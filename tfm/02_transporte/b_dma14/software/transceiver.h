/* transceiver.h — AXI-Stream UART + AXI DMA simple (Xilinx PG021)
 *
 * Diseño: 4 canales, cada uno con su propio axi_dma (sin scatter-gather).
 * TX: escribe SA+LENGTH → DMA transfiere → ISR MM2S libera semáforo.
 * RX: DMA armado con LENGTH=1 → TLAST cada byte completa el paquete →
 *     ISR S2MM copia al ring SW y rearma inmediatamente.
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
 * Registro AXI-Lite UART
 * ========================================================================= */
#define UART_CFG_REG              0x00U
#define UART_CFG_SHIFT_BAUD       12
#define UART_CFG_SHIFT_STOP       18
#define UART_CFG_SHIFT_PARITY     20
#define UART_CFG_SHIFT_DATA_BITS  23
#define UART_CFG_BIT_ORDER        (1U << 26)
#define UART_CFG_BIT_SLO          (1U << 27)

/* =========================================================================
 * AXI DMA simple — PG021 (c_include_sg=0)
 *
 * 4 instancias independientes, stride 4 KB entre ellas.
 * Mapa de memoria:
 *   axi_dma_0 → 0xA000_4000
 *   axi_dma_1 → 0xA000_5000
 *   PCB 14 canales: axi_dma_i → 0xA001_0000 + i*0x1000  (i=0..13)
 * ========================================================================= */
#define DMA0_BASE        0xA0010000UL
#define DMA_STRIDE       0x1000UL
#define DMA_CH_BASE(ch)  (DMA0_BASE + (uint32_t)(ch) * DMA_STRIDE)

/* ── Offsets de registros (PG021, tabla 2-4) ─────────────────────────────── */
#define DMA_MM2S_DMACR   0x00U   /* MM2S Control */
#define DMA_MM2S_DMASR   0x04U   /* MM2S Status  */
#define DMA_MM2S_SA      0x18U   /* Source Address [31:0]  */
#define DMA_MM2S_SA_MSB  0x1CU   /* Source Address [63:32] — 0 con c_addr_width=32 */
#define DMA_MM2S_LENGTH  0x28U   /* Transfer length; escritura aquí arranca TX */

#define DMA_S2MM_DMACR   0x30U   /* S2MM Control */
#define DMA_S2MM_DMASR   0x34U   /* S2MM Status  */
#define DMA_S2MM_DA      0x48U   /* Dest Address [31:0]    */
#define DMA_S2MM_DA_MSB  0x4CU   /* Dest Address [63:32]   */
#define DMA_S2MM_LENGTH  0x58U   /* Max bytes; escritura aquí arma RX */

/* ── Bits DMACR ──────────────────────────────────────────────────────────── */
#define DMA_CR_RS        (1U << 0)   /* Run/Stop */
#define DMA_CR_RESET     (1U << 2)   /* Soft reset (auto-clear) */
#define DMA_CR_IOC_IRQEN (1U << 12)  /* IRQ on complete */
#define DMA_CR_ERR_IRQEN (1U << 14)  /* IRQ on error */
#define DMA_CR_INIT      (DMA_CR_RS | DMA_CR_IOC_IRQEN | DMA_CR_ERR_IRQEN)

/* ── Bits DMASR ──────────────────────────────────────────────────────────── */
#define DMA_SR_HALTED    (1U << 0)
#define DMA_SR_IDLE      (1U << 1)
#define DMA_SR_IOC_IRQ   (1U << 12)  /* Interrupt on complete (W1C) */
#define DMA_SR_ERR_IRQ   (1U << 14)  /* Error (W1C) */
#define DMA_SR_IRQ_MASK  (DMA_SR_IOC_IRQ | DMA_SR_ERR_IRQ)

/* ── Vectores IRQ (PCB 14 canales) ────────────────────────────────────────
 * Con 14 canales hay 28 introut > 16 líneas PL→PS. El bitstream OR-coalesce
 * los 14 mm2s en una línea y los 14 s2mm en otra:
 *   pl_ps_irq0[0] = OR(14× mm2s_introut) → GIC SPI 89 → RTEMS 121
 *   pl_ps_irq0[1] = OR(14× s2mm_introut) → GIC SPI 90 → RTEMS 122
 * La ISR escanea los 14 canales para ver cuál(es) completó. */
#define IRQ_DMA_MM2S   121   /* línea compartida MM2S (TX completado) */
#define IRQ_DMA_S2MM   122   /* línea compartida S2MM (RX disponible) */

/* =========================================================================
 * Tamaño de buffers
 * ========================================================================= */
#define DMA_TX_BUF_SIZE   4096U  /* Bytes máximos por TX */
/* Buffer DMA de aterrizaje para RX: 1 byte efectivo por paquete (TLAST cada
 * byte). Se alinea a una línea de caché para que cache_invalidate sea atómico. */
#define DMA_RX_DMA_SIZE   64U

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
    uintptr_t config_base;   /* Base AXI-Lite del UART */
    uintptr_t dma_base;      /* Base AXI DMA de este canal */

    /* TX */
    uint8_t  *tx_buf;        /* Buffer DMA alineado para TX */
    rtems_id  tx_sem_id;     /* Binario: ISR MM2S lo libera al completar */

    /* RX DMA — buffer de aterrizaje de 1 byte (reutilizado en cada ISR) */
    uint8_t  *rx_dma_buf;

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

/* Envío binario por longitud (admite bytes 0x00, para frames de protocolo) */
int               Transceiver_Send(Transceiver *dev, const uint8_t *data, size_t len);

size_t            Transceiver_Read(Transceiver *dev, uint8_t *buf, size_t maxlen);

void              Transceiver_SetRxCallback(Transceiver *dev,
                                            void (*cb)(void *), void *arg);

#ifdef __cplusplus
}
#endif

/* Instrumentación común a las tres variantes (debe ir tras DMA0_BASE, que es
 * lo que usa para autodetectar la variante). */
#include "transceiver_bench.h"

#endif /* TRANSCEIVER_H */
