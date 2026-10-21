# Bodegas (IBOD)

## 🎯 Objetivo

Crear y configurar bodegas (farmacia, bodega central, carro de paro, etc.) con sus permisos, centros de costo y reglas de validación de stock.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `IBOD`
**Frontend:** `/inv/conf/itbod`, `/inv/conf/ibod`

ITBOD agrupa bodegas (farmacéuticas, carro de paro, botiquín, administrativas). IBOD lleva sede, centro de costo, bodega que pide (IDBODEGAPIDE, obligatoria para solicitar compras), MUEVEEXISTENCIAS, VALIDASTOCK, NOCONTABILIZA, ESDECUSTODIA, MANEJA_PICKPACK, COMPRASOL. Seguridad IBODS: qué usuarios entran (BODEGASELECT) y qué tipos de artículo acepta. Los catálogos (ICLA/ICLAH/IGRU, IGEN+ITGEN, IFFA, ICCN, IPAC, IUNI) solo se borran si nadie los usa.


## 📋 Campos relevantes

| Icono | Campo | Descripción | Impacto / Uso |
|-------|-------|-------------|---------------|
| 🔑 | **IDTIPOBODEGA** | Tipo de bodega | Define la naturaleza de la bodega (ITBOD) |
| 🔑 | **MUEVEEXISTENCIAS** | Afecta stock físico | Si no mueve, no altera IEXI (bodegas virtuales) |
| 🔑 | **VALIDASTOCK** | Valida que haya existencia antes de salida | Evita saldos negativos |
| 🔑 | **NOCONTABILIZA** | No genera asientos contables | Bodegas de prueba o administrativas sin impacto contable |
| 🔑 | **IDBODEGAPIDE** | Bodega que solicita compras | Obligatoria para generar órdenes de compra desde solicitudes |

**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario

## 🔢 Pasos

**1.** Ir a Inventario → Configuración → Bodegas

**2.** Seleccionar tipo de bodega (IDTIPOBODEGA)

**3.** Configurar nombre, sede y centro de costo

**4.** Definir si mueve existencias (MUEVEEXISTENCIAS) y valida stock (VALIDASTOCK)

**5.** Configurar bodega que pide (IDBODEGAPIDE) si genera órdenes de compra

**6.** Guardar y configurar permisos en Seguridad de bodegas (IBODS)

## ⚠️ Importante

- Nada se borra con hijos: tipo de bodega con bodegas, bodega con IBODEX/IBODS/IDXB/movimientos, catálogo con artículos
- Códigos y descripciones únicos

## 💡 Tips

- Bodegas de prueba: marcar NOCONTABILIZA y no MUEVEEXISTENCIAS
- Farmacia principal: debe tener VALIDASTOCK para evitar saldos negativos
- Configurar permisos por usuario en Seguridad de bodegas (IBODS) después de crear la bodega

## 📝 Ejemplo práctico

**Bodega: Farmacia Central**
- IDTIPOBODEGA = Farmacéutica
- DESCRIPCION = "Farmacia Central - Sede Principal"
- MUEVEEXISTENCIAS = 1 (afecta stock físico)
- VALIDASTOCK = 1 (valida existencia antes de salida)
- NOCONTABILIZA = 0 (sí contabiliza)
- IDBODEGAPIDE = (la misma bodega, si genera OC)
→ Permisos: configurar en IBODS qué usuarios/tipos de artículo pueden acceder

## 📌 Resumen

**IBOD** es una tabla decisiva que define el comportamiento de las bodegas en inventario.

**Campos clave:** IDTIPOBODEGA, MUEVEEXISTENCIAS, VALIDASTOCK (cambian el comportamiento del sistema)

**Proceso:** 6 pasos desde configuración hasta operación

**Prerrequisitos:** Requiere BOD

## ✅ Autoevaluación

**1.** ¿Cuándo usar MUEVEEXISTENCIAS=0 en una bodega?

   <details><summary>Ver respuesta</summary>
   En bodegas virtuales, de prueba o administrativas que no afectan el stock físico real (no alteran IEXI).
   </details>

**2.** ¿Qué hace VALIDASTOCK=1?

   <details><summary>Ver respuesta</summary>
   Valida que haya existencia disponible antes de permitir una salida, evitando saldos negativos.
   </details>

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_IBOD`

**Propósito:** Lista las bodegas a las que el usuario tiene acceso (IBODS TIPO USUSU con ACCESO SI). Es la lista que ven todas las pantallas de inventario.

**Métodos:**

- `BODEGASELECT`: Operación específica de negocio

#### `SPQ_IBOD`

**Propósito:** Asocia el equipo del usuario (UBEQ) a una bodega: la bodega por defecto de la estación.

**Métodos:**

- `UPDATEBODEGAUSER`: Operación específica de negocio

#### `SPQ_IBOD`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `BODEGAUSERASIG`: Operación específica de negocio

#### `SPQ_IBOD`

**Propósito:** Crea la bodega: tipo (ITBOD), sede, centro de costo, bodega que pide (IDBODEGAPIDE), banderas MUEVEEXISTENCIAS, VALIDASTOCK, CONSUMO, NOCONTABILIZA, ESDECUSTODIA, MANEJA_PICKPACK.

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_IBOD`

**Propósito:** Escribe en IBOD.

**Métodos:**

- `ACTUALIZAR`: Modifica registro existente

#### `SPQ_IBOD`

**Propósito:** Borra la bodega.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)

#### `SPQ_IBODS`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `GET_TIPO_SEGURIDAD`: Obtiene información

#### `SPQ_IBODS`

**Propósito:** Agrega una regla de seguridad a la bodega: usuario con acceso, tipo de artículo permitido, etc. (pestaña Seguridad). En Movimientos, Buscar Artículo de una entrada (incluido el saldo inicial) solo lista artículos activos cuyo tipo tiene, en la bodega del encabezado, una regla de tipo de artículo con acceso Si. Si el artículo maneja principal, la lista trae el SKU y no el principal.

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_IBODS`

**Propósito:** Escribe en IBODS.

**Métodos:**

- `ACTUALIZAR`: Modifica registro existente

#### `SPQ_IBODS`

**Propósito:** Escribe en IBODS.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)


<!-- /AUDIENCIA -->
