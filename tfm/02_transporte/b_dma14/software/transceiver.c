/* transceiver.c — AXI-Stream UART + AXI DMA simple (PG021, c_include_sg=0)
 *
 * Flujo TX:
 *   CPU copia datos al buffer DMA → flush caché → escribe MM2S_SA + MM2S_LENGTH
 *   → DMA transfiere sin intervención CPU → ISR MM2S libera semáforo al completar.
 *
 * Flujo RX:
 *   DMA S2MM armado con DA=rx_dma_buf, LENGTH=1. El UART emite TLAST=1 por cada
 *   byte recibido, por lo que el DMA completa un "paquete" de 1 byte en cada IRQ.
 *   ISR S2MM: invalida caché, copia byte al ring SW, rearma (escribe LENGTH=1).
 *
 * Nota: con TLAST=1 por byte, la latencia es mínima (una IRQ por byte recibido).
 * En producción sería más eficiente agrupar bytes en el UART IP; para esta
 * prueba la simplicidad prima sobre el throughput.
 */

#include "transceiver.h"
#include <stdio.h>
#include <string.h>
#include <rtems/rtems/cache.h>

/* =========================================================================
 * Estado global de hardware (descubierto vía SysInfo en Transceiver_Global_INIT)
 * ========================================================================= */
static uint32_t  g_hw_count  = 0;
static uintptr_t g_hw_base   = 0;
static uintptr_t g_hw_stride = 0;

#define SYS_INFO_ADDR     0xA0020000UL   /* PCB 14ch: SysInfo movido (DMA ocupa 0xA001_xxxx) */
#define SYSINFO_OFF_META  0x00U   /* [31:16]=stride [15:0]=count */
#define SYSINFO_OFF_BASE  0x08U   /* base address UARTs */

static Transceiver *g_instances[MAX_TRANSCEIVERS] = { NULL };

static volatile uint32_t g_rx_pending_mask = 0;
static rtems_id           g_rx_notify_sem  = RTEMS_ID_NONE;

/* ── Contadores de diagnóstico ─────────────────────────────────────────── */
volatile uint32_t g_dbg_mm2s_isr_total = 0;
volatile uint32_t g_dbg_s2mm_isr_total = 0;
volatile uint32_t g_dbg_mm2s_ch[MAX_TRANSCEIVERS];
volatile uint32_t g_dbg_s2mm_ch[MAX_TRANSCEIVERS];
volatile uint32_t g_dbg_s2mm_err[MAX_TRANSCEIVERS];

/* ── Contadores de benchmark (transceiver_bench.h) ─────────────────────── */
static volatile uint64_t g_bench_irq_tx   = 0;
static volatile uint64_t g_bench_irq_rx   = 0;
static volatile uint64_t g_bench_bytes_tx = 0;
static volatile uint64_t g_bench_bytes_rx = 0;
static volatile uint64_t g_bench_err      = 0;

/* =========================================================================
 * Buffers DMA estáticos alineados
 *
 * Viven en DDR. La coherencia de caché se gestiona manualmente:
 *   TX: flush antes de arrancar el DMA
 *   RX: invalidate después de que el DMA escribe
 * En ZynqMP+RTEMS virtual == física para el rango DDR normal, así que los
 * punteros C son directamente direcciones físicas para el DMA.
 * ========================================================================= */
static uint8_t g_tx_dma_bufs[MAX_TRANSCEIVERS][DMA_TX_BUF_SIZE]
    __attribute__((aligned(64)));
static uint8_t g_rx_dma_bufs[MAX_TRANSCEIVERS][DMA_RX_DMA_SIZE]
    __attribute__((aligned(64)));
static uint8_t g_sw_rx_bufs[MAX_TRANSCEIVERS][4096];

/* =========================================================================
 * Helpers de registro
 * ========================================================================= */
static inline uint32_t reg_read(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}
static inline void reg_write(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

#define DMA_RD(base, off)        reg_read ((uintptr_t)(base) + (off))
#define DMA_WR(base, off, val)   reg_write((uintptr_t)(base) + (off), (val))

/* =========================================================================
 * ISR MM2S — TX completado (línea COMPARTIDA, escanea los 14 canales)
 *
 * Con 14 canales las 14 mm2s_introut están OR-coalescidas en una sola línea
 * (pl_ps_irq0[0]). La ISR recorre todos los canales y atiende los que tengan
 * el flag IOC/ERR, libera su semáforo TX.
 * ========================================================================= */
static rtems_isr MM2S_ISR(void *arg) {
    (void)arg;
    g_dbg_mm2s_isr_total++;
    g_bench_irq_tx++;   /* una IRQ física, aunque la ISR atienda varios canales */
    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        uintptr_t db = DMA_CH_BASE(ch);
        uint32_t  sr = DMA_RD(db, DMA_MM2S_DMASR);
        if (!(sr & DMA_SR_IRQ_MASK)) continue;

        DMA_WR(db, DMA_MM2S_DMASR, sr);   /* W1C: limpiar IRQ de este canal */
        g_dbg_mm2s_ch[ch]++;

        Transceiver *dev = g_instances[ch];
        if (dev) {
            rtems_semaphore_release(dev->tx_sem_id);
        }
    }
}

/* =========================================================================
 * ISR S2MM — RX disponible (línea COMPARTIDA, escanea los 14 canales)
 *
 * Las 14 s2mm_introut están OR-coalescidas en pl_ps_irq0[1]. La ISR recorre
 * todos los canales; para cada uno con IOC: copia el byte al ring SW y rearma.
 * ========================================================================= */
static rtems_isr S2MM_ISR(void *arg) {
    (void)arg;
    g_dbg_s2mm_isr_total++;
    g_bench_irq_rx++;   /* una IRQ física, aunque la ISR atienda varios canales */
    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        uintptr_t db = DMA_CH_BASE(ch);
        uint32_t  sr = DMA_RD(db, DMA_S2MM_DMASR);
        if (!(sr & DMA_SR_IRQ_MASK)) continue;

        DMA_WR(db, DMA_S2MM_DMASR, sr);   /* W1C: limpiar IRQ de este canal */
        g_dbg_s2mm_ch[ch]++;

        if (sr & DMA_SR_ERR_IRQ) {
            g_dbg_s2mm_err[ch]++;
            g_bench_err++;
        }

        Transceiver *dev = g_instances[ch];
        if (dev && (sr & DMA_SR_IOC_IRQ)) {
            /* El DMA escribió 1 byte en rx_dma_buf[0]; invalidar caché. */
            rtems_cache_invalidate_multiple_data_lines(dev->rx_dma_buf, DMA_RX_DMA_SIZE);
            uint8_t byte = dev->rx_dma_buf[0];

            if (__atomic_load_n(&dev->rx_count, __ATOMIC_RELAXED) < dev->rx_buf_size) {
                dev->rx_buffer[dev->rx_tail] = byte;
                dev->rx_tail = (dev->rx_tail + 1) % dev->rx_buf_size;
                __atomic_fetch_add(&dev->rx_count, 1U, __ATOMIC_RELEASE);
                g_bench_bytes_rx++;
            } else {
                g_bench_err++;   /* overrun del ring SW: byte perdido */
            }

            if (dev->rx_callback) {
                __atomic_fetch_or(&g_rx_pending_mask, 1U << ch, __ATOMIC_RELEASE);
                rtems_semaphore_release(g_rx_notify_sem);
            }
        }

        /* Rearmar S2MM para el siguiente byte (misma DA). */
        if (dev) {
            DMA_WR(db, DMA_S2MM_LENGTH, 1U);
        }
    }
}

/* =========================================================================
 * Tarea de despacho RX — invoca callbacks fuera de contexto ISR
 * ========================================================================= */
static rtems_task RX_Dispatch_Task(rtems_task_argument arg) {
    (void)arg;
    for (;;) {
        rtems_semaphore_obtain(g_rx_notify_sem, RTEMS_WAIT, RTEMS_NO_TIMEOUT);
        uint32_t mask = __atomic_exchange_n((uint32_t *)&g_rx_pending_mask,
                                            0, __ATOMIC_ACQ_REL);
        for (uint32_t ch = 0; ch < g_hw_count; ch++) {
            if (!(mask & (1U << ch))) continue;
            Transceiver *dev = g_instances[ch];
            if (dev && dev->rx_callback)
                dev->rx_callback(dev->rx_callback_arg);
        }
    }
}

/* =========================================================================
 * Descubrimiento de hardware vía SysInfo
 * ========================================================================= */
static uint32_t Hardware_Discover(void) {
    uint32_t meta = reg_read(SYS_INFO_ADDR + SYSINFO_OFF_META);
    uint32_t base = reg_read(SYS_INFO_ADDR + SYSINFO_OFF_BASE);

    g_hw_count  =  meta & 0xFFFFU;
    g_hw_stride = (uintptr_t)((meta >> 16) & 0xFFFFU);
    g_hw_base   = (uintptr_t)base;

    if (g_hw_count == 0 || g_hw_count > MAX_TRANSCEIVERS) return 0;
    if (g_hw_stride == 0) g_hw_stride = 0x1000U;

    TRANS_DEBUG("HW: %u canales | UART base: 0x%08lX | stride: 0x%lX\n",
                g_hw_count, (unsigned long)g_hw_base, (unsigned long)g_hw_stride);
    return g_hw_count;
}

/* =========================================================================
 * DMA_Global_Init — registra ISRs y crea infraestructura RX
 * ========================================================================= */
static void DMA_Global_Init(void) {
    /* Semáforo de notificación RX (conteo, empieza en 0) */
    rtems_semaphore_create(rtems_build_name('R','X','N','T'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0,
                           &g_rx_notify_sem);

    /* Tarea de despacho RX (prioridad 10, invoca callbacks fuera de ISR) */
    rtems_id rx_task;
    rtems_task_create(rtems_build_name('R','X','D','P'), 10,
                      RTEMS_MINIMUM_STACK_SIZE * 2,
                      RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &rx_task);
    rtems_task_start(rx_task, RX_Dispatch_Task, 0);

    /* Dos ISRs compartidas: las 14 mm2s y las 14 s2mm están OR-coalescidas
     * en pl_ps_irq0[0] y [1]. Cada ISR escanea los 14 canales. */
    rtems_interrupt_handler_install(
        IRQ_DMA_MM2S, "DMA_TX_ALL",
        RTEMS_INTERRUPT_UNIQUE, MM2S_ISR, NULL);
    rtems_interrupt_handler_install(
        IRQ_DMA_S2MM, "DMA_RX_ALL",
        RTEMS_INTERRUPT_UNIQUE, S2MM_ISR, NULL);

    TRANS_DEBUG("DMA global init OK | MM2S IRQ=%d  S2MM IRQ=%d (compartidas, 14ch)\n",
                IRQ_DMA_MM2S, IRQ_DMA_S2MM);
}

/* =========================================================================
 * Transceiver_Init — inicializa un canal UART + su DMA
 * ========================================================================= */
rtems_status_code Transceiver_Init(Transceiver *dev, uint32_t id,
                                   const Transceiver_Config_t *cfg) {
    if (id >= MAX_TRANSCEIVERS || id >= g_hw_count) return RTEMS_INVALID_ID;

    dev->id          = id;
    dev->config_base = g_hw_base + id * g_hw_stride;
    dev->dma_base    = DMA_CH_BASE(id);

    dev->tx_buf     = g_tx_dma_bufs[id];
    dev->rx_dma_buf = g_rx_dma_bufs[id];

    dev->rx_buffer   = g_sw_rx_bufs[id];
    dev->rx_buf_size = sizeof(g_sw_rx_bufs[id]);
    dev->rx_head     = 0;
    dev->rx_tail     = 0;
    dev->rx_count    = 0;

    dev->rx_callback     = NULL;
    dev->rx_callback_arg = NULL;

    /* Semáforo TX — empieza en 1 para que el primer SendString no bloquee */
    rtems_status_code sc = rtems_semaphore_create(
        rtems_build_name('T','X','S','0'+(char)id), 1,
        RTEMS_SIMPLE_BINARY_SEMAPHORE | RTEMS_FIFO, 0,
        &dev->tx_sem_id);
    if (sc != RTEMS_SUCCESSFUL) return sc;

    g_instances[id] = dev;

    /* ── Configurar UART vía AXI-Lite ─────────────────────────────────── */
    if (cfg) {
        uint32_t val = 0;
        val |= ((cfg->baud      & 0x3FU) << UART_CFG_SHIFT_BAUD);
        val |= ((cfg->stop_bits & 0x3U)  << UART_CFG_SHIFT_STOP);
        val |= ((cfg->parity    & 0x7U)  << UART_CFG_SHIFT_PARITY);
        val |= ((cfg->data_bits & 0x7U)  << UART_CFG_SHIFT_DATA_BITS);
        if (cfg->bit_order) val |= UART_CFG_BIT_ORDER;
        if (cfg->slo_mode)  val |= UART_CFG_BIT_SLO;
        reg_write(dev->config_base + UART_CFG_REG, val);
    }

    uintptr_t db = dev->dma_base;

    /* ── Soft reset de ambos motores ────────────────────────────────────── */
    DMA_WR(db, DMA_MM2S_DMACR, DMA_CR_RESET);
    for (uint32_t t = 0; t < 10000; t++) {
        if (!(DMA_RD(db, DMA_MM2S_DMACR) & DMA_CR_RESET)) break;
    }
    DMA_WR(db, DMA_S2MM_DMACR, DMA_CR_RESET);
    for (uint32_t t = 0; t < 10000; t++) {
        if (!(DMA_RD(db, DMA_S2MM_DMACR) & DMA_CR_RESET)) break;
    }

    /* ── Arrancar MM2S con IRQs habilitadas ─────────────────────────────── */
    DMA_WR(db, DMA_MM2S_DMACR, DMA_CR_INIT);

    /* ── Arrancar S2MM y armar primer buffer RX ─────────────────────────── */
    DMA_WR(db, DMA_S2MM_DMACR, DMA_CR_INIT);
    uintptr_t pa = (uintptr_t)dev->rx_dma_buf;
    DMA_WR(db, DMA_S2MM_DA,     (uint32_t)pa);
    DMA_WR(db, DMA_S2MM_DA_MSB, (uint32_t)(pa >> 32));  /* 0 con c_addr_width=32 */
    DMA_WR(db, DMA_S2MM_LENGTH, 1U);                    /* arma: espera primer byte */

    TRANS_DEBUG("UART %u OK | cfg=0x%08lX | dma=0x%08lX | tx=%p rx_dma=%p\n",
                id, (unsigned long)dev->config_base, (unsigned long)dev->dma_base,
                (void *)dev->tx_buf, (void *)dev->rx_dma_buf);
    return RTEMS_SUCCESSFUL;
}

/* =========================================================================
 * Transceiver_SendString — envía una cadena por el canal
 *
 * Si el canal TX está ocupado (el DMA anterior aún no completó) bloquea
 * hasta que la ISR MM2S libere el semáforo.
 * La llamada retorna en cuanto el DMA arranca; la ISR finaliza en segundo plano.
 * ========================================================================= */
int Transceiver_Send(Transceiver *dev, const uint8_t *data, size_t len) {
    if (len == 0) return 0;
    if (len > DMA_TX_BUF_SIZE) len = DMA_TX_BUF_SIZE;

    /* Esperar a que el canal TX esté libre */
    rtems_semaphore_obtain(dev->tx_sem_id, RTEMS_WAIT, RTEMS_NO_TIMEOUT);

    memcpy(dev->tx_buf, data, len);
    rtems_cache_flush_multiple_data_lines(dev->tx_buf, len);

    uintptr_t db = dev->dma_base;
    uintptr_t pa = (uintptr_t)dev->tx_buf;
    DMA_WR(db, DMA_MM2S_SA,     (uint32_t)pa);
    DMA_WR(db, DMA_MM2S_SA_MSB, (uint32_t)(pa >> 32));
    DMA_WR(db, DMA_MM2S_LENGTH, (uint32_t)len);   /* escritura aquí arranca TX */

    g_bench_bytes_tx += len;
    return (int)len;
}

int Transceiver_SendString(Transceiver *dev, const char *s) {
    return Transceiver_Send(dev, (const uint8_t *)s, strlen(s));
}

/* =========================================================================
 * Transceiver_Read — lee del ring buffer SW (productor = ISR S2MM)
 * ========================================================================= */
size_t Transceiver_Read(Transceiver *dev, uint8_t *buf, size_t maxlen) {
    size_t got = 0;
    while (got < maxlen &&
           __atomic_load_n(&dev->rx_count, __ATOMIC_ACQUIRE) > 0) {
        buf[got++] = dev->rx_buffer[dev->rx_head];
        dev->rx_head = (dev->rx_head + 1) % dev->rx_buf_size;
        __atomic_fetch_sub(&dev->rx_count, 1U, __ATOMIC_RELEASE);
    }
    return got;
}

/* =========================================================================
 * Transceiver_SetRxCallback
 * ========================================================================= */
void Transceiver_SetRxCallback(Transceiver *dev, void (*cb)(void *), void *arg) {
    dev->rx_callback     = cb;
    dev->rx_callback_arg = arg;
}

/* =========================================================================
 * Transceiver_Global_INIT — descubrimiento de HW + inicialización global DMA
 * ========================================================================= */
uint32_t Transceiver_Global_INIT(void) {
    uint32_t count = Hardware_Discover();
    if (count == 0) {
        printf("[TRANSCEIVER] ERROR: no se detectaron canales de hardware\n");
        return 0;
    }
    DMA_Global_Init();
    return count;
}

/* =========================================================================
 * Instrumentación de benchmark (transceiver_bench.h)
 * ========================================================================= */
void Transceiver_BenchStats(Transceiver_BenchStats_t *out) {
    if (!out) return;
    out->variant       = BENCH_VARIANT_NAME;
    /* Send retorna en cuanto el DMA arranca; la ISR MM2S termina en segundo plano. */
    out->tx_blocking   = false;
    /* Un AXI-DMA independiente por canal: los 14 pueden transmitir a la vez. */
    out->tx_concurrent = true;
    out->irq_lines     = 2;   /* MM2S 121, S2MM 122 (OR-coalescidas en el bitstream) */
    out->isr_count     = 2;
    out->task_count    = 1;   /* RX_Dispatch_Task */
    out->sem_count     = 1 + g_hw_count;  /* g_rx_notify_sem + un tx_sem por canal */
    out->static_bytes  = sizeof(g_tx_dma_bufs) + sizeof(g_rx_dma_bufs) +
                         sizeof(g_sw_rx_bufs);
    out->heap_bytes    = 0;

    out->irq_tx    = g_bench_irq_tx;
    out->irq_rx    = g_bench_irq_rx;
    out->bytes_tx  = g_bench_bytes_tx;
    out->bytes_rx  = g_bench_bytes_rx;
    out->err_count = g_bench_err;
}

void Transceiver_BenchReset(void) {
    g_bench_irq_tx = g_bench_irq_rx = 0;
    g_bench_bytes_tx = g_bench_bytes_rx = 0;
    g_bench_err = 0;
}

void Transceiver_BenchDumpRx(uint32_t ch) {
    if (ch >= g_hw_count) return;
    uintptr_t db = DMA_CH_BASE(ch);
    uint32_t cr  = DMA_RD(db, DMA_S2MM_DMACR);
    uint32_t sr  = DMA_RD(db, DMA_S2MM_DMASR);
    uint32_t da  = DMA_RD(db, DMA_S2MM_DA);
    uint32_t len = DMA_RD(db, DMA_S2MM_LENGTH);

    printf("[DUMP] CH%u S2MM base=0x%08lX\n", (unsigned)ch, (unsigned long)db);
    printf("       DMACR =0x%08X  RS=%u IOC_EN=%u ERR_EN=%u\n", (unsigned)cr,
           (unsigned)(cr & DMA_CR_RS ? 1 : 0),
           (unsigned)(cr & DMA_CR_IOC_IRQEN ? 1 : 0),
           (unsigned)(cr & DMA_CR_ERR_IRQEN ? 1 : 0));
    printf("       DMASR =0x%08X  Halted=%u Idle=%u IOC_Irq=%u Err_Irq=%u\n", (unsigned)sr,
           (unsigned)(sr & DMA_SR_HALTED ? 1 : 0),
           (unsigned)(sr & DMA_SR_IDLE ? 1 : 0),
           (unsigned)(sr & DMA_SR_IOC_IRQ ? 1 : 0),
           (unsigned)(sr & DMA_SR_ERR_IRQ ? 1 : 0));
    printf("       DA    =0x%08X  LENGTH=%u  (0 = receptor NO armado)\n",
           (unsigned)da, (unsigned)len);
    printf("       s2mm_isr_total=%u  ch_isr=%u  ch_err=%u\n",
           (unsigned)g_dbg_s2mm_isr_total, (unsigned)g_dbg_s2mm_ch[ch],
           (unsigned)g_dbg_s2mm_err[ch]);
    fflush(stdout);
}

void Transceiver_SetBaud(Transceiver *dev, uint32_t baud) {
    uint32_t val = 0;
    val |= ((baud & 0x3FU) << UART_CFG_SHIFT_BAUD);
    val |= ((TRANSCEIVER_STOP_BITS_1 & 0x3U) << UART_CFG_SHIFT_STOP);
    val |= ((TRANSCEIVER_PARITY_NONE & 0x7U) << UART_CFG_SHIFT_PARITY);
    val |= ((TRANSCEIVER_DATA_BITS_8 & 0x7U) << UART_CFG_SHIFT_DATA_BITS);
    reg_write(dev->config_base + UART_CFG_REG, val);
}
