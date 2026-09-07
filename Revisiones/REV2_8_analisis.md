# Rev2.8 — Análisis de qué bajar a los anexos

Criterio del tutor: la memoria no debe leerse como un manual. Baja al anexo el
detalle que, si se borrase, no cambiaría ninguna conclusión del trabajo. Queda en
el cuerpo el resultado, la decisión de diseño y su motivo, más una frase de enlace
con `\ref` al anexo. Es corte y traslado, no reescritura.

Prueba para decidir cada bloque: **¿un lector que solo quiere entender qué se hizo
y por qué necesita esto?** Si la respuesta es «lo necesitaría si tuviera que
repetirlo», es anexo.

**Dos matices que gobiernan toda la pasada:**

1. El objetivo es **la densidad de lectura, no el número de páginas**. Una figura
   a página completa no hace daño: descansa la vista y aporta lo que tiene que
   aportar. Lo que cansa es el párrafo de procedimiento. Se poda prosa densa, no
   figuras.
2. **El anexo no es un vertedero.** Solo baja lo que tenga sentido consultar
   aparte. Un anexo C desbordado es tan mal síntoma como un capítulo 3 denso.

Todo se refiere a `capitulos/cap3/entorno_desarrollo.tex` salvo donde se indique.

## Resumen

| Bloque | Poda | Riesgo |
|---|---|---|
| §3.1.3 Validación del flujo de extremo a extremo (puerta AND) | ~230 líneas | Muy bajo |
| §3.6.1 Aplicación de testing del driver | ~55 líneas | Nulo |
| §3.4 Gestión interna de la transmisión y la recepción | ~80 líneas | Medio |
| §3.5.4 y §3.5.5 Subsistemas menores de las placas CDHS y AOCS | ~70 líneas | Bajo |
| §3.1.1, §3.1.2 y §3.3 (comprimir en el sitio) | ~25 líneas | Nulo |

Poda total en el cuerpo: unas 460 líneas de fuente, del orden de siete u ocho
páginas impresas. **Sin mover ninguna figura.**

## 1. §3.1.3 Validación del flujo de extremo a extremo (líneas 55--346)

292 líneas para un ejemplo cuya conclusión cabe en un párrafo. Reparto interno:

| Parte | Líneas | Qué es |
|---|---|---|
| Motivación y los dos ficheros a producir | 61--77 | Argumento |
| VHDL de la puerta AND | 78--92 | Manual |
| Block Design y figura `block_design_and` | 94--113 | Manual |
| Los seis componentes del BIF con modo y destino | 118--160 | Manual puro |
| Figura `vitis_boot_image` | 162--167 | Manual |
| `and_demo.c` y `mmu_pl_map.c` | 169--181 | Mitad y mitad |
| Tarjeta SD y tabla del conmutador `SW6` | 183--210 | Manual puro |
| Volcado de terminal de la tabla de verdad | 212--232 | Prueba |
| `make_img.sh` y `automate_ymodem_update.py` | 236--263 | Argumento |
| Vitis reutiliza artefactos, plataforma nueva cada vez | 265--277 | Argumento fuerte |
| `generate_boot.sh` | 279--300 | Argumento |

- **Al cuerpo (≈ 60 líneas):** qué se validó y por qué hacía falta un ejemplo
  mínimo antes del transceptor; los dos ficheros que hay que producir (`BOOT.BIN`
  y `rtems.img`); y sobre todo el bloque de automatización, que es una lección
  aprendida y no un procedimiento. **Hay que decir explícitamente que una
  iteración completa llevaba casi una hora de media**, contando síntesis en
  Vivado, plataforma y aplicación nuevas en Vitis, imagen de arranque, compilación
  de RTEMS y copia a la tarjeta. Ese número es lo que justifica los tres scripts y
  lo que explica por qué se invirtió tiempo en automatizar antes de seguir.
  También se queda, en una frase, que sin `mmu_pl_map.c` el primer acceso a los
  GPIO aborta: el mapeado reaparece en §3.6.1 como `mmu_map_pl_axi_early()`.
- **Al anexo C:** el listado VHDL, la lista de componentes del BIF, la secuencia
  numerada de Vitis, la tabla del `SW6` (que es una copia de la UG1182) y el
  volcado de la tabla de verdad. Las figuras `block_design_and` y
  `vitis_boot_image` bajan con el texto que ilustran.

## 2. §3.4 Driver serie en RTEMS (líneas 1003--1230)

Cuatro subsecciones de naturaleza muy distinta.

- **API pública (1003--1039). Se queda.** Seis funciones con una frase cada una.
  Es la cara que ve la aplicación.
- **Interfaz con el hardware (1041--1119). Se queda entera.** Contiene el mapa de
  bits, pero sobre todo el descubrimiento del mapa de direcciones: un AXI GPIO de
  solo lectura en `0xA0020000` publica el número de instancias, el stride y la
  dirección base, con lo que el mismo binario de RTEMS sirve para uno o para
  catorce canales sin recompilar. Eso es aportación, no procedimiento.
- **Gestión interna de la transmisión (1121--1194) y de la recepción
  (1196--1230). Se poda.** Al anexo bajan los tamaños de buffer, los semáforos,
  los nombres de estructuras (`g_instances[]`, `Rx_Worker_Task`) y la figura TikZ
  `driver_camino_datos`.

**Cuidado con el cierre de la recepción.** El último párrafo (líneas 1228--1230),
el que dice que la latencia de interrupción no depende del volumen de datos que
llegue, lo usa la §4.4. Si baja entero, la comparativa de transportes se queda sin
la explicación de por qué la variante GPIO se comporta como se comporta.

Al cuerpo se queda un resumen de dos párrafos: en transmisión la rutina de
interrupción escribe un byte por interrupción, con coste acotado; en recepción se
delega en una tarea ordinaria siguiendo el patrón de procesado diferido de RTEMS;
y de ahí la independencia entre latencia y volumen de datos.

## 3. §3.6.1 Aplicación de testing del driver (líneas 1781--1846)

El caso más limpio, riesgo nulo. Las dos cajas de código son las que el tutor
señala en la p. 54 cuando dice que le tienden a decir poco: seis macros de
`confdefs.h` y el protocolo de comandos de consola. La secuencia de `Init()` en
cinco pasos es documentación de uso, y el ensamblador de líneas por canal
(`AppLineBuffer` de 1024 bytes por cada uno de los catorce canales) es detalle de
implementación de una aplicación de pruebas.

- **Al cuerpo (≈ 10 líneas):** que existe una aplicación de testing, que permite
  enviar por un canal o por todos, y que puede reconfigurar el canal en caliente
  sin reiniciar. La reconfiguración del `slew rate` se menciona **por encima, en
  una frase**: no es un resultado del trabajo, solo la comodidad que hizo cómoda
  la campaña de la §4.3.
- **Al anexo C:** las dos cajas de código y la secuencia de inicialización.

Esto cierra a la vez el punto de la p. 54 de la Rev2.9.

## 4. §3.5.4 y §3.5.5 Placas CDHS y AOCS (líneas 1405--1710)

**Revisión importante respecto a la primera lectura: este bloque no es un manual y
casi todo se queda.** Leído entero, cada subsistema principal lleva una decisión
con su motivo detrás, que es justo lo que el cuerpo tiene que contar:

- El bus CAN con *split termination*, dos resistencias de 60~Ω y el condensador de
  4,7~nF al punto medio, con el argumento EMC.
- El cortocircuito DE--RE de la CDHS, con su motivo operativo (los esclavos solo
  transmiten bajo demanda del OBC) y su consecuencia (el eco en half-duplex).
- Las líneas DE y RE **separadas** en la AOCS, que son el contrapunto directo del
  punto anterior: cortocircuitadas no se puede verificar en banco ninguna otra
  combinación.
- Los puntos de prueba de la revisión V2, que existen porque los caracteres
  corruptos que motivaron los estados `PreDE` y `PostDE` se diagnosticaron
  pinchando el osciloscopio en el lado lógico.
- El error de conexión del eje Z, que ninguna regla de Altium detecta. Es de lo
  mejor del capítulo.
- SpaceWire con repetidores LVDS, *length matching* y 100~Ω diferencial.

**Las hojas de esquemático se quedan donde están.** Que una figura ocupe una
página no hace daño: alivia la lectura en vez de cargarla, y aportan el valor que
tienen que aportar.

Lo único que baja son los subsistemas que se limitan a nombrar componentes sin
ninguna decisión detrás, y solo esos:

- §Subsistema ADC de la CDHS (1545--1551): el ADS7950 por SPI con sus dos carriles.
- §Alimentación de la CDHS (1553--1559): el R-78E5.0 con η ≥ 96~%.
- §Conectores externos de la CDHS (1561--1571): macho o hembra y escudos a GND.
- §Alimentación de la AOCS (1698--1704): dice literalmente que es la misma
  arquitectura que la CDHS, con la sola excepción de los bornes banana, que sí se
  queda arriba.
- §Subsistema PWM de la CDHS (1531--1543): las cuatro frecuencias concretas del
  bloque `PWMx4_auto_test` son detalle de banco. La existencia del bloque
  autónomo, que permite validar el PWM con el mismo `BOOT.BIN` de las pruebas
  serie, se queda.

Son unas 70 líneas. Poco, y esa es la conclusión correcta para este bloque.

## 5. Bloques que se comprimen pero no se mueven

- **§3.1.1 y §3.1.2 (líneas 17--54).** Se quedan: justifican la máquina virtual y
  la compilación de RTEMS desde código fuente (control de la arquitectura AArch64,
  del BSP `zynqmp_apu` y del soporte SMP). Sobra el párrafo de validación con
  QEMU, con `hello.exe` y Dhrystone: dos líneas bastan.
- **§3.3 Generación con TCL (líneas 961--1002).** Sobran los nombres de
  procedimiento y la llamada literal `create_many_transceivers 14
  "zynq_ultra_ps_e_0" "axi_smc"`. Se queda que existen los dos scripts y que
  gracias a ellos no hace falta versionar el proyecto de Vivado entero.

## 6. Bloques que se quedan intactos

- **§3.2 Transmisor y receptor (líneas 426--759).** Es el núcleo del trabajo. Las
  máquinas de estados, el retardo del Driver Enable y la verificación del bit de
  inicio a mitad de período son aportación propia.
- **§3.5.6 Fabricación (líneas 1711--1780).** Corta y con incidencias reales.
- **`capitulos/cap3/transporte.tex` entero.** Las variantes A, B y C sostienen
  directamente la comparativa de la §4.4.

## Orden de ejecución

1. §3.6.1, que es la más limpia y cierra un punto de la Rev2.9.
2. §3.1.3, la de mayor poda.
3. §3.1.1, §3.1.2 y §3.3, que son compresiones en el sitio.
4. Los cinco subsistemas menores de las placas.
5. §3.4, la última por ser la de más riesgo: hay que comprobar que la §4.4 sigue
   teniendo el apoyo que necesita.

## Efecto sobre el anexo C

El anexo C pasaría de 570 a unas 850 líneas. Al hacer el traslado conviene
ordenarlo en tres bloques: primero los mapas y las tablas de referencia
(C.1--C.5), después los detalles de implementación traídos del capítulo 3, y al
final los volcados de terminal.
