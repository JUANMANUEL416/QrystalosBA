# Cotización de compras

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 3

## Explicación

GENERAR_OC: una FCOM por proveedor; FCOM PROCEDENCIA=ILPRE; luego CONFIRMAR_ORDEN en ordcom.

## En Qrystalos

**Ruta:** `/inv/cotizacion`
**Componente:** CotizacionComponent
**Modelo:** ILPRE
**Métodos:** `GENERAR_OC`

## Tablas

`ICTZ`, `ICTZD`

## Procedimientos almacenados

`SPQ_ILPRE`
