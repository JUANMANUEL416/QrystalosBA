CREATE OR ALTER PROCEDURE DBO.SPQ_RLOT_LOTE
@JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @PARAMETROS NVARCHAR(MAX),
        @PROCESO VARCHAR(20),
        @IDTERCERO VARCHAR(20),
        @USUARIO VARCHAR(20),
        @DETALLE NVARCHAR(MAX),
        @IDRLOT INT,
		@IDASIGNACION_LOTE VARCHAR(20),
		@ID INT;

	DECLARE @NIT_MANUAL VARCHAR(50);
	DECLARE @RADICADO_MANUAL VARCHAR(50);
	
    DECLARE @IDASIGNACION_LISTA NVARCHAR(MAX);
	DECLARE @TOTAL_REGISTROS_ACTUALIZADOS INT = 0;
    DECLARE @TOTAL_REGISTROS_ENCONTRADOS INT = 0;

	DECLARE @OBSERVACION_RESPUESTA NVARCHAR(256);
	DECLARE @USUARIO_RESPUESTA VARCHAR(20);
	DECLARE @NOMBRE_USUARIO VARCHAR(100);
    
    DECLARE @ErrorMessage NVARCHAR(MAX)
    DECLARE @FriendlyMessage NVARCHAR(MAX);
    DECLARE @TBLERRORES TABLE(ERROR VARCHAR(200));

	DECLARE @RadicadosExcel TABLE (RADICADO VARCHAR(50));

	DECLARE @ErroresLote TABLE (
        RADICADO VARCHAR(50) NULL,
        DESCRIPCION_ERROR VARCHAR(500)
    );

	DECLARE @TBL_PRIORIZACION TABLE (
        ID INT IDENTITY(1,1),
        NIT VARCHAR(50) NOT NULL,
        NRO_FACTURA VARCHAR(20) NOT NULL,
        RADICADO VARCHAR(50) NOT NULL
    );

	DECLARE @DETALLE_PRIORI NVARCHAR(MAX);
    DECLARE @RadicadosDuplicados NVARCHAR(MAX);
    -- Extraer MODELO, METODO y PARAMETROS
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO      VARCHAR(100)    '$.MODELO',
        METODO      VARCHAR(100)    '$.METODO',
        PARAMETROS  NVARCHAR(MAX)   AS JSON
    );
    SELECT @MODELO = MODELO,
           @METODO = METODO,
           @PARAMETROS = PARAMETROS
    FROM #JSON;

	DROP TABLE #JSON;

  IF @METODO = 'CRUDRLOT'
  BEGIN
    SELECT
    @PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
    @IDTERCERO = JSON_VALUE(@PARAMETROS, '$.IDTERCERO'),
    @USUARIO = JSON_VALUE(@PARAMETROS, '$.USUARIO'),
        @DETALLE = JSON_QUERY(@PARAMETROS, '$.DETALLE');

		SELECT TOP 1 @IDASIGNACION_LOTE = IDASIGNACION
		FROM OPENJSON(@DETALLE)
		WITH (
				IDASIGNACION VARCHAR(20) '$.IDASIGNACION'
		);
        
        --1. Valido que el Excel no venga vaco --12
        IF EXISTS (SELECT 1 FROM RLOT WHERE IDASIGNACION=@IDASIGNACION_LOTE) AND 1=2
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR = 'El ID de asignacion '+coalesce(@IDASIGNACION_LOTE,'')+' ya existe.';
            SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
            RETURN;
        END;
    BEGIN TRAN;
        BEGIN TRY
          IF UPPER(@PROCESO) = 'INSERTAR'
          BEGIN
              SELECT
              T.NIT, T.RAZON_SOCIAL, T.RADICADO, T.NRO_FACTURA,
              T.VALOR_FACTURA_INT, T.FECHA_RADICACION, T.ESTADO_FACTURA,
              T.LINEA, T.IDASIGNACION, T.IMAGEN, T.RADICADO_IMAGEN,
              T.FECHA_REINGRESO, T.FECHA_ASIGNACION, T.OPERADOR_PROCESAMIENTO,
              T.OBSERVACIONES, T.UBICACION_IMAGEN, 'Sin Tramitar' as ESTADO, T.PRIORIDAD, T.CANT_ITEM
                    INTO #RLOTD
            FROM OPENJSON(@DETALLE)
            WITH (
              NIT VARCHAR(20) '$.NIT',
              RAZON_SOCIAL VARCHAR(256) '$.RAZON_SOCIAL',
              RADICADO VARCHAR(50) '$.RADICADO',
              NRO_FACTURA VARCHAR(20) '$.NRO_FACTURA',
              VALOR_FACTURA_INT DECIMAL(14,2) '$.VALOR_FACTURA_INT',
              FECHA_RADICACION DATETIME '$.FECHA_RADICACION',
              ESTADO_FACTURA VARCHAR(20) '$.ESTADO_FACTURA',
              LINEA VARCHAR(20) '$.LINEA',
              IDASIGNACION VARCHAR(20) '$.IDASIGNACION',
              IMAGEN VARCHAR(50) '$.IMAGEN',
              RADICADO_IMAGEN VARCHAR(50) '$.RADICADO_IMAGEN',
              FECHA_REINGRESO DATETIME '$.FECHA_REINGRESO',
              FECHA_ASIGNACION DATETIME '$.FECHA_ASIGNACION',
              OPERADOR_PROCESAMIENTO VARCHAR(256) '$.OPERADOR_PROCESAMIENTO',
              OBSERVACIONES VARCHAR(256) '$.OBSERVACIONES',
              UBICACION_IMAGEN VARCHAR(50) '$.UBICACION_IMAGEN',
              PRIORIDAD BIT '$.PRIORIDAD',
              CANT_ITEM SMALLINT '$.CANT_ITEM'
            ) AS T;

            IF NOT EXISTS (SELECT 1 FROM #RLOTD WHERE RADICADO IS NOT NULL)
            BEGIN
              ROLLBACK;
					    SELECT 'KO' AS OK;
					    SELECT ERROR = 'El archivo Excel no contiene registros.';
                        SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0; 
              RETURN;
            END;


            -- 2. Valido que los campos obligatorios no sean nulos o vacos
                   -- Los registros fallidos se insertan en @ErroresLote
            INSERT INTO @ErroresLote (RADICADO, DESCRIPCION_ERROR)
            SELECT
			T.RADICADO,
			'Campos obligatorios incompletos (NIT, Raz�n Social, Factura, Valor, Fechas, Radicado o ID Asignaci�n).' AS DESCRIPCION_ERROR
            FROM #RLOTD T
            WHERE
              ISNULL(TRIM(T.NIT),'') = '' OR
              ISNULL(TRIM(T.RAZON_SOCIAL),'') = '' OR
              ISNULL(TRIM(T.RADICADO),'') = '' OR
              ISNULL(TRIM(T.NRO_FACTURA),'') = '' OR
              T.VALOR_FACTURA_INT IS NULL OR
              T.FECHA_RADICACION IS NULL OR
			  ISNULL(TRIM(T.IDASIGNACION),'') = '';


                    -- 2.5. Valido radicados duplicados dentro del mismo Excel
            INSERT INTO @ErroresLote (RADICADO, DESCRIPCION_ERROR)
            SELECT DISTINCT
                T.RADICADO,
                'Radicado duplicado dentro del mismo archivo Excel.'
            FROM #RLOTD T
                    WHERE NOT EXISTS (SELECT 1 FROM @ErroresLote A WHERE A.RADICADO=T.RADICADO)
                    GROUP BY RADICADO
                    HAVING COUNT(RADICADO) > 1


				    -- -- 3. Valido radicados duplicados (verifico si algn radicado ya existe en RLOTD)
                    INSERT INTO @ErroresLote (RADICADO, DESCRIPCION_ERROR)
                    SELECT DISTINCT
                        RE.RADICADO, 'Radicado ya existe.'
                    FROM #RLOTD AS RE
                        INNER JOIN RLOTD AS RD ON RE.RADICADO = RD.RADICADO
                    WHERE NOT EXISTS (SELECT 1 FROM @ErroresLote A WHERE A.RADICADO=RE.RADICADO)


                    --4. Verificar si hubo errores en las validaciones
                    IF EXISTS (SELECT 1 FROM @ErroresLote)
                    BEGIN
                        IF @@TRANCOUNT > 0 
                            ROLLBACK;
					
                        SELECT 'KO' AS OK;
                        SELECT ERROR = CONCAT('Carga Fallida! Se encontraron ', COUNT(DISTINCT RADICADO), ' radicados con errores. Descargue el archivo de errores para correcci�n.')
                        FROM @ErroresLote;
                        SELECT RADICADO, DESCRIPCION_ERROR FROM @ErroresLote;
					
                        RETURN;
                    END;
                 
            -- Insertar cabecera EXCEL
            INSERT INTO RLOT (IDTERCERO, USUARIO_REGISTRO, IDASIGNACION)
            VALUES (@IDTERCERO, @USUARIO, @IDASIGNACION_LOTE);

            SET @IDRLOT = SCOPE_IDENTITY();

            -- Insertar detalle
            INSERT INTO RLOTD (
              IDRLOT, NIT, RAZON_SOCIAL, RADICADO, NRO_FACTURA,
              VALOR_FACTURA_INT, FECHA_RADICACION, ESTADO_FACTURA,
              LINEA, IDASIGNACION, IMAGEN, RADICADO_IMAGEN,
              FECHA_REINGRESO, FECHA_ASIGNACION, OPERADOR_PROCESAMIENTO,
              OBSERVACIONES, UBICACION_IMAGEN, ESTADO, PRIORIDAD, CANT_ITEM
            )
            SELECT
              @IDRLOT,
              T.NIT, T.RAZON_SOCIAL, T.RADICADO, T.NRO_FACTURA,
              T.VALOR_FACTURA_INT, T.FECHA_RADICACION, T.ESTADO_FACTURA,
              T.LINEA, T.IDASIGNACION, T.IMAGEN, T.RADICADO_IMAGEN,
              T.FECHA_REINGRESO, T.FECHA_ASIGNACION, T.OPERADOR_PROCESAMIENTO,
              T.OBSERVACIONES, T.UBICACION_IMAGEN, ESTADO, T.PRIORIDAD, T.CANT_ITEM
            FROM #RLOTD T
          END
        END TRY
    BEGIN CATCH
            SELECT @ErrorMessage = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 
                ROLLBACK;

            SELECT 'KO' AS OK;
            SET @FriendlyMessage ='Hubo un error de sistema inesperado. Por favor, reporte el fallo a soporte t�cnico. Codigo de error: ' + CAST(@ErrorMessage AS NVARCHAR(10));
            SELECT ERROR = @FriendlyMessage; 
            SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0;
            RETURN;
    END CATCH

    IF @@TRANCOUNT > 0 
            COMMIT;
    SELECT 'OK' AS OK;
        SELECT RADICADO = NULL, DESCRIPCION_ERROR = NULL WHERE 1 = 0; 
		RETURN;
  END

	-- METODO 2: CRUDPRIORI (Priorizacin Masiva y Manual)
	IF @METODO = 'CRUDPRIORI'
	BEGIN
	

		SELECT
			@PROCESO	= JSON_VALUE(@PARAMETROS, '$.PROCESO'),
			@USUARIO	= JSON_VALUE(@PARAMETROS, '$.USUARIO');

		SELECT @NOMBRE_USUARIO = NOMBRE
        FROM USUSU
        WHERE USUARIO = @USUARIO;

		SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);

		BEGIN TRY
			BEGIN TRAN;

            IF UPPER(@PROCESO) = 'ACTUALIZAR_MANUAL'
            BEGIN
                -- Extraccin de parmetros especficos del manual
                SELECT
                    @RADICADO_MANUAL = JSON_VALUE(@PARAMETROS, '$.RADICADO'),
                    @IDASIGNACION_LISTA = JSON_VALUE(@PARAMETROS, '$.IDASIGNACION'); 
                
                -- 1. Validacin de campos obligatorios
                IF ISNULL(LTRIM(RTRIM(@RADICADO_MANUAL)), '') = '' OR ISNULL(LTRIM(RTRIM(@IDASIGNACION_LISTA)), '') = ''
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK;
					SELECT 'KO' AS OK;
					SELECT ERROR = 'El Radicado y la lista de Asignaci�n son obligatorios para la priorizaci�n manual.';
					RETURN;
                END;
                
                -- 2. Validar existencia de registros
                SELECT @TOTAL_REGISTROS_ENCONTRADOS = COUNT(R.IDRLOTD)
                FROM RLOTD AS R
                INNER JOIN STRING_SPLIT(@IDASIGNACION_LISTA, ',') AS L 
                    ON R.IDASIGNACION = L.value
                WHERE R.RADICADO = @RADICADO_MANUAL;
                

                IF @TOTAL_REGISTROS_ENCONTRADOS = 0
                BEGIN
                    IF @@TRANCOUNT > 0 ROLLBACK;
					SELECT 'KO' AS OK;
					SELECT ERROR = 'No se encontraron registros para actualizar con el Radicado especificado y los IDs de asignaci�n proporcionados.';
					RETURN;
                END;

                -- 3. ACTUALIZACIN MANUAL: ESTADO a 'Sin Tramitar' y PRIORIDAD a 1
                UPDATE R
				SET R.PRIORIDAD = 1
				FROM RLOTD AS R
                    INNER JOIN STRING_SPLIT(@IDASIGNACION_LISTA, ',') AS L  ON R.IDASIGNACION = L.value
				WHERE R.RADICADO = @RADICADO_MANUAL AND R.ESTADO = 'Sin Tramitar'

                SET @TOTAL_REGISTROS_ACTUALIZADOS = @@ROWCOUNT;
                
                -- 4. Insertar en la tabla de log (RLOTDL)
				INSERT INTO RLOTDL (
					IDRLOTD,
					PROCESO,
					OBSERVACION,
					FECHA_ASIGNACION
				)
				SELECT
					R.IDRLOTD,
					'Prioridad Manual',
					CONCAT('Factura(s) priorizada(s) manualmente por el usuario ', @NOMBRE_USUARIO, ' - Radicado: ', R.RADICADO, ' (ID Asignaci�n: ', R.IDASIGNACION, ')'),
					GETDATE()
				FROM RLOTD AS R
                    INNER JOIN STRING_SPLIT(@IDASIGNACION_LISTA, ',') AS L  ON R.IDASIGNACION = L.value
				WHERE R.RADICADO = @RADICADO_MANUAL AND R.ESTADO = 'Sin Tramitar'
            END
            
			IF UPPER(@PROCESO) = 'ACTUALIZAR_MASIVO'
			BEGIN
				
				SELECT @DETALLE_PRIORI	= JSON_QUERY(@PARAMETROS, '$.DETALLE');


				INSERT INTO @TBL_PRIORIZACION (NIT, NRO_FACTURA, RADICADO)
				SELECT
                    ISNULL(T.NIT, ''), 
                    ISNULL(T.NRO_FACTURA, ''),
                    ISNULL(T.RADICADO, '')
				FROM OPENJSON(@DETALLE_PRIORI)
				WITH (
					NIT VARCHAR(50) '$.NIT',
					NRO_FACTURA VARCHAR(20) '$.NRO_FACTURA',
					RADICADO VARCHAR(50) '$.RADICADO'
				) AS T;

				-- 2. Valido que el archivo no venga vaco
				IF NOT EXISTS (SELECT 1 FROM @TBL_PRIORIZACION)
				BEGIN
					IF @@TRANCOUNT > 0 ROLLBACK;
					SELECT 'KO' AS OK;
					SELECT ERROR = 'El archivo de priorizaci�n masiva no contiene registros.';
					RETURN;
				END;
                
                -- 3. VALIDACIN MEJORADA: Valido que los campos obligatorios no sean vacos (o nulos convertidos a '').
				IF EXISTS (
					SELECT 1
					FROM @TBL_PRIORIZACION
					WHERE
						LTRIM(RTRIM(NIT)) = '' OR
						LTRIM(RTRIM(NRO_FACTURA)) = '' OR
						LTRIM(RTRIM(RADICADO)) = ''
				)
				BEGIN

					IF @@TRANCOUNT > 0 ROLLBACK;
					SELECT 'KO' AS OK;
					SELECT ERROR = 'Error en el archivo. hay campos vacio que son obligatorio';
					RETURN;
				END;

				-- 4. Valido existencia de todos los registros (si pasa la validacin de campos)
				IF EXISTS (
					SELECT 1
					FROM @TBL_PRIORIZACION AS T
					LEFT JOIN RLOTD AS R
						ON T.NIT = R.NIT	
						AND T.NRO_FACTURA = R.NRO_FACTURA
						AND T.RADICADO = R.RADICADO
					WHERE R.IDRLOTD IS NULL
				)
				BEGIN
					IF @@TRANCOUNT > 0 ROLLBACK;
					SELECT 'KO' AS OK;
					SELECT ERROR = 'Error: Uno o m�s registros del lote (NIT/NRO_FACTURA/RADICADO) no existen en el sistema. Se ha deshecho la operaci�n.';
					RETURN;
				END;
                
        -- 5. Actualizacin y Log Masivo (si todas las validaciones pasan)
				UPDATE R SET PRIORIDAD = 1
				FROM RLOTD AS R
				    INNER JOIN @TBL_PRIORIZACION AS T ON T.NIT = R.NIT AND T.NRO_FACTURA = R.NRO_FACTURA AND T.RADICADO = R.RADICADO
       WHERE R.ESTADO = 'Sin Tramitar'

        SET @TOTAL_REGISTROS_ACTUALIZADOS = @@ROWCOUNT;

				INSERT INTO RLOTDL ( IDRLOTD, PROCESO, OBSERVACION, FECHA_ASIGNACION )
				SELECT R.IDRLOTD, 'Prioridad Masiva', CONCAT('Factura priorizada masivamente por el usuario ', @NOMBRE_USUARIO, ' - Nro: ', T.NRO_FACTURA, ' (Radicado: ', T.RADICADO, ')'), GETDATE()
				FROM RLOTD AS R
				    INNER JOIN @TBL_PRIORIZACION AS T ON T.NIT = R.NIT AND T.NRO_FACTURA = R.NRO_FACTURA AND T.RADICADO = R.RADICADO
       WHERE R.ESTADO = 'Sin Tramitar'
			END

		END TRY
		BEGIN CATCH		
			DECLARE @ErrorNumber2 INT = ERROR_NUMBER();

			IF @@TRANCOUNT > 0 
                ROLLBACK;
			SELECT 'KO' AS OK			
			SET @FriendlyMessage ='Hubo un error al procesar la priorizaci�n: '+ ERROR_MESSAGE();

			SELECT ERROR = @FriendlyMessage;
			RETURN;
		END CATCH

		IF @@TRANCOUNT > 0 
            COMMIT;
		SELECT 'OK' AS OK;
		RETURN;
	END


	IF @METODO = 'ACCIONES'
	BEGIN
	
		SELECT
			@PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
			@IDRLOT = JSON_VALUE(@PARAMETROS, '$.IDRLOTD');


		IF UPPER(@PROCESO) = 'DETALLEPENDIENTE'
		BEGIN
		
			SELECT
				R.RESPUESTA_CLIENTE,
				R.USUARIO_ASIGNADO,
				R.OBSERVACIONES,
				U.NOMBRE
			FROM RLOTD AS R
			INNER JOIN USUSU AS U ON R.USUARIO_ASIGNADO = U.USUARIO
			WHERE R.IDRLOTD = @IDRLOT;

			RETURN;
		END

		IF UPPER(@PROCESO) = 'RESPONDER'
		BEGIN
         
            SELECT
                @OBSERVACION_RESPUESTA = JSON_VALUE(@PARAMETROS, '$.OBSERVACION'),
                @USUARIO_RESPUESTA = JSON_VALUE(@PARAMETROS, '$.USUARIO');

			SELECT @NOMBRE_USUARIO = NOMBRE
            FROM USUSU
            WHERE USUARIO = @USUARIO_RESPUESTA;
        
            -- Fallback por si no encuentra el nombre
            SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO_RESPUESTA);

            IF @IDRLOT IS NULL OR ISNULL(LTRIM(RTRIM(@OBSERVACION_RESPUESTA)), '') = '' OR ISNULL(LTRIM(RTRIM(@USUARIO_RESPUESTA)), '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Faltan parametros para procesar la respuesta del pendiente.';
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;

       
                UPDATE RLOTD
                SET
                    RESPUESTA_PENDIENTE = @OBSERVACION_RESPUESTA, 
                    USUARIO_ASIGNADO = @USUARIO_RESPUESTA,      
                    ESTADO = 'Pendiente' ,
					COORDINADOR_RESPONDE = 1,
					OBSERVACIONES = NULL
                WHERE IDRLOTD = @IDRLOT;

       
                INSERT INTO RLOTDL (IDRLOTD, PROCESO, OBSERVACION, FECHA_ASIGNACION ,FECHA_RESPUESTA)
                VALUES (
                    @IDRLOT,
                    'Respuesta Pendiente',
                    CONCAT('Pendiente respondido por el coordinador con el usuario ', @NOMBRE_USUARIO, '. Respuesta: ', @OBSERVACION_RESPUESTA),
                    GETDATE(),
					GETDATE()
                );
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error de SQL al intentar responder el pendiente: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

			IF @@TRANCOUNT > 0 COMMIT;
                SELECT 'OK' AS OK;
                RETURN;

		END
		IF UPPER(@PROCESO) = 'REASIGNAR'
		BEGIN

            SELECT
                @USUARIO_RESPUESTA = JSON_VALUE(@PARAMETROS, '$.USUARIO');

			SELECT @NOMBRE_USUARIO = NOMBRE
            FROM USUSU
            WHERE USUARIO = @USUARIO_RESPUESTA;

			SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO_RESPUESTA);

            IF @IDRLOT IS NULL OR ISNULL(LTRIM(RTRIM(@USUARIO_RESPUESTA)), '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Faltan parametros para reasignar el pendiente.';
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;
                
                DECLARE @USUARIO_ANTERIOR VARCHAR(20);
				DECLARE @NOMBRE_USUARIO_ANTERIOR VARCHAR(100);

                SELECT @USUARIO_ANTERIOR = USUARIO_ASIGNADO
                FROM RLOTD
                WHERE IDRLOTD = @IDRLOT;

				SELECT @NOMBRE_USUARIO_ANTERIOR = NOMBRE
                FROM USUSU
                WHERE USUARIO = @USUARIO_ANTERIOR;

                SET @NOMBRE_USUARIO_ANTERIOR = ISNULL(@NOMBRE_USUARIO_ANTERIOR, @USUARIO_ANTERIOR);

  
                UPDATE RLOTD
                SET
                   USUARIO_ASIGNADO = @USUARIO_RESPUESTA 
                WHERE IDRLOTD = @IDRLOT;


                INSERT INTO RLOTDL (IDRLOTD, PROCESO, OBSERVACION, FECHA_ASIGNACION)
                VALUES (
                    @IDRLOT,
                    'Reasignaci�n',
                    CONCAT('Reasignado de ', @NOMBRE_USUARIO_ANTERIOR, ' a ', @NOMBRE_USUARIO, ' por el mismo usuario.'),
                    GETDATE()
                );
                
               

            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error de SQL al intentar reasignar el pendiente: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

			 IF @@TRANCOUNT > 0 COMMIT;
                SELECT 'OK' AS OK;
                RETURN;

		END

	END


	IF @METODO = 'ACTIVACION'
	BEGIN
        SELECT
            @PROCESO   = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
            @ID		   = JSON_VALUE(@PARAMETROS, '$.ID'),
            @USUARIO   = JSON_VALUE(@PARAMETROS, '$.USUARIO'); 

		IF UPPER(@PROCESO) = 'ACTIVAR'
		BEGIN

			SELECT @NOMBRE_USUARIO = NOMBRE
            FROM USUSU
            WHERE USUARIO = @USUARIO;
        
            SET @NOMBRE_USUARIO = ISNULL(@NOMBRE_USUARIO, @USUARIO);
            
            IF @ID IS NULL OR ISNULL(LTRIM(RTRIM(@USUARIO)), '') = ''
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Faltan parametros para activar el lote.';
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;

                UPDATE RLOT
                SET 
                    ESTADO_LOTE = 1, 
                    USUARIO_ACTIVACION = @USUARIO,
                    FECHA_ACTIVACION = GETDATE()
                WHERE 
                    ID = @ID
                    AND ESTADO_LOTE = 0;

                INSERT INTO RLOTDL (IDRLOTD, PROCESO, OBSERVACION, FECHA_ASIGNACION)
                SELECT
                    RD.IDRLOTD,
                    'Activaci�n Lote',
                    CONCAT('Lote activado para asignaci�n por el usuario ', @NOMBRE_USUARIO, '.'),
                    GETDATE()
                FROM RLOTD RD
                WHERE RD.IDRLOT = @ID;

            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error de SQL al intentar activar el lote: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH

            IF @@TRANCOUNT > 0 COMMIT;
            SELECT 'OK' AS OK;
            RETURN;
		END


		IF UPPER(@PROCESO) = 'ELIMINAR'
		BEGIN
        
			IF @ID IS NULL
			BEGIN
				SELECT 'KO' AS OK, ERROR = 'Falta el ID del lote para eliminar.';
				RETURN;
			END

			BEGIN TRY
				BEGIN TRAN;

				DELETE FROM RLOTD 
				WHERE IDRLOT = @ID;
            
				DELETE FROM RLOT 
				WHERE ID = @ID;

				IF @@ROWCOUNT = 0
				BEGIN
					SELECT 'KO' AS OK, ERROR = 'No se encontro el lote (ID: ' + CAST(@ID AS VARCHAR) + ') para eliminar.';
					IF @@TRANCOUNT > 0 ROLLBACK;
					RETURN;
				END

				
			END TRY
			BEGIN CATCH
				IF @@TRANCOUNT > 0 ROLLBACK;
				SELECT 'KO' AS OK, ERROR = 'Error de SQL al intentar eliminar el lote: ' + ERROR_MESSAGE();
			END CATCH

			IF @@TRANCOUNT > 0 COMMIT;
			SELECT 'OK' AS OK;
			RETURN;
		END


	END

	IF @METODO = 'MANTENIMIENTO'
    BEGIN
        SELECT @PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO');

        IF UPPER(@PROCESO) = 'RESTABLECER'
        BEGIN
            BEGIN TRY
                BEGIN TRAN;

                DELETE FROM dbo.RFIN_HISTORIAL;
                DBCC CHECKIDENT ('dbo.RFIN_HISTORIAL', RESEED, 0);

                DELETE FROM dbo.RFIN_CARGA;
                DBCC CHECKIDENT ('dbo.RFIN_CARGA', RESEED, 0);

                DELETE FROM dbo.RCALD;
                DBCC CHECKIDENT ('dbo.RCALD', RESEED, 0);

                DELETE FROM dbo.RCAL;
                DBCC CHECKIDENT ('dbo.RCAL', RESEED, 0);

                DELETE FROM dbo.RLOTDL;
                DBCC CHECKIDENT ('dbo.RLOTDL', RESEED, 0);

                DELETE FROM dbo.RLOTDI;
                DBCC CHECKIDENT ('dbo.RLOTDI', RESEED, 0);

                DELETE FROM dbo.DOCS_METADATOS;
                DBCC CHECKIDENT ('dbo.DOCS_METADATOS', RESEED, 0);

                DELETE FROM dbo.DOCS_TRAZABILIDAD;
                DBCC CHECKIDENT ('dbo.DOCS_TRAZABILIDAD', RESEED, 0);

                DELETE FROM dbo.RAD_ADJUNTOS;
                DBCC CHECKIDENT ('dbo.RAD_ADJUNTOS', RESEED, 0);

                DELETE FROM dbo.RLOTD;
                DBCC CHECKIDENT ('dbo.RLOTD', RESEED, 0);

                DELETE FROM dbo.RLOT;
                DBCC CHECKIDENT ('dbo.RLOT', RESEED, 0);

                IF @@TRANCOUNT > 0 COMMIT;
                SELECT 'OK' AS OK;
                RETURN;

            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK;
                SELECT 'KO' AS OK, ERROR = 'Error al restablecer datos: ' + ERROR_MESSAGE();
                RETURN;
            END CATCH
        END
    END


END;
