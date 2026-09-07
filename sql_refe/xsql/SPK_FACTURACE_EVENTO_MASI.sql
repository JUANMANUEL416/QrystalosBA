CREATE OR ALTER PROCEDURE DBO.SPK_FACTURACE_EVENTO_MASI
    @CNSRPDX      VARCHAR(20),
    @NIT          VARCHAR(20),
    @COMPANIA     VARCHAR(2),
    @IDSEDE       VARCHAR(5),
    @USUARIO      VARCHAR(12),
    @IDTERCEROCA1 VARCHAR(20),
    @IDPLAN       VARCHAR(20),
    @OBSERVACION  VARCHAR(2048),
    @F_FACTURA    DATETIME 
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IDAUT        VARCHAR(20);
    DECLARE @IDSEDEF      VARCHAR(5);
    DECLARE @RowNum       INT = 1;
    DECLARE @MaxRow       INT;
    DECLARE @FactSedePaciente BIT = 0;
    
    -- Verificar variable de sistema FACTSEDE
    IF DBO.FNK_VALORVARIABLE('FACTSEDE') = 'NO'
    BEGIN
        IF @IDSEDE <> DBO.FNK_VALORVARIABLE('IDSEDEPRINCIPAL')
        BEGIN
            SET @IDSEDE = DBO.FNK_VALORVARIABLE('IDSEDEPRINCIPAL');
        END
    END
    
    -- Verificar variable de sistema FACTSEDEPACIENTE
    IF DBO.FNK_VALORVARIABLE('FACTSEDEPACIENTE') = 'SI'
        SET @FactSedePaciente = 1;
    
    -- Tabla temporal para almacenar resultados (más eficiente que cursor)
    CREATE TABLE #TempAut (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        IDAUT VARCHAR(20),
        IDSEDEF VARCHAR(5)
    );
    
    -- Insertar todos los registros en una sola consulta
    IF @FactSedePaciente = 1
    BEGIN
        -- Caso: Factura con sede del paciente
        INSERT INTO #TempAut (IDAUT, IDSEDEF)
        SELECT AUT.IDAUT, 
            AFI.IDSEDE 
        FROM AUT WITH(NOLOCK)
        LEFT JOIN TER WITH(NOLOCK) ON AUT.IDTERCEROCA = TER.IDTERCERO
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = AUT.IDAFILIADO
        WHERE   AUT.IDTERCEROCA = @IDTERCEROCA1 
        AND     AUT.IDPLAN = @IDPLAN 
        AND     (AUT.FACTURADA = 0 OR AUT.FACTURADA IS NULL) 
        AND     AUT.MARCAFAC = 1 
        AND     AUT.CNSFACT = @CNSRPDX
        ORDER BY AFI.NOMBREAFI;
    END
    ELSE
    BEGIN
        -- Caso: Factura sin sede del paciente (usar sede del parámetro)
        INSERT INTO #TempAut (IDAUT, IDSEDEF)
        SELECT AUT.IDAUT, 
            @IDSEDE  -- Usar la sede del parámetro
        FROM AUT WITH(NOLOCK)
        LEFT JOIN TER WITH(NOLOCK) ON AUT.IDTERCEROCA = TER.IDTERCERO
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = AUT.IDAFILIADO
        WHERE   AUT.IDTERCEROCA = @IDTERCEROCA1 
        AND     AUT.IDPLAN = @IDPLAN 
        AND     (AUT.FACTURADA = 0 OR AUT.FACTURADA IS NULL) 
        AND     AUT.MARCAFAC = 1 
        AND     AUT.CNSFACT = @CNSRPDX
        ORDER BY AFI.NOMBREAFI;
    END
    
    SELECT @MaxRow = MAX(RowNum) FROM #TempAut;
    
    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT  @IDAUT = IDAUT,
                @IDSEDEF = IDSEDEF
        FROM    #TempAut
        WHERE   RowNum = @RowNum;
        
        EXEC SPK_FACTURACE_EVENTO  
            @CNSRPDX, 
            @NIT, 
            @COMPANIA, 
            @IDSEDEF,  -- Usar la sede determinada según FACTSEDEPACIENTE
            @USUARIO, 
            @IDTERCEROCA1, 
            @IDPLAN, 
            @OBSERVACION, 
            @IDAUT, 
            @F_FACTURA;
        
        SET @RowNum = @RowNum + 1;
    END
    
    -- Limpiar tabla temporal
    DROP TABLE #TempAut;
    
    SET NOCOUNT OFF;
END

