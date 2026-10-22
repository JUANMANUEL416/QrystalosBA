# 🏥 Facturación desde admisión (urgencias, hospitalización)

## Contexto

**Proceso:** Facturación  
**Capa:** 02 - Operación

Cuando un paciente es atendido en urgencias, hospitalización o atención domiciliaria, los servicios (consultas, procedimientos, medicamentos, estancia) se registran como **cargos** en la tabla `HPRE` y `HPRED` asociados a una admisión (`HADM`). Al dar el alta médica o al hacer un corte de facturación, el sistema toma esos cargos y crea una factura con **PROCEDENCIA = SALUD**, trasladando las líneas de cargo a `FTRD` (detalle financiero) y `FTRDC` (relación de prestaciones).

## Explicación

El flujo de facturación desde admisión es:

1. **Apertura de admisión:** al ingresar el paciente (urgencias, hospitalización o domiciliaria), se crea un registro en `HADM` con el tipo de admisión, la fecha de ingreso, el diagnóstico de ingreso, el médico tratante y el plan de salud.
2. **Registro de cargos:** cada servicio prestado (consulta especializada, radiografía, laboratorio, medicamento, estancia en habitación, honorarios médicos) se registra como un cargo en `HPRE` (cabecera del cargo) y `HPRED` (detalle del cargo). Los cargos pueden venir automáticamente de órdenes médicas, de notas de enfermería o ser ingresados manualmente.
3. **Consolidación de cargos:** el sistema valida que cada cargo tenga tarifa (`CPRE`/`COPS`), que el servicio esté cubierto por el plan, que el paciente esté autorizado (si aplica) y que la fecha del cargo esté dentro de la vigencia del contrato.
4. **Facturación:**
   - **Alta completa:** al dar el alta médica definitiva, el usuario pulsa Facturar admisión → el sistema toma todos los cargos de la admisión, los agrupa por tipo de servicio y crea la factura con `PROCEDENCIA=SALUD`. La admisión queda marcada como `FACTURADO=1`.
   - **Corte:** si la admisión es larga (ej. hospitalización de 15 días), el usuario puede hacer cortes parciales: el sistema factura los cargos desde la fecha del último corte hasta hoy, deja la admisión abierta y marca solo esos cargos como facturados. Al alta final se facturan los cargos restantes.
5. **Generación de RIPS:** al facturar, el sistema genera los RIPS (Registro Individual de Prestación de Servicios) en formato JSON para enviar al Ministerio y obtener el CUV (Código Único de Verificación). Sin CUV no se puede radicar la factura ante el pagador.

**Tablas involucradas:**
- `HADM`: admisión (paciente, fecha ingreso, diagnóstico, médico, plan).
- `HPRE`: cabecera del cargo (tipo de cargo, área, fecha, responsable).
- `HPRED`: detalle del cargo (código CUPS, medicamento, cantidad, valor unitario, valor total).
- `FTR`: factura resultante con `PROCEDENCIA=SALUD`.
- `FTRD`: líneas de la factura (copia de `HPRED`).
- `FTRDC`: relación de prestaciones (copia de `HPRED` para RIPS).

## Ideas principales

- **PROCEDENCIA = SALUD:** identifica que la factura nació de una admisión (`HADM`).
- **Cargos → factura:** los cargos `HPRE`/`HPRED` se convierten automáticamente en líneas de factura `FTRD`/`FTRDC`.
- **Alta completa vs corte:** alta completa factura toda la admisión y la cierra; corte factura un tramo y deja la admisión abierta.
- **Validación de cargos:** cada cargo debe tener tarifa, autorización (si aplica) y estar cubierto por el plan.
- **RIPS automáticos:** al facturar se generan los RIPS JSON para validar ante el Ministerio (SISPRO).
- **Marcado de facturado:** una vez facturado, el cargo queda con `FACTURADO=1` y ya no se puede volver a facturar.
- **Auditoría de cargos:** antes de facturar, el auditor revisa que no haya cargos duplicados, que las cantidades sean correctas y que los servicios correspondan al diagnóstico.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `HADM.IDHADM` | Asistencial → Admisiones | Identificador único de la admisión |
| `HADM.F_INGRESO` | Admisiones → detalle | Fecha y hora de ingreso del paciente |
| `HADM.F_EGRESO` | Admisiones → detalle | Fecha y hora de egreso (alta médica) |
| `HADM.IDPPT` | Admisiones → Plan | Plan de salud del paciente; determina tarifa y cobertura |
| `HADM.FACTURADO` | Admisiones → Estado | `0` = no facturada; `1` = facturada completa |
| `HPRE.TIPO_CARGO` | Admisiones → Cargos | Tipo: `C` consulta, `P` procedimiento, `M` medicamento, `E` estancia |
| `HPRE.F_CARGO` | Cargos → Fecha | Fecha en que se prestó el servicio |
| `HPRED.IDSER` / `IDPRE` | Cargos → Detalle | Código CUPS, medicamento o insumo |
| `HPRED.CANTIDAD` | Cargos → Detalle | Cantidad prestada (ej. 2 ampollas, 3 días de estancia) |
| `HPRED.VALOR_UNITARIO` | Cargos → Detalle | Precio unitario según tarifa del contrato |
| `HPRED.VALOR_TOTAL` | Cargos → Detalle | Cantidad × Valor unitario |
| `HPRED.FACTURADO` | Cargos → Estado | `0` = pendiente de facturar; `1` = ya facturado |
| `FTR.N_FACTURA` | Resultado de facturar → detalle | Número de factura generada desde la admisión |
| `FTR.PROCEDENCIA` | Factura (campo interno) | `SALUD` indica que vino de admisión |

## Variables de configuración (USVGS)

**Pendiente validar:** No se encontraron variables USVGS específicas para facturación desde admisión en la base de conocimiento. Las validaciones se hacen directamente en los SPs (`SPK_FACTURA_ASIS`, `SPK_FACTURA_ASIS_CORTE`).

## Usuario final

**Roles:**
- **Enfermera / auxiliar de enfermería:** registra cargos de medicamentos, procedimientos y estancia diaria.
- **Médico tratante:** registra cargos de consultas especializadas y procedimientos médicos.
- **Facturador:** al alta del paciente, revisa los cargos y ejecuta Facturar admisión.
- **Auditor de cuentas médicas:** valida que los cargos correspondan a la historia clínica, que no haya duplicados y que estén autorizados.

**Acciones del usuario:**
1. **Registrar cargo:** Asistencial → Admisiones → detalle de admisión → Agregar cargo → seleccionar tipo (consulta, procedimiento, medicamento, estancia), código CUPS o medicamento, cantidad, fecha del servicio. El sistema busca la tarifa en `CPRE`/`COPS` y calcula el valor total.
2. **Revisar cargos:** antes de facturar, el auditor abre la admisión, revisa todos los cargos, verifica que no haya duplicados, que las cantidades sean correctas y que los servicios estén autorizados.
3. **Facturar alta completa:** al dar el alta médica, el usuario marca F_EGRESO, pulsa Facturar admisión → el sistema valida que todos los cargos tengan tarifa, genera la factura con `PROCEDENCIA=SALUD`, copia los cargos a `FTRD`/`FTRDC`, marca la admisión como `FACTURADO=1` y genera los RIPS JSON.
4. **Facturar corte:** si la hospitalización es larga, el usuario pulsa Facturar corte → el sistema pregunta la fecha del corte, factura los cargos desde el último corte hasta esa fecha, marca solo esos cargos como `FACTURADO=1` y deja la admisión abierta.
5. **Consultar factura:** una vez facturada, el usuario puede ver el número de factura en el detalle de la admisión y acceder a la factura desde Administrativo → Facturación.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_FTR_HADM_COL → FACTURA_ADMI`
- **Propósito:** facturar una admisión completa (urgencias, hospitalización, domiciliaria).
- **Valida:**
  - Admisión existe (`HADM.IDHADM`).
  - Admisión tiene alta médica (`F_EGRESO` no nulo) o se permite facturar sin egreso (validación interna del SP).
  - Cargos `HPRE`/`HPRED` tienen tarifa (`CPRE`/`COPS`) y están autorizados (si aplica).
  - Periodo contable abierto para la fecha de la factura.
  - Resolución DIAN configurada para la sede.
- **Qué hace:**
  - Crea la cabecera `FTR` con `PROCEDENCIA=SALUD`, asigna número de factura (`SPK_GENNUMEROFACTURA`).
  - Copia los cargos de `HPRED` a `FTRD` (detalle financiero) y `FTRDC` (relación de prestaciones).
  - Marca la admisión como `FACTURADO=1` y los cargos como `FACTURADO=1`.
  - Genera RIPS JSON con `SPK_RIPS_JSON_FTR`.
  - Llama `SPK_TOTALFACTURFIN` para calcular totales.
- **Errores típicos:**
  - "Admisión no tiene alta médica" (falta `F_EGRESO`).
  - "Cargo sin tarifa: código CUPS no está en `CPRE`".
  - "Servicio no autorizado: falta autorización para procedimiento".

#### `SPK_FACTURA_ASIS`
- **Propósito:** facturar una admisión o un grupo de admisiones de forma masiva.
- **Valida:** igual que `FACTURA_ADMI`.
- **Qué hace:** igual que `FACTURA_ADMI`, pero permite procesar múltiples admisiones en un solo llamado (facturación en lote al final del día).
- **Llama:** `SPK_RIPS_JSON_FTR`, `SPK_TOTALFACTURFIN`, `SPK_GENNUMEROFACTURA`.

#### `SPK_FACTURA_ASIS_CORTE`
- **Propósito:** facturar un corte parcial de una admisión (ej. cada 10 días de hospitalización).
- **Valida:**
  - Admisión abierta (`FACTURADO=0` o `FACTURADO=2` si ya hubo cortes previos).
  - Fecha del corte debe ser posterior al último corte.
  - Cargos del período tienen tarifa y autorización.
- **Qué hace:**
  - Crea la cabecera `FTR` con `PROCEDENCIA=SALUD`, asigna número de factura.
  - Copia solo los cargos `HPRED` entre el último corte y la fecha del corte actual.
  - Marca esos cargos como `FACTURADO=1` pero deja la admisión en `FACTURADO=2` (corte parcial).
  - Genera RIPS JSON del corte.
  - Al alta final, factura los cargos restantes y marca la admisión como `FACTURADO=1`.
- **Errores típicos:**
  - "Fecha de corte debe ser posterior al último corte".
  - "No hay cargos pendientes en el período seleccionado".

#### `SPK_RIPS_JSON_FTR`
- **Propósito:** generar RIPS JSON de una factura de admisión.
- **Valida:** factura tiene líneas `FTRDC` (prestaciones relacionadas).
- **Qué hace:**
  - Lee `FTRDC` y construye el JSON RIPS según especificación Ministerio de Salud (archivos AC, US, AP, AM, AT, UR, etc.).
  - Guarda el JSON en `FTRDJSON` (o tabla de RIPS según configuración).
  - Retorna el JSON para enviar a SISPRO y obtener el CUV.
- **Errores típicos:**
  - "Factura sin prestaciones relacionadas (`FTRDC` vacía)".
  - "Código CUPS no válido en catálogo Ministerio".

### Ejemplos reales del sector salud

**Ejemplo 1 — Factura de urgencias:**
Un paciente ingresa a urgencias por trauma en accidente de tránsito. Se registra la admisión `HADM` con plan `SOAT`, fecha de ingreso `2026-10-21 14:30`. Se generan cargos:
- Consulta urgencias (`890201`): `$80.000`
- Radiografía de tórax (`870101`): `$120.000`
- Sutura simple (`120301`): `$150.000`
- Medicamentos (analgésicos, antibióticos): `$45.000`

Al dar el alta (4 horas después), el facturador pulsa Facturar admisión. El sistema crea la factura con `PROCEDENCIA=SALUD`, total `$395.000`, genera RIPS JSON y marca la admisión como `FACTURADO=1`. La factura se envía a la aseguradora SOAT con el FURIPS (Formato Único de Reclamación).

**Ejemplo 2 — Factura de hospitalización con corte:**
Un paciente con plan `Coomeva EPS` ingresa a hospitalización por neumonía el `2026-10-01`. Durante 15 días se registran cargos diarios:
- Estancia en habitación doble: `$200.000/día` × 15 días = `$3.000.000`
- Consultas especializadas (neumología, medicina interna): `$500.000`
- Procedimientos (broncoscopia, radiografías, laboratorios): `$1.200.000`
- Medicamentos (antibióticos IV, oxígeno, sueros): `$1.800.000`

Total acumulado: `$6.500.000`. El auditor decide hacer un corte al día 10 para facilitar la radicación ante la EPS. El facturador pulsa Facturar corte con fecha `2026-10-10`. El sistema factura los cargos del `2026-10-01` al `2026-10-10`, genera factura con `$4.300.000`, marca esos cargos como facturados y deja la admisión abierta (`FACTURADO=2`). Al alta definitiva (`2026-10-15`), se facturan los cargos restantes del día 11 al 15, generando otra factura con `$2.200.000`. La admisión queda `FACTURADO=1`.

**Ejemplo 3 — Rechazo por cargo no autorizado:**
Un paciente con plan `Nueva EPS` está hospitalizado. Se registra un cargo de tomografía contrastada (`876101`) por `$800.000`. El cargo no tiene autorización previa. Al intentar facturar, el sistema detecta que falta la autorización y rechaza con error "Servicio no autorizado: falta autorización para procedimiento `876101`". El facturador solicita la autorización a la EPS, la registra en el sistema y luego vuelve a facturar.

## Pendiente validar

- Cómo se manejan los ajustes de cargos después de facturado (glosas, correcciones).
- Si el sistema permite anular una factura de admisión y regenerarla con cargos corregidos.
- Mecanismo para detectar cargos sin soporte en la historia clínica electrónica (trazabilidad orden médica → cargo).
