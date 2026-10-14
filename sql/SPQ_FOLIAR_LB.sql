CREATE OR ALTER PROCEDURE DBO.SPQ_FOLIAR_LB
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO      VARCHAR(100),
        @METODO      VARCHAR(100),
        @PARAMETROS  NVARCHAR(MAX),

        @COMPANIA    VARCHAR(2),
        @IDSEDE      VARCHAR(2),
        @BODEGA      VARCHAR(20),
        @IDADICIONAL VARCHAR(20),
        @PREFIJO     VARCHAR(20),
        @CONSECUTIVO INT,
        @SERIE       INT,
        @LIMITE      INT,
        @PROCESO     VARCHAR(10);

    DECLARE @TBLERRORES TABLE (ERROR NVARCHAR(500));

    BEGIN TRY
        SELECT
            @MODELO     = MODELO,
            @METODO     = METODO,
            @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON)
        WITH (
            MODELO      VARCHAR(100) '$.MODELO',
            METODO      VARCHAR(100) '$.METODO',
            PARAMETROS  NVARCHAR(MAX) AS JSON
        );
    END TRY
    BEGIN CATCH
        INSERT INTO @TBLERRORES(ERROR)
        VALUES (CONCAT('Error al parsear JSON: ', ERROR_MESSAGE()));

        SELECT 'KO' AS OK;
        SELECT ERROR FROM @TBLERRORES ORDER BY ERROR;
        RETURN;
    END CATCH;

    IF @METODO = 'CRUD_USCXS'
    BEGIN
        BEGIN TRY
            SELECT
                @PROCESO     = UPPER(ISNULL(PROCESO, 'NUEVO')),
                @COMPANIA    = COMPANIA,
                @IDSEDE      = IDSEDE,
                @BODEGA      = BODEGA,
                @IDADICIONAL = IDADICIONAL,
                @PREFIJO     = PREFIJO,
                @CONSECUTIVO = ISNULL(CONSECUTIVO, 0),
                @SERIE       = ISNULL(SERIE, 0),
                @LIMITE      = ISNULL(LIMITE, 0)
            FROM OPENJSON(@PARAMETROS, '$.REGISTRO')
            WITH (
                PROCESO      VARCHAR(10) '$.PROCESO',
                COMPANIA     VARCHAR(2) '$.COMPANIA',
                IDSEDE       VARCHAR(2) '$.IDSEDE',
                BODEGA       VARCHAR(20) '$.BODEGA',
                IDADICIONAL  VARCHAR(20) '$.IDADICIONAL',
                PREFIJO      VARCHAR(20) '$.PREFIJO',
                CONSECUTIVO  INT '$.CONSECUTIVO',
                SERIE        INT '$.SERIE',
                LIMITE       INT '$.LIMITE'
            );

            -- Validaciones
            IF ISNULL(@COMPANIA, '') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('COMPANIA es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
            END

            IF ISNULL(@IDSEDE, '') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('IDSEDE es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
            END

            IF ISNULL(@BODEGA, '') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('BODEGA es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
            END

            IF ISNULL(@PREFIJO, '') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('PREFIJO es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
            END

            -- Verificar si existe el registro
            IF EXISTS (
                SELECT 1
                FROM USCXS
                WHERE COMPANIA = @COMPANIA
                  AND IDSEDE = @IDSEDE
                  AND BODEGA = @BODEGA
                  AND ISNULL(IDADICIONAL, '') = ISNULL(@IDADICIONAL, '')
                  AND PREFIJO = @PREFIJO
            )
            BEGIN
                -- UPDATE
                UPDATE USCXS
                SET CONSECUTIVO = @CONSECUTIVO,
                    SERIE = @SERIE,
                    LIMITE = @LIMITE
                WHERE COMPANIA = @COMPANIA
                  AND IDSEDE = @IDSEDE
                  AND BODEGA = @BODEGA
                  AND ISNULL(IDADICIONAL, '') = ISNULL(@IDADICIONAL, '')
                  AND PREFIJO = @PREFIJO;

                SELECT 'OK' AS OK;
                RETURN;
            END
            ELSE
            BEGIN
                -- INSERT
                INSERT INTO USCXS (
                    COMPANIA,
                    IDSEDE,
                    BODEGA,
                    IDADICIONAL,
                    PREFIJO,
                    CONSECUTIVO,
                    SERIE,
                    LIMITE
                )
                VALUES (
                    @COMPANIA,
                    @IDSEDE,
                    @BODEGA,
                    @IDADICIONAL,
                    @PREFIJO,
                    @CONSECUTIVO,
                    @SERIE,
                    @LIMITE
                );

                SELECT 'OK' AS OK;
                RETURN;
            END
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES VALUES (CONCAT('Error en CRUD_USCXS: ', ERROR_MESSAGE()));
            SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
        END CATCH
    END

    IF @METODO = 'INICIALIZAR_LIBROS'
    BEGIN
        BEGIN TRY
            SELECT
                @COMPANIA = ISNULL(COMPANIA, '01'),
                @IDSEDE   = ISNULL(IDSEDE, '01')
            FROM OPENJSON(@PARAMETROS)
            WITH (
                COMPANIA  VARCHAR(2) '$.COMPANIA',
                IDSEDE    VARCHAR(2) '$.IDSEDE'
            );

            -- Insertar libros contables que no existan
            INSERT INTO USCXS (
                COMPANIA,
                IDSEDE,
                BODEGA,
                IDADICIONAL,
                PREFIJO,
                CONSECUTIVO,
                SERIE,
                LIMITE
            )
            SELECT 
                @COMPANIA,
                @IDSEDE,
                IBOD.IDBODEGA,
                NULL,
                X.PREFIJO,
                0,
                0,
                0
            FROM (
                SELECT '@KFOL_LDIA' AS PREFIJO UNION 
                SELECT '@KFOL_LMAY' AS PREFIJO UNION 
                SELECT '@KFOL_LINV' AS PREFIJO UNION 
                SELECT '@KFOL_LEST' AS PREFIJO UNION 
                SELECT '@KFOL_LBPR' AS PREFIJO UNION 
                SELECT '@KFOL_LBGR' AS PREFIJO
            ) AS X
            LEFT JOIN USCXS ON X.PREFIJO = USCXS.PREFIJO
                AND USCXS.COMPANIA = @COMPANIA
                AND USCXS.IDSEDE = @IDSEDE
            CROSS JOIN (
                SELECT TOP 1 IDBODEGA 
                FROM IBOD 
                ORDER BY IDBODEGA
            ) IBOD
            WHERE USCXS.PREFIJO IS NULL;

            SELECT 'OK' AS OK;
            RETURN;
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES VALUES (CONCAT('Error en INICIALIZAR_LIBROS: ', ERROR_MESSAGE()));
            SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES ORDER BY ERROR; RETURN;
        END CATCH
    END

    INSERT INTO @TBLERRORES(ERROR)
    VALUES (CONCAT('M�todo no reconocido: ', ISNULL(@METODO, 'NULL')));

    SELECT 'KO' AS OK;
    SELECT ERROR FROM @TBLERRORES ORDER BY ERROR;
END;
