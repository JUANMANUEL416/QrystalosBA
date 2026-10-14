CREATE OR ALTER PROCEDURE DBO.SPQ_NOM_RETEI @JSON NVARCHAR(MAX)
	WITH ENCRYPTION
AS
BEGIN
	-- Optimizaciones de entorno
	SET NOCOUNT ON;
	SET XACT_ABORT ON;-- Mantenemos esto seg�n tu ejemplo para m�xima seguridad de datos

	DECLARE @METODO VARCHAR(100), @USUARIO VARCHAR(20), @PARAMETROS NVARCHAR(MAX);
	DECLARE @IDSEDE VARCHAR(5), @PROCESO VARCHAR(20), @CODIGO VARCHAR(10);
	DECLARE @DESCRIPCION VARCHAR(255), @CLASE VARCHAR(10), @ESTADO VARCHAR(10), @ORDEN SMALLINT;
	-- Bandera para control de transacciones
	DECLARE @StartedTran BIT = 0;
	DECLARE @SavePointName VARCHAR(32) = 'SPQ_NOM_RETEI_sp';

	-- 1. Extracci�n de cabecera JSON (Fuera del TRY para fallar r�pido si el JSON est� mal)
	SELECT @METODO = METODO, @USUARIO = USUARIO, @PARAMETROS = PARAMETROS
	FROM OPENJSON(@json) WITH (METODO VARCHAR(100) '$.METODO', USUARIO VARCHAR(12) '$.USUARIO', PARAMETROS NVARCHAR(MAX) AS JSON);

	BEGIN TRY
		-- Manejo de Transacci�n / Savepoint
		IF @@TRANCOUNT = 0
		BEGIN
			BEGIN TRANSACTION;

			SET @StartedTran = 1;
		END
		ELSE
		BEGIN
			SAVE TRANSACTION @SavePointName;
		END

		/* =========================
           L�GICA DE NEGOCIO
           ========================= */
		IF @METODO = 'GUARDAR'
		BEGIN
			-- Obtenci�n de contexto (Sede/Equipo)
			SELECT @IDSEDE = B.IDSEDE
			FROM USUSU A
			INNER JOIN UBEQ B ON A.SYS_COMPUTERNAME = B.SYS_ComputerName
			WHERE A.USUARIO = @USUARIO;

			-- Mapeo de par�metros
			SELECT @CODIGO = CODIGO, @DESCRIPCION = DESCRIPCION, @CLASE = CLASE, @ESTADO = ESTADO, @ORDEN = ORDEN, @PROCESO = PROCESO
			FROM OPENJSON(@PARAMETROS) WITH (
					CODIGO VARCHAR(10) '$.CODIGO', DESCRIPCION VARCHAR(255) '$.DESCRIPCION', CLASE VARCHAR(10) '$.CLASE', ESTADO VARCHAR(10) '$.ESTADO', ORDEN 
					SMALLINT '$.ORDEN', PROCESO VARCHAR(20) '$.PROCESO'
					);

			IF UPPER(@PROCESO) = 'INSERTAR'
			BEGIN
				EXEC SPQ_GENSEQUENCE @SEDE = @IDSEDE, @PREFIJO = '@RETEI', @LONGITUD = 4, @NVOCONSEC = @CODIGO OUTPUT;

				INSERT INTO [RETEI] ([CODIGO], [DESCRIPCION], [CLASE], [ESTADO], [ORDEN])
				VALUES (@CODIGO, @DESCRIPCION, @CLASE, @ESTADO, @ORDEN);
			END
			ELSE IF UPPER(@PROCESO) = 'EDITAR'
			BEGIN
				UPDATE RETEI
				SET DESCRIPCION = @DESCRIPCION, CLASE = @CLASE, ESTADO = @ESTADO, ORDEN = @ORDEN
				WHERE CODIGO = @CODIGO;
			END
		END
		ELSE IF @METODO = 'ELIMINAR'
		BEGIN
			SELECT @CODIGO = CODIGO
			FROM OPENJSON(@PARAMETROS) WITH (CODIGO VARCHAR(10) '$.CODIGO');

			DELETE
			FROM RETEI
			WHERE CODIGO = @CODIGO;
		END

		-- Si yo la abr�, yo la cierro
		IF @StartedTran = 1
			COMMIT TRANSACTION;

		-- Respuesta de �xito
		SELECT 'OK' AS OK;
	END TRY

	BEGIN CATCH
		-- Manejo de errores y reversi�n
		IF XACT_STATE() = - 1
		BEGIN
			-- Transacci�n rota (Uncommittable), rollback total obligatorio
			ROLLBACK TRANSACTION;
		END
		ELSE IF XACT_STATE() = 1
		BEGIN
			-- Transacci�n salvable
			IF @StartedTran = 1
				ROLLBACK TRANSACTION;-- Soy el due�o, limpio todo
			ELSE
				ROLLBACK TRANSACTION @SavePointName;-- Soy invitado, limpio solo mi parte
		END;

		-- Devolver informaci�n del error antes de lanzar el THROW (opcional para el cliente)
		-- SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
		-- Re-lanzar el error para que el SP Padre sepa que fall�
		THROW;
	END CATCH
END
