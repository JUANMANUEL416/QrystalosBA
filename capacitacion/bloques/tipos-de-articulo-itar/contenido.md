# Tipos de artículo (ITAR)

## 🎯 Objetivo

Configurar los tipos de artículo que definen el comportamiento de los artículos en inventario: si lotean, si tienen fecha de vencimiento, si manejan IVA, el consecutivo automático y las reglas de control de stock.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITAR`
**Frontend:** `/inv/conf/itar`, `/inv/conf/iart`

### 💊 **Configuración del tipo de artículo**

ITAR define qué datos pide el sistema para cada artículo: lote, fecha de vencimiento, clase terapéutica, principio activo (genérico), concentración, nivel de riesgo e IVA. También configura el prefijo del consecutivo automático y la cuenta contable asociada.

### 🔢 **Generación automática de códigos**

Cuando se guarda un artículo (IART · GUARDAR), el sistema genera automáticamente el código según el prefijo configurado en ITAR. Este proceso puede crear también el servicio SER vinculado para facturación hospitalaria.

### 📦 **Artículos principal y presentaciones (SKU)**

Los artículos pueden tener una estructura jerárquica: un artículo principal y múltiples presentaciones o SKU (artículos por fabricante). La presentación hija apunta a su principal mediante IDARTICULOPRIN. Al crear el SKU, se copia el IDITAR del principal.

> **⚠️ Importante:** Un cambio posterior del tipo del artículo principal NO actualiza los SKU ya creados. La ventana "Artículos por fabricante" no muestra el campo Tipo Artículo.

### 🔍 **Búsqueda y filtros especiales**

La lista de artículos muestra por defecto solo los principales. Las presentaciones aparecen cuando se filtra por código CUM (medicamentos regulados) o registro INVIMA. Al editar desde esa vista, el botón de búsqueda de Tipo Artículo guarda el tipo de esa fila específica.

### 🏥 **Operaciones especiales**

- **Trasladar Artículo:** Cambia el servicio principal vinculado (IDSERVICIO), pero NO cambia el tipo de artículo.
- **Variable IART_SER_UNICO = SI** (desde v2.0.7): Evita duplicar códigos CUM o descripciones de medicamentos.
- **Botón "Generar Servicios"** en ITAR: Crea servicios SER para todos los artículos de ese tipo.

> **💡 Tip:** La funcionalidad de precio regulado aún está pendiente (IART · CARGAR_PRECIO_REGULADO no existe en SPQ_IART).


## 📋 Campos relevantes

| Icono | Campo | Descripción | Impacto / Uso |
|-------|-------|-------------|---------------|
| 🔑 | **MLOTEO** | Define si el artículo usa loteo | 1 = sin pantalla de loteo (INICIAL=1). 0 = lotear en tránsito |
| 🔑 | **MFECHAVENCIMIENTO** | Exige fecha de vencimiento | CONF_ENTRADA valida que todas las líneas tengan fecha |
| 🔑 | **MIVA** | Maneja IVA | Coherencia con IART.IDIMPUESTO, afecta IMOVH y FCXPD |
| 🔑 | **PRECNS / MCNS** | Prefijo y consecutivo del código | Genera IDARTICULO automáticamente. Error: 'Revise ITAR PRECNS' |
| 🔑 | **MPRINCIPAL** | Permite artículos hijo (SKU/presentaciones) | Artículos con IDARTICULOPRIN comparten IDSERVICIO |
| 🔑 | **MSTOCK** | Controla existencias | Si no controla stock, no debe usarse en movimientos que afectan IEXI |

**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario

## 🔢 Pasos

**1.** Ir a Inventario → Configuración → Tipos de artículo

**2.** Nuevo tipo: ingresar nombre y seleccionar opciones de loteo, vencimiento, IVA

**3.** Configurar prefijo (PRECNS) y si el consecutivo es automático (MCNS)

**4.** Definir si el tipo permite artículos principal/hijo (MPRINCIPAL)

**5.** Guardar y verificar que el tipo aparezca en la lista

## ⚠️ Importante

- Artículo activo, con tipo coherente y servicio cuando se factura
- No se borra si está en alguna bodega (IDXB)
- DEINVNODESER configurada

## 💡 Tips

- Crear primero los tipos más comunes: Medicamentos (loteo+vencimiento+IVA), Insumos (solo loteo), Dispositivos (sin loteo ni vencimiento)
- El prefijo (PRECNS) no se puede cambiar después de crear artículos de ese tipo
- Si MPRINCIPAL=1, permite crear SKUs (ej: Acetaminofén 500mg principal, Acetaminofén Genven 500mg SKU)

## 📝 Ejemplo práctico

**Tipo: Medicamentos controlados**
- MLOTEO = 1 (sin pantalla de loteo manual)
- MFECHAVENCIMIENTO = 1 (exige fecha de vencimiento)
- MIVA = 1 (maneja IVA)
- PRECNS = "MED"
- MCNS = SI (consecutivo automático: MED00001, MED00002, ...)
- MPRINCIPAL = 1 (permite presentaciones/SKUs)
- MSTOCK = 1 (controla existencias)

## 📌 Resumen

**ITAR** es una tabla decisiva que define el comportamiento de el sistema en inventario.

**Campos clave:** MLOTEO, MFECHAVENCIMIENTO, MIVA (cambian el comportamiento del sistema)

**Proceso:** 5 pasos desde configuración hasta operación

**Prerrequisitos:** Ninguno (configuración base)

## ✅ Autoevaluación

**1.** ¿Qué sucede si un tipo de artículo tiene MLOTEO=0?

   <details><summary>Ver respuesta</summary>
   El artículo requiere pantalla de loteo en tránsito (IZSOL_TRANSITO). Si MLOTEO=1, el loteo es automático (INICIAL=1).
   </details>

**2.** ¿Se puede cambiar el PRECNS de un tipo después de crear artículos?

   <details><summary>Ver respuesta</summary>
   No. El prefijo queda fijo porque ya se usó para generar códigos de artículos (IDARTICULO).
   </details>

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_ITAR`

**Propósito:** Crea el tipo de artículo: qué pide el artículo (clase, principio activo, forma, concentración, unidad, fecha de vencimiento, lote, stock, riesgo, IVA), prefijo del consecutivo y cuenta contable.

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_ITAR`

**Propósito:** Escribe en ITAR.

**Métodos:**

- `ACTUALIZAR`: Modifica registro existente

#### `SPQ_ITAR`

**Propósito:** Borra el tipo de artículo.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)

#### `SPQ_ITAR`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `GET_IDITAR`: Obtiene información

#### `SPQ_ITAR`

**Propósito:** Exporta a Excel la tarifa de los artículos del tipo (KEXCEL_FILL).

**Métodos:**

- `TARI_EXPORTAR_EXCEL`: Exporta a Excel/archivo

#### `SPQ_ITAR`

**Propósito:** Escribe en KEXCEL_FILL; llama SPQ_GENSEQUENCE.

**Métodos:**

- `TARD_EXPORTAR_EXCEL`: Exporta a Excel/archivo


<!-- /AUDIENCIA -->
