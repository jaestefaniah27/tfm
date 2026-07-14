/*
 * main.c — App de testing de la PCB (14 drivers RS485/RS422)
 *
 * Escenario REALISTA: la ZCU102 hace de controlador de un bus de campo. Unos
 * canales actúan de MAESTRO (ordenan datos/control a sensores y actuadores) y
 * otros de ESCLAVO (periféricos que responden). Todo corre en la ZCU102, que
 * orquesta ambos lados sobre los buses FÍSICOS de la PCB.
 *
 * Topología física de la PCB (jumpers externos):
 *   Bus A (RS485 multidrop):  maestro CH0  | esclavos CH1..CH6
 *   Bus B (RS422 maestro/escl): maestro CH7  | esclavos CH8..CH10
 *   Bus C (RS422 maestro/escl): maestro CH11 | esclavos CH12..CH13
 *
 * Protocolo (request/response, half-duplex):
 *   Frame: [SOF=0xAA][DST][SRC][CMD][LEN][DATA..LEN][CHK]
 *     CHK = XOR(DST..último byte de DATA)
 *   Comandos:
 *     PING           → el esclavo responde PONG (eco de id)
 *     READ_SENSOR    → el esclavo responde con su lectura (2 bytes, big-endian)
 *     WRITE_ACTUATOR → el maestro fija un setpoint; el esclavo responde ACK+eco
 *
 * El test, por cada (maestro→esclavo), envía la orden desde el canal maestro,
 * ejecuta la lógica del esclavo (lee su RX, responde por su canal), y verifica
 * que el maestro recibe la respuesta correcta. Cuenta PASS/FAIL.
 */

#include <rtems.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include "transceiver.h"

/* =========================================================================
 * Parámetros de temporización (half-duplex RS485 con settling de DE ~100us)
 * ========================================================================= */
#define TURNAROUND_MS   60     /* margen tras cada transmisión (bus libre) */
#define RXWAIT_MS       40     /* espera a que llegue una respuesta */
#define MAX_FRAME       64

/* =========================================================================
 * Protocolo
 * ========================================================================= */
#define SOF             0xAAU

#define CMD_PING            0x01U
#define CMD_READ_SENSOR     0x02U
#define CMD_WRITE_ACTUATOR  0x03U

#define RSP_PONG            0x81U
#define RSP_SENSOR          0x82U
#define RSP_ACK             0x83U

/* Lectura simulada de cada sensor (distinta por canal, + contador de ronda) */
static uint16_t sim_sensor_value(uint32_t ch, uint32_t round) {
    return (uint16_t)(0x1000u + (ch << 4) + (round & 0xF));
}

/* =========================================================================
 * Estado global
 * ========================================================================= */
static uint32_t    num_transceivers;
static Transceiver uarts[MAX_TRANSCEIVERS];

/* Setpoint "escrito" en cada actuador (para verificar WRITE_ACTUATOR) */
static uint8_t actuator_setpoint[MAX_TRANSCEIVERS];

/* =========================================================================
 * Topología de buses
 * ========================================================================= */
typedef struct {
    const char *name;
    uint8_t     master;
    uint8_t     slaves[8];
    uint8_t     n_slaves;
} Bus;

static const Bus g_buses[] = {
    { "A (RS485 multidrop)", 0,  {1,2,3,4,5,6}, 6 },
    { "B (RS422 m/s)",       7,  {8,9,10},      3 },
    { "C (RS422 m/s)",       11, {12,13},       2 },
};
#define N_BUSES (sizeof(g_buses)/sizeof(g_buses[0]))

/* =========================================================================
 * Construcción / parseo de frames
 * ========================================================================= */
/* Construye un frame en out[], devuelve longitud total. */
static size_t build_frame(uint8_t *out, uint8_t dst, uint8_t src,
                          uint8_t cmd, const uint8_t *data, uint8_t len) {
    size_t i = 0;
    out[i++] = SOF;
    out[i++] = dst;
    out[i++] = src;
    out[i++] = cmd;
    out[i++] = len;
    for (uint8_t k = 0; k < len; k++) out[i++] = data[k];
    uint8_t chk = 0;
    for (size_t j = 1; j < i; j++) chk ^= out[j];   /* CHK sobre DST..DATA */
    out[i++] = chk;
    return i;
}

/* Busca y valida un frame dentro de buf[]. Devuelve true si encontró uno
 * bien formado (SOF + CHK correcto), y rellena los campos de salida. */
static bool parse_frame(const uint8_t *buf, size_t n,
                        uint8_t *dst, uint8_t *src, uint8_t *cmd,
                        uint8_t *data, uint8_t *len) {
    for (size_t off = 0; off + 6 <= n; off++) {
        if (buf[off] != SOF) continue;
        uint8_t l = buf[off + 4];
        size_t total = 5 + (size_t)l + 1;   /* SOF DST SRC CMD LEN + DATA + CHK */
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
 * Helpers
 * ========================================================================= */
static void flush_rx(uint32_t ch) {
    uint8_t tmp[MAX_FRAME];
    while (Transceiver_Read(&uarts[ch], tmp, sizeof(tmp)) > 0) { }
}

static size_t collect_rx(uint32_t ch, uint8_t *buf, size_t maxlen, uint32_t wait_ms) {
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(wait_ms));
    size_t total = 0;
    size_t n;
    do {
        n = Transceiver_Read(&uarts[ch], buf + total, maxlen - total);
        total += n;
    } while (n > 0 && total < maxlen);
    return total;
}

static void print_hex(const uint8_t *b, size_t n) {
    for (size_t i = 0; i < n; i++) printf("%02X ", b[i]);
}

/* =========================================================================
 * Lógica del ESCLAVO (la ejecuta la app por el canal del esclavo)
 *
 * Lee el RX del canal esclavo. Si hay un frame dirigido a él, construye y
 * envía la respuesta adecuada por SU canal. Devuelve true si respondió.
 * ========================================================================= */
static bool slave_service(uint32_t slave_ch, uint32_t round) {
    uint8_t rx[MAX_FRAME];
    size_t n = collect_rx(slave_ch, rx, sizeof(rx), RXWAIT_MS);
    if (n == 0) return false;

    uint8_t dst, src, cmd, data[MAX_FRAME], len;
    if (!parse_frame(rx, n, &dst, &src, &cmd, data, &len)) return false;
    if (dst != slave_ch) return false;   /* no es para este esclavo */

    uint8_t resp[MAX_FRAME];
    uint8_t payload[8];
    size_t  flen = 0;

    switch (cmd) {
    case CMD_PING:
        payload[0] = (uint8_t)slave_ch;
        flen = build_frame(resp, src, (uint8_t)slave_ch, RSP_PONG, payload, 1);
        break;
    case CMD_READ_SENSOR: {
        uint16_t v = sim_sensor_value(slave_ch, round);
        payload[0] = (uint8_t)(v >> 8);
        payload[1] = (uint8_t)(v & 0xFF);
        flen = build_frame(resp, src, (uint8_t)slave_ch, RSP_SENSOR, payload, 2);
        break;
    }
    case CMD_WRITE_ACTUATOR:
        actuator_setpoint[slave_ch] = (len > 0) ? data[0] : 0;
        payload[0] = actuator_setpoint[slave_ch];   /* eco del setpoint aplicado */
        flen = build_frame(resp, src, (uint8_t)slave_ch, RSP_ACK, payload, 1);
        break;
    default:
        return false;
    }

    /* Margen de turnaround: el maestro debe haber soltado el bus (DE bajo) */
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(5));
    Transceiver_Send(&uarts[slave_ch], resp, flen);
    return true;
}

/* =========================================================================
 * Transacción MAESTRO → ESCLAVO completa, con verificación
 * ========================================================================= */
static bool transaction(uint32_t master_ch, uint32_t slave_ch,
                        uint8_t cmd, uint8_t arg, uint32_t round,
                        const char *label) {
    /* Limpiar RX de ambos extremos */
    flush_rx(master_ch);
    flush_rx(slave_ch);

    /* 1) Maestro envía la orden */
    uint8_t req[MAX_FRAME];
    uint8_t a = arg;
    size_t  rlen = build_frame(req, (uint8_t)slave_ch, (uint8_t)master_ch,
                               cmd, (cmd == CMD_WRITE_ACTUATOR) ? &a : NULL,
                               (cmd == CMD_WRITE_ACTUATOR) ? 1 : 0);
    Transceiver_Send(&uarts[master_ch], req, rlen);

    /* 2) El esclavo lee, procesa y responde */
    bool answered = slave_service(slave_ch, round);
    if (!answered) {
        printf("    [FAIL] %-14s CH%u->CH%u: el esclavo no recibio/parseo la orden\n",
               label, (unsigned)master_ch, (unsigned)slave_ch);
        return false;
    }

    /* 3) El maestro lee la respuesta y verifica */
    uint8_t rx[MAX_FRAME];
    size_t  n = collect_rx(master_ch, rx, sizeof(rx), RXWAIT_MS);
    uint8_t dst, src, rcmd, data[MAX_FRAME], len;
    if (!parse_frame(rx, n, &dst, &src, &rcmd, data, &len)) {
        printf("    [FAIL] %-14s CH%u->CH%u: maestro no recibio respuesta valida (rx=%zuB: ",
               label, (unsigned)master_ch, (unsigned)slave_ch, n);
        print_hex(rx, n < 12 ? n : 12); printf(")\n");
        return false;
    }

    /* Validaciones */
    bool ok = (dst == master_ch) && (src == slave_ch);
    uint16_t sensor = 0;
    switch (cmd) {
    case CMD_PING:
        ok = ok && (rcmd == RSP_PONG) && (len == 1) && (data[0] == slave_ch);
        break;
    case CMD_READ_SENSOR:
        sensor = (uint16_t)((data[0] << 8) | data[1]);
        ok = ok && (rcmd == RSP_SENSOR) && (len == 2) &&
             (sensor == sim_sensor_value(slave_ch, round));
        break;
    case CMD_WRITE_ACTUATOR:
        ok = ok && (rcmd == RSP_ACK) && (len == 1) && (data[0] == arg);
        break;
    }

    if (ok) {
        printf("    [PASS] %-14s CH%u->CH%u  ", label, (unsigned)master_ch, (unsigned)slave_ch);
        if (cmd == CMD_READ_SENSOR)         printf("sensor=0x%04X", sensor);
        else if (cmd == CMD_WRITE_ACTUATOR) printf("setpoint=0x%02X ACK", arg);
        else                                printf("PONG");
        printf("\n");
    } else {
        printf("    [FAIL] %-14s CH%u->CH%u  respuesta inesperada: cmd=0x%02X len=%u data=",
               label, (unsigned)master_ch, (unsigned)slave_ch, rcmd, len);
        print_hex(data, len); printf("\n");
    }
    return ok;
}

/* =========================================================================
 * Verificación de bus multidrop: al transmitir el maestro, TODOS los esclavos
 * del bus reciben el frame (aunque solo responda el direccionado).
 * ========================================================================= */
static int multidrop_check(const Bus *bus, uint32_t round) {
    (void)round;
    for (uint8_t k = 0; k < bus->n_slaves; k++) flush_rx(bus->slaves[k]);

    /* El maestro emite un PING dirigido al primer esclavo (broadcast físico) */
    uint8_t req[MAX_FRAME];
    size_t  rlen = build_frame(req, bus->slaves[0], bus->master, CMD_PING, NULL, 0);
    Transceiver_Send(&uarts[bus->master], req, rlen);
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(TURNAROUND_MS));

    int heard = 0;
    for (uint8_t k = 0; k < bus->n_slaves; k++) {
        uint8_t rx[MAX_FRAME];
        size_t n = collect_rx(bus->slaves[k], rx, sizeof(rx), RXWAIT_MS);
        uint8_t dst, src, cmd, data[MAX_FRAME], len;
        bool got = parse_frame(rx, n, &dst, &src, &cmd, data, &len)
                   && (src == bus->master);
        if (got) heard++;
        printf("      CH%-2u %s\n", bus->slaves[k],
               got ? "oyo al maestro [OK]" : "NO oyo al maestro [X]");
    }
    return heard;
}

/* =========================================================================
 * Test principal
 * ========================================================================= */
static void run_pcb_test(void) {
    int checks = 0, passed = 0;
    uint32_t round = 0;

    printf("\n");
    printf("##################################################################\n");
    printf("##  TEST PCB - bus de campo maestro/esclavo (%u canales)\n", num_transceivers);
    printf("##  ZCU102 = controlador. Sensores y actuadores responden.\n");
    printf("##################################################################\n");
    fflush(stdout);

    for (size_t b = 0; b < N_BUSES; b++) {
        const Bus *bus = &g_buses[b];
        if (bus->master >= num_transceivers) continue;

        printf("\n=== Bus %s | maestro CH%u | esclavos:", bus->name, bus->master);
        for (uint8_t k = 0; k < bus->n_slaves; k++) printf(" CH%u", bus->slaves[k]);
        printf(" ===\n");

        /* --- 1) Integridad multidrop: todos oyen al maestro --- */
        printf("  [multidrop] el maestro emite, todos los esclavos deben oirlo:\n");
        int heard = multidrop_check(bus, round);
        checks++;
        if (heard == bus->n_slaves) {
            passed++;
            printf("      -> %d/%d esclavos oyeron al maestro  [PASS]\n", heard, bus->n_slaves);
        } else {
            printf("      -> solo %d/%d esclavos oyeron al maestro  [FAIL]\n", heard, bus->n_slaves);
        }

        /* --- 2) Por cada esclavo: PING, READ_SENSOR, WRITE_ACTUATOR --- */
        for (uint8_t k = 0; k < bus->n_slaves; k++) {
            uint32_t s = bus->slaves[k];
            if (s >= num_transceivers) continue;

            checks++; if (transaction(bus->master, s, CMD_PING, 0, round, "PING")) passed++;
            checks++; if (transaction(bus->master, s, CMD_READ_SENSOR, 0, round, "LEER SENSOR")) passed++;

            uint8_t sp = (uint8_t)(0x20 + s);
            checks++; if (transaction(bus->master, s, CMD_WRITE_ACTUATOR, sp, round, "ESCRIBIR ACT")) passed++;
            fflush(stdout);
        }
        round++;
    }

    printf("\n==============================================================\n");
    if (checks > 0 && passed == checks)
        printf("  >>> TEST PCB SUPERADO <<<  (%d/%d comprobaciones)\n", passed, checks);
    else
        printf("  >>> TEST PCB: %d/%d OK (%d fallos) <<<\n", passed, checks, checks - passed);
    printf("==============================================================\n");
    fflush(stdout);
}

/* =========================================================================
 * Reset de placa
 * ========================================================================= */
static void board_reset(void) {
    printf("\n[RESET] Reset en 3s...\n");
    fflush(stdout);
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(3000));
    __asm__ volatile("msr daifset, #0xf" ::: "memory");
    *(volatile uint32_t *)0xFF5E023CUL |= (1U << 23);
    rtems_shutdown_executive(0);
    for (;;) {}
}

/* =========================================================================
 * Entrada RTEMS
 * ========================================================================= */
rtems_task Init(rtems_task_argument arg) {
    (void)arg;

    extern void mmu_map_pl_axi_early(void);
    mmu_map_pl_axi_early();

    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(500));
    printf("\n=== ZCU102 PCB - 14 drivers RS485/RS422 (bus de campo) ===\n");
    fflush(stdout);

    num_transceivers = Transceiver_Global_INIT();
    if (num_transceivers == 0) {
        printf("ERROR: Transceiver_Global_INIT devolvio 0 canales\n");
        board_reset();
    }
    printf("Detectados %u canales\n\n", (unsigned)num_transceivers);

    static const Transceiver_Config_t cfg = {
        .baud      = TRANSCEIVER_BAUD_115200,
        .data_bits = TRANSCEIVER_DATA_BITS_8,
        .parity    = TRANSCEIVER_PARITY_NONE,
        .stop_bits = TRANSCEIVER_STOP_BITS_1,
        .bit_order = TRANSCEIVER_BIT_ORDER_LSB,
        .slo_mode  = TRANSCEIVER_SLO_OFF,
    };

    for (uint32_t i = 0; i < num_transceivers; i++) {
        rtems_status_code sc = Transceiver_Init(&uarts[i], i, &cfg);
        if (sc != RTEMS_SUCCESSFUL)
            printf("UART %u FAIL (sc=%d)\n", (unsigned)i, sc);
    }
    printf("%u canales inicializados (115200 8N1)\n", (unsigned)num_transceivers);
    fflush(stdout);

    run_pcb_test();

    board_reset();
    rtems_task_delete(RTEMS_SELF);
}
