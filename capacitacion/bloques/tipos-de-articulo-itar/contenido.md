# Tipos de artículo (ITAR)

## 🎯 Objetivo

Configurar los tipos de artículo que definen el comportamiento de los artículos en inventario: si lotean, si tienen fecha de vencimiento, si manejan IVA, el consecutivo automático y las reglas de control de stock.

## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `ITAR`
**Frontend:** `/inv/conf/itar`, `/inv/conf/iart`

ITAR dice qué datos pide el artículo (lote, vencimiento, clase, genérico, concentración, riesgo, IVA), el prefijo del consecutivo y la cuenta. IART GUARDAR genera el código, puede crear el servicio SER (para facturar) y la presentación hija apunta a su principal (IDARTICULOPRIN). El SKU (artículo por fabricante, PRINCIPAL=0) copia el IDITAR del principal al crearse. Un cambio posterior del tipo del principal no actualiza los SKU ya creados, y la ventana Artículos por fabricante no muestra Tipo Artículo. La lista de Artículos solo trae principales; la presentación sale si se filtra por CUM o registro INVIMA, y ahí Editar con la lupa de Tipo Artículo guarda el tipo de esa fila. Trasladar Artículo cambia el principal (IDSERVICIO), no el tipo. Con IART_SER_UNICO = SI (liberado en 2.0.7) no se repite CUM ni descripción. Botón Generar Servicios en ITAR crea SER para todo el tipo. Precio regulado: la pantalla llama IART · CARGAR_PRECIO_REGULADO y ese método no existe en SPQ_IART (pendiente).

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
