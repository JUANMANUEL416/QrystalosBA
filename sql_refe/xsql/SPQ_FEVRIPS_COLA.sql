CREATE OR ALTER PROCEDURE DBO.SPQ_FEVRIPS_COLA @JSON NVARCHAR(MAX)
AS
DECLARE @PARAMETROS NVARCHAR(MAX)   ,@MODELO   VARCHAR(100)   ,@METODO  VARCHAR(100)
	,@USUARIO      VARCHAR(20)
	,@TIPODOC      VARCHAR(4)        ,@CNSDOC   VARCHAR(40)    ,@CLASE   VARCHAR(1)
	,@AHORA        DATETIME2(0)      ,@LIMITE   DATETIME2(0)   ,@DUENIO  VARCHAR(50)
	,@WORKER       VARCHAR(50)       ,@LOTE     INT            ,@SOLO_PRIORITARIAS BIT
	,@WATCHDOG_MIN INT               ,@MAX_INTENTOS SMALLINT   ,@MIN_HORAS_DESDE_FACTURA INT
	,@ESTADO       TINYINT           ,@ESTADO_FINAL TINYINT    ,@MENSAJE VARCHAR(500)
	,@TAMANIO_BYTES BIGINT           ,@ESPERA_SEG INT          ,@LIBERAR BIT
	,@PRIORIDAD    BIT               ,@MINUTOS  INT            ,@DOCUMENTOS NVARCHAR(MAX)
	,@CONTAR_PENDIENTES BIT
	,@MODO VARCHAR(50)               ,@DB_ACTUAL VARCHAR(128)  ,@DB_PROD VARCHAR(128)
	,@URL_PROD VARCHAR(250)          ,@URL_PRUEBA VARCHAR(250) ,@URL VARCHAR(250)
	,@IDTERCERO VARCHAR(20)          ,@NIT VARCHAR(20)         ,@ES_PROD BIT
	,@TIENE_COLA BIT                 ,@PENDIENTES INT          ,@MOTIVO VARCHAR(200)
DECLARE @TBLERRORES TABLE (ERROR VARCHAR(MAX))

BEGIN
	SELECT @MODELO     = MODELO
	     , @METODO     = METODO
	     , @USUARIO    = USUARIO
	     , @PARAMETROS = PARAMETROS
	FROM OPENJSON (@JSON)
	WITH (
		MODELO     VARCHAR(100)   '$.MODELO',
		METODO     VARCHAR(100)   '$.METODO',
		USUARIO    VARCHAR(20)    '$.USUARIO',
		PARAMETROS NVARCHAR(MAX)  AS JSON
	)

	SELECT @TIPODOC = COALESCE(JSON_VALUE(@PARAMETROS, '$.TIPODOC'), 'FV')
	     , @CNSDOC  = JSON_VALUE(@PARAMETROS, '$.CNSDOC')
	     , @CLASE   = JSON_VALUE(@PARAMETROS, '$.CLASE')

	SET @AHORA = SYSDATETIME()

   /*
	   SPQ_FEVRIPS_COLA
	   Punto unico de entrada de la cola de radicacion FEV-RIPS ante SISPRO.

	   Lo consumen los dos lados con el mismo sobre JSON:
	     - El worker del microservicio Qrys.Sispro, por conexion directa:
	           EXEC DBO.SPQ_FEVRIPS_COLA @JSON = '{"MODELO":"FEVRIPS_COLA", ...}'
	     - La pantalla de Qrystalos, via SPQ_Json con MODELO = 'FEVRIPS_COLA'.

	   Una sola implementacion para ambos: lo que el worker respeta es exactamente lo
	   que la pantalla respeta, y no hay dos versiones de la misma regla.

	   METODOS
	   -------
	   APTITUD          Veredicto previo: modo, produccion vs pruebas, NIT y URL.
	   TOMAR_LOTE       Descubre candidatas y las reclama (worker).
	   SET_ESTADO       Avance del pipeline, backoff y control de propiedad (worker).
	   TOMAR_MANUAL     Reserva un documento para envio manual (pantalla).
	   LIBERAR_MANUAL   Suelta la reserva al terminar (pantalla).
	   ENCOLAR          Reprocesar y "enviar ya" con prioridad (pantalla).
	   ESTADOS          Estado en vivo de las filas visibles de la grilla.

	   Requiere DBO.FEVRIPS_COLA (ver FEVRIPS_COLA.sql).

	   Nota sobre WITH ENCRYPTION: los demas SPQ_ del sistema se compilan cifrados.
	   Aqui se deja sin cifrar a proposito durante el despliegue por fases, porque el
	   cifrado vuelve NULL a sys.sql_modules.definition y oculta el procedimiento de
	   las busquedas por dependencia. Para alinearlo con la convencion basta agregar
	   la linea WITH ENCRYPTION debajo de la firma.
   */

	/* =====================================================================
	   APTITUD
	   Chequeo que el worker ejecuta al arrancar y en cada ciclo, antes de
	   tomar nada. Resuelve tres cosas criticas:

	   1. El interruptor de despliegue por fases: USVGS FEVRIPS_MODO. Solo
	      'MICROSERVICIO' habilita el proceso automatico; vacio, nulo o
	      'FRONTEND' deja el sistema como esta hoy. La misma variable gobierna
	      la pantalla, asi que apagarla detiene los dos lados.

	   2. Produccion contra pruebas, con la misma regla que ya aplica SPQ_RIPS
	      en GET_DATOS: si DB_NAME() no coincide con BDATA_PRODUCCION, la base
	      es un entorno de pruebas y corresponde URL_SERV_RIPS_PRUEBA. Si esa
	      URL esta vacia el veredicto es KO. Jamas se cae de vuelta a la URL de
	      produccion: ese es justo el accidente a impedir, restaurar una copia
	      de produccion y radicar facturas reales por duplicado.

	   3. El NIT del prestador instalado, para que el worker lo compare contra
	      el NIT configurado en el microservicio. Si no coinciden el tenant no
	      procesa: radicar con las credenciales de otro prestador es el error
	      mas caro de revertir ante el ministerio.
	   ===================================================================== */
	IF @METODO = 'APTITUD'
	BEGIN
		SELECT @CONTAR_PENDIENTES = CASE
		          WHEN UPPER(COALESCE(JSON_VALUE(@PARAMETROS, '$.CONTAR_PENDIENTES'), '')) IN ('1','TRUE','SI')
		          THEN 1 ELSE 0
		       END

		SELECT @MODO       = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_MODO'), '')))
		     , @DB_ACTUAL  = DB_NAME()
		     , @DB_PROD    = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('BDATA_PRODUCCION'), '')))
		     , @URL_PROD   = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('URL_SERV_RIPS'), '')))
		     , @URL_PRUEBA = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('URL_SERV_RIPS_PRUEBA'), '')))
		     , @IDTERCERO  = LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO'), '')))

		SET @ES_PROD = CASE WHEN @DB_PROD <> '' AND @DB_PROD = @DB_ACTUAL THEN 1 ELSE 0 END
		SET @URL     = CASE WHEN @ES_PROD = 1 THEN @URL_PROD ELSE @URL_PRUEBA END

		IF @IDTERCERO <> ''
			SELECT @NIT = LTRIM(RTRIM(COALESCE(TER.NIT, '')))
			FROM DBO.TER WHERE TER.IDTERCERO = @IDTERCERO

		SET @TIENE_COLA = CASE WHEN OBJECT_ID('DBO.FEVRIPS_COLA','U') IS NULL THEN 0 ELSE 1 END

		IF UPPER(@MODO) <> 'MICROSERVICIO'      SET @MOTIVO = 'MODO_INACTIVO'
		ELSE IF @TIENE_COLA = 0                 SET @MOTIVO = 'SIN_COLA'
		ELSE IF COALESCE(@NIT,'') = ''          SET @MOTIVO = 'SIN_NIT'
		ELSE IF @URL = ''                       SET @MOTIVO = CASE WHEN @ES_PROD = 1 THEN 'SIN_URL_PRODUCCION' ELSE 'SIN_URL_PRUEBA' END

		IF @CONTAR_PENDIENTES = 1 AND @MOTIVO IS NULL
			SELECT @PENDIENTES = COUNT(1)
			FROM DBO.FTR F
			LEFT JOIN DBO.FEVRIPS_COLA C ON C.TIPODOC = 'FV' AND C.CNSDOC = F.CNSFCT
			WHERE EXISTS (SELECT 1 FROM DBO.FDIAN D
			               WHERE D.CNSRESOL = F.CNSRESOL
			                 AND COALESCE(D.FTRELECTRONICA,0) = 1
			                 AND D.PROCEDENCIA IN ('FTR','FPOS'))
			  AND COALESCE(F.FACTE,0)           = 2
			  AND COALESCE(F.SI,0)              = 0
			  AND COALESCE(F.ESTADO,'')         = 'P'
			  AND COALESCE(F.CONTABILIZADA,0)  <> 0
			  AND COALESCE(F.VR_TOTAL,0)        > 0
			  AND F.PROCEDENCIA                <> 'CAJA'
			  AND COALESCE(F.TIPOANULACION,'') <> 'NC'
			  AND YEAR(F.F_FACTURA)             > 2024
			  AND COALESCE(F.CUV,'')            = ''
			  AND (C.ID IS NULL OR C.ESTADO IN (0,4,5) OR C.REPROCESAR = 1)

		SELECT OK               = CASE WHEN @MOTIVO IS NULL THEN 'OK' ELSE 'KO' END
		     , MOTIVO           = @MOTIVO
		     , MODO             = @MODO
		     , DB_ACTUAL        = @DB_ACTUAL
		     , BDATA_PRODUCCION = @DB_PROD
		     , ES_PRODUCCION    = @ES_PROD
		     , URL_EFECTIVA     = @URL
		     , IDTERCERO        = @IDTERCERO
		     , NIT              = @NIT
		     , TIENE_COLA       = @TIENE_COLA
		     , PENDIENTES       = @PENDIENTES
		RETURN
	END

	/* =====================================================================
	   TOMAR_LOTE
	   Descubre facturas radicables y las reclama en una sola operacion.
	   Devuelve los documentos tomados; lista vacia significa que no hay trabajo.

	   Fase 1: solo facturas. Las notas viven en FNOT / FGLO y entran despues,
	   con su dependencia de orden: la nota de ajuste exige que la factura base
	   ya tenga CUV (ver SPQ_FTR_COL, metodo RIPS_JSON).

	   El predicado de candidatas replica el de FEVRIPSMasivoComponent.vue.
	   Filtrar solo por FACTE = 2 y CUV vacio tomaria facturas anuladas, de caja,
	   no contabilizadas o de valor cero, y las radicaria sin revision humana.

	   Sin TRY/CATCH a proposito: un fallo aqui debe llegar al worker como
	   excepcion para que lo registre y reintente, no disfrazado de KO.
	   ===================================================================== */
	IF @METODO = 'TOMAR_LOTE'
	BEGIN
		IF OBJECT_ID('DBO.FEVRIPS_COLA','U') IS NULL
		BEGIN
			RAISERROR('FEVRIPS_COLA no existe en esta base. Ejecute FEVRIPS_COLA.sql.', 16, 1)
			RETURN
		END

		SELECT @WORKER                  = JSON_VALUE(@PARAMETROS, '$.WORKER')
		     , @LOTE                    = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.LOTE') AS INT), 20)
		     , @WATCHDOG_MIN            = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.WATCHDOG_MIN') AS INT), 90)
		     , @MAX_INTENTOS            = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MAX_INTENTOS') AS SMALLINT), 5)
		     , @MIN_HORAS_DESDE_FACTURA = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MIN_HORAS_DESDE_FACTURA') AS INT), 0)
		     , @SOLO_PRIORITARIAS       = CASE
		          WHEN UPPER(COALESCE(JSON_VALUE(@PARAMETROS, '$.SOLO_PRIORITARIAS'), '')) IN ('1','TRUE','SI')
		          THEN 1 ELSE 0
		       END

		IF COALESCE(@WORKER,'') = ''
		BEGIN
			RAISERROR('WORKER es obligatorio en TOMAR_LOTE.', 16, 1)
			RETURN
		END

		SET @LIMITE = DATEADD(MINUTE, -@WATCHDOG_MIN, @AHORA)

		;WITH CAND AS (
			SELECT TOP (@LOTE)
			       CNSDOC    = F.CNSFCT,
			       PRIORIDAD = COALESCE(C.PRIORIDAD, 0),
			       F_ORDEN   = F.F_FACTURA
			FROM DBO.FTR F
			LEFT JOIN DBO.FEVRIPS_COLA C ON C.TIPODOC = 'FV' AND C.CNSDOC = F.CNSFCT
			WHERE EXISTS (
			          /* EXISTS y no JOIN: evita multiplicar filas y que el MERGE
			             intente actualizar el mismo destino dos veces. */
			          SELECT 1 FROM DBO.FDIAN D
			           WHERE D.CNSRESOL = F.CNSRESOL
			             AND COALESCE(D.FTRELECTRONICA,0) = 1
			             AND D.PROCEDENCIA IN ('FTR','FPOS')
			      )
			  AND COALESCE(F.FACTE,0)           = 2
			  AND COALESCE(F.SI,0)              = 0
			  AND COALESCE(F.ESTADO,'')         = 'P'
			  AND COALESCE(F.CONTABILIZADA,0)  <> 0
			  AND COALESCE(F.VR_TOTAL,0)        > 0
			  AND F.PROCEDENCIA                <> 'CAJA'
			  AND COALESCE(F.TIPOANULACION,'') <> 'NC'
			  AND YEAR(F.F_FACTURA)             > 2024
			  AND COALESCE(F.CUV,'')            = ''
			  AND (   @MIN_HORAS_DESDE_FACTURA = 0
			       OR F.F_FACTURA <= DATEADD(HOUR, -@MIN_HORAS_DESDE_FACTURA, @AHORA))
			  AND (   C.ID IS NULL                                   -- nunca procesada
			       OR C.ESTADO = 0                                    -- pendiente
			       OR C.REPROCESAR = 1                                -- corregida por el usuario
			       OR (    C.ESTADO = 4                               -- error tecnico con backoff
			           AND C.INTENTOS < @MAX_INTENTOS
			           AND COALESCE(C.F_PROXINTENTO, @AHORA) <= @AHORA)
			       OR (C.ESTADO IN (1,2,3) AND C.F_TOMADO < @LIMITE)  -- worker caido
			       OR (C.ESTADO = 9 AND COALESCE(C.BLOQUEO_HASTA, @AHORA) < @AHORA) -- manual vencido
			      )
			  AND (@SOLO_PRIORITARIAS = 0 OR COALESCE(C.PRIORIDAD,0) = 1)
			ORDER BY COALESCE(C.PRIORIDAD,0) DESC, F.F_FACTURA ASC
		)
		MERGE DBO.FEVRIPS_COLA WITH (HOLDLOCK) AS T
		USING CAND AS S
		   ON T.TIPODOC = 'FV' AND T.CNSDOC = S.CNSDOC
		WHEN MATCHED THEN
			UPDATE SET ESTADO        = 1,
			           REPROCESAR    = 0,
			           /* El intento se cuenta al tomar, no al fallar: asi una caida
			              del worker tambien suma y nada se reintenta sin fin. */
			           INTENTOS      = T.INTENTOS + 1,
			           F_TOMADO      = @AHORA,
			           F_ULT_CAMBIO  = @AHORA,
			           F_PROXINTENTO = NULL,
			           BLOQUEO_HASTA = NULL,
			           MENSAJE       = NULL,
			           WORKER        = @WORKER
		WHEN NOT MATCHED THEN
			INSERT (TIPODOC, CNSDOC, ESTADO, INTENTOS, F_ALTA, F_TOMADO, F_ULT_CAMBIO, WORKER)
			VALUES ('FV', S.CNSDOC, 1, 1, @AHORA, @AHORA, @AHORA, @WORKER)
		OUTPUT INSERTED.ID        AS ID,
		       INSERTED.TIPODOC   AS TIPODOC,
		       INSERTED.CNSDOC    AS CNSDOC,
		       INSERTED.PRIORIDAD AS PRIORIDAD,
		       INSERTED.INTENTOS  AS INTENTOS;
		RETURN
	END

	/* =====================================================================
	   SET_ESTADO
	   Avance del pipeline: GENERANDO -> ENVIANDO -> resultado.

	   Si se envia WORKER, solo actualiza cuando la fila sigue siendo suya.
	   TOMADA = 0 significa que la perdio (el watchdog la libero por demora y
	   otro ciclo la reclamo): el worker debe abandonar el documento en vez de
	   seguir escribiendo sobre trabajo ajeno.

	   El backoff no se calcula aqui. ESPERA_SEG lo decide el worker, que conoce
	   el numero de intento y la clase de error. Y la regla que evita martillar
	   al ministerio: ESTADO 4 (error tecnico) se reintenta solo; ESTADO 5
	   (error de validacion) nunca, porque reenviar el mismo paquete produce el
	   mismo rechazo; solo sale con REPROCESAR = 1 tras correccion humana.
	   ===================================================================== */
	IF @METODO = 'SET_ESTADO'
	BEGIN
		SELECT @ESTADO        = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ESTADO') AS TINYINT)
		     , @MENSAJE       = JSON_VALUE(@PARAMETROS, '$.MENSAJE')
		     , @TAMANIO_BYTES = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.TAMANIO_BYTES') AS BIGINT)
		     , @ESPERA_SEG    = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ESPERA_SEG') AS INT)
		     , @WORKER        = JSON_VALUE(@PARAMETROS, '$.WORKER')
		     , @LIBERAR       = CASE
		          WHEN UPPER(COALESCE(JSON_VALUE(@PARAMETROS, '$.LIBERAR'), '')) IN ('1','TRUE','SI')
		          THEN 1 ELSE 0
		       END

		UPDATE DBO.FEVRIPS_COLA
		   SET ESTADO        = @ESTADO,
		       MENSAJE       = @MENSAJE,
		       TAMANIO_BYTES = COALESCE(@TAMANIO_BYTES, TAMANIO_BYTES),
		       F_PROXINTENTO = CASE WHEN @ESPERA_SEG IS NULL THEN NULL
		                            ELSE DATEADD(SECOND, @ESPERA_SEG, @AHORA) END,
		       F_ULT_CAMBIO  = @AHORA,
		       F_TOMADO      = CASE WHEN @LIBERAR = 1 THEN NULL ELSE F_TOMADO END,
		       WORKER        = CASE WHEN @LIBERAR = 1 THEN NULL ELSE WORKER END
		 WHERE TIPODOC = @TIPODOC
		   AND CNSDOC  = @CNSDOC
		   AND (@WORKER IS NULL OR WORKER = @WORKER)

		SELECT OK = 'OK', TOMADA = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END
		RETURN
	END
	/* =====================================================================
	   TOMAR_MANUAL
	   Reserva el documento para envio manual mientras el microservicio esta
	   activo. El front lo llama ANTES de generar o enviar y solo continua si
	   recibe OK = 'OK'.

	   Por que se marca y no se desmarca: el poller descubre candidatas por
	   FACTE = 2 y CUV vacio, sin depender de ninguna marca previa. Si al
	   validar a mano se borrara la fila, el worker volveria a descubrir la
	   misma factura en el siguiente barrido y la radicaria por duplicado. Por
	   eso el estado 9 es una marca positiva que el poller respeta.

	   La verificacion va en la misma sentencia que la toma: la pantalla se
	   cargo hace minutos y su estado puede estar obsoleto. La autoridad es el
	   resultado de este MERGE, no lo que muestra la grilla.

	   BLOQUEO_HASTA es obligatorio: si el usuario cierra el navegador a mitad
	   del proceso, sin vencimiento esa factura no volveria a enviarse nunca.
	   ===================================================================== */
	IF @METODO = 'TOMAR_MANUAL'
	BEGIN
		SELECT @MINUTOS      = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MINUTOS') AS INT), 90)
		     , @WATCHDOG_MIN = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.WATCHDOG_MIN') AS INT), 90)

		SET @LIMITE = DATEADD(MINUTE, -@WATCHDOG_MIN, @AHORA)
		SET @DUENIO = 'MANUAL:' + COALESCE(@USUARIO, '')

		BEGIN TRY
			MERGE DBO.FEVRIPS_COLA WITH (HOLDLOCK) AS T
			USING (SELECT @TIPODOC AS TIPODOC, @CNSDOC AS CNSDOC) AS S
			   ON T.TIPODOC = S.TIPODOC AND T.CNSDOC = S.CNSDOC
			/* Estados 1, 2 y 3 quedan fuera a proposito: el worker la tiene en
			   proceso y un envio en vuelo no se puede cancelar, el ministerio ya
			   puede tener el paquete. Solo se readmiten si estan colgados.

			   El 9 tampoco entra libremente: si otro usuario tiene la reserva
			   viva, dejarlo pasar seria permitir dos envios manuales a la vez,
			   que es precisamente lo que este metodo existe para impedir. Se
			   readmite solo si el bloqueo vencio o si es del mismo usuario, caso
			   habitual cuando recarga la pantalla a mitad del proceso. */
			WHEN MATCHED AND (   T.ESTADO IN (0,4,5)
			                  OR (T.ESTADO = 9 AND (   T.WORKER = @DUENIO
			                                        OR T.BLOQUEO_HASTA IS NULL
			                                        OR T.BLOQUEO_HASTA <= @AHORA))
			                  OR (T.ESTADO IN (1,2,3) AND T.F_TOMADO < @LIMITE))
				THEN UPDATE SET ESTADO        = 9,
				                REPROCESAR    = 0,
				                BLOQUEO_HASTA = DATEADD(MINUTE, @MINUTOS, @AHORA),
				                F_ULT_CAMBIO  = @AHORA,
				                MENSAJE       = NULL,
				                WORKER        = @DUENIO
			WHEN NOT MATCHED THEN
				/* Nunca paso por la cola: hay que crear la fila igual, o el worker
				   la descubriria mientras el usuario la esta trabajando. */
				INSERT (TIPODOC, CNSDOC, CLASE, ESTADO, F_ALTA, BLOQUEO_HASTA, F_ULT_CAMBIO, WORKER)
				VALUES (S.TIPODOC, S.CNSDOC, @CLASE, 9, @AHORA,
				        DATEADD(MINUTE, @MINUTOS, @AHORA), @AHORA, @DUENIO);

			IF @@ROWCOUNT > 0
			BEGIN
				SELECT OK = 'OK'
				RETURN
			END
		END TRY
		BEGIN CATCH
			INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
			SELECT OK = 'KO', MOTIVO = 'ERROR'
			SELECT ERROR FROM @TBLERRORES
			RETURN
		END CATCH

		/* La antiguedad importa en el aviso: "hace 4 minutos" es un envio normal,
		   "hace 3 horas" es un worker caido que el watchdog aun no libera. */
		SELECT OK       = 'KO'
		     , MOTIVO   = 'EN_PROCESO'
		     , ESTADO   = ESTADO
		     , F_TOMADO = F_TOMADO
		     , MINUTOS  = DATEDIFF(MINUTE, COALESCE(F_TOMADO, F_ULT_CAMBIO, F_ALTA), @AHORA)
		     , WORKER   = WORKER
		FROM DBO.FEVRIPS_COLA
		WHERE TIPODOC = @TIPODOC AND CNSDOC = @CNSDOC
		RETURN
	END

	/* =====================================================================
	   LIBERAR_MANUAL
	   Suelta la reserva al terminar el flujo manual, con exito o con error.

	   ESTADO_FINAL = 0 deja el documento pendiente para el worker.
	   ESTADO_FINAL = 5 lo marca con error de validacion (el usuario vio el
	   rechazo de SISPRO), de modo que no se reintente solo hasta que alguien
	   lo corrija.

	   Si el flujo manual termino con CUV, el documento sale igual del universo
	   de candidatos porque FTR.CUV deja de estar vacio.

	   Solo el usuario que bloqueo puede soltar, para que nadie destrabe por
	   accidente el trabajo de otro.
	   ===================================================================== */
	IF @METODO = 'LIBERAR_MANUAL'
	BEGIN
		SELECT @ESTADO_FINAL = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ESTADO_FINAL') AS TINYINT), 0)
		SET @DUENIO = 'MANUAL:' + COALESCE(@USUARIO, '')

		DECLARE @FILAS INT = 0

		BEGIN TRY
			UPDATE DBO.FEVRIPS_COLA
			   SET ESTADO        = @ESTADO_FINAL,
			       BLOQUEO_HASTA = NULL,
			       F_TOMADO      = NULL,
			       F_ULT_CAMBIO  = @AHORA,
			       WORKER        = NULL
			 WHERE TIPODOC = @TIPODOC
			   AND CNSDOC  = @CNSDOC
			   AND WORKER  = @DUENIO

			SET @FILAS = @@ROWCOUNT
		END TRY
		BEGIN CATCH
			INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
		END CATCH

		IF (SELECT COUNT(1) FROM @TBLERRORES) > 0
		BEGIN
			SELECT OK = 'KO', MOTIVO = 'ERROR'
			SELECT ERROR FROM @TBLERRORES
			RETURN
		END

		/* LIBERADA = 0: el bloqueo ya no era de este usuario, porque vencio y otro
		   lo tomo. No es un error, pero el front no debe dar por hecho que la
		   reserva seguia viva mientras el usuario trabajaba. */
		SELECT OK = 'OK', LIBERADA = CASE WHEN @FILAS > 0 THEN 1 ELSE 0 END
		RETURN
	END

	/* =====================================================================
	   ENCOLAR
	   Reprocesar (tras corregir) y "enviar ya" (prioridad) desde la grilla.

	   Es la unica forma de salir del estado 5, que nunca se reintenta solo.
	   PRIORIDAD = 1 hace que el worker la tome en el barrido corto de
	   prioritarias, que ignora la ventana horaria configurada.

	   Los intentos se reinician porque el usuario declara que corrigio algo: si
	   no, un documento que ya agoto MAX_INTENTOS nunca volveria a tomarse.
	   ===================================================================== */
	IF @METODO = 'ENCOLAR'
	BEGIN
		SELECT @PRIORIDAD    = CASE
		          WHEN UPPER(COALESCE(JSON_VALUE(@PARAMETROS, '$.PRIORIDAD'), '')) IN ('1','TRUE','SI')
		          THEN 1 ELSE 0
		       END
		     , @WATCHDOG_MIN = COALESCE(TRY_CAST(JSON_VALUE(@PARAMETROS, '$.WATCHDOG_MIN') AS INT), 90)

		SET @LIMITE = DATEADD(MINUTE, -@WATCHDOG_MIN, @AHORA)

		BEGIN TRY
			MERGE DBO.FEVRIPS_COLA WITH (HOLDLOCK) AS T
			USING (SELECT @TIPODOC AS TIPODOC, @CNSDOC AS CNSDOC, @CLASE AS CLASE) AS S
			   ON T.TIPODOC = S.TIPODOC AND T.CNSDOC = S.CNSDOC
			/* En proceso (1,2,3) no se toca: ya va en camino. Unica excepcion,
			   que este colgada por caida del worker.

			   El 9 con bloqueo vivo tampoco: devolverlo a pendiente mientras
			   alguien lo esta enviando a mano habilitaria al worker a radicar el
			   mismo documento en paralelo. */
			WHEN MATCHED AND (   T.ESTADO IN (0,4,5)
			                  OR (T.ESTADO = 9 AND (   T.BLOQUEO_HASTA IS NULL
			                                        OR T.BLOQUEO_HASTA <= @AHORA))
			                  OR (T.ESTADO IN (1,2,3) AND T.F_TOMADO < @LIMITE))
				THEN UPDATE SET ESTADO        = 0,
				                REPROCESAR    = 1,
				                PRIORIDAD     = CASE WHEN @PRIORIDAD = 1 THEN 1 ELSE T.PRIORIDAD END,
				                INTENTOS      = 0,
				                F_PROXINTENTO = NULL,
				                BLOQUEO_HASTA = NULL,
				                F_TOMADO      = NULL,
				                F_ULT_CAMBIO  = @AHORA,
				                MENSAJE       = NULL,
				                WORKER        = NULL
			WHEN NOT MATCHED THEN
				INSERT (TIPODOC, CNSDOC, CLASE, ESTADO, PRIORIDAD, REPROCESAR, F_ALTA, F_ULT_CAMBIO)
				VALUES (S.TIPODOC, S.CNSDOC, S.CLASE, 0, @PRIORIDAD, 1, @AHORA, @AHORA);

			IF @@ROWCOUNT > 0
			BEGIN
				SELECT OK = 'OK'
				RETURN
			END
		END TRY
		BEGIN CATCH
			INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
			SELECT OK = 'KO', MOTIVO = 'ERROR'
			SELECT ERROR FROM @TBLERRORES
			RETURN
		END CATCH

		SELECT OK       = 'KO'
		     , MOTIVO   = 'EN_PROCESO'
		     , ESTADO   = ESTADO
		     , F_TOMADO = F_TOMADO
		     , MINUTOS  = DATEDIFF(MINUTE, COALESCE(F_TOMADO, F_ULT_CAMBIO, F_ALTA), @AHORA)
		     , WORKER   = WORKER
		FROM DBO.FEVRIPS_COLA
		WHERE TIPODOC = @TIPODOC AND CNSDOC = @CNSDOC
		RETURN
	END

	/* =====================================================================
	   ESTADOS
	   Estado en vivo de las filas visibles de la grilla. Consulta liviana: no
	   toca FTRJSON ni los NVARCHAR(MAX), asi que se puede refrescar cada 20 o
	   30 segundos sin costo apreciable.

	   Lo que se pinta sirve para informar y deshabilitar botones de forma
	   preventiva, pero la autoridad sobre si se puede enviar es siempre el
	   resultado de TOMAR_MANUAL en el instante del clic.

	   PARAMETROS: { "TIPODOC": "FV", "DOCUMENTOS": ["CNS1","CNS2", ...] }
	   ===================================================================== */
	IF @METODO = 'ESTADOS'
	BEGIN
		SELECT @DOCUMENTOS = JSON_QUERY(@PARAMETROS, '$.DOCUMENTOS')

		SELECT OK = 'OK'

		SELECT C.TIPODOC
		     , C.CNSDOC
		     , C.ESTADO
		     , ESTADO_DESC = CASE C.ESTADO
		                        WHEN 0 THEN 'Pendiente'
		                        WHEN 1 THEN 'Encolado'
		                        WHEN 2 THEN 'Generando'
		                        WHEN 3 THEN 'Enviando'
		                        WHEN 4 THEN 'Error tecnico'
		                        WHEN 5 THEN 'Error validacion'
		                        WHEN 9 THEN 'En proceso manual'
		                        ELSE 'Desconocido'
		                     END
		     , C.PRIORIDAD
		     , C.REPROCESAR
		     , C.INTENTOS
		     , C.F_TOMADO
		     , MINUTOS = CASE WHEN C.F_TOMADO IS NULL THEN NULL
		                      ELSE DATEDIFF(MINUTE, C.F_TOMADO, @AHORA) END
		     , C.TAMANIO_BYTES
		     , C.WORKER
		     , C.MENSAJE
		FROM DBO.FEVRIPS_COLA C
		WHERE C.TIPODOC = @TIPODOC
		  AND C.CNSDOC IN (SELECT VALUE FROM OPENJSON(@DOCUMENTOS))
		RETURN
	END

	SELECT OK = 'KO', ERROR = 'Metodo no reconocido: ' + COALESCE(@METODO, '')
END

