CREATE OR ALTER  PROCEDURE [dbo].[SPQ_SIFTR_COL]
    @JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFORMAT DMY;

    DECLARE
        @MODELO           VARCHAR(100),
        @METODO           VARCHAR(100),
        @USUARIO          VARCHAR(20),
        @P                NVARCHAR(MAX),
        @M                VARCHAR(80),
        @IDLOTE           VARCHAR(40)  = NULL,
        @MENSAJE          NVARCHAR(500) = NULL,
        @ESTADO_INI       VARCHAR(20)  = N'CARGADO',
        @INS              INT            = 0,
        @IDSEDE           VARCHAR(6)     = NULL,
        @COMPANIA         VARCHAR(2)     = NULL,
        @SYS_COMPUTERNAME VARCHAR(255)   = NULL,
        @OMIT             INT            = 0,
        @DEL              INT            = NULL,
        @F_IDTERCERO      VARCHAR(20)    = NULL,
        @F_NIT            VARCHAR(20)    = NULL,
        @F_N_FACTURA      VARCHAR(16)    = NULL,
        @F_TIENE_CXC      INT            = NULL,
        @F_PROCESADO      BIT            = NULL,
        @USU_FTR         NVARCHAR(20)  = NULL,
        @REGOK           INT            = 0,
        @REGER           INT            = 0,
        @IDF             INT            = NULL,
        @NF              NVARCHAR(20)  = NULL,
        @FF              DATETIME       = NULL,
        @FV              DATETIME       = NULL,
        @IT              NVARCHAR(20)  = NULL,
        @PL              NVARCHAR(6)   = NULL,
        @TTEC            NVARCHAR(10)  = NULL,
        @CXC             NVARCHAR(16)  = NULL,
        @CXC_R           NVARCHAR(16)  = NULL,
        @SAL             DECIMAL(18, 4) = NULL,
        @CONC            NVARCHAR(512) = NULL,
        @CCOSTO          NVARCHAR(20)  = NULL,
        @IDSERV          NVARCHAR(20)  = NULL,
        @IDAREA          NVARCHAR(20)  = NULL,
        @CNSFCT          VARCHAR(40)    = NULL,
        @MOT             NVARCHAR(500) = NULL,
        @IDTERCERO       VARCHAR(20),
        @DESCSERV        VARCHAR(200),
        @SALDO           DECIMAL(14,2),
        @DV_PPT          SMALLINT       = 30,
        @F_TER_NIT_ID    VARCHAR(20)    = NULL;

    SELECT
        @MODELO  = [MODELO],
        @METODO  = [METODO],
        @USUARIO = NULLIF(LEFT(LTRIM(RTRIM([USUARIO])), 20), N''),
        @P       = [PARAMETROS]
    FROM OPENJSON(@JSON) WITH (
        [MODELO]     VARCHAR(100) N'$.MODELO',
        [METODO]     VARCHAR(100) N'$.METODO',
        [USUARIO]    VARCHAR(20)  N'$.USUARIO',
        [PARAMETROS] NVARCHAR(MAX) N'$.PARAMETROS' AS JSON
    );

    IF @P IS NULL OR LTRIM(RTRIM(@P)) = N''
        SET @P = N'{}';

    SET @M = UPPER(LTRIM(RTRIM(ISNULL(@METODO, N''))));
    IF @USUARIO IS NULL
        SET @USUARIO = SUSER_SNAME();
    IF @M = N''
    BEGIN
        SELECT N'KO' AS [OK], N'METODO vacío.' AS [MENSAJE];
        RETURN;
    END
    SELECT @IDSEDE=COALESCE(UBEQ.IDSEDE,USUSU.IDSEDE),@COMPANIA=COALESCE(UBEQ.COMPANIA,USUSU.COMPANIA),
    @SYS_COMPUTERNAME=COALESCE(USUSU.SYS_ComputerName,HOST_NAME())
    FROM USUSU LEFT JOIN UBEQ ON USUSU.SYS_ComputerName=UBEQ.SYS_ComputerName
     WHERE USUSU.USUARIO=@USUARIO
    /* INSERTAR_LOTE: fechas = texto del JSON; validación estricta con TRY_CONVERT */
    IF @M = 'INSERTAR_LOTE'
    BEGIN
        BEGIN TRY
            IF JSON_QUERY(@P, N'$.DATOS') IS NULL
            BEGIN
                SELECT N'KO' AS [OK], N'PARAMETROS.DATOS no es un arreglo JSON válido.' AS [MENSAJE];
                RETURN;
            END

            SET @IDLOTE     = NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.IDLOTE'))), 40), N'');
            SET @ESTADO_INI = COALESCE(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.ESTADO_INICIAL'))), 20), N'CARGADO');
            IF JSON_VALUE(@P, N'$.USUARIO') IS NOT NULL
                SET @USUARIO = NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.USUARIO'))), 20), N'');
            IF @USUARIO IS NULL
                SET @USUARIO = SUSER_SNAME();

            IF OBJECT_ID(N'tempdb..#SIFTR_LOTE', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_LOTE];

            ;WITH [src] AS (
                SELECT
                    [j].[value],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.N_FACTURA'), N''))), 16), N'') AS [N_FACTURA_RAW],
                    NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE([j].[value], N'$.F_FACTURA'))), 50), N'') AS [F_FACTURA_S],
                    NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE([j].[value], N'$.F_VENCE'))), 50), N'') AS [F_VENCE_S],
                    NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE([j].[value], N'$.F_RADICA'))), 50), N'') AS [F_RADICA_S],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.IDTERCERO'), N''))), 20), N'') AS [IDTERCERO],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.IDPLAN'), N''))), 6), N'') AS [IDPLAN],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.TTEC'), N''))), 10), N'') AS [TTEC],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.CUENTACXC'), N''))), 16), N'') AS [CUENTACXC],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.CUENTACXC_RAD'), N''))), 16), N'') AS [CUENTACXC_RAD],
                    TRY_CONVERT(DECIMAL(14, 2), NULLIF(LTRIM(RTRIM(JSON_VALUE([j].[value], N'$.SALDO'))), N'')) AS [SALDO],
                    LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.CONCEPTO'), N''))), 512) AS [CONCEPTO],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.IDAREA'), N''))), 20), N'') AS [IDAREA],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.CCOSTO'), N''))), 20), N'') AS [CCOSTO],
                    NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.IDSERVICIO'), N''))), 20), N'') AS [IDSERVICIO],
                    LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE([j].[value], N'$.DESCSERVICIO'), N''))), 512) AS [DESCSERVICIO]
                FROM OPENJSON(@P, N'$.DATOS') AS [j]
            )
            /* Normaliza texto fecha: FEFF, barra "fullwidth" (U+FF0F), guión de rango a '-' para TRY_CONVERT. */
            , [norm] AS (
                SELECT
                    s.*,
                    [F_FACTURA_N] = IIF(
                        s.[F_FACTURA_S] IS NULL,
                        NULL,
                        REPLACE(
                            REPLACE(REPLACE(LTRIM(RTRIM(s.[F_FACTURA_S])), NCHAR(0xFEFF), N''), NCHAR(0xFF0F), N'/'),
                            NCHAR(0x2013),
                            N'-'
                        )
                    ),
                    [F_VENCE_N] = IIF(
                        s.[F_VENCE_S] IS NULL,
                        NULL,
                        REPLACE(
                            REPLACE(REPLACE(LTRIM(RTRIM(s.[F_VENCE_S])), NCHAR(0xFEFF), N''), NCHAR(0xFF0F), N'/'),
                            NCHAR(0x2013),
                            N'-'
                        )
                    ),
                    [F_RADICA_N] = IIF(
                        s.[F_RADICA_S] IS NULL,
                        NULL,
                        REPLACE(
                            REPLACE(REPLACE(LTRIM(RTRIM(s.[F_RADICA_S])), NCHAR(0xFEFF), N''), NCHAR(0xFF0F), N'/'),
                            NCHAR(0x2013),
                            N'-'
                        )
                    )
                FROM [src] AS s
            )
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [LINEA],
                s.[N_FACTURA_RAW],
                /* ISO 126/23 primero; 103/105 d-m-y; evitar 120 en cadena d/m/y ambigua. */
                COALESCE(
                    TRY_CONVERT(DATE, s.[F_FACTURA_N], 126),
                    TRY_CONVERT(DATE, s.[F_FACTURA_N], 23),
                    TRY_CONVERT(DATE, s.[F_FACTURA_N], 120),
                    TRY_CONVERT(DATE, s.[F_FACTURA_N], 103),
                    TRY_CONVERT(DATE, REPLACE(s.[F_FACTURA_N], N'/', N'-'), 105)
                ) AS [F_FACTURA],
                COALESCE(
                    TRY_CONVERT(DATE, s.[F_VENCE_N], 126),
                    TRY_CONVERT(DATE, s.[F_VENCE_N], 23),
                    TRY_CONVERT(DATE, s.[F_VENCE_N], 120),
                    TRY_CONVERT(DATE, s.[F_VENCE_N], 103),
                    TRY_CONVERT(DATE, REPLACE(s.[F_VENCE_N], N'/', N'-'), 105)
                ) AS [F_VENCE],
                s.[F_FACTURA_S],
                s.[F_VENCE_S],
                COALESCE(
                    TRY_CONVERT(DATE, s.[F_RADICA_N], 126),
                    TRY_CONVERT(DATE, s.[F_RADICA_N], 23),
                    TRY_CONVERT(DATE, s.[F_RADICA_N], 120),
                    TRY_CONVERT(DATE, s.[F_RADICA_N], 103),
                    TRY_CONVERT(DATE, REPLACE(s.[F_RADICA_N], N'/', N'-'), 105)
                ) AS [F_RADICA],
                s.[F_RADICA_S],
                s.[IDTERCERO], s.[IDPLAN], s.[TTEC],
                s.[CUENTACXC], s.[CUENTACXC_RAD], s.[SALDO], s.[CONCEPTO],
                s.[IDAREA], s.[CCOSTO], s.[IDSERVICIO], s.[DESCSERVICIO]
            INTO [#SIFTR_LOTE]
            FROM [norm] AS s;

            ALTER TABLE [#SIFTR_LOTE] ADD [MOTIVO] NVARCHAR(200) NULL;

            UPDATE [t]
            SET [MOTIVO] = N'F_FACTURA: valor no es una fecha válida (enviar ISO yyyy-mm-dd o equivalente).'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND [t].[F_FACTURA_S] IS NOT NULL
              AND [t].[F_FACTURA] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'F_VENCE: valor no es una fecha válida (enviar ISO yyyy-mm-dd o equivalente).'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND [t].[F_VENCE_S] IS NOT NULL
              AND [t].[F_VENCE] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'F_RADICA: valor no es una fecha válida (enviar ISO yyyy-mm-dd o equivalente).'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND [t].[F_RADICA_S] IS NOT NULL
              AND [t].[F_RADICA] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'N_FACTURA vacía o inválida.'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND [t].[N_FACTURA_RAW] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'F_FACTURA requerida.'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND ([t].[F_FACTURA_S] IS NULL OR [t].[F_FACTURA] IS NULL);

            UPDATE [t]
            SET [MOTIVO] = N'IDTERCERO requerido.'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND ([t].[IDTERCERO] IS NULL OR LTRIM(RTRIM([t].[IDTERCERO])) = N'');

            UPDATE [t]
            SET [MOTIVO] = N'SALDO requerido y debe ser mayor que cero.'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND ([t].[SALDO] IS NULL OR [t].[SALDO] <= 0);

            UPDATE [t]
            SET [MOTIVO] = N'La factura ya existe en FTR (sistema de facturación).'
            FROM [#SIFTR_LOTE] AS [t]
            INNER JOIN [dbo].[FTR] AS [f] ON [f].[N_FACTURA] = [t].[N_FACTURA_RAW]
            WHERE [t].[MOTIVO] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'La factura ya existe en FTR_SI (sistema de facturación SALDO INICIALES).'
            FROM [#SIFTR_LOTE] AS [t]
            INNER JOIN [dbo].[FTR_SI] AS [f] ON [f].[N_FACTURA] = [t].[N_FACTURA_RAW]
            WHERE [t].[MOTIVO] IS NULL;

            UPDATE [t]
            SET [MOTIVO] = N'N_FACTURA duplicada en el lote (misma carga / Excel).'
            FROM [#SIFTR_LOTE] AS [t]
            WHERE [t].[MOTIVO] IS NULL
              AND [t].[N_FACTURA_RAW] IS NOT NULL
              AND EXISTS (
                    SELECT 1
                    FROM [#SIFTR_LOTE] AS [s]
                    WHERE [s].[N_FACTURA_RAW] = [t].[N_FACTURA_RAW]
                      AND [s].[MOTIVO] IS NULL
                      AND [s].[LINEA] < [t].[LINEA]
                );

            SET @OMIT = (SELECT COUNT(1) FROM [#SIFTR_LOTE] WHERE [MOTIVO] IS NOT NULL);

            INSERT INTO [dbo].[FTR_SI] (
                [N_FACTURA], [F_FACTURA], [F_VENCE], [IDTERCERO], [IDPLAN], [TTEC],
                [CUENTACXC], [CUENTACXC_RAD], [SALDO], [F_RADICA], [CONCEPTO],
                [IDAREA], [CCOSTO], [IDSERVICIO], [DESCSERVICIO],
                [IDLOTE], [USUARIO], [FECHACARGA], [PROCESADO], [MENSAJEERROR], [ESTADO]
            )
            SELECT
                [N_FACTURA_RAW], [F_FACTURA], [F_VENCE], [IDTERCERO], [IDPLAN], [TTEC],
                [CUENTACXC], [CUENTACXC_RAD], [SALDO], [F_RADICA], [CONCEPTO],
                [IDAREA], [CCOSTO], [IDSERVICIO], [DESCSERVICIO],
                @IDLOTE, @USUARIO, GETDATE(), 0, NULL, @ESTADO_INI
            FROM [#SIFTR_LOTE]
            WHERE [MOTIVO] IS NULL;

            SET @INS = @@ROWCOUNT;

            SELECT N'OK' AS [OK];

            SELECT
                @INS AS [REGISTROS_INSERTADOS],
                @OMIT AS [REGISTROS_OMITIDOS],
                @IDLOTE AS [IDLOTE],
                CASE
                    WHEN @OMIT > 0 THEN N'Lote cargado con filas omitidas (revise el tercer resultset).'
                    ELSE N'Lote cargado correctamente.'
                END AS [MENSAJE];

            IF @OMIT > 0
                SELECT
                    [LINEA]         AS [LINEA_LOTE],
                    [N_FACTURA_RAW] AS [N_FACTURA],
                    [MOTIVO]        AS [MOTIVO]
                FROM [#SIFTR_LOTE]
                WHERE [MOTIVO] IS NOT NULL
                ORDER BY [LINEA];
        END TRY
        BEGIN CATCH
            SET @MENSAJE = ERROR_MESSAGE();
            SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE], ERROR_NUMBER() AS [SQL_ERR];
        END CATCH

        IF OBJECT_ID(N'tempdb..#SIFTR_LOTE', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_LOTE];
        RETURN;
    END

    IF @M = 'LIMPIAR_NO_PROCESADOS'
    BEGIN
        BEGIN TRY
            SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.IDLOTE'))), 40), N'');
            IF @IDLOTE IS NULL
            BEGIN
                DELETE FROM [dbo].[FTR_SI] WHERE [PROCESADO] = 0;
            END
            ELSE
            BEGIN
                DELETE FROM [dbo].[FTR_SI]
                 WHERE [PROCESADO] = 0 AND [IDLOTE] = @IDLOTE;
            END
            SET @DEL = @@ROWCOUNT;
            SELECT N'OK' AS [OK];
            SELECT @DEL AS [REGISTROS_ELIMINADOS], @IDLOTE AS [IDLOTE], N'Registros no procesados eliminados.' AS [MENSAJE];
        END TRY
        BEGIN CATCH
            SET @MENSAJE = ERROR_MESSAGE();
            SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE], ERROR_NUMBER() AS [SQL_ERR];
        END CATCH
        RETURN;
    END

    IF @M = 'CONSULTAR'
    BEGIN
        SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
        SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
        SET @F_PROCESADO = NULL;
        IF LOWER(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.PROCESADO'), N'')))) IN (N'true', N'1', N'1.0')
            SET @F_PROCESADO = 1;
        IF LOWER(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.PROCESADO'), N'')))) IN (N'false', N'0', N'0.0')
            SET @F_PROCESADO = 0;
        SELECT
            s.[ID], s.[N_FACTURA], s.[F_FACTURA], s.[F_VENCE], s.[IDTERCERO], s.[IDPLAN], s.[TTEC],
            s.[CUENTACXC], s.[CUENTACXC_RAD], s.[SALDO], s.[F_RADICA], s.[CONCEPTO],
            s.[IDAREA], s.[CCOSTO], s.[IDSERVICIO], s.[DESCSERVICIO],
            s.[IDLOTE], s.[USUARIO], s.[FECHACARGA], s.[PROCESADO], s.[MENSAJEERROR],
            s.[ESTADO], s.[CNSFCT], s.[CNSCXC]
        FROM [dbo].[FTR_SI] s
        WHERE (@F_IDTERCERO IS NULL OR s.[IDTERCERO] = @F_IDTERCERO)
          AND (@F_N_FACTURA  IS NULL OR s.[N_FACTURA]  = @F_N_FACTURA)
          AND (@F_PROCESADO  IS NULL OR s.[PROCESADO]  = @F_PROCESADO)
        ORDER BY s.[ID] DESC;
        SELECT N'OK' AS [OK];
        RETURN;
    END

    /* Filas completas de FTR_SI por lista de ID (p. ej. errores de PROCESAR_FTR para Excel de corrección). */
    IF @M = 'CONSULTAR_POR_IDS'
    BEGIN
        IF JSON_QUERY(@P, N'$.IDS') IS NULL
        BEGIN
            SELECT N'KO' AS [OK], N'PARAMETROS.IDS no es un arreglo JSON válido.' AS [MENSAJE];
            RETURN;
        END

        SELECT N'OK' AS [OK];

        SELECT COUNT(1) AS [REGISTROS_TOTAL]
        FROM   [dbo].[FTR_SI] s WITH (READPAST)
        INNER JOIN (
            SELECT TRY_CAST([JD].[value] AS INT) AS [VID]
            FROM   OPENJSON(@P, N'$.IDS') AS [JD]
        ) AS J
            ON J.[VID] = s.[ID]
        WHERE  J.[VID] IS NOT NULL;

        SELECT
            s.[ID], s.[N_FACTURA], s.[F_FACTURA], s.[F_VENCE], s.[IDTERCERO], s.[IDPLAN], s.[TTEC],
            s.[CUENTACXC], s.[CUENTACXC_RAD], s.[SALDO], s.[F_RADICA], s.[CONCEPTO],
            s.[IDAREA], s.[CCOSTO], s.[IDSERVICIO], s.[DESCSERVICIO],
            s.[IDLOTE], s.[PROCESADO], s.[MENSAJEERROR], s.[ESTADO]
        FROM   [dbo].[FTR_SI] s WITH (READPAST)
        INNER JOIN (
            SELECT TRY_CAST([JD].[value] AS INT) AS [VID]
            FROM   OPENJSON(@P, N'$.IDS') AS [JD]
        ) AS J
            ON J.[VID] = s.[ID]
        WHERE  J.[VID] IS NOT NULL
        ORDER BY s.[ID];

        RETURN;
    END

    /* IDs pendientes en páginas: el cliente pide TAKE (p. ej. 3000) y DESDE_ID para armar lotes; luego PROCESAR_FTR con $.IDS. */
    IF @M = 'LISTAR_IDS_PENDIENTES'
    BEGIN
        DECLARE
            @LST_DL INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.DESDE_ID') AS INT), 0),
            @LST_TK INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.TAKE') AS INT), 3000);

        IF @LST_TK < 1
            SET @LST_TK = 1;
        IF @LST_TK > 5000
            SET @LST_TK = 5000;

        SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
            COALESCE(
                JSON_VALUE(@P, N'$.IDLOTE'),
                JSON_VALUE(@P, N'$.parametros.IDLOTE')
            )
        )), 40), N'');
        IF LOWER(COALESCE(@IDLOTE, N'')) = N'null'
            SET @IDLOTE = NULL;

        SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
        SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
        SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
        SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
        IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

        SET @F_TER_NIT_ID = NULL;
        IF @F_NIT IS NOT NULL
            SELECT @F_TER_NIT_ID = T.[IDTERCERO]
            FROM   [dbo].[TER] T WITH (READPAST)
            WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

        SELECT N'OK' AS [OK];

        SELECT TOP (@LST_TK)
            S.[ID]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        WHERE  S.[PROCESADO] = 0
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
          AND  S.[ID] > @LST_DL
        ORDER BY S.[ID];
        RETURN;
    END

    /* Candidatas a generar FCXC/FCXCD: FTR creada (CNSFCT), con F_RADICA. Incluye sin CNSCXC o CNSCXC cuyo FCXC no existe/esta cerrada o radicada (nueva CC). Excluye N_FACTURA ya en FCXCD. Misma paginacion que LISTAR_IDS_PENDIENTES. */
    IF @M = 'LISTAR_IDS_CXC'
    BEGIN
        DECLARE
            @LST_CXC_DL INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.DESDE_ID') AS INT), 0),
            @LST_CXC_TK INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.TAKE') AS INT), 3000);

        IF @LST_CXC_TK < 1
            SET @LST_CXC_TK = 1;
        IF @LST_CXC_TK > 5000
            SET @LST_CXC_TK = 5000;

        SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
            COALESCE(
                JSON_VALUE(@P, N'$.IDLOTE'),
                JSON_VALUE(@P, N'$.parametros.IDLOTE')
            )
        )), 40), N'');
        IF LOWER(COALESCE(@IDLOTE, N'')) = N'null'
            SET @IDLOTE = NULL;

        SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
        SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
        SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
        SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
        IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

        SET @F_TER_NIT_ID = NULL;
        IF @F_NIT IS NOT NULL
            SELECT @F_TER_NIT_ID = T.[IDTERCERO]
            FROM   [dbo].[TER] T WITH (READPAST)
            WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

        SELECT N'OK' AS [OK];

        SELECT TOP (@LST_CXC_TK)
            S.[ID]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        INNER JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        WHERE  S.[PROCESADO] = 1
          AND  S.[CNSFCT] IS NOT NULL
          AND  S.[CNSFCT] <> N''
          AND  F.[IDTERCERO] IS NOT NULL
          AND  LTRIM(RTRIM(F.[IDTERCERO])) <> N''
          AND  (
                    (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                    OR NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXC] C WITH (READPAST)
                        WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                          AND  COALESCE( C.[CERRADA], 0 ) = 0
                          AND  COALESCE( C.[INDRECIBIDO], 0 ) = 0
                    )
                )
          AND  S.[F_RADICA] IS NOT NULL
          AND  S.[ID] > @LST_CXC_DL
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
          AND  NOT EXISTS (
                    SELECT 1
                    FROM   [dbo].[FCXCD] D WITH (READPAST)
                    WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                )
        /* Paginación por S.ID (igual que LISTAR_IDS_PENDIENTES). No ordenar por tercero/F_RADICA aquí:
           DESDE_ID = max(ID) del lote anterior; un ORDER BY distinto deja filas sin procesar. */
        ORDER BY S.[ID];
        RETURN;
    END

    /*
        VALIDAR_PRE_CXC: antes de PROCESAR_CXC. Resume candidatas, filas con bloqueo y agrupación
        (1 cuenta de cobro = IDTERCERO + F_RADICA + sede; todas las facturas del mismo grupo comparten CNSCXC).
    */
    IF @M = 'VALIDAR_PRE_CXC'
    BEGIN
        SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
            COALESCE(
                JSON_VALUE(@P, N'$.IDLOTE'),
                JSON_VALUE(@P, N'$.parametros.IDLOTE')
            )
        )), 40), N'');
        IF LOWER(COALESCE(@IDLOTE, N'')) = N'null'
            SET @IDLOTE = NULL;

        SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
        SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
        SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
        SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
        IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

        SET @F_TER_NIT_ID = NULL;
        IF @F_NIT IS NOT NULL
            SELECT @F_TER_NIT_ID = T.[IDTERCERO]
            FROM   [dbo].[TER] T WITH (READPAST)
            WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

        SELECT N'OK' AS [OK];

        SELECT
            COUNT(DISTINCT S.[ID]) AS [TOTAL_CANDIDATAS],
            COUNT(DISTINCT CONCAT(
                F.[IDTERCERO], N'|',
                CONVERT(VARCHAR(10), CONVERT(DATE, S.[F_RADICA]), 23)
            )) AS [TOTAL_GRUPOS_CC],
            N'Validación previa de cuentas de cobro (candidatas y bloqueos).' AS [MENSAJE]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        INNER JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        WHERE  S.[PROCESADO] = 1
          AND  S.[CNSFCT] IS NOT NULL
          AND  S.[CNSFCT] <> N''
          AND  S.[F_RADICA] IS NOT NULL
          AND  (
                    (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                    OR NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXC] C WITH (READPAST)
                        WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                          AND  COALESCE(C.[CERRADA], 0) = 0
                          AND  COALESCE(C.[INDRECIBIDO], 0) = 0
                    )
                )
          AND  F.[IDTERCERO] IS NOT NULL
          AND  LTRIM(RTRIM(F.[IDTERCERO])) <> N''
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
          AND  NOT EXISTS (
                    SELECT 1
                    FROM   [dbo].[FCXCD] D WITH (READPAST)
                    WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                );

        SELECT TOP (500)
            S.[ID],
            S.[N_FACTURA],
            CASE
                WHEN S.[PROCESADO] <> 1 THEN N'Sin factura procesada (PROCESADO=0).'
                WHEN S.[CNSFCT] IS NULL OR S.[CNSFCT] = N'' THEN N'Sin CNSFCT en FTR_SI.'
                WHEN S.[F_RADICA] IS NULL THEN N'Sin F_RADICA; obligatoria para agrupar cuenta de cobro.'
                WHEN F.[CNSFCT] IS NULL THEN N'Sin registro en FTR.'
                WHEN F.[IDTERCERO] IS NULL OR LTRIM(RTRIM(F.[IDTERCERO])) = N'' THEN N'FTR sin IDTERCERO.'
                WHEN COALESCE(TRY_CAST(F.[VR_TOTAL] AS DECIMAL(18, 4)), 0) <= 0 THEN N'FTR con valor total inválido o cero.'
                WHEN EXISTS (
                    SELECT 1
                    FROM   [dbo].[FCXCD] D WITH (READPAST)
                    WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                ) THEN N'La factura ya existe en FCXCD.'
                ELSE N'No elegible para FCXC con los filtros actuales.'
            END AS [MOTIVO]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        LEFT JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        WHERE  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
          AND  (
                S.[PROCESADO] <> 1
                OR S.[CNSFCT] IS NULL OR S.[CNSFCT] = N''
                OR S.[F_RADICA] IS NULL
                OR F.[CNSFCT] IS NULL
                OR F.[IDTERCERO] IS NULL OR LTRIM(RTRIM(F.[IDTERCERO])) = N''
                OR COALESCE(TRY_CAST(F.[VR_TOTAL] AS DECIMAL(18, 4)), 0) <= 0
                OR EXISTS (
                    SELECT 1
                    FROM   [dbo].[FCXCD] D WITH (READPAST)
                    WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                )
                OR NOT (
                    S.[PROCESADO] = 1
                    AND S.[F_RADICA] IS NOT NULL
                    AND (
                        (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                        OR NOT EXISTS (
                            SELECT 1
                            FROM   [dbo].[FCXC] C WITH (READPAST)
                            WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                              AND  COALESCE(C.[CERRADA], 0) = 0
                              AND  COALESCE(C.[INDRECIBIDO], 0) = 0
                        )
                    )
                    AND NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXCD] D WITH (READPAST)
                        WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                    )
                )
               )
        ORDER BY S.[ID];

        SELECT TOP (300)
            F.[IDTERCERO],
            CONVERT(DATE, S.[F_RADICA]) AS [F_RADICA],
            COUNT(*) AS [CANT_FACTURAS],
            MAX(NULLIF(LTRIM(RTRIM(S.[CNSCXC])), N'')) AS [CNSCXC_REF]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        INNER JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        WHERE  S.[PROCESADO] = 1
          AND  S.[CNSFCT] IS NOT NULL
          AND  S.[CNSFCT] <> N''
          AND  S.[F_RADICA] IS NOT NULL
          AND  F.[IDTERCERO] IS NOT NULL
          AND  LTRIM(RTRIM(F.[IDTERCERO])) <> N''
          AND  (
                    (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                    OR NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXC] C WITH (READPAST)
                        WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                          AND  COALESCE(C.[CERRADA], 0) = 0
                          AND  COALESCE(C.[INDRECIBIDO], 0) = 0
                    )
                )
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
          AND  NOT EXISTS (
                    SELECT 1
                    FROM   [dbo].[FCXCD] D WITH (READPAST)
                    WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                )
        GROUP BY F.[IDTERCERO], CONVERT(DATE, S.[F_RADICA])
        ORDER BY F.[IDTERCERO], CONVERT(DATE, S.[F_RADICA]);

        RETURN;
    END

    IF @M = 'PROCESAR_FTR'
    BEGIN
        BEGIN TRY
            SET @REGOK = 0;
            SET @REGER = 0;
            SET @MENSAJE = N'';

            SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
                COALESCE(
                    JSON_VALUE(@P, N'$.IDLOTE'),
                    JSON_VALUE(@P, N'$.parametros.IDLOTE')
                )
            )), 40), N'');
            IF LOWER(COALESCE(@IDLOTE, N'')) = N'null'
                SET @IDLOTE = NULL;

            SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
            SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
            SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
            SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
            IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

            SET @F_TER_NIT_ID = NULL;
            IF @F_NIT IS NOT NULL
                SELECT @F_TER_NIT_ID = T.[IDTERCERO]
                FROM   [dbo].[TER] T WITH (READPAST)
                WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

            SET @USU_FTR = COALESCE(
                NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.USUARIO'))), 20), N''),
                NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.usuario'))), 20), N''),
                @USUARIO
            );

            SELECT
                @COMPANIA = COALESCE(UBEQ.COMPANIA, USUSU.COMPANIA, N'01'),
                @IDSEDE  = COALESCE(UBEQ.IDSEDE, USUSU.IDSEDE, N'01')
            FROM USUSU USUSU
            LEFT JOIN UBEQ UBEQ
                ON USUSU.SYS_ComputerName = UBEQ.SYS_ComputerName
            WHERE USUSU.USUARIO = @USU_FTR;

            IF @COMPANIA IS NULL
                SET @COMPANIA = N'01';
            IF @IDSEDE IS NULL
                SET @IDSEDE = N'01';

            IF OBJECT_ID(N'tempdb..#FTR_SI_ERR', N'U') IS NOT NULL
                DROP TABLE [#FTR_SI_ERR];
            CREATE TABLE [#FTR_SI_ERR] (
                [ID]        INT            NOT NULL,
                [N_FACTURA] NVARCHAR(20)  NULL,
                [MOTIVO]    NVARCHAR(500) NULL
            );

            IF OBJECT_ID(N'tempdb..#FTR_SI_IDS', N'U') IS NOT NULL
                DROP TABLE [#FTR_SI_IDS];
            /* Solo claves; PK agiliza MIN(ID). Con $.IDS = lote; sin $.IDS = todos los pendientes del filtro. */
            CREATE TABLE [#FTR_SI_IDS] ( [ID] INT NOT NULL PRIMARY KEY CLUSTERED );
            IF JSON_QUERY( @P, '$.IDS' ) IS NULL
            BEGIN
                INSERT INTO [#FTR_SI_IDS] ( [ID] )
                SELECT S.[ID]
                FROM   [dbo].[FTR_SI] S WITH (READPAST)
                WHERE
                    S.[PROCESADO] = 0
                    AND ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
                    AND ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
                    AND ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
                    AND (
                        @F_NIT IS NULL
                        OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                        OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
                    )
                    AND  (
                        @F_TIENE_CXC IS NULL
                     OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
                     OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
                    );
            END
            ELSE
            BEGIN
                INSERT INTO [#FTR_SI_IDS] ( [ID] )
                SELECT DISTINCT J.[VID]
                FROM (
                    SELECT TRY_CAST( [JD].[value] AS INT) AS [VID]
                    FROM OPENJSON( @P, '$.IDS' ) AS [JD]
                ) AS J
                INNER JOIN [dbo].[FTR_SI] S WITH (READPAST)
                    ON S.[ID] = J.[VID]
                WHERE J.[VID] IS NOT NULL
                  AND S.[PROCESADO] = 0
                  AND ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
                  AND ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
                  AND ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
                  AND (
                        @F_NIT IS NULL
                        OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                        OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
                    )
                  AND  (
                        @F_TIENE_CXC IS NULL
                     OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
                     OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
                    );
            END

            IF OBJECT_ID(N'tempdb..#TER_NIT_SIFTR', N'U') IS NOT NULL
                DROP TABLE [#TER_NIT_SIFTR];
            CREATE TABLE [#TER_NIT_SIFTR] (
                [NIT]       VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                [IDTERCERO] VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                PRIMARY KEY CLUSTERED ([NIT])
            );
            INSERT INTO [#TER_NIT_SIFTR] ( [NIT], [IDTERCERO] )
            SELECT DISTINCT
                T.[NIT] COLLATE DATABASE_DEFAULT,
                T.[IDTERCERO] COLLATE DATABASE_DEFAULT
            FROM   [dbo].[TER] T WITH (READPAST)
            INNER JOIN (
                SELECT DISTINCT S.[IDTERCERO] AS [NIT_KEY]
                FROM   [dbo].[FTR_SI] S WITH (READPAST)
                INNER JOIN [#FTR_SI_IDS] I ON I.[ID] = S.[ID]
            ) AS X ON X.[NIT_KEY] COLLATE DATABASE_DEFAULT = T.[NIT] COLLATE DATABASE_DEFAULT;

            IF OBJECT_ID(N'tempdb..#PPT_SIFTR', N'U') IS NOT NULL
                DROP TABLE [#PPT_SIFTR];
            CREATE TABLE [#PPT_SIFTR] (
                [IDTERCERO]       VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                [IDPLAN]          VARCHAR(6)  COLLATE DATABASE_DEFAULT NOT NULL,
                [DIASVTO]         SMALLINT    NULL,
                [TIPOTERCONTABLE] NVARCHAR(10) COLLATE DATABASE_DEFAULT NULL,
                PRIMARY KEY CLUSTERED ([IDTERCERO], [IDPLAN])
            );
            INSERT INTO [#PPT_SIFTR] ( [IDTERCERO], [IDPLAN], [DIASVTO], [TIPOTERCONTABLE] )
            SELECT
                P.[IDTERCERO] COLLATE DATABASE_DEFAULT,
                P.[IDPLAN] COLLATE DATABASE_DEFAULT,
                P.[DIASVTO],
                P.[TIPOTERCONTABLE] COLLATE DATABASE_DEFAULT
            FROM   [dbo].[PPT] P WITH (NOLOCK)
            INNER JOIN (
                SELECT DISTINCT COALESCE(TN.[IDTERCERO], S.[IDTERCERO] COLLATE DATABASE_DEFAULT) AS [IDT]
                FROM   [dbo].[FTR_SI] S WITH (READPAST)
                INNER JOIN [#FTR_SI_IDS] I ON I.[ID] = S.[ID]
                LEFT JOIN [#TER_NIT_SIFTR] TN
                    ON TN.[NIT] = S.[IDTERCERO] COLLATE DATABASE_DEFAULT
            ) AS Y ON Y.[IDT] = P.[IDTERCERO] COLLATE DATABASE_DEFAULT;

            WHILE 1 = 1
            BEGIN
                SET @IDF = (SELECT MIN([ID]) FROM [#FTR_SI_IDS]);
                IF @IDF IS NULL
                    BREAK;

                /* Una fila de FTR_SI: sin duplicar columnas en temp; fechas = DATETIME en tabla. */
                SELECT
                    @NF     = LEFT(RTRIM(LTRIM(S.[N_FACTURA])), 20),
                    @FF     = S.[F_FACTURA],
                    @FV     = S.[F_VENCE],
                    @IT     = S.[IDTERCERO],
                    @PL     = S.[IDPLAN],
                    @TTEC   = S.[TTEC],
                    @CXC    = S.[CUENTACXC],
                    @CXC_R  = S.[CUENTACXC_RAD],
                    @SAL    = S.[SALDO],
                    @CONC   = LEFT(S.[CONCEPTO], 2048),
                    @CCOSTO = S.[CCOSTO],
                    @IDSERV = S.[IDSERVICIO],
                    @DESCSERV = S.[DESCSERVICIO],
                    @IDAREA = S.[IDAREA]
                FROM   [dbo].[FTR_SI] S WITH (READPAST)
                WHERE  S.[ID] = @IDF
                  AND  S.[PROCESADO] = 0;

                IF @@ROWCOUNT = 0
                BEGIN
                    DELETE FROM [#FTR_SI_IDS] WHERE [ID] = @IDF;
                    CONTINUE;
                END

                SET @MOT    = NULL;
                SET @CNSFCT = NULL;
                SET @DV_PPT = 30;
                SET @IDTERCERO = NULL;
                IF @SAL IS NULL
                    SET @MOT = CONCAT(@MOT, N'SALDO nulo. ');

                IF @NF IS NULL OR LTRIM(RTRIM(@NF)) = N''
                    SET @MOT = CONCAT(@MOT, N'N_FACTURA requerida. ');

                IF @IT IS NULL OR LTRIM(RTRIM(@IT)) = N''
                    SET @MOT = CONCAT(@MOT, N'IDTERCERO requerido. ');

                IF @FF IS NULL
                    SET @MOT = CONCAT(@MOT, N'F_FACTURA no convertible a fecha. ');

                SELECT @IDTERCERO = TN.[IDTERCERO]
                FROM   [#TER_NIT_SIFTR] TN
                WHERE  TN.[NIT] = @IT COLLATE DATABASE_DEFAULT;
                IF COALESCE(@IDTERCERO, N'') <> N''
                    SET @IT = @IDTERCERO;

                IF @PL IS NULL
                    SELECT TOP (1) @PL = P.[IDPLAN]
                    FROM   [#PPT_SIFTR] P
                    WHERE  P.[IDTERCERO] = @IT COLLATE DATABASE_DEFAULT
                    ORDER BY P.[IDPLAN];

                IF @MOT IS NULL
                    SELECT
                        @DV_PPT = COALESCE(P.[DIASVTO], 30),
                        @TTEC   = CASE WHEN COALESCE(@TTEC, N'') <> N'' THEN @TTEC ELSE P.[TIPOTERCONTABLE] END
                    FROM   [#PPT_SIFTR] P
                    WHERE  P.[IDTERCERO] = @IT COLLATE DATABASE_DEFAULT
                      AND  P.[IDPLAN] = @PL COLLATE DATABASE_DEFAULT;

                IF @MOT IS NULL AND @PL IS NULL
                    SET @MOT = CONCAT(@MOT, N'Sin plan (PPT) para el tercero. ');
                IF @FV IS NULL AND @FF IS NOT NULL
                    SET @FV = DATEADD(DAY, COALESCE(@DV_PPT, 30), @FF);

                /* Periodo contable (criterio similar a CREARFTR) */
      

                IF @MOT IS NULL
                    AND EXISTS (
                        SELECT 1
                        FROM   [dbo].[FTR] F WITH ( NOLOCK )
                        WHERE  F.[N_FACTURA] COLLATE DATABASE_DEFAULT = @NF COLLATE DATABASE_DEFAULT
                    )
                    SET @MOT = N'N_FACTURA ya existe en FTR.';

                IF @MOT IS NULL
                BEGIN
                    BEGIN TRY
                        SET @CNSFCT = N'';
                        EXEC DBO.SPK_GENCONSECUTIVO
                            @COMPANIA,
                            @IDSEDE,
                            N'@CNSFTR',
                            @CNSFCT OUTPUT;
                        SET @CNSFCT
                            = @IDSEDE+'SI'
                            + REPLACE(SPACE(8 - LEN(@CNSFCT)) + LTRIM(RTRIM(@CNSFCT)), SPACE(1), 0);
                    END TRY
                    BEGIN CATCH
                        SET @MOT = CONCAT(@MOT, ERROR_MESSAGE());
                    END CATCH

                    IF ( @CNSFCT IS NULL OR LTRIM(RTRIM(@CNSFCT)) = N'' )
                        SET @MOT = CONCAT(@MOT, N'No se genero CNSFCT (SPK_GENCONSECUTIVO). ');
                END

                IF @MOT IS NULL
                BEGIN
                    BEGIN TRY
                        BEGIN TRAN [TR_PFF];

                        INSERT INTO [dbo].[FTR] (
                            [CNSFCT], [COMPANIA], [CLASE], [N_FACTURA], [F_FACTURA], [F_VENCE], [IDTERCERO], [IDPLAN], [IDSEDE], [TIPOTTEC],
                            [VR_TOTAL], [VALORSERVICIOS], [VALORCOPAGO], [ESTADO], [TIPOFAC], [PROCEDENCIA], [USUARIOFACTURA], [FECHAFAC],
                            [CUENTACXC], [CUENTACXC_RAD], [OBSERVACION], [INDCXC],[FACTE],[CONTABILIZADA],[INDCARTERA],[TIPOVENTA],[TIPOFIN],
                            [IDDEP],[SI]
                        ) VALUES (
                            @CNSFCT, @COMPANIA, N'C', @NF, @FF, @FV, @IT, @PL, @IDSEDE, NULLIF(LEFT(LTRIM(RTRIM(@TTEC)), 10), N''),
                            0,0, 0, N'P', N'I', N'FINANCIERO', @USU_FTR, GETDATE(),
                            @CXC, @CXC_R,COALESCE(@DESCSERV,'Saldos Iniciales Facturacion',@CONC),0,2,1,0,'Credito','C',
                            DBO.FNK_VALORVARIABLE('IDFDEPFACTURACION'),1
                        );

                        INSERT INTO [dbo].[FTRD] (
                            [CNSFTR], [N_CUOTA], [ITEM], [N_FACTURA], [VR_TOTAL], [VALOR], [CANTIDAD], [PREFIJO], [CCOSTO],[REFERENCIA],[ANEXO], [IDPLAN], [FECHA], [VLR_SERVICI], [DB_CR], [PROCEDENCIA]
                        ) VALUES (
                            @CNSFCT, 1, 1, @NF, @SAL, @SAL, 1,
                            @CONC,@CCOSTO,@IDSERV,@DESCSERV,  @PL, @FF, @SAL, NULL, N'FINANCIERO'
                        );

                        EXEC DBO.SPK_TOTALFACTURFIN @NF;

                        UPDATE [S]
                        SET
                            [S].[PROCESADO] = 1,
                            [S].[CNSFCT]   = @CNSFCT
                        FROM [dbo].[FTR_SI] AS [S]
                        WHERE [S].[ID] = @IDF;

                        COMMIT TRAN [TR_PFF];
                        SET @REGOK = @REGOK + 1;
                    END TRY
                    BEGIN CATCH
                        IF XACT_STATE() <> 0
                            ROLLBACK TRAN [TR_PFF];
                        SET @MOT = ERROR_MESSAGE();
                        IF @MOT IS NULL
                            OR LEN(@MOT) < 1
                            SET @MOT = N'Error al insertar FTR/FTRD';
                    END CATCH
                END

                IF @MOT IS NOT NULL
                BEGIN
                    SET @REGER = @REGER + 1;
                    INSERT INTO [#FTR_SI_ERR] ( [ID], [N_FACTURA], [MOTIVO] )
                    VALUES ( @IDF, @NF, @MOT );
                END

                DELETE FROM [#FTR_SI_IDS] WHERE [ID] = @IDF;
            END

            IF @REGER = 0
                SET @MENSAJE = N'Proceso finalizado. Sin errores por fila.';
            ELSE
                SET @MENSAJE = N'Proceso finalizado con errores por fila (tercer resultset).';

            SELECT N'OK' AS [OK];

            SELECT
                @MENSAJE AS [MENSAJE],
                @REGOK AS [REGISTROS_PROCESADOS],
                @REGER AS [REGISTROS_ERROR];

            IF @REGER > 0
                SELECT
                    E.[ID],
                    E.[N_FACTURA],
                    E.[MOTIVO]
                FROM [#FTR_SI_ERR] E;
        END TRY
        BEGIN CATCH
            SET @MENSAJE = ERROR_MESSAGE();
            SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE], ERROR_NUMBER() AS [SQL_ERR];
        END CATCH

        IF OBJECT_ID(N'tempdb..#FTR_SI_IDS', N'U') IS NOT NULL
            DROP TABLE [#FTR_SI_IDS];
        IF OBJECT_ID(N'tempdb..#TER_NIT_SIFTR', N'U') IS NOT NULL
            DROP TABLE [#TER_NIT_SIFTR];
        IF OBJECT_ID(N'tempdb..#PPT_SIFTR', N'U') IS NOT NULL
            DROP TABLE [#PPT_SIFTR];
        RETURN;
    END

    IF @M = 'PROCESAR_CXC'
    BEGIN
        BEGIN TRY
            DECLARE
                @CXC_REGOK    INT            = 0,
                @CXC_REGER    INT            = 0,
                @CXC_USU      NVARCHAR(20)   = NULL,
                @CXC_IDF      INT            = NULL,
                @CXC_CNSFCT   VARCHAR(40)    = NULL,
                @CXC_CNSCXC   VARCHAR(20)    = NULL,
                @CXC_NF       NVARCHAR(20)   = NULL,
                @CXC_IT       NVARCHAR(20)   = NULL,
                @CXC_PL       NVARCHAR(6)    = NULL,
                @CXC_VR       DECIMAL(18, 4)  = NULL,
                @CXC_D_RAD    DATE           = NULL,
                @CXC_MOT      NVARCHAR(500)  = NULL,
                @CXC_COORF    NVARCHAR(20)   = NULL,
                @CXC_COORC    NVARCHAR(20)   = NULL,
                @CXC_OBS      NVARCHAR(512)  = NULL,
                @CXC_MES      INT            = NULL,
                @CXC_ANO      VARCHAR(4)     = NULL,
                @CXC_CNSG     NVARCHAR(20)   = NULL,
                @CXC_CUENTA   NVARCHAR(16)   = NULL,
                @CXC_DSC      NVARCHAR(256)  = NULL,
                @CXC_SEDE_P   NVARCHAR(5)    = NULL,
                @CXC_CIA      VARCHAR(2)     = NULL;

            SET @CXC_MOT  = N'';
            SET @CXC_CNSFCT   = NULL;
            SET @CXC_CNSCXC   = NULL;
            SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
                COALESCE( JSON_VALUE(@P, N'$.IDLOTE'), JSON_VALUE(@P, N'$.parametros.IDLOTE') )
            )), 40), N'');
            IF LOWER(COALESCE(@IDLOTE, N'')) = N'null' SET @IDLOTE = NULL;

            SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
            SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
            SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
            SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
            IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

            SET @F_TER_NIT_ID = NULL;
            IF @F_NIT IS NOT NULL
                SELECT @F_TER_NIT_ID = T.[IDTERCERO]
                FROM   [dbo].[TER] T WITH (READPAST)
                WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

            SET @CXC_USU = COALESCE(
                NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.USUARIO'))), 20), N''),
                NULLIF(LEFT(LTRIM(RTRIM(JSON_VALUE(@P, N'$.usuario'))), 20), N''),
                @USUARIO
            );

            SELECT
                @CXC_CIA  = COALESCE(UBEQ.COMPANIA, USUSU.COMPANIA, N'01'),
                @CXC_SEDE_P = COALESCE(UBEQ.IDSEDE, USUSU.IDSEDE, N'01')
            FROM   USUSU USUSU
            LEFT JOIN UBEQ UBEQ ON USUSU.SYS_ComputerName = UBEQ.SYS_ComputerName
            WHERE  USUSU.USUARIO = @CXC_USU;
            IF @CXC_CIA IS NULL  SET @CXC_CIA = N'01';
            IF @CXC_SEDE_P IS NULL SET @CXC_SEDE_P = N'01';

            ;SELECT @CXC_OBS = NULLIF(LEFT(LTRIM(RTRIM([OBSERVACION])), 512), N'')
            FROM   [dbo].[USVGS] WITH (NOLOCK)
            WHERE  [IDVARIABLE] = N'FCXC_OBSERVACION_DEF';
            IF @CXC_OBS IS NULL
                SET @CXC_OBS = N'Cuenta por cobro (saldos iniciales)';

            SET @CXC_COORF = NULLIF(LEFT(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('USUARIOJEFEFACTURA'))), 20), N'');
            SET @CXC_COORC = NULLIF(LEFT(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('USUARIOJEFECARTERA'))), 20), N'');
            IF @CXC_COORF IS NULL OR @CXC_COORF = N'' SET @CXC_COORF = @CXC_USU;
            IF @CXC_COORC IS NULL OR @CXC_COORC = N'' SET @CXC_COORC = @CXC_USU;

            IF OBJECT_ID(N'tempdb..#SIFTR_CXC_ERR', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_CXC_ERR];
            CREATE TABLE [#SIFTR_CXC_ERR] (
                [ID]        INT            NOT NULL,
                [N_FACTURA] NVARCHAR(20)  NULL,
                [MOTIVO]    NVARCHAR(500) NULL
            );

            IF OBJECT_ID(N'tempdb..#SIFTR_CXC_IDS', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_CXC_IDS];
            CREATE TABLE [#SIFTR_CXC_IDS] ( [ID] INT NOT NULL PRIMARY KEY CLUSTERED );

            IF JSON_QUERY(@P, N'$.IDS') IS NULL
            BEGIN
                INSERT INTO [#SIFTR_CXC_IDS] ( [ID] )
                SELECT S.[ID]
                FROM   [dbo].[FTR_SI] S WITH (READPAST)
                WHERE
                    S.[PROCESADO] = 1
                    AND S.[CNSFCT] IS NOT NULL
                    AND S.[CNSFCT] <> N''
                    AND S.[F_RADICA] IS NOT NULL
                    AND (
                        (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                        OR NOT EXISTS (
                            SELECT 1
                            FROM   [dbo].[FCXC] C WITH (READPAST)
                            WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                              AND  COALESCE( C.[CERRADA], 0 ) = 0
                              AND  COALESCE( C.[INDRECIBIDO], 0 ) = 0
                        )
                    )
                    AND NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXCD] D WITH (READPAST)
                        WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                    )
                    AND ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
                    AND ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
                    AND ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
                    AND (
                        @F_NIT IS NULL
                        OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                        OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
                    )
                    AND  (
                        @F_TIENE_CXC IS NULL
                     OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
                     OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
                    );
            END
            ELSE
            BEGIN
                INSERT INTO [#SIFTR_CXC_IDS] ( [ID] )
                SELECT DISTINCT J.[VID]
                FROM ( SELECT TRY_CAST( [JD].[value] AS INT) AS [VID] FROM OPENJSON( @P, '$.IDS' ) AS [JD] ) J
                INNER JOIN [dbo].[FTR_SI] S WITH (READPAST) ON S.[ID] = J.[VID]
                WHERE
                    J.[VID] IS NOT NULL
                    AND S.[PROCESADO] = 1
                    AND S.[CNSFCT] IS NOT NULL
                    AND S.[F_RADICA] IS NOT NULL
                    AND (
                        (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                        OR NOT EXISTS (
                            SELECT 1
                            FROM   [dbo].[FCXC] C WITH (READPAST)
                            WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                              AND  COALESCE( C.[CERRADA], 0 ) = 0
                              AND  COALESCE( C.[INDRECIBIDO], 0 ) = 0
                        )
                    )
                    AND ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
                    AND ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
                    AND ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
                    AND (
                        @F_NIT IS NULL
                        OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                        OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
                    )
                    AND  (
                        @F_TIENE_CXC IS NULL
                     OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
                     OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
                    )
                    AND NOT EXISTS (
                        SELECT 1
                        FROM   [dbo].[FCXCD] D WITH (READPAST)
                        WHERE  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
                    );
            END

            IF OBJECT_ID(N'tempdb..#SIFTR_CXC_SRC', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_CXC_SRC];
            CREATE TABLE [#SIFTR_CXC_SRC] (
                [ID]          INT            NOT NULL PRIMARY KEY,
                [CNSFCT]      VARCHAR(40)    COLLATE DATABASE_DEFAULT NULL,
                [N_FACTURA]   NVARCHAR(20)   COLLATE DATABASE_DEFAULT NULL,
                [IDTERCERO]   NVARCHAR(20)   COLLATE DATABASE_DEFAULT NULL,
                [VR_TOTAL]    DECIMAL(18, 4) NULL,
                [IDPLAN]      NVARCHAR(6)    COLLATE DATABASE_DEFAULT NULL,
                [CUENTACXC]   NVARCHAR(16)   COLLATE DATABASE_DEFAULT NULL,
                [F_RADICA]    DATE           NULL,
                [DESCRIPCION] NVARCHAR(256)  COLLATE DATABASE_DEFAULT NULL,
                [EN_FCXCD]    BIT            NOT NULL DEFAULT 0,
                [ELEGIBLE]    BIT            NOT NULL DEFAULT 0
            );
            INSERT INTO [#SIFTR_CXC_SRC] (
                [ID], [CNSFCT], [N_FACTURA], [IDTERCERO], [VR_TOTAL], [IDPLAN], [CUENTACXC],
                [F_RADICA], [DESCRIPCION], [EN_FCXCD], [ELEGIBLE]
            )
            SELECT
                S.[ID],
                S.[CNSFCT] COLLATE DATABASE_DEFAULT,
                LTRIM(RTRIM(S.[N_FACTURA])) COLLATE DATABASE_DEFAULT,
                F.[IDTERCERO] COLLATE DATABASE_DEFAULT,
                COALESCE(TRY_CAST(F.[VR_TOTAL] AS DECIMAL(18, 4)), 0),
                F.[IDPLAN] COLLATE DATABASE_DEFAULT,
                F.[CUENTACXC] COLLATE DATABASE_DEFAULT,
                CONVERT(DATE, S.[F_RADICA]),
                COALESCE(LEFT(NULLIF(LTRIM(RTRIM(S.[CONCEPTO])), N''), 200), N'Saldo inicial (SIFTR)') COLLATE DATABASE_DEFAULT,
                CASE WHEN D.[N_FACTURA] IS NOT NULL THEN 1 ELSE 0 END,
                CASE
                    WHEN F.[CNSFCT] IS NULL THEN 0
                    WHEN F.[IDTERCERO] IS NULL OR LTRIM(RTRIM(F.[IDTERCERO])) = N'' THEN 0
                    WHEN COALESCE(TRY_CAST(F.[VR_TOTAL] AS DECIMAL(18, 4)), 0) <= 0 THEN 0
                    WHEN S.[F_RADICA] IS NULL THEN 0
                    WHEN D.[N_FACTURA] IS NOT NULL THEN 0
                    WHEN NOT (
                        (S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'')
                        OR NOT EXISTS (
                            SELECT 1
                            FROM   [dbo].[FCXC] C WITH (READPAST)
                            WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = S.[CNSCXC] COLLATE DATABASE_DEFAULT
                              AND  COALESCE(C.[CERRADA], 0) = 0
                              AND  COALESCE(C.[INDRECIBIDO], 0) = 0
                        )
                    ) THEN 0
                    ELSE 1
                END
            FROM   [dbo].[FTR_SI] S WITH (READPAST)
            INNER JOIN [#SIFTR_CXC_IDS] I ON I.[ID] = S.[ID]
            LEFT JOIN [dbo].[FTR] F WITH (READPAST)
                ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
                AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
            LEFT JOIN [dbo].[FCXCD] D WITH (READPAST)
                ON  D.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT;

            IF OBJECT_ID(N'tempdb..#SIFTR_CXC_GRP', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_CXC_GRP];
            CREATE TABLE [#SIFTR_CXC_GRP] (
                [IDTERCERO] VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                [F_RADICA]  DATE        NOT NULL,
                [IDSEDE]    NVARCHAR(5) COLLATE DATABASE_DEFAULT NOT NULL,
                [CNSCXC]    VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
                PRIMARY KEY CLUSTERED ([IDTERCERO], [F_RADICA], [IDSEDE])
            );

            WHILE 1 = 1
            BEGIN
                SET @CXC_IDF = (
                    SELECT TOP (1) I.[ID]
                    FROM   [#SIFTR_CXC_IDS] I
                    INNER JOIN [#SIFTR_CXC_SRC] SRC ON SRC.[ID] = I.[ID]
                    ORDER BY SRC.[IDTERCERO], SRC.[F_RADICA], I.[ID]
                );
                IF @CXC_IDF IS NULL
                    BREAK;

                SET @CXC_MOT  = NULL;
                SET @CXC_CNSCXC = NULL;
                SET @CXC_CNSFCT   = NULL;
                SET @CXC_NF       = NULL;
                SET @CXC_IT       = NULL;
                SET @CXC_PL       = NULL;
                SET @CXC_VR       = NULL;
                SET @CXC_D_RAD    = NULL;
                SET @CXC_CUENTA   = NULL;
                SET @CXC_DSC      = NULL;
                SET @CXC_CNSG     = NULL;

                SELECT
                    @CXC_CNSFCT = SRC.[CNSFCT],
                    @CXC_NF     = SRC.[N_FACTURA],
                    @CXC_IT     = SRC.[IDTERCERO],
                    @CXC_VR     = SRC.[VR_TOTAL],
                    @CXC_PL     = SRC.[IDPLAN],
                    @CXC_CUENTA = SRC.[CUENTACXC],
                    @CXC_D_RAD  = SRC.[F_RADICA],
                    @CXC_DSC    = SRC.[DESCRIPCION]
                FROM   [#SIFTR_CXC_SRC] SRC
                WHERE  SRC.[ID] = @CXC_IDF;

                IF @CXC_CNSFCT IS NULL
                    SET @CXC_MOT = N'No se pudo leer FTR + FTR_SI.';
                ELSE IF EXISTS (SELECT 1 FROM [#SIFTR_CXC_SRC] SRC WHERE SRC.[ID] = @CXC_IDF AND SRC.[EN_FCXCD] = 1)
                    SET @CXC_MOT = N'La factura ya existe en FCXCD; no se puede duplicar en cartera.';
                ELSE IF EXISTS (SELECT 1 FROM [#SIFTR_CXC_SRC] SRC WHERE SRC.[ID] = @CXC_IDF AND SRC.[ELEGIBLE] = 0)
                    SET @CXC_MOT = N'Fila FTR_SI no elegible (sin FTR/IDTERCERO, F_RADICA, valor, o CNSCXC ya vinculado a FCXC abierta).';
                ELSE IF @CXC_IT IS NULL OR LTRIM(RTRIM(@CXC_IT)) = N''
                    SET @CXC_MOT = N'FTR sin IDTERCERO; no se puede agrupar cuenta de cobro por tercero.';
                ELSE IF @CXC_VR IS NULL OR @CXC_VR <= 0
                    SET @CXC_MOT = N'FTR con valor total inválido o cero.';
                ELSE IF @CXC_D_RAD IS NULL
                    SET @CXC_MOT = N'Sin fecha de radicación (F_RADICA); no se asigna Cuenta de Cobro; permanece en facturación.';
                ELSE
                BEGIN
                    SELECT
                        @CXC_MES = MONTH( CONVERT( DATETIME, @CXC_D_RAD ) ),
                        @CXC_ANO = CAST( YEAR( CONVERT( DATETIME, @CXC_D_RAD ) ) AS VARCHAR(4) );

                    /* Agrupación: 1 FCXC por IDTERCERO + F_RADICA + sede (mismo lote, FTR_SI hermanas o FCXC SIFTR abierta). */
                    SELECT @CXC_CNSCXC = G.[CNSCXC]
                    FROM   [#SIFTR_CXC_GRP] G
                    WHERE  G.[IDTERCERO] = @CXC_IT COLLATE DATABASE_DEFAULT
                      AND  G.[F_RADICA] = @CXC_D_RAD
                      AND  G.[IDSEDE] = @CXC_SEDE_P;

                    IF @CXC_CNSCXC IS NULL
                        SELECT TOP (1) @CXC_CNSCXC = LTRIM(RTRIM(S2.[CNSCXC]))
                        FROM   [dbo].[FTR_SI] S2 WITH (READPAST)
                        INNER JOIN [dbo].[FTR] F2 WITH (READPAST)
                            ON  F2.[CNSFCT] COLLATE DATABASE_DEFAULT = S2.[CNSFCT] COLLATE DATABASE_DEFAULT
                            AND F2.[N_FACTURA] COLLATE DATABASE_DEFAULT = S2.[N_FACTURA] COLLATE DATABASE_DEFAULT
                        WHERE  F2.[IDTERCERO] COLLATE DATABASE_DEFAULT = @CXC_IT COLLATE DATABASE_DEFAULT
                          AND  CONVERT(DATE, S2.[F_RADICA]) = @CXC_D_RAD
                          AND  S2.[CNSCXC] IS NOT NULL
                          AND  LTRIM(RTRIM(S2.[CNSCXC])) <> N''
                          AND  EXISTS (
                                SELECT 1
                                FROM   [dbo].[FCXC] C WITH (READPAST)
                                WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = LTRIM(RTRIM(S2.[CNSCXC])) COLLATE DATABASE_DEFAULT
                                  AND  C.[IDTERCERO] COLLATE DATABASE_DEFAULT = @CXC_IT COLLATE DATABASE_DEFAULT
                                  AND  C.[IDSEDE] = @CXC_SEDE_P
                                  AND  C.[PROCEDENCIA] = N'SIFTR'
                                  AND  COALESCE(C.[CERRADA], 0) = 0
                                  AND  COALESCE(C.[INDRECIBIDO], 0) = 0
                                  AND  CONVERT(DATE, ISNULL(C.[FRADICAEPS], C.[FECHACXC])) = @CXC_D_RAD
                            )
                        ORDER BY S2.[ID];

                    IF @CXC_CNSCXC IS NULL
                        SELECT TOP (1) @CXC_CNSCXC = C.[CNSCXC]
                        FROM   [dbo].[FCXC] C WITH (READPAST)
                        WHERE
                            C.[IDTERCERO] COLLATE DATABASE_DEFAULT = @CXC_IT COLLATE DATABASE_DEFAULT
                            AND COALESCE( C.[CERRADA], 0 ) = 0
                            AND COALESCE( C.[INDRECIBIDO], 0 ) = 0
                            AND ( C.[ESTADO] = N'Activa' OR C.[ESTADO] IS NULL )
                            AND C.[IDSEDE] = @CXC_SEDE_P
                            AND C.[PROCEDENCIA] = N'SIFTR'
                            AND CONVERT( DATE, ISNULL( C.[FRADICAEPS], C.[FECHACXC] ) ) = @CXC_D_RAD
                        ORDER BY
                            C.[FECHACXC] DESC;

                    IF @CXC_CNSCXC IS NULL
                    BEGIN
                        SET @CXC_CNSG = N'';
                        BEGIN TRY
                            EXEC DBO.SPK_GENCONSECUTIVO
                                @CXC_CIA,
                                @CXC_SEDE_P,
                                N'@CXC',
                                @CXC_CNSG OUTPUT;
                        END TRY
                        BEGIN CATCH
                            SET @CXC_MOT = ERROR_MESSAGE();
                        END CATCH
                        IF @CXC_MOT IS NULL
                            SET @CXC_CNSCXC
                                = @CXC_SEDE_P
                                + REPLACE( SPACE(8 - LEN( @CXC_CNSG )) + LTRIM( RTRIM( @CXC_CNSG )), SPACE(1), 0);
                        IF @CXC_MOT IS NULL
                        BEGIN
                            BEGIN TRY
                                INSERT INTO [dbo].[FCXC] (
                                    [CNSCXC], [FECHACXC], [IDTERCERO], [IDMENSAJERO], [F_VENCE], [INDRECIBIDO], [F_RECIBIDO], [QUIENRECIBIO], [NOREFERENCIAEXT], [USUARIO], [COMPANIA], [VALORDEVUELTO], [CERRADA], [TIENEGLOSAS], [TIENEDEVOLUCION], [CNSANT], 
                                    [ANTIGUA], [VALORCXC], [DEDUCCIONES], [VALORCXCNETO], [VLRPAGOS], [VLRNOTADB], [VLRNOTACR], [SALDO], [SALDONETO], [VLRGLOSAS], [VLRGLOSAS_R], [VLREXTRA], [OBSERVACION], [NROCOMPROBANTE], [PROCEDENCIA], 
                                    [ENPRESUPUESTO], [MARCAFAC], [ITFC], [CNSITFC], [CONTABILIZADA], [OBSCARTA], [IDSEDE], [MODALIDAD], [ATENCION], [MES], [ANO], [REGIMEN], [NROGUIA], [USUCIERRA], [F_CIERRA], [ESTADO], [COORFACTURACION], [COORCARTERA], 
                                    [NOPOS], [FRADICAEPS], [FENVIO], [SUCURSAL], [MSEDE]
                                )
                                VALUES (
                                    @CXC_CNSCXC, CAST( @CXC_D_RAD AS DATETIME ), @CXC_IT, NULL, NULL, 0, NULL, NULL, NULL, @CXC_USU, @CXC_CIA, 0, 0, 0, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, @CXC_OBS, NULL, N'SIFTR', 
                                    0, 0, 0, NULL, 0, NULL, @CXC_SEDE_P, N'F', N'C', CAST( @CXC_MES AS VARCHAR(2) ), @CXC_ANO, N'C', NULL, NULL, NULL, N'Activa', @CXC_COORF, @CXC_COORC, 0, CAST( @CXC_D_RAD AS DATETIME), NULL, NULL, 0
                                );
                            END TRY
                            BEGIN CATCH
                                SET @CXC_MOT = ERROR_MESSAGE();
                            END CATCH
                        END
                    END

                    IF @CXC_MOT IS NULL
                    BEGIN
                        BEGIN TRY
                            BEGIN TRAN [TR_CXC_SI];
                            INSERT INTO [dbo].[FCXCD] (
                                [CNSCXC], [N_FACTURA], [USUARIO], [COMPANIA], [VALORFACTURA], [DEDUCCIONES], [VALORFACTURANETO], [VLRPAGOS], [VLRNOTADB], [VLRNOTACR], 
                                [SALDO], [SALDONETO], [CERRADA], [TIENEGLOSAS], [TIENEDEVOLUCION], [MARCAPAGO],  [NT_MARCAP], [VLRGLOSAS], [VLRGLOSAS_R], [VLREXTRA], 
                                [NROCOMPROBANTE], [CUENTA], [DESCRIPCION], [NOREFERENCIAEXT], [ENCOBROJUR], [IDPLAN], [ITFC], [CNSITFC], [VLRFCES], [VLRLEVANTADO], [MARCA], [USURESP], [RESPUESTA],  [RAZONDEVOL]
                            )
                            VALUES (
                                @CXC_CNSCXC, @CXC_NF, @CXC_USU, @CXC_CIA, @CXC_VR, 0, @CXC_VR, 0, 0, 0, @CXC_VR, @CXC_VR, 0, 0, 0, 0, NULL, 0, 0, 0, NULL, @CXC_CUENTA, @CXC_DSC, NULL, 0, @CXC_PL, 0, NULL, 0, 0, 0, NULL, NULL, NULL
                            );

                            UPDATE [dbo].[FCXC] WITH (ROWLOCK)
                            SET
                                [VALORCXC]     = [VALORCXC] + @CXC_VR,
                                [VALORCXCNETO] = [VALORCXCNETO] + @CXC_VR,
                                [SALDO]        = [SALDO] + @CXC_VR,
                                [SALDONETO]    = [SALDONETO] + @CXC_VR
                            WHERE
                                [CNSCXC] = @CXC_CNSCXC;

                            UPDATE [dbo].[FTR_SI] WITH (ROWLOCK)
                            SET
                                [CNSCXC] = @CXC_CNSCXC
                            WHERE
                                [ID] = @CXC_IDF;

                            COMMIT TRAN [TR_CXC_SI];

                            IF NOT EXISTS (
                                SELECT 1
                                FROM   [#SIFTR_CXC_GRP] G
                                WHERE  G.[IDTERCERO] = @CXC_IT COLLATE DATABASE_DEFAULT
                                  AND  G.[F_RADICA] = @CXC_D_RAD
                                  AND  G.[IDSEDE] = @CXC_SEDE_P
                            )
                                INSERT INTO [#SIFTR_CXC_GRP] ( [IDTERCERO], [F_RADICA], [IDSEDE], [CNSCXC] )
                                VALUES ( @CXC_IT, @CXC_D_RAD, @CXC_SEDE_P, @CXC_CNSCXC );
                        END TRY
                        BEGIN CATCH
                            IF XACT_STATE() <> 0
                                ROLLBACK TRAN [TR_CXC_SI];
                            SET @CXC_MOT = ERROR_MESSAGE();
                        END CATCH
                    END

                END

                IF @CXC_MOT IS NOT NULL
                BEGIN
                    SET @CXC_REGER = @CXC_REGER + 1;
                    INSERT INTO [#SIFTR_CXC_ERR] ( [ID], [N_FACTURA], [MOTIVO] )
                    VALUES ( @CXC_IDF, @CXC_NF, @CXC_MOT );
                END
                ELSE
                BEGIN
                    SET @CXC_REGOK = @CXC_REGOK + 1;
                END

                DELETE FROM [#SIFTR_CXC_IDS] WHERE [ID] = @CXC_IDF;
            END

            /* Reliquidación, entrega (SPK_ENTREGA_CXC) y paso a CARTERA: solo en METODO = FINALIZAR_CXC_SIFTR. */

            IF @CXC_REGER = 0
                SET @MENSAJE = N'Generación FCXC/FCXCD finalizada. Sin errores por fila. Debe ejecutarse FINALIZAR_CXC_SIFTR al terminar todos los lotes (queda en SIFTR hasta entonces).';
            ELSE
                SET @MENSAJE = N'Generación FCXC/FCXCD con errores por fila (tercer resultset). Corrija y  FINALIZAR_CXC_SIFTR solo cuando haya completado la generación.';

            SELECT N'OK' AS [OK];

            SELECT
                @MENSAJE AS [MENSAJE],
                @CXC_REGOK AS [REGISTROS_PROCESADOS],
                @CXC_REGER AS [REGISTROS_ERROR];

            IF @CXC_REGER > 0
                SELECT
                    E.[ID],
                    E.[N_FACTURA],
                    E.[MOTIVO]
                FROM [#SIFTR_CXC_ERR] E;
        END TRY
        BEGIN CATCH
            SET @MENSAJE = ERROR_MESSAGE();
            SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE], ERROR_NUMBER() AS [SQL_ERR];
        END CATCH

        IF OBJECT_ID(N'tempdb..#SIFTR_CXC_IDS', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_CXC_IDS];
        IF OBJECT_ID(N'tempdb..#SIFTR_CXC_SRC', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_CXC_SRC];
        IF OBJECT_ID(N'tempdb..#SIFTR_CXC_GRP', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_CXC_GRP];
        IF OBJECT_ID(N'tempdb..#SIFTR_CXC_ERR', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_CXC_ERR];
        RETURN;
    END

    /* Un solo paso (tras todos los lotes de PROCESAR_CXC en el front): reliquidar, entregar y PROCEDENCIA = CARTERA. Mismos filtros + IDLOTE. */
    IF @M = 'FINALIZAR_CXC_SIFTR'
    BEGIN
        BEGIN TRY
            DECLARE
                @FIN_REGOK       INT            = 0,
                @FIN_REGER       INT            = 0,
                @FIN_CNS         VARCHAR(20)    = NULL,
                @FIN_D_RAD       DATE           = NULL,
                @FIN_SEDE        NVARCHAR(5)    = NULL,
                @FIN_MOT         NVARCHAR(500)  = NULL,
                @FIN_FEENT       DATETIME       = NULL,
                @FIN_N_VAC       INT            = 0;

            SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
                COALESCE( JSON_VALUE(@P, N'$.IDLOTE'), JSON_VALUE(@P, N'$.parametros.IDLOTE') )
            )), 40), N'');
            IF LOWER(COALESCE(@IDLOTE, N'')) = N'null' SET @IDLOTE = NULL;

            SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
            SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
            SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
            SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
            IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

            SET @F_TER_NIT_ID = NULL;
            IF @F_NIT IS NOT NULL
                SELECT @F_TER_NIT_ID = T.[IDTERCERO]
                FROM   [dbo].[TER] T WITH (READPAST)
                WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

            IF OBJECT_ID(N'tempdb..#SIFTR_FIN_CNS', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_FIN_CNS];
            CREATE TABLE [#SIFTR_FIN_CNS] ( [CNSCXC] VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY );

            IF OBJECT_ID(N'tempdb..#SIFTR_FIN_ERR', N'U') IS NOT NULL
                DROP TABLE [#SIFTR_FIN_ERR];
            CREATE TABLE [#SIFTR_FIN_ERR] (
                [CNSCXC] VARCHAR(20) NOT NULL,
                [MOTIVO] NVARCHAR(500) NULL
            );

            INSERT INTO [#SIFTR_FIN_CNS] ( [CNSCXC] )
            SELECT DISTINCT LTRIM(RTRIM(S.[CNSCXC])) COLLATE DATABASE_DEFAULT
            FROM   [dbo].[FTR_SI] S WITH (READPAST)
            INNER JOIN [dbo].[FCXC] C WITH (READPAST)
                ON C.[CNSCXC] COLLATE DATABASE_DEFAULT = LTRIM(RTRIM(S.[CNSCXC])) COLLATE DATABASE_DEFAULT
            WHERE  S.[PROCESADO] = 1
              AND  S.[CNSFCT] IS NOT NULL
              AND  LTRIM(RTRIM(S.[CNSFCT])) <> N''
              AND  S.[F_RADICA] IS NOT NULL
              AND  S.[CNSCXC] IS NOT NULL
              AND  LTRIM(RTRIM(S.[CNSCXC])) <> N''
              AND  C.[PROCEDENCIA] = N'SIFTR'
              AND  COALESCE( C.[CERRADA], 0 ) = 0
              AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
              AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
              AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
              AND  (
                    @F_NIT IS NULL
                    OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                    OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
                )
              AND  (
                    @F_TIENE_CXC IS NULL
                 OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND LTRIM(RTRIM(S.[CNSCXC])) <> N'' )
                 OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR LTRIM(RTRIM(S.[CNSCXC])) = N'' ) )
                );

            SELECT @FIN_N_VAC = COUNT(1) FROM [#SIFTR_FIN_CNS];

            WHILE 1 = 1
            BEGIN
                SET @FIN_CNS = (SELECT MIN([CNSCXC]) FROM [#SIFTR_FIN_CNS]);
                IF @FIN_CNS IS NULL
                    BREAK;

                SET @FIN_MOT = NULL;
                SET @FIN_D_RAD = NULL;
                SET @FIN_SEDE = NULL;

                SELECT
                    @FIN_D_RAD = CONVERT( DATE, ISNULL( C.[FRADICAEPS], C.[FECHACXC] ) ),
                    @FIN_SEDE = C.[IDSEDE]
                FROM   [dbo].[FCXC] C WITH (READPAST)
                WHERE  C.[CNSCXC] COLLATE DATABASE_DEFAULT = @FIN_CNS COLLATE DATABASE_DEFAULT
                  AND  C.[PROCEDENCIA] = N'SIFTR';

                IF @FIN_SEDE IS NULL
                    SET @FIN_MOT = N'No se encontro FCXC con PROCEDENCIA SIFTR para el consecutivo.';

                IF @FIN_MOT IS NULL AND @FIN_D_RAD IS NULL
                    SET @FIN_MOT = N'Sin fecha (FRADICAEPS/FECHACXC) en FCXC.';

                IF @FIN_MOT IS NULL
                BEGIN
                    BEGIN TRY
                        EXEC DBO.SPK_RELIQUIDACXCQX @FIN_CNS;
                    END TRY
                    BEGIN CATCH
                        SET @FIN_MOT = ERROR_MESSAGE();
                    END CATCH
                END
                IF @FIN_MOT IS NULL
                BEGIN
                    BEGIN TRY
                        SET @FIN_FEENT = CAST(@FIN_D_RAD AS DATETIME);
                        EXEC DBO.SPK_ENTREGA_CXC
                            @FIN_CNS,
                            N'saldos iniciales',
                            @FIN_FEENT,
                            NULL,
                            NULL,
                            @FIN_SEDE,
                            NULL;
                    END TRY
                    BEGIN CATCH
                        SET @FIN_MOT = ERROR_MESSAGE();
                    END CATCH
                END
                IF @FIN_MOT IS NULL
                BEGIN
                    BEGIN TRY
                        UPDATE C
                        SET    C.[PROCEDENCIA] = N'CARTERA'
                        FROM   [dbo].[FCXC] C
                        WHERE  C.[CNSCXC] = @FIN_CNS
                          AND  C.[PROCEDENCIA] = N'SIFTR';
                    END TRY
                    BEGIN CATCH
                        SET @FIN_MOT = ERROR_MESSAGE();
                    END CATCH
                END

                IF @FIN_MOT IS NOT NULL
                BEGIN
                    SET @FIN_REGER = @FIN_REGER + 1;
                    INSERT INTO [#SIFTR_FIN_ERR] ( [CNSCXC], [MOTIVO] ) VALUES ( @FIN_CNS, @FIN_MOT );
                END
                ELSE
                    SET @FIN_REGOK = @FIN_REGOK + 1;

                DELETE FROM [#SIFTR_FIN_CNS] WHERE [CNSCXC] = @FIN_CNS;
            END

            IF @FIN_N_VAC = 0
                SET @MENSAJE = N'Ningun FCXC SIFTR elegible (FTR_SI+filtro). No se aplico cierre. Si aun faltan lotes, ejecute finalizar despues de generar.';
            ELSE IF @FIN_REGER = 0
                SET @MENSAJE = N'Cierre SIFTR en cartera: radicada/entregada, PROCEDENCIA = CARTERA. Sin errores por cabecera.';
            ELSE
                SET @MENSAJE = N'Cierre SIFTR con errores (tercer resultset).';

            SELECT N'OK' AS [OK];

            SELECT
                @MENSAJE AS [MENSAJE],
                @FIN_REGOK AS [REGISTROS_PROCESADOS],
                @FIN_REGER AS [REGISTROS_ERROR];

            IF @FIN_REGER > 0
                SELECT
                    E.[CNSCXC],
                    E.[MOTIVO]
                FROM [#SIFTR_FIN_ERR] E;
        END TRY
        BEGIN CATCH
            SET @MENSAJE = ERROR_MESSAGE();
            SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE], ERROR_NUMBER() AS [SQL_ERR];
        END CATCH

        IF OBJECT_ID(N'tempdb..#SIFTR_FIN_CNS', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_FIN_CNS];
        IF OBJECT_ID(N'tempdb..#SIFTR_FIN_ERR', N'U') IS NOT NULL
            DROP TABLE [#SIFTR_FIN_ERR];
        RETURN;
    END

    /*
        EXPORTAR_CXC_FACTURAS: relación cuenta de cobro ? facturas (FTR_SI con CNSCXC) para validación en Excel.
        Mismos filtros de vista (IDLOTE, N_FACTURA, NIT/IDTERCERO, CON_CXC). Paginación opcional: DESDE_ID + TAKE.
    */
    IF @M = 'EXPORTAR_CXC_FACTURAS'
    BEGIN
        DECLARE
            @EXP_DL INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.DESDE_ID') AS INT), 0),
            @EXP_TK INT = ISNULL(TRY_CAST(JSON_VALUE(@P, N'$.TAKE') AS INT), 5000);

        IF @EXP_TK < 1
            SET @EXP_TK = 1;
        IF @EXP_TK > 10000
            SET @EXP_TK = 10000;

        SET @IDLOTE = NULLIF(LEFT(LTRIM(RTRIM(
            COALESCE(
                JSON_VALUE(@P, N'$.IDLOTE'),
                JSON_VALUE(@P, N'$.parametros.IDLOTE')
            )
        )), 40), N'');
        IF LOWER(COALESCE(@IDLOTE, N'')) = N'null'
            SET @IDLOTE = NULL;

        SET @F_N_FACTURA = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.N_FACTURA'), N''))), 16), N'');
        SET @F_IDTERCERO = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.IDTERCERO'), N''))), 20), N'');
        SET @F_NIT = NULLIF(LEFT(LTRIM(RTRIM(COALESCE(JSON_VALUE(@P, N'$.NIT'), N''))), 20), N'');
        SET @F_TIENE_CXC = TRY_CAST(JSON_VALUE(@P, N'$.CON_CXC') AS INT);
        IF @F_TIENE_CXC IS NOT NULL AND @F_TIENE_CXC NOT IN (0, 1) SET @F_TIENE_CXC = NULL;

        SET @F_TER_NIT_ID = NULL;
        IF @F_NIT IS NOT NULL
            SELECT @F_TER_NIT_ID = T.[IDTERCERO]
            FROM   [dbo].[TER] T WITH (READPAST)
            WHERE  T.[NIT] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT;

        SELECT N'OK' AS [OK];

        SELECT
            COUNT(DISTINCT S.[CNSCXC]) AS [TOTAL_CNSCXC],
            COUNT(*) AS [TOTAL_FILAS]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        LEFT JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        WHERE  S.[CNSCXC] IS NOT NULL
          AND  LTRIM(RTRIM(S.[CNSCXC])) <> N''
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               );

        SELECT TOP (@EXP_TK)
            LTRIM(RTRIM(S.[CNSCXC])) AS [CNSCXC],
            COALESCE(C.[IDTERCERO], F.[IDTERCERO], S.[IDTERCERO]) AS [IDTERCERO],
            CONVERT(DATE, S.[F_RADICA]) AS [F_RADICA],
            LTRIM(RTRIM(S.[N_FACTURA])) AS [N_FACTURA],
            LTRIM(RTRIM(S.[CNSFCT])) AS [CNSFCT],
            S.[SALDO],
            CONVERT(DATE, S.[F_FACTURA]) AS [F_FACTURA],
            CONVERT(DATE, C.[FECHACXC]) AS [FECHACXC],
            CONVERT(DATE, ISNULL(C.[FRADICAEPS], C.[FECHACXC])) AS [FRADICAEPS],
            COALESCE(C.[VALORCXC], 0) AS [VALOR_CXC],
            COALESCE(C.[SALDO], 0) AS [SALDO_CXC],
            C.[PROCEDENCIA] AS [PROCEDENCIA_CXC],
            C.[ESTADO] AS [ESTADO_CXC],
            COUNT(*) OVER (
                PARTITION BY LTRIM(RTRIM(S.[CNSCXC]))
            ) AS [CANT_FACTURAS_EN_CC],
            S.[IDLOTE],
            S.[ID] AS [ID_FTR_SI]
        FROM   [dbo].[FTR_SI] S WITH (READPAST)
        LEFT JOIN [dbo].[FTR] F WITH (READPAST)
            ON  F.[CNSFCT] COLLATE DATABASE_DEFAULT = S.[CNSFCT] COLLATE DATABASE_DEFAULT
            AND F.[N_FACTURA] COLLATE DATABASE_DEFAULT = S.[N_FACTURA] COLLATE DATABASE_DEFAULT
        LEFT JOIN [dbo].[FCXC] C WITH (READPAST)
            ON  C.[CNSCXC] COLLATE DATABASE_DEFAULT = LTRIM(RTRIM(S.[CNSCXC])) COLLATE DATABASE_DEFAULT
        WHERE  S.[CNSCXC] IS NOT NULL
          AND  LTRIM(RTRIM(S.[CNSCXC])) <> N''
          AND  S.[ID] > @EXP_DL
          AND  ( @IDLOTE IS NULL OR S.[IDLOTE] = @IDLOTE )
          AND  ( @F_N_FACTURA IS NULL OR S.[N_FACTURA] COLLATE DATABASE_DEFAULT = @F_N_FACTURA COLLATE DATABASE_DEFAULT )
          AND  ( @F_IDTERCERO IS NULL OR S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_IDTERCERO COLLATE DATABASE_DEFAULT )
          AND  (
                 @F_NIT IS NULL
                 OR  S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_NIT COLLATE DATABASE_DEFAULT
                 OR  ( @F_TER_NIT_ID IS NOT NULL AND S.[IDTERCERO] COLLATE DATABASE_DEFAULT = @F_TER_NIT_ID COLLATE DATABASE_DEFAULT )
               )
          AND  (
                 @F_TIENE_CXC IS NULL
              OR ( @F_TIENE_CXC = 1 AND S.[CNSCXC] IS NOT NULL AND S.[CNSCXC] <> N'' )
              OR ( @F_TIENE_CXC = 0 AND ( S.[CNSCXC] IS NULL OR S.[CNSCXC] = N'' ) )
               )
        ORDER BY S.[ID];

        RETURN;
    END

    SET @MENSAJE = N'METODO desconocido: ' + ISNULL(@METODO, N'');
    SELECT N'KO' AS [OK], @MENSAJE AS [MENSAJE];
END

