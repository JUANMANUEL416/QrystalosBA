# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260903-0100016298/solicitud.json` — formulario completo
2. `activo/20260903-0100016298/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\QrystalosBA\cola\IX OnLine.htm` — HTML avalasesor (cola)
4. **SQL — métodos documentados** (no exigir `sql/` de entrada)
   - Catálogo: `conocimiento/conciliaciones/sps.json`
   - Métodos del gate:
- SPQ_FCONCI_COL · CONFIRMAR_CONCILIACION (estado: leido)
- SPK_APLICA_CONCILIACION · APLICAR (estado: leido)
   - Línea exacta F_NOTA: `sql_refe/xsql/SPK_APLICA_CONCILIACION.sql` (~l.125)
   - Lea esas fichas (`hace`, `valida`, `noValida`, `errores`, `llama`, `efecto`).
   - **No se detenga** porque `sql/` esté vacío si esos METODO cubren el REQ.
   - En el **Chat del caso** (`activo/20260903-0100016298/chat.json`), en el primer resumen, indique si hace falta el .sql de hoy:
     - Todos `leido` y el alcance no sale de lo documentado → seguir sin pedir el script.
     - Alguno `listado` / `no_leido` / `parcial`, o el REQ toca validaciones no documentadas → **pedir** el .sql en `sql/` (los SP se actualizan a diario).
   - No invente METODOs que no estén en `sps.json`.
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

Si falta cola, aclaración, o el Chat concluye que hay que releer el SP: **DETENER y pedir** el .sql en `sql/`.

## Caso
- **ID caso:** 20260903-0100016298
- **ID REQ:** 0100016298
- **Dictamen:** dictamenes/20260903-0100016298.html

## Fase 1 — su tarea ahora
1. Analizar requerimiento + (fichas SP en conocimiento/ y/o SQL de hoy) + código Qrystalos2 + documentación.
2. Generar **propuesta** en `dictamenes/20260903-0100016298.html`.
3. Resumir propuesta en `activo/20260903-0100016298/chat.json` (autor: agente) o indicar al coordinador que abra el dictamen.
4. Si usó métodos documentados: deje en el Chat el veredicto de **releer o no** el .sql de hoy.

## Chat
El coordinador escribe **solo** en la app (pestaña Chat → `chat.json`).
No pida que pegue el mismo texto en Cursor. Relea `chat.json` en cada turno y responda ahí (autor: `agente`).

## Contabilidad
Si `solicitud.json` → `contenido.contabilidad.afecta` es true, valide cómoAfecta y desarrollo
contra Qrystalos2 (MCUE, CON, MCPE) y documentación. Escriba el veredicto en el Chat y en
`contenido.contabilidad.validacion`.

## Cierre fase 1
Cuando el coordinador apruebe → botón **Cerrar fase 1** en la app.
