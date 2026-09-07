CREATE OR ALTER PROC dbo.SPK_FINALIDAD_DEVOL
    @CNSPAGO    VARCHAR(20), 
    @USUARIO   VARCHAR(12),
    @SEDE      VARCHAR(6),
    @FINDEVOL  TINYINT
WITH ENCRYPTION
AS
BEGIN
    -- Declaración de variables
    DECLARE @N_FACTURA VARCHAR(20)
    DECLARE @CNSCXC VARCHAR(20)
    DECLARE @CNSDEVOL VARCHAR(20)
    DECLARE @CNSENTREGAORI VARCHAR(20)
    DECLARE @CNSENTREGA VARCHAR(20)
    DECLARE @NODOCUMENTO VARCHAR(20)
    DECLARE @COMPANIA VARCHAR(2) = '01'
    DECLARE @IDDEPENTREGA VARCHAR(20)
    DECLARE @CONSEC_ENT_RAW VARCHAR(20)
    DECLARE @ERROR VARCHAR(2048)
    DECLARE @OBSERVACION VARCHAR(2048)
    DECLARE @SYS_COMPUTERNAME VARCHAR(256)
    DECLARE @MSEDE BIT = 0
    DECLARE @COORFACTURACION VARCHAR(20)
    DECLARE @COORCARTERA VARCHAR(20)
    DECLARE @IDTERCERO VARCHAR(20)
    -- Configuración inicial de seguridad y contexto
    SET NOCOUNT ON;

    BEGIN TRY
        IF @FINDEVOL = 1
        BEGIN
            PRINT 'VOY A ANULAR FACTURAS'

            -- Obtener valores de configuración de forma segura (ENT.ENT_RECIBE / DEP_RECIBE: varchar(20))
            DECLARE @IDDEPFACT VARCHAR(20) = LEFT(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('IDFDEPFACTURACION'))), 20)
            DECLARE @USUARIO_JSON VARCHAR(12) = LEFT(LTRIM(RTRIM(@USUARIO)), 12)
            DECLARE @SEDE_JSON VARCHAR(5) = LEFT(LTRIM(RTRIM(@SEDE)), 5)

            IF LEN(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('IDFDEPFACTURACION')))) > 20
            BEGIN
                RAISERROR('La variable IDFDEPFACTURACION supera 20 caracteres (ENT_RECIBE). Revise USVGS / configuración.', 16, 1)
                RETURN
            END

            IF EXISTS (
                SELECT 1 FROM FPAGD
                WHERE CNSFPAG = @CNSPAGO AND LEN(LTRIM(RTRIM(N_FACTURA))) > 16
            )
            BEGIN
                RAISERROR('Hay facturas en FPAGD con N_FACTURA mayor a 16 caracteres (ENTD.NODOCUMENTO). Corrija el detalle del recaudo.', 16, 1)
                RETURN
            END

            IF COALESCE(@SEDE_JSON, '') = ''
            BEGIN
                SELECT @SEDE_JSON = LEFT(LTRIM(RTRIM(COALESCE(F.IDSEDE, U.IDSEDE, ''))), 5)
                FROM FPAG F
                LEFT JOIN USUSU U ON U.USUARIO = @USUARIO_JSON
                WHERE F.CNSFPAG = @CNSPAGO
            END

            IF COALESCE(@SEDE_JSON, '') = ''
            BEGIN
                RAISERROR('No se pudo determinar la sede (IDSEDE) para crear la entrega DEVFACT.', 16, 1)
                RETURN
            END

            /* Cartera/auditoría entrega; facturación recibe (mismo criterio que DevolFactura / ENT_COL). */
            SET @IDDEPENTREGA = LEFT(LTRIM(RTRIM(COALESCE(
                NULLIF(DBO.FNK_VALORVARIABLE('IDFDEPCARTERA'), ''),
                DBO.FNK_VALORVARIABLE('IDFDEPAUDITORIA')
            ))), 20)

            /*
              Crear ENT DEVFACT en línea (sin SPQ_JSON).
              Evita "transacción no confirmable" cuando SPK_PAGOSCXC ya abrió TRAN y SPQ_ENT_COL/SPQ_JSON falla anidado.
            */
            BEGIN TRY
                SET @CONSEC_ENT_RAW = ''
                EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE_JSON, '@ENT', @CONSEC_ENT_RAW OUTPUT

                IF COALESCE(@CONSEC_ENT_RAW, '') = ''
                BEGIN
                    RAISERROR('No se pudo generar el consecutivo de entrega DEVFACT (@ENT).', 16, 1)
                    RETURN
                END

                SET @CNSDEVOL = @SEDE_JSON + REPLACE(
                    SPACE(8 - LEN(@CONSEC_ENT_RAW)) + LTRIM(RTRIM(@CONSEC_ENT_RAW)),
                    SPACE(1),
                    0
                )
                SET @CNSDEVOL = LEFT(@CNSDEVOL, 20)

                INSERT INTO ENT (
                    CNSENTREGA, PROCESO, USUARIOENTREGA, FECHAENTREGA, USUARIORECIBE, USUARIO, COMPANIA,
                    ESTADO, ENT_ENTREGA, ENT_RECIBE, FECHARECIBE, IDSEDE, CERRADO, IDTERCERO, IDPLAN, MSEDE
                )
                VALUES (
                    @CNSDEVOL, 'DEVFACT', @USUARIO_JSON, DBO.FNK_GETDATE(), NULL, @USUARIO_JSON, @COMPANIA,
                    0, @IDDEPENTREGA, @IDDEPFACT, NULL, @SEDE_JSON, 0, NULL, NULL, 0
                )
            END TRY
            BEGIN CATCH
                SELECT @ERROR = ERROR_MESSAGE()
                RAISERROR('Error creando entrega DEVFACT: %s', 16, 1, @ERROR)
                RETURN
            END CATCH

            PRINT '@CNSDEVOL=' + COALESCE(@CNSDEVOL, 'NO TRAJE VALOR')

            -- Inserción cabecera devolución
            INSERT INTO ENTD(CNSENTREGA, NODOCUMENTO, PROCESO, ESTADO, USUARIOVERIFICA, MARCA, VALORENTREGA, OBSERVACION, ENDEVO, CNSDEVOL)
            SELECT @CNSDEVOL, LEFT(LTRIM(RTRIM(N_FACTURA)), 16), 'DEVFACT', 0, NULL, 0, NULL,
                   LEFT(CAST(OBSERVACION AS VARCHAR(2024)), 2024), 0, NULL
            FROM FPAGD
            WHERE CNSFPAG = @CNSPAGO

            -- Obtener nombre del equipo
            SELECT @SYS_COMPUTERNAME = COALESCE(U.SYS_ComputerName, HOST_NAME())   
            FROM USUSU U 
            LEFT JOIN UBEQ E ON U.SYS_ComputerName = E.SYS_ComputerName
            WHERE U.USUARIO = @USUARIO
                    
            -- Cursor para marcar facturas originales como devueltas
            DECLARE ENTDDEV_CURSOR CURSOR LOCAL FAST_FORWARD FOR 
            SELECT NODOCUMENTO FROM ENTD WHERE CNSENTREGA = @CNSDEVOL
            
            OPEN ENTDDEV_CURSOR    
            FETCH NEXT FROM ENTDDEV_CURSOR INTO @NODOCUMENTO
            
            WHILE @@FETCH_STATUS = 0    
            BEGIN 
                SELECT TOP 1 @CNSENTREGAORI = CNSENTREGA 
                FROM ENTD 
                WHERE NODOCUMENTO = @NODOCUMENTO 
                  AND PROCESO = 'FACTURAS' 
                  AND COALESCE(ENDEVO, 0) = 0

                IF COALESCE(@CNSENTREGAORI, '') <> ''
                BEGIN
                    UPDATE ENTD 
                    SET ENDEVO = 1, CNSDEVOL = @CNSDEVOL 
                    WHERE CNSENTREGA = @CNSENTREGAORI AND NODOCUMENTO = @NODOCUMENTO
                END
                
                FETCH NEXT FROM ENTDDEV_CURSOR INTO @NODOCUMENTO
            END
            
            CLOSE ENTDDEV_CURSOR
            DEALLOCATE ENTDDEV_CURSOR

            -- Actualización de estados finales
            UPDATE ENTD SET ESTADO = 1, USUARIOVERIFICA = @USUARIO WHERE CNSENTREGA = @CNSDEVOL AND PROCESO = 'DEVFACT'
            UPDATE ENT SET ESTADO = 1, CERRADO = 1, USUARIORECIBE = @USUARIO WHERE CNSENTREGA = @CNSDEVOL
     
            UPDATE FTR 
            SET IDDEP = DBO.FNK_VALORVARIABLE('IDFDEPFACTURACION'), INDCARTERA = 0, INDASIGENT = 0
            FROM FTR 
            INNER JOIN ENTD ON FTR.N_FACTURA = ENTD.NODOCUMENTO
            WHERE ENTD.CNSENTREGA = @CNSDEVOL

            PRINT 'SE PROCEDE A ANULAR FACTURAS'

            -- Cursor para anulación individual
            DECLARE ANULA_CURSOR CURSOR LOCAL FAST_FORWARD FOR
            SELECT LEFT(LTRIM(RTRIM(N_FACTURA)), 16),
                   LEFT(CAST(OBSERVACION AS VARCHAR(512)), 512)
            FROM FPAGD
            WHERE CNSFPAG = @CNSPAGO
            ORDER BY N_FACTURA

            OPEN ANULA_CURSOR    
            FETCH NEXT FROM ANULA_CURSOR INTO @N_FACTURA, @OBSERVACION
            
            WHILE @@FETCH_STATUS = 0    
            BEGIN 
                PRINT 'Anulando factura: ' + @N_FACTURA
                -- Ejecución del procedimiento de anulación
                EXEC SPK_ANULA_FACT @N_FACTURA, '01', @SEDE, @USUARIO, @OBSERVACION, @SYS_COMPUTERNAME, @USUARIO, 0
                
                FETCH NEXT FROM ANULA_CURSOR INTO @N_FACTURA, @OBSERVACION
            END
            
            CLOSE ANULA_CURSOR
            DEALLOCATE ANULA_CURSOR
        END
        ELSE IF @FINDEVOL = 2
        BEGIN
            PRINT 'VOY A CREAR UNA NUEVA CXC'
            PRINT 'Creando la CXC'

            SELECT @OBSERVACION = LTRIM(RTRIM(OBSERVACION)) FROM USVGS WHERE IDVARIABLE = 'FCXC_OBSERVACION_DEF'
            SELECT @COORFACTURACION = LEFT(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('USUARIOJEFEFACTURA'))), 20),
                   @COORCARTERA = LEFT(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('USUARIOJEFECARTERA'))), 20)
            SELECT @IDTERCERO = IDTERCERO FROM FPAG WHERE CNSFPAG = @CNSPAGO

            -- Generación de consecutivo
            BEGIN TRY
                PRINT 'AQUI LLAMO A GENCONSECUTIVO @IDSEDE=' + COALESCE(@SEDE, 'SIN SEDE') 
                DECLARE @CONSECUTIVO_RAW VARCHAR(20) = ''
                
                -- Nota: Asumiendo que SPK_GENCONSECUTIVO llena la variable de salida correctamente
                EXEC SPK_GENCONSECUTIVO '01', @SEDE, '@CXC', @CONSECUTIVO_RAW OUTPUT  


                
                IF @CONSECUTIVO_RAW IS NULL OR @CONSECUTIVO_RAW = ''
                BEGIN
                     RAISERROR('No se pudo generar el consecutivo para CXC.', 16, 1)
                     RETURN
                END

                -- Formateo manual del consecutivo (Sede + Relleno ceros)
                SELECT @CNSCXC = @SEDE + RIGHT(REPLICATE('0', 8) + LTRIM(RTRIM(@CONSECUTIVO_RAW)), 8)
                
                PRINT '@CNSCXC GENERADO=' + @CNSCXC
            END TRY
            BEGIN CATCH
                SELECT @ERROR = ERROR_MESSAGE()
                RAISERROR('Error generando consecutivo: %s', 16, 1, @ERROR)
                RETURN
            END CATCH

            -- Inserción Cabecera CXC
            BEGIN TRY
                INSERT INTO FCXC(CNSCXC, FECHACXC, IDTERCERO, IDMENSAJERO, F_VENCE, INDRECIBIDO, F_RECIBIDO, QUIENRECIBIO, NOREFERENCIAEXT, USUARIO, COMPANIA, VALORDEVUELTO, CERRADA, TIENEGLOSAS, TIENEDEVOLUCION, CNSANT, 
                                ANTIGUA, VALORCXC, DEDUCCIONES, VALORCXCNETO, VLRPAGOS, VLRNOTADB, VLRNOTACR, SALDO, SALDONETO, VLRGLOSAS, VLRGLOSAS_R, VLREXTRA, OBSERVACION, NROCOMPROBANTE, PROCEDENCIA, 
                                ENPRESUPUESTO, MARCAFAC, ITFC, CNSITFC, CONTABILIZADA, OBSCARTA, IDSEDE, MODALIDAD, ATENCION, MES, ANO, REGIMEN, NROGUIA, USUCIERRA, F_CIERRA, ESTADO, COORFACTURACION, COORCARTERA, 
                                NOPOS, FRADICAEPS, FENVIO, SUCURSAL, MSEDE)
                SELECT @CNSCXC, DBO.FNK_GETDATE(), @IDTERCERO, NULL, NULL, 0, NULL, NULL, NULL, @USUARIO, '01', 0, 0, 0, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, @OBSERVACION, NULL, 'CARTERA', 
                0, 0, 0, NULL, 0, NULL, @SEDE, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Activa', @COORFACTURACION, @COORCARTERA, 0, NULL, NULL, NULL, @MSEDE                    
            END TRY
            BEGIN CATCH
                SELECT @ERROR = ERROR_MESSAGE()
                RAISERROR('Error insertando cabecera FCXC: %s', 16, 1, @ERROR)
                RETURN
            END CATCH

            -- Inserción Detalle CXC
            BEGIN TRY
                INSERT INTO FCXCD(CNSCXC, N_FACTURA, USUARIO, COMPANIA, VALORFACTURA, DEDUCCIONES, VALORFACTURANETO, VLRPAGOS, VLRNOTADB, VLRNOTACR, SALDO, SALDONETO, CERRADA, TIENEGLOSAS, TIENEDEVOLUCION, MARCAPAGO, 
                                NT_MARCAP, VLRGLOSAS, VLRGLOSAS_R, VLREXTRA, NROCOMPROBANTE, CUENTA, DESCRIPCION, NOREFERENCIAEXT, ENCOBROJUR, IDPLAN, ITFC, CNSITFC, VLRFCES, VLRLEVANTADO, MARCA, USURESP, RESPUESTA, 
                                RAZONDEVOL)
                SELECT @CNSCXC, FTR.N_FACTURA, @USUARIO, '01', FTR.VR_TOTAL, 0, FTR.VR_TOTAL, 0, 0, 0, FTR.VR_TOTAL, FTR.VR_TOTAL, 0, 0, 0, 0,
                        0, 0, 0, 0, NULL, FTR.CUENTACXC, 'Respuesta Devolución de Facturas', NULL, 0, FTR.IDPLAN, 0, NULL, 0, 0, 0, NULL, NULL,
                        LEFT(CAST(FPAGD.OBSERVACION AS VARCHAR(1024)), 1024)
                FROM FPAGD 
                INNER JOIN FTR ON FPAGD.N_FACTURA = FTR.N_FACTURA
                WHERE FPAGD.CNSFPAG = @CNSPAGO

                -- Validación post-inserción
                IF @@ROWCOUNT = 0
                BEGIN
                    RAISERROR('No se insertaron detalles en FCXCD. Verifique las facturas asociadas al pago.', 16, 1)
                    RETURN
                END
            END TRY
            BEGIN CATCH
                SELECT @ERROR = ERROR_MESSAGE()
                RAISERROR('Error insertando detalle FCXCD: %s', 16, 1, @ERROR)
                RETURN
            END CATCH

            -- Actualización de FTR
            UPDATE FTR 
            SET INDCARTERA = 1,
                FECHAPASOCXC = DBO.FNK_GETDATE(),
                IDDEP = DBO.FNK_VALORVARIABLE('IDFDEPCARTERA'),
                INDASIGENT = 0,
                INDASIGCXC = 1,
                CLASE = CASE WHEN COALESCE(FTR.CLASE, '') <> 'C' THEN 'C' ELSE FTR.CLASE END
            FROM FTR 
            INNER JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA
            WHERE FCXCD.CNSCXC = @CNSCXC

            -- Reliquidación final
            EXEC SPK_RELIQUIDACXCQX @CNSCXC
            
            PRINT 'CXC CREADA EXITOSAMENTE: ' + @CNSCXC
        END
        ELSE
        BEGIN
            RAISERROR('El parámetro @FINDEVOL debe ser 1 (Anular) o 2 (Crear CXC).', 16, 1)
            RETURN
        END

    END TRY
    BEGIN CATCH
        SELECT @ERROR = ERROR_MESSAGE()
        /* Si la transacción del llamador (p. ej. SPK_PAGOSCXC) quedó no confirmable, revertir antes de RAISERROR. */
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION
        RAISERROR('Error crítico en SPK_FINALIDAD_DEVOL: %s', 16, 1, @ERROR)
        RETURN
    END CATCH
END

