CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_FTR_CITPAQ
    @N_FACTURA  VARCHAR(20),
    @URL_PATH   VARCHAR(MAX) = NULL,
    @PLANO      NVARCHAR(MAX) OUTPUT
AS
DECLARE @NOADMISION VARCHAR(20)
DECLARE @PROCEDENCIA VARCHAR(20)
DECLARE @MEDICA AS NVARCHAR(MAX)
DECLARE @PROCEDI AS NVARCHAR(MAX)
DECLARE @URGEN AS NVARCHAR(MAX)
DECLARE @HOSPITA AS NVARCHAR(MAX)
DECLARE @OTROSER AS NVARCHAR(MAX)
DECLARE @IDTERINSTA VARCHAR(20)
DECLARE @TIPODOC VARCHAR(2)
DECLARE @DOCIDAFILIADO VARCHAR(20)
DECLARE @TIPOUSU VARCHAR(2)
DECLARE @FNACIMIENTO VARCHAR(10)
DECLARE @SEXO VARCHAR(1)
DECLARE @MUNICIPIO VARCHAR(5)
DECLARE @ZONA VARCHAR(20)
DECLARE @INCAPACIDAD VARCHAR(2)
DECLARE @CNS INT = 1
DECLARE @IDPRESTADOR VARCHAR(20)
DECLARE @NRO INT
DECLARE @CANT INT
DECLARE @conceptoRecaudo VARCHAR(20)
DECLARE @VALORCOPAGO DECIMAL(14,2)
DECLARE @IDSEDE VARCHAR(20)
DECLARE @CODHABILITA VARCHAR(100)
DECLARE @CNSCONSULTA INT
DECLARE @CANTORI INT
DECLARE @BASE64 NVARCHAR(MAX)
DECLARE @BANDERA INT, @IDMEDICODEFAULT VARCHAR(12), @TIPO_ID_MEDICODEFAULT VARCHAR(5)

DECLARE @numDocumentoIdObligado VARCHAR(20)
DECLARE @CNSFCT VARCHAR(20)
DECLARE @PAQUETE BIT, @CONCEPTORECAUDOMCE VARCHAR(20), @CONCEPTORECAUDOMCI VARCHAR(20), @ESMODERADORAENFTR VARCHAR(2)
DECLARE @PAQUETIZADO INT = 0

BEGIN
    SET NOCOUNT ON
    DECLARE @json NVARCHAR(MAX)

    CREATE TABLE #USUARIOS (
        usuarioId INT IDENTITY(1,1) PRIMARY KEY,
        tipoDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
        tipoUsuario VARCHAR(2) COLLATE DATABASE_DEFAULT,
        fechaNacimiento VARCHAR(10) COLLATE DATABASE_DEFAULT,
        codSexo VARCHAR(1) COLLATE DATABASE_DEFAULT,
        codPaisResidencia VARCHAR(5) COLLATE DATABASE_DEFAULT,
        codPaisOrigen VARCHAR(5) COLLATE DATABASE_DEFAULT,
        codMunicipioResidencia VARCHAR(5) COLLATE DATABASE_DEFAULT,
        codZonaTerritorialResidencia VARCHAR(2) COLLATE DATABASE_DEFAULT,
        incapacidad VARCHAR(20) COLLATE DATABASE_DEFAULT
    )

    CREATE TABLE #CONSULTAS (
        codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        fechaInicioAtencion VARCHAR(16) COLLATE DATABASE_DEFAULT,
        numAutorizacion VARCHAR(30) COLLATE DATABASE_DEFAULT,
        codConsulta VARCHAR(6) COLLATE DATABASE_DEFAULT,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE DATABASE_DEFAULT,
        grupoServicios VARCHAR(2) COLLATE DATABASE_DEFAULT,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE DATABASE_DEFAULT,
        causaMotivoAtencion VARCHAR(2) COLLATE DATABASE_DEFAULT,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoRelacionado1 VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoRelacionado2 VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoRelacionado3 VARCHAR(20) COLLATE DATABASE_DEFAULT,
        tipoDiagnosticoPrincipal VARCHAR(3) COLLATE DATABASE_DEFAULT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
        numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        vrServicio DECIMAL(14,2),
        conceptoRecaudo VARCHAR(20) COLLATE DATABASE_DEFAULT,
        tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
        valorPagoModerador DECIMAL(14,2),
        numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
        usuarioId INT,
        ID INT IDENTITY(1,1),
        xconsecutivo INT
    )
    CREATE INDEX IX_CONSULTAS_IDAFILIADO ON #CONSULTAS (IDAFILIADO)
    CREATE INDEX IX_CONSULTAS_USUARIO ON #CONSULTAS (usuarioId)

    CREATE TABLE #OTROSSER (
        codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
        CONSECUTIVO VARCHAR(20) COLLATE DATABASE_DEFAULT,
        numAutorizacion VARCHAR(30) COLLATE DATABASE_DEFAULT,
        idMIPRES VARCHAR(15) COLLATE DATABASE_DEFAULT,
        fechaSuministroTecnologia VARCHAR(16) COLLATE DATABASE_DEFAULT,
        tipoOS VARCHAR(2) COLLATE DATABASE_DEFAULT,
        codTecnologiaSalud VARCHAR(20) COLLATE DATABASE_DEFAULT,
        nomTecnologiaSalud VARCHAR(60) COLLATE DATABASE_DEFAULT,
        cantidadOS INT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
        numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        vrUnitOS DECIMAL(14,2),
        vrServicio DECIMAL(14,2),
        conceptoRecaudo VARCHAR(20) COLLATE DATABASE_DEFAULT,
        tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
        valorPagoModerador DECIMAL(14,2),
        numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        usuarioId INT,
        ID INT IDENTITY(1,1),
        xconsecutivo INT
    )
    CREATE INDEX IX_OTROSSER_IDAFILIADO ON #OTROSSER (IDAFILIADO)
    CREATE INDEX IX_OTROSSER_USUARIO ON #OTROSSER (usuarioId)

    SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
    SELECT @IDMEDICODEFAULT = DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')

    SELECT @CNSFCT = CNSFCT, @PAQUETE = COALESCE(FTR.PAQUETE, 0), @PROCEDENCIA = FTR.PROCEDENCIA
    FROM FTR WITH(NOLOCK)
    WHERE N_FACTURA = @N_FACTURA AND TIPOFAC = 'M'

    IF NOT EXISTS(SELECT 1 FROM FTRD WITH(NOLOCK) WHERE CNSFTR = @CNSFCT)
    BEGIN
        RAISERROR('FACTURA MASIVA SIN RELACION DE SERVICIOS, POR FAVOR VERIFIQUE.', 16, 1)
        RETURN
    END

    IF NOT EXISTS(SELECT 1 FROM FTR WITH(NOLOCK) WHERE CNSFCT = @CNSFCT AND COALESCE(PAQUETE, 0) = 1 AND PROCEDENCIA = 'CI' AND TIPOFAC = 'M')
    BEGIN
        RAISERROR('FACTURA NO ES DE PROCEDENCIA DE CITAS PAQUETE', 16, 1)
        RETURN
    END

    SELECT @PAQUETIZADO = COALESCE(PPT.PAQUETIZADO, 0)
    FROM FTR WITH(NOLOCK)
    INNER JOIN PPT WITH(NOLOCK) ON PPT.IDTERCERO = FTR.IDTERCERO AND PPT.IDPLAN = FTR.IDPLAN
    WHERE FTR.CNSFCT = @CNSFCT

    SELECT @TIPO_ID_MEDICODEFAULT = TIPO_ID FROM MED WITH(NOLOCK) WHERE IDMEDICO = @IDMEDICODEFAULT

    SELECT @conceptoRecaudo = '05'
    SELECT @IDPRESTADOR = COALESCE(SED.CODHABILITA, 'No tengo'), @numDocumentoIdObligado = SED.NIT
    FROM FTR WITH(NOLOCK)
    INNER JOIN SED WITH(NOLOCK) ON SED.IDSEDE = FTR.IDSEDE
    WHERE FTR.CNSFCT = @CNSFCT

    IF EXISTS(SELECT 1 FROM FDIANR WITH(NOLOCK)
              WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV'
                AND COALESCE(XML_AttachedDocument, '') != '')
    BEGIN
        IF EXISTS(SELECT 1 FROM FDIANR WITH(NOLOCK)
                  WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV'
                    AND COALESCE(XML_AttachedDocument, '') != ''
                    AND CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>', XML_AttachedDocument) > 0)
        BEGIN
            SELECT @ESMODERADORAENFTR = '02'
        END
    END
    ELSE
    BEGIN
        IF EXISTS(SELECT 1 FROM FDIANR WITH(NOLOCK)
                  WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV'
                    AND COALESCE(CONVERT(NVARCHAR(MAX), XML_SOLICITUD), '') != '')
        BEGIN
            IF EXISTS(SELECT 1 FROM FDIANR WITH(NOLOCK)
                      WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV'
                        AND COALESCE(CONVERT(NVARCHAR(MAX), XML_SOLICITUD), '') != ''
                        AND CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>', CONVERT(NVARCHAR(MAX), XML_SOLICITUD)) > 0)
            BEGIN
                SELECT @ESMODERADORAENFTR = '02'
            END
        END
    END

    IF COALESCE(@PAQUETE, 0) = 1 AND @PROCEDENCIA = 'CI'
    BEGIN
        UPDATE FTRD SET PROCEDENCIA = 'CI'
        FROM FTR WITH(NOLOCK)
        INNER JOIN FTRD ON FTR.N_FACTURA = FTRD.N_FACTURA
        WHERE FTRD.PROCEDENCIA IS NULL
          AND FTR.PROCEDENCIA = 'CI'
          AND FTRD.NOITEM = 99
          AND FTR.N_FACTURA = @N_FACTURA
    END

    SELECT @CONCEPTORECAUDOMCE = DATO1 FROM TGEN WITH(NOLOCK) WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'MCE'
    SELECT @CONCEPTORECAUDOMCI = DATO1 FROM TGEN WITH(NOLOCK) WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'MCI'
    SELECT @conceptoRecaudo = '05'

    INSERT INTO #USUARIOS(tipoDocumentoIdentificacion, numDocumentoIdentificacion, IDAFILIADO, tipoUsuario, fechaNacimiento, codSexo, codPaisResidencia, codPaisOrigen,
                         codMunicipioResidencia, codZonaTerritorialResidencia, incapacidad)
    SELECT DISTINCT
        AFI.TIPO_DOC,
        AFI.DOCIDAFILIADO,
        AFI.IDAFILIADO,
        CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') <> '' THEN AFI.TIPOUSUARIO
             ELSE CASE WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
                       WHEN AFI.TIPOAFILIADO = 'B' THEN '02'
                       WHEN AFI.TIPOAFILIADO = 'J' THEN '01'
                       WHEN AFI.TIPOAFILIADO = 'A' THEN '03'
                       WHEN AFI.TIPOAFILIADO = 'S' THEN '07'
                       WHEN AFI.TIPOAFILIADO = 'Sb' THEN '04'
                       WHEN AFI.TIPOAFILIADO = 'SR' THEN '05'
                       WHEN AFI.TIPOAFILIADO = 'TA' THEN '06'
                       WHEN AFI.TIPOAFILIADO = 'RE' THEN '07'
                       WHEN AFI.TIPOAFILIADO = 'SN' THEN '05'
                       WHEN AFI.TIPOAFILIADO = 'S/' THEN '05'
                       WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05'
                       ELSE '05' END END,
        REPLACE(CONVERT(VARCHAR, AFI.FNACIMIENTO, 102), '.', '-'),
        UPPER(LEFT(AFI.SEXO, 1)),
        '170',
        '170',
        AFI.CIUDAD,
        CASE WHEN AFI.ZONA = 'R' THEN '01' ELSE '02' END,
        'NO'
    FROM FTRD WITH(NOLOCK)
    INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = FTRD.IDAFI
    WHERE FTRD.CNSFTR = @CNSFCT

    /* OTROS SERVICIOS - Paquete CIT facturado (excluye AC cuando es paquetizado) */
    INSERT INTO #OTROSSER(codPrestador, IDAFILIADO, CONSECUTIVO, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS, codTecnologiaSalud, nomTecnologiaSalud,
                         cantidadOS, tipoDocumentoIdentificacion, numDocumentoIdentificacion, vrUnitOS, vrServicio, conceptoRecaudo, tipoPagoModerador,
                         valorPagoModerador, numFEVPagoModerador)
    SELECT
        @IDPRESTADOR,
        CIT.IDAFILIADO,
        CIT.CONSECUTIVO,
        DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION, 'null') IN ('', ' ', '  '), 'null', CIT.NOAUTORIZACION), 'A-Z0-9-'),
        'null',
        REPLACE(CONVERT(VARCHAR, CIT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, CIT.FECHA, 108), 5),
        CASE WHEN COALESCE(SER.TIPOOTRO, '0') = '0' THEN '04' ELSE IIF(LEN(SER.TIPOOTRO) = 1, CONCAT('0', SER.TIPOOTRO), SER.TIPOOTRO) END,
        SER.CODCUPS,
        LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO, '0-9 A-Z();:.,'), 60),
        FTRD.CANTIDAD,
        COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
        COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
        IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VALOR, 0)),
        IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VLR_SERVICI, 0)),
        IIF(@PAQUETIZADO = 1, @conceptoRecaudo,
            CASE WHEN COALESCE(FTRD.VLR_COPAGOS, 0) > 0 THEN
                     CASE WHEN COALESCE(FTRD.TCOPAGO, '') <> '' THEN FTRD.TCOPAGO
                          WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03') THEN '02'
                          ELSE '01' END
                 ELSE @conceptoRecaudo END),
        IIF(@PAQUETIZADO = 1, '01', '04'),
        IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VLR_COPAGOS, 0)),
        IIF(@PAQUETIZADO = 1, 'null', @N_FACTURA)
    FROM FTRD WITH(NOLOCK)
    INNER JOIN CIT WITH(NOLOCK) ON FTRD.NOADMISION = CIT.CONSECUTIVO
    INNER JOIN AFI WITH(NOLOCK) ON CIT.IDAFILIADO = AFI.IDAFILIADO
    INNER JOIN SER WITH(NOLOCK) ON FTRD.REFERENCIA = SER.IDSERVICIO
    INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
    LEFT JOIN MED WITH(NOLOCK) ON CIT.IDMEDICO = MED.IDMEDICO
    WHERE FTRD.CNSFTR = @CNSFCT

    /* CONSULTAS - Solo tercero paquetizado (PPT.PAQUETIZADO = 1) desde FTRD */
    IF @PAQUETIZADO = 1
    BEGIN
        SELECT CONSECUTIVOCIT, IDDX, TIPODX
        INTO #HCA_CIT
        FROM (
            SELECT
                HCA.CONSECUTIVOCIT,
                HCA.IDDX,
                HCA.TIPODX,
                RN = ROW_NUMBER() OVER (PARTITION BY HCA.CONSECUTIVOCIT ORDER BY HCA.FECHA DESC)
            FROM HCA WITH(NOLOCK)
            INNER JOIN CIT WITH(NOLOCK) ON CIT.CONSECUTIVO = HCA.CONSECUTIVOCIT
            INNER JOIN FTRD WITH(NOLOCK) ON FTRD.NOADMISION = CIT.CONSECUTIVO AND FTRD.CNSFTR = @CNSFCT
            WHERE COALESCE(HCA.ANULADA, 0) <> 1
        ) DX
        WHERE DX.RN = 1

        CREATE CLUSTERED INDEX IX_HCA_CIT ON #HCA_CIT (CONSECUTIVOCIT)

        /* CONSULTAS facturadas (FTRD + CIT) - ARCHIVO AC */
        INSERT INTO #CONSULTAS(codPrestador, fechaInicioAtencion, numAutorizacion, codConsulta, modalidadGrupoServicioTecSal, grupoServicios, codServicio,
                               finalidadTecnologiaSalud, causaMotivoAtencion, codDiagnosticoPrincipal, codDiagnosticoRelacionado1, codDiagnosticoRelacionado2,
                               codDiagnosticoRelacionado3, tipoDiagnosticoPrincipal, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                               vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
        SELECT
            @IDPRESTADOR,
            REPLACE(CONVERT(VARCHAR, CIT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, CIT.FECHA, 108), 5),
            DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION, 'null') IN ('', ' ', '  '), 'null', CIT.NOAUTORIZACION), 'A-Z0-9-'),
            LEFT(SER.CODCUPS, 6),
            '01',
            CASE WHEN COALESCE(SER.RIPS_GRUPO, '') = '' THEN '01' ELSE SER.RIPS_GRUPO END,
            CASE WHEN COALESCE(SER.RIPS_CODIGO, '') = '' THEN 325 ELSE TRY_CAST(SER.RIPS_CODIGO AS INT) END,
            LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1, '') <> '' THEN COALESCE(FINALIDADTGEN.DATO1, '12')
                      WHEN CIT.FINCONSULTA = '10' THEN COALESCE(FINALIDADTGEN.DATO1, '12')
                      WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA = '' OR CIT.FINCONSULTA <= '10'
                           THEN CASE WHEN COALESCE(MPE.FINALIDAD, '') <> '' THEN MPE.FINALIDAD ELSE COALESCE(FINALIDADTGEN.DATO1, '12') END
                      ELSE COALESCE(FINALIDADTGEN.DATO1, CIT.FINCONSULTA, '12')
                 END, 2),
            '38',
            LEFT(COALESCE(HCA.IDDX, CIT.IDDX, ''), 4),
            'null',
            'null',
            'null',
            CASE HCA.TIPODX
                WHEN 'Presuntivo' THEN '01'
                WHEN 'Impresion dx' THEN '01'
                WHEN 'Definitivo' THEN '01'
                WHEN 'Conf Nuevo' THEN '02'
                WHEN 'Conf Repet' THEN '03'
                ELSE '01'
            END,
            COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
            COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
            0,
            @conceptoRecaudo, --CASE WHEN COALESCE(CIT.VALORCOPAGO, 0) > 0 THEN
            --         CASE WHEN COALESCE(@ESMODERADORAENFTR, '') <> '' THEN @ESMODERADORAENFTR
            --              WHEN COALESCE(CIT.TIPOCOPAGO, '') <> '' THEN CIT.TIPOCOPAGO
            --              WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03') THEN '02'
            --              ELSE '01' END
            --     ELSE @conceptoRecaudo END,
            '01',
            0, --COALESCE(CIT.VALORCOPAGO, 0),
            'null',
            CIT.IDAFILIADO
        FROM FTRD WITH(NOLOCK)
        INNER JOIN CIT WITH(NOLOCK) ON FTRD.NOADMISION = CIT.CONSECUTIVO
        INNER JOIN SER WITH(NOLOCK) ON CIT.IDSERVICIO = SER.IDSERVICIO
        INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AC'
        INNER JOIN PRE WITH(NOLOCK) ON SER.PREFIJO = PRE.PREFIJO
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = CIT.IDAFILIADO
        LEFT JOIN MPE WITH(NOLOCK) ON MPE.IDPESPECIAL = CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP'
        LEFT JOIN TGEN FINALIDADTGEN WITH(NOLOCK) ON FINALIDADTGEN.TABLA = 'GENERAL' AND FINALIDADTGEN.CAMPO = 'FINALIDAD' AND FINALIDADTGEN.CODIGO = PRE.FINALIDAD
        LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = CIT.IDMEDICO
        LEFT JOIN #HCA_CIT HCA ON HCA.CONSECUTIVOCIT = CIT.CONSECUTIVO
        WHERE FTRD.CNSFTR = @CNSFCT

        UPDATE #CONSULTAS SET codDiagnosticoPrincipal = 'Z000'
        WHERE LEN(COALESCE(codDiagnosticoPrincipal, '')) < 4
    END

    DECLARE @TOTALAT INT, @TOTALFTRD INT
    SELECT @TOTALAT = COUNT(1) FROM #OTROSSER
    SELECT @TOTALFTRD = COUNT(1) FROM FTRD WITH(NOLOCK) WHERE CNSFTR = @CNSFCT

    IF @TOTALAT <> @TOTALFTRD
    BEGIN
        RAISERROR('Error de registros en servicios, el total no coincide con lo facturado', 16, 1)
    END

    UPDATE #OTROSSER SET usuarioId = US.usuarioId
    FROM #OTROSSER OT
    INNER JOIN #USUARIOS US ON OT.IDAFILIADO = US.IDAFILIADO

    UPDATE #CONSULTAS SET usuarioId = US.usuarioId
    FROM #CONSULTAS AC
    INNER JOIN #USUARIOS US ON AC.IDAFILIADO = US.IDAFILIADO

    ;WITH CTE AS (
        SELECT ID, IDAFILIADO,
            xconsecutivo = ROW_NUMBER() OVER (PARTITION BY IDAFILIADO ORDER BY ID ASC)
        FROM #OTROSSER
    )
    UPDATE OT SET OT.xconsecutivo = CTE.xconsecutivo
    FROM #OTROSSER OT
    INNER JOIN CTE ON OT.ID = CTE.ID

    ;WITH CTE AS (
        SELECT ID, IDAFILIADO,
            xconsecutivo = ROW_NUMBER() OVER (PARTITION BY IDAFILIADO ORDER BY ID ASC)
        FROM #CONSULTAS
    )
    UPDATE AC SET AC.xconsecutivo = CTE.xconsecutivo
    FROM #CONSULTAS AC
    INNER JOIN CTE ON AC.ID = CTE.ID

    IF @PAQUETIZADO = 1
    BEGIN
        SET @json = (
            SELECT
                rips = (
                    SELECT
                        numDocumentoIdObligado = @numDocumentoIdObligado,
                        numFactura = @N_FACTURA,
                        tipoNota = 'null',
                        numNota = 'null',
                        usuarios = (
                            SELECT
                                tipoDocumentoIdentificacion = u.tipoDocumentoIdentificacion,
                                numDocumentoIdentificacion = u.numDocumentoIdentificacion,
                                tipoUsuario = u.tipoUsuario,
                                fechaNacimiento = u.fechaNacimiento,
                                codSexo = u.codSexo,
                                codPaisResidencia = u.codPaisResidencia,
                                codPaisOrigen = u.codPaisOrigen,
                                codMunicipioResidencia = u.codMunicipioResidencia,
                                codZonaTerritorialResidencia = u.codZonaTerritorialResidencia,
                                incapacidad = u.incapacidad,
                                consecutivo = u.usuarioId,
                                registroSIRAS = 'null',
                                servicios = (
                                    SELECT
                                        consultas = JSON_QUERY((
                                            SELECT
                                                ac.codPrestador,
                                                ac.fechaInicioAtencion,
                                                numAutorizacion = NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(ac.numAutorizacion, CHAR(10), ''), CHAR(13), ''), CHAR(9), ''))), ''),
                                                ac.codConsulta,
                                                ac.modalidadGrupoServicioTecSal,
                                                ac.grupoServicios,
                                                ac.codServicio,
                                                ac.finalidadTecnologiaSalud,
                                                ac.causaMotivoAtencion,
                                                codDiagnosticoPrincipal = IIF(LEN(COALESCE(ac.codDiagnosticoPrincipal, '')) <> 4, 'null', ac.codDiagnosticoPrincipal),
                                                codDiagnosticoRelacionado1 = IIF(LEN(COALESCE(ac.codDiagnosticoRelacionado1, '')) <> 4, 'null', ac.codDiagnosticoRelacionado1),
                                                codDiagnosticoRelacionado2 = IIF(LEN(COALESCE(ac.codDiagnosticoRelacionado2, '')) <> 4, 'null', ac.codDiagnosticoRelacionado2),
                                                codDiagnosticoRelacionado3 = IIF(LEN(COALESCE(ac.codDiagnosticoRelacionado3, '')) <> 4, 'null', ac.codDiagnosticoRelacionado3),
                                                codDiagnosticoPrincipalCIE11 = 'null',
                                                nomCodDiagnosticoPrincipalCIE11 = 'null',
                                                codDiagnosticoRelacionado1CIE11 = 'null',
                                                nomCodDiagnosticoRelacionado1CIE11 = 'null',
                                                codDiagnosticoRelacionado2CIE11 = 'null',
                                                nomCodDiagnosticoRelacionado2CIE11 = 'null',
                                                codDiagnosticoRelacionado3CIE11 = 'null',
                                                nomCodDiagnosticoRelacionado3CIE11 = 'null',
                                                codigoVIDA = 'null',
                                                tipoDiagnosticoPrincipal = IIF(LEN(ac.tipoDiagnosticoPrincipal) < 2, '01', COALESCE(ac.tipoDiagnosticoPrincipal, '01')),
                                                ac.tipoDocumentoIdentificacion,
                                                ac.numDocumentoIdentificacion,
                                                ac.vrServicio,
                                                ac.conceptoRecaudo,
                                                ac.valorPagoModerador,
                                                numFEVPagoModerador = IIF(ac.numFEVPagoModerador IS NULL, 'null', ac.numFEVPagoModerador),
                                                consecutivo = ac.xconsecutivo
                                            FROM #CONSULTAS ac
                                            WHERE ac.usuarioId = u.usuarioId
                                            ORDER BY ac.xconsecutivo ASC
                                            FOR JSON PATH, INCLUDE_NULL_VALUES
                                        )),
                                        otrosServicios = JSON_QUERY((
                                            SELECT
                                                os.codPrestador,
                                                os.numAutorizacion,
                                                os.idMIPRES,
                                                os.fechaSuministroTecnologia,
                                                os.tipoOS,
                                                os.codTecnologiaSalud,
                                                os.nomTecnologiaSalud,
                                                os.cantidadOS,
                                                os.tipoDocumentoIdentificacion,
                                                os.numDocumentoIdentificacion,
                                                os.vrUnitOS,
                                                os.vrServicio,
                                                vrDispensacion = CAST(0 AS DECIMAL(14,2)),
                                                codigoVIDA = 'null',
                                                os.conceptoRecaudo,
                                                os.valorPagoModerador,
                                                IIF(os.numFEVPagoModerador IS NULL, 'null', os.numFEVPagoModerador) numFEVPagoModerador,
                                                consecutivo = os.xconsecutivo
                                            FROM #OTROSSER os
                                            WHERE os.usuarioId = u.usuarioId
                                            ORDER BY os.xconsecutivo ASC
                                            FOR JSON PATH
                                        ))
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                )
                            FROM #USUARIOS u
                            ORDER BY usuarioId ASC
                            FOR JSON PATH
                        )
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ),
                xmlFevFile = '@XMLFEVFILE'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    END
    ELSE
    BEGIN
        SET @json = (
            SELECT
                rips = (
                    SELECT
                        numDocumentoIdObligado = @numDocumentoIdObligado,
                        numFactura = @N_FACTURA,
                        tipoNota = 'null',
                        numNota = 'null',
                        usuarios = (
                            SELECT
                                tipoDocumentoIdentificacion = u.tipoDocumentoIdentificacion,
                                numDocumentoIdentificacion = u.numDocumentoIdentificacion,
                                tipoUsuario = u.tipoUsuario,
                                fechaNacimiento = u.fechaNacimiento,
                                codSexo = u.codSexo,
                                codPaisResidencia = u.codPaisResidencia,
                                codPaisOrigen = u.codPaisOrigen,
                                codMunicipioResidencia = u.codMunicipioResidencia,
                                codZonaTerritorialResidencia = u.codZonaTerritorialResidencia,
                                incapacidad = u.incapacidad,
                                consecutivo = u.usuarioId,
                                registroSIRAS = 'null',
                                servicios = (
                                    SELECT
                                        otrosServicios = (
                                            SELECT
                                                os.codPrestador,
                                                os.numAutorizacion,
                                                os.idMIPRES,
                                                os.fechaSuministroTecnologia,
                                                os.tipoOS,
                                                os.codTecnologiaSalud,
                                                os.nomTecnologiaSalud,
                                                os.cantidadOS,
                                                os.tipoDocumentoIdentificacion,
                                                os.numDocumentoIdentificacion,
                                                os.vrUnitOS,
                                                os.vrServicio,
                                                vrDispensacion = CAST(0 AS DECIMAL(14,2)),
                                                codigoVIDA = 'null',
                                                os.conceptoRecaudo,
                                                os.valorPagoModerador,
                                                IIF(os.numFEVPagoModerador IS NULL, 'null', os.numFEVPagoModerador) numFEVPagoModerador,
                                                consecutivo = os.xconsecutivo
                                            FROM #OTROSSER os
                                            WHERE os.usuarioId = u.usuarioId
                                            ORDER BY os.xconsecutivo ASC
                                            FOR JSON PATH
                                        )
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                )
                            FROM #USUARIOS u
                            ORDER BY usuarioId ASC
                            FOR JSON PATH
                        )
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ),
                xmlFevFile = '@XMLFEVFILE'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    END

    SELECT @JSON = REPLACE(@JSON, '\"', '"')
    SELECT @JSON = REPLACE(@JSON, '\\"', '"')
    SELECT @JSON = REPLACE(@JSON, '"{', '{')
    SELECT @JSON = REPLACE(@JSON, '}"', '}')
    SELECT @JSON = REPLACE(@JSON, '"null"', 'null')
    SELECT @PLANO = @json

    IF 1 = 1
    BEGIN
        SELECT @base64 = CAST('' AS XML).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
        FROM (
            SELECT [binaryValue] = CAST(dbo.FNK_AttachedDocument(@CNSFCT, 'FV') AS VARBINARY(MAX))
        ) AS conv

        SELECT @PLANO = REPLACE(@PLANO, '@XMLFEVFILE', @base64)
    END

    IF COALESCE(@URL_PATH, '') <> ''
    BEGIN
        SELECT @N_FACTURA = @N_FACTURA + '.json'
        EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
        SELECT @PLANO = @URL_PATH + IIF(RIGHT(@URL_PATH, 1) = '\', '', '\') + @N_FACTURA
    END

    IF OBJECT_ID('tempdb..#USUARIOS') IS NOT NULL DROP TABLE #USUARIOS
    IF OBJECT_ID('tempdb..#CONSULTAS') IS NOT NULL DROP TABLE #CONSULTAS
    IF OBJECT_ID('tempdb..#OTROSSER') IS NOT NULL DROP TABLE #OTROSSER
    IF OBJECT_ID('tempdb..#HCA_CIT') IS NOT NULL DROP TABLE #HCA_CIT
END

