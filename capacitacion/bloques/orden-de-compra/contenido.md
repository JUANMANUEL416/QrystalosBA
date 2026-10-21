# Orden de compra

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Orden

## Explicación

La orden de compra (FCOM) es el documento oficial que autoriza al proveedor a entregar los artículos. Puede generarse desde una cotización aprobada o crearse manualmente.

## Invariante

> Cada orden debe tener proveedor, fecha, artículos, cantidades, precios, bodega destino y estado (Creada, Confirmada, Recibida, Anulada).

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_FCOM`  
**Rol:** Crea o modifica órdenes de compra

## Pasos

### Desde cotización

1. Ir a **Inventario → Procesos → Cotización de compras**
2. Seleccionar cotización aprobada
3. Hacer clic en **Generar orden de compra**
4. Revisar artículos y precios (se copian de la cotización)
5. Seleccionar bodega destino
6. Guardar

### Manual

1. Ir a **Inventario → Procesos → Orden de compra**
2. Hacer clic en **Nueva orden**
3. Seleccionar proveedor
4. Ingresar fecha esperada de entrega
5. Agregar artículos manualmente:
   - Buscar artículo
   - Cantidad
   - Precio unitario
6. Seleccionar bodega destino
7. Guardar

## Siguiente paso

La orden creada debe **confirmarse** antes de que el proveedor la reciba.
