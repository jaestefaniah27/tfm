/*
 * pcb_main.c — Caracterización eléctrica de la PCB de 14 transceptores RS-485/RS-422
 *
 * Corre sobre la variante MCDMA (serial_bridge) con el bitstream SIN loopback:
 * las líneas TD/RD van a los pines físicos, así que todo lo que se mide aquí
 * atraviesa de verdad los drivers, el cobre y la terminación de la PCB.
 *
 * A diferencia del benchmark de transportes (bench_main.c), que mide el coste
 * del camino PS↔PL, este programa mide **la PCB**: qué canales están realmente
 * unidos, hasta qué velocidad aguanta cada bus, qué hace el limitador de slew
 * (pin SLO), cuánto tarda un driver en soltar la línea (DE), cuánto se cuelan
 * los buses entre sí y cómo se comporta el bus en colisión.
 *
 * Topología esperada (jumpers, ver bench_compat.h):
 *   Bus A (RS485 multidrop): maestro CH0  | esclavos CH1..CH6
 *   Bus B (RS422):           maestro CH7  | esclavos CH8..CH10
 *   Bus C (RS422):           maestro CH11 | esclavos CH12..CH13
 * Los drivers 7 y 11 no tienen pin DE: su DE está fijado en la PCB.
 *
 * NINGÚN test da la topología por supuesta: T2 la MIDE y el resto usa lo medido.
 * Si los jumpers no coinciden con lo esperado, el informe lo dice y sigue.
 *
 * Salida: líneas "PCB,..." en CSV por consola; el resto es traza.
 *   PCB,<test>,<métrica>,<unidad>,<valor>,<nota>
 */

#include <rtems.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <inttypes.h>

#include "transceiver.h"
#include "bench_compat.h"   /* topología esperada + reloj CNTVCT */

/* =========================================================================
 * Parámetros
 * ========================================================================= */
#define N_CH             14
#define PROBE_LEN        32     /* bytes del patrón de sondeo de conectividad */
#define BER_FRAME        64     /* bytes por trama en el barrido de velocidad */
#define BER_REPS         16     /* tramas por punto de medida */
#define CROSSTALK_BYTES  128    /* ráfaga que se emite para medir diafonía */
#define IDLE_MS          300    /* escucha en reposo */

/* Los paquetes de RX no pueden pasar de MAX_PKT=256 B (el DRAIN los trocea a
 * ese tamaño para no bloquear el buffer store-and-forward del S2MM). Todas las
 * tramas de este test se quedan holgadamente por debajo. */

static Transceiver uarts[N_CH];
static uint32_t    num_ch;

/* Velocidades del barrido, de menor a mayor. */
static const struct { uint32_t sel; const char *name; uint32_t bps; } BAUDS[] = {
    { TRANSCEIVER_BAUD_9600,   "9600",   9600   },
    { TRANSCEIVER_BAUD_115200, "115200", 115200 },
    { TRANSCEIVER_BAUD_460800, "460800", 460800 },
    { TRANSCEIVER_BAUD_921600, "921600", 921600 },
    { TRANSCEIVER_BAUD_1M,     "1M",     1000000},
    { TRANSCEIVER_BAUD_2M,     "2M",     2000000},
    { TRANSCEIVER_BAUD_3M,     "3M",     3000000},
    { TRANSCEIVER_BAUD_4M,     "4M",     4000000},
};
#define N_BAUDS (sizeof(BAUDS)/sizeof(BAUDS[0]))

/* Guard times del test de vuelta del DE, en microsegundos. */
static const uint32_t GUARDS_US[] = { 0, 10, 25, 50, 100, 250, 500, 1000 };
#define N_GUARDS (sizeof(GUARDS_US)/sizeof(GUARDS_US[0]))

#define PCB_ROW(test, metric, unit, fmt, val, note)                        \
    do {                                                                   \
        printf("PCB,%s,%s,%s," fmt ",%s\n", (test), (metric), (unit),      \
               (val), (note));                                             \
        fflush(stdout);                                                    \
    } while (0)

/* =========================================================================
 * Utilidades
 * ========================================================================= */
static void settle(uint32_t ms) {
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(ms) + 1);
}

/* Espera activa fina: el tick de RTEMS (10 ms) es demasiado grueso para los
 * guard times de decenas de µs del test de vuelta del DE. */
static void busy_wait_us(uint32_t us) {
    uint64_t t0 = bench_cycles();
    while (bench_us_since(t0) < us) { __asm__ volatile("nop"); }
}

/* Reprograma un canal ya inicializado. Escribe el registro de configuración
 * directamente porque Transceiver_SetBaud fuerza SLO=0, y el efecto del SLO es
 * justo una de las cosas que hay que caracterizar. */
static void cfg_write(uint32_t ch, uint32_t baud_sel, uint32_t slo) {
    uint32_t v = 0;
    v |= (baud_sel                  & 0x3FU) << UART_CFG_SHIFT_BAUD;
    v |= (TRANSCEIVER_STOP_BITS_1   & 0x03U) << UART_CFG_SHIFT_STOP;
    v |= (TRANSCEIVER_PARITY_NONE   & 0x07U) << UART_CFG_SHIFT_PARITY;
    v |= (TRANSCEIVER_DATA_BITS_8   & 0x07U) << UART_CFG_SHIFT_DATA_BITS;
    if (slo) v |= UART_CFG_BIT_SLO;
    volatile uint32_t *reg =
        (volatile uint32_t *)(UART_CFG_BASE + (uintptr_t)ch * UART_CFG_STRIDE);
    *reg = v;
    __asm__ volatile("dsb sy" ::: "memory");
}

static void cfg_all(uint32_t baud_sel, uint32_t slo) {
    for (uint32_t c = 0; c < num_ch; c++) cfg_write(c, baud_sel, slo);
}

/* Transceiver_Send devuelve -1 cuando la DMA no confirma la transmisión (no
 * llega el IOC del MM2S o el EOAF de la UART). Eso NO es un error del bus: los
 * bytes ni siquiera salieron. Confundir las dos cosas fue el fallo de la primera
 * versión de este test, que apuntaba BER=100 % donde en realidad el transporte
 * no había llegado a transmitir. Se cuentan aparte. */
static uint32_t g_tx_fail;

static bool send_ok(uint32_t ch, const uint8_t *buf, uint32_t len) {
    int r = Transceiver_Send(&uarts[ch], buf, len);
    if (r != (int)len) { g_tx_fail++; return false; }
    return true;
}

/* Un timeout de TX deja el canal colgado y no se recupera solo: el resto de la
 * tanda daría cero aunque el cobre esté perfecto. Se reinicializan los canales
 * para volver a un estado limpio antes de seguir midiendo. */
static void recover(void) {
    Transceiver_Config_t cfg = {
        .baud      = TRANSCEIVER_BAUD_115200,
        .data_bits = TRANSCEIVER_DATA_BITS_8,
        .parity    = TRANSCEIVER_PARITY_NONE,
        .stop_bits = TRANSCEIVER_STOP_BITS_1,
        .bit_order = TRANSCEIVER_BIT_ORDER_LSB,
        .slo_mode  = TRANSCEIVER_SLO_OFF,
    };
    for (uint32_t c = 0; c < num_ch; c++)
        Transceiver_Init(&uarts[c], c, &cfg);
    settle(50);
}

/* Vacía el ring de recepción de un canal y devuelve cuántos bytes había. */
static uint32_t drain(uint32_t ch) {
    uint8_t tmp[256];
    uint32_t total = 0, n;
    while ((n = (uint32_t)Transceiver_Read(&uarts[ch], tmp, sizeof tmp)) > 0)
        total += n;
    return total;
}

static void drain_all(void) {
    for (uint32_t c = 0; c < num_ch; c++) (void)drain(c);
}

/* Patrón determinista: depende del canal emisor y de la posición, de modo que
 * un byte recibido dice de quién viene y si está en su sitio. */
static uint8_t pat(uint32_t src, uint32_t i) {
    return (uint8_t)(0x5AU ^ (src * 17U) ^ (i * 31U));
}

static void fill_pattern(uint8_t *buf, uint32_t src, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) buf[i] = pat(src, i);
}

/* Tiempo de vuelo de `len` bytes a `bps` (10 bits por byte en 8N1), con un
 * margen del 100 % más 2 ms fijos para el arranque de la DMA y el drenado. */
static uint32_t airtime_ms(uint32_t len, uint32_t bps) {
    uint64_t us = ((uint64_t)len * 10ULL * 1000000ULL) / bps;
    return (uint32_t)(us / 1000ULL) * 2U + 2U;
}

/* Recibe hasta `len` bytes de `ch` esperando como mucho `ms`.
 * Devuelve cuántos llegaron; deja en `buf` lo recibido. */
static uint32_t recv_timeout(uint32_t ch, uint8_t *buf, uint32_t len, uint32_t ms) {
    uint32_t got = 0;
    uint64_t t0 = bench_cycles();
    while (got < len && bench_us_since(t0) < (uint64_t)ms * 1000ULL) {
        got += (uint32_t)Transceiver_Read(&uarts[ch], buf + got, len - got);
    }
    return got;
}

/* Cuenta bytes correctos comparando contra el patrón del emisor. */
static uint32_t count_ok(const uint8_t *buf, uint32_t got, uint32_t src) {
    uint32_t ok = 0;
    for (uint32_t i = 0; i < got; i++)
        if (buf[i] == pat(src, i)) ok++;
    return ok;
}

/* =========================================================================
 * Topología: la esperada (jumpers) y la MEDIDA (T2)
 * ========================================================================= */
static const int8_t BUS_ESPERADO[N_CH] = {
    /* CH0..CH6 → bus A */ 0,0,0,0,0,0,0,
    /* CH7..CH10 → bus B */ 1,1,1,1,
    /* CH11..CH13 → bus C */ 2,2,2
};
static const char *BUS_NAME[3] = { "A(RS485-multidrop)", "B(RS422)", "C(RS422)" };
static const uint32_t MASTER[3]  = { 0, 7, 11 };
static const uint32_t LISTENER[3] = { 1, 8, 12 };

/* Matriz medida: hear[src][dst] = bytes correctos que dst oyó de src. */
static uint32_t hear[N_CH][N_CH];

/* =========================================================================
 * T1 — Reposo: ¿la línea está en fail-safe o flota?
 *
 * Con todos los drivers callados, un bus RS-485 bien polarizado (resistencias
 * de bias + terminación) se queda en estado de reposo y el receptor no ve nada.
 * Si la línea flota, el receptor interpreta ruido como bytes: aquí eso aparece
 * como bytes espurios. Es la comprobación más barata de que la polarización de
 * fail-safe de la PCB existe y funciona.
 * ========================================================================= */
static void T1_reposo(void) {
    puts("\n=== T1 — Reposo (fail-safe / polarización) ===");
    cfg_all(TRANSCEIVER_BAUD_115200, TRANSCEIVER_SLO_OFF);
    drain_all();
    settle(IDLE_MS);

    uint32_t total = 0;
    for (uint32_t c = 0; c < num_ch; c++) {
        uint32_t n = drain(c);
        total += n;
        char note[48];
        snprintf(note, sizeof note, "CH%" PRIu32, c);
        PCB_ROW("T1_reposo", "bytes_espurios", "count", "%" PRIu32, n, note);
        if (n) printf("  CH%-2" PRIu32 ": %" PRIu32 " bytes espurios en reposo\n", c, n);
    }
    PCB_ROW("T1_reposo", "total_espurios", "count", "%" PRIu32, total,
            total ? "linea flotante o ruido: revisar bias/terminacion" : "lineas en reposo, fail-safe OK");
    printf("  %s\n", total ? "  [AVISO] hay bytes espurios: la polarizacion de reposo no es limpia"
                           : "  [OK] ningun byte espurio en 14 canales");
}

/* =========================================================================
 * T2 — Matriz de conectividad 14×14: MIDE el cableado real
 *
 * Cada canal emite, por turnos, un patrón que lo identifica; se escucha en los
 * otros 13. El resultado es quién oye a quién de verdad: revela los buses
 * físicos tal como están puenteados, canales muertos, y cruces de cableado.
 * Todo lo que viene después se apoya en esta matriz, no en lo que "debería ser".
 * ========================================================================= */
static void T2_matriz(void) {
    puts("\n=== T2 — Matriz de conectividad (quién oye a quién) ===");
    cfg_all(TRANSCEIVER_BAUD_115200, TRANSCEIVER_SLO_OFF);
    memset(hear, 0, sizeof hear);

    uint8_t tx[PROBE_LEN], rx[PROBE_LEN * 2];

    for (uint32_t src = 0; src < num_ch; src++) {
        drain_all();
        fill_pattern(tx, src, PROBE_LEN);
        (void)send_ok(src, tx, PROBE_LEN);
        settle(airtime_ms(PROBE_LEN, 115200) + 20);

        for (uint32_t dst = 0; dst < num_ch; dst++) {
            if (dst == src) continue;   /* un canal no se oye a sí mismo: el DE inhibe su receptor */
            uint32_t got = (uint32_t)Transceiver_Read(&uarts[dst], rx, sizeof rx);
            hear[src][dst] = count_ok(rx, got > PROBE_LEN ? PROBE_LEN : got, src);
        }
    }

    /* Matriz legible */
    printf("\n      dst→");
    for (uint32_t d = 0; d < num_ch; d++) printf("%4" PRIu32, d);
    printf("\n");
    for (uint32_t s = 0; s < num_ch; s++) {
        printf("  src %2" PRIu32 ":", s);
        for (uint32_t d = 0; d < num_ch; d++) {
            if (d == s) printf("   ·");
            else if (hear[s][d] == PROBE_LEN) printf("   #");     /* íntegro */
            else if (hear[s][d] > 0)          printf("%4" PRIu32); /* parcial: bytes ok */
            else printf("   .");                                   /* nada */
        }
        printf("\n");
    }
    puts("  (# = las 32 B íntegras · n = n bytes correctos · . = no oye · · = sí mismo)");

    /* Contraste con la topología esperada por los jumpers */
    uint32_t enlaces_ok = 0, enlaces_esperados = 0, enlaces_extra = 0, enlaces_faltan = 0;
    for (uint32_t s = 0; s < num_ch; s++) {
        for (uint32_t d = 0; d < num_ch; d++) {
            if (d == s) continue;
            bool esperado = (BUS_ESPERADO[s] == BUS_ESPERADO[d]);
            bool oido     = (hear[s][d] > 0);
            if (esperado) enlaces_esperados++;
            if (esperado && oido)  enlaces_ok++;
            if (esperado && !oido) enlaces_faltan++;
            if (!esperado && oido) enlaces_extra++;

            if (oido) {
                char note[64];
                snprintf(note, sizeof note, "CH%" PRIu32 "->CH%" PRIu32 "%s",
                         s, d, esperado ? "" : " (NO ESPERADO: cruce de buses)");
                PCB_ROW("T2_matriz", "bytes_ok", "count", "%" PRIu32, hear[s][d], note);
            }
        }
    }
    PCB_ROW("T2_matriz", "enlaces_ok",      "count", "%" PRIu32, enlaces_ok,     "de los esperados por los jumpers");
    PCB_ROW("T2_matriz", "enlaces_esperados","count","%" PRIu32, enlaces_esperados, "");
    PCB_ROW("T2_matriz", "enlaces_faltan",  "count", "%" PRIu32, enlaces_faltan, "esperados que no se oyen: cableado o driver muerto");
    PCB_ROW("T2_matriz", "enlaces_extra",   "count", "%" PRIu32, enlaces_extra,  "no esperados que se oyen: cruce entre buses");

    /* Canales completamente mudos o sordos: el diagnóstico más útil de la PCB */
    for (uint32_t c = 0; c < num_ch; c++) {
        uint32_t oyen_a_c = 0, c_oye_a = 0;
        for (uint32_t o = 0; o < num_ch; o++) {
            if (o == c) continue;
            if (hear[c][o] > 0) oyen_a_c++;
            if (hear[o][c] > 0) c_oye_a++;
        }
        if (oyen_a_c == 0) {
            char note[48]; snprintf(note, sizeof note, "CH%" PRIu32, c);
            PCB_ROW("T2_matriz", "canal_mudo", "bool", "%d", 1, note);
            printf("  [FALLO] CH%" PRIu32 " no lo oye NADIE: driver o pista de TX/DE\n", c);
        }
        if (c_oye_a == 0) {
            char note[48]; snprintf(note, sizeof note, "CH%" PRIu32, c);
            PCB_ROW("T2_matriz", "canal_sordo", "bool", "%d", 1, note);
            printf("  [FALLO] CH%" PRIu32 " no oye a NADIE: receptor o pista de RX\n", c);
        }
    }
}

/* =========================================================================
 * T3 — Integridad multidrop del bus A
 *
 * En un bus compartido, cuando habla el maestro TODOS los esclavos deben oírlo
 * íntegro. Si solo lo oyen algunos, el bus no está realmente compartido (o un
 * stub está mal terminado y refleja).
 * ========================================================================= */
static void T3_multidrop(void) {
    puts("\n=== T3 — Integridad multidrop del bus A ===");
    recover();
    const uint32_t slaves[] = { 1, 2, 3, 4, 5, 6 };
    const uint32_t n_sl = sizeof(slaves)/sizeof(slaves[0]);

    for (uint32_t b = 0; b < N_BAUDS; b++) {
        cfg_all(BAUDS[b].sel, TRANSCEIVER_SLO_OFF);
        drain_all();

        uint8_t tx[PROBE_LEN], rx[PROBE_LEN * 2];
        fill_pattern(tx, 0, PROBE_LEN);
        (void)send_ok(0, tx, PROBE_LEN);
        settle(airtime_ms(PROBE_LEN, BAUDS[b].bps) + 20);

        uint32_t enteros = 0, parciales = 0;
        for (uint32_t i = 0; i < n_sl; i++) {
            uint32_t got = (uint32_t)Transceiver_Read(&uarts[slaves[i]], rx, sizeof rx);
            uint32_t ok  = count_ok(rx, got > PROBE_LEN ? PROBE_LEN : got, 0);
            if (ok == PROBE_LEN) enteros++;
            else if (ok > 0)     parciales++;
        }
        PCB_ROW("T3_multidrop", "esclavos_integros", "count", "%" PRIu32, enteros,  BAUDS[b].name);
        PCB_ROW("T3_multidrop", "esclavos_parciales","count", "%" PRIu32, parciales, BAUDS[b].name);
        printf("  %-7s: %" PRIu32 "/%" PRIu32 " esclavos íntegros, %" PRIu32 " parciales\n",
               BAUDS[b].name, enteros, n_sl, parciales);
    }
}

/* =========================================================================
 * T4 — Barrido de velocidad por bus: hasta dónde aguanta el cobre
 *
 * Para cada bus, el maestro manda BER_REPS tramas de BER_FRAME bytes a cada
 * velocidad, y se cuenta cuántos bytes llegan correctos al primer esclavo.
 * La velocidad más alta con BER = 0 es la que la PCB soporta de verdad: por
 * encima manda la carga capacitiva del bus, la terminación y el slew del driver.
 *
 * `slo` permite repetir el barrido con el limitador de slew activado (T5).
 * Devuelve la velocidad máxima sin errores, en bps (0 si falla ya la más baja).
 * ========================================================================= */
static uint32_t barrido_bus(uint32_t bus, uint32_t slo, const char *test) {
    const uint32_t m = MASTER[bus], s = LISTENER[bus];
    recover();   /* cada bus arranca con el transporte en un estado conocido */
    uint32_t max_limpio = 0;
    uint8_t tx[BER_FRAME], rx[BER_FRAME * 2];

    for (uint32_t b = 0; b < N_BAUDS; b++) {
        cfg_all(BAUDS[b].sel, slo);
        drain_all();

        uint32_t enviados = 0, correctos = 0, recibidos = 0, fallos_tx = 0;
        for (uint32_t r = 0; r < BER_REPS; r++) {
            fill_pattern(tx, m, BER_FRAME);
            if (!send_ok(m, tx, BER_FRAME)) { fallos_tx++; continue; }
            uint32_t got = recv_timeout(s, rx, BER_FRAME,
                                        airtime_ms(BER_FRAME, BAUDS[b].bps) + 20);
            enviados  += BER_FRAME;
            recibidos += got;
            correctos += count_ok(rx, got, m);
        }

        char note[72];
        snprintf(note, sizeof note, "%s bus%s SLO=%s",
                 BAUDS[b].name, BUS_NAME[bus], slo ? "ON" : "OFF");

        /* Si la DMA no llegó a transmitir, este punto no dice NADA del cobre:
         * se registra como fallo de transporte y no se calcula BER. */
        if (fallos_tx) {
            PCB_ROW(test, "fallos_tx", "count", "%" PRIu32, fallos_tx, note);
            printf("  bus %-18s %-7s SLO=%-3s  TX NO COMPLETO (%" PRIu32 "/%d): "
                   "punto no medible, se recupera el canal\n",
                   BUS_NAME[bus], BAUDS[b].name, slo ? "ON" : "OFF",
                   fallos_tx, BER_REPS);
            recover();
            if (enviados == 0) break;   /* nada salió: no tiene sentido subir más */
            continue;
        }

        /* BER en partes por millón: entero, sin coma flotante en la consola. */
        uint32_t ber_ppm = (uint32_t)(((uint64_t)(enviados - correctos) * 1000000ULL) / enviados);

        PCB_ROW(test, "bytes_ok",  "count", "%" PRIu32, correctos, note);
        PCB_ROW(test, "bytes_rx",  "count", "%" PRIu32, recibidos, note);
        PCB_ROW(test, "ber",       "ppm",   "%" PRIu32, ber_ppm,   note);

        printf("  bus %-18s %-7s SLO=%-3s  ok=%4" PRIu32 "/%4" PRIu32
               "  BER=%" PRIu32 " ppm\n",
               BUS_NAME[bus], BAUDS[b].name, slo ? "ON" : "OFF",
               correctos, enviados, ber_ppm);

        if (ber_ppm == 0) max_limpio = BAUDS[b].bps;

        /* Si a esta velocidad no llegó un solo byte correcto, más rápido tampoco
         * llegará: se corta el barrido y se deja el canal limpio. Seguir subiendo
         * fue lo que colgó el transporte en la primera tanda. */
        if (correctos == 0) {
            printf("  bus %-18s: nada correcto a %s, se corta el barrido aquí\n",
                   BUS_NAME[bus], BAUDS[b].name);
            recover();
            break;
        }
    }

    char note[64];
    snprintf(note, sizeof note, "bus%s SLO=%s", BUS_NAME[bus], slo ? "ON" : "OFF");
    PCB_ROW(test, "baud_max_sin_errores", "bps", "%" PRIu32, max_limpio, note);
    return max_limpio;
}

static uint32_t baud_max_slo_off[3];

static void T4_velocidad(void) {
    puts("\n=== T4 — Velocidad máxima por bus (SLO OFF) ===");
    for (uint32_t bus = 0; bus < 3; bus++)
        baud_max_slo_off[bus] = barrido_bus(bus, TRANSCEIVER_SLO_OFF, "T4_velocidad");
}

/* =========================================================================
 * T5 — Efecto del limitador de slew (pin SLO)
 *
 * El SLO de los drivers frena los flancos: reduce la emisión radiada y las
 * reflexiones en un bus mal terminado, a costa de limitar la velocidad máxima.
 * Se repite el barrido con SLO activo y se compara la velocidad máxima limpia
 * de cada bus. Es la caracterización directa de ese componente.
 * ========================================================================= */
static void T5_slo(void) {
    puts("\n=== T5 — Limitador de slew (SLO) ===");
    for (uint32_t bus = 0; bus < 3; bus++) {
        uint32_t con_slo = barrido_bus(bus, TRANSCEIVER_SLO_ON, "T5_slo");
        char note[80];
        snprintf(note, sizeof note, "bus%s SLO_OFF=%" PRIu32 " bps",
                 BUS_NAME[bus], baud_max_slo_off[bus]);
        PCB_ROW("T5_slo", "baud_max_con_slo", "bps", "%" PRIu32, con_slo, note);
        printf("  bus %-18s  máx sin SLO = %8" PRIu32 " bps   |   con SLO = %8" PRIu32 " bps\n",
               BUS_NAME[bus], baud_max_slo_off[bus], con_slo);
    }
}

/* =========================================================================
 * T6 — Vuelta del bus (turnaround del DE)
 *
 * En half-duplex, el esclavo no puede contestar hasta que el maestro haya
 * soltado la línea (DE a 0). Si contesta demasiado pronto, los dos drivers
 * conducen a la vez y la respuesta sale corrupta.
 *
 * Se mide el guard time mínimo: el esclavo espera g µs desde que recibe la
 * consulta antes de responder, y se busca el g más pequeño con el que la
 * respuesta llega íntegra. Ese valor caracteriza el tiempo de deshabilitación
 * del driver más el tiempo de vuelo de la línea.
 *
 * Solo tiene sentido en el bus A (RS-485 half-duplex, con DE conmutable).
 * ========================================================================= */
static void T6_turnaround(void) {
    puts("\n=== T6 — Vuelta del bus / guard time del DE (bus A) ===");
    cfg_all(TRANSCEIVER_BAUD_115200, TRANSCEIVER_SLO_OFF);

    const uint32_t m = 0, s = 1;
    const uint32_t QLEN = 8, RLEN = 8;
    uint8_t q[QLEN], r[RLEN], rx[RLEN * 2];
    uint32_t g_min = 0;
    bool encontrado = false;

    for (uint32_t gi = 0; gi < N_GUARDS; gi++) {
        uint32_t guard = GUARDS_US[gi];
        uint32_t intentos = 8, integras = 0;

        for (uint32_t k = 0; k < intentos; k++) {
            drain_all();
            fill_pattern(q, m, QLEN);
            if (!send_ok(m, q, QLEN)) continue;   /* bloqueante: vuelve tras la TX física */

            /* El esclavo espera a oír la consulta y responde tras el guard. */
            uint32_t got_q = recv_timeout(s, rx, QLEN, airtime_ms(QLEN, 115200) + 20);
            if (got_q < QLEN) continue;             /* no oyó la consulta: no cuenta */

            busy_wait_us(guard);
            fill_pattern(r, s, RLEN);
            (void)send_ok(s, r, RLEN);

            uint32_t got_r = recv_timeout(m, rx, RLEN, airtime_ms(RLEN, 115200) + 20);
            if (got_r == RLEN && count_ok(rx, RLEN, s) == RLEN) integras++;
        }

        char note[48];
        snprintf(note, sizeof note, "guard=%" PRIu32 "us", guard);
        PCB_ROW("T6_turnaround", "respuestas_integras", "count", "%" PRIu32, integras, note);
        printf("  guard %5" PRIu32 " µs → %" PRIu32 "/%" PRIu32 " respuestas íntegras\n",
               guard, integras, intentos);

        if (!encontrado && integras == intentos) { g_min = guard; encontrado = true; }
    }

    PCB_ROW("T6_turnaround", "guard_minimo", "us", "%" PRIu32, g_min,
            encontrado ? "menor guard con 8/8 respuestas integras"
                       : "NINGUN guard dio 8/8: revisar DE o cableado del bus A");
    if (encontrado)
        printf("  guard mínimo con respuesta siempre íntegra: %" PRIu32 " µs\n", g_min);
    else
        puts("  [FALLO] ningún guard time consiguió respuesta íntegra");
}

/* =========================================================================
 * T7 — Diafonía entre buses
 *
 * Los tres buses están aislados. Se satura el bus A con una ráfaga a la máxima
 * velocidad que aguantó, y se escucha en B y C: cualquier byte que aparezca ahí
 * es acoplamiento entre pistas o un cruce de cableado.
 * ========================================================================= */
static void T7_diafonia(void) {
    puts("\n=== T7 — Diafonía entre buses ===");
    uint32_t bps = baud_max_slo_off[0] ? baud_max_slo_off[0] : 115200;
    uint32_t sel = TRANSCEIVER_BAUD_115200;
    for (uint32_t b = 0; b < N_BAUDS; b++) if (BAUDS[b].bps == bps) sel = BAUDS[b].sel;

    cfg_all(sel, TRANSCEIVER_SLO_OFF);
    drain_all();

    uint8_t tx[CROSSTALK_BYTES];
    fill_pattern(tx, 0, CROSSTALK_BYTES);
    (void)send_ok(0, tx, CROSSTALK_BYTES);
    settle(airtime_ms(CROSSTALK_BYTES, bps) + 20);

    uint32_t fuga = 0;
    for (uint32_t c = 0; c < num_ch; c++) {
        if (BUS_ESPERADO[c] == 0) { (void)drain(c); continue; }  /* el propio bus A */
        uint32_t n = drain(c);
        fuga += n;
        if (n) {
            char note[48];
            snprintf(note, sizeof note, "CH%" PRIu32 " (bus %s)", c, BUS_NAME[BUS_ESPERADO[c]]);
            PCB_ROW("T7_diafonia", "bytes_fuga", "count", "%" PRIu32, n, note);
            printf("  [AVISO] CH%" PRIu32 " oyó %" PRIu32 " bytes del bus A\n", c, n);
        }
    }
    char note[64];
    snprintf(note, sizeof note, "ráfaga de %d B a %" PRIu32 " bps en bus A", CROSSTALK_BYTES, bps);
    PCB_ROW("T7_diafonia", "total_fuga", "count", "%" PRIu32, fuga, note);
    printf("  %s\n", fuga ? "  hay acoplamiento entre buses" : "  [OK] buses aislados: 0 bytes de fuga");
}

/* =========================================================================
 * T8 — Colisión en el bus multidrop
 *
 * Dos esclavos del bus A emiten a la vez. En RS-485 los drivers hacen un AND
 * cableado: la trama que oye el maestro debe salir corrupta. Lo que importa no
 * es que se corrompa (eso es física), sino que el bus se RECUPERE: tras la
 * colisión, un intercambio limpio tiene que volver a funcionar. Si no, algún
 * driver se ha quedado enganchado.
 * ========================================================================= */
/* Transceiver_Send es bloqueante en MCDMA: espera a que la UART haya sacado el
 * último bit. Dos llamadas en serie NUNCA se solapan en el cobre, así que la
 * colisión hay que provocarla desde dos tareas que arranquen a la vez. */
static rtems_id g_col_start, g_col_done;

static rtems_task Col_TX_Task(rtems_task_argument arg) {
    uint32_t ch = (uint32_t)arg;
    uint8_t buf[PROBE_LEN];
    fill_pattern(buf, ch, PROBE_LEN);

    rtems_semaphore_obtain(g_col_start, RTEMS_WAIT, RTEMS_NO_TIMEOUT);
    Transceiver_Send(&uarts[ch], buf, PROBE_LEN);
    rtems_semaphore_release(g_col_done);
    rtems_task_delete(RTEMS_SELF);
}

static void T8_colision(void) {
    puts("\n=== T8 — Colisión y recuperación (bus A) ===");
    cfg_all(TRANSCEIVER_BAUD_115200, TRANSCEIVER_SLO_OFF);
    drain_all();

    uint8_t rx[PROBE_LEN * 3];

    rtems_semaphore_create(rtems_build_name('C','S','T','A'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0, &g_col_start);
    rtems_semaphore_create(rtems_build_name('C','D','O','N'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0, &g_col_done);

    for (uint32_t i = 1; i <= 2; i++) {   /* CH1 y CH2, dos esclavos del bus A */
        rtems_id t;
        rtems_task_create(rtems_build_name('C','T','X','0' + (char)i), 110,
                          RTEMS_MINIMUM_STACK_SIZE * 2,
                          RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &t);
        rtems_task_start(t, Col_TX_Task, (rtems_task_argument)i);
    }
    settle(20);                                   /* que las dos lleguen a la barrera */
    rtems_semaphore_release(g_col_start);
    rtems_semaphore_release(g_col_start);         /* arrancan a la vez */

    for (uint32_t i = 0; i < 2; i++)
        rtems_semaphore_obtain(g_col_done, RTEMS_WAIT, RTEMS_MILLISECONDS_TO_TICKS(2000));
    rtems_semaphore_delete(g_col_start);
    rtems_semaphore_delete(g_col_done);

    settle(airtime_ms(PROBE_LEN * 2, 115200) + 30);

    uint32_t got = (uint32_t)Transceiver_Read(&uarts[0], rx, sizeof rx);
    uint32_t ok_a = count_ok(rx, got > PROBE_LEN ? PROBE_LEN : got, 1);
    uint32_t ok_b = count_ok(rx, got > PROBE_LEN ? PROBE_LEN : got, 2);
    bool corrupta = !(ok_a == PROBE_LEN || ok_b == PROBE_LEN);

    PCB_ROW("T8_colision", "bytes_oidos",   "count", "%" PRIu32, got, "el maestro escucha la colision");
    PCB_ROW("T8_colision", "trama_corrupta","bool",  "%d", corrupta ? 1 : 0,
            corrupta ? "colision detectada, como debe ser"
                     : "una de las dos tramas sobrevivio intacta: los esclavos no comparten bus");

    /* Recuperación: un PING limpio después de la colisión */
    drain_all();
    uint8_t p[PROBE_LEN];
    fill_pattern(p, 0, PROBE_LEN);
    (void)send_ok(0, p, PROBE_LEN);
    uint32_t g2 = recv_timeout(1, rx, PROBE_LEN, airtime_ms(PROBE_LEN, 115200) + 30);
    bool recuperado = (count_ok(rx, g2, 0) == PROBE_LEN);

    PCB_ROW("T8_colision", "recuperado", "bool", "%d", recuperado ? 1 : 0,
            recuperado ? "intercambio limpio tras la colision"
                       : "el bus NO se recupera: driver enganchado");
    printf("  colisión: %s | recuperación: %s\n",
           corrupta ? "trama corrupta (esperado)" : "trama intacta (los esclavos NO comparten bus)",
           recuperado ? "OK" : "FALLO");
}

/* =========================================================================
 * T9 — Estabilidad sostenida
 *
 * Tráfico continuo en los tres buses durante unos segundos, a la velocidad más
 * alta que cada uno aguantó limpio. Da la tasa de error en régimen permanente,
 * que es lo que de verdad se va a ver en operación, y saca a la luz los fallos
 * que solo aparecen con el cobre caliente o con el bus cargado.
 * ========================================================================= */
static void T9_estabilidad(void) {
    puts("\n=== T9 — Estabilidad sostenida (tráfico continuo) ===");
    const uint32_t SEGUNDOS = 10;

    for (uint32_t bus = 0; bus < 3; bus++) {
        uint32_t bps = baud_max_slo_off[bus] ? baud_max_slo_off[bus] : 115200;
        uint32_t sel = TRANSCEIVER_BAUD_115200;
        for (uint32_t b = 0; b < N_BAUDS; b++) if (BAUDS[b].bps == bps) sel = BAUDS[b].sel;

        recover();
        cfg_all(sel, TRANSCEIVER_SLO_OFF);
        drain_all();
        Transceiver_BenchDbgReset();

        const uint32_t m = MASTER[bus], s = LISTENER[bus];
        uint8_t tx[BER_FRAME], rx[BER_FRAME * 2];
        uint64_t t0 = bench_cycles();
        uint32_t enviados = 0, correctos = 0, tramas = 0;

        while (bench_us_since(t0) < (uint64_t)SEGUNDOS * 1000000ULL) {
            fill_pattern(tx, m, BER_FRAME);
            if (!send_ok(m, tx, BER_FRAME)) { recover(); continue; }
            uint32_t got = recv_timeout(s, rx, BER_FRAME, airtime_ms(BER_FRAME, bps) + 20);
            enviados  += BER_FRAME;
            correctos += count_ok(rx, got, m);
            tramas++;
        }

        uint32_t ber_ppm = enviados ?
            (uint32_t)(((uint64_t)(enviados - correctos) * 1000000ULL) / enviados) : 0;

        Transceiver_BenchStats_t st;
        Transceiver_BenchStats(&st);

        char note[80];
        snprintf(note, sizeof note, "bus%s a %" PRIu32 " bps, %" PRIu32 " s",
                 BUS_NAME[bus], bps, SEGUNDOS);
        PCB_ROW("T9_estabilidad", "tramas",     "count", "%" PRIu32, tramas,    note);
        PCB_ROW("T9_estabilidad", "bytes_ok",   "count", "%" PRIu32, correctos, note);
        PCB_ROW("T9_estabilidad", "bytes_total","count", "%" PRIu32, enviados,  note);
        PCB_ROW("T9_estabilidad", "ber",        "ppm",   "%" PRIu32, ber_ppm,   note);
        PCB_ROW("T9_estabilidad", "errores_hw", "count", "%" PRIu64, st.err_count, note);

        printf("  bus %-18s %8" PRIu32 " bps: %" PRIu32 " tramas, BER=%" PRIu32
               " ppm, errores HW=%" PRIu64 "\n",
               BUS_NAME[bus], bps, tramas, ber_ppm, st.err_count);
    }
}

/* =========================================================================
 * Tarea principal
 * ========================================================================= */
static rtems_task Pcb_Task(rtems_task_argument arg) {
    (void)arg;

    puts("\n########################################################");
    puts("#  CARACTERIZACION ELECTRICA DE LA PCB — variante MCDMA #");
    puts("########################################################");
    printf("canales detectados: %" PRIu32 "\n", num_ch);
    puts("Requiere el bitstream SIN loopback: las lineas van a los pines fisicos.");
    puts("Si todos los canales salen mudos, es que esta cargado el bitstream de loopback.\n");

    printf("PCB,test,metric,unit,value,note\n");
    fflush(stdout);

    T1_reposo();
    T2_matriz();
    T3_multidrop();
    T4_velocidad();
    T5_slo();
    T6_turnaround();
    T7_diafonia();
    T8_colision();
    T9_estabilidad();

    PCB_ROW("resumen", "fallos_tx_total", "count", "%" PRIu32, g_tx_fail,
            "envios que la DMA no completo: fallo de transporte, NO del bus");

    puts("\n=== FIN DE LA CARACTERIZACION DE LA PCB ===");
    fflush(stdout);
    rtems_task_suspend(RTEMS_SELF);
}

rtems_task Init(rtems_task_argument arg) {
    (void)arg;

    /* Sin esto, el primer acceso a 0xA000_0000 es un Data Abort. */
    extern void mmu_map_pl_axi_early(void);
    mmu_map_pl_axi_early();

    settle(500);

    num_ch = Transceiver_Global_INIT();
    if (num_ch == 0) {
        printf("[PCB] ERROR: no se detectaron canales de hardware\n");
        rtems_task_suspend(RTEMS_SELF);
    }
    if (num_ch > N_CH) num_ch = N_CH;

    Transceiver_Config_t cfg = {
        .baud      = TRANSCEIVER_BAUD_115200,
        .data_bits = TRANSCEIVER_DATA_BITS_8,
        .parity    = TRANSCEIVER_PARITY_NONE,
        .stop_bits = TRANSCEIVER_STOP_BITS_1,
        .bit_order = TRANSCEIVER_BIT_ORDER_LSB,
        .slo_mode  = TRANSCEIVER_SLO_OFF,
    };
    for (uint32_t i = 0; i < num_ch; i++)
        Transceiver_Init(&uarts[i], i, &cfg);

    settle(500);

    /* Por debajo de las tareas de recepción del driver (prio 10 y 50), para que
     * el sondeo de este test no compita con la ruta de datos. */
    rtems_id t;
    rtems_task_create(rtems_build_name('P','C','B','T'), 120,
                      RTEMS_MINIMUM_STACK_SIZE * 8,
                      RTEMS_DEFAULT_MODES, RTEMS_FLOATING_POINT, &t);
    rtems_task_start(t, Pcb_Task, 0);

    rtems_task_suspend(RTEMS_SELF);
}
