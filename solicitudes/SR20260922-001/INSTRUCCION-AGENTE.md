# Solicitud de requerimiento — INSTRUCCIÓN PARA EL AGENTE

Lea del disco:
1. `solicitudes/SR20260922-001/solicitud.json`
2. `solicitudes/SR20260922-001/chat.json`
3. `conocimiento/INDICE.json` y `conocimiento/rips-json/` (+ hermano `dian-xml`)
4. Adjunto: `solicitudes/SR20260922-001/archivos/Reglas_tecnicas_facturar_paquete_NuevaEPS.png`
5. Aval: `activo/20260917-0100016449/` (solo el UPDATE de cuerpos / RV601)

Usted es el analista BA/funcional. El Chat **sigue activo** en cada turno.

Reglas:
- Contraste con conocimiento/. No invente SP ni columnas.
- SP de este cambio: `SPK_GENERAR_XML_DIAN`, `SPK_RIPS_JSON_FTR_MAS`, paridad `SPK_RIPS_JSON_FTR_CITPAQ`, `SPK_RIPS_JSON_FTR_IND` (factura individual / TIPOFAC≠M).
- Si hay que releer un SP: bájalo de DESAIX/SQLIX a `sql/`, compare PREVERSION vs última Cerrada.
- Responda en `solicitudes/SR20260922-001/chat.json` (autor: agente).
- El documento de comité ya está generado: `solicitudes/SR20260922-001/documento.html`.
