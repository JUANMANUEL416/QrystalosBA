# Contabilización entrada de compra

📊

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Compras y contabilización

## Explicación

La entrada de compra confirmada genera movimiento contable de inventario a través del OM (Orden de Movimiento) INV. El SP `SPK_NC_CONTAB_INV` toma el movimiento ESTADO=1, busca cuentas DB/CR en KMCOM (modelo MOV_INVENTARIO) usando IDTIPOMOV como prefijo, CCOSTO del movimiento e ITAR del artículo, y genera el comprobante MCP. La contabilización puede ser inmediata tras confirmar la entrada o diferida a través de la cola IMOVC (si CONTABIMOV_JOB=SI).

## Ideas principales

- **Orden de movimiento inventario**: El operador va a Contabilidad → Conciliaciones contables → OM Inventario; filtra por bodega, tipo de movimiento y rango de fechas; selecciona la entrada 02 confirmada y pulsa Contabilizar.
- **SECONTABILIZA efectivo**: Para que el movimiento contabilice debe cumplir ITMO.SECONTABILIZA=1 AND IBOD.NOCONTABILIZA=0; si no, SPK_NC_CONTAB_INV sale con mensaje «Este movimiento no se contabiliza».
- **Modelo contable MOV_INVENTARIO**: KMCOM debe tener cuentas DB (inventario) y CR (inventario en tránsito o similar) con IDTIPOCONT=MOV_INVENTARIO, PREFIJO=IDTIPOMOV (02, 22, etc.), CCOSTO y opcionalmente ITAR si se segrega por tipo de artículo.
- **Contabilización automática o job**: Con CONTABIMOV_JOB≠SI contabiliza en línea al confirmar entrada; con SI encola en IMOVC y un job periódico procesa los pendientes.
- **Errores comunes**: KMCOM faltante, centro de costo sin cuenta, periodo cerrado (PRI.CERRADO_INV=1 o CERRADO=1 bloqueando), VALID_CCOSTO_CXP=SI exige CCOSTO antes de permitir confirmar entrada.

## Campos decisivos y visibles

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| **ITMO.SECONTABILIZA** | Tipos de movimiento | Si 1, puede contabilizarse; si 0, no |
| **IBOD.NOCONTABILIZA** | Bodegas | Si 1, esa bodega no contabiliza aunque ITMO diga que sí |
| **CONTABIMOV_JOB** | USVGS | SI = encolar IMOVC; ≠SI = contabilizar inmediato |
| **VALID_CCOSTO_CXP** | USVGS | SI = exige CCOSTO antes de confirmar entrada con CxP |
| **IMOV.ESTADO** | Movimientos | 0=pendiente, 1=confirmado (solo 1 contabiliza) |
| **PRI.CERRADO_INV, PRI.CERRADO** | Periodo | Bloquean si 1; debe estar abierto |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| **CONTABIMOV_JOB** | Contabilizar inventario por job | SI / No | SI = encola IMOVC y job procesa; No = contabiliza inmediato al confirmar |
| **VALID_CCOSTO_CXP** | Validar centro de costo en compras CxP | SI / No | SI = exige CCOSTO con KMCOM CXP_COMPRAS antes de confirmar; No = permite sin CCOSTO |
| **CONTAB_INV_IVA_ITAR** | IVA en entrada por tipo de artículo | SI / No | SI = segrega IVA en FCXPD por ITAR; No = IVA consolidado |
| **REDONDEO_COMPRAS_CXP** | Redondeo en compras vs CxP | SI / No | SI = ajusta diferencia centavos IMOVH ↔ FCXPD; No = sin ajuste |
| **IDMODELOCONTABLE** | Modelo contable cliente | 01, 02… | SPK_CONFIRMARSALIDAS hardcodea '01' en validación (riesgo INV-C06) |

## Usuario final

- Contador revisa movimientos confirmados y selecciona cuáles contabilizar desde OM Inventario.
- Farmaceuta/Asistente de compras solo confirma la entrada; la contabilización la hace contabilidad.
- En modo job, el contador verifica la cola IMOVC y ejecuta el job si está atrasado.

## Soporte y desarrollo

### Procedimientos almacenados

**SPK_NC_CONTAB_INV**  
**Propósito:** Genera comprobante MCP de inventario (movimiento entrada/salida).  
**Métodos:** (invocado desde OM INV o job IMOVC)  
**Valida:** SECONTABILIZA efectivo, KMCOM MOV_INVENTARIO con PREFIJO=IDTIPOMOV+CCOSTO, periodo abierto.  
**Qué hace:** Busca cuentas DB/CR, arma MCPE+MCPED por lote/artículo, suma valores, inserta comprobante.  
**Errores:** «Este movimiento no se contabiliza», «No existe cuenta KMCOM», «Periodo cerrado».

**SPK_INSERT_CXP_INV**  
**Propósito:** Crea detalle FCXPD desde entrada compra.  
**Métodos:** (invocado por SPK_CONFIRMARENTRADAS si tipo 02/22/SI con proveedor)  
**Valida:** KMCOM CXP_COMPRAS, IVA según CONTAB_INV_IVA_ITAR.  
**Qué hace:** Por cada línea IMOVH genera FCXPD con base gravable, IVA y total; maneja impuestos múltiples si aplica.

**FNK_NC_CUENTA_KMCOM**  
**Propósito:** Función que devuelve cuenta contable según modelo/prefijo/CCOSTO/ITAR.  
**Métodos:** (usado por SPK_NC_CONTAB_INV)  
**Valida:** Existe fila KMCOM con esos criterios.

### Ejemplos reales

- **Entrada compra 02 contabilizada**: El contador va a OM Inventario, filtra por IMOV 02 (compras) en estado Confirmado, selecciona 10 entradas del día y pulsa Contabilizar; SPK_NC_CONTAB_INV genera 10 comprobantes MCP con DB inventario CR inventario en tránsito; luego el contador va a OM Comprobantes y revisa que los valores cuadren.
- **Entrada bloqueada por KMCOM faltante**: Al confirmar entrada con centro de costo CCOSTO=301 y tipo 02, SPK_CONFIRMARSALIDAS valida que exista KMCOM MOV_INVENTARIO con PREFIJO=02 y CCOSTO=301; si no existe, sale error «No se encontró cuenta contable» y la entrada queda pendiente.
- **Job IMOVC**: Con CONTABIMOV_JOB=SI, al confirmar entrada el sistema encola IMOVC con IDMOV y PROCESO=INV; un job SQL Server ejecuta cada hora un SP que lee IMOVC pendientes, llama SPK_NC_CONTAB_INV por cada uno y marca como procesado.

## Pendiente validar

- ⚠️ Variable IDMODELOCONTABLE en USVGS: SPK_CONFIRMARSALIDAS hardcodea '01'; verificar si el cliente usa modelo distinto y si hay que ajustar el SP (ticket INV-TCK-01).
- ⚠️ Contabilización diferida IMOVC: revisar frecuencia del job y si hay cola atrasada; el SP del job no está en la KB.
