# Proceso: Cartera · Reportes e informes

**Estado:** completo (libro reorganizado 2026-10-03)  
**Módulo:** CARTERA_RPT  
**Ventana:** `/admin/InformesCartera` (`Admin.RptCarte`) → `ConsRptCarteraPage.vue` → `cartera/Informes/*` y `consultasReportes/*`  
**Satélites:** Seguimiento Cartera (`admin.SeguiCXC`, `SeguiCarteComponent`, FSEG) · Cierre cartera (`Admin.Cierre`, `CerrarProceAdmComponent`, FCARTH)

> Fuente SQL: IXONLINE/SQL `SPQ_CARTERA_RPT` (16 METODO) releído 2026-10-03; PREVERSION idéntica a la liberada 2.0.7.
> `SPQ_CARTERA_IMPRESION`, `SPQ_FSEG_COL`, `SPK_AJUSTE_FCXCDV_NC`, `SPK_REPORTES_VARIOS_CARTERA` leídos 2026-09-06.
> El FE invoca `EXECUTE_SPK_REPORTES_VARIOS_CARTERA` y `TRAER_DETALLE_HISTORICO`, que **no existen** en el catálogo (ni PREVERSION ni 2.0.7).

## Qué es

Ventana de consulta de cartera: trece informes de **solo lectura** que muestran el resultado de radicar, recaudar, hacer notas, responder glosas y conciliar.
Responde cuatro preguntas: qué pasa con una factura, qué cuentas de cobro se entregaron, cuánto deben y hace cuánto (aging), y cuánto se radicó y recaudó cada mes.

Excepciones a «solo lectura»: **Reliquidar** (`RELIQUIDA_FTR` → `SPK_RELIQUIDA_FTR`), **Ajuste de Saldos Cartera** desde el Detalle (`EJECUTAR_AJUSTE_NC_FCXCDV` → `SPK_AJUSTE_FCXCDV_NC`, nota crédito con concepto CPNT) y **Devoluciones** (responder, módulo FCXCR).

**No es:** radicar (Cartera · Radicación), recaudar (Cartera · Recaudos), hacer notas (Cartera · Notas), responder glosas ni conciliar. Tampoco es el informe contable de cartera (`/cont`).

## Mapa de informes (13)

| Pregunta | Informe | Componente | METODO principal |
|---|---|---|---|
| Qué pasa con una factura | Facturas CXC | `FactEnCxcComponent` | `/read` FCXC/FTR + `TRAER_TOTAL1`; Detalle: `TRAE_DETALLES`, `TRAER_CAB_AJUSTE_NO_CREDITO` |
| Facturas liberadas sin cuenta de cobro | Facturas sin CXC | `FactSinCxcComponent` | `/read` FTR sin FCXCD |
| Soporte de lo radicado | Facturas radicadas | `FacturasRadicadasComponent` | `/read` FCXC radicadas por tercero |
| Qué CXC se entregaron / faltan | CXC entregadas · CXC sin entregar · Cuentas de cobro | `CxcEntregadas*`, `CxcSinEntregar*`, `CuentasCobro*` | `/read` FCXC + `SPQ_CARTERA_IMPRESION` (PDF) |
| Devoluciones de la EPS | Devoluciones | `CXC/FCXCRComponent` | FCXCR (ver Cartera · Radicación) |
| Cuánto deben y hace cuánto | Vencimientos (6 pestañas) | `VtosCxcComponent` + `Vtos*` | `TRAER_TOTAL1`, `ACTUALIZAR_DATOS_ACTUAL_TOTAL`, `TRAER_TOTAL_POR_REGIMEN[_DIALOG…]`, `TRAER_TTEC`, `TRAER_TOTAL_POR_PLAN[_DIALOG_CXC]`, `TRAER_TOTAL_HISTORICO[_CONTABLE]`, `EXPORT_DETA`, `EXPORT_DETA2`, `VERIFICAR_IDTERCERO` |
| Cuánto se radicó / recaudó por mes | Resumen radicación · Resumen recaudos | `ResumenRadicacion*`, `ResumenRecaudos*` | `/read` + PDF |
| Pagos en banco sin legalizar | Recaudos en bancos | `RecaudosEnBancos*` | `/read` FREC por estado |
| Indicadores varios | Varios x mes | `consultasReportes/reportes/ReportesComponent` | `EXECUTE_SPK_REPORTES_VARIOS_CARTERA` (**ausente**) → lee RPDX de CNSID `0116608638` |
| Atenciones sin facturar | Estado de admisiones | `consultasReportes/EstadoAdmisiones` | `/read` HADM/CIT/AUT vivo |

## Vencimientos (aging)

Pestañas: **Actual** (una fila por tercero, filtros régimen / tipo tercero / radicadas / clase glosa / particulares), **Actual-Total** (`ACTUALIZAR_DATOS_ACTUAL_TOTAL` recalcula y guarda), **Régimen**, **Tipo Tercero** (TTEC), **Por Plan**, **Histórico** (FCARTH por año/mes, con variante contable).
Columnas: Por vencer · 0-30 · 31-60 · 61-90 · 91-120 · 121-150 · 151-180 · 181-360 · 361+ · Total. Marcas por fila: NR (no radicada), GL (con glosa), PA (particular), CJ (cobro jurídico), CA (castigada), DV (devuelta) — ver semáforo `marcasAging`.
Salidas: PDF por tercero y rango (`SPQ_CARTERA_IMPRESION`), Excel detalle (`EXPORT_DETA` / `EXPORT_DETA2`), export Histórico (`TRAER_DETALLE_HISTORICO`, **ausente**).

## Rutina de cierre de mes

1. Facturas sin CXC → que no queden liberadas sin cuenta de cobro.
2. CXC sin entregar → radicar lo pendiente.
3. Recaudos en bancos → legalizar pagos pendientes.
4. Vencimientos → Actual-Total → Procesar; revisar Reliquidar en facturas con saldo inconsistente.
5. Cierre cartera (`Admin.Cierre`) → crea la foto FCARTH del mes (`SPQ_PRI · CERRAR_FACTURA`); reabrir (≤ 25 días, `ABRIR_FACTURA`) borra la foto.
6. Histórico ↔ contabilidad: pestaña Histórico (contable) contra el saldo de la cuenta de cartera.

## Seguimiento de cartera

`/admin/SeguiCXC` → cuenta de cobro → Nuevo seguimiento (`SPQ_FSEG_COL`, tabla FSEG: fecha, contacto, compromiso, observación). Bitácora de cobro; no mueve saldos.

## Variables y catálogos

- `TERCATAFILIADO`: categoría de tercero que la casilla «Incluir particulares» excluye por defecto.
- `FACTSEDE`: logo de los PDF.
- Catálogo TTEC: filtro y pestaña Tipo Tercero (tercero sin TTEC no aparece agrupado).
- Catálogo CPNT: concepto obligatorio en Ajuste de Saldos Cartera.
- Cierre de cartera mensual: sin cierre no hay Histórico de ese mes.

## Permisos

Solo acceso a pantalla: `Admin.RptCarte`, `admin.SeguiCXC`, `Admin.Cierre`. No hay USGRUH por botón: Reliquidar y Ajuste NC quedan abiertos a quien entra (pendiente `rptcartera-sin-permisos-por-accion`).

## Defectos conocidos (2.0.7)

- **Varios x mes / Estado admisiones – Procesar** no recalcula: `EXECUTE_SPK_REPORTES_VARIOS_CARTERA` no existe en `SPQ_CARTERA_RPT`; el FE no maneja el error y muestra RPDX viejo (`rptcartera-execute-spk-ausente`).
- **Histórico – export detalle por tercero** falla: `TRAER_DETALLE_HISTORICO` ausente (`rptcartera-traer-detalle-historico-ausente`).
- Binding P.Jurídico / DEVUELTAS está en código comentado: no es defecto, es funcionalidad retirada.

## Tablas (sin ficha en `qrystalos.documentacion`; no inventar columnas)

FCXC, FCXCD, FCXCDV, FCXCR, FTR, FREC, FNOT, FCARTH, FSEG, RPDX, TER, TTEC, CPNT.
