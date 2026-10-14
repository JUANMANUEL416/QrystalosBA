CREATE OR ALTER  PROCEDURE dbo.SPK_REVERSAR_RECUADO 
    @NROCOMPROBANTE      VARCHAR(20),
    @CNSFPAG             VARCHAR(20),
    @COMPANIA            VARCHAR(2),
    @SEDE                VARCHAR(5),
    @USUARIO             VARCHAR(12),
    @SYS_COMPUTERNAME    VARCHAR(254),
    @NROCOMPROBANTEDEST  VARCHAR(20),
    @N_FACTURA           VARCHAR(20) = '',
    @ITEM                SMALLINT   = 0
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NVOCONSEC     VARCHAR(20) = '';
    DECLARE @NOREFERENCIA  VARCHAR(20) = '';
    DECLARE @PREFIJO_USCXS VARCHAR(20);
    DECLARE @COM           VARCHAR(2);
    DECLARE @ANO           VARCHAR(4);
    DECLARE @MES           VARCHAR(2);
    DECLARE @VALORB        DECIMAL(14,2) = 0;
    DECLARE @CNSCXC        VARCHAR(20) = '';
    DECLARE @CXC_R         VARCHAR(20);
    DECLARE @N_fAC_R       VARCHAR(20);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Obtener CNSCXC si se pasa factura
        IF @N_FACTURA <> ''
        BEGIN
            SELECT @CNSCXC = CNSCXC 
            FROM dbo.FPAGD 
            WHERE N_FACTURA = @N_FACTURA 
              AND ITEM = @ITEM 
              AND CNSFPAG = @CNSFPAG;
        END

        -- 2. Generar nuevo comprobante si no hay destino
        IF ISNULL(@NROCOMPROBANTEDEST, '') = ''
        BEGIN
            SET @COM = LTRIM(RTRIM(ISNULL(dbo.FNK_VALORVARIABLE('IDCON_TCOM_CXC'), '')));
            IF @COM = '' SET @COM = LTRIM(RTRIM(ISNULL(dbo.FNK_VALORVARIABLE('IDCON_TCOM_DEFAULT'), '')));
            IF @COM = '' SET @COM = 'IX';

            SET @ANO = CAST(YEAR(GETDATE()) AS VARCHAR(4));
            SET @MES = RIGHT('0' + CAST(MONTH(GETDATE()) AS VARCHAR(2)), 2);
            
            -- OJO: Concatena literal '@COM' + valor de @COM. Verificar si es intencional.
            SET @PREFIJO_USCXS = '@COM' + @COM;
            SET @NOREFERENCIA = SPACE(20);

            EXEC dbo.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, @PREFIJO_USCXS, @NOREFERENCIA OUTPUT;
            SET @NOREFERENCIA = RIGHT('00000000' + LTRIM(RTRIM(@NOREFERENCIA)), 8);

            SET @NVOCONSEC = SPACE(20);
            EXEC dbo.SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@MCP', @NVOCONSEC OUTPUT;
            SET @NVOCONSEC = @SEDE + RIGHT('00000000' + LTRIM(RTRIM(@NVOCONSEC)), 8);

            -- Insertar cabecera contable
            INSERT INTO dbo.MCPE (COMPANIA, NROCOMPROBANTE, PROCEDENCIA, NOREFERENCIA, ANO, MES, FECHACONTABLE, 
                                  TOTALDEBITO, TOTALCREDITO, REFERENCIA1, REFERENCIA2, USUARIO, FECHA, LOTE, 
                                  OBSERVACION, IDSEDE, ESTADO, COMPROBANTE, IDTERCERO, REFERENCIA3, BANCO, 
                                  NOCHEQUE, ANULADO, RPT_COMPROBANTE, VALOR_CHEQUE, FECHARADICACION)
            SELECT COMPANIA, @NVOCONSEC, PROCEDENCIA, @NOREFERENCIA, @ANO, @MES, GETDATE(), 0, 0,
                   REFERENCIA1, REFERENCIA2, @USUARIO, dbo.FNK_FECHA_SIN_MLS(GETDATE()), 'REV',
                   LEFT('REVERSION: ' + ISNULL(OBSERVACION, ''), 512),
                   IDSEDE, 0, @COM, IDTERCERO, @NROCOMPROBANTE, BANCO, NOCHEQUE, ANULADO, 
                   RPT_COMPROBANTE, VALOR_CHEQUE, FECHARADICACION
            FROM dbo.MCP
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE;
        END

        -- 3. Detalle Contable (MCHE)
        DELETE FROM dbo.MCHE WHERE NROCOMPROBANTE = @NVOCONSEC;

        INSERT INTO dbo.MCHE (NROCOMPROBANTE, COMPANIA, TIPO, CUENTA, IDTERCERO, CCOSTO, DETALLE, VALOR,
                              REFERENCIA1, REFERENCIA2, ITEMREF, USUARIO, FECHA, PREFIJO, IDAREA,
                              CLASECONT, ESTADO, PROCESO, REFERENCIA3, CNSPAGO, GENERA, F_FACTURAREF,
                              F_VENCE, VALOR_PORCIMP, BASE_IMP, CLASE_GENERA, N_FACTURA, PROCEDENCIA,
                              REFERENCIA_PRO, CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR)
        SELECT @NVOCONSEC, COMPANIA,
               CASE
                   WHEN LTRIM(RTRIM(TIPO)) = 'DB' THEN 'CR'
                   WHEN LTRIM(RTRIM(TIPO)) = 'CR' THEN 'DB'
                   ELSE LTRIM(RTRIM(TIPO))
               END,
               CUENTA, IDTERCERO, CCOSTO, DETALLE, VALOR, REFERENCIA1, REFERENCIA2, ITEMREF,
               @USUARIO, dbo.FNK_FECHA_SIN_MLS(GETDATE()), PREFIJO, IDAREA, CLASECONT, 1, 'REVERSION', 
               REFERENCIA3, CNSPAGO, GENERA, F_FACTURAREF, F_VENCE, VALOR_PORCIMP, BASE_IMP, 
               CLASE_GENERA, N_FACTURA, PROCEDENCIA, REFERENCIA_PRO, CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR
        /* Reversion completa (@N_FACTURA=''): voltear TODAS las lineas MCH del comprobante.
           En BANCOS/CAJA el debito del banco no trae REFERENCIA1 = CNSFPAG (suele ser la sede,
           PROCESO DEP_CLIENTES_%). Filtrar solo por CNSFPAG copia los creditos CXC y, al invertirlos,
           el comprobante nuevo queda solo con DB. */
        FROM dbo.MCH
        WHERE NROCOMPROBANTE = @NROCOMPROBANTE
          AND (
              @N_FACTURA = ''
              OR (
                  MCH.N_FACTURA = @N_FACTURA
                  AND (@CNSFPAG = '' OR MCH.REFERENCIA1 = @CNSFPAG)
                  AND (@CNSCXC = '' OR MCH.REFERENCIA2 = @CNSCXC)
                  AND (@ITEM = 0 OR MCH.ITEMREF = @ITEM)
              )
          );

        -- 4. Ajuste por bancos/caja
        IF EXISTS (SELECT 1 FROM dbo.FPAG WHERE CNSFPAG = @CNSFPAG AND INGRESO IN ('BANCOS', 'CAJA')) 
           AND @N_FACTURA <> ''
        BEGIN
            EXEC dbo.SPK_NC_SUMA_DBCR @NVOCONSEC;

            SELECT @VALORB = TOTALCREDITO - TOTALDEBITO 
            FROM dbo.MCPE 
            WHERE NROCOMPROBANTE = @NVOCONSEC;

            INSERT INTO dbo.MCHE (NROCOMPROBANTE, COMPANIA, TIPO, CUENTA, IDTERCERO, CCOSTO, DETALLE, VALOR,
                                  REFERENCIA1, REFERENCIA2, ITEMREF, USUARIO, FECHA, PREFIJO, IDAREA,
                                  CLASECONT, ESTADO, PROCESO, REFERENCIA3, CNSPAGO, GENERA, F_FACTURAREF,
                                  F_VENCE, VALOR_PORCIMP, BASE_IMP, CLASE_GENERA, N_FACTURA, PROCEDENCIA,
                                  REFERENCIA_PRO, CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR)
            SELECT @NVOCONSEC, COMPANIA, 'CR', CUENTA, IDTERCERO, CCOSTO, DETALLE, ABS(@VALORB), 
                   REFERENCIA1, REFERENCIA2, ITEMREF, @USUARIO, dbo.FNK_FECHA_SIN_MLS(GETDATE()), 
                   PREFIJO, IDAREA, CLASECONT, 1, 'REVERSION', REFERENCIA3, CNSPAGO, GENERA, F_FACTURAREF, 
                   F_VENCE, VALOR_PORCIMP, BASE_IMP, CLASE_GENERA, N_FACTURA, PROCEDENCIA, REFERENCIA_PRO, 
                   CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR
            FROM dbo.MCH
            WHERE NROCOMPROBANTE = @NROCOMPROBANTE
              AND ISNULL(N_FACTURA, '') = ''
              AND TIPO = 'DB'
              AND PROCESO LIKE 'DEP_CLIENTES_%';
        END

        -- 5. Validaciones y confirmaci�n
        EXEC dbo.SPK_NC_REVISAR_COMPROBANTE '01', @NVOCONSEC;
        EXEC dbo.SPK_NC_REVISAMCPE @NVOCONSEC, @COMPANIA, @USUARIO, @SEDE, @SYS_COMPUTERNAME;

        IF EXISTS (SELECT 1 FROM dbo.MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE AND ESTADO <> 2)
        BEGIN
            EXEC dbo.SPK_NC_CONFIRMAR_CONTAB @NVOCONSEC, @USUARIO, @COMPANIA, @SEDE, @SYS_COMPUTERNAME, 
                                             @ANO, @MES, 'CXC', '', 'CONTABILIZAR';
        END

        -- 6. Actualizaci�n de estados y desactivaci�n temporal de trigger
        IF @N_FACTURA <> ''
        BEGIN
            ALTER TABLE dbo.FPAGD DISABLE TRIGGER TK_FPAGD_ADDFACTURAS;
            
            UPDATE dbo.FPAGD 
            SET ESTADO = 'Retirada',
                CONTABILIZADA_R = 1,
                NROCOMPROBANTE_R = @NVOCONSEC
            WHERE CNSFPAG = @CNSFPAG 
              AND N_FACTURA = @N_FACTURA 
              AND CNSCXC = @CNSCXC 
              AND ITEM = @ITEM;
              
            ALTER TABLE dbo.FPAGD ENABLE TRIGGER TK_FPAGD_ADDFACTURAS;

            DELETE FROM dbo.FGLO 
            WHERE N_FACTURA = @N_FACTURA 
              AND CNSFPAG = @CNSFPAG 
              AND CNSCXC = @CNSCXC;

            EXEC dbo.SPK_RELIQUIDA_FTR @CNSCXC, @N_FACTURA;
        END
        ELSE
        BEGIN
            IF (SELECT INGRESO FROM dbo.FPAG WHERE CNSFPAG = @CNSFPAG) = 'GLOSAS'
            BEGIN
                DELETE FROM dbo.FGLO 
                WHERE CNSFPAG = @CNSFPAG 
                  AND CNSCXC = @CNSCXC;
            END

            DECLARE REVPAG_CURSOR CURSOR LOCAL FAST_FORWARD FOR 
            SELECT DISTINCT CNSCXC, N_FACTURA 
            FROM dbo.FPAGD 
            WHERE CNSFPAG = @CNSFPAG;

            OPEN REVPAG_CURSOR;
            FETCH NEXT FROM REVPAG_CURSOR INTO @CXC_R, @N_fAC_R;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.SPK_RELIQUIDA_FTR @CXC_R, @N_fAC_R;
                FETCH NEXT FROM REVPAG_CURSOR INTO @CXC_R, @N_fAC_R;
            END;

            CLOSE REVPAG_CURSOR;
            DEALLOCATE REVPAG_CURSOR;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
