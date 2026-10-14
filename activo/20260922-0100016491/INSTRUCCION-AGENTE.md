# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260922-0100016491/solicitud.json` — formulario completo
2. `activo/20260922-0100016491/chat.json` — mensajes del coordinador (releer en cada turno)
3. `C:\DevQuasar\Qrystalos\QrystalosBA\cola\IX OnLine.htm` — HTML avalasesor (cola)
4. **Capturas para análisis** — lea las imágenes en:
   - activo/20260922-0100016491/imagenes/xsd.png
   Contraste pantallazos con Qrystalos2 y el REQ.
5. **Diagrama de flujo** — ya generado en `activo/20260922-0100016491/diagramas/flujo.html`. **Incruste el mapa en la sección 4.5** del dictamen (no solo un enlace). Copia suelta: `dictamenes/20260922-0100016491-flujo.html`.
5. `activo/20260922-0100016491/sql/` — scripts de ESTE caso: dfdf
   No lea ni escriba la carpeta compartida `sql/` (es de Documentar y mezcla otros análisis).
6. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

Si falta algún SQL, imagen, HTML en cola o aclaración: **DETENER y pedirla**. El .sql de este caso va en `activo/20260922-0100016491/sql/`.

## Caso
- **ID caso:** 20260922-0100016491
- **ID REQ:** 0100016491
- **Dictamen:** dictamenes/20260922-0100016491.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución**: criteriosAceptacion, alcance, restricciones, analisis, recomendacion + lista de SP/METODO **de este cambio** (no el catálogo del módulo). Si el fix es SQL, complete `contenido.cambioPropuestoSql` (fragmentos para dictamen §5.2.1).
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/20260922-0100016491.html`.
5. Si usó métodos documentados: veredicto breve de releer o no el .sql de hoy.
6. **Mockup UX:** si genera o ajusta `activo/20260922-0100016491/mockups/`, pinte la **ventana propuesta** (`cambioPropuestoSimple`, criterios, recomendación), no la captura del error ni un control de otro REQ. `imagenes/` es solo referencia «Hoy».

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
