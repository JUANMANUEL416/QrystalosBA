# Proceso: Contabilidad

**Estado:** documentado (capa 3 alimentadores + Fase 1 grafo)  
**Módulo:** MCP_COL  
**Ventanas:** `/cont/mcp`, `/cont/mcpe`

> MCUE no está en INDICE_TABLAS. No inventar. El cuerpo de los SP se lee de DESAIX o de la copia local `sql/`/`sql_refe/` (fuera de git); aquí solo queda el nombre del SP, sus métodos y validaciones (cita `SP:línea`).

## Capas

1. Configuración
2. Proceso propio
3. Lo que llega y completa
4. Subproceso unido
5. Envío a contabilidad

## Cómo se va completando

La contabilización se documenta en la capa 3 de `proceso.json`: un control por procedencia (`proc-*`). Cada hallazgo (error, documento, corrección, caso) se anota ahí. El METODO de pantalla sigue en el proceso hermano (inventario, CxP, caja, facturación, etc.).

**Fase 1 grafo (cerrada 2026-10-13):** las 19 procedencias MCP tienen cadena inversa N4→N0 en `grafo-contabilizacion/` — ver **`FASE-1-GRAFO-CONTABILIZACION.md`** e índice `grafo-contabilizacion-indice.json`. Los generadores releídos para nómina, cesiones, legalización, IACT, radicación `_1`, CONCI y AJDEP están en `sql/` (PREVERSION). Auditoría BA valida `requires[]` (véase `grafo-contabilizacion/VALIDACION-SQL-INDICE.json`).

**Fase 2 (pendiente):** cierre/apertura PRI, informes, arrastre de saldos — no sustituye los grafos alimentadores.

## Del comprobante errado al origen

Pantalla: Contabilidad → Comprobantes errados (`/cont/mcpe`). El detalle vive en el control `mcpe-flujo-invertido` de `proceso.json`.

El texto de la línea lo escribe `SPK_REVISAR_COMPROBANTE`: cuenta inexistente, cuenta que no es de detalle, valor cero, valor negativo o tercero inexistente. La cabecera dice de qué módulo vino (`PROCEDENCIA`) y qué documento hay que abrir (`REFERENCIA1`, `REFERENCIA2`, `NOREFERENCIA`, sede).

Reconstruir vuelve a ejecutar el procedimiento de esa procedencia. La corrección va en el documento origen; después Revisar y Reconstruir.

En CEM, las familias ya dictaminadas son la dispensación tipo 06 sin centro de costo, el duplicado de referencia entre sedes al reconstruir, y el tercero que no es afiliado y tumba la categoría. El impuesto al consumo de CxP puede quedar en el libro y no en errados.


## Libro 2026-10-04 (notas internas)

- Menú real: USPROH/USGRUH con IDPROCEDIMIENTO = MENUQ_CONTABLE es dato de instalación (no está en SQLIX de DESAIX). El libro documenta por el árbol fijo de ContableLayout.arbolMenu; rutas del árbol sin router: proviCartera, LibrosOficiales, AuxiliarBancos (dup), agrupacionCuentas, procesosNiff, balanceApertura, librosOficiales.
- SQL leído este día: SPK_REVISAR_COMPROBANTE, SPK_SUMA_DBCR, SPK_NC_CONFIRMAR_CONTAB, SPK_PASA_A_MCPE, SPK_NC_REVISAMCPE, SPK_NC_BALANCEO_CENTAVOS, SPK_DIAG_MCPE_ERRORES, SPQ_CONTA_LIQIMP + SPK_GEN_CXP_LIQIMP + VWK_LIQ_IMP(_1), SPQ_FOLIAR_LB, SPQ_MOV_ACTIVOS, SPQ_TER_EQUIV_EFECTIVO, SPQ_EXOFMT, SPK_HOMOLOGA_TERCERO/CUENTA, SPK_NC_CONTAB_CASTIGO_CARTERA, SPK_REVERSAR_MCP, SPK_CIERRA/ABRE_PERIODOCONTABLE, SPK_CIERRE_FISCAL, SPK_GEN_COMP_CIERRE_FISCAL, FNK_REVISION_ANTES_CIERRE_PERIODO. Todos PREVERSION = 2.0.7 (IDANT 2.0.6).
- Hallazgos (17, ids conta-* en proceso.json y pendientes.json): métodos invocados por el FE que no existen (ACTUALIZAR_MARCACONT, CXC_FCXC_RESET_CONTABILIZADO, CONSULTAR_PERIODOS_CIERRE); ACTIVOS_MOV y HPRE marcan pero no contabilizan; FNK_REVISION compara YEAR(F_NOTA) con el mes; rama 'NOTAS' muerta en REVISAMCPE; liquidación cierra CERRADO_IMP para todo el periodo aunque el rango de cuentas sea parcial, CUECREDITO NULL y F_VENCE día 1; ruta liqImp duplicada; Foliar libros «en desarrollo»; PAR con dos procedimientos; centavos ajustados sin rastro; duplicado descartado sin aviso; terceros creados en silencio desde AFI; HAVING de VWK_LIQ_IMP comentado; componentes BACKUP y console.log en producción.
