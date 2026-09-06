CREATE OR ALTER PROC SPK_FINALIDAD_GLOSAS
    @CNSPAGO    VARCHAR(20),
    @USUARIO   VARCHAR(12),
    @SEDE      VARCHAR(6),
    @FINDEVOL  TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @COMPANIA             VARCHAR(2),
            @SYS_COMPUTERNAME     VARCHAR(256),
            @IDCONCEPRPTAGLO_AUTO VARCHAR(20),
            @IDTERCERO            VARCHAR(20),
            @CNSDEVOL             VARCHAR(20),
            @CNSENTREGA           VARCHAR(20),
            @CNSRPDX              VARCHAR(20),
            @CNSGLOI              VARCHAR(20),
            @CNSGLO               VARCHAR(20),
            @SQL                  NVARCHAR(MAX),
            @ERROR                VARCHAR(MAX),
            @CONTADOR_REGISTROS   INT,
            @ERROR_DETALLE        VARCHAR(MAX),
            @XACT_STATE_VAL       INT;

    DECLARE @TBLERRORES TABLE (ERROR VARCHAR(MAX));
    DECLARE @RESUL TABLE (DATO1 VARCHAR(20), DATO2 VARCHAR(20));

    -- =============================================================================
    -- LOGGING INICIAL DE ESTADO
    -- =============================================================================

    SET @IDCONCEPRPTAGLO_AUTO = DBO.FNK_VALORVARIABLE('IDCONCEPRPTAGLO_AUTO');

    SELECT @SEDE          = COALESCE(UBEQ.IDSEDE, USUSU.IDSEDE),
           @COMPANIA      = COALESCE(UBEQ.COMPANIA, USUSU.COMPANIA),
           @SYS_COMPUTERNAME = COALESCE(USUSU.SYS_ComputerName, HOST_NAME())
    FROM USUSU 
    LEFT JOIN UBEQ ON USUSU.SYS_ComputerName = UBEQ.SYS_ComputerName
    WHERE USUSU.USUARIO = @USUARIO;

    -- =============================================================================
    -- BLOQUE PRINCIPAL SIN XACT_ABORT ON
    -- =============================================================================
    BEGIN TRY

        PRINT '=== INICIO PROCESO FINALIDAD GLOSAS ===';

        -- -------------------------------------------------------------------------
        -- PASO 1: ENVIAR A AUDITORÍA
        -- -------------------------------------------------------------------------
        PRINT '--- PASO 1: ENVIANDO A AUDITORÍA ---';

        SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FPAG_COL","METODO":"ENVIAR_AUDIT","PARAMETROS":{"CNSFPAG":"' + @CNSPAGO + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';

        INSERT INTO @RESUL (DATO1) EXEC (@SQL);

        SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;

        IF @CONTADOR_REGISTROS = 0
        BEGIN
            RAISERROR('No se recibió respuesta válida de SPQ_JSON para auditoría.', 16, 1);
            RETURN -1;
        END

        SELECT TOP 1 @CNSDEVOL = DATO1 FROM @RESUL;
        IF @CNSDEVOL IS NULL OR @CNSDEVOL <> 'OK'
        BEGIN
            RAISERROR('La auditoría no retornó estado OK. Valor: %s', 16, 1, @CNSDEVOL);
            RETURN -1;
        END

        -- -------------------------------------------------------------------------
        -- PASO 2: RECIBIR GLOSA
        -- -------------------------------------------------------------------------
        PRINT '--- PASO 2: RECIBIENDO GLOSA ---';

        SELECT @CNSENTREGA = CNSENTREGA FROM FPAG WHERE CNSFPAG = @CNSPAGO;

        SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FGLO_COL","METODO":"RECIBIR_GLOSA","PARAMETROS":{"CNSENTREGA":"' + @CNSENTREGA + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';

        DELETE FROM @RESUL;
        INSERT INTO @RESUL (DATO1) EXEC (@SQL);

        SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;
        IF @CONTADOR_REGISTROS = 0
        BEGIN
            RAISERROR('No se recibió respuesta válida de SPQ_JSON para recepción de glosa.', 16, 1);
            RETURN -1;
        END

        SELECT TOP 1 @CNSDEVOL = DATO1 FROM @RESUL;
        IF @CNSDEVOL IS NULL OR @CNSDEVOL <> 'OK'
        BEGIN
            RAISERROR('La recepción de glosa no retornó estado OK. Valor: %s', 16, 1, @CNSDEVOL);
            RETURN -1;
        END

        -- -------------------------------------------------------------------------
        -- PASO 3: ACTUALIZAR RESPUESTA DE GLOSAS
        -- -------------------------------------------------------------------------
        PRINT '--- PASO 3: ACTUALIZANDO RESPUESTA DE GLOSAS ---';

        SELECT @IDTERCERO = IDTERCERO,
               @CNSRPDX   = CNSRPDX + '_1'
        FROM FPAG WHERE CNSFPAG = @CNSPAGO;

        UPDATE FGLO 
        SET IDCONCEPTO     = @IDCONCEPRPTAGLO_AUTO,
            OBSERVACIONRTA = FPAGD.OBSERVACION,
            VLRACEPTADO    = COALESCE(FPAGD.VLR_ACEPTADO, 0),
            FECHARESP      = DBO.FNK_GETDATE(),
            USURESPONRTA   = @USUARIO,
            VLRRECUPERAR   = FGLO.VLRGLOSA - COALESCE(FPAGD.VLR_ACEPTADO, 0),
            TIPORESPUESTA  = CASE WHEN @FINDEVOL = 4 THEN 'T' ELSE 'I' END
        FROM FGLO 
        INNER JOIN FPAGD ON FGLO.CNSGLO = FPAGD.CNSGLO_ASIG
        WHERE FPAGD.CNSFPAG = @CNSPAGO AND FGLO.CNSFPAG = @CNSPAGO;

        -- -------------------------------------------------------------------------
        -- PASO 4: PROCESAR SEGÚN TIPO DE FINALIDAD
        -- -------------------------------------------------------------------------
        IF @FINDEVOL = 4
        BEGIN
            PRINT '--- PROCESANDO DEVOLUCIÓN TOTAL (FINDEVOL=4) ---';

            -- 4.1: Registrar conceptos de glosa
            INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
            SELECT FGLO.CNSGLO, FPAGD.MOTIVO1, FGLO.VLRGLOSA, FPAGD.OBSERVACION
            FROM FGLO   INNER JOIN FPAGD ON FGLO.CNSGLO = FPAGD.CNSGLO_ASIG
            WHERE FPAGD.CNSFPAG = @CNSPAGO AND FGLO.CNSFPAG = @CNSPAGO;

            -- 4.2: Ejecutar respuesta de glosa por cada CNSGLO
            DECLARE FINDEV4_CURSOR CURSOR LOCAL FAST_FORWARD FOR 
                SELECT DISTINCT CNSGLO FROM FGLO WHERE CNSFPAG = @CNSPAGO;

            OPEN FINDEV4_CURSOR;
            FETCH NEXT FROM FINDEV4_CURSOR INTO @CNSGLO;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- ?? Verificar estado ANTES de llamar SP anidado
                SET @XACT_STATE_VAL = XACT_STATE();
                IF @XACT_STATE_VAL = -1
                BEGIN
                    PRINT '?? Transacción en estado irreversible. Deteniendo cursor.';
                    CLOSE FINDEV4_CURSOR;
                    DEALLOCATE FINDEV4_CURSOR;
                    RETURN -1;
                END

                BEGIN TRY
                    PRINT '? Ejecutando SPK_RESPUESTAGLOSA para: ' + @CNSGLO;
                    
                    EXEC SPK_RESPUESTAGLOSA 
                        @CNSGLO, 3, @SEDE, @COMPANIA, @USUARIO, @SYS_COMPUTERNAME, 0;
                END TRY
                BEGIN CATCH
                    SELECT @ERROR_DETALLE = ERROR_MESSAGE();
                    SET @XACT_STATE_VAL = XACT_STATE();
                    
                    PRINT '? Error en SPK_RESPUESTAGLOSA: ' + @ERROR_DETALLE;
                    PRINT '?? XACT_STATE después del error: ' + CAST(@XACT_STATE_VAL AS VARCHAR);
                    
                    -- ?? Si está en -1, NO hacer INSERT, salir inmediatamente
                    IF @XACT_STATE_VAL = -1
                    BEGIN
                        PRINT '?? Transacción DOOMED - Saliendo sin INSERT';
                        CLOSE FINDEV4_CURSOR;
                        DEALLOCATE FINDEV4_CURSOR;
                        -- NO hacer RAISERROR aquí (también escribe en log)
                        RETURN -1;
                    END
                    ELSE
                    BEGIN
                        -- Solo registrar si la transacción permite escritura
                        INSERT INTO @TBLERRORES (ERROR) 
                        SELECT 'CNSGLO: ' + @CNSGLO + ' - ' + @ERROR_DETALLE;
                    END
                END CATCH

                FETCH NEXT FROM FINDEV4_CURSOR INTO @CNSGLO;
            END

            CLOSE FINDEV4_CURSOR;
            DEALLOCATE FINDEV4_CURSOR;

            -- Verificar errores acumulados
            IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
            BEGIN
                PRINT '=== ERRORES EN PROCESAMIENTO DE GLOSAS ===';
                SELECT 'KO' AS OK, ERROR FROM @TBLERRORES;
                RETURN -1;
            END

            -- 4.3: Generar consecutivo e imprimir respuestas
            BEGIN TRY
                PRINT '? Generando consecutivo FGLOI...';
                
                EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, 'FGLOI', @CNSGLOI OUTPUT;
                SELECT @CNSGLOI = @SEDE + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@CNSGLOI)), 8);

                INSERT INTO FGLOI (CNSGLOI, IDTERCERO, USUARIO, FECHA, OBSERVACION, IMPRESIONES, 
                                   RADICADO, FECHARAD, USUARIORAD, CONTABILIZADA, NROCOMPROBANTE, FECHADIG)
                SELECT @CNSGLOI, @IDTERCERO, @USUARIO, DBO.FNK_GETDATE(), 
                       'Impresión de respuestas automática', 0, 0, NULL, NULL, 0, NULL, NULL;

                INSERT INTO FGLOID (CNSGLOI, CNSGLO, N_FACTURA, ITEM)
                SELECT @CNSGLOI, FGLO.CNSGLO, FGLO.N_FACTURA,
                       ROW_NUMBER() OVER (ORDER BY FGLO.CNSGLO)
                FROM FGLO WHERE FGLO.CNSFPAG = @CNSPAGO;

                UPDATE FGLO SET ASIGNADAIMP = 1, CNSGLOI = @CNSGLOI
                WHERE FGLO.CNSFPAG = @CNSPAGO;

                UPDATE FGLOI SET IMPRESIONES = COALESCE(IMPRESIONES, 0) + 1 
                WHERE CNSGLOI = @CNSGLOI;
            END TRY
            BEGIN CATCH
                SELECT @ERROR_DETALLE = ERROR_MESSAGE();
                SET @XACT_STATE_VAL = XACT_STATE();
                
                PRINT '? Error generando consecutivo: ' + @ERROR_DETALLE;
                PRINT '?? XACT_STATE: ' + CAST(@XACT_STATE_VAL AS VARCHAR);
                
                IF @XACT_STATE_VAL = -1
                BEGIN
                    PRINT '?? Transacción DOOMED - Saliendo';
                    RETURN -1;
                END
                ELSE
                BEGIN
                    INSERT INTO @TBLERRORES (ERROR) SELECT 'Error consecutivo: ' + @ERROR_DETALLE;
                END
            END CATCH

            -- 4.4: Enviar respuesta a cartera
            PRINT '--- ENVIANDO RESPUESTA A CARTERA ---';

            DELETE @RESUL;

            SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FGLO_COL","METODO":"ENVIAR_RESPUESTA","PARAMETROS":{"CNSGLOI":"' + @CNSGLOI + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';

            INSERT INTO @RESUL (DATO1,DATO2) EXEC (@SQL);

            SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;
            IF @CONTADOR_REGISTROS = 0
            BEGIN
                PRINT'No se recibió respuesta válida de SPQ_JSON para envío a cartera.';
                RETURN -1;
            END

            SELECT TOP 1 @CNSENTREGA = DATO2 FROM @RESUL;
            IF COALESCE(@CNSENTREGA, '') = ''
            BEGIN
                SELECT TOP 1 @CNSENTREGA = CNSENTDEV FROM FGLO WHERE CNSFPAG = @CNSPAGO;
            END
            -- 4.4: Enviar respuesta a cartera
            PRINT '--- RECIBIENDO RESPUESTA EN CARTERA ---';

            DELETE @RESUL;

            SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FGLO_COL","METODO":"RECIBIR_RPTASGLOSA","PARAMETROS":{"CNSENTREGA":"' + @CNSENTREGA + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';
            PRINT @SQL

            INSERT INTO @RESUL (DATO1) EXEC (@SQL);

            SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;
            IF @CONTADOR_REGISTROS = 0
            BEGIN
                PRINT'No se recibió respuesta válida de SPQ_JSON para envío a cartera.';
                RETURN -1;
            END
            PRINT 'TERMINO TODO.....'
        END

        -- -------------------------------------------------------------------------
        -- OPCION 5: DEVOLUCIÓN PARCIAL
        -- -------------------------------------------------------------------------
        ELSE IF @FINDEVOL = 5
        BEGIN
            PRINT '--- PROCESANDO DEVOLUCIÓN PARCIAL (FINDEVOL=5) ---';
            
            INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
            SELECT FPAGD.CNSGLO_ASIG, RPDX.ID3, RPDX.VALOR2, RPDX.STRINGGRANDE1
            FROM FPAGD INNER JOIN RPDX ON FPAGD.CNSFPAG = RPDX.CNS1 AND FPAGD.ITEM = RPDX.CANTIDAD
            WHERE FPAGD.CNSFPAG = @CNSPAGO AND RPDX.CNS = @CNSRPDX
            AND EXISTS(SELECT * FROM FCGLO WHERE FCGLO.CNSFCGLO=RPDX.ID3)

            INSERT INTO FGLOD (CNSGLO, ITEM, CNSCXC, N_FACTURA, USUARIO, FECHANOVEDAD, TIPO, 
                               IDSERVICIO, DESCRIPCION, CANTIDAD, VR_UNITARIO, VLRGLOSA, 
                               VLRACEPTADO, VLRRECUPERAR, OBSERVACION, CERRADA, RESPUESTA, 
                               FECHARESP, CONCEPTO, ASIGRESP, RESPONSABLE, OBSRESPON, 
                               VALORFINAL, AUTORIZA, ESTADO, N_CUOTAS, USUARIOCE, TIPOTEC, 
                               F_CIERRE, CONTABILIZADA, NROCOMPROBANTE, IDAREA, CCOSTO, 
                               CODUNG, CODPRG, N_CUOTA, CODGLOSA, CODRPTA)
            SELECT FGLO.CNSGLO,ROW_NUMBER() OVER(PARTITION BY FGLO.CNSGLO ORDER BY FGLO.CNSGLO ASC)NRO,
                   FGLO.CNSCXC, FGLO.N_FACTURA, FGLO.USUARIO, DBO.FNK_GETDATE(), 'S', 
                   NULL, NULL, 1, RPDX.VALOR2, RPDX.VALOR2, 0, 0, RPDX.STRINGGRANDE1, 
                   CERRADA, NULL, NULL, @IDCONCEPRPTAGLO_AUTO, NULL, NULL, NULL, NULL, 
                   NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
                   NULL, RPDX.ID3, NULL
            FROM FGLO 
            INNER JOIN FPAGD ON FGLO.CNSGLO = FPAGD.CNSGLO_ASIG
            INNER JOIN RPDX ON FPAGD.CNSFPAG = RPDX.CNS1 AND FPAGD.ITEM = RPDX.CANTIDAD
            WHERE FPAGD.CNSFPAG = @CNSPAGO AND FGLO.CNSFPAG = @CNSPAGO AND RPDX.CNS = @CNSRPDX;
        END
        ELSE IF @FINDEVOL = 6
        BEGIN
            PRINT '--- PROCESANDO DEVOLUCIÓN PARCIAL (FINDEVOL=6) ---';
            
            INSERT INTO FGLOCG (CNSGLO, CNSFCGLO, VALOR, OBSERVACION)
            SELECT FPAGD.CNSGLO_ASIG, RPDX.ID3, RPDX.VALOR2, RPDX.STRINGGRANDE1
            FROM FPAGD INNER JOIN RPDX ON FPAGD.CNSFPAG = RPDX.CNS1 AND FPAGD.ITEM = RPDX.CANTIDAD
            WHERE FPAGD.CNSFPAG = @CNSPAGO AND RPDX.CNS = @CNSRPDX
            AND EXISTS(SELECT * FROM FCGLO WHERE FCGLO.CNSFCGLO=RPDX.ID3)

            INSERT INTO FGLOD (CNSGLO, ITEM, CNSCXC, N_FACTURA, USUARIO, FECHANOVEDAD, TIPO, 
                               IDSERVICIO, DESCRIPCION, CANTIDAD, VR_UNITARIO, VLRGLOSA, 
                               VLRACEPTADO, VLRRECUPERAR, OBSERVACION, CERRADA, RESPUESTA, 
                               FECHARESP, CONCEPTO, ASIGRESP, RESPONSABLE, OBSRESPON, 
                               VALORFINAL, AUTORIZA, ESTADO, N_CUOTAS, USUARIOCE, TIPOTEC, 
                               F_CIERRE, CONTABILIZADA, NROCOMPROBANTE, IDAREA, CCOSTO, 
                               CODUNG, CODPRG, N_CUOTA, CODGLOSA, CODRPTA)
            SELECT FGLO.CNSGLO,ROW_NUMBER() OVER(PARTITION BY FGLO.CNSGLO ORDER BY FGLO.CNSGLO ASC)NRO,
                   FGLO.CNSCXC, FGLO.N_FACTURA, FGLO.USUARIO, DBO.FNK_GETDATE(), 'S', 
                   NULL, NULL, 1, RPDX.VALOR2, RPDX.VALOR2,RPDX.VALOR3,(RPDX.VALOR2-COALESCE(RPDX.VALOR3,0)), RPDX.STRINGGRANDE1, 
                   CERRADA, NULL, NULL, @IDCONCEPRPTAGLO_AUTO, NULL, NULL, NULL, NULL, 
                   NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
                   NULL, RPDX.ID3, RPDX.ID4
            FROM FGLO 
            INNER JOIN FPAGD ON FGLO.CNSGLO = FPAGD.CNSGLO_ASIG
            INNER JOIN RPDX ON FPAGD.CNSFPAG = RPDX.CNS1 AND FPAGD.ITEM = RPDX.CANTIDAD
            WHERE FPAGD.CNSFPAG = @CNSPAGO AND FGLO.CNSFPAG = @CNSPAGO AND RPDX.CNS = @CNSRPDX;

           -- 4.2: Ejecutar respuesta de glosa por cada CNSGLO
            DECLARE FINDEV4_CURSOR CURSOR LOCAL FAST_FORWARD FOR 
                SELECT DISTINCT CNSGLO FROM FGLO WHERE CNSFPAG = @CNSPAGO;

            OPEN FINDEV4_CURSOR;
            FETCH NEXT FROM FINDEV4_CURSOR INTO @CNSGLO;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- ?? Verificar estado ANTES de llamar SP anidado
                SET @XACT_STATE_VAL = XACT_STATE();
                IF @XACT_STATE_VAL = -1
                BEGIN
                    PRINT '?? Transacción en estado irreversible. Deteniendo cursor.';
                    CLOSE FINDEV4_CURSOR;
                    DEALLOCATE FINDEV4_CURSOR;
                    RETURN -1;
                END

                BEGIN TRY
                    PRINT '? Ejecutando SPK_RESPUESTAGLOSA para: ' + @CNSGLO;
                    
                    EXEC SPK_RESPUESTAGLOSA 
                        @CNSGLO, 3, @SEDE, @COMPANIA, @USUARIO, @SYS_COMPUTERNAME, 0;
                END TRY
                BEGIN CATCH
                    SELECT @ERROR_DETALLE = ERROR_MESSAGE();
                    SET @XACT_STATE_VAL = XACT_STATE();
                    
                    PRINT '? Error en SPK_RESPUESTAGLOSA: ' + @ERROR_DETALLE;
                    PRINT '?? XACT_STATE después del error: ' + CAST(@XACT_STATE_VAL AS VARCHAR);
                    
                    -- ?? Si está en -1, NO hacer INSERT, salir inmediatamente
                    IF @XACT_STATE_VAL = -1
                    BEGIN
                        PRINT '?? Transacción DOOMED - Saliendo sin INSERT';
                        CLOSE FINDEV4_CURSOR;
                        DEALLOCATE FINDEV4_CURSOR;
                        -- NO hacer RAISERROR aquí (también escribe en log)
                        RETURN -1;
                    END
                    ELSE
                    BEGIN
                        -- Solo registrar si la transacción permite escritura
                        INSERT INTO @TBLERRORES (ERROR) 
                        SELECT 'CNSGLO: ' + @CNSGLO + ' - ' + @ERROR_DETALLE;
                    END
                END CATCH

                FETCH NEXT FROM FINDEV4_CURSOR INTO @CNSGLO;
            END

            CLOSE FINDEV4_CURSOR;
            DEALLOCATE FINDEV4_CURSOR;

            -- Verificar errores acumulados
            IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
            BEGIN
                PRINT '=== ERRORES EN PROCESAMIENTO DE GLOSAS ===';
                SELECT 'KO' AS OK, ERROR FROM @TBLERRORES;
                RETURN -1;
            END

            -- 4.3: Generar consecutivo e imprimir respuestas
            BEGIN TRY
                PRINT '? Generando consecutivo FGLOI...';
                
                EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, 'FGLOI', @CNSGLOI OUTPUT;
                SELECT @CNSGLOI = @SEDE + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@CNSGLOI)), 8);

                INSERT INTO FGLOI (CNSGLOI, IDTERCERO, USUARIO, FECHA, OBSERVACION, IMPRESIONES, 
                                   RADICADO, FECHARAD, USUARIORAD, CONTABILIZADA, NROCOMPROBANTE, FECHADIG)
                SELECT @CNSGLOI, @IDTERCERO, @USUARIO, DBO.FNK_GETDATE(), 
                       'Impresión de respuestas automática', 0, 0, NULL, NULL, 0, NULL, NULL;

                INSERT INTO FGLOID (CNSGLOI, CNSGLO, N_FACTURA, ITEM)
                SELECT @CNSGLOI, FGLO.CNSGLO, FGLO.N_FACTURA,
                       ROW_NUMBER() OVER (ORDER BY FGLO.CNSGLO)
                FROM FGLO WHERE FGLO.CNSFPAG = @CNSPAGO;

                UPDATE FGLO SET ASIGNADAIMP = 1, CNSGLOI = @CNSGLOI
                WHERE FGLO.CNSFPAG = @CNSPAGO;

                UPDATE FGLOI SET IMPRESIONES = COALESCE(IMPRESIONES, 0) + 1 
                WHERE CNSGLOI = @CNSGLOI;
            END TRY
            BEGIN CATCH
                SELECT @ERROR_DETALLE = ERROR_MESSAGE();
                SET @XACT_STATE_VAL = XACT_STATE();
                
                PRINT '? Error generando consecutivo: ' + @ERROR_DETALLE;
                PRINT '?? XACT_STATE: ' + CAST(@XACT_STATE_VAL AS VARCHAR);
                
                IF @XACT_STATE_VAL = -1
                BEGIN
                    PRINT '?? Transacción DOOMED - Saliendo';
                    RETURN -1;
                END
                ELSE
                BEGIN
                    INSERT INTO @TBLERRORES (ERROR) SELECT 'Error consecutivo: ' + @ERROR_DETALLE;
                END
            END CATCH

            -- 4.4: Enviar respuesta a cartera
            PRINT '--- ENVIANDO RESPUESTA A CARTERA ---';

            DELETE @RESUL;

            SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FGLO_COL","METODO":"ENVIAR_RESPUESTA","PARAMETROS":{"CNSGLOI":"' + @CNSGLOI + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';

            INSERT INTO @RESUL (DATO1,DATO2) EXEC (@SQL);

            SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;
            IF @CONTADOR_REGISTROS = 0
            BEGIN
                PRINT'No se recibió respuesta válida de SPQ_JSON para envío a cartera.';
                RETURN -1;
            END

            SELECT TOP 1 @CNSENTREGA = DATO2 FROM @RESUL;
            IF COALESCE(@CNSENTREGA, '') = ''
            BEGIN
                SELECT TOP 1 @CNSENTREGA = CNSENTDEV FROM FGLO WHERE CNSFPAG = @CNSPAGO;
            END
            -- 4.4: Enviar respuesta a cartera
            PRINT '--- RECIBIENDO RESPUESTA EN CARTERA ---';

            DELETE @RESUL;

            SET @SQL = N'EXEC SPQ_JSON ''{"MODELO":"FGLO_COL","METODO":"RECIBIR_RPTASGLOSA","PARAMETROS":{"CNSENTREGA":"' + @CNSENTREGA + '"},"USUARIO":"' + REPLACE(@USUARIO, '''', '''''') + '"}''';
            PRINT @SQL

            INSERT INTO @RESUL (DATO1,DATO2) EXEC (@SQL);

            SELECT @CONTADOR_REGISTROS = COUNT(*) FROM @RESUL;
            IF @CONTADOR_REGISTROS = 0
            BEGIN
                PRINT'No se recibió respuesta válida de SPQ_JSON para envío a cartera.';
                RETURN -1;
            END
            PRINT 'TERMINO TODO.....'

        END
        -- -------------------------------------------------------------------------
        -- VALIDACIÓN FINAL
        -- -------------------------------------------------------------------------
        IF (SELECT COUNT(*) FROM @TBLERRORES) > 0
        BEGIN
            PRINT '=== SE PRESENTARON ERRORES ===';
            SELECT 'KO' AS OK, ERROR FROM @TBLERRORES;
            RETURN -1;
        END

        PRINT '=== PROCESO FINALIZADO EXITOSAMENTE ===';
        SELECT 'OK' AS OK;
        RETURN 0;

    END TRY
    BEGIN CATCH
        SELECT @ERROR = ERROR_MESSAGE();
        SET @XACT_STATE_VAL = XACT_STATE();
    
        PRINT '? ERROR EN CATCH PRINCIPAL: ' + @ERROR;
        PRINT '?? XACT_STATE()=' + CAST(@XACT_STATE_VAL AS VARCHAR);
        PRINT '?? @@TRANCOUNT=' + CAST(@@TRANCOUNT AS VARCHAR);
    
        RETURN -1;
    END CATCH
END

