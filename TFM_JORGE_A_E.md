

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

Este Trabajo de Fin de Máster presenta el desarrollo de una plataforma de comunicación con periféricos sobre el MPSoC Zynq UltraScale+ ZCU102, en el marco del proyecto LINCE, una iniciativa del PERTE Aeroespacial liderada por Indra para el desarrollo de microsatélites de órbita baja.

El trabajo abarca tres áreas principales. En primer lugar, diseñé e implementé en VHDL un IP core de transceptor serie configurable para la lógica programable del MPSoC, con soporte para los estándares RS422 y RS485 y configuración en tiempo de ejecución de baudrate, paridad, bits de datos, bits de parada y orden de bit. En segundo lugar, desarrollé en C un driver para el sistema operativo de tiempo real RTEMS capaz de gestionar múltiples instancias del transceptor de forma simultánea, con modelo de interrupciones, buffers circulares y una API pública que abstrae completamente el hardware. En tercer lugar, diseñé tres placas de circuito impreso conectadas a la ZCU102 mediante conector FMC HPC: la placa CDHS, con interfaces RS422/RS485, CAN, SPI y PWM; la placa AOCS, con interfaces RS422/RS485, SpaceWire y PWM para control de motores; y la placa LINCE Comunicación Serie, un diseño propio con 14 canales serie —7 RS485 en bus compartido y 7 RS422— orientado a la validación del sistema completo con todas las instancias del transceptor operando en paralelo.

Para la validación se desarrollaron herramientas de software específicas y se utilizó instrumental de laboratorio adicional, confirmando el correcto funcionamiento tanto del driver serie como de las distintas funcionalidades de las placas. (La placa LINCE Comunicación Serie se encuentra en fase de fabricación.)

El conjunto del trabajo constituye una plataforma funcional y documentada que el equipo de Sener, Indra y el laboratorio B105 pueden utilizar como base para el subsistema de comunicaciones del ordenador de a bordo del satélite LINCE en el futuro.

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

El diseño de ordenadores de a bordo (OBC) para satélites exige resolver un reto de ingeniería que va más allá del procesamiento puro: conseguir que el procesador central se comunique de forma determinista y fiable con una familia heterogénea de periféricos —sensores de actitud, actuadores, cargas de pago— a través de buses serie con especificaciones eléctricas y de temporización muy diferentes entre sí. En el marco del proyecto LINCE, el grupo B105 Electronic Systems Lab de la Universidad Politécnica de Madrid asume la responsabilidad del subsistema de comunicaciones del OBC.

Me incorporé al laboratorio B105 como colaborador en prácticas para trabajar en el proyecto LINCE, y mi tarea inicial consistió en implementar el soporte de comunicaciones serie RS422 y RS485 sobre la plataforma de evaluación Zynq UltraScale+ ZCU102. Esta plataforma, basada en un MPSoC que integra en un mismo encapsulado un subsistema de procesamiento ARM (PS) y una lógica programable tipo FPGA (PL), proporciona la flexibilidad necesaria para implementar transceptores serie a medida. Se optó por un diseño propio en VHDL en lugar de emplear IPs de terceros, con el objetivo de obtener control total sobre el comportamiento del transceptor: parámetros de temporización, gestión de errores y adaptación a los requisitos concretos del sistema.

A medida que avanzaba el desarrollo, el alcance del trabajo se fue ampliando: las tareas de hardware me fueron asignadas al ir demostrando capacidad para asumirlas. Así, además del diseño del transceptor y su driver software, asumí el diseño de las tarjetas de circuito impreso necesarias para validar el sistema frente a los requisitos del consorcio. La colaboración directa con Sener —socio tecnológico del proyecto LINCE, con reuniones quincenales y comunicación continua por correo— fue determinante tanto para definir esos requisitos como para iterar sobre el diseño. A su vez, Sener traslada los requisitos técnicos impuestos por Indra, que lidera el consorcio.

El resultado de todo este trabajo es una plataforma funcional que abarca el codiseño hardware-software del subsistema de comunicaciones serie, su integración bajo el sistema operativo de tiempo real RTEMS, y la fabricación y validación de dos tarjetas de prueba.

## Objetivos

El objetivo principal de este trabajo es desarrollar una plataforma funcional y validada de comunicación con periféricos serie sobre el MPSoC Zynq UltraScale+ ZCU102, que sirva como base para el OBC del proyecto LINCE. Para alcanzarlo, me propuse los siguientes objetivos específicos:

1. **Diseñar un IP core de transceptor serie configurable en VHDL** para la lógica programable del MPSoC, capaz de operar sobre los estándares RS422 y RS485, con parámetros configurables en tiempo de ejecución: baudrate, paridad, número de bits de datos, bits de parada y orden de bit.

2. **Desarrollar un driver de software completo en C para RTEMS** que abstraiga el acceso al hardware y permita a la aplicación gestionar hasta 14 instancias de transceptor simultáneas mediante una API orientada a interrupciones, sin recurrir a polling de CPU.

3. **Diseñar y fabricar las tarjetas de expansión de prueba** requeridas para validar el sistema frente a los subsistemas CDHS (gestión de datos y calentadores) y AOCS (control de actitud y órbita) del satélite, integrando interfaces RS422/RS485, CAN, SPI, SpaceWire y PWM.

4. **Desarrollar herramientas de automatización del flujo de desarrollo**, incluyendo scripts TCL para la generación automática del diseño en Vivado y scripts de despliegue de imágenes, con el fin de reducir los tiempos de iteración.

5. **Integrar y validar el sistema completo**, verificando la comunicación entre la ZCU102 y las tarjetas de expansión a través de los distintos buses implementados.

# Metodología

El desarrollo de este trabajo se enmarcó en la dinámica de trabajo colaborativo del proyecto LINCE. Mantuve reuniones quincenales con los ingenieros de Sener asignados al proyecto, además de comunicación continua por correo para resolver dudas técnicas y alinear requisitos. Las tareas se gestionaron mediante Jira, donde cada reunión servía para revisar el estado de los ítems abiertos, identificar bloqueos y planificar los próximos hitos. Los requisitos de diseño de las PCBs de prueba llegaron a través de Sener, que los traslada desde Indra como líder del consorcio.

El trabajo se estructuró en dos fases principales:

**Fase 1 — Familiarización y establecimiento del entorno (octubre – enero):** Dediqué los primeros meses a establecer las bases del entorno de desarrollo: instalación y configuración de Vivado y Vitis, compilación de RTEMS 7 desde código fuente para la arquitectura AArch64 mediante el RTEMS Source Builder, y validación del flujo completo (síntesis en Vivado → empaquetado en Vitis → ejecución en RTEMS sobre la ZCU102) con un ejemplo funcional de extremo a extremo. Esta fase fue fundamental para comprender la arquitectura PS-PL del MPSoC y las particularidades del entorno de compilación cruzada para sistemas empotrados.

**Fase 2 — Desarrollo e integración (febrero – junio):** Con el entorno establecido, abordé el desarrollo principal: el transceptor serie en VHDL, el driver para RTEMS, el diseño de las PCBs CDHS y AOCS, y las aplicaciones de prueba. Seguí una metodología iterativa: cada módulo se implementaba, se validaba de forma aislada (mediante simulación en Vivado o prueba directa sobre la placa) y se integraba en el sistema global antes de avanzar al siguiente.

Quedan pendientes para la fase final, antes de la entrega del TFM en septiembre de 2026, la fabricación y validación de la PCB de diseño propio y el desarrollo de la aplicación de testing exhaustivo de los 14 transceptores en paralelo.

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

> **[FIGURA: Diagrama FSM del transmisor — tres partes]**

Durante las pruebas sobre la placa CDHS se detectó que en las primeras recepciones aparecían ocasionalmente caracteres corruptos. Como primera hipótesis se consideró que la señal DE podría estar conmutando demasiado rápido al paso de transmisión a recepción, haciendo que el transceptor físico no tuviera tiempo de establecerse. Para corregirlo, se añadieron dos estados adicionales en la FSM del transmisor que introducen un retardo de microsegundos entre la desactivación del último bit y la desactivación de DE. Sin embargo, esto no resolvió el problema, descartando la hipótesis inicial.

### receptor

El siguiente diagrama FSM resume el comportamiento del receptor.

> **[FIGURA: Diagrama FSM del receptor]**

#### Decisión de diseño: verificación de start-bit a mitad de período

Tras descartar el flanco de DE como causa de los caracteres corruptos, el análisis se centró en el receptor. El protocolo serie comienza con un **start-bit**: la línea, normalmente en reposo en nivel alto, cae a nivel bajo para señalizar el inicio de una trama. El receptor detecta este flanco descendente y arranca la máquina de estados de recepción.

El problema era que pulsos de ruido breves en la línea generaban flancos descendentes espurios que el receptor interpretaba como start-bits válidos, capturando una trama de basura y enviando un carácter corrupto al buffer.

La solución se implementó directamente en la FSM: en el estado de recepción del start-bit, una vez transcurrido el **primer medio período de bit**, se vuelve a muestrear la línea antes de continuar. Si la línea ha vuelto a nivel alto, el pulso era ruido y la FSM regresa al estado IDLE sin capturar nada. Solo si la línea sigue en bajo al llegar a la mitad del bit se considera un start-bit legítimo y se procede con la recepción del resto de la trama.

Esta técnica —verificación a mitad de start-bit— es una práctica estándar de robustez en receptores UART. Su implementación en la FSM VHDL eliminó por completo la aparición de caracteres corruptos en las pruebas posteriores.

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

El proceso manual de exportación del XSA, creación de la plataforma Vitis, compilación del FSBL y ensamblado del BOOT.BIN con `bootgen` resultó tedioso de repetir en cada iteración del diseño. Para automatizarlo, desarrollé el script `generate_boot.sh` (disponible en `tfm/04_tools/`), un wizard interactivo en Bash que encadena todos estos pasos de forma desatendida. El script ofrece tres puntos de entrada según el estado en que se encuentre el trabajo: partir del proyecto de Vivado y generar bitstream desde cero, partir de un proyecto con bitstream ya generado y solo exportar el XSA, o partir directamente de un XSA ya exportado. A partir de ahí invoca Vitis en modo script mediante su API Python para crear la plataforma y compilar el FSBL, y llama a `bootgen` para ensamblar el BOOT.BIN final con los componentes de arranque precompilados (PMUFW, BL31, U-Boot, DTB). Esto redujo el tiempo de iteración hardware→imagen de varios minutos de clicks a una sola ejecución de terminal.
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

# desarrollo hardware

Una vez completado el firmware del transceptor serie, desarrollé el hardware de prueba necesario para validar el sistema en condiciones reales. El plan inicial era diseñar una única PCB propia para testear múltiples líneas serie. Posteriormente, el proyecto LINCE requirió dos tarjetas adicionales con especificaciones impuestas por Indra —la placa CDHS y la placa AOCS— para que Sener pudiera validar su firmware sobre la ZCU102. Los esquemáticos completos, BOMs y archivos de fabricación de las tres placas están disponibles en el repositorio del proyecto bajo `HARDWARE/`.

## diseño placa de comunicación serie (diseño propio)

El objetivo de esta placa es poder ejercitar simultáneamente los 14 transceptores del IP core, replicando las topologías de bus reales que se encontrarán en el satélite: RS485 multipunto con múltiples nodos en el mismo cable, y RS422 en configuración master/slave con cruce de TX y RX. A diferencia de las placas CDHS y AOCS, cuyas especificaciones vinieron dictadas por Indra, esta placa fue diseñada con total libertad para maximizar la flexibilidad de los ensayos en laboratorio.

La arquitectura general de la placa, visible en la hoja de nivel superior del esquemático, divide los 14 canales en dos grupos conectados al FMC:

> **[FIGURA: `LINCE_comunicacion_serial.pdf` — hoja TOP.SchDoc (hoja 1): arquitectura general de la placa con los 7 drivers RS485 a la izquierda, el conector FMC en el centro y los 7 drivers RS422 a la derecha]**

- **7 drivers RS485 (RS0–RS6)** conectados a un bus diferencial común mediante jumpers, formando una topología multipunto configurable.
- **7 drivers RS422 (RS7–RS13)** organizados en dos buses master/slave independientes (BUS 1: 1 master + 3 slaves; BUS 2: 1 master + 2 slaves), con la línea TX cruzada con RX para emular la conexión real punto a punto RS422.

### Topología RS485: bus compartido configurable por jumper

La decisión de diseño más relevante de esta placa es el mecanismo de bus compartido RS485 sin necesidad de recablear. Cada driver RS485 tiene un conector Dupont de 3 pines (A+, B−, GND) que actúa a la vez como punto de conexión hacia el exterior y como punto de interconexión entre drivers adyacentes. Colocando un jumper entre dos conectores consecutivos, las líneas A y B de ambos drivers quedan físicamente unidas, formando un segmento de bus RS485 compartido. Retirando el jumper, el driver queda independiente y puede conectarse a un periférico externo de forma individual.

> **[FIGURA: `LINCE_comunicacion_serial.pdf` — hoja RS485-Dupont-Conector.SchDoc (hoja 7): circuito del conector Dupont con la sección "Use" mostrando el jumper de bus compartido y la sección "Example" con drivers 0–2 en bus 1 y drivers 3–6 en bus 2]**

Este mecanismo permite configurar por hardware cualquier partición de los 7 drivers RS485 en uno o varios buses, sin modificar el firmware ni el cableado exterior. Por ejemplo, se pueden agrupar tres drivers en un bus para simular un segmento de red del OBC, y dejar los otros cuatro libres para conectar periféricos reales.

### Selector de conector Micro-D para RS485

Los conectores de mayor densidad (Micro-D) de la placa son compartidos entre el Driver 0 y el Driver 6 mediante un jumper de selección de hardware. Dependiendo de la posición del jumper, los conectores Micro-D quedan asignados a uno u otro driver, lo que permite usar un único tipo de conector con cableado de satélite sin duplicar el número de conectores en la placa.

> **[FIGURA: `LINCE_comunicacion_serial.pdf` — hoja Driver-selector-0-6-485.SchDoc (hoja 11): circuito del selector con las dos posiciones de jumper y los ejemplos de conectividad resultantes]**

### Topología RS422: master/slave configurable por jumper

Para RS422, cada driver slave dispone de un conector con las líneas TX cruzadas a RX (TX-Y+/TX-Z− conectadas a RX del bus), replicando la conexión estándar punto a punto RS422 donde el receptor del esclavo escucha las transmisiones del master. Al igual que en RS485, un jumper determina si el driver se une al bus común o permanece independiente.

> **[FIGURA: `LINCE_comunicacion_serial.pdf` — hoja RS422-Slave-Conector.SchDoc (hoja 12): circuito con el cruce TX↔RX y la sección "Use/Example" mostrando el master con sus esclavos conectados al bus]**

El esquemático completo (12 hojas) y la BOM están disponibles en `HARDWARE/lince_comunicacion_serial/` del repositorio del proyecto.

> **[FIGURA: Foto de la placa fabricada — pendiente]**

## diseño placa cdhs

La placa LINCE3 CDHS BreakoutBox es una tarjeta de interconexión entre la ZCU102 (conectada por FMC) y los periféricos del subsistema de gestión de datos y calentadores del satélite. Sus especificaciones fueron definidas por Indra: 6 conectores D-Sub-9 (J1–J6), interfaces CAN redundante, tres canales RS422/RS485, cuatro líneas PWM para calentadores y un ADC para termistores.

> **[FIGURA: `LINCE3_CDHS.pdf` — hoja LINCE3\_TOP.SchDoc (hoja 1): diagrama jerárquico con el bloque CAN (J1), los tres bloques RS (J2–J4), el bloque PWM (J5) y el bloque ADC/THERM (J6) conectados al bloque MPSoC/FMC]**

> **[FIGURA: Render 3D de la PCB — vista superior e inferior]**

### Decisión de nivel de tensión: 1.8 V

Todos los bancos de pines del conector FMC HPC utilizados por esta placa operan a 1.8 V. Se buscaron deliberadamente componentes con VIO nativo a 1.8 V para evitar etapas de adaptación de nivel adicionales entre el MPSoC y los transceptores. Esta decisión simplifica el diseño y reduce el número de componentes activos en la cadena de señal.

### Subsistema CAN

El bus CAN implementa topología redundante con dos instancias independientes: CAN Nominal (CAN_NOM) y CAN Redundante (CAN_RED). Se seleccionó el transceptor **TCAN1044AVDRQ1** de Texas Instruments por su compatibilidad nativa con VIO de 1.8 V, grado automotriz y baja corriente en modo standby. Ambos canales convergen en el conector J1.

#### Terminación split con jumpers

Las resistencias de terminación siguen el esquema *split termination* recomendado en las notas de aplicación del estándar CAN (ISO 11898-2). En lugar de una única resistencia de 120 Ω entre CANH y CANL, se emplean **dos resistencias de 60 Ω en serie** con un **condensador de 4.7 nF** conectado desde el punto medio al plano de masa. Cada una de las dos resistencias de 60 Ω está controlada por un jumper independiente, lo que permite habilitar o deshabilitar la terminación sin modificar el circuito. Las ventajas de este esquema frente a la terminación simple son dos: la resistencia equivalente sigue siendo 120 Ω cuando ambos jumpers están colocados, y el condensador de derivación crea un camino de baja impedancia para las interferencias de modo común de alta frecuencia hacia masa, mejorando el comportamiento EMC del bus. Este último aspecto resultó observable durante las pruebas, donde la forma de onda diferencial mejoraba visiblemente al conectar las resistencias de terminación.

#### Protección ESD

Las líneas CANH y CANL de cada canal incorporan diodos de protección ESD **ESDCAN24-2BLY**, específicamente diseñados para buses CAN. Este componente garantiza que los transceptores no sufran daños por descargas electrostáticas al conectar o desconectar cables en el laboratorio, y su capacidad parásita reducida preserva la integridad de señal a las velocidades de operación del bus CAN.

> **[FIGURA: `LINCE3_CDHS.pdf` — hoja CAN.SchDoc: transceptores TCAN1044 con la red de terminación split (2×60 Ω + 4.7 nF) controlada por jumpers y los diodos ESD ESDCAN24-2BLY]**

### Subsistema RS422/RS485

Se disponen tres canales serie idénticos e independientes (RS1, RS2, RS3), cada uno con el transceptor **THVD1424RGTR**. Este integrado fue elegido porque soporta VIO de 1.8 V, incorpora resistencias de terminación internas conmutables, y permite seleccionar entre modo Half-Duplex y Full-Duplex sin cambiar el hardware. La configuración se expone mediante jumpers físicos de 2 pines:

- **H/F**: conmuta entre Half-Duplex (bus compartido RS485) y Full-Duplex (punto a punto RS422).
- **SLR**: habilita el control de slew rate del driver, reduciendo las emisiones EMI a expensas de velocidad.
- **TERM\_TX / TERM\_RX**: conectan las resistencias de terminación internas del integrado en las líneas TX y RX respectivamente.

Esta flexibilidad por jumper permite probar ambos protocolos (RS422 y RS485) con la misma placa y el mismo cableado, cambiando únicamente la configuración física del transceptor. Los tres canales salen por los conectores J2, J3 y J4.

#### Protección ESD en canales RS

Tanto las líneas RX (RX\_P / RX\_N) como las TX (TX\_P / TX\_N) de cada canal llevan un par de diodos TVS **SM712-02HTG** conectados entre las líneas diferenciales y el plano de masa. El SM712 es un TVS bidireccional de baja capacidad específicamente indicado para interfaces de datos de alta velocidad, que clampea transitorios por encima de su tensión de ruptura sin introducir una capacitancia parásita significativa que degradaría la integridad de señal. Esta protección resulta especialmente relevante en el contexto de laboratorio, donde los cables se conectan y desconectan frecuentemente con la alimentación activa.

#### Decisión de diseño: cortocircuito DE–RE

El THVD1424 expone dos pines de control independientes: **DE** (*Driver Enable*, activo en alto) habilita el transmisor, y **RE** (*Receiver Enable*, activo en bajo) habilita el receptor. En el esquemático, ambos pines están conectados a la misma señal de control procedente del MPSoC.

El resultado es que una única línea digital controla simultáneamente transmisor y receptor de forma complementaria:

| Señal DE/RE | Transmisor (DE) | Receptor (RE activo bajo) |
|---|---|---|
| **1 (alto)** | Habilitado | Deshabilitado |
| **0 (bajo)** | Deshabilitado | Habilitado |

Esta decisión responde a dos motivos concretos. Por un lado, el equipo de Indra comunicó que en la arquitectura del satélite los esclavos solo transmiten bajo demanda del OBC, por lo que no existe un escenario real en el que un nodo deba transmitir y recibir simultáneamente. Por otro lado, cuando el THVD1424 se configura en modo Half-Duplex, las líneas TX y RX comparten físicamente el mismo par diferencial A/B. Si el receptor permaneciera activo durante la transmisión, el nodo escucharía su propio eco, lo que podría confundir al driver de software. Cortocircuitar DE con RE elimina este problema sin ningún componente adicional: al activar la transmisión (DE=1) se deshabilita automáticamente la recepción (RE=1, inactivo), y al volver al modo de escucha (DE=0) el receptor se rehabilita de forma inmediata.

> **[FIGURA: `LINCE3_CDHS.pdf` — hoja RS.SchDoc (hoja 4): circuito completo de un canal RS con el THVD1424RGTR, el cortocircuito DE–RE (ambos pines al mismo net de control), los jumpers H/F (P3), SLR (P4), TERM\_TX (P5) y TERM\_RX (P6), y los diodos TVS SM712-02HTG en RX\_P/N y TX\_P/N]**

### Subsistema PWM (calentadores)

Cuatro señales PWM de 1.8 V procedentes del FMC se elevan a 3.3 V mediante el adaptador de niveles **TXU0104PWR** para excitar los circuitos de control de calentadores externos. El nivel de salida de 3.3 V fue el requerido por Indra para esta interfaz. Las cuatro líneas adaptadas salen por J5.

Para la validación de esta interfaz se diseñó un bloque VHDL autónomo, `PWMx4_auto_test`, sintetizado en la PL junto al resto del diseño de Vivado. El bloque genera cuatro señales PWM independientes con duty cycle del 50% a partir del reloj de 100 MHz de la FPGA: canal 0 a 10 kHz, canal 1 a 5 kHz, canal 2 a 1 kHz y canal 3 a 100 Hz. Al ser completamente autónomo no requiere ningún driver ni intervención de la PS, lo que permitió verificar el subsistema PWM de la placa con el mismo `BOOT.BIN` utilizado para las pruebas serie.

### Subsistema ADC (termistores)

Cuatro entradas analógicas de termistores (CH0–CH3) se digitalizan con el ADC SAR de 12 bits **ADS7950QDBTRQ1**, comunicado al procesador por SPI a 1.8 V. La circuitería analógica opera a 3.3 V por requerimientos del ADC; ambos carriles (+VBD a 1.8 V y +VA a 3.3 V) son independientes para evitar acoplos entre el dominio digital y el analógico. Los termistores se conectan por J6.

### Alimentación

El conector FMC suministra 12 V, 3.3 V y el carril VADJ a 1.8 V. El convertidor conmutado **R-78E5.0-1.0** genera los 5 V necesarios para la etapa de potencia de los transceptores RS y CAN a partir de los 12 V del FMC. Se eligió este módulo DC/DC por su integración en un footprint reducido de 3 pines (equivalente a un regulador lineal) y su eficiencia ≥ 96%, evitando la disipación térmica que tendría un LDO con ese diferencial de tensión.

### Conectores externos

Los seis puertos D-Sub-9 (J1–J6) son de tipo macho o hembra según la convención de uso: J1–J5 hembra (para cables con conector macho en los periféricos externos), J6 macho (el ADC actúa como maestro SPI). Los escudos metálicos de todos los conectores (SH1, SH2) están conectados al plano de GND para mantener la continuidad de apantallamiento EMI con los cables blindados.

### Mapa de señales

El mapa completo de señales entre la placa CDHS y el conector FMC se encuentra en el Anexo 1 de este documento. El esquemático completo y la BOM están disponibles en `HARDWARE/CDHS/`.

## diseño placa aocs

La placa LINCE3 AOCS BreakoutBox es la tarjeta de interconexión para el subsistema de control de actitud y órbita del satélite. Al igual que la CDHS, conecta la ZCU102 mediante FMC y expone las interfaces al exterior a través de conectores D-Sub-9, en este caso 8 conectores (J1–J8).

> **[FIGURA: `LINCE3_AOCS.pdf` — hoja LINCE3\_TOP.SchDoc (hoja 1): diagrama jerárquico con los 5 bloques RS (J1, J3–J5, J8), el bloque MOT-PWM (J2), los dos bloques SpaceWire LVDS (J6, J7) y el bloque FMC]**

> **[FIGURA: Render 3D de la PCB — vista superior e inferior]**

### Canales RS422/RS485

La placa incorpora 5 canales serie (RS1, RS3, RS4, RS5, RS8) con exactamente el mismo diseño de transceptor THVD1424RGTR descrito en la sección de la placa CDHS, incluyendo el cortocircuito DE–RE y los jumpers de configuración H/F, SLR y terminación. Los canales salen por J1, J3, J4, J5 y J8.

### Canales SpaceWire

Se implementan dos enlaces SpaceWire full-duplex independientes (SPW1 y SPW2) mediante señalización diferencial LVDS, sin transceptor activo adicional ya que el estándar SpaceWire opera directamente a niveles LVDS compatibles con los bancos del FMC. Los pares diferenciales —cuatro por enlace: DIN, SIN, SOUT y DOUT— se han trazado en la PCB con técnicas de igualación de longitud (*length matching*) para minimizar el *skew* entre el par de datos y el par de strobe, y con impedancia característica controlada de 100 Ω diferencial. Los dos enlaces salen por J6 y J7.

> **[FIGURA: Página del esquemático AOCS del subsistema SpaceWire, mostrando los cuatro pares diferenciales y su conexión al FMC]**

### Control de motores (MOT-PWM)

Seis señales PWM de 1.8 V procedentes del FMC se elevan al nivel de tensión requerido por los puentes en H externos mediante un adaptador de niveles. Las señales se agrupan en tres pares (X, Y, Z para los tres ejes del satélite), con dos líneas por eje para controlar la dirección de giro del motor. Salen por J2. La alimentación de potencia de los motores se conecta mediante dos bornes banana independientes de la alimentación de la placa, permitiendo usar una fuente de laboratorio externa para los puentes en H sin interferir con la electrónica de señal.

### Alimentación

Misma arquitectura que la placa CDHS: 12 V del FMC, convertidor DC/DC para los 5 V de potencia, y VADJ 1.8 V para los transceptores.

### Mapa de señales

El mapa completo de señales entre la placa AOCS y el conector FMC se encuentra en el Anexo 1 de este documento. El esquemático completo y la BOM están disponibles en `HARDWARE/AOCS/`.

## fabricación

Una vez validados los esquemáticos y completado el rutado de las PCBs, se encargaron las placas con stencil a **PCBWay**, y los componentes a **Mouser** y **DigiKey** según disponibilidad. El proceso de montaje en el laboratorio siguió los pasos habituales de soldadura por reflujo SMD:

1. **Aplicación de pasta de soldadura.** Se fijó la placa a la mesa con placas de idéntico grosor alrededor y cinta de pintor. Se colocó el stencil alineado y se extendió la pasta con espátula.
2. **Colocación de componentes.** Con pinzas de punta fina, se colocaron los componentes SMD sobre la pasta. Se montaron dos placas en paralelo para optimizar el tiempo de proceso.
3. **Reflujo.** Las placas se introdujeron en el horno de reflujo del laboratorio seleccionando el perfil de temperatura adecuado para la pasta de soldadura utilizada.

> **[FIGURA: Foto del proceso de fabricación — aplicación de pasta con stencil, o colocación de componentes]**

> **[FIGURA: Foto de la placa CDHS soldada (cara superior)]**

> **[FIGURA: Foto de la placa AOCS soldada (cara superior)]**

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
Para controlar las líneas de PWM se instanció el bloque `PWMx4_auto_test`, que genera desde la PL cuatro señales PWM a 10 kHz, 5 kHz, 1 kHz y 100 Hz con duty cycle del 50%, sin necesidad de ningún driver en la PS.
se utilizó el mismo BOOT.bin para todas las pruebas de CDHS.
Se utilizó la app de test en RTEMS de los drivers serial para probar el PWM y las líneas serie.
Para probar el ADC ADS7950 de la placa CDHS, se desarrolló una pequeña aplicación de lectura SPI sobre RTEMS. Dado que el BSP de RTEMS 7 para ZCU102 no incluía en ese momento un driver SPI de alto nivel, se accedió directamente al controlador SPI Cadence integrado en el PS mediante mapeo de registros en memoria (MMIO), siguiendo el mapa de registros descrito en el Manual de Referencia Técnico del Zynq UltraScale+ (AMD/Xilinx, UG1085). El protocolo de comunicación con el ADC —formato de trama de 16 bits, selección de canal en Manual Mode y gestión de la latencia de conversión— se implementó conforme al datasheet del ADS7950 (Texas Instruments, SLAS605C).

**Referencias:**

Texas Instruments. (2018). *ADS7950/51/52/53 — 12/10/8-Bit, 1-MSPS, 4-/8-Channel, Serial Interface, MicroPower Sampling Analog-to-Digital Converter* (SLAS605C). Recuperado de https://www.ti.com/lit/ds/symlink/ads7950.pdf

AMD/Xilinx. (2023). *Zynq UltraScale+ MPSoC Technical Reference Manual* (UG1085). Recuperado de https://docs.amd.com/r/en-US/ug1085-zynq-ultrascale-trm

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

En este capítulo se recogen los resultados de la validación hardware del sistema completo. Las pruebas se realizaron con la placa CDHS y la placa AOCS conectadas a la ZCU102 mediante FMC. La placa de comunicación serie de diseño propio queda pendiente de fabricación y sus resultados se incorporarán antes de la entrega final.

## Montaje del sistema

> **[FIGURA: Foto del sistema completo montado — ZCU102 con la placa CDHS conectada al puerto FMC J5, alimentación y cables de laboratorio]**

> **[FIGURA: Foto de la placa CDHS soldada (vista superior con los componentes montados)]**

> **[FIGURA: Foto de la placa AOCS soldada (vista superior)]**

## Validación de comunicaciones serie RS422/RS485

Las pruebas de comunicaciones serie se realizaron con la aplicación de testing en RTEMS, que expone una consola interactiva por USB donde el usuario puede enviar mensajes a cualquier transceptor con el formato `<ID> <MENSAJE>` o a todos simultáneamente con `ALL <MENSAJE>`. Se construyeron arneses de loopback para interconectar los canales:

- **RS422**: arnés a 4 hilos cruzando TX\_P/N de un canal con RX\_P/N del opuesto.
- **RS485**: arnés a 2 hilos conectando A+ y B− de un canal con A+ y B− del otro.

### CDHS — 3 transceptores

Al arrancar, el driver descubrió automáticamente los 3 transceptores instanciados en el bitstream e imprimió sus direcciones base (`0xA0000000`, `0xA0001000`, `0xA0002000`), confirmando el mecanismo de descubrimiento dinámico de hardware. A continuación, la consola reportó `UART 00 [OK]`, `UART 01 [OK]`, `UART 02 [OK]`.

Las pruebas de loopback mostraron que los mensajes enviados por UART 0 llegaban a UART 2 y viceversa, y los enviados por UART 1 llegaban correctamente. En las primeras recepciones de esta captura aparecen caracteres corruptos (`?`), correspondientes a una iteración previa del diseño antes de aplicar la corrección de robustez del receptor descrita en la sección del transceptor VHDL (verificación de start-bit a mitad de período). Una vez implementada esa mejora en la FSM del receptor, los caracteres corruptos desaparecieron por completo en las pruebas posteriores.

```
[TRANSCEIVER DEBUG] Detectados: 3 | Base: 0xA0000000 | INT: 0xA0003000
UART 00 [OK]  UART 01 [OK]  UART 02 [OK]
CMD> 0 HOLA MUNDO
Tx -> UART 0: OK
[RX UART 02]: HOLA MUNDO
CMD> 2 HOLA MUNDO
Tx -> UART 2: OK
[RX UART 00]: HOLA MUNDO
```

> **[FIGURA: captura completa del terminal `cdhs_testing_rs` disponible en `tfm/terminal/`]**

### AOCS — 5 transceptores

Con el bitstream de 5 transceptores para la placa AOCS, el descubrimiento detectó correctamente 5 instancias (`0xA0000000`–`0xA0004000`, INTC en `0xA0005000`). Las pruebas de loopback entre distintos pares de canales —UART 0↔4, UART 0↔3, UART 0↔2, UART 0↔1— resultaron todas correctas sin errores de framing.

```
[TRANSCEIVER DEBUG] Detectados: 5 | Base: 0xA0000000 | INT: 0xA0005000
CMD> 0 HOLA  →  [RX UART 04]: HOLA
CMD> 4 HOLA  →  [RX UART 00]: HOLA
CMD> 0 HOLA  →  [RX UART 03]: HOLA
CMD> 0 HOLA  →  [RX UART 01]: HOLA
```

> **[FIGURA: captura completa del terminal `aocs_testing_rs` disponible en `tfm/terminal/`]**

### Prueba con 13 transceptores simultáneos

Para verificar el correcto funcionamiento del driver con un número elevado de instancias, se cargó un bitstream con 13 transceptores instanciados, conectando los canales adicionales a los pines externos del conector J3 de la ZCU102. El sistema arrancó y operó correctamente con todos los canales, confirmando que la arquitectura de ISR maestra con tareas worker individuales escala sin problemas hasta el número máximo de instancias soportado. La prueba con los 14 transceptores sobre la placa de comunicación serie de diseño propio queda pendiente de fabricación.

## Validación del bus CAN

Las pruebas del bus CAN se realizaron con la aplicación de test desarrollada por Diego Ramos (compañero del laboratorio B105 en el proyecto LINCE), que configura los canales CAN y ejecuta una batería de tests de enlace. La aplicación se cargó sobre una imagen RTEMS generada y validada previamente por él.

La suite de tests ejecutó 26 pruebas cubriendo inicialización, loopback interno, transferencia física CAN0↔CAN1, filtrado de identificadores estándar y extendido, manejo de tramas RTR y pruebas de interrupción por hardware. El resultado fue **26/26 tests PASS, 0 FAILED**:

```
[PASS] CAN0 initialization (Fast Mode)
[PASS] CAN1 initialization (Slow Mode)
[PASS] Loopback RX ID matches TX ID
[PASS] Loopback RX Data matches TX Data
[PASS] CAN0 received correct ID from CAN1        (físico)
[PASS] CAN0 received correct Data from CAN1      (físico)
[PASS] Standard ID: Exact Match Accepted (0x1A4)
[PASS] Extended ID: Exact Match Accepted (0x12345678)
[PASS] RTR Filter: Accepted matching Remote Request
[PASS] TxOk fired successfully
[PASS] RxOk fired and FIFO was drained successfully (No Storm)
... (26/26 PASS, 0 FAILED)
```

> **[FIGURA: captura completa del terminal `cdhs_testing_can.txt` disponible en `tfm/terminal/`]**

Un resultado relevante adicional fue la verificación del efecto de las resistencias de terminación sobre la integridad de la señal CAN. Se realizaron capturas de osciloscopio de la tensión diferencial CAN\_H − CAN\_L con los jumpers desconectados y conectados. Sin terminación, la señal presentaba reflexiones visibles que degradaban los flancos; con ambas resistencias de 60 Ω conectadas, la forma de onda resultó limpia y bien definida.

> **[FIGURA: captura de osciloscopio — señal CAN sin resistencias de terminación]**

> **[FIGURA: captura de osciloscopio — señal CAN con resistencias de terminación]**

## Validación del ADC SPI (termistores CDHS)

La aplicación de lectura del ADC ADS7950 muestreó los cuatro canales a 500 ms de intervalo e imprimió los valores digitales por el terminal. Para verificar la linealidad de la cadena de adquisición se aplicaron tensiones de referencia conocidas a las entradas analógicas:

- Tensión de entrada 0 V → valor digital próximo a 0 (fondo de escala inferior).
- Tensión de entrada 3,3 V → valor digital próximo a 4095 (fondo de escala superior, 12 bits).

Los resultados confirmaron el rango de conversión esperado, validando el driver SPI de bajo nivel y la cadena analógica de la placa CDHS. La captura registra el canal CH2 siendo sometido a un barrido de tensión con la fuente de laboratorio: partiendo de 0 (valor digital ≈ 0), la tensión se elevó progresivamente hasta aproximadamente 2,9 V (valor digital ≈ 3565 sobre 4095), se mantuvo, y se redujo de vuelta a 0, con el ADC siguiendo la rampa en tiempo real. Los canales CH0 (≈245), CH1 (≈43) y CH3 (≈19) mostraron valores estables bajos durante todo el ensayo, correspondientes a las entradas no excitadas.

```
ADS7950: CH0= 244  CH1=  43  CH2=   0  CH3=  19   ← tensión en CH2 = 0V
ADS7950: CH0= 245  CH1=  43  CH2=1577  CH3=  19   ← subida
ADS7950: CH0= 245  CH1=  43  CH2=3419  CH3=  21   ← cerca del máximo
ADS7950: CH0= 245  CH1=  43  CH2=3565  CH3=  21   ← ~2.9V aplicados
ADS7950: CH0= 245  CH1=  43  CH2=2436  CH3=  22   ← bajada
ADS7950: CH0= 246  CH1=  43  CH2= 102  CH3=  22   ← de vuelta a 0V
```

> **[FIGURA: captura completa del terminal `cdhs_testing_adc.txt` disponible en `tfm/terminal/`]**

## Validación PWM (calentadores CDHS y puentes en H AOCS)

Las señales PWM generadas por el bloque `PWMx4_auto_test` se midieron con el osciloscopio sobre el conector J5 de la placa CDHS, verificando los cuatro canales: 10 kHz, 5 kHz, 1 kHz y 100 Hz, todos con duty cycle del 50%.

Para la placa AOCS, el bloque VHDL de control de motores generó señales PWM alternando la dirección de giro cada pocos segundos (línea 1 activa con línea 2 a 0, y a continuación línea 1 a 0 con línea 2 activa), permitiendo verificar el control de puentes en H con una fuente de alimentación externa conectada a los bornes banana.

> **[FIGURA: Captura de osciloscopio — señal PWM medida en el conector J5 de la placa CDHS (frecuencia y duty cycle)]**

> **[FIGURA: Captura de osciloscopio — señales PWM de control de motor (AOCS): par de señales complementarias para control de dirección del puente en H]]**

# conclusiones y líneas futuras

## Conclusiones

El objetivo principal de este trabajo era desarrollar una plataforma funcional de comunicación con periféricos serie sobre el MPSoC Zynq UltraScale+ ZCU102, adaptada a los requisitos del proyecto LINCE. A lo largo del desarrollo he conseguido los siguientes resultados:

El transceptor serie configurable diseñado en VHDL funciona correctamente sobre la lógica programable del ZCU102. Soporta los estándares RS422 y RS485 con configuración completa de protocolo en tiempo de ejecución, y el NCO de 32 bits implementado garantiza un error de baudrate inferior a 20 ppm para la mayoría de las velocidades estándar validadas, desde 9.600 hasta 4.000.000 baudios.

El driver desarrollado para RTEMS abstrae el hardware de forma efectiva y permite gestionar hasta 14 instancias simultáneas del transceptor mediante una arquitectura orientada a interrupciones. La separación entre la ISR maestra y las tareas worker garantiza tiempos de latencia mínimos en la atención de interrupciones, manteniendo el determinismo propio de un sistema de tiempo real.

Las dos tarjetas de circuito impreso diseñadas y fabricadas —la placa CDHS y la placa AOCS— cumplen con las especificaciones impuestas por Indra a través de Sener y han permitido validar el sistema de comunicaciones en un entorno hardware real. La fabricación se realizó en el propio laboratorio mediante proceso de soldadura por reflujo con stencil.

La validación experimental ha confirmado el correcto funcionamiento de las interfaces RS422, RS485 y CAN de la placa CDHS, así como de las interfaces RS422 y RS485 de la placa AOCS. En el caso del bus CAN, se comprobó experimentalmente la importancia de las resistencias de terminación para la integridad de la señal diferencial. El driver SPI del ADC ADS7950 produjo lecturas coherentes con la tensión de entrada aplicada, validando la cadena de adquisición analógica de la placa CDHS.

En conjunto, el trabajo ha servido como contribución directa al proyecto LINCE, proporcionando al laboratorio B105 una base funcional y documentada para el subsistema de comunicaciones del ordenador de a bordo del satélite.

## Líneas futuras

A partir del trabajo realizado, identifico las siguientes líneas de continuación:

**Validación SpaceWire.** La interfaz SpaceWire de la placa AOCS no pudo probarse por falta del arnés micro-D9 adecuado. Completar esta validación es el paso inmediato más relevante, ya que SpaceWire es el protocolo de alta velocidad previsto para los enlaces de mayor ancho de banda del satélite.

**Fabricación y validación de la PCB de diseño propio.** La primera placa diseñada, orientada a la prueba simultánea de múltiples líneas serie con posibilidad de interconexión en buses compartidos, está pendiente de fabricación. Su validación completaría el conjunto de hardware de prueba.

**Aplicación de testing exhaustivo de los 14 transceptores.** El driver soporta hasta 14 instancias simultáneas pero la aplicación de testing actual no las ejercita todas a la vez de forma controlada. Desarrollar una aplicación que pruebe los 14 canales en paralelo, con métricas de throughput y tasa de errores, permitiría caracterizar completamente el rendimiento del sistema.

**Migración a AXI-Stream con transferencia por DMA.** La arquitectura actual del transceptor serie utiliza AXI GPIO como interfaz entre la PS y la PL, lo que implica que la CPU interviene en cada byte transferido. Durante el desarrollo se identificó una alternativa significativamente más eficiente: reemplazar AXI GPIO por **AXI-Stream** para el flujo de datos entre PS y PL, y añadir un controlador **DMA** (*Direct Memory Access*) que mueva los bloques de datos directamente entre la memoria del procesador y la PL sin intervención de la CPU. Esto permitiría que el procesador quede completamente libre durante las transferencias, relegando toda la lógica de serialización y control de protocolo a la FPGA. Esta migración es factible sin comprometer los recursos disponibles: con 14 transceptores instanciados simultáneamente, la utilización de la FPGA se sitúa en torno al 7% de los recursos totales disponibles, dejando margen más que suficiente para absorber la lógica adicional del controlador DMA y los FIFOs AXI-Stream en la PL.

**Integración con el stack de software de vuelo de Sener.** El driver y las PCBs han sido diseñados con los requisitos de Indra/Sener como guía. El siguiente paso natural es la integración del driver en el stack de software de vuelo de Sener y la realización de pruebas de validación conjuntas en entorno Hardware-in-the-Loop.

**Soporte de protocolos adicionales.** La arquitectura modular del transceptor VHDL facilita la incorporación de nuevos modos de operación. Una extensión interesante sería añadir soporte nativo del protocolo MIL-STD-1553, ampliamente utilizado en sistemas espaciales de mayor herencia.

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

