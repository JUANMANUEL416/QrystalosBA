# Plan — Grafo operativo de accidente de tránsito (SOAT)

Metodología igual al grafo de inventario: un JSON por tramo, nodos N0–N4, fichas SP/METODO y puntos críticos. Aquí la cadena es **asistencial + reclamación**, no existencias.

El libro (`proceso.json`) sigue en esqueleto porque se documentó por REQs sueltos (Amparo, FURIPS 2 circular). Este grafo **enlaza** lo ya leído y cierra huecos al pasar cada tramo.

## Cadena (capacitación)

```text
[N0] Config (IDTARIFASOAT, IDPLANSOAT, GFACSOAT, FURIPSRESUMIDO, IDTERCEROINSTALADO)
  ↓
[N1] Expediente HACTRAN (+ detalle HACTRAND / topes)
  ↓
[N2] Atención: HADM / CE-AUT / CI  →  cargos HPRE/HPRED (GFACSOAT)
  ↓
[N3] Factura FTR (Cargos SOAT · FACTURAR o CE) — admisión cerrada
  ↓
[N4] Reclamación: FURIPS 1+2 (TXT o JSON) / FURTRAN / FUCTAS / PDF
```

**Qué no es este grafo:** RIPS JSON / FEVRIPS (`rips-json`) ni XML DIAN. Esos salen de la factura ya notificada (`FACTE=2`), no del expediente SOAT.

## Fase 1 — un tramo por turno

| Orden | Tramo | Documento | Control clave | ¿Genera FTR? | Grafo |
|------:|-------|-----------|---------------|--------------|-------|
| 1 | Creación del expediente | HACTRAN | SPQ_HACTRAN · INSERT / UPDATE / LLENAR | No | **documentado** |
| 2 | Detalle y topes | HACTRAND | SPQ_HACTRAND · INSERT / RELIQUIDAR | No | **documentado** |
| 3 | Cargos SOAT | HPRE / HPRED | SPQ_DISTRIHPRED_SOAT · CARGAR_DATOS / HPRED_SOATSER | No | **documentado** |
| 4 | Facturación SOAT | FTR / HADMF | DISTRIHPRED_SOAT · FACTURAR → SPK_FACTURA_SOAT_TODO | Sí | **documentado** |
| 5 | FURIPS plano TXT | recordsets 1 y 2 | SPQ_FURIPS · FURIPS / FURIPSCXC | No (lee FTR) | **documentado** |
| 6 | FURIPS tipo JSON | FUR_*.json + SER_*.json | Mismo SP; FE `formato=JSON` | No | **documentado** |
| 7 | FURTRAN / FUCTAS / PDF | recordsets V2/V3 (HACTRANFURT no la escribe el export) | SPQ_FURIPS_V2/V3 · FURTRAN / FUCTAS / PDFFURIPS | No | **documentado** |
| 8 | Satélites | AUT / SIRAS / certificados | SPK_RELIQ_HACTRAN / SPK_MOV_ACTRAN / SPQ_HACTRAN certificados | No | **documentado** |

Al cerrar cada tramo: grafo + puntos críticos + veredicto de fichas (¿hay que releer el .sql de hoy?).

## Distinción TXT vs JSON (tramos 5 y 6)

El SP es el mismo (`MODELO FURIPS`). El FE (`useHactranPlanosExport`) elige el formato:

- **TXT:** `Object.values` del recordset → `FURIPS1*.txt` + `FURIPS2*.txt` (o cartera `FURIPSCXC`).
- **JSON:** remapea a grupos oficiales (víctima, sitio, vehículo, propietario, conductor, atención, remisión, transporte) → `FUR_{NIT}.json` + `SER_{NIT}.json`.
- **FURTRAN/FUCTAS en JSON:** hoy envuelven la línea del plano (`formatoOrigen: TXT`); no usan los grupos FUR/SER.

FURIPS 1 = cabecera del accidente. FURIPS 2 = líneas de servicio (HPRE / cirugía / CI / CE).

## Huecos a cerrar en el tramo que los use

| Objeto · METODO | Estado | Tramo |
|-----------------|--------|-------|
| SPQ_HACTRAN · CONSULTAR, CONSULTARSIRASADMISION, CONSULTARTOPES, CERTIFICADORES, CERTIFICADO_*, FORMATO_RECLAMACION, AVISO_AUT_POLICIAL, VALIDARACCIDENTEMISMODIA | leido (2026-10-14; PREVERSION=liberada 2.0.9). No existen DELETE ni RELIQUIDAR en este SP | 8 |
| SPQ_HACTRAND · 9 METODOs | leido (2026-10-14; PREVERSION=liberada 2.0.9) | detalle-topes |
| SPQ_PACIENTE_COL · DATOSAFI | listado | 1 |
| SPQ_DISTRIHPRED_SOAT · CARGAR_DATOS, HPRED_SOATSER/PRE, DISTRIBUIR, REORGANIZAR, GUARDAR, MOVER_*, RELIQUIDAR_ADMISION, FECHAS_CARGOS | leido (2026-10-14; PREVERSION=liberada 2.0.9) | cargos |
| SPQ_DISTRIHPRED_SOAT · FACTURAR | leido (2026-10-14; PREVERSION=liberada 2.0.9) | facturacion |
| SPK_FACTURA_SOAT_TODO | leido (2026-10-14; PREVERSION=liberada 2.0.9) | facturacion |
| SPQ_FURIPS · FURIPS / FURIPSCXC | leido (2026-10-14; PREVERSION=liberada 2.0.9). SELECT externo FURIPS 2 = CAMPO01–09 | furips-txt |
| SPQ_FURIPS_V2 · FURTRAN / FURTRANCXC / PDFFURTRAN / FUCTAS / FUCTASCXC | leido (2026-10-14; PREVERSION=liberada 2.0.9). No escribe HACTRANFURT | 7 |
| SPQ_FURIPS_V3 · PDFFURIPS | leido (2026-10-14; PREVERSION=liberada 2.0.9) | 7 |
| SPK_RELIQ_HACTRAN / SPK_MOV_ACTRAN | leido (2026-10-14; PREVERSION=liberada 2.0.9). RELIQ ≠ HACTRAND · RELIQUIDAR | 8 |
