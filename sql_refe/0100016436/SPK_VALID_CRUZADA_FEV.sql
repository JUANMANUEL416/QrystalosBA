CREATE OR ALTER PROCEDURE DBO.SPK_VALID_CRUZADA_FEV
    @IDTERCERO         VARCHAR(20),
    @IDPLAN            VARCHAR(6),
    @IDAFILIADO        VARCHAR(20),
    @FECHA_REF         DATE         = NULL,  -- Fecha del documento; si NULL se infiere de FTR o GETDATE()
    @VALIDAR_MODALIDAD BIT          = 0,
    @CNSFTR            VARCHAR(20)  = NULL,
    @TIPOCAP           INT          = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @COBERTURA    VARCHAR(2)
    DECLARE @MODALIDAD    VARCHAR(2)
    DECLARE @TIPOUSUARIO  VARCHAR(2)
    DECLARE @DESC_COB     VARCHAR(200)
    DECLARE @PROCEDENCIA  VARCHAR(20)
    DECLARE @DESC_MOD     VARCHAR(200)
    DECLARE @DESC_TU      VARCHAR(200)
    DECLARE @MENSAJE      VARCHAR(MAX) = ''
    DECLARE @FECHA_VALIDA DATE
    DECLARE @N_FACTURA    VARCHAR(20)
    DECLARE @NOREFERENCIA VARCHAR(20)
    DECLARE @NOMBREAFI    VARCHAR(124)
    DECLARE @DOCIDAFILIADO VARCHAR(20)
    DECLARE @TIPO_DOC     VARCHAR(2)
    DECLARE @CONTEXTO_DOC VARCHAR(1000)

    DECLARE @ERRORES TABLE (
        ITEM        INT IDENTITY(1,1),
        CODIGO      VARCHAR(20),
        DESCRIPCION VARCHAR(500)
    )

    -- -------------------------------------------------------
    -- Fecha de referencia para vigencia normativa
    -- Prioridad: @FECHA_REF > F_FACTURA de la factura > hoy
    -- -------------------------------------------------------
    SET @FECHA_VALIDA = CAST(GETDATE() AS DATE)

    IF @FECHA_REF IS NOT NULL
        SET @FECHA_VALIDA = @FECHA_REF

    -- Contexto del documento (cola FEV/XML: identificar la factura detenida)
    IF @CNSFTR IS NOT NULL
    BEGIN
        SELECT
            @N_FACTURA    = F.N_FACTURA,
            @NOREFERENCIA = F.NOREFERENCIA,
            @FECHA_VALIDA = CASE
                WHEN @FECHA_REF IS NOT NULL THEN @FECHA_VALIDA
                ELSE CAST(COALESCE(F.F_FACTURA, GETDATE()) AS DATE)
            END,
            @PROCEDENCIA=PROCEDENCIA
        FROM FTR F
        WHERE F.CNSFCT = @CNSFTR

        SELECT
            @NOMBREAFI     = A.NOMBREAFI,
            @DOCIDAFILIADO = A.DOCIDAFILIADO,
            @TIPO_DOC      = A.TIPO_DOC
        FROM AFI A
        WHERE A.IDAFILIADO = @IDAFILIADO

        SET @CONTEXTO_DOC = CONCAT_WS(' | ',
            CONCAT('Factura N° ', COALESCE(NULLIF(@N_FACTURA, ''), @CNSFTR)),
            CONCAT('Consec. ', @CNSFTR),
            CONCAT('Fecha ', CONVERT(VARCHAR(10), @FECHA_VALIDA, 103)),
            --NULLIF(CONCAT('Ref. ', @NOREFERENCIA), 'Ref. '),
            CONCAT('Paciente ', @IDAFILIADO, ' - ', @DOCIDAFILIADO, ' ', @NOMBREAFI),
            CONCAT('Plan ', @IDPLAN),
            CONCAT('Tercero ', @IDTERCERO)
        )
    END

    -- -------------------------------------------------------
    -- Resolución de códigos
    -- -------------------------------------------------------
    SELECT @COBERTURA = TIPOVOLUNTARIO FROM PLN WHERE IDPLAN = @IDPLAN

    IF @VALIDAR_MODALIDAD = 1
    BEGIN
        SELECT @MODALIDAD = CASE
            WHEN COALESCE(CNT.MODALIDAD, '') IN ('01','02','03','04') THEN CNT.MODALIDAD
            ELSE CASE COALESCE(PPT.CAPITADO, 0)
                WHEN 1 THEN CASE
                    WHEN COALESCE(FTR.TIPOCAP, @TIPOCAP, 0) <> 4
                        THEN IIF(COALESCE(PPT.PGP, 0) = 1, '02', '03')
                    ELSE '04'
                END
                WHEN 0 THEN CASE
                    WHEN COALESCE(PPT.PGP, 0) = 1 THEN '02'
                    WHEN COALESCE(PPT.PAQUETIZADO, 0) = 1
                        THEN CASE WHEN dbo.FNK_VALORVARIABLE('IDTERCERO_OFE') = '900986941' THEN '04' ELSE '01' END
                    ELSE '04'
                END
            END
        END
        FROM PPT
            LEFT JOIN CNT ON CNT.IDCONTRATO = PPT.IDCONTRATO
            LEFT JOIN FTR ON FTR.IDTERCERO = PPT.IDTERCERO
                           AND FTR.IDPLAN = PPT.IDPLAN
                           AND FTR.CNSFCT = @CNSFTR
        WHERE PPT.IDTERCERO = @IDTERCERO
          AND PPT.IDPLAN = @IDPLAN

        IF COALESCE(@MODALIDAD, '') = '' SET @MODALIDAD = '04'
    END
    
    DECLARE @IDTARIFASOAT      VARCHAR(20) = DBO.FNK_VALORVARIABLE('IDTARIFASOAT');
    DECLARE @TERCATASEGURADORA VARCHAR(20) = DBO.FNK_VALORVARIABLE('TERCATASEGURADORA');

    IF @PROCEDENCIA = 'SALUD'
    BEGIN
        SELECT @TIPOUSUARIO = CASE
            WHEN IIF(H.TIPOADM = @IDTARIFASOAT, 1, 0) = 0
              OR EXISTS (
                    SELECT 1 FROM TEXCA T
                    WHERE T.IDTERCERO = @IDTERCERO
                      AND T.IDCATEGORIA = @TERCATASEGURADORA
                 )
                THEN H.TIPOAFILIADO
            ELSE A.TIPOUSUARIO
        END
        FROM HADM H
            OUTER APPLY ( SELECT TIPOUSUARIO FROM AFI WHERE IDAFILIADO = @IDAFILIADO) A
        WHERE H.NOADMISION = @NOREFERENCIA;
    END
    ELSE
        SELECT @TIPOUSUARIO = TIPOUSUARIO FROM AFI WHERE IDAFILIADO = @IDAFILIADO;

    SELECT @DESC_COB = DESCRIPCION FROM TGEN
    WHERE TABLA = 'PLN' AND CAMPO = 'CobertuPlanBeneficio' AND CODIGO = @COBERTURA

    IF @VALIDAR_MODALIDAD = 1
        SELECT @DESC_MOD = DESCRIPCION FROM TGEN
        WHERE TABLA = 'CNT' AND CAMPO = 'modalidadPago' AND CODIGO = @MODALIDAD

    SELECT @DESC_TU = DESCRIPCION FROM TGEN
    WHERE TABLA = 'AFI' AND CAMPO = 'TIPO_USUARIO' AND CODIGO = @TIPOUSUARIO

    -- -------------------------------------------------------
    -- Validación 1: Cobertura activa y vigente
    -- -------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM RIPS_VALID_COBERTURA
        WHERE COBERTURA = @COBERTURA
          AND ACTIVO = 1
          AND @FECHA_VALIDA >= FECHA_DESDE
          AND @FECHA_VALIDA <= COALESCE(FECHA_HASTA, '9999-12-31')
    )
    BEGIN
        INSERT INTO @ERRORES (CODIGO, DESCRIPCION) VALUES (
            'COB_INVALIDA',
            CONCAT(
                'La cobertura ', @COBERTURA, ' (', COALESCE(@DESC_COB, 'sin descripción'), ') ',
                'no está activa o no existe en la tabla normativa.'
            )
        )
    END
    ELSE
    BEGIN
        -- -------------------------------------------------------
        -- Validación 2: Modalidad válida (solo si @VALIDAR_MODALIDAD = 1)
        -- -------------------------------------------------------
        IF @VALIDAR_MODALIDAD = 1
        AND NOT EXISTS (
            SELECT 1 FROM RIPS_VALID_COB_MOD
            WHERE COBERTURA = @COBERTURA
              AND MODALIDAD = @MODALIDAD
              AND ACTIVO = 1
              AND @FECHA_VALIDA >= FECHA_DESDE
              AND @FECHA_VALIDA <= COALESCE(FECHA_HASTA, '9999-12-31')
        )
        INSERT INTO @ERRORES (CODIGO, DESCRIPCION) VALUES (
            'MOD_INVALIDA',
            CONCAT(
                'La modalidad de pago ', @MODALIDAD, ' (', COALESCE(@DESC_MOD, 'sin descripción'), ') ',
                'no es válida para la cobertura ', @COBERTURA, ' (', COALESCE(@DESC_COB, ''), ').'
            )
        )

        -- -------------------------------------------------------
        -- Validación 3: Tipo de usuario válido para la cobertura
        -- -------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM RIPS_VALID_COB_TU
            WHERE COBERTURA = @COBERTURA
              AND TIPOUSUARIO = @TIPOUSUARIO
              AND ACTIVO = 1
              AND @FECHA_VALIDA >= FECHA_DESDE
              AND @FECHA_VALIDA <= COALESCE(FECHA_HASTA, '9999-12-31')
        )
        INSERT INTO @ERRORES (CODIGO, DESCRIPCION) VALUES (
            'TU_INVALIDO',
            CONCAT(
                'El tipo de usuario ', @TIPOUSUARIO, ' (', COALESCE(@DESC_TU, 'sin descripción'), ') ',
                'no es válido para la cobertura ', @COBERTURA, ' (', COALESCE(@DESC_COB, ''), ').'
            )
        )
    END

    -- -------------------------------------------------------
    -- Solo interrumpe el proceso llamador si hay errores
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM @ERRORES)
    BEGIN
        SELECT @MENSAJE = STRING_AGG(DESCRIPCION, CHAR(13) + CHAR(10))
                          WITHIN GROUP (ORDER BY ITEM)
        FROM @ERRORES

        IF COALESCE(@CONTEXTO_DOC, '') <> ''
            SET @MENSAJE = CONCAT('Documento detenido en validación FEV/RIPS: ', @CONTEXTO_DOC, CHAR(13) + CHAR(10), @MENSAJE)

        RAISERROR(@MENSAJE, 16, 1)
    END
END

