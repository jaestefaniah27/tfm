# -*- coding: utf-8 -*-
"""Recortes del guion hablado para bajar de 18,3 a ~17 minutos.

Cada par es (fragmento actual, fragmento nuevo). Se recorta lo que ya esta
escrito en la propia diapositiva, no el argumento.
"""

RECORTES = [
    # --- livelock: la cita ya aparece en la diapositiva
    ("Si interrumpes una vez por byte, al subir la velocidad de línea el tiempo "
     "entre bytes baja pero el coste de la interrupción no: hay un umbral de "
     "saturación, y con N enlaces llega N veces antes. Mogul y Ramakrishnan lo "
     "llamaron interrupt livelock. La solución de fondo no es optimizar la "
     "rutina: es interrumpir por paquete y no por byte. Es decir, DMA.",
     "Si interrumpes una vez por byte, al subir la velocidad el tiempo entre "
     "bytes baja pero el coste de la interrupción no: hay un umbral de "
     "saturación, y con N enlaces llega N veces antes. La solución de fondo no "
     "es optimizar la rutina: es interrumpir por paquete. Es decir, DMA."),

    # --- depuracion: los dos invariantes estan enunciados en la diapositiva
    ("De ahí salieron dos invariantes estructurales. La primera: el motor de "
     "recepción trabaja en store-and-forward con un buffer de 512 bytes, así "
     "que un paquete mayor lo bloquea esperando un TLAST que nunca llega; DRAIN "
     "impone un tope duro de 256. La segunda: TLAST no puede ser combinacional "
     "sobre FIFO vacía, porque un byte nuevo durante una espera por "
     "contrapresión tumbaría el TLAST ya presentado. Con las correcciones, la "
     "batería en placa pasó de 0 de 36 a 36 de 36.",
     "De ahí salieron los dos invariantes estructurales que veis aquí, y los "
     "dos nacen de la misma causa: el motor de recepción trabaja en "
     "store-and-forward sobre un buffer de 512 bytes. Con las correcciones, la "
     "batería en placa pasó de 0 de 36 a 36 de 36."),

    # --- caudal: la condicion del banco ya esta escrita arriba
    ("Esta campaña se hizo sin ninguna de las placas: los buses se cierran "
     "dentro de la propia FPGA con un módulo de loopback que reproduce "
     "fielmente la topología de la PCB, incluido el wired-AND de RS485 y el "
     "hecho de que un canal no se oye a sí mismo. Así se mide el coste del "
     "transporte y no la capa física. Esta es la gráfica clave del trabajo:",
     "Los buses se cierran dentro de la propia FPGA, con un módulo de loopback "
     "que reproduce la topología de la PCB: así se mide el coste del transporte "
     "y no la capa física. Esta es la gráfica clave del trabajo:"),

    # --- interrupciones: no hace falta deletrear la cifra
    ("En la variante GPIO, las interrupciones de transmisión igualan "
     "exactamente a los bytes transmitidos, veintidós mil ciento sesenta y uno "
     "igual a veintidós mil ciento sesenta y uno: la CPU toca cada byte. "
     "Cuatrocientas veces menos interrupciones es lo que explica la latencia, "
     "el 99 % del techo y la escalabilidad.",
     "En GPIO, las interrupciones de transmisión igualan exactamente a los "
     "bytes transmitidos: la CPU toca cada byte. Cuatrocientas veces menos "
     "interrupciones es lo que explica la latencia, el 99 % del techo y la "
     "escalabilidad."),

    # --- transceptor: el detalle del NCO esta en el recuadro inferior
    ("La temporización de bit no se puede sacar de un divisor entero del reloj, "
     "así que se usa un oscilador controlado numéricamente: un acumulador de 32 "
     "bits cuyo incremento está tabulado por baudrate; cada desbordamiento "
     "genera un tick. Hay un NCO para transmisión y otro para recepción, con un "
     "modo de doble frecuencia que el transmisor usa en el campo de parada y el "
     "receptor en el bit de inicio.",
     "La temporización de bit no sale de un divisor entero del reloj, así que "
     "se usa un oscilador controlado numéricamente: un acumulador de 32 bits "
     "con el incremento tabulado por baudrate, y cada desbordamiento es un "
     "tick. Uno para transmisión y otro para recepción."),

    # --- mcdma: el bloque EOF tiene su propio recuadro
    ("El reparto lo hace la señal TDEST: el bloque DRAIN etiqueta cada paquete "
     "con su canal de origen y el MCDMA lo lleva al descriptor correcto. Sin esa "
     "etiqueta, todo cae en el canal cero, que fue exactamente el síntoma que "
     "vimos en placa.",
     "El reparto lo hace la señal TDEST: DRAIN etiqueta cada paquete con su "
     "canal de origen. Sin esa etiqueta todo cae en el canal cero, que fue "
     "exactamente el síntoma que vimos en placa."),

    # --- futuras: el cierre va en la diapositiva de gracias
    ("Y a largo plazo, endurecer la plataforma frente a radiación con triple "
     "redundancia modular y scrubbing de configuración, que es precisamente lo "
     "que el 5,18 % de ocupación hace viable. Muchas gracias por su atención.",
     "Y a largo plazo, endurecer la plataforma frente a radiación con TMR y "
     "scrubbing de configuración, que es lo que el 5,18 % de ocupación hace "
     "viable."),

    # --- driver: el descubrimiento dinamico tiene su recuadro
    ("Primera: no hay ninguna dirección fija en el código. Un GPIO de solo "
     "lectura publica el número de transceptores, el stride y la dirección "
     "base, y el driver deduce el resto, así que el mismo binario sirve para "
     "cualquier bitstream, de uno a catorce canales. Segunda: procesado "
     "diferido. La rutina de interrupción hace lo mínimo y delega en una tarea "
     "worker, de modo que la latencia de interrupción no depende del volumen de "
     "datos.",
     "Primera: no hay ninguna dirección fija en el código, se descubren en "
     "arranque, así que el mismo binario sirve de uno a catorce canales. "
     "Segunda: procesado diferido, la rutina de interrupción delega en una "
     "tarea worker y la latencia no depende del volumen de datos."),

    # --- validacion de placas: el detalle de CAN va en la foto siguiente
    ("El bus CAN se validó con la batería de pruebas del driver CANps del TFG "
     "de Diego Ramos: veintiséis pruebas, veintiséis correctas, incluyendo "
     "transferencia física entre CAN0 y CAN1, filtrado de identificador "
     "estándar y extendido y tramas RTR. El ADC responde lineal en todo el "
     "rango y el PWM es correcto en las cuatro frecuencias.",
     "El bus CAN se validó con la batería del driver CANps del TFG de Diego "
     "Ramos: veintiséis de veintiséis, incluida la transferencia física entre "
     "CAN0 y CAN1. El ADC responde lineal en todo el rango y el PWM es correcto "
     "en las cuatro frecuencias."),

    # --- conclusiones: el recuento de codigo esta en la grafica
    ("En total, 20.188 líneas de código propio: el código de verificación casi "
     "iguala al RTL que verifica y la automatización es la mayor partida.",
     "En total, 20.188 líneas de código propio, con la verificación casi a la "
     "par del RTL que verifica."),
]
