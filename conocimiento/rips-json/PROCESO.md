# Proceso: Facturación · RIPS JSON / FEVRIPS

**Estado:** completo (contrastado DESAIX PREVERSION = 2.0.10 el 2026-10-18)  
**Módulo:** RIPS_JSON · Administrativo → Facturación / FEVRIPS  
**Hermano:** `conocimiento/facturacion/` (armar FTR, DIAN, empaque, radicar). Aquí solo el JSON SISPRO.

> Pregunte en Documentar o Consultas eligiendo este módulo. No mezclar con caja ni nómina.

## Qué es / qué no es

| Esto | No es |
|------|--------|
| JSON RIPS + XML FEV + CUV ministerio | Encolar DIAN (`FACTE`, `NOTI_DIAN`) |
| Persistencia `FTRJSON` / `FNOTJSON` | Radicar cuenta (`FCXC`) |
| Validar / corregir defaults del JSON | Asiento contable |

## Árbol de generación

```
FE (useRipsJsonAsync / Validaciones / masivos)
  └─ FTR_COL
       ├─ INICIAR_RIPS_JSON_JOB → FNK_RIPS_JSON_USAR_ASYNC
       │     └─ 0: FE cae a RIPS_JSON síncrono
       │     └─ 1: SPQ_PROCESO_JOB → EJECUTAR_RIPS_JSON_ASYNC
       └─ RIPS_JSON / EJECUTAR_RIPS_JSON_ASYNC
            └─ SPK_GENERAR_RIPS_JSON   (exige FTR.FACTE=2)
                 ├─ SOLO_META=SI → meta, sin JSON
                 ├─ GENERAR=NO y FTRJSON.JSON_ENVIO lleno → reutiliza
                 ├─ FACTURA
                 │    ├─ CAPITADA=1 + PPT.PGP=1     → SPK_RIPS_JSON_FTR_PGP
                 │    ├─ CAPITADA=1 + TIPOCAP<4     → SPK_RIPS_JSON_FTR_CAPI
                 │    ├─ TIPOCAP=4 (capita o no)    → SPK_RIPS_JSON_FTR_CAPMASI
                 │    ├─ TIPOFAC=M + AUTPG          → SPK_RIPS_JSON_FTR_AUTPG
                 │    ├─ TIPOFAC=M + NEDXC/NEDXS/NCDXPS/NSDXPS → SPK_RIPS_JSON_FTR_CITPAQ  (confirmado 2.0.10)
                 │    ├─ TIPOFAC=M (resto)          → SPK_RIPS_JSON_FTR_MAS
                 │    └─ evento (no M, no capita)   → SPK_RIPS_JSON_FTR_IND
                 ├─ AJUSTE (CNSGLO o CNSFCT) + CUV obligatorio
                 │    ├─ capita + PGP               → SPK_RIPS_JSON_AJUSTE_PGP  → RETURN
                 │    ├─ capita no-PGP              → no genera → RETURN
                 │    └─ evento                     → SPK_RIPS_JSON_AJUSTE_IND → RETURN
                 ├─ NOTACR / NOTADB (FNOT.FACTE=2)  → SPK_RIPS_JSON_NDBCR_IND
                 └─ SPK_PERSISTIR_RIPSJSON_ENVIO → FTRJSON / FNOTJSON

NOTAAJUSTE_PGP y NOTAAJUSTE_MAS están después del RETURN de AJUSTE:
no corren por FTR_COL.
```

## Defaults ya vistos (IND + recién nacido)

Base para un REQ de defaults automáticos:

- **tipoUsuario:** `AFI.TIPOUSUARIO` (2 dígitos) o mapa `TIPOAFILIADO` (C/J=01, B=02, A=03, Sb=04, SR/SN=05, TA=06, S/RE=07) else **05**
- **usuario:** tipoDoc **CC**, fecha **1900-01-01**, sexo **M**, mpio **00000**, zona **02**, incapacidad **NO**, país **170**
- **conceptoRecaudo:** parte en **05**; si hay copago: 02 / 01 / 03 según tipo usuario
- **tipoDiagnostico:** presuntivo/impresión/definitivo = **01**
- **Particular:** sí se reporta
- **Recién nacido** (`FNK_RIPS_JSON_RECIENNACIDOS`): solo **1** `QXRCN`; tipo **CN**; sexo F=02/M=01/otro=03; prenatal no numérico → **2**; CIE11 y VIDA siempre null

## Después del JSON

Marcar lote (`SPQ_RIPS`) → envío SISPRO → `SET_DATOS` escribe CUV. Cola microservicio opcional (`FEVRIPS_COLA`).

## Fichas

Catálogo en `sps.json` de este módulo (no el de Facturación entero).
