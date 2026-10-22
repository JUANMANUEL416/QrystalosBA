# 💰 Orden de pago y egreso de caja

## Contexto

**Proceso:** Cuentas por Pagar  
**Capa:** 03 - Autorización y ejecución del pago

Una vez contabilizada la cuenta por pagar, el siguiente paso es programar su pago mediante una **Orden de Pago** (`FCXPP`). La orden agrupa una o varias facturas de uno o varios proveedores, define el monto a pagar (total o parcial), se autoriza (genera egresos pendientes en caja) y finalmente se confirma en caja con la forma de pago (efectivo, cheque, transferencia, datáfono). Al confirmar, el egreso se contabiliza y el saldo de la CxP disminuye.

## Explicación

El flujo completo es:

1. **Crear orden de pago:** en Administrativo → Órdenes de pago → Nuevo, el usuario selecciona las CxP pendientes de un proveedor o de varios, define si paga el saldo total o un abono parcial, y guarda la orden.
2. **Detalle de la orden:** la orden (`FCXPP`) tiene líneas (`FCXPPM`) que relacionan cada CxP incluida con el valor a pagar.
3. **Autorizar:** el tesorero o el contador revisa la orden y pulsa Autorizar. Según las variables configuradas, la autorización puede ser:
   - **Masiva:** crea un solo egreso `FCJ` por el total de la orden (todos los proveedores juntos).
   - **Individual por tercero:** crea un egreso `FCJ` por cada proveedor incluido en la orden.
   - **Individual por abono:** crea un egreso `FCJ` por cada línea de la orden (cada CxP un egreso separado).
   
   Los egresos nacen con estado pendiente de confirmar en caja (`CONFIRMADO=0`).

4. **Confirmar en caja:** el cajero abre Administrativo → Caja → Mov. Egreso, ve los egresos pendientes, selecciona la forma de pago (efectivo, cheque, transferencia) y pulsa Confirmar. El sistema:
   - Marca el egreso como confirmado (`CONFIRMADO=1`).
   - Actualiza el saldo bancario (`BCT`) si la forma de pago es cheque o transferencia.
   - Contabiliza el egreso (`SPK_NC_CONTAB_CAJA_EGR`): débito a proveedores, crédito a bancos o caja.
   - Actualiza el saldo de la CxP (`FCXP.SALDO -= valor pagado`).
   - Marca la orden de pago como pagada (`FCXPP.ESTADO=P`).

**Tres modos de autorización (según variables):**

| Modo | Variables | Resultado |
|------|-----------|-----------|
| **Masivo** | `AUT_EGRE_INDIVIDUAL=NO` | Un solo egreso `FCJ` por el total de la orden |
| **Individual por tercero** | `AUT_EGRE_INDIVIDUAL=SI`, `PERMITE_EGR_SIN_C=SI` | Un egreso por proveedor |
| **Individual por abono** | `AUT_EGRE_INDIVIDUAL=SI`, `PERMITE_EGR_SIN_C=NO` | Un egreso por cada línea de la orden |

## Ideas principales

- **Orden de pago:** agrupa CxP para programar su pago; puede incluir varios proveedores.
- **Autorización:** genera egresos pendientes en caja según el modo configurado.
- **Egreso pendiente:** recibo de caja clase PAGO con `CONFIRMADO=0`; espera forma de pago del cajero.
- **Confirmación:** el cajero asigna forma de pago, confirma el egreso, actualiza saldo bancario y contabiliza.
- **Abono total o parcial:** la orden puede pagar el saldo completo de la CxP o solo un abono parcial.
- **Control de flujo de caja:** el tesorero programa los pagos según disponibilidad de efectivo o saldo bancario.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `FCXPP.CNSFCXPP` | Órdenes de pago → Detalle | Consecutivo de la orden de pago |
| `FCXPP.F_ORDEN` | Orden de pago → Fecha | Fecha de creación de la orden |
| `FCXPP.ESTADO` | Orden de pago → Estado | `B` = borrador, `A` = autorizada, `P` = pagada |
| `FCXPP.TOTAL` | Orden de pago → Total | Suma de valores a pagar de todas las líneas |
| `FCXPPM.IDFCXP` | Detalle orden → CxP incluida | Cuenta por pagar que se va a pagar |
| `FCXPPM.VALOR` | Detalle orden → Valor a pagar | Monto a pagar (total o parcial del saldo de la CxP) |
| `FCJ.CNSFCJ` | Mov. Egreso → Recibo | Consecutivo del recibo de egreso |
| `FCJ.CONFIRMADO` | Mov. Egreso → Estado | `0` = pendiente, `1` = confirmado |
| `PCJ.IDFPA` | Mov. Egreso → Forma de pago | Efectivo, cheque, transferencia, datáfono |
| `PCJ.VALOR` | Forma de pago → Valor | Monto de la forma de pago |
| `PCJ.REFERENCIA` | Forma de pago → Referencia | Número de cheque, número de transferencia |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `AUT_EGRE_INDIVIDUAL` | Modo de autorización | `NO` = masivo, `SI` = individual | Define si se crea un egreso por orden o un egreso por proveedor/línea |
| `PERMITE_EGR_SIN_C` | Permite egreso sin caja | `NO` | Si `NO`, exige caja abierta para autorizar; si `SI`, crea egresos sin sesión de caja |
| `IDCJTECXP` | Tipo de egreso para CxP | `1` (pago proveedores) | Tipo de egreso de caja (`CJTE`) con que nacen los egresos de la orden |
| `BANC_DINA_ARCH_PLANO` | Genera archivo plano bancario | `SI` | Habilita el botón Archivo Plano para generar el archivo de transferencias bancarias |

## Usuario final

**Roles:**
- **Tesorero:** crea la orden de pago, selecciona las CxP a pagar, autoriza la orden.
- **Cajero:** confirma los egresos en caja, ingresa las formas de pago (cheque, transferencia).
- **Contador:** revisa que los pagos estén bien contabilizados y que el saldo de la CxP cuadre.

**Acciones del usuario:**
1. **Crear orden:** Órdenes de pago → Nuevo → buscar CxP pendientes del proveedor, marcar las que se van a pagar, definir si paga total o parcial, guardar orden.
2. **Autorizar:** en el detalle de la orden, pulsar Autorizar → el sistema crea egresos pendientes en caja según el modo configurado.
3. **Confirmar en caja:** el cajero abre Caja → Mov. Egreso, selecciona el egreso pendiente, pulsa Forma de Pago → seleccionar efectivo/cheque/transferencia, ingresar referencia (número de cheque), pulsar Confirmar.
4. **Consultar estado:** en Órdenes de pago, filtrar por estado `P` (pagada) para ver las órdenes completadas.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_ORDEN_PAGO → CRUD_FCXPPM`
- **Propósito:** crear orden de pago y agregar líneas.
- **Valida:** CxP contabilizada, con saldo pendiente.
- **Qué hace:** `INSERT` en `FCXPP` y `FCXPPM`; suma valores de líneas en `FCXPP.TOTAL`.

#### `SPQ_ORDEN_PAGO → AUTORIZAR`
- **Propósito:** autorizar la orden (generar egresos pendientes).
- **Valida:** orden en estado borrador; variable `IDCJTECXP` configurada; concepto de caja activo; caja de la orden existe.
- **Qué hace:** llama `SPK_CONFIRMAR_PAGOSMASIVO` (si masivo) o crea egresos individuales; inserta `FCJ` con `CONFIRMADO=0`.
- **Errores:** "variable IDCJTECXP no configurada", "Concepto de caja no existe", "Caja no existe".

#### `SPQ_CONF_CAJA → CONFIRMAR_RECIBO_EGRESO`
- **Propósito:** confirmar el egreso en caja.
- **Valida:** egreso existe, sesión de caja abierta, forma de pago registrada.
- **Qué hace:** marca `FCJ.CONFIRMADO=1`, llama `SPK_CIERRERECIBO_CAJA` (actualiza saldo banco `BCT`), llama `SPK_NC_CONTAB_CAJA_EGR` (contabiliza egreso), llama `SPK_MARCA_OP_PAGADA_POR_EGRESO` (actualiza saldo `FCXP`).
- **Errores:** "Caja cerrada", "Forma de pago no registrada".

#### `SPK_CONFIRMAR_PAGOSMASIVO`
- **Propósito:** autorización masiva (un egreso por toda la orden).
- **Qué hace:** suma todos los valores de la orden, crea un único egreso `FCJ` por ese total.

#### `SPK_NC_CONTAB_CAJA_EGR`
- **Propósito:** contabilizar egreso de caja.
- **Qué hace:** débito a proveedores (`2205`), crédito a bancos o caja según forma de pago.

### Ejemplos reales del sector salud

**Ejemplo 1 — Orden de pago a un proveedor:**
El tesorero crea una orden de pago para `Laboratorios ABC` con dos facturas pendientes: `FA-12345` por `$11.650.000` y `FA-12346` por `$5.800.000`. Total de la orden: `$17.450.000`. Pulsa Autorizar (modo individual por tercero); el sistema crea un egreso `FCJ` por `$17.450.000` pendiente de confirmar. El cajero abre Caja → Mov. Egreso, ve el egreso, ingresa forma de pago Transferencia con número `T-789456`, pulsa Confirmar. El sistema actualiza saldo banco, contabiliza el egreso y marca las dos facturas como pagadas (saldo `$0`).

**Ejemplo 2 — Abono parcial:**
La IPS debe `$50.000.000` a un proveedor de equipos médicos. El tesorero decide pagar solo `$20.000.000` este mes. Crea la orden de pago, selecciona la CxP, ingresa `$20.000.000` en valor a pagar (parcial), guarda y autoriza. Se crea un egreso por `$20.000.000`. Al confirmar en caja, el saldo de la CxP queda en `$30.000.000` pendiente.

## Pendiente validar

- Cómo se genera el archivo plano bancario para pagos masivos por transferencia.
- Si el sistema permite desautorizar una orden de pago ya autorizada pero no confirmada.
- Mecanismo de alertas cuando el saldo bancario es insuficiente para cubrir la orden de pago.
