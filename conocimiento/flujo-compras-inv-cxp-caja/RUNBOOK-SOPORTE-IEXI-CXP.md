# Runbook soporte — núcleo IEXI ↔ CxP (PC-N1 … PC-N5)

**Audiencia:** soporte L2 / coordinador. **Solo lectura en BD** salvo acciones en pantalla Qrystalos.

**Herramienta BA:** menú **Auditoría de procesos** → servidor + BD + `CNSFCOM` u `ORDENCOMPRA`. Los pasos citados coinciden con los nombres de la traza.

**Referencias:** `NUCLEO-CRITICO-IEXI-CXP.md` · `CONF-ENTRADA-CXP.md` · `nucleo-critico-iexi-cxp.json`

---

## Orden de diagnóstico (siempre)

1. Traza la **OC** en Auditoría BA.
2. Ubica el **CNSMOV** (IMOV) en el paso «Ingreso inventario (IMOV)».
3. Sigue la tabla del síntoma más abajo **de arriba hacia abajo** (N1 → N5): no contabilizar CxP con N1 o N5 en KO.

---

## PC-N1 — IEXI incompleto

| Campo | Contenido |
|-------|-----------|
| **Síntomas usuario** | «Confirmé entrada pero no veo stock»; «existencia en cero»; artículo no aparece en kardex/lote. |
| **Paso Auditoría KO** | **IEXI vs IMOV confirmado** — «Líneas IMOVH sin fila IEXI». |
| **Causas frecuentes** | CONF_ENTRADA falló a medias (raro); **NOLOTE** duplicado o no alineado bodega+artículo+lote; movimiento no confirmado (`IMOV.ESTADO=0`) pero usuario cree que sí; bodega distinta a la consultada. |
| **Consulta solo lectura** | IMOV `ESTADO`, `IDBODEGA`; IMOVH por `CNSMOV`; IEXI mismo `IDBODEGA`+`IDARTICULO`+`NOLOTE`. |
| **Acción en app** | Si `IMOV.ESTADO=0`: completar factura/costo/vencimientos (PC-04b) → **CONF_ENTRADA** de nuevo. Si `ESTADO=1` y falta IEXI: **escalar L3** (posible inconsistencia post-SPK); no insertar IEXI manual en SQL. |
| **No hacer** | PROCESAR_IMOVH / contabilizar CxP hasta resolver existencias. |
| **Escalamiento** | L3 con `CNSMOV`, captura IMOV/IMOVH, resultado traza N1. |

---

## PC-N2 — CxP no generada o IMOVH sin ENCXP

| Campo | Contenido |
|-------|-----------|
| **Síntomas usuario** | «No puedo contabilizar la factura»; «CxP sin detalle»; «el movimiento no pasó a CxP». |
| **Pasos Auditoría** | **Cuenta por pagar (FCXP)** warn «Sin FCXP»; **Detalle CxP ↔ IMOV** KO; **IMOVH sin ENCXP** (hay FCXPD pero ENCXP=0). |
| **Causas frecuentes** | No ejecutaron **PROCESAR_IMOVH**; FCXP cabecera no creada; IMOV aún `ESTADO=0`; reproceso a medias tras editar IMOVH. |
| **Consulta solo lectura** | FCXP por `CNSFCOM`; FCXPD `N_PRESUP`; IMOVH `ENCXP`. |
| **Acción en app** | 1) Confirmar entrada (**CONF_ENTRADA**). 2) CxP: cabecera **FCXP** (proveedor/factura). 3) **PROCESAR_IMOVH** con `CNSFCXP` + `CNSMOV`. 4) Ver detalle FCXPD en pantalla. |
| **No hacer** | Contabilizar FCXP sin líneas (VALIDAR_FCXP KO). |
| **Escalamiento** | Si PROCESAR_IMOVH KO: mensaje de error completo a L3. |

---

## PC-N3 — KMCOM / CUENTA_SER

| Campo | Contenido |
|-------|-----------|
| **Síntomas usuario** | «Centro de costo no configurado en CXP_COMPRAS»; «cuenta contable no existe»; CONF_ENTRADA no deja confirmar. |
| **Pasos Auditoría** | **Preconfirmación CONF_ENTRADA** (indirecto); **KMCOM en FCXPD (CUENTA_SER)** KO; **Preconfirmación** + mensaje KMCOM en UI. |
| **Causas frecuentes** | Falta fila **KMCOM** `IDTIPOCONT=CXP_COMPRAS` para **PREFIJO=IDITAR** + **CCOSTO** del IMOV; `VALID_CCOSTO_CXP=SI`; CCOSTO del movimiento ≠ CCOSTO parametrizado. |
| **Consulta solo lectura** | IMOV `CCOSTO`, `IDAREA`; ITAR de artículos en IMOVH; KMCOM CXP_COMPRAS; USVGS `VALID_CCOSTO_CXP`. |
| **Acción en app** | Configuración contable: completar **KMCOM** (DB y CR) por ITAR+CCOSTO+área. Reintentar **CONF_ENTRADA** o **PROCESAR_IMOVH**. Opcional: **RECONSTRUIR_CUENTAS_FCXPD** solo si importes ya cuadran (PC-N4). |
| **No hacer** | Usar RECONSTRUIR_CUENTAS_FCXPD como sustituto de KMCOM faltante en parametrización. |
| **Escalamiento** | Contabilidad/cliente define CCOSTO y prefijos ITAR. |

---

## PC-N4 — Reconstrucción equivocada

| Campo | Contenido |
|-------|-----------|
| **Síntomas usuario** | «Reconstruí cuentas pero el valor sigue mal»; «cambié costo en inventario y CxP no cambió». |
| **Paso Auditoría** | **Cuadre IMOVH ↔ FCXPD** KO tras solo reconstruir; valores viejos en FCXPD. |
| **Causas frecuentes** | Usaron **RECONSTRUIR_CUENTAS_FCXPD** cuando debían **PROCESAR_IMOVH**; FCXP ya contabilizada (no deja reprocesar). |
| **Acción en app** | Si **CONTABILIZADA=0**: **PROCESAR_IMOVH** (relee IMOVH). Si **CONTABILIZADA=1**: descontabilizar según política cliente → reprocesar → validar → contabilizar de nuevo. |
| **No hacer** | Editar masivamente FCXPD a mano sin cuadre con IMOVH. |
| **Escalamiento** | L3 si descontabilización bloqueada (abonos, OP, FCXPP). |

---

## PC-N5 — Cuadre valores entrada ≠ CxP

| Campo | Contenido |
|-------|-----------|
| **Síntomas usuario** | «Total CxP distinto al ingreso»; «IVA no cuadra»; auditoría interna rechaza comprobante. |
| **Pasos Auditoría** | **Cuadre IMOVH ↔ FCXPD** KO (Δ base o IVA > 1 peso); **Cuadre FCXP cabecera ↔ detalle** warn. |
| **Causas frecuentes** | IMOVH editado después de PROCESAR; `REDONDEO_COMPRAS_CXP=SI`; **DECONSUMO** en FCOM; líneas excluidas del cursor SPK; flete/anticipo en cabecera FCXP. |
| **Consulta solo lectura** | Sumas IMOVH `PCOSTO*CANTIDAD`, `VLRIVA`; FCXPD `VALOR*CANTIDAD`, `VLR_IVA` por `N_PRESUP`; FCXP `VLR_NETO`, `VLR_IVA`. |
| **Acción en app** | **PROCESAR_IMOVH** de nuevo (FCXP abierta). Comparar totales en pantalla movimiento vs CxP. Si cabecera vs detalle: revisar flete (`VLR_FLETE`) y **SPK_CALCULOVALORESCXP**. |
| **Tolerancia** | ≤ **1 peso** por redondeo (auditoría BA). |
| **Escalamiento** | L3 si tras reprocesar persiste Δ grande (revisar VWK_IMOVH_AGRUPADO / bug MEDICAL782/COESME600 en SPK). |

---

## Matriz rápida (síntoma → PC → acción)

| Síntoma | PC | Primera acción |
|---------|-----|----------------|
| No hay stock | N1 | CONF_ENTRADA / revisar bodega-lote |
| CxP vacía | N2 | PROCESAR_IMOVH |
| Error KMCOM al confirmar | N3 | Parametrizar KMCOM CXP_COMPRAS |
| Reconstruí y sigue mal el valor | N4 | PROCESAR_IMOVH (no solo reconstruir) |
| Totales distintos | N5 | Reprocesar IMOVH + cuadre |

---

## Checklist cierre soporte (listo para usuario)

- [ ] Auditoría: **IEXI vs IMOV confirmado** = OK  
- [ ] **Cuadre IMOVH ↔ FCXPD** = OK (o Δ explicado ≤ 1 peso)  
- [ ] **CUENTA_SER** presente en líneas FCXPD (N3)  
- [ ] Usuario sabe si falta **CONTABILIZAR_FCXP** (PC-07, fuera de N1–N5)  

---

## Escalamiento L3 (datos mínimos)

Enviar: `CNSFCOM`, `ORDENCOMPRA`, `CNSMOV`, `CNSFCXP`, capturas IMOV + CxP, **export JSON/texto traza Auditoría BA**, mensaje KO exacto de CONF_ENTRADA o PROCESAR_IMOVH, versión liberada si se conoce.

**Prohibido en soporte:** `INSERT`/`UPDATE`/`DELETE` directo en IEXI, IMOV, FCXPD, FCXP; ejecutar SPs fuera de la aplicación salvo runbook L3 explícito del cliente.
