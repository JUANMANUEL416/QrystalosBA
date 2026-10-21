# Artículos (IART)


## 🔹 Variables de configuración

| Código | Descripción | Valor | Efecto |
|--------|-------------|-------|--------|
| `DEINVNODESER` | Define artículos que NO generan servicio al crear | Pendiente validar | Evita crear SER automáticamente para ciertos tipos de artículo |
| `ESFARMACIA` | Indica si la bodega es farmacia (para dispensación) | SI o SIP (según institución) | Habilita reglas de dispensación farmacéutica |
| `IART_SER_UNICO` | Evita duplicar código CUM o descripción de medicamentos | SI (desde v2.0.7) | No permite crear artículos con CUM o descripción repetida |

> **💡 Tip:** Los valores mostrados son códigos habituales. Cada institución puede configurar los propios en USVGS.

## 🎯 Objetivo

Crear y configurar artículos (medicamentos, insumos, dispositivos) con su información básica, precios, costos, y asociación a servicios facturables.


## 📍 Contexto

**Proceso:** Inventario, Compras y Farmacia
**Tabla:** `IART`
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

<!-- AUDIENCIA: soporte-desarrollo -->

## 🔧 Referencia técnica (Soporte y Desarrollo)

### Stored Procedures

Esta tabla es gestionada por los siguientes procedimientos almacenados:

#### `SPQ_IART`

**Propósito:** Alta o edición del artículo. Genera el consecutivo con el prefijo del tipo (PRECNS + MCNS, NRO_ESPACIOS_ITARCNS). Puede crear el servicio SER (CREARSER) y registrar precio en lista ILPRED. Si cambia el estado y CAMBIO_ART_ESTADO = SI deja rastro en LOG_IART. Si INTERFAZ_INV está activa marca para la interfaz. PROCESO INSERTAR_HERMANO crea el SKU (presentación por fabricante, PRINCIPAL=0) y copia el IDITAR del principal en ese momento. PROCESO EDITAR cambia el IDITAR solo de ese artículo. PROCESO EDITAR_HERMANO escribe el IDITAR que traiga el JSON; si viene vacío conserva el del SKU.

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_IART`

**Propósito:** Antes de guardar: revisa el artículo principal y propone crear el servicio (COD_TARIFA_MAT_VE).

**Métodos:**

- `VALIDA_SERVICIO`: Valida datos antes de guardar

#### `SPQ_IART`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `IDITARUNIDOSIS`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `DETALLE_DOSIS`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Escribe en IART.

**Métodos:**

- `SET_PROCEDIMIENTO`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Crea la presentación unidosis a partir del medicamento base (tipo IDITARUNIDOSIS) y la transformación ITXA.

**Métodos:**

- `NUEVA_DOSIS`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Activa/inactiva el artículo y escribe LOG_IART.

**Métodos:**

- `CAMBIAR_ESTADO`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `GET_LOG_ESTADO`: Obtiene información

#### `SPQ_IART`

**Propósito:** Escribe en ITXA.

**Métodos:**

- `AGREGAR_INSUMO`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Escribe en ITXA.

**Métodos:**

- `DESCARTAR_INSUMO`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `VALIDA_PERMITE_HERMANO`: Valida datos antes de guardar

#### `SPQ_IART`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `CONTAR_HERMANOS`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Lista las presentaciones (SKU, PRINCIPAL=0) de un artículo principal, con el fabricante y el IDITAR propio de cada una. Con ESFARMACIA=SI y sin interfaz SAP, el código del SKU empieza por el del principal. No reescribe el tipo.

**Métodos:**

- `GET_ARTICULOS_X_FABRICANTE`: Obtiene información

#### `SPQ_IART`

**Propósito:** Igual que VALIDA_SERVICIO pero para la presentación hija: usa prefijos de medicamentos POS/NOPOS (PREFIJOMEDICAMENTOS, PREFIJOMEDNOPOS, IDMEDPOSRIPS, IDMEDNOPOSRIPS).

**Métodos:**

- `VALIDA_SERVICIO_HIJO`: Valida datos antes de guardar

#### `SPQ_IART`

**Propósito:** Devuelve el siguiente consecutivo según el tipo de artículo.

**Métodos:**

- `GET_CONTADOR`: Obtiene información

#### `SPQ_IART`

**Propósito:** Códigos de barras del artículo (pestaña Códigos de Barras).

**Métodos:**

- `GET_CODIGOS_BARRAS`: Obtiene información

#### `SPQ_IART`

**Propósito:** Borra el artículo.

**Métodos:**

- `ELIMINAR`: Elimina registro (con validaciones)

#### `SPQ_IART`

**Propósito:** Escribe en IARTE.

**Métodos:**

- `ESTABLECER_ESTANTE`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Crea el fabricante como tercero (TER + TEXCA con categoría TERCATFABRICANTE).

**Métodos:**

- `GUARDAR_FABRICANTE`: Inserta o actualiza registro

#### `SPQ_IART`

**Propósito:** Reasigna el SKU a otro artículo principal: IART.IDSERVICIO del origen pasa a ser el artículo destino y SER.IDREFERENCIA del SKU apunta a ese destino. Permiso TRASLADA_IART. La pantalla es Trasladar Artículo, dentro de Artículos por fabricante.

**Métodos:**

- `TRANSFERIR_ARTICULO`: Operación específica de negocio

#### `SPQ_IART`

**Propósito:** Excel del maestro IART (botón Excel en /inv/conf/iart). Segundo recordset filtrado por tipo y estado. PCOSTO solo si VER_PCOSTO=1 y USGRUH MENUQ_INVENTARIO / IART_VER_PCOSTO; si no, se elimina la columna.

**Métodos:**

- `EXPORTAR`: Exporta a Excel/archivo

#### `SPQ_IART`

**Propósito:** Kits: artículo compuesto (IARTK) y sus componentes (IARTKD).

**Métodos:**

- `CRUD_IARTK`: Create/Read/Update/Delete completo

#### `SPQ_IART`

**Propósito:** Transformaciones entre artículos (ITXA): origen, destino y cantidad. Sirve a los tipos 20/21 Transformación entre lotes.

**Métodos:**

- `CRUDITXA`: Create/Read/Update/Delete completo

#### `SPQ_IART`

**Propósito:** Diagnósticos UNIRS permitidos por artículo (IARTDX).

**Métodos:**

- `CRUDIARTDX`: Create/Read/Update/Delete completo

#### `SPQ_IARTO`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `LISTAR`: Lista registros

#### `SPQ_IARTO`

**Propósito:** Consulta / listado (sin escritura).

**Métodos:**

- `CONSULTAR`: Operación específica de negocio

#### `SPQ_IARTO`

**Propósito:** Escribe en CABECERA.

**Métodos:**

- `CONSULTAR_PDF`: Operación específica de negocio

#### `SPQ_IARTO`

**Propósito:** Hoja de gasto de osteosíntesis (IARTO/IARTOD).

**Métodos:**

- `GUARDAR`: Inserta o actualiza registro

#### `SPQ_IARTO`

**Propósito:** Aprueba la hoja: crea entrada (IDMOVOST_ENTR) y salida (IDMOVOST_SAL) en la bodega BODEGA_OSTEO, solicitud IZSOL y remisión; usa SPK_CONFIRMARENTRADAS y SPK_CONFIRMASAL_CM.

**Métodos:**

- `APROBAR`: Operación específica de negocio

#### `SPQ_IARTO`

**Propósito:** Escribe en IARTO.

**Métodos:**

- `MARCA_REV_ESTERILIZACION`: Operación específica de negocio

#### `SPQ_IARTO`

**Propósito:** Escribe en IARTO.

**Métodos:**

- `ANULAR`: Anula operación

#### `SPQ_IARTO`

**Propósito:** Escribe en TGEN.

**Métodos:**

- `CATALOGO_OSTEO`: Operación específica de negocio

#### `SPQ_IARTO`

**Propósito:** Escribe en TGEN.

**Métodos:**

- `ACTUALIZAR_PRECIO_OSTEO`: Modifica registro existente

#### `SPQ_IARTO`

**Propósito:** Importa el catálogo de material de osteosíntesis (IART + SER + tarifas).

**Métodos:**

- `IMPORTAR_MAT_OSTEO`: Importa desde Excel/archivo

#### `SPQ_IARTO`

**Propósito:** Escribe en IART, SER, TGEN.

**Métodos:**

- `ELIMINAR_MAT_OSTEO`: Elimina registro (con validaciones)


<!-- /AUDIENCIA -->
