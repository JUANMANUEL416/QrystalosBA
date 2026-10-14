CREATE OR ALTER PROCEDURE DBO.SPQ_MOV_ACTIVOS
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT dmy;
    SET LANGUAGE Spanish;

    DECLARE @PARAMETROS     NVARCHAR(MAX),
            @MODELO         VARCHAR(100),
            @METODO         VARCHAR(100),
            @USUARIO        VARCHAR(12),
            @COMPANIA       VARCHAR(2),
            @ANOCONTABLE    VARCHAR(4),
            @MESCONTABLE    VARCHAR(2),
            @ESTADO         VARCHAR(20),
            @ITEMS_JSON     NVARCHAR(MAX),
            @NROCOMPROBANTE VARCHAR(20),
            @IDSEDE         VARCHAR(5),
            @SYS_COMPUTERNAME VARCHAR(254);

    -- Parseo del JSON
    BEGIN TRY
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'KO' AS OK, 'JSON inv�lido' AS ERROR;
            RETURN;
        END

        SELECT 
            @MODELO     = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO     = LTRIM(RTRIM(JSON_VALUE(@JSON, '$.METODO'))),
            @USUARIO    = JSON_VALUE(@JSON, '$.USUARIO'),
            @PARAMETROS = JSON_QUERY(@JSON, '$.PARAMETROS');

        IF @MODELO IS NULL OR @METODO IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Datos incompletos en la petici�n' AS ERROR;
            RETURN;
        END
        
        -- Normalizar m�todo a may�sculas y sin espacios
        SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))));
    END TRY
    BEGIN CATCH
        SELECT 'KO' AS OK, 'Error al parsear JSON: ' + ERROR_MESSAGE() AS ERROR;
        RETURN;
    END CATCH

    -- Obtener datos del usuario
    SELECT 
        @COMPANIA = u.COMPANIA,
        @SYS_COMPUTERNAME = COALESCE(u.SYS_COMPUTERNAME, 'WEB_APP')
    FROM USUSU u
    WHERE u.USUARIO = @USUARIO;
    
    IF @COMPANIA IS NULL
    BEGIN
        SELECT 'KO' AS OK, 'Usuario no encontrado o sin compa��a asignada' AS ERROR;
        RETURN;
    END

    -- Obtener IDSEDE desde UBEQ
    SELECT @IDSEDE = IDSEDE
    FROM UBEQ
    WHERE SYS_ComputerName = @SYS_COMPUTERNAME;

    IF COALESCE(@IDSEDE, '') = ''
        SET @IDSEDE = '01';

    IF COALESCE(@SYS_COMPUTERNAME, '') = ''
        SET @SYS_COMPUTERNAME = 'WEB_APP';

    -- Parseo de par�metros del m�todo
    BEGIN TRY
        SELECT 
            @ANOCONTABLE = JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE'),
            @MESCONTABLE = JSON_VALUE(@PARAMETROS, '$.MESCONTABLE'),
            @ESTADO      = ISNULL(JSON_VALUE(@PARAMETROS, '$.ESTADO'), 'TODAS'),
            @ITEMS_JSON  = JSON_QUERY(@PARAMETROS, '$.ITEMS'),
            @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE');
    END TRY
    BEGIN CATCH
        -- Si falla el parseo, no retornar error aqu�, algunos m�todos no necesitan todos los par�metros
    END CATCH

    -- M�TODO LISTA - Obtener movimientos de activos
    IF @METODO = 'LISTA'
    BEGIN
        IF @ANOCONTABLE IS NULL OR @MESCONTABLE IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'A�o y mes contable son requeridos' AS ERROR;
            RETURN;
        END

        -- Normalizar estado
        DECLARE @ESTADO_LIMPIO VARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@ESTADO, 'TODAS'))));

        BEGIN TRY
            SELECT
                'OK' AS OK,
                IACTH.CNSIACTH AS CNSIACTH,
                IACTH.IDACTIVO AS IDACTIVO,
                ISNULL(IACT.DESCRIPCION, '') AS DESCRIPCION_ACTIVO,
                IACTH.IDEVENTO AS IDEVENTO,
                ISNULL(IACTE.DESCRIPCION, '') AS DESCRIPCION_EVENTO,
                CONVERT(VARCHAR(10), IACTH.FECHAEVENTO, 103) AS FECHAEVENTO,
                ISNULL(IACTH.VALOR, 0) AS VALOR,
                ISNULL(IACTH.IDAREA, '') AS IDAREA,
                ISNULL(AFU.DESCRIPCION, '') AS DESCRIPCION_AREA,
                ISNULL(IACTH.CCOSTO, '') AS CCOSTO,
                ISNULL(CEN.DESCRIPCION, '') AS DESCRIPCION_CCOSTO,
                ISNULL(IACTH.NODOCUMENTO, '') AS NODOCUMENTO,
                ISNULL(IACTH.OBSERVACION, '') AS OBSERVACION,
                ISNULL(IACTH.ESTADO, '') AS ESTADO,
                ISNULL(IACTH.NROCOMPROBANTE, '') AS NROCOMPROBANTE,
                ISNULL(IACTH.CONTABILIZADA, 0) AS CONTABILIZADA,
                -- Estado real para filtro
                CASE 
                    WHEN ISNULL(IACTH.CONTABILIZADA, 0) = 1 
                         AND ISNULL(IACTH.NROCOMPROBANTE, '') <> ''
                        THEN 'ENVIADA'
                    ELSE 'NO_ENVIADA'
                END AS ESTADO_REAL
            FROM IACTH
            LEFT JOIN IACT ON IACTH.IDACTIVO = IACT.IDACTIVO
            LEFT JOIN IACTE ON IACTH.IDEVENTO = IACTE.IDEVENTO
            LEFT JOIN AFU ON IACTH.IDAREA = AFU.IDAREA
            LEFT JOIN CEN ON IACTH.CCOSTO = CEN.CCOSTO
            WHERE YEAR(IACTH.FECHAEVENTO) = CAST(@ANOCONTABLE AS INT)
                AND MONTH(IACTH.FECHAEVENTO) = CAST(@MESCONTABLE AS INT)
                -- Filtro por estado
                AND (
                    @ESTADO_LIMPIO = 'TODAS'
                    OR (
                        @ESTADO_LIMPIO = 'ENVIADAS'
                        AND ISNULL(IACTH.CONTABILIZADA, 0) = 1
                        AND ISNULL(IACTH.NROCOMPROBANTE, '') <> ''
                    )
                    OR (
                        @ESTADO_LIMPIO = 'NO_ENVIADAS'
                        AND (
                            ISNULL(IACTH.CONTABILIZADA, 0) = 0
                            OR ISNULL(IACTH.NROCOMPROBANTE, '') = ''
                        )
                    )
                )
            ORDER BY IACTH.FECHAEVENTO DESC, IACTH.CNSIACTH DESC;

            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, 'Error al consultar movimientos de activos: ' + ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    -- M�TODO CONTABILIZAR - Enviar movimientos a contabilidad
    -- M�TODO CONTABILIZAR (MEJORADO)
IF @METODO = 'CONTABILIZAR'
BEGIN
    IF @ANOCONTABLE IS NULL OR @MESCONTABLE IS NULL
    BEGIN
        SELECT 'KO' AS OK, 'A�o y mes contable son requeridos' AS ERROR;
        RETURN;
    END

    BEGIN TRY
        -- Generar n�mero de comprobante autom�tico si no se proporcion�
        DECLARE @NROCOMP_GENERADO VARCHAR(20);
        IF @NROCOMPROBANTE IS NULL OR @NROCOMPROBANTE = ''
            SET @NROCOMP_GENERADO = CONCAT(@ANOCONTABLE, @MESCONTABLE, '-ACTIVOS');
        ELSE
            SET @NROCOMP_GENERADO = @NROCOMPROBANTE;

        -- Construir ITEMS como JSON v�lido
        DECLARE @ITEMS_ARRAY NVARCHAR(MAX);
        
        IF @ITEMS_JSON IS NOT NULL AND @ITEMS_JSON != '[]' AND @ITEMS_JSON != ''
        BEGIN
            SET @ITEMS_ARRAY = @ITEMS_JSON;
        END
        ELSE
        BEGIN
            SET @ITEMS_ARRAY = '[]';
        END

        -- Construir JSON para SPQ_CONTABILIDAD
        DECLARE @JSON_CONTABILIDAD NVARCHAR(MAX);
        SET @JSON_CONTABILIDAD = N'{
            "MODELO": "CONTABILIDAD",
            "METODO": "CONTAB_MASIVA",
            "USUARIO": "' + @USUARIO + N'",
            "PARAMETROS": {
                "ANOCONTABLE": "' + @ANOCONTABLE + N'",
                "MESCONTABLE": "' + @MESCONTABLE + N'",
                "USUARIO": "' + @USUARIO + N'",
                "PROCEDENCIA": "ACTIVOS_MOV",
                "TIPO_OPERACION": "MOV_ACTIVOS",
                "NROCOMPROBANTE": "' + @NROCOMP_GENERADO + N'",
                "REFERENCIA2": "",
                "ITEMS": ' + @ITEMS_ARRAY + N'
            }
        }';

        PRINT ' Enviando a SPQ_CONTABILIDAD...';
        PRINT @JSON_CONTABILIDAD;

        -- Ejecutar SPQ_CONTABILIDAD
        EXEC SPQ_CONTABILIDAD @JSON_CONTABILIDAD;

        -- SPQ_CONTABILIDAD ya retorna el resultado, no necesitamos hacer nada m�s
        RETURN;
        
    END TRY
    BEGIN CATCH
        SELECT 
            'KO' AS OK, 
            'Error al contabilizar movimientos: ' + ERROR_MESSAGE() AS ERROR,
            ERROR_LINE() AS LINEA_ERROR,
            ERROR_NUMBER() AS ERROR_NUMBER;
        RETURN;
    END CATCH
END


    -- M�TODO RESUMEN - Obtener resumen de movimientos
    IF @METODO = 'RESUMEN'
    BEGIN
        IF @ANOCONTABLE IS NULL OR @MESCONTABLE IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'A�o y mes contable son requeridos' AS ERROR;
            RETURN;
        END

        BEGIN TRY
            SELECT
                COUNT(*) AS TOTAL_MOVIMIENTOS,
                SUM(CASE WHEN ISNULL(CONTABILIZADA, 0) = 1 AND ISNULL(NROCOMPROBANTE, '') <> '' THEN 1 ELSE 0 END) AS ENVIADOS,
                SUM(CASE WHEN ISNULL(CONTABILIZADA, 0) = 0 OR ISNULL(NROCOMPROBANTE, '') = '' THEN 1 ELSE 0 END) AS PENDIENTES,
                SUM(ISNULL(VALOR, 0)) AS VALOR_TOTAL,
                SUM(CASE WHEN ISNULL(CONTABILIZADA, 0) = 1 AND ISNULL(NROCOMPROBANTE, '') <> '' THEN ISNULL(VALOR, 0) ELSE 0 END) AS VALOR_ENVIADO,
                SUM(CASE WHEN ISNULL(CONTABILIZADA, 0) = 0 OR ISNULL(NROCOMPROBANTE, '') = '' THEN ISNULL(VALOR, 0) ELSE 0 END) AS VALOR_PENDIENTE
            FROM IACTH
            WHERE YEAR(FECHAEVENTO) = CAST(@ANOCONTABLE AS INT)
                AND MONTH(FECHAEVENTO) = CAST(@MESCONTABLE AS INT);

            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, 'Error al obtener resumen: ' + ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    -- Si llegamos aqu�, el m�todo no fue reconocido
    SELECT 
        'KO' AS OK,
        'M�todo no implementado: ' + ISNULL(@METODO, 'NULL') AS ERROR;
END
