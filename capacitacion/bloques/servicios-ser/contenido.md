# Servicios (SER)

## 🎯 Objetivo

Configurar servicios facturables asociados a artículos para que puedan aparecer en facturación y contabilidad con su centro de costo correcto.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `SER`
**Frontend:** `/inv/conf/itar`, `/inv/conf/iart`


### 💊 **Artículos y presentaciones**

ITAR dice qué datos pide el artículo (lote, vencimiento, clase, genérico, concentración, riesgo, IVA), el prefijo del consecutivo y la cuenta. IART GUARDAR genera el código, puede crear el servicio SER (para facturar) y la presentación hija apunta a su principal (IDARTICULOPRIN).

### 🏥 **Artículos y presentaciones**

El SKU (artículo por fabricante, PRINCIPAL=0) copia el IDITAR del principal al crearse. Un cambio posterior del tipo del principal no actualiza los SKU ya creados, y la ventana Artículos por fabricante no muestra Tipo Artículo.

### 🩺 **Estructura de datos**

La lista de Artículos solo trae principales; la presentación sale si se filtra por CUM o registro INVIMA, y ahí Editar con la lupa de Tipo Artículo guarda el tipo de esa fila. Trasladar Artículo cambia el principal (IDSERVICIO), no el tipo.

### ⚕️ **Generación de códigos**

Con IART_SER_UNICO = SI (liberado en 2.0.7) no se repite CUM ni descripción. Botón Generar Servicios en ITAR crea SER para todo el tipo.


## 📋 Campos relevantes

| Icono | Campo | Descripción | Impacto / Uso |
|-------|-------|-------------|---------------|
| 🔑 | **IDKMCOM** | Centro de costo contable | Define dónde se contabiliza (CXP_COMPRAS, MOV_INVENTARIO) |
| 📝 | **DESCRIPCION** | Nombre del servicio | Aparece en facturación y contabilidad |

**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario

## ⚠️ Importante

- Artículo activo, con tipo coherente y servicio cuando se factura
- No se borra si está en alguna bodega (IDXB)
- DEINVNODESER configurada

## 📌 Resumen

**SER** es una tabla decisiva que define el comportamiento de el sistema en inventario.

**Campos clave:** IDKMCOM (cambian el comportamiento del sistema)

**Proceso:** 0 pasos desde configuración hasta operación

**Prerrequisitos:** Requiere configuración previa

<!-- AUDIENCIA: soporte-desarrollo -->

<!-- /AUDIENCIA -->
