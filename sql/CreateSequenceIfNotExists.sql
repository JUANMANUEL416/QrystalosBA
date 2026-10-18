CREATE OR ALTER PROCEDURE dbo.CreateSequenceIfNotExists
    @IDSEDE VARCHAR(5),
    @PREFIJO VARCHAR(20),
    @InicialValue INT
AS
BEGIN
    DECLARE @SequenceName NVARCHAR(128) = 'SEQ_' + @IDSEDE + '_' + @PREFIJO;
    
    IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = @SequenceName AND schema_id = SCHEMA_ID('dbo'))
    BEGIN
        DECLARE @SQL NVARCHAR(MAX) = 'CREATE SEQUENCE dbo.' + @SequenceName +
            ' AS INT START WITH ' + CAST(@InicialValue AS NVARCHAR) + ' INCREMENT BY 1;';
        EXEC sp_executesql @SQL;
    END
END
