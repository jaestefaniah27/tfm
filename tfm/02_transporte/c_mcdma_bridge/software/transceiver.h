/* transceiver.h — AXI MCDMA (PG288, SG mode) + BRIDGE_MCDMA_TOP
 *
 * Hardware (serial_bridge MCDMA asimétrico):
 *   TX: 1 canal MM2S → axis_dwidth 32→8 → BRIDGE_MCDMA_TOP → 14 UARTs
 *       Frame: [{CH_ID[3:0],LEN[11:8]}, {LEN[7:0]}, payload...]
 *   RX: 14 UARTs → BRIDGE_RX_TOP (FIFO por canal + DEMUX + DRAIN) → axis_dwidth 8→32
 *       → 14 canales S2MM, uno por UART
 *
 * Mapa de memoria:
 *   0xA000_0000  AXI_UART_CONFIG  (4 KB, 1 reg×32b por canal, stride=4)
 *   0xA000_1000  TX_ISR_EOF_HANDLER
 *   0xA001_0000  MCDMA ctrl       (64 KB)
 *
 * IRQ:
 *   pl_ps_irq0[0] = mm2s_introut → GIC SPI 89 → RTEMS 121
 *   pl_ps_irq0[1] = s2mm_introut → GIC SPI 90 → RTEMS 122
 */
#ifndef TRANSCEIVER_H
#define TRANSCEIVER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <rtems.h>

#define DEBUG_TRANSCEIVER
#ifdef DEBUG_TRANSCEIVER
  #include <stdio.h>
  #define TRANS_DEBUG(fmt, ...) \
      do { printf("[TRANSCEIVER DEBUG] " fmt, ##__VA_ARGS__); fflush(stdout); } while (0)
#else
  #define TRANS_DEBUG(fmt, ...) do {} while (0)
#endif

#define MAX_TRANSCEIVERS 14

/* =========================================================================
 * Configuración UART por defecto
 * ========================================================================= */
#define TRANSCEIVER_BIT_ORDER_DEFAULT TRANSCEIVER_BIT_ORDER_LSB
#define TRANSCEIVER_DATA_BITS_DEFAULT TRANSCEIVER_DATA_BITS_8
#define TRANSCEIVER_STOP_BITS_DEFAULT TRANSCEIVER_STOP_BITS_1
#define TRANSCEIVER_PARITY_DEFAULT    TRANSCEIVER_PARITY_NONE
#define TRANSCEIVER_BAUD_DEFAULT      TRANSCEIVER_BAUD_115200
#define TRANSCEIVER_SLO_DEFAULT       TRANSCEIVER_SLO_OFF

/* ── Bit order ────────────────────────────────────────────────────────────── */
#define TRANSCEIVER_BIT_ORDER_LSB  0
#define TRANSCEIVER_BIT_ORDER_MSB  1

/* ── Bits de datos ────────────────────────────────────────────────────────── */
#define TRANSCEIVER_DATA_BITS_5  0
#define TRANSCEIVER_DATA_BITS_6  1
#define TRANSCEIVER_DATA_BITS_7  2
#define TRANSCEIVER_DATA_BITS_8  3
#define TRANSCEIVER_DATA_BITS_9  4

/* ── Bits de stop ─────────────────────────────────────────────────────────── */
#define TRANSCEIVER_STOP_BITS_1    0
#define TRANSCEIVER_STOP_BITS_1_5  2
#define TRANSCEIVER_STOP_BITS_2    3

/* ── Paridad ──────────────────────────────────────────────────────────────── */
#define TRANSCEIVER_PARITY_EVEN   0
#define TRANSCEIVER_PARITY_ODD    1
#define TRANSCEIVER_PARITY_MARK   2
#define TRANSCEIVER_PARITY_SPACE  3
#define TRANSCEIVER_PARITY_NONE   4

/* ── SLO ──────────────────────────────────────────────────────────────────── */
#define TRANSCEIVER_SLO_ON   1
#define TRANSCEIVER_SLO_OFF  0

/* ── Baudrates (selector NCO LUT) ─────────────────────────────────────────── */
#define TRANSCEIVER_BAUD_50        0
#define TRANSCEIVER_BAUD_75        1
#define TRANSCEIVER_BAUD_110       2
#define TRANSCEIVER_BAUD_134       3
#define TRANSCEIVER_BAUD_150       4
#define TRANSCEIVER_BAUD_200       5
#define TRANSCEIVER_BAUD_300       6
#define TRANSCEIVER_BAUD_600       7
#define TRANSCEIVER_BAUD_1200      8
#define TRANSCEIVER_BAUD_1800      9
#define TRANSCEIVER_BAUD_2000      10
#define TRANSCEIVER_BAUD_2400      11
#define TRANSCEIVER_BAUD_3600      12
#define TRANSCEIVER_BAUD_4800      13
#define TRANSCEIVER_BAUD_7200      14
#define TRANSCEIVER_BAUD_9600      15
#define TRANSCEIVER_BAUD_12000     16
#define TRANSCEIVER_BAUD_14400     17
#define TRANSCEIVER_BAUD_19200     18
#define TRANSCEIVER_BAUD_28800     19
#define TRANSCEIVER_BAUD_31250     20
#define TRANSCEIVER_BAUD_38400     21
#define TRANSCEIVER_BAUD_50000     22
#define TRANSCEIVER_BAUD_56000     23
#define TRANSCEIVER_BAUD_57600     24
#define TRANSCEIVER_BAUD_64000     25
#define TRANSCEIVER_BAUD_74400     26
#define TRANSCEIVER_BAUD_74880     27
#define TRANSCEIVER_BAUD_76800     28
#define TRANSCEIVER_BAUD_115200    29
#define TRANSCEIVER_BAUD_128000    30
#define TRANSCEIVER_BAUD_153600    31
#define TRANSCEIVER_BAUD_200000    32
#define TRANSCEIVER_BAUD_230400    33
#define TRANSCEIVER_BAUD_250000    34
#define TRANSCEIVER_BAUD_256000    35
#define TRANSCEIVER_BAUD_312500    36
#define TRANSCEIVER_BAUD_400000    37
#define TRANSCEIVER_BAUD_460800    38
#define TRANSCEIVER_BAUD_500000    39
#define TRANSCEIVER_BAUD_576000    40
#define TRANSCEIVER_BAUD_614400    41
#define TRANSCEIVER_BAUD_750000    42
#define TRANSCEIVER_BAUD_921600    43
#define TRANSCEIVER_BAUD_1M        44
#define TRANSCEIVER_BAUD_1_152M    45
#define TRANSCEIVER_BAUD_1_5M      46
#define TRANSCEIVER_BAUD_1_8432M   47
#define TRANSCEIVER_BAUD_2M        48
#define TRANSCEIVER_BAUD_2_5M      49
#define TRANSCEIVER_BAUD_3M        50
#define TRANSCEIVER_BAUD_3_5M      51
#define TRANSCEIVER_BAUD_3_6864M   52
#define TRANSCEIVER_BAUD_4M        53

/* =========================================================================
 * Registro AXI_UART_CONFIG (IP personalizado en BRIDGE_MCDMA)
 *
 * Un registro de 32b por canal, stride=4.
 * Base: 0xA000_0000. Canal N: 0xA000_0000 + N*4.
 * Valor de reset: 0x00001C2B (921600 8N1 LSB).
 * ========================================================================= */
#define UART_CFG_BASE             0xA0000000UL
#define UART_CFG_STRIDE           4U
#define UART_CFG_REG              0x00U

#define UART_CFG_SHIFT_BAUD       0    /* bits[5:0]   baud selector (6b) */
#define UART_CFG_SHIFT_STOP       6    /* bits[7:6]   stop bits (2b)     */
#define UART_CFG_SHIFT_PARITY     8    /* bits[10:8]  parity (3b)        */
#define UART_CFG_SHIFT_DATA_BITS  11   /* bits[13:11] data bits (3b)     */
#define UART_CFG_BIT_ORDER        (1U << 14)
#define UART_CFG_BIT_SLO          (1U << 15)

/* =========================================================================
 * AXI MCDMA — PG288 (Scatter-Gather)
 *
 * Base: 0xA001_0000 (64 KB).
 *
 * MM2S (TX) side base = MCDMA_BASE + 0x000
 *   Canal 1 (único TX): registros a MM2S_BASE + 1*0x40
 *
 * S2MM (RX) side base = MCDMA_BASE + 0x500
 *   Canal N (1..14):   registros a S2MM_BASE + N*0x40
 * ========================================================================= */
#define MCDMA_BASE                0xA0010000UL

/* Offsets comunes de dirección (relativos a MM2S_BASE o S2MM_BASE) */
#define MCDMA_DIR_CCR             0x00U   /* run=bit0, reset=bit2 */
#define MCDMA_DIR_CSR             0x04U   /* halted=bit0 */
#define MCDMA_DIR_CHEN            0x08U   /* bit N-1 = enable canal N */
#define MCDMA_DIR_CHSER           0x0CU   /* último canal servido */

/* Offsets por canal (1-indexed), relativos a MM2S_BASE/S2MM_BASE */
#define MCDMA_CHN_CR(n)           ((n) * 0x40U)           /* Control per-canal */
#define MCDMA_CHN_SR(n)           ((n) * 0x40U + 0x04U)   /* Status per-canal  */
#define MCDMA_CHN_CDESC(n)        ((n) * 0x40U + 0x08U)   /* Current desc [31:0] */
#define MCDMA_CHN_CDESC_MSB(n)    ((n) * 0x40U + 0x0CU)   /* Current desc [63:32] */
#define MCDMA_CHN_TDESC(n)        ((n) * 0x40U + 0x10U)   /* Tail desc [31:0] */
#define MCDMA_CHN_TDESC_MSB(n)    ((n) * 0x40U + 0x14U)   /* Tail desc [63:32] */
#define MCDMA_CHN_PKTDROP(n)      ((n) * 0x40U + 0x18U)   /* pkts descartados (canal sin BD servible) */
#define MCDMA_CHN_PKTCNT(n)       ((n) * 0x40U + 0x1CU)   /* pkts recibidos por la interfaz S_AXIS del canal */

/* Contadores/observadores comunes de la dirección (relativos a S2MM_BASE) */
#define MCDMA_DIR_ERR             0x10U   /* errores comunes */
#define MCDMA_DIR_CPKTDROP        0x14U   /* pkts descartados comunes (coalesce) */
#define MCDMA_DIR_CHOBS1          0x440U  /* observadores internos del motor */
#define MCDMA_DIR_CHOBS2          0x444U
#define MCDMA_DIR_CHOBS3          0x448U
#define MCDMA_DIR_CHOBS4          0x44CU
#define MCDMA_DIR_CHOBS5          0x450U
#define MCDMA_DIR_CHOBS6          0x454U

#define MM2S_BASE                 (MCDMA_BASE + 0x000UL)
#define S2MM_BASE                 (MCDMA_BASE + 0x500UL)

/* CCR global bits */
#define MCDMA_CCR_RS              (1U << 0)
#define MCDMA_CCR_RESET           (1U << 2)

/* Channel CR bits */
#define MCDMA_CH_CR_RS            (1U << 0)
#define MCDMA_CH_CR_IOC_EN        (1U << 5)
#define MCDMA_CH_CR_ERR_EN        (1U << 7)
#define MCDMA_CH_CR_COALESCE(n)   ((uint32_t)(n) << 16)
#define MCDMA_CH_CR_INIT          (MCDMA_CH_CR_RS | MCDMA_CH_CR_IOC_EN | \
                                   MCDMA_CH_CR_ERR_EN | MCDMA_CH_CR_COALESCE(1))

/* Channel SR IRQ bits (W1C para limpiar) */
#define MCDMA_CH_SR_IOC           (1U << 5)
#define MCDMA_CH_SR_ERR           (1U << 7)
#define MCDMA_CH_SR_IRQ_MASK      (MCDMA_CH_SR_IOC | MCDMA_CH_SR_ERR)

/* ── IRQ vectors (c_enable_multi_intr=0 → una línea por dirección) ────────
 * pl_ps_irq0[0] = mm2s_introut → GIC SPI 89 → RTEMS 121
 * pl_ps_irq0[1] = s2mm_introut → GIC SPI 90 → RTEMS 122
 * pl_ps_irq0[2] = EOAF         → GIC SPI 91 → RTEMS 123            */
#define IRQ_MCDMA_MM2S            121
#define IRQ_MCDMA_S2MM            122

/* =========================================================================
 * Scatter-Gather Buffer Descriptor (64 bytes, 16 palabras de 32b)
 *
 * Offsets HW (0x00..0x33, 52 bytes utilizados por el hardware):
 *   0x00 NDESC [31:0]    — siguiente descriptor en el anillo
 *   0x04 NDESC [63:32]
 *   0x08 BUFA  [31:0]    — dirección del buffer de datos
 *   0x0C BUFA  [63:32]
 *   0x10 RESERVED
 *   0x14 CTRL            — SOF=bit31, EOF=bit30, LEN=bits[25:0]
 *   0x18 STS (S2MM)      — COMPLETE=bit31, actual_len=bits[25:0]
 *        CTRL_SBAND (MM2S) — TID/TUSER de salida
 *   0x1C SIDEBAND_STS (MM2S) — COMPLETE=bit31
 *   0x20..0x30 USR0..USR4
 * Offsets SW (0x34..0x3C, reservados para software):
 * ========================================================================= */
typedef struct __attribute__((aligned(64))) {
    uint32_t ndesc;
    uint32_t ndesc_msb;
    uint32_t bufa;
    uint32_t bufa_msb;
    uint32_t reserved;
    uint32_t ctrl;          /* SOF|EOF|LEN */
    uint32_t sts;           /* S2MM: COMPLETE + actual_len */
    uint32_t sideband_sts;  /* MM2S: COMPLETE */
    uint32_t usr[5];
    uint32_t has_dre;
    uint32_t has_ctrlsts;
    uint32_t sw_id;
} MCDMA_BD;

/* BD control bits */
#define BD_CTRL_SOF               (1U << 31)
#define BD_CTRL_EOF               (1U << 30)
#define BD_CTRL_LEN_MASK          0x03FFFFFFU

/* BD status bits */
#define BD_STS_COMPLETE           (1U << 31)   /* S2MM completion flag */
#define BD_STS_LEN_MASK           0x03FFFFFFU  /* actual bytes transferred */
#define BD_SBAND_COMPLETE         (1U << 31)   /* MM2S completion flag (sideband_sts) */

/* =========================================================================
 * Frame TX: header que parsea TX_DMA_ROUTER en BRIDGE_MCDMA_TOP
 *
 * Byte 0: {CH_ID[3:0], PAYLOAD_LEN[11:8]}
 * Byte 1: PAYLOAD_LEN[7:0]
 * Bytes 2..2+len-1: payload
 * ========================================================================= */
#define TX_HDR0(ch, len)  ((uint8_t)(((uint32_t)(ch) << 4) | (((uint32_t)(len) >> 8) & 0x0FU)))
#define TX_HDR1(len)      ((uint8_t)((uint32_t)(len) & 0xFFU))
#define TX_HDR_SIZE       2U

/* =========================================================================
 * Tamaño de buffers
 * ========================================================================= */
#define DMA_TX_BUF_SIZE   4096U  /* payload máximo por TX */

/* Capacidad útil de la FIFO de TX de un canal, en bytes de payload.
 *
 * El router vuelca a la FIFO a la frecuencia del bus mientras la UART la drena
 * a la del baudrate. Todo lo que no cabe se pierde sin dejar rastro: no hay bit
 * de error ni interrupción. Por eso el driver nunca entrega a la DMA un frame
 * con más payload del que la FIFO puede retener, y espera el EOAF de cada trozo
 * (la UART ya lo ha transmitido entero) antes de encolar el siguiente.
 *
 * Los 2 bytes de cabecera los consume el router y no llegan a ocupar FIFO. */
#define TX_FIFO_PAYLOAD   512U

/* Trozo máximo de payload por frame entregado a la DMA */
#define TX_CHUNK_MAX      TX_FIFO_PAYLOAD
/* Buffer DMA por canal RX. El TLAST lo emite BRIDGE_RX_FIFO_DRAIN al vaciar el
 * FIFO del canal, y el drenado arranca cuando ese FIFO alcanza prog_full o
 * cuando el UART lleva 8,5 periodos de bit en silencio. En una ráfaga continua
 * el timeout no salta, así que un paquete es "todo lo acumulado desde
 * prog_full hasta vaciar", que puede pasar de prog_full si siguen entrando
 * bytes durante el drenado.
 *
 * Con prog_full=508 sobre una FIFO de 512, el paquete desbordaba estos 512 B y
 * el canal se quedaba mudo. Ahora prog_full es 256 y el descriptor 2048: cuatro
 * veces el umbral, margen de sobra aunque el drenado se alargue. */
#define DMA_RX_DMA_SIZE   1024U

/* Descriptores de RX encadenados por canal.
 *
 * Con un anillo de un solo BD, rearmarlo obliga a escribir TDESC con la misma
 * dirección que ya tiene CDESC. Para el PG288 eso es una cola vacía: el motor
 * deja de captar descriptores y el canal enmudece tras un par de paquetes.
 * Con varios BDs, TDESC siempre puede apuntar a un descriptor por delante de
 * CDESC, y el motor encadena sin pararse. Además da margen para que lleguen
 * paquetes mientras la ISR copia el anterior. */
#define RX_BD_COUNT       4U

/* =========================================================================
 * Structs de API
 * ========================================================================= */
typedef struct {
    uint32_t baud;
    uint32_t data_bits;
    uint32_t parity;
    uint32_t stop_bits;
    uint32_t bit_order;
    uint32_t slo_mode;
} Transceiver_Config_t;

typedef struct {
    uint32_t  id;
    uintptr_t config_base;   /* Base AXI_UART_CONFIG de este canal */

    /* Ring buffer SW (consumido por Transceiver_Read / rx_callback) */
    uint8_t  *rx_buffer;
    size_t    rx_buf_size;
    volatile size_t rx_head;
    volatile size_t rx_tail;
    volatile size_t rx_count;

    /* Callback de usuario (invocado fuera de contexto ISR) */
    void (*rx_callback)(void *arg);
    void *rx_callback_arg;

} Transceiver;

/* =========================================================================
 * Contadores de diagnóstico
 * ========================================================================= */
extern volatile uint32_t g_dbg_mm2s_isr_total;
extern volatile uint32_t g_dbg_s2mm_isr_total;
extern volatile uint32_t g_dbg_eoaf_isr;    /* nº de ISR EOAF (TX_ISR_EOF_HANDLER, IRQ 123) */
extern volatile uint32_t g_dbg_eoaf_mask;   /* OR de máscaras TX_DONE vistas por la ISR */
extern volatile uint32_t g_dbg_mm2s_ch[MAX_TRANSCEIVERS];
extern volatile uint32_t g_dbg_s2mm_ch[MAX_TRANSCEIVERS];
extern volatile uint32_t g_dbg_s2mm_err[MAX_TRANSCEIVERS];

/* =========================================================================
 * API pública
 * ========================================================================= */
#ifdef __cplusplus
extern "C" {
#endif

uint32_t          Transceiver_Global_INIT(void);

rtems_status_code Transceiver_Init(Transceiver *dev, uint32_t id,
                                   const Transceiver_Config_t *cfg);

int               Transceiver_SendString(Transceiver *dev, const char *s);

/* Envío binario por longitud (admite bytes 0x00) */
int               Transceiver_Send(Transceiver *dev, const uint8_t *data, size_t len);

size_t            Transceiver_Read(Transceiver *dev, uint8_t *buf, size_t maxlen);

void              Transceiver_SetRxCallback(Transceiver *dev,
                                            void (*cb)(void *), void *arg);

#ifdef __cplusplus
}
#endif

/* Instrumentación común a las tres variantes (debe ir tras MCDMA_BASE, que es
 * lo que usa para autodetectar la variante). */
#include "transceiver_bench.h"

#endif /* TRANSCEIVER_H */
