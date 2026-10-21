# Variables de sistema (USVGS)


## 🔹 Variables de configuración

| Código | Descripción | Valor | Efecto |
|--------|-------------|-------|--------|
| `IDINVDEVPROVEEDOR` | Tipo de movimiento para devolución a proveedor | 05 (habitual) | Identifica la devolución de medicamentos/insumos al proveedor |
| `IDINVENTA_PARTICULAR` | Tipo de movimiento para venta a particular | VE (habitual) | Identifica la venta a particular (no facturado) |
| `IDINVMOVVENTAFACTURA` | Tipo de movimiento para venta con factura | VC (habitual) | Identifica la venta con factura generada |
| `IDINVMOV_COMPRAS` | Tipo de movimiento para compras/entrada de almacén | 02 (habitual) | Identifica el movimiento de entrada por compra |
| `IDINVMOV_REMISION_EN` | Tipo de movimiento para remisión de entrada | 22 (habitual) | Identifica la remisión de entrada de inventario |
| `IDINVSALVENCIDOS` | Tipo de movimiento para salida de vencidos | 07 (habitual) | Identifica la salida de medicamentos/insumos vencidos |
| `IDINVSIENT` | Tipo de movimiento para ajuste de entrada por conteo | SI (habitual) | Ajuste positivo de inventario tras conteo físico |
| `IDINVTFSA` | Tipo de movimiento para farmacia-sala | 21 (habitual) | Identifica el movimiento de farmacia a sala/servicio |
| `IDINVTPROPIA` | Tipo de movimiento para custodia propia | PR (habitual) | Identifica medicamentos/insumos en custodia propia |
| `IDINVTRASLOTESAL` | Tipo de movimiento para traslado de lote salida | 24 (habitual) | Identifica el traslado de un lote específico (salida) |
| `IDTE` | Tipo de movimiento para traslado de entrada | 13 (habitual) | Identifica el traslado de entrada entre bodegas |
| `IDTS` | Tipo de movimiento para traslado de salida | 14 (habitual) | Identifica el traslado de salida entre bodegas |

> **💡 Tip:** Los valores mostrados son códigos habituales. Cada institución puede configurar los propios en USVGS.

## 🎯 Objetivo

Configurar las variables de sistema que controlan el comportamiento global de inventario y compras.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `USVGS`
**Frontend:** `/inv/conf/itmo`, `/conf/usvgs`

### 🔹 **Variables de configuración**

USVGS almacena variables del sistema que controlan el comportamiento de los procesos. No se usan valores fijos en el código sino referencias a estas variables (ej: IDINVMOV_COMPRAS, IDINVENTA_PARTICULAR).

### 📦 **Variables de movimientos de inventario**

Los tipos de movimiento (ITMO) se referencian por variable: IDINVMOV_COMPRAS=02, IDINVMOV_REMISION_EN=22, IDTS/IDTE=14/13 (traslado), IDINVENTA_PARTICULAR=VE, IDINVMOVVENTAFACTURA=VC, IDINVDEVPROVEEDOR=05, IDINVSALVENCIDOS=07, IDINVTRASLOTESAL/ENT=24/25, IDINVSIENT/SISAL=SI/SA (ajustes), IDINVTPROPIA=PR (custodia), IDINVTFSA=21.

> **💡 Tip:** Cada institución configura sus propios códigos. Los mencionados son habituales pero no obligatorios.


## ⚠️ Importante

- Cada variable IDINV* apunta a un ITMO activo del tipo correcto (el SP rechaza «La variable configurada no es de tipo salida»)
- GENTRANSITO exige IDTIPOMOVOP
- SECONTABILIZA requiere cuentas KMCOM MOV_INVENTARIO (y CXP_COMPRAS para compras); si faltan, la confirmación falla con «Inconsistencia

## 📌 Resumen

**USVGS** es una tabla de configuración que define el comportamiento de el sistema en inventario.

**Campos clave:** Configuración básica

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Ninguno (configuración base)

<!-- AUDIENCIA: soporte-desarrollo -->

<!-- /AUDIENCIA -->
