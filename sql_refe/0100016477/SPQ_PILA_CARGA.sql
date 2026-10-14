CREATE OR ALTER PROCEDURE DBO.SPQ_PILA_CARGA
@JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO    VARCHAR(100),
        @METODO    VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX);

    DECLARE @ErrorMessage NVARCHAR(MAX);

    -- Variables reutilizadas entre m�todos
    DECLARE @USUARIO         VARCHAR(20);
    DECLARE @NOMBRE_USUARIO  NVARCHAR(200);
    DECLARE @IDTERCERO       VARCHAR(20);
    DECLARE @OPERADOR        VARCHAR(30);
    DECLARE @IDCARGA         INT;
    DECLARE @IDEMPRESA       INT;

    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100)    '$.MODELO',
        METODO      VARCHAR(100)    '$.METODO',
        PARAMETROS  NVARCHAR(MAX)   AS JSON
    );

    SELECT @MODELO = MODELO, @METODO = METODO, @PARAMETROS = PARAMETROS
    FROM #JSON;

    DROP TABLE #JSON;

    IF @METODO = 'LISTAR_CONFIGS'
    BEGIN
        SELECT
            IDCONFIG,
            OPERADOR,
            DESCRIPCION,
            CONFIG_JSON,
            PLANILLA_REGEX,
            VERSION,
            ACTIVO,
            FECHA_CREACION,
            FECHA_MODIFICA
        FROM dbo.PILA_OPERADOR_CONFIG
        WHERE ACTIVO = 1
        ORDER BY OPERADOR;
        RETURN;
    END

    IF @METODO = 'GUARDAR_CONFIG'
    BEGIN
        DECLARE
            @CONFIG_JSON     NVARCHAR(MAX),
            @DESCRIPCION     VARCHAR(200),
            @VERSION_CONFIG  VARCHAR(10),
            @PLANILLA_REGEX  VARCHAR(500),
            @IDCONFIG_EXIST  INT;

        SELECT 
            @OPERADOR        = UPPER(TRIM(OPERADOR)),
            @DESCRIPCION     = DESCRIPCION,
            @CONFIG_JSON     = CONFIG_JSON,
            @VERSION_CONFIG  = ISNULL(VERSION, '1.0'),
            @PLANILLA_REGEX  = NULLIF(TRIM(PLANILLA_REGEX), ''),
            @USUARIO         = USUARIO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            OPERADOR        VARCHAR(30)    '$.OPERADOR',
            DESCRIPCION     VARCHAR(200)   '$.DESCRIPCION',
            CONFIG_JSON     NVARCHAR(MAX)  '$.CONFIG_JSON',
            VERSION         VARCHAR(10)    '$.VERSION',
            PLANILLA_REGEX  VARCHAR(500)   '$.PLANILLA_REGEX',
            USUARIO         VARCHAR(20)    '$.USUARIO'
        );

        -- Validar par�metros obligatorios
        IF ISNULL(@OPERADOR, '') = '' OR ISNULL(@CONFIG_JSON, '') = '' OR ISNULL(@USUARIO, '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios: OPERADOR, CONFIG_JSON, USUARIO.';
            RETURN;
        END

        -- Validar que el JSON sea v�lido (ISJSON = 1)
        IF ISJSON(@CONFIG_JSON) = 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El CONFIG_JSON no es un JSON v�lido. Verifique la sintaxis.';
            RETURN;
        END

        -- Validar claves m�nimas obligatorias en el JSON
        IF JSON_VALUE(@CONFIG_JSON, '$.hoja') IS NULL
           OR JSON_QUERY(@CONFIG_JSON, '$.H1') IS NULL
           OR JSON_QUERY(@CONFIG_JSON, '$.H2') IS NULL
           OR JSON_VALUE(@CONFIG_JSON, '$.H2.fila_inicio_datos') IS NULL
           OR JSON_QUERY(@CONFIG_JSON, '$.H2.columnas.id_fusionado') IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El JSON no tiene la estructura m�nima requerida. Debe tener: hoja, H1, H2, H2.fila_inicio_datos, H2.columnas.id_fusionado.';
            RETURN;
        END

        SELECT @IDCONFIG_EXIST = IDCONFIG
        FROM dbo.PILA_OPERADOR_CONFIG
        WHERE OPERADOR = @OPERADOR;

        BEGIN TRAN;
        BEGIN TRY
            IF @IDCONFIG_EXIST IS NOT NULL
            BEGIN
                -- UPDATE
                UPDATE dbo.PILA_OPERADOR_CONFIG
                SET DESCRIPCION      = ISNULL(@DESCRIPCION, DESCRIPCION),
                    CONFIG_JSON      = @CONFIG_JSON,
                    PLANILLA_REGEX   = @PLANILLA_REGEX,
                    VERSION          = @VERSION_CONFIG,
                    USUARIO_MODIFICA = @USUARIO,
                    FECHA_MODIFICA   = GETDATE()
                WHERE IDCONFIG = @IDCONFIG_EXIST;
            END
            ELSE
            BEGIN
                -- INSERT
                INSERT INTO dbo.PILA_OPERADOR_CONFIG
                    (OPERADOR, DESCRIPCION, CONFIG_JSON, PLANILLA_REGEX, VERSION, ACTIVO, USUARIO_CREACION, FECHA_CREACION)
                VALUES
                    (@OPERADOR, @DESCRIPCION, @CONFIG_JSON, @PLANILLA_REGEX, @VERSION_CONFIG, 1, @USUARIO, GETDATE());
            END

            IF @@TRANCOUNT > 0 COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al guardar configuraci�n: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    IF @METODO = 'CARGAR_PILA_LOTE'
    BEGIN
        DECLARE
            @NOMBRE_ARCHIVO  VARCHAR(255),
            @EMPRESA_JSON    NVARCHAR(MAX),
            @DETALLE_JSON    NVARCHAR(MAX);

        SELECT
            @IDTERCERO      = JSON_VALUE(@PARAMETROS, '$.IDTERCERO'),
            @OPERADOR       = UPPER(TRIM(JSON_VALUE(@PARAMETROS, '$.OPERADOR'))),
            @NOMBRE_ARCHIVO = JSON_VALUE(@PARAMETROS, '$.NOMBRE_ARCHIVO'),
            @USUARIO        = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @EMPRESA_JSON   = JSON_QUERY(@PARAMETROS, '$.EMPRESA'),
            @DETALLE_JSON   = JSON_QUERY(@PARAMETROS, '$.DETALLE');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        -- Validar par�metros obligatorios
        IF ISNULL(LTRIM(RTRIM(@IDTERCERO)), '') = ''
           OR ISNULL(LTRIM(RTRIM(@OPERADOR)), '') = ''
           OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios: IDTERCERO, OPERADOR, USUARIO.';
            RETURN;
        END

        IF ISNULL(@EMPRESA_JSON, '') = '' OR ISNULL(@DETALLE_JSON, '') = '' OR @DETALLE_JSON = '[]'
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El archivo no contiene datos de empresa o empleados.';
            RETURN;
        END

        -- Parsear detalle H2 a tabla temporal
        SELECT
            T.TIPO_DOCUMENTO,
            T.NRO_DOCUMENTO,
            NULLIF(TRIM(T.PRIMER_APELLIDO), '')    AS PRIMER_APELLIDO,
            NULLIF(TRIM(T.SEGUNDO_APELLIDO), '')   AS SEGUNDO_APELLIDO,
            NULLIF(TRIM(T.PRIMER_NOMBRE), '')      AS PRIMER_NOMBRE,
            NULLIF(TRIM(T.SEGUNDO_NOMBRE), '')     AS SEGUNDO_NOMBRE,
            NULLIF(TRIM(T.TIPO_COTIZANTE), '')     AS TIPO_COTIZANTE,
            NULLIF(TRIM(T.SUBTIPO_COTIZANTE), '')  AS SUBTIPO_COTIZANTE,
            NULLIF(TRIM(T.NOV_ING), '')  AS NOV_ING,
            NULLIF(TRIM(T.NOV_RET), '')  AS NOV_RET,
            NULLIF(TRIM(T.NOV_TDE), '')  AS NOV_TDE,
            NULLIF(TRIM(T.NOV_TAE), '')  AS NOV_TAE,
            NULLIF(TRIM(T.NOV_TDP), '')  AS NOV_TDP,
            NULLIF(TRIM(T.NOV_TAP), '')  AS NOV_TAP,
            NULLIF(TRIM(T.NOV_VSP), '')  AS NOV_VSP,
            NULLIF(TRIM(T.NOV_VTE), '')  AS NOV_VTE,
            NULLIF(TRIM(T.NOV_VST), '')  AS NOV_VST,
            NULLIF(TRIM(T.NOV_SLN), '')  AS NOV_SLN,
            NULLIF(TRIM(T.NOV_IGE), '')  AS NOV_IGE,
            NULLIF(TRIM(T.NOV_LMA), '')  AS NOV_LMA,
            NULLIF(TRIM(T.NOV_VAC), '')  AS NOV_VAC,
            NULLIF(TRIM(T.NOV_AVP), '')  AS NOV_AVP,
            NULLIF(TRIM(T.NOV_VCT), '')  AS NOV_VCT,
            T.NOV_IRL,
            T.DIAS_PENSION, T.DIAS_SALUD, T.DIAS_CCF, T.DIAS_ARL,
            NULLIF(TRIM(T.AFP_CODIGO), '') AS AFP_CODIGO,
            NULLIF(TRIM(T.AFP_NOMBRE), '') AS AFP_NOMBRE,
            T.IBC_PENSION,
            NULLIF(TRIM(T.EPS_CODIGO), '') AS EPS_CODIGO,
            NULLIF(TRIM(T.EPS_NOMBRE), '') AS EPS_NOMBRE,
            T.IBC_SALUD,
            NULLIF(TRIM(T.CCF_CODIGO), '') AS CCF_CODIGO,
            NULLIF(TRIM(T.CCF_NOMBRE), '') AS CCF_NOMBRE,
            T.IBC_CCF,
            T.IBC_ARL,
            T.TARIFA_ARL,
            T.IBC_PARAFISCALES,
            NULLIF(TRIM(T.ACTIVIDAD_ECONOMICA_ARL), '') AS ACTIVIDAD_ECONOMICA_ARL
        INTO #PILA_TMP
        FROM OPENJSON(@DETALLE_JSON)
        WITH (
            TIPO_DOCUMENTO         VARCHAR(5)    '$.TIPO_DOCUMENTO',
            NRO_DOCUMENTO          VARCHAR(20)   '$.NRO_DOCUMENTO',
            PRIMER_APELLIDO        VARCHAR(50)   '$.PRIMER_APELLIDO',
            SEGUNDO_APELLIDO       VARCHAR(50)   '$.SEGUNDO_APELLIDO',
            PRIMER_NOMBRE          VARCHAR(50)   '$.PRIMER_NOMBRE',
            SEGUNDO_NOMBRE         VARCHAR(50)   '$.SEGUNDO_NOMBRE',
            TIPO_COTIZANTE         VARCHAR(5)    '$.TIPO_COTIZANTE',
            SUBTIPO_COTIZANTE      VARCHAR(5)    '$.SUBTIPO_COTIZANTE',
            NOV_ING  VARCHAR(2)   '$.NOV_ING',
            NOV_RET  VARCHAR(2)   '$.NOV_RET',
            NOV_TDE  VARCHAR(2)   '$.NOV_TDE',
            NOV_TAE  VARCHAR(2)   '$.NOV_TAE',
            NOV_TDP  VARCHAR(2)   '$.NOV_TDP',
            NOV_TAP  VARCHAR(2)   '$.NOV_TAP',
            NOV_VSP  VARCHAR(2)   '$.NOV_VSP',
            NOV_VTE  VARCHAR(2)   '$.NOV_VTE',
            NOV_VST  VARCHAR(2)   '$.NOV_VST',
            NOV_SLN  VARCHAR(2)   '$.NOV_SLN',
            NOV_IGE  VARCHAR(2)   '$.NOV_IGE',
            NOV_LMA  VARCHAR(2)   '$.NOV_LMA',
            NOV_VAC  VARCHAR(2)   '$.NOV_VAC',
            NOV_AVP  VARCHAR(2)   '$.NOV_AVP',
            NOV_VCT  VARCHAR(2)   '$.NOV_VCT',
            NOV_IRL  SMALLINT     '$.NOV_IRL',
            DIAS_PENSION SMALLINT  '$.DIAS_PENSION',
            DIAS_SALUD   SMALLINT  '$.DIAS_SALUD',
            DIAS_CCF     SMALLINT  '$.DIAS_CCF',
            DIAS_ARL     SMALLINT  '$.DIAS_ARL',
            AFP_CODIGO   VARCHAR(20)    '$.AFP_CODIGO',
            AFP_NOMBRE   VARCHAR(100)   '$.AFP_NOMBRE',
            IBC_PENSION  DECIMAL(18,2)  '$.IBC_PENSION',
            EPS_CODIGO   VARCHAR(20)    '$.EPS_CODIGO',
            EPS_NOMBRE   VARCHAR(100)   '$.EPS_NOMBRE',
            IBC_SALUD    DECIMAL(18,2)  '$.IBC_SALUD',
            CCF_CODIGO   VARCHAR(20)    '$.CCF_CODIGO',
            CCF_NOMBRE   VARCHAR(100)   '$.CCF_NOMBRE',
            IBC_CCF      DECIMAL(18,2)  '$.IBC_CCF',
            IBC_ARL      DECIMAL(18,2)  '$.IBC_ARL',
            TARIFA_ARL   DECIMAL(10,5)  '$.TARIFA_ARL',
            IBC_PARAFISCALES DECIMAL(18,2) '$.IBC_PARAFISCALES',
            ACTIVIDAD_ECONOMICA_ARL VARCHAR(20) '$.ACTIVIDAD_ECONOMICA_ARL'
        ) AS T;

        -- Validaci�n b�sica: debe haber al menos 1 empleado con documento
        IF NOT EXISTS (SELECT 1 FROM #PILA_TMP WHERE ISNULL(NRO_DOCUMENTO, '') <> '')
        BEGIN
            DROP TABLE #PILA_TMP;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El detalle no contiene registros con n�mero de documento v�lido.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            -- 1. Insertar cabecera del lote
            INSERT INTO dbo.PILA_CARGA (IDTERCERO, OPERADOR, NOMBRE_ARCHIVO, USUARIO_CREACION, FECHA_CREACION)
            VALUES (@IDTERCERO, @OPERADOR, @NOMBRE_ARCHIVO, @USUARIO, GETDATE());
            SET @IDCARGA = SCOPE_IDENTITY();

            -- 2. Insertar H1 (empresa)
            INSERT INTO dbo.PILA_EMPRESA (
                IDCARGA, NRO_DOCUMENTO, DV, TIPO_DOCUMENTO, RAZON_SOCIAL, CLASE_APORTANTE, TIPO_APORTANTE, TIPO_EMPRESA,
                PERIODO_PENSION, PERIODO_SALUD, FECHA_PAGO, CENTRO_TRABAJO,
                DEPARTAMENTO, MUNICIPIO, NUM_AFILIADOS, ESTADO_PLANILLA, ARL, ACTIVIDAD_ECONOMICA,
                CODIGO, NOMBRE, DIRECCION, TELEFONO, EMAIL, NUMERO_PLANTILLA
            )
            SELECT
                @IDCARGA,
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.NRO_DOCUMENTO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.DV')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.TIPO_DOCUMENTO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.RAZON_SOCIAL')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.CLASE_APORTANTE')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.TIPO_APORTANTE')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.TIPO_EMPRESA')), ''),
                TRY_CAST(CASE WHEN LEN(JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_PENSION')) = 7 THEN CONCAT(JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_PENSION'), '-01') ELSE JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_PENSION') END AS DATE),
                TRY_CAST(CASE WHEN LEN(JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_SALUD')) = 7 THEN CONCAT(JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_SALUD'), '-01') ELSE JSON_VALUE(@EMPRESA_JSON, '$.PERIODO_SALUD') END AS DATE),
                TRY_CAST(JSON_VALUE(@EMPRESA_JSON, '$.FECHA_PAGO') AS DATE),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.CENTRO_TRABAJO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.DEPARTAMENTO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.MUNICIPIO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.NUM_AFILIADOS')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.ESTADO_PLANILLA')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.ARL')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.ACTIVIDAD_ECONOMICA')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.CODIGO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.NOMBRE')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.DIRECCION')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.TELEFONO')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.EMAIL')), ''),
                NULLIF(TRIM(JSON_VALUE(@EMPRESA_JSON, '$.NUMERO_PLANTILLA')), '');

            SET @IDEMPRESA = SCOPE_IDENTITY();

            -- 3. Insertar H2 (detalle empleados) desde tabla temporal
            INSERT INTO dbo.PILA_DETALLE (
                IDCARGA, IDEMPRESA,
                TIPO_DOCUMENTO, NRO_DOCUMENTO,
                PRIMER_APELLIDO, SEGUNDO_APELLIDO, PRIMER_NOMBRE, SEGUNDO_NOMBRE,
                TIPO_COTIZANTE, SUBTIPO_COTIZANTE,
                NOV_ING, NOV_RET, NOV_TDE, NOV_TAE, NOV_TDP, NOV_TAP,
                NOV_VSP, NOV_VTE, NOV_VST, NOV_SLN, NOV_IGE, NOV_LMA,
                NOV_VAC, NOV_AVP, NOV_VCT, NOV_IRL,
                DIAS_PENSION, DIAS_SALUD, DIAS_CCF, DIAS_ARL,
                AFP_CODIGO, AFP_NOMBRE, IBC_PENSION,
                EPS_CODIGO, EPS_NOMBRE, IBC_SALUD,
                CCF_CODIGO, CCF_NOMBRE, IBC_CCF,
                IBC_ARL, TARIFA_ARL, IBC_PARAFISCALES, ACTIVIDAD_ECONOMICA_ARL
            )
            SELECT
                @IDCARGA, @IDEMPRESA,
                TIPO_DOCUMENTO, NRO_DOCUMENTO,
                PRIMER_APELLIDO, SEGUNDO_APELLIDO, PRIMER_NOMBRE, SEGUNDO_NOMBRE,
                TIPO_COTIZANTE, SUBTIPO_COTIZANTE,
                NOV_ING, NOV_RET, NOV_TDE, NOV_TAE, NOV_TDP, NOV_TAP,
                NOV_VSP, NOV_VTE, NOV_VST, NOV_SLN, NOV_IGE, NOV_LMA,
                NOV_VAC, NOV_AVP, NOV_VCT, NOV_IRL,
                DIAS_PENSION, DIAS_SALUD, DIAS_CCF, DIAS_ARL,
                AFP_CODIGO, AFP_NOMBRE, IBC_PENSION,
                EPS_CODIGO, EPS_NOMBRE, IBC_SALUD,
                CCF_CODIGO, CCF_NOMBRE, IBC_CCF,
                IBC_ARL, TARIFA_ARL, IBC_PARAFISCALES, ACTIVIDAD_ECONOMICA_ARL
            FROM #PILA_TMP;

            DROP TABLE #PILA_TMP;
            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK, @IDCARGA AS IDCARGA;
            RETURN;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            IF OBJECT_ID('tempdb..#PILA_TMP') IS NOT NULL DROP TABLE #PILA_TMP;
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al guardar la planilla PILA: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- M�todo no reconocido
    SELECT 'KO' AS OK;
    SELECT ERROR = 'M�todo no reconocido: ' + ISNULL(@METODO, 'NULL');

END
