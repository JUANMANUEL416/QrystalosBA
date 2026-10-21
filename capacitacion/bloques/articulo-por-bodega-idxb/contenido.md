# Artículo por bodega (IDXB)

## 🎯 Objetivo

Asociar artículos a bodegas con punto de reorden, máximo y mínimo para control de stock.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `IDXB`
**Frontend:** `/inv/conf/itar`, `/inv/conf/iart`


### 💊 **Artículos y presentaciones**

ITAR dice qué datos pide el artículo (lote, vencimiento, clase, genérico, concentración, riesgo, IVA), el prefijo del consecutivo y la cuenta. IART GUARDAR genera el código, puede crear el servicio SER (para facturar) y la presentación hija apunta a su principal (IDARTICULOPRIN).

### 🏥 **Artículos y presentaciones**

El SKU (artículo por fabricante, PRINCIPAL=0) copia el IDITAR del principal al crearse. Un cambio posterior del tipo del principal no actualiza los SKU ya creados, y la ventana Artículos por fabricante no muestra Tipo Artículo.

### 🩺 **Estructura de datos**

La lista de Artículos solo trae principales; la presentación sale si se filtra por CUM o registro INVIMA, y ahí Editar con la lupa de Tipo Artículo guarda el tipo de esa fila. Trasladar Artículo cambia el principal (IDSERVICIO), no el tipo.

### ⚕️ **Generación de códigos**

Con IART_SER_UNICO = SI (liberado en 2.0.7) no se repite CUM ni descripción. Botón Generar Servicios en ITAR crea SER para todo el tipo.


## ⚠️ Importante

- Artículo activo, con tipo coherente y servicio cuando se factura
- No se borra si está en alguna bodega (IDXB)
- DEINVNODESER configurada

## 📌 Resumen

**IDXB** es una tabla de configuración que define el comportamiento de el sistema en inventario.

**Campos clave:** Configuración básica

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Requiere DXB

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_IDXB`

**Propósito:** Alta, edición o borrado del artículo en la bodega (IDXB): stock mínimo, máximo, punto de reorden, requiere autorización, días de sugerido.

**Métodos:**

- `CRUD_IDXB`: Create/Read/Update/Delete completo


<!-- /AUDIENCIA -->
