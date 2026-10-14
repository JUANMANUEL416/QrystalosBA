CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_FTR_CAPI
@N_FACTURA  VARCHAR(20),
@URL_PATH VARCHAR(MAX)=NULL,
@PLANO NVARCHAR(MAX) OUTPUT,
@REPORTE_VALIDACION NVARCHAR(MAX) = NULL OUTPUT
AS 
BEGIN
    SET NOCOUNT ON;

    -- Declaraciones de variables escalares
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
    DECLARE @VALORCOPAGOACU DECIMAL(14,2)
    DECLARE @IDSEDE VARCHAR(20)
    DECLARE @CODHABILITA VARCHAR(100)
    DECLARE @CNSCONSULTA INT
    DECLARE @CANTORI INT
    DECLARE @BANDERA INT
    DECLARE @BASE64 NVARCHAR(MAX)
    DECLARE @valorPagoModerador INT
    DECLARE @N_FACTURAANT VARCHAR(20)
    DECLARE @IDTERCERO VARCHAR(20)
    DECLARE @IDPLAN VARCHAR(20)
    DECLARE @CPROPIO BIT = 0
    DECLARE @IDSEDEFAC VARCHAR(6)

    -- === CREACI�N DE TABLAS TEMPORALES CON COLLATE database_default ===

    CREATE TABLE #USUARIOS (
        usuarioId INT IDENTITY(1,1) PRIMARY KEY,
        tipoDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        tipoUsuario VARCHAR(2) COLLATE database_default,
        fechaNacimiento VARCHAR(10) COLLATE database_default,
        codSexo VARCHAR(1) COLLATE database_default,
        codPaisResidencia VARCHAR(5) COLLATE database_default,
        codPaisOrigen VARCHAR(5) COLLATE database_default,
        codMunicipioResidencia VARCHAR(5) COLLATE database_default,
        codZonaTerritorialResidencia VARCHAR(2) COLLATE database_default,
        incapacidad VARCHAR(20) COLLATE database_default
    );

    CREATE TABLE #CONSULTAS (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codConsulta VARCHAR(10) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        causaMotivoAtencion VARCHAR(2) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado1 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado2 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado3 VARCHAR(20) COLLATE database_default,
        tipoDiagnosticoPrincipal VARCHAR(3) COLLATE database_default,
        vrServicio int,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_CONSULTAS_IDAFILIADO ON #CONSULTAS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_CONSULTAS_USUARIOID ON #CONSULTAS (usuarioId);

    CREATE TABLE #CONSULTAS1 (
        IDCONSULTA INT IDENTITY PRIMARY KEY,
        codPrestador VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codConsulta VARCHAR(10) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        causaMotivoAtencion VARCHAR(2) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado1 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado2 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado3 VARCHAR(20) COLLATE database_default,
        tipoDiagnosticoPrincipal VARCHAR(3) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        vrServicio int,
        Cantidad int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        valorPagoModerador INT,
        restoPagoModerador DECIMAL(14,2),
        usuarioId  INT,
        xconsecutivo int
    );

    CREATE TABLE #CONSULTAS2 (
        codPrestador VARCHAR(20) COLLATE database_default,
        consecutivo VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codConsulta VARCHAR(10) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        causaMotivoAtencion VARCHAR(2) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado1 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado2 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado3 VARCHAR(20) COLLATE database_default,
        tipoDiagnosticoPrincipal VARCHAR(3) COLLATE database_default,
        vrServicio int,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        ID int,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_CONSULTAS2_USUARIOID ON #CONSULTAS2 (usuarioId);

    CREATE TABLE #MEDICAMENTOS (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        fechaDispensAdmon VARCHAR(16) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE database_default,
        tipoMedicamento VARCHAR(4) COLLATE database_default,
        codTecnologiaSalud VARCHAR(20) COLLATE database_default,
        nomTecnologiaSalud VARCHAR(30) COLLATE database_default,
        concentracionMedicamento VARCHAR(4) COLLATE database_default,
        unidadMedida int,
        formaFarmaceutica VARCHAR(8) COLLATE database_default,
        unidadMinDispensa VARCHAR(4) COLLATE database_default,
        cantidadMedicamento VARCHAR(20) COLLATE database_default,
        diasTratamiento VARCHAR(5) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        vrUnitMedicamento VARCHAR(15) COLLATE database_default,
        vrServicio VARCHAR(15) COLLATE database_default,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_MEDICAMENTOS_IDAFILIADO ON #MEDICAMENTOS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_MEDICAMENTOS_USUARIOID ON #MEDICAMENTOS (usuarioId);

    CREATE TABLE #MEDICAMENTOS2 (
        codPrestador VARCHAR(20) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        fechaDispensAdmon VARCHAR(16) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE database_default,
        tipoMedicamento VARCHAR(4) COLLATE database_default,
        codTecnologiaSalud VARCHAR(20) COLLATE database_default,
        nomTecnologiaSalud VARCHAR(30) COLLATE database_default,
        concentracionMedicamento INT,
        unidadMedida int,
        formaFarmaceutica VARCHAR(8) COLLATE database_default,
        unidadMinDispensa INT,
        cantidadMedicamento INT,
        diasTratamiento SMALLINT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        vrUnitMedicamento DECIMAL(14,2),
        vrServicio DECIMAL(14,2),
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador DECIMAL(14,2),
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        ID INT,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_MEDICAMENTOS2_USUARIOID ON #MEDICAMENTOS2 (usuarioId);

    CREATE TABLE #PROCEDIMIENTOS (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codProcedimiento VARCHAR(6) COLLATE database_default,
        viaIngresoServicioSalud VARCHAR(2) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE database_default,
        codComplicacion VARCHAR(20) COLLATE database_default,
        vrServicio int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_PROCEDIMIENTOS_IDAFILIADO ON #PROCEDIMIENTOS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_PROCEDIMIENTOS_USUARIOID ON #PROCEDIMIENTOS (usuarioId);

    CREATE TABLE #PROCEDIMIENTOS1 (
        IDPROCE INT IDENTITY PRIMARY KEY,
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codProcedimiento VARCHAR(6) COLLATE database_default,
        viaIngresoServicioSalud VARCHAR(2) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio VARCHAR(4) COLLATE database_default,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE database_default,
        codComplicacion VARCHAR(20) COLLATE database_default,
        vrServicio int,
        cantidad int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador DECIMAL(14,2),
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        restoPagoModerador VARCHAR(10) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );

    CREATE TABLE #PROCEDIMIENTOS2 (
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        codProcedimiento VARCHAR(6) COLLATE database_default,
        viaIngresoServicioSalud VARCHAR(2) COLLATE database_default,
        modalidadGrupoServicioTecSal VARCHAR(2) COLLATE database_default,
        grupoServicios VARCHAR(2) COLLATE database_default,
        codServicio INT,
        finalidadTecnologiaSalud VARCHAR(2) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionado VARCHAR(20) COLLATE database_default,
        codComplicacion VARCHAR(20) COLLATE database_default,
        vrServicio int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        ID int,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_PROCEDIMIENTOS2_USUARIOID ON #PROCEDIMIENTOS2 (usuarioId);

    CREATE TABLE #URGENCIAS (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        causaMotivoAtencion VARCHAR(2) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoPrincipalE VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE1 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE2 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE3 VARCHAR(20) COLLATE database_default,
        condicionDestinoUsuarioEgreso VARCHAR(2) COLLATE database_default,
        codDiagnosticoCausaMuerte VARCHAR(20) COLLATE database_default,
        fechaEgreso VARCHAR(16) COLLATE database_default,
        viaIngresoServicioSalud VARCHAR(2) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_URGENCIAS_IDAFILIADO ON #URGENCIAS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_URGENCIAS_USUARIOID ON #URGENCIAS (usuarioId);

    CREATE TABLE #HOSPITALIZACION (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        viaIngresoServicioSalud VARCHAR(2) COLLATE database_default,
        fechaInicioAtencion VARCHAR(16) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        causaMotivoAtencion VARCHAR(2) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        codDiagnosticoPrincipalE VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE1 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE2 VARCHAR(20) COLLATE database_default,
        codDiagnosticoRelacionadoE3 VARCHAR(20) COLLATE database_default,
        codComplicacion VARCHAR(20) COLLATE database_default,
        condicionDestinoUsuarioEgreso VARCHAR(2) COLLATE database_default,
        codDiagnosticoCausaMuerte VARCHAR(20) COLLATE database_default,
        fechaEgreso VARCHAR(16) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );

    CREATE TABLE #RECIEN (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default DEFAULT 'CN',
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        fechaNacimiento VARCHAR(16) COLLATE database_default,
        edadGestacional VARCHAR(2) COLLATE database_default,
        numConsultasCPrenatal VARCHAR(2) COLLATE database_default,
        codSexoBiologico VARCHAR(2) COLLATE database_default,
        peso VARCHAR(4) COLLATE database_default,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        condicionDestinoUsuarioEgreso VARCHAR(2) COLLATE database_default,
        codDiagnosticoCausaMuerte VARCHAR(20) COLLATE database_default,
        fechaEgreso VARCHAR(16) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );

    CREATE TABLE #OTROSSER (
        id int IDENTITY(1,1),
        codPrestador VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        fechaSuministroTecnologia VARCHAR(16) COLLATE database_default,
        tipoOS VARCHAR(2) COLLATE database_default,
        codTecnologiaSalud VARCHAR(20) COLLATE database_default,
        nomTecnologiaSalud VARCHAR(60) COLLATE database_default,
        cantidadOS INT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        vrUnitOS INT,
        vrServicio int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        xconsecutivo int
    );

    CREATE TABLE #OTROSSER2 (
        codPrestador VARCHAR(20) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        numAutorizacion VARCHAR(30) COLLATE database_default,
        idMIPRES VARCHAR(15) COLLATE database_default,
        fechaSuministroTecnologia VARCHAR(16) COLLATE database_default,
        tipoOS VARCHAR(2) COLLATE database_default,
        codTecnologiaSalud VARCHAR(20) COLLATE database_default,
        nomTecnologiaSalud VARCHAR(60) COLLATE database_default,
        cantidadOS INT,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default,
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        vrUnitOS INT,
        vrServicio int,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId  INT,
        ID int,
        xconsecutivo int
    );

    CREATE TABLE #DX (
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        NOADMISION VARCHAR(20) COLLATE database_default,
        CONSECUTIVOCIT VARCHAR(20) COLLATE database_default,
        TIPODX VARCHAR(20) COLLATE database_default,
        IDDX VARCHAR(4) COLLATE database_default,
        NIDDX VARCHAR(255) COLLATE database_default,
        DX1 VARCHAR(4) COLLATE database_default,
        NDX1 VARCHAR(255) COLLATE database_default,
        DX2 VARCHAR(4) COLLATE database_default,
        NDX2 VARCHAR(255) COLLATE database_default,
        DX3 VARCHAR(4) COLLATE database_default,
        NDX3 VARCHAR(255) COLLATE database_default
    );

    DECLARE @codProcedimiento VARCHAR(6),
            @vialngresoServicioSalud VARCHAR(2),
            @codComplicacion VARCHAR(20),
            @fechaSuministroTecnologia VARCHAR(16),
            @tipoOS VARCHAR(2),
            @cantidadOS INT,
            @vrUnitOS INT,
            @primerGrupo BIT = 1,
            @numDocumentoIdObligado VARCHAR(20),
            @CNSFCT VARCHAR(20),
            @TIPOCAP SMALLINT,
            @FECHAINICAP DATETIME,
            @FECHAFINCAP DATETIME;

    DECLARE @json NVARCHAR(MAX)
    DECLARE @numNota VARCHAR(MAX)
    SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
    PRINT 'SPK_RIPS_JSON_FTR_CAPI ='+@N_FACTURA
    SELECT @CNSFCT=CNSFCT,@TIPOCAP=COALESCE(TIPOCAP,0) ,@IDTERCERO=IDTERCERO , @IDPLAN=IDPLAN,@CPROPIO=COALESCE(COPAPROPIO,0),
    @VALORCOPAGO=CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0) ELSE COALESCE(VALORCOPAGO,0) END,
    @FECHAINICAP=FECHACAP_INI,@FECHAFINCAP=COALESCE(FECHACAP_FIN, FECHA_CAPRIPS),
    @IDSEDEFAC=FTR.IDSEDE
    FROM FTR WHERE N_FACTURA=@N_FACTURA
    IF @TIPOCAP=0
    BEGIN
        PRINT 'No se ha Definido el Tipo de Capita, Verifique e intente de Nuevo'
        RAISERROR('No se ha Definido el Tipo de Capita, Verifique e intente de Nuevo', 16, 1)
        GOTO FIN
    END
    IF @TIPOCAP=4
    BEGIN
        PRINT 'Este tipo de Capita no es permitido, me Regreso'
        RAISERROR('Este tipo de Capita no es permitido, Verifique e intente de Nuevo', 16, 1)
        GOTO FIN
    END
    IF @TIPOCAP<> 0
    BEGIN
        PRINT '@TIPOCAP='+CAST(COALESCE(@TIPOCAP,0) AS VARCHAR(2))
        IF NOT EXISTS(SELECT 1 FROM FTRDC WHERE CNSFTR=@CNSFCT  ) AND COALESCE(@TIPOCAP,0)<>1
        BEGIN
            PRINT 'FACTURA CAPITADA SIN RELACION DE SERVICIOS, ME REGRESO'
            RAISERROR('FACTURA CAPITADA SIN RELACION DE SERVICIOS, POR FAVOR VERIFIQUE.', 16, 1)
            GOTO FIN
        END
        IF @TIPOCAP=2
        BEGIN
            SELECT TOP 1 @N_FACTURAANT=N_FACTURA FROM FTR 
            WHERE IDTERCERO=@IDTERCERO 
            AND IDPLAN=@IDPLAN 
            AND CAPITADA=1  
            AND COALESCE(FACTE,0)=2
            AND COALESCE(TIPOANULACION,'')<>'NC'
            AND FTR.ESTADO='P'
            AND PROCEDENCIA='FINANCIERO'
            AND N_FACTURA<>@N_FACTURA
            AND @FECHAINICAP IS NOT NULL
            AND @FECHAFINCAP IS NOT NULL
            AND FECHACAP_INI >= DATEADD(MONTH, -1, @FECHAINICAP)
            AND FECHACAP_FIN <= EOMONTH(DATEADD(MONTH, -1, CAST(@FECHAFINCAP AS DATE)))
            AND IDSEDE=CASE WHEN DBO.FNK_VALORVARIABLE('FACTSEDE')='SI' THEN '' ELSE FTR.IDSEDE END
            ORDER BY F_FACTURA DESC
        END
        IF EXISTS(SELECT 1 FROM FTRDC WHERE CNSFTR=@CNSFCT AND IDAFILIADO IS NULL)
        BEGIN 
            UPDATE FTRDC SET IDAFILIADO=CIT.IDAFILIADO
            FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO AND FTRDC.PROCEDENCIA='CIT'
            WHERE FTRDC.IDAFILIADO IS NULL
            AND FTRDC.CNSFTR=@CNSFCT
            UPDATE FTRDC SET IDAFILIADO=AUT.IDAFILIADO
            FROM FTRDC INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT AND FTRDC.PROCEDENCIA='AUT'
            WHERE FTRDC.IDAFILIADO IS NULL
            AND FTRDC.CNSFTR=@CNSFCT
            UPDATE FTRDC SET IDAFILIADO=HADM.IDAFILIADO
            FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION AND FTRDC.PROCEDENCIA='HADM'
            WHERE FTRDC.IDAFILIADO IS NULL
            AND FTRDC.CNSFTR=@CNSFCT
        END

        SELECT  @conceptoRecaudo = '05'
        IF EXISTS(SELECT * FROM PLN WHERE IDPLAN=@IDPLAN AND TIPOSISTEMA='Contributivo')
        BEGIN
            SELECT @conceptoRecaudo = '02'
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT * FROM PLN WHERE IDPLAN=@IDPLAN AND TIPOSISTEMA='Subsidiado')
            BEGIN
                SELECT @conceptoRecaudo = '01'
            END
            ELSE
            BEGIN
                IF EXISTS(SELECT * FROM PLN WHERE IDPLAN=@IDPLAN AND TIPOSISTEMA='Prepagado')
                BEGIN
                    SET @conceptoRecaudo='03'
                END
            END
        END
        PRINT '@conceptoRecaudo='+@conceptoRecaudo
        SELECT @IDPRESTADOR=COALESCE(IDALTERNA2,'No tengo'), @numDocumentoIdObligado = NIT 
        FROM TER 
        WHERE IDTERCERO=@IDTERINSTA
        PRINT 'BUSCANDO LOS AFILIADOS'
        BEGIN 
            INSERT INTO #USUARIOS(tipoDocumentoIdentificacion,numDocumentoIdentificacion,IDAFILIADO,tipoUsuario,fechaNacimiento,codSexo,codPaisResidencia,codPaisOrigen,
                                    codMunicipioResidencia,codZonaTerritorialResidencia,incapacidad)
            SELECT DISTINCT  AFI.TIPO_DOC,AFI.DOCIDAFILIADO,AFI.IDAFILIADO,
                   CASE WHEN COALESCE(AFI.TIPOUSUARIO,'')='' THEN 
                        CASE   WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
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
                                       WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END ELSE  COALESCE(AFI.TIPOUSUARIO,'') END ,
                        FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
                        SEXO=UPPER(LEFT(AFI.SEXO,1)),'170','170', MUNICIPIO=AFI.CIUDAD,ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
                        INCAPACIDAD='NO'
            FROM FTRDC INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
            WHERE CNSFTR=@CNSFCT
        END
        PRINT 'COMIENZO CONSULTAS'
        PRINT 'CONSULTAS'
        BEGIN
            PRINT 'CONSULTAS CIT'
            BEGIN 
                INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                        finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,conceptoRecaudo,valorPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                                        codDiagnosticoPrincipal,tipoDiagnosticoPrincipal, numFEVPagoModerador)
                SELECT @IDPRESTADOR,CIT.CONSECUTIVO,CIT.IDAFILIADO,fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                numAutorizacion=LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS,FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
                modalidadGrupoServicioTecSal= COALESCE(TGEN.DATO3,'01'),
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                finalidadTecnologiaSalud =LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
												WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12')
												WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10' 
														THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
																	THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'12') 
																END  
												ELSE  COALESCE(FINALIDADTGEN.DATO1,CIT.FINCONSULTA,'12') 
                                    END,2),				       
                causaMotivoAtencion=  CASE WHEN COALESCE(CIT.CAUSAEXTERNA,'') = '' 
                                          THEN CASE WHEN COALESCE(CIT.CLASEORDEN,'')='PYP' 
                                                    THEN CASE WHEN COALESCE(MPE.CAUSA_EXTERNA,'')=''
                                                              THEN '38'
                                                              ELSE MPE.CAUSA_EXTERNA
                                                         END
                                                    ELSE '38'
                                               END
                                           ELSE CIT.CAUSAEXTERNA
                                     END,
                CIT.VALORTOTAL
                ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                ,COALESCE(FTRDC.VLR_COPAGO,0),IIF(COALESCE(MED.TIPO_ID,'')='','CC',MED.TIPO_ID), MED.IDMEDICO,
                HCA.IDDX,CASE HCA.TIPODX 
                                      WHEN 'Presuntivo'   THEN '01'
                                      WHEN 'Impresion dx' THEN '01'
                                      WHEN 'Definitivo'   THEN '01'
                                      WHEN 'Conf Nuevo'   THEN '02'
                                      WHEN 'Conf Repet'   THEN '03'
                                      ELSE '01'
                                      END, @N_FACTURA
                FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                                INNER JOIN SER ON FTRDC.IDSERVICIO=SER.IDSERVICIO
                            INNER JOIN AFI ON CIT.IDAFILIADO=AFI.IDAFILIADO
                                INNER JOIN MED ON CIT.IDMEDICO = MED.IDMEDICO
                                INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                          LEFT  JOIN ( SELECT ROW_NUMBER() OVER(PARTITION BY HCA.CONSECUTIVOCIT ORDER BY HCA.FECHA ASC) ITEM,  HCA.CONSECUTIVO, CONSECUTIVOCIT, HCA.IDDX, HCA.TIPODX
                                       FROM HCA 
                                       WHERE COALESCE(CONSECUTIVOCIT,'') <> ''  
                                       AND CLASE='HC' AND PROCEDENCIA<>'QX' AND YEAR(HCA.FECHA)>='2025'  AND COALESCe(ANULADA,0)=0 
                                      ) HCA ON CIT.CONSECUTIVO=HCA.CONSECUTIVOCIT AND HCA.ITEM = 1
                          LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                          LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
                               INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                               LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA IN ('CIT','ONCO')
                AND RIPS_CP.ARCHIVO='AC'
            END
            PRINT 'CONSULTAS AUT'
            BEGIN
                INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                           finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,conceptoRecaudo,valorPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion, 
                           codDiagnosticoPrincipal, codDiagnosticoRelacionado1, codDiagnosticoRelacionado2, tipoDiagnosticoPrincipal,numFEVPagoModerador)
                SELECT @IDPRESTADOR,AUT.NOAUT,AUT.IDAFILIADO,fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                       numAutorizacion=LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30) ,codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS,FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
                     modalidadGrupoServicioTecSal='01', 
                     grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                     codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                     finalidadTecnologiaSalud=LEFT(CASE	WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
													WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' 
													ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12') 
												END,2),
                        causaMotivoAtencion=  CASE WHEN AUT.CLASEORDEN <> 'PYP' 
                                              THEN '38'
                                              ELSE CASE WHEN COALESCE(MPE.CAUSA_EXTERNA,'')='' THEN '38' ELSE MPE.CAUSA_EXTERNA END
                                        END
                      ,AUTD.VALOR
                    ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                    ,COALESCE(FTRDC.VLR_COPAGO,0),IIF(COALESCE(MED.TIPO_ID,'')='','CC',MED.TIPO_ID), COALESCE(MED.IDMEDICO, 'null',''),
                     AUT.DXPPAL, CASE WHEN COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL) THEN 'null' ELSE AUT.DXRELACIONADO END, CASE WHEN COALESCE(AUT.DXRELACIONADO2,'')='' THEN 'null' END,'01',
                     @N_FACTURA
                FROM  FTRDC INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT 
                            INNER JOIN AFI ON AUT.IDAFILIADO=AFI.IDAFILIADO
                             INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT AND FTRDC.NOPRESTACION=AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM
                            INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
                            INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                             LEFT  JOIN MED ON IIF(COALESCE(AUT.IDSOLICITANTE,'')='' OR COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA))=MED.IDMEDICO
                          LEFT  JOIN MPE ON MPE.IDPESPECIAL=AUT.IDPESPECIAL AND AUT.CLASEORDEN = 'PYP' 
                               INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                               LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='AUT'
                AND AUTD.N_FACTURA=@N_FACTURA
                AND RIPS_CP.ARCHIVO='AC'
               -- AND COALESCE(AUTD.VALOR,0)>0
            END 
            PRINT 'CONSULTAS HADM...'
            BEGIN
                INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,conceptoRecaudo,valorPagoModerador, 	tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador) 
                SELECT COALESCE(@IDPRESTADOR,''),HADM.NOADMISION,HADM.IDAFILIADO,fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                      numAutorizacion= LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30) ,codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
                    modalidadGrupoServicioTecSal='01', 
                    grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                    codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                    finalidadTecnologiaSalud=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' ELSE COALESCE(FINALIDADTGEN.DATO1,'12') END,2),
                    causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END,
                    COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),IIF(COALESCE(HADM.DXSALIDA1,'')='' OR UPPER(HADM.DXSALIDA1)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA1),IIF(COALESCE(HADM.DXSALIDA2,'')='' OR UPPER(HADM.DXSALIDA2)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA2),IIF(COALESCE(HADM.DXSALIDA3,'')='' OR UPPER(HADM.DXSALIDA3)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA3),
                    '01',HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),COALESCE(FTRDC.VLR_COPAGO,0), MED.TIPO_ID, MED.IDMEDICO, @N_FACTURA
                FROM  FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM = HPRED.NOITEM 
                           INNER JOIN HPRE ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                           INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION  
                            INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO
                            INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                           INNER JOIN MED ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' THEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA) ELSE HPRE.IDMEDICO END
                          LEFT  JOIN TGEN ON TABLA = 'GENERAL' AND CAMPO = 'CAUSAEXTERNA' AND TGEN.CODIGO = HADM.CAUSAEXTERNA
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='HADM'
                AND HPRED.N_FACTURA=@N_FACTURA
                --AND COALESCE(HPRED.VALOR,0)>0
                AND RIPS_CP.ARCHIVO='AC'
                AND HPRED.CANTIDAD=1
                PRINT 'REVISO CANTIDADES MAYORES A 1 CONSULTAS HADM'
                INSERT INTO #CONSULTAS1(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,conceptoRecaudo,valorPagoModerador,Cantidad, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador) 
                SELECT COALESCE(@IDPRESTADOR,''),HADM.NOADMISION,HADM.IDAFILIADO,fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                numAutorizacion=LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30),codConsulta=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),modalidadGrupoServicioTecSal='01',
              grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
              codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
              finalidadTecnologiaSalud=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' ELSE COALESCE(FINALIDADTGEN.DATO1,'12') END,2),
                causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END,
              COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),IIF(COALESCE(HADM.DXSALIDA1,'')='' OR UPPER(HADM.DXSALIDA1)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA1),IIF(COALESCE(HADM.DXSALIDA2,'')='' OR UPPER(HADM.DXSALIDA2)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA2),IIF(COALESCE(HADM.DXSALIDA3,'')='' OR UPPER(HADM.DXSALIDA3)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)),'null',HADM.DXSALIDA3),
                '01',HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),COALESCE(FTRDC.VLR_COPAGO,0),CONVERT(INT,HPRED.CANTIDAD), MED.TIPO_ID, MED.IDMEDICO, @N_FACTURA
                FROM  FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM = HPRED.NOITEM 
                                      INNER JOIN HPRE ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                                      INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION  
                                        INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO
                                        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                                    INNER JOIN MED ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' THEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA) ELSE HPRE.IDMEDICO END
                                     LEFT  JOIN TGEN ON TABLA = 'GENERAL' AND CAMPO = 'CAUSAEXTERNA' AND TGEN.CODIGO = HADM.CAUSAEXTERNA		
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='HADM'
                AND HPRED.N_FACTURA=@N_FACTURA
              --  AND COALESCE(HPRED.VALOR,0)>0
                AND RIPS_CP.ARCHIVO='AC'
                AND HPRED.CANTIDAD > 1
                IF EXISTS(SELECT 1 FROM #CONSULTAS1)
                BEGIN
                    PRINT 'INGRESO A MAYOR QUE 1'
                    DECLARE @MaxCantidad INT = (SELECT ISNULL(MAX(Cantidad), 1) FROM #CONSULTAS1 WHERE Cantidad > 0);
                    IF @MaxCantidad < 1 SET @MaxCantidad = 1;
                    UPDATE #CONSULTAS1 
                    SET 
                        restoPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0),
                        valorPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) - (TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0))
                    WHERE Cantidad > 0;
                    WITH Tally AS (
                        SELECT 1 AS n
                        UNION ALL
                        SELECT n + 1
                        FROM Tally
                        WHERE n < @MaxCantidad
                    ),
                    Expanded AS (
                        SELECT 
                            C.*,
                            T.n AS Repetition,
                            BaseValor = CAST(C.valorPagoModerador AS decimal(14,2)) / NULLIF(C.Cantidad, 0),
                            IsLast = CASE WHEN T.n = C.Cantidad THEN 1 ELSE 0 END
                        FROM #CONSULTAS1 C
                        INNER JOIN Tally T ON T.n <= C.Cantidad
                        WHERE C.Cantidad > 0
                    )
                    INSERT INTO #CONSULTAS (
                        codPrestador, fechaInicioAtencion, numAutorizacion, codConsulta,
                        modalidadGrupoServicioTecSal, grupoServicios, codServicio,
                        finalidadTecnologiaSalud, causaMotivoAtencion, codDiagnosticoPrincipal,
                        codDiagnosticoRelacionado1, codDiagnosticoRelacionado2,
                        codDiagnosticoRelacionado3, tipoDiagnosticoPrincipal, vrServicio,
                        valorPagoModerador, numFEVPagoModerador, tipoDocumentoIdentificacion,
                        numDocumentoIdentificacion, IDAFILIADO
                    )
                    SELECT 
                        codPrestador, fechaInicioAtencion, numAutorizacion, codConsulta,
                        modalidadGrupoServicioTecSal, grupoServicios, codServicio,
                        finalidadTecnologiaSalud, causaMotivoAtencion, codDiagnosticoPrincipal,
                        codDiagnosticoRelacionado1, codDiagnosticoRelacionado2,
                        codDiagnosticoRelacionado3, tipoDiagnosticoPrincipal, vrServicio,
                        CAST(BaseValor AS decimal(14,2)) + 
                            CASE WHEN IsLast = 1 THEN ISNULL(CAST(restoPagoModerador AS decimal(14,2)), 0) ELSE 0 END,
                        numFEVPagoModerador, tipoDocumentoIdentificacion,
                        numDocumentoIdentificacion, IDAFILIADO
                    FROM Expanded
                    OPTION (MAXRECURSION 0);
                END
            END
        END
        PRINT 'VAMOS POR MEDICAMENTOS'
        BEGIN
            PRINT 'MEDICAMENTOS CIT APLIM'
            BEGIN
                INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                        ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                        ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                        ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
                SELECT @IDPRESTADOR,LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30) ,CIT.IDAFILIADO,CIT.CONSECUTIVO,'null',fechaDispensAdmon=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                    HCA.IDDX,'null','01',(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=IIF(CHARINDEX('-',APLIMF.IDSERVICIO,0)>0,LEFT(APLIMF.IDSERVICIO,CHARINDEX('-',APLIMF.IDSERVICIO,0)-1),APLIMF.IDSERVICIO)   AND COALESCE(CODCUM,'')<>''),
                 LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),30),
                 CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
                    COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',COALESCE(APLIMF.CANTIDAD,0),1,COALESCE(MED.TIPO_ID,'CC'),CASE WHEN MED.IDMEDICO LIKE '%ILLA%' THEN COALESCE(HCA.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')) ELSE DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') END,
                 CIT.VALORTOTAL,CIT.VALORTOTAL,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO  
                    INNER JOIN APLIM ON CIT.CONSECUTIVO=APLIM.CONSECUTIVOCIT
                 INNER JOIN ( SELECT ROW_NUMBER() OVER(PARTITION BY IDAPLIM,IDSERVICIO ORDER BY IDAPLIM,IDSERVICIO ASC) ITEM, IDAPLIM,IDSERVICIO,CANTIDAD
                             FROM APLIMF 
                             WHERE COALESCE(CLASE,'')='MEDI'  
                             ) APLIMF ON APLIM.ID=APLIMF.IDAPLIM AND APLIMF.ITEM=1
                    INNER JOIN SER ON APLIMF.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO 
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                 LEFT  JOIN ( SELECT ROW_NUMBER() OVER(PARTITION BY HCA.CONSECUTIVOCIT ORDER BY HCA.FECHA ASC) ITEM,  HCA.CONSECUTIVO, CONSECUTIVOCIT, HCA.IDDX, HCA.TIPODX,
                              HCA.IDMEDICO
                             FROM HCA 
                             WHERE COALESCE(CONSECUTIVOCIT,'') <> ''  AND YEAR(HCA.FECHA)>='2025'  AND COALESCe(ANULADA,0)=0 
                             ) HCA ON CIT.CONSECUTIVO=HCA.CONSECUTIVOCIT AND HCA.ITEM = 1
                    LEFT  JOIN IART ON SER.IDSERVICIO=IART.IDSERVICIO AND IART.PRINCIPAL=1
                    LEFT  JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
                    LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
                 LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
                 LEFT JOIN MED ON IIF(COALESCE(CIT.IDMEDICO,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(CIT.IDMEDICO,''))=MED.IDMEDICO
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='APLIM'
                AND CIT.N_FACTURA=@N_FACTURA
                AND RIPS_CP.ARCHIVO='AM'
            END
            PRINT 'MEDICAMENTOS AUT'
            BEGIN
                INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                        ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                        ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                        ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
                SELECT @IDPRESTADOR,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30) ,AUT.IDAFILIADO,AUT.NOAUT,'null',fechaDispensAdmon=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                    AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),'01',COALESCE(SER.CODCUM,IART.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>'')),LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),30),
                 CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
                    COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',COALESCE(AUTD.CANTIDAD,0),CASE WHEN COALESCE(AUTD.DIAS,0)=0 THEN 1 ELSE AUTD.DIAS END,COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),
                 AUTD.VALOR,AUTD.VALOR*AUTD.CANTIDAD,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                FROM FTRDC INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT  
                    INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT
                    INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO 
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    LEFT  JOIN IART ON SER.IDSERVICIO=IART.IDSERVICIO AND IART.PRINCIPAL=1
                    LEFT  JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
                    LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
                 LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
                 LEFT JOIN MED ON IIF(COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA))=MED.IDMEDICO
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='AUT'
                AND AUTD.N_FACTURA=@N_FACTURA
                AND RIPS_CP.ARCHIVO='AM'
            END
            PRINT 'MEDICAMENTOS HADM'
            BEGIN
                INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                        ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                        ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                        ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
                SELECT @IDPRESTADOR,LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30) ,HADM.IDAFILIADO,HADM.NOADMISION,'null',fechaDispensAdmon=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,FTRDC.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,FTRDC.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                    COALESCE(HADM.DXINGRESO,''),IIF(COALESCE(HADM.DXSALIDA1,'')='' OR UPPER(HADM.DXSALIDA1)=UPPER(COALESCE(HADM.DXINGRESO,'')),'null',HADM.DXSALIDA1),'01',CASE WHEN COALESCE(SER.MEDICAMENTOS,0)=1 THEN IIF(COALESCE(IART.CODCUM,'')='',COALESCE(SER.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>'')),IART.CODCUM) ELSE SER.IDSERVICIO END,
                    LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),
                    CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',
                    COALESCE(HPRED.CANTIDAD,0),1,COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR),20),
                    CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR*HPRED.CANTIDAD),20),DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END),'04',CONVERT(DECIMAL(14,2),FTRDC.VLR_COPAGO),@N_FACTURA
                FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION
                    INNER JOIN AFI  ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM 
                    INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    LEFT JOIN IART ON COALESCE(HPRED.IDARTICULO,SER.IDARTICULO)=IART.IDARTICULO
                    LEFT JOIN IFFA ON IART.IDFORFARM=IFFA.IDFORFARM
                    LEFT JOIN IUNI ON IUNI.IDUNIDAD = IART.IDUNIDAD
                 LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
                 LEFT JOIN MED ON COALESCE(HADM.IDMEDICOING,HADM.IDMEDICOTRA)=MED.IDMEDICO
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='HADM'
                AND HPRED.N_FACTURA=@N_FACTURA
             --   AND COALESCE(HPRED.VALOR,0)>0
                AND COALESCE(HPRED.NOCOBRABLE,0)=0
                AND RIPS_CP.ARCHIVO='AM'
            END
        END
        PRINT 'PROCEDIMIENTOS'
        BEGIN 
            PRINT 'PROCEDIMIENTOS CIT'
            BEGIN
                INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                        ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                        ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                        )
                SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),'null',
                         LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),'02',
                     COALESCE(TGEN.DATO3,'01'),
                     grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                     codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                     finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
												WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12')
												WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10' 
														THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
																	THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'12') 
																END  
												ELSE  COALESCE(FINALIDADTGEN.DATO1,CIT.FINCONSULTA,'12') 
                                            END,2),	
                     MED.TIPO_ID,MED.IDMEDICO,CIT.IDDX,
                         CASE WHEN COALESCE(CIT.IDDX,'')='' THEN 'null' ELSE 'null' END,CASE WHEN COALESCE(CIT.IDDX,'')='' THEN 'null' ELSE 'null' END,CIT.VALORTOTAL
                    ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                    ,'04'
                    ,COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                FROM  FTRDC 
                    INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                    INNER JOIN SER ON CIT.IDSERVICIO=SER.IDSERVICIO
                    INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                 LEFT  JOIN MED ON CIT.IDMEDICO=MED.IDMEDICO
                 LEFT  JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                 LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
                       INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                       LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA IN('CIT','ONCO')
                AND RIPS_CP.ARCHIVO='AP'
            END   
            PRINT 'PROCEDIMIENTOS AUT'
            BEGIN
                INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
                SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5), @FECHAINICAP, @FECHAFINCAP),'NULL'
                    ,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),'02',
                  '01'
                  ,grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END
                  ,codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END
                  ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , 
                  COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'))
                    ,AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),AUT.DXPPAL,AUTD.VALOR
                  ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                  ,'04'
                    ,CASE WHEN AUT.IDPLAN IN (DBO.FNK_VALORVARIABLE ('IDPLANPART'),DBO.FNK_VALORVARIABLE ('IDPLANPART2')    
                                            ,DBO.FNK_VALORVARIABLE ('IDPLANPART3'),DBO.FNK_VALORVARIABLE ('IDPLANPART4')  
                                            ,DBO.FNK_VALORVARIABLE ('IDPLANPART5'))                                       
                            THEN '0.00' 
                            ELSE FTRDC.VLR_COPAGO
                            END
                    ,@N_FACTURA
                FROM FTRDC 
                        INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT
                        INNER  JOIN AUTD ON AUT.IDAUT = AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM
                        INNER JOIN AFI ON COALESCE(FTRDC.IDAFILIADO,AUT.IDAFILIADO)=AFI.IDAFILIADO
                        INNER JOIN SER ON AUTD.IDSERVICIO = SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO
                        INNER JOIN RIPS_CP ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
                        LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA))				
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='AUT'
                AND AUTD.N_FACTURA = @N_FACTURA
                AND RIPS_CP.ARCHIVO = 'AP'
                AND FTRDC.CANTIDAD = 1
                INSERT INTO #PROCEDIMIENTOS1 (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,cantidad,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
                SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5), @FECHAINICAP, @FECHAFINCAP),'NULL'
                    ,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),'02','01'
                  ,grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END
                  ,codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END
                  ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , 
                  COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'))
                    ,AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),AUT.DXPPAL,AUTD.VALOR
                  ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                  ,FTRDC.CANTIDAD,'04'
                    ,CASE WHEN AUT.IDPLAN IN (DBO.FNK_VALORVARIABLE ('IDPLANPART'),DBO.FNK_VALORVARIABLE ('IDPLANPART2')    
                                            ,DBO.FNK_VALORVARIABLE ('IDPLANPART3'),DBO.FNK_VALORVARIABLE ('IDPLANPART4')  
                                            ,DBO.FNK_VALORVARIABLE ('IDPLANPART5'))                                       
                            THEN '0.00' 
                            ELSE FTRDC.VLR_COPAGO
                            END
                    ,@N_FACTURA
                FROM FTRDC 
                        INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT
                        INNER  JOIN AUTD ON AUT.IDAUT = AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM
                        INNER JOIN AFI ON COALESCE(FTRDC.IDAFILIADO,AUT.IDAFILIADO)=AFI.IDAFILIADO
                        INNER JOIN SER ON AUTD.IDSERVICIO = SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO
                        INNER JOIN RIPS_CP ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
                        LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA))				
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='AUT'
                AND AUTD.N_FACTURA = @N_FACTURA
                AND RIPS_CP.ARCHIVO = 'AP'
                AND FTRDC.CANTIDAD > 1
                UPDATE #PROCEDIMIENTOS1 
                SET 
                    restoPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0),
                    valorPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) - (TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0))
                WHERE Cantidad > 0;
                DECLARE @RESIDUO DECIMAL(14,2) = (
                    SELECT ISNULL(SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))), 0)
                    FROM #PROCEDIMIENTOS1
                    WHERE Cantidad > 0
                );
                DECLARE @MaxCantidad1 INT = (
                    SELECT ISNULL(MAX(Cantidad), 1)
                    FROM #PROCEDIMIENTOS1
                    WHERE Cantidad > 0
                );
                IF @MaxCantidad1 < 1 SET @MaxCantidad1 = 1;
                WITH Tally AS (
                    SELECT 1 AS n
                    UNION ALL
                    SELECT n + 1
                    FROM Tally
                    WHERE n < @MaxCantidad1
                ),
                Expanded AS (
                    SELECT 
                        P.*,
                        T.n AS Bandera,
                        ValorUnitario = CONVERT(INT, CAST(P.valorPagoModerador AS decimal(14,2)) / NULLIF(P.Cantidad, 0)),
                        EsUltimoDePrimero = CASE 
                            WHEN P.IDPROCE = 1 AND T.n = P.Cantidad THEN 1 
                            ELSE 0 
                        END
                    FROM #PROCEDIMIENTOS1 P
                    INNER JOIN Tally T ON T.n <= P.Cantidad
                    WHERE P.Cantidad > 0
                )
                INSERT INTO #PROCEDIMIENTOS (
                    codPrestador, IDAFILIADO, CONSECUTIVO, fechaInicioAtencion, idMIPRES, numAutorizacion,
                    codProcedimiento, viaIngresoServicioSalud, modalidadGrupoServicioTecSal, grupoServicios,
                    codServicio, finalidadTecnologiaSalud, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                    codDiagnosticoPrincipal, codDiagnosticoRelacionado, codComplicacion, vrServicio,
                    conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador
                )
                SELECT 
                    codPrestador, IDAFILIADO, CONSECUTIVO, fechaInicioAtencion, idMIPRES, numAutorizacion,
                    codProcedimiento, viaIngresoServicioSalud, modalidadGrupoServicioTecSal, grupoServicios,
                    codServicio, finalidadTecnologiaSalud, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                    codDiagnosticoPrincipal, codDiagnosticoRelacionado, codComplicacion, vrServicio,
                    conceptoRecaudo, tipoPagoModerador,
                    ValorUnitario + 
                        CASE 
                            WHEN EsUltimoDePrimero = 1 THEN ISNULL(@RESIDUO, 0) 
                            ELSE 0 
                        END,
                    numFEVPagoModerador
                FROM Expanded
                OPTION (MAXRECURSION 0);
                DELETE FROM #PROCEDIMIENTOS1 WHERE 1=1
            END
            PRINT 'PROCEDIMIENTOS HADM'
            BEGIN
                INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                      )
                SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),'null',
                    LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),'01',
                 grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                 codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
                 ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , 
                 COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO), 
                    CASE WHEN COALESCE(HADM.DXSALIDA1,'')='' OR LEN(COALESCE(HADM.DXSALIDA1,''))<4 OR UPPER(HADM.DXSALIDA1)=UPPER(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)) THEN 'null' ELSE HADM.DXSALIDA1 END, 
                    CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END, 
                 HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                FROM  FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM
                           INNER JOIN HPRE  ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                        INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION
                    INNER JOIN AFI  ON HADM.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                      INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    INNER JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
                      LEFT JOIN MED ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') 
                                                     ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='HADM'
                AND HPRED.N_FACTURA=@N_FACTURA
             --   AND COALESCE(HPRED.VALOR,0)>0
                AND COALESCE(HPRED.NOCOBRABLE,0)=0
                AND HPRED.CANTIDAD=1
              AND COALESCE(HPRED.IDCIRUGIA,'') = ''
                AND RIPS_CP.ARCHIVO='AP' 
                PRINT 'INSERTO CANTIDAS MAYORES A UNO HADM '
                INSERT INTO #PROCEDIMIENTOS1 (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,cantidad,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                      )
                SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),'null',
                    LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),'01',
                 grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                 codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
                 ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , 
                 COALESCE(MED.TIPO_ID,'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),
                 COALESCE(HADM.DXINGRESO,HADM.DXEGRESO), 
                    CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) END,CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
                 HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),HPRED.CANTIDAD, '04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                FROM  FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM
                           INNER JOIN HPRE  ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                        INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION
                    INNER JOIN AFI  ON HADM.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                      INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    INNER JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
                      LEFT JOIN MED ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') 
                                                     ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
                WHERE FTRDC.CNSFTR=@CNSFCT
                AND FTRDC.PROCEDENCIA='HADM'
                AND HPRED.N_FACTURA=@N_FACTURA
                --AND COALESCE(HPRED.VALOR,0)>0
                AND COALESCE(HPRED.NOCOBRABLE,0)=0
                AND HPRED.CANTIDAD>1
                AND RIPS_CP.ARCHIVO='AP' 
                AND COALESCE(HPRED.IDCIRUGIA,'') = ''
                PRINT 'INSERTO CIRUGIAS'
                IF EXISTS (SELECT 1 FROM FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION = HPRED.NOPRESTACION AND FTRDC.NOITEM = HPRED.NOITEM
                            WHERE FTRDC.CNSFTR = @CNSFCT AND FTRDC.PROCEDENCIA = 'HADM'
                               AND HPRED.N_FACTURA = @N_FACTURA AND COALESCE(HPRED.VALOR, 0) > 0 AND COALESCE(HPRED.NOCOBRABLE, 0) = 0
                               AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
                   )
                BEGIN
                      INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                      )
                      SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),'null',
                            LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),'01',
                         grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                         codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
                         ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , 
                         COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
                            upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
                            upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
                         FTRDC.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                        FROM  FTRDC INNER JOIN HADM    ON FTRDC.NOADMISION=HADM.NOADMISION
                                    INNER JOIN AFI     ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                                    INNER JOIN HPRED   ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM
                                    INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION AND FTRDC.NOPRESTACION=HPRE.NOPRESTACION
                                    INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO
                                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                                    INNER JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
                                    LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') 
                                                           ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
                           INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                           LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
                        WHERE FTRDC.CNSFTR = @CNSFCT
                        AND FTRDC.PROCEDENCIA = 'HADM'
                        AND HPRED.N_FACTURA = @N_FACTURA
                     --   AND COALESCE(HPRED.VALOR,0) > 0
                        AND COALESCE(HPRED.NOCOBRABLE,0) = 0
                      AND COALESCE(SER.CIRUGIA,0) = 1
                        AND RIPS_CP.ARCHIVO = 'AP' 
                END
                IF EXISTS(SELECT 1 FROM #PROCEDIMIENTOS1)
                BEGIN
                   UPDATE #PROCEDIMIENTOS1 
                    SET 
                        restoPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0),
                        valorPagoModerador = TRY_CAST(valorPagoModerador AS decimal(14,2)) - (TRY_CAST(valorPagoModerador AS decimal(14,2)) % NULLIF(Cantidad, 0))
                    WHERE Cantidad > 0;
                    DECLARE @RESIDUO1 DECIMAL(14,2) = (
                        SELECT ISNULL(SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))), 0)
                        FROM #PROCEDIMIENTOS1
                        WHERE Cantidad > 0
                    );
                    DECLARE @MaxCantidad2 INT = (
                        SELECT ISNULL(MAX(Cantidad), 1)
                        FROM #PROCEDIMIENTOS1
                        WHERE Cantidad > 0
                    );
                    IF @MaxCantidad2 < 1 SET @MaxCantidad2 = 1;
                    WITH Tally AS (
                        SELECT 1 AS n
                        UNION ALL
                        SELECT n + 1
                        FROM Tally
                        WHERE n < @MaxCantidad2
                    ),
                    Expanded AS (
                        SELECT 
                            P.*,
                            T.n AS Bandera,
                            ValorUnitario = CONVERT(INT, CAST(P.valorPagoModerador AS decimal(14,2)) / NULLIF(P.Cantidad, 0)),
                            EsUltimoDePrimero = CASE 
                                WHEN P.IDPROCE = 1 AND T.n = P.Cantidad THEN 1 
                                ELSE 0 
                            END
                        FROM #PROCEDIMIENTOS1 P
                        INNER JOIN Tally T ON T.n <= P.Cantidad
                        WHERE P.Cantidad > 0
                    )
                    INSERT INTO #PROCEDIMIENTOS (
                        codPrestador, IDAFILIADO, CONSECUTIVO, fechaInicioAtencion, idMIPRES, numAutorizacion,
                        codProcedimiento, viaIngresoServicioSalud, modalidadGrupoServicioTecSal, grupoServicios,
                        codServicio, finalidadTecnologiaSalud, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                        codDiagnosticoPrincipal, codDiagnosticoRelacionado, codComplicacion, vrServicio,
                        conceptoRecaudo, tipoPagoModerador, valorPagoModerador, numFEVPagoModerador
                    )
                    SELECT 
                        codPrestador, IDAFILIADO, CONSECUTIVO, fechaInicioAtencion, idMIPRES, numAutorizacion,
                        codProcedimiento, viaIngresoServicioSalud, modalidadGrupoServicioTecSal, grupoServicios,
                        codServicio, finalidadTecnologiaSalud, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                        codDiagnosticoPrincipal, codDiagnosticoRelacionado, codComplicacion, vrServicio,
                        conceptoRecaudo, tipoPagoModerador,
                        ValorUnitario + 
                            CASE 
                                WHEN EsUltimoDePrimero = 1 THEN ISNULL(@RESIDUO1, 0) 
                                ELSE 0 
                            END,
                        numFEVPagoModerador
                    FROM Expanded
                    OPTION (MAXRECURSION 0);
                END
            END
        END
        PRINT  'URGENCIAS'
        UPDATE HADM SET HADM.DXINGRESO=CASE WHEN COALESCE(HADM.DXINGRESO,'')='' THEN HCA.IDDX ELSE HADM.DXINGRESO END,
                        HADM.DXSALIDA1=CASE WHEN COALESCE(HADM.DXSALIDA1,'')='' THEN HCA.IDDX ELSE HADM.DXSALIDA1 END,
                        HADM.DXSALIDA2=CASE WHEN COALESCE(HADM.DXSALIDA2,'')='' THEN HCA.IDDX ELSE HADM.DXSALIDA2 END,
                        HADM.DXSALIDA3=CASE WHEN COALESCE(HADM.DXSALIDA3,'')='' THEN HCA.IDDX ELSE HADM.DXSALIDA3 END
        FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION
                    INNER JOIN HCA ON HADM.NOADMISION=HCA.NOADMISION
        WHERE FTRDC.CNSFTR=@CNSFCT 
        AND FTRDC.PROCEDENCIA='HADM'
        BEGIN
        INSERT INTO #URGENCIAS(codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoPrincipalE,
                                codDiagnosticoRelacionadoE1,codDiagnosticoRelacionadoE2,codDiagnosticoRelacionadoE3,condicionDestinoUsuarioEgreso,
                                codDiagnosticoCausaMuerte,fechaEgreso)
        SELECT DISTINCT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,
                REPLACE(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <= @FECHAINICAP THEN @FECHAINICAP ELSE HADM.FECHA END,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <= @FECHAINICAP THEN @FECHAINICAP ELSE HADM.FECHA END,108),5),
        --CASE WHEN COALESCE(TGEN.CHECK1,0)=1 THEN DATO1 ELSE CODIGO END
        causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END
        ,COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HADM.DXEGRESO,HCA.DX1,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),
        COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HADM.DXSALIDA3,HCA.DX2),CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END,
        CASE WHEN HADM.ESTADOPSALIDA=1 THEN null ELSE CAUSABMUERTE END
         ,REPLACE(CONVERT(VARCHAR,
               CASE
                  WHEN HADM.FECHAALTAMED IS NULL THEN @FECHAFINCAP
                  WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN @FECHAFINCAP
                  WHEN HADM.FECHAALTAMED <= @FECHAINICAP THEN @FECHAINICAP
                  ELSE HADM.FECHAALTAMED
               END
         ,102),'.','-')+' '+CASE
                  WHEN HADM.FECHAALTAMED IS NULL THEN '23:59'
                  WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN '23:59'
                  WHEN HADM.FECHAALTAMED <= @FECHAINICAP THEN '23:59'
                  ELSE LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5)
               END
        FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION  
                LEFT JOIN (SELECT NOADMISION,MAX(HCA.IDDX)IDDX,MAX(HCA.DX1)DX1,MAX(DX2)DX2 FROM HCA WHERE 
                           EXISTS(SELECT 1 FROM FTRDC WHERE HCA.NOADMISION=FTRDC.NOADMISION  AND FTRDC.CNSFTR=@CNSFCT 
                           AND FTRDC.PROCEDENCIA='HADM'
                           ) AND HCA.CLASE='HC'
                             AND HCA.PROCEDENCIA='QX'
                             AND HCA.CLASEPLANTILLA <> DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
                             GROUP BY NOADMISION
                           )HCA ON HADM.NOADMISION=HCA.NOADMISION
                LEFT JOIN TGEN ON HADM.CAUSAEXTERNA=TGEN.CODIGO AND TGEN.TABLA='General' AND TGEN.CAMPO='CAUSAEXTERNA'
        WHERE FTRDC.CNSFTR=@CNSFCT 
        AND FTRDC.PROCEDENCIA='HADM'
        AND DATEDIFF(HOUR,HADM.FECHA,HADM.FECHAALTAMED)<=36
        END
        PRINT 'HOSPITALIZACION'
        BEGIN 
            INSERT INTO #HOSPITALIZACION (codPrestador,IDAFILIADO,CONSECUTIVO,viaIngresoServicioSalud,fechaInicioAtencion,numAutorizacion,causaMotivoAtencion,codDiagnosticoPrincipal,
                                        codDiagnosticoPrincipalE,codDiagnosticoRelacionadoE1,codDiagnosticoRelacionadoE2,codDiagnosticoRelacionadoE3,
                                        codComplicacion,condicionDestinoUsuarioEgreso,codDiagnosticoCausaMuerte,fechaEgreso)
            SELECT DISTINCT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,DBO.FNK_RIPS_VIA_INGRESO(IIF (HADM.TIPOADM='02' AND  HADM.VIAINGRESO = '5' , '13' ,  COALESCE(REPLACE(TGEN.DATO2,' ',''), HADM.VIAINGRESO ,'01') )),
            REPLACE(CONVERT(VARCHAR,CASE WHEN HADM.FECHA < @FECHAINICAP THEN @FECHAINICAP ELSE  HADM.FECHA END,102),'.','-')+' '+
            CASE WHEN HADM.FECHA < @FECHAINICAP THEN '00:00' ELSE  LEFT(CONVERT(VARCHAR,HADM.FECHA,108),5) END
                ,LEFT(COALESCE(NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''), 'null'), 30)
                ,COALESCE(REPLACE(TGEN2.DATO1,' ',''),HADM.CAUSAEXTERNA,'38')
                ,COALESCE(HADM.DXINGRESO,'')
                ,COALESCE(HADM.DXEGRESO,'')
                ,CASE WHEN COALESCE(HADM.DXSALIDA1,'')='' THEN 'null' ELSE HADM.DXSALIDA1 END
                ,CASE WHEN COALESCE(HADM.DXSALIDA2,'')='' THEN 'null' ELSE HADM.DXSALIDA2 END
                ,CASE WHEN COALESCE(HADM.DXSALIDA3,'')='' THEN 'null' ELSE HADM.DXSALIDA3 END
                ,COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO)
                ,CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END
                ,CASE WHEN HADM.ESTADOPSALIDA=1 THEN '' ELSE CAUSABMUERTE END
                ,REPLACE(CONVERT(VARCHAR,CASE WHEN @FECHAINICAP<HADM.FECHAALTAMED THEN CASE WHEN HADM.FECHAALTAMED>@FECHAFINCAP  THEN @FECHAFINCAP ELSE HADM.FECHAALTAMED END ELSE HADM.FECHAALTAMED END ,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5)
            FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION
                    LEFT JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
                    LEFT JOIN TGEN TGEN2 ON HADM.CAUSAEXTERNA = TGEN2.CODIGO AND TGEN2.TABLA = 'General' AND TGEN2.CAMPO = 'CAUSAEXTERNA'
            WHERE FTRDC.CNSFTR=@CNSFCT 
            AND FTRDC.PROCEDENCIA='HADM'
            AND DATEDIFF(HOUR,HADM.FECHA,HADM.FECHAALTAMED)>36
        END 
        PRINT 'RECIEN NACIDOS'
        IF EXISTS (SELECT 1 FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION INNER JOIN QXRCN ON HADM.NOADMISION=QXRCN.NOADMISION
                WHERE FTRDC.CNSFTR=@CNSFCT AND FTRDC.PROCEDENCIA='HADM'
                )
        BEGIN
            INSERT INTO #RECIEN(codPrestador,IDAFILIADO,CONSECUTIVO,tipoDocumentoIdentificacion,numDocumentoIdentificacion,fechaNacimiento,
                                edadGestacional,numConsultasCPrenatal,codSexoBiologico,peso, codDiagnosticoPrincipal,condicionDestinoUsuarioEgreso,
                                codDiagnosticoCausaMuerte,fechaEgreso
                                )
        SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,'CN',AFI.DOCIDAFILIADO,
        REPLACE(CONVERT(VARCHAR,QXRCN.RNFECHANACE,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,QXRCN.RNFECHANACE,108),5),
        --QXRCN.CMPERIODOGES,
        CONVERT(INT,LEFT(QXRCN.CMPERIODOGES, PATINDEX('%[A-Za-z.,]%', QXRCN.CMPERIODOGES + 'x') - 1))
        ,QXRCN.CMCONTROLPRE,CASE WHEN LEFT(QXRCN.RNSEXO,1)='M' THEN '01' WHEN LEFT(QXRCN.RNSEXO,1)='M'  THEN  '02' ELSE '03' END,
        QXRCN.RNPESO,QXRCN.RNDX,QXRCN.ESTADORN,
        QXRCN.CMCAUSAMUERTE,
        REPLACE(CONVERT(VARCHAR,HADM.FECHAALTAMED,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5)
        FROM  QXRCN INNER JOIN HADM ON QXRCN.NOADMISION=HADM.NOADMISION 
                    INNER JOIN AFI ON HADM.IDAFILIADO=AFI.IDAFILIADO
        WHERE EXISTS(SELECT * FROM FTRDC   WHERE HADM.NOADMISION=FTRDC.NOADMISION AND FTRDC.CNSFTR=@CNSFCT
        AND FTRDC.PROCEDENCIA='HADM' )
        END
        PRINT 'OTROS SERVICIOS'
        BEGIN
            INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                                ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                                ,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,numAutorizacion=CIT.NOAUTORIZACION,null,
                fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
                codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
                cantidadOS=IIF(COALESCE(CIT.CANTIDADC,1)=0,1,COALESCE(CIT.CANTIDADC,1)),tipoDocumentoIdentificacion=AFI.TIPO_DOC,
                numDocumentoIdentificacion=AFI.DOCIDAFILIADO,COALESCE(CIT.VALORTOTAL,0),COALESCE(CIT.VALORTOTAL,0)
                                ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END),tipoPagoModerador='04',COALESCE(FTRDC.VLR_COPAGO,0),
                @N_FACTURA
            FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                        INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                        INNER JOIN SER ON CIT.IDSERVICIO=SER.IDSERVICIO
                        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA='CIT'
            AND CIT.N_FACTURA=@N_FACTURA
            AND RIPS_CP.ARCHIVO='AT'
            PRINT 'TERMINO CIT'
            INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                                ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                                ,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,numAutorizacion=AUT.NUMAUTORIZA,null,
                fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
                codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
                cantidadOS=COALESCE(AUTD.CANTIDAD,1),tipoDocumentoIdentificacion=MED.TIPO_ID,
                numDocumentoIdentificacion=MED.IDMEDICO,
                COALESCE(AUTD.VALOR,0),
                COALESCE(AUTD.VALOR,0)*COALESCE(AUTD.CANTIDAD, 0)
                                ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END),
                tipoPagoModerador='04',
                COALESCE(FTRDC.VLR_COPAGO,0),
                @N_FACTURA
            FROM FTRDC INNER JOIN AUT ON FTRDC.NOADMISION= AUT.IDAUT
                         INNER JOIN AFI ON AUT.IDAFILIADO=AFI.IDAFILIADO
                         INNER JOIN AUTD ON AUT.IDAUT = AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM
                        INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
                        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                        LEFT  JOIN MED		ON MED.IDMEDICO    = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA='AUT'
            AND AUTD.N_FACTURA=@N_FACTURA
            AND RIPS_CP.ARCHIVO='AT'
            PRINT 'TERMINO AUT'
            INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                                ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                                ,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION                                                                   
                ,numAutorizacion=HADM.NOAUTORIZACION
                ,null                                                                             
                ,fechaInicioAtencion=DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP)
                ,tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END
                ,codTecnologiaSalud=CASE WHEN RIPS_CP.IDCONCEPTORIPS=DBO.FNK_VALORVARIABLE('IDMATERIALESRIPS')THEN SER.IDSERVICIO ELSE left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6) END
                ,nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
                ,cantidadOS=CONVERT(INT,COALESCE(HPRED.CANTIDAD,1))
                ,tipoDocumentoIdentificacion=MED.TIPO_ID
                ,numDocumentoIdentificacion=MED.IDMEDICO
                ,CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR,0))
                ,CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR*HPRED.CANTIDAD,0))
                               ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(
                FTRDC.VLR_COPAGO,
                FTRDC.TCOPAGO,
                FTRDC.PROCEDENCIA,
                CASE WHEN COALESCE(AFI.TIPOUSUARIO, '') IN ('01', '02', '03', '04') THEN '01' ELSE @conceptoRecaudo END)
                ,tipoPagoModerador='04'
                ,CONVERT(DECIMAL(14,2),COALESCE(FTRDC.VLR_COPAGO,0)) 
                ,@N_FACTURA                                                                       
            FROM FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM 
                      INNER JOIN  HPRE ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                      INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION
                      INNER JOIN AFI ON HADM.IDAFILIADO=AFI.IDAFILIADO
                      INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                      INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                      INNER JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING)='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
                      LEFT JOIN HCA ON HPRE.CONSECUTIVOHCA=HCA.CONSECUTIVO
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA='HADM'
            AND HPRED.N_FACTURA=@N_FACTURA
            AND RIPS_CP.ARCHIVO='AT'   
           -- AND COALESCE(HPRED.VALOR,0)>0
            AND COALESCE(HPRED.NOCOBRABLE,0)=0
            PRINT 'TERMINO HADM OTROS SER'
        END 
        PRINT 'TERMINO LA RECOLECCION DE DATOS '+CAST(GETDATE() AS VARCHAR(20))
        PRINT 'ASOCIANDO IDUSUARIO'
        BEGIN
            UPDATE #CONSULTAS SET usuarioId=US.usuarioId
            FROM #CONSULTAS AC INNER JOIN #USUARIOS US ON AC.IDAFILIADO=US.IDAFILIADO
            UPDATE #MEDICAMENTOS SET usuarioId=US.usuarioId
            FROM #MEDICAMENTOS AM INNER JOIN #USUARIOS US ON AM.IDAFILIADO=US.IDAFILIADO
            UPDATE #PROCEDIMIENTOS SET usuarioId=US.usuarioId
            FROM #PROCEDIMIENTOS AP INNER JOIN #USUARIOS US ON AP.IDAFILIADO=US.IDAFILIADO
            UPDATE #OTROSSER SET usuarioId=US.usuarioId
            FROM #OTROSSER OT INNER JOIN #USUARIOS US ON OT.IDAFILIADO=US.IDAFILIADO
            UPDATE #URGENCIAS SET usuarioId=US.usuarioId
            FROM #URGENCIAS AU INNER JOIN #USUARIOS US ON AU.IDAFILIADO=US.IDAFILIADO
            UPDATE #HOSPITALIZACION SET usuarioId=US.usuarioId
            FROM #HOSPITALIZACION AH INNER JOIN #USUARIOS US ON AH.IDAFILIADO=US.IDAFILIADO
            UPDATE #RECIEN SET usuarioId=US.usuarioId
            FROM #RECIEN AN INNER JOIN #USUARIOS US ON AN.IDAFILIADO=US.IDAFILIADO
        END
        PRINT 'ARMADO TABLA DIAGNOSTICOS '
       DECLARE @USUARIOID INT
       DECLARE @FNACI DATETIME
       DECLARE @FECHAATE DATETIME
       DECLARE @TIPDC VARCHAR(2)
       DECLARE @TIPODOCN VARCHAR(2)
       DECLARE VALI_CURSOR CURSOR FOR 
       SELECT  X.usuarioId,AFI.FNACIMIENTO,MAX(FTRDC.FECHA)FECHA,X.tipoDocumentoIdentificacion  
               FROM FTRDC INNER JOIN #USUARIOS X ON FTRDC.IDAFILIADO=X.IDAFILIADO
                          INNER JOIN AFI ON X.IDAFILIADO=AFI.IDAFILIADO
       WHERE FTRDC.CNSFTR=@CNSFCT
       AND AFI.EDAD LIKE '%A�OS%'
       AND CONVERT(INT,LTRIM(RTRIM(REPLACE(AFI.EDAD,'A�OS','')))) IN(3,7,8,18)
       GROUP BY X.usuarioId,AFI.FNACIMIENTO,X.tipoDocumentoIdentificacion
       OPEN VALI_CURSOR    
       FETCH NEXT FROM VALI_CURSOR    
       INTO @USUARIOID,@FNACI,@FECHAATE,@TIPDC
       WHILE @@FETCH_STATUS = 0    
       BEGIN 
          SET @TIPODOCN=NULL
          SELECT @TIPODOCN=dbo.FNK_JSON_EDADYTIPODOC(@FNACI,@FECHAATE,@TIPDC)
          IF @TIPODOCN<>'tr'
          BEGIN
            UPDATE #USUARIOS SET tipoDocumentoIdentificacion=@TIPODOCN WHERE USUARIOID=@USUARIOID
          END
          FETCH NEXT FROM VALI_CURSOR    
          INTO @USUARIOID,@FNACI,@FECHAATE,@TIPDC
       END
       CLOSE VALI_CURSOR
       DEALLOCATE VALI_CURSOR
        BEGIN
            INSERT INTO #DX (IDAFILIADO,NOADMISION,CONSECUTIVOCIT,TIPODX,IDDX,DX1,DX2,DX3)
            SELECT HCA.IDAFILIADO,HCA.NOADMISION,'',
                   MAX( CASE HCA.TIPODX 
                                WHEN 'Presuntivo'   THEN '01'
                                WHEN 'Impresion dx' THEN '01'
                                WHEN 'Definitivo'   THEN '01'
                                WHEN 'Conf Nuevo'   THEN '02'
                                WHEN 'Conf Repet'   THEN '03'
                                ELSE '01'
                                END),MAX(LEFT(HCA.IDDX,4)),MAX(LEFT(HCA.DX1,4)),MAX(LEFT(HCA.DX2,4)),MAX(LEFT(HCA.DX3,4))
            FROM HCA INNER JOIN HADM ON HCA.NOADMISION=HADM.NOADMISION AND HCA.IDAFILIADO = HADM.IDAFILIADO
            WHERE HCA.CLASE='HC'
            AND HCA.PROCEDENCIA='QX'
            AND EXISTS(SELECT 1 FROM FTRDC WHERE  FTRDC.CNSFTR=@CNSFCT AND FTRDC.IDAFILIADO=HCA.IDAFILIADO AND((FTRDC.NOADMISION=HCA.NOADMISION AND FTRDC.PROCEDENCIA='HADM') OR (FTRDC.NOADMISION=HCA.CONSECUTIVOCIT AND FTRDC.PROCEDENCIA='CIT')))
            GROUP BY  HCA.IDAFILIADO,HCA.NOADMISION
        END
        PRINT 'ACTUALIZO TABLA DIAGNOSTICOS '
        BEGIN
            UPDATE #DX SET NIDDX=MDX.DESCRIPCION
            FROM #DX DX INNER JOIN MDX ON DX.IDDX=MDX.IDDX
            UPDATE #DX SET NDX1=MDX.DESCRIPCION
            FROM #DX DX INNER JOIN MDX ON DX.DX1=MDX.IDDX
            UPDATE #DX SET NDX2=MDX.DESCRIPCION
            FROM #DX DX INNER JOIN MDX ON DX.DX2=MDX.IDDX
            UPDATE #DX SET NDX3=MDX.DESCRIPCION
            FROM #DX DX INNER JOIN MDX ON DX.DX3=MDX.IDDX
            PRINT 'Diagnosticos consultas'
        END
        PRINT 'Actualizaci�n de LAS TABLAS con los diagn�sticos principales y relacionados en un solo bloque'
        PRINT 'TERMINO LA RECOLECCION DE DIAGNOSTICOS '+CAST(GETDATE() AS VARCHAR(20))
        BEGIN
            PRINT 'Diagnosticos Consultas'+CAST(GETDATE() AS VARCHAR(20))
            UPDATE AC
            SET 
                AC.codDiagnosticoPrincipal = CASE WHEN COALESCE(AC.codDiagnosticoPrincipal, '') = '' THEN DX.IDDX ELSE AC.codDiagnosticoPrincipal END,
                AC.tipoDiagnosticoPrincipal = DX.TIPODX,
                AC.codDiagnosticoRelacionado1 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado1, '') = '' OR AC.codDiagnosticoRelacionado1 = 'null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AC.codDiagnosticoRelacionado1 END,
                AC.codDiagnosticoRelacionado2 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado2, '') = '' OR AC.codDiagnosticoRelacionado2 = 'null' THEN IIF(COALESCE(DX.DX2,'')='' OR DX.DX2=COALESCE(DX.IDDX,''),'null',DX.DX2) ELSE AC.codDiagnosticoRelacionado2 END,
                AC.codDiagnosticoRelacionado3 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado3, '') = '' OR AC.codDiagnosticoRelacionado3 = 'null' THEN IIF(COALESCE(DX.DX3,'')='' OR DX.DX3=COALESCE(DX.IDDX,''),'null',DX.DX3) ELSE AC.codDiagnosticoRelacionado3 END
            FROM #CONSULTAS AC  INNER JOIN #DX DX ON AC.IDAFILIADO = DX.IDAFILIADO
            WHERE COALESCE(DX.IDDX, '') <> '' 
                OR COALESCE(DX.DX1, '') <> ''
                OR COALESCE(DX.DX2, '') <> ''
                OR COALESCE(DX.DX3, '') <> ''
            UPDATE #CONSULTAS SET tipoDiagnosticoPrincipal='01' WHERE LEN(COALESCE(tipoDiagnosticoPrincipal,''))<2
            UPDATE #CONSULTAS SET codDiagnosticoPrincipal='Z000' WHERE COALESCE(codDiagnosticoPrincipal,'')=''
            PRINT 'Diagnosticos medicamentos'+CAST(GETDATE() AS VARCHAR(20))
            UPDATE AM
            SET 
                AM.codDiagnosticoPrincipal = CASE WHEN COALESCE(AM.codDiagnosticoPrincipal, '') = '' THEN DX.IDDX ELSE AM.codDiagnosticoPrincipal END,
                AM.codDiagnosticoRelacionado = CASE WHEN COALESCE(AM.codDiagnosticoRelacionado, '') = '' OR AM.codDiagnosticoRelacionado = 'null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AM.codDiagnosticoRelacionado END
            FROM #MEDICAMENTOS AM  INNER JOIN #DX DX ON AM.IDAFILIADO = DX.IDAFILIADO
            WHERE COALESCE(DX.IDDX, '') <> '';
            UPDATE #MEDICAMENTOS SET codDiagnosticoPrincipal=UPPER(codDiagnosticoPrincipal),codDiagnosticoRelacionado=UPPER(IIF(LEN(codDiagnosticoRelacionado)<4,'null',codDiagnosticoRelacionado)) WHERE 1=1
            PRINT 'Diagnosticos procedimientos'
            UPDATE AP
            SET 
                AP.codDiagnosticoPrincipal = CASE WHEN COALESCE(AP.codDiagnosticoPrincipal, '') = '' THEN COALESCE(DX.IDDX,'Z008') ELSE AP.codDiagnosticoPrincipal END,
                AP.codDiagnosticoRelacionado = CASE WHEN COALESCE(AP.codDiagnosticoRelacionado, '') = '' OR AP.codDiagnosticoRelacionado = 'null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AP.codDiagnosticoRelacionado END
            FROM #PROCEDIMIENTOS AP  INNER JOIN #DX DX ON AP.IDAFILIADO = DX.IDAFILIADO
            WHERE COALESCE(DX.IDDX, '') <> '';
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal='Z000' WHERE (codDiagnosticoPrincipal IS NULL OR LEN(COALESCE(codDiagnosticoPrincipal,''))<4)
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoRelacionado='null' WHERE LEN(COALESCE(codDiagnosticoRelacionado,''))<4
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal=UPPER(codDiagnosticoPrincipal),codDiagnosticoRelacionado=UPPER(IIF(LEN(codDiagnosticoRelacionado)<4,'null',codDiagnosticoRelacionado)) WHERE 1=1
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal='R520' WHERE codDiagnosticoPrincipal='R500'
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoRelacionado='R520' WHERE codDiagnosticoRelacionado='R500'
            UPDATE #PROCEDIMIENTOS SET codComplicacion='R520' WHERE codComplicacion='R500'
            PRINT 'Diagnosticos procedimientos '+CAST(GETDATE() AS VARCHAR(20))
            PRINT 'URGENCIAS'
            UPDATE AU
            SET 
                AU.codDiagnosticoPrincipalE = CASE WHEN COALESCE(AU.codDiagnosticoPrincipalE, '') = '' THEN DX.IDDX ELSE AU.codDiagnosticoPrincipalE END,
                AU.codDiagnosticoRelacionadoE1 = CASE WHEN COALESCE(AU.codDiagnosticoRelacionadoE1, '') = '' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AU.codDiagnosticoRelacionadoE1 END,
                AU.codDiagnosticoRelacionadoE2 = CASE WHEN COALESCE(AU.codDiagnosticoRelacionadoE2, '') = '' THEN IIF(COALESCE(DX.DX2,'')='' OR DX.DX2=COALESCE(DX.IDDX,''),'null',DX.DX2) ELSE AU.codDiagnosticoRelacionadoE2 END,
                AU.codDiagnosticoRelacionadoE3 = CASE WHEN COALESCE(AU.codDiagnosticoRelacionadoE3, '') = '' THEN IIF(COALESCE(DX.DX3,'')='' OR DX.DX3=COALESCE(DX.IDDX,''),'null',DX.DX3) ELSE AU.codDiagnosticoRelacionadoE3 END
            FROM #URGENCIAS AU
            INNER JOIN #DX DX ON AU.IDAFILIADO = DX.IDAFILIADO
            WHERE COALESCE(DX.IDDX, '') <> '' 
                OR COALESCE(DX.DX1, '') <> ''
                OR COALESCE(DX.DX2, '') <> ''
                OR COALESCE(DX.DX3, '') <> ''
            PRINT 'HOSPITALIZACION'
            UPDATE AH
            SET 
                AH.codDiagnosticoPrincipal = CASE WHEN COALESCE(AH.codDiagnosticoPrincipal, '') = '' THEN DX.IDDX ELSE AH.codDiagnosticoPrincipal END,
                AH.codDiagnosticoPrincipalE = CASE WHEN COALESCE(AH.codDiagnosticoPrincipalE, '') = '' THEN COALESCE(DX.IDDX, AH.codDiagnosticoPrincipal) ELSE AH.codDiagnosticoPrincipalE END,
                AH.codDiagnosticoRelacionadoE1 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE1, '') = '' OR AH.codDiagnosticoRelacionadoE1 = 'null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AH.codDiagnosticoRelacionadoE1 END,
                AH.codDiagnosticoRelacionadoE2 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE2, '') = '' OR AH.codDiagnosticoRelacionadoE2 = 'null' THEN IIF(COALESCE(DX.DX2,'')='' OR DX.DX2=COALESCE(DX.IDDX,''),'null',DX.DX2) ELSE AH.codDiagnosticoRelacionadoE2 END,
                AH.codDiagnosticoRelacionadoE3 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE3, '') = '' OR AH.codDiagnosticoRelacionadoE3 = 'null' THEN IIF(COALESCE(DX.DX3,'')='' OR DX.DX3=COALESCE(DX.IDDX,''),'null',DX.DX3) ELSE AH.codDiagnosticoRelacionadoE3 END
            FROM #HOSPITALIZACION AH
            INNER JOIN #DX DX ON AH.IDAFILIADO = DX.IDAFILIADO
            WHERE COALESCE(DX.IDDX, '') <> '';
            -- Validaci�n RIPS: el dx relacionado no puede ser igual al dx principal
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado1 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado1) = UPPER(codDiagnosticoPrincipal)
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado2 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado2) = UPPER(codDiagnosticoPrincipal)
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoPrincipal)
            UPDATE #MEDICAMENTOS SET codDiagnosticoRelacionado = 'null'
            WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado) = UPPER(codDiagnosticoPrincipal)
            UPDATE #PROCEDIMIENTOS SET codDiagnosticoRelacionado = 'null'
            WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado) = UPPER(codDiagnosticoPrincipal)
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE1 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE1) = UPPER(codDiagnosticoPrincipalE)
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE2 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE2) = UPPER(codDiagnosticoPrincipalE)
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoPrincipalE)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE1 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE1) = UPPER(codDiagnosticoPrincipalE)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE2 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE2) = UPPER(codDiagnosticoPrincipalE)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoPrincipalE,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoPrincipalE)
            -- Validaci�n RIPS: dx relacionados de consulta no pueden repetirse entre s�
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado2 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado2) = UPPER(codDiagnosticoRelacionado1)
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoRelacionado1)
            UPDATE #CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoRelacionado2)
            -- Validaci�n RIPS: dx relacionados de egreso no pueden repetirse entre s�
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE2 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE2) = UPPER(codDiagnosticoRelacionadoE1)
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoRelacionadoE1)
            UPDATE #URGENCIAS SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoRelacionadoE2)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE2 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE2) = UPPER(codDiagnosticoRelacionadoE1)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE1,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoRelacionadoE1)
            UPDATE #HOSPITALIZACION SET codDiagnosticoRelacionadoE3 = 'null'
            WHERE COALESCE(codDiagnosticoRelacionadoE3,'') NOT IN ('','null')
                AND COALESCE(codDiagnosticoRelacionadoE2,'') NOT IN ('','null')
                AND UPPER(codDiagnosticoRelacionadoE3) = UPPER(codDiagnosticoRelacionadoE2)
        END
        PRINT 'TERMINO LA ACTUALIZAR DX  '+CAST(GETDATE() AS VARCHAR(20))
        SELECT @VALORCOPAGOACU=COALESCE(SUM(valorPagoModerador),0) FROM #CONSULTAS
        SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #PROCEDIMIENTOS
        SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #MEDICAMENTOS
        SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #OTROSSER
        IF ABS(@VALORCOPAGO-@VALORCOPAGOACU)<1000
        BEGIN
            DECLARE @CONSE INT
            DECLARE @DIF INT
            SELECT TOP 1 @CONSE=id FROM #CONSULTAS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
            if COALESCE(@CONSE,0)>0
            BEGIN
                UPDATE #CONSULTAS SET valorPagoModerador=valorPagoModerador+(@VALORCOPAGO-@VALORCOPAGOACU)   WHERE id=@CONSE 
            END
            ELSE
            BEGIN
                SELECT TOP 1 @CONSE=id FROM #PROCEDIMIENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
                if COALESCE(@CONSE,0)>0
                BEGIN
                    UPDATE #PROCEDIMIENTOS SET valorPagoModerador=valorPagoModerador+(@VALORCOPAGO-@VALORCOPAGOACU)   WHERE id=@CONSE 
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @CONSE=id FROM #MEDICAMENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
                    if COALESCE(@CONSE,0)>0
                    BEGIN
                        UPDATE #MEDICAMENTOS SET valorPagoModerador=valorPagoModerador+(@VALORCOPAGO-@VALORCOPAGOACU)   WHERE id=@CONSE 
                    END   
                    ELSE
                    BEGIN
                        SELECT TOP 1 @CONSE=id FROM #OTROSSER WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
                        if COALESCE(@CONSE,0)>0
                        BEGIN
                            UPDATE #OTROSSER SET valorPagoModerador=valorPagoModerador+(@VALORCOPAGO-@VALORCOPAGOACU)   WHERE id=@CONSE 
                        END  
                    END
                END
            END
        END
        IF COALESCE(@CPROPIO,0)=1
        BEGIN
            UPDATE #CONSULTAS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
            UPDATE #PROCEDIMIENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
            UPDATE #MEDICAMENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
            UPDATE #OTROSSER SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
        END
        ELSE
        BEGIN
            UPDATE #CONSULTAS SET conceptoRecaudo=@conceptoRecaudo WHERE valorPagoModerador>=0 AND conceptoRecaudo='05'
            UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=@conceptoRecaudo WHERE valorPagoModerador>=0 AND conceptoRecaudo='05'
            UPDATE #MEDICAMENTOS SET conceptoRecaudo=@conceptoRecaudo WHERE valorPagoModerador>=0 AND conceptoRecaudo='05'
            UPDATE #OTROSSER SET conceptoRecaudo=@conceptoRecaudo WHERE valorPagoModerador>=0 AND conceptoRecaudo='05'

            UPDATE #CONSULTAS SET conceptoRecaudo='05' WHERE valorPagoModerador<=0 AND conceptoRecaudo<>'05'
            UPDATE #PROCEDIMIENTOS SET conceptoRecaudo='05' WHERE valorPagoModerador<=0 AND conceptoRecaudo<>'05'
            UPDATE #MEDICAMENTOS SET conceptoRecaudo='05' WHERE valorPagoModerador<=0 AND conceptoRecaudo<>'05'
            UPDATE #OTROSSER SET conceptoRecaudo='05' WHERE valorPagoModerador<=0 AND conceptoRecaudo<>'05'

            --reviso la dian por si acaso
            DECLARE @ESMODERADORAENFTR VARCHAR(3)=NULL
            DECLARE @ITEM_FDIANR INT
            SELECT @ITEM_FDIANR = MAX(ITEM)
            FROM  FDIANR 
            WHERE CNSDOCUMENTO =  @CNSFCT  --'0100011890'-- @CNSFCT 
            AND   TIPO = 'FV'
            AND   METODO = 'SendBillSync'

            IF EXISTS( SELECT * 
                       FROM  FDIANR 
                       WHERE ITEM = @ITEM_FDIANR
                       AND   COALESCE(TEXTO_SOLICITUD,'') != '' 
                       AND   CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>',TEXTO_SOLICITUD) > 0  
                       )
            BEGIN
               SELECT @ESMODERADORAENFTR = '02'
            END
            IF EXISTS( SELECT top 1 * 
                        FROM  FDIANR 
                        WHERE ITEM = @ITEM_FDIANR
                        AND   COALESCE(TEXTO_SOLICITUD,'') != '' 
                        AND   CHARINDEX('<cbc:ID schemeID="01">COPAGO</cbc:ID>',TEXTO_SOLICITUD) > 0  
                        )
            BEGIN
               IF @ESMODERADORAENFTR IS NULL
               BEGIN
                  SELECT @ESMODERADORAENFTR = '01'
               END
               ELSE
               BEGIN
                   SELECT @ESMODERADORAENFTR = 'XX'
               END
            END

            IF EXISTS( SELECT top 1 * 
                        FROM  FDIANR 
                        WHERE ITEM = @ITEM_FDIANR
                        AND   COALESCE(TEXTO_SOLICITUD,'') != '' 
                        AND   CHARINDEX('<cbc:ID schemeID="03">PAGOS COMPARTIDOS EN PLANES VOLUNTARIOS DE SALUD</cbc:ID>',TEXTO_SOLICITUD) > 0  
                        )
            BEGIN
               IF @ESMODERADORAENFTR IS NULL
               BEGIN
                  SELECT @ESMODERADORAENFTR = '03'
               END
               ELSE
               BEGIN
                   SELECT @ESMODERADORAENFTR = 'XX'
               END
            END
            IF @ESMODERADORAENFTR IS NOT NULL OR @ESMODERADORAENFTR<>'XX'
            BEGIN
               UPDATE #CONSULTAS SET conceptoRecaudo=@ESMODERADORAENFTR WHERE valorPagoModerador>=0 AND conceptoRecaudo<>@ESMODERADORAENFTR
               UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=@ESMODERADORAENFTR WHERE valorPagoModerador>=0 AND conceptoRecaudo<>@ESMODERADORAENFTR
               UPDATE #MEDICAMENTOS SET conceptoRecaudo=@ESMODERADORAENFTR WHERE valorPagoModerador>=0 AND conceptoRecaudo<>@ESMODERADORAENFTR
               UPDATE #OTROSSER SET conceptoRecaudo=@ESMODERADORAENFTR WHERE valorPagoModerador>=0 AND conceptoRecaudo<>@ESMODERADORAENFTR             
            END

        END
        UPDATE #CONSULTAS SET vrServicio=0 WHERE 1=1
        UPDATE #PROCEDIMIENTOS SET vrServicio=0 WHERE 1=1
        UPDATE #MEDICAMENTOS SET vrServicio=0,vrUnitMedicamento=0 WHERE 1=1
        UPDATE #OTROSSER SET vrServicio=0, vrUnitOS=0 WHERE 1=1

        /* RVC014: fechas de servicio dentro del periodo de facturacion (FECHACAP_INI / FECHACAP_FIN) */
        IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL
        BEGIN
            PRINT N'RIPS RVC014: ajuste fechas servicio al periodo '
                + CONVERT(VARCHAR(10), CAST(@FECHAINICAP AS DATE), 23)
                + N' - '
                + CONVERT(VARCHAR(10), CAST(@FECHAFINCAP AS DATE), 23);

            UPDATE #CONSULTAS
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #CONSULTAS1
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #PROCEDIMIENTOS
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #PROCEDIMIENTOS1
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #MEDICAMENTOS
            SET fechaDispensAdmon = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaDispensAdmon, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaDispensAdmon, '') NOT IN ('', 'null');

            UPDATE #OTROSSER
            SET fechaSuministroTecnologia = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaSuministroTecnologia, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaSuministroTecnologia, '') NOT IN ('', 'null');

            UPDATE #URGENCIAS
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #URGENCIAS
            SET fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaEgreso, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaEgreso, '') NOT IN ('', 'null');

            UPDATE #HOSPITALIZACION
            SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

            UPDATE #HOSPITALIZACION
            SET fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaEgreso, @FECHAINICAP, @FECHAFINCAP)
            WHERE COALESCE(fechaEgreso, '') NOT IN ('', 'null');
        END

        PRINT 'TERMINE DE PREPARAR LOS DATOS '+CAST(GETDATE() AS VARCHAR(20))
    END
    PRINT 'TERMINE DE PREPARAR LOS DATOS'
    DECLARE @IDAFILIADOANT VARCHAR(20)=''
    DECLARE @IDAFILIADO VARCHAR(20)
    DECLARE @CNSX INT 
    DECLARE @ID INT 
    INSERT INTO #CONSULTAS2 (codPrestador,	consecutivo,	IDAFILIADO,	fechaInicioAtencion,	numAutorizacion ,	codConsulta ,
                                  modalidadGrupoServicioTecSal ,	grupoServicios ,	codServicio,	finalidadTecnologiaSalud ,	causaMotivoAtencion ,
                                  codDiagnosticoPrincipal ,	codDiagnosticoRelacionado1,	codDiagnosticoRelacionado2,	codDiagnosticoRelacionado3,	tipoDiagnosticoPrincipal ,
                                  vrServicio ,	tipoPagoModerador ,	tipoDocumentoIdentificacion ,	numDocumentoIdentificacion ,	conceptoRecaudo ,	valorPagoModerador ,	numFEVPagoModerador ,
                                  usuarioId  ,   ID ,   xconsecutivo )
    SELECT codPrestador,	consecutivo,	IDAFILIADO,	fechaInicioAtencion,	numAutorizacion ,	codConsulta ,
        modalidadGrupoServicioTecSal ,	grupoServicios ,	codServicio,	finalidadTecnologiaSalud ,	causaMotivoAtencion ,
        codDiagnosticoPrincipal ,	codDiagnosticoRelacionado1,	codDiagnosticoRelacionado2,	codDiagnosticoRelacionado3,	tipoDiagnosticoPrincipal ,
        vrServicio ,	tipoPagoModerador ,	tipoDocumentoIdentificacion ,	numDocumentoIdentificacion ,	conceptoRecaudo ,	valorPagoModerador ,	numFEVPagoModerador ,
        usuarioId  ,   ID , 
        ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #CONSULTAS
    --PROCEDIMIENTOS
    INSERT INTO #PROCEDIMIENTOS2(	codPrestador,	IDAFILIADO,	CONSECUTIVO,	fechaInicioAtencion,	idMIPRES,	numAutorizacion,	codProcedimiento,
    viaIngresoServicioSalud,	modalidadGrupoServicioTecSal,	grupoServicios,	codServicio,	finalidadTecnologiaSalud ,	tipoDocumentoIdentificacion,
    numDocumentoIdentificacion,	codDiagnosticoPrincipal,	codDiagnosticoRelacionado ,	codComplicacion,	vrServicio, 	conceptoRecaudo ,	tipoPagoModerador,
    valorPagoModerador,	numFEVPagoModerador,	usuarioId,   ID ,   xconsecutivo)
    SELECT codPrestador,	IDAFILIADO,	CONSECUTIVO,	fechaInicioAtencion,	idMIPRES,	numAutorizacion,	codProcedimiento,
    viaIngresoServicioSalud,	modalidadGrupoServicioTecSal,	grupoServicios,	codServicio,	finalidadTecnologiaSalud ,	tipoDocumentoIdentificacion,
    numDocumentoIdentificacion,	codDiagnosticoPrincipal,	codDiagnosticoRelacionado ,	codComplicacion,	vrServicio, 	conceptoRecaudo ,	tipoPagoModerador,
    valorPagoModerador,	numFEVPagoModerador,	usuarioId,   ID ,   ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #PROCEDIMIENTOS
    PRINT'--MEDICAMENTOS'

    INSERT INTO #MEDICAMENTOS2(codPrestador ,	numAutorizacion, IDAFILIADO ,	CONSECUTIVO,	idMIPRES ,	fechaDispensAdmon,	codDiagnosticoPrincipal ,	codDiagnosticoRelacionado,
                 tipoMedicamento,	codTecnologiaSalud,	nomTecnologiaSalud,	concentracionMedicamento ,	unidadMedida ,	formaFarmaceutica,	unidadMinDispensa ,
                 cantidadMedicamento,	diasTratamiento,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,	vrUnitMedicamento,	vrServicio,	conceptoRecaudo,
                 tipoPagoModerador,	valorPagoModerador,	numFEVPagoModerador ,	usuarioId ,   ID  ,   xconsecutivo)
    SELECT codPrestador , numAutorizacion,	IDAFILIADO ,	CONSECUTIVO,	idMIPRES ,	fechaDispensAdmon,	codDiagnosticoPrincipal ,	codDiagnosticoRelacionado,
         tipoMedicamento,	codTecnologiaSalud,	nomTecnologiaSalud,	concentracionMedicamento ,CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,2), unidadMedida)))unidadMedida ,
         formaFarmaceutica,	unidadMinDispensa ,
         CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,2), cantidadMedicamento)))cantidadMedicamento,	diasTratamiento,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,	vrUnitMedicamento,	vrServicio,	conceptoRecaudo,
         tipoPagoModerador,	valorPagoModerador,	numFEVPagoModerador ,	usuarioId ,   ID  ,    ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #MEDICAMENTOS

    PRINT'--OTROS SERVICIOS'
    INSERT INTO #OTROSSER2(codPrestador,	IDAFILIADO ,	CONSECUTIVO,	numAutorizacion,	idMIPRES,	fechaSuministroTecnologia,	tipoOS,	
              codTecnologiaSalud,nomTecnologiaSalud ,	cantidadOS,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,
              vrUnitOS, 	vrServicio, 	conceptoRecaudo,	tipoPagoModerador, valorPagoModerador,	numFEVPagoModerador,	usuarioId ,
              ID , xconsecutivo)
    SELECT codPrestador,	IDAFILIADO ,	CONSECUTIVO,	numAutorizacion,	idMIPRES,	fechaSuministroTecnologia,	tipoOS,	
          codTecnologiaSalud,nomTecnologiaSalud ,	cantidadOS,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,
          vrUnitOS, 	vrServicio, 	conceptoRecaudo,	tipoPagoModerador, valorPagoModerador,	numFEVPagoModerador,	usuarioId ,
          ID , ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #OTROSSER
    --OTROS HOSPITALIZACION
    SELECT @ID=0,@IDAFILIADOANT=''
    DECLARE PG_CURSOR CURSOR FOR 
    SELECT ID,IDAFILIADO FROM #HOSPITALIZACION
    ORDER BY IDAFILIADO ASC
    OPEN PG_CURSOR    
    FETCH NEXT FROM PG_CURSOR    
    INTO @ID, @IDAFILIADO
    WHILE @@FETCH_STATUS = 0    
    BEGIN 
        IF @IDAFILIADOANT<>@IDAFILIADO
        BEGIN
            SELECT @CNSX=1,@IDAFILIADOANT=@IDAFILIADO
        END
        ELSE
        BEGIN
            SELECT @CNSX = @CNSX+1
        END
        UPDATE #HOSPITALIZACION SET xconsecutivo=@CNSX WHERE ID=@ID
        FETCH NEXT FROM PG_CURSOR    
        INTO @ID, @IDAFILIADO
    END
    CLOSE PG_CURSOR
    DEALLOCATE PG_CURSOR
    --OTROS URGENCIAS
    SELECT @ID=0,@IDAFILIADOANT=''
    DECLARE PG_CURSOR CURSOR FOR 
    SELECT ID,IDAFILIADO FROM #URGENCIAS
    ORDER BY IDAFILIADO ASC
    OPEN PG_CURSOR    
    FETCH NEXT FROM PG_CURSOR    
    INTO @ID, @IDAFILIADO
    WHILE @@FETCH_STATUS = 0    
    BEGIN 
        IF @IDAFILIADOANT<>@IDAFILIADO
        BEGIN
            SELECT @CNSX=1,@IDAFILIADOANT=@IDAFILIADO
        END
        ELSE
        BEGIN
            SELECT @CNSX = @CNSX+1
        END
        UPDATE #URGENCIAS SET xconsecutivo=@CNSX WHERE ID=@ID
        FETCH NEXT FROM PG_CURSOR    
        INTO @ID, @IDAFILIADO
    END
    CLOSE PG_CURSOR
    DEALLOCATE PG_CURSOR
    --OTROS RECIEN NACIDOS
    SELECT @ID=0,@IDAFILIADOANT=''
    DECLARE PG_CURSOR CURSOR FOR 
    SELECT ID,IDAFILIADO FROM #RECIEN
    ORDER BY IDAFILIADO ASC
    OPEN PG_CURSOR    
    FETCH NEXT FROM PG_CURSOR    
    INTO @ID, @IDAFILIADO
    WHILE @@FETCH_STATUS = 0    
    BEGIN 
        IF @IDAFILIADOANT<>@IDAFILIADO
        BEGIN
            SELECT @CNSX=1,@IDAFILIADOANT=@IDAFILIADO
        END
        ELSE
        BEGIN
            SELECT @CNSX = @CNSX+1
        END
        UPDATE #RECIEN SET xconsecutivo=@CNSX WHERE ID=@ID
        FETCH NEXT FROM PG_CURSOR    
        INTO @ID, @IDAFILIADO
    END
    CLOSE PG_CURSOR
    DEALLOCATE PG_CURSOR
    IF EXISTS(SELECT * FROM #PROCEDIMIENTOS2 WHERE tipoDocumentoIdentificacion IS NULL)
    BEGIN
        UPDATE #PROCEDIMIENTOS2 SET tipoDocumentoIdentificacion=AFI.TIPO_DOC,numDocumentoIdentificacion=AFI.DOCIDAFILIADO
        FROM #PROCEDIMIENTOS2 AP INNER JOIN AFI ON AP.IDAFILIADO=AFI.IDAFILIADO
        WHERE AP.tipoDocumentoIdentificacion IS NULL
    END

    /* RVC014: segundo pase sobre tablas finales antes del FOR JSON */
    IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL
    BEGIN
        UPDATE #CONSULTAS2
        SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #PROCEDIMIENTOS2
        SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #MEDICAMENTOS2
        SET fechaDispensAdmon = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaDispensAdmon, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaDispensAdmon, '') NOT IN ('', 'null');

        UPDATE #OTROSSER2
        SET fechaSuministroTecnologia = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaSuministroTecnologia, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaSuministroTecnologia, '') NOT IN ('', 'null');

        UPDATE #URGENCIAS
        SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #URGENCIAS
        SET fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaEgreso, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaEgreso, '') NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
        SET fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaInicioAtencion, '') NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
        SET fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(fechaEgreso, @FECHAINICAP, @FECHAFINCAP)
        WHERE COALESCE(fechaEgreso, '') NOT IN ('', 'null');

        UPDATE #PROCEDIMIENTOS
        SET viaIngresoServicioSalud = DBO.FNK_RIPS_VIA_INGRESO(viaIngresoServicioSalud)
        WHERE COALESCE(viaIngresoServicioSalud, '') NOT IN ('', 'null');

        UPDATE #PROCEDIMIENTOS2
        SET viaIngresoServicioSalud = DBO.FNK_RIPS_VIA_INGRESO(viaIngresoServicioSalud)
        WHERE COALESCE(viaIngresoServicioSalud, '') NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
        SET viaIngresoServicioSalud = DBO.FNK_RIPS_VIA_INGRESO(viaIngresoServicioSalud)
        WHERE COALESCE(viaIngresoServicioSalud, '') NOT IN ('', 'null');
    END

    /*
       Normalización y reporte RIPS antes de serializar el JSON.
       Los rechazos no corregibles se validan previamente en
       SPK_RIPS_PREVALIDAR_FTR_CAPI, antes de recolectar los servicios.
    */
    CREATE TABLE #REPORTE_RIPS (
        id INT IDENTITY(1,1) PRIMARY KEY,
        tipo VARCHAR(20) NOT NULL,
        regla VARCHAR(20) NULL,
        objeto VARCHAR(30) NOT NULL,
        idAfiliado VARCHAR(20) NULL,
        campo VARCHAR(60) NOT NULL,
        valorOriginal VARCHAR(100) NULL,
        valorCorregido VARCHAR(100) NULL,
        detalle VARCHAR(500) NOT NULL
    );

    DECLARE @MENSAJE_VALIDACION_RIPS NVARCHAR(2047) = N'';

    -- Normalizaciones seguras de identificación: no se modifica el valor clínico,
    -- solo espacios y la capitalización de los códigos de documento.
    UPDATE U
       SET tipoDocumentoIdentificacion = UPPER(LTRIM(RTRIM(U.tipoDocumentoIdentificacion)))
    OUTPUT 'CORREGIDO', 'U01', 'usuarios', inserted.IDAFILIADO,
           'tipoDocumentoIdentificacion', deleted.tipoDocumentoIdentificacion,
           inserted.tipoDocumentoIdentificacion, 'Se normalizaron espacios o mayúsculas del tipo de documento.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #USUARIOS U
    WHERE U.tipoDocumentoIdentificacion <> UPPER(LTRIM(RTRIM(U.tipoDocumentoIdentificacion)));

    UPDATE U
       SET numDocumentoIdentificacion = LTRIM(RTRIM(U.numDocumentoIdentificacion))
    OUTPUT 'CORREGIDO', 'U02', 'usuarios', inserted.IDAFILIADO,
           'numDocumentoIdentificacion', deleted.numDocumentoIdentificacion,
           inserted.numDocumentoIdentificacion, 'Se eliminaron espacios externos del número de documento.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #USUARIOS U
    WHERE U.numDocumentoIdentificacion <> LTRIM(RTRIM(U.numDocumentoIdentificacion));

    -- SISPRO: numDocumentoIdentificacion solo admite letras y números (sin puntos, guiones, espacios, etc.).
    UPDATE U
       SET numDocumentoIdentificacion = LIMPIO.docLimpio
    OUTPUT 'CORREGIDO', 'U04', 'usuarios', inserted.IDAFILIADO,
           'numDocumentoIdentificacion', deleted.numDocumentoIdentificacion,
           inserted.numDocumentoIdentificacion, N'Se retiraron caracteres especiales del número de documento (solo letras y números).'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #USUARIOS U
    CROSS APPLY (
        SELECT DBO.FNK_LIMPIATEXTO(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                LTRIM(RTRIM(U.numDocumentoIdentificacion)),
                CHAR(9), ''), CHAR(10), ''), CHAR(13), ''), CHAR(160), ''), ' ', ''),
            'A-Za-z0-9') AS docLimpio
    ) LIMPIO
    WHERE U.numDocumentoIdentificacion <> LIMPIO.docLimpio;

    IF EXISTS (
        SELECT 1
        FROM #USUARIOS U
        CROSS APPLY (
            SELECT DBO.FNK_LIMPIATEXTO(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(U.numDocumentoIdentificacion)),
                    CHAR(9), ''), CHAR(10), ''), CHAR(13), ''), CHAR(160), ''), ' ', ''),
                'A-Za-z0-9') AS docLimpio
        ) LIMPIO
        WHERE NULLIF(LIMPIO.docLimpio, '') IS NULL
    )
        SET @MENSAJE_VALIDACION_RIPS += N'Número de documento de usuario vacío o inválido tras normalización. ';

    -- tipoUsuario fuera del catálogo RIPS (01-13): valor seguro 05 (no afiliado).
    UPDATE U
       SET tipoUsuario = '05'
    OUTPUT 'CORREGIDO', 'U03', 'usuarios', inserted.IDAFILIADO,
           'tipoUsuario', deleted.tipoUsuario,
           inserted.tipoUsuario, N'Tipo de usuario inválido reemplazado por 05 (no afiliado).'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #USUARIOS U
    WHERE TRY_CONVERT(INT, U.tipoUsuario) IS NULL
       OR LEN(LTRIM(RTRIM(U.tipoUsuario))) <> 2
       OR TRY_CONVERT(INT, U.tipoUsuario) NOT BETWEEN 1 AND 13;

    -- numAutorizacion vacío o con caracteres no permitidos ? 'null' (SISPRO rechaza cadenas vacías).
    UPDATE C
       SET numAutorizacion = LEFT(
               DBO.FNK_LIMPIATEXTO(
                   IIF(COALESCE(C.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', C.numAutorizacion),
                   'A-Z0-9-'),
               30)
    OUTPUT 'CORREGIDO', 'C01', 'consultas', inserted.IDAFILIADO,
           'numAutorizacion', deleted.numAutorizacion,
           inserted.numAutorizacion, N'Autorización vacía o inválida normalizada a null.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #CONSULTAS2 C
    WHERE C.numAutorizacion <> LEFT(
              DBO.FNK_LIMPIATEXTO(
                  IIF(COALESCE(C.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', C.numAutorizacion),
                  'A-Z0-9-'),
              30);

    UPDATE P
       SET numAutorizacion = LEFT(
               DBO.FNK_LIMPIATEXTO(
                   IIF(COALESCE(P.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', P.numAutorizacion),
                   'A-Z0-9-'),
               30)
    OUTPUT 'CORREGIDO', 'P01', 'procedimientos', inserted.IDAFILIADO,
           'numAutorizacion', deleted.numAutorizacion,
           inserted.numAutorizacion, N'Autorización vacía o inválida normalizada a null.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #PROCEDIMIENTOS2 P
    WHERE P.numAutorizacion <> LEFT(
              DBO.FNK_LIMPIATEXTO(
                  IIF(COALESCE(P.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', P.numAutorizacion),
                  'A-Z0-9-'),
              30);

    UPDATE O
       SET numAutorizacion = LEFT(
               DBO.FNK_LIMPIATEXTO(
                   IIF(COALESCE(O.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', O.numAutorizacion),
                   'A-Z0-9-'),
               30)
    OUTPUT 'CORREGIDO', 'O01', 'otrosServicios', inserted.IDAFILIADO,
           'numAutorizacion', deleted.numAutorizacion,
           inserted.numAutorizacion, N'Autorización vacía o inválida normalizada a null.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #OTROSSER2 O
    WHERE O.numAutorizacion <> LEFT(
              DBO.FNK_LIMPIATEXTO(
                  IIF(COALESCE(O.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', O.numAutorizacion),
                  'A-Z0-9-'),
              30);

    UPDATE H
       SET numAutorizacion = LEFT(
               DBO.FNK_LIMPIATEXTO(
                   IIF(COALESCE(H.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', H.numAutorizacion),
                   'A-Z0-9-'),
               30)
    OUTPUT 'CORREGIDO', 'H01', 'hospitalizacion', inserted.IDAFILIADO,
           'numAutorizacion', deleted.numAutorizacion,
           inserted.numAutorizacion, N'Autorización vacía o inválida normalizada a null.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #HOSPITALIZACION H
    WHERE H.numAutorizacion <> LEFT(
              DBO.FNK_LIMPIATEXTO(
                  IIF(COALESCE(H.numAutorizacion, 'null') IN ('', ' ', '  '), 'null', H.numAutorizacion),
                  'A-Z0-9-'),
              30);

    /* SISPRO rechaza numAutorizacion vacío: asegurar literal 'null' tras limpieza. */
    UPDATE #CONSULTAS2
       SET numAutorizacion = 'null'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(numAutorizacion, ''))), '') IS NULL;

    UPDATE #PROCEDIMIENTOS2
       SET numAutorizacion = 'null'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(numAutorizacion, ''))), '') IS NULL;

    UPDATE #OTROSSER2
       SET numAutorizacion = 'null'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(numAutorizacion, ''))), '') IS NULL;

    UPDATE #HOSPITALIZACION
       SET numAutorizacion = 'null'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(numAutorizacion, ''))), '') IS NULL;

    -- causaMotivoAtencion ausente o con longitud distinta de 2 ? 38 (enfermedad general).
    UPDATE C
       SET causaMotivoAtencion = '38'
    OUTPUT 'CORREGIDO', 'C02', 'consultas', inserted.IDAFILIADO,
           'causaMotivoAtencion', deleted.causaMotivoAtencion,
           inserted.causaMotivoAtencion, N'Causa externa inválida reemplazada por 38.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #CONSULTAS2 C
    WHERE NULLIF(LTRIM(RTRIM(C.causaMotivoAtencion)), '') IS NULL
       OR LEN(C.causaMotivoAtencion) <> 2;

    UPDATE U
       SET causaMotivoAtencion = '38'
    OUTPUT 'CORREGIDO', 'UR01', 'urgencias', inserted.IDAFILIADO,
           'causaMotivoAtencion', deleted.causaMotivoAtencion,
           inserted.causaMotivoAtencion, N'Causa externa inválida reemplazada por 38.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #URGENCIAS U
    WHERE NULLIF(LTRIM(RTRIM(U.causaMotivoAtencion)), '') IS NULL
       OR LEN(U.causaMotivoAtencion) <> 2;

    UPDATE H
       SET causaMotivoAtencion = '38'
    OUTPUT 'CORREGIDO', 'H03', 'hospitalizacion', inserted.IDAFILIADO,
           'causaMotivoAtencion', deleted.causaMotivoAtencion,
           inserted.causaMotivoAtencion, N'Causa externa inválida reemplazada por 38.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #HOSPITALIZACION H
    WHERE NULLIF(LTRIM(RTRIM(H.causaMotivoAtencion)), '') IS NULL
       OR LEN(H.causaMotivoAtencion) <> 2;

    -- modalidadGrupoServicioTecSal vacía ? 01.
    UPDATE C
       SET modalidadGrupoServicioTecSal = '01'
    OUTPUT 'CORREGIDO', 'C03', 'consultas', inserted.IDAFILIADO,
           'modalidadGrupoServicioTecSal', deleted.modalidadGrupoServicioTecSal,
           inserted.modalidadGrupoServicioTecSal, N'Modalidad de grupo vacía reemplazada por 01.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #CONSULTAS2 C
    WHERE NULLIF(LTRIM(RTRIM(C.modalidadGrupoServicioTecSal)), '') IS NULL
       OR LEN(C.modalidadGrupoServicioTecSal) <> 2;

    -- RVC014 urgencias/hospitalización: egreso en el último día del periodo ? hora 23:59.
    IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL
    BEGIN
        UPDATE U
           SET fechaEgreso = LEFT(U.fechaEgreso, 11) + '23:59'
        OUTPUT 'CORREGIDO', 'UR02', 'urgencias', inserted.IDAFILIADO,
               'fechaEgreso', deleted.fechaEgreso,
               inserted.fechaEgreso, N'Fecha de egreso acotada al periodo: hora ajustada a 23:59.'
          INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
        FROM #URGENCIAS U
        WHERE COALESCE(U.fechaEgreso, '') NOT IN ('', 'null')
          AND LEN(U.fechaEgreso) >= 16
          AND RIGHT(U.fechaEgreso, 5) <> '23:59'
          AND TRY_CONVERT(DATE, LEFT(U.fechaEgreso, 10), 23) = CAST(@FECHAFINCAP AS DATE);

        UPDATE H
           SET fechaEgreso = LEFT(H.fechaEgreso, 11) + '23:59'
        OUTPUT 'CORREGIDO', 'H04', 'hospitalizacion', inserted.IDAFILIADO,
               'fechaEgreso', deleted.fechaEgreso,
               inserted.fechaEgreso, N'Fecha de egreso acotada al periodo: hora ajustada a 23:59.'
          INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
        FROM #HOSPITALIZACION H
        WHERE COALESCE(H.fechaEgreso, '') NOT IN ('', 'null')
          AND LEN(H.fechaEgreso) >= 16
          AND RIGHT(H.fechaEgreso, 5) <> '23:59'
          AND TRY_CONVERT(DATE, LEFT(H.fechaEgreso, 10), 23) = CAST(@FECHAFINCAP AS DATE);
    END

    -- Finalidades sin valor válido: se aplica el valor seguro que el SP ya usa
    -- como predeterminado (12 para consulta y 16 para procedimiento).
    UPDATE C
       SET finalidadTecnologiaSalud = '12'
    OUTPUT 'CORREGIDO', 'C08', 'consultas', inserted.IDAFILIADO,
           'finalidadTecnologiaSalud', deleted.finalidadTecnologiaSalud,
           inserted.finalidadTecnologiaSalud, 'Finalidad inválida reemplazada por 12 (detección temprana de enfermedad general).'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #CONSULTAS2 C
    WHERE TRY_CONVERT(INT, C.finalidadTecnologiaSalud) IS NULL
       OR LEN(C.finalidadTecnologiaSalud) <> 2;

    UPDATE P
       SET finalidadTecnologiaSalud = '16'
    OUTPUT 'CORREGIDO', 'P10', 'procedimientos', inserted.IDAFILIADO,
           'finalidadTecnologiaSalud', deleted.finalidadTecnologiaSalud,
           inserted.finalidadTecnologiaSalud, 'Finalidad inválida reemplazada por 16 (tratamiento).'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #PROCEDIMIENTOS2 P
    WHERE TRY_CONVERT(INT, P.finalidadTecnologiaSalud) NOT BETWEEN 12 AND 44
       OR P.finalidadTecnologiaSalud = '21'
       OR LEN(P.finalidadTecnologiaSalud) <> 2;

    /* SISPRO RVG01: diagnosticos deben tener 4 caracteres cuando van informados. */
    UPDATE #CONSULTAS2
       SET codDiagnosticoPrincipal = 'null'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, ''))), '') IS NULL;

    UPDATE #CONSULTAS2
       SET codDiagnosticoPrincipal = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoPrincipal, '.', ''), ' ', ''))))
     WHERE codDiagnosticoPrincipal NOT IN ('', 'null');

    UPDATE #CONSULTAS2
       SET codDiagnosticoPrincipal = LEFT(codDiagnosticoPrincipal, 4)
     WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) > 4
       AND codDiagnosticoPrincipal NOT IN ('', 'null');

    UPDATE #CONSULTAS2
       SET codDiagnosticoPrincipal = 'null'
     WHERE codDiagnosticoPrincipal NOT IN ('', 'null')
       AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipal = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoPrincipal, '.', ''), ' ', ''))))
     WHERE codDiagnosticoPrincipal NOT IN ('', 'null');

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipalE = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoPrincipalE, '.', ''), ' ', ''))))
     WHERE codDiagnosticoPrincipalE NOT IN ('', 'null');

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipal = LEFT(codDiagnosticoPrincipal, 4)
     WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) > 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipalE = LEFT(codDiagnosticoPrincipalE, 4)
     WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, '')))) > 4
       AND codDiagnosticoPrincipalE NOT IN ('', 'null');

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipal = 'Z000'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, ''))), '') IS NULL
        OR LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipalE = codDiagnosticoPrincipal
     WHERE (NULLIF(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, ''))), '') IS NULL
        OR LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, '')))) <> 4)
       AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) = 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoPrincipalE = 'Z000'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, ''))), '') IS NULL
        OR LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoRelacionadoE1 = 'null'
     WHERE codDiagnosticoRelacionadoE1 NOT IN ('', 'null')
       AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE1, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoRelacionadoE2 = 'null'
     WHERE codDiagnosticoRelacionadoE2 NOT IN ('', 'null')
       AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE2, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codDiagnosticoRelacionadoE3 = 'null'
     WHERE codDiagnosticoRelacionadoE3 NOT IN ('', 'null')
       AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE3, '')))) <> 4;

    UPDATE #HOSPITALIZACION
       SET codComplicacion = 'null'
     WHERE codComplicacion NOT IN ('', 'null')
       AND LEN(LTRIM(RTRIM(COALESCE(codComplicacion, '')))) <> 4;

    UPDATE #URGENCIAS
       SET codDiagnosticoPrincipalE = 'Z000'
     WHERE NULLIF(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, ''))), '') IS NULL
        OR LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, '')))) <> 4;

    -- Homologa la vía y, si no existe dato aprovechable, aplica 01, que es el
    -- valor predeterminado utilizado históricamente por este generador.
    UPDATE P
       SET viaIngresoServicioSalud = V.viaRips
    OUTPUT 'CORREGIDO', 'P06', 'procedimientos', inserted.IDAFILIADO,
           'viaIngresoServicioSalud', deleted.viaIngresoServicioSalud,
           inserted.viaIngresoServicioSalud, 'Vía de ingreso homologada mediante FNK_RIPS_VIA_INGRESO.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #PROCEDIMIENTOS2 P
    CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(P.viaIngresoServicioSalud) AS viaRips) V
    WHERE NULLIF(LTRIM(RTRIM(P.viaIngresoServicioSalud)), '') IS NOT NULL
      AND P.viaIngresoServicioSalud <> 'null'
      AND NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NOT NULL
      AND V.viaRips <> 'null'
      AND P.viaIngresoServicioSalud <> V.viaRips;

    UPDATE H
       SET viaIngresoServicioSalud = V.viaRips
    OUTPUT 'CORREGIDO', 'H02', 'hospitalizacion', inserted.IDAFILIADO,
           'viaIngresoServicioSalud', deleted.viaIngresoServicioSalud,
           inserted.viaIngresoServicioSalud, 'Vía de ingreso homologada mediante FNK_RIPS_VIA_INGRESO.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #HOSPITALIZACION H
    CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(H.viaIngresoServicioSalud) AS viaRips) V
    WHERE NULLIF(LTRIM(RTRIM(H.viaIngresoServicioSalud)), '') IS NOT NULL
      AND H.viaIngresoServicioSalud <> 'null'
      AND NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NOT NULL
      AND V.viaRips <> 'null'
      AND H.viaIngresoServicioSalud <> V.viaRips;

    UPDATE P
       SET viaIngresoServicioSalud = '01'
    OUTPUT 'CORREGIDO', 'P06', 'procedimientos', inserted.IDAFILIADO,
           'viaIngresoServicioSalud', deleted.viaIngresoServicioSalud,
           inserted.viaIngresoServicioSalud, 'Vía de ingreso ausente o no homologable reemplazada por 01; verificar el registro asistencial.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #PROCEDIMIENTOS2 P
    CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(P.viaIngresoServicioSalud) AS viaRips) V
    WHERE NULLIF(LTRIM(RTRIM(P.viaIngresoServicioSalud)), '') IS NULL
       OR P.viaIngresoServicioSalud = 'null'
       OR NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NULL
       OR V.viaRips = 'null'
       OR LEN(V.viaRips) <> 2
       OR V.viaRips LIKE '%[^0-9]%';

    UPDATE H
       SET viaIngresoServicioSalud = '01'
    OUTPUT 'CORREGIDO', 'H02', 'hospitalizacion', inserted.IDAFILIADO,
           'viaIngresoServicioSalud', deleted.viaIngresoServicioSalud,
           inserted.viaIngresoServicioSalud, 'Vía de ingreso ausente o no homologable reemplazada por 01; verificar el registro asistencial.'
      INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
    FROM #HOSPITALIZACION H
    CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(H.viaIngresoServicioSalud) AS viaRips) V
    WHERE NULLIF(LTRIM(RTRIM(H.viaIngresoServicioSalud)), '') IS NULL
       OR H.viaIngresoServicioSalud = 'null'
       OR NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NULL
       OR V.viaRips = 'null'
       OR LEN(V.viaRips) <> 2
       OR V.viaRips LIKE '%[^0-9]%';

    -- Bloqueo solo si, tras homologar y aplicar 01, la vía sigue sin ser un código RIPS válido.
    IF EXISTS (
        SELECT 1
        FROM #PROCEDIMIENTOS2 P
        CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(P.viaIngresoServicioSalud) AS viaRips) V
        WHERE NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NULL
           OR V.viaRips = 'null'
           OR LEN(V.viaRips) <> 2
           OR V.viaRips LIKE '%[^0-9]%'
        UNION ALL
        SELECT 1
        FROM #HOSPITALIZACION H
        CROSS APPLY (SELECT DBO.FNK_RIPS_VIA_INGRESO(H.viaIngresoServicioSalud) AS viaRips) V
        WHERE NULLIF(LTRIM(RTRIM(V.viaRips)), '') IS NULL
           OR V.viaRips = 'null'
           OR LEN(V.viaRips) <> 2
           OR V.viaRips LIKE '%[^0-9]%'
    )
        SET @MENSAJE_VALIDACION_RIPS += N'Vía de ingreso inválida: no se pudo homologar a un código RIPS de dos posiciones. ';

    IF @MENSAJE_VALIDACION_RIPS <> N''
    BEGIN
        INSERT INTO #REPORTE_RIPS(tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle)
        VALUES ('ADVERTENCIA', 'VALIDACION', 'rips', NULL, 'prevalidacion', NULL, NULL, @MENSAJE_VALIDACION_RIPS);
    END

    IF EXISTS (SELECT 1 FROM #REPORTE_RIPS)
    BEGIN
        SELECT @REPORTE_VALIDACION = (
            SELECT tipo, regla, objeto, idAfiliado, campo, valorOriginal, valorCorregido, detalle
            FROM #REPORTE_RIPS
            ORDER BY id
            FOR JSON PATH
        );
    END

    IF @TIPOCAP<>1
    BEGIN
        SET @json = (
        SELECT 
            rips = (
                SELECT 
                    numDocumentoIdObligado =  @numDocumentoIdObligado,
                    numFactura = CASE WHEN COALESCE(@TIPOCAP,0)=2 THEN @N_FACTURAANT ELSE @N_FACTURA END,
                    tipoNota ='null',
                    numNota = 'null',
                    usuarios = (
                        SELECT 
                            tipoDocumentoIdentificacion = u.tipoDocumentoIdentificacion,
                            numDocumentoIdentificacion = DBO.FNK_LIMPIATEXTO(
                                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                    LTRIM(RTRIM(u.numDocumentoIdentificacion)),
                                    CHAR(9), ''), CHAR(10), ''), CHAR(13), ''), CHAR(160), ''), ' ', ''),
                                'A-Za-z0-9'),
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
                                    consultas = (
                                        SELECT 
                                            c.codPrestador,
                                            fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(c.fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP),
                                            c.numAutorizacion,
                                            c.codConsulta,
                                            c.modalidadGrupoServicioTecSal,
                                            c.grupoServicios,
                                            c.codServicio,
                                            c.finalidadTecnologiaSalud,
                                            c.causaMotivoAtencion,
                                            c.codDiagnosticoPrincipal,
                                            ISNULL( NULLIF(c.codDiagnosticoRelacionado1,''), 'null') codDiagnosticoRelacionado1,
                                            ISNULL( NULLIF(c.codDiagnosticoRelacionado2,''), 'null') codDiagnosticoRelacionado2,
                                            ISNULL( NULLIF(c.codDiagnosticoRelacionado3,''), 'null') codDiagnosticoRelacionado3,
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoRelacionado1CIE11 = 'null',
                                            nomCodDiagnosticoRelacionado1CIE11 = 'null',
                                            codDiagnosticoRelacionado2CIE11 = 'null',
                                            nomCodDiagnosticoRelacionado2CIE11 = 'null',
                                            codDiagnosticoRelacionado3CIE11 = 'null',
                                            nomCodDiagnosticoRelacionado3CIE11 = 'null',
                                            codigoVIDA = 'null',
                                            c.tipoDiagnosticoPrincipal,
                                            c.tipoDocumentoIdentificacion,
                                            c.numDocumentoIdentificacion,
                                            c.vrServicio,
                                            c.conceptoRecaudo,
                                            c.valorPagoModerador,
                                            c.numFEVPagoModerador,
                                            consecutivo = xconsecutivo  
                                        FROM #CONSULTAS2 c
                                        WHERE c.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    procedimientos = (
                                        SELECT 
                                            p.codPrestador,
                                            fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(p.fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP),
                                            p.idMIPRES,
                                            p.numAutorizacion,
                                            p.codProcedimiento,
                                            viaIngresoServicioSalud = DBO.FNK_RIPS_VIA_INGRESO(p.viaIngresoServicioSalud),
                                            p.modalidadGrupoServicioTecSal,
                                            p.grupoServicios,
                                            p.codServicio,
                                            p.finalidadTecnologiaSalud,
                                            p.tipoDocumentoIdentificacion,
                                            p.numDocumentoIdentificacion,
                                            p.codDiagnosticoPrincipal,
                                            p.codDiagnosticoRelacionado,
                                            p.codComplicacion,
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoRelacionadoCIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoCIE11 = 'null',
                                            codComplicacionCIE11 = 'null',
                                            nomCodComplicacionCIE11 = 'null',
                                            codigoVIDA = 'null',
                                            p.vrServicio,
                                            p.conceptoRecaudo,
                                            p.valorPagoModerador,
                                            p.numFEVPagoModerador,
                                            consecutivo = xconsecutivo  
                                        FROM #PROCEDIMIENTOS2 p
                                        WHERE p.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    urgencias = (
                                        SELECT 
                                            ur.codPrestador,
                                            fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(ur.fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP),
                                            ur.causaMotivoAtencion,
                                            ur.codDiagnosticoPrincipal,
                                            ur.codDiagnosticoPrincipalE,
                                            codDiagnosticoRelacionadoE1=ISNULL(NULLIF(ur.codDiagnosticoRelacionadoE1,''), 'null'),
                                            codDiagnosticoRelacionadoE2=ISNULL(NULLIF(ur.codDiagnosticoRelacionadoE2,''), 'null'),
                                            codDiagnosticoRelacionadoE3=ISNULL(NULLIF(ur.codDiagnosticoRelacionadoE3,''), 'null'),
                                            ur.condicionDestinoUsuarioEgreso,
                                            codDiagnosticoCausaMuerte=ISNULL(NULLIF(ur.codDiagnosticoCausaMuerte,''), 'null'),
                                            fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(ur.fechaEgreso, @FECHAINICAP, @FECHAFINCAP),
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoPrincipalECIE11 = 'null',
                                            nomCodDiagnosticoPrincipalECIE11 = 'null',
                                            codDiagnosticoRelacionadoE1CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE1CIE11 = 'null',
                                            codDiagnosticoRelacionadoE2CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE2CIE11 = 'null',
                                            codDiagnosticoRelacionadoE3CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE3CIE11 = 'null',
                                            codDiagnosticoCausaMuerteCIE11 = 'null',
                                            nomCodDiagnosticoCausaMuerteCIE11 = 'null',
                                            codigoVIDA = 'null',
                                            consecutivo =xconsecutivo  
                                        FROM #URGENCIAS ur
                                        WHERE ur.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    hospitalizacion = (
                                        SELECT 
                                            h.codPrestador,
                                            viaIngresoServicioSalud = DBO.FNK_RIPS_VIA_INGRESO(COALESCE(h.viaIngresoServicioSalud, '01')),
                                            fechaInicioAtencion = DBO.FNK_RIPS_FECHA_EN_PERIODO(h.fechaInicioAtencion, @FECHAINICAP, @FECHAFINCAP),
                                            h.numAutorizacion,
                                            h.causaMotivoAtencion,
                                            ISNULL(NULLIF(h.codDiagnosticoPrincipal, ''), 'null') codDiagnosticoPrincipal,
                                            ISNULL( NULLIF(h.codDiagnosticoPrincipalE,''), 'null') codDiagnosticoPrincipalE,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE1,''), 'null') codDiagnosticoRelacionadoE1,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE2,''), 'null') codDiagnosticoRelacionadoE2,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE3,''), 'null') codDiagnosticoRelacionadoE3,
                                            ISNULL( NULLIF(h.codComplicacion,''), 'null') codComplicacion,
                                            ISNULL( NULLIF(h.codDiagnosticoCausaMuerte,''), 'null') codDiagnosticoCausaMuerte,
                                            h.condicionDestinoUsuarioEgreso,
                                            fechaEgreso = DBO.FNK_RIPS_FECHA_EN_PERIODO(h.fechaEgreso, @FECHAINICAP, @FECHAFINCAP),
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoPrincipalECIE11 = 'null',
                                            nomCodDiagnosticoPrincipalECIE11 = 'null',
                                            codDiagnosticoRelacionadoE1CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE1CIE11 = 'null',
                                            codDiagnosticoRelacionadoE2CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE2CIE11 = 'null',
                                            codDiagnosticoRelacionadoE3CIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoE3CIE11 = 'null',
                                            codComplicacionCIE11 = 'null',
                                            nomCodComplicacionCIE11 = 'null',
                                            codDiagnosticoCausaMuerteCIE11 = 'null',
                                            nomCodDiagnosticoCausaMuerteCIE11 = 'null',
                                            codigoVIDA = 'null',
                                            consecutivo = xconsecutivo  
                                        FROM #HOSPITALIZACION h
                                        WHERE h.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    recienNacidos = (
                                        SELECT 
                                            r.codPrestador,
                                            r.tipoDocumentoIdentificacion,
                                            r.numDocumentoIdentificacion,
                                            r.fechaNacimiento,
                                            r.edadGestacional,
                                            r.numConsultasCPrenatal,
                                            r.codSexoBiologico,
                                            r.peso,
                                            r.codDiagnosticoPrincipal,
                                            r.condicionDestinoUsuarioEgreso,
                                            r.codDiagnosticoCausaMuerte,
                                            r.fechaEgreso,
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoCausaMuerteCIE11 = 'null',
                                            nomCodDiagnosticoCausaMuerteCIE11 = 'null',
                                            codigoVIDA = 'null',
                                            consecutivo = xconsecutivo  
                                        FROM #RECIEN r
                                        WHERE r.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    medicamentos = (
                                        SELECT 
                                            m.codPrestador,
                                            m.idMIPRES,
                                            fechaDispensAdmon = DBO.FNK_RIPS_FECHA_EN_PERIODO(m.fechaDispensAdmon, @FECHAINICAP, @FECHAFINCAP),
                                            m.codDiagnosticoPrincipal,
                                            m.codDiagnosticoRelacionado,
                                            codDiagnosticoPrincipalCIE11 = 'null',
                                            nomCodDiagnosticoPrincipalCIE11 = 'null',
                                            codDiagnosticoRelacionadoCIE11 = 'null',
                                            nomCodDiagnosticoRelacionadoCIE11 = 'null',
                                            vrDispensacion = CAST(0 AS DECIMAL(14,2)),
                                            codigoVIDA = 'null',
                                            m.tipoMedicamento,
                                            m.codTecnologiaSalud,
                                            m.nomTecnologiaSalud,
                                            m.concentracionMedicamento,
                                            m.unidadMedida,
                                            m.formaFarmaceutica,
                                            m.unidadMinDispensa,
                                            m.cantidadMedicamento,
                                            m.diasTratamiento,
                                            m.tipoDocumentoIdentificacion,
                                            m.numDocumentoIdentificacion,
                                            m.vrUnitMedicamento,
                                            m.vrServicio,
                                            m.conceptoRecaudo,
                                            m.valorPagoModerador,
                                            m.numFEVPagoModerador,
                                            consecutivo = xconsecutivo  
                                        FROM #MEDICAMENTOS2 m
                                        WHERE m.usuarioId = u.usuarioId
                                        ORDER BY xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    otrosServicios = (
                                        SELECT 
                                            os.codPrestador,
                                            os.numAutorizacion,
                                            os.idMIPRES,
                                            fechaSuministroTecnologia = DBO.FNK_RIPS_FECHA_EN_PERIODO(os.fechaSuministroTecnologia, @FECHAINICAP, @FECHAFINCAP),
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
                                            os.numFEVPagoModerador,
                                            consecutivo = xconsecutivo  
                                        FROM #OTROSSER2 os
                                        WHERE os.usuarioId = u.usuarioId 
                                        ORDER BY xconsecutivo
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
        SELECT @JSON = REPLACE(@JSON,'\"','"')
        SELECT @JSON = REPLACE(@JSON,'\\"','"')
        SELECT @JSON = REPLACE(@JSON,'"{','{')
        SELECT @JSON = REPLACE(@JSON,'}"','}')	
        SELECT @JSON = REPLACE(@JSON,'"null"','null')
        SELECT @PLANO= @json
    END
    IF 1=1
    BEGIN
        SELECT @base64 = cast('' as xml).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
        from (
            select [binaryValue] = cast(dbo.FNK_AttachedDocument(@CNSFCT,'FV') as varbinary(max))
        ) as conv;
        IF @TIPOCAP<>1
        BEGIN
            SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE',@base64)
        END
        ELSE
        BEGIN
            SET @json ='{ '
            SET @json +=' "xmlFevFile" :"'+@base64+'" '
            SET @json +='	}'
            SELECT @PLANO=@json
        END
    END
    IF COALESCE(@URL_PATH,'')<>''
    BEGIN
        SELECT @N_FACTURA=@N_FACTURA+'.json'
        EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
        SELECT @PLANO= @URL_PATH+IIF(RIGHT(@URL_PATH,1)='\','','\')+@N_FACTURA 
    END
    PRINT 'FINALIZO EN SPK_RIPS_JSON_FTR_CAPI'


    FIN:
    -- === Limpieza expl�cita de todas las tablas temporales ===
    DROP TABLE IF EXISTS #USUARIOS;
    DROP TABLE IF EXISTS #CONSULTAS;
    DROP TABLE IF EXISTS #CONSULTAS1;
    DROP TABLE IF EXISTS #CONSULTAS2;
    DROP TABLE IF EXISTS #MEDICAMENTOS;
    DROP TABLE IF EXISTS #MEDICAMENTOS2;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS1;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS2;
    DROP TABLE IF EXISTS #URGENCIAS;
    DROP TABLE IF EXISTS #HOSPITALIZACION;
    DROP TABLE IF EXISTS #RECIEN;
    DROP TABLE IF EXISTS #OTROSSER;
    DROP TABLE IF EXISTS #OTROSSER2;
    DROP TABLE IF EXISTS #DX;
    DROP TABLE IF EXISTS #REPORTE_RIPS;
END

