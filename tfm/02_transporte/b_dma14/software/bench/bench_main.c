/*
 * bench_main.c — Benchmark comparativo de transportes PS↔PL
 *
 * Fichero IDÉNTICO en los tres proyectos:
 *   configurable_transceiver_inter   → AXI-GPIO + AXI-INTC
 *   lince_comunicacion_serial_dma_pcb→ 14× AXI-DMA simple (PG021)
 *   serial_bridge                    → AXI-MCDMA SG (PG288), 1 TX / 14 RX
 *
 * La variante se autodetecta en transceiver_bench.h. Ninguna condicional de
 * preprocesador altera la secuencia de tests: los tres binarios ejecutan
 * exactamente las mismas medidas, en el mismo orden, sobre la misma PCB.
 *
 * MEDIDA DEL TIEMPO — la decisión central de este benchmark:
 *   Transceiver_Send es BLOQUEANTE en MCDMA (espera al EOAF) y NO BLOQUEANTE
 *   en GPIO y DMA14 (retorna al encolar). Cronometrar el retorno de Send daría
 *   throughputs absurdos en dos de las tres. Por eso todo se mide END-TO-END:
 *   el cronómetro para cuando el CANAL RECEPTOR tiene los bytes en su ring.
 *
 * Topología: los buses físicos de la PCB (ver bench_compat.h). No se usa
 * loopback interno porque el bitstream de la variante GPIO no lo implementa.
 *
 * Salida: líneas "BENCH,..." en CSV por consola. Todo lo demás es traza.
 */

#include <rtems.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <inttypes.h>

#include "transceiver.h"
#include "bench_compat.h"

/* =========================================================================
 * Parámetros del benchmark
 * ========================================================================= */
#define LAT_ITERS        50      /* muestras de latencia */
#define LAT_PAYLOAD      8       /* bytes de datos en el frame de latencia */
#define THR_BYTES        1024    /* bloque para throughput de un canal */
#define THR_REPS         5       /* repeticiones promediadas */
#define CONC_BYTES       512     /* bytes por maestro en el test concurrente */
#define MULTIDROP_BYTES  256     /* bytes que emite el maestro del bus A */
#define OVERRUN_BYTES    8192    /* > ring SW (4096) para forzar pérdida */
#define RX_TIMEOUT_US    3000000ULL   /* 3 s: techo de cualquier espera de RX */
#define SETTLE_MS        50      /* reposo del bus entre tests */
#define BAUD_SETTLE_MS   200     /* reposo tras reprogramar los 14 UARTs */

#define MAX_ACC          2048    /* acumulador de RX por canal */
#define MAX_FRAME        64

/* Barrido de velocidades: los 7 puntos que ya usaba serial_bridge/main.c */
typedef struct { uint32_t sel; const char *name; uint32_t bps; } BaudPoint;
static const BaudPoint g_bauds[] = {
    { TRANSCEIVER_BAUD_115200, "115200",  115200 },
    { TRANSCEIVER_BAUD_230400, "230400",  230400 },
    { TRANSCEIVER_BAUD_460800, "460800",  460800 },
    { TRANSCEIVER_BAUD_921600, "921600",  921600 },
    { TRANSCEIVER_BAUD_1M,     "1M",     1000000 },
    { TRANSCEIVER_BAUD_2M,     "2M",     2000000 },
    { TRANSCEIVER_BAUD_4M,     "4M",     4000000 },
};
#define N_BAUDS (sizeof(g_bauds)/sizeof(g_bauds[0]))

/* =========================================================================
 * Estado global
 * ========================================================================= */
static uint32_t    num_ch;
static Transceiver uarts[MAX_TRANSCEIVERS];
static uint8_t     rx_acc[MAX_TRANSCEIVERS][MAX_ACC];

/* =========================================================================
 * Patrón de datos: LCG determinista, reproducible en TX y en la verificación.
 * ========================================================================= */
static inline uint8_t pattern_byte(uint32_t i) {
    uint32_t x = i * 1103515245u + 12345u;
    return (uint8_t)((x >> 16) & 0xFF);
}

static void fill_pattern(uint8_t *buf, size_t n, uint32_t seed) {
    for (size_t i = 0; i < n; i++) buf[i] = pattern_byte(seed + (uint32_t)i);
}

/* Cuenta cuántos de los `n` bytes de `buf` coinciden con el patrón. */
static size_t count_matches(const uint8_t *buf, size_t n, uint32_t seed) {
    size_t ok = 0;
    for (size_t i = 0; i < n; i++)
        if (buf[i] == pattern_byte(seed + (uint32_t)i)) ok++;
    return ok;
}

/* =========================================================================
 * Protocolo de frames (idéntico al de serial_bridge/main.c)
 *   [0xFF][SOF=0xAA][DST][SRC][CMD][LEN][DATA..][CHK=XOR][0xFF]
 * ========================================================================= */
#define SOF 0xAAU
#define CMD_PING 0x01U

static size_t build_frame(uint8_t *out, uint8_t dst, uint8_t src,
                          uint8_t cmd, const uint8_t *data, uint8_t len) {
    size_t i = 0;
    out[i++] = 0xFF;
    out[i++] = SOF;
    out[i++] = dst;
    out[i++] = src;
    out[i++] = cmd;
    out[i++] = len;
    uint8_t chk = dst ^ src ^ cmd ^ len;
    for (uint8_t k = 0; k < len; k++) { out[i++] = data[k]; chk ^= data[k]; }
    out[i++] = chk;
    out[i++] = 0xFF;
    return i;
}

static bool parse_frame(const uint8_t *buf, size_t n,
                        uint8_t *dst, uint8_t *src, uint8_t *cmd,
                        uint8_t *data, uint8_t *len) {
    for (size_t off = 0; off + 6 <= n; off++) {
        if (buf[off] != SOF) continue;
        uint8_t l = buf[off + 4];
        size_t total = 5 + (size_t)l + 1;
        if (off + total > n) continue;
        uint8_t chk = 0;
        for (size_t i = off + 1; i < off + 5 + l; i++) chk ^= buf[i];
        if (chk != buf[off + 5 + l]) continue;
        *dst = buf[off + 1];
        *src = buf[off + 2];
        *cmd = buf[off + 3];
        *len = l;
        for (uint8_t k = 0; k < l; k++) data[k] = buf[off + 5 + k];
        return true;
    }
    return false;
}

/* =========================================================================
 * Espera de recepción
 *
 * Polling desde la tarea de benchmark, que corre a la prioridad MÁS BAJA del
 * sistema: las ISRs y las tareas de recepción de los tres drivers (prio 10 y
 * 50) la expulsan en cuanto tienen trabajo. Así el sondeo no roba tiempo a la
 * ruta de datos y las tres variantes se miden con el mismo mecanismo.
 * ========================================================================= */
static void flush_rx(uint32_t ch) {
    uint8_t tmp[MAX_FRAME];
    while (Transceiver_Read(&uarts[ch], tmp, sizeof(tmp)) > 0) { }
}

static void flush_all_rx(void) {
    for (uint32_t c = 0; c < num_ch; c++) flush_rx(c);
}

/* Acumula en rx_acc[ch] hasta `want` bytes o hasta agotar `timeout_us`.
 * Devuelve los bytes recibidos y, si `elapsed_us` no es NULL, escribe en él
 * el tiempo desde `t0` hasta el instante en que llegó el ÚLTIMO byte. */
static size_t wait_rx(uint32_t ch, size_t want, uint64_t t0,
                      uint64_t timeout_us, uint64_t *elapsed_us) {
    if (want > MAX_ACC) want = MAX_ACC;
    size_t got = 0;
    uint64_t last = 0;
    while (got < want && bench_us_since(t0) < timeout_us) {
        size_t n = Transceiver_Read(&uarts[ch], rx_acc[ch] + got, want - got);
        if (n > 0) { got += n; last = bench_us_since(t0); }
    }
    if (elapsed_us) *elapsed_us = last;
    return got;
}

static void settle(uint32_t ms) {
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(ms));
}

/* =========================================================================
 * Censo de recepción: cuántos bytes esperan en el ring SW de CADA canal.
 *
 * Cuando un test no recibe nada en el canal que vigila, la pregunta no es
 * "¿se perdieron los bytes?" sino "¿dónde cayeron?". Si el hardware demultiplexa
 * mal (por ejemplo, si TDEST se pierde por el camino), los bytes existen y el
 * driver los copió, pero al ring de otro canal. Este censo lo distingue.
 *
 * No consume: solo lee el contador del ring, sin sacar bytes.
 * ========================================================================= */
static void rx_census(const char *when) {
    size_t total = 0;
    printf("[CENSO] bytes esperando por canal (%s):\n        ", when);
    for (uint32_t c = 0; c < num_ch; c++) {
        size_t n = __atomic_load_n(&uarts[c].rx_count, __ATOMIC_ACQUIRE);
        total += n;
        printf("CH%u=%-5u", (unsigned)c, (unsigned)n);
        if (c == 6) printf("\n        ");
    }
    printf("\n        total=%u\n", (unsigned)total);
    fflush(stdout);
}

/* =========================================================================
 * Contadores por ventana
 *
 * Los tests necesitan el coste de SU tramo, y el resumen final el de toda la
 * sesión. Reiniciar los contadores dentro de un test destruía el acumulado
 * global, así que en vez de Transceiver_BenchReset se toma una foto al entrar
 * y se resta al salir. Los contadores del driver solo se ponen a cero una vez,
 * al arrancar el benchmark.
 * ========================================================================= */
static void bench_snapshot(Transceiver_BenchStats_t *s) {
    Transceiver_BenchStats(s);
}

/* Rellena `out` con lo ocurrido desde la foto `base`. */
static void bench_delta(const Transceiver_BenchStats_t *base,
                        Transceiver_BenchStats_t *out) {
    Transceiver_BenchStats(out);
    out->irq_tx    -= base->irq_tx;
    out->irq_rx    -= base->irq_rx;
    out->bytes_tx  -= base->bytes_tx;
    out->bytes_rx  -= base->bytes_rx;
    out->err_count -= base->err_count;
}

/* Foto tomada al principio de la sesión, para el resumen de eficiencia. */
static Transceiver_BenchStats_t g_session_base;

/* Ordena in-situ (inserción; n≤LAT_ITERS) para extraer mediana y percentil. */
static void sort_u64(uint64_t *a, size_t n) {
    for (size_t i = 1; i < n; i++) {
        uint64_t v = a[i];
        size_t j = i;
        while (j > 0 && a[j - 1] > v) { a[j] = a[j - 1]; j--; }
        a[j] = v;
    }
}

/* =========================================================================
 * T0 — Autodiagnóstico: ¿hay hardware y hay lazo TX→RX?
 *
 * Los tres bitstreams sacan los 14 canales a pines físicos (LVCMOS18); no hay
 * loopback interno en ninguno. Sin la PCB conectada —o sin al menos un puente
 * de TD[0] a RD[1]— la recepción es imposible y TODOS los tests darían cero.
 * Ese cero no significa "transporte lento", significa "no hay cable", así que
 * conviene distinguirlo antes de medir nada.
 *
 * Devuelve true si el lazo de referencia CH0 → CH1 está cerrado.
 * ========================================================================= */
/* Escaneo de buses: emite por cada maestro y cuenta qué canales oyen.
 *
 * Con el loopback, la línea de recepción de un canal es el AND de las
 * transmisiones del RESTO de su bus. Si un solo canal en reposo tuviera su TD
 * a '0', el AND quedaría clavado y NINGÚN canal de ese bus recibiría, aunque
 * los demás buses funcionaran. Esta matriz distingue "un bus muerto" de "todo
 * muerto", y de paso valida la topología A/B/C. */
static void T0_bus_scan(void) {
    static const uint8_t masters[3] = { 0, 7, 11 };
    static const char   *names[3]   = { "A(0->1..6)", "B(7->8..10)", "C(11->12,13)" };
    uint8_t probe[4];
    fill_pattern(probe, sizeof(probe), 950);

    printf("\n[SCAN] emisor -> receptores que oyen (esperado: los de su bus)\n");
    for (uint32_t m = 0; m < 3; m++) {
        if (masters[m] >= num_ch) continue;
        flush_all_rx();
        settle(SETTLE_MS);

        Transceiver_Send(&uarts[masters[m]], probe, sizeof(probe));
        settle(300);   /* 4 B a 115200 = 350 us; sobra de largo */

        printf("  CH%-2u %-14s oyen:", masters[m], names[m]);
        bool any = false;
        for (uint32_t c = 0; c < num_ch; c++) {
            uint8_t tmp[32];
            size_t n = Transceiver_Read(&uarts[c], tmp, sizeof(tmp));
            if (n > 0) { printf(" CH%u(%uB)", (unsigned)c, (unsigned)n); any = true; }
        }
        if (!any) printf(" nadie");
        printf("\n");
    }
    printf("\n");
    fflush(stdout);
}

static bool T0_selftest(void) {
    uint8_t probe[8];
    fill_pattern(probe, sizeof(probe), 900);

    BENCH_ROW("T0_selftest", "channels", "count", "%u", num_ch, "esperados 14");

    flush_all_rx();
    settle(SETTLE_MS);
    Transceiver_BenchReset();

    uint64_t t0 = bench_cycles();
    int sent = Transceiver_Send(&uarts[BENCH_TX_CH], probe, sizeof(probe));
    size_t got = wait_rx(BENCH_RX_CH, sizeof(probe), t0, 500000ULL, NULL);

    Transceiver_BenchStats_t st;
    Transceiver_BenchStats(&st);

    /* El camino de TX vive aunque nadie escuche: el driver entregó los bytes
     * al hardware y este levantó su interrupción de fin. */
    bool tx_ok   = (sent > 0) && (st.bytes_tx > 0) && (st.irq_tx > 0);
    bool link_ok = (got == sizeof(probe)) &&
                   (count_matches(rx_acc[BENCH_RX_CH], got, 900) == got);

    BENCH_ROW("T0_selftest", "tx_datapath", "bool", "%u", (uint32_t)tx_ok, "el driver mueve bytes al HW");
    BENCH_ROW("T0_selftest", "rx_link",     "bool", "%u", (uint32_t)link_ok, "lazo CH0->CH1 cerrado");
    BENCH_ROW("T0_selftest", "bytes_rx",    "count", "%u", (uint32_t)got, "de 8 enviados");

    if (!tx_ok) {
        printf("\n[BENCH] AVISO: el camino de TX no responde (sent=%d bytes_tx=%llu "
               "irq_tx=%llu).\n"
               "        Revisa que el BOOT.bin grabado sea el de esta variante.\n\n",
               sent, (unsigned long long)st.bytes_tx, (unsigned long long)st.irq_tx);
    } else if (!link_ok) {
        printf("\n[BENCH] AVISO: no hay lazo TX->RX (recibidos %u de 8 bytes).\n"
               "        Con el bitstream de loopback esto NO deberia pasar. Estado del\n"
               "        receptor del canal %u para distinguir 'no armado' de 'no llega nada':\n\n",
               (unsigned)got, (unsigned)BENCH_RX_CH);
        Transceiver_BenchDumpRx(BENCH_RX_CH);
        rx_census("justo tras el sondeo de T0");
        T0_bus_scan();
        printf("        Sin loopback en la PL, conecta la PCB o puentea TD[0] (T11) con\n"
               "        RD[1] (U6): ambos son LVCMOS18 y el puente directo es seguro.\n\n");
    } else {
        printf("[BENCH] Autodiagnostico OK: %u canales, lazo CH0->CH1 cerrado.\n", num_ch);
    }
    fflush(stdout);
    return link_ok;
}

/* =========================================================================
 * T1 — Latencia de ida y vuelta de un frame corto
 *
 * Mide el tiempo desde justo antes de Send hasta que el receptor tiene el
 * frame completo. Incluye el tiempo de bit de la UART, que es idéntico en las
 * tres variantes; la diferencia entre ellas es el overhead del transporte.
 * ========================================================================= */
static void T1_latency(void) {
    uint8_t frame[MAX_FRAME];
    uint8_t data[LAT_PAYLOAD];
    uint64_t samples[LAT_ITERS];
    uint32_t timeouts = 0, n = 0;

    fill_pattern(data, sizeof(data), 0);
    size_t flen = build_frame(frame, BENCH_RX_CH, BENCH_TX_CH, CMD_PING,
                              data, LAT_PAYLOAD);

    for (uint32_t i = 0; i < LAT_ITERS; i++) {
        flush_rx(BENCH_RX_CH);
        settle(5);

        uint64_t t0 = bench_cycles();
        Transceiver_Send(&uarts[BENCH_TX_CH], frame, flen);

        uint64_t el = 0;
        size_t got = wait_rx(BENCH_RX_CH, flen, t0, 500000ULL, &el);
        if (got == flen) samples[n++] = el; else timeouts++;
    }

    if (n == 0) {
        BENCH_ROW("T1_latency", "samples", "count", "%u", 0u, "sin recepcion");
        BENCH_ROW("T1_latency", "timeouts", "count", "%u", timeouts, "");
        return;
    }

    sort_u64(samples, n);
    uint64_t sum = 0;
    for (uint32_t i = 0; i < n; i++) sum += samples[i];
    uint64_t avg = sum / n;
    uint64_t p50 = samples[n / 2];
    uint64_t p95 = samples[(n * 95) / 100 >= n ? n - 1 : (n * 95) / 100];
    uint64_t max = samples[n - 1];

    BENCH_ROW("T1_latency", "avg",      "us", "%" PRIu64, avg, "frame de 11 B");
    BENCH_ROW("T1_latency", "p50",      "us", "%" PRIu64, p50, "");
    BENCH_ROW("T1_latency", "p95",      "us", "%" PRIu64, p95, "");
    BENCH_ROW("T1_latency", "max",      "us", "%" PRIu64, max, "");
    BENCH_ROW("T1_latency", "timeouts", "count", "%u", timeouts, "");
}

/* =========================================================================
 * T2 — Throughput de un solo canal
 *
 * SANITY CHECK: a 115200 8N1 (10 bits por byte) el techo físico es
 * 11520 B/s. Un resultado muy por encima significa que se está midiendo el
 * retorno de un Send no bloqueante, no la transmisión real.
 * ========================================================================= */
static void T2_throughput_1ch(void) {
    static uint8_t tx[THR_BYTES];
    fill_pattern(tx, sizeof(tx), 100);

    /* El throughput se calcula sobre los bytes que REALMENTE llegan. Exigir el
     * bloque completo hacía que la pérdida de un solo byte de 1024 reportara
     * throughput 0, confundiendo "transporte lento" con "transporte con
     * pérdidas". La integridad se mide aparte, en bytes_ok. */
    uint64_t total_us = 0;
    uint64_t total_rx = 0;
    size_t   total_ok = 0;
    uint32_t reps_ok  = 0, reps_full = 0;

    for (uint32_t r = 0; r < THR_REPS; r++) {
        flush_rx(BENCH_RX_CH);
        settle(SETTLE_MS);

        uint64_t t0 = bench_cycles();
        Transceiver_Send(&uarts[BENCH_TX_CH], tx, THR_BYTES);

        uint64_t el = 0;
        size_t got = wait_rx(BENCH_RX_CH, THR_BYTES, t0, RX_TIMEOUT_US, &el);
        total_ok += count_matches(rx_acc[BENCH_RX_CH], got, 100);

        if (got > 0 && el > 0) { total_us += el; total_rx += got; reps_ok++; }
        if (got == THR_BYTES)  reps_full++;

        /* Si el canal vigilado no recibió el bloque entero, mirar dónde están
         * los bytes: puede que el hardware los haya entregado a otro canal. */
        if (r == 0 && got < THR_BYTES) {
            printf("\n[BENCH] T2: recibidos %u de %u bytes en CH%u.\n",
                   (unsigned)got, (unsigned)THR_BYTES, (unsigned)BENCH_RX_CH);
            rx_census("tras la 1a repeticion de T2, sin vaciar los rings");
            /* CH1 es el canal que enmudece; CH2 recibe el mismo estímulo por el
             * mismo bus y sigue vivo. Volcar los dos y comparar sus registros
             * dice qué distingue al canal muerto del sano. */
            printf("--- canal MUDO:\n");
            Transceiver_BenchDumpRx(BENCH_RX_CH);
            printf("--- canal SANO (mismo bus, mismo estimulo):\n");
            Transceiver_BenchDumpRx(2);
            printf("\n");
        }
    }

    if (reps_ok == 0) {
        BENCH_ROW("T2_throughput_1ch", "throughput", "B/s", "%u", 0u,
                  "no llego ningun byte");
        return;
    }

    uint64_t avg_us = total_us / reps_ok;
    uint64_t avg_rx = total_rx / reps_ok;
    uint64_t bps    = avg_rx * 1000000ULL / avg_us;
    uint64_t exp_ok = (uint64_t)THR_BYTES * THR_REPS;

    BENCH_ROW("T2_throughput_1ch", "throughput",  "B/s",   "%" PRIu64, bps, "115200 8N1: techo 11520");
    BENCH_ROW("T2_throughput_1ch", "elapsed",     "us",    "%" PRIu64, avg_us, "por bloque de 1024 B");
    BENCH_ROW("T2_throughput_1ch", "reps_full",   "count", "%u", reps_full, "repeticiones sin perdidas, de 5");
    BENCH_ROW("T2_throughput_1ch", "bytes_ok",    "count", "%" PRIu64, (uint64_t)total_ok, "");
    BENCH_ROW("T2_throughput_1ch", "bytes_rx",    "count", "%" PRIu64, total_rx, "");
    BENCH_ROW("T2_throughput_1ch", "bytes_total", "count", "%" PRIu64, exp_ok, "");
}

/* =========================================================================
 * T3 — Throughput agregado con los tres maestros transmitiendo a la vez
 *
 * Aquí se separan las arquitecturas: DMA14 y GPIO tienen un recurso de TX por
 * canal y pueden solapar; MCDMA tiene un único canal MM2S serializado por
 * semáforo, así que los tres envíos se encolan.
 * ========================================================================= */
static const uint8_t g_masters[BENCH_N_BUSES]   = BENCH_MASTERS;
static const uint8_t g_listeners[BENCH_N_BUSES] = BENCH_LISTENERS;

static rtems_id g_start_sem;    /* barrera de arranque */
static rtems_id g_done_sem;     /* cuenta las tareas TX que han terminado */
static uint8_t  g_conc_tx[BENCH_N_BUSES][CONC_BYTES];

static rtems_task Conc_TX_Task(rtems_task_argument arg) {
    uint32_t idx = (uint32_t)arg;
    rtems_semaphore_obtain(g_start_sem, RTEMS_WAIT, RTEMS_NO_TIMEOUT);
    Transceiver_Send(&uarts[g_masters[idx]], g_conc_tx[idx], CONC_BYTES);
    rtems_semaphore_release(g_done_sem);
    rtems_task_delete(RTEMS_SELF);
}

static void T3_throughput_concurrent(void) {
    for (uint32_t i = 0; i < BENCH_N_BUSES; i++)
        fill_pattern(g_conc_tx[i], CONC_BYTES, 200 + i * 1000);

    flush_all_rx();
    settle(SETTLE_MS);

    rtems_semaphore_create(rtems_build_name('B','S','T','A'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0, &g_start_sem);
    rtems_semaphore_create(rtems_build_name('B','D','O','N'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0, &g_done_sem);

    /* Prioridad 110: por encima de la tarea de benchmark (120), por debajo de
     * las tareas de recepción de los drivers. */
    for (uint32_t i = 0; i < BENCH_N_BUSES; i++) {
        rtems_id t;
        rtems_task_create(rtems_build_name('B','T','X','0' + (char)i), 110,
                          RTEMS_MINIMUM_STACK_SIZE * 2,
                          RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &t);
        rtems_task_start(t, Conc_TX_Task, (rtems_task_argument)i);
    }
    settle(20);   /* dejar que las tres tareas lleguen a la barrera */

    uint64_t t0 = bench_cycles();
    for (uint32_t i = 0; i < BENCH_N_BUSES; i++)
        rtems_semaphore_release(g_start_sem);   /* arrancan a la vez */

    /* El cronómetro para cuando el último receptor tiene sus bytes. */
    uint64_t last_us = 0;
    size_t   total_got = 0, total_ok = 0;
    for (uint32_t i = 0; i < BENCH_N_BUSES; i++) {
        uint64_t el = 0;
        size_t got = wait_rx(g_listeners[i], CONC_BYTES, t0, RX_TIMEOUT_US, &el);
        total_got += got;
        total_ok  += count_matches(rx_acc[g_listeners[i]], got, 200 + i * 1000);
        if (el > last_us) last_us = el;
    }

    for (uint32_t i = 0; i < BENCH_N_BUSES; i++)
        rtems_semaphore_obtain(g_done_sem, RTEMS_WAIT,
                               RTEMS_MILLISECONDS_TO_TICKS(2000));
    rtems_semaphore_delete(g_start_sem);
    rtems_semaphore_delete(g_done_sem);

    uint64_t expect = (uint64_t)CONC_BYTES * BENCH_N_BUSES;
    /* Sobre los bytes efectivamente recibidos, no sobre los esperados. */
    uint64_t bps = last_us ? ((uint64_t)total_got * 1000000ULL / last_us) : 0;

    BENCH_ROW("T3_tx_concurrent", "throughput",  "B/s",   "%" PRIu64, bps, "3 maestros en paralelo");
    BENCH_ROW("T3_tx_concurrent", "elapsed",     "us",    "%" PRIu64, last_us, "hasta el ultimo byte");
    BENCH_ROW("T3_tx_concurrent", "bytes_ok",    "count", "%" PRIu64, (uint64_t)total_ok, "");
    BENCH_ROW("T3_tx_concurrent", "bytes_total", "count", "%" PRIu64, expect, "");
    BENCH_ROW("T3_tx_concurrent", "bytes_rx",    "count", "%" PRIu64, (uint64_t)total_got, "");
}

/* =========================================================================
 * T4 — Recepción simultánea: multidrop del bus A
 *
 * El maestro CH0 emite una vez; los 6 esclavos del bus reciben en paralelo.
 * Mide la capacidad del transporte de atender 6 flujos de RX a la vez, y de
 * paso verifica la integridad del multidrop.
 * ========================================================================= */
static const uint8_t g_busa[BENCH_BUSA_N] = BENCH_BUSA_SLAVES;

static void T4_rx_multidrop(void) {
    static uint8_t tx[MULTIDROP_BYTES];
    fill_pattern(tx, sizeof(tx), 300);

    flush_all_rx();
    settle(SETTLE_MS);

    uint64_t t0 = bench_cycles();
    Transceiver_Send(&uarts[BENCH_TX_CH], tx, MULTIDROP_BYTES);

    uint64_t last_us = 0;
    uint32_t full = 0;
    size_t   total_ok = 0, total_got = 0;
    for (uint32_t i = 0; i < BENCH_BUSA_N; i++) {
        uint64_t el = 0;
        size_t got = wait_rx(g_busa[i], MULTIDROP_BYTES, t0, RX_TIMEOUT_US, &el);
        total_got += got;
        total_ok += count_matches(rx_acc[g_busa[i]], got, 300);
        if (got == MULTIDROP_BYTES) full++;
        if (el > last_us) last_us = el;
    }

    uint64_t expect = (uint64_t)MULTIDROP_BYTES * BENCH_BUSA_N;
    uint64_t bps = last_us ? ((uint64_t)total_got * 1000000ULL / last_us) : 0;

    BENCH_ROW("T4_rx_multidrop", "throughput",   "B/s",   "%" PRIu64, bps, "6 receptores simultaneos");
    BENCH_ROW("T4_rx_multidrop", "elapsed",      "us",    "%" PRIu64, last_us, "");
    BENCH_ROW("T4_rx_multidrop", "listeners_ok", "count", "%u", full, "de 6");
    BENCH_ROW("T4_rx_multidrop", "bytes_ok",     "count", "%" PRIu64, (uint64_t)total_ok, "");
    BENCH_ROW("T4_rx_multidrop", "bytes_rx",     "count", "%" PRIu64, (uint64_t)total_got, "");
    BENCH_ROW("T4_rx_multidrop", "bytes_total",  "count", "%" PRIu64, expect, "");
}

/* =========================================================================
 * T5 — Overrun: el productor va más rápido que el consumidor
 *
 * Se envían OVERRUN_BYTES (8 KB) sin leer el ring SW (4 KB). Los bytes que no
 * caben se pierden; el driver los contabiliza en err_count. Mide cómo degrada
 * cada transporte cuando la aplicación no consume a tiempo.
 * ========================================================================= */
static void T5_overrun(void) {
    static uint8_t tx[512];
    fill_pattern(tx, sizeof(tx), 400);

    flush_all_rx();
    settle(SETTLE_MS);

    Transceiver_BenchStats_t base, st;
    bench_snapshot(&base);

    /* Enviar sin leer nunca el canal receptor. Se espera entre bloques para no
     * desbordar la cola de TX: lo que se quiere provocar es el overrun del ring
     * de RX, no un fallo de encolado en TX (que en GPIO devolvería -1 y
     * contaminaría el recuento de bytes perdidos). */
    uint32_t tx_fail = 0;
    for (uint32_t i = 0; i < OVERRUN_BYTES / sizeof(tx); i++) {
        if (Transceiver_Send(&uarts[BENCH_TX_CH], tx, sizeof(tx)) < 0) tx_fail++;
        settle(60);   /* 512 B a 115200 ≈ 44 ms */
    }

    settle(1000);   /* dejar que se drene la TX y llegue todo lo que vaya a llegar */

    bench_delta(&base, &st);

    /* Vaciar el ring y comprobar que el canal sigue vivo después. */
    size_t drained = 0, n;
    uint8_t tmp[MAX_FRAME];
    while ((n = Transceiver_Read(&uarts[BENCH_RX_CH], tmp, sizeof(tmp))) > 0)
        drained += n;

    BENCH_ROW("T5_overrun", "bytes_sent",   "count", "%u", (uint32_t)OVERRUN_BYTES, "ring SW = 4096 B");
    BENCH_ROW("T5_overrun", "bytes_rx",     "count", "%" PRIu64, st.bytes_rx, "aceptados por el ring");
    BENCH_ROW("T5_overrun", "bytes_lost",   "count", "%" PRIu64, st.err_count, "descartados por overrun");
    BENCH_ROW("T5_overrun", "bytes_drained","count", "%" PRIu64, (uint64_t)drained, "");
    BENCH_ROW("T5_overrun", "tx_fail",      "count", "%u", tx_fail, "envios rechazados por cola TX llena");
}

/* =========================================================================
 * T6 — Barrido de velocidad: dónde se rompe cada transporte
 *
 * Por cada baudrate: reprograma los 14 UARTs, envía un bloque y cuenta bytes
 * correctos. El punto en que bytes_ok deja de ser 100 % es el límite práctico.
 * ========================================================================= */
static void T6_baud_sweep(void) {
    static uint8_t tx[THR_BYTES];

    for (uint32_t b = 0; b < N_BAUDS; b++) {
        for (uint32_t c = 0; c < num_ch; c++)
            Transceiver_SetBaud(&uarts[c], g_bauds[b].sel);
        settle(BAUD_SETTLE_MS);
        flush_all_rx();

        uint32_t seed = 500 + b * 1000;
        fill_pattern(tx, sizeof(tx), seed);

        Transceiver_BenchStats_t base, st;
        bench_snapshot(&base);

        uint64_t t0 = bench_cycles();
        Transceiver_Send(&uarts[BENCH_TX_CH], tx, THR_BYTES);

        uint64_t el = 0;
        size_t got = wait_rx(BENCH_RX_CH, THR_BYTES, t0, RX_TIMEOUT_US, &el);
        size_t ok  = count_matches(rx_acc[BENCH_RX_CH], got, seed);

        bench_delta(&base, &st);

        /* Throughput sobre lo recibido, no sobre lo esperado: a baudrates altos
         * el interés está en ver cuánto se pierde, no en anular la medida. */
        uint64_t bps = el ? ((uint64_t)got * 1000000ULL / el) : 0;
        uint64_t irqs = st.irq_tx + st.irq_rx;
        /* IRQs por KB transferido: la métrica que explica el coste de CPU. */
        uint64_t irq_per_kb = got ? (irqs * 1024ULL / got) : 0;

        BENCH_ROW("T6_baud_sweep", "throughput",  "B/s",   "%" PRIu64, bps, g_bauds[b].name);
        BENCH_ROW("T6_baud_sweep", "bytes_ok",    "count", "%" PRIu64, (uint64_t)ok, g_bauds[b].name);
        BENCH_ROW("T6_baud_sweep", "bytes_rx",    "count", "%" PRIu64, (uint64_t)got, g_bauds[b].name);
        BENCH_ROW("T6_baud_sweep", "bytes_total", "count", "%u", (uint32_t)THR_BYTES, g_bauds[b].name);
        BENCH_ROW("T6_baud_sweep", "irq_per_kb",  "count", "%" PRIu64, irq_per_kb, g_bauds[b].name);
        BENCH_ROW("T6_baud_sweep", "errors",      "count", "%" PRIu64, st.err_count, g_bauds[b].name);
    }

    /* Restaurar la velocidad de referencia para los tests siguientes. */
    for (uint32_t c = 0; c < num_ch; c++)
        Transceiver_SetBaud(&uarts[c], TRANSCEIVER_BAUD_115200);
    settle(BAUD_SETTLE_MS);
}

/* =========================================================================
 * T7 — Inyección de error y recuperación
 *
 * Se emiten tres frames corruptos (checksum malo, longitud truncada, ruido) y
 * se comprueba que el parser los rechaza. Después se envía un PING válido: si
 * llega, el canal se recuperó y el transporte no quedó desincronizado.
 * ========================================================================= */
static void T7_error_recovery(void) {
    uint8_t frame[MAX_FRAME], data[LAT_PAYLOAD];
    uint8_t d_dst, d_src, d_cmd, d_len, d_data[MAX_FRAME];
    uint32_t rejected = 0;

    fill_pattern(data, sizeof(data), 600);

    for (uint32_t k = 0; k < 3; k++) {
        flush_rx(BENCH_RX_CH);
        settle(SETTLE_MS);

        size_t flen = build_frame(frame, BENCH_RX_CH, BENCH_TX_CH, CMD_PING,
                                  data, LAT_PAYLOAD);
        size_t send_len = flen;
        switch (k) {
            case 0: frame[flen - 2] ^= 0xFF; break;        /* checksum corrupto */
            case 1: send_len = flen - 4;     break;        /* frame truncado */
            default: for (size_t i = 2; i < flen; i++) frame[i] ^= 0x5A; break;
        }

        uint64_t t0 = bench_cycles();
        Transceiver_Send(&uarts[BENCH_TX_CH], frame, send_len);
        size_t got = wait_rx(BENCH_RX_CH, send_len, t0, 500000ULL, NULL);

        if (!parse_frame(rx_acc[BENCH_RX_CH], got, &d_dst, &d_src,
                         &d_cmd, d_data, &d_len))
            rejected++;
    }

    /* ¿Sigue vivo el canal tras los tres frames corruptos? */
    flush_rx(BENCH_RX_CH);
    settle(SETTLE_MS);
    size_t flen = build_frame(frame, BENCH_RX_CH, BENCH_TX_CH, CMD_PING,
                              data, LAT_PAYLOAD);
    uint64_t t0 = bench_cycles();
    Transceiver_Send(&uarts[BENCH_TX_CH], frame, flen);
    size_t got = wait_rx(BENCH_RX_CH, flen, t0, 500000ULL, NULL);
    bool recovered = parse_frame(rx_acc[BENCH_RX_CH], got, &d_dst, &d_src,
                                 &d_cmd, d_data, &d_len) && d_cmd == CMD_PING;

    BENCH_ROW("T7_error_recovery", "rejected",  "count", "%u", rejected, "de 3 frames corruptos");
    BENCH_ROW("T7_error_recovery", "recovered", "bool",  "%u", (uint32_t)recovered, "PING valido tras el error");
}

/* =========================================================================
 * Coste estructural del driver: memoria, IRQs y objetos de RTEMS.
 * ========================================================================= */
static void report_footprint(void) {
    Transceiver_BenchStats_t st;
    Transceiver_BenchStats(&st);

    BENCH_ROW("footprint", "static_bytes",  "B",     "%" PRIu64, st.static_bytes, "buffers en .bss");
    BENCH_ROW("footprint", "heap_bytes",    "B",     "%" PRIu64, st.heap_bytes, "buffers con malloc");
    BENCH_ROW("footprint", "total_bytes",   "B",     "%" PRIu64, st.static_bytes + st.heap_bytes, "");
    BENCH_ROW("footprint", "irq_lines",     "count", "%u", st.irq_lines, "lineas PL->PS");
    BENCH_ROW("footprint", "isr_count",     "count", "%u", st.isr_count, "");
    BENCH_ROW("footprint", "task_count",    "count", "%u", st.task_count, "tareas del driver");
    BENCH_ROW("footprint", "sem_count",     "count", "%u", st.sem_count, "semaforos del driver");
    BENCH_ROW("footprint", "tx_blocking",   "bool",  "%u", (uint32_t)st.tx_blocking, "Send espera a la TX fisica");
    BENCH_ROW("footprint", "tx_concurrent", "bool",  "%u", (uint32_t)st.tx_concurrent, "varios canales TX a la vez");
    BENCH_ROW("footprint", "channels",      "count", "%u", num_ch, "");
}

/* Coste por byte acumulado durante toda la sesión de tests. Se calcula como
 * delta contra la foto tomada al arrancar, así que ningún test intermedio
 * puede falsearlo poniendo los contadores a cero. */
static void report_efficiency(void) {
    Transceiver_BenchStats_t st;
    bench_delta(&g_session_base, &st);

    uint64_t bytes = st.bytes_tx + st.bytes_rx;
    uint64_t irqs  = st.irq_tx + st.irq_rx;
    uint64_t per_kb = bytes ? (irqs * 1024ULL / bytes) : 0;

    BENCH_ROW("efficiency", "irq_tx",     "count", "%" PRIu64, st.irq_tx, "");
    BENCH_ROW("efficiency", "irq_rx",     "count", "%" PRIu64, st.irq_rx, "");
    BENCH_ROW("efficiency", "bytes_tx",   "count", "%" PRIu64, st.bytes_tx, "");
    BENCH_ROW("efficiency", "bytes_rx",   "count", "%" PRIu64, st.bytes_rx, "");
    BENCH_ROW("efficiency", "irq_per_kb", "count", "%" PRIu64, per_kb, "IRQs por KB transferido");
    BENCH_ROW("efficiency", "errors",     "count", "%" PRIu64, st.err_count, "");
}

/* =========================================================================
 * Tarea de benchmark — prioridad 120, la más baja del sistema.
 * ========================================================================= */
static rtems_task Bench_Task(rtems_task_argument arg) {
    (void)arg;

    printf("\n=== BENCHMARK DE TRANSPORTE: %s ===\n", BENCH_VARIANT_NAME);
    printf("Reloj del sistema: %" PRIu64 " Hz\n", bench_freq_hz());
    bench_csv_header();

    report_footprint();

    /* El footprint y el coste de hardware son válidos aunque no haya cableado;
     * el resto de tests no. Se ejecutan igualmente para dejar constancia, pero
     * el aviso de T0 explica por qué salen a cero. */
    bool link = T0_selftest();
    if (!link)
        printf("[BENCH] Continuando sin lazo: las cifras de T1..T7 no son comparables.\n");

    /* Único punto en el que se ponen a cero los contadores del driver. A partir
     * de aquí cada test mide su tramo por diferencia (bench_snapshot/bench_delta),
     * y report_efficiency mide toda la sesión contra esta misma foto. */
    Transceiver_BenchReset();
    bench_snapshot(&g_session_base);

    T1_latency();
    T2_throughput_1ch();
    T3_throughput_concurrent();
    T4_rx_multidrop();
    T5_overrun();
    T6_baud_sweep();
    T7_error_recovery();

    report_efficiency();

    printf("=== FIN DEL BENCHMARK: %s ===\n", BENCH_VARIANT_NAME);
    fflush(stdout);

    rtems_task_suspend(RTEMS_SELF);
}

/* =========================================================================
 * Init — descubre el hardware, configura los canales y lanza el benchmark.
 * ========================================================================= */
rtems_task Init(rtems_task_argument arg) {
    (void)arg;

    /* Mapear la región AXI de la PL en la MMU. Sin esto, el primer acceso a
     * 0xA000_0000 (SysInfo, registros del DMA…) provoca un Data Abort. Debe
     * ocurrir antes de cualquier lectura del hardware. */
    extern void mmu_map_pl_axi_early(void);
    mmu_map_pl_axi_early();

    settle(500);   /* dejar que se estabilice la consola */

    num_ch = Transceiver_Global_INIT();
    if (num_ch == 0) {
        printf("[BENCH] ERROR: no se detectaron canales de hardware\n");
        rtems_task_suspend(RTEMS_SELF);
    }
    if (num_ch > MAX_TRANSCEIVERS) num_ch = MAX_TRANSCEIVERS;

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

    /* El benchmark corre por debajo de las tareas de recepción de los drivers
     * (prio 10 y 50) para que su sondeo no compita con la ruta de datos. */
    rtems_id t;
    rtems_task_create(rtems_build_name('B','N','C','H'), 120,
                      RTEMS_MINIMUM_STACK_SIZE * 8,
                      RTEMS_DEFAULT_MODES, RTEMS_FLOATING_POINT, &t);
    rtems_task_start(t, Bench_Task, 0);

    rtems_task_suspend(RTEMS_SELF);
}
