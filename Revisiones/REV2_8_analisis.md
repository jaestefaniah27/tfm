# Rev2.8 — Análisis de qué bajar a los anexos

Criterio del tutor: la memoria no debe leerse como un manual. Baja al anexo el
detalle que, si se borrase, no cambiaría ninguna conclusión del trabajo. Queda en
el cuerpo el resultado, la decisión de diseño y su motivo, más una frase de enlace
con `\ref` al anexo. Es corte y traslado, no reescritura.

Prueba para decidir cada bloque: **¿un lector que solo quiere entender qué se hizo
y por qué necesita esto?** Si la respuesta es «lo necesitaría si tuviera que
repetirlo», es anexo.

Todo se refiere a `capitulos/cap3/entorno_desarrollo.tex` salvo donde se indique.

## Resumen

| Bloque | Líneas | Veredicto |
|---|---|---|
| §3.1.3 Validación del flujo de extremo a extremo (puerta AND) | 292 | Bajar casi entero |
| §3.5.4 y §3.5.5 Subsistemas de las placas CDHS y AOCS | 306 | Bajar por subsistema |
| §3.4 Driver RTEMS, gestión interna | 228 | Bajar la mitad interna |
| §3.6.1 Aplicación de testing del driver | 66 | Bajar entero |
| §3.3 Generación con TCL | 42 | Comprimir, no mover |
| §3.1.1 y §3.1.2 Instalación de Vivado, Vitis y RTEMS | 38 | Comprimir, no mover |
| §3.5.6 Fabricación | 70 | Se queda |
| §3.2 Transmisor y receptor | 334 | Se queda |

Poda estimada en el cuerpo: entre 550 y 700 líneas de fuente, del orden de diez a
doce páginas impresas.

## 1. §3.1.3 Validación del flujo de extremo a extremo (líneas 55--346)

Es el bloque más caro del capítulo y el más parecido a un manual: 292 líneas para
un ejemplo cuya única conclusión es que el flujo Vivado → Vitis → SD → RTEMS
funciona. Contiene el VHDL de la puerta AND, la lista de los seis componentes del
fichero BIF con su modo y su destino, el procedimiento de Vitis paso a paso y dos
capturas de pantalla de la herramienta.

- **Al cuerpo (≈ 25 líneas):** qué se validó, por qué hacía falta un ejemplo
  mínimo antes de abordar el transceptor, y los dos ficheros que hay que producir
  (`BOOT.BIN` y `rtems.img`), con la frase de enlace al anexo.
- **Al anexo C:** el listado VHDL, la lista de componentes del BIF, la secuencia
  numerada de Vitis y las figuras `block_design_and` y `vitis_boot_image`.

El argumento de que el orden del BIF no está documentado en un solo sitio de AMD
es bueno, pero es exactamente el argumento de un anexo: tiene valor de referencia,
no de narración.

## 2. §3.5.4 y §3.5.5 Subsistemas de las placas CDHS y AOCS (líneas 1405--1710)

Cada placa se recorre subsistema a subsistema con referencias de fabricante, pines
y jumpers. Hay dos capas mezcladas y conviene separarlas.

- **Al cuerpo:** el diagrama de bloques de cada placa, la restricción de 1,8~V, la
  elección del THVD1424 frente al LTC2865 y las decisiones que tienen un motivo de
  ingeniería detrás. El cortocircuito DE--RE es el mejor ejemplo de lo que **debe
  quedarse**: hay una decisión, un motivo operativo (los esclavos solo transmiten
  bajo demanda del OBC) y una consecuencia (el eco en half-duplex).
- **Al anexo C:** las referencias exactas de los componentes, el reparto de pines
  por conector, las hojas de esquemático a página completa y los detalles de
  alimentación y de conectores externos. El mapa de señales ya vive en C.2 y C.3,
  así que el destino existe y solo hay que ampliarlo.

Los subsistemas PWM y ADC son los candidatos más claros dentro de este bloque: son
periféricos secundarios del trabajo y se describen con el mismo detalle que los
serie, que sí son el objeto de la memoria.

## 3. §3.4 Driver serie en RTEMS (líneas 1003--1230)

La sección se declara a sí misma como prueba de concepto sin requisitos impuestos
y aun así ocupa 228 líneas. La API pública y el mapa de registros sostienen el
argumento del capítulo. «Gestión interna de la transmisión» y «Gestión interna de
la recepción» (líneas 1121--1230) describen mecánica de implementación que ninguna
conclusión utiliza.

- **Al cuerpo:** la API pública y el mapa de registros, más un párrafo que diga
  cómo se evita bloquear al procesador.
- **Al anexo C:** el detalle de las dos gestiones internas, junto a C.6, que ya
  recoge la descripción RTL del registro de desplazamiento y la FIFO.

## 4. §3.6.1 Aplicación de testing del driver (líneas 1781--1846)

Las dos cajas de código, las macros de `confdefs.h` y el protocolo de comandos de
consola, son las que el tutor señala en la p. 54 cuando dice que le tienden a
decir poco. La secuencia de arranque de `Init()` en cinco pasos es documentación
de uso.

- **Al cuerpo (≈ 10 líneas):** que existe una aplicación de testing, que permite
  enviar por un canal o por todos, y que reconfigura el slew rate en caliente sin
  reiniciar. Esto último sí importa, porque es lo que hace posible la campaña de
  la §4.3.
- **Al anexo C:** las dos cajas de código y la secuencia de inicialización.

Esto cierra a la vez el punto de la p. 54 de la Rev2.9.

## 5. Bloques que se comprimen pero no se mueven

- **§3.1.1 y §3.1.2 (líneas 17--54).** Solo 38 líneas, y justifican la máquina
  virtual y la compilación de RTEMS desde código fuente, que es una decisión con
  motivo. Sobra la validación con QEMU (`hello.exe` y Dhrystone), que puede quedar
  en una frase.
- **§3.3 Generación con TCL (líneas 961--1002).** La existencia de los dos scripts
  y la reproducibilidad del proyecto son argumento; los nombres de procedimiento y
  la llamada concreta con sus catorce instancias son referencia. Se comprime a un
  párrafo con el enlace al repositorio, que ya está citado.

## 6. Bloques que se quedan como están

- **§3.2 Transmisor y receptor (líneas 426--759).** Es el núcleo del trabajo. Las
  máquinas de estados, el retardo del Driver Enable y la verificación del bit de
  inicio a mitad de período son aportación propia, no procedimiento.
- **§3.5.6 Fabricación (líneas 1711--1780).** Corta y con incidencias reales.
- **`capitulos/cap3/transporte.tex` entero.** Las variantes A, B y C sostienen
  directamente la comparativa de la §4.4. No tocar.

## Efecto sobre el anexo C

El anexo C pasaría de 570 a unas 900 líneas. Conviene reordenarlo en dos bloques
al hacer el traslado: primero los mapas y tablas de referencia (C.1--C.5), después
los detalles de implementación trasladados desde el capítulo 3, y al final los
volcados de terminal.

## Pendiente de confirmación

Marcar en la lista de la Rev2.8 del plan qué bloques entran. El análisis propone
empezar por los cuatro primeros, que dan la mayor parte de la poda con el menor
riesgo de romper el hilo del capítulo.
