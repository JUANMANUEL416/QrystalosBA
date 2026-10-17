# Borrador temporal — SPK_RIPS_JSON_FTR_MAS

Fuente: IXONLINE/SQL **PREVERSION** (no se ejecutó en CEM).
Caso CEM de prueba: factura **FV60187** / CNSFCT **0600061157**.

## Regla añadida

Si `FTR.PAQUETE=1` y `PPT.PAQUETIZADO=0` (`@RUTA_VALOR_FTRD=1`):
incluir líneas FTRD con **valor** y/o **`PAQUETE=0`**.
No incluir hijas `PAQUETE=2` en 0.

En FV60187 debe salir **otrosServicios** `603900_2` = 1.356.499 (ítem 99).

Pendiente: pedir el requerimiento formal y pasar este `.sql` a `activo/{id}/sql/`.
