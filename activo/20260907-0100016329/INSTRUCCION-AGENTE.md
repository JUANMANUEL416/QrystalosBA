# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260907-0100016329/solicitud.json` — formulario completo
2. `activo/20260907-0100016329/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\QrystalosBA\cola\IX OnLine.htm` — HTML avalasesor (cola)
5. **Diagrama de flujo** — ya generado en `activo/20260907-0100016329/diagramas/flujo.html`. **Incruste el mapa en la sección 4.5** del dictamen (no solo un enlace). Copia suelta: `dictamenes/20260907-0100016329-flujo.html`.
4. **SQL — métodos documentados** (no exigir `sql/` de entrada)
   - Catálogo: `conocimiento/bancos/sps.json`
   - Métodos del formulario:
- SPQ_BCTC · GETCONCILIACIONES (estado: leido)
- SPQ_BCTC · ACTUALIZACONCILIACION (estado: leido)
- SPQ_BCTC · CIERRACONCILIACION (estado: leido)
- SPQ_BCTC · GUARDABCTCD (estado: leido)
- SPQ_BCTC · GETBCTCD (estado: leido)
- SPQ_BCTC · RELIQUIDAR (estado: leido)
- SPQ_BCTC · IMPRIMIR_CONCILIACION (estado: leido)
- SPQ_BMOV · CONFIRMARBMOV (estado: leido)
   - Lea esas fichas (`hace`, `valida`, `noValida`, `errores`, `llama`, `efecto`).
   - **No se detenga** porque `sql/` esté vacío si esos METODO cubren el REQ.
   - En el **Chat del caso** (`activo/20260907-0100016329/chat.json`), en el primer resumen, indique si hace falta el .sql de hoy:
     - Todos `leido` y el alcance no sale de lo documentado → seguir sin pedir el script.
     - Alguno `listado` / `no_leido` / `parcial`, o el REQ toca validaciones no documentadas → **pedir** el .sql en `sql/` (los SP se actualizan a diario).
   - No invente METODOs que no estén en `sps.json`.
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

Si falta cola, aclaración, o el Chat concluye que hay que releer el SP: **DETENER y pedir** el .sql en `sql/`.

## Caso
- **ID caso:** 20260907-0100016329
- **ID REQ:** 0100016329
- **Dictamen:** dictamenes/20260907-0100016329.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución**: criteriosAceptacion, alcance, restricciones, analisis, recomendacion + lista de SP/METODO **de este cambio** (no el catálogo del módulo).
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/20260907-0100016329.html`.
5. Si usó métodos documentados: veredicto breve de releer o no el .sql de hoy.

## Chat
El coordinador escribe **solo** en la app (pestaña Chat → `chat.json`).
No pida que pegue el mismo texto en Cursor. Relea `chat.json` en cada turno y responda ahí (autor: `agente`).

## Contabilidad
Si `solicitud.json` → `contenido.contabilidad.afecta` es true, valide cómoAfecta y desarrollo
contra Qrystalos2 (MCUE, CON, MCPE) y documentación. Escriba el veredicto en el Chat y en
`contenido.contabilidad.validacion`. Si **no afecta**, en el dictamen HTML deje solo
«Afecta contabilidad: No». No ponga Cómo lo afecta, Desarrollo contable ni Validación del agente.

## Cierre fase 1
Cuando el coordinador apruebe → botón **Cerrar fase 1** en la app.
