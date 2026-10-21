# Tránsito de mercancía

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Tránsito

## Explicación

El tránsito (ITRA) registra la llegada de la mercancía del proveedor. Se ingresa la remisión, las cantidades recibidas y observaciones. El tránsito puede ser parcial (llegadas múltiples) o total.

## Invariante

> Cada tránsito debe tener remisión, fecha, cantidades recibidas ≤ cantidades ordenadas, y estado (Pendiente loteo).

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `ON_ACEPTA_TRANSITO`  
**Rol:** Registra tránsito y crea movimiento temporal (IMOV tipo 02 estado 0)

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden **Confirmada**
3. Hacer clic en **Registrar tránsito**
4. Ingresar número de remisión del proveedor
5. Ingresar fecha de llegada
6. Para cada artículo:
   - Cantidad recibida (puede ser menor que la ordenada)
   - Observaciones si hay faltantes o daños
7. Guardar

## Siguiente paso

El tránsito queda pendiente de **Loteo** para ingresar números de lote, vencimientos y cantidades definitivas.
