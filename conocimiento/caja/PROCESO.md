# Proceso: Caja

**Estado:** parcial  
**Módulo:** CJA · Administrativo → Caja (`admin.caja`) y Procesos de caja (`admin.procaja`)

> Flujo tomado de Qrystalos2 y de `sql_refe/0100015121/SPQ_CONF_CAJA.sql`. Los SP se bajan a `sql/` el día del análisis. No copiar cuerpos aquí.

## Procedimientos

Catálogo en `sps.json` (Consultas → pestaña **Procedimientos**). Formato por método: hace / valida / noValida / errores KO / llama / efecto. Se completa al leer el `.sql`; no se copia el cuerpo.

Hoy: `SPQ_CONF_CAJA` (métodos de abrir, confirmar, CRUDFPA, contabilización masiva **leídos**; el resto **listados**). `SPQ_CONF_CAJA_2` y los SPK de apertura/cierre/banco/contab: **no leídos**. Impresión de recibo: `SPQ_CAJA_RPT` / `IMPRIMIR_RECIBO_FCJ` (el PDF lo arma el FE).

## Orquestadores

| MODELO FE | SPQ | Para qué |
|-----------|-----|----------|
| `CONF_CAJA` | `SPQ_CONF_CAJA` (+ `ELSE` → `SPQ_CONF_CAJA_2`) | Abrir, armar, confirmar, anular, contabilizar |
| `CAJA_RPT` | `SPQ_CAJA_RPT` | Reportes / PDF de procaja |
| `CAJ_COL` | `SPQ_CAJ_COL` | CRUD catálogo CAJ |

## Capas

### 1. Configuración

Pantallas: `conf.caj` (CAJ), `conf.cpcj` (CPCJ), `conf.fpa` (FPA), `conf.caja` (CAJ + CJR). Turnos `CXT`+`TUR`. Equipo `UBEQ.ESCAJA`. Variable `IDCJAPERTURACAJA` ∈ CPCJ.

### 2. Proceso propio

1. Entrar: `VALIDA_INGRESO_PANTALLA`.
2. Abrir: `ABRIR_CAJA` → `SPK_APERTURA_DE_CAJA`.
3. Armar recibo: `INSERTA_RECIBO` / `INSERTA_FCJD` (**en CONF_CAJA_2**) + `CRUDFPA`.
4. Confirmar ingreso: `CONFIRMAR_RECIBO` → `SPK_CIERRERECIBO_CAJA` + `SPK_ACTUALIZA_SALDO_BANCO` + `SPK_NC_CONTAB_CAJA_ING`.
5. Cerrar turno: `CERRAR_CAJA` → `SPK_CIERRE_DE_CAJA` (o reembolso caja menor).

**Hueco:** confirmar **no** exige `FCJD.CONCEPTO` ∈ `CPCJ` (salvo no usar el de apertura). El error sale en el SPK contable.

### 3. Alimentadores

Agenda, autorizador, venta farmacia, CxP/OP, recaudo Perú: mismo `CONF_CAJA` / `CRUDFPA` con procedencia CITAS, CE, etc.

### 4. Bancos

`SPK_ACTUALIZA_SALDO_BANCO` al confirmar ingreso. Reporte Flujo de caja = `CAJA_RPT`, no el movimiento.

### 5. Contabilidad

Al confirmar (SPK NC contab) y masivo en procaja: `ENVIAR_RECIBOS_CONTABILIDAD` → `SPK_CONTAB_MASIVA`. Cuenta desde `CPCJ.CUENTA`.
