# Radicación CxC — traza auditoría (read-only)

Parámetro: **CNSCXC** (cuenta de cobro en FCXC). La traza valida radicación recibida, detalle FCXCD, sugiere generador (`SPK_CONTAB_RADICACXC` vs `_1`) según abonos/notas en facturas incluidas, y aplica checks del grafo N3 (MCP FACTURA previo, PRI, duplicidad MCP RAD CXC).

Fuente SQL: IXONLINE/SQL · `SPK_CONTAB_RADICACXC`, `SPK_CONTAB_RADICACXC_1`.
