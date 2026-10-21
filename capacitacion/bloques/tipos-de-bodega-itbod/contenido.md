# Tipos de bodega (ITBOD)

## 🎯 Objetivo

Definir los tipos de bodega que agrupan las bodegas por su naturaleza (farmacéutica, administrativa, etc.).


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITBOD`
**Frontend:** `/inv/conf/itbod`, `/inv/conf/ibod`

### 🏥 **Tipos de bodega**

ITBOD define tipos para agrupar bodegas: farmacéuticas, carro de paro, botiquín, bodegas administrativas. Cada tipo configura el comportamiento de las bodegas que lo usan.

### 📦 **Configuración de bodegas (IBOD)**

Cada bodega individual lleva sede, centro de costo y bodega que pide (IDBODEGAPIDE, obligatoria para solicitar compras). Los campos MUEVEEXISTENCIAS, VALIDASTOCK, NOCONTABILIZA, ESDECUSTODIA, MANEJA_PICKPACK y COMPRASOL controlan su operación.

### 🔐 **Seguridad y catálogos**

IBODS define qué usuarios pueden ingresar (BODEGASELECT) y qué tipos de artículo acepta. Los catálogos (ICLA/ICLAH/IGRU, IGEN+ITGEN, IFFA, ICCN, IPAC, IUNI) solo se eliminan si no están en uso.


## ⚠️ Importante

- Nada se borra con hijos: tipo de bodega con bodegas, bodega con IBODEX/IBODS/IDXB/movimientos, catálogo con artículos
- Códigos y descripciones únicos

## 📌 Resumen

**ITBOD** es una tabla de configuración que define el comportamiento de las bodegas en inventario.

**Campos clave:** Configuración básica

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
