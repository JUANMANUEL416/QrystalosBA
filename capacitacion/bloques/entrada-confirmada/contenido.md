# Entrada confirmada

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Entrada

## Explicación

La entrada confirmada ingresa los artículos a la bodega destino, actualiza existencias (IDXB) y genera automáticamente la cuenta por pagar (FCXP) al proveedor.

## Invariante

> La entrada confirma el movimiento de inventario (IMOV tipo 02 estado 0 → estado 1), actualiza IDXB y crea FCXP por el valor de la compra.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `CONF_ENTRADA`  
**Rol:** Confirma entrada, actualiza existencias y genera CxP

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden con loteo completo
3. Hacer clic en **Confirmar entrada**
4. Revisar resumen:
   - Artículos con lotes y vencimientos
   - Cantidades que ingresan
   - Valor total de la compra
   - Impuestos (IVA)
5. Confirmar

El sistema automáticamente:
- Actualiza existencias en la bodega (IDXB)
- Genera movimiento de entrada (IMOV estado 1)
- Crea cuenta por pagar (FCXP) al proveedor
- Cambia orden a estado **Recibida**

## Resultado

- Los artículos ya están disponibles en la bodega
- Se generó una CxP pendiente de pago
- La orden queda cerrada
