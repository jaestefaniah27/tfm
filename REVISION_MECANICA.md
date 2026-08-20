# Revisión mecánica de la memoria — 20 de agosto de 2026

Sustituye la lectura completa de las 120 páginas por una lista acotada. Todo lo que se podía
comprobar con una regla determinista está comprobado; lo que queda abajo es lo que exige criterio.

Los scripts que generan este informe están en `tools/revision.py` y `tools/revision2.py`.
Se ejecutan desde `plantilla_tft_etsit/`:

```bash
cd plantilla_tft_etsit
python ../tools/revision.py     # informe general
python ../tools/revision2.py    # siglas y frases largas
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
| 81 | `cap1/intro.tex:1` | «Este trabajo se enmarca en el proyecto LINCE…» ← **primera frase de la memoria** |
| 73 | `anexos/anexo1.tex:180` | «se excluye todo el código generado automáticamente…» |
| 71 | `anexos/anexoB.tex:30` | «La mano de obra es la mayor partida individual…» |
| 66 | `cap5/conclusiones.tex:80` | «La validación experimental confirma el funcionamiento…» ← enumera 5 interfaces |
| 65 | `cap3/entorno_desarrollo.tex:842` | «calcula la dirección base y la dirección del INTC…» |
| 64 | `cap5/lineasfuturas.tex:34` | «el scrubbing periódico de la memoria de configuración…» |
| 64 | `cap4/validacion_hardware.tex:171` | «Para la placa AOCS, el bloque VHDL de control de motores…» |
| 63 | `pre/resumen.tex:33` | «La comparativa demuestra que la primera interrumpe…» |
| 62 | `pre/resumen.tex:77` | la misma, en el Summary |

Las dos que yo partiría: **`cap1/intro.tex:1`** (es lo primero que lee el tribunal) y
**`pre/resumen.tex:33`** con su gemela inglesa. El resto son enumeraciones, donde una frase larga
es legítima.

### 2.2 Muletillas

- **«de modo que»: 37 veces** en 120 páginas. Es tu conector por defecto. Sustituciones según el
  caso: «por lo que», «así», «con lo que», punto y seguido.
- «además»: 26. Aceptable, pero conviene no encadenar dos en el mismo párrafo.

### 2.3 Etiquetas definidas y nunca referenciadas (4)

Inofensivas, pero son anclas muertas. Si no piensas citarlas, se pueden borrar:

- `cap2/transporte.tex:5` → `sec:teoria_transporte`
- `cap3/entorno_desarrollo.tex:167` → `sec:carga_sd`
- `cap3/entorno_desarrollo.tex:1213` → `sec:reglas_diseno`
- `cap3/transporte.tex:129` → `sec:variante_mcdma`

### 2.4 Lo que ninguna regla detecta

- **Ortografía**: no hay corrector instalado en el equipo. `hunspell` + `hunspell-es` daría una
  pasada real; sin él, esto no está comprobado.
- **Fluidez**: escuchar el PDF con la lectura en voz alta del visor, a 1,5×. El oído detecta el
  párrafo enrevesado que el ojo se salta.
- **Lo que el tribunal lee de verdad**: resumen, objetivos, conclusiones, pies de figura y tablas.
  Son unas 15 páginas y son las que merecen lectura en papel.
