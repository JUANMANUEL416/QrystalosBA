# Confirmación de orden

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Orden

## Explicación

La confirmación de la orden (FCOM estado Confirmada) autoriza al proveedor a despachar la mercancía. Una vez confirmada, la orden no puede modificarse.

## Invariante

> Solo pueden confirmarse órdenes en estado Creada. La confirmación genera un registro de tránsito para cada artículo.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `CONFIRMAR_ORDEN`  
**Rol:** Confirma la orden y genera registros de tránsito (ITRA)

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden en estado **Creada**
3. Revisar artículos, cantidades y precios
4. Hacer clic en **Confirmar orden**
5. El sistema genera automáticamente:
   - Estado de la orden → **Confirmada**
   - Registros de tránsito (ITRA) para cada artículo
   - PDF de la orden para enviar al proveedor

## Siguiente paso

Cuando el proveedor despache, registrar el **Tránsito de mercancía** (llegada parcial o total).
