CREATE OR ALTER PROCEDURE DBO.SPQ_FCJ
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET DATEFORMAT dmy;
    SET LANGUAGE Spanish;

    DECLARE
        @PARAMETROS       NVARCHAR(MAX),
        @METODO           VARCHAR(100),
        @USUARIO          VARCHAR(12),
        @IDSEDE           VARCHAR(5),
        @GRUPO            VARCHAR(8),
        @MODELO           VARCHAR(100),

        -- Variables de lógica
        @CNSFACJ          VARCHAR(20),
        @CODCAJA          VARCHAR(4),
        @TIPOEGRESO       VARCHAR(8),
        @ESTADO           VARCHAR(1),
        @CERRADA          VARCHAR(20),
        @DEAPERTURA       SMALLINT,
        @CNSACJ           VARCHAR(20),
        @CLASE_FAC        VARCHAR(5),
        @NROCOMPROBANTE   VARCHAR(20),

        -- Variables para contabilidad
        @ESTADO_MCP       INT,
        @ANOMES           VARCHAR(6),
        @CERRADO_PRI      BIT,
        @COMPANIA		VARCHAR(2)='01';

		
    
		DECLARE 
			@DETALLE_ANULACION NVARCHAR(300),
			@IDCAUSALANUL VARCHAR(10),
			@CLASE_FAC_FCJ VARCHAR(10),
			@IDPLAN_FCJ VARCHAR(20),
			@PROCEDENCIA VARCHAR(20),
			@NOADMISION VARCHAR(20),
			@FACTURADA BIT;
		DECLARE @CLASE_CAJA VARCHAR(10);

    -- Parseo principal
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
        WITH (
            MODELO     VARCHAR(20)  '$.MODELO', 
            METODO     VARCHAR(100) '$.METODO',
            USUARIO    VARCHAR(12)  '$.USUARIO',
            PARAMETRO NVARCHAR(MAX) AS JSON
        );

    SELECT
        @MODELO     = MODELO,
        @METODO     = METODO,
        @PARAMETROS = PARAMETRO,
        @USUARIO    = USUARIO
    FROM #JSON;

    -- Obtener GRUPO y IDSEDE como en otros SPQ
    SELECT @GRUPO = DBO.FNK_DESCIFRAR(GRUPO)
    FROM USUSU
    WHERE USUARIO = @USUARIO;

    DECLARE @SYS_COMPUTERNAME VARCHAR(256);
    SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME
    FROM USUSU
    WHERE USUARIO = @USUARIO;

    SELECT @IDSEDE = IDSEDE
    FROM UBEQ
    WHERE SYS_ComputerName = @SYS_COMPUTERNAME;

    IF COALESCE(@IDSEDE, '') = ''
        SET @IDSEDE = '01';

    DROP TABLE #JSON;

    -- =======================================
    -- MÉTODO: ANULAR_RECIBO
    -- =======================================
    IF @METODO = 'ANULAR_RECIBO'	
	BEGIN
		  SELECT
			@CNSFACJ = JSON_VALUE(@PARAMETROS, '$.CNSFACJ'),
			@CODCAJA = JSON_VALUE(@PARAMETROS, '$.CODCAJA'),
			@DETALLE_ANULACION = JSON_VALUE(@PARAMETROS, '$.DETALLEANULACION'),
			@IDCAUSALANUL = JSON_VALUE(@PARAMETROS, '$.IDCAUSALANUL');

		SELECT @TIPOEGRESO=FCJ.TIPOEGRESO, 
			@ESTADO=FCJ.ESTADO, 
			@CERRADA=FCJ.CERRADA, 
			@DEAPERTURA=FCJ.DEAPERTURA, 
			@CNSACJ=FCJ.CNSACJ, 
			@CLASE_FAC=FCJ.CLASE_FAC, 
			@NROCOMPROBANTE=FCJ.NROCOMPROBANTE,			
			@IDPLAN_FCJ = IDPLAN,
			@PROCEDENCIA = PROCEDENCIA,
			@NOADMISION = NOADMISION
		FROM FCJ WHERE CODCAJA=@CODCAJA AND CNSFACJ=@CNSFACJ

		SELECT @CLASE_CAJA = CLASE FROM CAJ WHERE CODCAJA = @CODCAJA;

        IF @CNSFACJ IS NULL RETURN;
		
		-- Validaciones
		IF NOT EXISTS(SELECT 1 FROM FCJ WHERE CODCAJA=@CODCAJA AND CNSFACJ=@CNSFACJ)
		BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Recibo de caja no encontrado, por favor valide';
            RETURN;
		END
        IF @TIPOEGRESO = RTRIM(dbo.FNK_VALORVARIABLE('IDCJTETRASLADO'))
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Los Traslados entre Cajas No Pueden Anular';
            RETURN;
        END

        IF @ESTADO IN ('A', 'D')
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Recibo ya está Anulado o Desechado';
            RETURN;
        END

        IF @CERRADA = '0'
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR ='No se puede anular un recibo no confirmado';
            RETURN;
        END

        IF @DEAPERTURA = 1
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR ='No se puede anular un recibo de apertura';
            RETURN;
        END

        IF UPPER(dbo.FNK_VALORVARIABLE('MAN_RELRECIBOSFCJ')) = 'SI'
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM PCJ
                WHERE CNSFACJ = @CNSFACJ AND TRASLADADO = '1' AND TRASLADO_CNSFACJ <> '' AND CODCAJA = @CODCAJA
            )
            BEGIN
                SELECT 'KO' AS OK
				SELECT ERROR ='Relacionado a un traslado entre Cajas';
                RETURN;
            END
        END

        IF EXISTS (SELECT 1 FROM ACJ WHERE CNSACJ = @CNSACJ AND ABIERTA = 0)
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Apertura cerrada. No se puede anular.';
            RETURN;
        END
		
		IF @CLASE_FAC NOT IN ('COBRO','PAGO')
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Clase de Factura no válida';
            RETURN;
        END
		
		IF @CLASE_FAC = 'COBRO'
		BEGIN
			IF @IDPLAN_FCJ NOT IN (
				DBO.FNK_VALORVARIABLE('IDPLANPART'),
				DBO.FNK_VALORVARIABLE('IDPLANPART2'),
				DBO.FNK_VALORVARIABLE('IDPLANPART3'),
				DBO.FNK_VALORVARIABLE('IDPLANPART4'),
				DBO.FNK_VALORVARIABLE('IDPLANPART5')
			)
			BEGIN
				IF @PROCEDENCIA = 'CITAS'
				BEGIN
					SELECT @FACTURADA = FACTURADA 
					FROM CIT 
					WHERE CONSECUTIVO = @NOADMISION;

					IF @FACTURADA = 1
					BEGIN
						SELECT 'KO' AS OK 
						  SELECT ERROR = 'La cita asociada ya está facturada. Anule primero la factura.';
						RETURN;
					END
				END
				ELSE IF @PROCEDENCIA = 'CE'
				BEGIN
					SELECT @FACTURADA = FACTURADA 
					FROM AUT 
					WHERE NOAUT = @NOADMISION;

					IF @FACTURADA = 1
					BEGIN
						SELECT 'KO' AS OK
						SELECT ERROR = 'La autorización u orden médica asociada ya está facturada. Anule primero la factura.';
						RETURN;
					END
				END
			END
		END		
		IF @CLASE_CAJA='Menor'
		BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'En Cajas Menores no se contabiliza la anulación';
            RETURN;
		END

        IF @TIPOEGRESO = dbo.FNK_VALORVARIABLE('IDCJTECXP')
        BEGIN
            EXEC SPK_ANULA_ODERNPAGOENCAJA @CODCAJA, @CNSFACJ, @USUARIO, 'A';
        END

        -- Anular el recibo
        EXEC SPK_ANULARECIBO_CAJA @CODCAJA, @CNSFACJ, @USUARIO;

        -- Manejo contable
        SELECT @ESTADO_MCP = ESTADO, @ANOMES = ANOMES FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
        SELECT @CERRADO_PRI = CERRADO FROM PRI WHERE ANOMES = @ANOMES;
		
        IF @CLASE_FAC = 'COBRO'
        BEGIN
            IF @ESTADO_MCP = 2
            BEGIN
                IF @CERRADO_PRI = 1
                BEGIN
					EXEC SPK_REVERSAR_MCP @NROCOMPROBANTE, @CNSFACJ, 'REVCAJAING', @CODCAJA, @CNSFACJ, @COMPANIA, @IDSEDE, @USUARIO, NULL, NULL;
               
                END
                ELSE
				BEGIN
                    UPDATE MCP SET ANULADO = 1 WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
				END
            END
            ELSE
            BEGIN
				EXEC SPK_CONTAB_CAJA_ING @CNSFACJ, @CODCAJA, @USUARIO, @SYS_COMPUTERNAME, @COMPANIA, @IDSEDE, @NROCOMPROBANTE;
            END

            IF EXISTS (SELECT 1 FROM FCJ WHERE CNSFACJ = @CNSFACJ AND CONTABILIZADA = 2)
            BEGIN
                DELETE FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
                DELETE FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
            END
        END
        ELSE IF @CLASE_FAC = 'PAGO'
        BEGIN
            IF @CLASE_CAJA <> 'Menor'
            BEGIN
                IF @ESTADO_MCP = 2  
                BEGIN
					IF @CERRADO_PRI = 1
					BEGIN
						EXEC SPK_REVERSAR_MCP @NROCOMPROBANTE, @CNSFACJ, 'REVCAJAEGR', @CODCAJA, @CNSFACJ, @COMPANIA, @IDSEDE, @USUARIO, @SYS_COMPUTERNAME, NULL 
					END
					ELSE
					BEGIN
						UPDATE MCP SET ANULADO = 1 WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
						EXEC SPK_CONTAB_CAJA_ING @CNSFACJ, @CODCAJA, @USUARIO, @SYS_COMPUTERNAME, @COMPANIA, @IDSEDE, @NROCOMPROBANTE;
					END
                END
				ELSE
				BEGIN
					EXEC SPK_CONTAB_CAJA_EGR @CNSFACJ ,@CODCAJA,@USUARIO,@SYS_COMPUTERNAME ,@COMPANIA,@IDSEDE,@NROCOMPROBANTE
				END                

                IF EXISTS (SELECT 1 FROM FCJ WHERE CNSFACJ = @CNSFACJ AND CONTABILIZADA = 2)
                BEGIN
                    DELETE FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
                    DELETE FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
                END
            END
        END
		

		-- Actualizar datos en FCJ
		UPDATE FCJ
		SET 
			FECHAANU = DBO.FNK_FECHA_SIN_MLS(GETDATE()),
			SYS_COMPUTERNAMEANUL = @SYS_COMPUTERNAME,
			USUARIOANUL = @USUARIO,
			DETALLEANULACION = ISNULL(@DETALLE_ANULACION, ''),
			IDCAUSALANUL = ISNULL(@IDCAUSALANUL, '')
		WHERE CODCAJA = @CODCAJA AND CNSFACJ = @CNSFACJ;

		SELECT 'OK' AS OK, MENSAJE = 'Detalle de Anulación Registrado Correctamente';
		RETURN;
	END
	
END


