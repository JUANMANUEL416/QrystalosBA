# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260829-0100015154/solicitud.json` — formulario completo
2. `activo/20260829-0100015154/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\Qrys.Quatec\cola\aval-asesor-lista.htm` — HTML avalasesor (cola)
4. `sql/` — scripts: no requiere sql
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico. OpenAI no analiza el caso: solo organiza texto o sugiere criterios en el formulario.

## Caso
- **ID caso:** 20260829-0100015154
- **ID REQ:** 0100015154
- **Dictamen:** dictamenes/20260829-0100015154.html

## Fase 1 — su tarea ahora
1. Analizar requerimiento + SQL + código Qrystalos2 + documentación.
2. Generar **propuesta** en `dictamenes/20260829-0100015154.html`.
3. Resumir propuesta en `activo/20260829-0100015154/chat.json` (autor: agente) o indicar al coordinador que abra el dictamen.

## Chat
El coordinador escribe en la app (pestaña Chat). **Releer chat.json** cuando diga "continúa" o abra el chat.

## Cierre fase 1
Cuando el coordinador apruebe → botón **Cerrar fase 1** en la app.
