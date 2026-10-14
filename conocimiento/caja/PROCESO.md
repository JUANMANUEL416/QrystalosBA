# Proceso: Módulo de Caja y Recibos

**Módulo:** CJA · Caja Operativa y Procesos de Caja  
**Ventanas:** Administrativo → Caja (`/admin/caja`) y Administrativo → Procesos de Caja (`/admin/procaja`)  
**Componentes Vue:** `CajaPage.vue` → `CAJMovinComponent.vue`, `ProCajaPage.vue` → `ProCajaComponent.vue`

El módulo de **Caja y Recibos** en Qrystalos ERP está concebido bajo una arquitectura de **doble motor operativo**: la consola de atención diaria en ventanilla (`/admin/caja`) y la consola central de supervisión, auditoría y cierres masivos (`/admin/procaja`).

### Sketchnote: Ecosistema Integral de Caja y Recibos

![Ecosistema Integral de Caja y Recibos · Qrystalos ERP](img/ecosistema_caja_arquitectura_sketchnote.jpg)

### Los Dos Grandes Pilares del Módulo

1. **Pilar 1 — Ventanilla Diaria (`/admin/caja`):**
   - **Apertura de Turno:** Validación de hardware (`UBEQ`), cajero (`CJR`) y horario (`CXT`), creando la sesión en `ACJ`.
   - **Importación de la Cola Médica:** Mecanismo *Traer Recibo* que transforma atenciones de Citas (`CIT`), Consulta Externa (`AUT`) y Hospitalización (`HADM`) en recibos oficiales `FCJ` sin digitación manual.
   - **Canasta de Cobros Mixtos:** Liquidación simultánea en efectivo, datáfonos con voucher, tarjetas a cuotas institucionales, cheques y consignaciones (`PCJ`).
   - **Egresos Autorizados:** Gestión de gastos urgentes, devolución ágil de copagos a usuarios y traslados seguros entre terminales.

2. **Pilar 2 — Supervisión y Auditoría (`/admin/procaja`):**
   - **Reporte de Cierre de Turno:** Cuadre de los recibos y medios de pago registrados durante la sesión.
   - **Anulación Controlada:** Cancelación formal de recibos con reversión automática de comprobantes contables sin alterar la auditoría.
   - **Auditoría Espejo:** Cotejo línea por línea entre los recibos emitidos (`FCJ`/`PCJ`) y los asientos de contabilidad (`MCP`/`MCH`).
   - **Contabilización Masiva:** Procesamiento por lote para asentar miles de recibos del mes sin demorar la fila de atención.

### Sincronización en Tiempo Real
- **Bancos (`BCT`):** Los pagos recibidos por transferencia o consignación incrementan de inmediato el saldo en bancos (`BCT.SALDO`) sin crear registros duplicados en `BMOV`.
- **Contabilidad General (`MCP`):** Cada recibo cerrado genera su comprobante contable automático en las cuentas PUC correspondientes (`1105`, `1110`, ingresos o gastos).

---

## 1. Visión General del Ciclo de Caja

El módulo de **Caja** es el punto neurálgico de recepción de dinero, liquidación de copagos de pacientes, administración de egresos de caja menor y puente en tiempo real con **Tesorería/Bancos** y **Contabilidad General**.

### Sketchnote: Ruta Completa del Dinero en Caja

![Ruta Completa del Dinero en Caja · Qrystalos ERP](img/ruta_completa_caja_sketchnote.jpg)

### Clarificación: El Viaje Clínico del Paciente hacia la Caja (No es una Plantilla de Excel)

> **Nota para el Usuario:** Las siglas `CIT`, `AUT`, `HADM`, `TFCJ` y `FCJ` **no son una plantilla de Excel** que el usuario deba diligenciar ni importar. Corresponden al **viaje clínico y administrativo del paciente en el sistema**:

![Integración Asistencial · Flujo de Traer Recibo en Qrystalos ERP](img/flujo_traer_recibo_sketchnote.jpg)

- **`CIT` (Citas Médicas):** Consulta asistencial agendada en la que se generó una cuota moderadora o copago.
- **`AUT` (Autorizaciones):** Procedimientos, exámenes de laboratorio o terapias generadas desde Consulta Externa.
- **`HADM` (Hospitalización):** Liquidación de copagos o abonos generados al ingreso del paciente internado.
- **`TFCJ` (Temporal de Facturas de Caja):** Bandeja virtual en espera donde el sistema encola automáticamente las atenciones médicas listas para ser cobradas.
- **`FCJ` (Factura / Recibo de Caja Oficial):** Comprobante legal definitivo emitido e impreso en ventanilla.

---

### Los 5 Pilares de Operación en Caja (Sketchnotes)

![Los 5 Pilares de Operación en Caja · Qrystalos ERP](img/cinco_pilares_caja_sketchnote.jpg)

#### 📌 Pilar 1: El Puente Clínico ➔ Recaudo
* **Cero digitación repetida:** Los servicios generados en Citas (`CIT`), Consulta Externa (`AUT`) y Hospitalización (`HADM`) viajan solos a la cola temporal (`TFCJ`).
* **Operación ágil:** El cajero pulsa **Traer Recibo**, selecciona el paciente por documento de identidad y el motor `SPK_TRAERECIB_CAJA` crea en el acto el recibo oficial `FCJ` con su detalle `FCJD`.
* **Reversibilidad asistencial:** Si el paciente desiste o no cuenta con los fondos, el cajero pulsa **Devolver Recibo** (`SPK_DEVUELVERECIB_CAJA`), devolviendo la orden médica a la agenda sin generar huecos contables ni borrar la atención.

#### 📌 Pilar 2: Canasta de Cobros Mixtos
* **Un solo recibo, múltiples billeteras:** Un mismo recibo (`FCJ`) puede liquidarse combinando múltiples medios de pago en la tabla `PCJ`.
* **Medios soportados:** Efectivo físico (`EFE`), datáfono con voucher (`TDD`/`TDC`), tarjetas institucionales a cuotas (`BCT.TARCRED=1` con tabla de amortización `BCTTAR`), cheques normales o posfechados (`CHQ`), y transferencias o consignaciones bancarias (`CON`).

#### 📌 Pilar 3: Afectación Bancaria en Tiempo Real
* **El dinero en banco no espera a fin de mes:** Al confirmar un recibo que incluya transferencias o consignaciones bancarias, el procedimiento `SPK_ACTUALIZA_SALDO_BANCO` suma de inmediato el dinero al saldo disponible de la cuenta institucional:
  $$\text{BCT.SALDO} = \text{BCT.SALDO} + \text{PCJ.VALOR}$$
* **Protección antiduplicidad:** No crea registros temporales en `BMOV` porque el recibo de caja causa su propio comprobante contable directo, evitando descuadres en la conciliación.

#### 📌 Pilar 4: El Doble Carril Contable
* **Carril 1 (En Línea):** Al confirmar cada recibo en ventanilla, el sistema genera de inmediato el comprobante contable (`MCP`/`MCH`) con procedencia `CAJA`.
* **Carril 2 (Reproceso por Lote):** La confirmación siempre invoca el motor contable en línea. Si un recibo queda pendiente de asiento por una salida controlada, error o reproceso, **Procesos de Caja** (`/admin/procaja`) permite seleccionarlo y ejecutar **Enviar a Contabilidad** (`SPK_CONTAB_MASIVA`), que reutiliza los mismos motores de ingreso y egreso.

#### 📌 Pilar 5: La Balanza de Cajas (Principal vs Menor)
* **Caja General / Principal:** Diseñada para recaudar. Al cerrar turno, el sistema consolida en `ACJD` los saldos calculados en `CAJR` por forma de pago. Los objetos leídos no capturan un conteo físico digitado por el cajero.
* **Caja Menor:** Diseñada para gastos menores y compras urgentes. Al cerrar la caja, el motor `SPK_SOL_REEMBOLSO_CAJAMENOR` no espera dinero: agrupa los egresos del turno, emite la Solicitud de Reembolso (`CMREE`), causa la Cuenta por Pagar (`FCXP`) a nombre del custodio y restablece el Fondo Fijo (`FOFI`).

---

## 2. Configuración Previa y Requisitos de Inicio

Antes de que un cajero pueda abrir turno en una terminal, deben existir 8 configuraciones activas en la base de datos:

| Paso | Catálogo / Tabla | Pantalla Qrystalos2 | Qué define |
|---|---|---|---|
| **1** | `CPCJ` | `/conf/cpcj` | Conceptos de caja (Copago, Particular, Devolución, Gastos Menores, Traslados). Asigna la `CUENTA` contable y el comprobante `COM`. |
| **2** | `FPA` | `/conf/fpa` | Formas de pago (Efectivo `EFE`, Tarjetas `TDC`/`TDD`, Cheque `CHQ`, Consignación `CON`). Configura si es físico, si pide datáfono o si exige cuenta bancaria. |
| **3** | `TUR` | `/conf/caja` (Pestaña Turnos) | Horarios de trabajo con franja inicial/final y días de la semana activos (`LUNES` a `DOMINGO`, `FESTIVO`). |
| **4** | `CAJ` | `/conf/caj` o `/conf/caja` | Catálogo de cajas físicas y virtuales. Define si es Principal, Auxiliar o Menor, su fondo fijo (`FOFI`), su cuenta contable y si acepta recaudos de cartera (`ACEPTARECAUDO=1`). |
| **5** | `CJR` | `/conf/caja` (Pestaña Cajeros) | Maestro de personal autorizado como cajero en la institución. |
| **6** | `CXT` | `/conf/caja` (Pestaña CXT) | Asignación obligatoria que vincula `CODCAJA + CODTURNO + CODCAJERO`. |
| **7** | `USVGS` | `/conf/sistemas/usvgs` | Variables del sistema: `IDCJAPERTURACAJA`, `IDCJAPERTURACJMENOR`, `IDCJ_TRASLADOENCAJAS`, `IDCJTEDEVOLRECIBO`, `IDCJDEPOSITO`, `IDCJTECXP`. |
| **8** | `UBEQ` | Configuración Hardware | La estación física donde se ubica el usuario debe tener `ESCAJA = 1` y el campo `CAJA = CODCAJA`. |

> **Regla de Oro:** Si falta cualquiera de estos 8 elementos, la pantalla no abre o bloquea el botón de apertura arrojando mensajes como *"No es Cajero"*, *"El equipo no es caja"* o *"Concepto de apertura sin definición"*.

---

## 3. Apertura de Caja y Turnos de Trabajo

### Validación de Entrada a Pantalla
Al montar la ruta `/admin/caja` (`CajaPage.vue`), el frontend invoca `SPQ_CONF_CAJA` con el método `VALIDA_INGRESO_PANTALLA`:
- Ejecuta la función SQL `FNK_VALIDA_TURNO_CAJA`.
- Comprueba que el usuario sea cajero activo (`CJR`).
- Comprueba que la terminal esté registrada en `UBEQ` como caja física (`ESCAJA = 1`).
- Comprueba que la caja exista en `CAJ` y que exista un turno vigente en `CXT` para el día y hora actual.
- Si la validación falla (`OK = 'KO'`), el sistema muestra el error en pantalla y a los 4 segundos redirige automáticamente al menú administrativo.

### Proceso de Apertura de Turno
Cuando el cajero pulsa el icono de candado y selecciona **Abrir Caja**:

```
[Cajero pulsa: Abrir Caja]
            │
            ▼
SPQ_CONF_CAJA · METODO: ABRIR_CAJA
            │
            ├── Valida: CAJ.ABIERTA = 0
            ├── Valida: No existan sesiones ACJ colgadas en estado abierto
            ├── Valida: Variable IDCJAPERTURACAJA exista en CPCJ
            │
            ▼
SPK_APERTURA_DE_CAJA
            ├── 1. Inserta registro en ACJ (consecutivo CNSACJ, fecha, cajero, turno)
            ├── 2. Actualiza CAJ: ABIERTA = 1, CNSACJ = @CNSACJ
            ├── 3. Genera recibo FCJ de apertura con DEAPERTURA = 1
            ├── 4. Vuelca en ACJD los saldos iniciales por forma de pago
            └── 5. En Caja Menor: Asigna saldo inicial = FOFI − reembolsos pendientes
```

Al finalizar, el indicador superior cambia a verde con estado **Abierta**, mostrando el cajero, el turno y el saldo actual de la sesión.

---

## 4. Movimientos de Ingreso y el Mecanismo "Traer Recibo"

El cajero dispone de dos caminos para registrar un ingreso en la pestaña **Mov. Ingreso**:

```
                        ┌───────────────────────────────┐
                        │      ¿Cómo llega el cobro?    │
                        └───────────────────────────────┘
                                   /         \
                      Cobro Asistencial       Cobro Directo / Particular
                             /                     \
                            ▼                       ▼
                    [Traer Recibo]           [Nuevo Recibo]
                    Lee cola TFCJ            Digita Afiliado/Tercero
                    desde Citas/AUT          y agrega conceptos FCJD
                            │                       │
                            └───────────┬───────────┘
                                        ▼
                            Liquidación Formas de Pago
                            (Efectivo, Tarjeta, Cheque)
                                        │
                                        ▼
                                [Confirmar Recibo]
```

### A. El Mecanismo "Traer Recibo" (Integración Asistencial)
Cuando el médico atiende en agenda o el autorizador aprueba una orden en Consulta Externa, el sistema **no** obliga al paciente a dictar nuevamente qué exámenes o citas va a pagar. El software genera un comprobante temporal en la tabla `TFCJ` (con su detalle `TFCJD`).

1. El cajero pulsa el botón **Traer Recibo** (`BrwCaja / traerCompobanteIngreso`).
2. Se abre un diálogo con la lista de órdenes y citas pendientes de pago.
3. Al seleccionar el paciente, `SPQ_CONF_CAJA` ejecuta `TRAER_COMPROBANTE` y el motor `SPK_TRAERECIB_CAJA`:
   - Lee el registro `TFCJ` y su detalle `TFCJD`.
   - Genera el consecutivo legal definitivo en `FCJ` y sus líneas en `FCJD`.
   - Asocia el identificador de la cita (`CIT`) o de la autorización (`AUT`).
   - Legaliza depósitos asistenciales previos si existían (`QXDING`).
   - Elimina el comprobante temporal `TFCJ` para que nadie más lo cobre por error.
4. El recibo queda cargado en pantalla en estado **No Confirmado** listo para liquidar medios de pago.

> **¿Qué pasa si el paciente desiste o no tiene fondos?**  
> El cajero pulsa el botón **Devolver Recibo** (acción Devolver Recibo). La plataforma revierte la operación: descompone el recibo `FCJ` abierto y lo regresa a la cola temporal `TFCJ`, permitiendo que la cita médica o autorización continúe vigente para ser atendida o reprogramada.

---

## 5. Las Diferentes Formas de Pago y su Operación

Un recibo no se limita a un único medio de cobro. Qrystalos permite cobros combinados en la tabla `PCJ` (`CRUDFPA` / `CRUDFPA_2`):

### 1. Efectivo Físico (`EFE`)
- Configurado con `FISICO = 1`.
- Afecta directamente el efectivo disponible en poder del cajero (`CAJR`).
- Si se ingresan varios montos en efectivo, el sistema acumula el valor en una sola línea `PCJ` física.

### 2. Tarjetas Débito y Crédito vía Datáfono (`TDD` / `TDC`)
- Configurado con `DATAFONO = 1`, `REQAUT = 1` y `REQDOC = 1`.
- Exige ingresar: últimos 4 dígitos de la tarjeta (`DIGITOS_TARJETA`), franquicia (Visa, MasterCard, etc.), número de comprobante/aprobación (`NUMEROAUTORIZA`) y código de transacción (`ID_TRANSACCION`).
- No suma efectivo físico; queda discriminado en el cuadre de formas de pago del turno.

### 3. Tarjeta de Crédito Institucional (`BCT.TARCRED = 1`)
- Se utiliza cuando la institución ofrece financiamiento directo o maneja convenios corporativos.
- El sistema marca `PCJ.TARCRED = 1` y exige el número de cuotas mensuales (`NCUOTAS`).
- Al confirmar el recibo, **no** genera un movimiento bancario `BMOV`, sino que divide el saldo en `NCUOTAS` registros en la tabla de amortización `BCTTAR` y descuenta el cupo disponible `BCT.CUPODISP`.

### 4. Cheques (`CHQ`)
- Configurado con `GENCHEQUE = 1` y `REQBCO = 1`.
- Almacena el banco librador, la sucursal, la cuenta del cliente y el número de cheque (`NUMERODOCUMENTO`).
- Permite cheques posfechados marcando `POSFECHADO = 1` y registrando la fecha futura de consignación (`FECHAPOST`).

### 5. Consignaciones y Transferencias Bancarias (`CON`)
- Configurado con `REQCTA_BCO_DEP = 1` y `REQDOC = 1`.
- El cajero selecciona la cuenta bancaria de la empresa (`BANCO_DEP`, `CTA_BCO_DEP`) y digita el número de comprobante o autorización de la transferencia bancaria.
- Este medio dispara la afectación directa del saldo bancario al confirmar (ver sección 8).

---

## 6. Facturación Electrónica de Copagos y Cuotas Moderadoras (Emisión DIAN en Ventanilla)

Por mandato fiscal y normativo de los entes reguladores de salud y la administración tributaria (DIAN), las Instituciones Prestadoras de Salud (IPS) están obligadas a expedir **Factura Electrónica de Venta (FEV)** o documento equivalente por los recursos recaudados directamente de los usuarios en concepto de **copagos, cuotas moderadoras o servicios particulares**.

Qrystalos integra este requerimiento de manera transparente y automática dentro del flujo de ventanilla en `/admin/caja`: el cajero recauda normalmente en el recibo de caja (`FCJ`), y el motor financiero genera en segundo plano la factura electrónica (`FTR`), reserva el consecutivo oficial DIAN, causa la cuenta por cobrar y asienta el recaudo automático para mantener la cartera saldada en $0.

### Sketchnote: Facturación Electrónica del Copago en Caja

![Facturación Electrónica del Copago en Caja · Qrystalos ERP](img/factura_electronica_copago_caja_sketchnote.jpg)

### Los 4 Pilares del Circuito Fiscal del Copago

#### 📌 1. Identificación y Clasificación del Concepto Fiscal
- El recibo de caja (`FCJ` / `FCJD`) se origina habitualmente desde el botón **Traer Recibo** (`TFCJ ➔ FCJ`), arrastrando la prestación médica desde Citas (`CIT`), Consulta Externa (`AUT`) u Hospitalización (`HADM`).
- El sistema determina que el recibo debe facturarse electrónicamente si el concepto `FCJD.CONCEPTO` se encuentra homologado como copago en el catálogo de modelos de contratación (`MOCC.CODIGOCPCJ`) o si el concepto de caja tiene activa la marca fiscal `CPCJ.NDIAN = 1`.

#### 📌 2. Disparo del Motor SQL (`SPK_CREA_FACTURA_POS_CAJA`)
Al presionar **Confirmar Recibo** en la interfaz diaria (`CAJMovinComponent`), el procedimiento principal `SPK_CIERRERECIBO_CAJA` valida las variables institucionales:
1. **Condición de Activación:** Verifica que la variable del sistema `FACTURAPOS_ACTIVA = 'SI'`. Si además el copago iguala o supera el servicio y `FACTU_COPA_MAYOR_SER = 'SI'`, fuerza la liquidación directa a tarifa particular.
2. **Consecutivo DIAN:** Invoca `SPK_GENNUMEROFACTURA` y `SPK_GENCONSECUTIVO`, reservando el siguiente número disponible de la resolución activa en la tabla `FDIAN` configurada para la sede y procedencia.
3. **Generación del Documento `FTR`:** Inserta la cabecera en `FTR` con `PROCEDENCIA = 'CAJA'`, clase de factura contado, asociando el afiliado como tercero beneficiario y vinculando la referencia `NOREFERENCIA = CODCAJA + CNSFACJ`. Inserta el ítem en `FTRD` con el valor exacto del copago.
4. **Vínculo en el Recibo:** Actualiza el recibo de caja asignando `FCJ.N_FACTURAPOS = @N_FACTURA` y `FCJ.RECAUDO = 1`.

#### 📌 3. Saneamiento Inmediato de Cartera (Saldo Neto $0)
Un error operativo habitual en sistemas ERP desconectados es que emitir una factura genera una cuenta por cobrar pendiente en cartera, requiriendo cruces manuales posteriores. Qrystalos resuelve esto de forma atómica:
- Ejecuta `SPK_ADMIN_CXC_CONTAB`: Inserta el registro de cuenta por cobrar particular en `FCXC` y `FCXCDV`.
- Ejecuta `SPK_ADMIN_PAGOS` con procedencia `CXC`: Genera de inmediato el recibo de recaudo `FPAG` y el registro de cruce `FCJPCXC`.
- **Efecto Contable y Financiero:** La cartera queda saldada en **$0** en el mismo segundo de la confirmación. No quedan cuentas por cobrar abiertas ficticias para el paciente.
- Ejecuta `SPK_NC_CONTAB_FTR`: Contabiliza la factura `FTR` en el libro mayor (`MCP`/`MCH`), marcando `FCXC.CONTABILIZADA = 1` y `FPAG.CONTABILIZADO = 1`.

#### 📌 4. Trazabilidad Clínica y Entrega al Paciente
- **Trazabilidad en orígenes:**
  - Si vino de Consulta Externa / Citas: Actualiza `CIT.NFACTURA = @N_FACTURA` y `CIT.FACTURADA = 1`.
  - Si vino de Autorizaciones: Actualiza `AUTD.NFACTURA = @N_FACTURA`.
  - Si vino de Hospitalización: Inserta el registro correspondiente en `HADMF` con descripción `'COPAGOS'`.
- **Experiencia del Cajero en Ventanilla:**
  - Al hacer clic en el botón de **Imprimir Recibo**, el componente `CAJMovinComponent` detecta que el registro posee `N_FACTURAPOS`.
  - El sistema presenta un diálogo de decisión interactivo:  
    *«Este recibo tiene factura asociada. ¿Qué desea imprimir? [Recibo de Caja] | [Factura]»*.
  - Al seleccionar **Factura**, se genera el reporte oficial `ImprimeFormatoFtr` (formato `CAJ01` o media carta) provisto de código QR, representación gráfica del CUFE, numeración autorizada por la DIAN y detalle del servicio para entrega inmediata al paciente.
- **Encolamiento FEV:** La factura `FTR` queda disponible en la consola de **Proceso DIAN** (`FTREComponent` / `FTRFE_COL`) para la transmisión electrónica y validación del XML ante los servidores de la DIAN.

### Variables del Sistema (USVGS) que Gobiernan este Proceso

| Variable USVGS | Tipo / Valor Sugerido | Propósito en el Proceso |
|---|---|---|
| `FACTURAPOS_ACTIVA` | `Texto (SI / NO)` → **`SI`** | Enciende el motor de facturación electrónica automática al confirmar recibos de copago en ventanilla. |
| `FACTU_COPA_MAYOR_SER` | `Texto (SI / NO)` → **`SI`** | Si el copago iguala o supera el servicio, emite factura a tarifa particular para el paciente. |
| `IDFORMATOFTR_CAJA` | `Texto` → **`CAJ01`** | Formato de impresión oficial (tirilla o carta) que incorpora CUFE, QR y resolución DIAN. |
| `IDPLANPART` | `Código Plan (PLN)` → **`PART`** | Plan tarifario particular asignado por defecto a la factura electrónica del copago. |
| `IDTERCEROPARTICULAR`| `Código Tercero (TER)` → **`PARTICULAR`** | Tercero particular institucional asignado para clasificar la emisión fiscal de la factura de copago. |
| `IDTERCONTABLEPART` | `Código Tipo Tercero` → **`PART`** | Tipo de tercero contable que determina la cuenta PUC de cartera particular para la factura. |
| `UVT_MAX_FACTURAPOS` | `Numérico` → **`5`** | Límite en UVT para clasificar entre documento equivalente POS y factura electrónica plena FTR. |
| `BLOQUEADIAN` / `FACTSEDE` | `Texto (SI / NO)` → **`SI`** | Exige resolución DIAN vigente por sede (`FDIAN`); bloquea la confirmación si la resolución está vencida. |

---

## 7. Movimientos de Egreso, Caja Menor y Traslados

En la pestaña **Mov. Egreso**, se registran todas las salidas autorizadas de fondos de la caja (consecutivo con prefijo 'E' y `CLASE_FAC = 'PAGO'`).

### Sketchnote: Principales Tipos de Egreso en Caja

![Principales Tipos de Egreso en Caja · Qrystalos ERP](img/tipos_egreso_caja_sketchnote.jpg)

### Sketchnote: Ciclo Completo de Egresos y Reembolso de Caja Menor

![Ciclo Completo de Egresos y Reembolso de Caja Menor · Qrystalos ERP](img/ciclo_egresos_caja_menor_sketchnote.jpg)

### Las 4 Fases del Flujo de Egresos y Reembolso

1. **Fase 1 — Puntos de Salida Autorizada:**
   - **Gastos menores:** Compras de insumos urgentes, papelería, cafetería o viáticos validados estrictamente contra el tope máximo por pago (`CAJ.MAXPAGOCM`).
   - **Devolución de copagos:** Reembolso a pacientes por citas o procedimientos cancelados, con trazabilidad automática al recibo original (`CNSFACJDEP`) marcando `FCJ.DEVUELTO = 1`.
   - **Pago a proveedores CXP:** Pago directo de facturas de compras urgentes o anticipos (`IDCJTECXP`).
   - **Traslados entre cajas:** Envío de fondos a otras terminales asegurando que la caja destino se encuentre activa y abierta (`CAJ.ABIERTA = 1`).

2. **Fase 2 — Registro y Validación en Ventanilla:**
   - Generación del recibo oficial `FCJ` con `CLASE_FAC = 'PAGO'`.
   - Registro de salida en la grilla de pagos `PCJ` (efectivo físico o cheque).
   - Validación de consistencia: sumatoria de pagos igual al valor total del comprobante y periodo contable `PRI` abierto.

3. **Fase 3 — Cierre y Cuadre del Turno:**
   - El sistema valida que no haya recibos pendientes ni errores contables y consolida los valores registrados por forma de pago. El control físico de soportes es una actividad operativa externa; no se captura en los objetos SQL documentados.

4. **Fase 4 — Reposición y Reembolso Automático:**
   - Al cerrar la caja de clase Menor, el procedimiento `SPK_SOL_REEMBOLSO_CAJAMENOR` consolida en un solo paso todos los egresos del periodo.
   - Genera la Solicitud formal de Reembolso `CMREE`.
   - Causa automáticamente la Cuenta por Pagar `FCXP` a nombre del custodio (`CAJ.RESPONSABLE`).
   - Tesorería emite el pago de reposición, restableciendo el Fondo Fijo (`FOFI`) para el siguiente ciclo operativo.

### Estructura de las 5 Salidas Autorizadas de Dinero

#### 📌 1. Gastos Menores (Caja Menor)
* **Destino:** Compras operativas del día como papelería, fotocopias, cafetería y transporte urbano.
* **Control de Seguridad:** El valor está rigurosamente validado por el sistema contra el tope máximo por pago de caja menor configurado en `CAJ.MAXPAGOCM`.
* **Cierre:** Al cerrar el turno, estos egresos se consolidan automáticamente para reposición del fondo fijo vía `SPK_SOL_REEMBOLSO_CAJAMENOR`.

#### 📌 2. Devolución de Copagos
* **Destino:** Reembolso de dinero al paciente por citas no atendidas, desistimiento o cobros indebidos.
* **Trazabilidad Automática:** Concepto configurado en la variable `IDCJTEDEVOLRECIBO`. Al insertar el pago con `CRUDFPA_EGRESO_DEVOLUCION`, se vincula el recibo original de cobro (`CNSFACJDEP`) y el sistema marca en automático `FCJ.DEVUELTO = 1` en el ingreso de origen para evitar duplicidad de devoluciones.

#### 📌 3. Anticipos y Pago de Cuentas por Pagar (CXP)
* **Destino:** Pago inmediato a proveedores de insumos, servicios o cancelación de anticipos.
* **Código de Egreso:** Asignado en la variable `IDCJTECXP`. Permite pagar órdenes de compra (`FCOM`) o amortizar facturas de proveedores (`FCXP`), actualizando saldos de cartera con `SPK_ADMIN_PAGOS`.
* **Requisito:** Exige que la variable del sistema `IDCJTECXP_EDITAR` se encuentre en `SI`.

#### 📌 4. Traslados entre Cajas
* **Destino:** Envíos de dinero entre terminales físicas o cajas auxiliares de la institución.
* **Candado Operativo:** Concepto configurado en `IDCJ_TRASLADOENCAJAS`. Exige que la caja destino exista, esté activa y se encuentre en estado **ABIERTA** (`CAJ.ABIERTA = 1`).
* **Seguridad:** El sistema prohíbe la anulación directa desde ventanilla para prevenir descuadres entre terminales.

#### 📌 5. Consignación al Banco
* **Destino:** Salida física de efectivo acumulado en la caja para depósito formal en la cuenta corriente o de ahorros de la entidad financiera.
* **Efecto Contable:** Resta del efectivo físico en poder del cajero (`CAJR`) y genera el asiento que acredita Caja (`1105`) y debita Depósitos en Tránsito o Bancos. Posteriormente, Tesorería lo concilia formalmente en el módulo de Bancos (`/admin/Cuentas`).

### Confirmación de Egresos
Al presionar **Confirmar Egreso** (`BrwCajaEgresos / confirmarEgreso`):
- Se valida que `SUM(PCJ.VALOR) == FCJ.VALORTOTAL`.
- Se valida que el periodo contable `PRI` esté abierto.
- Ejecuta `SPK_CIERRERECIBO_CAJA` (rama de egreso) sellando `CERRADA = 1`.
- Ejecuta `SPK_NC_CONTAB_CAJA_EGR` generando el comprobante contable de salida (Débito: Cuenta de Gasto/Proveedor/Traslado según `CPCJ.CUENTA`, Crédito: Caja `1105`).

---

## 8. Consignaciones y el Efecto en Bancos

La interacción entre el dinero de Caja y el módulo de **Tesorería y Bancos** ocurre bajo dos modalidades distintas:

```
                          ┌────────────────────────────────────────────────────────┐
                          │                 MÓDULO DE CAJA                         │
                          └────────────────────────────────────────────────────────┘
                                      │                                │
                MODALIDAD 1:          │                  MODALIDAD 2:  │
         Paciente paga en Caja con    │             Cajero consigna el │
         Consignación o Transferencia │             efectivo en Banco  │
                                      ▼                                ▼
                         SPK_ACTUALIZA_SALDO_BANCO             Egreso de Caja (Efectivo)
                                      │                                │
                        ┌─────────────┴─────────────┐                  ▼
                        ▼                           ▼             Boleta de Consignación
                  Actualiza BCT            Contabilidad MCP            │
                 SALDO = SALDO+VLR          Debita Banco 1110          ▼
              (Sin duplicar BMOV)          Acredita Ingreso       MÓDULO DE BANCOS
                                                                  (/admin/Cuentas)
                                                                       │
                                                                       ▼
                                                                Crea BMOV / BMOVD
                                                                 (Operación OFIN)
                                                                       │
                                                                       ▼
                                                                SPK_OK_BMOV
                                                                (Confirmación y
                                                                 Conciliación)
```

### Modalidad 1: Paciente paga en Caja mediante Consignación o Transferencia
- El paciente presenta el comprobante bancario del pago realizado a la cuenta de la institución.
- En la pestaña de medios de pago (`PCJ`), se selecciona la forma de pago consignación (`FPA.REQCTA_BCO_DEP = 1`) y se selecciona la cuenta bancaria destino (`BCT`).
- **Al confirmar el recibo (`CONFIRMAR_RECIBO`):**
  - Se ejecuta el procedimiento `SPK_ACTUALIZA_SALDO_BANCO`.
  - Este procedimiento actualiza de inmediato el saldo disponible de la cuenta en `BCT`:
    $$\text{BCT.SALDO} = \text{BCT.SALDO} + \text{PCJ.VALOR}$$
  - En la contabilidad (`SPK_NC_CONTAB_CAJA_ING`), no se debita la cuenta `1105` (Caja General), sino que se debita directamente la cuenta contable asociada al banco (`BCT.COD_CONTABLE`, ej. `11100501`).
  - **Evita duplicidad:** No genera una fila en `BMOV` porque el recibo de caja ya emitió su propio comprobante contable `MCP` con procedencia `CAJA`.

### Modalidad 2: Consignación física de la Caja al Banco
- Al final de la jornada o al acumular sumas importantes de efectivo, el cajero retira el dinero físico y lo consigna en la cuenta bancaria de la empresa.
- **Paso 1 (En Caja):** Se genera un recibo de **Egreso** por concepto de consignación/traslado a banco. El pago en `PCJ` es de tipo `Efectivo` (restando del efectivo en mano). Contabilidad genera el asiento: Debita Bancos/Depósitos en tránsito y Acredita Caja `1105`.
- **Paso 2 (En Tesorería / Bancos - `/admin/Cuentas`):**
  - Tesorería registra el movimiento bancario en `BMOV` y su detalle `BMOVD` con la operación financiera (`OFIN`) de consignación.
  - Al confirmar el movimiento (`CONFIRMARBMOV` ──> `SPK_OK_BMOV`), el saldo `BCT.SALDO` queda conciliado con el extracto bancario oficial en la conciliación bancaria (`BCTC` / `CONCBMOVComponent`).
- **Paso 3 (Si es Recaudo de Cartera):**
  - Si la consignación provino del pago de una EPS por facturas de venta, Tesorería marca `BMOVD.RECAUDO = 1`.
  - El módulo de **Recaudos de Cartera** (`/admin/Recaudos`) busca ese `BMOVD` confirmado y lo cruza contra las cuentas de cobro del cliente (`FPAG` / `FPAGD`), legalizando el recaudo.

---

## 9. Cierre de Caja, Cuadre de Medios y Reembolso

Al finalizar el turno o jornada laboral, el cajero pulsa el candado y selecciona **Cerrar Caja** (`CERRAR_CAJA` en `SPQ_CONF_CAJA`).

### Validaciones Obligatorias de Cierre
El sistema valida que no existan inconsistencias operativas:
1. **Recibos sin confirmar:** Comprueba que **NO existan recibos en estado `P` con `CERRADA = 0`**. Si hay recibos pendientes, el cierre se aborta y la pantalla lista los números de recibo para que el cajero los confirme o los deseche (`DESHACER_INGRESO` / `DESHACER_EGRESO`).
2. **Errores contables:** Valida que ningún recibo haya dejado comprobantes en la tabla de errores contables `MCPE`.
3. **Tope en Cajas Auxiliares:** El efectivo recaudado no puede superar el límite configurado en `CAJ.FOFI`.

---

### Bifurcación del Cierre según la Clase de Caja

```
                     ┌─────────────────────────────┐
                     │   CERRAR_CAJA (Validado)    │
                     └─────────────────────────────┘
                                    │
                    ¿Cuál es la CLASE de la caja?
                   /                             \
     General / Principal / Auxiliar               Caja Menor
                 │                                    │
                 ▼                                    ▼
        SPK_CIERRE_DE_CAJA               SPK_SOL_REEMBOLSO_CAJAMENOR
                 │                                    │
                 ├── CAJ.ABIERTA = 0                  ├── 1. Ejecuta SPK_CIERRE_DE_CAJA
                 ├── ACJ.FECHACIERRE = GETDATE()      ├── 2. Agrupa egresos no contabilizados
                 ├── ACJD: vuelca saldos finales      ├── 3. Crea solicitud reembolso CMREE
                 │   por cada forma de pago           ├── 4. Crea Cuenta por Pagar (FCXP)
                 └── Asiento contable de cierre       │      a nombre de CAJ.RESPONSABLE
                     (SPK_NC_CONTAB_CIERRE_CAJ)       └── 5. Genera asiento de reembolso
                                                             (MCPE/MCHE procedencia CAJAMENOR)
```

1. **Caja General / Principal (`SPK_CIERRE_DE_CAJA`):**
   - Actualiza `CAJ.ABIERTA = 0`.
   - Estampa la fecha y hora final en `ACJ.FECHACIERRE`.
   - Vuelca en `ACJD` los saldos finales calculados en `CAJR` por cada medio de pago.
   - Si la variable `MAN_CIERRE_CONT_CAJA` está en `SI`, dispara `SPK_NC_CONTAB_CIERRE_CAJ` para generar el comprobante contable de cierre de caja.

2. **Caja Menor (`SPK_SOL_REEMBOLSO_CAJAMENOR`):**
   - Ejecuta el cierre de turno sellando la sesión.
   - Agrupa todos los egresos del turno que no fueron contabilizados de forma individual.
   - Genera una **Solicitud de Reembolso de Caja Menor** (`CMREE`).
   - Genera una **Cuenta por Pagar** (`FCXP`) a favor del responsable de la caja (`CAJ.RESPONSABLE`) por el monto exacto gastado.
   - Genera el comprobante contable agrupado `MCPE`/`MCHE` con procedencia `CAJAMENOR`, cargando los gastos a sus cuentas contables y acreditando la cuenta por pagar `CAJ.CUENTACXP_CM`. Al pagarse la `FCXP`, el fondo fijo de la caja menor queda 100% restablecido.

---

## 10. Procesos de Caja (/admin/procaja) · Consola de Supervisión y Auditoría

En el menú principal de Qrystalos ERP (sección **Administrativo**), el botón **Procesos de Caja** da acceso a la consola centralizada de control, reportes, auditoría y contabilidad posterior (`/admin/procaja` · `ProCajaPage.vue` ➔ `ProCajaComponent.vue`).

### Sketchnote: Consola de Supervisión y Auditoría (Procesos de Caja)

![Procesos de Caja · Consola de Auditoría y Supervisión en Qrystalos ERP](img/procesos_caja_consola_sketchnote.jpg)

### Diferencia Fundamental: Caja Operativa vs Procesos de Caja

| Criterio | Caja Operativa (`/admin/caja`) | Procesos de Caja (`/admin/procaja`) |
|---|---|---|
| **Propósito** | Ventanilla de cobro diario con paciente presente. | Auditoría, control, reimpresiones y contabilidad. |
| **Exigencia UBEQ** | **Sí:** la terminal física debe tener `ESCAJA = 1`. | **No:** accesible desde cualquier equipo administrativo. |
| **Exigencia Cajero** | **Sí:** el usuario debe existir en `CJR`. | **No:** accesible por supervisores, auditores y contadores. |
| **Exigencia Turno** | **Sí:** exige caja abierta (`CAJ.ABIERTA=1`) y turno `CXT`. | **No:** no exige tener caja abierta ni turno activo. |
| **Permiso Base** | `BrwCaja`, `BrwCajaEgresos`. | `IDPROCEDIMIENTO = MENUQ_CAJA` en `USGRUH`. |

---

### Los 4 Cuadrantes y las 12 Pestañas de Procesos de Caja

#### 🟦 Cuadrante 1: Reportes y Cierres de Turno
1. **Recaudo por Fecha (`recaudoPorFecha` · `RecaudoPorFechaComponent`):**
   - Consulta consolidada de ingresos y egresos por rango de fechas, clase (`COBRO`/`PAGO`), filtros multicaja, formas de pago, terceros y cajeros.
   - Genera 6 reportes oficiales en PDF vía `useCajaReportes`:
     - `00001` LGD: Listado general detallado por fecha.
     - `00002` FPDSUB: Formas de pago detallado con subtotales.
     - `00003` FPA: Resumen general por forma de pago.
     - `00004` CDSUB: Conceptos de caja detallado con subtotales.
     - `00005` CA: Consolidado general por caja.
     - `00006` MB: Movimientos de bancos y transferencias.
2. **Reportes de Cierre (`reporteDeCierre` · `ReportesDeCierreComponent`):**
   - Búsqueda por Consecutivo de Apertura (`CNSACJ`) de sesiones de caja (`ACJ`).
   - Genera informes de cuadre desde los valores registrados: detalle de la sesión (`IMPRIME_ARQUEO_EGRESO`), desglose por forma de pago (`IMPRIME_ARQUEO_EGRESO_FPA`), recibos pagados (`RPT_RECIBOS_PAGADOS_TURNO`) y formas de pago del turno (`RPT_FORMA_PAGO_TURNO`). El nombre histórico «arqueo» no implica captura de conteo físico.
3. **Reimpresión de Recibos (`reimpresion` · `ReimpresionDeRecibosDeCaja`):**
   - Búsqueda de recibos históricos por caja y consecutivo (`CNSFACJ`).
   - Permite regenerar la tirilla POS o la representación gráfica en PDF carta para entrega de duplicados al usuario o auditoría.

#### 🟧 Cuadrante 2: Control y Auditoría Operativa
4. **Monitor de Recaudos en Caja (`recaudoEnCaja` · `RecaudosEnCajaComponent`):**
   - Tablero de control que supervisa en tiempo real el dinero vivo recaudado en cada caja física o auxiliar.
   - Desglosa la tabla `CAJR` mostrando el saldo actual clasificado por efectivo, comprobantes de datáfono, cheques y transferencias.
5. **Anular Recibos Confirmados (`anularRecibosM` · `AnularRecibosComponent`):**
   - Proceso formal de anulación mediante `MODELO: "FCJ", METODO: "ANULAR_RECIBO"` (`SPK_ANULARECIBO_CAJA` y `SPK_REVERSAR_MCP`).
   - Cambia el estado del recibo a `ESTADO = 'A'`, restituye la cita médica (`CIT`) o autorización (`AUT`) a su estado pendiente original, reversa el saldo bancario si provino de consignación y causa el contrasiento o anulación contable.
6. **Cobros NO Recaudados (`cobrosNORecaudados` · `CobrosNORecaudados`):**
   - Lista atenciones y órdenes médicas en cola temporal (`TFCJ`) que nunca fueron pagadas en ventanilla.
   - Permite exportar a Excel, generar el informe oficial `rpt_COBROSNR` y anular citas desistidas (`CONF_CAJA` · `ANULAR_COMPROBANTE`) si el usuario tiene el permiso complementario `anular_recibo`.
7. **Histórico de Recibos Anulados (`recibosAnulados` · `RecibosAnulados`):**
   - Consulta y emisión del reporte de auditoría `rpt_R_A` con todos los recibos cancelados, discriminando fecha, caja, usuario responsable y justificación.

#### 🟩 Cuadrante 3: Gestión Contable y Tesorería
8. **Contabilización Masiva (`contabilizacion` · `ContabilizacionComponent`):**
   - Herramienta para contabilizar por lote los recibos confirmados que tienen `CONTABILIZADA = 0`.
   - Ejecuta `CONF_CAJA` · `ENVIAR_RECIBOS_CONTABILIDAD` invocando el motor `SPK_CONTAB_MASIVA` con procedencia `CAJA`, creando los comprobantes `MCP` en bloque sin demorar la fila de pacientes en ventanilla.
9. **Seguimiento Contable en Espejo (`seguimientoContable` · `SeguimientoContableComponent`):**
   - Pantalla de auditoría comparativa a doble columna:
     - **Columna Izquierda (Operación):** Recibo `FCJ`, desglose de conceptos `FCJD` y medios de pago `PCJ`.
     - **Columna Derecha (Contabilidad):** Comprobante contable `MCP` y sus asientos de débito/crédito en `MCH`.
     - **Barra de Chips:** Totales en vivo de Ingresos, Egresos en Efectivo, Egresos en Bancos, Egresos en Otras Formas de Pago y Saldo/Diferencia.
10. **Auxiliar de Caja (`auxiliarDeCaja` · `AuxiliarDeCajaComponent`):**
    - Genera el reporte auxiliar contable por cuentas y cajas (`CAJA_RPT` · `AUX_CAJA`).
    - Vuelca la información de saldo inicial, débitos, créditos y saldo final en la tabla temporal `RPDX2` para exportación a Excel y cruce con el libro mayor.
11. **Flujo de Caja (`flujoCaja` · `FlujoCajaComponent`):**
    - Genera el informe financiero `rpt_FLUJO_CAJ` para evaluación de liquidez institucional, discriminando entradas y salidas en el tiempo.

---

### Matriz de Permisos del Módulo (USPROH)

Todos los accesos de este módulo se configuran bajo el procedimiento padre **`IDPROCEDIMIENTO = MENUQ_CAJA`** en la tabla de permisos de grupos **`USGRUH`**:

| Pestaña en Pantalla | IDCONTROL (USPROH) | Componente Vue | Rol Habitual |
|---|---|---|---|
| **Recaudo por Fecha** | `recaudoPorFecha` | `RecaudoPorFechaComponent` | Supervisor / Auditor |
| **Reportes de Cierre** | `reporteDeCierre` | `ReportesDeCierreComponent` | Supervisor / Cajero Ppal |
| **Reimpresión** | `reimpresion` | `ReimpresionDeRecibosDeCaja` | Ventanilla / Atención |
| **Recaudos en Caja** | `recaudoEnCaja` | `RecaudosEnCajaComponent` | Tesorero / Auditor |
| **Anular Recibos** | `anularRecibosM` | `AnularRecibosComponent` | Supervisor de Caja |
| **Reportes Generales** | `reporte` | `ReportesCajaComponent` | Coordinador de Caja |
| **Cobros NO Recaudados** | `cobrosNORecaudados` | `CobrosNORecaudados` | Facturación / Cartera |
| **Anular en Pendientes** | `anular_recibo` | Acción en `CobrosNORecaudados` | Supervisor de Caja |
| **Recibos Anulados** | `recibosAnulados` | `RecibosAnulados` | Auditoría Interna |
| **Flujo de Caja** | `flujoCaja` | `FlujoCajaComponent` | Director Financiero |
| **Contabilización** | `contabilizacion` | `ContabilizacionComponent` | Contador General |
| **Seguimiento Contable**| `seguimientoContable` | `SeguimientoContableComponent`| Contador / Auditor |
| **Auxiliar de Caja** | `auxiliarDeCaja` | `AuxiliarDeCajaComponent` | Contador General |

---

## 11. Matriz de Soporte y Preguntas Frecuentes

| Síntoma o Error | Causa Raíz | Solución para Soporte / Administrador |
|---|---|---|
| *"No es Cajero"* | El usuario no está en la tabla `CJR`. | Crear el usuario en `/conf/caja` pestaña Cajeros. |
| *"El equipo no es caja"* | La terminal cliente no está registrada en `UBEQ`. | En `UBEQ`, buscar la máquina física y activar `ESCAJA = 1` con el código de caja asignado. |
| *"No tiene turno configurado"* | No existe asignación vigente en `CXT` o el turno `TUR` no cubre la hora/día actual. | Revisar en `/conf/caja` la matriz Caja-Turno-Cajero (`CXT`) y verificar que el turno incluya el día de la semana. |
| *"Concepto IDCJAPERTURACAJA no existe"* | La variable `USVGS` está vacía o el código no está en `CPCJ`. | Configurar la variable en `/conf/sistemas/usvgs` y verificar que exista en el catálogo de conceptos `/conf/cpcj`. |
| *No se ven las pestañas de Ingreso/Egreso* | La caja está cerrada, no hay caja seleccionada o el saldo es negativo. | Abrir la caja desde el candado superior o seleccionar la caja asignada al usuario. |
| *Botón Confirmar deshabilitado* | La suma de `PCJ` no coincide con el total del recibo (`FCJ.VALORTOTAL`). | Verificar el detalle de formas de pago; debe cuadrar peso a peso con el valor del recibo. |
| *Error al confirmar: "Periodo Cerrado"* | El mes/año del recibo pertenece a un periodo contable bloqueado en `PRI`. | Abrir el periodo en Contabilidad o corregir la fecha del recibo si el usuario tiene permiso `FCJ:Ficha`. |
| *Cierre de caja bloqueado por recibos pendientes* | Existen recibos en estado `P` sin confirmar (`CERRADA = 0`). | El cajero debe filtrar por "No confirmados" y proceder a confirmarlos o desecharlos con el botón Desechar. |
