# Loteo en tránsito

## Contexto

**Proceso:** Flujo compras · inventario · CxP · caja · contabilidad
**Orden:** 6

## Explicación

MLOTEO en ITAR. IZSOL.GUARDA_INV/GUARDA_CUM en flujos especiales. Hemoderivados: TRANSFUSIONAL. Con INV_CUFE_LOTEO = SI y factura, el CUFE queda en ITRA y lo loteado debe igualar el XML; el IVA del ítem sale de la orden. Remisión no usa ese control. La recepción masiva aún no cruza cada OC con su factura.

## En Qrystalos

**Ruta:** `/inv/ges`
**Componente:** IMOVComponetNew → TraerTransitoTempComponent
**Modelo:** IZSOL_TRANSITO
**Métodos:** `LEER_CUFE_LOTEO`, `BUSCAR_RADIAN_LOTEO`, `GUARDAR_CUFE_LOTEO`, `VALIDA_TRAN`, `SEL_RPDX`, `AGREGAR_IART`, `ON_PROCESAR`, `ON_ELIMINAR`

## Tablas

`ITRAH`, `MOV_TRAN`, `RPDX`, `IART`, `FRADIAN`

## Procedimientos almacenados

`SPQ_IZSOL_TRANSITO`
