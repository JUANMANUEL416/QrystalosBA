# Orden de compra

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 4

## Explicación

CONFIRMAR_ORDEN: C→P, ORDENCOMPRA++, ITRA/ITRAH. Ver OC-CONFIRMACION-RECEPCION.md (PC-02…PC-02c).

## En Qrystalos

**Ruta:** `/inv/ordcom`
**Componente:** FComComponent
**Modelo:** FCOM
**Métodos:** `GENERA_OC`, `CONFIRMAR_ORDEN`, `RECEPCION_MASIVA`, `RECEPCION_PARCIAL_OC`, `ABRIR`

## Tablas

`FCOM`, `FCOMD`

## Procedimientos almacenados

`SPQ_FCOM`, `SPK_INSERT_ITRA_REQ`
