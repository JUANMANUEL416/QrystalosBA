CREATE OR ALTER PROCEDURE DBO.SPK_PAGOSCXC    
    @CNSFPAG          VARCHAR(20),    -- Consecutivo del pago a procesar
    @SEDE             VARCHAR(5),     -- Sede de la operaci~n
    @COMPANIA         VARCHAR(2),     -- Compa~~a asociada
    @USUARIO          VARCHAR(12),    -- Usuario que ejecuta
    @SYS_COMPUTERNAME VARCHAR(254)    -- Nombre del equipo desde donde se ejecuta
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================================================
    -- DECLARACI~N DE VARIABLES ORGANIZADAS POR PROP~SITO
    -- =============================================================================
    
    -- Variables de contexto y configuraci~n
    DECLARE @IDDEP              VARCHAR(20),
            @HOY                DATETIME = CONVERT(SMALLDATETIME, GETDATE()),
            @TRAN_NAME          VARCHAR(50) = 'TRN_PAGOSCXC_' + @CNSFPAG,
            @ERROR_MSG          VARCHAR(MAX),
            @ROLLBACK_REQUIRED  BIT = 0;

    -- Variables de datos del pago (FPAG)
    DECLARE @IDTERCERO          VARCHAR(20),
            @INGRESO            VARCHAR(10),
            @FECHAPAGO          DATETIME,
            @NOCONTABILIZA      SMALLINT,
            @NROCOMPROBANTE     VARCHAR(20),
            @BANCO              VARCHAR(3),
            @CNSFACJ            VARCHAR(20),
            @CODCAJA            VARCHAR(4),
            @SUCURSAL           VARCHAR(2),
            @CTA_BCO            VARCHAR(40),
            @ITEM_BMOVD         INT,
            @RENGLON            INT,
            @FINDEVO            TINYINT;

    -- Variables de procesamiento de detalles (FPAGD)
    DECLARE @CNSCXC             VARCHAR(20),
            @N_FACTURA          VARCHAR(16),
            @ITEM               SMALLINT,
            @VLRPAGOS           DECIMAL(14,2),
            @VLRIMPUESTO        DECIMAL(14,2),
            @VLRGLOSAS          DECIMAL(14,2),
            @VLRDTOFIN          DECIMAL(14,2),
            @VLREXTRA           DECIMAL(14,2),
            @TIPOGLOSA          VARCHAR(1),
            @SINPAGO            SMALLINT,
            @CLASE              VARCHAR(1),
            @CNSGLO             VARCHAR(20),
            @OBSERVACIONG       VARCHAR(MAX),
            @LEVANTADO          BIT,
            @SALDONETO          DECIMAL(14,2),
            @MOTIVO1            VARCHAR(20),
            @MOTIVO2            VARCHAR(20);

    -- Variables de glosas y consecutivos
    DECLARE @NVOCONSEC          VARCHAR(20),
            @CNSGLOI            VARCHAR(20),
            @PORGLO             DECIMAL(14,6),
            @PORPAG             DECIMAL(14,6),
            @ENFTR              INT,
            @M1_NORM            VARCHAR(20),
            @M2_NORM            VARCHAR(20),
            @OBS_FGLOCG         VARCHAR(1024),
            @M1_OK              BIT,
            @M2_OK              BIT,
            @VLR_M1             DECIMAL(14,2),
            @VLR_M2             DECIMAL(14,2);

    -- Variables de notas cr~dito/d~bito (DEVPAR)
    DECLARE @NVOCNSFNOT         VARCHAR(20),
            @NROCOMPROBANTEFNOT VARCHAR(20);

    -- Variables de CXP (cruce con proveedores)
    DECLARE @CNSFCXP            VARCHAR(20),
            @CNSFCXPP           VARCHAR(20),
            @FCXPP              VARCHAR(20),
            @VLRCRUCE           DECIMAL(14,2),
            @NOREFERENCIA       VARCHAR(20),
            @CUECREDITO         VARCHAR(16);

    -- Variables de presupuesto (opcionales)
    DECLARE @CONSECUTIVO        VARCHAR(20),
            @CCOSTOPRESUP       VARCHAR(20),
            @RECA               VARCHAR(20),
            @RECO               VARCHAR(20),
            @OBSERVACIONPTO     VARCHAR(1023),
            @RUBRO              VARCHAR(16),
            @RUBROANT           VARCHAR(16),
            @CNSPPTOFTR         VARCHAR(20),
            @ESTADOPPTO         VARCHAR(10),
            @FECHARECEP         DATETIME;

    -- Variables auxiliares de control
    DECLARE @AUX                DECIMAL(14,2),
            @PAGO               DECIMAL(14,2),
            @SALDOFACT          DECIMAL(14,2),
            @OBSERVACION        VARCHAR(255),
            @CNSFCT             VARCHAR(16),
            @FECHARAD           DATETIME,
            @VLRIMPUESTOS_FPAG   DECIMAL(14,2),
            @VLRIMPUESTOS_FPAGDI DECIMAL(14,2),
            @VLRIMPUESTOS_FPAGD  DECIMAL(14,2),
            @N_FACTURA_IMP       VARCHAR(16),
            @ITEM_IMP            SMALLINT,
            @VLRIMP_FPAGD        DECIMAL(14,2),
            @VLRIMP_FPAGDI       DECIMAL(14,2);

    -- =============================================================================
    -- INICIO DE TRANSACCI~N PRINCIPAL
    -- =============================================================================
    EXEC SPK_FPAG @CNSFPAG
    BEGIN TRY
        -- Validar que no haya transacci~n abierta previamente
        IF @@TRANCOUNT > 0
        BEGIN
            PRINT '?? Advertencia: SPK_PAGOSCXC llamado con @@TRANCOUNT=' + CAST(@@TRANCOUNT AS VARCHAR);
        END

     --   BEGIN TRANSACTION @TRAN_NAME;
        PRINT '? Transacci~n iniciada: ' + @TRAN_NAME + ' | CNSFPAG: ' + @CNSFPAG;

        -- =============================================================================
        -- VALIDACIONES INICIALES (antes de cualquier modificaci~n)
        -- =============================================================================
        
        SELECT @IDDEP = LEFT(DATO, 20) 
        FROM USVGS 
        WHERE IDVARIABLE = 'IDFDEPCARTERA';

        IF @IDDEP IS NULL
        BEGIN
            RAISERROR('No tiene configurado Departamento de Cartera', 16, 1);
            -- No hace rollback aqu~ porque no hemos iniciado modificaciones a~n
            RETURN -1;
        END
    
        -- Cargar datos principales del pago
        SELECT @IDTERCERO = IDTERCERO, 
               @INGRESO = INGRESO, 
               @FECHAPAGO = FECHAPAGO,
               @NOCONTABILIZA = NOCONTABILIZA, 
               @NROCOMPROBANTE = NROCOMPROBANTE,
               @BANCO = BANCO, 
               @CNSFACJ = CNSFACJ, 
               @CODCAJA = CODCAJA, 
               @SUCURSAL = SUCURSAL, 
               @CTA_BCO = CTA_BCO, 
               @ITEM_BMOVD = ITEM,
               @RENGLON = RENGLON,
               @FINDEVO = COALESCE(FINDEVOL, 0)         
        FROM FPAG 
        WHERE CNSFPAG = @CNSFPAG;

        IF @FECHAPAGO IS NULL
        BEGIN
            RAISERROR(N'No se encontr? el recaudo indicado (CNSFPAG).', 16, 1);
            RETURN -1;
        END

        -- Validaci?n: impuestos del recaudo (FPAG) vs desglose en FPAGDI
        SELECT @VLRIMPUESTOS_FPAG = COALESCE(VLRIMPUESTOS, 0)
        FROM FPAG
        WHERE CNSFPAG = @CNSFPAG;

        SELECT @VLRIMPUESTOS_FPAGDI = COALESCE(SUM(VLRIMPUESTO), 0)
        FROM FPAGDI
        WHERE CNSFPAG = @CNSFPAG;

        IF ABS(@VLRIMPUESTOS_FPAG - @VLRIMPUESTOS_FPAGDI) > 0.01
        BEGIN
            SET @ERROR_MSG = N'Los impuestos del recaudo (FPAG.VLRIMPUESTOS=' +
                             CAST(@VLRIMPUESTOS_FPAG AS VARCHAR(30)) +
                             N') no coinciden con el total del desglose en FPAGDI (' +
                             CAST(@VLRIMPUESTOS_FPAGDI AS VARCHAR(30)) +
                             N'). Verifique e intente de nuevo.';
            RAISERROR(@ERROR_MSG, 16, 1);
            RETURN -1;
        END

        -- Validaci?n: impuestos cabecera (FPAG) vs suma del detalle (FPAGD)
        SELECT @VLRIMPUESTOS_FPAGD = COALESCE(SUM(VLRIMPUESTO), 0)
        FROM FPAGD
        WHERE CNSFPAG = @CNSFPAG;

        IF ABS(@VLRIMPUESTOS_FPAG - @VLRIMPUESTOS_FPAGD) > 0.01
        BEGIN
            SET @ERROR_MSG = N'Los impuestos del recaudo (FPAG.VLRIMPUESTOS=' +
                             CAST(@VLRIMPUESTOS_FPAG AS VARCHAR(30)) +
                             N') no coinciden con la suma de impuestos en FPAGD (' +
                             CAST(@VLRIMPUESTOS_FPAGD AS VARCHAR(30)) +
                             N'). Verifique e intente de nuevo.';
            RAISERROR(@ERROR_MSG, 16, 1);
            RETURN -1;
        END

        -- Validaci?n: impuestos por factura (FPAGD) vs desglose en FPAGDI
        SET @N_FACTURA_IMP = NULL;
        SET @ITEM_IMP = NULL;

        SELECT TOP 1
            @N_FACTURA_IMP = D.N_FACTURA,
            @ITEM_IMP = D.ITEM,
            @VLRIMP_FPAGD = COALESCE(D.VLRIMPUESTO, 0),
            @VLRIMP_FPAGDI = COALESCE(I.TOTAL_IMP, 0)
        FROM FPAGD D
        LEFT JOIN (
            SELECT CNSFPAG, N_FACTURA, ITEM, SUM(COALESCE(VLRIMPUESTO, 0)) AS TOTAL_IMP
            FROM FPAGDI
            GROUP BY CNSFPAG, N_FACTURA, ITEM
        ) I ON D.CNSFPAG = I.CNSFPAG
           AND D.N_FACTURA = I.N_FACTURA
           AND D.ITEM = I.ITEM
        WHERE D.CNSFPAG = @CNSFPAG
          AND ABS(COALESCE(D.VLRIMPUESTO, 0) - COALESCE(I.TOTAL_IMP, 0)) > 0.01;

        IF @N_FACTURA_IMP IS NOT NULL
        BEGIN
            SET @ERROR_MSG = N'Los impuestos de la factura ' + @N_FACTURA_IMP +
                             N' (ITEM ' + CAST(@ITEM_IMP AS VARCHAR(10)) +
                             N') no coinciden: FPAGD.VLRIMPUESTO=' +
                             CAST(@VLRIMP_FPAGD AS VARCHAR(30)) +
                             N', total FPAGDI=' +
                             CAST(@VLRIMP_FPAGDI AS VARCHAR(30)) +
                             N'. Verifique e intente de nuevo.';
            RAISERROR(@ERROR_MSG, 16, 1);
            RETURN -1;
        END

        IF @INGRESO NOT IN ('GLOSAS', 'DEVOLUCION', 'DEVPAR')
        BEGIN
            IF EXISTS (SELECT 1 FROM FPAGD WHERE CNSFPAG = @CNSFPAG AND COALESCE(VLRGLOSA, 0) > 0)
            BEGIN
                RAISERROR('No se permiten glosas en un tipo de recaudo diferente a Glosas. Verifique e intente de nuevo.', 16, 1);
                RETURN -1;
            END
        END

        -- =============================================================================
        -- PROCESAMIENTO ESPECIAL: LEVANTAMIENTO DE GLOSAS
        -- =============================================================================
        IF @INGRESO = 'LEVANTA'
        BEGIN
            EXEC SPK_LEVANTA_GLOSA @CNSFPAG, @USUARIO, @SEDE, 'A';
            -- Este SP maneja su propia l~gica, salimos aqu~
            IF @@TRANCOUNT > 0 AND XACT_STATE() = 1
            BEGIN
               -- COMMIT TRANSACTION @TRAN_NAME;
                PRINT '? Transacci~n confirmada (LEVANTA): ' + @TRAN_NAME;
            END
            RETURN 0;
        END

        -- =============================================================================
        -- CURSOR PRINCIPAL: PROCESAMIENTO DE DETALLES DE PAGO (FPAGD)
        -- =============================================================================
        DECLARE PAGD_CURSOR CURSOR LOCAL FAST_FORWARD FOR    
        SELECT CNSCXC, N_FACTURA, ITEM, VALORPAGO, VLRIMPUESTO + VLRDTOFIN, VLRGLOSA, 
               TIPOGLOSA, SINPAGO, CLASE, CNSGLO, VLRDTOFIN, VLREXTRA, OBSERVACION, LEVANTADO,
               MOTIVO1, MOTIVO2
        FROM FPAGD    
        WHERE CNSFPAG = @CNSFPAG AND CERRADO = 0;
  
        OPEN PAGD_CURSOR;
        
        FETCH NEXT FROM PAGD_CURSOR INTO @CNSCXC, @N_FACTURA, @ITEM, @VLRPAGOS, @VLRIMPUESTO, @VLRGLOSAS, 
             @TIPOGLOSA, @SINPAGO, @CLASE, @CNSGLO, @VLRDTOFIN, @VLREXTRA, @OBSERVACIONG, @LEVANTADO,
             @MOTIVO1, @MOTIVO2;

        WHILE @@FETCH_STATUS = 0    
        BEGIN       
            -- Verificar estado de transacci~n en cada iteraci~n cr~tica
            IF XACT_STATE() = -1
            BEGIN
                RAISERROR('Transacci~n en estado irreversible. Abortando procesamiento.', 16, 1);
                BREAK;
            END

            PRINT '? Procesando: Factura=' + @N_FACTURA + ' | Item=' + CAST(@ITEM AS VARCHAR) + ' | Ingreso=' + @INGRESO;

            -- -------------------------------------------------------------------------
            -- CASO: DEVOLUCI~N TOTAL
            -- -------------------------------------------------------------------------
            IF @INGRESO = 'DEVOLUCION' 
            BEGIN
                EXEC SPK_RETIRAFTR_DE_CXC @CNSCXC, @N_FACTURA, @USUARIO, 'R', @CNSFPAG;
            END
            -- -------------------------------------------------------------------------
            -- CASO: DEVOLUCI~N PARCIAL (Genera nota cr~dito)
            -- -------------------------------------------------------------------------
            ELSE IF @INGRESO = 'DEVPAR'
            BEGIN
                PRINT '? Procesando devoluci~n parcial para factura: ' + @N_FACTURA;
                
                SET @NVOCNSFNOT = NULL;
                SET @NROCOMPROBANTEFNOT = NULL;

                -- Generar consecutivo de nota cr~dito
                EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FNOTC', @NVOCNSFNOT OUTPUT;
                SELECT @NVOCNSFNOT = @SEDE + 'C' + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@NVOCNSFNOT)), 8);

                -- Insertar cabecera de nota cr~dito
                INSERT INTO FNOT (CNSFNOT, CLASE, N_FACTURA, CNSCXC, IDTERCERO, F_NOTA, VR_TOTAL, 
                                  OBSERVACION, MARCA, MARCACONT, CONTABILIZADA, NROCOMPROBANTE, 
                                  IMPRESO, COMPANIA, USUARIO, CERRADA, ESTADO, USUARIOANU, USUARIOSOL, 
                                  FECHAANU, RAZONANU, PROCEDENCIA, CNSGLO, APLICADAA, LIBERAHADM, 
                                  CODUNG, CODPRG, ENPRESUPUESTO, IDTERCEROCOBERTURA, COBERTURA_AUT_POR, 
                                  CONCEPTO, IDCONCEPTO, TIPOCONCEPTO, VALORCONCEPTO, USUARIOAPLICA, DETGENERADOS)
                SELECT @NVOCNSFNOT, 'C', @N_FACTURA, '', @IDTERCERO, @HOY, 0, 
                       CONCAT('Enviado desde devoluci~n parcial CNSFPAG=', @CNSFPAG), 
                       0, 0, 0, NULL, 0, '01', @USUARIO, 1, 'O', '', '', NULL, NULL, 
                       'FACTURA', @CNSFPAG, 'F', 0, '', '', 0, '', '', 1, 
                       DBO.FNK_VALORVARIABLE('IDCONCEP_ANULAFTRCE'), 'P', 100, NULL, 0;

                -- Insertar detalles de nota cr~dito
                INSERT INTO FNOTD(CNSFNOT, CLASE, ITEM, TIPO, IDSERVICIO, DESCRIPCION, CANTIDAD, VR_UNITARIO,
                                  VR_TOTAL, COMPANIA, USUARIO, OBSERVACION, N_CUOTA, PIVA, VALORIVA, 
                                  N_FACTURA, CCOSTO, IDAREA, PREFIJO, CUENTA)
                SELECT @NVOCNSFNOT, 'C', FTRD.N_CUOTA, 'S', FPAGDD.IDSERVICIO, FTRD.ANEXO, 1, 
                       FPAGDD.VLRACEPTADO, ROUND(FPAGDD.VLRACEPTADO, 2), '01', @USUARIO, NULL, 
                       FTRD.N_CUOTA, FTRD.PIVA, FTRD.VIVA, @N_FACTURA, FTRD.CCOSTO, 
                       FTRD.AREAPRESTACION, FTRD.PREFIJO, FTRD.CUENTACR
                FROM FPAGDD 
                INNER JOIN FTR ON FTR.N_FACTURA = FPAGDD.N_FACTURA
                INNER JOIN FTRD ON FTRD.CNSFTR = FTR.CNSFCT AND FTRD.N_CUOTA = FPAGDD.N_CUOTA
                WHERE FPAGDD.CNSFPAG = @CNSFPAG AND FPAGDD.N_FACTURA = @N_FACTURA;

                -- Procesar valores y contabilizaci~n de la nota
                EXEC SPK_VLRNOTAS @NVOCNSFNOT, 'C';
                EXEC SPK_NC_CONTAB_FNOT @NVOCNSFNOT, 'C', @USUARIO, @SYS_COMPUTERNAME, @COMPANIA, @SEDE, @NROCOMPROBANTEFNOT;
                EXEC SPK_RELIQUIDA_FTR @CNSCXC, @N_FACTURA;

                -- Generaci~n de archivo electr~nico para Per~ (si aplica)
                IF DBO.FNK_VALORVARIABLE('IXCOUNTRY') = 'PERU'
                BEGIN
                    IF DBO.FNK_VALORVARIABLE('PROVEEDOR_FACTUELECT') = 'MIFACT'
                    BEGIN 
                        EXEC SPK_GENERA_JSON_PERU_NOTADBCR @NVOCNSFNOT, @N_FACTURA;
                    END
                    ELSE
                    BEGIN
                        EXEC SPK_GENERA_XML_PERU_NOTADBCR @NVOCNSFNOT, @N_FACTURA;
                    END
                END
            END
            -- -------------------------------------------------------------------------
            -- CASO: PROCESAMIENTO NORMAL (Pagos, Glosas, etc.)
            -- -------------------------------------------------------------------------
            ELSE
            BEGIN        
                -- Validaci~n: Si no hay valor de pago y no est~ permitido impuesto sin pago
                IF @VLRPAGOS = 0 AND DBO.FNK_VALORVARIABLE('RECPER_IMPSINPAGO') <> 'SI'
                BEGIN
                    UPDATE FPAGD SET VLRIMPUESTO = 0
                    WHERE CNSFPAG = @CNSFPAG AND N_FACTURA = @N_FACTURA AND ITEM = @ITEM;    
                END     

                -- =====================================================================
                -- PROCESAMIENTO DE GLOSAS
                -- =====================================================================
                IF @VLRGLOSAS > 0
                BEGIN
                    PRINT '? Procesando glosa: Valor=' + CAST(@VLRGLOSAS AS VARCHAR) + ' | Tipo=' + ISNULL(@TIPOGLOSA, 'N/A');
                    
                    IF @SINPAGO = 1
                    BEGIN
                        SELECT @TIPOGLOSA = 'T';
                        PRINT '  ? Glosa total aplicada';
                    END
                     
                    SELECT @IDDEP = LEFT(DATO, 20) FROM USVGS WHERE IDVARIABLE = 'IDFDEPCARTERA';
                    
                    -- Generar consecutivo de glosa
                    EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FGLO', @NVOCONSEC OUTPUT;
                    SELECT @NVOCONSEC = @SEDE + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@NVOCONSEC)), 8);
                    PRINT '  ? Consecutivo generado: ' + @NVOCONSEC;
                     
                    -- Verificar si la factura existe en FTR
                    SELECT @ENFTR = COUNT(*) FROM FTR WHERE N_FACTURA = @N_FACTURA;
                    IF @ENFTR IS NULL SET @ENFTR = 0;

                    IF @ENFTR > 0
                    BEGIN
                        -- Insertar glosa vinculada a factura existente
                        INSERT INTO FGLO(CNSGLO, CNSCXC, N_FACTURA, F_FACTURA, TIPO, VLRGLOSA, VLRACEPTADO, 
                                         VLRRECUPERAR, OBSERVACION, CERRADA, USUARIO, ASIGENT, CNSENTREGA, 
                                         MARCAENT, CNSMARCA, FECHAAUD, IDTERCERO, FECHARESP, OBSERVACIONRTA,
                                         USUARIOINGRTA, ENAUDITORIA, USURESPONRTA, TIPORESPUESTA, 
                                         CNSFPAG, ASIGDEV, CNSENTDEV, IDDEP, CNSFNOT, ESTADO, 
                                         ABONADO, SALDO, CNSGLO_O, ASIGNADAIMP, PROCEDENCIA, TIPOCONCILIACION)
                        SELECT @NVOCONSEC, @CNSCXC, @N_FACTURA, 
                               CAST(DATEPART(DAY, F_FACTURA) AS VARCHAR) + '/' + 
                               CAST(DATEPART(MONTH, F_FACTURA) AS VARCHAR) + '/' + 
                               CAST(DATEPART(YEAR, F_FACTURA) AS VARCHAR), 
                               @TIPOGLOSA, @VLRGLOSAS, 0, 0, 
                               LEFT('GENERADO POR PAGO No ' + LTRIM(RTRIM(@CNSFPAG)) + 
                                    CASE WHEN LEN(@OBSERVACIONG) > 10 THEN ' Motivo: ' + @OBSERVACIONG ELSE '' END, 8000), 
                               0, @USUARIO, 0, NULL, 0, NULL, NULL, @IDTERCERO, NULL, NULL, NULL, 0, NULL, 'T', 
                               @CNSFPAG, 0, NULL, @IDDEP, NULL, 'O', 0, 0, @CNSGLO, 0, 'Recaudo', 'A Favor'
                        FROM FTR WHERE N_FACTURA = @N_FACTURA;

                        UPDATE FPAGD SET CNSGLO_ASIG = @NVOCONSEC 
                        WHERE CNSFPAG = @CNSFPAG AND N_FACTURA = @N_FACTURA;
                    END
                    ELSE
                    BEGIN
                        -- Insertar glosa sin factura vinculada
                        INSERT INTO FGLO(CNSGLO, CNSCXC, N_FACTURA, F_FACTURA, TIPO, VLRGLOSA, VLRACEPTADO, 
                                         VLRRECUPERAR, OBSERVACION, CERRADA, USUARIO, ASIGENT, CNSENTREGA, 
                                         MARCAENT, CNSMARCA, FECHAAUD, IDTERCERO, FECHARESP, OBSERVACIONRTA,
                                         USUARIOINGRTA, ENAUDITORIA, USURESPONRTA, TIPORESPUESTA, 
                                         CNSFPAG, ASIGDEV, CNSENTDEV, IDDEP, CNSFNOT, ESTADO, 
                                         ABONADO, SALDO, CNSGLO_O, ASIGNADAIMP, PROCEDENCIA, TIPOCONCILIACION)
                        SELECT @NVOCONSEC, @CNSCXC, @N_FACTURA, 
                               CAST(DATEPART(DAY, GETDATE()) AS VARCHAR) + '/' + 
                               CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR) + '/' + 
                               CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR), 
                               @TIPOGLOSA, @VLRGLOSAS, 0, 0, 
                               LEFT('GENERADO POR PAGO No ' + LTRIM(RTRIM(@CNSFPAG)) + ' Motivo: ' + @OBSERVACIONG, 8000), 
                               0, @USUARIO, 0, NULL, 0, NULL, NULL, @IDTERCERO, NULL, NULL, NULL, 0, NULL, 'T', 
                               @CNSFPAG, 0, NULL, @IDDEP, NULL, 'O', 0, 0, @CNSGLO, 0, 'Recaudo', 'A Favor';
                    END

                    -- Motivos capturados en recaudo (FPAGD) -> FGLOCG para auditoria (RespGlosas / TRAE_MOTIGLO)
                    IF @VLRGLOSAS > 0 AND COALESCE(@NVOCONSEC, '') <> ''
                    BEGIN
                        SET @M1_NORM = NULLIF(LTRIM(RTRIM(@MOTIVO1)), '');
                        SET @M2_NORM = NULLIF(LTRIM(RTRIM(@MOTIVO2)), '');
                        SET @OBS_FGLOCG = LEFT(LTRIM(RTRIM(COALESCE(@OBSERVACIONG, ''))), 1024);
                        SET @M1_OK = 0;
                        SET @M2_OK = 0;
                        SET @VLR_M1 = 0;
                        SET @VLR_M2 = 0;

                        IF @M1_NORM IS NOT NULL
                           AND EXISTS (
                               SELECT 1
                               FROM FCGLO
                               WHERE CNSFCGLO = @M1_NORM
                                 AND UPPER(LTRIM(RTRIM(CLASE))) = 'GLOSA'
                                 AND UPPER(LTRIM(RTRIM(ESTADO))) = 'ACTIVO'
                           )
                            SET @M1_OK = 1;

                        IF @M2_NORM IS NOT NULL
                           AND EXISTS (
                               SELECT 1
                               FROM FCGLO
                               WHERE CNSFCGLO = @M2_NORM
                                 AND UPPER(LTRIM(RTRIM(CLASE))) = 'GLOSA'
                                 AND UPPER(LTRIM(RTRIM(ESTADO))) = 'ACTIVO'
                           )
                            SET @M2_OK = 1;

                        IF @M1_OK = 1 AND @M2_OK = 1 AND @M1_NORM = @M2_NORM
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM FGLOCG WHERE CNSGLO = @NVOCONSEC AND CNSFCGLO = @M1_NORM)
                                INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
                                VALUES (@NVOCONSEC, @M1_NORM, @VLRGLOSAS, @OBS_FGLOCG);
                        END
                        ELSE IF @M1_OK = 1 AND @M2_OK = 1 AND @M1_NORM <> @M2_NORM
                        BEGIN
                            SET @VLR_M2 = ROUND(@VLRGLOSAS / 2, 2);
                            SET @VLR_M1 = @VLRGLOSAS - @VLR_M2;

                            IF NOT EXISTS (SELECT 1 FROM FGLOCG WHERE CNSGLO = @NVOCONSEC AND CNSFCGLO = @M1_NORM)
                                INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
                                VALUES (@NVOCONSEC, @M1_NORM, @VLR_M1, @OBS_FGLOCG);

                            IF NOT EXISTS (SELECT 1 FROM FGLOCG WHERE CNSGLO = @NVOCONSEC AND CNSFCGLO = @M2_NORM)
                                INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
                                VALUES (@NVOCONSEC, @M2_NORM, @VLR_M2, @OBS_FGLOCG);
                        END
                        ELSE IF @M1_OK = 1
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM FGLOCG WHERE CNSGLO = @NVOCONSEC AND CNSFCGLO = @M1_NORM)
                                INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
                                VALUES (@NVOCONSEC, @M1_NORM, @VLRGLOSAS, @OBS_FGLOCG);
                        END
                        ELSE IF @M2_OK = 1
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM FGLOCG WHERE CNSGLO = @NVOCONSEC AND CNSFCGLO = @M2_NORM)
                                INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
                                VALUES (@NVOCONSEC, @M2_NORM, @VLRGLOSAS, @OBS_FGLOCG);
                        END
                        ELSE
                        BEGIN
                            IF @M1_NORM IS NOT NULL
                                PRINT '  ? Motivo glosa rechazado (MOTIVO1, no existe en FCGLO Glosa/Activo): ' + @M1_NORM;
                            IF @M2_NORM IS NOT NULL AND (@M1_NORM IS NULL OR @M2_NORM <> @M1_NORM)
                                PRINT '  ? Motivo glosa rechazado (MOTIVO2, no existe en FCGLO Glosa/Activo): ' + @M2_NORM;
                        END
                    END

                    -- Calcular y aplicar porcentaje de glosa en FTRCXC
                    SELECT @PORGLO = ((@VLRGLOSAS * 100) / NULLIF(SUM(SALDO), 0)) 
                    FROM FTRCXC WHERE N_FACTURA = @N_FACTURA;

                    PRINT '  ? Porcentaje de glosa calculado: ' + ISNULL(STR(@PORGLO), '0');

                    IF (SELECT COUNT(*) FROM FTRCXC 
                        INNER JOIN TTEC ON FTRCXC.TIPOTTEC = TTEC.TIPO 
                        WHERE FTRCXC.N_FACTURA = @N_FACTURA 
                          AND FTRCXC.CUENTACXC = TTEC.CTAGLOSADB) = 0
                    BEGIN
                        INSERT INTO FTRCXC
                        SELECT FTRCXC.N_FACTURA, FTRCXC.IDTERCERO, FTRCXC.TIPOTTEC, TTEC.CTAGLOSADB, 
                               ROUND((SALDO * @PORGLO) / 100, 2), FTRCXC.CCOSTO, FTRCXC.ESTADO
                        FROM FTRCXC 
                        INNER JOIN TTEC ON FTRCXC.TIPOTTEC = TTEC.TIPO
                        WHERE FTRCXC.N_FACTURA = @N_FACTURA;
                    END
                    ELSE
                    BEGIN
                        UPDATE FTRCXC SET SALDO = SALDO + @VLRGLOSAS
                        FROM FTRCXC 
                        INNER JOIN TTEC ON FTRCXC.TIPOTTEC = TTEC.TIPO 
                                       AND FTRCXC.CUENTACXC = TTEC.CTAGLOSADB
                        WHERE FTRCXC.N_FACTURA = @N_FACTURA;
                    END
                END -- Fin procesamiento de glosas
                -- =====================================================================
                -- ACTUALIZAR ESTADO DEL DETALLE DE PAGO
                -- =====================================================================
                UPDATE FPAGD SET CERRADO = 1    
                WHERE CNSFPAG = @CNSFPAG AND N_FACTURA = @N_FACTURA AND ITEM = @ITEM;

                PRINT '  ? Detalle marcado como cerrado: CNSFPAG=' + @CNSFPAG + ' | Factura=' + @N_FACTURA;

                -- Registrar hist~rico del pago aplicado
                INSERT INTO FPAGDC
                SELECT A.CNSFPAG, D.FECHA, D.IDTERCERO, B.TIPOTTEC, B.CUENTACXC, A.N_FACTURA, B.CCOSTO, 
                       B.SALDO, 0, B.SALDO
                FROM FPAGD A 
                INNER JOIN FTRCXC B ON A.N_FACTURA = B.N_FACTURA
                INNER JOIN TTEC C ON B.TIPOTTEC = C.TIPO AND B.CUENTACXC = C.CUENTARAD
                INNER JOIN FPAG D ON A.CNSFPAG = D.CNSFPAG
                WHERE A.N_FACTURA = @N_FACTURA AND A.CNSFPAG = @CNSFPAG;

                -- =====================================================================
                -- DISTRIBUCI~N PROPORCIONAL DEL PAGO EN FTRCXC
                -- =====================================================================
                SELECT @PORPAG = (((@VLRPAGOS + @VLRIMPUESTO + @VLRDTOFIN + @VLRGLOSAS) * 100) / NULLIF(SUM(SALDO), 0))
                FROM FTRCXC  
                INNER JOIN TTEC ON FTRCXC.TIPOTTEC = TTEC.TIPO
                WHERE N_FACTURA = @N_FACTURA AND FTRCXC.CUENTACXC = TTEC.CUENTARAD;

                PRINT '  ? Porcentaje de pago aplicado: ' + ISNULL(STR(@PORPAG), '0');

                -- Actualizar valores en FPAGDC
                UPDATE FPAGDC 
                SET VLR_PAGO = ROUND((VALORINI * @PORPAG) / 100, 2), 
                    SALDO = VALORINI - ROUND((VALORINI * @PORPAG) / 100, 2)
                WHERE N_FACTURA = @N_FACTURA AND CNSFPAG = @CNSFPAG;

                -- Actualizar saldos en FTRCXC
                UPDATE FTRCXC 
                SET SALDO = SALDO - ROUND((SALDO * @PORPAG) / 100, 2)
                FROM FTRCXC A 
                INNER JOIN TTEC B ON A.TIPOTTEC = B.TIPO
                WHERE N_FACTURA = @N_FACTURA AND A.CUENTACXC = B.CUENTARAD;

                -- =====================================================================
                -- ACTUALIZACI~N DE GLOSAS Y SALDOS EN FCXCDV
                -- =====================================================================
                IF @CLASE IN ('G', 'R', 'C')
                BEGIN
                    UPDATE FGLO 
                    SET ABONADO = ABONADO + @VLRPAGOS + @VLRIMPUESTO + @VLRDTOFIN
                    WHERE CNSGLO = @CNSGLO;

                    UPDATE FGLO 
                    SET SALDO = VLRGLOSA - ABONADO
                    WHERE CNSGLO = @CNSGLO;

                    SELECT @SALDONETO = SALDONETO 
                    FROM FCXCDV
                    WHERE CNSCXC = @CNSCXC AND N_FACTURA = @N_FACTURA AND TIPO = @CLASE AND CNSGLO = @CNSGLO;

                    UPDATE FCXCDV 
                    SET SALDONETO = SALDONETO - (@VLRPAGOS + @VLRIMPUESTO + @VLRDTOFIN - @VLRGLOSAS)
                    WHERE CNSCXC = @CNSCXC AND N_FACTURA = @N_FACTURA AND TIPO = @CLASE AND CNSGLO = @CNSGLO;

                    -- Proceso de levantamiento de glosas (si aplica)
                    IF @CLASE = 'G' AND @LEVANTADO = 1 
                    BEGIN
                        UPDATE FCXCDV SET 
                            LEVANTADO = CASE TIPO WHEN 'F' THEN LEVANTADO ELSE @LEVANTADO END,
                            SALDONETO = CASE TIPO WHEN 'F' THEN SALDONETO ELSE 0 END,
                            VLRLEVANTADO = ISNULL(VLRLEVANTADO, 0) + (@SALDONETO - @VLRGLOSAS)
                        WHERE CNSCXC = @CNSCXC AND N_FACTURA = @N_FACTURA AND TIPO IN (@CLASE, 'F')
                          AND ISNULL(CNSGLO, '') = CASE TIPO WHEN 'F' THEN ISNULL(CNSGLO, '') ELSE @CNSGLO END;
                    END

                    -- Limpiar marca de pago
                    UPDATE FCXCDV SET MARCAPAGO = 0
                    WHERE CNSCXC = @CNSCXC AND N_FACTURA = @N_FACTURA AND TIPO = @CLASE AND CNSGLO = @CNSGLO;
                END
                ELSE
                BEGIN
                    PRINT '  ? Disminuyendo saldo para tipo F';
                    UPDATE FCXCDV SET MARCAPAGO = 0
                    WHERE CNSCXC = @CNSCXC AND N_FACTURA = @N_FACTURA AND TIPO = 'F';
                END
            END -- Fin caso procesamiento normal

            FETCH NEXT FROM PAGD_CURSOR INTO @CNSCXC, @N_FACTURA, @ITEM, @VLRPAGOS, @VLRIMPUESTO, @VLRGLOSAS, 
                 @TIPOGLOSA, @SINPAGO, @CLASE, @CNSGLO, @VLRDTOFIN, @VLREXTRA, @OBSERVACIONG, @LEVANTADO,
                 @MOTIVO1, @MOTIVO2;
        END -- Fin WHILE cursor

        CLOSE PAGD_CURSOR;
        DEALLOCATE PAGD_CURSOR;
        -- =============================================================================
        -- VALIDAMOS NOTAS CREDITOS POR DESCUENTOS FINANCIEROS -- 20260813 STORRES
        -- =============================================================================
      IF @INGRESO ='BANCOS'
      BEGIN
         DECLARE @VLRMAXAJUSTERECAUDOS DECIMAL(14,2) -- 20260813 STORRES
         SELECT @VLRMAXAJUSTERECAUDOS = COALESCE(TRY_CAST(DBO.FNK_VALORVARIABLE('VLRMAXAJUSTERECAUDOS') AS DECIMAL(14,2)), 0) -- 20260813 STORRES
         DECLARE @N_FACT VARCHAR(20)
         DECLARE @CXC VARCHAR(20)
         DECLARE @VLR_DTO DECIMAL(14,2)
         DECLARE NCDTOS_CURSOR CURSOR FOR 
         SELECT N_FACTURA,CNSCXC,COALESCE(VLROTROSDCTOS,0) FROM FPAGD
         WHERE CNSFPAG=@CNSFPAG
         AND COALESCE(VLROTROSDCTOS,0)>@VLRMAXAJUSTERECAUDOS -- 20260813 STORRES
         ORDER BY CNSCXC,N_FACTURA
         OPEN NCDTOS_CURSOR    
         FETCH NEXT FROM NCDTOS_CURSOR    
         INTO @N_FACT,@CXC,@VLR_DTO
         WHILE @@FETCH_STATUS = 0    
         BEGIN 
            SET @NVOCNSFNOT = NULL;
            SET @NROCOMPROBANTEFNOT = NULL;

            -- Generar consecutivo de nota cr~dito
            EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FNOTC', @NVOCNSFNOT OUTPUT;
            SELECT @NVOCNSFNOT = @SEDE + 'C' + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@NVOCNSFNOT)), 8);
            PRINT '@N_FACT >>> ' + COALESCe(@N_FACT,'')
            -- Insertar cabecera de nota cr~dito
            INSERT INTO FNOT (CNSFNOT, CLASE, N_FACTURA, CNSCXC, IDTERCERO, F_NOTA, VR_TOTAL, 
                              OBSERVACION, MARCA, MARCACONT, CONTABILIZADA, NROCOMPROBANTE, 
                              IMPRESO, COMPANIA, USUARIO, CERRADA, ESTADO, USUARIOANU, USUARIOSOL, 
                              FECHAANU, RAZONANU, PROCEDENCIA, CNSGLO, APLICADAA, LIBERAHADM, 
                              CODUNG, CODPRG, ENPRESUPUESTO, IDTERCEROCOBERTURA, COBERTURA_AUT_POR, 
                              CONCEPTO, IDCONCEPTO, TIPOCONCEPTO, VALORCONCEPTO, USUARIOAPLICA, DETGENERADOS)
            SELECT @NVOCNSFNOT, 'C', @N_FACT,@CXC, @IDTERCERO, @HOY,@VLR_DTO , 
                  CONCAT('Descuentos Administrativos segun Pago:', @CNSFPAG), 
                  0, 0, 0, NULL, 0, '01', @USUARIO, 1, 'O', '', '', NULL, NULL, 
                  'FACTURA', @CNSFPAG, 'F', 0, '', '', 0, '', '', 1, 
                  DBO.FNK_VALORVARIABLE('IDCONCEP_ANULAFTRCE'), 'V', @VLR_DTO, NULL, 0;

            -- Insertar detalles de nota cr~dito
            EXEC SPK_GENITEMS_NOTACR @NVOCNSFNOT,'C',@USUARIO 

            -- Procesar valores y contabilizaci~n de la nota
            EXEC SPK_VLRNOTAS @NVOCNSFNOT, 'C';
            EXEC SPK_NC_CONTAB_FNOT @NVOCNSFNOT, 'C', @USUARIO, @SYS_COMPUTERNAME, @COMPANIA, @SEDE, @NROCOMPROBANTEFNOT;
            EXEC SPK_RELIQUIDA_FTR @CNSCXC, @N_FACTURA;


            FETCH NEXT FROM NCDTOS_CURSOR    
            INTO @N_FACT,@CXC,@VLR_DTO
         END
         CLOSE NCDTOS_CURSOR
         DEALLOCATE NCDTOS_CURSOR
      END

        -- =============================================================================
        -- PROCESAMIENTO DE PRESUPUESTO (si est~ activado)
        -- =============================================================================
        IF DBO.FNK_VALORVARIABLE('PRESUP_CXC_ACTIVADO') = 'SI'
        BEGIN
            PRINT '? Ejecutando proceso de presupuesto...';
            
            IF DBO.FNK_VALORVARIABLE('PRESUP_TIPORECO') = 'DESDEFTR'
            BEGIN
                EXEC SPK_RECUADO_PPTO_DESDEFTR @CNSFPAG, @SEDE, @COMPANIA, @USUARIO;
            END
            ELSE
            BEGIN
                EXEC SPK_RECUADO_PPTO @CNSFPAG, @SEDE, @COMPANIA, @USUARIO;
            END
            PRINT '  ? Proceso de presupuesto completado';
        END

        -- =============================================================================
        -- PROCESAMIENTO DE FINALIDAD (Devoluci~n o Glosas)
        -- =============================================================================
        PRINT '? Validando finalidad del proceso...';

        IF @INGRESO = 'DEVOLUCION' AND COALESCE(@FINDEVO, 0) IN (1, 2)
        BEGIN
            PRINT '  ? Ejecutando SPK_FINALIDAD_DEVOL...';
            EXEC SPK_FINALIDAD_DEVOL @CNSFPAG, @USUARIO, @SEDE, @FINDEVO;
        END
        -- =============================================================================
        -- RELIQUIDACI~N DE FACTURAS PROCESADAS
        -- =============================================================================
        DECLARE CXCPAG_CURSOR CURSOR LOCAL FAST_FORWARD FOR    
        SELECT CNSCXC, N_FACTURA FROM FPAGD WHERE FPAGD.CNSFPAG = @CNSFPAG;

        OPEN CXCPAG_CURSOR;
        FETCH NEXT FROM CXCPAG_CURSOR INTO @CNSCXC, @N_FACTURA;

        WHILE @@FETCH_STATUS = 0    
        BEGIN    
            EXEC SPK_RELIQUIDA_FTR @CNSCXC, @N_FACTURA;
            FETCH NEXT FROM CXCPAG_CURSOR INTO @CNSCXC, @N_FACTURA;
        END
        
        CLOSE CXCPAG_CURSOR;
        DEALLOCATE CXCPAG_CURSOR;

        -- =============================================================================
        -- ACTUALIZACI~N FINAL DEL ESTADO DEL PAGO
        -- =============================================================================
        UPDATE FPAG SET CERRADO = 1 WHERE FPAG.CNSFPAG = @CNSFPAG;
        
        EXEC SPK_FPAG @CNSFPAG;

        -- =============================================================================
        -- ACTUALIZACI~N DE INGRESOS EN BANCOS O CAJA
        -- =============================================================================
        IF @INGRESO = 'BANCOS'
        BEGIN 
            PRINT '? Actualizando movimientos en bancos...';
            
            UPDATE BMOVD 
            SET ENPAGOS = CASE 
                            WHEN BMOVD.VLRITEM - COALESCE(BMOVD.VLRLEGALIZADO, 0) - FPAG.VLRITEMS - FPAG.VLRAJUSTEPESO = 0 
                            THEN 1 ELSE 0 
                          END,
                VLRLEGALIZADO = COALESCE(BMOVD.VLRLEGALIZADO, 0) + COALESCE(FPAG.VLRITEMS, 0) + COALESCE(X.VLREXTRA, 0)
            FROM FPAG 
            INNER JOIN BMOVD ON BMOVD.BANCO = FPAG.BANCO 
                           AND BMOVD.SUCURSAL = FPAG.SUCURSAL 
                           AND BMOVD.CTA_BCO = FPAG.CTA_BCO 
                           AND BMOVD.ITEM = FPAG.ITEM 
                           AND BMOVD.RENGLON = FPAG.RENGLON
            LEFT JOIN (SELECT CNSFPAG, SUM(VLREXTRA) VLREXTRA FROM FPAGD GROUP BY CNSFPAG) X
                   ON FPAG.CNSFPAG = X.CNSFPAG
            WHERE FPAG.CNSFPAG = @CNSFPAG;
        END

        IF @INGRESO = 'CAJA'
        BEGIN
            PRINT '? Actualizando movimientos en caja...';
            
            UPDATE FCJ 
            SET ENPAGOS = CASE 
                            WHEN FCJ.VALORTOTAL - FCJ.VLRLEGALIZADO - FPAG.VLRITEMS = 0 THEN 1 ELSE 0 
                          END,
                VLRLEGALIZADO = FCJ.VLRLEGALIZADO + FPAG.VLRITEMS
            FROM FPAG 
            INNER JOIN FCJ ON FCJ.CODCAJA = FPAG.CODCAJA AND FCJ.CNSFACJ = FPAG.CNSFACJ
            WHERE FPAG.CNSFPAG = @CNSFPAG;
        END

        -- =============================================================================
        -- PROCESAMIENTO DE CRUCES CON CXP (PROVEEDORES)
        -- =============================================================================
        IF @INGRESO = 'CXP'
        BEGIN
            PRINT '? Procesando cruces con CXP...';
            
            DECLARE CXP_CURSOR CURSOR LOCAL FAST_FORWARD FOR    
            SELECT CNSFCXP, VLRCRUCE, NOREFERENCIA, CNSFCXPP
            FROM FPAGDCXP WHERE FPAGDCXP.CNSFPAG = @CNSFPAG;

            OPEN CXP_CURSOR;
            FETCH NEXT FROM CXP_CURSOR INTO @CNSFCXP, @VLRCRUCE, @NOREFERENCIA, @FCXPP;

            WHILE @@FETCH_STATUS = 0    
            BEGIN  
                IF COALESCE(@FCXPP, '') <> ''
                BEGIN
                    IF (SELECT ESTADO FROM FCXPP WHERE CNSFCXPP = @FCXPP) <> 'A'
                    BEGIN
                        PRINT '  ? Pago CXP ya procesado: ' + @FCXPP;
                        FETCH NEXT FROM CXP_CURSOR INTO @CNSFCXP, @VLRCRUCE, @NOREFERENCIA, @FCXPP;
                        CONTINUE;
                    END
                END

                EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FCXPP', @CNSFCXPP OUTPUT;
                SELECT @CNSFCXPP = @SEDE + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@CNSFCXPP)), 8);

                SELECT @CUECREDITO = CUECREDITO FROM FCXP WHERE CNSFCXP = @CNSFCXP;
                SELECT @OBSERVACION = 'CRUCE EN RECAUDOS CNSFPAG: ' + @CNSFPAG;

                EXEC SPK_ADMIN_PAGOS 'CXP', @NOREFERENCIA, @CNSFCXP, @CNSFCXPP, 'INSERT', 
                                     @VLRCRUCE, @IDTERCERO, @USUARIO, @SYS_COMPUTERNAME,
                                     @COMPANIA, @SEDE, @OBSERVACION, 'RECAUDOS', 'P', NULL, 
                                     @FECHAPAGO, '', '', @CUECREDITO, '', '';

                UPDATE FPAGDCXP SET CNSFCXPP = @CNSFCXPP
                WHERE CNSFPAG = @CNSFPAG AND CNSFCXP = @CNSFCXP;

                EXEC SPK_CALCULOVALORESCXP @CNSFCXP;

                FETCH NEXT FROM CXP_CURSOR INTO @CNSFCXP, @VLRCRUCE, @NOREFERENCIA, @FCXPP;
            END

            CLOSE CXP_CURSOR;
            DEALLOCATE CXP_CURSOR;
        END

        -- =============================================================================
        -- CONTABILIZACI~N AUTOM~TICA (si aplica)
        -- =============================================================================
        IF @NOCONTABILIZA = 1 
        BEGIN
            UPDATE FPAG SET CONTABILIZADO = 1 WHERE FPAG.CNSFPAG = @CNSFPAG;
        END

        IF @NROCOMPROBANTE IS NULL SET @NROCOMPROBANTE = '';

        IF (SELECT CERRADO FROM FPAG WHERE CNSFPAG = @CNSFPAG) = 1 AND COALESCE(@NOCONTABILIZA, 0) = 0
        BEGIN
            PRINT '? Ejecutando contabilizaci~n autom~tica...';
            EXEC SPK_NC_CONTAB_CXC @CNSFPAG, @USUARIO, @SYS_COMPUTERNAME, @COMPANIA, @SEDE, @NROCOMPROBANTE;
            PRINT '  ? Contabilizaci~n completada';
        END

    END TRY
    BEGIN CATCH
        -- =============================================================================
        -- MANEJO DE ERRORES CON ROLLBACK SEGURO
        -- =============================================================================
        SELECT @ERROR_MSG = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR) + 
                           ' (L~nea ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR), 'N/A') + '): ' + 
                           ERROR_MESSAGE() + 
                           ' | Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR) + 
                           ' | State: ' + CAST(ERROR_STATE() AS VARCHAR);

        PRINT '? ERROR CR~TICO: ' + @ERROR_MSG;

        RAISERROR(@ERROR_MSG, 16, 1);
        SELECT 'KO' AS ESTADO, @ERROR_MSG AS MENSAJE, @CNSFPAG AS CNSFPAG;
        RETURN -1;
    END CATCH
END

