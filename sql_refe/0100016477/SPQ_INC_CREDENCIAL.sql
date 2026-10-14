-- =============================================================================
-- SPQ_INC_CREDENCIAL
-- Frontend: appStore.json({ MODELO: 'INC_CREDENCIAL', METODO: '...', PARAMETROS: {...} })
--   GUARDAR           ? insert + log CREAR
--   EDITAR            ? update + log EDITAR (observaci�n con campos cambiados)
--   ELIMINAR          ? baja l�gica ACTIVO = 0 + log INACTIVAR
--   REVELAR           ? devuelve CONTRASENA o CLAVE_ESPECIAL + log
--   VER_TRAZABILIDAD  ? historial de la credencial
-- Alcance interno/externo: solo en el front (mismo payload en ambos casos).
-- =============================================================================

CREATE OR ALTER PROCEDURE DBO.SPQ_INC_CREDENCIAL
    @JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO               VARCHAR(100),
        @METODO               VARCHAR(100),
        @PARAMETROS           NVARCHAR(MAX),
        @USUARIO              VARCHAR(20),
        @IDTERCERO            VARCHAR(20),
        @NOMBRE_PORTAL        VARCHAR(200),
        @LINK                 NVARCHAR(500),
        @USUARIO_PORTAL       VARCHAR(100),
        @CONTRASENA           NVARCHAR(200),
        @CLAVE_ESPECIAL       NVARCHAR(200),
        @ESTADO               VARCHAR(2),
        @DATO_ADICIONAL       NVARCHAR(1000),
        @TIPO_DOCUMENTO       VARCHAR(50),
        @IDCREDENCIAL         INT,
        @CAMPO                VARCHAR(50),
        @ErrorMessage         NVARCHAR(MAX),
        @OBSERVACION          NVARCHAR(MAX),
        @OLD_NOMBRE_PORTAL    VARCHAR(200),
        @OLD_LINK             NVARCHAR(500),
        @OLD_USUARIO_PORTAL   VARCHAR(100),
        @OLD_CONTRASENA       NVARCHAR(200),
        @OLD_CLAVE_ESPECIAL   NVARCHAR(200),
        @OLD_ESTADO           VARCHAR(2),
        @OLD_DATO_ADICIONAL   NVARCHAR(1000),
        @OLD_TIPO_DOCUMENTO   VARCHAR(50),
        @OLD_IDTERCERO        VARCHAR(20),
        @DESC_ESTADO_ANT      NVARCHAR(200),
        @DESC_ESTADO_NUE      NVARCHAR(200),
        @DESC_EPS_ANT         NVARCHAR(200),
        @DESC_EPS_NUE         NVARCHAR(200),
        @VALOR_REVELADO        NVARCHAR(200);

    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO     VARCHAR(100)  '$.MODELO',
        METODO     VARCHAR(100)  '$.METODO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    SELECT @MODELO = MODELO, @METODO = METODO, @PARAMETROS = PARAMETROS
    FROM #JSON;

    DROP TABLE #JSON;

    IF @METODO = 'GUARDAR'
    BEGIN
        SELECT
            @USUARIO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), ''),
            @IDTERCERO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO'))), ''),
            @NOMBRE_PORTAL  = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.NOMBRE_PORTAL'))), ''),
            @LINK           = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.LINK'))), ''),
            @USUARIO_PORTAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO_PORTAL'))), ''),
            @CONTRASENA     = JSON_VALUE(@PARAMETROS, '$.CONTRASENA'),
            @CLAVE_ESPECIAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CLAVE_ESPECIAL'))), ''),
            @ESTADO         = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ESTADO'))), ''),
            @DATO_ADICIONAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.DATO_ADICIONAL'))), ''),
            @TIPO_DOCUMENTO = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.TIPO_DOCUMENTO'))), '');

        IF @ESTADO IS NULL SET @ESTADO = '01';

        -- NOMBRE_PORTAL = IDTERCERO de la EPS (compatibilidad con param IDEPS)
        IF @NOMBRE_PORTAL IS NULL
            SET @NOMBRE_PORTAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDEPS'))), '');

        IF @USUARIO IS NULL OR @IDTERCERO IS NULL OR @NOMBRE_PORTAL IS NULL OR @LINK IS NULL
            OR @USUARIO_PORTAL IS NULL OR ISNULL(@CONTRASENA, '') = '' OR @ESTADO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Empresa, EPS, link, usuario, contrase�a y estado son obligatorios.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TER WHERE IDTERCERO = @IDTERCERO)
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La empresa no existe.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TER WHERE IDTERCERO = @NOMBRE_PORTAL)
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La EPS no existe.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM dbo.TGEN
            WHERE TABLA = 'PORTALES' AND CAMPO = 'ESTADOS' AND CODIGO = @ESTADO
        )
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'El estado del acceso no es v�lido.';
            RETURN;
        END

        BEGIN TRY
            INSERT INTO dbo.INC_CREDENCIAL (
                IDTERCERO, NOMBRE_PORTAL, LINK, USUARIO_PORTAL, CONTRASENA,
                CLAVE_ESPECIAL, ESTADO, DATO_ADICIONAL, TIPO_DOCUMENTO,
                ACTIVO, USUARIO_CREACION, FECHA_CREACION
            )
            VALUES (
                @IDTERCERO, @NOMBRE_PORTAL, @LINK, @USUARIO_PORTAL, @CONTRASENA,
                @CLAVE_ESPECIAL, @ESTADO, @DATO_ADICIONAL, @TIPO_DOCUMENTO,
                1, @USUARIO, GETDATE()
            );

            SET @IDCREDENCIAL = SCOPE_IDENTITY();

            SELECT @DESC_ESTADO_NUE = DESCRIPCION
            FROM dbo.TGEN
            WHERE TABLA = 'PORTALES' AND CAMPO = 'ESTADOS' AND CODIGO = @ESTADO;

            SELECT @DESC_EPS_NUE = RAZONSOCIAL FROM dbo.TER WHERE IDTERCERO = @NOMBRE_PORTAL;

            INSERT INTO dbo.INC_CREDENCIAL_LOG (
                IDCREDENCIAL, IDTERCERO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                @IDCREDENCIAL,
                @IDTERCERO,
                'CREAR',
                CONCAT(
                    'Credencial creada - EPS: ', ISNULL(@DESC_EPS_NUE, @NOMBRE_PORTAL),
                    '; Estado: ', ISNULL(@DESC_ESTADO_NUE, @ESTADO)
                ),
                @USUARIO,
                GETDATE()
            );

            SELECT 'OK' AS OK, @IDCREDENCIAL AS IDCREDENCIAL;
            RETURN;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            SELECT 'KO' AS OK, ERROR = 'Error al guardar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    IF @METODO = 'EDITAR'
    BEGIN
        SELECT
            @IDCREDENCIAL   = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IDCREDENCIAL') AS INT),
            @USUARIO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), ''),
            @IDTERCERO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO'))), ''),
            @NOMBRE_PORTAL  = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.NOMBRE_PORTAL'))), ''),
            @LINK           = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.LINK'))), ''),
            @USUARIO_PORTAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO_PORTAL'))), ''),
            @CONTRASENA     = JSON_VALUE(@PARAMETROS, '$.CONTRASENA'),
            @CLAVE_ESPECIAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CLAVE_ESPECIAL'))), ''),
            @ESTADO         = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ESTADO'))), ''),
            @DATO_ADICIONAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.DATO_ADICIONAL'))), ''),
            @TIPO_DOCUMENTO = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.TIPO_DOCUMENTO'))), '');

        IF @NOMBRE_PORTAL IS NULL
            SET @NOMBRE_PORTAL = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDEPS'))), '');

        IF @IDCREDENCIAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'IDCREDENCIAL es obligatorio para editar.';
            RETURN;
        END

        SELECT
            @OLD_IDTERCERO      = IDTERCERO,
            @OLD_NOMBRE_PORTAL  = NOMBRE_PORTAL,
            @OLD_LINK           = LINK,
            @OLD_USUARIO_PORTAL = USUARIO_PORTAL,
            @OLD_CONTRASENA     = CONTRASENA,
            @OLD_CLAVE_ESPECIAL = CLAVE_ESPECIAL,
            @OLD_ESTADO         = ESTADO,
            @OLD_DATO_ADICIONAL = DATO_ADICIONAL,
            @OLD_TIPO_DOCUMENTO = TIPO_DOCUMENTO
        FROM dbo.INC_CREDENCIAL
        WHERE IDCREDENCIAL = @IDCREDENCIAL
            AND ACTIVO = 1;

        IF @OLD_IDTERCERO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La credencial no existe o est� inactiva.';
            RETURN;
        END

        IF ISNULL(@CONTRASENA, '') = ''
            SET @CONTRASENA = @OLD_CONTRASENA;

        IF ISNULL(@CLAVE_ESPECIAL, '') = ''
            SET @CLAVE_ESPECIAL = @OLD_CLAVE_ESPECIAL;

        IF @IDTERCERO IS NULL OR @NOMBRE_PORTAL IS NULL OR @LINK IS NULL
            OR @USUARIO_PORTAL IS NULL OR ISNULL(@CONTRASENA, '') = '' OR @ESTADO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Empresa, EPS, link, usuario, contrase�a y estado son obligatorios.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TER WHERE IDTERCERO = @IDTERCERO)
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La empresa no existe.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TER WHERE IDTERCERO = @NOMBRE_PORTAL)
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La EPS no existe.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM dbo.TGEN
            WHERE TABLA = 'PORTALES' AND CAMPO = 'ESTADOS' AND CODIGO = @ESTADO
        )
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'El estado del acceso no es v�lido.';
            RETURN;
        END

        SET @OBSERVACION = '';

        IF ISNULL(@OLD_NOMBRE_PORTAL, '') <> ISNULL(@NOMBRE_PORTAL, '')
        BEGIN
            SELECT @DESC_EPS_ANT = RAZONSOCIAL FROM dbo.TER WHERE IDTERCERO = @OLD_NOMBRE_PORTAL;
            SELECT @DESC_EPS_NUE = RAZONSOCIAL FROM dbo.TER WHERE IDTERCERO = @NOMBRE_PORTAL;
            SET @OBSERVACION = @OBSERVACION
                + 'EPS: ' + ISNULL(@DESC_EPS_ANT, ISNULL(@OLD_NOMBRE_PORTAL, '(vac�o)'))
                + ' ? ' + ISNULL(@DESC_EPS_NUE, ISNULL(@NOMBRE_PORTAL, '(vac�o)')) + '; ';
        END

        IF ISNULL(@OLD_LINK, '') <> ISNULL(@LINK, '')
            SET @OBSERVACION = @OBSERVACION + 'LINK: ' + ISNULL(@OLD_LINK, '(vac�o)') + ' ? ' + ISNULL(@LINK, '(vac�o)') + '; ';

        IF ISNULL(@OLD_USUARIO_PORTAL, '') <> ISNULL(@USUARIO_PORTAL, '')
            SET @OBSERVACION = @OBSERVACION + 'USUARIO_PORTAL: ' + ISNULL(@OLD_USUARIO_PORTAL, '(vac�o)') + ' ? ' + ISNULL(@USUARIO_PORTAL, '(vac�o)') + '; ';

        IF ISNULL(@OLD_CONTRASENA, '') <> ISNULL(@CONTRASENA, '')
            SET @OBSERVACION = @OBSERVACION + 'CONTRASENA: [actualizada]; ';

        IF ISNULL(@OLD_CLAVE_ESPECIAL, '') <> ISNULL(@CLAVE_ESPECIAL, '')
            SET @OBSERVACION = @OBSERVACION + 'CLAVE_ESPECIAL: [actualizada]; ';

        IF ISNULL(@OLD_ESTADO, '') <> ISNULL(@ESTADO, '')
        BEGIN
            SELECT @DESC_ESTADO_ANT = DESCRIPCION
            FROM dbo.TGEN
            WHERE TABLA = 'PORTALES' AND CAMPO = 'ESTADOS' AND CODIGO = @OLD_ESTADO;

            SELECT @DESC_ESTADO_NUE = DESCRIPCION
            FROM dbo.TGEN
            WHERE TABLA = 'PORTALES' AND CAMPO = 'ESTADOS' AND CODIGO = @ESTADO;

            SET @OBSERVACION = @OBSERVACION
                + 'ESTADO: ' + ISNULL(@DESC_ESTADO_ANT, ISNULL(@OLD_ESTADO, '(vac�o)'))
                + ' ? ' + ISNULL(@DESC_ESTADO_NUE, ISNULL(@ESTADO, '(vac�o)')) + '; ';
        END

        IF ISNULL(@OLD_DATO_ADICIONAL, '') <> ISNULL(@DATO_ADICIONAL, '')
            SET @OBSERVACION = @OBSERVACION + 'DATO_ADICIONAL: ' + ISNULL(@OLD_DATO_ADICIONAL, '(vac�o)') + ' ? ' + ISNULL(@DATO_ADICIONAL, '(vac�o)') + '; ';

        IF ISNULL(@OLD_TIPO_DOCUMENTO, '') <> ISNULL(@TIPO_DOCUMENTO, '')
            SET @OBSERVACION = @OBSERVACION + 'TIPO_DOCUMENTO: ' + ISNULL(@OLD_TIPO_DOCUMENTO, '(vac�o)') + ' ? ' + ISNULL(@TIPO_DOCUMENTO, '(vac�o)') + '; ';

        IF ISNULL(@OLD_IDTERCERO, '') <> ISNULL(@IDTERCERO, '')
            SET @OBSERVACION = @OBSERVACION + 'IDTERCERO: ' + ISNULL(@OLD_IDTERCERO, '(vac�o)') + ' ? ' + ISNULL(@IDTERCERO, '(vac�o)') + '; ';

        IF ISNULL(LTRIM(RTRIM(@OBSERVACION)), '') = ''
            SET @OBSERVACION = 'Sin cambios detectados en los campos.';

        BEGIN TRY
            UPDATE dbo.INC_CREDENCIAL
            SET IDTERCERO             = @IDTERCERO,
                NOMBRE_PORTAL         = @NOMBRE_PORTAL,
                LINK                  = @LINK,
                USUARIO_PORTAL        = @USUARIO_PORTAL,
                CONTRASENA            = @CONTRASENA,
                CLAVE_ESPECIAL        = @CLAVE_ESPECIAL,
                ESTADO                = @ESTADO,
                DATO_ADICIONAL        = @DATO_ADICIONAL,
                TIPO_DOCUMENTO        = @TIPO_DOCUMENTO,
                USUARIO_ACTUALIZACION = @USUARIO,
                FECHA_ACTUALIZACION   = GETDATE()
            WHERE IDCREDENCIAL = @IDCREDENCIAL
                AND ACTIVO = 1;

            INSERT INTO dbo.INC_CREDENCIAL_LOG (
                IDCREDENCIAL, IDTERCERO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                @IDCREDENCIAL,
                @IDTERCERO,
                'EDITAR',
                @OBSERVACION,
                @USUARIO,
                GETDATE()
            );

            SELECT 'OK' AS OK, @IDCREDENCIAL AS IDCREDENCIAL;
            RETURN;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            SELECT 'KO' AS OK, ERROR = 'Error al editar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    IF @METODO = 'ELIMINAR'
    BEGIN
        SELECT
            @IDCREDENCIAL = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IDCREDENCIAL') AS INT),
            @USUARIO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), '');

        IF @IDCREDENCIAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'IDCREDENCIAL es obligatorio.';
            RETURN;
        END

        SELECT
            @IDTERCERO = IDTERCERO,
            @NOMBRE_PORTAL = NOMBRE_PORTAL
        FROM dbo.INC_CREDENCIAL
        WHERE IDCREDENCIAL = @IDCREDENCIAL
            AND ACTIVO = 1;

        IF @IDTERCERO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La credencial no existe o ya est� inactiva.';
            RETURN;
        END

        BEGIN TRY
            UPDATE dbo.INC_CREDENCIAL
            SET ACTIVO                = 0,
                USUARIO_ACTUALIZACION = @USUARIO,
                FECHA_ACTUALIZACION   = GETDATE()
            WHERE IDCREDENCIAL = @IDCREDENCIAL;

            INSERT INTO dbo.INC_CREDENCIAL_LOG (
                IDCREDENCIAL, IDTERCERO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                @IDCREDENCIAL,
                @IDTERCERO,
                'INACTIVAR',
                CONCAT('Acceso inactivado - Portal: ', ISNULL(@NOMBRE_PORTAL, '(sin nombre)')),
                @USUARIO,
                GETDATE()
            );

            SELECT 'OK' AS OK, @IDCREDENCIAL AS IDCREDENCIAL;
            RETURN;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            SELECT 'KO' AS OK, ERROR = 'Error al inactivar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    IF @METODO = 'REVELAR'
    BEGIN
        SELECT
            @IDCREDENCIAL = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IDCREDENCIAL') AS INT),
            @USUARIO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), ''),
            @CAMPO        = NULLIF(UPPER(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CAMPO')))), '');

        IF @IDCREDENCIAL IS NULL OR @CAMPO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'IDCREDENCIAL y CAMPO son obligatorios.';
            RETURN;
        END

        IF @CAMPO NOT IN ('CONTRASENA', 'CLAVE_ESPECIAL')
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'CAMPO no v�lido.  CONTRASENA o CLAVE_ESPECIAL.';
            RETURN;
        END

        SELECT
            @IDTERCERO = IDTERCERO,
            @NOMBRE_PORTAL = NOMBRE_PORTAL,
            @VALOR_REVELADO = CASE
                WHEN @CAMPO = 'CONTRASENA' THEN CONTRASENA
                ELSE CLAVE_ESPECIAL
            END
        FROM dbo.INC_CREDENCIAL
        WHERE IDCREDENCIAL = @IDCREDENCIAL
            AND ACTIVO = 1;

        IF @IDTERCERO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La credencial no existe o est� inactiva.';
            RETURN;
        END

        IF @VALOR_REVELADO IS NULL OR LTRIM(RTRIM(@VALOR_REVELADO)) = ''
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'No hay valor para revelar en este campo.';
            RETURN;
        END

        INSERT INTO dbo.INC_CREDENCIAL_LOG (
            IDCREDENCIAL, IDTERCERO, ACCION, OBSERVACION, USUARIO_ID, FECHA
        )
        VALUES (
            @IDCREDENCIAL,
            @IDTERCERO,
            CASE WHEN @CAMPO = 'CONTRASENA' THEN 'REVELAR_CONTRASENA' ELSE 'REVELAR_CLAVE_ESPECIAL' END,
            CONCAT(
                'Consult� ',
                CASE WHEN @CAMPO = 'CONTRASENA' THEN 'la contrase�a' ELSE 'la clave especial' END,
                ' - Portal: ',
                ISNULL(@NOMBRE_PORTAL, '(sin nombre)')
            ),
            @USUARIO,
            GETDATE()
        );

        SELECT 'OK' AS OK, @CAMPO AS CAMPO, @VALOR_REVELADO AS VALOR;
        RETURN;
    END

    IF @METODO = 'VER_TRAZABILIDAD'
    BEGIN
        SELECT @IDCREDENCIAL = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IDCREDENCIAL') AS INT);

        IF @IDCREDENCIAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'IDCREDENCIAL es requerido.';
            RETURN;
        END

        SELECT
            L.IDHISTORIAL,
            L.IDCREDENCIAL,
            L.ACCION,
            ISNULL(L.OBSERVACION, '') AS OBSERVACION,
            L.USUARIO_ID,
            CONVERT(VARCHAR(20), L.FECHA, 120) AS FECHA
        FROM dbo.INC_CREDENCIAL_LOG L
        WHERE L.IDCREDENCIAL = @IDCREDENCIAL
        ORDER BY L.FECHA ASC;

        RETURN;
    END

    SELECT 'KO' AS OK, ERROR = 'M�todo no reconocido: ' + ISNULL(@METODO, 'NULL');
END
