# Proceso: Tesorería · Bancos

**Estado:** completo (libro reorganizado 2026-10-03)  
**Módulo:** BMOV  
**Ventana:** `/admin/Cuentas` (`admin.cuentas`) → `CuentasPage.vue` → `tesoreria/BCTComponent.vue` (tarjetas BCT) → `BMOVComponent.vue` (libro) · diálogos `BCTCComponent` (conciliación), `BCTDComponent` (chequeras), `BCTTARComponent` (cuotas TC)  
**Configuración:** `/conf/bancos` (`BCOComponent`), `/conf/ofin` (`OFINComponent`)  
**Contabilidad:** `/cont/conciContables` → `CONCBMOVComponent` · `/cont` Otros módulos → `OMBancosComponent` · `/cont/auxBancos` → `AuxiliarBancosComponent`

> Fuente SQL: IXONLINE/SQL releído 2026-10-03, PREVERSION idéntica a la liberada 2.0.7: `SPQ_BMOV` (19 METODO), `SPQ_BCTC` (18), `SPQ_BCTD` (13), `SPQ_BANCOS_AUXILIAR` (5), `SPK_OK_BMOV`, `SPK_DESOK_BMOV`, `SPK_UPSERT_BCTSM`, `SPK_CAMBIA_BCT_PCJ_CAJA`.
> `SPQ_BCO`, `SPQ_OFIN_COL`, `SPK_NC_CONTAB_BMOV`, `SPK_RECALCULO_BANCOS`, `SPK_ACTUALIZA_SALDO_BANCO` leídos 2026-09-06.
> Tablas BCT, BMOV, BMOVD, BCTC, BCTCD, BCTSM, BCTD, BCTDD, BCTTAR sin ficha en `qrystalos.documentacion`. No inventar columnas.

## Qué es

El libro de cada cuenta bancaria. **BCT** = banco + sucursal + número, con tipo (TGEN TIPOCUENTABCT; `TC` = tarjeta de crédito con CUPODISP), COD_CONTABLE (CUE activa, detalle, clase 1) y SALDO calculado.
**BMOV** cabecera (FECHAOPERACION, FECHAOK, IDOPERACION OFIN, DESCRIPCION, VLROPERACION = Σ BMOVD.VLRITEM, ESTADO P/O/A, PROCEDENCIA BANCOS/CAJA/CONTAB, GENCXP, NROCOMPROBANTE, CONTABILIZADA 0/1/2) y **BMOVD** renglones (FORMAPAGO, BANCODOC, NODOCUMENTO, VLRITEM, IDTERCERO, CUENTA, RECAUDO, RNOMI, ENPAGOS, VLRLEGALIZADO, CCOSTO).

**OFIN** (operación financiera) manda: TIPO DB/CR, COMPROBANTE, CUENTA, RECAUDO, GENCXP, MCCOSTO, RNOMI, TRASLADO + cuenta destino.

**No es:** Caja (recibos llegan con PROCEDENCIA CAJA y se confirman allá), CxP (el pago a proveedor se gira desde CxP), Cartera · Conciliaciones (FCONCI) ni el auxiliar contable (`/cont/auxBancos`).

## Configuración (orden)

1. **BCO/BSU** — `SPQ_BCO` GUARDAR/EDITAR/ELIMINAR + GUARDARBSU/EDITARBSU/ELIMINARBSU. IDTERCERO único por banco; ELIMINAR bloqueado con sucursales. Variable `TERCATBANCO`.
2. **BCT** — `SPQ_BCTC` GUARDARBCT/ACTUALIZABCT (ELIMINABCT no lo invoca el FE). Formatos: FORMATODEPAGO 01-04, FORMATOCHEQUE 01-05, TIPO_PLANO (BANCO_BOGOTA/COLPATRIA/BANCOLOMBIA), IDFORMATO. Perú (`IXCOUNTRY`): CCI, TIPOCUE, IDSEDE.
3. **OFIN** — `SPQ_OFIN_COL` CRUDOFIN. RNOMI solo si `SOLICITA_RECA_NOMINA = SI`. ELIMINAR no revisa BMOV (botón oculto).
4. **PRI** abierto en la fecha del movimiento. **FPA** para renglones. **TGEN GENERAL/BCTC** conceptos de partida.

## Ciclo del movimiento

1. **Nuevo** — GUARDABMOV (PROCEDENCIA BANCOS, ESTADO P; valida PRI). Renglones GUARDABMOVD / ACTUALIZABMOVD / ELIMINABMOVD; TERCONTABLE trae cuenta del tercero; GETFORMAPAGOS.
2. **Confirmar (✓)** — FE exige ≥ 1 renglón. CONFIRMARBMOV → `SPK_OK_BMOV`: ya O → KO; PRI existe/abierto; ESTADO O; `SPK_RECALCULO_BANCOS` (TC: cupo + DB − CR); si PROCEDENCIA ∈ {BANCOS, CONTAB} y hay BMOVD → `SPK_NC_CONTAB_BMOV` (MCP procedencia BMOV, CONTABILIZADA 1); si OFIN.TRASLADO = 1 clona BMOV+BMOVD en cuenta destino.
3. **Desconfirmar (↺)** — solo BANCOS + O. DESCONFIRMAVAL: ENPAGOS = 1 → KO «ya se encuentra en pagos en cartera»; PRI cerrado → PREGUNTA. DESCONFIRMABMOV: MCPE existe → borra MCHE/MCPE **y termina** (ver pendiente); si no → MCP ESTADO 2: `SPK_REVERSAR_MCP_BANCO` (PRI cerrado) o ESTADO 1; `SPK_DESOK_BMOV` (RETURN silencioso si ENPAGOS o FCXP contabilizada; anula FCXP; MCP anulado; BMOV P; saldo); limpia NROCOMPROBANTE/CONTABILIZADA.
4. **Anular (⊘)** — solo BANCOS + P. ANULARBMOV: RAZONANULACION, FECHAANU, USUARIOANULA; EXEC `SPK_CONTAB_BMOV`.
5. **Generar Cxp** — GENCXPBMOV (O o CONTABILIZADA 1, GENCXP 1, sin CNSFCXP) → `SPK_GENCXP_MOVIN_BANCO`. Tarjeta: GENCXPBCTTAR → `SPK_GEN_CXP_BCTTAR`.
6. **Cambiar tercero** — renglón de BMOV BANCOS + O + CONTABILIZADA 1: ACTUALIZA_TERCERO → `SPK_MCP_ACT_TER`.
7. **Cambiar cuenta** — solo PROCEDENCIA CAJA + O + USGRUH `MENUQ_ADMINISTRATIVO · CAMBIAR_CTA_BMOV_CAJA`: CAMBIAR_CUENTA_BANCARIA → `SPK_CAMBIA_BCT_PCJ_CAJA` (anula origen, crea+confirma destino, PCJ/FCJ, regenera MCP con `SPK_CONTAB_CAJA_ING/EGR` + `SPK_NC_CONFIRMAR_CONTAB`, USLOG).
8. **Reliquidar** — `SPQ_BCTC` RELIQUIDAR → `SPK_RECALCULO_BANCOS`.
9. **Distribuye ADRES** (Perú) — DISTRUYE_ADRES: reparte renglón O sin ENPAGOS a otro tercero; `SPK_NC_CONTAB_DISTRI_ADRES`.

## Recaudos (legalizar)

Renglón con RECAUDO = 1, BMOV O, ENPAGOS = 0 y VLRITEM − VLRLEGALIZADO > 0 aparece en Cartera · Recaudos (Ingreso Bancos). INSERTAR → ENPAGOS 1; APLICARPAGO → VLRLEGALIZADO (`SPK_PAGOSCXC` BANCOS). Informe **Consignaciones**: `SPQ_BCTC` REPORTE_CONSIGNACIONES (Todas / Legalizadas / No legalizadas, por tercero o todos). Caja: `SPK_ACTUALIZA_SALDO_BANCO` suma PCJ a BCT sin pasar por BMOV.

## Conciliación bancaria (BCTC) — REQ 0100016329 implementado en 2.0.7

- **Nueva conciliación** GUARDACONCILIACION (FECHACON, SALDOB extracto, SALDOCONT libros, OBSERVACION; `SPK_GENCONSECUTIVO` @BCTC). ACTUALIZACONCILIACION solo Abierta.
- **Partidas** BCTCD: GUARDABCTCD / ACTUALIZABCTCD / GETBCTCD (fecha, concepto TGEN GENERAL/BCTC vía OPERACIONES/GUARDAOPERACION/ELIMINAOPERACION, beneficiario, valor, TIPO CR/DB, detalle).
- **Cerrar** CIERRACONCILIACION: Cerrada; ANO/MES de FECHACON; `SPK_UPSERT_BCTSM`: SI = SF mes anterior (0 si falta), DB/CR = Σ BMOV.VLROPERACION ESTADO O por OFIN.TIPO y FECHAOK en el mes, SF = SI + DB − CR; SALDOB/SALDOCONT de la BCTC; AVISO si |SF − SALDOCONT| > 0,01. Upsert **BCTSM**.
- **Auxiliar de saldos por mes**: LISTAR_AUXILIAR_MES; GENERAR_AUXILIAR_MES regenera (exige conciliación Cerrada del mes). Botones PDF/Excel del auxiliar ocultos (`v-if="false"`). Ver movimientos del mes filtra el libro.
- **Imprimir** IMPRIMIR_CONCILIACION (cabecera, totales por operación, BCTCD) solo Cerrada.

## Tres «conciliaciones»

| | BCTC (Tesorería) | CONCBMOV (Contabilidad) | Auxiliar de bancos (Contabilidad) |
|---|---|---|---|
| Compara | Extracto vs libros + partidas | BMOV PROCEDENCIA BANCOS vs MCP/MCPE PROCEDENCIA BMOV (±0,01) | MCH de la cuenta contable por periodo/fechas |
| Produce | Acta + BCTSM + PDF | Semáforo CONTABILIZADA 0/1/2; ENV_CONTA_OTROS_MODULS; `MCPE_COL · RECONSTRUIR`; Excel | MCH.CONCILIADO / FECHACONCILIACION (`SPQ_BANCOS_AUXILIAR` OBTENER_MOVIMIENTOS → RPDX → SALVAR_CONCILIACION); PDF/Excel |

OM Bancos (`OMBancosComponent`): BMOV ESTADO O por año/mes/cuenta/contabilizada → `SPQ_CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS` PROCEDENCIA BMOV. `SPK_CONTAB_MASIVA` también recorre BMOV.

## Chequeras y tarjeta

- **BCTD/BCTDD** (`SPQ_BCTD`): GUARDABCTD/EDITABCTD (editar solo sin documentos), GENDOCUMENTOS, GUARDABCTDD/EDITABCTDD/ELIMINARBCTDD, ENTREGARBCTDD (KO «Recibo no se pudo cerrar»), ANULARBCTDD, LIBERARBCTDD, GUARDAR_ESTADO, ACTUALIZARCNSALFA (KO si anulado).
- **BCTTAR**: cuotas por año/mes, FCTSER cuentas contables (`FCTSER_COL · CRUDFCTSER`), Generar CxP del mes (`SPQ_BMOV · GENCXPBCTTAR`).

## Reportes

REPORTE_LISTADO_MOVIMIENTOS (una cuenta, filtros del libro) · REPORTE_LISTADO_MOVIMIENTOS_MULTI (Reportes bancarios, varias cuentas; PDF por cuenta y Excel) · REPORTE_CONSIGNACIONES · IMPRIMIR_CONCILIACION · Auxiliar de bancos PDF/Excel.

## Permisos y variables

Pantalla: `admin.cuentas`, `conf.bancos`, `conf.ofin`, `cont.conciContables`, `cont.auxBancos`. Único USGRUH por acción: `CAMBIAR_CTA_BMOV_CAJA`. Variables: `TERCATBANCO`, `SOLICITA_RECA_NOMINA`, `IXCOUNTRY`; catálogos TIPOCUENTABCT (TC), TGEN GENERAL/BCTC, OFIN, PRI.

## Pendientes (2.0.7)

- `bancos-desconfirmar-mcpe`: DESCONFIRMABMOV con MCPE existente no ejecuta SPK_DESOK_BMOV ni limpia BMOV.
- `bancos-sin-permisos-por-accion`: confirmar/desconfirmar/anular/reliquidar/cerrar conciliación sin USGRUH.
- `bancos-auxiliar-mes-pdf-oculto`: PDF/Excel del auxiliar mensual con `v-if="false"`.
- `bancos-doc-tablas`: fichas de tablas (BCTSM nueva).
- ACTUALIZABCT devuelve mensaje de duplicado cuando la cuenta no existe. CRUDOFIN ELIMINAR no revisa BMOV.
