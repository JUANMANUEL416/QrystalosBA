# Tipos de bodega (ITBOD)

## 🎯 Objetivo

Definir los tipos de bodega que agrupan las bodegas por su naturaleza (farmacéutica, administrativa, etc.).

## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITBOD`
**Frontend:** `/inv/conf/itbod`, `/inv/conf/ibod`

ITBOD agrupa bodegas (farmacéuticas, carro de paro, botiquín, administrativas). IBOD lleva sede, centro de costo, bodega que pide (IDBODEGAPIDE, obligatoria para solicitar compras), MUEVEEXISTENCIAS, VALIDASTOCK, NOCONTABILIZA, ESDECUSTODIA, MANEJA_PICKPACK, COMPRASOL. Seguridad IBODS: qué usuarios entran (BODEGASELECT) y qué tipos de artículo acepta. Los catálogos (ICLA/ICLAH/IGRU, IGEN+ITGEN, IFFA, ICCN, IPAC, IUNI) solo se borran si nadie los usa.

## ⚠️ Importante

- Nada se borra con hijos: tipo de bodega con bodegas, bodega con IBODEX/IBODS/IDXB/movimientos, catálogo con artículos
- Códigos y descripciones únicos

## 📌 Resumen

**ITBOD** es una tabla de configuración que define la información de las bodegas en inventario.

**Campos clave:**  (cambian el comportamiento del sistema)

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Ninguno (configuración base)

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_ITBOD`

**Propósito:** Crea el tipo de bodega (ITBOD).

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_ITBOD`

**Propósito:** Escribe en ITBOD.

**Métodos:**

- `ACTUALIZAR`: Modifica registro existente

#### `SPQ_ITBOD`

**Propósito:** Borra el tipo de bodega.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)


<!-- /AUDIENCIA -->
