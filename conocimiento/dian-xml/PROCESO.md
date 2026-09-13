# Proceso: Facturación · XML DIAN / FEV

**Estado:** parcial  
**Módulo:** DIAN_XML · Administrativo → Facturación (Colombia)  
**Hermanos:** `facturacion` (armar FTR), `rips-json` (JSON SISPRO), `json-peru` (SUNAT).

> Pregunte en Documentar o Consultas eligiendo este módulo. El título del Chat es **XML DIAN / FEV** (no empiece por «Facturación ·»).

## Qué es / qué no es

| Esto | No es |
|------|--------|
| Encolar FEV (FACTE) + CUFE + XML en FTRE | JSON RIPS / CUV ministerio |
| Descarga `TREA_XML` | JSON Perú / SUNAT (`FACTEP`) |
| Resolución y certificado | Radicar cuenta (`FCXC`) |

## Árbol de notificación

```
FE Facturación (NotificaDian / confirmar FE / Proceso DIAN)
  ├─ VALIDADIAN2 (al numerar; BLOQUEADIAN)
  └─ Encolar
       ├─ FTR_COL · NOTI_DIAN              → FTR.FACTE=1
       ├─ FTR_COL · ENCOLAR_ITEM           → FTR o FNOT.FACTE=1
       ├─ FTR_COL · ENCOLAR_MASIVO         → VWK_ESTADODIAN_FTRE
       └─ FTRFE_COL · FE_ENCOLAR           → FTR.FACTE=1 (fecha=hoy)
            └─ Servicio facturador (fuera de SPQ)
                 → FACTE=2 + FTRE (CUFE, XML)
                      ├─ LISTAR_FTRE / TREA_XML
                      ├─ RESET_NOTIFICADOS (correo EPS)
                      └─ opcional: rips-json (exige FACTE=2)
```

**Desencolar:** `DESCOLA_ITEM` / `FE_DESENCOLAR` → FACTE=0. No toca FACTE=2.

## Estados FACTE

0 Sin notificar · 1 En cola · 2 Notificada (DIAN OK) · 3 Con errores · 4 Procesando · 5 Por prevalidar · 6 Prevalidada · 7 Rechazada en pruebas.

## Hueco consciente

El **cuerpo del XML** (UBL / AttachedDocument) lo arma el **servicio facturador electrónico**, no un `SPQ_*` de Qrystalos. Aquí documentamos cola, precondiciones y lectura (`TREA_XML`, `FDIANR` para el ZIP RIPS).
