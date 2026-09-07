CREATE OR ALTER PROCEDURE DBO.SPK_FACTURACI_ESCIN
    @CNSRPDX      VARCHAR(20),
    @NIT          VARCHAR(20),
    @COMPANIA     VARCHAR(2),
    @IDSEDE       VARCHAR(5),
    @USUARIO      VARCHAR(12),
    @IDTERCEROCA1 VARCHAR(20),
    @F_FACTURA    DATETIME,
    @OBSERVACION  VARCHAR(2048) = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NOAUT   VARCHAR(16);
    DECLARE @IDSEDEF VARCHAR(5);
    DECLARE @RowNum  INT = 1;
    DECLARE @MaxRow  INT;
    DECLARE @FactSedePaciente BIT = 0;
    
    -- Verificar variable de sistema una sola vez
    IF DBO.FNK_VALORVARIABLE('FACTSEDEPACIENTE') = 'SI'
        SET @FactSedePaciente = 1;
    
    -- Tabla temporal para almacenar resultados (más eficiente que cursor)
    CREATE TABLE #TempAut (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        CONSECUTIVO VARCHAR(16),
        IDSEDEF VARCHAR(5)
    );
    
    -- Insertar todos los registros en una sola consulta
    IF @FactSedePaciente = 1
    BEGIN
        -- Caso: Factura con sede del paciente
        INSERT INTO #TempAut (CONSECUTIVO, IDSEDEF)
        SELECT  CIT.CONSECUTIVO, 
                AFI.IDSEDE 
        FROM CIT WITH(NOLOCK)
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = CIT.IDAFILIADO
        WHERE   CIT.CNSFACT = @CNSRPDX  
        AND     CIT.MARCAFAC = 1
        AND     COALESCE(CIT.FACTURABLE, 0) = 1
        AND     COALESCE(CIT.VALORTOTAL, 0) > 0 
        AND     ISNULL(CIT.DESCUENTO, 0) < CASE 
            WHEN CIT.TIPODTO = 'P' THEN 100 
            ELSE CIT.VALORTOTAL 
        END;
    END
    ELSE
    BEGIN
        -- Caso: Factura sin sede del paciente
        INSERT INTO #TempAut (CONSECUTIVO, IDSEDEF)
        SELECT  CIT.CONSECUTIVO, 
                @IDSEDE  -- Usar la sede del parámetro
        FROM CIT WITH(NOLOCK)
        WHERE   CIT.CNSFACT = @CNSRPDX  
        AND     CIT.MARCAFAC = 1
        AND     COALESCE(CIT.FACTURABLE, 0) = 1
        AND     COALESCE(CIT.VALORTOTAL, 0) > 0 
        AND     ISNULL(CIT.DESCUENTO, 0) < CASE 
            WHEN CIT.TIPODTO = 'P' THEN 100 
            ELSE CIT.VALORTOTAL 
        END;
    END
    
    SELECT @MaxRow = MAX(RowNum) FROM #TempAut;
    
    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT  @NOAUT = CONSECUTIVO,
                @IDSEDEF = IDSEDEF
        FROM    #TempAut
        WHERE   RowNum = @RowNum;
        
        EXEC SPK_FACTURACE_N 
            @NOAUT, 
            @NIT, 
            @COMPANIA, 
            @IDSEDEF, 
            @USUARIO, 
            '', 
            '', 
            '', 
            '', 
            '',
            'CI', 
            @IDTERCEROCA1, 
            FALSE, 
            NULL, 
            @F_FACTURA,
            @OBSERVACION;
        SET @RowNum = @RowNum + 1;
    END
    
    -- Limpiar tabla temporal
    DROP TABLE #TempAut;
    
    SET NOCOUNT OFF;
END

