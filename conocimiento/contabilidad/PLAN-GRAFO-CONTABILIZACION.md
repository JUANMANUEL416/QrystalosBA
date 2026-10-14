# Plan — Grafo contable (desde contabilización hacia atrás)

Metodología acordada con coordinación (2026-10-13).

## Objetivo

Por **cada procedencia contable** (cabecera MCP/MCPE), documentar la cadena **inversa**:

```text
[N0] Configuración (PRI, CUE, KMCOM, USVGS, TTEC, FIMPDV, COM…)
  ↑
[N1] Documento origen en estado válido (FTR, FCJ, FPAG, IMOV…)
  ↑
[N2] Gate operativo del módulo (confirmar, aplicar, contabilizar CxP…)
  ↑
[N3] Generador del comprobante (SPK_NC_CONTAB_* / SPK_CONTAB_*)
  ↑
[N4] Revisión común (SPK_REVISAR_COMPROBANTE, SPK_SUMA_DBCR, confirmación)
```

Cada nodo lleva: **SP/METODO**, **tablas**, **requires[]** (config + documento), **llama[]** hacia atrás, **validacionSql** (solo lectura en Auditoría BA).

Al terminar **todos** los procesos contables alimentadores, **Fase 2**: cierre de periodo, informes y arrastre al periodo nuevo.

---

## Fase 1 — Procesos contables (alimentadores → generador)

Catálogo maestro: `grafo-contabilizacion-indice.json`. Ficha errados existente: `procedencias/{id}.json` + `agentes.json`.

| Orden sugerido | PROCEDENCIA | Generador(es) | Proceso hermano | Grafo hacia atrás |
|----------------|-------------|---------------|-----------------|-------------------|
| 1 | CAJA | SPK_NC_CONTAB_CAJA_ING / EGR | caja | **documentado** |
| 2 | CXC | SPK_NC_CONTAB_CXC | recaudos | **documentado** |
| 3 | FACTURA | SPK_NC_CONTAB_FTR | facturacion | **documentado** |
| 4 | NOTDBCR | SPK_NC_CONTAB_FNOT | notas-dbcr | **documentado** |
| 5 | CXP | SPK_NC_CONTAB_CXP | cxp-fcxp | **documentado** |
| 6 | NOTDBCRCXP | SPK_NC_CONTAB_CXPFNT | cxp-fcxp | **documentado** |
| 7 | INV | SPK_NC_CONTAB_INV | inventario | **documentado** |
| 8 | BMOV | SPK_NC_CONTAB_BMOV | bancos | **documentado** |
| 9 | RGLO | SPK_CONTAB_FGLO | glosas | **documentado** |
| 10 | CONCI | SPK_CONTAB_CONCI (+ ANULA) | conciliaciones | **documentado** |
| 11 | RAD CXC | SPK_CONTAB_RADICACXC / _1 | facturacion / radicaciones | **documentado** |
| 12 | AJDEP | SPK_APL_AJDEPRECIACION | activos-fijos | **documentado** |
| 13 | IACT | SPK_CONTAB_IACT | activos-fijos | **documentado** |
| 14 | ANTICIPOS | SPK_NC_CONTAB_ANTICIPO | cxp-fcxp | **documentado** |
| 15 | NOMINA | SPK_NC_CONTAB_NOMINA | nomina | **documentado** |
| 16 | CESIONES | SPK_CONTAB_FCES | (cesiones) | **documentado** |
| 17 | LEGALIZACION | SPK_CONTAB_FLEG | caja / legalización | **documentado** |
| 18 | Reversos | SPK_REVERSAR_MCP, REV* | varios | **documentado** |
| 19 | MANUAL | CRUD MCP/MCH | — | **documentado** |

**Estado 2026-10-13:** Fase 1 cerrada en catálogo y documentación maestro (`FASE-1-GRAFO-CONTABILIZACION.md`, `VALIDACION-SQL-INDICE.json`, capa 03 `proceso.json`). Siguiente: ampliar trazas documento en Auditoría + Fase 2 (cierre periodo).

Salida por procedencia: `grafo-contabilizacion/{procedencia-id}.json` (nodos + requires + enlace al SP en sql/ o carpeta del caso).

Puerta común **Otros módulos**: `SPQ_CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS` → despacha al generador; el grafo de cada pestaña termina en la fila de la tabla anterior.

---

## Fase 2 — Después de Fase 1 (revisión acordada)

No se dictamina cierre hasta tener Fase 1 cerrada.

| Tema | Qué documentar / auditar |
|------|---------------------------|
| **Contabilización transversal** | SPK_REVISAR_COMPROBANTE, SPK_NC_CONFIRMAR_CONTAB, MCPE→MCP, estados 0/1/2 |
| **Cierre de periodo** | VALIDAR_PERIODO_BASICO, FNK_REVISION_ANTES_CIERRE_PERIODO, sub-cierres cartera/CxP |
| **Apertura periodo nuevo** | SPK_ABRE_PERIODOCONTABLE, qué valida el anterior cerrado |
| **Informes** | Libros (USCXS), foliado, balances, exógena — qué leen (MCP/MCH, SALDOMES) |
| **Arrastre al nuevo periodo** | SALDOMES/SALDOMESTER, SI, saldos por tercero; qué **no** se mueve (documentos operativos abiertos) |

Entregable Fase 2: `grafo-cierre-periodo.json` + checks read-only en Auditoría (complemento, no sustituto de Fase 1).

---

## Reglas de trabajo

1. Leer generador en **PREVERSION** (sqlix); comparar liberada si aplica.
2. Subir `llama[]` hasta el METODO de pantalla; no inventar requires — salen del SQL.
3. Cruzar proceso hermano (`sps.json`); el grafo **no** duplica el cuerpo del SP.
4. Auditoría BA: primero catálogo requires; después traza por referencia (NROCOMPROBANTE / REFERENCIA1).
