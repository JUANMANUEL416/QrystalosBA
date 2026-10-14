CREATE OR ALTER PROCEDURE dbo.SPK_GEN_CXP_LIQIMP
    @ANO               SMALLINT,
    @MES               SMALLINT,
    @CUENTAINI         VARCHAR(20),
    @CUENTAFINAL       VARCHAR(20),
    @IDTERCERO         VARCHAR(20) = NULL,
    @F_CERTIFICADO     DATE = NULL,
    @USUARIO           VARCHAR(20),
    @COMPANIA          VARCHAR(2) = '01',
    @SEDE              VARCHAR(6),
    @SYS_COMPUTERNAME  VARCHAR(254),
    @CNSFCXP           VARCHAR(20) OUTPUT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IDTERCERO_DIAN     VARCHAR(20);
    DECLARE @TOTAL_CXP          DECIMAL(14,2);
    DECLARE @OBSERVACION        VARCHAR(500);
    DECLARE @ITEM               INT;
    DECLARE @FVENCE             DATETIME;
    DECLARE @CUECREDITO         VARCHAR(20);
    DECLARE @NOREF              VARCHAR(30);
    DECLARE @LIQIMP_ASUM        INT;
    DECLARE @NROCOMPROBANTE_REF VARCHAR(20);

    BEGIN TRY
        -- Sanitizaci�n e inicializaci�n de par�metros
        SET @CUENTAINI     = LTRIM(RTRIM(COALESCE(@CUENTAINI, '')));
        SET @CUENTAFINAL   = LTRIM(RTRIM(COALESCE(@CUENTAFINAL, '')));
        SET @IDTERCERO     = NULLIF(LTRIM(RTRIM(@IDTERCERO)), '');
        SET @F_CERTIFICADO = COALESCE(@F_CERTIFICADO, GETDATE());

        -- Validaciones de entrada
        IF @CUENTAINI = '' OR @CUENTAFINAL = ''
        BEGIN
            RAISERROR('Debe indicar cuenta inicial y cuenta final.', 16, 1);
            RETURN;
        END

        SET @IDTERCERO_DIAN = LTRIM(RTRIM(COALESCE(dbo.FNK_VALORVARIABLE('IDTERCERO_DIAN'), '')));
        IF @IDTERCERO_DIAN = ''
            SET @IDTERCERO_DIAN = LTRIM(RTRIM(COALESCE(dbo.FNK_VALORVARIABLE('TERCERO_DIAN'), '')));

        IF @IDTERCERO_DIAN = '' OR NOT EXISTS (SELECT 1 FROM TER WHERE IDTERCERO = @IDTERCERO_DIAN)
        BEGIN
            RAISERROR('Variable de sistema IDTERCERO_DIAN no configurada o tercero DIAN inexistente en TER.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES)
        BEGIN
            RAISERROR('No existe periodo contable PRI para el a�o y mes indicados,o esta cerrado', 16, 1);
            RETURN;
        END

        --IF EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES AND CERRADO = 1)
        --BEGIN
        --    RAISERROR('El periodo contable ya fue CERRADO', 16, 1);
        --    RETURN;
        --END

        IF EXISTS (SELECT 1 FROM PRI WHERE ANO = @ANO AND MES = @MES AND COALESCE(CERRADO_IMP, 0) = 1)
        BEGIN
            RAISERROR('El periodo ya fue cerrado para liquidaci�n de impuestos (CERRADO_IMP=1).', 16, 1);
            RETURN;
        END

        SET @LIQIMP_ASUM = CASE WHEN dbo.FNK_VALORVARIABLE('LIQIMPASUMIDO') = 'NO' THEN 1 ELSE 4 END;

        -- Construcci�n de tabla temporal de movimientos a liquidar
        IF OBJECT_ID('tempdb..#MCH_LIQ') IS NOT NULL 
            DROP TABLE #MCH_LIQ;

        SELECT MCH.NROCOMPROBANTE,
               MCH.IDTERCERO,
               MCH.CUENTA,
               MCH.REFERENCIA1,
               MCH.REFERENCIA2,
               MCH.TIPO,
               MCH.VALOR
        INTO   #MCH_LIQ
        FROM   MCP
               INNER JOIN MCH ON MCP.NROCOMPROBANTE = MCH.NROCOMPROBANTE
               INNER JOIN CUE ON MCH.CUENTA = CUE.CUENTA
        WHERE  MCP.ANO = @ANO
          AND  MCP.MES = @MES
          AND  MCP.ESTADO = 2
          AND  COALESCE(MCP.ANULADO, 0) <> 1
          AND  CUE.IMPUESTO = 1
          AND  CUE.COMPANIA = @COMPANIA
          AND  NOT (MCH.BASE_IMP IS NULL OR MCH.BASE_IMP = 0)
          AND  COALESCE(MCH.LIQUI_IMP, 0) = 0
          AND  MCH.CUENTA >= @CUENTAINI
          AND  MCH.CUENTA <= @CUENTAFINAL
          AND  (@IDTERCERO IS NULL OR MCH.IDTERCERO = @IDTERCERO)
          AND  NOT EXISTS (
                   SELECT 1
                   FROM   FCXPI
                   WHERE  COALESCE(FCXPI.IMPUESTO_ASUM, 0) = @LIQIMP_ASUM
                     AND  MCH.CNSPAGO = FCXPI.CNSFCXPI
                     AND  FCXPI.IDIMPUESTO = MCH.REFERENCIA1
                     AND  FCXPI.IDCLASE = MCH.REFERENCIA2
                     AND  FCXPI.ITEM = CASE WHEN ISNUMERIC(MCH.REFERENCIA3) = 0 THEN 0 ELSE MCH.REFERENCIA3 END
               );

        IF NOT EXISTS (SELECT 1 FROM #MCH_LIQ)
        BEGIN
            RAISERROR('No hay movimientos pendientes de liquidaci�n para el periodo y filtros indicados.', 16, 1);
            RETURN;
        END

        /* Comprobante ya contabilizado del periodo (referencia FCXP; no genera asiento nuevo) */
        SELECT @NROCOMPROBANTE_REF = MIN(LTRIM(RTRIM(L.NROCOMPROBANTE)))
        FROM   (SELECT DISTINCT NROCOMPROBANTE FROM #MCH_LIQ) L
        WHERE  NULLIF(LTRIM(RTRIM(L.NROCOMPROBANTE)), '') IS NOT NULL;

        IF @NROCOMPROBANTE_REF IS NULL
           OR NOT EXISTS (
                 SELECT 1
                 FROM   MCP
                 WHERE  NROCOMPROBANTE = @NROCOMPROBANTE_REF
                   AND  ESTADO = 2
                   AND  COALESCE(ANULADO, 0) <> 1
              )
        BEGIN
            RAISERROR('No se encontr� comprobante contable de referencia para la CxP de liquidaci�n.', 16, 1);
            RETURN;
        END

        -- Agrupaci�n de detalles de liquidaci�n
        IF OBJECT_ID('tempdb..#DET_LIQ') IS NOT NULL 
            DROP TABLE #DET_LIQ;

        SELECT L.CUENTA,
               MAX(L.REFERENCIA1) AS IDIMPUESTO,
               MAX(L.REFERENCIA2) AS IDCLASE,
               SUM(CASE WHEN L.TIPO = 'DB' THEN L.VALOR ELSE 0 END) AS DEBITOS,
               SUM(CASE WHEN L.TIPO = 'CR' THEN L.VALOR ELSE 0 END) AS CREDITOS,
               NTZ.TIPO AS NTZ_TIPO
        INTO   #DET_LIQ
        FROM   #MCH_LIQ L
               INNER JOIN NTZ ON NTZ.N_INICIAL = LEFT(L.CUENTA, 1)
        GROUP BY 
               L.CUENTA,
               NTZ.TIPO;

        SELECT @TOTAL_CXP = COALESCE(SUM(
                   CASE D.NTZ_TIPO
                       WHEN 'DB' THEN D.DEBITOS - D.CREDITOS
                       WHEN 'CR' THEN D.CREDITOS - D.DEBITOS
                       ELSE 0
                   END), 0)
        FROM   #DET_LIQ D;

        IF COALESCE(@TOTAL_CXP, 0) <= 0
        BEGIN
            RAISERROR('El total a liquidar del periodo es cero o negativo.', 16, 1);
            RETURN;
        END

        -- Generaci�n de consecutivo y variables auxiliares
        SET @CNSFCXP = SPACE(20);
        EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, '@FCXPSR', @CNSFCXP OUTPUT;
        SELECT @CNSFCXP = @SEDE + 'SR' + REPLACE(SPACE(6 - LEN(@CNSFCXP)) + LTRIM(RTRIM(@CNSFCXP)), SPACE(1), '0');

        SET @NOREF       = 'LIQIMP' + RIGHT('0' + CAST(@MES AS VARCHAR(2)), 2) + CAST(@ANO AS VARCHAR(4));
        SET @OBSERVACION = 'Liquidaci�n Impuestos periodo ' + RIGHT('0' + CAST(@MES AS VARCHAR(2)), 2) + '/' + CAST(@ANO AS VARCHAR(4));
        SET @FVENCE      = DATEFROMPARTS(@ANO, @MES, 1);
        SET @CUECREDITO  = NULL;

        -- Proceso Transaccional
        BEGIN TRANSACTION;

            INSERT INTO FCXP (
                CNSFCXP, FECHA, IDTERCERO, NOREFERENCIA, F_FACTURAREF, F_VENCE,
                VALOR, ESTADO, USUARIO, PROCEDENCIA, OBSERVACION, CUECREDITO,
                COMPANIA, SYS_COMPUTERNAME, MARCACONT, CONTABILIZADA, NROCOMPROBANTE,
                TIPOCXP, SALDO, VLR_DESCUENTO, VLR_IVA, VLR_NETO, VLR_IMPUESTOS,
                VLR_NOTASDEBITO, VLR_COMISION, IDSEDE
            )
            VALUES (
                @CNSFCXP,
                dbo.FNK_FECHA_SIN_MLS(GETDATE()),
                @IDTERCERO_DIAN,
                @NOREF,
                dbo.FNK_FECHA_SIN_MLS(@F_CERTIFICADO),
                dbo.FNK_FECHA_SIN_MLS(@FVENCE),
                @TOTAL_CXP, 'N', @USUARIO, 'Servicios', @OBSERVACION, @CUECREDITO,
                @COMPANIA, @SYS_COMPUTERNAME, 1, 1, @NROCOMPROBANTE_REF,
                dbo.FNK_VALORVARIABLE('IDTIPOCXP_DEFAULT'),
                @TOTAL_CXP, 0, 0, @TOTAL_CXP, 0,
                0, 0, @SEDE
            );

            SET @ITEM = 0;

            INSERT INTO FCXPD (
                CNSFCXP, ITEM, IDSERVICIO, CANTIDAD, VALOR, ESTADO,
                VLR_DESCUENTO, VLR_IVA, VLR_NETO, PROCEDENCIA, CUENTA_SER, PREFIJO, COD_EXT, DESC_EXT
            )
            SELECT @CNSFCXP,
                   ROW_NUMBER() OVER (ORDER BY D.CUENTA, D.IDIMPUESTO, D.IDCLASE) AS ITEM,
                   COALESCE(NULLIF(LTRIM(RTRIM(D.IDCLASE)), ''), 'LIQIMP') AS IDSERVICIO,
                   1,
                   CASE D.NTZ_TIPO
                       WHEN 'DB' THEN D.DEBITOS - D.CREDITOS
                       WHEN 'CR' THEN D.CREDITOS - D.DEBITOS
                       ELSE 0
                   END AS VALOR,
                   'P',
                   0, 
                   0,
                   CASE D.NTZ_TIPO
                       WHEN 'DB' THEN D.DEBITOS - D.CREDITOS
                       WHEN 'CR' THEN D.CREDITOS - D.DEBITOS
                       ELSE 0
                   END AS VLR_NETO,
                   'Servicios',
                   D.CUENTA,
                   COALESCE(NULLIF(LTRIM(RTRIM(D.IDIMPUESTO)), ''), ''),
                   COALESCE(NULLIF(LTRIM(RTRIM(D.IDCLASE)), ''), 'LIQIMP') AS COD_EXT,
                   COALESCE(
                       (SELECT TOP 1 F.DESCRIPCION
                        FROM   FIMPD F
                        WHERE  F.IDIMPUESTO = COALESCE(NULLIF(LTRIM(RTRIM(D.IDIMPUESTO)), ''), '')
                          AND  F.IDCLASE = COALESCE(NULLIF(LTRIM(RTRIM(D.IDCLASE)), ''), '')),
                       'Liquidaci�n impuesto ' + LTRIM(RTRIM(D.CUENTA))
                   ) AS DESC_EXT
            FROM   #DET_LIQ D
            WHERE  CASE D.NTZ_TIPO
                       WHEN 'DB' THEN D.DEBITOS - D.CREDITOS
                       WHEN 'CR' THEN D.CREDITOS - D.DEBITOS
                       ELSE 0
                   END <> 0;

            -- Actualizaci�n de MCH omitiendo triggers de sistema
            ALTER TABLE MCH DISABLE TRIGGER TK_MCH_MOVIMIENTOS;

            UPDATE MCH
            SET    LIQUI_IMP = 1,
                   CNSFCXP   = @CNSFCXP
            WHERE  EXISTS (
                       SELECT 1
                       FROM   #MCH_LIQ T
                       WHERE  MCH.NROCOMPROBANTE = T.NROCOMPROBANTE
                         AND  MCH.IDTERCERO = T.IDTERCERO
                         AND  MCH.CUENTA = T.CUENTA
                         AND  COALESCE(MCH.REFERENCIA1, '') = COALESCE(T.REFERENCIA1, '')
                         AND  COALESCE(MCH.REFERENCIA2, '') = COALESCE(T.REFERENCIA2, '')
                         AND  MCH.TIPO = T.TIPO
                         AND  MCH.VALOR = T.VALOR
                   );

            ALTER TABLE MCH ENABLE TRIGGER TK_MCH_MOVIMIENTOS;

            -- Procesos finales de cierre y rec�lculo
            EXEC SPK_CALCULOVALORESCXP @CNSFCXP;

            UPDATE PRI
            SET    CERRADO_IMP = 1
            WHERE  ANO = @ANO
              AND  MES = @MES;

        COMMIT TRANSACTION;

        -- Salida de control
        DECLARE @ITEMS_FCXPD INT = (
            SELECT COUNT(*) 
            FROM   #DET_LIQ D
            WHERE  CASE D.NTZ_TIPO
                       WHEN 'DB' THEN D.DEBITOS - D.CREDITOS
                       WHEN 'CR' THEN D.CREDITOS - D.DEBITOS
                       ELSE 0
                   END <> 0
        );

        SELECT 'OK' AS OK, 
               @CNSFCXP AS CNSFCXP, 
               @ANO AS ANO, 
               @MES AS MES, 
               @TOTAL_CXP AS TOTAL,
               @ITEMS_FCXPD AS ITEMS_FCXPD,
               (SELECT COUNT(*) FROM #MCH_LIQ) AS MOVIMIENTOS_MCH,
               @NROCOMPROBANTE_REF AS NROCOMPROBANTE_REF;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;

        DECLARE @ERR VARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ERR, 16, 1);
    END CATCH
END;
