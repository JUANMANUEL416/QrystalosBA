# Custodia de medicamentos

Guardar en una bodega de la institución un medicamento que **no es de la institución**: lo entrega un proveedor para un **paciente concreto**, sin compra ni factura. El sistema lo recibe como **entrada propia** (tipo de movimiento de la variable `IDINVTPROPIA`), con el paciente en la cabecera y, en la carga masiva, una unidad por línea.

Actualizado 2026-10-04. Contrastado con Qrystalos2, la documentación de tablas y los procedimientos de IXONLINE/SQL (PREVERSION; los bloques de custodia son idénticos a la última liberada).

## Qué hace la persona

### Camino manual (pocas unidades de un proveedor)

1. Inventario → Movimientos: elige la bodega de custodia y deja el filtro en **Crédito**. Permiso `BrwTransito · Bcustodia`.
2. En el panel de tránsito pulsa **Ingresar Custodia**: proveedor y observación. Se crea el tránsito (`ITRA`, origen `CUSTODIA`, tipo `IDINVTPROPIA`, estado 0).
3. **Nuevo artículo**: código de presentación (no el principal) y cantidad. Una línea por clic, sin lote ni vencimiento.
4. En **Traer del Tránsito** lotea cada artículo: lote del proveedor, vencimiento, cantidad. Lo no loteado necesita causa.
5. **Aceptar** el tránsito: genera la entrada en estado 0 con el tipo del tránsito y el proveedor como tercero; el tránsito pasa a estado 1.
6. Abre la entrada: la cabecera muestra **Información del Paciente**; con Buscar paciente elige el afiliado.
7. **Confirmar entrada**: exige paciente, no pide costo ni factura. Suma existencia y enlaza la aplicación pendiente del paciente.
8. Clic derecho → **Acta de Recepción de Custodia**.

### Camino masivo (Excel)

1. Botón morado **Ingresar Custodia** en la barra (filtro Crédito): solo observación; el proveedor va por NIT en el Excel. Abre el tránsito.
2. **Subir Custodia Masivo** (permiso `Masivo_cus`, bodega marcada *Es de Custodia*): descargar plantilla, llenarla, procesar.
3. Columnas: `CEDULA, IDARTICULO, CANTIDAD, CANTIDADREV, TERCERO (NIT), NOLOTEPEDIDO, FECHAVENCE (YYYY-MM-DD), PCOSTO (opcional), TEMPERATURA, CUMPLE, APROBADO`.
4. El procedimiento valida todo o nada (bodega, tránsito, NIT, fechas, artículos activos no principales permitidos con servicio, obligatorios, pacientes activos) y arma un tránsito por proveedor, un movimiento por paciente y proveedor, y una unidad por línea con lote interno en existencia cero.
5. Confirmar cada movimiento. **Acta custodia por tercero** para el consolidado del proveedor.

## Qué queda guardado

| Tabla | Qué |
|---|---|
| `ITRA` / `ITRAH` | Tránsito del proveedor (`CNSMOVORI = CUSTODIA`, `USUARIOTRA` = proveedor). Detalle con temperatura, cumple, aprobado, cantidad revisada. |
| `IMOV` / `IMOVH` | Entrada tipo `IDINVTPROPIA`, `CNSTRAN` = paciente, `TIPO_DOC_COMPRA = N`, `ESTRANSITO = 1`. Una línea por unidad en la masiva. |
| `IEXI` | Un lote interno por unidad en la bodega de custodia. `EXISLOTE 0` hasta confirmar. |
| `APLIMF` / `IEXIF` | Al confirmar: línea de aplicación del paciente `RESERVADO` con el lote; requerimiento `RECEPCIONADO`. |

## Estados

- `ITRA.ESTADO`: 0 abierto · 1 aceptado (manual) · 2 loteado por la masiva · 3 anulado.
- `IMOV.ESTADO`: 0 borrador · 1 confirmado · 2 anulado.
- `IEXI.EXISLOTE`: 0 sin confirmar o consumido · 1 unidad disponible.

## Procedimientos

| Objeto | Método | Papel |
|---|---|---|
| `SPQ_IZSOL` | `AGREGA_CUSTODIA` | Abre el tránsito. Error si falta `IDINVTPROPIA`. |
| `SPQ_IZSOL` | `CONSULTA_ARTICULOS_PRUEBA` | Catálogos del diálogo (artículos no principales permitidos, terceros PRO). |
| `SPQ_IZSOL` | `AGREGA_ARTICULO_ITRAH` | Línea manual. **Sin validaciones** (bloque vacío). |
| `SPQ_IZSOL` | `ON_ACEPTA_TRANSITO` | Acepta el tránsito manual; exige loteo o causa. |
| `SPK_INSERTENTTRANSITO` | — | Genera la entrada desde las líneas loteadas. |
| `SPQ_IZSOL` | `SUBIR_CUSTODIA_MASIVA` | Procesa el Excel; doce validaciones con mensaje exacto. |
| `SPQ_IZSOL` | `CONF_ENTRADA` | Confirma; en custodia exige paciente, no costo ni factura; enlace automático (cuatro rutas). |
| `SPK_CONFIRMARENTRADAS` | — | Suma existencia por unidad; no mezcla pacientes; tránsito solo desde `CNSITRA`. |
| `SPQ_IMOV_3` | `RPT_ACTA_RECEPCION_CUSTODIA` | Acta del movimiento. |
| `SPQ_IMOV_3` | `RPT_ACTAS_CUSTODIA_TERCERO_LISTA` / `RPT_ACTA_CUSTODIA_TERCERO_CONSOLIDADA` | Lista y acta consolidada por proveedor. |
| `SPQ_EXISTENCIA` | `EXPORTA_INFORME_CUSTODIA` | Exportación del informe. |

## Configuración

- Variable `IDINVTPROPIA` (tipo Entrada propia). Cada institución define su código.
- Bodega con `IBOD.ESDECUSTODIA = 1` y tipos de artículo permitidos (`IBODS`).
- Permisos `BrwTransito · Bcustodia` y `BrwTransito · Masivo_cus`.
- Opcionales: `APLIM_USA_MEDCUSTOD` (aplicación), `SED.IDBODEGACUSTODIA` (sede).

## Dónde sigue

- **Aplicación de medicamentos**: al agendar la cita solo se ofrecen lotes `IDINVTPROPIA` del paciente.
- **Dispensación**: la solicitud del paciente puede tomar el lote.
- **Informe de Custodia** en Existencias: paciente, lote, existencia, vencimiento; *Solo con existencia* oculta lo consumido.

## Hallazgos

1. `AGREGA_ARTICULO_ITRAH` no valida nada (marcador vacío).
2. El camino manual exige lotear y aceptar el tránsito; el libro anterior y el runbook lo resumían como un paso.
3. El runbook de documentación cita `GestionTempComponent.vue` y `SPQ_IMOV` para actas; hoy son `IMOVComponetNew.vue` y `SPQ_IMOV_3`.
4. `SPK_CONFIRMARENTRADAS` usa `CNSTRAN` como respaldo del tránsito si `CNSITRA` va vacío (riesgo bajo: en los dos caminos siempre va lleno).
5. La masiva no rechaza vencimientos pasados (solo el formato).
