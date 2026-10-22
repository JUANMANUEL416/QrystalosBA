# 💵 Recibo de ingreso (recaudo asistencial)

## Contexto

**Proceso:** Caja  
**Capa:** 02 - Operación

Cuando un paciente es atendido en la IPS y debe pagar su copago, cuota moderadora o un servicio particular, el cajero genera un **recibo de ingreso** (`FCJ` clase INGRESO). Este recibo puede originarse desde una atención asistencial pendiente de pago (la agenda crea un comprobante en cola `TFCJ` que el cajero "trae" a caja) o directamente como un recibo nuevo (ventas de medicamentos, otros servicios). El cajero registra las formas de pago (efectivo, datáfono, tarjeta de crédito, cheque), confirma el recibo, y el sistema actualiza el saldo bancario, contabiliza el ingreso y genera la factura POS (si aplica).

## Explicación

**Traer recibo desde agenda:**
1. Cuando el paciente agenda una cita o es atendido en urgencias, si hay copago o cuota moderadora, el sistema crea un comprobante en cola (`TFCJ`) con el valor a pagar.
2. El cajero pulsa Traer Recibo, busca el paciente o la cita, selecciona el comprobante pendiente y lo trae a caja.
3. El comprobante se convierte en un recibo `FCJ` con estado pendiente de confirmar (`CONFIRMADO=0`).

**Nuevo recibo:**
1. Si el paciente viene a pagar algo no registrado (ej. venta de medicamentos en farmacia externa, servicio particular), el cajero pulsa Nuevo Recibo, selecciona el concepto de caja (`CPCJ`), ingresa el valor y crea el recibo.

**Formas de pago:**
1. El cajero pregunta al paciente cómo va a pagar: efectivo, tarjeta débito/crédito (datáfono), cheque, consignación o tarjeta de crédito institucional (crédito IPS a cuotas).
2. El cajero registra cada forma de pago en `PCJ`: selecciona el tipo (`IDFPA`), ingresa el valor y la referencia (ej. número de aprobación del datáfono, número de cheque).
3. La suma de formas de pago debe igualar el valor del recibo.

**Confirmación:**
1. Una vez registradas las formas de pago, el cajero pulsa Confirmar.
2. El sistema valida que la suma de formas de pago cuadre con el valor del recibo.
3. Marca el recibo como confirmado (`CONFIRMADO=1`).
4. Actualiza el saldo bancario (`BCT`) si la forma de pago es datáfono, cheque o consignación.
5. Contabiliza el ingreso (`SPK_NC_CONTAB_CAJA_ING`): débito a caja o bancos, crédito a ingresos asistenciales.
6. Si el recibo es de copago, genera la factura POS (`FTR` con `PROCEDENCIA=CAJA`, `TIPOFAC=P`).
7. Imprime el recibo de caja para entregar al paciente.

## Ideas principales

- **Recibo de ingreso:** documento que respalda el pago del paciente.
- **Traer recibo:** vincula el comprobante asistencial pendiente con el recibo de caja.
- **Formas de pago mixtas:** un recibo puede tener varias formas de pago (ej. `$50.000` efectivo + `$30.000` datáfono).
- **Confirmación:** solo al confirmar se actualiza el banco y se contabiliza.
- **Factura POS:** si el recibo es copago o cuota moderadora, el sistema genera automáticamente la factura POS para el reporte a la EPS.
- **Trazabilidad:** el recibo queda vinculado a la cita, la admisión o la venta de farmacia.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `FCJ.CNSFCJ` | Caja → Recibo | Consecutivo del recibo de ingreso |
| `FCJ.F_RECIBO` | Recibo → Fecha | Fecha y hora de emisión del recibo |
| `FCJ.VALOR` | Recibo → Valor | Monto total del recibo |
| `FCJ.CONFIRMADO` | Recibo → Estado | `0` = pendiente, `1` = confirmado |
| `FCJ.IDCPCJ` | Recibo → Concepto | Concepto de caja (copago, cuota moderadora, venta farmacia, otros) |
| `FCJ.IDAFI` | Recibo → Paciente | Afiliado que paga |
| `PCJ.IDFPA` | Formas de pago → Tipo | Efectivo, datáfono, cheque, consignación, tarjeta crédito IPS |
| `PCJ.VALOR` | Formas de pago → Valor | Monto de la forma de pago |
| `PCJ.REFERENCIA` | Formas de pago → Referencia | Número de aprobación (datáfono), número de cheque |
| `TFCJ.IDTFCJ` | Comprobantes en cola → ID | Comprobante asistencial pendiente de pago |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `CAJA_EXIGE_PACIENTE` | Exige identificar al paciente | `SI` | No permite confirmar recibo sin afiliado registrado |
| `CAJA_GENERA_FTR_POS` | Genera factura POS automáticamente | `SI` | Al confirmar copago, crea la factura POS |
| `CAJA_VALIDA_CUADRE_FP` | Valida que formas de pago cuadren | `SI` | Rechaza confirmación si suma de formas ≠ valor del recibo |
| `CAJA_PERMITE_VUELTOS` | Permite registrar vueltos | `SI` | Si el paciente paga con efectivo mayor al valor del recibo, el sistema calcula el vuelto |

## Usuario final

**Roles:**
- **Cajero:** genera el recibo, registra formas de pago, confirma el recibo e imprime el soporte.
- **Paciente:** paga el copago o el servicio y recibe el recibo de caja.
- **Auditor de tesorería:** revisa que los recibos estén bien contabilizados y que el saldo bancario cuadre.

**Acciones del usuario:**
1. **Traer recibo:** Caja → Traer Recibo → buscar paciente o número de cita, seleccionar comprobante pendiente, traer a caja.
2. **Nuevo recibo:** Caja → Nuevo Recibo → seleccionar paciente, concepto (ej. venta farmacia), ingresar valor.
3. **Registrar formas de pago:** en el recibo, botón Forma de Pago → seleccionar tipo (efectivo, datáfono, cheque), ingresar valor y referencia. Repetir si hay formas mixtas.
4. **Confirmar:** pulsar Confirmar → el sistema valida cuadre, actualiza banco, contabiliza, genera factura POS (si aplica), imprime recibo.
5. **Entregar recibo:** imprimir y entregar al paciente.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_CONF_CAJA → TRAER_RECIBO`
- **Propósito:** traer comprobante asistencial pendiente a caja.
- **Valida:** comprobante existe en `TFCJ`, no está pagado, sesión de caja abierta.
- **Qué hace:** `INSERT` en `FCJ` con `CONFIRMADO=0`, vincula con `IDTFCJ`.
- **Errores:** "Comprobante ya pagado", "Sesión de caja cerrada".

#### `SPQ_CONF_CAJA → NUEVO_RECIBO`
- **Propósito:** crear recibo nuevo (no vinculado a agenda).
- **Valida:** concepto de caja activo, sesión abierta.
- **Qué hace:** `INSERT` en `FCJ` con `CONFIRMADO=0`.

#### `SPQ_CONF_CAJA → CONFIRMAR_RECIBO`
- **Propósito:** confirmar el recibo de ingreso.
- **Valida:** suma de formas de pago = valor del recibo; sesión abierta.
- **Qué hace:** marca `FCJ.CONFIRMADO=1`, llama `SPK_CIERRERECIBO_CAJA` (actualiza saldo banco `BCT`), llama `SPK_NC_CONTAB_CAJA_ING` (contabiliza ingreso), si es copago llama `SPK_CREA_FACTURA_POS_CAJA` (genera factura POS).
- **Errores:** "Formas de pago no cuadran", "Caja cerrada".

#### `SPK_CIERRERECIBO_CAJA`
- **Propósito:** actualizar saldo bancario según formas de pago.
- **Qué hace:** lee `PCJ`, actualiza `BCT` (saldo banco) por cada forma de pago no efectivo (datáfono, cheque, consignación).

#### `SPK_NC_CONTAB_CAJA_ING`
- **Propósito:** contabilizar ingreso de caja.
- **Qué hace:** débito a caja o bancos (según forma de pago), crédito a ingresos asistenciales (`4105`).

#### `SPK_CREA_FACTURA_POS_CAJA`
- **Propósito:** generar factura POS desde recibo de copago.
- **Qué hace:** `INSERT` en `FTR` con `PROCEDENCIA=CAJA`, `TIPOFAC=P`, vincula con `CNSFCJ`.

### Ejemplos reales del sector salud

**Ejemplo 1 — Copago consulta general:**
El paciente `Juan Ramírez` tiene cita de consulta general con copago de `$10.000`. Al llegar a caja, el cajero pulsa Traer Recibo, busca al paciente, trae el comprobante pendiente. Registra forma de pago:
- Efectivo: `$10.000`.

Pulsa Confirmar. El sistema marca el recibo como confirmado, contabiliza el ingreso, genera la factura POS `FV-POS-001234` con `PROCEDENCIA=CAJA`, imprime el recibo de caja y el paciente recibe su comprobante.

**Ejemplo 2 — Venta de medicamentos con formas mixtas:**
Una paciente particular compra medicamentos en farmacia externa por `$85.000`. El cajero crea Nuevo Recibo, selecciona concepto "Venta farmacia", ingresa `$85.000`. La paciente paga:
- Efectivo: `$50.000`
- Datáfono (débito): `$35.000`, referencia `APR-789456`.

El cajero registra ambas formas de pago, pulsa Confirmar. El sistema valida que `$50.000 + $35.000 = $85.000`, actualiza el saldo bancario con `$35.000` (datáfono), contabiliza el ingreso, imprime el recibo.

## Pendiente validar

- Cómo se anula un recibo ya confirmado (ej. paciente devuelve el pago).
- Si el sistema permite confirmar un recibo con formas de pago pendientes de validar (ej. cheque sin fondos).
- Mecanismo de alertas cuando un paciente tiene recibos pendientes de pago de atenciones anteriores.
