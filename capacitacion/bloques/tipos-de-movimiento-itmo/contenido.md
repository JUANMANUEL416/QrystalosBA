# Tipos de movimiento (ITMO)

## 🎯 Objetivo

Configurar los tipos de movimiento de inventario (entradas, salidas, traslados) que definen si afectan existencias, si contabilizan y cómo.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITMO`
**Frontend:** `/inv/conf/itmo`, `/conf/usvgs`

ITMO define Débito (salida) o Crédito (entrada), si afecta costo o promedio, si se contabiliza y con qué comprobante, si genera tránsito (y su tipo opuesto), si pide proveedor o valor. El proceso no elige el tipo por nombre sino por variable: IDINVMOV_COMPRAS=02, IDINVMOV_REMISION_EN=22, IDTS/IDTE=14/13 (traslado), IDINVENTA_PARTICULAR=VE, IDINVMOVVENTAFACTURA=VC, IDINVDEVPROVEEDOR=05, IDINVSALVENCIDOS=07, IDINVTRASLOTESAL/ENT=24/25, IDINVSIENT/SISAL=SI/SA (ajustes de conteo), IDINVTPROPIA=PR (custodia), IDINVTFSA=21 (códigos habituales; cada institución configura los suyos).


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
