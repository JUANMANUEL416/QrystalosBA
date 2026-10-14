# Proceso: Radicaciones · Incapacidades / PILA

**Estado:** parcial  
**Módulo:** INC_LOTE · PILA_CARGA · INC_CREDENCIAL

Semáforo INCA (constantes del SP): 1 interno, 2 externo, 3 revisión, 4 devuelto, 5 subsanado, **6 validado (motor)**, 7 radicado, 8 pte. rechazo, 12 definitivo, 13 recurrible, **9 aprobada**, **10 pagada**.

PILA no crea INCA. **PAGAR_INCA** no genera CxP ni MCP. **LIMPIAR_TABLAS** borra operación INC/PILA sin confirmación.

Tablas operativas (`INCA`, `INC_*`, `PILA_*`) no están en `INDICE_TABLAS` viva.
