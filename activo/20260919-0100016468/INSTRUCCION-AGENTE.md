# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260919-0100016468/solicitud.json` — formulario completo
2. `activo/20260919-0100016468/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\QrystalosBA\cola\IX OnLine.htm` — HTML avalasesor (cola)
4. **Capturas para análisis** — lea las imágenes en:
   - activo/20260919-0100016468/imagenes/image__2__1_.png
   Contraste pantallazos con Qrystalos2 y el REQ.
5. `sql/` — scripts: SPK_NC_CONTAB_CXP.sql, SPK_NC_CONTAB_CXPFNT.sql, SPQ_ANTICIPOS_COL.sql, SPQ_CONF_CXP.sql, SPQ_FCXP.sql, SPQ_FCXPDBCR.sql, SPQ_FCXP_AUDIT.sql, SPQ_FRADIAN.sql, SPQ_ORDEN_PAGO.sql
6. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

Si falta algún SQL, imagen, HTML en cola o aclaración: **DETENER y pedirla**.

## Caso
- **ID caso:** 20260919-0100016468
- **ID REQ:** 0100016468
- **Dictamen:** dictamenes/20260919-0100016468.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución**: criteriosAceptacion, alcance, restricciones, analisis, recomendacion + lista de SP/METODO **de este cambio** (no el catálogo del módulo).
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/20260919-0100016468.html`.
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
