# Núcleo crítico: IEXI completo ↔ KMCOM ↔ CxP = entrada

Este es el **punto más sensible** del flujo compras: si falla aquí, hay stock incorrecto, CxP mal valuada o contabilidad incoherente.

JSON de controles: `nucleo-critico-iexi-cxp.json`.

## 1. Ingreso completo a IEXI (existencias)

**Responsable:** `SPQ_IZSOL.CONF_ENTRADA` → **`SPK_CONFIRMARENTRADAS`**.

| Invariante | Qué comprueba |
|------------|----------------|
| **Toda línea confirmada en stock** | Por cada `IMOVH` del movimiento confirmado debe existir **IEXI** en `IMOV.IDBODEGA` + `IDARTICULO` + **NOLOTE** (PK lote). |
| **Cantidad sumada** | `IEXI.EXISLOTE` aumenta en `IMOVH.CANTIDAD` (líneas marcadas ESTADO=9 durante el SP). |
| **No confirmar a medias** | Si `CONF_ENTRADA` KO, `IMOV.ESTADO` sigue 0 — no asumir existencias. |
| **Lote / pedido** | Reglas de adopción de `NOLOTE` vs `NOLOTEPEDIDO` (custodia, hemoderivados); lote duplicado en IEXI bloquea inserción. |

**Señales de fallo:** IMOV `ESTADO=1` pero líneas sin fila IEXI; cantidades OC vs IEXI incoherentes; usuario confirmó sin completar factura/costo (ver PC-04b).

**Prueba coordinador:** Inventario → consulta existencias por artículo/lote/bodega vs movimiento confirmado.

---

## 2. Generación correcta de la CxP (detalle)

**Responsable:** **`PROCESAR_IMOVH`** → **`SPK_INSERT_CXP_INV`** (`PROCE='CXP'`).

| Paso SPK | Efecto |
|----------|--------|
| Marca `IMOVH.ESTADO=9` (lectura) | Cursor sobre **VWK_IMOVH_AGRUPADO** |
| Inserta **FCXPD** | `N_PRESUP = CNSMOV`, `IDSERVICIO = IDARTICULO`, cantidades/valores desde entrada |
| **FNK_CUENTA_KMCOM** | `CXP_COMPRAS` / DB por **PREFIJO (ITAR)**, **CCOSTO**, **IDAREA** |
| Homologación gravada | Si `VLR_IVA>0` y cuenta con `MCUEGRAV=1` → **`CUENTA_SER = CUENTAGRAV`** |
| IVA línea | `FNK_PIVA_IART` / `ITAR.CUE_IVA` si `CONTAB_INV_IVA_ITAR=SI` |
| Cierra puente | `IMOVH.ENCXP=1`, **`SPK_CALCULOVALORESCXP`** actualiza cabecera **FCXP** |

**No sustituye** confirmar entrada: el IMOV debe estar **`ESTADO=1`** con costos ya fijados en IMOVH.

---

## 3. Validación KMCOM (dos momentos)

| Momento | Dónde | Qué valida |
|---------|-------|------------|
| **Antes de existencias** | `CONF_ENTRADA` si `VALID_CCOSTO_CXP=SI` | KMCOM **CXP_COMPRAS** DB **y** CR por **ITAR** + **CCOSTO** del IMOV |
| **Al armar FCXPD** | `SPK_INSERT_CXP_INV` | `FNK_CUENTA_KMCOM(...,'CXP_COMPRAS','DB',...)` en cada línea → **CUENTA_SER** |
| **Solo cuentas (reconstrucción)** | `RECONSTRUIR_CUENTAS_FCXPD` | Recalcula **PREFIJO** y **CUENTA_SER** vía KMCOM; **no** relee importes de IMOVH |

**Error típico:** CCOSTO del IMOV distinto al configurado en KMCOM para ese prefijo ITAR → KO en CONF_ENTRADA o CUENTA_SER vacía / inválida en FCXPD.

---

## 4. Reconstrucción de CxP — qué sí y qué no

| Acción | METODO | Corrige valores | Corrige cuentas KMCOM |
|--------|--------|-------------------|------------------------|
| **Rearmar desde inventario** | `PROCESAR_IMOVH` | **Sí** (borra FCXPD del CNSMOV y vuelve a leer IMOVH) | **Sí** (incl. CUENTAGRAV) |
| **Reconstruir cuentas** | `RECONSTRUIR_CUENTAS_FCXPD` | **No** | **Sí** (PREFIJO, CUENTA_SER) |
| **Editar manual FCXPD** | CRUD UI | Riesgo de desalinear vs IMOV | — |

**Regla operativa:** si la entrada cambió (costo, IVA, cantidades) después de un `PROCESAR_IMOVH` → volver a **`PROCESAR_IMOVH`**, no solo reconstruir cuentas.

**Condición:** `FCXP.CONTABILIZADA = 0`.

---

## 5. Cuadre: entrada (IMOVH) = detalle CxP (FCXPD) = cabecera FCXP

Referencias de cálculo en SPK (base sin IVA en PCOSTO/COSTO; IVA en `VLRIVA` / `VLR_IVA`; `REDONDEO_COMPRAS_CXP` redondea a 3–4 decimales).

| Nivel | Cuadre esperado |
|-------|-----------------|
| **Línea** | `FCXPD.CANTIDAD` ≈ suma IMOVH agrupada; `FCXPD.VALOR` ≈ unitario base; `VLR_IVA` ≈ IMOVH.IVA/VLRIVA |
| **Movimiento** | Σ(`VALOR×CANTIDAD`) + Σ`VLR_IVA` en FCXPD (`N_PRESUP=CNSMOV`) ≈ Σ(`PCOSTO×CANTIDAD`) + Σ`VLRIVA` en IMOVH |
| **Cabecera** | `FCXP.VLR_NETO`, `VLR_IVA`, `VALOR` coherentes con **SPK_CALCULOVALORESCXP** tras procesar |

Tolerancia práctica en auditoría: **≤ 1 peso** por redondeo masivo (`REDONDEO_COMPRAS_CXP=SI`).

**Después de PROCESAR:** revisar en UI CxP totales vs reporte del movimiento confirmado; si divergen → reprocesar IMOVH.

---

## Puntos críticos (IDs)

| ID | Tema |
|----|------|
| **PC-N1** | IEXI completo por IMOV confirmado |
| **PC-N2** | FCXPD generado desde IMOVH (ENCXP) |
| **PC-N3** | KMCOM CXP_COMPRAS (CONF_ENTRADA + CUENTA_SER) |
| **PC-N4** | Reconstrucción: PROCESAR vs RECONSTRUIR |
| **PC-N5** | Cuadre importes IMOVH ↔ FCXPD ↔ FCXP |

## Auditoría BA

La traza OC ejecuta pasos **«IEXI vs IMOV confirmado»** y **«Cuadre IMOVH ↔ FCXPD ↔ FCXP»** cuando hay movimientos confirmados y/o FCXPD.

## Runbook soporte

Guía síntoma → paso Auditoría → acción en app: **`RUNBOOK-SOPORTE-IEXI-CXP.md`** (PC-N1 … PC-N5).
