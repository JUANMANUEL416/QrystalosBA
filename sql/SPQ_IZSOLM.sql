CREATE OR ALTER PROCEDURE DBO.SPQ_IZSOLM
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET DATEFORMAT dmy;
    SET LANGUAGE Spanish;

    DECLARE
        @PARAMETROS    NVARCHAR(MAX),
        @METODO        VARCHAR(100),
		@MODELO VARCHAR(100),
        @USUARIO       VARCHAR(12),
        @IDSEDE        VARCHAR(5),
        @GRUPO         VARCHAR(8),
        @C1_DATE       DATE,

		 -- variables usadas por los diferentes m�todos
        @CNSIZSOLM  VARCHAR(50),
        @SECTORF    VARCHAR(100),
        @ESTADO     INT

    -- Extrae estructura principal desde el JSON
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
		MODELO VARCHAR(100) '$.MODELO',
        METODO     VARCHAR(100) '$.METODO',
        USUARIO    VARCHAR(12)  '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    SELECT
		@MODELO = MODELO,
        @METODO     = METODO,
        @PARAMETROS = PARAMETROS,
        @USUARIO    = USUARIO
    FROM #JSON;

    -- Obtener GRUPO y IDSEDE como en SPQ_PRC
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

    
    IF @METODO = 'HOY'
    BEGIN
        -- Obtener la fecha actual truncada
        SET @C1_DATE = CONVERT(DATE, GETDATE());

        -- Verificar si ya existen �rdenes para ese d�a
        IF NOT EXISTS (
            SELECT 1
            FROM IZSOLM
            WHERE DBO.FNK_FECHA_SIN_HORA(FECHA) = @C1_DATE
        )
        BEGIN
			PRINT @C1_DATE
            -- Ejecutar el procedimiento SPK_GENDIA_OME24
            EXEC SPK_GENDIA_OME24 
                @C1_DATE,
                @IDSEDE,
                @USUARIO;

            -- Si es modo depuraci�n y grupo PPAL, mostrar el SQL
          --  IF DBO.FNVALORVARIABLE('IDDEPURAR') = 'SI' AND @GRUPO = 'PPAL'
            BEGIN
                PRINT 'EXEC SPK_GENDIA_OME24 ''' + CONVERT(VARCHAR, @C1_DATE, 120) + ''', ''' + @IDSEDE + ''', ''' + @USUARIO + '''';
            END

            SELECT 'OK' AS OK;
        END
        ELSE
        BEGIN
            SELECT 'KO' AS OK
			SELECT ERROR = 'Ya existen Ordenes Generadas para este d�a.'
			RETURN
        END

        RETURN;
    END

	IF @METODO = 'GENERAL_24HS'
	BEGIN
		-- Obtener CNSIZSOLM desde el JSON de par�metros
		SET @CNSIZSOLM = JSON_VALUE(@PARAMETROS, '$.CNSIZSOLM');

		-- Obtener estado actual del registro IZSOLM
		IF NOT EXISTS (SELECT * FROM IZSOLM WHERE CNSIZSOLM=@CNSIZSOLM)
		BEGIN
			SELECT 'KO' OK
			SELECT ERROR='Consecutivo de solicitud no existe'
			RETURN
		END

		SELECT @ESTADO = ISNULL(ESTADO,0)
		FROM IZSOLM
		WHERE CNSIZSOLM = @CNSIZSOLM;

		IF @ESTADO = 0
		BEGIN
			-- Ejecutar el procedimiento SPK_IZSOL_OME24 con par�metros
			EXEC SPK_IZSOL_OME24 @CNSIZSOLM, @IDSEDE, @USUARIO;

			-- Modo depuraci�n
			BEGIN
				PRINT 'EXEC SPK_IZSOL_OME24 ''' + @CNSIZSOLM + ''', ''' + @IDSEDE + ''', ''' + @USUARIO + '''';
			END

			-- Actualizar estado a 1 para CNSIZSOLM
			UPDATE IZSOLM SET ESTADO = 1 WHERE CNSIZSOLM = @CNSIZSOLM;

			SELECT 'OK' AS OK, MENSAJE = 'Proceso Terminado Correctamente';
		END 
		ELSE
		BEGIN
			SELECT 'KO' AS OK
			SELECT ERROR = 'Ya existen Ordenes Generadas para este d�a.'
			RETURN
		END
		RETURN;
    END

	IF @METODO = 'SECTOR_24HS'
	BEGIN
		-- Par�metros que vienen en el JSON
		SET @CNSIZSOLM = JSON_VALUE(@PARAMETROS, '$.CNSIZSOLM');
		SET @SECTORF   = JSON_VALUE(@PARAMETROS, '$.SECTORF');

		IF NOT EXISTS (SELECT * FROM IZSOLM WHERE CNSIZSOLM=@CNSIZSOLM)
		BEGIN
			SELECT 'KO' OK
			SELECT ERROR='Consecutivo de solicitud no existe'
			RETURN
		END

		/* Validaci�n: debe escoger un sector distinto de 'Todos' */
		IF ISNULL(@SECTORF,'')='' OR @SECTORF = 'Todos'
		BEGIN
			SELECT 'KO' AS OK
			SELECT ERROR = 'Debe escoger un sector';
			RETURN;
		END

		/* Estado actual del registro IZSOLM */
		SELECT @ESTADO = ISNULL(ESTADO,0)
		FROM IZSOLM
		WHERE CNSIZSOLM = @CNSIZSOLM;

		IF @ESTADO = 0
		BEGIN
			/* Ejecuta SPK_IZSOL_OME24 con flag�2 y sector */
			EXEC SPK_IZSOL_OME24 @CNSIZSOLM, @IDSEDE, @USUARIO, 2, @SECTORF;        

			/* Modo depuraci�n (opcional) */
			-- IF dbo.FNVALORVARIABLE('IDDEPURAR') = 'SI' AND @GRUPO = 'PPAL'
			-- BEGIN
			PRINT 'EXEC SPK_IZSOL_OME24 ''' 
				  + @CNSIZSOLM + ''', ''' 
				  + @IDSEDE    + ''', ''' 
				  + @USUARIO   + ''', 2, ''' 
				  + @SECTORF   + '''';

			SELECT 'OK' AS OK, MENSAJE = 'Proceso Terminado Correctamente';
		END
		ELSE
		BEGIN
			SELECT 'KO' AS OK
			SELECT ERROR = 'Ya existen Ordenes Generadas para este d�a.'
		END
		RETURN;
	END

	IF @METODO = 'ADMISION_24HS'
	BEGIN
		-- Obtener CNSIZSOLM y NOADMISION desde el JSON de par�metros
		SET @CNSIZSOLM = JSON_VALUE(@PARAMETROS, '$.CNSIZSOLM');
		DECLARE @NOADMISION VARCHAR(50) = JSON_VALUE(@PARAMETROS, '$.NOADMISION');

		IF NOT EXISTS (SELECT * FROM IZSOLM WHERE CNSIZSOLM=@CNSIZSOLM)
		BEGIN
			SELECT 'KO' OK
			SELECT ERROR='Consecutivo de solicitud no existe'
			RETURN
		END

		IF NOT EXISTS (SELECT * FROM HHAB WHERE NOADMISION=@NOADMISION)
		BEGIN
			SELECT 'KO' OK
			SELECT ERROR='No. Admision no existe'
			RETURN
		END

		-- Consultar el estado actual
		SELECT @ESTADO = ISNULL(ESTADO,0)
		FROM IZSOLM
		WHERE CNSIZSOLM = @CNSIZSOLM;

		IF @ESTADO = 0
		BEGIN
			-- Ejecutar el SP con flag 4 y NOADMISION
			EXEC SPK_IZSOL_OME24 @CNSIZSOLM, @IDSEDE, @USUARIO, 4, @NOADMISION;

			-- Modo depuraci�n
		   -- IF DBO.FNVALORVARIABLE('IDDEPURAR') = 'SI' AND @GRUPO = 'PPAL'
			BEGIN
				PRINT 'EXEC SPK_IZSOL_OME24 ''' 
					  + @CNSIZSOLM + ''', ''' 
					  + @IDSEDE    + ''', ''' 
					  + @USUARIO   + ''', 4, ''' 
					  + @NOADMISION + '''';
			END


			SELECT 'OK' AS OK, MENSAJE = 'Proceso Terminado Correctamente';
		END
		ELSE
		BEGIN
			SELECT 'KO' AS OK;
			SELECT ERROR = 'Ya existen Ordenes Generadas para este d�a.';
		END

		RETURN;
	END

	IF @METODO = 'REVISAR_24HS'
	BEGIN
		IF NOT EXISTS (
			SELECT 1
			FROM IZSOLM
			WHERE CONVERT(DATE, FECHA) = CONVERT(DATE, GETDATE())
			  AND ISNULL(ESTADO, 0) = 1
		)
		BEGIN
			SELECT 'KO' AS OK;
			SELECT ERROR = 'Las 24 horas del d�a de hoy no se ha generado o cerrado';
			RETURN;
		END

		IF DBO.FNK_VALORVARIABLE('IDDEPURAR') = 'SI' AND @GRUPO = 'PPAL'
		BEGIN
			PRINT 'EXEC SPK_REVISION24HORAS_DESPUES10MINUTOS';
		END

		EXEC SPK_REVISION24HORAS_DESPUES10MINUTOS;

		SELECT 'OK' AS OK, MENSAJE = 'Proceso terminado correctamente';
		RETURN;
	END
END
