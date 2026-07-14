/*
 * AND demo sobre AXI GPIO (RTEMS, ZynqMP) — sin usar TRI
 * A/B -> axi_gpio_0 (salida configurada en HW)
 *  Z  <- axi_gpio_1 (entrada configurada en HW)
 */

#include <rtems.h>
#include <stdio.h>
#include <stdint.h>

/* Direcciones según tu Address Editor */
#define GPIO0_BASE   0xA0000000u   /* axi_gpio_0: A/B (canal 1) */
#define GPIO1_BASE   0xA0010000u   /* axi_gpio_1: Z   (canal 1) */

/* Offsets canal 1 */
#define GPIO_DATA_OFFSET  0x00u

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

rtems_task Init(rtems_task_argument arg)
{
  /* Pequeño margen por si la PL acaba de cargarse */
  //rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(50));
  /* Mapea la región de la PL antes de tocar UART/printf o los GPIO */
  mmu_map_pl_axi_early();

  printf("Barrido AND via PL\n");

  for (unsigned a = 0; a <= 1; ++a) {
    for (unsigned b = 0; b <= 1; ++b) {
      /* DATA[1]=B, DATA[0]=A */
      uint32_t w = (a & 1u) | ((b & 1u) << 1);
      mmio_write32(GPIO0_BASE + GPIO_DATA_OFFSET, w);

      /* breve espera para estabilizar */
      rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));

      /* Leer Z (bit0) desde axi_gpio_1 */
      uint32_t r = mmio_read32(GPIO1_BASE + GPIO_DATA_OFFSET);
      unsigned z = r & 1u;

      printf("A=%u, B=%u, Z=%u (raw=0x%08x)\n", a, b, z, r);

      rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(250));
      while(1);
    }
  }

  rtems_shutdown_executive(0);
}
