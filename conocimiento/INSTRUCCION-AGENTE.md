# Conocimiento — instrucción para el agente

El Chat histórico **no se lee**. El bot pega en el prompt el último mensaje del coordinador.
Consultas y Documentar tienen **un chat por módulo** (facturación aparte de caja). Cada REQ tiene el suyo en `activo/{id-caso}/chat.json`.
Las respuestas que el coordinador **acepte** viven en `conocimiento/{id}/faq.json`. El bot solo recibe coincidencias con la pregunta actual (no el archivo entero).

Lea **solo lo del giro**, en este orden:

1. `conocimiento/INDICE.json` — ubicar el proceso nombrado (no releer el índice si ya está en el prompt).
2. `conocimiento/tarea.json` — si `abierta` es true, esa es la tarea de Documentar.
3. `conocimiento/{id}/proceso.json` y `sps.json` de **ese** proceso — la base ya destiló FE y docs.
4. Si la tarea trae `archivoSql`: leer **`sql/{archivo}` de hoy**.
5. Qrystalos2 / `qrystalos.documentacion` / `pendientes.json` / `RUTA.json` **solo** si la ficha no cubre el pedido.

Prohibido: abrir `chat.json` (canales, chats, raíz), barrer todos los `sps.json`, recorrer Qrystalos2 «por si acaso».

## Si `tarea.json` está abierta (tipo `documentar_sp`)

1. Leer el `.sql` indicado en `sql/`.
2. En `{id}/sps.json` documentar **cada `METODO`** del SP (plantilla `_plantillas/SP.json`):
   - `hace` — de qué se encarga en el proceso
   - `valida` — qué comprueba
   - `noValida` — huecos (qué no comprueba)
   - `errores` — textos KO que ve el usuario
   - `llama` — SPK/SPQ/FNK anidados
   - `efecto` — qué queda cierto si responde OK
   - `estado` — `leido` | `listado` | `no_leido`
3. Actualizar el **control** en `proceso.json` solo si cambia el flujo.
4. **No pegar el cuerpo del procedimiento** en la base.
5. Escribir en `chat.json` qué documentó y qué falta (SPK anidados → nuevas filas en pendientes).
6. Marcar el pendiente `en_progreso` o `completado` según alcance.
7. Poner `tarea.json` → `abierta: false` al terminar o si se detiene a pedir otro script.

## Si el proceso no existe (REQ de un módulo nuevo)

Crear esqueleto de 5 capas, una fila en `INDICE.json` y pendientes. Dictaminar solo el control de **este** REQ. Declarar el resto incompleto.

## Prohibido

Inventar columnas, cuerpos de SP o invariantes no vistos en el script o confirmados por el coordinador.
