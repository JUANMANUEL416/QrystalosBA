# Proceso: Facturación · JSON Perú / SUNAT

**Estado:** parcial (envío MiFact + Liberar/consulta + Interfax leídos 2026-09-12)  
**Módulo:** JSON_PERU · Administrativo → Facturación Perú  
**Hermanos:** `facturacion`, `dian-xml` (Colombia), `rips-json` (no aplica en Perú).

> Pregunte en Documentar o Consultas este módulo. Chat: **JSON Perú / SUNAT**.

## Qué es / qué no es

| Esto | No es |
|------|--------|
| JSON a MiFact / SUNAT (`FACTEP`) | XML DIAN / `FACTE` / CUFE |
| Boleta 03 vs factura 01 | JSON RIPS / CUV |
| Notas 07/08 (`FNOT_ENVIARSUNAT`) | Calificación PHD (solo precios) |

## Árbol

```
FE Facturación Perú (/admin/facturacionPe)
  └─ FTR_COL · ENVIA_CONTAB   (en Perú ejecuta UNO de los dos y luego contabiliza)
       ├─ TIPOFIN=C y FACTEP≠102 → SPK_GENERA_JSON_PERU_FTR_INTEGRA   (variante, no gemela)
       ├─ resto → SPK_GENERA_JSON_PERU_FACTURA
       └─ SPK_NC_CONTAB_FTR   (en Perú se re-ejecuta en cada pulsación)

  Detalle de SPK_GENERA_JSON_PERU_FACTURA:
            ├─ ya hay FTRE de esa N_FACTURA → RETURN
            ├─ FDIAN PREFIJO (BOLE si TIPOFIN=N, si no FTR)
            ├─ tipo doc: N → 03 boleta; resto → 01 factura
            ├─ afecto+inafecto ≤ 0 → RETURN
            ├─ TOKEN < 20 o URL < 30 → RETURN
            └─ POST MiFact (URLFACT_ELE_*JSON)
                 ├─ OK → FTR.FACTEP=ESTDOC, LINKFACTURA, INSERT FTRE + FTRAPILOG
                 ├─ 101/102/103 → actualiza FTRE.SOLICITUDJSON y RETURN
                 └─ vacío / error estructura → FACTEP=104A

FE Notas DB/CR
  └─ FNOT_COL · FNOT_ENVIARSUNAT     (IXCOUNTRY=PERU, FACTEP≠OK)
       └─ SPK_GENERA_JSON_PERU_NOTADBCR
            ├─ FNOT.FACTEP=OK → RETURN
            ├─ ENVIA_NOTAS_ACEPTA≠SI → no arma (el IF envuelve el cuerpo)
            ├─ CLASE C → 07 NC; D → 08 ND
            └─ prefijo NCB/NCF o NDB/NDF
```

```
FE Liberar SUNAT
  └─ FTR_PERU · LIBERAR_SUNAT          (P, no NC, FACTEP ≠ 101/102)
       └─ SPK_CONSULTA_DOCUMENTO_ELECTRONICA   (solo MIFACT)
            ├─ URL: SendInvoice → GetEstatusInvoice
            ├─ 101/102/103 → FACTEP=ESTDOC; INSERT FTRE si faltaba
            └─ otro → FACTEP=ERROR
       └─ luego FACTEP=NULL solo si tras la consulta no quedó 101/102
            (no borra FTRE)

FE / INTER_SAP
  └─ FTR_PERU · ENVIAR_FACTURA_SAP
       └─ SPK_JSON_FTR_PERU_INTERFAX   (EPrefactura → CIPERU)
            ├─ garante sin remesa → RETURN
            ├─ valor 0 → FACTEP=104A
            ├─ paciente/boleta → PreFacturaPacienteEM
            ├─ garante → PreFacturaGaranteEM
            ├─ codigo 0 → FACTEP=102
            └─ otro → FACTEP=104

Cartera (notas Interfax)
  └─ SPK_JSON_FTR_PERU_INTERFAX_FNOT   (EPreabono; FCXC / NOTASCXC)
```

`QUITAR_ERROR_API` solo limpia `104A`.

## FACTEP (pantalla Est.Sunat)

Mapeo FE (`FTRPeComponent`): vacío=Sin notificar · 103=Error valida · 104=Rechazado · 104A=Rechazado-api · 105=Anulada · 108=Baja · resto=OK.

## Defaults vistos en FACTURA

- Moneda **PEN**; operación SUNAT **0101**
- Código postal emisor/receptor **150101**
- DNI afiliado a **8** dígitos (pad/right)
- IGV código **1000** / VAT
- Guías en el script: valores fijos `T001-00000001` / `09` (no vienen de una tabla de guías)
- Líneas `FTRD.PAQUETE=2` no suman
- Fuera de `BDATA_PRODUCCION`: RUC emisor de prueba `20100100100`

## Hueco

Circuito JSON MiFact + Liberar/consulta + Interfax factura/nota: fichado. PHD/HPREP no es el JSON SUNAT. El POST HTTP de Interfax (`SPK_ENVIA_TRAMAS_CIPERU`) no se fichó: es transporte, no el armado.
