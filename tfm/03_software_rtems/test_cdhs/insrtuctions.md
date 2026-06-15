PS-PL AND_GATE EXAMPLE
Vamos a crear el primer ejemplo de unir PS con PL. Para ello, vamos a implementar una puerta
AND en la FPGA, y luego a usarla por software para ver su tabla de verdad, tal y como se ve
aquí:
Para ello, seguiremos los siguientes pasos:
PARTE DE VIVADO
1. Crear el proyecto en Vivado. En mi caso lo he llamado and_gate_ps_pl.
2. Implementar la puerta and en VHDL.
3. Create Block Design.
4. Ponerle un nombre al block design. (yo puse BLOCK_DESIGN_ZYNQ_AND).
5. Añadir ZYNQ UltraScale+ MPSoC IP al diagrama de bloques.
6. Run Block Automation.
7. Desactivar el segundo puerto M_AXI_HPM1_FPD.
8. Click derecho en la puerta and + Add Module to Block Design.
9. Añadir dos AXI GPIO IPs al block design.
1 library IEEE;
2 use IEEE.STD_LOGIC_1164.ALL;
3
4 -- Uncomment the following library declaration if using
5 -- arithmetic functions with Signed or Unsigned values
6 --use IEEE.NUMERIC_STD.ALL;
7
8 -- Uncomment the following library declaration if instantiating
9 -- any Xilinx leaf cells in this code.
10 --library UNISIM;
11 --use UNISIM.VComponents.all;
12
13 entity AND_GATE is
14 Port ( A_B_IN : in STD_LOGIC_VECTOR (1 downto 0);
15 Z_OUT : out STD_LOGIC);
16 end AND_GATE;
17
18 architecture Behavioral of AND_GATE is
19
20 begin
21
22 Z_OUT <= A_B_IN(1) and A_B_IN(0);
23
24 end Behavioral;
10. Configurar uno como entrada de 1 bit y otro como salida de dos bits.
11. Unir los puertos gpio de los AXI GPIO con la puerta AND.
12. Run Automate Conection.
13. Click derecho en el Block Design + Generate Wrapper (opción let vivado manage…). (En mi
caso se llama BLOCK_DESIGN_ZYNQ_AND_wrapper).
14. En la pestaña Address Editor podemos ver las direcciones de los registros para acceder a la
parte PL desde la PS.
15. Generate Bitstream.
16. Emport Hardware + export bitstream. Anotar direcciones de los archivos .xsa y .bit
generados. (En mi caso se generó BLOCK_DESIGN_ZYNQ_AND_wrapper.bit, ubicado en la
carpeta del proyecto:
/and_gate_ps_pl/and_gate_ps_pl.runs/imple_1/BLOCK_DESIGN_ZYNQ_AND_wrapper.bit; y
BLOCK_DESIGN_ZYNQ_AND_wrapper.xsa, ubicado en la carpeta del proyecto
/and_gate_ps_pl/BLOCK_DESIGN_ZYNQ_AND_wrapper.xsa).
PARTE VITIS
En esta parte generaremos el archivo BOOT.bin
1. File + New Component + Platform.
2. Yo le puse de nombre and_gate.
3. En la pestaña Flow, seleccionar el Hardware Design (XSA) generado anteriormente en
Vivado.
4. Después de generar la Platform, ir a Welcome + Examples. Bajar hasta abajo, y seleccionar
Zynq MP FSBL + Create Application Component from Template.
5. Le ponemos un nombre a la aplicación. (yo le puse zynqmp_fsbl_proyect).
6. En la pestaña Harwdare, seleccionar la plataforma que acabamos de crear (and_gate).
7. En la pestaña Domain, nos da un error de Invalid Template. Nos da igual, le damos a Create
new, escribimos un nombre (yo puse fsbl_domain) y seleccionamos el Processor
psu_cortexa53_0.
8. Le damos a Build en la app que acabamos de crear. Se creará
9. Vamos a Vitis + Create Boot Image + Zynq Ultrascale+.
10. Añdimos archivos en este orden:
a. zynqmp_fsbl_proyect.elf en modo Bootloader, Destination CPU a53-0., Exception Level: el3. Este archivo se encuentra en la carpeta build de la aplicación que acabamos de crear.
b. pmufw.elf en modo pmufw_image, Destination CPU a53-0.. Este archivo es descargado de
soc-prebuilt-firmware/zcu102-zynqmp at xilinx_v2025.1 · Xilinx/soc-prebuilt-firmware .
c. BLOCK_DESIGN_ZYNQ_AND_wrapper.bit en modo datafile, Destination device PL.
d. bl31.elf, en modo datafile, Destination CPU a53-0, Exception Level: el-3. Este archivo es
descargado del mismo sitio que pmufw.elf.
e. u-boot.elf en modo datafile, Destination CPU a53-0, Exception Level: el-2. Eset archivo
descargado del mismo sitio que pmufw.elf y bl31.elf.
f. system.dtb e modo datafile, Destination CPU a53-0, Load: 0x100000. Este archivo
descargado del mismo sitio que los anteriores, sirve para que bl31 sepa donde linkar el
bl33 (u-boot) y arranque el U-boot.
PARTE RTEMS
Con nuestro BOOT.bin creado correctamente, ya tenemos casi todo listo. Solo falta la imagen de
rtems para terminar. Para ello, seguimos estos pasos:
1. Creamos el proyecto de la misma manera que creamos el proyecto hello world.
2. Yo añadí los ficheros de ayuda make_img.sh y automate_ymodem_update.py para facilitar el
desarrollo.
3. Programamos and_demo.c de la siguiente manera:
11. Pinchamos en Output BIF File Path * + Browse, seleccionamos una carpeta donde queramos
que se genere la imagen, escribimos el nombre de la configuración que queramos
terminando en .bif. Esto sirve para guardar la configuración por si la queremos cambiar o
repetir luego, y para seleccionar la carpeta donde se creará BOOT.bin
12. Pinchamos en Create Image.
1 /*
2 * AND demo sobre AXI GPIO (RTEMS, ZynqMP)
3 * A/B -> axi_gpio_0 (salida configurada en HW)
4 * Z <- axi_gpio_1 (entrada configurada en HW)
5 */
6
7 #include <rtems.h>
4. Añadir el archivo mmu_pl_map.c:
8 #include <stdio.h>
9 #include <stdint.h>
10
11 /* Direcciones según tu Address Editor */
12 #define GPIO0_BASE 0xA0000000u /* axi_gpio_0: A/B (canal 1) */
13 #define GPIO1_BASE 0xA0010000u /* axi_gpio_1: Z (canal 1) */
14
15 /* Offsets canal 1 */
16 #define GPIO_DATA_OFFSET 0x00u
17
18 void mmu_map_pl_axi_early(void);
19
20 /* MMIO helpers con barrera */
21 static inline void mmio_write32(uintptr_t a, uint32_t v) {
22 *(volatile uint32_t *)a = v;
23 __asm__ volatile("dmb sy" ::: "memory");
24 }
25 static inline uint32_t mmio_read32(uintptr_t a) {
26 __asm__ volatile("dmb sy" ::: "memory");
27 return *(volatile uint32_t *)a;
28 }
29
30 rtems_task Init(rtems_task_argument arg)
31 {
32 /* Pequeño margen por si la PL acaba de cargarse */
33 //rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(50));
34 /* Mapea la región de la PL antes de tocar UART/printf o los GPIO */
35 mmu_map_pl_axi_early();
36
37 printf("Barrido AND via PL\n");
38
39 for (unsigned a = 0; a <= 1; ++a) {
40 for (unsigned b = 0; b <= 1; ++b) {
41 /* DATA[1]=B, DATA[0]=A */
42 uint32_t w = (a & 1u) | ((b & 1u) << 1);
43 mmio_write32(GPIO0_BASE + GPIO_DATA_OFFSET, w);
44
45 /* breve espera para estabilizar */
46 rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));
47
48 /* Leer Z (bit0) desde axi_gpio_1 */
49 uint32_t r = mmio_read32(GPIO1_BASE + GPIO_DATA_OFFSET);
50 unsigned z = r & 1u;
51
52 printf("A=%u, B=%u, Z=%u (raw=0x%08x)\n", a, b, z, r);
53
54 rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(250));
55 while(1);
56 }
57 }
58
59 rtems_shutdown_executive(0);
60 }
1 #include <bsp/aarch64-mmu.h>
2 #include <rtems.h>
3
4 /* Por compatibilidad con algunas ramas */
5 #ifndef AARCH64_MMU_DEVICE_nGnRE
6 #define AARCH64_MMU_DEVICE_nGnRE AARCH64_MMU_DEVICE
7 #endif
8 #ifndef AARCH64_MMU_AP_RW_RW
9 #define AARCH64_MMU_AP_RW_RW 0 /* si tu cabecera no lo define, quítalo de los flags */
10 #endif
5. No hay que olvidarse de edital el wscript para se compilen todos los archivos .c de la
siguiente manera:
6. Creamos la imagen.
7. Cargamos en la tarjeta SD BOOT.bin y rtems.img.
8. Encendemos la ZCU102 con el boot mode en tarjeta SD.
9. Conectamos el usb uart de la ZCU102 al ordenador.
10. Deveríamos ver la salida correctamente en nuestro monitor serial.
11 #ifndef AARCH64_MMU_SH_IS
12 #define AARCH64_MMU_SH_IS 0 /* idem */
13 #endif
14
15 /* Lo llamaremos muy al principio del Init() */
16 static void map_pl_axi_region(void)
17 {
18 aarch64_mmu_config_entry e = {
19 .begin = 0xA0000000u,
20 .end = 0xA0000000u + 0x00200000u, /* 2 MiB para cubrir 0xA0000000..0xA01FFFF */
21 .flags = AARCH64_MMU_DEVICE_nGnRE
22 | AARCH64_MMU_AP_RW_RW
23 | AARCH64_MMU_SH_IS
24 };
25
26 /* Usa la instancia de tablas del BSP para añadir nuestra región */
27 (void)aarch64_mmu_set_translation_table_entries(&aarch64_mmu_instance, &e);
28
29 /* Barreras por si acaso */
30 __asm__ volatile("dsb sy; isb" ::: "memory");
31 }
32
33 /* Exponlo para que lo llames en tu Init() */
34 void mmu_map_pl_axi_early(void) { map_pl_axi_region(); }
1 from __future__ import print_function
2 rtems_version = "7"
3 try:
4 import rtems_waf.rtems as rtems
5 except:
6 import sys
7 print('error: no rtems_waf git submodule')
8 sys.exit(1)
9
10 def init(ctx):
11 rtems.init(ctx, version = rtems_version, long_commands = True)
12
13 def bsp_configure(conf, arch_bsp):
14 pass
15
16 def options(opt):
17 rtems.options(opt)
18
19 def configure(conf):
20 rtems.configure(conf, bsp_configure = bsp_configure)
21
22 def build(bld):
23 rtems.build(bld)
24 bld(features='c cprogram', target='and.exe', cflags='-g -O2', source=bld.path.ant_glob
## Transferring control to RTEMS (at address 00010000)
Barrido AND via PL
A=0, B=0, Z=0 (raw=0x00000000)
A=0, B=1, Z=0 (raw=0x00000000)
A=1, B=0, Z=0 (raw=0x00000000)
A=1, B=1, Z=1 (raw=0x00000001)
[ RTEMS shutdown ]