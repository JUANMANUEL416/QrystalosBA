# Proceso: Accidentes de tránsito SOAT

**Estado:** esqueleto  
**Módulo:** ACCTRAN

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

## Resumen

El expediente vive en `HACTRAN`. El usuario lo abre en Asistencial → SOAT o como modal desde admisión (urgencias), triage, agenda CE o autorizador. Pestañas: Accidente, Paciente, Vehículo, Conductor, Remisión, Amparo.

Este REQ: botón en **Amparo** para traer datos básicos del paciente. Vehículo y Conductor ya copian AFI (`PACIENTE_COL` · `DATOSAFI`). Amparo no.

## Procedimientos (`sps.json`)

Sin fichas. Vistos en FE: `HACTRAN` LLENAR / INSERT / UPDATE; `PACIENTE_COL` DATOSAFI.

## Capas

### 1. Configuración

Variables `IDTARIFASOAT` / `IDPLANSOAT`. Catálogos de tipo documento.

### 2. Proceso propio

Alta y edición del expediente. **Gate de este REQ:** copiar AFI a campos `*_AMPARO`.

### 3. Lo que llega

HADM / triage / CE / autorizador pasan `idafiliado` al modal.

### 4. Subproceso unido

Autorizaciones (`AUT.CNSHACTRAN`), FURIPS. Fuera del REQ.

### 5. Contabilidad

No aplica a este REQ.
