

MÁSTER UNIVERSITARIO EN INGENIERÍA DE TELECOMUNICACIÓN
TRABAJO FIN DE MÁSTER

DESARROLLO DE UNA PLATAFORMA DE COMUNICACIÓN CON PERIFÉRICOS SOBRE MPSoC DE ALTAS PRESTACIONES PARA ORENADORES DE A BORDO EN SISTEMAS ESPACIALES

JORGE ALEJANDRO ESTEFANÍA HIDALGO
2026

# MÁSTER UNIVERSITARIO EN INGENIERÍA DE TELECOMUNICACIÓN

# trabajo fin de MÁSTER
**Título:**** **Desarrollo de una plataforma de comunicación con periféricos sobre MPSoC de altas prestaciones para Ordenadores de a Bordo en sistemas espaciales.
**Autor:****	**D. Jorge Alejandro Estefanía Hidalgo
**Tutor:****	**D. Daniel Sánchez García
**Ponente:**** ****	**D. Alvaro Araujo Pinto
**Departamento:**	Departamento de Ingeniería Electrónica
# Miembros del Tribunal
**Presidente:****	**D. ……………
**Vocal:****	**D. …………..
**Secretario:****	**D. …………..
**Suplente:****	**D. ……………..

	Los miembros del tribunal arriba nombrados acuerdan otorgar la calificación de: ………

Madrid,  a               de                                de 20…

**UNIVERSIDAD POLITÉCNICA DE MADRID**
**ESCUELA TÉCNICA SUPERIOR **
**DE INGENIEROS**** ****DE TELECOMUNICACIÓN**

MÁSTER UNIVERSITARIO EN INGENIERÍA DE TELECOMUNICACIÓN
TRABAJO FIN DE MÁSTER

DESARROLLO DE UNA PLATAFORMA DE COMUNICACIÓN CON PERIFÉRICOS SOBRE MPSoC DE ALTAS PRESTACIONES PARA ORENADORES DE A BORDO EN SISTEMAS ESPACIALES

JORGE ALEJANDRO ESTEFANÍA HIDALGO
2026
# RESUMEN
Número máximo de palabras: 500…

# summary
Maximum number of words: 500…

# PALABRAS CLAVE
Deben reflejar el contenido del trabajo, deberían servir para localizar el TFM mediante búsqueda bibliográfica...
# KEYWORDS
….

# índice del contenido

1.	introducción y objetivos	6
1.1.	Introducción	6
1.2.	Objetivos	6
2.	desarrollo	2
3.	resultados	3
4.	conclusiones y líneas futuras	4
4.1.	Conclusiones	4
4.2.	Líneas futuras	4
5.	bibliografía	5
anexo a: aspectos ÉTICOS, económicos, sociales y ambientales	6
A.1 iNTRODUCCIÓN	6
A.2 DESCRIPCIÓN DE IMPACTOS RELEVANTES RELACIONADOS CON EL PROYECTO	6
A.3 ANÁLISIS DETALLADO DE ALGUNO DE LOS PRINCIPALES IMPACTOS	6
A.4 CONCLUSIONES	6
anexo b: presupuesto económico	7

# introducción y objetivos

## Introducción y motivación

## Objetivos

# Metodología
## scrum asdfs

# Marco teórico

## Proyecto lince
El Proyecto LINCE (Línea de industrialización de cargas de pago y plataformas espaciales) es una iniciativa estratégica enmarcada en el PERTE Aeroespacial, cuyo propósito es consolidar la capacidad industrial de España en el segmento de los microsatélites (100–200 kg) destinados a órbitas bajas (LEO). Liderado por Indra, el consorcio busca desarrollar plataformas satelitales modulares, fiables y de altas prestaciones, optimizando costes y plazos mediante procesos de producción en serie. Este ecosistema integra a grandes empresas, PYMES y centros de investigación, como la Universidad Politécnica de Madrid (UPM), para habilitar servicios avanzados de telecomunicaciones, vigilancia y observación, garantizando así la autonomía estratégica de España y Europa en el sector espacial (Indra, 2026).

Referencias:

Indra. (2026). Proyecto LINCE: Línea de industrialización de cargas de pago y plataformas espaciales. Recuperado el 12 de junio de 2026, de 

## mpsoc zynq ultrascale+ zcu102
La placa de desarrollo sobre la que se va a trabajar en este proyecto es la Tarjeta de Evaluación de propósito general ZCU102, desarrollada por Xilinx, orientada al prototipado rápido de sistemas empotrados de alta complejidad. Esta placa ofrece soporte a todas las interfaces de alta velocidad y lógica programable del MPSoC (Multiprocessor System-on-Chip) Zynq UltraScale+, que integra en un único encapsulado de silicio un sistema de procesamiento con cuatro núcleos y una matriz lógica programable, conectados internamente mediante buses de alto rendimiento. Esta arquitectura divide el sistema en dos dominios complementarios, permitiendo separar la carga de trabajo entre el Sistema de Procesamiento (que en adelante será referido como PS por sus siglas en inglés, Processing System) y la lógica programable (en adelante, PL por Programmable Logic).

El PS representa el dominio del software. Su desarrollo es análogo a la programación de cualquier microcontrolador o microprocesador clásico; está basado en una arquitectura física fija (núcleos ARM en este dispositivo) diseñada para ejecutar instrucciones de código en C o C++ de forma estrictamente secuencial. Este dominio es el encargado de ejecutar sistemas operativos (como RTEMS o Linux), gestionar la memoria y ejecutar las rutinas de control de alto nivel.

Por el contrario, la PL representa el dominio del hardware a medida. Se trata de una matriz tipo FPGA (Field Programmable Gate Array), la cual no ejecuta un programa línea a línea, sino que se reconfigura físicamente. Mediante lenguajes de descripción de hardware (como VHDL), se define la interconexión de miles de recursos internos disponibles en el silicio —tales como tablas de búsqueda (LUTs), biestables, memorias BRAM y bloques de procesamiento digital de señales (DSP)— para conformar circuitos digitales reales y específicos. Esta característica otorga a la PL un determinismo temporal estricto y la capacidad de procesar señales con un paralelismo masivo inalcanzable para un procesador convencional.
Entre sus características destacadas, una que resulta relevante para este trabajo es la capacidad de expansión externa mediante dos conectores FMC HPC (*High Pin Count*). Estos puertos son el punto de anclaje para tarjetas de expansión o *Mezzanines*, permitiendo extraer pines digitales y pares diferenciales hacia el exterior del sistema. Siguen el estándar *VITA 57.1 FPGA **mezzanine** **card** (FMC)** **specification** *(VITA FMC Marketing Alliance website:  ) 

Referencias:
## Vivado y vitis (xilinx): ps y pl
Los programas que más se van a utilizar durante este trabajo son Vivado y Vitis, ambos desarrollados por Xilinx para el desarrollo sobre sus sistemas hardware. 
### Vivado Design Suite
Es el entorno oficial de Xilinx para el diseño, síntesis e implementación de circuitos digitales destinados a la PL. Permite programar en Lenguaje de Descripción Hardware (HDL por sus siglas en inglés, *Hardware **Description** **Language*) los circuitos que se desean implementar. También ofrece una herramienta de diseño por bloques y además permite hacer simulaciones temporales de los circuitos para verificar el comportamiento correcto del hardware desarrollado.
En el contexto específico de este proyecto, Vivado se utiliza para encapsular los transceptores serie diseñados a medida en VHDL y enlazarlos al núcleo del procesador Zynq. Esta integración se realiza mediante el bus de interconexión de alto rendimiento AXI (*Advanced** **eXtensible** **Interface*) a través de la herramienta *Block Design*. Asimismo, Vivado es la herramienta encargada de gestionar el archivo de restricciones físicas (.xdc), necesario para mapear lógicamente las señales de los periféricos desde el silicio hacia los pines reales de los conectores FMC. El flujo de trabajo en Vivado culmina con la generación del *Bitstream* (el archivo binario que configura físicamente la FPGA) y la exportación de la arquitectura del hardware en un archivo unificado (.xsa).
### Vitis Unified Software Platform
Vitis es el entorno de desarrollo integrado (IDE) proporcionado por Xilinx para la programación del dominio del software, es decir, el PS. Funciona en tándem con Vivado: importa el archivo de especificación hardware (.xsa) y genera de forma automatizada el Paquete de Soporte de la Placa o BSP (*Board **Support** **Package*). Este BSP contiene el mapa de memoria estático y los controladores de bajo nivel (*drivers*) indispensables para que el código en C/C++ pueda acceder a los periféricos instanciados previamente en la PL.
Durante el desarrollo de este trabajo, Vitis se emplea para la compilación cruzada orientada a los núcleos ARM del sistema. Se utiliza para generar el firmware crítico de inicialización, concretamente el PMUFW (*Power Management **Unit** Firmware*) y el cargador de arranque de primera etapa FSBL (*First Stage Boot Loader*). Finalmente, Vitis proporciona las herramientas de empaquetado para fusionar el código ejecutable, el *Bitstream* de la PL y los archivos de arranque en un único fichero binario (BOOT.BIN), habilitando el arranque autónomo de la placa desde una memoria no volátil como una tarjeta SD.
## rtems
RTEMS (*Real-Time Executive **for** **Multiprocessor** **Systems*) es un sistema operativo de tiempo real (RTOS) de código abierto diseñado de forma específica para sistemas empotrados de misión crítica. A diferencia de los sistemas operativos de propósito general, como distribuciones estándar de Linux, RTEMS no utiliza memoria virtual y opera en un único espacio de direcciones físico (arquitectura de un solo proceso y múltiples hilos). Esta arquitectura elimina la latencia de los cambios de contexto pesados, minimiza la sobrecarga del procesador y garantiza tiempos de respuesta estrictamente deterministas ante las interrupciones del hardware.
El uso de RTEMS es un estándar de facto en la industria aeroespacial europea y americana (siendo empleado activamente por agencias como la ESA y la NASA en misiones satelitales y sondas espaciales) debido a su robustez, su certificación para entornos críticos y su compatibilidad nativa con arquitecturas ARM como la del Zynq UltraScale+. En el marco del proyecto LINCE y de este TFM, RTEMS se ejecuta sobre el PS actuando como el cerebro temporal del sistema. Su función es orquestar las rutinas de control de alto nivel, gestionar la lectura/escritura de los registros de los transceptores de la PL y asegurar que las transacciones en los buses de comunicación (SpaceWire, RS422, RS485 o CAN) cumplan con los plazos de tiempo (*deadlines*) exigidos durante las pruebas *Hardware-in-the-Loop* de los subsistemas del satélite.

## Comunicaciones serie
En el diseño de sistemas empotrados de misión crítica y arquitecturas satelitales, las comunicaciones serie constituyen la columna vertebral para el intercambio de datos entre el Ordenador de a Bordo (OBC) y sus múltiples periféricos, tales como sensores de actitud, actuadores mecánicos y cargas de pago. Frente a las topologías de bus paralelo tradicionales, los enlaces serie proporcionan una reducción drástica de las líneas físicas necesarias, lo que se traduce de forma directa en una disminución crítica del volumen y peso del arnés del satélite. Además, al operar frecuentemente mediante señalización diferencial, mitigan en gran medida la susceptibilidad a las interferencias electromagnéticas (EMI) propias del entorno espacial.
En este apartado se detallan los fundamentos técnicos, topologías y características eléctricas de los protocolos de comunicación serie específicos que han sido seleccionados e integrados en la plataforma de hardware durante el desarrollo de este trabajo: RS485, RS422, SpaceWire y bus CAN.
### rs485
El estándar TIA/EIA-485, comúnmente conocido como RS485, define las características eléctricas de receptores y transmisores para su uso en sistemas de comunicaciones serie balanceados (diferenciales). Su principal característica es la capacidad de operar en topologías multipunto (buses compartidos), permitiendo conectar hasta 32 transceptores estándar en el mismo par de cables (o más, si se emplean transceptores de carga fraccional).
La señalización diferencial, donde la información se transmite como la diferencia de potencial entre dos hilos trenzados (A y B), le otorga un alto Rechazo al Modo Común (CMRR). Esto significa que cualquier ruido electromagnético inducido en el cable afecta por igual a ambas líneas, cancelándose en el receptor. Habitualmente se implementa en modo *Half-**Duplex* (2 hilos), donde la transmisión y recepción comparten el medio físico, exigiendo un control estricto del flujo de datos mediante software (gestión de los pines de *Driver **Enable*) para evitar colisiones. Es un estándar robusto capaz de alcanzar distancias de hasta 1.200 metros (a velocidades reducidas) o velocidades de hasta 50 Mbps en distancias cortas, requiriendo resistencias de terminación (típicamente de 120 $\Omega$) en los extremos del bus para evitar reflexiones destructivas de la señal.
**Fuentes:**
Texas Instruments. (2014). *The RS-485 Design Guide* (Application Report SLLA272C). Recuperado de 
Electronic Industries Alliance (EIA). (1998). *Electrical Characteristics of Generators and Receivers for Use in Balanced Digital Multipoint Systems* (TIA/EIA-485-A).

### rs422
El estándar TIA/EIA-422 (RS422) es el predecesor técnico del RS485 y comparte con él la base física de la señalización diferencial para garantizar la inmunidad al ruido y cubrir largas distancias. Sin embargo, su principal diferencia radica en la topología de la red: el RS422 está diseñado estrictamente para comunicaciones punto a punto o punto a multipunto (conocido como *multi-drop*).
A diferencia del RS485, los transceptores RS422 no están diseñados para ceder el control del bus. En un bus RS422 solo puede existir un único transmisor (maestro) conectado a un máximo de 10 receptores (esclavos) en el mismo par de hilos. Para lograr una comunicación bidireccional continua (*Full-**Duplex*), el RS422 requiere obligatoriamente el uso de cuatro hilos (dos pares trenzados: uno dedicado exclusivamente a la transmisión y otro a la recepción). Esta separación física de los canales de ida y vuelta elimina la necesidad de arbitrar el bus por software, reduciendo la sobrecarga de procesamiento y garantizando un determinismo temporal absoluto, lo que lo hace idóneo para el envío continuo de telemetría de sensores críticos.
**Fuentes:**
Texas Instruments. (2018). *RS-422 and RS-485 Standards Overview and System Configurations* (Application Report SLLA070D). Recuperado de 
Telecommunications Industry Association. (1994). *Electrical Characteristics of Balanced Voltage Digital Interface Circuits* (TIA/EIA-422-B).

### spacewire
SpaceWire es un estándar de red de comunicaciones espaciales de alta velocidad, coordinado por la Agencia Espacial Europea (ESA) y ampliamente adoptado a nivel mundial en misiones científicas y comerciales. Está diseñado específicamente para interconectar nodos de alto rendimiento a bordo de satélites, como memorias masivas, procesadores de instrumentación y enlaces de telemetría, ofreciendo un gran ancho de banda y una fiabilidad extrema.
A nivel físico, SpaceWire utiliza señalización diferencial de bajo voltaje (LVDS) e implementa una codificación única denominada *Data-**Strobe* (DS). En lugar de transmitir una señal de reloj independiente que sufriría desvíos temporales (*skew*) respecto a los datos a altas frecuencias, la señalización DS envía los datos por un par diferencial y una señal *Strobe* por otro. El reloj se recupera en el receptor realizando una operación lógica XOR entre la señal de datos y el *Strobe*. Esto permite enlaces punto a punto full-duplex asíncronos con velocidades que abarcan desde los 2 Mbps hasta más de 400 Mbps. Además, su arquitectura en capas soporta el enrutamiento de paquetes, permitiendo construir topologías de red complejas mediante *routers* SpaceWire.
**Fuentes:**
European Cooperation for Space Standardization (ECSS). (2008). *Space engineering - SpaceWire - Links, nodes, routers and networks* (ECSS-E-ST-50-12C). ESA-ESTEC.
Parkes, S. M. (2012). *SpaceWire User's Guide*. STAR-Dundee Ltd.

### can
El bus CAN es un estándar de comunicaciones serie robusto diseñado originalmente para el sector de la automoción, pero cuya alta tolerancia a fallos lo ha convertido en un estándar de facto (*CAN **for** **Aerospace*) para las redes internas de monitorización, telemetría y telecomandos (TM/TC) en nanosatélites y satélites comerciales.
Es un bus multipunto y multi-maestro que opera bajo el paradigma CSMA/CD+AMP (*Carrier Sense **Multiple** Access **with** **Collision** **Detection** and **Arbitration** **on** **Message** **Priority*). En una red CAN, los nodos no tienen una dirección física; en su lugar, transmiten tramas de datos encabezadas por un identificador que define el contenido y la prioridad del mensaje. Si dos nodos intentan transmitir simultáneamente, la colisión se resuelve a nivel de bit y de forma no destructiva: el mensaje con el identificador de mayor prioridad sobrescribe al de menor prioridad sin corromper el bus, garantizando un determinismo estricto para las alarmas críticas. Además, la capa de enlace del protocolo CAN incorpora mecanismos de detección de errores por hardware (CRC, bit stuffing, comprobación de tramas) y confinamiento automático de nodos defectuosos, asegurando que un periférico averiado no bloquee el sistema de control de actitud u otros subsistemas vitales del Ordenador de a Bordo.
**Fuentes:**
International Organization for Standardization (ISO). (2015). *Road vehicles — Controller area network (**CAN) —** Part 1: Data link layer and physical **signalling* (ISO 11898-1:2015).
Agencia Espacial Europea (ESA). (2015). *CAN in Space: Implementation guide and application notes*. TEC-ED & TEC-SW.

# desarrollo firmware
## preparación entorno de desarrollo
Para llevar a cabo la implementación propuesta en este Trabajo de Fin de Máster, fue necesario establecer un entorno de desarrollo robusto que permitiera el codiseño hardware-software (PS-PL) sobre la plataforma Zynq UltraScale+ MPSoC. A continuación, se detalla la metodología seguida para la configuración de las herramientas de síntesis, la compilación del sistema operativo en tiempo real (RTEMS) y la validación del flujo de trabajo completo. El entorno de desarrollo principal se desplegó sobre una máquina virtual con una distribución Linux (Ubuntu/Debian). En este sistema se instalaron las dependencias necesarias para la compilación cruzada, incluyendo paquetes esenciales de desarrollo de C/C++, Python 3 y herramientas de control de versiones.  
### instalación vivado y vitis
Para el desarrollo de la lógica programable (PL) y la generación de imágenes de arranque, se utilizaron las herramientas oficiales de AMD Xilinx: Vivado Design Suite y Vitis Unified Software Platform. Vivado se empleó para el diseño a nivel de hardware y la generación del bitstream, mientras que Vitis se utilizó para empaquetar los binarios y generar la imagen de arranque (BOOT.bin).	
### instalación rtems
En lugar de utilizar binarios precompilados, se optó por compilar el sistema operativo RTEMS (versión 7) desde cero, garantizando el control total sobre la configuración del núcleo. 
La compilación se realizó utilizando la herramienta RTEMS Source Builder (RSB). 
Se generó un *toolchain* cruzado específico para la arquitectura AArch64. 
Se configuró y compiló el Board Support Package (BSP) correspondiente a la plataforma ZynqMP (zynqmp_apu), habilitando explícitamente el soporte para multiprocesamiento simétrico (SMP). 
Para validar el entorno recién compilado, se ejecutaron pruebas preliminares utilizando el emulador QEMU (qemu-system-aarch64) configurado con la máquina xlnx-zcu102. 
Se verificó la correcta ejecución de ejemplos básicos como hello.exe y pruebas de rendimiento computacional como el benchmark Dhrystone. 
### flujo de desarrollo completo
Una vez preparadas todas las herramientas de desarrollo, se probó a realizar un desarrollo completo de principio a fin implementando un ejemplo sencillo: una puerta AND. Para ello, se siguieron los siguientes pasos:
Parte VIVADO:
Se creó un proyecto nuevo en Vivado llamado and_gate_ps_p, y se diseñó la puerta AND en VHDL:
*AND_GATE.vhd*
**library** **IEEE**;
**use** **IEEE.STD_LOGIC_1164.****ALL**;

**entity** **AND_GATE** **is**
    **Port** ( A_B_IN : **in** **STD_LOGIC_VECTOR** (**1** **downto** **0**);
           Z_OUT : **out** **STD_LOGIC**);
**end** **AND_GATE**;
**architecture** **Behavioral** **of** **AND_GATE** **is**
**begin**
Z_OUT <= A_B_IN(**1**) **and** A_B_IN(**0**);
**end** **Behavioral**;

Después se creó un Block Design, se añadió el bloque Zynque UltraScale+ MPSoC IP, y se configuró automáticamente usando Block Automation de Vivado. Se añadió el fichero VHDL del paso anterior al Block Design.
Se añadieron dos AXI GPIO IPs al block design para comunicar la PS con la PL, y se conectaron los bloques entre sí, y se utilizó Automate Conection de Vivado para todas las conexiones faltantes. El Block Design final fue el siguiente:

Después se crea un Wrapper del Block Design para que Vivado pueda sintetizarlo correctamente. En la pestaña Address Editor se pueden ver las direcciones de los registros para acceder a la parte PL desde la PS.

Por último, se generó el BitStream y se exportó el hardware como .xsa.

Generación de la Imagen de Arranque (Vitis): para empaquetar el hardware que acabamos de generar en Vivado en un binario que el MPSoC entienda y sepa utilizar. Se siguieron los siguientes pasos:
Se creó un nuevo componente en Vitis, de tipo Platform, utilizando como base el .xsa generado. 
Se utilizó un ejemplo del propio Vitis llamado Zynq MP FSBL para crear un bootloader de arranque (fsbl), utilizando la plataforma que acabamos de crear.
Se compiló la aplicación.
Por último, se generó el archivo BOOT.bin mediante el generador de imágenes de Vitis, siguiendo una estructura de archivos específica:
zynqmp_fsbl_proyect.elf en modo Bootloader, Destination CPU a53-0., Exception Level: el-3. Este archivo se encuentra en la carpeta build de la aplicación que acabamos de crear.
pmufw.elf en modo pmufw_image, Destination CPU a53-0.. Este archivo es descargado de soc-prebuilt-firmware/zcu102-zynqmp at xilinx_v2025.1 · Xilinx/soc-prebuilt-firmware .
BLOCK_DESIGN_ZYNQ_AND_wrapper.bit en modo datafile, Destination device PL.
bl31.elf, en modo datafile, Destination CPU a53-0, Exception Level: el-3. Este archivo es descargado del mismo sitio que pmufw.elf.
u-boot.elf en modo datafile, Destination CPU a53-0, Exception Level: el-2. Eset archivo descargado del mismo sitio que pmufw.elf y bl31.elf.
system.dtb e modo datafile, Destination CPU a53-0, Load: 0x100000. Este archivo descargado del mismo sitio que los anteriores, sirve para que bl31 sepa donde linkar el bl33 (u-boot) y arranque el U-boot. 
Se generó la imagen BOOT.bin exitosamente.
Parte RTEMS: una vez generado el archivo de arranque que sirve para cargar en el MPSoC toda la lógica hardware y las conexiones entre la PS y la PL, podemos desarrollar el software que va a correr en uno de los núcleos de la PS. En este caso, fue un ejemplo sencillo que interactuaba con los puertos GPIO conectados por AXI, excitando todas las combinaciones posibles de la puerta AND en la PL y leyendo su salida. También hizo falta añadir un archivo que le diga al sistema operativo que direcciones corresponden con la PL, para que pasen a formar parte del mapa de memoria (O ALGO ASÍ) y no se rompa el sistema al intentar leer de direcciones inexistentes. Por último, añadir el fichero wscript para compilar todos los archivos .c (explicar wscript aquí).
Para facilitar el desarrollo rápido en la parte de RTEMS, se desarrolló un script rápido que compila la imagen de rtems, generando una imagen de rtems: rtems.img.
Para evitar quitar y poner la tarjeta SD constantemente, se desarrolló un script en Python que es capaz de subir la imagen de rtems a la tarjeta SD mediante una conexión USB.
Una vez generados el BOOT.bin y rtems.img, se copian ambos en una tarjeta SD, se introduce la tarjeta SD en la ZCU102, se colocan los switches del selector de arranque en la posición 1000 para que el sistema lea de la tarjeta al arrancar, y se conecta por usb la zcu al ordenador para leer la salida del terminal por monitor serial. La salida obtenida realizar todos estos pasos es la siguiente:

Una vez verificado que esta metodología de desarrollo funciona correctamente, se estableció como el proceso estándar a seguir para los próximos desarrollos.

## Diseño transceptor serie configurable (pl)
El transceptor serie se diseñó para ser altamente configurable y adaptable a cualquier dispositivo. De esta manera, se buscó poder configurar los siguientes parámetros de la transmisión/recepción: 
Baudrate(desde 50 hasta 4000000 baudios).
Número de stop bits (1, 1.5 o 2).
Paridad (par, impar, marca, espacio o deshabilitada).
Orden de los bits (LSB o MSB).
Número de bits (entre 5 y 9).
### transmisor

El siguiente diagrama FSM resume el comportamiento del transmisor. Debido a su tamaño, se ha troceado en tres partes para su legibilidad.

### receptor
El siguiente diagrama FSM resume el comportamiento del receptor.

### oscilador controlado numéricamente
Este oscilador sirve para generar una señal de enable a un baudrate seleccionado. Hay 54 valores de velocidad seleccionables almacenados en una tabla de verdad. Para poder generar frecuencias que no son divisibles de la frecuencia de reloj de la FPGA, se utiliza este circuito que es capaz de corregir cada ciertos pulsos el desfase generado por esta imprecisión, logrando replicar un amplio número de frecuencias con muy poco error. El circuito consiste en un sumador, que para cada frecuencia seleccionada tiene calculado un incremento concreto, el cual depende del número de bits del sumador. Cuantos más bits tenga este sumador, mejor precisión se consigue con el NCO. En esta implementación, se han utilizado 32 bits. Este incremento se suma y se va acumulando en cada período de reloj. Cuando eventualmente el sumador se desborda, se utiliza el bit de carry_out del sumador como tick del NCO. Este tick se genera a una frecuencia igual o menor a la frecuencia deseada, que con el tiempo va acumulando error. Para corregirlo, el incremento es calculado de manera que cada cierto número de ticks, se genera un tick con una suma menos que los demás, debido al resto que se ha ido acumulando tras cada suma. Este tick generado con un ciclo de reloj menos es el que corrige el error acumulado. Para verificar que este oscilador funcionaba correctamente en las frecuencias de trabajo, se realizó una simulación que comprobaba varias frecuencias y calculaba el error obtenido en cada frecuencia concreta. Los resultados se recogen en una tabla (CITAR TABLA DEL ANEXO). 
En el siguiente diagrama se describe el circuito implementado, que sigue la metodología de diseño “next state logic” aprendida en clase (MEJORAR Y CITAR LIBRO DE CLASE).

### shift-register

El registro de desplazamiento está diseñado para poder almacenar datos tanto si la configuración de datos es LSB o MSB, para que una vez recibido el mensaje la palabra en la salida siempre es la correcta.
### fifo

La FIFO es un bloque IP con 9 bits de datos (para poder almacenar mensajes de 9bits) y 512 de profundidad, que permite almacenar temporalmente varios mensajes, y permite su lectura posterior.
### bloque zynq ultrascale+ mpsoc

Para que el proyecto en Vivado funcione, es importante aplicar el preset al bloque IP Zynq UltraScale+ antes de añadir todo lo demás, ya que se aplican configuraciones de relojes y alimentación cruciales para el correcto funcionamiento de la PL.

## herramientas para facilitar desarrollo del transceptor serie configurable (PL)
### generar transceivers con tcl
Se desarrolló un script de TCL (EXPLICAR TCL) que permitía generar y conectar automáticamente un número deseado de Transceptores en el Block Design de Vivado. Para que funcione correctamente, hay que tener las fuentes .vhd del transceptor en el proyecto, creado el Block Design, importado el bloque IP Zynq UltraScale+ MPSoC y configurado previamente este bloque, el script se encarga de añadir y conectar el resto de los bloques necesarios. (CITAR SCRIPT EN EL ANEXO)
### generar proyecto con tcl
También se desarrolló otro script de TCL que regenera el proyecto entero con un número determinado de transceptores. (CITAR SCRIPT EN EL ANEXO)
## generación binario en vitis (ps)
Una vez diseñada la lógica hardware en Vivado y exportado el hardware, se siguieron los pasos establecidos previamente para generar el binario BOOT.bin.
## diseño driver serie en rtems (ps)
Desarrollo de la librería C para el driver serie sobre RTEMS
Motivación y contexto
El subsistema de comunicaciones del OBC requiere gestionar simultáneamente múltiples interfaces serie físicas (RS422 y RS485) desde una aplicación de tiempo real ejecutada sobre RTEMS. El bloque hardware CONFIGURABLE_SERIAL_TOP, implementado en VHDL en la lógica programable (PL) de la FPGA, expone cada transceptor a través de un periférico AXI GPIO de doble canal, cuya interfaz de bajo nivel es demasiado específica para ser usada directamente desde la aplicación. Para abstraer esta complejidad y ofrecer una API uniforme e independiente de la dirección física de cada instancia, se desarrollaron los ficheros transceiver.c y transceiver.h.

El diseño cubre tres requisitos fundamentales: (1) descubrimiento dinámico del hardware en tiempo de arranque, de modo que el mismo binario funcione con cualquier número de transceptores instanciados en el bitstream; (2) comunicación orientada a interrupciones para no bloquear el procesador durante la espera de datos; y (3) una API sencilla que permita a la aplicación enviar y recibir datos sin conocer los detalles del mapa de registros.

Interfaz hardware: mapa de registros
Cada instancia del transceptor ocupa una región de 4 KB del espacio de memoria del procesador, estructurada como un AXI GPIO de doble canal:

Canal 1 (escritura, PS → PL): contiene el dato de transmisión (bits 8:0), los bits de control de protocolo (SEND, ERROR_OK, DATA_READ) y los campos de configuración: tasa de baudios (6 bits), bits de parada (2 bits), paridad (3 bits), bits de datos (3 bits), orden de bits y modo SLO.
Canal 2 (lectura, PL → PS): contiene el byte recibido (bits 8:0) y las banderas de estado: RX_EMPTY, RX_FULL, PARITY_ERROR, FRAME_ERROR y TX_RDY.
Adicionalmente, un bloque de información del sistema situado en la dirección fija 0xA0020000 expone en tiempo de ejecución el número de transceptores instanciados, el stride de memoria entre instancias y la dirección base de la primera de ellas. Más allá del último transceptor se aloja el controlador de interrupciones AXI INTC, compartido por todas las instancias.

El diagrama de la Figura 1 muestra el bloque VHDL integrado en el sistema y su conexión al bus AXI.

Arquitectura software
La librería se organiza en torno a dos estructuras de datos centrales:

Transceiver_Config_t agrupa los parámetros de configuración del protocolo: tasa de baudios, número de bits de datos (5 a 9), paridad (par, impar, mark, space o ninguna), bits de parada (1, 1.5 o 2), orden de bits (LSB o MSB first) y modo de emisión lenta (SLO, que reduce las emisiones electromagnéticas). Todos los valores se expresan mediante macros simbólicas definidas en transceiver.h, que corresponden directamente a los valores codificados en la LUT del NCO hardware.

Transceiver es el objeto handle que representa una instancia concreta del transceptor en ejecución. Contiene el mapa de direcciones calculado dinámicamente (base_addr, intc_base y los offsets derivados), las máscaras de interrupción individuales de RX y TX, y el estado software: un buffer circular de recepción y uno de transmisión (ambos de 4096 bytes por defecto, asignados dinámicamente), los identificadores de las primitivas RTEMS asociadas (tarea worker, mutex de RX y mutex de TX) y el callback de usuario para notificación de datos recibidos.

Descubrimiento dinámico del hardware
La función Transceiver_Hardware_Discover() lee el bloque de información del sistema al arranque y extrae el número de instancias presentes, el stride de memoria y la dirección base. Con estos tres valores se calcula automáticamente la dirección del INTC compartido:

g_intc_addr = g_hw_base + (g_hw_count × g_hw_stride)
Este mecanismo permite que el mismo binario RTEMS funcione sin modificación con cualquier número de transceptores (hasta el máximo soportado de 14), cubriendo configuraciones que van desde un único canal hasta la instalación completa. La alternativa de hardcodear las direcciones habría requerido recompilar la aplicación para cada variante del bitstream.

Modelo de interrupciones: ISR maestra y tareas worker
El diseño de la gestión de interrupciones adopta el patrón deferred interrupt processing recomendado para RTEMS. Se instala una única ISR en el vector 121 (Master_ISR) que atiende a todos los transceptores a través del AXI INTC compartido:

La ISR lee el registro de interrupciones pendientes (INTC_ISR).
Para cada transceptor con interrupción RX activa: reconoce la interrupción (INTC_IAR), deshabilita temporalmente la línea (INTC_CIE) y envía el evento RTEMS_EVENT_0 a la tarea worker correspondiente.
Para cada transceptor con interrupción TX activa: extrae el siguiente byte del buffer circular de transmisión, lo escribe en el registro de control pulsando BIT_TX_SEND, y limpia la interrupción. Si el buffer ha quedado vacío, marca tx_busy = false.
Cada instancia Transceiver tiene asociada una tarea RTEMS dedicada (Rx_Worker_Task) que se bloquea esperando el evento. Al recibirlo, vacía el FIFO hardware byte a byte hacia el buffer circular de recepción, pulsando BIT_DATA_READ para confirmar la lectura de cada byte al hardware. El acceso al buffer se protege con un semáforo binario de prioridad para evitar condiciones de carrera con la tarea de aplicación. Tras drenar el FIFO, la worker re-habilita la interrupción (INTC_SIE) e invoca el callback de usuario si está registrado.

La separación entre la ISR (que solo despierta la tarea) y la worker (que realiza el trabajo real) garantiza que el tiempo de latencia en contexto de interrupción sea mínimo y que el procesamiento se ejecute con las prioridades del planificador RTEMS.

Inicialización y configuración del hardware
Transceiver_Init() realiza la puesta en marcha completa de una instancia:

Calcula la dirección base y la dirección del INTC a partir de los parámetros descubiertos.
Asigna las máscaras de interrupción individuales: el bit 2·id para RX y el bit 2·id+1 para TX dentro del registro de 32 bits del INTC.
Asigna dinámicamente los buffers circulares de RX y TX.
Crea el semáforo de RX, el semáforo de TX y la tarea worker con rtems_semaphore_create y rtems_task_create.
Si se proporciona una estructura de configuración, construye el valor del registro de control canal 1 ensamblando los campos mediante desplazamientos y máscaras, y lo escribe en el hardware.
Lanza la tarea worker y habilita la interrupción de TX en el INTC.
La función Transceiver_Global_INIT() orquesta la inicialización completa del sistema: primero llama a Transceiver_Hardware_Discover() para poblar las variables globales, y a continuación a Transceiver_Global_INTC_Init(), que habilita el modo maestro del INTC (registro MER) e instala la Master_ISR.

API pública
La interfaz expuesta al código de aplicación se reduce a cinco funciones:

Función	Descripción
Transceiver_Global_INIT()	Descubrimiento hardware e inicialización del INTC. Devuelve el número de transceptores detectados.
Transceiver_Init(dev, id, cfg)	Inicializa la instancia dev con el identificador id y la configuración cfg.
Transceiver_SetRxCallback(dev, cb, arg)	Registra una función de callback invocada cada vez que se reciben datos.
Transceiver_Read(dev, buf, maxlen)	Extrae hasta maxlen bytes del buffer circular de recepción.
Transceiver_SendString(dev, s)	Encola la cadena s en el buffer de transmisión e inicia la transmisión si el hardware está libre.

La Figura 3 del entregable LINCE muestra el flujo de uso recomendado: tras crear el objeto de configuración e invocar Transceiver_Global_INIT() y Transceiver_Init(), la aplicación registra un callback que, al ser invocado, llama a Transceiver_Read() en bucle hasta que devuelve 0, indicando que el buffer está vacío. El envío se realiza en cualquier momento con Transceiver_SendString().

Decisiones de diseño destacadas
Buffer circular frente a copia directa en ISR. Dado que RTEMS no permite operaciones de copia de longitud arbitraria en contexto de interrupción sin afectar la latencia del sistema, se optó por buffers circulares gestionados desde la tarea worker. El tamaño de 4096 bytes proporciona margen suficiente para ráfagas de datos a las tasas más altas soportadas (hasta 4 Mbaudios).

Transmisión dirigida por interrupción. El primer byte de cada cadena a transmitir se escribe directamente desde Transceiver_SendString() para arrancar el hardware; los bytes siguientes son enviados sucesivamente por la Master_ISR al recibir la interrupción TX_RDY, sin necesidad de que la tarea de aplicación permanezca bloqueada durante la transmisión.

Compatibilidad multi-instancia mediante tabla global. El array g_instances[] permite a la Master_ISR localizar en O(1) el objeto Transceiver asociado a cada par de bits de interrupción, evitando búsquedas costosas en contexto de ISR.

Modo SLO. El bit BIT_SLO del registro de control activa en el hardware VHDL una rampa de subida más lenta en las señales de salida, reduciendo el contenido espectral de alta frecuencia y mejorando la compatibilidad electromagnética en entornos con restricciones EMI.

Perfecto, ahí tienes el apartado completo. Está estructurado para encajar en el cuerpo de un TFM: comienza con la motivación, explica la interfaz hardware, desarrolla la arquitectura software con sus decisiones de diseño, y cierra con la API pública. Puedes ajustar el nivel de detalle de cualquier sección o añadir fragmentos de código si el estilo del resto del documento lo incluye.

# desarrollo hardware
Después de desarrollar el firmware del transceptor serie configurable, se procedió a desarrollar hardware sobre el que probarlo de manera más exhaustiva. En una primera instancia, se había establecido como plan hacer una única placa de circuito impreso con un diseño propio. Después de diseñar esta placa, surgió en el proyecto Lince la necesidad de desarrollar dos placas más con especificaciones impuestas por Indra, que servirían para ofrecer el soporte hardware necesario para que ellos probaran su firmware sobre la ZCU102.
## diseño placa diseño propia
El objetivo de esta placa era poder probar varias líneas serie simultáneas, pudiendo conectarlas entre sí en buses compartidos de manera sencilla, además de poder probar la comunicación con periféricos reales.
METER FOTO PLACA PROPIA

## diseño placa cdhs
El objetivo de esta placa era ser una placa de interconexión para probar y enrutar las señales entre el subsistema principal ZCU102 (conectado mediante un puerto FMC) y periféricos externos.
Las especificaciones de la PCB han sido impuestas por parte de Indra, tanto el tipo y número de conectores como los tipos de comunicación y de señales que pasan por cada uno. Según estas especificaciones, el enrutamiento hacia el exterior se realiza a través de 6 conectores D-Sub-9 (DS9) etiquetados de J1 a J6, y la placa centraliza la comunicación CAN, buses seriales RS422/RS485, adaptación de niveles para PWM y adquisición de señales analógicas de termistores.
METER AQUÍ TABLA CDHS SI ME DEJAN
Dado que la interfaz de conexión de la PCB con la ZCU102 se realiza a través del conector FMC J5 y que los bancos de pines a los que se conectan las señales que salen por este conector trabajan a 1.8V, se han buscado componentes que ofrezcan compatibilidad nativa con este nivel de tensión a fin de simplificar el diseño.
En las siguientes imágenes se ve el renderizado en tres dimensiones de la PCB por delante y por detrás.

### Subsistemas de Hardware
Interfaz CAN
Implementa un bus CAN con topología redundante, dividida en CAN Nominal (CAN_NOM) y CAN Redundante (CAN_RED) y utiliza dos transceptores TCAN1044AVDRQ1. La tensión de alimentación principal (VCC) de los transceptores es de 5V, mientras que la interfaz lógica (VIO) opera a 1V8 para ser compatible con las señales del MPSoC. Las líneas diferenciales cuentan con diodos de protección ESD ESDCAN24-2BLY. Ambas líneas (Nominal y Redundante) convergen en el conector DS9 J1.
Interfaces Seriales RS422/RS485
Dispone de tres bloques idénticos e independientes para comunicación serial (RS1, RS2 y RS3). Cada canal emplea el transceptor THVD1424RGTR, alimentado a 5V (VCC) y 1V8 (VIO). La configuración del transceptor es seleccionable por hardware mediante jumpers físicos (headers de 2 pines):
H/F: Conmuta entre funcionamiento Half-Duplex y Full-Duplex.
SLR: Controla el Slew Rate del integrado.
TERM_TX / TERM_RX: Habilitan las resistencias de terminación integradas para las líneas de transmisión y recepción.
Las líneas diferenciales (TX_P/N y RX_P/N) incluyen diodos de protección TVS SM712-02HTG. Estos buses se exponen al exterior en los conectores DS9 J2, J3 y J4 respectivamente.
Control de Calentadores - Level Shifter
Dedicado a la adaptación de niveles lógicos para 4 señales PWM (Heater 1 a 4). Las señales digitales de 1V8 provenientes del conector FMC se elevan a 3V3 utilizando el integrado adaptador de niveles TXU0104PWR. Las 4 líneas PWM adaptadas tienen salida en el conector DS9 J5.
Adquisición de Datos – ADC
Subsistema destinado a la lectura analógica de 4 termistores (CH0 a CH3). Se implementa mediante el conversor analógico-digital de aproximaciones sucesivas ADS7950QDBTRQ1. La comunicación de datos y configuración del ADC hacia el controlador principal se realiza a través de un bus SPI alimentado a 1V8 (+VBD), mientras que la circuitería analógica (+VA) opera a 3V3. Las entradas de los termistores se conectan mediante el puerto DS9 J6.
### Alimentación y conectividad
**Conexión Principal**: Utiliza un conector FMC (ASP-134604-01) de alta velocidad que transporta las señales de los buses (SPI, CAN_Dig, SERIAL), señales lógicas de control y líneas de alimentación (12P0V, 3P3V, VADJ a 1V8).
**Conversión DC/DC**: Incluye un convertidor conmutado R-785.0-1.0 (etiquetado como PS1) que recibe los +12V del bus FMC y genera el carril de +5V necesario para la etapa de potencia de los transceptores RS422/RS485 y CAN.
**Conectores Externos**: Los puertos DS9 (J1 a J6) son todos del tipo D-Sub-9 pines (D09S13A4GL00LF y D09P13A4GL00LF), con terminales de escudo térmico (SH1, SH2) derivados al plano de tierra (GND) para mantener el apantallamiento EMI de los cables. Del J1 al J5 son conectores hembra, el conector J6 es macho.
### Mapa de señales
A continuación, se muestra una tabla completa con el mapeo de las señales digitales hacia el conector FMC:

## diseño placa aocs
### Visión general y arquitectura
La PCB LINCE3_AOCS BreakoutBox testing PCB (diseñada por Jorge A. Estefanía) es una placa de interconexión para probar y enrutar las señales entre el subsistema principal ZCU102 (conectado mediante un puerto FMC) y periféricos externos orientados al control de actitud y órbita (AOCS).
Las especificaciones de la PCB determinan que el enrutamiento hacia el exterior se realiza a través de 8 conectores D-Sub-9 (DS9), centralizando la comunicación a través de buses seriales RS422/RS485, enlaces de alta velocidad SpaceWire y la adaptación de niveles para el control de potencia de motores (MOT-PWM).
Dado que la interfaz de conexión de la PCB con la ZCU102 se realiza a través del conector FMC y que los bancos de pines a los que se conectan las señales trabajan a 1.8V, se han implementado componentes que ofrecen compatibilidad nativa con este nivel de tensión a fin de simplificar el diseño y garantizar la integridad de las señales.

*Vista superior.*

*Vista inferior.*
### subsistemas de hardware
Puertos de Comunicaciones Serie (RS422/RS485)
La placa centraliza 5 canales serie independientes (RS1, RS3, RS4, RS5 y RS8), son exactamente los mismos que los utilizados para la placa CDHS.
Comunicación de Alta Velocidad - SpaceWire
Para el manejo de grandes volúmenes de datos de telemetría y control, se implementan dos enlaces SpaceWire independientes (SPW1 y SPW2) utilizando señalización diferencial LVDS a través de los conectores DS9_1 y DS9_2. Los pares diferenciales se han trazado con técnicas de igualación de longitud (skew matching) y una impedancia característica controlada de 100 Ohmios.
 Control de Potencia y Actuadores (MOT-PWM)
Este bloque realiza la adaptación de niveles lógicos (level shifting) para las señales PWM provenientes del MPSoC, elevándose a los niveles requeridos por las etapas de potencia externas de los motores.
### Alimentación y conectividad
La gestión de potencia toma como entrada el carril de 12V proporcionado por el bus del conector FMC. Asimismo, alimentación para el control de motores por PWM se realiza a través de dos conectores banana, para poder enchufar una fuente de alimentación externa y alimentar los puentes en H directamente de forma externa.
### Mapa de señales
A continuación, se muestra una tabla completa con el mapeo de las señales digitales hacia el conector FMC:

## fabricación
Una vez diseñadas las placas, se pidieron las placas con stencil para la cara donde están los componentes montados superficialmente a PCBWay y los componentes a distintos proveedores como Mouser o DigiKey. Cuando llegaron, se siguió el siguiente procedimiento:
Aplicación de la pasta de soldadura. Se fijó la placa a la mesa rodeándola con placas del mismo grosor y asegurando el montaje a la mesa con cinta de pintor. Después, se colocó el stencil encima de la placa, y se aplicó la pasta de soldadura con una espátula.
Colocación de componentes: se fueron colocando los componentes con pinzas en las placas. En este paso, se colocaron componentes sobre dos placas con pasta de soldadura a la vez, para ahorrar tiempo logístico al fabricar.
Horneado de reflujo: se colocaron las placas en el Reflow Oven (MEJORAR ESTO) y se seleccionó la curva de temperatura adecuada, en nuestro horno la curva 3.

# desarrollo herramientas orientadas a testing

## diseño app testing de drivers serie en rtems (ps)
Diseño de la Aplicación de Testing del Driver Serie en RTEMS
Visión general
La aplicación está estructurada en tres archivos:

Archivo	Rol
init.c	Configuración del sistema RTEMS (macros de confdefs.h)
transceiver.c + transceiver.h	Driver del transceptor serie sobre AXI GPIO
main.c	Aplicación de testing que usa la API del driver
1. Configuración del sistema RTEMS — init.c
init.c es el fichero de configuración estática de RTEMS. No contiene lógica de aplicación; define el entorno de ejecución mediante macros que <rtems/confdefs.h> convierte en estructuras de datos internas del kernel:

CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER   // Necesario para rtems_task_wake_after()
CONFIGURE_APPLICATION_NEEDS_CONSOLE_DRIVER // Habilita stdin/stdout (printf, fgets)
CONFIGURE_MICROSECONDS_PER_TICK 10000      // Tick del sistema = 10 ms (100 Hz)
CONFIGURE_UNLIMITED_OBJECTS                // Sin límite de tareas/semáforos
CONFIGURE_UNIFIED_WORK_AREAS              // Un único pool de memoria
CONFIGURE_INIT_TASK_STACK_SIZE (64 KB)   // Stack grande para la tarea Init
El punto de entrada del sistema RTEMS es la función Init() declarada en main.c, que RTEMS invoca automáticamente al arrancar.

2. El Driver — transceiver.c / transceiver.h
El driver abstrae hasta 14 UARTs implementadas en la FPGA (PL del ZCU102) sobre AXI GPIO de doble canal. Cada transceptor ocupa un bloque de memoria de 4 KB (stride) a partir de una dirección base descubierta en tiempo de ejecución.

Descubrimiento de hardware (transceiver.c:70-89):

En Transceiver_Global_INIT() → Transceiver_Hardware_Discover(), el driver lee dos registros de un bloque de información del sistema en 0xA0020000:

Canal 1: count (16 bits bajos) y stride (16 bits altos)
Canal 2: dirección base de todos los transceivers
Esto hace que el número de UARTs y sus direcciones sean configurables desde la FPGA sin recompilar.

Arquitectura de interrupciones — ISR Maestra + Worker Tasks (transceiver.c:110-186):

El diseño usa un patrón ISR/worker de dos niveles:

FPGA genera IRQ → Master_ISR() (contexto de interrupción)
                       │
                       ├─ Identifica qué UART disparó (bitmask del INTC)
                       ├─ Desactiva esa línea de interrupción (INTC_CIE)
                       ├─ Reconoce la interrupción (INTC_IAR)
                       └─ Envía RTEMS_EVENT_0 al Rx_Worker_Task de esa UART
                                   │
                            Rx_Worker_Task() (tarea normal, con contexto completo)
                                   │
                                   ├─ Drena el FIFO de hardware byte a byte
                                   ├─ Almacena en buffer circular (protegido por mutex)
                                   ├─ Pulsa BIT_DATA_READ para avanzar el FIFO del HW
                                   ├─ Invoca el callback de usuario: on_rx_data()
                                   └─ Re-habilita la línea de interrupción (INTC_SIE)
La ISR es mínima (no bloquea, no llama a printf); toda la lógica pesada la hace la worker task. Cada una de las hasta 14 UARTs tiene su propia worker task con prioridad 50.

Transmisión — buffer circular + kick en ISR TX (transceiver.c:279-318):

Transceiver_SendString() escribe los bytes en un buffer circular TX y hace un "kick" del primer byte directamente al registro AXI. Los bytes siguientes los envía la propia Master_ISR() cada vez que el hardware señala TX-listo (mask_tx), evitando espera activa.

API pública (definida en transceiver.h:196-218):

uint32_t Transceiver_Global_INIT(void);                        // Descubre HW + instala ISR maestra
rtems_status_code Transceiver_Init(dev, id, cfg);              // Inicia una UART: HW, mutex, task
size_t Transceiver_Read(dev, buf, maxlen);                     // Lee del buffer circular RX
int Transceiver_SendString(dev, s);                            // Envía string por TX
void Transceiver_SetRxCallback(dev, cb, arg);                  // Registra callback de recepción
3. La Aplicación de Testing — main.c
La aplicación tiene tres secciones claramente separadas:

3.1 Callback de recepción on_rx_data() (main.c:67-107)
Se registra en el driver y se invoca desde la worker task cuando llegan datos. Implementa un ensamblador de líneas por canal:

on_rx_data(dev)
    │
    ├─ Obtiene el AppLineBuffer del canal (rx_lines[dev->id])
    ├─ Drena todo lo disponible con Transceiver_Read() en bucle
    └─ Por cada byte:
          ├─ '\n' o '\r' → imprime línea acumulada:  [RX UART 02]: mensaje
          ├─ carácter normal → acumula en buf hasta '\n'
          └─ buffer lleno sin '\n' → impresión parcial forzada (anti-overflow)
Hay un AppLineBuffer (1024 bytes) por cada uno de los 14 canales, declarados estáticamente en el array rx_lines[MAX_TRANSCEIVERS]. Esto evita mezclar caracteres de UARTs distintas en la misma línea de consola.

3.2 Tarea de consola TX Tx_Console_Task() (main.c:112-207)
Es una tarea RTEMS independiente (prioridad 100, baja) que bloquea en fgets(stdin) esperando comandos del usuario por la consola USB. El protocolo de comandos es:

<ID> <MENSAJE>     → Envía MENSAJE por la UART número ID
ALL <MENSAJE>      → Envía MENSAJE por TODAS las UARTs
<ID> SLO ON        → Reconfigura UART ID con Slew Rate limitado (mejora EMI)
<ID> SLO OFF       → Reconfigura UART ID con Slew Rate normal
ALL SLO ON/OFF     → Aplica configuración SLO a todas las UARTs
El parseo usa strtok(): primer token = ID o "ALL", resto de la línea = mensaje o subcomando. Los comandos SLO re-ejecutan Transceiver_Init() con una configuración distinta, lo que permite reconfigurar el hardware en caliente sin reiniciar.

3.3 Función Init() — punto de entrada RTEMS (main.c:212-259)
RTEMS la llama al arrancar en lugar de main(). La secuencia de inicialización es:

1. mmu_map_pl_axi_early()        // Mapea en la MMU la región del PL (FPGA) para acceso bare-metal
2. Transceiver_Global_INIT()     // Descubre HW + instala ISR maestra; retorna número de UARTs
3. Bucle for(i < num_transceivers):
       Transceiver_Init(&uarts[i], i, &cfg)         // 115200 8N1, sin SLO
       Transceiver_SetRxCallback(on_rx_data, &uarts[i])
       Transceiver_SendString("UART N Lista.\r\n")  // Mensaje de boot por el cable serie
4. rtems_task_create("CMDT") + rtems_task_start(Tx_Console_Task)
5. rtems_task_delete(RTEMS_SELF)  // Init se suicida; el kernel queda con las worker tasks + CMDT
La tarea Init se elimina a sí misma al final: en RTEMS esto es correcto porque las worker tasks de cada UART y la tarea de consola continúan ejecutándose bajo el planificador.

Diagrama de flujo de datos

Consola USB (teclado)
      │
      │  fgets(stdin)
      ▼
 Tx_Console_Task (prio 100)
      │
      │  Transceiver_SendString(&uarts[id], msg)
      ▼
 Buffer circular TX (4 KB) ──kick──► Registro AXI GPIO CH1 ──► FPGA/UART TX ──► Cable RS232
                                           ▲
                                      Master_ISR() gestiona el resto de bytes via TX IRQ

Cable RS232 ──► FPGA/UART RX ──► IRQ ──► Master_ISR()
                                              │  rtems_event_send(worker_id, EVENT_0)
                                              ▼
                                     Rx_Worker_Task (prio 50)
                                              │  lee bytes, pone en buffer circular RX (4 KB)
                                              │  dev->rx_callback()  →  on_rx_data()
                                              ▼
                                     printf("[RX UART %02d]: %s\n", ...)  ──► Consola USB
Puntos clave de diseño para el TFM
Sin polling: toda la RX es orientada a interrupciones. La CPU solo trabaja cuando hay datos.
ISR mínima: la ISR solo hace reconocimiento de interrupción y señalización de evento. El trabajo real (copiar bytes, invocar callback, printf) lo hace la worker task en contexto de tarea, donde están disponibles todos los servicios de RTEMS.
Un buffer de línea por canal: el array rx_lines[14] permite recibir simultáneamente de varias UARTs sin corrupción de mensajes en la salida.
Reconfiguración en caliente: los comandos SLO ON/OFF llaman a Transceiver_Init() de nuevo, lo que sobreescribe los registros de configuración del hardware sin detener el sistema.
Descubrimiento automático de HW: el número de UARTs y sus direcciones base se leen de registros de la FPGA en tiempo de arranque, haciendo la aplicación independiente de la configuración concreta del bitstream.

## Diseño app de testing de placa cdhs y aocs
### Ampliación en pl para soportar interfaces adicionales cdhs
Para poder probar la funcionalidad de la placa CDHS, faltaba añadir soporte firmware que controlasen las líneas adicionales a RS422 y RS485. 
La manera de preparar el entorno para probar esta placa fue la siguiente: se preparó el hardware en la PL para poder probar las líneas de RS422 y RS485, SPI, CAN y PWM, creando un proyecto en vivado con el script de tcl de regenerate_all con 3 transceivers serie, y añadiendo el bloque de control PWM. Además se configuró la PS para conectar SPI y CAN con el exterior:

En la imagen se ve como en la parte de la izquierda, aparecen activadas las líneas de SPI 0, CAN 0 y CAN 1. Estas tres interfaces se configuraron como externas para que fueran a pines externos directamente conectados al conector FMC hacia la placa CDHS.
Para controlar las líneas de PWM, se creó un circuito en Vivado que generaba 4 señales de PWM diferentes, desde dentro de la FPGA, para que salieran directamente al level shifter de la placa, sin necesidad de añadir ningún control por software en la PS.
se utilizó el mismo BOOT.bin para todas las pruebas de CDHS.
Se utilizó la app de test en RTEMS de los drivers serial para probar el PWM y las líneas serie.
Para probar el SPI, se creó una aplicación en RTEMS para conectarse con el ADC de la placa. 
Para controlar las líneas de SPI:
Diseño del Software para Comunicación SPI con los ADCs de la Placa CDHS
1. Contexto y hardware implicado
La placa CDHS incorpora convertidores analógico-digitales (ADC) del modelo ADS7950 de Texas Instruments, conectados al procesador a través del bus SPI (Serial Peripheral Interface). El software corre sobre el sistema operativo de tiempo real RTEMS 7 ejecutado en el subsistema de procesamiento (PS) del SoC Xilinx Zynq UltraScale+ ZCU102 (procesador ARM Cortex-A53 aarch64). El controlador SPI hardware disponible es el Cadence SPI integrado en el PS del ZynqMP, accesible mediante mapeo directo de memoria (MMIO).

2. Fuentes de información
Recurso	Descripción	Referencia
Datasheet ADS7950	Especificación completa del ADC: protocolo SPI, modos de operación, formato de trama, temporización	Texas Instruments, ADS7950/51/52/53/…, 12/10/8-bit, 1-MSPS ADC Family, SLAS605C, revisado julio 2018. Disponible en: https://www.ti.com/lit/ds/symlink/ads7950.pdf
Zynq UltraScale+ TRM	Descripción del controlador SPI Cadence integrado en el PS del ZynqMP: mapa de registros, bits de control, procedimiento de transferencia	Xilinx/AMD, Zynq UltraScale+ MPSoC Technical Reference Manual, UG1085. Disponible en: https://docs.amd.com/r/en-US/ug1085-zynq-ultrascale-trm
Documentación RTEMS 7	API del sistema operativo: configuración de tareas, temporización, gestión de memoria	https://docs.rtems.org
El datasheet del ADS7950 se encuentra también incluido localmente en el repositorio como spi_test/ads7950.pdf y como texto extraído en spi_test/ads7950.txt.

3. Arquitectura software en capas
El software se organiza en tres capas bien diferenciadas:

┌─────────────────────────────────────────────┐
│              main.c                          │  ← Lógica de aplicación RTEMS
├─────────────────────────────────────────────┤
│         ads7950.c / ads7950.h                │  ← Driver del ADC ADS7950
├─────────────────────────────────────────────┤
│    cadence_spi_low.c / cadence_spi_low.h     │  ← Driver SPI Cadence (MMIO)
└─────────────────────────────────────────────┘
                    Hardware (PS SPI0)
4. Capa 1 — Driver SPI Cadence de bajo nivel (cadence_spi_low)
Origen y motivación
RTEMS 7 no proporciona en su BSP para ZCU102 un driver SPI de alto nivel accesible mediante la API de dispositivos estándar en el momento del desarrollo. Por ello se desarrolló un driver de acceso directo a los registros del controlador SPI Cadence, cuya dirección base en el ZynqMP es 0xFF040000 (SPI0 del PS), tal y como documenta el TRM de Xilinx (UG1085, capítulo de SPI).

El driver se compone de dos ficheros: spi_test/cadence_spi_low.h y spi_test/cadence_spi_low.c.

Mapa de registros implementado
Los offsets de los registros se definieron a partir del TRM (UG1085):

#define CSPI_CONTROL_REG      0x00U  // Configuration Register (CR)
#define CSPI_INTR_STATUS_REG  0x04U  // Interrupt Status Register (ISR)
#define CSPI_INTR_DISABLE_REG 0x0CU  // Interrupt Disable Register
#define CSPI_ENABLE_REG       0x14U  // SPI Enable/Disable
#define CSPI_TX_DATA_REG      0x1CU  // TX FIFO
#define CSPI_RX_DATA_REG      0x20U  // RX FIFO
El acceso a estos registros se realiza mediante punteros volátiles sobre la dirección física, técnica válida en RTEMS ya que el kernel mapea el espacio de E/S del PS en el espacio de direcciones físicas sin MMU adicional:

static volatile uint32_t *spi_reg_base = (volatile uint32_t *)(uintptr_t)base;
Inicialización (cadence_spi_init)
La función de inicialización, definida en cadence_spi_low.c:17, sigue el procedimiento indicado en el TRM:

Deshabilitar el controlador antes de cualquier configuración (registro ENABLE_REG = 0).
Enmascarar todas las interrupciones (se utiliza polling en lugar de interrupciones para simplificar el diseño).
Limpiar flags de estado residuales del ISR.
Calcular el divisor del prescaler: el reloj de entrada al SPI del PS es de 100 MHz (ADS7950_INPUT_CLOCK_HZ). La fórmula del divisor es 2^(prescaler+1), con prescaler en el rango [0, 7] (divisores de 4 a 512). Para la velocidad configurada de 500 kHz (ADS7950_DEFAULT_SPEED_HZ), el bucle calcula el prescaler mínimo que no supere esa frecuencia.
Configurar el registro de control (CR): se activan el modo maestro (MSTREN), el prescaler calculado, y el chip select forzado (SSFORCE) con todos los CS deseleccionados inicialmente (SSCTRL = 0xF). El modo SPI se fija en Modo 0 (CPOL=0, CPHA=0), que es el requerido por el ADS7950 según su datasheet (SLAS605C, sección 7.9, Timing Requirements): el dato SDO del ADC se actualiza en el flanco de bajada de SCLK y el maestro lo muestrea en el flanco de subida.
Habilitar el controlador de nuevo (ENABLE_REG = 1).
Transferencia SPI full-duplex (cadence_spi_transfer)
La función definida en cadence_spi_low.c:61 implementa una transferencia full-duplex byte a byte mediante polling del FIFO:

Se vacía el RX FIFO de datos anteriores.
Se selecciona el chip select CS0 escribiendo 0x0E en el campo SSCTRL del CR (en el Cadence SPI, el campo SSCTRL con decodificación deshabilitada usa máscara invertida: 0xE = 1110b activa CS0 en bajo).
Se ejecuta un bucle lockstep: por cada byte enviado al TX FIFO, se espera a que el byte correspondiente llegue al RX FIFO. Esto garantiza la naturaleza full-duplex del protocolo SPI.
Al finalizar, se deselecciona el CS (SSCTRL = 0xF) para liberar el bus.
5. Capa 2 — Driver del ADC ADS7950 (ads7950)
El ADS7950 y su protocolo SPI
El ADS7950 (SLAS605C) es un ADC SAR de 12 bits, 4 canales, con velocidad de muestreo de hasta 1 MSPS e interfaz SPI de 20 MHz. Su protocolo funciona mediante tramas de 16 bits full-duplex: mientras el maestro envía una palabra de comando al ADC (SDI), el ADC devuelve simultáneamente el resultado de la conversión anterior (SDO).

Esta característica introduce una latencia de un frame: el resultado de la conversión del canal solicitado en la trama N se recibe en la trama N+1. Esto está documentado en el datasheet (SLAS605C, Figure 1, Device Operation Timing Diagram).

El driver se compone de spi_test/ads7950.h y spi_test/ads7950.c.

Construcción de la palabra de comando (Manual Mode)
El ADS7950 soporta varios modos de operación. Se utilizó el Manual Mode, en el que cada trama selecciona explícitamente el canal a convertir a continuación. Según la sección de programación del datasheet (SLAS605C, sección 8.5, Manual Mode), la palabra de 16 bits enviada por SDI tiene el siguiente formato:

Bit 15..12: 0001  → Identificador de Manual Mode
Bit 11:     0     → DI11 (GPIO/Range, no usado)
Bit 10:     X     → DI10
Bit  9:     0     → DI09 (range = 0: 0 a VREF)  
Bit  8:     0     → DI08
Bits 10..7: CCCC  → Selección de canal (4 bits)
Bits  6..0: 0000000 → bits reservados/GPIO
En código, esto se implementa en ads7950.c:13:

static inline uint16_t ads7950_build_command(uint8_t channel)
{
    return (uint16_t)(0x1800u | ((uint16_t)(channel & 0x0Fu) << 7));
}
El prefijo 0x1800 corresponde a 0001 1000 0000 0000b, donde el bit 11 establece el Manual Mode (DI15..12 = 0001) y el campo de canal se desplaza 7 bits para ocupar las posiciones DI10..DI07.

La palabra se transmite MSB first, conforme al datasheet: el byte alto se envía primero, luego el byte bajo.

Lectura de los 4 canales (ADS7950_ReadChannels)
Para obtener los valores de los 4 canales (CH0–CH3) compensando la latencia de un frame, la función ads7950.c:62 ejecuta 6 transferencias en lugar de 4, descartando los 2 primeros resultados (que corresponden al estado previo del ADC):

const uint8_t sequence[6] = { 0, 1, 2, 3, 0, 1 };

for (int i = 0; i < 6; i++) {
    ads7950_transfer(adc, sequence[i], &response);
    if (i >= 2) {
        values[i - 2] = response & 0x0FFFu;
    }
}
La secuencia funciona así:

Frame	Comando enviado	Resultado recibido	¿Se guarda?
0	"Lee CH0"	(anterior, descartado)	No
1	"Lee CH1"	CH0	No (i<2)
2	"Lee CH2"	CH1	Sí → values[0]
3	"Lee CH3"	CH2	Sí → values[1]
4	"Lee CH0"	CH3	Sí → values[2]
5	"Lee CH1"	CH0 (segundo)	Sí → values[3]
El resultado se enmascara con 0x0FFF para extraer únicamente los 12 bits de dato de la respuesta del ADC, ya que los 4 bits superiores de la respuesta SDO contienen información de estado del canal.

Inicialización y destrucción
ADS7950_Init (ads7950.c:33): llama a cadence_spi_init y reserva mediante malloc dos buffers de 2 bytes para TX y RX. La separación en buffers dinámicos permite alineamiento flexible en caso de requerir DMA en el futuro.
ADS7950_Destroy (ads7950.c:84): libera los buffers con free.
6. Capa 3 — Aplicación principal (main.c)
El fichero spi_test/main.c contiene la tarea de entrada RTEMS (Init), que es el punto de arranque del sistema bajo RTEMS 7 (equivalente a main() en un programa convencional).

La configuración del sistema RTEMS (recursos, drivers de reloj y consola, tamaño de pila, etc.) se define en el fichero spi_test/init.c mediante las macros del sistema de configuración de RTEMS (<rtems/confdefs.h>). Los parámetros clave son:

Tick del sistema: 10 ms (100 Hz), necesario para rtems_task_wake_after.
Stack de la tarea Init: 64 KB.
Drivers: se activan el driver de reloj (CLOCK_DRIVER) y el de consola UART (CONSOLE_DRIVER) para printf.
La lógica de la aplicación es la siguiente:

rtems_task Init(rtems_task_argument arg)
{
    ADS7950 adc = { .speed_hz = 0 };
    uint16_t values[ADS7950_NUM_CHANNELS];

    // 1. Inicializar el ADC sobre el dispositivo SPI a 500 kHz
    ADS7950_Init(&adc, ADS7950_SPI_DEVICE, ADS7950_DEFAULT_SPEED_HZ);

    // 2. Bucle infinito: leer los 4 canales cada 500 ms
    for (;;) {
        ADS7950_ReadChannels(&adc, values);
        printf("CH0=%u  CH1=%u  CH2=%u  CH3=%u\n", ...);
        rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(500));
    }
}
El intervalo de muestreo de 500 ms (definido por ADS7950_PRINT_INTERVAL_MS) se implementa mediante rtems_task_wake_after, que suspende la tarea el número de ticks correspondiente sin consumir CPU, permitiendo que el scheduler de RTEMS atienda otras tareas durante ese tiempo.

7. Resumen de parámetros de configuración SPI
Parámetro	Valor	Fuente
Dirección base SPI0 PS	0xFF040000	Xilinx UG1085
Reloj de entrada SPI	100 MHz	Xilinx UG1085
Velocidad de reloj SPI	500 kHz	Diseño propio (conservador)
Modo SPI	Modo 0 (CPOL=0, CPHA=0)	TI SLAS605C, §7.9
Longitud de trama	16 bits	TI SLAS605C, §8.5
Orden de bits	MSB first	TI SLAS605C, §7.6
Resolución ADC	12 bits	TI SLAS605C
Canales leídos	4 (CH0–CH3)	TI SLAS605C
Tramas por lectura completa	6 (2 de preambulo + 4 datos)	TI SLAS605C, Fig. 1

Para probar el CAN, se utilizó una aplicación hecha por mi compañero en el laboratorio y en el proyecto Lince Diego Ramos. En su aplicación, se configuran las líneas de can y se establecen test que comprueban que la conexión por can funciona correctamente. Se cargó una imagen de RTEMS probada por él para probar mi placa.

### ampliación app de testing para soportar interfaces adicionales aocs

Para probar la placa AOCS, se generó un proyecto de Vivado con regenerate_all con 5 transceptores, añadiendo un bloque vhdl para controlar los puentes en H por PWM, en el anexo está Motor_H_bridge_test.vhd, que genera 3 PWMs y los enruta por la línea 1 o 2 de cada motor en función de la dirección deseada. Para estas pruebas, se fijó un tiempo para cada dirección de manera que durante unos segundos el PWM fuera en un sentido (línea 1 pwm y línea 2 a 0) y durante los siguientes segundos en el sentido contrario (línea 1 0 y línea 2 pwm). 
La comunicación por Space Wire no se llegó a probar por falta de tiempo al comprar arneses micro-d-9.

## validación de hardware
### Arnés para verificar comunicaciones rs422
Arnés a 4 hilos, cruzando las líneas TX de un driver con las RX del otro.

### Arnés para verificar comunicaciones rs485
Arnés a dos hilos, en el que se conectan A+ y B- de un driver con los del otro.

### Arnés para verificar comunicaciones can
Se conectan las líneas CAN_H y CAN_L del nominal con las del redundante.

### Equipo de laboratorio utilizado

Se utilizó un osciloscopio y una Fuente de alimentación de hasta 32V.

Esto es un ejemplo de cita a una referencia bibliográfica …

# resultados
CDHS soldada:

AOCS soldada:

Osciloscopio:

LECTURAS OSCILOSCOPIO

CDHS:
ORANIZAR AQUÍ RESULTADOS LECTURAS RS

ORGANIZAR AQUÍ RESULTADOS LECTURAS CAN (TEST DE DIEGO)

ORGANIZAR AQUÍ RESULTADOS LECTURAS ADC

AOCS:
ORGANIZAR AQUÍ LECTURAS RS

# conclusiones y líneas futuras
## Conclusiones
…
## Líneas futuras
…

# anexo 1

MAPA DE SEÑALES CDHS:
| Subsistema | Señal Lógica | Red (FMC HPC0) | Pin FMC (P7) | Pin Zynq MPSoC |
| --- | --- | --- | --- | --- |
| SPI (ADC) | SDO | FMC_HPC0_LA02_N | H8 | V1 |
| SPI (ADC) | SDI | FMC_HPC0_LA00_CC_N | G7 | Y3 |
| SPI (ADC) | SCLK | FMC_HPC0_LA02_P | H7 | V2 |
| SPI (ADC) | CS_N | FMC_HPC0_LA00_CC_P | G6 | Y4 |
| CAN (Nominal) | TX_N | FMC_HPC0_LA21_P | H25 | P12 |
| CAN (Nominal) | RX_N | FMC_HPC0_LA22_P | G24 | M15 |
| CAN (Redundante) | TX_R | FMC_HPC0_LA21_N | H26 | N12 |
| CAN (Redundante) | RX_R | FMC_HPC0_LA22_N | G25 | M14 |
| RS1 (Serial 1) | TX | FMC_HPC0_LA15_P | H19 | Y10 |
| RS1 (Serial 1) | RX | FMC_HPC0_LA11_N | H17 | AB5 |
| RS1 (Serial 1) | DE | FMC_HPC0_LA16_P | G18 | Y12 |
| RS2 (Serial 2) | TX | FMC_HPC0_LA12_N | G16 | W6 |
| RS2 (Serial 2) | RX | FMC_HPC0_LA12_P | G15 | W7 |
| RS2 (Serial 2) | DE | FMC_HPC0_LA11_P | H16 | AB6 |
| RS3 (Serial 3) | TX | FMC_HPC0_LA07_N | H14 | U4 |
| RS3 (Serial 3) | RX | FMC_HPC0_LA07_P | H13 | U5 |
| RS3 (Serial 3) | DE | FMC_HPC0_LA08_N | G13 | V3 |
| PWM (Heaters) | IN1 | FMC_HPC0_LA04_N | H11 | AA1 |
| PWM (Heaters) | IN2 | FMC_HPC0_LA04_P | H10 | AA2 |
| PWM (Heaters) | IN3 | FMC_HPC0_LA03_P | G9 | Y2 |
| PWM (Heaters) | IN4 | FMC_HPC0_LA03_N | G10 | Y1 |

MAPA DE SEÑALES AOCS:
| Subsistema | Señal Lógica | Red (FMC HPC0) | Pin FMC (P1) | Pin Zynq MPSoC |
| --- | --- | --- | --- | --- |
| RS1 (Serial J1) | TX | FMC_HPC0_LA20_N | G22 | M13 |
| RS1 (Serial J1) | RX | FMC_HPC0_LA20_P | G21 | N13 |
| RS1 (Serial J1) | DE | FMC_HPC0_LA19_P | H22 | L13 |
| MOT-PWM (Motor J2) | PWM_X_1 | FMC_HPC0_LA17_CC_N | D21 | N11 |
| MOT-PWM (Motor J2) | PWM_X_2 | FMC_HPC0_LA15_N | H20 | Y9 |
| MOT-PWM (Motor J2) | PWM_Y_1 | FMC_HPC0_LA16_N | G19 | AA12 |
| MOT-PWM (Motor J2) | PWM_Y_2 | FMC_HPC0_LA15_P | H19 | Y10 |
| MOT-PWM (Motor J2) | PWM_Z_1 | FMC_HPC0_LA16_P | G18 | Y12 |
| MOT-PWM (Motor J2) | PWM_Z_2 | FMC_HPC0_LA13_N | D18 | AC8 |
| RS3 (Serial J3) | TX | FMC_HPC0_LA11_N | H17 | AB5 |
| RS3 (Serial J3) | RX | FMC_HPC0_LA12_P | G15 | W7 |
| RS3 (Serial J3) | DE | FMC_HPC0_LA11_P | H16 | AB6 |
| RS4 (Serial J4) | TX | FMC_HPC0_LA09_P | D14 | W2 |
| RS4 (Serial J4) | RX | FMC_HPC0_LA08_N | G13 | V3 |
| RS4 (Serial J4) | DE | FMC_HPC0_LA07_N | H14 | U4 |
| RS5 (Serial J5) | TX | FMC_HPC0_LA07_P | H13 | U5 |
| RS5 (Serial J5) | RX | FMC_HPC0_LA05_P | D11 | AB3 |
| RS5 (Serial J5) | DE | FMC_HPC0_LA08_P | G12 | V4 |
| SPW1 (SpaceWire J6) | DIN_P | FMC_HPC0_LA02_P | H7 | V2 |
| SPW1 (SpaceWire J6) | DIN_N | FMC_HPC0_LA02_N | H8 | V1 |
| SPW1 (SpaceWire J6) | SIN_P | FMC_HPC0_LA04_P | H10 | AA2 |
| SPW1 (SpaceWire J6) | SIN_N | FMC_HPC0_LA04_N | H11 | AA1 |
| SPW1 (SpaceWire J6) | SOUT_P | FMC_HPC0_LA01_CC_P | D8 | AB4 |
| SPW1 (SpaceWire J6) | SOUT_N | FMC_HPC0_LA01_CC_N | D9 | AC4 |
| SPW1 (SpaceWire J6) | DOUT_P | FMC_HPC0_LA00_CC_P | G6 | Y4 |
| SPW1 (SpaceWire J6) | DOUT_N | FMC_HPC0_LA00_CC_N | G7 | Y3 |
| SPW2 (SpaceWire J7) | DIN_P | FMC_HPC0_LA21_P | H25 | P12 |
| SPW2 (SpaceWire J7) | DIN_N | FMC_HPC0_LA21_N | H26 | N12 |
| SPW2 (SpaceWire J7) | SIN_P | FMC_HPC0_LA24_P | H28 | L12 |
| SPW2 (SpaceWire J7) | SIN_N | FMC_HPC0_LA24_N | H29 | K12 |
| SPW2 (SpaceWire J7) | SOUT_P | FMC_HPC0_LA28_P | H31 | T7 |
| SPW2 (SpaceWire J7) | SOUT_N | FMC_HPC0_LA28_N | H32 | T6 |
| SPW2 (SpaceWire J7) | DOUT_P | FMC_HPC0_LA30_P | H34 | V6 |
| SPW2 (SpaceWire J7) | DOUT_N | FMC_HPC0_LA30_N | H35 | U6 |
| RS8 (Serial J8) | TX | FMC_HPC0_LA22_N | G25 | M14 |
| RS8 (Serial J8) | RX | FMC_HPC0_LA19_N | H23 | K13 |
| RS8 (Serial J8) | DE | FMC_HPC0_LA22_P | G24 | M15 |

TABLA NCO:

| Baud | Half | INC_ROM | INC_HALF_ROM | Measured_Hz | Error_ppm |
| --- | --- | --- | --- | --- | --- |
| 9600 | 0 | 412317 | 824634 | 9600.001536 | 0.2 |
| 9600 | 1 | 412317 | 824634 | 19199.993856 | -0.3 |
| 14400 | 0 | 618475 | 1236951 | 14399.988480 | -0.8 |
| 14400 | 1 | 618475 | 1236951 | 28800.018432 | 0.6 |
| 19200 | 0 | 824634 | 1649267 | 19200.012288 | 0.6 |
| 19200 | 1 | 824634 | 1649267 | 38399.950848 | -1.3 |
| 28800 | 0 | 1236951 | 2473901 | 28799.976960 | -0.8 |
| 28800 | 1 | 1236951 | 2473901 | 57599.870976 | -2.2 |
| 31250 | 0 | 1342177 | 2684355 | 31250.000000 | 0.0 |
| 31250 | 1 | 1342177 | 2684355 | 62500.000000 | 0.0 |
| 38400 | 0 | 1649267 | 3298535 | 38400.024576 | 0.6 |
| 38400 | 1 | 1649267 | 3298535 | 76799.901696 | -1.3 |
| 56000 | 0 | 2405182 | 4810363 | 55999.977600 | -0.4 |
| 56000 | 1 | 2405182 | 4810363 | 111999.641601 | -3.2 |
| 57600 | 0 | 2473901 | 4947802 | 57600.036864 | 0.6 |
| 57600 | 1 | 2473901 | 4947802 | 115200.073728 | 0.6 |
| 74400 | 0 | 3195456 | 6390911 | 74400.056544 | 0.8 |
| 74400 | 1 | 3195456 | 6390911 | 148800.666627 | 4.5 |
| 115200 | 0 | 4947802 | 9895605 | 115200.073728 | 0.6 |
| 115200 | 1 | 4947802 | 9895605 | 230401.474569 | 6.4 |
| 128000 | 0 | 5497558 | 10995116 | 128000.000000 | 0.0 |
| 128000 | 1 | 5497558 | 10995116 | 256000.000000 | 0.0 |
| 153600 | 0 | 6597070 | 13194140 | 153600.393217 | 2.6 |
| 153600 | 1 | 6597070 | 13194140 | 307200.786434 | 2.6 |
| 230400 | 0 | 9895605 | 19791209 | 230398.820358 | -5.1 |
| 230400 | 1 | 9895605 | 19791209 | 460797.640716 | -5.1 |
| 256000 | 0 | 10995116 | 21990233 | 256000.000000 | 0.0 |
| 256000 | 1 | 10995116 | 21990233 | 512006.553684 | 12.8 |
| 312500 | 0 | 13421773 | 26843546 | 312500.000000 | 0.0 |
| 312500 | 1 | 13421773 | 26843546 | 625000.000000 | 0.0 |
| 460800 | 0 | 19791209 | 39582419 | 460808.257684 | 17.9 |
| 460800 | 1 | 19791209 | 39582419 | 921616.515368 | 17.9 |
| 500000 | 0 | 21474836 | 42949673 | 500000.000000 | 0.0 |
| 500000 | 1 | 21474836 | 42949673 | 1000000.000000 | 0.0 |
| 576000 | 0 | 24739012 | 49478023 | 576003.686424 | 6.4 |
| 576000 | 1 | 24739012 | 49478023 | 1152007.372847 | 6.4 |
| 614400 | 0 | 26388279 | 52776558 | 614401.572868 | 2.6 |
| 614400 | 1 | 26388279 | 52776558 | 1228803.145736 | 2.6 |
| 750000 | 0 | 32212255 | 64424509 | 749990.625117 | -12.5 |
| 750000 | 1 | 32212255 | 64424509 | 1499925.003750 | -50.0 |
| 921600 | 0 | 39582419 | 79164837 | 921616.515368 | 17.9 |
| 921600 | 1 | 39582419 | 79164837 | 1843148.096950 | -28.2 |
| 1000000 | 0 | 42949673 | 85899346 | 1000000.000000 | 0.0 |
| 1000000 | 1 | 42949673 | 85899346 | 2000000.000000 | 0.0 |
| 1152000 | 0 | 49478023 | 98956046 | 1152007.372847 | 6.4 |
| 1152000 | 1 | 49478023 | 98956046 | 2303882.041239 | -51.2 |
| 1500000 | 0 | 64424509 | 128849019 | 1499925.003750 | -50.0 |
| 1500000 | 1 | 64424509 | 128849019 | 2999850.007500 | -50.0 |
| 1843200 | 0 | 79164837 | 158329674 | 1843148.096950 | -28.2 |
| 1843200 | 1 | 79164837 | 158329674 | 3686635.944700 | 64.0 |
| 2000000 | 0 | 85899346 | 171798692 | 2000000.000000 | 0.0 |
| 2000000 | 1 | 85899346 | 171798692 | 4000000.000000 | 0.0 |
| 2500000 | 0 | 107374182 | 214748365 | 2500000.000000 | 0.0 |
| 2500000 | 1 | 107374182 | 214748365 | 5000000.000000 | 0.0 |
| 3000000 | 0 | 128849019 | 257698038 | 3000300.030003 | 100.0 |
| 3000000 | 1 | 128849019 | 257698038 | 5998800.239952 | -200.0 |
| 3686400 | 0 | 158329674 | 316659349 | 3685956.505713 | -120.3 |
| 3686400 | 1 | 158329674 | 316659349 | 7371913.011426 | -120.3 |

# anexo a: aspectos ÉTICOS, económicos, sociales y ambientales
El apartado “Requisitos de las acreditaciones internacionales EUR-ACE y ABET” de la Normativa de TFT de la ETSIT-UPM establece que “*La memoria del TFT del GITST, GIB y MUIT, y en general la de aquellas titulaciones que hayan obtenido o para las que se desee solicitar una acreditación internacional EUR-ACE o ABET, debe mostrar conciencia de la responsabilidad de la aplicación práctica de la ingeniería, el impacto social y ambiental, el compromiso con la ética profesional, la responsabilidad y las normas de la aplicación práctica de la ingeniería, así como sobre las prácticas de gestión de proyectos, gestión, y control de riesgos, entendiendo sus limitaciones*”. 
Este anexo obligatorio del TFT tendrá un carácter sintético con los siguientes apartados: 
## A.1 iNTRODUCCIÓN
Breve descripción del contexto del proyecto, objetivos, necesidades que pretende cubrir o problemas que pretende resolver, centrándose en su relación con los temas sociales, económicos, éticos, legales y/o ambientales que se hayan identificado.

## A.2 DESCRIPCIÓN DE IMPACTOS RELEVANTES RELACIONADOS CON EL PROYECTO
Síntesis del trabajo realizado en la fase 2, de selección y descripción de impactos. Presentar y justificar las conclusiones a las que se haya llegado sobre cuáles son los asuntos más relevantes relacionados con la sostenibilidad social, económica o ambiental, así como los principales grupos de interés identificados y que se han considerado en los análisis posteriores. 

## A.3 ANÁLISIS DETALLADO DE ALGUNO DE LOS PRINCIPALES IMPACTOS
Síntesis del trabajo de análisis realizado. 

## A.4 CONCLUSIONES
Valorar el proyecto desde un punto de vista ético, social, económico y medioambiental y justificar si el uso de criterios de sostenibilidad ha aportado o puede aportar valor añadido al proyecto.

# anexo b: presupuesto económico
El apartado “Requisitos de las acreditaciones internacionales EUR-ACE y ABET” de la Normativa de TFT de la ETSIT-UPM establece que “*La memoria del TFT del GITST, GIB y MUIT, y en general la de aquellas titulaciones que hayan obtenido o para las que se desee solicitar una acreditación internacional EUR-ACE o ABET, … debe incluir un presupuesto económico*”. A modo de ejemplo, la tabla del presupuesto de un proyecto podría ser la siguiente:
| COSTE DE MANO DE OBRA (coste directo) | COSTE DE MANO DE OBRA (coste directo) | COSTE DE MANO DE OBRA (coste directo) | COSTE DE MANO DE OBRA (coste directo) | COSTE DE MANO DE OBRA (coste directo) | Horas | Horas | Precio/hora | Total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  | 300 | 300 | 15 € | 4.500 € |
|  |  |  |  |  |  |  |  |  |
| COSTE DE RECURSOS MATERIALES (coste directo) | COSTE DE RECURSOS MATERIALES (coste directo) | COSTE DE RECURSOS MATERIALES (coste directo) | COSTE DE RECURSOS MATERIALES (coste directo) | Precio de compra | Uso en meses | Uso en meses | Amortización (en años) | Total |
| Ordenador personal (Software incluido)....... | Ordenador personal (Software incluido)....... | Ordenador personal (Software incluido)....... | Ordenador personal (Software incluido)....... | 1.500,00 € | 6 | 6 | 5 | 150,00 € |
| Impresora láser | Impresora láser | Impresora láser | Impresora láser | 500,00 € | 6 | 6 | 5 | 50,00 € |
| Otro equipamiento | Otro equipamiento | Otro equipamiento | Otro equipamiento |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
| COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | COSTE TOTAL DE RECURSOS MATERIALES | 200,00 € |
|  |  |  |  |  |  |  |  |  |
| GASTOS GENERALES (costes indirectos) | GASTOS GENERALES (costes indirectos) | 15% | 15% | sobre CD | sobre CD | sobre CD | sobre CD | 705,00 € |
| BENEFICIO INDUSTRIAL | BENEFICIO INDUSTRIAL | 6% | 6% | sobre CD+CI | sobre CD+CI | sobre CD+CI | sobre CD+CI | 324,30 € |
|  |  |  |  |  |  |  |  |  |
| MATERIAL FUNGIBLE | MATERIAL FUNGIBLE |  |  |  |  |  |  |  |
| Impresión | Impresión | Impresión | Impresión | Impresión | Impresión | Impresión | Impresión | 100,00 € |
| Encuadernación | Encuadernación | Encuadernación | Encuadernación | Encuadernación | Encuadernación | Encuadernación | Encuadernación | 300,00 € |
| IVA APLICABLE | IVA APLICABLE | IVA APLICABLE | IVA APLICABLE | IVA APLICABLE | IVA APLICABLE | IVA APLICABLE | 21% | 1.287,15 € |
|  |  |  |  |  |  |  |  |  |
| TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | TOTAL PRESUPUESTO | 7.416,45 € |

Esta tabla podría ser rellenada mediante una sencilla hoja de cálculo como la siguiente:

