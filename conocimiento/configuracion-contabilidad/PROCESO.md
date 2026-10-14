# Configuración · Contable (notas internas)

Proceso del libro: `configuracion-contabilidad` (familia `configuracion`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/ConfLayout.vue` (arbolMenu[0] Contable), `router/routes.js` (/conf), `pages/conf/Conta/*`, `components/conf/Conta/*` (+ `help/HelpManual*`, `cueContaExcel.js`, `kmcomExcel.js`, `kmcomProcedencia.js`).
- qrystalos.documentacion/tablas: SED, AFU, CEN, KMCOM, USVGS, PRI documentadas. Sin ficha: CENH, HARE, KUNG, SEDUNG, SEDCONS, CUE, CUENIIF, TTEC, KCDE, KMCOMS, KTCO, FDIS, FDISD, COM, MND, MNDV, FIMP, FIMPD, FIMPDV, FCTSER, FCTSERD, RETEI, RETTER, RETUVT, PAR, MCHNIIF.
- DESAIX/SQLIX → `sql/`: SPQ_CONF_CONTABLE, SPQ_SED, SPQ_CUE_COL, SPQ_CUENIIF, SPQ_KMCOM_COL, SPQ_KCDE_COL, SPQ_TTEC_COL, SPQ_COM_COL, SPQ_PRI, SPQ_MND_COL, SPQ_MNDV_COL, SPQ_FIMP_COL, SPQ_FIMPD_COL, SPQ_FIMPDV_COL, SPQ_FCTSER_COL, SPQ_FCTSERD_COL, SPQ_RETEFTE_SALARIO, SPQ_CENH_COL. Todos PREVERSION idéntica a 2.0.7 (IDANT 2.0.6).
- PCEM (servidor5): no hizo falta consultarlo; el menú habilitado por grupo (MENUQ_COL · CONFIGURACION / USPROH) es dato de instalación y el libro documenta el árbol fijo del layout.

## Menú

Las quince opciones del árbol tienen ruta. Dos de ellas («Retención Honorarios», «Dependencias») apuntan a `conf.contableGenerales` sin `procedencia`, y la pantalla deja `tabGen` sin valor → contenido vacío. Sedes aparece también bajo Generales → Sedes → Sedes con ruta `conf.en_construccion`.

## Hallazgos (16, ids `confconta-*` en proceso.json y pendientes.json)

Prioritarios para desarrollo: EDITA_PAR no persiste MCUEORDEN_CXC/CXP/INGRESOS/EGRESOS; CRUDPRI EDITAR actualiza antes de evaluar el error de SI duplicado; FDIS_CRUD Editar con cambio de código no actualiza. Resto: ver proceso.json → hallazgos.

- Variables Vue no listadas al inicio y añadidas 2026-10-04 21:00: MANEJA_UNIDAD_NEG (Sedes/Áreas), IXCOUNTRY (variante de plan). PCEM no consultado.

