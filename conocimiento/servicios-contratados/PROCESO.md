# Servicios contratados (notas internas)

Proceso `servicios-contratados`. Arranque 2026-10-15.

## Fuentes leídas (PREVERSION = última Cerrada 2.0.9, IDANT 2.0.8, cuerpos idénticos)

Vistas: `SERTOT`, `SERTOT1`, `SERPRO`, `SERETP`, `SERESP`, `SERESP1`, `SERESPPCOSTO`, `SERETPPCOSTO`, `SERETPPAR`, `SERETPPARPCOSTO`, `SERTOT_PAQNOR`, `VWK_SERTARIFA`.
Función: `FNK_VLR_SERTOT`. Procedimiento: `SPQ_TER_SERTOT` (solo EXPORTAR).

Pantallas: `ConfLayout.vue` Generales → Servicios (`/conf/servi`, MODELO SER) y Tarifas (`/conf/tar`, MODELO TAR). Terceros → plan (PPT) → Excepción Servicios (`ExceptServiceComponent`, MODELO ESP) y Excepción Tarifas / prefijo (`ExceptPrefijoComponente`, MODELO ETP). Consulta «Servicios contratados» (`ConsultContratosComponent`, Tabla SERTOT + TER_SERTOT · EXPORTAR). Selector de venta `SERTOT1Component` (Tabla SERTOT1).

## Aún no leídos

`SPQ_SER`, `SPQ_PPT`, `SPQ_PPTSER`. `SPQ_TAR` no apareció en PREVERSION ni 2.0.9 ni 2.0.8 (la pantalla igual llama MODELO TAR). Falta confirmar `SPQ_ESP` y `SPQ_ETP`. `SERPRO_PAQNOR` no leído (lo usa `SERTOT_PAQNOR`).

Hermanos ya documentados: `configuracion-generales` (CAT, TER, PPT, CNT, PLN, CPPAF) y el uso del precio en facturación / autorizaciones (`FNQ_VAL_SERTOT_PERU`, `SPK_CONFIRMAR_AUT`).
