# Proceso: Facturación

**Estado:** parcial  
**Módulo:** FTR

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

## Resumen

Quien factura arma la factura en Administrativo → Facturación, notifica a la DIAN, empaqueta anexos, junta facturas en una **cuenta de cobro** y la **radica** en Cuentas por cobrar (fecha, quién recibió, número de radicado).

**Ya cubierto (no es desarrollo):** subir el radicado de cada factura en masa = detalle de CXC **recibida** → **Importar Radicados**. No es el diálogo Radicar → «varias fechas». Ver `proceso.json` → `necesidadesYaCubiertas`.

Eso no es el menú **Radicaciones** (`/rad`): ahí se reciben lotes, incapacidades y PQR.

## Capas

1. Configuración — resolución DIAN, firma, pagador/plan.
2. Proceso propio — facturar → notificar → empaquetar → armar cuenta → radicar.
3. Lo que llega — admisión, citas, autorizaciones.
4. Subproceso unido — empaque y RIPS/FEV (no bancos).
5. Envío a contabilidad — factura y cuenta (cuerpo de SP no leído).

## Árbol RIPS JSON (2026-09-12)

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
                 │    ├─ TIPOFAC=M + NEDXC/NEDXS    → SPK_RIPS_JSON_FTR_CITPAQ
                 │    ├─ TIPOFAC=M (resto)          → SPK_RIPS_JSON_FTR_MAS
                 │    └─ evento (no M, no capita)   → SPK_RIPS_JSON_FTR_IND
                 ├─ AJUSTE (CNSGLO o CNSFCT) + CUV obligatorio
                 │    ├─ capita + PGP               → SPK_RIPS_JSON_AJUSTE_PGP  → RETURN
                 │    ├─ capita no-PGP              → no genera (JSON actual) → RETURN
                 │    └─ evento                     → SPK_RIPS_JSON_AJUSTE_IND → RETURN
                 ├─ NOTACR / NOTADB (FNOT.FACTE=2)  → SPK_RIPS_JSON_NDBCR_IND
                 └─ luego SPK_PERSISTIR_RIPSJSON_ENVIO → FTRJSON / FNOTJSON

NOTAAJUSTE_PGP y NOTAAJUSTE_MAS están en el script después del RETURN de AJUSTE:
no se ejecutan por este camino. Confirmar otro caller al leerlos.
```

Árbol **cerrado 2026-09-12**. El módulo propio (preguntas, FAQ, fichas) es `conocimiento/rips-json/`. No pido más SQL de este circuito.

Módulos hermanos de documentos electrónicos:

- XML DIAN / FEV (Colombia, `FACTE`) → `conocimiento/dian-xml/`
- JSON Perú / SUNAT (`FACTEP`) → `conocimiento/json-peru/`

