# Confirmación de OC y primera recepción

Continúa **`CONFIG-BODEGA-TIPO-MOV.md`**. JSON: `catalogo-oc-confirmacion-recepcion.json`.

## 1. Antes de confirmar (cabecera FCOM)

| Requisito | Por qué |
|-----------|---------|
| **FCOMD** con líneas | `CONFIRMAR_ORDEN` KO: «No cuenta con detalle.» |
| **IDTERCERO** proveedor | Tránsito y CxP |
| **IDBODEGA** | Destino en `ITRA.IDBODEGADES` e `IMOV` |
| **CCOSTO / IDAREA** | KMCOM si `VALID_CCOSTO_CXP=SI` |
| **Detalle coherente** | Cantidades, IVA (`TIENEIVA`, `FACTORIVA`), artículos activos |

Estado típico: **`ESTADO = C`** (abierta). **`ENINVENTARIO`** y **`ENCXP`** suelen estar en **0** al crear la OC (no sustituyen el hecho de tener IMOV/FCXP).

## 2. Confirmar orden (`CONFIRMAR_ORDEN`)

En **Inventario → Orden de compra** → confirmar.

**SPQ_FCOM · CONFIRMAR_ORDEN:**

1. Valida detalle.
2. **`ORDENCOMPRA`** += 1 (si era 0 → 1).
3. **`ESTADO`**: si era **`C`** → **`P`** (procesada/confirmada).
4. **`SPK_INSERT_ITRA_REQ`**: crea **ITRA** + **ITRAH** por cada línea FCOMD.

### Qué queda en tránsito

| Campo ITRA | Valor |
|------------|--------|
| `CNSFCOM` | La OC |
| `IDBODEGADES` | `FCOM.IDBODEGA` |
| `IDTIPOMOV` | `IDINVMOV_COMPRAS` (o **`IDINVMOV_PRESTAMOS`** si `IDTIPOSER = Presta`) |
| `ESTADO` | **0** (abierto) |
| `LOTEADO` | **0** |

**ITRAH:** `INICIAL = 0`, cantidades desde FCOMD. Si **`ITAR.MLOTEO = 1`**, el SP marca **`INICIAL = 1`** y cierra cantidades **sin** pasar por pantalla de loteo.

> **Importante:** Confirmar **no** confirma inventario: no hay **IEXI** hasta **`CONF_ENTRADA`**.

## 3. Estados FCOM (recepción)

| Código | Significado (UI seguimiento OC) |
|--------|----------------------------------|
| **C** | Abierta |
| **P** | Confirmada, pendiente de recepcionar |
| **R** | Recepción parcial en bodega |
| **I** | Recepción total |
| **A** | Anulada |

Tras **`CONF_ENTRADA`**, **`SPK_FCOM_RECALCULA_RECEPCION`** deja **`R`** o **`I`** según pendientes FCOMD vs IMOV confirmado.

## 4. Primera recepción — dos caminos

### A) Manual (habitual con loteo)

1. OC ya **P** con **ITRA** creado al confirmar (o al iniciar recepción parcial).
2. **Inventario → Movimientos** → traer tránsito → **loteo** (`IZSOL_TRANSITO`) si **`ITAR.MLOTEO = 0`**.
3. **`ON_ACEPTA_TRANSITO`** → **`SPK_INSERTENTTRANSITO`** → **IMOV** `ESTADO = 0`.
4. Completar factura/costos si aplica → **`CONF_ENTRADA`**.

### B) Recepción masiva Excel

**`RECEPCION_MASIVA`** → **`SPQ_FCOM_RECEPCION_MASIVA`**: puede generar **IMOV** borrador e **ITRAH** con **`INICIAL = 1`** sin loteo en UI. Igual requiere **`CONF_ENTRADA`** para existencias.

Consulta de apoyo: **`RECEPCION_PARCIAL_OC`** (cruza ITRA/IMOV vs FCOMD).

## 5. Controles críticos (PC)

| ID | Control |
|----|---------|
| **PC-02** | OC no anulada/borrador para recepcionar (`P`, `R`, `I`) |
| **PC-02b** | Tras confirmar: **ITRA** ligado y líneas **ITRAH** |
| **PC-02c** | **`ITRA.IDTIPOMOV`** = USVGS esperado (compras/préstamo) |
| **PC-03 … PC-03c** | Loteo, **IMOV** borrador, cantidades |

## 6. Abrir OC (`ABRIR`)

No permite volver a **`C`** si ya hay **ITRA procesado** o **IMOV confirmado** (`ESTADO = 1`). Mensaje: recepción parcial/total en bodega.

## Auditoría BA

La traza OC incluye: estado/flags cabecera, **ITRA vs tipo mov USVGS**, y loteo/recepción existentes.

## Siguiente eslabón

**`CONF-ENTRADA-CXP.md`** — confirmación física, existencias y puente **PROCESAR_IMOVH** → FCXPD.
