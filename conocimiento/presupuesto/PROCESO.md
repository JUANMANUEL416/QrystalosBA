# Proceso: Presupuesto

**Estado:** parcial (SPQ + envío nómina/PAC leídos; CRUDPTNOT no desarrollado; REQ 6310 es Analista)  
**Módulo:** PTPTO · `/ppto`

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se documenten.

## Resumen

Presupuesto web (Qrystalos2, `PresupuestoLayout`). Dos cadenas operativas:

1. **Ingresos:** reconocimientos → recaudos / notas.
2. **Gastos:** CDP → registro presupuestal (RP) → obligación (CxP) → pago.

Configuración: rubros, recursos, clasificaciones, tipos de movimiento, divisiones, contratos, nómina PPTO y periodos (PRI).

**Hueco de menú (REQ 0100016310):** «Seguimiento Gastos» y Históricos → «Seguimiento Gasto» abren `EnConstruccionPage`. El componente de seguimiento ya existe y se usa en «Seguimiento CDP, CxP y Pagos».

También en construcción: Históricos → Cierre, Seguimiento Reconocimientos, Seguimiento Recaudos.

## Procedimientos (`sps.json`)

Catálogo en `sps.json` (**leído** salvo `CRUDPTNOT` y `PRESUPUESTO_FCXC`). Scripts en `sql/`.

| SPQ | MODELO FE | METODOs |
|---|---|---|
| SPQ_PRESUPUESTO | PRESUPUESTO | Maestros, PTPTO/DG, CAMBIAR_ESTADO_PPTO, CRUDNPER/NCOND/NPLTCO, CRUDPLN, ENVIAR, HELPER, COPIAR_RUBROS |
| SPQ_PPTO_PTCDP | PPTO_PTCDP | CRUDPTCDP/D … CRUDPTPAG/D |
| SPQ_PPTO_RECO | PPTO_RECO | RECO, RECA, PTMOV, PTRES. **CRUDPTNOT no desarrollado** |
| SPQ_PPTO_REP | PPTO_REP | TRAER_FACTURA_PPTO, PRESUPUESTO_FPAG, PRESUPUESTO_FNOT, EXPORT_* |

Confirmar el nombre real del SPQ al bajar el script (el MODELO del JSON es el lógico).

## Capas

### 1. Configuración

Parametrizar rubros/recursos/tipos y periodo presupuestal abierto.

**Invariante:** no afirmada (falta .sql).

### 2. Proceso propio

Usuario abre PTPTO, opera ingresos o arma CDP y confirma/anula/desconfirma eslabones.

**Controles:** maestro-ptpto · cadena-gastos · cadena-ingresos · seguimiento-gastos.

### 3. Lo que llega

Facturación, recaudos y anticipos CxP se «traen» a presupuesto.

### 4. Subproceso unido

PTCXP vs CxP operativa — pendiente de SP.

### 5. Envío a contabilidad

Sin evidencia FE de asiento. No inventar.

## Pendiente

- [ ] `SPQ_PPTO_PTCDP.sql` en `sql/` → fichar CRUD* (prioridad: Documentar + REQ 6310).
- [ ] `SPQ_PRESUPUESTO.sql` → maestros + CAMBIAR_ESTADO_PPTO.
- [ ] `SPQ_PPTO_RECO.sql` + SPK_APLICA_NOTA_PPTO.
- [ ] `SPQ_PPTO_REP.sql` / INFORMES_PPTO.
- [ ] Confirmar SPQ de CRUDPTPTO.
- [ ] Cierre histórico (menú en construcción).
