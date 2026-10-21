# Confirmar entrada inventario

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 8

## Explicación

CONF_ENTRADA valida costo/factura/KMCOM; SPK sube IEXI y FCOM R/I. CONF-ENTRADA-CXP.md · PC-04/PC-04b.

## En Qrystalos

**Ruta:** `/inv/ges`
**Componente:** IMOVComponetNew
**Modelo:** IZSOL
**Métodos:** `CONF_ENTRADA`, `ANULAR_ENTRADA`

## Tablas

`IMOV`, `IMOVH`, `IEXI`

## Procedimientos almacenados

`SPQ_IZSOL`, `SPK_CONFIRMARENTRADAS`, `SPK_FCOM_RECALCULA_RECEPCION`
