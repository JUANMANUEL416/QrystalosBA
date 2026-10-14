CREATE OR ALTER PROCEDURE DBO.SPQ_TER_EQUIV_EFECTIVO
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @IDTERCERO VARCHAR(20),
        @NIT VARCHAR(20),
        @NIIF_VTAEQUIEFECTIVOS VARCHAR(100),
        @RAZONSOCIAL VARCHAR(200)
    
    DECLARE @TBLERRORES TABLE(ERROR NVARCHAR(500));

    SELECT @MODELO = MODELO,
           @METODO = METODO,
           @PARAMETROS = PARAMETROS
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100) '$.MODELO',
        METODO      VARCHAR(100) '$.METODO',
        PARAMETROS  NVARCHAR(MAX) AS JSON
    );

    IF @METODO = 'LISTAR_TERCEROS'
    BEGIN
        SELECT 'OK' AS OK;
        
        SELECT 
            TER.IDTERCERO,
            TER.NIT,
            TER.DV,
            TER.RAZONSOCIAL,
            TER.NIIF_VTAEQUIEFECTIVOS
        FROM TER
        ORDER BY TER.RAZONSOCIAL;
        
        RETURN;
    END
    
    IF @METODO = 'ACTUALIZAR_TERCERO'
    BEGIN
        SELECT @IDTERCERO = IDTERCERO,
               @NIT = NIT,
               @NIIF_VTAEQUIEFECTIVOS = NIIF_VTAEQUIEFECTIVOS,
               @RAZONSOCIAL = RAZONSOCIAL
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDTERCERO              VARCHAR(20)  '$.IDTERCERO',
            NIT                    VARCHAR(20)  '$.NIT',
            NIIF_VTAEQUIEFECTIVOS  VARCHAR(100) '$.NIIF_VTAEQUIEFECTIVOS',
            RAZONSOCIAL            VARCHAR(200) '$.RAZONSOCIAL'
        );

        IF @IDTERCERO IS NULL OR LTRIM(RTRIM(@IDTERCERO)) = ''
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) VALUES('El ID Tercero es requerido');
        END
        
        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) VALUES('El NIT es requerido para seguridad');
        END
        
        IF @RAZONSOCIAL IS NULL OR LTRIM(RTRIM(@RAZONSOCIAL)) = ''
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) VALUES('La Raz�n Social es requerida');
        END
        
        IF NOT EXISTS (
            SELECT 1 
            FROM TER 
            WHERE IDTERCERO = @IDTERCERO 
              AND NIT = @NIT
        )
        BEGIN
            INSERT INTO @TBLERRORES(ERROR) 
            VALUES('No se encontr� el tercero con el ID y NIT proporcionados. Verifique los datos.');
        END
        
        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR FROM @TBLERRORES ORDER BY ERROR;
            RETURN;
        END
        
        BEGIN TRY
           UPDATE TER
            SET NIIF_VTAEQUIEFECTIVOS = @NIIF_VTAEQUIEFECTIVOS,
                RAZONSOCIAL = @RAZONSOCIAL
            WHERE IDTERCERO = @IDTERCERO
              AND NIT = @NIT;
            
            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 'KO' AS OK,
                       'No se pudo actualizar el registro. Verifique que el ID Tercero y NIT sean correctos.' AS ERROR;
                RETURN;
            END
            
            SELECT 'OK' AS OK;
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) 
            SELECT ERROR_MESSAGE();
            
            SELECT 'KO' AS OK;
            SELECT ERROR FROM @TBLERRORES ORDER BY ERROR;
            RETURN;
        END CATCH
    END
    
    IF @METODO IS NULL OR @METODO NOT IN ('LISTAR_TERCEROS', 'ACTUALIZAR_TERCERO')
    BEGIN
        SELECT 'KO' AS OK,
               'M�todo no v�lido. solo LISTAR_TERCEROS o ACTUALIZAR_TERCERO' AS ERROR;
        RETURN;
    END
END
