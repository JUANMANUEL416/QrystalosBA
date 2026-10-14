# Reversos — traza auditoría (read-only)

Parámetro:

- **NROCOMPROBANTE** del comprobante de reversión (habitualmente MCPE en estado 0), o
- **`ORIG:`** + NRO del comprobante **origen** (busca el reverso más reciente con `REFERENCIA3` = ese NRO y `PROCEDENCIA` LIKE `REV%`).

Checks: cabecera REV*, enlace origen, cuadre MCH/MCH, conteo líneas `PROCESO=REVERSION`, PRI para ramas REVCAJA.

Fuente SQL: IXONLINE/SQL · `SPK_REVERSAR_MCP`.
