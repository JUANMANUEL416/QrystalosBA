# Proceso: Glosas (recaudo → auditoría)

**Estado:** esqueleto  
**Módulo:** CAR / AUD

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

## Resumen

Cartera registra glosas en Administrativo → Recaudos (`FPAG` / `FPAGD`, motivos `MOTIVO1` y `MOTIVO2`). Al aplicar el recaudo nace la glosa (`FGLO`). Auditoría responde en Auditoría → Glosas → Responder, leyendo los motivos en `FGLOCG` (`TRAE_MOTIGLO`).

Este REQ cubre el puente: que esos motivos de cartera queden en `FGLOCG` y se vean al contestar. El resto de capas queda incompleto.

## Procedimientos (`sps.json`)

Leídos hoy (sql/): `SPQ_FPAG_COL` (métodos del puente) y `SPQ_FGLO_COL` (`TRAE_MOTIGLO`, `CRUD_FGLOCG`, validación de suma en `CRUD_FGLO`).

Faltan cuerpos: `SPK_PAGOSCXC`, `SPK_CARGA_MASIVA_FAC_CXC_02` (y, si aplica, `SPK_FINALIDAD_GLOSAS`).

## Capas

### 1. Configuración

Catálogo `FCGLO` (códigos de glosa, clase GLOSA, estado ACTIVO). Variables `IDFDEPCARTERA` / `IDFDEPAUDITORIA` para el envío.

**Invariante:** un motivo en `FGLOCG.CNSFCGLO` debe existir en `FCGLO`.

### 2. Proceso propio

Auditoría: recepción → responder (motivos `FGLOCG` + detalle `FGLOD`) → aplicar respuesta.

**Invariante (vista hoy):** al responder tipo T, la suma de `FGLOCG.VALOR` debe igualar `FGLO.VLRGLOSA`.

### 3. Lo que llega y completa

Recaudo (cartera) alimenta la glosa. **Gate de este REQ.**

### 4. Subproceso unido

Entrega cartera → auditoría (`ENVIAR_AUDIT` → `ENT`/`ENTD`).

### 5. Envío a contabilidad

Fuera de este REQ (`solicitud.contabilidad.afecta` = false). No leído.

## Pendiente

- [ ] Bajar `SPK_PAGOSCXC` y `SPK_CARGA_MASIVA_FAC_CXC_02` a `sql/`.
- [ ] Completar capas 1, 2, 4 y 5 en un valle (Documentar).
