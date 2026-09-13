CREATE OR ALTER PROCEDURE DBO.SPQ_PRI
@JSON  NVARCHAR(MAX)
WITH
ENCRYPTION
AS
DECLARE @PARAMETROS     NVARCHAR(MAX)  ,@MODELO           VARCHAR(100)    ,@METODO   VARCHAR(100)  ,@USUARIO        VARCHAR(12)
        ,@GRUPO         VARCHAR(8)     ,@SYS_COMPUTERNAME VARCHAR(254)    ,@SEDE     VARCHAR(5)	   ,@A              INT
        ,@IDENTITY      INT 
        ,@PROCESO       VARCHAR(20)    
        ,@PRI           NVARCHAR(MAX)
        ,@COMPANIA      VARCHAR(2)='01'
        ,@ANO           VARCHAR(4)
        ,@MES           VARCHAR(2)
        ,@NOMPERIODO    VARCHAR(30)
        ,@FECHA_INI     DATETIME
        ,@FECHA_FIN     VARCHAR(20)
        ,@PAAG          DECIMAL(9,5)
        ,@CERRADO_INV   BIT
        ,@CERRADO_FAC   BIT
        ,@CERRADO       BIT
        ,@SI            BIT
        ,@SINIIF        BIT 
        ,@ANOMES        VARCHAR(7)
        ,@TIPO_AJ       VARCHAR(12)
        ,@TCAMBIOFINAL  DECIMAL(14,2)
        ,@PROCEDENCIA   VARCHAR(20)
        ,@DATOS VARCHAR(MAX)
BEGIN
    SET LANGUAGE Spanish
    SET DATEFORMAT dmy
   
    SELECT @A = ISJSON(@JSON)
    IF @A = 0
    BEGIN
        RAISERROR('Json: Formato Erroneo',16,1)
        RETURN
    END
    SELECT *
    INTO #JSON
    FROM OPENJSON (@json)
    WITH (
        MODELO         VARCHAR(100)     '$.MODELO',
        METODO         VARCHAR(100)     '$.METODO',
        USUARIO        VARCHAR(12)      '$.USUARIO',
        PARAMETROS     NVARCHAR(MAX)     AS JSON
    )
   
    SELECT @MODELO = MODELO , @METODO = METODO , @PARAMETROS = PARAMETROS , @USUARIO = USUARIO
    FROM #JSON
    DECLARE @TBLERRORES TABLE(ERROR VARCHAR(200))
    IF COALESCE(@SEDE,'') = '' SELECT @SEDE = '01'

    IF @METODO = 'CRUDPRI'
    BEGIN
        SELECT @PRI  = REGISTRO
        FROM OPENJSON (@PARAMETROS)
        WITH(
            REGISTRO   NVARCHAR(MAX)     AS JSON
        )

        SELECT @PROCESO     = JSON_VALUE(@PRI ,'$.PROCESO')
        SELECT @COMPANIA = '01'
        SELECT @ANO = JSON_VALUE(@PRI , '$.ANO' )
        SELECT @MES = JSON_VALUE(@PRI , '$.MES' )
        SELECT @NOMPERIODO = JSON_VALUE(@PRI , '$.NOMPERIODO' )
        SELECT @FECHA_INI = TRY_CAST(JSON_VALUE(@PRI , '$.FECHA_INI') AS date)
        SELECT @FECHA_FIN = JSON_VALUE(@PRI , '$.FECHA_FIN')
        SELECT @PAAG = JSON_VALUE(@PRI , '$.PAAG' )
        SELECT @TIPO_AJ = JSON_VALUE(@PRI , '$.TIPO_AJ' )
        SELECT @CERRADO_INV = JSON_VALUE(@PRI , '$.CERRADO_INV' )
        SELECT @CERRADO_FAC = JSON_VALUE(@PRI , '$.CERRADO_FAC' )
        SELECT @SI = JSON_VALUE(@PRI , '$.SI' )
        SELECT @SINIIF = JSON_VALUE(@PRI , '$.SINIIF' )
        SELECT @ANOMES = JSON_VALUE(@PRI , '$.ANOMES' )
        SELECT @TCAMBIOFINAL = JSON_VALUE(@PRI , '$.TCAMBIOFINAL' )
        
        IF COALESCE(@ANOMES,'')=''
        BEGIN
            SELECT @ANOMES=@ANO+RIGHT(('00'+@MES),2)
        END
        PRINT @ANOMES
        IF @SI=1 AND EXISTS (SELECT 1 FROM PRI WHERE SI=1 AND ANOMES<>@ANOMES)
            INSERT INTO @TBLERRORES (ERROR) SELECT 'Ya existe un periodo de saldos iniciales, no pueden existir mas de uno'

        IF @SINIIF=1 AND EXISTS (SELECT 1 FROM PRI WHERE SINIIF=1 AND ANOMES<>@ANOMES)
            INSERT INTO @TBLERRORES (ERROR) SELECT 'Ya existe un periodo de saldos iniciales, no pueden existir mas de uno'
        
        IF UPPER(@PROCESO) = 'INSERTAR'
        BEGIN
            IF EXISTS (SELECT 1 FROM PRI WHERE ANO=@ANO AND MES=@MES)
            BEGIN
                INSERT INTO @TBLERRORES (ERROR) SELECT CONCAT('Periodo insertado ya existe, por favor validar, Periodo: ', @ANOMES)
            END
            IF (SELECT COUNT(1) FROM @TBLERRORES)> 0
            BEGIN
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
            BEGIN TRY
                INSERT INTO PRI(COMPANIA,ANO,MES,NOMPERIODO,FECHA_INI,FECHA_FIN,CERRADO,
                                    AJUSTADO,PAAG,COMPROBANTE,DOCUMENTO,NROCOMPROBANTE,TIPO_AJ,CERRADO_INV,
                                    NROCOMPROBANTE_AJI,COMPROBANTE_AJI,NOREFERENCIA_AJI,CERRADO_CARTERA,DESALDOSINICIALES,CERRADO_FAC,SI,
                                    CIERREFISCAL,EJERCICIOMES,BDATOS,CIERRECOSTOS,CIERREIMP,CERRADO_PPTO,CERRADONIIF,
                                    DETCARTERANIIF,DETINVENTARIONIIF,COMP_DETCARTERA,COMP_DETINVENTARIO,SINIIF,CERRADO_CXP,
                                    MCIERRECOSTOS,NROCOMTRASCOSTO,CIERRE_TRASCOSTOS,CIEFISNIIF,TCAMBIOFINAL,KARDEXHISTO)
                SELECT @COMPANIA,@ANO,@MES,@NOMPERIODO,@FECHA_INI,TRY_CAST(REPLACE(@FECHA_FIN,'-','')+' 23:59:59' AS datetime),0,
                                    0,@PAAG,'','','',@TIPO_AJ,@CERRADO_INV,
                                    '','','',0,0,@CERRADO_FAC,@SI,
                                    0,0,'',0,0,0,0,
                                    0,0,'','',@SINIIF,0,
                                    0,'',0,0,@TCAMBIOFINAL,0
            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
            END CATCH
            IF (SELECT COUNT(1) FROM @TBLERRORES)> 0
            BEGIN
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
            SELECT 'OK' OK
            RETURN
        END
        IF UPPER(@PROCESO) = 'EDITAR'
        BEGIN
            BEGIN TRY
                UPDATE PRI SET NOMPERIODO = @NOMPERIODO,FECHA_INI = @FECHA_INI,FECHA_FIN = TRY_CAST(REPLACE(@FECHA_FIN,'-','')+' 23:59:59' AS datetime),
                            CERRADO_INV = @CERRADO_INV,CERRADO_FAC = @CERRADO_FAC,SI = @SI,SINIIF = @SINIIF,
                            TCAMBIOFINAL = @TCAMBIOFINAL, PAAG = @PAAG, TIPO_AJ = @TIPO_AJ                
                WHERE ANOMES=@ANOMES
            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
            END CATCH
            IF (SELECT COUNT(1) FROM @TBLERRORES)> 0
            BEGIN
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
            SELECT 'OK' OK
            RETURN
        END
        RETURN
    END
    IF @METODO='CERRAR_FACTURA'     
    BEGIN         
        SELECT @DATOS=DATOS        
        FROM   OPENJSON (@PARAMETROS)
        WITH (           
            DATOS NVARCHAR(MAX) AS JSON 
        )
                 
        SELECT @ANO=ANIO,@MES=MES,@CERRADO=CERRADO,@PROCEDENCIA=PROCEDENCIA      
        FROM OPENJSON (@DATOS)
        WITH ( 
            ANIO  VARCHAR(4)   '$.ANIO',
            MES  SMALLINT   '$.MES',
            CERRADO  BIT   '$.CERRADO',
            PROCEDENCIA  VARCHAR(20)   '$.PROCEDENCIA'
        )   
        IF COALESCE(@CERRADO,0)<>0
        BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT 'Periodo Cerrado...'
        END
        IF @PROCEDENCIA='FACTURA'
        BEGIN
            IF NOT EXISTS(SELECT * FROM PRI WHERE ANO=@ANO AND MES=@MES AND CERRADO_FAC=0)
            BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT 'No se Encontro el Periodo de Facturación o ya esta Cerrado. Verifique e intente de nuevo'
            END
        END
        IF @PROCEDENCIA='CARTERA'
        BEGIN
            IF NOT EXISTS(SELECT * FROM PRI WHERE ANO=@ANO AND MES=@MES AND CERRADO_CARTERA=0)
            BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT 'No se Encontro el Periodo de Cartera o ya esta Cerrado. Verifique e intente de nuevo'
            END
        END      
        IF EXISTS( SELECT 1 FROM MCPE WHERE PROCEDENCIA IN('CXC','RAD CXC','NOTDBCR','FACTURA','RGLO','CONCI')AND MES=@MES   AND ANO=@ANO AND COALESCE(CLASECONTB,'')<>'NIIF')
        BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT 'Existen comprobantes con Error que Afectan la Cartera, no se puede cerrar con comprobantes  con error'
        END
        IF(SELECT COUNT(1) FROM @TBLERRORES)>0
        BEGIN
            SELECT 'KO' OK, ERROR FROM @TBLERRORES
            RETURN
        END
        BEGIN TRY   
            EXEC SPK_CIERRA_CARTERA @ANO,@MES,@USUARIO,@PROCEDENCIA                
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
        END CATCH
        IF(SELECT COUNT(1) FROM @TBLERRORES)>0
        BEGIN
            SELECT 'KO' OK, ERROR FROM @TBLERRORES
            RETURN
        END
        SELECT 'OK' OK
        RETURN 
    END

    IF @METODO = 'ABRIR_FACTURA'
    BEGIN
        SELECT @DATOS = DATOS
        FROM OPENJSON (@PARAMETROS)
        WITH (
            DATOS NVARCHAR(MAX) AS JSON
        )

        SELECT @ANO = ANIO, @MES = MES, @CERRADO = CERRADO, @PROCEDENCIA = PROCEDENCIA
        FROM OPENJSON (@DATOS)
        WITH (
            ANIO VARCHAR(4) '$.ANIO',
            MES SMALLINT '$.MES',
            CERRADO BIT '$.CERRADO',
            PROCEDENCIA VARCHAR(20) '$.PROCEDENCIA'
        )

        IF COALESCE(@CERRADO, 0) = 0
        BEGIN
            INSERT INTO @TBLERRORES (ERROR)
            SELECT N'El periodo no está cerrado; no se puede abrir.'
        END

        IF @PROCEDENCIA = 'FACTURA'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA AND CERRADO_FAC = 1)
            BEGIN
                INSERT INTO @TBLERRORES (ERROR)
                SELECT N'No se encontró el periodo de facturación o ya está abierto. Verifique e intente de nuevo.'
            END
        END
        ELSE IF @PROCEDENCIA = 'CARTERA'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA AND CERRADO_CARTERA = 1)
            BEGIN
                INSERT INTO @TBLERRORES (ERROR)
                SELECT N'No se encontró el periodo de cartera o ya está abierto. Verifique e intente de nuevo.'
            END
            INSERT INTO @TBLERRORES (ERROR)
            SELECT CONCAT(
                N'Ya pasaron ',
                CAST(DATEDIFF(DAY, DBO.FNK_DIA_DEL_MES(@ANO, @MES, 'ULTIMO'), GETDATE()) AS VARCHAR(11)),
                N' días; ya no es posible la apertura de la cartera para este periodo contable.'
            )
            FROM PRI AS P
            WHERE P.ANO = @ANO
              AND P.MES = @MES
              AND P.COMPANIA = @COMPANIA
              AND DATEDIFF(DAY, DBO.FNK_DIA_DEL_MES(P.ANO, P.MES, 'ULTIMO'), GETDATE()) >= 25
        END
        ELSE IF @PROCEDENCIA = 'CXP'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA AND CERRADO_CXP = 1)
            BEGIN
                INSERT INTO @TBLERRORES (ERROR)
                SELECT N'No se encontró el periodo de CxP o ya está abierto. Verifique e intente de nuevo.'
            END
        END
        ELSE
        BEGIN
            INSERT INTO @TBLERRORES (ERROR)
            SELECT N'Procedencia no válida para abrir periodo.'
        END

        IF (SELECT COUNT(1) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK, ERROR FROM @TBLERRORES
            RETURN
        END

        BEGIN TRY
            IF @PROCEDENCIA = 'FACTURA'
            BEGIN
                UPDATE PRI
                SET CERRADO_FAC = 0
                WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA
            END
            ELSE IF @PROCEDENCIA = 'CARTERA'
            BEGIN
                UPDATE PRI
                SET CERRADO_CARTERA = 0
                WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA

                DELETE FROM FCARTH
                WHERE ANO = @ANO AND MES = @MES AND PROCEDENCIA = 'CARTERA'
            END
            ELSE IF @PROCEDENCIA = 'CXP'
            BEGIN
                UPDATE PRI
                SET CERRADO_CXP = 0
                WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA
            END
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES (ERROR) SELECT ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(1) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK, ERROR FROM @TBLERRORES
            RETURN
        END

        SELECT 'OK' AS OK
        RETURN
    END
END

