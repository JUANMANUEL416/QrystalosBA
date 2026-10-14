# Flujo compras → inventario → CxP → caja

Documento transversal (2026-09-19). Detalle por módulo en procesos hermanos `inventario`, `cxp-fcxp`, `caja`, `contabilidad`.

## Uso

- **Documentación:** `proceso.json` (pasos FE + tablas + SP), `puntos-criticos.json` (existencias, costo, contabilidad), **`USVGS-INVENTARIO.md`** + `usvgs-inventario.json` (variables USVGS: para qué sirven y dónde las lee el SQL).
- **Auditoría en vivo:** menú BA → **Auditoría de procesos** → servidor + BD + número OC (`ORDENCOMPRA` o `CNSFCOM`).

## Orden operativo

1. **Catálogo artículo:** ITAR → IART → SER → KMCOM — **`CATALOGO-ARTICULO.md`** (PC-00a … PC-01).
2. **Bodega y tipo movimiento:** ITMO compras + **`USVGS.IDINVMOV_COMPRAS`** + **IBOD** destino (y **IBODS**) — **`CONFIG-BODEGA-TIPO-MOV.md`** (PC-00g … PC-00i). Resto de movimientos (traslado, venta, devolución): **`inventario/MOVIMIENTOS-INVENTARIO.md`**.
3. Cotización opcional: **`ILPRE.GENERAR_OC`**. OC directa: **`FCOM.GENERA_OC`**.
4. **`CONFIRMAR_ORDEN`**: C→P, **`SPK_INSERT_ITRA_REQ`** (ITRA/ITRAH). Detalle: **`OC-CONFIRMACION-RECEPCION.md`**.
5. Primera recepción: tránsito/loteo **o** Excel masivo → **IMOV(0)** → **`CONF_ENTRADA`** (FCOM **R/I**).
6. **Loteo** / **aceptar tránsito** / masiva (ver doc recepción).
7. **`CONF_ENTRADA`** → IEXI — **`CONF-ENTRADA-CXP.md`**.
8. **`PROCESAR_IMOVH`** → FCXPD → **CONTABILIZAR_FCXP** → OP → caja.
9. Salidas IMOV → OM (`SPK_NC_CONTAB_INV`; **PC-08** doble costo).

## Puntos críticos

Ver `puntos-criticos.json` (PC-00a … PC-13). Base del flujo: catálogo (PC-00a–PC-01). Luego puente IMOV–FCXPD (PC-05), CxP (PC-07), OP/caja (PC-09–PC-10), IVA salida (PC-12).
