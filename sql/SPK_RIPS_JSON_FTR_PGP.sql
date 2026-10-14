CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_FTR_PGP
@N_FACTURA  VARCHAR(20),
@URL_PATH VARCHAR(MAX)=NULL,
@PLANO NVARCHAR(MAX) OUTPUT
AS 
BEGIN 
    SET NOCOUNT ON;
    -- Declaraci?n de variables escalares
    DECLARE @NOADMISION VARCHAR(20)
    DECLARE @CNSFCT VARCHAR(20)
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
    DECLARE @PLANTILLA VARCHAR(20)
    DECLARE @CAMPO_NRODOCUMENTO VARCHAR(20)
    DECLARE @CAMPO_TIPODOC VARCHAR(5)
    DECLARE @CAMPO_DESTINORN VARCHAR(2)
    DECLARE @ADQUIRIENTE VARCHAR(20)
    DECLARE @MODO_ASISTENCIAL VARCHAR(10)
    DECLARE @ESMODERADORAENFTR VARCHAR(2)
    DECLARE @ITEM_FDIANR INT
    DECLARE @CPROPIO BIT = 0
    DECLARE @IDPLAN VARCHAR(6)
    DECLARE @F_FACTURA DATETIME
    DECLARE @F_FINPERIODO DATETIME
    DECLARE @F_INIPERIODO DATETIME
    DECLARE @MODE BIT
    DECLARE @TDOC VARCHAR(2)
    DECLARE @IDMED VARCHAR(20)
    DECLARE @numDocumentoIdObligado VARCHAR(20)
    DECLARE @FECHAINICAP DATETIME
    DECLARE @FECHAFINCAP DATETIME
    DECLARE @TIPOCAP SMALLINT=0
    DECLARE @N_FACTURAANT VARCHAR(20)
    DECLARE @CAPITADA SMALLINT = 0
    DECLARE @PAQUETE SMALLINT = 0
    -- === CREACI?N DE TABLAS TEMPORALES CON COLLATE ===
        
    DECLARE @VALORCOPAGOFTR DECIMAL(12,2) ,@VALORMODERADORAFTR DECIMAL(12,2) ,@VLCOPAGO DECIMAL(12,2) , @VLMODERADORA DECIMAL(12,2) 
            ,@VLANTICIPO DECIMAL(12,2) ,@pro VARCHAR(3) ,@idT INT
    DECLARE   @RECAUDO AS TABLE (valorPagoModerador DECIMAL(12,2) ,PROCE VARCHAR(3)  COLLATE database_default,  ID INT )

    CREATE TABLE #HC_POR_ADMISION ( 
        NOADMISION VARCHAR(20) COLLATE database_default,
        CONSECUTIVOHCA VARCHAR(20) COLLATE database_default,
        CAMPO_NRODOCUMENTO VARCHAR(30) COLLATE database_default,
        CAMPO_TIPODOC VARCHAR(10) COLLATE database_default,
        DESTINORN VARCHAR(2) COLLATE database_default
    );

    CREATE TABLE #TODAS_HC ( 
        NOADMISION VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default
    );

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
        usuarioId INT,
        ID int IDENTITY(1,1),
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_CONSULTAS_IDAFILIADO ON #CONSULTAS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_CONSULTAS_USUARIOID ON #CONSULTAS (usuarioId);

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
        usuarioId INT,
        ID int,
        xconsecutivo int
    );

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
        restoPagoModerador DECIMAL(14,2) NULL,
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador INT,
        usuarioId INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default
    );

    CREATE TABLE #MEDICAMENTOS (
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
        nomTecnologiaSalud VARCHAR(120) COLLATE database_default,
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
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId INT,
        ID int IDENTITY(1,1),
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
        nomTecnologiaSalud VARCHAR(120) COLLATE database_default,
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
        valorPagoModerador INT,
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId INT,
        ID INT,
        xconsecutivo int
    );

    CREATE TABLE #PROCEDIMIENTOS (
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
        usuarioId INT,
        ID int IDENTITY(1,1),
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_PROCEDIMIENTOS_IDAFILIADO ON #PROCEDIMIENTOS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_PROCEDIMIENTOS_USUARIOID ON #PROCEDIMIENTOS (usuarioId);

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
        usuarioId INT,
        ID int,
        xconsecutivo int
    );

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
        restoPagoModerador DECIMAL(14,2),
        conceptoRecaudo VARCHAR(20) COLLATE database_default,
        tipoPagoModerador VARCHAR(2) COLLATE database_default,
        valorPagoModerador DECIMAL(14,2),
        numFEVPagoModerador VARCHAR(20) COLLATE database_default,
        usuarioId INT
    );

    CREATE TABLE #URGENCIAS (
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
        usuarioId INT,
        ID int IDENTITY(1,1),
        xconsecutivo int
    );
    CREATE NONCLUSTERED INDEX IX_URGENCIAS_IDAFILIADO ON #URGENCIAS (IDAFILIADO);
    CREATE NONCLUSTERED INDEX IX_URGENCIAS_USUARIOID ON #URGENCIAS (usuarioId);

    CREATE TABLE #HOSPITALIZACION (
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
        usuarioId INT,
        ID int IDENTITY(1,1),
        xconsecutivo int
    );

    CREATE TABLE #RECIEN (
        codPrestador VARCHAR(12) COLLATE database_default,
        IDAFILIADO VARCHAR(20) COLLATE database_default,
        CONSECUTIVO VARCHAR(20) COLLATE database_default,
        tipoDocumentoIdentificacion VARCHAR(2) COLLATE database_default DEFAULT 'CN',
        numDocumentoIdentificacion VARCHAR(20) COLLATE database_default,
        fechaNacimiento VARCHAR(16) COLLATE database_default,
        edadGestacional INT,
        numConsultasCPrenatal int,
        codSexoBiologico VARCHAR(2) COLLATE database_default,
        peso int,
        codDiagnosticoPrincipal VARCHAR(20) COLLATE database_default,
        condicionDestinoUsuarioEgreso VARCHAR(2) COLLATE database_default,
        codDiagnosticoCausaMuerte VARCHAR(20) COLLATE database_default,
        fechaEgreso VARCHAR(16) COLLATE database_default,
        usuarioId INT,
        ID int IDENTITY(1,1),
        xconsecutivo int
    );

    CREATE TABLE #OTROSSER (
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
        usuarioId INT,
        ID int IDENTITY(1,1),
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
        usuarioId INT,
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

    CREATE TABLE #MODERADORAS (
        NIVEL INT,
        VALOR DECIMAL(14,2)
    );


    DECLARE @json NVARCHAR(MAX)
    DECLARE @numNota VARCHAR(MAX)
    SELECT @MODO_ASISTENCIAL = DBO.FNK_VALORVARIABLE ('MODO_ASISTENCIAL') 
    SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
    PRINT 'SPK_RIPS_JSON_FTR_PGP ='+@N_FACTURA
    SELECT @CNSFCT=CNSFCT,@CPROPIO=COALESCE(COPAPROPIO,0),@IDPLAN=IDPLAN, @ADQUIRIENTE = IDTERCERO, 
           @VALORCOPAGO=CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(NULLIF(CP_VLR_COPAGOS,0), VALORCOPAGO, 0) ELSE COALESCE(VALORCOPAGO,0) END,
           @FECHAINICAP=FTR.FECHACAP_INI, @FECHAFINCAP=FTR.FECHACAP_FIN,
           @CAPITADA=COALESCE(CAPITADA,0), @PAQUETE=COALESCE(PAQUETE,0)
    FROM FTR WHERE N_FACTURA=@N_FACTURA

    -- === CACHE: si ya existe resultado en FTRJSON con SINENVIO=1, devolverlo sin recalcular ===
    --IF EXISTS (
    --    SELECT 1 FROM FTRJSON 
    --    WHERE CNSFCT = @CNSFCT 
    --      AND SINENVIO = 1
    --)
    --BEGIN
    --    SELECT @PLANO = JSON_ENVIO 
    --    FROM FTRJSON 
    --    WHERE CNSFCT = @CNSFCT;

    --    -- Inyectar el base64 del XML FEV (el cach? guarda el JSON sin base64 para ser liviano)
    --    SELECT @BASE64 = cast('' as xml).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
    --    FROM (
    --        SELECT [binaryValue] = cast(dbo.FNK_AttachedDocument(@CNSFCT,'FV') as varbinary(max))
    --    ) as conv;
    --    SELECT @PLANO = REPLACE(@PLANO, '@XMLFEVFILE', @BASE64);

    --    UPDATE FTRJSON 
    --    SET SINENVIO = 0 
    --    WHERE CNSFCT = @CNSFCT;

    --    DELETE FROM FTRJSON 
    --    WHERE CNSFCT = @CNSFCT 
    --      AND COALESCE(CUV, '') = '';

    --    PRINT 'CACHE: Devuelto desde FTRJSON (SINENVIO=1) + base64 inyectado, registro limpiado'
    --    RETURN;
    --END

    DECLARE @INICIO_EJECUCION DATETIME2 = SYSDATETIME();
    -- === FIN CACHE ===

    IF NOT EXISTS(SELECT 1 FROM FTRDC WHERE CNSFTR=@CNSFCT)
    BEGIN
        PRINT 'FACTURA CAPITADA SIN RELACION DE SERVICIOS, ME REGRESO'
        RAISERROR('FACTURA CAPITADA SIN RELACION DE SERVICIOS, POR FAVOR VERIFIQUE.', 16, 1)
        RETURN
    END

    IF EXISTS(SELECT 1 FROM FTRDC WHERE CNSFTR=@CNSFCT AND IDAFILIADO IS NULL)
    BEGIN 
        UPDATE FTRDC SET IDAFILIADO=CIT.IDAFILIADO
        FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO AND FTRDC.PROCEDENCIA IN('CIT','ONCO','APLIM')
        WHERE FTRDC.IDAFILIADO IS NULL AND FTRDC.CNSFTR=@CNSFCT

        UPDATE FTRDC SET IDAFILIADO=CIT.IDAFILIADO
        FROM FTRDC INNER JOIN CIT ON FTRDC.NOPRESTACION=CIT.CONSECUTIVO AND FTRDC.PROCEDENCIA ='APLIM'
        WHERE FTRDC.IDAFILIADO IS NULL AND FTRDC.CNSFTR=@CNSFCT

        UPDATE FTRDC SET IDAFILIADO=AUT.IDAFILIADO
        FROM FTRDC INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT AND FTRDC.PROCEDENCIA='AUT'
        WHERE FTRDC.IDAFILIADO IS NULL AND FTRDC.CNSFTR=@CNSFCT

        UPDATE FTRDC SET IDAFILIADO=HADM.IDAFILIADO
        FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION AND FTRDC.PROCEDENCIA='HADM'
        WHERE FTRDC.IDAFILIADO IS NULL AND FTRDC.CNSFTR=@CNSFCT
    END

    SELECT @conceptoRecaudo = '05'
    SELECT @IDPRESTADOR=COALESCE(IDALTERNA2,'No tengo'), @numDocumentoIdObligado = NIT 
    FROM TER WHERE IDTERCERO=@IDTERINSTA

    SELECT @ITEM_FDIANR = MAX(ITEM)
    FROM FDIANR WHERE CNSDOCUMENTO = @CNSFCT AND TIPO = 'FV' AND METODO = 'SendBillSync'
    
    -- eemc78: HAY QUE ARREGLAR ESTO QUE NO FUCNIONA CUANDO LA FACTURA TIENE DE LOS DOS
    IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND COALESCE(XML_AttachedDocument,'') != '' )
    BEGIN  
        IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND COALESCE(XML_AttachedDocument,'') != '' AND CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>',XML_AttachedDocument) > 0)
        BEGIN
            SELECT @ESMODERADORAENFTR = '02'
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND COALESCE(XML_AttachedDocument,'') != '' AND CHARINDEX('<cbc:ID schemeID="01">COPAGO</cbc:ID>',XML_AttachedDocument) > 0)
            BEGIN
                SELECT @ESMODERADORAENFTR = '01'
            END
        END
    END
    ELSE
    BEGIN
        IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND TIPO = 'FV' AND COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' )
        BEGIN
            IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND TIPO = 'FV' AND COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' AND CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>',CONVERT(NVARCHAR(MAX),XML_SOLICITUD)) > 0)
            BEGIN
                SELECT @ESMODERADORAENFTR = '02'
            END  
            ELSE
            BEGIN
                IF EXISTS(SELECT * FROM FDIANR WHERE ITEM = @ITEM_FDIANR AND TIPO = 'FV' AND COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' AND CHARINDEX('<cbc:ID schemeID="01">COPAGO</cbc:ID>',CONVERT(NVARCHAR(MAX),XML_SOLICITUD)) > 0)
                BEGIN
                    SELECT @ESMODERADORAENFTR = '01'
                END
            END
        END
    END

    select @VALORCOPAGOFTR = FTR.VALORCOPAGO , @VALORMODERADORAFTR = FTR.VALORMODERADORA FROM FTR WHERE N_fACTURA =@N_FACTURA
    PRINT ' VALORES DE FACTURA COPAGOS : ' + STR( @VALORCOPAGOFTR  )  + '   MODERADADORA : ' + STR ( @VALORMODERADORAFTR ) + '----------------------------------------'

    PRINT '@ESMODERADORAENFTR='+COALESCE(@ESMODERADORAENFTR,'Noencontrado')

    PRINT 'BUSCANDO LOS AFILIADOS'
    BEGIN 
        INSERT INTO #USUARIOS(tipoDocumentoIdentificacion,numDocumentoIdentificacion,IDAFILIADO,tipoUsuario,fechaNacimiento,codSexo,codPaisResidencia,codPaisOrigen,
                                codMunicipioResidencia,codZonaTerritorialResidencia,incapacidad)
        SELECT DISTINCT  AFI.TIPO_DOC,AFI.DOCIDAFILIADO,AFI.IDAFILIADO,
             TIPOUSUARIO=  CASE WHEN COALESCE(AFI.TIPOUSUARIO,'')='' THEN 
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
                                    WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END ELSE AFI.TIPOUSUARIO END,
                FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
                SEXO=UPPER(LEFT(AFI.SEXO,1)),PAIS='170',PAISR='170', MUNICIPIO=AFI.CIUDAD,ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
                INCAPACIDAD='NO'
        FROM FTRDC INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
        WHERE CNSFTR=@CNSFCT

    END
    IF EXISTS(SELECT * FROM FTRDJSON WHERE CNSFTR=@CNSFCT)
    BEGIN
       PRINT 'SI TENGO DATOS'
       INSERT INTO #USUARIOS(tipoDocumentoIdentificacion,numDocumentoIdentificacion,IDAFILIADO,tipoUsuario,fechaNacimiento,codSexo,codPaisResidencia,codPaisOrigen,
                                codMunicipioResidencia,codZonaTerritorialResidencia,incapacidad)

        SELECT 
            tipoDocumentoIdentificacion,
            numDocumentoIdentificacion,
            NULL,
            tipoUsuario,
            fechaNacimiento,
            codSexo,
            codPaisResidencia,
            codPaisOrigen,
            codMunicipioResidencia,
            codZonaTerritorialResidencia,
            incapacidad
        FROM (
            SELECT 
                JSON_VALUE(JSON_AFI,'$.tipoDocumentoIdentificacion') AS tipoDocumentoIdentificacion,
                JSON_VALUE(JSON_AFI,'$.numDocumentoIdentificacion') AS numDocumentoIdentificacion,
                JSON_VALUE(JSON_AFI,'$.tipoUsuario') AS tipoUsuario,
                CONVERT(VARCHAR(10), CAST(JSON_VALUE(JSON_AFI,'$.fechaNacimiento') AS DATE), 23) AS fechaNacimiento,
                JSON_VALUE(JSON_AFI,'$.codSexo') AS codSexo,
                JSON_VALUE(JSON_AFI,'$.codPaisResidencia') AS codPaisResidencia,
                JSON_VALUE(JSON_AFI,'$.codPaisOrigen') AS codPaisOrigen,
                JSON_VALUE(JSON_AFI,'$.codMunicipioResidencia') AS codMunicipioResidencia,
                JSON_VALUE(JSON_AFI,'$.codZonaTerritorialResidencia') AS codZonaTerritorialResidencia,
                JSON_VALUE(JSON_AFI,'$.incapacidad') AS incapacidad,
                ROW_NUMBER() OVER(
                    PARTITION BY JSON_VALUE(JSON_AFI,'$.numDocumentoIdentificacion')
                    ORDER BY JSON_VALUE(JSON_AFI,'$.consecutivo') DESC
                ) AS rn
            FROM FTRDJSON
                 WHERE CNSFTR=@CNSFCT
                 AND NOT EXISTS(
                     SELECT *
                     FROM #USUARIOS X
                     WHERE X.numDocumentoIdentificacion =JSON_VALUE(JSON_AFI,'$.numDocumentoIdentificacion')
                     and X.tipoDocumentoIdentificacion=JSON_VALUE(JSON_AFI,'$.tipoDocumentoIdentificacion')
                 )
        ) X
        WHERE rn = 1

         UPDATE #USUARIOS SET IDAFILIADO=CASE WHEN AFI.IDAFILIADO IS NOT NULL THEN AFI.IDAFILIADO ELSE X.numDocumentoIdentificacion END
         FROM  #USUARIOS X LEFT JOIN AFI  ON AFI.TIPO_DOC=X.tipoDocumentoIdentificacion AND AFI.DOCIDAFILIADO=X.numDocumentoIdentificacion
         WHERE X.IDAFILIADO IS NULL

         UPDATE FTRDJSON SET IDAFILIADO=X.IDAFILIADO
         FROM FTRDJSON INNER JOIN  #USUARIOS X ON FTRDJSON.IDAFI_EXT=X.numDocumentoIdentificacion
         WHERE CNSFTR=@CNSFCT
         AND FTRDJSON.IDAFILIADO<>X.IDAFILIADO

    END

    SELECT @conceptoRecaudo=CASE WHEN TIPOSISTEMA='Contributivo' THEN CASE WHEN COALESCE(@ESMODERADORAENFTR,'')<> '' THEN @ESMODERADORAENFTR ELSE '02' END  WHEN TIPOSISTEMA='Subsidiado' THEN '01' ELSE '05' END FROM PLN WHERE IDPLAN=@IDPLAN

    PRINT 'ARMADO TABLA DIAGNOSTICOS '
    BEGIN
        INSERT INTO #DX (IDAFILIADO,NOADMISION,CONSECUTIVOCIT,TIPODX,IDDX,DX1,DX2,DX3)
            SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
            CASE HCA.TIPODX 
                                WHEN 'Presuntivo'   THEN '01'
                                WHEN 'Impresion dx' THEN '01'
                                WHEN 'Definitivo'   THEN '01'
                                WHEN 'Conf Nuevo'   THEN '02'
                                WHEN 'Conf Repet'   THEN '03'
                                ELSE '01'
                                END
            ,LEFT(HCA.IDDX,4),LEFT(HCA.DX1,4),LEFT(HCA.DX2,4),LEFT(HCA.DX3,4)
        FROM HCA INNER JOIN CIT ON HCA.CONSECUTIVOCIT=CIT.CONSECUTIVO
        WHERE HCA.CLASE='HC'
            AND HCA.PROCEDENCIA='IPS'
            AND COALESCE(HCA.IDDX,'')<>''
            AND EXISTS(SELECT * FROM FTRDC WHERE  FTRDC.CNSFTR=@CNSFCT AND FTRDC.NOADMISION=CIT.CONSECUTIVO AND FTRDC.PROCEDENCIA IN ('CIT','ONCO'))
        UNION 
        SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
                CASE HCA.TIPODX 
                            WHEN 'Presuntivo'   THEN '01'
                            WHEN 'Impresion dx' THEN '01'
                            WHEN 'Definitivo'   THEN '01'
                            WHEN 'Conf Nuevo'   THEN '02'
                            WHEN 'Conf Repet'   THEN '03'
                            ELSE '01'
                            END,LEFT(HCA.IDDX,4),LEFT(HCA.DX1,4),LEFT(HCA.DX2,4),LEFT(HCA.DX3,4)
        FROM HCA INNER JOIN HADM ON HCA.NOADMISION=HADM.NOADMISION AND HCA.IDAFILIADO = HADM.IDAFILIADO
        WHERE HCA.CLASE='HC'
        AND HCA.PROCEDENCIA='QX'
        AND EXISTS(SELECT * FROM FTRDC WHERE  FTRDC.CNSFTR=@CNSFCT AND FTRDC.NOADMISION=HADM.NOADMISION AND FTRDC.PROCEDENCIA='HADM')
    END

    UPDATE HADM SET DXINGRESO=CASE WHEN LEN(COALESCE(HADM.DXINGRESO,''))<4 THEN DX.IDDX ELSE HADM.DXINGRESO END,
    DXEGRESO=CASE WHEN LEN(COALESCE(HADM.DXEGRESO,''))<4 THEN DX.IDDX ELSE HADM.DXEGRESO END,
    COMPLICACION=CASE WHEN LEN(COALESCE(HADM.COMPLICACION,''))<4 THEN DX.IDDX ELSE HADM.COMPLICACION END,
    DXSALIDA1=CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(DX.DX1,DX.IDDX) ELSE HADM.DXSALIDA1 END,
    DXSALIDA2=CASE WHEN LEN(COALESCE(HADM.DXSALIDA2,''))<4 THEN COALESCE(DX.DX2,DX.IDDX) ELSE HADM.DXSALIDA2 END,
    DXSALIDA3=CASE WHEN LEN(COALESCE(HADM.DXSALIDA3,''))<4 THEN COALESCE(DX.DX3,DX.IDDX) ELSE HADM.DXSALIDA3 END
    FROM HADM INNER JOIN #DX DX ON HADM.NOADMISION=DX.NOADMISION AND HADM.IDAFILIADO=DX.IDAFILIADO
    WHERE  EXISTS(SELECT * FROM FTRDC WHERE  FTRDC.CNSFTR=@CNSFCT AND FTRDC.NOADMISION=HADM.NOADMISION AND FTRDC.PROCEDENCIA='HADM')

    PRINT 'CONSULTAS'
    BEGIN
        PRINT 'CONSULTAS CIT'
        BEGIN 
            INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                    finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,conceptoRecaudo,valorPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                           codDiagnosticoPrincipal,tipoDiagnosticoPrincipal, numFEVPagoModerador)
            SELECT @IDPRESTADOR,CIT.CONSECUTIVO,CIT.IDAFILIADO,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
            numAutorizacion=LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS,FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
            modalidadGrupoServicioTecSal= COALESCE(TGEN.DATO3,'01'),
            grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
            codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
            finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1,'15') 
												WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'15')
												WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10' 
														THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
																	THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'15') 
																END  
												ELSE  COALESCE(FINALIDADTGEN.DATO1,CIT.FINCONSULTA,'15') 
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
                               WHERE COALESCE(CONSECUTIVOCIT,'') <> ''  AND YEAR(HCA.FECHA)>='2025'  AND COALESCe(ANULADA,0)=0 
                              ) HCA ON CIT.CONSECUTIVO=HCA.CONSECUTIVOCIT AND HCA.ITEM = 1
                  LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                  LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
                       INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                       LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA IN ('CIT','ONCO')
            AND RIPS_CP.ARCHIVO='AC'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

        END

         PRINT 'CONSULTAS CITSER'
        BEGIN 
            INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                    finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,conceptoRecaudo,valorPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                           codDiagnosticoPrincipal,tipoDiagnosticoPrincipal, numFEVPagoModerador)
            SELECT @IDPRESTADOR,CIT.CONSECUTIVO,CIT.IDAFILIADO,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
            numAutorizacion=LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS,FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
            modalidadGrupoServicioTecSal= COALESCE(TGEN.DATO3,'01'),
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
            coalesce(RCONREF.IDDX,''),'01', @N_FACTURA
            FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                        INNER JOIN CITSER ON CIT.CONSECUTIVO = CITSER.CONSECUTIVO_CIT  AND FTRDC.IDSERVICIO = CITSER.IDSERVICIO 
                        INNER JOIN SER ON FTRDC.IDSERVICIO=SER.IDSERVICIO
                        INNER JOIN AFI ON CIT.IDAFILIADO=AFI.IDAFILIADO
                        INNER JOIN MED ON CIT.IDMEDICO = MED.IDMEDICO
                        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                       LEFT JOIN RCONREF ON CIT.NOADMISION = RCONREF.NOADMISION
                      LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                      LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
                       INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                       LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA IN ('CITSER')
            AND RIPS_CP.ARCHIVO='AC'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END

        PRINT 'CONSULTAS AUT'
        BEGIN
            INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                       finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,conceptoRecaudo,valorPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion, 
                       codDiagnosticoPrincipal, codDiagnosticoRelacionado1, codDiagnosticoRelacionado2, tipoDiagnosticoPrincipal,numFEVPagoModerador)
            SELECT @IDPRESTADOR,AUT.NOAUT,AUT.IDAFILIADO,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
                   numAutorizacion=LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30) ,codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS,FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
                modalidadGrupoServicioTecSal='01',
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                finalidadTecnologiaSalud=LEFT(CASE WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD=''  OR AUT.FINALIDAD<='10' 
                                                         THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
                                                                   THEN  MPE.FINALIDAD 
																						 ELSE COALESCE(FINALIDADTGEN.DATO1,'12') 
                                                              END  
																			ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD )
                                                    END,2), 
                 causaMotivoAtencion=  CASE WHEN AUT.CLASEORDEN <> 'PYP' 
                                           THEN '38'
                                           ELSE CASE WHEN COALESCE(MPE.CAUSA_EXTERNA,'')='' THEN '38' ELSE MPE.CAUSA_EXTERNA END
                                     END
                ,AUTD.VALOR
                 ,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)
                ,COALESCE(FTRDC.VLR_COPAGO,0),IIF(COALESCE(MED.TIPO_ID,'')='','CC',MED.TIPO_ID), COALESCE(MED.IDMEDICO, 'null',''),
                 AUT.DXPPAL, CASE WHEN COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL) THEN 'null' ELSE AUT.DXRELACIONADO END, CASE WHEN COALESCE(AUT.DXRELACIONADO2,'')='' THEN 'null' END,'01',
                 @N_FACTURA
            FROM  FTRDC INNER JOIN AUT ON FTRDC.NOADMISION=AUT.IDAUT 
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
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END 
        PRINT 'CONSULTAS HADM...'
        BEGIN
            INSERT INTO #CONSULTAS(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,conceptoRecaudo,valorPagoModerador, 	tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador) 
            SELECT COALESCE(@IDPRESTADOR,''),HADM.NOADMISION,HADM.IDAFILIADO,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
                  numAutorizacion= LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30) ,codConsulta=LEFT(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),
                modalidadGrupoServicioTecSal='01', 
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
                finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(HPRE.FINALIDAD ,'')=''  OR HPRE.FINALIDAD ='10' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '44' ELSE COALESCE(FINALIDADTGEN.DATO1,HPRE.FINALIDAD,'') END,2) ,
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
            AND RIPS_CP.ARCHIVO='AC'
            AND HPRED.CANTIDAD=1
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

            PRINT 'REVISO CANTIDADES MAYORES A 1 CONSULTAS HADM'
            INSERT INTO #CONSULTAS1(codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,conceptoRecaudo,valorPagoModerador,Cantidad, tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador) 
            SELECT COALESCE(@IDPRESTADOR,''),HADM.NOADMISION,HADM.IDAFILIADO,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
            numAutorizacion=LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30),codConsulta=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),modalidadGrupoServicioTecSal='01',
          grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
          codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, 
          finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(HPRE.FINALIDAD ,'')=''  OR HPRE.FINALIDAD ='10' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' ELSE COALESCE(FINALIDADTGEN.DATO1,HPRE.FINALIDAD,'12') END,2) ,
            causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END,
          COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),COALESCE(HADM.DXSALIDA1,''),COALESCE(HADM.DXSALIDA2,''),COALESCE(HADM.DXSALIDA3,''),
            '01',HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),COALESCE(FTRDC.VLR_COPAGO,0),CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,6), COALESCE(HPRED.CANTIDAD,1)))), MED.TIPO_ID, MED.IDMEDICO, @N_FACTURA
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
           AND RIPS_CP.ARCHIVO='AC'
            AND HPRED.CANTIDAD > 1
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

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
            SELECT @IDPRESTADOR,LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30) ,CIT.IDAFILIADO,CIT.CONSECUTIVO,'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
                HCA.IDDX,'null','01'
                ,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=IIF(CHARINDEX('-',APLIMF.IDSERVICIO,0)>0,LEFT(APLIMF.IDSERVICIO,CHARINDEX('-',APLIMF.IDSERVICIO,0)-1),APLIMF.IDSERVICIO)   AND COALESCE(CODCUM,'')<>''),
             LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),120),
             CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
                COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',COALESCE(APLIMF.CANTIDAD,0),1,COALESCE(MED.TIPO_ID,'CC'),CASE WHEN MED.IDMEDICO LIKE '%ILLA%' THEN COALESCE(HCA.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')) ELSE DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') END,
             CIT.VALORTOTAL,CIT.VALORTOTAL,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
            FROM FTRDC INNER JOIN CIT ON FTRDC.NOPRESTACION=CIT.CONSECUTIVO  
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
             LEFT JOIN MED ON IIF(COALESCE(HCA.IDMEDICO,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(HCA.IDMEDICO,''))=MED.IDMEDICO
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA='APLIM'
            AND CIT.N_FACTURA=@N_FACTURA
            AND RIPS_CP.ARCHIVO='AM'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' 
            AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END
       
       PRINT 'MEDICAMENTOS CITSER DEL PAD'
        BEGIN
            INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                    ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                    ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                    ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30) ,CIT.IDAFILIADO,CIT.CONSECUTIVO,'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
                coalesce( rconref.IDDX,''),coalesce(rconref.iddx1,''),'01',COALESCE(SER.CODCUM,IART.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>'')),LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),120),
             CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
                COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',COALESCE(CITSER.CANTIDAD,0), 1 DIAS ,COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),
             CITSER.VALORTOTAL,CITSER.VALORTOTAL*CITSER.CANTIDAD,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
           FROM FTRDC 
            INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO  
                 INNER JOIN CITSER ON CIT.CONSECUTIVO=CITSER.CONSECUTIVO_CIT  AND FTRDC.IDSERVICIO = CITSER.IDSERVICIO 
                 INNER JOIN SER ON CITSER.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO 
                 INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS          AND RIPS_CP.ARCHIVO='AM'
                 LEFT JOIN RCONREF ON CIT.NOADMISION = RCONREF.NOADMISION
                 LEFT  JOIN IART ON SER.IDSERVICIO=IART.IDSERVICIO AND IART.PRINCIPAL=1
                 LEFT  JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
                 LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
              LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
              LEFT JOIN MED ON IIF(COALESCE(CIT.IDMEDICO,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),CIT.IDMEDICO )=MED.IDMEDICO
             WHERE FTRDC.CNSFTR= @CNSFCT
             AND FTRDC.PROCEDENCIA='CITSER'
             -- AND CIT.N_FACTURA=@N_FACTURA
             AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CITSER.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END

        PRINT 'MEDICAMENTOS AUT'
        BEGIN
           IF  DBO.FNK_VALORVARIABLE('PGP_AUT_SOLODISPENSA')<>'SI'
           BEGIN
              INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                       ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                       ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                       ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
               SELECT @IDPRESTADOR,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30) ,AUT.IDAFILIADO,AUT.NOAUT,'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
                     AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),'01',COALESCE(SER.CODCUM,IART.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>'')),LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),120),
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
               AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
               AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
          END
          ELSE
          BEGIN
              DELETE FTRDC  WHERE CNSFTR=@CNSFCT AND PROCEDENCIA='AUT'
              AND NOT EXISTS(SELECT 1 FROM  AUTD INNER JOIN AUT ON AUTD.IDAUT=AUT.IDAUT
                          INNER JOIN IZSOL ON AUT.CNSMOV=IZSOL.CNSIZSOL AND IZSOL.CLASE='CE'
                          INNER JOIN IZSOLD ON IZSOL.CNSIZSOL=IZSOLD.CNSIZSOL AND AUTD.IDSERVICIO=IZSOLD.IDSERVICIO
                          INNER JOIN IZSOLDT ON IZSOLD.CNSIZSOLD=IZSOLDT.CNSIZSOLD AND IZSOLD.IDARTICULO=IZSOLDT.IDARTICULO
                          WHERE  FTRDC.NOADMISION=AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM  AND FTRDC.IDSERVICIO=AUTD.IDSERVICIO
                          AND AUTD.N_FACTURA=@N_FACTURA)

              INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                       ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                       ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                       ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
               SELECT @IDPRESTADOR,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30) ,AUT.IDAFILIADO,AUT.NOAUT,'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,COALESCE(IIF(IMOV.FECHACONF>@FECHAFINCAP,@FECHAFINCAP,IMOV.FECHACONF),IZSOL.FECHASOL),102),'.','-')+' '+LEFT(CONVERT(VARCHAR,IZSOL.FECHASOL,108),5),
                     AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),'01',COALESCE(IART.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>''),SER.CODCUM),
                     LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),120),
                  CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
                     COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',COALESCE(AUTD.CANTIDAD,0),CASE WHEN COALESCE(AUTD.DIAS,0)=0 THEN 1 ELSE AUTD.DIAS END,COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),
                  AUTD.VALOR,AUTD.VALOR*AUTD.CANTIDAD,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
               FROM FTRDC INNER JOIN AUTD ON FTRDC.NOADMISION=AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM  AND FTRDC.IDSERVICIO=AUTD.IDSERVICIO
                          INNER JOIN AUT ON AUTD.IDAUT=AUT.IDAUT
                          INNER JOIN IZSOL ON AUT.CNSMOV=IZSOL.CNSIZSOL AND IZSOL.CLASE='CE'
                          INNER JOIN IZSOLD ON IZSOL.CNSIZSOL=IZSOLD.CNSIZSOL AND AUTD.IDSERVICIO=IZSOLD.IDSERVICIO
                          INNER JOIN IZSOLDT ON IZSOLD.CNSIZSOLD=IZSOLDT.CNSIZSOLD AND IZSOLD.IDARTICULO=IZSOLDT.IDARTICULO
                          INNER JOIN SER ON IZSOLD.IDSERVICIO=SER.IDSERVICIO AND FTRDC.IDSERVICIO = SER.IDSERVICIO 
                          INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                          LEFT  JOIN IMOV ON IZSOLDT.CNSMOV=IMOV.CNSMOV
                          LEFT  JOIN IART ON IART.IDARTICULO=IZSOLDT.IDARTICULOREAL
                          LEFT  JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
                          LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
                          LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
                          LEFT JOIN MED ON IIF(COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(AUT.IDSOLICITANTE,AUT.IDMEDICOSOLICITA))=MED.IDMEDICO
               WHERE FTRDC.CNSFTR=@CNSFCT
               AND FTRDC.PROCEDENCIA='AUT'
               AND AUTD.N_FACTURA=@N_FACTURA
               AND RIPS_CP.ARCHIVO='AM'
               AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
               AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')          
          END
        END

        PRINT 'MEDICAMENTOS HADM'
        BEGIN
            INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                    ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                    ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                    ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30) ,HADM.IDAFILIADO,HADM.NOADMISION,'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,FTRDC.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,FTRDC.FECHA,108),5),
                COALESCE(HADM.DXINGRESO,''),IIF(COALESCE(HADM.DXSALIDA1,'')='' OR UPPER(HADM.DXSALIDA1)=UPPER(COALESCE(HADM.DXINGRESO,'')),'null',HADM.DXSALIDA1),'01',CASE WHEN COALESCE(SER.MEDICAMENTOS,0)=1 THEN IIF(COALESCE(IART.CODCUM,'')='',COALESCE(SER.CODCUM,(SELECT TOP 1 CODCUM FROM IART WHERE IDSERVICIO=FTRDC.IDSERVICIO  AND COALESCE(CODCUM,'')<>'')),IART.CODCUM) ELSE SER.IDSERVICIO END,
                LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),120),
                CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',
                COALESCE(HPRED.CANTIDAD,0),1,COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR),20),
                CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR*HPRED.CANTIDAD),20),DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',CONVERT(DECIMAL(14,2),FTRDC.VLR_COPAGO),@N_FACTURA
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
            AND COALESCE(HPRED.NOCOBRABLE,0)=0
            AND RIPS_CP.ARCHIVO='AM'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' 
            AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
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
            SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),'null',
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
                ,CASE WHEN COALESCE(FTRDC.VLR_COPAGO,0)<= 0 THEN '05'
                      ELSE DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)
                 END
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
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END   

        PRINT 'PROCEDIMIENTOS CITSER PARA PAD'
        BEGIN
            INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                        ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                        ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                        )
            SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),'null',
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
                ,CASE WHEN COALESCE(FTRDC.VLR_COPAGO,0)<= 0 THEN '05'
                      ELSE DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)
                 END
                ,'04'
                ,COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
            FROM  FTRDC 
                INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                INNER JOIN CITSER ON CIT.CONSECUTIVO = CITSER.CONSECUTIVO_CIT  AND FTRDC.IDSERVICIO = CITSER.IDSERVICIO 
                INNER JOIN SER ON CITSER.IDSERVICIO=SER.IDSERVICIO 
                INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                LEFT  JOIN MED ON CIT.IDMEDICO=MED.IDMEDICO
                LEFT  JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
                INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
                LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA IN('CITSER')
            AND RIPS_CP.ARCHIVO='AP'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CITSER.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
        END   

        PRINT 'PROCEDIMIENTOS AUT'
        BEGIN
            INSERT INTO #PROCEDIMIENTOS (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                  ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                  ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5),'NULL'
                ,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(COALESCE(SER.CODCUPS, FTRDC.IDSERVICIO))),CHAR(13),''),CHAR(10),''),6),'02',
             '01'
             ,grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END
             ,codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END
             ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) ,
             COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'))
                ,AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),AUT.DXPPAL,AUTD.VALOR
             ,CASE  WHEN COALESCE(FTRDC.VLR_COPAGO,0)<=0 THEN '05'
                    ELSE DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)
              END
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
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

            INSERT INTO #PROCEDIMIENTOS1 (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                  ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                  ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,cantidad,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
            SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5),'NULL'
                ,LEFT(COALESCE(AUT.NUMAUTORIZA,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),'02','01'
             ,grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END
             ,codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END
             ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) ,
             COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'))
                ,AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR UPPER(AUT.DXRELACIONADO)=UPPER(AUT.DXPPAL),'null',AUT.DXRELACIONADO),AUT.DXPPAL,AUTD.VALOR
             ,CASE  WHEN COALESCE(FTRDC.VLR_COPAGO,0)<=0 THEN '05'
                    ELSE DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)
              END
             ,CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,6), FTRDC.CANTIDAD))), '04'
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
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
           
           
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
            SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
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
            AND COALESCE(HPRED.NOCOBRABLE,0)=0
            AND HPRED.CANTIDAD=1
            AND COALESCE(HPRED.IDCIRUGIA,'') = ''
            AND RIPS_CP.ARCHIVO='AP' 
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
           

            PRINT 'INSERTO CANTIDAS MAYORES A UNO HADM '
            INSERT INTO #PROCEDIMIENTOS1 (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                  ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                  ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,cantidad,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
                  )
            SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
                LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30),left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),'01',
             grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,
             codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END
             ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) ,
             COALESCE(MED.TIPO_ID,'CC'), COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),
             COALESCE(HADM.DXINGRESO,HADM.DXEGRESO), 
                CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) END,CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
             HPRED.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,6), HPRED.CANTIDAD))), '04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
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
            AND COALESCE(HPRED.NOCOBRABLE,0)=0
            AND HPRED.CANTIDAD>1
            AND RIPS_CP.ARCHIVO='AP' 
            AND COALESCE(HPRED.IDCIRUGIA,'') = ''
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

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
                  SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
                        LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),'01',
                     grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                     codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
                     ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) ,
                     COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
                        upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
                        upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
                     FTRDC.VALOR,DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),'04',COALESCE(FTRDC.VLR_COPAGO,0),@N_FACTURA
                    FROM  FTRDC INNER JOIN HPRED   ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM
                                INNER JOIN HPRE    ON HPRED.NOPRESTACION=HPRE.NOPRESTACION AND FTRDC.NOPRESTACION=HPRE.NOPRESTACION
                                INNER JOIN HADM    ON HPRE.NOADMISION=HADM.NOADMISION
                                INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
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
                    AND COALESCE(HPRED.NOCOBRABLE,0) = 0
                    AND COALESCE(SER.CIRUGIA,0) = 1
                    AND RIPS_CP.ARCHIVO = 'AP' 
                    AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
                    AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')
                  --GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,DBO.FNK_RIPS_FECHA_EN_PERIODO(REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5), @FECHAINICAP, @FECHAFINCAP),
                  --      LEFT(COALESCE(HADM.NOAUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),DBO.FNK_RIPS_VIA_INGRESO(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),
                  --    CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
                  --    CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
                  --   ,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) ,
                  --   COALESCE(MED.TIPO_ID,'CC'),COALESCE(MED.IDMEDICO,DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT')),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
                  --      upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
                  --      upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
                  --     DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo)            
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
                REPLACE(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <=@FECHAINICAP THEN  @FECHAINICAP ELSE  HADM.FECHA END,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <=@FECHAINICAP THEN   @FECHAINICAP ELSE  HADM.FECHA END,108),5),
        --CASE WHEN COALESCE(TGEN.CHECK1,0)=1 THEN DATO1 ELSE CODIGO END
        causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END
        ,COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HADM.DXEGRESO,HCA.DX1,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),
        COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HADM.DXSALIDA3,HCA.DX2),CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END,
        CASE WHEN HADM.ESTADOPSALIDA=1 THEN null ELSE CAUSABMUERTE END
         ,REPLACE(CONVERT(VARCHAR,
               CASE
                  WHEN HADM.FECHAALTAMED IS NULL THEN @FECHAFINCAP
                  WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN @FECHAFINCAP -- Si la fecha de alta es despu?s del fin del corte, usar el fin del corte
                  WHEN HADM.FECHAALTAMED <= @FECHAINICAP THEN @FECHAINICAP -- Si la fecha de alta es antes del inicio del corte, usar el inicio del corte
                  ELSE HADM.FECHAALTAMED -- Si est? dentro del periodo, usar la fecha real
               END
         ,102),'.','-')+' '+CASE
                  WHEN HADM.FECHAALTAMED IS NULL THEN '23:59'
                  WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN '23:59' -- Si la fecha de alta es despu?s del fin del corte, usar el fin del corte
                  WHEN HADM.FECHAALTAMED <= @FECHAINICAP THEN '23:59' -- Si la fecha de alta es antes del inicio del corte, usar el inicio del corte
                  ELSE LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5) -- Si est? dentro del periodo, usar la fecha real
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
       PRINT 'INGRESO A HOSPITALIZACION'
        INSERT INTO #HOSPITALIZACION (codPrestador,IDAFILIADO,CONSECUTIVO,viaIngresoServicioSalud,fechaInicioAtencion,numAutorizacion,causaMotivoAtencion,codDiagnosticoPrincipal,
                                    codDiagnosticoPrincipalE,codDiagnosticoRelacionadoE1,codDiagnosticoRelacionadoE2,codDiagnosticoRelacionadoE3,
                                    codComplicacion,condicionDestinoUsuarioEgreso,codDiagnosticoCausaMuerte,fechaEgreso)
        SELECT DISTINCT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION
        ,DBO.FNK_RIPS_VIA_INGRESO(IIF (HADM.TIPOADM='02' AND  HADM.VIAINGRESO = '5' , '13' ,  COALESCE(REPLACE(TGEN.DATO2,' ',''), HADM.VIAINGRESO ,'01') )),
        REPLACE(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <@FECHAINICAP THEN  @FECHAINICAP ELSE  HADM.FECHA END,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CASE WHEN HADM.FECHA <=@FECHAINICAP THEN   @FECHAINICAP ELSE  HADM.FECHA END,108),5)
            ,LEFT(COALESCE(HADM.NOAUTORIZACION,'NULL') ,30) -- STORRES 20260610 SE AGREGA COALESCE PARA QUE DE NULL Y ASI AL GENERAR JSON NO QUITE ESTA OPCION
            --,COALESCE(REPLACE(TGEN2.DATO1,' ',''),HADM.CAUSAEXTERNA,'38')
            ,causaMotivoAtencion=CASE WHEN COALESCE( HADM.CAUSAEXTERNA,'')<>'' THEN  CASE WHEN HADM.CAUSAEXTERNA <= '15' THEN TGEN2.DATO1 ELSE HADM.CAUSAEXTERNA END ELSE '38' END
            ,COALESCE(HADM.DXINGRESO,'')
            ,COALESCE(HADM.DXEGRESO,'')
            ,CASE WHEN COALESCE(HADM.DXSALIDA1,'')='' THEN 'null' END
            ,CASE WHEN COALESCE(HADM.DXSALIDA2,'')='' THEN 'null' END
            ,CASE WHEN COALESCE(HADM.DXSALIDA3,'')='' THEN 'null' END
            ,COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO)
            ,CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END
            ,CASE WHEN HADM.ESTADOPSALIDA=1 THEN '' ELSE CAUSABMUERTE END
            ,REPLACE(CONVERT(VARCHAR,
                CASE
                    WHEN HADM.FECHAALTAMED IS NULL THEN @FECHAFINCAP
                    WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN @FECHAFINCAP -- Si la fecha de alta es despu?s del fin del corte, usar el fin del corte
                    WHEN HADM.FECHAALTAMED < @FECHAINICAP THEN @FECHAINICAP -- Si la fecha de alta es antes del inicio del corte, usar el inicio del corte
                    ELSE HADM.FECHAALTAMED -- Si est? dentro del periodo, usar la fecha real
                END
            ,102),'.','-')+' '+ CASE
                    WHEN HADM.FECHAALTAMED IS NULL THEN '23:59'
                    WHEN HADM.FECHAALTAMED > @FECHAFINCAP THEN '23:59' -- Si la fecha de alta es despu?s del fin del corte, usar el fin del corte
                    WHEN HADM.FECHAALTAMED < @FECHAINICAP THEN '23:59' -- Si la fecha de alta es antes del inicio del corte, usar el inicio del corte
                    ELSE LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5) -- Si est? dentro del periodo, usar la fecha real
                END
        FROM FTRDC INNER JOIN HADM ON FTRDC.NOADMISION=HADM.NOADMISION
                LEFT JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
                LEFT JOIN TGEN TGEN2 ON HADM.CAUSAEXTERNA = TGEN2.CODIGO AND TGEN2.TABLA = 'General' AND TGEN2.CAMPO = 'CAUSAEXTERNA'
        WHERE FTRDC.CNSFTR=@CNSFCT 
        AND FTRDC.PROCEDENCIA='HADM'
        AND 1= CASE WHEN FECHAALTAMED IS NULL  THEN  CASE WHEN  DATEDIFF(HOUR,HADM.FECHA,@FECHAFINCAP)> 36 THEN 1 ELSE 0 END 
               ELSE  CASE WHEN DATEDIFF(HOUR,HADM.FECHA,HADM.FECHAALTAMED)>36 THEN 1 ELSE 0  END END
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
        codDiagnosticoCausaMuerte = coalesce(QXRCN.CMCAUSAMUERTE,'null'), --STORRES 20260610 SE AGREGA COLAESCE PARA LLNAR EL DATO NULL CUANDO LA INFORMACION VIENE VACIA
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
        SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,numAutorizacion=LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),'null', --STORRES 20260610 SE AGREGA COMULLAS A LA PALABRA NULL PARA QUE LO TENGA EN CUENTA AL FINAL y se agrega coalesce a numautorizacion para no perder informeacion en la generacion del json
            fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
            tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
            codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
            cantidadOS=IIF(COALESCE(CIT.CANTIDADC,1)=0,1,COALESCE(CIT.CANTIDADC,1)),tipoDocumentoIdentificacion=left(MED.TIPO_ID,2),
            numDocumentoIdentificacion=MED.IDMEDICO,COALESCE(CIT.VALORTOTAL,0),COALESCE(CIT.VALORTOTAL,0),IIF(COALESCE(
            FTRDC.VLR_COPAGO,0)>0,@conceptoRecaudo,'05'),tipoPagoModerador='04',COALESCE(FTRDC.VLR_COPAGO,0),
            @N_FACTURA
        FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                    INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN SER ON CIT.IDSERVICIO=SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    LEFT  JOIN MED ON CIT.IDMEDICO=MED.IDMEDICO
        WHERE FTRDC.CNSFTR=@CNSFCT
        AND FTRDC.PROCEDENCIA='CIT'
        AND CIT.N_FACTURA=@N_FACTURA
        AND RIPS_CP.ARCHIVO='AT'
        AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
        AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

        INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                            ,valorPagoModerador,numFEVPagoModerador)
        SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,numAutorizacion=LEFT(COALESCE(CIT.NOAUTORIZACION,'null'),30),'null', --STORRES 20260610 SE AGREGA COMULLAS A LA PALABRA NULL PARA QUE LO TENGA EN CUENTA AL FINAL y se agrega coalesce a numautorizacion para no perder informeacion en la generacion del json
            fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
            tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
            codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
            cantidadOS=IIF(COALESCE(CIT.CANTIDADC,1)=0,1,COALESCE(CIT.CANTIDADC,1)),tipoDocumentoIdentificacion=left(MED.TIPO_ID,2),
            numDocumentoIdentificacion=HCA.IDMEDICO,COALESCE(CIT.VALORTOTAL,0),COALESCE(CIT.VALORTOTAL,0),IIF(COALESCE(
            FTRDC.VLR_COPAGO,0)>0,@conceptoRecaudo,'05'),tipoPagoModerador='04',COALESCE(FTRDC.VLR_COPAGO,0),
            @N_FACTURA
            FROM FTRDC INNER JOIN CIT ON FTRDC.NOPRESTACION=CIT.CONSECUTIVO  
                       INNER JOIN APLIM ON CIT.CONSECUTIVO=APLIM.CONSECUTIVOCIT
                      INNER JOIN ( SELECT ROW_NUMBER() OVER(PARTITION BY IDAPLIM,IDSERVICIO ORDER BY IDAPLIM,IDSERVICIO ASC) ITEM, IDAPLIM,IDSERVICIO,CANTIDAD
                                  FROM APLIMF 
                                  WHERE COALESCE(CLASE,'')='INSUMO'  
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
             LEFT JOIN MED ON IIF(COALESCE(HCA.IDMEDICO,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(HCA.IDMEDICO,''))=MED.IDMEDICO
            WHERE FTRDC.CNSFTR=@CNSFCT
            AND FTRDC.PROCEDENCIA='APLIM'
            AND CIT.N_FACTURA=@N_FACTURA
            AND RIPS_CP.ARCHIVO='AT'
            AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CIT.VALORTOTAL,0) ) >0
            AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' 
            AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')


        PRINT 'TERMINO CIT'

        INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                            ,valorPagoModerador,numFEVPagoModerador)
        SELECT @IDPRESTADOR,CIT.IDAFILIADO,CIT.CONSECUTIVO,numAutorizacion=LEFT(coalesce(CIT.NOAUTORIZACION,'null'),30),'null', --STORRES 20260610 SE AGREGA COMULLAS A LA PALABRA NULL PARA QUE LO TENGA EN CUENTA AL FINAL y se agrega coalesce a numautorizacion para no perder informeacion en la generacion del json
            fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
            tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
            codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
            cantidadOS=IIF(COALESCE(CITSER.CANTIDAD,1)=0,1,COALESCE(CITSER.CANTIDAD,1)),tipoDocumentoIdentificacion=left(MED.TIPO_ID,2),
            numDocumentoIdentificacion=MED.IDMEDICO,COALESCE(CITSER.VALORTOTAL,0),COALESCE(CITSER.VALORTOTAL,0),IIF(COALESCE(
            FTRDC.VLR_COPAGO,0)>0,@conceptoRecaudo,'05'),tipoPagoModerador='04',COALESCE(FTRDC.VLR_COPAGO,0),
            @N_FACTURA
        FROM FTRDC INNER JOIN CIT ON FTRDC.NOADMISION=CIT.CONSECUTIVO
                    INNER JOIN CITSER ON CITSER.CONSECUTIVO_CIT=CIT.CONSECUTIVO  AND FTRDC.IDSERVICIO = CITSER.IDSERVICIO 
                    INNER JOIN AFI ON FTRDC.IDAFILIADO=AFI.IDAFILIADO
                    INNER JOIN SER ON CITSER.IDSERVICIO=SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    LEFT  JOIN MED ON CIT.IDMEDICO=MED.IDMEDICO
        WHERE FTRDC.CNSFTR=@CNSFCT
        AND FTRDC.PROCEDENCIA='CITSER'
        AND CIT.N_FACTURA=@N_FACTURA
        AND RIPS_CP.ARCHIVO='AT'
        AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(CITSER.VALORTOTAL,0) ) >0
        AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

        PRINT 'TERMINO CITSER'

        INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                            ,valorPagoModerador,numFEVPagoModerador)
        SELECT @IDPRESTADOR,AUT.IDAFILIADO,AUT.NOAUT,numAutorizacion=LEFT(coalesce(AUT.NUMAUTORIZA,'null'),30),'null', --STORRES 20260610 SE AGREGA COMULLAS A LA PALABRA NULL PARA QUE LO TENGA EN CUENTA AL FINAL y se agrega coalesce a numautorizacion para no perder informeacion en la generacion del json
            fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
            tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,
            codTecnologiaSalud=left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
            cantidadOS=COALESCE(AUTD.CANTIDAD,1),tipoDocumentoIdentificacion=MED.TIPO_ID,
            numDocumentoIdentificacion=MED.IDMEDICO,
            COALESCE(AUTD.VALOR,0),
            COALESCE(AUTD.VALOR,0)*COALESCE(AUTD.CANTIDAD, 0),
            DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),
            tipoPagoModerador='04',
            COALESCE(FTRDC.VLR_COPAGO,0),
            @N_FACTURA
        FROM FTRDC INNER JOIN AUT ON FTRDC.NOADMISION= AUT.IDAUT
                     INNER JOIN AUTD ON AUT.IDAUT = AUTD.IDAUT AND FTRDC.NOITEM=AUTD.NO_ITEM
                    INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    LEFT  JOIN MED		ON MED.IDMEDICO    = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
        WHERE FTRDC.CNSFTR=@CNSFCT
        AND FTRDC.PROCEDENCIA='AUT'
        AND AUTD.N_FACTURA=@N_FACTURA
        AND RIPS_CP.ARCHIVO='AT'
        AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(AUTD.VALOR,0) ) >0
        AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

        PRINT 'TERMINO AUT'

        INSERT INTO #OTROSSER(codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                            ,valorPagoModerador,numFEVPagoModerador)
        SELECT @IDPRESTADOR,HADM.IDAFILIADO,HADM.NOADMISION                                                                   
            ,numAutorizacion=LEFT(coalesce(HADM.NOAUTORIZACION,'null'),30) --STORRES 20260610 SE AGREGA COALESCE A NUMAUTORIZACION PARA NO PERDER INFORMEACION EN LA GENERACION DEL JSON
            ,'null' --STORRES 20260610 SE AGREGA COMULLAS A LA PALABRA NULL PARA QUE LO TENGA EN CUENTA AL FINAL
            ,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
            ,tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END
            ,codTecnologiaSalud=CASE WHEN RIPS_CP.IDCONCEPTORIPS=DBO.FNK_VALORVARIABLE('IDMATERIALESRIPS')THEN SER.IDSERVICIO ELSE left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6) END
            ,nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
            ,cantidadOS=CONVERT(INT, FLOOR(CONVERT(DECIMAL(18,6), COALESCE(HPRED.CANTIDAD,1)))),
            tipoDocumentoIdentificacion=MED.TIPO_ID,
            numDocumentoIdentificacion=MED.IDMEDICO,
            CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR,0)),
            CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR*HPRED.CANTIDAD,0)),
            DBO.FNK_RIPS_CONCEPTO_RECAUDO(FTRDC.VLR_COPAGO, FTRDC.TCOPAGO, FTRDC.PROCEDENCIA, @conceptoRecaudo),
            tipoPagoModerador='04',
            CONVERT(DECIMAL(14,2),COALESCE(FTRDC.VLR_COPAGO,0)) ,
            @N_FACTURA                                                                       
        FROM FTRDC INNER JOIN HPRED ON FTRDC.NOPRESTACION=HPRED.NOPRESTACION AND FTRDC.NOITEM=HPRED.NOITEM 
                  INNER JOIN  HPRE ON HPRED.NOPRESTACION=HPRE.NOPRESTACION
                  INNER JOIN HADM ON HPRE.NOADMISION=HADM.NOADMISION
                  INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  INNER JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING)='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
                  LEFT JOIN HCA ON HPRE.CONSECUTIVOHCA=HCA.CONSECUTIVO
        WHERE FTRDC.CNSFTR=@CNSFCT
        AND FTRDC.PROCEDENCIA='HADM'
        AND HPRED.N_FACTURA=@N_FACTURA
        AND RIPS_CP.ARCHIVO='AT'   
        AND COALESCE(HPRED.NOCOBRABLE,0)=0
        AND IIF( COALESCE(DBO.FNK_VALORVARIABLE('FEVRIPS_INC_SINVLR'),'NO' ) ='SI' , 1 , COALESCE(HPRED.VALOR,0) ) >0
        AND SER.IDSERVICIO NOT IN ( SELECT CODIGO  FROM TGEN WHERE TGEN.TABLA='EXCUYSERPLAN' AND TGEN.CAMPO = FTRDC.IDPLAN AND COALESCE(DBO.FNK_VALORVARIABLE('FTRDC_EXCUYSERPLAN'),'NO' ) ='SI')

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
    -- SERMUS89: retirado VALI_CURSOR / FNK_JSON_EDADYTIPODOC (fecha nacimiento vs tipo doc); ya no aplica en norma RIPS.
    /*
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
    AND AFI.EDAD LIKE '%A?OS%'
    AND CONVERT(INT,LTRIM(RTRIM(REPLACE(AFI.EDAD,'A?OS','')))) IN(3,7,8,18)
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
    */
    PRINT 'ARMADO TABLA DIAGNOSTICOS '
    BEGIN
        INSERT INTO #DX (IDAFILIADO,NOADMISION,CONSECUTIVOCIT,TIPODX,IDDX,DX1,DX2,DX3)
            SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
            CASE HCA.TIPODX 
                                    WHEN 'Presuntivo'   THEN '01'
                                    WHEN 'Impresion dx' THEN '01'
                                    WHEN 'Definitivo'   THEN '01'
                                    WHEN 'Conf Nuevo'   THEN '02'
                                    WHEN 'Conf Repet'   THEN '03'
                                    ELSE '01'
                                    END
            ,LEFT(HCA.IDDX,4),LEFT(HCA.DX1,4),LEFT(HCA.DX2,4),LEFT(HCA.DX3,4)
        FROM HCA INNER JOIN CIT ON HCA.CONSECUTIVOCIT=CIT.CONSECUTIVO AND HCA.IDAFILIADO = CIT.IDAFILIADO
        WHERE HCA.CLASE='HC'
            AND HCA.PROCEDENCIA='IPS'
            AND COALESCE(HCA.IDDX,'')<>''
            AND EXISTS(SELECT 1 FROM FTRDC WHERE FTRDC.CNSFTR=@CNSFCT 
            AND FTRDC.NOADMISION=CIT.CONSECUTIVO AND FTRDC.PROCEDENCIA='CIT')
        UNION 
        SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
                CASE HCA.TIPODX 
                            WHEN 'Presuntivo'   THEN '01'
                            WHEN 'Impresion dx' THEN '01'
                            WHEN 'Definitivo'   THEN '01'
                            WHEN 'Conf Nuevo'   THEN '02'
                            WHEN 'Conf Repet'   THEN '03'
                            ELSE '01'
                            END,LEFT(HCA.IDDX,4),LEFT(HCA.DX1,4),LEFT(HCA.DX2,4),LEFT(HCA.DX3,4)
        FROM HCA INNER JOIN HADM ON HCA.NOADMISION=HADM.NOADMISION AND HCA.IDAFILIADO = HADM.IDAFILIADO
        WHERE HCA.CLASE='HC'
        AND HCA.PROCEDENCIA='QX'
        AND EXISTS(SELECT 1 FROM FTRDC WHERE  FTRDC.CNSFTR=@CNSFCT AND FTRDC.NOADMISION=HADM.NOADMISION AND FTRDC.PROCEDENCIA='HADM')
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
    IF EXISTS(SELECT * FROM #CONSULTAS WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal,''))))<4)
    BEGIN

         WITH HCA_Reciente AS (
             SELECT 
                 HCA.IDAFILIADO,
                 HCA.IDDX,
                 ROW_NUMBER() OVER (PARTITION BY HCA.IDAFILIADO ORDER BY HCA.FECHA DESC) AS rn -- Ordena por fecha descendente y numera
            FROM #CONSULTAS INNER JOIN HCA ON #CONSULTAS.IDAFILIADO=HCA.IDAFILIADO
            WHERE HCA.CLASE='HC' 
            AND COALESCE(HCA.IDDX,'')<>''
            AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal,''))))<4
         )
         UPDATE AC
         SET codDiagnosticoPrincipal = HCA_Reciente.IDDX
         FROM #CONSULTAS AC
         INNER JOIN HCA_Reciente ON AC.IDAFILIADO = HCA_Reciente.IDAFILIADO
         WHERE HCA_Reciente.rn = 1
         AND LEN(LTRIM(RTRIM(COALESCE(AC.codDiagnosticoPrincipal,''))))<4;
    END
    PRINT 'Actualizaci?n de LAS TABLAS con los diagn?sticos principales y relacionados en un solo bloque'
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

        UPDATE #CONSULTAS SET codDiagnosticoPrincipal='Z000' WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal,''))))<4;
        UPDATE #CONSULTAS SET tipoDiagnosticoPrincipal='01' WHERE LEN(COALESCE(tipoDiagnosticoPrincipal,''))<2

        PRINT 'Diagnosticos medicamentos'+CAST(GETDATE() AS VARCHAR(20))
        UPDATE AM
        SET 
            AM.codDiagnosticoPrincipal = CASE WHEN COALESCE(AM.codDiagnosticoPrincipal, '') = '' THEN DX.IDDX ELSE AM.codDiagnosticoPrincipal END,
            AM.codDiagnosticoRelacionado = CASE WHEN COALESCE(AM.codDiagnosticoRelacionado, '') = '' OR AM.codDiagnosticoRelacionado = 'null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AM.codDiagnosticoRelacionado END
        FROM #MEDICAMENTOS AM  INNER JOIN #DX DX ON AM.IDAFILIADO = DX.IDAFILIADO
        WHERE COALESCE(DX.IDDX, '') <> '';

        UPDATE #MEDICAMENTOS SET codDiagnosticoPrincipal=UPPER(codDiagnosticoPrincipal),
               codDiagnosticoRelacionado=UPPER(IIF(LEN(codDiagnosticoRelacionado)<4,'null',codDiagnosticoRelacionado))
        WHERE 1=1

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
        WHERE COALESCE(DX.IDDX, '') <> '';

        PRINT 'HOSPITALIZACION'
        UPDATE AH
        SET 
            AH.codDiagnosticoPrincipal = CASE WHEN COALESCE(AH.codDiagnosticoPrincipal, '') = '' THEN DX.IDDX ELSE AH.codDiagnosticoPrincipal END,
            AH.codDiagnosticoPrincipalE = CASE WHEN COALESCE(AH.codDiagnosticoPrincipalE, '') = '' THEN COALESCE(DX.IDDX, AH.codDiagnosticoPrincipal) ELSE AH.codDiagnosticoPrincipalE END,
            AH.codDiagnosticoRelacionadoE1 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE1, '') = '' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AH.codDiagnosticoRelacionadoE1 END,
            AH.codDiagnosticoRelacionadoE2 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE2, '') = '' THEN IIF(COALESCE(DX.DX2,'')='' OR DX.DX2=COALESCE(DX.IDDX,''),'null',DX.DX2) ELSE AH.codDiagnosticoRelacionadoE2 END,
            AH.codDiagnosticoRelacionadoE3 = CASE WHEN COALESCE(AH.codDiagnosticoRelacionadoE3, '') = '' THEN IIF(COALESCE(DX.DX3,'')='' OR DX.DX3=COALESCE(DX.IDDX,''),'null',DX.DX3) ELSE AH.codDiagnosticoRelacionadoE3 END
        FROM #HOSPITALIZACION AH
        INNER JOIN #DX DX ON AH.IDAFILIADO = DX.IDAFILIADO
        WHERE COALESCE(DX.IDDX, '') <> '';

        -- Validaci?n RIPS: el dx relacionado no puede ser igual al dx principal
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
        -- Validaci?n RIPS: dx relacionados de consulta no pueden repetirse entre s?
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
        -- Validaci?n RIPS: dx relacionados de egreso no pueden repetirse entre s?
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

        /* SISPRO RVG01: diagnosticos de hospitalizacion deben tener 4 caracteres. */
        UPDATE #HOSPITALIZACION
           SET codDiagnosticoPrincipal = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoPrincipal, '.', ''), ' ', ''))))
        WHERE codDiagnosticoPrincipal NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoPrincipalE = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoPrincipalE, '.', ''), ' ', ''))))
        WHERE codDiagnosticoPrincipalE NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE1 = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoRelacionadoE1, '.', ''), ' ', ''))))
        WHERE codDiagnosticoRelacionadoE1 NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE2 = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoRelacionadoE2, '.', ''), ' ', ''))))
        WHERE codDiagnosticoRelacionadoE2 NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE3 = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoRelacionadoE3, '.', ''), ' ', ''))))
        WHERE codDiagnosticoRelacionadoE3 NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codComplicacion = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codComplicacion, '.', ''), ' ', ''))))
        WHERE codComplicacion NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoCausaMuerte = UPPER(LTRIM(RTRIM(REPLACE(REPLACE(codDiagnosticoCausaMuerte, '.', ''), ' ', ''))))
        WHERE codDiagnosticoCausaMuerte NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoPrincipal = LEFT(codDiagnosticoPrincipal, 4)
        WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipal, '')))) > 4;

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoPrincipalE = LEFT(codDiagnosticoPrincipalE, 4)
        WHERE LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoPrincipalE, '')))) > 4
          AND codDiagnosticoPrincipalE NOT IN ('', 'null');

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE1 = LEFT(codDiagnosticoRelacionadoE1, 4)
        WHERE codDiagnosticoRelacionadoE1 NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE1, '')))) > 4;

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE2 = LEFT(codDiagnosticoRelacionadoE2, 4)
        WHERE codDiagnosticoRelacionadoE2 NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE2, '')))) > 4;

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoRelacionadoE3 = LEFT(codDiagnosticoRelacionadoE3, 4)
        WHERE codDiagnosticoRelacionadoE3 NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoRelacionadoE3, '')))) > 4;

        UPDATE #HOSPITALIZACION
           SET codComplicacion = LEFT(codComplicacion, 4)
        WHERE codComplicacion NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codComplicacion, '')))) > 4;

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoCausaMuerte = LEFT(codDiagnosticoCausaMuerte, 4)
        WHERE codDiagnosticoCausaMuerte NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoCausaMuerte, '')))) > 4;

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

        UPDATE #HOSPITALIZACION
           SET codDiagnosticoCausaMuerte = ''
        WHERE codDiagnosticoCausaMuerte NOT IN ('', 'null')
          AND LEN(LTRIM(RTRIM(COALESCE(codDiagnosticoCausaMuerte, '')))) <> 4;

    END

    PRINT 'TERMINO LA ACTUALIZAR DX  '+CAST(GETDATE() AS VARCHAR(20))

    SELECT @VALORCOPAGOACU=COALESCE(SUM(valorPagoModerador),0) FROM #CONSULTAS
    SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #PROCEDIMIENTOS
    SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #MEDICAMENTOS
    SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #OTROSSER

    PRINT '@VALORCOPAGO '+STR(@VALORCOPAGO)
    PRINT '@VALORCOPAGOACU '+STR(@VALORCOPAGOACU)

    IF COALESCE(@PAQUETE,0)=0 AND COALESCE(@VALORCOPAGO,0)>0 AND COALESCE(@VALORCOPAGOACU,0)=0 AND COALESCE(@CPROPIO,0)=0
    BEGIN
        SET @idT = 0
        SET @pro = NULL
        SELECT TOP 1 @pro = 'CON', @idT = id FROM #CONSULTAS ORDER BY id
        IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'PRO', @idT = id FROM #PROCEDIMIENTOS ORDER BY id
        IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'MED', @idT = id FROM #MEDICAMENTOS ORDER BY id
        IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'OTR', @idT = id FROM #OTROSSER ORDER BY id
        IF COALESCE(@idT,0)>0
        BEGIN
            PRINT 'FACTURA NO PAQUETIZADA: asigno copago de encabezado al primer servicio (' + COALESCE(@pro,'') + ') valor=' + CAST(@VALORCOPAGO AS VARCHAR(20))
            IF @pro='CON' UPDATE #CONSULTAS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
            IF @pro='PRO' UPDATE #PROCEDIMIENTOS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
            IF @pro='MED' UPDATE #MEDICAMENTOS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
            IF @pro='OTR' UPDATE #OTROSSER SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
        END
    END

    IF ABS(@VALORCOPAGO-@VALORCOPAGOACU)<1000 AND   COALESCE(@CPROPIO,0)=0
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

    IF COALESCE(@CPROPIO,0)=1 OR COALESCE(@PAQUETE,0)=1
    BEGIN
        print ' entre por copago propio PAQUETIZADO: anulo copagos por linea y conceptos en 05'
        UPDATE #CONSULTAS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
        UPDATE #PROCEDIMIENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
        UPDATE #MEDICAMENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
        UPDATE #OTROSSER SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0

    END
    ELSE IF COALESCE(@CPROPIO,0)=1 AND COALESCE(@PAQUETE,0)=0
    BEGIN
        PRINT 'COPAGO PROPIO NO PAQUETIZADO: conservo copagos por linea desde FTRDC'
        UPDATE #CONSULTAS SET conceptoRecaudo=CASE WHEN COALESCE(valorPagoModerador,0)=0 THEN '05' WHEN conceptoRecaudo IN ('01','02') THEN conceptoRecaudo ELSE COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') END WHERE 1=1
        UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=CASE WHEN COALESCE(valorPagoModerador,0)=0 THEN '05' WHEN conceptoRecaudo IN ('01','02') THEN conceptoRecaudo ELSE COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') END WHERE 1=1
        UPDATE #MEDICAMENTOS SET conceptoRecaudo=CASE WHEN COALESCE(valorPagoModerador,0)=0 THEN '05' WHEN conceptoRecaudo IN ('01','02') THEN conceptoRecaudo ELSE COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') END WHERE 1=1
        UPDATE #OTROSSER SET conceptoRecaudo=CASE WHEN COALESCE(valorPagoModerador,0)=0 THEN '05' WHEN conceptoRecaudo IN ('01','02') THEN conceptoRecaudo ELSE COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') END WHERE 1=1
    END
    ELSE
    BEGIN
        PRINT ' NO TIENE COPAGO PROPIO '
        UPDATE #CONSULTAS SET conceptoRecaudo=@conceptoRecaudo WHERE COALESCE(valorPagoModerador,0)>0 AND conceptoRecaudo NOT IN ('01','02')
        UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=@conceptoRecaudo WHERE COALESCE(valorPagoModerador,0)>0 AND conceptoRecaudo NOT IN ('01','02')
        UPDATE #MEDICAMENTOS SET conceptoRecaudo=@conceptoRecaudo WHERE COALESCE(valorPagoModerador,0)>0 AND conceptoRecaudo NOT IN ('01','02')
        UPDATE #OTROSSER SET conceptoRecaudo=@conceptoRecaudo WHERE COALESCE(valorPagoModerador,0)>0 AND conceptoRecaudo NOT IN ('01','02')
    END
    print '-- coloca los conceptos 05 cuando el valor esta en 0 '
    IF (COALESCE(@CAPITADA,0)=1 OR COALESCE(@PAQUETE,0)=1)
    BEGIN
        PRINT 'FACTURA CAPITADA PAQUETIZADA: anulo vrServicio en detalle RIPS'
        UPDATE #CONSULTAS SET vrServicio=0,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #PROCEDIMIENTOS SET vrServicio=0 ,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #MEDICAMENTOS SET vrServicio=0,vrUnitMedicamento=0 ,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #OTROSSER SET vrServicio=0, vrUnitOS=0,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
    END
    ELSE
    BEGIN
        PRINT 'FACTURA NO PAQUETIZADA: conservo vrServicio en detalle RIPS (CAPITADA='+CAST(@CAPITADA AS VARCHAR(2))+', PAQUETE='+CAST(@PAQUETE AS VARCHAR(2))+')'
        UPDATE #CONSULTAS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #MEDICAMENTOS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
        UPDATE #OTROSSER SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
    END
    print 'reviso la variable PGP_MOD_Y_COP_PROPIO : ' + coalesce(DBO.FNK_VALORVARIABLE('PGP_MOD_Y_COP_PROPIO') ,'')

    IF (COALESCE(@CPROPIO,0)=1 OR COALESCE(@PAQUETE,0)=1 )AND DBO.FNK_VALORVARIABLE('PGP_MOD_Y_COP_PROPIO')= 'SI'
    BEGIN
       PRINT '--- AHORA COLOCO LOS COPAGOS Y MODERADORAS SI SE CALCULARON EN FTR (PAQUETIZADA)'
        PRINT ' VALORES DE FACTURA COPAGOS : ' + STR( @VALORCOPAGOFTR  )  + '   MODERADADORA : ' + STR ( @VALORMODERADORAFTR ) + '----------------------------------------'
        
       -- if exists (select top 1 1 from @RECAUDO )  truncate table @RECAUDO
        INSERT INTO @RECAUDO  
            SELECT valorPagoModerador ,'CON' PROCe , ID FROM  #CONSULTAS    
            UNION ALL
            SELECT valorPagoModerador ,'PRO' PROCe , ID FROM  #PROCEDIMIENTOS   
            UNION ALL
            SELECT valorPagoModerador ,'MED' PROCe , ID FROM  #MEDICAMENTOS 
            UNION ALL
            SELECT valorPagoModerador ,'OTR' PROCe , ID FROM  #OTROSSER 
        PRINT @@ROWCOUNT

        --SELECT @VLCOPAGO = SUM( CASE conceptoRecaudo WHEN '01' THEN valorPagoModerador ELSE 0 END ) 
        --        , @VLMODERADORA = SUM( CASE conceptoRecaudo WHEN '02' THEN valorPagoModerador ELSE 0 END ) 
        --        , @VLANTICIPO = SUM( CASE conceptoRecaudo WHEN '05' THEN valorPagoModerador ELSE 0 END ) 
        --FROM @RECAUDO
        SELECT @VALORCOPAGOFTR = COALESCE(
            NULLIF((SELECT SUM(COPAGOS_CP) FROM FTRD WHERE N_FACTURA = @N_FACTURA), 0),
            @VALORCOPAGOFTR,
            @VALORCOPAGO,
            0
        )
        IF @VALORCOPAGOFTR> 0 
        BEGIN
            SET @idT =0
            select top 1 @pro = proce , @idT =id  from @RECAUDO  
            if @pro='CON' UPDATE #CONSULTAS set valorPagoModerador = @VALORCOPAGOFTR , conceptoRecaudo =@ESMODERADORAENFTR  where  @idT =id  
            if @pro='PRO' UPDATE #PROCEDIMIENTOS set valorPagoModerador = @VALORCOPAGOFTR , conceptoRecaudo =@ESMODERADORAENFTR  where  @idT =id  
            if @pro='MED' UPDATE #MEDICAMENTOS set valorPagoModerador = @VALORCOPAGOFTR , conceptoRecaudo =@ESMODERADORAENFTR  where  @idT =id  
            if @pro='OTR' UPDATE #OTROSSER set valorPagoModerador = @VALORCOPAGOFTR , conceptoRecaudo =@ESMODERADORAENFTR  where  @idT =id  
            UPDATE @RECAUDO SET valorPagoModerador = @VALORCOPAGOFTR  where  @idT =id  
            PRINT 'COLOQUE EL COPAGO EN ' +@PRO + '  CON EL VALOR DE  : ' +STR(@VALORCOPAGOFTR)  +  ' CON EL CONCEPTO RECAUDO DE LA FACTURA ' + @ESMODERADORAENFTR
        END
        IF @VALORMODERADORAFTR> 0 
        BEGIN
            SET @idT =0
            select top 1 @pro = proce , @idT =id  from @recaudo WHERE  valorPagoModerador=0
            if @pro='CON' UPDATE #CONSULTAS set valorPagoModerador = @VALORMODERADORAFTR , conceptoRecaudo ='02'  where  @idT =id  
            if @pro='PRO' UPDATE #PROCEDIMIENTOS set valorPagoModerador = @VALORMODERADORAFTR , conceptoRecaudo ='02'  where  @idT =id  
            if @pro='MED' UPDATE #MEDICAMENTOS set valorPagoModerador = @VALORMODERADORAFTR , conceptoRecaudo ='02'  where  @idT =id  
            if @pro='OTR' UPDATE #OTROSSER set valorPagoModerador = @VALORMODERADORAFTR , conceptoRecaudo ='02'  where  @idT =id  
            UPDATE @RECAUDO SET valorPagoModerador = @VALORMODERADORAFTR  where  @idT =id  
             PRINT 'COLOQUE LA MODERADORA EN ' +@PRO+ '  CON EL VALOR DE  : ' +STR(@VALORMODERADORAFTR)  +  ' CON EL CONCEPTO RECAUDO DE LA FACTURA ' + '02'
        END


    END

    /* Evento: servicios desde FTRDJSON. Capita/PGP: solo FTRDC (evita duplicar lineas y fechas US mm/dd/yyyy). */
    IF COALESCE(@CAPITADA, 0) = 1
    BEGIN
      INSERT INTO #MEDICAMENTOS
      (  codPrestador,numAutorizacion,IDAFILIADO,CONSECUTIVO,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                    ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                    ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                                    ,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
      )
      SELECT  @IDPRESTADOR,numAutorizacion,IDAFILIADO,IDAFI_EXT,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                                    ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                                    ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,0
                                    ,0,conceptoRecaudo,'04',valorPagoModerador,numFEVPagoModerador
      FROM FTRDJSON
      CROSS APPLY OPENJSON(JSON_SER,'$.medicamentos')
      WITH (
      codPrestador VARCHAR(20),
      numAutorizacion VARCHAR(50),
      idMIPRES VARCHAR(50),
      fechaDispensAdmon VARCHAR(20),
      codDiagnosticoPrincipal VARCHAR(10),
      codDiagnosticoRelacionado VARCHAR(10),
      tipoMedicamento VARCHAR(2),
      codTecnologiaSalud VARCHAR(50),
      nomTecnologiaSalud VARCHAR(255),
      concentracionMedicamento DECIMAL(18,2),
      unidadMedida INT,
      formaFarmaceutica VARCHAR(20),
      unidadMinDispensa INT,
      cantidadMedicamento INT,
      diasTratamiento INT,
      tipoDocumentoIdentificacion VARCHAR(5),
      numDocumentoIdentificacion VARCHAR(20),
      vrUnitMedicamento DECIMAL(18,2),
      vrServicio DECIMAL(18,2),
      conceptoRecaudo VARCHAR(5),
      valorPagoModerador DECIMAL(18,2),
      numFEVPagoModerador VARCHAR(50),
      consecutivo INT
      )
      WHERE CNSFTR=@CNSFCT


         INSERT INTO #CONSULTAS (codPrestador,CONSECUTIVO,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,conceptoRecaudo,valorPagoModerador, 	tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador
         )
         SELECT @IDPRESTADOR,IDAFI_EXT,IDAFILIADO,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                                finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                                codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,0,conceptoRecaudo,0,tipoDocumentoIdentificacion, numDocumentoIdentificacion,
                             numFEVPagoModerador
         FROM FTRDJSON
         CROSS APPLY OPENJSON(JSON_SER,'$.consultas')
         WITH (
             codPrestador VARCHAR(20),
             fechaInicioAtencion VARCHAR(20),
             numAutorizacion VARCHAR(50),
             codConsulta VARCHAR(20),
             modalidadGrupoServicioTecSal VARCHAR(5),
             grupoServicios VARCHAR(5),
             codServicio VARCHAR(10),
             finalidadTecnologiaSalud VARCHAR(5),
             causaMotivoAtencion VARCHAR(5),
             codDiagnosticoPrincipal VARCHAR(10),
             codDiagnosticoRelacionado1 VARCHAR(10),
             codDiagnosticoRelacionado2 VARCHAR(10),
             codDiagnosticoRelacionado3 VARCHAR(10),
             tipoDiagnosticoPrincipal VARCHAR(5),
             tipoDocumentoIdentificacion VARCHAR(5),
             numDocumentoIdentificacion VARCHAR(20),
             vrServicio DECIMAL(18,2),
             conceptoRecaudo VARCHAR(5),
             valorPagoModerador DECIMAL(18,2),
             numFEVPagoModerador VARCHAR(50),
             consecutivo INT
         ) C
         WHERE CNSFTR=@CNSFCT

         INSERT INTO #PROCEDIMIENTOS
         (codPrestador,IDAFILIADO,CONSECUTIVO,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,conceptoRecaudo,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
         )
         SELECT  @IDPRESTADOR,IDAFILIADO,IDAFI_EXT,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,viaIngresoServicioSalud
                      ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
                      ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,0,conceptoRecaudo,'04',valorPagoModerador,numFEVPagoModerador
         FROM FTRDJSON
         CROSS APPLY OPENJSON(JSON_SER,'$.procedimientos')
         WITH (
             codPrestador VARCHAR(20),
             fechaInicioAtencion VARCHAR(20),
             numAutorizacion VARCHAR(50),
             codProcedimiento VARCHAR(20),
             viaIngresoServicioSalud VARCHAR(5),
             modalidadGrupoServicioTecSal VARCHAR(5),
             grupoServicios VARCHAR(5),
             codServicio VARCHAR(10),
             idMIPRES VARCHAR(20),
             finalidadTecnologiaSalud VARCHAR(5),
             tipoDocumentoIdentificacion VARCHAR(5),
             numDocumentoIdentificacion VARCHAR(20),
             codDiagnosticoPrincipal VARCHAR(10),
             codDiagnosticoRelacionado VARCHAR(10),
             codComplicacion VARCHAR(10),
             vrServicio DECIMAL(18,2),
             conceptoRecaudo VARCHAR(5),
             valorPagoModerador DECIMAL(18,2),
             numFEVPagoModerador VARCHAR(50),
             consecutivo INT
         ) P
         WHERE CNSFTR=@CNSFCT


         INSERT INTO #OTROSSER (codPrestador,IDAFILIADO,CONSECUTIVO,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,conceptoRecaudo,tipoPagoModerador
                            ,valorPagoModerador,numFEVPagoModerador )
         SELECT @IDPRESTADOR,IDAFILIADO,IDAFI_EXT,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                            ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,0,conceptoRecaudo,'04'
                            ,valorPagoModerador,numFEVPagoModerador
         FROM FTRDJSON
         CROSS APPLY OPENJSON(JSON_SER,'$.otrosServicios')
         WITH (
             codPrestador VARCHAR(20),
             numAutorizacion VARCHAR(50),
             idMIPRES VARCHAR(50),
             fechaSuministroTecnologia VARCHAR(20),
             tipoOS VARCHAR(5),
             codTecnologiaSalud VARCHAR(50),
             nomTecnologiaSalud VARCHAR(255),
             cantidadOS INT,
             tipoDocumentoIdentificacion VARCHAR(5),
             numDocumentoIdentificacion VARCHAR(20),
             vrUnitOS DECIMAL(18,2),
             vrServicio DECIMAL(18,2),
             conceptoRecaudo VARCHAR(5),
             valorPagoModerador DECIMAL(18,2),
             numFEVPagoModerador VARCHAR(50),
             consecutivo INT
         ) O
         WHERE CNSFTR=@CNSFCT
    END

    IF COALESCE(@CPROPIO,0)=0
    BEGIN
       IF COALESCE(@VALORCOPAGO,0)=0 AND COALESCE(@VALORCOPAGOFTR,0)=0 AND COALESCE(@VALORMODERADORAFTR,0)=0
       BEGIN
           PRINT 'SIN RECAUDO EN FTR: anulo valorPagoModerador post FTRDJSON'
           UPDATE #CONSULTAS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
           UPDATE #PROCEDIMIENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
           UPDATE #MEDICAMENTOS SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
           UPDATE #OTROSSER SET conceptoRecaudo='05',valorPagoModerador=0 WHERE valorPagoModerador>=0
       END
       print '-- coloca los conceptos 05 cuando el valor esta en 0 (post FTRDJSON) '
       IF COALESCE(@CAPITADA,0)=1 OR COALESCE(@PAQUETE,0)=1
       BEGIN
           UPDATE #CONSULTAS SET vrServicio=0,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #PROCEDIMIENTOS SET vrServicio=0 ,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #MEDICAMENTOS SET vrServicio=0,vrUnitMedicamento=0 ,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #OTROSSER SET vrServicio=0, vrUnitOS=0,conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
       END
       ELSE
       BEGIN
           UPDATE #CONSULTAS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #PROCEDIMIENTOS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #MEDICAMENTOS SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
           UPDATE #OTROSSER SET conceptoRecaudo=CASE WHEN valorPagoModerador >0 THEN conceptoRecaudo ELSE '05' END WHERE 1=1
       END

       IF COALESCE(@PAQUETE,0)=0 AND COALESCE(@VALORCOPAGO,0)>0  
       BEGIN
           SELECT @VALORCOPAGOACU=COALESCE(SUM(valorPagoModerador),0) FROM #CONSULTAS
           SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #PROCEDIMIENTOS
           SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #MEDICAMENTOS
           SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(valorPagoModerador),0) FROM #OTROSSER

           IF COALESCE(@VALORCOPAGOACU,0)=0
           BEGIN
               SET @idT = 0
               SET @pro = NULL
               SELECT TOP 1 @pro = 'CON', @idT = id FROM #CONSULTAS ORDER BY id
               IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'PRO', @idT = id FROM #PROCEDIMIENTOS ORDER BY id
               IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'MED', @idT = id FROM #MEDICAMENTOS ORDER BY id
               IF COALESCE(@idT,0)=0 SELECT TOP 1 @pro = 'OTR', @idT = id FROM #OTROSSER ORDER BY id
               IF COALESCE(@idT,0)>0
               BEGIN
                   PRINT 'POST FTRDJSON NO PAQUETIZADA: asigno copago de encabezado al primer servicio (' + COALESCE(@pro,'') + ')'
                   IF @pro='CON' UPDATE #CONSULTAS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
                   IF @pro='PRO' UPDATE #PROCEDIMIENTOS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
                   IF @pro='MED' UPDATE #MEDICAMENTOS SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
                   IF @pro='OTR' UPDATE #OTROSSER SET valorPagoModerador = @VALORCOPAGO, conceptoRecaudo = COALESCE(NULLIF(@ESMODERADORAENFTR,''), @conceptoRecaudo, '05') WHERE id = @idT
               END
           END
       END
   END
    print 'reviso la variable PGP_MOD_Y_COP_PROPIO : ' + coalesce(DBO.FNK_VALORVARIABLE('PGP_MOD_Y_COP_PROPIO') ,'')

    /* Capita/PGP sin copago propio: cuadrar totales RIPS con FTR (validaci?n RVG09 SISPRO) */
    IF COALESCE(@CAPITADA, 0) = 1 AND COALESCE(@CPROPIO, 0) = 0
    BEGIN
        SELECT
            @VALORCOPAGOFTR = COALESCE(VALORCOPAGO, 0),
            @VALORMODERADORAFTR = COALESCE(VALORMODERADORA, 0)
        FROM FTR
        WHERE N_FACTURA = @N_FACTURA;

        DECLARE @SUM_RIPS_01 DECIMAL(14, 2) = 0;
        DECLARE @SUM_RIPS_02 DECIMAL(14, 2) = 0;
        DECLARE @DIF_RIPS DECIMAL(14, 2) = 0;
        DECLARE @ID_AJU_RIPS INT = 0;

        SELECT @SUM_RIPS_02 = COALESCE(SUM(CASE WHEN R.conceptoRecaudo = '02' THEN TRY_CAST(R.valorPagoModerador AS DECIMAL(14, 2)) ELSE 0 END), 0)
        FROM (
            SELECT conceptoRecaudo, valorPagoModerador FROM #CONSULTAS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #PROCEDIMIENTOS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #MEDICAMENTOS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #OTROSSER
        ) R;

        IF COALESCE(@VALORMODERADORAFTR, 0) > 0
           AND ABS(@SUM_RIPS_02 - @VALORMODERADORAFTR) >= 0.01
        BEGIN
            PRINT N'RIPS RVG09: ajuste moderadora detalle. RIPS=' + CAST(@SUM_RIPS_02 AS VARCHAR(20))
                + N' FTR=' + CAST(@VALORMODERADORAFTR AS VARCHAR(20));

            IF @SUM_RIPS_02 > 0
            BEGIN
                UPDATE #CONSULTAS
                SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORMODERADORAFTR / @SUM_RIPS_02, 0)
                WHERE conceptoRecaudo = '02'
                  AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

                UPDATE #PROCEDIMIENTOS
                SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORMODERADORAFTR / @SUM_RIPS_02, 0)
                WHERE conceptoRecaudo = '02'
                  AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

                UPDATE #MEDICAMENTOS
                SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORMODERADORAFTR / @SUM_RIPS_02, 0)
                WHERE conceptoRecaudo = '02'
                  AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

                UPDATE #OTROSSER
                SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORMODERADORAFTR / @SUM_RIPS_02, 0)
                WHERE conceptoRecaudo = '02'
                  AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

                SELECT @SUM_RIPS_02 = COALESCE(SUM(CASE WHEN R.conceptoRecaudo = '02' THEN TRY_CAST(R.valorPagoModerador AS DECIMAL(14, 2)) ELSE 0 END), 0)
                FROM (
                    SELECT conceptoRecaudo, valorPagoModerador FROM #CONSULTAS
                    UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #PROCEDIMIENTOS
                    UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #MEDICAMENTOS
                    UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #OTROSSER
                ) R;

                SET @DIF_RIPS = @VALORMODERADORAFTR - @SUM_RIPS_02;

                IF ABS(@DIF_RIPS) >= 0.01
                BEGIN
                    SELECT TOP 1 @ID_AJU_RIPS = id
                    FROM #CONSULTAS
                    WHERE conceptoRecaudo = '02'
                      AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                    ORDER BY id;

                    IF COALESCE(@ID_AJU_RIPS, 0) > 0
                        UPDATE #CONSULTAS
                        SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                        WHERE id = @ID_AJU_RIPS;
                    ELSE
                    BEGIN
                        SELECT TOP 1 @ID_AJU_RIPS = id
                        FROM #PROCEDIMIENTOS
                        WHERE conceptoRecaudo = '02'
                          AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                        ORDER BY id;

                        IF COALESCE(@ID_AJU_RIPS, 0) > 0
                            UPDATE #PROCEDIMIENTOS
                            SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                            WHERE id = @ID_AJU_RIPS;
                    END
                END
            END
        END

        SELECT @SUM_RIPS_01 = COALESCE(SUM(CASE WHEN R.conceptoRecaudo = '01' THEN TRY_CAST(R.valorPagoModerador AS DECIMAL(14, 2)) ELSE 0 END), 0)
        FROM (
            SELECT conceptoRecaudo, valorPagoModerador FROM #CONSULTAS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #PROCEDIMIENTOS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #MEDICAMENTOS
            UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #OTROSSER
        ) R;

        IF COALESCE(@VALORCOPAGOFTR, 0) > 0
           AND ABS(@SUM_RIPS_01 - @VALORCOPAGOFTR) >= 0.01
           AND @SUM_RIPS_01 > 0
        BEGIN
            PRINT N'RIPS RVG09: ajuste copago detalle. RIPS=' + CAST(@SUM_RIPS_01 AS VARCHAR(20))
                + N' FTR=' + CAST(@VALORCOPAGOFTR AS VARCHAR(20));

            UPDATE #CONSULTAS
            SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORCOPAGOFTR / @SUM_RIPS_01, 0)
            WHERE conceptoRecaudo = '01'
              AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

            UPDATE #PROCEDIMIENTOS
            SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORCOPAGOFTR / @SUM_RIPS_01, 0)
            WHERE conceptoRecaudo = '01'
              AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

            UPDATE #MEDICAMENTOS
            SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORCOPAGOFTR / @SUM_RIPS_01, 0)
            WHERE conceptoRecaudo = '01'
              AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

            UPDATE #OTROSSER
            SET valorPagoModerador = ROUND(TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) * @VALORCOPAGOFTR / @SUM_RIPS_01, 0)
            WHERE conceptoRecaudo = '01'
              AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0;

            SELECT @SUM_RIPS_01 = COALESCE(SUM(CASE WHEN R.conceptoRecaudo = '01' THEN TRY_CAST(R.valorPagoModerador AS DECIMAL(14, 2)) ELSE 0 END), 0)
            FROM (
                SELECT conceptoRecaudo, valorPagoModerador FROM #CONSULTAS
                UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #PROCEDIMIENTOS
                UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #MEDICAMENTOS
                UNION ALL SELECT conceptoRecaudo, valorPagoModerador FROM #OTROSSER
            ) R;

            SET @DIF_RIPS = @VALORCOPAGOFTR - @SUM_RIPS_01;
            SET @ID_AJU_RIPS = 0;

            IF ABS(@DIF_RIPS) >= 0.01
            BEGIN
                SELECT TOP 1 @ID_AJU_RIPS = id
                FROM #CONSULTAS
                WHERE conceptoRecaudo = '01'
                  AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                ORDER BY id;

                IF COALESCE(@ID_AJU_RIPS, 0) > 0
                    UPDATE #CONSULTAS
                    SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                    WHERE id = @ID_AJU_RIPS;
                ELSE
                BEGIN
                    SELECT TOP 1 @ID_AJU_RIPS = id
                    FROM #PROCEDIMIENTOS
                    WHERE conceptoRecaudo = '01'
                      AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                    ORDER BY id;

                    IF COALESCE(@ID_AJU_RIPS, 0) > 0
                        UPDATE #PROCEDIMIENTOS
                        SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                        WHERE id = @ID_AJU_RIPS;
                    ELSE
                    BEGIN
                        SELECT TOP 1 @ID_AJU_RIPS = id
                        FROM #MEDICAMENTOS
                        WHERE conceptoRecaudo = '01'
                          AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                        ORDER BY id;

                        IF COALESCE(@ID_AJU_RIPS, 0) > 0
                            UPDATE #MEDICAMENTOS
                            SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                            WHERE id = @ID_AJU_RIPS;
                        ELSE
                        BEGIN
                            SELECT TOP 1 @ID_AJU_RIPS = id
                            FROM #OTROSSER
                            WHERE conceptoRecaudo = '01'
                              AND TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) > 0
                            ORDER BY id;

                            IF COALESCE(@ID_AJU_RIPS, 0) > 0
                                UPDATE #OTROSSER
                                SET valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14, 2)) + @DIF_RIPS
                                WHERE id = @ID_AJU_RIPS;
                        END
                    END
                END
            END
        END
    END

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

    PRINT 'TERMINE DE PREPARAR LOS DATOS '+CAST(GETDATE() AS VARCHAR(20))

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

    --MEDICAMENTOS
    INSERT INTO #MEDICAMENTOS2(codPrestador ,	numAutorizacion, IDAFILIADO ,	CONSECUTIVO,	idMIPRES ,	fechaDispensAdmon,	codDiagnosticoPrincipal ,	codDiagnosticoRelacionado,
             tipoMedicamento,	codTecnologiaSalud,	nomTecnologiaSalud,	concentracionMedicamento ,	unidadMedida ,	formaFarmaceutica,	unidadMinDispensa ,
             cantidadMedicamento,	diasTratamiento,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,	vrUnitMedicamento,	vrServicio,	conceptoRecaudo,
             tipoPagoModerador,	valorPagoModerador,	numFEVPagoModerador ,	usuarioId ,   ID  ,   xconsecutivo)
    SELECT codPrestador , numAutorizacion,	IDAFILIADO ,	CONSECUTIVO,	idMIPRES ,	fechaDispensAdmon,	codDiagnosticoPrincipal ,	codDiagnosticoRelacionado,
         tipoMedicamento,	codTecnologiaSalud,	nomTecnologiaSalud,	concentracionMedicamento ,	unidadMedida ,	formaFarmaceutica,	unidadMinDispensa ,
         cantidadMedicamento,	diasTratamiento,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,	vrUnitMedicamento,	vrServicio,	conceptoRecaudo,
         tipoPagoModerador,	valorPagoModerador,	numFEVPagoModerador ,	usuarioId ,   ID  ,    ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #MEDICAMENTOS

    --OTROS SERVICIOS
    INSERT INTO #OTROSSER2(codPrestador,	IDAFILIADO ,	CONSECUTIVO,	numAutorizacion,	idMIPRES,	fechaSuministroTecnologia,	tipoOS,	
          codTecnologiaSalud,nomTecnologiaSalud ,	cantidadOS,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,
          vrUnitOS, 	vrServicio, 	conceptoRecaudo,	tipoPagoModerador, valorPagoModerador,	numFEVPagoModerador,	usuarioId ,
          ID , xconsecutivo)
    SELECT codPrestador,	IDAFILIADO ,	CONSECUTIVO,	numAutorizacion,	idMIPRES,	fechaSuministroTecnologia,	tipoOS,	
          codTecnologiaSalud,nomTecnologiaSalud ,	cantidadOS,	tipoDocumentoIdentificacion,	numDocumentoIdentificacion,
          vrUnitOS, 	vrServicio, 	conceptoRecaudo,	tipoPagoModerador, valorPagoModerador,	numFEVPagoModerador,	usuarioId ,
          ID , ROW_NUMBER() OVER(PARTITION BY IDAFILIADO ORDER BY IDAFILIADO ASC)
    FROM #OTROSSER


    PRINT 'VOY POR LO QUE ESTA EN FTRDJSON'



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

    /* RVC014: ajuste fechas servicio al periodo (tablas finales antes del FOR JSON) */
    IF @FECHAINICAP IS NOT NULL AND @FECHAFINCAP IS NOT NULL
    BEGIN
        PRINT N'RIPS RVC014: ajuste fechas servicio al periodo '
            + CONVERT(VARCHAR(10), CAST(@FECHAINICAP AS DATE), 23)
            + N' - '
            + CONVERT(VARCHAR(10), CAST(@FECHAFINCAP AS DATE), 23);

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

    /* Finalidades inv?lidas: SISPRO exige exactamente 2 caracteres (RVG01). */
    UPDATE C
       SET finalidadTecnologiaSalud = '12'
    FROM #CONSULTAS2 C
    WHERE NULLIF(LTRIM(RTRIM(C.finalidadTecnologiaSalud)), '') IS NULL
       OR TRY_CONVERT(INT, C.finalidadTecnologiaSalud) IS NULL
       OR LEN(LTRIM(RTRIM(C.finalidadTecnologiaSalud))) <> 2;

    UPDATE P
       SET finalidadTecnologiaSalud = '16'
    FROM #PROCEDIMIENTOS2 P
    WHERE NULLIF(LTRIM(RTRIM(P.finalidadTecnologiaSalud)), '') IS NULL
       OR TRY_CONVERT(INT, P.finalidadTecnologiaSalud) NOT BETWEEN 12 AND 44
       OR P.finalidadTecnologiaSalud = '21'
       OR LEN(LTRIM(RTRIM(P.finalidadTecnologiaSalud))) <> 2;

    /*
       Normalizaci?n SISPRO - usuarios: numDocumentoIdentificacion solo letras y n?meros.
       Quita espacios internos, tabuladores y caracteres de control antes de FNK_LIMPIATEXTO.
    */
    UPDATE U
       SET tipoDocumentoIdentificacion = UPPER(LTRIM(RTRIM(U.tipoDocumentoIdentificacion)))
    FROM #USUARIOS U
    WHERE U.tipoDocumentoIdentificacion <> UPPER(LTRIM(RTRIM(U.tipoDocumentoIdentificacion)));

    UPDATE U
       SET numDocumentoIdentificacion = LIMPIO.docLimpio
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
    BEGIN
        RAISERROR(N'N?mero de documento de usuario vac?o o inv?lido tras normalizaci?n RIPS.', 16, 1);
        RETURN;
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
                                            c.fechaInicioAtencion,
                                            LEFT(REPLACE(REPLACE(REPLACE(REPLACE(c.numAutorizacion, CHAR(10), ''), '/', '-'), CHAR(13), ''), CHAR(9), '') ,30) numAutorizacion,
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
                                            p.fechaInicioAtencion,
                                            p.idMIPRES,
                                            LEFT(REPLACE(REPLACE(REPLACE(REPLACE(p.numAutorizacion, CHAR(10), ''), '/', '-'), CHAR(13), ''), CHAR(9), '') ,30) numAutorizacion,
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
                                            ur.fechaInicioAtencion,
                                            ur.causaMotivoAtencion,                                            
                                            ISNULL( NULLIF(ur.codDiagnosticoPrincipal,''), 'null')codDiagnosticoPrincipal,
                                            ISNULL( NULLIF(ur.codDiagnosticoPrincipalE,''), 'null')codDiagnosticoPrincipalE,                                          
                                            ISNULL( NULLIF(ur.codDiagnosticoRelacionadoE1,''), 'null')codDiagnosticoRelacionadoE1,
                                            ISNULL( NULLIF(ur.codDiagnosticoRelacionadoE2,''), 'null') codDiagnosticoRelacionadoE2,
                                            ISNULL( NULLIF(ur.codDiagnosticoRelacionadoE3,''), 'null') codDiagnosticoRelacionadoE3,
                                            ur.condicionDestinoUsuarioEgreso,
                                            ISNULL( NULLIF(ur.codDiagnosticoCausaMuerte,''), 'null') codDiagnosticoCausaMuerte, -- STORRES 20260616 se agrega condicion para cambiar NULL DE SQL O VACIO POR EL TEXTO NULL
                                            ur.fechaEgreso,
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
                                            h.fechaInicioAtencion, -- STORRES 20260610 SE CAMBIA DE LUGAR PARA COORDINAR CON LA ESTRUCUTRA SEGUN RESOL
                                            LEFT(REPLACE(REPLACE(REPLACE(REPLACE(h.numAutorizacion, CHAR(10), ''), '/', '-'), CHAR(13), ''), CHAR(9), '') ,30) numAutorizacion,
                                            h.causaMotivoAtencion,
                                            h.codDiagnosticoPrincipal,
                                            ISNULL( NULLIF(h.codDiagnosticoPrincipalE,''), 'null') codDiagnosticoPrincipalE,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE1,''), 'null') codDiagnosticoRelacionadoE1,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE2,''), 'null') codDiagnosticoRelacionadoE2,
                                            ISNULL( NULLIF(h.codDiagnosticoRelacionadoE3,''), 'null') codDiagnosticoRelacionadoE3,
                                            ISNULL( NULLIF(h.codComplicacion,''), 'null') codComplicacion,
                                            h.condicionDestinoUsuarioEgreso, -- STORRES 20260610 SE CAMBIA DE LUGAR PARA COORDINAR CON LA ESTRUCUTRA SEGUN RESOL
                                            ISNULL( NULLIF(h.codDiagnosticoCausaMuerte,''), 'null') codDiagnosticoCausaMuerte,
                                            h.fechaEgreso,
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
                                        ORDER BY r.xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    medicamentos = (
                                        SELECT 
                                            m.codPrestador,
                                            m.idMIPRES,
                                            m.fechaDispensAdmon,
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
                                            REPLACE(m.nomTecnologiaSalud,'\','')nomTecnologiaSalud,
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
                                        ORDER BY M.xconsecutivo
                                        FOR JSON PATH
                                    ),
                                    otrosServicios = (
                                        SELECT 
                                            os.codPrestador,
                                            LEFT(REPLACE(REPLACE(REPLACE(REPLACE(os.numAutorizacion, CHAR(10), ''), '/', '-'), CHAR(13), ''), CHAR(9), '') ,30) numAutorizacion,
                                            os.idMIPRES,
                                            os.fechaSuministroTecnologia,
                                            os.tipoOS,
                                            os.codTecnologiaSalud,
                                            REPLACE(os.nomTecnologiaSalud,'\','')nomTecnologiaSalud,
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
                                        ORDER BY os.xconsecutivo
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




    --IF DATEDIFF(SECOND, @INICIO_EJECUCION, SYSDATETIME()) > 60
    --BEGIN
    --    IF EXISTS (SELECT 1 FROM FTRJSON WHERE CNSFCT = @CNSFCT)
    --    BEGIN
    --        UPDATE FTRJSON 
    --        SET JSON_ENVIO = @PLANO,
    --            SINENVIO = 1
    --        WHERE CNSFCT = @CNSFCT;
    --    END
    --    ELSE
    --    BEGIN
    --        INSERT INTO FTRJSON (CNSFCT, JSON_ENVIO, SINENVIO)
    --        VALUES (@CNSFCT, @PLANO, 1);
    --    END
    --    PRINT 'CACHE: Ejecuci?n tard? m?s de 60s (' 
    --          + CAST(DATEDIFF(SECOND, @INICIO_EJECUCION, SYSDATETIME()) AS VARCHAR(10)) 
    --          + 's), RIPS guardado en FTRJSON (sin base64) con SINENVIO=1'
    --END
    -- === FIN CACHE ===

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
    PRINT 'FINALIZO EN SPK_RIPS_JSON_FTR_PGP'

    -- === Limpieza expl?cita ===
    DROP TABLE IF EXISTS #HC_POR_ADMISION;
    DROP TABLE IF EXISTS #TODAS_HC;
    DROP TABLE IF EXISTS #USUARIOS;
    DROP TABLE IF EXISTS #CONSULTAS;
    DROP TABLE IF EXISTS #CONSULTAS2;
    DROP TABLE IF EXISTS #CONSULTAS1;
    DROP TABLE IF EXISTS #MEDICAMENTOS;
    DROP TABLE IF EXISTS #MEDICAMENTOS2;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS2;
    DROP TABLE IF EXISTS #PROCEDIMIENTOS1;
    DROP TABLE IF EXISTS #URGENCIAS;
    DROP TABLE IF EXISTS #HOSPITALIZACION;
    DROP TABLE IF EXISTS #RECIEN;
    DROP TABLE IF EXISTS #OTROSSER;
    DROP TABLE IF EXISTS #OTROSSER2;
    DROP TABLE IF EXISTS #DX;
    DROP TABLE IF EXISTS #MODERADORAS;
END
