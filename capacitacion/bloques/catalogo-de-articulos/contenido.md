# Catálogo de artículos

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

El catálogo de artículos (IART) contiene todos los productos que la institución puede comprar, almacenar y vender. Cada artículo tiene código, nombre, tipo, unidad de medida, precio y propiedades farmacéuticas si aplica.

## Invariante

> Cada artículo debe tener código único, nombre, tipo válido, unidad de medida y estar asociado a al menos una bodega con mínimos y máximos.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_IART`  
**Rol:** Crea, modifica o elimina artículos en el catálogo

### SPK_INVENTARIO

**Método:** `CRUD_IDXB`  
**Rol:** Asocia artículo con bodega y define mínimos/máximos

## Pasos

1. Ir a **Inventario → Configuración → Artículos**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre del artículo
4. Seleccionar tipo de artículo
5. Definir unidad de medida
6. Si es medicamento:
   - Ingresar principio activo
   - Concentración y forma farmacéutica
   - Registro INVIMA
7. Asociar con bodegas:
   - Seleccionar bodega
   - Definir stock mínimo y máximo
   - Ubicación (estante/fila/columna)
8. Guardar

## Errores comunes

- **Código duplicado** — El código del artículo ya existe  
  **Solución:** Usar un código único o buscar el artículo existente

- **Falta tipo de artículo** — No se seleccionó el tipo  
  **Solución:** Seleccionar el tipo apropiado

- **Sin bodega asociada** — El artículo no tiene bodegas  
  **Solución:** Asociar al menos una bodega con mínimos y máximos
