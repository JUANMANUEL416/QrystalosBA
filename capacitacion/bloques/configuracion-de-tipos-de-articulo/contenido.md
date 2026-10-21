# Configuración de tipos de artículo

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Los tipos de artículo (ITAR) clasifican los productos según su naturaleza y uso. Cada tipo define propiedades como manejo de lotes, vencimientos, refrigeración y regulación.

Tipos comunes:
- **Medicamento** — Requiere lote, vencimiento y registro INVIMA
- **Dispositivo médico** — Requiere lote y registro
- **Insumo** — Sin requerimientos especiales
- **Alimento** — Requiere vencimiento

## Invariante

> Cada tipo debe tener código único y definir si maneja lotes, vencimientos, refrigeración y regulación sanitaria.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ITAR`  
**Rol:** Crea, modifica o elimina tipos de artículo

## Pasos

1. Ir a **Inventario → Configuración → Tipos de artículo**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre
4. Marcar las opciones:
   - Maneja lotes
   - Maneja vencimientos
   - Requiere refrigeración
   - Requiere registro sanitario
5. Guardar

## Errores comunes

- **Código duplicado** — El código ya existe  
  **Solución:** Usar un código único
