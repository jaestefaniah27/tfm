/*
 * Receptor serie por PL (FIFO) usando AXI GPIO (RTEMS, ZynqMP)
 *  - axi_gpio_0 (canal 1, 8b)  -> DATA_OUT[7:0]  (PS lo lee)
 *  - axi_gpio_1 (canal 1, 1b)  -> EMPTY (1=vacío) (PS lo lee)
 *  - axi_gpio_2 (canal 1, 1b)  -> DATA_READ (PS lo escribe: 1->consume)
 *
 * Vivado: configurar direcciones de los GPIO y el ancho de datos como indicas.
 */

#include <rtems.h>
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

/* Direcciones (Address Editor) */
#define GPIO0_BASE   0xA0000000u   /* axi_gpio_0: DATA_OUT[7:0] (in) */
#define GPIO1_BASE   0xA0010000u   /* axi_gpio_1: EMPTY bit0 (in)   */
#define GPIO2_BASE   0xA0020000u   /* axi_gpio_2: DATA_READ bit0 (out) */

/* Registros canal 1 */
#define GPIO_DATA_OFFSET   0x00u    /* DATA */
#define GPIO_TRI_OFFSET    0x04u    /* (no se usa si ya fijaste dirección en HW) */

void mmu_map_pl_axi_early(void);

/* MMIO helpers con barrera */
static inline void mmio_write32(uintptr_t a, uint32_t v) {
  *(volatile uint32_t *)a = v;
  __asm__ volatile("dmb sy" ::: "memory");
}
static inline uint32_t mmio_read32(uintptr_t a) {
  __asm__ volatile("dmb sy" ::: "memory");
  return *(volatile uint32_t *)a;
}

/* Pulso breve en DATA_READ: 0->1->0 */
static inline void fifo_consume_pulse(void) {
  mmio_write32(GPIO2_BASE + GPIO_DATA_OFFSET, 1u);
  __asm__ volatile("dmb sy" ::: "memory");
  mmio_write32(GPIO2_BASE + GPIO_DATA_OFFSET, 0u);
}

/* Devuelve 1 si la FIFO está vacía (EMPTY=1), 0 si hay datos */
static inline int fifo_empty(void) {
  return (mmio_read32(GPIO1_BASE + GPIO_DATA_OFFSET) & 1u) ? 1 : 0;
}

/* Lee el byte actual del puerto DATA_OUT[7:0] */
static inline uint8_t fifo_peek_byte(void) {
  return (uint8_t)(mmio_read32(GPIO0_BASE + GPIO_DATA_OFFSET) & 0xFFu);
}

/* ==== Selección de canal (descomenta si tus señales están en canal 2) ==== */
// #define USE_CH2_GPIO0   /* DATA_OUT por canal 2 (offset 0x08) */
// #define USE_CH2_GPIO1   /* EMPTY por canal 2 (offset 0x08) */
// #define USE_CH2_GPIO2   /* DATA_READ por canal 2 (offset 0x0C para TRI, 0x08 para DATA) */

#ifdef USE_CH2_GPIO0
  #define GPIO0_DATA_OFF 0x08u
#else
  #define GPIO0_DATA_OFF 0x00u
#endif

#ifdef USE_CH2_GPIO1
  #define GPIO1_DATA_OFF 0x08u
#else
  #define GPIO1_DATA_OFF 0x00u
#endif

#ifdef USE_CH2_GPIO2
  #define GPIO2_DATA_OFF 0x08u
#else
  #define GPIO2_DATA_OFF 0x00u
#endif

static inline void dataread_write(uint32_t v) {
  mmio_write32(GPIO2_BASE + GPIO2_DATA_OFF, v);
}

static inline uint32_t empty_read(void) {
  return mmio_read32(GPIO1_BASE + GPIO1_DATA_OFF) & 1u;
}

static inline uint8_t dataout_read_byte(void) {
  return (uint8_t)(mmio_read32(GPIO0_BASE + GPIO0_DATA_OFF) & 0xFFu);
}

rtems_task Init(rtems_task_argument arg)
{
  mmu_map_pl_axi_early();
  printf("Iniciando receptor serie por PL (AXI GPIO)...\n");

  /* ETAPA 1: probar ESCRITURA a DATA_READ (GPIO2). Si se cuelga aquí, base/offset de GPIO2 están mal. */
  printf("[STEP] Seteando DATA_READ=0...\n");
  dataread_write(0u);
  printf("[OK] DATA_READ=0 escrito.\n");

  /* ETAPA 2: probar LECTURA de EMPTY (GPIO1). Si se cuelga aquí, base/offset de GPIO1 están mal. */
  printf("[STEP] Leyendo EMPTY (GPIO1)...\n");
  uint32_t e = empty_read();
  printf("[OK] EMPTY=%u (0=hay datos, 1=vacío)\n", e);

  /* ETAPA 3: probar LECTURA de DATA_OUT (GPIO0). Si se cuelga aquí, base/offset de GPIO0 están mal. */
  printf("[STEP] Leyendo DATA_OUT (GPIO0)...\n");
  uint8_t first = dataout_read_byte();
  printf("[OK] DATA_OUT=0x%02x\n", first);

  printf("RX por PL lista. Esperando lineas terminadas en LF (0x0A)...\n");

  enum { RX_BUF_SZ = 512 };
  char   line[RX_BUF_SZ];
  size_t len = 0;

  for (;;) {
    /* Poll amigable */
    if (empty_read()) {
      rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));
      continue;
    }

    uint8_t b = dataout_read_byte();

    /* Pulso de consumo visible (1->delay->0) */
    dataread_write(1u);
    for (volatile int i=0; i<200; ++i) __asm__ volatile("nop");
    dataread_write(0u);

    if (b == '\r') continue; /* limpiar CR si llega CRLF */

    if (len < RX_BUF_SZ - 1) {
      line[len++] = (char)b;
    } else {
      line[len] = '\0';
      printf("RX (truncada): %s\n", line);
      len = 0;
    }

    if (b == '\n') {
      line[len] = '\0';
      printf("RX: %s", line);
      len = 0;
    }
  }
}


