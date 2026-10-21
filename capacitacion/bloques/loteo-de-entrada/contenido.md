# Loteo de entrada

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Loteo

## Explicación

El loteo registra números de lote y fechas de vencimiento de los artículos recibidos. Es obligatorio para medicamentos y dispositivos médicos. Cada lote se registra en IEXI con su cantidad específica.

## Invariante

> La suma de cantidades de todos los lotes debe coincidir con la cantidad en tránsito. Artículos con tipo que maneja lote exigen lote y vencimiento.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `LOTEO_TRANSITO`  
**Rol:** Registra lotes (IEXI) y actualiza existencias preliminares

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden con tránsito **Pendiente loteo**
3. Hacer clic en **Lotear**
4. Para cada artículo que maneja lote:
   - Ingresar número de lote del proveedor
   - Fecha de vencimiento
   - Cantidad de este lote
   - Si hay varios lotes, agregar líneas adicionales
5. Verificar que suma de lotes = cantidad en tránsito
6. Guardar

## Siguiente paso

Después del loteo, **Confirmar entrada** para que los artículos ingresen a la bodega y se genere la CxP.
