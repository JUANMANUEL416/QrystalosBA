# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/20260917-cxp-fcxp-radian/solicitud.json` — formulario completo
2. `activo/20260917-cxp-fcxp-radian/chat.json` — mensajes del coordinador (releer en cada turno)
3. **Dictamen ya generado:** `dictamenes/20260917-cxp-fcxp-radian.html` y flujo `dictamenes/20260917-cxp-fcxp-radian-flujo.html`
4. **Proceso:** `conocimiento/cxp-fcxp/proceso.json`, `conocimiento/cxp-fcxp/sps.json`
5. **SQL — métodos documentados** (no exigir `sql/` de entrada salvo releer)
   - Catálogo: `conocimiento/cxp-fcxp/sps.json`
   - Métodos del formulario: SPQ_FCXP (ELIMINAR_FCXPD, REGISTRAR_CXP_FRADIAN), SPQ_FCXPDBCR, SPQ_ORDEN_PAGO, SPQ_FCXP_AUDIT, SPQ_FRADIAN, SPQ_ANTICIPOS_COL, SPQ_CONF_CXP
   - Scripts en `sql/` PREVERSION=2.0.1 cuando haga falta releer cuerpo
6. Qrystalos2: `CXPComponent.vue`, `FacturasRadianComponent.vue`, `AUDCXPComponent.vue`, `OPComponent.vue`

## Caso
- **ID caso:** 20260917-cxp-fcxp-radian
- **ID REQ:** pendiente numeración avalasesor (documentación interna producto)
- **Dictamen:** dictamenes/20260917-cxp-fcxp-radian.html

## Fase 1 — estado
Dictamen **Propuesto**. Coordinador revisa en Chat app y aprueba **Cerrar fase 1** cuando listo.

## Alcance
- **F1:** defectos FE (PROCEDE=2, SALDO)
- **F2:** Radian rápido vía REGISTRAR_CXP_FRADIAN
- **F3:** documentación tabs (Auditoría, OP — en curso)
