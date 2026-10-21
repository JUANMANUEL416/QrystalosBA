# Tipo de artículo y artículo (ITAR / IART / SER)

## Contexto

**Proceso:** Inventario, Compras y Farmacia
**Capa:** Configuración

## Explicación

ITAR dice qué datos pide el artículo (lote, vencimiento, clase, genérico, concentración, riesgo, IVA), el prefijo del consecutivo y la cuenta. IART GUARDAR genera el código, puede crear el servicio SER (para facturar) y la presentación hija apunta a su principal (IDARTICULOPRIN). El SKU (artículo por fabricante, PRINCIPAL=0) copia el IDITAR del principal al crearse. Un cambio posterior del tipo del principal no actualiza los SKU ya creados, y la ventana Artículos por fabricante no muestra Tipo Artículo. La lista de Artículos solo trae principales; la presentación sale si se filtra por CUM o registro INVIMA, y ahí Editar con la lupa de Tipo Artículo guarda el tipo de esa fila. Trasladar Artículo cambia el principal (IDSERVICIO), no el tipo. Con IART_SER_UNICO = SI (liberado en 2.0.7) no se repite CUM ni descripción. Botón Generar Servicios en ITAR crea SER para todo el tipo. Precio regulado: la pantalla llama IART · CARGAR_PRECIO_REGULADO y ese método no existe en SPQ_IART (pendiente).

## Invariante

> Artículo activo, con tipo coherente y servicio cuando se factura. No se borra si está en alguna bodega (IDXB). DEINVNODESER configurada.

## Procedimientos almacenados

### SPQ_ITAR
**Método:** `GUARDAR / ELIMINAR / TARI_EXPORTAR_EXCEL`
**Rol:** Tipo de artículo.

### SPQ_IART
**Método:** `GUARDAR / VALIDA_SERVICIO / VALIDA_SERVICIO_HIJO / GET_CONTADOR`
**Rol:** Alta y edición con servicio.

### SPQ_IART
**Método:** `CAMBIAR_ESTADO / TRANSFERIR_ARTICULO / GUARDAR_FABRICANTE`
**Rol:** Estado con LOG_IART. TRANSFERIR_ARTICULO mueve el SKU a otro principal y no cambia el tipo. GUARDAR_FABRICANTE crea el fabricante como tercero.

### SPQ_IART
**Método:** `CRUD_IARTK / CRUDITXA / CRUDIARTDX / NUEVA_DOSIS`
**Rol:** Kits, transformaciones, diagnósticos UNIRS, unidosis.

### SPQ_IEXI
**Método:** `EDITAR / SACAR_CUARENTENA`
**Rol:** Corregir lote y liberar cuarentena (BTN_INV_EDIT_ART).
