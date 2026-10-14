# Proceso: Radicaciones · Cuentas médicas

**Estado:** parcial  
**Módulo:** RLOT_LOTE

Lote Excel → `RLOT`/`RLOTD` (Sin Tramitar) → activar (`ESTADO_LOTE=1`) → asignar el siguiente Sin Tramitar (prioridad). Calidad y RFIN son satélites. RFIN no es Recaudos.

Hallazgo: en `CRUDRLOT` el KO «ID de asignación ya existe» no corre (`AND 1=2`).
