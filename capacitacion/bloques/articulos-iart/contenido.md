# Artículos (IART)

## 🎯 Objetivo

Crear y configurar artículos (medicamentos, insumos, dispositivos) con su información básica, precios, costos, y asociación a servicios facturables.

## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `IART`
**Frontend:** `/inv/conf/itar`, `/inv/conf/iart`

ITAR dice qué datos pide el artículo (lote, vencimiento, clase, genérico, concentración, riesgo, IVA), el prefijo del consecutivo y la cuenta. IART GUARDAR genera el código, puede crear el servicio SER (para facturar) y la presentación hija apunta a su principal (IDARTICULOPRIN). El SKU (artículo por fabricante, PRINCIPAL=0) copia el IDITAR del principal al crearse. Un cambio posterior del tipo del principal no actualiza los SKU ya creados, y la ventana Artículos por fabricante no muestra Tipo Artículo. La lista de Artículos solo trae principales; la presentación sale si se filtra por CUM o registro INVIMA, y ahí Editar con la lupa de Tipo Artículo guarda el tipo de esa fila. Trasladar Artículo cambia el principal (IDSERVICIO), no el tipo. Con IART_SER_UNICO = SI (liberado en 2.0.7) no se repite CUM ni descripción. Botón Generar Servicios en ITAR crea SER para todo el tipo. Precio regulado: la pantalla llama IART · CARGAR_PRECIO_REGULADO y ese método no existe en SPQ_IART (pendiente).

## 📋 Campos relevantes

| Icono | Campo | Descripción | Impacto / Uso |
|-------|-------|-------------|---------------|
| 🔑 | **IDITAR** | Tipo de artículo | Define el comportamiento del artículo (loteo, vencimiento, IVA) |
| 🔑 | **ESTADO** | Activo / Inactivo | Solo artículos Activos pueden comprarse y usarse en movimientos |
| 🔑 | **IDSERVICIO** | Servicio facturable asociado | Necesario si hay contabilidad/CxP. No dejar solo DEINVNODESER |
| 🔑 | **IDIMPUESTO / IDCLASE_IMP** | Impuesto del artículo | Obligatorio si USVGS IMPUESTO_OBL=SI |
| 🔑 | **IDARTICULOPRIN** | Artículo principal (para SKU) | SKU/presentaciones apuntan al principal, comparten IDSERVICIO |
| 📝 | **REGINVIMA / CODCUM** | Registro INVIMA y código CUM | Regulatorio, necesario para cotizaciones y trazabilidad |
| 🔑 | **PCOSTO** | Precio de costo | Base para valorización de inventario y CxP |

**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario

## 🔢 Pasos

**1.** Ir a Inventario → Configuración → Artículos

**2.** Seleccionar el tipo de artículo (IDITAR) — debe existir previamente

**3.** Ingresar descripción, código CUM, registro INVIMA (regulatorio)

**4.** Configurar impuesto (IDIMPUESTO) si es obligatorio

**5.** Si es SKU/presentación: seleccionar artículo principal (IDARTICULOPRIN)

**6.** Definir si crea servicio facturable (CREARSER=1) o usar uno existente

**7.** Guardar — el sistema genera el código (IDARTICULO) automáticamente

## ⚠️ Importante

- Artículo activo, con tipo coherente y servicio cuando se factura
- No se borra si está en alguna bodega (IDXB)
- DEINVNODESER configurada

## 💡 Tips

- Buscar primero si el artículo ya existe (CUM, INVIMA) para no duplicar
- Con IART_SER_UNICO=SI (liberado 2.0.7) el sistema no permite CUM ni descripción repetidos
- El precio de costo (PCOSTO) se actualiza automáticamente al confirmar entradas de compras

## 📝 Ejemplo práctico

**Artículo: Acetaminofén 500mg**
- IDITAR = Medicamentos
- DESCRIPCION = "Acetaminofén 500mg tableta"
- CODCUM = "19901234567890"
- REGINVIMA = "INVIMA2023M-001234"
- IDIMPUESTO = IVA 19%
- CREARSER = 1 (crea servicio automáticamente)
- ESTADO = Activo
→ El sistema genera: IDARTICULO = "MED00001" (según ITAR.PRECNS)

## 📌 Resumen

**IART** es una tabla decisiva que define el comportamiento de los artículos en inventario.

**Campos clave:** IDITAR, ESTADO, IDSERVICIO (cambian el comportamiento del sistema)

**Proceso:** 7 pasos desde configuración hasta operación

**Prerrequisitos:** Requiere ART

## ✅ Autoevaluación

**1.** ¿Qué pasa si dejo IDSERVICIO en DEINVNODESER en un artículo que se factura?

   <details><summary>Ver respuesta</summary>
   La facturación y contabilidad fallarán porque no hay servicio asociado. Debe crear un SER válido con centro de costo.
   </details>

**2.** ¿Cómo se actualiza el precio de costo (PCOSTO) de un artículo?

   <details><summary>Ver respuesta</summary>
   Se actualiza automáticamente al confirmar entradas de compras, tomando el costo de la factura.
   </details>
