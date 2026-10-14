# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20261001-0100016569/solicitud.json` — formulario completo
2. `activo/20261001-0100016569/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\QrystalosBA\cola\IX OnLine.htm` — HTML avalasesor (cola)
4. **Capturas para análisis** — lea las imágenes en:
   - activo/20261001-0100016569/imagenes/Captura_de_pantalla_2025-12-17_132159.png
   Contraste pantallazos con Qrystalos2 y el REQ.
5. **Diagrama de flujo** — ya generado en `activo/20261001-0100016569/diagramas/flujo.html`. **Incruste el mapa en la sección 4.5** del dictamen (no solo un enlace). Copia suelta: `dictamenes/20261001-0100016569-flujo.html`.
5. **SQL — métodos documentados** (no exigir `activo/20261001-0100016569/sql/` de entrada)
   - Catálogo: `conocimiento/cxp-fcxp/sps.json`
   - Carpeta de ESTE análisis: `activo/20261001-0100016569/sql/` (no usar la carpeta compartida `sql/`).
   - Métodos del formulario:
- SPQ_FCXP · CONTABILIZAR_FCXP (estado: leido)
- SPQ_ORDEN_PAGO · PAGO_CXPTOTAL (estado: leido)
- SPQ_ORDEN_PAGO · PAGO_PARCIAL (estado: leido)
   - Lea esas fichas (`hace`, `valida`, `noValida`, `errores`, `llama`, `efecto`).
   - **No se detenga** porque `activo/20261001-0100016569/sql/` esté vacío si esos METODO cubren el REQ.
   - En el **Chat del caso** (`activo/20261001-0100016569/chat.json`), en el primer resumen, indique si hace falta el .sql de hoy:
     - Todos `leido` y el alcance no sale de lo documentado → seguir sin pedir el script.
     - Alguno `listado` / `no_leido` / `parcial`, o el REQ toca validaciones no documentadas → **bajar** el .sql a `activo/20261001-0100016569/sql/` (`python scripts/sqlix_bajar_objeto.py --caso 20261001-0100016569 NOMBRE`).
   - No invente METODOs que no estén en `sps.json`.
6. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

Si falta cola, aclaración, o el Chat concluye que hay que releer el SP: **bajar** el .sql a `activo/20261001-0100016569/sql/`. No lo deje en `sql/`.

## Caso
- **ID caso:** 20261001-0100016569
- **ID REQ:** 0100016569
- **Dictamen:** dictamenes/20261001-0100016569.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución**: criteriosAceptacion, alcance, restricciones, analisis, recomendacion + lista de SP/METODO **de este cambio** (no el catálogo del módulo). Si el fix es SQL, complete `contenido.cambioPropuestoSql` (fragmentos para dictamen §5.2.1).
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/20261001-0100016569.html`.
5. Si usó métodos documentados: veredicto breve de releer o no el .sql de hoy.
6. **Mockup UX:** si genera o ajusta `activo/20261001-0100016569/mockups/`, pinte la **ventana propuesta** (`cambioPropuestoSimple`, criterios, recomendación), no la captura del error ni un control de otro REQ. `imagenes/` es solo referencia «Hoy».

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
