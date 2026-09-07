CREATE OR ALTER PROCEDURE DBO.SPK_FPAG
    @CNSFPAG VARCHAR(20)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Validación de entrada
    IF @CNSFPAG IS NULL OR LTRIM(RTRIM(@CNSFPAG)) = ''
    BEGIN
        RAISERROR('El parámetro @CNSFPAG es obligatorio y no puede estar vacío.', 16, 1);
        RETURN -1;
    END

    -- 2. Declaración e inicialización de variables
    DECLARE @VLRITEMS     DECIMAL(14,2) = 0,
            @VLRIMPUESTOS DECIMAL(14,2) = 0,
            @VLRGLOSAS    DECIMAL(14,2) = 0,
            @VLRDTOFIN    DECIMAL(14,2) = 0,
            @DIF          DECIMAL(14,2) = 0,
            @VALORPAGO    DECIMAL(14,2) = 0,
            @VLRAJUSTEPESO DECIMAL(14,2) = 0,
            @VLRTOTAL     DECIMAL(14,2) = 0,
            @AJPESO_CFG   VARCHAR(10),
            @MAX_AJUSTE   DECIMAL(14,2) = 0;

    BEGIN TRY
        BEGIN TRAN;

        -- 3. Lectura única de variables de configuración (evita múltiples llamadas a UDF)
        SELECT @AJPESO_CFG = UPPER(LTRIM(RTRIM(dbo.FNK_VALORVARIABLE('AJPESO_CON_IMPUESTOS')))),
               @MAX_AJUSTE  = TRY_CAST(UPPER(LTRIM(RTRIM(dbo.FNK_VALORVARIABLE('REC_VLRMAX_AJUSTE')))) AS DECIMAL(14,2));

        SET @MAX_AJUSTE = ISNULL(@MAX_AJUSTE, 0);

        -- 4. Agregación de valores desde la tabla de detalles
        SELECT @VLRITEMS     = ISNULL(SUM(VALORPAGO), 0),
               @VLRIMPUESTOS = ISNULL(SUM(VLRIMPUESTO), 0),
               @VLRGLOSAS    = ISNULL(SUM(VLRGLOSA), 0),
               @VLRDTOFIN    = ISNULL(SUM(VLRDTOFIN), 0)
        FROM   DBO.FPAGD
        WHERE  CNSFPAG = @CNSFPAG 
          AND  CLASEPAG = 'P';

        -- 5. Obtención del valor base del comprobante
        SELECT @VALORPAGO = VALORPAGO
        FROM   DBO.FPAG
        WHERE  CNSFPAG = @CNSFPAG;

        -- 6. Cálculo de la diferencia según configuración
        IF @AJPESO_CFG = 'SI'
            SET @DIF = @VALORPAGO + @VLRIMPUESTOS - @VLRITEMS;
        ELSE
            SET @DIF = @VALORPAGO - @VLRITEMS;

        -- 7. Determinación de ajuste y total
        IF ABS(@DIF) < @MAX_AJUSTE
        BEGIN
            SET @VLRAJUSTEPESO = @DIF;
            SET @VLRTOTAL      = @VALORPAGO - @VLRAJUSTEPESO;
        END
        ELSE
        BEGIN
            SET @VLRAJUSTEPESO = 0;
            SET @VLRTOTAL      = @VLRITEMS;
        END

        -- 8. Actualización atómica en una sola sentencia
        UPDATE DBO.FPAG 
        SET    VLRITEMS      = @VLRITEMS,
               VLRIMPUESTOS  = @VLRIMPUESTOS,        
               VLRGLOSAS     = @VLRGLOSAS, 
               VLRDTOFINAN   = @VLRDTOFIN,
               VLRAJUSTEPESO = @VLRAJUSTEPESO,
               VLRTOTAL      = @VLRTOTAL
        WHERE  CNSFPAG = @CNSFPAG;

        COMMIT TRAN;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        
        -- Registro de error (puedes redirigir a una tabla de logs si lo requieres)
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(),
                @ErrorSeverity INT = ERROR_SEVERITY(),
                @ErrorState    INT = ERROR_STATE();

        RAISERROR('Error en SPK_FPAG: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
        RETURN -1;
    END CATCH
END

