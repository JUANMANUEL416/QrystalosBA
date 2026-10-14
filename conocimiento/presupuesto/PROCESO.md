# Presupuesto (notas internas)

Proceso del libro: `presupuesto` (familia `presupuesto`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/PresupuestoLayout.vue` (arbolMenu), `router/routes.js` `/ppto`, `components/presupuesto/*` (PTPTO, PRI, PTCDP, PTRP, PTCXP, PTPAG, PTRECO, PTRECA, PTNOT, PTMOV, PTRES, AnticiposCxp, SeguimientoGastosCatalogo, ConfPresupuesto, Infoppto*), `composables/ppto/*`.
- qrystalos.documentacion: solo PRI (CERRADO_PPTO). Sin ficha: PTPTO, PTPTODG, PTCDP, PTRP, PTCXP, PTPAG, PTRECO, PTRECA, PTNOT, PTRUB, PTREC, PTCLA, PTTMOV, PTDIV.
- IXONLINE/SQL (PREVERSION = 2.0.7, IDANT 2.0.6): idénticas salvo **SPQ_PPTO_RECO** (PRE ≠ liberada). SPQ_PTPTO no existe. SPQ_PPTO_RECO PRE sin CRUDPTNOT. SPQ_PPTO_REP sin PRESUPUESTO_FCXC ni TRAER_ANTICIPOCXP. PCEM no consultado.

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
