CREATE OR ALTER PROCEDURE DBO.SPQ_CONTABILIDAD_3
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET DEADLOCK_PRIORITY HIGH;
    DECLARE 
        @PARAMETROS NVARCHAR(MAX), @CERRADA INT, @MESCONTABLE    VARCHAR(2), @ANOCONTABLE    VARCHAR(4), @CODCAJA    VARCHAR(20), @ANO        VARCHAR(4), @MES        VARCHAR(2),
        @CLASE_FAC  VARCHAR(10),  @ESTADO     VARCHAR(20), @ESTADO_BD  VARCHAR(1), @COMPANIA   VARCHAR(2), @IDSEDE     VARCHAR(2), @TIPORECIBO VARCHAR(20), @CNSFACJ    VARCHAR(20),
        @N_RECIBO   VARCHAR(20),	@CONTABILIZADA INT,	@MARCA INT, @PROCEDENCIA   VARCHAR(10), @REFERENCIA2   VARCHAR(20), @ITEMS_JSON    NVARCHAR(MAX),  @NROCOMPROBANTE VARCHAR(20),
		@SYS_COMPUTE VARCHAR(20),  @CNSMOV  VARCHAR(20), @CNSFPAG VARCHAR(20),  @CNSFNOT  VARCHAR(20), @CNSGLO VARCHAR(20), @BANCO VARCHAR(3), @SUCURSAL VARCHAR(3), @CTA_BCO VARCHAR(40),
		@INCONSISTENCIAS INT,	  @TIPO VARCHAR(5),	@MES_INT INT, @COUNT_PEND INT, @CNSFCXPXC VARCHAR(20),
        @TABLA      VARCHAR(50), @DESCRIPCION VARCHAR(1000), @HOJAEXP    VARCHAR(50),	@IDFORMATO  VARCHAR(20), @IDFORMATO_OLD VARCHAR(20),@CODCONCEPTO VARCHAR(20),
		@CODCONCEPTO_OLD VARCHAR(20),@CUENTAINI  VARCHAR(50),@CUENTAFIN  VARCHAR(50),@MTERCERO   VARCHAR(1),@NTZ        VARCHAR(20),@MOTOMIN    DECIMAL(18,2),
        @CAMPO      VARCHAR(50),@CAMPO_OLD  VARCHAR(50),@MSF        VARCHAR(50),@TIPOE      VARCHAR(20),@CODIGO     VARCHAR(20),@CODIGO_OLD VARCHAR(20),@VALOR1     VARCHAR(50),


		@MODELO     VARCHAR(100), 
        @METODO     VARCHAR(100),
        @USUARIO    VARCHAR(12),
		@PROCESO    VARCHAR(20);
		
    BEGIN TRY
        -- Validar JSON
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'JSON inv?lido' AS MENSAJE;
            RETURN;
        END;

        -- Extraer par?metros del JSON
        SELECT @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON)
        WITH (PARAMETROS NVARCHAR(MAX) AS JSON);

        SELECT 
            @MODELO  = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO  = JSON_VALUE(@JSON, '$.METODO'),
            @USUARIO = JSON_VALUE(@JSON, '$.USUARIO');

        -- Obtener COMPANIA del usuario
        SELECT @COMPANIA = COMPANIA
        FROM USUSU
        WHERE USUARIO = @USUARIO;
        IF @COMPANIA IS NULL
        BEGIN
            SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'Usuario no encontrado o sin compa??a asignada' AS MENSAJE;
            RETURN;
        END
        -- Normalizar m?todo a may?sculas
        SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))));
        -- M?TODO: LISTAR_RECIBOS 
        IF @METODO = 'LISTAR_RECIBOS'
        BEGIN
            -- Extraer par?metros
            SELECT 
                @CODCAJA    = JSON_VALUE(@PARAMETROS, '$.caja'),
                @ANO        = JSON_VALUE(@PARAMETROS, '$.ano'),
                @MES        = JSON_VALUE(@PARAMETROS, '$.mes'),
                @CLASE_FAC  = JSON_VALUE(@PARAMETROS, '$.clase'),
                @ESTADO     = JSON_VALUE(@PARAMETROS, '$.estado'),
				@CERRADA     = JSON_VALUE(@PARAMETROS, '$.cerrado'),
                @COMPANIA   = ISNULL(JSON_VALUE(@PARAMETROS, '$.compania'), @COMPANIA),
                @IDSEDE     = ISNULL(JSON_VALUE(@PARAMETROS, '$.idsede'), '01'),
                @TIPORECIBO = JSON_VALUE(@PARAMETROS, '$.tipoRecibo');

            -- Validar par?metros obligatorios
            IF @ANO IS NULL OR @MES IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'Debe especificar a?o y mes' AS MENSAJE;
                RETURN;
            END;

            -- MAPEAR ESTADO: frontend env?a descriptivos, necesitamos c?digos de BD
            SET @ESTADO_BD = NULL;
            
            IF @ESTADO IN ('Pendiente', 'NO_ENVIADAS', 'P')
                SET @ESTADO_BD = 'P';
            ELSE IF @ESTADO IN ('Enviado', 'ENVIADAS', 'C')
                SET @ESTADO_BD = 'C';
            ELSE IF @ESTADO IN ('Anulado', 'A')
                SET @ESTADO_BD = 'A';
           
            SELECT 
                -- Identificaci?n
                COALESCE(CAST(FCJ.N_RECIBO AS VARCHAR(20)),
                         CAST(FCJ.CNSFACJ AS VARCHAR(20)), 
                         'SIN-NUMERO') AS noRecibo,
                FCJ.CODCAJA AS caja,
                FORMAT(FCJ.FECHA, 'yyyyMMdd') AS fechaOrden,
                FORMAT(FCJ.FECHA, 'dd/MM/yyyy') AS fecha,
                CAST(ISNULL(FCJ.VALORTOTAL, 0) AS DECIMAL(18,2)) AS valorTotal,
                ISNULL(FCJ.NROCOMPROBANTE, '') AS ciContable,
                ISNULL(FCJ.ESTADO, 'P') AS estadoOriginal,
                
                -- Estado descriptivo para mostrar
                CASE ISNULL(FCJ.ESTADO, 'P')
                    WHEN 'D' THEN 'Desechada'
                    WHEN 'A' THEN 'Anulado'
                    WHEN 'P' THEN 'Preparada'
                END AS estado,
                
                CASE WHEN ISNULL(FCJ.CERRADA, 0) = 1 THEN 'S?' ELSE 'No' END AS cerrado,
                ISNULL(FCJ.CONTABILIZADA, 0) AS contabilizada,
                CASE FCJ.CLASE_FAC
                    WHEN 'P' THEN 'PAGO'
                    WHEN 'C' THEN 'COBRO'
                    ELSE ISNULL(FCJ.CLASE_FAC, '')
                END AS clase,
                
                ISNULL(FCJ.IDPLAN, '') AS idPlan,
                ISNULL(FCJ.TIPO, '') AS tipo,
                
                CASE 
                    WHEN FCJ.TIPO = 'E' THEN 'Efectivo'
                    WHEN FCJ.TIPO = 'C' THEN 'Cheque'
                    WHEN FCJ.TIPO = 'T' THEN 'Tarjeta'
                    WHEN FCJ.TIPO = 'B' THEN 'Transferencia'
                    ELSE ''
                END AS tipoTC,
                
                ISNULL(FCJ.IDTERCERO, '') AS tercero,
                ISNULL((SELECT TOP 1 RAZONSOCIAL 
                        FROM VWK_TEXCA WITH (NOLOCK)
                        WHERE IDTERCERO = FCJ.IDTERCERO),
                       ISNULL(FCJ.NOMBRECLIENTE, '')) AS descTerContable,
                ISNULL(FCJ.IDAFILIADO, '') AS afiliado,
                
                CASE FCJ.PROCEDENCIA
                    WHEN 'F' THEN 'Facturaci?n'
                    WHEN 'A' THEN 'Admisi?n'
                    WHEN 'C' THEN 'Caja'
                    WHEN 'CITAS' THEN 'Citas'
                    ELSE ISNULL(FCJ.PROCEDENCIA, '')
                END AS procedencia,
                
                ISNULL(FCJ.NOADMISION, '') AS noAdmision,
                ISNULL(FCJ.CCOSTO, '') AS cuenta,
                ISNULL(CUE.NOMCUENTA, 
                       ISNULL((SELECT TOP 1 NOMCUENTA 
                               FROM PUC WITH (NOLOCK)
                               WHERE CUENTA = FCJ.CCOSTO), '')) AS nombreCuenta,
                FCJ.CNSFACJ AS cnsfacj

            FROM FCJ WITH (NOLOCK)
            LEFT JOIN CUE WITH (NOLOCK) 
                ON CUE.CUENTA = FCJ.CCOSTO
                AND CUE.COMPANIA = FCJ.COMPANIA
            WHERE 
                FCJ.COMPANIA = @COMPANIA
                AND (@CODCAJA IS NULL OR FCJ.CODCAJA = @CODCAJA)
                AND YEAR(FCJ.FECHA) = CAST(@ANO AS INT)
                AND MONTH(FCJ.FECHA) = CAST(@MES AS INT)
                AND (
                    @CLASE_FAC IS NULL OR 
                    (CASE 
                        WHEN FCJ.CLASE_FAC = 'P' THEN 'PAGO'
                        WHEN FCJ.CLASE_FAC = 'C' THEN 'COBRO'
                        ELSE FCJ.CLASE_FAC
                    END = @CLASE_FAC)
                )
                -- FILTRO DE ESTADO CORREGIDO
				AND ISNULL(FCJ.ESTADO, 'P') = 'P'
                AND (@CERRADA IS NULL OR ISNULL(FCJ.CERRADA, 0) = @CERRADA)
				AND FCJ.DEAPERTURA <> 1
                /*AND (
                    @ESTADO_BD IS NULL OR 
                    ISNULL(FCJ.ESTADO, 'P') = @ESTADO_BD
                )*/
            ORDER BY FCJ.FECHA DESC, FCJ.CNSFACJ DESC;

            RETURN;
        END;
        -- M?TODO: DETALLE_RECIBO 
        IF @METODO = 'DETALLE_RECIBO'
        BEGIN
            SELECT @N_RECIBO = JSON_VALUE(@PARAMETROS, '$.noRecibo');

            IF @N_RECIBO IS NULL OR @N_RECIBO = ''
            BEGIN
                SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'Debe especificar No. Recibo' AS MENSAJE;
                RETURN;
            END;

            -- Buscar el recibo
            SELECT TOP 1 
                @CNSFACJ = CNSFACJ,
                @CODCAJA = CODCAJA
            FROM FCJ WITH (NOLOCK)
            WHERE CAST(N_RECIBO AS VARCHAR(20)) = @N_RECIBO
               OR CAST(CNSFACJ AS VARCHAR(20)) = @N_RECIBO;

            IF @CNSFACJ IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 
                    'Recibo no encontrado: ' + @N_RECIBO AS MENSAJE;
                RETURN;
            END;

            -- Verificar si hay detalle en FCJD
            IF EXISTS (
                SELECT 1 FROM FCJD WITH (NOLOCK) 
                WHERE CNSFACJ = @CNSFACJ 
                  AND CODCAJA = @CODCAJA
            )
            BEGIN
                SELECT 
                    FCJD.ITEM AS item,
                    ISNULL(CPCJ.DESCRIPCION, 'Concepto sin descripci?n') AS concepto,
                    CAST(ISNULL(FCJD.VALORTOTAL, 0) AS DECIMAL(18,2)) AS total
                FROM FCJD WITH (NOLOCK)
                LEFT JOIN CPCJ WITH (NOLOCK) 
                    ON FCJD.CONCEPTO = CPCJ.CODIGO
                WHERE FCJD.CNSFACJ = @CNSFACJ
                  AND FCJD.CODCAJA = @CODCAJA
                ORDER BY FCJD.ITEM;
            END
            ELSE
            BEGIN
                SELECT 
                    1 AS item,
                    'Recibo de Caja No. ' + @N_RECIBO AS concepto,
                    CAST(ISNULL(FCJ.VALORTOTAL, 0) AS DECIMAL(18,2)) AS total
                FROM FCJ WITH (NOLOCK)
                WHERE CNSFACJ = @CNSFACJ
                  AND CODCAJA = @CODCAJA;
            END;

            RETURN;
        END;
        -- M?TODO: FORMAS_PAGO 
        IF @METODO = 'FORMAS_PAGO'
        BEGIN
            SELECT @N_RECIBO = JSON_VALUE(@PARAMETROS, '$.noRecibo');

            IF @N_RECIBO IS NULL OR @N_RECIBO = ''
            BEGIN
                SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'Debe especificar No. Recibo' AS MENSAJE;
                RETURN;
            END;

            -- Buscar el recibo
            SELECT TOP 1 
                @CNSFACJ = CNSFACJ,
                @CODCAJA = CODCAJA
            FROM FCJ WITH (NOLOCK)
            WHERE CAST(N_RECIBO AS VARCHAR(20)) = @N_RECIBO
               OR CAST(CNSFACJ AS VARCHAR(20)) = @N_RECIBO;

            IF @CNSFACJ IS NULL
            BEGIN
                SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 
                    'Recibo no encontrado: ' + @N_RECIBO AS MENSAJE;
                RETURN;
            END;

            -- Verificar si hay formas de pago en PCJ
            IF EXISTS (
                SELECT 1 FROM PCJ WITH (NOLOCK) 
                WHERE CNSFACJ = @CNSFACJ 
                  AND CODCAJA = @CODCAJA
            )
            BEGIN
                SELECT 
                    ISNULL(FPA.DESCRIPCION, 
                        CASE ISNULL(PCJ.TIPOPAGO, '')
                            WHEN 'E' THEN 'Efectivo'
                            WHEN 'T' THEN 'Tarjeta'
                            WHEN 'C' THEN 'Cheque'
                            WHEN 'B' THEN 'Transferencia'
                            ELSE 'Otro'
                        END) AS formaPago,
                    CAST(ISNULL(PCJ.VALOR, 0) AS DECIMAL(18,2)) AS valor,
                    ISNULL(BCO.DESCRIPCION, ISNULL(PCJ.BANCO, '')) AS banco,
                    ISNULL(PCJ.NUMERODOCUMENTO, '') AS descripcion,
                    ISNULL(PCJ.IDTERCERO, '') AS idTercero,
                    ISNULL(PCJ.CUENTA, '') AS cuenta
                FROM PCJ WITH (NOLOCK)
                LEFT JOIN FPA WITH (NOLOCK)
                    ON PCJ.TIPOPAGO = FPA.FORMAPAGO
                LEFT JOIN BCO WITH (NOLOCK)
                    ON PCJ.BANCO = BCO.BANCO
                WHERE PCJ.CNSFACJ = @CNSFACJ
                  AND PCJ.CODCAJA = @CODCAJA
                ORDER BY PCJ.CNSPCJ;
            END
            ELSE
            BEGIN
                SELECT 
                    CASE ISNULL(FCJ.TIPO, '')
                        WHEN 'E' THEN 'Efectivo'
                        WHEN 'T' THEN 'Tarjeta'
                        WHEN 'C' THEN 'Cheque'
                        WHEN 'B' THEN 'Transferencia'
                        ELSE 'No especificado'
                    END AS formaPago,
                    CAST(ISNULL(FCJ.VALORTOTAL, 0) AS DECIMAL(18,2)) AS valor,
                    ISNULL(FCJ.CTA_BCO, '') AS banco,
                    ISNULL(FCJ.OBSERVACION, '') AS descripcion,
                    ISNULL(FCJ.IDTERCERO, '') AS idTercero,
                    ISNULL(FCJ.CCOSTO, '') AS cuenta
                FROM FCJ WITH (NOLOCK)
                WHERE FCJ.CNSFACJ = @CNSFACJ
                  AND FCJ.CODCAJA = @CODCAJA;
            END;

            RETURN;
        END;
        -- M?TODO: OBTENER_CAJAS
        IF @METODO = 'OBTENER_CAJAS'
        BEGIN
            SELECT 
                CODCAJA AS value,
                CODCAJA + ' - ' + DESCRIPCION AS label
            FROM CAJ WITH (NOLOCK)
            WHERE ESTADO = 'Activo'
            ORDER BY CODCAJA;

            RETURN;
        END
		--DETALLE INVENTARIO
		IF @METODO = 'DETALLE_OM_INVENTARIO'
		BEGIN
			 SELECT @CNSMOV      = JSON_VALUE(@PARAMETROS, '$.CNSMOV');
			IF @CNSMOV IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Consecutivo de movimiento es requerido' AS ERROR;
				RETURN;
			END

			BEGIN TRY
				IF NOT EXISTS (
					SELECT 1 FROM IMOV 
					WHERE CNSMOV = @CNSMOV
				)
				BEGIN
					SELECT 'KO' AS OK, 'Movimiento no encontrado' AS ERROR;
					RETURN;
				END

				SELECT
					'OK' AS OK,
					IMOVH.IDARTICULO AS articulo,
					ISNULL(IART.DESCRIPCION, '') AS descripcion,
					ISNULL(IMOVH.CANTIDAD, 0) AS cantidad,
					ISNULL(IMOVH.PCOSTO, 0) AS costo_unidad,
					ISNULL(IMOVH.CANTIDAD * IMOVH.PCOSTO, 0) AS total
				FROM IMOVH
				LEFT JOIN IART ON IMOVH.IDARTICULO = IART.IDARTICULO
				WHERE IMOVH.CNSMOV = @CNSMOV
				ORDER BY IMOVH.IDARTICULO;

				RETURN;
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar detalle: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH
		END 
		-- M?TODO DETALLE CXC
		IF @METODO = 'DETALLE_OM_CXC'
		BEGIN
			 SELECT @CNSFPAG = JSON_VALUE(@PARAMETROS, '$.CNSFPAG');
			IF @CNSFPAG IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Consecutivo de pago es requerido' AS ERROR;
				RETURN;
			END

			BEGIN TRY
				IF NOT EXISTS (
					SELECT 1 FROM FPAG 
					WHERE CNSFPAG = @CNSFPAG AND COMPANIA = @COMPANIA
				)
				BEGIN
					SELECT 'KO' AS OK, 'Recaudo no encontrado' AS ERROR;
					RETURN;
				END

				-- Intentar obtener detalle de FPAGDET
				IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FPAGDET')
				BEGIN
					SELECT
						'OK' AS OK,
						DET.CNSFPAG AS cons_cxc,
						ISNULL(DET.NO_FACT, '') AS no_fact,
						ISNULL(DET.VALORFACTURA, 0) AS valor_factura,
						ISNULL(DET.VLRGLOSAS, 0) AS glosa,
						ISNULL(DET.ARF, 0) AS arf,
						ISNULL(DET.VALORCOPAGO, 0) AS valor_copago,
						ISNULL(DET.BASE, 0) AS base,
						ISNULL(DET.VLRIMPUESTOS, 0) AS valor_impuesto,
						ISNULL(DET.VLRSINDTO, 0) AS vlr_sin_dto,
						ISNULL(DET.VALORDTOFIN, 0) AS valor_dto_fin,
						ISNULL(DET.SP, 0) AS sp,
						ISNULL(DET.PAGOEXTRA, 0) AS pago_extra,
						ISNULL(DET.PAGO, 0) AS pago
					FROM FPAGDET DET
					WHERE DET.CNSFPAG = @CNSFPAG AND DET.COMPANIA = @COMPANIA
					ORDER BY ISNULL(DET.ITEM, 0), ISNULL(DET.RENGLON, 0);
					RETURN;
				END

				-- Intentar obtener detalle de DFPAG
				IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DFPAG')
				BEGIN
					SELECT
						'OK' AS OK,
						DET.CNSFPAG AS cons_cxc,
						ISNULL(DET.NO_FACT, '') AS no_fact,
						ISNULL(DET.VALORFACTURA, 0) AS valor_factura,
						ISNULL(DET.VLRGLOSAS, 0) AS glosa,
						ISNULL(DET.ARF, 0) AS arf,
						ISNULL(DET.VALORCOPAGO, 0) AS valor_copago,
						ISNULL(DET.BASE, 0) AS base,
						ISNULL(DET.VLRIMPUESTOS, 0) AS valor_impuesto,
						ISNULL(DET.VLRSINDTO, 0) AS vlr_sin_dto,
						ISNULL(DET.VALORDTOFIN, 0) AS valor_dto_fin,
						ISNULL(DET.SP, 0) AS sp,
						ISNULL(DET.PAGOEXTRA, 0) AS pago_extra,
						ISNULL(DET.PAGO, 0) AS pago
					FROM DFPAG DET
					WHERE DET.CNSFPAG = @CNSFPAG AND DET.COMPANIA = @COMPANIA
					ORDER BY ISNULL(DET.ITEM, 0), ISNULL(DET.RENGLON, 0);
					RETURN;
				END

				-- Si no existe tabla de detalle, retornar datos b?sicos
				SELECT
					'OK' AS OK,
					FPAG.CNSFPAG AS cons_cxc,
					'' AS no_fact,
					ISNULL(FPAG.VLRTOTAL, 0) AS valor_factura,
					0 AS glosa,
					0 AS arf,
					0 AS valor_copago,
					ISNULL(FPAG.VLRITEMS, 0) AS base,
					ISNULL(FPAG.VLRIMPUESTOS, 0) AS valor_impuesto,
					0 AS vlr_sin_dto,
					ISNULL(FPAG.VLRDTOFINAN, 0) AS valor_dto_fin,
					0 AS sp,
					0 AS pago_extra,
					ISNULL(FPAG.VLRTOTAL, 0) AS pago
				FROM FPAG
				WHERE FPAG.CNSFPAG = @CNSFPAG AND FPAG.COMPANIA = @COMPANIA;
				RETURN;
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar detalle: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH
		END
		-- M?TODO DETALLE NOTA DEBITO CREDITO
		IF @METODO = 'DETALLE_OM_NOTADBCR'
		BEGIN
            SELECT @CNSFNOT     = JSON_VALUE(@PARAMETROS, '$.CNSFNOT');
			IF @CNSFNOT IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Consecutivo de nota es requerido' AS ERROR;
				RETURN;
			END

			BEGIN TRY
				IF NOT EXISTS (SELECT 1 FROM FNOT WHERE CNSFNOT = @CNSFNOT)
				BEGIN
					SELECT 'KO' AS OK, 'Nota no encontrada' AS ERROR;
					RETURN;
				END

				SELECT
					'OK' AS OK,
					ISNULL(FNOTD.ITEM, 0) AS ITEM,
					ISNULL(FNOTD.TIPO, '') AS TIPO,
					ISNULL(FNOTD.IDSERVICIO, '') AS IDSERVICIO,
					ISNULL(FNOTD.CANTIDAD, 0) AS CANTIDAD,
					ISNULL(FNOTD.VR_UNITARIO, 0) AS VR_UNITARIO,
					ISNULL(FNOTD.VR_TOTAL, 0) AS VR_TOTAL,
					ISNULL(FNOTD.DESCRIPCION, '') AS DESCRIPCION
				FROM FNOTD
				WHERE FNOTD.CNSFNOT = @CNSFNOT
				ORDER BY FNOTD.ITEM;
				RETURN;
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar detalle: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH 
		END
		-- M?TODO BODEGAS - Obtener lista de bodegas ?nicas
		IF @METODO = 'BODEGAS'
		BEGIN
			BEGIN TRY
				SELECT DISTINCT
					'OK' AS OK,
					IMOV.IDBODEGA AS id_bodega,
					ISNULL(IBOD.DESCRIPCION, IMOV.IDBODEGA) AS descripcion
				FROM IMOV
				LEFT JOIN IBOD ON IMOV.IDBODEGA = IBOD.IDBODEGA
				WHERE IMOV.IDBODEGA IS NOT NULL
					AND IMOV.IDBODEGA <> ''
				ORDER BY IMOV.IDBODEGA;

				RETURN;
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar bodegas: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH
		END
		-- M?TODO DETALLE OTROS MODULOS GLOSAS
		IF @METODO = 'DETALLE_OM_GLOSAS'
		BEGIN
			SELECT  @CNSGLO = JSON_VALUE(@PARAMETROS, '$.CNSGLO');
			IF @CNSGLO IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Consecutivo de glosa es requerido' AS ERROR;
				RETURN;
			END
        
			BEGIN TRY
				IF NOT EXISTS (
					SELECT 1 FROM FGLO 
					WHERE CNSGLO = @CNSGLO
				)
				BEGIN
					SELECT 'KO' AS OK, 'Glosa no encontrada' AS ERROR;
					RETURN;
				END
            
				SELECT
					'OK' AS OK,
					FGLO.CNSGLO,
					FGLO.CNSCXC,
					FGLO.N_FACTURA,
					FGLO.F_FACTURA,
					FGLO.TIPO,
					ISNULL(FGLO.VLRGLOSA, 0) AS VLRGLOSA,
					ISNULL(FGLO.VLRACEPTADO, 0) AS VLRACEPTADO,
					ISNULL(FGLO.VLRRECUPERAR, 0) AS VLRRECUPERAR,
					FGLO.OBSERVACION,
					ISNULL(FGLO.CERRADA, 0) AS CERRADA,
					FGLO.USUARIO,
					ISNULL(FGLO.ASIGENT, 0) AS ASIGENT,
					FGLO.CNSENTREGA,
					ISNULL(FGLO.MARCAENT, 0) AS MARCAENT,
					FGLO.CNSMARCA,
					ISNULL(FGLO.ENAUDITORIA, 0) AS ENAUDITORIA,
					FGLO.FECHAAUD,
					FGLO.IDTERCERO,
					FGLO.FECHARESP,
					FGLO.USURESPONRTA,
					FGLO.OBSERVACIONRTA,
					FGLO.USUARIOINGRTA,
					FGLO.TIPORESPUESTA,
					FGLO.CNSFPAG,
					ISNULL(FGLO.ASIGDEV, 0) AS ASIGDEV,
					FGLO.CNSENTDEV,
					FGLO.IDDEP,
					FGLO.CNSFNOT,
					FGLO.ESTADO,
					ISNULL(FGLO.ABONADO, 0) AS ABONADO,
					ISNULL(FGLO.SALDO, 0) AS SALDO,
					FGLO.CNSGLO_O,
					FGLO.RADICADO,
					FGLO.CNSGLOI,
					ISNULL(FGLO.ASIGNADAIMP, 0) AS ASIGNADAIMP,
					FGLO.IDCONCEPTO,
					FGLO.PROCEDENCIA,
					ISNULL(FGLO.GENERANOTA, 0) AS GENERANOTA,
					ISNULL(FGLO.CONTABILIZADA, 0) AS CONTABILIZADA,
					FGLO.FECHAGEN,
					FGLO.NROCOMPROBANTE,
					ISNULL(FGLO.MARCACONT, 0) AS MARCACONT,
					FGLO.RAZONANULA,
					FGLO.USUARIOANULA,
					FGLO.FECHAANU,
					FGLO.CODUNG,
					FGLO.CODPRG,
					ISNULL(FGLO.ENPRESUPUESTO, 0) AS ENPRESUPUESTO,
					FGLO.TCONCILIACION,
					FGLO.FECHACONC,
					FGLO.OBSCONCILIACION,
					FGLO.TIPOCONCILIACION,
					ISNULL(FGLO.VALORCONC, 0) AS VALORCONC,
					FGLO.CNSFNOTCONC,
					FGLO.ASIGNADOA,
					FGLO.FASIGNA,
					FGLO.FLIMITE,
					FGLO.CODNDIAN,
					FGLO.FCIERRE,
					FGLO.CNSRMASIVO,
					FGLO.FRADICA_RIPS,
					FGLO.CUV
				FROM FGLO
				WHERE FGLO.CNSGLO = @CNSGLO;
				RETURN;
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar detalle: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH
		END
		-- M?TODO ITEMS OTROS MODULOS GLOSAS
		IF @METODO = 'ITEMS_OM_GLOSAS'
		BEGIN
			SELECT  @CNSGLO = JSON_VALUE(@PARAMETROS, '$.CNSGLO');
			-- Validar que CNSGLO est? presente
			IF @CNSGLO IS NULL OR LTRIM(RTRIM(@CNSGLO)) = ''
			BEGIN
				SELECT 'KO' AS OK, 'Consecutivo de glosa es requerido' AS ERROR;
				RETURN;
			END
        
			BEGIN TRY
				-- Consultar FGLOD directamente (tabla de detalle de glosas)
				-- FGLOD contiene los items detallados de cada glosa relacionados por CNSGLO
				IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FGLOD')
				BEGIN
					-- Verificar si hay registros para este CNSGLO
					IF EXISTS (SELECT 1 FROM FGLOD WHERE CNSGLO = @CNSGLO)
					BEGIN
						-- Consultar FGLOD con las columnas reales de la tabla
						SELECT
							'OK' AS OK,
							ROW_NUMBER() OVER (ORDER BY ISNULL(FGLOD.CODGLOSA, ''), ISNULL(FGLOD.TIPO, '')) AS ITEM,
							ISNULL(CAST(FGLOD.TIPO AS VARCHAR(10)), '') AS TIPO,
							ISNULL(CAST(FGLOD.IDSERVICIO AS VARCHAR(20)), '') AS IDSERVICIO,
							ISNULL(CAST(FGLOD.CONCEPTO AS VARCHAR(20)), '') AS CONCEPTO,
							ISNULL(CAST(FGLOD.DESCRIPCION AS VARCHAR(200)), '') AS DESCRIPCION,
							ISNULL(CAST(FGLOD.VLRGLOSA AS DECIMAL(18,2)), 0) AS VLRGLOSA,
							ISNULL(CAST(FGLOD.VLRACEPTADO AS DECIMAL(18,2)), 0) AS VLRACEPTADO,
							ISNULL(CAST(FGLOD.VLRRECUPERAR AS DECIMAL(18,2)), 0) AS VLRRECUPERAR,
							ISNULL(CAST(FGLOD.OBSERVACION AS VARCHAR(MAX)), '') AS OBSERVACION,
							ISNULL(CAST(FGLOD.RESPUESTA AS VARCHAR(MAX)), '') AS RESPUESTA
						FROM FGLOD
						WHERE FGLOD.CNSGLO = @CNSGLO
						ORDER BY ISNULL(FGLOD.CODGLOSA, ''), ISNULL(FGLOD.TIPO, '');
						RETURN;
					END
					ELSE
					BEGIN
						-- No hay registros en FGLOD para este CNSGLO, retornar conjunto vac?o
						SELECT 
							'OK' AS OK, 
							1 AS ITEM, 
							'' AS TIPO, 
							'' AS IDSERVICIO, 
							'' AS CONCEPTO, 
							'' AS DESCRIPCION, 
							0 AS VLRGLOSA, 
							0 AS VLRACEPTADO, 
							0 AS VLRRECUPERAR,
							'' AS OBSERVACION, 
							'' AS RESPUESTA
						WHERE 1 = 0;
						RETURN;
					END
				END
				ELSE
				BEGIN
					-- La tabla FGLOD no existe, retornar conjunto vac?o
					SELECT 
						'OK' AS OK, 
						1 AS ITEM, 
						'' AS TIPO, 
						'' AS IDSERVICIO, 
						'' AS CONCEPTO, 
						'' AS DESCRIPCION, 
						0 AS VLRGLOSA, 
						0 AS VLRACEPTADO, 
						0 AS VLRRECUPERAR,
						'' AS OBSERVACION, 
						'' AS RESPUESTA
					WHERE 1 = 0;
					RETURN;
				END
			END TRY
			BEGIN CATCH
				SELECT 'KO' AS OK, 'Error al consultar items: ' + ERROR_MESSAGE() AS ERROR;
				RETURN;
			END CATCH
		END

		IF @METODO = 'UPDATE_FCJ'
		BEGIN
			SELECT  @CNSFACJ = JSON_VALUE(@PARAMETROS, '$.CNSFACJ')
			SELECT  @CODCAJA = JSON_VALUE(@PARAMETROS, '$.CODCAJA')

			IF NOT EXISTS (SELECT 1 FROM FCJ WHERE CNSFACJ = @CNSFACJ AND CODCAJA = @CODCAJA)
			BEGIN
				SELECT 'KO' AS OK, 'ERROR, Recibo de caja inexistente' AS ERROR;
                RETURN;
			END

			UPDATE FCJ SET CONTABILIZADA = 1 WHERE CNSFACJ = @CNSFACJ AND CODCAJA = @CODCAJA
			
			SELECT 'OK' AS OK
		END

		IF @METODO = 'CORREGIR_Y_CONTABILIZAR_FCJ'
		BEGIN
			SELECT  @CNSFACJ = JSON_VALUE(@PARAMETROS, '$.CNSFACJ')
			SELECT  @CODCAJA = JSON_VALUE(@PARAMETROS, '$.CODCAJA')

			IF NOT EXISTS (SELECT 1 FROM FCJ WHERE CNSFACJ = @CNSFACJ AND CODCAJA = @CODCAJA)
			BEGIN
				SELECT 'KO' AS OK, 'ERROR, Recibo de caja inexistente' AS ERROR;
                RETURN;
			END

			UPDATE FCJ SET CONTABILIZADA = 0, NROCOMPROBANTE = NULL WHERE CNSFACJ = @CNSFACJ AND CODCAJA = @CODCAJA

			--SELECT * FROM FCJ WHERE CNSFACJ = @CNSFACJ AND CODCAJA = @CODCAJA
			
			SELECT 'OK' AS OK

		END

		--=========== ENVIAR CONTABILIZAR TOODS LAS PROCEDECNIAS OTROS MODULOS=====================
		IF @METODO = 'ENV_CONTA_OTROS_MODULS'
		BEGIN
			SELECT
				@ANO            = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE'))), ''),
				@MES            = RIGHT('00' + LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.MESCONTABLE'))), 2),
				@USUARIO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.USUARIO'))), ''),
				@PROCEDENCIA    = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.PROCEDENCIA'))), ''),
				@NROCOMPROBANTE = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.NROCOMPROBANTE'))), ''),
				@REFERENCIA2    = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.REFERENCIA2'))), ''),
				@ITEMS_JSON     = JSON_QUERY(@PARAMETROS, '$.ITEMS'),
				--RECIBO DATOS DE BANCO
				@BANCO          = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.BANCO'))), ''),
				@SUCURSAL       = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.SUCURSAL'))), ''),
				@CTA_BCO        = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CTA_BCO'))), '');
				
				SET @MES_INT = TRY_CAST(@MES AS INT);

				SET DATEFORMAT dmy;				
				--CAPTURO IDSEDE
				SELECT @IDSEDE = COALESCE(IDSEDE,HOST_NAME()) FROM USUSU WHERE USUARIO= @USUARIO
				--CAPTURO COMPA?IA
				SELECT @COMPANIA = COALESCE(COMPANIA,HOST_NAME()) FROM USUSU WHERE USUARIO= @USUARIO
				--COMPUTADOR
				SELECT @SYS_COMPUTE = COALESCE(SYS_COMPUTERNAME,HOST_NAME()) FROM USUSU WHERE USUARIO= @USUARIO --@USUANULA
				
				PRINT @ANO;	PRINT @MES;	PRINT @IDSEDE;	PRINT @USUARIO;	PRINT @PROCEDENCIA;	PRINT @COMPANIA;PRINT @NROCOMPROBANTE;PRINT @REFERENCIA2;PRINT @ITEMS_JSON
				PRINT 'DATOS DE BANCO'; PRINT @BANCO; PRINT @SUCURSAL; PRINT @CTA_BCO;
				IF NOT EXISTS (SELECT 1  FROM PRI WHERE ANO = @ANO AND MES = @MES AND ISNULL(CERRADO,0) = 0)
				BEGIN
					SELECT 'KO' AS OK, 'ERROR, El periodo seleccionado se encuentra cerrado' AS ERROR;
					RETURN;
				END
				IF @ITEMS_JSON IS NULL OR LTRIM(RTRIM(@ITEMS_JSON)) = '' OR LTRIM(RTRIM(@ITEMS_JSON)) = '[]'
				BEGIN
					SELECT 'KO' AS OK, 'Debe enviar al menos un item (ITEMS) para facturas' AS ERROR;
					RETURN;
				END 
				IF @PROCEDENCIA='FACTURA'
				BEGIN
					PRINT 'ENTRE A FACTURA'
					IF EXISTS (SELECT 1 FROM FTR WHERE YEAR(F_FACTURA) = @ANO AND MONTH(F_FACTURA) = @MES AND CONTABILIZADA in(1,2)	AND N_FACTURA IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, hayfactura(s) ya contabilizadas. No se puede enviar.' AS ERROR;
						RETURN;
					END
					UPDATE FTR
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(F_FACTURA) = @ANO 
					AND MONTH(F_FACTURA) = @MES 
					AND COALESCE(CONTABILIZADA,0) = 0 
					AND FTR.N_FACTURA IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM FTR WHERE YEAR(F_FACTURA) = @ANO AND MONTH(F_FACTURA) = @MES AND (CONTABILIZADA = 0 OR CONTABILIZADA IS NULL) AND MARCACONT = 1 AND N_FACTURA IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						PRINT 'NO ACTUALIZO'
						SELECT 'KO' AS OK, 'ERROR, No hay item marcado en MARCACONT.' AS ERROR;
						RETURN;
					END
				END 
				IF @PROCEDENCIA='CAJA'
				BEGIN
					PRINT 'ENTRE A CAJA'
					IF @REFERENCIA2 IS NULL OR @REFERENCIA2 = ''
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, debe seleccionar una caja del filtro inicial.' AS ERROR;
						RETURN;
					END
					IF NOT EXISTS (SELECT 1 FROM FCJ WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND ESTADO='P' AND CERRADA=1 AND COALESCE(CONTABILIZADA,0)= 0 AND CODCAJA= @REFERENCIA2 AND CNSFACJ IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay recibos pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM FCJ WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND ESTADO='P' AND CERRADA=1 AND CONTABILIZADA IN (1,2) AND CODCAJA= @REFERENCIA2 AND CNSFACJ IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay recibos marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE FCJ
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(FECHA) = @ANO 
					AND MONTH(FECHA) = @MES 
					AND ISNULL(CONTABILIZADA,0) = 0
					AND ESTADO='P' AND CERRADA=1 
					AND CNSFACJ IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM FCJ WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND ESTADO='P' AND CERRADA=1  AND (CONTABILIZADA = 0 OR CONTABILIZADA IS NULL) AND MARCACONT = 1 AND CODCAJA= @REFERENCIA2 AND CNSFACJ IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				IF @PROCEDENCIA='CXP'
				BEGIN
					PRINT 'ENTRE A CXP'
					UPDATE FCXP
					SET MARCACONT = 0
					WHERE YEAR(TRY_CONVERT(DATE, F_FACTURAREF, 103)) = @ANO
					  AND MONTH(TRY_CONVERT(DATE, F_FACTURAREF, 103)) = @MES;

					IF NOT EXISTS (SELECT 1 FROM FCXP WHERE YEAR(F_FACTURAREF) = @ANO AND MONTH(F_FACTURAREF) = @MES AND COALESCE(CONTABILIZADA,0)= 0 AND CNSFCXP IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay CXP pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM FCXP WHERE YEAR(F_FACTURAREF) = @ANO AND MONTH(F_FACTURAREF) = @MES AND CONTABILIZADA IN (1,2) AND CNSFCXP IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay CXP marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE  FCXP 
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(F_FACTURAREF) = @ANO 
					AND MONTH(F_FACTURAREF) = @MES 
					AND ISNULL(CONTABILIZADA,0) = 0
					AND CNSFCXP IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM FCXP WHERE YEAR(F_FACTURAREF) = @ANO AND MONTH(F_FACTURAREF) = @MES AND COALESCE(CONTABILIZADA,0)= 0  AND MARCACONT = 1 AND CNSFCXP IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END 
				IF @PROCEDENCIA='CXC'
				BEGIN
					PRINT 'ENTRE A CXC'
					UPDATE  FPAG  
					SET MARCACONT = 0
					WHERE YEAR(FECHA) = @ANO
					  AND MONTH(FECHA) = @MES;

					IF NOT EXISTS (SELECT 1 FROM FPAG WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND COALESCE(CONTABILIZADO,0)= 0 AND CNSFPAG IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay CXC (FPAG) pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM FPAG WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND CONTABILIZADO IN (1,2) AND CNSFPAG IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay CXC (FPAG) marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END

					UPDATE FPAG
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(FECHA) = @ANO 
					AND MONTH(FECHA) = @MES 
					AND ISNULL(CONTABILIZADO,0) = 0
					AND CNSFPAG IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF EXISTS (
						SELECT 1
						FROM FPAG
						WHERE MARCACONT = 1
						  AND FPAG.FECHA IS NOT NULL
						  AND TRY_CONVERT(DATETIME, FPAG.FECHA, 103) IS NULL
					)
					BEGIN
						SELECT 'KO' AS OK,
							'ERROR, Hay recaudos con FECHA inv?lida para el formato dd/MM/yyyy (FPAG.FECHA). No se puede contabilizar.' AS ERROR;
						RETURN;
					END

					IF NOT EXISTS (SELECT 1 FROM FPAG WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND COALESCE(CONTABILIZADO,0)= 0  AND MARCACONT = 1 AND CNSFPAG IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				IF @PROCEDENCIA='RGLO'
				BEGIN
					PRINT 'ENTRE A RGLO'
					IF NOT EXISTS (SELECT 1 FROM FGLO WHERE YEAR(FECHARESP) = @ANO AND MONTH(FECHARESP) = @MES AND COALESCE(CONTABILIZADA,0)= 0 AND CNSGLO IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay glosas pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM FGLO WHERE YEAR(FECHARESP) = @ANO AND MONTH(FECHARESP) = @MES AND CONTABILIZADA IN (1,2) AND CNSGLO IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay glosas marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE FGLO
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(FECHARESP) = @ANO 
					AND MONTH(FECHARESP) = @MES 
					AND ISNULL(CONTABILIZADA,0) = 0
					AND CNSGLO IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM FGLO WHERE YEAR(FECHARESP) = @ANO AND MONTH(FECHARESP) = @MES AND COALESCE(CONTABILIZADA,0)= 0  AND MARCACONT = 1 AND CNSGLO IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				IF @PROCEDENCIA='INV'
				BEGIN
					PRINT 'ENTRE A INV'
					IF COALESCE(@REFERENCIA2,'')=''
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Debe seleccionar la bodega' AS ERROR;
						RETURN;
					END

					-- Se marca por CNSMOV + bodega (ITEMS). No filtrar por FECHACONF:
					-- el front lista por FECHAMOV y FECHACONF puede ser NULL u otro mes.
					IF NOT EXISTS (
						SELECT 1
						FROM IMOV
						WHERE COALESCE(CONTABILIZADA, 0) = 0
						  AND LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
						  AND LTRIM(RTRIM(CNSMOV)) IN (
								SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
								FROM OPENJSON(@ITEMS_JSON) j
						  )
					)
					BEGIN
						SELECT 'KO' AS OK, N'ERROR, No hay movimientos pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (
						SELECT 1
						FROM IMOV
						WHERE CONTABILIZADA IN (1, 2)
						  AND LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
						  AND LTRIM(RTRIM(CNSMOV)) IN (
								SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
								FROM OPENJSON(@ITEMS_JSON) j
						  )
					)
					BEGIN
						SELECT 'KO' AS OK, N'ERROR, Hay movimientos marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END

					UPDATE IMOV
					SET MARCACONT = 1
					WHERE LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
					  AND ISNULL(CONTABILIZADA, 0) = 0
					  AND LTRIM(RTRIM(CNSMOV)) IN (
							SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
							FROM OPENJSON(@ITEMS_JSON) j
					  );

					IF NOT EXISTS (
						SELECT 1
						FROM IMOV
						WHERE COALESCE(CONTABILIZADA, 0) = 0
						  AND LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
						  AND MARCACONT = 1
						  AND LTRIM(RTRIM(CNSMOV)) IN (
								SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
								FROM OPENJSON(@ITEMS_JSON) j
						  )
					)
					BEGIN
						SELECT 'KO' AS OK, N'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				IF @PROCEDENCIA='NOTDBCR'
				BEGIN
					PRINT 'ENTRE A NOTDBCR'
					IF COALESCE(@REFERENCIA2,'')=''
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Debe seleccionar el tipo de nota' AS ERROR;
						RETURN;
					END

					IF NOT EXISTS (SELECT 1 FROM FNOT WHERE YEAR(F_NOTA) = @ANO AND MONTH(F_NOTA) = @MES AND COALESCE(CONTABILIZADA,0)= 0 AND CLASE=@REFERENCIA2 AND CNSFNOT IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay Notas pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM FNOT WHERE YEAR(F_NOTA) = @ANO AND MONTH(F_NOTA) = @MES AND CONTABILIZADA IN (1,2) AND CLASE=@REFERENCIA2 AND CNSFNOT IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay Notas marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE FNOT
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(F_NOTA) = @ANO 
					AND MONTH(F_NOTA) = @MES 
					AND CLASE = @REFERENCIA2
					AND ISNULL(CONTABILIZADA,0) = 0
					AND CNSFNOT IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM FNOT WHERE YEAR(F_NOTA) = @ANO AND MONTH(F_NOTA) = @MES AND COALESCE(CONTABILIZADA,0)= 0  AND MARCACONT = 1 AND CNSFNOT IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END 
				IF @PROCEDENCIA='ACTIVOS_MOV'
				BEGIN
					PRINT 'ENTRE A ACTIVOS_MOV'
					IF NOT EXISTS (SELECT 1 FROM IACTH WHERE YEAR(FECHAEVENTO) = @ANO AND MONTH(FECHAEVENTO) = @MES AND COALESCE(CONTABILIZADA,0)= 0 AND CNSIACTH IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay Movimientos de activos pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM IACTH WHERE YEAR(FECHAEVENTO) = @ANO AND MONTH(FECHAEVENTO) = @MES AND CONTABILIZADA IN (1,2) AND CNSIACTH IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay Movimientos de activos marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE IACTH
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(FECHAEVENTO) = @ANO 
					AND MONTH(FECHAEVENTO) = @MES 
					AND ISNULL(CONTABILIZADA,0) = 0
					AND CNSIACTH IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM IACTH WHERE YEAR(FECHAEVENTO) = @ANO AND MONTH(FECHAEVENTO) = @MES AND COALESCE(CONTABILIZADA,0)= 0  AND MARCACONT = 1 AND CNSIACTH IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END				
				IF @PROCEDENCIA='BMOV'
				BEGIN
					PRINT 'ENTRE A BANCOS'
					IF COALESCE(@BANCO,'') = '' OR COALESCE(@SUCURSAL,'') = '' OR COALESCE(@CTA_BCO,'') = ''
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Debe enviar BANCO, SUCURSAL y CTA_BCO para procedencia BMOV' AS ERROR;
						RETURN;
					END

					IF NOT EXISTS (
						SELECT 1
						FROM BMOV
						WHERE YEAR(FECHAOPERACION) = @ANO
						  AND MONTH(FECHAOPERACION) = @MES
						  AND BANCO = @BANCO
						  AND SUCURSAL = @SUCURSAL
						  AND CTA_BCO = @CTA_BCO
						  AND ESTADO = 'O'
						  AND COALESCE(CONTABILIZADA,0)= 0
						  AND ITEM IN (SELECT value FROM OPENJSON(@ITEMS_JSON))
					)
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay movimientos bancarios pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (	SELECT 1 FROM BMOV
						WHERE YEAR(FECHAOPERACION) = @ANO
						  AND MONTH(FECHAOPERACION) = @MES
						  AND BANCO = @BANCO
						  AND SUCURSAL = @SUCURSAL
						  AND CTA_BCO = @CTA_BCO
						  AND ESTADO = 'O'
						  AND CONTABILIZADA IN (1,2)
						  AND ITEM IN (SELECT value FROM OPENJSON(@ITEMS_JSON))
					)
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay movimientos bancarios marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE BMOV
					SET MARCACONT = 1
					WHERE YEAR(FECHAOPERACION) = @ANO
					  AND MONTH(FECHAOPERACION) = @MES
					  AND BANCO = @BANCO
					  AND SUCURSAL = @SUCURSAL
					  AND CTA_BCO = @CTA_BCO
					  AND ESTADO = 'O'
					  AND ISNULL(CONTABILIZADA,0) = 0
					  AND ITEM IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);


					IF NOT EXISTS (
						SELECT 1
						FROM BMOV
						WHERE YEAR(FECHAOPERACION) = @ANO
						  AND MONTH(FECHAOPERACION) = @MES
						  AND BANCO = @BANCO
						  AND SUCURSAL = @SUCURSAL
						  AND CTA_BCO = @CTA_BCO
						  AND ESTADO = 'O'
						  AND COALESCE(CONTABILIZADA,0)= 0
						  AND MARCACONT = 1
						  AND ITEM IN (SELECT value FROM OPENJSON(@ITEMS_JSON))
					)
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				IF @PROCEDENCIA='HPRE'
				BEGIN
					PRINT 'ENTRE A HPRE'
					IF NOT EXISTS (SELECT 1 FROM HPRE WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND COALESCE(CONTABILIZADA,0)= 0 AND NOPRESTACION IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No hay Prestaciones pendientes por contabilizar' AS ERROR;
						RETURN;
					END

					IF EXISTS (SELECT 1 FROM HPRE WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND CONTABILIZADA IN (1,2) AND NOPRESTACION IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, Hay Prestaciones marcados que ya se enviaron a contabilidad' AS ERROR;
						RETURN;
					END
					UPDATE HPRE
					SET MARCACONT = 1
					WHERE 1=1
					AND	YEAR(FECHA) = @ANO 
					AND MONTH(FECHA) = @MES 
					AND ISNULL(CONTABILIZADA,0) = 0
					AND NOPRESTACION IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);

					IF NOT EXISTS (SELECT 1 FROM HPRE WHERE YEAR(FECHA) = @ANO AND MONTH(FECHA) = @MES AND COALESCE(CONTABILIZADA,0)= 0  AND MARCACONT = 1 AND NOPRESTACION IN (SELECT value FROM OPENJSON(@ITEMS_JSON)))
					BEGIN
						SELECT 'KO' AS OK, 'ERROR, No existe ningun item marcado en la columna MARCACONT.' AS ERROR;
						RETURN;
					END
				END
				--SI PASA TODAS LAS VALIDACIONES SE EJECUTA SPK 
				BEGIN TRY
							
					PRINT 'PASO TODAS LAS VALIDACIONES ENTRO A SPK CONTAB MASIVA'
					PRINT CONCAT('SPK params ANO=', @ANO, ' MES=', @MES, ' MES_INT=', @MES_INT, ' REF2=', @REFERENCIA2)
					EXEC SPK_CONTAB_MASIVA @ANO, @MES_INT, @COMPANIA, @USUARIO, @SYS_COMPUTE, @IDSEDE, @PROCEDENCIA,@NROCOMPROBANTE, @REFERENCIA2;
					
					IF @PROCEDENCIA = 'CXP'
					BEGIN
						UPDATE FCXP
						SET MARCACONT = 0
						WHERE YEAR(TRY_CONVERT(DATE, F_FACTURAREF, 103)) = @ANO
						  AND MONTH(TRY_CONVERT(DATE, F_FACTURAREF, 103)) = @MES
						  AND CNSFCXP IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);
					END
					IF @PROCEDENCIA = 'CXC'
					BEGIN
						UPDATE FPAG
						SET MARCACONT = 0
						WHERE YEAR(FECHA) = @ANO
						  AND MONTH(FECHA) = @MES
						  AND CNSFPAG IN (SELECT CAST(j.value AS VARCHAR(50)) FROM OPENJSON(@ITEMS_JSON) j);
					END

					-- INV: detectar "éxito vacío" (entró al SPK pero no contabilizó los ITEMS)
					IF @PROCEDENCIA = 'INV'
					BEGIN
						SELECT @COUNT_PEND = COUNT(1)
						FROM IMOV
						WHERE LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
						  AND LTRIM(RTRIM(CNSMOV)) IN (
								SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
								FROM OPENJSON(@ITEMS_JSON) j
						  )
						  AND COALESCE(CONTABILIZADA, 0) = 0;

						IF @COUNT_PEND > 0
						BEGIN
							SELECT
								'KO' AS OK,
								N'ERROR, Los movimientos se marcaron pero no se contabilizaron. Verifique que SPK_CONTAB_MASIVA esté actualizado (no debe filtrar por FECHACONF) y revise SPK_NC_CONTAB_INV.' AS ERROR,
								@COUNT_PEND AS PENDIENTES;
							RETURN;
						END

						SELECT @COUNT_PEND = COUNT(1)
						FROM IMOV
						WHERE LTRIM(RTRIM(IDBODEGA)) = LTRIM(RTRIM(@REFERENCIA2))
						  AND LTRIM(RTRIM(CNSMOV)) IN (
								SELECT LTRIM(RTRIM(CAST(j.value AS VARCHAR(50))))
								FROM OPENJSON(@ITEMS_JSON) j
						  )
						  AND COALESCE(CONTABILIZADA, 0) <> 0;

						SELECT
							'OK' AS OK,
							CONCAT(@PROCEDENCIA, N' enviada a contabilidad correctamente') AS MENSAJE,
							@COUNT_PEND AS PROCESADOS;
						RETURN;
					END

					SELECT 'OK' AS OK,	CONCAT(@PROCEDENCIA, ' enviada a contabilidad correctamente') AS MENSAJE;
					RETURN;
				END TRY
				BEGIN CATCH
					SELECT
						'KO' AS OK,
						CONCAT('Error en SPK_CONTAB_MASIVA: ', ERROR_MESSAGE()) AS ERROR,
						ERROR_PROCEDURE() AS ERROR_PROCEDURE,
						ERROR_LINE() AS ERROR_LINE,
						CONCAT(
							'PROCEDENCIA=', COALESCE(@PROCEDENCIA,''),
							' | ANO=', COALESCE(CONVERT(VARCHAR(10),@ANO),''),
							' | MES=', COALESCE(CONVERT(VARCHAR(10),@MES),''),
							' | USUARIO=', COALESCE(@USUARIO,''),
							' | NROCOMPROBANTE=', COALESCE(@NROCOMPROBANTE,'<NULL>'),
							' | REFERENCIA2=', COALESCE(@REFERENCIA2,'<NULL>'),
							' | ITEMS=', COALESCE(LEFT(CONVERT(NVARCHAR(MAX),@ITEMS_JSON), 400), '')
						) AS PARAMETROS_USADOS;
					RETURN;
				END CATCH
		END
		--ENVIAR A CONTABILIDAD DEPRECIACION ACTIVOS
		IF @METODO = 'DEPRECIACION_ACTIVOS_LISTA'
		BEGIN
			BEGIN TRY
				-- Extraer par?metros del JSON
				SELECT 
					@ANO = ANO,
					@MES = MES
				FROM OPENJSON(@PARAMETROS)
				WITH (
					ANO VARCHAR(4) '$.ANO',
					MES VARCHAR(2) '$.MES'
				);

				IF @ANO IS NULL OR @MES IS NULL
				BEGIN
					SELECT 'KO' AS OK, 'Par?metros ANO y MES son obligatorios' AS ERROR;
					RETURN;
				END;

				-- Convertir mes a entero
				SET @MES_INT = TRY_CAST(@MES AS INT);

				IF @MES_INT IS NULL OR @MES_INT NOT BETWEEN 1 AND 12
				BEGIN
					SELECT 'KO' AS OK, 'El MES debe ser un n?mero entre 1 y 12' AS ERROR;
					RETURN;
				END;

				-- Obtener compa??a del usuario
				SELECT @COMPANIA = u.COMPANIA
				FROM USUSU u
				WHERE u.USUARIO = @USUARIO;

				IF @COMPANIA IS NULL
				BEGIN
					SELECT 'KO' AS OK, 'Usuario sin compa??a asignada' AS ERROR;
					RETURN;
				END; 
				SELECT
					IACTD.IDACTIVO,
					IACTD.ITEM,
					IACTD.FECHA AS FECHACOMPRA,
					IACT.IDTIPOACTIVO,
					IACT.DESCRIPCION,
					CAST(COALESCE(IACT.DEPACUMHISTORICA, 0) AS FLOAT) AS DEPACUMHISTORICA_ACTIVO,
					CAST(COALESCE(IACT.DEPACUMDIFERIDA, 0) AS FLOAT) AS DEPACUMDIFERIDA_ACTIVO,
					CAST(COALESCE(IACT.MESESADEPRECIAR, 0) AS INT) AS MESESADEPRECIAR_ACTIVO,
					CAST(COALESCE(IACT.MESESDEPRECIADOS, 0) AS INT) AS MESESDEPRECIADOS,
					CAST(
					  COALESCE(IACT.MESESADEPRECIAR, 0) - COALESCE(IACT.MESESDEPRECIADOS, 0) AS INT
					) AS MESES_PENDIENTES_ACTIVO,
					CAST(COALESCE(IACTD.VALORDEPRECIADO, 0) AS FLOAT) AS VALORDEPRECIADO,
					CAST(COALESCE(IACT.PRECIOCOMERCIAL, 0) AS FLOAT) AS PRECIOCOMERCIAL,
					CAST(COALESCE(IACTD.DEPACUMHISTORICA, 0) AS FLOAT) AS DEPACUMHISTORICA,
					CAST(COALESCE(IACTD.DEPACUMDIFERIDA, 0) AS FLOAT) AS DEPACUMDIFERIDA,
					CAST(COALESCE(IACTD.AJUSTEACUMULADO, 0) AS FLOAT) AS AJUSTEACUMULADO,
					IACTD.CUENTA,
					CAST(COALESCE(IACTD.CONTABILIZADA, 0) AS BIT) AS CONTABILIZADA,
					IACTD.FECHA,
					IACTD.NROCOMPROBANTE
				FROM IACTD
				LEFT JOIN IACT ON IACTD.IDACTIVO = IACT.IDACTIVO
				WHERE IACTD.FECHA IS NOT NULL
				  AND YEAR(IACTD.FECHA) = CAST(@ANO AS INT)
				  AND MONTH(IACTD.FECHA) = @MES_INT
				ORDER BY IACTD.ITEM ASC;

			END TRY
			BEGIN CATCH
				SELECT 
					'KO' AS OK,
					'Error al obtener depreciaciones: ' + ERROR_MESSAGE() AS ERROR,
					ERROR_LINE() AS LINEA_ERROR;
			END CATCH;
		END;
		IF @METODO = 'DEPR_ACFIJP_ENV_CONTA'
		BEGIN
			BEGIN TRY 
				SELECT 
					@ANO = ANO,
					@MES = MES
				FROM OPENJSON(@PARAMETROS)
				WITH (
					ANO VARCHAR(4) '$.ANO',
					MES VARCHAR(2) '$.MES'
					
				);
				PRINT CONCAT (@ANO, @MES)
	
				IF @ANO IS NULL OR @MES IS NULL
				BEGIN
					SELECT 'KO' AS OK, 'Par?metros ANO y MES son obligatorios' AS ERROR;
					RETURN;
				END
				SET @MES_INT = TRY_CAST(@MES AS INT)
				SELECT @COMPANIA = COMPANIA,@IDSEDE=IDSEDE,@SYS_COMPUTE=SYS_COMPUTERNAME FROM USUSU WHERE USUARIO= @USUARIO

				-- Validar variable IDCON_TCOM_DEPR (comprobante de depreciaci?n)
				IF (SELECT  COALESCE(DATO, '') FROM USVGS WHERE IDVARIABLE = 'IDCON_TCOM_DEPR') = ''
				BEGIN
					SELECT 'KO' AS OK, 'No se encuentra configurada la variable para comprobante de depreciaci?n (IDCON_TCOM_DEPR), por favor comun?quese con el ?rea de sistema' AS ERROR;
					RETURN;
				END;

				-- Validaci?n 1 (Clarion): IACT con compra reciente sin ning?n IACTD
				IF  EXISTS (SELECT 1 FROM IACT WHERE NOT EXISTS (SELECT 1 FROM IACTD d WHERE d.IDACTIVO = IACT.IDACTIVO) AND IACT.FECHACOMPRA >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)))
				BEGIN
					SELECT 'KO' AS OK,
						   'Existen Activos Fijos comprados en los ?ltimos meses a los que no se les ha generado depreciaci?n. No se puede continuar.' AS ERROR;
					RETURN;
				END;

				-- Validaci?n 2 (Clarion): MESESADEPRECIAR vs cantidad de l?neas LOCAL en IACTD
				SELECT @INCONSISTENCIAS = COUNT(*) 
				FROM IACT i
				LEFT JOIN (	SELECT d.IDACTIVO,COUNT(*) AS TOTAL_DEPR
							FROM IACTD d
							WHERE d.CLASE = 'LOCAL'  
							GROUP BY d.IDACTIVO
							) d ON d.IDACTIVO = i.IDACTIVO
				WHERE 
				(COALESCE(i.MESESADEPRECIAR, 0) - 1) > COALESCE(d.TOTAL_DEPR, 0)
				AND i.FECHACOMPRA >= DATEADD(DAY, -360, CAST(GETDATE() AS DATE));
				IF @INCONSISTENCIAS > 0
				BEGIN
					SELECT 'KO' AS OK,
						   'Existen inconsistencias entre los meses a depreciar y el listado de depreciaci?n. No se puede continuar.' AS ERROR;
					RETURN;
				END;
								
				SELECT @COUNT_PEND = COUNT(*)	FROM IACTD	WHERE YEAR(FECHA) = CAST(@ANO AS INT)  AND MONTH(FECHA) = @MES_INT AND COALESCE(CONTABILIZADA, 0) = 0
					  AND UPPER(LTRIM(RTRIM(COALESCE(CLASE, '')))) <> 'NIIF';
				
				IF @COUNT_PEND = 0
				BEGIN
					SELECT 'KO' AS OK, 'No hay Activos que Depreciar en este Periodo' AS ERROR;
					RETURN;
				END
				ELSE
				BEGIN
					-- IDCON_TCOM_DEPR ya validado; ejecutar SP seg?n TIPO (mismo orden de par?metros que Clarion)
					EXEC SPK_APL_AJDEPRECIACION @COMPANIA, @IDSEDE, @ANO, @MES_INT, @USUARIO, @SYS_COMPUTE;
				END
				SELECT 'OK' AS OK ,'SE HA ENVIADO LA DEPRECIACI?N A CONTABILIDAD.' AS MENSAJE,
					   @ANO AS ANO,
					   @MES AS MES
				RETURN

			END TRY
			BEGIN CATCH
				SELECT 
					'KO' AS OK,
					'Error al enviar depreciaci?n a contabilidad: ' + ERROR_MESSAGE() AS ERROR,
					ERROR_LINE() AS LINEA_ERROR;
			END CATCH;
		END
		IF @METODO = 'RESET_CONTABILIZADO'
		BEGIN
			DECLARE @RC_RESET INT = 0;

			SELECT
				@ANO = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE') AS INT),
				@MES = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MESCONTABLE') AS INT),
				@CNSFCXPXC = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.CNS'))), ''),
				@PROCEDENCIA = JSON_VALUE(@PARAMETROS, '$.PROCEDENCIA');

			SELECT @COMPANIA = COALESCE(COMPANIA, HOST_NAME()) FROM USUSU WHERE USUARIO = @USUARIO;
			IF @COMPANIA IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Usuario no encontrado o sin compa??a' AS ERROR;
				RETURN;
			END

			IF @PROCEDENCIA = 'CXC'
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM FPAG WHERE YEAR(FECHA)=@ANO AND MONTH(FECHA)=@MES AND CNSFPAG=@CNSFCXPXC AND CONTABILIZADO=1)
				BEGIN
					SELECT 'KO' AS OK, 'No se encuentra este items contabilizado' AS ERROR;
					RETURN;
				END
				ELSE			
				BEGIN
					UPDATE FPAG
					SET CONTABILIZADO = 0,
						MARCACONT = 0
					WHERE COMPANIA = @COMPANIA
					  AND CNSFPAG =@CNSFCXPXC
					  AND (@ANO IS NULL OR YEAR(FECHA) = @ANO)
					  AND (@MES IS NULL OR MONTH(FECHA) = @MES);

					SET @RC_RESET = @@ROWCOUNT;
				END
			END

			IF @PROCEDENCIA = 'CXP'
			BEGIN
				SELECT @ANO,@MES,@CNSFCXPXC 
				IF NOT EXISTS (SELECT 1 FROM FCXP WHERE YEAR(FECHA)=@ANO AND MONTH(FECHA)=@MES AND CNSFCXP=@CNSFCXPXC AND CONTABILIZADA=1)
				BEGIN
					SELECT 'KO' AS OK, 'No se encuentra este items contabilizado' AS ERROR;
					RETURN;
				END
				ELSE
				BEGIN
					UPDATE FCXP
					SET CONTABILIZADA = 0,
						MARCACONT = 0
					WHERE COMPANIA = @COMPANIA
					  AND CNSFCXP =@CNSFCXPXC
					  AND (@ANO IS NULL OR YEAR(FECHA) = @ANO)
					  AND (@MES IS NULL OR MONTH(FECHA) = @MES);
					SET @RC_RESET = @@ROWCOUNT;
				END
			END

			IF @RC_RESET = 0
			BEGIN
				SELECT 'KO' AS OK,
					'Error al actualizar recaudo (FPAG).' AS ERROR;
				RETURN;
			END
			SELECT 'OK' AS OK,CONCAT('desmarcado (CONTABILIZADO=0, MARCACONT=0). Registros actualizados: ', @RC_RESET) AS MENSAJE;
			RETURN
		END
		IF @METODO = 'DEPR_IACTD_UNICO'
		BEGIN
			DECLARE @IDACTIVO VARCHAR(20), @ITEM_JSON INT;

			SELECT
			@ANO = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ANOCONTABLE') AS INT),
			@MES = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.MESCONTABLE') AS INT),
			@IDACTIVO = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.IDACTIVO')), ''),
			@ITEM_JSON = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ITEM') AS INT);

			IF @ANO IS NULL OR @MES IS NULL OR @MES NOT BETWEEN 1 AND 12
			BEGIN
				SELECT 'KO' AS OK, 'Par?metros ANOCONTABLE / MESCONTABLE inv?lidos' AS ERROR;
				RETURN
			END
			IF @IDACTIVO IS NULL OR @ITEM_JSON IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Debe enviar IDACTIVO e ITEM' AS ERROR;
				RETURN
			END

			-- Ajustar seg?n su SPQ (USUSU, variables de sede y compa??a):
			SELECT 
				@IDSEDE = COALESCE(IDSEDE, HOST_NAME()), 
				@COMPANIA = COALESCE(COMPANIA, HOST_NAME()),
				@SYS_COMPUTE = COALESCE(SYS_COMPUTERNAME, HOST_NAME()) 
			FROM USUSU WHERE USUARIO = @USUARIO;
			
			IF EXISTS (SELECT 1 FROM IACTD WHERE YEAR(FECHA)=@ANO AND MONTH(FECHA)=@MES AND IDACTIVO= @IDACTIVO AND ITEM = @ITEM_JSON AND COALESCE(CONTABILIZADA,0)=0 AND MARCACONT=0)
			BEGIN
				UPDATE IACTD
				SET MARCACONT=1
				WHERE YEAR(FECHA)=@ANO AND MONTH(FECHA)=@MES AND IDACTIVO= @IDACTIVO AND ITEM = @ITEM_JSON AND COALESCE(CONTABILIZADA,0)=0 AND MARCACONT=0;
			END
			
			
			BEGIN TRY
			EXEC DBO.SPK_APL_AJDEPRECIACION_UNA_IACTD @COMPANIA,@IDSEDE,@ANO,@MES,@USUARIO,@SYS_COMPUTE,@IDACTIVO,@ITEM_JSON;

			SELECT 'OK' AS OK,
					'Depreciaci?n enviada (una l?nea IACTD, MARCACONT=1).' AS MENSAJE,
					CAST(@ANO AS VARCHAR(4)) AS ANOCONTABLE,
					CAST(@MES AS VARCHAR(2)) AS MESCONTABLE;
			END TRY
			BEGIN CATCH
			SELECT N'KO' AS OK, ERROR_MESSAGE() AS ERROR;
			END CATCH;
			RETURN;
		END;
		IF @METODO = 'CONF_EXOGENA'
		BEGIN
			DECLARE @ERRORES TABLE(ERROR NVARCHAR(4000));

			SELECT
				@TABLA = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PARAMETROS, '$.TABLA'))), ''),
				@PROCESO = UPPER(LTRIM(RTRIM(COALESCE(
					JSON_VALUE(@PARAMETROS, '$.PROCESO'),
					JSON_VALUE(@PARAMETROS, '$.REGISTRO.PROCESO')
				)))),
				@ITEMS_JSON = JSON_QUERY(@PARAMETROS, '$.REGISTRO');

			IF @TABLA IS NULL OR @PROCESO IS NULL OR @ITEMS_JSON IS NULL
			BEGIN
				SELECT 'KO' AS OK, 'Par?metros inv?lidos: TABLA, PROCESO o REGISTRO faltantes' AS ERROR;
				RETURN;
			END;

			IF UPPER(@TABLA) = 'EXOFMT'
			BEGIN
				SELECT
					@IDFORMATO = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO'),
					@DESCRIPCION = JSON_VALUE(@ITEMS_JSON, '$.DESCRIPCION'),
					@ESTADO = JSON_VALUE(@ITEMS_JSON, '$.ESTADO'),
					@HOJAEXP = JSON_VALUE(@ITEMS_JSON, '$.HOJAEXP'),
					@IDFORMATO_OLD = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO_OLD');

				IF @PROCESO = 'INSERTAR'
				BEGIN
					IF EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO)
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe un registro con ese IDFORMATO' AS ERROR;
						RETURN;
					END;

					INSERT INTO EXOFMT(IDFORMATO, DESCRIPCION, ESTADO, HOJAEXP)
					VALUES (@IDFORMATO, @DESCRIPCION, @ESTADO, NULLIF(@HOJAEXP, ''));

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'EDITAR'
				BEGIN
					IF @IDFORMATO_OLD IS NULL SET @IDFORMATO_OLD = @IDFORMATO;

					IF NOT EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO_OLD)
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para actualizar' AS ERROR;
						RETURN;
					END;

					IF @IDFORMATO <> @IDFORMATO_OLD
					   AND EXISTS (SELECT 1 FROM EXOFMT WHERE IDFORMATO = @IDFORMATO)
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe un registro con ese nuevo IDFORMATO' AS ERROR;
						RETURN;
					END;

					UPDATE EXOFMT
					SET IDFORMATO = @IDFORMATO,
						DESCRIPCION = @DESCRIPCION,
						ESTADO = @ESTADO,
						HOJAEXP = NULLIF(@HOJAEXP, '')
					WHERE IDFORMATO = @IDFORMATO_OLD;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se pudo actualizar el registro' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'ELIMINAR'
				BEGIN
					IF EXISTS (SELECT 1 FROM EXOFMTD WHERE IDFORMATO = @IDFORMATO)
					BEGIN
						SELECT 'KO' AS OK, 'No se puede eliminar el formato porque tiene conceptos asociados' AS ERROR;
						RETURN;
					END;

					DELETE FROM EXOFMT WHERE IDFORMATO = @IDFORMATO;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para eliminar' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				SELECT 'KO' AS OK, CONCAT('Proceso no reconocido: ', @PROCESO) AS ERROR;
				RETURN;
			END;

			IF UPPER(@TABLA) = 'EXOFMTD'
			BEGIN
				SELECT
					@CODCONCEPTO = JSON_VALUE(@ITEMS_JSON, '$.CODCONCEPTO'),
					@IDFORMATO = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO'),
					@DESCRIPCION = JSON_VALUE(@ITEMS_JSON, '$.DESCRIPCION'),
					@CUENTAINI = JSON_VALUE(@ITEMS_JSON, '$.CUENTAINI'),
					@CUENTAFIN = JSON_VALUE(@ITEMS_JSON, '$.CUENTAFIN'),
					@MTERCERO = JSON_VALUE(@ITEMS_JSON, '$.MTERCERO'),
					@NTZ = JSON_VALUE(@ITEMS_JSON, '$.NTZ'),
					@MOTOMIN = CASE
						WHEN JSON_VALUE(@ITEMS_JSON, '$.MOTOMIN') IS NULL
						  OR LEN(LTRIM(RTRIM(JSON_VALUE(@ITEMS_JSON, '$.MOTOMIN')))) = 0
						THEN NULL
						ELSE CAST(JSON_VALUE(@ITEMS_JSON, '$.MOTOMIN') AS DECIMAL(18,2))
					END,
					@ESTADO = JSON_VALUE(@ITEMS_JSON, '$.ESTADO'),
					@CODCONCEPTO_OLD = JSON_VALUE(@ITEMS_JSON, '$.CODCONCEPTO_OLD'),
					@IDFORMATO_OLD = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO_OLD');


				IF @PROCESO = 'INSERTAR'
				BEGIN
					IF EXISTS (
						SELECT 1 FROM EXOFMTD
						WHERE CODCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO
					)
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe un concepto con ese CODCONCEPTO para ese formato' AS ERROR;
						RETURN;
					END;

					INSERT INTO EXOFMTD(CODCONCEPTO, IDFORMATO, DESCRIPCION, CUENTAINI, CUENTAFIN, MTERCERO, NTZ, MOTOMIN, ESTADO)
					VALUES (
						@CODCONCEPTO, @IDFORMATO, @DESCRIPCION,
						NULLIF(@CUENTAINI, ''), NULLIF(@CUENTAFIN, ''),
						NULLIF(@MTERCERO, ''), NULLIF(@NTZ, ''), @MOTOMIN,
						@ESTADO
					);

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'EDITAR'
				BEGIN
					IF @CODCONCEPTO_OLD IS NULL SET @CODCONCEPTO_OLD = @CODCONCEPTO;
					IF @IDFORMATO_OLD IS NULL SET @IDFORMATO_OLD = @IDFORMATO;

					IF NOT EXISTS (
						SELECT 1 FROM EXOFMTD
						WHERE CODCONCEPTO = @CODCONCEPTO_OLD AND IDFORMATO = @IDFORMATO_OLD
					)
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para actualizar' AS ERROR;
						RETURN;
					END;

					IF (@CODCONCEPTO <> @CODCONCEPTO_OLD OR @IDFORMATO <> @IDFORMATO_OLD)
					   AND EXISTS (
							SELECT 1 FROM EXOFMTD
							WHERE CODCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO
					   )
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe un concepto con ese CODCONCEPTO para ese formato' AS ERROR;
						RETURN;
					END;

					UPDATE EXOFMTD
					SET CODCONCEPTO = @CODCONCEPTO,
						IDFORMATO = @IDFORMATO,
						DESCRIPCION = @DESCRIPCION,
						CUENTAINI = NULLIF(@CUENTAINI, ''),
						CUENTAFIN = NULLIF(@CUENTAFIN, ''),
						MTERCERO = NULLIF(@MTERCERO, ''),
						NTZ = NULLIF(@NTZ, ''),
						MOTOMIN = @MOTOMIN,
						ESTADO = @ESTADO
					WHERE CODCONCEPTO = @CODCONCEPTO_OLD
					  AND IDFORMATO = @IDFORMATO_OLD;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se pudo actualizar el registro' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'ELIMINAR'
				BEGIN
					IF EXISTS (
						SELECT 1 FROM EXOFMTDD
						WHERE IDCONCEPTO = @CODCONCEPTO AND IDFORMATO = @IDFORMATO
					)
					BEGIN
						SELECT 'KO' AS OK, 'No se puede eliminar el concepto porque tiene detalle de campos asociados' AS ERROR;
						RETURN;
					END;

					DELETE FROM EXOFMTD
					WHERE CODCONCEPTO = @CODCONCEPTO
					  AND IDFORMATO = @IDFORMATO;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para eliminar' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				SELECT 'KO' AS OK, CONCAT('Proceso no reconocido: ', @PROCESO) AS ERROR;
				RETURN;
			END;

			IF UPPER(@TABLA) = 'EXOFMTDD'
			BEGIN
				SELECT
					@CAMPO = JSON_VALUE(@ITEMS_JSON, '$.CAMPO'),
					@CODCONCEPTO = JSON_VALUE(@ITEMS_JSON, '$.IDCONCEPTO'),
					@IDFORMATO = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO'),
					@CUENTAINI = JSON_VALUE(@ITEMS_JSON, '$.CUENTAINI'),
					@CUENTAFIN = JSON_VALUE(@ITEMS_JSON, '$.CUENTAFIN'),
					@ESTADO = JSON_VALUE(@ITEMS_JSON, '$.ESTADO'),
					@MSF = JSON_VALUE(@ITEMS_JSON, '$.MSF'),
					@TIPOE = JSON_VALUE(@ITEMS_JSON, '$.TIPOE'),
					@CAMPO_OLD = JSON_VALUE(@ITEMS_JSON, '$.CAMPO_OLD'),
					@CODCONCEPTO_OLD = JSON_VALUE(@ITEMS_JSON, '$.IDCONCEPTO_OLD'),
					@IDFORMATO_OLD = JSON_VALUE(@ITEMS_JSON, '$.IDFORMATO_OLD');

				

				IF UPPER(TRIM(@TIPOE)) = 'Incluye'
				BEGIN
					SET @CUENTAINI = NULL;
					SET @CUENTAFIN = NULL;
				END;

				IF @PROCESO = 'INSERTAR'
				BEGIN
					INSERT INTO EXOFMTDD(CAMPO, IDCONCEPTO, IDFORMATO, CUENTAINI, CUENTAFIN, ESTADO, MSF, TIPOE)
					VALUES (
						@CAMPO, @CODCONCEPTO, @IDFORMATO,
						NULLIF(@CUENTAINI, ''), NULLIF(@CUENTAFIN, ''),
						@ESTADO, NULLIF(@MSF, ''), @TIPOE
					);

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'EDITAR'
				BEGIN
					IF @CAMPO_OLD IS NULL SET @CAMPO_OLD = @CAMPO;
					IF @CODCONCEPTO_OLD IS NULL SET @CODCONCEPTO_OLD = @CODCONCEPTO;
					IF @IDFORMATO_OLD IS NULL SET @IDFORMATO_OLD = @IDFORMATO;

					IF NOT EXISTS (
						SELECT 1 FROM EXOFMTDD
						WHERE CAMPO = @CAMPO_OLD
						  AND IDCONCEPTO = @CODCONCEPTO_OLD
						  AND IDFORMATO = @IDFORMATO_OLD
					)
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para actualizar' AS ERROR;
						RETURN;
					END;

					IF (@CAMPO <> @CAMPO_OLD
					 OR @CODCONCEPTO <> @CODCONCEPTO_OLD
					 OR @IDFORMATO <> @IDFORMATO_OLD)
					   AND EXISTS (
							SELECT 1 FROM EXOFMTDD
							WHERE CAMPO = @CAMPO
							  AND IDCONCEPTO = @CODCONCEPTO
							  AND IDFORMATO = @IDFORMATO
					   )
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe un detalle con esos valores para ese concepto y formato' AS ERROR;
						RETURN;
					END;

					UPDATE EXOFMTDD
					SET CAMPO = @CAMPO,
						IDCONCEPTO = @CODCONCEPTO,
						IDFORMATO = @IDFORMATO,
						CUENTAINI = NULLIF(@CUENTAINI, ''),
						CUENTAFIN = NULLIF(@CUENTAFIN, ''),
						ESTADO = @ESTADO,
						MSF = NULLIF(@MSF, ''),
						TIPOE = @TIPOE
					WHERE CAMPO = @CAMPO_OLD
					  AND IDCONCEPTO = @CODCONCEPTO_OLD
					  AND IDFORMATO = @IDFORMATO_OLD;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se pudo actualizar el registro' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'ELIMINAR'
				BEGIN
					IF EXISTS (
						SELECT 1 FROM TGEN
						WHERE TABLA = @CODCONCEPTO
						  AND CAMPO = @CAMPO
					)
					BEGIN
						SELECT 'KO' AS OK, 'No se puede eliminar el detalle porque tiene cuentas asociadas en TGEN' AS ERROR;
						RETURN;
					END;

					DELETE FROM EXOFMTDD
					WHERE CAMPO = @CAMPO
					  AND IDCONCEPTO = @CODCONCEPTO
					  AND IDFORMATO = @IDFORMATO;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para eliminar' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				SELECT 'KO' AS OK, CONCAT('Proceso no reconocido: ', @PROCESO) AS ERROR;
				RETURN;
			END;

			IF UPPER(@TABLA) = 'TGEN'
			BEGIN
				SELECT
					@CODCONCEPTO = JSON_VALUE(@ITEMS_JSON, '$.TABLA'),
					@CAMPO = JSON_VALUE(@ITEMS_JSON, '$.CAMPO'),
					@CODIGO = JSON_VALUE(@ITEMS_JSON, '$.CODIGO'),
					@DESCRIPCION = JSON_VALUE(@ITEMS_JSON, '$.DESCRIPCION'),
					@VALOR1 = JSON_VALUE(@ITEMS_JSON, '$.VALOR1'),
					@CODIGO_OLD = JSON_VALUE(@ITEMS_JSON, '$.CODIGO_OLD'),
					@CODCONCEPTO_OLD = JSON_VALUE(@ITEMS_JSON, '$.TABLA_OLD'),
					@CAMPO_OLD = JSON_VALUE(@ITEMS_JSON, '$.CAMPO_OLD');

				
				IF @PROCESO = 'ELIMINAR'
				BEGIN
					IF @CODIGO IS NULL OR LEN(LTRIM(RTRIM(@CODIGO))) = 0
						INSERT INTO @ERRORES(ERROR) VALUES('CODIGO (cuenta) es requerido');
				END;

				IF EXISTS (SELECT 1 FROM @ERRORES)
				BEGIN
					SELECT 'KO' AS OK;
					SELECT ERROR FROM @ERRORES ORDER BY ERROR;
					RETURN;
				END;

				IF @DESCRIPCION IS NULL OR LEN(LTRIM(RTRIM(@DESCRIPCION))) = 0
				BEGIN
					SELECT @DESCRIPCION = NOMCUENTA
					FROM CUE
					WHERE CUENTA = @CODIGO;
				END;

				IF @PROCESO = 'INSERTAR'
				BEGIN
					IF EXISTS (
						SELECT 1 FROM TGEN
						WHERE TABLA = @CODCONCEPTO
						  AND CAMPO = @CAMPO
						  AND CODIGO = @CODIGO
					)
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe una cuenta asociada con ese c?digo para el campo indicado' AS ERROR;
						RETURN;
					END;

					INSERT INTO TGEN(TABLA, CAMPO, CODIGO, DESCRIPCION, VALOR1)
					VALUES (
						@CODCONCEPTO, @CAMPO, @CODIGO,
						@DESCRIPCION, NULLIF(@VALOR1, '')
					);

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'EDITAR'
				BEGIN
					IF @CODIGO_OLD IS NULL SET @CODIGO_OLD = @CODIGO;
					IF @CODCONCEPTO_OLD IS NULL SET @CODCONCEPTO_OLD = @CODCONCEPTO;
					IF @CAMPO_OLD IS NULL SET @CAMPO_OLD = @CAMPO;

					IF NOT EXISTS (
						SELECT 1 FROM TGEN
						WHERE TABLA = @CODCONCEPTO_OLD
						  AND CAMPO = @CAMPO_OLD
						  AND CODIGO = @CODIGO_OLD
					)
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para actualizar' AS ERROR;
						RETURN;
					END;

					IF (@CODIGO <> @CODIGO_OLD
					 OR @CODCONCEPTO <> @CODCONCEPTO_OLD
					 OR @CAMPO <> @CAMPO_OLD)
					   AND EXISTS (
							SELECT 1 FROM TGEN
							WHERE TABLA = @CODCONCEPTO
							  AND CAMPO = @CAMPO
							  AND CODIGO = @CODIGO
					   )
					BEGIN
						SELECT 'KO' AS OK, 'Ya existe una cuenta asociada con ese c?digo para el campo indicado' AS ERROR;
						RETURN;
					END;

					UPDATE TGEN
					SET TABLA = @CODCONCEPTO,
						CAMPO = @CAMPO,
						CODIGO = @CODIGO,
						DESCRIPCION = @DESCRIPCION,
						VALOR1 = NULLIF(@VALOR1, '')
					WHERE TABLA = @CODCONCEPTO_OLD
					  AND CAMPO = @CAMPO_OLD
					  AND CODIGO = @CODIGO_OLD;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se pudo actualizar el registro' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				IF @PROCESO = 'ELIMINAR'
				BEGIN
					DELETE FROM TGEN
					WHERE TABLA = @CODCONCEPTO
					  AND CAMPO = @CAMPO
					  AND CODIGO = @CODIGO;

					IF @@ROWCOUNT = 0
					BEGIN
						SELECT 'KO' AS OK, 'No se encontr? el registro para eliminar' AS ERROR;
						RETURN;
					END;

					SELECT 'OK' AS OK;
					RETURN;
				END;

				SELECT 'KO' AS OK, CONCAT('Proceso no reconocido: ', @PROCESO) AS ERROR;
				RETURN;
			END;

			SELECT 'KO' AS OK, CONCAT('Tabla no reconocida: ', @TABLA) AS ERROR;
			RETURN;
		END;
    END TRY
    BEGIN CATCH
        SELECT 
            'RESULTADO' AS TIPO_RESULTADO,
            'KO' AS OK,
            'Error: ' + ERROR_MESSAGE() AS MENSAJE,
            ERROR_LINE() AS LINEA,
            ERROR_PROCEDURE() AS PROCEDIMIENTO;
    END CATCH;
END

