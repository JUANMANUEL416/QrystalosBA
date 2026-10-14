# Configuración · Activos F. (notas internas)

Proceso del libro: `configuracion-activos` (familia `configuracion`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/ConfLayout.vue` (arbolMenu · Activos F.), `router/routes.js` (`conf.iacttipoact`, `conf.iact_itar`, `conf.iacteventos`, `conf.iactgrupos`, `conf.iacteqxsec`, `conf.notixsec`, `conf.articulo`, `conf.en_construccion`). Duplicado 1:1 en `pages/iact/conf_*` (`TipoActivoComponent` TIPOAF, `EventosComponent` EVENTOAF, `GruposComponent` GRUPAC, `TipoArticuloComponent` ITAR, `ArticulosComponent` IART, `EquiposXSectorComponent` EQXSEAF, `NotifiParXSectorComponent` NOTIFPARADAAF). Gestión real: `/iact/gestion`.
- qrystalos.documentacion: IART.md (FK a IACT). Sin ficha: IACTT, IACTE, TGEN de grupos/sectores.
- IXONLINE/SQL (PREVERSION = 2.0.7, IDANT 2.0.6, idénticas): SPQ_TIPOAF, SPQ_EVENTOAF, SPQ_GRUPAC, SPQ_ITAR, SPQ_EQXSEAF, SPQ_NOTIFPARADAAF, SPQ_IART (listado; cuerpo en proceso Inventario), SPQ_IACT · TRE_TIPOACT. PCEM no consultado.

## Hallazgos (ids)

- `confact-activos-en-construccion`
- `confact-articulos-pendientes`
- `confact-useusvgs-sin-get`
- `confact-iactt-iacte-sin-ficha`
- `confact-no-confundir-iart-inventario`
