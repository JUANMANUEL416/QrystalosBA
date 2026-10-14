CREATE OR ALTER PROCEDURE DBO.SPQ_GESVENTA
@JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
DECLARE   @PARAMETROS       NVARCHAR(MAX),      @MODELO         VARCHAR(100)	,@METODO      VARCHAR(100)	,@IDSEDE VARCHAR(20)
        , @QUERY            VARCHAR(MAX),       @USUARIO        VARCHAR(12)		,@NVOCONSEC   VARCHAR(20)	,@COMPANIA VARCHAR(20)
        , @SEDE             VARCHAR(5)        , @NOADMISION     VARCHAR(16)		,@FECHA       VARCHAR(20)  , @FECHA_DATETIME       DATETIME        
        , @HORA             VARCHAR(10)       , @ITEM           SMALLINT		,@OBS         VARCHAR(2048)
        , @SYS_COMPUTERNAME VARCHAR(254)      , @GRUPO          VARCHAR(8)		,@PENDIENTES  SMALLINT	, @PROCEDIMIENTO VARCHAR(50)
        , @CNSMOV           VARCHAR(20)		  , @FIRMA			VARBINARY(MAX)	,@IDBODEGA VARCHAR(20)	,@FECHA_DESDE VARCHAR(10)
		  , @DATOS NVARCHAR(MAX)	, @PROCESO VARCHAR(50)	, @FECHA_HASTA VARCHAR(10) , @CLASE VARCHAR(50) , @N_FACTURA VARCHAR(20)
        , @OBSERVACION VARCHAR(200) ,@USUARIO_ANULA VARCHAR(20)   ,@SQL  VARCHAR(MAX), @IDTERCERO VARCHAR(20), @CNSFNOT VARCHAR(20)
        , @IDMODELOCONT VARCHAR(20)
BEGIN   
   SET DATEFORMAT dmy
   --SELECT @JSON
   SELECT *
   INTO #JSON
   FROM OPENJSON (@json)
   WITH (
      MODELO  VARCHAR(100) '$.MODELO',
      METODO  VARCHAR(100) '$.METODO',
      USUARIO VARCHAR(20) '$.USUARIO',
      PARAMETROS NVARCHAR(MAX) AS JSON
   )
   SELECT @MODELO = MODELO , @METODO = METODO , @PARAMETROS = PARAMETROS, @USUARIO = USUARIO
   FROM #JSON
   --DEFINICION DE TABLA DE ERRORES
   DECLARE @TBLERRORES TABLE(ERROR VARCHAR(200));
   	SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME FROM USUSU WHERE USUARIO = @USUARIO
	SELECT @SEDE = IDSEDE, @IDSEDE = IDSEDE, @COMPANIA = COMPANIA FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME

	IF @METODO = 'GEN_NC'
   BEGIN
    DECLARE @NOREINGERSO BIT
    SELECT @CNSMOV = CNSMOV, @PROCESO = PROCESO, @DATOS = DATOS, @N_FACTURA = N_FACTURA, @USUARIO_ANULA = USUARIO_ANULA, 
    @NOREINGERSO=CASE WHEN NO_GENERAR_REINGRESO='True' THEN 1 ELSE 0 END,
    @OBSERVACION = OBSERVACION
    FROM OPENJSON(@PARAMETROS)
    WITH(	CNSMOV	VARCHAR(20)		'$.CNSMOV', DATOS		NVARCHAR(MAX) AS JSON , PROCESO	VARCHAR(20)		'$.PROCESO'
      , N_FACTURA	VARCHAR(20)		'$.N_FACTURA', USUARIO_ANULA	VARCHAR(20)		'$.USUARIO_ANULA', 
      NO_GENERAR_REINGRESO  VARCHAR(20)   '$.NO_GENERAR_REINGRESO',
      OBSERVACION	VARCHAR(200)		'$.OBSERVACION')

    IF OBJECT_ID('tempdb..#DATOS') IS NOT NULL
    BEGIN
        DROP TABLE #DATOS;
    END;
    CREATE TABLE #DATOS (
        CNSFTR VARCHAR(20),
        N_CUOTA INT,
        CNSMOV VARCHAR(20),
        IDARTICULO VARCHAR(20),
        DESCRIPCION VARCHAR(500),
        CANTIDAD_A_DEVOLVER DECIMAL(14,2),
        VALOR DECIMAL(14,2),
        VR_TOTAL DECIMAL(14,2),
        NOLOTE VARCHAR(20)
    );
    
    IF @PROCESO = 'Parcial'
    BEGIN
       INSERT INTO #DATOS (CNSFTR, N_CUOTA, CNSMOV, IDARTICULO, DESCRIPCION, CANTIDAD_A_DEVOLVER, NOLOTE, VALOR, VR_TOTAL)
       SELECT CNSFTR, N_CUOTA, CNSMOV, IDARTICULO, DESCRIPCION, CANTIDAD_A_DEVOLVER, NOLOTE , VALOR, VR_TOTAL
       FROM OPENJSON (@DATOS)
       WITH(       CNSFTR					   VARCHAR(20)						'$.CNSFTR'
                ,N_CUOTA					   INT					'$.N_CUOTA'
                ,CNSMOV				   VARCHAR(20)				'$.CNSMOV'
                ,IDARTICULO				   VARCHAR(20)				'$.IDARTICULO'
                ,DESCRIPCION				   VARCHAR(500)				'$.DESCRIPCION'
                ,CANTIDAD_A_DEVOLVER    DECIMAL(14,2)					'$.CANTIDAD_A_DEVOLVER'
                ,VALOR    DECIMAL(14,2)					'$.VALOR'
                ,VR_TOTAL    DECIMAL(14,2)					'$.VR_TOTAL'
                ,NOLOTE			         VARCHAR(20)					'$.NOLOTE' )
    END

    IF @PROCESO = 'Total'
    BEGIN
       INSERT INTO #DATOS (CNSFTR, N_CUOTA, CNSMOV, IDARTICULO, CANTIDAD_A_DEVOLVER, NOLOTE, DESCRIPCION, VALOR, VR_TOTAL)
       SELECT FTRD.CNSFTR, FTRD.N_CUOTA, ISAL.CNSMOV , ISAL.IDARTICULO,ISAL.CANTIDAD,ISAL.NOLOTE, IART.DESCRIPCION, FTRD.VALOR, FTRD.VR_TOTAL
       FROM ISAL
       INNER JOIN FTRD ON ISAL.NOLOTE = FTRD.NOLOTE AND ISAL.IDARTICULO = FTRD.IDARTICULO
       INNER JOIN IART ON ISAL.IDARTICULO = IART.IDARTICULO
       WHERE ISAL.CNSMOV = @CNSMOV
    END

    -- VALIDACIONES: Si fallan, CANTDEV NO debe modificarse
    IF EXISTS (SELECT 1 FROM #DATOS WHERE COALESCE(CANTIDAD_A_DEVOLVER,0) = 0 ) and  @PROCESO = 'Parcial'
    BEGIN
        INSERT INTO @TBLERRORES(ERROR) SELECT 'Existen registros marcados, que no no tienen cantidades a devolver, Solo marcar, las que si tienen cantidades a devolver.'
    END
    
    IF @PROCESO = 'Parcial' AND DBO.FNK_VALORVARIABLE('FNOT_PAR_CONCEPTO') = ''
    BEGIN
        INSERT INTO @TBLERRORES(ERROR) SELECT 'Debe de configurar la variable FNOT_PAR_CONCEPTO, para las devolcuiones parciales.'
    END

    -- VALIDACIONES ADICIONALES ANTES DE PROCESAR
    -- Validar que la factura existe y no tiene notas asociadas (para proceso Total)
    IF @PROCESO = 'Total'
    BEGIN
        -- Validar que la factura existe
        IF NOT EXISTS (SELECT 1 FROM FTR WHERE N_FACTURA = @N_FACTURA)
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) SELECT 'La factura no existe'
        END
        
        -- Validar que la factura no tiene notas de cr�dito/d�bito asociadas
        IF EXISTS (SELECT 1 FROM FNOT WHERE N_FACTURA = @N_FACTURA AND ESTADO <> 'E')
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) SELECT 'Factura tiene Notas Debito/Credito Asociadas no se puede Anular'
        END
        
        -- Validar que la factura est� correctamente contabilizada si fue enviada a la DIAN
        IF EXISTS (SELECT 1 FROM FTR WHERE N_FACTURA = @N_FACTURA AND FACTE IN ('2','3') AND (COALESCE(CONTABILIZADA,0) = 0 OR COALESCE(NROCOMPROBANTE,'') = ''))
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) SELECT 'La Factura no se Encuentra correctamente contabilizada y ya fue enviada a la Dian. Es necesaria su Contabilizaci�n para generar la nota Cr�dito correspondiente'
        END
    END
    
    -- Si hay errores de validaci�n, retornar sin modificar CANTDEV
    IF (SELECT COUNT(*) FROM @TBLERRORES)> 0
    BEGIN
        SELECT 'KO' OK
        SELECT ERROR FROM @TBLERRORES
        RETURN  -- IMPORTANTE: Salir aqu� sin modificar CANTDEV
    END
    ELSE
    BEGIN
        -- Usar transacci�n para asegurar que si algo falla, se revierta todo incluyendo CANTDEV
        BEGIN TRANSACTION
        
        BEGIN TRY
            IF @PROCESO = 'Total'
            BEGIN
               -- Crear tabla temporal para capturar el resultado de SPQ_JSON
               IF OBJECT_ID('tempdb..#RESULTADO_ANULAR') IS NOT NULL
               BEGIN
                   DROP TABLE #RESULTADO_ANULAR;
               END
               CREATE TABLE #RESULTADO_ANULAR (OK VARCHAR(2), ERROR VARCHAR(MAX))
               
               SELECT @SQL = '{"MODELO":"FTR_COL","METODO":"ANULARFAC","PARAMETROS":{"N_FACTURA":"'+@N_FACTURA+'","USUANULA":"'+@USUARIO_ANULA+'","OBSANULA":"'+@OBSERVACION+'","PART":false,"NOREINGERSO":"'+CAST(@NOREINGERSO AS VARCHAR(2))+'"},"USUARIO":"'+@USUARIO+'"}'
               
               -- Ejecutar SPQ_JSON y capturar el resultado
               INSERT INTO #RESULTADO_ANULAR(OK)
               EXEC SPQ_JSON @SQL
               
               -- Validar que la anulaci�n fue exitosa
               DECLARE @RESULTADO_OK VARCHAR(2)
               SELECT @RESULTADO_OK = OK FROM #RESULTADO_ANULAR
               
               IF @RESULTADO_OK <> 'OK' OR @RESULTADO_OK IS NULL
               BEGIN
                   -- Si hay errores, capturarlos y hacer ROLLBACK
                   DECLARE @ERROR_MSG VARCHAR(MAX) = ''
                   SELECT @ERROR_MSG = STRING_AGG(ERROR, CHAR(13) + CHAR(10)) 
                   FROM #RESULTADO_ANULAR 
                   WHERE ERROR IS NOT NULL
                   
                   IF @ERROR_MSG = '' OR @ERROR_MSG IS NULL
                   BEGIN
                       SET @ERROR_MSG = 'Error al anular la factura. La factura no se pudo anular correctamente.'
                   END
                   
                   RAISERROR(@ERROR_MSG, 16, 1)
               END
               
               SELECT TOP 1 @CNSFNOT = CNSFNOT FROM FNOT WHERE N_FACTURA = @N_FACTURA ORDER BY  F_NOTA  DESC
               
               -- Validar que se cre� la nota de cr�dito
               IF @CNSFNOT IS NULL OR @CNSFNOT = ''
               BEGIN
                   RAISERROR('No se pudo crear la nota de cr�dito despu�s de anular la factura', 16, 1)
               END
               
               -- ACTUALIZAR CANTDEV SOLO DESPU�S DE QUE TODO SEA EXITOSO
               -- Esta actualizaci�n se hace al final, despu�s de todas las operaciones exitosas
               UPDATE ISAL SET CANTDEV = CANTIDAD WHERE ISAL.CNSMOV = @CNSMOV
            END
            
            IF @PROCESO = 'Parcial'
            BEGIN
               SELECT @CLASE = 'C'
               EXEC SPK_GENCONSECUTIVO @COMPANIA,@IDSEDE, '@FNOTC', @CNSFNOT OUTPUT  

               PRINT '@CNSFNOT='+COALESCE(@CNSFNOT,'')   
               SELECT @CNSFNOT = @IDSEDE +LTRIM(RTRIM(@CLASE))+ REPLACE(SPACE(8 - LEN(@CNSFNOT))+LTRIM(RTRIM(@CNSFNOT)),SPACE(1),0)
               PRINT '@CNSFNOT='+COALESCE(@CNSFNOT,'')   

               SELECT @IDMODELOCONT = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE')

               INSERT INTO FNOT(CNSFNOT, CLASE, N_FACTURA, CNSCXC, IDTERCERO, F_NOTA, VR_TOTAL, OBSERVACION, MARCA, MARCACONT, 
                       CONTABILIZADA, NROCOMPROBANTE, IMPRESO, COMPANIA, USUARIO, CERRADA, ESTADO, USUARIOANU,  
                       USUARIOSOL, FECHAANU, RAZONANU, PROCEDENCIA, CNSGLO, APLICADAA, LIBERAHADM, CODUNG, CODPRG, 
                       ENPRESUPUESTO, IDTERCEROCOBERTURA, COBERTURA_AUT_POR, CONCEPTO, IDCONCEPTO, TIPOCONCEPTO,  
                       VALORCONCEPTO, USUARIOAPLICA, DETGENERADOS, CONSECUTIVOPPTO, RECO, FACTE, CNSRESOLFE, 
                       PREFIJODIANFE, CNSDIANFE, CNSMASIVO, ZIPKEY, CUDE, FACTEP, RUTARPTA, DOCUMENTOID, DOCUXMLXZIPID,
                       XMLZIPID, SOLICITUDJSON, RESPUESTAJSON, PDF) 
               SELECT @CNSFNOT, @CLASE, @N_FACTURA, FCXCD.CNSCXC,FTR.IDTERCERO, DBO.FNK_GETDATE(),0,@OBSERVACION, 0, 0, 
                       0, NULL, 0, @COMPANIA, @USUARIO, 0, 'O', NULL,NULL, NULL, NULL, 'NOTAS', NULL,
                       'C',0, NULL, NULL, 0, NULL, NULL, 
                       NULL,DBO.FNK_VALORVARIABLE('FNOT_PAR_CONCEPTO'), 'P',0, NULL, 0, NULL, NULL, NULL, NULL,NULL, NULL,
                       NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0
               FROM FTR
               LEFT JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA 
               WHERE FTR.N_FACTURA = @N_FACTURA

               INSERT INTO FNOTD(CNSFNOT, CLASE, ITEM, TIPO, IDSERVICIO, DESCRIPCION, CANTIDAD, VR_UNITARIO, VR_TOTAL, COMPANIA, 
                  USUARIO, OBSERVACION, N_CUOTA, PIVA, VALORIVA, N_FACTURA, CCOSTO, IDAREA, PREFIJO, CUENTA, NOLOTE_DEV, CNSMOV_DEV )
               SELECT @CNSFNOT, @CLASE, ROW_NUMBER() OVER(ORDER BY #DATOS.IDARTICULO), 'S', #DATOS.IDARTICULO, #DATOS.DESCRIPCION, #DATOS.CANTIDAD_A_DEVOLVER, #DATOS.VALOR, #DATOS.VALOR*#DATOS.CANTIDAD_A_DEVOLVER, @COMPANIA, 
                  @USUARIO, @OBSERVACION, #DATOS.N_CUOTA, FTRD.PIVA, FTRD.VIVA, FTRD.N_FACTURA, FTRD.CCOSTO, FTRD.AREAFUNCONT, FTRD.PREFIJO
                  , DBO.FNK_NC_CUENTA_KMCOM(@IDMODELOCONT,'VENTAS','CR',FTRD.PREFIJO, FTRD.CCOSTO,'P','',0), #DATOS.NOLOTE, #DATOS.CNSMOV
               FROM #DATOS, FTRD
               WHERE #DATOS.CNSFTR = FTRD.CNSFTR AND #DATOS.N_CUOTA = FTRD.N_CUOTA

               UPDATE FTRD SET FTRD.VLRNOTACR=#DATOS.CANTIDAD_A_DEVOLVER*#DATOS.VALOR   FROM #DATOS, FTRD
               WHERE #DATOS.CNSFTR = FTRD.CNSFTR AND #DATOS.N_CUOTA = FTRD.N_CUOTA

               DECLARE @VLR_TOTAL  DECIMAL(14,2)
               SELECT @VLR_TOTAL=SUM(VR_TOTAL) FROM FNOTD WHERE  CNSFNOT=@CNSFNOT
               UPDATE FNOT SET VR_TOTAL=@VLR_TOTAL,VALORCONCEPTO=@VLR_TOTAL  WHERE CNSFNOT=@CNSFNOT

               EXEC SPK_NOTASCXC  @CNSFNOT, @CLASE, NULL, @SEDE, @COMPANIA, @USUARIO, @SYS_COMPUTERNAME

               IF EXISTS (SELECT 1 FROM FNOT WHERE CNSFNOT = @CNSFNOT AND COALESCE(FACTE,0) = 0)
               BEGIN
                  UPDATE FNOT SET FACTE = 1 WHERE  CNSFNOT = @CNSFNOT
               END

               -- ACTUALIZAR CANTDEV SOLO DESPU�S DE QUE TODO SEA EXITOSO
               -- Esta actualizaci�n se hace al final, despu�s de todas las operaciones exitosas
               UPDATE ISAL SET  ISAL.CANTDEV = COALESCE(ISAL.CANTDEV,0)+ #DATOS.CANTIDAD_A_DEVOLVER FROM ISAL,#DATOS 
               WHERE ISAL.CNSMOV = #DATOS.CNSMOV AND ISAL.NOLOTE = #DATOS.NOLOTE 
            END
            
            -- Si llegamos aqu�, todo fue exitoso, hacer COMMIT
            COMMIT TRANSACTION
            
            SELECT 'OK' OK
        END TRY  
        BEGIN CATCH 
            -- Si hay error, hacer ROLLBACK para revertir TODOS los cambios incluyendo CANTDEV
            IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION
            END
            
            -- Capturar el mensaje de error
            DECLARE @ERROR_MESSAGE VARCHAR(MAX) = ERROR_MESSAGE()
            DECLARE @ERROR_NUMBER INT = ERROR_NUMBER()
            DECLARE @ERROR_SEVERITY INT = ERROR_SEVERITY()
            DECLARE @ERROR_STATE INT = ERROR_STATE()
            
            INSERT INTO @TBLERRORES(ERROR) SELECT @ERROR_MESSAGE
            
            -- Si el error viene de SPQ_JSON, intentar capturar los errores de la tabla temporal
            IF OBJECT_ID('tempdb..#RESULTADO_ANULAR') IS NOT NULL
            BEGIN
                INSERT INTO @TBLERRORES(ERROR)
                SELECT ERROR FROM #RESULTADO_ANULAR WHERE ERROR IS NOT NULL
            END
            
            SELECT 'KO' OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END CATCH  
    END 
END
   --  
END
