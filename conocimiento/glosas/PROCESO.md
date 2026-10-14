# Proceso: Cartera · Glosas

**Estado:** parcial (operación completa; anidados contables en listado)  
**Módulo:** FGLO_COL → `SPQ_FGLO_COL` (38 METODOs, PREVERSION = liberada 2.0.7 al 2026-10-03) + `SPK_RESPUESTAGLOSA` + `SPK_FINALIDAD_GLOSAS`  
**Ventanas:** Auditoría → Glosas (`/auditoria/Glosas`, `AdiGlosasPage.vue`) · Administrativo → Adm. glosas (`/admin/AdmGlosas`, `AdminGlosasPage.vue`) · origen en Recaudos (ingreso GLOSAS)  
**Alcance:** ciclo administrativo de la glosa de cartera (CxC). Conciliaciones (FCONCI) y glosas de CxP son otros procesos.

> Solo flujo y explicación. El cuerpo del SP se baja a `sql/` cuando se analiza; no se archiva aquí.
> Este `.md` no se vuelca al libro (`incluirProcesoMdEnLibro: false`): el libro usa `capitulosLibro` de `proceso.json`.

## Qué es

La EPS objeta parte de una factura radicada y retiene ese valor. Cartera lo registra en un **recaudo con ingreso GLOSAS** (una glosa FGLO por factura, con hasta dos motivos del catálogo FCGLO), lo **envía** a auditoría en una entrega (ENT/ENTD); auditoría **recepciona**, **responde** (Total con motivos FGLOCG o por Ítems FGLOD), **aplica** (NC automática por lo aceptado, FCXCDV por lo defendido, asiento contable, CERRADA=1), arma el **lote de impresión** (FGLOI/FGLOID) y lo **devuelve**; cartera **recepciona** y **radica** (FGLOI_RADICA → SPK_RADICAGLOSAS). Con paso a seguir 4/5/6 en el recaudo, `SPK_FINALIDAD_GLOSAS` automatiza del envío a la devolución.

## Capas

1. **Configuración** — FCGLO (clases GLOSA/DEVOLUCION/RESPUESTA, activo), FDEP + variables `IDFDEPCARTERA`/`IDFDEPAUDITORIA`, `IDCONCEPRPTAGLO_AUTO`, `GLO_DIAS_HASTASABADO`, `RESTGLO_AUTOR_UNICO`, PRI abiertos.
2. **Proceso propio (auditoría)** — RECIBIR_GLOSA; TRAE_MOTIGLO; CRUD_FGLO / CRUD_FGLOCG / CRUD_FGLOD / BORRAR_TODO_ITEMS; APLICAR_GLOSA / APLIANULA_FACTURA / DESAPLICAR_GLOSA; CARGA_MASIVA_RESPUESTA_GLOSA; PLANTILLA/SUBIR_RPTA_DETALLES; ASIGNAR_RESPONSABLE_GLOSA; LIBERAR_PAC; lotes CRUD_FGLOI / CRUD_FGLOID / IMP_RESPUESTA / ABRIR/CERRAR_IMPRESION; devolución ENT_RPTAGLOSA / ENT_ADDRESPGLO / ENT_CIERRARPTAGLOSA / ENVIAR_RESPUESTA.
3. **Lo que llega** — Recaudos: PROCESAR_FACTURA / SUBIR_TXT / ASIGNAR / APLICARPAGO → SPK_PAGOSCXC (FGLO + FGLOCG si motivo válido). Facturas en CxC con saldo.
4. **Subproceso unido** — Entregas cartera ↔ auditoría: ENVIAR_AUDIT (Recaudos), ENT_ENVGLOSA / ENT_ADDRECAUDO / ENTD_DELITEMENVIO (Adm. glosas), RECIBIR_RPTASGLOSA, FGLOI_RADICA. Circuito automático SPK_FINALIDAD_GLOSAS (FINDEVOL 4/5/6).
5. **Contabilidad** — SPK_RESPUESTAGLOSA → SPK_CONTAB_FGLO al aplicar; FGLO.CONTABILIZADA 0/1/2; Contabilidad → Otros módulos → Glosas (SPQ_CONTABILIDAD_3).

## Reglas clave

- Motivo inexistente/inactivo en la plantilla del recaudo → glosa sin FGLOCG (no aborta). El auditor agrega motivos a mano.
- Aplicar exige glosa abierta, SUM(motivos) = VLRGLOSA (y SUM(ítems) si tipo I), PRI cartera y contable abiertos en FECHARESP, VLRACEPTADO ≤ VLRGLOSA.
- Aplicar y Anula Factura: VLRGLOSA = valor factura → SPK_GLOSAANULAFTR.
- Desaplicar: CERRADA=1 y ASIGNADAIMP=0; reversa NC (SPK_ANULANOTA_CR); bloqueado con factura anulada o comprobante no confirmado.
- Lotes: uno abierto por tercero+usuario; asignar/retirar solo con IMPRESIONES=0; Cerrar/Abrir con `MENUQ_GLOSAS · ABRIR_CERRAR_RESPUESTA`; Enviar a Cartera con impreso, sin radicar y no en cartera.
- Radicar: fecha no futura y ≤ 30 días atrás; no se desradica.
- Plazo: 15 días hábiles desde FECHAPAGO+1 (dom/FES excluidos; sábado según `GLO_DIAS_HASTASABADO`); columna Días verde 6–15 / ámbar 1–5 / rojo ≤ 0; cálculo en la consulta del FE.
- Asignar responsable: `MENUQ_GLOSAS · BASIGNARRESPONSABLE`; glosa ENAUDITORIA=1 y CERRADA=0; usuario activo; FASIGNA/FLIMITE; log USLOG.
- Carga masiva reemplaza FGLOCG/FGLOD; Rpta Det. es todo-o-nada (RESPUESTA ≥ 10 caracteres). Ninguna aplica.

## Pendientes

- Defecto FE Adm. glosas: columna/filtro Estado no cubre glosas devueltas a cartera (CERRADA=1, IDDEP cartera); SinRadicar/Radicada inalcanzables.
- Catálogo de permisos sin `BASIGNARRESPONSABLE`; manual Help cita permisos GLOSAS_* genéricos.
- SPK_CONTAB_FGLO, SPK_GLOSAANULAFTR, SPK_RADICAGLOSAS sin ficha.

## Libro

13 capítulos temáticos con 11 sketchnotes (`libro/img/glosas_*_sketchnote.jpg`, generador `libro/scripts/gen_glosas_sketchnotes.py`): guía rápida, qué es, ciclo, origen, entrega, responder, Excel, aplicar, plazo y responsables, lotes, radicar, estados, configuración.
