# Proceso: Cartera · Notas débito/crédito

**Estado:** parcial (operación completa; configuración CPNT/FNT leída)  
**Módulo:** FNOT_COL → `SPQ_FNOT_COL` (14 METODOs, PREVERSION = liberada 2.0.7 al 2026-10-03)  
**Ventana:** Administrativo → Notas DB/CR · `/admin/notasdbcr` (`admin.notasdbcr`) · `NotasDBCRComponent.vue`  
**Alcance:** notas de cuentas por cobrar (FNOT/FNOTD). Las notas a proveedores (FCXPDBCR) son otro proceso.

> Solo flujo y explicación. El cuerpo del SP se baja a `sql/` cuando se analiza; no se archiva aquí.
> Este `.md` no se vuelca al libro (`incluirProcesoMdEnLibro: false`): el libro usa `capitulosLibro` de `proceso.json`.

## Qué es

Una nota corrige una factura ya emitida sin tocarla. La **nota crédito (NC)** baja lo que se cobra (descuentos, glosas aceptadas, acuerdos); la **nota débito (ND)** lo sube (valores faltantes, intereses). Toda nota recorre **crear → detallar → aplicar**; al aplicar mueve el saldo de la factura en cartera, genera el comprobante contable y queda lista para **Encolar** a la DIAN.

Lo que no se hace aquí: anular una factura completa (Facturación; una NC manual por el 100 % está bloqueada), notas a proveedores (CxP), responder glosas o cerrar conciliaciones (esos módulos crean sus notas, que aquí solo se consultan, encolan e imprimen).

## Capas

1. **Configuración** — conceptos de nota (CPNT: cuenta contable, homologación DIAN), tipos de nota (FNT), periodos PRI abiertos (cartera y contable), resolución/firma DIAN, variables `IDCONCEP_ANULAFTRCE`, `FTR_PREVALIDA_ACTIVA`, `FNOT_ANULA_REVERSA`, `SOL_AUT_NDC`.
2. **Proceso propio** — crear cabecera (`FNOT_CRUD`), detalle manual (`FNOT_CRUDFNOTD`) o por concepto (`FNOT_ADDDETA`/`FNOT_DELDETA` → `SPK_GENITEMS_NOTACR`/`SPK_DESITEMS_NOTACR`), aplicar (`FNOT_APLICAR` → `SPK_NOTASCXC`), anular abierta (`FNOT_CRUD` ANULAR) o aplicada (`FNOT_ANULANOTA` → `SPK_ANULANOTA_CR`), carga masiva (`CARGAR_NOTAS_LOTE` → `FNOT_CREARMASIVO` → `SPK_APLICA_FNOT_MASIVA` / `ANULARFAC`; `FNOT_LIMPIARPDX`).
3. **Lo que llega** — facturas FTR con saldo (VWK_FTRNDCR / VWK_CXCDIASVTO), plano desde Recaudos (`CARGAR_NOTAS`), notas con procedencia AUDITORIA (Glosas) y CONCILIA (Conciliaciones).
4. **Subproceso unido** — cola DIAN (`FNOT_ENCOLAR` / `FNOT_DESENCOLAR` / `FNOT_ACTUALIZAR_FECHA`), SUNAT en Perú (`FNOT_ENVIARSUNAT`), anulación de factura por NC (ANULAFACT).
5. **Contabilidad** — al aplicar `SPK_NC_CONTAB_FNOT` genera el MCP con la cuenta del concepto; al anular aplicada, `SPK_ANULANOTA_CR` anula o reversa según `FNOT_ANULA_REVERSA` y periodo.

## Controles que el usuario ve (botones)

| Botón | Aparece cuando | Hace |
|---|---|---|
| Nueva Nota | Clase elegida en el filtro | Cabecera: factura, concepto, observación; NC puede marcar «Afecta todos los servicios» |
| Editar Nota / Detalle / Generar · Eliminar Detalles | Nota Abierta, no anulada | Cabecera y líneas |
| Aplicar | Abierta con detalle | Valida y aplica (cartera + comprobante) |
| Anular Nota (abierta) | Abierta | Motivo ≥ 10 caracteres; sin reverso ni DIAN |
| Anular Nota (aplicada) | Aplicada, procedencia NOTAS/AJUSTE | Bloqueada si FACTE ≠ 0; reversa cartera y contabilidad |
| Imprimir Nota / Comprobante / N_Factura | Aplicada (Comprobante: contabilizada) | Formatos |
| Encolar | Aplicada, FACTE 0 | Cola DIAN (1 o 5); fecha no anterior a hoy |
| Desencolar | FACTE 1 o 3 | Vuelve a Sin Enviar |
| Actualizar Fecha | Aplicada, FACTE 0, fecha anterior a hoy | Pone hoy en la nota y el comprobante |
| Envios y Respuestas | FACTE 2, 3 o 4 | XML y respuesta DIAN |
| Subir Notas | País ≠ Perú | Carga masiva Excel (nace aplicada) |
| Exportar Excel / ZIP masivo | Siempre (barra) | Según filtro actual; ZIP hasta 2000 notas por archivo |

## Reglas clave

- Una sola nota abierta por factura. Concepto obligatorio. Fecha en mes abierto en cartera y contabilidad.
- NC: el detalle no puede superar el saldo; NC por el 100 % → KO (anular desde Facturación). ND: sin tope, siempre detalle manual.
- Carga masiva: encabezados exactos, descripción/observación ≥ 15 caracteres, VALIDACION = OK; NC exige factura FACTE 2/6; ANULARFACT = SI anula la factura. Las notas nacen aplicadas.
- Encolar: factura notificada (2) o prevalidada (6); mismo mes → fecha hoy; mes anterior ≤ 3 → mueve fecha contable del MCP (sin MCPE, PRI abierto); más de 3 meses → no encola.
- Notificada por la DIAN (FACTE 2) = punto de no retorno: no se anula; se emite la nota contraria.

## Pendientes

- Defecto FE: filtro Estado = Aplicadas no filtra (`where` descarta el caso "A"). Ver `pendientes.json`.
- Estados E/Z/R del filtro (En Cartera, Autorizadas, Rechazadas) sin respaldo en el SP: confirmar si existe flujo de autorización.
- `SPK_RELIQUIDA_FTR` y `SPK_GENERA_JSON_PERU_NOTADBCR` siguen en estado listado.

## Libro

12 capítulos temáticos con sketchnotes (`libro/img/notas_*_sketchnote.jpg`, generador `libro/scripts/gen_notas_sketchnotes.py`): guía rápida, NC vs ND, hilo común, por concepto, detalle manual, carga masiva, aplicar, anular, DIAN, imprimir/ZIP, estados, procedencia.
