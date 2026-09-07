# Conocimiento — instrucción para el agente

Lea **del disco** en este orden cuando trabaje la base de procesos o un REQ:

1. `conocimiento/INDICE.json` — ¿existe el proceso del módulo?
2. `conocimiento/RUTA.json` — orden del coordinador (Caja → Facturación → Cartera → Activos → Contabilidad). El vigilante trabaja el siguiente valle.
3. `conocimiento/tarea.json` — si `abierta` es true, esa es la tarea de Documentar.
4. `conocimiento/canales/documentar/chat.json` — Chat de Documentar (autor: `agente`).
5. `conocimiento/pendientes.json` — cola de valles.
6. `conocimiento/{id}/proceso.json` — flujo e invariantes.
7. `conocimiento/{id}/sps.json` — catálogo SP → METODO (hace / valida / errores).
8. Si la tarea trae `archivoSql`: leer **`sql/{archivo}` de hoy**. No usar copias viejas ni `sql_refe` salvo que el coordinador lo indique.
9. Qrystalos2 y `qrystalos.documentacion` **vivos** (no duplicar aquí).

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
3. Actualizar el **gate** en `proceso.json` solo si cambia el flujo.
4. **No pegar el cuerpo del procedimiento** en la base.
5. Escribir en `chat.json` qué documentó y qué falta (SPK anidados → nuevas filas en pendientes).
6. Marcar el pendiente `en_progreso` o `completado` según alcance.
7. Poner `tarea.json` → `abierta: false` al terminar o si se detiene a pedir otro script.

## Si el proceso no existe (REQ de un módulo nuevo)

Crear esqueleto de 5 capas, una fila en `INDICE.json` y pendientes. Dictaminar solo el gate de **este** REQ. Declarar el resto incompleto.

## Prohibido

Inventar columnas, cuerpos de SP o invariantes no vistos en el script o confirmados por el coordinador.
