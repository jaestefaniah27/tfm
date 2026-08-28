# Revisión de la Sección de Desarrollo Hardware del TFM

Se ha realizado una auditoría en profundidad de la sección de **Desarrollo Hardware** de la memoria. El objetivo ha sido verificar la coherencia técnica de las explicaciones, la adecuación y disponibilidad de las figuras, y la calidad general de la redacción.

A continuación se detalla el veredicto revisado y los aspectos a mejorar.

---

## 1. Coherencia Técnica y Calidad de las Explicaciones

**Veredicto:** Excelente. La justificación de las decisiones de diseño es clara, madura y tiene mucho sentido desde el punto de vista de la ingeniería. 

**Puntos fuertes a destacar:**
- **Elección de tensiones:** La justificación de utilizar bancos FMC a 1.8V y seleccionar componentes con VIO nativo a 1.8V para evitar adaptadores de nivel es muy acertada.
- **Topologías RS485/RS422 por jumper:** La explicación de cómo se configuran las redes multipunto y maestro-esclavo mediante jumpers (compartiendo líneas A y B) se entiende perfectamente.
- **Decisión de cortocircuitar DE y RE:** La explicación técnica sobre el integrado THVD1424RGTR en modo *Half-Duplex* (evitando que el nodo escuche su propio eco) demuestra un gran conocimiento del hardware y del estándar.
- **Terminación Split en el CAN:** Se explica con todo detalle y acierto por qué se usa un esquema de resistencias *split* (60 Ω + 60 Ω) con un condensador central en lugar de una resistencia única, mencionando el rechazo al ruido de modo común (EMC).
- **Protecciones ESD:** La mención a diodos específicos de baja capacitancia parásita (ESDCAN24 y SM712) para no afectar la integridad de señal a altas velocidades es un gran punto a favor.
- **SpaceWire:** El ruteado de los pares diferenciales con adaptación de impedancia a 100 Ω y *length matching* está correctamente documentado.

---

## 2. Estado de las Figuras y Referencias Cruzadas (Revisado)

Tras una inspección más exhaustiva de la estructura real del repositorio (incluyendo las carpetas `plantilla_tft_etsit/IMG/` y `tfm/00_docs/pcbs/`), se confirma que **todas las figuras y archivos necesarios están presentes**.

### 🟢 Archivos y Esquemas (Comprobados)
1. **Esquemáticos de PCB:** El esquemático `LINCE_comunicacion_serial.pdf` se encuentra correctamente ubicado en `tfm/00_docs/pcbs/serial/`, al igual que los ficheros de las placas AOCS y CDHS. 
   - *Nota menor:* En el texto se menciona que están bajo la carpeta `HARDWARE/`. Como ahora están estructurados en `tfm/00_docs/pcbs/`, convendría actualizar esa ruta en el texto de la memoria para ser precisos.
2. **Renders 3D:** Los renders 3D de las caras superior e inferior de las placas CDHS y AOCS (`aocs_3d_bot.png`, `cdhs_3d_top.png`, etc.) están perfectamente guardados en `plantilla_tft_etsit/IMG/pcbs/`.
3. **Fotografías Reales:** Las fotos de las placas soldadas (`aocs_soldada.jpg`, `cdhs_soldada.jpg`, `serial_pcb_top.jpg`) también constan sin problemas en el directorio de imágenes.

### 🟠 Sugerencia Menor sobre Figuras
- **Duplicidad de fotos:** 
   - En la subsección *Diseño placa de comunicación serie* mencionas: `[FIGURA: Foto de la placa LINCE Comunicación Serie fabricada (cara superior)]`.
   - Más adelante, en la sección de *Fabricación*, repites: `[FIGURA: Foto de la placa LINCE Comunicación Serie soldada (cara superior)]`.
   **Recomendación:** Considera dejar solo la foto real en el apartado de *Fabricación* para mantener el orden cronológico, y usar esquemas o renders en la sección de *Diseño*.

---

## 3. Sugerencias de Redacción

- **Consolidación de esquemáticos:** A la hora de añadir las figuras de esquemáticos (hojas TOP, conectores, selectores), vigila que no saturen el documento. Mostrar la *Hoja TOP* (arquitectura) y un detalle del *circuito del jumper* está muy bien, pero agrupar recortes pequeños en una sola figura (p. ej., el circuito del jumper RS485 y el del selector Micro-D juntos) puede agilizar la lectura al tribunal.
- **Transición VHDL autónomo PWM:** Mencionas el bloque autónomo `PWMx4_auto_test` escrito en VHDL para verificar el funcionamiento de las salidas. Es un gran apunte técnico; sirve perfectamente como justificación del test sin necesidad de ahondar mucho más.

## Resumen del Plan de Acción
1. **Actualizar la ruta en el texto:** Cambiar la mención de la carpeta `HARDWARE/` por la ruta real `tfm/00_docs/pcbs/` en la redacción.
2. **Revisar redundancia de fotos:** Eliminar la mención duplicada de la foto de la placa de diseño propio.
3. **¡Listo!** El contenido técnico es impecable y está listo para ser defendido.
