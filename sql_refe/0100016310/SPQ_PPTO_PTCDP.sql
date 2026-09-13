CREATE OR ALTER PROCEDURE DBO.SPQ_PPTO_PTCDP 
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
SET NOCOUNT ON;
SET DATEFORMAT dmy;

DECLARE @TBLERRORES TABLE (ERROR VARCHAR(MAX))
DECLARE @MENSAJE_ERROR VARCHAR(MAX)
DECLARE @MODELO VARCHAR(100), @METODO VARCHAR(100), @USUARIO VARCHAR(12)
DECLARE @PARAMETROS NVARCHAR(MAX), @REGISTRO NVARCHAR(MAX)
DECLARE @COMPANIA VARCHAR(2), @IDSEDE VARCHAR(5)
DECLARE @PROCESO VARCHAR(20), @CDP VARCHAR(21), @COMPANIA_REG VARCHAR(2), @CONSECUTIVO VARCHAR(20)
DECLARE @OBJETIVO VARCHAR(1023), @IDDEP VARCHAR(20), @VALOR DECIMAL(18,2), @SALDO DECIMAL(18,2)
DECLARE @FECHAEXPEDICION DATETIME, @FECHAVENCE DATETIME, @FECHAREINTEGRO DATETIME
DECLARE @AUTORIZADOR VARCHAR(20), @ESTADO VARCHAR(20), @CCOSTO VARCHAR(20), @CNSPTSCDP VARCHAR(20)
DECLARE @USUARIO_REG VARCHAR(12), @JEFEPTPTO VARCHAR(20), @IDTERCERO VARCHAR(20)
DECLARE @ITEM INT, @RUBRO VARCHAR(30), @RUBRO_ID VARCHAR(45), @RECURSO VARCHAR(20)
DECLARE @IDTIPOMOV VARCHAR(20), @VIGENCIA VARCHAR(20), @SOLICITANTE VARCHAR(20)
DECLARE @MOTIVO_LIBERACION VARCHAR(500), @FECHA_LIBERACION DATETIME
DECLARE @RP VARCHAR(20), @FECHARP DATETIME, @FECHAPLAZO DATETIME, @NODOCUMENTO VARCHAR(50)
DECLARE @ITEMCDPD INT, @CLASE VARCHAR(20)
DECLARE @CNSCXP VARCHAR(20), @FECHA_CXP DATETIME, @OBSERVACION VARCHAR(500)
DECLARE @ITEM_CXP INT
DECLARE @CNSPAGO VARCHAR(20), @FECHA_PAGO DATETIME, @ORIGENPAGO VARCHAR(50)
DECLARE @CODCAJA VARCHAR(5), @CNSFACJ VARCHAR(21), @BANCO VARCHAR(4)
DECLARE @SUCURSAL VARCHAR(3), @CTA_BCO VARCHAR(41), @ITEM_BMOV INT
DECLARE @ITEM_PAGO INT
DECLARE @VALOR_ANTERIOR DECIMAL(18,2), @VALOR_ANTERIOR_CXP DECIMAL(18,2), @VALOR_ANTERIOR_PAGO DECIMAL(18,2)
DECLARE @SALDO_DISPONIBLE DECIMAL(18,2)
DECLARE @PERMITE_DESCONF_CADENA VARCHAR(20)
DECLARE @TOT_CADENA DECIMAL(18,2)
DECLARE @DIF_CADENA DECIMAL(18,2)

BEGIN
    BEGIN TRY
        BEGIN TRANSACTION
        SELECT 
            @MODELO = MODELO,
            @METODO = METODO,
            @USUARIO = USUARIO,
            @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON) WITH (
            MODELO VARCHAR(100) '$.MODELO',
            METODO VARCHAR(100) '$.METODO',
            USUARIO VARCHAR(12) '$.USUARIO',
            PARAMETROS NVARCHAR(MAX) AS JSON
        )

        IF @METODO IS NULL OR @METODO = ''
        BEGIN
            INSERT INTO @TBLERRORES VALUES ('El METODO es requerido en el JSON')
            GOTO ERROR_HANDLER
        END

        IF @USUARIO IS NULL OR @USUARIO = ''
        BEGIN
            INSERT INTO @TBLERRORES VALUES ('El USUARIO es requerido en el JSON')
            GOTO ERROR_HANDLER
        END

        SELECT @COMPANIA = '01'
        SELECT @IDSEDE = NULL

        IF @METODO = 'CRUDPTCDP'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @CDP = CDP, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @OBJETIVO = OBJETIVO, @IDDEP = IDDEP, @VALOR = VALOR, @SALDO = SALDO,
                @FECHAEXPEDICION = CASE WHEN FECHAEXPEDICION IS NOT NULL AND FECHAEXPEDICION != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHAEXPEDICION)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @FECHAVENCE = CASE WHEN FECHAVENCE IS NOT NULL AND FECHAVENCE != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHAVENCE)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @FECHAREINTEGRO = CASE WHEN FECHAREINTEGRO IS NOT NULL AND FECHAREINTEGRO != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHAREINTEGRO)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @AUTORIZADOR = AUTORIZADOR, @ESTADO = ESTADO, @CCOSTO = CCOSTO,
                @CNSPTSCDP = CNSPTSCDP, @USUARIO_REG = USUARIO, @JEFEPTPTO = JEFEPTPTO,
                @IDTERCERO = IDTERCERO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', CDP VARCHAR(21) '$.CDP',
                COMPANIA VARCHAR(2) '$.COMPANIA', CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO',
                OBJETIVO VARCHAR(1023) '$.OBJETIVO', IDDEP VARCHAR(20) '$.IDDEP',
                VALOR DECIMAL(18,2) '$.VALOR', SALDO DECIMAL(18,2) '$.SALDO',
                FECHAEXPEDICION VARCHAR(50) '$.FECHAEXPEDICION', FECHAVENCE VARCHAR(50) '$.FECHAVENCE',
                FECHAREINTEGRO VARCHAR(50) '$.FECHAREINTEGRO', AUTORIZADOR VARCHAR(20) '$.AUTORIZADOR',
                ESTADO VARCHAR(20) '$.ESTADO', CCOSTO VARCHAR(20) '$.CCOSTO',
                CNSPTSCDP VARCHAR(20) '$.CNSPTSCDP', USUARIO VARCHAR(12) '$.USUARIO',
                JEFEPTPTO VARCHAR(20) '$.JEFEPTPTO', IDTERCERO VARCHAR(20) '$.IDTERCERO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @CCOSTO IS NULL OR @CCOSTO = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El centro de costo es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @FECHAEXPEDICION IS NULL
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('La fecha de expedicion es requerida')
                    GOTO ERROR_HANDLER
                END

                IF @CDP IS NULL OR @CDP = ''
                BEGIN
                    SELECT @CDP = SPACE(8)
                    EXEC SPK_GENCONSECUTIVO_PPTO @COMPANIA, @CONSECUTIVO, 'CDP', @CDP OUTPUT
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CDP ' + @CDP + ' ya existe para este presupuesto')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTCDP (
                        COMPANIA, CONSECUTIVO, CDP, OBJETIVO, IDDEP, VALOR, SALDO,
                        FECHAEXPEDICION, FECHAVENCE, FECHAREINTEGRO, AUTORIZADOR,
                        ESTADO, CCOSTO, CNSPTSCDP, USUARIO, JEFEPTPTO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @OBJETIVO, @IDDEP, 
                        ISNULL(@VALOR, 0), ISNULL(@SALDO, 0),
                        @FECHAEXPEDICION, @FECHAVENCE, @FECHAREINTEGRO, @AUTORIZADOR,
                        ISNULL(@ESTADO, 'NoConfirmado'), @CCOSTO, @CNSPTSCDP, 
                        ISNULL(@USUARIO_REG, @USUARIO), @JEFEPTPTO
                    )
                    SELECT 'OK' AS OK, @CDP AS CDP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CDP ' + ISNULL(@CDP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCDP SET
                        OBJETIVO = ISNULL(@OBJETIVO, OBJETIVO), IDDEP = ISNULL(@IDDEP, IDDEP),
                        VALOR = ISNULL(@VALOR, VALOR), SALDO = ISNULL(@SALDO, SALDO),
                        FECHAEXPEDICION = ISNULL(@FECHAEXPEDICION, FECHAEXPEDICION),
                        FECHAVENCE = ISNULL(@FECHAVENCE, FECHAVENCE),
                        FECHAREINTEGRO = ISNULL(@FECHAREINTEGRO, FECHAREINTEGRO),
                        AUTORIZADOR = ISNULL(@AUTORIZADOR, AUTORIZADOR),
                        CCOSTO = ISNULL(@CCOSTO, CCOSTO), CNSPTSCDP = ISNULL(@CNSPTSCDP, CNSPTSCDP),
                        USUARIO = ISNULL(@USUARIO_REG, USUARIO), JEFEPTPTO = ISNULL(@JEFEPTPTO, JEFEPTPTO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP
                    SELECT 'OK' AS OK, @CDP AS CDP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ANULAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CDP ' + ISNULL(@CDP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CDP ya est? anulado')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP
                    AND (VALOR_RP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede anular un CDP con saldos utilizados en detalles')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCDP SET ESTADO = 'Anulado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP
                    SELECT 'OK' AS OK, @CDP AS CDP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'CONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CDP ' + ISNULL(@CDP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede confirmar un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCDP SET ESTADO = 'Confirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP
                    SELECT 'OK' AS OK, @CDP AS CDP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'DESCONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES (CONCAT('El CDP ', ISNULL(@CDP, ''), ' no existe'))
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede desconfirmar un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                SET @PERMITE_DESCONF_CADENA = UPPER(LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('PPTO_CDP_DESCONFMOV'), 'NO'))))

                IF @PERMITE_DESCONF_CADENA <> 'SI'
                AND EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP
                    AND (VALOR_RP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede desconfirmar un CDP con saldos utilizados en detalles')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    IF @PERMITE_DESCONF_CADENA = 'SI'
                    BEGIN
                        UPDATE PTPAG
                        SET ESTADO = 'NoConfirmado',
                            USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ESTADO = 'Confirmado'

                        UPDATE PTCXP
                        SET ESTADO = 'NoConfirmado',
                            USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ESTADO = 'Confirmado'

                        UPDATE PTRP
                        SET ESTADO = 'NoConfirmado',
                            USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ESTADO = 'Confirmado'
                    END

                    UPDATE PTCDP
                    SET ESTADO = 'NoConfirmado',
                        USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG
                      AND CONSECUTIVO = @CONSECUTIVO
                      AND CDP = @CDP

                    SELECT 'OK' AS OK, @CDP AS CDP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT CONCAT(
                        'Motor SQL ', CAST(ERROR_NUMBER() AS VARCHAR(11)),
                        ', ', ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)'),
                        ', linea ', CAST(ERROR_LINE() AS VARCHAR(11)),
                        ': ', ERROR_MESSAGE()
                    )
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTCDPD'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @ITEM = ITEM, @RUBRO = RUBRO, @RUBRO_ID = RUBRO_ID,
                @RECURSO = RECURSO, @IDTIPOMOV = IDTIPOMOV, @VIGENCIA = VIGENCIA,
                @VALOR = VALOR, @SOLICITANTE = SOLICITANTE, @OBJETIVO = OBJETIVO,
                @CCOSTO = CCOSTO, @CLASE = CLASE, @SALDO = SALDO,@MOTIVO_LIBERACION = MOTIVO_LIBERACION,
                @FECHA_LIBERACION = CASE WHEN FECHA_LIBERACION IS NOT NULL AND FECHA_LIBERACION != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHA_LIBERACION)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                ITEM INT '$.ITEM', RUBRO VARCHAR(30) '$.RUBRO', RUBRO_ID VARCHAR(20) '$.RUBRO_ID',
                RECURSO VARCHAR(20) '$.RECURSO', IDTIPOMOV VARCHAR(20) '$.IDTIPOMOV',
                VIGENCIA VARCHAR(20) '$.VIGENCIA', VALOR DECIMAL(18,2) '$.VALOR',
                SOLICITANTE VARCHAR(20) '$.SOLICITANTE', OBJETIVO VARCHAR(1023) '$.OBJETIVO',
                CCOSTO VARCHAR(20) '$.CCOSTO', CLASE VARCHAR(20) '$.CLASE', SALDO DECIMAL(18,2) '$.SALDO',
                MOTIVO_LIBERACION VARCHAR(500) '$.MOTIVO_LIBERACION',
                FECHA_LIBERACION VARCHAR(50) '$.FECHA_LIBERACION', USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP ' + @CDP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @RUBRO IS NULL OR @RUBRO = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @RUBRO_ID IS NULL OR @RUBRO_ID = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El ID del rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @IDTIPOMOV IS NULL OR @IDTIPOMOV = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El tipo de movimiento es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF @SOLICITANTE IS NULL OR @SOLICITANTE = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El solicitante es requerido')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCDPD WITH (NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG
                      AND CONSECUTIVO = @CONSECUTIVO
                      AND CDP = @CDP
                      AND (
                          RUBRO_ID = TRY_CAST(@RUBRO_ID AS INT)
                          OR CAST(RUBRO_ID AS VARCHAR(45)) = @RUBRO_ID
                      )
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El rubro ya existe en este CDP')
                    GOTO ERROR_HANDLER
                END

                IF @CCOSTO IS NULL OR LTRIM(RTRIM(@CCOSTO)) = ''
                BEGIN
                    SELECT @CCOSTO = P.CCOSTO
                    FROM PTCDP P WITH (NOLOCK)
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                END

                SELECT TOP (1) @CLASE = LTRIM(RTRIM(C.CLASE))
                FROM PTPTOG C WITH (NOLOCK)
                WHERE C.COMPANIA = @COMPANIA_REG
                  AND C.CONSECUTIVO = @CONSECUTIVO
                  AND C.RUBRO = @RUBRO
                  AND (
                      @CCOSTO IS NULL
                      OR LTRIM(RTRIM(@CCOSTO)) = ''
                      OR C.CCOSTO = @CCOSTO
                  )
                ORDER BY
                    CASE WHEN C.CCOSTO = @CCOSTO THEN 0 ELSE 1 END,
                    C.CLASE ASC,
                    C.RUBRO ASC

                IF @CLASE IS NULL OR LTRIM(RTRIM(@CLASE)) = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES (
                        CONCAT(
                            'El rubro ',
                            @RUBRO,
                            ' no esta registrado en PTPTOG para el centro de costo ',
                            ISNULL(@CCOSTO, ''),
                            '.'
                        )
                    )
                    GOTO ERROR_HANDLER
                END

                SET @CLASE = LTRIM(RTRIM(@CLASE))

                SET @SALDO_DISPONIBLE = DBO.FNK_PPTO_SALDO_DISP_RUBRO(
                    @COMPANIA_REG,
                    @CONSECUTIVO,
                    @RUBRO_ID,
                    @CLASE,
                    @CDP,
                    NULL
                );
                IF @VALOR > @SALDO_DISPONIBLE
                BEGIN
                    INSERT INTO @TBLERRORES VALUES (
                        CONCAT(
                            'El valor supera el saldo disponible del rubro (',
                            CAST(@SALDO_DISPONIBLE AS VARCHAR(30)),
                            ')'
                        )
                    )
                    GOTO ERROR_HANDLER
                END

                IF @ITEM IS NULL OR @ITEM = 0
                BEGIN
                    SELECT @ITEM = ISNULL(MAX(ITEM), 0) + 1
                    FROM PTCDPD WITH (NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG
                      AND CONSECUTIVO = @CONSECUTIVO
                      AND CDP = @CDP
                END

                IF EXISTS (
                    SELECT 1
                    FROM PTCDPD WITH (NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG
                      AND CONSECUTIVO = @CONSECUTIVO
                      AND CDP = @CDP
                      AND ITEM = @ITEM
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES (
                        CONCAT('El detalle con item ', CAST(@ITEM AS VARCHAR(20)), ' ya existe para este CDP')
                    )
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTCDPD (
                        COMPANIA, CONSECUTIVO, CDP, ITEM, CLASE, RUBRO, RUBRO_ID, RECURSO,
                        IDTIPOMOV, VIGENCIA, VALOR, SALDO, SOLICITANTE, OBJETIVO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @ITEM, @CLASE, @RUBRO, @RUBRO_ID, @RECURSO,
                        @IDTIPOMOV, ISNULL(@VIGENCIA, 'Actual'), @VALOR, @VALOR, @SOLICITANTE, @OBJETIVO
                    )

                   UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCDP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCDPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP

                    SELECT 'OK' AS OK, CAST(@ITEM AS VARCHAR(20)) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT CONCAT(
                        'Motor SQL ',
                        CAST(ERROR_NUMBER() AS VARCHAR(11)),
                        ', ',
                        ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)'),
                        ', linea ',
                        CAST(ERROR_LINE() AS VARCHAR(11)),
                        ': ',
                        ERROR_MESSAGE()
                    )
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un detalle de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                SELECT
                    @VALOR_ANTERIOR = VALOR,
                    @RUBRO = ISNULL(NULLIF(LTRIM(RTRIM(@RUBRO)), ''), RUBRO),
                    @RUBRO_ID = ISNULL(NULLIF(LTRIM(RTRIM(@RUBRO_ID)), ''), CAST(RUBRO_ID AS VARCHAR(45))),
                    @CLASE = ISNULL(NULLIF(LTRIM(RTRIM(@CLASE)), ''), CLASE)
                FROM PTCDPD WITH (NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG
                  AND CONSECUTIVO = @CONSECUTIVO
                  AND CDP = @CDP
                  AND ITEM = @ITEM

                IF @VALOR IS NOT NULL AND @VALOR > 0
                BEGIN
                    SET @SALDO_DISPONIBLE = DBO.FNK_PPTO_SALDO_DISP_RUBRO(
                        @COMPANIA_REG,
                        @CONSECUTIVO,
                        @RUBRO_ID,
                        @CLASE,
                        @CDP,
                        @ITEM
                    );
                    IF @VALOR > @SALDO_DISPONIBLE
                    BEGIN
                        INSERT INTO @TBLERRORES VALUES (
                            CONCAT(
                                'El valor supera el saldo disponible del rubro (',
                                CAST(@SALDO_DISPONIBLE AS VARCHAR(30)),
                                ')'
                            )
                        )
                        GOTO ERROR_HANDLER
                    END
                END

                SET @PERMITE_DESCONF_CADENA = UPPER(LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('PPTO_CDP_DESCONFMOV'), 'NO'))))

                IF @PERMITE_DESCONF_CADENA = 'SI'
                   AND @VALOR IS NOT NULL
                   AND EXISTS (
                        SELECT 1 FROM PTCDPD WITH(NOLOCK)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ITEM = @ITEM
                          AND ISNULL(VLR_LIBERADO, 0) > @VALOR
                   )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede reducir el valor por debajo del valor liberado del rubro')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    IF @PERMITE_DESCONF_CADENA = 'SI' AND @VALOR IS NOT NULL AND @VALOR > 0
                    BEGIN
                        SELECT @TOT_CADENA = ISNULL(SUM(VALOR), 0)
                        FROM PTPAGD WITH(NOLOCK)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ITEMCDPD = @ITEM

                        IF @TOT_CADENA > @VALOR AND @TOT_CADENA > 0
                        BEGIN
                            UPDATE PTPAGD
                            SET VALOR = ROUND(VALOR * (@VALOR / @TOT_CADENA), 2)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            SELECT @DIF_CADENA = @VALOR - ISNULL(SUM(VALOR), 0)
                            FROM PTPAGD WITH(NOLOCK)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            ;WITH tgt AS (
                                SELECT TOP (1) *
                                FROM PTPAGD
                                WHERE COMPANIA = @COMPANIA_REG
                                  AND CONSECUTIVO = @CONSECUTIVO
                                  AND CDP = @CDP
                                  AND ITEMCDPD = @ITEM
                                ORDER BY CNSPAGO DESC, ITEM DESC
                            )
                            UPDATE tgt SET VALOR = VALOR + ISNULL(@DIF_CADENA, 0)

                            UPDATE P
                            SET P.VALOR = ISNULL(agg.TOT_VALOR, 0)
                            FROM PTPAG P
                            OUTER APPLY (
                                SELECT SUM(D.VALOR) AS TOT_VALOR
                                FROM PTPAGD D
                                WHERE D.COMPANIA = P.COMPANIA
                                  AND D.CONSECUTIVO = P.CONSECUTIVO
                                  AND D.CDP = P.CDP
                                  AND D.RP = P.RP
                                  AND D.CNSCXP = P.CNSCXP
                                  AND D.CNSPAGO = P.CNSPAGO
                            ) agg
                            WHERE P.COMPANIA = @COMPANIA_REG
                              AND P.CONSECUTIVO = @CONSECUTIVO
                              AND P.CDP = @CDP
                              AND EXISTS (
                                  SELECT 1 FROM PTPAGD X
                                  WHERE X.COMPANIA = P.COMPANIA
                                    AND X.CONSECUTIVO = P.CONSECUTIVO
                                    AND X.CDP = P.CDP
                                    AND X.RP = P.RP
                                    AND X.CNSCXP = P.CNSCXP
                                    AND X.CNSPAGO = P.CNSPAGO
                                    AND X.ITEMCDPD = @ITEM
                              )
                        END

                        UPDATE C
                        SET C.VALOR_PAG = ISNULL(agg.TOT_PAG, 0)
                        FROM PTCXPD C
                        OUTER APPLY (
                            SELECT SUM(D.VALOR) AS TOT_PAG
                            FROM PTPAGD D
                            WHERE D.COMPANIA = C.COMPANIA
                              AND D.CONSECUTIVO = C.CONSECUTIVO
                              AND D.CDP = C.CDP
                              AND D.RP = C.RP
                              AND D.CNSCXP = C.CNSCXP
                              AND D.ITEMCDPD = C.ITEMCDPD
                        ) agg
                        WHERE C.COMPANIA = @COMPANIA_REG
                          AND C.CONSECUTIVO = @CONSECUTIVO
                          AND C.CDP = @CDP
                          AND C.ITEMCDPD = @ITEM

                        SELECT @TOT_CADENA = ISNULL(SUM(VALOR), 0)
                        FROM PTCXPD WITH(NOLOCK)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ITEMCDPD = @ITEM

                        IF @TOT_CADENA > @VALOR AND @TOT_CADENA > 0
                        BEGIN
                            UPDATE PTCXPD
                            SET VALOR = ROUND(VALOR * (@VALOR / @TOT_CADENA), 2)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            SELECT @DIF_CADENA = @VALOR - ISNULL(SUM(VALOR), 0)
                            FROM PTCXPD WITH(NOLOCK)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            ;WITH tgt AS (
                                SELECT TOP (1) *
                                FROM PTCXPD
                                WHERE COMPANIA = @COMPANIA_REG
                                  AND CONSECUTIVO = @CONSECUTIVO
                                  AND CDP = @CDP
                                  AND ITEMCDPD = @ITEM
                                ORDER BY CNSCXP DESC, ITEM DESC
                            )
                            UPDATE tgt SET VALOR = VALOR + ISNULL(@DIF_CADENA, 0)
                        END

                        UPDATE C
                        SET C.SALDO = ISNULL(C.VALOR, 0) - ISNULL(C.VALOR_PAG, 0) - ISNULL(C.VLR_LIBERADO, 0)
                        FROM PTCXPD C
                        WHERE C.COMPANIA = @COMPANIA_REG
                          AND C.CONSECUTIVO = @CONSECUTIVO
                          AND C.CDP = @CDP
                          AND C.ITEMCDPD = @ITEM

                        UPDATE P
                        SET
                            P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                            P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                        FROM PTCXP P
                        OUTER APPLY (
                            SELECT
                                SUM(D.VALOR) AS TOT_VALOR,
                                SUM(D.SALDO) AS TOT_SALDO
                            FROM PTCXPD D
                            WHERE D.COMPANIA = P.COMPANIA
                              AND D.CONSECUTIVO = P.CONSECUTIVO
                              AND D.CDP = P.CDP
                              AND D.RP = P.RP
                              AND D.CNSCXP = P.CNSCXP
                        ) agg
                        WHERE P.COMPANIA = @COMPANIA_REG
                          AND P.CONSECUTIVO = @CONSECUTIVO
                          AND P.CDP = @CDP
                          AND EXISTS (
                              SELECT 1 FROM PTCXPD X
                              WHERE X.COMPANIA = P.COMPANIA
                                AND X.CONSECUTIVO = P.CONSECUTIVO
                                AND X.CDP = P.CDP
                                AND X.RP = P.RP
                                AND X.CNSCXP = P.CNSCXP
                                AND X.ITEMCDPD = @ITEM
                          )

                        UPDATE R
                        SET R.VALOR_CXP = ISNULL(agg.TOT_CXP, 0)
                        FROM PTRPD R
                        OUTER APPLY (
                            SELECT SUM(D.VALOR) AS TOT_CXP
                            FROM PTCXPD D
                            WHERE D.COMPANIA = R.COMPANIA
                              AND D.CONSECUTIVO = R.CONSECUTIVO
                              AND D.CDP = R.CDP
                              AND D.RP = R.RP
                              AND D.ITEMCDPD = R.ITEMCDPD
                        ) agg
                        WHERE R.COMPANIA = @COMPANIA_REG
                          AND R.CONSECUTIVO = @CONSECUTIVO
                          AND R.CDP = @CDP
                          AND R.ITEMCDPD = @ITEM

                        SELECT @TOT_CADENA = ISNULL(SUM(VALOR), 0)
                        FROM PTRPD WITH(NOLOCK)
                        WHERE COMPANIA = @COMPANIA_REG
                          AND CONSECUTIVO = @CONSECUTIVO
                          AND CDP = @CDP
                          AND ITEMCDPD = @ITEM

                        IF @TOT_CADENA > @VALOR AND @TOT_CADENA > 0
                        BEGIN
                            UPDATE PTRPD
                            SET VALOR = ROUND(VALOR * (@VALOR / @TOT_CADENA), 2)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            SELECT @DIF_CADENA = @VALOR - ISNULL(SUM(VALOR), 0)
                            FROM PTRPD WITH(NOLOCK)
                            WHERE COMPANIA = @COMPANIA_REG
                              AND CONSECUTIVO = @CONSECUTIVO
                              AND CDP = @CDP
                              AND ITEMCDPD = @ITEM

                            ;WITH tgt AS (
                                SELECT TOP (1) *
                                FROM PTRPD
                                WHERE COMPANIA = @COMPANIA_REG
                                  AND CONSECUTIVO = @CONSECUTIVO
                                  AND CDP = @CDP
                                  AND ITEMCDPD = @ITEM
                                ORDER BY RP DESC, ITEMCDPD DESC
                            )
                            UPDATE tgt SET VALOR = VALOR + ISNULL(@DIF_CADENA, 0)
                        END

                        UPDATE P
                        SET
                            P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                            P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                        FROM PTRP P
                        OUTER APPLY (
                            SELECT
                                SUM(D.VALOR) AS TOT_VALOR,
                                SUM(ISNULL(D.VALOR, 0) - ISNULL(D.VALOR_CXP, 0) - ISNULL(D.VLR_LIBERADO, 0)) AS TOT_SALDO
                            FROM PTRPD D
                            WHERE D.COMPANIA = P.COMPANIA
                              AND D.CONSECUTIVO = P.CONSECUTIVO
                              AND D.CDP = P.CDP
                              AND D.RP = P.RP
                        ) agg
                        WHERE P.COMPANIA = @COMPANIA_REG
                          AND P.CONSECUTIVO = @CONSECUTIVO
                          AND P.CDP = @CDP
                          AND EXISTS (
                              SELECT 1 FROM PTRPD X
                              WHERE X.COMPANIA = P.COMPANIA
                                AND X.CONSECUTIVO = P.CONSECUTIVO
                                AND X.CDP = P.CDP
                                AND X.RP = P.RP
                                AND X.ITEMCDPD = @ITEM
                          )
                    END

                    UPDATE D
                    SET
                        RUBRO = ISNULL(@RUBRO, RUBRO),
                        RUBRO_ID = ISNULL(@RUBRO_ID, RUBRO_ID),
                        RECURSO = ISNULL(@RECURSO, RECURSO),
                        IDTIPOMOV = ISNULL(@IDTIPOMOV, IDTIPOMOV),
                        VIGENCIA = ISNULL(@VIGENCIA, VIGENCIA),
                        VALOR = ISNULL(@VALOR, VALOR),
                        VALOR_RP = CASE
                            WHEN @PERMITE_DESCONF_CADENA = 'SI' THEN ISNULL(agg.TOT_RP, 0)
                            ELSE D.VALOR_RP
                        END,
                        SALDO = ISNULL(@VALOR, VALOR)
                            - CASE
                                WHEN @PERMITE_DESCONF_CADENA = 'SI' THEN ISNULL(agg.TOT_RP, 0)
                                ELSE ISNULL(D.VALOR_RP, 0)
                              END
                            - ISNULL(D.VLR_LIBERADO, 0),
                        SOLICITANTE = ISNULL(@SOLICITANTE, SOLICITANTE),
                        OBJETIVO = ISNULL(@OBJETIVO, OBJETIVO)
                    FROM PTCDPD D
                    OUTER APPLY (
                        SELECT SUM(R.VALOR) AS TOT_RP
                        FROM PTRPD R
                        WHERE R.COMPANIA = D.COMPANIA
                          AND R.CONSECUTIVO = D.CONSECUTIVO
                          AND R.CDP = D.CDP
                          AND R.ITEMCDPD = D.ITEM
                    ) agg
                    WHERE D.COMPANIA = @COMPANIA_REG
                      AND D.CONSECUTIVO = @CONSECUTIVO
                      AND D.CDP = @CDP
                      AND D.ITEM = @ITEM

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCDP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCDPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP

                    SELECT 'OK' AS OK, CAST(@ITEM AS VARCHAR(20)) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT CONCAT(
                        'Motor SQL ', CAST(ERROR_NUMBER() AS VARCHAR(11)),
                        ', ', ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)'),
                        ', linea ', CAST(ERROR_LINE() AS VARCHAR(11)),
                        ': ', ERROR_MESSAGE()
                    )
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un detalle de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM
                    AND (VALOR_RP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un detalle con saldo utilizado')
                    GOTO ERROR_HANDLER
                END

                SELECT @VALOR = VALOR FROM PTCDPD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM

                BEGIN TRY
                    DELETE FROM PTCDPD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCDP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCDPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP

                    SELECT 'OK' AS OK, CAST(@ITEM AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'LIBERAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTCDPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF @MOTIVO_LIBERACION IS NULL OR @MOTIVO_LIBERACION = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El motivo de liberaci?n es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @FECHA_LIBERACION IS NULL
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('La fecha de liberaci?n es requerida')
                    GOTO ERROR_HANDLER
                END

                SELECT @SALDO_DISPONIBLE = SALDO FROM PTCDPD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM

                IF @SALDO_DISPONIBLE <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No hay saldo disponible para liberar')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCDPD SET
                        VLR_LIBERADO = ISNULL(VLR_LIBERADO, 0) + @SALDO_DISPONIBLE, SALDO = 0
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ITEM = @ITEM

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCDP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCDPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP

                    SELECT 'OK' AS OK, CAST(@ITEM AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'CONSULTA_SALDO'
            BEGIN
                IF @RUBRO_ID IS NULL OR @RUBRO_ID = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El ID del rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @CCOSTO IS NULL OR @CCOSTO = ''
                    SELECT @CCOSTO = CCOSTO FROM PTCDP
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP

                SELECT TOP (1) @CLASE = C.CLASE
                FROM PTPTOG C WITH (NOLOCK)
                WHERE C.COMPANIA = @COMPANIA_REG
                  AND C.CONSECUTIVO = @CONSECUTIVO
                  AND C.RUBRO = @RUBRO
                  AND C.CCOSTO = @CCOSTO
                ORDER BY C.CLASE ASC

                IF @CLASE IS NULL OR LTRIM(RTRIM(@CLASE)) = ''
                BEGIN
                    GOTO ERROR_HANDLER
                END

                SET @SALDO_DISPONIBLE = DBO.FNK_PPTO_SALDO_DISP_RUBRO(
                      @COMPANIA_REG,
                      @CONSECUTIVO,
                      @RUBRO_ID,
                      @CLASE,
                      @CDP,
                      @ITEM
                  );
        
                SET @SALDO_DISPONIBLE = DBO.FNK_PPTO_SALDO_DISP_RUBRO(
                    @COMPANIA_REG, @CONSECUTIVO, @RUBRO_ID, @CLASE, @CDP, @ITEM
                );
                IF @SALDO_DISPONIBLE < 0 SET @SALDO_DISPONIBLE = 0;

                SELECT
                    'OK' AS OK,
                    NULL AS ITEM,
                    @SALDO_DISPONIBLE AS SALDO,
                    @SALDO_DISPONIBLE AS VALOR,
                    NULL AS ERROR;
            END

            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTRP'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
           SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @CCOSTO = CCOSTO,
                @FECHARP = CASE WHEN FECHARP IS NOT NULL AND FECHARP != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHARP)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @FECHAPLAZO = CASE WHEN FECHAPLAZO IS NOT NULL AND FECHAPLAZO != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHAPLAZO)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @OBJETIVO = OBJETIVO, @SOLICITANTE = SOLICITANTE,
                @IDTERCERO = IDTERCERO, @NODOCUMENTO = NODOCUMENTO,
                @VALOR = VALOR, @SALDO = SALDO, @ESTADO = ESTADO,
                @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', CCOSTO VARCHAR(20) '$.CCOSTO',
                FECHARP VARCHAR(50) '$.FECHARP', FECHAPLAZO VARCHAR(50) '$.FECHAPLAZO',
                OBJETIVO VARCHAR(1023) '$.OBJETIVO', SOLICITANTE VARCHAR(20) '$.SOLICITANTE',
                IDTERCERO VARCHAR(20) '$.IDTERCERO', NODOCUMENTO VARCHAR(50) '$.NODOCUMENTO',
                VALOR DECIMAL(18,2) '$.VALOR', SALDO DECIMAL(18,2) '$.SALDO',
                ESTADO VARCHAR(20) '$.ESTADO',
                USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP ' + @CDP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @FECHARP IS NULL
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('La fecha RP es requerida')
                    GOTO ERROR_HANDLER
                END

                IF @RP IS NULL OR @RP = ''
                BEGIN
                    SELECT @RP = SPACE(8)
                    EXEC SPK_GENCONSECUTIVO_PPTO @COMPANIA_REG, @CONSECUTIVO, 'RP', @RP OUTPUT
                END

                IF EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El RP ' + @RP + ' ya existe para este CDP')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTRP (
                        COMPANIA, CONSECUTIVO, CDP, RP, CCOSTO, FECHARP, FECHAPLAZO,
                        OBJETIVO, SOLICITANTE, IDTERCERO, NODOCUMENTO,
                        VALOR, SALDO, ESTADO, USUARIO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @CCOSTO, @FECHARP, @FECHAPLAZO,
                        @OBJETIVO, @SOLICITANTE, @IDTERCERO, @NODOCUMENTO,
                        ISNULL(@VALOR, 0), ISNULL(@SALDO, 0),
                        ISNULL(NULLIF(LTRIM(RTRIM(@ESTADO)), ''), 'NoConfirmado'),
                        ISNULL(@USUARIO_REG, @USUARIO)
                    )
                    SELECT 'OK' AS OK, @RP AS RP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El RP ' + ISNULL(@RP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un RP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTRP SET
                        CCOSTO = ISNULL(@CCOSTO, CCOSTO), FECHARP = ISNULL(@FECHARP, FECHARP),
                        FECHAPLAZO = ISNULL(@FECHAPLAZO, FECHAPLAZO), OBJETIVO = ISNULL(@OBJETIVO, OBJETIVO),
                        SOLICITANTE = ISNULL(@SOLICITANTE, SOLICITANTE), IDTERCERO = ISNULL(@IDTERCERO, IDTERCERO),
                        NODOCUMENTO = ISNULL(@NODOCUMENTO, NODOCUMENTO), USUARIO = ISNULL(@USUARIO_REG, USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP
                    SELECT 'OK' AS OK, @RP AS RP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El RP ' + ISNULL(@RP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un RP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP
                    AND (VALOR_CXP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un RP con valores utilizados en detalles')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    DELETE FROM PTRPD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP

                    DELETE FROM PTRP
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP
                    SELECT 'OK' AS OK, @RP AS RP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'CONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El RP ' + ISNULL(@RP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede confirmar un RP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTRP SET ESTADO = 'Confirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP
                    SELECT 'OK' AS OK, @RP AS RP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'DESCONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El RP ' + ISNULL(@RP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede desconfirmar un RP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTRP SET ESTADO = 'NoConfirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP
                    SELECT 'OK' AS OK, @RP AS RP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTRPD'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @ITEMCDPD = ITEMCDPD, @RUBRO = RUBRO,
                @RUBRO_ID = RUBRO_ID, @CLASE = CLASE, @VALOR = VALOR, @SALDO = SALDO, @ESTADO = ESTADO,
                @OBJETIVO = OBJETIVO, @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', ITEMCDPD INT '$.ITEMCDPD',
                RUBRO VARCHAR(30) '$.RUBRO', RUBRO_ID VARCHAR(20) '$.RUBRO_ID',
                CLASE VARCHAR(20) '$.CLASE', VALOR DECIMAL(18,2) '$.VALOR', 
                SALDO DECIMAL(18,2) '$.SALDO',ESTADO VARCHAR(20) '$.ESTADO',
                OBJETIVO VARCHAR(1023) '$.OBJETIVO', USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @RP IS NULL OR @RP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El RP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTRP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El RP ' + @RP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('No se puede modificar un detalle de RP de un CDP anulado')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @RUBRO IS NULL OR @RUBRO = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @RUBRO_ID IS NULL OR @RUBRO_ID = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El ID del rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF @ITEMCDPD IS NULL OR @ITEMCDPD = 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No Existe item Asociado a este Rp, no se puede continuar')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEMCDPD AS VARCHAR) + ' ya existe para este RP')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTRPD (
                        COMPANIA, CONSECUTIVO, CDP, RP, ITEMCDPD, RUBRO, RUBRO_ID, CLASE, VALOR, OBJETIVO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @ITEMCDPD, @RUBRO, @RUBRO_ID, @CLASE, @VALOR, @OBJETIVO
                    )
                    SELECT 'OK' AS OK, @ITEMCDPD AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEMCDPD AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                    AND (VALOR_CXP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un detalle con valores utilizados')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTRPD SET
                        RUBRO = ISNULL(@RUBRO, RUBRO), RUBRO_ID = ISNULL(@RUBRO_ID, RUBRO_ID),
                        CLASE = ISNULL(@CLASE, CLASE), VALOR = @VALOR, OBJETIVO = ISNULL(@OBJETIVO, OBJETIVO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                    SELECT 'OK' AS OK, @ITEMCDPD AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEMCDPD AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTRPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                    AND (VALOR_CXP > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un detalle con valores utilizados')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    DELETE FROM PTRPD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND ITEMCDPD = @ITEMCDPD
                    SELECT 'OK' AS OK, @ITEMCDPD AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTCXP'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @CNSCXP = CNSCXP,
                @FECHA_CXP = CASE WHEN FECHA IS NOT NULL AND FECHA != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHA)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @VALOR = VALOR, @SALDO = SALDO, @OBSERVACION = OBSERVACION,
                @ESTADO = ESTADO, @CCOSTO = CCOSTO, @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', CNSCXP VARCHAR(20) '$.CNSCXP',
                FECHA VARCHAR(50) '$.FECHA', VALOR DECIMAL(18,2) '$.VALOR',
                SALDO DECIMAL(18,2) '$.SALDO', OBSERVACION VARCHAR(500) '$.OBSERVACION',
                ESTADO VARCHAR(20) '$.ESTADO', CCOSTO VARCHAR(20) '$.CCOSTO',
                USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP ' + @CDP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @FECHA_CXP IS NULL
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('La fecha es requerida')
                    GOTO ERROR_HANDLER
                END

                IF @CNSCXP IS NULL OR @CNSCXP = ''
                BEGIN
                    SELECT @CNSCXP = SPACE(8)
                    EXEC SPK_GENCONSECUTIVO_PPTO @COMPANIA_REG, @CONSECUTIVO, 'CXP', @CNSCXP OUTPUT
                END

                IF EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + @CNSCXP + ' ya existe para este RP')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTCXP (
                        COMPANIA, CONSECUTIVO, CDP, RP, CNSCXP, FECHA, VALOR, SALDO, OBSERVACION, ESTADO, CCOSTO, USUARIO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @CNSCXP, @FECHA_CXP, 
                        ISNULL(@VALOR, 0), ISNULL(@SALDO, 0), @OBSERVACION, 
                        ISNULL(@ESTADO, 'NoConfirmado'), @CCOSTO, ISNULL(@USUARIO_REG, @USUARIO)
                    )
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + ISNULL(@CNSCXP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un CXP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCXP SET
                        FECHA = ISNULL(@FECHA_CXP, FECHA), VALOR = ISNULL(@VALOR, VALOR),
                        SALDO = ISNULL(@SALDO, SALDO), OBSERVACION = ISNULL(@OBSERVACION, OBSERVACION),
                        CCOSTO = ISNULL(@CCOSTO, CCOSTO), USUARIO = ISNULL(@USUARIO_REG, USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + ISNULL(@CNSCXP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un CXP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    AND (VALOR_PAG > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un CXP con valores utilizados en detalles')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    DELETE FROM PTCXPD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP

                    DELETE FROM PTCXP
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ANULAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + ISNULL(@CNSCXP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede anular un CXP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    AND (VALOR_PAG > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede anular un CXP con valores utilizados en detalles')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCXP SET ESTADO = 'Anulado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'CONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + ISNULL(@CNSCXP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede confirmar un CXP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCXP SET ESTADO = 'Confirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'DESCONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El CXP ' + ISNULL(@CNSCXP, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede desconfirmar un CXP de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTCXP SET ESTADO = 'NoConfirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTCXPD'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @CNSCXP = CNSCXP, @ITEM_CXP = ITEM,
                @ITEMCDPD = ITEMCDPD,@RUBRO=RUBRO, @RUBRO_ID = RUBRO_ID, @CLASE = CLASE,
                @VALOR = VALOR, @SALDO = SALDO, @OBSERVACION = OBSERVACION,
                @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', CNSCXP VARCHAR(20) '$.CNSCXP',
                ITEM INT '$.ITEM', ITEMCDPD INT '$.ITEMCDPD',
                RUBRO_ID VARCHAR(20) '$.RUBRO_ID',RUBRO  VARCHAR(45)   '$.RUBRO', CLASE VARCHAR(20) '$.CLASE',
                VALOR DECIMAL(18,2) '$.VALOR', SALDO DECIMAL(18,2) '$.SALDO',
                OBSERVACION VARCHAR(500) '$.OBSERVACION', USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @RP IS NULL OR @RP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El RP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CNSCXP IS NULL OR @CNSCXP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CNSCXP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CXP ' + @CNSCXP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('No se puede modificar un detalle de CXP de un CDP anulado')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @RUBRO_ID IS NULL OR @RUBRO_ID = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El ID del rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @ITEMCDPD IS NULL OR @ITEMCDPD = 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Item CDPD es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF @ITEM_CXP IS NULL OR @ITEM_CXP = 0
                BEGIN
                    SELECT @ITEM_CXP = ISNULL(MAX(ITEM), 0) + 1
                    FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                END

                IF EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_CXP AS VARCHAR) + ' ya existe para este CXP')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTCXPD (
                        COMPANIA, CONSECUTIVO, CDP, RP, CNSCXP, ITEM, ITEMCDPD,RUBRO, RUBRO_ID, CLASE, VALOR, SALDO, OBSERVACION
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @CNSCXP, @ITEM_CXP, @ITEMCDPD,@RUBRO, @RUBRO_ID, @CLASE, @VALOR, @VALOR, @OBSERVACION
                    )

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCXP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCXPD D
                        WHERE D.COMPANIA = P.COMPANIA
                            AND D.CONSECUTIVO = P.CONSECUTIVO
                            AND D.CDP = P.CDP
                            AND D.RP = P.RP
                            AND D.CNSCXP = P.CNSCXP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                        AND P.CONSECUTIVO = @CONSECUTIVO
                        AND P.CDP = @CDP
                        AND P.RP = @RP
                        AND P.CNSCXP = @CNSCXP

                    SELECT 'OK' AS OK, CAST(@ITEM_CXP AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_CXP AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP
                    AND (VALOR_PAG > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un detalle con valores utilizados')
                    GOTO ERROR_HANDLER
                END

                SELECT @VALOR_ANTERIOR_CXP = COALESCE(VALOR,0) FROM PTCXPD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP

                BEGIN TRY
                    UPDATE PTCXPD SET
                        RUBRO_ID = ISNULL(@RUBRO_ID, RUBRO_ID), CLASE = ISNULL(@CLASE, CLASE),
                        VALOR = @VALOR,
                        SALDO = @VALOR - COALESCE(VALOR_PAG, 0) - COALESCE(VLR_LIBERADO, 0),
                        OBSERVACION = ISNULL(@OBSERVACION, OBSERVACION)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCXP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCXPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                          AND D.RP = P.RP
                          AND D.CNSCXP = P.CNSCXP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                      AND P.RP = @RP
                      AND P.CNSCXP = @CNSCXP

                    SELECT 'OK' AS OK, CAST(@ITEM_CXP AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_CXP AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (
                    SELECT 1 FROM PTCXPD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP
                    AND (VALOR_PAG > 0 OR VLR_LIBERADO > 0)
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un detalle con valores utilizados')
                    GOTO ERROR_HANDLER
                END

                SELECT @VALOR = VALOR FROM PTCXPD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP

                BEGIN TRY
                    DELETE FROM PTCXPD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND ITEM = @ITEM_CXP

                    UPDATE P
                    SET
                        P.VALOR = ISNULL(agg.TOT_VALOR, 0),
                        P.SALDO = ISNULL(agg.TOT_SALDO, 0)
                    FROM PTCXP P
                    OUTER APPLY (
                        SELECT
                            SUM(D.VALOR) AS TOT_VALOR,
                            SUM(D.SALDO) AS TOT_SALDO
                        FROM PTCXPD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                          AND D.RP = P.RP
                          AND D.CNSCXP = P.CNSCXP
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                      AND P.RP = @RP
                      AND P.CNSCXP = @CNSCXP

                    SELECT 'OK' AS OK, CAST(@ITEM_CXP AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ANULAR'
            BEGIN
                BEGIN TRY
                    UPDATE PTCXP SET ESTADO = 'Anulado'
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP
                    SELECT 'OK' AS OK, @CNSCXP AS CNSCXP, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTPAG'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @CNSCXP = CNSCXP, @CNSPAGO = CNSPAGO,
                @FECHA_PAGO = CASE WHEN FECHA IS NOT NULL AND FECHA != '' THEN CONVERT(DATETIME, CONVERT(DATE, FECHA)) + CONVERT(DATETIME, CAST(GETDATE() AS TIME)) ELSE NULL END,
                @VALOR = VALOR, @OBSERVACION = OBSERVACION, @ORIGENPAGO = ORIGENPAGO,
                @ESTADO = ESTADO, @CCOSTO = CCOSTO, @CODCAJA = CODCAJA,
                @CNSFACJ = CNSFACJ, @BANCO = BANCO, @SUCURSAL = SUCURSAL,
                @CTA_BCO = CTA_BCO, @ITEM_BMOV = ITEM_BMOV, @USUARIO_REG = USUARIO
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', CNSCXP VARCHAR(20) '$.CNSCXP',
                CNSPAGO VARCHAR(20) '$.CNSPAGO', FECHA VARCHAR(50) '$.FECHA',
                VALOR DECIMAL(18,2) '$.VALOR', OBSERVACION VARCHAR(500) '$.OBSERVACION',
                ORIGENPAGO VARCHAR(50) '$.ORIGENPAGO', ESTADO VARCHAR(20) '$.ESTADO',
                CCOSTO VARCHAR(20) '$.CCOSTO', CODCAJA VARCHAR(5) '$.CODCAJA',
                CNSFACJ VARCHAR(21) '$.CNSFACJ', BANCO VARCHAR(4) '$.BANCO',
                SUCURSAL VARCHAR(3) '$.SUCURSAL', CTA_BCO VARCHAR(41) '$.CTA_BCO',
                ITEM_BMOV INT '$.ITEM_BMOV', USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CNSCXP IS NULL OR @CNSCXP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CNSCXP es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTCXP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CXP ' + @CNSCXP + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @FECHA_PAGO IS NULL
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('La fecha es requerida')
                    GOTO ERROR_HANDLER
                END

                IF @CNSPAGO IS NULL OR @CNSPAGO = ''
                BEGIN
                    SELECT @CNSPAGO = SPACE(8)
                    EXEC SPK_GENCONSECUTIVO_PPTO @COMPANIA_REG, @CONSECUTIVO, 'PAGOS', @CNSPAGO OUTPUT
                END

                IF EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Pago ' + @CNSPAGO + ' ya existe para este CXP')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    INSERT INTO PTPAG (
                        COMPANIA, CONSECUTIVO, CDP, RP, CNSCXP, CNSPAGO, FECHA, VALOR, OBSERVACION, ORIGENPAGO, ESTADO, CCOSTO,
                        CODCAJA, CNSFACJ, BANCO, SUCURSAL, CTA_BCO, ITEM_BMOV, USUARIO
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @CNSCXP, @CNSPAGO, @FECHA_PAGO, 
                        ISNULL(@VALOR, 0), @OBSERVACION, @ORIGENPAGO, 
                        ISNULL(@ESTADO, 'NoConfirmado'), @CCOSTO,
                        @CODCAJA, @CNSFACJ, @BANCO, @SUCURSAL, @CTA_BCO, @ITEM_BMOV,
                        ISNULL(@USUARIO_REG, @USUARIO)
                    )
                    SELECT 'OK' AS OK, @CNSPAGO AS CNSPAGO, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Pago ' + ISNULL(@CNSPAGO, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede editar un Pago de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTPAG SET
                        FECHA = ISNULL(@FECHA_PAGO, FECHA), VALOR = ISNULL(@VALOR, VALOR),
                        OBSERVACION = ISNULL(@OBSERVACION, OBSERVACION), ORIGENPAGO = ISNULL(@ORIGENPAGO, ORIGENPAGO),
                        CCOSTO = ISNULL(@CCOSTO, CCOSTO), CODCAJA = @CODCAJA, CNSFACJ = @CNSFACJ,
                        BANCO = @BANCO, SUCURSAL = @SUCURSAL, CTA_BCO = @CTA_BCO,
                        ITEM_BMOV = @ITEM_BMOV, USUARIO = ISNULL(@USUARIO_REG, USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO
                    SELECT 'OK' AS OK, @CNSPAGO AS CNSPAGO, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Pago ' + ISNULL(@CNSPAGO, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede eliminar un Pago de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    DELETE FROM PTPAGD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO

                    DELETE FROM PTPAG
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO
                    SELECT 'OK' AS OK, @CNSPAGO AS CNSPAGO, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'CONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Pago ' + ISNULL(@CNSPAGO, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede confirmar un Pago de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTPAG SET ESTADO = 'Confirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO
                    SELECT 'OK' AS OK, @CNSPAGO AS CNSPAGO, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'DESCONFIRMAR'
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Pago ' + ISNULL(@CNSPAGO, '') + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('No se puede desconfirmar un Pago de un CDP anulado')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY
                    UPDATE PTPAG SET ESTADO = 'NoConfirmado', USUARIO = ISNULL(@USUARIO_REG, @USUARIO)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO
                    SELECT 'OK' AS OK, @CNSPAGO AS CNSPAGO, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END

        ELSE IF @METODO = 'CRUDPTPAGD'     
        BEGIN         
            SELECT @REGISTRO = REGISTRO        
            FROM OPENJSON(@PARAMETROS) WITH (REGISTRO NVARCHAR(MAX) AS JSON)
            
            SELECT 
                @PROCESO = PROCESO, @COMPANIA_REG = COMPANIA, @CONSECUTIVO = CONSECUTIVO,
                @CDP = CDP, @RP = RP, @CNSCXP = CNSCXP, @CNSPAGO = CNSPAGO,
                @ITEM_PAGO = ITEM, @ITEMCDPD = ITEMCDPD, @RUBRO=RUBRO, @RUBRO_ID = RUBRO_ID,
                @VALOR = VALOR, @OBSERVACION = OBSERVACION, @USUARIO_REG = USUARIO,@CLASE='Gasto'
            FROM OPENJSON(@REGISTRO) WITH (
                PROCESO VARCHAR(20) '$.PROCESO', COMPANIA VARCHAR(2) '$.COMPANIA',
                CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO', CDP VARCHAR(21) '$.CDP',
                RP VARCHAR(20) '$.RP', CNSCXP VARCHAR(20) '$.CNSCXP',
                CNSPAGO VARCHAR(20) '$.CNSPAGO', ITEM INT '$.ITEM',
                ITEMCDPD INT '$.ITEMCDPD', RUBRO  VARCHAR(45)   '$.RUBRO', RUBRO_ID VARCHAR(20) '$.RUBRO_ID',
                VALOR DECIMAL(18,2) '$.VALOR', OBSERVACION VARCHAR(500) '$.OBSERVACION',
                USUARIO VARCHAR(12) '$.USUARIO'
            )

            IF @PROCESO IS NULL OR @PROCESO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El proceso no puede estar vac?o')
                GOTO ERROR_HANDLER
            END

            IF @COMPANIA_REG IS NULL OR @COMPANIA_REG = ''
                SET @COMPANIA_REG = @COMPANIA

            IF @CONSECUTIVO IS NULL OR @CONSECUTIVO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El consecutivo del presupuesto es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CDP IS NULL OR @CDP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CDP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CNSCXP IS NULL OR @CNSCXP = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CNSCXP es requerido')
                GOTO ERROR_HANDLER
            END

            IF @CNSPAGO IS NULL OR @CNSPAGO = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El CNSPAGO es requerido')
                GOTO ERROR_HANDLER
            END

            IF NOT EXISTS (SELECT 1 FROM PTPAG WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO)
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('El Pago ' + @CNSPAGO + ' no existe')
                GOTO ERROR_HANDLER
            END

            IF EXISTS (SELECT 1 FROM PTCDP WITH(NOLOCK) WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND ESTADO = 'Anulado')
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('No se puede modificar un detalle de Pago de un CDP anulado')
                GOTO ERROR_HANDLER
            END

            IF @PROCESO = 'INSERTAR'
            BEGIN
                IF @RUBRO_ID IS NULL OR @RUBRO_ID = ''
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El ID del rubro es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @ITEMCDPD IS NULL OR @ITEMCDPD = 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El Item CDPD es requerido')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                IF @ITEM_PAGO IS NULL OR @ITEM_PAGO = 0
                BEGIN
                    SELECT @ITEM_PAGO = ISNULL(MAX(ITEM), 0) + 1
                    FROM PTPAGD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO
                END

                IF EXISTS (
                    SELECT 1 FROM PTPAGD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_PAGO AS VARCHAR) + ' ya existe para este Pago')
                    GOTO ERROR_HANDLER
                END

                BEGIN TRY           
                    INSERT INTO PTPAGD (
                        COMPANIA, CONSECUTIVO, CDP, RP, CNSCXP, CNSPAGO,CLASE, ITEM, ITEMCDPD,RUBRO, RUBRO_ID, VALOR, OBSERVACION
                    )
                    VALUES (
                        @COMPANIA_REG, @CONSECUTIVO, @CDP, @RP, @CNSCXP, @CNSPAGO,@CLASE,@ITEM_PAGO,@ITEMCDPD,@RUBRO, @RUBRO_ID, @VALOR, @OBSERVACION
                    )

                    UPDATE P
                    SET P.VALOR = ISNULL(agg.TOT_VALOR, 0)
                    FROM PTPAG P
                    OUTER APPLY (
                        SELECT SUM(D.VALOR) AS TOT_VALOR
                        FROM PTPAGD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                          AND D.RP = P.RP
                          AND D.CNSCXP = P.CNSCXP
                          AND D.CNSPAGO = P.CNSPAGO
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                      AND P.RP = @RP
                      AND P.CNSCXP = @CNSCXP
                      AND P.CNSPAGO = @CNSPAGO

                    SELECT 'OK' AS OK, CAST(@ITEM_PAGO AS VARCHAR) AS ITEM, NULL AS ERROR       
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'EDITAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTPAGD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_PAGO AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                IF @VALOR IS NULL OR @VALOR <= 0
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El valor debe ser mayor a cero')
                    GOTO ERROR_HANDLER
                END

                SELECT @VALOR_ANTERIOR_PAGO = VALOR FROM PTPAGD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO

                BEGIN TRY
                    UPDATE PTPAGD SET
                        RUBRO_ID = ISNULL(@RUBRO_ID, RUBRO_ID), VALOR = @VALOR,
                        OBSERVACION = ISNULL(@OBSERVACION, OBSERVACION)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO

                   UPDATE P
                    SET P.VALOR = ISNULL(agg.TOT_VALOR, 0)
                    FROM PTPAG P
                    OUTER APPLY (
                        SELECT SUM(D.VALOR) AS TOT_VALOR
                        FROM PTPAGD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                          AND D.RP = P.RP
                          AND D.CNSCXP = P.CNSCXP
                          AND D.CNSPAGO = P.CNSPAGO
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                      AND P.RP = @RP
                      AND P.CNSCXP = @CNSCXP
                      AND P.CNSPAGO = @CNSPAGO

                    SELECT 'OK' AS OK, CAST(@ITEM_PAGO AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END

            ELSE IF @PROCESO = 'ELIMINAR'
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM PTPAGD WITH(NOLOCK)
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO
                )
                BEGIN
                    INSERT INTO @TBLERRORES VALUES ('El detalle con item ' + CAST(@ITEM_PAGO AS VARCHAR) + ' no existe')
                    GOTO ERROR_HANDLER
                END

                SELECT @VALOR = VALOR FROM PTPAGD WITH(NOLOCK)
                WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO

                BEGIN TRY
                    DELETE FROM PTPAGD
                    WHERE COMPANIA = @COMPANIA_REG AND CONSECUTIVO = @CONSECUTIVO AND CDP = @CDP AND RP = @RP AND CNSCXP = @CNSCXP AND CNSPAGO = @CNSPAGO AND ITEM = @ITEM_PAGO

                    UPDATE P
                    SET P.VALOR = ISNULL(agg.TOT_VALOR, 0)
                    FROM PTPAG P
                    OUTER APPLY (
                        SELECT SUM(D.VALOR) AS TOT_VALOR
                        FROM PTPAGD D
                        WHERE D.COMPANIA = P.COMPANIA
                          AND D.CONSECUTIVO = P.CONSECUTIVO
                          AND D.CDP = P.CDP
                          AND D.RP = P.RP
                          AND D.CNSCXP = P.CNSCXP
                          AND D.CNSPAGO = P.CNSPAGO
                    ) agg
                    WHERE P.COMPANIA = @COMPANIA_REG
                      AND P.CONSECUTIVO = @CONSECUTIVO
                      AND P.CDP = @CDP
                      AND P.RP = @RP
                      AND P.CNSCXP = @CNSCXP
                      AND P.CNSPAGO = @CNSPAGO

                    SELECT 'OK' AS OK, CAST(@ITEM_PAGO AS VARCHAR) AS ITEM, NULL AS ERROR
                END TRY
                BEGIN CATCH
                    INSERT INTO @TBLERRORES (ERROR)
                    SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                        + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                        + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                        + ': ' + ERROR_MESSAGE()
                    GOTO ERROR_HANDLER
                END CATCH
            END
            ELSE
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('Proceso no valido: ' + ISNULL(@PROCESO, ''))
                GOTO ERROR_HANDLER
            END
        END
        ELSE
        BEGIN
            INSERT INTO @TBLERRORES VALUES ('M?todo no reconocido: ' + ISNULL(@METODO, ''))
            GOTO ERROR_HANDLER
        END

        COMMIT TRANSACTION
        RETURN
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        IF NOT EXISTS (SELECT 1 FROM @TBLERRORES)
            INSERT INTO @TBLERRORES (ERROR)
            SELECT 'Motor SQL ' + CAST(ERROR_NUMBER() AS VARCHAR(11))
                + ', ' + ISNULL(NULLIF(ERROR_PROCEDURE(), ''), '(sin procedimiento)')
                + ', linea ' + CAST(ERROR_LINE() AS VARCHAR(11))
                + ': ' + ERROR_MESSAGE()
        GOTO ERROR_HANDLER
    END CATCH

    ERROR_HANDLER:
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        
        SELECT TOP (1) @MENSAJE_ERROR = ERROR FROM @TBLERRORES

        IF @MENSAJE_ERROR IS NOT NULL
            SET @MENSAJE_ERROR = '[' + ISNULL(@METODO, '') + CASE WHEN @PROCESO IS NOT NULL AND @PROCESO <> '' THEN ';' + @PROCESO ELSE '' END + '] ' + @MENSAJE_ERROR

        IF @METODO = 'CRUDPTPAGD'
            SELECT 'KO' AS OK, NULL AS ITEM, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTPAG'
            SELECT 'KO' AS OK, NULL AS CNSPAGO, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTCXPD'
            SELECT 'KO' AS OK, NULL AS ITEM, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTCXP'
            SELECT 'KO' AS OK, NULL AS CNSCXP, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTRPD'
            SELECT 'KO' AS OK, NULL AS ITEM, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTRP'
            SELECT 'KO' AS OK, NULL AS RP, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE IF @METODO = 'CRUDPTCDPD'
            SELECT 'KO' AS OK, NULL AS ITEM, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        ELSE
            SELECT 'KO' AS OK, NULL AS CDP, ISNULL(@MENSAJE_ERROR, 'Error en la operacion') AS ERROR
        
        RETURN
END

