# Proceso: Auditoría · Factura

**Estado:** parcial  
**Módulo:** ENT_COL

`RECIBIR_AUDIFACTU` recibe el envío y, si es FACTURAS, mueve `FTR` a la dependencia `IDFDEPAUDITORIA`. Pendientes de factura (`RPT_PENDIENTES_FACT`) lista cargos **no facturados** (`VWK_CARGOS_HADMAUTCIT`), no ENT.

`CREARCXC_ENT` (mismo SP) arma cuenta de cobro: es puente a cartera, no a esta pantalla.
