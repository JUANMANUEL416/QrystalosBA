# Runbook soporte — Recaudos (CNSFPAG)

Traza read-only en **Auditoría de procesos**. Orden de lectura: pasos KO primero, luego AVISO.

## PC-RC-01 — REC_VLRMAX_AJUSTE

**Síntoma:** No deja crear CAJA/BANCOS/CXP o KO en aplicar por ajuste al peso.

**Acción:** Configuración → Variables (`REC_VLRMAX_AJUSTE` numérica). Revisar `FPAG.VLRAJUSTEPESO` vs límite.

## PC-RC-02 — Periodo cerrado

**Síntoma:** APLICARPAGO KO «periodo contable».

**Acción:** Abrir PRI del mes de `FPAG.FECHAPAGO` o corregir fecha de pago si el recaudo aún está abierto.

## PC-RC-04 / PC-RC-05 — Origen caja o banco

**Síntoma:** Recaudo sin FCJ/BMOVD o flags incoherentes (`ENPAGOS`, `RECAUDO`, recibo no cerrado).

**Acción CAJA:** `/admin/caja` — recibo ingreso externo con casilla **Recaudo**, tercero, **Confirmar** cierre. Luego Recaudos → nuevo CAJA y elegir recibo.

**Acción BANCOS:** Tesorería — movimiento con `RECAUDO=1`, OFIN confirmado, saldo por legalizar. Recaudos → BANCOS.

## PC-RC-06 — Doble FPAG mismo recibo

**Síntoma:** Otro `CNSFPAG` usa mismo `CODCAJA`+`CNSFACJ` o misma llave BMOVD.

**Acción:** Identificar FPAG duplicado; desaplicar/anular el incorrecto (si periodo lo permite) o escalar contabilidad si ya hay comprobante.

## PC-RC-07 / PC-RC-08 — Detalle

**Síntoma:** Sin FPAGD, totales no cuadran, factura duplicada.

**Acción:** Recaudos → Asignar facturas / Excel → **Asignar** antes de Aplicar. Revisar `VLRITEMS` vs suma `FPAGD.VALORPAGO`.

## PC-RC-09 — Impuestos

**Síntoma:** KO FIMPDV en aplicar.

**Acción:** Catálogo impuestos vigentes; completar FPAGDI en detalle del recaudo.

## PC-RC-10 — Cruce CxP

**Síntoma:** INGRESO=CXP y suma cruce ≠ ítems.

**Acción:** Pestaña FPAGDCXP; ajustar `VALORPAGO` por factura CxP hasta cuadrar con ítems CxC.

## PC-RC-12 / PC-RC-13 — Sin comprobante o en errados

**Síntoma:** `CERRADO=1` pero `CONTABILIZADO=0` o comprobante en MCPE.

**Acción:** Contable → Comprobantes errados → procedencia **CXC**, referencia `CNSFPAG` → corregir KMCOM/tercero/cuenta → **Reconstruir**. Si `NOCONTABILIZA=1`, es esperado sin asiento.

## PC-RC-14 — Caja origen sin contabilizar

**Síntoma:** Recaudo contabilizado pero FCJ `CONTABILIZADA=0`.

**Acción:** Procesos de caja o contabilizar recibo CAJA; luego revisar CXC si MCPE muestra descuadre tesorería.

## PC-RC-15 — Glosas

| FINDEVOL | Qué revisar |
|----------|-------------|
| 3 | FGLO creada; botón **Enviar a auditoría** (ENT); no deshacer fácil |
| 4 / 6 | SPK_FINALIDAD_GLOSAS post-apply; NC y devolución a cartera |
| 5 | FGLO en auditoría; respuesta manual ítems |

## PC-RC-16 — Devolución

**Acción:** `/admin/fcxcr` Respuesta devoluciones según FINDEVOL 0–2; no intentar desaplicar como pago normal si FINDEVOL≠0.

## PC-RC-17 / PC-RC-18 — Periodo cerrado / aval

**Acción:** Si `REC_SOLICITA_AVAL=SI`: Solicitar aval → Contable → Aval recaudos → Desaplicar con aval (PREVERSION). Si no hay aval, no reabrir periodo: reversión vía `SPK_REVERSAR_RECUADO`.
