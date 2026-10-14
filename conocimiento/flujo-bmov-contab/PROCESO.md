# Movimiento banco — traza auditoría

Parámetro: **BANCO/SUCURSAL/CTA_BCO/ITEM** (alternativa **REFERENCIA1/ITEM** como en MCP BMOV).

Valida ESTADO=O, BMOVD, BCT→CUE, OFIN, PRI, duplicidad MCP. Si hay líneas **RECAUDO=1**, lista FPAG activos (puente a recaudos CXC).

SQL: IXONLINE/SQL · `SPK_NC_CONTAB_BMOV`.
