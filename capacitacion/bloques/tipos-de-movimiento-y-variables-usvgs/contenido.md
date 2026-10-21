# Tipos de movimiento y variables USVGS

## Contexto

**Proceso:** Inventario, Compras y Farmacia
**Capa:** Configuración

## Explicación

ITMO define Débito (salida) o Crédito (entrada), si afecta costo o promedio, si se contabiliza y con qué comprobante, si genera tránsito (y su tipo opuesto), si pide proveedor o valor. El proceso no elige el tipo por nombre sino por variable: IDINVMOV_COMPRAS=02, IDINVMOV_REMISION_EN=22, IDTS/IDTE=14/13 (traslado), IDINVENTA_PARTICULAR=VE, IDINVMOVVENTAFACTURA=VC, IDINVDEVPROVEEDOR=05, IDINVSALVENCIDOS=07, IDINVTRASLOTESAL/ENT=24/25, IDINVSIENT/SISAL=SI/SA (ajustes de conteo), IDINVTPROPIA=PR (custodia), IDINVTFSA=21 (códigos habituales; cada institución configura los suyos).

## Invariante

> Cada variable IDINV* apunta a un ITMO activo del tipo correcto (el SP rechaza «La variable configurada no es de tipo salida»). GENTRANSITO exige IDTIPOMOVOP. SECONTABILIZA requiere cuentas KMCOM MOV_INVENTARIO (y CXP_COMPRAS para compras); si faltan, la confirmación falla con «Inconsistencia. No existe configuración contable».

## Procedimientos almacenados

### SPQ_ITMO
**Método:** `GUARDAR / ACTUALIZAR / ELIMINAR`
**Rol:** Tipo de movimiento; borrar solo valida IEXCEP.

### SPK_INSERT_ITRA_REQ
**Método:** `(confirmar OC)`
**Rol:** ITRA con el tipo de la variable.

### SPK_NC_CONTAB_INV
**Método:** `(OM INV)`
**Rol:** SECONTABILIZA según ITMO e IBOD.NOCONTABILIZA.
