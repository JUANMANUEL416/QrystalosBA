# Inventario — tickets de cambio (post-normalización)

Documentación de movimientos cerrada en **PREVERSION 2.0.3** (`sql/`, `sps.json`, `MOVIMIENTOS-INVENTARIO.md`).  
Estos ítems son **defectos o desalineaciones** detectados en análisis; no están implementados en QrystalosBA.

Use esta lista para **validar en test** y **solicitar desarrollo** con criterios claros.

---

## INV-TCK-01 — KMCOM modelo fijo `'01'` en confirmación salida (INV-C06)

| Campo | Valor |
|-------|--------|
| **Invariante** | INV-C06 |
| **Objeto** | `SPK_CONFIRMARSALIDAS` |
| **Fuente** | `sql/SPK_CONFIRMARSALIDAS.sql` (~L114–125) |
| **Síntoma** | Al confirmar salida con `SECONTABILIZA=1`, la validación previa exige KMCOM `MOV_INVENTARIO` con **`IDMODELOCONT='01'`** fijo. El cliente puede tener **USVGS IDMODELOCONTABLE** distinto; las cuentas reales en **SPK_NC_CONTAB_INV** pueden resolverse con otro modelo. |
| **Riesgo** | Falso KO «No existe configuración contable… MOV_INVENTARIO» aunque KMCOM esté bien en el modelo del cliente; o validación pasada en `'01'` pero contabilización con modelo distinto. |
| **Validar antes** | 1) Anotar `IDMODELOCONTABLE` en USVGS. 2) Confirmar salida contabilizable con CCOSTO real. 3) Comparar filas KMCOM CR/DB (`PREFIJO=IDTIPOMOV`, `CCOSTO`) en modelo `'01'` vs modelo USVGS. |
| **Cambio propuesto (SQL)** | Sustituir `'01'` por `DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE')` (o la misma función que use `FNK_NC_CUENTA_KMCOM` en contabilización) en ambos `EXISTS` KMCOM. |
| **Regresión** | Traslados, venta, Pick&Pack, devolución proveedor (no contabiliza OM), dispensación (otro SPK). |
| **Impacto** | SQL · Backend (sin FE si mensaje igual). |

---

## INV-TCK-02 — GEN_DOCUMENTO incompleto (SPQ_IMOV_3)

| Campo | Valor |
|-------|--------|
| **Objeto** | `SPQ_IMOV_3` · METODO `GEN_DOCUMENTO` |
| **Fuente** | `sql/SPQ_IMOV_3.sql` (~L542–586) |
| **Síntoma** | Tras validar periodo **PRI** y tercero **RPDX**, hay **`RETURN` incondicional** (L559); el bloque `--QUERY3` y el `SELECT 'OK'` posterior son **código muerto**. |
| **FE** | `Qrystalos2` · `IndexComponent.vue` · `onGenDocumento` → `MODELO: IMOV_3`, callback vacío aunque llegue OK. |
| **Validar antes** | Invocar GEN_DOCUMENTO con RPDX válido: comprobar que no devuelve OK/KO útil ni genera documento contable. |
| **Cambio propuesto** | 1) Quitar `RETURN` prematuro; implementar generación (QUERY3 / MCP según diseño legacy). 2) FE: acción post-OK (impresión, enlace comprobante, etc.). |
| **Regresión** | IZSOL flujo boleta/documento; periodo cerrado debe seguir KO. |
| **Impacto** | SQL + FE (inv.sol). |

---

## INV-TCK-03 — SPQ_IMOV_4 listados UI (opcional / baja)

| Campo | Valor |
|-------|--------|
| **Alcance** | METODOs solo listados en `sps.json` (`LISTA_PICKING`, `DETALLE_PACKING`, …) — comportamiento ya cubierto en fichas núcleo; documentación UI en mockups cliente. |
| **Acción** | Solo si QA reporta huecos; no bloquea validación contable. |

---

## INV-TCK-04 — presupuesto de insumos apagado al confirmar dispensación

| Campo | Valor |
|-------|--------|
| **Objeto** | `SPK_CONFIRMASAL_CM` |
| **Dónde** | 2.0.5 y PREVERSION (iguales). En 2.0.3 el bloque sí corría. |
| **Síntoma** | El `EXISTS` de materiales (`PREFIJOMATERIALES`) termina en `AND 1 = 2`. Ese bloque insertaba `HPREP` procedencia INSUMO y ya no entra. |
| **Validar antes** | Confirmar una salida de dispensación de un artículo con prefijo de materiales y ver si deja de nacer el presupuesto HPREP. |
| **No asumir** | No está dicho si el `1 = 2` es un apagado a propósito o un resto de prueba. |

---

## Checklist de validación (coordinador / test)

Referencia completa: **`MOVIMIENTOS-INVENTARIO.md`** §4 y **`catalogo-movimientos-inventario.json`**.

### Herramientas BA

1. Reiniciar servidor BA · Ctrl+F5.
2. **Auditoría → Validar USVGS inventario** (`POST /api/auditoria/usvgs`).
3. **Auditoría → Mapa movimientos ITMO** (`POST /api/auditoria/movimientos-inventario`).

### Por familia (muestra mínima)

| Familia | Probar | Contabilidad esperada |
|---------|--------|------------------------|
| Entrada compra | CONF_ENTRADA · CUFE sync | MOV_INVENTARIO + CXP si aplica |
| Salida consumo | CONFIRMA_SALIDA | MOV_INVENTARIO si SECONTABILIZA efectivo |
| Traslado IDTS/IDTE | Salida + entrada destino | MOV_INVENTARIO interno |
| Pick&Pack | FINALIZAR_PACKING → CONFIRMA_SALIDA | Igual salida |
| Venta FTR | VENTAFAR o FACTURAR_IMOV | FTR + INV (CONTAB_GASTOVEN_UNI) |
| Dev. traslado | ITRAH_REGRESAR + ITRADEV ACEPTAR | Entrada IDTIMOVDEV_TRASLBOD |
| Dev. proveedor | IDINVDEVPROVEEDOR | Sin OM INV |

### Tickets abiertos en validación

- Si falla salida solo con KMCOM en modelo USVGS pero no en `'01'` → **INV-TCK-01**.
- Si botón documento IZSOL no hace nada → **INV-TCK-02**.

---

## Cierre documentación BA

| Artefacto | Estado |
|-----------|--------|
| `conocimiento/inventario/sps.json` | SPQ_IMOV_3 métodos whitelist fichados |
| `sql/` PREVERSION 2.0.3 | Objetos movimientos + ITRADEV + CUFE + reintegra |
| `MOVIMIENTOS-INVENTARIO.md` | Flujos §4 + auditoría §6 |
| `TICKETS-CAMBIOS-PENDIENTES.md` | Este archivo |
| `pendientes.json` | INV-TCK-01 / INV-TCK-02 registrados |

Fecha cierre documentación: **2026-09-19**.
