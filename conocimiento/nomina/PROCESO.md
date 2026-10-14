# Nómina · Liquidación y procesos

Proceso `nomina` · módulo NOMI · familia Nómina y Personal.
Ruta en Qrystalos2: **Talento humano → Procesos nómina** (`/nom/Nom_procesos`: Prenómina ·
Liquidación · Envío DIAN) más pantallas satélite: Prestaciones, Vacaciones, Adelanto
cesantías, Gestión de libranzas, Manuales, Liquidación retefuente, Certificados,
Prestación social (recobros), Colillas y Reportes.

Este libro explica **la operación del período**: prenómina y motor de cálculo, novedades,
retiros, primas y cesantías, retefuente, libranzas, vacaciones y adelantos, generar /
cerrar / abrir, contabilizar y CxP, recobros, DIAN, colillas y reportes.

La configuración (conceptos, eventos, cargos, plantillas, períodos, retención) está en
el libro hermano **Nómina · Conceptos y novedades** (`nomina-conceptos`).

## Fuente SQL

Procedimientos leídos desde IXONLINE/SQL, canasta **PREVERSION**, idéntica a la última
liberada **2.0.7** (anterior 2.0.6). Fichas en `sps.json`; las de DIAN, motor y retiros
datan de 2026-09-12 y se conservan.

## Dos tablas, dos momentos

| Momento | Tablas | Quién escribe | Se deshace con |
|---|---|---|---|
| Calculado | NEMPF / NEMPFD (staging NEMPFD_RUN) | SPK_ADDDEL_CONCEPTOS_DE_CARGOS_NUMDOC · PRENOMINA | Recalcular |
| Liquidado | NIEPE / NIEPED / NPERP | SPQ_LIQUIDACION · GENERATE_NOMINA → SPQ_LIQUIDAR_NOMI | Volver a generar |
| Cerrado | NPER.CERRADO, PRSD Pagada | SPQ_CERRAR_NOMI | OPEN_NOMINA → SPQ_ABRIR_NOMI |
| Contabilizado | MCPE / MCHE, FCXP | SPQ_NC_CONTAB_NOMINA | SPQ_ABRIR_NOMI (si no hay pagos ni notas) |

## Capas

| Capa | Controles |
|---|---|
| 01 Configuración | empleados-historico (NEMPHIS), colilla-nombres (NCONCOL) |
| 02 Proceso propio | prenomina, liquidacion, prestaciones, retefuente, envio-dian, certificados (NCINGRET · NCERT/NSOLICERT · NCONTLABO · NCERTC), talento-humano (CAP/TALL · período de prueba · NDISP) |
| 03 Lo que llega | nedia-novedades, vacaciones-alimenta, adelanto-cesantias, gestion-libranzas, turnos-novedades (TSECFU → TSECRES → TURESUM/TURNOV) |
| 04 Subproceso unido | cxp-nomina, nieper-bancos-caja |
| 05 Contabilidad | om-nomina |

## Hallazgos (2026-10-03)

- **REQ 0100016359** (IDAREA/CCOSTO en NEMPHIS) y **REQ 0100016378** (alias en colilla):
  ya implementados en 2.0.7. Validar en preversión antes de dictaminar.
- Retefuente: renta exenta 25 % sin tope mensual UVT; sin deducciones por dependientes,
  vivienda ni medicina prepagada.
- `SPQ_NOM_NEDIA · GUARDAR` y `SPQ_NOM_PRSD · ELIMINAR` no validan período cerrado ni
  cuota ya descontada.
- `SPQ_NOM_DIAN · GENERATE_NIEPEG` no exige período cerrado.
- Umbrales 180/360 días y códigos de concepto fijos en `SPK_CALCULAR_RETIROS`.
- Ningún SP valida USGRUH por acción; el permiso vive en los botones Vue.
- Sin ficha: SPK_NC_CONTAB_RECOBRONOMI, SPK_GENCXP_NOMINA_UNO / _PROVI / NOMI_ESP,
  SPK_QUITANOV_RETIROS, SPQ_NOM_NEMPV.
- REQ 0100016450: METODO REFINANCIAR de libranzas no existe en PREVERSION.

## Ampliación 2026-10-04 · ítems del menú que faltaban

Inventario completo de **Talento humano** (`/nom`) y **Reportes nómina** (`/nom.reportes`).
Se añadieron tres capítulos (Turnos, Certificados, Talento humano) y se ampliaron
Retefuente (pantalla Liquidación retefuente) y Colillas y reportes (seis páginas).

| Ítem del menú | Pantalla | Objeto | Capítulo |
|---|---|---|---|
| Certificados | CerIngRetComponent | SPQ_NCINGRET_COL (9 métodos) | Certificados |
| Liquidación retefuente | RETELComponent (lectura RETEL/RETELD) | SPQ_NCINGRET_COL · IMPRIMIR_LIQRET | Retefuente / Certificados |
| Certificaciones | NominaCertLaboComponent + SolCertComponent (menú personal) | SPQ_FORMATOS_NOMINA · CRUD_NCERT / TRAER_NCERT, SPQ_NSOLICERT | Certificados |
| Contratos | NomContLaboComponent | SPQ_CONTRATOS_NOM | Certificados |
| Formatos | NCERTConfiComponent | SPQ_FORMATOS_NOMINA · CRUD_NCERTC / GUARDAR_CUERPO | Certificados |
| Auditoría turnos | AudiTurnosComponent / NovedadesTurComponent | SPQ_TURNOS_NOMINA → SPK_RESUMEN_TURNOS | Turnos |
| Capacitaciones | CAPComponent, talleres | SPQ_CAP, SPQ_TALL, SPQ_FORMULARIO_TALLER, SPQ_EMPLEADOS_TALL, SPQ_CALIFICAR_RESPUESTAS_TEXTO | Talento humano |
| Crear empleados | EmpleadosComponent (+ P. Prueba, planta) | SPQ_RPT_NOMINA, SPQ_TH_NEMPPRUEBA, SPQ_NDISP | Talento humano (detalle en libro Conceptos) |
| Reportes nómina (6 páginas) | pages/nom/reportes | SPQ_NOM_REPORTES (13), NOM_NPER · GET_NIEPE_REPORT, LIQUIDACION · EXPORTAR_DETALLE_NOMINA, PROVISIONES, NOM_ADELANTO_CESANTIAS · REPORTE | Colillas y reportes |
| Gastos por consumo | components/inv/GastosConsumoComponent | IZSOL / IZSOLD | Inventario (solo enlace) |

Hallazgos nuevos:

- Auditoría de turnos termina en TURNOV (CNSPAGO NULL): **no hay METODO** que lleve la
  novedad a NEDIA; se registra a mano en Prenómina → Novedades. Hueco, candidato a REQ.
- `SPQ_NCINGRET_COL` suma `NIEPED.TOTAL_NOMINA` por `NIEPE.ANO` para todos los contratos
  del tercero; FDESDE/FHASTA solo se imprimen. No valida certificado duplicado por año.
- `CRUD_NCERTC` siempre inserta TIPO 'Contrato'; `CRUD_NCERT` no lee @CNSFORMATO (NULL).
- Certificados y contratos: único permiso por botón `MENUQ_NOMINA · BtnFirmarContGerente`.
