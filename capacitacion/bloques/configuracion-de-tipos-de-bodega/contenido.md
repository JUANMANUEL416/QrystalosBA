# Configuración de tipos de bodega

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Los tipos de bodega (ITBOD) definen las categorías de almacenamiento disponibles en el sistema. Cada tipo determina las características y comportamientos de las bodegas que lo usan.

Tipos comunes:
- **Farmacia** — Medicamentos y dispositivos médicos
- **Alimentos** — Cocina y alimentación
- **Papelería** — Suministros de oficina
- **Aseo** — Productos de limpieza
- **Insumos médicos** — Material quirúrgico y hospitalario

## Invariante

> Cada tipo de bodega debe tener un código único y un nombre descriptivo. Los tipos activos determinan qué bodegas pueden crearse.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ITBOD`  
**Rol:** Crea, modifica o elimina tipos de bodega

## Pasos

1. Ir a **Inventario → Configuración → Tipos de bodega**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre del tipo
4. Definir si maneja lotes, vencimientos o refrigeración
5. Guardar

## Errores comunes

- **Código duplicado** — El código del tipo ya existe  
  **Solución:** Usar un código único

- **Tipo en uso** — No se puede eliminar porque hay bodegas asociadas  
  **Solución:** Eliminar primero las bodegas o cambiar su tipo
