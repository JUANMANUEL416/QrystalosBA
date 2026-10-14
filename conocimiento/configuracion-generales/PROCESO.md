# Configuración · Generales (Planes y Terceros) (notas internas)

Proceso del libro: `configuracion-generales` (familia `configuracion`). Documentado 2026-10-04.

## Fuentes

- Qrystalos2: `layouts/ConfLayout.vue` (arbolMenu · Generales → Planes, Contratos IPS, Terceros/Categorías). Rutas `conf.planes`, `conf.cnt`, `conf.categorias`, `conf.terceros`. Componentes PLN/CPPAF/PLNU, CNT/CNTD, CAT, TER + TEXCA (`terExcel.js`). Permisos MENUQ_PLANES (BTN_*) y TERCEROS_WEB. El resto de Generales (servicios, tarifas, ADX, sedes, médicos…) queda para otro proceso.
- IXONLINE/SQL (PREVERSION = 2.0.7, IDANT 2.0.6): SPQ_CONF_PLANES **PREVERSION distinta de la liberada** — validar en preversión, no pedir el cambio a ciegas. SPQ_CONF_CPPAF, SPQ_CNT, SPQ_TER_COL, SPQ_TEXCA. **SPQ_CONF_CAT no está en SQLIX** (ni PREVERSION, ni 2.0.7, ni IDANT 2.0.6). PCEM no consultado.

## Hallazgos (ids)

- `confgen-conf-cat-ausente-sqlix`
- `confgen-conf-planes-pre-distinta`
- `confgen-inca-option-exige-tabla`
- `confgen-tercatcontratante`
