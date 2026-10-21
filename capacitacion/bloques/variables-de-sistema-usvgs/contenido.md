# Variables de sistema (USVGS)

## 🎯 Objetivo

Configurar las variables de sistema que controlan el comportamiento global de inventario y compras.

## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `USVGS`
**Frontend:** `/inv/conf/itmo`, `/conf/usvgs`

ITMO define Débito (salida) o Crédito (entrada), si afecta costo o promedio, si se contabiliza y con qué comprobante, si genera tránsito (y su tipo opuesto), si pide proveedor o valor. El proceso no elige el tipo por nombre sino por variable: IDINVMOV_COMPRAS=02, IDINVMOV_REMISION_EN=22, IDTS/IDTE=14/13 (traslado), IDINVENTA_PARTICULAR=VE, IDINVMOVVENTAFACTURA=VC, IDINVDEVPROVEEDOR=05, IDINVSALVENCIDOS=07, IDINVTRASLOTESAL/ENT=24/25, IDINVSIENT/SISAL=SI/SA (ajustes de conteo), IDINVTPROPIA=PR (custodia), IDINVTFSA=21 (códigos habituales; cada institución configura los suyos).

## ⚠️ Importante

- Cada variable IDINV* apunta a un ITMO activo del tipo correcto (el SP rechaza «La variable configurada no es de tipo salida»)
- GENTRANSITO exige IDTIPOMOVOP
- SECONTABILIZA requiere cuentas KMCOM MOV_INVENTARIO (y CXP_COMPRAS para compras); si faltan, la confirmación falla con «Inconsistencia

## 📌 Resumen

**USVGS** es una tabla de configuración que define la información de el sistema en inventario.

**Campos clave:**  (cambian el comportamiento del sistema)

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Ninguno (configuración base)
