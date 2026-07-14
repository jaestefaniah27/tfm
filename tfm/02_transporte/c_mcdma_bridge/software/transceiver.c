/* transceiver.c — AXI MCDMA (PG288, SG) + BRIDGE_MCDMA_TOP
 *
 * TX (MM2S canal 1, compartido):
 *   CPU construye frame [hdr0, hdr1, payload] en g_tx_frame →
 *   actualiza BD TX → escribe TDESC → MCDMA transfiere →
 *   ISR MM2S libera semáforo.
 *
 * RX (S2MM canales 1..N, uno por UART):
 *   BD pre-armado con buffer de DMA_RX_DMA_SIZE bytes.
 *   UART → BRIDGE_RX_TOP → TLAST al vaciarse el FIFO del canal → MCDMA → IOC.
 *   ISR S2MM: lee actual_len del BD, copia al ring SW, re-arma.
 *
 * SG: anillo de 1 BD por canal (NDESC apunta a sí mismo). Para re-armar
 * basta limpiar STS, restaurar CTRL y escribir TDESC = dirección del BD.
 */

#include "transceiver.h"
#include <stdio.h>
#include <string.h>
#include <rtems/rtems/cache.h>

/* =========================================================================
 * Estado global
 * ========================================================================= */
static uint32_t  g_hw_count = 0;   /* canales UART activos (≤ MAX_TRANSCEIVERS) */

static Transceiver *g_instances[MAX_TRANSCEIVERS] = { NULL };

static volatile uint32_t g_rx_pending_mask = 0;
static rtems_id           g_rx_notify_sem  = RTEMS_ID_NONE;
static rtems_id           g_tx_sem_id      = RTEMS_ID_NONE;   /* mutex del recurso DMA compartido */
static rtems_id           g_tx_dma_sem     = RTEMS_ID_NONE;   /* liberado por MM2S_ISR: trozo ya en la FIFO */
static rtems_id           g_tx_eof_sem[MAX_TRANSCEIVERS];     /* uno por canal: fin de transmisión física */

/* ── Contadores de diagnóstico ─────────────────────────────────────────── */
volatile uint32_t g_dbg_mm2s_isr_total = 0;
volatile uint32_t g_dbg_s2mm_isr_total = 0;
volatile uint32_t g_dbg_eoaf_isr = 0;
volatile uint32_t g_dbg_eoaf_mask = 0;

/* Registros del bloque TX_ISR_EOF_HANDLER (AXI-Lite, base 0xA0001000) */
#define TXISR_BASE            0xA0001000UL
#define TXISR_TX_DONE         0x00U   /* RO  : bits sticky de fin de lote por canal */
#define TXISR_TX_DONE_CLEAR   0x04U   /* W1C : escribir 1 borra el bit */
#define TXISR_IRQ_ENABLE      0x08U   /* RW  : máscara (reset = todos habilitados) */
#define IRQ_TX_EOAF           123     /* pl_ps_irq0[2] → GIC SPI 91 → RTEMS 123 */
volatile uint32_t g_dbg_mm2s_ch[MAX_TRANSCEIVERS];
volatile uint32_t g_dbg_s2mm_ch[MAX_TRANSCEIVERS];

/* Traza de paquetes RX por canal: distingue "no llegan más paquetes" de
 * "llegan paquetes vacíos". Los primeros DBG_PKT_MAX se guardan con su
 * longitud; g_dbg_rx_pkts cuenta todos, tengan datos o no. */
#define DBG_PKT_MAX 12
volatile uint32_t g_dbg_rx_pkts[MAX_TRANSCEIVERS];
volatile uint16_t g_dbg_rx_len[MAX_TRANSCEIVERS][DBG_PKT_MAX];
volatile uint32_t g_dbg_rx_empty_bd[MAX_TRANSCEIVERS];   /* ISR con BD sin COMPLETE */
volatile uint32_t g_dbg_rx_bytes[MAX_TRANSCEIVERS];      /* bytes entregados por el HW */
volatile uint32_t g_dbg_rx_dropped[MAX_TRANSCEIVERS];    /* descartados: ring SW lleno */
volatile uint32_t g_dbg_rx_read[MAX_TRANSCEIVERS];       /* bytes servidos a Transceiver_Read */
volatile uint32_t g_dbg_s2mm_err[MAX_TRANSCEIVERS];

/* Línea base de los contadores acumuladores del motor MCDMA (PKTCNT/PKTDROP),
 * capturada en BenchDbgReset para reportar el delta del test y no arrastrar
 * T0/T1. Estos registros son de HW; no se pueden poner a 0 por software. */
volatile uint32_t g_dbg_motor_pktcnt0[MAX_TRANSCEIVERS];
volatile uint32_t g_dbg_motor_pktdrop0[MAX_TRANSCEIVERS];

/* ── Contadores de benchmark (transceiver_bench.h) ─────────────────────── */
static volatile uint64_t g_bench_irq_tx   = 0;
static volatile uint64_t g_bench_irq_rx   = 0;
static volatile uint64_t g_bench_bytes_tx = 0;
static volatile uint64_t g_bench_bytes_rx = 0;
static volatile uint64_t g_bench_err      = 0;

/* =========================================================================
 * Buffers DMA y BDs estáticos
 *
 * Los BDs deben estar alineados a 64 bytes (XMCDMA_BD_MINIMUM_ALIGNMENT).
 * ZynqMP + RTEMS: virtual == físico para DDR normal. Coherencia manual:
 *   TX:  flush BD + datos antes de escribir TDESC
 *   RX:  invalidate BD + datos después de IOC
 * ========================================================================= */

/* Un BD de TX compartido para el único canal MM2S */
static MCDMA_BD g_tx_bd __attribute__((aligned(64)));

/* Buffer TX: 2 bytes de header + hasta DMA_TX_BUF_SIZE de payload */
static uint8_t g_tx_frame[TX_HDR_SIZE + DMA_TX_BUF_SIZE] __attribute__((aligned(64)));

/* Anillo de RX_BD_COUNT descriptores por canal, encadenados circularmente */
static MCDMA_BD g_rx_bd[MAX_TRANSCEIVERS][RX_BD_COUNT] __attribute__((aligned(64)));

/* Buffer de aterrizaje de RX por canal y descriptor */
static uint8_t g_rx_dma_bufs[MAX_TRANSCEIVERS][RX_BD_COUNT][DMA_RX_DMA_SIZE]
    __attribute__((aligned(64)));

/* Índice del próximo BD que la ISR debe examinar en cada anillo */
static uint32_t g_rx_bd_head[MAX_TRANSCEIVERS];

/* Ring buffers SW de RX */
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

/* Lectura/escritura de registro MCDMA relativo a una base de dirección */
#define MCDMA_RD(side_base, off)       reg_read ((uintptr_t)(side_base) + (off))
#define MCDMA_WR(side_base, off, val)  reg_write((uintptr_t)(side_base) + (off), (val))

/* =========================================================================
 * Helpers de BD
 * ========================================================================= */
static void bd_flush(const MCDMA_BD *bd) {
    rtems_cache_flush_multiple_data_lines((void *)bd, sizeof(MCDMA_BD));
}

static void bd_invalidate(const MCDMA_BD *bd) {
    rtems_cache_invalidate_multiple_data_lines((void *)bd, sizeof(MCDMA_BD));
}

/* Devuelve un BD ya consumido al anillo: limpia COMPLETE y restaura la longitud */
static void rx_bd_recycle(MCDMA_BD *bd) {
    bd->sts  = 0;                                           /* limpiar COMPLETE */
    /* PG288: en un BD de S2MM, SOF/EOF son bits de ESTADO — los pone el motor al
     * recibir el paquete. El campo de control es solo la longitud del buffer.
     * Preescribirlos (0xC0000000) no es lo que hace XMcDma. */
    bd->ctrl = DMA_RX_DMA_SIZE;
    bd_flush(bd);
}

/* Reabastece la cola del motor. TDESC debe quedar SIEMPRE por delante de CDESC:
 * si llegan a coincidir, el MCDMA cree la cola vacía y se detiene, y como ya no
 * genera IRQs, la ISR no vuelve a correr para reanimarlo -> deadlock.
 *
 * Anclamos al CDESC REAL del motor (leído del registro), no al índice `head` del
 * software, que puede desincronizarse. TDESC = el BD inmediatamente ANTERIOR a
 * CDESC en el círculo: deja RX_BD_COUNT-1 descriptores libres por delante y
 * nunca coincide con CDESC (mientras RX_BD_COUNT >= 2). El parámetro `head` ya
 * no se usa para calcular TDESC; se conserva por compatibilidad de firma. */
static void rx_bd_publish(uint32_t ch, uint32_t head) {
    (void)head;
    uint32_t  mcdma_ch = ch + 1;                            /* MCDMA 1-indexed */

    uintptr_t cdesc = MCDMA_RD(S2MM_BASE, MCDMA_CHN_CDESC(mcdma_ch));
    uintptr_t base  = (uintptr_t)&g_rx_bd[ch][0];
    uint32_t  cur   = (uint32_t)((cdesc - base) / sizeof(MCDMA_BD));
    if (cur >= RX_BD_COUNT) cur = 0;                        /* guarda por si CDESC raro */

    uint32_t  tail_idx = (cur + RX_BD_COUNT - 1U) % RX_BD_COUNT;
    uintptr_t bd_pa    = (uintptr_t)&g_rx_bd[ch][tail_idx];

    MCDMA_WR(S2MM_BASE, MCDMA_CHN_TDESC(mcdma_ch),     (uint32_t)bd_pa);
    MCDMA_WR(S2MM_BASE, MCDMA_CHN_TDESC_MSB(mcdma_ch), (uint32_t)(bd_pa >> 32));
}

/* =========================================================================
 * ISR MM2S — DMA de TX completado (único canal MM2S, IRQ 121)
 *
 * Marca que el MCDMA terminó de VOLCAR el frame a la FIFO del puente (no que
 * el UART haya terminado de transmitir — eso lo indica EOAF). Solo limpia el
 * IOC (W1C) y contabiliza. La finalización física del lote la gestiona la ISR
 * EOAF, que es la que libera Transceiver_Send.
 * ========================================================================= */
static rtems_isr MM2S_ISR(void *arg) {
    (void)arg;
    uint32_t sr = MCDMA_RD(MM2S_BASE, MCDMA_CHN_SR(1));
    if (!(sr & MCDMA_CH_SR_IRQ_MASK)) return;

    MCDMA_WR(MM2S_BASE, MCDMA_CHN_SR(1), sr & MCDMA_CH_SR_IRQ_MASK);  /* W1C */
    g_dbg_mm2s_isr_total++;
    g_dbg_mm2s_ch[0]++;
    g_bench_irq_tx++;

    /* El trozo ya está en la FIFO del canal: el MM2S y el buffer de TX quedan
     * libres para otro canal, aunque la UART tarde milisegundos en sacarlo. */
    rtems_semaphore_release(g_tx_dma_sem);
}

/* =========================================================================
 * ISR S2MM — RX disponible (canales 1..g_hw_count, shared IRQ)
 *
 * Con c_enable_multi_intr=0, s2mm_introut es el OR de todos los canales.
 * La ISR recorre todos los canales activos buscando IOC.
 * ========================================================================= */
static rtems_isr S2MM_ISR(void *arg) {
    (void)arg;
    g_dbg_s2mm_isr_total++;
    g_bench_irq_rx++;

    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        uint32_t mcdma_ch = ch + 1;
        uint32_t sr = MCDMA_RD(S2MM_BASE, MCDMA_CHN_SR(mcdma_ch));
        if (!(sr & MCDMA_CH_SR_IRQ_MASK)) continue;

        MCDMA_WR(S2MM_BASE, MCDMA_CHN_SR(mcdma_ch), sr & MCDMA_CH_SR_IRQ_MASK);
        g_dbg_s2mm_ch[ch]++;

        if (sr & MCDMA_CH_SR_ERR) { g_dbg_s2mm_err[ch]++; g_bench_err++; }

        /* Una sola IRQ puede cubrir varios descriptores completados: recorrer el
         * anillo desde head hasta encontrar uno que el motor aún no ha cerrado. */
        Transceiver *dev     = g_instances[ch];
        uint32_t     head    = g_rx_bd_head[ch];
        uint32_t     n_bds   = 0;
        bool         got_any = false;

        for (uint32_t k = 0; k < RX_BD_COUNT; k++) {
            MCDMA_BD *bd = &g_rx_bd[ch][head];
            bd_invalidate(bd);
            if (!(bd->sts & BD_STS_COMPLETE)) {
                if (k == 0) g_dbg_rx_empty_bd[ch]++;   /* IRQ sin BD cerrado */
                break;
            }

            uint32_t actual = bd->sts & BD_STS_LEN_MASK;
            if (actual > DMA_RX_DMA_SIZE) actual = DMA_RX_DMA_SIZE;

            uint32_t p = g_dbg_rx_pkts[ch];
            if (p < DBG_PKT_MAX) g_dbg_rx_len[ch][p] = (uint16_t)actual;
            g_dbg_rx_pkts[ch] = p + 1;
            g_dbg_rx_bytes[ch] += actual;   /* lo que el HW dice haber entregado */

            if (actual > 0 && dev) {
                rtems_cache_invalidate_multiple_data_lines(g_rx_dma_bufs[ch][head], actual);

                for (uint32_t i = 0; i < actual; i++) {
                    if (__atomic_load_n(&dev->rx_count, __ATOMIC_RELAXED) < dev->rx_buf_size) {
                        dev->rx_buffer[dev->rx_tail] = g_rx_dma_bufs[ch][head][i];
                        dev->rx_tail = (dev->rx_tail + 1) % dev->rx_buf_size;
                        __atomic_fetch_add(&dev->rx_count, 1U, __ATOMIC_RELEASE);
                        g_bench_bytes_rx++;
                    } else {
                        g_bench_err++;   /* overrun del ring SW: byte perdido */
                        g_dbg_rx_dropped[ch]++;
                    }
                }
                got_any = true;
            }

            rx_bd_recycle(bd);
            head = (head + 1U) % RX_BD_COUNT;
            n_bds++;
        }

        if (n_bds > 0) {
            g_rx_bd_head[ch] = head;
            rx_bd_publish(ch, head);   /* devolver los BDs reciclados al motor */
        }

        if (got_any && dev && dev->rx_callback) {
            __atomic_fetch_or(&g_rx_pending_mask, 1U << ch, __ATOMIC_RELEASE);
            rtems_semaphore_release(g_rx_notify_sem);
        }
    }
}

/* =========================================================================
 * ISR EOAF — TX_ISR_EOF_HANDLER (bloque propio, IRQ 123)
 *
 * Diagnóstico/uso: dispara cuando un canal termina de transmitir su lote.
 * Lee TX_DONE (qué canales), lo acumula, y limpia con W1C. Independiente del
 * MCDMA: si esta ISR dispara, la entrega GIC/RTEMS de IRQs del PL funciona.
 * ========================================================================= */
static rtems_isr EOAF_ISR(void *arg) {
    (void)arg;
    g_dbg_eoaf_isr++;
    g_bench_irq_tx++;
    uint32_t done = reg_read(TXISR_BASE + TXISR_TX_DONE);
    if (done) {
        g_dbg_eoaf_mask |= done;
        reg_write(TXISR_BASE + TXISR_TX_DONE_CLEAR, done);   /* W1C: limpiar */

        /* Varios canales pueden transmitir a la vez: despertar solo a los que
         * han terminado. El bit sticky ya identifica a cada uno. */
        for (uint32_t ch = 0; ch < g_hw_count; ch++) {
            if (done & (1U << ch)) rtems_semaphore_release(g_tx_eof_sem[ch]);
        }
    }
}

/* =========================================================================
 * Tarea de despacho RX — invoca callbacks fuera de contexto ISR.
 * La copia al ring y el re-armado del BD los hace la S2MM_ISR (IRQ 122);
 * esta tarea solo despierta con g_rx_notify_sem para llamar a los callbacks.
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
 * MCDMA_Global_Init — inicializa el MCDMA + todos los BDs SG
 * ========================================================================= */
static void MCDMA_Global_Init(void) {
    /* ── Reset global de ambas direcciones ─────────────────────────────── */
    MCDMA_WR(MM2S_BASE, MCDMA_DIR_CCR, MCDMA_CCR_RESET);
    for (uint32_t t = 0; t < 100000; t++) {
        if (!(MCDMA_RD(MM2S_BASE, MCDMA_DIR_CCR) & MCDMA_CCR_RESET)) break;
    }
    MCDMA_WR(S2MM_BASE, MCDMA_DIR_CCR, MCDMA_CCR_RESET);
    for (uint32_t t = 0; t < 100000; t++) {
        if (!(MCDMA_RD(S2MM_BASE, MCDMA_DIR_CCR) & MCDMA_CCR_RESET)) break;
    }

    /* ── Arrancar motor global (ambas direcciones) ──────────────────────── */
    MCDMA_WR(MM2S_BASE, MCDMA_DIR_CCR, MCDMA_CCR_RS);
    MCDMA_WR(S2MM_BASE, MCDMA_DIR_CCR, MCDMA_CCR_RS);

    /* ── Configurar BD TX (anillo de 1: NDESC → sí mismo) ─────────────── */
    uintptr_t tx_bd_pa = (uintptr_t)&g_tx_bd;
    uintptr_t tx_fr_pa = (uintptr_t)g_tx_frame;

    memset(&g_tx_bd, 0, sizeof(g_tx_bd));
    g_tx_bd.ndesc     = (uint32_t)tx_bd_pa;
    g_tx_bd.ndesc_msb = (uint32_t)(tx_bd_pa >> 32);
    g_tx_bd.bufa      = (uint32_t)tx_fr_pa;
    g_tx_bd.bufa_msb  = (uint32_t)(tx_fr_pa >> 32);
    g_tx_bd.ctrl      = BD_CTRL_SOF | BD_CTRL_EOF;  /* longitud se fija en Send */
    bd_flush(&g_tx_bd);

    /* Canal MM2S 1: CDESC debe escribirse con RS=0 (PG288 §3).
     * Secuencia: CR(RS=0) → CDESC → CHEN → CR(RS=1).
     * TDESC se escribe en cada llamada a Transceiver_Send. */
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_CR(1),
             MCDMA_CH_CR_INIT & ~MCDMA_CH_CR_RS);           /* RS=0, IRQs habilitados */
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_CDESC(1),     (uint32_t)tx_bd_pa);
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_CDESC_MSB(1), (uint32_t)(tx_bd_pa >> 32));
    MCDMA_WR(MM2S_BASE, MCDMA_DIR_CHEN, 0x01U);             /* habilitar canal 1 */
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_CR(1), MCDMA_CH_CR_INIT);/* RS=1 */

    /* ── Configurar BDs RX (uno por canal, anillo de 1) ────────────────── */
    /* Fase 1: CR(RS=0) + CDESC para todos los canales (RS debe ser 0 al escribir CDESC) */
    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        uint32_t  mcdma_ch = ch + 1;
        uintptr_t head_pa  = (uintptr_t)&g_rx_bd[ch][0];

        g_rx_bd_head[ch] = 0;

        for (uint32_t k = 0; k < RX_BD_COUNT; k++) {
            MCDMA_BD *bd      = &g_rx_bd[ch][k];
            uintptr_t next_pa = (uintptr_t)&g_rx_bd[ch][(k + 1U) % RX_BD_COUNT];
            uintptr_t buf_pa  = (uintptr_t)g_rx_dma_bufs[ch][k];

            memset(bd, 0, sizeof(*bd));
            bd->ndesc     = (uint32_t)next_pa;              /* anillo circular */
            bd->ndesc_msb = (uint32_t)(next_pa >> 32);
            bd->bufa      = (uint32_t)buf_pa;
            bd->bufa_msb  = (uint32_t)(buf_pa >> 32);
            bd->ctrl      = DMA_RX_DMA_SIZE;   /* solo longitud: ver rx_bd_recycle */
            bd_flush(bd);
        }

        MCDMA_WR(S2MM_BASE, MCDMA_CHN_CR(mcdma_ch),
                 MCDMA_CH_CR_INIT & ~MCDMA_CH_CR_RS);       /* RS=0 */
        MCDMA_WR(S2MM_BASE, MCDMA_CHN_CDESC(mcdma_ch),     (uint32_t)head_pa);
        MCDMA_WR(S2MM_BASE, MCDMA_CHN_CDESC_MSB(mcdma_ch), (uint32_t)(head_pa >> 32));
    }
    /* Fase 2: habilitar canales en CHEN, luego RS=1 + TDESC (arma recepción).
     * TDESC apunta al último BD del anillo: el motor tiene RX_BD_COUNT
     * descriptores por delante y no vuelve a quedarse sin cola. */
    MCDMA_WR(S2MM_BASE, MCDMA_DIR_CHEN, (1U << g_hw_count) - 1U);
    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        uint32_t mcdma_ch = ch + 1;

        MCDMA_WR(S2MM_BASE, MCDMA_CHN_CR(mcdma_ch), MCDMA_CH_CR_INIT); /* RS=1 */
        rx_bd_publish(ch, 0U);
    }

    /* Interrupciones (bitstream con c_enable_multi_intr=1 + OR-reduce a 2 líneas):
     *   MM2S 121 → DMA de TX volcado a FIFO (MM2S_ISR, contabilidad).
     *   S2MM 122 → paquete RX recibido (S2MM_ISR: copia al ring + re-arma).
     *   EOAF 123 → fin físico de transmisión por canal (libera Transceiver_Send).
     * Los bits IOC/ERR del CR por canal (MCDMA_CH_CR_INIT) ya se graban. */

    /* ── Semáforo TX: mutex del recurso DMA compartido (empieza en 1) ────── */
    rtems_semaphore_create(rtems_build_name('M','C','T','X'), 1,
                           RTEMS_SIMPLE_BINARY_SEMAPHORE | RTEMS_FIFO, 0,
                           &g_tx_sem_id);

    /* ── Fin del volcado DMA de un trozo: lo libera MM2S_ISR (empieza en 0) ─ */
    rtems_semaphore_create(rtems_build_name('T','X','D','M'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0,
                           &g_tx_dma_sem);

    /* ── Fin de transmisión física, uno por canal: lo libera EOAF_ISR ─────── */
    for (uint32_t ch = 0; ch < g_hw_count; ch++) {
        rtems_semaphore_create(rtems_build_name('T','X','E', (char)('0' + ch)), 0,
                               RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0,
                               &g_tx_eof_sem[ch]);
    }

    /* ── Semáforo de notificación RX ────────────────────────────────────── */
    rtems_semaphore_create(rtems_build_name('R','X','N','T'), 0,
                           RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0,
                           &g_rx_notify_sem);

    /* ── Tarea de despacho RX ───────────────────────────────────────────── */
    rtems_id rx_task;
    rtems_task_create(rtems_build_name('R','X','D','P'), 10,
                      RTEMS_MINIMUM_STACK_SIZE * 2,
                      RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &rx_task);
    rtems_task_start(rx_task, RX_Dispatch_Task, 0);

    /* ── ISRs — usar SHARED para no fallar si hay un vector residual ──────
     * Con UNIQUE el install devuelve error silencioso si el vector ya existe,
     * dejando el semáforo TX bloqueado para siempre. */
    rtems_status_code isr_sc;
    isr_sc = rtems_interrupt_handler_install(
        IRQ_MCDMA_MM2S, "MCDMA_TX",
        RTEMS_INTERRUPT_SHARED, MM2S_ISR, NULL);
    if (isr_sc != RTEMS_SUCCESSFUL)
        printf("[TRANSCEIVER] ERROR: IRQ MM2S install sc=%d\n", (int)isr_sc);
    isr_sc = rtems_interrupt_handler_install(
        IRQ_MCDMA_S2MM, "MCDMA_RX",
        RTEMS_INTERRUPT_SHARED, S2MM_ISR, NULL);
    if (isr_sc != RTEMS_SUCCESSFUL)
        printf("[TRANSCEIVER] ERROR: IRQ S2MM install sc=%d\n", (int)isr_sc);

    /* ISR de tu bloque EOAF (TX_ISR_EOF_HANDLER, IRQ 123). Habilita todos los
     * canales en el bloque y engancha la ISR. Aísla si la entrega GIC funciona. */
    reg_write(TXISR_BASE + TXISR_IRQ_ENABLE, 0x3FFFU);   /* 14 canales habilitados */
    isr_sc = rtems_interrupt_handler_install(
        IRQ_TX_EOAF, "TX_EOAF",
        RTEMS_INTERRUPT_SHARED, EOAF_ISR, NULL);
    if (isr_sc != RTEMS_SUCCESSFUL)
        printf("[TRANSCEIVER] ERROR: IRQ EOAF install sc=%d\n", (int)isr_sc);

    TRANS_DEBUG("MCDMA global init OK | MM2S IRQ=%d  S2MM IRQ=%d  EOAF IRQ=%d | %u canales RX\n",
                IRQ_MCDMA_MM2S, IRQ_MCDMA_S2MM, IRQ_TX_EOAF, g_hw_count);
}

/* =========================================================================
 * Transceiver_Init — registra un canal y configura su UART
 * ========================================================================= */
rtems_status_code Transceiver_Init(Transceiver *dev, uint32_t id,
                                   const Transceiver_Config_t *cfg) {
    if (id >= MAX_TRANSCEIVERS || id >= g_hw_count) return RTEMS_INVALID_ID;

    dev->id          = id;
    dev->config_base = UART_CFG_BASE + id * UART_CFG_STRIDE;

    dev->rx_buffer   = g_sw_rx_bufs[id];
    dev->rx_buf_size = sizeof(g_sw_rx_bufs[id]);
    dev->rx_head     = 0;
    dev->rx_tail     = 0;
    dev->rx_count    = 0;

    dev->rx_callback     = NULL;
    dev->rx_callback_arg = NULL;

    g_instances[id] = dev;

    /* ── Configurar UART vía AXI_UART_CONFIG ─────────────────────────── */
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

    TRANS_DEBUG("UART %u OK | cfg=0x%08lX | sw_ring=%p\n",
                id, (unsigned long)dev->config_base,
                (void *)dev->rx_buffer);
    return RTEMS_SUCCESSFUL;
}

/* =========================================================================
 * Transceiver_Send — envía datos por el canal `dev->id`
 *
 * El MM2S es un recurso único, pero solo se ocupa mientras la DMA vuelca el
 * trozo a la FIFO del canal: microsegundos. La espera larga —que la UART saque
 * los bytes por el cable, milisegundos— se hace fuera del mutex y por canal,
 * de modo que varios canales transmiten a la vez.
 *
 * El frame incluye 2 bytes de header para TX_DMA_ROUTER:
 *   byte 0: {CH_ID[3:0], LEN[11:8]}
 *   byte 1: LEN[7:0]
 *   bytes 2..2+len-1: payload
 * ========================================================================= */
/* Envía un único frame cuyo payload cabe en la FIFO del canal, y espera a que
 * salga físicamente. No debe tenerse g_tx_sem_id al entrar. */
static int tx_send_chunk(uint32_t ch, const uint8_t *data, size_t len) {
    size_t total = TX_HDR_SIZE + len;

    /* Preparar el evento de fin de lote: limpiar el bit sticky del canal en el
     * TX_ISR_EOF_HANDLER y drenar cualquier señalización EOF residual. */
    reg_write(TXISR_BASE + TXISR_TX_DONE_CLEAR, 1U << ch);
    while (rtems_semaphore_obtain(g_tx_eof_sem[ch], RTEMS_NO_WAIT, 0) == RTEMS_SUCCESSFUL) { }

    /* ── Sección crítica: MM2S, buffer de TX y BD son de uso exclusivo ────── */
    rtems_semaphore_obtain(g_tx_sem_id, RTEMS_WAIT, RTEMS_NO_TIMEOUT);

    while (rtems_semaphore_obtain(g_tx_dma_sem, RTEMS_NO_WAIT, 0) == RTEMS_SUCCESSFUL) { }

    g_tx_frame[0] = TX_HDR0(ch, len);
    g_tx_frame[1] = TX_HDR1(len);
    memcpy(g_tx_frame + TX_HDR_SIZE, data, len);
    rtems_cache_flush_multiple_data_lines(g_tx_frame, total);

    /* Actualizar BD: longitud total del frame (header + payload) */
    g_tx_bd.sideband_sts = 0;
    g_tx_bd.ctrl         = BD_CTRL_SOF | BD_CTRL_EOF | (uint32_t)total;
    bd_flush(&g_tx_bd);

    /* Escribir TDESC dispara la transferencia en el canal MM2S 1: el DMA vuelca
     * el frame entero a la FIFO del canal, que por construcción tiene sitio. */
    uintptr_t bd_pa = (uintptr_t)&g_tx_bd;
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_TDESC(1),     (uint32_t)bd_pa);
    MCDMA_WR(MM2S_BASE, MCDMA_CHN_TDESC_MSB(1), (uint32_t)(bd_pa >> 32));

    /* Esperar solo a que la DMA suelte el trozo en la FIFO (MM2S IOC). */
    rtems_status_code sc = rtems_semaphore_obtain(
        g_tx_dma_sem, RTEMS_WAIT, RTEMS_MILLISECONDS_TO_TICKS(100));

    rtems_semaphore_release(g_tx_sem_id);
    /* ── Fin de la sección crítica: otro canal ya puede usar el MM2S ──────── */

    if (sc != RTEMS_SUCCESSFUL) {
        g_bench_err++;
        TRANS_DEBUG("TX timeout CH%u: MM2S IOC no llego. CSR=0x%08X\n",
                    (unsigned)ch, (unsigned)MCDMA_RD(MM2S_BASE, MCDMA_DIR_CSR));
        return -1;
    }

    /* Esperar el fin de transmisión física de ESTE canal, sin bloquear al resto.
     * Al volver, su FIFO está vacía y admite el trozo siguiente. */
    sc = rtems_semaphore_obtain(g_tx_eof_sem[ch], RTEMS_WAIT,
                                RTEMS_MILLISECONDS_TO_TICKS(1000));
    if (sc != RTEMS_SUCCESSFUL) {
        g_bench_err++;
        TRANS_DEBUG("TX timeout CH%u: EOAF no llego (eof_isr=%u, mask=0x%04X)\n",
                    (unsigned)ch, (unsigned)g_dbg_eoaf_isr,
                    (unsigned)g_dbg_eoaf_mask);
        return -1;
    }

    g_bench_bytes_tx += len;
    return (int)len;
}

/* Trocea el mensaje en frames que quepan en la FIFO del canal. Cada trozo se
 * entrega a la DMA solo cuando el anterior ha salido físicamente por la UART
 * (EOAF), de modo que la FIFO nunca desborda. */
int Transceiver_Send(Transceiver *dev, const uint8_t *data, size_t len) {
    if (len == 0) return 0;
    if (len > DMA_TX_BUF_SIZE) len = DMA_TX_BUF_SIZE;

    uint32_t ch   = dev->id;
    size_t   sent = 0;

    /* Cada trozo toma y suelta el MM2S por su cuenta. Entre trozo y trozo este
     * canal está esperando a su UART, y el MM2S queda libre para los demás. */
    while (sent < len) {
        size_t chunk = len - sent;
        if (chunk > TX_CHUNK_MAX) chunk = TX_CHUNK_MAX;

        int r = tx_send_chunk(ch, data + sent, chunk);
        if (r < 0) return sent > 0 ? (int)sent : -1;   /* envío parcial */
        sent += (size_t)r;
    }

    return (int)sent;
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
    g_dbg_rx_read[dev->id] += got;
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
 * Transceiver_Global_INIT — inicializa el MCDMA y toda la infraestructura
 *
 * El hardware serial_bridge tiene exactamente MAX_TRANSCEIVERS (14) UARTs
 * conectados a los 14 canales S2MM del MCDMA. No hay registro SysInfo;
 * el número de canales es fijo en el bitstream.
 * ========================================================================= */
uint32_t Transceiver_Global_INIT(void) {
    g_hw_count = MAX_TRANSCEIVERS;
    MCDMA_Global_Init();
    printf("[TRANSCEIVER] MCDMA init OK: %u canales TX/RX\n", g_hw_count);
    return g_hw_count;
}

/* =========================================================================
 * Instrumentación de benchmark (transceiver_bench.h)
 * ========================================================================= */
void Transceiver_BenchStats(Transceiver_BenchStats_t *out) {
    if (!out) return;
    out->variant       = BENCH_VARIANT_NAME;
    /* Send espera a la ISR EOAF: al retornar, la UART ya emitió el último bit. */
    out->tx_blocking   = true;
    /* Un único canal MM2S serializado por g_tx_sem_id. */
    out->tx_concurrent = false;
    out->irq_lines     = 3;   /* MM2S 121, S2MM 122, EOAF 123 */
    out->isr_count     = 3;
    out->task_count    = 1;   /* RX_Dispatch_Task */
    /* g_tx_sem_id, g_tx_dma_sem, g_rx_notify_sem + un g_tx_eof_sem por canal */
    out->sem_count     = 3 + g_hw_count;
    out->static_bytes  = sizeof(g_tx_bd) + sizeof(g_tx_frame) + sizeof(g_rx_bd) +
                         sizeof(g_rx_dma_bufs) + sizeof(g_sw_rx_bufs);
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

void Transceiver_BenchDbgReset(void) {
    for (uint32_t c = 0; c < MAX_TRANSCEIVERS; c++) {
        g_dbg_rx_pkts[c]     = 0;
        g_dbg_rx_bytes[c]    = 0;
        g_dbg_rx_dropped[c]  = 0;
        g_dbg_rx_empty_bd[c] = 0;
        g_dbg_rx_read[c]     = 0;
        /* Snapshot de los acumuladores del motor para reportar delta del test. */
        if (c < g_hw_count) {
            uint32_t mc = c + 1;
            g_dbg_motor_pktcnt0[c]  = MCDMA_RD(S2MM_BASE, MCDMA_CHN_PKTCNT(mc));
            g_dbg_motor_pktdrop0[c] = MCDMA_RD(S2MM_BASE, MCDMA_CHN_PKTDROP(mc));
        }
    }
}

void Transceiver_BenchDumpRx(uint32_t ch) {
    if (ch >= g_hw_count) return;
    uint32_t mc = ch + 1;   /* MCDMA indexa los canales desde 1 */
    MCDMA_BD *bd = &g_rx_bd[ch][g_rx_bd_head[ch]];   /* el BD que toca consumir */
    bd_invalidate(bd);

    printf("[DUMP] CH%u S2MM (MCDMA canal %u)\n", (unsigned)ch, (unsigned)mc);
    printf("       CCR   =0x%08X  CSR=0x%08X  CHEN=0x%08X\n",
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CCR),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CSR),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHEN));
    printf("       CH_CR =0x%08X  CH_SR=0x%08X\n",
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_CHN_CR(mc)),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_CHN_SR(mc)));
    printf("       BD sts=0x%08X (COMPLETE=%u len=%u)  ctrl=0x%08X\n",
           (unsigned)bd->sts, (unsigned)(bd->sts & BD_STS_COMPLETE ? 1 : 0),
           (unsigned)(bd->sts & BD_STS_LEN_MASK), (unsigned)bd->ctrl);
    printf("       s2mm_isr_total=%u  ch_isr=%u  ch_err=%u\n",
           (unsigned)g_dbg_s2mm_isr_total, (unsigned)g_dbg_s2mm_ch[ch],
           (unsigned)g_dbg_s2mm_err[ch]);

    /* Pocos paquetes con datos => el canal deja de recibir (problema de BD).
     * Muchos paquetes de longitud 0 => llegan IRQs sin bytes (problema de FIFO). */
    uint32_t n = g_dbg_rx_pkts[ch];
    printf("       rx_pkts=%u  hw_bytes=%u  leidos=%u  en_ring=%u  ring_drop=%u  irq_sin_bd=%u\n",
           (unsigned)n, (unsigned)g_dbg_rx_bytes[ch], (unsigned)g_dbg_rx_read[ch],
           (unsigned)__atomic_load_n(&g_instances[ch]->rx_count, __ATOMIC_ACQUIRE),
           (unsigned)g_dbg_rx_dropped[ch], (unsigned)g_dbg_rx_empty_bd[ch]);
    printf("       len[]=");
    uint32_t shown = n < DBG_PKT_MAX ? n : DBG_PKT_MAX;
    for (uint32_t i = 0; i < shown; i++) printf("%u ", (unsigned)g_dbg_rx_len[ch][i]);
    if (n > DBG_PKT_MAX) printf("... (+%u)", (unsigned)(n - DBG_PKT_MAX));
    printf("\n");

    /* Si el HW reparte mal los bytes (TDEST), el total por canal lo delata:
     * unos canales de más y otros de menos, con el mismo número de paquetes. */
    printf("       [HW] bytes entregados por canal: ");
    for (uint32_t c = 0; c < g_hw_count; c++)
        printf("%u:%u ", (unsigned)c, (unsigned)g_dbg_rx_bytes[c]);
    printf("\n");

    /* Punteros del motor: CDESC dice por que descriptor va, TDESC hasta donde
     * tiene permiso. Si CDESC se quedo parado o TDESC apunta detras, el motor
     * cree que la cola esta vacia. */
    printf("       CDESC=0x%08X  TDESC=0x%08X  (base anillo=0x%08X, paso=%u)\n",
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_CHN_CDESC(mc)),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_CHN_TDESC(mc)),
           (unsigned)(uintptr_t)&g_rx_bd[ch][0], (unsigned)sizeof(MCDMA_BD));

    /* Contadores DEL PROPIO MOTOR en el puerto S_AXIS_S2MM (la frontera no
     * simulada en S1-S7). Discriminan candidato A vs B sin ambigüedad:
     *   PKTCNT  = paquetes que CRUZARON el puerto hacia el motor.
     *   PKTDROP = paquetes que el motor TIRÓ por no tener BD servible.
     * Si PKTCNT>=4: el stream completo llegó al motor -> fallo en el motor o su
     * programación (A). Si PKTCNT=1..2 y PKTDROP=0: el stream se cortó aguas
     * arriba (B). Si PKTDROP>0: el driver no rearma el BD a tiempo (A, cadencia). */
    uint32_t pktcnt_now  = MCDMA_RD(S2MM_BASE, MCDMA_CHN_PKTCNT(mc));
    uint32_t pktdrop_now = MCDMA_RD(S2MM_BASE, MCDMA_CHN_PKTDROP(mc));
    printf("       [MOTOR] PKTCNT=%u (delta=%u)  PKTDROP=%u (delta=%u)  (canal %u)\n",
           (unsigned)pktcnt_now,  (unsigned)(pktcnt_now  - g_dbg_motor_pktcnt0[ch]),
           (unsigned)pktdrop_now, (unsigned)(pktdrop_now - g_dbg_motor_pktdrop0[ch]),
           (unsigned)mc);
    printf("       [MOTOR] DIR_ERR=0x%08X  CPKTDROP=0x%08X\n",
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_ERR),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CPKTDROP));
    printf("       [MOTOR] CHOBS1..6=0x%08X 0x%08X 0x%08X 0x%08X 0x%08X 0x%08X\n",
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS1),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS2),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS3),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS4),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS5),
           (unsigned)MCDMA_RD(S2MM_BASE, MCDMA_DIR_CHOBS6));

    /* Anillo completo, no solo el BD en curso. Si hay descriptores cerrados que
     * la ISR no ha contado, el fallo esta en el recorrido del anillo; si no los
     * hay, el motor dejo de entregar. */
    for (uint32_t k = 0; k < RX_BD_COUNT; k++) {
        MCDMA_BD *b = &g_rx_bd[ch][k];
        bd_invalidate(b);
        uint32_t st = b->sts;
        /* sts crudo: los bits altos (31..26) no se decodifican aqui porque
         * COMPLETE comparte el bit 31 con SOF del control. Lo que importa es si
         * hay descriptores cerrados que la ISR no conto, y con que longitud. */
        printf("       BD[%u]%s sts=0x%08X (CMPLT=%u len=%u) ctrl=0x%08X ndesc=0x%08X\n",
               (unsigned)k, (k == g_rx_bd_head[ch]) ? "<-head" : "      ",
               (unsigned)st,
               (unsigned)((st & BD_STS_COMPLETE) ? 1U : 0U),
               (unsigned)(st & BD_STS_LEN_MASK),
               (unsigned)b->ctrl, (unsigned)b->ndesc);
    }
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
