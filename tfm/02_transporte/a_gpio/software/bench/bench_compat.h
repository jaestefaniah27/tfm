/* bench_compat.h — utilidades comunes del benchmark de transportes
 *
 * Fichero IDÉNTICO en los tres proyectos. Aísla lo único que depende de la
 * plataforma (el contador de ciclos) y el formato de salida CSV.
 *
 * La variante activa la decide transceiver_bench.h (BENCH_VARIANT_NAME).
 */
#ifndef BENCH_COMPAT_H
#define BENCH_COMPAT_H

#include <stdint.h>
#include <stdio.h>
#include "transceiver.h"

/* =========================================================================
 * Reloj: contador de sistema del ARM (CNTVCT_EL0), invariante al DVFS.
 * El tick de RTEMS (10 ms) es demasiado grueso para medir latencias.
 * ========================================================================= */
static inline uint64_t bench_cycles(void) {
    uint64_t v;
    __asm__ volatile("isb; mrs %0, cntvct_el0" : "=r"(v));
    return v;
}

static inline uint64_t bench_freq_hz(void) {
    uint64_t v;
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(v));
    return v;
}

/* Microsegundos transcurridos desde `start` (obtenido con bench_cycles). */
static inline uint64_t bench_us_since(uint64_t start) {
    uint64_t f = bench_freq_hz();
    if (f == 0) return 0;
    return ((bench_cycles() - start) * 1000000ULL) / f;
}

/* =========================================================================
 * Salida CSV. Toda línea de resultado lleva el prefijo BENCH, para poder
 * extraerla del log de consola con un grep, ignorando la traza de debug.
 *
 *   BENCH,<variante>,<test>,<métrica>,<unidad>,<valor>,<nota>
 * ========================================================================= */
#define BENCH_ROW(test, metric, unit, fmt, val, note)                      \
    do {                                                                   \
        printf("BENCH,%s,%s,%s,%s," fmt ",%s\n",                           \
               BENCH_VARIANT_NAME, (test), (metric), (unit), (val), (note));\
        fflush(stdout);                                                    \
    } while (0)

/* Cabecera del CSV: la imprime solo una vez el arranque del benchmark. */
static inline void bench_csv_header(void) {
    printf("BENCH,variant,test,metric,unit,value,note\n");
    fflush(stdout);
}

/* =========================================================================
 * Topología física de la PCB (idéntica en las tres variantes).
 *   Bus A (RS485 multidrop): maestro CH0  | esclavos CH1..CH6
 *   Bus B (RS422):           maestro CH7  | esclavos CH8..CH10
 *   Bus C (RS422):           maestro CH11 | esclavos CH12..CH13
 * ========================================================================= */
#define BENCH_TX_CH   0   /* maestro del bus A: emisor de referencia */
#define BENCH_RX_CH   1   /* primer esclavo del bus A: receptor de referencia */

/* Maestros de cada bus, para el test de TX concurrente. */
#define BENCH_MASTERS { 0, 7, 11 }
/* Primer esclavo de cada bus, en el mismo orden que BENCH_MASTERS. */
#define BENCH_LISTENERS { 1, 8, 12 }
#define BENCH_N_BUSES 3

/* Esclavos del bus A (multidrop): todos oyen al maestro CH0. */
#define BENCH_BUSA_SLAVES { 1, 2, 3, 4, 5, 6 }
#define BENCH_BUSA_N 6

#endif /* BENCH_COMPAT_H */
