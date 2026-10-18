CREATE OR ALTER PROCEDURE DBO.SPQ_PROCESO_JOB
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT DMY;

    DECLARE @PARAMETROS NVARCHAR(MAX)
          , @MODELO     VARCHAR(100)
          , @METODO     VARCHAR(100)
          , @USUARIO    VARCHAR(20)
          , @CNS        VARCHAR(20)
          , @TIPO       VARCHAR(50)
          , @ESTADO     VARCHAR(20)
          , @COMPANIA   VARCHAR(2)
          , @IDSEDE     VARCHAR(5)
          , @NVOCONSEC  INT
          , @ERROR_MESSAGE NVARCHAR(MAX)
          , @RESULTADO_JSON NVARCHAR(MAX)
    ;

    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO     VARCHAR(100)    '$.MODELO',
        METODO     VARCHAR(100)    '$.METODO',
        USUARIO    VARCHAR(20)     '$.USUARIO',
        PARAMETROS NVARCHAR(MAX)   AS JSON
    );

    SELECT @MODELO = MODELO
         , @METODO = METODO
         , @PARAMETROS = PARAMETROS
         , @USUARIO = USUARIO
    FROM #JSON;
    /* ------------------------------------------------------------------
       INICIAR_JOB — Registra proceso pendiente y devuelve CNS al instante.
       PARAMETROS: { "TIPO": "CIERRE_PERIODO|RIPS_JSON|...", "PARAMETROS": {...} }
    IF @METODO = 'INICIAR_JOB'
    BEGIN
        BEGIN TRY
            SELECT @TIPO = TIPO
                 , @PARAMETROS = COALESCE(JSON_QUERY(J.PARAMETROS), J.PARAMETROS)
            FROM OPENJSON(@PARAMETROS)
            WITH (
                TIPO       VARCHAR(50),
                PARAMETROS NVARCHAR(MAX) AS JSON
            ) J;

            IF COALESCE(@TIPO, '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = N'TIPO es requerido para iniciar el proceso.';
                RETURN;
            END;

            SELECT @COMPANIA = COMPANIA
                 , @IDSEDE = IDSEDE
            FROM USUSU WITH (NOLOCK)
            WHERE USUARIO = @USUARIO;

            IF @COMPANIA IS NULL
            BEGIN
                SELECT 'KO' AS OK, ERROR = N'Usuario sin compañía asignada.';
                RETURN;
            END;

            EXEC DBO.SPK_GENCONSECUTIVO
                 @COMPANIA  = @COMPANIA,
                 @SEDE      = @IDSEDE,
                 @PREFIJO   = '@RPDX',
                 @NVOCONSEC = @NVOCONSEC OUTPUT;

            SET @CNS = @IDSEDE + RIGHT('00000000' + CONVERT(VARCHAR(8), @NVOCONSEC), 8);

            INSERT INTO PROCESO_JOB (CNS, TIPO, ESTADO, USUARIO, PARAMETROS, FECHA_SOLICITUD)
            VALUES (@CNS, @TIPO, N'PENDIENTE', @USUARIO, @PARAMETROS, GETDATE());

            SELECT 'OK' AS OK
                 , CNS = @CNS
                 , ESTADO = N'PENDIENTE'
                 , TIPO = @TIPO;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
        END CATCH

        RETURN;
    END;

    /* ------------------------------------------------------------------
       ACTUALIZAR_ESTADO — Actualiza estado del job (uso interno vía JSON).
       PARAMETROS: { "CNS", "ESTADO", "ERROR_MESSAGE?", "RESULTADO_JSON?" }
    IF @METODO = 'ACTUALIZAR_ESTADO'
    BEGIN
        BEGIN TRY
            SELECT @CNS = CNS
                 , @ESTADO = ESTADO
                 , @ERROR_MESSAGE = ERROR_MESSAGE
                 , @RESULTADO_JSON = RESULTADO_JSON
            FROM OPENJSON(@PARAMETROS)
            WITH (
                CNS             VARCHAR(20),
                ESTADO          VARCHAR(20),
                ERROR_MESSAGE   NVARCHAR(MAX),
                RESULTADO_JSON  NVARCHAR(MAX)
            );

            IF COALESCE(@CNS, '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = N'CNS es requerido.';
                RETURN;
            END;

            UPDATE PROCESO_JOB
            SET ESTADO = @ESTADO,
                FECHA_INICIO = CASE
                    WHEN @ESTADO = N'PROCESANDO' AND FECHA_INICIO IS NULL THEN GETDATE()
                    ELSE FECHA_INICIO
                END,
                FECHA_FIN = CASE
                    WHEN @ESTADO IN (N'COMPLETADO', N'OK', N'ERROR') THEN GETDATE()
                    ELSE FECHA_FIN
                END,
                ERROR_MESSAGE = COALESCE(@ERROR_MESSAGE, ERROR_MESSAGE),
                RESULTADO_JSON = COALESCE(@RESULTADO_JSON, RESULTADO_JSON)
            WHERE CNS = @CNS;

            SELECT 'OK' AS OK, CNS = @CNS, ESTADO = @ESTADO;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
        END CATCH

        RETURN;
    END;

    /* ------------------------------------------------------------------
       CONSULTAR_ESTADO_JOB — Misma forma de respuesta que CONTABILIDAD_2 / RPDX_JOBS.
       PARAMETROS: { "CNS": "..." }
    IF @METODO = 'CONSULTAR_ESTADO_JOB'
    BEGIN
        BEGIN TRY
            SELECT @CNS = CNS
            FROM OPENJSON(@PARAMETROS)
            WITH (CNS VARCHAR(20));

            IF COALESCE(@CNS, '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = N'CNS es requerido.';
                RETURN;
            END;

            IF EXISTS (SELECT 1 FROM PROCESO_JOB WITH (NOLOCK) WHERE CNS = @CNS)
            BEGIN
                SELECT 'OK' AS OK
                     , PJ.CNS
                     , PJ.TIPO
                     , PJ.ESTADO
                     , FECHA_INICIO = COALESCE(PJ.FECHA_INICIO, PJ.FECHA_SOLICITUD)
                     , PJ.FECHA_FIN
                     , PJ.ERROR_MESSAGE
                     , PJ.RESULTADO_JSON
                     , TIEMPO_TRANSCURRIDO = DATEDIFF(
                           SECOND,
                           COALESCE(PJ.FECHA_INICIO, PJ.FECHA_SOLICITUD),
                           COALESCE(PJ.FECHA_FIN, GETDATE())
                       )
                FROM PROCESO_JOB PJ WITH (NOLOCK)
                WHERE PJ.CNS = @CNS;
                RETURN;
            END;

            IF EXISTS (SELECT 1 FROM RPDX_JOBS WITH (NOLOCK) WHERE CNS = @CNS)
            BEGIN
                SELECT 'OK' AS OK
                     , RJ.CNS
                     , TIPO = CAST(N'LIBROS_AUX' AS VARCHAR(50))
                     , RJ.ESTADO
                     , RJ.FECHA_INICIO
                     , RJ.FECHA_FIN
                     , RJ.ERROR_MESSAGE
                     , RESULTADO_JSON = CAST(NULL AS NVARCHAR(MAX))
                     , TIEMPO_TRANSCURRIDO = DATEDIFF(
                           SECOND,
                           COALESCE(RJ.FECHA_INICIO, GETDATE()),
                           COALESCE(RJ.FECHA_FIN, GETDATE())
                       )
                FROM RPDX_JOBS RJ WITH (NOLOCK)
                WHERE RJ.CNS = @CNS;
                RETURN;
            END;

            SELECT 'KO' AS OK, ERROR = N'Job no encontrado.';
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
        END CATCH

        RETURN;
    END;

    SELECT 'KO' AS OK, ERROR = N'Método no implementado: ' + COALESCE(@METODO, '');
END;
