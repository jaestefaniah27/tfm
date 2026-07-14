/* transceiver.c */
#include "transceiver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* === Mapa de Memoria Global (Compacto) === */
//#define TRANSCEIVER_BASE_START  0xA0000000
//#define TRANSCEIVER_STRIDE      0x1000      /* 4KB por bloque */

static uint32_t g_hw_count = 0;
static uintptr_t g_hw_base = 0;
static uintptr_t g_hw_stride = 0;

/* Dirección Fija del Bloque de Información del Sistema (Privado del Driver) */
#define SYS_INFO_ADDR           0xA0020000
#define GPIO_DATA_CH1          0x00
#define GPIO_DATA_CH2          0x08

#define IRQ_VECTOR_ID           121

/* === Offsets del AXI GPIO (Dual Channel) === */
#define REG_CH1_DATA  0x00  /* Output: Config + Control + TX Data */
#define REG_CH2_DATA  0x08  /* Input:  Status + RX Data */

/* Registros AXI INTC */
#define INTC_ISR   0x00
#define INTC_IER   0x08
#define INTC_IAR   0x0C
#define INTC_SIE   0x10
#define INTC_CIE   0x14
#define INTC_MER   0x1C

/* === Mapeo de Bits CANAL 1 (Output -> FPGA) === */
/* [Order(1) | DataBits(3) | Parity(3) | Stop(2) | Baud(6) | Read(1) | ErrOK(1) | Send(1) | DataIn(9)] | SLO(1) */
#define MASK_DATA_IN        0x000001FF
#define BIT_TX_SEND         (1 << 9)
#define BIT_ERROR_OK        (1 << 10)
#define BIT_DATA_READ       (1 << 11)
#define SHIFT_BAUD          12
#define SHIFT_STOP          18
#define SHIFT_PARITY        20
#define SHIFT_DATA_BITS     23
#define BIT_ORDER           (1 << 26)
#define BIT_SLO             (1 << 27) /* Bit para activar modo SLO */

/* === Mapeo de Bits CANAL 2 (Input <- FPGA) === */
/* [TxRdy(1) | FrameErr(1) | ParErr(1) | Full(1) | Empty(1) | DataOut(9)] */
#define MASK_DATA_OUT       0x000001FF
#define BIT_RX_EMPTY        (1 << 9)
#define BIT_RX_FULL         (1 << 10)
#define BIT_PAR_ERROR       (1 << 11)
#define BIT_FRAME_ERROR     (1 << 12)
#define BIT_TX_RDY          (1 << 13)

static Transceiver *g_instances[MAX_TRANSCEIVERS] = { NULL };

/* Cache para la dirección del INTC calculada dinámicamente */
static uintptr_t g_intc_addr = 0;

/* ── Contadores de benchmark (transceiver_bench.h) ─────────────────────────
 * El INTC agrupa TX y RX de los 14 canales en una sola línea hacia el PS, así
 * que irq_tx/irq_rx cuentan EVENTOS atendidos, no entradas a la ISR: una misma
 * entrada puede incrementar ambos si coinciden un fin de TX y un byte de RX. */
static volatile uint64_t g_bench_irq_tx   = 0;
static volatile uint64_t g_bench_irq_rx   = 0;
static volatile uint64_t g_bench_bytes_tx = 0;
static volatile uint64_t g_bench_bytes_rx = 0;
static volatile uint64_t g_bench_err      = 0;

/* --- Helpers --- */
static inline uint32_t reg_read(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}
static inline void reg_write(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

/* === TODO: RECOMPATIBILIZAR: Descubrimiento de Hardware === */
uint32_t Transceiver_Hardware_Discover(void) {
    uint32_t meta_val = reg_read(SYS_INFO_ADDR + GPIO_DATA_CH1);
    uint32_t base_val = reg_read(SYS_INFO_ADDR + GPIO_DATA_CH2);

    g_hw_count  = meta_val & 0xFFFF;
    g_hw_stride = (uintptr_t)((meta_val >> 16) & 0xFFFF);
    g_hw_base   = (uintptr_t)base_val;

    if (g_hw_count == 0 || g_hw_count > MAX_TRANSCEIVERS) return 0;
    if (g_hw_stride == 0) g_hw_stride = 0x1000;

    g_intc_addr = g_hw_base + (g_hw_count * g_hw_stride);

    TRANS_DEBUG("Detectados: %d | Base: 0x%08lX | INT: 0x%08lX\n", g_hw_count, (unsigned long)g_hw_base, (unsigned long)g_intc_addr);
    for (uint32_t i = 0; i < g_hw_count; i++) {
        uintptr_t addr = g_hw_base + (i * g_hw_stride);
        TRANS_DEBUG("  - Transceptor %d: 0x%08lX\n", i, (unsigned long)addr);
    }
    return g_hw_count;
}


/* === Helper Interno: Calcular dirección del INTC === */
static uintptr_t get_intc_addr(void) {
    /* Si ya la calculamos, retornarla */
    if (g_intc_addr != 0) return g_intc_addr;

    /* Si no, leer count y calcular: Base + (N * Stride) */
    uint32_t n = g_hw_count;
    g_intc_addr = g_hw_base + (n * g_hw_stride);
    printf("Detected %u transceivers. INTC at 0x%08lx\n", n, (unsigned long)g_intc_addr);
    return g_intc_addr;
}

/* --- Control Global INTC --- */
static void intc_enable_line(Transceiver *dev, uint32_t mask) {
    reg_write(dev->intc_base + INTC_SIE, mask);
}

/* --- Saca un byte de la cola de TX y lo entrega al registro del GPIO.
 * Requiere tx_count > 0 y llamarse con las interrupciones deshabilitadas. --- */
static void tx_push_byte_locked(Transceiver *dev) {
    uint8_t byte = dev->tx_buffer[dev->tx_head];
    dev->tx_head = (dev->tx_head + 1) % dev->tx_buf_size;
    dev->tx_count--;

    uintptr_t reg_out = dev->base_addr + REG_CH1_DATA;
    uint32_t val = reg_read(reg_out);
    val &= ~(MASK_DATA_IN | BIT_TX_SEND | BIT_DATA_READ);
    val |= (byte & MASK_DATA_IN);

    reg_write(reg_out, val);
    reg_write(reg_out, val | BIT_TX_SEND);
    for (volatile int k = 0; k < 50; k++);
    reg_write(reg_out, val & ~BIT_TX_SEND);

    g_bench_bytes_tx++;
}

/* --- Worker Task (RX) --- */
static rtems_task Rx_Worker_Task(rtems_task_argument arg) {
    Transceiver *dev = (Transceiver *)arg;
    rtems_event_set events;
    uintptr_t reg_out = dev->base_addr + REG_CH1_DATA;
    uintptr_t reg_in  = dev->base_addr + REG_CH2_DATA;

    intc_enable_line(dev, dev->mask_rx);

    for (;;) {
        rtems_event_receive(RTEMS_EVENT_0, RTEMS_WAIT | RTEMS_EVENT_ANY, RTEMS_NO_TIMEOUT, &events);

        while ((reg_read(reg_in) & BIT_RX_EMPTY) == 0) {
            uint32_t status_val = reg_read(reg_in);
            uint8_t byte = (uint8_t)(status_val & MASK_DATA_OUT);

            if (status_val & (BIT_PAR_ERROR | BIT_FRAME_ERROR)) g_bench_err++;

            rtems_semaphore_obtain(dev->mutex_id, RTEMS_WAIT, RTEMS_NO_TIMEOUT);
            if (dev->rx_count < dev->rx_buf_size) {
                dev->rx_buffer[dev->rx_tail] = byte;
                dev->rx_tail = (dev->rx_tail + 1) % dev->rx_buf_size;
                dev->rx_count++;
                g_bench_bytes_rx++;
            } else {
                g_bench_err++;   /* overrun del ring SW: byte perdido */
            }
            rtems_semaphore_release(dev->mutex_id);

            rtems_interrupt_level level;
            rtems_interrupt_local_disable(level);
            uint32_t current_ctrl = reg_read(reg_out);
            reg_write(reg_out, current_ctrl | BIT_DATA_READ);
            for(volatile int k=0; k<50; k++); 
            reg_write(reg_out, current_ctrl & ~BIT_DATA_READ);
            rtems_interrupt_local_enable(level);
        }

        if (dev->rx_callback) dev->rx_callback(dev->rx_callback_arg);
        intc_enable_line(dev, dev->mask_rx);
    }
}

/* --- ISR Maestra --- */
static rtems_isr Master_ISR(void *arg) {
    (void)arg;
    /* Usamos la dirección calculada dinámicamente */
    uintptr_t intc = get_intc_addr(); 
    uint32_t pending = reg_read(intc + INTC_ISR);

    /* Recorremos hasta el máximo posible o guardamos 'count' en una variable global */
    for (int i = 0; i < MAX_TRANSCEIVERS; i++) {
        Transceiver *dev = g_instances[i];
        if (!dev) continue;

        if (pending & dev->mask_rx) {
            g_bench_irq_rx++;
            reg_write(intc + INTC_IAR, dev->mask_rx);
            reg_write(intc + INTC_CIE, dev->mask_rx);
            rtems_event_send(dev->worker_id, RTEMS_EVENT_0);
        }

        if (pending & dev->mask_tx) {
            g_bench_irq_tx++;
            if (dev->tx_count > 0) {
                tx_push_byte_locked(dev);
            } else {
                dev->tx_busy = false;
            }
            reg_write(intc + INTC_IAR, dev->mask_tx);
        }
    }
}


/* --- Inicialización Global (Auto-Detect) --- */
void Transceiver_Global_INTC_Init(void) {
    /* 1. Detectar dirección del INTC automáticamente */
    uintptr_t intc = get_intc_addr();
    
    /* 2. Inicializar Hardware */
    reg_write(intc + INTC_MER, 0x3); 
    reg_write(intc + INTC_IER, 0x0);
    reg_write(intc + INTC_IAR, 0xFFFFFFFF);

    /* 3. Instalar ISR */
    rtems_interrupt_handler_install(IRQ_VECTOR_ID, "UART_Master", 
                                    RTEMS_INTERRUPT_UNIQUE, Master_ISR, NULL);
}

/* --- Init Transceiver --- */
rtems_status_code Transceiver_Init(Transceiver *dev, uint32_t id, const Transceiver_Config_t *cfg) {
    rtems_status_code sc;
    if (id >= MAX_TRANSCEIVERS) return RTEMS_INVALID_ID;

    dev->id = id;
    dev->base_addr = g_hw_base + (id * g_hw_stride);
    /* Asignar dirección del INTC calculada */
    dev->intc_base = get_intc_addr();
    
    
    dev->mask_rx = (1 << (2 * id));
    dev->mask_tx = (1 << (2 * id + 1));

    dev->rx_buf_size = 4096;
    dev->rx_buffer = malloc(dev->rx_buf_size);
    dev->rx_head = dev->rx_tail = dev->rx_count = 0;

    dev->tx_buf_size = 4096;
    dev->tx_buffer = malloc(dev->tx_buf_size);
    dev->tx_head = dev->tx_tail = dev->tx_count = 0;
    dev->tx_busy = false;

    sc = rtems_semaphore_create(rtems_build_name('T','R','X', '0'+id), 1, 
                                RTEMS_PRIORITY | RTEMS_BINARY_SEMAPHORE, 0, &dev->mutex_id);
    if (sc != RTEMS_SUCCESSFUL) return sc;
    
    sc = rtems_semaphore_create(rtems_build_name('T','X','M', '0'+id), 1, 
                                RTEMS_PRIORITY | RTEMS_BINARY_SEMAPHORE, 0, &dev->tx_mutex_id);
    if (sc != RTEMS_SUCCESSFUL) return sc;
    
    sc = rtems_task_create(rtems_build_name('W','K','R', '0'+id), 50, 
    RTEMS_MINIMUM_STACK_SIZE * 2,
    RTEMS_DEFAULT_MODES, RTEMS_DEFAULT_ATTRIBUTES, &dev->worker_id);
    if (sc != RTEMS_SUCCESSFUL) return sc;
    
    g_instances[id] = dev;

    if (cfg) {
        /* Leer estado actual para no borrar bits de control en vuelo */
        uint32_t val = reg_read(dev->base_addr + REG_CH1_DATA);
        
        /* Borrar Configuración Previa (Bits 12-31) */
        val &= 0x00000FFF; 
        
        val |= ((cfg->baud & 0x3F) << SHIFT_BAUD);
        val |= ((cfg->stop_bits & 0x3) << SHIFT_STOP);
        val |= ((cfg->parity & 0x7) << SHIFT_PARITY);
        val |= ((cfg->data_bits & 0x7) << SHIFT_DATA_BITS);
        if (cfg->slo_mode) val |= BIT_SLO;
        if (cfg->bit_order) val |= BIT_ORDER;

        reg_write(dev->base_addr + REG_CH1_DATA, val);
    }

    sc = rtems_task_start(dev->worker_id, Rx_Worker_Task, (rtems_task_argument)dev);
    
    intc_enable_line(dev, dev->mask_tx);
    
    return sc;
}

/* ... Las funciones Read/SendString siguen igual ... */
size_t Transceiver_Read(Transceiver *dev, uint8_t *buf, size_t maxlen) {
  size_t got = 0;
    rtems_semaphore_obtain(dev->mutex_id, RTEMS_WAIT, RTEMS_NO_TIMEOUT);
    while (got < maxlen && dev->rx_count > 0) {
        buf[got++] = dev->rx_buffer[dev->rx_head];
        dev->rx_head = (dev->rx_head + 1) % dev->rx_buf_size;
        dev->rx_count--;
    }
    rtems_semaphore_release(dev->mutex_id);
    return got;
}

/* Encola `len` bytes y arranca la transmisión si el canal está en reposo.
 * No bloquea: la ISR de TX va sacando el resto de la cola. */
int Transceiver_Send(Transceiver *dev, const uint8_t *data, size_t len) {
    if (len == 0) return 0;

    rtems_semaphore_obtain(dev->tx_mutex_id, RTEMS_WAIT, RTEMS_NO_TIMEOUT);

    size_t queued = 0;
    for (size_t i = 0; i < len; i++) {
        rtems_interrupt_level level;
        rtems_interrupt_local_disable(level);
        bool room = (dev->tx_count < dev->tx_buf_size);
        if (room) {
            dev->tx_buffer[dev->tx_tail] = data[i];
            dev->tx_tail = (dev->tx_tail + 1) % dev->tx_buf_size;
            dev->tx_count++;
            queued++;
        }
        rtems_interrupt_local_enable(level);
        if (!room) break;   /* buffer de TX lleno */
    }

    rtems_interrupt_level level;
    rtems_interrupt_local_disable(level);
    if (!dev->tx_busy && dev->tx_count > 0) {
        dev->tx_busy = true;
        tx_push_byte_locked(dev);
    }
    rtems_interrupt_local_enable(level);

    rtems_semaphore_release(dev->tx_mutex_id);

    if (queued < len) {
        g_bench_err++;
        return -1;
    }
    return (int)queued;
}

int Transceiver_SendString(Transceiver *dev, const char *s) {
    return Transceiver_Send(dev, (const uint8_t *)s, strlen(s));
}

void Transceiver_SetRxCallback(Transceiver *dev, void (*cb)(void *), void *arg) {
    dev->rx_callback = cb;
    dev->rx_callback_arg = arg;
}

uint32_t Transceiver_Global_INIT(void) {
    uint32_t count = Transceiver_Hardware_Discover();
    Transceiver_Global_INTC_Init();
    return count;
}

/* =========================================================================
 * Instrumentación de benchmark (transceiver_bench.h)
 * ========================================================================= */
void Transceiver_BenchStats(Transceiver_BenchStats_t *out) {
    if (!out) return;
    out->variant       = BENCH_VARIANT_NAME;
    /* Send encola y retorna; la ISR de TX drena la cola byte a byte. */
    out->tx_blocking   = false;
    /* Cada canal tiene su propio registro GPIO: los 14 transmiten a la vez. */
    out->tx_concurrent = true;
    out->irq_lines     = 1;   /* el AXI-INTC agrega los 28 eventos en una línea */
    out->isr_count     = 1;   /* Master_ISR */
    out->task_count    = g_hw_count;      /* un Rx_Worker_Task por canal */
    out->sem_count     = 2 * g_hw_count;  /* mutex_id + tx_mutex_id por canal */
    out->static_bytes  = 0;               /* los buffers salen del heap */
    out->heap_bytes    = (uint64_t)g_hw_count * (4096 + 4096);  /* rx + tx por canal */

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
    Transceiver *dev = g_instances[ch];
    if (!dev) { printf("[DUMP] CH%u sin instancia\n", (unsigned)ch); return; }

    uintptr_t intc = get_intc_addr();
    uint32_t st = reg_read(dev->base_addr + REG_CH2_DATA);

    printf("[DUMP] CH%u GPIO base=0x%08lX\n", (unsigned)ch, (unsigned long)dev->base_addr);
    printf("       STATUS=0x%08X  RxEmpty=%u RxFull=%u ParErr=%u FrameErr=%u TxRdy=%u\n",
           (unsigned)st,
           (unsigned)(st & BIT_RX_EMPTY ? 1 : 0), (unsigned)(st & BIT_RX_FULL ? 1 : 0),
           (unsigned)(st & BIT_PAR_ERROR ? 1 : 0), (unsigned)(st & BIT_FRAME_ERROR ? 1 : 0),
           (unsigned)(st & BIT_TX_RDY ? 1 : 0));
    printf("       INTC ISR=0x%08X IER=0x%08X  mask_rx=0x%08X\n",
           (unsigned)reg_read(intc + INTC_ISR), (unsigned)reg_read(intc + INTC_IER),
           (unsigned)dev->mask_rx);
    fflush(stdout);
}

void Transceiver_SetBaud(Transceiver *dev, uint32_t baud) {
    rtems_interrupt_level level;
    rtems_interrupt_local_disable(level);

    /* Preservar los bits de control y de dato en vuelo (0..11). */
    uint32_t val = reg_read(dev->base_addr + REG_CH1_DATA) & 0x00000FFF;
    val |= ((baud & 0x3F) << SHIFT_BAUD);
    val |= ((TRANSCEIVER_STOP_BITS_1 & 0x3) << SHIFT_STOP);
    val |= ((TRANSCEIVER_PARITY_NONE & 0x7) << SHIFT_PARITY);
    val |= ((TRANSCEIVER_DATA_BITS_8 & 0x7) << SHIFT_DATA_BITS);
    reg_write(dev->base_addr + REG_CH1_DATA, val);

    rtems_interrupt_local_enable(level);
}