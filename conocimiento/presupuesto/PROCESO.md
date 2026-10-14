# Presupuesto (notas internas)

Proceso del libro: `presupuesto` (familia `presupuesto`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/PresupuestoLayout.vue` (arbolMenu), `router/routes.js` `/ppto`, `components/presupuesto/*` (PTPTO, PRI, PTCDP, PTRP, PTCXP, PTPAG, PTRECO, PTRECA, PTNOT, PTMOV, PTRES, AnticiposCxp, SeguimientoGastosCatalogo, ConfPresupuesto, Infoppto*), `composables/ppto/*`.
- qrystalos.documentacion/tablas: **23** operativas + **4** históricas (**PTRECOH, PTCDPH, PTRPH, PTPTOIH**) vía `fichas-lote-presupuesto-hist-20261013.json` · **SPK_GEN_HISTORICO_PPTO**. Opcional: resto *H (PTCDPDH, PTCXPH…).
- **CRUDPTNOT:** PREVERSION/liberada **2.0.9** — SPQ_PPTO_RECO **sin** la rama; FE sí llama. Confirmar nota: SPK_APLICA_NOTA_PPTO.
- IXONLINE/SQL (PREVERSION = 2.0.7): **SPQ_PTPTO no existe** — usar **SPQ_PRESUPUESTO** (CRUDPTPTO). Mapa MODELO→SPQ: `catalogo-sp-fe.json`. SPQ_PPTO_RECO PRE sin CRUDPTNOT. SPQ_PPTO_REP sin PRESUPUESTO_FCXC ni TRAER_ANTICIPOCXP.

## Menú

Árbol fijo. Habilitación MENUQ_COL · PRESUPUESTO. `ppto.en_construccion` siempre en la lista de permisos del layout. Seguimiento Gastos (REQ 0100016310) vive en Gastos; Históricos → Seguimiento Gasto sigue en construcción.

## Hallazgos (ids `ppto-*` en proceso.json)

- `ppto-crudptnot-fe-adelantado`
- `ppto-ppto-reco-pre-distinta`
- `ppto-traer-anticipocxp-sin-rama`
- `ppto-presupesto-fcxc-sin-rama`
- `ppto-historicos-en-construccion`
- `ppto-seguimiento-gasto-duplicado`
- `ppto-typo-recuados`
- `ppto-print-ingreso-reco`
- `ppto-spq-ptpto-no-existe`
- `ppto-tablas-sin-ficha`
- `ppto-sin-envio-conta`
- `ppto-enviar-nomina-silencio`
- `ppto-informes-clarion-fallback`
- `ppto-spk-historico-sin-pantalla`

## Capa 5

No hay ENV_CONTA / MCP. No inventar OM.
