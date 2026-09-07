CREATE OR ALTER PROCEDURE DBO.SPQ_GENSEQUENCE  
    @SEDE      VARCHAR(5),  
    @PREFIJO   VARCHAR(20),   
    @EXTRA     VARCHAR(10) = NULL,
    @LONGITUD  INT = 10, -- LONGITUD DE DIGITOS (SIN INCLUIR LA SEDE)
	@DEFAULT   INT = 10,
    @LLAMADO   varchar(10) = 'NVO',
    @NVOCONSEC VARCHAR(20) OUTPUT
WITH ENCRYPTION
AS  
BEGIN
    SET NOCOUNT ON;

    DECLARE @SequenceName NVARCHAR(128) = 'dbo.SEQ_' + @SEDE + '_' + @PREFIJO;
    DECLARE @InicialValue INT = 1; -- Valor inicial por defecto, puede cambiar según sea necesario
    DECLARE @trancount    INT = @@trancount;
    DECLARE @sql          NVARCHAR(MAX);
    DECLARE @paramDef     NVARCHAR(MAX);
    DECLARE @NextValue    INT;

    BEGIN TRY
        --IF @trancount = 0
        --    BEGIN TRANSACTION;
        --ELSE
        --    SAVE TRANSACTION USP_SPQ_GENSEQUENCE;
        
        -- Verificar si la secuencia existe en la tabla de control
        IF NOT EXISTS (
            SELECT 1 
            FROM SequenceControl 
            WHERE IDSEDE = @SEDE AND PREFIJO = @PREFIJO
        )
        BEGIN
            -- Obtener el valor inicial de la tabla USCXS si existe
            SELECT @InicialValue = ISNULL(MAX(CONSECUTIVO), 1) + 1
            FROM USCXS WITH(NOLOCK)
            WHERE IDSEDE = @SEDE AND PREFIJO = @PREFIJO;

            -- Registrar en la tabla de control
            INSERT INTO SequenceControl (IDSEDE, PREFIJO, SequenceName, InicialValue)
            VALUES (@SEDE, @PREFIJO, @SequenceName, @InicialValue);

            -- Crear la secuencia con el valor inicial
            EXEC CreateSequenceIfNotExists @IDSEDE = @SEDE, @PREFIJO = @PREFIJO, @InicialValue = @InicialValue;
        END

        -- Construir la consulta para obtener el siguiente valor de la secuencia
        SET @sql = 'SELECT @NextValue = NEXT VALUE FOR ' + @SequenceName;
        SET @paramDef = N'@NextValue INT OUTPUT';

        -- Ejecutar la consulta para obtener el siguiente valor
        EXEC sp_executesql @sql, @paramDef, @NextValue OUTPUT;

        -- Asignar el valor al parámetro de salida
        SET @NVOCONSEC = CAST(@NextValue AS VARCHAR(20));

        -- Si el prefijo es '@MCP', ajusta el formato del consecutivo
        IF @PREFIJO = '@MCP'
        BEGIN
            SELECT @NVOCONSEC = CONVERT(VARCHAR, @@SPID) + REPLACE(SPACE(14 - LEN(@@SPID) - LEN(@NVOCONSEC)) + LTRIM(RTRIM(@NVOCONSEC)), SPACE(1), '0');
        END

        -- Formatear el consecutivo final
        IF @LLAMADO = 'NVO'
        BEGIN
           IF @PREFIJO = '@FCJ'
               SELECT @NVOCONSEC = REPLACE(SPACE(@LONGITUD - LEN(@NVOCONSEC)) + LTRIM(RTRIM(@NVOCONSEC)), SPACE(1), '0');
           ELSE
               SELECT @NVOCONSEC = @SEDE + CASE WHEN COALESCE(@EXTRA,'') = '' THEN '' ELSE TRIM(@EXTRA) END 
                              +REPLACE(SPACE(@LONGITUD - LEN(@NVOCONSEC)) + LTRIM(RTRIM(@NVOCONSEC)), SPACE(1), '0');
        END
        --ELSE
        --BEGIN
        --   SELECT @NVOCONSEC = REPLACE(SPACE(@LONGITUD - LEN(@NVOCONSEC)) + LTRIM(RTRIM(@NVOCONSEC)), SPACE(1), '0');
        --END

        --IF @trancount = 0 
        --    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        --IF @trancount = 0 
        --    ROLLBACK TRANSACTION;
        --ELSE
        --    IF XACT_STATE() <> -1
        --        ROLLBACK TRANSACTION USP_SPQ_GENSEQUENCE;
        THROW;
    END CATCH
END



