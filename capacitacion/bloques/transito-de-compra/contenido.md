# Tránsito de compra

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 5

## Explicación

Recepción crea o alimenta ITRA ligado a CNSFCOM. ITRAH INICIAL=0 pendiente de loteo o INICIAL=1 si viene de Excel/masiva.

## En Qrystalos

**Ruta:** `/inv/ordcom`
**Componente:** FComComponent recepción
**Modelo:** FCOM
**Métodos:** `RECEPCION_MASIVA`, `RECEPCION_PARCIAL_OC`

## Tablas

`ITRA`, `ITRAH`, `MOV_TRAN`

## Procedimientos almacenados

`SPQ_FCOM_RECEPCION_MASIVA`, `SPK_INSERT_ITRA_REQ`
