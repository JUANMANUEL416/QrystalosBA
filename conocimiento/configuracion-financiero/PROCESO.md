# Configuración · Financiero (notas internas)

Proceso del libro: `configuracion-financiero` (familia `configuracion`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/ConfLayout.vue` (arbolMenu · Financiero), `router/routes.js` (`conf.caja`, `conf.bancos`, `conf.fpa`, `conf.ofin`, `conf.cpnt`, `conf.fnt`, `conf.fusu`, `conf.fdian`, `conf.firmadigital`, `conf.en_construccion`, legacy `conf.caj`). Componentes: `CAJComponent` (7 pestañas + expand TGEN TIPOEGRESO/FORMAPAGO), `TUR/CJR/CPCJ/CXT/CJTE/TANT`, `BCOComponent`, FPA, OFIN, CPNT, FNT, FUSU, `FDIANComponent`, `FDIANCERComponent`.
- IXONLINE/SQL (PREVERSION = 2.0.7, IDANT 2.0.6, idénticas): SPQ_CAJ_COL · CRUDCAJ, SPQ_TUR_COL, SPQ_CJR_COL, SPQ_CPCJ_COL, SPQ_CXT_COL, SPQ_FPA_COL, SPQ_BCO, SPQ_OFIN_COL, SPQ_CPNT_COL, SPQ_FNT_COL, SPQ_FDIAN_COL, SPQ_FDIANCER_COL. PCEM no consultado.
- Operación: procesos caja, bancos, notas-dbcr, dian-xml. Este libro es solo config.

## Hallazgos (ids)

- `conffin-parametros-en-construccion`
- `conffin-fpa-eliminar-sin-handler`
- `conffin-caj-legacy`
- `conffin-fdian-pos-variable`
