CREATE OR ALTER PROCEDURE DBO.SPQ_RLOTD_ASIGNAR
@JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @USUARIO VARCHAR(50),
        @IDRLOTD INT,
        @NRO_FACTURA VARCHAR(20),
        @OBSERVACION VARCHAR(256),
        @CANT_ITEM SMALLINT,
        @ESTADO VARCHAR(20),

		@MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @REGISTROS NVARCHAR(MAX),
        @PROCESO VARCHAR(50),

		@INCONSISTENCIA VARCHAR(2),
		@INCONSISTENCIAS_DETALLE NVARCHAR(MAX),
		
	
		@TIPO_FORMULARIO VARCHAR(20),
		@TIPO_DOC_PACIENTE VARCHAR(20),
		@DOCUMENTO_PACIENTE VARCHAR(20),
		@ESTADO_FACTURA VARCHAR(20),
		@FECHA_INICIO DATE,
		@FECHA_FIN DATE,
		@INCONSISTENCIA_DET VARCHAR(255),
		@OBSERVACION_DET VARCHAR(MAX),
		@CODIGO_SERVICIO VARCHAR(50),
		@AUTORIZACION VARCHAR(30),
		@DESC_SERVICIO VARCHAR(255),
		@TIPIFICACION_OP VARCHAR(50),
		@VALOR_SERVICIO DECIMAL(12, 2),
		@NOMBRE VARCHAR(80),
		@EDAD VARCHAR(3),
		@SEXO VARCHAR(10),
		@FECHA_NAC DATE,
		@OBS_COLABORADOR VARCHAR(80),
		@NOVEDAD VARCHAR(255),
		@RESPUESTA_CLIENTE VARCHAR(256);

    -- Extraer MODELO, METODO y PARAMETROS
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100)    '$.MODELO',
        METODO      VARCHAR(100)    '$.METODO',
        PARAMETROS  NVARCHAR(MAX)   AS JSON
    );

    SELECT
        @MODELO = MODELO,
        @METODO = METODO,
        @PARAMETROS = PARAMETROS
    FROM #JSON;

    IF @METODO = 'CRUDASIGNAR'
    BEGIN

        SET @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTRO');

        -- Extraer los parmetros especficos del objeto 'REGISTRO'
        SELECT
            @PROCESO = JSON_VALUE(@REGISTROS, '$.PROCESO'),
            @USUARIO = JSON_VALUE(@REGISTROS, '$.USUARIO'),
            @IDRLOTD = JSON_VALUE(@REGISTROS, '$.IDRLOTD'),
            @OBSERVACION = JSON_VALUE(@REGISTROS, '$.OBSERVACIONES'),
            @CANT_ITEM = JSON_VALUE(@REGISTROS, '$.CANT_ITEM'),
            @ESTADO = JSON_VALUE(@REGISTROS, '$.ESTADO'),
			@RESPUESTA_CLIENTE = JSON_VALUE(@REGISTROS, '$.RESPUESTA_CLIENTE');


        IF UPPER(@PROCESO) = 'ASIGNAR'
        BEGIN
            BEGIN TRY
                BEGIN TRAN;

                SELECT TOP 1
                    @IDRLOTD = IDRLOTD,
                    @NRO_FACTURA = NRO_FACTURA
                FROM RLOTD RD
				INNER JOIN RLOT R ON RD.IDRLOT = R.ID
                WHERE R.ESTADO_LOTE = 1 AND RD.ESTADO = 'Sin Tramitar'
				ORDER BY 
				ISNULL(PRIORIDAD, 0) DESC,
				IDRLOTD ASC;


                IF @IDRLOTD IS NULL
                BEGIN
                    ROLLBACK;
                    SELECT 'KO' AS OK;
                    SELECT ERROR = 'No hay registros en estado Sin Tramitar para asignar.';
                    RETURN;
                END;

                UPDATE RLOTD
                SET ESTADO = 'Asignado',
                    USUARIO_ASIGNADO = @USUARIO,
                    FECHA_ASIGNACION = GETDATE()
                WHERE IDRLOTD = @IDRLOTD;

                INSERT INTO RLOTDL (
                    IDRLOTD,
                    PROCESO,
                    OBSERVACION,
					FECHA_ASIGNACION
                )
                VALUES (
                    @IDRLOTD,
                    'Asignado',
                    CONCAT('Asignaci�n de factura ', @NRO_FACTURA, ' en la fecha ', CONVERT(VARCHAR, GETDATE(), 120)),
					GETDATE()
                );

            END TRY
            BEGIN CATCH
                ROLLBACK;
                SELECT 'KO' AS OK;
                SELECT ERROR = 'Error al asignar factura: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;

        END


        IF UPPER(@PROCESO) = 'EDITAR'
        BEGIN

            BEGIN TRY
                BEGIN TRAN;

                
                SELECT @NRO_FACTURA = NRO_FACTURA
                FROM RLOTD
                WHERE IDRLOTD = @IDRLOTD;
				
                UPDATE RLOTD
                SET
                    OBSERVACIONES = @OBSERVACION,
                    CANT_ITEM = @CANT_ITEM,
                    ESTADO = @ESTADO,
					FECHA_RESPUESTA = GETDATE(),
					COORDINADOR_RESPONDE = CASE 
						WHEN @ESTADO = 'Pendiente' THEN 0
						ELSE COORDINADOR_RESPONDE
					END
                WHERE IDRLOTD = @IDRLOTD;

				SELECT @INCONSISTENCIA = JSON_VALUE(@PARAMETROS, '$.INCONSISTENCIA');
                
				IF UPPER(@INCONSISTENCIA) = 'SI'
					
				BEGIN
			
					SET @INCONSISTENCIAS_DETALLE = JSON_QUERY(@PARAMETROS, '$.INCONSISTENCIAS_DETALLE');
					
			
					SELECT
						@TIPO_FORMULARIO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.TIPO_FORMULARIO'),
						@TIPO_DOC_PACIENTE = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.TIPO_DOC_PACIENTE'),
						@DOCUMENTO_PACIENTE = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.DOCUMENTO_PACIENTE'),
						@ESTADO_FACTURA = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.ESTADO_FACTURA'),
						@FECHA_INICIO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.FECHA_INICIO'),
						@FECHA_FIN = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.FECHA_FIN'),
						@INCONSISTENCIA_DET = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.INCONSISTENCIA'),
						@OBSERVACION_DET = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.OBSERVACION'),
						@CODIGO_SERVICIO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.CODIGO_SERVICIO'),
						@AUTORIZACION = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.AUTORIZACION'),
						@DESC_SERVICIO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.DESC_SERVICIO'),
						@TIPIFICACION_OP = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.TIPIFICACION_OP'),
						@VALOR_SERVICIO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.VALOR_SERVICIO'),
						@NOMBRE = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.NOMBRE'),
						@EDAD = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.EDAD'),
						@SEXO = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.SEXO'),
						@FECHA_NAC = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.FECHA_NAC'),
						@OBS_COLABORADOR = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.OBS_COLABORADOR'),
						@NOVEDAD = JSON_VALUE(@INCONSISTENCIAS_DETALLE, '$.NOVEDAD');

		
					INSERT INTO RLOTDI (
						IDRLOTD, TIPO_FORMULARIO, TIPO_DOC_PACIENTE, DOCUMENTO_PACIENTE, ESTADO_FACTURA, FECHA_INICIO,
						FECHA_FIN, INCONSISTENCIA, OBSERVACION, CODIGO_SERVICIO, AUTORIZACION, DESC_SERVICIO,
						TIPIFICACION_OP, VALOR_SERVICIO, NOMBRE, EDAD, SEXO, FECHA_NAC, OBS_COLABORADOR, NOVEDAD
					)
					VALUES (
						@IDRLOTD, @TIPO_FORMULARIO, @TIPO_DOC_PACIENTE, @DOCUMENTO_PACIENTE, @ESTADO_FACTURA, @FECHA_INICIO,
						@FECHA_FIN, @INCONSISTENCIA_DET, @OBSERVACION_DET, @CODIGO_SERVICIO, @AUTORIZACION, @DESC_SERVICIO,
						@TIPIFICACION_OP, @VALOR_SERVICIO, @NOMBRE, @EDAD, @SEXO, @FECHA_NAC, @OBS_COLABORADOR, @NOVEDAD
					);
				END
				--hice cambio aqui agregue estado asignacion en 1
				IF @ESTADO IN ('Liquidado', 'Devolucion')
				BEGIN
					UPDATE RCALD
					SET
						ESTADO = 'Auditoria',
						ESTADO_ASIGNADO = 1,
						OBSERVACION_RECHAZO = CASE WHEN @ESTADO <> 'Ajuste' THEN NULL ELSE OBSERVACION_RECHAZO END
					WHERE
						IDRLOTD = @IDRLOTD
						AND IDRLOTD IS NOT NULL;
				END
				
				INSERT INTO RLOTDL(
                    IDRLOTD,
                    PROCESO,
                    OBSERVACION,
                    FECHA_ASIGNACION,
                    FECHA_RESPUESTA
                )
                VALUES (
                    @IDRLOTD,
                    CONCAT('Actualizaci�n de estado a: ', @ESTADO),
                    CONCAT('Factura ', @NRO_FACTURA, ' se actualiza al estado: ', @ESTADO),
                    GETDATE(),
                    GETDATE()
                );


            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0
                    ROLLBACK;
                SELECT 'KO' AS OK;
                SELECT ERROR = 'Error al editar/finalizar factura: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;

        END


		/*IF UPPER(@PROCESO) = 'PENDIENTES'
        BEGIN

            BEGIN TRY
                BEGIN TRAN;

                UPDATE RLOTD
                SET
                    RESPUESTA_CLIENTE = @RESPUESTA_CLIENTE,
                    ESTADO = 'Respondido'
                WHERE IDRLOTD = @IDRLOTD;

                SELECT @NRO_FACTURA = NRO_FACTURA
                FROM RLOTD
                WHERE IDRLOTD = @IDRLOTD;

                INSERT INTO RLOTDL (
                    IDRLOTD,
                    PROCESO,
                    OBSERVACION,
                    FECHA_RESPUESTA
                )
                VALUES (
                    @IDRLOTD,
                    'Respondido por Cliente',
                    CONCAT('Respuesta del cliente recibida para factura: ', @NRO_FACTURA, '. Contenido: ', LEFT(@RESPUESTA_CLIENTE, 200) + CASE WHEN LEN(@RESPUESTA_CLIENTE) > 200 THEN '...' ELSE '' END),
                    GETDATE()
                );

            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0
                    ROLLBACK;
                SELECT 'KO' AS OK;
                SELECT ERROR = 'Error al registrar respuesta del cliente: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

            COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
        END*/

    END


    IF @METODO = 'CRUDPROCESADOS'
    BEGIN

        SET @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTRO');


        SELECT
        @PROCESO = JSON_VALUE(@REGISTROS, '$.PROCESO'),
        @IDRLOTD = JSON_VALUE(@REGISTROS, '$.IDRLOTD');


        IF UPPER(@PROCESO) = 'VERDETALLES'
        BEGIN
        BEGIN TRY

            IF @IDRLOTD IS NULL OR @IDRLOTD = 0
            BEGIN
            SELECT 'KO' AS KO, 'Debe especificar el ID para ver los detalles.' AS ERROR;
            RETURN;
            END
            

            SELECT
            R.PROCESO                 AS titulo,
            R.PROCESO                 AS tipo,
            R.OBSERVACION             AS descripcion,
            CONVERT(VARCHAR(19), R.FECHA_ASIGNACION, 120) AS fechaAsignacion,
            U.NOMBRE                  AS nombreUsuarioAsignado
            FROM
            RLOTDL AS R
            INNER JOIN
            RLOTD AS RD ON R.IDRLOTD = RD.IDRLOTD
            LEFT JOIN
            USUSU AS U ON RD.USUARIO_ASIGNADO = U.USUARIO
            WHERE
            R.IDRLOTD = @IDRLOTD
            ORDER BY
            R.IDLOG DESC;
        
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK;
            SELECT ERROR = 'Error SQL al obtener la trazabilidad: ' + ERROR_MESSAGE();
            RETURN;
        END CATCH

        RETURN;
        END
    END


END;
