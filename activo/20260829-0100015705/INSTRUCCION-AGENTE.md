# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260829-0100015705/solicitud.json` — formulario completo
2. `activo/20260829-0100015705/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\Qrys.Quatec\cola\aval-asesor-lista.htm` — HTML avalasesor (cola)
4. `sql/` — scripts: no se requeire sql
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico. OpenAI no analiza el caso: solo organiza texto o sugiere criterios en el formulario.

## Caso
- **ID caso:** 20260829-0100015705
- **ID REQ:** 0100015705
- **Dictamen:** dictamenes/20260829-0100015705.html

## Fase 1 — su tarea ahora
1. Analizar requerimiento + SQL + código Qrystalos2 + documentación.
2. Generar **propuesta** en `dictamenes/20260829-0100015705.html`.
3. Resumir propuesta en `activo/20260829-0100015705/chat.json` (autor: agente) o indicar al coordinador que abra el dictamen.

## Chat
El coordinador escribe **solo** en la app (pestaña Chat → `chat.json`).
No pida que pegue el mismo texto en Cursor. Relea `chat.json` en cada turno y responda ahí (autor: `agente`).

## Contabilidad
Si `solicitud.json` → `contenido.contabilidad.afecta` es true, valide cómoAfecta y desarrollo
contra Qrystalos2 (MCUE, CON, MCPE) y documentación. Escriba el veredicto en el Chat y en
`contenido.contabilidad.validacion`.

## Cierre fase 1
Cuando el coordinador apruebe → botón **Cerrar fase 1** en la app.
