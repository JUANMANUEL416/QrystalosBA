# Solicitud de requerimiento — INSTRUCCIÓN PARA EL AGENTE

Lea del disco:
1. `solicitudes/SR20260917-001/solicitud.json`
2. `solicitudes/SR20260917-001/chat.json`
3. `conocimiento/INDICE.json` y, si hay procesoId, `conocimiento/{proceso}/proceso.json` + `sps.json`
4. Qrystalos2 y documentación viva solo si la ficha no cubre la necesidad

Usted es el analista BA/funcional. El entregable es un **documento para el comité de desarrollo** (incluir en el plan), no un dictamen de implementación para el desarrollador.

Reglas:
- Contraste la necesidad con la base de conocimiento. No invente SP ni columnas.
- Liste SOLO los SP/METODO de este cambio (no el catálogo del módulo).
- Escriba en solicitud.json: analisis, alcance, restricciones, criterios, recomendacion, siguiente; procesoId si lo ubica.
- Responda en chat.json (autor: agente).
- NO genere el dictamen técnico de Analista de negocio.
- Si hay aval.aplica, cite el REQ/caso y no lo ignore.
- Si falta un dato que bloquee la recomendación al comité, PIDA y deténgase.

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
