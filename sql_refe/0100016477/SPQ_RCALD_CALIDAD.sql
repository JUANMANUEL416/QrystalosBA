CREATE OR ALTER PROCEDURE DBO.SPQ_RCALD_CALIDAD
@JSON NVARCHAR(MAX)
AS
BEGIN
� � SET NOCOUNT ON;

� � DECLARE
� � � � @IDRCALD INT,
		@IDRLOTD INT,
        @IDRLOT INT,
        @IDRCAL INT,
� � � � @USUARIO VARCHAR(50),
		@OBSERVACION_RECHAZO VARCHAR(500),

� � � � @MODELO VARCHAR(100),
� � � � @METODO VARCHAR(100),
� � � � @PARAMETROS NVARCHAR(MAX),
� � � � @REGISTROS NVARCHAR(MAX),
� � � � @PROCESO VARCHAR(50);

	-- Variable para almacenar el usuario auditado
	DECLARE�
		@USUARIO_AFECTADO VARCHAR(20);


� � -- 1. Extraer MODELO, METODO y PARAMETROS
� � SELECT *
� � INTO #JSON
� � FROM OPENJSON(@JSON)
� � WITH (
� � � � MODELO� � � VARCHAR(100)� � '$.MODELO',
� � � � METODO� � � VARCHAR(100)� � '$.METODO',
� � � � PARAMETROS� NVARCHAR(MAX)� �AS JSON
� � );

� � SELECT
� � � � @MODELO = MODELO,
� � � � @METODO = METODO,
� � � � @PARAMETROS = PARAMETROS
� � FROM #JSON;

� � IF OBJECT_ID('tempdb..#JSON') IS NOT NULL DROP TABLE #JSON;

� � -- Si el METODO es CRUDASIGNAR
� � IF @METODO = 'CRUDASIGNAR'
� � BEGIN

� � � � SET @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTRO');

� � � � SELECT
� � � � � � @PROCESO = JSON_VALUE(@REGISTROS, '$.PROCESO'),
� � � � � � @USUARIO = JSON_VALUE(@REGISTROS, '$.USUARIO'),
			@IDRCALD = JSON_VALUE(@REGISTROS, '$.IDRCALD'),
			@OBSERVACION_RECHAZO = JSON_VALUE(@REGISTROS, '$.DESCRIPCION');
			
		-- L�gica para obtener el USUARIO_AFECTADO, IDRCAL y IDRLOT antes de cualquier cambio
		IF @PROCESO IN ('APROBAR', 'RECHAZAR')
		BEGIN
			-- Obtenemos IDRLOTD, USUARIO_AFECTADO y IDRCAL del registro de calidad
			SELECT�
				@IDRLOTD = IDRLOTD,
				@USUARIO_AFECTADO = USUARIO_RLOTD,
                @IDRCAL = IDRCAL
			FROM RCALD
			WHERE IDRCALD = @IDRCALD;

			IF @IDRLOTD IS NULL
			BEGIN
� � � � � � � � SELECT 'KO' AS OK, 'El registro de detalle de calidad no fue encontrado.';
� � � � � � � � RETURN;
			END

            -- Obtenemos el IDRLOT de la tabla RLOTD
            SELECT @IDRLOT = IDRLOT
            FROM RLOTD
            WHERE IDRLOTD = @IDRLOTD;

            IF @IDRLOT IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'El lote principal no fue encontrado.';
                RETURN;
            END
		END


� � � � IF UPPER(@PROCESO) = 'ASIGNAR'
� � � � BEGIN
� � � � � � BEGIN TRY
� � � � � � � � BEGIN TRAN;

				SELECT TOP 1
� � � � � � � � � � @IDRCALD = RCALD.IDRCALD
� � � � � � � � FROM 
                    RCALD
                    -- Unir a RCAL para obtener la fecha de creaci�n del lote (la "bolsa")
                    JOIN RCAL ON RCALD.IDRCAL = RCAL.IDRCAL
� � � � � � � � WHERE 
                    RCALD.ESTADO = 'Auditoria' 
                    AND RCALD.ESTADO_ASIGNADO = 0
� � � � � � � � ORDER BY
                    RCAL.FECHA_CREACION ASC,
� � � � � � � � � � RCALD.IDRCALD ASC;

� � � � � � � � IF @IDRCALD IS NULL
� � � � � � � � BEGIN
� � � � � � � � � � ROLLBACK;
� � � � � � � � � � SELECT 'KO' AS OK, 'No hay registros en estado Auditoria y sin asignar.';
� � � � � � � � � � RETURN;
� � � � � � � � END;

� � � � � � � � UPDATE RCALD
� � � � � � � � SET
� � � � � � � � � � ESTADO_ASIGNADO = 1,
					AUDITOR_ASIGNADO = @USUARIO
� � � � � � � � WHERE IDRCALD = @IDRCALD;
� � � � � � � ��
� � � � � � END TRY
� � � � � � BEGIN CATCH
� � � � � � � � IF @@TRANCOUNT > 0
� � � � � � � � ROLLBACK;
� � � � � � � � SELECT 'KO' AS OK, 'Error al asignar registro para Calidad: ' + ERROR_MESSAGE();
� � � � � � � � RETURN;
� � � � � � END CATCH

� � � � � � COMMIT;
� � � � � � SELECT 'OK' AS OK;
� � � � � � RETURN;

� � � � END
		
		IF UPPER(@PROCESO) = 'RECHAZAR'
� � � � BEGIN
� � � � � � BEGIN TRY
� � � � � � � � BEGIN TRAN;

� � � � � � � � -- A. Actualizar el registro individual a RECHAZADO (Ajuste)
� � � � � � � � UPDATE RCALD
� � � � � � � � SET
� � � � � � � � � � ESTADO = 'Ajuste',
� � � � � � � � � � ESTADO_ASIGNADO = 0,
					OBSERVACION_RECHAZO = @OBSERVACION_RECHAZO
� � � � � � � � WHERE IDRCALD = @IDRCALD;

� � � � � � � � UPDATE RLOTD
� � � � � � � � SET
� � � � � � � � � � ESTADO = 'Ajuste'
� � � � � � � � WHERE IDRLOTD = @IDRLOTD;

� � � � � � � � -- Llamar a la l�gica de validaci�n masiva despu�s de la actualizaci�n individual
				EXEC DBO.VALIDAR_95_PORCIENTO 
                    @USUARIO_AFECTADO, 
                    @IDRCAL, 
                    @IDRLOT, 
                    @PROCESO = 'RECHAZAR';

� � � � � � END TRY
� � � � � � BEGIN CATCH
� � � � � � � � IF @@TRANCOUNT > 0
� � � � � � � � ROLLBACK;
� � � � � � � � SELECT 'KO' AS OK, 'Error al rechazar el registro: ' + ERROR_MESSAGE();
� � � � � � � � RETURN;
� � � � � � END CATCH

			COMMIT;
			SELECT 'OK' AS OK;
� � � � � � RETURN;

� � � � END


		IF UPPER(@PROCESO) = 'APROBAR'
� � � � BEGIN
� � � � � � BEGIN TRY
� � � � � � � � BEGIN TRAN;

� � � � � � � � -- Actualizar el registro individual a APROBADO (Certificado)
� � � � � � � � UPDATE RCALD
� � � � � � � � SET
� � � � � � � � � � ESTADO = 'Certificado',
					ESTADO_ASIGNADO = 0
� � � � � � � � WHERE IDRCALD = @IDRCALD;

� � � � � � � � UPDATE RLOTD
� � � � � � � � SET
� � � � � � � � � � ESTADO = 'Certificado'
� � � � � � � � WHERE IDRLOTD = @IDRLOTD;

� � � � � � � � -- Llamar a la l�gica de validaci�n masiva despu�s de la actualizaci�n individual
				EXEC DBO.VALIDAR_95_PORCIENTO 
                    @USUARIO_AFECTADO, 
                    @IDRCAL, 
                    @IDRLOT, 
                    @PROCESO = 'APROBAR';
� � � � � � � �

� � � � � � END TRY
� � � � � � BEGIN CATCH
� � � � � � � � IF @@TRANCOUNT > 0
� � � � � � � � � � ROLLBACK;
� � � � � � � � SELECT 'KO' AS OK, ERROR = 'Error al aprobar el registro: ' + ERROR_MESSAGE();
� � � � � � � � RETURN;
� � � � � � END CATCH

			COMMIT;
			SELECT 'OK' AS OK;
� � � � � � RETURN;

� � � � END
	END
END;
