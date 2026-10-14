CREATE OR ALTER PROCEDURE dbo.SPQ_CONTA_LIQIMP
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET LANGUAGE Spanish;

    DECLARE @MODELO           VARCHAR(100),
            @METODO           VARCHAR(100),
            @USUARIO          VARCHAR(20),
            @PARAMETROS       NVARCHAR(MAX),
            @SYS_COMPUTERNAME VARCHAR(254),
            @SEDE             VARCHAR(6),
            @COMPANIA         VARCHAR(2),
            @ANO              SMALLINT,
            @MES              SMALLINT,
            @CUENTAINI        VARCHAR(20),
            @CUENTAFINAL      VARCHAR(20),
            @IDTERCERO        VARCHAR(20),
            @F_CERTIFICADO    DATE,
            @CNSFCXP          VARCHAR(20);

    BEGIN TRY
        -- Validar formato del JSON
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'KO' AS OK, 'JSON inv�lido' AS ERROR;
            RETURN;
        END

        -- Extraer propiedades principales
        SELECT @MODELO     = MODELO,
               @METODO     = METODO,
               @USUARIO    = USUARIO,
               @PARAMETROS = PARAMETROS
        FROM   OPENJSON(@JSON)
        WITH (
            MODELO     VARCHAR(100)  '$.MODELO',
            METODO     VARCHAR(100)  '$.METODO',
            USUARIO    VARCHAR(20)   '$.USUARIO',
            PARAMETROS NVARCHAR(MAX) AS JSON
        );

        SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))));

        -- M�todo: Generaci�n de CxP Liquidaci�n Impuestos
        IF @METODO = 'GEN_CXP_LIQIMP'
        BEGIN
            SELECT @ANO           = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ANO') AS SMALLINT),
                   @MES           = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MES') AS SMALLINT),
                   @CUENTAINI     = JSON_VALUE(@PARAMETROS, '$.CUENTAINI'),
                   @CUENTAFINAL   = JSON_VALUE(@PARAMETROS, '$.CUENTAFINAL'),
                   @IDTERCERO     = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO'))), ''),
                   @F_CERTIFICADO = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.F_CERTIFICADO') AS DATE),
                   @COMPANIA      = COALESCE(NULLIF(JSON_VALUE(@PARAMETROS, '$.COMPANIA'), ''), '01'),
                   @SEDE          = JSON_VALUE(@PARAMETROS, '$.IDSEDE'),
                   @USUARIO       = COALESCE(NULLIF(JSON_VALUE(@PARAMETROS, '$.USUARIO'), ''), @USUARIO);

            -- Obtener nombre del equipo del usuario
            SELECT @SYS_COMPUTERNAME = COALESCE(
                       NULLIF(JSON_VALUE(@PARAMETROS, '$.SYS_COMPUTERNAME'), ''),
                       NULLIF(JSON_VALUE(@PARAMETROS, '$.SYS_ComputerName'), ''),
                       SYS_COMPUTERNAME
                   )
            FROM   USUSU
            WHERE  USUARIO = @USUARIO;

            -- Determinar la sede
            IF COALESCE(@SEDE, '') = ''
                SELECT @SEDE = IDSEDE FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME;

            IF COALESCE(@SEDE, '') = ''
                SET @SEDE = '01';

            -- Validar par�metros obligatorios
            IF @ANO IS NULL OR @MES IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'A�o y mes del periodo son obligatorios.' AS ERROR;
                RETURN;
            END

            SET @CNSFCXP = NULL;

            -- Ejecutar procedimiento de negocio
            EXEC dbo.SPK_GEN_CXP_LIQIMP
                @ANO              = @ANO,
                @MES              = @MES,
                @CUENTAINI        = @CUENTAINI,
                @CUENTAFINAL      = @CUENTAFINAL,
                @IDTERCERO        = @IDTERCERO,
                @F_CERTIFICADO    = @F_CERTIFICADO,
                @USUARIO          = @USUARIO,
                @COMPANIA         = @COMPANIA,
                @SEDE             = @SEDE,
                @SYS_COMPUTERNAME = @SYS_COMPUTERNAME,
                @CNSFCXP          = @CNSFCXP OUTPUT;

            SELECT 'OK' AS OK, @CNSFCXP AS CNSFCXP, @ANO AS ANO, @MES AS MES;
            RETURN;
        END

        -- Respuesta si el m�todo no coincide
        SELECT 'KO' AS OK, 'M�todo no implementado: ' + ISNULL(@METODO, '') AS ERROR;

    END TRY
    BEGIN CATCH
        SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
    END CATCH
END;
