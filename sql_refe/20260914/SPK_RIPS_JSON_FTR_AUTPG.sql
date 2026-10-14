CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_FTR_AUTPG
    @N_FACTURA  VARCHAR(20),
    @URL_PATH VARCHAR(MAX)=NULL,
    @XML_BASE64 NVARCHAR(MAX)=NULL,
    @PLANO NVARCHAR(MAX) OUTPUT
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
DECLARE @RIPS_CITSOLOCUMPLIDA VARCHAR(10) = ''
DECLARE @PREFIJOMEDICAMENTOS VARCHAR(20) = ''
DECLARE @PGP_AUT_SOLODISPENSA VARCHAR(10) = ''
DECLARE @IDTERCERO VARCHAR(20)
DECLARE @FECHA_FACTURA DATETIME
DECLARE @FECHA_LIMITE_CIT DATETIME
DECLARE @FECHAINICAP DATETIME
DECLARE @FECHAFINCAP DATETIME
DECLARE @XMLFEV NVARCHAR(MAX)
DECLARE @BLOQUEPERIODO NVARCHAR(500)
DECLARE @POSXML INT

BEGIN
    SET NOCOUNT ON
    /*
      MAXDOP 1: evita deadlock intra-query
      "was deadlocked on lock | communication buffer resources".
      Los INSERT/SELECT sobre CIT, AUT, HCA, VWK_CARGOS_HADMAUTCIT_ART y FOR JSON
      generan planes paralelos; los hilos del mismo SP se bloquean entre s?.
    */
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

    CREATE TABLE #MEDICAMENTOS (
        codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        numAutorizacion VARCHAR(30) COLLATE DATABASE_DEFAULT,
        idMIPRES VARCHAR(15) COLLATE DATABASE_DEFAULT,
        fechaDispensAdmon VARCHAR(16) COLLATE DATABASE_DEFAULT,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE DATABASE_DEFAULT,
        tipoMedicamento VARCHAR(4) COLLATE DATABASE_DEFAULT,
        codTecnologiaSalud VARCHAR(20) COLLATE DATABASE_DEFAULT,
        nomTecnologiaSalud VARCHAR(30) COLLATE DATABASE_DEFAULT,
        concentracionMedicamento INT,
        unidadMedida INT,
        formaFarmaceutica VARCHAR(8) COLLATE DATABASE_DEFAULT,
        unidadMinDispensa INT,
        cantidadMedicamento INT,
        diasTratamiento SMALLINT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
        numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        vrUnitMedicamento DECIMAL(14,2),
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
    CREATE INDEX IX_MEDICAMENTOS_IDAFILIADO ON #MEDICAMENTOS (IDAFILIADO)
    CREATE INDEX IX_MEDICAMENTOS_USUARIO ON #MEDICAMENTOS (usuarioId)

    CREATE TABLE #PROCEDIMIENTOS (
        codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
        fechaInicioAtencion VARCHAR(16) COLLATE DATABASE_DEFAULT,
        idMIPRES VARCHAR(15) COLLATE DATABASE_DEFAULT,
        numAutorizacion VARCHAR(30) COLLATE DATABASE_DEFAULT,
        codProcedimiento VARCHAR(6) COLLATE DATABASE_DEFAULT,
        vialngresoServicioSalud VARCHAR(2) COLLATE DATABASE_DEFAULT,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE DATABASE_DEFAULT,
        grupoServicios VARCHAR(2) COLLATE DATABASE_DEFAULT,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE DATABASE_DEFAULT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
        numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE DATABASE_DEFAULT,
        codComplicacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
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
    CREATE INDEX IX_PROCEDIMIENTOS_IDAFILIADO ON #PROCEDIMIENTOS (IDAFILIADO)
    CREATE INDEX IX_PROCEDIMIENTOS_USUARIO ON #PROCEDIMIENTOS (usuarioId)

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

    /* Cache de variables de configuraci?n */
    SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
    SELECT @IDMEDICODEFAULT = DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')
    SELECT @RIPS_CITSOLOCUMPLIDA = COALESCE(DATO, '') FROM USVGS WITH(NOLOCK) WHERE IDVARIABLE = 'RIPS_CITSOLOCUMPLIDA'
    SELECT @PREFIJOMEDICAMENTOS = DATO FROM USVGS WITH(NOLOCK) WHERE IDVARIABLE = 'PREFIJOMEDICAMENTOS'
    SELECT @PGP_AUT_SOLODISPENSA = COALESCE(DBO.FNK_VALORVARIABLE('PGP_AUT_SOLODISPENSA'), '')

    SELECT @CNSFCT = CNSFCT, @PAQUETE = COALESCE(FTR.PAQUETE,0), @PROCEDENCIA = FTR.PROCEDENCIA,
           @FECHA_FACTURA = COALESCE(FTR.F_FACTURA, FTR.FECHAFAC),
           @FECHAINICAP = FTR.FECHACAP_INI, @FECHAFINCAP = FTR.FECHACAP_FIN
    FROM FTR WITH(NOLOCK)
    WHERE N_FACTURA = @N_FACTURA AND TIPOFAC = 'M'

    SET @FECHA_LIMITE_CIT = DATEADD(DAY, 1, CAST(COALESCE(@FECHA_FACTURA, GETDATE()) AS DATE))

    IF NOT EXISTS(SELECT 1 FROM FTRD WITH(NOLOCK) WHERE CNSFTR = @CNSFCT)
    BEGIN
        RAISERROR('FACTURA MASIVA SIN RELACION DE SERVICIOS, POR FAVOR VERIFIQUE.', 16, 1)
        RETURN
    END

    IF NOT EXISTS(SELECT 1 FROM FTR WITH(NOLOCK) WHERE CNSFCT = @CNSFCT AND PROCEDENCIA = 'AUTPG')
    BEGIN
        RAISERROR('FACTURA NO ES DE PROCEDENCIA DE PROGRAMA', 16, 1)
        RETURN
    END

    SELECT @PAQUETIZADO = COALESCE(PPT.PAQUETIZADO, 0), @IDTERCERO = FTR.IDTERCERO
    FROM FTR WITH(NOLOCK)
    INNER JOIN PPT WITH(NOLOCK) ON PPT.IDTERCERO = FTR.IDTERCERO AND PPT.IDPLAN = FTR.IDPLAN
    WHERE FTR.CNSFCT = @CNSFCT

    SELECT @TIPO_ID_MEDICODEFAULT = TIPO_ID FROM MED WITH(NOLOCK) WHERE IDMEDICO = @IDMEDICODEFAULT

    SELECT @conceptoRecaudo = '05'
    SELECT @IDPRESTADOR = COALESCE(SED.CODHABILITA,'No tengo'), @numDocumentoIdObligado = SED.NIT
    FROM FTR WITH(NOLOCK)
    INNER JOIN SED WITH(NOLOCK) ON SED.IDSEDE = FTR.IDSEDE
    WHERE FTR.CNSFCT = @CNSFCT

    /* FDIANR: cuota moderadora e InvoicePeriod (mismo XML que valida SISPRO / RVC014) */
    SELECT TOP 1
        @XMLFEV = CASE
            WHEN COALESCE(CONVERT(NVARCHAR(MAX), XML_AttachedDocument), '') <> ''
                THEN CONVERT(NVARCHAR(MAX), XML_AttachedDocument)
            ELSE CONVERT(NVARCHAR(MAX), XML_SOLICITUD)
        END
    FROM FDIANR WITH(NOLOCK)
    WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV'

    IF CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>', COALESCE(@XMLFEV, '')) > 0
        SET @ESMODERADORAENFTR = '02'

    SET @POSXML = CHARINDEX('<cac:InvoicePeriod>', COALESCE(@XMLFEV, ''))
    IF @POSXML > 0
    BEGIN
        SET @BLOQUEPERIODO = SUBSTRING(
            @XMLFEV,
            @POSXML,
            NULLIF(CHARINDEX('</cac:InvoicePeriod>', @XMLFEV, @POSXML), 0) - @POSXML
        )
        SET @POSXML = CHARINDEX('<cbc:StartDate>', COALESCE(@BLOQUEPERIODO, ''))
        IF @POSXML > 0
            SET @FECHAINICAP = TRY_CONVERT(DATE, SUBSTRING(@BLOQUEPERIODO, @POSXML + 15, 10), 23)
        SET @POSXML = CHARINDEX('<cbc:EndDate>', COALESCE(@BLOQUEPERIODO, ''))
        IF @POSXML > 0
            SET @FECHAFINCAP = TRY_CONVERT(DATE, SUBSTRING(@BLOQUEPERIODO, @POSXML + 13, 10), 23)
    END

    /* Si el XML no trae periodo, se usa FECHACAP o F_FACTURA */
    IF @FECHAINICAP IS NULL AND @FECHA_FACTURA IS NOT NULL
        SET @FECHAINICAP = DATEFROMPARTS(YEAR(@FECHA_FACTURA), MONTH(@FECHA_FACTURA), 1)
    IF @FECHAFINCAP IS NULL AND @FECHA_FACTURA IS NOT NULL
        SET @FECHAFINCAP = CAST(@FECHA_FACTURA AS DATE)
    IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL AND @FECHAFINCAP < @FECHAINICAP
        SET @FECHAFINCAP = CAST(@FECHA_FACTURA AS DATE)

    /* USUARIOS */
    BEGIN
        SELECT @CONCEPTORECAUDOMCE = DATO1 FROM TGEN WITH(NOLOCK) WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'MCE'
        SELECT @CONCEPTORECAUDOMCI = DATO1 FROM TGEN WITH(NOLOCK) WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'MCI'
        SELECT @conceptoRecaudo = '05'

        INSERT INTO #USUARIOS(tipoDocumentoIdentificacion, numDocumentoIdentificacion, IDAFILIADO, tipoUsuario, fechaNacimiento, codSexo, codPaisResidencia, codPaisOrigen,
                             codMunicipioResidencia, codZonaTerritorialResidencia, incapacidad)
        SELECT DISTINCT
            AFI.TIPO_DOC,
            AFI.DOCIDAFILIADO,
            AFI.IDAFILIADO,
            CASE WHEN COALESCE(AUTPG.TIPO_USUARIO,'') <> '' THEN AUTPG.TIPO_USUARIO
                 WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN AFI.TIPOUSUARIO
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
        LEFT JOIN AUTPG WITH(NOLOCK) ON CONVERT(VARCHAR(20), AUTPG.ID) = FTRD.NOADMISION
        WHERE FTRD.CNSFTR = @CNSFCT
        OPTION (MAXDOP 1)
    END

    /* AUTPG de la factura - tabla temporal indexada (evita escaneos sobre la vista) */
    SELECT
        AUTPG_ID    = AUTPG.ID,
        IDAFILIADO  = AUTPG.IDAFILIADO,
        IDTERCEROCA = AUTPG.IDTERCEROCA,
        IDPLAN      = AUTPG.IDPLAN,
        ANOMES      = AUTPG.ANOMES,
        IDPESPECIAL = AUTPG.IDPESPECIAL,
        IDDX        = AUTPG.IDDX,
        NOAUTORIZACION = AUTPG.NOAUTORIZACION,
        IDMEDICO    = CAST(NULL AS VARCHAR(12))
    INTO #AUTPG_FTR
    FROM FTRD WITH(NOLOCK)
    INNER JOIN AUTPG WITH(NOLOCK) ON FTRD.NOADMISION = AUTPG.ID
    WHERE FTRD.CNSFTR = @CNSFCT
    OPTION (MAXDOP 1)

    CREATE CLUSTERED INDEX IX_AUTPG_FTR_PK ON #AUTPG_FTR (AUTPG_ID)
    CREATE NONCLUSTERED INDEX IX_AUTPG_FTR_CIT ON #AUTPG_FTR (IDAFILIADO, ANOMES, IDPESPECIAL, IDPLAN)

    ;WITH MedicoPorAutpg AS (
        SELECT APG.AUTPG_ID, A.IDMEDICO,
               RN = ROW_NUMBER() OVER (PARTITION BY APG.AUTPG_ID ORDER BY A.FECHA DESC)
        FROM #AUTPG_FTR APG
        INNER JOIN VWK_CARGOS_HADMAUTCIT_ART A WITH(NOLOCK)
            ON A.IDAFILIADO = APG.IDAFILIADO
           AND A.IDTERCEROCA = APG.IDTERCEROCA
           AND A.ANOMES = APG.ANOMES
           AND A.FECHA < GETDATE()
           AND A.IDMEDICO <> ''
    )
    UPDATE APG
    SET IDMEDICO = M.IDMEDICO
    FROM #AUTPG_FTR APG
    INNER JOIN MedicoPorAutpg M ON M.AUTPG_ID = APG.AUTPG_ID AND M.RN = 1
    OPTION (MAXDOP 1)

    /* Fallback: m?dico de epicrisis de ?ltima atenci?n (misma l?gica que soportes GET_ANEXOS / Masivos) */
    ;WITH PlanesPaqueteMed AS (
        SELECT DISTINCT PLN.IDPLAN
        FROM PPT WITH (NOLOCK)
        INNER JOIN PLN WITH (NOLOCK) ON PPT.IDPLAN = PLN.IDPLAN
        WHERE PPT.IDTERCERO = @IDTERCERO AND PLN.ESPAQUETE = 1
    ),
    AtencionesClinicasRef AS (
        SELECT
            APG.AUTPG_ID,
            APG.IDAFILIADO,
            HCA_MR.IDMEDICO,
            HCA_MR.FECHA,
            HCA_MR.CONSECUTIVO,
            CIT_MR.ANOMES,
            ES_VIRTUAL = CASE WHEN CIT_MR.MODALIDAD = 'Virtual' THEN 1 ELSE 0 END
        FROM #AUTPG_FTR APG
        INNER JOIN HCA HCA_MR WITH (NOLOCK) ON APG.IDAFILIADO = HCA_MR.IDAFILIADO
        INNER JOIN CIT CIT_MR WITH (NOLOCK) ON HCA_MR.CONSECUTIVOCIT = CIT_MR.CONSECUTIVO
            AND CIT_MR.IDTERCEROCA = APG.IDTERCEROCA
            AND (CIT_MR.IDPLAN = APG.IDPLAN OR CIT_MR.IDPLAN IN (SELECT IDPLAN FROM PlanesPaqueteMed))
        INNER JOIN MPEMES MPEMES_MR WITH (NOLOCK) ON MPEMES_MR.IDPESPECIAL = CIT_MR.IDPESPECIAL AND MPEMES_MR.IDEMEDICA = CIT_MR.IDEMEDICA
        INNER JOIN MPL MPL_MR WITH (NOLOCK) ON MPL_MR.CLASEPLANTILLA = HCA_MR.CLASEPLANTILLA AND COALESCE(MPL_MR.NOFACTURABLE, 0) = 0
        WHERE COALESCE(HCA_MR.ANULADA, 0) <> 1
          AND COALESCE(HCA_MR.IDMEDICO, '') <> ''
          AND COALESCE(APG.IDMEDICO, '') = ''
    ),
    MesReferencia AS (
        SELECT IDAFILIADO, MAX(ANOMES) AS ANOMES_REFERENCIA
        FROM AtencionesClinicasRef
        GROUP BY IDAFILIADO
    ),
    MedicoUltimaAtencion AS (
        SELECT
            ACV.AUTPG_ID,
            ACV.IDMEDICO,
            RN = ROW_NUMBER() OVER (
                PARTITION BY ACV.AUTPG_ID
                ORDER BY ACV.ES_VIRTUAL ASC, ACV.FECHA DESC, ACV.CONSECUTIVO DESC
            )
        FROM AtencionesClinicasRef ACV
        INNER JOIN MesReferencia MR ON ACV.IDAFILIADO = MR.IDAFILIADO AND ACV.ANOMES = MR.ANOMES_REFERENCIA
    )
    UPDATE APG
    SET IDMEDICO = M.IDMEDICO
    FROM #AUTPG_FTR APG
    INNER JOIN MedicoUltimaAtencion M ON M.AUTPG_ID = APG.AUTPG_ID AND M.RN = 1
    WHERE COALESCE(APG.IDMEDICO, '') = ''
    OPTION (MAXDOP 1)

    /* OTROS SERVICIOS - Paquete AUTPG facturado */
    BEGIN
        INSERT INTO #OTROSSER(codPrestador, IDAFILIADO, CONSECUTIVO, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS, codTecnologiaSalud, nomTecnologiaSalud,
                             cantidadOS, tipoDocumentoIdentificacion, numDocumentoIdentificacion, vrUnitOS, vrServicio, conceptoRecaudo, tipoPagoModerador,
                             valorPagoModerador, numFEVPagoModerador)
        SELECT
            @IDPRESTADOR,
            AUTPG.IDAFILIADO,
            AUTPG.ID,
            DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUTPG.NOAUTORIZACION, 'null') IN ('', ' ', '  '), 'null', AUTPG.NOAUTORIZACION), 'A-Z0-9-'),
            'null',
            LEFT(AUTPG.ANOMES, 4) + '-' + RIGHT(AUTPG.ANOMES, 2) + '-01 00:00',
            CASE WHEN COALESCE(SER.TIPOOTRO,'0') = '0' THEN '04' ELSE IIF(LEN(SER.TIPOOTRO) = 1, CONCAT('0', SER.TIPOOTRO), SER.TIPOOTRO) END,
            SER.CODCUPS,
            LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO, '0-9 A-Z();:.,'), 60),
            FTRD.CANTIDAD,
            IIF(TGEN.CHECK2=1, 'CC',COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT,'CC')),
            IIF(TGEN.CHECK2=1, @IDMEDICODEFAULT, COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT)),
            IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VALOR, 0)),
            IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VLR_SERVICI, 0)),
            IIF(@PAQUETIZADO = 1, @conceptoRecaudo,
                CASE WHEN COALESCE(FTRD.VLR_COPAGOS, 0) > 0 THEN
                         CASE WHEN COALESCE(FTRD.TCOPAGO,'') <> '' THEN FTRD.TCOPAGO
                              WHEN COALESCE(AFI.TIPOUSUARIO,'') IN ('01','02','03') THEN '02'
                              ELSE '01' END
                     ELSE @conceptoRecaudo END),
            IIF(@PAQUETIZADO = 1, '01', '04'),
            IIF(@PAQUETIZADO = 1, 0, COALESCE(FTRD.VLR_COPAGOS, 0)),
            'null'
        FROM FTRD WITH(NOLOCK)
        INNER JOIN AUTPG WITH(NOLOCK) ON FTRD.NOADMISION = AUTPG.ID
        INNER JOIN #AUTPG_FTR APG ON APG.AUTPG_ID = AUTPG.ID
        INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = FTRD.REFERENCIA
        INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = FTRD.IDAFI
        LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = APG.IDMEDICO
        LEFT JOIN TGEN ON TGEN.TABLA='MED' AND TGEN.CAMPO='TIPO_USUARIO' AND TGEN.CODIGO=MED.TIPO_USUARIO
        WHERE FTRD.CNSFTR = @CNSFCT
        OPTION (MAXDOP 1)
    END

    /* CONSULTAS Y MEDICAMENTOS - Solo tercero paquetizado (PPT.PAQUETIZADO = 1) */
    IF @PAQUETIZADO = 1
    BEGIN
        /* Planes paquete del tercero (EPS): misma l?gica que GET_ANEXOS_MASIVOS_V2 */
        IF OBJECT_ID('tempdb..#PlanesPaquete') IS NOT NULL DROP TABLE #PlanesPaquete;

        SELECT DISTINCT PLN.IDPLAN
        INTO #PlanesPaquete
        FROM PPT WITH (NOLOCK)
        INNER JOIN PLN WITH (NOLOCK) ON PPT.IDPLAN = PLN.IDPLAN
        WHERE PPT.IDTERCERO = @IDTERCERO AND PLN.ESPAQUETE = 1
        OPTION (MAXDOP 1);

        CREATE UNIQUE CLUSTERED INDEX IX_PlanesPaquete ON #PlanesPaquete (IDPLAN);

        /* AUT + AUTD del periodo AUTPG (un solo escaneo para consultas/medicamentos) */
        SELECT
            AP.AUTPG_ID,
            AP.IDAFILIADO,
            AP.IDDX,
            AP.ANOMES,
            AP.NOAUTORIZACION,
            AUT.IDAUT,
            AUT.FECHA,
            AUT.NUMAUTORIZA,
            AUT.IDMIPRESS,
            AUT.DXPPAL,
            AUT.DXRELACIONADO,
            AUT.DXRELACIONADO2,
            AUT.COMPLICACION,
            AUT.FINALIDAD,
            AUT.IDMEDICOSOLICITA,
            AUT.CNSMOV,
            AUT.IDPROVEEDOR,
            AUT.PROCEDENCIA,
            AUTD.IDSERVICIO,
            AUTD.CANTIDAD,
            AUTD.DIAS,
            AUTD.CODCUM_DISP,
            fechaInicioAtencion = CONCAT(REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-'), ' ', LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5)),
            numAutorizacionLimpia = DBO.FNK_LIMPIATEXTO(
                IIF(COALESCE(NULLIF(LTRIM(RTRIM(AP.NOAUTORIZACION)), ''), '') <> '',
                    AP.NOAUTORIZACION,
                    IIF(COALESCE(AUT.NUMAUTORIZA, 'null') IN ('', ' ', '  '), 'null', AUT.NUMAUTORIZA)),
                'A-Z0-9-'),
            fechaDispensAdmon = IIF(
                CAST(AUT.FECHA AS DATE) > CAST(GETDATE() AS DATE),
                CONCAT(LEFT(AP.ANOMES, 4), '-', RIGHT(AP.ANOMES, 2), '-01 00:00'),
                CONCAT(REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-'), ' ', LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5)))
        INTO #AUT_PERIODO
        FROM #AUTPG_FTR AP
        INNER JOIN AUT WITH(NOLOCK) ON AUT.IDAFILIADO = AP.IDAFILIADO
            AND AUT.IDTERCEROCA = AP.IDTERCEROCA
            AND AUT.FECHA >= CONVERT(DATE, CONCAT(AP.ANOMES, '01'))
            AND AUT.FECHA < DATEADD(MONTH, 1, CONVERT(DATE, CONCAT(AP.ANOMES, '01')))
            AND AUT.FECHA < @FECHA_LIMITE_CIT
        INNER JOIN #PlanesPaquete PP ON AUT.IDPLAN = PP.IDPLAN
        INNER JOIN AUTD WITH(NOLOCK) ON AUTD.IDAUT = AUT.IDAUT
            AND COALESCE(AUTD.NOCOBRABLE, 0) = 0
            AND COALESCE(AUTD.CANTIDAD, 0) > 0
        OPTION (MAXDOP 1)

        CREATE CLUSTERED INDEX IX_AUT_PERIODO_PK ON #AUT_PERIODO (AUTPG_ID, IDAUT, IDSERVICIO)
        CREATE NONCLUSTERED INDEX IX_AUT_PERIODO_SRV ON #AUT_PERIODO (IDSERVICIO, IDAFILIADO)

        /* Diagn?sticos HCA de las citas del periodo/programa en un solo paso */
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
            INNER JOIN #AUTPG_FTR APG ON APG.IDAFILIADO = CIT.IDAFILIADO
                AND APG.ANOMES = CIT.ANOMES
                --AND APG.IDPESPECIAL = CIT.IDPESPECIAL
            WHERE CIT.IDTERCEROCA = APG.IDTERCEROCA
              AND CIT.IDPLAN IN (SELECT IDPLAN FROM #PlanesPaquete)
              AND CIT.FECHA < @FECHA_LIMITE_CIT
              AND CIT.IDAUTSES IS NULL
              AND (@RIPS_CITSOLOCUMPLIDA <> 'SI' OR COALESCE(CIT.CUMPLIDA, 0) = 1)
              AND COALESCE(HCA.ANULADA, 0) <> 1
        ) DX
        WHERE DX.RN = 1
        OPTION (MAXDOP 1)

        CREATE CLUSTERED INDEX IX_HCA_CIT ON #HCA_CIT (CONSECUTIVOCIT)

        /* CONSULTAS (CIT) del IDPESPECIAL del AUTPG - consulta directa sin vista */
        INSERT INTO #CONSULTAS(codPrestador, fechaInicioAtencion, numAutorizacion, codConsulta, modalidadGrupoServicioTecSal, grupoServicios, codServicio,
                               finalidadTecnologiaSalud, causaMotivoAtencion, codDiagnosticoPrincipal, codDiagnosticoRelacionado1, codDiagnosticoRelacionado2,
                               codDiagnosticoRelacionado3, tipoDiagnosticoPrincipal, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                               vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
        SELECT
            @IDPRESTADOR,
            REPLACE(CONVERT(VARCHAR, CIT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, CIT.FECHA, 108), 5),
            NULL,
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
            LEFT(COALESCE(HCA.IDDX, APG.IDDX, ''), 4),
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
            APG.IDAFILIADO
        FROM #AUTPG_FTR APG
        INNER JOIN CIT WITH(NOLOCK) ON CIT.IDAFILIADO = APG.IDAFILIADO
            AND CIT.ANOMES = APG.ANOMES
            AND CIT.IDTERCEROCA = APG.IDTERCEROCA
            AND CIT.IDPLAN IN (SELECT IDPLAN FROM #PlanesPaquete)
            --AND CIT.IDPESPECIAL = APG.IDPESPECIAL
            AND CIT.FECHA < @FECHA_LIMITE_CIT
            AND CIT.IDAUTSES IS NULL
            AND (@RIPS_CITSOLOCUMPLIDA <> 'SI' OR COALESCE(CIT.CUMPLIDA, 0) = 1)
        INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = CIT.IDSERVICIO
        INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AC'
        INNER JOIN PRE WITH(NOLOCK) ON SER.PREFIJO = PRE.PREFIJO
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = APG.IDAFILIADO
        LEFT JOIN MPE WITH(NOLOCK) ON MPE.IDPESPECIAL = CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP'
        LEFT JOIN TGEN FINALIDADTGEN WITH(NOLOCK) ON FINALIDADTGEN.TABLA = 'GENERAL' AND FINALIDADTGEN.CAMPO = 'FINALIDAD' AND FINALIDADTGEN.CODIGO = PRE.FINALIDAD
        LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = CIT.IDMEDICO
        LEFT JOIN #HCA_CIT HCA ON HCA.CONSECUTIVOCIT = CIT.CONSECUTIVO
        OPTION (MAXDOP 1)

        /* CONSULTAS (AUT) del periodo AUTPG - contingencia cuando no est?n en CIT */
        INSERT INTO #CONSULTAS(codPrestador, fechaInicioAtencion, numAutorizacion, codConsulta, modalidadGrupoServicioTecSal, grupoServicios, codServicio,
                               finalidadTecnologiaSalud, causaMotivoAtencion, codDiagnosticoPrincipal, codDiagnosticoRelacionado1, codDiagnosticoRelacionado2,
                               codDiagnosticoRelacionado3, tipoDiagnosticoPrincipal, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                               vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
        SELECT
            @IDPRESTADOR,
            AP.fechaInicioAtencion,
            NULL,
            LEFT(SER.CODCUPS, 6),
            '01',
            CASE WHEN COALESCE(SER.RIPS_GRUPO, '') = '' THEN '01' ELSE SER.RIPS_GRUPO END,
            CASE WHEN COALESCE(SER.RIPS_CODIGO, '') = '' THEN 325 ELSE TRY_CAST(SER.RIPS_CODIGO AS INT) END,
            LEFT(CASE WHEN AP.FINALIDAD = '10' THEN COALESCE(FINALIDADTGEN.DATO1, '12')
                      WHEN AP.FINALIDAD IS NULL OR AP.FINALIDAD = '' OR COALESCE(FINALIDADTGEN.DATO1, '') = '' THEN '12'
                      ELSE COALESCE(FINALIDADTGEN.DATO1, AP.FINALIDAD, '12')
                 END, 2),
            '38',
            LEFT(COALESCE(AP.DXPPAL, AP.IDDX, ''), 4),
            LEFT(IIF(COALESCE(AP.DXRELACIONADO, '') = '', 'null', AP.DXRELACIONADO), 4),
            LEFT(IIF(COALESCE(AP.DXRELACIONADO2, '') = '', 'null', AP.DXRELACIONADO2), 4),
            LEFT(IIF(COALESCE(AP.COMPLICACION, '') = '', 'null', AP.COMPLICACION), 4),
            '01',
            COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
            COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
            0,
            @conceptoRecaudo,
            '01',
            0,
            'null',
            AP.IDAFILIADO
        FROM #AUT_PERIODO AP
        INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = AP.IDSERVICIO
        INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AC'
        INNER JOIN PRE WITH(NOLOCK) ON SER.PREFIJO = PRE.PREFIJO
        LEFT JOIN TGEN FINALIDADTGEN WITH(NOLOCK) ON FINALIDADTGEN.TABLA = 'GENERAL' AND FINALIDADTGEN.CAMPO = 'FINALIDAD' AND FINALIDADTGEN.CODIGO = PRE.FINALIDAD
        LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = IIF(COALESCE(AP.IDMEDICOSOLICITA, '') = '', @IDMEDICODEFAULT, AP.IDMEDICOSOLICITA)
        WHERE NOT EXISTS (
            SELECT 1
            FROM #CONSULTAS AC
            WHERE AC.IDAFILIADO = AP.IDAFILIADO
              AND AC.codConsulta = LEFT(SER.CODCUPS, 6)
              AND AC.fechaInicioAtencion = AP.fechaInicioAtencion
        )
        OPTION (MAXDOP 1)

        /* MEDICAMENTOS (AUT) del periodo AUTPG - l?gica CE seg?n PGP_AUT_SOLODISPENSA */
        IF @PGP_AUT_SOLODISPENSA <> 'SI'
        BEGIN
            INSERT INTO #MEDICAMENTOS(codPrestador, numAutorizacion, idMIPRES, fechaDispensAdmon, codDiagnosticoPrincipal, codDiagnosticoRelacionado,
                                      tipoMedicamento, codTecnologiaSalud, nomTecnologiaSalud, concentracionMedicamento, unidadMedida, formaFarmaceutica,
                                      unidadMinDispensa, cantidadMedicamento, diasTratamiento, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                                      vrUnitMedicamento, vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
            SELECT
                @IDPRESTADOR,
                NULL,
                COALESCE(AP.IDMIPRESS, 'null'),
                AP.fechaDispensAdmon,
                LEFT(COALESCE(AP.DXPPAL, AP.IDDX, ''), 4),
                LEFT(IIF(COALESCE(AP.DXRELACIONADO, '') = '', 'null', AP.DXRELACIONADO), 4),
                '01',
                DBO.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM, ''), NULLIF(IART.CODCUM, ''), NULLIF(AP.CODCUM_DISP, ''), SER.CODCUM), 'A-Z0-9-'),
                LEFT(dbo.FNK_LIMPIATEXTO(COALESCE(IART.DESCRIPCION, SER.DESCSERVICIO), '0-9 A-Z();:.,'), 30),
                0,
                COALESCE(IUNI.HOMOLOGO_RIPS, 0),
                COALESCE(IFFA.HOMOJSON, 'null'),
                11,
                CONVERT(INT, COALESCE(AP.CANTIDAD, 1)),
                CAST(IIF(COALESCE(AP.DIAS, 0) = 0, 1, AP.DIAS) AS SMALLINT),
                COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
                COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
                0,
                0,
                @conceptoRecaudo,
                '01',
                0,
                'null',
                AP.IDAFILIADO
            FROM #AUT_PERIODO AP
            INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = AP.IDSERVICIO
            INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AM'
            LEFT JOIN IART WITH(NOLOCK) ON SER.IDSERVICIO = IART.IDSERVICIO AND IART.PRINCIPAL = 1
            LEFT JOIN IFFA WITH(NOLOCK) ON IART.IDFORFARM = IFFA.IDFORFARM
            LEFT JOIN IUNI WITH(NOLOCK) ON IUNI.IDUNIDAD = IART.IDUNIDAD
            LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = IIF(COALESCE(AP.IDMEDICOSOLICITA, '') = '', @IDMEDICODEFAULT, AP.IDMEDICOSOLICITA)
            OPTION (MAXDOP 1)
        END
        ELSE
        BEGIN
            SELECT IDSERVICIO, IUM, CODCUM,
                RN = ROW_NUMBER() OVER (
                    PARTITION BY IDSERVICIO
                    ORDER BY CASE WHEN COALESCE(PRINCIPAL, 0) = 1 THEN 0 ELSE 1 END, IDARTICULO)
            INTO #IART_SERVICIO
            FROM IART WITH(NOLOCK)
            WHERE COALESCE(NULLIF(IUM, ''), CODCUM, '') <> ''
              AND IDSERVICIO IN (SELECT DISTINCT IDSERVICIO FROM #AUT_PERIODO)
            OPTION (MAXDOP 1)

            CREATE CLUSTERED INDEX IX_IART_SERVICIO ON #IART_SERVICIO (IDSERVICIO, RN)

            INSERT INTO #MEDICAMENTOS(codPrestador, numAutorizacion, idMIPRES, fechaDispensAdmon, codDiagnosticoPrincipal, codDiagnosticoRelacionado,
                                      tipoMedicamento, codTecnologiaSalud, nomTecnologiaSalud, concentracionMedicamento, unidadMedida, formaFarmaceutica,
                                      unidadMinDispensa, cantidadMedicamento, diasTratamiento, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                                      vrUnitMedicamento, vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
            SELECT
                @IDPRESTADOR,
                NULL,
                COALESCE(AP.IDMIPRESS, 'null'),
                AP.fechaDispensAdmon,
                LEFT(COALESCE(AP.DXPPAL, AP.IDDX, ''), 4),
                LEFT(IIF(COALESCE(AP.DXRELACIONADO, '') = '', 'null', AP.DXRELACIONADO), 4),
                '01',
                DBO.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM, ''), NULLIF(IART.CODCUM, ''), NULLIF(AP.CODCUM_DISP, ''), NULLIF(IARTS.IUM, ''), NULLIF(IARTS.CODCUM, ''), SER.CODCUM), 'A-Z0-9-'),
                LEFT(dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION, '') = '', SER.DESCSERVICIO, IART.DESCRIPCION), '0-9 A-Z();:.,'), 30),
                CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION, '0'), 3), '0-9')) = 1
                     THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION, '0'), 3), '0-9')
                     ELSE 0 END,
                COALESCE(IUNI.HOMOLOGO_RIPS, 0),
                COALESCE(IFFA.HOMOJSON, 'null'),
                11,
                CONVERT(INT, COALESCE(IZSOLDT.CANTIDADSOL, 0)),
                CAST(IIF(COALESCE(AP.DIAS, 0) = 0, 1, AP.DIAS) AS SMALLINT),
                COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
                COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
                0,
                0,
                @conceptoRecaudo,
                '01',
                0,
                'null',
                AP.IDAFILIADO
            FROM #AUT_PERIODO AP
            INNER JOIN IZSOL WITH(NOLOCK) ON AP.CNSMOV = IZSOL.CNSIZSOL AND IZSOL.CLASE = 'CE'
            INNER JOIN IZSOLD WITH(NOLOCK) ON IZSOL.CNSIZSOL = IZSOLD.CNSIZSOL AND AP.IDSERVICIO = IZSOLD.IDSERVICIO
            INNER JOIN IZSOLDT WITH(NOLOCK) ON IZSOLD.CNSIZSOLD = IZSOLDT.CNSIZSOLD AND IZSOLD.IDARTICULO = IZSOLDT.IDARTICULO
            INNER JOIN SER WITH(NOLOCK) ON IZSOLD.IDSERVICIO = SER.IDSERVICIO AND AP.IDSERVICIO = SER.IDSERVICIO
            INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AM'
            LEFT JOIN #IART_SERVICIO IARTS ON IARTS.IDSERVICIO = AP.IDSERVICIO AND IARTS.RN = 1
            LEFT JOIN IMOV WITH(NOLOCK) ON IZSOLDT.CNSMOV = IMOV.CNSMOV
            LEFT JOIN IART WITH(NOLOCK) ON IART.IDARTICULO = IZSOLDT.IDARTICULOREAL
            LEFT JOIN IFFA WITH(NOLOCK) ON IART.IDFORFARM = IFFA.IDFORFARM
            LEFT JOIN IUNI WITH(NOLOCK) ON IUNI.IDUNIDAD = IART.IDUNIDAD
            LEFT JOIN ICCN WITH(NOLOCK) ON IART.IDCONCENTRA = ICCN.IDCONCENTRA
            LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = IIF(COALESCE(AP.IDMEDICOSOLICITA, '') = '', @IDMEDICODEFAULT, AP.IDMEDICOSOLICITA)
            OPTION (MAXDOP 1)

            /* Contingencia: AUT cargadas sin dispensaci?n (IDPROVEEDOR NULL + AUTORIZADOPOR EXTERNO) */
            INSERT INTO #MEDICAMENTOS(codPrestador, numAutorizacion, idMIPRES, fechaDispensAdmon, codDiagnosticoPrincipal, codDiagnosticoRelacionado,
                                      tipoMedicamento, codTecnologiaSalud, nomTecnologiaSalud, concentracionMedicamento, unidadMedida, formaFarmaceutica,
                                      unidadMinDispensa, cantidadMedicamento, diasTratamiento, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                                      vrUnitMedicamento, vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
            SELECT
                @IDPRESTADOR,
                NULL,
                COALESCE(AP.IDMIPRESS, 'null'),
                AP.fechaDispensAdmon,
                LEFT(COALESCE(AP.DXPPAL, AP.IDDX, ''), 4),
                LEFT(IIF(COALESCE(AP.DXRELACIONADO, '') = '', 'null', AP.DXRELACIONADO), 4),
                '01',
                DBO.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM, ''), NULLIF(IART.CODCUM, ''), NULLIF(AP.CODCUM_DISP, ''), SER.CODCUM), 'A-Z0-9-'),
                LEFT(dbo.FNK_LIMPIATEXTO(COALESCE(IART.DESCRIPCION, SER.DESCSERVICIO), '0-9 A-Z();:.,'), 30),
                0,
                COALESCE(IUNI.HOMOLOGO_RIPS, 0),
                COALESCE(IFFA.HOMOJSON, 'null'),
                11,
                CONVERT(INT, COALESCE(AP.CANTIDAD, 1)),
                CAST(IIF(COALESCE(AP.DIAS, 0) = 0, 1, AP.DIAS) AS SMALLINT),
                COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
                COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
                0,
                0,
                @conceptoRecaudo,
                '01',
                0,
                'null',
                AP.IDAFILIADO
            FROM #AUT_PERIODO AP
            INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = AP.IDSERVICIO
            INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AM'
            LEFT JOIN IART WITH(NOLOCK) ON SER.IDSERVICIO = IART.IDSERVICIO AND IART.PRINCIPAL = 1
            LEFT JOIN IFFA WITH(NOLOCK) ON IART.IDFORFARM = IFFA.IDFORFARM
            LEFT JOIN IUNI WITH(NOLOCK) ON IUNI.IDUNIDAD = IART.IDUNIDAD
            LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = IIF(COALESCE(AP.IDMEDICOSOLICITA, '') = '', @IDMEDICODEFAULT, AP.IDMEDICOSOLICITA)
            WHERE AP.IDPROVEEDOR IS NULL
              AND AP.PROCEDENCIA = 'EXTERNO'
              AND NOT EXISTS (
                SELECT 1
                FROM #MEDICAMENTOS AM
                WHERE AM.IDAFILIADO = AP.IDAFILIADO
                  AND AM.codTecnologiaSalud = DBO.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM, ''), NULLIF(IART.CODCUM, ''), NULLIF(AP.CODCUM_DISP, ''), SER.CODCUM), 'A-Z0-9-')
                  AND AM.fechaDispensAdmon = AP.fechaDispensAdmon
            )
            OPTION (MAXDOP 1)

            DROP TABLE IF EXISTS #IART_SERVICIO
        END

        /* PROCEDIMIENTOS (CIT) del IDPESPECIAL del AUTPG - ARCHIVO AP */
        INSERT INTO #PROCEDIMIENTOS(codPrestador, fechaInicioAtencion, idMIPRES, numAutorizacion, codProcedimiento, vialngresoServicioSalud,
                                    modalidadGrupoServicioTecSal, grupoServicios, codServicio, finalidadTecnologiaSalud,
                                    tipoDocumentoIdentificacion, numDocumentoIdentificacion, codDiagnosticoPrincipal, codDiagnosticoRelacionado,
                                    codComplicacion, vrServicio, conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador, IDAFILIADO)
        SELECT
            @IDPRESTADOR,
            REPLACE(CONVERT(VARCHAR, CIT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, CIT.FECHA, 108), 5),
            'null',
            NULL,
            LEFT(SER.CODCUPS, 6),
            '02',
            '01',
            CASE WHEN COALESCE(SER.RIPS_GRUPO, '') = '' THEN '02' ELSE SER.RIPS_GRUPO END,
            CASE WHEN COALESCE(SER.RIPS_CODIGO, '') = '' THEN 325 ELSE TRY_CAST(SER.RIPS_CODIGO AS INT) END,
            LEFT(COALESCE(FINALIDADTGEN.DATO1, '16'), 2),
            COALESCE(MED.TIPO_ID, @TIPO_ID_MEDICODEFAULT, 'CC'),
            COALESCE(MED.IDMEDICO, @IDMEDICODEFAULT),
            LEFT(COALESCE(HCA.IDDX, CIT.IDDX, APG.IDDX, ''), 4),
            'null',
            'null',
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
            APG.IDAFILIADO
        FROM #AUTPG_FTR APG
        INNER JOIN CIT WITH(NOLOCK) ON CIT.IDAFILIADO = APG.IDAFILIADO
            AND CIT.ANOMES = APG.ANOMES
            AND CIT.IDTERCEROCA = APG.IDTERCEROCA
            AND CIT.IDPLAN IN (SELECT IDPLAN FROM #PlanesPaquete)
            --AND CIT.IDPESPECIAL = APG.IDPESPECIAL
            AND CIT.FECHA < @FECHA_LIMITE_CIT
            AND CIT.IDAUTSES IS NULL
            AND (@RIPS_CITSOLOCUMPLIDA <> 'SI' OR COALESCE(CIT.CUMPLIDA, 0) = 1)
        INNER JOIN SER WITH(NOLOCK) ON SER.IDSERVICIO = CIT.IDSERVICIO
        INNER JOIN RIPS_CP WITH(NOLOCK) ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS AND RIPS_CP.ARCHIVO = 'AP'
        INNER JOIN PRE WITH(NOLOCK) ON SER.PREFIJO = PRE.PREFIJO
        INNER JOIN AFI WITH(NOLOCK) ON AFI.IDAFILIADO = APG.IDAFILIADO
        LEFT JOIN TGEN FINALIDADTGEN WITH(NOLOCK) ON FINALIDADTGEN.TABLA = 'GENERAL' AND FINALIDADTGEN.CAMPO = 'FINALIDAD' AND FINALIDADTGEN.CODIGO = PRE.FINALIDAD
        LEFT JOIN MED WITH(NOLOCK) ON MED.IDMEDICO = CIT.IDMEDICO
        LEFT JOIN #HCA_CIT HCA ON HCA.CONSECUTIVOCIT = CIT.CONSECUTIVO
        OPTION (MAXDOP 1)

        UPDATE #CONSULTAS SET codDiagnosticoPrincipal = 'Z000'
        WHERE LEN(COALESCE(codDiagnosticoPrincipal, '')) < 4

        UPDATE #MEDICAMENTOS SET codDiagnosticoPrincipal = 'Z000'
        WHERE LEN(COALESCE(codDiagnosticoPrincipal, '')) < 4

        UPDATE #MEDICAMENTOS SET codDiagnosticoRelacionado = 'null'
        WHERE LEN(COALESCE(codDiagnosticoRelacionado, '')) < 4
           OR codDiagnosticoRelacionado = codDiagnosticoPrincipal

        UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal = 'Z000'
        WHERE LEN(COALESCE(codDiagnosticoPrincipal, '')) < 4

        UPDATE #PROCEDIMIENTOS SET codDiagnosticoRelacionado = 'null'
        WHERE LEN(COALESCE(codDiagnosticoRelacionado, '')) < 4
           OR codDiagnosticoRelacionado = codDiagnosticoPrincipal

        UPDATE #PROCEDIMIENTOS SET codComplicacion = 'null'
        WHERE LEN(COALESCE(codComplicacion, '')) < 4
           OR codComplicacion = codDiagnosticoPrincipal

        UPDATE #CONSULTAS SET codDiagnosticoRelacionado1 = 'null'
        WHERE codDiagnosticoRelacionado1 = codDiagnosticoPrincipal
          AND codDiagnosticoRelacionado1 <> 'null'

        UPDATE #CONSULTAS SET codDiagnosticoRelacionado2 = 'null'
        WHERE codDiagnosticoRelacionado2 = codDiagnosticoPrincipal
          AND codDiagnosticoRelacionado2 <> 'null'

        UPDATE #CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
        WHERE codDiagnosticoRelacionado3 = codDiagnosticoPrincipal
          AND codDiagnosticoRelacionado3 <> 'null'

        DROP TABLE IF EXISTS #PlanesPaquete
        DROP TABLE IF EXISTS #AUT_PERIODO
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

    UPDATE #MEDICAMENTOS SET usuarioId = US.usuarioId
    FROM #MEDICAMENTOS AM
    INNER JOIN #USUARIOS US ON AM.IDAFILIADO = US.IDAFILIADO

    UPDATE #PROCEDIMIENTOS SET usuarioId = US.usuarioId
    FROM #PROCEDIMIENTOS AP
    INNER JOIN #USUARIOS US ON AP.IDAFILIADO = US.IDAFILIADO

    /* xconsecutivo por tipo de servicio y afiliado */
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

    ;WITH CTE AS (
        SELECT ID, IDAFILIADO,
            xconsecutivo = ROW_NUMBER() OVER (PARTITION BY IDAFILIADO ORDER BY ID ASC)
        FROM #MEDICAMENTOS
    )
    UPDATE AM SET AM.xconsecutivo = CTE.xconsecutivo
    FROM #MEDICAMENTOS AM
    INNER JOIN CTE ON AM.ID = CTE.ID

    ;WITH CTE AS (
        SELECT ID, IDAFILIADO,
            xconsecutivo = ROW_NUMBER() OVER (PARTITION BY IDAFILIADO ORDER BY ID ASC)
        FROM #PROCEDIMIENTOS
    )
    UPDATE AP SET AP.xconsecutivo = CTE.xconsecutivo
    FROM #PROCEDIMIENTOS AP
    INNER JOIN CTE ON AP.ID = CTE.ID

    /* RVC014: FNK no recorta VARCHAR(16) sin segundos (CONVERT 120). Se rellena :00 y se recorta por DATE. */
    IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL
    BEGIN
        PRINT N'RIPS RVC014: ajuste fechas servicio al periodo '
            + CONVERT(VARCHAR(10), CAST(@FECHAINICAP AS DATE), 23)
            + N' - '
            + CONVERT(VARCHAR(10), CAST(@FECHAFINCAP AS DATE), 23);

        UPDATE #CONSULTAS
        SET fechaInicioAtencion = LEFT(DBO.FNK_RIPS_FECHA_EN_PERIODO(
            CASE WHEN LEN(LTRIM(RTRIM(fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(fechaInicioAtencion)) + ':00' ELSE fechaInicioAtencion END,
            @FECHAINICAP, @FECHAFINCAP), 16)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #PROCEDIMIENTOS
        SET fechaInicioAtencion = LEFT(DBO.FNK_RIPS_FECHA_EN_PERIODO(
            CASE WHEN LEN(LTRIM(RTRIM(fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(fechaInicioAtencion)) + ':00' ELSE fechaInicioAtencion END,
            @FECHAINICAP, @FECHAFINCAP), 16)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #MEDICAMENTOS
        SET fechaDispensAdmon = LEFT(DBO.FNK_RIPS_FECHA_EN_PERIODO(
            CASE WHEN LEN(LTRIM(RTRIM(fechaDispensAdmon))) = 16 THEN LTRIM(RTRIM(fechaDispensAdmon)) + ':00' ELSE fechaDispensAdmon END,
            @FECHAINICAP, @FECHAFINCAP), 16)
        WHERE COALESCE(fechaDispensAdmon, '') NOT IN ('', 'null');

        UPDATE #OTROSSER
        SET fechaSuministroTecnologia = LEFT(DBO.FNK_RIPS_FECHA_EN_PERIODO(
            CASE WHEN LEN(LTRIM(RTRIM(fechaSuministroTecnologia))) = 16 THEN LTRIM(RTRIM(fechaSuministroTecnologia)) + ':00' ELSE fechaSuministroTecnologia END,
            @FECHAINICAP, @FECHAFINCAP), 16)
        WHERE COALESCE(fechaSuministroTecnologia, '') NOT IN ('', 'null');

        UPDATE T
        SET fechaInicioAtencion = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAFINCAP), MONTH(@FECHAFINCAP), DAY(@FECHAFINCAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #CONSULTAS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(T.fechaInicioAtencion)) + ':00' ELSE T.fechaInicioAtencion END, 120),
                TRY_CONVERT(DATETIME, T.fechaInicioAtencion))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) > CAST(@FECHAFINCAP AS DATE);

        UPDATE T
        SET fechaInicioAtencion = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAINICAP), MONTH(@FECHAINICAP), DAY(@FECHAINICAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #CONSULTAS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(T.fechaInicioAtencion)) + ':00' ELSE T.fechaInicioAtencion END, 120),
                TRY_CONVERT(DATETIME, T.fechaInicioAtencion))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) < CAST(@FECHAINICAP AS DATE);

        UPDATE T
        SET fechaInicioAtencion = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAFINCAP), MONTH(@FECHAFINCAP), DAY(@FECHAFINCAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #PROCEDIMIENTOS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(T.fechaInicioAtencion)) + ':00' ELSE T.fechaInicioAtencion END, 120),
                TRY_CONVERT(DATETIME, T.fechaInicioAtencion))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) > CAST(@FECHAFINCAP AS DATE);

        UPDATE T
        SET fechaInicioAtencion = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAINICAP), MONTH(@FECHAINICAP), DAY(@FECHAINICAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #PROCEDIMIENTOS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaInicioAtencion))) = 16 THEN LTRIM(RTRIM(T.fechaInicioAtencion)) + ':00' ELSE T.fechaInicioAtencion END, 120),
                TRY_CONVERT(DATETIME, T.fechaInicioAtencion))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) < CAST(@FECHAINICAP AS DATE);

        UPDATE T
        SET fechaDispensAdmon = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAFINCAP), MONTH(@FECHAFINCAP), DAY(@FECHAFINCAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #MEDICAMENTOS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaDispensAdmon))) = 16 THEN LTRIM(RTRIM(T.fechaDispensAdmon)) + ':00' ELSE T.fechaDispensAdmon END, 120),
                TRY_CONVERT(DATETIME, T.fechaDispensAdmon))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) > CAST(@FECHAFINCAP AS DATE);

        UPDATE T
        SET fechaDispensAdmon = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAINICAP), MONTH(@FECHAINICAP), DAY(@FECHAINICAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #MEDICAMENTOS T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaDispensAdmon))) = 16 THEN LTRIM(RTRIM(T.fechaDispensAdmon)) + ':00' ELSE T.fechaDispensAdmon END, 120),
                TRY_CONVERT(DATETIME, T.fechaDispensAdmon))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) < CAST(@FECHAINICAP AS DATE);

        UPDATE T
        SET fechaSuministroTecnologia = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAFINCAP), MONTH(@FECHAFINCAP), DAY(@FECHAFINCAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #OTROSSER T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaSuministroTecnologia))) = 16 THEN LTRIM(RTRIM(T.fechaSuministroTecnologia)) + ':00' ELSE T.fechaSuministroTecnologia END, 120),
                TRY_CONVERT(DATETIME, T.fechaSuministroTecnologia))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) > CAST(@FECHAFINCAP AS DATE);

        UPDATE T
        SET fechaSuministroTecnologia = CONVERT(VARCHAR(16),
            DATETIMEFROMPARTS(YEAR(@FECHAINICAP), MONTH(@FECHAINICAP), DAY(@FECHAINICAP), DATEPART(HOUR, X.F), DATEPART(MINUTE, X.F), 0, 0), 120)
        FROM #OTROSSER T
        CROSS APPLY (
            SELECT F = COALESCE(
                TRY_CONVERT(DATETIME, CASE WHEN LEN(LTRIM(RTRIM(T.fechaSuministroTecnologia))) = 16 THEN LTRIM(RTRIM(T.fechaSuministroTecnologia)) + ':00' ELSE T.fechaSuministroTecnologia END, 120),
                TRY_CONVERT(DATETIME, T.fechaSuministroTecnologia))
        ) X
        WHERE X.F IS NOT NULL AND CAST(X.F AS DATE) < CAST(@FECHAINICAP AS DATE);
    END

    IF @PAQUETIZADO = 1
    BEGIN
        SELECT @json = (
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
                                                numAutorizacion = CAST(NULL AS VARCHAR(30)),
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
                                        medicamentos = JSON_QUERY((
                                            SELECT
                                                am.codPrestador,
                                                numAutorizacion = CAST(NULL AS VARCHAR(30)),
                                                idMIPRES = IIF(COALESCE(am.idMIPRES, '') = '', 'null', am.idMIPRES),
                                                am.fechaDispensAdmon,
                                                codDiagnosticoPrincipal = IIF(LEN(COALESCE(am.codDiagnosticoPrincipal, '')) <> 4, 'null', am.codDiagnosticoPrincipal),
                                                codDiagnosticoRelacionado = IIF(LEN(COALESCE(am.codDiagnosticoRelacionado, '')) <> 4, 'null', am.codDiagnosticoRelacionado),
                                                codDiagnosticoPrincipalCIE11 = 'null',
                                                nomCodDiagnosticoPrincipalCIE11 = 'null',
                                                codDiagnosticoRelacionadoCIE11 = 'null',
                                                nomCodDiagnosticoRelacionadoCIE11 = 'null',
                                                vrDispensacion = CAST(0 AS DECIMAL(14,2)),
                                                codigoVIDA = 'null',
                                                am.tipoMedicamento,
                                                codTecnologiaSalud = DBO.FNK_LIMPIATEXTO(am.codTecnologiaSalud, '0-9A-Z_-'),
                                                am.nomTecnologiaSalud,
                                                am.concentracionMedicamento,
                                                am.unidadMedida,
                                                am.formaFarmaceutica,
                                                am.unidadMinDispensa,
                                                am.cantidadMedicamento,
                                                am.diasTratamiento,
                                                am.tipoDocumentoIdentificacion,
                                                am.numDocumentoIdentificacion,
                                                am.vrUnitMedicamento,
                                                am.vrServicio,
                                                am.conceptoRecaudo,
                                                am.valorPagoModerador,
                                                numFEVPagoModerador = IIF(am.numFEVPagoModerador IS NULL, 'null', am.numFEVPagoModerador),
                                                consecutivo = am.xconsecutivo
                                            FROM #MEDICAMENTOS am
                                            WHERE am.usuarioId = u.usuarioId
                                            ORDER BY am.xconsecutivo ASC
                                            FOR JSON PATH, INCLUDE_NULL_VALUES
                                        )),
                                        procedimientos = JSON_QUERY((
                                            SELECT
                                                ap.codPrestador,
                                                ap.fechaInicioAtencion,
                                                idMIPRES = IIF(COALESCE(ap.idMIPRES, '') = '', 'null', ap.idMIPRES),
                                                numAutorizacion = CAST(NULL AS VARCHAR(30)),
                                                ap.codProcedimiento,
                                                viaIngresoServicioSalud = ap.vialngresoServicioSalud,
                                                ap.modalidadGrupoServicioTecSal,
                                                ap.grupoServicios,
                                                ap.codServicio,
                                                ap.finalidadTecnologiaSalud,
                                                ap.tipoDocumentoIdentificacion,
                                                ap.numDocumentoIdentificacion,
                                                codDiagnosticoPrincipal = IIF(LEN(COALESCE(ap.codDiagnosticoPrincipal, '')) <> 4, 'null', ap.codDiagnosticoPrincipal),
                                                codDiagnosticoRelacionado = IIF(LEN(COALESCE(ap.codDiagnosticoRelacionado, '')) <> 4, 'null', ap.codDiagnosticoRelacionado),
                                                codComplicacion = IIF(LEN(COALESCE(ap.codComplicacion, '')) <> 4, 'null', ap.codComplicacion),
                                                codDiagnosticoPrincipalCIE11 = 'null',
                                                nomCodDiagnosticoPrincipalCIE11 = 'null',
                                                codDiagnosticoRelacionadoCIE11 = 'null',
                                                nomCodDiagnosticoRelacionadoCIE11 = 'null',
                                                codComplicacionCIE11 = 'null',
                                                nomCodComplicacionCIE11 = 'null',
                                                codigoVIDA = 'null',
                                                ap.vrServicio,
                                                ap.conceptoRecaudo,
                                                ap.valorPagoModerador,
                                                numFEVPagoModerador = IIF(ap.numFEVPagoModerador IS NULL, 'null', ap.numFEVPagoModerador),
                                                consecutivo = ap.xconsecutivo
                                            FROM #PROCEDIMIENTOS ap
                                            WHERE ap.usuarioId = u.usuarioId
                                            ORDER BY ap.xconsecutivo ASC
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
        OPTION (MAXDOP 1)
    END
    ELSE
    BEGIN
        SELECT @json = (
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
        OPTION (MAXDOP 1)
    END

    SELECT @JSON = REPLACE(@JSON, '\"', '"')
    SELECT @JSON = REPLACE(@JSON, '\\"', '"')
    SELECT @JSON = REPLACE(@JSON, '"{', '{')
    SELECT @JSON = REPLACE(@JSON, '}"', '}')
    SELECT @JSON = REPLACE(@JSON, '"null"', 'null')
    SELECT @PLANO = @json

    IF COALESCE(@XML_BASE64, '') <> ''
    BEGIN
        SELECT @PLANO = REPLACE(@PLANO, '@XMLFEVFILE', @XML_BASE64)
    END
    ELSE
    BEGIN
        SELECT @base64 = CAST('' AS XML).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
        FROM (
            SELECT [binaryValue] = CAST(dbo.FNK_AttachedDocument(@CNSFCT, 'FV') AS VARBINARY(MAX))
        ) AS conv
        OPTION (MAXDOP 1)

        SELECT @PLANO = REPLACE(@PLANO, '@XMLFEVFILE', @base64)
    END

    IF COALESCE(@URL_PATH, '') <> ''
    BEGIN
        SELECT @N_FACTURA = @N_FACTURA + '.json'
        EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
        SELECT @PLANO = @URL_PATH + IIF(RIGHT(@URL_PATH, 1) = '\', '', '\') + @N_FACTURA
    END

    IF OBJECT_ID('tempdb..#USUARIOS') IS NOT NULL
        DROP TABLE #USUARIOS
    IF OBJECT_ID('tempdb..#CONSULTAS') IS NOT NULL
        DROP TABLE #CONSULTAS
    IF OBJECT_ID('tempdb..#MEDICAMENTOS') IS NOT NULL
        DROP TABLE #MEDICAMENTOS
    IF OBJECT_ID('tempdb..#PROCEDIMIENTOS') IS NOT NULL
        DROP TABLE #PROCEDIMIENTOS
    IF OBJECT_ID('tempdb..#OTROSSER') IS NOT NULL
        DROP TABLE #OTROSSER
    IF OBJECT_ID('tempdb..#AUTPG_FTR') IS NOT NULL
        DROP TABLE #AUTPG_FTR
    IF OBJECT_ID('tempdb..#AUT_PERIODO') IS NOT NULL
        DROP TABLE #AUT_PERIODO
    IF OBJECT_ID('tempdb..#HCA_CIT') IS NOT NULL
        DROP TABLE #HCA_CIT
END

