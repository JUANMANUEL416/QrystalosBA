CREATE OR ALTER PROCEDURE DBO.SPK_IZSOLDT_PROCESOS
    @IDARTICULO     VARCHAR(20),
    @CNSIZSOLD      VARCHAR(20),
    @PROCESO        VARCHAR(20),
    @IDSEDE         VARCHAR(5) = '01',
    @IDARTICULOREAL VARCHAR(20) = '',
    @NOLOTE         VARCHAR(20) = '',
    @CANTIDAD       DECIMAL(14,2) = 0.00,
    @CANTIDADSOL    DECIMAL(14,2) = 0.00,
    @CNSMOV         VARCHAR(20)  = '',
    @CNSIZSOLDT     VARCHAR(20)  = ''
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CANTACTUAL DECIMAL(14,2), @NVOCONSEC VARCHAR(20), @IDBODEGA VARCHAR(20);
    DECLARE @FALTA DECIMAL(14,2), @IDSERVAL VARCHAR(20), @LIBRE SMALLINT, @CAPACIDADBS DECIMAL(14,2);
    DECLARE @trancount INT = @@TRANCOUNT;

    BEGIN TRY
        IF @trancount = 0
            BEGIN TRANSACTION; -- Inicia una nueva transacción si no hay una en curso
        ELSE
            SAVE TRANSACTION SPK_IZSOLDT_PROCESOS; -- Guarda el punto de la transacción actual

        SELECT @IDBODEGA = IDBODEGA FROM IMOV WHERE CNSMOV = @CNSMOV;

        IF @PROCESO = 'CANCELAR'
        BEGIN
            UPDATE IEXI
            SET IEXI.EXISLOTE = IEXI.EXISLOTE + IZSOLDT.CANTIDADSOL
            FROM IEXI
            INNER JOIN IZSOLDT ON IEXI.IDARTICULO = IZSOLDT.IDARTICULOREAL
                              AND IEXI.NOLOTE = IZSOLDT.NOLOTE
                              AND IEXI.IDBODEGA = @IDBODEGA
            WHERE IZSOLDT.CNSIZSOLD = @CNSIZSOLD
            AND COALESCE(IZSOLDT.ESTADO, 0) = 0;

            DELETE FROM IZSOLDT
            WHERE IDARTICULO = @IDARTICULO AND CNSIZSOLD = @CNSIZSOLD AND ESTADO = 0;
        END
        ELSE IF @PROCESO = 'AGREGAR'
        BEGIN
            -- Guard crítico: @CANTIDAD NULL o <= 0 corrompería EXISLOTE silenciosamente (NULL - NULL = NULL)
            IF @CANTIDAD IS NULL OR @CANTIDAD <= 0
            BEGIN
                THROW 50005, 'La cantidad a entregar debe ser mayor a cero.', 1;
            END

            SELECT @CANTACTUAL = COALESCE(SUM(IZSOLDT.CANTIDADSOL), 0)
            FROM IZSOLDT
			INNER JOIN IZSOLD ON IZSOLDT.CNSIZSOLD = IZSOLD.CNSIZSOLD
            WHERE IZSOLDT.CNSIZSOLD = @CNSIZSOLD
            AND IZSOLDT.IDARTICULO = @IDARTICULO;

            IF @CANTACTUAL >= @CANTIDADSOL
            BEGIN 
                THROW 50000, 'Este Artículo ya tiene La Cantidad Cumplida.', 1
            END        

            SELECT @FALTA = @CANTIDADSOL - @CANTACTUAL;

            IF @CANTIDAD > @FALTA
            BEGIN
                THROW 50001, 'La Cantidad Supera lo Solicitado.', 1
            END

            IF NOT EXISTS (SELECT 1 FROM IEXI WHERE IDBODEGA = @IDBODEGA AND NOLOTE = @NOLOTE AND IDARTICULO = @IDARTICULOREAL)
            BEGIN
                SELECT @IDARTICULOREAL = IDARTICULO FROM IEXI WHERE NOLOTE = @NOLOTE AND IDBODEGA = @IDBODEGA;
            END

            /* Único descuento del lote en la dispensación. No pasa de la existencia
               y no resta más de una fila: si hay dos pedidos con stock, se devuelve todo. */

            SELECT @IDSERVAL = IDSERVICIO FROM IART WHERE IDARTICULO = @IDARTICULOREAL;

            IF @IDSERVAL <> DBO.FNK_VALORVARIABLE('DEINVNODESER')
            BEGIN
                IF @IDSERVAL <> @IDARTICULO
                BEGIN
                    IF (SELECT IDSERVICIO FROM IART WHERE IDARTICULO = @IDARTICULO) <> @IDSERVAL
                    BEGIN
                        THROW 50003, 'Inconsistencia en la Entrega idarticulo no corresponde a IDservicio.', 1;
                    END
                END
            END

            IF (SELECT COUNT(1) FROM IZSOLDT WHERE CNSIZSOLD = @CNSIZSOLD AND IDARTICULOREAL = @IDARTICULOREAL AND NOLOTE = @NOLOTE AND ESTADO = 0) > 0
            BEGIN
                UPDATE IZSOLDT
                SET CANTIDADSOL = CANTIDADSOL + @CANTIDAD
                WHERE IDARTICULOREAL = @IDARTICULOREAL AND NOLOTE = @NOLOTE AND CNSIZSOLD = @CNSIZSOLD AND ESTADO = 0;

                UPDATE IEXI
                SET IEXI.EXISLOTE = IEXI.EXISLOTE - @CANTIDAD
                WHERE IEXI.IDARTICULO = @IDARTICULOREAL AND IEXI.NOLOTE = @NOLOTE AND IEXI.IDBODEGA = @IDBODEGA
                  AND IEXI.EXISLOTE >= @CANTIDAD;

                IF @@ROWCOUNT <> 1
                    THROW 50002, 'El lote no cuenta con las cantidades a entregar.', 1;
            END
            ELSE
            BEGIN
				EXEC SPQ_GENSEQUENCE @SEDE = @IDSEDE, @PREFIJO = '@IZSOLDT', @LONGITUD = 8, @NVOCONSEC = @NVOCONSEC OUTPUT

                IF (SELECT IDITAR FROM IART WHERE IDARTICULO = @IDARTICULOREAL) = DBO.FNK_VALORVARIABLE('IDITARHEMODERIVADOS')
                BEGIN
                    SELECT @LIBRE = 0, @CAPACIDADBS = CAPACIDAD
                    FROM IEXI
                    WHERE IEXI.IDARTICULO = @IDARTICULOREAL AND IEXI.NOLOTE = @NOLOTE AND IEXI.IDBODEGA = @IDBODEGA;
                END
                ELSE
                BEGIN
                    SELECT @LIBRE = 0, @CAPACIDADBS = 0;
                END

                INSERT INTO IZSOLDT (CNSIZSOLDT, CNSIZSOLD, IDARTICULO, CANTIDADSOL, ESTADO, NOLOTE, IDARTICULOREAL, CNSMOV, LIBERADO, BSCAPACIDAD)
                VALUES (@NVOCONSEC, @CNSIZSOLD, @IDARTICULO, @CANTIDAD, 0, @NOLOTE, @IDARTICULOREAL, @CNSMOV, @LIBRE, @CAPACIDADBS);

                UPDATE IEXI
                SET IEXI.EXISLOTE = IEXI.EXISLOTE - @CANTIDAD
                WHERE IEXI.IDARTICULO = @IDARTICULOREAL AND IEXI.NOLOTE = @NOLOTE AND IEXI.IDBODEGA = @IDBODEGA
                  AND IEXI.EXISLOTE >= @CANTIDAD;

                IF @@ROWCOUNT <> 1
                    THROW 50002, 'El lote no cuenta con las cantidades a entregar.', 1;
            END
        END
        ELSE IF @PROCESO = 'QUITAR'
        BEGIN
            IF (SELECT COALESCE(LIBERADO, 0) FROM IZSOLDT WHERE CNSIZSOLDT = @CNSIZSOLDT) NOT IN (0, 2)
            BEGIN
                THROW 50004, 'El estado del registro no permite la operación.', 1;
            END

            UPDATE IEXI
            SET IEXI.EXISLOTE = IEXI.EXISLOTE + IZSOLDT.CANTIDADSOL
            FROM IEXI
            INNER JOIN IZSOLDT ON IEXI.IDARTICULO = IZSOLDT.IDARTICULOREAL
                              AND IEXI.NOLOTE = IZSOLDT.NOLOTE
                              AND IEXI.IDBODEGA = @IDBODEGA
            WHERE IZSOLDT.CNSIZSOLDT = @CNSIZSOLDT;

            DELETE FROM IZSOLDT WHERE CNSIZSOLDT = @CNSIZSOLDT;
        END

        IF @trancount = 0
            COMMIT TRANSACTION; -- Commitea la transacción si fue iniciada aquí
    END TRY
    BEGIN CATCH
        IF @trancount = 0
            ROLLBACK TRANSACTION; -- Hace rollback de la transacción si fue iniciada aquí
        ELSE
            IF XACT_STATE() <> -1
                ROLLBACK TRANSACTION SPK_IZSOLDT_PROCESOS; -- Hace rollback al punto guardado si se trata de una transacción anidada

        -- Propaga el error capturado
        THROW;
    END CATCH
END
