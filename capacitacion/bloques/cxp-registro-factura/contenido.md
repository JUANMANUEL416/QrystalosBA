# 📝 Registro de factura de proveedor (CxP)

## Contexto

**Proceso:** Cuentas por Pagar (FCXP)  
**Capa:** 02 - Operación

Cuando la institución de salud recibe una factura de un proveedor (compra de medicamentos, insumos médicos, servicios, nómina, arrendamientos), debe registrarla en el módulo de **Cuentas por Pagar** para reconocer la obligación, contabilizarla, programar su pago y controlar el flujo de caja. La factura del proveedor se registra en la tabla `FCXP` (cabecera) con su detalle `FCXPD` (líneas de productos o servicios) e impuestos `FCXPI` (IVA, retenciones).

## Explicación

El flujo de registro de una cuenta por pagar es:

1. **Crear cabecera:** el usuario abre Administrativo → Cuentas por Pagar → Nueva CxP, selecciona el tercero (proveedor), ingresa la fecha de la factura, el número de factura del proveedor, la fecha de vencimiento y el valor total.
2. **Agregar detalle:** en la grilla de detalle, el usuario agrega líneas con el concepto (medicamento, insumo, servicio), la cantidad, el valor unitario, el centro de costo y la cuenta contable del gasto.
3. **Calcular impuestos:** el sistema calcula automáticamente el IVA según el tipo de bien o servicio, y las retenciones (retención en la fuente, ICA, IVA retenido) según el régimen del proveedor y los porcentajes configurados en `FIMPDV`.
4. **Contabilizar:** una vez revisada, el usuario pulsa Contabilizar → el sistema valida que el periodo contable esté abierto, que la cuenta por pagar cuadre (suma de líneas = valor total), genera el comprobante contable en `MCP` o `MCPE` (si hay errores de cuadre) y marca la `FCXP` como `CONTABILIZADA=1`.
5. **Programar pago:** la cuenta contabilizada queda pendiente de pago (`SALDO > 0`); el usuario la incluye en una orden de pago para autorizar el egreso.

**Tablas involucradas:**
- `FCXP`: cabecera de la cuenta por pagar (tercero, fecha, número factura proveedor, valor, saldo, estado).
- `FCXPD`: detalle de la cuenta (concepto, cantidad, valor unitario, cuenta contable, centro de costo).
- `FCXPI`: impuestos de la cuenta (IVA, retenciones, base gravable, tarifa).
- `TER`: terceros (proveedores, acreedores).
- `MCP` / `MCPE`: comprobante contable generado al contabilizar.

## Ideas principales

- **Reconocimiento de la obligación:** al registrar la factura del proveedor se reconoce la deuda en libros.
- **Validación de cuadre:** suma de líneas `FCXPD` + impuestos `FCXPI` debe igualar el valor de la cabecera `FCXP`.
- **Retenciones automáticas:** el sistema calcula retenciones según el régimen del proveedor (gran contribuyente, autorretenedor, régimen simple).
- **Contabilización:** genera el asiento contable (débito a gastos y crédito a proveedores) en `MCP` o `MCPE`.
- **Control de saldo:** la `FCXP` tiene un saldo que disminuye al pagar; cuando llega a cero queda totalmente pagada.
- **Periodo contable:** no se puede registrar ni contabilizar una CxP si el periodo contable está cerrado.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `FCXP.IDTER` | Cuentas por Pagar → Nueva CxP → Tercero | Proveedor o acreedor |
| `FCXP.F_FACTURA` | Nueva CxP → Fecha factura | Fecha de emisión de la factura del proveedor |
| `FCXP.NRO_FACTURA` | Nueva CxP → Número factura | Número de factura del proveedor (no el consecutivo interno) |
| `FCXP.F_VENCIMIENTO` | Nueva CxP → Vencimiento | Fecha límite de pago según plazo pactado |
| `FCXP.VALOR` | Nueva CxP → Valor total | Valor bruto de la factura (incluye IVA) |
| `FCXP.SALDO` | Detalle CxP → Saldo | Valor pendiente de pagar (disminuye al abonar) |
| `FCXP.CONTABILIZADA` | Detalle CxP → Estado | `0` = borrador; `1` = contabilizada |
| `FCXPD.CONCEPTO` | Detalle CxP → Líneas → Concepto | Descripción del bien o servicio (medicamento, insumo, arrendamiento) |
| `FCXPD.CANTIDAD` | Líneas → Cantidad | Cantidad comprada |
| `FCXPD.VALOR_UNITARIO` | Líneas → Valor unitario | Precio unitario |
| `FCXPD.IDCCOSTO` | Líneas → Centro de costo | Centro de costo al que se imputa el gasto |
| `FCXPD.CUENTA` | Líneas → Cuenta contable | Cuenta del PUC para el gasto (ej. `5135` medicamentos) |
| `FCXPI.TIPO_IMPUESTO` | Impuestos → Tipo | `IVA`, `RETEFTE`, `RETEICA`, `RETEIVA` |
| `FCXPI.BASE` | Impuestos → Base | Base gravable del impuesto |
| `FCXPI.TARIFA` | Impuestos → Tarifa | Porcentaje del impuesto (ej. 19% para IVA) |
| `FCXPI.VALOR` | Impuestos → Valor | Valor calculado del impuesto (Base × Tarifa) |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `CERRADO_CXP` | Periodo CxP cerrado | `0` = abierto, `1` = cerrado | Si está cerrado, no se registran CxP con fecha en ese período (campo de `FCARTH` y `PRI`) |

**Pendiente validar:**
- Cálculo automático de IVA y retenciones: se hace en el SP pero no se encontró variable USVGS que lo active/desactive
- Validación de cuadre: se hace en `CONTABILIZAR_FCXP` pero no se encontró variable específica
- Exigencia de entrada de inventario: validación interna del SP

## Usuario final

**Roles:**
- **Auxiliar contable:** registra la factura del proveedor, ingresa el detalle y los impuestos.
- **Contador:** revisa que el cuadre sea correcto, que las retenciones estén bien aplicadas y pulsa Contabilizar.
- **Tesorero:** consulta las CxP pendientes de pago para programar la orden de pago.

**Acciones del usuario:**
1. **Crear CxP:** Cuentas por Pagar → Nueva CxP → seleccionar proveedor, ingresar fecha y número de factura, valor total.
2. **Agregar líneas:** en el detalle, agregar línea → seleccionar concepto (medicamento, insumo), cantidad, valor unitario, centro de costo, cuenta contable.
3. **Calcular impuestos:** el sistema calcula automáticamente IVA y retenciones; el usuario puede ajustar manualmente si es necesario.
4. **Revisar cuadre:** verificar que suma de líneas + IVA - retenciones = valor total de la cabecera.
5. **Contabilizar:** pulsar Contabilizar → el sistema valida periodo abierto, genera comprobante en `MCP`/`MCPE`, marca `CONTABILIZADA=1`.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_FCXP → CRUD_FCXP`
- **Propósito:** crear o editar cabecera de cuenta por pagar.
- **Valida:** tercero existe; periodo contable abierto; periodo CxP no cerrado (`FCARTH.CERRADO_CXP=0`).
- **Qué hace:** `INSERT` o `UPDATE` en `FCXP`; inicializa `SALDO = VALOR`.
- **Errores:** "Periodo contable cerrado", "Periodo CxP cerrado".

#### `SPQ_FCXP → CRUD_FCXPD`
- **Propósito:** agregar o editar línea de detalle.
- **Valida:** CxP no contabilizada.
- **Qué hace:** `INSERT` o `UPDATE` en `FCXPD`; llama `SPK_CALCULOVALORESCXP` para recalcular totales.

#### `SPQ_FCXP → CRUD_FCXPI`
- **Propósito:** agregar o editar impuesto.
- **Valida:** CxP no contabilizada.
- **Qué hace:** `INSERT` o `UPDATE` en `FCXPI`; recalcula totales.

#### `SPQ_FCXP → CONTABILIZAR_FCXP`
- **Propósito:** contabilizar la cuenta por pagar.
- **Valida:** suma de líneas + IVA - retenciones = valor cabecera; periodo contable abierto; no duplicada (misma referencia 1 y 2 en comprobante vigente).
- **Qué hace:** llama `SPK_NC_CONTAB_CXP` para generar comprobante en `MCP`/`MCPE`; marca `CONTABILIZADA=1`.
- **Errores:** "Cuenta por pagar no cuadra", "Ya existe comprobante con la misma referencia".

#### `SPK_NC_CONTAB_CXP`
- **Propósito:** generar asiento contable de la CxP.
- **Qué hace:** débito a cuentas de gasto (`FCXPD.CUENTA`) por valor de cada línea, débito a IVA descontable, crédito a retenciones, crédito a proveedores (`FCXP.CUENTA_CXP`).
- **Retorna:** número de comprobante generado.

### Ejemplos reales del sector salud

**Ejemplo 1 — Compra de medicamentos:**
La IPS recibe factura del proveedor `Laboratorios ABC` por `$10.000.000` + IVA 19% = `$11.900.000`. El auxiliar contable registra:
- Cabecera: tercero `Laboratorios ABC`, fecha `2026-10-20`, número factura `FA-12345`, valor `$11.900.000`.
- Detalle: `Amoxicilina 500mg`, cantidad `5.000 tabletas`, valor unitario `$2.000`, cuenta `5135` (medicamentos), centro de costo `Farmacia`.
- Impuestos: IVA 19% sobre `$10.000.000` = `$1.900.000`; retención en la fuente 2,5% sobre `$10.000.000` = `$250.000`.

Al contabilizar, el sistema genera el asiento:
- Débito `5135 Medicamentos`: `$10.000.000`
- Débito `2408 IVA descontable`: `$1.900.000`
- Crédito `2365 Retención en la fuente`: `$250.000`
- Crédito `2205 Proveedores nacionales`: `$11.650.000`

La CxP queda con saldo `$11.650.000` pendiente de pago.

**Ejemplo 2 — Servicios públicos:**
La IPS recibe factura de energía eléctrica por `$3.500.000` sin IVA (exento). Se registra la CxP:
- Cabecera: tercero `Empresa de Energía`, fecha `2026-10-15`, número `EE-456789`, valor `$3.500.000`.
- Detalle: `Energía eléctrica octubre`, cantidad `1`, valor unitario `$3.500.000`, cuenta `5135` (servicios públicos).
- Impuestos: ninguno (exento).

Al contabilizar, el asiento es:
- Débito `5135 Servicios públicos`: `$3.500.000`
- Crédito `2205 Proveedores`: `$3.500.000`

## Pendiente validar

- Cómo se vincula la CxP con la entrada de inventario cuando es una compra de medicamentos o insumos.
- Mecanismo de alertas cuando una CxP está próxima a vencer (5 días antes).
- Si el sistema permite aplicar un anticipo previamente registrado como abono a la CxP.
