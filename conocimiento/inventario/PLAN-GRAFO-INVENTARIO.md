# Plan — Grafo operativo de inventario

Metodología acordada con coordinación (2026-10-14). Misma idea que el grafo de contabilización: un JSON por tramo, nodos con SP/METODO, `requires[]`, `llama[]` y puntos críticos auditables. Aquí la cadena es **operativa** (existencias, costo, fechas), no el asiento INV.

El libro (`proceso.json`, `PROCESO.md`) y las fichas (`sps.json`) ya existen. Este grafo **no las duplica**: las enlaza y sirve para capacitación, desarrollos y la pasada de fallas.

## Objetivo

Por **cada tramo** del módulo (lista de precios, cotización, venta, OC, loteo, ingreso masivo, confirmación, entrada/salida), documentar la cadena:

```text
[N0] Configuración (ITAR, IART, IBOD, ITMO, USVGS, TER, KMCOM, PRI)
  ↓
[N1] Documento origen (ILPRE, ICTZ, FCOM, IMOV, ITRA, PRESELL)
  ↓
[N2] Control operativo (guardar, confirmar orden, lotear, aceptar tránsito, confirmar IMOV)
  ↓
[N3] Efecto en existencias / costo (IEXI, IDXB, IART, kardex) — o «no toca IEXI»
  ↓
[N4] Efectos satélite (CxP, FTR, caja, OM) + revisión FECHACONF / NULL / truncamiento
```

Cada nodo lleva: **pantalla**, **SP/METODO**, **tablas**, **requires[]**, **llama[]**, **efecto**, **noEs** (para capacitación) y **validacionSql** (solo lectura).

El grafo de contabilización INV (`contabilidad/grafo-contabilizacion/inv.json`) sigue siendo el de **OM Inventario**. Este plan no lo reemplaza.

---

## Fase 1 — Grafos operativos (un tramo por turno)

Catálogo maestro: `grafo-inventario-indice.json`.

| Orden | Tramo | Documento origen | Control clave | ¿Toca IEXI? | Grafo |
|------:|-------|------------------|---------------|-------------|-------|
| 1 | Listas de precios | ILPRE / ILPRED | GUARDA_ILPRE / IMPORTAR_PRECIO_2 | No | **documentado** |
| 2 | Cotizaciones de compras | ICTZ / ICTZD | GUARDA_COTIZACION / GENERAR_OC | No | **documentado** |
| 3 | Ventas | PRESELL / IMOV VE·VC | GUARDA_VENTA / FACTMASIVO_INV | Sí (descuento) | **documentado** |
| 4 | Órdenes de compra | FCOM / FCOMD | CONFIRMAR_ORDEN → SPK_INSERT_ITRA_REQ | No (solo ITRA) | **documentado** |
| 5 | Loteo / tránsito | ITRA / ITRAH | ON_PROCESAR / ON_ACEPTA_TRANSITO | No (deja IMOV 0) | **documentado** |
| 6 | Ingresos masivos | Excel → ITRA / IMOV | SPQ_FCOM_RECEPCION_MASIVA | No hasta confirmar | **documentado** |
| 7 | Confirmación | IMOV | CONF_ENTRADA / CONFIRMA_SALIDA | Sí | **documentado** |
| 8 | Entradas y salidas | IMOV / IMOVH / ISAL | CRUD + confirmar | No (armado) | **documentado** |
| 9 | Dispensación | IZSOL / IZSOLDT | AGREGAR → CONF_MOVIMIENTO | Sí (al confirmar) | **documentado** |
| 10 | Conteo físico | IFIS / IFISH | APLICAR → APLICARCONTEO | Sí (salida; entrada 0) | **documentado** |
| 11 | Devolución a proveedor | FCOM → IMOV 05 | CONFIRMAR_DEVOLUCION | Sí | **documentado** |
| 12 | Vencidos | IEXI → IMOV 07 | GEN_MOVIMIENTO | Sí (en el acto) | **documentado** |
| 13 | Pick & Pack | IMOV / ISAL reserva | CONFIRMA_PICKING / FINALIZAR_PACKING | No (reserva) | **documentado** |
| 14 | Ajustes de costo / totales | IART / IDXB | AJUSTA_PCOSTO / ACTUALIZAR_EXISTENCIAS | No | **documentado** |
| 15 | Custodia | ITRA / IMOV PR | AGREGA_CUSTODIA / CONF_ENTRADA | Sí (al confirmar) | **documentado** |
| 16 | Satélites e informes | varios | mapa (reutilizan confirmar) | Según satélite | **documentado** |

**Nada del libro queda fuera.** Canastas y gasto por consumo viven en el grafo de dispensación. Trasladar lote e informes, en satélites.

Al cerrar cada tramo: grafo JSON + `puntos-criticos-{id}.json` + veredicto de fichas (¿hay que releer el .sql de hoy?).

---

## Fase 2 — Revisión de fallas (después de cada grafo, no al final de los 8)

Sobre los SP/METODO de **ese** tramo, buscar solo con evidencia de ficha o script:

| Tema | Qué buscar |
|------|------------|
| **Lógica** | `AND 1=2`, `RETURN` prematuro, código muerto, validación en modelo fijo (`'01'`) |
| **Programación** | METODO que llama el FE y no existe en el SP; SPQ que duplica a otro |
| **Truncamiento** | Textos KO cortados o con tildes rotas (`mnimo`, `artculos`, `Período`) |
| **NULL → existencias** | IEXI / IDXB / IART.EXISTOTAL / NOLOTE / FECHAVENCE / PCOSTO en NULL o 0 |
| **FECHACONF fuera de contexto** | Se usa `FECHAMOV` donde el periodo es `FECHACONF`; confirmar/anular sin `PRI.CERRADO_INV` |

Hallazgos ya vistos (no se reabren salvo que el tramo los toque): `TICKETS-CAMBIOS-PENDIENTES.md` (INV-TCK-01…04) y Hallazgos 2026-10-04 del libro.

---

## Cobertura de fichas (2026-10-14)

El catálogo `inventario/sps.json` tiene **77 objetos / 631 METODOs** (PREVERSION vs 2.0.7). No hay que documentar el módulo desde cero.

Huecos a cerrar **en el tramo que los use** (no barrer el `sps.json`):

| Objeto · METODO | Estado | Tramo |
|-----------------|--------|-------|
| SPQ_ILPRE · LEER_DETALLE_OC | leido (2026-10-14) | cotizaciones |
| SPQ_ITRA · ANIOS / EXCEL_DETALLE / EXPORT_TRANSITO | leido (2026-10-14) | loteo (listados; no mueven stock) |
| SPQ_IZSOL_TRANSITO · ON_ELIMINAR / ELIMINA_PREGUARDADO | leido (2026-10-14) | loteo |
| SPQ_IMOV_VENTA · ANEXO_PREVIO | leido (2026-10-14) | ventas |
| SPQ_IMOV_3 · GEN_DOCUMENTO | defecto (INV-TCK-02, RETURN prematuro) | satélites / IZSOL |
| IART · CARGAR_PRECIO_REGULADO | el FE lo llama y no está en SPQ_IART | catálogo |

Los SPK del flujo (CONFIRMARENTRADAS, CONFIRMARSALIDAS, CONFIRMASAL_CM, INSERT_ITRA_REQ, INSERTENTTRANSITO, FAC_VENTA_INV*) están **leido**.

**Fase 1 cerrada 2026-10-14 (ampliada a 16).** Hallazgos nuevos: CONF_MOVIMIENTO no usa CONFIRMARSALIDAS ni PRI (INV-TCK-04 materiales apagado); conteo deja entrada en 0 y no mira PRI; vencidos no respetan reserva P&P; devolución a proveedor hereda confirmar sin PRI. Detalle en cada `puntos-criticos-*.json`.

---

## Reglas de trabajo

1. Un tramo por turno. No saltar a confirmación sin tener OC + loteo + masivo.
2. Fuente: fichas vía índice (`conocimiento/_indice_busqueda.json`). No leer el `sps.json` entero.
3. Si la ficha está `parcial` / `listado` / `fichaAutomatica` y el tramo depende de ella: bajar el objeto de IXONLINE/SQL PREVERSION a `sql/` (Documentar) y completar.
4. No inventar columnas ni invariantes. Si el script no lo dice, queda hueco.
5. En el grafo y en capacitación se dice **control**, no «gate».
6. El libro no publica datos de un cliente (volúmenes, valores de USVGS de una instalación).
7. El grafo **no** lleva rutas internas del BA (`sql/`, `sql_refe/`, `activo/`). Fuente SQL: **IXONLINE/SQL** + nombre del objeto.

---

## Artefactos

| Artefacto | Uso |
|-----------|-----|
| `PLAN-GRAFO-INVENTARIO.md` | Este plan |
| `grafo-inventario-indice.json` | Catálogo maestro: orden, documento, control, estado |
| `grafo-inventario/{id}.json` | Nodos N0–N4 del tramo |
| `grafo-inventario/puntos-criticos-{id}.json` | Invariantes (IDs PC-INVOP-*) |
| `proceso.json` / `sps.json` | Libro y fichas (ya existían) |
| `flujo-compras-inv-cxp-caja/` | Puente compras → CxP (se enlaza, no se copia) |
| `contabilidad/grafo-contabilizacion/inv.json` | OM Inventario (asiento) |
