CREATE OR ALTER PROCEDURE DBO.SPQ_MCHE_COL
@JSON  NVARCHAR(MAX)
WITH
ENCRYPTION
AS
DECLARE @PARAMETROS         NVARCHAR(MAX)  ,@MODELO           VARCHAR(100)    ,@METODO        VARCHAR(100)  ,@USUARIO        VARCHAR(12)
        ,@GRUPO              VARCHAR(8)     ,@SYS_COMPUTERNAME VARCHAR(254)    ,@SEDE          VARCHAR(5)	   ,@A              INT
        ,@IDENTITY           INT 
        ,@PROCESO            VARCHAR(20)    ,@MCHE    NVARCHAR(MAX)
        ,@NROCOMPROBANTE     VARCHAR(20)
        ,@COMPANIA     VARCHAR(2)
        ,@NROASIENTO     INT
        ,@TIPO     VARCHAR(2)
        ,@CUENTA     VARCHAR(16)
        ,@IDTERCERO     VARCHAR(20)
        ,@CCOSTO     VARCHAR(20)
        ,@IDAREA     VARCHAR(20)
        ,@DETALLE     VARCHAR(512)
        ,@VALOR     DECIMAL(18,2) -- STORRES 20260610 SE AGRANDA TAMAÑO DE LA PARA EVITAR ERROR DE DESBORDAMIENTO
        ,@REFERENCIA1     VARCHAR(20) 
        ,@REFERENCIA2     VARCHAR(20)
        ,@REFERENCIA3     VARCHAR(20)
        ,@N_FACTURA     VARCHAR(20)
        ,@F_FACTURAREF     DATETIME
        ,@F_FACTURAREF_STR VARCHAR(10)
        ,@F_VENCE     DATETIME
        ,@F_VENCE_STR VARCHAR(10)
        ,@FECHA     DATETIME
        ,@FECHA_STR VARCHAR(10)
        ,@ERROR     VARCHAR(128)
        ,@ESTADO    INT
        ,@IDPROVEEDOR     VARCHAR(20)
        ,@ROWCOUNT  INT
        ,@ESTADO_ACTUAL INT
        ,@ERROR_ACTUAL VARCHAR(128)
        ,@NROASIENTO_EXISTENTE INT
        ,@EXISTE_DUPLICADO BIT = 0
BEGIN
    SET LANGUAGE Spanish
    SET DATEFORMAT dmy
   
    SELECT @A = ISJSON(@JSON)
    IF @A = 0
    BEGIN
        RAISERROR('Json: Formato Erroneo',16,1)
        RETURN
    END
    PRINT 'INGRESE A SPQ_MCHE'
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
   
    PRINT 'USUARIO:'+@USUARIO
    IF COALESCE(@SEDE,'') = '' SELECT @SEDE = '01'
    PRINT 'SEDE='+@SEDE
   
	IF @METODO = 'CRUDMCHE'
    BEGIN
        PRINT 'CRUDMCHE'
        SELECT @MCHE  = REGISTRO
        FROM OPENJSON (@PARAMETROS)
        WITH(
            REGISTRO   NVARCHAR(MAX)     AS JSON
        )
      
        DECLARE @NROCOMPROBANTE_TEMP VARCHAR(20) = JSON_VALUE(@MCHE , '$.NROCOMPROBANTE' )
        SELECT @PROCESO     = JSON_VALUE(@MCHE ,'$.PROCESO')
      
        IF @NROCOMPROBANTE_TEMP IS NOT NULL AND LTRIM(RTRIM(@NROCOMPROBANTE_TEMP)) != ''
        BEGIN
            DECLARE @DUPLICADOS_COMPROBANTE INT = 0
            DECLARE @TOTAL_REGISTROS INT = 0
            DECLARE @REGISTROS_UNICOS INT = 0
            DECLARE @DUPLICADOS_ELIMINADOS_INICIAL INT = 0
            DECLARE @ITERACION_INICIAL INT = 0
            DECLARE @MAX_ITERACIONES_INICIAL INT = 100
            DECLARE @DUPLICADOS_RESTANTES_INICIAL INT = 1
         
            PRINT ' ========== VALIDACIÓN INICIAL ULTRA-AGRESIVA: ELIMINANDO TODOS LOS DUPLICADOS en comprobante ' + @NROCOMPROBANTE_TEMP + ' =========='
         
            WHILE @DUPLICADOS_RESTANTES_INICIAL > 0 AND @ITERACION_INICIAL < @MAX_ITERACIONES_INICIAL
            BEGIN
            SET @ITERACION_INICIAL = @ITERACION_INICIAL + 1
            
            SELECT @TOTAL_REGISTROS = COUNT(*)
            FROM MCHE
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_TEMP
            
            IF @TOTAL_REGISTROS = 0
            BEGIN
                PRINT ' No hay registros en el comprobante. Limpieza completada.'
                BREAK
            END
            
            SELECT @REGISTROS_UNICOS = COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
            FROM MCHE
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE_TEMP
            AND CUENTA IS NOT NULL
            AND TIPO IS NOT NULL
            AND VALOR IS NOT NULL
            
            SET @DUPLICADOS_COMPROBANTE = @TOTAL_REGISTROS - @REGISTROS_UNICOS
            SET @DUPLICADOS_RESTANTES_INICIAL = @DUPLICADOS_COMPROBANTE
            
            IF @DUPLICADOS_COMPROBANTE = 0
            BEGIN
                IF @ITERACION_INICIAL = 1
                BEGIN
                    PRINT ' VALIDACIÓN INICIAL: No se detectaron duplicados en el comprobante ' + @NROCOMPROBANTE_TEMP
                END
                ELSE
                BEGIN
                    PRINT ' Iteración ' + CAST(@ITERACION_INICIAL AS VARCHAR) + ': OK - Todos los duplicados eliminados.'
                END
                BREAK
            END
            
            IF @ITERACION_INICIAL = 1
            BEGIN
                PRINT ' VALIDACIÓN INICIAL: Total=' + CAST(@TOTAL_REGISTROS AS VARCHAR) + ' | Únicos=' + CAST(@REGISTROS_UNICOS AS VARCHAR) + ' | Duplicados=' + CAST(@DUPLICADOS_COMPROBANTE AS VARCHAR)
            END
            
            PRINT ' Iteración ' + CAST(@ITERACION_INICIAL AS VARCHAR) + ': ELIMINANDO ' + CAST(@DUPLICADOS_COMPROBANTE AS VARCHAR) + ' duplicado(s)...'
            
            DELETE m1
            FROM MCHE m1
            WHERE EXISTS (
                SELECT 1
                FROM (
                    SELECT NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01') AS COMPANIA, MIN(NROASIENTO) AS MIN_NROASIENTO
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE_TEMP
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
            
            SET @DUPLICADOS_ELIMINADOS_INICIAL = @DUPLICADOS_ELIMINADOS_INICIAL + @@ROWCOUNT
            
            IF @@ROWCOUNT = 0
            BEGIN
                PRINT ' Iteración ' + CAST(@ITERACION_INICIAL AS VARCHAR) + ': No se eliminaron registros. Verificando estado final...'
               
                SELECT @TOTAL_REGISTROS = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE_TEMP
               
                SELECT @REGISTROS_UNICOS = COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE_TEMP
                AND CUENTA IS NOT NULL
                AND TIPO IS NOT NULL
                AND VALOR IS NOT NULL
               
                SET @DUPLICADOS_RESTANTES_INICIAL = @TOTAL_REGISTROS - @REGISTROS_UNICOS
               
                IF @DUPLICADOS_RESTANTES_INICIAL = 0
                BEGIN
                    PRINT ' VERIFICACIÓN FINAL: OK - No quedan duplicados.'
                END
                ELSE
                BEGIN
                    PRINT ' ADVERTENCIA: Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_INICIAL AS VARCHAR) + ' duplicado(s). Continuando...'
                END
            END
            ELSE
            BEGIN
                PRINT ' Iteración ' + CAST(@ITERACION_INICIAL AS VARCHAR) + ' completada: Se eliminaron ' + CAST(@@ROWCOUNT AS VARCHAR) + ' duplicado(s)'
            END
            END
         
            IF @DUPLICADOS_ELIMINADOS_INICIAL > 0
            BEGIN
            PRINT ' ========== LIMPIEZA PREVIA COMPLETADA: Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS_INICIAL AS VARCHAR) + ' duplicado(s) del comprobante ' + @NROCOMPROBANTE_TEMP + ' en ' + CAST(@ITERACION_INICIAL AS VARCHAR) + ' iteración(es) =========='
            END
         
            IF @DUPLICADOS_RESTANTES_INICIAL > 0 AND @ITERACION_INICIAL >= @MAX_ITERACIONES_INICIAL
            BEGIN
                PRINT ' ========== ERROR CRÍTICO: Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_INICIAL AS VARCHAR) + ' duplicado(s) después de ' + CAST(@MAX_ITERACIONES_INICIAL AS VARCHAR) + ' iteraciones. Se requiere revisión manual inmediata. =========='
            END
            ELSE IF @DUPLICADOS_RESTANTES_INICIAL = 0
            BEGIN
                PRINT ' ========== VALIDACIÓN INICIAL: OK - No quedan duplicados en el comprobante ' + @NROCOMPROBANTE_TEMP + ' =========='
            END
        END

        SELECT @NROCOMPROBANTE = JSON_VALUE(@MCHE , '$.NROCOMPROBANTE' )
        SELECT @COMPANIA = JSON_VALUE(@MCHE , '$.COMPANIA' )
        SELECT @NROASIENTO = JSON_VALUE(@MCHE , '$.NROASIENTO' )
        SELECT @TIPO = JSON_VALUE(@MCHE , '$.TIPO' )
        SELECT @CUENTA = JSON_VALUE(@MCHE , '$.CUENTA' )
        SELECT @IDTERCERO = JSON_VALUE(@MCHE , '$.IDTERCERO' )
        SELECT @CCOSTO = JSON_VALUE(@MCHE , '$.CCOSTO' )
        SELECT @IDAREA = JSON_VALUE(@MCHE , '$.IDAREA' )
        SELECT @DETALLE = JSON_VALUE(@MCHE , '$.DETALLE' )
        SELECT @VALOR = CAST(JSON_VALUE(@MCHE , '$.VALOR' ) AS DECIMAL(18,2)) -- STORRES 20260610 SE AGRANDA TAMAÑO DE EL CAST PARA EVITAR ERROR DE DESBORDAMIENTO
        SELECT @REFERENCIA1 = JSON_VALUE(@MCHE , '$.REFERENCIA1' )
        SELECT @REFERENCIA2 = JSON_VALUE(@MCHE , '$.REFERENCIA2' )
        SELECT @REFERENCIA3 = JSON_VALUE(@MCHE , '$.REFERENCIA3' )
        SELECT @N_FACTURA = JSON_VALUE(@MCHE , '$.N_FACTURA' )
        SELECT @IDPROVEEDOR = JSON_VALUE(@MCHE , '$.IDPROVEEDOR' )
        SELECT @USUARIO = COALESCE(JSON_VALUE(@MCHE , '$.USUARIO'), @USUARIO)
        SELECT @F_FACTURAREF_STR = JSON_VALUE(@MCHE , '$.F_FACTURAREF')
        IF @F_FACTURAREF_STR IS NOT NULL AND LTRIM(RTRIM(@F_FACTURAREF_STR)) != ''
            SELECT @F_FACTURAREF = CONVERT(DATE, SUBSTRING(@F_FACTURAREF_STR,9,2)+'/'+SUBSTRING(@F_FACTURAREF_STR,6,2)+'/'+SUBSTRING(@F_FACTURAREF_STR,1,4))
      
        SELECT @F_VENCE_STR = JSON_VALUE(@MCHE , '$.F_VENCE')
        IF @F_VENCE_STR IS NOT NULL AND LTRIM(RTRIM(@F_VENCE_STR)) != ''
            SELECT @F_VENCE = CONVERT(DATE, SUBSTRING(@F_VENCE_STR,9,2)+'/'+SUBSTRING(@F_VENCE_STR,6,2)+'/'+SUBSTRING(@F_VENCE_STR,1,4))
      
        SELECT @FECHA_STR = JSON_VALUE(@MCHE , '$.FECHA')
        IF @FECHA_STR IS NOT NULL AND LTRIM(RTRIM(@FECHA_STR)) != ''
            SELECT @FECHA = CONVERT(DATE, SUBSTRING(@FECHA_STR,9,2)+'/'+SUBSTRING(@FECHA_STR,6,2)+'/'+SUBSTRING(@FECHA_STR,1,4))
        ELSE
            SELECT @FECHA = GETDATE()
      
        IF @COMPANIA IS NULL OR LTRIM(RTRIM(@COMPANIA)) = '' SELECT @COMPANIA = '01'
      
        IF @CUENTA IS NOT NULL SET @CUENTA = LTRIM(RTRIM(@CUENTA))
        IF @CCOSTO IS NOT NULL SET @CCOSTO = LTRIM(RTRIM(@CCOSTO))
        IF @IDAREA IS NOT NULL SET @IDAREA = LTRIM(RTRIM(@IDAREA))
        IF @IDTERCERO IS NOT NULL SET @IDTERCERO = LTRIM(RTRIM(@IDTERCERO))
        IF @IDPROVEEDOR IS NOT NULL SET @IDPROVEEDOR = LTRIM(RTRIM(@IDPROVEEDOR))
      
        IF @CCOSTO IS NOT NULL AND @CCOSTO != '' 
            AND (@IDAREA IS NULL OR @IDAREA = '')
        BEGIN
            SELECT @IDAREA = IDAREA 
            FROM CEN 
            WHERE CCOSTO = @CCOSTO
         
            IF @IDAREA IS NOT NULL SET @IDAREA = LTRIM(RTRIM(@IDAREA))
            IF @IDAREA = '' SET @IDAREA = NULL
        END
      
        IF UPPER(@PROCESO) = 'EDITAR' OR UPPER(@PROCESO) = 'INSERTAR'
        BEGIN
            DECLARE @ESTADO_ENVIADO INT = CAST(JSON_VALUE(@MCHE , '$.ESTADO' ) AS INT)
         
            SET @ERROR = NULL
            SET @ESTADO = 0
         
            IF @CUENTA IS NULL OR @CUENTA = ''
            BEGIN
                SET @ERROR = 'ERROR       : La Cuenta NO Existe.'
                SET @ESTADO = 0
                PRINT 'Validación: Cuenta vacía - ERROR presente, ESTADO = 0'
            END
            ELSE IF EXISTS(SELECT 1 FROM CUE WHERE CUE.CUENTA = @CUENTA AND CUE.ESTADO = 'Activa')
            BEGIN
                SET @ERROR = NULL
                IF @ESTADO_ENVIADO = 1
                BEGIN
                    SET @ESTADO = 1
                    PRINT 'Validación: Cuenta ' + @CUENTA + ' existe y está activa - ERROR = NULL, ESTADO = 1 (respetando valor enviado)'
                END
                ELSE
                BEGIN
                    SET @ESTADO = 1
                    PRINT 'Validación: Cuenta ' + @CUENTA + ' existe y está activa - ERROR = NULL, ESTADO = 1'
                END
            END
            ELSE
            BEGIN
                SET @ERROR = 'ERROR       : La Cuenta NO Existe.'
                SET @ESTADO = 0
                PRINT 'Validación: Cuenta ' + @CUENTA + ' NO existe o NO está activa - ERROR presente, ESTADO = 0'
            END
         
            IF (@ERROR IS NOT NULL AND @ERROR != '') AND @ESTADO != 0
            BEGIN
                SET @ESTADO = 0
                PRINT ' FORZADO: ERROR presente pero ESTADO != 0. FORZANDO ESTADO = 0'
            END
            IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO_ENVIADO = 1
            BEGIN
                SET @ESTADO = 1
                PRINT ' RESPETADO: ERROR = NULL y ESTADO = 1 enviado explícitamente. MANTENIENDO ESTADO = 1'
            END
            IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO_ENVIADO IS NULL
            BEGIN
                SET @ESTADO = 1
                PRINT ' FORZADO: ERROR = NULL, estableciendo ESTADO = 1'
            END
        END
        ELSE
        BEGIN
            SET @ESTADO = CAST(JSON_VALUE(@MCHE , '$.ESTADO' ) AS INT)
            IF @ESTADO IS NULL SET @ESTADO = 0
            SET @ERROR = JSON_VALUE(@MCHE , '$.ERROR' )
        END
      
        IF @ESTADO IS NULL SET @ESTADO = 0
      
        IF UPPER(@PROCESO) = 'EDITAR' OR UPPER(@PROCESO) = 'INSERTAR'
        BEGIN
            IF (@ERROR IS NOT NULL AND @ERROR != '') AND @ESTADO != 0
            BEGIN
                SET @ESTADO = 0
                PRINT 'CORRECCIÓN: ERROR presente pero ESTADO != 0. Ajustando ESTADO = 0'
            END
            ELSE IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO != 1
            BEGIN
                SET @ESTADO = 1
                PRINT 'CORRECCIÓN: ERROR = NULL pero ESTADO != 1. Ajustando ESTADO = 1'
            END
        END
      
        PRINT 'Proceso: ' + ISNULL(@PROCESO, 'NULL') + ' | CUENTA: ' + ISNULL(@CUENTA, 'NULL') + ' | CCOSTO: ' + ISNULL(@CCOSTO, 'NULL') + ' | IDAREA: ' + ISNULL(@IDAREA, 'NULL') + ' | ESTADO: ' + CAST(@ESTADO AS VARCHAR) + ' | ERROR: ' + ISNULL(@ERROR, 'NULL')
      
        IF UPPER(@PROCESO) = 'INSERTAR'
        BEGIN
            PRINT ' ========== INSERTAR MCHE - ESTRATEGIA UPSERT: SIEMPRE ACTUALIZAR SI EXISTE, INSERTAR SOLO SI NO EXISTE =========='
         
            SET @EXISTE_DUPLICADO = 0
            SET @NROASIENTO_EXISTENTE = NULL
         
            DECLARE @CANTIDAD_DUPLICADOS INT = 0
            DECLARE @NROASIENTO_PRIMERO INT = NULL
         
            IF @COMPANIA IS NULL OR LTRIM(RTRIM(@COMPANIA)) = '' 
            SET @COMPANIA = '01'
         
            IF @NROCOMPROBANTE IS NULL OR LTRIM(RTRIM(@NROCOMPROBANTE)) = ''
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) SELECT 'NROCOMPROBANTE es obligatorio y no puede estar vacío'
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
         
            IF @CUENTA IS NULL OR LTRIM(RTRIM(@CUENTA)) = ''
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) SELECT 'CUENTA es obligatoria y no puede estar vacía'
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
         
            IF @TIPO IS NULL OR LTRIM(RTRIM(@TIPO)) = ''
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) SELECT 'TIPO es obligatorio y no puede estar vacío'
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
         
            IF @VALOR IS NULL
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) SELECT 'VALOR es obligatorio y no puede estar vacío'
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
         
            PRINT ' ========== VALIDACIÓN UPSERT ULTRA-ESTRICTA: Verificando si existe registro con NROCOMPROBANTE=' + @NROCOMPROBANTE + ', CUENTA=' + @CUENTA + ', TIPO=' + @TIPO + ', VALOR=' + CAST(@VALOR AS VARCHAR) + ', COMPANIA=' + ISNULL(@COMPANIA, '01') + ' =========='
         
            DECLARE @VERIFICACIONES_UPSERT INT = 0
            DECLARE @MAX_VERIFICACIONES_UPSERT INT = 3
         
            WHILE @VERIFICACIONES_UPSERT < @MAX_VERIFICACIONES_UPSERT
            BEGIN
                SET @VERIFICACIONES_UPSERT = @VERIFICACIONES_UPSERT + 1
            
                SELECT @CANTIDAD_DUPLICADOS = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    AND CUENTA = @CUENTA
                    AND TIPO = @TIPO
                    AND ABS(VALOR - @VALOR) < 0.01
                    AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
            
                IF @CANTIDAD_DUPLICADOS = 0
                BEGIN
                    PRINT ' Verificación ' + CAST(@VERIFICACIONES_UPSERT AS VARCHAR) + ': OK - No se detectaron duplicados. Procediendo con inserción.'
                    BREAK
                END
            
                PRINT ' Verificación ' + CAST(@VERIFICACIONES_UPSERT AS VARCHAR) + ': DUPLICADO DETECTADO - Existen ' + CAST(@CANTIDAD_DUPLICADOS AS VARCHAR) + ' registro(s) con la misma combinación.'
            
                IF @CANTIDAD_DUPLICADOS > 0
                BEGIN
                    SELECT TOP 1 @NROASIENTO_EXISTENTE = NROASIENTO
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                    ORDER BY NROASIENTO ASC
            
                    SET @NROASIENTO_PRIMERO = @NROASIENTO_EXISTENTE
            
                    PRINT ' ========== DUPLICADO DETECTADO ANTES DE INSERTAR: Ya existe ' + CAST(@CANTIDAD_DUPLICADOS AS VARCHAR) + ' registro(s) con la misma combinación. NROASIENTO existente=' + CAST(@NROASIENTO_EXISTENTE AS VARCHAR) + ' =========='
            
                    IF @CANTIDAD_DUPLICADOS > 1
                    BEGIN
                        PRINT ' ELIMINANDO ' + CAST((@CANTIDAD_DUPLICADOS - 1) AS VARCHAR) + ' registro(s) duplicado(s) adicional(es) ANTES de actualizar...'
               
                        DECLARE @ITERACION_ELIMINACION INT = 0
                        DECLARE @MAX_ITERACIONES_ELIMINACION INT = 10
                        DECLARE @DUPLICADOS_RESTANTES_ELIMINACION INT = @CANTIDAD_DUPLICADOS - 1
               
                        WHILE @DUPLICADOS_RESTANTES_ELIMINACION > 0 AND @ITERACION_ELIMINACION < @MAX_ITERACIONES_ELIMINACION
                        BEGIN
                            SET @ITERACION_ELIMINACION = @ITERACION_ELIMINACION + 1
                  
                            DELETE FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                            AND CUENTA = @CUENTA
                            AND TIPO = @TIPO
                            AND ABS(VALOR - @VALOR) < 0.01
                            AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                            AND NROASIENTO != @NROASIENTO_EXISTENTE
                  
                            DECLARE @ELIMINADOS_ITERACION INT = @@ROWCOUNT
                  
                            IF @ELIMINADOS_ITERACION = 0
                                BREAK
                  
                            DECLARE @VERIFICACION_POST_DELETE_ITERACION INT = 0
                            SELECT @VERIFICACION_POST_DELETE_ITERACION = COUNT(*)
                            FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                            AND CUENTA = @CUENTA
                            AND TIPO = @TIPO
                            AND ABS(VALOR - @VALOR) < 0.01
                            AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                            AND NROASIENTO != @NROASIENTO_EXISTENTE
                  
                            SET @DUPLICADOS_RESTANTES_ELIMINACION = @VERIFICACION_POST_DELETE_ITERACION
                  
                            IF @DUPLICADOS_RESTANTES_ELIMINACION = 0
                            BEGIN
                                PRINT ' Iteración ' + CAST(@ITERACION_ELIMINACION AS VARCHAR) + ': Todos los duplicados eliminados. Se mantiene el registro con NROASIENTO=' + CAST(@NROASIENTO_EXISTENTE AS VARCHAR)
                                BREAK
                            END
                            ELSE
                            BEGIN
                                PRINT ' Iteración ' + CAST(@ITERACION_ELIMINACION AS VARCHAR) + ': Se eliminaron ' + CAST(@ELIMINADOS_ITERACION AS VARCHAR) + ' duplicado(s). Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_ELIMINACION AS VARCHAR) + ' duplicado(s).'
                            END
                        END
               
                        IF @DUPLICADOS_RESTANTES_ELIMINACION > 0
                        BEGIN
                            PRINT ' ADVERTENCIA: Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_ELIMINACION AS VARCHAR) + ' duplicado(s) después de ' + CAST(@MAX_ITERACIONES_ELIMINACION AS VARCHAR) + ' iteraciones.'
                        END
                    END
            
                    SET @EXISTE_DUPLICADO = 1
                    SET @NROASIENTO = @NROASIENTO_EXISTENTE
                    SET @PROCESO = 'EDITAR'
                    PRINT ' ========== UPSERT: Duplicado detectado. Cambiando a UPDATE. Se actualizará el registro existente NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR) + ' en lugar de insertar =========='
                    BREAK
                END
            END
         
            IF @EXISTE_DUPLICADO = 0
            BEGIN
                PRINT ' VALIDACIÓN UPSERT: No se encontraron duplicados después de ' + CAST(@VERIFICACIONES_UPSERT AS VARCHAR) + ' verificación(es). Procediendo con inserción.'
            END
         
            IF @EXISTE_DUPLICADO = 0
            BEGIN
                PRINT ' VERIFICACIÓN FINAL PRE-INSERT: Ejecutando verificación ULTRA-ESTRICTA una vez más antes de insertar...'
            
                SELECT @CANTIDAD_DUPLICADOS = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    AND CUENTA = @CUENTA
                    AND TIPO = @TIPO
                    AND ABS(VALOR - @VALOR) < 0.01
                    AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
            
                IF @CANTIDAD_DUPLICADOS > 0
                BEGIN
                    SELECT TOP 1 @NROASIENTO_EXISTENTE = NROASIENTO
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                    ORDER BY NROASIENTO ASC
               
                    PRINT ' DUPLICADO DETECTADO EN VERIFICACIÓN FINAL: Cambiando a UPDATE. NROASIENTO=' + CAST(@NROASIENTO_EXISTENTE AS VARCHAR)
               
                    IF @CANTIDAD_DUPLICADOS > 1
                    BEGIN
                        DELETE FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        AND NROASIENTO != @NROASIENTO_EXISTENTE
                  
                        PRINT ' Se eliminaron ' + CAST(@@ROWCOUNT AS VARCHAR) + ' duplicado(s) adicional(es).'
                    END
               
                    SET @EXISTE_DUPLICADO = 1
                    SET @NROASIENTO = @NROASIENTO_EXISTENTE
                    SET @PROCESO = 'EDITAR'
                END
            END
         
            IF @EXISTE_DUPLICADO = 1
            BEGIN
                PRINT 'ACTUALIZANDO registro existente (anti-duplicado): NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
                BEGIN TRY
                    IF (@ERROR IS NOT NULL AND @ERROR != '') AND @ESTADO != 0
                    BEGIN
                        SET @ESTADO = 0
                        PRINT ' PRE-UPDATE: ERROR presente pero ESTADO != 0. FORZANDO ESTADO = 0'
                    END
                    ELSE IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO != 1 AND (@ESTADO_ENVIADO IS NULL OR @ESTADO_ENVIADO = 1)
                    BEGIN
                        SET @ESTADO = 1
                        PRINT ' PRE-UPDATE: ERROR = NULL pero ESTADO != 1. FORZANDO ESTADO = 1'
                    END
               
                    PRINT ' ANTES DEL UPDATE (anti-duplicado): ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL') + ' | CUENTA=' + ISNULL(@CUENTA, 'NULL') + ' | DETALLE=' + ISNULL(@DETALLE, 'NULL') + ' | NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
               
                    UPDATE MCHE SET
                            NROCOMPROBANTE = @NROCOMPROBANTE,
                            COMPANIA = @COMPANIA,
                            TIPO = @TIPO,
                            CUENTA = @CUENTA,
                            IDTERCERO = @IDTERCERO,
                            CCOSTO = NULLIF(@CCOSTO, ''),
                            IDAREA = NULLIF(@IDAREA, ''),
                            DETALLE = @DETALLE,
                            VALOR = @VALOR,
                            REFERENCIA1 = NULLIF(@REFERENCIA1, ''),
                            REFERENCIA2 = NULLIF(@REFERENCIA2, ''),
                            REFERENCIA3 = NULLIF(@REFERENCIA3, ''),
                            N_FACTURA = NULLIF(@N_FACTURA, ''),
                            F_FACTURAREF = @F_FACTURAREF,
                            F_VENCE = @F_VENCE,
                            USUARIO = @USUARIO,
                            FECHA = @FECHA,
                            ERROR = NULLIF(@ERROR, ''),
                            ESTADO = @ESTADO,
                            IDPROVEEDOR = NULLIF(@IDPROVEEDOR, '')
                    WHERE NROASIENTO = @NROASIENTO
               
                    SET @ROWCOUNT = @@ROWCOUNT
                    PRINT ' UPDATE ejecutado (anti-duplicado): ROWCOUNT=' + CAST(@ROWCOUNT AS VARCHAR) + ' | ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL')
               
                    SELECT @ESTADO_ACTUAL = ESTADO, @ERROR_ACTUAL = ERROR 
                    FROM MCHE 
                    WHERE NROASIENTO = @NROASIENTO
               
                    IF @ROWCOUNT = 0
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) SELECT 'No se encontró el registro con NROASIENTO: ' + CAST(@NROASIENTO AS VARCHAR)
                    END
               
                    DECLARE @DUPLICADOS_POST_UPDATE INT = 0
                    SELECT @DUPLICADOS_POST_UPDATE = COUNT(*)
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        AND NROASIENTO != @NROASIENTO
               
                    IF @DUPLICADOS_POST_UPDATE > 0
                    BEGIN
                        PRINT ' VERIFICACIÓN POST-UPDATE: Se detectaron ' + CAST(@DUPLICADOS_POST_UPDATE AS VARCHAR) + ' duplicado(s) después de actualizar. Eliminando...'
                  
                        DELETE FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        AND NROASIENTO != @NROASIENTO
                  
                        PRINT ' Duplicados post-update eliminados. Se mantiene el registro con NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
                    END
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
                END CATCH
                IF (SELECT COUNT(*) FROM @TBLERRORES)> 0
                BEGIN
                    SELECT 'KO' OK
                    SELECT ERROR FROM @TBLERRORES
                    RETURN
                END
                SELECT 'OK' OK, @NROASIENTO CNS
                RETURN
            END
            ELSE
            BEGIN
                PRINT 'INSERTAR MCHE (nuevo registro) - UPSERT: Solo inserta si NO existe duplicado'
                BEGIN TRY
                    PRINT ' ========== VERIFICACIÓN ULTRA-FINAL PRE-INSERT: Verificación ABSOLUTA justo antes de INSERTAR =========='
               
                    DECLARE @DUPLICADO_ULTRA_FINAL INT = 0
                    DECLARE @NROASIENTO_ULTRA_FINAL INT = NULL
               
                    SELECT @DUPLICADO_ULTRA_FINAL = COUNT(*)
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
               
                    IF @DUPLICADO_ULTRA_FINAL > 0
                    BEGIN
                        SELECT TOP 1 @NROASIENTO_ULTRA_FINAL = NROASIENTO
                        FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        ORDER BY NROASIENTO ASC
                  
                        PRINT ' ========== ERROR CRÍTICO: DUPLICADO DETECTADO JUSTO ANTES DE INSERTAR. NUNCA se insertará. Cambiando a UPDATE. NROASIENTO=' + CAST(@NROASIENTO_ULTRA_FINAL AS VARCHAR) + ' =========='
                  
                        IF @DUPLICADO_ULTRA_FINAL > 1
                        BEGIN
                            DELETE FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                            AND CUENTA = @CUENTA
                            AND TIPO = @TIPO
                            AND ABS(VALOR - @VALOR) < 0.01
                            AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                            AND NROASIENTO != @NROASIENTO_ULTRA_FINAL
                     
                            PRINT ' Se eliminaron ' + CAST(@@ROWCOUNT AS VARCHAR) + ' duplicado(s) adicional(es) antes de actualizar.'
                        END
                  
                        SET @EXISTE_DUPLICADO = 1
                        SET @NROASIENTO = @NROASIENTO_ULTRA_FINAL
                        SET @PROCESO = 'EDITAR'
                  
                        PRINT ' ========== BLOQUEANDO INSERT: Se detectó duplicado. NUNCA se insertará. Solo se actualizará NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR) + ' =========='
                    END
               
                    IF @EXISTE_DUPLICADO = 0
                    BEGIN
                        INSERT INTO MCHE(
                            NROCOMPROBANTE, COMPANIA, TIPO, CUENTA, IDTERCERO, CCOSTO, IDAREA, DETALLE,
                            VALOR, REFERENCIA1, REFERENCIA2, REFERENCIA3, N_FACTURA, F_FACTURAREF, F_VENCE,
                            USUARIO, FECHA, ERROR, ESTADO, IDPROVEEDOR
                        )
                        VALUES(
                            @NROCOMPROBANTE, @COMPANIA, @TIPO, @CUENTA, @IDTERCERO, NULLIF(@CCOSTO, ''), NULLIF(@IDAREA, ''), @DETALLE,
                            @VALOR, NULLIF(@REFERENCIA1, ''), NULLIF(@REFERENCIA2, ''), NULLIF(@REFERENCIA3, ''), NULLIF(@N_FACTURA, ''), @F_FACTURAREF, @F_VENCE,
                            @USUARIO, @FECHA, NULLIF(@ERROR, ''), @ESTADO, NULLIF(@IDPROVEEDOR, '')
                        )
                        SELECT @IDENTITY = SCOPE_IDENTITY()
                  
                        PRINT ' INSERT ejecutado: IDENTITY=' + CAST(@IDENTITY AS VARCHAR) + ' | ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL')
                  
                        IF @IDENTITY IS NOT NULL
                        BEGIN
                            DECLARE @DUPLICADOS_POST_INSERT INT = 0
                            DECLARE @DUPLICADOS_ELIMINADOS_POST INT = 0
                            DECLARE @ITERACION_POST_INSERT INT = 0
                            DECLARE @MAX_ITERACIONES_POST_INSERT INT = 10
                     
                            PRINT ' VERIFICACIÓN POST-INSERT OBLIGATORIA: Verificando duplicados después de insertar NROASIENTO=' + CAST(@IDENTITY AS VARCHAR)
                     
                            WHILE @ITERACION_POST_INSERT < @MAX_ITERACIONES_POST_INSERT
                            BEGIN
                            SET @ITERACION_POST_INSERT = @ITERACION_POST_INSERT + 1
                        
                            SELECT @DUPLICADOS_POST_INSERT = COUNT(*)
                            FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                                AND CUENTA = @CUENTA
                                AND TIPO = @TIPO
                                AND ABS(VALOR - @VALOR) < 0.01
                                AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        
                            IF @DUPLICADOS_POST_INSERT <= 1
                            BEGIN
                                PRINT ' Iteración ' + CAST(@ITERACION_POST_INSERT AS VARCHAR) + ': OK - No se detectaron duplicados después de insertar.'
                                BREAK
                            END
                        
                            PRINT ' Iteración ' + CAST(@ITERACION_POST_INSERT AS VARCHAR) + ': ERROR CRÍTICO - Se detectaron ' + CAST(@DUPLICADOS_POST_INSERT AS VARCHAR) + ' registros duplicados después de insertar. Eliminando todos excepto el recién insertado...'
                        
                            DELETE FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                                AND CUENTA = @CUENTA
                                AND TIPO = @TIPO
                                AND ABS(VALOR - @VALOR) < 0.01
                                AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                                AND NROASIENTO != @IDENTITY
                        
                            SET @DUPLICADOS_ELIMINADOS_POST = @DUPLICADOS_ELIMINADOS_POST + @@ROWCOUNT
                        
                            IF @@ROWCOUNT = 0
                            BEGIN
                                PRINT ' Iteración ' + CAST(@ITERACION_POST_INSERT AS VARCHAR) + ': No se eliminaron registros. Verificando...'
                                BREAK
                            END
                            ELSE
                            BEGIN
                                PRINT ' Iteración ' + CAST(@ITERACION_POST_INSERT AS VARCHAR) + ' completada: Se eliminaron ' + CAST(@@ROWCOUNT AS VARCHAR) + ' duplicado(s). Se mantiene NROASIENTO=' + CAST(@IDENTITY AS VARCHAR)
                            END
                            END
                     
                            IF @DUPLICADOS_ELIMINADOS_POST > 0
                            BEGIN
                            PRINT ' CORRECCIÓN POST-INSERT COMPLETADA: Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS_POST AS VARCHAR) + ' duplicado(s) en ' + CAST(@ITERACION_POST_INSERT AS VARCHAR) + ' iteración(es). Se mantiene el registro con NROASIENTO=' + CAST(@IDENTITY AS VARCHAR)
                            END
                            ELSE
                            BEGIN
                            PRINT ' VERIFICACIÓN POST-INSERT: OK - No se detectaron duplicados. Registro insertado correctamente.'
                            END
                        END
                    END
                    ELSE
                    BEGIN
                        PRINT ' SE DETECTÓ DUPLICADO EN VERIFICACIÓN FINAL PRE-INSERT. Ejecutando UPDATE en lugar de INSERT para NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
                  
                        IF (@ERROR IS NOT NULL AND @ERROR != '') AND @ESTADO != 0
                        BEGIN
                            SET @ESTADO = 0
                            PRINT ' PRE-UPDATE: ERROR presente pero ESTADO != 0. FORZANDO ESTADO = 0'
                        END
                        ELSE IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO != 1 AND (@ESTADO_ENVIADO IS NULL OR @ESTADO_ENVIADO = 1)
                        BEGIN
                            SET @ESTADO = 1
                            PRINT ' PRE-UPDATE: ERROR = NULL pero ESTADO != 1. FORZANDO ESTADO = 1'
                        END
                  
                        UPDATE MCHE SET
                                NROCOMPROBANTE = @NROCOMPROBANTE,
                                COMPANIA = @COMPANIA,
                                TIPO = @TIPO,
                                CUENTA = @CUENTA,
                                IDTERCERO = @IDTERCERO,
                                CCOSTO = NULLIF(@CCOSTO, ''),
                                IDAREA = NULLIF(@IDAREA, ''),
                                DETALLE = @DETALLE,
                                VALOR = @VALOR,
                                REFERENCIA1 = NULLIF(@REFERENCIA1, ''),
                                REFERENCIA2 = NULLIF(@REFERENCIA2, ''),
                                REFERENCIA3 = NULLIF(@REFERENCIA3, ''),
                                N_FACTURA = NULLIF(@N_FACTURA, ''),
                                F_FACTURAREF = @F_FACTURAREF,
                                F_VENCE = @F_VENCE,
                                USUARIO = @USUARIO,
                                FECHA = @FECHA,
                                ERROR = NULLIF(@ERROR, ''),
                                ESTADO = @ESTADO,
                                IDPROVEEDOR = NULLIF(@IDPROVEEDOR, '')
                        WHERE NROASIENTO = @NROASIENTO
                  
                        SET @ROWCOUNT = @@ROWCOUNT
                        PRINT ' UPDATE ejecutado (duplicado detectado en pre-insert): ROWCOUNT=' + CAST(@ROWCOUNT AS VARCHAR) + ' | ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL')
                  
                        DECLARE @DUPLICADOS_POST_UPDATE_FINAL INT = 0
                        SELECT @DUPLICADOS_POST_UPDATE_FINAL = COUNT(*)
                        FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                        AND CUENTA = @CUENTA
                        AND TIPO = @TIPO
                        AND ABS(VALOR - @VALOR) < 0.01
                        AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                        AND NROASIENTO != @NROASIENTO
                  
                        IF @DUPLICADOS_POST_UPDATE_FINAL > 0
                        BEGIN
                            PRINT ' VERIFICACIÓN POST-UPDATE FINAL: Se detectaron ' + CAST(@DUPLICADOS_POST_UPDATE_FINAL AS VARCHAR) + ' duplicado(s) después de actualizar. Eliminando...'
                     
                            DELETE FROM MCHE
                            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                            AND CUENTA = @CUENTA
                            AND TIPO = @TIPO
                            AND ABS(VALOR - @VALOR) < 0.01
                            AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                            AND NROASIENTO != @NROASIENTO
                     
                            PRINT ' Duplicados post-update final eliminados. Se mantiene el registro con NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
                        END
                  
                        SET @IDENTITY = @NROASIENTO
                    END
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
                END CATCH
                IF (SELECT COUNT(*) FROM @TBLERRORES)> 0
                BEGIN
                    SELECT 'KO' OK
                    SELECT ERROR FROM @TBLERRORES
                    RETURN
                END
                SELECT 'OK' OK ,@IDENTITY CNS 
                RETURN
            END
        END
      
        IF UPPER(@PROCESO) = 'EDITAR'
        BEGIN
            PRINT 'EDITAR MCHE'
            BEGIN TRY
            DECLARE @DUPLICADOS_ANTES_EDITAR INT = 0
            
            IF @NROCOMPROBANTE IS NOT NULL AND @CUENTA IS NOT NULL AND @TIPO IS NOT NULL AND @VALOR IS NOT NULL
            BEGIN
                IF @COMPANIA IS NULL OR LTRIM(RTRIM(@COMPANIA)) = '' 
                    SET @COMPANIA = '01'
               
                SELECT @DUPLICADOS_ANTES_EDITAR = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    AND CUENTA = @CUENTA
                    AND TIPO = @TIPO
                    AND ABS(VALOR - @VALOR) < 0.01
                    AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                    AND NROASIENTO != @NROASIENTO
               
                IF @DUPLICADOS_ANTES_EDITAR > 0
                BEGIN
                    PRINT ' ADVERTENCIA: Existen ' + CAST(@DUPLICADOS_ANTES_EDITAR AS VARCHAR) + ' registro(s) duplicado(s) antes de editar. Se eliminarán después de actualizar.'
                END
            END
            
            IF (@ERROR IS NOT NULL AND @ERROR != '') AND @ESTADO != 0
            BEGIN
                SET @ESTADO = 0
                PRINT ' PRE-UPDATE: ERROR presente pero ESTADO != 0. FORZANDO ESTADO = 0'
            END
            ELSE IF (@ERROR IS NULL OR @ERROR = '') AND @ESTADO != 1 AND (@ESTADO_ENVIADO IS NULL OR @ESTADO_ENVIADO = 1)
            BEGIN
                SET @ESTADO = 1
                PRINT ' PRE-UPDATE: ERROR = NULL pero ESTADO != 1. FORZANDO ESTADO = 1'
            END
            
            PRINT ' ANTES DEL UPDATE: ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL') + ' | CUENTA=' + ISNULL(@CUENTA, 'NULL') + ' | DETALLE=' + ISNULL(@DETALLE, 'NULL') + ' | NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
            
            UPDATE MCHE SET
                    NROCOMPROBANTE = @NROCOMPROBANTE,
                    COMPANIA = @COMPANIA,
                    TIPO = @TIPO,
                    CUENTA = @CUENTA,
                    IDTERCERO = @IDTERCERO,
                    CCOSTO = NULLIF(@CCOSTO, ''),
                    IDAREA = NULLIF(@IDAREA, ''),
                    DETALLE = @DETALLE,
                    VALOR = @VALOR,
                    REFERENCIA1 = NULLIF(@REFERENCIA1, ''),
                    REFERENCIA2 = NULLIF(@REFERENCIA2, ''),
                    REFERENCIA3 = NULLIF(@REFERENCIA3, ''),
                    N_FACTURA = NULLIF(@N_FACTURA, ''),
                    F_FACTURAREF = @F_FACTURAREF,
                    F_VENCE = @F_VENCE,
                    USUARIO = @USUARIO,
                    FECHA = @FECHA,
                    ERROR = NULLIF(@ERROR, ''),
                    ESTADO = @ESTADO,
                    IDPROVEEDOR = NULLIF(@IDPROVEEDOR, '')
            WHERE NROASIENTO = @NROASIENTO
            
            SET @ROWCOUNT = @@ROWCOUNT
            PRINT ' UPDATE ejecutado: ROWCOUNT=' + CAST(@ROWCOUNT AS VARCHAR) + ' | ESTADO=' + CAST(@ESTADO AS VARCHAR) + ' | ERROR=' + ISNULL(@ERROR, 'NULL')
            
            SELECT @ESTADO_ACTUAL = ESTADO, @ERROR_ACTUAL = ERROR 
            FROM MCHE 
            WHERE NROASIENTO = @NROASIENTO
            
            IF @ROWCOUNT = 0
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) SELECT 'No se encontró el registro con NROASIENTO: ' + CAST(@NROASIENTO AS VARCHAR)
            END
            
            IF @DUPLICADOS_ANTES_EDITAR > 0 AND @NROCOMPROBANTE IS NOT NULL AND @CUENTA IS NOT NULL AND @TIPO IS NOT NULL AND @VALOR IS NOT NULL
            BEGIN
                DECLARE @DUPLICADOS_DESPUES_EDITAR INT = 0
               
                SELECT @DUPLICADOS_DESPUES_EDITAR = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    AND CUENTA = @CUENTA
                    AND TIPO = @TIPO
                    AND ABS(VALOR - @VALOR) < 0.01
                    AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                    AND NROASIENTO != @NROASIENTO
               
                IF @DUPLICADOS_DESPUES_EDITAR > 0
                BEGIN
                    PRINT ' ELIMINANDO ' + CAST(@DUPLICADOS_DESPUES_EDITAR AS VARCHAR) + ' registro(s) duplicado(s) después de editar...'
                  
                    DELETE FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
                    AND CUENTA = @CUENTA
                    AND TIPO = @TIPO
                    AND ABS(VALOR - @VALOR) < 0.01
                    AND ISNULL(COMPANIA, '01') = ISNULL(@COMPANIA, '01')
                    AND NROASIENTO != @NROASIENTO
                  
                    PRINT ' Duplicados eliminados después de editar. Se mantiene el registro con NROASIENTO=' + CAST(@NROASIENTO AS VARCHAR)
                END
            END
            
            IF @ESTADO = 0 AND @NROCOMPROBANTE IS NOT NULL
            BEGIN
                DECLARE @HAY_ERRORES INT
                SELECT @HAY_ERRORES = COUNT(*) 
                FROM MCHE 
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE 
                    AND ESTADO = 1
               
                PRINT ' VERIFICACIÓN POST-EDITAR: Comprobante=' + @NROCOMPROBANTE + ' | Registros con errores (ESTADO=1)=' + CAST(@HAY_ERRORES AS VARCHAR)
               
                IF @HAY_ERRORES = 0
                BEGIN
                    PRINT ' Comprobante ' + @NROCOMPROBANTE + ' sin errores. Listo para reconstruir.'
                END
            END
            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
            END CATCH
            IF (SELECT COUNT(*) FROM @TBLERRORES)> 0
            BEGIN
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
            SELECT 'OK' OK
            RETURN
        END
      
        IF UPPER(@PROCESO) = 'ELIMINAR'
        BEGIN
            PRINT 'ELIMINAR MCHE'
            BEGIN TRY
                DELETE FROM MCHE 
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE 
                    AND NROASIENTO = @NROASIENTO
            END TRY
            BEGIN CATCH
                INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
            END CATCH
            IF (SELECT COUNT(*) FROM @TBLERRORES)> 0
            BEGIN
                SELECT 'KO' OK
                SELECT ERROR FROM @TBLERRORES
                RETURN
            END
            SELECT 'OK' OK
            RETURN
        END
      
        DECLARE @NROCOMPROBANTE_FINAL VARCHAR(20) = COALESCE(@NROCOMPROBANTE, @NROCOMPROBANTE_TEMP)
      
        IF @NROCOMPROBANTE_FINAL IS NOT NULL AND LTRIM(RTRIM(@NROCOMPROBANTE_FINAL)) != ''
        BEGIN
            DECLARE @DUPLICADOS_FINAL INT = 0
            DECLARE @DUPLICADOS_ELIMINADOS_FINAL INT = 0
            DECLARE @TOTAL_REGISTROS_FINAL INT = 0
            DECLARE @REGISTROS_UNICOS_FINAL INT = 0
         
            PRINT ' ========== VALIDACIÓN FINAL OBLIGATORIA Y ULTRA-AGRESIVA: Verificando y eliminando TODOS los duplicados en comprobante ' + @NROCOMPROBANTE_FINAL + ' =========='
         
            DECLARE @ITERACION_FINAL INT = 0
            DECLARE @MAX_ITERACIONES_FINAL INT = 100
            DECLARE @DUPLICADOS_RESTANTES_FINAL INT = 1
         
            WHILE @DUPLICADOS_RESTANTES_FINAL > 0 AND @ITERACION_FINAL < @MAX_ITERACIONES_FINAL
            BEGIN
                SET @ITERACION_FINAL = @ITERACION_FINAL + 1
            
                SELECT @TOTAL_REGISTROS_FINAL = COUNT(*)
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE_FINAL
                AND CUENTA IS NOT NULL
                AND TIPO IS NOT NULL
                AND VALOR IS NOT NULL
            
                IF @TOTAL_REGISTROS_FINAL = 0
                BEGIN
                    PRINT ' Iteración ' + CAST(@ITERACION_FINAL AS VARCHAR) + ': No hay registros en el comprobante. Limpieza completada.'
                    BREAK
                END
            
                SELECT @REGISTROS_UNICOS_FINAL = COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                FROM MCHE
                WHERE NROCOMPROBANTE = @NROCOMPROBANTE_FINAL
                AND CUENTA IS NOT NULL
                AND TIPO IS NOT NULL
                AND VALOR IS NOT NULL
            
                SET @DUPLICADOS_FINAL = @TOTAL_REGISTROS_FINAL - @REGISTROS_UNICOS_FINAL
                SET @DUPLICADOS_RESTANTES_FINAL = @DUPLICADOS_FINAL
            
                IF @DUPLICADOS_FINAL = 0
                BEGIN
                    IF @ITERACION_FINAL = 1
                    BEGIN
                        PRINT ' VALIDACIÓN FINAL: No se detectaron duplicados en el comprobante ' + @NROCOMPROBANTE_FINAL
                    END
                    ELSE
                    BEGIN
                        PRINT ' Iteración ' + CAST(@ITERACION_FINAL AS VARCHAR) + ': OK - Todos los duplicados eliminados. Limpieza final completada.'
                    END
                    BREAK
                END
         
                IF @ITERACION_FINAL = 1
                BEGIN
                    PRINT ' VALIDACIÓN FINAL: Total=' + CAST(@TOTAL_REGISTROS_FINAL AS VARCHAR) + ' | Únicos=' + CAST(@REGISTROS_UNICOS_FINAL AS VARCHAR) + ' | Duplicados=' + CAST(@DUPLICADOS_FINAL AS VARCHAR) + ' | Comprobante=' + @NROCOMPROBANTE_FINAL
                END
            
                PRINT ' Iteración ' + CAST(@ITERACION_FINAL AS VARCHAR) + ': Eliminando ' + CAST(@DUPLICADOS_FINAL AS VARCHAR) + ' duplicado(s) restante(s)...'
            
                DELETE m1
                FROM MCHE m1
                WHERE EXISTS (
                    SELECT 1
                    FROM (
                        SELECT NROCOMPROBANTE, CUENTA, TIPO, VALOR, ISNULL(COMPANIA, '01') AS COMPANIA, MIN(NROASIENTO) AS MIN_NROASIENTO
                        FROM MCHE
                        WHERE NROCOMPROBANTE = @NROCOMPROBANTE_FINAL
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
            
                SET @DUPLICADOS_ELIMINADOS_FINAL = @DUPLICADOS_ELIMINADOS_FINAL + @@ROWCOUNT
            
                IF @@ROWCOUNT = 0
                BEGIN
                    PRINT ' Iteración ' + CAST(@ITERACION_FINAL AS VARCHAR) + ': No se eliminaron registros. Verificando estado final...'
               
                    SELECT @TOTAL_REGISTROS_FINAL = COUNT(*)
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE_FINAL
                    AND CUENTA IS NOT NULL
                    AND TIPO IS NOT NULL
                    AND VALOR IS NOT NULL
               
                    SELECT @REGISTROS_UNICOS_FINAL = COUNT(DISTINCT CONCAT(ISNULL(CUENTA, ''), '|', ISNULL(TIPO, ''), '|', CAST(ISNULL(VALOR, 0) AS VARCHAR(20)), '|', ISNULL(COMPANIA, '01')))
                    FROM MCHE
                    WHERE NROCOMPROBANTE = @NROCOMPROBANTE_FINAL
                    AND CUENTA IS NOT NULL
                    AND TIPO IS NOT NULL
                    AND VALOR IS NOT NULL
               
                    SET @DUPLICADOS_RESTANTES_FINAL = @TOTAL_REGISTROS_FINAL - @REGISTROS_UNICOS_FINAL
               
                    IF @DUPLICADOS_RESTANTES_FINAL = 0
                    BEGIN
                        PRINT ' VERIFICACIÓN FINAL: OK - No quedan duplicados en el comprobante ' + @NROCOMPROBANTE_FINAL
                    END
                    ELSE
                    BEGIN
                        PRINT ' ADVERTENCIA: Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_FINAL AS VARCHAR) + ' duplicado(s) después de ' + CAST(@ITERACION_FINAL AS VARCHAR) + ' iteraciones. Continuando...'
                    END
                END
                ELSE
                BEGIN
                    PRINT ' Iteración ' + CAST(@ITERACION_FINAL AS VARCHAR) + ' completada: Se eliminaron ' + CAST(@@ROWCOUNT AS VARCHAR) + ' duplicado(s)'
                END
            END
         
            IF @DUPLICADOS_ELIMINADOS_FINAL > 0
            BEGIN
                PRINT '  LIMPIEZA FINAL COMPLETADA: Se eliminaron ' + CAST(@DUPLICADOS_ELIMINADOS_FINAL AS VARCHAR) + ' duplicado(s) del comprobante ' + @NROCOMPROBANTE_FINAL + ' en ' + CAST(@ITERACION_FINAL AS VARCHAR) + ' iteración(es) '
            END
         
            IF @DUPLICADOS_RESTANTES_FINAL > 0 AND @ITERACION_FINAL >= @MAX_ITERACIONES_FINAL
            BEGIN
                PRINT '  ERROR CRÍTICO: Aún quedan ' + CAST(@DUPLICADOS_RESTANTES_FINAL AS VARCHAR) + ' duplicado(s) después de ' + CAST(@MAX_ITERACIONES_FINAL AS VARCHAR) + ' iteraciones. Se requiere revisión manual inmediata.'
            END
            ELSE IF @DUPLICADOS_RESTANTES_FINAL = 0
            BEGIN
                PRINT ' VERIFICACIÓN FINAL: OK - No quedan duplicados en el comprobante ' + @NROCOMPROBANTE_FINAL
            END
        END
        ELSE 
        BEGIN
            PRINT ' ADVERTENCIA: No se pudo ejecutar validación final porque @NROCOMPROBANTE es NULL o vacío.'
        END
      
        RETURN
    END
	IF @METODO = 'MARCAR_DESMARCAR_MCHE'
	BEGIN
	    SELECT @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')
	    SELECT @NROASIENTO = CAST(JSON_VALUE(@PARAMETROS, '$.NROASIENTO') AS INT)
	    SELECT @TIPO = JSON_VALUE(@PARAMETROS, '$.TIPO')

	    IF @NROCOMPROBANTE IS NULL OR LTRIM(RTRIM(@NROCOMPROBANTE)) = ''
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NROCOMPROBANTE es obligatorio'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    IF @TIPO = 1
	    BEGIN
		    -- Marcar/Desmarcar individual: toggle MARCA (1->0, 0/NULL->1)
		    IF @NROASIENTO IS NULL
		    BEGIN
			    INSERT INTO @TBLERRORES(ERROR) SELECT 'NROASIENTO es obligatorio para marcar/desmarcar individual'
			    SELECT 'KO' OK
			    SELECT ERROR FROM @TBLERRORES
			    RETURN
		    END

		    UPDATE MCHE
		    SET MARCA = CASE WHEN ISNULL(MARCA, 0) = 1 THEN 0 ELSE 1 END
		    WHERE NROCOMPROBANTE = @NROCOMPROBANTE
			AND NROASIENTO = @NROASIENTO

		    SET @ROWCOUNT = @@ROWCOUNT
	    END
	    ELSE IF @TIPO = 2
	    BEGIN
		    -- Marcar todo: establecer MARCA = 1 para todos los registros del comprobante
		    UPDATE MCHE
		    SET MARCA = 1
		    WHERE NROCOMPROBANTE = @NROCOMPROBANTE

		    SET @ROWCOUNT = @@ROWCOUNT
	    END
	    ELSE IF @TIPO = 3
	    BEGIN
		IF EXISTS (SELECT 1 FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE AND MARCA = 1)
		BEGIN
		    UPDATE MCHE
		    SET MARCA = 0
		    WHERE NROCOMPROBANTE = @NROCOMPROBANTE

		    SET @ROWCOUNT = @@ROWCOUNT
		END
	    END
	    ELSE
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'TIPO inválido. 1 (individual) o 2 (marcar todo)'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
	    BEGIN
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    SELECT 'OK' OK, @ROWCOUNT ROWS_AFFECTED
	    RETURN
	END
	IF @METODO = 'PROCESAR_MARCADOS'
	BEGIN
	    SELECT @NROCOMPROBANTE = JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE')
	    SELECT @CCOSTO = JSON_VALUE(@PARAMETROS, '$.CCOSTO')
	    SELECT @IDAREA = JSON_VALUE(@PARAMETROS, '$.IDAREA')

	    IF @NROCOMPROBANTE IS NULL OR LTRIM(RTRIM(@NROCOMPROBANTE)) = ''
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NROCOMPROBANTE es obligatorio'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    IF @CCOSTO IS NULL OR LTRIM(RTRIM(@CCOSTO)) = ''
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NO SE HA ESCOGIDO CCOSTO.'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    IF @IDAREA IS NULL OR LTRIM(RTRIM(@IDAREA)) = ''
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NO SE HA ESCOGIDO IDAREA (Área).'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    -- Validar que existan items marcados
	    IF  NOT EXISTS(SELECT  1 FROM MCHE  WHERE NROCOMPROBANTE = @NROCOMPROBANTE  AND COALESCE(MARCA, 0) = 1)
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NO EXISTEN ITEMS MARCADOS.'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    -- Validar que CCOSTO exista en CEN
	    IF NOT EXISTS (SELECT 1 FROM CEN WHERE CCOSTO = @CCOSTO)
	    BEGIN
		    INSERT INTO @TBLERRORES(ERROR) SELECT 'NO EXISTE EL CENTRO DE COSTO ELEGIDO.'
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END

	    -- Ejecutar cambio masivo
	    BEGIN TRY
		    EXEC SPK_MCHE_CAMBIOMASIVO @NROCOMPROBANTE, @CCOSTO, @IDAREA
		    SELECT 'OK' OK
	    END TRY
	    BEGIN CATCH
		    INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
		    SELECT 'KO' OK
		    SELECT ERROR FROM @TBLERRORES
		    RETURN
	    END CATCH
	    RETURN
	END
END

