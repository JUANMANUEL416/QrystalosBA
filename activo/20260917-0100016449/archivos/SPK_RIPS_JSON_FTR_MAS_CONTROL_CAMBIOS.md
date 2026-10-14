# SPK_RIPS_JSON_FTR_MAS — Cuerpo de paquete CI entra al RIPS JSON

| Campo | Valor |
|---|---|
| Rama | `feature/RIPS_JSON_MAS_USUARIOS` |
| Referencia / ticket | RIPS JSON masivo: factura paquete sin usuarios (RVG01) |
| Fecha | 2026-09-18 |
| Commit | N/A — el SP vive solo en `SQL/` (no va en git) |
| Objeto | `DBO.SPK_RIPS_JSON_FTR_MAS` |
| Caso de prueba | Factura masiva de citas, `FTR.PAQUETE = 1`, valor en `FTRD.PAQUETE = 0` |

Este documento cubre **únicamente** el cambio de `SPK_RIPS_JSON_FTR_MAS`. No incluye otros scripts de la rama (por ejemplo actualización de `CCOSTO` en `FTRD`).

## Texto del requerimiento (negocio / ticket)

Al generar el RIPS JSON de una factura **masiva de citas** marcada como paquete, el sobre salía con XML pero **sin usuarios**. SISPRO respondía **RVG01**: los datos de usuario son obligatorios.

El valor de la factura no está en la cabecera `FTRD.PAQUETE = 1`, sino en un **cuerpo** `FTRD.PAQUETE = 0` (o con `VR_TOTAL > 0`). Esa línea tenía `PROCEDENCIA` nula, así que el generador no la veía como cita.

Objetivo: que ese cuerpo tome procedencia CI, entre el afiliado y la consulta AC, y el JSON quede completo. Alcance: solo facturas `TIPOFAC = M` / `PROCEDENCIA = CI` / `FTR.PAQUETE = 1`. Criterio: `rips.usuarios` ≥ 1 y al menos una consulta; el valor del servicio es el de `FTRD`.

## Procesos y ventanas

| Proceso | Ventana | Cadena |
|---|---|---|
| Generación RIPS JSON (factura masiva) | Administrativo → FEV RIPS / validación o envío de factura | FE → `SPQ_JSON` `{MODELO:FTR_COL, METODO:RIPS_JSON, PARAMETROS:{CNSFCT, TIPODOC:FACTURA, GENERAR}}` → `SPQ_FTR_COL` → `SPK_GENERAR_RIPS_JSON` → `SPK_RIPS_JSON_FTR_MAS` |

## Flujo del proceso

1. El usuario pide RIPS de una factura notificada a la DIAN (`FACTE = 2`), `TIPOFAC = M`, `PROCEDENCIA = CI`, `FTR.PAQUETE = 1`.
2. `RIPS_JSON` con `GENERAR = SI` llama al masivo.
3. El masivo, si la factura es paquete CI, rellena `FTRD.PROCEDENCIA = CI` en las líneas que aún no la tienen.
4. Con esas líneas arma `#USUARIOS` y consultas (archivo AC) y devuelve `{ rips, xmlFevFile }`.

**Antes (dónde rompía)**

El `UPDATE` de procedencia solo tocaba `FTRD.PAQUETE = 1`. El cuerpo con el dinero (`PAQUETE = 0`, `PROCEDENCIA` nula) no pasaba el `WHERE PROCEDENCIA = 'CI'`. El JSON quedaba en cabecera (`numFactura`, nit) **sin `usuarios`**. SISPRO: RVG01.

**Después (qué queda cierto)**

El mismo `UPDATE` usa la regla de **cuerpos**: `PAQUETE IN (0, 3)` **o** `VR_TOTAL > 0` (y acepta procedencia nula o vacía). Esa línea pasa a CI, entra el afiliado y la consulta AC con `VLR_SERVICI` / `VR_TOTAL` de `FTRD`. Las líneas `PAQUETE = 2` en cero no se tratan como cuerpo.

## Solución realizada

Se restauró el invariante: **el cuerpo con valor es el que reporta el RIPS**, no la cabecera `PAQUETE = 1`.

El 16/09 el `UPDATE` se había restringido a `PAQUETE = 1`. En el caso real el valor está en `PAQUETE = 0` (a veces `NOITEM = 99`). Se alineó el `UPDATE` a la misma condición que ya usan los `INSERT` de usuarios y consultas.

**Qué no se tocó**

- Filtros de inclusión de `#USUARIOS` / `#CONSULTAS` (`PAQUETE IN (0, 3)` o `VR_TOTAL > 0`).
- No se agregó `PAQUETE = 2` como cuerpo.
- No se exige `PPT.PAQUETIZADO = 1`.
- `SPQ_FTR_COL`, `SPK_GENERAR_RIPS_JSON`, FE y otros generadores (IND, PGP, CAPI, AUTPG).

| Archivo | Cambio |
|---|---|
| `SQL/SPK_RIPS_JSON_FTR_MAS.sql` | `UPDATE FTRD.PROCEDENCIA = CI` en factura paquete CI: cuerpos `PAQUETE IN (0, 3)` o `VR_TOTAL > 0`; también si la procedencia viene vacía (`''`), no solo `NULL` |

Zona: bloque `/*USUARIOS*/`, al inicio, cuando `@PAQUETE = 1` y `@PROCEDENCIA = 'CI'`.

## Pruebas sugeridas

**Desarrollador**

- Publicar solo `SPK_RIPS_JSON_FTR_MAS` en el entorno acordado.
- `GENERAR = SI` sobre un `@CNSFCT` de factura masiva CI paquete cuyo valor está en `FTRD.PAQUETE = 0` y `PROCEDENCIA` nula.
- Tras generar: `OPENJSON(JSON_ENVIO, '$.rips.usuarios')` ≥ 1 y al menos una consulta en `$.rips.usuarios[].servicios.consultas`.
- Factura masiva **sin** paquete: mismos usuarios/servicios que antes.
- Factura individual (`TIPOFAC` distinto de `M`): no pasa por este SP.

**Coordinador (usuario)**

- En FEV RIPS, «Validar ahora» / generar JSON de la factura de prueba: ya no RVG01 por usuarios vacíos.
- El valor de la consulta coincide con el de la factura.
- Una factura masiva de citas que antes armaba bien el JSON sigue igual.

**Soporte**

- Dato: `@CNSFCT` / `@N_FACTURA` del cliente. Confirmar `FTR.TIPOFAC = M`, `PROCEDENCIA = CI`, `PAQUETE = 1`, `FACTE = 2`.
- En `FTRD`: ¿hay línea `PAQUETE IN (0, 3)` o `VR_TOTAL > 0` con `NOADMISION` de cita?
- Si no hay cuerpo con valor, es dato, no el SP.
- Si el cuerpo existe, tiene cita y el JSON sigue sin usuarios: confirmar que el SP publicado es el de esta rama.
- Rollback: restaurar el SP anterior (el `UPDATE` otra vez solo con `PAQUETE = 1`).

## Archivos / módulos afectados

| Ámbito | Archivo |
|---|---|
| Solo local (`SQL/`, no git) | `SQL/SPK_RIPS_JSON_FTR_MAS.sql` |
| Este documento | `SQL/SPK_RIPS_JSON_FTR_MAS_CONTROL_CAMBIOS.md` |

No hay cambios de front ni de otros SP.

## Consultas / comandos de validación

```sql
SELECT CNSFCT, N_FACTURA, TIPOFAC, PROCEDENCIA, PAQUETE, FACTE, IDPLAN
FROM FTR
WHERE CNSFCT = @CNSFCT;

SELECT N_CUOTA, REFERENCIA, NOITEM, PAQUETE, PROCEDENCIA, VLR_SERVICI, VR_TOTAL, NOADMISION
FROM FTRD
WHERE CNSFTR = @CNSFCT
ORDER BY N_CUOTA;

SELECT
  JSON_VALUE(JSON_ENVIO, '$.rips.numFactura') AS NUMFACT,
  (SELECT COUNT(*) FROM OPENJSON(JSON_ENVIO, '$.rips.usuarios')) AS CANT_USUARIOS,
  (SELECT COUNT(*)
   FROM OPENJSON(JSON_ENVIO, '$.rips.usuarios') U
   CROSS APPLY OPENJSON(U.value, '$.servicios.consultas')) AS CANT_CONSULTAS
FROM FTRJSON
WHERE CNSFCT = @CNSFCT;
```

Llamada de generación (el usuario la ejecuta en el entorno acordado; aquí no se dispara):

```sql
-- EXEC SPQ_JSON N'{"MODELO":"FTR_COL","METODO":"RIPS_JSON","PARAMETROS":{"CNSFCT":"@CNSFCT","TIPODOC":"FACTURA","GENERAR":"SI"},"USUARIO":"@USUARIO"}'
```

## Despliegue, impacto y rollback

- Publicar `SPK_RIPS_JSON_FTR_MAS` en el servidor SQL del entorno (desarrollo, calidad o producción).
- Impacto: facturas masivas de paquete CI cuyo cuerpo con valor tiene `PAQUETE IN (0, 3)` o `VR_TOTAL > 0` y procedencia nula o vacía. Al generar, ese `UPDATE` escribe `FTRD.PROCEDENCIA = CI` en esas líneas.
- Sin impacto en FE.
- Rollback: republicar el SP previo al 18/09/2026 (condición `FTRD.PAQUETE = 1` en el `UPDATE` de procedencia).
