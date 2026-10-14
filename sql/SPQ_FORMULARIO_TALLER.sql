CREATE OR ALTER PROCEDURE DBO.SPQ_FORMULARIO_TALLER @JSON NVARCHAR(MAX)
	WITH ENCRYPTION
AS
DECLARE @PARAMETROS NVARCHAR(MAX), @MODELO VARCHAR(100), @METODO VARCHAR(100), @DATOS NVARCHAR(MAX), @IDCAP INT
DECLARE @USUARIO VARCHAR(20), @PROCESO VARCHAR(20), @TALLERID INT, @PREGUNTAS NVARCHAR(MAX), @NOMBRETALLER NVARCHAR(255), @DESCRIPCION NVARCHAR(MAX)
DECLARE @EMPLEADOID INT
DECLARE @TBLERRORES TABLE (ERROR VARCHAR(MAX))

BEGIN
	SET NOCOUNT ON;

	SELECT @MODELO = MODELO, @METODO = METODO, @USUARIO = USUARIO, @PARAMETROS = PARAMETROS
	FROM OPENJSON(@json) WITH (MODELO VARCHAR(100) '$.MODELO', METODO VARCHAR(100) '$.METODO', USUARIO VARCHAR(12) '$.USUARIO', PARAMETROS NVARCHAR(MAX) AS JSON
			)

	IF @METODO = 'GUARDAR'
	BEGIN
		BEGIN TRY
			SELECT @PROCESO = PROCESO, @TALLERID = TALLERID, @PREGUNTAS = PREGUNTAS, @NOMBRETALLER = NOMBRETALLER, @DESCRIPCION = DESCRIPCION
			FROM OPENJSON(@PARAMETROS) WITH (
					PROCESO VARCHAR(20) '$.PROCESO', TALLERID INT '$.datosFormulario.tallerId', PREGUNTAS NVARCHAR(MAX) '$.datosFormulario.preguntas' AS JSON, 
					NOMBRETALLER NVARCHAR(255) '$.datosFormulario.titulo', DESCRIPCION NVARCHAR(MAX) '$.datosFormulario.descripcion'
					)

			IF UPPER(@PROCESO) = 'INSERTAR'
			BEGIN
				BEGIN TRY
					BEGIN TRAN;

					UPDATE TALL
					SET NOMBRETALLER = @NOMBRETALLER, DESCRIPCION = @DESCRIPCION
					WHERE TALLERID = @TALLERID

					DECLARE @i INT = 0, @total INT = (
							SELECT COUNT(*)
							FROM OPENJSON(@PREGUNTAS)
							);

					WHILE @i < @total
					BEGIN
						DECLARE @ENUNCIADO NVARCHAR(MAX), @TIPO NVARCHAR(50), @PREGUNTAID INT, @OPCIONES NVARCHAR(MAX), @RESP_CORRECTA NVARCHAR(MAX), 
							@RESP_CORRECTAS NVARCHAR(MAX), @RESP_CORRECTA_BOOLEANA BIT;

						SELECT @ENUNCIADO = JSON_VALUE(value, '$.texto'), @TIPO = JSON_VALUE(value, '$.tipo'), @OPCIONES = JSON_QUERY(value, '$.opciones'), 
							@RESP_CORRECTA = JSON_VALUE(value, '$.respuesta_correcta'), @RESP_CORRECTAS = JSON_QUERY(value, '$.respuestas_correctas'), 
							@RESP_CORRECTA_BOOLEANA = JSON_VALUE(value, '$.respuesta_correcta_booleano')
						FROM OPENJSON(@PREGUNTAS)
						ORDER BY CAST([key] AS INT) OFFSET @i ROWS

						FETCH NEXT 1 ROWS ONLY;

						INSERT INTO TPREGUNTAS (TALLERID, ENUNCIADO, TIPOPREGUNTA, ORDEN)
						VALUES (@TALLERID, @ENUNCIADO, @TIPO, @i + 1);

						SET @PREGUNTAID = SCOPE_IDENTITY();

						-- Manejar opciones seg�n tipo
						IF @TIPO IN ('multiple', 'seleccion_unica', 'booleano')
						BEGIN
							INSERT INTO TOPCIONES (PREGUNTAID, TEXTOPCION, ESCORRECTA)
							SELECT @PREGUNTAID, JSON_VALUE(value, '$.label'), CASE 
									WHEN @TIPO = 'seleccion_unica' AND JSON_VALUE(value, '$.value') = @RESP_CORRECTA
										THEN 1
									WHEN @TIPO = 'multiple' AND JSON_VALUE(value, '$.value') IN (
											SELECT value
											FROM OPENJSON(@RESP_CORRECTAS)
											)
										THEN 1
									WHEN @TIPO = 'booleano' AND CAST(JSON_VALUE(value, '$.value') AS BIT) = @RESP_CORRECTA_BOOLEANA
										THEN 1
									ELSE 0
									END
							FROM OPENJSON(@OPCIONES);
						END

						SET @i += 1;
					END

					COMMIT TRAN;
				END TRY

				BEGIN CATCH
					IF @@TRANCOUNT > 0
					BEGIN
						ROLLBACK TRAN;
					END

					INSERT INTO @TBLERRORES (ERROR)
					SELECT ERROR_MESSAGE()
				END CATCH

				IF (
						SELECT COUNT(*)
						FROM @TBLERRORES
						) > 0
				BEGIN
					SELECT 'KO' OK

					SELECT ERROR
					FROM @TBLERRORES

					RETURN
				END

				SELECT 'OK' OK

				RETURN
			END

			IF UPPER(@PROCESO) = 'EDITAR'
			BEGIN
				BEGIN TRY
					BEGIN TRAN;

					UPDATE TALL
					SET NOMBRETALLER = @NOMBRETALLER, DESCRIPCION = @DESCRIPCION
					WHERE TALLERID = @TALLERID;

					DELETE
					FROM TPREGUNTAS
					WHERE TALLERID = @TALLERID;

					DECLARE @ie INT = 0, @totale INT = (
							SELECT COUNT(*)
							FROM OPENJSON(@PREGUNTAS)
							);

					WHILE @ie < @totale
					BEGIN
						DECLARE @ENUNCIADOE NVARCHAR(MAX), @TIPOE NVARCHAR(50), @PREGUNTAIDE INT, @OPCIONESE NVARCHAR(MAX), @RESP_CORRECTAE NVARCHAR(MAX), 
							@RESP_CORRECTASE NVARCHAR(MAX), @RESP_CORRECTA_BOOLEANAE BIT;

						-- Re-extraer los datos de la pregunta
						SELECT @ENUNCIADOE = JSON_VALUE(value, '$.texto'), @TIPOE = JSON_VALUE(value, '$.tipo'), @OPCIONESE = JSON_QUERY(value, '$.opciones'), 
							@RESP_CORRECTAE = JSON_VALUE(value, '$.respuesta_correcta'), @RESP_CORRECTASE = JSON_QUERY(value, '$.respuestas_correctas'), 
							@RESP_CORRECTA_BOOLEANAE = JSON_VALUE(value, '$.respuesta_correcta_booleano')
						FROM OPENJSON(@PREGUNTAS)
						ORDER BY CAST([key] AS INT) OFFSET @ie ROWS

						FETCH NEXT 1 ROWS ONLY;

						-- Insertar la nueva pregunta (genera un nuevo PREGUNTAID)
						INSERT INTO TPREGUNTAS (TALLERID, ENUNCIADO, TIPOPREGUNTA, ORDEN)
						VALUES (@TALLERID, @ENUNCIADOE, @TIPOE, @ie + 1);

						SET @PREGUNTAIDE = SCOPE_IDENTITY();

						-- Re-insertar las opciones seg�n el tipo
						IF @TIPOE IN ('multiple', 'seleccion_unica', 'booleano')
						BEGIN
							INSERT INTO TOPCIONES (PREGUNTAID, TEXTOPCION, ESCORRECTA)
							SELECT @PREGUNTAIDE, JSON_VALUE(value, '$.label'), CASE 
									WHEN @TIPOE = 'seleccion_unica' AND JSON_VALUE(value, '$.value') = @RESP_CORRECTAE
										THEN 1
									WHEN @TIPOE = 'multiple' AND JSON_VALUE(value, '$.value') IN (
											SELECT value
											FROM OPENJSON(@RESP_CORRECTASE)
											)
										THEN 1
									WHEN @TIPOE = 'booleano' AND CAST(JSON_VALUE(value, '$.value') AS BIT) = @RESP_CORRECTA_BOOLEANAE
										THEN 1
									ELSE 0
									END
							FROM OPENJSON(@OPCIONESE);
						END

						SET @ie += 1;
					END

					COMMIT TRAN;
				END TRY

				BEGIN CATCH
					IF @@TRANCOUNT > 0
					BEGIN
						ROLLBACK TRAN;
					END

					INSERT INTO @TBLERRORES (ERROR)
					SELECT ERROR_MESSAGE()
				END CATCH

				IF (
						SELECT COUNT(*)
						FROM @TBLERRORES
						) > 0
				BEGIN
					SELECT 'KO' OK

					SELECT ERROR
					FROM @TBLERRORES

					RETURN
				END

				SELECT 'OK' OK

				RETURN
			END
		END TRY

		BEGIN CATCH
			INSERT INTO @TBLERRORES (ERROR)
			SELECT ERROR_MESSAGE()
		END CATCH

		IF (
				SELECT COUNT(*)
				FROM @TBLERRORES
				) > 0
		BEGIN
			SELECT 'KO' OK

			SELECT ERROR
			FROM @TBLERRORES

			RETURN
		END

		SELECT 'OK' OK
	END

	IF @METODO = 'GET_FORMULARIO'
	BEGIN
		SELECT @TALLERID = TALLERID
		FROM OPENJSON(@PARAMETROS) WITH (TALLERID INT '$.TALLERID')

		BEGIN TRY
			DECLARE @NPREGUNTAS INT

			IF EXISTS (
					SELECT COUNT(*)
					FROM TPREGUNTAS
					WHERE TALLERID = @TALLERID
					GROUP BY TALLERID
					)
			BEGIN
				SELECT 'OK' OK

				SELECT 1 AS hasForm

				RETURN
			END

			SELECT 'OK' OK

			SELECT 0 AS hasForm
		END TRY

		BEGIN CATCH
			INSERT INTO @TBLERRORES (ERROR)
			SELECT ERROR_MESSAGE()
		END CATCH

		IF (
				SELECT COUNT(*)
				FROM @TBLERRORES
				) > 0
		BEGIN
			SELECT 'KO' OK

			SELECT ERROR
			FROM @TBLERRORES

			RETURN
		END

		SELECT 'OK' OK
	END

	IF @METODO = 'GET_FORMULARIO_DETALLE'
	BEGIN
		SELECT @TALLERID = TALLERID
		FROM OPENJSON(@PARAMETROS) WITH (TALLERID INT '$.TALLERID')

		BEGIN TRY
			SET NOCOUNT ON;

			SELECT 'OK' OK

			SELECT P.PREGUNTAID, P.ENUNCIADO, P.TIPOPREGUNTA, P.ORDEN,
				-- Devuelve las opciones como JSON (si aplica)
				(
					SELECT O.TEXTOPCION AS [label], O.TEXTOPCION AS [value], O.ESCORRECTA
					FROM TOPCIONES O
					WHERE O.PREGUNTAID = P.PREGUNTAID
					FOR JSON PATH
					) AS OPCIONES_JSON,
				-- Devuelve la respuesta correcta (para selecci�n �nica)
				(
					SELECT TOP 1 O.TEXTOPCION
					FROM TOPCIONES O
					WHERE O.PREGUNTAID = P.PREGUNTAID AND O.ESCORRECTA = 1 AND P.TIPOPREGUNTA = 'seleccion_unica'
					) AS RESP_CORRECTA,
				-- Devuelve las respuestas correctas (para selecci�n m�ltiple)
				(
					SELECT O.TEXTOPCION
					FROM TOPCIONES O
					WHERE O.PREGUNTAID = P.PREGUNTAID AND O.ESCORRECTA = 1 AND P.TIPOPREGUNTA = 'multiple'
					FOR JSON PATH
					) AS RESP_CORRECTAS_JSON
			FROM TPREGUNTAS P
			WHERE P.TALLERID = @TALLERID
			ORDER BY P.ORDEN;
		END TRY

		BEGIN CATCH
			INSERT INTO @TBLERRORES (ERROR)
			SELECT ERROR_MESSAGE()
		END CATCH

		IF (
				SELECT COUNT(*)
				FROM @TBLERRORES
				) > 0
		BEGIN
			SELECT 'KO' OK

			SELECT ERROR
			FROM @TBLERRORES

			RETURN
		END

		SELECT 'OK' OK
	END

	IF @METODO = 'GET_RESPUESTAS_EMPLEADO'
	BEGIN
		SELECT @TALLERID = TALLERID, @EMPLEADOID = EMPLEADOID
		FROM OPENJSON(@PARAMETROS) WITH (TALLERID INT '$.TALLERID', EMPLEADOID VARCHAR(20) '$.EMPLEADOID');

		BEGIN TRY
			SELECT 'OK' OK;

			DECLARE @ResultadoID INT;

			SELECT TOP 1 @ResultadoID = R.ResultadoID
			FROM dbo.TRESULTADOS R
			INNER JOIN dbo.TASIGNACION A ON R.AsignacionID = A.ASIGNACIONID
			WHERE A.TALLERID = @TALLERID AND A.NUMDOC = @EMPLEADOID
			ORDER BY R.FechaCompletado DESC;

			IF @ResultadoID IS NULL
			BEGIN
				SELECT CAST(0 AS INT) AS TotalPreguntas, CAST(0 AS INT) AS TotalCorrectas, CAST(0 AS INT) AS TotalIncorrectas
				WHERE 1 = 0;

				SELECT CAST(NULL AS NVARCHAR(MAX)) AS ENUNCIADO, CAST(NULL AS NVARCHAR(50)) AS TIPOPREGUNTA, '[]' AS OPCIONES_JSON, NULL AS RESPUESTA_EMPLEADO, CAST(
						NULL AS BIT) AS RESP_CORRECTA_BOOL, '[]' AS RESPUESTAS_EMPLEADO_JSON, CAST(0 AS BIT) AS ES_CORRECTA
				WHERE 1 = 0;

				RETURN;
			END;

			-- Resumen
			SELECT (
					SELECT COUNT(*)
					FROM dbo.TPREGUNTAS
					WHERE TALLERID = @TALLERID
					) AS TotalPreguntas, (
					SELECT COUNT(*)
					FROM (
						SELECT PreguntaID
						FROM TRespEmpleado
						WHERE ResultadoID = @ResultadoID AND Correcta = 1
						GROUP BY PreguntaID
						) AS COR
					) AS TotalCorrectas, (
					SELECT COUNT(*)
					FROM (
						SELECT PreguntaID
						FROM TRespEmpleado
						WHERE ResultadoID = @ResultadoID AND Correcta = 0
						GROUP BY PreguntaID
						) AS INC
					) AS TotalIncorrectas;

			-- Detalle de preguntas
			SELECT P.PREGUNTAID, P.ENUNCIADO, P.TIPOPREGUNTA,
				-- Opciones de la pregunta
				ISNULL((
						SELECT O.OPCIONID AS [value], O.TEXTOPCION AS [label], O.ESCORRECTA
						FROM dbo.TOPCIONES O
						WHERE O.PREGUNTAID = P.PREGUNTAID
						FOR JSON PATH
						), '[]') AS OPCIONES_JSON,
				-- Respuesta del empleado (texto, booleano o selecci�n �nica)
				CASE 
					WHEN P.TIPOPREGUNTA = 'texto'
						THEN TResp.RespuestaTexto
					WHEN P.TIPOPREGUNTA = 'booleano'
						THEN TResp.RespuestaTexto
					WHEN P.TIPOPREGUNTA = 'seleccion_unica'
						THEN CAST(TResp.OpcionID_Seleccionada AS NVARCHAR(50))
					ELSE NULL
					END AS RESPUESTA_EMPLEADO,
				-- Valor correcto en preguntas booleanas
				CASE 
					WHEN P.TIPOPREGUNTA = 'booleano'
						THEN CAST(CASE 
									WHEN (
											SELECT TOP 1 O.TEXTOPCION
											FROM dbo.TOPCIONES O
											WHERE O.PREGUNTAID = P.PREGUNTAID AND O.ESCORRECTA = 1
											) = 'Verdadero'
										THEN 1
									ELSE 0
									END AS BIT)
					ELSE NULL
					END AS RESP_CORRECTA_BOOL,
				-- JSON con todas las opciones seleccionadas (solo para "multiple")
				CASE 
					WHEN P.TIPOPREGUNTA = 'multiple'
						THEN ISNULL((
									SELECT O.OPCIONID AS [value], O.TEXTOPCION AS [label]
									FROM dbo.TRespEmpleado R
									INNER JOIN dbo.TOPCIONES O ON O.OPCIONID = R.OpcionID_Seleccionada
									WHERE R.ResultadoID = @ResultadoID AND R.PreguntaID = P.PREGUNTAID
									FOR JSON PATH
									), '[]')
					ELSE NULL
					END AS RESPUESTAS_EMPLEADO_JSON,
				-- Evaluaci�n correcta de la pregunta
				CAST(CASE 
						WHEN P.TIPOPREGUNTA = 'multiple'
							THEN CASE 
									WHEN (
											-- total correctas
											(
												SELECT COUNT(*)
												FROM TOPCIONES O
												WHERE O.PREGUNTAID = P.PREGUNTAID AND O.ESCORRECTA = 1
												) =
											-- total seleccionadas por empleado
											(
												SELECT COUNT(*)
												FROM TRespEmpleado R
												WHERE R.ResultadoID = @ResultadoID AND R.PreguntaID = P.PREGUNTAID
												) AND
											-- todas las seleccionadas son correctas
											NOT EXISTS (
												SELECT 1
												FROM TRespEmpleado R
												INNER JOIN TOPCIONES O ON O.OPCIONID = R.OpcionID_Seleccionada
												WHERE R.ResultadoID = @ResultadoID AND R.PreguntaID = P.PREGUNTAID AND O.ESCORRECTA = 0
												)
											)
										THEN 1
									ELSE 0
									END
						ELSE ISNULL(TResp.Correcta, 0)
						END AS BIT) AS ES_CORRECTA,CAST(ISNULL(TResp.Calificada, 0) AS BIT) AS ESTA_CALIFICADA
			FROM dbo.TPREGUNTAS P
			OUTER APPLY (
				SELECT MAX(CAST(R.Correcta AS INT)) AS Correcta, MAX(R.RespuestaTexto) AS RespuestaTexto, MAX(R.OpcionID_Seleccionada) AS OpcionID_Seleccionada, 
					MAX(CAST(R.Calificada AS INT)) AS Calificada
				FROM dbo.TRespEmpleado R
				WHERE R.ResultadoID = @ResultadoID AND R.PreguntaID = P.PREGUNTAID
				) AS TResp
			WHERE P.TALLERID = @TALLERID
			ORDER BY P.ORDEN, P.PREGUNTAID;
		END TRY

		BEGIN CATCH
			INSERT INTO @TBLERRORES (ERROR)
			SELECT ERROR_MESSAGE();
		END CATCH;

		IF (
				SELECT COUNT(*)
				FROM @TBLERRORES
				) > 0
		BEGIN
			SELECT 'KO' OK;

			SELECT ERROR
			FROM @TBLERRORES;

			RETURN;
		END;

		SELECT 'OK' OK;
	END;

	IF @METODO = 'ELIMINA_FORMULARIO'
	BEGIN
		SELECT @TALLERID = TALLERID
		FROM OPENJSON(@PARAMETROS) WITH (TALLERID INT '$.TALLERID')

		BEGIN TRY
			BEGIN TRAN;

			DELETE
			FROM TPREGUNTAS
			WHERE TALLERID = @TALLERID;

			COMMIT TRAN;
		END TRY

		BEGIN CATCH
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRAN;
			END

			INSERT INTO @TBLERRORES (ERROR)
			SELECT ERROR_MESSAGE()
		END CATCH

		IF (
				SELECT COUNT(*)
				FROM @TBLERRORES
				) > 0
		BEGIN
			SELECT 'KO' OK

			SELECT ERROR
			FROM @TBLERRORES

			RETURN
		END

		SELECT 'OK' OK

		RETURN
	END
END
