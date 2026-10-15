# Proceso: Accidentes de tránsito SOAT

**Estado:** esqueleto (grafo Fase 1 cerrada 8/8)  
**Módulo:** ACCTRAN

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

## Resumen

El expediente vive en `HACTRAN`. El usuario lo abre en Asistencial → SOAT o como modal desde admisión (urgencias), triage, agenda CE o autorizador. Pestañas: Accidente, Paciente, Vehículo, Conductor, Remisión, Amparo.

Cadena: expediente → detalle/topes (HACTRAND · RELIQUIDAR) → cargos SOAT (HPRE/HPRED por GFACSOAT) → factura (una FTR por responsable) → FURIPS 1+2 (TXT o JSON) → FURTRAN / FUCTAS / PDF. Satélites: SIRAS, CE (RELIQ/MOV) y certificados. Grafo: 8/8 cerrado.

Amparo: botón para traer datos básicos del paciente. Vehículo y Conductor ya copian AFI (`PACIENTE_COL` · `DATOSAFI`).

Cargos SOAT: responsable 1=Aseguradora, 2=ADRES, 3=EPS, 4=ARL. Abrir la pantalla puede reasignar. Distribuir automático no escribe tercero/plan.

Facturar: una FTR por responsable. El FE pide admisión cerrada; el SP no. Sin tercero/plan de un GFACSOAT lo salta.

FURIPS TXT: el SP devuelve cabecera + líneas; el FE arma FURIPS1*.txt y FURIPS2*.txt. Siempre OK. El SELECT de líneas ya deja nueve campos.

FURIPS JSON: mismo SP. El FE arma FUR_{NIT}.json (ocho grupos) y SER_{NIT}.json. El NIT es el de la institución. Exige número de factura. No es RIPS JSON.

FURTRAN = plano de traslado (una fila). FUCTAS = certificación de servicios. El PDF sí valida firma, representante legal y detalle. El JSON de esos botones envuelve el plano. HACTRANFURT no la escribe este export.

SIRAS: el botón abre el portal; el radicado vive en NOSIRAS / HADM.SIRAS. Confirmar AUT SOAT sincroniza el detalle (no es Reliquidar). Certificados y aviso policial son PDFs de solo lectura.

## Procedimientos (`sps.json`)

HACTRAN 12/12 leídos (no hay DELETE ni RELIQUIDAR). HACTRAND 9/9. DISTRI cargos + FACTURAR. SPK_FACTURA_SOAT_TODO. FURIPS / V2 / V3. SPK_RELIQ_HACTRAN y SPK_MOV_ACTRAN. PACIENTE_COL DATOSAFI listado.

## Capas

### 1. Configuración

Variables `IDTARIFASOAT` / `IDPLANSOAT`. Catálogos de tipo documento.

### 2. Proceso propio

Alta y edición del expediente. Reliquidar detalle/topes. Cargos SOAT por GFACSOAT. Facturar: una FTR por responsable.

### 3. Lo que llega

HADM / triage / CE / autorizador pasan `idafiliado` al modal.

### 4. Subproceso unido

Autorizaciones (`AUT.CNSHACTRAN` → SPK_RELIQ_HACTRAN). FURIPS 1+2 TXT o JSON (mismo SP; el FE remapea). FURTRAN / FUCTAS / PDF por V2/V3. Certificados y SIRAS en SPQ_HACTRAN.

### 5. Contabilidad

La factura SOAT contabiliza (SPK_NC_CONTAB_FTR o cola FTRCO). El asiento no se documentó en este tramo.
