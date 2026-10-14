# Configuración · Sistemas (notas internas)

Proceso del libro: `configuracion-sistemas` (familia `configuracion`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/ConfLayout.vue` (arbolMenu · Sistemas), `router/routes.js` (`conf.usvgs`, `conf.tgen`, `conf.grupos`, `conf.usuarios`, `conf.permesp`, `conf.ubeq`, `conf.defaults`, `conf.logauditoria`, `conf.klog`, `conf.historialmensajes`, `conf.historialacceso`, varias `conf.en_construccion`).
- qrystalos.documentacion: USVGS.md, TGEN.md, USUSU.md, USGRU.md, USGRUH.md, USPROH.md.
- IXONLINE/SQL (PREVERSION = 2.0.7, IDANT 2.0.6, idénticas): SPQ_USVGS_COL · ACTUALIZA_DATO, SPQ_TGEN_COL · GUARDAR / ELIMINAR / OPCIONES_TGEN, SPQ_USGRU, SPQ_USUSU_COL · CRUDUSUSU / REINICIAR_CLAVE_WEB, SPQ_UBEQ_COL · CRUDUBEQ. Logs: USLOG/USLOGH, KLOG, KSMSL/QRY_ENVIOS, ULOGIN (listado). PCEM no consultado.

## Hallazgos (ids)

- `confsis-opciones-en-construccion`
- `confsis-usvgs-no-crea`
- `confsis-procedimientos-sin-pantalla`
- `confsis-eliminar-usuario-oculto`
