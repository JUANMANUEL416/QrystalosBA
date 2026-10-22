# 📋 Contratos, planes y tarifas de facturación

## Contexto

**Proceso:** Facturación  
**Capa:** 01 - Configuración

Antes de facturar cualquier atención médica es necesario configurar los contratos con cada pagador (EPS, ARS, particular), definir los planes de salud asociados y establecer las tarifas que aplican a cada servicio o procedimiento según el contrato vigente.

## Explicación

Un **contrato** (tabla `TARC`) es el acuerdo comercial entre la institución de salud y un pagador (EPS, medicina prepagada, aseguradora o particular). Cada contrato define la vigencia, el responsable (tercero `TER`), el régimen (contributivo, subsidiado, vinculado), el tipo de facturación (evento, cápita o PGP) y las condiciones comerciales.

Dentro de cada contrato se registran uno o más **planes** de salud (tabla `PPT`) que identifican el esquema de beneficios: POS, planes complementarios, SOAT, medicina prepagada o convenios especiales. El plan determina la modalidad de facturación:
- **Evento** (`CAPITADA=0`): se cobra por cada procedimiento, consulta o servicio realizado.
- **Cápita** (`CAPITADA=1`, `PGP=0`): pago fijo por afiliado cubierto; se relacionan las prestaciones ejecutadas en `FTRDC`.
- **PGP** (Pago Global Prospectivo, `CAPITADA=1`, `PGP=1`): valor global por período; también relaciona prestaciones.

Las **tarifas** son los precios unitarios de cada servicio o procedimiento según el contrato. Se manejan con:
- **`CPRE`** (Contrato-Prestación): precio individual de un código CUPS, medicamento o insumo dentro del contrato.
- **`COPS`** (Contrato-Paquete): agrupa múltiples prestaciones con un precio global (ej. paquete cesárea, paquete parto).

Al facturar, el sistema busca primero la tarifa específica en `CPRE` o `COPS`; si no existe, consulta los manuales tarifarios genéricos configurados para el contrato (SOAT, ISS, particular).

## Ideas principales

- **Contrato = acuerdo comercial:** cada pagador (EPS, ARS, particular) tiene su contrato con vigencia, responsable y condiciones.
- **Plan = esquema de beneficios:** dentro de cada contrato, los planes (`PPT`) definen el tipo de facturación (evento, cápita o PGP) y el alcance de cobertura.
- **Modalidad de facturación:** evento cobra por prestación; cápita paga por afiliado cubierto; PGP entrega un valor global por período.
- **Tarifas específicas (`CPRE`, `COPS`):** precio unitario o paquete que aplica solo a ese contrato.
- **Manuales tarifarios genéricos:** cuando no hay tarifa específica, se consulta el manual configurado (SOAT, ISS, particular).
- **Regímenes:** contributivo (empleados), subsidiado (SISBEN), vinculado (población pobre no afiliada), prepagada o particular.
- **Vigencia del contrato:** fecha inicio y fin; no se factura si el contrato está vencido.

## Campos decisivos y visibles (frontend)

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| `TARC.NOMBRE` | Configuración → Contratos | Nombre del contrato |
| `TARC.VIGENCIA_INI` / `VIGENCIA_FIN` | Configuración → Contratos | Vigencia del contrato; fuera de estas fechas no se factura |
| `TARC.IDTER` | Configuración → Contratos | Responsable del pago (EPS, ARS, aseguradora, particular) |
| `TARC.REGIMEN` | Configuración → Contratos | Contributivo, subsidiado, vinculado, prepagada, particular |
| `PPT.NOMBRE` | Configuración → Planes | Nombre del plan de salud (POS, complementario, SOAT) |
| `PPT.CAPITADA` | Configuración → Planes | `0` = evento, `1` = cápita o PGP |
| `PPT.PGP` | Configuración → Planes | `1` = PGP (Pago Global Prospectivo); exige `CAPITADA=1` |
| `PPT.IDTARC` | Configuración → Planes | Contrato al que pertenece el plan |
| `CPRE.IDSER` / `IDPRE` | Configuración → Tarifas → Prestaciones | Código CUPS, medicamento o insumo tarifado |
| `CPRE.VALOR` | Configuración → Tarifas → Prestaciones | Precio unitario de la prestación en este contrato |
| `COPS.NOMBRE` | Configuración → Tarifas → Paquetes | Nombre del paquete (ej. cesárea, parto, cirugía mayor) |
| `COPS.VALOR` | Configuración → Tarifas → Paquetes | Precio global del paquete |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| `FTR_VALIDAR_TARIFA` | Exige tarifa específica al facturar | `SI` | Si está en `SI`, rechaza la factura si no encuentra tarifa en `CPRE` o `COPS` ni en manual tarifario |
| `FTR_MANUAL_TARIFARIO` | Manual tarifario genérico | `SOAT`, `ISS`, `PARTICULAR` | Define el manual de precios de respaldo cuando no hay tarifa específica |
| `FTR_CONTRATO_OBLIGATORIO` | Exige contrato vigente al facturar | `SI` | Valida que el contrato esté activo y dentro de su vigencia |
| `CAPITA_EXIGE_FTRDC` | Cápita exige relación de prestaciones | `TIPOCAP=2,3,4` | Factura cápita solo pasa si tiene líneas en `FTRDC` (relaciona afiliados y servicios) |

## Usuario final

**Roles:**
- **Administrador de contratos:** registra contratos, planes y vigencias en Configuración → Contratos y Planes.
- **Tarifador:** mantiene actualizadas las tarifas específicas (`CPRE`) y los paquetes (`COPS`) según negociación comercial.
- **Facturador:** al crear la factura, selecciona el plan; el sistema busca automáticamente la tarifa aplicable.
- **Auditor de facturación:** revisa que las tarifas aplicadas coincidan con el contrato vigente.

**Acciones del usuario:**
1. **Crear contrato:** Configuración → Contratos → Nuevo contrato → llenar nombre, responsable (tercero), régimen, vigencia, manual tarifario.
2. **Crear plan:** Configuración → Planes → Nuevo plan → seleccionar contrato, nombre del plan, modalidad (evento/cápita/PGP).
3. **Cargar tarifas:** Configuración → Tarifas → Prestaciones → importar Excel con código CUPS y precio unitario; o Paquetes → crear paquete con lista de prestaciones incluidas.
4. **Facturar:** al crear factura, el usuario elige el plan; el sistema busca automáticamente la tarifa en `CPRE`/`COPS` o el manual configurado.

## Soporte y desarrollo

### Stored Procedures

#### `SPQ_TARC_COL`
- **Propósito:** CRUD de contratos (crear, editar, consultar, listar).
- **Métodos:** `CREA_TARC`, `EDITA_TARC`, `LISTA_TARC`, `CONSULTA_TARC`.
- **Valida:** vigencia no superpuesta con otro contrato del mismo tercero; manual tarifario configurado; responsable (`IDTER`) existe en `TER`.
- **Qué hace:** inserta o actualiza `TARC`; valida fechas de vigencia.
- **Errores:** "Contrato ya existe para este responsable en el mismo período", "Manual tarifario no configurado".

#### `SPQ_PPT_COL`
- **Propósito:** CRUD de planes de salud.
- **Métodos:** `CREA_PPT`, `EDITA_PPT`, `LISTA_PPT`, `CONSULTA_PPT`.
- **Valida:** contrato (`IDTARC`) existe; si `PGP=1` entonces `CAPITADA=1`.
- **Qué hace:** inserta o actualiza `PPT`; valida coherencia entre `CAPITADA` y `PGP`.
- **Errores:** "PGP exige que CAPITADA sea 1", "Contrato no existe".

#### `SPQ_CPRE_COL`
- **Propósito:** CRUD de tarifas de prestaciones individuales.
- **Métodos:** `CREA_CPRE`, `EDITA_CPRE`, `LISTA_CPRE`, `IMPORTAR_CPRE` (masivo desde Excel).
- **Valida:** prestación (`IDSER`/`IDPRE`) existe; contrato (`IDTARC`) existe; valor mayor a cero.
- **Qué hace:** inserta o actualiza `CPRE`; permite carga masiva de tarifas desde archivo Excel.
- **Errores:** "Prestación no existe", "Valor debe ser mayor a cero".

#### `SPQ_COPS_COL`
- **Propósito:** CRUD de paquetes tarifarios.
- **Métodos:** `CREA_COPS`, `EDITA_COPS`, `LISTA_COPS`, `AGREGA_PRESTACION_PAQUETE`.
- **Valida:** contrato existe; prestaciones del paquete están registradas.
- **Qué hace:** inserta o actualiza `COPS` y sus líneas `COPSD` (prestaciones incluidas en el paquete).
- **Errores:** "Paquete debe incluir al menos una prestación", "Prestación duplicada en el paquete".

#### `SPK_BUSCAR_TARIFA`
- **Propósito:** busca la tarifa aplicable para una prestación en un contrato dado.
- **Valida:** contrato vigente; prestación activa.
- **Qué hace:** busca en orden: 1) `CPRE` específico del contrato, 2) paquete `COPS`, 3) manual tarifario genérico configurado.
- **Retorna:** `VALOR`, `ORIGEN` (específico, paquete o manual), `IDCPRE` o `IDCOPS`.

### Ejemplos reales del sector salud

**Ejemplo 1 — Contrato con EPS para evento:**
La IPS firma un contrato con **Compensar EPS** para atender régimen contributivo. El contrato se registra con vigencia 2026-01-01 a 2026-12-31, responsable `Compensar EPS`, régimen `Contributivo`. Se crea el plan `POS Compensar` con `CAPITADA=0` (evento). Se cargan tarifas específicas:
- Consulta general (`890201`): $45.000
- Ecografía obstétrica (`881101`): $120.000
- Cesárea paquete (`PAQCESA`): $3.500.000 (incluye honorarios, sala, anestesia, hospitalización 3 días).

Al facturar una cesárea, el sistema busca el paquete `PAQCESA` en `COPS` y aplica el precio global; las prestaciones individuales quedan relacionadas en `FTRDC` para RIPS.

**Ejemplo 2 — Contrato cápita con ARS:**
La IPS tiene un contrato de **cápita** con **Salud Total ARS**. Se registra el plan `Cápita Salud Total` con `CAPITADA=1`, `PGP=0`. El pago es mensual por afiliado cubierto. Al facturar, se usa `TIPOCAP=2` (periodo intermedio) y se relacionan todas las atenciones del mes en `FTRDC`: consultas, procedimientos, medicamentos POS. La factura lleva el valor fijo capitado; las prestaciones son soporte para RIPS y auditoría.

**Ejemplo 3 — Manual tarifario SOAT:**
La IPS atiende accidentes de tránsito bajo **SOAT**. No hay tarifas específicas en `CPRE`; el manual tarifario configurado es `SOAT 2026`. Al facturar una atención de urgencias por trauma, el sistema consulta automáticamente los valores del manual SOAT vigente. La variable `FTR_MANUAL_TARIFARIO=SOAT` indica al procedimiento `SPK_BUSCAR_TARIFA` que use ese manual cuando no encuentre tarifa específica.

## Pendiente validar

- Cómo se actualizan masivamente las tarifas cuando el manual SOAT o ISS publica nueva versión.
- Si el sistema permite tener tarifas diferenciadas por sede dentro del mismo contrato.
- Mecanismo de alertas cuando un contrato está próximo a vencer (30 días antes).
