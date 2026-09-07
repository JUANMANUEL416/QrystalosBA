CREATE OR ALTER PROCEDURE DBO.SPQ_MCPE_COL
@JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
DECLARE @PARAMETROS NVARCHAR(MAX), @MODELO VARCHAR(100), @METODO VARCHAR(100), @USUARIO VARCHAR(12)
    ,@NROCOMPROBANTE VARCHAR(20), @ERROR_MSG VARCHAR(500), @MENSAJE_FINAL VARCHAR(1000)
    ,@RECONSTRUIDOS INT, @ERRORES_REC INT, @SYS_COMPUTERNAME VARCHAR(254), @SEDE VARCHAR(5)
    ,@COMPANIA VARCHAR(2), @ANO INT, @MES INT, @PROCEDENCIA VARCHAR(50), @CLASECONTB VARCHAR(10)
    ,@REF1 VARCHAR(50), @REF2 VARCHAR(50), @REF3 VARCHAR(50), @NOREFERENCIA VARCHAR(50)
    ,@CERRADO BIT, @CERRADO_INV BIT, @CERRADO_CARTERA BIT, @LONGITUDCODBANCO INT
    ,@CLASE_FAC VARCHAR(20), @CNSCXC VARCHAR(50), @VLR_PAGOS DECIMAL(18,2), @ITEMREF VARCHAR(50)
    ,@DUPLICADOS_ELIMINADOS INT, @DUPLICADOS_ANTES INT, @DUPLICADOS_DESPUES INT
    ,@COMPROBANTE VARCHAR(2) --STORRES - SE AGREGA PARA VALIDACION DE REPETIDOS

DECLARE @COMP AS TABLE(ITEM INT IDENTITY(1,1), NROCOMPROBANTE VARCHAR(100))
DECLARE @TBLERRORES TABLE(ERROR VARCHAR(500))

BEGIN
    SET LANGUAGE Spanish
    SET DATEFORMAT dmy
   

    SELECT * INTO #JSON
    FROM OPENJSON (@json)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        USUARIO VARCHAR(12) '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    )
   
    SELECT @MODELO = MODELO, @METODO = METODO, @PARAMETROS = PARAMETROS, @USUARIO = USUARIO
    FROM #JSON
   
    SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME FROM USUSU WHERE USUARIO = @USUARIO
    SELECT @SEDE = ISNULL(IDSEDE, '01') FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME
    SELECT @COMPANIA = '01'
    

   /*STORRES - 20260325 - SE AGREGA VALIDACION DE LA VARIABLE QUIEN DETERMINA SI LA LONGITUD DEL BANCO*/
   SET @LONGITUDCODBANCO = DBO.FNK_VALORVARIABLE('LONGITUDCODBANCO')
   SET @LONGITUDCODBANCO = CASE WHEN @LONGITUDCODBANCO LIKE '%[^0-9]%' OR @LONGITUDCODBANCO IS NULL OR @LONGITUDCODBANCO = ''
                                THEN 2
                                ELSE CAST(@LONGITUDCODBANCO AS INT)
                           END
   /*STORRES - 20260325 - SE AGREGA VALIDACION DE LA VARIABLE QUIEN DETERMINA SI LA LONGITUD DEL BANCO*/

    IF @METODO = 'OBTENER_ERRORES_DETALLE'
    BEGIN
        SELECT @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')
        
        SELECT 
            MCHE.CUENTA,
            MCHE.DETALLE,
            MCHE.VALOR,
            MCHE.TIPO,
            'La cuenta ' + MCHE.CUENTA + ' no existe en el plan de cuentas' AS DESCRIPCION_ERROR
        FROM MCHE 
        WHERE MCHE.NROCOMPROBANTE = @NROCOMPROBANTE 
          AND NOT EXISTS(SELECT 1 FROM CUE WHERE MCHE.CUENTA = CUE.CUENTA)
        ORDER BY CUENTA
        
        RETURN
    END

    IF @METODO = 'RECONSTRUIR'
    BEGIN
        BEGIN TRY

            INSERT INTO @COMP (NROCOMPROBANTE)
            SELECT VALUE FROM OPENJSON(@PARAMETROS, '$.COMPROBANTES')

            SELECT TOP 1 @NROCOMPROBANTE = C.NROCOMPROBANTE
            FROM @COMP C  INNER JOIN MCPE ON MCPE.NROCOMPROBANTE = C.NROCOMPROBANTE
            WHERE MCPE.PROCEDENCIA = 'MANUAL'

            IF @NROCOMPROBANTE IS NOT NULL
            BEGIN
                SELECT @ERROR_MSG = 'No se pueden reconstruir comprobantes MANUALES: ' + @NROCOMPROBANTE
                RAISERROR (@ERROR_MSG, 16, 1)
            END

            SELECT TOP 1 @NROCOMPROBANTE = NROCOMPROBANTE
            FROM @COMP
            WHERE NROCOMPROBANTE NOT IN (SELECT NROCOMPROBANTE FROM MCPE)
            
            IF COALESCE(@NROCOMPROBANTE, '') <> ''
            BEGIN
                SELECT @ERROR_MSG = 'Comprobante ' + @NROCOMPROBANTE + ' no existe en MCPE'
                RAISERROR (@ERROR_MSG, 16, 1)
            END

            SELECT TOP 1 @NROCOMPROBANTE = MCP.NROCOMPROBANTE
            FROM @COMP C 
            INNER JOIN MCP ON MCP.NROCOMPROBANTE = C.NROCOMPROBANTE

            IF @NROCOMPROBANTE IS NOT NULL
            BEGIN
                SELECT @ERROR_MSG = 'El comprobante ' + @NROCOMPROBANTE + ' ya está contabilizado'
                RAISERROR (@ERROR_MSG, 16, 1)
            END

            SELECT TOP 1 @NROCOMPROBANTE = C.NROCOMPROBANTE  
            FROM @COMP C 
            INNER JOIN MCPE ON MCPE.NROCOMPROBANTE = C.NROCOMPROBANTE
            WHERE ISNULL(MCPE.ANULADO, 0) = 1

            IF @NROCOMPROBANTE IS NOT NULL
            BEGIN
                SELECT @ERROR_MSG = 'No se puede reconstruir un comprobante anulado: ' + @NROCOMPROBANTE
                RAISERROR (@ERROR_MSG, 16, 1)
            END

            DECLARE cur_periodo CURSOR FOR
            SELECT C.NROCOMPROBANTE, M.ANO, M.MES, M.PROCEDENCIA, ISNULL(M.CLASECONTB, ''), M.COMPANIA
            FROM @COMP C 
            INNER JOIN MCPE M ON M.NROCOMPROBANTE = C.NROCOMPROBANTE

            OPEN cur_periodo
            FETCH NEXT FROM cur_periodo INTO @NROCOMPROBANTE, @ANO, @MES, @PROCEDENCIA, @CLASECONTB, @COMPANIA

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @CLASECONTB <> 'NIIF'
                BEGIN
                    SELECT @CERRADO = ISNULL(CERRADO, 0) FROM PRI 
                    WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA
                    
                    IF @CERRADO = 1
                    BEGIN
                        SELECT @ERROR_MSG = 'Período cerrado para: ' + @NROCOMPROBANTE
                        RAISERROR (@ERROR_MSG, 16, 1)
                    END

                    IF @PROCEDENCIA = 'INV'
                    BEGIN
                        SELECT @CERRADO_INV = ISNULL(CERRADO_INV, 0) FROM PRI 
                        WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA
                        
                        IF @CERRADO_INV = 1
                        BEGIN
                            SELECT @ERROR_MSG = 'Inventario cerrado para: ' + @NROCOMPROBANTE
                            RAISERROR (@ERROR_MSG, 16, 1)
                        END
                    END

                    IF @PROCEDENCIA IN ('CXC', 'RAD CXC', 'NOTDBCR', 'FACTURA', 'RGLO', 'CONCI')
                    BEGIN
                        SELECT @CERRADO_CARTERA = CASE WHEN ISNULL(CERRADO_CARTERA,0)=1 OR ISNULL(CERRADO_FAC,0)=1 THEN 1 ELSE 0 END 
                        FROM PRI WHERE ANO = @ANO AND MES = @MES AND COMPANIA = @COMPANIA
                        
                        IF @CERRADO_CARTERA = 1
                        BEGIN
                            SELECT @ERROR_MSG = 'Cartera/Facturación cerrada para: ' + @NROCOMPROBANTE
                            RAISERROR (@ERROR_MSG, 16, 1)
                        END
                    END
                END

                FETCH NEXT FROM cur_periodo INTO @NROCOMPROBANTE, @ANO, @MES, @PROCEDENCIA, @CLASECONTB, @COMPANIA
            END

            CLOSE cur_periodo
            DEALLOCATE cur_periodo

            SET @RECONSTRUIDOS = 0
            SET @ERRORES_REC = 0
            DECLARE @SQL_EXEC NVARCHAR(2000)

            DECLARE _cursor CURSOR FOR   
            SELECT NROCOMPROBANTE FROM @COMP
          
            OPEN _cursor  
            FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
          
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
                BEGIN TRY
                    
                    PRINT ' ========== RECONSTRUYENDO COMPROBANTE: ' + @NROCOMPROBANTE + ' =========='
                    
                    DECLARE @REGISTROS_ELIMINADOS_PRE INT = 0
                    DECLARE @TOTAL_REGISTROS_PRE INT = 0
                    
                    SELECT @TOTAL_REGISTROS_PRE = COUNT(*)
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    
                    IF @TOTAL_REGISTROS_PRE > 0
                    BEGIN
                        PRINT ' LIMPIEZA PRE-RECONSTRUCCIÓN OBLIGATORIA: Eliminando TODOS los ' + CAST(@TOTAL_REGISTROS_PRE AS VARCHAR) + ' registro(s) existente(s) del comprobante ' + @NROCOMPROBANTE + ' antes de reconstruir'
                        
                        DELETE FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        
                        SET @REGISTROS_ELIMINADOS_PRE = @@ROWCOUNT
                        PRINT ' LIMPIEZA PRE-RECONSTRUCCIÓN COMPLETADA: Se eliminaron ' + CAST(@REGISTROS_ELIMINADOS_PRE AS VARCHAR) + ' registro(s) del comprobante ' + @NROCOMPROBANTE
                    END
                    ELSE
                    BEGIN
                        PRINT ' VALIDACIÓN PRE-RECONSTRUCCIÓN: No hay registros existentes en comprobante ' + @NROCOMPROBANTE + '. Procediendo con reconstrucción.'
                    END
                    
                    SELECT @PROCEDENCIA = PROCEDENCIA, @REF1 = REFERENCIA1, @REF2 = REFERENCIA2, 
                           @REF3 = REFERENCIA3, @NOREFERENCIA = NOREFERENCIA, @COMPROBANTE = COMPROBANTE
                    FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    
                    IF @PROCEDENCIA IS NULL
                    BEGIN
                       PRINT ' ERROR: No se encontró el comprobante ' + @NROCOMPROBANTE + ' en MCPE'
                       INSERT INTO @TBLERRORES(ERROR) VALUES('Comprobante ' + @NROCOMPROBANTE + ' no existe en MCPE')
                       SET @ERRORES_REC = @ERRORES_REC + 1
                       FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
                       CONTINUE
                    END
                    
                    PRINT ' VALIDACIÓN PRE-RECONSTRUCCIÓN: Comprobante=' + @NROCOMPROBANTE + ' | Procedencia=' + ISNULL(@PROCEDENCIA, 'NULL') + ' | NOREFERENCIA=' + ISNULL(@NOREFERENCIA, 'NULL')
                    
                    IF @NOREFERENCIA IS NOT NULL AND LTRIM(RTRIM(@NOREFERENCIA)) != ''
                    BEGIN
                       DECLARE @COMPROBANTES_DUPLICADOS INT = 0
                       DECLARE @NROCOMPROBANTE_DUPLICADO VARCHAR(20) = NULL
                       
                       SELECT @COMPROBANTES_DUPLICADOS = COUNT(*)
                       FROM MCPE
                       WHERE NOREFERENCIA = @NOREFERENCIA
                         AND NROCOMPROBANTE != @NROCOMPROBANTE 
                         AND MCPE.PROCEDENCIA = @PROCEDENCIA -- STORRES - 20260325 -- SE AGREGA COMPARACION PROCEDENCIA POR QUE INDICA DILICIDAD CON DOCUEMNTOS QUE NO CORRESPONDEN
                         AND MCPE.COMPROBANTE = @COMPROBANTE -- STORRES - 20260413 -- SE AGREGA COMPARACION COMPROBANTE POR QUE INDICA DILICIDAD CON DOCUEMNTOS QUE NO CORRESPONDEN
                         AND COMPANIA = @COMPANIA
                       
                       IF @COMPROBANTES_DUPLICADOS > 0
                       BEGIN
                          PRINT ' ========== ADVERTENCIA CRÍTICA: Se detectaron ' + CAST(@COMPROBANTES_DUPLICADOS AS VARCHAR) + ' comprobante(s) duplicado(s) con NOREFERENCIA=' + @NOREFERENCIA + ' diferente(s) a ' + @NROCOMPROBANTE + ' =========='
                          
                          SELECT TOP 1 @NROCOMPROBANTE_DUPLICADO = NROCOMPROBANTE
                          FROM MCPE
                          WHERE NOREFERENCIA = @NOREFERENCIA
                            AND NROCOMPROBANTE != @NROCOMPROBANTE
                            AND COMPANIA = @COMPANIA
                          ORDER BY NROCOMPROBANTE ASC
                          
                          PRINT ' ERROR CRÍTICO: Existe comprobante duplicado ' + @NROCOMPROBANTE_DUPLICADO + ' con NOREFERENCIA=' + @NOREFERENCIA + '. Se requiere revisión manual antes de reconstruir.'
                          INSERT INTO @TBLERRORES(ERROR) VALUES('ERROR CRÍTICO: Existe comprobante duplicado ' + @NROCOMPROBANTE_DUPLICADO + ' con NOREFERENCIA=' + @NOREFERENCIA + '. No se puede reconstruir ' + @NROCOMPROBANTE + ' hasta resolver el duplicado.')
                          SET @ERRORES_REC = @ERRORES_REC + 1
                          FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
                          CONTINUE
                       END
                    END

                    SET @SQL_EXEC = NULL
                    
                    IF @PROCEDENCIA = 'NOTDBCRCXP'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_CXPFNT ''' + ISNULL(@REF1,'') + ''',''' + ISNULL(@REF2,'') + ''',''' + 
                                       @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'FACTURA'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_FTR ''' + ISNULL(@NOREFERENCIA,'') + ''',''' + @COMPANIA + ''',''' + 
                                       @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'CAJA'
                    BEGIN
                        SELECT @CLASE_FAC = CLASE_FAC FROM FCJ WHERE CNSFACJ = @REF1 AND CODCAJA = @REF2
                        
                        IF UPPER(@CLASE_FAC) = 'COBRO'
                           BEGIN 
                            SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_CAJA_ING ''' + ISNULL(@REF1,'') + ''',''' + ISNULL(@REF2,'') + ''',''' + 
                                           @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                                           PRINT @SQL_EXEC
                           END
                        ELSE IF UPPER(@CLASE_FAC) = 'PAGO'
                            SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_CAJA_EGR ''' + ISNULL(@REF1,'') + ''',''' + ISNULL(@REF2,'') + ''',''' + 
                                           @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'INV'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_INV ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'IACT'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_CONTAB_IACT ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'CXP'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_CXP ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'CXC'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_CXC ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'NOTDBCR'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_FNOT ''' + ISNULL(@REF1,'') + ''',''' + ISNULL(@REF2,'') + ''',''' + 
                                       @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'RGLO'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_CONTAB_FGLO ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'BMOV'
                    BEGIN
                        SELECT @ITEMREF = ISNULL(ITEMREF, @REF2) FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        IF @ITEMREF IS NULL SET @ITEMREF = @REF2
                        
                        IF @LONGITUDCODBANCO = 3
                            SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_BMOV ''' + ISNULL(SUBSTRING(@REF1,1,3),'') + ''',''' + ISNULL(SUBSTRING(@REF1,4,2),'') + ''',''' + 
                                           ISNULL(SUBSTRING(@REF1,6,20),'') + ''',''' + ISNULL(@ITEMREF,'') + ''',''' + @USUARIO + ''',''' + 
                                           @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                        ELSE
                            SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_BMOV ''' + ISNULL(SUBSTRING(@REF1,1,2),'') + ''',''' + ISNULL(SUBSTRING(@REF1,3,2),'') + ''',''' + 
                                           ISNULL(SUBSTRING(@REF1,5,20),'') + ''',''' + ISNULL(@ITEMREF,'') + ''',''' + @USUARIO + ''',''' + 
                                           @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'CESIONES'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_CONTAB_FCES ''' + ISNULL(@REF1,'') + ''',''' + @COMPANIA + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'LEGALIZACION'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_CONTAB_FLEG ''' + ISNULL(@REF1,'') + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + 
                                       @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA IN ('REVCAJAING', 'REVCAJAEGR', 'REVNOTDBCR')
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_REVERSAR_MCP ''' + ISNULL(@REF3,'') + ''','''','''','''','''',''' + @COMPANIA + ''',''' + 
                                       @SEDE + ''',''' + @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'AJDEP'
                    BEGIN
                        SELECT @ANO = ANO, @MES = MES FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        SET @SQL_EXEC = 'EXEC SPK_APL_AJDEPRECIACION ''' + @COMPANIA + ''',''' + @SEDE + ''',''' + 
                                       CAST(@ANO AS VARCHAR) + ''',''' + CAST(@MES AS VARCHAR) + ''',''' + @USUARIO + ''',''' + 
                                       @SYS_COMPUTERNAME + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'NOMINA'
                    BEGIN
                        DECLARE @FECHA_CONTABLE VARCHAR(8)
                        SELECT @FECHA_CONTABLE = CONVERT(VARCHAR(8), FECHACONTABLE, 112) FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_NOMINA ''' + ISNULL(@REF2,'') + ''',''' + ISNULL(@REF1,'') + ''',''' + ISNULL(@REF3,'') + ''',''' + 
                                       @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + 
                                       @NROCOMPROBANTE + ''',''' + @FECHA_CONTABLE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'RAD CXC'
                    BEGIN
                        SET @CNSCXC = @REF1
                        IF ISNULL(@CNSCXC, '') = ''
                        BEGIN
                            SELECT TOP 1 @CNSCXC = ISNULL(REFERENCIA1, ISNULL(REFERENCIA_PRO, DETALLE))
                            FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        END
                        
                        IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'FCXC')
                        BEGIN
                            SELECT @VLR_PAGOS = ISNULL(VLRPAGOS + VLRNOTADB + VLRNOTACR + VLRGLOSAS + VLRGLOSAS_R, 0)
                            FROM FCXC WHERE CNSCXC = @CNSCXC
                        END
                        ELSE
                        BEGIN
                            SET @VLR_PAGOS = 0
                        END
                        
                        IF @VLR_PAGOS > 0
                            SET @SQL_EXEC = 'EXEC SPK_CONTAB_RADICACXC_1 ''' + ISNULL(@CNSCXC,'') + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + 
                                           @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @NROCOMPROBANTE + ''''
                        ELSE
                            SET @SQL_EXEC = 'EXEC SPK_CONTAB_RADICACXC ''' + ISNULL(@CNSCXC,'') + ''',''' + @COMPANIA + ''',''' + @SEDE + ''',''' + 
                                           @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + @NROCOMPROBANTE + ''''
                    END
                    
                    ELSE IF @PROCEDENCIA = 'CONCI'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_CONTAB_CONCI ''' + ISNULL(@REF1,'') + ''',''' + @USUARIO + ''',''' + @SYS_COMPUTERNAME + ''',''' + 
                                       @COMPANIA + ''',''' + @SEDE + ''',''' + @NROCOMPROBANTE + ''''
                    END
					--Nuevo para reconstruir anticipos
					ELSE IF @PROCEDENCIA = 'ANTICIPOS'
                    BEGIN
                        SET @SQL_EXEC = 'EXEC SPK_NC_CONTAB_ANTICIPO ''' + ISNULL(@REF1,'') + ''',''' + 
                                       ISNULL(@REF2,'') + ''',''' + @SEDE + ''',''' + @USUARIO + ''',''' + 
                                       @NROCOMPROBANTE + ''''
                    END
                    
                   
                    IF @SQL_EXEC IS NOT NULL
                    BEGIN
                        PRINT 'Ejecutando: ' + @SQL_EXEC
                        
                        DECLARE @NOREFERENCIA_ORIGINAL VARCHAR(50) = @NOREFERENCIA
                        DECLARE @COMPROBANTES_MCPE_ANTES INT = 0
                        DECLARE @COMPROBANTES_MCPE_DESPUES INT = 0
                        
                        IF @NOREFERENCIA_ORIGINAL IS NOT NULL AND LTRIM(RTRIM(@NOREFERENCIA_ORIGINAL)) != ''
                        BEGIN
                           SELECT @COMPROBANTES_MCPE_ANTES = COUNT(*)
                           FROM MCPE
                           WHERE NOREFERENCIA = @NOREFERENCIA_ORIGINAL
                             AND COMPANIA = @COMPANIA
                        END
                        
                        EXEC sp_executesql @SQL_EXEC
                        SET @RECONSTRUIDOS = @RECONSTRUIDOS + 1
                        
                        PRINT ' RECONSTRUCCIÓN COMPLETADA para ' + @NROCOMPROBANTE
                        
                        IF @NOREFERENCIA_ORIGINAL IS NOT NULL AND LTRIM(RTRIM(@NOREFERENCIA_ORIGINAL)) != ''
                        BEGIN
                           SELECT @COMPROBANTES_MCPE_DESPUES = COUNT(*)
                           FROM MCPE
                           WHERE NOREFERENCIA = @NOREFERENCIA_ORIGINAL
                             AND COMPANIA = @COMPANIA
                           
                           IF @COMPROBANTES_MCPE_DESPUES > @COMPROBANTES_MCPE_ANTES
                           BEGIN
                              PRINT ' ========== ERROR CRÍTICO: Se detectó creación de comprobante(s) duplicado(s) en MCPE con NOREFERENCIA=' + @NOREFERENCIA_ORIGINAL + ' =========='
                              PRINT ' Comprobantes ANTES: ' + CAST(@COMPROBANTES_MCPE_ANTES AS VARCHAR) + ' | DESPUÉS: ' + CAST(@COMPROBANTES_MCPE_DESPUES AS VARCHAR)
                              
                              DECLARE @DUPLICADOS_MCPE_ELIMINADOS INT = 0
                              
                              DECLARE @COMPROBANTES_DUPLICADOS_A_ELIMINAR TABLE(NROCOMPROBANTE_DUP VARCHAR(20))
                              
                              INSERT INTO @COMPROBANTES_DUPLICADOS_A_ELIMINAR
                              SELECT NROCOMPROBANTE
                              FROM MCPE
                              WHERE NOREFERENCIA = @NOREFERENCIA_ORIGINAL
                                AND NROCOMPROBANTE != @NROCOMPROBANTE
                                AND COMPANIA = @COMPANIA
                              
                              DECLARE @NROCOMPROBANTE_DUP VARCHAR(20)
                              DECLARE cur_eliminar_duplicados CURSOR FOR
                              SELECT NROCOMPROBANTE_DUP FROM @COMPROBANTES_DUPLICADOS_A_ELIMINAR
                              
                              OPEN cur_eliminar_duplicados
                              FETCH NEXT FROM cur_eliminar_duplicados INTO @NROCOMPROBANTE_DUP
                              
                              WHILE @@FETCH_STATUS = 0
                              BEGIN
                                 DECLARE @REGISTROS_MCHE_ELIMINADOS INT = 0
                                 
                                 SELECT @REGISTROS_MCHE_ELIMINADOS = COUNT(*)
                                 FROM MCHE
                                 WHERE NROCOMPROBANTE = @NROCOMPROBANTE_DUP
                                 
                                 DELETE FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE_DUP
                                 
                                 PRINT ' LIMPIEZA MCHE: Se eliminaron ' + CAST(@REGISTROS_MCHE_ELIMINADOS AS VARCHAR) + ' registro(s) MCHE del comprobante duplicado ' + @NROCOMPROBANTE_DUP
                                 
                                 FETCH NEXT FROM cur_eliminar_duplicados INTO @NROCOMPROBANTE_DUP
                              END
                              
                              CLOSE cur_eliminar_duplicados
                              DEALLOCATE cur_eliminar_duplicados
                              
                              DELETE FROM MCPE
                              WHERE NOREFERENCIA = @NOREFERENCIA_ORIGINAL
                                AND NROCOMPROBANTE != @NROCOMPROBANTE
                                AND COMPANIA = @COMPANIA
                              
                              SET @DUPLICADOS_MCPE_ELIMINADOS = @@ROWCOUNT
                              
                              IF @DUPLICADOS_MCPE_ELIMINADOS > 0
                              BEGIN
                                 PRINT ' LIMPIEZA MCPE: Se eliminaron ' + CAST(@DUPLICADOS_MCPE_ELIMINADOS AS VARCHAR) + ' comprobante(s) duplicado(s) en MCPE con NOREFERENCIA=' + @NOREFERENCIA_ORIGINAL
                                 PRINT ' LIMPIEZA MCPE COMPLETADA: Se eliminaron todos los comprobantes duplicados en MCPE'
                              END
                              
                              DECLARE @VERIFICACION_FINAL_MCPE INT = 0
                              SELECT @VERIFICACION_FINAL_MCPE = COUNT(*)
                              FROM MCPE
                              WHERE NOREFERENCIA = @NOREFERENCIA_ORIGINAL
                                AND COMPANIA = @COMPANIA
                              
                              IF @VERIFICACION_FINAL_MCPE > 1
                              BEGIN
                                 PRINT ' ========== ERROR CRÍTICO PERSISTENTE: Aún existen ' + CAST(@VERIFICACION_FINAL_MCPE AS VARCHAR) + ' comprobante(s) con NOREFERENCIA=' + @NOREFERENCIA_ORIGINAL + ' después de la limpieza =========='
                                 INSERT INTO @TBLERRORES(ERROR) VALUES('ERROR CRÍTICO: Aún existen ' + CAST(@VERIFICACION_FINAL_MCPE AS VARCHAR) + ' comprobante(s) duplicado(s) con NOREFERENCIA=' + @NOREFERENCIA_ORIGINAL + ' después de la limpieza. Se requiere revisión manual.')
                              END
                              ELSE
                              BEGIN
                                 PRINT ' VERIFICACIÓN FINAL MCPE: OK - Solo existe 1 comprobante con NOREFERENCIA=' + @NOREFERENCIA_ORIGINAL
                              END
                           END
                        END
                        
                        DECLARE @TOTAL_REGISTROS_POST INT = 0
                        DECLARE @REGISTROS_UNICOS_POST INT = 0
                        DECLARE @ITERACION_LIMPIEZA INT = 0
                        DECLARE @MAX_ITERACIONES_LIMPIEZA INT = 20
                        DECLARE @DUPLICADOS_ELIMINADOS_ITERACION INT = 0
                        
                        SET @DUPLICADOS_DESPUES = 0
                        SET @DUPLICADOS_ELIMINADOS = 0
                        
                        PRINT ' INICIANDO LIMPIEZA POST-RECONSTRUCCIÓN AGRESIVA para comprobante ' + @NROCOMPROBANTE
                        
                        WHILE @ITERACION_LIMPIEZA < @MAX_ITERACIONES_LIMPIEZA
                        BEGIN
                           SET @ITERACION_LIMPIEZA = @ITERACION_LIMPIEZA + 1
                           
                           SELECT @TOTAL_REGISTROS_POST = COUNT(*)
                           FROM MCHE
                           WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                           AND CUENTA IS NOT NULL
                           AND TIPO IS NOT NULL
                           AND VALOR IS NOT NULL
                           
                           IF @TOTAL_REGISTROS_POST = 0
                              BREAK
                           
                           SELECT @REGISTROS_UNICOS_POST = COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                           FROM MCHE
                           WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                           AND CUENTA IS NOT NULL
                           AND TIPO IS NOT NULL
                           AND VALOR IS NOT NULL
                           
                           SET @DUPLICADOS_DESPUES = @TOTAL_REGISTROS_POST - @REGISTROS_UNICOS_POST
                           
                           IF @DUPLICADOS_DESPUES = 0
                           BEGIN
                              PRINT ' Iteración ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ': OK - No se detectaron duplicados. Limpieza completada.'
                              BREAK
                           END
                           
                           PRINT ' Iteración ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ': Detectados ' + CAST(@DUPLICADOS_DESPUES AS VARCHAR) + ' duplicado(s). Eliminando...'
                           
                           DELETE m1
                           FROM MCHE m1
                           WHERE EXISTS (
                              SELECT 1
                              FROM (
                                 SELECT NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01') AS COMPANIA, MIN(NROASIENTO) AS MIN_NROASIENTO
                                 FROM MCHE
                                 WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                                 AND CUENTA IS NOT NULL
                                 AND TIPO IS NOT NULL
                                 AND VALOR IS NOT NULL
                                 GROUP BY NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01')
                                 HAVING COUNT(*) > 1
                              ) m2
                              WHERE m1.NROCOMPROBANTE = m2.NROCOMPROBANTE
                                AND m1.CUENTA = m2.CUENTA
                                AND m1.TIPO = m2.TIPO
                                AND ABS(m1.VALOR - m2.VALOR) < 0.01
                                AND ISNULL(m1.COMPANIA, '01') = m2.COMPANIA
                                AND m1.NROASIENTO != m2.MIN_NROASIENTO
                           )
                           
                           SET @DUPLICADOS_ELIMINADOS_ITERACION = @@ROWCOUNT
                           SET @DUPLICADOS_ELIMINADOS = @DUPLICADOS_ELIMINADOS + @DUPLICADOS_ELIMINADOS_ITERACION
                           
                           IF @DUPLICADOS_ELIMINADOS_ITERACION > 0
                           BEGIN
                              PRINT ' Iteración ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ' completada: Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS_ITERACION AS VARCHAR) + ' duplicado(s)'
                           END
                           ELSE
                           BEGIN
                              PRINT ' Iteración ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ': No se eliminaron registros. Verificando...'
                              BREAK
                           END
                        END
                        
                        IF @DUPLICADOS_ELIMINADOS > 0
                        BEGIN
                           PRINT ' LIMPIEZA POST-RECONSTRUCCIÓN COMPLETADA: Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS AS VARCHAR) + ' duplicado(s) en ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ' iteración(es)'
                           SET @MENSAJE_FINAL = 'Comprobante ' + @NROCOMPROBANTE + ' reconstruido. Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS AS VARCHAR) + ' duplicado(s).'
                        END
                        ELSE
                        BEGIN
                           PRINT ' VALIDACIÓN POST-RECONSTRUCCIÓN: OK - No se detectaron duplicados en comprobante ' + @NROCOMPROBANTE
                        END
                        
                        DECLARE @VERIFICACION_FINAL_POST INT = 0
                        SELECT @VERIFICACION_FINAL_POST = COUNT(*) - COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                        FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA IS NOT NULL
                        AND TIPO IS NOT NULL
                        AND VALOR IS NOT NULL
                        
                        IF @VERIFICACION_FINAL_POST > 0
                        BEGIN
                           PRINT ' ERROR CRÍTICO: Aún existen ' + CAST(@VERIFICACION_FINAL_POST AS VARCHAR) + ' duplicado(s) después de ' + CAST(@ITERACION_LIMPIEZA AS VARCHAR) + ' iteraciones. Ejecutando limpieza final de emergencia...'
                           
                           DECLARE @ITERACION_EMERGENCIA INT = 0
                           WHILE @VERIFICACION_FINAL_POST > 0 AND @ITERACION_EMERGENCIA < 10
                           BEGIN
                              SET @ITERACION_EMERGENCIA = @ITERACION_EMERGENCIA + 1
                              
                              DELETE m1
                              FROM MCHE m1
                              WHERE EXISTS (
                                 SELECT 1
                                 FROM (
                                    SELECT NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01') AS COMPANIA, MIN(NROASIENTO) AS MIN_NROASIENTO
                                    FROM MCHE
                                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                                    AND CUENTA IS NOT NULL
                                    AND TIPO IS NOT NULL
                                    AND VALOR IS NOT NULL
                                    GROUP BY NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01')
                                    HAVING COUNT(*) > 1
                                 ) m2
                                 WHERE m1.NROCOMPROBANTE = m2.NROCOMPROBANTE
                                   AND m1.CUENTA = m2.CUENTA
                                   AND m1.TIPO = m2.TIPO
                                   AND ABS(m1.VALOR - m2.VALOR) < 0.01
                                   AND ISNULL(m1.COMPANIA, '01') = m2.COMPANIA
                                   AND m1.NROASIENTO != m2.MIN_NROASIENTO
                              )
                              
                              SELECT @VERIFICACION_FINAL_POST = COUNT(*) - COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                              FROM MCHE
                              WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                              AND CUENTA IS NOT NULL
                              AND TIPO IS NOT NULL
                              AND VALOR IS NOT NULL
                              
                              IF @VERIFICACION_FINAL_POST = 0
                                 BREAK
                           END
                           
                           IF @VERIFICACION_FINAL_POST = 0
                           BEGIN
                              PRINT ' Limpieza de emergencia completada exitosamente. No quedan duplicados.'
                           END
                           ELSE
                           BEGIN
                              PRINT ' ADVERTENCIA CRÍTICA: Aún quedan ' + CAST(@VERIFICACION_FINAL_POST AS VARCHAR) + ' duplicado(s) después de la limpieza de emergencia. Se requiere revisión manual.'
                           END
                        END
                        ELSE
                        BEGIN
                           PRINT ' VERIFICACIÓN FINAL: OK - No se detectaron duplicados después de la limpieza.'
                        END
                    END
                    ELSE
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('Procedencia no soportada: ' + ISNULL(@PROCEDENCIA, 'NULL') + ' para ' + @NROCOMPROBANTE)
                        SET @ERRORES_REC = @ERRORES_REC + 1
                    END

                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES(ERROR) VALUES('Error en ' + @NROCOMPROBANTE + ': ' + ERROR_MESSAGE())
                    SET @ERRORES_REC = @ERRORES_REC + 1
                END CATCH

                FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
            END  
         
            CLOSE _cursor  
            DEALLOCATE _cursor  
            
            PRINT ' ========== VALIDACIÓN FINAL MCPE: Verificando y eliminando comprobantes duplicados en MCPE por NOREFERENCIA =========='
            
            DECLARE @DUPLICADOS_MCPE_FINAL INT = 0
            DECLARE @ITERACION_MCPE_FINAL INT = 0
            DECLARE @MAX_ITERACIONES_MCPE_FINAL INT = 50
            
            WHILE @ITERACION_MCPE_FINAL < @MAX_ITERACIONES_MCPE_FINAL
            BEGIN
               SET @ITERACION_MCPE_FINAL = @ITERACION_MCPE_FINAL + 1
               
               SELECT @DUPLICADOS_MCPE_FINAL = COUNT(*) - COUNT(DISTINCT NOREFERENCIA)
               FROM MCPE
               WHERE NOREFERENCIA IS NOT NULL
                 AND LTRIM(RTRIM(NOREFERENCIA)) != ''
                 AND COMPANIA = @COMPANIA
                 AND NROCOMPROBANTE IN (SELECT NROCOMPROBANTE FROM @COMP)
               
               IF @DUPLICADOS_MCPE_FINAL = 0
               BEGIN
                  IF @ITERACION_MCPE_FINAL = 1
                  BEGIN
                     PRINT ' VALIDACIÓN FINAL MCPE: No se detectaron comprobantes duplicados por NOREFERENCIA'
                  END
                  ELSE
                  BEGIN
                     PRINT ' Iteración ' + CAST(@ITERACION_MCPE_FINAL AS VARCHAR) + ': OK - Todos los comprobantes duplicados en MCPE eliminados'
                  END
                  BREAK
               END
               
               PRINT ' Iteración ' + CAST(@ITERACION_MCPE_FINAL AS VARCHAR) + ': Detectados ' + CAST(@DUPLICADOS_MCPE_FINAL AS VARCHAR) + ' comprobante(s) duplicado(s) en MCPE. Eliminando...'
               
               DECLARE @COMPROBANTES_DUPLICADOS_MCPE TABLE(NOREFERENCIA_DUP VARCHAR(50), NROCOMPROBANTE_DUP VARCHAR(20))
               
               INSERT INTO @COMPROBANTES_DUPLICADOS_MCPE
               SELECT NOREFERENCIA, NROCOMPROBANTE
               FROM MCPE m1
               WHERE EXISTS (
                  SELECT 1
                  FROM (
                     SELECT NOREFERENCIA, MIN(NROCOMPROBANTE) AS MIN_NROCOMPROBANTE
                     FROM MCPE
                     WHERE NOREFERENCIA IS NOT NULL
                       AND LTRIM(RTRIM(NOREFERENCIA)) != ''
                       AND COMPANIA = @COMPANIA
                       AND NROCOMPROBANTE IN (SELECT NROCOMPROBANTE FROM @COMP)
                     GROUP BY NOREFERENCIA
                     HAVING COUNT(*) > 1
                  ) m2
                  WHERE m1.NOREFERENCIA = m2.NOREFERENCIA
                    AND m1.NROCOMPROBANTE != m2.MIN_NROCOMPROBANTE
                    AND m1.COMPANIA = @COMPANIA
               )
               
               DECLARE @NOREFERENCIA_DUP VARCHAR(50)
               DECLARE @NROCOMPROBANTE_DUP_MCPE VARCHAR(20)
               DECLARE cur_eliminar_mcpe_duplicados CURSOR FOR
               SELECT NOREFERENCIA_DUP, NROCOMPROBANTE_DUP FROM @COMPROBANTES_DUPLICADOS_MCPE
               
               OPEN cur_eliminar_mcpe_duplicados
               FETCH NEXT FROM cur_eliminar_mcpe_duplicados INTO @NOREFERENCIA_DUP, @NROCOMPROBANTE_DUP_MCPE
               
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DECLARE @REGISTROS_MCHE_ELIMINADOS_MCPE INT = 0
                  
                  SELECT @REGISTROS_MCHE_ELIMINADOS_MCPE = COUNT(*)
                  FROM MCHE
                  WHERE NROCOMPROBANTE = @NROCOMPROBANTE_DUP_MCPE
                  
                  DELETE FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE_DUP_MCPE
                  
                  IF @REGISTROS_MCHE_ELIMINADOS_MCPE > 0
                  BEGIN
                     PRINT ' Limpieza MCHE: Se eliminaron ' + CAST(@REGISTROS_MCHE_ELIMINADOS_MCPE AS VARCHAR) + ' registro(s) MCHE del comprobante duplicado ' + @NROCOMPROBANTE_DUP_MCPE + ' (NOREFERENCIA=' + @NOREFERENCIA_DUP + ')'
                  END
                  
                  DELETE FROM MCPE
                  WHERE NROCOMPROBANTE = @NROCOMPROBANTE_DUP_MCPE
                    AND COMPANIA = @COMPANIA
                  
                  PRINT ' Limpieza MCPE: Se eliminó comprobante duplicado ' + @NROCOMPROBANTE_DUP_MCPE + ' (NOREFERENCIA=' + @NOREFERENCIA_DUP + ')'
                  
                  FETCH NEXT FROM cur_eliminar_mcpe_duplicados INTO @NOREFERENCIA_DUP, @NROCOMPROBANTE_DUP_MCPE
               END
               
               CLOSE cur_eliminar_mcpe_duplicados
               DEALLOCATE cur_eliminar_mcpe_duplicados
               
               IF @@ROWCOUNT = 0
                  BREAK
            END
            
            IF @DUPLICADOS_MCPE_FINAL = 0 OR @ITERACION_MCPE_FINAL >= @MAX_ITERACIONES_MCPE_FINAL
            BEGIN
               IF @DUPLICADOS_MCPE_FINAL = 0
               BEGIN
                  PRINT ' ========== VALIDACIÓN FINAL MCPE: OK - No quedan comprobantes duplicados por NOREFERENCIA =========='
               END
               ELSE
               BEGIN
                  PRINT ' ========== ADVERTENCIA: Aún quedan comprobantes duplicados en MCPE después de ' + CAST(@MAX_ITERACIONES_MCPE_FINAL AS VARCHAR) + ' iteraciones =========='
               END
            END
            
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) VALUES('Error general: ' + ERROR_MESSAGE())
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' OK, ERROR MENSAJE FROM @TBLERRORES
            RETURN
        END

        SET @MENSAJE_FINAL = 'Proceso completado. ' + CAST(@RECONSTRUIDOS AS VARCHAR) + ' comprobante(s) reconstruido(s).'
        IF @ERRORES_REC > 0
            SET @MENSAJE_FINAL = @MENSAJE_FINAL + ' ' + CAST(@ERRORES_REC AS VARCHAR) + ' errores.'

        SELECT 'OK' OK, @MENSAJE_FINAL MENSAJE
        RETURN
    END
    IF @METODO='REVISAR_MCPE'     
    BEGIN         
       SELECT @NROCOMPROBANTE=NROCOMPROBANTE       
       FROM   OPENJSON (@PARAMETROS)
       WITH (           
       NROCOMPROBANTE  VARCHAR(20)   '$.NROCOMPROBANTE'
       )
       IF EXISTS(SELECT * FROM MCPE WHERE NROCOMPROBANTE=@NROCOMPROBANTE)    
       BEGIN
          DECLARE @IDSEDE VARCHAR(6)
          SELECT @IDSEDE=COALESCE(UBEQ.IDSEDE,USUSU.IDSEDE),@COMPANIA=COALESCE(UBEQ.COMPANIA,USUSU.COMPANIA),  
          @SYS_COMPUTERNAME=COALESCE(USUSU.SYS_ComputerName,HOST_NAME())   
          FROM USUSU LEFT JOIN UBEQ ON USUSU.SYS_ComputerName=UBEQ.SYS_ComputerName
           WHERE USUSU.USUARIO=@USUARIO
           BEGIN TRY           
            EXEC SPK_NC_REVISAMCPE @NROCOMPROBANTE,@COMPANIA,@USUARIO,@IDSEDE,@SYS_COMPUTERNAME
                               
           END TRY
           BEGIN CATCH
                   INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
           END CATCH
       END
       ELSE
       BEGIN
         INSERT INTO @TBLERRORES(ERROR)
         SELECT 'No se encontro el comprobante en errados, verifique e intente de nuevo '
       END
       IF(SELECT COUNT(*) FROM @TBLERRORES)>0
       BEGIN
          SELECT 'KO' OK, ERROR FROM @TBLERRORES
           RETURN
       END
       SELECT 'OK' OK 
       RETURN 
    END

    IF @METODO = 'DIAGNOSTICAR_ERRORES'
    BEGIN
        DECLARE @DIAG_NRO VARCHAR(20)
        DECLARE @DIAG_PROCEDENCIA VARCHAR(20)
        DECLARE @DIAG_ANO VARCHAR(4)
        DECLARE @DIAG_MES INT
        DECLARE @DIAG_TOP INT

        SELECT
            @DIAG_NRO = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE'))), ''),
            @DIAG_PROCEDENCIA = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.PROCEDENCIA'))), ''),
            @DIAG_ANO = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ANO'))), ''),
            @DIAG_MES = TRY_CONVERT(INT, JSON_VALUE(@PARAMETROS, '$.MES')),
            @DIAG_TOP = COALESCE(TRY_CONVERT(INT, JSON_VALUE(@PARAMETROS, '$.TOP')), 500)

        IF OBJECT_ID('DBO.SPK_DIAG_MCPE_ERRORES') IS NULL
        BEGIN
            SELECT 'KO' OK, N'No existe el procedimiento SPK_DIAG_MCPE_ERRORES. Despliégalo primero.' MENSAJE
            RETURN
        END

        BEGIN TRY
            EXEC DBO.SPK_DIAG_MCPE_ERRORES
                @NROCOMPROBANTE = @DIAG_NRO,
                @PROCEDENCIA = @DIAG_PROCEDENCIA,
                @ANO = @DIAG_ANO,
                @MES = @DIAG_MES,
                @TOP = @DIAG_TOP
        END TRY
        BEGIN CATCH
            SELECT 'KO' OK, ERROR_MESSAGE() MENSAJE
        END CATCH
        RETURN
    END
END

