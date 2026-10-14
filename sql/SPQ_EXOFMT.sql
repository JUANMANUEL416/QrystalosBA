CREATE OR ALTER PROCEDURE DBO.SPQ_EXOFMT 
    @JSON NVARCHAR(MAX) 
WITH ENCRYPTION 
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    
    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @PROCESO VARCHAR(20),
        @REGISTROS NVARCHAR(MAX),
        @TABLA VARCHAR(50),
        @ERROR_MESSAGE NVARCHAR(4000),
        @ERROR_NUMBER INT,
        @ERROR_SEVERITY INT,
        @ERROR_STATE INT,
        @ERROR_LINE INT,
        -- Formatos (EXOFMT) ++++++++++++++++++++++++++++++
        @IDFORMATO VARCHAR(20),
        @DESCRIPCION VARCHAR(255),
        @ESTADO VARCHAR(20),
        @HOJAEXP VARCHAR(50),
        @IDFORMATO_OLD VARCHAR(20),
        -- Conceptos (EXOFMTD) ++++++++++++++++++++++++++++++
        @CODCONCEPTO VARCHAR(20),
        @CUENTAINI VARCHAR(50),
        @CUENTAFIN VARCHAR(50),
        @MTERCERO VARCHAR(1),
        @NTZ VARCHAR(20),
        @MOTOMIN DECIMAL(18,2),
        @ESTADO_CONCEPTO VARCHAR(20),
        @CODCONCEPTO_OLD VARCHAR(20),
        @IDFORMATO_CONCEPTO VARCHAR(20),
        @IDFORMATO_CONCEPTO_OLD VARCHAR(20),
        -- Reglas (EXOFMTDD) ++++++++++++++++++++++++++++++++++
        @CAMPO VARCHAR(50),
        @CUENTAINI_REGLA VARCHAR(50),
        @CUENTAFIN_REGLA VARCHAR(50),
        @ESTADO_REGLA VARCHAR(20),
        @MSF VARCHAR(50),
        @TIPOE VARCHAR(20),
        @IDCONCEPTO_REGLA VARCHAR(20),
        @IDFORMATO_REGLA VARCHAR(20),
        @CAMPO_OLD VARCHAR(50),
        @IDCONCEPTO_REGLA_OLD VARCHAR(20),
        @IDFORMATO_REGLA_OLD VARCHAR(20)

    DECLARE @TBLERRORES TABLE(ERROR NVARCHAR(4000))

    BEGIN TRY
        SELECT 
            @MODELO = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO = JSON_VALUE(@JSON, '$.METODO'),
            @PARAMETROS = JSON_QUERY(@JSON, '$.PARAMETROS')

        IF @METODO IS NULL OR @PARAMETROS IS NULL
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) VALUES('Par�metros inv�lidos: MODELO, METODO o PARAMETROS faltantes')
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
            RETURN
        END

        IF @METODO = 'CRUDEXOFMT'
        BEGIN
            SELECT 
                @TABLA = JSON_VALUE(@PARAMETROS, '$.TABLA'),
                @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTRO'),
                @PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO')

            IF @TABLA IS NULL OR @PROCESO IS NULL
            BEGIN
                INSERT INTO @TBLERRORES(ERROR) VALUES('Par�metros inv�lidos: TABLA o PROCESO faltantes')
                SELECT 'KO' AS OK
                SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
                RETURN
            END

            IF UPPER(@TABLA) = 'EXOFMT'
            BEGIN
                SELECT
                    @IDFORMATO = JSON_VALUE(@REGISTROS, '$.IDFORMATO'),
                    @DESCRIPCION = JSON_VALUE(@REGISTROS, '$.DESCRIPCION'),
                    @ESTADO = JSON_VALUE(@REGISTROS, '$.ESTADO'),
                    @HOJAEXP = JSON_VALUE(@REGISTROS, '$.HOJAEXP'),
                    @IDFORMATO_OLD = JSON_VALUE(@REGISTROS, '$.IDFORMATO_OLD')

                -- Validaciones comunes
                IF @IDFORMATO IS NULL OR LEN(LTRIM(RTRIM(@IDFORMATO))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('IDFORMATO es requerido')
                END

                -- Validaciones SOLO para INSERTAR / EDITAR
                IF UPPER(@PROCESO) IN ('INSERTAR', 'EDITAR')
                BEGIN
                    IF @DESCRIPCION IS NULL OR LEN(LTRIM(RTRIM(@DESCRIPCION))) = 0
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('DESCRIPCION es requerida')
                    END
                END

                IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
                BEGIN
                    SELECT 'KO' AS OK
                    SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
                    RETURN
                END

                -- INSERTAR
                IF UPPER(@PROCESO) = 'INSERTAR'
                BEGIN
                    IF EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'Ya existe un registro con ese IDFORMATO'
                        RETURN
                    END

                    INSERT INTO EXOFMT(IDFORMATO, DESCRIPCION, ESTADO, HOJAEXP)
                    VALUES (@IDFORMATO, @DESCRIPCION, ISNULL(@ESTADO, 'A'), @HOJAEXP)

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- EDITAR
                IF UPPER(@PROCESO) = 'EDITAR'
                BEGIN
                    IF @IDFORMATO_OLD IS NULL
                        SET @IDFORMATO_OLD = @IDFORMATO

                    -- Verificar que existe el registro original
                    IF NOT EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO_OLD)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para actualizar'
                        RETURN
                    END

                    -- Si se cambia el ID, verificar que no exista otro registro con el nuevo ID
                    IF @IDFORMATO <> @IDFORMATO_OLD
                    BEGIN
                        IF EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO)
                        BEGIN
                            SELECT 'KO' AS OK
                            SELECT ERROR = 'Ya existe un registro con ese nuevo IDFORMATO'
                            RETURN
                        END
                    END

                    -- Actualizar registro usando el ID original en el WHERE
                    UPDATE EXOFMT
                    SET IDFORMATO = @IDFORMATO,
                        DESCRIPCION = @DESCRIPCION,
                        ESTADO = ISNULL(@ESTADO, ESTADO),
                        HOJAEXP = @HOJAEXP
                    WHERE IDFORMATO = @IDFORMATO_OLD

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se pudo actualizar el registro'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- ELIMINAR
                IF UPPER(@PROCESO) = 'ELIMINAR'
                BEGIN
                    -- Verificar que no tenga conceptos asociados
                    IF EXISTS (SELECT 1 FROM EXOFMTD WHERE IDFORMATO = @IDFORMATO)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se puede eliminar el formato porque tiene conceptos asociados'
                        RETURN
                    END

                    DELETE FROM EXOFMT 
                    WHERE IDFORMATO = @IDFORMATO

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para eliminar'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END
            END

            IF UPPER(@TABLA) = 'EXOFMTD'
            BEGIN
                SELECT
                    @CODCONCEPTO = JSON_VALUE(@REGISTROS, '$.CODCONCEPTO'),
                    @IDFORMATO_CONCEPTO = JSON_VALUE(@REGISTROS, '$.IDFORMATO'),
                    @DESCRIPCION = JSON_VALUE(@REGISTROS, '$.DESCRIPCION'),
                    @CUENTAINI = JSON_VALUE(@REGISTROS, '$.CUENTAINI'),
                    @CUENTAFIN = JSON_VALUE(@REGISTROS, '$.CUENTAFIN'),
                    @MTERCERO = JSON_VALUE(@REGISTROS, '$.MTERCERO'),
                    @NTZ = JSON_VALUE(@REGISTROS, '$.NTZ'),
                    @MOTOMIN = CASE 
                        WHEN JSON_VALUE(@REGISTROS, '$.MOTOMIN') IS NULL OR LEN(LTRIM(RTRIM(JSON_VALUE(@REGISTROS, '$.MOTOMIN')))) = 0 
                        THEN NULL 
                        ELSE CAST(JSON_VALUE(@REGISTROS, '$.MOTOMIN') AS DECIMAL(18,2)) 
                    END,
                    @ESTADO_CONCEPTO = JSON_VALUE(@REGISTROS, '$.ESTADO'),
                    @CODCONCEPTO_OLD = JSON_VALUE(@REGISTROS, '$.CODCONCEPTO_OLD'),
                    @IDFORMATO_CONCEPTO_OLD = JSON_VALUE(@REGISTROS, '$.IDFORMATO_OLD')

                -- Validaciones comunes (solo campos clave)
                IF @CODCONCEPTO IS NULL OR LEN(LTRIM(RTRIM(@CODCONCEPTO))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('CODCONCEPTO es requerido')
                END

                IF @IDFORMATO_CONCEPTO IS NULL OR LEN(LTRIM(RTRIM(@IDFORMATO_CONCEPTO))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('IDFORMATO es requerido')
                END

                -- Validaciones SOLO para INSERTAR / EDITAR
                IF UPPER(@PROCESO) IN ('INSERTAR', 'EDITAR')
                BEGIN
                    IF @DESCRIPCION IS NULL OR LEN(LTRIM(RTRIM(@DESCRIPCION))) = 0
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('DESCRIPCION es requerida')
                    END

                    -- Validar que el formato existe (solo para INSERTAR/EDITAR)
                    IF NOT EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO_CONCEPTO)
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('El formato especificado no existe')
                    END
                END

                IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
                BEGIN
                    SELECT 'KO' AS OK
                    SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
                    RETURN
                END

                -- INSERTAR
                IF UPPER(@PROCESO) = 'INSERTAR'
                BEGIN
                    IF EXISTS (SELECT 1 FROM EXOFMTD WHERE CODCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO_CONCEPTO)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'Ya existe un concepto con ese CODCONCEPTO para ese formato'
                        RETURN
                    END

                    INSERT INTO EXOFMTD(CODCONCEPTO, IDFORMATO, DESCRIPCION, CUENTAINI, CUENTAFIN, MTERCERO, NTZ, MOTOMIN, ESTADO)
                    VALUES (@CODCONCEPTO, @IDFORMATO_CONCEPTO, @DESCRIPCION, NULLIF(@CUENTAINI, ''), NULLIF(@CUENTAFIN, ''), NULLIF(@MTERCERO, ''), NULLIF(@NTZ, ''), @MOTOMIN, ISNULL(@ESTADO_CONCEPTO, 'A'))

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- EDITAR
                IF UPPER(@PROCESO) = 'EDITAR'
                BEGIN
                    IF @CODCONCEPTO_OLD IS NULL
                        SET @CODCONCEPTO_OLD = @CODCONCEPTO
                    IF @IDFORMATO_CONCEPTO_OLD IS NULL
                        SET @IDFORMATO_CONCEPTO_OLD = @IDFORMATO_CONCEPTO

                    IF NOT EXISTS (SELECT 1 FROM EXOFMTD WHERE CODCONCEPTO = @CODCONCEPTO_OLD AND IDFORMATO = @IDFORMATO_CONCEPTO_OLD)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para actualizar'
                        RETURN
                    END

                    IF @CODCONCEPTO <> @CODCONCEPTO_OLD OR @IDFORMATO_CONCEPTO <> @IDFORMATO_CONCEPTO_OLD
                    BEGIN
                        IF EXISTS (SELECT 1 FROM EXOFMTD WHERE CODCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO_CONCEPTO)
                        BEGIN
                            SELECT 'KO' AS OK
                            SELECT ERROR = 'Ya existe un concepto con ese CODCONCEPTO para ese formato'
                            RETURN
                        END
                    END

                    UPDATE EXOFMTD
                    SET CODCONCEPTO = @CODCONCEPTO,
                        IDFORMATO = @IDFORMATO_CONCEPTO,
                        DESCRIPCION = @DESCRIPCION,
                        CUENTAINI = NULLIF(@CUENTAINI, ''),
                        CUENTAFIN = NULLIF(@CUENTAFIN, ''),
                        MTERCERO = NULLIF(@MTERCERO, ''),
                        NTZ = NULLIF(@NTZ, ''),
                        MOTOMIN = @MOTOMIN,
                        ESTADO = ISNULL(@ESTADO_CONCEPTO, ESTADO)
                    WHERE CODCONCEPTO = @CODCONCEPTO_OLD 
                      AND IDFORMATO = @IDFORMATO_CONCEPTO_OLD

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se pudo actualizar el registro'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- ELIMINAR
                IF UPPER(@PROCESO) = 'ELIMINAR'
                BEGIN
                    IF EXISTS (SELECT 1 FROM EXOFMTDD WHERE IDCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO_CONCEPTO)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se puede eliminar el concepto porque tiene reglas asociadas'
                        RETURN
                    END

                    DELETE FROM EXOFMTD 
                    WHERE CODCONCEPTO = @CODCONCEPTO 
                      AND IDFORMATO = @IDFORMATO_CONCEPTO

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para eliminar'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END
            END

            IF UPPER(@TABLA) = 'EXOFMTDD'
            BEGIN
                SELECT
                    @CAMPO = JSON_VALUE(@REGISTROS, '$.CAMPO'),
                    @IDCONCEPTO_REGLA = JSON_VALUE(@REGISTROS, '$.IDCONCEPTO'),
                    @IDFORMATO_REGLA = JSON_VALUE(@REGISTROS, '$.IDFORMATO'),
                    @CUENTAINI_REGLA = JSON_VALUE(@REGISTROS, '$.CUENTAINI'),
                    @CUENTAFIN_REGLA = JSON_VALUE(@REGISTROS, '$.CUENTAFIN'),
                    @ESTADO_REGLA = JSON_VALUE(@REGISTROS, '$.ESTADO'),
                    @MSF = JSON_VALUE(@REGISTROS, '$.MSF'),
                    @TIPOE = JSON_VALUE(@REGISTROS, '$.TIPOE'),
                    @CAMPO_OLD = JSON_VALUE(@REGISTROS, '$.CAMPO_OLD'),
                    @IDCONCEPTO_REGLA_OLD = JSON_VALUE(@REGISTROS, '$.IDCONCEPTO_OLD'),
                    @IDFORMATO_REGLA_OLD = JSON_VALUE(@REGISTROS, '$.IDFORMATO_OLD')

                -- Validaciones comunes (campos clave)
                IF @CAMPO IS NULL OR LEN(LTRIM(RTRIM(@CAMPO))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('CAMPO es requerido')
                END

                IF @IDCONCEPTO_REGLA IS NULL OR LEN(LTRIM(RTRIM(@IDCONCEPTO_REGLA))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('IDCONCEPTO es requerido')
                END

                IF @IDFORMATO_REGLA IS NULL OR LEN(LTRIM(RTRIM(@IDFORMATO_REGLA))) = 0
                BEGIN
                    INSERT INTO @TBLERRORES(ERROR) VALUES('IDFORMATO es requerido')
                END

                -- Validaciones SOLO para INSERTAR / EDITAR
                IF UPPER(@PROCESO) IN ('INSERTAR', 'EDITAR')
                BEGIN
                    IF @TIPOE IS NULL OR LEN(LTRIM(RTRIM(@TIPOE))) = 0
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('TIPOE es requerido')
                    END

                    -- Validar que el concepto existe (solo para INSERTAR/EDITAR)
                    IF NOT EXISTS (SELECT 1 FROM EXOFMTD WHERE CODCONCEPTO = @IDCONCEPTO_REGLA AND IDFORMATO = @IDFORMATO_REGLA)
                    BEGIN
                        INSERT INTO @TBLERRORES(ERROR) VALUES('El concepto especificado no existe')
                    END
                END

                IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
                BEGIN
                    SELECT 'KO' AS OK
                    SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
                    RETURN
                END

                -- INSERTAR
                IF UPPER(@PROCESO) = 'INSERTAR'
                BEGIN
                    IF EXISTS (SELECT 1 FROM EXOFMTDD 
                               WHERE CAMPO = @CAMPO 
                                 AND IDCONCEPTO = @IDCONCEPTO_REGLA 
                                 AND IDFORMATO = @IDFORMATO_REGLA)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'Ya existe una regla con ese CAMPO para ese concepto y formato'
                        RETURN
                    END

                    INSERT INTO EXOFMTDD(CAMPO, IDCONCEPTO, IDFORMATO, CUENTAINI, CUENTAFIN, ESTADO, MSF, TIPOE)
                    VALUES (@CAMPO, @IDCONCEPTO_REGLA, @IDFORMATO_REGLA, NULLIF(@CUENTAINI_REGLA, ''), NULLIF(@CUENTAFIN_REGLA, ''), ISNULL(@ESTADO_REGLA, 'A'), NULLIF(@MSF, ''), @TIPOE)

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- EDITAR
                IF UPPER(@PROCESO) = 'EDITAR'
                BEGIN
                    IF @CAMPO_OLD IS NULL
                        SET @CAMPO_OLD = @CAMPO
                    IF @IDCONCEPTO_REGLA_OLD IS NULL
                        SET @IDCONCEPTO_REGLA_OLD = @IDCONCEPTO_REGLA
                    IF @IDFORMATO_REGLA_OLD IS NULL
                        SET @IDFORMATO_REGLA_OLD = @IDFORMATO_REGLA

                    IF NOT EXISTS (SELECT 1 FROM EXOFMTDD 
                                  WHERE CAMPO = @CAMPO_OLD 
                                    AND IDCONCEPTO = @IDCONCEPTO_REGLA_OLD 
                                    AND IDFORMATO = @IDFORMATO_REGLA_OLD)
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para actualizar'
                        RETURN
                    END

                    IF @CAMPO <> @CAMPO_OLD OR @IDCONCEPTO_REGLA <> @IDCONCEPTO_REGLA_OLD OR @IDFORMATO_REGLA <> @IDFORMATO_REGLA_OLD
                    BEGIN
                        IF EXISTS (SELECT 1 FROM EXOFMTDD 
                                  WHERE CAMPO = @CAMPO 
                                    AND IDCONCEPTO = @IDCONCEPTO_REGLA 
                                    AND IDFORMATO = @IDFORMATO_REGLA)
                        BEGIN
                            SELECT 'KO' AS OK
                            SELECT ERROR = 'Ya existe una regla con esos valores para ese concepto y formato'
                            RETURN
                        END
                    END

                    UPDATE EXOFMTDD
                    SET CAMPO = @CAMPO,
                        IDCONCEPTO = @IDCONCEPTO_REGLA,
                        IDFORMATO = @IDFORMATO_REGLA,
                        CUENTAINI = NULLIF(@CUENTAINI_REGLA, ''),
                        CUENTAFIN = NULLIF(@CUENTAFIN_REGLA, ''),
                        ESTADO = ISNULL(@ESTADO_REGLA, ESTADO),
                        MSF = NULLIF(@MSF, ''),
                        TIPOE = @TIPOE
                    WHERE CAMPO = @CAMPO_OLD 
                      AND IDCONCEPTO = @IDCONCEPTO_REGLA_OLD 
                      AND IDFORMATO = @IDFORMATO_REGLA_OLD

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se pudo actualizar el registro'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END

                -- ELIMINAR
                IF UPPER(@PROCESO) = 'ELIMINAR'
                BEGIN
                    DELETE FROM EXOFMTDD 
                    WHERE CAMPO = @CAMPO 
                      AND IDCONCEPTO = @IDCONCEPTO_REGLA 
                      AND IDFORMATO = @IDFORMATO_REGLA

                    IF @@ROWCOUNT = 0
                    BEGIN
                        SELECT 'KO' AS OK
                        SELECT ERROR = 'No se encontr� el registro para eliminar'
                        RETURN
                    END

                    SELECT 'OK' AS OK
                    RETURN
                END
            END

            INSERT INTO @TBLERRORES(ERROR) VALUES(CONCAT('Tabla no reconocida: ', @TABLA))
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
            RETURN
        END
        ELSE
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) VALUES(CONCAT('M�todo no reconocido: ', @METODO))
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
            RETURN
        END
    END TRY
    BEGIN CATCH
        SELECT 
            @ERROR_MESSAGE = ERROR_MESSAGE(),
            @ERROR_NUMBER = ERROR_NUMBER(),
            @ERROR_SEVERITY = ERROR_SEVERITY(),
            @ERROR_STATE = ERROR_STATE(),
            @ERROR_LINE = ERROR_LINE()

        INSERT INTO @TBLERRORES(ERROR) 
        VALUES(CONCAT('Error en l�nea ', CAST(@ERROR_LINE AS VARCHAR(10)), ': ', @ERROR_MESSAGE))

        SELECT 'KO' AS OK
        SELECT ERROR FROM @TBLERRORES ORDER BY ERROR
        RETURN
    END CATCH
END
