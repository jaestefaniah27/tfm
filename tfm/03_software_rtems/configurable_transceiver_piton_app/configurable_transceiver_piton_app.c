/*
 * configurable_transceiver_piton_app.c
 *
 * App para RTEMS (PS) que:
 *  - monitoriza continuamente registros AXI GPIO (GPIO0..GPIO3)
 *  - envía por la consola (stdout) las líneas de cambio en formato textual
 *  - recibe comandos por stdin (consola) para modificar registros escribibles
 *
 * Usa la librería transceiver.h para acceder a los registros.
 */

#include <rtems.h>
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdlib.h>

#include "transceiver.h" /* nuestra librería */

/* ---- Messaging helpers (usamos stdout) ---- */
static void send_line_stdout(const char *s) {
  puts(s); /* prints with newline */
  fflush(stdout);
}

/* ---- Compose and emit current register states (dump) ---- */
static void emit_full_dump_stdout(void) {
  char line[256];
  uint32_t g0 = gpio0_read_raw();
  snprintf(line, sizeof(line), "CHG GPIO0.SERIAL_CONFIG RAW=0x%08x BAUD=%u STOP=%u PARITY=%u DATABITS=%u BITORDER=%u",
           g0,
           (unsigned)(g0 & SERIAL_BAUD_MASK),
           (unsigned)((g0 & SERIAL_STOP_MASK) >> 22),
           (unsigned)((g0 & SERIAL_PARITY_MASK) >> 25),
           (unsigned)((g0 & SERIAL_DATA_BITS_MASK) >> 28),
           (unsigned)((g0 & SERIAL_BIT_ORDER_MASK) ? 1 : 0));
  send_line_stdout(line);

  uint32_t g3 = gpio3_read_raw();
  snprintf(line, sizeof(line), "CHG GPIO3.PS_OUT RAW=0x%04x DATA=0x%03x EMPTY=%u TXRDY=%u FULL=%u FRAME_ERR=%u PAR_ERR=%u",
           (unsigned)g3,
           (unsigned)(g3 & PS_OUT_DATA_MASK),
           (unsigned)((g3 & PS_OUT_EMPTY_MASK) ? 1 : 0),
           (unsigned)((g3 & PS_OUT_TX_RDY_MASK) ? 1 : 0),
           (unsigned)((g3 & PS_OUT_FULL_MASK) ? 1 : 0),
           (unsigned)((g3 & PS_OUT_FRAME_ERR_MASK) ? 1 : 0),
           (unsigned)((g3 & PS_OUT_PAR_ERR_MASK) ? 1 : 0));
  send_line_stdout(line);

  uint32_t g1 = gpio1_read_raw();
  snprintf(line, sizeof(line), "CHG GPIO1.RX_CTRL RAW=0x%08x DATA_READ=%u ERROR_OK=%u",
           (unsigned)g1,
           (unsigned)((g1 & GPIO1_DATA_READ_MASK) ? 1 : 0),
           (unsigned)((g1 & GPIO1_ERROR_OK_MASK) ? 1 : 0));
  send_line_stdout(line);

  uint32_t g2 = gpio2_read_raw();
  snprintf(line, sizeof(line), "CHG GPIO2.TX_CTRL RAW=0x%08x DATA_IN=0x%03x TX_SEND=%u",
           (unsigned)g2,
           (unsigned)(g2 & GPIO2_DATA_IN_MASK),
           (unsigned)((g2 & GPIO2_TX_SEND_MASK) ? 1 : 0));
  send_line_stdout(line);
}

/* ---- Snapshot for change detection ---- */
typedef struct {
  uint32_t g0,g1,g2,g3;
} snap_t;
static snap_t prev_snap;

/* ---- Monitor task: poll registers and print diffs to stdout ---- */
static rtems_task monitor_task(rtems_task_argument arg) {
  (void)arg;
  prev_snap.g0 = gpio0_read_raw();
  prev_snap.g1 = gpio1_read_raw();
  prev_snap.g2 = gpio2_read_raw();
  prev_snap.g3 = gpio3_read_raw();

  emit_full_dump_stdout();

  for (;;) {
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(100)); /* 100 ms poll */

    uint32_t g0 = gpio0_read_raw();
    uint32_t g1 = gpio1_read_raw();
    uint32_t g2 = gpio2_read_raw();
    uint32_t g3 = gpio3_read_raw();

    if (g0 != prev_snap.g0) {
      char line[256];
      snprintf(line, sizeof(line), "CHG GPIO0.SERIAL_CONFIG RAW=0x%08x BAUD=%u STOP=%u PARITY=%u DATABITS=%u BITORDER=%u",
               g0,
               (unsigned)(g0 & SERIAL_BAUD_MASK),
               (unsigned)((g0 & SERIAL_STOP_MASK) >> 22),
               (unsigned)((g0 & SERIAL_PARITY_MASK) >> 25),
               (unsigned)((g0 & SERIAL_DATA_BITS_MASK) >> 28),
               (unsigned)((g0 & SERIAL_BIT_ORDER_MASK) ? 1 : 0));
      send_line_stdout(line);
      prev_snap.g0 = g0;
    }
    if (g1 != prev_snap.g1) {
      char line[128];
      snprintf(line, sizeof(line), "CHG GPIO1.RX_CTRL RAW=0x%08x DATA_READ=%u ERROR_OK=%u",
               g1,
               (unsigned)((g1 & GPIO1_DATA_READ_MASK) ? 1 : 0),
               (unsigned)((g1 & GPIO1_ERROR_OK_MASK) ? 1 : 0));
      send_line_stdout(line);
      prev_snap.g1 = g1;
    }
    if (g2 != prev_snap.g2) {
      char line[128];
      snprintf(line, sizeof(line), "CHG GPIO2.TX_CTRL RAW=0x%08x DATA_IN=0x%03x TX_SEND=%u",
               g2,
               (unsigned)(g2 & GPIO2_DATA_IN_MASK),
               (unsigned)((g2 & GPIO2_TX_SEND_MASK) ? 1 : 0));
      send_line_stdout(line);
      prev_snap.g2 = g2;
    }
    if (g3 != prev_snap.g3) {
      char line[256];
      snprintf(line, sizeof(line), "CHG GPIO3.PS_OUT RAW=0x%04x DATA=0x%03x EMPTY=%u TXRDY=%u FULL=%u FRAME_ERR=%u PAR_ERR=%u",
               (unsigned)g3,
               (unsigned)(g3 & PS_OUT_DATA_MASK),
               (unsigned)((g3 & PS_OUT_EMPTY_MASK) ? 1 : 0),
               (unsigned)((g3 & PS_OUT_TX_RDY_MASK) ? 1 : 0),
               (unsigned)((g3 & PS_OUT_FULL_MASK) ? 1 : 0),
               (unsigned)((g3 & PS_OUT_FRAME_ERR_MASK) ? 1 : 0),
               (unsigned)((g3 & PS_OUT_PAR_ERR_MASK) ? 1 : 0));
      send_line_stdout(line);
      prev_snap.g3 = g3;
    }
  }
}

static inline void gpio1_write_data_read_local(uint32_t v)
{
    gpio1_write_data_read(v);
}

static inline void gpio1_write_error_ok_local(uint32_t v)
{
    gpio1_write_error_ok(v);
}
static inline void gpio2_write_data_in_local(uint32_t v)
{
    gpio2_write_data_in(v);
}

static inline void gpio2_write_tx_send_local(uint32_t v)
{
    gpio2_write_tx_send(v);
}

/* ---- Command task: read from stdin (console) and apply commands ---- */
#define CMD_BUF_SZ 256
static rtems_task cmd_task(rtems_task_argument arg) {
    (void)arg;
    char buf[CMD_BUF_SZ];

    for (;;) {

        /* read line */
        if (fgets(buf, sizeof(buf), stdin) == NULL) {
            rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1000));
            continue;
        }

        /* strip newline */
        size_t L = strlen(buf);
        while (L > 0 && (buf[L-1] == '\n' || buf[L-1] == '\r')) { buf[L-1] = 0; --L; }
        if (L == 0) continue;

        /* --------------------- DUMP --------------------- */
        if (strcmp(buf, "DUMP") == 0) {
            emit_full_dump_stdout();
            send_line_stdout("OK");
            continue;
        }

        /* --------------------- GET SERIAL --------------------- */
        if (strncmp(buf, "GET SERIAL", 10) == 0) {
            uint32_t g0 = gpio0_read_raw();
            char out[192];
            snprintf(out, sizeof(out),
                     "CHG GPIO0.SERIAL_CONFIG RAW=0x%08x BAUD=%u STOP=%u PARITY=%u DATABITS=%u BITORDER=%u",
                     g0,
                     (unsigned)(g0 & SERIAL_BAUD_MASK),
                     (unsigned)((g0 & SERIAL_STOP_MASK) >> 22),
                     (unsigned)((g0 & SERIAL_PARITY_MASK) >> 25),
                     (unsigned)((g0 & SERIAL_DATA_BITS_MASK) >> 28),
                     (unsigned)((g0 & SERIAL_BIT_ORDER_MASK) ? 1 : 0));
            send_line_stdout(out);
            send_line_stdout("OK");
            continue;
        }

        /* --------------------- SET SERIAL ... --------------------- */
        if (strncmp(buf, "SET SERIAL ", 11) == 0) {
            char field[32];
            unsigned val;
            if (sscanf(buf + 11, "%31s %u", field, &val) == 2) {
                int matched = 0;

                if (strcmp(field, "BAUD") == 0)   { serial_set_baudrate(val);  matched = 1; }
                else if (strcmp(field, "STOP") == 0)   { serial_set_stop_bits(val);  matched = 1; }
                else if (strcmp(field, "PARITY") == 0) { serial_set_parity(val);      matched = 1; }
                else if (strcmp(field, "DATABITS") == 0){ serial_set_data_bits(val);  matched = 1; }
                else if (strcmp(field, "BITORDER") == 0){ serial_set_bit_order(val);  matched = 1; }

                if (matched) {
                    send_line_stdout("OK");

                    /* Emit immediate CHG */
                    uint32_t g0 = gpio0_read_raw();
                    char out[192];
                    snprintf(out, sizeof(out),
                         "CHG GPIO0.SERIAL_CONFIG RAW=0x%08x BAUD=%u STOP=%u PARITY=%u DATABITS=%u BITORDER=%u",
                         g0,
                         (unsigned)(g0 & SERIAL_BAUD_MASK),
                         (unsigned)((g0 & SERIAL_STOP_MASK) >> 22),
                         (unsigned)((g0 & SERIAL_PARITY_MASK) >> 25),
                         (unsigned)((g0 & SERIAL_DATA_BITS_MASK) >> 28),
                         (unsigned)((g0 & SERIAL_BIT_ORDER_MASK) ? 1 : 0));
                    send_line_stdout(out);
                } else {
                    send_line_stdout("ERR UNKNOWN_FIELD");
                }
            } else {
                send_line_stdout("ERR BAD_ARGS");
            }
            continue;
        }

        /* --------------------- SET GPIO1 ... --------------------- */
        if (strncmp(buf, "SET GPIO1 ", 10) == 0) {
            char field[32];
            unsigned val;
            if (sscanf(buf + 10, "%31s %u", field, &val) == 2) {
                int matched = 0;

                if (strcmp(field, "DATA_READ") == 0) {
                    gpio1_write_data_read(val ? 1 : 0);
                    matched = 1;
                }
                else if (strcmp(field, "ERROR_OK") == 0) {
                    gpio1_write_error_ok(val ? 1 : 0);
                    matched = 1;
                }

                if (matched) {
                    send_line_stdout("OK");

                    /* Emit CHG for GPIO1 */
                    uint32_t g1 = gpio1_read_raw();
                    char out[192];
                    snprintf(out, sizeof(out),
                        "CHG GPIO1.RX_CTRL RAW=0x%08x DATA_READ=%u ERROR_OK=%u",
                        g1,
                        (unsigned)(g1 & 0x1u),
                        (unsigned)((g1 >> 1) & 0x1u));
                    send_line_stdout(out);
                } else {
                    send_line_stdout("ERR UNKNOWN_FIELD");
                }
            } else {
                send_line_stdout("ERR BAD_ARGS");
            }
            continue;
        }

        /* --------------------- SET GPIO2 ... --------------------- */
        if (strncmp(buf, "SET GPIO2 ", 10) == 0) {
            char field[32];
            unsigned val;
            if (sscanf(buf + 10, "%31s %u", field, &val) == 2) {
                int matched = 0;

                if (strcmp(field, "DATA_IN") == 0) {
                    gpio2_write_data_in(val & 0x1FFu);   // 9 bits
                    matched = 1;
                }
                else if (strcmp(field, "TX_SEND") == 0) {
                    gpio2_write_tx_send(val ? 1 : 0);
                    matched = 1;
                }

                if (matched) {
                    send_line_stdout("OK");

                    /* Emit CHG for GPIO2 */
                    uint32_t g2 = gpio2_read_raw();
                    char out[192];
                    snprintf(out, sizeof(out),
                        "CHG GPIO2.TX_CTRL RAW=0x%08x DATA_IN=%u TX_SEND=%u",
                        g2,
                        (unsigned)(g2 & 0x1FFu),
                        (unsigned)((g2 >> 9) & 0x1u));
                    send_line_stdout(out);
                } else {
                    send_line_stdout("ERR UNKNOWN_FIELD");
                }
            } else {
                send_line_stdout("ERR BAD_ARGS");
            }
            continue;
        }

        /* --------------------- TX BYTE --------------------- */
        if (strncmp(buf, "TX BYTE ", 8) == 0) {
            unsigned val;
            if (sscanf(buf + 8, "0x%x", &val) == 1 || sscanf(buf + 8, "%u", &val) == 1) {
                tx_write_data_and_send((uint16_t)(val & 0x1FFu));
                send_line_stdout("OK");
            } else {
                send_line_stdout("ERR BAD_ARGS");
            }
            continue;
        }

        /* --------------------- TX STR "..." (comando extra útil) --------------------- */
        if (strncmp(buf, "TX STR \"", 8) == 0) {
            /* parse simple hasta la siguiente comilla */
            char *start = strchr(buf, '"');
            if (!start) { send_line_stdout("ERR BAD_ARGS"); continue; }
            start++;
            char *end = strchr(start, '"');
            if (!end) { send_line_stdout("ERR BAD_ARGS"); continue; }
            size_t len = (size_t)(end - start);
            if (len == 0) { send_line_stdout("OK"); continue; }
            int r = send_bytes((const uint8_t*)start, len, 50); /* timeout 50ms por byte */
            if (r == 0) send_line_stdout("OK");
            else send_line_stdout("ERR TX_TIMEOUT");
            continue;
        }

        /* --------------------- UNKNOWN --------------------- */
        send_line_stdout("ERR UNKNOWN_COMMAND");
    }
}

/* ---- Task creation helper ---- */
static void start_tasks(void) {
  rtems_status_code sc;
  rtems_id tid;
  rtems_name n1 = rtems_build_name('M','O','N','1');
  sc = rtems_task_create(n1, 120, RTEMS_MINIMUM_STACK_SIZE * 4, RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &tid);
  if (sc == RTEMS_SUCCESSFUL) rtems_task_start(tid, monitor_task, 0);
  else printf("ERR: monitor_task create %d\n", (int)sc);

  rtems_name n2 = rtems_build_name('C','M','D','1');
  sc = rtems_task_create(n2, 130, RTEMS_MINIMUM_STACK_SIZE * 4, RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &tid);
  if (sc == RTEMS_SUCCESSFUL) rtems_task_start(tid, cmd_task, 0);
  else printf("ERR: cmd_task create %d\n", (int)sc);
}

/* ---- Init ---- */
rtems_task Init(rtems_task_argument arg) {
  (void)arg;

  /* mapear PL antes de acceder */
  mmu_map_pl_axi_early();
  rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(10));

  printf("PS serial bridge arrancando. Consola conectada al USB-PS.\n");

  /* inicializa config a valores seguros (puedes cambiar si no quieres esto) */
  serial_set_baudrate(115200u);
  serial_set_stop_bits(2u);
  serial_set_parity(4u);   /* sin paridad según tu map */
  serial_set_data_bits(3u);/* 3 -> 8 bits */
  serial_set_bit_order(0u);

  start_tasks();

  for (;;) rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1000));
}
