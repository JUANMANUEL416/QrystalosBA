CREATE OR ALTER PROCEDURE DBO.SPQ_ICTZG 
    @JSON NVARCHAR(MAX) 
WITH ENCRYPTION 
AS
BEGIN
    -- Declaraci�n de variables (incluye IDBODEGA)
    DECLARE
        @MODELO VARCHAR(100),
        @METODO VARCHAR(100),
        @GRUPO VARCHAR(8),
        @SYS_COMPUTERNAME VARCHAR(254),
        @IDSEDE VARCHAR(6),
        @IDBODEGA VARCHAR(20),
        @SEDE VARCHAR(5),
        @COMPANIA VARCHAR(2),
        @PARAMETROS NVARCHAR(MAX),
        @REGISTROS NVARCHAR(MAX),
        @PROCESO VARCHAR(20),
        @IDCOTIZACION INT,
        @IDTERCERO VARCHAR(20),
        @IDPLAN VARCHAR(6),
        @FECHA DATE,
        @IDSERVICIO VARCHAR(20),
        @FECHAVENCE DATE,
        @ESTADO VARCHAR(20),
        @USUARIO VARCHAR(20),
        @OBSERVACION VARCHAR(1000),
        @WHERES NVARCHAR(MAX),
        @QUERY NVARCHAR(MAX),
		@TIPOCNS_REL VARCHAR(50),
		@CNSREL VARCHAR(20)

    -- Extraer MODELO, METODO y PARAMETROS del JSON principal
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    )

    SELECT 
        @MODELO = MODELO,
        @METODO = METODO,
        @PARAMETROS = PARAMETROS
    FROM #JSON

    DROP TABLE #JSON;

    DECLARE @TBLERRORES TABLE(ERROR VARCHAR(500))

    PRINT 'USUARIO:' + @USUARIO
    SELECT @GRUPO = DBO.FNK_DESCIFRAR(GRUPO) FROM USUSU WHERE USUARIO = @USUARIO
    SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME FROM USUSU WHERE USUARIO = @USUARIO
    SELECT @SEDE = IDSEDE FROM UBEQ WHERE SYS_ComputerName = @SYS_COMPUTERNAME
    SELECT @IDSEDE = IDSEDE, 
           @COMPANIA = COMPANIA, 
           @IDBODEGA = COALESCE(IDBODEGA, IDBODEGA2, IDBODEGANOCHE, IDBODEGACONSUMO) 
    FROM UBEQ 
    WHERE SYS_ComputerName = @SYS_COMPUTERNAME
    
    IF COALESCE(@SEDE, '') = '' SELECT @SEDE = '01'
    PRINT 'SEDE=' + @SEDE
    PRINT '@SYS_COMPUTERNAME=' + @SYS_COMPUTERNAME

    -- M�TODO: GET_TERCEROS_PLANES
    IF @METODO = 'GET_TERCEROS_PLANES'
    BEGIN
        DECLARE @TIPO_LISTA VARCHAR(50)

        SELECT 
            @TIPO_LISTA = TIPO_LISTA,
            @IDTERCERO = IDTERCERO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            TIPO_LISTA VARCHAR(50) '$.TIPO_LISTA',
            IDTERCERO VARCHAR(20) '$.IDTERCERO'
        )

        IF @TIPO_LISTA = 'TERCEROS'
        BEGIN
            SELECT 
                value = IDTERCERO,
                label = RAZONSOCIAL
            FROM VWK_TEXCA 
            WHERE (IDCATEGORIA = 'PRO' OR IDCATEGORIA = 'CLI') 
                AND ESTADO = 'Activo'
            ORDER BY RAZONSOCIAL
        END
        ELSE IF @TIPO_LISTA = 'PLANES'
        BEGIN
            IF @IDTERCERO IS NULL
            BEGIN
                SELECT 'KO' AS OK, ERROR = 'Debe especificar un tercero para listar sus planes'
            END
            ELSE
            BEGIN
                SELECT 
                    value = P.IDPLAN,
                    label = P.DESCPLAN
                FROM PLN P
                INNER JOIN PPT TP ON TP.IDPLAN = P.IDPLAN
                WHERE TP.IDTERCERO = @IDTERCERO
                ORDER BY P.DESCPLAN
            END
        END
        ELSE
        BEGIN
            SELECT 'KO' AS OK, ERROR = 'Tipo de lista no v�lido: ' + ISNULL(@TIPO_LISTA, '(NULL)')
        END
        RETURN
    END

    -- M�TODO: VWK_TEXCA (Filtros din�micos para terceros)
    IF @METODO = 'VWK_TEXCA'
    BEGIN
        SELECT @WHERES = WHERES
        FROM OPENJSON(@PARAMETROS)
        WITH ( WHERES NVARCHAR(MAX) '$.WHERES' );

        IF COALESCE(@WHERES, '') <> ''
        BEGIN
            PRINT '--- FILTRO PERSONALIZADO ---';

            IF CHARINDEX('.', @WHERES) = 0
            BEGIN
                SET @WHERES = REPLACE(@WHERES, 'IDTERCERO', 'VWK_TEXCA.IDTERCERO');
                SET @WHERES = REPLACE(@WHERES, 'RAZONSOCIAL', 'VWK_TEXCA.RAZONSOCIAL');
                SET @WHERES = REPLACE(@WHERES, 'IDCATEGORIA', 'VWK_TEXCA.IDCATEGORIA');
            END
            ELSE IF CHARINDEX('TER.', @WHERES) = 0 AND CHARINDEX('VWK_TEXCA.', @WHERES) = 0
            BEGIN
                SET @WHERES = 'VWK_TEXCA.' + @WHERES;
            END

            SELECT @QUERY = 
                'SELECT 
                    VWK_TEXCA.IDTERCERO AS value,
                    VWK_TEXCA.RAZONSOCIAL AS label,
                    VWK_TEXCA.IDTERCERO,
                    VWK_TEXCA.RAZONSOCIAL,
                    TER.ENVIODICAJA,
                    VWK_TEXCA.IDCATEGORIA,
                    TER.IDALTERNA2
                 FROM VWK_TEXCA
                 INNER JOIN TER ON VWK_TEXCA.IDTERCERO = TER.IDTERCERO
                 WHERE VWK_TEXCA.ESTADO = ''Activo''
                   AND COALESCE(VWK_TEXCA.RAZONSOCIAL, '''') <> ''''
                   AND VWK_TEXCA.IDCATEGORIA = ''CON''
                   AND ' + @WHERES;

            PRINT @QUERY;
            EXEC (@QUERY);
        END
        ELSE
        BEGIN
            SELECT 
                VWK_TEXCA.IDTERCERO AS value,
                VWK_TEXCA.RAZONSOCIAL AS label,
                VWK_TEXCA.IDTERCERO,
                VWK_TEXCA.RAZONSOCIAL,
                TER.ENVIODICAJA,
                VWK_TEXCA.IDCATEGORIA,
                TER.IDALTERNA2
            FROM VWK_TEXCA
            INNER JOIN TER ON VWK_TEXCA.IDTERCERO = TER.IDTERCERO
            WHERE VWK_TEXCA.ESTADO = 'Activo'
              AND COALESCE(VWK_TEXCA.RAZONSOCIAL, '') <> ''
              AND VWK_TEXCA.IDCATEGORIA = 'CON';
        END

        RETURN;
    END

    -- M�TODO: GET_PRODUCTOS
    IF @METODO = 'GET_PRODUCTOS'
    BEGIN
        SELECT 
            IDARTICULO AS value,
            DESCRIPCION AS label,
            PCOSTO,
            IVA = MIVA
        FROM IART
        WHERE ESTADO = 'Activo'
        ORDER BY DESCRIPCION;

        RETURN;
    END

    -- M�TODO: GET_COTIZA_DETALLE
    IF @METODO = 'GET_COTIZA_DETALLE'
    BEGIN
        DECLARE @ID INT
        SELECT @ID = IDCOTIZACION 
        FROM OPENJSON(@PARAMETROS) 
        WITH (IDCOTIZACION INT '$.IDCOTIZACION');

        SELECT 
            C.ID, 
            C.IDCOTIZACION, 
            A.DESCRIPCION, 
            C.IDARTICULO, 
            C.CANTIDAD, 
            C.VALORUNITARIO AS PRECIO, 
            C.IVA, 
            C.VALORTOTAL
        FROM ICTZGD C
        INNER JOIN IART A ON A.IDARTICULO = C.IDARTICULO
        WHERE C.IDCOTIZACION = @ID
        ORDER BY ID;

        RETURN;
    END

    -- M�TODO: GET_COTIZACION (?? MODIFICADO - Incluye IDBODEGA)
    IF @METODO = 'GET_COTIZACION'
    BEGIN
        SELECT 
            C.IDCOTIZACION,
            C.IDTERCERO,
            T.RAZONSOCIAL AS NOMBRE_TERCERO,
            C.IDPLAN,
            P.DESCPLAN AS NOMBRE_PLAN,
            C.IDBODEGA,                                       -- ?? Campo agregado
            IBOD.DESCRIPCION AS NOMBRE_BODEGA,                -- ?? Campo agregado
            C.FECHA,
            C.FECHAVENCE,
            C.ESTADO,
            C.USUARIO,                                    
            ISNULL(U.NOMBRE, C.USUARIO) AS NOMBRE_USUARIO, 
            C.OBSERVACION,
			C.TIPOCNS_REL,
			C.CNSREL,
			AFI.NOMBREAFI,
			AFI.DOCIDAFILIADO,
			SER.DESCSERVICIO
        FROM ICTZG C
        INNER JOIN TER T ON T.IDTERCERO = C.IDTERCERO
        INNER JOIN PLN P ON P.IDPLAN = C.IDPLAN
        LEFT JOIN IBOD ON C.IDBODEGA = IBOD.IDBODEGA          -- ?? JOIN agregado
        LEFT JOIN USUSU U ON U.USUARIO = C.USUARIO
		LEFT JOIN IARTO ON IARTO.ID = C.CNSREL
		LEFT JOIN AFI ON AFI.IDAFILIADO = IARTO.IDAFILIADO
		LEFT JOIN CXPS ON CXPS.NOPROGRAMACION = IARTO.NOPROGRAMACION
		LEFT JOIN SER ON CXPS.IDSERVICIO = SER.IDSERVICIO

		
        ORDER BY C.IDCOTIZACION DESC;
        
        RETURN;
    END

    -- M�TODO: GET_COTIZACIONES_MASIVO (?? MODIFICADO - Incluye IDBODEGA)
    IF @METODO = 'GET_COTIZACIONES_MASIVO'
    BEGIN
        SELECT DISTINCT
            Z.IDCOTIZACION,
            Z.FECHA,
            Z.FECHAVENCE,
            Z.ESTADO,
            Z.USUARIO,
            Z.OBSERVACION,
            T.RAZONSOCIAL AS TERCERO,
            P.DESCPLAN AS PLANNOMBRE,
            Z.IDBODEGA,                                       -- ?? Campo agregado
            IBOD.DESCRIPCION AS BODEGA,                       -- ?? Campo agregado
            Z.FECHA AS FECHA_COTIZACION,
            Totales.SUBTOTAL,
            Totales.IVA_TOTAL,
            Totales.TOTAL,
            Totales.TOTAL_CANT,
            Totales.ITEMS
        FROM ICTZG Z
        INNER JOIN VWK_TEXCA T ON T.IDTERCERO = Z.IDTERCERO
        INNER JOIN PLN P ON P.IDPLAN = Z.IDPLAN
        LEFT JOIN IBOD ON Z.IDBODEGA = IBOD.IDBODEGA          -- ?? JOIN agregado
        LEFT JOIN (
            SELECT 
                D.IDCOTIZACION,
                SUM(D.VALORUNITARIO * D.CANTIDAD) AS SUBTOTAL,
                SUM(D.VALORUNITARIO * D.CANTIDAD * (D.IVA / 100.0)) AS IVA_TOTAL,
                SUM(D.VALORUNITARIO * D.CANTIDAD + (D.VALORUNITARIO * D.CANTIDAD * (D.IVA / 100.0))) AS TOTAL,
                SUM(D.CANTIDAD) AS TOTAL_CANT,
                COUNT(DISTINCT D.IDARTICULO) AS ITEMS,
                MAX(D.IVA) AS VALOR_IVA_PORCENTAJE,
                MAX(D.VALORUNITARIO) AS PRECIO_PRODUCTO
            FROM ICTZGD D
            GROUP BY D.IDCOTIZACION
        ) Totales ON Totales.IDCOTIZACION = Z.IDCOTIZACION
        ORDER BY Z.FECHA DESC;

        RETURN;
    END

    -- M�TODO: COTIZA_CRUD (?? MODIFICADO - Incluye IDBODEGA)
    IF @METODO = 'COTIZA_CRUD'
    BEGIN
        -- Extraer los datos del JSON
        SELECT @REGISTROS = REGISTRO
        FROM OPENJSON(@PARAMETROS)
        WITH (REGISTRO NVARCHAR(MAX) AS JSON)

        -- Extraer encabezado y PROCESO (?? Incluye IDBODEGA)
        SELECT 
            @IDCOTIZACION = IDCOTIZACION,
            @IDTERCERO = IDTERCERO,
            @IDPLAN = IDPLAN,
            @IDBODEGA = IDBODEGA,                             -- ?? Variable agregada
            @FECHAVENCE = FECHAVENCE,
            @ESTADO = ESTADO,
            @USUARIO = USUARIO,
            @OBSERVACION = OBSERVACION,
			@TIPOCNS_REL = TIPOCNS_REL,
			@CNSREL = CNSREL,
            @PROCESO = PROCESO
        FROM OPENJSON(@REGISTROS)
        WITH (
            IDCOTIZACION INT '$.IDCOTIZACION',
            IDTERCERO VARCHAR(20) '$.IDTERCERO',
            IDPLAN VARCHAR(6) '$.IDPLAN',
            IDBODEGA VARCHAR(20) '$.IDBODEGA',                -- ?? Lectura agregada
            FECHAVENCE DATE '$.FECHAVENCE',
            ESTADO VARCHAR(20) '$.ESTADO',
            USUARIO VARCHAR(20) '$.USUARIO',
            OBSERVACION VARCHAR(1000) '$.OBSERVACION',
            TIPOCNS_REL VARCHAR(50) '$.TIPOCNS_REL',
            CNSREL VARCHAR(20) '$.CNSREL',
            PROCESO VARCHAR(20) '$.PROCESO'
        )

        BEGIN TRY
            BEGIN TRAN

            -- INSERTAR NUEVA COTIZACI�N (?? Incluye IDBODEGA)
            IF UPPER(@PROCESO) = 'INSERTAR'
            BEGIN
                INSERT INTO ICTZG (
                    IDTERCERO, 
                    IDPLAN, 
                    IDBODEGA,                                     -- ?? Campo agregado
                    FECHAVENCE, 
                    ESTADO, 
                    USUARIO, 
                    OBSERVACION,
					TIPOCNS_REL,
					CNSREL
                )
                VALUES (
                    @IDTERCERO, 
                    @IDPLAN, 
                    @IDBODEGA,                                    -- ?? Valor agregado
                    @FECHAVENCE, 
                    @ESTADO, 
                    @USUARIO, 
                    @OBSERVACION,
					@TIPOCNS_REL,
					@CNSREL
                );

                SET @IDCOTIZACION = SCOPE_IDENTITY();

                -- Insertar detalle si existe
                IF EXISTS (SELECT 1 FROM OPENJSON(@REGISTROS, '$.DETALLE'))
                BEGIN
                    INSERT INTO ICTZGD (
                        IDCOTIZACION, 
                        IDARTICULO, 
                        CANTIDAD, 
                        VALORUNITARIO, 
                        IVA, 
                        VALORTOTAL
                    )
                    SELECT
                        @IDCOTIZACION,
                        IDARTICULO,
                        CANTIDAD,
                        VALORUNITARIO,
                        IVA,
                        VALORTOTAL
                    FROM OPENJSON(@REGISTROS, '$.DETALLE')
                    WITH (
                        IDARTICULO VARCHAR(20) '$.IDARTICULO',
                        CANTIDAD INT '$.CANTIDAD',
                        VALORUNITARIO MONEY '$.VALORUNITARIO',
                        IVA MONEY '$.IVA',
                        VALORTOTAL MONEY '$.VALORTOTAL'
                    );
                END

                COMMIT TRAN;
                SELECT 'OK' AS OK, @IDCOTIZACION AS IDCOTIZACION;
                RETURN;
            END

            -- EDITAR COTIZACI�N (?? Incluye IDBODEGA)
            IF UPPER(@PROCESO) = 'EDITAR'
            BEGIN
                UPDATE ICTZG
                SET 
                    IDTERCERO = @IDTERCERO,
                    IDPLAN = @IDPLAN,
                    IDBODEGA = @IDBODEGA,                         -- ?? Campo agregado
                    FECHAVENCE = @FECHAVENCE,
                    ESTADO = @ESTADO,
                    USUARIO = @USUARIO,
                    OBSERVACION = @OBSERVACION,
					TIPOCNS_REL = @TIPOCNS_REL,
					CNSREL = @CNSREL
                WHERE IDCOTIZACION = @IDCOTIZACION;

                IF @@ROWCOUNT = 0
                BEGIN
                    ROLLBACK TRAN;
                    SELECT 'KO' AS OK;
                    SELECT ERROR = 'No se encontr� la cotizaci�n para actualizar';
                    RETURN;
                END

                -- Borrar detalles anteriores
                DELETE FROM ICTZGD WHERE IDCOTIZACION = @IDCOTIZACION;

                -- Insertar nuevo detalle (si el JSON trae detalle)
                IF EXISTS (SELECT 1 FROM OPENJSON(@REGISTROS, '$.DETALLE'))
                BEGIN
                    INSERT INTO ICTZGD (
                        IDCOTIZACION, 
                        IDARTICULO, 
                        CANTIDAD, 
                        VALORUNITARIO, 
                        IVA, 
                        VALORTOTAL
                    )
                    SELECT
                        @IDCOTIZACION,
                        IDARTICULO,
                        CANTIDAD,
                        VALORUNITARIO,
                        IVA,
                        VALORTOTAL
                    FROM OPENJSON(@REGISTROS, '$.DETALLE')
                    WITH (
                        IDARTICULO VARCHAR(20) '$.IDARTICULO',
                        CANTIDAD INT '$.CANTIDAD',
                        VALORUNITARIO MONEY '$.VALORUNITARIO',
                        IVA MONEY '$.IVA',
                        VALORTOTAL MONEY '$.VALORTOTAL'
                    );
                END

                COMMIT TRAN;
                SELECT 'OK' AS OK, @IDCOTIZACION AS IDCOTIZACION;
                RETURN;
            END

            -- ELIMINAR COTIZACI�N Y SUS DETALLES
            IF UPPER(@PROCESO) = 'ELIMINAR'
            BEGIN
                DELETE FROM ICTZGD WHERE IDCOTIZACION = @IDCOTIZACION;
                DELETE FROM ICTZG WHERE IDCOTIZACION = @IDCOTIZACION;

                COMMIT TRAN;
                SELECT 'OK' AS OK;
                RETURN;
            END

            -- Si llegamos aqu�, commit por seguridad
            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRAN;

            INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE();
        END CATCH

        -- Manejo de errores
        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            SELECT 'KO' AS OK;
            SELECT ERROR FROM @TBLERRORES;
            RETURN;
        END

        SELECT 'OK' AS OK;
        RETURN;
    END

    -- M�TODO: UPD_COTIZA_PRINCIPAL (?? MODIFICADO - Incluye IDBODEGA)
    IF @METODO = 'UPD_COTIZA_PRINCIPAL'
    BEGIN
        DECLARE @IDBODEGA_UPD VARCHAR(20)                         -- ?? Variable agregada

        -- Extraer par�metros (?? Incluye IDBODEGA)
        SELECT 
            @IDCOTIZACION = IDCOTIZACION,
            @IDTERCERO = IDTERCERO,
            @IDPLAN = IDPLAN,
            @IDBODEGA_UPD = IDBODEGA,                             -- ?? Lectura agregada
            @FECHAVENCE = FECHAVENCE,
            @ESTADO = ESTADO,
            @USUARIO = USUARIO,
            @OBSERVACION = OBSERVACION
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDCOTIZACION INT '$.IDCOTIZACION',
            IDTERCERO VARCHAR(20) '$.IDTERCERO',
            IDPLAN VARCHAR(6) '$.IDPLAN',
            IDBODEGA VARCHAR(20) '$.IDBODEGA',                    -- ?? Lectura agregada
            FECHAVENCE DATE '$.FECHAVENCE',
            ESTADO VARCHAR(20) '$.ESTADO',
            USUARIO VARCHAR(20) '$.USUARIO',
            OBSERVACION VARCHAR(1000) '$.OBSERVACION'
        )

        BEGIN TRY
            BEGIN TRAN

            -- Actualizar solo el encabezado (?? Incluye IDBODEGA)
            UPDATE ICTZG
            SET 
                IDTERCERO = @IDTERCERO,
                IDPLAN = @IDPLAN,
                IDBODEGA = @IDBODEGA_UPD,                         -- ?? Campo agregado
                FECHAVENCE = @FECHAVENCE,
                ESTADO = @ESTADO,
                USUARIO = @USUARIO,
                OBSERVACION = @OBSERVACION
            WHERE IDCOTIZACION = @IDCOTIZACION;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRAN;
                SELECT 'KO' AS OK, ERROR = 'No se encontr� la cotizaci�n para actualizar';
                RETURN;
            END

            COMMIT TRAN;
            SELECT 'OK' AS OK, IDCOTIZACION = @IDCOTIZACION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRAN;

            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- M�TODO: UPD_COTIZA_DETALLE
    IF @METODO = 'UPD_COTIZA_DETALLE'
    BEGIN
        DECLARE @DETALLE NVARCHAR(MAX)

        SELECT 
            @IDCOTIZACION = IDCOTIZACION,
            @DETALLE = DETALLE
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDCOTIZACION INT '$.IDCOTIZACION',
            DETALLE NVARCHAR(MAX) AS JSON
        )

        BEGIN TRY
            BEGIN TRAN

            -- Eliminar detalles anteriores
            DELETE FROM ICTZGD WHERE IDCOTIZACION = @IDCOTIZACION;

            -- Insertar nuevo detalle
            INSERT INTO ICTZGD (
                IDCOTIZACION, 
                IDARTICULO, 
                CANTIDAD, 
                VALORUNITARIO, 
                IVA, 
                VALORTOTAL
            )
            SELECT
                @IDCOTIZACION,
                IDARTICULO,
                CANTIDAD,
                PRECIO AS VALORUNITARIO,
                IVA,
                TOTAL AS VALORTOTAL
            FROM OPENJSON(@DETALLE)
            WITH (
                IDARTICULO VARCHAR(20) '$.IDARTICULO',
                CANTIDAD INT '$.CANTIDAD',
                PRECIO MONEY '$.PRECIO',
                IVA DECIMAL(5,2) '$.IVA',
                TOTAL MONEY '$.TOTAL'
            );

            COMMIT TRAN;
            SELECT 'OK' AS OK, IDCOTIZACION = @IDCOTIZACION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRAN;

            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- M�TODO: ANULAR_COTIZACION
    IF @METODO = 'ANULAR_COTIZACION'
    BEGIN
        SELECT 
            @IDCOTIZACION = IDCOTIZACION,
            @USUARIO = USUARIO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDCOTIZACION INT '$.IDCOTIZACION',
            USUARIO VARCHAR(20) '$.USUARIO'
        )

        BEGIN TRY
            BEGIN TRAN

            -- Verificar que la cotizaci�n existe y est� en estado Pendiente
            IF NOT EXISTS (SELECT 1 FROM ICTZG WHERE IDCOTIZACION = @IDCOTIZACION AND ESTADO = 'Pendiente')
            BEGIN
                ROLLBACK TRAN;
                SELECT 'KO' AS OK, ERROR = 'La cotizaci�n no existe o no est� en estado Pendiente';
                RETURN;
            END

            -- Actualizar estado a Anulada
            UPDATE ICTZG
            SET 
                ESTADO = 'Anulada',
                USUARIO = @USUARIO
            WHERE IDCOTIZACION = @IDCOTIZACION;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRAN;
                SELECT 'KO' AS OK, ERROR = 'No se pudo anular la cotizaci�n';
                RETURN;
            END

            COMMIT TRAN;
            SELECT 'OK' AS OK, MENSAJE = 'Cotizaci�n anulada correctamente', IDCOTIZACION = @IDCOTIZACION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRAN;

            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- M�TODO: CERRAR_COTIZACION
    IF @METODO = 'CERRAR_COTIZACION'
    BEGIN
        SELECT 
            @IDCOTIZACION = IDCOTIZACION,
            @USUARIO = USUARIO
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDCOTIZACION INT '$.IDCOTIZACION',
            USUARIO VARCHAR(20) '$.USUARIO'
        )

        BEGIN TRY
            BEGIN TRAN

            -- Verificar que la cotizaci�n existe y est� en estado Pendiente
            IF NOT EXISTS (SELECT 1 FROM ICTZG WHERE IDCOTIZACION = @IDCOTIZACION AND ESTADO = 'Pendiente')
            BEGIN
                ROLLBACK TRAN;
                SELECT 'KO' AS OK, ERROR = 'La cotizaci�n no existe o no est� en estado Pendiente';
                RETURN;
            END

            -- Actualizar estado a Cerrada
            UPDATE ICTZG
            SET 
                ESTADO = 'Cerrada',
                USUARIO = @USUARIO
            WHERE IDCOTIZACION = @IDCOTIZACION;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK TRAN;
                SELECT 'KO' AS OK, ERROR = 'No se pudo cerrar la cotizaci�n';
                RETURN;
            END

            COMMIT TRAN;
            SELECT 'OK' AS OK, MENSAJE = 'Cotizaci�n cerrada correctamente', IDCOTIZACION = @IDCOTIZACION;
            RETURN;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRAN;

            SELECT 'KO' AS OK, ERROR = ERROR_MESSAGE();
            RETURN;
        END CATCH
    END

    -- M�TODO: GET_IMPUESTO_ARTICULO
    IF @METODO = 'GET_IMPUESTO_ARTICULO'
	BEGIN
		SELECT @IDSERVICIO = IDSERVICIO
		FROM OPENJSON(@PARAMETROS)
		WITH(IDSERVICIO VARCHAR(20) '$.IDSERVICIO')

		SELECT OK = 'OK'

		SELECT 
			IART.IDARTICULO,
			IART.MIVA,
			IART.IDIMPUESTO,           
			IDCLASE = IART.IDCLASE_IMP, 
			FIMPD.DESCRIPCION,
			FIMPDV.VALOR
		FROM IART                                    
		INNER JOIN FIMPD ON IART.IDIMPUESTO = FIMPD.IDIMPUESTO 
			AND IART.IDCLASE_IMP = FIMPD.IDCLASE
		INNER JOIN FIMPDV ON FIMPD.IDIMPUESTO = FIMPDV.IDIMPUESTO 
			AND FIMPD.IDCLASE = FIMPDV.IDCLASE
		WHERE IART.IDARTICULO = @IDSERVICIO           
			OR IART.IDARTICULO LIKE @IDSERVICIO + '-%' 
		RETURN
	END
END
