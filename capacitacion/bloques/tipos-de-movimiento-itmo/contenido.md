# Tipos de movimiento (ITMO)


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

Configurar los tipos de movimiento de inventario (entradas, salidas, traslados) que definen si afectan existencias, si contabilizan y cómo.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITMO`
**Frontend:** `/inv/conf/itmo`, `/conf/usvgs`

### 📦 **Configuración del movimiento**

ITMO define cada tipo de movimiento: Débito (salida) o Crédito (entrada), si afecta costo o promedio, si se contabiliza y con qué comprobante, si genera tránsito (y su tipo opuesto), si pide proveedor o valor.

### 🔹 **Variables del sistema**

El proceso NO elige el tipo por nombre sino por variable de sistema (USVGS): IDINVMOV_COMPRAS=02, IDINVMOV_REMISION_EN=22, IDTS/IDTE=14/13 (traslado), IDINVENTA_PARTICULAR=VE, IDINVMOVVENTAFACTURA=VC, IDINVDEVPROVEEDOR=05, IDINVSALVENCIDOS=07, IDINVTRASLOTESAL/ENT=24/25, IDINVSIENT/SISAL=SI/SA (ajustes de conteo), IDINVTPROPIA=PR (custodia), IDINVTFSA=21.

> **💡 Tip:** Estos son códigos habituales; cada institución configura los propios en USVGS.


## 📋 Campos relevantes

| Icono | Campo | Descripción | Impacto / Uso |
|-------|-------|-------------|---------------|
| 🔑 | **Débito / Crédito** | Tipo de movimiento | Débito = salida, Crédito = entrada. Afecta signo en IEXI |
| 🔑 | **CONTABILIZA** | Genera comprobante contable | Define si el movimiento afecta contabilidad |
| 🔑 | **MPIDEPROV** | Pide proveedor | Usado en entradas de compras (tipo 02, 22) |

**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario

## ⚠️ Importante

- Cada variable IDINV* apunta a un ITMO activo del tipo correcto (el SP rechaza «La variable configurada no es de tipo salida»)
- GENTRANSITO exige IDTIPOMOVOP
- SECONTABILIZA requiere cuentas KMCOM MOV_INVENTARIO (y CXP_COMPRAS para compras); si faltan, la confirmación falla con «Inconsistencia

## 📌 Resumen

**ITMO** es una tabla decisiva que define el comportamiento de los movimientos en inventario.

**Campos clave:** Débito / Crédito, CONTABILIZA, MPIDEPROV (cambian el comportamiento del sistema)

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Ninguno (configuración base)

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_ITMO`

**Propósito:** Crea el tipo de movimiento: código (2), descripción, TIPO Débito (salida) / Crédito (entrada), tipo opuesto si genera tránsito, comprobante si se contabiliza, banderas AFECTACOSTO, AFECTAPROM, SECONTABILIZA, GENTRANSITO, OCULTARCOSTOS, MPROVEEDOR, PIDEVALOR.

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_ITMO`

**Propósito:** Escribe en ITMO.

**Métodos:**

- `ACTUALIZAR`: Modifica registro existente

#### `SPQ_ITMO`

**Propósito:** Borra el tipo de movimiento.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)


<!-- /AUDIENCIA -->
