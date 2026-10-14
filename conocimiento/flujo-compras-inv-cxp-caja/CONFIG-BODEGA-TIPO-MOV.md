# Bodega, tipo de movimiento y USVGS (antes de la primera entrada)

Continúa **`CATALOGO-ARTICULO.md`**. Detalle JSON: `catalogo-bodega-tipo-mov.json`.

## Orden recomendado

1. **ITMO** — Tipo **entrada por compras** (`TIPO` = Crédito, `COMPRAS=1`, `GENTRANSITO` acorde al proceso, `SECONTABILIZA` según política).
2. **USVGS** — **`IDINVMOV_COMPRAS`** = ese `IDTIPOMOV` (varchar(2)). Verificar en SQL:

```sql
SELECT IDVARIABLE, DATO FROM dbo.USVGS
WHERE IDVARIABLE IN ('IDINVMOV_COMPRAS','IDINVMOV_PRESTAMOS','VALID_CCOSTO_CXP');
```

3. **IBOD** — Bodega que recibirá la OC: **Activo**, **MUEVEEXISTENCIAS** acorde a operación, **CCOSTO/IDAREA** si `VALID_CCOSTO_CXP=SI`.
4. **IBODS** — Usuarios de recepción con acceso a esa bodega.
5. **FCOM** — Al crear/confirmar OC, **`IDBODEGA`** debe ser la bodega destino (misma que terminará en `IMOV.IDBODEGA`).

## Regla de contabilización efectiva

En **`SPK_NC_CONTAB_INV`**:

`SECONTABILIZA_EFECTIVO = 0` si **`IBOD.NOCONTABILIZA = 1`**, aunque **`ITMO.SECONTABILIZA = 1`**.

| Expectativa | ITMO | IBOD |
|-------------|------|------|
| Entrada compra contabiliza en OM INV | SECONTABILIZA=1 | NOCONTABILIZA=0 |
| Bodega auxiliar / no contable | (cualquiera) | NOCONTABILIZA=1 |
| Solo costo en CxP, no INV | SECONTABILIZA=0 | — |

## Dónde se usa IDINVMOV_COMPRAS

| Punto | Comportamiento |
|-------|----------------|
| `SPK_INSERT_ITRA_REQ` | `@IDTIPOMOV` desde USVGS al confirmar OC |
| `SPK_INSERTENTTRANSITO` | Cabecera IMOV; ramas factura/CUFE solo compras |
| `SPQ_IZSOL_TRANSITO` | `ESCOMPRA` vs `NOESCOMPRA`; edición precios si `TRAN_EDIT_OC=SI` |
| `SPQ_IMOV_3` | Sincronización CUFE/plantillas masivas (solo tipo compras + CNSFCOM) |

## Préstamos

Si **`FCOM.IDTIPOSER = 'Presta'`**, `SPK_INSERT_ITRA_REQ` usa **`IDINVMOV_PRESTAMOS`** en lugar de compras. Debe existir ITMO equivalente y variable USVGS.

## Auditoría BA

Al trazar una OC, el paso **«Bodega y tipo movimiento (OC)»** contrasta `FCOM.IDBODEGA` con `IBOD`, `USVGS.IDINVMOV_COMPRAS` con `ITMO` y calcula **SECONTABILIZA efectivo**.

## Siguiente eslabón

**Confirmación y primera recepción:** **`OC-CONFIRMACION-RECEPCION.md`** (`CONFIRMAR_ORDEN`, estados P/R/I, ITRA, caminos a IMOV).
