# Cierre periodo — traza Fase 2 (read-only)

Parámetro opcional: **ANO-MES** o **ANO/MES**. Si se deja vacío, el motor toma el **último periodo con PRI.CERRADO=0** (o el más reciente en PRI).

## Orden de profundización (motor)

### 1. Integridad paso 2 (extra FNK)

Después de `precierre-fnk` (FNK en BD):

- **`int-notdbcrcxp-mcp-duplicado`:** más de un MCP vigente (`ANULADO=0`) con `PROCEDENCIA=NOTDBCRCXP` para el mismo `REFERENCIA1/REFERENCIA2` (CNSFCXP/ítem) en el mes por **FECHACONTABLE** — criterio REQ cierre (FNK liberada no siempre lo detecta por ítem).
- **`int-mcp-cuenta-no-detalle`:** comprobantes confirmados con líneas en cuentas que no son tipo **Detalle** (módulo CONTABILIDAD de FNK).

### 2. Libros / informes (USCXS)

Al final del barrido:

- **`libros-uscxs-registros`:** prefijos y consecutivos en **USCXS**.
- **`libros-uscxs-seis-tipos`:** cobertura de los seis libros (patrón LBGR, LBPR, LDIA, LEST, LINV, LMAY en `PREFIJO`), alineado a `SPQ_FOLIAR_LB · INICIALIZAR_LIBROS`.

No valida jobs async de libros auxiliares ni exógena.

### 3. OBTENER periodo a cerrar / secuencia PRI

Tras **PRI foco** y sub-cierre cartera:

- **`opc-si-existe`**, **`opc-si-abierto-con-posteriores-cerrados`**
- **`opc-periodo-calculado-vs-foco`:** primer periodo abierto (SI o operativo) vs periodo auditado
- **`opc-secuencia-posterior-cerrado`:** mes foco abierto con posteriores ya `CERRADO=1`
- **`opc-periodo-anterior-cerrado`:** mes anterior con `CERRADO=1` (salvo foco SI)
- **`opc-cierre-fiscal`:** `PAR.MESDECIERRE` vs `PRI.CIERREFISCAL`

Réplica read-only de reglas de **CONTABILIDAD_2 · OBTENER_PERIODO_A_CERRAR** (sin cursor fiscal completo ni traslado duplicado — traslado en paso 1 VPB).

## Resto de checks Fase 2

- Contexto TOP 24 PRI  
- **Periodo foco:** CERRADO, CERRADO_CARTERA, INV/FAC/IMP, SI  
- **MCPE** estado 0 en el periodo  
- **Validar periodo básico (paso 1):** VPB (FECHAMOV, SI único, MCP ANOMES, MCPE≠NIIF, traslado costos)  
- **SALDOMES**, **SALDOMESTER**, **SALDOMESTERFAC**  
- **Pre-cierre módulos** + FNK + MCP sin confirmar  
- **PRI** periodo siguiente  

Equivalente a **Validar configuración** con procedencia **Fase 2 — cierre periodo**.

## Escalón informes / paso 2 FNK

- **`int-fnk-validar-integridad`:** SELECT a `FNK_REVISION_ANTES_CIERRE_PERIODO` con hasta 25 filas (MODULO, REFERENCIA, ERROR) — equivalente read-only a **VALIDAR_INTEGRIDAD_PERIODO** paso 2.
- **`int-fnk-validar-integridad-sin-fiscal`:** conteo con filtro `EXCLUIR_CIERRE_FISCAL` (comparar vs total).
- **`int-notdbcr-mcp-duplicado`:** MCP `NOTDBCR` duplicados por CNSFNOT/CLASE (CxC), mismo criterio vigente/FECHACONTABLE que NOTDBCRCXP.
- **`tbalanceh-fotos-mes`:** fotos **BPRUEBA** / **ESTRES** en el periodo; warn si mes cerrado sin BPRUEBA.
- **`tbalanceh-foto-anual`:** si mes=12, revisa **MES=13** (foto del año).

## Orden del cierre (grafo, 2026-10-14)

N0 obtener periodo → N1 cerrar cartera ∥ N1 cerrar CxP (SPK_CIERRA_CARTERA; prerrequisitos) → N2 validar periodo (reporta cartera/CxP sin cerrar) → N3 pre-cierre FNK → N4 integridad paso 2 → N5 cierre contable → N6 crear periodo (manual SPQ_PRI·CRUDPRI / automático SPK_PRI) → N7 saldos y periodo siguiente · N8 libros/foliado (SPQ_FOLIAR_LB + SPQ_GENSEQUENCE con SEQUENCE) y fotos TBALANCEH. Confirmado con el usuario el 2026-10-14. Evidencia en `evidenciaOrden`. Validar: `python scripts/validar_grafos.py`.

Grafo: `grafo-cierre-periodo.json`. No ejecuta SP de cierre ni METODOs CONTABILIDAD_2 en API.
