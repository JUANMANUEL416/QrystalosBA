# CONF_ENTRADA y puente a CxP

Continúa **`OC-CONFIRMACION-RECEPCION.md`**. JSON: `catalogo-conf-entrada-cxp.json`.

**Núcleo crítico (IEXI + KMCOM + cuadre CxP):** leer primero **`NUCLEO-CRITICO-IEXI-CXP.md`** (PC-N1 … PC-N5).

SP: `SPQ_IZSOL` · `SPK_CONFIRMARENTRADAS` · `SPK_INSERT_CXP_INV`.

## 1. Confirmar entrada (`CONF_ENTRADA`)

**Pantalla:** Inventario → Movimientos (`IMOVComponetNew`) · MODELO **IZSOL** · METODO **CONF_ENTRADA**.

**Precondiciones:** `IMOV.ESTADO = 0`, detalle **IMOVH** con `ESTADO = 0` y `CANTIDAD > 0`, factura/costos completos según tipo.

### Validaciones (SPQ_IZSOL)

| Validación | Cuándo |
|------------|--------|
| Fecha vencimiento en líneas | `ITAR.MFECHAVENCIMIENTO = 1` |
| Detalle confirmable | IMOVH ESTADO=0, cantidad > 0 |
| Factura duplicada | Compras / remisión entrada: mismo `NODOCUMENTO` + `IDTERCERO` en otro IMOV no anulado |
| Fechas factura | `TIPO_DOC_COMPRA`: F y R con reglas de `F_FACTURA` / `F_VENCE` |
| **PCOSTO > 0** | Salvo tipo `IDINVTPROPIA` |
| Paciente | `IDINVTPROPIA` exige `CNSTRAN` |
| Artículo principal loteable | No confirmar principal cuando ITAR.MPRINCIPAL y IART.PRINCIPAL |
| **KMCOM CXP_COMPRAS** | Si `VALID_CCOSTO_CXP=SI` y tipo compras: DB+CR por **ITAR** y **CCOSTO** del IMOV |

Si pasa: **`EXEC SPK_CONFIRMARENTRADAS`** → **`IMOV.ESTADO = 1`**, sube **IEXI**, kardex; si hay **`CNSFCOM`**: **`SPK_FCOM_RECALCULA_RECEPCION`** (FCOM **R** / **I**).

**No hace:** crear FCXP ni FCXPD (eso es CxP después).

## 2. Puente CxP (`PROCESAR_IMOVH`)

**Pantalla:** Administración → Cuentas por pagar (`CXPComponent`) · MODELO **FCXP**.

Flujo habitual:

1. Existe **FCXP** cabecera ligada a la compra (`CNSFCOM` / factura proveedor) — creación manual o proceso del cliente.
2. **`PROCESAR_IMOVH`**: `EXEC SPK_INSERT_CXP_INV @CNSFCXP, @CNSMOV, 'CXP'`.

### Qué hace `SPK_INSERT_CXP_INV`

| Paso | Efecto |
|------|--------|
| Lee **IMOV** confirmado + **VWK_IMOVH_AGRUPADO** | Base/IVA según `REDONDEO_COMPRAS_CXP` |
| Borra/reconstruye **FCXPD** con **`N_PRESUP = CNSMOV`** | Puente movimiento ↔ líneas CxP |
| Homologa **CUENTAGRAV** / **CUENTA_IVA** | Gravados (`ITAR.MIVA`, `CUE_IVA`) |
| Actualiza cuentas en **IEXI** | CUEDEBITO / CUENTAIVA desde FCXPD |
| **IMOVH**: `ESTADO=1`, **`ENCXP=1`** | Marca líneas ya procesadas a CxP |
| **SPK_CALCULOVALORESCXP** | Totales FCXP |
| Anticipos | Si `PROCE='CXP'`: legalización **ANT** vía `CNSFCOM` |

**FCOM.ENCXP:** el flag de cabecera puede seguir en 0 hasta procesos posteriores; el indicador operativo fuerte es **FCXPD.N_PRESUP** y **IMOVH.ENCXP**.

## 3. Después del puente

| Paso | METODO / SP | PC |
|------|-------------|-----|
| Reconstruir cuentas (opcional) | `RECONSTRUIR_CUENTAS_FCXPD` | No repone CUENTAGRAV |
| Validar | `VALIDAR_FCXP` | Detalle + CUECREDITO detalle |
| Retenciones | `CRUD_FCXPI` / impuestos | PC-06 |
| Contabilizar | `CONTABILIZAR_FCXP` → **SPK_NC_CONTAB_CXP** | PC-07 |
| Doble costo | OM **INV** vs **CxP** mismo CNSMOV | PC-08 |

Variables clave: **`VALID_CCOSTO_CXP`**, **`CUENTA_IVA_CXP`**, **`REDONDEO_COMPRAS_CXP`**.

## 4. Orden recomendado (compras estándar)

```
IMOV(0) + factura/costos en cabecera
  → CONF_ENTRADA (existencias + FCOM R/I)
  → FCXP cabecera (si no existe)
  → PROCESAR_IMOVH (FCXPD ← IMOVH)
  → VALIDAR_FCXP → FCXPI → CONTABILIZAR_FCXP
```

## Auditoría BA

Pasos: detalle IMOVH, **preconfirmación** si IMOV(0), **FCXPD** con `N_PRESUP`, contabilidad CxP/INV (PC-05…PC-08).
