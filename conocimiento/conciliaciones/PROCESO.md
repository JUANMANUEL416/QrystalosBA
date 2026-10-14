# Proceso: Cartera · Conciliaciones

**Estado:** completo (libro reorganizado 2026-10-03)  
**Módulo:** FCONCI_COL  
**Ventana:** `/admin/Concilia` (`Admin.Conci`) → `ConciliaPage.vue` → `Concilia/FconciComponent.vue`  
**Envío contable:** `/cont` → Otros módulos → Conciliaciones (`OMConciliacionesComponent`)

> Fuente SQL: IXONLINE/SQL `SPQ_FCONCI_COL` (8 METODO) y `SPK_APLICA_CONCILIACION`, releídos 2026-10-03; PREVERSION idéntica a la liberada 2.0.7.
> `SPK_RETIRA_FACTURA_CONCI`, `SPK_CONTAB_CONCI`, `SPK_NC_CONTAB_ANULA_CONCI`, `SPQ_CONCILIACIONES` leídos 2026-09-06.
> Tablas FCONCI/FCONCID/FCXCDV no tienen ficha en `qrystalos.documentacion` (pendiente). No inventar columnas.

## Qué es

Acta del acuerdo entre la IPS y una EPS sobre facturas con saldo en cartera (glosas defendidas, ratificaciones, saldos de conciliaciones previas, facturas).
Cabecera `FCONCI` (tercero, F. Concilia, Fecha Pago Acuerdo, Nro. Externo, Funcionario Externo, TIPO Individual/Porcentaje, Observaciones ≥ 10) y detalle `FCONCID` por vencimiento `FCXCDV`
(SALDONETO, VLRACEPTADO, VLRRECUPERAR = SALDONETO − VLRACEPTADO, CONDCONCEPTO CPNT, CNSFCGLO opcional, CNSGLO).

Estados: **Ingresada** (se edita) → **Cerrada** (confirmada) → **Anulada** (reversada). No hay regreso a Ingresada.

**No es:** conciliación bancaria (`/cont/conciContables`, CONCFGLO), responder glosas (Cartera · Glosas), ni recaudo.

## Ciclo

1. **Crear** — Nueva Conciliación → `CRUD_FCONCI` Nueva (`@CONCI`, PROCEDENCIA CXC, CONTABILIZADA 0). Editar/Borrar solo Ingresada; Borrar exige sin detalle.
2. **Agregar facturas** — Nuevo Detalle (`CRUD_FCONCID`), Agregar Archivo Plano (`CARGA_EXCEL_FCONCID`; plantilla N_FACTURA, TIPO, CNSGLO, VLRACEPTADO, CODCONCEPTO), Aplicar concepto a líneas marcadas (varios `CRUD_FCONCID` Editar), Limpiar Todos (`LIMPIAR_FCONCID`).
   - Seleccionar Factura: `FCXCDV ⋈ FTR` por IDTERCERO, SALDONETO > 0 y `TIPO IN (CONCIGLOSA_TIPOSPERM)` si la variable tiene valor.
   - TIPO P: VLRACEPTADO = SALDONETO × PORCENTAJE / 100 (campo bloqueado; no recalcula al cambiar el % después).
3. **Revisar** — Imp.Conci. (`IMPRIMIR`, PDF) en cualquier estado; Escaneo (DOCXTPO tipo FCONCI) si no Anulada.
4. **Confirmar** — `CONFIRMAR_CONCILIACION`: valida PRI si `FNOT_FECHACONCILIA = CONCILIACION`; toda línea con CNSGLO → glosa existe, CERRADA = 1, FECHARESP, radicada (FGLO.RADICADO o FGLOI/FGLOID); ningún TIPO fuera de `CONCIGLOSA_TIPOSPERM`.
   Asigna `@FNOTC` (sede + C + 8) a ítems con VLRACEPTADO > 0 → `SPK_APLICA_CONCILIACION`:
   - aceptado > 0: FNOT clase C PROCEDENCIA CONCILIA (`SPK_GENITEMS_NOTACR`, `SPK_NOTASCXC`); fecha = FECHACONC o GETDATE() según variable.
   - recuperar > 0: vencimiento origen a 0; FCXCDV tipo C con IDFCONCI (suma si ya existía; reemplaza si lo conciliado era C).
   - `SPK_RELIQUIDA_FTR`; línea Cerrada. Si hay recuperar y FTR no castigada → `SPK_CONTAB_CONCI` (MCPE CONCI). Cabecera Cerrada si todas las líneas cerraron; si no, KO «La Conciliación No se ha aplicado correctamente…».
5. **Anular** — `ANULAR_CONCILIACION` (todas) / `ANULAR_ITEM` (una, solo Cerrada y sin CNSNOTADB previo): `@FNOTD` (sede + D) → `SPK_RETIRA_FACTURA_CONCI` (FNOT D CONCILIA, borra tipo C, reliquida, `SPK_NC_CONTAB_ANULA_CONCI`). Estado Anulada. Imp.ND / Imp.NC por línea.
6. **Contabilizar** — Otros módulos → Conciliaciones: `SPQ_CONCILIACIONES` LISTA/DETALLE; envío `SPQ_CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS` → CONTABILIZADA 1 + NROCOMPROBANTE; habilita Imp.Comp.

## Tipos de vencimiento FCXCDV

F factura · G glosa · R ratificación · C conciliación (saldo por recuperar de una conciliación previa) · L (tratado como glosa; significado pendiente de confirmar).
G/C/R/L exigen CNSGLO y glosa aplicada + radicada (manual, Excel y confirmar).

## Configuración

- `IDCOPNOTACONCI` (CPNT) — concepto por defecto de NC/ND; sin él no cierra («NO EXISTE CONFIGURACION PARA GENERAR LA NOTA CREDITO»).
- `FNOT_FECHACONCILIA` — CONCILIACION = fecha de conciliación (PRI abierto) / otro = hoy.
- `CONCIGLOSA_TIPOSPERM` — lista de tipos permitidos (ej. G,R,C,L); vacía = sin filtro.
- `CONCIGLOSA_NREXTERNO` — alfanumerico permite letras en Nro. Externo.
- Consecutivos `@CONCI`, `@FNOTC`, `@FNOTD`; tipo de comprobante de conciliación y cuenta de glosas (TTEC); catálogos CPNT y FCGLO.
- Acceso por menú `admin.conci`; no hay controles USGRUH por botón.

## Capas

1. Configuración — concepto NC, glosa/tipos permitidos.
2. Proceso propio — CRUD cabecera y detalle, Excel, split aceptado/recuperar, confirmar, anular, imprimir.
3. Lo que llega y completa — FCXCDV/FTR/FGLO (glosa radicada).
4. Subproceso unido — notas CONCILIA al confirmar/anular.
5. Envío a contabilidad — OM Conciliaciones.

## Libro

`proceso.json` → `capitulosLibro` (13): guía rápida, qué es, ciclo, cabecera, tipos de vencimiento, detalle, carga masiva, confirmar, anular, imprimir, contabilidad, estados (`estadosConci`), configuración.
Mapas: `libro/img/conci_*_sketchnote.jpg` (10), generador `libro/scripts/gen_conci_sketchnotes.py`.

## Pendientes

Ver `conocimiento/pendientes.json` (procesoId `conciliaciones`): tipo L, Porcentaje sin recálculo, ficha FCXCDV.
