CREATE OR ALTER PROCEDURE DBO.SPQ_FAR_IF
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
DECLARE @PARAMETROS NVARCHAR(MAX)
DECLARE @MODELO     VARCHAR(100)
DECLARE @METODO     VARCHAR(100)
DECLARE @USUARIO    VARCHAR(20)
DECLARE @COMPANIA   VARCHAR(2) = '01'
DECLARE @SEDE       VARCHAR(5)
DECLARE @CNSIF      VARCHAR(20)
DECLARE @CNSIFH     VARCHAR(20)
DECLARE @IDIFCAT    VARCHAR(20)
DECLARE @NOADMISION VARCHAR(16)
DECLARE @IDAFILIADO VARCHAR(20)
DECLARE @IDSERVICIO VARCHAR(20)
DECLARE @CODOM      VARCHAR(10)
DECLARE @CONSECUTIVO VARCHAR(13)
DECLARE @ITEMRED    INT
DECLARE @IF_TEXTO   VARCHAR(500)
DECLARE @OBS_QCO    VARCHAR(MAX)
DECLARE @ACEPTADA   CHAR(1)
DECLARE @OBS_ACEPTA VARCHAR(MAX)
DECLARE @OBS_VERIF  VARCHAR(MAX)
DECLARE @NOMBRE_ACEPTA VARCHAR(200)
DECLARE @ESTADO_ANT VARCHAR(30)
DECLARE @ESTADO_NUEVO VARCHAR(30)
DECLARE @ACCION     VARCHAR(20)
DECLARE @PERFIL     VARCHAR(20)
DECLARE @IDSEDE     VARCHAR(5)
DECLARE @ESTADO     VARCHAR(30)
DECLARE @FECHA_DESDE DATE
DECLARE @FECHA_HASTA DATE
DECLARE @DESCRIPCION VARCHAR(200)
DECLARE @CONV_GRANADA VARCHAR(200)
DECLARE @EXPLICACION NVARCHAR(MAX)
DECLARE @ORDEN      INT
DECLARE @ACTIVO     BIT
DECLARE @ES_OTRO    BIT
DECLARE @ITEMS      NVARCHAR(MAX)
DECLARE @CNT        INT
DECLARE @HELPER_SUB VARCHAR(40)
BEGIN
    SET NOCOUNT ON;

    SELECT
        @MODELO = MODELO,
        @METODO = METODO,
        @USUARIO = USUARIO,
        @PARAMETROS = PARAMETROS
    FROM OPENJSON(@JSON)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        USUARIO VARCHAR(20) '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    SELECT TOP (1)
        @SEDE = COALESCE(NULLIF(LTRIM(RTRIM(IDSEDE)), ''), '01'),
        @COMPANIA = COALESCE(NULLIF(LTRIM(RTRIM(COMPANIA)), ''), '01')
    FROM DBO.USUSU WITH (NOLOCK)
    WHERE USUARIO = @USUARIO;

    IF @SEDE IS NULL SET @SEDE = '01';

    /* =====================================================================
       HELPER: cat�logo activo / CONV_GRANADA (TGEN)
       PARAMETROS.METODO opcional: 'CONV_GRANADA'
       ===================================================================== */
    IF @METODO = 'HELPER'
    BEGIN
        SELECT @HELPER_SUB = UPPER(NULLIF(LTRIM(RTRIM(METODO)), ''))
        FROM OPENJSON(COALESCE(@PARAMETROS, '{}'))
        WITH (METODO VARCHAR(40) '$.METODO');

        IF @HELPER_SUB = 'CONV_GRANADA'
        BEGIN
            SELECT 'OK' OK;
            SELECT
                T.CODIGO value,
                T.DESCRIPCION label,
                T.DESCRIPCION
            FROM DBO.TGEN T WITH (NOLOCK)
            WHERE T.TABLA COLLATE DATABASE_DEFAULT = 'FAR_IF'
              AND T.CAMPO COLLATE DATABASE_DEFAULT = 'CONV_GRANADA'
            ORDER BY T.DESCRIPCION;
            RETURN;
        END;

        SELECT 'OK' OK;
        SELECT
            C.IDIFCAT value,
            C.DESCRIPCION label,
            C.CONV_GRANADA,
            C.PERFIL,
            C.EXPLICACION,
            C.ES_OTRO,
            C.ORDEN
        FROM DBO.FAR_IFCAT C WITH (NOLOCK)
        WHERE C.ACTIVO = 1
        ORDER BY C.ORDEN, C.DESCRIPCION;
        RETURN;
    END;

    /* =====================================================================
       CAT_LISTAR
       ===================================================================== */
    IF @METODO = 'CAT_LISTAR'
    BEGIN
        SELECT 'OK' OK;
        SELECT
            C.IDIFCAT,
            C.DESCRIPCION,
            C.CONV_GRANADA,
            C.PERFIL,
            C.EXPLICACION,
            C.ES_OTRO,
            C.ACTIVO,
            C.ORDEN,
            C.USUARIOREG,
            C.FECHAREG
        FROM DBO.FAR_IFCAT C WITH (NOLOCK)
        ORDER BY C.ORDEN, C.DESCRIPCION;
        RETURN;
    END;

    /* =====================================================================
       CAT_UPSERT
       ===================================================================== */
    IF @METODO = 'CAT_UPSERT'
    BEGIN
        SELECT
            @IDIFCAT = NULLIF(LTRIM(RTRIM(IDIFCAT)), ''),
            @DESCRIPCION = NULLIF(LTRIM(RTRIM(DESCRIPCION)), ''),
            @CONV_GRANADA = NULLIF(LTRIM(RTRIM(CONV_GRANADA)), ''),
            @PERFIL = UPPER(NULLIF(LTRIM(RTRIM(PERFIL)), '')),
            @EXPLICACION = EXPLICACION,
            @ORDEN = COALESCE(ORDEN, 100),
            @ACTIVO = COALESCE(ACTIVO, 1),
            @ES_OTRO = COALESCE(ES_OTRO, 0)
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDIFCAT VARCHAR(20) '$.IDIFCAT',
            DESCRIPCION VARCHAR(200) '$.DESCRIPCION',
            CONV_GRANADA VARCHAR(200) '$.CONV_GRANADA',
            PERFIL VARCHAR(20) '$.PERFIL',
            EXPLICACION NVARCHAR(MAX) '$.EXPLICACION',
            ORDEN INT '$.ORDEN',
            ACTIVO BIT '$.ACTIVO',
            ES_OTRO BIT '$.ES_OTRO'
        );

        IF @DESCRIPCION IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'La descripci�n es obligatoria.' ERROR;
            RETURN;
        END;

        IF @PERFIL IS NULL OR @PERFIL NOT IN ('MEDICO', 'ENFERMERIA', 'AMBOS')
            SET @PERFIL = 'MEDICO';

        IF @IDIFCAT IS NULL
        BEGIN
            SET @IDIFCAT = NULL;
            BEGIN TRY
                EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIFCAT', @IDIFCAT OUTPUT;
                SELECT @IDIFCAT = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@IDIFCAT)) + LTRIM(RTRIM(@IDIFCAT)), SPACE(1), '0');
            END TRY
            BEGIN CATCH
                SET @IDIFCAT = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
            END CATCH;

            INSERT INTO DBO.FAR_IFCAT (
                IDIFCAT, DESCRIPCION, CONV_GRANADA, PERFIL, EXPLICACION,
                ES_OTRO, ACTIVO, ORDEN, USUARIOREG, FECHAREG
            )
            VALUES (
                @IDIFCAT, @DESCRIPCION, @CONV_GRANADA, @PERFIL, @EXPLICACION,
                @ES_OTRO, @ACTIVO, @ORDEN, @USUARIO, GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE DBO.FAR_IFCAT
            SET DESCRIPCION = @DESCRIPCION,
                CONV_GRANADA = @CONV_GRANADA,
                PERFIL = @PERFIL,
                EXPLICACION = @EXPLICACION,
                ES_OTRO = @ES_OTRO,
                ACTIVO = @ACTIVO,
                ORDEN = @ORDEN
            WHERE IDIFCAT = @IDIFCAT;

            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 'KO' OK;
                SELECT '�tem de cat�logo no encontrado.' ERROR;
                RETURN;
            END;
        END;

        SELECT 'OK' OK;
        SELECT @IDIFCAT IDIFCAT;
        RETURN;
    END;

    /* =====================================================================
       CAT_TOGGLE
       ===================================================================== */
    IF @METODO = 'CAT_TOGGLE'
    BEGIN
        SELECT @IDIFCAT = NULLIF(LTRIM(RTRIM(IDIFCAT)), '')
        FROM OPENJSON(@PARAMETROS)
        WITH (IDIFCAT VARCHAR(20) '$.IDIFCAT');

        IF @IDIFCAT IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'IDIFCAT requerido.' ERROR;
            RETURN;
        END;

        UPDATE DBO.FAR_IFCAT
        SET ACTIVO = CASE WHEN ACTIVO = 1 THEN 0 ELSE 1 END
        WHERE IDIFCAT = @IDIFCAT;

        SELECT 'OK' OK;
        SELECT IDIFCAT, ACTIVO FROM DBO.FAR_IFCAT WITH (NOLOCK) WHERE IDIFCAT = @IDIFCAT;
        RETURN;
    END;

    /* =====================================================================
       CREAR (uno o varios �tems de cat�logo)
       ===================================================================== */
    IF @METODO = 'CREAR'
    BEGIN
        SELECT
            @NOADMISION = NULLIF(LTRIM(RTRIM(NOADMISION)), ''),
            @IDAFILIADO = NULLIF(LTRIM(RTRIM(IDAFILIADO)), ''),
            @IDSERVICIO = NULLIF(LTRIM(RTRIM(IDSERVICIO)), ''),
            @CODOM = NULLIF(LTRIM(RTRIM(CODOM)), ''),
            @CONSECUTIVO = NULLIF(LTRIM(RTRIM(CONSECUTIVO)), ''),
            @ITEMRED = ITEMRED,
            @OBS_QCO = OBSERVACION_QCO,
            @IF_TEXTO = NULLIF(LTRIM(RTRIM(IF_TEXTO)), ''),
            @ITEMS = JSON_QUERY(@PARAMETROS, '$.ITEMS')
        FROM OPENJSON(@PARAMETROS)
        WITH (
            NOADMISION VARCHAR(16) '$.NOADMISION',
            IDAFILIADO VARCHAR(20) '$.IDAFILIADO',
            IDSERVICIO VARCHAR(20) '$.IDSERVICIO',
            CODOM VARCHAR(10) '$.CODOM',
            CONSECUTIVO VARCHAR(13) '$.CONSECUTIVO',
            ITEMRED INT '$.ITEMRED',
            OBSERVACION_QCO NVARCHAR(MAX) '$.OBSERVACION_QCO',
            IF_TEXTO VARCHAR(500) '$.IF_TEXTO'
        );

        IF @ITEMS IS NULL AND JSON_VALUE(@PARAMETROS, '$.IDIFCAT') IS NOT NULL
            SET @ITEMS = CONCAT('["', JSON_VALUE(@PARAMETROS, '$.IDIFCAT'), '"]');

        IF @NOADMISION IS NULL OR @IDSERVICIO IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'NOADMISION e IDSERVICIO son obligatorios.' ERROR;
            RETURN;
        END;

        IF @IDAFILIADO IS NULL
            SELECT @IDAFILIADO = IDAFILIADO
            FROM DBO.HADM WITH (NOLOCK)
            WHERE NOADMISION COLLATE DATABASE_DEFAULT = @NOADMISION COLLATE DATABASE_DEFAULT;

        IF OBJECT_ID('tempdb..#IF_ITEMS') IS NOT NULL DROP TABLE #IF_ITEMS;
        CREATE TABLE #IF_ITEMS (
            IDIFCAT VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL
        );

        INSERT INTO #IF_ITEMS (IDIFCAT)
        SELECT DISTINCT UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(20), value)))) COLLATE DATABASE_DEFAULT
        FROM OPENJSON(CASE WHEN ISJSON(COALESCE(@ITEMS, '')) = 1 THEN @ITEMS ELSE '[]' END)
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), value))), '') IS NOT NULL;

        IF NOT EXISTS (SELECT 1 FROM #IF_ITEMS)
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Debe seleccionar al menos una intervenci�n.' ERROR;
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM #IF_ITEMS I
            INNER JOIN DBO.FAR_IFCAT C WITH (NOLOCK)
                ON C.IDIFCAT COLLATE DATABASE_DEFAULT = I.IDIFCAT COLLATE DATABASE_DEFAULT
            WHERE C.ES_OTRO = 1 AND @IF_TEXTO IS NULL
        )
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Para la opci�n Otro debe indicar el texto de la intervenci�n.' ERROR;
            RETURN;
        END;

        /* No PRM sobre medicamento suspendido (evento vigente o HHOM) */
        IF EXISTS (
            SELECT 1
            FROM DBO.FAR_OM_EVENTO E WITH (NOLOCK)
            WHERE E.NOADMISION COLLATE DATABASE_DEFAULT = @NOADMISION COLLATE DATABASE_DEFAULT
              AND E.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT
              AND COALESCE(E.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(@CODOM, '') COLLATE DATABASE_DEFAULT
              AND E.VIGENTE = 1
              AND UPPER(LTRIM(RTRIM(COALESCE(E.CLASE, '')))) = 'S'
        )
        OR EXISTS (
            SELECT 1
            FROM DBO.HHOM H WITH (NOLOCK)
            WHERE H.NOADMISION COLLATE DATABASE_DEFAULT = @NOADMISION COLLATE DATABASE_DEFAULT
              AND H.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT
              AND COALESCE(H.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(@CODOM, '') COLLATE DATABASE_DEFAULT
              AND UPPER(LTRIM(RTRIM(COALESCE(H.ESTADO, '')))) = 'S'
        )
        BEGIN
            SELECT 'KO' OK;
            SELECT 'No se puede registrar PRM sobre un medicamento suspendido.' ERROR;
            RETURN;
        END;

        /* Solo un PRM abierto por l�nea OM (pendiente valoraci�n o verificaci�n) */
        IF EXISTS (
            SELECT 1
            FROM DBO.FAR_IF F WITH (NOLOCK)
            WHERE F.NOADMISION COLLATE DATABASE_DEFAULT = @NOADMISION COLLATE DATABASE_DEFAULT
              AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT
              AND COALESCE(F.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(@CODOM, '') COLLATE DATABASE_DEFAULT
              AND F.ESTADO_REG = 'A'
              AND F.ESTADO IN ('PendienteValoracion', 'PendienteVerificacion')
              AND (
                    @CONSECUTIVO IS NULL
                    OR F.CONSECUTIVO IS NULL
                    OR F.CONSECUTIVO COLLATE DATABASE_DEFAULT = @CONSECUTIVO COLLATE DATABASE_DEFAULT
                  )
        )
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Ya existe un PRM pendiente de valoraci�n o de verificaci�n del qu�mico para este medicamento.' ERROR;
            RETURN;
        END;

        DECLARE @CUR_IDIFCAT VARCHAR(20);
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT IDIFCAT FROM #IF_ITEMS;
        OPEN cur;
        FETCH NEXT FROM cur INTO @CUR_IDIFCAT;
        SET @CNT = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @CNSIF = NULL;
            BEGIN TRY
                EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIF', @CNSIF OUTPUT;
                SELECT @CNSIF = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@CNSIF)) + LTRIM(RTRIM(@CNSIF)), SPACE(1), '0');
            END TRY
            BEGIN CATCH
                SET @CNSIF = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
            END CATCH;

            INSERT INTO DBO.FAR_IF (
                CNSIF, NOADMISION, IDAFILIADO, IDSERVICIO, CODOM, CONSECUTIVO, ITEMRED,
                IDIFCAT, IF_TEXTO, OBSERVACION_QCO, ESTADO, IDUSUARIO_IF, FECHA_IF,
                ESTADO_REG, FECHAREG
            )
            VALUES (
                @CNSIF, @NOADMISION, @IDAFILIADO, @IDSERVICIO, @CODOM, @CONSECUTIVO, @ITEMRED,
                @CUR_IDIFCAT,
                CASE WHEN EXISTS (
                         SELECT 1 FROM DBO.FAR_IFCAT
                         WHERE IDIFCAT COLLATE DATABASE_DEFAULT = @CUR_IDIFCAT COLLATE DATABASE_DEFAULT
                           AND ES_OTRO = 1)
                     THEN @IF_TEXTO ELSE NULL END,
                @OBS_QCO, 'PendienteValoracion', @USUARIO, GETDATE(),
                'A', GETDATE()
            );

            SET @CNSIFH = NULL;
            BEGIN TRY
                EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIFH', @CNSIFH OUTPUT;
                SELECT @CNSIFH = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@CNSIFH)) + LTRIM(RTRIM(@CNSIFH)), SPACE(1), '0');
            END TRY
            BEGIN CATCH
                SET @CNSIFH = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
            END CATCH;

            INSERT INTO DBO.FAR_IFH (CNSIFH, CNSIF, ACCION, ESTADO_ANT, ESTADO_NUEVO, DETALLE, USUARIO, FECHA)
            VALUES (@CNSIFH, @CNSIF, 'CREAR', NULL, 'PendienteValoracion', @OBS_QCO, @USUARIO, GETDATE());

            SET @CNT = @CNT + 1;
            FETCH NEXT FROM cur INTO @CUR_IDIFCAT;
        END;
        CLOSE cur;
        DEALLOCATE cur;

        IF @CONSECUTIVO IS NOT NULL AND @IDSERVICIO IS NOT NULL
        BEGIN
            UPDATE H
            SET IF_PENDIENTES = (
                SELECT COUNT(*)
                FROM DBO.FAR_IF F WITH (NOLOCK)
                WHERE F.CONSECUTIVO COLLATE DATABASE_DEFAULT = H.CONSECUTIVO COLLATE DATABASE_DEFAULT
                  AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = H.IDSERVICIO COLLATE DATABASE_DEFAULT
                  AND COALESCE(F.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(H.CODOM, '') COLLATE DATABASE_DEFAULT
                  AND (H.ITEMRED IS NULL OR F.ITEMRED = H.ITEMRED OR F.ITEMRED IS NULL)
                  AND F.ESTADO_REG = 'A'
                  AND F.ESTADO <> 'Cerrado'
            )
            FROM DBO.HCATD H
            WHERE H.CONSECUTIVO COLLATE DATABASE_DEFAULT = @CONSECUTIVO COLLATE DATABASE_DEFAULT
              AND H.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT
              AND (@CODOM IS NULL OR COALESCE(H.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(@CODOM, '') COLLATE DATABASE_DEFAULT)
              AND (@ITEMRED IS NULL OR H.ITEMRED = @ITEMRED);
        END;

        SELECT 'OK' OK;
        SELECT @CNT CREADOS, @NOADMISION NOADMISION, @IDSERVICIO IDSERVICIO;
        RETURN;
    END;

    /* =====================================================================
       RESPONDER (m�dico / enfermer�a)
       ===================================================================== */
    IF @METODO = 'RESPONDER'
    BEGIN
        SELECT
            @CNSIF = NULLIF(LTRIM(RTRIM(CNSIF)), ''),
            @ACEPTADA = UPPER(NULLIF(LTRIM(RTRIM(ACEPTADA)), '')),
            @OBS_ACEPTA = OBS_ACEPTA,
            @NOMBRE_ACEPTA = NULLIF(LTRIM(RTRIM(NOMBRE_ACEPTA)), '')
        FROM OPENJSON(@PARAMETROS)
        WITH (
            CNSIF VARCHAR(20) '$.CNSIF',
            ACEPTADA CHAR(1) '$.ACEPTADA',
            OBS_ACEPTA NVARCHAR(MAX) '$.OBS_ACEPTA',
            NOMBRE_ACEPTA VARCHAR(200) '$.NOMBRE_ACEPTA'
        );

        IF @CNSIF IS NULL OR @ACEPTADA NOT IN ('S', 'N')
        BEGIN
            SELECT 'KO' OK;
            SELECT 'CNSIF y ACEPTADA (S/N) son obligatorios.' ERROR;
            RETURN;
        END;

        IF @ACEPTADA = 'N' AND NULLIF(LTRIM(RTRIM(@OBS_ACEPTA)), '') IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Debe indicar justificaci�n al no aceptar la intervenci�n.' ERROR;
            RETURN;
        END;

        IF @NOMBRE_ACEPTA IS NULL
            SELECT @NOMBRE_ACEPTA = COALESCE(
                NULLIF(LTRIM(RTRIM(COALESCE(NOMBRES, '') + ' ' + COALESCE(APELLIDOS, ''))), ''),
                NULLIF(LTRIM(RTRIM(NOMBRE)), ''),
                @USUARIO
            )
            FROM DBO.USUSU WITH (NOLOCK) WHERE USUARIO = @USUARIO;

        SELECT @ESTADO_ANT = ESTADO
        FROM DBO.FAR_IF WITH (NOLOCK)
        WHERE CNSIF = @CNSIF AND ESTADO_REG = 'A';

        IF @ESTADO_ANT IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Intervenci�n no encontrada.' ERROR;
            RETURN;
        END;

        IF @ESTADO_ANT <> 'PendienteValoracion'
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Solo se puede responder intervenciones en PendienteValoracion.' ERROR;
            RETURN;
        END;

        SET @ESTADO_NUEVO = 'PendienteVerificacion';
        SET @ACCION = CASE WHEN @ACEPTADA = 'S' THEN 'ACEPTAR' ELSE 'RECHAZAR' END;

        UPDATE DBO.FAR_IF
        SET ACEPTADA = @ACEPTADA,
            IDUSUARIO_ACEPTA = @USUARIO,
            NOMBRE_ACEPTA = @NOMBRE_ACEPTA,
            FECHA_ACEPTA = GETDATE(),
            OBS_ACEPTA = @OBS_ACEPTA,
            ESTADO = @ESTADO_NUEVO
        WHERE CNSIF = @CNSIF;

        SET @CNSIFH = NULL;
        BEGIN TRY
            EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIFH', @CNSIFH OUTPUT;
            SELECT @CNSIFH = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@CNSIFH)) + LTRIM(RTRIM(@CNSIFH)), SPACE(1), '0');
        END TRY
        BEGIN CATCH
            SET @CNSIFH = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
        END CATCH;

        INSERT INTO DBO.FAR_IFH (CNSIFH, CNSIF, ACCION, ESTADO_ANT, ESTADO_NUEVO, DETALLE, USUARIO, FECHA)
        VALUES (@CNSIFH, @CNSIF, @ACCION, @ESTADO_ANT, @ESTADO_NUEVO, @OBS_ACEPTA, @USUARIO, GETDATE());

        SELECT 'OK' OK;
        SELECT @CNSIF CNSIF, @ESTADO_NUEVO ESTADO;
        RETURN;
    END;

    /* =====================================================================
       CERRAR / VERIFICAR (qu�mico)
       ===================================================================== */
    IF @METODO IN ('CERRAR', 'VERIFICAR')
    BEGIN
        SELECT
            @CNSIF = NULLIF(LTRIM(RTRIM(CNSIF)), ''),
            @OBS_VERIF = OBS_VERIF
        FROM OPENJSON(@PARAMETROS)
        WITH (
            CNSIF VARCHAR(20) '$.CNSIF',
            OBS_VERIF NVARCHAR(MAX) '$.OBS_VERIF'
        );

        SELECT @ESTADO_ANT = ESTADO, @CONSECUTIVO = CONSECUTIVO, @IDSERVICIO = IDSERVICIO,
               @CODOM = CODOM, @ITEMRED = ITEMRED
        FROM DBO.FAR_IF WITH (NOLOCK)
        WHERE CNSIF = @CNSIF AND ESTADO_REG = 'A';

        IF @ESTADO_ANT IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Intervenci�n no encontrada.' ERROR;
            RETURN;
        END;

        SET @ESTADO_NUEVO = 'Cerrado';
        UPDATE DBO.FAR_IF
        SET ESTADO = @ESTADO_NUEVO,
            IDUSUARIO_VERIF = @USUARIO,
            FECHA_VERIF = GETDATE(),
            OBS_VERIF = @OBS_VERIF
        WHERE CNSIF = @CNSIF;

        SET @CNSIFH = NULL;
        BEGIN TRY
            EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIFH', @CNSIFH OUTPUT;
            SELECT @CNSIFH = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@CNSIFH)) + LTRIM(RTRIM(@CNSIFH)), SPACE(1), '0');
        END TRY
        BEGIN CATCH
            SET @CNSIFH = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
        END CATCH;

        INSERT INTO DBO.FAR_IFH (CNSIFH, CNSIF, ACCION, ESTADO_ANT, ESTADO_NUEVO, DETALLE, USUARIO, FECHA)
        VALUES (@CNSIFH, @CNSIF, 'CERRAR', @ESTADO_ANT, @ESTADO_NUEVO, @OBS_VERIF, @USUARIO, GETDATE());

        IF @CONSECUTIVO IS NOT NULL AND @IDSERVICIO IS NOT NULL
        BEGIN
            UPDATE H
            SET IF_PENDIENTES = (
                SELECT COUNT(*)
                FROM DBO.FAR_IF F WITH (NOLOCK)
                WHERE F.CONSECUTIVO COLLATE DATABASE_DEFAULT = H.CONSECUTIVO COLLATE DATABASE_DEFAULT
                  AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = H.IDSERVICIO COLLATE DATABASE_DEFAULT
                  AND COALESCE(F.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(H.CODOM, '') COLLATE DATABASE_DEFAULT
                  AND (H.ITEMRED IS NULL OR F.ITEMRED = H.ITEMRED OR F.ITEMRED IS NULL)
                  AND F.ESTADO_REG = 'A'
                  AND F.ESTADO <> 'Cerrado'
            )
            FROM DBO.HCATD H
            WHERE H.CONSECUTIVO COLLATE DATABASE_DEFAULT = @CONSECUTIVO COLLATE DATABASE_DEFAULT
              AND H.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT;
        END;

        SELECT 'OK' OK;
        SELECT @CNSIF CNSIF, @ESTADO_NUEVO ESTADO;
        RETURN;
    END;

    /* =====================================================================
       REABRIR
       ===================================================================== */
    IF @METODO = 'REABRIR'
    BEGIN
        SELECT
            @CNSIF = NULLIF(LTRIM(RTRIM(CNSIF)), ''),
            @OBS_VERIF = OBS_VERIF
        FROM OPENJSON(@PARAMETROS)
        WITH (
            CNSIF VARCHAR(20) '$.CNSIF',
            OBS_VERIF NVARCHAR(MAX) '$.OBS_VERIF'
        );

        SELECT @ESTADO_ANT = ESTADO, @CONSECUTIVO = CONSECUTIVO, @IDSERVICIO = IDSERVICIO
        FROM DBO.FAR_IF WITH (NOLOCK)
        WHERE CNSIF = @CNSIF AND ESTADO_REG = 'A';

        IF @ESTADO_ANT IS NULL OR @ESTADO_ANT NOT IN ('PendienteVerificacion', 'Cerrado')
        BEGIN
            SELECT 'KO' OK;
            SELECT 'Solo se puede reabrir desde PendienteVerificacion o Cerrado.' ERROR;
            RETURN;
        END;

        SET @ESTADO_NUEVO = 'PendienteValoracion';
        UPDATE DBO.FAR_IF
        SET ESTADO = @ESTADO_NUEVO,
            ACEPTADA = NULL,
            IDUSUARIO_ACEPTA = NULL,
            NOMBRE_ACEPTA = NULL,
            FECHA_ACEPTA = NULL,
            OBS_ACEPTA = NULL,
            IDUSUARIO_VERIF = NULL,
            FECHA_VERIF = NULL,
            OBS_VERIF = @OBS_VERIF
        WHERE CNSIF = @CNSIF;

        SET @CNSIFH = NULL;
        BEGIN TRY
            EXEC DBO.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FARIFH', @CNSIFH OUTPUT;
            SELECT @CNSIFH = LEFT(@SEDE, 2) + REPLACE(SPACE(8 - LEN(@CNSIFH)) + LTRIM(RTRIM(@CNSIFH)), SPACE(1), '0');
        END TRY
        BEGIN CATCH
            SET @CNSIFH = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 20);
        END CATCH;

        INSERT INTO DBO.FAR_IFH (CNSIFH, CNSIF, ACCION, ESTADO_ANT, ESTADO_NUEVO, DETALLE, USUARIO, FECHA)
        VALUES (@CNSIFH, @CNSIF, 'REABRIR', @ESTADO_ANT, @ESTADO_NUEVO, @OBS_VERIF, @USUARIO, GETDATE());

        IF @CONSECUTIVO IS NOT NULL AND @IDSERVICIO IS NOT NULL
        BEGIN
            UPDATE H
            SET IF_PENDIENTES = (
                SELECT COUNT(*)
                FROM DBO.FAR_IF F WITH (NOLOCK)
                WHERE F.CONSECUTIVO COLLATE DATABASE_DEFAULT = H.CONSECUTIVO COLLATE DATABASE_DEFAULT
                  AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = H.IDSERVICIO COLLATE DATABASE_DEFAULT
                  AND F.ESTADO_REG = 'A'
                  AND F.ESTADO <> 'Cerrado'
            )
            FROM DBO.HCATD H
            WHERE H.CONSECUTIVO COLLATE DATABASE_DEFAULT = @CONSECUTIVO COLLATE DATABASE_DEFAULT
              AND H.IDSERVICIO COLLATE DATABASE_DEFAULT = @IDSERVICIO COLLATE DATABASE_DEFAULT;
        END;

        SELECT 'OK' OK;
        SELECT @CNSIF CNSIF, @ESTADO_NUEVO ESTADO;
        RETURN;
    END;

    /* =====================================================================
       HISTORICO
       ===================================================================== */
    IF @METODO = 'HISTORICO'
    BEGIN
        SELECT @CNSIF = NULLIF(LTRIM(RTRIM(CNSIF)), '')
        FROM OPENJSON(@PARAMETROS)
        WITH (CNSIF VARCHAR(20) '$.CNSIF');

        SELECT 'OK' OK;
        SELECT
            H.CNSIFH, H.CNSIF, H.ACCION, H.ESTADO_ANT, H.ESTADO_NUEVO,
            H.DETALLE, H.USUARIO, H.FECHA,
            U.NOMBRE AS NOMBRE_USUARIO
        FROM DBO.FAR_IFH H WITH (NOLOCK)
        LEFT JOIN DBO.USUSU U WITH (NOLOCK)
            ON U.USUARIO COLLATE DATABASE_DEFAULT = H.USUARIO COLLATE DATABASE_DEFAULT
        WHERE H.CNSIF COLLATE DATABASE_DEFAULT = @CNSIF COLLATE DATABASE_DEFAULT
        ORDER BY H.FECHA ASC;
        RETURN;
    END;

    /* =====================================================================
       LISTAR / LISTAR_PENDIENTES / REPORTE
       ===================================================================== */
    IF @METODO IN ('LISTAR', 'LISTAR_PENDIENTES', 'REPORTE')
    BEGIN
        SELECT
            @NOADMISION = NULLIF(LTRIM(RTRIM(NOADMISION)), ''),
            @IDAFILIADO = NULLIF(LTRIM(RTRIM(IDAFILIADO)), ''),
            @IDSEDE = NULLIF(LTRIM(RTRIM(IDSEDE)), ''),
            @ESTADO = NULLIF(LTRIM(RTRIM(ESTADO)), ''),
            @PERFIL = UPPER(NULLIF(LTRIM(RTRIM(PERFIL)), '')),
            @FECHA_DESDE = TRY_CONVERT(DATE, FECHA_DESDE),
            @FECHA_HASTA = TRY_CONVERT(DATE, FECHA_HASTA)
        FROM OPENJSON(@PARAMETROS)
        WITH (
            NOADMISION VARCHAR(16) '$.NOADMISION',
            IDAFILIADO VARCHAR(20) '$.IDAFILIADO',
            IDSEDE VARCHAR(5) '$.IDSEDE',
            ESTADO VARCHAR(30) '$.ESTADO',
            PERFIL VARCHAR(20) '$.PERFIL',
            FECHA_DESDE VARCHAR(20) '$.FECHA_DESDE',
            FECHA_HASTA VARCHAR(20) '$.FECHA_HASTA'
        );

        IF @METODO = 'LISTAR_PENDIENTES'
            SET @ESTADO = COALESCE(@ESTADO, 'PendienteValoracion');

        IF COALESCE(@IDSEDE, '') IN ('TODOS', '*') SET @IDSEDE = NULL;

        SELECT 'OK' OK;

        SELECT
            F.CNSIF,
            F.NOADMISION,
            CAMA = COALESCE(HH.HABCAMA, ''),
            BLOQUE = COALESCE(HH.SECTOR, ''),
            DOCUMENTO = LTRIM(RTRIM(COALESCE(AFI.TIPO_DOC, ''))) + ' ' + LTRIM(RTRIM(COALESCE(AFI.DOCIDAFILIADO, ''))),
            PACIENTE = AFI.NOMBREAFI,
            MEDICAMENTO = F.IDSERVICIO + ' ' + COALESCE(SER.DESCSERVICIO, ''),
            F.IDSERVICIO,
            INTERVENCION = COALESCE(NULLIF(F.IF_TEXTO, ''), CAT.DESCRIPCION, ''),
            PRM = COALESCE(CAT.CONV_GRANADA, ''),
            CAT.PERFIL AS PERFIL_CAT,
            CAT.EXPLICACION,
            QUIMICO_IF = COALESCE(
                NULLIF(LTRIM(RTRIM(COALESCE(UQ.NOMBRES, '') + ' ' + COALESCE(UQ.APELLIDOS, ''))), ''),
                UQ.NOMBRE,
                F.IDUSUARIO_IF
            ),
            F.FECHA_IF,
            ACEPTADA = CASE F.ACEPTADA WHEN 'S' THEN 'Aceptada' WHEN 'N' THEN 'No aceptada' ELSE NULL END,
            F.ACEPTADA AS ACEPTADA_COD,
            F.NOMBRE_ACEPTA,
            F.FECHA_ACEPTA,
            TIEMPO_RESPUESTA = CASE
                WHEN F.FECHA_ACEPTA IS NOT NULL
                THEN CONVERT(VARCHAR(12), DATEADD(SECOND, DATEDIFF(SECOND, F.FECHA_IF, F.FECHA_ACEPTA), 0), 108)
                ELSE NULL
            END,
            QUIMICO_VERIF = COALESCE(
                NULLIF(LTRIM(RTRIM(COALESCE(UV.NOMBRES, '') + ' ' + COALESCE(UV.APELLIDOS, ''))), ''),
                UV.NOMBRE,
                F.IDUSUARIO_VERIF
            ),
            F.FECHA_VERIF,
            TIEMPO_VERIFICACION = CASE
                WHEN F.FECHA_VERIF IS NOT NULL AND F.FECHA_ACEPTA IS NOT NULL
                THEN CONVERT(VARCHAR(12), DATEADD(SECOND, DATEDIFF(SECOND, F.FECHA_ACEPTA, F.FECHA_VERIF), 0), 108)
                ELSE NULL
            END,
            TIEMPO_TOTAL = CASE
                WHEN F.FECHA_VERIF IS NOT NULL
                THEN CONVERT(VARCHAR(12), DATEADD(SECOND, DATEDIFF(SECOND, F.FECHA_IF, F.FECHA_VERIF), 0), 108)
                WHEN F.FECHA_ACEPTA IS NOT NULL
                THEN CONVERT(VARCHAR(12), DATEADD(SECOND, DATEDIFF(SECOND, F.FECHA_IF, F.FECHA_ACEPTA), 0), 108)
                ELSE NULL
            END,
            SEDE = COALESCE(SED.DESCRIPCION, HH.IDSEDE, ''),
            HH.IDSEDE,
            ESTADO_INTERVENCION = F.ESTADO,
            JUSTIFICACION_NO_ACEPTA = CASE WHEN F.ACEPTADA = 'N' THEN F.OBS_ACEPTA ELSE NULL END,
            F.OBS_ACEPTA,
            F.OBSERVACION_QCO,
            TIPO_ORDEN = 'Hospitalaria',
            MEDICO_PRESCRIBIO = COALESCE(MED.NOMBRE, HCA.IDMEDICO, ''),
            FECHA_PRESCRIBIO = HCA.FECHA,
            TIEMPO_PRESCRIPCION_IF = CASE
                WHEN HCA.FECHA IS NOT NULL
                THEN CONVERT(VARCHAR(12), DATEADD(SECOND, DATEDIFF(SECOND, HCA.FECHA, F.FECHA_IF), 0), 108)
                ELSE NULL
            END,
            JEFE_DOSIFICA = CAST(NULL AS VARCHAR(200)),
            FECHA_DOSIFICA = CAST(NULL AS DATETIME),
            ESTADO_REGISTRO = CASE F.ESTADO_REG WHEN 'A' THEN 'Registro activo' ELSE 'Inactivo' END,
            F.CONSECUTIVO,
            F.CODOM,
            F.ITEMRED,
            F.IDIFCAT,
            F.IDAFILIADO
        FROM DBO.FAR_IF F WITH (NOLOCK)
        LEFT JOIN DBO.FAR_IFCAT CAT WITH (NOLOCK)
            ON CAT.IDIFCAT COLLATE DATABASE_DEFAULT = F.IDIFCAT COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.AFI WITH (NOLOCK)
            ON AFI.IDAFILIADO COLLATE DATABASE_DEFAULT = F.IDAFILIADO COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.SER WITH (NOLOCK)
            ON SER.IDSERVICIO COLLATE DATABASE_DEFAULT = F.IDSERVICIO COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.HHAB HH WITH (NOLOCK)
            ON HH.NOADMISION COLLATE DATABASE_DEFAULT = F.NOADMISION COLLATE DATABASE_DEFAULT
           AND HH.CLASE = 'Cama'
           AND HH.ESTADOHAB = 'Ocupada'
        LEFT JOIN DBO.SED WITH (NOLOCK)
            ON SED.IDSEDE COLLATE DATABASE_DEFAULT = HH.IDSEDE COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.USUSU UQ WITH (NOLOCK)
            ON UQ.USUARIO COLLATE DATABASE_DEFAULT = F.IDUSUARIO_IF COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.USUSU UV WITH (NOLOCK)
            ON UV.USUARIO COLLATE DATABASE_DEFAULT = F.IDUSUARIO_VERIF COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.HCA WITH (NOLOCK)
            ON HCA.CONSECUTIVO COLLATE DATABASE_DEFAULT = F.CONSECUTIVO COLLATE DATABASE_DEFAULT
        LEFT JOIN DBO.MED WITH (NOLOCK)
            ON MED.IDMEDICO COLLATE DATABASE_DEFAULT = HCA.IDMEDICO COLLATE DATABASE_DEFAULT
        WHERE F.ESTADO_REG = 'A'
          AND (@NOADMISION IS NULL OR F.NOADMISION COLLATE DATABASE_DEFAULT = @NOADMISION COLLATE DATABASE_DEFAULT)
          AND (@IDAFILIADO IS NULL OR F.IDAFILIADO COLLATE DATABASE_DEFAULT = @IDAFILIADO COLLATE DATABASE_DEFAULT)
          AND (@ESTADO IS NULL OR F.ESTADO = @ESTADO)
          AND (@IDSEDE IS NULL OR HH.IDSEDE COLLATE DATABASE_DEFAULT = @IDSEDE COLLATE DATABASE_DEFAULT)
          AND (@FECHA_DESDE IS NULL OR CAST(F.FECHA_IF AS DATE) >= @FECHA_DESDE)
          AND (@FECHA_HASTA IS NULL OR CAST(F.FECHA_IF AS DATE) <= @FECHA_HASTA)
          AND (
                @PERFIL IS NULL
             OR @PERFIL = 'TODOS'
             OR CAT.PERFIL COLLATE DATABASE_DEFAULT = @PERFIL COLLATE DATABASE_DEFAULT
             OR CAT.PERFIL = 'AMBOS'
             OR (@PERFIL = 'AMBOS')
          )
        ORDER BY F.FECHA_IF DESC;

        RETURN;
    END;

    SELECT 'KO' OK;
    SELECT 'M�todo no soportado.' ERROR;
END
