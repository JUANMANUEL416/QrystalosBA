CREATE OR ALTER PROCEDURE DBO.SPQ_MCP_COL
    @JSON  NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT dmy;
    SET LANGUAGE Spanish;

    DECLARE @PARAMETROS         NVARCHAR(MAX),
            @MODELO             VARCHAR(100),
            @METODO             VARCHAR(100),
            @USUARIO            VARCHAR(12),
            @SYS_COMPUTERNAME   VARCHAR(254),
            @SEDE               VARCHAR(5),
            @PROCESO            VARCHAR(20),
            @MCP                NVARCHAR(MAX),
            @COMPANIA           VARCHAR(2),
            @NROCOMPROBANTE     VARCHAR(20),
            @PROCEDENCIA        VARCHAR(20),
            @NOREFERENCIA       VARCHAR(20),
            @ANO                VARCHAR(4),
            @MES                VARCHAR(2),
            @FECHACONTABLE      DATETIME,
            @FECHACONTABLE_STR  VARCHAR(10),
            @TOTALDEBITO        DECIMAL(14,2),
            @TOTALCREDITO       DECIMAL(14,2),
            @REFERENCIA1        VARCHAR(40),
            @REFERENCIA2        VARCHAR(20),
            @REFERENCIA3        VARCHAR(20),
            @FECHA              DATETIME,
            @FECHA_STR          VARCHAR(20),
            @LOTE               VARCHAR(8),
            @OBSERVACION        VARCHAR(512),
            @IDSEDE             VARCHAR(5),
            @ESTADO             VARCHAR(1),
            @ANULADO            SMALLINT,
            @COMPROBANTE        VARCHAR(2),
            @IDTERCERO          VARCHAR(20),
            @BANCO              VARCHAR(20),
            @NOCHEQUE           VARCHAR(20),
            @CODCAJA            VARCHAR(5),
            @CNSFACJ            VARCHAR(21),
            @VALOR_CHEQUE       DECIMAL(14,2),
            @RPT_COMPROBANTE    VARCHAR(20),
            @FECHARADICACION    DATETIME,
            @FECHARADICACION_STR VARCHAR(20),
            @MARCA              SMALLINT,
            @SYS_COMPUTERNAME_MARCA VARCHAR(128),
            @ESTADOIMP          VARCHAR(1),
            @CBTEINTERNO        VARCHAR(20),
            @CLASECONT          VARCHAR(16),
            @ENVNIIF            SMALLINT,
            @NROCOMPROBANTENIIF VARCHAR(20),
            @ANOMES             VARCHAR(22),
            @TREVERSION         SMALLINT,
            @NROCOMPROBANTEREVER VARCHAR(20),
            @ANO_PARAM          INT,
            @MES_PARAM          INT,
            @COMPROBANTES       NVARCHAR(MAX),
            @CONFIRMADOS        INT,
            @ERRORES_COUNT      INT,
            @CUENTAS_NO_DETALLE INT,
            @FECHA_ACTUAL       DATETIME,
            @CNSLOG             VARCHAR(20),
            @CONSECUTIVO_LOG    INT,
            @ERROR_MSG          VARCHAR(500),
            @MENSAJE_FINAL      VARCHAR(1000),
            -- Variables adicionales para SUBIR_DETALLE_COMPROBANTE
            @EXITOSOS_DETALLE   INT,
            @ERRORES_DETALLE_COUNT INT,
            @ITEM_DETALLE       INT,
            @CUENTA_DETALLE     VARCHAR(20),
            @TIPO_DETALLE       VARCHAR(2),
            @TERCERO_DETALLE_NIT VARCHAR(20),
            @TERCERO_DETALLE_ID VARCHAR(20),
            @FACTURA_DETALLE    VARCHAR(20),
            @REF1_DETALLE       VARCHAR(40),
            @CCOSTO_DETALLE     VARCHAR(20),
            @VALOR_DETALLE      DECIMAL(18,2),
            @FECHA_INI_DETALLE  VARCHAR(20),
            @FECHA_FIN_DETALLE  VARCHAR(20),
            @DETALLE_DETALLE    VARCHAR(512),
            @FECHA_INI_DETALLE_DATE DATETIME,
            @FECHA_FIN_DETALLE_DATE DATETIME,
            @LINEA_DETALLE      INT,
            @NITLOGO      VARCHAR(20),
            @RAZONLOGO    VARCHAR (255),
            @DUPLICAR_DETALLES BIT,
            @NROCOMPROBANTE_ORIGEN VARCHAR(20),
            @CANT_DETALLES_COPIADOS INT

    DECLARE @COMP AS TABLE(ITEM INT IDENTITY(1,1), NROCOMPROBANTE VARCHAR(100))
    DECLARE @TBLERRORES TABLE(ERROR VARCHAR(MAX))

    BEGIN TRY
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'KO' AS OK, 'JSON invalido' AS ERROR;
            RETURN;
        END

        PRINT 'INGRESE A SPQ_MCP_COL'

        SELECT 
            @MODELO     = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO     = LTRIM(RTRIM(JSON_VALUE(@JSON, '$.METODO'))),
            @USUARIO    = JSON_VALUE(@JSON, '$.USUARIO'),
            @PARAMETROS = JSON_QUERY(@JSON, '$.PARAMETROS');

        IF @MODELO IS NULL OR @METODO IS NULL OR @USUARIO IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Datos incompletos en la peticion' AS ERROR;
            RETURN;
        END

        -- Normalizar METODO a mayusculas
        SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))));

        PRINT 'USUARIO:' + @USUARIO
        PRINT 'METODO:' + @METODO

        SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME FROM USUSU WHERE USUARIO = @USUARIO
        SELECT @SEDE = IDSEDE FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME
        IF COALESCE(@SEDE,'') = '' SELECT @SEDE = '01'
        SELECT @COMPANIA = COALESCE(@COMPANIA, '01')
        SELECT @FECHA_ACTUAL = GETDATE()

        PRINT 'SEDE=' + @SEDE

    END TRY
    BEGIN CATCH
        SELECT 'KO' AS OK, 'Error al parsear JSON: ' + ERROR_MESSAGE() AS ERROR;
        RETURN;
    END CATCH

    -- VALORVARIABLES - Handler para el framework usvgs
    IF @METODO = 'VALORVARIABLES'
    BEGIN
        PRINT 'VALORVARIABLES - Procesando variables del framework'
        
        BEGIN TRY
            DECLARE @VARIABLES NVARCHAR(MAX)
            DECLARE @SP_INTERNO VARCHAR(100)
            DECLARE @PARAMETROS_INTERNO NVARCHAR(MAX)
            
            -- Extraer las variables del framework
            SET @VARIABLES = JSON_QUERY(@PARAMETROS, '$.VARIABLES')
            PRINT 'Variables extraidas: ' + SUBSTRING(ISNULL(@VARIABLES, 'NULL'), 1, 200)
            
            -- Extraer el primer SP y sus parametros
            SET @SP_INTERNO = JSON_VALUE(@VARIABLES, '$[0].SP')
            SET @PARAMETROS_INTERNO = JSON_VALUE(@VARIABLES, '$[0].PARAMETROS')
            
            PRINT 'SP interno: ' + ISNULL(@SP_INTERNO, 'NULL')
            PRINT 'Parametros internos (200 chars): ' + SUBSTRING(ISNULL(@PARAMETROS_INTERNO, 'NULL'), 1, 200)
            
            -- Si es nuestro SP, procesar
            IF @SP_INTERNO = 'SPQ_MCP_COL'
            BEGIN
                PRINT 'Es SPQ_MCP_COL - procesando internamente'
                
                -- Verificar que el JSON interno es valido
                IF ISJSON(@PARAMETROS_INTERNO) = 1
                BEGIN
                    -- Extraer metodo interno
                    DECLARE @METODO_INTERNO VARCHAR(100)
                    DECLARE @USUARIO_INTERNO VARCHAR(100)
                    DECLARE @PARAMETROS_METODO NVARCHAR(MAX)
                    
                    SET @METODO_INTERNO = JSON_VALUE(@PARAMETROS_INTERNO, '$.METODO')
                    SET @USUARIO_INTERNO = JSON_VALUE(@PARAMETROS_INTERNO, '$.USUARIO')
                    SET @PARAMETROS_METODO = JSON_QUERY(@PARAMETROS_INTERNO, '$.PARAMETROS')
                    
                    PRINT 'Metodo interno: ' + ISNULL(@METODO_INTERNO, 'NULL')
                    PRINT 'Usuario interno: ' + ISNULL(@USUARIO_INTERNO, 'NULL')
                    
                    IF @METODO_INTERNO = 'RECALCULAR_TOTALES'
                    BEGIN
                        PRINT 'Ejecutando RECALCULAR_TOTALES desde VALORVARIABLES'
                        
                        -- Extraer parametros del comprobante
                        DECLARE @NROCOMPROBANTE_RT VARCHAR(20)
                        DECLARE @COMPANIA_RT VARCHAR(2)
                        DECLARE @TotalDebito_RT DECIMAL(18,2)
                        DECLARE @TotalCredito_RT DECIMAL(18,2)
                        
                        SET @NROCOMPROBANTE_RT = JSON_VALUE(@PARAMETROS_METODO, '$.NROCOMPROBANTE')
                        SET @COMPANIA_RT = COALESCE(JSON_VALUE(@PARAMETROS_METODO, '$.COMPANIA'), '01')
                        
                        PRINT 'Comprobante a recalcular: ' + ISNULL(@NROCOMPROBANTE_RT, 'NULL')
                        PRINT 'Compania: ' + ISNULL(@COMPANIA_RT, 'NULL')
                        
                        -- Validaciones basicas
                        IF @NROCOMPROBANTE_RT IS NULL OR @NROCOMPROBANTE_RT = ''
                        BEGIN
                            SELECT 'KO' AS OK, 'Numero de comprobante requerido' AS MENSAJE
                            RETURN
                        END
                        
                        -- Verificar si el comprobante existe
                        IF NOT EXISTS (SELECT 1 FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RT)
                        BEGIN
                            SELECT 'KO' AS OK, 'Comprobante no encontrado' AS MENSAJE
                            RETURN
                        END
                        
                        -- Ejecutar procedimientos de validacion y calculo
                        BEGIN TRY
                            PRINT 'Ejecutando SPK_REVISAR_COMPROBANTE'
                            EXEC SPK_REVISAR_COMPROBANTE @COMPANIA_RT, @NROCOMPROBANTE_RT
                            
                            PRINT 'Ejecutando SPK_SUMA_DBCR'
                            EXEC SPK_SUMA_DBCR @NROCOMPROBANTE_RT
                            
                            -- Obtener totales recalculados desde MCP despues de SPK_SUMA_DBCR
                            SELECT @TotalDebito_RT = COALESCE(TOTALDEBITO, 0),
                                   @TotalCredito_RT = COALESCE(TOTALCREDITO, 0)
                            FROM MCP
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RT
                            
                            PRINT 'Total Debito: ' + CAST(@TotalDebito_RT AS VARCHAR)
                            PRINT 'Total Credito: ' + CAST(@TotalCredito_RT AS VARCHAR)
                            
                            -- Actualizar MCP con los nuevos totales (NO SOBREESCRIBIR LO QUE HACE SPK_SUMA_DBCR)
                            -- SPK_SUMA_DBCR ya actualiza TOTALDEBITO, TOTALCREDITO y ESTADO correctamente
                            PRINT 'SPK_SUMA_DBCR ha actualizado los totales y el estado automaticamente'
                            
                            -- Obtener informacion final del comprobante
                            DECLARE @ESTADO_FINAL VARCHAR(1)
                            DECLARE @ERRORES_FINAL INT
                            DECLARE @DETALLES_TOTAL INT
                            DECLARE @BALANCEADO_FINAL BIT
                            
                            SELECT @ESTADO_FINAL = COALESCE(ESTADO, '0')
                            FROM MCP 
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RT
                            
                            SELECT @ERRORES_FINAL = COUNT(*)
                            FROM MCH 
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RT 
                            AND COALESCE(ESTADO,'0') = '0'
                            
                            SELECT @DETALLES_TOTAL = COUNT(*)
                            FROM MCH 
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RT
                            
                            SET @BALANCEADO_FINAL = CASE WHEN @TotalDebito_RT = @TotalCredito_RT AND @ERRORES_FINAL = 0 THEN 1 ELSE 0 END
                            
                            -- Devolver respuesta exitosa
                            SELECT 'OK' AS OK, 
                                   'Totales recalculados exitosamente' AS MENSAJE,
                                   @ESTADO_FINAL AS ESTADO,
                                   @TotalDebito_RT AS TOTAL_DEBITO,
                                   @TotalCredito_RT AS TOTAL_CREDITO,
                                   @ERRORES_FINAL AS ERRORES_DETALLE,
                                   @DETALLES_TOTAL AS TOTAL_DETALLES,
                                   @BALANCEADO_FINAL AS BALANCEADO,
                                   @NROCOMPROBANTE_RT AS NROCOMPROBANTE
                            
                            RETURN
                            
                        END TRY
                        BEGIN CATCH
                            PRINT 'Error en RECALCULAR_TOTALES: ' + ERROR_MESSAGE()
                            SELECT 'KO' AS OK, 
                                   'Error al recalcular totales: ' + ERROR_MESSAGE() AS MENSAJE
                            RETURN
                        END CATCH
                    END
                    ELSE
                    BEGIN
                        SELECT 'KO' AS OK, 'Metodo interno no soportado: ' + ISNULL(@METODO_INTERNO, 'NULL') AS MENSAJE
                        RETURN
                    END
                END
                ELSE
                BEGIN
                    PRINT 'ERROR: JSON interno invalido'
                    SELECT 'KO' AS OK, 'JSON interno invalido' AS MENSAJE
                    RETURN
                END
            END
            ELSE
            BEGIN
                SELECT 'KO' AS OK, 'SP no soportado: ' + ISNULL(@SP_INTERNO, 'NULL') AS MENSAJE
                RETURN
            END
            
        END TRY
        BEGIN CATCH
            PRINT 'ERROR en VALORVARIABLES: ' + ERROR_MESSAGE()
            SELECT 'KO' AS OK, 'Error en VALORVARIABLES: ' + ERROR_MESSAGE() AS MENSAJE
            RETURN
        END CATCH
    END

    -- GET_PERIODOS
    IF @METODO = 'GET_PERIODOS'
    BEGIN
        SELECT 'OK' AS OK
        SELECT ANO, MES, ANOMES, NOMPERIODO, FECHA_INI, FECHA_FIN, COALESCE(CERRADO,0) AS CERRADO 
        FROM PRI 
        WHERE COALESCE(CERRADO,0)=0
        RETURN
    END

    -- VALIDAR PERIODO
    IF @METODO = 'VALIDAR_PERIODO'
    BEGIN
        PRINT 'VALIDAR_PERIODO'

        SELECT @ANO_PARAM = JSON_VALUE(@PARAMETROS, '$.ANO')
        SELECT @MES_PARAM = JSON_VALUE(@PARAMETROS, '$.MES')

        PRINT 'ANO_PARAM: ' + CAST(@ANO_PARAM AS VARCHAR)
        PRINT 'MES_PARAM: ' + CAST(@MES_PARAM AS VARCHAR)

        IF @ANO_PARAM IS NULL OR @MES_PARAM IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Parametros ANO y MES son requeridos' AS MENSAJE, 1 AS CERRADO
            RETURN
        END

        DECLARE @TIPO_RESPUESTA VARCHAR(10) = JSON_VALUE(@PARAMETROS, '$.TIPO_RESPUESTA')

        IF NOT EXISTS(SELECT 1 FROM PRI WHERE ANO = @ANO_PARAM AND MES = @MES_PARAM)
        BEGIN
            SELECT 'KO' AS OK, 'El periodo ' + CAST(@ANO_PARAM AS VARCHAR) + '-' + 
                    RIGHT('00' + CAST(@MES_PARAM AS VARCHAR), 2) + ' no existe en tabla PRI' AS MENSAJE, 1 AS CERRADO
            RETURN
        END

        DECLARE @PERIODO_CERRADO BIT = 0
        SELECT @PERIODO_CERRADO = COALESCE(CERRADO, 0) FROM PRI WHERE ANO = @ANO_PARAM AND MES = @MES_PARAM

        PRINT 'PERIODO_CERRADO desde PRI: ' + CAST(@PERIODO_CERRADO AS VARCHAR)

        IF @TIPO_RESPUESTA = 'VALIDACION'
        BEGIN
            IF @PERIODO_CERRADO = 1
            BEGIN
                SELECT 'KO' AS OK, 'El periodo ' + CAST(@ANO_PARAM AS VARCHAR) + '-' + 
                        RIGHT('00' + CAST(@MES_PARAM AS VARCHAR), 2) + 
                        ' esta CERRADO en tabla PRI. No se pueden hacer modificaciones.' AS MENSAJE, 1 AS CERRADO
                RETURN
            END
            SELECT 'OK' AS OK, 'Periodo valido para modificaciones' AS MENSAJE, 0 AS CERRADO
        END
        ELSE
        BEGIN
            SELECT 'OK' AS OK, 
                    CASE WHEN @PERIODO_CERRADO = 1 
                        THEN 'Periodo CERRADO segun tabla PRI' 
                        ELSE 'Periodo ABIERTO segun tabla PRI' 
                    END AS MENSAJE,
                    @PERIODO_CERRADO AS CERRADO
        END

        RETURN
    END

    -- CONFIRMAR MASIVO
    IF @METODO = 'CONFIRMAR_MASIVO'
    BEGIN
        PRINT 'CONFIRMAR_MASIVO'
        BEGIN TRY

            INSERT INTO @COMP (NROCOMPROBANTE)
            SELECT VALUE FROM OPENJSON(@PARAMETROS, '$.COMPROBANTES')

            -- Validaciones optimizadas
            BEGIN
                -- Validar que todos los comprobantes existen
                DECLARE @COMPROBANTES_INEXISTENTES INT
                SELECT @COMPROBANTES_INEXISTENTES = COUNT(*)
                FROM @COMP C
                LEFT JOIN MCP M ON M.NROCOMPROBANTE = C.NROCOMPROBANTE
                WHERE M.NROCOMPROBANTE IS NULL
                
                IF @COMPROBANTES_INEXISTENTES > 0
                BEGIN
                    SELECT TOP 1 @NROCOMPROBANTE = C.NROCOMPROBANTE
                    FROM @COMP C
                    LEFT JOIN MCP M ON M.NROCOMPROBANTE = C.NROCOMPROBANTE
                    WHERE M.NROCOMPROBANTE IS NULL
                    
                    SELECT @ERROR_MSG = CONCAT('Comprobante ', @NROCOMPROBANTE, ' no existe')
                    RAISERROR (@ERROR_MSG, 16, 2)
                END
                
                -- Validar periodos cerrados con JOIN
                SELECT TOP 1 @ANO = PRI.ANO, @MES = PRI.MES
                FROM @COMP C 
                INNER JOIN MCP ON MCP.NROCOMPROBANTE = C.NROCOMPROBANTE
                INNER JOIN PRI ON PRI.ANO = MCP.ANO AND PRI.MES = MCP.MES
                WHERE PRI.CERRADO = 1
                
                IF @ANO IS NOT NULL AND @MES IS NOT NULL
                BEGIN
                    SELECT @ERROR_MSG = CONCAT('Periodo Cerrado: ', @ANO, '-', @MES)
                    RAISERROR (@ERROR_MSG, 16, 2)
                END
                
                -- Validar cuentas de detalle con JOIN
                SELECT TOP 1 @NROCOMPROBANTE = MCH.NROCOMPROBANTE
                FROM MCH
                INNER JOIN @COMP C ON C.NROCOMPROBANTE = MCH.NROCOMPROBANTE
                LEFT JOIN CUE ON MCH.CUENTA = CUE.CUENTA AND CUE.TIPO = 'Detalle'
                WHERE CUE.CUENTA IS NULL
                
                IF @NROCOMPROBANTE IS NOT NULL
                BEGIN
                    SELECT @ERROR_MSG = CONCAT('Existen en el comprobante ', @NROCOMPROBANTE, ' Cuentas que no son de Detalle')
                    RAISERROR (@ERROR_MSG, 16, 2)
                END
            END

            SET @CONFIRMADOS = 0
            SET @ERRORES_COUNT = 0

            DECLARE _cursor CURSOR FOR   
                SELECT NROCOMPROBANTE FROM @COMP

            OPEN _cursor  
            FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE

            WHILE @@FETCH_STATUS = 0  
            BEGIN  
                SELECT @IDSEDE  = IDSEDE
                    ,@ANO = MCP.ANO
                    ,@MES = MCP.MES
                    ,@PROCEDENCIA = MCP.PROCEDENCIA
                    ,@NOREFERENCIA = MCP.NOREFERENCIA
                FROM MCP 
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE

                BEGIN TRY
                   EXEC DBO.SPK_NC_CONFIRMAR_CONTAB @NROCOMPROBANTE
                      ,@USUARIO, @COMPANIA, @IDSEDE
                      ,@SYS_COMPUTERNAME, @ANO, @MES
                      ,@PROCEDENCIA, @NOREFERENCIA
                      ,'CONTABILIZAR'

                   SET @CONFIRMADOS = @CONFIRMADOS + 1
                   PRINT 'Se ha contabilizado el comprobante ' + COALESCE(@NROCOMPROBANTE, '')

                   EXEC SPK_GENCONSECUTIVO @IDSEDE,'01','@LOG',@CONSECUTIVO_LOG OUTPUT
                   SET @CNSLOG = @IDSEDE + RIGHT('00000000' + CAST(@CONSECUTIVO_LOG AS VARCHAR), 8)

                   INSERT INTO USLOG(CNSLOG, COMPANIA, NOADMISION, PROCESO, REQUEST, REFERENCIA, USUARIO, FECHA, SYS_ComputerName, TABLA)
                   SELECT @CNSLOG, @COMPANIA, @NROCOMPROBANTE, 'CONFIRMAR', 'CERRAR', 'MCP:NROCOMPROBANTE=' + @NROCOMPROBANTE, 
                           @USUARIO, GETDATE(), @SYS_COMPUTERNAME, 'MCP'

                   INSERT INTO USLOGH(CNSLOG, ITEM, CAMPO, VALORANT, VALORNVO)
                   SELECT @CNSLOG, 1, 'MCP:ESTADO', '1', '2'

                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    SET @ERRORES_COUNT = @ERRORES_COUNT + 1
                END CATCH

                FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
            END  

            CLOSE _cursor  
            DEALLOCATE _cursor  

        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES (ERROR)
            SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                + ': ' + ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END

        SELECT 'OK' AS OK, MENSAJE = CONCAT(CAST(@CONFIRMADOS AS VARCHAR), ' comprobante(s) confirmado(s). ', CAST(@ERRORES_COUNT AS VARCHAR), ' errores.')
        RETURN
    END

    -- DESCONFIRMAR MASIVO
    IF @METODO = 'DESCONFIRMAR_MASIVO'
    BEGIN
        PRINT 'DESCONFIRMAR_MASIVO'
        BEGIN TRY

            INSERT INTO @COMP (NROCOMPROBANTE)
            SELECT VALUE FROM OPENJSON(@PARAMETROS, '$.COMPROBANTES')

            -- Validaciones optimizadas
            BEGIN
                -- Validar que todos los comprobantes existen
                DECLARE @COMP_INEXIST_DESC INT
                SELECT @COMP_INEXIST_DESC = COUNT(*)
                FROM @COMP C
                LEFT JOIN MCP M ON M.NROCOMPROBANTE = C.NROCOMPROBANTE
                WHERE M.NROCOMPROBANTE IS NULL
                
                IF @COMP_INEXIST_DESC > 0
                BEGIN
                    SELECT TOP 1 @NROCOMPROBANTE = C.NROCOMPROBANTE
                    FROM @COMP C
                    LEFT JOIN MCP M ON M.NROCOMPROBANTE = C.NROCOMPROBANTE
                    WHERE M.NROCOMPROBANTE IS NULL
                    
                    SELECT @ERROR_MSG = CONCAT('Comprobante ', @NROCOMPROBANTE, ' no existe')
                    RAISERROR (@ERROR_MSG, 16, 2)
                END
                
                -- Validar periodos cerrados
                SELECT TOP 1 @ANO = PRI.ANO, @MES = PRI.MES
                FROM @COMP C 
                INNER JOIN MCP ON MCP.NROCOMPROBANTE = C.NROCOMPROBANTE
                INNER JOIN PRI ON PRI.ANO = MCP.ANO AND PRI.MES = MCP.MES
                WHERE PRI.CERRADO = 1
                
                IF @ANO IS NOT NULL AND @MES IS NOT NULL
                BEGIN
                    SELECT @ERROR_MSG = CONCAT('Periodo Cerrado: ', @ANO, '-', @MES)
                    RAISERROR (@ERROR_MSG, 16, 2)
                END
            END

            SET @CONFIRMADOS = 0
            SET @ERRORES_COUNT = 0

            DECLARE _cursor CURSOR FOR   
                SELECT NROCOMPROBANTE FROM @COMP

            OPEN _cursor  
            FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE

            WHILE @@FETCH_STATUS = 0  
            BEGIN  
                SELECT @IDSEDE  = IDSEDE
                    ,@ANO = MCP.ANO
                    ,@MES = MCP.MES
                    ,@PROCEDENCIA = MCP.PROCEDENCIA
                    ,@NOREFERENCIA = MCP.NOREFERENCIA
                FROM MCP 
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE

                BEGIN TRY
                   EXEC DBO.SPK_NC_CONFIRMAR_CONTAB @NROCOMPROBANTE
                      ,@USUARIO, @COMPANIA, @IDSEDE
                      ,@SYS_COMPUTERNAME, @ANO, @MES
                      ,@PROCEDENCIA, @NOREFERENCIA
                      ,'DESCONTABILIZAR'

                   SET @CONFIRMADOS = @CONFIRMADOS + 1
                   PRINT 'Se ha descontabilizado el comprobante ' + COALESCE(@NROCOMPROBANTE, '')

                   EXEC SPK_GENCONSECUTIVO @IDSEDE,'01','@LOG',@CONSECUTIVO_LOG OUTPUT
                   SET @CNSLOG = @IDSEDE + RIGHT('00000000' + CAST(@CONSECUTIVO_LOG AS VARCHAR), 8)

                   INSERT INTO USLOG(CNSLOG, COMPANIA, NOADMISION, PROCESO, REQUEST, REFERENCIA, USUARIO, FECHA, SYS_ComputerName, TABLA)
                   SELECT @CNSLOG, @COMPANIA, @NROCOMPROBANTE, 'DESCONFIRMAR', 'ABRIR', 'MCP:NROCOMPROBANTE=' + @NROCOMPROBANTE, 
                           @USUARIO, GETDATE(), @SYS_COMPUTERNAME, 'MCP'

                   INSERT INTO USLOGH(CNSLOG, ITEM, CAMPO, VALORANT, VALORNVO)
                   SELECT @CNSLOG, 1, 'MCP:ESTADO', '2', '1'

                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    SET @ERRORES_COUNT = @ERRORES_COUNT + 1
                END CATCH

                FETCH NEXT FROM _cursor INTO @NROCOMPROBANTE
            END  

            CLOSE _cursor  
            DEALLOCATE _cursor  

        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES (ERROR)
            SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                + ': ' + ERROR_MESSAGE()
        END CATCH

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END

        SELECT 'OK' AS OK, MENSAJE = CONCAT(CAST(@CONFIRMADOS AS VARCHAR), ' comprobante(s) desconfirmado(s). ', CAST(@ERRORES_COUNT AS VARCHAR), ' errores.')
        RETURN
    END

    -- ENVIAR A CAMBIOS
    IF @METODO = 'ENVIAR_A_CAMBIOS'
    BEGIN
        PRINT 'ENVIAR_A_CAMBIOS - VERSI?N UNIFICADA'

        DECLARE @ENVIADOS_CAMBIOS INT = 0
        DECLARE @ERRORES_CAMBIOS INT = 0
        DECLARE @CERRADOINV_CAMBIOS INT = 0 
        DECLARE @CERRADOCART_CAMBIOS INT = 0

        -- Insertar comprobantes desde JSON
        INSERT INTO @COMP (NROCOMPROBANTE)
        SELECT VALUE FROM OPENJSON(@PARAMETROS, '$.COMPROBANTES')

        PRINT 'Total comprobantes a procesar: ' + CAST(@@ROWCOUNT AS VARCHAR)

        -- Validar que se insertaron comprobantes
        DECLARE @TOTAL_COMPROBANTES INT
        SELECT @TOTAL_COMPROBANTES = COUNT(*) FROM @COMP
        
        IF @TOTAL_COMPROBANTES = 0
        BEGIN
            SELECT 'KO' AS OK, 'No se recibieron comprobantes para procesar' AS MENSAJE
            RETURN
        END

        -- Cursor para procesar cada comprobante
        DECLARE envio_cursor CURSOR FOR
        SELECT C.NROCOMPROBANTE, MCP.ANO, MCP.MES, MCP.ESTADO, MCP.PROCEDENCIA, MCP.COMPANIA, COALESCE(MCP.ANULADO, 0) AS ANULADO
        FROM @COMP C 
        INNER JOIN MCP ON MCP.NROCOMPROBANTE = C.NROCOMPROBANTE

        DECLARE @NRO_ENVIO VARCHAR(20)
        DECLARE @ANO_ENVIO INT
        DECLARE @MES_ENVIO INT  
        DECLARE @ESTADO_ENVIO VARCHAR(1)
        DECLARE @PROC_ENVIO VARCHAR(20)
        DECLARE @COMP_ENVIO VARCHAR(2)
        DECLARE @ANULADO_ENVIO BIT

        OPEN envio_cursor
        FETCH NEXT FROM envio_cursor INTO @NRO_ENVIO, @ANO_ENVIO, @MES_ENVIO, @ESTADO_ENVIO, @PROC_ENVIO, @COMP_ENVIO, @ANULADO_ENVIO

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @PUEDE_PROCESAR BIT = 1
            DECLARE @MOTIVO_BLOQUEO VARCHAR(200) = ''

            PRINT 'Procesando comprobante: ' + @NRO_ENVIO + ' - Estado: ' + @ESTADO_ENVIO + ' - Procedencia: ' + @PROC_ENVIO

            -- Validacion 1: Comprobante anulado
            IF @ANULADO_ENVIO = 1
            BEGIN
                SET @PUEDE_PROCESAR = 0
                SET @MOTIVO_BLOQUEO = 'Comprobante anulado'
                PRINT 'Comprobante anulado: ' + @NRO_ENVIO
            END
            -- Validacion 2: Periodo cerrado
            ELSE IF EXISTS(SELECT 1 FROM PRI WHERE ANO = @ANO_ENVIO AND MES = @MES_ENVIO AND CERRADO = 1)
            BEGIN
                SET @PUEDE_PROCESAR = 0
                SET @MOTIVO_BLOQUEO = 'Periodo cerrado'
                PRINT 'Periodo cerrado para: ' + @NRO_ENVIO
            END
            -- Validacion 3: Procedencia MANUAL
            ELSE IF @PROC_ENVIO = 'MANUAL'
            BEGIN
                SET @PUEDE_PROCESAR = 0
                SET @MOTIVO_BLOQUEO = 'Procedencia MANUAL no permitida'
                PRINT 'Procedencia MANUAL para: ' + @NRO_ENVIO
            END
            -- Validacion 4: Estado = 2 (Contabilizado)
            ELSE IF @ESTADO_ENVIO = '2'
            BEGIN
                SET @PUEDE_PROCESAR = 0
                SET @MOTIVO_BLOQUEO = 'Comprobante contabilizado'
                PRINT 'Comprobante contabilizado: ' + @NRO_ENVIO
            END
            -- Validacion 5: Validaciones especificas por procedencia
            ELSE IF @PROC_ENVIO = 'INV'
            BEGIN
                DECLARE @CERRADO_INV_ENVIO INT
                SELECT @CERRADO_INV_ENVIO = COALESCE(CERRADO_INV, 0) 
                FROM PRI WHERE ANO = @ANO_ENVIO AND MES = @MES_ENVIO

                IF @CERRADO_INV_ENVIO <> 0
                BEGIN
                    SET @CERRADOINV_CAMBIOS = @CERRADOINV_CAMBIOS + 1
                    SET @PUEDE_PROCESAR = 0
                    SET @MOTIVO_BLOQUEO = 'Inventario cerrado para el periodo'
                    PRINT 'Inventario cerrado para: ' + @NRO_ENVIO
                END
            END
            ELSE IF @PROC_ENVIO IN ('CXC', 'RAD CXC', 'NOTDBCR', 'FACTURA', 'RGLO', 'CONCI', 'NOMINA')
            BEGIN
                DECLARE @CERRADO_CART_ENVIO INT
                SELECT @CERRADO_CART_ENVIO = CASE WHEN COALESCE(CERRADO_CARTERA,0)=1 OR COALESCE(CERRADO_FAC,0)=1 THEN 1 ELSE 0 END
                FROM PRI WHERE ANO = @ANO_ENVIO AND MES = @MES_ENVIO

                IF @CERRADO_CART_ENVIO <> 0
                BEGIN
                    SET @CERRADOCART_CAMBIOS = @CERRADOCART_CAMBIOS + 1
                    SET @PUEDE_PROCESAR = 0
                    SET @MOTIVO_BLOQUEO = 'Cartera/Facturacion cerrada para el periodo'
                    PRINT 'Cartera cerrada para: ' + @NRO_ENVIO
                END
            END

            IF @PUEDE_PROCESAR = 1
            BEGIN
                BEGIN TRY
                    PRINT 'Ejecutando SPK_PASA_A_MCPE para: ' + @NRO_ENVIO

                    EXEC SPK_PASA_A_MCPE @NRO_ENVIO, @USUARIO

                    SET @ENVIADOS_CAMBIOS = @ENVIADOS_CAMBIOS + 1

                    PRINT 'Exito para comprobante: ' + @NRO_ENVIO

                    -- Log de auditoria
                    DECLARE @CNSLOG_ENVIO VARCHAR(20)
                    DECLARE @CONSECUTIVO_ENVIO INT

                    EXEC SPK_GENCONSECUTIVO @SEDE, '01', '@LOG', @CONSECUTIVO_ENVIO OUTPUT
                    SET @CNSLOG_ENVIO = @SEDE + RIGHT('00000000' + CAST(@CONSECUTIVO_ENVIO AS VARCHAR), 8)

                    INSERT INTO USLOG(CNSLOG, COMPANIA, NOADMISION, PROCESO, REQUEST, REFERENCIA, USUARIO, FECHA, SYS_ComputerName, TABLA)
                    VALUES(@CNSLOG_ENVIO, @COMP_ENVIO, @NRO_ENVIO, 'CAMBIOS', 'ENVIAR', 'MCP:NROCOMPROBANTE=' + @NRO_ENVIO, 
                           @USUARIO, GETDATE(), @SYS_COMPUTERNAME, 'MCP')

                    INSERT INTO USLOGH(CNSLOG, ITEM, CAMPO, VALORANT, VALORNVO)
                    VALUES(@CNSLOG_ENVIO, 1, 'PASO A MCPE', 'MCP', 'MCPE')

                END TRY
                BEGIN CATCH
                    SET @ERRORES_CAMBIOS = @ERRORES_CAMBIOS + 1
                    PRINT 'Error en comprobante ' + @NRO_ENVIO + ': ' + ERROR_MESSAGE()

                    INSERT INTO @TBLERRORES(ERROR) 
                    SELECT 'Error en comprobante ' + @NRO_ENVIO + ': ' + ERROR_MESSAGE()
                END CATCH
            END
            ELSE
            BEGIN
                SET @ERRORES_CAMBIOS = @ERRORES_CAMBIOS + 1
                PRINT 'Comprobante ' + @NRO_ENVIO + ' no procesado: ' + @MOTIVO_BLOQUEO

                INSERT INTO @TBLERRORES(ERROR) 
                SELECT 'Comprobante ' + @NRO_ENVIO + ': ' + @MOTIVO_BLOQUEO
            END

            FETCH NEXT FROM envio_cursor INTO @NRO_ENVIO, @ANO_ENVIO, @MES_ENVIO, @ESTADO_ENVIO, @PROC_ENVIO, @COMP_ENVIO, @ANULADO_ENVIO
        END

        CLOSE envio_cursor
        DEALLOCATE envio_cursor

        DECLARE @MSG_ENVIO VARCHAR(500)
        SET @MSG_ENVIO = CAST(@ENVIADOS_CAMBIOS AS VARCHAR) + ' comprobante(s) enviado(s) a cambios exitosamente.'

        IF @ERRORES_CAMBIOS > 0
        BEGIN
            SET @MSG_ENVIO = @MSG_ENVIO + ' ' + CAST(@ERRORES_CAMBIOS AS VARCHAR) + ' comprobante(s) no pudieron ser enviados.'
        END

        IF @CERRADOCART_CAMBIOS > 0 OR @CERRADOINV_CAMBIOS > 0
        BEGIN
            SET @MSG_ENVIO = @MSG_ENVIO + ' Algunos comprobantes no fueron enviados por periodos especificos cerrados.'
        END

        -- Devolver resultado
        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'PARCIAL' AS OK, @MSG_ENVIO AS MENSAJE
            SELECT ERROR FROM @TBLERRORES
        END
        ELSE
        BEGIN
            SELECT 'OK' AS OK, @MSG_ENVIO AS MENSAJE
        END

        RETURN
    END

    -- GENERAR COMPROBANTE CONTABLE (INDIVIDUAL)
    IF @METODO = 'GENERAR_COMPROBANTE_CONTABLE'
    BEGIN
        PRINT 'GENERAR_COMPROBANTE_CONTABLE - INICIO'
        SELECT @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')

        IF @NROCOMPROBANTE IS NULL OR @NROCOMPROBANTE = ''
        BEGIN
            SELECT 'KO' AS OK, 'Numero de comprobante es requerido' AS MENSAJE
            RETURN
        END

        BEGIN TRY
            IF NOT EXISTS(SELECT 1 FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE)
            BEGIN
                SELECT 'KO' AS OK, 'Comprobante no encontrado: ' + @NROCOMPROBANTE AS MENSAJE
                RETURN
            END
            SELECT 'OK' AS OK
            -- Determinar marca de agua
            DECLARE @MARCA_AGUA VARCHAR(20) = ''
            DECLARE @ESTADO_COMP VARCHAR(1)
            DECLARE @ANULADO_COMP BIT
            DECLARE @RPT_COMP_PDF VARCHAR(20) = ''
            DECLARE @TCOM_EGRESO VARCHAR(2) = NULL
            DECLARE @NOM_EGRESO VARCHAR(100) = NULL

            SELECT @ESTADO_COMP = ESTADO,
                   @ANULADO_COMP = COALESCE(ANULADO, 0),
                   @RPT_COMP_PDF = UPPER(TRIM(COALESCE(RPT_COMPROBANTE, '')))
            FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE

            IF @ANULADO_COMP = 1
                SET @MARCA_AGUA = 'ANULADO'
            ELSE IF @ESTADO_COMP = '0'
                SET @MARCA_AGUA = 'INCOMPLETO'
            ELSE IF @ESTADO_COMP = '1'
                SET @MARCA_AGUA = 'PREPARADO'
            ELSE IF @ESTADO_COMP = '2'
                SET @MARCA_AGUA = ''

            -- EGRESO: título del PDF desde COM del tipo configurado en IDCON_TCOM_ECAJ
            IF @RPT_COMP_PDF = 'EGRESO'
            BEGIN
                SET @TCOM_EGRESO = NULLIF(TRIM(DBO.FNK_VALORVARIABLE('IDCON_TCOM_ECAJ')), '')
                IF @TCOM_EGRESO IS NOT NULL
                BEGIN
                    SELECT @NOM_EGRESO = NULLIF(RTRIM(COM.NOMCOMPROBANTE), '')
                    FROM COM
                    WHERE COM.COMPROBANTE = @TCOM_EGRESO
                END
            END

            SELECT @NITLOGO=NIT+' - '+CAST(DV AS VARCHAR(2)),@RAZONLOGO=RAZONSOCIAL FROM TER 
            WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
            SELECT 
                'RESPUESTA' AS TIPO,
                1 AS ORDEN,
                'OK' AS OK,
                'Reporte generado exitosamente' AS MENSAJE,
                @MARCA_AGUA AS MARCA_AGUA,
                CAST(NULL AS VARCHAR(10)) AS COMPROBANTE,
                CAST(NULL AS VARCHAR(100)) AS NOMCOMPROBANTE,
                CAST(NULL AS VARCHAR(20)) AS NROCOMPROBANTE,
                CAST(NULL AS VARCHAR(20)) AS NOREFERENCIA,
                CAST(NULL AS VARCHAR(10)) AS FECHACONTABLE,
                CAST(NULL AS VARCHAR(20)) AS IDTERCERO,
                CAST(NULL AS VARCHAR(20)) AS NIT,
                CAST(NULL AS VARCHAR(200)) AS RAZONSOCIAL,
                CAST(NULL AS VARCHAR(500)) AS OBSERVACION,
                CAST(NULL AS DECIMAL(18,2)) AS TOTALDEBITO,
                CAST(NULL AS DECIMAL(18,2)) AS TOTALCREDITO,
                CAST(NULL AS VARCHAR(1)) AS ESTADO,
                CAST(NULL AS BIT) AS ANULADO,
                CAST(NULL AS VARCHAR(20)) AS USUARIO,
                NULL AS NOMBREUSU,
                CAST(NULL AS VARCHAR(20)) AS PROCEDENCIA,
                CAST(NULL AS VARCHAR(40)) AS REFERENCIA1,
                CAST(NULL AS VARCHAR(20)) AS REFERENCIA2,
                CAST(NULL AS VARCHAR(20)) AS REFERENCIA3,
                CAST(NULL AS INT) AS ANO,
                CAST(NULL AS INT) AS MES,
                CAST(NULL AS VARCHAR(100)) AS NOMBRE_EMPRESA,
                CAST(NULL AS VARCHAR(20)) AS NIT_EMPRESA,
                CAST(NULL AS VARCHAR(20)) AS CUENTA,
                CAST(NULL AS VARCHAR(200)) AS NOMCUENTA,
                CAST(NULL AS VARCHAR(500)) AS DETALLE,
                CAST(NULL AS VARCHAR(20)) AS CCOSTO,
                CAST(NULL AS VARCHAR(200)) AS NOMB_CCOSTO,
                CAST(NULL AS DECIMAL(18,2)) AS DEBITO,
                CAST(NULL AS DECIMAL(18,2)) AS CREDITO,
                CAST(NULL AS VARCHAR(1)) AS TIPO_MOV

            UNION ALL

            -- Datos del encabezado
            SELECT 
                'ENCABEZADO' AS TIPO,
                2 AS ORDEN,
                CAST(NULL AS VARCHAR(10)) AS OK,
                CAST(NULL AS VARCHAR(200)) AS MENSAJE,
                @MARCA_AGUA AS MARCA_AGUA,
                MCP.COMPROBANTE,
                COALESCE(@NOM_EGRESO, COM.NOMCOMPROBANTE) AS NOMCOMPROBANTE,
                MCP.NROCOMPROBANTE,
                MCP.NOREFERENCIA,
                CONVERT(VARCHAR(10), MCP.FECHACONTABLE, 23) AS FECHACONTABLE, -- Format YYYY-MM-DD
                MCP.IDTERCERO,
                TER.NIT,
                TER.RAZONSOCIAL,
                MCP.OBSERVACION,
                MCP.TOTALDEBITO,
                MCP.TOTALCREDITO,
                MCP.ESTADO,
                COALESCE(MCP.ANULADO, 0) AS ANULADO,
                MCP.USUARIO,
                USUSU.NOMBRE AS NOMBREUSU,
                MCP.PROCEDENCIA,
                MCP.REFERENCIA1,
                MCP.REFERENCIA2,
                MCP.REFERENCIA3,
                MCP.ANO,
                MCP.MES,
                @RAZONLOGO AS NOMBRE_EMPRESA,
                @NITLOGO AS NIT_EMPRESA,
                CAST(NULL AS VARCHAR(20)) AS CUENTA,
                CAST(NULL AS VARCHAR(200)) AS NOMCUENTA,
                CAST(NULL AS VARCHAR(500)) AS DETALLE,
                CAST(NULL AS VARCHAR(20)) AS CCOSTO,
                CAST(NULL AS VARCHAR(200)) AS NOMB_CCOSTO,
                CAST(NULL AS DECIMAL(18,2)) AS DEBITO,
                CAST(NULL AS DECIMAL(18,2)) AS CREDITO,
                CAST(NULL AS VARCHAR(1)) AS TIPO_MOV

            FROM MCP 
            LEFT JOIN COM ON MCP.COMPROBANTE = COM.COMPROBANTE
            LEFT JOIN TER ON MCP.IDTERCERO = TER.IDTERCERO
            LEFT JOIN USUSU ON MCP.USUARIO=USUSU.USUARIO
            WHERE MCP.NROCOMPROBANTE = @NROCOMPROBANTE

            UNION ALL

            -- Datos del detalle 
            SELECT 
                'DETALLE' AS TIPO,
                3 AS ORDEN,
                CAST(NULL AS VARCHAR(10)) AS OK,
                CAST(NULL AS VARCHAR(200)) AS MENSAJE,
                CAST(NULL AS VARCHAR(20)) AS MARCA_AGUA,
                CAST(NULL AS VARCHAR(10)) AS COMPROBANTE,
                CAST(NULL AS VARCHAR(100)) AS NOMCOMPROBANTE,
                CAST(NULL AS VARCHAR(20)) AS NROCOMPROBANTE,
                CAST(NULL AS VARCHAR(20)) AS NOREFERENCIA,
                CAST(NULL AS VARCHAR(10)) AS FECHACONTABLE,
                CAST(NULL AS VARCHAR(20)) AS IDTERCERO,
                CAST(NULL AS VARCHAR(20)) AS NIT,
                CAST(NULL AS VARCHAR(200)) AS RAZONSOCIAL,
                CAST(NULL AS VARCHAR(500)) AS OBSERVACION,
                CAST(NULL AS DECIMAL(18,2)) AS TOTALDEBITO,
                CAST(NULL AS DECIMAL(18,2)) AS TOTALCREDITO,
                CAST(NULL AS VARCHAR(1)) AS ESTADO,
                CAST(NULL AS BIT) AS ANULADO,
                CAST(NULL AS VARCHAR(20)) AS USUARIO,
                NULL,
                CAST(NULL AS VARCHAR(20)) AS PROCEDENCIA,
                CAST(NULL AS VARCHAR(40)) AS REFERENCIA1,
                CAST(NULL AS VARCHAR(20)) AS REFERENCIA2,
                CAST(NULL AS VARCHAR(20)) AS REFERENCIA3,
                CAST(NULL AS INT) AS ANO,
                CAST(NULL AS INT) AS MES,
                CAST(NULL AS VARCHAR(100)) AS NOMBRE_EMPRESA,
                CAST(NULL AS VARCHAR(20)) AS NIT_EMPRESA,
                MCH.CUENTA,
                MAX(COALESCE(CUE.NOMCUENTA, 'Sin descripcion')) AS NOMCUENTA,
                MCH.DETALLE,
                MAX(MCH.CCOSTO) AS CCOSTO,
                MAX(CEN.DESCRIPCION) AS NOMB_CCOSTO,
                CASE WHEN MCH.TIPO = 'DB' THEN SUM(COALESCE(MCH.VALOR, 0)) ELSE 0 END AS DEBITO,
                CASE WHEN MCH.TIPO = 'CR' THEN SUM(COALESCE(MCH.VALOR, 0)) ELSE 0 END AS CREDITO,
                MCH.TIPO AS TIPO_MOV

            FROM MCH
            LEFT JOIN CUE ON MCH.CUENTA = CUE.CUENTA
            LEFT JOIN CEN ON MCH.CCOSTO = CEN.CCOSTO
            LEFT JOIN MCP ON MCH.NROCOMPROBANTE = MCP.NROCOMPROBANTE
            WHERE MCH.NROCOMPROBANTE = @NROCOMPROBANTE
            GROUP BY MCH.CUENTA, MCH.DETALLE, MCH.TIPO
            ORDER BY ORDEN, TIPO_MOV DESC, CUENTA

            IF EXISTS(SELECT * FROM MCP WHERE NROCOMPROBANTE=@NROCOMPROBANTE AND RPT_COMPROBANTE='EGRESO')
            BEGIN
               -- Usar MCP (no MCH): el detalle puede tener varias REFERENCIA2 distintas
               -- y al asignar sin ORDER BY queda un CODCAJA incorrecto ? impuestos vacíos.
               SELECT @CODCAJA = REFERENCIA2, @CNSFACJ = REFERENCIA1
               FROM MCP
               WHERE NROCOMPROBANTE = @NROCOMPROBANTE

                 SELECT IMP.IDIMPUESTO, IMP.DESCIMPUESTO, IMP.IDCLASE, IMP.DESCCLASE, FCXPI.VALORIMP AS VLR_IMP,
                        FCXPI.BASE, FCXPI.VALOR AS TOTAL, FCXP.NOREFERENCIA
                 FROM FCXP INNER JOIN
                      FCXPP ON FCXP.CNSFCXP=FCXPP.CNSFCXP INNER JOIN
                      FCXPI ON FCXPP.CNSFCXP=FCXPI.CNSFCXP INNER JOIN
                      (SELECT FIMP.IDIMPUESTO, FIMP.DESCRIPCION AS DESCIMPUESTO, FIMPD.IDCLASE, FIMPD.DESCRIPCION AS DESCCLASE,
                              FIMPDV.ITEM, FIMPDV.VALOR AS VLR_IMP, FIMPDV.CUENTA
                       FROM FIMP INNER JOIN
                            FIMPD ON FIMP.IDIMPUESTO=FIMPD.IDIMPUESTO INNER JOIN
                            FIMPDV ON FIMPD.IDIMPUESTO=FIMPDV.IDIMPUESTO AND FIMPD.IDCLASE=FIMPDV.IDCLASE) AS
                      IMP ON FCXPI.IDIMPUESTO=IMP.IDIMPUESTO AND FCXPI.IDCLASE=IMP.IDCLASE AND FCXPI.ITEM=IMP.ITEM INNER JOIN
                      FCJD ON FCJD.CODCAJA=@CODCAJA AND FCJD.CNSFACJ=@CNSFACJ
                 WHERE CNSFCXPP=FCJD.IDSERVICIO 

                  SELECT  FCXP.NOREFERENCIA,FCXPDBCR.ITEM,FCXPDBCR.IDNOTA,FNT.DESCRIPCION,CASE WHEN FCXPDBCR.TIPO='DB' THEN FCXPDBCR.VALOR  ELSE 0 END DEBITO
                    ,CASE WHEN FCXPDBCR.TIPO='CR' THEN FCXPDBCR.VALOR  ELSE 0 END CREDITO
                    FROM FCXP INNER JOIN FCXPP ON FCXP.CNSFCXP=FCXPP.CNSFCXP 
                              INNER JOIN FCXPDBCR ON FCXP.CNSFCXP=FCXPDBCR.CNSFCXP
                              INNER JOIN FCJD ON FCJD.IDSERVICIO=FCXPP.CNSFCXPP
                              INNER JOIN FNT ON FCXPDBCR.IDNOTA=FNT.IDNOTA
                     WHERE FCJD.CODCAJA=@CODCAJA AND FCJD.CNSFACJ=@CNSFACJ
                     AND   FCXPDBCR.ESTADO<>'A' AND FCXPDBCR.CONTABILIZADA=1
                     ORDER BY  FCXP.NOREFERENCIA,FCXPDBCR.ITEM

            END

        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, 'Error generando reporte: ' + ERROR_MESSAGE() AS MENSAJE
        END CATCH

        RETURN
    END
    -- GENERAR COMPROBANTES MASIVO
    IF @METODO = 'GENERAR_COMPROBANTES_MASIVO_V2'
    BEGIN
        PRINT 'GENERAR_COMPROBANTES_MASIVO_V2 - VERSION FINAL'

        SELECT @COMPROBANTES = JSON_VALUE(@PARAMETROS, '$.COMPROBANTES')

        CREATE TABLE #TEMP_COMPROBANTES (NROCOMPROBANTE VARCHAR(20))
        INSERT INTO #TEMP_COMPROBANTES (NROCOMPROBANTE)
        SELECT VALUE FROM OPENJSON(@COMPROBANTES)

        DECLARE @TCOM_EGRESO_M VARCHAR(2) = NULLIF(TRIM(DBO.FNK_VALORVARIABLE('IDCON_TCOM_ECAJ')), '')

        SELECT 
            'OK' AS STATUS_PROCESO,
            'Datos procesados correctamente' AS MENSAJE_PROCESO,
            ROW_NUMBER() OVER(ORDER BY MCP.NROCOMPROBANTE) AS ORDEN,
            'ENCABEZADO' AS TIPO,
            MCP.NROCOMPROBANTE,
            MCP.COMPROBANTE,
            CASE
                WHEN UPPER(RTRIM(COALESCE(MCP.RPT_COMPROBANTE, ''))) = 'EGRESO'
                     AND NULLIF(RTRIM(COM_EGRESO.NOMCOMPROBANTE), '') IS NOT NULL
                THEN COM_EGRESO.NOMCOMPROBANTE
                ELSE COM.NOMCOMPROBANTE
            END AS NOMCOMPROBANTE,
            MCP.NOREFERENCIA,
            CONVERT(VARCHAR(10), MCP.FECHACONTABLE, 23) AS FECHACONTABLE, -- Format YYYY-MM-DD
            TER.NIT,
            TER.RAZONSOCIAL,
            MCP.OBSERVACION,
            MCP.TOTALDEBITO,
            MCP.TOTALCREDITO,
            MCP.USUARIO,
            MCP.ESTADO,
            COALESCE(MCP.ANULADO, 0) AS ANULADO,
            CAST(NULL AS VARCHAR(20)) AS CUENTA,
            CAST(NULL AS VARCHAR(200)) AS NOMCUENTA,
            CAST(NULL AS VARCHAR(500)) AS DETALLE,
            CAST(NULL AS DECIMAL(18,2)) AS DEBITO,
            CAST(NULL AS DECIMAL(18,2)) AS CREDITO,
            CAST(NULL AS VARCHAR(2)) AS TIPO_MOV

        FROM MCP 
        LEFT JOIN COM ON MCP.COMPROBANTE = COM.COMPROBANTE
        LEFT JOIN COM COM_EGRESO ON COM_EGRESO.COMPROBANTE = @TCOM_EGRESO_M
        LEFT JOIN TER ON MCP.IDTERCERO = TER.IDTERCERO
        WHERE MCP.NROCOMPROBANTE IN (SELECT NROCOMPROBANTE FROM #TEMP_COMPROBANTES)

        UNION ALL

        SELECT 
            'OK' AS STATUS_PROCESO,
            'Datos procesados correctamente' AS MENSAJE_PROCESO,
            ROW_NUMBER() OVER(ORDER BY MCP.NROCOMPROBANTE) AS ORDEN,
            'DETALLE' AS TIPO,
            MCH.NROCOMPROBANTE,
            CAST(NULL AS VARCHAR(10)) AS COMPROBANTE,
            CAST(NULL AS VARCHAR(100)) AS NOMCOMPROBANTE,
            CAST(NULL AS VARCHAR(20)) AS NOREFERENCIA,
            CAST(NULL AS VARCHAR(10)) AS FECHACONTABLE,
            CAST(NULL AS VARCHAR(20)) AS NIT,
            CAST(NULL AS VARCHAR(200)) AS RAZONSOCIAL,
            CAST(NULL AS VARCHAR(500)) AS OBSERVACION,
            CAST(NULL AS DECIMAL(18,2)) AS TOTALDEBITO,
            CAST(NULL AS DECIMAL(18,2)) AS TOTALCREDITO,
            CAST(NULL AS VARCHAR(20)) AS USUARIO,
            CAST(NULL AS VARCHAR(1)) AS ESTADO,
            CAST(NULL AS BIT) AS ANULADO,
            MCH.CUENTA,
            MAX(COALESCE(CUE.NOMCUENTA, 'Sin descripcion')) AS NOMCUENTA,
            MCH.DETALLE,
            CASE WHEN MCH.TIPO = 'DB' THEN SUM(COALESCE(MCH.VALOR, 0)) ELSE 0 END AS DEBITO,
            CASE WHEN MCH.TIPO = 'CR' THEN SUM(COALESCE(MCH.VALOR, 0)) ELSE 0 END AS CREDITO,
            MCH.TIPO AS TIPO_MOV

        FROM MCH
        LEFT JOIN CUE ON MCH.CUENTA = CUE.CUENTA
        INNER JOIN MCP ON MCH.NROCOMPROBANTE = MCP.NROCOMPROBANTE
        WHERE MCH.NROCOMPROBANTE IN (SELECT NROCOMPROBANTE FROM #TEMP_COMPROBANTES)
        GROUP BY MCH.NROCOMPROBANTE, MCH.CUENTA, MCH.DETALLE, MCH.TIPO

        ORDER BY ORDEN, TIPO_MOV DESC, CUENTA

        DROP TABLE #TEMP_COMPROBANTES
        RETURN
    END

    -- CRUDMCP
    IF @METODO = 'CRUDMCP'
    BEGIN
        PRINT 'CRUDMCP'
        SELECT @MCP = JSON_QUERY(@PARAMETROS, '$.REGISTRO')

        SELECT @PROCESO = JSON_VALUE(@MCP, '$.PROCESO')

        SELECT @COMPANIA = JSON_VALUE(@MCP, '$.COMPANIA')
        SELECT @NROCOMPROBANTE = JSON_VALUE(@MCP, '$.NROCOMPROBANTE')
        SELECT @PROCEDENCIA = JSON_VALUE(@MCP, '$.PROCEDENCIA')
        SELECT @NOREFERENCIA = JSON_VALUE(@MCP, '$.NOREFERENCIA')
        -- Manejo mejorado de fechas para evitar dia extra
        SET @FECHA_STR = JSON_VALUE(@MCP, '$.FECHACONTABLE')
        PRINT 'Fecha recibida del frontend: ' + ISNULL(@FECHA_STR, 'NULL')
        
        -- Intentar conversion directa si ya esta en formato ISO YYYY-MM-DD
        SELECT @FECHACONTABLE = TRY_CONVERT(DATE, @FECHA_STR, 120)  -- ISO format YYYY-MM-DD
        IF @FECHACONTABLE IS NULL
            SELECT @FECHACONTABLE = TRY_CONVERT(DATE, @FECHA_STR, 23)  -- ISO format YYYY-MM-DD
        IF @FECHACONTABLE IS NULL
            SELECT @FECHACONTABLE = TRY_CONVERT(DATE, @FECHA_STR, 103)  -- DD/MM/YYYY
        IF @FECHACONTABLE IS NULL
            SELECT @FECHACONTABLE = TRY_CONVERT(DATE, @FECHA_STR, 101)  -- MM/DD/YYYY
            
        PRINT 'Fecha convertida: ' + ISNULL(CONVERT(VARCHAR, @FECHACONTABLE, 23), 'NULL')
        SELECT @ANO = YEAR(@FECHACONTABLE)
        SELECT @MES = MONTH(@FECHACONTABLE)
        SELECT @TOTALDEBITO = JSON_VALUE(@MCP, '$.TOTALDEBITO')
        SELECT @TOTALCREDITO = JSON_VALUE(@MCP, '$.TOTALCREDITO')
        SELECT @REFERENCIA1 = JSON_VALUE(@MCP, '$.REFERENCIA1')
        SELECT @REFERENCIA2 = JSON_VALUE(@MCP, '$.REFERENCIA2')
        SELECT @REFERENCIA3 = JSON_VALUE(@MCP, '$.REFERENCIA3')
        SELECT @FECHA = GETDATE()
        SELECT @LOTE = JSON_VALUE(@MCP, '$.LOTE')
        SELECT @OBSERVACION = JSON_VALUE(@MCP, '$.OBSERVACION')
        SELECT @IDSEDE = JSON_VALUE(@MCP, '$.IDSEDE')
        SELECT @ESTADO = JSON_VALUE(@MCP, '$.ESTADO')
        SELECT @ANULADO = CAST(JSON_VALUE(@MCP, '$.ANULADO') AS BIT)
        SELECT @COMPROBANTE = JSON_VALUE(@MCP, '$.COMPROBANTE')
        SELECT @IDTERCERO = JSON_VALUE(@MCP, '$.IDTERCERO')
        SELECT @BANCO = JSON_VALUE(@MCP, '$.BANCO')
        SELECT @NOCHEQUE = JSON_VALUE(@MCP, '$.NOCHEQUE')
        SELECT @VALOR_CHEQUE = JSON_VALUE(@MCP, '$.VALOR_CHEQUE')
        SELECT @RPT_COMPROBANTE = JSON_VALUE(@MCP, '$.RPT_COMPROBANTE')
        -- Manejo mejorado de fecha de radicacion
        SET @FECHARADICACION_STR = JSON_VALUE(@MCP, '$.FECHARADICACION')
        IF @FECHARADICACION_STR IS NOT NULL AND @FECHARADICACION_STR <> ''
        BEGIN
            SELECT @FECHARADICACION = TRY_CONVERT(DATE, @FECHARADICACION_STR, 120)  -- ISO format
            IF @FECHARADICACION IS NULL
                SELECT @FECHARADICACION = TRY_CONVERT(DATE, @FECHARADICACION_STR, 103)  -- DD/MM/YYYY
            IF @FECHARADICACION IS NULL
                SELECT @FECHARADICACION = TRY_CONVERT(DATE, @FECHARADICACION_STR, 101)  -- MM/DD/YYYY
        END
        SELECT @MARCA = JSON_VALUE(@MCP, '$.MARCA')
        SELECT @SYS_COMPUTERNAME_MARCA = JSON_VALUE(@MCP, '$.SYS_COMPUTERNAME_MARCA')
        SELECT @ESTADOIMP = JSON_VALUE(@MCP, '$.ESTADOIMP')
        SELECT @CBTEINTERNO = JSON_VALUE(@MCP, '$.CBTEINTERNO')
        SELECT @CLASECONT = JSON_VALUE(@MCP, '$.CLASECONT')
        SELECT @ENVNIIF = JSON_VALUE(@MCP, '$.ENVNIIF')
        SELECT @NROCOMPROBANTENIIF = JSON_VALUE(@MCP, '$.NROCOMPROBANTENIIF')
        SELECT @ANOMES = CONCAT(@ANO, RIGHT('00' + CAST(@MES AS VARCHAR), 2))
        SELECT @TREVERSION = JSON_VALUE(@MCP, '$.TREVERSION')
        SELECT @NROCOMPROBANTEREVER = JSON_VALUE(@MCP, '$.NROCOMPROBANTEREVER')
        SELECT @NROCOMPROBANTE_ORIGEN = NULLIF(LTRIM(RTRIM(JSON_VALUE(@MCP, '$.NROCOMPROBANTE_ORIGEN'))), '')
        SELECT @DUPLICAR_DETALLES = CASE
            WHEN @NROCOMPROBANTE_ORIGEN IS NOT NULL
                 AND COALESCE(JSON_VALUE(@MCP, '$.DUPLICAR_DETALLES'), '0') IN ('1', 'true', 'TRUE', 'SI', 'S')
            THEN 1
            ELSE 0
        END

        -- Validar periodo de forma optimizada
        DECLARE @PERIODO_EXISTE BIT = 0
        DECLARE @PERIODO_CERRADO_CRUD BIT = 0
        
        SELECT @PERIODO_EXISTE = 1, @PERIODO_CERRADO_CRUD = COALESCE(CERRADO, 0)
        FROM PRI 
        WHERE ANO = @ANO AND MES = @MES
        
        IF @PERIODO_EXISTE = 0
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) 
            SELECT 'El periodo ' + CAST(@ANO AS VARCHAR) + '-' + 
                   RIGHT('00' + CAST(@MES AS VARCHAR), 2) + ' no existe en tabla PRI'
        END
        ELSE IF @PERIODO_CERRADO_CRUD = 1
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) 
            SELECT 'No se puede guardar: el periodo ' + 
                   CAST(@ANO AS VARCHAR) + '-' + RIGHT('00' + CAST(@MES AS VARCHAR), 2) + 
                   ' esta CERRADO en tabla PRI'
        END

        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END

        -- INSERTAR
        IF UPPER(@PROCESO) = 'INSERTAR'
        BEGIN
            PRINT 'INSERTAR'
            BEGIN TRY
                IF @COMPROBANTE = DBO.FNK_VALORVARIABLE('IDCON_TCOM_ECAJ')
                    SELECT @RPT_COMPROBANTE = 'EGRESO'

                EXEC SPK_GENCONSECUTIVO @COMPANIA,'01','@MCP',@NROCOMPROBANTE OUTPUT
                SELECT @NROCOMPROBANTE = '01' + @NROCOMPROBANTE

                PRINT '@NROCOMPROBANTE >' + COALESCE(@NROCOMPROBANTE,' SIN @NROCOMPROBANTE')

                IF @COMPROBANTE <> DBO.FNK_VALORVARIABLE('IDCON_TCOM_FTR')
                BEGIN
                    DECLARE @PREFIJO VARCHAR(20) = '@COM' + @COMPROBANTE
                    EXEC SPK_GENCONSECUTIVO @COMPANIA,'01',@PREFIJO,@NOREFERENCIA OUTPUT
                    SELECT @NOREFERENCIA = REPLACE(SPACE(8 - LEN(@NOREFERENCIA))+LTRIM(RTRIM(@NOREFERENCIA)),SPACE(1),0)
                    PRINT '@NOREFERENCIA >' + COALESCE(@NOREFERENCIA,' SIN @NOREFERENCIA')
                END

                INSERT INTO MCP(COMPANIA,NROCOMPROBANTE,PROCEDENCIA,NOREFERENCIA,ANO,MES,FECHACONTABLE,
                                    TOTALDEBITO,TOTALCREDITO,REFERENCIA1,REFERENCIA2,REFERENCIA3,USUARIO,FECHA,
                                    LOTE,OBSERVACION,IDSEDE,ESTADO,ANULADO,COMPROBANTE,IDTERCERO,
                                    BANCO,NOCHEQUE,VALOR_CHEQUE,RPT_COMPROBANTE,FECHARADICACION,MARCA,SYS_COMPUTERNAME_MARCA,
                                    ESTADOIMP,CBTEINTERNO,CLASECONT,ENVNIIF,NROCOMPROBANTENIIF,TREVERSION,
                                    NROCOMPROBANTEREVER)
                SELECT COALESCE(@COMPANIA,'01'),@NROCOMPROBANTE,@PROCEDENCIA,@NOREFERENCIA,@ANO,@MES,@FECHACONTABLE,
                                    @TOTALDEBITO,@TOTALCREDITO,@REFERENCIA1,@REFERENCIA2,@REFERENCIA3,@USUARIO,@FECHA,
                                    @LOTE,@OBSERVACION,@SEDE,@ESTADO,@ANULADO,@COMPROBANTE,@IDTERCERO,
                                    @BANCO,@NOCHEQUE,COALESCE(@VALOR_CHEQUE,0),@RPT_COMPROBANTE,@FECHARADICACION,COALESCE(@MARCA,0),@SYS_COMPUTERNAME_MARCA,
                                    @ESTADOIMP,@CBTEINTERNO,@CLASECONT,COALESCE(@ENVNIIF,0),@NROCOMPROBANTENIIF,COALESCE(@TREVERSION,0),
                                    @NROCOMPROBANTEREVER

            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES (ERROR)
                SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                    + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                    + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                    + ': ' + ERROR_MESSAGE()
            END CATCH

            IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
            BEGIN
                SELECT 'KO' AS OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END

            SET @CANT_DETALLES_COPIADOS = 0

            -- Duplicar líneas MCH del comprobante origen (opcional)
            IF @DUPLICAR_DETALLES = 1 AND @NROCOMPROBANTE_ORIGEN IS NOT NULL
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM MCP
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE_ORIGEN
                )
                BEGIN
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Comprobante origen no encontrado: ' + @NROCOMPROBANTE_ORIGEN
                END
                ELSE IF NOT EXISTS (
                    SELECT 1
                    FROM MCH
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE_ORIGEN
                )
                BEGIN
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'El comprobante origen no tiene detalle para copiar'
                END
                ELSE
                BEGIN
                    BEGIN TRY
                        INSERT INTO MCH (
                            COMPANIA, NROCOMPROBANTE, TIPO, CUENTA, VALOR, CLASECONT, CTAREVERSION,
                            IDTERCERO, IDPROVEEDOR, CCOSTO, IDAREA, IDSEDE,
                            REFERENCIA1, REFERENCIA2, REFERENCIA3, REFERENCIA_PRO, ITEMREF,
                            N_FACTURA, F_FACTURAREF, F_VENCE,
                            GENERA, CLASE_GENERA, PROCESO, PROCEDENCIA, IDOPERACION,
                            VALOR_PORCIMP, BASE_IMP, CODUNG, CODPRG, PREFIJO,
                            ESTADO, ESTADOIMP, ENPRESUPUESTO, DETALLE,
                            USUARIO, FECHA
                        )
                        SELECT
                            COALESCE(@COMPANIA, MCH.COMPANIA),
                            @NROCOMPROBANTE,
                            MCH.TIPO,
                            MCH.CUENTA,
                            MCH.VALOR,
                            MCH.CLASECONT,
                            MCH.CTAREVERSION,
                            MCH.IDTERCERO,
                            MCH.IDPROVEEDOR,
                            MCH.CCOSTO,
                            MCH.IDAREA,
                            MCH.IDSEDE,
                            MCH.REFERENCIA1,
                            MCH.REFERENCIA2,
                            MCH.REFERENCIA3,
                            MCH.REFERENCIA_PRO,
                            MCH.ITEMREF,
                            MCH.N_FACTURA,
                            MCH.F_FACTURAREF,
                            MCH.F_VENCE,
                            MCH.GENERA,
                            MCH.CLASE_GENERA,
                            'MANUAL',
                            'MANUAL',
                            MCH.IDOPERACION,
                            MCH.VALOR_PORCIMP,
                            MCH.BASE_IMP,
                            MCH.CODUNG,
                            MCH.CODPRG,
                            MCH.PREFIJO,
                            MCH.ESTADO,
                            MCH.ESTADOIMP,
                            MCH.ENPRESUPUESTO,
                            MCH.DETALLE,
                            @USUARIO,
                            GETDATE()
                        FROM MCH
                        WHERE MCH.NROCOMPROBANTE = @NROCOMPROBANTE_ORIGEN
                        ORDER BY MCH.NROASIENTO

                        SET @CANT_DETALLES_COPIADOS = @@ROWCOUNT

                        IF @CANT_DETALLES_COPIADOS > 0
                        BEGIN
                            EXEC SPK_REVISAR_COMPROBANTE @COMPANIA, @NROCOMPROBANTE
                            EXEC SPK_SUMA_DBCR @NROCOMPROBANTE
                        END
                    END TRY
                    BEGIN CATCH
                        INSERT INTO @TBLERRORES (ERROR)
                        SELECT 'Error al copiar detalle: ' + ERROR_MESSAGE()
                    END CATCH
                END
            END

            IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
            BEGIN
                SELECT 'KO' AS OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END

            SELECT
                'OK' AS OK,
                @NROCOMPROBANTE AS CNS,
                CASE WHEN @CANT_DETALLES_COPIADOS > 0 THEN 1 ELSE 0 END AS DETALLES_COPIADOS,
                @CANT_DETALLES_COPIADOS AS CANTIDAD_DETALLES_COPIADOS
            RETURN
        END

        -- EDITAR
        IF UPPER(@PROCESO) = 'EDITAR'
        BEGIN
            BEGIN TRY
                UPDATE MCP SET
                        COMPROBANTE = @COMPROBANTE,
                        PROCEDENCIA = @PROCEDENCIA,
                        NOREFERENCIA = @NOREFERENCIA,
                        ANO = @ANO,
                        MES = @MES,
                        FECHACONTABLE = @FECHACONTABLE,
                        TOTALDEBITO = @TOTALDEBITO,
                        TOTALCREDITO = @TOTALCREDITO,
                        REFERENCIA1 = @REFERENCIA1,
                        REFERENCIA2 = @REFERENCIA2,
                        REFERENCIA3 = @REFERENCIA3,
                        OBSERVACION = @OBSERVACION,
                        IDTERCERO = @IDTERCERO,
                        NOCHEQUE = @NOCHEQUE,
                        VALOR_CHEQUE = @VALOR_CHEQUE,
                        FECHARADICACION = @FECHARADICACION,
                        ANULADO = @ANULADO
                WHERE COMPANIA = @COMPANIA AND NROCOMPROBANTE = @NROCOMPROBANTE

                IF @@ROWCOUNT = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) SELECT 'No se encontro el registro para actualizar: ' + @NROCOMPROBANTE
                END
                ELSE
                BEGIN
                    PRINT 'Registro actualizado correctamente: ' + @NROCOMPROBANTE
                END
            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES (ERROR)
                SELECT 'Error UPDATE: Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                    + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                    + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                    + ': ' + ERROR_MESSAGE()
            END CATCH

            IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
            BEGIN
                SELECT 'KO' AS OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END

            SELECT 'OK' AS OK, 'Registro actualizado correctamente' AS MENSAJE
            RETURN
        END

        RETURN
    END  

    -- SUBIR DETALLE COMPROBANTE
    IF @METODO = 'SUBIR_DETALLE_COMPROBANTE'
    BEGIN
        PRINT 'SUBIR_DETALLE_COMPROBANTE - INICIO'

        DECLARE @REGISTROS NVARCHAR(MAX)
        DECLARE @EXITOSOS INT = 0
        DECLARE @ERRORES_DETALLE INT = 0
        DECLARE @ITEM_ACTUAL INT
        DECLARE @CUENTA_ACTUAL VARCHAR(20)
        DECLARE @TIPO_ACTUAL VARCHAR(2)
        DECLARE @TERCERO_NIT VARCHAR(20)
        DECLARE @TERCERO_ID VARCHAR(20)
        DECLARE @FACTURA_ACTUAL VARCHAR(20)
        DECLARE @REF1_ACTUAL VARCHAR(40)
        DECLARE @CCOSTO_ACTUAL VARCHAR(20)
        DECLARE @VALOR_ACTUAL DECIMAL(18,2)
        DECLARE @FECHA_INI_ACTUAL VARCHAR(20)
        DECLARE @FECHA_FIN_ACTUAL VARCHAR(20)
        DECLARE @DETALLE_ACTUAL VARCHAR(512)
        DECLARE @FECHA_INI_DATE DATETIME
        DECLARE @FECHA_FIN_DATE DATETIME
        DECLARE @LINEA_ACTUAL INT

        -- Tabla temporal para errores de detalle
        DECLARE @ERRORES_TEMP TABLE(
            LINEA INT,
            CUENTA VARCHAR(20),
            TIPO VARCHAR(2),
            TERCERO VARCHAR(20),
            FACTURA VARCHAR(20),
            REFERENCIA1 VARCHAR(40),
            CCOSTO VARCHAR(20),
            VALOR DECIMAL(18,2),
            ERROR VARCHAR(500)
        )

        BEGIN TRY
            -- REGISTROS: JSON_QUERY del array (JSON_VALUE si viene como escalar)
            SELECT @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')
            SELECT @COMPANIA = JSON_VALUE(@PARAMETROS, '$.COMPANIA')
            SET @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTROS')
            IF @REGISTROS IS NULL
                SET @REGISTROS = JSON_VALUE(@PARAMETROS, '$.REGISTROS')


            PRINT 'NROCOMPROBANTE: ' + ISNULL(@NROCOMPROBANTE, 'NULL')
            PRINT 'COMPANIA: ' + ISNULL(@COMPANIA, 'NULL')
            PRINT 'REGISTROS (primeros 200 chars): ' + SUBSTRING(ISNULL(@REGISTROS, 'NULL'), 1, 200)

            -- Validaciones optimizadas
            DECLARE @COMPROBANTE_EXISTE BIT = 0
            DECLARE @COMPROBANTE_CONFIRMADO BIT = 0
            DECLARE @PERIODO_CERRADO_DETALLE BIT = 0
            
            -- Una sola consulta para todas las validaciones del comprobante
            SELECT @COMPROBANTE_EXISTE = 1,
                   @COMPROBANTE_CONFIRMADO = CASE WHEN MCP.ESTADO = '2' THEN 1 ELSE 0 END,
                   @PERIODO_CERRADO_DETALLE = COALESCE(PRI.CERRADO, 0),
                   @ANO = MCP.ANO,
                   @MES = MCP.MES
            FROM MCP
            LEFT JOIN PRI ON PRI.ANO = MCP.ANO AND PRI.MES = MCP.MES
            WHERE MCP.NROCOMPROBANTE = @NROCOMPROBANTE AND MCP.PROCEDENCIA = 'MANUAL'
            
            IF @COMPROBANTE_EXISTE = 0
            BEGIN
                SELECT 'KO' AS OK, 'El comprobante no existe o no es de procedencia MANUAL' AS MENSAJE
                RETURN
            END
            
            IF @COMPROBANTE_CONFIRMADO = 1
            BEGIN
                SELECT 'KO' AS OK, 'No se puede subir detalle a un comprobante confirmado' AS MENSAJE
                RETURN
            END
            
            IF @PERIODO_CERRADO_DETALLE = 1
            BEGIN
                SELECT 'KO' AS OK, 'No se puede subir detalle: el periodo esta cerrado' AS MENSAJE
                RETURN
            END

            -- Validar que REGISTROS no esta vacio
            IF @REGISTROS IS NULL OR @REGISTROS = '' OR @REGISTROS = '[]'
            BEGIN
                SELECT 'KO' AS OK, 'No se recibieron registros para procesar' AS MENSAJE
                RETURN
            END

            -- Crear tabla temporal para los registros
            CREATE TABLE #REGISTROS_DETALLE (
                ITEM INT IDENTITY(1,1),
                LINEA INT,
                CUENTA VARCHAR(20),
                TIPO VARCHAR(2),
                TERCERO VARCHAR(20),
                FACTURA VARCHAR(20),
                REFERENCIA1 VARCHAR(40),
                CCOSTO VARCHAR(20),
                VALOR DECIMAL(18,2),
                FECHA_INI VARCHAR(20),
                FECHA_FIN VARCHAR(20),
                DETALLE VARCHAR(512)
            )

            -- Parsear el JSON de registros
            INSERT INTO #REGISTROS_DETALLE (LINEA, CUENTA, TIPO, TERCERO, FACTURA, REFERENCIA1, CCOSTO, VALOR, FECHA_INI, FECHA_FIN, DETALLE)
            SELECT
                TRY_CAST(COALESCE(JSON_VALUE(value, '$.LINEA'), JSON_VALUE(value, '$.linea')) AS INT),
                COALESCE(JSON_VALUE(value, '$.CUENTA'), JSON_VALUE(value, '$.cuenta')),
                UPPER(LTRIM(RTRIM(COALESCE(JSON_VALUE(value, '$.TIPO'), JSON_VALUE(value, '$.tipo'), '')))),
                COALESCE(JSON_VALUE(value, '$.TERCERO'), JSON_VALUE(value, '$.tercero')),
                COALESCE(JSON_VALUE(value, '$.N_FACTURA'), JSON_VALUE(value, '$.factura')),
                COALESCE(JSON_VALUE(value, '$.REFERENCIA1'), JSON_VALUE(value, '$.referencia1')),
                COALESCE(JSON_VALUE(value, '$.CCOSTO'), JSON_VALUE(value, '$.ccosto')),
                TRY_CAST(COALESCE(JSON_VALUE(value, '$.VALOR'), JSON_VALUE(value, '$.valor')) AS DECIMAL(18,2)),
                COALESCE(JSON_VALUE(value, '$.FECHA_INI'), JSON_VALUE(value, '$.fechaIni')),
                COALESCE(JSON_VALUE(value, '$.FECHA_FIN'), JSON_VALUE(value, '$.fechaFin')),
                COALESCE(JSON_VALUE(value, '$.DETALLE'), JSON_VALUE(value, '$.detalle'))
            FROM OPENJSON(@REGISTROS)


            PRINT 'Registros insertados en tabla temporal: ' + CAST(@@ROWCOUNT AS VARCHAR)

            -- Validar que se insertaron registros
            IF NOT EXISTS(SELECT 1 FROM #REGISTROS_DETALLE)
            BEGIN
                DROP TABLE #REGISTROS_DETALLE
                SELECT 'KO' AS OK, 'No se pudieron parsear los registros del JSON. Verifique el formato.' AS MENSAJE
                RETURN
            END

            -- Procesar cada registro
            DECLARE detalle_cursor CURSOR FOR
            SELECT ITEM, LINEA, CUENTA, TIPO, TERCERO, FACTURA, REFERENCIA1, CCOSTO, VALOR, FECHA_INI, FECHA_FIN, DETALLE
            FROM #REGISTROS_DETALLE
            ORDER BY ITEM

            OPEN detalle_cursor
            FETCH NEXT FROM detalle_cursor INTO @ITEM_ACTUAL, @LINEA_ACTUAL, @CUENTA_ACTUAL, @TIPO_ACTUAL, @TERCERO_NIT, @FACTURA_ACTUAL, @REF1_ACTUAL, @CCOSTO_ACTUAL, @VALOR_ACTUAL, @FECHA_INI_ACTUAL, @FECHA_FIN_ACTUAL, @DETALLE_ACTUAL

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @TIENE_ERROR BIT = 0
                DECLARE @ERROR_ACTUAL VARCHAR(500) = ''

                PRINT 'Procesando registro l?nea: ' + CAST(ISNULL(@LINEA_ACTUAL, 0) AS VARCHAR) + ' - Cuenta: ' + ISNULL(@CUENTA_ACTUAL, 'NULL')

                -- Validaciones optimizadas con JOINs
                DECLARE @CUENTA_VALIDA BIT = 0
                DECLARE @TERCERO_VALIDO BIT = 0
                DECLARE @CCOSTO_VALIDO BIT = 1  -- Asumimos valido si no se especifica
                
                -- Validar cuenta en una sola consulta
                SELECT @CUENTA_VALIDA = CASE WHEN CUE.CUENTA IS NOT NULL AND CUE.TIPO = 'Detalle' THEN 1 ELSE 0 END
                FROM CUE
                WHERE CUE.CUENTA = @CUENTA_ACTUAL
                
                IF @CUENTA_ACTUAL IS NULL OR @CUENTA_ACTUAL = ''
                BEGIN
                    SET @TIENE_ERROR = 1
                    SET @ERROR_ACTUAL = 'La cuenta es requerida'
                END
                ELSE IF @CUENTA_VALIDA = 0
                BEGIN
                    SET @TIENE_ERROR = 1
                    SET @ERROR_ACTUAL = 'La cuenta no existe o no es de tipo detalle'
                END
                
                -- Validar tipo de movimiento
                IF @TIENE_ERROR = 0 AND (@TIPO_ACTUAL IS NULL OR @TIPO_ACTUAL NOT IN ('DB', 'CR'))
                BEGIN
                    SET @TIENE_ERROR = 1
                    SET @ERROR_ACTUAL = 'Debe especificar el tipo de movimiento DB/CR'
                END
                
                -- Validar tercero si se especifica
                SET @TERCERO_ID = NULL
                IF @TIENE_ERROR = 0 AND @TERCERO_NIT IS NOT NULL AND @TERCERO_NIT <> ''
                BEGIN
                    SELECT @TERCERO_ID = IDTERCERO FROM TER WHERE NIT = @TERCERO_NIT
                    IF @TERCERO_ID IS NULL
                    BEGIN
                        SET @TIENE_ERROR = 1
                        SET @ERROR_ACTUAL = 'El tercero con NIT ' + @TERCERO_NIT + ' no existe'
                    END
                END
                
                -- Validar centro de costo si se especifica
                IF @TIENE_ERROR = 0 AND @CCOSTO_ACTUAL IS NOT NULL AND @CCOSTO_ACTUAL <> ''
                BEGIN
                    SELECT @CCOSTO_VALIDO = COUNT(*) FROM CEN WHERE CCOSTO = @CCOSTO_ACTUAL
                    IF @CCOSTO_VALIDO = 0
                    BEGIN
                        SET @TIENE_ERROR = 1
                        SET @ERROR_ACTUAL = 'El centro de costo no existe'
                    END
                END
                
                -- Validar valor
                IF @TIENE_ERROR = 0 AND (@VALOR_ACTUAL IS NULL OR @VALOR_ACTUAL <= 0)
                BEGIN
                    SET @TIENE_ERROR = 1
                    SET @ERROR_ACTUAL = 'El valor debe ser mayor a 0'
                END

                -- Convertir fechas si existen (formato DD/MM/YYYY)
                SET @FECHA_INI_DATE = NULL
                SET @FECHA_FIN_DATE = NULL
                IF @TIENE_ERROR = 0
                BEGIN
                    IF @FECHA_INI_ACTUAL IS NOT NULL AND @FECHA_INI_ACTUAL <> ''
                    BEGIN
                        SET @FECHA_INI_DATE = TRY_CONVERT(DATETIME, @FECHA_INI_ACTUAL, 103)
                        IF @FECHA_INI_DATE IS NULL
                            SET @FECHA_INI_DATE = TRY_CONVERT(DATETIME, @FECHA_INI_ACTUAL, 120)
                        IF @FECHA_INI_DATE IS NULL
                            SET @FECHA_INI_DATE = TRY_CONVERT(DATETIME, @FECHA_INI_ACTUAL, 101)
                    END

                    IF @FECHA_FIN_ACTUAL IS NOT NULL AND @FECHA_FIN_ACTUAL <> ''
                    BEGIN
                        SET @FECHA_FIN_DATE = TRY_CONVERT(DATETIME, @FECHA_FIN_ACTUAL, 103)
                        IF @FECHA_FIN_DATE IS NULL
                            SET @FECHA_FIN_DATE = TRY_CONVERT(DATETIME, @FECHA_FIN_ACTUAL, 120)
                        IF @FECHA_FIN_DATE IS NULL
                            SET @FECHA_FIN_DATE = TRY_CONVERT(DATETIME, @FECHA_FIN_ACTUAL, 101)
                    END
                END

                -- Si hay error, agregarlo a la tabla de errores
                IF @TIENE_ERROR = 1
                BEGIN
                    INSERT INTO @ERRORES_TEMP (LINEA, CUENTA, TIPO, TERCERO, FACTURA, REFERENCIA1, CCOSTO, VALOR, ERROR)
                    VALUES (@LINEA_ACTUAL, @CUENTA_ACTUAL, @TIPO_ACTUAL, @TERCERO_NIT, @FACTURA_ACTUAL, @REF1_ACTUAL, @CCOSTO_ACTUAL, @VALOR_ACTUAL, @ERROR_ACTUAL)

                    SET @ERRORES_DETALLE = @ERRORES_DETALLE + 1
                END
                ELSE
                BEGIN
                    -- Insertar en MCH
                    BEGIN TRY
                        INSERT INTO MCH (
                            NROCOMPROBANTE, CUENTA, TIPO, IDTERCERO, N_FACTURA, REFERENCIA1, 
                            CCOSTO, VALOR, CLASECONT, COMPANIA, F_FACTURAREF, F_VENCE, 
                            DETALLE, GENERA, CLASE_GENERA, USUARIO, FECHA, PROCESO, 
                            PROCEDENCIA, REFERENCIA_PRO
                        )
                        VALUES (
                            @NROCOMPROBANTE, @CUENTA_ACTUAL, @TIPO_ACTUAL, @TERCERO_ID, @FACTURA_ACTUAL, @REF1_ACTUAL,
                            @CCOSTO_ACTUAL, @VALOR_ACTUAL, 'S', @COMPANIA, @FECHA_INI_DATE, @FECHA_FIN_DATE,
                            @DETALLE_ACTUAL, 'Movimiento', 'Otros', @USUARIO, GETDATE(), 'MANUAL',
                            'MANUAL', 'MANUAL'
                        )

                        SET @EXITOSOS = @EXITOSOS + 1
                        PRINT 'Insertado MCH exitosamente para linea: ' + CAST(ISNULL(@LINEA_ACTUAL, 0) AS VARCHAR)

                    END TRY
                    BEGIN CATCH
                        INSERT INTO @ERRORES_TEMP (LINEA, CUENTA, TIPO, TERCERO, FACTURA, REFERENCIA1, CCOSTO, VALOR, ERROR)
                        VALUES (@LINEA_ACTUAL, @CUENTA_ACTUAL, @TIPO_ACTUAL, @TERCERO_NIT, @FACTURA_ACTUAL, @REF1_ACTUAL, @CCOSTO_ACTUAL, @VALOR_ACTUAL, 'Error insertando: ' + ERROR_MESSAGE())

                        SET @ERRORES_DETALLE = @ERRORES_DETALLE + 1
                    END CATCH
                END

                FETCH NEXT FROM detalle_cursor INTO @ITEM_ACTUAL, @LINEA_ACTUAL, @CUENTA_ACTUAL, @TIPO_ACTUAL, @TERCERO_NIT, @FACTURA_ACTUAL, @REF1_ACTUAL, @CCOSTO_ACTUAL, @VALOR_ACTUAL, @FECHA_INI_ACTUAL, @FECHA_FIN_ACTUAL, @DETALLE_ACTUAL
            END

            CLOSE detalle_cursor
            DEALLOCATE detalle_cursor

            -- Ejecutar procedimientos de validacion y suma
            IF @EXITOSOS > 0
            BEGIN
                PRINT 'Ejecutando SPK_REVISAR_COMPROBANTE para: ' + @NROCOMPROBANTE

                BEGIN TRY
                    EXEC SPK_REVISAR_COMPROBANTE @COMPANIA, @NROCOMPROBANTE
                    PRINT 'SPK_REVISAR_COMPROBANTE ejecutado exitosamente'
                END TRY
                BEGIN CATCH
                    PRINT 'Error en SPK_REVISAR_COMPROBANTE: ' + ERROR_MESSAGE()
                END CATCH

                BEGIN TRY
                    EXEC SPK_SUMA_DBCR @NROCOMPROBANTE
                    PRINT 'SPK_SUMA_DBCR ejecutado exitosamente'
                END TRY
                BEGIN CATCH
                    PRINT 'Error en SPK_SUMA_DBCR: ' + ERROR_MESSAGE()
                END CATCH
                
                -- ACTUALIZAR TOTALES EN MCP AUTOMATICAMENTE
                DECLARE @NuevoTotalDebito DECIMAL(18,2)
                DECLARE @NuevoTotalCredito DECIMAL(18,2)
                
                SELECT @NuevoTotalDebito = ISNULL(SUM(CASE WHEN TIPO='DB' THEN VALOR ELSE 0 END), 0),
                       @NuevoTotalCredito = ISNULL(SUM(CASE WHEN TIPO='CR' THEN VALOR ELSE 0 END), 0)
                FROM MCH 
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                
                -- SPK_SUMA_DBCR ya actualiza TOTALDEBITO, TOTALCREDITO y ESTADO automaticamente
                -- No necesitamos actualizar manualmente para evitar conflictos
                PRINT 'SPK_SUMA_DBCR ha actualizado los totales automaticamente - DB: ' + CAST(@NuevoTotalDebito AS VARCHAR) + ', CR: ' + CAST(@NuevoTotalCredito AS VARCHAR)
            END

            DROP TABLE #REGISTROS_DETALLE

            -- Devolver resultado
            IF @ERRORES_DETALLE > 0
            BEGIN
                -- Si hay errores, devolverlos
                SELECT 'ERRORES' AS RESULTADO, 
                       CAST(@EXITOSOS AS VARCHAR) + ' registros procesados exitosamente. ' + 
                       CAST(@ERRORES_DETALLE AS VARCHAR) + ' registros con errores.' AS MENSAJE

                -- Devolver los errores encontrados en un segundo recordset
                SELECT LINEA, CUENTA, TIPO, TERCERO, FACTURA, REFERENCIA1, CCOSTO, VALOR, ERROR
                FROM @ERRORES_TEMP
                ORDER BY LINEA
            END
            ELSE
            BEGIN
                SELECT 'OK' AS OK,
                       'Detalle procesado exitosamente. ' + CAST(@EXITOSOS AS VARCHAR) + ' registro(s) insertado(s).' AS MENSAJE
            END

        END TRY
        BEGIN CATCH
            PRINT 'Error general en SUBIR_DETALLE_COMPROBANTE: ' + ERROR_MESSAGE()

            -- Limpiar tabla temporal si existe
            IF OBJECT_ID('tempdb..#REGISTROS_DETALLE') IS NOT NULL
                DROP TABLE #REGISTROS_DETALLE

            SELECT 'KO' AS OK, 'Error procesando detalle: ' + ERROR_MESSAGE() AS MENSAJE
        END CATCH

        RETURN
    END

    -- RECALCULAR TOTALES (metodo directo)
    IF @METODO = 'RECALCULAR_TOTALES'
    BEGIN
        PRINT 'RECALCULAR_TOTALES - INICIO DIRECTO'
        
        BEGIN TRY
            DECLARE @NROCOMPROBANTE_RECALC VARCHAR(20)
            DECLARE @COMPANIA_RECALC VARCHAR(2)
            
            SELECT @NROCOMPROBANTE_RECALC = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')
            SELECT @COMPANIA_RECALC = COALESCE(JSON_VALUE(@PARAMETROS, '$.COMPANIA'), '01')
            
            PRINT 'Comprobante a recalcular: ' + ISNULL(@NROCOMPROBANTE_RECALC, 'NULL')
            PRINT 'Compania: ' + ISNULL(@COMPANIA_RECALC, 'NULL')
            
            -- Validaciones optimizadas
            IF @NROCOMPROBANTE_RECALC IS NULL OR @NROCOMPROBANTE_RECALC = ''
            BEGIN
                SELECT 'KO' AS OK, 'Numero de comprobante requerido' AS MENSAJE
                RETURN
            END
            
            DECLARE @COMPROBANTE_EXISTE_REC BIT = 0
            SELECT @COMPROBANTE_EXISTE_REC = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
            FROM MCP 
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RECALC
            
            IF @COMPROBANTE_EXISTE_REC = 0
            BEGIN
                SELECT 'KO' AS OK, 'Comprobante no encontrado' AS MENSAJE
                RETURN
            END
            
            -- Ejecutar validacion y calculo
            PRINT 'Ejecutando SPK_REVISAR_COMPROBANTE para: ' + @NROCOMPROBANTE_RECALC
            EXEC SPK_REVISAR_COMPROBANTE @COMPANIA_RECALC, @NROCOMPROBANTE_RECALC
            
            PRINT 'Ejecutando SPK_SUMA_DBCR para: ' + @NROCOMPROBANTE_RECALC
            EXEC SPK_SUMA_DBCR @NROCOMPROBANTE_RECALC
            
            -- Obtener informacion final DESPUES de que los SPs hagan su trabajo
            DECLARE @ESTADO_REC VARCHAR(1) = '0'
            DECLARE @TOTAL_DB_REC DECIMAL(18,2) = 0
            DECLARE @TOTAL_CR_REC DECIMAL(18,2) = 0
            DECLARE @ERRORES_REC INT = 0
            DECLARE @DETALLES_REC INT = 0
            DECLARE @BALANCEADO_REC BIT = 0
            
            -- Obtener datos actualizados del comprobante despues de los calculos
            SELECT @ESTADO_REC = COALESCE(ESTADO, '0'),
                   @TOTAL_DB_REC = COALESCE(TOTALDEBITO, 0),
                   @TOTAL_CR_REC = COALESCE(TOTALCREDITO, 0)
            FROM MCP 
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RECALC
            
            -- Contar errores en detalles
            SELECT @ERRORES_REC = COUNT(*)
            FROM MCH 
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RECALC 
            AND COALESCE(ESTADO,'0') = '0'
            
            -- Contar total de detalles
            SELECT @DETALLES_REC = COUNT(*)
            FROM MCH 
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_RECALC
            
            -- Determinar si esta balanceado
            SET @BALANCEADO_REC = CASE 
                WHEN @TOTAL_DB_REC = @TOTAL_CR_REC AND @ERRORES_REC = 0 
                THEN 1 ELSE 0 END
            
            PRINT 'RESULTADOS FINALES DIRECTOS:'
            PRINT '- Estado: ' + @ESTADO_REC
            PRINT '- Total DB: ' + CAST(@TOTAL_DB_REC AS VARCHAR)
            PRINT '- Total CR: ' + CAST(@TOTAL_CR_REC AS VARCHAR) 
            PRINT '- Errores: ' + CAST(@ERRORES_REC AS VARCHAR)
            PRINT '- Detalles: ' + CAST(@DETALLES_REC AS VARCHAR)
            PRINT '- Balanceado: ' + CAST(@BALANCEADO_REC AS VARCHAR)
            
            -- Devolver respuesta exitosa con toda la informacion
            SELECT 'OK' AS OK, 
                   'Totales recalculados exitosamente' AS MENSAJE,
                   @ESTADO_REC AS ESTADO,
                   @TOTAL_DB_REC AS TOTAL_DEBITO,
                   @TOTAL_CR_REC AS TOTAL_CREDITO,
                   @ERRORES_REC AS ERRORES_DETALLE,
                   @DETALLES_REC AS TOTAL_DETALLES,
                   @BALANCEADO_REC AS BALANCEADO,
                   @NROCOMPROBANTE_RECALC AS NROCOMPROBANTE
            
        END TRY
        BEGIN CATCH
            PRINT 'Error en RECALCULAR_TOTALES directo: ' + ERROR_MESSAGE()
            PRINT 'Linea del error: ' + CAST(ERROR_LINE() AS VARCHAR)
            SELECT 'KO' AS OK, 
                   'Error al recalcular totales: ' + ERROR_MESSAGE() AS MENSAJE,
                   ERROR_LINE() AS LINEA_ERROR
        END CATCH
        
        RETURN
    END

    -- CRUDMCH - INTERCEPTOR CON LA RECALCULACION 
    IF @METODO = 'CRUDMCH'
    BEGIN
        PRINT 'CRUDMCH - INTERCEPTANDO OPERACION MCH CON RECALCULACION AUTOMATICA'
        
        BEGIN TRY
            -- Variables para la recalculacion
            DECLARE @NROCOMPROBANTE_AUTO VARCHAR(20)
            DECLARE @COMPANIA_AUTO VARCHAR(2) = '01'
            
            -- Extraer datos del registro para la recalculacion
            DECLARE @REGISTRO_AUTO NVARCHAR(MAX) = JSON_QUERY(@PARAMETROS, '$.REGISTRO')
            SELECT @NROCOMPROBANTE_AUTO = JSON_VALUE(@REGISTRO_AUTO, '$.NROCOMPROBANTE')
            SELECT @COMPANIA_AUTO = COALESCE(JSON_VALUE(@REGISTRO_AUTO, '$.COMPANIA'), '01')
            
            PRINT 'Procesando detalle para comprobante: ' + ISNULL(@NROCOMPROBANTE_AUTO, 'NULL')
            
            -- Ejecutar la operacion MCH original
            EXEC SPQ_MCH_COL @JSON
            
            -- Recalculacion automatica inmediata
            PRINT 'Ejecutando recalculacion automatica...'
            
            BEGIN TRY
                EXEC SPK_REVISAR_COMPROBANTE @COMPANIA_AUTO, @NROCOMPROBANTE_AUTO
                PRINT 'OK: SPK_REVISAR_COMPROBANTE ejecutado'
            END TRY
            BEGIN CATCH
                PRINT 'ERROR en SPK_REVISAR_COMPROBANTE: ' + ERROR_MESSAGE()
            END CATCH
            
            BEGIN TRY
                EXEC SPK_SUMA_DBCR @NROCOMPROBANTE_AUTO
                PRINT 'OK: SPK_SUMA_DBCR ejecutado'
            END TRY
            BEGIN CATCH
                PRINT 'ERROR en SPK_SUMA_DBCR: ' + ERROR_MESSAGE()
            END CATCH
            
            -- Ejecutar metodo RECALCULAR_TOTALES para asegurar actualizacion completa
            BEGIN TRY
                DECLARE @JSON_RECALC NVARCHAR(MAX) = '{"MODELO":"MCP_COL","METODO":"RECALCULAR_TOTALES","PARAMETROS":{"NROCOMPROBANTE":"' + @NROCOMPROBANTE_AUTO + '","COMPANIA":"' + @COMPANIA_AUTO + '"},"USUARIO":"' + @USUARIO + '"}'
                EXEC SPQ_MCP_COL @JSON_RECALC
                PRINT 'OK: RECALCULAR_TOTALES ejecutado - MCP actualizada automaticamente'
            END TRY
            BEGIN CATCH
                PRINT 'ERROR en RECALCULAR_TOTALES: ' + ERROR_MESSAGE()
            END CATCH
            
            -- Mostrar totales finales actualizados
            DECLARE @TOTAL_FINAL_DB DECIMAL(18,2) = 0
            DECLARE @TOTAL_FINAL_CR DECIMAL(18,2) = 0
            DECLARE @ESTADO_FINAL_MCP VARCHAR(1) = '0'
            
            SELECT @TOTAL_FINAL_DB = COALESCE(TOTALDEBITO, 0),
                   @TOTAL_FINAL_CR = COALESCE(TOTALCREDITO, 0),
                   @ESTADO_FINAL_MCP = COALESCE(ESTADO, '0')
            FROM MCP 
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_AUTO
            
            PRINT 'TOTALES ACTUALIZADOS EN MCP:'
            PRINT 'Debito: ' + CAST(@TOTAL_FINAL_DB AS VARCHAR)
            PRINT 'Credito: ' + CAST(@TOTAL_FINAL_CR AS VARCHAR) 
            PRINT 'Estado: ' + @ESTADO_FINAL_MCP
            
        END TRY
        BEGIN CATCH
            PRINT 'Error en CRUDMCH automatico: ' + ERROR_MESSAGE()
            SELECT 'KO' AS OK, 
                   'Error en operacion automatica: ' + ERROR_MESSAGE() AS MENSAJE,
                   ERROR_LINE() AS LINEA_ERROR
        END CATCH
        
        RETURN
    END

    -- Si llegamos aqui, el metodo no fue reconocido
    SELECT 'KO' AS OK, 'Metodo no implementado: ' + ISNULL(@METODO, 'NULL') AS ERROR
END

