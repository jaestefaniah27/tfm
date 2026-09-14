# Informe de terminologia y ortografia (pasada 2)

Texto extraido de `Terminologia y ortografia del TFM.html`, cuyo contenido real
vive en `Terminologia y ortografia del TFM_files/saved_resource.html` y no se ve
abriendo el HTML de fuera. Se conserva aqui en plano para no tener que volver a
extraerlo.

---
 
Terminología y ortografía del TFM 
Pasada 2 · Ortografía y terminología
Terminología y ortografía del TFM
Casi todo esto se aplica con buscar-y-reemplazar. Las cursivas y las comillas están comprobadas en las fuentes del PDF, no supuestas : sé exactamente qué palabra va en CMTI y cuál en redonda, así que las cifras de abajo son medidas, no impresiones.
Localización · «p. 45» es el folio impreso; la página del visor es folio + 17.
Alcance · quedan fuera los listados de código, los volcados de terminal, los rótulos de esquemático y la bibliografía, donde el inglés y las erratas del propio log son legítimos.
Retirado · Alvaro Araujo sin tilde, por indicación tuya.
A · Tabla de decisiones terminológicas 10 decisiones 
Ninguna de estas variantes es un error: el problema es que conviven. La columna «adoptar» es mi recomendación, casi siempre la mayoritaria, para minimizar los cambios. La última columna dice dónde están las que hay que tocar.
Formas conviviendo · recuento sobre el cuerpo del documento 
Adoptar
Sustituir
Cambios
Páginas afectadas
Por qué
RS422 · RS485
RS-422 · RS-485
27
39×2, 40×2, 62, 67, 68, 83×5, 85, 87×5, 89×3, 91, 92×3, 101×2
132 sin guion frente a 27 con guion, y las Palabras Clave ya van sin guion. Conviven incluso en la tabla 4.9.
transceptor
transceiver
15
34×6, 54×2, 57, 61
129 frente a 15. Uno de los 15 es el título del apartado 3.3.1, «Generación de transceivers con TCL».
baudios · Mbaudios
kbps · Mbps
~32
84×6, 85×12, 86×7, 89×4, 90×2 (salvo citas del datasheet) 
El §4.3.2 mide en baudios y el §4.3.3 lo mismo en Mbps; la p. 86 usa las dos, y las conclusiones alternan. Excepción legítima: los límites del LTC2865 (250 kbps, 20 Mbps) van como los da la hoja de características.
BOOT.BIN
BOOT.bin
9
15, 16, 17, 18×2, 21, 55, 66
Es el nombre real del fichero en la FAT. Ahora 4 en mayúsculas y 9 en minúsculas.
Data-Strobe
data-strobe
2
56, 90
Es como lo escribe el estándar ECSS.
half-duplex
Half-Duplex
5
44×4, 45
Minúscula en prosa. Excepción: cuando nombras el jumper H/F del THVD1424, ahí va como lo serigrafía el fabricante.
NewSpace
New Space
1
38
3 frente a 1.
AMD (declarando el cambio) 
Xilinx suelto
—
Xilinx: 5, 6×2, 12, 15, 17, 18×2, 31, 61, 100 · AMD: 5, 6, 15
Se alternan sin criterio. Basta una frase en §2.2 («Xilinx, hoy AMD; en adelante AMD») y luego una sola forma. Los nombres de IP y las guías ( axi_dma , PG021) se quedan como los publica el fabricante, y la bibliografía como esté en la fuente.
«Consultado en»
«Recuperado el»
2
92×2 (bibliografía) 
4 frente a 2, en el mismo .bib .
una sola grafía de LINCE
tres grafías
2
1, 5, lista de acrónimos
«Línea de IN dustrialización de C argas de pago y plataformas E spaciales» (p. 1), «Línea de industrialización de cargas de pago y plataformas espaciales» (p. 5 y lista). Las mayúsculas que explican el acrónimo están bien, pero entonces van en las tres.
B · Cursivas comprobadas en las fuentes del PDF 
He separado el texto por familia tipográfica: CMTI/CMBXTI es cursiva, CMR es redonda, CMTT es código y queda fuera. 554 fragmentos en cursiva en 96 páginas.
buena noticia 
El criterio existe y en su mayor parte está bien aplicado
36 extranjerismos van siempre en cursiva y nunca en redonda: bitstream (25), loopback (23), throughput (17), testbench (14), jumper / jumpers (22), worker (9), ring (8), half-duplex (6), master/slave (6), stencil (5), toolchain (4), duty cycle , handshake , skew , preset , wizard , scoreboard , multi-drop , polling , store-and-forward , datasheet , rad-hard , wired-AND … Eso es una política, no una casualidad.
Y hay una segunda política implícita, también defendible: cursiva en la primera aparición, redonda después , aplicada a las palabras ya asentadas en castellano — driver (5 cursivas de 151), hardware (4 de 70), firmware (3 de 22).
Declararla. Una frase en §1.4 o en la lista de acrónimos: «Los términos ingleses sin equivalente asentado se marcan en cursiva; los ya incorporados al uso técnico ( hardware , software , driver , firmware ) se marcan solo en su primera aparición». Con eso, lo que ahora parece descuido pasa a ser criterio, y solo hay que corregir los casos de abajo. 
corregir 
Siete términos cambian de estilo dentro de la misma página
Estos no encajan ni en la política de «siempre cursiva» ni en la de «solo la primera vez», porque el mismo término aparece de las dos formas en la misma página:
p. 81 frames en cursiva dos veces y en redonda dos veces, en la misma página ; frame , en cursiva en la p. 79 y en redonda en las pp. 68 y 81. 
pp. 12, 13, 59, 63 stream : 12 cursivas y 21 redondas, mezcladas en las cuatro páginas. 
pp. 13, 63, 64 buffer : 23 cursivas y 9 redondas; las nueve redondas caen en páginas que también lo llevan en cursiva. 
p. 85 slew rate : 10 cursivas y 2 redondas, y la p. 85 tiene una de cada. 
p. 3 sprint y backlog : en cursiva en la p. 2 y en las dos formas dentro de la p. 3. 
p. 9 full-duplex : cursiva en las pp. 8, 10, 44 y 49; redonda solo en la p. 9. 
— software nunca va en cursiva (39 apariciones) mientras que hardware sí lo hace cuatro veces. Van en pareja o no van. 
Falso positivo que no hay que tocar: livelock , benchmark y routers aparecen en redonda en las pp. 92–93, pero eso es la bibliografía —títulos de Mogul y Ramakrishnan, de Dhrystone y del estándar SpaceWire— y ahí van como en el original.
C · Comillas 1 punto, 6 apariciones 
crítico 
p. 66 · pdf 83  |  p. 85 · pdf 102 (×2)  |  p. 89 · pdf 106 
Las comillas del documento no son comillas: son los símbolos matemáticos ≪ y ≫
Las seis comillas angulares del TFM están compuestas con la fuente CMSY6 —Computer Modern Symbol a 6 puntos—, es decir, con $\ll$ y $\gg$ , los operadores «mucho menor que» y «mucho mayor que». No son « ni » . Se ven más pequeñas, con el espaciado de un operador matemático a los dos lados, y al copiar el PDF salen como U+226A y U+226B, no como comillas.
No hay ninguna otra comilla en el documento: cero « » , cero “ ” . Las seis son estas.
p. 66 el estado de FIFO vacía · se manifestaba como todo el tráfico acaba en el canal cero 
p. 85 distinguir el transporte no llegó a transmitir de el bus corrompió los bytes · y la cita del datasheet del LTC2865 
p. 89 la macro se llama SLO desactivado 
Con babel en español y codificación T1, escribir «…» directamente, o usar \enquote{} de csquotes , que además elige el nivel de anidamiento. La cita del LTC2865 de la p. 85 es un caso aparte: son tres líneas en inglés de una fuente citada, y gana como quote sangrado (o quotation ), sin comillas, con la referencia [23] al final.
D · Números y unidades 4 puntos 
corregir 
pp. 22, 88, 90 
Tres números usan el punto como separador de millares; los otros 140 usan espacio fino
p. 22 desde 50 hasta 4.000.000 baudios → 4 000 000 
p. 88 velocidad entre 50 y 4.000.000 de baudios → 4 000 000 
p. 90 el trabajo ha producido 20.188 líneas de código → 20 188 
Espacio fino en los tres ( \, o siunitx ). El resto del documento ya lo hace bien: 140 apariciones con espacio fino, 81 decimales con coma. Es el criterio del SI y el que pide la RAE.
corregir 
p. 100 · tabla 5.1  |  p. 43 · figura 3.8 
Dos porcentajes van pegados al número, contra 39 que llevan espacio
En la tabla del presupuesto conviven 15 % y 6% en filas consecutivas. En la figura 3.8, η ≥ 96% .
Espacio fino antes del signo, como el resto. Es el uso correcto en español y en el SI.
verificar 
p. 80 · tablas 4.6 y 4.5 
Las cabeceras de la tabla 4.6 escriben las velocidades sin separador
115200 · 230400 · 460800 · 921600 · 1M · 2M · 4M , mientras que la prosa de la misma página escribe «115 200». Y dentro de la propia cabecera se mezclan dos notaciones: cifras completas para las cuatro primeras y sufijo M para las tres últimas.
Unificar a espacio fino, o dejar la cabecera compacta y decir en el pie que las velocidades están en baudios. Lo que no conviene es tener las dos notaciones dentro de la misma fila.
corregir 
Espacio fino no separable en las magnitudes
Repasar que todas van con \, y ninguna se parte al final de línea: 1,8 V 120 Ω 100 µs 460 kbps 3,52 W 32 bits 4,7 nF ±2 % 120 ppm . Con siunitx ( \SI{1,8}{\volt} ) sale solo y de paso unifica el decimal.
E · Lista de acrónimos 23 ausencias + 1 sobrante 
La lista tiene 78 entradas y está bien hecha. Faltan estas, ordenadas por número de usos en el cuerpo. La columna «1.ª vez» es dónde habría que definirla también en el texto.
Sigla
Usos
1.ª vez
Desarrollo propuesto
TDEST
20
p. 11
Transfer Destination — señal de AXI4-Stream que identifica el canal de destino.
TLAST
13
p. 11
Transfer Last — marca de fin de paquete en AXI4-Stream.
BER
8
p. 84
Está en la lista, pero se usa 8 veces sin volver a definirse; conviene desarrollarla también en su primera aparición del capítulo 4.
RTL
5
p. 4
Register Transfer Level — nivel de descripción del hardware. Aparece ya en el título del anexo C.
TVALID / TREADY
5 / 5
p. 11
Definidas en una nota al pie de la p. 11, pero no en la lista.
SPW
5
p. 39
Abreviatura de SpaceWire usada en el rutado y en los esquemáticos.
HPC
3
p. 6
High Pin Count — variante del conector FMC. Se define en el texto pero no en la lista.
HP
3
p. 11
High Performance — puertos AXI del PS. Se confunde fácilmente con HPC y en el documento aparecen a dos páginas de distancia.
BIF
3
p. 17
Boot Image Format — fichero que describe el orden de la imagen de arranque.
SMP
2
p. 15
Symmetric Multiprocessing — multiprocesamiento simétrico.
SAR
2
p. 43
Successive Approximation Register — arquitectura del ADC ADS7950.
TVS
2
p. 40
Está en la lista; solo falta desarrollarla en su primera aparición.
WNS
2
p. 77
Ídem: en la lista, sin desarrollar en la tabla 4.1 donde es una columna.
SG
2
p. 12
Ídem.
RSB · EMC · LDO · CRC · IDE · GUI · QEMU · PYMES · MMIO
1 c/u
15–96
Un uso cada una. O se desarrollan en el sitio, o se sustituyen por su nombre completo y desaparece el problema.
Y al revés: SLO está en la lista de acrónimos y no es un acrónimo — la entrada dice «Pin de los transceptores LTC2865 que habilita el limitador de velocidad de flanco, activo a nivel bajo». O la sección se titula «Lista de acrónimos y glosario» y se admiten entradas así, o SLO baja al texto, donde ya está explicado en §3.4.2 y §4.3.3.
F · Rótulos y numeración 3 puntos 
corregir 
los 9 listados de código 
«Programación 3.1» no es el rótulo de un listado
«Programación» nombra la actividad, no el objeto. En castellano un listado de código se rotula Listado , Código o Programa , y el índice correspondiente, «Índice de listados».
\renewcommand{\lstlistingname}{Listado} y \renewcommand{\lstlistlistingname}{Índice de listados} . Una línea en el preámbulo y cambia en los nueve sitios.
corregir 
p. 108 y siguientes 
Los listados de los anexos también arrastran el contador del capítulo 5
«Programación 5.1» y «Programación 5.2» en el anexo C, igual que las tablas 5.1–5.6 que ya salieron en la pasada anterior. Es el mismo \appendix ausente, así que se arreglan de una vez.
verificar 
índice · pdf 9 
El índice numera los preliminares en romanos mayúsculos y las páginas van en minúsculos
El índice dice Resumen y Palabras Clave II , Agradecimientos IV , Lista de acrónimos X . Las páginas correspondientes llevan impreso iii , iv , x … en minúscula. Además el número del índice y el folio real no siempre coinciden: el resumen empieza en la ii y el índice dice II, pero la lista de acrónimos empieza en la x y ocupa hasta la xiii .
Un \pagenumbering{roman} en minúscula antes del \frontmatter , o quitar la mayúscula donde se genera la entrada. Es de esas cosas que solo se ven al mirar el índice y la página a la vez.
G · Ortografía y gramática 5 puntos 
Pasado el corrector con el diccionario es_ES sobre las 5 280 palabras distintas del documento, descontando listados, volcados de terminal, esquemáticos y bibliografía. El cuerpo técnico sale limpio. Todo lo que queda está en el capítulo 3 y en los agradecimientos.
crítico 
pp. 23, 24, 25 (×3), 29, 30 
«semiperiodo» sin tilde, siete veces, frente a «período» con tilde
El documento escribe período con tilde cinco veces (pp. 23, 28, 70) y semiperiodo/semiperiodos sin tilde las siete. Ambas acentuaciones son válidas en español — periodo y período —, pero hay que elegir una, y la palabra compuesta tiene que seguir a la simple. Hay además un por periodo de bit sin tilde en la p. 9.
Como ya usas «período», quedan semiperíodo y semiperíodos , y la p. 9 pasa a «por período de bit». Ocho cambios en total y el criterio queda cerrado. La alternativa (todo sin tilde) son solo seis cambios, pero «período» es la forma que domina en el texto.
crítico 
agradecimientos · p. iv · pdf 8 
«exámenes» aparece bien la primera vez y mal la segunda, en el mismo párrafo
La de exámenes que hemos salvado en el último momento gracias a las explicaciones en pizarra de Eugenio. […] Las largas horas de estudio con Javier, los examenes sacados en un día…
La segunda, con tilde. Que la primera esté bien es lo que prueba que es una errata y no una decisión.
crítico 
agradecimientos · p. iv · pdf 8 
Paralelismo roto en la enumeración del B105
Formar parte del B105 ha sido excepcional, he podido disfrutar del buen rollo, empaparme del conocimiento sobre todos vuestros trabajos, y contado con vuestra ayuda y consejo en todo momento…
Los tres términos cuelgan de «he podido»: disfrutar , empaparme y… contado , que es participio y no encaja.
«…he podido disfrutar del buen rollo, empaparme del conocimiento sobre todos vuestros trabajos y contar con vuestra ayuda y consejo en todo momento…». De paso, la coma antes de la «y» sobra en una enumeración de tres.
corregir 
agradecimientos · p. iv · pdf 8 
Dos detalles menores más en el mismo texto
régimen Gracias a todos los que han participado de este desarrollo → participar en . «Participar de» significa compartir una opinión o una cualidad, no tomar parte. 
repetición Al resto de compañeros del laboratorio , por hacer del laboratorio algo más que un lugar de trabajo → «…por hacer de él algo más que un lugar de trabajo». 
Lo que no toco: «las cerves», «el buen rollo», «ser mopa oficial vistiendo de blanco» y el salto de la tercera a la segunda persona con Dani. Son unos agradecimientos y el registro coloquial es suyo; solo lo señalo por si prefiere uniformar el trato.
falsos positivos 
Lo que el corrector marca y no hay que tocar
Para que no te hagan dudar cuando pases tu propio corrector: Configuracion , Envia , Inyeccion , tambien , tension , maximo , fisico , unico , semaforos , via están todos dentro de listados de código o de volcados de terminal; Revision , Master , Duplex son rótulos de esquemático de Altium; caracterizacion y comunicacion son nombres de directorio del repositorio; eXtensible , areas y expansion son inglés (el desarrollo de AXI y el Summary ).
Aparte: los mensajes de la propia aplicación llevan las tildes sin poner — Envia 'Hola' por UART 0 , Configuracion : 9600 —. En la memoria van tal cual, porque es lo que imprime el programa, pero si algún día se tocan esas cadenas, ahí están.
H · Summary en inglés 2 puntos 
p. ii The boards connect to it in order to extend its capabilities and widen the development window . Traducción literal de «ampliar la ventana de desarrollo», que en inglés no significa nada reconocible — window se lee como ventana temporal. Propuesta: …to extend its capabilities and broaden the range of interfaces that can be developed and tested on it . 
p. ii CAN, PWM, analogue and SpaceWire interfaces . Ortografía británica en un texto que por lo demás no marca variedad. Es válida, pero conviene decidirla y aplicarla en todo el Summary y en las Keywords . 
I · Comprobado y limpio no hace falta repasarlo 
Comprobación
Resultado
Corrector es_ES sobre 5 280 palabras distintas
solo las erratas del bloque G; el cuerpo técnico, limpio
«en base a», «dicho/dicha», «a nivel de»
0, 0 y 1 — prácticamente ausentes
«el mismo / la misma» como pronombre
2 en 90 páginas
Decimales con coma
81 en el cuerpo, ninguno con punto fuera de listados
Separador de millares
140 con espacio fino frente a los 3 del bloque D
Porcentajes con espacio
39 correctos frente a los 2 del bloque D
Cursiva de extranjerismos
36 términos con criterio constante; 7 con mezcla
Nombres de fichero, IP y rutas del repositorio
consistentes entre capítulos
Siguiente
Alcance : qué se poda del cuerpo y qué se va a los anexos. Es la pasada que más tiempo lleva y la que más mueve, con el §3.1 y las cinco hojas de esquemático a página completa como candidatos principales. Y detrás, el hilo — donde, como pediste, la ordenación temporal la dejo señalada y sin insistir, porque en un trabajo que se desarrolló por sprints el orden cronológico puede tener razones que la memoria no cuenta pero tú sí conoces.
Las cursivas salen de separar el texto del PDF por familia tipográfica (CMTI/CMBXTI frente a CMR), las comillas de identificar la fuente glifo a glifo, y la ortografía de pasar hunspell con el diccionario es_ES sobre el vocabulario del documento, excluyendo bibliografía. Los recuentos son medidos; las páginas son folios impresos.
