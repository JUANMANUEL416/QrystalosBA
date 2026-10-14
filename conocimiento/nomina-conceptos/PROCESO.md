# Nómina · Conceptos y novedades (configuración)

Proceso `nomina-conceptos` · módulo NOMI · familia Nómina y Personal.
Ruta en Qrystalos2: **Nómina → Configuración** (`/nom/conf`, `pages/nom/conf/indexPage.vue`).

Este libro explica **cómo se arma la nómina antes de liquidar**: nóminas y períodos,
cargos y escalas salariales, plantillas, conceptos (NCON) con su definición vigente
(NCOND), eventos de novedad (NEVE), parámetros, agrupaciones de aportes (NPRF),
datos del empleado que alimentan el cálculo (NEMPHIS, NEMPDA, NEMPE, NPRFE) y la
configuración de retención en la fuente (RETTER / RETUVT / RETEI).

La operación (prenómina, liquidar, primas, libranzas, DIAN) está en el libro
hermano **Nómina · Liquidación y procesos** (`nomina`).

## Fuente SQL

Todos los procedimientos fueron leídos desde IXONLINE/SQL, canasta **PREVERSION**,
idéntica a la última liberada **2.0.7** (anterior 2.0.6). Fichas en `sps.json`.

## Capas

| Capa | Qué resuelve | Tablas |
|---|---|---|
| 01 Estructura | Nóminas, períodos, periodicidad, cargos/escalas, plantillas | NOMI, NOMIE, NPER, NPPAG, NCAR, NCARNG, NCARNGV, NCARNGE, NPLT, NPLTCA, NPLTCO |
| 02 Conceptos | Maestro NCON, definición vigente NCOND y sus pestañas | NCOND, NCONDD, NCONDF, NCONDTC, NCONDC, NCONDA, NCONDB, NCONDBD, NCONT*, NCONCOL |
| 03 Novedades y parámetros | Eventos NEVE/NEVED, parámetros NPAR/NPARV, agrupaciones NPRF/NPRFD/NPRFT | — |
| 04 Empleado | Histórico laboral, particulares, exclusiones, afiliaciones | NEMPHIS, NEMPDA, NEMPE, NPRFE, NPRFED, NEMPC |
| 05 Retención | Terceros sujetos, tabla UVT, conceptos base | RETTER, RETUVT, RETEI |

## Hallazgos (2026-10-03)

- **REQ 0100016359** (área y centro de costo en el histórico del empleado): ya
  implementado en 2.0.7 — `SPQ_NOM_NEMPHIS.GUARDAR` escribe `IDAREA` y `CCOSTO`, y
  `HistorialComponent` muestra el selector de centro (CEN).
- **REQ 0100016378** (nombre alterno del concepto en la colilla): ya implementado —
  `NCONCOL` + `FNK_NOM_NOMBRE_COLILLA`, permiso `BtnNombreColilla`.
- Ningún SP de configuración valida USGRUH por acción; el permiso vive solo en los
  botones Vue (`MENUQ_NOMINA`).
- `SPQ_NOM_CONCEPTOS.ELIMINAR` y `SPQ_NOM_NOMI` no revisan uso previo (dependen de FK).
- Renta exenta 25 % en retención se aplica sin tope UVT mensual (ver libro de
  Liquidación, capítulo Retefuente).
- Sin ficha: `FNK_VALOR_NCONDC`, `FNK_VALOR_NCONDTC`, `SPK_AJUSTE_SALARIO_NEMP`,
  `SPK_QUITA_AJUSTE_SALARIO_NEMP`, Formulario Único (`NFUTC`).
