# 📊 Comprobante contable (MCP)

## Contexto

**Proceso:** Contabilidad  
**Capa:** 02 - Operación

El **comprobante contable** (`MCP` cabecera, `MCH` líneas) es el registro del asiento contable en el libro mayor. Todo movimiento financiero de la IPS (facturación, pagos, recaudos, compras, nómina, ajustes) debe tener un comprobante que respalde la afectación contable. Los comprobantes nacen en **borrador** (`CONFIRMADO=0`), se revisan y se **confirman** (`CONFIRMADO=1`). Los que vienen de otros módulos (facturación, caja, CxP) entran primero a **Comprobantes Errados** (`MCPE`/`MCHE`) si tienen errores de cuadre o configuración; solo pasan a `MCP` cuando se corrigen.

## Explicación

**Creación de comprobante:**
1. **Manual:** el contador abre Contabilidad → Movimiento Diario → Nuevo Comprobante, selecciona el tipo (egreso, ingreso, ajuste), la fecha, el concepto y agrega las líneas con débitos y créditos.
2. **Automático:** otros módulos generan comprobantes automáticamente:
   - Facturación → al contabilizar una factura (`SPK_NC_CONTAB_FTR`).
   - Caja → al confirmar un recibo o egreso (`SPK_NC_CONTAB_CAJA_ING` / `SPK_NC_CONTAB_CAJA_EGR`).
   - CxP → al contabilizar una cuenta por pagar (`SPK_NC_CONTAB_CXP`).
   - Bancos → al registrar un movimiento bancario (`SPK_NC_CONTAB_BMOV`).

**Líneas del comprobante (`MCH`):**
- Cada línea tiene: cuenta contable (`IDCUE`), tercero (`IDTER`), centro de costo (`IDCCOSTO`), débito, crédito, concepto.
- **Validación de cuadre:** suma de débitos = suma de créditos. Si no cuadra, el comprobante no se puede confirmar.

**Estados:**
- **Borrador** (`CONFIRMADO=0`): editable; no afecta el balance.
- **Confirmado** (`CONFIRMADO=1`): bloqueado; afecta el balance; solo se puede anular o reversar.

**Periodo contable:**
- El comprobante debe tener fecha dentro de un periodo contable **abierto** (`PRI.CERRADO=0`).
- Si el periodo está cerrado, no se puede crear ni confirmar comprobantes en ese mes.

## Ideas principales

- **Comprobante = asiento contable:** todo movimiento financiero tiene un comprobante que lo respalda.
- **Débito = crédito:** validación básica; el comprobante debe cuadrar.
- **Borrador → confirmado:** solo al confirmar se afecta el balance.
- **Comprobantes errados:** cuando un módulo genera un comprobante con errores (no cuadra, tercero inactivo, cuenta inexistente), entra a `MCPE`; el contador lo revisa, corrige la configuración (cuenta, tercero, centro de costo) y lo reconstruye para que pase a `MCP`.
- **Periodo contable:** controla el mes contable abierto; una vez cerrado, solo se consulta.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `MCP.CNSMCP` | Contabilidad → Movimiento Diario | Consecutivo del comprobante |
| `MCP.F_COMPROBANTE` | Comprobante → Fecha | Fecha del comprobante (debe estar en periodo abierto) |
| `MCP.TIPO` | Comprobante → Tipo | `E` = egreso, `I` = ingreso, `A` = ajuste, `N` = nota, `C` = cierre |
| `MCP.CONFIRMADO` | Comprobante → Estado | `0` = borrador, `1` = confirmado |
| `MCP.PROCEDENCIA` | Comprobante (campo interno) | Módulo de origen: `FTR`, `CXP`, `CAJA`, `BMOV`, `MANUAL` |
| `MCH.IDCUE` | Líneas del comprobante → Cuenta | Cuenta del PUC (plan único de cuentas) |
| `MCH.IDTER` | Líneas → Tercero | Tercero (cliente, proveedor, paciente, empleado) |
| `MCH.DEBITO` | Líneas → Débito | Valor débito de la cuenta |
| `MCH.CREDITO` | Líneas → Crédito | Valor crédito de la cuenta |
| `MCH.IDCCOSTO` | Líneas → Centro de costo | Centro de costo al que se imputa |
| `MCH.CONCEPTO` | Líneas → Concepto | Descripción de la línea |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `CONTAB_VALIDA_CUADRE` | Valida cuadre al confirmar | `SI` | Rechaza confirmación si débitos ≠ créditos |
| `CONTAB_PERMITE_TERCERO_INACTIVO` | Permite tercero inactivo | `NO` | Rechaza líneas con tercero inactivo |
| `CONTAB_EXIGE_CCOSTO` | Exige centro de costo | `SI` | Rechaza líneas sin centro de costo en cuentas de gastos |
| `CONTAB_CONFIRMA_AUTO` | Confirmación automática | `NO` | Si `SI`, los comprobantes de módulos se confirman automáticamente (no pasan por borrador) |

## Usuario final

**Roles:**
- **Contador:** crea comprobantes manuales, revisa borradores, confirma comprobantes.
- **Auditor contable:** valida que los comprobantes estén bien clasificados, que cuadren y que tengan soporte.
- **Revisor fiscal:** audita los comprobantes confirmados, verifica trazabilidad.

**Acciones del usuario:**
1. **Crear comprobante manual:** Contabilidad → Movimiento Diario → Nuevo → seleccionar tipo, fecha, concepto → agregar líneas con cuenta, tercero, débito/crédito.
2. **Revisar cuadre:** verificar que suma de débitos = suma de créditos.
3. **Confirmar:** pulsar Confirmar → el sistema valida cuadre, periodo abierto, tercero activo, cuenta activa; marca `CONFIRMADO=1`.
4. **Consultar comprobantes:** filtrar por tipo, fecha, procedencia; exportar a Excel para análisis.
5. **Anular:** si el comprobante tiene un error, anularlo (genera un comprobante de anulación con los mismos valores invertidos).

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_MCP_COL → CRUDMCP`
- **Propósito:** crear o editar cabecera de comprobante.
- **Valida:** periodo contable abierto; tipo de comprobante válido.
- **Qué hace:** `INSERT` o `UPDATE` en `MCP` con `CONFIRMADO=0`.
- **Errores:** "Periodo contable cerrado", "Tipo de comprobante inválido".

#### `SPQ_MCP_COL → CONFIRMAR_MASIVO`
- **Propósito:** confirmar uno o varios comprobantes.
- **Valida:** débitos = créditos; tercero activo; cuenta activa; periodo abierto.
- **Qué hace:** llama `SPK_REVISAR_COMPROBANTE` para validar, llama `SPK_NC_CONFIRMAR_CONTAB` para marcar `CONFIRMADO=1`.
- **Errores:** "Comprobante no cuadra: débitos $X, créditos $Y", "Tercero inactivo: código `Z`".

#### `SPK_REVISAR_COMPROBANTE`
- **Propósito:** validar que el comprobante cumpla todas las reglas.
- **Qué hace:** valida cuadre, tercero activo, cuenta activa, centro de costo en gastos, periodo abierto.
- **Retorna:** lista de errores (si hay).

#### `SPK_NC_CONFIRMAR_CONTAB`
- **Propósito:** marcar el comprobante como confirmado.
- **Qué hace:** `UPDATE MCP SET CONFIRMADO=1, F_CONFIRMADO=GETDATE()`.

### Ejemplos reales del sector salud

**Ejemplo 1 — Comprobante manual de ajuste:**
El contador detecta que se contabilizó mal una compra de insumos médicos: se cargó a la cuenta `5135 Medicamentos` cuando debió ser `5136 Insumos médicos`. Crea un comprobante de ajuste:
- Tipo: `A` (ajuste)
- Fecha: `2026-10-20`
- Línea 1: Débito `5136 Insumos médicos` `$2.000.000`
- Línea 2: Crédito `5135 Medicamentos` `$2.000.000`

El sistema valida que cuadre (`$2.000.000 = $2.000.000`), el contador pulsa Confirmar, el comprobante pasa a confirmado y corrige el saldo de las cuentas.

**Ejemplo 2 — Comprobante automático de facturación:**
Al contabilizar una factura de `$10.000.000`, el sistema llama `SPK_NC_CONTAB_FTR` y genera automáticamente el comprobante:
- Tipo: `I` (ingreso)
- Procedencia: `FTR`
- Línea 1: Débito `1305 Cuentas por cobrar EPS` `$10.000.000`, tercero `Compensar EPS`
- Línea 2: Crédito `4105 Ingresos asistenciales` `$10.000.000`

El comprobante nace en borrador, el contador lo revisa, confirma que esté bien clasificado y pulsa Confirmar. Si hubiera tenido un error (ej. tercero inactivo), habría entrado a `MCPE` (Comprobantes Errados) para corrección.

## Pendiente validar

- Cómo se reversa un comprobante ya confirmado (ej. factura anulada después de contabilizada).
- Si el sistema permite confirmar comprobantes con centavos de diferencia (balanceo automático).
- Mecanismo de alertas cuando un comprobante lleva más de 5 días en borrador sin confirmar.
