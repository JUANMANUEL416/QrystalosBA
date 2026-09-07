CREATE OR ALTER PROCEDURE DBO.SPQ_CONCILIACIONES
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
            @IDFCONCI       VARCHAR(20);

    -----------------------------------------------------
    -- Parseo del JSON
    -----------------------------------------------------
    BEGIN TRY
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'KO' AS OK, 'JSON inválido' AS ERROR;
            RETURN;
        END

        SELECT 
            @MODELO     = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO     = LTRIM(RTRIM(JSON_VALUE(@JSON, '$.METODO'))),
            @USUARIO    = JSON_VALUE(@JSON, '$.USUARIO'),
            @PARAMETROS = JSON_QUERY(@JSON, '$.PARAMETROS');

        IF @MODELO IS NULL OR @METODO IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Datos incompletos en la petición' AS ERROR;
            RETURN;
        END
        
        SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))));
    END TRY
    BEGIN CATCH
        SELECT 'KO' AS OK, 'Error al parsear JSON: ' + ERROR_MESSAGE() AS ERROR;
        RETURN;
    END CATCH

    -----------------------------------------------------
    -- Obtener compañía del usuario
    -----------------------------------------------------
    SELECT @COMPANIA = COMPANIA FROM USUSU WHERE USUARIO = @USUARIO;
    
    IF @COMPANIA IS NULL
    BEGIN
        SELECT 'KO' AS OK, 'Usuario no encontrado o sin compañía asignada' AS ERROR;
        RETURN;
    END

    -----------------------------------------------------
    -- Parseo de parámetros del método
    -----------------------------------------------------
    BEGIN TRY
        SELECT 
            @ANOCONTABLE = JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE'),
            @MESCONTABLE = JSON_VALUE(@PARAMETROS, '$.MESCONTABLE'),
            @ESTADO      = ISNULL(JSON_VALUE(@PARAMETROS, '$.ESTADO'), 'TODAS'),
            @IDFCONCI    = JSON_VALUE(@PARAMETROS, '$.IDFCONCI');
    END TRY
    BEGIN CATCH
    END CATCH

    -----------------------------------------------------
    -- MÉTODO LISTA
    -----------------------------------------------------
    IF @METODO = 'LISTA'
    BEGIN
        IF @ANOCONTABLE IS NULL OR @MESCONTABLE IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Año y mes contable son requeridos' AS ERROR;
            RETURN;
        END

        DECLARE @ESTADO_LIMPIO VARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@ESTADO, 'TODAS'))));

        BEGIN TRY
            SELECT
                'OK' AS OK,
                FCONCI.IDFCONCI AS IDFCONCI,
                FCONCI.IDTERCERO AS IDTERCERO,
                ISNULL(TER.RAZONSOCIAL, '') AS RAZONSOCIAL,
                ISNULL(TER.NIT, '') AS NIT,
                FCONCI.FECHACONC AS FECHACONC,
                ISNULL(FCONCI.CNSEXTERNO, '') AS CNSSEXTERNO,
                ISNULL(FCONCI.USUARIO, '') AS USUARIO,
                FCONCI.FECHA_PAGCONC AS FECHA_PAGOCONC,
                ISNULL(FCONCI.ESTADO, '') AS ESTADO,
                ISNULL(FCONCI.CONTABILIZADA, 0) AS CONTABILIZADA,
                ISNULL(FCONCI.NROCOMPROBANTE, '') AS NROCOMPROBANTE,
                CASE 
                    WHEN ISNULL(FCONCI.CONTABILIZADA, 0) = 1 
                         AND ISNULL(FCONCI.NROCOMPROBANTE, '') <> ''
                        THEN 'ENVIADA'
                    ELSE 'NO_ENVIADA'
                END AS ESTADO_REAL
            FROM FCONCI
            LEFT JOIN TER ON FCONCI.IDTERCERO = TER.IDTERCERO
            WHERE YEAR(FCONCI.FECHACONC) = CAST(@ANOCONTABLE AS INT)
                AND MONTH(FCONCI.FECHACONC) = CAST(@MESCONTABLE AS INT)
                AND (
                    @ESTADO_LIMPIO = 'TODAS'
                    OR (@ESTADO_LIMPIO = 'ENVIADAS' AND ISNULL(FCONCI.CONTABILIZADA, 0) = 1 AND ISNULL(FCONCI.NROCOMPROBANTE, '') <> '')
                    OR (@ESTADO_LIMPIO = 'NO_ENVIADAS' AND (ISNULL(FCONCI.CONTABILIZADA, 0) = 0 OR ISNULL(FCONCI.NROCOMPROBANTE, '') = ''))
                )
            ORDER BY FCONCI.FECHACONC DESC, FCONCI.IDFCONCI DESC;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, 'Error al consultar conciliaciones: ' + ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    -----------------------------------------------------
    -- MÉTODO DETALLE
    -----------------------------------------------------
    IF @METODO = 'DETALLE'
    BEGIN
        IF @IDFCONCI IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Consecutivo de conciliación es requerido' AS ERROR;
            RETURN;
        END

        BEGIN TRY
            IF NOT EXISTS (SELECT 1 FROM FCONCI WHERE IDFCONCI = @IDFCONCI)
            BEGIN
                SELECT 'KO' AS OK, 'Conciliación no encontrada' AS ERROR;
                RETURN;
            END

            SELECT
                'OK' AS OK,
                ISNULL(FCONCID.ITEM_FCONCID, 0) AS ITEM_FCONCID,
                ISNULL(FCONCID.CNSCXC, '') AS CNSCXC,
                ISNULL(FCONCID.N_FACTURA, '') AS N_FACTURA,
                ISNULL(FCONCID.TIPO, '') AS TIPO,
                ISNULL(FCONCID.CNSGLO, '') AS CNSGLO,
                ISNULL(FCONCID.SALDONETO, 0) AS SALDONETO,
                ISNULL(FCONCID.VLRACEPTADO, 0) AS VLRACEPTADO,
                ISNULL(FCONCID.VLRRECUPERAR, 0) AS VLRRECUPERAR,
                ISNULL(FCONCID.CNSFNOT, '') AS CNSFNOT,
                ISNULL(FCONCID.CLASE, '') AS CLASE,
                ISNULL(FCONCID.ESTADO, '') AS ESTADO,
                ISNULL(FCONCID.OBSERVACION, '') AS OBSERVACION
            FROM FCONCID
            WHERE FCONCID.IDFCONCI = @IDFCONCI
            ORDER BY FCONCID.ITEM_FCONCID;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, 'Error al consultar detalle: ' + ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    -----------------------------------------------------
-- MÉTODO CONTAB_MASIVA - SIMPLIFICADO PARA DEPURAR
-----------------------------------------------------
IF @METODO = 'CONTAB_MASIVA'
BEGIN
    DECLARE @CONCI_SYS VARCHAR(254), @CONCI_SEDE VARCHAR(5),
            @CONCILIACIONES NVARCHAR(MAX), @CONCI_PROCESADAS INT = 0,
            @NROCOMP_GENERADO VARCHAR(20);

    BEGIN TRY
        SELECT 
            @ANOCONTABLE = JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE'),
            @MESCONTABLE = JSON_VALUE(@PARAMETROS, '$.MESCONTABLE'),
            @CONCILIACIONES = JSON_QUERY(@PARAMETROS, '$.CONCILIACIONES');

        IF @ANOCONTABLE IS NULL OR @MESCONTABLE IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Año y mes contable son requeridos' AS ERROR;
            RETURN;
        END

        SELECT @CONCI_SYS = ISNULL(SYS_COMPUTERNAME, 'CAJAPPAL')
        FROM USUSU WHERE USUARIO = @USUARIO;
        IF @CONCI_SYS IS NULL OR @CONCI_SYS = '' SET @CONCI_SYS = 'CAJAPPAL';

        SELECT @CONCI_SEDE = IDSEDE FROM UBEQ WHERE SYS_ComputerName = @CONCI_SYS;
        IF @CONCI_SEDE IS NULL OR @CONCI_SEDE = '' SET @CONCI_SEDE = '06';

        SET @NROCOMP_GENERADO = CONCAT(@ANOCONTABLE, @MESCONTABLE, '-CONCI');

        -- ? ACTUALIZAR DIRECTAMENTE SIN CURSOR
        IF @CONCILIACIONES IS NOT NULL AND @CONCILIACIONES != '[]' AND LEN(LTRIM(RTRIM(@CONCILIACIONES))) > 2
        BEGIN
            -- Actualizar todas las conciliaciones del array de una vez
            UPDATE FCONCI
            SET 
                CONTABILIZADA = 1,
                NROCOMPROBANTE = @NROCOMP_GENERADO
            FROM FCONCI
            INNER JOIN OPENJSON(@CONCILIACIONES) AS J ON FCONCI.IDFCONCI = J.value;

            SET @CONCI_PROCESADAS = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            SELECT 'KO' AS OK, 'No se enviaron conciliaciones para procesar' AS ERROR;
            RETURN;
        END

        SELECT 
            'OK' AS OK,
            CONCAT(@CONCI_PROCESADAS, ' conciliación(es) enviada(s) a contabilidad correctamente') AS MENSAJE,
            @ANOCONTABLE AS ANO,
            @MESCONTABLE AS MES,
            @COMPANIA AS COMPANIA,
            @CONCI_PROCESADAS AS PROCESADOS,
            'CONCILIACIONES' AS TIPO_OPERACION,
            @NROCOMP_GENERADO AS NROCOMPROBANTE;
        RETURN;
    END TRY
    BEGIN CATCH
        SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR,
            ERROR_LINE() AS LINEA_ERROR, ERROR_PROCEDURE() AS PROCEDIMIENTO;
        RETURN;
    END CATCH
END

    -- Método no reconocido
    SELECT 'KO' AS OK, 'Método no implementado: ' + ISNULL(@METODO, 'NULL') AS ERROR;
END

