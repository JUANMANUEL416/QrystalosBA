# Tipos de bodega, bodegas y catálogos

## Contexto

**Proceso:** Inventario, Compras y Farmacia
**Capa:** Configuración

## Explicación

ITBOD agrupa bodegas (farmacéuticas, carro de paro, botiquín, administrativas). IBOD lleva sede, centro de costo, bodega que pide (IDBODEGAPIDE, obligatoria para solicitar compras), MUEVEEXISTENCIAS, VALIDASTOCK, NOCONTABILIZA, ESDECUSTODIA, MANEJA_PICKPACK, COMPRASOL. Seguridad IBODS: qué usuarios entran (BODEGASELECT) y qué tipos de artículo acepta. Los catálogos (ICLA/ICLAH/IGRU, IGEN+ITGEN, IFFA, ICCN, IPAC, IUNI) solo se borran si nadie los usa.

## Invariante

> Nada se borra con hijos: tipo de bodega con bodegas, bodega con IBODEX/IBODS/IDXB/movimientos, catálogo con artículos. Códigos y descripciones únicos.

## Procedimientos almacenados

### SPQ_ITBOD
**Método:** `GUARDAR / ACTUALIZAR / ELIMINAR`
**Rol:** Tipo de bodega.

### SPQ_IBOD
**Método:** `GUARDAR / ACTUALIZAR / ELIMINAR / BODEGASELECT / UPDATEBODEGAUSER`
**Rol:** Bodega y bodega por defecto del equipo (UBEQ).

### SPQ_IBODS
**Método:** `GUARDAR / GET_TIPO_SEGURIDAD`
**Rol:** Seguridad por bodega.

### SPQ_ICLA
**Método:** `GUARDAR / ELIMINAR`
**Rol:** Clase, subclase, grupo.

### SPQ_IGEN
**Método:** `GUARDAR / ELIMINAR`
**Rol:** Genérico DCI.

### SPQ_ESTANTE
**Método:** `CRUD_TGEN / CRUD_IARTE`
**Rol:** Estantes y artículos por estante.

### SPQ_IDXB
**Método:** `CRUD_IDXB`
**Rol:** Stock mínimo/máximo/punto de reorden por bodega.
