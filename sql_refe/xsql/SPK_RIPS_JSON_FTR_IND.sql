CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_FTR_IND
@N_FACTURA  VARCHAR(20),
@URL_PATH VARCHAR(MAX)=NULL,
@PLANO NVARCHAR(MAX) OUTPUT
AS 
DECLARE @NOADMISION VARCHAR(20)
DECLARE @PROCEDENCIA VARCHAR(20)
DECLARE @NFACTURA VARCHAR(20)=NULL
DECLARE @MEDICA AS NVARCHAR(MAX)
DECLARE @PROCEDI AS NVARCHAR(MAX)
DECLARE @URGEN AS NVARCHAR(MAX)
DECLARE @HOSPITA AS NVARCHAR(MAX)
DECLARE @RECIEN  AS NVARCHAR(MAX)
DECLARE @OTROSER AS NVARCHAR(MAX)
DECLARE @IDTERINSTA VARCHAR(20)
DECLARE @TIPODOC VARCHAR(2)
DECLARE @DOCIDAFILIADO VARCHAR(20)
DECLARE @TIPOUSU VARCHAR(2)
DECLARE @FNACIMIENTO VARCHAR(10)
DECLARE @SEXO VARCHAR(1) --M --F
DECLARE @MUNICIPIO VARCHAR(5)
DECLARE @CIUDADNAC VARCHAR(5)
DECLARE @ZONA VARCHAR(20) --01 RURAL -- 02 URBANO
DECLARE @CODPAISORIGEN VARCHAR(5) 
DECLARE @CODPAISRESIDENCIA VARCHAR(5) 
DECLARE @INCAPACIDAD VARCHAR(2) --SI--NO
DECLARE @CNS INT =1 --factura individual
DECLARE @IDPRESTADOR VARCHAR(20)
DECLARE @NRO INT
DECLARE @CANT INT
DECLARE @conceptoRecaudo VARCHAR(20)
DECLARE @VALORCOPAGO DECIMAL(14,2)
DECLARE @IDSEDE VARCHAR(20)
DECLARE @CODHABILITA VARCHAR(100)
DECLARE @CNSCONSULTA INT
DECLARE @CANTORI INT
DECLARE @BANDERA INT
DECLARE @CNSFCT VARCHAR(20)
DECLARE @primerGrupo SMALLINT
DECLARE @BASE64 NVARCHAR(MAX)
DECLARE @codPrestador VARCHAR(20),
	@fechaInicioAtencion VARCHAR(16),
	@numAutorizacion VARCHAR(30),
	@codConsulta VARCHAR(6),
	@modalidadGrupoServicioTecSal VARCHAR(2),
	@grupoServicios VARCHAR(2),
	@codServicio VARCHAR(4),
	@finalidadTecnologiaSalud VARCHAR(2),
	@causaMotivoAtencion VARCHAR(2),
	@codDiagnosticoPrincipal VARCHAR(20),
	@codDiagnosticoRelacionado1 VARCHAR(20),
	@codDiagnosticoRelacionado2 VARCHAR(20),
	@codDiagnosticoRelacionado3 VARCHAR(20),
	@tipoDiagnosticoPrincipal VARCHAR(2),
	@vrServicio DECIMAL(14,2),
	@tipoPagoModerador VARCHAR(2),
	@valorPagoModerador DECIMAL(14,2),
	@consecutivo  VARCHAR(4)  
DECLARE 
	@numAutorizadon VARCHAR(30),
	@idMIPRES       VARCHAR(15),
	@fechaDispensAdmon VARCHAR(16),
	@codDiagnosticoRelacionado VARCHAR(20),
	@tipoMedicamento VARCHAR(4),
	@codTecnologiaSalud VARCHAR(20),
	@nomTecnologiaSalud VARCHAR(30),
	@concentracionMedicamento VARCHAR(4),
	@unidadMedida int,
	@formaFarmaceutica VARCHAR(8),
	@unidadMinDispensa VARCHAR(4),
	@cantidadMedicamento VARCHAR(20),
	@diasTratamiento     VARCHAR(5),
	@tipoDocumentoIdentificacion VARCHAR(4),
	@numDocumentoIdentificacion VARCHAR(20),
	@vrUnitMedicamento VARCHAR(15),
	@numFEVPagoModerador VARCHAR(20)
DECLARE 
	@codProcedimiento VARCHAR(6),
	@vialngresoServicioSalud VARCHAR(2),
	@codComplicacion VARCHAR(20)
	DECLARE @codDiagnosticoPrincipalE VARCHAR(20)
	DECLARE @codDiagnosticoRelacionadoE1 VARCHAR(20)
	DECLARE @codDiagnosticoRelacionadoE2 VARCHAR(20)
	DECLARE @codDiagnosticoRelacionadoE3 VARCHAR(20)
	DECLARE @condicionDestinoUsuarioEgreso VARCHAR(2)
	DECLARE @codDiagnosticoCausaMuerte VARCHAR(20)
	DECLARE @fechaEgreso VARCHAR(16)
	DECLARE @viaIngresoServicioSalud VARCHAR(2)
DECLARE @RESIDUO DECIMAL(14,2)
DECLARE @numDocumentoIdObligado VARCHAR(20) 
, @CIRUJANOENJSON  VARCHAR(20) 
, @EPI_MEDICODEFAULT  VARCHAR(20)
, @TIPODC_DEF VARCHAR(2)
, @IDPLANPART   VARCHAR(20) 
, @IDPLANPART2  VARCHAR(20) 
, @IDPLANPART3  VARCHAR(20) 
, @IDPLANPART4  VARCHAR(20) 
, @IDPLANPART5  VARCHAR(20) 
, @HCPLANTILLAEPI  VARCHAR(20) 
, @IDMATERIALESRIPS  VARCHAR(20) 
, @MODO_ASISTENCIAL  VARCHAR(20) 

DECLARE @IDPLAN VARCHAR(10),@IDTERCERO VARCHAR(20),@CONCEPTORECAUDOICI VARCHAR(20) ,@IDDXCIT VARCHAR(10) ,@TIPODXCIT VARCHAR(20) ,@IDAFILIADOCIT VARCHAR(20)
       ,@CONCEPTORECAUDOICE VARCHAR(20) ,@ESMODERADORAENFTR VARCHAR(2) ,@FMINHPRE DATE,@FMAXHPRE DATE,@FHADM DATE ,@FALTAMED DATE,@FINIATEN DATETIME ,@FFINATEN DATETIME
       ,@FINIATENCION DATETIME, @FFINATENCION DATETIME, @ITEM_FDIANR INT,@FECHAFACTURA DATE ,@FECHANACIMIENTOAFI DATE ,@EDAD INT, @PAQUETE INT -- 20250618 - STORRES - SE AGREGA VARIABLE PARA IDENTIFICAR PAQUETE
	   , @PAQUETIZADO INT =0

DECLARE @TOTALFTRD INT, @BASE INT, @RESTO INT, @TOTALMOD VARCHAR(10), @BASEMOD DECIMAL(14,2), @RESTOMOD DECIMAL(14,2)
			

BEGIN
   SET LANGUAGE Spanish
   SET DATEFORMAT dmy
   
   -- Crear tablas temporales en lugar de variables de tabla
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
	vrServicio DECIMAL(14,2),
	tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
	tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT, 
	numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT, 
	valorPagoModerador DECIMAL(14,2),
   numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo  INT IDENTITY(1,1) 
   );
   CREATE INDEX IX_CONSULTAS_IDAFILIADO ON #CONSULTAS (IDAFILIADO);

   CREATE TABLE #CONSULTAS1 (
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
	Cantidad int,
	tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
	valorPagoModerador DECIMAL(14,2),
   numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
	restoPagoModerador  VARCHAR(10) COLLATE DATABASE_DEFAULT,
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo  INT IDENTITY(1,1) 
   );
   CREATE INDEX IX_CONSULTAS1_CONSECUTIVO ON #CONSULTAS1 (consecutivo);

   CREATE TABLE #MEDICAMENTOS (
	codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
	numAutorizadon VARCHAR(30) COLLATE DATABASE_DEFAULT,
	idMIPRES       VARCHAR(15) COLLATE DATABASE_DEFAULT,
	fechaDispensAdmon VARCHAR(16) COLLATE DATABASE_DEFAULT,
	codDiagnosticoPrincipal VARCHAR(20) COLLATE DATABASE_DEFAULT,
	codDiagnosticoRelacionado VARCHAR(20) COLLATE DATABASE_DEFAULT,
	tipoMedicamento VARCHAR(4) COLLATE DATABASE_DEFAULT,
	codTecnologiaSalud VARCHAR(20) COLLATE DATABASE_DEFAULT,
	nomTecnologiaSalud VARCHAR(30) COLLATE DATABASE_DEFAULT,
	concentracionMedicamento int,
	unidadMedida int,
	formaFarmaceutica VARCHAR(8) COLLATE DATABASE_DEFAULT,
	unidadMinDispensa int,
	cantidadMedicamento INT,
	diasTratamiento    SMALLINT,
	tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
	numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
	vrUnitMedicamento DECIMAL(14,2),
	vrServicio DECIMAL(14,2),
	tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
	valorPagoModerador DECIMAL(14,2),
	numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo  INT IDENTITY(1,1) ,
	MED BIT,
	idArticulo varchar(20),
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT
   );
   CREATE INDEX IX_MEDICAMENTOS_IDAFILIADO ON #MEDICAMENTOS (IDAFILIADO);

   CREATE TABLE #PROCEDIMIENTOS (
	codPrestador VARCHAR(12) COLLATE DATABASE_DEFAULT,
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
	tipoPagoModerador  VARCHAR(2) COLLATE DATABASE_DEFAULT,
	valorPagoModerador  DECIMAL(14,2),
	numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo INT IDENTITY(1,1)
	);
   CREATE INDEX IX_PROCEDIMIENTOS_IDAFILIADO ON #PROCEDIMIENTOS (IDAFILIADO);

   CREATE TABLE #PROCEDIMIENTOS1 (
	codPrestador VARCHAR(12) COLLATE DATABASE_DEFAULT,
	fechaInicioAtencion VARCHAR(16) COLLATE DATABASE_DEFAULT,
	idMIPRES VARCHAR(15) COLLATE DATABASE_DEFAULT,
	numAutorizacion VARCHAR(30) COLLATE DATABASE_DEFAULT,
	codProcedimiento VARCHAR(6) COLLATE DATABASE_DEFAULT,
	vialngresoServicioSalud VARCHAR(2) COLLATE DATABASE_DEFAULT,
	modalidadGrupoServicioTecSal VARCHAR(2) COLLATE DATABASE_DEFAULT,
	grupoServicios VARCHAR(2) COLLATE DATABASE_DEFAULT,
	codServicio VARCHAR(4) COLLATE DATABASE_DEFAULT,
	finalidadTecnologiaSalud VARCHAR(2) COLLATE DATABASE_DEFAULT,
	tipoDocumentoIdentificacion VARCHAR(2) COLLATE DATABASE_DEFAULT,
	numDocumentoIdentificacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
	codDiagnosticoPrincipal VARCHAR(20) COLLATE DATABASE_DEFAULT,
	codDiagnosticoRelacionado VARCHAR(20) COLLATE DATABASE_DEFAULT,
	codComplicacion VARCHAR(20) COLLATE DATABASE_DEFAULT,
   vrtotal int, 
	vrServicio DECIMAL(14,2), 
	cantidad int,
	tipoPagoModerador  VARCHAR(2) COLLATE DATABASE_DEFAULT,
	valorPagoModerador  DECIMAL(14,2),
	restoPagoModerador  VARCHAR(10) COLLATE DATABASE_DEFAULT,
	numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo INT IDENTITY(1,1)
	);
   CREATE INDEX IX_PROCEDIMIENTOS1_CONSECUTIVO ON #PROCEDIMIENTOS1 (consecutivo);

   CREATE TABLE #OTROSSER (
	codPrestador VARCHAR(20) COLLATE DATABASE_DEFAULT,
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
	tipoPagoModerador VARCHAR(2) COLLATE DATABASE_DEFAULT,
	valorPagoModerador DECIMAL(14,2),
	numFEVPagoModerador VARCHAR(20) COLLATE DATABASE_DEFAULT,
   IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	consecutivo  INT IDENTITY(1,1) 
	);
   CREATE INDEX IX_OTROSSER_IDAFILIADO ON #OTROSSER (IDAFILIADO);

   CREATE TABLE #DX (
	IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	NOADMISION VARCHAR(20) COLLATE DATABASE_DEFAULT,
	CONSECUTIVOCIT VARCHAR(20) COLLATE DATABASE_DEFAULT,
	TIPODX VARCHAR(20) COLLATE DATABASE_DEFAULT,
	IDDX VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NIDDX VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX1 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX1 VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX2 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX2 VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX3 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX3 VARCHAR(255) COLLATE DATABASE_DEFAULT
   );
   CREATE INDEX IX_DX_IDAFILIADO_NOADM ON #DX (IDAFILIADO, NOADMISION);

   CREATE TABLE #DX1 (
	IDAFILIADO VARCHAR(20) COLLATE DATABASE_DEFAULT,
	NOADMISION VARCHAR(20) COLLATE DATABASE_DEFAULT,
	CONSECUTIVOCIT VARCHAR(20) COLLATE DATABASE_DEFAULT,
	TIPODX VARCHAR(20) COLLATE DATABASE_DEFAULT,
	IDDX VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NIDDX VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX1 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX1 VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX2 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX2 VARCHAR(255) COLLATE DATABASE_DEFAULT,
	DX3 VARCHAR(4) COLLATE DATABASE_DEFAULT,
	NDX3 VARCHAR(255) COLLATE DATABASE_DEFAULT
   );
   CREATE INDEX IX_DX1_IDAFILIADO_NOADM ON #DX1 (IDAFILIADO, NOADMISION);


	SELECT @PROCEDENCIA=PROCEDENCIA,
		@NOADMISION=NOREFERENCIA ,
		@IDSEDE = IDSEDE,
		@VALORCOPAGO=CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0) ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0) ELSE COALESCE(VALORCOPAGO,0) END END
		,@IDSEDE = IDSEDE, @CNSFCT = CNSFCT, @IDPLAN = FTR.IDPLAN,@IDTERCERO=IDTERCERO
	FROM FTR WHERE N_FACTURA=@N_FACTURA

	SELECT @ITEM_FDIANR = MAX(ITEM)
	FROM  FDIANR 
              WHERE CNSDOCUMENTO =  @CNSFCT 
              AND   TIPO = 'FV'
              AND   METODO = 'SendBillSync'

   IF EXISTS( SELECT * 
              FROM  FDIANR 
              WHERE ITEM = @ITEM_FDIANR
              AND   COALESCE(XML_AttachedDocument,'') != '' 
              AND   CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>',XML_AttachedDocument) > 0  
              )
   BEGIN
      SELECT @ESMODERADORAENFTR = '02'
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT top 1 * 
                 FROM  FDIANR 
                 WHERE ITEM = @ITEM_FDIANR
                 AND   COALESCE(XML_AttachedDocument,'') != '' 
                 AND   CHARINDEX('<cbc:ID schemeID="01">COPAGO</cbc:ID>',XML_AttachedDocument) > 0  
                  )
      BEGIN
         SELECT @ESMODERADORAENFTR = '01'
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT top 1 * 
                    FROM  FDIANR 
                    WHERE ITEM = @ITEM_FDIANR
                    AND   COALESCE(XML_AttachedDocument,'') != '' 
                    AND   CHARINDEX('<cbc:ID schemeID="03">PAGOS COMPARTIDOS EN PLANES VOLUNTARIOS DE SALUD</cbc:ID>',XML_AttachedDocument) > 0  
                     )
         BEGIN
            SELECT @ESMODERADORAENFTR = '03'
         END
      END
   END

   -- Si no se encontro busco en el XML_SOLICITUD
   IF ISNULL(@ESMODERADORAENFTR,'') = ''
   BEGIN
		IF EXISTS(SELECT 1
                FROM  FDIANR 
                WHERE ITEM = @ITEM_FDIANR
                AND   TIPO = 'FV'
                AND   COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '')
		BEGIN
			IF EXISTS(SELECT 1
					    FROM  FDIANR 
					    WHERE ITEM = @ITEM_FDIANR
					    AND   TIPO = 'FV'
					    AND   COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' 
					    AND   CHARINDEX('<cbc:ID schemeID="02">CUOTA MODERADORA</cbc:ID>',CONVERT(NVARCHAR(MAX),XML_SOLICITUD)) > 0)
			BEGIN
			    SELECT @ESMODERADORAENFTR = '02'
			END
			ELSE IF EXISTS(SELECT 1
					    FROM  FDIANR 
					    WHERE ITEM = @ITEM_FDIANR
					    AND   TIPO = 'FV'
					    AND   COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' 
					    AND   CHARINDEX('<cbc:ID schemeID="01">COPAGO</cbc:ID>',CONVERT(NVARCHAR(MAX),XML_SOLICITUD)) > 0)
			BEGIN
			    SELECT @ESMODERADORAENFTR = '01'
			END
			ELSE IF EXISTS(SELECT 1
					    FROM  FDIANR 
					    WHERE ITEM = @ITEM_FDIANR
					    AND   TIPO = 'FV'
					    AND   COALESCE(CONVERT(NVARCHAR(MAX),XML_SOLICITUD),'') != '' 
					    AND   CHARINDEX('<cbc:ID schemeID="03">PAGOS COMPARTIDOS EN PLANES VOLUNTARIOS DE SALUD</cbc:ID>',CONVERT(NVARCHAR(MAX),XML_SOLICITUD)) > 0)
			BEGIN
			    SELECT @ESMODERADORAENFTR = '03'
			END
		END
	END
   DECLARE @XML XML ,@CNSDOCUMENTO VARCHAR(20), @VLRSERVICIOSDIAN DECIMAL(14,2), @VLR_TOTALDIAN DECIMAL(14,2), @VLRCOPAGODIAN DECIMAL(14,2)

   SELECT TOP 1 @XML=xml_solicitud FROM FDIANR 
   WHERE ITEM =@ITEM_FDIANR;

      WITH XMLNAMESPACES (
            'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' AS inv,
            'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2' AS cac,
            'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc
      )
      SELECT
          @VLRSERVICIOSDIAN= @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:LineExtensionAmount)[1]', 'DECIMAL(18,2)') ,
          @VLRCOPAGODIAN=  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PrepaidAmount)[1]', 'DECIMAL(18,2)') ,
          @VLR_TOTALDIAN=  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount)[1]', 'DECIMAL(18,2)')
   --20250618 - STORRES - BUSCO SI LA FACTURA ES PAQUETE O NO    
   IF EXISTS( SELECT * 
              FROM  FDIANR 
              WHERE ITEM = @ITEM_FDIANR
              AND   COALESCE(XML_AttachedDocument,'') != '' 
              AND   CHARINDEX('<Value schemeName="salud_modalidad_pago.gc" schemeID="01">Pago individual por caso / Conjunto integral de atenciones / Paquete / Canasta.</Value>',XML_AttachedDocument) > 0  
              )
   BEGIN
      SELECT @PAQUETE = 1
   END
   print '@PAQUETE='+convert(varchar(50),@PAQUETE)
   print '@ESMODERADORAENFTR='+convert(varchar(50),@ESMODERADORAENFTR)
   /* --Se conoce que los partoculares SI SE REPORTAN STORRES_20250403
	IF EXISTS (SELECT DATO FROM USVGS WHERE IDVARIABLE IN ('IDPLANPART','IDPLANPART1', 'IDPLANPART2', 'IDPLANPART3', 'IDPLANPART4', 'IDPLANPART5') AND DATO = @IDPLAN)
	BEGIN 
		PRINT 'ES UNA FACTURA PARTICULAR'
		RETURN
	END 
   */ --Se conoce que los partoculares SI SE REPORTAN STORRES_20250403
	IF NOT EXISTS(SELECT 1 FROM FTR WHERE N_FACTURA=@N_FACTURA AND NOREFERENCIA=@NOADMISION)
	BEGIN
		PRINT CONCAT(
			'[SPK_RIPS_JSON_FTR_IND] ERROR: No encontre factura. N_FACTURA=', COALESCE(@N_FACTURA,'NULL'),
			' | NOREFERENCIA/NOADMISION=', COALESCE(@NOADMISION,'NULL'),
			' (NULL=NULL no cumple en SQL)'
		);
		RAISERROR('SPK_RIPS_JSON_FTR_IND: no se encontro FTR.N_FACTURA/NOREFERENCIA; JSON no generado.', 16, 1);
		RETURN
	END
	SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO') 
			, @CIRUJANOENJSON  = COALESCE(DBO.FNK_VALORVARIABLE('CIRUJANOENJSON')  ,'')
			, @EPI_MEDICODEFAULT = COALESCE(DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT') ,'')
			, @IDPLANPART = COALESCE(DBO.FNK_VALORVARIABLE('IDPLANPART') ,'')
			, @IDPLANPART2 = COALESCE(DBO.FNK_VALORVARIABLE('IDPLANPART2') ,'')
			, @IDPLANPART3 = COALESCE(DBO.FNK_VALORVARIABLE('IDPLANPART3') ,'')
			, @IDPLANPART4 = COALESCE(DBO.FNK_VALORVARIABLE('IDPLANPART4') ,'')
			, @IDPLANPART5 = COALESCE(DBO.FNK_VALORVARIABLE('IDPLANPART5') ,'')
			, @HCPLANTILLAEPI = COALESCE(DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI') ,'')
			, @IDMATERIALESRIPS = COALESCE(DBO.FNK_VALORVARIABLE('IDMATERIALESRIPS') ,'')
			, @MODO_ASISTENCIAL = COALESCE(DBO.FNK_VALORVARIABLE('MODO_ASISTENCIAL') ,'')

	SELECT @TIPODC_DEF = LEFT(COALESCE(NULLIF(TIPO_ID, ''), 'CC'), 2)
	FROM MED
	WHERE IDMEDICO = @EPI_MEDICODEFAULT
	SET @TIPODC_DEF = COALESCE(@TIPODC_DEF, 'CC')

    SELECT @CONCEPTORECAUDOICI = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICI' 
    SELECT @CONCEPTORECAUDOICE = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICE' 
	IF EXISTS(SELECT 1 FROM FTR INNER JOIN AFI ON FTR.IDAFILIADO=AFI.IDAFILIADO WHERE FTR.N_FACTURA=@N_FACTURA)
	BEGIN
		SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
			@TIPOUSU= CASE WHEN AFI.TIPOUSUARIO IS NOT NULL AND LEN(AFI.TIPOUSUARIO) = 2 THEN AFI.TIPOUSUARIO ELSE 
						CASE WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
							WHEN AFI.TIPOAFILIADO = 'B' THEN '02'
							WHEN AFI.TIPOAFILIADO = 'J' THEN '01'
							WHEN AFI.TIPOAFILIADO = 'A' THEN '03'
							WHEN AFI.TIPOAFILIADO = 'S' THEN '07'
							WHEN AFI.TIPOAFILIADO = 'Sb' THEN '04'
							WHEN AFI.TIPOAFILIADO = 'SR' THEN '05' --sin regimen
							WHEN AFI.TIPOAFILIADO = 'TA' THEN '06'
							WHEN AFI.TIPOAFILIADO = 'RE' THEN '07'
							WHEN AFI.TIPOAFILIADO = 'SN' THEN '05' --no recuerdo
							WHEN AFI.TIPOAFILIADO = 'S/' THEN '05' --sn
							WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END END,
			@FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
			@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@CIUDADNAC=AFI.CIUDADDOC,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
			@INCAPACIDAD='NO',@CNS=1
			,@FECHAFACTURA = FTR.F_FACTURA
			,@FECHANACIMIENTOAFI = AFI.FNACIMIENTO
		FROM FTR INNER JOIN AFI ON FTR.IDAFILIADO=AFI.IDAFILIADO 
		WHERE FTR.N_FACTURA=@N_FACTURA

		
		DECLARE @IDTARIFASOAT      VARCHAR(20) = DBO.FNK_VALORVARIABLE('IDTARIFASOAT');
		DECLARE @TERCATASEGURADORA VARCHAR(20) = DBO.FNK_VALORVARIABLE('TERCATASEGURADORA');

		IF @PROCEDENCIA = 'SALUD'
		BEGIN
			/* HADM.TIPOAFILIADO NULL no debe pisar @TIPOUSU: NULL + texto anula todo @PLANO. */
			PRINT CONCAT('[SPK_RIPS_JSON_FTR_IND] TIPOUSU SALUD previo=', COALESCE(@TIPOUSU, 'NULL'), ' NOADMISION=', COALESCE(@NOADMISION, ''));
			SELECT @TIPOUSU = COALESCE(
				NULLIF(LTRIM(RTRIM(
					CASE
						WHEN IIF(H.TIPOADM = @IDTARIFASOAT, 1, 0) = 0
						  OR EXISTS (
								SELECT 1 FROM TEXCA T
								WHERE T.IDTERCERO = @IDTERCERO
								  AND T.IDCATEGORIA = @TERCATASEGURADORA
							 )
							THEN H.TIPOAFILIADO
						ELSE A.TIPOUSUARIO
					END
				)), ''),
				@TIPOUSU,
				'05'
			)
			FROM HADM H
				OUTER APPLY ( SELECT TIPOUSUARIO FROM AFI WHERE IDAFILIADO = H.IDAFILIADO) A
			WHERE H.NOADMISION = @NOADMISION;
			PRINT CONCAT('[SPK_RIPS_JSON_FTR_IND] TIPOUSU SALUD final=', COALESCE(@TIPOUSU, 'NULL'));
		END


		SELECT @EDAD = DATEDIFF(year, @FECHANACIMIENTOAFI, @FECHAFACTURA)           -- diferencia bruta de aÃ±os
				- CASE                                    -- Â¿ya celebrÃ³ el cumpleaÃ±os este aÃ±o?
					WHEN DATEADD(year,
								DATEDIFF(year,@FECHANACIMIENTOAFI, @FECHAFACTURA),
								@FECHANACIMIENTOAFI) > @FECHAFACTURA
					THEN 1
					ELSE 0
				END
	END
	ELSE
	BEGIN
		IF @PROCEDENCIA='CI' OR @PROCEDENCIA='ONCO'
		BEGIN
			SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
				@TIPOUSU= CASE WHEN AFI.TIPOUSUARIO IS NOT NULL AND AFI.TIPOUSUARIO <> '' THEN   AFI.TIPOUSUARIO
                           WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
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
									WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END,
				@FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
				@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@CIUDADNAC=AFI.CIUDADDOC,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
				@INCAPACIDAD='NO',@CNS=1
			FROM CIT INNER JOIN AFI ON CIT.IDAFILIADO=AFI.IDAFILIADO 
			WHERE CIT.CONSECUTIVO=@NOADMISION
		END
		BEGIN
			IF @PROCEDENCIA='AUT'
			BEGIN
				SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
					@TIPOUSU= CASE    WHEN AFI.TIPOUSUARIO IS NOT NULL AND AFI.TIPOUSUARIO <> '' THEN   AFI.TIPOUSUARIO
                                 WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
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
											WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END,
					@FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
					@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@CIUDADNAC=AFI.CIUDADDOC,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
					@INCAPACIDAD='NO',@CNS=1
				FROM AUT INNER JOIN AFI ON AUT.IDAFILIADO=AFI.IDAFILIADO 
				WHERE AUT.NOAUT=@NOADMISION
			END
			ELSE
			BEGIN
				SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
					@TIPOUSU= CASE WHEN AFI.TIPOUSUARIO IS NOT NULL AND AFI.TIPOUSUARIO <> '' THEN   AFI.TIPOUSUARIO
                                 WHEN AFI.TIPOAFILIADO = 'C' THEN '01'
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
											WHEN AFI.TIPOAFILIADO = 'S/N' THEN '05' ELSE '05' END,
					@FNACIMIENTO=REPLACE(CONVERT(VARCHAR,AFI.FNACIMIENTO,102),'.','-'),
					@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@CIUDADNAC=AFI.CIUDADDOC,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
					@INCAPACIDAD='NO',@CNS=1
				FROM HADM INNER JOIN AFI ON HADM.IDAFILIADO=AFI.IDAFILIADO 
				WHERE HADM.NOADMISION=@NOADMISION
			END
		END
	END
	
	-- codPaisResidencia: ISO 3166-1 numerico desde PAIS segun ciudad de residencia (AFI.CIUDAD)
	SELECT @CODPAISRESIDENCIA = COALESCE(NULLIF(TRIM(CONVERT(VARCHAR(5), PAIS.ISO3166NUM)), ''), '170')
	FROM CIU
	INNER JOIN DEP ON CIU.DPTO = DEP.DPTO
	INNER JOIN PAIS ON DEP.PAIS = PAIS.IDPAIS
	WHERE CIU.CIUDAD = @MUNICIPIO

	-- codPaisOrigen: ISO 3166-1 numerico desde PAIS segun ciudad de nacimiento (AFI.CIUDADNAC)
	SELECT @CODPAISORIGEN = COALESCE(NULLIF(TRIM(CONVERT(VARCHAR(5), PAIS.ISO3166NUM)), ''), '170')
	FROM CIU
	INNER JOIN DEP ON CIU.DPTO = DEP.DPTO
	INNER JOIN PAIS ON DEP.PAIS = PAIS.IDPAIS
	WHERE CIU.CIUDAD = @CIUDADNAC

	IF @CODPAISORIGEN IS NULL
		SELECT @CODPAISORIGEN = '170'
	IF @CODPAISRESIDENCIA IS NULL
		SELECT @CODPAISRESIDENCIA = '170'


	SELECT @conceptoRecaudo = '05' -- El ministerio le dio como respuesta a san luis que el concepto debe ser 05 no aplica (krodriuguez)
    PRINT '@VALORCOPAGO='+STR(@VALORCOPAGO)
    PRINT ' @TIPOUSU='+ @TIPOUSU
	IF @VALORCOPAGO > 0 
	BEGIN
		IF @TIPOUSU IN('01','02','06') AND @PROCEDENCIA <>'SALUD' --
		BEGIN 
			SELECT @conceptoRecaudo = '02' --CUOTA MODERADORA
		END
		ELSE
		BEGIN
			IF @TIPOUSU IN('01','02','04')
			BEGIN
				SELECT @conceptoRecaudo = '01'
			END
			ELSE
				BEGIN
					IF @TIPOUSU IN('03','11') --ARREGLO PARA MASMENTE
					BEGIN
						SELECT @conceptoRecaudo = '03' 
					END
				END
		END
	END
    PRINT '@conceptoRecaudo='+@conceptoRecaudo
	SELECT @IDPRESTADOR=COALESCE(IDALTERNA2,'No tengo'), @numDocumentoIdObligado = NIT
	FROM TER 
	WHERE IDTERCERO=@IDTERINSTA
	-- Si la IPS maneja multiples sedes el codigo de habilitaciÃ³n es por sede
	IF EXISTS(SELECT 1 FROM USVGS WHERE IDVARIABLE = 'FACTSEDE' AND DATO='SI')
	BEGIN
		SELECT @IDPRESTADOR = COALESCE(CODHABILITA, IDSGSSS) FROM SED WHERE IDSEDE=@IDSEDE
	END
	PRINT '@PROCEDENCIA = ' + @PROCEDENCIA
	PRINT 'ARMADO TABLA DIAGNOSTICOS '
	BEGIN
		INSERT INTO #DX1 (IDAFILIADO,NOADMISION,CONSECUTIVOCIT,TIPODX,IDDX,DX1,DX2,DX3)
			SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
			CASE HCA.TIPODX 
								WHEN 'Presuntivo'   THEN '01'
								WHEN 'Impresion dx' THEN '01'
								WHEN 'Definitivo'   THEN '01'
								WHEN 'Conf Nuevo'   THEN '02'
								WHEN 'Conf Repet'   THEN '03'
								ELSE '01'
								END
			,LEFT(HCA.IDDX,4),LEFT(COALESCE(PX.DX1,HCA.DX1),4),LEFT(COALESCE(PX.DX2,HCA.DX2),4),LEFT(COALESCE(PX.DX3,HCA.DX3),4)
		FROM HCA 
			INNER JOIN CIT ON HCA.CONSECUTIVOCIT=CIT.CONSECUTIVO --AND HCA.IDAFILIADO = CIT.IDAFILIADO
			LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO = HCA.CONSECUTIVO
		WHERE HCA.CLASE='HC'
			AND HCA.PROCEDENCIA='IPS'
			AND COALESCE(HCA.IDDX,'')<>''
			AND EXISTS(SELECT * FROM FTR WHERE  FTR.CNSFCT=@CNSFCT AND FTR.NOREFERENCIA=CIT.CONSECUTIVO AND FTR.PROCEDENCIA IN ('CI','CE'))
		UNION 
		SELECT HCA.IDAFILIADO,HCA.NOADMISION,HCA.CONSECUTIVOCIT,
				CASE HCA.TIPODX 
							WHEN 'Presuntivo'   THEN '01'
							WHEN 'Impresion dx' THEN '01'
							WHEN 'Definitivo'   THEN '01'
							WHEN 'Conf Nuevo'   THEN '02'
							WHEN 'Conf Repet'   THEN '03'
							ELSE '01'
							END,LEFT(HCA.IDDX,4),LEFT(COALESCE(PX.DX1,HCA.DX1),4),LEFT(COALESCE(PX.DX2,HCA.DX2),4),LEFT(COALESCE(PX.DX3,HCA.DX3),4)
		FROM HCA 
			INNER JOIN HADM ON HCA.NOADMISION=HADM.NOADMISION AND HCA.IDAFILIADO = HADM.IDAFILIADO
			LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO = HCA.CONSECUTIVO
		WHERE HCA.CLASE='HC'
		AND HCA.PROCEDENCIA='QX'
		AND EXISTS(SELECT * FROM FTR WHERE  FTR.CNSFCT=@CNSFCT AND FTR.NOREFERENCIA=HADM.NOADMISION AND FTR.PROCEDENCIA='SALUD')
	END
   ;WITH CTE AS (
       SELECT *,
              ROW_NUMBER() OVER (PARTITION BY IDAFILIADO, NOADMISION ORDER BY (SELECT NULL)) AS rn
       FROM #DX1
   )
   INSERT INTO #DX
   SELECT
       IDAFILIADO,
       NOADMISION,
       MAX(CONSECUTIVOCIT)        AS CONSECUTIVOCIT,
       MAX(TIPODX)                 AS TIPODX,
       MAX(IDDX)                   AS IDDX,
       MAX(NIDDX)                  AS NIDDX,
       MAX(DX1)                    AS DX1,
       MAX(NDX1)                   AS NDX1,
       MAX(DX2)                    AS DX2,
       MAX(NDX2)                   AS NDX2,
       MAX(DX3)                    AS DX3,
       MAX(NDX3)                   AS NDX3
   FROM CTE
   GROUP BY IDAFILIADO, NOADMISION;
	/* Evitar que un NULL en datos de usuario anule todo el JSON (NULL + texto = NULL). */
	SET @TIPODOC = COALESCE(NULLIF(LTRIM(RTRIM(@TIPODOC)), ''), 'CC');
	SET @DOCIDAFILIADO = COALESCE(NULLIF(LTRIM(RTRIM(@DOCIDAFILIADO)), ''), '');
	SET @TIPOUSU = COALESCE(NULLIF(LTRIM(RTRIM(@TIPOUSU)), ''), '05');
	SET @FNACIMIENTO = COALESCE(NULLIF(LTRIM(RTRIM(@FNACIMIENTO)), ''), '1900-01-01');
	SET @SEXO = COALESCE(NULLIF(LTRIM(RTRIM(@SEXO)), ''), 'M');
	SET @MUNICIPIO = COALESCE(NULLIF(LTRIM(RTRIM(@MUNICIPIO)), ''), '00000');
	SET @ZONA = COALESCE(NULLIF(LTRIM(RTRIM(@ZONA)), ''), '02');
	SET @INCAPACIDAD = COALESCE(NULLIF(LTRIM(RTRIM(@INCAPACIDAD)), ''), 'NO');

	IF COALESCE(@DOCIDAFILIADO, '') = ''
	BEGIN
		PRINT CONCAT('[SPK_RIPS_JSON_FTR_IND] ERROR: DOCIDAFILIADO vacio. N_FACTURA=', COALESCE(@N_FACTURA, ''), ' NOADMISION=', COALESCE(@NOADMISION, ''));
		RAISERROR('SPK_RIPS_JSON_FTR_IND: DOCIDAFILIADO vacio; no se puede armar el RIPS JSON.', 16, 1);
		RETURN;
	END

	PRINT CONCAT(
		'[SPK_RIPS_JSON_FTR_IND] Armando usuario | DOC=', @DOCIDAFILIADO,
		' | TIPODOC=', @TIPODOC,
		' | TIPOUSU=', @TIPOUSU,
		' | FNAC=', @FNACIMIENTO,
		' | SEXO=', @SEXO,
		' | MPIO=', @MUNICIPIO,
		' | ZONA=', @ZONA
	);

	SELECT @PLANO='{'
	SET @PLANO += '"numDocumentoIdObligado":"'+LTRIM(RTRIM(COALESCE(@numDocumentoIdObligado,'')))+'" ,' 
	SET @PLANO += '"numFactura":"'+COALESCE(@N_FACTURA,'')+'" ,'
	SET @PLANO += '"tipoNota": null,'
	SET @PLANO += '"numNota": null,'
	SET @PLANO += '"usuarios": [ '
	SET @PLANO += '{ '
	SET @PLANO += '  "tipoDocumentoIdentificacion":"'+CASE WHEN @TIPODOC = 'NV' THEN 'CN' ELSE @TIPODOC END+'" ,'
	SET @PLANO += '  "numDocumentoIdentificacion":"'+@DOCIDAFILIADO+'" ,'
	SET @PLANO += '  "tipoUsuario":"'+@TIPOUSU+'" ,'
	SET @PLANO += ' "fechaNacimiento":"'+@FNACIMIENTO+'",'
	SET @PLANO += ' "codSexo": "'+@SEXO+'",'
	SET @PLANO += ' "codPaisResidencia":"'+COALESCE(@CODPAISRESIDENCIA,'170')+'" ,'
	SET @PLANO += ' "codMunicipioResidencia": "'+@MUNICIPIO+'", '
	SET @PLANO += ' "codZonaTerritorialResidencia": "'+@ZONA+'",'
	SET @PLANO += ' "incapacidad":"'+@INCAPACIDAD+'",'
	SET @PLANO += ' "consecutivo": '+CAST(@CNS AS VARCHAR(5))+','
	SET @PLANO += ' "codPaisOrigen":"'+COALESCE(@CODPAISORIGEN,'170')+'" ,' -- ISO3166NUM via AFI.CIUDADNAC; default 170
	SET @PLANO += ' "registroSIRAS": null,'
	SET @PLANO += ' "servicios": { '
	--PRINT '@PLANO INIICIAL '+COALESCE(@PLANO,'NADA DE INICIO')
    begin --VERIFICACION de fechas en el xml de la factura para poder arreglar a las malas los datos
        SELECT @FMINHPRE= REPLACE(CONVERT(VARCHAR,MAX(FECHA),102),'.','-')+' '+LEFT(CONVERT(VARCHAR,MIN(FECHA),108),5) FROM HPRE WHERE NOADMISION=@NOADMISION
	    SELECT @FMAXHPRE= REPLACE(CONVERT(VARCHAR,MIN(FECHA),102),'.','-')+' '+LEFT(CONVERT(VARCHAR,MIN(FECHA),108),5) FROM HPRE WHERE NOADMISION=@NOADMISION
	    SELECT @FHADM=REPLACE(CONVERT(VARCHAR,HADM.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HADM.FECHA,108),5) FROM HADM WHERE NOADMISION=@NOADMISION
        SELECT @FALTAMED=REPLACE(CONVERT(VARCHAR,HADM.FECHAALTAMED,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HADM.FECHAALTAMED,108),5) FROM HADM WHERE NOADMISION=@NOADMISION
        SELECT @FINIATEN= MIN(Fecha) FROM (VALUES (@FMINHPRE), (@FHADM)) AS Fechas(Fecha)
        SELECT @FFINATEN  = MAX(fecha) FROM (VALUES (@FMAXHPRE), (@FALTAMED)) AS Fechas(Fecha)
        BEGIN --SACAR LAS FECHAS DE INICIO Y FINAL DEL XML QUE ESTA EN FDIANR
             DECLARE @AttachedText NVARCHAR(MAX),   -- XML del AttachedDocument (texto)
                     @InvText      NVARCHAR(MAX),   -- XML de la factura incrustada (texto)
                     @InvXML       XML,             -- XML de la factura UBL
                     @StartDate VARCHAR(10), @StartTime VARCHAR(20),
                     @EndDate   VARCHAR(10), @EndTime VARCHAR(20)
             /*------------------------------------------------------------------
               1. ObtÃ©n el AttachedDocument y quita la cabecera
             ------------------------------------------------------------------*/
             SELECT TOP 1 @AttachedText = XML_AttachedDocument
             FROM   FDIANR
             WHERE  CNSDOCUMENTO = @CNSFCT
             AND    TIPO         = 'FV'
		     AND METODO='SendBillSync' AND coalesce(XML_AttachedDocument,'')<>''
		     ORDER BY CONVERT(DATE,FECHA) DESC;
             IF CHARINDEX('?>', @AttachedText) > 0
                 SET @AttachedText = SUBSTRING(@AttachedText,
                                               CHARINDEX('?>', @AttachedText) + 2,
                                               LEN(@AttachedText));
             /*------------------------------------------------------------------
               2. Convierte a XML para navegar
             ------------------------------------------------------------------*/
             DECLARE @Attached XML = TRY_CONVERT(XML, @AttachedText);
             IF @Attached IS NULL
             BEGIN
                 PRINT 'No se pudo convertir AttachedDocument a XML.'
             END
             ELSE
             BEGIN
                /*------------------------------------------------------------------
                  3. Extrae el texto del nodo que contiene la factura
                     (Description o EmbeddedDocumentBinaryObject)
                ------------------------------------------------------------------*/
                SELECT TOP 1
                       @InvText = N.value('text()[1]', 'nvarchar(max)')
                FROM   @Attached.nodes('
                         //*[local-name()="Description" or local-name()="EmbeddedDocumentBinaryObject"]
                       ') AS T(N);
                IF @InvText IS NULL OR LEN(@InvText)=0
                BEGIN
                    RAISERROR('No se encontrÃ³ la factura UBL dentro del AttachedDocument.', 16, 1);
                    RETURN;
                END;
                /*------------------------------------------------------------------
                  4. Quita la cabecera del XML de la factura (para evitar UTF-8)
                ------------------------------------------------------------------*/
                IF CHARINDEX('?>', @InvText) > 0
                    SET @InvText = SUBSTRING(@InvText,
                                             CHARINDEX('?>', @InvText) + 2,
                                             LEN(@InvText));
                /*------------------------------------------------------------------
                  5. Convierte la factura a tipo XML
                ------------------------------------------------------------------*/
                SET @InvXML = TRY_CONVERT(XML, @InvText);
                IF @InvXML IS NULL
                BEGIN
                    RAISERROR('El texto extraÃ­do no es XML vÃ¡lido.', 16, 1);
                    RETURN;
                END;
                /*6- Extraer fecha (date)  y hora (varchar) */
                DECLARE
                    @SD  date,        @STtxt varchar(20),
                    @ED  date,        @ETtxt varchar(20);
                SELECT
                  @SD    = @InvXML.value(
                             'declare namespace cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2";
                              declare namespace cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2";
                              (/descendant::cac:InvoicePeriod/cbc:StartDate)[1]', 'date'),
                  @STtxt = @InvXML.value(
                             'declare namespace cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2";
                              declare namespace cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2";
                              (/descendant::cac:InvoicePeriod/cbc:StartTime/text())[1]', 'varchar(20)'),
                  @ED    = @InvXML.value(
                             'declare namespace cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2";
                              declare namespace cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2";
                              (/descendant::cac:InvoicePeriod/cbc:EndDate)[1]', 'date'),
                  @ETtxt = @InvXML.value(
                             'declare namespace cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2";
                              declare namespace cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2";
                              (/descendant::cac:InvoicePeriod/cbc:EndTime/text())[1]', 'varchar(20)');
			      PRINT '@ED'
			      PRINT @ED
                /* 7- Coge solo HH:MM:SS  y conviÃ©rtelo */
                DECLARE
                    @ST  time(0) = TRY_CONVERT(time(0), LEFT(@STtxt, 8)),
                    @ET  time(0) = TRY_CONVERT(time(0), LEFT(@ETtxt, 8));
				    PRINT '@ET EMEL';
				    PRINT @ET;
                /* 8- Combina fecha + hora SIN ajustar zona */
                select @FINIATENCION =  DATEADD(SECOND, DATEDIFF(SECOND, '00:00:00', @ST), CAST(@SD AS datetime)),
                    @FFINATENCION  =     DATEADD(SECOND, DATEDIFF(SECOND, '00:00:00', @ET), CAST(@ED AS datetime))
                /*------------------------------------------------------------------
                  9. Resultado
                ------------------------------------------------------------------*/
                PRINT '@FINIATENCION=' + CONVERT(VARCHAR(50),@FINIATENCION )+' // @FFINATENCION='+CONVERT(VARCHAR(50),@FFINATENCION)
             END
      END
      IF COALESCE(@FINIATENCION,'') != ''
      BEGIN
         IF @FINIATENCION > @FINIATEN
         BEGIN
            SELECT @FINIATEN  = @FINIATENCION
         END
      END
	  PRINT '@FFINATENCION EMEL'
	  PRINT @FFINATENCION
	  PRINT '@FFINATEN EMEL'
	  PRINT @FFINATEN
      IF COALESCE(@FFINATENCION,'') != ''
      BEGIN
         IF @FFINATENCION <> @FFINATEN
         BEGIN
            SELECT @FFINATEN  = @FFINATENCION
         END
      END
      SELECT @fechaInicioAtencion = REPLACE(CONVERT(VARCHAR,@FINIATEN,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,@FINIATEN,108),5)
      IF CONVERT(DATE, @FFINATEN) = CONVERT(DATE, GETDATE())
      BEGIN
          SET @FFINATEN = DATEADD(HOUR, -1, GETDATE());
      END
      SELECT @fechaEgreso = REPLACE(CONVERT(VARCHAR,@FFINATEN,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,@FFINATEN,108),5)
      print '@fechaInicioAtencion=' +@fechaInicioAtencion 
      print '@fechaEgreso='+@fechaEgreso
   end--VERIFICACION de fechas en el xml de la factura para poder arreglar a las malas los datos
	IF @PROCEDENCIA='CI'
	BEGIN
		BEGIN --AC
            BEGIN
			    INSERT INTO #CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									    finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO)
			    SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
				        numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                    codConsulta=LEFT(SER.CODCUPS,6),
                    modalidadGrupoServicioTecSal='01',
                    grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                    codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
					finalidadTecnologiaSalud=LEFT(CASE  WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1,'44') 
												               WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'44')
												WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10' 
														THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
																	               THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'44') 
																END  
												               ELSE  COALESCE(FINALIDADTGEN.DATO1,CIT.FINCONSULTA,'44') 
                                                   END,2), -- STORRES 20260610 SE CAMBIA LOS COALESCE POR EL CODIGO 44 - OTRO YA QUE EL 12 GENERA ERROR EN VALIDACIONES EN RIPS
					causaMotivoAtencion='38',
                    CASE WHEN CIT.IDPLAN IN (SELECT DATO FROM USVGS WHERE IDVARIABLE IN ('IDPLANPART','IDPLANPART1', 'IDPLANPART2', 'IDPLANPART3', 'IDPLANPART4', 'IDPLANPART5'))
                              THEN COALESCE(CIT.VALORTOTAL,0)-COALESCE(CIT.DESCUENTO,0)
                         ELSE FTRD.VLR_SERVICI
                    END, --storres_20250403
                    COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO,CIT.IDAFILIADO
			    FROM   FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO
				            INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				            INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                            INNER JOIN MED      ON MED.IDMEDICO=CIT.IDMEDICO
							LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
							LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
							--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
			    WHERE FTRD.N_FACTURA=@N_FACTURA
		            AND   RIPS_CP.ARCHIVO='AC'
                  AND   COALESCE(FTRD.VR_TOTAL,0)>0
            END
			IF EXISTS(SELECT 1 FROM #CONSULTAS)
			BEGIN
				-- https://web.sispro.gov.co/WebPublico/Consultas/ConsultarDetalleReferenciaBasica.aspx?Code=RIPSTipoDiagnosticoPrincipalVersion2
				PRINT 'DX DE CI AC'
            SELECT @IDAFILIADOCIT = IDAFILIADO FROM CIT WHERE CONSECUTIVO = @NOADMISION
            PRINT '@IDAFILIADOCIT='+@IDAFILIADOCIT
            SELECT @IDDXCIT = HCA.IDDX 
                  ,@TIPODXCIT =CASE TIPODX 
								WHEN 'Presuntivo'   THEN '01'
								WHEN 'Impresion dx' THEN '01'
								WHEN 'Definitivo'   THEN '01'
								WHEN 'Conf Nuevo'   THEN '02'
								WHEN 'Conf Repet'   THEN '03'
								ELSE '01'
								END
            FROM CIT INNER JOIN HCA ON CIT.IDAFILIADO=HCA.IDAFILIADO  
                                       AND CIT.CONSECUTIVO= IIF(COALESCE(HCA.CONSECUTIVOCIT,'')='',HCA.NOADMISION,HCA.CONSECUTIVOCIT) 
                                       AND HCA.PROCEDENCIA='IPS'
				WHERE CIT.CONSECUTIVO=@NOADMISION
				AND N_FACTURA=@N_FACTURA    
            PRINT '@IDDXCIT='+@IDDXCIT
            IF COALESCE(@IDDXCIT,'') = ''
            BEGIN
               SELECT TOP 1 @IDDXCIT= IDDX, @TIPODXCIT = TIPODX FROM HCA WHERE IDAFILIADO = @IDAFILIADOCIT AND PROCEDENCIA = 'IPS' AND CLASE = 'HC' ORDER BY FECHA DESC
               PRINT ' INGRESE A BUSCAR HCA @IDDXCIT='+@IDDXCIT
            END
            UPDATE #CONSULTAS SET codDiagnosticoPrincipal=@IDDXCIT
				,codDiagnosticoRelacionado1='null'
				,codDiagnosticoRelacionado2='null'
				,codDiagnosticoRelacionado3='null'
				,tipoDiagnosticoPrincipal= CASE @TIPODXCIT
								WHEN 'Presuntivo'   THEN '01'
								WHEN 'Impresion dx' THEN '01'
								WHEN 'Definitivo'   THEN '01'
								WHEN 'Conf Nuevo'   THEN '02'
								WHEN 'Conf Repet'   THEN '03'
								ELSE '01'
								END
				FROM CIT 
				WHERE CIT.CONSECUTIVO=@NOADMISION
				--AND N_FACTURA=@N_FACTURA    
			END
		END		
		BEGIN --AP
            IF EXISTS(
                    SELECT 1 
                    FROM  FTRD 
                        INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				        INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
			            INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
                        INNER JOIN TGEN     ON TGEN.TABLA='MED' AND CAMPO='TIPO_USUARIO' AND CODIGO=MED.TIPO_USUARIO AND TGEN.CHECK2>0
			        WHERE FTRD.N_FACTURA  = @N_FACTURA AND   RIPS_CP.ARCHIVO ='AP')
            BEGIN
			    INSERT INTO #PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
						    ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
						    ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO
						    )
			    SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),'null',
					        numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                    LEFT(SER.CODCUPS,6),'02','01',
                    grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                    codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                     -- ,'16',
					finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
					 MED.TIPO_ID,MED.IDMEDICO,COALESCE(CIT.IDDX,HCA.IDDX,'null'),
					        IIF(LEFT(TRIM(COALESCE(HCA.DX1,'')),4)=LEFT(TRIM(COALESCE(CIT.IDDX,HCA.IDDX,'')),4),'null',COALESCE(HCA.DX1,'null')),
					        COALESCE(HCA.DX2,HCA.IDDX,CIT.IDDX,'null'),COALESCE(FTRD.VLR_SERVICI,0),'04',COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA),CIT.IDAFILIADO
			    FROM  FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				            INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				            INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                            INNER JOIN (SELECT ROW_NUMBER() OVER (PARTITION BY HCA.IDAFILIADO, HCA.CONSECUTIVOCIT ORDER BY HCA.IDAFILIADO, HCA.CONSECUTIVOCIT) AS ITEM, 
                                HCA.CONSECUTIVOCIT, HCA.IDDX, HCA.IDAFILIADO, HCA.IDMEDICO,
                                COALESCE(PX.DX1,HCA.DX1) DX1, COALESCE(PX.DX2,HCA.DX2) DX2
                                FROM HCA 
                                LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
                                WHERE COALESCE(HCA.PROCEDENCIA,'')<>'QX' AND COALESCE(ANULADA,0)=0
                                ) HCA ON HCA.CONSECUTIVOCIT=CIT.CONSECUTIVO AND HCA.ITEM=1
                            INNER JOIN MED      ON MED.IDMEDICO=HCA.IDMEDICO
							--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
							INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
							LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
			    WHERE FTRD.N_FACTURA  = @N_FACTURA
		        AND   RIPS_CP.ARCHIVO ='AP'
           END
           ELSE
           BEGIN
			    INSERT INTO #PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
						    ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
						    ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO
						    )
			    SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),'null',
					        numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                    LEFT(SER.CODCUPS,6),'02','01',
                    grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                    codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                     -- ,'16',
					finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
					 MED.TIPO_ID,MED.IDMEDICO,CIT.IDDX,
					        'null',COALESCE(CIT.IDDX,'null'),COALESCE(FTRD.VLR_SERVICI,0),'04',COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA),CIT.IDAFILIADO
			    FROM  FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				            INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				            INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
			                INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
			    WHERE FTRD.N_FACTURA  = @N_FACTURA
		        AND   RIPS_CP.ARCHIVO ='AP'
              AND COALESCE(FTRD.VALOR,0)>0
           END
			IF EXISTS(SELECT 1 FROM #PROCEDIMIENTOS)
			BEGIN
            SELECT @IDAFILIADOCIT = IDAFILIADO FROM CIT WHERE CONSECUTIVO = @NOADMISION
            SELECT @IDDXCIT = HCA.IDDX 
                  ,@TIPODXCIT =CASE TIPODX 
								WHEN 'Presuntivo'   THEN '01'
								WHEN 'Impresion dx' THEN '01'
								WHEN 'Definitivo'   THEN '01'
								WHEN 'Conf Nuevo'   THEN '02'
								WHEN 'Conf Repet'   THEN '03'
								ELSE '01'
								END
            FROM CIT INNER JOIN HCA ON CIT.IDAFILIADO=HCA.IDAFILIADO  
                                       AND CIT.CONSECUTIVO= IIF(COALESCE(HCA.CONSECUTIVOCIT,'')='',HCA.NOADMISION,HCA.CONSECUTIVOCIT) 
                                       AND HCA.PROCEDENCIA='IPS'
				WHERE CIT.CONSECUTIVO=@NOADMISION
            AND COALESCE(HCA.IDDX ,'')<>''
				--AND N_FACTURA=@N_FACTURA    
            IF COALESCE(@IDDXCIT,'') = ''
               SELECT TOP 1 @IDDXCIT= IDDX, @TIPODXCIT = TIPODX FROM HCA WHERE IDAFILIADO = @IDAFILIADOCIT AND PROCEDENCIA = 'IPS' AND CLASE = 'HC' ORDER BY FECHA DESC
            IF COALESCE(@IDDXCIT,'') <> ''
            BEGIN
               UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal=@IDDXCIT
				   ,codDiagnosticoRelacionado='null'
				   FROM CIT 
				   WHERE CIT.CONSECUTIVO=@NOADMISION
            END
				--AND N_FACTURA=@N_FACTURA    
			END
		END
		BEGIN --AT
         PRINT 'AT'
			INSERT INTO #OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
								,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
								,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
			SELECT @IDPRESTADOR,
                numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                'null',
			       fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
			       tipoOS =CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,  --20250702 -- STORRES -- ESPERA CAMPO PARA REALIZAR CONFIGURACION
                codTecnologiaSalud=LEFT(SER.CODCUPS,20), nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z());:.,'),60),
			       cantidadOS=COALESCE(CIT.CANTIDADC,1), COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF), COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT), COALESCE(FTRD.VLR_SERVICI,0),COALESCE(FTRD.VLR_SERVICI,0),
                tipoPagoModerador='04',
                COALESCE(FTRD.VLR_COPAGOS,0), COALESCE(CIT.NFACTURA,@N_FACTURA),CIT.IDAFILIADO
			FROM   FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				         INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				         INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                     LEFT JOIN MED     ON MED.IDMEDICO = COALESCE(NULLIF(CIT.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
			WHERE FTRD.N_FACTURA  = @N_FACTURA
         AND   RIPS_CP.ARCHIVO = 'AT'
         AND COALESCE(FTRD.VALOR,0)>0
		END
	END
	ELSE IF @PROCEDENCIA='CE'
	BEGIN
		BEGIN --AC
			INSERT INTO #CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								finalidadTecnologiaSalud,causaMotivoAtencion
                        ,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3
                        ,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO )
			SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				    numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                codConsulta=LEFT(SER.CODCUPS,6),
                modalidadGrupoServicioTecSal='01',
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                --finalidadTecnologiaSalud=LEFT(CASE WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR AUT.FINALIDAD='10' OR COALESCE(TGEN.DATO1,'')='' THEN '44' ELSE COALESCE(TGEN.DATO1,AUT.FINALIDAD,'') END,2),
				finalidadTecnologiaSalud=LEFT(CASE	WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
													WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' 
													ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12') 
												END,2),
				  causaMotivoAtencion='38'
                , AUT.DXPPAL codDiagnosticoPrincipal,'null','null','null'  -- EEMC 06-06-2025 SE AGREGA DX PORQUE SON CONSULTAS 
               ,FTRD.VLR_SERVICI 
               --,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                ,CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
				   ,COALESCE(AUTD.NFACTURA,@N_FACTURA),COALESCE(MED.TIPO_ID, @TIPODOC,''), COALESCE(MED.IDMEDICO, @DOCIDAFILIADO,''),AUT.IDAFILIADO --STORRES_20250326
			FROM  FTRD INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT 
                                      AND FTRD.NOITEM       = AUTD.NO_ITEM
                    INNER JOIN AUT     ON AUTD.IDAUT        = AUT.IDAUT
					INNER JOIN SER     ON AUTD.IDSERVICIO   = SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS    = RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN TGEN    ON TGEN.TABLA        = 'GENERAL' 
								AND CAMPO             = 'FINALIDADCONSULTA' 
								AND CODIGO            = AUT.FINALIDAD
					LEFT JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)				
					--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
					INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
					LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
			WHERE FTRD.N_FACTURA         = @N_FACTURA
			AND   COALESCE(AUTD.VALOR,0) > 0
			--AND   AUTD.CANTIDAD          > 0
         AND   COALESCE(AUTD.CANTIDAD,1 ) = 1
			AND   RIPS_CP.ARCHIVO        ='AC'
         -- EEMC 06-06-2025  AHORA  LOS QUE TIENEN CANTIDAD > 1
            INSERT INTO #CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud
                           ,causaMotivoAtencion
                           ,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3
                           ,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad,IDAFILIADO) 
			   SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				       numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'),codConsulta=LEFT(SER.CODCUPS,6),modalidadGrupoServicioTecSal='01',grupoServicios='01',
				       codServicio='325'
					   ,finalidadTecnologiaSalud=LEFT(CASE	WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
															WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' 
															ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12') 
													END,2),
				       causaMotivoAtencion='38'
                  ,COALESCE(AUT.DXPPAL,'') codDiagnosticoPrincipal,COALESCE(AUT.DXRELACIONADO,'null') codDiagnosticoRelacionado1,COALESCE(AUT.DXRELACIONADO2,'null') codDiagnosticoRelacionado2
                  ,COALESCE(AUT.COMPLICACION,'null') codDiagnosticoRelacionado3
				      ,FTRD.VLR_SERVICI 
                 -- ,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                  ,CAST(CONVERT(DECIMAL(14,2),FTRD.VLR_COPAGOS) AS VARCHAR(20))
				      ,COALESCE(AUTD.NFACTURA,@N_FACTURA),COALESCE(MED.TIPO_ID, @TIPODOC,''), COALESCE(MED.IDMEDICO, @DOCIDAFILIADO,'') 
                  ,CONVERT(INT,AUTD.CANTIDAD),AUT.IDAFILIADO
			   FROM  FTRD INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT 
                                         AND FTRD.NOITEM       = AUTD.NO_ITEM
                       INNER JOIN AUT     ON AUTD.IDAUT        = AUT.IDAUT
					        INNER JOIN SER     ON AUTD.IDSERVICIO   = SER.IDSERVICIO
					        INNER JOIN RIPS_CP ON SER.CODIGORIPS    = RIPS_CP.IDCONCEPTORIPS
					         --LEFT JOIN TGEN    ON TGEN.TABLA        = 'GENERAL' 
              --                           AND CAMPO             = 'FINALIDADCONSULTA' 
              --                           AND CODIGO            = AUT.FINALIDAD
					         LEFT JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)				
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
			   WHERE FTRD.N_FACTURA         = @N_FACTURA
			   AND   COALESCE(AUTD.VALOR,0) > 0
            AND   COALESCE(AUTD.CANTIDAD,1 ) > 1
			   AND   RIPS_CP.ARCHIVO        ='AC'
			   UPDATE #CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
			   UPDATE #CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
			   SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM #CONSULTAS1
			   DECLARE JSCONSUL_AUT_CURSOR CURSOR FOR 
			   SELECT consecutivo,CANTIDAD FROM #CONSULTAS1
			   ORDER BY consecutivo
			   OPEN JSCONSUL_AUT_CURSOR    
			   FETCH NEXT FROM JSCONSUL_AUT_CURSOR    
			   INTO @CNSCONSULTA,@CANTORI
			   WHILE @@FETCH_STATUS = 0    
			   BEGIN 
				   SELECT @BANDERA=1
               PRINT 'ENTRE A SEPARAR LAS CONSULTAS CUANDO SE CARGARON POR AUT Y LA CANTIDAD > 1'
				   --SELECT valorPagoModerador, @CANTORI FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				   SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				   --SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
				   WHILE @BANDERA<=@CANTORI
				   BEGIN
					   IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
					   BEGIN
						   SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
					   END
					   INSERT INTO #CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO) 
					   SELECT codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,iif(coalesce(cantidad,1)>1 ,vrServicio/cantidad , vrServicio),@valorPagoModerador,numFEVPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO 
					   FROM #CONSULTAS1
					   WHERE consecutivo=@CNSCONSULTA
					   SELECT @BANDERA = @BANDERA+1
				   END
				   FETCH NEXT FROM JSCONSUL_AUT_CURSOR    
				   INTO  @CNSCONSULTA,@CANTORI
			   END
			   CLOSE JSCONSUL_AUT_CURSOR
			   DEALLOCATE JSCONSUL_AUT_CURSOR
         -----  EEMC 
			IF EXISTS(SELECT 1 FROM #CONSULTAS)
			BEGIN
				UPDATE #CONSULTAS SET codDiagnosticoPrincipal=AUT.DXPPAL
				,codDiagnosticoRelacionado1=AUT.DXRELACIONADO
				,codDiagnosticoRelacionado2=AUT.DXRELACIONADO2
				,tipoDiagnosticoPrincipal='01'
				FROM AUT
				WHERE AUT.NOAUT=@NOADMISION
				AND N_FACTURA=@N_FACTURA  
			END
		END
		BEGIN --AM
			IF DBO.FNK_VALORVARIABLE('PGP_AUT_SOLODISPENSA')<>'SI'
           	BEGIN
				INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
											,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
											,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
											,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
				SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
					COALESCE(AUT.IDMIPRESS,'null'),fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
						AUT.DXPPAL,AUT.DXRELACIONADO,'01',dbo.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''), SER.CODCUM),'A-Z0-9-'),LEFT( dbo.FNK_LIMPIATEXTO(COALESCE (IART.DESCRIPCION,''),'0-9 A-Z();:.,'),30),'0',
						COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,AUTD.CANTIDAD),10), CAST(IIF(COALESCE(AUTD.DIAS,0)=0,1,AUTD.DIAS) AS VARCHAR(3)),
						COALESCE(MED.TIPO_ID, @TIPODOC),COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),AUTD.VALOR,AUTD.VALOR * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) ,
						'04'
						,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
						,COALESCE(AUTD.NFACTURA,@N_FACTURA),AUT.IDAFILIADO
				FROM AUT 
					INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT
					INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN IART ON SER.IDSERVICIO=IART.IDSERVICIO AND PRINCIPAL = 1 
					LEFT JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
					LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
					LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)				
				WHERE AUTD.N_FACTURA=@N_FACTURA
					AND (AUT.NOAUT=@NOADMISION OR AUT.IDAUT=@NOADMISION)
					AND COALESCE(AUTD.VALOR,0)>0
					AND AUTD.CANTIDAD>0
					AND RIPS_CP.ARCHIVO='AM'
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT * FROM AUT WHERE N_FACTURA = @N_FACTURA AND PROCEDENCIA = 'APLIM')
				BEGIN
					PRINT 'ES DE PROCEDENCIA DE APLIM'
					INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
											,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
											,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
											,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
					SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
					COALESCE(AUT.IDMIPRESS,'null'),fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,COALESCE(IMOV.FECHACONF,IZSOL.FECHASOL),102),'.','-')+' '+LEFT(CONVERT(VARCHAR,IZSOL.FECHASOL,108),5),
						AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR LEFT(TRIM(AUT.DXRELACIONADO),4)=LEFT(TRIM(AUT.DXPPAL),4),'null',AUT.DXRELACIONADO),'01',COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''), (SELECT TOP 1 COALESCE(NULLIF(IUM,''), NULLIF(CODCUM,'')) FROM IART WHERE IDSERVICIO=AUTD.IDSERVICIO AND COALESCE(NULLIF(IUM,''), CODCUM,'')<>''), SER.CODCUM),LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),30),CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
						COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,COALESCE(IZSOLDT.CANTIDADSOL,0)),10), CAST(IIF(COALESCE(AUTD.DIAS,0)=0,1,AUTD.DIAS) AS VARCHAR(3)),
						COALESCE(MED.TIPO_ID, @TIPODOC),COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),AUTD.VALOR,AUTD.VALOR * ( CASE COALESCE(IZSOLDT.CANTIDADSOL,0) WHEN 0 THEN 1 ELSE IZSOLDT.CANTIDADSOL END ) ,
						'04'
						,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
						,COALESCE(AUTD.NFACTURA,@N_FACTURA),AUT.IDAFILIADO
					FROM AUT 
						INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT 
						INNER JOIN IZSOL ON AUT.CNSMOV=IZSOL.NOADMISION AND IZSOL.CLASE IN ('CE','APLIM')
                		INNER JOIN IZSOLD ON IZSOL.CNSIZSOL=IZSOLD.CNSIZSOL AND (AUTD.IDSERVICIO=IZSOLD.IDSERVICIO OR AUTD.IDSERVICIO = IZSOLD.IDARTICULO)
                		INNER JOIN IZSOLDT ON IZSOLD.CNSIZSOLD=IZSOLDT.CNSIZSOLD AND IZSOLD.IDARTICULO=IZSOLDT.IDARTICULO
						INNER JOIN SER ON IZSOLD.IDSERVICIO=SER.IDSERVICIO AND AUTD.IDSERVICIO = SER.IDSERVICIO
						INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
						LEFT  JOIN IMOV ON IZSOLDT.CNSMOV=IMOV.CNSMOV
                		LEFT  JOIN IART ON IART.IDARTICULO=IZSOLDT.IDARTICULOREAL 
						LEFT JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
						LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
						LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
						LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)				
					WHERE AUTD.N_FACTURA=@N_FACTURA
						AND (AUT.NOAUT=@NOADMISION OR AUT.IDAUT=@NOADMISION)
						AND COALESCE(AUTD.VALOR,0)>0
						AND AUTD.CANTIDAD>0
						AND RIPS_CP.ARCHIVO='AM'
				END
				ELSE
				BEGIN 
					INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
											,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
											,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
											,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
					SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
					COALESCE(AUT.IDMIPRESS,'null'),fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,COALESCE(IMOV.FECHACONF,IZSOL.FECHASOL),102),'.','-')+' '+LEFT(CONVERT(VARCHAR,IZSOL.FECHASOL,108),5),
						AUT.DXPPAL,IIF(COALESCE(AUT.DXRELACIONADO,'')='' OR LEFT(TRIM(AUT.DXRELACIONADO),4)=LEFT(TRIM(AUT.DXPPAL),4),'null',AUT.DXRELACIONADO),'01',COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''), (SELECT TOP 1 COALESCE(NULLIF(IUM,''), NULLIF(CODCUM,'')) FROM IART WHERE IDSERVICIO=AUTD.IDSERVICIO AND COALESCE(NULLIF(IUM,''), CODCUM,'')<>''), SER.CODCUM),LEFT( dbo.FNK_LIMPIATEXTO(IIF(COALESCE(IART.DESCRIPCION,'')='',SER.DESCSERVICIO,IART.DESCRIPCION),'0-9 A-Z();:.,'),30),CASE WHEN ISNUMERIC(dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9'))=1 THEN dbo.FNK_LIMPIATEXTO(LEFT(COALESCE(ICCN.DESCRIPCION,'0'),3),'0-9') ELSE 0 END,
						COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,COALESCE(IZSOLDT.CANTIDADSOL,0)),10), CAST(IIF(COALESCE(AUTD.DIAS,0)=0,1,AUTD.DIAS) AS VARCHAR(3)),
						COALESCE(MED.TIPO_ID, @TIPODOC),COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),AUTD.VALOR,AUTD.VALOR * ( CASE COALESCE(IZSOLDT.CANTIDADSOL,0) WHEN 0 THEN 1 ELSE IZSOLDT.CANTIDADSOL END ) ,
						'04'
						,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
						,COALESCE(AUTD.NFACTURA,@N_FACTURA),AUT.IDAFILIADO
					FROM AUT 
						INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT 
						INNER JOIN IZSOL ON AUT.CNSMOV=IZSOL.CNSIZSOL AND IZSOL.CLASE IN ('CE','APLIM')
                		INNER JOIN IZSOLD ON IZSOL.CNSIZSOL=IZSOLD.CNSIZSOL AND AUTD.IDSERVICIO=IZSOLD.IDSERVICIO
                		INNER JOIN IZSOLDT ON IZSOLD.CNSIZSOLD=IZSOLDT.CNSIZSOLD AND IZSOLD.IDARTICULO=IZSOLDT.IDARTICULO
						INNER JOIN SER ON IZSOLD.IDSERVICIO=SER.IDSERVICIO AND AUTD.IDSERVICIO = SER.IDSERVICIO
						INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
						LEFT  JOIN IMOV ON IZSOLDT.CNSMOV=IMOV.CNSMOV
                		LEFT  JOIN IART ON IART.IDARTICULO=IZSOLDT.IDARTICULOREAL 
						LEFT JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
						LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
						LEFT JOIN ICCN ON IART.IDCONCENTRA=ICCN.IDCONCENTRA
						LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)				
					WHERE AUTD.N_FACTURA=@N_FACTURA
						AND (AUT.NOAUT=@NOADMISION OR AUT.IDAUT=@NOADMISION)
						AND COALESCE(AUTD.VALOR,0)>0
						AND AUTD.CANTIDAD>0
						AND RIPS_CP.ARCHIVO='AM'
				END
			END
		END
		BEGIN --AP
			INSERT INTO #PROCEDIMIENTOS1 (codPrestador, fechaInicioAtencion, idMIPRES, numAutorizacion, codProcedimiento, vialngresoServicioSalud,modalidadGrupoServicioTecSal,
				grupoServicios ,codServicio ,finalidadTecnologiaSalud ,tipoDocumentoIdentificacion ,numDocumentoIdentificacion ,codDiagnosticoPrincipal ,codDiagnosticoRelacionado
				,codComplicacion ,vrServicio ,tipoPagoModerador ,valorPagoModerador ,numFEVPagoModerador,CANTIDAD,IDAFILIADO)
			SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5) ,'null',
                numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                LEFT(SER.CODCUPS,6) ,'02' ,'01',
				 grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				 codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				 -- '16',
				finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
				COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,@DOCIDAFILIADO), AUT.DXPPAL ,AUT.DXRELACIONADO
				--,AUT.DXPPAL,COALESCE(AUTD.VALOR * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) , 0) ,'04'
				,AUT.DXPPAL,COALESCE(AUTD.VALOR  , 0) ,'04'
				,CASE 
					WHEN AUT.IDPLAN IN (@IDPLANPART,@IDPLANPART2
										,@IDPLANPART3,@IDPLANPART4
										,@IDPLANPART5)
					THEN '0.00' 
					ELSE CASE WHEN COALESCE(FTRD.VLR_COPAGOS,0) >0 THEN COALESCE(FTRD.VLR_COPAGOS,0)
                         ELSE --CAST(CONVERT(DECIMAL(14,2), IIF(COALESCE(AUT.COPAGOPROPIO,0)=1, COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)), COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                          CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
                    END 
					END
				,COALESCE(AUTD.NFACTURA,@N_FACTURA), AUTD.CANTIDAD,AUT.IDAFILIADO
			FROM  FTRD LEFT JOIN AUTD     ON FTRD.NOPRESTACION = AUTD.IDAUT
                                      AND FTRD.NOITEM       = AUTD.NO_ITEM
                    INNER JOIN AUT     ON AUTD.IDAUT = AUT.IDAUT
                    INNER JOIN SER     ON AUTD.IDSERVICIO = SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
				    LEFT  JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)	
					--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
					INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
					LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 
         WHERE FTRD.N_FACTURA = @N_FACTURA
         AND   RIPS_CP.ARCHIVO = 'AP'
         AND   COALESCE(FTRD.VR_TOTAL,0)  > 0     
			UPDATE #PROCEDIMIENTOS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
			UPDATE #PROCEDIMIENTOS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
			SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM #PROCEDIMIENTOS1
			DECLARE JSPROCE_CURSOR_AUTD CURSOR FOR 
			SELECT consecutivo,CANTIDAD FROM #PROCEDIMIENTOS1
			ORDER BY consecutivo
			OPEN JSPROCE_CURSOR_AUTD
			FETCH NEXT FROM JSPROCE_CURSOR_AUTD INTO @CNSCONSULTA,@CANTORI
			WHILE @@FETCH_STATUS = 0    
			BEGIN
				SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
				SELECT @BANDERA=1
				WHILE @BANDERA<=@CANTORI
				BEGIN
					IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
					BEGIN
						SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
					END
					INSERT INTO #PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
								,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
								,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO
									)
					SELECT codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
									,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
									,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,@valorPagoModerador,numFEVPagoModerador,IDAFILIADO
					FROM #PROCEDIMIENTOS1
					WHERE consecutivo=@CNSCONSULTA
					SELECT @BANDERA = @BANDERA+1
				END
				FETCH NEXT FROM JSPROCE_CURSOR_AUTD INTO  @CNSCONSULTA,@CANTORI
			END
			CLOSE JSPROCE_CURSOR_AUTD
			DEALLOCATE JSPROCE_CURSOR_AUTD
		END
		BEGIN --AT
			INSERT INTO #OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
									,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
									,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
			SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
            'null', fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END, --20250702 -- STORRES -- ESPERA CAMPO PARA CONFIGURAR 
            codTecnologiaSalud=LEFT(SER.CODCUPS,20),nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
				cantidadOS=COALESCE(AUTD.CANTIDAD,1),tipoDocumentoIdentificacion=COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF),
				numDocumentoIdentificacion=COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT),
				COALESCE(AUTD.VALOR,0),
				COALESCE(AUTD.VALOR,0) * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) ,
				tipoPagoModerador='04',
				CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20)),
				COALESCE(AUTD.NFACTURA,@N_FACTURA),AUT.IDAFILIADO
			FROM AUT 
				INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT
				INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',@EPI_MEDICODEFAULT,AUT.IDMEDICOSOLICITA)
			WHERE AUT.NOAUT=@NOADMISION
			AND AUTD.N_FACTURA=@N_FACTURA
			AND COALESCE(AUTD.VALOR,0)>0
			AND AUTD.CANTIDAD>0
			AND RIPS_CP.ARCHIVO='AT'
		END
	END
--query2
--query2
	ELSE IF @PROCEDENCIA='SALUD'
	BEGIN	 
      IF EXISTS(SELECT * FROM HADMF WHERE NOADMISION=@NOADMISION AND DESCRIPCION='COPAGOS')
      BEGIN
         SELECT TOP 1 @NFACTURA=N_FACTURA  FROM HADMF WHERE NOADMISION=@NOADMISION AND DESCRIPCION='COPAGOS'
      END  
	  DECLARE @FORMATOCODIGO SMALLINT
	  SELECT @PAQUETIZADO = PPT.PAQUETIZADO,@FORMATOCODIGO=IMPRIMEIDALTERNA FROM PPT INNER JOIN FTR ON PPT.IDPLAN= FTR.IDPLAN AND PPT.IDTERCERO = FTR.IDTERCERO WHERE FTR.N_FACTURA = @N_FACTURA

		IF @PAQUETIZADO =1 
		BEGIN
			PRINT 'PAQUETIZADO '
			IF 1=1
			BEGIN --AC
			 PRINT 'SALUD AC' 
				INSERT INTO #CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad,IDAFILIADO) 
				SELECT COALESCE(@IDPRESTADOR,'')
				,fechaInicioAtencion=CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN  THEN   @fechaInicioAtencion
										  ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
									 END,
					numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION),'null') IN ('',' ','  '), 'null',COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION)),'A-Z0-9-') -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
				,codConsulta=LEFT(SER.CODCUPS,6),
				modalidadGrupoServicioTecSal='01',
				grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
					codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				 FINALIDADTECNOLOGIASALUD=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'15') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '15' ELSE COALESCE(FINALIDADTGEN.DATO1,'15') END,2), --se realiza cambio para que la finalidad no sea 12 ya que no aplica para asistencial -- KR 20260619
						causaMotivoAtencion=CASE WHEN COALESCE(TGEN.CHECK1,0)=1 AND COALESCE(TGEN.DATO1,'')<>'' THEN TGEN.DATO1 ELSE TGEN.CODIGO END -- SE AGREGA CASE PARA QUE LA CAUSAEXTERNA CONCUERDE CON LA DE LA ADMISION --KR 20260619
						                   ,COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HCA.DX3,HADM.DXSALIDA3),
					CASE HCA.TIPODX 
									WHEN 'Presuntivo'   THEN 1
									WHEN 'Impresion dx' THEN 1
									WHEN 'Definitivo'   THEN 2
									WHEN 'Conf Nuevo'   THEN 2
									WHEN 'Conf Repet'   THEN 3
									ELSE 1
									END,
					CASE WHEN COALESCE(@PAQUETE,0) = 0 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
				COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO,CONVERT(INT,HPRED.CANTIDAD),HADM.IDAFILIADO
				FROM HADM 
					INNER JOIN  HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3 
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
					LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
                    LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
                    LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
                    LEFT JOIN TGEN ON HADM.CAUSAEXTERNA=TGEN.CODIGO AND TGEN.TABLA='General' AND TGEN.CAMPO='CAUSAEXTERNA' -- SE AGREGA LEFT CON TGEN PARA QUE LA CAUSA EXTERNA CONCUERDE CON LA DE LA ADMISION --KR 20260619
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND COALESCE(HPRED.CANTIDAD,0)>0
					AND COALESCE(HPRED.PAQUETE,0)=1
					AND RIPS_CP.ARCHIVO='AC'

				UPDATE #CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
				UPDATE #CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
				SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM #CONSULTAS1
				DECLARE JSCONSUL_CURSOR CURSOR FOR 
				SELECT consecutivo,CANTIDAD FROM #CONSULTAS1
				ORDER BY consecutivo
				OPEN JSCONSUL_CURSOR    
				FETCH NEXT FROM JSCONSUL_CURSOR    
				INTO @CNSCONSULTA,@CANTORI
				WHILE @@FETCH_STATUS = 0    
				BEGIN 
					SELECT @BANDERA=1
					--SELECT valorPagoModerador, @CANTORI FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
					SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
					--SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
					WHILE @BANDERA<=@CANTORI
					BEGIN
						IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
						BEGIN
							SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
						END
						INSERT INTO #CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO) 
						SELECT codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,@valorPagoModerador,numFEVPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO
						FROM #CONSULTAS1
						WHERE consecutivo=@CNSCONSULTA
						SELECT @BANDERA = @BANDERA+1
					END
					FETCH NEXT FROM JSCONSUL_CURSOR    
					INTO  @CNSCONSULTA,@CANTORI
				END
				CLOSE JSCONSUL_CURSOR
				DEALLOCATE JSCONSUL_CURSOR
			END
			IF 1=1
			BEGIN --AM
			 PRINT 'SALUD AM'
				INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
										,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
										,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
										,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador, MED, idArticulo,IDAFILIADO)
				SELECT @IDPRESTADOR,
            		 numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION),'null') IN ('',' ','  '), 'null', COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION)),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
					'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
						COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),'01',dbo.FNK_LIMPIATEXTO(COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''),NULLIF(SER.CODCUM,''), SER.IDSERVICIO),'A-Z0-9-') ,LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),0, -- 20250815 -- STORRES -- SE AGREGA COMANDO NULLIF PARA CONVERTIR LOS VACIOS '' A NULL Y PODER CONTINUAR CON EL COALESCE
						COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,HPRED.CANTIDAD),10),1,LEFT(MED.TIPO_ID,2),MED.IDMEDICO,
					CASE WHEN COALESCE(@PAQUETE,0) = 0 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR),20)END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
						CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR*HPRED.CANTIDAD),20) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
					'04',CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALORCOPAGO),20),COALESCE(@NFACTURA,@N_FACTURA), SER.MEDICAMENTOS, HPRED.IDARTICULO,HADM.IDAFILIADO
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN IART ON COALESCE(HPRED.IDARTICULO,SER.IDARTICULO)=IART.IDARTICULO
					LEFT JOIN IFFA ON IART.IDFORFARM=IFFA.IDFORFARM
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3 
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					LEFT JOIN IUNI ON IUNI.IDUNIDAD = IART.IDUNIDAD
					LEFT JOIN MED ON MED.IDMEDICO = COALESCE(NULLIF(HADM.IDMEDICOTRA,''), NULLIF(HADM.IDMEDICOING,''), NULLIF(HADM.IDMEDICOALTA,''), NULLIF(HPRE.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND COALESCE(HPRED.CANTIDAD,0)>0
					AND COALESCE(HPRED.IDCIRUGIA,'') ='' 
					AND COALESCE(HPRED.PAQUETE,0)=1
					AND RIPS_CP.ARCHIVO='AM' 
				BEGIN
					UPDATE #MEDICAMENTOS SET MED=1, codTecnologiaSalud=COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''), NULLIF(SER.CODCUM,''))
					FROM #MEDICAMENTOS A 
						INNER JOIN SER ON SER.IDSERVICIO COLLATE DATABASE_DEFAULT= A.codTecnologiaSalud COLLATE DATABASE_DEFAULT
						INNER JOIN IART ON IART.IDARTICULO COLLATE DATABASE_DEFAULT =A.IDARTICULO COLLATE DATABASE_DEFAULT
					WHERE SER.MEDICAMENTOS=1 AND ISNULL(A.codTecnologiaSalud,'')='' OR ISNULL(A.codTecnologiaSalud,'') NOT LIKE '%-%'
					UPDATE #MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE ISNULL(SER.CODCUM,'') WHEN '' THEN A.codTecnologiaSalud ELSE SER.CODCUM END
					FROM #MEDICAMENTOS A 
					INNER JOIN SER ON A.codTecnologiaSalud=SER.IDSERVICIO
					WHERE SER.MEDICAMENTOS=1 AND ISNULL(codTecnologiaSalud,'')='' OR ISNULL(codTecnologiaSalud,'') NOT LIKE '%-%'
					UPDATE #MEDICAMENTOS SET codTecnologiaSalud=DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9-') FROM #MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'	
					UPDATE #MEDICAMENTOS SET codTecnologiaSalud=(stuff((select CONCAT('-',IIF(ISNUMERIC(WORD)=1 AND CONVERT(INT, WORD)>0, CONVERT(INT, WORD),WORD)) 
													FROM DBO.FNK_EXPLODE(codTecnologiaSalud,'-') FOR XML PATH('')),1,1,'')
													)
					FROM #MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'
				END
			END
			IF 1=1
			BEGIN --AP
			 PRINT 'SALUD AP'
				INSERT INTO #PROCEDIMIENTOS1 (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
							,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
							,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,cantidad,vrtotal,IDAFILIADO
							)
				SELECT @IDPRESTADOR
				,CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN   THEN @fechaInicioAtencion
					  ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
				 END
				,'null',
					numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION),'null') IN ('',' ','  '), 'null', COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION)),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
				LEFT(SER.CODCUPS,6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
				grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
					codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				'16',COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF),COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT),COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
					COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
				CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
				'04',COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA),HPRED.CANTIDAD,
				CASE WHEN COALESCE(@PAQUETE,0) = 0 THEN 0 ELSE FTRD.VLR_SERVICI END,HADM.IDAFILIADO --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT  JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
					INNER JOIN FTRD ON HPRED.NOPRESTACION = FTRD.NOPRESTACION 
								AND HPRED.NOITEM       = FTRD.NOITEM
								AND HPRED.N_FACTURA    = FTRD.N_FACTURA 
								AND HADM.NOADMISION    = FTRD.NOADMISION
					LEFT JOIN MED ON MED.IDMEDICO = COALESCE(NULLIF(HADM.IDMEDICOTRA,''), NULLIF(HADM.IDMEDICOING,''), NULLIF(HADM.IDMEDICOALTA,''), NULLIF(HPRE.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3 
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND HPRED.CANTIDAD > 0
					AND COALESCE(HPRED.PAQUETE,0)=1
					AND RIPS_CP.ARCHIVO='AP'
					AND COALESCE(HPRED.IDCIRUGIA,'') =''

				DECLARE JSPROCE_CURSOR CURSOR FOR 
				SELECT consecutivo,CANTIDAD,vrtotal, valorPagoModerador FROM #PROCEDIMIENTOS1
				ORDER BY consecutivo
				OPEN JSPROCE_CURSOR    
				FETCH NEXT FROM JSPROCE_CURSOR INTO @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
				WHILE @@FETCH_STATUS = 0    
				BEGIN 
					--SELECT  @valorPagoModerador=CONVERT(VARCHAR(20), CONVERT(DECIMAL (14,2),CAST(valorPagoModerador AS decimal(14,2))/@CANTORI)) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
				SELECT @BASE = @TOTALFTRD/@CANTORI
				SELECT @RESTO = @TOTALFTRD % @CANTORI
				SELECT @BASEMOD = CONVERT(DECIMAL (14,4),CAST(@TOTALMOD AS decimal(14,4)) / @CANTORI)
				SELECT @RESTOMOD = CONVERT(DECIMAL (14,4),CAST(@TOTALMOD AS decimal(14,4)) % @CANTORI)
				;WITH cte AS ( SELECT 1 AS n UNION ALL SELECT n + 1 FROM cte WHERE n + 1 <= @CANTORI )
				INSERT INTO #PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
								   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
									,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
				   SELECT codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion
				   ,codProcedimiento,vialngresoServicioSalud
							   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
							   ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,
						 CASE WHEN n <= @RESTO THEN @BASE + 1 ELSE @BASE END                    
						 ,tipoPagoModerador,
						 CASE WHEN n <= @RESTOMOD THEN CONVERT(VARCHAR(20), @BASEMOD + 1) ELSE CONVERT(VARCHAR(20), @BASEMOD) END
						 ,numFEVPagoModerador,IDAFILIADO
					FROM #PROCEDIMIENTOS1 X, cte
					WHERE X.consecutivo=@CNSCONSULTA 
				 OPTION (MAXRECURSION 0)
					FETCH NEXT FROM JSPROCE_CURSOR INTO  @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
				END
				CLOSE JSPROCE_CURSOR
				DEALLOCATE JSPROCE_CURSOR
			 PRINT 'INSERTO CIRUGIAS'
			 IF EXISTS (SELECT 1 FROM HPRE INNER JOIN HPRED ON HPRE.NOPRESTACION = HPRED.NOPRESTACION
						 WHERE HPRE.NOADMISION = @NOADMISION
							AND HPRED.N_FACTURA = @N_FACTURA AND COALESCE(HPRED.VALOR, 0) > 0 AND COALESCE(HPRED.NOCOBRABLE, 0) = 0
							AND COALESCE(HPRED.IDCIRUGIA,'') <> '' 
				)
			 BEGIN
			
				IF ( @CIRUJANOENJSON ='SI')
				BEGIN 

					INSERT INTO #PROCEDIMIENTOS  (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
										   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
											,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
						   SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
								 LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
							  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
							  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
							  -- ,'16',   -- PUEDEN SER PRODECIMIENTOS DIAGNOSTICOS '15'
									,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
							COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
								 upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
								 upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
							  --SUM(HPRED.VALOREXCEDENTE) 
							  SUM(HPRED.VALOR*HPRED.CANTIDAD) --EEMC 16-09-2025  SE MODIFICA POR QUE ESTA GENERANDO INCONSISTENCIAS EN LA SUMATORIA DE LA FACTURA CONTRA EL RIPS
							  ,NULL -- IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
							  ,SUM(COALESCE(HPRED.VALORCOPAGO,0)),@N_FACTURA,HADM.IDAFILIADO
						 FROM  HADM    INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
										INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION 
										INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
										INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
										INNER JOIN SER  SER1   ON HPRED.IDSERVICIO=SER1.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
										INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
										INNER JOIN RIPS_CP CP ON SER1.CODIGORIPS=CP.IDCONCEPTORIPS
										LEFT JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'  --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
										LEFT JOIN  ( -- EEMC78 21-04-2026 PARA COLOCA EN EL PROCEDIMIENTO EL MEDICO CIRUJANO 
													select hpred.IDPROVEEDOR , IDCIRUGIA, ITEMCIRUGIA
													from HPRE    
														INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
													WHERE HPRE.NOADMISION=@NOADMISION
														AND HPRED.N_FACTURA = @N_FACTURA
														AND COALESCE(HPRED.VALOR,0) > 0
														AND COALESCE(HPRED.NOCOBRABLE,0) = 0
														AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
														AND  hpred.TIPOSERCIRUGIA ='Cirujano'
												)  CIR ON HPRED.IDCIRUGIA = CIR.IDCIRUGIA AND HPRED.ITEMCIRUGIA = CIR.ITEMCIRUGIA
														LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN   COALESCE(CIR.IDPROVEEDOR,'') <> ''  THEN CIR.IDPROVEEDOR
																					WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN @EPI_MEDICODEFAULT 
																				ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
							--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
								LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
								LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
						 WHERE HADM.NOADMISION=@NOADMISION
						 AND HPRED.N_FACTURA = @N_FACTURA
						 AND COALESCE(HPRED.VALOR,0) > 0
						 AND COALESCE(HPRED.NOCOBRABLE,0) = 0
						 AND COALESCE(SER.CIRUGIA,0) = 1
						 AND COALESCE(HPRED.PAQUETE,0)=1
							AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
						 GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30),
								left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),
								CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END,
								COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),
								CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END,
								CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
								IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
										,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2)  -- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								ORDER BY HADM.NOADMISION

				END
				ELSE
				BEGIN

					INSERT INTO #PROCEDIMIENTOS  (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
									   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
										,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
					   SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
							 LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30)  ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
						  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
						  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
						  -- ,'16',   -- PUEDEN SER PRODECIMIENTOS DIAGNOSTICOS '15'
								,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
						COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
							 upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
							 upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
						  --SUM(HPRED.VALOREXCEDENTE) 
						  SUM(HPRED.VALOR*HPRED.CANTIDAD) --EEMC 16-09-2025  SE MODIFICA POR QUE ESTA GENERANDO INCONSISTENCIAS EN LA SUMATORIA DE LA FACTURA CONTRA EL RIPS
						  ,NULL -- IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
						  ,SUM(COALESCE(HPRED.VALORCOPAGO,0)),@N_FACTURA,HADM.IDAFILIADO
					 FROM  HADM    INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
									INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION 
									INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
									INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN SER  SER1   ON HPRED.IDSERVICIO=SER1.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
									INNER JOIN RIPS_CP CP ON SER1.CODIGORIPS=CP.IDCONCEPTORIPS
									LEFT JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'  --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
									LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN @EPI_MEDICODEFAULT 
															ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
								 
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
							INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
							LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
							LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
					 WHERE HADM.NOADMISION=@NOADMISION
						AND HPRED.N_FACTURA = @N_FACTURA
						AND COALESCE(HPRED.VALOR,0) > 0
						AND COALESCE(HPRED.NOCOBRABLE,0) = 0
						AND COALESCE(SER.CIRUGIA,0) = 1
						AND COALESCE(HPRED.PAQUETE,0)=1
						AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
					 GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30),
							left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),
							CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END,
							COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),
							CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END,
							CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
							IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
									,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2)  -- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
							ORDER BY HADM.NOADMISION
				END
			 END
			END
			IF 1=1
			BEGIN --AT
			 PRINT 'SALUD AT' 
			 DECLARE @TIPOIMP SMALLINT
			 SELECT @TIPOIMP=IMPRIMEIDALTERNA FROM PPT WHERE IDPLAN=@IDPLAN AND IDTERCERO=@IDTERCERO
				INSERT INTO #OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
									,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
									,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
				SELECT @IDPRESTADOR ,DBO.FNK_LIMPIATEXTO(COALESCE(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION),'null'),'A-Z0-9-'),'null' 
				, CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN   THEN @fechaInicioAtencion
					   ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
				  end
					, tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END --20250702 -- STORRES -- A A ESPERA QUE SE CREE EL CAMPO PARA CONFIGURAR
				, LEFT(IIF(RIPS_CP.IDCONCEPTORIPS=@IDMATERIALESRIPS AND @TIPOIMP NOT IN(9) , SER.IDSERVICIO, SER.CODCUPS),20),LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
					, CONVERT(INT,COALESCE(HPRED.CANTIDAD,1)),COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF),COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT)
				, CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
				, CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR*HPRED.CANTIDAD,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
					,'04',CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALORCOPAGO,0)) ,COALESCE(@NFACTURA,@N_FACTURA),HADM.IDAFILIADO                                                                      
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
                    INNER JOIN FTRD ON HADM.NOADMISION = FTRD.NOADMISION AND HPRE.NOPRESTACION = FTRD.NOPRESTACION AND HPRED.IDSERVICIO = FTRD.REFERENCIA
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN MED ON MED.IDMEDICO = COALESCE(NULLIF(HADM.IDMEDICOTRA,''), NULLIF(HADM.IDMEDICOING,''), NULLIF(HADM.IDMEDICOALTA,''), NULLIF(HPRE.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0		
					AND COALESCE(HPRED.CANTIDAD,0)>0
					AND COALESCE(HPRED.PAQUETE,0)=1
					AND COALESCE(HPRED.IDCIRUGIA,'') =''
					AND RIPS_CP.ARCHIVO='AT'  
                    AND FTRD.N_FACTURA = @N_FACTURA
                    AND COALESCE(FTRD.PAQUETE,0) <> 2
			END
		
		END 
		ELSE
		BEGIN
		 PRINT  'NO PAQUETIZADO '
			IF 1=1
			BEGIN --AC
			 PRINT 'SALUD AC' 
				INSERT INTO #CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad,IDAFILIADO) 
				SELECT COALESCE(@IDPRESTADOR,'')
				,fechaInicioAtencion=CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN  THEN   @fechaInicioAtencion
										  ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
									 END,
				--	numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION),'null') IN ('',' ','  '), 'null',COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION)),'A-Z0-9-') -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
             numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-')
				,codConsulta=LEFT(SER.CODCUPS,6),
				modalidadGrupoServicioTecSal='01',
				grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
					codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				 FINALIDADTECNOLOGIASALUD=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'15') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '15' ELSE COALESCE(FINALIDADTGEN.DATO1,'15') END,2), --se realiza cambio para que la finalidad no sea 12 ya que no aplica para asistencial -- KR 20260619
						causaMotivoAtencion=CASE WHEN COALESCE(TGEN.CHECK1,0)=1 AND COALESCE(TGEN.DATO1,'')<>'' THEN TGEN.DATO1 ELSE TGEN.CODIGO END -- SE AGREGA CASE PARA QUE LA CAUSAEXTERNA CONCUERDE CON LA DE LA ADMISION --KR 20260619
                                             ,COALESCE(HADM.DXINGRESO,HCA.IDDX,HADM.DXEGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HCA.DX3,HADM.DXSALIDA3),
					CASE HCA.TIPODX 
									WHEN 'Presuntivo'   THEN 1
									WHEN 'Impresion dx' THEN 1
									WHEN 'Definitivo'   THEN 2
									WHEN 'Conf Nuevo'   THEN 2
									WHEN 'Conf Repet'   THEN 3
									ELSE 1
									END,
					CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
				COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO,CONVERT(INT,HPRED.CANTIDAD),HADM.IDAFILIADO
				FROM HADM 
					INNER JOIN  HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3 
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                    INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
					LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
                    LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
                    LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
                    LEFT JOIN TGEN ON HADM.CAUSAEXTERNA=TGEN.CODIGO AND TGEN.TABLA='General' AND TGEN.CAMPO='CAUSAEXTERNA' -- SE AGREGA LEFT CON TGEN PARA QUE LA CAUSA EXTERNA CONCUERDE CON LA DE LA ADMISION --KR 20260619
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND COALESCE(HPRED.CANTIDAD,0)>0
					AND RIPS_CP.ARCHIVO='AC'


				UPDATE #CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
				UPDATE #CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
				SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM #CONSULTAS1
				DECLARE JSCONSUL_CURSOR CURSOR FOR 
				SELECT consecutivo,CANTIDAD FROM #CONSULTAS1
				ORDER BY consecutivo
				OPEN JSCONSUL_CURSOR    
				FETCH NEXT FROM JSCONSUL_CURSOR    
				INTO @CNSCONSULTA,@CANTORI
				WHILE @@FETCH_STATUS = 0    
				BEGIN 
					SELECT @BANDERA=1
					--SELECT valorPagoModerador, @CANTORI FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
					SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM #CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
					--SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
					WHILE @BANDERA<=@CANTORI
					BEGIN
						IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
						BEGIN
							SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
						END
						INSERT INTO #CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO) 
						SELECT codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
									codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,@valorPagoModerador,numFEVPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion,IDAFILIADO
						FROM #CONSULTAS1
						WHERE consecutivo=@CNSCONSULTA
						SELECT @BANDERA = @BANDERA+1
					END
					FETCH NEXT FROM JSCONSUL_CURSOR    
					INTO  @CNSCONSULTA,@CANTORI
				END
				CLOSE JSCONSUL_CURSOR
				DEALLOCATE JSCONSUL_CURSOR
			END
			IF 1=1
			BEGIN --AM
			 PRINT 'SALUD AM'
				INSERT INTO #MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
										,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
										,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
										,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador, MED, idArticulo,IDAFILIADO)
				SELECT @IDPRESTADOR,
            		 numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
					'null',fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
						COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),'01',CASE WHEN @FORMATOCODIGO <> 13
						THEN dbo.FNK_LIMPIATEXTO(COALESCE(NULLIF(IIF(LEN(IART.IUM)<10,NULL,IART.IUM),''), NULLIF(IART.CODCUM,''),NULLIF(SER.CODCUM,''), SER.IDSERVICIO),'A-Z0-9-')	 -- STORRES 2026610 se agrega validacion de IART.IUM para que entre unicamente si tiene mas de 10 caracteres. 
						ELSE  dbo.FNK_LIMPIATEXTO(COALESCE(NULLIF(SER.CODSISPRO,''), NULLIF(IIF(LEN(IART.IUM)<10,NULL,IART.IUM),''), NULLIF(IART.CODCUM,''),NULLIF(SER.CODCUM,''), SER.IDSERVICIO),'A-Z0-9-') -- STORRES 2026610 se agrega validacion de IART.IUM para que entre unicamente si tiene mas de 10 caracteres. 
						END ,LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),0, -- 20250815 -- STORRES -- SE AGREGA COMANDO NULLIF PARA CONVERTIR LOS VACIOS '' A NULL Y PODER CONTINUAR CON EL COALESCE
						COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,HPRED.CANTIDAD),10),1,LEFT(MED.TIPO_ID,2),MED.IDMEDICO,
					CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR),20)END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
						CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR*HPRED.CANTIDAD),20) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
					'04',CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALORCOPAGO),20),COALESCE(@NFACTURA,@N_FACTURA), SER.MEDICAMENTOS, HPRED.IDARTICULO,HADM.IDAFILIADO
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN IART ON COALESCE(HPRED.IDARTICULO,SER.IDARTICULO)=IART.IDARTICULO
					LEFT JOIN IFFA ON IART.IDFORFARM=IFFA.IDFORFARM
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3,IDMEDICO
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					LEFT JOIN IUNI ON IUNI.IDUNIDAD = IART.IDUNIDAD
					LEFT JOIN MED ON CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,HCA.IDMEDICO,'')='' THEN IIF(COALESCE(HPRE.IDMEDICO,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),COALESCE(HPRE.IDMEDICO,'')) ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,HCA.IDMEDICO,'') END=MED.IDMEDICO
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND COALESCE(HPRED.CANTIDAD,0)>0
				AND COALESCE(HPRED.IDCIRUGIA,'') ='' 
					AND RIPS_CP.ARCHIVO='AM' 
				BEGIN
					UPDATE #MEDICAMENTOS SET MED=1, codTecnologiaSalud=COALESCE(NULLIF(IART.IUM,''), NULLIF(IART.CODCUM,''), NULLIF(SER.CODCUM,''))
					FROM #MEDICAMENTOS A 
						INNER JOIN SER ON SER.IDSERVICIO COLLATE DATABASE_DEFAULT= A.codTecnologiaSalud COLLATE DATABASE_DEFAULT
						INNER JOIN IART ON IART.IDARTICULO COLLATE DATABASE_DEFAULT =A.IDARTICULO COLLATE DATABASE_DEFAULT
					WHERE SER.MEDICAMENTOS=1 AND ISNULL(A.codTecnologiaSalud,'')='' OR ISNULL(A.codTecnologiaSalud,'') NOT LIKE '%-%'
					UPDATE #MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE ISNULL(SER.CODCUM,'') WHEN '' THEN A.codTecnologiaSalud ELSE SER.CODCUM END
					FROM #MEDICAMENTOS A 
					INNER JOIN SER ON A.codTecnologiaSalud=SER.IDSERVICIO
					WHERE SER.MEDICAMENTOS=1 AND ISNULL(codTecnologiaSalud,'')='' OR ISNULL(codTecnologiaSalud,'') NOT LIKE '%-%'
					UPDATE #MEDICAMENTOS SET codTecnologiaSalud=DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9-') FROM #MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'	
					UPDATE #MEDICAMENTOS SET codTecnologiaSalud=(stuff((select CONCAT('-',IIF(ISNUMERIC(WORD)=1 AND CONVERT(INT, WORD)>0, CONVERT(INT, WORD),WORD)) 
													FROM DBO.FNK_EXPLODE(codTecnologiaSalud,'-') FOR XML PATH('')),1,1,'')
													)
					FROM #MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'
				END
			END
			IF 1=1
			BEGIN --AP
			 PRINT 'SALUD AP'
				INSERT INTO #PROCEDIMIENTOS1 (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
							,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
							,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,cantidad,vrtotal,IDAFILIADO
							)
				SELECT @IDPRESTADOR
				,CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN   THEN @fechaInicioAtencion
					  ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
				 END
				,'null',
			   numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
				LEFT(SER.CODCUPS,6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
				grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
					codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				'16',COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF),COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HCA.IDDX,HADM.DXEGRESO),
					COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HADM.DXINGRESO,HCA.IDDX,HADM.DXEGRESO),
				CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
				'04',COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA),HPRED.CANTIDAD,
				CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE FTRD.VLR_SERVICI END,HADM.IDAFILIADO --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT  JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
					INNER JOIN FTRD ON HPRED.NOPRESTACION = FTRD.NOPRESTACION 
								AND HPRED.NOITEM       = FTRD.NOITEM
								AND HPRED.N_FACTURA    = FTRD.N_FACTURA 
								AND HADM.NOADMISION    = FTRD.NOADMISION
					LEFT JOIN MED ON MED.IDMEDICO = COALESCE(NULLIF(HADM.IDMEDICOTRA,''), NULLIF(HADM.IDMEDICOING,''), NULLIF(HADM.IDMEDICOALTA,''), NULLIF(HPRE.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,
							COALESCE(PX.DX1,HCA.DX1,'')DX1,COALESCE(PX.DX2,HCA.DX2,'')DX2,COALESCE(PX.DX3,HCA.DX3,'')DX3 
							FROM HCA 
							LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
							WHERE NOADMISION=@NOADMISION AND COALESCE(HCA.IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>@HCPLANTILLAEPI
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0
					AND HPRED.CANTIDAD > 0
					AND RIPS_CP.ARCHIVO='AP'
					AND COALESCE(HPRED.IDCIRUGIA,'') =''
				 --SET @TOTALFTRD = 0 , @BASE  = 0 , @RESTO  = 0 , @TOTALMOD ='', @BASEMOD = 0, @RESTOMOD =0 
				DECLARE JSPROCE_CURSOR CURSOR FOR 
				SELECT consecutivo,CANTIDAD,vrtotal, valorPagoModerador FROM #PROCEDIMIENTOS1
				ORDER BY consecutivo
				OPEN JSPROCE_CURSOR    
				FETCH NEXT FROM JSPROCE_CURSOR INTO @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
				WHILE @@FETCH_STATUS = 0    
				BEGIN 
					--SELECT  @valorPagoModerador=CONVERT(VARCHAR(20), CONVERT(DECIMAL (14,2),CAST(valorPagoModerador AS decimal(14,2))/@CANTORI)) FROM #PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
				SELECT @BASE = @TOTALFTRD/@CANTORI
				SELECT @RESTO = @TOTALFTRD % @CANTORI
				SELECT @BASEMOD = CONVERT(DECIMAL (14,4),CAST(@TOTALMOD AS decimal(14,4)) / @CANTORI)
				SELECT @RESTOMOD = CONVERT(DECIMAL (14,4),CAST(@TOTALMOD AS decimal(14,4)) % @CANTORI)
				;WITH cte AS ( SELECT 1 AS n UNION ALL SELECT n + 1 FROM cte WHERE n + 1 <= @CANTORI )
				INSERT INTO #PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
								   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
									,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
				   SELECT codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion
				   ,codProcedimiento,vialngresoServicioSalud
							   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
							   ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,
						 CASE WHEN n <= @RESTO THEN @BASE + 1 ELSE @BASE END                    
						 ,tipoPagoModerador,
						 CASE WHEN n <= @RESTOMOD THEN CONVERT(VARCHAR(20), @BASEMOD + 1) ELSE CONVERT(VARCHAR(20), @BASEMOD) END
						 ,numFEVPagoModerador,IDAFILIADO
					FROM #PROCEDIMIENTOS1 X, cte
					WHERE X.consecutivo=@CNSCONSULTA 
				 OPTION (MAXRECURSION 0)
					FETCH NEXT FROM JSPROCE_CURSOR INTO  @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
				END
				CLOSE JSPROCE_CURSOR
				DEALLOCATE JSPROCE_CURSOR
			 PRINT 'INSERTO CIRUGIAS'
			 IF EXISTS (SELECT 1 FROM HPRE INNER JOIN HPRED ON HPRE.NOPRESTACION = HPRED.NOPRESTACION
						 WHERE HPRE.NOADMISION = @NOADMISION
							AND HPRED.N_FACTURA = @N_FACTURA AND COALESCE(HPRED.VALOR, 0) > 0 AND COALESCE(HPRED.NOCOBRABLE, 0) = 0
							AND COALESCE(HPRED.IDCIRUGIA,'') <> '' 
				)
			 BEGIN
			
				IF ( @CIRUJANOENJSON ='SI')
				BEGIN 

					INSERT INTO #PROCEDIMIENTOS  (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
										   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
											,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
						   SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
								 numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-')  
                        ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
							  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
							  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
							  -- ,'16',   -- PUEDEN SER PRODECIMIENTOS DIAGNOSTICOS '15'
									,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
							COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
								 upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
								 upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
							  --SUM(HPRED.VALOREXCEDENTE) 
							  SUM(HPRED.VALOR*HPRED.CANTIDAD) --EEMC 16-09-2025  SE MODIFICA POR QUE ESTA GENERANDO INCONSISTENCIAS EN LA SUMATORIA DE LA FACTURA CONTRA EL RIPS
							  ,NULL -- IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
							  ,SUM(COALESCE(HPRED.VALORCOPAGO,0)),@N_FACTURA,HADM.IDAFILIADO
						 FROM  HADM    INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
										INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION 
										INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
										INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
										INNER JOIN SER  SER1   ON HPRED.IDSERVICIO=SER1.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
										INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
										INNER JOIN RIPS_CP CP ON SER1.CODIGORIPS=CP.IDCONCEPTORIPS
										LEFT JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'  --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
										LEFT JOIN  ( -- EEMC78 21-04-2026 PARA COLOCA EN EL PROCEDIMIENTO EL MEDICO CIRUJANO 
													select hpred.IDPROVEEDOR , IDCIRUGIA, ITEMCIRUGIA
													from HPRE    
														INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
													WHERE HPRE.NOADMISION=@NOADMISION
														AND HPRED.N_FACTURA = @N_FACTURA
														AND COALESCE(HPRED.VALOR,0) > 0
														AND COALESCE(HPRED.NOCOBRABLE,0) = 0
														AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
														AND  hpred.TIPOSERCIRUGIA ='Cirujano'
												)  CIR ON HPRED.IDCIRUGIA = CIR.IDCIRUGIA AND HPRED.ITEMCIRUGIA = CIR.ITEMCIRUGIA
														LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN   COALESCE(CIR.IDPROVEEDOR,'') <> ''  THEN CIR.IDPROVEEDOR
																					WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN @EPI_MEDICODEFAULT 
																				ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
							--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
								LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
								LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
						 WHERE HADM.NOADMISION=@NOADMISION
						 AND HPRED.N_FACTURA = @N_FACTURA
						 AND COALESCE(HPRED.VALOR,0) > 0
						 AND COALESCE(HPRED.NOCOBRABLE,0) = 0
						 AND COALESCE(SER.CIRUGIA,0) = 1
							AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
						 GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30),
								left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),
								CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END,
								COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),
								CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END,
								CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
								IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
										,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2)  -- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								ORDER BY HADM.NOADMISION

				END
				ELSE
				BEGIN

					INSERT INTO #PROCEDIMIENTOS  (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
									   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
										,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
					   SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
							numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-')
                     ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
						  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
						  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
						  -- ,'16',   -- PUEDEN SER PRODECIMIENTOS DIAGNOSTICOS '15'
								,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
						COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
							 upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
							 upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
						  --SUM(HPRED.VALOREXCEDENTE) 
						  SUM(HPRED.VALOR*HPRED.CANTIDAD) --EEMC 16-09-2025  SE MODIFICA POR QUE ESTA GENERANDO INCONSISTENCIAS EN LA SUMATORIA DE LA FACTURA CONTRA EL RIPS
						  ,NULL -- IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
						  ,SUM(COALESCE(HPRED.VALORCOPAGO,0)),@N_FACTURA,HADM.IDAFILIADO
					 FROM  HADM    INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
									INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION 
									INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
									INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN SER  SER1   ON HPRED.IDSERVICIO=SER1.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
									INNER JOIN RIPS_CP CP ON SER1.CODIGORIPS=CP.IDCONCEPTORIPS
									LEFT JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'  --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
									LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN @EPI_MEDICODEFAULT 
															ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
								 
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
							INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
							LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
							LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
					 WHERE HADM.NOADMISION=@NOADMISION
					 AND HPRED.N_FACTURA = @N_FACTURA
					 AND COALESCE(HPRED.VALOR,0) > 0
					 AND COALESCE(HPRED.NOCOBRABLE,0) = 0
					 AND COALESCE(SER.CIRUGIA,0) = 1
					 AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
					 AND COALESCE(HPRED.TIPOSERCIRUGIA,'')<>'PAQUETE'
					 GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),LEFT(COALESCE(HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,'null'),30),
							left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),
							CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END,
							COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),
							CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END,
							CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
							IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
									,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2)  -- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								
							ORDER BY HADM.NOADMISION

					INSERT INTO #PROCEDIMIENTOS  (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
									   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
										,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,IDAFILIADO )
					   SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),'null',
							numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-')
                     ,left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
						  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, 
						  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END 
						  -- ,'16',   -- PUEDEN SER PRODECIMIENTOS DIAGNOSTICOS '15'
								,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
						COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),upper(COALESCE(HADM.DXINGRESO,HADM.DXEGRESO)), 
							 upper(CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END), 
							 upper(CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END), 
						  --SUM(HPRED.VALOREXCEDENTE) 
						  SUM(HPRED.VALOR*HPRED.CANTIDAD) --EEMC 16-09-2025  SE MODIFICA POR QUE ESTA GENERANDO INCONSISTENCIAS EN LA SUMATORIA DE LA FACTURA CONTRA EL RIPS
						  ,NULL -- IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
						  ,SUM(COALESCE(HPRED.VALORCOPAGO,0)),@N_FACTURA,HADM.IDAFILIADO
					 FROM  HADM    INNER JOIN AFI     ON HADM.IDAFILIADO=AFI.IDAFILIADO
									INNER JOIN HPRE    ON HADM.NOADMISION=HPRE.NOADMISION 
									INNER JOIN HPRED   ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
									INNER JOIN SER     ON HPRED.IDCIRUGIA=SER.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN SER  SER1   ON HPRED.IDSERVICIO=SER1.IDSERVICIO --AND FTRDC.IDSERVICIO = SER.IDSERVICIO
									INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
									INNER JOIN RIPS_CP CP ON SER1.CODIGORIPS=CP.IDCONCEPTORIPS
									LEFT JOIN TGEN    ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'  --STORRES 20251222 - SE CAMBIA INNER POR LEFT PARA QUE TRAIGA INFORMACION COMPLETA
									LEFT JOIN MED      ON MED.IDMEDICO = CASE WHEN COALESCE(HPRE.IDMEDICO,'') = '' OR  COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN @EPI_MEDICODEFAULT 
															ELSE CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA)='' THEN HPRE.IDMEDICO  END END
								 
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
							INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
							LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  
							LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
					 WHERE HADM.NOADMISION=@NOADMISION
					 AND HPRED.N_FACTURA = @N_FACTURA
					 AND COALESCE(HPRED.VALOR,0) > 0
					 AND COALESCE(HPRED.NOCOBRABLE,0) = 0
					 AND COALESCE(SER.CIRUGIA,0) = 1
					 AND COALESCE(HPRED.IDCIRUGIA,'') <> ''
					 AND COALESCE(HPRED.TIPOSERCIRUGIA,'')='PAQUETE'
					 GROUP BY HADM.IDAFILIADO,HADM.NOADMISION,HPRED.NOAUTORIZACION,HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
							left(REPLACE(REPLACE(LTRIM(RTRIM(SER.CODCUPS)),CHAR(13),''),CHAR(10),''),6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),
							CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END,CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END,
							COALESCE(MED.TIPO_ID,@TIPODC_DEF),COALESCE(MED.IDMEDICO,@EPI_MEDICODEFAULT),COALESCE(HADM.DXINGRESO,HADM.DXEGRESO),
							CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(HADM.DXINGRESO,HADM.DXEGRESO) ELSE HADM.DXSALIDA1 END,
							CASE WHEN COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'')='' THEN 'null' ELSE COALESCE(HADM.COMPLICACION,HADM.DXINGRESO,HADM.DXEGRESO,'') END,
							IIF(COALESCE(HPRED.VALORCOPAGO,0)>0,'02','05')
									,LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2)  -- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
								     ,HPRED.NOITEM
							ORDER BY HADM.NOADMISION

				END
			 END
			END
			IF 1=1
			BEGIN --AT
			 PRINT 'SALUD AT'
			 --DECLARE @TIPOIMP SMALLINT
			 SELECT @TIPOIMP=IMPRIMEIDALTERNA FROM PPT WHERE IDPLAN=@IDPLAN AND IDTERCERO=@IDTERCERO
				INSERT INTO #OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
									,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
									,valorPagoModerador,numFEVPagoModerador,IDAFILIADO)
				SELECT @IDPRESTADOR ,numAutorizacion=DBO.FNK_LIMPIATEXTO(ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(HPRED.NOAUTORIZACION)), ''), NULLIF(LTRIM(RTRIM(HADM.NOAUTORIZACION)), ''),NULLIF(LTRIM(RTRIM(HADMAUT.AUTORIZACION)), '')),'null' ), 'A-Z0-9-')
            ,'null' 
				, CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' AND HPRE.FECHA NOT BETWEEN @FINIATEN AND @FFINATEN   THEN @fechaInicioAtencion
					   ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
				  end
					, tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END --20250702 -- STORRES -- A A ESPERA QUE SE CREE EL CAMPO PARA CONFIGURAR
				, LEFT(IIF(RIPS_CP.IDCONCEPTORIPS=@IDMATERIALESRIPS AND @TIPOIMP NOT IN(9) ,IIF(@FORMATOCODIGO=13,COALESCE(SER.CODSISPRO,SER.IDSERVICIO),SER.IDSERVICIO), SER.CODCUPS),20),LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
					, CONVERT(INT,COALESCE(HPRED.CANTIDAD,1)),COALESCE(NULLIF(LEFT(MED.TIPO_ID,2),''),@TIPODC_DEF),COALESCE(NULLIF(MED.IDMEDICO,''),@EPI_MEDICODEFAULT)
				, CASE WHEN COALESCE(@PAQUETE,0) IN (1,2) THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(FTRD.VALOR,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
				, CASE WHEN COALESCE(@PAQUETE,0) IN (1,2) THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(FTRD.VALOR*FTRD.CANTIDAD,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
					,'04',CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALORCOPAGO,0)) ,COALESCE(@NFACTURA,@N_FACTURA),HADM.IDAFILIADO                                                                      
				FROM HADM 
					INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
					INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
               INNER JOIN FTRD ON HADM.NOADMISION = FTRD.NOADMISION AND HPRE.NOPRESTACION = FTRD.NOPRESTACION AND HPRED.IDSERVICIO = FTRD.REFERENCIA AND FTRD.NOITEM=HPRED.NOITEM
					INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
					INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
					LEFT JOIN MED ON MED.IDMEDICO = COALESCE(NULLIF(HADM.IDMEDICOTRA,''), NULLIF(HADM.IDMEDICOING,''), NULLIF(HADM.IDMEDICOALTA,''), NULLIF(HPRE.IDMEDICO,''), NULLIF(@EPI_MEDICODEFAULT,''))
					LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
				WHERE HADM.NOADMISION=@NOADMISION
					AND HPRED.N_FACTURA=@N_FACTURA
					AND COALESCE(HPRED.VALOR,0)>0
					AND COALESCE(HPRED.NOCOBRABLE,0)=0		
					AND COALESCE(HPRED.CANTIDAD,0)>0
					AND COALESCE(HPRED.IDCIRUGIA,'') =''
					AND RIPS_CP.ARCHIVO='AT'  
                    AND FTRD.N_FACTURA = @N_FACTURA
                    AND COALESCE(FTRD.PAQUETE,0) <> 2 -- 2026
			END
		END
		-- Si tipoOS='05' y cantidadOS>1, se reporta de uno en uno (vrServicio y copago se prorratean; el residuo queda en la Ãºltima unidad)
		IF EXISTS (SELECT 1 FROM #OTROSSER WHERE tipoOS = '05' AND COALESCE(cantidadOS, 0) > 1)
		BEGIN
			PRINT 'Desglosar otros servicios tipoOS=05 con cantidadOS>1'
			IF OBJECT_ID('tempdb..#OTROSSER05') IS NOT NULL DROP TABLE #OTROSSER05
			SELECT
				CAST(consecutivo AS INT) AS CONSECUTIVO,
				codPrestador,
				numAutorizacion,
				idMIPRES,
				fechaSuministroTecnologia,
				tipoOS,
				codTecnologiaSalud,
				nomTecnologiaSalud,
				cantidadOS,
				tipoDocumentoIdentificacion,
				numDocumentoIdentificacion,
				vrUnitOS,
				vrServicio,
				tipoPagoModerador,
				valorPagoModerador,
				numFEVPagoModerador,
				IDAFILIADO
			INTO #OTROSSER05
			FROM #OTROSSER

			TRUNCATE TABLE #OTROSSER

			DECLARE JSOTROS05_CURSOR CURSOR LOCAL FAST_FORWARD FOR
			SELECT CONSECUTIVO, cantidadOS
			FROM #OTROSSER05
			ORDER BY CONSECUTIVO

			OPEN JSOTROS05_CURSOR
			FETCH NEXT FROM JSOTROS05_CURSOR INTO @CNSCONSULTA, @CANTORI
			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF EXISTS (SELECT 1 FROM #OTROSSER05 WHERE CONSECUTIVO = @CNSCONSULTA AND tipoOS = '05' AND COALESCE(cantidadOS, 0) > 1)
				BEGIN
					SET @BANDERA = 1
					WHILE @BANDERA <= @CANTORI
					BEGIN
						INSERT INTO #OTROSSER (
							codPrestador, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS,
							codTecnologiaSalud, nomTecnologiaSalud, cantidadOS, tipoDocumentoIdentificacion,
							numDocumentoIdentificacion, vrUnitOS, vrServicio, tipoPagoModerador,
							valorPagoModerador, numFEVPagoModerador, IDAFILIADO
						)
						SELECT
							codPrestador, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS,
							codTecnologiaSalud, nomTecnologiaSalud, 1, tipoDocumentoIdentificacion,
							numDocumentoIdentificacion, vrUnitOS,
							CASE WHEN @BANDERA = @CANTORI
								THEN vrServicio - (CONVERT(DECIMAL(14,2), vrServicio / @CANTORI) * (@CANTORI - 1))
								ELSE CONVERT(DECIMAL(14,2), vrServicio / @CANTORI)
							END,
							tipoPagoModerador,
							CASE WHEN @BANDERA = @CANTORI
								THEN valorPagoModerador - (CONVERT(DECIMAL(14,2), valorPagoModerador / @CANTORI) * (@CANTORI - 1))
								ELSE CONVERT(DECIMAL(14,2), valorPagoModerador / @CANTORI)
							END,
							numFEVPagoModerador, IDAFILIADO
						FROM #OTROSSER05
						WHERE CONSECUTIVO = @CNSCONSULTA
						SET @BANDERA = @BANDERA + 1
					END
				END
				ELSE
				BEGIN
					INSERT INTO #OTROSSER (
						codPrestador, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS,
						codTecnologiaSalud, nomTecnologiaSalud, cantidadOS, tipoDocumentoIdentificacion,
						numDocumentoIdentificacion, vrUnitOS, vrServicio, tipoPagoModerador,
						valorPagoModerador, numFEVPagoModerador, IDAFILIADO
					)
					SELECT
						codPrestador, numAutorizacion, idMIPRES, fechaSuministroTecnologia, tipoOS,
						codTecnologiaSalud, nomTecnologiaSalud, cantidadOS, tipoDocumentoIdentificacion,
						numDocumentoIdentificacion, vrUnitOS, vrServicio, tipoPagoModerador,
						valorPagoModerador, numFEVPagoModerador, IDAFILIADO
					FROM #OTROSSER05
					WHERE CONSECUTIVO = @CNSCONSULTA
				END
				FETCH NEXT FROM JSOTROS05_CURSOR INTO @CNSCONSULTA, @CANTORI
			END
			CLOSE JSOTROS05_CURSOR
			DEALLOCATE JSOTROS05_CURSOR
			DROP TABLE #OTROSSER05
		END
	END
	ELSE
	BEGIN
		RAISERROR ('No se encontrÃ³ la procedencia de la factura', 16, 1); 
		RETURN
	END

   DECLARE @VALORCOPAGOACU DECIMAL(14,4)
   DECLARE @VALORCOPAGOS DECIMAL(14,4)
   DECLARE @CONSE INT
   DECLARE @DIF DECIMAL(14,4)
   SELECT @VALORCOPAGOS = VALORCOPAGO 
   FROM FTR 
   WHERE N_fACTURA = @N_FACTURA
   IF @VALORCOPAGOS<> @VLRCOPAGODIAN
   BEGIN
      SET @VALORCOPAGOS=@VLRCOPAGODIAN
   END
   SELECT @VALORCOPAGOACU = SUM(CAST(COALESCE(valorPagoModerador, '0') AS DECIMAL(14,4)))  FROM #CONSULTAS
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(valorPagoModerador, '0') AS DECIMAL(14,4))), 0) FROM #PROCEDIMIENTOS
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(valorPagoModerador, '0') AS DECIMAL(14,4))), 0) FROM #MEDICAMENTOS
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(valorPagoModerador, '0') AS DECIMAL(14,4))), 0) FROM #OTROSSER
   SELECT @DIF = (@VALORCOPAGOS - @VALORCOPAGOACU)
   PRINT '@VALORCOPAGOACU=' + CONVERT(VARCHAR(20), @VALORCOPAGOACU, 2)
   PRINT '@VALORCOPAGOS='  + CONVERT(VARCHAR(20), @VALORCOPAGOS, 2)
   PRINT '@DIFERENCIA='    + CONVERT(VARCHAR(20), @DIF, 2)
   IF COALESCE(@DIF, 0) <> 0
   BEGIN
       PRINT 'en 1298'
       SELECT TOP 1 @CONSE = CONSECUTIVO  FROM #CONSULTAS 
       WHERE CAST(valorPagoModerador AS DECIMAL(14,2)) > 0
       ORDER BY CONSECUTIVO  -- asegura orden predecible
       IF COALESCE(@CONSE, 0) > 0
       BEGIN
           PRINT 'en 1302'
           UPDATE #CONSULTAS SET valorPagoModerador =    CONVERT(VARCHAR(20),
        CASE 
            WHEN @DIF < 0 THEN
                ROUND(
                    CAST(valorPagoModerador AS DECIMAL(14,2)) - ABS(@DIF)
                ,2)
            ELSE
                ROUND(
                    CAST(valorPagoModerador AS DECIMAL(14,2)) + @DIF
                ,2)
        END
    )
WHERE CONSECUTIVO = @CONSE;
           UPDATE #CONSULTAS SET valorPagoModerador = '0.00' WHERE CONSECUTIVO = @CONSE  AND CAST(valorPagoModerador AS DECIMAL(14,2)) < 0;
       END
       ELSE
       BEGIN
           PRINT 'en 1308'
           SELECT TOP 1 @CONSE = CONSECUTIVO 
           FROM #PROCEDIMIENTOS
           
           WHERE CAST(valorPagoModerador AS DECIMAL(14,2)) > 0
           ORDER BY CONSECUTIVO
           IF COALESCE(@CONSE, 0) > 0
           BEGIN
               PRINT 'en 1312'
               PRINT 'DIF=' + CONVERT(VARCHAR(20), @DIF, 2)
               UPDATE #PROCEDIMIENTOS  SET valorPagoModerador = 
                    CASE 
                        WHEN @DIF < 0 THEN
                            ROUND(
                                CAST(valorPagoModerador AS DECIMAL(14,2)) - ABS(@DIF)
                            ,2)
                        ELSE
                            ROUND(
                                CAST(valorPagoModerador AS DECIMAL(14,2)) + @DIF
                            ,2)
                    END
                
            WHERE CONSECUTIVO = @CONSE;
               UPDATE #PROCEDIMIENTOS  SET valorPagoModerador = '0.00'  WHERE CONSECUTIVO = @CONSE 
               AND CAST(valorPagoModerador AS DECIMAL(14,2)) < 0;
           END
           ELSE
           BEGIN
               PRINT 'en 1320'
               SELECT TOP 1 @CONSE = CONSECUTIVO 
               FROM #MEDICAMENTOS 
               WHERE CAST(valorPagoModerador AS DECIMAL(14,2)) > 0
               ORDER BY CONSECUTIVO
               IF COALESCE(@CONSE, 0) > 0
               BEGIN
                   PRINT 'en 1324'
                   UPDATE #MEDICAMENTOS 
                   SET valorPagoModerador = CAST(
                                ROUND(
                                    CAST(valorPagoModerador AS DECIMAL(14,2)) + @DIF
                                ,2)
                             AS DECIMAL(14,2))
                     WHERE CONSECUTIVO = @CONSE;
                   UPDATE #MEDICAMENTOS 
                   SET valorPagoModerador = '0.00'
                   WHERE CONSECUTIVO = @CONSE
                     AND CAST(valorPagoModerador AS DECIMAL(14,2)) < 0;
               END   
               ELSE
               BEGIN
                   PRINT 'en 1329'
                   SELECT TOP 1 @CONSE = CONSECUTIVO 
                   FROM #OTROSSER 
                   WHERE CAST(valorPagoModerador AS DECIMAL(14,2)) > 0
                   ORDER BY CONSECUTIVO
                   IF COALESCE(@CONSE, 0) > 0
                   BEGIN
                       PRINT 'en 1334'
                       UPDATE #OTROSSER 
                       SET valorPagoModerador =  CAST(
                                ROUND(
                                    CAST(valorPagoModerador AS DECIMAL(14,2)) + @DIF
                                ,2)
                             AS DECIMAL(14,2))
                        WHERE CONSECUTIVO = @CONSE;
                       UPDATE #OTROSSER 
                       SET valorPagoModerador = '0.00'
                       WHERE CONSECUTIVO = @CONSE
                         AND CAST(valorPagoModerador AS DECIMAL(14,2)) < 0;
                   END  
               END
           END
       END
   END
   -- Reiniciar acumulados
   SELECT @VALORCOPAGOS = 0, @VALORCOPAGOACU = 0;
   -- Obtener valor esperado
   SELECT @VALORCOPAGOS = VALORSERVICIOS 
   FROM FTR 
   WHERE N_fACTURA = @N_FACTURA;
   -- Calcular acumulado (con manejo seguro de NULL y formato)
   SELECT @VALORCOPAGOACU = SUM(CAST(COALESCE(vrServicio, '0') AS DECIMAL(14,4))) FROM #CONSULTAS;
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(vrServicio, '0') AS DECIMAL(14,4))), 0) FROM #PROCEDIMIENTOS;
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(vrServicio, '0') AS DECIMAL(14,4))), 0) FROM #MEDICAMENTOS;
   SELECT @VALORCOPAGOACU = COALESCE(@VALORCOPAGOACU, 0) + COALESCE(SUM(CAST(COALESCE(vrServicio, '0') AS DECIMAL(14,4))), 0) FROM #OTROSSER;
   -- DiagnÃ³stico
   PRINT '@SERVICOS='          + CONVERT(VARCHAR(20), @VALORCOPAGOACU, 2);
   PRINT '@VALORSERVICIOS='    + CONVERT(VARCHAR(20), @VALORCOPAGOS, 2);
   PRINT '@DIFERENCIA_ABS='    + CONVERT(VARCHAR(20), ABS(@VALORCOPAGOS - @VALORCOPAGOACU), 2);
   -- Ajuste solo si diferencia ? 0 y < 100
   IF (@VALORCOPAGOS - @VALORCOPAGOACU) <> 0 
      AND ABS(@VALORCOPAGOS - @VALORCOPAGOACU) < 100
   BEGIN
       PRINT 'ABS(@VALORCOPAGOS-@VALORCOPAGOACU)<100';
       DECLARE @DIFE DECIMAL(14,4) = @VALORCOPAGOS - @VALORCOPAGOACU;
       PRINT 'DIFERENCIA=' + CONVERT(VARCHAR(20), @DIFE, 2);
       SET @CONSE = 0;
       -- Intentar en #CONSULTAS
       SELECT TOP 1 @CONSE = CONSECUTIVO 
       FROM #CONSULTAS 
       WHERE CAST(vrServicio AS DECIMAL(14,2)) > 0
       ORDER BY CONSECUTIVO;
       IF COALESCE(@CONSE, 0) > 0
       BEGIN
           PRINT 'INGRESO AL REDONDEO - #CONSULTAS';
            UPDATE #CONSULTAS
            SET vrServicio =
                CASE
                    WHEN @DIFE < 0 THEN
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),2) AS DECIMAL(14,2))
                    ELSE
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,2) AS DECIMAL(14,2))
                END
            WHERE CONSECUTIVO = @CONSE;
           UPDATE #CONSULTAS 
           SET vrServicio = '0.00'
           WHERE CONSECUTIVO = @CONSE
          AND CAST(vrServicio AS DECIMAL(14,2)) < 0;
       END
       ELSE
       BEGIN
           print '-- Intentar en #PROCEDIMIENTOS copagos'
           SELECT TOP 1 @CONSE = CONSECUTIVO 
           FROM #PROCEDIMIENTOS 
           WHERE CAST(vrServicio AS DECIMAL(14,2)) > 0
           ORDER BY CONSECUTIVO;
           IF COALESCE(@CONSE, 0) > 0
           BEGIN
               UPDATE #PROCEDIMIENTOS SET  vrServicio =                CASE
                    WHEN @DIFE < 0 THEN
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),2) AS DECIMAL(14,2))
                    ELSE
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,2) AS DECIMAL(14,2))
                END
            WHERE CONSECUTIVO = @CONSE;
               UPDATE #PROCEDIMIENTOS SET vrServicio = '0.00' WHERE CONSECUTIVO = @CONSE AND CAST(vrServicio AS DECIMAL(14,2)) < 0;
           END
           ELSE
           BEGIN
               -- Intentar en #MEDICAMENTOS
               SELECT TOP 1 @CONSE = CONSECUTIVO 
               FROM #MEDICAMENTOS 
               WHERE CAST(vrServicio AS DECIMAL(14,2)) > 0
               ORDER BY CONSECUTIVO;
               IF COALESCE(@CONSE, 0) > 0
               BEGIN
                   UPDATE #MEDICAMENTOS  SET vrServicio =                  CASE
                    WHEN @DIFE < 0 THEN
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),2) AS DECIMAL(14,2))
                    ELSE
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,2) AS DECIMAL(14,2))
                END
            WHERE CONSECUTIVO = @CONSE;
                   UPDATE #MEDICAMENTOS  SET vrServicio = '0.00'  WHERE CONSECUTIVO = @CONSE AND CAST(vrServicio AS DECIMAL(14,2)) < 0;
               END   
               ELSE
               BEGIN
                   -- Intentar en #OTROSSER
                   SELECT TOP 1 @CONSE = CONSECUTIVO 
                   FROM #OTROSSER 
                   WHERE CAST(vrServicio AS DECIMAL(14,2)) > 0
                   ORDER BY CONSECUTIVO;
                   IF COALESCE(@CONSE, 0) > 0
                   BEGIN
                       UPDATE #OTROSSER SET vrServicio =                 CASE
                    WHEN @DIFE < 0 THEN
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),2) AS DECIMAL(14,2))
                    ELSE
                        CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,2) AS DECIMAL(14,2))
                END
            WHERE CONSECUTIVO = @CONSE;
                       UPDATE #OTROSSER SET vrServicio = '0.00'  WHERE CONSECUTIVO = @CONSE   AND CAST(vrServicio AS DECIMAL(14,2)) < 0;
                   END  
               END
           END
       END
   END
	PRINT 'ActualizaciÃ³n de LAS TABLAS con los diagnÃ³sticos principales y relacionados en un solo bloque'
	BEGIN
		PRINT 'Diagnosticos Consultas'
		UPDATE AC
		SET 
			AC.codDiagnosticoPrincipal = CASE WHEN COALESCE(AC.codDiagnosticoPrincipal, '') = '' THEN IIF(COALESCE(DX.IDDX,'')='','Z000',DX.IDDX) ELSE AC.codDiagnosticoPrincipal END,
			AC.tipoDiagnosticoPrincipal = IIF(COALESCE(DX.TIPODX,'')='','01',DX.TIPODX),
			AC.codDiagnosticoRelacionado1 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado1, '') = '' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',COALESCE(DX.DX1,'null')) ELSE AC.codDiagnosticoRelacionado1 END,
			AC.codDiagnosticoRelacionado2 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado2, '') = '' THEN IIF(COALESCE(DX.DX2,'')='' OR DX.DX2=COALESCE(DX.IDDX,''),'null',COALESCE(DX.DX2,'null')) ELSE AC.codDiagnosticoRelacionado2 END,
			AC.codDiagnosticoRelacionado3 = CASE WHEN COALESCE(AC.codDiagnosticoRelacionado3, '') = '' THEN IIF(COALESCE(DX.DX3,'')='' OR DX.DX3=COALESCE(DX.IDDX,''),'null',COALESCE(DX.DX3,'null')) ELSE AC.codDiagnosticoRelacionado3 END
		FROM #CONSULTAS AC
		LEFT JOIN #DX DX ON AC.IDAFILIADO = DX.IDAFILIADO
		WHERE COALESCE(AC.codDiagnosticoPrincipal, '') = '' 
			OR COALESCE(AC.tipoDiagnosticoPrincipal, '') =''
			OR COALESCE(AC.codDiagnosticoRelacionado2, '') = ''
			OR COALESCE(AC.codDiagnosticoRelacionado3, '') = '';
      UPDATE #CONSULTAS SET tipoDiagnosticoPrincipal='01' WHERE LEN(COALESCE(tipoDiagnosticoPrincipal,''))<2
      UPDATE #CONSULTAS SET codDiagnosticoRelacionado1='null' WHERE LEN(COALESCE(codDiagnosticoRelacionado1,''))<2
		PRINT 'Diagnosticos medicamentos'
		UPDATE AM
		SET 
			AM.codDiagnosticoPrincipal = CASE WHEN COALESCE(AM.codDiagnosticoPrincipal, '') = '' THEN COALESCE(DX.IDDX,'Z000') ELSE AM.codDiagnosticoPrincipal END,
			AM.codDiagnosticoRelacionado = CASE WHEN COALESCE(AM.codDiagnosticoRelacionado, '') = '' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AM.codDiagnosticoRelacionado END
		FROM #MEDICAMENTOS AM
		INNER JOIN #DX DX ON AM.IDAFILIADO = DX.IDAFILIADO
		WHERE COALESCE(AM.codDiagnosticoPrincipal,'')='' 
      OR COALESCE(AM.codDiagnosticoRelacionado,'')=''
      UPDATE #MEDICAMENTOS SET codDiagnosticoPrincipal=UPPER(codDiagnosticoPrincipal),codDiagnosticoRelacionado=UPPER(IIF(LEN(codDiagnosticoRelacionado)<4,'null',codDiagnosticoRelacionado))
		PRINT 'Diagnosticos procedimientos'
		UPDATE AP
		SET 
			AP.codDiagnosticoPrincipal = CASE WHEN COALESCE(AP.codDiagnosticoPrincipal, '') = '' OR AP.codDiagnosticoPrincipal IS NULL OR AP.codDiagnosticoPrincipal ='null' THEN IIF(COALESCE(DX.IDDX,'')='','Z000',DX.IDDX) ELSE AP.codDiagnosticoPrincipal END,
			AP.codDiagnosticoRelacionado = CASE WHEN COALESCE(AP.codDiagnosticoRelacionado, '') = '' OR AP.codDiagnosticoRelacionado ='null' THEN IIF(COALESCE(DX.DX1,'')='' OR DX.DX1=COALESCE(DX.IDDX,''),'null',DX.DX1) ELSE AP.codDiagnosticoRelacionado END,
			AP.codComplicacion = CASE WHEN COALESCE(AP.codComplicacion, '') = '' OR AP.codComplicacion ='null' THEN IIF(COALESCE(DX.DX2,'')='',DX.IDDX,DX.DX2) ELSE AP.codComplicacion END
		FROM #PROCEDIMIENTOS AP
		INNER JOIN #DX DX ON AP.IDAFILIADO = DX.IDAFILIADO
      UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal='Z000' WHERE (codDiagnosticoPrincipal IS NULL OR LEN(COALESCE(codDiagnosticoPrincipal,''))<4)
      UPDATE #PROCEDIMIENTOS SET codDiagnosticoPrincipal=UPPER(codDiagnosticoPrincipal),codDiagnosticoRelacionado=UPPER(IIF(LEN(codDiagnosticoRelacionado)<4,'null',codDiagnosticoRelacionado))
		-- ValidaciÃ³n RIPS: el dx relacionado no puede ser igual al dx principal
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
		-- ValidaciÃ³n RIPS: dx relacionados de consulta no pueden repetirse entre sÃ­
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
	END
   PRINT '@ESMODERADORAENFTR >'  + COALESCE(@ESMODERADORAENFTR,' SIN @ESMODERADORAENFTR')
   PRINT '@CONCEPTORECAUDOICI='+@CONCEPTORECAUDOICI
   PRINT '@TIPOUSU='+@TIPOUSU
   PRINT '@conceptoRecaudo='+@conceptoRecaudo
	PRINT 'SALGO DE LOS AJUSTES'
    --SELECT 'AC', SUM(vrServicio) FROM #CONSULTAS       union all
    --SELECT 'AP', SUM(vrServicio) FROM #PROCEDIMIENTOS  union all 
    --SELECT 'AM', SUM(CAST(vrServicio AS DECIMAL(14,2))) FROM #MEDICAMENTOS    union all
    --SELECT 'AT', SUM(vrServicio) FROM #OTROSSER   
    --SELECT 'AC', SUM(valorPagoModerador) FROM #CONSULTAS       union all
    --SELECT 'AP', SUM(valorPagoModerador) FROM #PROCEDIMIENTOS  union all 
    --SELECT 'AM', SUM(CAST(valorPagoModerador AS DECIMAL(14,2))) FROM #MEDICAMENTOS    union all
    --SELECT 'AT', SUM(valorPagoModerador) FROM #OTROSSER 
    --RETURN
    set @primerGrupo=0
   IF EXISTS(SELECT * FROM #CONSULTAS)
	BEGIN
     PRINT 'CONSULTAS'
     DECLARE @CONSULTAS_JSON NVARCHAR(MAX);
   -- Generamos la parte de consultas como JSON
   SELECT @CONSULTAS_JSON = (
       SELECT 
           codPrestador,
           fechaInicioAtencion,
           numAutorizacion = NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(numAutorizacion,CHAR(10),''),CHAR(13),''),CHAR(9),''))),''),
           codConsulta,
           modalidadGrupoServicioTecSal,
           grupoServicios,
           codServicio,
           finalidadTecnologiaSalud,
           causaMotivoAtencion,
           codDiagnosticoPrincipal  = IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4 ,'null', codDiagnosticoPrincipal),
           codDiagnosticoRelacionado1 = IIF(LEN(COALESCE(codDiagnosticoRelacionado1,''))<>4 OR UPPER(codDiagnosticoRelacionado1)=UPPER(codDiagnosticoPrincipal),'null', codDiagnosticoRelacionado1),
           codDiagnosticoRelacionado2 = IIF(LEN(COALESCE(codDiagnosticoRelacionado2,''))<>4 OR UPPER(codDiagnosticoRelacionado2)=UPPER(codDiagnosticoPrincipal) OR UPPER(codDiagnosticoRelacionado2)=UPPER(codDiagnosticoRelacionado1),'null', codDiagnosticoRelacionado2),
           codDiagnosticoRelacionado3 = IIF(LEN(COALESCE(codDiagnosticoRelacionado3,''))<>4 OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoPrincipal) OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoRelacionado1) OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoRelacionado2),'null', codDiagnosticoRelacionado3),
           codDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(20)),
           nomCodDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(255)),
           codDiagnosticoRelacionado1CIE11 = CAST(NULL AS VARCHAR(20)),
           nomCodDiagnosticoRelacionado1CIE11 = CAST(NULL AS VARCHAR(255)),
           codDiagnosticoRelacionado2CIE11 = CAST(NULL AS VARCHAR(20)),
           nomCodDiagnosticoRelacionado2CIE11 = CAST(NULL AS VARCHAR(255)),
           codDiagnosticoRelacionado3CIE11 = CAST(NULL AS VARCHAR(20)),
           nomCodDiagnosticoRelacionado3CIE11 = CAST(NULL AS VARCHAR(255)),
           codigoVIDA = CAST(NULL AS VARCHAR(20)),
           tipoDiagnosticoPrincipal = IIF(LEN(tipoDiagnosticoPrincipal)<2,'01',COALESCE(tipoDiagnosticoPrincipal,'01')),
           tipoDocumentoIdentificacion,
           numDocumentoIdentificacion,
           vrServicio,
           conceptoRecaudo =
               CASE 
                   WHEN TRY_CAST(valorPagoModerador AS decimal(14,2))<=0 THEN '05' 
                   WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
                   WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN IIF(@TIPOUSU IN('03','11'),'03',@conceptoRecaudo)  
                   ELSE @conceptoRecaudo 
               END,
           valorPagoModerador,
           numFEVPagoModerador = CASE 
                                    WHEN COALESCE(numFEVPagoModerador,'')<>'' 
                                         AND COALESCE(numFEVPagoModerador,'')<>@N_FACTURA 
                                    THEN numFEVPagoModerador 
                                    ELSE 'null' 
                                 END,
           consecutivo
       FROM #CONSULTAS
       ORDER BY consecutivo
       FOR JSON PATH,INCLUDE_NULL_VALUES
   );
-- AquÃ­ quitamos las llaves externas y le damos el nombre "consultas"
    SET @PLANO += '"consultas": ' + COALESCE(@CONSULTAS_JSON, '[]');
    SET @primerGrupo=1
	END	
   IF EXISTS(SELECT * FROM #MEDICAMENTOS)
	BEGIN
      PRINT 'MEDICAMENTOS'
     DECLARE @MEDICAMENTOS_JSON NVARCHAR(MAX);
      SELECT @MEDICAMENTOS_JSON = (
          SELECT 
              codPrestador,
              idMIPRES          = IIF(COALESCE(idMIPRES,'')='', 'null', idMIPRES),
              fechaDispensAdmon,
              codDiagnosticoPrincipal  = IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4, 'null', codDiagnosticoPrincipal),
              codDiagnosticoRelacionado= IIF(LEN(COALESCE(codDiagnosticoRelacionado,''))<>4 OR UPPER(codDiagnosticoRelacionado)=UPPER(codDiagnosticoPrincipal),'null', codDiagnosticoRelacionado),
              codDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(20)),
              nomCodDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(255)),
              codDiagnosticoRelacionadoCIE11 = CAST(NULL AS VARCHAR(20)),
              nomCodDiagnosticoRelacionadoCIE11 = CAST(NULL AS VARCHAR(255)),
              vrDispensacion = CAST(0 AS DECIMAL(14,2)),
              codigoVIDA = CAST(NULL AS VARCHAR(20)),
              tipoMedicamento,
              codTecnologiaSalud = DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9A-Z_-'),
              nomTecnologiaSalud,
              concentracionMedicamento,
              unidadMedida,
              formaFarmaceutica,
              unidadMinDispensa,
              cantidadMedicamento,
              diasTratamiento,
              tipoDocumentoIdentificacion,
              numDocumentoIdentificacion,
              vrUnitMedicamento,
              vrServicio,
              conceptoRecaudo = CASE 
                                  WHEN TRY_CAST(valorPagoModerador AS DECIMAL(14,2)) <= 0 THEN '05' 
								   WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR 
								   WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN IIF(@TIPOUSU IN('03','11'),'03',@conceptoRecaudo)  
                                  ELSE @conceptoRecaudo  
                                END,
              valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14,2)),
              numFEVPagoModerador = CASE 
                                      WHEN COALESCE(numFEVPagoModerador,'') <> '' 
                                        AND COALESCE(numFEVPagoModerador,'') <> @N_FACTURA 
                                      THEN numFEVPagoModerador 
                                      ELSE 'null' 
                                    END,
              consecutivo
          FROM #MEDICAMENTOS
          ORDER BY consecutivo
          FOR JSON PATH, INCLUDE_NULL_VALUES
      );
      -- Concatenamos la secciÃ³n medicamentos
      IF @primerGrupo=1
          SET @PLANO +=','
      ELSE
         SET @primerGrupo=1
      SET @PLANO += '"medicamentos": ' + COALESCE(@MEDICAMENTOS_JSON, '[]');
	END
   IF EXISTS(SELECT * FROM #PROCEDIMIENTOS)
	BEGIN
	   PRINT 'PROCEDIMIENTOS'
      DECLARE @PROCEDIMIENTOS_JSON NVARCHAR(MAX);
      SELECT @PROCEDIMIENTOS_JSON = (
            SELECT 
               codPrestador,
               fechaInicioAtencion,
               idMIPRES = IIF(COALESCE(idMIPRES,'')='', 'null', idMIPRES),
               numAutorizacion = NULLIF(
                  REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(numAutorizacion)),CHAR(10),''),CHAR(13),''),CHAR(9),''),
                  ''
               ),
               codProcedimiento,
               viaIngresoServicioSalud   = vialngresoServicioSalud,
               modalidadGrupoServicioTecSal,
               grupoServicios,
               codServicio,
               finalidadTecnologiaSalud,
               tipoDocumentoIdentificacion,
               numDocumentoIdentificacion,
               codDiagnosticoPrincipal = NULLIF(codDiagnosticoPrincipal,''),
               codDiagnosticoRelacionado = CASE WHEN LEN(COALESCE(codDiagnosticoRelacionado,''))<>4 OR UPPER(codDiagnosticoRelacionado)=UPPER(codDiagnosticoPrincipal) THEN NULL ELSE NULLIF(codDiagnosticoRelacionado,'') END,
               codComplicacion = NULLIF(codComplicacion,''),
               codDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(20)),
               nomCodDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(255)),
               codDiagnosticoRelacionadoCIE11 = CAST(NULL AS VARCHAR(20)),
               nomCodDiagnosticoRelacionadoCIE11 = CAST(NULL AS VARCHAR(255)),
               codComplicacionCIE11 = CAST(NULL AS VARCHAR(20)),
               nomCodComplicacionCIE11 = CAST(NULL AS VARCHAR(255)),
               codigoVIDA = CAST(NULL AS VARCHAR(20)),
               vrServicio = vrServicio,
               conceptoRecaudo = CASE 
                                    WHEN valorPagoModerador <= 0 THEN '05'
                                    WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
									WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN IIF(@TIPOUSU IN('03','11'),'03',@conceptoRecaudo)  
                                    ELSE @conceptoRecaudo
                                 END,
               valorPagoModerador = valorPagoModerador ,
               numFEVPagoModerador = CASE 
                                       WHEN COALESCE(numFEVPagoModerador,'') <> '' 
                                          AND COALESCE(numFEVPagoModerador,'') <> @N_FACTURA 
                                       THEN numFEVPagoModerador 
                                       ELSE 'null' 
                                    END,
               consecutivo
            FROM #PROCEDIMIENTOS
            ORDER BY consecutivo
            FOR JSON PATH, INCLUDE_NULL_VALUES
      );
      -- Concatenamos la secciÃ³n al JSON principal
      IF @primerGrupo=1
          SET @PLANO +=','
      ELSE
         SET @primerGrupo=1
      SET @PLANO += '"procedimientos": ' + COALESCE(@PROCEDIMIENTOS_JSON, '[]');
	END
   IF EXISTS(SELECT * FROM #OTROSSER)
	BEGIN
      PRINT  'OTROS SERVICIOS'
      DECLARE @OTROSSER_JSON NVARCHAR(MAX);
      SELECT @OTROSSER_JSON = (
             SELECT 
                 codPrestador,
                 numAutorizacion = NULLIF(
                     REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(numAutorizacion)),CHAR(10),''),CHAR(13),''),CHAR(9),''),
                     ''
                 ),
                 idMIPRES       = IIF(COALESCE(idMIPRES,'')='', 'null', idMIPRES),
                 fechaSuministroTecnologia,
                 tipoOS,
                 codTecnologiaSalud = DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9- _ A-Z--'),
                 nomTecnologiaSalud,
                 cantidadOS,
                 tipoDocumentoIdentificacion,
                 numDocumentoIdentificacion,
                 vrUnitOS,
                 vrServicio,
                 vrDispensacion = CAST(0 AS DECIMAL(14,2)),
                 codigoVIDA = CAST(NULL AS VARCHAR(20)),
                 conceptoRecaudo = CASE 
                                     WHEN TRY_CAST(valorPagoModerador AS DECIMAL(14,2)) <= 0 THEN '05'
									 WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
									 WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN IIF(@TIPOUSU IN('03','11'),'03',@conceptoRecaudo)  
                                     ELSE @conceptoRecaudo 
                                   END,
                 valorPagoModerador = TRY_CAST(valorPagoModerador AS DECIMAL(14,2)),
                 numFEVPagoModerador = CASE 
                                         WHEN COALESCE(numFEVPagoModerador,'') <> '' 
                                           AND COALESCE(numFEVPagoModerador,'') <> @N_FACTURA 
                                         THEN numFEVPagoModerador 
                                         ELSE 'null' 
                                       END,
                 consecutivo
             FROM #OTROSSER
             ORDER BY consecutivo
             FOR JSON PATH,INCLUDE_NULL_VALUES
         );
         -- Concatenar a tu JSON maestro
         IF @primerGrupo=1
             SET @PLANO +=','
         ELSE
            SET @primerGrupo=1
         SET @PLANO += '"otrosServicios": ' + COALESCE(@OTROSSER_JSON, '[]');
	END
	IF @PROCEDENCIA='SALUD'
	BEGIN
		BEGIN --AU
     -- SELECT * FROM #DX
      UPDATE HADM SET DXINGRESO=CASE WHEN LEN(COALESCE(HADM.DXINGRESO,''))<4 THEN DX.IDDX ELSE HADM.DXINGRESO END,
      DXEGRESO=CASE WHEN LEN(COALESCE(HADM.DXEGRESO,''))<4 THEN DX.IDDX ELSE HADM.DXEGRESO END,
      COMPLICACION=CASE WHEN LEN(COALESCE(HADM.COMPLICACION,''))<4 THEN DX.IDDX ELSE HADM.COMPLICACION END,
      DXSALIDA1=CASE WHEN LEN(COALESCE(HADM.DXSALIDA1,''))<4 THEN COALESCE(DX.DX1,DX.IDDX) ELSE HADM.DXSALIDA1 END,
      DXSALIDA2=CASE WHEN LEN(COALESCE(HADM.DXSALIDA2,''))<4 THEN COALESCE(DX.DX2,DX.IDDX) ELSE HADM.DXSALIDA2 END,
      DXSALIDA3=CASE WHEN LEN(COALESCE(HADM.DXSALIDA3,''))<4 THEN COALESCE(DX.DX3,DX.IDDX) ELSE HADM.DXSALIDA3 END,
      CAUSABMUERTE=CASE WHEN ESTADOPSALIDA=2 AND COALESCE(CAUSABMUERTE,'')='' THEN DXEGRESO ELSE CAUSABMUERTE END
      FROM HADM INNER JOIN #DX DX ON HADM.NOADMISION=DX.NOADMISION AND HADM.IDAFILIADO=DX.IDAFILIADO
      WHERE  HADM.NOADMISION=@NOADMISION
         print '@fechaInicioAtencion=' +@fechaInicioAtencion 
         print '@fechaEgreso='+@fechaEgreso
			IF EXISTS(SELECT 1 FROM HADM WHERE NOADMISION=@NOADMISION AND DATEDIFF(HOUR,FECHA,FECHAALTAMED)<=24 
					    AND EXISTS (SELECT 1 FROM TGEN WHERE TGEN.CODIGO = HADM.TIPOESTANCIA AND TGEN.CAMPO =  'CLASEHOSP'   AND  TGEN.DATO1 = 'U' AND TABLA = 'General')
					   ) AND @PROCEDENCIA='SALUD' AND @MODO_ASISTENCIAL = 'Normal'  --STORRES 20250310
			BEGIN
            PRINT 'URGENCIAS'
            DECLARE @URGENCIAS_JSON NVARCHAR(MAX);
            SELECT @URGENCIAS_JSON = (
                SELECT  
                    codPrestador            = @IDPRESTADOR,
                    fechaInicioAtencion     = @fechaInicioAtencion,
                    causaMotivoAtencion     = CASE 
                                                 WHEN COALESCE(TGEN.CHECK1,0)=1 AND COALESCE(DATO1,'')<>'' 
                                                 THEN DATO1 
                                                 ELSE CODIGO 
                                               END,
                    codDiagnosticoPrincipal = UPPER(IIF(COALESCE(HADM.DXINGRESO,HCA.IDDX,'')='','Z000',COALESCE(HADM.DXINGRESO,HCA.IDDX))),
                    codDiagnosticoPrincipalE = UPPER(IIF(COALESCE(HADM.DXEGRESO,HCA.DX1,'')='','Z000',COALESCE(HADM.DXEGRESO,HCA.DX1))),
                    codDiagnosticoRelacionadoE1 = IIF(LEN(COALESCE(HCA.DX1,HADM.DXSALIDA1,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'Z000')),4), 'null', LEFT(TRIM(COALESCE(NULLIF(HCA.DX1,''),HADM.DXSALIDA1,'')),4)),
                    codDiagnosticoRelacionadoE2 = IIF(LEN(COALESCE(HCA.DX2,HADM.DXSALIDA2,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'Z000')),4) OR LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4)=LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4), 'null', LEFT(TRIM(COALESCE(NULLIF(HCA.DX2,''),HADM.DXSALIDA2,'')),4)),
                    codDiagnosticoRelacionadoE3 = IIF(LEN(COALESCE(HCA.DX3,HADM.DXSALIDA3,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'Z000')),4) OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4) OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4), 'null', LEFT(TRIM(COALESCE(NULLIF(HCA.DX3,''),HADM.DXSALIDA3,'')),4)),
                    codDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoPrincipalECIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoPrincipalECIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE1CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE1CIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE2CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE2CIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE3CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE3CIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoCausaMuerteCIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoCausaMuerteCIE11 = CAST(NULL AS VARCHAR(255)),
                    codigoVIDA = CAST(NULL AS VARCHAR(20)),
                    condicionDestinoUsuarioEgreso = CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END,
                    codDiagnosticoCausaMuerte     = CASE WHEN HADM.ESTADOPSALIDA=1 THEN'null' ELSE CAUSABMUERTE END,
                    fechaEgreso                   = @fechaEgreso,
                    consecutivo                   = 1
                FROM HADM 
                LEFT JOIN (
                    SELECT TOP 1 
                           HCA.NOADMISION,
                           HCA.TIPODX,
                           HCA.IDDX,
                           COALESCE(PX.DX1,HCA.DX1,'') DX1,
                           COALESCE(PX.DX2,HCA.DX2,'') DX2,
                           COALESCE(PX.DX3,HCA.DX3,'') DX3 
                    FROM HCA 
                    LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
                    WHERE NOADMISION=@NOADMISION 
                      AND COALESCE(HCA.IDDX,'')<>'' 
                      AND HCA.CLASE='HC' 
                      AND PROCEDENCIA='QX' 
                      AND COALESCE(ANULADA,0)=0 
                      AND CLASEPLANTILLA<>@HCPLANTILLAEPI
                    ORDER BY HCA.FECHA DESC
                ) HCA ON HADM.NOADMISION=HCA.NOADMISION
                LEFT JOIN TGEN 
                       ON HADM.CAUSAEXTERNA=TGEN.CODIGO 
                      AND TGEN.TABLA='General' 
                      AND TGEN.CAMPO='CAUSAEXTERNA'
                WHERE HADM.NOADMISION=@NOADMISION
                FOR JSON PATH,INCLUDE_NULL_VALUES
            );
            SET @PLANO += ',"urgencias": ' + COALESCE(@URGENCIAS_JSON,'[]');
			END
		END
		BEGIN --AH
			IF EXISTS(SELECT 1 FROM HADM WHERE NOADMISION=@NOADMISION AND DATEDIFF(HOUR,FECHA,FECHAALTAMED)>24) 
                 AND @PROCEDENCIA='SALUD' AND @MODO_ASISTENCIAL = 'Normal'  --STORRES 20250310
			BEGIN
            PRINT 'HOSPITALIZACION'
            DECLARE @HOSP_JSON NVARCHAR(MAX);
            SELECT @HOSP_JSON = (
                SELECT
                    codPrestador               = @IDPRESTADOR,
                    viaIngresoServicioSalud    = TRIM(COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01')),
                    fechaInicioAtencion        = @fechaInicioAtencion,
                    numAutorizacion            = NULLIF(DBO.FNK_LIMPIATEXTO(COALESCE(HADM.NOAUTORIZACION,HADMAUT.AUTORIZACION,''),'A-Z0-9-'),''),
                    causaMotivoAtencion        = COALESCE(REPLACE(TGEN2.DATO1,' ',''),HADM.CAUSAEXTERNA,'38'),
                    codDiagnosticoPrincipal    = UPPER(COALESCE(HADM.DXINGRESO,HCA.IDDX)),
                    codDiagnosticoPrincipalE   = UPPER(COALESCE(HADM.DXEGRESO,HCA.DX1)),
                    codDiagnosticoRelacionadoE1= IIF(LEN(COALESCE(HCA.DX1,HADM.DXSALIDA1,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'')),4),'null',LEFT(TRIM(COALESCE(NULLIF(HCA.DX1,''),HADM.DXSALIDA1,'')),4)),
                    codDiagnosticoRelacionadoE2= IIF(LEN(COALESCE(HCA.DX2,HADM.DXSALIDA2,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'')),4) OR LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4)=LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4),'null',LEFT(TRIM(COALESCE(NULLIF(HCA.DX2,''),HADM.DXSALIDA2,'')),4)),
                    codDiagnosticoRelacionadoE3= IIF(LEN(COALESCE(HCA.DX3,HADM.DXSALIDA3,''))<>4 OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HADM.DXEGRESO,HCA.DX1,'')),4) OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HCA.DX1,HADM.DXSALIDA1,'')),4) OR LEFT(TRIM(COALESCE(HCA.DX3,HADM.DXSALIDA3,'')),4)=LEFT(TRIM(COALESCE(HCA.DX2,HADM.DXSALIDA2,'')),4),'null',LEFT(TRIM(COALESCE(NULLIF(HCA.DX3,''),HADM.DXSALIDA3,'')),4)),
                    codComplicacion            = COALESCE(HADM.DXINGRESO,HCA.IDDX,HADM.DXEGRESO,''),
                    codDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoPrincipalCIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoPrincipalECIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoPrincipalECIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE1CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE1CIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE2CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE2CIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoRelacionadoE3CIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoRelacionadoE3CIE11 = CAST(NULL AS VARCHAR(255)),
                    codComplicacionCIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodComplicacionCIE11 = CAST(NULL AS VARCHAR(255)),
                    codDiagnosticoCausaMuerteCIE11 = CAST(NULL AS VARCHAR(20)),
                    nomCodDiagnosticoCausaMuerteCIE11 = CAST(NULL AS VARCHAR(255)),
                    codigoVIDA = CAST(NULL AS VARCHAR(20)),
                    condicionDestinoUsuarioEgreso = CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END,
                    codDiagnosticoCausaMuerte  = CASE WHEN HADM.ESTADOPSALIDA=1 THEN 'null' ELSE IIF(COALESCE(CAUSABMUERTE,'')='',UPPER(COALESCE(HCA.IDDX,HADM.DXINGRESO)),CAUSABMUERTE) END,
                    fechaEgreso                = @fechaEgreso,
                    consecutivo                = 1
                FROM HADM
				LEFT JOIN HADMAUT ON HADMAUT.N_FACTURA=@N_FACTURA
                LEFT JOIN TGEN 
                       ON HADM.VIAINGRESO = TGEN.CODIGO 
                      AND TGEN.TABLA='General' 
                      AND TGEN.CAMPO='VIADEINGRESO'
                LEFT JOIN TGEN TGEN2 
                       ON HADM.CAUSAEXTERNA = TGEN2.CODIGO 
                      AND TGEN2.TABLA='General' 
                      AND TGEN2.CAMPO='CAUSAEXTERNA'
                LEFT JOIN (
                    SELECT TOP 1 
                           HCA.NOADMISION,
                           HCA.TIPODX,
                           HCA.IDDX,
                           COALESCE(PX.DX1,HCA.DX1,'') DX1,
                           COALESCE(PX.DX2,HCA.DX2,'') DX2,
                           COALESCE(PX.DX3,HCA.DX3,'') DX3
                    FROM HCA 
                    LEFT JOIN VWK_HCADX_PIVOT PX ON PX.CONSECUTIVO=HCA.CONSECUTIVO
                    WHERE NOADMISION=@NOADMISION 
                      AND COALESCE(HCA.IDDX,'')<>'' 
                      AND HCA.CLASE='HC' 
                      AND PROCEDENCIA='QX' 
                      AND COALESCE(ANULADA,0)=0 
                      AND CLASEPLANTILLA<>@HCPLANTILLAEPI
                    ORDER BY HCA.FECHA DESC
                ) HCA ON HADM.NOADMISION=HCA.NOADMISION
                WHERE HADM.NOADMISION=@NOADMISION
                FOR JSON PATH,INCLUDE_NULL_VALUES
            );
            -- ConcatenaciÃ³n al JSON principal
            --IF @primerGrupo = 1 
            --    SET @primerGrupo = 0
            --ELSE 
            SET @PLANO += ',"hospitalizacion": ' + COALESCE(@HOSP_JSON,'[]');
			END
         --PRINT 'DESPUES DE AH '+COALESCE(@PLANO,'NADA DE NADA')
		END
		BEGIN --RECIEN NACIDO
			SELECT @RECIEN = DBO.FNK_RIPS_JSON_RECIENNACIDOS(@NOADMISION,@N_FACTURA,@PROCEDENCIA,@TIPODOC,@DOCIDAFILIADO,@IDTERINSTA)			
			IF LEN(@RECIEN)>0
			BEGIN
		PRINT '@RECIEN'
		PRINT @RECIEN
				--IF @primerGrupo = 1 SELECT @primerGrupo = 0
				--ELSE SET @PLANO += ','
				SET @PLANO += ',"recienNacidos":['
				SET @PLANO+=@RECIEN
				SET @PLANO  += ']'
			END
		END
	END
	SET @PLANO += '}' --SERVICIOS
	SET @PLANO += '}' --CADA USUARIO
	SET @PLANO += ']'--USUARIOS
	SET @PLANO += '}'--FIN
	SELECT @PLANO=REPLACE(@PLANO,'},]','}]')
	SELECT @PLANO=REPLACE(@PLANO,'"null"','null')
	SELECT @PLANO = '{"rips": '+COALESCE(@PLANO, '{}')+',"xmlFevFile": "@XMLFEVFILE"}'
	IF 1=1
	BEGIN
		select @base64 = cast('' as xml).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
		from (
			select [binaryValue] = cast(dbo.FNK_AttachedDocument(@CNSFCT,'FV') as varbinary(max))
		) as conv;
		/* REPLACE(..., NULL) anula TODO el JSON; si no hay XML se deja cadena vacÃ­a. */
		SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE', COALESCE(@base64, ''))
	END
	ELSE
	BEGIN
		SELECT @BASE64 = XML_Base64
		FROM FDIANR
		WHERE CNSDOCUMENTO = @CNSFCT
		AND TIPO='FV'
		AND METODO='SendBillSync'
		AND COALESCE(XML_BASE64, '') <> ''
		ORDER BY ITEM DESC
		SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE', COALESCE(@base64, ''))
	END
	IF COALESCE(@URL_PATH,'')<>''
	BEGIN
		SELECT @N_FACTURA=@N_FACTURA+'.json'
		EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
		SELECT @PLANO= @URL_PATH+IIF(RIGHT(@URL_PATH,1)='\','','\')+@N_FACTURA 
	END

	IF COALESCE(@PLANO, N'') = N''
	BEGIN
		PRINT CONCAT('[SPK_RIPS_JSON_FTR_IND] ERROR: @PLANO quedÃ³ NULL/vacÃ­o. N_FACTURA=', COALESCE(@N_FACTURA,''), ' NOADMISION=', COALESCE(@NOADMISION,''), ' TIPOUSU=', COALESCE(@TIPOUSU,'NULL'));
		RAISERROR('SPK_RIPS_JSON_FTR_IND: el JSON resultante quedÃ³ NULL. Revise Messages (TIPOUSU/afiliado/XML).', 16, 1);
		RETURN;
	END

	PRINT CONCAT('[SPK_RIPS_JSON_FTR_IND] FINALIZO OK | LEN_PLANO=', CONVERT(VARCHAR(20), LEN(@PLANO)));
	PRINT 'FINALIZO EN SPK_RIPS_JSON_FTR_IND'
	
	-- Limpiar tablas temporales
	IF OBJECT_ID('tempdb..#CONSULTAS') IS NOT NULL DROP TABLE #CONSULTAS
	IF OBJECT_ID('tempdb..#CONSULTAS1') IS NOT NULL DROP TABLE #CONSULTAS1
	IF OBJECT_ID('tempdb..#MEDICAMENTOS') IS NOT NULL DROP TABLE #MEDICAMENTOS
	IF OBJECT_ID('tempdb..#PROCEDIMIENTOS') IS NOT NULL DROP TABLE #PROCEDIMIENTOS
	IF OBJECT_ID('tempdb..#PROCEDIMIENTOS1') IS NOT NULL DROP TABLE #PROCEDIMIENTOS1
	IF OBJECT_ID('tempdb..#OTROSSER') IS NOT NULL DROP TABLE #OTROSSER
	IF OBJECT_ID('tempdb..#OTROSSER05') IS NOT NULL DROP TABLE #OTROSSER05
	IF OBJECT_ID('tempdb..#DX') IS NOT NULL DROP TABLE #DX
	IF OBJECT_ID('tempdb..#DX1') IS NOT NULL DROP TABLE #DX1
END

