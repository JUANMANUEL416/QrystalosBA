CREATE OR ALTER PROCEDURE DBO.SPQ_PRECOM
@JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    -- Declaraci�n de variables
    DECLARE 
        @CODIGO VARCHAR(20),
        @DESCRIPCION VARCHAR(100),
        @REGISTROS NVARCHAR(MAX),
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @PROCESO VARCHAR(20)

    -- Extraer MODELO, METODO y PARAMETROS
    SELECT * 
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100)    '$.MODELO',
        METODO      VARCHAR(100)    '$.METODO',
        PARAMETROS  NVARCHAR(MAX)   AS JSON
    )

    SELECT @MODELO = MODELO, 
           @METODO = METODO, 
           @PARAMETROS = PARAMETROS
    FROM #JSON

    -- Tabla para errores
    DECLARE @TBLERRORES TABLE(ERROR VARCHAR(200))

    IF @METODO = 'CRUDPRECOM'
    BEGIN
        -- Extraer el objeto REGISTRO y PROCESO
        SELECT @REGISTROS = REGISTRO, @PROCESO = PROCESO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            REGISTRO NVARCHAR(MAX) AS JSON,
            PROCESO  VARCHAR(20)   '$.PROCESO'
        )

        -- Extraer los valores del registro
        SELECT 
            @CODIGO = CODIGO,
            @DESCRIPCION = DESCRIPCION
        FROM OPENJSON(@REGISTROS)
        WITH (
            CODIGO        VARCHAR(20)   '$.CODIGO',
            DESCRIPCION   VARCHAR(100)  '$.DESCRIPCION'
            
        )
		PRINT 'ANTES DE'
		PRINT @DESCRIPCION
        -- Valores fijos
        DECLARE @TABLA VARCHAR(15) = 'IART'
        DECLARE @CAMPO VARCHAR(20) = 'PRECOMERCIAL'

        BEGIN TRY
            -- INSERTAR
            IF UPPER(@PROCESO) = 'Insertar'
            BEGIN
				IF (SELECT COUNT(*) FROM TGEN WHERE TABLA = @TABLA AND CAMPO = @CAMPO AND CODIGO = @CODIGO)>0
				BEGIN
					SELECT 'KO' OK
					SELECT ERROR = 'Esta presentaci�n ya existe, valide...'
					RETURN
				END
                IF (SELECT COUNT(*) FROM @TBLERRORES) <= 0
                BEGIN
                    INSERT INTO TGEN (TABLA, CAMPO, CODIGO, DESCRIPCION)
                    VALUES (@TABLA, @CAMPO, @CODIGO, @DESCRIPCION)
                END
            END

            -- EDITAR
            IF UPPER(@PROCESO) = 'Editar'
            BEGIN
                UPDATE TGEN
                SET DESCRIPCION = @DESCRIPCION
                    
                WHERE TABLA = @TABLA AND CAMPO = @CAMPO AND CODIGO = @CODIGO
            END

            -- ELIMINAR
            IF UPPER(@PROCESO) = 'Eliminar'
            BEGIN
                DELETE FROM TGEN
                WHERE TABLA = @TABLA AND CAMPO = @CAMPO AND CODIGO = @CODIGO
            END

        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
        END CATCH

        -- Retornar errores si existen
        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK
            SELECT ERROR FROM @TBLERRORES
            RETURN
        END

        -- Todo ok
        SELECT 'OK' AS OK
        RETURN
    END
END
