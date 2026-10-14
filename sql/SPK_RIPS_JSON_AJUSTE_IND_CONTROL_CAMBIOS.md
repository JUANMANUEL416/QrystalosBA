# SPK_RIPS_JSON_AJUSTE_IND — Resolver factura por CNSFCT o por glosa

| Campo | Valor |
|---|---|
| Referencia | Comparación local `sql/SPK_RIPS_JSON_AJUSTE_IND1.sql` contra la versión `sql_refe/20260914/SPK_RIPS_JSON_AJUSTE_IND.sql` |
| Fecha | 2026-09-23 |
| Objeto a publicar | `DBO.SPK_RIPS_JSON_AJUSTE_IND` (el archivo `IND1` es la copia de trabajo; el `CREATE OR ALTER` sigue llamando al mismo procedimiento) |
| Catálogo DESAIX | Última cerrada **2.0.3** (anterior **2.0.2**). También se consultó **PREVERSION** |
| Estado en canasta | El arreglo **no está** en PREVERSION, ni en 2.0.3, ni en 2.0.2. Las tres traen el `LEFT JOIN FGLO` (longitud 107096, igual que la referencia del 12/09/2026) |

Este documento cubre **únicamente** el cambio de resolución de la factura al inicio de `SPK_RIPS_JSON_AJUSTE_IND`. El resto del procedimiento es idéntico (fórmula de copago, nodos del JSON, parámetros).

## Texto del requerimiento (negocio)

Al armar el RIPS JSON de una **nota de ajuste de evento**, el generador a veces no encuentra la factura. El parámetro llega como consecutivo de **glosa** (`FGLO.CNSGLO`) o como consecutivo de **factura** (`FTR.CNSFCT`). Si la factura ya tiene glosas y se busca por el consecutivo de la factura, el cruce actual no devuelve fila: la procedencia queda vacía y el proceso se detiene con «No se encontró la procedencia de la factura» (o no halla el XML UBL de esa factura).

Objetivo: localizar **una** factura tanto si el dato es el consecutivo de la factura como si es el de una de sus glosas, sin duplicar filas cuando hay varias glosas. Alcance: solo notas de ajuste de evento (no cápita), hoja `SPK_RIPS_JSON_AJUSTE_IND`.

## Procesos y ventanas

| Proceso | Ventana | Cadena |
|---|---|---|
| Generación RIPS JSON (nota de ajuste evento) | Administrativo → FEV RIPS / validación o envío | FE → `SPQ_JSON` `{MODELO:FTR_COL, METODO:RIPS_JSON, PARAMETROS:{CNSFCT, TIPODOC:AJUSTE, GENERAR}}` → `SPK_GENERAR_RIPS_JSON` → `SPK_RIPS_JSON_AJUSTE_IND` (`@CNSGLO` recibe CNSGLO o CNSFCT) |

## Flujo del proceso

1. El usuario pide el RIPS de una nota de ajuste sobre factura de evento ya notificada a la DIAN (`FACTE = 2`, no cápita).
2. El despachador llama `SPK_RIPS_JSON_AJUSTE_IND` y le pasa el consecutivo de la glosa o el de la factura.
3. El procedimiento carga procedencia, admisión, sede, copago, `CNSFCT`, plan y `N_FACTURA`.
4. Con esa factura arma el JSON (consultas, procedimientos, medicamentos, otros servicios, recién nacidos) y el XML FEV.

**Antes (dónde rompía)**

```sql
SELECT @PROCEDENCIA = FTR.PROCEDENCIA, @NOADMISION = FTR.NOREFERENCIA, @IDSEDE = IDSEDE
     , @VALORCOPAGO = CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0)
                           ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0)
                                     ELSE COALESCE(VALORCOPAGO,0) END END
     , @CNSFCT = CNSFCT, @IDPLAN = FTR.IDPLAN, @N_FACTURA = FTR.N_FACTURA
FROM FTR
LEFT JOIN FGLO ON FTR.N_FACTURA = FGLO.N_FACTURA
WHERE @CNSGLO = CASE WHEN FGLO.CNSGLO IS NULL THEN FTR.CNSFCT ELSE FGLO.CNSGLO END
```

- Si la factura **ya tiene glosas**, el `CASE` compara el parámetro solo contra `FGLO.CNSGLO`. Buscar por `FTR.CNSFCT` no devuelve fila.
- El `LEFT JOIN` repite la factura una vez por cada glosa. La asignación a variables, sin `TOP 1`, se queda con la última fila que SQL Server procese.
- Con procedencia vacía, más adelante el procedimiento hace `RAISERROR` «No se encontró la procedencia de la factura». Si `@CNSFCT` queda nulo, tampoco encuentra el UBL en `FDIANR`.

**Después (qué queda cierto)**

```sql
SELECT TOP 1 @PROCEDENCIA = FTR.PROCEDENCIA, @NOADMISION = FTR.NOREFERENCIA, @IDSEDE = IDSEDE
     , @VALORCOPAGO = CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0)
                           ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0)
                                     ELSE COALESCE(VALORCOPAGO,0) END END
     , @CNSFCT = CNSFCT, @IDPLAN = FTR.IDPLAN, @N_FACTURA = FTR.N_FACTURA
FROM FTR
WHERE FTR.CNSFCT = @CNSGLO
   OR EXISTS (
        SELECT 1
        FROM FGLO
        WHERE FGLO.N_FACTURA = FTR.N_FACTURA
          AND FGLO.CNSGLO = @CNSGLO
      )
```

- Coincide la factura por su `CNSFCT` **aunque ya tenga glosas**.
- Coincide por `FGLO.CNSGLO` sin multiplicar filas de `FTR` (`EXISTS`, no `JOIN`).
- `TOP 1` deja una sola asignación.

La fórmula del copago no cambia.

## Solución a publicar

Sustituir en `DBO.SPK_RIPS_JSON_AJUSTE_IND` solo el `SELECT` inicial de cabecera (bloque posterior al `PRINT 'SPK_RIPS_JSON_AJUSTE_IND'`, antes de leer `FDIANR`). Fuente del texto nuevo: `sql/SPK_RIPS_JSON_AJUSTE_IND1.sql`. No crear un procedimiento `…_IND1`.

**Qué no se tocó**

- Parámetros (`@CNSGLO`, `@URL_PATH`, `@PLANO`).
- Cálculo de copago, paquete, nodos RIPS y `FNK_RIPS_JSON_RECIENNACIDOS`.
- `SPK_GENERAR_RIPS_JSON`, FE y las otras hojas (PGP, masiva, cápita, nota crédito/débito).

| Archivo | Cambio |
|---|---|
| `sql/SPK_RIPS_JSON_AJUSTE_IND1.sql` | Copia de trabajo del objeto `SPK_RIPS_JSON_AJUSTE_IND`: el `SELECT` de cabecera busca `FTR` por `CNSFCT` o por existencia de `FGLO.CNSGLO`, con `TOP 1` |

**Punto a confirmar al publicar.** `TOP 1` no trae `ORDER BY`. Si el mismo valor fuera a la vez `CNSFCT` de una factura y `CNSGLO` de la glosa de **otra** factura, la fila elegida no está definida. Si en el entorno esos consecutivos pueden coincidir, ordenar así (primero la factura, después la glosa):

```sql
ORDER BY CASE WHEN FTR.CNSFCT = @CNSGLO THEN 0 ELSE 1 END
```

Ese `ORDER BY` **no** está en `IND1`. La solicitud publica el `SELECT` de `IND1`; el orden solo entra si se confirma el cruce de consecutivos.

## Pruebas sugeridas

**Desarrollador**

- Confirmar en PREVERSION que el `SELECT` sigue siendo el `LEFT JOIN FGLO` (hoy 2026-09-23 lo es en PREVERSION, 2.0.3 y 2.0.2). Si alguien ya lo cambió, no volver a aplicar este bloque a ciegas.
- Publicar solo `SPK_RIPS_JSON_AJUSTE_IND` en el entorno acordado, tomando el cuerpo de `IND1`.
- Caso A: `@CNSGLO` = `FTR.CNSFCT` de una factura de evento **con** al menos una glosa. Debe llenar `@N_FACTURA`, `@PROCEDENCIA` y `@CNSFCT`. No debe salir «No se encontró la procedencia de la factura».
- Caso B: `@CNSGLO` = `FGLO.CNSGLO` de esa misma factura (varias glosas). Debe devolver **esa** factura, una sola vez.
- Caso C: `@CNSGLO` = `FTR.CNSFCT` de una factura **sin** glosas. Mismo resultado que antes.
- Caso D: factura cápita / PGP. No pasa por este procedimiento.

**Coordinador (usuario)**

- En FEV RIPS, generar el JSON de la nota de ajuste de la factura de prueba (la que antes fallaba al buscarla por consecutivo de factura).
- El JSON trae usuarios y servicios de esa factura, no de otra.
- Una nota de ajuste que antes generaba bien sigue igual.

**Soporte**

- Dato: consecutivo que envió el usuario y `N_FACTURA`.
- ¿El valor está en `FTR.CNSFCT` o en `FGLO.CNSGLO`?
- Si no existe en ninguna de las dos, es dato, no el procedimiento.
- Si existe y la procedencia sigue vacía: confirmar que el procedimiento publicado es el de esta solicitud (el `SELECT` nuevo, no el `LEFT JOIN`).
- Rollback: republicar el cuerpo de `sql_refe/20260914/SPK_RIPS_JSON_AJUSTE_IND.sql` (o el de PREVERSION / 2.0.3, que hoy es el mismo cruce).

## Archivos

| Ámbito | Archivo |
|---|---|
| Copia con el cambio (no es otro objeto) | `sql/SPK_RIPS_JSON_AJUSTE_IND1.sql` |
| Versión de referencia (12/09/2026) | `sql_refe/20260914/SPK_RIPS_JSON_AJUSTE_IND.sql` |
| Este documento | `sql/SPK_RIPS_JSON_AJUSTE_IND_CONTROL_CAMBIOS.md` |

No hay cambios de front ni de otros procedimientos.

## Consultas de validación

```sql
-- El parámetro puede ser CNSFCT o CNSGLO
SELECT FTR.CNSFCT, FTR.N_FACTURA, FTR.PROCEDENCIA, FTR.CAPITADA, FTR.FACTE, FTR.TIPOFAC
FROM FTR
WHERE FTR.CNSFCT = @CNSGLO
   OR EXISTS (
        SELECT 1 FROM FGLO
        WHERE FGLO.N_FACTURA = FTR.N_FACTURA
          AND FGLO.CNSGLO = @CNSGLO
      );

SELECT CNSGLO, N_FACTURA, CNSFCT
FROM FGLO
WHERE CNSGLO = @CNSGLO
   OR N_FACTURA IN (SELECT N_FACTURA FROM FTR WHERE CNSFCT = @CNSGLO);
```

Llamada de generación (el usuario la ejecuta en el entorno acordado; aquí no se dispara):

```sql
-- EXEC SPQ_JSON N'{"MODELO":"FTR_COL","METODO":"RIPS_JSON","PARAMETROS":{"CNSFCT":"@CNS","TIPODOC":"AJUSTE","GENERAR":"SI"},"USUARIO":"@USUARIO"}'
```

## Despliegue, impacto y rollback

- Publicar `SPK_RIPS_JSON_AJUSTE_IND` en el servidor SQL del entorno (desarrollo, calidad o producción) con el `SELECT` de `IND1`.
- Impacto: notas de ajuste de evento cuya factura ya tiene glosas y el llamado trae `CNSFCT`, y cualquier llamado por `CNSGLO` (deja de depender del `JOIN`).
- Sin impacto en FE.
- Rollback: republicar la versión del 12/09/2026 (`LEFT JOIN FGLO` + `CASE`).
