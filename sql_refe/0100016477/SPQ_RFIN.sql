CREATE OR ALTER PROCEDURE DBO.SPQ_RFIN
@JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @PROCESO VARCHAR(50),
        @USUARIO VARCHAR(20),
        @NOMBRE_ARCHIVO VARCHAR(256),
        @DETALLE_JSON NVARCHAR(MAX),
        @ID_CARGA INT,
        @TOTAL_REGISTROS INT,
        @TOTAL_OK INT = 0,
        @TOTAL_KO INT = 0,
        @TOTAL_INC INT = 0,
        @ErrorMessage NVARCHAR(4000);

    -- 1. Parsear el JSON base
    SELECT 
        @MODELO = JSON_VALUE(@JSON, '$.MODELO'),
        @METODO = JSON_VALUE(@JSON, '$.METODO'),
        @PARAMETROS = JSON_QUERY(@JSON, '$.PARAMETROS')
    
    IF @METODO = 'CARGAR_PAGOS'
    BEGIN
        SELECT 
            @PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @NOMBRE_ARCHIVO = JSON_VALUE(@PARAMETROS, '$.NOMBRE_ARCHIVO'),
            @DETALLE_JSON = JSON_QUERY(@PARAMETROS, '$.DETALLE')

        DECLARE @ErroresCarga TABLE (
            RADICADO VARCHAR(50) NULL,
            DESCRIPCION_ERROR VARCHAR(500)
        );

        -- Tabla temporal para procesar el Excel (Estilo RLOT)
        SELECT 
            TRIM(RADICADO) AS RADICADO, 
            MES_PERIODO, 
            OBSERVACION, 
            ESTADO_ENTIDAD, 
            PAGO, 
            ACUMULADO, 
            SALDO,
            CAST(NULL AS INT) AS IDRLOTD_REF,
            CAST(NULL AS DECIMAL(5,2)) AS INTERPRETADO,
            CAST(NULL AS VARCHAR(30)) AS ESTADO_FINAL,
            CAST(NULL AS VARCHAR(MAX)) AS MOTIVO_INC
        INTO #EXCEL_TMP
        FROM OPENJSON(@DETALLE_JSON)
        WITH (
            RADICADO VARCHAR(50) '$.RADICADO',
            MES_PERIODO VARCHAR(50) '$.MES_PERIODO',
            OBSERVACION VARCHAR(MAX) '$.OBSERVACION',
            ESTADO_ENTIDAD VARCHAR(50) '$.ESTADO_ENTIDAD',
            PAGO DECIMAL(18,2) '$.PAGO',
            ACUMULADO DECIMAL(18,2) '$.ACUMULADO',
            SALDO DECIMAL(18,2) '$.SALDO'
        )
        -- Aplicar Collation Database Default a las columnas de texto
        ALTER TABLE #EXCEL_TMP ALTER COLUMN RADICADO VARCHAR(50) COLLATE DATABASE_DEFAULT;
        ALTER TABLE #EXCEL_TMP ALTER COLUMN MES_PERIODO VARCHAR(50) COLLATE DATABASE_DEFAULT;
        ALTER TABLE #EXCEL_TMP ALTER COLUMN OBSERVACION VARCHAR(MAX) COLLATE DATABASE_DEFAULT;
        ALTER TABLE #EXCEL_TMP ALTER COLUMN ESTADO_ENTIDAD VARCHAR(50) COLLATE DATABASE_DEFAULT;

        SET @TOTAL_REGISTROS = @@ROWCOUNT

        -- 1.5 Limpieza de filas totalmente vac�as
        DELETE FROM #EXCEL_TMP 
        WHERE ISNULL(RADICADO,'') = '' 
          AND ISNULL(MES_PERIODO,'') = '' 
          AND ISNULL(OBSERVACION,'') = '' 
          AND ISNULL(PAGO,0) = 0;

        -- 1.5.1 Valido que el Excel no haya quedado vac�o tras la limpieza
        IF NOT EXISTS (SELECT 1 FROM #EXCEL_TMP)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El archivo Excel no contiene registros v�lidos o est� vac�o.';
            SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
            DROP TABLE #EXCEL_TMP;
            RETURN;
        END

        SELECT @TOTAL_REGISTROS = COUNT(*) FROM #EXCEL_TMP;

        -- 1.6 Validaci�n BLOQUEANTE (Contenido Cr�tico y Estructura)
        INSERT INTO @ErroresCarga (RADICADO, DESCRIPCION_ERROR)
        SELECT 
            ISNULL(RADICADO, 'Fila ' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS VARCHAR)), 
            CASE 
                WHEN ISNULL(RADICADO,'') = '' AND ISNULL(OBSERVACION, '') = '' THEN 'ERROR: Falta Radicado y falta Observaci�n.'
                WHEN ISNULL(RADICADO,'') = '' THEN 'ERROR: El Radicado es obligatorio para procesar la fila.'
                WHEN ISNULL(OBSERVACION, '') = '' THEN 'ERROR: La Observaci�n es obligatoria (se requiere para calcular el pago).'
                ELSE 'ERROR: Radicado duplicado para el mismo periodo dentro del archivo.'
            END
        FROM #EXCEL_TMP
        WHERE ISNULL(RADICADO,'') = '' OR ISNULL(OBSERVACION, '') = ''
        OR RADICADO IN (
            SELECT RADICADO FROM #EXCEL_TMP 
            WHERE RADICADO IS NOT NULL AND RADICADO <> ''
            GROUP BY RADICADO, MES_PERIODO HAVING COUNT(*) > 1
        );

        IF EXISTS (SELECT 1 FROM @ErroresCarga)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Carga Cancelada: Se encontraron errores de contenido (vac�os o duplicados). Por favor descargue el detalle, corrija el archivo y reintente.';
            SELECT * FROM @ErroresCarga;
            DROP TABLE #EXCEL_TMP;
            RETURN;
        END

        -- 2. Validaciones Masivas (Estilo RLOT)
        -- Vincular radicados existentes (Crucial: TRIM en RD.RADICADO por si tiene espacios o es CHAR)
        UPDATE T
        SET T.IDRLOTD_REF = RD.IDRLOTD
        FROM #EXCEL_TMP T
        INNER JOIN RLOTD RD ON TRIM(T.RADICADO) = TRIM(RD.RADICADO)

        -- 2.1 Validaci�n BLOQUEANTE: Radicados que NO existen en el sistema
        INSERT INTO @ErroresCarga (RADICADO, DESCRIPCION_ERROR)
        SELECT 
            RADICADO, 
            'ERROR: El radicado no existe en el sistema de facturaci�n. No se puede asociar a una factura.'
        FROM #EXCEL_TMP
        WHERE IDRLOTD_REF IS NULL;

        IF EXISTS (SELECT 1 FROM @ErroresCarga)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Carga Cancelada: Existen radicados en el archivo que no est�n registrados en el sistema. Por favor verifique los n�meros de radicado y reintente.';
            SELECT * FROM @ErroresCarga;
            DROP TABLE #EXCEL_TMP;
            RETURN;
        END

        -- D. Interpretaci�n y Reglas de Negocio (Mejorada para porcentajes din�micos y periodos seg�n levantamiento)
        UPDATE #EXCEL_TMP
        SET MES_PERIODO = TRIM(CASE 
                WHEN ISNULL(MES_PERIODO,'') = '' THEN 
                    COALESCE(
                        (SELECT TOP 1 M FROM (VALUES ('ENERO'),('FEBRERO'),('MARZO'),('ABRIL'),('MAYO'),('JUNIO'),('JULIO'),('AGOSTO'),('SEPTIEMBRE'),('OCTUBRE'),('NOVIEMBRE'),('DICIEMBRE')) AS Months(M) 
                         WHERE UPPER(#EXCEL_TMP.OBSERVACION) LIKE '%' + M + '%'), 
                        ''
                    ) + 
                    COALESCE(
                        ' ' + SUBSTRING(#EXCEL_TMP.OBSERVACION, PATINDEX('%20[2-9][0-9]%', #EXCEL_TMP.OBSERVACION), 4),
                        ''
                    ) +
                    -- Detecci�n de secuencial de pago (ej: - 1)
                    COALESCE(
                        ' - ' + SUBSTRING(SUBSTRING(OBSERVACION, CHARINDEX('%', OBSERVACION)+1, 10), 
                                          PATINDEX('%[0-9]%', SUBSTRING(OBSERVACION, CHARINDEX('%', OBSERVACION)+1, 10)), 
                                          1),
                        ''
                    )
                ELSE MES_PERIODO
            END),
            INTERPRETADO = CASE 
                WHEN (OBSERVACION LIKE '%NO APLICA%' OR OBSERVACION LIKE '%CERO%') AND OBSERVACION NOT LIKE '%APLICA PARA%' THEN 0.00
                WHEN OBSERVACION LIKE '%100%' OR (OBSERVACION LIKE '%APLICA%' AND OBSERVACION NOT LIKE '%NO APLICA%') OR OBSERVACION LIKE '%TOTAL%' THEN 100.00
                -- Extracci�n din�mica de porcentajes (busca d�gitos antes del %)
                WHEN CHARINDEX('%', OBSERVACION) > 1 THEN 
                    TRY_CAST(REVERSE(LEFT(REVERSE(SUBSTRING(OBSERVACION, 1, CHARINDEX('%', OBSERVACION)-1)), 
                             PATINDEX('%[^0-9]%', REVERSE(SUBSTRING(OBSERVACION, 1, CHARINDEX('%', OBSERVACION)-1)) + ' ') - 1
                            )) AS DECIMAL(5,2))
                WHEN OBSERVACION LIKE '%50%' OR OBSERVACION LIKE '%PARCIAL%' THEN 50.00
                ELSE -1.00 
            END

        -- E. Validaci�n de Reglas Funcionales (Marcaci�n de Inconsistencias individualmente)
        -- Nota: IDRLOTD_REF IS NULL ya no es posible aqu� porque se bloquea en validaci�n 2.1
        UPDATE #EXCEL_TMP
        SET MOTIVO_INC = CASE 
                WHEN INTERPRETADO = -1.00 THEN 'No se pudo interpretar el porcentaje o estado en la observaci�n.'
                -- Regla: Mismo Radicado + Mes ya procesado anteriormente
                WHEN EXISTS (SELECT 1 FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND MES_PERIODO = #EXCEL_TMP.MES_PERIODO AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente' AND PORCENTAJE_INTERPRETADO > 0) 
                     THEN 'Este radicado ya cuenta con un pago registrado para el periodo: ' + #EXCEL_TMP.MES_PERIODO
                -- Regla 1: No superar el 100%
                WHEN (SELECT COALESCE(SUM(PORCENTAJE_INTERPRETADO), 0) FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente') + INTERPRETADO > 100.00 
                     THEN 'El pago total acumulado exceder�a el 100% permitido.'
                -- Regla 2: M�ximo 2 pagos parciales
                WHEN INTERPRETADO > 0 AND INTERPRETADO < 100.00 AND (SELECT COUNT(*) FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND PORCENTAJE_INTERPRETADO > 0 AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente') >= 2 
                     THEN 'Se ha alcanzado el l�mite m�ximo de 2 pagos parciales para este radicado.'
                ELSE NULL
            END,
            ESTADO_FINAL = CASE 
                WHEN INTERPRETADO = -1.00 OR 
                     EXISTS (SELECT 1 FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND MES_PERIODO = #EXCEL_TMP.MES_PERIODO AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente' AND PORCENTAJE_INTERPRETADO > 0) OR
                     ((SELECT COALESCE(SUM(PORCENTAJE_INTERPRETADO), 0) FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente') + INTERPRETADO > 100.00) OR
                     (INTERPRETADO > 0 AND INTERPRETADO < 100.00 AND (SELECT COUNT(*) FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND PORCENTAJE_INTERPRETADO > 0 AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente') >= 2)
                THEN 'Inconsistente'
                WHEN INTERPRETADO = 100.00 OR (SELECT COALESCE(SUM(PORCENTAJE_INTERPRETADO), 0) FROM RFIN_HISTORIAL WHERE RADICADO = #EXCEL_TMP.RADICADO AND ESTADO_RESULTANTE_SISTEMA <> 'Inconsistente') + INTERPRETADO = 100.00 THEN 'Pagado 100%'
                WHEN INTERPRETADO > 0.00 AND INTERPRETADO < 100.00 THEN 'Pago Parcial'
                WHEN INTERPRETADO = 0.00 THEN 'No Aplica'
                ELSE 'Inconsistente'
            END

        -- 3. Inserci�n Final (Flujo No Bloqueante)
        -- No salimos si hay errores, procesamos todo marcando inconsistencias

        -- 4. Inserci�n Final (Proceso Limpio)
        BEGIN TRANSACTION
        BEGIN TRY
            -- Asegurar que el total sea el de la tabla temporal filtrada
            SELECT @TOTAL_REGISTROS = COUNT(*) FROM #EXCEL_TMP;

            INSERT INTO RFIN_CARGA (NOMBRE_ARCHIVO, USUARIO_RESPONSABLE, TOTAL_REGISTROS)
            VALUES (@NOMBRE_ARCHIVO, @USUARIO, @TOTAL_REGISTROS)
            
            SET @ID_CARGA = SCOPE_IDENTITY()

            INSERT INTO RFIN_HISTORIAL (
                IDCARGA, NOMBRE_ARCHIVO, USUARIO_CARGA, RADICADO, MES_PERIODO, 
                OBSERVACION_ORIGINAL, ESTADO_ENTIDAD, PAGO_EXCEL, ACUMULADO_EXCEL, 
                SALDO_EXCEL, PORCENTAJE_INTERPRETADO, ESTADO_RESULTANTE_SISTEMA, 
                DETALLE_INCONSISTENCIA, IDRLOTD
            )
            SELECT 
                @ID_CARGA, @NOMBRE_ARCHIVO, @USUARIO, RADICADO, MES_PERIODO,
                OBSERVACION, ESTADO_ENTIDAD, PAGO, ACUMULADO,
                SALDO, INTERPRETADO,
                ESTADO_FINAL,
                MOTIVO_INC, IDRLOTD_REF
            FROM #EXCEL_TMP

            -- Actualizar contadores
            UPDATE RFIN_CARGA 
            SET TOTAL_OK = (SELECT COUNT(*) FROM #EXCEL_TMP WHERE ESTADO_FINAL <> 'Inconsistente'),
                TOTAL_INCONSISTENTES = (SELECT COUNT(*) FROM #EXCEL_TMP WHERE ESTADO_FINAL = 'Inconsistente')
            WHERE IDCARGA = @ID_CARGA

            COMMIT TRANSACTION
            SELECT 'OK' AS OK;
            SELECT IDCARGA = @ID_CARGA;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SELECT @ErrorMessage = ERROR_MESSAGE();
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error interno en la base de datos: ' + @ErrorMessage;
            SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
        END CATCH

        DROP TABLE #EXCEL_TMP
    END

    
    IF @METODO = 'DASHBOARD'
    BEGIN
        SELECT 
            TOTAL_PROCESADOS = (SELECT COALESCE(SUM(TOTAL_REGISTROS), 0) FROM RFIN_CARGA),
            TOTAL_EXITOSOS = (SELECT COALESCE(SUM(TOTAL_OK), 0) FROM RFIN_CARGA),
            TOTAL_INCONSISTENTES = (SELECT COALESCE(SUM(TOTAL_INCONSISTENTES), 0) FROM RFIN_CARGA),
            PAGOS_PARCIALES = (SELECT COUNT(DISTINCT RADICADO) FROM RFIN_HISTORIAL WHERE ESTADO_RESULTANTE_SISTEMA LIKE '%Parcial%'),
            PAGOS_TOTALES = (SELECT COUNT(DISTINCT RADICADO) FROM RFIN_HISTORIAL WHERE ESTADO_RESULTANTE_SISTEMA LIKE '%100%'),
            PAGOS_NO_APLICA = (SELECT COUNT(DISTINCT RADICADO) FROM RFIN_HISTORIAL WHERE ESTADO_RESULTANTE_SISTEMA LIKE '%No Aplica%')
    END

    IF @METODO = 'LISTAR_DETALLE_CARGA'
    BEGIN
        DECLARE @ID_CARGA_BUSCAR INT = JSON_VALUE(@PARAMETROS, '$.IDCARGA')

        SELECT 
            H.*, 
            RD.NRO_FACTURA,
            RD.VALOR_FACTURA_INT
        FROM RFIN_HISTORIAL H
        LEFT JOIN RLOTD RD ON H.IDRLOTD = RD.IDRLOTD
        WHERE H.IDCARGA = @ID_CARGA_BUSCAR
        ORDER BY H.IDHISTORIAL ASC
    END


    IF @METODO = 'BUSCAR_RADICADO'
    BEGIN
        DECLARE @RADICADO_BUSCAR VARCHAR(50) = JSON_VALUE(@PARAMETROS, '$.RADICADO')

        SELECT 
            H.*, 
            C.FECHA_PROCESO,
            RD.NRO_FACTURA,
            TOTAL_PAGADO = SUM(CASE WHEN H.ESTADO_RESULTANTE_SISTEMA NOT LIKE '%Inconsistente%' THEN H.PORCENTAJE_INTERPRETADO ELSE 0 END) OVER(),
            CONTEO_PAGOS = SUM(CASE WHEN H.ESTADO_RESULTANTE_SISTEMA NOT LIKE '%Inconsistente%' THEN 1 ELSE 0 END) OVER()
        FROM RFIN_HISTORIAL H
        INNER JOIN RFIN_CARGA C ON H.IDCARGA = C.IDCARGA
        LEFT JOIN RLOTD RD ON H.IDRLOTD = RD.IDRLOTD
        WHERE H.RADICADO = @RADICADO_BUSCAR
        ORDER BY H.IDHISTORIAL DESC
    END

    IF @METODO = 'REPORTE_PAGOS_TOTALES'
    BEGIN
        DECLARE @MES INT = JSON_VALUE(@PARAMETROS, '$.MES')
        DECLARE @ANIO INT = JSON_VALUE(@PARAMETROS, '$.ANIO')

        -- Retorna �nicamente los KPIs para las tarjetas superiores del reporte
        SELECT 
            OK = 'OK',
            TOTAL_REGISTROS = COUNT(*),
            PAGOS_EFECTIVOS = SUM(CASE WHEN ESTADO_RESULTANTE_SISTEMA = 'Pagado 100%' THEN 1 ELSE 0 END),
            PAGOS_PARCIALES = SUM(CASE WHEN ESTADO_RESULTANTE_SISTEMA = 'Pago Parcial' THEN 1 ELSE 0 END),
            INCONSISTENCIAS = SUM(CASE WHEN ESTADO_RESULTANTE_SISTEMA = 'Inconsistente' THEN 1 ELSE 0 END)
        FROM RFIN_HISTORIAL
        WHERE MONTH(FECHA_CARGA) = @MES 
          AND YEAR(FECHA_CARGA) = @ANIO;
    END

    IF @METODO = 'REPORTE_PAGOS_MENSUAL'
    BEGIN
        DECLARE @MES_M INT = JSON_VALUE(@PARAMETROS, '$.MES')
        DECLARE @ANIO_M INT = JSON_VALUE(@PARAMETROS, '$.ANIO')

        -- Patr�n de Recordset �nico (Standard del Proyecto)
        -- Evita el modal de error por recordsets.length > 1 y simplifica el mapeo
        SELECT 
            OK = 'OK',
            H.IDHISTORIAL,
            H.FECHA_CARGA,
            H.RADICADO,
            RD.NRO_FACTURA,
            H.MES_PERIODO,
            H.OBSERVACION_ORIGINAL,
            H.PAGO_EXCEL,
            H.PORCENTAJE_INTERPRETADO,
            H.ESTADO_RESULTANTE_SISTEMA,
            H.DETALLE_INCONSISTENCIA,
            H.USUARIO_CARGA,
            U.NOMBRE AS NOMBRE_USUARIO_CARGA,
            H.NOMBRE_ARCHIVO,
            -- Totales calculados sobre el set filtrado completo
            TOTAL_REGISTROS = COUNT(*) OVER(),
            PAGOS_EFECTIVOS = SUM(CASE WHEN H.ESTADO_RESULTANTE_SISTEMA = 'Pagado 100%' THEN 1 ELSE 0 END) OVER(),
            PAGOS_PARCIALES = SUM(CASE WHEN H.ESTADO_RESULTANTE_SISTEMA = 'Pago Parcial' THEN 1 ELSE 0 END) OVER(),
            INCONSISTENCIAS = SUM(CASE WHEN H.ESTADO_RESULTANTE_SISTEMA = 'Inconsistente' THEN 1 ELSE 0 END) OVER()
        FROM RFIN_HISTORIAL H
        LEFT JOIN RLOTD RD ON H.IDRLOTD = RD.IDRLOTD
        LEFT JOIN USUSU U ON H.USUARIO_CARGA = U.USUARIO
        WHERE MONTH(H.FECHA_CARGA) = @MES_M 
          AND YEAR(H.FECHA_CARGA) = @ANIO_M
        ORDER BY H.FECHA_CARGA DESC, H.IDHISTORIAL DESC;
    END
END
