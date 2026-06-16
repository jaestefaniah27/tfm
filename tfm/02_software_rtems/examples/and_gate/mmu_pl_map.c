#include <bsp/aarch64-mmu.h>
#include <rtems.h>

/* Por compatibilidad con algunas ramas */
#ifndef AARCH64_MMU_DEVICE_nGnRE
  #define AARCH64_MMU_DEVICE_nGnRE AARCH64_MMU_DEVICE
#endif
#ifndef AARCH64_MMU_AP_RW_RW
  #define AARCH64_MMU_AP_RW_RW 0 /* si tu cabecera no lo define, quítalo de los flags */
#endif
#ifndef AARCH64_MMU_SH_IS
  #define AARCH64_MMU_SH_IS 0   /* idem */
#endif

/* Lo llamaremos muy al principio del Init() */
static void map_pl_axi_region(void)
{
  aarch64_mmu_config_entry e = {
    .begin = 0xA0000000u,
    .end   = 0xA0000000u + 0x00200000u, /* 2 MiB para cubrir 0xA0000000..0xA01FFFF */
    .flags = AARCH64_MMU_DEVICE_nGnRE
           | AARCH64_MMU_AP_RW_RW
           | AARCH64_MMU_SH_IS
  };

  /* Usa la instancia de tablas del BSP para añadir nuestra región */
  (void)aarch64_mmu_set_translation_table_entries(&aarch64_mmu_instance, &e);

  /* Barreras por si acaso */
  __asm__ volatile("dsb sy; isb" ::: "memory");
}

/* Exponlo para que lo llames en tu Init() */
void mmu_map_pl_axi_early(void) { map_pl_axi_region(); }
