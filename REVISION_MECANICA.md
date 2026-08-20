# Revisión mecánica de la memoria — 20 de agosto de 2026

Sustituye la lectura completa de las 120 páginas por una lista acotada. Todo lo que se podía
comprobar con una regla determinista está comprobado; lo que queda abajo es lo que exige criterio.

Los scripts que generan este informe están en `tools/revision.py`, `tools/revision2.py` y
`tools/ortografia.py`.
Se ejecutan desde `plantilla_tft_etsit/`:

```bash
cd plantilla_tft_etsit
python ../tools/revision.py     # informe general
python ../tools/revision2.py    # siglas y frases largas
python ../tools/ortografia.py   # ortografía (spylls + es_ES)
```

---

## 1. Ya corregido (42 incidencias)

| Qué | Cuántas | Cómo se arregló |
|---|---|---|
| `\ref`/`\cite` sin `~` delante | 19 | Espacio irrompible: evita que «figura» y su número caigan en líneas distintas |
| Cifras sin separador fino que en las tablas sí lo llevan | 15 | `1250` → `1\,250`, `9600` → `9\,600`, `3471` → `3\,471`… |
| Anglicismos sin cursiva | 5 | `jumper`, `testbench`, `stencil`, título `Throughput` |
| «sólo» con tilde | 1 | La RAE ya no la pide y el resto del documento escribe «solo» |
| `\caption` sin punto final | 1 | Anexo C |
| Tabla con etiqueta pero nunca citada en el texto | 1 | `tab:pcb_topologia`, ahora referenciada |
| Siglas frecuentes ausentes de la lista de acrónimos | 12 | API, ARM, BER, CPU, GPIO, LSB, MSB, SEU, SLO, TMR, USB, VADJ |

Comprobado y **sin incidencias**: dobles espacios en texto corrido, espacios antes de coma o punto,
comillas mezcladas, cursivas anidadas, separadores finos dentro de `\texttt`, captions de más de
150 caracteres, incisos con rayas.

## 2. Pendiente de tu criterio

### 2.1 Frases de más de 55 palabras (22)

Ninguna está mal escrita; son largas. Las que más lo notan, por orden:

| Palabras | Dónde | Empieza por |
|---|---|---|
| 105 | `anexos/anexoA.tex:1` | «El apartado ``Requisitos de las acreditaciones…» (cita normativa, se puede dejar) |
| 81 | `cap1/intro.tex:1` | ~~«Este trabajo se enmarca en el proyecto LINCE…»~~ partida en tres |
| 73 | `anexos/anexo1.tex:180` | «se excluye todo el código generado automáticamente…» |
| 71 | `anexos/anexoB.tex:30` | «La mano de obra es la mayor partida individual…» |
| 66 | `cap5/conclusiones.tex:80` | «La validación experimental confirma el funcionamiento…» ← enumera 5 interfaces |
| 65 | `cap3/entorno_desarrollo.tex:842` | «calcula la dirección base y la dirección del INTC…» |
| 64 | `cap5/lineasfuturas.tex:34` | «el scrubbing periódico de la memoria de configuración…» |
| 64 | `cap4/validacion_hardware.tex:171` | «Para la placa AOCS, el bloque VHDL de control de motores…» |

Las dos filas de `pre/resumen.tex` que aparecían en la primera versión de este informe eran un
falso positivo: el detector no cortaba en los dos puntos y unía dos frases. Medido bien, la
frase más larga de los dos resúmenes son 46 palabras. Ya está corregido en el script.

De las que quedan, el resto son enumeraciones, donde una frase larga es legítima.

### 2.2 Muletillas

- **«de modo que»: de 37 a 19.** Se repartieron 18 según lo que expresaba cada caso: «para que»
  en los seis de finalidad (los que llevaban subjuntivo), «por lo que» en nueve de consecuencia,
  «con lo que» en tres de resultado, y uno se reescribió con dos puntos para no encadenar dos
  «por lo que» en el mismo párrafo. Reparto actual: «de modo que» 19, «por lo que» 16,
  «para que» 12, «con lo que» 6, y ningún párrafo repite conector.
- «además»: 26. Aceptable, pero conviene no encadenar dos en el mismo párrafo.

### 2.3 Etiquetas definidas y nunca referenciadas — resuelto

Las cuatro eliminadas. Una de ellas, `sec:carga_sd`, colgaba de un `\textbf` y no de un comando
de seccionado: una referencia a ella habría dado el número de la sección anterior.

### 2.4 Lo que ninguna regla detecta

- **Ortografía**: ya hay corrector. `tools/ortografia.py` usa spylls (Hunspell) con el
  diccionario es_ES de LibreOffice. Encontró «destacadasde», «Para mi», «en mi», «Alvaro» y
  «sobretodo». Ahora sale limpio; las palabras técnicas viven en `tools/dic/whitelist.txt`.
- **Fluidez**: escuchar el PDF con la lectura en voz alta del visor, a 1,5×. El oído detecta el
  párrafo enrevesado que el ojo se salta.
- **Lo que el tribunal lee de verdad**: resumen, objetivos, conclusiones, pies de figura y tablas.
  Son unas 15 páginas y son las que merecen lectura en papel.
