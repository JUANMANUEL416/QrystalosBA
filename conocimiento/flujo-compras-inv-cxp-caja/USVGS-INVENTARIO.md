# Variables USVGS — inventario y flujo compras → CxP

Las variables viven en la tabla **`USVGS`** (`IDVARIABLE`, `DATO`). El motor las lee con **`dbo.FNK_VALORVARIABLE('NOMBRE')`**. No son parámetros de pantalla: son **configuración por cliente** que enlaza tipos de movimiento (`ITMO`), bodegas (`IBOD`), catálogo (`ITAR`/`IART`) y contabilidad (`KMCOM`).

**Catálogo máquina:** `usvgs-inventario.json` (misma carpeta).

---

## Cómo consultarlas (solo lectura en cliente)

```sql
SELECT IDVARIABLE, DATO
FROM dbo.USVGS
WHERE IDVARIABLE IN (
  'IDINVMOV_COMPRAS', 'VALID_CCOSTO_CXP', 'DEINVNODESER', 'CONTAB_INV_IVA_ITAR',
  'REDONDEO_COMPRAS_CXP', 'IDMODELOCONTABLE', 'CUENTA_IVA_CXP', 'IMPUESTO_OBL', 'IART_SER_UNICO',
  'IDINVMOV_PRESTAMOS', 'IDINVTPROPIA', 'TRAN_EDIT_OC', 'IDINVDIASPARAVENCER',
  'IDBOD_HEMODERIVADOS', 'MOV_PERIODOS_ANT', 'ASI_VAL_CCAF_CARGOS', 'ESFARMACIA'
  -- lista completa: usvgs-inventario.json → listaConsultaSql
);
```

Cada `DATO` suele ser un **código** (`IDTIPOMOV`, `IDARTICULO`, `SI`/`NO`, número de días, etc.). Hay que cruzarlo con `ITMO`, `IBOD`, `ITAR` o `KMCOM` según la variable.

---

## 1. Catálogo artículo (IART / SER)

| Variable | Para qué sirve | Qué pasa si está mal / vacía |
|----------|----------------|------------------------------|
| **DEINVNODESER** | ID de “servicio ficticio” cuando el artículo aún no tiene `SER`. `VALIDA_SERVICIO` lo usa como destino temporal de `IDSERVICIO`. | KO al validar servicio; no se puede cerrar alta de artículo con reglas de facturación. |
| **IART_SER_UNICO** | Si está en SI, al guardar un artículo activo `SPQ_IART` no permite otro activo con el mismo CUM ni la misma descripción. | CUM o nombres duplicados en el catálogo. Hoy solo está en PREVERSION; la 2.0.5 todavía no lo trae. |
| **IMPUESTO_OBL** | Obliga impuesto/clase en artículo (validación de negocio). | Artículos sin IVA configurado cuando el cliente exige impuesto. |
| **IDSEDEPRINCIPAL** | Sede para generar consecutivo de `IDARTICULO` si la UI no envía sede. | Consecutivos incorrectos o error al guardar. |
| **NRO_ESPACIOS_ITARCNS** | Cantidad de dígitos del consecutivo (tras prefijo `ITAR.PRECNS`). | IDs cortos/largos vs estándar del cliente. |
| **PREFIJOMEDICAMENTOS** / **PREFIJOMEDNOPOS** | Identifican ITAR medicamento POS/NOPOS al crear `SER` desde IART. | SER con prefijo/concepto equivocado. |
| **IDMEDPOSRIPS** / **IDMEDNOPOSRIPS** | Conceptos RIPS en plantilla de servicio. | Facturación/RIPS inconsistente. |
| **COD_TARIFA_MAT_VE** | Tarifa por defecto al crear SER. | Precios base incorrectos. |
| **CAMBIO_ART_ESTADO** | Sincroniza inactivación IART ↔ SER. | Artículo inactivo con SER activo (o viceversa). |
| **INTERFAZ_INV** | `INTER_SAP`: reglas Perú/SAP en IART y confirmación entrada. | Validaciones distintas a Colombia. |
| **ESFARMACIA** | Modo farmacia en listados y reglas IMOV. | Filtros y validaciones de movimiento distintos. |
| **IDITARUNIDOSIS** | ITAR unidosis en consultas IART. | Filtros/unidosis no aplican. |

Detalle artículo: `CATALOGO-ARTICULO.md`.

---

## 2. Tipos de movimiento (puente USVGS → ITMO)

Estas variables guardan el **`IDTIPOMOV`** que el sistema trata como “compras”, “remisión”, “propia”, etc.

| Variable | Para qué sirve | Dónde impacta |
|----------|----------------|---------------|
| **IDINVMOV_COMPRAS** | Entrada por **orden de compra**: `ITRA` al confirmar OC, tránsito, `CONF_ENTRADA`, KMCOM CXP. | Todo el núcleo compras → IEXI → CxP. **Crítica.** |
| **IDINVMOV_PRESTAMOS** | Entrada cuando la OC es tipo préstamo (`FCOM.IDTIPOSER=Presta`). | Tipo de tránsito distinto a compra normal. |
| **IDINVMOV_REMISION_EN** | Entrada por remisión de proveedor. | Mismas validaciones de factura/CxP que compras en varios SP. |
| **IDINVMOV_SI** | Entrada alterna (cliente) en tránsito/CUFE. | Flujos especiales de recepción. |
| **IDINVTPROPIA** | Producción propia / paciente; exige `CNSTRAN`; costo puede ser 0. | `CONF_ENTRADA`, anulaciones, IMOV manual. |
| **IDTS** / **IDTE** | Par traslado salida / entrada entre bodegas. | Tránsitos internos, no OC. |
| **IDINVMOV_VENTAS** | Tipo que la solicitud (IZSOL) trata como venta. En CEM está en **06**, que es el volumen de dispensación. | No es el mostrador. |
| **IDINVMOVVENTAFACTURA** | Movimiento que se factura a FTR. En CEM es **VC**. | Factura de inventario, no el recaudo de mostrador. |
| **IDINVENTA_PARTICULAR** | Salida de la venta a particulares (`VENTAFAR`). En CEM es **VE**. | Mostrador: carrito, caja y factura. |
| **INVE_CIRU_TIPO_MOV** | Salida débito cirugía desde solicitud. | Quirofano, no compras. |
| **FAR_MOVANULASALIDA** | Tipo para anular salida farmacia. | `SPK_CONFIRMARENTRADAS` anulaciones. |

Configuración bodega + tipo: `CONFIG-BODEGA-TIPO-MOV.md`. Runbook Q10 en `movimientos-de-inventario.md`.

---

## 3. OC, tránsito y CONF_ENTRADA

| Variable | Para qué sirve | Qué hace en runtime |
|----------|----------------|---------------------|
| **VALID_CCOSTO_CXP** | `SI`: antes de confirmar entrada compra, exige **KMCOM** `CXP_COMPRAS` por **ITAR + centro de costo** de la línea. | Bloqueo en `CONF_ENTRADA` si falta cuenta puente inventario→CxP. **Crítica (PC-N2).** |
| **TRAN_EDIT_OC** | `SI`: en loteo de tránsito **compra** permite ajustar costo/IVA vs OC. | `SPQ_IZSOL_TRANSITO` ON_PROCESAR. |
| **IDINVDIASPARAVENCER** | Días mínimos de vida útil al capturar lote (bodegas normales). | Rechaza lotes muy próximos a vencer. |
| **NDIASANTESVENCE** | Ventana de alerta/bloqueo por vencimiento (dispensación/loteo). | Mensaje KO al agregar lote. |
| **IDBOD_HEMODERIVADOS** | Código bodega hemoderivados. | Reglas de lote/fecha/INVIMA distintas. |
| **IDITARHEMODERIVADOS** | ITAR hemo; excepciones a vencimiento. | Validación cruzada con bodega hemo. |
| **VALID_INVIMA_HEMO** | `NO`: no exige registro INVIMA en hemo. | Solo aplica combinación hemo. |
| **ANULA_TRANSITO_SINEN** | Permite anular tránsito sin movimiento de entrada en condiciones definidas. | Soporte anulaciones atascadas. |
| **COLOCAR_TOTAL_IMOV** | `SI`: calcula totales en cabecera `IMOV` al crear desde tránsito. | Cuadre cabecera vs detalle. |
| **IDINVENTRADAUNICA** / **IDINVIDITARUNICA** | Restricciones “entrada única” por tipo/lote. | `SPK_INSERTENTTRANSITO`. |
| **INVCONSECUTIVOSINDEP** | Consecutivos IMOV independientes por subflujo. | Numeración documentos. |
| **CODIGOUNICOICBU** | `SI`: exige unicidad lote ICBU en compras/remisión. | IMOV / tránsito. |
| **IDINVENTXOBSEQUIOS** | Tipo movimiento óptica/lentes (cliente). | Tránsito especializado. |
| **MOV_PERIODOS_ANT** | `NO`: impide crear IMOV en **meses anteriores** al actual. | Cierre contable operativo. |
| **ASI_VAL_CCAF_CARGOS** | `SI`: al crear IMOV contabilizable valida **KMCOM** `MOV_INVENTARIO`. | Error al guardar movimiento sin modelo contable. |

Recepción y loteo: `OC-CONFIRMACION-RECEPCION.md`, `CONF-ENTRADA-CXP.md`.

---

## 4. Puente CxP y contabilidad inventario

| Variable | Para qué sirve | Efecto |
|----------|----------------|--------|
| **IDMODELOCONTABLE** | Modelo para `FNK_CUENTA_KMCOM` / `FNK_NC_CUENTA_KMCOM`. | Sin modelo, no hay cuentas en FCXPD ni MCP inventario. **Crítica.** |
| **CONTAB_INV_IVA_ITAR** | `SI`: al armar **FCXPD** desde `IMOVH`, usa IVA gravado según **ITAR** (homologación inventario/CxP). | Líneas CxP con IVA distinto al costo inventario. **Crítica (PC-N3).** |
| **CUENTA_IVA_CXP** | `SI`: exige **CUENTA_IVA** en detalle CxP cuando hay `VLR_IVA`. | `CONTABILIZAR_FCXP` falla si falta cuenta. |
| **REDONDEO_COMPRAS_CXP** | `SI`: redondeo a 3 decimales al pasar IMOVH → FCXPD. | Centavos de diferencia IMOV vs CxP. **Crítica (PC-N4).** |
| **IDIMP_IVA** | Impuesto IVA por defecto si el artículo no trae uno. | FCXPD sin IDIMPUESTO. |
| **CTAIMPUESTOCONSUMO** | Cuenta contable impoconsumo en FCXPD. | Líneas consumo sin cuenta. |
| **IDTIPOCXP_DEFAULT** | Tipo documento CxP al auto-crear desde entrada confirmada. | FCXP con tipo incorrecto. |
| **TERCATPROVEEDOR** | Categoría tercero proveedor en FCXP automática. | Clasificación proveedor en CxP. |
| **CONTABIMOV_JOB** | `SI`: contabiliza IMOV vía job tras confirmar. | MCP no inmediato en pantalla. |

Núcleo IEXI ↔ CxP: `NUCLEO-CRITICO-IEXI-CXP.md`, `RUNBOOK-SOPORTE-IEXI-CXP.md`.

---

## 5. Dispensación (IZSOL) — contexto

No son el corazón del flujo compras, pero comparten bodega, lotes e IEXI:

| Variable | Uso breve |
|----------|-----------|
| **MVIGENCIAIZSOL** / **HVIGENCIAIZSOL** | Vigencia horaria de solicitudes. |
| **IZSOL_MED_SOLI** | Médico vs usuario en entrega. |
| **IENF_RECIBE_INSUMOS** | Enfermería recibe en CE. |
| **VALIDA_INVI** | Exige REGINVIMA al dispensar. |
| **IXCOUNTRY** | Rama Perú vs resto (SAP, CE, etc.). |

---

## Validación en vivo (Auditoría BA)

Menú **Auditoría de procesos** → elija servidor y BD → **Validar USVGS inventario** (no requiere número de OC).

Por cada variable el panel muestra:

| Bloque | Significado |
|--------|-------------|
| **DATO** | Valor actual en `USVGS` del cliente |
| **Validación** | Cruce read-only: `ITMO` (tipo compras Crédito/COMPRAS=1), `IBOD`, `ITAR`, `IART`, `KMCO`/`KMCOM CXP_COMPRAS`, flags SI/NO |
| **SQL (BA/sql)** | Scripts locales donde aparece `FNK_VALORVARIABLE('…')` — **mapa de impacto** si cambia la variable en un REQ |
| **Si cambia el valor** | Qué flujos nuevos se rompen o desvían (histórico IMOV/FCXPD ya grabado no se recalcula solo) |

Regenerar referencias SQL tras bajar SP nuevos a `sql/`:

```text
python scripts/_scan_usvgs_refs.py
```

Archivo generado: `usvgs-sql-refs.json`.

API: `POST /api/auditoria/usvgs` con `{ servidorId, baseDatos }`.

---

## Relación con la auditoría BA

La traza de OC comprueba entre otros:

- `ITRA.IDTIPOMOV` = **IDINVMOV_COMPRAS** (o préstamos).
- Preconfirmación **VALID_CCOSTO_CXP** (KMCOM).
- Cuadre **IMOVH ↔ FCXPD** (afectado por **REDONDEO_COMPRAS_CXP**, **CONTAB_INV_IVA_ITAR**).

Si un paso KO menciona USVGS, contrastar `DATO` con `ITMO`/`IBOD`/`KMCOM` antes de tocar datos de la OC.

**CUFE en entrada compra:** con **IDINVMOV_COMPRAS**, `SPQ_IMOV_3` / **SPK_SINCRONIZAR_CUFE_RADIAN** llenan `IMOV.CUFE` desde **FRADIAN** (factura + NIT). Detalle: `../inventario/MOVIMIENTOS-INVENTARIO.md` §4.1. Generar CxP desde Radian sigue en **cxp-fcxp** (`REGISTRAR_CXP_FRADIAN`).

---

## Pick & Pack (SPQ_IMOV_4)

| USVGS | Uso | Si cambia |
|-------|-----|-----------|
| **IDMOVPICKPACK** | CSV de `ITMO.IDTIPOMOV` permitidos en órdenes pickpack; CONFIRMA_PICKING y listados filtran con `STRING_SPLIT`. | Tipos fuera de lista no entran al módulo; tipos viejos en IMOV abiertos pueden quedar inconsistentes. |
| **PVENTA_MOV_SAL** / **PVENTA_AUTO_TARIFA** | Con **IDINVMOVVENTAFACTURA** o **IDINVENTA_PARTICULAR**, obligan o calculan PVENTA en lotes antes de confirmar picking. | Desactivar puede permitir confirmar picking sin precio; activar bloquea líneas sin tarifa. |

Contabilidad: pickpack **no** contabiliza; la OM INV sigue en **CONFIRMA_SALIDA** → **SPK_CONFIRMARSALIDAS** (ver `../inventario/MOVIMIENTOS-INVENTARIO.md` §4.5).

---

## Documentos relacionados

| Documento | Contenido |
|-----------|-----------|
| `CATALOGO-ARTICULO.md` | Variables de artículo en profundidad |
| `CONFIG-BODEGA-TIPO-MOV.md` | IDINVMOV_COMPRAS + IBOD |
| `CONF-ENTRADA-CXP.md` | VALID_CCOSTO_CXP, CONF_ENTRADA |
| `usvgs-inventario.json` | Lista JSON para UI/scripts |
