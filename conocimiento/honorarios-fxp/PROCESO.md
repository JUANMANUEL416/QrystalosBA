# Proceso: Honorarios médicos (FXP)

**Estado:** documentado (2026-10-04)  
**Módulo:** FXP_COL · hermano de cxp-fcxp

FXP = «cuenta por pagar presupuestada»: lo que la institución debe a un proveedor/profesional externo por servicios facturados. No es FCXP; se convierte en FCXPD (procedencia Salud) al pasar a CxP.

## Cadena completa (verificada)

1. **Configuración.** Terceros → tercero contratante con categoría PRO → botón «Contratación Como Sub-Contratista» (TERCEROS_WEB · CONTR_SUBCONTR) → PXSNComponent: PXSN (administradora CON + plan PPT + tarifa + factor) → PXS (prefijos por sede; TIPOTARIFA Normal/Tarifa; EXCOBROPC/LIQUIDARPC/COBRARPC) → PXSE (Restringir / Tarifa+factor / Valor). Precio = VW_CXPPROTOT = VW_CXPPROPRE ∪ VW_CXPPROSER ∪ VW_CXPPROSER1. Servicio con SER.MPROVEEDOR («Maneja Proveedor»); PRE.REQ_PROVEED / IDPROVEEDORDEF y botón Proveedores (PXS · GUARDAR_PRE con PRIORIDAD/UMBRAL).
2. **Captura.** HPREComponent: si `esHpredRequiereProveedor` (MPROVEEDOR) muestra Id.Proveedor (VW_PXS filtrada por IDTERCEROCA y PREFIJO) y lo exige. AutorizadorComponent: AUT.IDPROVEEDOR (obligatorio si AUT_OBLI_IDPROVEEDOR = SI; deshabilitado si FACTURADA/Anulada/Ver). Citas: CIT.IDMEDICO.
3. **Generación.** SPK_FACTURA_ADMISION/ASIS/SOAT/UCI/DOMI → SPK_CREACXP_ASIS (@NVOCONSECFTR; excluye IDTERCEROINSTALADO; CXP = 0; vigencias FD y convenio; HPRED.CXP = 1, HADM.CXP = 1; bloque HOMED 'HADM'). SPK_FACTURACE_N/PERU → SPK_CREACXP_CE (AUT.IDPROVEEDOR, CXPGEN; HONORATAR_DIF; AUTD.VALORPROV; HOMED 'AUT') y SPK_CREACXP_CI (IDMEDICO). SPK_CREACXP_QX y SPK_CREACXP_ASIS_UNO: sin invocador.
4. **Gestión.** admin.FXP → HonorariosMedPage → FXPComponent/FXPDComponent. AppStore.read FXP+TER (estado P→IN('P','S')). FXP_COL · ESTADO_FXP → FNK_ESTADO_FXP (FTRD/FTR/MCP). CAMBIAR_TERFXP → SPK_CAMBIAR_TERFXP (@FCXP; HPRED/FTRD.IDPROVEEDOR; SPK_CONTAB_FTR si CONTABILIZADA). IMPRIMIR_CXP / IMPRIMIR_CUENTA_COBRO → useFxPReport (PDF «CUENTAS POR PAGAR PRESUPUESTADA» / «DEBE A»). Anular: stub FE. Sin getPermiso en FXPComponent.
5. **Paso a CxP.** FXPD 'S' → SPK_INSERT_CXP_SALUD(@CNSFCXP) → FCXPD (N_PRESUP, ITEM_PRESUP, CUENTA_SER = FNK_CUENTA_KMCOM 'CXP_SALUD', PROCEDENCIA 'Salud') → FXPD/FXP 'E'. SPK_INSERT_CXP_SALUD_TOTAL recorre FXP 'S'. Reversa: SPK_ANULAR_ITEM_CXP / SPK_ANULAR_CXP → 'P'. **Sin invocador en PREVERSION ni en Qrystalos2.** CXPComponent: Nueva CXP procedencia Salud usa FCTSER (sin vínculo); «Consulta Cuentas Esperadas en Salud» = AppStore.read FXP + CONF_CXP · EXPORTAR_CXP_ESPERADAS.
6. **Alrededor.** SPK_ANULA_FACT («ARREGLO DE HONORARIOS»: TIPOFAC 'I' por admisión; CE/CI por FTRD de la factura), SPK_ANULA_FACT_CAPITADA, SPK_LIBERAR_FACT: DELETE FXP/FXPD sin filtrar ESTADO. SPK_NOTASCXC rebaja FXPD.VALOR sin filtrar ESTADO.

## Notas internas

- SQL en `sql/` (PREVERSION idéntica a 2.0.7; IDANT 2.0.6): SPQ_FXP_COL, FNK_ESTADO_FXP, SPK_CAMBIAR_TERFXP, SPK_CREACXP_ASIS, SPK_CREACXP_ASIS_UNO, SPK_CREACXP_CE, SPK_CREACXP_CI, SPK_CREACXP_QX, SPK_INSERT_CXP_SALUD, SPK_INSERT_CXP_SALUD_TOTAL, SPK_ANULAR_ITEM_CXP, SPQ_CONF_CXP, SPQ_PXSN, SPQ_PXS, SPQ_PXSE, VW_CXPPROTOT, VW_CXPPROPRE, VW_CXPPROSER, VW_CXPPROSER1, VW_PXS.
- Metadatos de columnas (solo estructura, base de pruebas): FXP 14 col (incl. INDGENCTA), FXPD 17, PXS 13, PXSE 10, PXSN 9, HOMED 7 (CNSHOMED, PROCEDENCIA, NOPRESTACION, ITEM, RECURSOH, IDTERCERO, PORCEN). Ninguna con ficha en qrystalos.documentacion.
- Variables usadas por los SP: IDTERCEROINSTALADO, HONORATAR_DIF, TERCATPROVEEDOR, IDMODELOCONTABLE; por el FE: AUT_OBLI_IDPROVEEDOR. Consecutivo SPK_GENCONSECUTIVO '@FCXP'.
- Sketchnotes: `libro/scripts/gen_honorarios_sketchnotes.py` → `libro/img/fxp_config|generacion|gestion_sketchnote.jpg`.
- 13 hallazgos en `proceso.json`; 12 abiertos en `pendientes.json` (prefijo `fxp-`). Pendiente de dictamen si el coordinador lo pide.

## Dictamen (2026-10-04)

`dictamenes/20261004-fxp-cierre-ciclo-cxp.html` — cierre del ciclo (SELECCIONAR_ITEMS / PASAR_A_CXP sobre SPK_INSERT_CXP_SALUD), ANULAR_FXP, guardas de estado en SPK_ANULA_FACT / LIBERAR_FACT / NOTASCXC / CAMBIAR_TERFXP, permisos por botón. Cubre hallazgos 1-6, 10 y 11; los de cálculo (HONORATAR_DIF, PROSER1), HOMED, generadores huérfanos y fichas de tablas quedan para otra fase.

