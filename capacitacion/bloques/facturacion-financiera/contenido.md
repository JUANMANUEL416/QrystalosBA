# 📄 Factura financiera: evento, cápita y PGP

## Contexto

**Proceso:** Facturación  
**Capa:** 02 - Operación

La **Nueva Factura** (botón en Administrativo → Facturación) crea una factura con **PROCEDENCIA = FINANCIERO**. Esta procedencia significa que el usuario construye la factura manualmente: elige el plan, agrega líneas de servicios y ajusta valores. Según el plan seleccionado, la factura puede ser **por evento** (cobra cada prestación), **cápita** (pago fijo por afiliado con relación de servicios) o **PGP** (Pago Global Prospectivo por período).

## Explicación

Una **factura** en Qrystalos tiene dos componentes principales:
1. **Cabecera** (tabla `FTR`): datos del responsable, plan, fecha de emisión, tipo de facturación (evento/cápita/PGP), número de factura, estado (borrador, contabilizada, impresa, anulada).
2. **Líneas** de servicios:
   - **`FTRD`** (detalle financiero): líneas de prestaciones, medicamentos o insumos con cantidad, valor unitario, valor total, IVA, centro de costo. Siempre presente en facturas por evento; también aparece en cápita/PGP.
   - **`FTRDC`** (relación capitada): cuando `CAPITADA=1`, esta tabla relaciona los afiliados atendidos y las prestaciones ejecutadas (CUPS, medicamentos) que justifican el pago capitado. Requerida para cápita `TIPOCAP 2, 3 y 4` y para PGP.

Al crear una factura financiera:
- El sistema fija `PROCEDENCIA=FINANCIERO`, asigna el número de factura (`SPK_GENNUMEROFACTURA`), valida que el periodo contable esté abierto (`SPK_PRI`) y que la resolución DIAN esté configurada para la sede.
- El usuario agrega líneas en `FTRD`: selecciona el código CUPS o medicamento, ingresa cantidad y valor unitario; el sistema calcula IVA según el servicio y el tipo de contrato.
- Si el plan es **cápita o PGP**, el usuario también debe relacionar las prestaciones en `FTRDC`: marca los afiliados, las citas o los cargos de admisión correspondientes al período facturado.

**Modalidades:**

| Modalidad | `CAPITADA` | `PGP` | `TIPOCAP` | Qué se factura | Relación `FTRDC` |
|-----------|------------|-------|-----------|----------------|------------------|
| **Evento** | `0` | — | — | Cada prestación con su precio | No aplica |
| **Cápita** | `1` | `0` | `1`, `2`, `3` o `4` | Valor fijo por afiliado cubierto | Obligatoria (excepto `TIPOCAP=1`) |
| **PGP** | `1` | `1` | — | Valor global prospectivo por período | Obligatoria |

- **TIPOCAP:**
  - `1` = Inicial: inicio del contrato; puede no tener relación.
  - `2` = Periodo: corte intermedio; exige relación.
  - `3` = Final: cierre del ciclo; exige relación.
  - `4` = Masiva: consolidado del contrato sin entrar al ciclo Inicial→Periodo→Final; exige relación.

El procedimiento `SPK_TOTALFACTURFIN` recalcula los totales de la factura (suma de líneas `FTRD`, IVA, descuentos) cada vez que se agrega o elimina una línea.

## Ideas principales

- **PROCEDENCIA = FINANCIERO:** identifica que la factura fue creada manualmente desde Nueva Factura.
- **Tres modalidades:** evento (cada prestación), cápita (pago fijo por afiliado) y PGP (valor global por período).
- **Cabecera FTR:** responsable, plan, fecha, número de factura, tipo de facturación, estado.
- **Líneas FTRD:** prestaciones facturadas con cantidad, valor unitario, IVA, centro de costo.
- **Relación FTRDC:** para cápita y PGP, relaciona afiliados y servicios ejecutados como soporte del pago global.
- **Numeración automática:** `SPK_GENNUMEROFACTURA` asigna el consecutivo según la resolución DIAN de la sede.
- **Validaciones:** periodo contable abierto, plan activo, contrato vigente, resolución DIAN configurada.
- **Recalculo de totales:** cada cambio en `FTRD` o `FTRDC` dispara `SPK_TOTALFACTURFIN` para actualizar los totales de la factura.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `FTR.N_FACTURA` | Administrativo → Facturación → detalle factura | Número de factura asignado automáticamente |
| `FTR.PROCEDENCIA` | Detalle factura (campo interno) | Origen de la factura; `FINANCIERO` indica creación manual |
| `FTR.F_FACTURA` | Administrativo → Facturación → Nueva Factura | Fecha de emisión; valida periodo contable abierto |
| `FTR.IDPPT` | Nueva Factura → Plan | Plan de salud seleccionado; determina modalidad (evento/cápita/PGP) |
| `FTR.CAPITADA` | Heredado del plan `PPT.CAPITADA` | `0` = evento, `1` = cápita o PGP |
| `FTR.TIPOCAP` | Si `CAPITADA=1` | Tipo de factura cápita: `1` Inicial, `2` Periodo, `3` Final, `4` Masiva |
| `FTR.CONTABILIZADA` | Detalle factura | `0` = borrador; `1` = ya contabilizada (no se puede editar) |
| `FTR.IMPRESO` | Detalle factura | `0` = no impresa; `>0` = número de impresiones |
| `FTR.FACTE` | Detalle factura | `1` = notificada a DIAN (no se puede editar) |
| `FTRD.IDSER` / `IDPRE` | Detalle factura → Líneas → Agregar línea | Código CUPS, medicamento o insumo facturado |
| `FTRD.CANTIDAD` | Líneas de factura | Cantidad de la prestación |
| `FTRD.VALOR` | Líneas de factura | Valor unitario (consulta tarifa `CPRE`/`COPS`) |
| `FTRD.VR_TOTAL` | Líneas de factura | Cantidad × Valor + IVA |
| `FTRD.IDCCOSTO` | Líneas de factura | Centro de costo al que se imputa la prestación |
| `FTRDC.IDAFI` | Si cápita o PGP → Relación | Afiliado atendido |
| `FTRDC.IDSER` / `IDPRE` | Relación capitada | Prestación ejecutada (CUPS, medicamento) |
| `FTRDC.F_PRESTACION` | Relación capitada | Fecha en que se realizó el servicio |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `IDFORMATOFTRFINANCIE` | Formato de impresión para factura financiera | `1`, `2`, `3` | Define la plantilla de impresión (con o sin datos del paciente, con o sin tarifas) |

**Pendiente validar:**
- Validación de cápita con relación FTRDC (TIPOCAP 2, 3, 4): la documentación indica que "sin FTRDC no debe enviarse a contabilidad ni a DIAN" pero no se encontró la variable USVGS que controla esto
- Cálculo automático de IVA: se hace con `FNK_VALOR_IMPUESTO` pero no se encontró variable de activación automática
- Validación de contrato vigente: se hace en `CREARFTR` pero no se encontró variable USVGS específica

## Usuario final

**Roles:**
- **Facturador:** crea la factura, selecciona el plan, agrega líneas de servicios, relaciona prestaciones (si cápita/PGP).
- **Auditor de facturación:** revisa que las líneas `FTRD` coincidan con la tarifa del contrato y que la relación `FTRDC` esté completa.
- **Coordinador de facturación:** aprueba la factura antes de contabilizar y enviar a DIAN.

**Acciones del usuario:**
1. **Crear factura:** Administrativo → Facturación → Nueva Factura → seleccionar responsable (EPS, particular), plan, fecha de emisión.
2. **Agregar líneas:** en el detalle de la factura, botón Agregar línea → buscar código CUPS o medicamento, ingresar cantidad, valor unitario (el sistema sugiere la tarifa de `CPRE`/`COPS`).
3. **Calcular IVA:** el sistema calcula automáticamente IVA según el servicio y el tipo de contrato; el usuario puede ajustar manualmente si es necesario.
4. **Relacionar prestaciones (cápita/PGP):** botón Agregar relación → marcar afiliados atendidos, seleccionar citas o cargos de admisión del período facturado; el sistema copia los servicios a `FTRDC`.
5. **Guardar factura:** el sistema asigna número de factura, valida periodo contable abierto y resolución DIAN, actualiza totales.
6. **Contabilizar:** una vez revisada, el usuario pulsa Contabilizar; la factura pasa a `CONTABILIZADA=1` y ya no se puede editar.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_FTR_COL → CREARFTR`
- **Propósito:** crear o editar cabecera de factura financiera.
- **Métodos:** `CREARFTR` (único método de este SP para factura financiera).
- **Valida:**
  - `F_FACTURA` no puede ser futura.
  - Periodo contable (`PRI`) debe estar abierto para esa fecha (`SPK_PRI`).
  - Si `CAPITADA=1` y `PGP=1` (PGP con eventos), valida secuencia de cápita según `TIPOCAP` (comentada en el código para `TIPOCAP=4` y hospitales públicos).
  - Resolución DIAN configurada para la sede (`FDIAN` con `PROCEDENCIA=FTR`).
  - El plan (`PPT`) y el contrato (`TARC`) están activos y vigentes.
- **Qué hace:**
  - `INSERT` o `UPDATE` en `FTR` con `PROCEDENCIA=FINANCIERO`, `TIPOFAC=I` (ingreso).
  - Llama `SPK_GENCONSECUTIVO` y `SPK_GENNUMEROFACTURA` para asignar el número de factura según la resolución DIAN.
  - Si es cápita, genera número de boleta con `SPK_GENNUMERO_BOLETA`.
  - Al final ejecuta `SPK_TOTALFACTURFIN` con el copago anterior (`@COPAPROPIO_ANT`) para recalcular totales.
- **Errores típicos:**
  - "La Fecha de Emision... superio a la fecha Acutal"
  - "Periodo Contable No Existe o no Esta Abierto"
  - "Ya Existe una Factura de Capita Inicial" (si `TIPOCAP=1` duplicado)
  - "No existe la Factura de Capita Inicial" (si `TIPOCAP=2` o `3` sin `TIPOCAP=1` previo)
  - "Sede No habilitada para emitir Facturas" (sin resolución DIAN)

#### `SPQ_FTR_COL → CRUDFTRD`
- **Propósito:** insertar o actualizar línea de detalle financiero.
- **Valida:**
  - `N_FACTURA` obligatorio (la factura debe existir).
  - Factura no contabilizada (`CONTABILIZADA=0`), no notificada a DIAN (`FACTE=0`), no impresa (`IMPRESO<=0`).
- **Qué hace:**
  - `INSERT` o `UPDATE` en `FTRD` con `IDSER`/`IDPRE`, `CANTIDAD`, `VALOR`, `IDCCOSTO`.
  - Calcula IVA según el servicio (`FNK_VALOR_IMPUESTO`) y el tipo de contrato (`ARSTIPOCONTRATO`).
  - Llama `SPK_TOTALFACTURFIN` para recalcular totales de la factura.
  - Llama `SPK_FAC_IMPDEDUC` para recalcular impuestos deducibles (si aplica).
- **Errores típicos:**
  - "No Se ha Relacionado Ninguna Factura..." (falta `N_FACTURA`)

#### `SPQ_FTR_COL → DELETEFTRD`
- **Propósito:** eliminar línea de detalle financiero.
- **Valida:**
  - `N_FACTURA` presente.
  - Factura no contabilizada, no notificada a DIAN, no impresa.
- **Qué hace:**
  - `DELETE` de `FTRD` por `CNSFTR` (consecutivo de línea) y `N_CUOTA`.
  - Llama `SPK_TOTALFACTURFIN` y `SPK_FAC_IMPDEDUC` para recalcular totales.
- **Errores típicos:**
  - "Factura Contabilizada, Notificada a la Dian y/o Impresa, no se permiten Cambios"
  - "N_Factura no Encontrada"

#### `SPQ_FTR_COL → ADDFTRDC`
- **Propósito:** agregar o quitar relación capitada (prestaciones ejecutadas en cápita o PGP).
- **Valida:**
  - `CNSFTR` y `N_CUOTA` mayores a cero.
- **Qué hace:**
  - Si `PROCESO=ADD`: llama `SPK_ADDSERCAP` para insertar líneas en `FTRDC` desde `VWK_CARGOS` (cargos de admisión, citas, autorizaciones) y marca los orígenes como facturados (`FACTURADO=1`).
  - Si `PROCESO=DEL`: llama `SPK_DELSERCAP` para eliminar líneas de `FTRDC` y desfacturar los orígenes.
  - Ambos recalculan con `SPK_TOTALFACTURFIN`.
- **Errores típicos:**
  - "KO + ERROR_MESSAGE()" del bloque `TRY-CATCH` si falla la inserción o el borrado.

#### `SPK_TOTALFACTURFIN`
- **Propósito:** recalcular totales de la factura (suma de líneas `FTRD`, IVA, descuentos).
- **Valida:** factura existe.
- **Qué hace:**
  - Suma `FTRD.VR_TOTAL`, `FTRD.IVA`, `FTRD.DESCUENTO`.
  - Actualiza `FTR.VALOR`, `FTR.IVA`, `FTR.DESCUENTO`, `FTR.NETO`.
- **Retorna:** totales actualizados.

#### `SPK_GENNUMEROFACTURA`
- **Propósito:** asignar el número de factura según la resolución DIAN.
- **Valida:** resolución DIAN activa para la sede (`FDIAN.PROCEDENCIA=FTR`, `ACTIVO=1`).
- **Qué hace:**
  - Consulta `FDIAN` para la sede, incrementa el consecutivo, verifica que no supere el rango autorizado.
  - Retorna el número de factura con prefijo y consecutivo (ej. número generado según FDIAN).
- **Errores típicos:**
  - "Consecutivo fuera de rango autorizado por DIAN".

### Ejemplos reales del sector salud

**Ejemplo 1 — Factura por evento para consulta general:**
El facturador crea una Nueva Factura para un paciente con plan `POS Compensar` (evento). Selecciona el responsable `Compensar EPS`, fecha de emisión hoy. Agrega una línea:
- Servicio: `890201` (Consulta medicina general)
- Cantidad: `1`
- Valor unitario: `$45.000` (busca tarifa en `CPRE`)

El sistema calcula IVA `$0` (servicios médicos exentos), total `$45.000`. Al guardar, asigna número de factura según FDIAN, valida periodo contable abierto y resolución DIAN. La factura queda en borrador; el auditor la revisa y el coordinador pulsa Contabilizar.

**Ejemplo 2 — Factura cápita Periodo para ARS:**
La IPS factura el mes de octubre bajo contrato cápita con `Salud Total ARS`. El facturador crea Nueva Factura:
- Plan: `Cápita Salud Total` (`CAPITADA=1`, `TIPOCAP=2` Periodo)
- Responsable: `Salud Total ARS`
- Fecha: `2026-10-31`
- Valor: `$50.000.000` (valor fijo capitado por 1.000 afiliados cubiertos)

Agrega líneas en `FTRD` con el valor global. Luego pulsa Agregar relación: el sistema trae todos los cargos de admisión, citas y autorizaciones de octubre para afiliados de `Salud Total`, los marca y los copia a `FTRDC`. La factura relaciona 3.200 prestaciones (consultas, procedimientos, medicamentos) ejecutadas en el mes. Al guardar, el sistema valida que `FTRDC` tenga al menos una línea (exigido por `CAPITA_EXIGE_FTRDC`).

**Ejemplo 3 — Factura PGP para hospital universitario:**
El hospital factura un valor global prospectivo mensual de `$120.000.000` bajo contrato PGP con `EPS Sanitas`. El facturador crea Nueva Factura:
- Plan: `PGP Sanitas` (`CAPITADA=1`, `PGP=1`)
- Responsable: `EPS Sanitas`
- Fecha: `2026-10-31`

Agrega líneas en `FTRD` con el valor global. Relaciona en `FTRDC` todas las prestaciones de hospitalización, cirugías, UCI, medicamentos y procedimientos de alto costo ejecutados en octubre para pacientes de `Sanitas`. Sin `FTRDC` completo, la factura no pasa a contabilidad ni se envía a DIAN (validación en `SPK_NC_CONTAB_FTR`). El RIPS consolidado se produce con `SPK_RIPS_JSON_FTR_CAPMASI`.

## Pendiente validar

- Cómo se ajusta manualmente el IVA si la tarifa del contrato incluye IVA implícito.
- Si el sistema permite agregar descuentos por glosa anticipada en la línea `FTRD`.
- Mecanismo de validación cruzada entre `FTRD` y `FTRDC` para detectar servicios relacionados pero no facturados en el detalle financiero.
