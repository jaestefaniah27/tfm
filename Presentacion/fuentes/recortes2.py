# -*- coding: utf-8 -*-
"""Segunda tanda de recortes del guion, para volver a los 17 minutos.

El mazo creció al separar las variantes, meter RTEMS y poner portadillas, así
que el guion hablado se fue a casi 20 minutos. Se recorta sobre todo en las
diapositivas de foto, donde la imagen ya cuenta la mitad de lo que se decía.
"""

RECORTES2 = [
    # ---------------------------------------------------------- fotos
    ("Así quedó la placa de comunicación serie. Catorce transceptores LTC2865 "
     "y, en la cara de conectores, la fila de jumpers: cada driver tiene un "
     "conector Dupont de tres pines, y un jumper entre dos consecutivos une sus "
     "líneas A y B. Eso permite repartir los siete drivers RS485 en cualquier "
     "combinación de buses sin tocar el firmware ni el cableado.",
     "Catorce transceptores LTC2865. Cada driver tiene un conector Dupont de "
     "tres pines, y un jumper entre dos consecutivos une sus líneas A y B: eso "
     "reparte los siete drivers RS485 en cualquier combinación de buses sin "
     "tocar firmware ni cableado."),

    ("Para validar hubo que fabricar los arneses. El de RS422 lleva cuatro "
     "hilos y cruza transmisión con recepción; el de RS485, dos hilos entre "
     "drivers; el de CAN cruza el bus nominal con el redundante en el mismo "
     "conector. Con ellos se cierra cada bus sobre sí mismo y se mide sobre "
     "cobre de verdad.",
     "Hubo que fabricar los arneses: RS422 cruza transmisión con recepción, "
     "RS485 va entre drivers y el de CAN cruza el bus nominal con el "
     "redundante. Cierran cada bus sobre sí mismo para medir sobre cobre real."),

    ("Aquí se ve por qué la terminación importa. Arriba, sin terminar: las "
     "reflexiones deforman cada flanco. Abajo, con la terminación split de "
     "sesenta más sesenta ohmios, la señal queda limpia. Cada resistencia lleva "
     "su propio jumper, así que la placa permite ensayar el bus terminado en un "
     "extremo, en los dos o en ninguno.",
     "Arriba, sin terminar: las reflexiones deforman cada flanco. Abajo, con "
     "los sesenta más sesenta ohmios, la señal queda limpia. Cada resistencia "
     "lleva su jumper, así que se puede ensayar el bus terminado en un extremo, "
     "en los dos o en ninguno."),

    ("Las salidas PWM. En CDHS, los cuatro canales de calentadores se "
     "ejercitaron a diez, cinco y un kilohercio y a cien hercios, todos al "
     "cincuenta por ciento. En AOCS, el control de motores alterna el sentido "
     "de giro en los tres ejes. Aquí se detectó el error del eje Z, que era de "
     "placa y no de firmware, corregido en la revisión V2.",
     "Los cuatro canales de calentadores, a diez, cinco y un kilohercio y a "
     "cien hercios. En AOCS el control de motores alterna el sentido de giro. "
     "Aquí se detectó el error del eje Z, que era de placa y no de firmware."),

    ("Y este es el montaje de la campaña eléctrica: la placa serie sobre el "
     "FMC, con los catorce transceptores ejercitándose a la vez. Los jumpers "
     "están puestos para formar tres buses: el A, RS485 multipunto de siete "
     "nodos, y el B y el C, RS422 en estrella.",
     "El montaje de la campaña eléctrica: los catorce transceptores a la vez, "
     "con los jumpers formando tres buses. El A, RS485 de siete nodos; el B y "
     "el C, RS422 en estrella."),

    ("Y esto es lo que hace el limitador sobre el flanco. Sin él, la transición "
     "dura unas pocas decenas de nanosegundos; con él, cerca de un cuarto de "
     "microsegundo, casi un orden de magnitud más. Fijaos en las bases de "
     "tiempo: veinte nanosegundos por división a la izquierda, cien a la "
     "derecha. Eso reduce emisiones radiadas, pero es exactamente lo que fijaba "
     "el techo de velocidad de la placa.",
     "Sin limitador, la transición dura decenas de nanosegundos; con él, cerca "
     "de un cuarto de microsegundo. Fijaos en las bases de tiempo: veinte "
     "nanosegundos por división a la izquierda, cien a la derecha."),

    ("Esta es la tarjeta: cuatro núcleos ARM y una matriz de lógica programable "
     "en el mismo chip. Los dos conectores FMC de la izquierda exponen los "
     "pines diferenciales de la FPGA, y por ahí entran las tres placas que "
     "diseñé.",
     "Cuatro núcleos ARM y una matriz de lógica programable en el mismo chip. "
     "Los conectores FMC de la izquierda exponen los pines de la FPGA: por ahí "
     "entran las placas."),

    ("Este es el banco completo: la ZCU102 con la placa CDHS sobre el conector "
     "FMC HPC0. Solo cabe una placa de expansión a la vez, así que la "
     "validación se hizo placa por placa.",
     "El banco completo, con la placa CDHS sobre el FMC. Solo cabe una placa de "
     "expansión a la vez, así que la validación se hizo placa por placa."),

    ("El montaje se hizo en el laboratorio: pasta con el stencil alineado, "
     "colocación con pinzas y horno de reflujo. Seis unidades, dos de cada "
     "diseño, y ninguna necesitó retrabajo de fabricación.",
     "Montaje en el laboratorio: stencil, pasta, pinzas y horno de reflujo. "
     "Seis unidades, dos de cada diseño, sin retrabajos."),

    ("Reserva: RS485 es un bus compartido, hasta treinta y dos transceptores, "
     "half-duplex sobre dos hilos, con el control de dirección en software y "
     "terminación de ciento veinte ohmios en los dos extremos. Solo un nodo "
     "transmite a la vez, y por eso el bus A satura antes que los otros dos.",
     "RS485: bus compartido, half-duplex sobre dos hilos, control de dirección "
     "en software y terminación en los dos extremos. Solo un nodo transmite a "
     "la vez, y por eso el bus A satura antes."),

    ("Y RS422 es punto a punto, full-duplex continuo sobre cuatro hilos, con un "
     "único transmisor por par: no hace falta compartir el medio ni arbitrar, "
     "así que llega más lejos en velocidad. Son los buses B y C de la placa "
     "serie.",
     "RS422: punto a punto, full-duplex sobre cuatro hilos, un transmisor por "
     "par. Sin medio compartido ni arbitraje, llega más lejos en velocidad."),

    # ---------------------------------------------------------- contenido
    ("Antes del driver conviene decir qué es RTEMS, porque condiciona el "
     "diseño. Es un sistema operativo de tiempo real de código abierto, "
     "estándar de facto en la industria aeroespacial: lo usan la ESA y la NASA. "
     "La característica que importa es que no tiene memoria virtual: un solo "
     "espacio de direcciones físico, un proceso y varios hilos. Eso da "
     "latencias de interrupción muy bajas y deterministas, que es lo que pide "
     "un ordenador de a bordo. El precio es que no hay driver hecho para "
     "periféricos propios: control total, pero hay que escribirlo todo desde el "
     "registro.",
     "Conviene decir qué es RTEMS, porque condiciona el diseño. Sistema "
     "operativo de tiempo real, estándar de facto en la industria aeroespacial. "
     "Lo que importa: no tiene memoria virtual, así que la latencia de "
     "interrupción es baja y determinista. El precio es que no hay driver hecho "
     "para periféricos propios."),

    ("Con catorce canales, lo que limita el rendimiento es el camino que "
     "recorren los bytes entre la memoria y la lógica programable. Una "
     "interrupción cuesta del orden de microsegundos, y ese coste es casi "
     "constante: da igual que mueva un byte o mil. Si se interrumpe una vez por "
     "byte, al subir la velocidad el tiempo entre bytes baja pero el coste de "
     "la interrupción no, así que aparece un umbral de saturación, y con "
     "catorce enlaces llega catorce veces antes. Es lo que Mogul y Ramakrishnan "
     "llamaron interrupt livelock. La salida no es optimizar la rutina: es "
     "interrumpir por paquete en lugar de por byte, es decir, usar DMA.",
     "Con catorce canales, lo que limita el rendimiento es el camino de los "
     "bytes entre memoria y FPGA. Una interrupción cuesta microsegundos, y ese "
     "coste no depende de los bytes que mueva. Interrumpiendo una vez por byte "
     "aparece un umbral de saturación, y con catorce enlaces llega catorce "
     "veces antes. La salida es interrumpir por paquete: DMA."),

    ("La variante A es la de partida: un AXI GPIO por canal sobre el bus "
     "AXI-Lite, y el procesador escribiendo y leyendo byte a byte. Es la más "
     "sencilla y la que menos lógica ocupa, cuatrocientas sesenta LUT por "
     "canal. El defecto es estructural: la CPU toca cada byte, así que son mil "
     "doscientas cincuenta interrupciones por kilobyte y el caudal se queda en "
     "el treinta por ciento del techo físico, sin mejorar aunque se suba la "
     "velocidad de línea.",
     "La A es la de partida: un AXI GPIO por canal, y el procesador leyendo "
     "y escribiendo esos registros por AXI-Lite. Aquí no hay ningún maestro "
     "que toque la memoria: el dato pasa siempre por la CPU. Es la más "
     "ligera, cuatrocientas sesenta LUT por canal, pero el defecto es "
     "estructural: mil doscientas cincuenta interrupciones por kilobyte, y "
     "se queda en el treinta por ciento del techo."),

    ("La variante B saca a la CPU del camino de datos poniendo un motor DMA "
     "completo por canal. Funciona, y el coste en interrupciones se desploma. "
     "Pero replicar el motor catorce veces cuesta dos mil ochocientas setenta y "
     "tres LUT por canal, casi siete veces la huella de GPIO. Y hay un límite "
     "duro que no depende del diseño: cada AXI DMA expone dos líneas de "
     "interrupción, catorce motores son veintiocho líneas, y el procesador solo "
     "ofrece ocho.",
     "La B saca a la CPU del camino de datos con un motor DMA por canal. "
     "Funciona, pero replicarlo catorce veces cuesta casi siete veces la huella "
     "de GPIO. Y hay un límite duro: cada DMA expone dos líneas de "
     "interrupción, catorce son veintiocho, y el procesador ofrece ocho."),

    ("Dentro del puente, el reparto es asimétrico por una razón física. En "
     "transmisión basta un canal: el destino viaja en el propio dato, en una "
     "cabecera de dos bytes que el router lee. En recepción hacen falta "
     "catorce, porque cada UART habla cuando quiere y necesita su propio buffer "
     "en memoria. Quien decide a qué buffer va cada paquete es la señal TDEST: "
     "el bloque de drenado etiqueta cada paquete con su canal de origen. Sin "
     "esa etiqueta todo cae en el canal cero, que fue exactamente el síntoma "
     "que vimos en placa.",
     "El reparto es asimétrico por una razón física. En transmisión basta un "
     "canal: el destino viaja en el dato, en una cabecera de dos bytes. En "
     "recepción hacen falta catorce, porque cada UART habla cuando quiere. "
     "Quien decide el buffer es TDEST; sin esa etiqueta todo cae en el canal "
     "cero, que fue el síntoma en placa."),

    ("La selección de componentes quedó condicionada por una restricción: los "
     "bancos de entrada y salida del conector FMC operan a 1,8 voltios, así que "
     "todo lo que se conecte directamente tiene que admitir esa tensión. Se "
     "buscó herencia de vuelo en catálogo y el resultado fue negativo: los "
     "transceptores con herencia de vuelo son de una generación anterior, con "
     "interfaz a 3,3 o 5 voltios, y ninguno opera a 1,8. Se recurrió a grado "
     "automotriz, AEC-Q100. Esto se declara explícitamente en la memoria: estas "
     "tarjetas son hardware de validación funcional, no modelo de vuelo.",
     "La selección quedó condicionada por una restricción: los bancos del FMC "
     "operan a 1,8 voltios. Busqué herencia de vuelo en catálogo y el resultado "
     "fue cero: los que la tienen son de generación anterior, a 3,3 o 5 "
     "voltios. Se recurrió a grado automotriz. En la memoria se declara "
     "explícitamente: hardware de validación funcional, no modelo de vuelo."),

    ("Y llegamos a la comparativa de los tres transportes. Los buses se cierran "
     "dentro de la propia FPGA, con un módulo de loopback que reproduce la "
     "topología de la PCB: así se mide el coste del transporte y no la capa "
     "física. Esta es la gráfica clave del trabajo: GPIO se satura. Multiplicar "
     "por 35 la velocidad de línea solo le da un 41 % más de caudal, porque el "
     "cuello de botella es la CPU, no el enlace. MCDMA escala linealmente hasta "
     "345 kilobytes por segundo a 4 megabaudios: setenta veces más en el mismo "
     "punto.",
     "Los buses se cierran dentro de la FPGA, así que esto mide el transporte y "
     "no la capa física. Es la gráfica clave: GPIO se satura. Multiplicar por "
     "treinta y cinco la velocidad de línea solo le da un cuarenta y uno por "
     "ciento más de caudal, porque el cuello de botella es la CPU. MCDMA escala "
     "lineal: setenta veces más en el mismo punto."),

    ("La decisión no se toma solo por rendimiento. Replicar catorce motores "
     "cuesta 2,8 veces más lógica que compartir uno. Y mirando al futuro: "
     "endurecer frente a radiación con triple redundancia modular multiplica el "
     "área por tres. El 5,18 % de MCDMA se convierte en un 16 % asumible; el "
     "14,67 % de DMA14 se convierte en un 44 %, casi la mitad del dispositivo. "
     "Hay además un límite duro: cada AXI DMA expone dos líneas de "
     "interrupción, catorce motores son 28 líneas, y el procesador solo ofrece "
     "ocho.",
     "La decisión no se toma solo por rendimiento. Replicar catorce motores "
     "cuesta casi tres veces más lógica que compartir uno. Y endurecer frente a "
     "radiación multiplica el área por tres: el cinco por ciento de MCDMA se "
     "queda en un dieciséis asumible, y el quince de DMA14 se va al cuarenta y "
     "cuatro."),

    ("Validación de CDHS y AOCS, interfaz por interfaz. Las comunicaciones "
     "serie se probaron con consola interactiva y arneses de loopback: el "
     "descubrimiento automático encontró los transceptores y los loopbacks "
     "fueron correctos. El bus CAN se validó con la batería del driver CANps "
     "del TFG de Diego Ramos: veintiséis de veintiséis, incluida la "
     "transferencia física entre CAN0 y CAN1. El ADC responde lineal en todo el "
     "rango y el PWM es correcto en las cuatro frecuencias. Queda una interfaz "
     "sin validar, y lo digo explícitamente: SpaceWire.",
     "Validación interfaz por interfaz. Las series, con consola y arneses de "
     "loopback: el descubrimiento automático encontró los transceptores y todos "
     "los loopbacks fueron correctos. El CAN, con la batería del driver CANps "
     "del TFG de Diego Ramos: veintiséis de veintiséis. El ADC responde lineal "
     "y el PWM es correcto. Queda SpaceWire sin validar, y lo digo "
     "explícitamente."),

    ("Conclusiones. Los seis objetivos se cumplen, con una excepción declarada. "
     "El transceptor configurable funciona y está verificado configuración a "
     "configuración. El driver sobre RTEMS 7 expone seis funciones y descubre "
     "el hardware en arranque. La arquitectura de transporte es la contribución "
     "de mayor recorrido: tres implementadas y medidas, no elegidas sobre el "
     "papel, y la elegida pasa de 1.250 a 3 interrupciones por kilobyte. Las "
     "tres placas se fabricaron sin retrabajos y están caracterizadas. La única "
     "excepción es SpaceWire, y está dicho con su motivo. En total, 20.188 "
     "líneas de código propio, con la verificación casi a la par del RTL que "
     "verifica.",
     "Los seis objetivos se cumplen, con una excepción declarada. La "
     "contribución de mayor recorrido es la arquitectura de transporte: tres "
     "implementadas y medidas, no elegidas sobre el papel, y la elegida pasa de "
     "mil doscientas cincuenta a tres interrupciones por kilobyte. Las tres "
     "placas, fabricadas sin retrabajos y caracterizadas. La excepción es "
     "SpaceWire, dicha con su motivo."),

    ("En lugar de elegir sobre el papel, se implementaron las tres "
     "arquitecturas completas y se midieron con el mismo programa de pruebas. "
     "La A es AXI GPIO, la de partida: un registro por canal y el procesador "
     "movía byte a byte. La B son catorce AXI DMA, un motor completo por canal: "
     "saca a la CPU del camino de datos, pero replica el motor catorce veces. Y "
     "la C es un único MCDMA multicanal compartido, con un puente en VHDL de "
     "diseño propio que multiplexa los catorce canales sobre ese motor.",
     "En lugar de elegir sobre el papel, se implementaron las tres completas y "
     "se midieron con el mismo programa. Las veo una a una en las próximas "
     "diapositivas."),
]
