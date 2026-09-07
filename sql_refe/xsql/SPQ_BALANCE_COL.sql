CREATE OR ALTER PROCEDURE DBO.SPQ_BALANCE_COL
@JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    DECLARE @PARAMETROS NVARCHAR(MAX), @MODELO VARCHAR(100), @METODO VARCHAR(100), @USUARIO VARCHAR(12)
    DECLARE @ANO_INICIAL VARCHAR(4), @MES_INICIAL VARCHAR(2), @ANO_FINAL VARCHAR(4), @MES_FINAL VARCHAR(2)
    DECLARE @CUENTA_INICIAL VARCHAR(20), @CUENTA_FINAL VARCHAR(20), @NIVEL_INICIAL INT, @NIVEL_FINAL INT
    DECLARE @TERCERO_INICIAL VARCHAR(20), @TERCERO_FINAL VARCHAR(20)
    DECLARE @VER_SALDOS_TERCERO BIT, @VER_SALDOS_CCOSTO BIT, @GENERAR_AUXILIARES BIT, @APLICAR_CIERRE BIT
    DECLARE @COMPANIA VARCHAR(2), @IDSEDE VARCHAR(5), @CONSECUTIVO VARCHAR(20), @CNS_AUXILIAR VARCHAR(20)
    DECLARE @FECHA_INICIAL DATETIME, @FECHA_FINAL DATETIME, @CCOSTO_INI VARCHAR(20), @CCOSTO_FIN VARCHAR(20)
    DECLARE @SQL NVARCHAR(MAX), @MESINI VARCHAR(2), @MESFIN VARCHAR(2), @REGISTROS_INSERTADOS INT
    DECLARE @ANOINI VARCHAR(4), @ANOFIN VARCHAR(4)
    DECLARE @CNSPRO VARCHAR(20),@SYS_COMPUTERNAME VARCHAR(255)
    DECLARE @PAGE_NUMBER INT, @PAGE_SIZE INT, @ROW_START INT, @ROW_END INT
    DECLARE @nivelInicial SMALLINT, @nivelFinal SMALLINT
    DECLARE @CUENTA_FILTRO VARCHAR(20), @CUENTA_FILTRO_T VARCHAR(20)
    DECLARE @CNS VARCHAR(20)
    DECLARE @cnsBalance VARCHAR(20), @cnsAuxiliar VARCHAR(20)

    SET NOCOUNT ON
    SET DEADLOCK_PRIORITY HIGH
    
    BEGIN TRY
        SET LANGUAGE Spanish
        SET DATEFORMAT dmy

        IF ISJSON(@JSON) = 0
        BEGIN
            RAISERROR('Json: Formato Erroneo', 16, 1)
            RETURN
        END

        SELECT @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON)
        WITH(
            PARAMETROS NVARCHAR(MAX) AS JSON 
        )

        SELECT @MODELO = JSON_VALUE(@JSON, '$.MODELO'),
               @METODO = JSON_VALUE(@JSON, '$.METODO'),
               @USUARIO = JSON_VALUE(@JSON, '$.USUARIO')

         SELECT @IDSEDE=COALESCE(UBEQ.IDSEDE,USUSU.IDSEDE),@COMPANIA=COALESCE(UBEQ.COMPANIA,USUSU.COMPANIA), 
         @SYS_COMPUTERNAME=COALESCE(USUSU.SYS_ComputerName,HOST_NAME())   
         FROM USUSU LEFT JOIN UBEQ ON USUSU.SYS_ComputerName=UBEQ.SYS_ComputerName
            WHERE USUSU.USUARIO=@USUARIO
        IF @METODO='DATOS_EXPORT'
        BEGIN
           SELECT 'OK' AS OK
			  SELECT TER.NIT,TER.DV,COALESCE(SED.DIRECCION,TER.DIRECCION)DIRECCION,COALESCE(SED.TELEFONOS,TER.TELEFONOS)TELEFONOS,
            CASE WHEN DBO.FNK_VALORVARIABLE('RAZONSOCIALENSEDES')='TER' THEN SED.DESCRIPCION ELSE '' END+' - '+CIU.NOMBRE CIUDAD,DEP.NOMBRE AS DPTO,COALESCE(SED.EMAIL,TER.EMAIL)EMAIL,
            SED.CODHABILITA, COALESCE(TER.RAZONSOCIAL,SED.DESCRIPCION) AS RAZONSOCIAL
            FROM SED INNER JOIN TER ON SED.NIT=TER.NIT
		            INNER JOIN CIU ON COALESCE(SED.CIUDAD,TER.CIUDAD)=CIU.CIUDAD
		            LEFT  JOIN DEP ON CIU.DPTO=DEP.DPTO
                  LEFT  JOIN UBEQ ON SED.IDSEDE=UBEQ.IDSEDE
                  LEFT JOIN USUSU ON UBEQ.SYS_ComputerName=USUSU.SYS_ComputerName
            WHERE USUSU.USUARIO=@USUARIO
            AND TER.ESTADO='Activo' 
            RETURN
        END
        IF @METODO = 'GENERAR_BALANCE' 
        BEGIN 
            SELECT @ANO_INICIAL = JSON_VALUE(@PARAMETROS, '$.anoInicial'),
                   @MES_INICIAL = JSON_VALUE(@PARAMETROS, '$.mesInicial'),
                   @ANO_FINAL = JSON_VALUE(@PARAMETROS, '$.anoFinal'),
                   @MES_FINAL = JSON_VALUE(@PARAMETROS, '$.mesFinal'),
                   @CUENTA_INICIAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.cuentaInicial'), '1'),
                   @CUENTA_FINAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.cuentaFinal'), '99999999999999999'),
                   @TERCERO_INICIAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.terceroInicial'), ''),
                   @TERCERO_FINAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.terceroFinal'), 'ZZZZZZZZZZZZZZZZZZ'),
                   @CCOSTO_INI = ISNULL(JSON_VALUE(@PARAMETROS, '$.ccostoInicial'), ''),
                   @CCOSTO_FIN = ISNULL(JSON_VALUE(@PARAMETROS, '$.ccostoFinal'), 'ZZZZZZ'),
                   @NIVEL_INICIAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.nivelInicial'), 1),
                   @NIVEL_FINAL = ISNULL(JSON_VALUE(@PARAMETROS, '$.nivelFinal'), 10),
                   @VER_SALDOS_TERCERO = ISNULL(JSON_VALUE(@PARAMETROS, '$.verSaldosTercero'), 0),
                   @VER_SALDOS_CCOSTO = ISNULL(JSON_VALUE(@PARAMETROS, '$.verSaldosCCosto'), 0),
                   @GENERAR_AUXILIARES = ISNULL(JSON_VALUE(@PARAMETROS, '$.generarAuxiliares'), 0),
                   @APLICAR_CIERRE = ISNULL(JSON_VALUE(@PARAMETROS, '$.aplicarCierre'), 0)

            IF CAST(@ANO_FINAL AS INT) < CAST(@ANO_INICIAL AS INT)
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'El A?o Final No Puede Ser Menor Al A?o Inicial...' AS MENSAJE
                RETURN
            END

            IF @ANO_FINAL = @ANO_INICIAL AND CAST(@MES_FINAL AS INT) < CAST(@MES_INICIAL AS INT)
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'El Mes Final No Puede Ser Menor Al Mes Inicial...' AS MENSAJE
                RETURN
            END

            PRINT '========================================='
            PRINT 'GENERACI?N DE BALANCE - INICIO'
            PRINT '========================================='

            -- PASO 1: Preparar consecutivos (sin tocar ?ndices)
            PRINT 'PASO 1: Preparando consecutivos...'

            PRINT 'AQUI LLAMO A GENCONSECUTIVO @IDSEDE='+COALESCE(@IDSEDE,'SIN SEDE')  +COALESCE(@COMPANIA,'CIA') 
            SELECT @CONSECUTIVO=''
		      EXEC SPK_GENCONSECUTIVO @COMPANIA,@IDSEDE, '@TPROCONT', @CONSECUTIVO OUTPUT  
            PRINT '@CNSCXC='+COALESCE(@CONSECUTIVO,'')   
		      SELECT @CONSECUTIVO = @IDSEDE + REPLACE(SPACE(8 - LEN(@CONSECUTIVO))+LTRIM(RTRIM(@CONSECUTIVO)),SPACE(1),0)
		      PRINT '@CNSCXC='+COALESCE(@CONSECUTIVO,'')    

           -- SET @CONSECUTIVO = @IDSEDE + '00000001'
            IF @GENERAR_AUXILIARES =1
            BEGIN
               PRINT 'AQUI LLAMO A GENCONSECUTIVO @IDSEDE='+COALESCE(@IDSEDE,'SIN SEDE')  +COALESCE(@COMPANIA,'CIA') 
               SELECT @CNS_AUXILIAR=''
		         EXEC SPK_GENCONSECUTIVO @COMPANIA,@IDSEDE, '@RPDX2', @CNS_AUXILIAR OUTPUT  
               PRINT '@CNSCXC='+COALESCE(@CNS_AUXILIAR,'')   
		         SELECT @CNS_AUXILIAR = @IDSEDE + REPLACE(SPACE(8 - LEN(@CNS_AUXILIAR))+LTRIM(RTRIM(@CNS_AUXILIAR)),SPACE(1),0)
		         PRINT '@CNSCXC='+COALESCE(@CNS_AUXILIAR,'')    
             --  SET @CNS_AUXILIAR = @IDSEDE + '00100001'
               PRINT '  -> auxiliar: ' + @CNS_AUXILIAR
            END
            -- Limpieza dirigida al CNS actual (evita TRUNCATE global)
            DELETE FROM TBALANCETERFAC
            WHERE CNSPRO = @CONSECUTIVO

            -- PASO 2: EJECUTAR SPK_BALANCE
            PRINT 'PASO 2: Ejecutando SPK_BALANCE...'
            
            SET @FECHA_INICIAL = DATEFROMPARTS(CAST(@ANO_INICIAL AS INT), CAST(@MES_INICIAL AS INT), 1)
            SET @FECHA_FINAL = EOMONTH(DATEFROMPARTS(CAST(@ANO_FINAL AS INT), CAST(@MES_FINAL AS INT), 1))
            SET @MESINI = @MES_INICIAL
            SET @MESFIN = @MES_FINAL

            IF @APLICAR_CIERRE = 1 AND @MES_FINAL = '12'
                SET @MESFIN = '13'

            SET @SQL = 'EXEC SPK_BALANCE '

            IF @VER_SALDOS_TERCERO = 1 AND (@TERCERO_INICIAL = '' OR @TERCERO_INICIAL IS NULL)
                SET @SQL = @SQL + '''AU'''
            ELSE
                SET @SQL = @SQL + '''BP'''

            SET @SQL = @SQL + ', ''' + @CONSECUTIVO + ''''
                     + ', ''' + @ANO_INICIAL + ''''
                     + ', ''' + @MESINI + ''''
                     + ', ''' + @ANO_FINAL + ''''
                     + ', ''' + @MESFIN + ''''
                     + ', ''' + @CUENTA_INICIAL + ''''
                     + ', ''' + @CUENTA_FINAL + ''''
                     + ', ' + CAST(@NIVEL_INICIAL AS VARCHAR)
                     + ', ' + CAST(@NIVEL_FINAL AS VARCHAR)
                     + ', ''' + ISNULL(@CCOSTO_INI, '') + ''''
                     + ', ''' + ISNULL(@CCOSTO_FIN, '') + ''''
                     + ', ''' + @COMPANIA + ''''
                     + ', ''' + @IDSEDE + ''''
                     + ', ''' + ISNULL(@TERCERO_INICIAL, '') + ''''
                     + ', ''' + ISNULL(@TERCERO_FINAL, '') + ''''
                     + ', ' + CAST(@VER_SALDOS_TERCERO AS VARCHAR)
                     + ', ' + CAST(@VER_SALDOS_CCOSTO AS VARCHAR)

			PRINT '  SQL: ' + @SQL
            
            BEGIN TRY
                EXEC sp_executesql @SQL
                PRINT '  -> SPK_BALANCE ejecutado'
            END TRY
            BEGIN CATCH
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Error: ' + ERROR_MESSAGE() AS MENSAJE
                RETURN
            END CATCH

            -- PASO 3: LIMPIAR DUPLICADOS (solo CNS actual)
            PRINT 'PASO 3: Verificando duplicados...'
            
            ;WITH CTE AS (
                SELECT *, ROW_NUMBER() OVER (
                    PARTITION BY CNSPRO, CUENTA, ISNULL(IDTERCERO,''), ISNULL(CCOSTO,''), ISNULL(N_FACTURA,'')
                    ORDER BY (SELECT NULL)
                ) AS RN
                FROM TBALANCETERFAC
                WHERE CNSPRO = @CONSECUTIVO
            )
            DELETE FROM CTE WHERE RN > 1
            
            DECLARE @ELIMINADOS INT = @@ROWCOUNT
            IF @ELIMINADOS > 0
                PRINT '  ? Duplicados eliminados: ' + CAST(@ELIMINADOS AS VARCHAR)
            ELSE
                PRINT '  ? Sin duplicados'

            -- ? PASO 7: CONTAR REGISTROS
            DECLARE @COUNT_BALANCE INT = 0
            
            SELECT @COUNT_BALANCE = COUNT(*) 
            FROM TBALANCETERFAC WITH (NOLOCK)
            WHERE CNSPRO = @CONSECUTIVO

            PRINT 'PASO 7: Registros: ' + CAST(@COUNT_BALANCE AS VARCHAR)

            IF @COUNT_BALANCE = 0
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Sin datos' AS MENSAJE
                RETURN
            END

            -- ? PASO 8: GENERAR AUXILIAR
            DECLARE @COUNT_AUXILIAR INT = 0
            
            IF @GENERAR_AUXILIARES = 1 AND OBJECT_ID('dbo.NC_SPK_MOVXTERCERO') IS NOT NULL
            BEGIN
                PRINT 'PASO 8: Generando auxiliares...'
                
                SET @SQL = 'EXEC NC_SPK_MOVXTERCERO '
                         + '''' + CONVERT(VARCHAR(10), @FECHA_INICIAL, 103) + ''''
                         + ', ''' + CONVERT(VARCHAR(10), @FECHA_FINAL, 103) + ''''
                         + ', ''' + @TERCERO_INICIAL + ''''
                         + ', ''' + @TERCERO_FINAL + ''''
                         + ', ''' + @CUENTA_INICIAL + ''''
                         + ', ''' + @CUENTA_FINAL + ''''
                         + ', ''' + @CCOSTO_INI + ''''
                         + ', ''' + @CCOSTO_FIN + ''''
                         + ', '''''
                         + ', ''' + @CNS_AUXILIAR + ''''
                         + ', ''' + @COMPANIA + ''''
                         + ', ''' + @IDSEDE + ''''
                         + ', ''' + @CONSECUTIVO + ''''

                BEGIN TRY
                    EXEC sp_executesql @SQL
                    SELECT @COUNT_AUXILIAR = COUNT(*) FROM RPDX2 WITH (NOLOCK) WHERE CNS = @CNS_AUXILIAR
                    PRINT '  ? Auxiliares: ' + CAST(@COUNT_AUXILIAR AS VARCHAR)
                END TRY
                BEGIN CATCH
                    PRINT '  ? Error: ' + ERROR_MESSAGE()
                    SET @COUNT_AUXILIAR = 0
                END CATCH
            END

            SELECT 
                'OK' AS OK,
                'RESULTADO' AS TIPO,
                'Balance: ' + CAST(@COUNT_BALANCE AS VARCHAR) + ' registros' + 
                CASE WHEN @GENERAR_AUXILIARES = 1 THEN '. Auxiliares: ' + CAST(@COUNT_AUXILIAR AS VARCHAR) ELSE '' END AS MENSAJE,
                @CONSECUTIVO AS CONSECUTIVO,
                @CNS_AUXILIAR AS CONSECUTIVO_AUXILIAR,
                @COUNT_BALANCE AS REGISTROS_BALANCE,
                @COUNT_AUXILIAR AS REGISTROS_AUXILIAR

            RETURN
        END
        IF @METODO = 'OBTENER_BALANCE'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.consecutivo')
            SET @nivelInicial = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.nivelInicial') AS SMALLINT), 1)
            SET @nivelFinal   = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.nivelFinal') AS SMALLINT), 10)
            IF @nivelInicial < 1 SET @nivelInicial = 1
            IF @nivelFinal > 10 SET @nivelFinal = 10
            IF @nivelInicial > @nivelFinal SET @nivelFinal = @nivelInicial

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
                SELECT TOP 1 @CONSECUTIVO = CNSPRO FROM TBALANCETERFAC WITH (NOLOCK) ORDER BY CNSPRO DESC

            IF @CONSECUTIVO IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'No existen datos' AS MENSAJE
                RETURN
            END
            SELECT 'OK' AS OK
            SELECT 
                T.CUENTA, T.NOMCUENTA, 
                ISNULL(T.IDTERCERO, '') AS IDTERCERO, 
				TER.NIT,
				TER.RAZONSOCIAL AS RAZON_SOCIAL,
                ISNULL(T.CCOSTO, '') AS CCOSTO,
				CEN.DESCRIPCION AS NOMBRE_CCOSTO,
                ISNULL(T.N_FACTURA, '') AS N_FACTURA, 
                CAST(ISNULL(T.SI, 0) AS DECIMAL(18,2)) AS SI,
                CAST(ISNULL(T.DB, 0) AS DECIMAL(18,2)) AS DB, 
                CAST(ISNULL(T.CR, 0) AS DECIMAL(18,2)) AS CR,
                CAST(ISNULL(T.DB, 0) - ISNULL(T.CR, 0) AS DECIMAL(18,2)) AS SM,
                CAST(ISNULL(T.SF, 0) AS DECIMAL(18,2)) AS SF, 
                ISNULL(T.NTZ, '') AS NTZ, 
                ISNULL(T.TIPO, '') AS TIPO,
		    CASE 
                    WHEN T.IDTERCERO IS NULL OR T.IDTERCERO = '' THEN 'CUENTA'
                    ELSE 'TERCERO'
                END AS TIPO_FILA
            FROM TBALANCETERFAC T WITH (NOLOCK)
			LEFT JOIN TER ON TER.IDTERCERO=T.IDTERCERO
			LEFT JOIN CEN ON CEN.CCOSTO=T.CCOSTO
			INNER JOIN CUE ON CUE.CUENTA = T.CUENTA
            WHERE T.CNSPRO = @CONSECUTIVO
                AND CUE.NIVEL >= @nivelInicial
                AND CUE.NIVEL <= @nivelFinal
            --WHERE T.CNSPRO = @CONSECUTIVO
            ORDER BY T.CUENTA, 
                --CASE WHEN T.IDTERCERO IS NULL OR T.IDTERCERO = '' THEN 0 ELSE 1 END, 
                T.IDTERCERO, T.CCOSTO


                SELECT SI,DB,CR,SF,SM
                FROM TBALANCETERFAC T WITH (NOLOCK)
                WHERE T.CNSPRO = @CONSECUTIVO
                AND TIPO='Total_General'

            RETURN
        END
        IF @METODO = 'OBTENER_AUXILIAR'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.consecutivo')
            SET @CUENTA_FILTRO = ISNULL(JSON_VALUE(@PARAMETROS, '$.cuenta'), '')
            SET @PAGE_NUMBER = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.page') AS INT), 0)
            SET @PAGE_SIZE = ISNULL(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.rowsPerPage') AS INT), 0)
            IF @PAGE_NUMBER < 1 SET @PAGE_NUMBER = 0
            IF @PAGE_SIZE < 1 SET @PAGE_SIZE = 0
            
            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
                SELECT TOP 1 @CONSECUTIVO = CNS FROM RPDX2 WITH (NOLOCK) WHERE ID1 IS NOT NULL ORDER BY CNS DESC

            IF @CONSECUTIVO IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'No existen datos de auxiliar' AS MENSAJE
                RETURN
            END

            IF @PAGE_SIZE = 0
            BEGIN
			    SELECT 
				    'MV' AS TIPO, 
				    R.ID1 AS CUENTA, 
				    ISNULL(R.STRINGMEDIO1, '') AS NOMBRE_CUENTA,  -- Descripci?n de la cuenta
				    ISNULL(R.ID3, '') AS TERCERO,                 -- ID3 = IDTERCERO/NIT
				    ISNULL(R.ID2, '') AS CCOSTO,                  -- ID2 = CCOSTO
				    ISNULL(R.STRINGMEDIO2, '') AS NOMBRE_CCOSTO,  -- Descripci?n del centro de costo
				    ISNULL(R.ID4, '') AS N_FACTURA,             -- ID4 = N_FACTURA
				    ISNULL(R.ID5, '') AS COMPROBANTE,             -- ID4 = N_FACTURA
				    ISNULL(R.ID6, '') AS CONSECUTIVO,             -- ID4 = N_FACTURA
				    ISNULL(CONVERT(VARCHAR(10), R.FECHA3, 103), '') AS FECHA,
				    ISNULL(R.STRINGGRANDE1, '') AS DETALLE, 
				    CAST(ISNULL(R.VALOR1, 0) AS DECIMAL(18,2)) AS SALDO_INICIAL,
				    CAST(ISNULL(R.VALOR2, 0) AS DECIMAL(18,2)) AS DEBITO, 
				    CAST(ISNULL(R.VALOR3, 0) AS DECIMAL(18,2)) AS CREDITO,
				    CAST(ISNULL(R.VALOR4, 0) AS DECIMAL(18,2)) AS SALDO_ACUMULADO, 
				    ISNULL(R.STRINGMEDIO3, '') AS RAZON_SOCIAL,
				    ISNULL(COM.NOMCOMPROBANTE, '') AS TIPO_COMPROBANTE, --tipo comprobante
				    ISNULL(R.ID14, '') AS NROCOMPROBANTE --nro comprobante
				
			    FROM RPDX2 R WITH (NOLOCK)
			    LEFT JOIN COM ON COM.COMPROBANTE = R.ID5 AND R.ID5 IS NOT NULL AND R.ID5 <> ''
			    WHERE R.CNS = @CONSECUTIVO AND R.ID1 IS NOT NULL
                  AND (@CUENTA_FILTRO = '' OR R.ID1 = @CUENTA_FILTRO)
			    ORDER BY R.ID1, R.FECHA3, R.ID4, R.ID5, R.ID14, R.ID3, R.ID2, R.VALOR2, R.VALOR3, R.VALOR4, R.ID6, R.STRINGGRANDE1, R.ITEM
                OPTION (RECOMPILE)
            END
            ELSE
            BEGIN
                SET @ROW_START = ((@PAGE_NUMBER - 1) * @PAGE_SIZE) + 1
                SET @ROW_END = @PAGE_NUMBER * @PAGE_SIZE

                ;WITH CTE_AUX AS (
                    SELECT
                        ROW_NUMBER() OVER (
                            ORDER BY R.ID1, R.FECHA3, R.ID4, R.ID5, R.ID14, R.ID3, R.ID2,
                                     R.VALOR2, R.VALOR3, R.VALOR4, R.ID6, R.STRINGGRANDE1, R.ITEM
                        ) AS RN,
                        COUNT(1) OVER() AS TOTAL_REGISTROS,
                        'MV' AS TIPO,
                        R.ID1 AS CUENTA,
                        ISNULL(R.STRINGMEDIO1, '') AS NOMBRE_CUENTA,
                        ISNULL(R.ID3, '') AS TERCERO,
                        ISNULL(R.ID2, '') AS CCOSTO,
                        ISNULL(R.STRINGMEDIO2, '') AS NOMBRE_CCOSTO,
                        ISNULL(R.ID4, '') AS N_FACTURA,
                        ISNULL(R.ID5, '') AS COMPROBANTE,
                        ISNULL(R.ID6, '') AS CONSECUTIVO,
                        ISNULL(CONVERT(VARCHAR(10), R.FECHA3, 103), '') AS FECHA,
                        ISNULL(R.STRINGGRANDE1, '') AS DETALLE,
                        CAST(ISNULL(R.VALOR1, 0) AS DECIMAL(18,2)) AS SALDO_INICIAL,
                        CAST(ISNULL(R.VALOR2, 0) AS DECIMAL(18,2)) AS DEBITO,
                        CAST(ISNULL(R.VALOR3, 0) AS DECIMAL(18,2)) AS CREDITO,
                        CAST(ISNULL(R.VALOR4, 0) AS DECIMAL(18,2)) AS SALDO_ACUMULADO,
                        ISNULL(R.STRINGMEDIO3, '') AS RAZON_SOCIAL,
                        ISNULL(COM.NOMCOMPROBANTE, '') AS TIPO_COMPROBANTE,
                        ISNULL(R.ID14, '') AS NROCOMPROBANTE
                    FROM RPDX2 R WITH (NOLOCK)
                    LEFT JOIN COM ON COM.COMPROBANTE = R.ID5 AND R.ID5 IS NOT NULL AND R.ID5 <> ''
                    WHERE R.CNS = @CONSECUTIVO AND R.ID1 IS NOT NULL
                      AND (@CUENTA_FILTRO = '' OR R.ID1 = @CUENTA_FILTRO)
                )
                SELECT
                    TIPO, CUENTA, NOMBRE_CUENTA, TERCERO, CCOSTO, NOMBRE_CCOSTO, N_FACTURA, COMPROBANTE, CONSECUTIVO, FECHA,
                    DETALLE, SALDO_INICIAL, DEBITO, CREDITO, SALDO_ACUMULADO, RAZON_SOCIAL,
                    TIPO_COMPROBANTE, NROCOMPROBANTE, TOTAL_REGISTROS
                FROM CTE_AUX
                WHERE RN BETWEEN @ROW_START AND @ROW_END
                ORDER BY RN
                OPTION (RECOMPILE)
            END

            RETURN
        END
        IF @METODO = 'OBTENER_AUXILIAR_TOTALES'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.consecutivo')
            SET @CUENTA_FILTRO_T = ISNULL(JSON_VALUE(@PARAMETROS, '$.cuenta'), '')

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
                SELECT TOP 1 @CONSECUTIVO = CNS FROM RPDX2 WITH (NOLOCK) WHERE ID1 IS NOT NULL ORDER BY CNS DESC

            IF @CONSECUTIVO IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'No existen datos de auxiliar' AS MENSAJE
                RETURN
            END

            ;WITH BASE AS (
                SELECT
                    CAST(ISNULL(R.VALOR1, 0) AS DECIMAL(18,2)) AS SALDO_INICIAL,
                    CAST(ISNULL(R.VALOR2, 0) AS DECIMAL(18,2)) AS DEBITO,
                    CAST(ISNULL(R.VALOR3, 0) AS DECIMAL(18,2)) AS CREDITO,
                    CAST(ISNULL(R.VALOR4, 0) AS DECIMAL(18,2)) AS SALDO_ACUMULADO,
                    ROW_NUMBER() OVER (ORDER BY R.ID1, R.FECHA3, R.ID4, R.ID5, R.ID14, R.ID3, R.ID2, R.VALOR2, R.VALOR3, R.VALOR4, R.ID6, R.STRINGGRANDE1, R.ITEM) AS RN_ASC,
                    ROW_NUMBER() OVER (ORDER BY R.ID1 DESC, R.FECHA3 DESC, R.ID4 DESC, R.ID5 DESC, R.ID14 DESC, R.ID3 DESC, R.ID2 DESC, R.VALOR2 DESC, R.VALOR3 DESC, R.VALOR4 DESC, R.ID6 DESC, R.STRINGGRANDE1 DESC, R.ITEM DESC) AS RN_DESC
                FROM RPDX2 R WITH (NOLOCK)
                WHERE R.CNS = @CONSECUTIVO
                  AND R.ID1 IS NOT NULL
                  AND (@CUENTA_FILTRO_T = '' OR R.ID1 = @CUENTA_FILTRO_T)
            )
            SELECT
                ISNULL(SUM(DEBITO), 0) AS TOTAL_DEBITOS,
                ISNULL(SUM(CREDITO), 0) AS TOTAL_CREDITOS,
                ISNULL(MAX(CASE WHEN RN_ASC = 1 THEN SALDO_INICIAL END), 0) AS SALDO_INICIAL,
                ISNULL(MAX(CASE WHEN RN_DESC = 1 THEN SALDO_ACUMULADO END), 0) AS SALDO_FINAL,
                COUNT(1) AS TOTAL_REGISTROS
            FROM BASE

            RETURN
        END
        IF @METODO = 'OBTENER_RESUMEN'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.consecutivo')

            SELECT 'ACTIVO' AS TIPO_CUENTA,
                ISNULL(SUM(T.SI), 0) AS TOTAL_SI, ISNULL(SUM(T.DB), 0) AS TOTAL_DB,
                ISNULL(SUM(T.CR), 0) AS TOTAL_CR, ISNULL(SUM(T.SF), 0) AS TOTAL_SF
            FROM TBALANCETERFAC T WITH (NOLOCK)
            WHERE T.CNSPRO = @CONSECUTIVO AND T.CUENTA LIKE '1%' AND (T.IDTERCERO IS NULL OR T.IDTERCERO = '')
            UNION ALL
            SELECT 'DEBITO' AS TIPO_CUENTA,
                ISNULL(SUM(T.SI), 0), ISNULL(SUM(T.DB), 0), ISNULL(SUM(T.CR), 0), ISNULL(SUM(T.SF), 0)
            FROM TBALANCETERFAC T WITH (NOLOCK)
            WHERE T.CNSPRO = @CONSECUTIVO AND (T.CUENTA LIKE '1%' OR T.CUENTA LIKE '5%' OR T.CUENTA LIKE '6%' OR T.CUENTA LIKE '7%') AND (T.IDTERCERO IS NULL OR T.IDTERCERO = '')
            UNION ALL
            SELECT 'CREDITO' AS TIPO_CUENTA,
                ISNULL(SUM(T.SI), 0), ISNULL(SUM(T.DB), 0), ISNULL(SUM(T.CR), 0), ISNULL(SUM(T.SF), 0)
            FROM TBALANCETERFAC T WITH (NOLOCK)
            WHERE T.CNSPRO = @CONSECUTIVO AND (T.CUENTA LIKE '2%' OR T.CUENTA LIKE '3%' OR T.CUENTA LIKE '4%') AND (T.IDTERCERO IS NULL OR T.IDTERCERO = '')

            RETURN
        END
        IF @METODO = 'TOMAR_FOTO_MES'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.CONSECUTIVO'),
                   @ANOINI = JSON_VALUE(@PARAMETROS, '$.ANOINICIAL'),
                   @ANOFIN = JSON_VALUE(@PARAMETROS, '$.ANOFINAL'),
                   @MESINI = JSON_VALUE(@PARAMETROS, '$.MESINICIAL'),
                   @MESFIN = JSON_VALUE(@PARAMETROS, '$.MESFINAL')

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Consecutivo requerido' AS MENSAJE
                RETURN
            END
            
            IF COALESCE(@ANOINI,'')<>COALESCE(@ANOFIN,'')
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'A?o requerido para la foto del mes el a?o inicial y final deben ser iguales' AS MENSAJE
                RETURN
            END

            IF COALESCE(@MESINI,'')<>COALESCE(@MESFIN,'')
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'El mes inicial y mes final debe ser iguales ' AS MENSAJE
                RETURN
            END
            
            IF @MESINI < 1 OR @MESINI > 12
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Mes Inicial inv?lido (1-12)' AS MENSAJE
                RETURN
            END
            IF @MESFIN < 1 OR @MESFIN > 12
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Mes Final inv?lido (1-12)' AS MENSAJE
                RETURN
            END            
            IF NOT EXISTS (SELECT 1 FROM TBALANCETERFAC WITH (NOLOCK) WHERE CNSPRO=@CONSECUTIVO)
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'No puede insertar foto sin detalle' AS MENSAJE
                RETURN
            END
            IF EXISTS (SELECT 1 FROM TBALANCEH WITH (NOLOCK) WHERE ANO=@ANOFIN AND MES=@MESFIN AND CLASEH='BPRUEBA')
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Ya existe una foto para el periodo indicado' AS MENSAJE
                RETURN
            END
            BEGIN TRY
		        EXEC SPK_GENCONSECUTIVO '01','01','@TBALANCEH', @CNSPRO OUTPUT  
		        SELECT @CNSPRO = '01' + REPLACE(SPACE(8 - LEN(@CNSPRO))+LTRIM(RTRIM(@CNSPRO)),SPACE(1),0) 

                INSERT INTO TBALANCEH (CNSPRO,ANO,MES, CUENTA, IDTERCERO, CCOSTO, N_FACTURA, NOMCUENTA, SI, DB, CR, SF, SM, NTZ, TIPO,CLASEH)
                SELECT @CNSPRO, @ANOFIN,@MESFIN, CUENTA, IDTERCERO, CCOSTO, N_FACTURA, NOMCUENTA, SI, DB, CR, SF, SM, NTZ, TIPO,'BPRUEBA'
                FROM TBALANCETERFAC WHERE CNSPRO=@CONSECUTIVO
                SET @REGISTROS_INSERTADOS = @@ROWCOUNT
            END TRY
            BEGIN CATCH                
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Error al generar la foto: ' + ERROR_MESSAGE() AS MENSAJE, @REGISTROS_INSERTADOS AS REGISTROS_INSERTADOS
                RETURN
            END CATCH

            SELECT 'RESULTADO' AS TIPO, 'OK' AS OK, 'Foto del mes ' + @ANOFIN + '-' + RIGHT('0' + CAST(@MESFIN AS VARCHAR(2)), 2) + ' guardada correctamente' AS MENSAJE,
                   @REGISTROS_INSERTADOS AS REGISTROS_INSERTADOS
            RETURN
        END
        IF @METODO = 'TOMAR_FOTO_ANO'
        BEGIN
            SELECT @CONSECUTIVO = JSON_VALUE(@PARAMETROS, '$.CONSECUTIVO'),
                   @ANOINI = JSON_VALUE(@PARAMETROS, '$.ANOINICIAL'),
                   @ANOFIN = JSON_VALUE(@PARAMETROS, '$.ANOFINAL'),
                   @MESINI = JSON_VALUE(@PARAMETROS, '$.MESINICIAL'),
                   @MESFIN = JSON_VALUE(@PARAMETROS, '$.MESFINAL')

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Consecutivo requerido' AS MENSAJE
                RETURN
            END
            
            IF COALESCE(@ANOINI,'')<>COALESCE(@ANOFIN,'')
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'A?o requerido para la foto del mes el a?o inicial y final deben ser iguales' AS MENSAJE
                RETURN
            END
            
            IF COALESCE(@MESINI,'')<>1
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'El mes inicial debe ser 1 (Enero)' AS MENSAJE
                RETURN
            END

            IF COALESCE(@MESFIN,'')<>12
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'El mes Final debe ser 12 (Diciembre)' AS MENSAJE
                RETURN
            END
           
            IF NOT EXISTS (SELECT 1 FROM TBALANCETERFAC WITH (NOLOCK) WHERE CNSPRO=@CONSECUTIVO)
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'No puede insertar foto sin detalle' AS MENSAJE
                RETURN
            END
            IF EXISTS (SELECT 1 FROM TBALANCEH WITH (NOLOCK) WHERE ANO=@ANOFIN AND MES='13' AND CLASEH='BPRUEBA')
            BEGIN
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Ya existe una foto para el a?o indicado' AS MENSAJE
                RETURN
            END
            BEGIN TRY
		        EXEC SPK_GENCONSECUTIVO '01','01','@TBALANCEH', @CNSPRO OUTPUT  
		        SELECT @CNSPRO = '01' + REPLACE(SPACE(8 - LEN(@CNSPRO))+LTRIM(RTRIM(@CNSPRO)),SPACE(1),0) 

                INSERT INTO TBALANCEH (CNSPRO,ANO,MES, CUENTA, IDTERCERO, CCOSTO, N_FACTURA, NOMCUENTA, SI, DB, CR, SF, SM, NTZ, TIPO,CLASEH)
                SELECT @CNSPRO, @ANOFIN,'13', CUENTA, IDTERCERO, CCOSTO, N_FACTURA, NOMCUENTA, SI, DB, CR, SF, SM, NTZ, TIPO,'BPRUEBA'
                FROM TBALANCETERFAC WHERE CNSPRO=@CONSECUTIVO
                SET @REGISTROS_INSERTADOS = @@ROWCOUNT
            END TRY
            BEGIN CATCH                
                SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Error al generar la foto del a?o: ' + @ANOFIN + '. ' + ERROR_MESSAGE() AS MENSAJE, @REGISTROS_INSERTADOS AS REGISTROS_INSERTADOS
                RETURN
            END CATCH

            SELECT 'RESULTADO' AS TIPO, 'OK' AS OK, 'Foto del a?o ' + @ANOFIN +' guardada correctamente' AS MENSAJE,
                   @REGISTROS_INSERTADOS AS REGISTROS_INSERTADOS
            RETURN
        END
        IF @METODO ='REPORTE_ACUMULADO_BP'
        BEGIN 
            SELECT @CNS = COALESCE(JSON_VALUE(@PARAMETROS, '$.CNS'), JSON_VALUE(@PARAMETROS, '$.consecutivo'))

            DECLARE @OMITIR_SALDOS_CERO BIT = ISNULL(JSON_VALUE(@PARAMETROS, '$.OMITIR_SALDOS_CERO'), 0)
        -- ========== Recordset 0: datos empresa / sede ==========

			    SELECT CASE WHEN DBO.FNK_VALORVARIABLE('RAZONSOCIALENSEDES')='TER' THEN (SELECT RAZONSOCIAL FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO'))ELSE
				    COALESCE(SED.DESCRIPCION,TER.RAZONSOCIAL) END RAZONSOCIAL,TER.NIT,TER.DV,COALESCE(SED.DIRECCION,TER.DIRECCION)DIRECCION,COALESCE(SED.TELEFONOS,TER.TELEFONOS)TELEFONOS,
			    CASE WHEN DBO.FNK_VALORVARIABLE('RAZONSOCIALENSEDES')='TER' THEN SED.DESCRIPCION ELSE '' END+' - '+CIU.NOMBRE CIUDAD,DEP.NOMBRE AS DPTO,COALESCE(SED.EMAIL,TER.EMAIL)EMAIL,SED.CODHABILITA, COALESCE(TER.RAZONSOCIAL,SED.DESCRIPCION) AS RAZONSOCIAL2
			    FROM SED INNER JOIN TER ON SED.NIT=TER.NIT
					    INNER JOIN CIU ON COALESCE(SED.CIUDAD,TER.CIUDAD)=CIU.CIUDAD
					    LEFT  JOIN DEP ON CIU.DPTO=DEP.DPTO
			    WHERE IDSEDE=@IDSEDE
             AND TER.ESTADO='Activo' 

            -- ========== Recordset 1: cabeceras (SI) ==========
            SELECT
                RTRIM(r.ID1) AS ID1,
                RTRIM(r.ID1) AS CUENTA,
                RTRIM(c.NOMCUENTA) AS NOMCUENTA,
                COALESCE(r.VALOR1,0) AS SALDO_INICIAL,
                CAST(CASE
                    WHEN LEFT(RTRIM(c.CUENTA), 1) IN ('2', '3', '4') THEN 1
                    ELSE 0
                END AS BIT) AS ES_NATURALEZA_CREDITO
            FROM RPDX2  r
            INNER JOIN CUE AS c ON RTRIM(r.ID1) = RTRIM(c.CUENTA)
            WHERE r.CNS = @CNS
              AND c.TIPO = 'Detalle'
              AND r.VALOR10 = 1
            GROUP BY RTRIM(r.ID1),RTRIM(c.NOMCUENTA), r.VALOR1, c.CUENTA
            ORDER BY RTRIM(r.ID1);

            -- ========== Recordset 2: movimientos ==========
            IF @OMITIR_SALDOS_CERO = 1
            BEGIN
                ;WITH MOV_BASE AS (
                    SELECT
                        r.ID1,
                        r.ID2,
                        ISNULL(r.STRINGMEDIO2, '') AS NOMBRE_CCOSTO,
                        r.ID3,
                        r.STRINGMEDIO3,
                        r.FECHA3,
                        r.ID4,
                        CONCAT(RTRIM(r.ID5), ' ', RTRIM(r.ID6)) AS COMPROBANTE,
                        r.STRINGMEDIO1,
                        r.STRINGGRANDE1 AS DETALLE,
                        r.VALOR1,
                        r.VALOR2,
                        r.VALOR3,
                        r.VALOR4
                    FROM RPDX2 AS r
                    WHERE r.CNS = @CNS
                   --   AND (r.VALOR2 > 0 OR r.VALOR3 > 0)
                ),
                SALDO_TERCERO AS (
                    SELECT
                        RTRIM(m.ID1) AS CUENTA,
                        RTRIM(ISNULL(m.ID3, '')) AS IDTERCERO,
                        CAST(
                            CASE
                                WHEN LEFT(RTRIM(m.ID1), 1) IN ('2', '3', '4')
                                THEN SUM(COALESCE(m.VALOR3, 0)) - SUM(COALESCE(m.VALOR2, 0))
                                ELSE SUM(COALESCE(m.VALOR2, 0)) - SUM(COALESCE(m.VALOR3, 0))
                            END AS DECIMAL(18, 2)
                        ) AS SALDO_FINAL
                    FROM MOV_BASE m
                    GROUP BY RTRIM(m.ID1), RTRIM(ISNULL(m.ID3, ''))
                )
                SELECT DISTINCT
                    m.ID1 AS ID1,
                    m.ID2 AS CCOSTO,
                    m.NOMBRE_CCOSTO,
                    m.ID3 AS IDTERCERO,
                    m.STRINGMEDIO3 AS RAZONSOCIAL,
                    m.FECHA3 AS FECHA3,
                    m.ID4 AS ID4,
                    m.COMPROBANTE,
                    m.STRINGMEDIO1,
                    m.STRINGMEDIO3,
                    m.DETALLE,
                    m.VALOR1 AS SI,
                    m.VALOR2 AS DB,
                    m.VALOR3 AS CR,
                    m.VALOR4 AS SF
                FROM MOV_BASE m
                INNER JOIN SALDO_TERCERO st
                    ON st.CUENTA = RTRIM(m.ID1)
                   AND st.IDTERCERO = RTRIM(ISNULL(m.ID3, ''))
                WHERE st.SALDO_FINAL <> 0
                ORDER BY m.ID1, m.FECHA3
            END
            ELSE
            BEGIN
                SELECT r.ID1 AS ID1, r.ID2 AS CCOSTO, ISNULL(r.STRINGMEDIO2, '') AS NOMBRE_CCOSTO, r.ID3 AS IDTERCERO,
                    r.STRINGMEDIO3 AS RAZONSOCIAL, r.FECHA3 AS FECHA3, r.ID4 AS ID4, CONCAT(RTRIM(r.ID5), ' ', RTRIM(r.ID6)) AS COMPROBANTE,
                    r.STRINGMEDIO1, r.STRINGMEDIO3, r.STRINGGRANDE1 AS DETALLE,
                    r.VALOR1 AS SI,
                    r.VALOR2 AS DB,
                    r.VALOR3 AS CR,
                    r.VALOR4 AS SF
                FROM RPDX2 AS r
                WHERE r.CNS = @CNS
                  AND (r.VALOR2 > 0 OR r.VALOR3 > 0)
                --GROUP BY r.ID1 , r.ID2, ISNULL(r.STRINGMEDIO2, '') ,
                --         r.ID3 , r.STRINGMEDIO3 , r.FECHA3 ,r.ID4 , CONCAT(RTRIM(r.ID5), ' ', RTRIM(r.ID6)) ,
                --         r.STRINGMEDIO1, r.STRINGMEDIO3, r.STRINGGRANDE1 
                ORDER BY r.ID1
            END
            
            RETURN
        END
        IF @METODO ='REPORTE_ACUMULADO_BP_TERCERO'
        BEGIN
            SELECT @CNS = COALESCE(JSON_VALUE(@PARAMETROS, '$.CNS'), JSON_VALUE(@PARAMETROS, '$.consecutivo'))

            DECLARE @OMITIR_SALDOS_CERO_T BIT = ISNULL(JSON_VALUE(@PARAMETROS, '$.OMITIR_SALDOS_CERO'), 0)

            -- ========== Recordset 0: datos empresa / sede ==========
            SELECT CASE WHEN DBO.FNK_VALORVARIABLE('RAZONSOCIALENSEDES')='TER' THEN (SELECT RAZONSOCIAL FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO'))ELSE
                COALESCE(SED.DESCRIPCION,TER.RAZONSOCIAL) END RAZONSOCIAL,TER.NIT,TER.DV,COALESCE(SED.DIRECCION,TER.DIRECCION)DIRECCION,COALESCE(SED.TELEFONOS,TER.TELEFONOS)TELEFONOS,
            CASE WHEN DBO.FNK_VALORVARIABLE('RAZONSOCIALENSEDES')='TER' THEN SED.DESCRIPCION ELSE '' END+' - '+CIU.NOMBRE CIUDAD,DEP.NOMBRE AS DPTO,COALESCE(SED.EMAIL,TER.EMAIL)EMAIL,SED.CODHABILITA, COALESCE(TER.RAZONSOCIAL,SED.DESCRIPCION) AS RAZONSOCIAL2
            FROM SED INNER JOIN TER ON SED.NIT=TER.NIT
                    INNER JOIN CIU ON COALESCE(SED.CIUDAD,TER.CIUDAD)=CIU.CIUDAD
                    LEFT  JOIN DEP ON CIU.DPTO=DEP.DPTO
            WHERE IDSEDE=@IDSEDE
             AND TER.ESTADO='Activo'

            -- Resumen por cuenta + tercero (SI desde VALOR10=1 + DB/CR/SF del per?odo)
            IF OBJECT_ID('tempdb..#RESUMEN_TERCERO') IS NOT NULL
                DROP TABLE #RESUMEN_TERCERO;

            ;WITH MOV_AGG AS (
                SELECT
                    RTRIM(r.ID1) AS CUENTA,
                    RTRIM(ISNULL(r.ID3, '')) AS IDTERCERO,
                    SUM(COALESCE(r.VALOR2, 0)) AS TOTAL_DB,
                    SUM(COALESCE(r.VALOR3, 0)) AS TOTAL_CR
                FROM RPDX2 AS r
                WHERE r.CNS = @CNS
                  AND (r.VALOR2 > 0 OR r.VALOR3 > 0)
                GROUP BY RTRIM(r.ID1), RTRIM(ISNULL(r.ID3, ''))
            ),
            CAB AS (
                SELECT
                    RTRIM(r.ID1) AS CUENTA,
                    RTRIM(ISNULL(r.ID3, '')) AS IDTERCERO,
                    RTRIM(ISNULL(r.STRINGMEDIO3, '')) AS RAZONSOCIAL,
                    RTRIM(c.NOMCUENTA) AS NOMCUENTA,
                    COALESCE(r.VALOR1, 0) AS SALDO_INICIAL,
                    CAST(CASE
                        WHEN LEFT(RTRIM(c.CUENTA), 1) IN ('2', '3', '4') THEN 1
                        ELSE 0
                    END AS BIT) AS ES_NATURALEZA_CREDITO
                FROM RPDX2 AS r
                INNER JOIN CUE AS c ON RTRIM(r.ID1) = RTRIM(c.CUENTA)
                WHERE r.CNS = @CNS
                  AND c.TIPO = 'Detalle'
                  AND r.VALOR10 = 1
            )
            SELECT
                mov.CUENTA AS ID1,
                mov.CUENTA,
                mov.IDTERCERO,
                COALESCE(cab.RAZONSOCIAL, '') AS RAZONSOCIAL,
                COALESCE(cab.NOMCUENTA, c.NOMCUENTA) AS NOMCUENTA,
                COALESCE(cab.SALDO_INICIAL, 0) AS SALDO_INICIAL,
                CAST(CASE
                    WHEN LEFT(RTRIM(mov.CUENTA), 1) IN ('2', '3', '4') THEN 1
                    ELSE 0
                END AS BIT) AS ES_NATURALEZA_CREDITO,
                mov.TOTAL_DB,
                mov.TOTAL_CR,
                CAST(
                    CASE
                        WHEN LEFT(RTRIM(mov.CUENTA), 1) IN ('2', '3', '4')
                        THEN COALESCE(cab.SALDO_INICIAL, 0) + mov.TOTAL_CR - mov.TOTAL_DB
                        ELSE COALESCE(cab.SALDO_INICIAL, 0) + mov.TOTAL_DB - mov.TOTAL_CR
                    END AS DECIMAL(18, 2)
                ) AS SALDO_FINAL
            INTO #RESUMEN_TERCERO
            FROM MOV_AGG AS mov
            INNER JOIN CUE AS c ON RTRIM(mov.CUENTA) = RTRIM(c.CUENTA) AND c.TIPO = 'Detalle'
            LEFT JOIN CAB AS cab
                ON cab.CUENTA = mov.CUENTA
               AND cab.IDTERCERO = mov.IDTERCERO;

            -- ========== Recordset 1: resumen por cuenta + tercero (SI, DB, CR, SF) ==========
            SELECT
                ID1,
                CUENTA,
                IDTERCERO,
                RAZONSOCIAL,
                NOMCUENTA,
                SALDO_INICIAL,
                ES_NATURALEZA_CREDITO,
                TOTAL_DB AS DEBITOS,
                TOTAL_CR AS CREDITOS,
                SALDO_FINAL,
                TOTAL_DB,
                TOTAL_CR
            FROM #RESUMEN_TERCERO
            WHERE @OMITIR_SALDOS_CERO_T = 0 OR SALDO_FINAL <> 0
            ORDER BY CUENTA, IDTERCERO;

            -- ========== Recordset 2: totales generales ==========
            SELECT
                CAST(SUM(SALDO_INICIAL) AS DECIMAL(18, 2)) AS TOTAL_SALDO_INICIAL,
                CAST(SUM(TOTAL_DB) AS DECIMAL(18, 2)) AS TOTAL_DB,
                CAST(SUM(TOTAL_CR) AS DECIMAL(18, 2)) AS TOTAL_CR,
                CAST(SUM(SALDO_FINAL) AS DECIMAL(18, 2)) AS TOTAL_SF
            FROM #RESUMEN_TERCERO
            WHERE @OMITIR_SALDOS_CERO_T = 0 OR SALDO_FINAL <> 0;

            DROP TABLE #RESUMEN_TERCERO;

            RETURN
        END
        IF @METODO='LIMPIAR'     
        BEGIN    
           SELECT  @cnsBalance=CNSBALANCE,@cnsAuxiliar =cnsAuxiliar   
           FROM   OPENJSON (@PARAMETROS)
           WITH (           
           cnsBalance  VARCHAR(20)   '$.cnsBalance', 
           cnsAuxiliar  VARCHAR(20)   '$.cnsAuxiliar'
           )
           IF COALESCE(@cnsBalance,'') <>''
           BEGIN
              DELETE TBALANCETERFAC WHERE CNSPRO=@cnsBalance
           END
           IF COALESCE(@cnsAuxiliar,'')<>''
           BEGIN
              DELETE RPDX2 WHERE CNS=@cnsAuxiliar
           END
           SELECT 'OK' AS OK
           RETURN
        END  
        SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'M?todo no implementado' AS MENSAJE
		
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
            
        SELECT 'RESULTADO' AS TIPO, 'KO' AS OK, 'Error: ' + ERROR_MESSAGE() AS MENSAJE, ERROR_LINE() AS ERROR_LINE
    END CATCH
END

