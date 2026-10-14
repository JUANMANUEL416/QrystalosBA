CREATE OR ALTER PROCEDURE DBO.SPQ_RCAL_CALIDAD
@JSON NVARCHAR(MAX)
AS
BEGIN
� � SET NOCOUNT ON;

� � DECLARE
� � � � @FECHA_INICIO DATE,� � � � ��
� � � � @FECHA_FIN DATE,� � � � � � �
� � � � @USUARIO VARCHAR(50),
� � � � @PORCENTAJE DECIMAL(5, 2),
� � � � @NewIDRCAL INT,
� � � � @ESTADO_INICIAL_RCALD VARCHAR(20) = 'Auditoria',
� � � � @PROCESO VARCHAR(50),
� � � � @MODELO VARCHAR(100),
� � � � @METODO VARCHAR(100),
� � � � @PARAMETROS NVARCHAR(MAX),
� � � � @REGISTROS NVARCHAR(MAX),

		@USUARIO_ASIGNADO VARCHAR(50), 
        @USUARIO_REGISTRO VARCHAR(50), 
        @DETALLE NVARCHAR(MAX),
        @IDASIGNACION_LOTE VARCHAR(20),
        @IDRLOT INT,
        @ErrorMessage NVARCHAR(4000);

� � -- Bloque para parsear el JSON
� � SELECT * INTO #JSON FROM OPENJSON(@JSON) WITH (
� � � � MODELO� � � VARCHAR(100)� � '$.MODELO',
� � � � METODO� � � VARCHAR(100)� � '$.METODO',
� � � � PARAMETROS� NVARCHAR(MAX)� �AS JSON
� � );

� � SELECT
� � � � @MODELO = MODELO,
� � � � @METODO = METODO,
� � � � @PARAMETROS = PARAMETROS
� � FROM #JSON;
� ��
� � IF OBJECT_ID('tempdb..#JSON') IS NOT NULL DROP TABLE #JSON;

� � IF @METODO = 'CRUDINSERTAR'
� � BEGIN
� � � � SET @REGISTROS = JSON_QUERY(@PARAMETROS, '$.REGISTRO');

� � � � SELECT
� � � � � � @PROCESO = JSON_VALUE(@REGISTROS, '$.PROCESO'),
� � � � � � -- Conversi�n a DATE (seguro para YYYY-MM-DD)
� � � � � � @FECHA_INICIO = CONVERT(DATE, JSON_VALUE(@REGISTROS, '$.FECHA_INICIO')),
� � � � � � @FECHA_FIN = CONVERT(DATE, JSON_VALUE(@REGISTROS, '$.FECHA_FINAL')),
� � � � � � @USUARIO = JSON_VALUE(@REGISTROS, '$.USUARIO'),
� � � � � � -- Conversi�n a DECIMAL
� � � � � � @PORCENTAJE = CONVERT(DECIMAL(5, 2), JSON_VALUE(@REGISTROS, '$.PORCENTAJE'));

� � � � IF UPPER(@PROCESO) = 'GUARDAR_FILTRO'
� � � � BEGIN
� � � �
� � � � � � -- 1. VALIDACIONES DE FECHAS
� � � � � � -- 1.1. Validar que la FECHA_FIN no sea el d�a de hoy
� � � � � � IF @FECHA_FIN >= CAST(GETDATE() AS DATE)
� � � � � � BEGIN
� � � � � � � � SELECT�
� � � � � � � � � � 'KO' AS OK,�
� � � � � � � � � � ERROR = 'La Fecha Final del filtro (' + CONVERT(VARCHAR, @FECHA_FIN, 120) + ') no puede ser igual o posterior a la fecha actual.';
� � � � � � � � RETURN;
� � � � � � END

� � � � � � -- 1.2. Validar que el nuevo rango no se solape con rangos existentes en RCAL
� � � � � � IF EXISTS (
� � � � � � � � SELECT 1
� � � � � � � � FROM RCAL
� � � � � � � � -- Condici�n de solapamiento
� � � � � � � � WHERE�
� � � � � � � � � � CAST(@FECHA_INICIO AS DATETIME) <= FECHA_FIN�
� � � � � � � � � � AND CAST(@FECHA_FIN AS DATETIME) >= FECHA_INICIO
� � � � � � )
� � � � � � BEGIN
� � � � � � � � SELECT�
� � � � � � � � � � 'KO' AS OK,�
� � � � � � � � � � ERROR = 'El rango de fechas seleccionado (' + CONVERT(VARCHAR, @FECHA_INICIO, 120) + ' a ' + CONVERT(VARCHAR, @FECHA_FIN, 120) + ') ya se encuentra total o parcialmente cubierto por un lote de Calidad existente.';
� � � � � � � � RETURN;
� � � � � � END
� � � � � ��
� � � � � � BEGIN TRY
� � � � � � � � BEGIN TRAN;

� � � � � � � � -- 2. Insertar el encabezado en RCAL
� � � � � � � � INSERT INTO RCAL (FECHA_INICIO, FECHA_FIN, USUARIO, PORCENTAJE, FECHA_CREACION)
� � � � � � � � VALUES (CAST(@FECHA_INICIO AS DATETIME), CAST(@FECHA_FIN AS DATETIME), @USUARIO, CAST(@PORCENTAJE AS INT), GETDATE());

� � � � � � � � SET @NewIDRCAL = SCOPE_IDENTITY();

� � � � � � � � IF @NewIDRCAL IS NOT NULL
� � � � � � � � BEGIN
� � � � � � � � � ��
� � � � � � � � � � -- 3. L�gica de muestreo y asignaci�n a RCALD
� � � � � � � � � � WITH RLD_Liquidado AS (
� � � � � � � � � � � � SELECT
� � � � � � � � � � � � � � RD.IDRLOTD,
� � � � � � � � � � � � � � RD.USUARIO_ASIGNADO,
                            COALESCE(CONVERT(DECIMAL(5, 2), U.PORCENTAJE), @PORCENTAJE) AS PorcentajeAUsar,
                            
� � � � � � � � � � � � � � ROW_NUMBER() OVER (PARTITION BY RD.USUARIO_ASIGNADO ORDER BY NEWID()) AS RN_ALEATORIO,
� � � � � � � � � � � � � � COUNT(*) OVER (PARTITION BY RD.USUARIO_ASIGNADO) AS TotalRegistrosUsuario
� � � � � � � � � � � � FROM
� � � � � � � � � � � � � � dbo.RLOTD RD
                            -- LEFT JOIN a USUSU para obtener el porcentaje espec�fico (si existe)
                            LEFT JOIN USUSU U ON RD.USUARIO_ASIGNADO = U.USUARIO 
� � � � � � � � � � � � WHERE
� � � � � � � � � � � � � � RD.ESTADO IN ('Liquidado', 'Devolucion')
� � � � � � � � � � � � � � AND CAST(RD.FECHA_RESPUESTA AS DATE) >= @FECHA_INICIO
� � � � � � � � � � � � � � AND CAST(RD.FECHA_RESPUESTA AS DATE) <= @FECHA_FIN
� � � � � � � � � � � � � � AND RD.USUARIO_ASIGNADO IS NOT NULL
							AND NOT EXISTS(SELECT 1 FROM RCALD D WHERE D.IDRLOTD=RD.IDRLOTD)
� � � � � � � � � � ),
� � � � � � � � � � RLD_Seleccionado AS (
� � � � � � � � � � � � SELECT
� � � � � � � � � � � � � � RLD.IDRLOTD,
� � � � � � � � � � � � � � RLD.USUARIO_ASIGNADO
� � � � � � � � � � � � FROM
� � � � � � � � � � � � � � RLD_Liquidado RLD
� � � � � � � � � � � � WHERE
� � � � � � � � � � � � � � -- L�gica del m�nimo de 2 registros, usando el porcentaje calculado (PorcentajeAUsar)
� � � � � � � � � � � � � � RN_ALEATORIO <= IIF(CEILING(TotalRegistrosUsuario * (RLD.PorcentajeAUsar / 100.0))<2 AND TotalRegistrosUsuario >= 2, 2, CEILING(TotalRegistrosUsuario * (RLD.PorcentajeAUsar / 100.0)))
� � � � � � � � � � )
� � � � � � � � � � -- 4. Insertar los registros seleccionados en RCALD
� � � � � � � � � � INSERT INTO dbo.RCALD (IDRCAL, IDRLOTD, ESTADO, ESTADO_ASIGNADO, OBSERVACION_RECHAZO, USUARIO_RLOTD)
� � � � � � � � � � SELECT
� � � � � � � � � � � � @NewIDRCAL,
� � � � � � � � � � � � IDRLOTD,
� � � � � � � � � � � � @ESTADO_INICIAL_RCALD,
� � � � � � � � � � � � 0,
� � � � � � � � � � � � NULL,
� � � � � � � � � � � � USUARIO_ASIGNADO
� � � � � � � � � � FROM RLD_Seleccionado;
� � � � � � � � END
� � � � � � � � COMMIT TRAN;
� � � � � � � � SELECT 'OK' AS OK, IDRCAL = @NewIDRCAL;
� � � � � � � � RETURN;

� � � � � � END TRY
� � � � � � BEGIN CATCH
� � � � � � � � IF @@TRANCOUNT > 0
� � � � � � � � � � ROLLBACK TRAN;�
� � � � � � � �
� � � � � � � � -- Mensaje de error detallado
� � � � � � � � SELECT�
� � � � � � � � � � 'KO' AS OK,�
� � � � � � � � � � ERROR = 'Error en el filtro de Calidad. Mensaje SQL: ' + ERROR_MESSAGE(),
� � � � � � � � � � LINEA_ERROR = ERROR_LINE();�
� � � � � � � � RETURN;
� � � � � � END CATCH
� � � � END
� � END
	
	--CARGA MASIVA AJUSTE
	IF @METODO = 'CRUD_CARGA_MASIVA'
    BEGIN
        SELECT
            @PROCESO = JSON_VALUE(@PARAMETROS, '$.PROCESO'),
            @USUARIO_ASIGNADO = JSON_VALUE(@PARAMETROS, '$.USUARIO_ASIGNADO'), 
            @USUARIO_REGISTRO = JSON_VALUE(@PARAMETROS, '$.USUARIO_REGISTRO'), 
            @DETALLE = JSON_QUERY(@PARAMETROS, '$.DETALLE');

        -- 1. Validaciones b�sicas de entrada
        IF @USUARIO_ASIGNADO IS NULL
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'El Usuario Asignado es obligatorio para la carga masiva de ajuste.';
            RETURN;
        END

        IF UPPER(@PROCESO) = 'CARGA_AJUSTE'
        BEGIN
            BEGIN TRAN;
            BEGIN TRY
                
                -- 1. Crear tabla temporal con el detalle del JSON (registros a procesar)
                SELECT
                    T.NIT, 
                    T.RADICADO, 
                    T.NRO_FACTURA,
                    T.IDASIGNACION 
                    INTO #CARGA_AJUSTE_TMP
                FROM OPENJSON(@DETALLE)
                WITH (
                    NIT VARCHAR(20) '$.NIT',
                    RADICADO VARCHAR(50) '$.RADICADO',
                    NRO_FACTURA VARCHAR(20) '$.NRO_FACTURA',
                    IDASIGNACION VARCHAR(20) '$.IDASIGNACION'
                ) AS T;

                -- 2. Validar que la tabla temporal no est� vac�a
                IF NOT EXISTS (SELECT 1 FROM #CARGA_AJUSTE_TMP)
                BEGIN
                    ROLLBACK;
                    SELECT 'KO' AS OK, ERROR = 'El archivo de detalle no contiene registros v�lidos para procesar.';
                    RETURN;
                END;

                -- 3. Contar los registros del archivo que S� existen en RLOTD
                -- Usamos INNER JOIN para obtener solo los que coinciden con la llave compuesta
                SELECT 
                    T.RADICADO, 
                    RD.IDRLOTD
                    INTO #REGISTROS_ENCONTRADOS
                FROM #CARGA_AJUSTE_TMP T
                INNER JOIN dbo.RLOTD RD ON 
                    RD.IDASIGNACION = T.IDASIGNACION
                    AND RD.NIT = T.NIT
                    AND RD.NRO_FACTURA = T.NRO_FACTURA
                    AND RD.RADICADO = T.RADICADO;

                DECLARE @TOTAL_CARGADOS INT = (SELECT COUNT(1) FROM #CARGA_AJUSTE_TMP);
                DECLARE @TOTAL_ENCONTRADOS INT = (SELECT COUNT(1) FROM #REGISTROS_ENCONTRADOS);

                -- 4. CRITERIO DE FALLO: Si no se encontr� el 100% de los registros en RLOTD
                IF @TOTAL_CARGADOS <> @TOTAL_ENCONTRADOS
                BEGIN
                    ROLLBACK;
                    SELECT 
                        'KO' AS OK, 
                        ERROR = 'Fallo la validaci�n de carga masiva de Ajuste. Se encontraron ' + CAST(@TOTAL_ENCONTRADOS AS VARCHAR) + ' de ' + CAST(@TOTAL_CARGADOS AS VARCHAR) + ' registros. La actualizaci�n requiere que el 100% de los registros existan en el sistema.';
                    -- Limpieza de temporales antes de salir
                    IF OBJECT_ID('tempdb..#CARGA_AJUSTE_TMP') IS NOT NULL DROP TABLE #CARGA_AJUSTE_TMP;
                    IF OBJECT_ID('tempdb..#REGISTROS_ENCONTRADOS') IS NOT NULL DROP TABLE #REGISTROS_ENCONTRADOS;
                    RETURN;
                END

                -- 5. Ejecutar la Actualizaci�n Masiva (si la validaci�n es 100% exitosa)
                UPDATE RD
                SET 
                    RD.ESTADO = 'Ajuste',
                    RD.USUARIO_ASIGNADO = @USUARIO_ASIGNADO
                FROM dbo.RLOTD RD
                INNER JOIN #REGISTROS_ENCONTRADOS RE ON RD.IDRLOTD = RE.IDRLOTD;

                -- 6. Actualizar el encabezado RLOTDL
                DECLARE @NOM_USUARIO_LOG VARCHAR(100);
                SELECT @NOM_USUARIO_LOG = NOMBRE FROM USUSU WHERE USUARIO = @USUARIO_REGISTRO;
                SET @NOM_USUARIO_LOG = ISNULL(@NOM_USUARIO_LOG, UPPER(@USUARIO_REGISTRO));

                INSERT INTO RLOTDL (
                    IDRLOTD, 
                    PROCESO, 
                    OBSERVACION, 
                    FECHA_ASIGNACION
                )
                SELECT 
                    RE.IDRLOTD,
                    'Carga Ajuste Calidad',
                    CONCAT('Registro pasado a estado Ajuste y reasignado a ', @USUARIO_ASIGNADO, ' por el usuario ', UPPER(@NOM_USUARIO_LOG), ' (Acci�n masiva desde Calidad)'),
                    GETDATE()
                FROM #REGISTROS_ENCONTRADOS RE;
                
                -- Limpieza de temporales
                IF OBJECT_ID('tempdb..#CARGA_AJUSTE_TMP') IS NOT NULL DROP TABLE #CARGA_AJUSTE_TMP;
                IF OBJECT_ID('tempdb..#REGISTROS_ENCONTRADOS') IS NOT NULL DROP TABLE #REGISTROS_ENCONTRADOS;
                
                COMMIT;
                
                SELECT 'OK' AS OK, MENSAJE = 'Carga masiva de Ajuste completada. Se actualizar�n ' + CAST(@TOTAL_ENCONTRADOS AS VARCHAR) + ' registros a estado "Ajuste" y se reasign� al usuario: ' + @USUARIO_ASIGNADO;
                RETURN;

            END TRY
            BEGIN CATCH
                SELECT @ErrorMessage = ERROR_MESSAGE();
                IF @@TRANCOUNT > 0  
                    ROLLBACK;

                -- Limpieza de temporales en caso de error
                IF OBJECT_ID('tempdb..#CARGA_AJUSTE_TMP') IS NOT NULL DROP TABLE #CARGA_AJUSTE_TMP;
                IF OBJECT_ID('tempdb..#REGISTROS_ENCONTRADOS') IS NOT NULL DROP TABLE #REGISTROS_ENCONTRADOS;

                SELECT 'KO' AS OK, ERROR = 'Error de sistema inesperado durante la carga masiva de ajuste. Mensaje SQL: ' + @ErrorMessage; 
                RETURN;
            END CATCH
        END

    END
END;
