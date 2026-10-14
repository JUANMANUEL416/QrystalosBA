CREATE OR ALTER PROCEDURE DBO.SPQ_IARTO
@JSON  NVARCHAR(MAX)
WITH ENCRYPTION
AS
DECLARE
    @PARAMETROS     NVARCHAR(MAX) ,@MODELO       VARCHAR(100) ,@METODO    VARCHAR(100)
    ,@USUARIO        VARCHAR(12)   ,@SEDE         VARCHAR(5)   ,@A         INT
    -- Filtros LISTAR
    ,@FECHA_DESDE    DATETIME      ,@FECHA_HASTA  DATETIME
    ,@ESTADO_FILTRO  VARCHAR(10)   ,@USUARIO_FILTRO VARCHAR(12)
    -- Cabecera GUARDAR / APROBAR / ANULAR
    ,@ID             INT           ,@ESTADO       VARCHAR(10)
    ,@OBSERVACION    VARCHAR(500)  ,@MOTIVO_ANUL  VARCHAR(500)
    ,@IDTERCERO      VARCHAR(20)   ,@NOPROGRAMACION INT
    ,@NOADMISION     VARCHAR(20)   ,@IDAFILIADO     VARCHAR(20)
    ,@NOCIRUGIA      VARCHAR(20)
    ,@IDAFILIADO_HADM VARCHAR(20) ,@IDAFILIADO_CXPS VARCHAR(20) ,@IDAFILIADO_CXPI VARCHAR(20)
    ,@IDAFILIADO_ENVIADO VARCHAR(20)
    ,@NOCIRUGIA_CXPS VARCHAR(20)
    -- Filtro LISTAR: por programaci�n
    ,@NOPROGRAMACION_FILTRO INT
    ,@IDAFILIADO_FILTRO     VARCHAR(20)
    ,@NOADMISION_FILTRO     VARCHAR(20)
    ,@NOCIRUGIA_FILTRO      VARCHAR(20)
    ,@SOLICITUD_FILTRO      BIT
    -- Campo SOLICITUD (0=Gasto, 1=Solicitud)
    ,@SOLICITUD             BIT
    -- Campos de lote/bodega (obligatorios en Gasto)
    ,@IDBODEGA              VARCHAR(20)
    -- Cat�logo / Precio
    ,@IDTGEN         INT           ,@PRECIO_NUEVO DECIMAL(14,2)
    ,@COD_BUSCAR     VARCHAR(100)  ,@DESC_BUSCAR  VARCHAR(200)
    -- Detalle JSON
    ,@DETALLE_JSON   NVARCHAR(MAX)
    -- APROBAR (Gasto OSTEO): inventario + IZSOL + CXPSI
    ,@SYS_COMPUTERNAME_AP VARCHAR(254) ,@COMPANIA_AP VARCHAR(10)   ,@IDSEDE_AP VARCHAR(10)
    ,@CNSMOV_ENT VARCHAR(20) ,@CNSMOV_SAL VARCHAR(20) ,@CNSIZSOL_AP VARCHAR(20)
    ,@NODOC_ENT VARCHAR(30) ,@VLRCOMPRA_ENT DECIMAL(14,2)
    ,@IDCIR_CXPS VARCHAR(20) ,@IDPLAN_HADM VARCHAR(6) ,@SECTOR_HAB VARCHAR(30)
    ,@CCOSTO_UBEQ VARCHAR(20)
    ,@CCOSTO_CXPS VARCHAR(20) ,@IDAREA_CXPS VARCHAR(20)
    ,@NOLOTE_ICBU VARCHAR(20) ,@ITEM_LIN INT
    ,@IDART_LOOP VARCHAR(20) ,@CANT_LOOP INT ,@PCOSTO_LOOP DECIMAL(14,2)
    ,@FV_LOOP DATE ,@NLP_LOOP VARCHAR(20) ,@CNSIZSOLD_AP VARCHAR(20)
    ,@IDSERV_ART VARCHAR(20) ,@NOLOTE_IEXI VARCHAR(20) ,@IDART_REAL VARCHAR(20)
    ,@EST_MOV_SAL TINYINT
    ,@RN_I INT ,@MAX_RN INT
    ,@IDTIPOMOV_TMP VARCHAR(2)
    -- Variables de sistema para flujo OSTEO
    ,@IDMOVOST_ENTR VARCHAR(5)  -- USVGS: IDMOVOST_ENTR  (tipo mov entrada, ej: '04')
    ,@IDMOVOST_SAL  VARCHAR(5)  -- USVGS: IDMOVOST_SAL   (tipo mov salida,  ej: '01')
    ,@BODEGA_OSTEO  VARCHAR(20) -- USVGS: BODEGA_OSTEO   (bodega osteos�ntesis, ej: 'OS')
    ,@SUMINISTROEPS BIT         -- 1 = material suministrado por la EPS (omite flujo inventario)
    ,@IDPLAN VARCHAR(6)
    ,@IDAREA VARCHAR(20), @IDSERVICIO VARCHAR(20)
	DECLARE @FILAS_JSON NVARCHAR(MAX);
	DECLARE @SOLO_NUEVOS BIT = 0
	,@PREFIJO_OSTEO VARCHAR(6)
	,@IDITAR_OSTEO VARCHAR(2)
	,@IDARTICULO_SYNC VARCHAR(20)
	,@IDTARIFA_OSTEO VARCHAR(5)
BEGIN
    SET LANGUAGE Spanish
    SET DATEFORMAT dmy
    SET NOCOUNT ON

    SELECT @A = ISJSON(@JSON)
    IF @A = 0 BEGIN RAISERROR('Json: Formato Erroneo',16,1) RETURN END

    DECLARE @TBLERRORES TABLE (ERROR VARCHAR(1200))

    SELECT * INTO #JSON FROM OPENJSON(@JSON)
    WITH (
    MODELO     VARCHAR(100)  '$.MODELO',
    METODO     VARCHAR(100)  '$.METODO',
    USUARIO    VARCHAR(12)   '$.USUARIO',
    PARAMETROS NVARCHAR(MAX) AS JSON
    )
    SELECT @MODELO=MODELO,@METODO=METODO,@PARAMETROS=PARAMETROS,@USUARIO=USUARIO FROM #JSON

    IF COALESCE(@SEDE,'') = '' SELECT @SEDE = '01'

    -- --------------------------------------------------------
    -- LISTAR: paginado/filtrado de solicitudes
    -- --------------------------------------------------------
    IF @METODO = 'LISTAR'
    BEGIN
        SELECT
            @FECHA_DESDE           = FECHA_DESDE
            ,@FECHA_HASTA           = FECHA_HASTA
            ,@ESTADO_FILTRO         = ESTADO
            ,@USUARIO_FILTRO        = USUARIO_FILTRO
            ,@NOPROGRAMACION_FILTRO = NOPROGRAMACION
            ,@IDAFILIADO_FILTRO     = IDAFILIADO
            ,@NOADMISION_FILTRO     = NOADMISION
            ,@NOCIRUGIA_FILTRO      = NOCIRUGIA
            ,@SOLICITUD_FILTRO      = SOLICITUD
        FROM OPENJSON(@PARAMETROS)
        WITH (
            FECHA_DESDE    DATETIME     '$.FECHA_DESDE',
            FECHA_HASTA    DATETIME     '$.FECHA_HASTA',
            ESTADO         VARCHAR(10)  '$.ESTADO',
            USUARIO_FILTRO VARCHAR(12)  '$.USUARIO',
            NOPROGRAMACION INT          '$.NOPROGRAMACION',
            IDAFILIADO     VARCHAR(20)  '$.IDAFILIADO',
            NOADMISION     VARCHAR(20)  '$.NOADMISION',
            NOCIRUGIA      VARCHAR(20)  '$.NOCIRUGIA',
            SOLICITUD      BIT          '$.SOLICITUD'
        )
        SET @NOADMISION_FILTRO = NULLIF(@NOADMISION_FILTRO, '')
        SET @IDAFILIADO_FILTRO = NULLIF(@IDAFILIADO_FILTRO, '')
        SET @NOCIRUGIA_FILTRO  = NULLIF(@NOCIRUGIA_FILTRO, '')

        IF @FECHA_HASTA IS NOT NULL SET @FECHA_HASTA = DATEADD(DAY,1,@FECHA_HASTA)

        SELECT 'OK' OK  -- RS1: estado

        SELECT
            O.ID
            ,O.FECHA
            ,O.USUARIO
            ,O.IDSEDE
            ,O.IDTERCERO
            ,O.ESTADO
            ,O.OBSERVACION
            ,O.MOTIVO_ANUL
            ,O.FECHA_APRUEBA
            ,O.USUARIO_APRUEBA
            ,O.FECHA_ANULA
            ,O.FECHA_CREA
            ,COALESCE(O.REV_ESTERILIZACION, 0) AS REV_ESTERILIZACION
            ,O.FECHA_REV_ESTERILIZACION
            ,O.USUARIO_REV_ESTERILIZACION
            ,COUNT(D.ID)          AS NITEMS
            ,SUM(D.SUBTOTAL)      AS TOTAL
        FROM IARTO O
        LEFT JOIN IARTOD D ON D.IDIARTO = O.ID
        WHERE 1=1
            AND (@FECHA_DESDE    IS NULL OR O.FECHA  >= @FECHA_DESDE)
            AND (@FECHA_HASTA    IS NULL OR O.FECHA  <  @FECHA_HASTA)
            AND (@ESTADO_FILTRO         IS NULL OR COALESCE(@ESTADO_FILTRO,'') = '' OR O.ESTADO = @ESTADO_FILTRO)
            AND (@USUARIO_FILTRO        IS NULL OR COALESCE(@USUARIO_FILTRO,'') = '' OR O.USUARIO = @USUARIO_FILTRO)
            AND (
                (@NOCIRUGIA_FILTRO IS NOT NULL AND O.NOCIRUGIA = @NOCIRUGIA_FILTRO)
            OR (
                @NOCIRUGIA_FILTRO IS NULL
                AND (
                    (@NOPROGRAMACION_FILTRO IS NULL AND @NOADMISION_FILTRO IS NULL AND @IDAFILIADO_FILTRO IS NULL)
                    OR (@NOPROGRAMACION_FILTRO IS NOT NULL AND O.NOPROGRAMACION = @NOPROGRAMACION_FILTRO)
                    OR (@NOPROGRAMACION_FILTRO IS NOT NULL AND COALESCE(O.NOPROGRAMACION, 0) = 0
                        AND @NOADMISION_FILTRO IS NOT NULL AND O.NOADMISION = @NOADMISION_FILTRO)
                    OR (@NOPROGRAMACION_FILTRO IS NOT NULL AND COALESCE(O.NOPROGRAMACION, 0) = 0
                        AND @IDAFILIADO_FILTRO IS NOT NULL AND O.IDAFILIADO = @IDAFILIADO_FILTRO)
                    OR (@NOPROGRAMACION_FILTRO IS NULL AND @NOADMISION_FILTRO IS NOT NULL AND O.NOADMISION = @NOADMISION_FILTRO)
                    OR (@NOPROGRAMACION_FILTRO IS NULL AND @IDAFILIADO_FILTRO IS NOT NULL AND O.IDAFILIADO = @IDAFILIADO_FILTRO)
                )
            )
            )
            AND (@SOLICITUD_FILTRO      IS NULL OR O.SOLICITUD       = @SOLICITUD_FILTRO)
        GROUP BY
            O.ID,O.FECHA,O.USUARIO,O.IDSEDE,O.IDTERCERO,O.ESTADO
            ,O.OBSERVACION,O.MOTIVO_ANUL,O.FECHA_APRUEBA,O.USUARIO_APRUEBA
            ,O.FECHA_ANULA,O.FECHA_CREA,O.REV_ESTERILIZACION
            ,O.FECHA_REV_ESTERILIZACION,O.USUARIO_REV_ESTERILIZACION
        ORDER BY O.ID DESC
        RETURN
    END

    -- --------------------------------------------------------
    -- CONSULTAR: cabecera + detalle por ID
    -- --------------------------------------------------------
    IF @METODO = 'CONSULTAR'
    BEGIN
        SELECT @ID = ID FROM OPENJSON(@PARAMETROS) WITH (ID INT '$.ID')

        SELECT 'OK' OK  -- RS1: estado

        -- RS2: Cabecera
        SELECT * FROM IARTO WHERE ID = @ID

        -- RS3: Detalle
        SELECT
            D.ID, D.IDIARTO, D.IDTERCERO, D.REFERENCIA, D.IDTGEN
            ,D.IDARTICULO, D.DESCRIPCION, D.CANTIDAD, D.PRECIO
            ,D.SUBTOTAL, D.PRECIO_CATALOGO
            ,COALESCE(D.PRECIO - D.PRECIO_CATALOGO, 0) AS DIFF_PRECIO
            ,D.NOLOTEPEDIDO
            ,D.FECHAVENCE
        FROM IARTOD D
        WHERE D.IDIARTO = @ID
        ORDER BY D.ID
        RETURN
    END

    -- --------------------------------------------------------
    -- CONSULTAR_PDF: encabezado enriquecido + detalle para impresi�n
    -- Agrupado por IDTERCERO (una p�gina por casa comercial)
    -- --------------------------------------------------------
    IF @METODO = 'CONSULTAR_PDF'
    BEGIN
        SELECT @ID = ID FROM OPENJSON(@PARAMETROS) WITH (ID INT '$.ID')

        SELECT 'OK' OK  -- RS1: estado

        -- RS2: Encabezado enriquecido (SOLICITUD: 0=gasto, 1=solicitud; el front usa esto para el PDF)
        SELECT
            IARTO.ID
            ,IARTO.ESTADO
            ,COALESCE(IARTO.REV_ESTERILIZACION, 0) AS REV_ESTERILIZACION
            ,IARTO.FECHA_REV_ESTERILIZACION
            ,IARTO.USUARIO_REV_ESTERILIZACION
            ,USUSU_REV.NOMBRE            AS NOMBRE_REV_ESTERILIZACION
            ,CONVERT(VARCHAR, IARTO.FECHA, 103) + ' ' + LEFT(CONVERT(VARCHAR, IARTO.FECHA, 108), 5) AS FECHA_SOLICITUD
            ,USUSU.NOMBRE                AS RESPONSABLE
            ,IARTO.SOLICITUD
            ,IARTO.SUMINISTROEPS
            ,IARTO.NOADMISION
            ,AFI.TIPO_DOC
            ,AFI.DOCIDAFILIADO
            ,COALESCE(AFI.NOMBREAFI, LTRIM(RTRIM(COALESCE(AFI.PNOMBRE,'') + ' ' +
                                                COALESCE(AFI.PAPELLIDO,'')))) AS NOMBRE_PACIENTE
            ,SER.DESCSERVICIO            AS PROCEDIMIENTO
            ,TER.RAZONSOCIAL             AS ENTIDAD
        FROM IARTO
        INNER JOIN CXPS  ON CXPS.NOPROGRAMACION = IARTO.NOPROGRAMACION
        INNER JOIN USUSU ON IARTO.USUARIO        = USUSU.USUARIO
        LEFT  JOIN USUSU USUSU_REV ON USUSU_REV.USUARIO = IARTO.USUARIO_REV_ESTERILIZACION
        INNER JOIN AFI   ON AFI.IDAFILIADO       = IARTO.IDAFILIADO
        LEFT  JOIN HADM  ON HADM.NOADMISION      = IARTO.NOADMISION
        LEFT  JOIN SER   ON SER.IDSERVICIO       = CXPS.IDSERVICIO
        LEFT  JOIN TER   ON TER.IDTERCERO        = COALESCE(HADM.IDTERCERO, AFI.IDADMINISTRADORA)
        WHERE IARTO.ID = @ID

        -- RS3: Detalle ordenado por casa comercial y descripci�n
        -- Lote y vencimiento solo cuando es gasto (SOLICITUD = 0); en solicitud van NULL
        SELECT
            D.IDTERCERO
            ,D.IDARTICULO
            ,D.REFERENCIA
            ,D.DESCRIPCION
            ,D.CANTIDAD
            ,D.PRECIO
            ,D.SUBTOTAL
            ,CASE WHEN I.SOLICITUD = 0 THEN D.NOLOTEPEDIDO ELSE NULL END AS NOLOTEPEDIDO
            ,CASE WHEN I.SOLICITUD = 0 THEN CONVERT(VARCHAR(10), D.FECHAVENCE, 103) ELSE NULL END AS FECHAVENCE
        FROM IARTOD D
        INNER JOIN IARTO I ON I.ID = D.IDIARTO
        WHERE D.IDIARTO = @ID
        ORDER BY D.IDTERCERO, D.DESCRIPCION

        -- RS4: Firmas - Instrumentador (izquierda) y Cirujano (derecha)
        -- Instrumentador: usuario que gener� el documento ? USUSU.IDMEDICO ? MED ? ARCHIVOS
        -- Cirujano: cirujano principal de la programaci�n ? CXPS.IDMEDICO ? MED ? ARCHIVOS
        DECLARE @NOMBRE_INST    VARCHAR(45)   ,@REGISTRO_INST  VARCHAR(20)   ,@FIRMA_BIN_INST VARBINARY(MAX)
        DECLARE @NOMBRE_CIR     VARCHAR(45)   ,@REGISTRO_CIR   VARCHAR(20)   ,@FIRMA_BIN_CIR  VARBINARY(MAX)
        DECLARE @FIRMA_B64_INST VARCHAR(MAX)  ,@FIRMA_B64_CIR  VARCHAR(MAX)

        SELECT
            @NOMBRE_INST    = COALESCE(M.NOMBRE, U.NOMBRE)
            ,@REGISTRO_INST  = M.NO_REGISTRO
            ,@FIRMA_BIN_INST = A.DICOM
        FROM IARTO I
        INNER JOIN USUSU    U ON U.USUARIO  = I.USUARIO
        LEFT  JOIN MED      M ON M.IDMEDICO = U.IDMEDICO
        LEFT  JOIN ARCHIVOS A ON A.ID       = M.IDFIRMA
        WHERE I.ID = @ID

        SELECT
            @NOMBRE_CIR    = M.NOMBRE
            ,@REGISTRO_CIR  = M.NO_REGISTRO
            ,@FIRMA_BIN_CIR = A.DICOM
        FROM IARTO I
        INNER JOIN CXPS     C ON C.NOPROGRAMACION = I.NOPROGRAMACION
        LEFT  JOIN MED      M ON M.IDMEDICO       = C.IDMEDICO
        LEFT  JOIN ARCHIVOS A ON A.ID             = M.IDFIRMA
        WHERE I.ID = @ID

        IF @FIRMA_BIN_INST IS NOT NULL
            SELECT @FIRMA_B64_INST = CAST(N'' AS XML).value('xs:base64Binary(xs:hexBinary(sql:column("bin")))', 'VARCHAR(MAX)')
            FROM (SELECT @FIRMA_BIN_INST AS bin) AS T

        IF @FIRMA_BIN_CIR IS NOT NULL
            SELECT @FIRMA_B64_CIR = CAST(N'' AS XML).value('xs:base64Binary(xs:hexBinary(sql:column("bin")))', 'VARCHAR(MAX)')
            FROM (SELECT @FIRMA_BIN_CIR AS bin) AS T

        SELECT 'INSTRUMENTADOR' AS ROL, COALESCE(@NOMBRE_INST,'') AS NOMBRE, COALESCE(@REGISTRO_INST,'') AS NO_REGISTRO, @FIRMA_B64_INST AS FIRMA
        UNION ALL
        SELECT 'CIRUJANO', COALESCE(@NOMBRE_CIR,''), COALESCE(@REGISTRO_CIR,''), @FIRMA_B64_CIR

        RETURN
    END

    -- --------------------------------------------------------
    -- GUARDAR: insert/update cabecera + replace detalle (transaccional)
    -- --------------------------------------------------------
    IF @METODO = 'GUARDAR'
    BEGIN
        SELECT
            @ID             = ID
            ,@OBSERVACION    = OBSERVACION
            ,@IDTERCERO      = IDTERCERO
            ,@NOPROGRAMACION = NOPROGRAMACION
            ,@NOADMISION     = NOADMISION
            ,@IDAFILIADO     = IDAFILIADO
            ,@NOCIRUGIA      = NOCIRUGIA
            ,@SOLICITUD      = SOLICITUD
            ,@IDBODEGA       = IDBODEGA
            ,@SUMINISTROEPS  = SUMINISTROEPS
	        ,@IDPLAN		   = IDPLAN
            ,@DETALLE_JSON   = DETALLE
        FROM OPENJSON(@PARAMETROS)
        WITH (
            ID              INT            '$.ID',
            OBSERVACION     VARCHAR(500)   '$.OBSERVACION',
            IDTERCERO       VARCHAR(20)    '$.IDTERCERO',
            NOPROGRAMACION  INT            '$.NOPROGRAMACION',
            NOADMISION      VARCHAR(20)    '$.NOADMISION',
            IDAFILIADO      VARCHAR(20)    '$.IDAFILIADO',
            NOCIRUGIA       VARCHAR(20)    '$.NOCIRUGIA',
            SOLICITUD       BIT            '$.SOLICITUD',
            IDBODEGA        VARCHAR(20)    '$.IDBODEGA',
            SUMINISTROEPS   BIT            '$.SUMINISTROEPS',
	        IDPLAN		  VARCHAR(6)	 '$.IDPLAN',
            DETALLE         NVARCHAR(MAX)  AS JSON
        )
	
        SET @NOCIRUGIA  = NULLIF(LTRIM(RTRIM(@NOCIRUGIA)), '')
        SET @NOADMISION = NULLIF(LTRIM(RTRIM(@NOADMISION)), '')
        SET @IDAFILIADO = NULLIF(LTRIM(RTRIM(@IDAFILIADO)), '')
        SET @IDAFILIADO_ENVIADO = @IDAFILIADO

        -- Validar que hay al menos 1 l�nea de detalle
        IF (SELECT COUNT(*) FROM OPENJSON(@DETALLE_JSON)) = 0
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'La solicitud debe tener al menos un art�culo en el detalle.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF COALESCE(@NOADMISION,'') = ''
            SELECT @NOADMISION = NOADMISION FROM QXPCX WHERE NOPROGRAMACION = @NOPROGRAMACION
        -- QXPCX puede no existir a�n para esa programaci�n; la programaci�n en CXPS suele traer NOADMISION
        IF COALESCE(@NOADMISION,'') = ''
            SELECT @NOADMISION = NOADMISION FROM CXPS WHERE NOPROGRAMACION = @NOPROGRAMACION

        IF COALESCE(@IDAFILIADO,'') = ''
            SELECT @IDAFILIADO = IDAFILIADO FROM HADM WHERE NOADMISION = @NOADMISION

        IF COALESCE(@IDAFILIADO,'') = ''
            SELECT @IDAFILIADO = IDAFILIADO FROM CXPS WHERE NOPROGRAMACION = @NOPROGRAMACION

        -- Resolver contexto desde NOCIRUGIA (ancla CXPI)
        IF COALESCE(@NOCIRUGIA,'') <> ''
        BEGIN
            IF COALESCE(@IDAFILIADO,'') = ''
            SELECT @IDAFILIADO = IDAFILIADO FROM CXPI WHERE NOCIRUGIA = @NOCIRUGIA

            IF COALESCE(@NOADMISION,'') = ''
            SELECT @NOADMISION = NOADMISION FROM CXPI WHERE NOCIRUGIA = @NOCIRUGIA

            IF COALESCE(@NOPROGRAMACION, 0) = 0
            SELECT TOP 1 @NOPROGRAMACION = NOPROGRAMACION
            FROM CXPS
            WHERE NOCIRUGIA = @NOCIRUGIA
            ORDER BY NOPROGRAMACION DESC
        END
        ELSE IF COALESCE(@NOPROGRAMACION, 0) > 0
        BEGIN
            SELECT TOP 1 @NOCIRUGIA = NOCIRUGIA
            FROM CXPS
            WHERE NOPROGRAMACION = @NOPROGRAMACION
            AND NULLIF(LTRIM(RTRIM(NOCIRUGIA)), '') IS NOT NULL
        END
        ELSE IF COALESCE(@NOADMISION,'') <> '' AND COALESCE(@IDAFILIADO,'') <> ''
        BEGIN
            SELECT TOP 1 @NOCIRUGIA = NOCIRUGIA
            FROM CXPI
            WHERE NOADMISION = @NOADMISION
            AND IDAFILIADO = @IDAFILIADO
            AND COALESCE(ESTADO, '') <> 'ANULADO'
            ORDER BY FECHA DESC, NOCIRUGIA DESC
        END

        -- Validar que admision, programacion y cirugia pertenezcan al mismo afiliado.
        IF COALESCE(@NOPROGRAMACION, 0) > 0
        BEGIN
            SELECT TOP 1
                @NOCIRUGIA_CXPS = NULLIF(LTRIM(RTRIM(NOCIRUGIA)), ''),
                @IDAFILIADO_CXPS = NULLIF(LTRIM(RTRIM(IDAFILIADO)), '')
            FROM CXPS
            WHERE NOPROGRAMACION = @NOPROGRAMACION

            IF @NOCIRUGIA IS NOT NULL AND @NOCIRUGIA_CXPS IS NOT NULL AND @NOCIRUGIA <> @NOCIRUGIA_CXPS
            BEGIN
                INSERT INTO @TBLERRORES SELECT 'La cirugia enviada no corresponde al numero de programacion.'
                SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
            END
        END

        IF COALESCE(@NOCIRUGIA, '') <> ''
            SELECT TOP 1 @IDAFILIADO_CXPI = NULLIF(LTRIM(RTRIM(IDAFILIADO)), '')
            FROM CXPI
            WHERE NOCIRUGIA = @NOCIRUGIA

        IF COALESCE(@NOADMISION, '') <> ''
        BEGIN
            SELECT @IDAFILIADO_HADM = NULLIF(LTRIM(RTRIM(IDAFILIADO)), '')
            FROM HADM
            WHERE NOADMISION = @NOADMISION

            IF COALESCE(@IDAFILIADO_HADM, '') = ''
            BEGIN
                INSERT INTO @TBLERRORES SELECT 'La admision indicada no existe o no tiene un afiliado asociado.'
                SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
            END

            IF @IDAFILIADO IS NOT NULL AND @IDAFILIADO <> @IDAFILIADO_HADM
            BEGIN
                INSERT INTO @TBLERRORES SELECT 'El afiliado enviado no corresponde a la admision indicada.'
                SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
            END

            SET @IDAFILIADO = @IDAFILIADO_HADM
        END
        ELSE
        BEGIN
            IF @IDAFILIADO_ENVIADO IS NOT NULL
               AND COALESCE(@IDAFILIADO_CXPS, @IDAFILIADO_CXPI) IS NOT NULL
               AND @IDAFILIADO_ENVIADO <> COALESCE(@IDAFILIADO_CXPS, @IDAFILIADO_CXPI)
            BEGIN
                INSERT INTO @TBLERRORES SELECT 'El afiliado enviado no corresponde a la programacion o cirugia indicada.'
                SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
            END

            SET @IDAFILIADO = COALESCE(@IDAFILIADO_CXPS, @IDAFILIADO_CXPI, @IDAFILIADO)
        END

        IF @IDAFILIADO_CXPS IS NOT NULL AND @IDAFILIADO IS NOT NULL AND @IDAFILIADO_CXPS <> @IDAFILIADO
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'El afiliado de CXPS no coincide con el contexto validado de la solicitud.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF @IDAFILIADO_CXPI IS NOT NULL AND @IDAFILIADO IS NOT NULL AND @IDAFILIADO_CXPI <> @IDAFILIADO
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'El afiliado de CXPI no coincide con el contexto validado de la solicitud.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        -- Normalizar '' -> NULL antes de persistir
        SET @NOADMISION = NULLIF(@NOADMISION, '')
        SET @IDAFILIADO = NULLIF(@IDAFILIADO, '')
        SET @NOCIRUGIA  = NULLIF(@NOCIRUGIA, '')

        IF COALESCE(@NOCIRUGIA,'') = '' AND COALESCE(@IDAFILIADO,'') = ''
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'Debe indicar NOCIRUGIA o datos suficientes (paciente/admisi�n/programaci�n) para vincular la solicitud.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        -- Auto-resolver IDBODEGA desde equipo del usuario si no viene
        IF COALESCE(@IDBODEGA,'') = ''
            SELECT TOP 1 @IDBODEGA = U2.IDBODEGA
            FROM USUSU U
            INNER JOIN UBEQ U2 ON U2.SYS_COMPUTERNAME = U.SYS_COMPUTERNAME
            WHERE U.USUARIO = @USUARIO

        -- Validar campos obligatorios para Gasto (SOLICITUD = 0)
        IF COALESCE(@SOLICITUD, 1) = 0
        BEGIN
	
            IF COALESCE(@SUMINISTROEPS, 0) = 0
            BEGIN
		        DECLARE @FECHAVENCE_DEFAULT DATE = DATEADD(YEAR, 1, CONVERT(DATE, GETDATE()));
		        IF EXISTS (
		            SELECT 1
		            FROM OPENJSON(@DETALLE_JSON)
		            WITH (
			        FECHAVENCE_TXT NVARCHAR(30) '$.FECHAVENCE',
			        NOLOTEPEDIDO   VARCHAR(20)  '$.NOLOTEPEDIDO'
		            )
		            WHERE
			        COALESCE(NOLOTEPEDIDO,'') = ''
			        OR (
			            NULLIF(LTRIM(RTRIM(FECHAVENCE_TXT)),'') IS NOT NULL
			            AND TRY_CONVERT(DATE, FECHAVENCE_TXT) IS NULL
			        )
		        )
		        BEGIN
		            INSERT INTO @TBLERRORES
		            SELECT 'En Hoja de Gasto, todas las l�neas deben tener N�mero de Lote y FECHAVENCE.'
		            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
		        END
            END
            IF COALESCE(@IDBODEGA,'') = ''
            BEGIN
                INSERT INTO @TBLERRORES 
                SELECT 'No se pudo determinar la bodega del usuario. Verifique la configuraci�n del equipo.'
                SELECT 'KO' OK 
                SELECT ERROR FROM @TBLERRORES 
                RETURN
            END
        END

        -- Validar cantidad y precio en cada l�nea
        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DETALLE_JSON)
            WITH (CANTIDAD INT '$.CANTIDAD', PRECIO DECIMAL(14,2) '$.PRECIO')
            WHERE COALESCE(CANTIDAD,0) <= 0 OR COALESCE(PRECIO,0) < 0
        )
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'Existen l�neas con cantidad <= 0 o precio negativo.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END
	
        -- Si EDITAR, verificar que no est� APROBADO/ANULADO
        IF COALESCE(@ID,0) > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM IARTO WHERE ID=@ID AND ESTADO IN ('APROBADO','ANULADO'))
            BEGIN
                INSERT INTO @TBLERRORES SELECT 'No se puede editar una solicitud en estado APROBADO o ANULADO.'
                SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
            END
        END

        -- Casa comercial (proveedor remisi�n): TGEN.DATO5 por l�nea IART_OSTEO
        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@DETALLE_JSON)
            WITH (
            IDTGEN     INT          '$.IDTGEN',
            REFERENCIA VARCHAR(100) '$.REFERENCIA'
            ) D
            WHERE NULLIF(LTRIM(RTRIM(
            (SELECT TOP 1 T.DATO5
                FROM TGEN T
                WHERE T.IDTGEN = D.IDTGEN AND T.TABLA = 'IART_OSTEO')
            )), '') IS NULL
        )
        BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT TOP 1
            CONCAT(
                'Casa comercial no configurada para el item ',
                COALESCE(NULLIF(LTRIM(RTRIM(D.REFERENCIA)), ''), CAST(D.IDTGEN AS VARCHAR(20)))
            )
            FROM OPENJSON(@DETALLE_JSON)
            WITH (
                IDTGEN     INT          '$.IDTGEN',
                REFERENCIA VARCHAR(100) '$.REFERENCIA'
            ) D
            WHERE NULLIF(LTRIM(RTRIM(
                (SELECT TOP 1 T.DATO5
                    FROM TGEN T
                    WHERE T.IDTGEN = D.IDTGEN AND T.TABLA = 'IART_OSTEO')
                )), '') IS NULL

            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END

        BEGIN TRY
            BEGIN TRANSACTION
                IF COALESCE(@ID,0) = 0
                BEGIN
	                SELECT @IDBODEGA = DBO.FNK_VALORVARIABLE('IBODOSTEO_CX') 
                    INSERT INTO IARTO (FECHA, USUARIO, IDSEDE, IDTERCERO, NOPROGRAMACION, NOADMISION, IDAFILIADO, NOCIRUGIA,
                                        SOLICITUD, ESTADO, OBSERVACION, IDBODEGA, SUMINISTROEPS, IDPLAN)
                    SELECT GETDATE(), @USUARIO, @SEDE, @IDTERCERO, @NOPROGRAMACION, @NOADMISION, @IDAFILIADO, @NOCIRUGIA,
                            COALESCE(@SOLICITUD, 1), 'GENERADO', @OBSERVACION, @IDBODEGA, COALESCE(@SUMINISTROEPS, 0), @IDPLAN
                    SET @ID = SCOPE_IDENTITY()
                END
                ELSE  
                BEGIN
                    UPDATE IARTO SET
                        OBSERVACION    = @OBSERVACION
                        ,IDTERCERO      = @IDTERCERO
                        ,NOPROGRAMACION = @NOPROGRAMACION
                        ,NOADMISION     = @NOADMISION
                        ,IDAFILIADO     = @IDAFILIADO
                        ,NOCIRUGIA      = @NOCIRUGIA
                        ,IDBODEGA       = @IDBODEGA
                        ,SUMINISTROEPS  = COALESCE(@SUMINISTROEPS, 0)
                        ,FECHA_MOD      = GETDATE()
		                ,IDPLAN		  = @IDPLAN
                    WHERE ID = @ID
                END
	  
                -- Replace detalle (borra y reinserta en transacci�n)
                DELETE IARTOD WHERE IDIARTO = @ID

                INSERT INTO IARTOD (IDIARTO, IDTERCERO, REFERENCIA, IDTGEN, IDARTICULO, DESCRIPCION,
                                    CANTIDAD, PRECIO, PRECIO_CATALOGO, FECHAVENCE, NOLOTEPEDIDO)						 
                SELECT
                    @ID
                    ,COALESCE(
                        NULLIF(LTRIM(RTRIM((
                            SELECT TOP 1 T.DATO5
                            FROM TGEN T
                            WHERE T.IDTGEN = D.IDTGEN AND T.TABLA = 'IART_OSTEO'
                        ))), ''),
                        NULLIF(LTRIM(RTRIM(D.IDTERCERO)), '')
                        ) AS IDTERCERO
                    ,D.REFERENCIA
                    ,D.IDTGEN
                    ,D.IDARTICULO
                    ,D.DESCRIPCION
                    ,D.CANTIDAD
                    ,D.PRECIO
                    ,D.PRECIO_CATALOGO
	                ,COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(D.FECHAVENCE_TXT)), '')),@FECHAVENCE_DEFAULT) AS FECHAVENCE
                    ,D.NOLOTEPEDIDO
                FROM OPENJSON(@DETALLE_JSON)
                WITH (
                    IDTERCERO       VARCHAR(20)    '$.IDTERCERO',
                    REFERENCIA      VARCHAR(100)   '$.REFERENCIA',
                    IDTGEN          INT            '$.IDTGEN',
                    IDARTICULO      VARCHAR(20)    '$.IDARTICULO',
                    DESCRIPCION     VARCHAR(500)   '$.DESCRIPCION',
                    CANTIDAD        INT            '$.CANTIDAD',
                    PRECIO          DECIMAL(14,2)  '$.PRECIO',
                    PRECIO_CATALOGO DECIMAL(14,2)  '$.PRECIO_CATALOGO',
                    FECHAVENCE_TXT  NVARCHAR(30)  '$.FECHAVENCE',
                    NOLOTEPEDIDO    VARCHAR(20)    '$.NOLOTEPEDIDO'
                ) D
            COMMIT TRANSACTION
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            INSERT INTO @TBLERRORES SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN 
            SELECT 'KO' OK 
            SELECT ERROR FROM @TBLERRORES 
            RETURN 
        END
        SELECT 'OK' OK, @ID ID
        RETURN
    END

    -- --------------------------------------------------------
    -- APROBAR: cambia estado a APROBADO
    --   SOLICITUD=0 (Hoja de Gasto OSTEO): entrada 04 (remisi�n) en bodega OS,
    --   confirma entrada, genera IZSOL CLASE='OSTEO', salida 01 con mismos lotes,
    --   confirma salida, CXPSI: UPDATE filas sin CNSMOV + INSERT por IDSERVICIO (IART) con CNSMOV salida, PEDIDOINV=1.
    --   SOLICITUD=1 (Solicitud cotizaci�n): solo aprueba cabecera.
    -- --------------------------------------------------------
    IF @METODO = 'APROBAR'
    BEGIN
        DECLARE @TRN_INI INT = @@TRANCOUNT
        SELECT @ID = ID FROM OPENJSON(@PARAMETROS) WITH (ID INT '$.ID')
        SELECT
            @SOLICITUD       = SOLICITUD
            ,@NOPROGRAMACION  = NOPROGRAMACION
            ,@NOADMISION      = NOADMISION
            ,@IDAFILIADO      = IDAFILIADO
            ,@IDBODEGA        = IDBODEGA
            ,@SUMINISTROEPS   = SUMINISTROEPS
        FROM IARTO WHERE ID = @ID
        IF NOT EXISTS (SELECT 1 FROM IARTO WHERE ID=@ID AND ESTADO='GENERADO')
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'Solo se pueden aprobar solicitudes en estado GENERADO.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END
        BEGIN TRY
            IF @TRN_INI = 0
                BEGIN TRANSACTION
            ELSE
                SAVE TRANSACTION SPQ_IARTO_APROBAR


        IF @SOLICITUD = 0 AND COALESCE(@SUMINISTROEPS, 0) = 0
        BEGIN
            DECLARE @T_DET TABLE (
                RN INT IDENTITY(1,1) PRIMARY KEY
                ,IDTERCERO    VARCHAR(20)
                ,IDARTICULO   VARCHAR(20)
                ,CANTIDAD     INT
                ,PRECIO       DECIMAL(14,2)
                ,FECHAVENCE   DATE
                ,NOLOTEPEDIDO VARCHAR(20)
            ) ;
            DECLARE @T_IZSOLD_RN TABLE (
                RN INT PRIMARY KEY
                ,CNSIZSOLD  VARCHAR(20)
                ,IDARTICULO VARCHAR(20)
                ,CANTIDADSOL INT
                ,NOLOTEPEDIDO VARCHAR(20)
            )
            DECLARE @IZSOL_REF VARCHAR(20), @IDTER_SALIDA_AP VARCHAR(20)

            SELECT @SYS_COMPUTERNAME_AP = SYS_COMPUTERNAME FROM USUSU WHERE USUARIO = @USUARIO
            IF COALESCE(@SYS_COMPUTERNAME_AP,'') = ''
                RAISERROR('El usuario no tiene equipo asignado en USUSU/SYS_COMPUTERNAME.', 16, 1)

            SELECT @IDSEDE_AP = IDSEDE, @COMPANIA_AP = COMPANIA, @CCOSTO_UBEQ = CCOSTO
            FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME_AP
            IF @@ROWCOUNT = 0
                RAISERROR('El equipo del usuario no existe en UBEQ.', 16, 1)

            -- Cargar variables de sistema para flujo OSTEO
            SELECT
                @IDMOVOST_ENTR = RTRIM(DBO.FNK_VALORVARIABLE('IDMOVOST_ENTR'))
                ,@IDMOVOST_SAL  = RTRIM(DBO.FNK_VALORVARIABLE('IDMOVOST_SAL'))
                ,@BODEGA_OSTEO  = RTRIM(DBO.FNK_VALORVARIABLE('IBODOSTEO_CX'))

            IF COALESCE(@BODEGA_OSTEO,'') = ''
                RAISERROR('La variable de sistema BODEGA_OSTEO no est� configurada. Configure la bodega de osteos�ntesis.', 16, 1)
            IF NOT EXISTS (SELECT 1 FROM IBOD WHERE IDBODEGA = @BODEGA_OSTEO)
                RAISERROR('La bodega configurada en BODEGA_OSTEO (%s) no existe en IBOD.', 16, 1, @BODEGA_OSTEO)

            IF COALESCE(@IDMOVOST_ENTR,'') = ''
                RAISERROR('La variable de sistema IDMOVOST_ENTR no est� configurada. Configure el tipo de movimiento de entrada para osteos�ntesis.', 16, 1)
            IF NOT EXISTS (SELECT 1 FROM ITMO WHERE IDTIPOMOV = @IDMOVOST_ENTR)
                RAISERROR('El tipo de movimiento configurado en IDMOVOST_ENTR (%s) no existe en ITMO.', 16, 1, @IDMOVOST_ENTR)

            IF COALESCE(@IDMOVOST_SAL,'') = ''
                RAISERROR('La variable de sistema IDMOVOST_SAL no est� configurada. Configure el tipo de movimiento de salida para osteos�ntesis.', 16, 1)
            IF NOT EXISTS (SELECT 1 FROM ITMO WHERE IDTIPOMOV = @IDMOVOST_SAL)
                RAISERROR('El tipo de movimiento configurado en IDMOVOST_SAL (%s) no existe en ITMO.', 16, 1, @IDMOVOST_SAL)

            SET @IDBODEGA = @BODEGA_OSTEO

            INSERT INTO @T_DET (IDTERCERO, IDARTICULO, CANTIDAD, PRECIO, FECHAVENCE, NOLOTEPEDIDO)
            SELECT IDTERCERO, IDARTICULO, CANTIDAD, PRECIO, FECHAVENCE, NOLOTEPEDIDO
            FROM IARTOD WHERE IDIARTO = @ID

            IF NOT EXISTS (SELECT 1 FROM @T_DET)
                RAISERROR('La hoja de gasto no tiene detalle.', 16, 1)

		    UPDATE @T_DET
            SET FECHAVENCE = DATEADD(YEAR, 1, CONVERT(date, SYSDATETIME()))
            WHERE FECHAVENCE IS NULL

            IF EXISTS (SELECT 1 FROM @T_DET WHERE FECHAVENCE IS NULL OR COALESCE(NOLOTEPEDIDO,'') = '')
                RAISERROR('Cada l�nea debe tener Fecha de Vencimiento y N�mero de Lote (NOLOTEPEDIDO).', 16, 1)

            SELECT @VLRCOMPRA_ENT = SUM(CAST(CANTIDAD AS DECIMAL(14,2)) * PRECIO) FROM @T_DET

            SELECT
                @IDCIR_CXPS = IDSERVICIO
                ,@CCOSTO_CXPS = CCOSTO
                ,@IDAREA_CXPS = IDAREA
            FROM CXPS
            WHERE NOPROGRAMACION = @NOPROGRAMACION
            IF COALESCE(@IDCIR_CXPS,'') = ''
                RAISERROR('No se encontr� CXPS para el n�mero de programaci�n.', 16, 1)

            IF COALESCE(@NOADMISION,'') = ''
                SELECT @NOADMISION = NOADMISION FROM QXPCX WHERE NOPROGRAMACION = @NOPROGRAMACION
            IF COALESCE(@NOADMISION,'') = ''
                SELECT @NOADMISION = NOADMISION FROM CXPS WHERE NOPROGRAMACION = @NOPROGRAMACION

            -- IZSOL.NOADMISION: admisi�n real si existe; si no, n�mero de programaci�n (mismo criterio que b�squedas QX en pantallas)
            SET @IZSOL_REF = COALESCE(NULLIF(RTRIM(@NOADMISION), ''), CAST(@NOPROGRAMACION AS VARCHAR(20)))

            SET @IDPLAN_HADM = NULL
            SET @SECTOR_HAB = NULL
            SET @IDTER_SALIDA_AP = NULL
            IF COALESCE(@NOADMISION,'') <> ''
            BEGIN
                SELECT @IDPLAN_HADM = IDPLAN FROM HADM WHERE NOADMISION = @NOADMISION
                SELECT TOP 1 @SECTOR_HAB = SECTOR FROM HHAB WHERE NOADMISION = @NOADMISION
            END
            IF COALESCE(@IDPLAN_HADM,'') = '' AND COALESCE(@IDAFILIADO,'') <> ''
                SELECT @IDPLAN_HADM = IDPLAN FROM AFI WHERE IDAFILIADO = @IDAFILIADO
            IF COALESCE(@SECTOR_HAB,'') = ''
                SET @SECTOR_HAB = COALESCE(@CCOSTO_UBEQ, 'CX')

            -- Centro de costo / �rea: CXPS; si falta y hay cama (admisi�n), HHAB
            IF (COALESCE(@CCOSTO_CXPS,'') = '' OR COALESCE(@IDAREA_CXPS,'') = '') AND COALESCE(@NOADMISION,'') <> ''
            BEGIN
                SELECT TOP 1
                    @CCOSTO_CXPS = COALESCE(NULLIF(RTRIM(@CCOSTO_CXPS),''), HHAB.CCOSTO)
                ,@IDAREA_CXPS = COALESCE(NULLIF(RTRIM(@IDAREA_CXPS),''), HHAB.IDAREA)
                FROM HHAB
                WHERE HHAB.NOADMISION = @NOADMISION
            END
            IF COALESCE(@CCOSTO_CXPS,'') = ''
                SET @CCOSTO_CXPS = @CCOSTO_UBEQ

            -- Tercero para IMOV salida: HADM si hay admisi�n; si no, administradora del afiliado
            IF COALESCE(@NOADMISION,'') <> ''
                SELECT TOP 1 @IDTER_SALIDA_AP = IDTERCERO FROM HADM WHERE NOADMISION = @NOADMISION
            IF COALESCE(@IDTER_SALIDA_AP,'') = '' AND COALESCE(@IDAFILIADO,'') <> ''
                SELECT TOP 1 @IDTER_SALIDA_AP = IDADMINISTRADORA FROM AFI WHERE IDAFILIADO = @IDAFILIADO

            SET @NODOC_ENT = 'IARTO-' + CAST(@ID AS VARCHAR(12))
		    -- Validar que todas las l�neas tengan proveedor (sin exigir que sea el mismo)
		    IF EXISTS (SELECT 1 FROM @T_DET WHERE NULLIF(LTRIM(RTRIM(IDTERCERO)), '') IS NULL)
		    BEGIN
		        RAISERROR('Todas las l�neas deben tener proveedor (IDTERCERO) para la remisi�n.', 16, 1)
		        RETURN
		    END

		    DECLARE @IDTERCERO_CUR VARCHAR(20)
		    DECLARE @VLRCOMPRA_TER DECIMAL(18,2)   -- ajusta precisi�n si aplica
		    DECLARE @MAX_RN_TER INT
		    DECLARE @RN_TER INT

		    DECLARE cur_terceros CURSOR LOCAL FAST_FORWARD FOR
		        SELECT IDTERCERO
		        FROM @T_DET
		        GROUP BY IDTERCERO
		        ORDER BY IDTERCERO

		    OPEN cur_terceros
		    FETCH NEXT FROM cur_terceros INTO @IDTERCERO_CUR

		    WHILE @@FETCH_STATUS = 0
		    BEGIN
		        -- Valor compra solo de este proveedor
		        SELECT @VLRCOMPRA_TER = SUM(D.CANTIDAD * D.PRECIO)
		        FROM @T_DET D
		        WHERE D.IDTERCERO = @IDTERCERO_CUR

		        SET @CNSMOV_ENT = NULL
		        EXEC SPQ_GENSEQUENCE
			        @SEDE     = @IDSEDE_AP,
			        @PREFIJO  = '@MOV',
			        @LONGITUD = 8,
			        @NVOCONSEC = @CNSMOV_ENT OUTPUT

		        INSERT INTO IMOV (
			        CNSMOV, VLRCOMPRA, IDITAR, IDRECIBE, FECHAMOV, TIPO_DOC_COMPRA, IDTIPOMOV, VLR_FLETE
			    ,IDTERCERO, NODOCUMENTO, CCOSTO, IDAREA, IDSOLICITA, OBSERVACION, IDBODEGA, PROCEDENCIA
			    ,USUARIO, CONTABILIZADA, SYS_ComputerName, ESTADO, F_FACTURA, F_VENCE, CNSTRAN
		        )

		        SELECT
			        @CNSMOV_ENT
			    ,@VLRCOMPRA_TER
			    ,(SELECT TOP 1 IART.IDITAR
			        FROM @T_DET D
			        INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
			        WHERE D.IDTERCERO = @IDTERCERO_CUR)
			    ,NULL
			    ,DBO.FNK_GETDATE()
			    ,'R'
			    ,@IDMOVOST_ENTR
			    ,0
			    ,@IDTERCERO_CUR          -- proveedor del movimiento actual
			    ,@NODOC_ENT
			    ,@CCOSTO_CXPS
			    ,@IDAREA_CXPS
			    ,NULL
			    ,'Gasto OSTEO IARTO ' + CAST(@ID AS VARCHAR(12)) + ' - ' + @IDTERCERO_CUR
			    ,@BODEGA_OSTEO
			    ,'INV'
			    ,@USUARIO
			    ,0
			    ,@SYS_COMPUTERNAME_AP
			    ,0
			    ,CONVERT(DATETIME, CONVERT(DATE, GETDATE()))
			    ,NULL
			    ,NULL

		        -- Detalle: solo l�neas de este tercero (ITEM 1..N por movimiento)
		        SELECT @MAX_RN_TER = COUNT(*)
		        FROM @T_DET
		        WHERE IDTERCERO = @IDTERCERO_CUR

		        SET @RN_TER = 1

		        WHILE @RN_TER <= @MAX_RN_TER
		        BEGIN
			    SELECT
			        @IDART_LOOP = D.IDARTICULO
			        ,@CANT_LOOP   = D.CANTIDAD
			        ,@PCOSTO_LOOP = D.PRECIO
			        ,@FV_LOOP     = D.FECHAVENCE
			        ,@NLP_LOOP    = D.NOLOTEPEDIDO
			    FROM (
			        SELECT
				        IDARTICULO, CANTIDAD, PRECIO, FECHAVENCE, NOLOTEPEDIDO,
				        ROW_NUMBER() OVER (ORDER BY RN) AS RN_TER
			        FROM @T_DET
			        WHERE IDTERCERO = @IDTERCERO_CUR
			    ) D
			    WHERE D.RN_TER = @RN_TER

			    SET @NOLOTE_ICBU = SPACE(20)
			    EXEC SPK_GENCONSECUTIVO '01', @IDSEDE_AP, '@ICBU', @NOLOTE_ICBU OUTPUT
			    SELECT @NOLOTE_ICBU = @IDSEDE_AP + 'L' + REPLACE(SPACE(8 - LEN(@NOLOTE_ICBU)) + LTRIM(RTRIM(@NOLOTE_ICBU)), SPACE(1), 0)

			    INSERT INTO IMOVH (
			        CNSMOV, IDARTICULO, CANTPEDIDA, CANTIDAD, PCOSTO, PVENTA, IDITAR
			        ,NOLOTEPEDIDO, NOLOTE, FECHAVENCE, ESTADO, USUARIO, ITEM
			    )
			    SELECT
			        @CNSMOV_ENT
			        ,D.IDARTICULO
			        ,D.CANTIDAD
			        ,D.CANTIDAD
			        ,D.PRECIO
			        ,D.PRECIO
			        ,COALESCE(IART.IDITAR, '')
			        ,D.NOLOTEPEDIDO
			        ,@NOLOTE_ICBU
			        ,D.FECHAVENCE
			        ,0
			        ,@USUARIO
			        ,@RN_TER              -- ITEM por movimiento, no RN global
			    FROM @T_DET D
			    INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
			    WHERE D.IDTERCERO = @IDTERCERO_CUR
			        AND D.RN = (
				    SELECT RN
				    FROM (
				        SELECT RN, ROW_NUMBER() OVER (ORDER BY RN) AS RN_TER
				        FROM @T_DET
				        WHERE IDTERCERO = @IDTERCERO_CUR
				    ) X
				    WHERE X.RN_TER = @RN_TER
			        )

			    SET @RN_TER = @RN_TER + 1
		        END

		        EXEC SPK_CONFIRMARENTRADAS
			        @IDBODEGA,
			        @CNSMOV_ENT,
			        @USUARIO,
			        @COMPANIA_AP,
			        @IDSEDE_AP,
			        @SYS_COMPUTERNAME_AP

		        FETCH NEXT FROM cur_terceros INTO @IDTERCERO_CUR
		    END

		    CLOSE cur_terceros
		    DEALLOCATE cur_terceros
		    --FIN IMOV ENTRADA
            SET @CNSIZSOL_AP = NULL
            EXEC SPQ_GENSEQUENCE @SEDE = @IDSEDE_AP, @PREFIJO = '@IZSOL', @NVOCONSEC = @CNSIZSOL_AP OUTPUT

            INSERT INTO IZSOL (
                CNSIZSOL, FECHASOL, USUARIOSOL, ESTADO, IDSEDE, SECTOR, IDBODEGASOLICITA, IDBODEGAATIENDE, CLASE, NOADMISION, SYS_COMPUTER, IDPLAN
            )
            VALUES (
                @CNSIZSOL_AP, DBO.FNK_FECHA_SIN_MLS(GETDATE()), @USUARIO, 0, @IDSEDE_AP, @SECTOR_HAB, @BODEGA_OSTEO, @BODEGA_OSTEO, 'OSTEO', @IZSOL_REF, @SYS_COMPUTERNAME_AP, @IDPLAN_HADM
            )

            SET @RN_I = 1
            WHILE @RN_I <= @MAX_RN
            BEGIN
                SELECT
                    @IDART_LOOP = D.IDARTICULO
                ,@CANT_LOOP = D.CANTIDAD
                ,@IDSERV_ART = IART.IDSERVICIO
                ,@NLP_LOOP = D.NOLOTEPEDIDO
                FROM @T_DET D
                INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
                WHERE D.RN = @RN_I

                SET @CNSIZSOLD_AP = NULL
                EXEC SPQ_GENSEQUENCE @SEDE = @IDSEDE_AP, @PREFIJO = '@IZSOLD', @NVOCONSEC = @CNSIZSOLD_AP OUTPUT

                -- CNSIZSOLD es calculada en esta BD: se debe poblar NEWCNSIZOLD y dejar que CNSIZSOLD se derive
                INSERT INTO IZSOLD (CNSIZSOL, IDARTICULO, CANTIDADSOL, ESTADO, CODOM, CANTIDAD, IDSERVICIO, NEWCNSIZOLD)
                VALUES (@CNSIZSOL_AP, @IDART_LOOP, @CANT_LOOP, 1, '', 0, @IDSERV_ART, @CNSIZSOLD_AP)

                -- Recuperar el CNSIZSOLD calculado para usarlo en IZSOLDT / salida
                SELECT TOP 1 @CNSIZSOLD_AP = CNSIZSOLD
                FROM IZSOLD
                WHERE CNSIZSOL = @CNSIZSOL_AP
                AND IDARTICULO = @IDART_LOOP
                AND NEWCNSIZOLD = @CNSIZSOLD_AP
                ORDER BY ID DESC

                INSERT INTO @T_IZSOLD_RN (RN, CNSIZSOLD, IDARTICULO, CANTIDADSOL, NOLOTEPEDIDO)
                VALUES (@RN_I, @CNSIZSOLD_AP, @IDART_LOOP, @CANT_LOOP, @NLP_LOOP)

                SET @RN_I = @RN_I + 1
            END

            -- Generar IMOV de salida de forma determin�stica (evita INSERT con IDBODEGA NULL dentro de SPK_CM_GENIMOV_SOL)
            SELECT TOP 1 @CNSMOV_SAL = CNSMOV
            FROM IMOV
            WHERE NODOCUMENTO = @CNSIZSOL_AP
                AND RTRIM(LTRIM(COALESCE(ESTADO,''))) IN ('0','')
            ORDER BY FECHAMOV ASC

            IF COALESCE(@CNSMOV_SAL,'') = ''
            BEGIN
                EXEC SPQ_GENSEQUENCE @SEDE = @IDSEDE_AP, @PREFIJO = '@MOV', @LONGITUD = 8, @NVOCONSEC = @CNSMOV_SAL OUTPUT

                INSERT INTO IMOV (
                    CNSMOV, IDBODEGA, IDTIPOMOV, NODOCUMENTO, FECHAMOV, CCOSTO, IDAREA, IDSOLICITA, IDFUNCIONARIO, IDTERCERO
                ,OBSERVACION, PROCEDENCIA, USUARIO, SYS_ComputerName, ESTADO, CONTABILIZADA, USUARIOCONF
                )
                VALUES (
                    @CNSMOV_SAL
                    ,@BODEGA_OSTEO
                    ,@IDMOVOST_SAL
                    ,@CNSIZSOL_AP
                    ,DBO.FNK_GETDATE()
                    ,@CCOSTO_CXPS
                    ,@IDAREA_CXPS
                    ,@USUARIO
                    ,@USUARIO
                    ,COALESCE(@IDTER_SALIDA_AP, '')
                    ,'Salida OSTEO IARTO ' + CAST(@ID AS VARCHAR(12))
                    ,'CM_SOL'
                    ,@USUARIO
                    ,@SYS_COMPUTERNAME_AP
                    ,0
                    ,0
                    ,@USUARIO
                )
            END

            IF COALESCE(@CNSMOV_SAL,'') = ''
                RAISERROR('No se pudo resolver/crear movimiento de salida (IMOV) para la solicitud IZSOL.', 16, 1)
            IF NOT EXISTS (SELECT 1 FROM IMOV WHERE CNSMOV = @CNSMOV_SAL)
                RAISERROR('No se insert� IMOV de salida (CNSMOV).', 16, 1)

            SELECT @IDTIPOMOV_TMP = IDTIPOMOV FROM IMOV WHERE CNSMOV = @CNSMOV_SAL
            IF COALESCE(@IDTIPOMOV_TMP,'') <> @IDMOVOST_SAL
                UPDATE IMOV SET IDTIPOMOV = @IDMOVOST_SAL WHERE CNSMOV = @CNSMOV_SAL

            -- Solicitud IZSOL / CM: mismo criterio que otros flujos de dispensaci�n por solicitud
            -- IDFUNCIONARIO: quien ejecuta la aprobaci�n (grilla IMOV une USUSU por este campo)
            UPDATE IMOV
            SET PROCEDENCIA = 'CM_SOL'
                , IDFUNCIONARIO = @USUARIO
                , USUARIO = @USUARIO
                , USUARIOCONF = @USUARIO
            WHERE CNSMOV = @CNSMOV_SAL

            SET @RN_I = 1
            WHILE @RN_I <= @MAX_RN
            BEGIN
                SELECT
                    @CNSIZSOLD_AP = CNSIZSOLD
                ,@IDART_LOOP = IDARTICULO
                ,@CANT_LOOP = CANTIDADSOL
                ,@NLP_LOOP = NOLOTEPEDIDO
                FROM @T_IZSOLD_RN WHERE RN = @RN_I

                SET @NOLOTE_IEXI = NULL
                SET @IDART_REAL = NULL

                SELECT TOP 1 @NOLOTE_IEXI = IEXI.NOLOTE, @IDART_REAL = IEXI.IDARTICULO
                FROM IEXI
                WHERE IEXI.IDBODEGA = @BODEGA_OSTEO
                AND IEXI.IDARTICULO = @IDART_LOOP
                AND COALESCE(IEXI.NOLOTEPEDIDO,'') = COALESCE(@NLP_LOOP,'')
                AND IEXI.EXISLOTE >= @CANT_LOOP
                ORDER BY IEXI.NOLOTE DESC

                IF COALESCE(@NOLOTE_IEXI,'') = '' OR @IDART_REAL IS NULL
                RAISERROR('No se encontr� existencia en IEXI para dispensar (mismo lote ingresado).', 16, 1)

                EXEC SPK_IZSOLDT_PROCESOS @IDART_LOOP, @CNSIZSOLD_AP, 'AGREGAR', @IDSEDE_AP, @IDART_REAL, @NOLOTE_IEXI, @CANT_LOOP, @CANT_LOOP, @CNSMOV_SAL, ''

                SET @RN_I = @RN_I + 1
            END

            -- Igual que METODO ENTREGAR en SPQ_IZSOL: l�nea cumplida -> IZSOLD.ESTADO = 0
            UPDATE S
            SET S.ESTADO = 0
            FROM IZSOLD S
            WHERE S.CNSIZSOL = @CNSIZSOL_AP
                AND S.CANTIDADSOL = (
                SELECT COALESCE(SUM(COALESCE(T.CANTIDADSOL, 0)), 0)
                FROM IZSOLDT T
                WHERE T.CNSIZSOLD = S.CNSIZSOLD
                )

            EXEC SPK_PROCESA_IZSOLDT @CNSIZSOL_AP, @CNSMOV_SAL, @IDMOVOST_SAL, @IDSEDE_AP, @USUARIO

            -- Igual que METODO PROCESAR en SPQ_IZSOL
            UPDATE IZSOL SET SYS_ENTREGA = '', SYS_COMPUTER = '' WHERE CNSIZSOL = @CNSIZSOL_AP
            UPDATE IMOV SET IDSERVICIO = @IDCIR_CXPS WHERE CNSMOV = @CNSMOV_SAL

            -- La grilla dtIZSOLD_AGRE (IndexComponent) cuenta ENTREGADO con IZSOLDT + IMOV donde IMOV.ESTADO = '1'.
            -- CONF_MOVIMIENTO confirma con SPK_CONFIRMASAL_CM; SPK_CONFIRMARSALIDAS es otra ruta y puede dejar
            -- el movimiento sin el estado que esa consulta espera.
            EXEC SPK_CONFIRMASAL_CM @CNSMOV_SAL, @USUARIO, @IDSEDE_AP, 'LOG_PROD'

            SELECT @EST_MOV_SAL = TRY_CAST(ESTADO AS TINYINT) FROM IMOV WHERE CNSMOV = @CNSMOV_SAL
            IF COALESCE(@EST_MOV_SAL,0) <> 1
                RAISERROR('El movimiento de salida no qued� confirmado.', 16, 1)

            -- CXPSI: PK (NOPROGRAMACION, IDCIRUGIA, IDSERVICIO, CNSMOV). IDSERVICIO = servicio del art�culo (IART).
            -- 1) Filas previas de programaci�n sin CNSMOV: enlazar al movimiento de salida y marcar pedido.
            UPDATE C
            SET C.PEDIDOINV = 1
                , C.CNSMOV = @CNSMOV_SAL
                , C.CANTIDADEST = COALESCE(A.QTY, C.CANTIDADEST)
                , C.CANTIDADREAL = COALESCE(A.QTY, C.CANTIDADREAL)
                , C.PCOSTO = COALESCE(A.PCOST, C.PCOSTO)
                , C.PVENTA = COALESCE(A.PCOST, C.PVENTA)
                , C.IDTEROSTEO = COALESCE(NULLIF(RTRIM(A.IDTER_LINEA), ''), C.IDTEROSTEO)
            FROM CXPSI C
            INNER JOIN (
                SELECT
                    IART.IDSERVICIO AS IDSERV
                ,CAST(SUM(D.CANTIDAD) AS FLOAT) AS QTY
                ,MAX(D.PRECIO) AS PCOST
                ,MAX(D.IDTERCERO) AS IDTER_LINEA
                FROM IARTOD D
                INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
                WHERE D.IDIARTO = @ID
                AND COALESCE(IART.IDSERVICIO, '') <> ''
                GROUP BY IART.IDSERVICIO
            ) A ON A.IDSERV = C.IDSERVICIO
            WHERE C.NOPROGRAMACION = @NOPROGRAMACION
                AND C.IDCIRUGIA = @IDCIR_CXPS
                AND NULLIF(RTRIM(C.CNSMOV), '') IS NULL

            -- 2) Insertar l�neas que no existan a�n para este movimiento de salida (mismo patr�n que canasta SPQ_IZSOL).
            INSERT INTO CXPSI (
                NOPROGRAMACION, IDCIRUGIA, IDSERVICIO
                ,CANTIDADEST, CANTIDADREAL, PCOSTO, PVENTA
                ,PEDIDOINV, CANTIDADDEV, CNSMOV, INDDEV, BASICO
                ,IDTEROSTEO
            )
            SELECT
                @NOPROGRAMACION
                ,@IDCIR_CXPS
                ,A.IDSERV
                ,A.QTY
                ,A.QTY
                ,ISNULL(A.PCOST, 0)
                ,ISNULL(A.PCOST, 0)
                ,1
                ,0
                ,@CNSMOV_SAL
                ,0
                ,0
                ,NULLIF(RTRIM(A.IDTER_LINEA), '')
            FROM (
                SELECT
                    IART.IDSERVICIO AS IDSERV
                ,CAST(SUM(D.CANTIDAD) AS FLOAT) AS QTY
                ,MAX(D.PRECIO) AS PCOST
                ,MAX(D.IDTERCERO) AS IDTER_LINEA
                FROM IARTOD D
                INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
                WHERE D.IDIARTO = @ID
                AND COALESCE(IART.IDSERVICIO, '') <> ''
                GROUP BY IART.IDSERVICIO
            ) A
            WHERE NOT EXISTS (
                SELECT 1
                FROM CXPSI C
                WHERE C.NOPROGRAMACION = @NOPROGRAMACION
                AND C.IDCIRUGIA = @IDCIR_CXPS
                AND C.IDSERVICIO = A.IDSERV
                AND C.CNSMOV = @CNSMOV_SAL
            )

            UPDATE IZSOL SET ESTADO = 2 WHERE CNSIZSOL = @CNSIZSOL_AP
        END

        IF @SOLICITUD = 1
	    BEGIN
		    PRINT 'TODO: Crear Cotizacion con IARTO y IARTOD'
		    SELECT @IDTERCERO = IDTERCERO, @IDPLAN = IDPLAN, @IDBODEGA = IDBODEGA FROM IARTO WHERE ID = @ID

		    DECLARE @JSON_COTIZACIONES nvarchar(max);
		    SELECT @JSON_COTIZACIONES =
		    (
		        SELECT
			    'COTIZA_CRUD' AS METODO,
			    'ICTZG'       AS MODELO,
			    JSON_QUERY((
			        SELECT
				    JSON_QUERY((
				        SELECT
					    NULL AS IDCOTIZACION,
					    @IDTERCERO AS IDTERCERO,
					    @IDPLAN    AS IDPLAN,
					    @IDBODEGA  AS IDBODEGA,
					    CONVERT(char(10), GETDATE(), 23) AS FECHAVENCE,
					    'Pendiente'    AS ESTADO,
					    @USUARIO   AS USUARIO,
					    'Materiales de Osteosintesis' AS OBSERVACION,
					    'IARTO' AS TIPOCNS_REL,
					        @ID AS CNSREL,
					    'INSERTAR' AS PROCESO,
					    JSON_QUERY(
					        COALESCE((
						    SELECT
						        d.IDARTICULO,
						        d.CANTIDAD AS CANTIDAD,
						        d.PRECIO   AS VALORUNITARIO,
						        0          AS IVA,
						        d.SUBTOTAL AS VALORTOTAL
						    FROM IARTOD d
						    WHERE d.IDIARTO = @ID
						    FOR JSON PATH
					        ), '[]')
					    ) AS DETALLE
				        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
				    )) AS REGISTRO
			        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			    )) AS PARAMETROS
		        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		    );
		    --SELECT @JSON_COTIZACIONES
		    
            EXEC dbo.SPQ_ICTZG @JSON = @JSON_COTIZACIONES;

	    END
	  
	    SELECT TOP 1 @IDCIR_CXPS = IDCIRUGIA FROM CXPSD WHERE NOPROGRAMACION = @NOPROGRAMACION ORDER BY ITEM ASC
	    SELECT @IDTERCERO = IDTERCERO FROM IARTO WHERE ID = @ID

	    --INSERT INTO CXPSI (
     --           NOPROGRAMACION, IDCIRUGIA, IDSERVICIO
     --           ,CANTIDADEST, CANTIDADREAL, PCOSTO, PVENTA
     --           ,PEDIDOINV, CANTIDADDEV, CNSMOV, INDDEV, BASICO
     --           ,IDTEROSTEO
     --       )
     --   SELECT
     --       @NOPROGRAMACION
     --       ,@IDCIR_CXPS
     --       ,A.IDSERV
     --       ,A.QTY
     --       ,A.QTY
     --       ,ISNULL(A.PCOST, 0)
     --       ,ISNULL(A.PCOST, 0)
     --       ,0
     --       ,0
     --       ,''
     --       ,0
     --       ,0
     --       ,NULLIF(RTRIM(@IDTERCERO), '')
     --   FROM (
     --       SELECT
     --           IART.IDSERVICIO AS IDSERV
     --       ,CAST(SUM(D.CANTIDAD) AS FLOAT) AS QTY
     --       ,MAX(D.PRECIO) AS PCOST
     --       ,MAX(D.IDTERCERO) AS IDTER_LINEA
     --       FROM IARTOD D
     --       INNER JOIN IART ON IART.IDARTICULO = D.IDARTICULO
     --       WHERE D.IDIARTO = @ID
     --       AND COALESCE(IART.IDSERVICIO, '') <> ''
     --       GROUP BY IART.IDSERVICIO
     --   ) A
     --   WHERE NOT EXISTS (
     --       SELECT 1
     --       FROM CXPSI C
     --       WHERE C.NOPROGRAMACION = @NOPROGRAMACION
     --       AND C.IDCIRUGIA = @IDCIR_CXPS
     --       AND C.IDSERVICIO = A.IDSERV
     --       AND C.CNSMOV = @CNSMOV_SAL
     --   )
	
	
	        UPDATE IARTO SET
                ESTADO          = 'APROBADO'
            ,FECHA_APRUEBA   = GETDATE()
            ,USUARIO_APRUEBA = @USUARIO
            WHERE ID = @ID

            IF @TRN_INI = 0
                COMMIT TRANSACTION
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1
            BEGIN
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            END
            ELSE
            BEGIN
                IF @TRN_INI = 0
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
                END
                ELSE
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION SPQ_IARTO_APROBAR
                END
            END
            INSERT INTO @TBLERRORES 
            SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN 
            SELECT 'KO' OK 
            SELECT ERROR FROM @TBLERRORES 
            RETURN 
        END
        SELECT 'OK' OK 
        RETURN
    END

    -- --------------------------------------------------------
    -- MARCA_REV_ESTERILIZACION: solo hoja de gasto (SOLICITUD=0)
    -- --------------------------------------------------------
    IF @METODO = 'MARCA_REV_ESTERILIZACION'
    BEGIN
        SELECT @ID = ID FROM OPENJSON(@PARAMETROS) WITH (ID INT '$.ID')

        IF NOT EXISTS (SELECT 1 FROM IARTO WHERE ID = @ID)
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'Registro no encontrado.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM IARTO WHERE ID = @ID AND SOLICITUD = 0)
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'La revisi�n de esterilidad aplica solo a Hoja de Gasto.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF EXISTS (SELECT 1 FROM IARTO WHERE ID = @ID AND COALESCE(REV_ESTERILIZACION, 0) = 1)
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'El registro ya tiene revisi�n de esterilidad marcada.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        BEGIN TRY
            UPDATE IARTO SET
                REV_ESTERILIZACION         = 1
            ,FECHA_REV_ESTERILIZACION   = GETDATE()
            ,USUARIO_REV_ESTERILIZACION = @USUARIO
            ,FECHA_MOD                  = GETDATE()
            WHERE ID = @ID
            AND SOLICITUD = 0
            AND COALESCE(REV_ESTERILIZACION, 0) = 0
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN 
            SELECT 'KO' OK 
            SELECT ERROR FROM @TBLERRORES 
            RETURN 
        END

        SELECT 'OK' OK 
        RETURN
    END

    -- --------------------------------------------------------
    -- ANULAR: cambia estado a ANULADO + motivo obligatorio
    -- --------------------------------------------------------
    IF @METODO = 'ANULAR'
    BEGIN
        SELECT @ID=ID, @MOTIVO_ANUL=MOTIVO
        FROM OPENJSON(@PARAMETROS)
        WITH (ID INT '$.ID', MOTIVO VARCHAR(500) '$.MOTIVO')

        IF COALESCE(@MOTIVO_ANUL,'') = ''
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'Debe indicar el motivo de anulaci�n.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM IARTO WHERE ID=@ID AND ESTADO IN ('GENERADO','APROBADO'))
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'La solicitud ya est� anulada o no existe.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        BEGIN TRY
            UPDATE IARTO SET
                ESTADO        = 'ANULADO'
            ,MOTIVO_ANUL   = @MOTIVO_ANUL
            ,FECHA_ANULA   = GETDATE()
            ,USUARIO_ANULA = @USUARIO
            WHERE ID = @ID
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN 
            SELECT 'KO' OK 
            SELECT ERROR FROM @TBLERRORES 
            RETURN 
        END

        SELECT 'OK' OK 
        RETURN
    END

    -- --------------------------------------------------------
    -- CATALOGO_OSTEO: b�squeda en TGEN por referencia o descripci�n
    -- --------------------------------------------------------
    IF @METODO = 'CATALOGO_OSTEO'
    BEGIN
        SELECT @COD_BUSCAR=COD_PROVEEDOR, @DESC_BUSCAR=DESCRIPCION, @NOPROGRAMACION = NOPROGRAMACION, @NOADMISION = NOADMISION,
	    @IDTERCERO = IDTERCERO, @IDPLAN = IDPLAN
        FROM OPENJSON(@PARAMETROS)
        WITH (COD_PROVEEDOR VARCHAR(100) '$.COD_PROVEEDOR', DESCRIPCION VARCHAR(200) '$.DESCRIPCION',
		        NOPROGRAMACION INT '$.NOPROGRAMACION', NOADMISION VARCHAR(16) '$.NOADMISION',
		        IDTERCERO VARCHAR(20) '$.IDTERCERO', IDPLAN VARCHAR(6) '$.IDPLAN')

	    SELECT @IDAREA = IDAREA, @IDSERVICIO = IDSERVICIO FROM CXPS WHERE NOPROGRAMACION = @NOPROGRAMACION

	    IF COALESCE(@IDAREA, '') = ''
	    BEGIN
		    SELECT @IDAREA = DATO FROM USVGS WHERE IDVARIABLE = 'TMIDAREAQX'
	    END

	    IF NOT EXISTS(SELECT 1 FROM AFU WHERE IDAREA = @IDAREA)
	    BEGIN
		    SELECT @IDAREA = DATO FROM USVGS WHERE IDVARIABLE = 'TMIDAREAQX'
	    END
        SELECT 'OK' OK  -- RS1: estado

        SELECT
            T.IDTGEN
            ,T.DATO5   AS IDTERCERO
            ,T.OBSERVACION AS NOMBRE_CASA_COMERCIAL
            ,T.CODIGO  AS COD_PROVEEDOR
            ,T.DATO1   AS IDARTICULO
            ,COALESCE(IART.DESCRIPCION, SER.DESCSERVICIO, T.DESCRIPCION) AS DESCRIPCION
	        ,COALESCE(TAR.PRECIO, 0) AS PRECIO
        FROM TGEN T 
        INNER JOIN SER  ON SER.IDSERVICIO  = T.DATO1
        INNER JOIN IART ON IART.IDARTICULO = SER.IDSERVICIO
	    OUTER APPLY (
        SELECT TOP (1)
                CAST(S1.VLRSERVICIO AS DECIMAL(14,2)) AS PRECIO
			    FROM   SERTOT1 S1
			    WHERE  S1.IDTERCERO  = @IDTERCERO
			        AND  S1.IDPLAN     = @IDPLAN
			    -- AND S1.IDSERVICIO = IART.IDSERVICIO
			        AND S1.IDSERVICIO = SER.IDSERVICIO
			        AND    GETDATE()     >= FECHAINIFD
			        AND    GETDATE()     <= FECHAFINFD
			        AND  GETDATE() BETWEEN S1.FECHAINI   AND S1.FECHAFIN
			        AND  S1.IDAREACA   = @IDAREA
			    ORDER BY S1.FECHAINI DESC, S1.FECHAINIFD DESC
		    ) TAR
        WHERE T.TABLA = 'IART_OSTEO'
            AND (
                COALESCE(@COD_BUSCAR,'') = ''
                OR T.CODIGO LIKE '%' + @COD_BUSCAR + '%'
            )
            AND (
                COALESCE(@DESC_BUSCAR,'') = ''
                OR COALESCE(IART.DESCRIPCION, SER.DESCSERVICIO) LIKE '%' + @DESC_BUSCAR + '%'
            )
        ORDER BY DESCRIPCION
        RETURN
    END

    -- --------------------------------------------------------
    -- ACTUALIZAR_PRECIO_OSTEO: update TGEN.VALOR1 por IDTGEN
    -- --------------------------------------------------------
    IF @METODO = 'ACTUALIZAR_PRECIO_OSTEO'
    BEGIN
        SELECT @IDTGEN=IDTGEN, @PRECIO_NUEVO=PRECIO
        FROM OPENJSON(@PARAMETROS)
        WITH (IDTGEN INT '$.IDTGEN', PRECIO DECIMAL(14,2) '$.PRECIO')

        IF COALESCE(@IDTGEN,0) = 0
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'IDTGEN es obligatorio para actualizar precio.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF @PRECIO_NUEVO < 0
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'El precio no puede ser negativo.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM TGEN WHERE IDTGEN=@IDTGEN AND TABLA='IART_OSTEO')
        BEGIN
            INSERT INTO @TBLERRORES SELECT 'El art�culo no existe en el cat�logo IART_OSTEO.'
            SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
        END

        BEGIN TRY
            UPDATE TGEN SET
                VALOR1   = @PRECIO_NUEVO
            ,DATO3    = @USUARIO            -- auditor�a: usuario que actualiz�
            ,DATO4    = CONVERT(VARCHAR,GETDATE(),103)  -- auditor�a: fecha dd/mm/yyyy
            WHERE IDTGEN = @IDTGEN AND TABLA = 'IART_OSTEO'
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN 
            SELECT 'KO' OK 
            SELECT ERROR FROM @TBLERRORES 
            RETURN 
        END

        SELECT 'OK' OK RETURN
    END
	IF @METODO = 'IMPORTAR_MAT_OSTEO'
	BEGIN
		SELECT @FILAS_JSON = FILAS
		FROM OPENJSON(@PARAMETROS)
		WITH (FILAS NVARCHAR(MAX) AS JSON);

		SET @SOLO_NUEVOS = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.SOLO_NUEVOS') AS BIT), 0);

		IF COALESCE(@FILAS_JSON, '') = ''
		BEGIN
			SELECT OK = 'KO', ERROR = 'No se recibieron filas para importar';
			RETURN;
		END;

		SELECT
			ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS ITEM,
			FILA_EXCEL,
			IDTGEN,
			LTRIM(RTRIM(CODIGO)) AS CODIGO,
			LTRIM(RTRIM(DESCRIPCION)) AS DESCRIPCION,
			LTRIM(RTRIM(REFERENCIA)) AS REFERENCIA,
			CAST(VALOR AS DECIMAL(18, 2)) AS VALOR,
			LTRIM(RTRIM(CASA_COMERCIAL)) AS CASA_COMERCIAL,
			LTRIM(RTRIM(IDTERCERO)) AS IDTERCERO,
			LTRIM(RTRIM(NOM_TERCERO)) AS NOM_TERCERO
		INTO #FILAS_MAT_OSTEO
		FROM OPENJSON(@FILAS_JSON)
		WITH (
			FILA_EXCEL INT '$.FILA_EXCEL',
			IDTGEN INT '$.IDTGEN',
			CODIGO VARCHAR(20) '$.CODIGO',
			DESCRIPCION VARCHAR(1000) '$.DESCRIPCION',
			REFERENCIA VARCHAR(255) '$.REFERENCIA',
			VALOR DECIMAL(18, 2) '$.VALOR',
			CASA_COMERCIAL VARCHAR(255) '$.CASA_COMERCIAL',
			IDTERCERO VARCHAR(20) '$.IDTERCERO',
			NOM_TERCERO VARCHAR(1000) '$.NOM_TERCERO'
		);

		IF NOT EXISTS (SELECT 1 FROM #FILAS_MAT_OSTEO)
		BEGIN
			SELECT OK = 'KO', ERROR = 'No se recibieron filas para importar';
			RETURN;
		END;

		SELECT DISTINCT
			LTRIM(RTRIM(TER.IDALTERNA2)) AS CODIGO,
			LTRIM(RTRIM(TER.RAZONSOCIAL)) AS DESCRIPCION,
			LTRIM(RTRIM(TER.IDTERCERO)) AS IDTERCERO
		INTO #CASAS_MAT_OSTEO
		FROM TER WITH (NOLOCK)
		INNER JOIN TEXCA WITH (NOLOCK) ON TEXCA.IDTERCERO = TER.IDTERCERO
		WHERE TEXCA.IDCATEGORIA = 'OST'
		  AND COALESCE(TER.IDALTERNA2, '') <> '';

		DECLARE @RESULTADOS_MAT TABLE (
			FILA INT NULL,
			CODIGO VARCHAR(20) NULL,
			OK VARCHAR(2) NOT NULL,
			MENSAJE VARCHAR(500) NULL
		);

		DECLARE
			@ITEM INT,
			@FILA_EXCEL INT,
			@IDTGEN_IN INT,
			@CODIGO VARCHAR(20),
			@DESCRIPCION VARCHAR(1000),
			@REFERENCIA VARCHAR(255),
			@VALOR DECIMAL(18, 2),
			@CASA_COMERCIAL VARCHAR(255),
			@IDTERCERO_IN VARCHAR(20),
			@NOM_TERCERO_IN VARCHAR(1000),
			@IDTERCERO_FINAL VARCHAR(20),
			@NOM_TERCERO_FINAL VARCHAR(1000),
			@IDTGEN_EXISTE INT,
			@IDARTICULO_ANTERIOR VARCHAR(20),
			@ERR VARCHAR(500);

		SET @IDITAR_OSTEO = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('IDITAR_INSUMOS_OSTEO'), '')));
		SET @IDTARIFA_OSTEO = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('IDTARIFAOSTEO'), '')));

		DECLARE CUR_FILAS_MAT CURSOR LOCAL FAST_FORWARD FOR
			SELECT ITEM, FILA_EXCEL, IDTGEN, CODIGO, DESCRIPCION, REFERENCIA, VALOR, CASA_COMERCIAL, IDTERCERO, NOM_TERCERO
			FROM #FILAS_MAT_OSTEO
			ORDER BY ITEM;

		OPEN CUR_FILAS_MAT;
		FETCH NEXT FROM CUR_FILAS_MAT
		INTO @ITEM, @FILA_EXCEL, @IDTGEN_IN, @CODIGO, @DESCRIPCION, @REFERENCIA, @VALOR, @CASA_COMERCIAL, @IDTERCERO_IN, @NOM_TERCERO_IN;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @ERR = NULL;
			SET @IDTERCERO_FINAL = NULL;
			SET @NOM_TERCERO_FINAL = NULL;
			SET @IDTGEN_EXISTE = NULL;
			SET @IDARTICULO_ANTERIOR = NULL;

			IF COALESCE(@CODIGO, '') = ''
				SET @ERR = 'C�digo requerido';
			ELSE IF COALESCE(@DESCRIPCION, '') = ''
				SET @ERR = 'Descripci�n requerida';
			ELSE IF COALESCE(@REFERENCIA, '') = ''
				SET @ERR = 'Referencia requerida';
			ELSE IF @VALOR IS NULL
				SET @ERR = 'Valor requerido';
			ELSE IF COALESCE(@CASA_COMERCIAL, '') = ''
				SET @ERR = 'Casa comercial requerida';

			IF @ERR IS NULL
			BEGIN
				SELECT
					@IDTERCERO_FINAL = COALESCE(NULLIF(@IDTERCERO_IN, ''), C.IDTERCERO, @CASA_COMERCIAL),
					@NOM_TERCERO_FINAL = COALESCE(NULLIF(@NOM_TERCERO_IN, ''), C.DESCRIPCION, '')
				FROM (SELECT 1 AS X) D
				LEFT JOIN #CASAS_MAT_OSTEO C ON C.CODIGO = @CASA_COMERCIAL;

				IF NOT EXISTS (SELECT 1 FROM #CASAS_MAT_OSTEO WHERE CODIGO = @CASA_COMERCIAL)
					SET @ERR = CONCAT('Casa comercial no v�lida: ', @CASA_COMERCIAL);
			END;

			IF @ERR IS NULL
			BEGIN
				BEGIN TRY
					IF COALESCE(@IDTGEN_IN, 0) > 0
					BEGIN
						SELECT
							@IDTGEN_EXISTE = IDTGEN,
							@IDARTICULO_ANTERIOR = COALESCE(NULLIF(LTRIM(RTRIM(DATO1)), ''), CAMPO)
						FROM TGEN WITH (UPDLOCK, HOLDLOCK)
						WHERE IDTGEN = @IDTGEN_IN
						  AND TABLA = 'IART_OSTEO';

						IF @IDTGEN_EXISTE IS NULL
							SET @ERR = 'El material a editar no existe.';
						ELSE IF EXISTS (
							SELECT 1
							FROM TGEN WITH (UPDLOCK, HOLDLOCK)
							WHERE TABLA = 'IART_OSTEO'
							  AND CODIGO = @CODIGO
							  AND CAMPO = @REFERENCIA
							  AND IDTGEN <> @IDTGEN_EXISTE
						)
							SET @ERR = 'Ya existe otro material con el mismo C�digo y Referencia.';
					END
					ELSE
					BEGIN
						SELECT @IDTGEN_EXISTE = IDTGEN
						FROM TGEN WITH (UPDLOCK, HOLDLOCK)
						WHERE TABLA = 'IART_OSTEO'
						  AND CODIGO = @CODIGO
						  AND CAMPO = @REFERENCIA;
					END

					IF @ERR IS NOT NULL
					BEGIN
						INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
						VALUES (@FILA_EXCEL, @CODIGO, 'KO', @ERR);
					END
					ELSE IF @IDTGEN_EXISTE IS NOT NULL
					BEGIN
						IF @SOLO_NUEVOS = 1 AND COALESCE(@IDTGEN_IN, 0) = 0
						BEGIN
							INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
							VALUES (@FILA_EXCEL, @CODIGO, 'KO', 'El material ya existe (Referencia + Cod Articulo)');
						END
						ELSE
						BEGIN
							UPDATE TGEN
							SET CAMPO = @REFERENCIA,
								DESCRIPCION = @DESCRIPCION,
								VALOR1 = @VALOR,
								DATO5 = @CASA_COMERCIAL,
								DATOMAX = @IDTERCERO_FINAL,
								OBSERVACION = @NOM_TERCERO_FINAL,
								DATO1 = @REFERENCIA
							WHERE IDTGEN = @IDTGEN_EXISTE;

							-- IART + SER (mismo ID que Cod Articulo / TGEN.DATO1)
							SET @IDARTICULO_SYNC = @REFERENCIA;
							SET @PREFIJO_OSTEO = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('PREOSTEO_CX'), '')));							

							IF NOT EXISTS (SELECT 1 FROM IART WHERE IDARTICULO = @IDARTICULO_SYNC)
							BEGIN
								INSERT INTO IART (
									IDARTICULO, DESCRIPCION, IDITAR, ESTADO, PRINCIPAL, PCOSTO, REFERENCIA,
									IDSERVICIO, MAT_IMPLANTACION, IDUNIDAD, EXISTOTAL
								)
								VALUES (
									@IDARTICULO_SYNC, @DESCRIPCION, @IDITAR_OSTEO, 'Activo', 1, @VALOR, @CODIGO,
									@IDARTICULO_SYNC, 1, 'NA', 0
								);
							END
							ELSE
							BEGIN
								UPDATE IART
								SET DESCRIPCION = @DESCRIPCION,
									PCOSTO = @VALOR,
									REFERENCIA = @CODIGO,
									IDSERVICIO = @IDARTICULO_SYNC,
									ESTADO = 'Activo',
									MAT_IMPLANTACION = 1
								WHERE IDARTICULO = @IDARTICULO_SYNC;
							END;

							IF NOT EXISTS (SELECT 1 FROM SER WHERE IDSERVICIO = @IDARTICULO_SYNC)
							BEGIN
								INSERT INTO SER (
									PREFIJO, IDSERVICIO, DESCSERVICIO, IDARTICULO, ESTADO, CIRUGIA,
									MEDICAMENTOS, SEXO, NIVELATENCION, NIVELFUNCIONARIO, NIVELSEDE,
									CANTIDAD,CODFURIPS,CODIGORIPS,TIPOOTRO,CODCUPS, DESCRIPCION_CUPS
								)
								VALUES (
									@PREFIJO_OSTEO, @IDARTICULO_SYNC, @DESCRIPCION, @IDARTICULO_SYNC, 'Activo', 1,
									0, 'Ambos', 1, 1, 1, 1, '07', 'AT', '1', @IDARTICULO_SYNC, @DESCRIPCION
								);
							END
							ELSE
							BEGIN
								UPDATE SER
								SET DESCSERVICIO = @DESCRIPCION,
									IDARTICULO = @IDARTICULO_SYNC,
									PREFIJO = @PREFIJO_OSTEO,
									CIRUGIA = 1,
									ESTADO = 'Activo'
								WHERE IDSERVICIO = @IDARTICULO_SYNC;
							END;

							IF COALESCE(@IDARTICULO_ANTERIOR, '') <> ''
							   AND @IDARTICULO_ANTERIOR <> @IDARTICULO_SYNC
							   AND NOT EXISTS (
									SELECT 1
									FROM TGEN WITH (NOLOCK)
									WHERE TABLA = 'IART_OSTEO'
									  AND IDTGEN <> @IDTGEN_EXISTE
									  AND COALESCE(NULLIF(LTRIM(RTRIM(DATO1)), ''), CAMPO) = @IDARTICULO_ANTERIOR
							   )
							BEGIN
								IF COALESCE(@PREFIJO_OSTEO, '') <> ''
									DELETE FROM SER
									WHERE IDSERVICIO = @IDARTICULO_ANTERIOR
									  AND PREFIJO = @PREFIJO_OSTEO;

								IF EXISTS (
									SELECT 1
									FROM IEXI WITH (NOLOCK)
									WHERE IDARTICULO = @IDARTICULO_ANTERIOR
									  AND COALESCE(EXISLOTE, 0) <> 0
								)
									UPDATE IART SET ESTADO = 'Inactivo' WHERE IDARTICULO = @IDARTICULO_ANTERIOR;
								ELSE
									DELETE FROM IART WHERE IDARTICULO = @IDARTICULO_ANTERIOR;
							END;

							INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
							VALUES (@FILA_EXCEL, @CODIGO, 'OK', NULL);
						END
					END
					ELSE
					BEGIN
						IF @IDTARIFA_OSTEO = '' OR NOT EXISTS (SELECT 1 FROM TAR WHERE IDTARIFA = @IDTARIFA_OSTEO)
						BEGIN
							SET @ERR = 'Configure la variable IDTARIFAOSTEO con una tarifa v�lida antes de crear materiales de osteos�ntesis.';
							INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
							VALUES (@FILA_EXCEL, @CODIGO, 'KO', @ERR);
						END
						ELSE
						BEGIN
						INSERT INTO TGEN (
							TABLA, CAMPO, CODIGO, DESCRIPCION, VALOR1, DATO5, DATOMAX, OBSERVACION, DATO1
						)
						VALUES (
							'IART_OSTEO', @REFERENCIA, @CODIGO, @DESCRIPCION, @VALOR,
							@CASA_COMERCIAL, @IDTERCERO_FINAL, @NOM_TERCERO_FINAL, @REFERENCIA
						);

						SET @IDTGEN_EXISTE = SCOPE_IDENTITY();
						SET @IDARTICULO_SYNC = @REFERENCIA;
						SET @PREFIJO_OSTEO = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('PREOSTEO_CX'), '')));						

						IF NOT EXISTS (SELECT 1 FROM IART WHERE IDARTICULO = @IDARTICULO_SYNC)
						BEGIN
							INSERT INTO IART (
								IDARTICULO, DESCRIPCION, IDITAR, ESTADO, PRINCIPAL, PCOSTO, REFERENCIA,
								IDSERVICIO, MAT_IMPLANTACION, IDUNIDAD, EXISTOTAL
							)
							VALUES (
								@IDARTICULO_SYNC, @DESCRIPCION, @IDITAR_OSTEO, 'Activo', 1, @VALOR, @CODIGO,
								@IDARTICULO_SYNC, 1, 'NA', 0
							);
						END
						ELSE
						BEGIN
							UPDATE IART
							SET DESCRIPCION = @DESCRIPCION,
								PCOSTO = @VALOR,
								REFERENCIA = @CODIGO,
								IDSERVICIO = @IDARTICULO_SYNC,
								ESTADO = 'Activo',
								MAT_IMPLANTACION = 1
							WHERE IDARTICULO = @IDARTICULO_SYNC;
						END;

						IF NOT EXISTS (SELECT 1 FROM SER WHERE IDSERVICIO = @IDARTICULO_SYNC)
						BEGIN
							INSERT INTO SER (
								PREFIJO, IDSERVICIO, DESCSERVICIO, IDARTICULO, ESTADO, CIRUGIA,
								MEDICAMENTOS, SEXO, NIVELATENCION, NIVELFUNCIONARIO, NIVELSEDE,
								CANTIDAD, CODFURIPS,CODIGORIPS,TIPOOTRO,CODCUPS, DESCRIPCION_CUPS
							)
							VALUES (
								@PREFIJO_OSTEO, @IDARTICULO_SYNC, @DESCRIPCION, @IDARTICULO_SYNC, 'Activo', 1,
								0, 'Ambos', 1, 1, 1, 1, '07', 'AT', '1', @IDARTICULO_SYNC, @DESCRIPCION
							);
						END
						ELSE
						BEGIN
							UPDATE SER
							SET DESCSERVICIO = @DESCRIPCION,
								IDARTICULO = @IDARTICULO_SYNC,
								PREFIJO = @PREFIJO_OSTEO,
								CIRUGIA = 1,
								ESTADO = 'Activo'
							WHERE IDSERVICIO = @IDARTICULO_SYNC;
						END;

						-- Configuraci�n tarifaria inicial para el material creado.
						-- TARD conserva el servicio en la tarifa; TARDV registra el valor y vigencia anual.
						IF NOT EXISTS (
							SELECT 1
							FROM TARD
							WHERE IDTARIFA = @IDTARIFA_OSTEO
							  AND IDSERVICIO = @IDARTICULO_SYNC
						)
						BEGIN
							INSERT INTO TARD (IDTARIFA, IDSERVICIO, CIRUGIA)
							VALUES (@IDTARIFA_OSTEO, @IDARTICULO_SYNC, 0);
						END;

						IF NOT EXISTS (
							SELECT 1
							FROM TARDV
							WHERE IDTARIFA = @IDTARIFA_OSTEO
							  AND IDSERVICIO = @IDARTICULO_SYNC
							  AND NOITEM = 1
						)
						BEGIN
							INSERT INTO TARDV (
								IDTARIFA, IDSERVICIO, NOITEM, VALOR, FECHAINI, FECHAFIN, TIPOVALOR
							)
							VALUES (
								@IDTARIFA_OSTEO, @IDARTICULO_SYNC, 1, @VALOR,
								DATEFROMPARTS(YEAR(GETDATE()), 1, 1),
								DATEFROMPARTS(YEAR(GETDATE()), 12, 31),
								'Valor'
							);
						END;

						/*
						  Equivale al flujo manual de SerCPPAFComponent:
						  1. RPDX.CPPAF_INSERTAR_TODOS_PLANES.
						  2. SER.GENERAR_CPPAF (SPK_CFG_SERCPPAF).
						  Los consecutivos conservan el formato aleatorio de 10 caracteres usado en frontend.
						*/
						DECLARE @CNSRPDX_CPPAF VARCHAR(20), @CNSRPDX2_CPPAF VARCHAR(20);

						SET @CNSRPDX_CPPAF = '';
						WHILE @CNSRPDX_CPPAF = ''
						   OR EXISTS (SELECT 1 FROM RPDX WHERE CNS = @CNSRPDX_CPPAF)
						   OR EXISTS (SELECT 1 FROM RPDX2 WHERE CNS = @CNSRPDX_CPPAF)
						BEGIN
							SET @CNSRPDX_CPPAF = UPPER(LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10));
						END;

						SET @CNSRPDX2_CPPAF = '';
						WHILE @CNSRPDX2_CPPAF = ''
						   OR @CNSRPDX2_CPPAF = @CNSRPDX_CPPAF
						   OR EXISTS (SELECT 1 FROM RPDX WHERE CNS = @CNSRPDX2_CPPAF)
						   OR EXISTS (SELECT 1 FROM RPDX2 WHERE CNS = @CNSRPDX2_CPPAF)
						BEGIN
							SET @CNSRPDX2_CPPAF = UPPER(LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10));
						END;

						INSERT INTO RPDX (CNS, IDTERCERO, ID1, ID2, CANTIDAD1)
						SELECT DISTINCT
							@CNSRPDX_CPPAF,
							CPPAF.IDPLAN,
							CPPAF.IDTERCEROCA,
							CASE WHEN CPPAF.COBRARA = 'C' THEN 'C' ELSE 'O' END,
							0
						FROM CPPAF
						INNER JOIN PLN ON PLN.IDPLAN = CPPAF.IDPLAN
						LEFT JOIN TER ON TER.IDTERCERO = CPPAF.IDTERCEROCA
						WHERE PLN.ESTADO = 'Activo';

						-- Todas las �reas funcionales activas, equivalente a seleccionar cada AFU en SerCPPAFComponent.
						INSERT INTO RPDX2 (CNS, IDTERCERO)
						SELECT @CNSRPDX2_CPPAF, AFU.IDAREA
						FROM AFU
						WHERE AFU.ESTADO = 1;

						EXEC SPK_CFG_SERCPPAF @IDARTICULO_SYNC, @CNSRPDX_CPPAF, @CNSRPDX2_CPPAF;

						INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
						VALUES (@FILA_EXCEL, @CODIGO, 'OK', NULL);
						END;
					END;
				END TRY
				BEGIN CATCH
					INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
					VALUES (@FILA_EXCEL, @CODIGO, 'KO', ERROR_MESSAGE());
				END CATCH
			END
			ELSE
			BEGIN
				INSERT INTO @RESULTADOS_MAT (FILA, CODIGO, OK, MENSAJE)
				VALUES (@FILA_EXCEL, @CODIGO, 'KO', @ERR);
			END;

			FETCH NEXT FROM CUR_FILAS_MAT
			INTO @ITEM, @FILA_EXCEL, @IDTGEN_IN, @CODIGO, @DESCRIPCION, @REFERENCIA, @VALOR, @CASA_COMERCIAL, @IDTERCERO_IN, @NOM_TERCERO_IN;
		END;

		CLOSE CUR_FILAS_MAT;
		DEALLOCATE CUR_FILAS_MAT;

		SELECT
			OK = 'OK',
			TOTAL = (SELECT COUNT(*) FROM #FILAS_MAT_OSTEO),
			OK_COUNT = (SELECT COUNT(*) FROM @RESULTADOS_MAT WHERE OK = 'OK');

		SELECT
			FILA = FILA,
			CODIGO = CODIGO,
			MENSAJE = MENSAJE
		FROM @RESULTADOS_MAT
		WHERE OK <> 'OK';

		RETURN;
	END;
	IF @METODO = 'ELIMINAR_MAT_OSTEO'
	BEGIN
		SELECT
			@IDTGEN = IDTGEN,
			@CODIGO = CODIGO,
			@REFERENCIA = REFERENCIA
		FROM OPENJSON(@PARAMETROS)
		WITH (
			IDTGEN INT '$.IDTGEN',
			CODIGO VARCHAR(20) '$.CODIGO',
			REFERENCIA VARCHAR(255) '$.REFERENCIA'
		);

		SET @CODIGO = NULLIF(LTRIM(RTRIM(@CODIGO)), '');
		SET @REFERENCIA = NULLIF(LTRIM(RTRIM(@REFERENCIA)), '');

		IF COALESCE(@IDTGEN, 0) = 0
		   AND (@CODIGO IS NULL OR @REFERENCIA IS NULL)
		BEGIN
			INSERT INTO @TBLERRORES SELECT 'IDTGEN o la clave CODIGO + REFERENCIA son obligatorios.'
			SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
		END

		IF COALESCE(@IDTGEN, 0) > 0
		BEGIN
			SELECT
				@CODIGO = CODIGO,
				@REFERENCIA = CAMPO,
				@IDARTICULO_SYNC = COALESCE(NULLIF(LTRIM(RTRIM(DATO1)), ''), CAMPO)
			FROM TGEN WITH (NOLOCK)
			WHERE IDTGEN = @IDTGEN AND TABLA = 'IART_OSTEO';
		END
		ELSE
		BEGIN
			SELECT
				@IDTGEN = IDTGEN,
				@IDARTICULO_SYNC = COALESCE(NULLIF(LTRIM(RTRIM(DATO1)), ''), CAMPO)
			FROM TGEN WITH (NOLOCK)
			WHERE TABLA = 'IART_OSTEO'
			  AND CODIGO = @CODIGO
			  AND CAMPO = @REFERENCIA;
		END

		IF COALESCE(@IDTGEN, 0) = 0
		BEGIN
			INSERT INTO @TBLERRORES SELECT 'El material no existe en el cat�logo IART_OSTEO.'
			SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
		END

		IF EXISTS (SELECT 1 FROM IARTOD WITH (NOLOCK) WHERE IDTGEN = @IDTGEN)
		BEGIN
			INSERT INTO @TBLERRORES SELECT 'No se puede eliminar: el material est� referenciado en solicitudes de osteos�ntesis.'
			SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
		END

		SET @PREFIJO_OSTEO = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('PREOSTEO_CX'), '')));

		BEGIN TRY
			BEGIN TRANSACTION;

			DELETE FROM TGEN WHERE IDTGEN = @IDTGEN AND TABLA = 'IART_OSTEO';

			IF COALESCE(@IDARTICULO_SYNC, '') <> ''
			   AND NOT EXISTS (
					SELECT 1
					FROM TGEN WITH (NOLOCK)
					WHERE TABLA = 'IART_OSTEO'
					  AND COALESCE(NULLIF(LTRIM(RTRIM(DATO1)), ''), CAMPO) = @IDARTICULO_SYNC
			   )
			BEGIN
				IF COALESCE(@PREFIJO_OSTEO, '') <> ''
				BEGIN
					DELETE FROM SER
					WHERE IDSERVICIO = @IDARTICULO_SYNC
					  AND PREFIJO = @PREFIJO_OSTEO;
				END

				IF EXISTS (SELECT 1 FROM IEXI WITH (NOLOCK) WHERE IDARTICULO = @IDARTICULO_SYNC AND COALESCE(EXISLOTE, 0) <> 0)
				BEGIN
					UPDATE IART SET ESTADO = 'Inactivo' WHERE IDARTICULO = @IDARTICULO_SYNC;
				END
				ELSE
				BEGIN
					DELETE FROM IART WHERE IDARTICULO = @IDARTICULO_SYNC;
				END
			END

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			INSERT INTO @TBLERRORES SELECT ERROR_MESSAGE();
		END CATCH

		IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
		BEGIN
			SELECT 'KO' OK SELECT ERROR FROM @TBLERRORES RETURN
		END

		SELECT 'OK' OK RETURN
	END
END
