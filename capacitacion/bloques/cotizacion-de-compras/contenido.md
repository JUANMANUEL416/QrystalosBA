# Cotización de compras

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Cotización

## Explicación

La cotización (ICTZ) registra las ofertas de proveedores antes de generar la orden de compra. Permite comparar precios, descuentos y plazos de entrega.

## Invariante

> Cada cotización debe tener proveedor, fecha, artículos con cantidades y precios, y estado (Pendiente, Aprobada, Rechazada).

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ICTZ`  
**Rol:** Crea, modifica o elimina cotizaciones

## Pasos

1. Ir a **Inventario → Procesos → Cotización de compras**
2. Hacer clic en **Nueva cotización**
3. Seleccionar proveedor
4. Ingresar fecha de cotización
5. Agregar artículos:
   - Buscar artículo
   - Ingresar cantidad
   - Precio unitario
   - Descuento (opcional)
6. Revisar subtotal e IVA
7. Guardar como Pendiente
8. Al aprobar: cambiar estado a **Aprobada**

## Siguiente paso

La cotización aprobada se puede convertir en **Orden de compra**.
