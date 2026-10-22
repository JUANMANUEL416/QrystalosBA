# 🔐 Apertura y cierre de sesión de caja

## Contexto

**Proceso:** Caja  
**Capa:** 02 - Operación

Antes de recibir pagos o efectuar egresos, el cajero debe **abrir la sesión de caja** (`ACJ`) con una base inicial de efectivo. Durante el turno, el cajero registra ingresos (recaudos asistenciales, ventas, otros) y egresos (pagos a proveedores, caja menor, reembolsos). Al final del turno, el cajero **cierra la caja** contando el efectivo físico, validando las formas de pago (datáfono, cheques, consignaciones) y generando el cuadre automático. El cuadre compara el efectivo esperado vs el efectivo real; si hay diferencia, el sistema la registra como sobrante o faltante.

## Explicación

**Apertura de caja:**
1. El cajero ingresa a Administrativo → Caja, el sistema detecta que no hay sesión abierta.
2. El cajero pulsa Abrir Caja, selecciona el turno (mañana, tarde, noche), ingresa la base inicial de efectivo (ej. `$500.000` para dar cambio) y confirma.
3. El sistema crea un registro en `ACJ` (apertura/cierre) con `IDCJR` (cajero), `F_ABIERTO` (fecha y hora de apertura), `BASE` (efectivo inicial), `ESTADO=A` (abierta).
4. A partir de ese momento, el cajero puede registrar recibos de ingreso (recaudos de pacientes) y confirmar egresos autorizados.

**Durante el turno:**
- El cajero recibe pagos de pacientes (copagos, cuotas moderadoras, ventas de medicamentos): genera recibos de ingreso (`FCJ` clase INGRESO).
- El cajero confirma egresos autorizados (pagos a proveedores): confirma egresos pendientes (`FCJ` clase PAGO).
- Cada recibo tiene formas de pago (`PCJ`): efectivo, datáfono, cheque, consignación, tarjeta de crédito institucional.

**Cierre de caja:**
1. Al final del turno, el cajero cuenta el efectivo físico en la gaveta.
2. Pulsa Cerrar Caja → el sistema calcula el cuadre:
   - **Efectivo esperado** = Base inicial + ingresos efectivo - egresos efectivo - caja menor.
   - **Efectivo real** = lo que cuenta el cajero.
   - **Diferencia** = Efectivo real - Efectivo esperado.
   - Si diferencia > 0: sobrante (el cajero debe explicar de dónde salió el excedente).
   - Si diferencia < 0: faltante (el cajero debe cubrir el faltante o registrarlo como pérdida).
3. El sistema actualiza `ACJ` con `F_CERRADO`, `EFECTIVO_ESPERADO`, `EFECTIVO_REAL`, `DIFERENCIA`, `ESTADO=C` (cerrada).
4. Se genera el informe de cierre con el detalle de recibos, formas de pago y cuadre.

**Cuadre automático o manual:**
- **Automático:** el sistema calcula la diferencia y la registra.
- **Manual:** el cajero ajusta las formas de pago si detecta errores (ej. un pago con datáfono que se ingresó como efectivo).

## Ideas principales

- **Sesión de caja:** un cajero solo puede operar si tiene una sesión abierta en su turno.
- **Base inicial:** efectivo de arranque para dar cambio a los pacientes.
- **Cuadre:** validación de que el efectivo físico coincida con el efectivo esperado según los recibos.
- **Sobrante / faltante:** diferencia entre efectivo real y esperado; debe justificarse.
- **Control de turno:** cada cajero abre y cierra su caja en su turno; no puede operar en caja abierta por otro cajero.
- **Auditoría:** el informe de cierre es el soporte contable y de tesorería del día.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `ACJ.CNSACJ` | Caja → Sesión | Consecutivo de apertura/cierre |
| `ACJ.IDCJR` | Caja → Cajero | Cajero responsable de la sesión |
| `ACJ.F_ABIERTO` | Caja → Apertura | Fecha y hora de apertura |
| `ACJ.F_CERRADO` | Caja → Cierre | Fecha y hora de cierre |
| `ACJ.BASE` | Apertura → Base inicial | Efectivo inicial en la gaveta |
| `ACJ.EFECTIVO_ESPERADO` | Cierre → Cuadre | Efectivo que debería haber según recibos |
| `ACJ.EFECTIVO_REAL` | Cierre → Cuadre | Efectivo contado físicamente por el cajero |
| `ACJ.DIFERENCIA` | Cierre → Cuadre | Diferencia (sobrante o faltante) |
| `ACJ.ESTADO` | Caja → Estado | `A` = abierta, `C` = cerrada |
| `ACJD.IDFPA` | Cierre → Detalle formas de pago | Forma de pago (efectivo, datáfono, cheque) |
| `ACJD.VALOR_ESPERADO` | Detalle formas | Valor esperado según recibos |
| `ACJD.VALOR_REAL` | Detalle formas | Valor real contado o validado |

## Variables de configuración (USVGS)

**Pendiente validar:** No se encontraron variables USVGS específicas para apertura/cierre de caja en la base de conocimiento. La validación de base inicial, cuadre y reembolso se hace directamente en los SPs (`SPQ_CONF_CAJA → APERTURA_CAJA`, `SPQ_CONF_CAJA_2 → CIERRE_CAJA`, `SPQ_CONF_CAJA_2 → CUADRE_CAJA`).

## Usuario final

**Roles:**
- **Cajero:** abre y cierra la caja, cuenta el efectivo, genera el informe de cuadre.
- **Supervisor de caja:** revisa el cuadre, autoriza faltantes mayores, audita el cierre.
- **Contador:** registra el cuadre en libros, contabiliza sobrantes/faltantes.

**Acciones del usuario:**
1. **Abrir caja:** Caja → Abrir Caja → seleccionar turno, ingresar base inicial (ej. `$500.000`), confirmar.
2. **Operar:** durante el turno, registrar recibos de ingreso y confirmar egresos.
3. **Cerrar caja:** al final del turno, pulsar Cerrar Caja → contar el efectivo físico, ingresar `EFECTIVO_REAL`, validar formas de pago (datáfono, cheques), confirmar cierre.
4. **Revisar cuadre:** el sistema muestra el cuadre con efectivo esperado, efectivo real, diferencia. Si hay faltante mayor al permitido, el supervisor debe autorizar el cierre.
5. **Imprimir informe:** generar el informe de cierre con el detalle de recibos, formas de pago y cuadre para entregar a contabilidad.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_CONF_CAJA → APERTURA_CAJA`
- **Propósito:** abrir sesión de caja.
- **Valida:** cajero existe y tiene permisos; caja configurada; turno seleccionado; no hay otra sesión abierta por el mismo cajero.
- **Qué hace:** `INSERT` en `ACJ` con `ESTADO=A`, `F_ABIERTO`, `BASE`, `IDCJR`.
- **Errores:** "Cajero ya tiene una sesión abierta", "Caja no configurada".

#### `SPQ_CONF_CAJA_2 → CIERRE_CAJA`
- **Propósito:** cerrar sesión de caja.
- **Valida:** sesión abierta; todos los recibos confirmados; efectivo real ingresado.
- **Qué hace:** calcula `EFECTIVO_ESPERADO` (base + ingresos efectivo - egresos efectivo), compara con `EFECTIVO_REAL`, registra `DIFERENCIA`, actualiza `ACJ` con `ESTADO=C`, `F_CERRADO`.
- **Errores:** "Hay recibos pendientes de confirmar", "Faltante supera el máximo permitido".

#### `SPQ_CONF_CAJA_2 → CUADRE_CAJA`
- **Propósito:** generar cuadre detallado por forma de pago.
- **Qué hace:** lee todos los recibos de la sesión, agrupa por forma de pago, suma valores esperados vs reales, inserta en `ACJD` (detalle de cierre).
- **Retorna:** tabla con forma de pago, valor esperado, valor real, diferencia.

### Ejemplos reales del sector salud

**Ejemplo 1 — Apertura y cierre sin diferencia:**
El cajero `María López` abre la caja a las `07:00 AM` con base inicial `$500.000`. Durante el turno recibe:
- 15 recaudos de pacientes: `$1.200.000` efectivo, `$800.000` datáfono.
- Confirma 3 egresos (pagos proveedores): `$300.000` efectivo.

Al cerrar a las `03:00 PM`, cuenta el efectivo:
- Esperado: `$500.000` (base) + `$1.200.000` (ingresos) - `$300.000` (egresos) = `$1.400.000`.
- Real: `$1.400.000`.
- Diferencia: `$0` (cuadre perfecto).

El sistema marca la sesión como cerrada, genera el informe de cierre y contabiliza los movimientos del día.

**Ejemplo 2 — Cierre con faltante:**
El cajero `Juan Pérez` abre la caja con base `$500.000`. Durante el turno recibe `$2.000.000` efectivo. Al cerrar, cuenta solo `$2.490.000` (esperado `$2.500.000`). Faltante: `$10.000`. Como supera el máximo permitido (`$5.000`), el supervisor `Ana Gómez` debe autorizar el cierre. El faltante se registra en contabilidad como gasto por diferencia de caja.

## Pendiente validar

- Cómo se contabiliza el sobrante/faltante (cuenta contable específica).
- Si el sistema permite reabrir una caja ya cerrada para ajustar errores.
- Mecanismo de alertas cuando un cajero tiene faltantes recurrentes (auditoría de riesgo).
