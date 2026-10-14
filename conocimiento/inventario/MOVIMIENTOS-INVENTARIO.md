# Movimientos de inventario — catálogo normalizado y contabilidad

Documento maestro del proceso **`inventario`** (2026-09-19). Complementa el runbook vivo [`movimientos-de-inventario.md`](../../../qrystalos.documentacion/runbooks/movimientos-de-inventario.md) y el flujo compras [`flujo-compras-inv-cxp-caja`](../flujo-compras-inv-cxp-caja/PROCESO.md).

**Catálogo máquina:** `catalogo-movimientos-inventario.json`  
**USVGS:** [`USVGS-INVENTARIO.md`](../flujo-compras-inv-cxp-caja/USVGS-INVENTARIO.md)

---

## 1. Modelo mental

Todo movimiento operativo es **`IMOV` + `IMOVH`**, clasificado por **`ITMO.IDTIPOMOV`**. En muchos clientes el código concreto del tipo no es fijo: se **normaliza por familia** (compra, traslado, venta…) y se enlaza a **`USVGS`** cuando el producto trae variable dedicada.

| Capa | Qué define | Ajuste contable típico |
|------|------------|-------------------------|
| **ITMO** | TIPO (Crédito/Débito), COMPRAS, SECONTABILIZA, MPROVEEDOR | Activar/desactivar contabilidad por tipo |
| **IBOD** | NOCONTABILIZA, CCOSTO | Bodega excluida de MCP aunque ITMO contabilice |
| **USVGS** | Qué IDTIPOMOV es “compra”, “traslado salida”, etc. | Cambio de variable ≠ cambio automático en histórico |
| **KMCOM** | MOV_INVENTARIO, CXP_COMPRAS | Cuentas DB/CR por ITAR, CCOSTO, IDTIPOMOV |
| **OM INV** | `SPK_NC_CONTAB_INV` | Comprobante MCP desde `/cont/conciContables` |

**SECONTABILIZA efectivo** (invariante INV-C01):

```text
SECONTABILIZA_efectivo = ITMO.SECONTABILIZA = 1  AND  IBOD.NOCONTABILIZA = 0
```

Si efectivo = 0, `SPK_NC_CONTAB_INV` responde *«Este movimiento no se contabiliza»*.

---

## 2. Familias normalizadas (resumen)

Cada fila es una **familiaNorm** del JSON. La columna USVGS indica la variable que fija el `IDTIPOMOV` en ese cliente.

| Familia | USVGS (principal) | IEXI | CxP auto | OM INV (SPK_NC_CONTAB_INV) |
|---------|-------------------|------|----------|----------------------------|
| Entrada compra | IDINVMOV_COMPRAS | + | Sí (FCXP + SPK_INSERT_CXP_INV) | Sí · KMCOM MOV_INVENTARIO + puente CXP |
| Entrada remisión | IDINVMOV_REMISION_EN | + | Según flujo | Sí |
| Entrada préstamo | IDINVMOV_PRESTAMOS | + | No típico | Sí · tercero puede ser IMOV |
| Entrada SI | IDINVMOV_SI | + | Según flujo | Sí |
| Salida traslado | IDTS | − origen | No | Sí · ESTRANSITO |
| Entrada traslado | IDTE | + destino | No | Sí |
| Propia / paciente | IDINVTPROPIA | + | No | Sí · CNSTRAN |
| Dispensación | IDINVMOV_DISPEN | − | No | Sí |
| Cirugía | INVE_CIRU_TIPO_MOV | − | No | Sí |
| Venta retail | IDINVMOV_VENTAS | − | No | Sí · + caja |
| Venta facturable | IDINVMOVVENTAFACTURA | − | No | Sí · + FTR / CONTAB_GASTOVEN_UNI |
| Venta particular | IDINVENTA_PARTICULAR | − | No | Sí · rama venta |
| Devolución cliente | IDTIPOMOVDEV_CLIENTE | + | No | Sí · rama venta |
| Devolución proveedor | IDINVDEVPROVEEDOR | − | Nota CxP | **No** (MCP desde nota) |
| Devolución interna | IDINVMOV_DEVOLUCION | + | No | Sí |
| Devoluciones CE/Cx/HTX | IDINVMOVDEVCX, … | ± | No | Sí (revisar par) |
| Traslado AF | IDINVTRASLACTIVOS | − | No | Sí |
| TFSA / ajustes | IDINVTFSA, IDINVSAL_MISMAENT | − | No | Sí |
| Anulación salida FAR | FAR_MOVANULASALIDA | + | No | Sí |
| Óptica / obsequios | IDINVENTXOBSEQUIOS | + | No | Sí |
| **Solo ITMO** | *(ninguna)* | ± | No | Según SECONTABILIZA del tipo elegido |

Detalle por familia, SP y variables: **`catalogo-movimientos-inventario.json`**.

---

## 3. Controles de confirmación (normalizados)

| Sentido | Control UI / API | SPK principal | IMOV.ESTADO |
|---------|------------------|---------------|-------------|
| Entrada | `CONF_ENTRADA` (IZSOL) | SPK_CONFIRMARENTRADAS | 0 → 1 |
| Salida manual | `CONFIRMA_SALIDA` (IMOV) | SPK_CONFIRMARSALIDAS | 0 → 1 |
| Salida dispensación | `CONF_MOVIMIENTO` (IZSOL) | SPK_CONFIRMASAL_CM | 0 → 1 |
| Tránsito → IMOV entrada | `ON_ACEPTA_TRANSITO` | SPK_INSERTENTTRANSITO | crea 0 |
| Contabilizar | OM Inventario | SPK_NC_CONTAB_INV | MCP |

**Periodo:** `CRUD_IMOV` / `CRUD_IMOV_SAL` validan `PRI.CERRADO_INV` / `CERRADO`; muchas confirmaciones **no** revalidan PRI (riesgo documentado en proceso inventario).

---

## 4. Comportamiento contable por escenario (para ajustes)

### 4.1 Entrada compra (referencia cruzada)

1. `CONF_ENTRADA` → existencias + opcional FCXP.
2. `SPK_INSERT_CXP_INV` arma FCXPD (KMCOM **CXP_COMPRAS**, IVA según **CONTAB_INV_IVA_ITAR**).
3. Contabilización inventario: OM → **MOV_INVENTARIO** (cuentas por ITAR/CCOSTO/**IDTIPOMOV** en `FNK_NC_CUENTA_KMCOM`).
4. Contabilización CxP: proceso **cxp-fcxp** (`CONTABILIZAR_FCXP`).

**Ajustes habituales:** KMCOM faltante (VALID_CCOSTO_CXP), cuadre IMOVH↔FCXPD (REDONDEO), cuenta IVA (CUENTA_IVA_CXP).

**CUFE en IMOV (DIAN / Radian)** — columna `IMOV.CUFE`, solo **IDINVMOV_COMPRAS** con **CNSFCOM** (requiere DDL `IMOV.CUFE`):

| METODO IMOV_3 | Uso |
|---------------|-----|
| **SINCRONIZAR_CUFE_RADIAN** | Auto: `FRADIAN.UUID` por factura + NIT proveedor (`SPK_SINCRONIZAR_CUFE_RADIAN`; lotes históricos por trimestre) |
| **ACTUALIZAR_CUFE** | Manual un movimiento |
| **PLANTILLA_CUFE** / **CARGAR_CUFE_MASIVO** | Excel masivo |

No sustituye **REGISTRAR_CXP_FRADIAN** (proceso **cxp-fcxp**): el CUFE en inventario es trazabilidad del documento recibido; la CxP sigue su propio flujo Radian.

**Loteo con factura (INV_CUFE_LOTEO = SI)** — control `imov-transito`, pantalla Movimientos → Traer del tránsito:

1. Catálogo: Exportar en la fila de filtros; copiar a la izquierda del número de compra; clic derecho abre las acciones; se cierra con la X del título.
2. Documento de la entrada: Factura o Remisión. En Factura la lista de RADIAN se refresca al escribir documento, fechas o valor. Se puede continuar aunque el CUFE esté repetido; el aviso «no está en RADIAN» solo sale si no hay ninguna fila.
3. Todos (en la factura): ítems de la orden cuyo CUM está en la factura. Solo lote y vencimiento. Menos cantidad deja debajo una línea con el faltante, sin lote; esa línea no se guarda.
4. Faltante: total de la factura menos lo loteado, en el título de Loteado y en la columna Faltante de cada línea (después del CUM).
5. Al aceptar, el número, las fechas y el CUFE pasan a la entrada y ahí no se editan (tampoco el tipo de documento ni el tipo de movimiento).
6. Nuevo fabricante, desde el loteo: una fila con Tipo artículo, Maneja IVA, Id. Impuesto e Id. Clase Impuesto. Al marcar Maneja IVA, si Id. Impuesto está vacío se llena con **IDIMP_IVA**. INVIMA (código y vigencia) a la izquierda; códigos del medicamento a la derecha.

Remisión, variable distinta de SI y traslados sin orden de compra no usan este camino.

**Actas recepción (IMOV_3):** `RPT_ACTA_RECEPCION` / custodia; listados `RPT_ACTAS_*` (custodia filtra **IDINVTPROPIA**). Solo lectura/reporte — no mueve IEXI ni contabilidad.

### 4.2 Salida consumo / dispensación

Cadena normal (**inv.ges** o **IZSOL**):

```text
CRUD_IMOV_SAL → ISAL + CONFIRMA_ENTREGA → CONFIRMA_SALIDA (SPQ_IMOV)
  → SPK_CONFIRMARSALIDAS → [SPK_NC_CONTAB_INV | IMOVC si CONTABIMOV_JOB=SI]
```

1. **SPK_CONFIRMARSALIDAS** (sql/ PREVERSION 2.0.3): exige **CCOSTO** en CEN; si `SECONTABILIZA=1`, valida **KMCOM MOV_INVENTARIO** DB y CR con `PREFIJO=IDTIPOMOV` y `CCOSTO` del movimiento (⚠ en el script la validación usa `IDMODELOCONT='01'` fijo — invariante **INV-C06**).
2. Descuenta **IEXI** y deja **IMOV.ESTADO=1**.
3. Contabilidad inmediata salvo **CONTABIMOV_JOB=SI** (encola **IMOVC**).
4. No genera CxP.

Dispensación **inv.sol_2** — camino distinto:

```text
IZSOL PROCESAR → CONF_MOVIMIENTO → SPK_CONFIRMASAL_CM
  (no llama SPK_CONFIRMARSALIDAS)
  → IDXB/IART −cantidad → SPK_NC_CONTAB_INV | IMOVC
```

No aplica la validación previa KMCOM DB/CR de **SPK_CONFIRMARSALIDAS**; el ajuste contable falla en **SPK_NC_CONTAB_INV** si falta modelo/cuentas.

**Ajustes:** ITMO SECONTABILIZA=0; IBOD NOCONTABILIZA=1; KMCOM; periodo PRI no bloqueado en confirmación; cruce IEXI lote vs IDXB en dispensación.

### 4.3 Traslado IDTS → IDTE

1. Salida origen: −IEXI, puede quedar **ESTRANSITO=1**.
2. Entrada destino: +IEXI al confirmar **IDTE**.
3. Contabilidad: suele ser movimiento interno (CR/DB inventario); revisar **IDCON_IMOVDBENT_COMP=MOV_INVENTARIO** en cliente.

**Ajustes:** tránsito aceptado sin entrada confirmada; costos distintos entre bodegas.

**Tránsito en pantalla (IMOV_3, inv.ges / Traer del tránsito):**

| METODO | Cuándo | Efecto |
|--------|--------|--------|
| **ELIMINA_ITRAH** | Quitar artículo/lote del tránsito antes de generar IMOV | DELETE **ITRAH** (`INICIAL=0`); auditoría **FCOMTRANEVT** si es OC; **SPK_FCOM_RECALCULA_RECEPCION** |
| **ITRAH_REGRESAR** | Traslado aún en tránsito (sin recepción destino) | **INV_APRU_DEVTRA=SI:** solicitud **ITRADEV** + ITRA/ITRAH **ESTADO=3** (aceptar en origen). **NO:** **SPK_REINTGRA_TRASLADO_INV** → entrada **IDTIMOVDEV_TRASLBOD** + **SPK_CONFIRMARENTRADAS** |

**SPQ_ITRADEV** (dialogo aprobación bodega origen, solo si **INV_APRU_DEVTRA=SI**):

| METODO | Efecto |
|--------|--------|
| **LISTAR** / **CONTAR_PENDIENTES** | Cola ITRADEV ESTADO=0 |
| **ACEPTAR** | **SPK_REINTGRA_TRASLADO_INV** + ITRADEV ESTADO=1 |
| **RECHAZAR** | ITRADEV ESTADO=2; ITRA/ITRAH → ESTADO=0 (destino debe recibir); **no** re-solicitar Regresar |

Requiere **IDTIMOVDEV_TRASLBOD** (ITMO crédito devolución traslado). Contabilidad de la devolución: misma OM entrada (**MOV_INVENTARIO**) al confirmar el IMOV generado.

### 4.4 Venta al público y venta facturable

**Retail (`SPQ_VENTAFAR.GUARDA_VENTA`)** — familia `venta_particular` / USVGS **IDINVENTA_PARTICULAR**:

1. Crea IMOV con **GENFACTURA=1**, ISAL, ejecuta **SPK_CONFIRMARSALIDAS**.
2. Descuenta **IEXI comercial** por lote (paso explícito en GUARDA_VENTA; distinto al artículo “hermano”).
3. **SPK_FAC_VENTA_INV** → FTR + **SPK_NC_CONTAB_FTR** (ingreso).
4. **FCJ** recaudo + **SPK_NC_CONTAB_CAJA_ING**.

**Facturable posterior (`IDINVMOVVENTAFACTURA`)** — salida ya confirmada:

| Pantalla | MODELO | METODO | SPK |
|----------|--------|--------|-----|
| inv.facturaInv | IMOV_VENTA | FACTMASIVO_INV / MARCA_FACTURAR | SPK_FAC_VENTA_INV_MASIVA |
| inv.ges | IMOV_3 | **FACTURAR_IMOV** (uno) o FACTMASIVO_INV | SPK_FAC_VENTA_INV |

**FACTURAR_IMOV** exige **ISAL↔IEXI** por lote antes de facturar; no trae recaudo caja (solo FTR). **VENTAFAR** sigue siendo el flujo retail completo (caja + FTR).

**CONTAB_GASTOVEN_UNI=SI** (invariante **INV-C07**): **SPK_NC_CONTAB_INV** puede diferir el costo al comprobante **FACTURA** unificado (`MCPE.PROCEDENCIA=FACTURA`) en lugar de MCP INV separado.

**Ajustes:** PGP/capitado en PPT; BLOQUEADIAN/FACTSEDE; homologar IDINVENTA_PARTICULAR vs IDINVMOVVENTAFACTURA según canal.

### 4.5 Pick & Pack (SPQ_IMOV_4 / MODELO IMOV_4)

Flujo **paralelo** a salida manual: la bodega debe tener **IBOD.MANEJA_PICKPACK=1** y el **IDTIPOMOV** debe estar en **USVGS IDMOVPICKPACK** (lista separada por comas).

| Fase | METODO (IMOV_4) | Efecto en stock / IMOV |
|------|-----------------|-------------------------|
| Orden | CREAR_ORDEN_PICKING | IMOV **ES_PICKPACK=1**, ESTADO=0, IMOVH |
| Lotes | AGREGAR_LOTE_PICKING | **ISAL** reserva soft; **no** baja **IEXI** |
| Preparación | CONFIRMAR_PREPARACION_PICKING | PREPARACION_LISTA=1 |
| Picking → packing | CONFIRMA_PICKING | ESTADO_PICKPACK=1, ENTREGADO=1 (permiso **CONF_PICKING**) |
| Cierre packing | FINALIZAR_PACKING | **ESTADO_PICKPACK=3** |
| Salida contable | inv.ges **CONFIRMA_SALIDA** (SPQ_IMOV) | **SPK_CONFIRMARSALIDAS** + **SPK_NC_CONTAB_INV** si SECONTABILIZA efectivo |

**SPQ_IMOV** bloquea **CONFIRMA_SALIDA** si `ES_PICKPACK=1` y `ESTADO_PICKPACK ≠ 3`. Misma regla de contabilidad que cualquier salida débito (KMCOM **MOV_INVENTARIO**, invariante **INV-C06**).

**VENTAFAR / venta cliente:** en picking se valida **PVENTA** cuando el tipo es **IDINVMOVVENTAFACTURA** o **IDINVENTA_PARTICULAR** y **PVENTA_MOV_SAL** / **PVENTA_AUTO_TARIFA** = SI.

Enrutamiento: **SPQ_IMOV** y **SPQ_IMOV_3** delegan métodos pickpack a **EXEC SPQ_IMOV_4**; el front preferible usa **MODELO IMOV_4**.

### 4.6 Import / export (IMOV_3, inv.ges)

| METODO | Rol |
|--------|-----|
| **EXPORTAR_FORMATO** | Descarga plantilla (existencias IEXI por bodega) |
| **IMPORTAR_ARTICULOS** | Carga lotes → reemplaza **IMOVH/ISAL**; exige **IEXI**; bloqueado en Pick&Pack packing (ESTADO_PICKPACK 1/3) |
| **EXPORTAR_EXCEL_MOVIMIENTOS** | Informe histórico (mismos filtros que grilla; detalle físico **ISAL** en salidas) |

La confirmación y contabilidad siguen en **CONFIRMA_SALIDA** / **CONFIRMA_ENTRADA** (SPQ_IMOV).

**GEN_DOCUMENTO:** inv.sol **IZSOL** llama **IMOV_3** con RPDX; en PREVERSION 2.0.3 hay **RETURN** antes de generar y el callback Vue está vacío — **defecto** SQL + hueco FE.

### 4.7 Perú — boleta afecta/inafecta (IMOV_3 + IZSOL)

**BOL_AFECTA_INAFECTA** / **BOL_AFECTA_INAFECTA_YA_NO** — solo **IXCOUNTRY=PERU**; movimiento inventario ligado a **AUT** (CE / IMOVH.NOPRESTACION):

- Crea **FCJ** + **FCJD** desde copagos **AUTD** (afecta SER.IVA=`SER`, inafecta ≠ `SER`, particular ESPART=1).
- Exige **caja abierta** (ACJ); no sustituye confirmación de salida ni **SPK_NC_CONTAB_INV** (contabilidad caja aparte).

**Fabricantes en tránsito:** **NUEVO_FABRICANTE** (consecutivo hijo) + **GUARDA_FABRICANTE** (INSERT **IART** clonado) desde **TraerTransito** / **TraerTransitoTemp**. Al marcar Maneja IVA, si Id. Impuesto está vacío se propone **IDIMP_IVA**; al desmarcar se limpian impuesto y clase. Id. Clase Impuesto no se llena con esa variable.

**IMOV_BORRADETA:** borra detalle **IMOVH/ISAL** en movimiento pendiente; en **Pick&Pack** resetea flags y usa applock de bodega.

### 4.8 Devolución proveedor (IDINVDEVPROVEEDOR)

- **SPK_NC_CONTAB_INV** marca el movimiento no contabilizable y sale: la contabilidad va por **nota de devolución CxP**, no por OM INV.

---

## 5. Tipos ITMO sin USVGS

Movimientos creados en **Inventario → Movimientos** con cualquier `ITMO` activo:

- Validar **SECONTABILIZA** y **ASI_VAL_CCAF_CARGOS** al guardar.
- Misma confirmación entrada/salida.
- Para REQ de ajustes contables: listar ITMO del cliente con SECONTABILIZA=1 y cruzar KMCOM **MOV_INVENTARIO** por ITAR/CCOSTO.

---

## 6. Auditoría BA — mapa ITMO vs familias

En **Auditoría de procesos**:

1. **Validar USVGS inventario** — valores y cruces ITMO/IBOD/KMCO.
2. **Mapa movimientos ITMO** — lista `ITMO` del cliente, asignación a familiaNorm por USVGS, alertas SECONTABILIZA sin KMCOM muestral.

API: `POST /api/auditoria/movimientos-inventario` `{ servidorId, baseDatos }`.

---

## 7. SQL de referencia en `sql/` (PREVERSION = 2.0.3)

| Objeto | Rol contable |
|--------|----------------|
| **SPQ_IMOV** | CRUD, CONFIRMA_SALIDA → SPK_CONFIRMARSALIDAS |
| **SPK_CONFIRMARSALIDAS** | KMCOM gate, IEXI, SPK_NC_CONTAB_INV / IMOVC |
| **SPQ_VENTAFAR** | GUARDA_VENTA — cadena FTR + caja |
| **SPK_FAC_VENTA_INV** | FTR + SPK_NC_CONTAB_FTR |
| **SPK_CONFIRMASAL_CM** | Dispensación CONF_MOVIMIENTO → SPK_NC_CONTAB_INV |
| **SPQ_IMOV_VENTA** | MARCA_FACTURAR, FACTMASIVO_INV, devoluciones IDTIPOMOVDEV_CLIENTE |
| **SPK_FAC_VENTA_INV_MASIVA** | FTR agrupada + SPK_NC_CONTAB_FTR |

| **SPQ_IMOV_3** | inv.ges: FACTURAR_IMOV, traslados, actas, CUFE compras |
| **SPQ_IMOV_4** | Pick&Pack: reserva ISAL → FINALIZAR_PACKING → CONFIRMA_SALIDA |
| **SPK_SINCRONIZAR_CUFE_RADIAN** | IMOV.CUFE ← FRADIAN (compras) |
| **SPQ_ITRADEV** | Aprobar/rechazar devolución traslado (INV_APRU_DEVTRA) |

**Documentación IMOV_3:** métodos whitelist fichados en `sps.json` (estado **leido**). Cambios de producto pendientes: **`TICKETS-CAMBIOS-PENDIENTES.md`** (INV-TCK-01 KMCOM, INV-TCK-02 GEN_DOCUMENTO).

---

## 8. Validación y solicitud de cambios

1. Ejecutar checklist en **`TICKETS-CAMBIOS-PENDIENTES.md`** (auditoría BA + muestra por familia).
2. Registrar hallazgos en Chat del REQ o comité; citar ticket **INV-TCK-01** / **INV-TCK-02** si aplica.
3. Dictamen de implementación aparte (QrystalosBA no codifica).

---

## 9. Documentos relacionados

| Ruta | Contenido |
|------|-----------|
| `TICKETS-CAMBIOS-PENDIENTES.md` | Tickets INV-TCK-* + checklist validación |
| `catalogo-movimientos-inventario.json` | Familias, matriz confirmación, invariantes |
| `sps.json` | Catálogo SP → METODO |
| `proceso.json` | Capas 01–04 inventario |
| `../flujo-compras-inv-cxp-caja/NUCLEO-CRITICO-IEXI-CXP.md` | Compras ↔ CxP |
| `qrystalos.documentacion/tablas/ITMO.md` | Columnas ITMO |
| `qrystalos.documentacion/tablas/IMOV.md` | Estados IMOV |
