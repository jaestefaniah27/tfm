Vamos a crear el primer ejemplo de unir PS con PL. Para ello, vamos a implementar una puerta AND en la FPGA, y luego a usarla por software para ver su tabla de verdad, tal y como se ve aquí:

image-20251028-174747.png
Para ello, seguiremos los siguientes pasos:

PARTE DE VIVADO
Crear el proyecto en Vivado. En mi caso lo he llamado and_gate_ps_pl.

Implementar la puerta and en VHDL.



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
entity AND_GATE is
    Port ( A_B_IN : in STD_LOGIC_VECTOR (1 downto 0);
           Z_OUT : out STD_LOGIC);
end AND_GATE;
architecture Behavioral of AND_GATE is
begin
Z_OUT <= A_B_IN(1) and A_B_IN(0);
end Behavioral;
Create Block Design.

Ponerle un nombre al block design. (yo puse BLOCK_DESIGN_ZYNQ_AND).

Añadir ZYNQ UltraScale+ MPSoC IP al diagrama de bloques.

Run Block Automation.

Desactivar el segundo puerto M_AXI_HPM1_FPD.

Click derecho en la puerta and + Add Module to Block Design.

Añadir dos AXI GPIO IPs al block design.

Configurar uno como entrada de 1 bit y otro como salida de dos bits. 

Unir los puertos gpio de los AXI GPIO con la puerta AND.

Run Automate Conection.

image-20251028-183309.png
Click derecho en el Block Design + Generate Wrapper (opción let vivado manage…). (En mi caso se llama BLOCK_DESIGN_ZYNQ_AND_wrapper). 

image-20251028-183603.png
En la pestaña Address Editor podemos ver las direcciones de los registros para acceder a la parte  PL desde la PS. 

image-20251028-183423.png
Generate Bitstream.

Emport Hardware + export bitstream. Anotar direcciones de los archivos .xsa y .bit generados. (En mi caso se generó BLOCK_DESIGN_ZYNQ_AND_wrapper.bit, ubicado en la carpeta del proyecto: /and_gate_ps_pl/and_gate_ps_pl.runs/imple_1/BLOCK_DESIGN_ZYNQ_AND_wrapper.bit; y BLOCK_DESIGN_ZYNQ_AND_wrapper.xsa, ubicado en la carpeta del proyecto /and_gate_ps_pl/BLOCK_DESIGN_ZYNQ_AND_wrapper.xsa).

PARTE VITIS
En esta parte generaremos el archivo BOOT.bin

File + New Component + Platform.

Yo le puse de nombre and_gate.

En la pestaña Flow, seleccionar el Hardware Design (XSA) generado anteriormente en Vivado.

Después de generar la Platform, ir a Welcome + Examples. Bajar hasta abajo, y seleccionar Zynq MP FSBL + Create Application Component from Template.

Le ponemos un nombre a la aplicación. (yo le puse zynqmp_fsbl_proyect).

En la pestaña Harwdare, seleccionar la plataforma que acabamos de crear (and_gate).

En la pestaña Domain, nos da un error de Invalid Template. Nos da igual, le damos a Create new, escribimos un nombre (yo puse fsbl_domain) y seleccionamos el Processor psu_cortexa53_0.

Le damos a Build en la app que acabamos de crear. Se creará

Vamos a Vitis + Create Boot Image + Zynq Ultrascale+.

Añdimos archivos en este orden:

zynqmp_fsbl_proyect.elf en modo Bootloader, Destination CPU a53-0., Exception Level: el-3. Este archivo se encuentra en la carpeta build de la aplicación que acabamos de crear.

pmufw.elf en modo pmufw_image, Destination CPU a53-0.. Este archivo es descargado de soc-prebuilt-firmware/zcu102-zynqmp at xilinx_v2025.1 · Xilinx/soc-prebuilt-firmware .

BLOCK_DESIGN_ZYNQ_AND_wrapper.bit en modo datafile, Destination device PL.

bl31.elf, en modo datafile, Destination CPU a53-0, Exception Level: el-3. Este archivo es descargado del mismo sitio que pmufw.elf.

u-boot.elf en modo datafile, Destination CPU a53-0, Exception Level: el-2. Eset archivo descargado del mismo sitio que pmufw.elf y bl31.elf.

system.dtb e modo datafile, Destination CPU a53-0, Load: 0x100000. Este archivo descargado del mismo sitio que los anteriores, sirve para que bl31 sepa donde linkar el bl33 (u-boot) y arranque el U-boot. 

image-20251028-183654.png
Pinchamos en Output BIF File Path * + Browse, seleccionamos una carpeta donde queramos que se genere la imagen, escribimos el nombre de la configuración que queramos terminando en .bif. Esto sirve para guardar la configuración por si la queremos cambiar o repetir luego, y para seleccionar la carpeta donde se creará BOOT.bin

Pinchamos en Create Image.

 

PARTE RTEMS
Con nuestro BOOT.bin creado correctamente, ya tenemos casi todo listo. Solo falta la imagen de rtems para terminar. Para ello, seguimos estos pasos:

Creamos el proyecto de la misma manera que creamos el proyecto hello world.

Yo añadí los ficheros de ayuda make_img.sh y automate_ymodem_update.py para facilitar el desarrollo.

Programamos and_demo.c de la siguiente manera:



/*
 * AND demo sobre AXI GPIO (RTEMS, ZynqMP)
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
Añadir el archivo mmu_pl_map.c:



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
No hay que olvidarse de edital el wscript para se compilen todos los archivos .c de la siguiente manera:



from __future__ import print_function
rtems_version = "7"
try:
    import rtems_waf.rtems as rtems
except:
    import sys
    print('error: no rtems_waf git submodule')
    sys.exit(1)
def init(ctx):
    rtems.init(ctx, version = rtems_version, long_commands = True)
def bsp_configure(conf, arch_bsp):
    pass
def options(opt):
    rtems.options(opt)
def configure(conf):
    rtems.configure(conf, bsp_configure = bsp_configure)
def build(bld):
    rtems.build(bld)
    bld(features='c cprogram', target='and.exe', cflags='-g -O2', source=bld.path.ant_glob('*.c'))
Creamos la imagen.

Cargamos en la tarjeta SD BOOT.bin y rtems.img.

Encendemos la ZCU102 con el boot mode en tarjeta SD.

Conectamos el usb uart de la ZCU102 al ordenador.

Deveríamos ver la salida correctamente en nuestro monitor serial.

image-20251028-184447.png
 

 