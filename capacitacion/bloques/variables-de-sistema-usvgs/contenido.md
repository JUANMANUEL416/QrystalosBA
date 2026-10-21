# Variables de sistema (USVGS)

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
