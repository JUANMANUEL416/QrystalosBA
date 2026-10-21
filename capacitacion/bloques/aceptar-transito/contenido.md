# Aceptar tránsito

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 7

## Explicación

Valida causas sin loteo e ITRAH INICIAL=1 con NOLOTE. Recepción masiva puede saltar UI y llamar SPK_INSERTENTTRANSITO en SPQ_FCOM_RECEPCION_MASIVA.

## En Qrystalos

**Ruta:** `/inv/ges`
**Componente:** IMOVComponetNew
**Modelo:** IZSOL
**Métodos:** `ON_ACEPTA_TRANSITO`, `CANCELAR_TRANSITO`

## Tablas

`ITRA`, `ITRAH`, `IMOV`, `IMOVH`

## Procedimientos almacenados

`SPQ_IZSOL`, `SPK_INSERTENTTRANSITO`
