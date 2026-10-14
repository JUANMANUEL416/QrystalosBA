# Cuentas por pagar (FCXP) — del menú Administrativo al pago en caja

Documento interno del agente (no se incluye en el libro: `incluirProcesoMdEnLibro: false`). El libro vive en `proceso.json` → `capitulosLibro`.

## Ciclo

1. **Registrar** — Administrativo → Cuentas por Pagar → Nueva CXP (`SPQ_FCXP · CRUD_FCXP`), detalle (`CRUD_FCXPD` → `RECALCULAR_FCXP`), impuestos (`CRUD_FCXPI`). Compras llegan por `SPK_INSERT_CXP_INV`; Radian por `REGISTRAR_CXP_FRADIAN` / CRUD asistido; anticipos por `SPK_GEN_PROCESO_ANTICIPO`; caja menor por `SPK_SOL_REEMBOLSO_CAJAMENOR`.
2. **Contabilizar** — columna Conta → `VALIDAR_FCXP` → `CONTABILIZAR_FCXP` → `SPK_CALCULOVALORESCXP` + `SPK_NC_CONTAB_CXP`. Deshacer: mismo método (toggle) con bloqueos.
3. **Orden de pago** — `SPQ_ORDEN_PAGO · CRUD_FCXPPM` → `LISTAR_CXP_PENDIENTES` → `PAGO_TOTAL` / `PAGO_PARCIAL` (FCXPP N). Atajo desde la factura: `PAGO_CXPTOTAL` (clásico inmediato) o `PAGO_PARCIAL` + `AUTORIZAR_INDIVIDUAL_TER`.
4. **Autorizar** — FE elige por variables (`OPComponent.onAutorizarPagos`):
   - ninguna → `AUTORIZAR` → `SPK_CONFIRMAR_PAGOSMASIVO` (FCJ PROCEDENCIA CAJA, pendiente, FCJD.IDSERVICIO = CNSFCXPP; FCXPP C; FCXP.SALDO −; FCXPPM C);
   - `AUT_EGRE_INDIVIDUAL=SI` → `AUTORIZAR_INDIVIDUAL_TER` (FCJ PROCEDENCIA CXP pendiente, PCJ desde la orden, FCJD sin IDSERVICIO; FCXPPM C o, con `PERMITE_EGR_SIN_C=SI`, N + OP_TER_IND/CERRADA vía Cerrar Orden);
   - `BANC_DINA_ARCH_PLANO=SI` → `AUTORIZAR_INDIVIDUAL` (FCJ CXP cerrados + llamada al SPK clásico; FCXPP P; FCXPPM P).
5. **Caja** — Administrativo → Caja → Mov. Egreso → Forma de Pago (`VALIDA_INSERT_FPA_EGRESO` / `CRUDFPA_EGRESO`) → Confirmar (`SPQ_CONF_CAJA · CONFIRMAR_RECIBO_EGRESO`): `SPK_CIERRERECIBO_CAJA` (FCXPP P por IDSERVICIO, `SPK_CALCULOVALORESCXP`, FCXPPM P, caja menor) → `SPK_NC_CONTAB_CAJA_EGR` (DB CUECREDITO por abono / CR forma de pago) → CERRADA 1 → si PROCEDENCIA CXP `SPK_MARCA_OP_PAGADA_POR_EGRESO`.
   - Atajos: Caja → Confirmar orden de pago (`CONSULTAR_ORDEN_CAJA` → `CONFIRMAR_EGRESOS_MASIVO_OP DESDE_CAJA=1`); Orden → Realizar Pago (`OPPagoEgresosDialog`: `CONFIRMAR_RECIBO_EGRESO` + `MARCAR_PAGADA_POR_EGRESO` por egreso).
   - Reversa: Anular recibo → `OBTENER_ORDENES_POR_RECIBO` / `DESAUTORIZAR_POR_RECIBO`.

## Estados

- FCXP.ESTADO: N sin abonos · C con abonos y saldo · P saldo 0 con abonos · A anulada · (M aceptado por LISTAR, origen no hallado). CONTABILIZADA 0/1/2 (2 = DIAN).
- FCXPPM.ESTADO: N · C · P · A. CERRADA, OP_TER_IND.
- FCXPP.ESTADO: N · C · P · A.
- FCJ: ESTADO P/A/D + CERRADA 0/1; PROCEDENCIA CAJA (clásico) / CXP (individual); CLASE_FAC PAGO; TIPOEGRESO = IDCJTECXP o CAJ.TIPOEGRESO.

## Fuentes (trabajo interno)

- Qrystalos2: `pages/administrativo/CuentasxpagarPage.vue`, `OrdenPagoPage.vue`, `CajaPage.vue`; `components/administrativo/CXP/CXPComponent.vue`, `OPComponent.vue`, `OPPagoEgresosDialog.vue`, `help/HelpManual*`; `components/administrativo/Caja/CAJMovinComponent.vue`; `router/routes.js`.
- Documentación: `tablas/FCXP.md`, `FCXPD.md`, `FCXPP.md`, `FCXPPM.md` (no listan valores de estado).
- DESAIX SQLIX PREVERSION vs 2.0.7 (IDANT 2.0.6), 2026-10-04: todo idéntico salvo SPQ_FCXP (CRUD_FCXP MASIVA_CXP; CRUD_FCXPD y CLONAR_FCXP UNSPSC). Scripts en `sql/` (Documentar).

## Hallazgos (detalle en `proceso.json → hallazgos`)

Doble egreso en `AUTORIZAR_INDIVIDUAL`; egreso individual sin IDSERVICIO (asiento contra CPCJ.CUENTA); permisos de pestaña no evaluados; eliminar-todos del detalle; Informes depende de la pestaña CxP; VINCULAR_CXP_FRADIAN inexistente; RECONSTRUIR sin CUENTAGRAV; ESTADO M sin origen; Pagar desde la factura ignora el modo de autorización.

Solución propuesta de todos (y del archivo plano) en `dictamenes/20261004-cxp-hallazgos-archivo-plano.html`.

## Archivo plano para el banco (2026-10-04)

- Camino operativo: `OPComponent` → botón **Archivo Plano** (`dataGuarda.CERRADA && ESTADO == 'N'`) → `onGenerarArchivoPlano` → diálogo `dgPlanoBanco` (BCT con `TIPO_PLANO` = formato y `ESTADO='Activa'`, tipo movimiento, oficina, clave) → `SPQ_ORDEN_PAGO · GET_INF_PLANO` (rs1 TER instalado × BCT; rs2 por FCXPP con TER.TIPO_CUE / CUE_BANCARIA y BCO.CODACH por TER.BANCO) → `generarArchivoBancoBogota` / `generarArchivoBancoColpatria` → descarga .txt.
- Roto: opción Bancolombia (firma `generarArchivoBancolombia(empresa, filas, tipo)`); Colpatria ignora `paramPlanoBanco` (clave `PGCORPUCOO`, oficina `2`, tipo `02`, totales `00002`); Bogotá `tipoIdentificacionXBanco` compara `'BOGOTA '`; `GUARDAR_ARCHIVO_PLANO_BANCOLOMBIA` es esqueleto y se llama con MODELO `FCXP`; ventana nómina sin botón (comentado 85-86) y `exportarNominaPlanoDinamico` inexistente; `EXPORTAR_NOMINA_PLANO*` usa `FCXP.CUECREDITO` como cuenta bancaria y `BCO.IDTERCERO = FCXP.IDTERCERO`.
- Base de pruebas (solo metadatos): `BCO` = BANCO, DESCRIPCION, CODACH, IDTERCERO; `FCXP.FECHA_GENERACION_PLANO` existe (solo soporte nómina Excel); no hay tabla de historial de planos; `BCT.TIPO_PLANO` sin configurar allí (no es dato de manual).

## Alrededor del ciclo (2026-10-04, tarde)

Capítulos nuevos del libro: lujo-notas, 
otas-detalle, lujo-anticipos, lujo-radian, lujo-auditoria, informes-cierre, estados-alrededor (reemplazan el capítulo lrededor). Sketchnotes libro/img/cxp_{notas,anticipos,radian,auditoria}_sketchnote.jpg.

- **Notas DB/CR**: catálogo FNT (SPQ_FNT_COL · CRUDFNT); diálogo de CXPComponent → SPQ_FCXP proxy → SPQ_FCXPDBCR (CRUD_FCXPDBCR_2 / _MANUAL, AFECTA_RETENCION, VALIDA_IDNOTA, CRUD_NOTA_EDITA, CONTABILIZAR_NOTACREDITO, ENVIARDIAN_NOTACREDITO, DESAPLICAR_NOTACREDITO, ELIMINR_NOTACREDITO, CONSULTAR_RESPUESTA_DIAN_NOTA). Contabilizar: GENCXP=1 → SPK_CIERRA_FCXPDBCR (+ SPK_NC_CONTAB_CXPFNT solo con CONT_FCXPDBCR_Y_FCXP=SI); GENCXP=0 → SPQ_NC_CONTAB_CXPFNT. Saldo solo ve notas CONTABILIZADA<>0 y ESTADO in (P,N) (SPK_CALCULOVALORESCXP). Reversa SPK_ANULAR_FCXPDBCR.
- **Anticipos**: TANT (SPQ_TANT_COL); FCOM C → CERRAR_FCOM 'P' → ENVIAR_CAJA (SPK_GEN_PROCESO_ANTICIPO: FCXP AN###### Anticipos, FCXPPM/FCXPP en CODCAJANTICIPOS, SPK_CONFIRMAR_PAGOSMASIVO) → egreso en caja. Factura real: TRAER_VALORES_ANTI → APLICAR_ANTICIPO → SPK_ANTICIPO_LEG_CXP (+ SPK_NC_CONTAB_ANTICIPO si GENANTIDESDEORDENSER=SI) → SPK_CALCULOVALORESCXP. ANULAR_ANTICIPO solo ANT L.
- **Radian**: SPQ_FRADIAN completo (ARCHIVOS, ACTUALIZAR_DATOS, GETEVENTOS, GETENVIO, MATRIZ_EVENTOS, ADDEVENTO, DELEVENTO, REENCOLAR_EVENTO, LOG). Permiso MENUQ_CXP · BTN_NUEVO_EVENTO_RADIAN. Generar CxP solo gestionaCxp (pestaña dentro de CxP; FacturasRadianPage pasa false) y filtro evento 030: VALIDA_TERCERO → CxpFradianGenerarDialog → REGISTRAR_CXP_FRADIAN. Marcar → CONCILIAR_CXP_FRADIAN. **Sin SP en SQLIX** (PREVERSION ni 2.0.7): GUARDAR_HOMOLOGA_RADIAN, BUSCAR_HOMOLOGA_RADIAN, VINCULAR_CXP_FRADIAN, RELIQUIDAR_CXP.
- **Auditoría**: lista FCXP Servicios contabilizadas; Nueva Glosa = FCXPDBCR AUDT + FCXPS (SPQ_FCXP_AUDIT · CRUD_FCXPS); CERRAR_GLOSA (Nuevo→Glosa + CONTABILIZAR_NOTACREDITO); Levantar (nota CR, ITEMNCR); CERRAR_CONCI; CERRAR_SIN_GLOSA (AUDITADO=1 — hace el UPDATE aunque registre error).
- **Informes/cierre**: SPQ_CONF_CXP; SPQ_ORDEN_PAGO · CERRAR_CUENTA (valida MCPE de cartera y llama SPK_CIERRA_CARTERA 'CXP' → FCARTH CXP + PRI.CERRADO_CXP) / ABRIR_CUENTA (≤25 días; **borra FCARTH 'CARTERA'**). CRUD_FCXP y REGISTRAR_CXP_FRADIAN validan CERRADO_CXP=0.
- **Cruce CxC**: OPComponent solo lee FCXPCXC; ningún objeto de SQLIX la escribe (solo la leen SPK_CONFIRMAR/DESCONFIRMAR_PAGOSMASIVO, SPK_CONTAB_CAJA_EGR, SPK_NC_CONTAB_CAJA_EGR).

Hallazgos nuevos (sin dictamen aún): cxp-fe-metodos-sin-sp, cxp-abrir-periodo-borra-cartera, cxp-cerrar-periodo-valida-cartera, cxp-cerrar-sin-glosa-marca-con-error, cxp-cruce-cxc-sin-captura, cxp-anular-nota-literal-aud, cxp-nota-gencxp-marca-condicional, cxp-glosa-valor-suma-todas, cxp-aplicar-anticipo-error-fe, cxp-acumulado-circularizacion. Registrados en conocimiento/pendientes.json.

Scripts leídos hoy (todos PREVERSION idéntica a 2.0.7): SPQ_FCXPDBCR, SPQ_NC_CONTAB_CXPFNT, SPK_NC_CONTAB_CXPFNT, SPK_CIERRA_FCXPDBCR, SPK_ANULAR_FCXPDBCR, SPQ_FNT_COL, SPQ_TANT_COL, SPQ_ANTICIPOS_COL, SPK_GEN_PROCESO_ANTICIPO, SPK_ANTICIPO_LEG_CXP, SPK_NC_CONTAB_ANTICIPO, SPQ_FRADIAN, SPQ_FCXP_AUDIT, SPQ_CONF_CXP, SPQ_ORDEN_PAGO, SPK_CIERRA_CARTERA.