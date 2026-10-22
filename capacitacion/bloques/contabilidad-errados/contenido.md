# ⚠️ Comprobantes errados (MCPE)

## Contexto

**Proceso:** Contabilidad  
**Capa:** 04 - Corrección

Cuando un módulo (facturación, caja, CxP, bancos, inventario, nómina) intenta generar un comprobante contable y detecta errores de configuración o cuadre, el comprobante no llega a `MCP` (libro mayor) sino que entra a **Comprobantes Errados** (`MCPE` cabecera, `MCHE` líneas). Los errores más comunes son: tercero inactivo, cuenta contable inexistente, falta centro de costo, no cuadra (débitos ≠ créditos), duplicados (misma referencia). El contador revisa el errado, corrige la configuración (`KMCOM`, cuentas, terceros, variables) y **reconstruye** el comprobante para que pase a `MCP`.

## Explicación

**¿Por qué llegan comprobantes a errados?**
- **Tercero inactivo:** el procedimiento de contabilización intenta usar un tercero que está marcado como inactivo en la tabla `TER`.
- **Cuenta inexistente:** la cuenta contable no existe en el plan de cuentas (`CUE`) o está inactiva.
- **No cuadra:** débitos ≠ créditos (error en la configuración del modelo contable `KMCOM` o en las variables).
- **Duplicado:** ya existe un comprobante vigente con la misma procedencia y las mismas referencias (ej. dos comprobantes de la misma factura).
- **Falta centro de costo:** cuentas de gastos exigen centro de costo y no se configuró.
- **Periodo cerrado:** el periodo contable está cerrado para la fecha del comprobante.

**Flujo de corrección:**
1. El contador abre Contabilidad → Comprobantes Errados → ve la lista de errados con el texto del error.
2. Pulsa Diagnosticar Errores → el sistema analiza el errado y retorna el diagnóstico detallado (qué tercero está inactivo, qué cuenta falta, cuánto no cuadra).
3. El contador corrige la configuración:
   - Si el tercero está inactivo, lo activa en Configuración → Terceros.
   - Si la cuenta no existe, la crea en Plan de Cuentas o ajusta el modelo contable `KMCOM`.
   - Si no cuadra, revisa las variables de contabilización y ajusta el modelo.
4. Pulsa Reconstruir → el sistema vuelve a ejecutar el procedimiento de contabilización (`SPK_NC_CONTAB_*`) con la configuración corregida.
5. Si la corrección es correcta, el comprobante pasa a `MCP` (confirmado) y sale de errados.
6. Si aún hay errores, vuelve a `MCPE` con el nuevo texto de error.

**Revisar vs Reconstruir:**
- **Revisar:** ejecuta las validaciones sin generar el comprobante; útil para probar si la corrección funciona antes de reconstruir.
- **Reconstruir:** vuelve a ejecutar el procedimiento completo; si pasa, el comprobante sale de errados.

## Ideas principales

- **Errados = comprobantes bloqueados:** no afectan el balance hasta que se corrijan.
- **Diagnóstico:** el sistema identifica el error y sugiere la corrección.
- **Corrección en configuración:** la mayoría de errores se corrigen ajustando `KMCOM`, terceros, cuentas o variables.
- **Reconstrucción:** vuelve a generar el comprobante con la configuración corregida.
- **No editar líneas a mano:** en errados no se editan las líneas manualmente; se corrige la configuración y se reconstruye.
- **Trazabilidad:** cada errado tiene referencias al documento origen (factura, recibo, CxP, nómina).

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `MCPE.CNSMCPE` | Comprobantes Errados → Detalle | Consecutivo del errado |
| `MCPE.PROCEDENCIA` | Errados → Origen | Módulo de origen: `FTR`, `CXP`, `CAJA`, `BMOV`, `INV`, `NOMINA` |
| `MCPE.REFERENCIA1` | Errados → Referencia | Número del documento origen (ej. número de factura, recibo de caja) |
| `MCPE.REFERENCIA2` | Errados → Referencia 2 | Complemento de la referencia (ej. consecutivo de la CxP) |
| `MCPE.ERROR` | Errados → Error | Texto del error (ej. "Tercero 890123456 inactivo") |
| `MCPE.F_COMPROBANTE` | Errados → Fecha | Fecha del comprobante que falló |
| `MCHE.IDCUE` | Líneas del errado → Cuenta | Cuenta del PUC |
| `MCHE.IDTER` | Líneas → Tercero | Tercero (puede estar inactivo o inexistente) |
| `MCHE.DEBITO` / `CREDITO` | Líneas → Débito/Crédito | Valores del asiento |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `CONTAB_ENVIA_A_ERRADOS` | Envía comprobantes con errores a errados | `SI` | Si `NO`, rechaza la operación sin crear el comprobante |
| `CONTAB_DIAGNOSTICA_AUTO` | Diagnóstico automático al entrar a errados | `SI` | Ejecuta `DIAGNOSTICAR_ERRORES` automáticamente al crear el errado |
| `CONTAB_PERMITE_EDITAR_ERRADO` | Permite editar líneas de errados | `NO` | Si `SI`, el contador puede editar las líneas a mano; si `NO`, solo reconstrucción |

## Usuario final

**Roles:**
- **Contador:** revisa errados, corrige configuración, reconstruye comprobantes.
- **Administrador del sistema:** ajusta modelos contables (`KMCOM`), crea cuentas, activa terceros.
- **Auditor contable:** valida que los errados se corrijan en tiempo y forma.

**Acciones del usuario:**
1. **Ver errados:** Contabilidad → Comprobantes Errados → filtrar por procedencia, fecha, tipo de error.
2. **Diagnosticar:** seleccionar errado, pulsar Diagnosticar Errores → el sistema retorna el diagnóstico detallado.
3. **Corregir configuración:** según el diagnóstico:
   - Tercero inactivo: Configuración → Terceros → buscar el tercero, marcar Activo.
   - Cuenta inexistente: Plan de Cuentas → crear la cuenta o ajustar `KMCOM`.
   - No cuadra: revisar variables de contabilización (ej. `CXP_CUENTA_IVA`, `FTR_CUENTA_INGRESO`).
4. **Revisar:** pulsar Revisar MCPE → el sistema valida sin reconstruir; si pasa, confirmar que la corrección es correcta.
5. **Reconstruir:** pulsar Reconstruir → el sistema vuelve a ejecutar el procedimiento; si pasa, el comprobante sale de errados y entra a `MCP`.
6. **Consultar histórico:** revisar cuántos errados se corrigieron en el mes y cuántos están pendientes.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_MCPE_COL → DIAGNOSTICAR_ERRORES`
- **Propósito:** analizar el errado y retornar diagnóstico detallado.
- **Qué hace:** lee `MCPE`/`MCHE`, valida tercero activo, cuenta activa, cuadre, duplicados, centro de costo, periodo abierto.
- **Retorna:** tabla con tipo de error, línea afectada, código de error, sugerencia de corrección.

#### `SPQ_MCPE_COL → REVISAR_MCPE`
- **Propósito:** validar el errado sin reconstruir (prueba).
- **Qué hace:** ejecuta `SPK_NC_REVISAMCPE` que valida todas las reglas sin insertar en `MCP`.
- **Retorna:** `OK` si pasa, lista de errores si aún falla.

#### `SPQ_MCPE_COL → RECONSTRUIR`
- **Propósito:** reconstruir el comprobante con la configuración corregida.
- **Qué hace:** vuelve a ejecutar el procedimiento de contabilización (`SPK_NC_CONTAB_*`) según la procedencia; si pasa, inserta en `MCP`, borra de `MCPE`.
- **Errores:** si aún hay errores, actualiza `MCPE.ERROR` con el nuevo texto.

#### `SPK_NC_REVISAMCPE`
- **Propósito:** validar un errado contra todas las reglas de contabilización.
- **Qué hace:** tercero activo, cuenta activa, cuadre, duplicados, centro de costo, periodo abierto.
- **Retorna:** lista de errores (vacía si pasa).

### Ejemplos reales del sector salud

**Ejemplo 1 — Tercero inactivo en CxP:**
Al contabilizar una CxP del proveedor `Laboratorios XYZ`, el sistema detecta que el tercero está inactivo. El comprobante entra a errados con error "Tercero 890123456 inactivo". El contador:
1. Abre Configuración → Terceros, busca `890123456`.
2. Marca el tercero como Activo.
3. Vuelve a Comprobantes Errados, selecciona el errado, pulsa Revisar → pasa.
4. Pulsa Reconstruir → el sistema genera el comprobante en `MCP`, lo confirma y borra el errado.

**Ejemplo 2 — Comprobante no cuadra en facturación:**
Al contabilizar una factura de `$10.000.000`, el comprobante entra a errados con error "No cuadra: débitos $10.000.000, créditos $9.950.000". El contador diagnóstica y descubre que falta contabilizar el IVA. Revisa el modelo contable `KMCOM` procedencia `FTR` y encuentra que la cuenta de IVA está mal configurada. Corrige la cuenta, pulsa Reconstruir y el comprobante pasa a `MCP` con el IVA incluido.

## Pendiente validar

- Cómo se eliminan errados antiguos (más de 6 meses sin corregir).
- Si el sistema permite forzar la salida de un errado sin reconstruir (ej. documento anulado en el origen).
- Mecanismo de alertas cuando hay más de 50 errados pendientes (indicador de problemas de configuración recurrentes).
