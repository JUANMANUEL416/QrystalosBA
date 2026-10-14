# Fase 1 — Grafo de contabilización (19 procedencias)

**Estado:** cerrada en catálogo (2026-10-13)  
**Alcance:** procesos que **alimentan** MCP/MCPE desde otros módulos (y comprobante manual / reversos).  
**Fuera de Fase 1:** cierre y apertura de periodo, informes, arrastre SALDOMES/SI → ver `PLAN-GRAFO-CONTABILIZACION.md` (Fase 2).

---

## Objetivo

Por cada valor de `MCP.PROCEDENCIA` / `MCPE.PROCEDENCIA`, documentar la cadena **inversa** desde el generador del asiento hasta configuración y documento operativo:

```text
[N4] Revisión común (SPK_REVISAR_COMPROBANTE, SPK_SUMA_DBCR, confirmación, MCPE→MCP)
  ↑
[N3] Generador (SPK_NC_CONTAB_* / SPK_CONTAB_* / SPK_APL_* / CRUD MCP)
  ↑
[N2] Gate del módulo (confirmar recibo, aplicar pago, contabilizar CxP, etc.)
  ↑
[N1] Documento en estado válido (FCJ, FPAG, FTR, IMOV…)
  ↑
[N0] Configuración (PRI, CUE, USVGS, KMCOM, TTEC, CPCJ, FIMPDV, COM…)
```

Cada grafo JSON incluye nodos con `requiresConfig[]`, `requiresDocumento[]`, `llamaAnterior[]` y enlace a **puntos críticos** (invariantes de negocio).

---

## Artefactos

| Artefacto | Uso |
|-----------|-----|
| `grafo-contabilizacion-indice.json` | Catálogo maestro: orden, generadores, ficha errados, rutas a grafo y PC |
| `grafo-contabilizacion/{id}.json` | Grafo N4→N0 por procedencia |
| `grafo-contabilizacion/puntos-criticos-{id}.json` | Invariantes auditables (IDs PC-*) |
| `procedencias/{id}.json` | Variantes de asiento y texto para errados (ya existía) |
| `PLAN-GRAFO-CONTABILIZACION.md` | Plan por fases y reglas de lectura SQL |
| `grafo-contabilizacion/VALIDACION-SQL-INDICE.json` | Cruce requires[] ↔ checks read-only en Auditoría BA |
| `sql/` (Documentar) | Cuerpos PREVERSION releídos para generadores 10–17 y satélites |

**Proceso hermano:** el detalle operativo (pantalla, METODO) sigue en `conocimiento/{proceso}/`. El grafo no sustituye la ficha del SP en inventario/caja/recaudos; **complementa** el camino hacia contabilidad.

---

## Catálogo de las 19 procedencias

| # | PROCEDENCIA | Generador principal | Documento origen | Grafo | Puntos críticos |
|---|-------------|---------------------|------------------|-------|-----------------|
| 1 | CAJA | SPK_NC_CONTAB_CAJA_ING / EGR | FCJ (REF1 recibo, REF2 caja) | `caja.json` | `puntos-criticos-caja.json` |
| 2 | CXC | SPK_NC_CONTAB_CXC | FPAG (REF1 = CNSFPAG) | `cxc.json` | `puntos-criticos-cxc.json` |
| 3 | FACTURA | SPK_NC_CONTAB_FTR | FTR (NOREFERENCIA) | `factura.json` | `puntos-criticos-factura.json` |
| 4 | NOTDBCR | SPK_NC_CONTAB_FNOT | FNOT | `notdbcr.json` | `puntos-criticos-notdbcr.json` |
| 5 | CXP | SPK_NC_CONTAB_CXP | FCXP (REF1 = CNSFCXP) | `cxp.json` | `puntos-criticos-cxp.json` |
| 6 | NOTDBCRCXP | SPK_NC_CONTAB_CXPFNT | FCXP + ítem nota | `notdbcrcxp.json` | `puntos-criticos-notdbcrcxp.json` |
| 7 | INV | SPK_NC_CONTAB_INV | IMOV (REF1 = CNSMOV) | `inv.json` | `puntos-criticos-inv.json` |
| 8 | BMOV | SPK_NC_CONTAB_BMOV | BMOV/BMOVD | `bmov.json` | `puntos-criticos-bmov.json` |
| 9 | RGLO | SPK_CONTAB_FGLO | FGLO | `rglo.json` | `puntos-criticos-rglo.json` |
| 10 | CONCI | SPK_CONTAB_CONCI (+ ANULA) | FCONCI | `conci.json` | `puntos-criticos-conci.json` |
| 11 | RAD CXC | SPK_CONTAB_RADICACXC / _1 | FCXC / CNSCXC | `rad-cxc.json` | `puntos-criticos-rad-cxc.json` |
| 12 | AJDEP | SPK_APL_AJDEPRECIACION | Periodo + sede | `ajdep.json` | `puntos-criticos-ajdep.json` |
| 13 | IACT | SPK_CONTAB_IACT | IACT / IACTH | `iact.json` | `puntos-criticos-iact.json` |
| 14 | ANTICIPOS | SPK_NC_CONTAB_ANTICIPO | Anticipo / TANT | `anticipos.json` | `puntos-criticos-anticipos.json` |
| 15 | NOMINA | SPK_NC_CONTAB_NOMINA | Nómina cerrada | `nomina.json` | `puntos-criticos-nomina.json` |
| 16 | CESIONES | SPK_CONTAB_FCES | FCES | `cesiones.json` | `puntos-criticos-cesiones.json` |
| 17 | LEGALIZACION | SPK_CONTAB_FLEG | FLEG / caja menor | `legalizacion.json` | `puntos-criticos-legalizacion.json` |
| 18 | REVERSOS | SPK_REVERSAR_MCP | MCP original | `reversos.json` | `puntos-criticos-reversos.json` |
| 19 | MANUAL | SPQ_MCP_COL · CRUDMCP | Usuario | `manual.json` | `puntos-criticos-manual.json` |

**Puerta común:** pestaña *Otros módulos* → `SPQ_CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS` (mismo despachador que Reconstruir en MCPE). Cada grafo termina en el METODO de pantalla del proceso hermano.

**Revisión común (todas):** ver bloque `revisionComun` en el índice maestro (`SPK_REVISAR_COMPROBANTE`, `SPK_SUMA_DBCR`, `SPK_NC_CONFIRMAR_CONTAB`, errados, `SPQ_MCPE_COL · RECONSTRUIR`).

---

## Metodología de lectura

1. Bajar generador desde **IXONLINE/SQL PREVERSION** (comparar última liberada si el ticket depende de un fix pendiente).
2. Extraer `requires` de tablas, JOINs y `USVGS` / `DBO.FNK` — no inventar variables.
3. Subir `llamaAnterior` hasta el METODO que deja el documento listo (confirmar, aplicar, etc.).
4. Registrar al menos **dos puntos críticos** por procedencia (config + documento).
5. Enriquecer `auditoriaBd` en el grafo: qué checks del motor BA aplican hoy.

**Profundización N3 (2026-10-13):** cada generador N3 incluye `requires` ampliados, `llamaAnidado`, `postGenerador` (REVISAMCPE/PASA), `catalogoSql` (USVGS + mensajes RAISERROR leídos de `sql/` PREVERSION) y parches en `deep/*-n3.json`. Fusión: `scripts/_deepen_grafos_n3.py`.

**Profundización N0–N2 (2026-10-13):** las 19 procedencias tienen gates operativos, pantallas/METODO y `requires[]` en configuración y documento. Parches mantenibles en `grafo-contabilizacion/deep/*-n012.json`; fusión con `scripts/_deepen_grafos_nodos.py`. CAJA/CXC ya traían cadena completa; el resto quedó alineado al mismo nivel (`metadatosFase1.estadoDocumentacion`: `profundizado-n012`).

---

## Auditoría BA (read-only)

**Menú:** Auditoría de procesos → **Validar configuración contable**.

- **API:** `GET /api/auditoria/procedencias-contab` · `POST /api/auditoria/config-contabilidad` con `{ servidorId, baseDatos, procedencia }` (opcional `referencia` + `tipoReferencia: CNSFPAG` para cruce documento en recaudos).
- **Motor:** `scripts/auditoria_procesos.py` → `validar_config_contabilidad` agrega USVGS/tablas desde `requires[]` de los grafos seleccionados.
- **Implementación actual:**
  - **Global:** PRI, USVGS del grafo, cuentas USVGS vs CUE, TTEC, CPCJ/CAJ, FIMPDV, COMMS multisede, CONCI/NOTDBCR según paquete.
  - **Por procedencia:** FPA, BCT, OFIN, KMCOM (`IDTIPOCONT` CXP_COMPRAS, MOV_INVENTARIO, etc.).
  - **Documento (grafo N3):** `tipoReferencia` + `referencia` — **CNSFPAG**, **CNSFCXP**, **N_FACTURA**, **CNSMOV**, **FCJ** (`CODCAJA/CNSFACJ`). Inferencia automática si elige una sola procedencia. Respuesta incluye `catalogoValidacionN3` (requires con `validacionSql`). Detalle checks: `VALIDACION-SQL-INDICE.json` → `checksDocumentoImplementados`.
- **Traza recaudos:** pasos «Grafo config» vía checks FPAG al final de `trazar_recaudos`.

Estados en grafo (`auditoriaBd.estado`):

| Estado | Significado |
|--------|-------------|
| `implementado_parcial` | CAJA, CXC — checks config + documento FPAG |
| `catalogo` | Resto — validación config vía requires[]; cruce documento pendiente (FCJ, CNSFCXP, N_FACTURA, …) |

Detalle check ↔ SQL: `grafo-contabilizacion/VALIDACION-SQL-INDICE.json`.

---

## Trazas documento (complemento, no Fase 1)

Flujos transversales ya en `conocimiento/`:

- Recaudos → CxC → contabilidad (`flujo-recaudos-cartera-contab`) — CNSFPAG.
- Compras → inv → CxP → caja — orden de compra.

Fase 1 entrega el **mapa estático**; las trazas dinámicas se amplían en auditoría cuando haya consecutivo.

---

## Límites explícitos (Fase 2)

No están modelados en estos grafos:

- Validación antes de cierre (`FNK_REVISION_ANTES_CIERRE_PERIODO`, inventario por FECHACONF vs FECHAMOV en grillas).
- Cierre/apertura PRI, cierre fiscal, SALDOMES/SI.
- Libros, foliado, exógena.
- Castigo cartera, liquidación impuestos, NIIF (procedencias propias o controles capa 4).

---

## Cómo usar en un REQ

1. Identificar `PROCEDENCIA` en MCPE/MCP.
2. Abrir grafo + `procedencias/{id}.json` + ficha errados en `agentes.json`.
3. Recorrer N3→N0: ¿falla config o documento?
4. Si hace falta evidencia SQL del día: bajar SP a carpeta del caso (Analista) o releer `sql/` (Documentar).
5. Proponer corrección en origen; Revisar + Reconstruir en MCPE.

---

## Referencias cruzadas

- Capa 3 del libro contable: `proceso.json` → `03-alimentadores` (controles por procedencia + enlace a este catálogo).
- Errados: control `mcpe-flujo-invertido`, `errores-comprobantes.json`.
- Plan siguiente: `grafo-contabilizacion-indice.json` → `fase2Pendiente[]`.
