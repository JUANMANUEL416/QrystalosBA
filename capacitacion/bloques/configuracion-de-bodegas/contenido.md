# Configuración de bodegas

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Las bodegas (IBOD) son los almacenes físicos donde se guardan los artículos. Cada bodega pertenece a un tipo y puede tener responsables, sedes y permisos específicos.

## Invariante

> Cada bodega debe tener código único, nombre, tipo de bodega válido y sede. Las bodegas activas pueden recibir movimientos de inventario.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_IBOD`  
**Rol:** Crea, modifica o elimina bodegas

## Pasos

1. Ir a **Inventario → Configuración → Bodegas**
2. Hacer clic en **Nuevo**
3. Seleccionar el **tipo de bodega**
4. Ingresar código, nombre y sede
5. Asignar responsable (opcional)
6. Activar la bodega
7. Guardar

## Errores comunes

- **Código duplicado** — El código de la bodega ya existe  
  **Solución:** Usar un código único

- **Tipo de bodega inactivo** — No se puede crear bodega con tipo inactivo  
  **Solución:** Activar primero el tipo de bodega

- **Bodega con existencias** — No se puede eliminar porque tiene artículos  
  **Solución:** Trasladar o dar salida a todos los artículos antes de eliminar
