# Entrada de almacén y confirmación

## Contexto

**Proceso:** Inventario, Compras y Farmacia
**Capa:** Proceso propio

## Explicación

Entrada manual (CRUD_IMOV + CRUD_IMOVH) o entrada que viene del tránsito de compras (ya en estado 0). Buscar Artículo, en el saldo inicial y en el resto de entradas manuales, lista artículos con estado Activo cuyo tipo de artículo tiene acceso Si en la seguridad de la bodega del encabezado. Si el artículo maneja principal, la lista trae el SKU y no el principal. Al confirmar (CONF_ENTRADA → SPK_CONFIRMARENTRADAS) se exige fecha de vencimiento en todas las líneas, factura no duplicada con fechas, costo en todos los lotes, paciente si el tipo lo pide y, con VALID_CCOSTO_CXP = SI, centro de costo con cuenta CXP_COMPRAS. El SPK crea IEXI (con PCOSTO base DIAN en recepción de OC), suma IDXB/IART, cierra ITRA, actualiza kardex, pasa la orden a R o I y, si el tipo es 02/22/SI con proveedor, crea la CxP (FCXP + SPK_INSERT_CXP_INV + impuestos). Contabiliza en línea solo si CONTABIMOV_JOB ≠ SI.

## Invariante

> Ninguna línea sin lote, vencimiento ni costo. Cuentas KMCOM MOV_INVENTARIO y CXP_COMPRAS presentes para el tipo/centro/área. La entrada confirmada no se edita: se anula o se devuelve.

## Procedimientos almacenados

### SPQ_IMOV
**Método:** `CRUD_IMOV / CRUD_IMOVH`
**Rol:** Cabecera y detalle de entrada.

### SPQ_IZSOL
**Método:** `CONF_ENTRADA / ANULAR_ENTRADA / CAMBIAR_FACTURA`
**Rol:** Confirmar, anular pendiente, cambiar factura (si la CxP no está contabilizada).

### SPK_CONFIRMARENTRADAS
**Método:** `(SPK)`
**Rol:** IEXI, IDXB, kardex, FCOM R/I, CxP automática. PREVERSION corrige el total con líneas ESTADO 9.

### SPK_INSERT_CXP_INV
**Método:** `(SPK)`
**Rol:** Detalle FCXPD desde IMOVH.
