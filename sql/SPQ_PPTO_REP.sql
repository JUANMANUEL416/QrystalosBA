CREATE OR ALTER PROCEDURE DBO.SPQ_PPTO_REP
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT dmy;

   DECLARE
    @PARAMETROS                  NVARCHAR(MAX),          @MODELO                  VARCHAR(100),          @METODO                VARCHAR(100),
    @USUARIO                     VARCHAR(12),            @SYS_COMPUTERNAME        VARCHAR(254),          @COMPANIA              VARCHAR(2),
    @CNSFPAG_PPTO                VARCHAR(20),            @SEDE                    VARCHAR(5),            @INGRESO_FPAG          VARCHAR(10),
    @ANIO_PAGO                   INT,                    @ANIO_ACT                INT,                   @TIPORECO              VARCHAR(20),
    @PLANES_SIN_RUBRO            NVARCHAR(MAX) = N'',    @ADVERTENCIA             NVARCHAR(500) = NULL,  @INGRESO               VARCHAR(20),
    @TIPO_FECHA                  VARCHAR(20),            @F_INICIAL               DATE,                  @F_FINAL               DATE,
    @F_FINAL_EX                  DATE,                   @IDTERCERO               VARCHAR(20),           @PRESUPUESTO           VARCHAR(1),
    @CONSECUTIVO                 VARCHAR(20),            @CNSFNOT_PPTO            VARCHAR(20),           @CONSECUTIVOPPTO       VARCHAR(20),
    @EST_NOTA_PPTO               VARCHAR(1),             @RUBRO_FNOT              VARCHAR(50),           @ESTADO_PPTO_FNOT      VARCHAR(20),
    @CONSECUTIVOPPTO_RECO_TER    VARCHAR(20),            @CONSECUTIVO_PAC         VARCHAR(20),           @MES_PAC               INT,
    @RUBRO_PAC                   VARCHAR(50),            @COMPANIA_PAC            VARCHAR(2),            @CNSRPDX_PAC           VARCHAR(20),
    @CNSRPDX_ANT_PAC             VARCHAR(20),            @IDSEDE_PAC              VARCHAR(5),            @COMPANIA_EGR          VARCHAR(2),
    @CODCAJA_EGR                 VARCHAR(20),            @F_INI_EGR               DATE,                  @F_FIN_EX_EGR          DATE,
    @CNSANT_ANT                  VARCHAR(20),            @CNSFCXP_ANT             VARCHAR(20),           @IDSEDE_ANT            VARCHAR(5),
    @N_FACTURA_FTR               VARCHAR(20),            @IDSEDE_FTR              VARCHAR(5),
    @CNSFCT_FTR                  VARCHAR(40),            @CONSECUTIVO_FTR         VARCHAR(20),           @CCOSTOPRESUP_FTR      VARCHAR(20),
    @RECO_FTR                    VARCHAR(20),            @FECHARECEP_FTR          DATETIME,              @ENPPTO_FTR            INT,
    @IDSEDEPPAL_FTR              VARCHAR(5),             @TIPORECO_FTR            VARCHAR(20),           @RECO_NUM_FTR          INT,
    @COMPANIA_FTR                VARCHAR(2),             @OBJETIVO_FTR            VARCHAR(512),          @CLASE_NOTA_ANU        VARCHAR(1),            
    @N_FACTURA_ANU               VARCHAR(20),            @ESTADO_PPTO_ANU         VARCHAR(20);

    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO     VARCHAR(100)  '$.MODELO',
        METODO     VARCHAR(100)  '$.METODO',
        USUARIO    VARCHAR(12)   '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    SELECT @MODELO = MODELO,
           @METODO = METODO,
           @PARAMETROS = PARAMETROS,
           @USUARIO = USUARIO
    FROM #JSON;

    SELECT @SYS_COMPUTERNAME = SYS_COMPUTERNAME,
           @COMPANIA = COMPANIA,
           @SEDE = IDSEDE
    FROM   USUSU
    WHERE  USUARIO = @USUARIO;

    IF COALESCE(@COMPANIA, '') = '' OR COALESCE(@SEDE, '') = ''
    BEGIN
        SELECT @COMPANIA = COMPANIA,
               @SEDE = IDSEDE
        FROM   UBEQ
        WHERE  SYS_ComputerName = @SYS_COMPUTERNAME;
    END;

    IF @METODO = 'PRESUPUESTO_FPAG'
    BEGIN
        SET @ANIO_ACT = YEAR(GETDATE());
        SET @TIPORECO = COALESCE(DBO.FNK_VALORVARIABLE('PRESUP_TIPORECO'), '');

        SELECT @CNSFPAG_PPTO = CNSFPAG,
               @SEDE = CASE
                  WHEN COALESCE(NULLIF(LTRIM(RTRIM(IDSEDE)), ''), '') <> '' THEN NULLIF(LTRIM(RTRIM(IDSEDE)), '')
                  ELSE @SEDE
               END
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            CNSFPAG VARCHAR(20) '$.CNSFPAG',
            IDSEDE  VARCHAR(5)  '$.IDSEDE'
        );

        IF COALESCE(@CNSFPAG_PPTO, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar CNSFPAG' AS ERROR;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM FPAG WHERE CNSFPAG = @CNSFPAG_PPTO)
        BEGIN
            SELECT 'KO' AS OK, 'Recaudo no encontrado' AS ERROR;
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM   FPAG
            WHERE  CNSFPAG = @CNSFPAG_PPTO
            AND    COALESCE(ENPRESUPUESTO, 0) <> 0
        )
        BEGIN
            SELECT 'KO' AS OK, 'El recaudo ya fue enviado a presupuesto' AS ERROR;
            RETURN;
        END;

        SELECT @ANIO_PAGO = YEAR(FECHAPAGO),
               @INGRESO_FPAG = INGRESO,
               @SEDE = CASE
                  WHEN COALESCE(@SEDE, '') <> '' THEN @SEDE
                  ELSE IDSEDE
               END
        FROM   FPAG
        WHERE  CNSFPAG = @CNSFPAG_PPTO;

        IF COALESCE(@SEDE, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar sede (IDSEDE)' AS ERROR;
            RETURN;
        END;

        IF COALESCE(@COMPANIA, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'No se pudo determinar COMPANIA del usuario. Verifique USUSU/UBEQ.' AS ERROR;
            RETURN;
        END;

        IF COALESCE(DBO.FNK_VALORVARIABLE('PRESUP_CCOSTO'), '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'No está configurada la variable PRESUP_CCOSTO (centro de costo presupuesto)' AS ERROR;
            RETURN;
        END;

        IF @INGRESO_FPAG IN ('GLOSAS', 'DEVOLUCION')
        BEGIN
            SELECT 'KO' AS OK, 'Los recaudos de glosas o devolución no se envían a presupuesto por este proceso' AS ERROR;
            RETURN;
        END;

        IF @ANIO_PAGO <> @ANIO_ACT
        BEGIN
            SET @ADVERTENCIA = 'Este recaudo es de una vigencia distinta a la actual';
        END;

        IF EXISTS (
            SELECT 1
            FROM   FPAGD A
            INNER JOIN FTR B ON A.N_FACTURA = B.N_FACTURA
            INNER JOIN PTRECO D
                ON B.CONSECUTIVOPTO = D.CONSECUTIVO
               AND B.RECO = D.RECO
            WHERE  A.CNSFPAG = @CNSFPAG_PPTO
            AND    D.ESTADO = 'NoConfirmado'
            AND    COALESCE(B.ENPRESUPUESTO, 0) = 1
        )
        BEGIN
            SELECT 'KO' AS OK,
                   CONCAT(
                       'Los Reconocimientos Para este Recaudo No estan Confirmados',
                       CHAR(13),
                       'Es Necesario Confirmar Los Reconocimientos Antes de Recaudarlos'
                   ) AS ERROR;
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM   FPAGD A
            INNER JOIN FTR B ON A.N_FACTURA = B.N_FACTURA
            LEFT JOIN  PLN C ON B.IDPLAN = C.IDPLAN
            WHERE  A.CNSFPAG = @CNSFPAG_PPTO
            AND    (COALESCE(C.RUBRO, '') = '' OR COALESCE(C.RUBROANT, '') = '')
        )
        BEGIN
            SELECT @PLANES_SIN_RUBRO = STRING_AGG(
                       CONCAT(X.IDPLAN, ' -- ', X.DESCPLAN),
                       CHAR(13)
                   )
            FROM (
                SELECT DISTINCT
                    COALESCE(C.IDPLAN, 'SINPLAN') AS IDPLAN,
                    COALESCE(C.DESCPLAN, 'NO EXISTE CONTRATO') AS DESCPLAN
                FROM   FPAGD A
                INNER JOIN FTR B ON A.N_FACTURA = B.N_FACTURA
                LEFT JOIN  PLN C ON B.IDPLAN = C.IDPLAN
                WHERE  A.CNSFPAG = @CNSFPAG_PPTO
                AND    (COALESCE(C.RUBRO, '') = '' OR COALESCE(C.RUBROANT, '') = '')
            ) X;

            SELECT 'KO' AS OK,
                   CONCAT(
                       'Los planes:', CHAR(13),
                       @PLANES_SIN_RUBRO, CHAR(13),
                       'No tienen definidos los rubros presupuestales.'
                   ) AS ERROR;
            RETURN;
        END;

        BEGIN TRY
            IF @TIPORECO = 'DESDEFTR'
            BEGIN
                EXEC DBO.SPK_RECUADO_PPTO_DESDEFTR
                     @CNSPAGO  = @CNSFPAG_PPTO,
                     @SEDE     = @SEDE,
                     @COMPANIA = @COMPANIA,
                     @USUARIO  = @USUARIO;
            END;
            ELSE
            BEGIN
                EXEC DBO.SPK_RECUADO_PPTO
                     @CNSPAGO  = @CNSFPAG_PPTO,
                     @SEDE     = @SEDE,
                     @COMPANIA = @COMPANIA,
                     @USUARIO  = @USUARIO;
            END;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH;

        IF NOT EXISTS (
            SELECT 1
            FROM   FPAG
            WHERE  CNSFPAG = @CNSFPAG_PPTO
            AND    COALESCE(ENPRESUPUESTO, 0) = 1
        )
        BEGIN
            SELECT 'KO' AS OK,
                   'El recaudo no quedó en presupuesto. Revise PRESUP_TIPORECO, PRESUP_CCOSTO, rubros del plan (PLN) y vigencia PTPTO.' AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK,
               CASE
                  WHEN @ADVERTENCIA IS NOT NULL
                    THEN CONCAT(@ADVERTENCIA, '. Recaudo enviado a presupuesto.')
                  ELSE 'Recaudo enviado a presupuesto'
               END AS MENSAJE;
        RETURN;
    END;

    IF @METODO = 'EXPORT_FPAG_DETALLADO'
    BEGIN
        SELECT @CNSFPAG_PPTO = NULLIF(LTRIM(RTRIM(CNSFPAG)), ''),
               @INGRESO = COALESCE(NULLIF(LTRIM(RTRIM(INGRESO)), ''), 'TODOS'),
               @TIPO_FECHA = COALESCE(NULLIF(LTRIM(RTRIM(TIPO_FECHA)), ''), 'PAGO'),
               @F_INICIAL = F_INICIAL,
               @F_FINAL = F_FINAL,
               @IDTERCERO = NULLIF(LTRIM(RTRIM(IDTERCERO)), ''),
               @PRESUPUESTO = COALESCE(NULLIF(LTRIM(RTRIM(PRESUPUESTO)), ''), 'T'),
               @CONSECUTIVO = NULLIF(LTRIM(RTRIM(CONSECUTIVO)), '')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            CNSFPAG     VARCHAR(20) '$.CNSFPAG',
            INGRESO     VARCHAR(20) '$.INGRESO',
            TIPO_FECHA  VARCHAR(20) '$.TIPO_FECHA',
            F_INICIAL   DATE        '$.F_INICIAL',
            F_FINAL     DATE        '$.F_FINAL',
            IDTERCERO   VARCHAR(20) '$.IDTERCERO',
            PRESUPUESTO VARCHAR(1)  '$.PRESUPUESTO',
            CONSECUTIVO VARCHAR(20) '$.CONSECUTIVO'
        );

        IF COALESCE(@CNSFPAG_PPTO, '') = ''
        BEGIN
            IF @F_INICIAL IS NULL OR @F_FINAL IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Las fechas inicial y final son requeridas' AS ERROR;
                RETURN;
            END;

            SET @F_FINAL_EX = DATEADD(DAY, 1, @F_FINAL);
        END;

        SELECT FPAG.CNSFPAG
        INTO   #FPAG_EXPORT
        FROM   FPAG
        INNER JOIN TER ON FPAG.IDTERCERO = TER.IDTERCERO
        WHERE  COALESCE(FPAG.CERRADO, 0) = 1
        AND    COALESCE(FPAG.ESTADO, '') = 'Activo'
        AND    (
                  COALESCE(@CNSFPAG_PPTO, '') <> ''
                  AND FPAG.CNSFPAG = @CNSFPAG_PPTO
               OR COALESCE(@CNSFPAG_PPTO, '') = ''
                  AND (
                     (@TIPO_FECHA = 'LEGALIZA' AND FPAG.FECHA >= @F_INICIAL AND FPAG.FECHA < @F_FINAL_EX)
                     OR (@TIPO_FECHA <> 'LEGALIZA' AND FPAG.FECHAPAGO >= @F_INICIAL AND FPAG.FECHAPAGO < @F_FINAL_EX)
                  )
                  AND (@INGRESO = 'TODOS' OR FPAG.INGRESO = @INGRESO)
                  AND (
                     @PRESUPUESTO = 'T'
                     OR COALESCE(FPAG.ENPRESUPUESTO, 0) = CASE WHEN @PRESUPUESTO = '1' THEN 1 ELSE 0 END
                  )
                  AND (@CONSECUTIVO IS NULL OR FPAG.CNSFPAG LIKE CONCAT(@CONSECUTIVO, '%'))
                  AND (@IDTERCERO IS NULL OR FPAG.IDTERCERO = @IDTERCERO)
               );

        IF NOT EXISTS (SELECT 1 FROM #FPAG_EXPORT)
        BEGIN
            SELECT 'KO' AS OK, 'No hay recaudos para exportar con los filtros indicados' AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK;

        SELECT FPAG.CNSFPAG,
               FPAG.FECHAPAGO,
               FPAG.IDTERCERO,
               TER.RAZONSOCIAL,
               FPAG.INGRESO,
               CASE FPAG.INGRESO
                  WHEN 'BANCOS' THEN FPAG.BANCO
                  WHEN 'CAJA' THEN FPAG.CODCAJA
                  ELSE ''
               END AS BANCAJ,
               CASE FPAG.INGRESO
                  WHEN 'BANCOS' THEN FPAG.CTA_BCO
                  WHEN 'CAJA' THEN CONVERT(VARCHAR(20), FPAG.CNSFACJ)
                  ELSE ''
               END AS CNSMOV,
               COALESCE(FPAG.VALORPAGO, 0) AS VALORPAGO,
               COALESCE(FPAG.VLRITEMS, 0) AS VLRITEMS,
               COALESCE(FPAG.VLRAJUSTEPESO, 0) AS VLRAJUSTEPESO
        FROM   FPAG
        INNER JOIN TER ON FPAG.IDTERCERO = TER.IDTERCERO
        INNER JOIN #FPAG_EXPORT F ON F.CNSFPAG = FPAG.CNSFPAG
        ORDER BY FPAG.CNSFPAG DESC;

        SELECT FPAGD.CNSFPAG,
               FPAGD.ITEM,
               FPAGD.CNSCXC,
               FCXC.FECHACXC,
               FPAGD.N_FACTURA,
               FTR.F_FACTURA,
               COALESCE(FPAGD.VLRFACTURA, 0) AS VLRFACTURA,
               COALESCE(FPAGD.VLRGLOSA, 0) AS VLRGLOSA,
               CASE FPAGD.CLASE
                  WHEN 'F' THEN 'FACTURA'
                  WHEN 'G' THEN 'GLOSA'
                  WHEN 'R' THEN 'RATIFICACION'
                  WHEN 'C' THEN 'CONCILIA'
                  ELSE 'OTRO'
               END AS CLASE_FAC
        FROM   FPAGD
        INNER JOIN #FPAG_EXPORT F ON F.CNSFPAG = FPAGD.CNSFPAG
        INNER JOIN FCXC ON FPAGD.CNSCXC = FCXC.CNSCXC
        INNER JOIN FTR ON FPAGD.N_FACTURA = FTR.N_FACTURA
        ORDER BY FPAGD.CNSFPAG DESC, FPAGD.ITEM ASC, FPAGD.N_FACTURA ASC;

        RETURN;
    END;

    IF @METODO = 'PRESUPUESTO_FNOT'
    BEGIN
        SELECT @CNSFNOT_PPTO = NULLIF(LTRIM(RTRIM(CNSFNOT)), ''),
               @CONSECUTIVOPPTO = NULLIF(LTRIM(RTRIM(CONSECUTIVOPPTO)), '')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            CNSFNOT         VARCHAR(20) '$.CNSFNOT',
            CONSECUTIVOPPTO VARCHAR(20) '$.CONSECUTIVOPPTO'
        );

        IF COALESCE(@CNSFNOT_PPTO, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar CNSFNOT' AS ERROR;
            RETURN;
        END;

        IF COALESCE(@CONSECUTIVOPPTO, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar el presupuesto destino (CONSECUTIVOPPTO)' AS ERROR;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM FNOT WHERE CNSFNOT = @CNSFNOT_PPTO)
        BEGIN
            SELECT 'KO' AS OK, 'Nota no encontrada' AS ERROR;
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM   FNOT
            WHERE  CNSFNOT = @CNSFNOT_PPTO
            AND    COALESCE(ENPRESUPUESTO, 0) <> 0
        )
        BEGIN
            SELECT 'KO' AS OK, 'La nota ya fue enviada a presupuesto' AS ERROR;
            RETURN;
        END;

        BEGIN TRY
            EXEC DBO.ENVIA_NOTADBCR_PPTO
                 @CNSFNOT_PPTO,
                 @CONSECUTIVOPPTO;
        END TRY
        BEGIN CATCH
            SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH;

        IF NOT EXISTS (
            SELECT 1
            FROM   FNOT
            WHERE  CNSFNOT = @CNSFNOT_PPTO
            AND    COALESCE(ENPRESUPUESTO, 0) = 1
        )
        BEGIN
            SELECT 'KO' AS OK,
                   'La nota no quedó en presupuesto. Revise la factura relacionada y la vigencia del presupuesto.' AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK, 'Nota enviada a presupuesto' AS MENSAJE;
        RETURN;
    END;

    IF @METODO = 'EXPORT_FNOT'
    BEGIN
        SELECT @F_INICIAL = F_INICIAL,
               @F_FINAL = F_FINAL,
               @CONSECUTIVOPPTO = NULLIF(LTRIM(RTRIM(CONSECUTIVOPPTO)), ''),
               @EST_NOTA_PPTO = COALESCE(NULLIF(LTRIM(RTRIM(EST_NOTA_PPTO)), ''), 'T'),
               @IDTERCERO = NULLIF(LTRIM(RTRIM(IDTERCERO)), ''),
               @RUBRO_FNOT = NULLIF(LTRIM(RTRIM(RUBRO)), ''),
               @CONSECUTIVO = NULLIF(LTRIM(RTRIM(CNSCXC)), ''),
               @ESTADO_PPTO_FNOT = COALESCE(NULLIF(LTRIM(RTRIM(ESTADO_PPTO)), ''), 'T')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            F_INICIAL       DATE        '$.F_INICIAL',
            F_FINAL         DATE        '$.F_FINAL',
            CONSECUTIVOPPTO VARCHAR(20) '$.CONSECUTIVOPPTO',
            EST_NOTA_PPTO   VARCHAR(1)  '$.EST_NOTA_PPTO',
            IDTERCERO       VARCHAR(20) '$.IDTERCERO',
            RUBRO           VARCHAR(50) '$.RUBRO',
            CNSCXC          VARCHAR(20) '$.CNSCXC',
            ESTADO_PPTO     VARCHAR(20) '$.ESTADO_PPTO'
        );

        IF @F_INICIAL IS NULL OR @F_FINAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Las fechas inicial y final son requeridas' AS ERROR;
            RETURN;
        END;

        SET @F_FINAL_EX = DATEADD(DAY, 1, @F_FINAL);

        IF OBJECT_ID('tempdb..#FNOT_EXPORT') IS NOT NULL
            DROP TABLE #FNOT_EXPORT;

        SELECT FNOT.CNSFNOT,
               FNOT.CLASE,
               FNOT.F_NOTA,
               FNOT.N_FACTURA,
               COALESCE(NULLIF(RTRIM(FNOT.CNSCXC), ''), FCXCD_REF.CNSCXC_FCXCD, '') AS CNSCXC,
               COALESCE(NULLIF(RTRIM(PLN.RUBRO), ''), NULLIF(RTRIM(PTRUB.RUBRO), ''), '') AS RUBRO,
               COALESCE(PTRUB.NOMRUBRO, '') AS NOMRUBRO,
               COALESCE(FNOT.VR_TOTAL, 0) AS VR_TOTAL,
               COALESCE(FNOT.ENPRESUPUESTO, 0) AS ENPRESUPUESTO,
               TER.NIT,
               COALESCE(VWK_TEXCA.RAZONSOCIAL, TER.RAZONSOCIAL) AS RAZONSOCIAL,
               FNOT.OBSERVACION
        INTO   #FNOT_EXPORT
        FROM   FNOT
        INNER JOIN FTR ON FNOT.N_FACTURA = FTR.N_FACTURA
        INNER JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
        INNER JOIN TER ON FNOT.IDTERCERO = TER.IDTERCERO
        INNER JOIN VWK_TEXCA ON VWK_TEXCA.IDTERCERO = FNOT.IDTERCERO
        LEFT JOIN  PTPTO ON FNOT.CONSECUTIVOPPTO = PTPTO.CONSECUTIVO AND FNOT.COMPANIA = PTPTO.COMPANIA
        LEFT JOIN  PTRUB ON PLN.RUBRO = PTRUB.RUBRO
                          AND PTRUB.CONSECUTIVO = COALESCE(NULLIF(@CONSECUTIVOPPTO, ''), FNOT.CONSECUTIVOPPTO)
                          AND PTRUB.COMPANIA = FNOT.COMPANIA
        OUTER APPLY (
            SELECT TOP 1 FCXCD.CNSCXC AS CNSCXC_FCXCD
            FROM   FCXCD
            WHERE  FCXCD.N_FACTURA = FNOT.N_FACTURA
            ORDER BY FCXCD.CNSCXC DESC
        ) FCXCD_REF
        WHERE  COALESCE(FNOT.CERRADA, 0) = 1
        AND    COALESCE(FNOT.ESTADO, '') = 'O'
        AND    FNOT.F_NOTA >= @F_INICIAL
        AND    FNOT.F_NOTA < @F_FINAL_EX
        AND    (
                  @EST_NOTA_PPTO = 'T'
                  OR COALESCE(FNOT.ENPRESUPUESTO, 0) = CASE WHEN @EST_NOTA_PPTO = '1' THEN 1 ELSE 0 END
               )
        AND    (@IDTERCERO IS NULL OR FNOT.IDTERCERO = @IDTERCERO)
        AND    (
                  COALESCE(@CONSECUTIVOPPTO, '') = ''
                  OR EXISTS (
                      SELECT 1
                      FROM   FTR FTR_PPTO
                      WHERE  FTR_PPTO.N_FACTURA = FNOT.N_FACTURA
                      AND    COALESCE(FTR_PPTO.ENPRESUPUESTO, 0) = 1
                      AND    COALESCE(FTR_PPTO.CONSECUTIVOPTO, '') = @CONSECUTIVOPPTO
                  )
               )
        AND    (
                  @RUBRO_FNOT IS NULL
                  OR NULLIF(RTRIM(PLN.RUBRO), '') = @RUBRO_FNOT
                  OR NULLIF(RTRIM(PLN.RUBRO), '') LIKE CONCAT(@RUBRO_FNOT, '.%')
                  OR @RUBRO_FNOT LIKE CONCAT(NULLIF(RTRIM(PLN.RUBRO), ''), '.%')
               )
        AND    (@CONSECUTIVO IS NULL OR FNOT.CNSCXC LIKE CONCAT(@CONSECUTIVO, '%'))
        AND    (@ESTADO_PPTO_FNOT = 'T' OR PTPTO.ESTADO = @ESTADO_PPTO_FNOT);

        IF NOT EXISTS (SELECT 1 FROM #FNOT_EXPORT)
        BEGIN
            SELECT 'KO' AS OK, 'No hay notas para exportar con los filtros indicados' AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK;

        SELECT CASE WHEN COALESCE(E.ENPRESUPUESTO, 0) = 1 THEN 'Sí' ELSE 'No' END AS Presupuesto,
               E.CNSFNOT AS Consecutivo,
               CASE
                  WHEN E.CLASE = 'C' THEN 'Crédito'
                  WHEN E.CLASE = 'D' THEN 'Débito'
                  ELSE COALESCE(E.CLASE, '')
               END AS [Clase Nota],
               E.CLASE AS ClaseCod,
               E.F_NOTA AS [F. Nota],
               E.N_FACTURA AS [N. Factura],
               E.CNSCXC AS CnsCxc,
               E.RUBRO AS Rubro,
               E.NOMRUBRO AS [Nombre del Rubro],
               E.VR_TOTAL AS [Vlr. Nota],
               E.NIT AS [Id. Tercero],
               E.RAZONSOCIAL AS [Razón Social],
               E.OBSERVACION AS Observación
        FROM   #FNOT_EXPORT E
        ORDER BY E.F_NOTA DESC, E.CNSFNOT DESC, E.CLASE DESC;

        RETURN;
    END;

    IF @METODO = 'EXPORT_LISTADO_RECO_TER'
    BEGIN
        SELECT @F_INICIAL = TRY_CAST(F_INICIAL AS DATE),
               @F_FINAL = TRY_CAST(F_FINAL AS DATE),
               @CONSECUTIVOPPTO_RECO_TER = NULLIF(LTRIM(RTRIM(CONSECUTIVOPPTO)), ''),
               @IDTERCERO = NULLIF(LTRIM(RTRIM(IDTERCERO)), '')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            F_INICIAL        VARCHAR(20) '$.F_INICIAL',
            F_FINAL          VARCHAR(20) '$.F_FINAL',
            CONSECUTIVOPPTO  VARCHAR(20) '$.CONSECUTIVOPPTO',
            IDTERCERO        VARCHAR(20) '$.IDTERCERO'
        );

        IF @CONSECUTIVOPPTO_RECO_TER IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'El presupuesto (CONSECUTIVO) es requerido' AS ERROR;
            RETURN;
        END;

        IF @F_INICIAL IS NULL OR @F_FINAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Las fechas inicial y final son requeridas' AS ERROR;
            RETURN;
        END;

        SET @F_FINAL_EX = DATEADD(DAY, 1, @F_FINAL);

        IF NOT EXISTS (
            SELECT 1
            FROM   PTRECO
            INNER JOIN TER ON TER.IDTERCERO = PTRECO.IDTERCERO
            INNER JOIN PTRECOD
                ON PTRECO.CONSECUTIVO = PTRECOD.CONSECUTIVO
               AND PTRECO.RECO = PTRECOD.RECO
            WHERE  PTRECO.COMPANIA = @COMPANIA
            AND    PTRECO.CONSECUTIVO = @CONSECUTIVOPPTO_RECO_TER
            AND    PTRECO.ESTADO = 'Confirmado'
            AND    PTRECO.FECHA >= @F_INICIAL
            AND    PTRECO.FECHA < @F_FINAL_EX
            AND    (@IDTERCERO IS NULL OR PTRECO.IDTERCERO = @IDTERCERO)
        )
        BEGIN
            SELECT 'KO' AS OK, 'No hay registros para los filtros indicados' AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK;

        SELECT PTRECO.CONSECUTIVO,
               MONTH(PTRECO.FECHA) AS MES,
               TER.NIT AS IDTERCERO,
               TER.RAZONSOCIAL,
               SUM(COALESCE(PTRECO.VALOR, 0)) AS VLR_RECO,
               SUM(COALESCE(PTRECO.VALOR, 0) - COALESCE(PTRECO.SALDO, 0)) AS VLR_RECA,
               SUM(COALESCE(PTRECOD.VLR_NOTAS, 0)) AS VLR_NOTAS,
               SUM(COALESCE(PTRECO.SALDO, 0)) AS VLR_SALDO
        FROM   PTRECO
        INNER JOIN TER ON TER.IDTERCERO = PTRECO.IDTERCERO
        INNER JOIN PTRECOD
            ON PTRECO.CONSECUTIVO = PTRECOD.CONSECUTIVO
           AND PTRECO.RECO = PTRECOD.RECO
        WHERE  PTRECO.COMPANIA = @COMPANIA
        AND    PTRECO.CONSECUTIVO = @CONSECUTIVOPPTO_RECO_TER
        AND    PTRECO.ESTADO = 'Confirmado'
        AND    PTRECO.FECHA >= @F_INICIAL
        AND    PTRECO.FECHA < @F_FINAL_EX
        AND    (@IDTERCERO IS NULL OR PTRECO.IDTERCERO = @IDTERCERO)
        GROUP BY PTRECO.CONSECUTIVO,
                 MONTH(PTRECO.FECHA),
                 PTRECO.IDTERCERO,
                 TER.NIT,
                 TER.RAZONSOCIAL
        ORDER BY PTRECO.CONSECUTIVO ASC,
                 MONTH(PTRECO.FECHA) ASC,
                 PTRECO.IDTERCERO ASC;

        RETURN;
    END;

     IF @METODO = 'EXPORT_EJECUCION_PAC'
    BEGIN
        DECLARE @SOLO_FILTRO_PAC BIT = 0;

        SELECT @COMPANIA_PAC = NULLIF(LTRIM(RTRIM(COMPANIA)), ''),
               @CONSECUTIVO_PAC = NULLIF(LTRIM(RTRIM(CONSECUTIVO)), ''),
               @MES_PAC = MES,
               @RUBRO_PAC = NULLIF(LTRIM(RTRIM(RUBRO)), ''),
               @CNSRPDX_ANT_PAC = NULLIF(LTRIM(RTRIM(CNSRPDX)), ''),
               @IDSEDE_PAC = NULLIF(LTRIM(RTRIM(IDSEDE)), ''),
               @SOLO_FILTRO_PAC = COALESCE(SOLO_FILTRO, 0)
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            COMPANIA     VARCHAR(2)  '$.COMPANIA',
            CONSECUTIVO  VARCHAR(20) '$.CONSECUTIVO',
            MES          INT         '$.MES',
            RUBRO        VARCHAR(50) '$.RUBRO',
            CNSRPDX      VARCHAR(20) '$.CNSRPDX',
            IDSEDE       VARCHAR(5)  '$.IDSEDE',
            SOLO_FILTRO  BIT         '$.SOLO_FILTRO'
        );

        SET @COMPANIA_PAC = COALESCE(@COMPANIA_PAC, @COMPANIA, '01');
        SET @IDSEDE_PAC = COALESCE(@IDSEDE_PAC, @SEDE, '01');

        IF @CONSECUTIVO_PAC IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'CONSECUTIVO requerido' AS ERROR;
            RETURN;
        END;

        IF @MES_PAC IS NULL OR @MES_PAC < 1 OR @MES_PAC > 12
        BEGIN
            SELECT 'KO' AS OK, 'MES requerido (1-12)' AS ERROR;
            RETURN;
        END;

        IF @SOLO_FILTRO_PAC = 1 AND @CNSRPDX_ANT_PAC IS NOT NULL
        BEGIN
            SET @CNSRPDX_PAC = @CNSRPDX_ANT_PAC;
        END
        ELSE
        BEGIN
            IF @CNSRPDX_ANT_PAC IS NOT NULL
            BEGIN
                DELETE FROM RPDX
                WHERE  CNS = @CNSRPDX_ANT_PAC;
            END;

            SET @CNSRPDX_PAC = NULL;
            EXEC SPK_GENCONSECUTIVO @COMPANIA_PAC, @IDSEDE_PAC, '@RPDX', @CNSRPDX_PAC OUTPUT;

            IF COALESCE(@CNSRPDX_PAC, '') = ''
            BEGIN
                SELECT 'KO' AS OK, 'No se pudo generar consecutivo RPDX' AS ERROR;
                RETURN;
            END;

            BEGIN TRY
                EXEC SPK_GENERA_PAC_G @CNSRPDX_PAC, @CONSECUTIVO_PAC, @MES_PAC;
            END TRY
            BEGIN CATCH
                SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
                RETURN;
            END CATCH;
        END;

        SELECT 'OK' AS OK, @CNSRPDX_PAC AS CNSRPDX;

        SELECT @COMPANIA_PAC AS COMPANIA,
               @CONSECUTIVO_PAC AS CONSECUTIVO,
               @MES_PAC AS MES,
               COALESCE(R.ID5, '') AS IDTIPOMOV,
               COALESCE(
                   NULLIF(RTRIM(R.ID4), ''),
                   (
                       SELECT TOP 1 P.RUBRO
                       FROM   PTRUB P
                       WHERE  P.NOMRUBRO = R.STRINGMEDIO1
                       ORDER BY P.NIVEL ASC, LEN(P.RUBRO) ASC, P.RUBRO ASC
                   ),
                   ''
               ) AS RUBRO,
               R.ID3 AS RECURSO,
               COALESCE(R.STRINGMEDIO1, '') AS NOMRUBRO,
               COALESCE(R.VALOR1, 0) AS PAC_INI,
               COALESCE(R.VALOR2, 0) AS RESAGO,
               COALESCE(R.VALOR3, 0) AS VLR_TDB,
               COALESCE(R.VALOR4, 0) AS VLR_TCR,
               COALESCE(R.VALOR5, 0) AS VLR_MDB,
               COALESCE(R.VALOR6, 0) AS VLR_MCR,
               COALESCE(R.VALOR7, 0) AS PAC_DEF,
               COALESCE(R.VALOR8, 0) AS VLR_PAG_ACU,
               COALESCE(R.VALOR9, 0) AS VLR_PAG_MES,
               COALESCE(R.VALOR10, 0) AS SALDO_PAC
        FROM   RPDX R
        WHERE  R.CNS = @CNSRPDX_PAC
        AND    (
                   @RUBRO_PAC IS NULL
                   OR NULLIF(RTRIM(R.ID4), '') = @RUBRO_PAC
                   OR NULLIF(RTRIM(R.ID4), '') LIKE CONCAT(@RUBRO_PAC, '.%')
                   OR EXISTS (
                       SELECT 1
                       FROM   PTRUB P
                       WHERE  P.NOMRUBRO = R.STRINGMEDIO1
                       AND    P.COMPANIA = @COMPANIA_PAC
                       AND    P.CONSECUTIVO = @CONSECUTIVO_PAC
                       AND    P.RECURSO = R.ID3
                       AND    (
                                  P.RUBRO = @RUBRO_PAC
                                  OR P.RUBRO LIKE CONCAT(@RUBRO_PAC, '.%')
                              )
                   )
               )
        ORDER BY R.ITEM ASC;

        RETURN;
    END;

     IF @METODO = 'EXPORT_LISTA_EGRESOS'
    BEGIN
        SELECT @COMPANIA_EGR = NULLIF(LTRIM(RTRIM(COMPANIA)), ''),
               @F_INI_EGR = TRY_CAST(F_INICIAL AS DATE),
               @F_FIN_EX_EGR = TRY_CAST(F_FINAL AS DATE),
               @CODCAJA_EGR = NULLIF(LTRIM(RTRIM(CODCAJA)), '')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            COMPANIA   VARCHAR(2)  '$.COMPANIA',
            F_INICIAL  VARCHAR(20) '$.F_INICIAL',
            F_FINAL    VARCHAR(20) '$.F_FINAL',
            CODCAJA    VARCHAR(20) '$.CODCAJA'
        );

        SET @COMPANIA_EGR = COALESCE(@COMPANIA_EGR, @COMPANIA, '01');

        IF @CODCAJA_EGR IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'CODCAJA requerido' AS ERROR;
            RETURN;
        END;

        IF @F_INI_EGR IS NULL OR @F_FIN_EX_EGR IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Las fechas inicial y final son requeridas' AS ERROR;
            RETURN;
        END;

        -- Clarion: FECHA < fechafin+1
        SET @F_FIN_EX_EGR = DATEADD(DAY, 1, @F_FIN_EX_EGR);

        SELECT 'OK' AS OK;

        SELECT FCJ.CODCAJA,
               COALESCE(CAJ.DESCRIPCION, '') AS CAJA,
               FCJ.CNSFACJ,
               FCJ.FECHA,
               COALESCE(FCJ.VALORTOTAL, 0) AS VALORTOTAL,
               COALESCE(TER.NIT, '') AS IDTERCERO,
               COALESCE(TER.RAZONSOCIAL, '') AS RAZONSOCIAL,
               COALESCE(
                   NULLIF(RTRIM(CPCJ.CUENTA), ''),
                   NULLIF(RTRIM(FCJ.TIPOEGRESO), ''),
                   NULLIF(RTRIM(FCJ.CLASER), ''),
                   ''
               ) AS CL_CONTABLE,
               COALESCE(FCJ.OBSERVACION, '') AS OBSERVACION
        FROM   FCJ
        INNER JOIN CAJ ON FCJ.CODCAJA = CAJ.CODCAJA
        INNER JOIN TER ON FCJ.IDTERCERO = TER.IDTERCERO
        LEFT JOIN CPCJ ON FCJ.TIPOEGRESO = CPCJ.CODIGO
        WHERE  FCJ.COMPANIA = @COMPANIA_EGR
        AND    FCJ.CODCAJA = @CODCAJA_EGR
        AND    FCJ.ESTADO <> 'A'
        AND    FCJ.CERRADA = 1
        AND    FCJ.CLASE_FAC = 'PAGO'
        AND    FCJ.FECHA >= @F_INI_EGR
        AND    FCJ.FECHA < @F_FIN_EX_EGR
        ORDER BY FCJ.CNSFACJ ASC;
        RETURN;
    END;

    IF @METODO = 'TRAER_FACTURA_PPTO'
    BEGIN
        IF COALESCE(DBO.FNK_VALORVARIABLE('PRESUP_CXC_ACTIVADO'), '') <> 'SI'
        BEGIN
            SELECT 'KO' AS OK, 'Presupuesto CxC no activado (PRESUP_CXC_ACTIVADO)' AS ERROR;
            RETURN;
        END;

        SELECT @N_FACTURA_FTR = NULLIF(LTRIM(RTRIM(N_FACTURA)), ''),
               @IDSEDE_FTR = NULLIF(LTRIM(RTRIM(IDSEDE)), '')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            N_FACTURA VARCHAR(20) '$.N_FACTURA',
            IDSEDE    VARCHAR(5)  '$.IDSEDE'
        );

        IF COALESCE(@IDSEDE_FTR, '') <> ''
        BEGIN
            SET @SEDE = @IDSEDE_FTR;
        END;

        IF COALESCE(@N_FACTURA_FTR, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar N_FACTURA' AS ERROR;
            RETURN;
        END;

        IF COALESCE(@SEDE, '') = ''
        BEGIN
            SELECT 'KO' AS OK, 'Debe indicar sede (IDSEDE)' AS ERROR;
            RETURN;
        END;

        SET @TIPORECO_FTR = COALESCE(DBO.FNK_VALORVARIABLE('PRESUP_TIPORECO'), '');
        IF @TIPORECO_FTR <> 'CUENTAC'
        BEGIN
            SELECT 'KO' AS OK,
                   CONCAT(
                       'TRAER_FACTURA_PPTO solo inserta cuando PRESUP_TIPORECO = CUENTAC. Actual: ',
                       COALESCE(NULLIF(@TIPORECO_FTR, ''), '(vacío)')
                   ) AS ERROR;
            RETURN;
        END;

        SET @CCOSTOPRESUP_FTR = COALESCE(DBO.FNK_VALORVARIABLE('PRESUP_CCOSTO'), '');
        IF @CCOSTOPRESUP_FTR = ''
        BEGIN
            SELECT 'KO' AS OK, 'No está configurada la variable PRESUP_CCOSTO' AS ERROR;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM FTR WHERE N_FACTURA = @N_FACTURA_FTR)
        BEGIN
            SELECT 'KO' AS OK, 'Factura no encontrada' AS ERROR;
            RETURN;
        END;

        SELECT @FECHARECEP_FTR = FTR.F_FACTURA,
               @ENPPTO_FTR = COALESCE(FTR.ENPRESUPUESTO, 0),
               @CNSFCT_FTR = FTR.CNSFCT
        FROM   FTR
        WHERE  FTR.N_FACTURA = @N_FACTURA_FTR;

        IF COALESCE(@ENPPTO_FTR, 0) <> 0
        BEGIN
            SELECT 'KO' AS OK, 'La factura ya está en presupuesto' AS ERROR;
            RETURN;
        END;

        SET @COMPANIA_FTR = COALESCE(NULLIF(@COMPANIA, ''), '01');

        SELECT TOP (1)
               @CONSECUTIVO_FTR = PTPTO.CONSECUTIVO
        FROM   PTPTO
        WHERE  PTPTO.COMPANIA = @COMPANIA_FTR
        AND    PTPTO.FECHAINI <= @FECHARECEP_FTR
        AND    PTPTO.FECHAFIN >= @FECHARECEP_FTR
        ORDER BY PTPTO.CONSECUTIVO DESC;

        IF COALESCE(@CONSECUTIVO_FTR, '') = ''
        BEGIN
            SELECT 'KO' AS OK,
                   'No hay presupuesto (PTPTO) vigente para la fecha de la factura' AS ERROR;
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM   FTR
            INNER JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
            WHERE  FTR.N_FACTURA = @N_FACTURA_FTR
            AND    (COALESCE(PLN.RUBRO, '') = '' OR PLN.RUBRO_ID IS NULL)
        )
        BEGIN
            SELECT 'KO' AS OK,
                   'El plan de la factura no tiene rubro presupuestal (PLN.RUBRO / RUBRO_ID)' AS ERROR;
            RETURN;
        END;

        SET @IDSEDEPPAL_FTR = NULLIF(LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('IDSEDEPRINCIPAL'))), '');
        IF COALESCE(@IDSEDEPPAL_FTR, '') = ''
        BEGIN
            SET @IDSEDEPPAL_FTR = @SEDE;
        END;

        BEGIN TRY
            BEGIN TRAN;

            SELECT @RECO_NUM_FTR = COALESCE(CONTADOR_RR, 0) + 1
            FROM   PTPTO WITH (UPDLOCK, ROWLOCK)
            WHERE  COMPANIA = @COMPANIA_FTR
            AND    CONSECUTIVO = @CONSECUTIVO_FTR;

            SET @RECO_FTR = CONCAT(
                @IDSEDEPPAL_FTR,
                RIGHT(CONCAT('00000000', CAST(@RECO_NUM_FTR AS VARCHAR(20))), 8)
            );

            UPDATE PTPTO
            SET    CONTADOR_RR = COALESCE(CONTADOR_RR, 0) + 1
            WHERE  COMPANIA = @COMPANIA_FTR
            AND    CONSECUTIVO = @CONSECUTIVO_FTR;

            SELECT @OBJETIVO_FTR = CONCAT(
                       'REGIMEN: ',
                       COALESCE(PLN.TIPOSISTEMA, ''),
                       ' ',
                       CASE WHEN COALESCE(PLN.CAPITADO, 0) = 0 THEN 'EVENTO' ELSE 'CAPITADO' END,
                       ' FACTURADO EN EL MES DE ',
                       CASE MONTH(FTR.F_FACTURA)
                           WHEN 1 THEN 'ENERO'
                           WHEN 2 THEN 'FEBRERO'
                           WHEN 3 THEN 'MARZO'
                           WHEN 4 THEN 'ABRIL'
                           WHEN 5 THEN 'MAYO'
                           WHEN 6 THEN 'JUNIO'
                           WHEN 7 THEN 'JULIO'
                           WHEN 8 THEN 'AGOSTO'
                           WHEN 9 THEN 'SEPTIEMBRE'
                           WHEN 10 THEN 'OCTUBRE'
                           WHEN 11 THEN 'NOVIEMBRE'
                           WHEN 12 THEN 'DICIEMBRE'
                       END
                   )
            FROM   FTR
            LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
            WHERE  FTR.N_FACTURA = @N_FACTURA_FTR;

            INSERT INTO PTRECO (
                COMPANIA, CONSECUTIVO, RECO, OBJETIVO, VALOR, CNSFCXC,
                IDTERCERO, FECHA, ESTADO, CCOSTO, N_FACTURA, CNSFTR, TIPO, IDSEDE, SALDO
            )
            SELECT @COMPANIA_FTR,
                   @CONSECUTIVO_FTR,
                   @RECO_FTR,
                   @OBJETIVO_FTR,
                   FTR.VR_TOTAL,
                   FTR.CNSFCT,
                   FTR.IDTERCERO,
                   @FECHARECEP_FTR,
                   'NoConfirmado',
                   @CCOSTOPRESUP_FTR,
                   @N_FACTURA_FTR,
                   @CNSFCT_FTR,
                   'Suma',
                   @SEDE,
                   FTR.VR_TOTAL
            FROM   FTR
            WHERE  FTR.N_FACTURA = @N_FACTURA_FTR;

            INSERT INTO PTRECOD (
                COMPANIA, CONSECUTIVO, RECO, CLASE, RUBRO, OBJETIVO,
                VALOR, VALOR_RECA, SALDO, RUBRO_ID
            )
            SELECT @COMPANIA_FTR,
                   @CONSECUTIVO_FTR,
                   @RECO_FTR,
                   'Ingreso',
                   PLN.RUBRO,
                   CONCAT(
                       CASE WHEN COALESCE(PLN.CAPITADO, 0) = 0 THEN 'EVENTO' ELSE 'CAPITADO' END,
                       ' FACTURADO EN EL MES DE ',
                       CASE MONTH(FTR.F_FACTURA)
                           WHEN 1 THEN 'ENERO'
                           WHEN 2 THEN 'FEBRERO'
                           WHEN 3 THEN 'MARZO'
                           WHEN 4 THEN 'ABRIL'
                           WHEN 5 THEN 'MAYO'
                           WHEN 6 THEN 'JUNIO'
                           WHEN 7 THEN 'JULIO'
                           WHEN 8 THEN 'AGOSTO'
                           WHEN 9 THEN 'SEPTIEMBRE'
                           WHEN 10 THEN 'OCTUBRE'
                           WHEN 11 THEN 'NOVIEMBRE'
                           WHEN 12 THEN 'DICIEMBRE'
                       END
                   ),
                   FTR.VR_TOTAL,
                   0,
                   FTR.VR_TOTAL,
                   PLN.RUBRO_ID
            FROM   FTR
            LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
            WHERE  FTR.N_FACTURA = @N_FACTURA_FTR;

            UPDATE FTR
            SET    ENPRESUPUESTO = 1,
                   CONSECUTIVOPTO = @CONSECUTIVO_FTR,
                   RECO = @RECO_FTR
            WHERE  N_FACTURA = @N_FACTURA_FTR;

            UPDATE PTRECO
            SET    ESTADO = 'Confirmado'
            WHERE  CONSECUTIVO = @CONSECUTIVO_FTR
            AND    RECO = @RECO_FTR
            AND    N_FACTURA = @N_FACTURA_FTR;

            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRAN;
            END;
            SELECT 'KO' AS OK, ERROR_MESSAGE() AS ERROR;
            RETURN;
        END CATCH;

        IF NOT EXISTS (
            SELECT 1
            FROM   FTR
            WHERE  N_FACTURA = @N_FACTURA_FTR
            AND    COALESCE(ENPRESUPUESTO, 0) = 1
        )
        BEGIN
            SELECT 'KO' AS OK,
                   CONCAT(
                       'La factura ',
                       @N_FACTURA_FTR,
                       ' no quedó en presupuesto. Revise PRESUP_TIPORECO=CUENTAC, PRESUP_CCOSTO, rubro PLN y vigencia PTPTO.'
                   ) AS ERROR;
            RETURN;
        END;

        SELECT 'OK' AS OK,
               'Proceso Terminado' AS MENSAJE,
               @RECO_FTR AS RECO,
               @CONSECUTIVO_FTR AS CONSECUTIVOPTO;
        RETURN;
    END;

    IF @METODO = 'EXPORT_LISTA_FTR_ANU'
    BEGIN
        SELECT @F_INICIAL = TRY_CAST(F_INICIAL AS DATE),
               @F_FINAL = TRY_CAST(F_FINAL AS DATE),
               @CONSECUTIVOPPTO = NULLIF(LTRIM(RTRIM(CONSECUTIVOPPTO)), ''),
               @IDTERCERO = NULLIF(LTRIM(RTRIM(IDTERCERO)), ''),
               @N_FACTURA_ANU = NULLIF(LTRIM(RTRIM(N_FACTURA)), ''),
               @CLASE_NOTA_ANU = COALESCE(NULLIF(LTRIM(RTRIM(CLASE_NOTA)), ''), 'T'),
               @ESTADO_PPTO_ANU = COALESCE(NULLIF(LTRIM(RTRIM(ESTADO_PPTO)), ''), 'T')
        FROM   OPENJSON(@PARAMETROS)
        WITH (
            F_INICIAL       VARCHAR(20) '$.F_INICIAL',
            F_FINAL         VARCHAR(20) '$.F_FINAL',
            CONSECUTIVOPPTO VARCHAR(20) '$.CONSECUTIVOPPTO',
            IDTERCERO       VARCHAR(20) '$.IDTERCERO',
            N_FACTURA       VARCHAR(20) '$.N_FACTURA',
            CLASE_NOTA      VARCHAR(1)  '$.CLASE_NOTA',
            ESTADO_PPTO     VARCHAR(20) '$.ESTADO_PPTO'
        );

        IF @F_INICIAL IS NULL OR @F_FINAL IS NULL
        BEGIN
            SELECT 'KO' AS OK, 'Las fechas inicial y final son requeridas' AS ERROR;
            RETURN;
        END;

        SET @F_FINAL_EX = DATEADD(DAY, 1, @F_FINAL);

        SELECT 'OK' AS OK;

        SELECT FTR.N_FACTURA,
               FTR.F_FACTURA,
               NOTAS.F_NOTA,
               TER.NIT,
               COALESCE(VWK_TEXCA.RAZONSOCIAL, TER.RAZONSOCIAL, '') AS RAZONSOCIAL,
               COALESCE(PLN.RUBRO, '') AS RUBRO,
               COALESCE(PTRUB.NOMRUBRO, '') AS NOMRUBRO,
               COALESCE(FTR.VR_TOTAL, 0) AS VR_TOTAL,
               NOTAS.VLR_NOTA_CR,
               NOTAS.VLR_NOTA_DB,
               NOTAS.CLASE_NOTAS,
               COALESCE(FCXCD_REF.CNSCXC_FCXCD, '') AS CNSCXC,
               COALESCE(FTR.CONSECUTIVOPTO, '') AS CONSECUTIVOPTO,
               COALESCE(FTR.ENPRESUPUESTO, 0) AS ENPRESUPUESTO,
               COALESCE(FTR.ESTADO, '') AS ESTADO,
               COALESCE(FTR.TIPOANULACION, '') AS TIPOANULACION,
               COALESCE(FTR.RAZONANULACION, '') AS RAZONANULACION
        FROM   FTR
        INNER JOIN TER ON FTR.IDTERCERO = TER.IDTERCERO
        INNER JOIN (
            SELECT FNOT.N_FACTURA,
                   MAX(FNOT.F_NOTA) AS F_NOTA,
                   SUM(CASE WHEN FNOT.CLASE = 'C' THEN COALESCE(FNOT.VR_TOTAL, 0) ELSE 0 END) AS VLR_NOTA_CR,
                   SUM(CASE WHEN FNOT.CLASE = 'D' THEN COALESCE(FNOT.VR_TOTAL, 0) ELSE 0 END) AS VLR_NOTA_DB,
                   CASE
                       WHEN SUM(CASE WHEN FNOT.CLASE = 'C' THEN 1 ELSE 0 END) > 0
                        AND SUM(CASE WHEN FNOT.CLASE = 'D' THEN 1 ELSE 0 END) > 0 THEN 'Ambas'
                       WHEN SUM(CASE WHEN FNOT.CLASE = 'C' THEN 1 ELSE 0 END) > 0 THEN 'Crédito'
                       WHEN SUM(CASE WHEN FNOT.CLASE = 'D' THEN 1 ELSE 0 END) > 0 THEN 'Débito'
                       ELSE ''
                   END AS CLASE_NOTAS
            FROM   FNOT
            WHERE  COALESCE(FNOT.CERRADA, 0) = 1
            AND    COALESCE(FNOT.ESTADO, '') = 'O'
            AND    FNOT.CLASE IN ('C', 'D')
            AND    FNOT.F_NOTA >= @F_INICIAL
            AND    FNOT.F_NOTA < @F_FINAL_EX
            AND    (
                      @CLASE_NOTA_ANU = 'T'
                      OR FNOT.CLASE = @CLASE_NOTA_ANU
                   )
            GROUP BY FNOT.N_FACTURA
        ) NOTAS ON NOTAS.N_FACTURA = FTR.N_FACTURA
        LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
        LEFT JOIN PTPTO
               ON FTR.CONSECUTIVOPTO = PTPTO.CONSECUTIVO
              AND FTR.COMPANIA = PTPTO.COMPANIA
        LEFT JOIN PTRUB
               ON PLN.RUBRO = PTRUB.RUBRO
              AND PTRUB.CONSECUTIVO = COALESCE(@CONSECUTIVOPPTO, FTR.CONSECUTIVOPTO)
              AND PTRUB.COMPANIA = FTR.COMPANIA
        LEFT JOIN VWK_TEXCA ON VWK_TEXCA.IDTERCERO = FTR.IDTERCERO
        OUTER APPLY (
            SELECT TOP 1 FCXCD.CNSCXC AS CNSCXC_FCXCD
            FROM   FCXCD
            WHERE  FCXCD.N_FACTURA = FTR.N_FACTURA
            ORDER BY FCXCD.CNSCXC DESC
        ) FCXCD_REF
        WHERE  (@IDTERCERO IS NULL OR FTR.IDTERCERO = @IDTERCERO)
        AND    (@N_FACTURA_ANU IS NULL OR FTR.N_FACTURA LIKE CONCAT(@N_FACTURA_ANU, '%'))
        AND    (
                  @CONSECUTIVOPPTO IS NULL
                  OR (
                         COALESCE(FTR.ENPRESUPUESTO, 0) = 1
                     AND COALESCE(FTR.CONSECUTIVOPTO, '') = @CONSECUTIVOPPTO
                  )
               )
        AND    (@ESTADO_PPTO_ANU = 'T' OR PTPTO.ESTADO = @ESTADO_PPTO_ANU)
        ORDER BY FTR.F_FACTURA DESC, FTR.N_FACTURA DESC;

        RETURN;
    END;

    SELECT 'KO' AS OK, 'Metodo no soportado' AS ERROR;
END;
