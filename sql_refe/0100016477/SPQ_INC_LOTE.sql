CREATE OR ALTER PROCEDURE DBO.SPQ_INC_LOTE
@JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Constantes INC_ESTADO (alineadas con frontend)
    DECLARE @INC_INGRESADA_INTERNO INT = 1;
    DECLARE @INC_INGRESADA_EXTERNO INT = 2;
    DECLARE @INC_EN_REVISION INT = 3;
    DECLARE @INC_DEVUELTO_EMPRESA INT = 4;
    DECLARE @INC_SUBSANADO INT = 5;
    DECLARE @INC_VALIDADO INT = 6;
    DECLARE @INC_RADICADO INT = 7;
    DECLARE @INC_PENDIENTE_VALIDACION_RECHAZO INT = 8;
    DECLARE @INC_RECHAZO_DEFINITIVO INT = 12;
    DECLARE @INC_RECHAZO_RECURRIBLE INT = 13;
    DECLARE @INC_APROBADA INT = 9;
    DECLARE @INC_PAGADA INT = 10;

    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @IDTERCERO VARCHAR(20),
        @USUARIO VARCHAR(20),
        @NOMBRE_USUARIO NVARCHAR(200),
        @DETALLE NVARCHAR(MAX),
        @IDESTADO_INICIAL INT;

    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @FriendlyMessage NVARCHAR(MAX);

    -- CARGAR_LOTE
    DECLARE @IDCARGA INT;

    -- CAMBIAR_ESTADO
    DECLARE @IDINCAPACIDAD INT;
    DECLARE @IDESTADO_NUEVO INT;
    DECLARE @IDESTADO_ANTERIOR INT;
    DECLARE @ACCION VARCHAR(50);
    DECLARE @CAUSA_RECHAZO VARCHAR(200);
    DECLARE @OBSERVACION_RECHAZO NVARCHAR(2000);
    DECLARE @DETALLES_RECHAZO NVARCHAR(MAX);
    DECLARE @CAUSA_DEV_DESC NVARCHAR(500);
    DECLARE @DETALLE_DEV_LOG NVARCHAR(MAX);
    DECLARE @OBSERVACION_APROBADA NVARCHAR(2000);

    -- REASIGNAR_INCA
    DECLARE @IDINCAPACIDADES NVARCHAR(MAX);
    DECLARE @Ids TABLE (IDINCAPACIDAD INT PRIMARY KEY);
    DECLARE @IdsActualizados TABLE (IDINCAPACIDAD INT);

    -- REGISTRAR_RADICADO_EPS
    DECLARE @NUMERO_RADICADO_EPS VARCHAR(50);

    -- CORREGIR_INCA
    DECLARE @IDESTADO_ACTUAL INT;
    DECLARE @EDITABLE_CLIENTE BIT;
    DECLARE @TIPO_DOCUMENTO VARCHAR(10);
    DECLARE @NUMERO_DOCUMENTO VARCHAR(20);
    DECLARE @PRIMER_NOMBRE VARCHAR(100);
    DECLARE @SEGUNDO_NOMBRE VARCHAR(100);
    DECLARE @PRIMER_APELLIDO VARCHAR(100);
    DECLARE @SEGUNDO_APELLIDO VARCHAR(100);
    DECLARE @IDEPS VARCHAR(20);
    DECLARE @FECHA_INICIO DATE;
    DECLARE @DIAS_INCAPACIDAD SMALLINT;
    DECLARE @DIAGNOSTICO NVARCHAR(500);
    DECLARE @IDIPS VARCHAR(20);
    DECLARE @ORIGEN VARCHAR(50);
    DECLARE @TIPO_LM VARCHAR(20);
    DECLARE @PRORROGA BIT;
    DECLARE @IBC DECIMAL(18,2);
    DECLARE @TIPO_COTIZANTE VARCHAR(20);
    DECLARE @FECHA_FIN DATE;
    DECLARE @IDDX VARCHAR(10);

    -- ACTUALIZAR_IBC / resoluci�n PILA en CARGAR_LOTE
    DECLARE @IBC_NUEVO DECIMAL(18,2);
    DECLARE @IBC_PILA DECIMAL(18,2);
    DECLARE @IBC_ORIGEN_ANTERIOR VARCHAR(20);
    DECLARE @IDINCAPACIDAD_ACTUAL INT;
    DECLARE @FECHA_INICIO_INC DATE;
    DECLARE @NUMERO_DOCUMENTO_AFILIADO VARCHAR(20);
    DECLARE @PERIODO_PILA CHAR(6);
    DECLARE @ORIGEN_INC VARCHAR(50);  -- Origen de la incapacidad (MATERNIDAD/PATERNIDAD/otros)

    -- RECHAZO BIFURCADO
    DECLARE @TIPO_RECHAZO VARCHAR(20);
    DECLARE @FECHA_NOTIF_RECHAZO_RAD DATE;
    DECLARE @CATEGORIA_RECHAZO_RAD VARCHAR(50);
    DECLARE @MOTIVO_RECHAZO_RAD NVARCHAR(2000);
    -- INC_PARAMETROS_LEGALES
    DECLARE @IDPARAMETRO_INC INT;
    DECLARE @ANIO_INC INT;
    DECLARE @SMMLV_INC DECIMAL(18,2);
    DECLARE @MARGEN_ERROR_PESOS_INC DECIMAL(18,2);

    -- APROBAR_INCA / margen de error
    DECLARE @ANIO_INCA INT;
    DECLARE @VALOR_PAGADO_EPS DECIMAL(18,2);
    DECLARE @CONFIRMAR_FUERA_MARGEN BIT;
    DECLARE @VALOR_LIQUIDADO_MOTOR DECIMAL(18,2);
    DECLARE @DIFERENCIA_APROBACION DECIMAL(18,2);
    DECLARE @MARGEN_ERROR_PESOS DECIMAL(18,2);

    -- ACTIVACION_LOTE
    DECLARE @PROCESO VARCHAR(20);
    DECLARE @IDCARGA_ACTIVAR INT;

    -- INC_INCAPACIDAD_ADJUNTO
    DECLARE @CODIGO_DOC VARCHAR(50);
    DECLARE @ETIQUETA_DOC VARCHAR(300);
    DECLARE @ID_DOCS UNIQUEIDENTIFIER;

    -- Extraer MODELO, METODO y PARAMETROS
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100)    '$.MODELO',
        METODO      VARCHAR(100)    '$.METODO',
        PARAMETROS  NVARCHAR(MAX)   AS JSON
    );

    SELECT @MODELO = MODELO,
        @METODO = METODO,
        @PARAMETROS = PARAMETROS
    FROM #JSON;

    DROP TABLE #JSON;

    -- METODO: CARGAR_LOTE (Carga masiva desde Excel)
    IF @METODO = 'CARGAR_LOTE'
    BEGIN
        SELECT
            @IDTERCERO = JSON_VALUE(@PARAMETROS, '$.IDTERCERO'),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @DETALLE = JSON_QUERY(@PARAMETROS, '$.DETALLE'),
            @IDESTADO_INICIAL = CAST(JSON_VALUE(@PARAMETROS, '$.IDESTADO_INICIAL') AS INT);

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        DECLARE @ErroresInca TABLE (
            TIPO_DOCUMENTO VARCHAR(10) NULL,
            NUMERO_DOCUMENTO VARCHAR(20) NULL,
            DESCRIPCION_ERROR VARCHAR(500)
        );

        IF ISNULL(LTRIM(RTRIM(@IDTERCERO)), '') = '' OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = '' OR @IDESTADO_INICIAL IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios.';
            RETURN;
        END

        IF ISNULL(@DETALLE, '') = '' OR @DETALLE = '[]'
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El archivo Excel no contiene registros.';
            RETURN;
        END

        -- 1. Parsear el JSON a tabla temporal
        SELECT
            T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO,
            NULLIF(TRIM(T.PRIMER_NOMBRE), '') AS PRIMER_NOMBRE,
            NULLIF(TRIM(T.SEGUNDO_NOMBRE), '') AS SEGUNDO_NOMBRE,
            NULLIF(TRIM(T.PRIMER_APELLIDO), '') AS PRIMER_APELLIDO,
            NULLIF(TRIM(T.SEGUNDO_APELLIDO), '') AS SEGUNDO_APELLIDO,
            NULLIF(TRIM(T.NIT_EPS), '') AS NIT_EPS,
            T.IBC, T.FECHA_INICIO, T.DIAS_INCAPACIDAD,
            T.DIAGNOSTICO AS CODIGO_CIE10,
            NULLIF(TRIM(T.NIT_IPS), '') AS NIT_IPS,
            T.ORIGEN, T.TIPO_LM,
            ISNULL(T.PRORROGA, 0) AS PRORROGA,
            ISNULL(T.TIPO_COTIZANTE, 'DEPENDIENTE') AS TIPO_COTIZANTE,
            CAST(NULL AS INT) AS IDAFILIADO,
            CAST(NULL AS VARCHAR(10)) AS IDDX
        INTO #INCA_TMP
        FROM OPENJSON(@DETALLE)
        WITH (
            TIPO_DOCUMENTO VARCHAR(10) '$.TIPO_DOCUMENTO',
            NUMERO_DOCUMENTO VARCHAR(20) '$.NUMERO_DOCUMENTO',
            PRIMER_NOMBRE VARCHAR(100) '$.PRIMER_NOMBRE',
            SEGUNDO_NOMBRE VARCHAR(100) '$.SEGUNDO_NOMBRE',
            PRIMER_APELLIDO VARCHAR(100) '$.PRIMER_APELLIDO',
            SEGUNDO_APELLIDO VARCHAR(100) '$.SEGUNDO_APELLIDO',
            NIT_EPS VARCHAR(20) '$.EPS',
            IBC DECIMAL(18,2) '$.IBC',
            FECHA_INICIO DATE '$.FECHA_INICIO',
            DIAS_INCAPACIDAD SMALLINT '$.DIAS_INCAPACIDAD',
            DIAGNOSTICO VARCHAR(10) '$.DIAGNOSTICO',
            NIT_IPS VARCHAR(20) '$.NIT_IPS',
            ORIGEN VARCHAR(50) '$.ORIGEN',
            TIPO_LM VARCHAR(20) '$.TIPO_LM',
            PRORROGA BIT '$.PRORROGA',
            TIPO_COTIZANTE VARCHAR(20) '$.TIPO_COTIZANTE'
        ) AS T;

        -- Resolver IDEPS e IDIPS desde TER (carga masiva: Excel env�a NIT)
        ALTER TABLE #INCA_TMP ADD IDEPS VARCHAR(20) NULL;
        ALTER TABLE #INCA_TMP ADD IDIPS VARCHAR(20) NULL;

        -- 2. Validaciones Obligatorias de Evento
        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'El Tipo de documento es obligatorio.'
        FROM #INCA_TMP
        WHERE ISNULL(LTRIM(RTRIM(TIPO_DOCUMENTO)), '') = '';

        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'Campos obligatorios incompletos: Documento, Fecha Inicio, D�as (>0), Diagn�stico o Origen.'
        FROM #INCA_TMP
        WHERE ISNULL(NUMERO_DOCUMENTO, '') = '' OR FECHA_INICIO IS NULL OR ISNULL(DIAS_INCAPACIDAD, 0) <= 0 
            OR ISNULL(CODIGO_CIE10, '') = '' OR ISNULL(ORIGEN, '') = '';

        -- Regla de Maternidad
        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'Val. Maternidad: Si Origen es MATERNIDAD, Tipo LM debe ser NORMAL/PREMATURO/MULTIPLE. Si no, vac�o.'
        FROM #INCA_TMP
        WHERE (ORIGEN = 'MATERNIDAD' AND ISNULL(TIPO_LM, '') NOT IN ('NORMAL', 'PREMATURO', 'MULTIPLE'))
            OR (ISNULL(ORIGEN, '') <> 'MATERNIDAD' AND ISNULL(TIPO_LM, '') <> '');

        -- Topes de d�as LM / Paternidad (solo esos or�genes; EG/ARL sin cambio)
        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, V.MENSAJE
        FROM #INCA_TMP T
        CROSS APPLY dbo.FNK_INC_VALIDAR_DIAS_LM(T.ORIGEN, T.TIPO_LM, T.DIAS_INCAPACIDAD) V
        WHERE V.ES_VALIDO = 0;

        -- Duplicados en el mismo archivo (misma carga)
        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT
            T.TIPO_DOCUMENTO,
            T.NUMERO_DOCUMENTO,
            'Registro duplicado en el archivo (mismo Tipo documento, N�mero y Fecha inicio). Un certificado no puede repetirse en la misma carga.'
        FROM #INCA_TMP T
        WHERE ISNULL(LTRIM(RTRIM(T.TIPO_DOCUMENTO)), '') <> ''
            AND ISNULL(LTRIM(RTRIM(T.NUMERO_DOCUMENTO)), '') <> ''
            AND T.FECHA_INICIO IS NOT NULL
        GROUP BY T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, T.FECHA_INICIO
        HAVING COUNT(*) > 1;

        -- Duplicados contra incapacidades ya registradas (global, cualquier estado y empresa)
        -- Marco legal: un mismo certificado (tipo doc + n�mero + fecha inicio) no puede radicarse dos veces ante la EPS.
        INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT DISTINCT
            T.TIPO_DOCUMENTO,
            T.NUMERO_DOCUMENTO,
            'Incapacidad ya registrada (mismo Tipo documento, N�mero y Fecha inicio, Lote #' + CAST(I.IDCARGA AS VARCHAR(20))
                + '). No se permite duplicar el certificado ni la pr�rroga con la misma fecha; utilice correcci�n o devoluci�n.'
        FROM #INCA_TMP T
        INNER JOIN dbo.INC_AFILIADO AF
            ON AF.TIPO_DOCUMENTO = T.TIPO_DOCUMENTO
           AND AF.NUMERO_DOCUMENTO = T.NUMERO_DOCUMENTO
        INNER JOIN dbo.INCA I
            ON I.IDAFILIADO = AF.IDAFILIADO
           AND I.FECHA_INICIO = T.FECHA_INICIO
        WHERE ISNULL(LTRIM(RTRIM(T.TIPO_DOCUMENTO)), '') <> ''
            AND ISNULL(LTRIM(RTRIM(T.NUMERO_DOCUMENTO)), '') <> ''
            AND T.FECHA_INICIO IS NOT NULL
            AND NOT EXISTS (
                SELECT 1 FROM @ErroresInca E
                WHERE ISNULL(E.TIPO_DOCUMENTO, '') = ISNULL(T.TIPO_DOCUMENTO, '')
                  AND ISNULL(E.NUMERO_DOCUMENTO, '') = ISNULL(T.NUMERO_DOCUMENTO, '')
                  AND E.DESCRIPCION_ERROR LIKE '%duplicad%'
            );

        -- Abortar antes de transacci�n si ya hay errores de validaci�n previa
        IF EXISTS (SELECT 1 FROM @ErroresInca)
        BEGIN
            IF OBJECT_ID('tempdb..#INCA_TMP') IS NOT NULL DROP TABLE #INCA_TMP;
            SELECT 'KO' AS OK;
            SELECT ERROR = CONCAT(
                'Carga fallida. Hay ',
                (SELECT COUNT(*) FROM @ErroresInca),
                ' registro(s) con errores. Descargue el archivo.'
            );
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR FROM @ErroresInca;
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            -- Vincular Diagn�stico (Solo Activos)
            UPDATE T SET IDDX = C.IDDX
            FROM #INCA_TMP T INNER JOIN dbo.MDX C ON T.CODIGO_CIE10 = C.IDDX AND C.ESTADO = 'Activo';

            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'Diagn�stico CIE10 no v�lido o Inactivo: ' + CODIGO_CIE10 FROM #INCA_TMP WHERE IDDX IS NULL;

            -- 3. VALIDACI�N DE AFILIADOS (Upsert Inteligente)
            -- Prioridad IBC del caso (se aplica en cursor post-insert sobre INCA):
            --   1) PILA (periodo mes anterior a fecha inicio)
            --   2) Excel (columna del archivo)
            --   3) INC_AFILIADO.IBC_ULTIMO (si el Excel no trae IBC)
            -- A. Resolver IDEPS: NIT_EPS + categor�a contratante (EPS)
            UPDATE T SET T.IDEPS = TER.IDTERCERO
            FROM #INCA_TMP T
            INNER JOIN dbo.TER ON TER.NIT = T.NIT_EPS AND TER.ESTADO = 'Activo'
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATCONTRATANTE')
                AND TX.ESTADO = 'Activo'
            WHERE T.NIT_EPS IS NOT NULL;

            -- B. Resolver IDIPS: NIT_IPS + categor�a IPS
            UPDATE T SET T.IDIPS = TER.IDTERCERO
            FROM #INCA_TMP T
            INNER JOIN dbo.TER ON TER.NIT = T.NIT_IPS AND TER.ESTADO = 'Activo'
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATIPS')
                AND TX.ESTADO = 'Activo'
            WHERE T.NIT_IPS IS NOT NULL;

            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'El NIT de la EPS es obligatorio.'
            FROM #INCA_TMP
            WHERE ISNULL(LTRIM(RTRIM(NIT_EPS)), '') = '';

            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'EPS no v�lida.'
            FROM #INCA_TMP
            WHERE ISNULL(LTRIM(RTRIM(NIT_EPS)), '') <> '' AND IDEPS IS NULL;

            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'El NIT de la IPS es obligatorio.'
            FROM #INCA_TMP
            WHERE ISNULL(LTRIM(RTRIM(NIT_IPS)), '') = '';

            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'IPS no v�lida.'
            FROM #INCA_TMP
            WHERE ISNULL(LTRIM(RTRIM(NIT_IPS)), '') <> '' AND IDIPS IS NULL;

            -- Afiliados existentes: completar IBC; IDEPS ya viene resuelto desde TER
            UPDATE T SET IDAFILIADO = A.IDAFILIADO,
                IBC = ISNULL(T.IBC, A.IBC_ULTIMO)
            FROM #INCA_TMP T INNER JOIN dbo.INC_AFILIADO A ON T.TIPO_DOCUMENTO = A.TIPO_DOCUMENTO AND T.NUMERO_DOCUMENTO = A.NUMERO_DOCUMENTO;

            -- B. Validar Extrictamente a los NUEVOS
            INSERT INTO @ErroresInca (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'Afiliado Nuevo: OBLIGATORIO traer Primer Nombre, Primer Apellido y NIT de EPS v�lido en su primer registro.'
            FROM #INCA_TMP
            WHERE IDAFILIADO IS NULL AND (PRIMER_NOMBRE IS NULL OR PRIMER_APELLIDO IS NULL OR IDEPS IS NULL OR IDIPS IS NULL);

            -- Abortar si hay errores
            IF EXISTS (SELECT 1 FROM @ErroresInca)
            BEGIN
                ROLLBACK;
                IF OBJECT_ID('tempdb..#INCA_TMP') IS NOT NULL DROP TABLE #INCA_TMP;
                SELECT 'KO' AS OK;
                SELECT ERROR = CONCAT('Carga fallida. Hay ', (SELECT COUNT(*) FROM @ErroresInca), ' registro(s) con errores. Descargue el archivo.');
                SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR FROM @ErroresInca;
                RETURN;
            END

            -- C. Crear Afiliados Nuevos
            INSERT INTO dbo.INC_AFILIADO (IDTERCERO, TIPO_DOCUMENTO, NUMERO_DOCUMENTO, PRIMER_NOMBRE, SEGUNDO_NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO, IDEPS_ULTIMA, IBC_ULTIMO)
            SELECT DISTINCT @IDTERCERO, TIPO_DOCUMENTO, NUMERO_DOCUMENTO, PRIMER_NOMBRE, SEGUNDO_NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO, IDEPS, IBC
            FROM #INCA_TMP WHERE IDAFILIADO IS NULL;

            -- Actualizar IDs en temporal
            UPDATE T SET IDAFILIADO = A.IDAFILIADO
            FROM #INCA_TMP T INNER JOIN dbo.INC_AFILIADO A ON T.TIPO_DOCUMENTO = A.TIPO_DOCUMENTO AND T.NUMERO_DOCUMENTO = A.NUMERO_DOCUMENTO
            WHERE T.IDAFILIADO IS NULL;

            -- D. Actualizar Afiliados Existentes (nombres/IDEPS; IBC_ULTIMO tras resolver PILA/Excel)
            UPDATE A SET
                PRIMER_NOMBRE = ISNULL(T.PRIMER_NOMBRE, A.PRIMER_NOMBRE),
                SEGUNDO_NOMBRE = ISNULL(T.SEGUNDO_NOMBRE, A.SEGUNDO_NOMBRE),
                PRIMER_APELLIDO = ISNULL(T.PRIMER_APELLIDO, A.PRIMER_APELLIDO),
                SEGUNDO_APELLIDO = ISNULL(T.SEGUNDO_APELLIDO, A.SEGUNDO_APELLIDO),
                IDEPS_ULTIMA = ISNULL(T.IDEPS, A.IDEPS_ULTIMA)
            FROM dbo.INC_AFILIADO A INNER JOIN #INCA_TMP T ON A.IDAFILIADO = T.IDAFILIADO;

            -- 4. INSERTAR EN INCA (S�lo IDs de identidad)
            INSERT INTO dbo.INC_CARGA (IDTERCERO, USUARIO_CREACION, FECHA_CREACION, ESTADO_LOTE) 
            VALUES (@IDTERCERO, @USUARIO, GETDATE(), 0);
            SET @IDCARGA = SCOPE_IDENTITY();

            -- CAMBIO 2026-06-02 IVAN - INSERT INCA con IBC_EXCEL y resoluci�n autom�tica desde PILA
            DECLARE @InsertedInca TABLE (IDINCAPACIDAD INT PRIMARY KEY);

            INSERT INTO dbo.INCA (
                IDCARGA, IDESTADO, IDTERCERO, IDAFILIADO, IDDX,
                FECHA_INICIO, DIAS_INCAPACIDAD, FECHA_FIN, IDIPS, ORIGEN, TIPO_LM, PRORROGA,
                IBC, IBC_EXCEL, IDEPS, TIPO_COTIZANTE,
                USUARIO_CREACION, FECHA_CREACION
            )
            OUTPUT INSERTED.IDINCAPACIDAD INTO @InsertedInca (IDINCAPACIDAD)
            SELECT
                @IDCARGA, @IDESTADO_INICIAL, @IDTERCERO, T.IDAFILIADO, T.IDDX,
                T.FECHA_INICIO, T.DIAS_INCAPACIDAD, DATEADD(DAY, T.DIAS_INCAPACIDAD - 1, T.FECHA_INICIO), T.IDIPS, T.ORIGEN, T.TIPO_LM, ISNULL(T.PRORROGA, 0),
                T.IBC, T.IBC, T.IDEPS, T.TIPO_COTIZANTE,
                @USUARIO, GETDATE()
            FROM #INCA_TMP T;

            DECLARE cur_resuelve_ibc CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.IDINCAPACIDAD, i.FECHA_INICIO, af.NUMERO_DOCUMENTO, UPPER(ISNULL(i.ORIGEN, ''))
            FROM @InsertedInca ins
            INNER JOIN dbo.INCA i ON i.IDINCAPACIDAD = ins.IDINCAPACIDAD
            INNER JOIN dbo.INC_AFILIADO af ON i.IDAFILIADO = af.IDAFILIADO;

            OPEN cur_resuelve_ibc;
            FETCH NEXT FROM cur_resuelve_ibc INTO @IDINCAPACIDAD_ACTUAL, @FECHA_INICIO_INC, @NUMERO_DOCUMENTO_AFILIADO, @ORIGEN_INC;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @IBC_PILA = NULL;

                -- Regla de per�odo PILA seg�n origen:
                --   MATERNIDAD / PATERNIDAD ? mismo mes de la incapacidad (el IBC del per�odo en curso
                --                             es el que corresponde normativamente para licencias de maternidad/paternidad)
                --   EG / ARL / dem�s        ? mes inmediatamente anterior a la fecha de inicio
                IF @ORIGEN_INC IN ('MATERNIDAD', 'PATERNIDAD')
                    SET @PERIODO_PILA = FORMAT(@FECHA_INICIO_INC, 'yyyyMM');
                ELSE
                    SET @PERIODO_PILA = FORMAT(DATEADD(MONTH, -1, @FECHA_INICIO_INC), 'yyyyMM');

                SELECT TOP 1 @IBC_PILA = PD.IBC_SALUD
                FROM dbo.PILA_DETALLE PD
                INNER JOIN dbo.PILA_CARGA PC ON PD.IDCARGA = PC.IDCARGA
                INNER JOIN dbo.PILA_EMPRESA PE ON PE.IDCARGA = PC.IDCARGA
                WHERE PC.IDTERCERO = @IDTERCERO
                    AND PD.NRO_DOCUMENTO = @NUMERO_DOCUMENTO_AFILIADO
                    AND CONVERT(CHAR(6), PE.PERIODO_SALUD, 112) = @PERIODO_PILA
                    AND ISNULL(PD.NOV_ING,'') = '' AND ISNULL(PD.NOV_RET,'') = ''
                    AND ISNULL(PD.NOV_TDE,'') = '' AND ISNULL(PD.NOV_TAE,'') = ''
                    AND ISNULL(PD.NOV_TDP,'') = '' AND ISNULL(PD.NOV_TAP,'') = ''
                    AND ISNULL(PD.NOV_VSP,'') = '' AND ISNULL(PD.NOV_VTE,'') = ''
                    AND ISNULL(PD.NOV_VST,'') = '' AND ISNULL(PD.NOV_SLN,'') = ''
                    AND ISNULL(PD.NOV_IGE,'') = '' AND ISNULL(PD.NOV_LMA,'') = ''
                    AND ISNULL(PD.NOV_VAC,'') = '' AND ISNULL(PD.NOV_AVP,'') = ''
                    AND ISNULL(PD.NOV_VCT,'') = '' AND ISNULL(PD.NOV_IRL,0) = 0
                ORDER BY PE.PERIODO_SALUD DESC;

                IF @IBC_PILA IS NOT NULL AND @IBC_PILA > 0
                BEGIN
                    UPDATE dbo.INCA
                    SET IBC = @IBC_PILA,
                        IBC_PILA = @IBC_PILA,
                        IBC_ORIGEN = 'PILA'
                    WHERE IDINCAPACIDAD = @IDINCAPACIDAD_ACTUAL;
                END
                ELSE
                BEGIN
                    UPDATE dbo.INCA
                    SET IBC_ORIGEN = 'EXCEL'
                    WHERE IDINCAPACIDAD = @IDINCAPACIDAD_ACTUAL;
                END

                FETCH NEXT FROM cur_resuelve_ibc INTO @IDINCAPACIDAD_ACTUAL, @FECHA_INICIO_INC, @NUMERO_DOCUMENTO_AFILIADO, @ORIGEN_INC;
            END

            CLOSE cur_resuelve_ibc;
            DEALLOCATE cur_resuelve_ibc;

            -- E. Maestro afiliado: IBC_ULTIMO = IBC vigente ya resuelto en INCA (PILA > Excel > anterior)
            UPDATE A
            SET IBC_ULTIMO = ult.IBC
            FROM dbo.INC_AFILIADO A
            INNER JOIN (
                SELECT i.IDAFILIADO, i.IBC,
                    ROW_NUMBER() OVER (PARTITION BY i.IDAFILIADO ORDER BY i.IDINCAPACIDAD DESC) AS rn
                FROM dbo.INCA i
                INNER JOIN @InsertedInca ins ON ins.IDINCAPACIDAD = i.IDINCAPACIDAD
                WHERE i.IBC IS NOT NULL AND i.IBC > 0
            ) ult ON ult.IDAFILIADO = A.IDAFILIADO AND ult.rn = 1;

            -- 5. Registrar log
            INSERT INTO dbo.INC_LOG (IDCARGA, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA)
            VALUES (@IDCARGA, NULL, @IDESTADO_INICIAL, 'CARGA_EXCEL', 'Carga masiva por ' + @NOMBRE_USUARIO, @USUARIO, GETDATE());

            DROP TABLE #INCA_TMP;
            COMMIT;

            SELECT 'OK' AS OK;
            SELECT NUMERO_DOCUMENTO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = 'Error inesperado: ' + ERROR_MESSAGE();
            SELECT NUMERO_DOCUMENTO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
            RETURN;
        END CATCH
    END

    -- METODO: CAMBIAR_ESTADO (cambio de estado de una incapacidad)
    IF @METODO = 'CAMBIAR_ESTADO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @IDESTADO_NUEVO = CAST(JSON_VALUE(@PARAMETROS, '$.IDESTADO_NUEVO') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @CAUSA_RECHAZO = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CAUSA_RECHAZO')), ''),
            @OBSERVACION_RECHAZO = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.OBSERVACION_RECHAZO')), ''),
            @DETALLES_RECHAZO = JSON_QUERY(@PARAMETROS, '$.DETALLES_RECHAZO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @IDESTADO_NUEVO IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros IDINCAPACIDAD o IDESTADO_NUEVO';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR = @IDESTADO_NUEVO
        BEGIN
            SELECT 'OK' AS OK;
            RETURN;
        END

        SET @ACCION = CASE @IDESTADO_NUEVO
            WHEN @INC_EN_REVISION THEN 'EN_REVISION'
            WHEN @INC_DEVUELTO_EMPRESA THEN 'DEVOLUCION_EMPRESA'
            WHEN @INC_VALIDADO THEN 'VALIDADO'
            ELSE 'CAMBIO_ESTADO'
        END;

        -- =====================================================================
        -- ESCUDO CRONOL�GICO: Prevenir Ejecuci�n de Motor en Desorden
        -- No permite validar un caso si hay otros m�s antiguos pendientes
        -- =====================================================================
        IF @IDESTADO_NUEVO = @INC_VALIDADO
        BEGIN
            DECLARE @FechaInicioCheck DATE;
            DECLARE @IdAfiliadoCheck INT;
            DECLARE @IdDxCheck VARCHAR(10);
            
            SELECT @FechaInicioCheck = FECHA_INICIO, @IdAfiliadoCheck = IDAFILIADO, @IdDxCheck = IDDX
            FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
            
            IF EXISTS (
                SELECT 1 FROM dbo.INCA
                WHERE IDAFILIADO = @IdAfiliadoCheck
                    AND FECHA_INICIO < @FechaInicioCheck
                    AND FECHA_INICIO >= DATEADD(DAY, -90, @FechaInicioCheck)
                    AND IDESTADO < @INC_VALIDADO
                    AND (
                        FECHA_FIN >= @FechaInicioCheck  -- Mismo o diferente origen, pero se pisan las fechas (Riesgo Traslape)
                        OR
                        (IDDX = @IdDxCheck AND DATEDIFF(DAY, FECHA_FIN, @FechaInicioCheck) <= 30) -- Misma enfermedad en < 30 d�as (Riesgo Pr�rroga)
                    )
            )

            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = 'Validaci�n denegada. El paciente tiene incapacidades m�s antiguas pendientes por gestionar. Para asegurar el c�lculo correcto de Pr�rrogas y Traslapes, debe validar los casos en estricto orden cronol�gico.';
                RETURN;
            END
        END

        -- CAMBIO 2026-06-02 IVAN - Blindaje IBC antes de validar
        IF @IDESTADO_NUEVO = @INC_VALIDADO
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM dbo.INCA
                WHERE IDINCAPACIDAD = @IDINCAPACIDAD
                    AND IBC > 0
                    AND IBC_ORIGEN IS NOT NULL
            )
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = 'No se puede validar: el IBC no ha sido resuelto. Abra la incapacidad, verifique el IBC y gu�rdelo antes de validar.';
                RETURN;
            END
        END

        -- Devoluci�n a empresa: validar causa TGEN y detalles m�ltiples
        IF @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA
        BEGIN
            IF @CAUSA_RECHAZO IS NULL
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = 'La causa de devoluci�n es obligatoria';
                RETURN;
            END

            IF NOT EXISTS (
                SELECT 1
                FROM dbo.TGEN
                WHERE TABLA = 'INCAPACIDADES'
                  AND CAMPO = 'CAUSA_DEVOLUCION'
                  AND CODIGO = @CAUSA_RECHAZO
            )
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = 'La causa de devoluci�n no es v�lida';
                RETURN;
            END

            IF @CAUSA_RECHAZO IN ('02', '04')
            BEGIN
                IF @DETALLES_RECHAZO IS NULL
                    OR @DETALLES_RECHAZO = '[]'
                    OR (SELECT COUNT(*) FROM OPENJSON(@DETALLES_RECHAZO)) = 0
                BEGIN
                    SELECT 'KO' AS OK;
                    SELECT ERROR = 'Debe seleccionar al menos un detalle de devoluci�n';
                    RETURN;
                END
            END

            IF @DETALLES_RECHAZO IS NOT NULL AND @DETALLES_RECHAZO <> '[]'
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM OPENJSON(@DETALLES_RECHAZO) j
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM dbo.TGEN t
                        WHERE t.TABLA = 'INCAPACIDADES'
                          AND t.CAMPO = 'DETALLE_DEVOLUCION'
                          AND t.CODIGO = j.value
                          AND t.DATO1 = @CAUSA_RECHAZO
                    )
                )
                BEGIN
                    SELECT 'KO' AS OK;
                    SELECT ERROR = 'Uno o m�s detalles no corresponden a la causa seleccionada';
                    RETURN;
                END
            END
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @IDESTADO_NUEVO,
                CAUSA_RECHAZO = CASE WHEN @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA THEN @CAUSA_RECHAZO ELSE CAUSA_RECHAZO END,
                OBSERVACION_RECHAZO = CASE WHEN @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA THEN @OBSERVACION_RECHAZO ELSE OBSERVACION_RECHAZO END,
                ESTADO_SEMAFORO = CASE
                    WHEN @IDESTADO_NUEVO = @INC_APROBADA THEN 'AZUL'
                    ELSE ESTADO_SEMAFORO
                END
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            IF @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA
            BEGIN
                DELETE FROM dbo.INC_DEVOLUCION_DET
                WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

                IF @DETALLES_RECHAZO IS NOT NULL AND @DETALLES_RECHAZO <> '[]'
                BEGIN
                    INSERT INTO dbo.INC_DEVOLUCION_DET (IDINCAPACIDAD, CODIGO_DETALLE)
                    SELECT @IDINCAPACIDAD, j.value
                    FROM OPENJSON(@DETALLES_RECHAZO) j;
                END
            END

            SET @CAUSA_DEV_DESC = NULL;
            SET @DETALLE_DEV_LOG = NULL;

            IF @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA
            BEGIN
                SELECT @CAUSA_DEV_DESC = DESCRIPCION
                FROM dbo.TGEN
                WHERE TABLA = 'INCAPACIDADES'
                  AND CAMPO = 'CAUSA_DEVOLUCION'
                  AND CODIGO = @CAUSA_RECHAZO;

                IF @DETALLES_RECHAZO IS NOT NULL AND @DETALLES_RECHAZO <> '[]'
                BEGIN
                    SELECT @DETALLE_DEV_LOG = STRING_AGG(t.DESCRIPCION, '; ') WITHIN GROUP (ORDER BY t.CODIGO)
                    FROM OPENJSON(@DETALLES_RECHAZO) j
                    INNER JOIN dbo.TGEN t
                        ON t.TABLA = 'INCAPACIDADES'
                       AND t.CAMPO = 'DETALLE_DEVOLUCION'
                       AND t.CODIGO = j.value;
                END
            END

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @IDESTADO_ANTERIOR,
                @IDESTADO_NUEVO,
                @ACCION,
                CASE
                    WHEN @IDESTADO_NUEVO = @INC_DEVUELTO_EMPRESA THEN
                        CONCAT(
                            ISNULL(@CAUSA_DEV_DESC, @CAUSA_RECHAZO),
                            CASE WHEN @DETALLE_DEV_LOG IS NOT NULL THEN ': ' + @DETALLE_DEV_LOG ELSE '' END,
                            CASE WHEN @OBSERVACION_RECHAZO IS NOT NULL THEN ' - ' + @OBSERVACION_RECHAZO ELSE '' END,
                            ' - Por: ', @NOMBRE_USUARIO
                        )
                    ELSE 'Cambio realizado por ' + @NOMBRE_USUARIO
                END,
                @USUARIO,
                GETDATE()
            );

            -- Ejecutar el Motor de Liquidaci�n Autom�ticamente al Validar
            IF @IDESTADO_NUEVO = @INC_VALIDADO
            BEGIN
                -- Ejecutamos el motor. Nota: El motor devuelve su propio SELECT 'OK' al final.
                -- Para evitar doble SELECT, capturamos el resultado o simplemente retornamos tras su ejecuci�n.
                EXEC dbo.SPQ_INC_MOTOR_LIQUIDACION @IDINCAPACIDAD = @IDINCAPACIDAD;
                IF @@TRANCOUNT > 0 COMMIT;
                RETURN;
            END

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al cambiar estado: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- CAMBIO 2026-06-02 IVAN -  (auditor ajusta IBC antes de Validado)
    IF @METODO = 'ACTUALIZAR_IBC'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @IBC_NUEVO = CAST(JSON_VALUE(@PARAMETROS, '$.IBC_NUEVO') AS DECIMAL(18,2)),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @IBC_NUEVO IS NULL OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios: IDINCAPACIDAD, IBC_NUEVO, USUARIO.';
            RETURN;
        END

        IF @IBC_NUEVO <= 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El IBC debe ser mayor a cero.';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO, @IBC_ORIGEN_ANTERIOR = IBC_ORIGEN
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad.';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR >= @INC_VALIDADO
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El IBC no puede modificarse: la incapacidad ya fue radicada o se encuentra en un estado posterior.';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR = @INC_DEVUELTO_EMPRESA
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El IBC no puede modificarse por auditor: la incapacidad fue devuelta a la empresa.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IBC = @IBC_NUEVO,
                IBC_ORIGEN = 'MANUAL'
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @IDESTADO_ANTERIOR,
                @IDESTADO_ANTERIOR,
                'ACTUALIZAR_IBC',
                'IBC actualizado manualmente a ' + CAST(@IBC_NUEVO AS VARCHAR(30))
                    + '. Origen anterior: ' + ISNULL(@IBC_ORIGEN_ANTERIOR, '(sin origen)')
                    + '. Por: ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al actualizar IBC: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: CORREGIR_INCA (cliente corrige registro devuelto a empresa)
    IF @METODO = 'CORREGIR_INCA'
    BEGIN

        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @TIPO_DOCUMENTO = JSON_VALUE(@PARAMETROS, '$.TIPO_DOCUMENTO'),
            @NUMERO_DOCUMENTO = JSON_VALUE(@PARAMETROS, '$.NUMERO_DOCUMENTO'),
            @PRIMER_NOMBRE = JSON_VALUE(@PARAMETROS, '$.PRIMER_NOMBRE'),
            @SEGUNDO_NOMBRE = JSON_VALUE(@PARAMETROS, '$.SEGUNDO_NOMBRE'),
            @PRIMER_APELLIDO = JSON_VALUE(@PARAMETROS, '$.PRIMER_APELLIDO'),
            @SEGUNDO_APELLIDO = JSON_VALUE(@PARAMETROS, '$.SEGUNDO_APELLIDO'),
            @IDEPS = JSON_VALUE(@PARAMETROS, '$.IDEPS'),
            @IDIPS = JSON_VALUE(@PARAMETROS, '$.IDIPS'),
            @FECHA_INICIO = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_INICIO') AS DATE),
            @DIAS_INCAPACIDAD = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.DIAS_INCAPACIDAD') AS SMALLINT),
            @DIAGNOSTICO = JSON_VALUE(@PARAMETROS, '$.DIAGNOSTICO'),
            @ORIGEN = JSON_VALUE(@PARAMETROS, '$.ORIGEN'),
            @TIPO_LM = JSON_VALUE(@PARAMETROS, '$.TIPO_LM'),
            @PRORROGA = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.PRORROGA') AS BIT), 0),
            @IBC = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IBC') AS DECIMAL(18,2)),
            @TIPO_COTIZANTE = JSON_VALUE(@PARAMETROS, '$.TIPO_COTIZANTE');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @FECHA_INICIO IS NULL OR @DIAS_INCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios (IDINCAPACIDAD, FECHA_INICIO, DIAS_INCAPACIDAD)';
            RETURN;
        END

        SELECT @IDESTADO_ACTUAL = i.IDESTADO,
            @EDITABLE_CLIENTE = e.EDITABLE_CLIENTE
        FROM dbo.INCA i
        INNER JOIN dbo.INC_ESTADO e ON i.IDESTADO = e.IDESTADO
        WHERE i.IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ACTUAL IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ACTUAL <> @INC_DEVUELTO_EMPRESA OR @EDITABLE_CLIENTE <> 1
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Solo se pueden corregir registros en estado Devuelto a Empresa';
            RETURN;
        END

        -- Validaciones Especiales (SIMILARES AL CARGA_LOTE)
        IF (@ORIGEN = 'MATERNIDAD' AND ISNULL(@TIPO_LM, '') NOT IN ('NORMAL', 'PREMATURO', 'MULTIPLE'))
            OR (ISNULL(@ORIGEN, '') <> 'MATERNIDAD' AND ISNULL(@TIPO_LM, '') <> '')
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Val. Maternidad: Si el Origen es MATERNIDAD, el Tipo de Licencia debe ser NORMAL, PREMATURO o MULTIPLE. Si no, debe estar vac�o.';
            RETURN;
        END

        IF UPPER(TRIM(ISNULL(@ORIGEN, ''))) IN ('MATERNIDAD', 'PATERNIDAD')
        BEGIN
            DECLARE @ErrDiasLM_Corr VARCHAR(300);
            SELECT @ErrDiasLM_Corr = V.MENSAJE
            FROM dbo.FNK_INC_VALIDAR_DIAS_LM(@ORIGEN, @TIPO_LM, @DIAS_INCAPACIDAD) V
            WHERE V.ES_VALIDO = 0;

            IF @ErrDiasLM_Corr IS NOT NULL
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = @ErrDiasLM_Corr;
                RETURN;
            END
        END

        IF NULLIF(LTRIM(RTRIM(@DIAGNOSTICO)), '') IS NOT NULL
        BEGIN
            SELECT @IDDX = IDDX
            FROM dbo.MDX
            WHERE IDDX = NULLIF(LTRIM(RTRIM(@DIAGNOSTICO)), '') AND ESTADO = 'Activo';

            IF @IDDX IS NULL
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Val. Diagn�stico: El c�digo CIE10 (' + ISNULL(@DIAGNOSTICO, 'Vacio') + ') no existe o est� Inactivo.';
                RETURN;
            END
        END

        SET @FECHA_FIN = DATEADD(DAY, @DIAS_INCAPACIDAD - 1, @FECHA_INICIO);

        IF ISNULL(LTRIM(RTRIM(@TIPO_DOCUMENTO)), '') = '' OR ISNULL(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Tipo y n�mero de documento son obligatorios.';
            RETURN;
        END

        IF ISNULL(LTRIM(RTRIM(@IDEPS)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La EPS es obligatoria.';
            RETURN;
        END

        IF ISNULL(LTRIM(RTRIM(@IDIPS)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La IPS es obligatoria.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TER
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATCONTRATANTE')
                AND TX.ESTADO = 'Activo'
            WHERE TER.IDTERCERO = NULLIF(LTRIM(RTRIM(@IDEPS)), '')
                AND TER.ESTADO = 'Activo'
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'EPS no v�lida.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TER
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATIPS')
                AND TX.ESTADO = 'Activo'
            WHERE TER.IDTERCERO = NULLIF(LTRIM(RTRIM(@IDIPS)), '')
                AND TER.ESTADO = 'Activo'
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'IPS no v�lida.';
            RETURN;
        END

        -- Un certificado (tipo doc + n�mero + fecha inicio) no puede existir dos veces en el sistema
        IF EXISTS (
            SELECT 1
            FROM dbo.INCA I
            INNER JOIN dbo.INC_AFILIADO AF ON AF.IDAFILIADO = I.IDAFILIADO
            WHERE AF.TIPO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@TIPO_DOCUMENTO)), '')
                AND AF.NUMERO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), '')
                AND I.FECHA_INICIO = @FECHA_INICIO
                AND I.IDINCAPACIDAD <> @IDINCAPACIDAD
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Ya existe una incapacidad registrada con el mismo Tipo documento, N�mero y Fecha inicio. No se permite duplicar el certificado ni la pr�rroga con la misma fecha; utilice el flujo de correcci�n o devoluci�n.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            -- En INC_AFILIADO actualizamos los datos b�sicos si la correcci�n incluy� cambios de nombre
            -- Obtener primero el IDAFILIADO
            DECLARE @IDAFILIADO_CORREGIR INT;
            SELECT @IDAFILIADO_CORREGIR = IDAFILIADO FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            UPDATE dbo.INC_AFILIADO
            SET TIPO_DOCUMENTO = ISNULL(NULLIF(LTRIM(RTRIM(@TIPO_DOCUMENTO)), ''), TIPO_DOCUMENTO),
                NUMERO_DOCUMENTO = ISNULL(NULLIF(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), ''), NUMERO_DOCUMENTO),
                PRIMER_NOMBRE = ISNULL(NULLIF(LTRIM(RTRIM(@PRIMER_NOMBRE)), ''), PRIMER_NOMBRE),
                SEGUNDO_NOMBRE = ISNULL(NULLIF(LTRIM(RTRIM(@SEGUNDO_NOMBRE)), ''), SEGUNDO_NOMBRE),
                PRIMER_APELLIDO = ISNULL(NULLIF(LTRIM(RTRIM(@PRIMER_APELLIDO)), ''), PRIMER_APELLIDO),
                SEGUNDO_APELLIDO = ISNULL(NULLIF(LTRIM(RTRIM(@SEGUNDO_APELLIDO)), ''), SEGUNDO_APELLIDO),
                IDEPS_ULTIMA = ISNULL(NULLIF(LTRIM(RTRIM(@IDEPS)), ''), IDEPS_ULTIMA),
                IBC_ULTIMO = ISNULL(@IBC, IBC_ULTIMO)
            WHERE IDAFILIADO = @IDAFILIADO_CORREGIR;

            -- En INCA solo actualizamos datos del evento de la incapacidad
            UPDATE dbo.INCA
            SET IDEPS = NULLIF(LTRIM(RTRIM(@IDEPS)), ''),
                IDIPS = NULLIF(LTRIM(RTRIM(@IDIPS)), ''),
                FECHA_INICIO = @FECHA_INICIO,
                DIAS_INCAPACIDAD = @DIAS_INCAPACIDAD,
                FECHA_FIN = @FECHA_FIN,
                IDDX = @IDDX,
                ORIGEN = NULLIF(LTRIM(RTRIM(@ORIGEN)), ''),
                TIPO_LM = NULLIF(LTRIM(RTRIM(@TIPO_LM)), ''),
                PRORROGA = @PRORROGA,
                IBC = @IBC,
                TIPO_COTIZANTE = ISNULL(NULLIF(LTRIM(RTRIM(@TIPO_COTIZANTE)), ''), 'DEPENDIENTE'),
                IDESTADO = @INC_SUBSANADO
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @INC_DEVUELTO_EMPRESA,
                @INC_SUBSANADO,
                'CORREGIDO_CLIENTE',
                'Correcci�n realizada por ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al guardar correcci�n: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: ACTUALIZAR_INCA (edici�n interna/empresa en estados previos a revisi�n/validado)
    -- Estados: 1 Ingresada interno, 2 Ingresada externo, 5 Subsanado.
    -- No cambia IDESTADO. Empresa (IDTERCERO del lote) no se modifica.
    IF @METODO = 'ACTUALIZAR_INCA'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @TIPO_DOCUMENTO = JSON_VALUE(@PARAMETROS, '$.TIPO_DOCUMENTO'),
            @NUMERO_DOCUMENTO = JSON_VALUE(@PARAMETROS, '$.NUMERO_DOCUMENTO'),
            @PRIMER_NOMBRE = JSON_VALUE(@PARAMETROS, '$.PRIMER_NOMBRE'),
            @SEGUNDO_NOMBRE = JSON_VALUE(@PARAMETROS, '$.SEGUNDO_NOMBRE'),
            @PRIMER_APELLIDO = JSON_VALUE(@PARAMETROS, '$.PRIMER_APELLIDO'),
            @SEGUNDO_APELLIDO = JSON_VALUE(@PARAMETROS, '$.SEGUNDO_APELLIDO'),
            @IDEPS = JSON_VALUE(@PARAMETROS, '$.IDEPS'),
            @IDIPS = JSON_VALUE(@PARAMETROS, '$.IDIPS'),
            @FECHA_INICIO = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_INICIO') AS DATE),
            @DIAS_INCAPACIDAD = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.DIAS_INCAPACIDAD') AS SMALLINT),
            @DIAGNOSTICO = JSON_VALUE(@PARAMETROS, '$.DIAGNOSTICO'),
            @ORIGEN = JSON_VALUE(@PARAMETROS, '$.ORIGEN'),
            @TIPO_LM = JSON_VALUE(@PARAMETROS, '$.TIPO_LM'),
            @PRORROGA = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.PRORROGA') AS BIT), 0),
            @IBC = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.IBC') AS DECIMAL(18,2)),
            @TIPO_COTIZANTE = JSON_VALUE(@PARAMETROS, '$.TIPO_COTIZANTE');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @FECHA_INICIO IS NULL OR @DIAS_INCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios (IDINCAPACIDAD, FECHA_INICIO, DIAS_INCAPACIDAD)';
            RETURN;
        END

        SELECT @IDESTADO_ACTUAL = IDESTADO
        FROM dbo.INCA WITH (UPDLOCK, ROWLOCK)
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ACTUAL IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ACTUAL NOT IN (
            @INC_INGRESADA_INTERNO,
            @INC_INGRESADA_EXTERNO,
            @INC_SUBSANADO
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se pueden editar los datos en el estado actual de la incapacidad.';
            RETURN;
        END

        IF (@ORIGEN = 'MATERNIDAD' AND ISNULL(@TIPO_LM, '') NOT IN ('NORMAL', 'PREMATURO', 'MULTIPLE'))
            OR (ISNULL(@ORIGEN, '') <> 'MATERNIDAD' AND ISNULL(@TIPO_LM, '') <> '')
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Val. Maternidad: Si el Origen es MATERNIDAD, el Tipo de Licencia debe ser NORMAL, PREMATURO o MULTIPLE. Si no, debe estar vac�o.';
            RETURN;
        END

        IF UPPER(TRIM(ISNULL(@ORIGEN, ''))) IN ('MATERNIDAD', 'PATERNIDAD')
        BEGIN
            DECLARE @ErrDiasLM_Act VARCHAR(300);
            SELECT @ErrDiasLM_Act = V.MENSAJE
            FROM dbo.FNK_INC_VALIDAR_DIAS_LM(@ORIGEN, @TIPO_LM, @DIAS_INCAPACIDAD) V
            WHERE V.ES_VALIDO = 0;

            IF @ErrDiasLM_Act IS NOT NULL
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = @ErrDiasLM_Act;
                RETURN;
            END
        END

        SET @IDDX = NULL;
        IF NULLIF(LTRIM(RTRIM(@DIAGNOSTICO)), '') IS NOT NULL
        BEGIN
            SELECT @IDDX = IDDX
            FROM dbo.MDX
            WHERE IDDX = NULLIF(LTRIM(RTRIM(@DIAGNOSTICO)), '') AND ESTADO = 'Activo';

            IF @IDDX IS NULL
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Val. Diagn�stico: El c�digo CIE10 (' + ISNULL(@DIAGNOSTICO, 'Vacio') + ') no existe o est� Inactivo.';
                RETURN;
            END
        END

        SET @FECHA_FIN = DATEADD(DAY, @DIAS_INCAPACIDAD - 1, @FECHA_INICIO);

        IF ISNULL(LTRIM(RTRIM(@TIPO_DOCUMENTO)), '') = '' OR ISNULL(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Tipo y n�mero de documento son obligatorios.';
            RETURN;
        END

        IF ISNULL(LTRIM(RTRIM(@IDEPS)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La EPS es obligatoria.';
            RETURN;
        END

        IF ISNULL(LTRIM(RTRIM(@IDIPS)), '') = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La IPS es obligatoria.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TER
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATCONTRATANTE')
                AND TX.ESTADO = 'Activo'
            WHERE TER.IDTERCERO = NULLIF(LTRIM(RTRIM(@IDEPS)), '')
                AND TER.ESTADO = 'Activo'
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'EPS no v�lida.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.TER
            INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATIPS')
                AND TX.ESTADO = 'Activo'
            WHERE TER.IDTERCERO = NULLIF(LTRIM(RTRIM(@IDIPS)), '')
                AND TER.ESTADO = 'Activo'
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'IPS no v�lida.';
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.INCA I
            INNER JOIN dbo.INC_AFILIADO AF ON AF.IDAFILIADO = I.IDAFILIADO
            WHERE AF.TIPO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@TIPO_DOCUMENTO)), '')
                AND AF.NUMERO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), '')
                AND I.FECHA_INICIO = @FECHA_INICIO
                AND I.IDINCAPACIDAD <> @IDINCAPACIDAD
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Ya existe una incapacidad registrada con el mismo Tipo documento, N�mero y Fecha inicio.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            DECLARE @IDAFILIADO_ACT INT;
            SELECT @IDAFILIADO_ACT = IDAFILIADO FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            UPDATE dbo.INC_AFILIADO
            SET TIPO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@TIPO_DOCUMENTO)), ''),
                NUMERO_DOCUMENTO = NULLIF(LTRIM(RTRIM(@NUMERO_DOCUMENTO)), ''),
                PRIMER_NOMBRE = ISNULL(NULLIF(LTRIM(RTRIM(@PRIMER_NOMBRE)), ''), PRIMER_NOMBRE),
                SEGUNDO_NOMBRE = NULLIF(LTRIM(RTRIM(@SEGUNDO_NOMBRE)), ''),
                PRIMER_APELLIDO = ISNULL(NULLIF(LTRIM(RTRIM(@PRIMER_APELLIDO)), ''), PRIMER_APELLIDO),
                SEGUNDO_APELLIDO = NULLIF(LTRIM(RTRIM(@SEGUNDO_APELLIDO)), ''),
                IDEPS_ULTIMA = NULLIF(LTRIM(RTRIM(@IDEPS)), ''),
                IBC_ULTIMO = ISNULL(@IBC, IBC_ULTIMO)
            WHERE IDAFILIADO = @IDAFILIADO_ACT;

            UPDATE dbo.INCA
            SET IDEPS = NULLIF(LTRIM(RTRIM(@IDEPS)), ''),
                IDIPS = NULLIF(LTRIM(RTRIM(@IDIPS)), ''),
                FECHA_INICIO = @FECHA_INICIO,
                DIAS_INCAPACIDAD = @DIAS_INCAPACIDAD,
                FECHA_FIN = @FECHA_FIN,
                IDDX = @IDDX,
                ORIGEN = NULLIF(LTRIM(RTRIM(@ORIGEN)), ''),
                TIPO_LM = NULLIF(LTRIM(RTRIM(@TIPO_LM)), ''),
                PRORROGA = @PRORROGA,
                IBC = @IBC,
                TIPO_COTIZANTE = ISNULL(NULLIF(LTRIM(RTRIM(@TIPO_COTIZANTE)), ''), 'DEPENDIENTE')
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @IDESTADO_ACTUAL,
                @IDESTADO_ACTUAL,
                'ACTUALIZADO_DATOS',
                'Actualizaci�n de datos por ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al actualizar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: REASIGNAR_INCA (asignar incapacidades a un usuario)
    IF @METODO = 'REASIGNAR_INCA'
    BEGIN
        SELECT
            @IDINCAPACIDADES = JSON_QUERY(@PARAMETROS, '$.IDINCAPACIDADES'),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @USUARIO IS NULL OR LTRIM(RTRIM(@USUARIO)) = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Falta el par�metro USUARIO';
            RETURN;
        END

        IF @IDINCAPACIDADES IS NULL OR @IDINCAPACIDADES = '[]'
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Debe seleccionar al menos una incapacidad';
            RETURN;
        END

        -- Insertar IDs en tabla temporal desde el JSON array
        INSERT INTO @Ids (IDINCAPACIDAD)
        SELECT CAST(value AS INT)
        FROM OPENJSON(@IDINCAPACIDADES);

        IF NOT EXISTS (SELECT 1 FROM @Ids)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontraron incapacidades v�lidas para asignar';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET USUARIO_ASIGNADO = @USUARIO
            OUTPUT INSERTED.IDINCAPACIDAD INTO @IdsActualizados
            WHERE IDINCAPACIDAD IN (SELECT IDINCAPACIDAD FROM @Ids)
                AND IDESTADO >= @INC_VALIDADO
                AND IDESTADO < @INC_PAGADA;

            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 'KO' AS OK;
                SELECT ERROR = 'No se pudo asignar. Verifique que las incapacidades est�n en estado entre Validado y Aprobada (antes de Pagada).';
                IF @@TRANCOUNT > 0 ROLLBACK;
                RETURN;
            END

            -- Registrar en INC_LOG (trazabilidad - 1 registro por incapacidad asignada)
            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            SELECT
                NULL,
                i.IDINCAPACIDAD,
                inca.IDESTADO,
                inca.IDESTADO,
                'ASIGNAR_CASO',
                'Asignado a ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            FROM @IdsActualizados i
            INNER JOIN dbo.INCA inca ON inca.IDINCAPACIDAD = i.IDINCAPACIDAD;

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al asignar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: ASIGNAR_UNO_INCA (autoasignar un caso disponible al usuario que hace clic)
    -- Busca una incapacidad con IDESTADO=Validado(6), USUARIO_ASIGNADO NULL
    -- y cuyo lote padre (INC_CARGA) tenga ESTADO_LOTE=1 (activo).
    IF @METODO = 'ASIGNAR_UNO_INCA'
    BEGIN
        SELECT @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @USUARIO IS NULL OR LTRIM(RTRIM(@USUARIO)) = ''
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Falta el par�metro USUARIO';
            RETURN;
        END

        -- Buscar el primer registro disponible en lotes activos
        SELECT TOP 1 @IDINCAPACIDAD = i.IDINCAPACIDAD
        FROM dbo.INCA i
        INNER JOIN dbo.INC_CARGA c ON c.IDCARGA = i.IDCARGA
        WHERE i.IDESTADO = @INC_VALIDADO
            AND (i.USUARIO_ASIGNADO IS NULL OR i.USUARIO_ASIGNADO = '')
            AND c.ESTADO_LOTE = 1
        ORDER BY i.IDINCAPACIDAD ASC;

        IF @IDINCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No hay m�s registros que asignar en lotes activos';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE i
            SET USUARIO_ASIGNADO = @USUARIO
            FROM dbo.INCA i
            INNER JOIN dbo.INC_CARGA c ON c.IDCARGA = i.IDCARGA
            WHERE i.IDINCAPACIDAD = @IDINCAPACIDAD
                AND i.IDESTADO = @INC_VALIDADO
                AND (i.USUARIO_ASIGNADO IS NULL OR i.USUARIO_ASIGNADO = '')
                AND c.ESTADO_LOTE = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK;
                SELECT ERROR = 'No hay m�s registros que asignar en lotes activos';
                RETURN;
            END

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @INC_VALIDADO,
                @INC_VALIDADO,
                'ASIGNAR_CASO',
                'Autoasignado a ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al asignar: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END


    -- METODO: RECHAZAR_RADICADO (Bifurcado)
    IF @METODO = 'RECHAZAR_RADICADO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @TIPO_RECHAZO = JSON_VALUE(@PARAMETROS, '$.TIPO_RECHAZO'),
            @FECHA_NOTIF_RECHAZO_RAD = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_NOTIF_RECHAZO_RAD') AS DATE),
            @CATEGORIA_RECHAZO_RAD = JSON_VALUE(@PARAMETROS, '$.CATEGORIA_RECHAZO_RAD'),
            @MOTIVO_RECHAZO_RAD = JSON_VALUE(@PARAMETROS, '$.MOTIVO_RECHAZO_RAD');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @USUARIO IS NULL OR @TIPO_RECHAZO IS NULL OR @FECHA_NOTIF_RECHAZO_RAD IS NULL OR @CATEGORIA_RECHAZO_RAD IS NULL OR @MOTIVO_RECHAZO_RAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios para el rechazo.';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
        IF @IDESTADO_ANTERIOR IN (12, 9, 10, 11) 
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'No se puede rechazar una incapacidad que ya se encuentra en un estado final (Aprobada, Pagada, etc.).';
            RETURN;
        END

        IF @TIPO_RECHAZO = 'DEFINITIVO'
            SET @IDESTADO_NUEVO = @INC_PENDIENTE_VALIDACION_RECHAZO; -- 8
        ELSE IF @TIPO_RECHAZO = 'RECURRIBLE'
            SET @IDESTADO_NUEVO = @INC_RECHAZO_RECURRIBLE; -- 13
        ELSE
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Tipo de rechazo inv�lido.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @IDESTADO_NUEVO,
                ESTADO_SEMAFORO = 'ROJO',
                FECHA_NOTIF_RECHAZO_RAD = @FECHA_NOTIF_RECHAZO_RAD,
                CATEGORIA_RECHAZO_RAD = @CATEGORIA_RECHAZO_RAD,
                MOTIVO_RECHAZO_RAD = @MOTIVO_RECHAZO_RAD
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL, @IDINCAPACIDAD, @IDESTADO_ANTERIOR, @IDESTADO_NUEVO, 'RECHAZO_RADICADO', 
                'Rechazo (' + @TIPO_RECHAZO + ') registrado por ' + @NOMBRE_USUARIO, @USUARIO, GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = 'Error al registrar el rechazo: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: APROBAR_RECHAZO_DEFINITIVO
    IF @METODO = 'APROBAR_RECHAZO_DEFINITIVO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Faltan par�metros obligatorios.';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
        
        IF @IDESTADO_ANTERIOR <> @INC_PENDIENTE_VALIDACION_RECHAZO
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'La incapacidad no est� pendiente de validaci�n de rechazo.';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @INC_RECHAZO_DEFINITIVO,
                ESTADO_SEMAFORO = 'GRIS'
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL, @IDINCAPACIDAD, @IDESTADO_ANTERIOR, @INC_RECHAZO_DEFINITIVO, 'APROBACION_RECHAZO', 
                'Rechazo definitivo aprobado por ' + @NOMBRE_USUARIO, @USUARIO, GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = 'Error al aprobar rechazo definitivo: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: REVERTIR_RECHAZO
    IF @METODO = 'REVERTIR_RECHAZO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Faltan par�metros obligatorios.';
            RETURN;
        END

        DECLARE @FECHA_RADICADO_TMP DATETIME;
        SELECT @IDESTADO_ANTERIOR = IDESTADO, @FECHA_RADICADO_TMP = FECHA_RADICADO_EPS FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
        
        IF @IDESTADO_ANTERIOR <> @INC_RECHAZO_RECURRIBLE
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Solo se pueden revertir rechazos recurribles.';
            RETURN;
        END

        IF @FECHA_RADICADO_TMP IS NOT NULL AND DATEDIFF(YEAR, @FECHA_RADICADO_TMP, GETDATE()) >= 3
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'No se puede revertir el rechazo. Han pasado m�s de 3 a�os desde la radicaci�n.';
            RETURN;
        END

        DECLARE @NUEVO_SEMAFORO VARCHAR(20) = 'VERDE';
        DECLARE @DiasSLA INT = 0;
        IF @FECHA_RADICADO_TMP IS NOT NULL
        BEGIN
            SET @DiasSLA = DATEDIFF(DAY, @FECHA_RADICADO_TMP, GETDATE());
            IF @DiasSLA > 20 SET @NUEVO_SEMAFORO = 'ROJO';
            ELSE IF @DiasSLA >= 16 SET @NUEVO_SEMAFORO = 'AMARILLO';
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @INC_RADICADO,
                ESTADO_SEMAFORO = @NUEVO_SEMAFORO
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL, @IDINCAPACIDAD, @IDESTADO_ANTERIOR, @INC_RADICADO, 'REVERSION_RECHAZO', 
                'Rechazo revertido por ' + @NOMBRE_USUARIO + '. Vuelve a Radicado.', @USUARIO, GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = 'Error al revertir rechazo: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: REGISTRAR_RADICADO_EPS
    IF @METODO = 'REGISTRAR_RADICADO_EPS'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @NUMERO_RADICADO_EPS = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.NUMERO_RADICADO_EPS'))), ''),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR @NUMERO_RADICADO_EPS IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros: IDINCAPACIDAD y NUMERO_RADICADO_EPS son obligatorios';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR <> @INC_VALIDADO
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Solo se puede registrar radicado en incapacidades con estado Validado';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET NUMERO_RADICADO_EPS = @NUMERO_RADICADO_EPS,
                FECHA_RADICADO_EPS = GETDATE(),
                IDESTADO = @INC_RADICADO,
                ESTADO_SEMAFORO = 'VERDE'
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @INC_VALIDADO,
                @INC_RADICADO,
                'RADICAR_EPS',
                'Radicado EPS: ' + @NUMERO_RADICADO_EPS + ' por ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al registrar radicado: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: OBTENER_DATOS_PAGO (total motor + margen; estado Aprobada antes de Pagada)
    IF @METODO = 'OBTENER_DATOS_PAGO'
    BEGIN
        SELECT @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT);

        IF @IDINCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Falta par�metro IDINCAPACIDAD';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR <> @INC_APROBADA
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Solo se puede consultar datos de pago en estado Aprobada';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM dbo.INC_LIQUIDACION_DIARIA WHERE IDINCAPACIDAD = @IDINCAPACIDAD
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No hay liquidaci�n calculada para esta incapacidad.';
            RETURN;
        END

        SELECT @VALOR_LIQUIDADO_MOTOR = ISNULL(ROUND(SUM(VALOR_TOTAL_LIQUIDADO), 0), 0)
        FROM dbo.INC_LIQUIDACION_DIARIA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        SELECT @ANIO_INCA = YEAR(FECHA_INICIO)
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        SELECT @MARGEN_ERROR_PESOS = MARGEN_ERROR_PESOS
        FROM dbo.INC_PARAMETROS_LEGALES
        WHERE ANIO = @ANIO_INCA
          AND ACTIVO = 1;

        SET @MARGEN_ERROR_PESOS = ISNULL(@MARGEN_ERROR_PESOS, 50000);

        SELECT 'OK' AS OK;
        SELECT
            VALOR_LIQUIDADO_MOTOR = @VALOR_LIQUIDADO_MOTOR,
            MARGEN_ERROR_PESOS = @MARGEN_ERROR_PESOS,
            EPS_SIN_PAGO = CASE WHEN @VALOR_LIQUIDADO_MOTOR <= 0 THEN 1 ELSE 0 END;
        RETURN;
    END

    -- METODO: APROBAR_INCA (Radicado 7 ? Aprobada 9; solo observaci�n)
    IF @METODO = 'APROBAR_INCA'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @OBSERVACION_APROBADA = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.OBSERVACION_APROBADA'))), '');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = '' OR @OBSERVACION_APROBADA IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios: IDINCAPACIDAD, USUARIO y OBSERVACION_APROBADA';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR <> @INC_RADICADO
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Solo se puede aprobar una incapacidad en estado Radicado';
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @INC_APROBADA,
                OBSERVACION_APROBADA = @OBSERVACION_APROBADA,
                ESTADO_SEMAFORO = 'AZUL'
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @IDESTADO_ANTERIOR,
                @INC_APROBADA,
                'APROBAR_INCA',
                'Aprobaci�n: ' + @OBSERVACION_APROBADA + ' - Por: ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al aprobar incapacidad: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: PAGAR_INCA (Aprobada 9 ? Pagada 10; valor EPS + margen vs motor)
    IF @METODO = 'PAGAR_INCA'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @VALOR_PAGADO_EPS = CAST(JSON_VALUE(@PARAMETROS, '$.VALOR_PAGADO_EPS') AS DECIMAL(18,2)),
            @CONFIRMAR_FUERA_MARGEN = CAST(ISNULL(JSON_VALUE(@PARAMETROS, '$.CONFIRMAR_FUERA_MARGEN'), '0') AS BIT);

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        IF @IDINCAPACIDAD IS NULL OR NULLIF(LTRIM(RTRIM(@USUARIO)), '') IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios: IDINCAPACIDAD y USUARIO';
            RETURN;
        END

        IF @VALOR_PAGADO_EPS IS NULL OR @VALOR_PAGADO_EPS < 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Debe ingresar el valor pagado por la EPS (cero o mayor).';
            RETURN;
        END

        SELECT @IDESTADO_ANTERIOR = IDESTADO
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ANTERIOR IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se encontr� la incapacidad';
            RETURN;
        END

        IF @IDESTADO_ANTERIOR <> @INC_APROBADA
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Solo se puede pagar una incapacidad en estado Aprobado';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM dbo.INC_LIQUIDACION_DIARIA WHERE IDINCAPACIDAD = @IDINCAPACIDAD
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No hay liquidaci�n calculada para esta incapacidad.';
            RETURN;
        END

        SELECT @VALOR_LIQUIDADO_MOTOR = ISNULL(ROUND(SUM(VALOR_TOTAL_LIQUIDADO), 0), 0)
        FROM dbo.INC_LIQUIDACION_DIARIA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @VALOR_LIQUIDADO_MOTOR > 0 AND @VALOR_PAGADO_EPS <= 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Debe ingresar el valor pagado por la EPS (mayor a cero).';
            RETURN;
        END

        IF @VALOR_LIQUIDADO_MOTOR <= 0 AND @VALOR_PAGADO_EPS <> 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Seg�n el motor, la EPS no tiene valor a pagar. Registre cero.';
            RETURN;
        END

        SELECT @ANIO_INCA = YEAR(FECHA_INICIO)
        FROM dbo.INCA
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        SELECT @MARGEN_ERROR_PESOS = MARGEN_ERROR_PESOS
        FROM dbo.INC_PARAMETROS_LEGALES
        WHERE ANIO = @ANIO_INCA
            AND ACTIVO = 1;

        SET @MARGEN_ERROR_PESOS = ISNULL(@MARGEN_ERROR_PESOS, 50000);
        SET @DIFERENCIA_APROBACION = ABS(@VALOR_PAGADO_EPS - @VALOR_LIQUIDADO_MOTOR);

        IF @DIFERENCIA_APROBACION > @MARGEN_ERROR_PESOS AND ISNULL(@CONFIRMAR_FUERA_MARGEN, 0) = 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La diferencia entre el valor pagado por la EPS y el liquidado por el motor supera el margen de error permitido.';
            SELECT
                VALOR_LIQUIDADO_MOTOR = @VALOR_LIQUIDADO_MOTOR,
                VALOR_PAGADO_EPS = @VALOR_PAGADO_EPS,
                DIFERENCIA_APROBACION = @DIFERENCIA_APROBACION,
                MARGEN_ERROR_PESOS = @MARGEN_ERROR_PESOS,
                REQUIERE_CONFIRMACION = 1;
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE dbo.INCA
            SET IDESTADO = @INC_PAGADA,
                VALOR_LIQUIDADO_MOTOR = @VALOR_LIQUIDADO_MOTOR,
                VALOR_PAGADO_EPS = @VALOR_PAGADO_EPS,
                DIFERENCIA_APROBACION = @DIFERENCIA_APROBACION,
                FUERA_MARGEN_APROBACION = CASE WHEN @DIFERENCIA_APROBACION > @MARGEN_ERROR_PESOS THEN 1 ELSE 0 END
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

            INSERT INTO dbo.INC_LOG (
                IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA
            )
            VALUES (
                NULL,
                @IDINCAPACIDAD,
                @IDESTADO_ANTERIOR,
                @INC_PAGADA,
                'PAGAR_INCA',
                'Pago registrado. Motor: ' + CAST(@VALOR_LIQUIDADO_MOTOR AS VARCHAR(30))
                    + '. EPS pag�: ' + CAST(@VALOR_PAGADO_EPS AS VARCHAR(30))
                    + '. Diferencia: ' + CAST(@DIFERENCIA_APROBACION AS VARCHAR(30))
                    + '. Margen: ' + CAST(@MARGEN_ERROR_PESOS AS VARCHAR(30))
                    + CASE WHEN @DIFERENCIA_APROBACION > @MARGEN_ERROR_PESOS THEN ' [FUERA DE MARGEN - CONFIRMADO]' ELSE '' END
                    + ' - Por: ' + @NOMBRE_USUARIO,
                @USUARIO,
                GETDATE()
            );

            IF @@TRANCOUNT > 0 COMMIT;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error al pagar la incapacidad: ' + @ErrorMessage;
            RETURN;
        END CATCH
    END

    -- METODO: VER_TRAZABILIDAD
    IF @METODO = 'VER_TRAZABILIDAD'
    BEGIN
        SELECT @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT);

        IF @IDINCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'IDINCAPACIDAD es requerido.';
            RETURN;
        END

        SELECT
            L.IDHISTORIAL,
            L.IDINCAPACIDAD,
            L.ACCION,
            ISNULL(L.OBSERVACION, '') AS OBSERVACION,
            L.USUARIO_ID,
            CONVERT(VARCHAR(20), L.FECHA, 120) AS FECHA,
            ISNULL(E_ANT.NOMBRE, '-') AS ESTADO_ANTERIOR_NOMBRE,
            ISNULL(E_NUE.NOMBRE, '-') AS ESTADO_NUEVO_NOMBRE
        FROM dbo.INC_LOG L
        LEFT JOIN dbo.INC_ESTADO E_ANT ON L.IDESTADO_ANTERIOR = E_ANT.IDESTADO
        LEFT JOIN dbo.INC_ESTADO E_NUE ON L.IDESTADO_NUEVO = E_NUE.IDESTADO
        WHERE L.IDINCAPACIDAD = @IDINCAPACIDAD
        ORDER BY L.FECHA ASC;

        RETURN;
    END

    -- METODO: OBTENER_LIQUIDACION_DETALLE (para el modal premium)
    IF @METODO = 'OBTENER_LIQUIDACION_DETALLE'
    BEGIN
        SELECT @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT);

        IF @IDINCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metro IDINCAPACIDAD';
            RETURN;
        END

        SELECT 'OK' AS OK; -- Primero el estado para el interceptor de la app

        -- 1. Resumen de la Incapacidad Actual
        SELECT 
            I.IDINCAPACIDAD, 
            A.NUMERO_DOCUMENTO, 
            CONCAT_WS(' ', A.PRIMER_NOMBRE, A.SEGUNDO_NOMBRE, A.PRIMER_APELLIDO, A.SEGUNDO_APELLIDO) AS NOMBRE_COMPLETO,
            I.FECHA_INICIO, 
            I.FECHA_FIN, 
            I.DIAS_INCAPACIDAD, 
            I.IBC, 
            I.IDEPS,
            TER_EPS.RAZONSOCIAL AS EPS_NOMBRE,
            I.ORIGEN,
            I.TIPO_COTIZANTE,
            I.PRORROGA AS ES_PRORROGA_USER,
            I.ID_ANTECESOR,
            E.NOMBRE AS ESTADO_NOMBRE
        FROM dbo.INCA I
        INNER JOIN dbo.INC_AFILIADO A ON I.IDAFILIADO = A.IDAFILIADO
        INNER JOIN dbo.INC_ESTADO E ON I.IDESTADO = E.IDESTADO
        LEFT JOIN dbo.TER TER_EPS ON I.IDEPS = TER_EPS.IDTERCERO
        WHERE I.IDINCAPACIDAD = @IDINCAPACIDAD;

        -- 2. Desglose Mensual (Prorrateo Comercial de 30 d�as - Slots)
        SELECT 
            MES_CONTABLE, 
            ANIO_CONTABLE, 
            COUNT(*) AS DIAS_TOTALES,
            SUM(CASE WHEN ENTIDAD_PAGADORA = 'EMPRESA' THEN 1 ELSE 0 END) AS DIAS_EMPRESA,
            SUM(CASE WHEN ENTIDAD_PAGADORA = 'TRASLAPE' THEN 1 ELSE 0 END) AS DIAS_TRASLAPADOS,
            SUM(CASE WHEN ENTIDAD_PAGADORA NOT IN ('EMPRESA', 'TRASLAPE') AND VALOR_TOTAL_LIQUIDADO > 0 THEN 1 ELSE 0 END) AS DIAS_COBRADOS,
            MAX(VALOR_IBC_DIA) AS IBC_DIA,
            MAX(PORCENTAJE_APLICADO) AS PORCENTAJE,
            ROUND(SUM(VALOR_PAGADO_EMPRESA), 0) AS TOTAL_EMPRESA,
            ROUND(SUM(VALOR_PAGADO_EPS), 0) AS TOTAL_EPS,
            ROUND(SUM(VALOR_APORTE_SALUD_8), 0) AS TOTAL_SALUD,
            ROUND(SUM(VALOR_TOTAL_LIQUIDADO), 0) AS TOTAL_NETO,
            CAST(MAX(CASE WHEN ENTIDAD_PAGADORA = 'TRASLAPE' THEN 1 ELSE 0 END) AS BIT) AS TIENE_TRASLAPE
        FROM dbo.INC_LIQUIDACION_DIARIA LD
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD
        GROUP BY ANIO_CONTABLE, MES_CONTABLE
        ORDER BY ANIO_CONTABLE, MES_CONTABLE;

        -- 3. Cadena de Pr�rrogas (Trazabilidad Recursiva)
        ;WITH Cadena(IDINCAPACIDAD, ID_ANTECESOR, FECHA_INICIO, FECHA_FIN, DIAS, NIVEL) AS (
            SELECT IDINCAPACIDAD, ID_ANTECESOR, FECHA_INICIO, FECHA_FIN, DIAS_INCAPACIDAD, 0
            FROM dbo.INCA
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD
            UNION ALL
            SELECT I.IDINCAPACIDAD, I.ID_ANTECESOR, I.FECHA_INICIO, I.FECHA_FIN, I.DIAS_INCAPACIDAD, C.NIVEL + 1
            FROM dbo.INCA I
            INNER JOIN Cadena C ON I.IDINCAPACIDAD = C.ID_ANTECESOR
        )
        SELECT * FROM Cadena ORDER BY NIVEL DESC; -- De la m�s vieja a la actual

        RETURN;
    END

    IF @METODO = 'GUARDAR_PARAMETRO_LEGAL'
    BEGIN
        SELECT 
            @IDPARAMETRO_INC = NULLIF(JSON_VALUE(@PARAMETROS, '$.IDPARAMETRO'), ''),
            @ANIO_INC = JSON_VALUE(@PARAMETROS, '$.ANIO'),
            @SMMLV_INC = JSON_VALUE(@PARAMETROS, '$.SMMLV'),
            @MARGEN_ERROR_PESOS_INC = CAST(JSON_VALUE(@PARAMETROS, '$.MARGEN_ERROR_PESOS') AS DECIMAL(18,2));

        IF @ANIO_INC IS NULL OR @SMMLV_INC IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'A�o y valor de SMMLV son obligatorios.';
            RETURN;
        END

        IF @MARGEN_ERROR_PESOS_INC IS NULL OR @MARGEN_ERROR_PESOS_INC < 0
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'El margen de error en pesos debe ser mayor o igual a cero.';
            RETURN;
        END

        BEGIN TRANSACTION;
        BEGIN TRY
            IF @IDPARAMETRO_INC IS NOT NULL
               AND EXISTS (SELECT 1 FROM dbo.INC_PARAMETROS_LEGALES WHERE IDPARAMETRO = @IDPARAMETRO_INC)
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM dbo.INC_PARAMETROS_LEGALES
                    WHERE ANIO = @ANIO_INC
                      AND IDPARAMETRO <> @IDPARAMETRO_INC
                )
                BEGIN
                    ROLLBACK TRANSACTION;
                    SELECT 'KO' AS OK, ERROR = 'Ya existe un par�metro legal para el a�o indicado.';
                    RETURN;
                END

                UPDATE dbo.INC_PARAMETROS_LEGALES
                SET ANIO = @ANIO_INC,
                    SMMLV = @SMMLV_INC,
                    MARGEN_ERROR_PESOS = @MARGEN_ERROR_PESOS_INC
                WHERE IDPARAMETRO = @IDPARAMETRO_INC;
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1 FROM dbo.INC_PARAMETROS_LEGALES WHERE ANIO = @ANIO_INC)
                BEGIN
                    ROLLBACK TRANSACTION;
                    SELECT 'KO' AS OK, ERROR = 'Ya existe un par�metro legal para el a�o indicado.';
                    RETURN;
                END

                INSERT INTO dbo.INC_PARAMETROS_LEGALES (ANIO, SMMLV, MARGEN_ERROR_PESOS, ACTIVO)
                VALUES (@ANIO_INC, @SMMLV_INC, @MARGEN_ERROR_PESOS_INC, 1);
            END

            COMMIT TRANSACTION;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SELECT 'KO' AS OK, ERROR = 'Error al guardar par�metro: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    IF @METODO = 'ELIMINAR_PARAMETRO_LEGAL'
    BEGIN
        SELECT @IDPARAMETRO_INC = CAST(JSON_VALUE(@PARAMETROS, '$.IDPARAMETRO') AS INT);

        IF @IDPARAMETRO_INC IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Falta par�metro IDPARAMETRO.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.INC_PARAMETROS_LEGALES WHERE IDPARAMETRO = @IDPARAMETRO_INC AND ACTIVO = 1)
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'No se encontr� el par�metro legal o ya fue eliminado.';
            RETURN;
        END

        UPDATE dbo.INC_PARAMETROS_LEGALES
        SET ACTIVO = 0
        WHERE IDPARAMETRO = @IDPARAMETRO_INC;

        SELECT 'OK' AS OK;
        RETURN;
    END

    IF @METODO = 'LIMPIAR_TABLAS'
    BEGIN
        BEGIN TRANSACTION;
        BEGIN TRY
            -- Hijas de INCA primero (orden de FKs)
            DELETE FROM dbo.INC_DEVOLUCION_DET;
            DELETE FROM dbo.INC_INCAPACIDAD_ADJUNTO;
            DELETE FROM dbo.INC_LIQUIDACION_DIARIA;
            DELETE FROM dbo.INC_LOG;

            DELETE FROM dbo.INCA;
            DELETE FROM dbo.INC_CARGA;
            DELETE FROM dbo.INC_AFILIADO;

            -- Credenciales de portales
            DELETE FROM dbo.INC_CREDENCIAL_LOG;
            DELETE FROM dbo.INC_CREDENCIAL;

            -- PILA
            DELETE FROM dbo.PILA_DETALLE;
            DELETE FROM dbo.PILA_EMPRESA;
            DELETE FROM dbo.PILA_CARGA;

            -- No se tocan cat�logos/configuraci�n:
            -- INC_ESTADO, INC_PARAMETROS_LEGALES, INCA_OPTION, PILA_OPERADOR_CONFIG

            COMMIT TRANSACTION;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SELECT 'KO' AS OK, ERROR = 'Error al limpiar tablas: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    IF @METODO = 'ACTIVACION_LOTE'
    BEGIN
        SELECT
            @PROCESO         = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
            @IDCARGA_ACTIVAR = CAST(JSON_VALUE(@PARAMETROS, '$.IDCARGA') AS INT),
            @USUARIO         = JSON_VALUE(@PARAMETROS, '$.USUARIO');

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);


        IF UPPER(@PROCESO) = 'ACTIVAR'
        BEGIN
            IF @IDCARGA_ACTIVAR IS NULL OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Faltan par�metros para activar el lote.';
                RETURN;
            END

            BEGIN TRAN;
            BEGIN TRY
                UPDATE dbo.INC_CARGA
                SET ESTADO_LOTE       = 1,
                    USUARIO_ACTIVACION = @USUARIO,
                    FECHA_ACTIVACION   = GETDATE()
                WHERE IDCARGA = @IDCARGA_ACTIVAR
                    AND ESTADO_LOTE = 0;

                IF @@ROWCOUNT = 0
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK;
                    SELECT 'KO' AS OK, ERROR = 'El lote no se encontr� o ya est� activo.';
                    RETURN;
                END

                INSERT INTO dbo.INC_LOG (IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA)
                VALUES (@IDCARGA_ACTIVAR, NULL, NULL, NULL, 'ACTIVACION_LOTE',
                        CONCAT('Lote activado por ', @NOMBRE_USUARIO, '.'),
                        @USUARIO, GETDATE());

                COMMIT;
                SELECT 'OK' AS OK;
                RETURN;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error al activar el lote: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH
        END

        IF UPPER(@PROCESO) = 'ELIMINAR'
        BEGIN
            IF @IDCARGA_ACTIVAR IS NULL
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Falta el IDCARGA para eliminar el lote.';
                RETURN;
            END

            IF NOT EXISTS (
                SELECT 1 FROM dbo.INC_CARGA
                WHERE IDCARGA = @IDCARGA_ACTIVAR AND ESTADO_LOTE = 0
            )
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Solo se pueden eliminar lotes inactivos. Active o elimine desde la interfaz seg�n corresponda.';
                RETURN;
            END

            BEGIN TRAN;
            BEGIN TRY

                DECLARE @AfiliadosLote TABLE (IDAFILIADO INT PRIMARY KEY);

                INSERT INTO @AfiliadosLote (IDAFILIADO)
                SELECT DISTINCT IDAFILIADO
                FROM dbo.INCA
                WHERE IDCARGA = @IDCARGA_ACTIVAR;

                DELETE FROM dbo.INC_DEVOLUCION_DET
                WHERE IDINCAPACIDAD IN (SELECT IDINCAPACIDAD FROM dbo.INCA WHERE IDCARGA = @IDCARGA_ACTIVAR);

                DELETE FROM dbo.INC_INCAPACIDAD_ADJUNTO
                WHERE IDINCAPACIDAD IN (SELECT IDINCAPACIDAD FROM dbo.INCA WHERE IDCARGA = @IDCARGA_ACTIVAR);

                DELETE FROM dbo.INC_LIQUIDACION_DIARIA
                WHERE IDINCAPACIDAD IN (SELECT IDINCAPACIDAD FROM dbo.INCA WHERE IDCARGA = @IDCARGA_ACTIVAR);

                DELETE FROM dbo.INC_LOG
                WHERE IDINCAPACIDAD IN (SELECT IDINCAPACIDAD FROM dbo.INCA WHERE IDCARGA = @IDCARGA_ACTIVAR);

                DELETE FROM dbo.INC_LOG
                WHERE IDCARGA = @IDCARGA_ACTIVAR;

                DELETE FROM dbo.INCA
                WHERE IDCARGA = @IDCARGA_ACTIVAR;

                DELETE A
                FROM dbo.INC_AFILIADO A
                INNER JOIN @AfiliadosLote AL ON A.IDAFILIADO = AL.IDAFILIADO
                WHERE NOT EXISTS (
                    SELECT 1 FROM dbo.INCA I WHERE I.IDAFILIADO = A.IDAFILIADO
                );

                DELETE FROM dbo.INC_CARGA
                WHERE IDCARGA = @IDCARGA_ACTIVAR;

                IF @@ROWCOUNT = 0
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK;
                    SELECT 'KO' AS OK, ERROR = 'No se encontr� el lote (IDCARGA: ' + CAST(@IDCARGA_ACTIVAR AS VARCHAR) + ') para eliminar.';
                    RETURN;
                END

                COMMIT;
                SELECT 'OK' AS OK;
                RETURN;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error al eliminar el lote: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH
        END

        SELECT 'KO' AS OK, ERROR = 'PROCESO no reconocido dentro de ACTIVACION_LOTE: ' + ISNULL(@PROCESO, '(null)');
        RETURN;
    END

    -- METODO: REGISTRAR_INDIVIDUAL (Registro individual con devoluci�n de ID)
    IF @METODO = 'REGISTRAR_INDIVIDUAL'
    BEGIN
        SELECT
            @IDTERCERO = JSON_VALUE(@PARAMETROS, '$.IDTERCERO'),
            @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
            @DETALLE = CONCAT('[', @PARAMETROS, ']'), -- Convertir el objeto a array de 1 elemento
            @IDESTADO_INICIAL = CAST(JSON_VALUE(@PARAMETROS, '$.IDESTADO_INICIAL') AS INT);

        SELECT @NOMBRE_USUARIO = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO;
        SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

        DECLARE @ErroresIncaInd TABLE (
            TIPO_DOCUMENTO VARCHAR(10) NULL,
            NUMERO_DOCUMENTO VARCHAR(20) NULL,
            DESCRIPCION_ERROR VARCHAR(500)
        );

        IF ISNULL(TRIM(@IDTERCERO), '') = '' OR ISNULL(TRIM(@USUARIO), '') = '' OR @IDESTADO_INICIAL IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros obligatorios.';
            RETURN;
        END

        -- 1. Parsear el JSON a tabla temporal
        SELECT
            T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO,
            NULLIF(TRIM(T.PRIMER_NOMBRE), '') AS PRIMER_NOMBRE,
            NULLIF(TRIM(T.SEGUNDO_NOMBRE), '') AS SEGUNDO_NOMBRE,
            NULLIF(TRIM(T.PRIMER_APELLIDO), '') AS PRIMER_APELLIDO,
            NULLIF(TRIM(T.SEGUNDO_APELLIDO), '') AS SEGUNDO_APELLIDO,
            NULLIF(TRIM(T.IDEPS), '') AS IDEPS,
            NULLIF(TRIM(T.IDIPS), '') AS IDIPS,
            T.IBC, T.FECHA_INICIO, T.DIAS_INCAPACIDAD,
            T.DIAGNOSTICO AS CODIGO_CIE10,
            T.ORIGEN, T.TIPO_LM,
            ISNULL(T.PRORROGA, 0) AS PRORROGA,
            ISNULL(T.TIPO_COTIZANTE, 'DEPENDIENTE') AS TIPO_COTIZANTE,
            CAST(NULL AS INT) AS IDAFILIADO,
            CAST(NULL AS VARCHAR(10)) AS IDDX
        INTO #INCA_TMP_IND
        FROM OPENJSON(@DETALLE)
        WITH (
            TIPO_DOCUMENTO VARCHAR(10) '$.TIPO_DOCUMENTO',
            NUMERO_DOCUMENTO VARCHAR(20) '$.NUMERO_DOCUMENTO',
            PRIMER_NOMBRE VARCHAR(100) '$.PRIMER_NOMBRE',
            SEGUNDO_NOMBRE VARCHAR(100) '$.SEGUNDO_NOMBRE',
            PRIMER_APELLIDO VARCHAR(100) '$.PRIMER_APELLIDO',
            SEGUNDO_APELLIDO VARCHAR(100) '$.SEGUNDO_APELLIDO',
            IDEPS VARCHAR(20) '$.IDEPS',
            IDIPS VARCHAR(20) '$.IDIPS',
            IBC DECIMAL(18,2) '$.IBC',
            FECHA_INICIO DATE '$.FECHA_INICIO',
            DIAS_INCAPACIDAD SMALLINT '$.DIAS_INCAPACIDAD',
            DIAGNOSTICO VARCHAR(10) '$.DIAGNOSTICO',
            ORIGEN VARCHAR(50) '$.ORIGEN',
            TIPO_LM VARCHAR(20) '$.TIPO_LM',
            PRORROGA BIT '$.PRORROGA',
            TIPO_COTIZANTE VARCHAR(20) '$.TIPO_COTIZANTE'
        ) AS T;

        -- 2. Validaciones
        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'El Tipo de documento es obligatorio.' FROM #INCA_TMP_IND WHERE ISNULL(LTRIM(RTRIM(TIPO_DOCUMENTO)), '') = '';

        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'La EPS es obligatoria.'
        FROM #INCA_TMP_IND
        WHERE ISNULL(LTRIM(RTRIM(IDEPS)), '') = '';

        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'La IPS es obligatoria.'
        FROM #INCA_TMP_IND
        WHERE ISNULL(LTRIM(RTRIM(IDIPS)), '') = '';

        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT TIPO_DOCUMENTO, NUMERO_DOCUMENTO, 'Campos obligatorios incompletos: Documento, Fecha Inicio, D�as (>0), Diagn�stico o Origen.'
        FROM #INCA_TMP_IND
        WHERE ISNULL(NUMERO_DOCUMENTO, '') = '' OR FECHA_INICIO IS NULL OR ISNULL(DIAS_INCAPACIDAD, 0) <= 0 
            OR ISNULL(CODIGO_CIE10, '') = '' OR ISNULL(ORIGEN, '') = '';

        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, V.MENSAJE
        FROM #INCA_TMP_IND T CROSS APPLY dbo.FNK_INC_VALIDAR_DIAS_LM(T.ORIGEN, T.TIPO_LM, T.DIAS_INCAPACIDAD) V WHERE V.ES_VALIDO = 0;

        INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
        SELECT DISTINCT T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, 'Incapacidad ya registrada.'
        FROM #INCA_TMP_IND T INNER JOIN dbo.INC_AFILIADO AF ON AF.TIPO_DOCUMENTO = T.TIPO_DOCUMENTO AND AF.NUMERO_DOCUMENTO = T.NUMERO_DOCUMENTO
        INNER JOIN dbo.INCA I ON I.IDAFILIADO = AF.IDAFILIADO AND I.FECHA_INICIO = T.FECHA_INICIO;

        IF EXISTS (SELECT 1 FROM @ErroresIncaInd)
        BEGIN
            IF OBJECT_ID('tempdb..#INCA_TMP_IND') IS NOT NULL DROP TABLE #INCA_TMP_IND;
            SELECT 'KO' AS OK;
            SELECT TOP 1 ERROR = DESCRIPCION_ERROR FROM @ErroresIncaInd;
            RETURN;
        END

        BEGIN TRAN;
        BEGIN TRY
            UPDATE T SET IDDX = C.IDDX FROM #INCA_TMP_IND T INNER JOIN dbo.MDX C ON T.CODIGO_CIE10 = C.IDDX AND C.ESTADO = 'Activo';
            IF EXISTS (SELECT 1 FROM #INCA_TMP_IND WHERE IDDX IS NULL) BEGIN ROLLBACK; SELECT 'KO' AS OK, ERROR = 'Diagn�stico CIE10 inv�lido.'; RETURN; END

            INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, 'EPS no v�lida.'
            FROM #INCA_TMP_IND T
            WHERE ISNULL(LTRIM(RTRIM(T.IDEPS)), '') <> ''
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.TER
                  INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                      AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATCONTRATANTE')
                      AND TX.ESTADO = 'Activo'
                  WHERE TER.IDTERCERO = T.IDEPS
                      AND TER.ESTADO = 'Activo'
              );

            INSERT INTO @ErroresIncaInd (TIPO_DOCUMENTO, NUMERO_DOCUMENTO, DESCRIPCION_ERROR)
            SELECT T.TIPO_DOCUMENTO, T.NUMERO_DOCUMENTO, 'IPS no v�lida.'
            FROM #INCA_TMP_IND T
            WHERE ISNULL(LTRIM(RTRIM(T.IDIPS)), '') <> ''
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.TER
                  INNER JOIN dbo.TEXCA TX ON TX.IDTERCERO = TER.IDTERCERO
                      AND TX.IDCATEGORIA = DBO.FNK_VALORVARIABLE('TERCATIPS')
                      AND TX.ESTADO = 'Activo'
                  WHERE TER.IDTERCERO = T.IDIPS
                      AND TER.ESTADO = 'Activo'
              );

            IF EXISTS (SELECT 1 FROM @ErroresIncaInd)
            BEGIN
                ROLLBACK;
                IF OBJECT_ID('tempdb..#INCA_TMP_IND') IS NOT NULL DROP TABLE #INCA_TMP_IND;
                SELECT 'KO' AS OK;
                SELECT TOP 1 ERROR = DESCRIPCION_ERROR FROM @ErroresIncaInd;
                RETURN;
            END

            UPDATE T SET IDAFILIADO = A.IDAFILIADO, IBC = ISNULL(T.IBC, A.IBC_ULTIMO)
            FROM #INCA_TMP_IND T INNER JOIN dbo.INC_AFILIADO A ON T.TIPO_DOCUMENTO = A.TIPO_DOCUMENTO AND T.NUMERO_DOCUMENTO = A.NUMERO_DOCUMENTO;

            IF EXISTS (SELECT 1 FROM #INCA_TMP_IND WHERE IDAFILIADO IS NULL AND (PRIMER_NOMBRE IS NULL OR PRIMER_APELLIDO IS NULL))
            BEGIN ROLLBACK; SELECT 'KO' AS OK, ERROR = 'Afiliado Nuevo: Faltan nombres obligatorios.'; RETURN; END

            INSERT INTO dbo.INC_AFILIADO (IDTERCERO, TIPO_DOCUMENTO, NUMERO_DOCUMENTO, PRIMER_NOMBRE, SEGUNDO_NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO, IDEPS_ULTIMA, IBC_ULTIMO)
            SELECT DISTINCT @IDTERCERO, TIPO_DOCUMENTO, NUMERO_DOCUMENTO, PRIMER_NOMBRE, SEGUNDO_NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO, IDEPS, IBC
            FROM #INCA_TMP_IND WHERE IDAFILIADO IS NULL;

            UPDATE T SET IDAFILIADO = A.IDAFILIADO FROM #INCA_TMP_IND T INNER JOIN dbo.INC_AFILIADO A ON T.TIPO_DOCUMENTO = A.TIPO_DOCUMENTO AND T.NUMERO_DOCUMENTO = A.NUMERO_DOCUMENTO WHERE T.IDAFILIADO IS NULL;

            UPDATE A SET PRIMER_NOMBRE = ISNULL(T.PRIMER_NOMBRE, A.PRIMER_NOMBRE), SEGUNDO_NOMBRE = ISNULL(T.SEGUNDO_NOMBRE, A.SEGUNDO_NOMBRE),
                PRIMER_APELLIDO = ISNULL(T.PRIMER_APELLIDO, A.PRIMER_APELLIDO), SEGUNDO_APELLIDO = ISNULL(T.SEGUNDO_APELLIDO, A.SEGUNDO_APELLIDO), IDEPS_ULTIMA = ISNULL(T.IDEPS, A.IDEPS_ULTIMA)
            FROM dbo.INC_AFILIADO A INNER JOIN #INCA_TMP_IND T ON A.IDAFILIADO = T.IDAFILIADO;

            INSERT INTO dbo.INC_CARGA (IDTERCERO, USUARIO_CREACION, FECHA_CREACION, ESTADO_LOTE) VALUES (@IDTERCERO, @USUARIO, GETDATE(), 0);
            SET @IDCARGA = SCOPE_IDENTITY();

            DECLARE @InsertedIncaInd TABLE (IDINCAPACIDAD INT PRIMARY KEY);
            INSERT INTO dbo.INCA (IDCARGA, IDESTADO, IDTERCERO, IDAFILIADO, IDDX, FECHA_INICIO, DIAS_INCAPACIDAD, FECHA_FIN, IDIPS, ORIGEN, TIPO_LM, PRORROGA, IBC, IBC_EXCEL, IDEPS, TIPO_COTIZANTE, USUARIO_CREACION, FECHA_CREACION, IBC_ORIGEN)
            OUTPUT INSERTED.IDINCAPACIDAD INTO @InsertedIncaInd (IDINCAPACIDAD)
            SELECT @IDCARGA, @IDESTADO_INICIAL, @IDTERCERO, T.IDAFILIADO, T.IDDX, T.FECHA_INICIO, T.DIAS_INCAPACIDAD, DATEADD(DAY, T.DIAS_INCAPACIDAD - 1, T.FECHA_INICIO), T.IDIPS, T.ORIGEN, T.TIPO_LM, ISNULL(T.PRORROGA, 0), T.IBC, T.IBC, T.IDEPS, T.TIPO_COTIZANTE, @USUARIO, GETDATE(), 'EXCEL'
            FROM #INCA_TMP_IND T;
            
            DECLARE @IDINC_CREADA INT = (SELECT TOP 1 IDINCAPACIDAD FROM @InsertedIncaInd);

            INSERT INTO dbo.INC_LOG (IDCARGA, IDINCAPACIDAD, IDESTADO_ANTERIOR, IDESTADO_NUEVO, ACCION, OBSERVACION, USUARIO_ID, FECHA)
            VALUES (NULL, @IDINC_CREADA, NULL, @IDESTADO_INICIAL, 'REGISTRO_INDIVIDUAL', 'Registro creado desde frontend', @USUARIO, GETDATE());

            DROP TABLE #INCA_TMP_IND;
            COMMIT;

            SELECT 'OK' AS OK;
            SELECT IDINCAPACIDAD = @IDINC_CREADA;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: ELIMINAR_INCAPACIDAD (Rollback para falla en subida de documentos)
    IF @METODO = 'ELIMINAR_INCAPACIDAD'
    BEGIN
        SELECT @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT);
        IF @IDINCAPACIDAD IS NULL BEGIN SELECT 'KO' AS OK, ERROR='Falta IDINCAPACIDAD'; RETURN; END
        BEGIN TRAN;
        BEGIN TRY
            DELETE FROM dbo.INC_LOG WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
            DECLARE @IDCARGA_DEL INT = (SELECT IDCARGA FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD);
            DELETE FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
            IF @IDCARGA_DEL IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.INCA WHERE IDCARGA = @IDCARGA_DEL)
            BEGIN
                DELETE FROM dbo.INC_CARGA WHERE IDCARGA = @IDCARGA_DEL;
            END
            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: VINCULAR_ADJUNTO (despu�s de SPQ_UPLOAD / INC_DOCUMENTO)
    -- Alta inicial del registro individual. Si ya hay vigente del mismo CODIGO,
    -- lo inactiva (trazabilidad) e inserta el nuevo ACTIVO=1.
    IF @METODO = 'VINCULAR_ADJUNTO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @CODIGO_DOC     = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CODIGO'))), ''),
            @ETIQUETA_DOC   = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ETIQUETA'))), ''),
            @ID_DOCS        = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ID_DOCS') AS UNIQUEIDENTIFIER),
            @IDEPS          = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDEPS'))), ''),
            @IDTERCERO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO'))), ''),
            @USUARIO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), '');

        IF @IDINCAPACIDAD IS NULL OR @CODIGO_DOC IS NULL OR @ETIQUETA_DOC IS NULL
            OR @ID_DOCS IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros: IDINCAPACIDAD, CODIGO, ETIQUETA, ID_DOCS, USUARIO.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.INCA WHERE IDINCAPACIDAD = @IDINCAPACIDAD)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La incapacidad no existe.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.DOCS WHERE DocumentoID = @ID_DOCS)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El documento no existe en DOCS.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            IF COL_LENGTH('dbo.INC_INCAPACIDAD_ADJUNTO', 'ACTIVO') IS NOT NULL
            BEGIN
                UPDATE dbo.INC_INCAPACIDAD_ADJUNTO
                SET ACTIVO = 0,
                    FECHA_INACTIVA = GETDATE(),
                    USUARIO_INACTIVA = @USUARIO
                WHERE IDINCAPACIDAD = @IDINCAPACIDAD
                  AND CODIGO = @CODIGO_DOC
                  AND ISNULL(ACTIVO, 1) = 1;

                INSERT INTO dbo.INC_INCAPACIDAD_ADJUNTO (
                    IDINCAPACIDAD, IDEPS, IDTERCERO, CODIGO, ETIQUETA, ID_DOCS, USUARIO, FECHA_CARGA, ACTIVO
                )
                VALUES (
                    @IDINCAPACIDAD, @IDEPS, @IDTERCERO, @CODIGO_DOC, @ETIQUETA_DOC, @ID_DOCS, @USUARIO, GETDATE(), 1
                );
            END
            ELSE
            BEGIN
                -- Compatibilidad si a�n no se ejecut� ALTER_INC_INCAPACIDAD_ADJUNTO_ACTIVO.sql
                DELETE FROM dbo.INC_INCAPACIDAD_ADJUNTO
                WHERE IDINCAPACIDAD = @IDINCAPACIDAD AND CODIGO = @CODIGO_DOC;

                INSERT INTO dbo.INC_INCAPACIDAD_ADJUNTO (
                    IDINCAPACIDAD, IDEPS, IDTERCERO, CODIGO, ETIQUETA, ID_DOCS, USUARIO, FECHA_CARGA
                )
                VALUES (
                    @IDINCAPACIDAD, @IDEPS, @IDTERCERO, @CODIGO_DOC, @ETIQUETA_DOC, @ID_DOCS, @USUARIO, GETDATE()
                );
            END

            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: REEMPLAZAR_ADJUNTO (edici�n con bloqueo por IDESTADO)
    -- Estados permitidos: 1 Ingresada interno, 2 Ingresada externo,
    -- 4 Devuelto empresa, 5 Subsanado. No 3 ni 6+.
    IF @METODO = 'REEMPLAZAR_ADJUNTO'
    BEGIN
        SELECT
            @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT),
            @CODIGO_DOC     = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CODIGO'))), ''),
            @ETIQUETA_DOC   = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ETIQUETA'))), ''),
            @ID_DOCS        = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ID_DOCS') AS UNIQUEIDENTIFIER),
            @IDEPS          = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDEPS'))), ''),
            @IDTERCERO      = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO'))), ''),
            @USUARIO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), '');

        IF @IDINCAPACIDAD IS NULL OR @CODIGO_DOC IS NULL OR @ETIQUETA_DOC IS NULL
            OR @ID_DOCS IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Faltan par�metros: IDINCAPACIDAD, CODIGO, ETIQUETA, ID_DOCS, USUARIO.';
            RETURN;
        END

        SELECT @IDESTADO_ACTUAL = IDESTADO
        FROM dbo.INCA WITH (UPDLOCK, ROWLOCK)
        WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        IF @IDESTADO_ACTUAL IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'La incapacidad no existe.';
            RETURN;
        END

        IF @IDESTADO_ACTUAL NOT IN (
            @INC_INGRESADA_INTERNO,
            @INC_INGRESADA_EXTERNO,
            @INC_DEVUELTO_EMPRESA,
            @INC_SUBSANADO
        )
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No se pueden modificar documentos en el estado actual de la incapacidad.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.DOCS WHERE DocumentoID = @ID_DOCS)
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El documento no existe en DOCS.';
            RETURN;
        END

        IF OBJECT_ID('dbo.INC_INCAPACIDAD_ADJUNTO', 'U') IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'No existe la tabla INC_INCAPACIDAD_ADJUNTO.';
            RETURN;
        END

        IF COL_LENGTH('dbo.INC_INCAPACIDAD_ADJUNTO', 'ACTIVO') IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Falta columna ACTIVO. Ejecute ALTER_INC_INCAPACIDAD_ADJUNTO_ACTIVO.sql.';
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE dbo.INC_INCAPACIDAD_ADJUNTO
            SET ACTIVO = 0,
                FECHA_INACTIVA = GETDATE(),
                USUARIO_INACTIVA = @USUARIO
            WHERE IDINCAPACIDAD = @IDINCAPACIDAD
              AND CODIGO = @CODIGO_DOC
              AND ISNULL(ACTIVO, 1) = 1;

            INSERT INTO dbo.INC_INCAPACIDAD_ADJUNTO (
                IDINCAPACIDAD, IDEPS, IDTERCERO, CODIGO, ETIQUETA, ID_DOCS, USUARIO, FECHA_CARGA, ACTIVO
            )
            VALUES (
                @IDINCAPACIDAD, @IDEPS, @IDTERCERO, @CODIGO_DOC, @ETIQUETA_DOC, @ID_DOCS, @USUARIO, GETDATE(), 1
            );

            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SELECT 'KO' AS OK;
            SELECT ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- METODO: LISTAR_ADJUNTOS_INCA (solo vigentes)
    IF @METODO = 'LISTAR_ADJUNTOS_INCA'
    BEGIN
        SELECT @IDINCAPACIDAD = CAST(JSON_VALUE(@PARAMETROS, '$.IDINCAPACIDAD') AS INT);

        IF @IDINCAPACIDAD IS NULL
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Falta par�metro IDINCAPACIDAD';
            RETURN;
        END

        IF OBJECT_ID('dbo.INC_INCAPACIDAD_ADJUNTO', 'U') IS NULL
        BEGIN
            SELECT
                CAST(NULL AS INT) AS ID,
                CAST(NULL AS INT) AS IDINCAPACIDAD,
                CAST(NULL AS VARCHAR(50)) AS CODIGO,
                CAST(NULL AS VARCHAR(300)) AS ETIQUETA,
                CAST(NULL AS UNIQUEIDENTIFIER) AS ID_DOCS,
                CAST(NULL AS DATETIME) AS FECHA_CARGA,
                CAST(NULL AS VARCHAR(20)) AS USUARIO,
                CAST(NULL AS BIT) AS ACTIVO,
                CAST(NULL AS VARCHAR(128)) AS DocNombre,
                CAST(NULL AS VARCHAR(10)) AS DocExtension,
                CAST(NULL AS DATETIME) AS DocFechaRegistro
            WHERE 1 = 0;
            RETURN;
        END

        IF COL_LENGTH('dbo.INC_INCAPACIDAD_ADJUNTO', 'ACTIVO') IS NOT NULL
        BEGIN
            SELECT
                A.ID,
                A.IDINCAPACIDAD,
                A.CODIGO,
                A.ETIQUETA,
                A.ID_DOCS,
                A.FECHA_CARGA,
                A.USUARIO,
                A.ACTIVO,
                D.DocNombre,
                D.DocExtension,
                D.DocFechaRegistro
            FROM dbo.INC_INCAPACIDAD_ADJUNTO A
            INNER JOIN dbo.DOCS D ON D.DocumentoID = A.ID_DOCS
            WHERE A.IDINCAPACIDAD = @IDINCAPACIDAD
              AND ISNULL(A.ACTIVO, 1) = 1
            ORDER BY A.FECHA_CARGA ASC, A.ID ASC;
        END
        ELSE
        BEGIN
            SELECT
                A.ID,
                A.IDINCAPACIDAD,
                A.CODIGO,
                A.ETIQUETA,
                A.ID_DOCS,
                A.FECHA_CARGA,
                A.USUARIO,
                CAST(1 AS BIT) AS ACTIVO,
                D.DocNombre,
                D.DocExtension,
                D.DocFechaRegistro
            FROM dbo.INC_INCAPACIDAD_ADJUNTO A
            INNER JOIN dbo.DOCS D ON D.DocumentoID = A.ID_DOCS
            WHERE A.IDINCAPACIDAD = @IDINCAPACIDAD
            ORDER BY A.FECHA_CARGA ASC, A.ID ASC;
        END

        RETURN;
    END

    SELECT 'KO' AS OK;
    SELECT ERROR = 'M�todo no reconocido: ' + ISNULL(@METODO, '(null)');
    SELECT NUMERO_DOCUMENTO = NULL, NUMERO_INCAPACIDAD = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
END;
