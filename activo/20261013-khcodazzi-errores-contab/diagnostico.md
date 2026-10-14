# KHCODAZZI — Diagnóstico errores contables (read-only)

**Servidor:** `servidorHcodazzi` · **BD:** KHCODAZZI · **Fecha levantamiento:** 2026-10-13

## Resumen ejecutivo

| Métrica | Valor |
|--------|------:|
| Comprobantes en **MCPE** (estado error) | **16** |
| Líneas **MCHE** con texto de error | **34** |
| Procedencias afectadas | INV (10), CONCI (3), FACTURA (2), CXC (1) |

El “~50” puede corresponder a líneas erradas + pendientes **FNK** pre-cierre + comprobantes sin detalle; no hay 50 cabeceras distintas en MCPE hoy.

## Causa dominante (definitiva)

**Mensaje:** `La Cuenta NO Existe.` en líneas con cuenta literal **`NO DEF.KMCOM`**.

No es que falte la cuenta en el PUC (**CUE**): el motor **no encontró fila en KMCOM** (`FNK_CUENTA_KMCOM`) para la combinación modelo + concepto + tipo movimiento + área + centro de costo.

**Ejemplo verificado (INV):**

- Movimiento `0100105628` · tipo `05` (salida consumo) · **IDAREA `5105`** · **CCOSTO `119`**
- En **KMCOM** (`IDMODELOCONT=01`, `MOV_INVENTARIO`, `PREFIJO=05`) existen áreas 4105/4110/4115… pero **no 5105 + 119** → `NO DEF.KMCOM`.

## Por procedencia

### INV (10 comprobantes, 24 líneas erradas)

- Acción: completar matriz **KMCOM** `MOV_INVENTARIO` (DB/CR) para cada **IDTIPOMOV (PREFIJO)** + **IDAREA** + **CCOSTO** usados en los IMOV fallidos (prioridad área **5105** y CC **119**).
- Tras parametrizar: **Comprobantes errados → Reconstruir** (o reenviar desde inventario) por cada `NROCOMPROBANTE` / `CNSMOV` (REFERENCIA1).

### CONCI (3 comprobantes)

- Líneas de diagnóstico en MCHE (`PROCESO: CONC_GLOSAS`) con cuenta vacía → **KMCOM conciliación/glosas** incompleto (no hay filas `IDTIPOCONT` CONC/GLO en modelo 01).
- Una línea usa cuenta `89151701` (sí existe en CUE); revisar si el error real es otra regla en líneas adyacentes del mismo comprobante.

### FACTURA (2)

- `0111000000181843` (oct-2026): 148 líneas MCHE, **1** con error cuenta — revisar línea puntual tras KMCOM facturación.
- `0113100000148635` (may-2026): **MCPE sin MCHE**, totales 0, **ANULADO=1** — basura/histórico: limpiar desde errados (revisar/anular definitivo) o soporte L3.

### CXC (1)

- `0185000000173551`: **MCPE sin MCHE**, totales 0 — intento fallido recaudo; reconstruir desde FPAG o eliminar cabecera huérfana según política.

## Pre-cierre FNK (periodo abierto oct-2026)

| Módulo | Hallazgo |
|--------|----------|
| CIERRE | Sub-cierre **CARTERA** y **CXP** pendientes en PRI |
| CONCILIACIONES | Conciliación `0100000078` sin contabilizar |
| CXP | `01CM000609` pendiente contabilizar |
| CXP DBCR | 2 notas pendientes |

## Configuración a corregir (preventivo)

| Variable / tabla | Estado | Riesgo futuro |
|------------------|--------|----------------|
| **KMCOM** INV `5105`/`119`/tipo `05` | Falta | Nuevas salidas mismo CC seguirán fallando |
| **KMCOM** CONCI / `CONC_GLOSAS` | Falta o incompleto | Glosas/conciliaciones no contabilizan |
| **IDCON_TCOM_DEPR** | Vacío | Depreciación **AJDEP** puede fallar al generar comprobante |
| **PRI** | Meses 5–10 abiertos contablemente | Secuencia cierre; no cerrar saltando meses |
| **MCPE huérfanos** | 2 cabeceras sin detalle | Ensucian panel “Comprobantes errados” |

## Pasos recomendados (orden)

1. **Inventario de combinaciones:** extraer DISTINCT `IDTIPOMOV, IDAREA, CCOSTO` de IMOV ligados a los 10 MCP errados (REFERENCIA1 = CNSMOV).
2. **Parametrización:** Contabilidad → modelo **01** → **KMCOM** — replicar patrón de áreas 41xx para área **5105** (y demás faltantes).
3. **Conciliaciones:** parametrizar KMCOM proceso **CONC_GLOSAS** (misma lógica que SPK contab conciliación).
4. **Reprocesar:** MCPE errados INV/CONCI/FACTURA — **Reconstruir** tras KMCOM; huérfanos FACTURA/CXC — decisión anular/eliminar o regenerar desde documento.
5. **Operación:** contabilizar CxP `01CM000609`, conciliación `0100000078`, notas CXP DBCR; sub-cierres cartera/CxP en PRI.
6. **Cierre:** cuando MCPE=0 y FNK limpio, **VALIDAR_PERIODO_BASICO → integridad → cierre** mes a mes desde el más antiguo abierto (may-2026 en adelante).
7. **Completar** `IDCON_TCOM_DEPR` antes de corrida depreciación.

## Conexión en Qrystalos BA

Usar en Consultas/Auditoría: servidor **`servidorHcodazzi`**, base **`KHCODAZZI`** (credencial ya en `.env.local` — no publicar clave en tickets).
