/* transceiver_bench.h — instrumentación común a las tres variantes de transporte
 *
 * Fichero IDÉNTICO en configurable_transceiver_inter (GPIO),
 * lince_comunicacion_serial_dma_pcb (AXI-DMA x14) y serial_bridge (MCDMA).
 * Lo incluye transceiver.h al final, de modo que bench_main.c puede leer las
 * mismas métricas de los tres drivers sin conocer sus contadores internos.
 *
 * La variante se autodetecta por macros que solo existen en un transceiver.h:
 *   MCDMA_BASE → MCDMA      DMA0_BASE → DMA14      ninguna → GPIO
 */
#ifndef TRANSCEIVER_BENCH_H
#define TRANSCEIVER_BENCH_H

#include <stdint.h>
#include <stdbool.h>

#if defined(MCDMA_BASE)
  #define BENCH_VARIANT_MCDMA 1
  #define BENCH_VARIANT_NAME  "MCDMA"
#elif defined(DMA0_BASE)
  #define BENCH_VARIANT_DMA14 1
  #define BENCH_VARIANT_NAME  "DMA14"
#else
  #define BENCH_VARIANT_GPIO  1
  #define BENCH_VARIANT_NAME  "GPIO"
#endif

typedef struct {
    const char *variant;      /* BENCH_VARIANT_NAME */

    /* ── Coste estructural (constante, conocido en Global_INIT) ─────────── */
    bool     tx_blocking;     /* true: Send retorna tras la TX física por la UART */
    bool     tx_concurrent;   /* true: varios canales pueden transmitir a la vez  */
    uint32_t irq_lines;       /* líneas de IRQ PL→PS ocupadas */
    uint32_t isr_count;       /* ISRs instaladas por el driver */
    uint32_t task_count;      /* tareas RTEMS creadas por el driver */
    uint32_t sem_count;       /* semáforos RTEMS creados por el driver */
    uint64_t static_bytes;    /* buffers estáticos del driver (.bss) */
    uint64_t heap_bytes;      /* buffers pedidos con malloc por el driver */

    /* ── Contadores dinámicos (reiniciables con Transceiver_BenchReset) ─── */
    uint64_t irq_tx;          /* interrupciones atribuibles a TX */
    uint64_t irq_rx;          /* interrupciones atribuibles a RX */
    uint64_t bytes_tx;        /* bytes entregados al hardware de TX */
    uint64_t bytes_rx;        /* bytes copiados al ring SW de RX */
    uint64_t err_count;       /* errores señalados por el hardware */
} Transceiver_BenchStats_t;

#ifdef __cplusplus
extern "C" {
#endif

/* Vuelca el estado de instrumentación del driver. */
void Transceiver_BenchStats(Transceiver_BenchStats_t *out);

/* Pone a cero los contadores dinámicos (no los estructurales). */
void Transceiver_BenchReset(void);

/* Reprograma el baudrate de un canal ya inicializado, dejando el resto de la
 * trama en 8N1 LSB. Existe porque volver a llamar a Transceiver_Init para
 * cambiar de velocidad recrearía tareas y semáforos en la variante GPIO. */
void Transceiver_SetBaud(Transceiver *dev, uint32_t baud);

/* Vuelca por consola el estado del hardware de recepción del canal `ch`.
 * Se invoca solo cuando el autodiagnóstico no encuentra lazo TX→RX, para
 * distinguir "el receptor no está armado" de "no llega ningún byte". */
void Transceiver_BenchDumpRx(uint32_t ch);

/* Pone a cero la traza de RX (paquetes, bytes por canal, descartes), para poder
 * atribuir lo medido a un único test en vez de a todo lo corrido desde el boot. */
void Transceiver_BenchDbgReset(void);

#ifdef __cplusplus
}
#endif

#endif /* TRANSCEIVER_BENCH_H */
