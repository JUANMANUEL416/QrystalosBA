# Proceso: Consulta externa · Agenda

**Estado:** parcial  
**Módulo:** Consulta externa (`/ce`) y la asignación del médico en Consultorio (`/consultorio/administrativo/agenda`)

> Flujo visto en pantalla. El cuerpo de los procedimientos no se leyó: las fichas están en `listado`. No hay comprobante contable propio.

## Resumen

La agenda del día no inventa los cupos. Primero existe un **modelo** (franjas), el médico queda **asignado** a ese modelo en su sede, y una **programación** genera los cupos. En Consulta externa → Agenda el usuario ve esos cupos y **asigna el paciente** a uno libre.

Hay dos asignaciones distintas:

1. **Asignar la agenda al médico** (sede, especialidad y modelo). Vive en Consultorio médico → Administrativo → Agenda.
2. **Asignar el paciente al cupo**. Vive en Consulta externa → Agenda, botón Agendar.

`/ce/modagenda` es otro catálogo (tabla `MAGQ`). No es el modelo que genera los cupos.

## Capas

### 1. Configuración

- **Modelos de agenda** (`MAG`): Consulta externa → Modelos de Agenda (`/ce/mag`) y Configuración → `/conf/mag`. Componente `MAGComponent`. El detalle de franjas es `MAGD`. El cuerpo del procedimiento de esta pantalla no se abrió en este turno.
- **Catálogo MAGQ** (`/ce/modagenda`): grilla `MAGQ` (id, descripción, estado). Alta con `AGENDACOL` · `MAGQ`. No genera cupos.
- **Médicos** (`/ce/med`) y **disponibilidad** (`/ce/dis`, `DisponibilidadComponent`). La disponibilidad por consultorio es un camino aparte de la grilla diaria; no se leyó el componente.
- **Variable `USA_DISPONIBILIDAD`:** si está activa, la Agenda muestra filtros y el acceso a pacientes por reagendar. El código habitual de cada institución no queda en este libro.

### 2. Proceso propio

1. **Asignación del médico.** Consultorio médico → Administrativo → Agenda. Se elige un médico activo de consultorio (`MED.ENCONSUL` y estado Activo). La pestaña **Configurar** trae modelos y programación. La pestaña **Agendar** muestra sede, especialidad, modelo y sede de atención leídos de `MEDS`. Si no hay fila en `MEDS`, avisa que el médico no tiene sede ni especialidad. Si no existe el modelo, avisa que hay que configurarlo. Botones **Programar hoy** y **Programar con anticipación** (exigen modelo ya ligado). Guardar la asignación llama `MEDS_COL` · `GUARDAR_MEDS`. Crear el modelo del médico llama `MAG_COL` · `GUARDAR_MAG` (código tomado del id del médico, descripción con su nombre, estado Activa).
2. **Programación.** Misma zona de consultorio y la pantalla de programación de Consulta externa (`/ce/magp`, `MAGPComponent`, que llama `GENERAR_MAGP`). Métodos vistos en el consultorio: `MAGP_COL` · `GUARDAR_MAGP`, `GENERAR_MAGP`, `DESHACER_MAGP`. Restricciones del médico: `MAGPRP_COL` · `GUARDAR_MAGPRP` y `ELIMINAR_MAGPRP`. Qué filas de `CIT` deja cada método queda pendiente del cuerpo SQL.
3. **Agenda del día.** Consulta externa → Agenda (`/ce/agendamiento`, `AgendaNuevaPage` → `AgendaNuevaComponent`). Para cargar exige sede, especialidad y fecha de 10 caracteres. Llama `CIT_COL_2` · `DISPONIBILIDAD` (si el origen es aplicación de medicamentos, el modelo pasa a `APLI` con el mismo método). Cupo suelto: `CIT_COL` · `CREA_AGENDA`.
4. **Asignar el paciente.** Diálogo `AgendarCitaComponent`, botón **Agendar**. Antes arma los servicios y, si la clase de orden es Normal y el paciente tiene programas, pregunta si se agenda como Normal. Si el paciente está en lista de espera de esa especialidad, pregunta si se quita de la lista. Luego `CIT_VALIDA` · `ASIGNAR` con el consecutivo del cupo, el afiliado, los servicios, `CNSNOCIT` si viene de lista de espera e `ITEM_HCATDC` si viene de una cita de control.

Otras acciones de la misma Agenda (cuerpo SQL sin leer): confirmar cita, cancelar, no asistió, confirmar llegada, facturar cita, clonar agenda, reprogramar, visor, liberar cita en uso.

### 3. Lo que llega

- **Lista de espera.** Botón en la Agenda. Al asignar, el diálogo puede enviar `CNSNOCIT` y la respuesta del usuario a «quitarlo de la lista». El alta y el retiro de la lista no se leyeron.
- **Citas de control.** Botón en la Agenda. Al agendar desde ahí viaja `ITEM_HCATDC`. Archivar la solicitud no se leyó.
- **Afiliado.** La Agenda consulta al paciente con `AFICOL` (`CONSULTAAFI`, `VALIDA_DATOS_COMPLETOS`, `LLAMAR_PACIENTE`). El módulo de afiliados no es este proceso.

### 4. Encuentro con caja

Desde la Agenda se recauda, se confirma el recibo y se devuelve (`CONF_CAJA`, `CIT_VALIDA` · `CONFIRMAR_RECIBO` / `INFO_CITA_RECAUDAR`, `CIT_COL_2` · `DEVOLVER_RECIBO`). El ciclo de caja está en el proceso Caja. Aquí solo se nombra el puente.

### 5. Envío a contabilidad

La Agenda no arma comprobante. **Facturar cita** (`CIT_COL_2` · `FACTURAR_CITA`) entrega la cita a facturación. El envío masivo de citas a factura es el proceso Consulta externa · Autorizaciones, no esta pantalla.

## Qué no es

- **Gestión** (`/ce/gesagenda`): abre la atención del paciente, no programa cupos.
- **Autorizaciones, transcripciones y aplicación de medicamentos:** procesos ya separados. La Agenda solo cambia el modelo a `APLI` cuando el origen es aplicación.
- **Oncología, tópico y agenda Perú:** pantallas propias; fuera de este libro.

## Pendiente

- [ ] Leer `SPQ_CIT_VALIDA` (`ASIGNAR`) y `SPQ_CIT_COL_2` (`DISPONIBILIDAD`).
- [ ] Leer `SPQ_MAG_COL`, `SPQ_MAGD_COL`, `SPQ_MAGP_COL` y `SPQ_MEDS_COL`.
- [ ] Abrir `MAGComponent` y `DisponibilidadComponent` y fichar sus métodos.
- [ ] Alta y retiro de lista de espera, y archivar cita de control.
