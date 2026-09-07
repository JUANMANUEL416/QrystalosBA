CREATE OR ALTER PROCEDURE DBO.SPQ_PARN
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @REGISTRO NVARCHAR(MAX),
        @PROCESO VARCHAR(50),
        @PARN_ID INT,
        @PARNI_ID INT,
        @PARAMETRO VARCHAR(100),
        @FECHA DATETIME,
        @DATO VARCHAR(MAX),
        @PARAMETRO_OLD VARCHAR(100),
        @INICIAL DECIMAL(18,2),
        @FINAL DECIMAL(18,2),
        @PARNI_ID_OLD INT;

    SELECT 
        @MODELO = MODELO,
        @METODO = METODO,
        @PARAMETROS = PARAMETROS
    FROM OPENJSON(@JSON)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    IF @METODO = 'CRUD_PARN'
    BEGIN
        SELECT @REGISTRO = REGISTRO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            REGISTRO NVARCHAR(MAX) AS JSON
        );

        SELECT @PROCESO = UPPER(LTRIM(RTRIM(JSON_VALUE(@REGISTRO, '$.PROCESO'))))

        SELECT
            @PARAMETRO = JSON_VALUE(@REGISTRO, '$.PARAMETRO'),
            @FECHA = TRY_CAST(JSON_VALUE(@REGISTRO, '$.FECHA') AS DATETIME),
            @DATO = JSON_VALUE(@REGISTRO, '$.DATO'),
            @PARAMETRO_OLD = JSON_VALUE(@REGISTRO, '$.PARAMETRO_OLD');

        BEGIN TRY
            IF @PROCESO = 'INSERTAR_PARN'
            BEGIN
                IF EXISTS (SELECT 1 FROM PARN WHERE PARAMETRO = @PARAMETRO)
                BEGIN
                    SELECT 'KO' AS OK, CONCAT('El parámetro ', @PARAMETRO, ' ya existe') AS ERROR;
                    RETURN;
                END

                SELECT @PARN_ID = ISNULL(MAX(PARN_ID), 0) + 1 FROM PARN;

                INSERT INTO PARN (PARN_ID, PARAMETRO, FECHA, DATO)
                VALUES (@PARN_ID, @PARAMETRO, @FECHA, @DATO);

                SELECT 'OK' AS OK, @PARN_ID AS PARN_ID;
                RETURN;
            END

            IF @PROCESO = 'EDITAR_PARN'
            BEGIN
                IF @PARAMETRO_OLD IS NULL SET @PARAMETRO_OLD = @PARAMETRO;

                IF NOT EXISTS (SELECT 1 FROM PARN WHERE PARAMETRO = @PARAMETRO_OLD)
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el registro para actualizar' AS ERROR;
                    RETURN;
                END

                IF @PARAMETRO <> @PARAMETRO_OLD AND EXISTS (SELECT 1 FROM PARN WHERE PARAMETRO = @PARAMETRO)
                BEGIN
                    SELECT 'KO' AS OK, CONCAT('El parámetro ', @PARAMETRO, ' ya existe') AS ERROR;
                    RETURN;
                END

                UPDATE PARN
                SET 
                    PARAMETRO = @PARAMETRO,
                    FECHA = @FECHA,
                    DATO = @DATO
                WHERE PARAMETRO = @PARAMETRO_OLD;

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el registro para actualizar' AS ERROR;
                    RETURN;
                END

                SELECT 'OK' AS OK;
                RETURN;
            END

            IF @PROCESO = 'ELIMINAR_PARN'
            BEGIN
                IF EXISTS (SELECT 1 FROM PARNI WHERE PARAMETRO = @PARAMETRO)
                BEGIN
                    SELECT 'KO' AS OK, 'No se puede eliminar el parámetro porque tiene intervalos asociados' AS ERROR;
                    RETURN;
                END

                DELETE FROM PARN WHERE PARAMETRO = @PARAMETRO;

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el registro para eliminar' AS ERROR;
                    RETURN;
                END

                SELECT 'OK' AS OK;
                RETURN;
            END

            SELECT 'KO' AS OK, CONCAT('Proceso no reconocido en CRUD_PARN. Proceso: [', ISNULL(@PROCESO, 'NULL'), '] | METODO: [', ISNULL(@METODO, 'NULL'), ']') AS ERROR;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    IF @METODO = 'CRUD_PARNI'
    BEGIN
        SELECT @REGISTRO = REGISTRO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            REGISTRO NVARCHAR(MAX) AS JSON
        );

        SELECT @PROCESO = UPPER(LTRIM(RTRIM(JSON_VALUE(@REGISTRO, '$.PROCESO'))))

        IF @PROCESO IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'El campo PROCESO es NULL o no existe en el JSON' AS ERROR;
            RETURN;
        END

        SELECT
            @PARAMETRO = JSON_VALUE(@REGISTRO, '$.PARAMETRO'),
            @INICIAL = TRY_CAST(JSON_VALUE(@REGISTRO, '$.INICIAL') AS DECIMAL(18,2)),
            @FINAL = TRY_CAST(JSON_VALUE(@REGISTRO, '$.FINAL') AS DECIMAL(18,2)),
            @FECHA = TRY_CAST(JSON_VALUE(@REGISTRO, '$.FECHA') AS DATETIME),
            @DATO = JSON_VALUE(@REGISTRO, '$.DATO'),
            @PARNI_ID_OLD = TRY_CAST(JSON_VALUE(@REGISTRO, '$.PARNI_ID_OLD') AS INT);

        IF JSON_VALUE(@REGISTRO, '$.PARNI_ID') IS NOT NULL
        BEGIN
            SET @PARNI_ID = TRY_CAST(JSON_VALUE(@REGISTRO, '$.PARNI_ID') AS INT)
        END

        BEGIN TRY
            IF @PROCESO = 'INSERTAR_PARNI'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PARN WHERE PARAMETRO = @PARAMETRO)
                BEGIN
                    SELECT 'KO' AS OK, CONCAT('El parámetro ', @PARAMETRO, ' no existe') AS ERROR;
                    RETURN;
                END

                IF @INICIAL > @FINAL
                BEGIN
                    SELECT 'KO' AS OK, 'El valor inicial no puede ser mayor que el valor final' AS ERROR;
                    RETURN;
                END

                -- CORRECCIÓN: Validar solo por DATO para ese PARAMETRO
                IF EXISTS (
                    SELECT 1
                    FROM PARNI
                    WHERE PARAMETRO = @PARAMETRO
                      AND DATO = @DATO
                )
                BEGIN
                    SELECT 'KO' AS OK,
                           'Ya existe un intervalo con el mismo valor de DATO para este parámetro.' AS ERROR;
                    RETURN;
                END

                SELECT @PARNI_ID = ISNULL(MAX(PARNI_ID), 0) + 1 FROM PARNI;

                INSERT INTO PARNI (PARNI_ID, PARAMETRO, INICIAL, FINAL, FECHA, DATO)
                VALUES (@PARNI_ID, @PARAMETRO, @INICIAL, @FINAL, @FECHA, @DATO);

                SELECT 'OK' AS OK, @PARNI_ID AS PARNI_ID;
                RETURN;
            END

            IF @PROCESO = 'EDITAR_PARNI'
            BEGIN
                IF @PARNI_ID IS NULL AND @PARNI_ID_OLD IS NULL
                BEGIN
                    SELECT 'KO' AS OK, 'No se especificó el ID del intervalo a actualizar' AS ERROR;
                    RETURN;
                END

                DECLARE @ID_USAR INT = COALESCE(@PARNI_ID, @PARNI_ID_OLD)

                IF NOT EXISTS (SELECT 1 FROM PARNI WHERE PARNI_ID = @ID_USAR)
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el intervalo para actualizar' AS ERROR;
                    RETURN;
                END

                IF NOT EXISTS (SELECT 1 FROM PARN WHERE PARAMETRO = @PARAMETRO)
                BEGIN
                    SELECT 'KO' AS OK, CONCAT('El parámetro ', @PARAMETRO, ' no existe') AS ERROR;
                    RETURN;
                END

                IF @INICIAL > @FINAL
                BEGIN
                    SELECT 'KO' AS OK, 'El valor inicial no puede ser mayor que el valor final' AS ERROR;
                    RETURN;
                END

                -- CORRECCIÓN: Validar solo por DATO para ese PARAMETRO (excluyendo el registro actual)
                IF EXISTS (SELECT 1 FROM PARNI 
                          WHERE PARAMETRO = @PARAMETRO 
                          AND DATO = ISNULL(@DATO, '')
                          AND PARNI_ID <> @ID_USAR)
                BEGIN
                    SELECT 'KO' AS OK, CONCAT('Ya existe otro intervalo con el mismo valor de DATO (', ISNULL(@DATO, ''), ') para el parámetro ', @PARAMETRO, '. Por favor, modifique el valor de DATO.') AS ERROR;
                    RETURN;
                END

                UPDATE PARNI
                SET 
                    PARAMETRO = @PARAMETRO,
                    INICIAL = @INICIAL,
                    FINAL = @FINAL,
                    FECHA = @FECHA,
                    DATO = @DATO
                WHERE PARNI_ID = @ID_USAR;

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el intervalo para actualizar' AS ERROR;
                    RETURN;
                END

                SELECT 'OK' AS OK;
                RETURN;
            END

            IF @PROCESO = 'ELIMINAR_PARNI'
            BEGIN
                IF @PARNI_ID IS NULL AND @PARNI_ID_OLD IS NULL
                BEGIN
                    SELECT 'KO' AS OK, 'No se especificó el ID del intervalo a eliminar' AS ERROR;
                    RETURN;
                END

                DECLARE @ID_ELIMINAR INT = COALESCE(@PARNI_ID, @PARNI_ID_OLD)

                IF NOT EXISTS (SELECT 1 FROM PARNI WHERE PARNI_ID = @ID_ELIMINAR)
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el intervalo para eliminar' AS ERROR;
                    RETURN;
                END

                DELETE FROM PARNI WHERE PARNI_ID = @ID_ELIMINAR;

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 'KO' AS OK, 'No se encontró el intervalo para eliminar' AS ERROR;
                    RETURN;
                END

                SELECT 'OK' AS OK;
                RETURN;
            END

            SELECT 'KO' AS OK, CONCAT('Proceso no reconocido en CRUD_PARNI. Proceso recibido: [', ISNULL(@PROCESO, 'NULL'), '] | Longitud: ', CAST(LEN(ISNULL(@PROCESO, '')) AS VARCHAR), ' | METODO: [', ISNULL(@METODO, 'NULL'), ']') AS ERROR;
            RETURN;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH
    END

    IF @METODO IS NULL OR @METODO NOT IN ('CRUD_PARN', 'CRUD_PARNI')
    BEGIN
        SELECT 'KO' AS OK, CONCAT('Método no reconocido: [', ISNULL(@METODO, 'NULL'), ']') AS ERROR;
        RETURN;
    END
END

