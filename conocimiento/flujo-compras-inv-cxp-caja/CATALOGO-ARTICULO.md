# Catálogo artículo — requisitos para el flujo de inventario

Documento de referencia (2026-09-19). Detalle JSON: `catalogo-articulo.json`. SP: `SPQ_IART` (PREVERSION = 2.0.3).

## Orden de configuración recomendado

1. **ITAR** — tipo con reglas (loteo, vencimiento, IVA, consecutivo).
2. **IART** — artículo (`GUARDAR`); consecutivo automático si `ITAR.MCNS` o `ESAUTOMATICO`.
3. **SER** — `VALIDA_SERVICIO` + `CRUDSERVICIO` si `CREARSER=1` (IDSERVICIO distinto de `DEINVNODESER`).
4. **KMCOM** — prefijo del SER + centro de costo (compras `CXP_COMPRAS`, inventario `MOV_INVENTARIO`).
5. **ILPRE** (opcional) — si el camino es cotización → `GENERAR_OC`.

## ITAR — lo que el flujo exige

| Característica | Por qué importa |
|----------------|-----------------|
| **MLOTEO** | **1** = sin pantalla de loteo (ITRAH queda INICIAL=1 al confirmar). **0** = lotear en tránsito (`IZSOL_TRANSITO`). |
| **MFECHAVENCIMIENTO** | `CONF_ENTRADA` exige fecha en líneas cuando el tipo lo marca. |
| **MIVA / impuesto en ITAR** | Coherencia con `IART.IDIMPUESTO`; afecta IMOVH y FCXPD. |
| **PRECNS / MCNS** | Generación de `IDARTICULO`; error típico: «Revise ITAR PRECNS». |
| **MPRINCIPAL** | Artículos hijo en recepción OC (mismo `IDSERVICIO`). |
| **MSTOCK** | Si no controla stock, no debe usarse en movimientos que mueven IEXI. |

## IART — lo que debe quedar bien

| Característica | Validación / SP |
|----------------|-----------------|
| **IDITAR + Activo** | Existe en catálogo; `ESTADO` Activo para comprar. |
| **IDSERVICIO** | No dejar solo `DEINVNODESER` si hay contabilidad/CxP: crear **SER** vía flujo FE. |
| **IDIMPUESTO / IDCLASE_IMP** | Obligatorio si `USVGS IMPUESTO_OBL=SI`. |
| **PRINCIPAL** | Alineado con variantes en tránsito (`ON_PROCESAR`). |
| **REGINVIMA, CODCUM** | Regulatorio y cotizaciones. |
| **UNID_VENTA** | Unidad coherente en cotización y OC. |

## Efecto downstream (resumen)

```
ITAR + IART (+ SER + KMCOM)
  → FCOMD / recepción / loteo
  → IMOVH (costo, IVA, vencimiento)
  → FCXPD + CONTABILIZAR_FCXP
  → SPK_NC_CONTAB_INV (salidas)
```

## Variables USVGS críticas

Ver lista en `catalogo-articulo.json`. Las más frecuentes en incidentes: `DEINVNODESER`, `IMPUESTO_OBL`, `VALID_CCOSTO_CXP`, `CONTAB_INV_IVA_ITAR`, `IDINVDIASPARAVENCER`, `IDINVMOV_COMPRAS`.

## Auditoría

En **Auditoría de procesos**, tras localizar la OC, la traza incluye **IART/ITAR** por líneas FCOMD y **bodega/tipo movimiento** (pasos «Catálogo artículos en OC» y «Bodega y tipo movimiento (OC)»).

## Continúa en

**`CONFIG-BODEGA-TIPO-MOV.md`** — IBOD, ITMO, `IDINVMOV_COMPRAS` y contabilización efectiva (PC-00g … PC-00i).
