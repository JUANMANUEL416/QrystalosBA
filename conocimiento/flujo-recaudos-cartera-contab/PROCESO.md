# Recaudos de cartera → CxC → contabilidad

Flujo transversal para **Auditoría de procesos** (BA). Parámetro de traza: **`CNSFPAG`**.

Proceso hermano documentado: `conocimiento/recaudos/` (libro FPAG_COL). Este flujo ordena los **controles de auditoría** y la **traza SQL** en el mismo orden operativo.

## Camino común (todos los INGRESO)

1. Variables USVGS (`REC_VLRMAX_AJUSTE`, `REC_SOLICITA_AVAL`, observaciones devolución/glosas).
2. Periodo contable de **FECHAPAGO** (PRI).
3. Cabecera **FPAG** (tercero, valor, CERRADO, ESTADO, FINDEVOL si aplica).
4. **Origen del dinero** (solo CAJA/BANCOS) o datos documento (GLOSAS/CXP/DEVOLUCION/LEVANTAMIENTO).
5. Detalle **FPAGD** (+ **FPAGDI** impuestos).
6. Cruce **FPAGDCXP** (solo CXP).
7. **Aplicar** → `SPK_PAGOSCXC` → `CERRADO=1`.
8. **Contabilidad** FPAG (`CONTABILIZADO`, `NROCOMPROBANTE`, procedencia **CXC**).
9. Comprobante **MCP** o **MCPE**.
10. Subproceso unido (FGLO, FCXCR, ENT, aval).

## INGRESO — resumen de variantes

| INGRESO | Origen / enlace | Paso a seguir (FINDEVOL) | Al aplicar | Contabilidad |
|--------|------------------|---------------------------|------------|--------------|
| **CAJA** | FCJ `RECAUDO=1`, cerrado | — | Pago CxC | CXC + recibo caja (CAJA) |
| **BANCOS** | BMOVD `RECAUDO=1` | — | Pago CxC | CXC + mov. banco (BMOV) |
| **CXP** | FPAGDCXP ↔ FCXP | — | Pago + cruce CxP | CXC |
| **GLOSAS** | Facturas CxC | 3 Recepcionar; 4 Rec+Resp; 5 Detalle; 6 Det+Resp | Crea/ mueve FGLO | CXC + RGLO según caso |
| **DEVOLUCION** | Facturas tipo F | 0 retira; 1 anula; 2 radica | FCXCR + finalidad | CXC / sin contab según caso |
| **LEVANTAMIENTO** | Facturas con saldo | — | Marca LEVANTADO | CXC |

## Herramienta BA

Menú **Auditoría de procesos** → flujo **Recaudos cartera** → servidor + BD + `CNSFPAG`.

Runbook: `RUNBOOK-SOPORTE-RECAUDOS.md`.
