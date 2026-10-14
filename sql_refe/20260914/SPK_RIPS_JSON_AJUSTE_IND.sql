CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_AJUSTE_IND
@CNSGLO  VARCHAR(20),
@URL_PATH VARCHAR(MAX)=NULL,
@PLANO NVARCHAR(MAX) OUTPUT
AS 
DECLARE @NOADMISION VARCHAR(20)
DECLARE @PROCEDENCIA VARCHAR(20)
DECLARE @N_FACTURA VARCHAR(20)
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
DECLARE @ZONA VARCHAR(20) --01 RURAL -- 02 URBANO
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
DECLARE @BASE64 NVARCHAR(MAX)
DECLARE @CONSULTAS TABLE (
	codPrestador VARCHAR(20),
	fechaInicioAtencion VARCHAR(16),
	numAutorizacion VARCHAR(30),
	codConsulta VARCHAR(6),
	modalidadGrupoServicioTecSal VARCHAR(2),
	grupoServicios VARCHAR(2),
	codServicio VARCHAR(4),
	finalidadTecnologiaSalud VARCHAR(2),
	causaMotivoAtencion VARCHAR(2),
	codDiagnosticoPrincipal VARCHAR(20),
	codDiagnosticoRelacionado1 VARCHAR(20),
	codDiagnosticoRelacionado2 VARCHAR(20),
	codDiagnosticoRelacionado3 VARCHAR(20),
	tipoDiagnosticoPrincipal VARCHAR(3),
	vrServicio int,
	tipoPagoModerador VARCHAR(2),
	tipoDocumentoIdentificacion VARCHAR(2), 
	numDocumentoIdentificacion VARCHAR(20), 
	valorPagoModerador VARCHAR(10),
   numFEVPagoModerador VARCHAR(20),
	consecutivo  INT IDENTITY(1,1) 
)
DECLARE @CONSULTAS1 TABLE (
	codPrestador VARCHAR(20),
	fechaInicioAtencion VARCHAR(16),
	numAutorizacion VARCHAR(30),
	codConsulta VARCHAR(6),
	modalidadGrupoServicioTecSal VARCHAR(2),
	grupoServicios VARCHAR(2),
	codServicio VARCHAR(4),
	finalidadTecnologiaSalud VARCHAR(2),
	causaMotivoAtencion VARCHAR(2),
	codDiagnosticoPrincipal VARCHAR(20),
	codDiagnosticoRelacionado1 VARCHAR(20),
	codDiagnosticoRelacionado2 VARCHAR(20),
	codDiagnosticoRelacionado3 VARCHAR(20),
	tipoDiagnosticoPrincipal VARCHAR(3),
	tipoDocumentoIdentificacion VARCHAR(2), 
	numDocumentoIdentificacion VARCHAR(20), 
	vrServicio int,
	Cantidad int,
	tipoPagoModerador VARCHAR(2),
	valorPagoModerador VARCHAR(10),
   numFEVPagoModerador VARCHAR(20),
	restoPagoModerador  VARCHAR(10),
	consecutivo  INT IDENTITY(1,1) 
)
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
	@valorPagoModerador VARCHAR(10),
	@consecutivo  VARCHAR(4)  

DECLARE @MEDICAMENTOS TABLE (
	codPrestador VARCHAR(20),
	numAutorizadon VARCHAR(30),
	idMIPRES       VARCHAR(15),
	fechaDispensAdmon VARCHAR(16),
	codDiagnosticoPrincipal VARCHAR(20),
	codDiagnosticoRelacionado VARCHAR(20),
	tipoMedicamento VARCHAR(4),
	codTecnologiaSalud VARCHAR(20),
	nomTecnologiaSalud VARCHAR(30),
	concentracionMedicamento VARCHAR(4),
	unidadMedida int,
	formaFarmaceutica VARCHAR(8),
	unidadMinDispensa VARCHAR(4),
	cantidadMedicamento VARCHAR(20),
	diasTratamiento     VARCHAR(5),
	tipoDocumentoIdentificacion VARCHAR(2),
	numDocumentoIdentificacion VARCHAR(20),
	vrUnitMedicamento VARCHAR(15),
	vrServicio VARCHAR(15),
	tipoPagoModerador VARCHAR(2),
	valorPagoModerador VARCHAR(10),
	numFEVPagoModerador VARCHAR(20),
	consecutivo  INT IDENTITY(1,1) ,
	MED BIT,
	idArticulo varchar(20)
)
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

DECLARE @PROCEDIMIENTOS TABLE (
	codPrestador VARCHAR(12),
	fechaInicioAtencion VARCHAR(16),
	idMIPRES VARCHAR(15),
	numAutorizacion VARCHAR(30),
	codProcedimiento VARCHAR(6),
	vialngresoServicioSalud VARCHAR(2),
	modalidadGrupoServicioTecSal VARCHAR(2),
	grupoServicios VARCHAR(2),
	codServicio VARCHAR(4),
	finalidadTecnologiaSalud VARCHAR(2),
	tipoDocumentoIdentificacion VARCHAR(2),
	numDocumentoIdentificacion VARCHAR(20),
	codDiagnosticoPrincipal VARCHAR(20),
	codDiagnosticoRelacionado VARCHAR(20),
	codComplicacion VARCHAR(20),
	vrServicio int, 
	tipoPagoModerador  VARCHAR(2),
	valorPagoModerador  VARCHAR(10),
	numFEVPagoModerador VARCHAR(20),
	consecutivo INT IDENTITY(1,1)
	)
DECLARE @PROCEDIMIENTOS1 TABLE (
	codPrestador VARCHAR(12),
	fechaInicioAtencion VARCHAR(16),
	idMIPRES VARCHAR(15),
	numAutorizacion VARCHAR(30),
	codProcedimiento VARCHAR(6),
	vialngresoServicioSalud VARCHAR(2),
	modalidadGrupoServicioTecSal VARCHAR(2),
	grupoServicios VARCHAR(2),
	codServicio VARCHAR(4),
	finalidadTecnologiaSalud VARCHAR(2),
	tipoDocumentoIdentificacion VARCHAR(2),
	numDocumentoIdentificacion VARCHAR(20),
	codDiagnosticoPrincipal VARCHAR(20),
	codDiagnosticoRelacionado VARCHAR(20),
	codComplicacion VARCHAR(20),
   vrtotal int, 
	vrServicio int, 
	cantidad int,
	tipoPagoModerador  VARCHAR(2),
	valorPagoModerador  VARCHAR(10),
	restoPagoModerador  VARCHAR(10),
	numFEVPagoModerador VARCHAR(20),
	consecutivo INT IDENTITY(1,1)
	)
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

DECLARE @OTROSSER TABLE (
	codPrestador VARCHAR(20),
	numAutorizacion VARCHAR(30),
	idMIPRES VARCHAR(15),
	fechaSuministroTecnologia VARCHAR(16),
	tipoOS VARCHAR(2),
	codTecnologiaSalud VARCHAR(20),
	nomTecnologiaSalud VARCHAR(60),
	cantidadOS INT, 
	tipoDocumentoIdentificacion VARCHAR(2),
	numDocumentoIdentificacion VARCHAR(20),
	vrUnitOS INT, 
	vrServicio int, 
	tipoPagoModerador VARCHAR(2),
	valorPagoModerador VARCHAR(20),
	numFEVPagoModerador VARCHAR(20),
	consecutivo  INT IDENTITY(1,1) 
	)
DECLARE  @fechaSuministroTecnologia VARCHAR(16)
	,@tipoOS VARCHAR(2)
	,@cantidadOS INT
	,@vrUnitOS INT
	,@primerGrupo BIT = 1
DECLARE @RESIDUO DECIMAL(14,2)

DECLARE @numDocumentoIdObligado VARCHAR(20) 
DECLARE @IDPLAN VARCHAR(10),@CONCEPTORECAUDOICI VARCHAR(20) ,@IDDXCIT VARCHAR(10) ,@TIPODXCIT VARCHAR(20) ,@IDAFILIADOCIT VARCHAR(20)
       ,@CONCEPTORECAUDOICE VARCHAR(20) ,@ESMODERADORAENFTR VARCHAR(2) ,@FMINHPRE DATE,@FMAXHPRE DATE,@FHADM DATE ,@FALTAMED DATE,@FINIATEN DATETIME ,@FFINATEN DATETIME
       ,@FINIATENCION DATETIME, @FFINATENCION DATETIME, @ITEM_FDIANR INT,@FECHAFACTURA DATE ,@FECHANACIMIENTOAFI DATE ,@EDAD INT, @PAQUETE INT -- 20250618 - STORRES - SE AGREGA VARIABLE PARA IDENTIFICAR PAQUETE
BEGIN

   SET LANGUAGE Spanish
   SET DATEFORMAT dmy
	PRINT 'SPK_RIPS_JSON_AJUSTE_IND'
	--SELECT [PROCEDENCIA]=FTR.PROCEDENCIA,[NOADMISION]=FTR.NOREFERENCIA ,[IDSEDE ]= IDSEDE
	--		,[VALORCOPAGO]=CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0) ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0) ELSE COALESCE(VALORCOPAGO,0) END END
	--	   ,[IDSEDE ]= IDSEDE, [CNSFCT ]= CNSFCT, [IDPLAN ]= FTR.IDPLAN,[N_FACTURA]=FTR.N_FACTURA
	--FROM FTR INNER JOIN FGLO ON FTR.N_FACTURA=FGLO.N_FACTURA
 --  WHERE FGLO.CNSGLO='0100001771' --@CNSGLO

--	PROCEDENCIA	NOADMISION	IDSEDE 	VALORCOPAGO	IDSEDE 	CNSFCT 	IDPLAN 	N_FACTURA
--SALUD	0100004500	01	0.00	01	0100013820	FOMAG	COCQ9856

	SELECT @PROCEDENCIA=FTR.PROCEDENCIA,@NOADMISION=FTR.NOREFERENCIA ,@IDSEDE = IDSEDE
			,@VALORCOPAGO=CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0) ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0) ELSE COALESCE(VALORCOPAGO,0) END END
		   ,@IDSEDE = IDSEDE, @CNSFCT = CNSFCT, @IDPLAN = FTR.IDPLAN,@N_FACTURA=FTR.N_FACTURA
	FROM FTR LEFT JOIN FGLO ON FTR.N_FACTURA=FGLO.N_FACTURA
   WHERE @CNSGLO=CASE WHEN FGLO.CNSGLO IS NULL THEN FTR.CNSFCT ELSE FGLO.CNSGLO END

   SELECT @ITEM_FDIANR = MAX(ITEM)
   FROM  FDIANR 
              WHERE CNSDOCUMENTO =  @CNSFCT  --'0100011890'-- @CNSFCT 
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
   END
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
		PRINT 'No encontre la Factura...me devuelvo'
		RETURN
	END
	
--	PROCEDENCIA	NOADMISION	IDSEDE 	VALORCOPAGO	IDSEDE 	CNSFCT 	IDPLAN 	N_FACTURA
--SALUD	0100004500	01	0.00	01	0100013820	FOMAG	COCQ9856


	SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
   SELECT @CONCEPTORECAUDOICI = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICI' 
   SELECT @CONCEPTORECAUDOICE = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICE' 
	IF EXISTS(SELECT 1 FROM FTR INNER JOIN AFI ON FTR.IDAFILIADO=AFI.IDAFILIADO WHERE FTR.N_FACTURA=@N_FACTURA)
	BEGIN
		SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
            @TIPOUSU= CASE WHEN COALESCE(AFI.TIPOUSUARIO,'')<>'' AND LEN(AFI.TIPOUSUARIO) = 2 THEN AFI.TIPOUSUARIO ELSE 
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
			@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
			@INCAPACIDAD='NO',@CNS=1
         ,@FECHAFACTURA = FTR.F_FACTURA
         ,@FECHANACIMIENTOAFI = AFI.FNACIMIENTO
		FROM FTR INNER JOIN AFI ON FTR.IDAFILIADO=AFI.IDAFILIADO 
		WHERE FTR.N_FACTURA=@N_FACTURA

      SELECT @EDAD = DATEDIFF(year, @FECHANACIMIENTOAFI, @FECHAFACTURA)           -- diferencia bruta de a?os
             - CASE                                    -- ?ya celebr? el cumplea?os este a?o?
                 WHEN DATEADD(year,
                              DATEDIFF(year,@FECHANACIMIENTOAFI, @FECHAFACTURA),
                              @FECHANACIMIENTOAFI) > @FECHAFACTURA
                 THEN 1
                 ELSE 0
               END
      IF @EDAD < 7 SELECT @TIPODOC = 'RC'
      PRINT '@EDAD='+CONVERT(VARCHAR(5),@EDAD)
	END
	ELSE
	BEGIN
		IF @PROCEDENCIA='CI' OR @PROCEDENCIA='ONCO'
		BEGIN
			SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
				@TIPOUSU= CASE WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN   AFI.TIPOUSUARIO
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
				@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
				@INCAPACIDAD='NO',@CNS=1
			FROM CIT INNER JOIN AFI ON CIT.IDAFILIADO=AFI.IDAFILIADO 
			WHERE CIT.CONSECUTIVO=@NOADMISION
		END
		BEGIN
			IF @PROCEDENCIA='AUT'
			BEGIN
				SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
					@TIPOUSU= CASE    WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN   AFI.TIPOUSUARIO
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
					@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
					@INCAPACIDAD='NO',@CNS=1
				FROM AUT INNER JOIN AFI ON AUT.IDAFILIADO=AFI.IDAFILIADO 
				WHERE AUT.NOAUT=@NOADMISION
			END
			ELSE
			BEGIN
				SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
					@TIPOUSU= CASE    WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN   AFI.TIPOUSUARIO
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
					@SEXO=UPPER(LEFT(AFI.SEXO,1)),@MUNICIPIO=AFI.CIUDAD,@ZONA=CASE WHEN AFI.ZONA='R' THEN '01'ELSE '02' END,
					@INCAPACIDAD='NO',@CNS=1
				FROM HADM INNER JOIN AFI ON HADM.IDAFILIADO=AFI.IDAFILIADO 
				WHERE HADM.NOADMISION=@NOADMISION
			END
		END
	END
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

	-- Si la IPS maneja multiples sedes el codigo de habilitaci?n es por sede
	IF EXISTS(SELECT 1 FROM USVGS WHERE IDVARIABLE = 'FACTSEDE' AND DATO='SI')
	BEGIN
		SELECT @IDPRESTADOR = COALESCE(CODHABILITA, IDSGSSS) FROM SED WHERE IDSEDE=@IDSEDE
	END
	PRINT '@PROCEDENCIA = ' + @PROCEDENCIA

	SELECT @PLANO='{'
	SET @PLANO += '"numDocumentoIdObligado":"'+LTRIM(RTRIM(COALESCE(@numDocumentoIdObligado,'')))+'" ,' 
	SET @PLANO += '"numFactura":"'+@N_FACTURA+'" ,'
	SET @PLANO += '"tipoNota":"NA",'
	SET @PLANO += '"numNota": "'+@N_FACTURA+'",'
	--SET @PLANO += '"numNota": "'+@CNSGLO+'",'
	SET @PLANO += '"usuarios": [ '
	SET @PLANO += '{ '
	SET @PLANO += '  "tipoDocumentoIdentificacion":"'+CASE WHEN @TIPODOC = 'NV' THEN 'CN' ELSE @TIPODOC END+'" ,'
	SET @PLANO += '  "numDocumentoIdentificacion":"'+@DOCIDAFILIADO+'" ,'
	SET @PLANO += '  "tipoUsuario":"'+@TIPOUSU+'" ,'
	SET @PLANO += ' "fechaNacimiento":"'+@FNACIMIENTO+'",'
	SET @PLANO += ' "codSexo": "'+@SEXO+'",'
	SET @PLANO += ' "codPaisResidencia":"170" ,'
	SET @PLANO += ' "codMunicipioResidencia": "'+@MUNICIPIO+'", '
	SET @PLANO += ' "codZonaTerritorialResidencia": "'+@ZONA+'",'
	SET @PLANO += ' "incapacidad":"'+@INCAPACIDAD+'",'
	SET @PLANO += ' "consecutivo": '+CAST(@CNS AS VARCHAR(5))+','
	SET @PLANO += ' "codPaisOrigen":"170" ,' -- debe ir aqui segun resolucion deiver
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
           1. Obt?n el AttachedDocument y quita la cabecera
         ------------------------------------------------------------------*/
         SELECT TOP 1 @AttachedText = XML_AttachedDocument
         FROM   FDIANR
         WHERE  CNSDOCUMENTO = @CNSFCT
         AND    TIPO         = 'FV'
			AND METODO='SendBillSync'  
			AND COALESCE (  XML_AttachedDocument, '')<>''  -- EEMC78 31-08-2025 Minimiza el error de UBL
		 ORDER BY CONVERT(DATE,FECHA) DESC

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
             PRINT 'No se pudo convertir AttachedDocument a XML.  o no se encuentra el AttachedDocument'
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
                RAISERROR('No se encontr? la factura UBL dentro del AttachedDocument. o no se encuentra el AttachedDocument', 16, 1);
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
                RAISERROR('El texto extra?do no es XML v?lido.', 16, 1);
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

            /* 7- Coge solo HH:MM:SS  y convi?rtelo */
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
         IF @FFINATENCION > @FFINATEN
         BEGIN
            SELECT @FFINATEN  = @FFINATENCION
         END
      END
      SELECT @fechaInicioAtencion = REPLACE(CONVERT(VARCHAR,@FINIATEN,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,@FINIATEN,108),5)
      SELECT @fechaEgreso = REPLACE(CONVERT(VARCHAR,@FFINATEN,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,@FFINATEN,108),5)
      print '@fechaInicioAtencion=' +@fechaInicioAtencion 
      print '@fechaEgreso='+@fechaEgreso

   end--VERIFICACION de fechas en el xml de la factura para poder arreglar a las malas los datos

	IF @PROCEDENCIA='CI'
	BEGIN
		BEGIN --AC
         PRINT 'AC'
					
			
			INSERT INTO @CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
									finalidadTecnologiaSalud,causaMotivoAtencion,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion)
			SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
				    numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                codConsulta=LEFT(SER.CODCUPS,6),
                modalidadGrupoServicioTecSal='01',
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                -- finalidadTecnologiaSalud=LEFT(CASE WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA='10' OR COALESCE(TGEN.DATO1,'')='' THEN '44' ELSE COALESCE(TGEN.DATO1,CIT.FINCONSULTA,'') END,2),
				--- EEMC78 30-08-2025 SE CAMBIA PARA HOMOLOGACION
				finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1 ,'12') 
												WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12')
												WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10' 
														THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>'' 
																	THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'12') 
																END  
												ELSE  COALESCE(FINALIDADTGEN.DATO1,'12') 
                                    END,2),

					 causaMotivoAtencion='38',
                CASE WHEN CIT.IDPLAN IN (SELECT DATO FROM USVGS WHERE IDVARIABLE IN ('IDPLANPART','IDPLANPART1', 'IDPLANPART2', 'IDPLANPART3', 'IDPLANPART4', 'IDPLANPART5'))
                          THEN COALESCE(CIT.VALORTOTAL,0)-COALESCE(CIT.DESCUENTO,0)
                     ELSE FTRD.VLR_SERVICI
                END, --storres_20250403
                COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO
			FROM   FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO
				         INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				         INNER JOIN MED     ON CIT.IDMEDICO = MED.IDMEDICO
				         INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				        -- LEFT JOIN TGEN    ON TGEN.TABLA='GENERAL' AND CAMPO='FINALIDADCONSULTA' AND CODIGO=CIT.FINCONSULTA
							LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP' 
                      
							LEFT JOIN TGEN ON TGEN.TABLA = 'AFI' AND TGEN.CAMPO = 'TIPOATENCION' AND TGEN.CODIGO = CIT.ATENCION
							  
							--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD  

			WHERE FTRD.N_FACTURA=@N_FACTURA
			AND   RIPS_CP.ARCHIVO='AC'
         AND   COALESCE(FTRD.VR_TOTAL,0)>0

			IF EXISTS(SELECT 1 FROM @CONSULTAS)
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

            UPDATE @CONSULTAS SET codDiagnosticoPrincipal=@IDDXCIT
				,codDiagnosticoRelacionado1=@IDDXCIT
				,codDiagnosticoRelacionado2=@IDDXCIT
				,codDiagnosticoRelacionado3=@IDDXCIT
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
         print 'ap'

			
			INSERT INTO @PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
						,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
						,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
						)
			SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),null,
					 numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                LEFT(SER.CODCUPS,6),'02','01',
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                -- ,'16',
					,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
					 MED.TIPO_ID,MED.IDMEDICO,CIT.IDDX,
					 CIT.IDDX,COALESCE(CIT.IDDX,'null'),COALESCE(FTRD.VLR_SERVICI,0),'04',COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA)
			FROM  FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				        INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				        INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
			           INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
						  	
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

			WHERE FTRD.N_FACTURA  = @N_FACTURA
		   AND   RIPS_CP.ARCHIVO ='AP'

			IF EXISTS(SELECT 1 FROM @PROCEDIMIENTOS)
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
               UPDATE @PROCEDIMIENTOS SET codDiagnosticoPrincipal=@IDDXCIT
				   ,codDiagnosticoRelacionado=@IDDXCIT
				   FROM CIT 
				   WHERE CIT.CONSECUTIVO=@NOADMISION
            END
				--AND N_FACTURA=@N_FACTURA    


			END
		END
		BEGIN --AT
         PRINT 'AT'
			INSERT INTO @OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
								,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
								,valorPagoModerador,numFEVPagoModerador)
			SELECT @IDPRESTADOR,
                numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(CIT.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', CIT.NOAUTORIZACION),'A-Z0-9-'),  -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                NULL,
			       fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,CIT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,CIT.FECHA,108),5),
			       tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END
					 ,  --20250702 -- STORRES -- ESPERA CAMPO PARA REALIZAR CONFIGURACION
                codTecnologiaSalud=LEFT(SER.CODCUPS,6), nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
			       cantidadOS=COALESCE(CIT.CANTIDADC,1), MED.TIPO_ID, MED.IDMEDICO, COALESCE(FTRD.VLR_SERVICI,0),COALESCE(FTRD.VLR_SERVICI,0),
                tipoPagoModerador='04',
                COALESCE(FTRD.VLR_COPAGOS,0), COALESCE(CIT.NFACTURA,@N_FACTURA)
			FROM   FTRD INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO 
				         INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
				         INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                     INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
			WHERE FTRD.N_FACTURA  = @N_FACTURA
         AND   RIPS_CP.ARCHIVO = 'AT'
		END
	END
	ELSE IF @PROCEDENCIA='CE'
	BEGIN
		BEGIN --AC
			
		
			INSERT INTO @CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								finalidadTecnologiaSalud,causaMotivoAtencion
                        ,codDiagnosticoPrincipal
                        ,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion )
			SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				    numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                codConsulta=LEFT(SER.CODCUPS,6),
                modalidadGrupoServicioTecSal='01',
                grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                finalidadTecnologiaSalud=LEFT(CASE	WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
													WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' 
													ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12') 
												END,2),

				    causaMotivoAtencion='38'
                , AUT.DXPPAL codDiagnosticoPrincipal  -- EEMC 06-06-2025 SE AGREGA DX PORQUE SON CONSULTAS 
               ,FTRD.VLR_SERVICI 
               --,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                ,CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
				   ,COALESCE(AUTD.NFACTURA,@N_FACTURA),COALESCE(MED.TIPO_ID, @TIPODOC,''), COALESCE(MED.IDMEDICO, @DOCIDAFILIADO,'') --STORRES_20250326
			FROM  FTRD INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT 
                                      AND FTRD.NOITEM       = AUTD.NO_ITEM
                    INNER JOIN AUT     ON AUTD.IDAUT        = AUT.IDAUT
					     INNER JOIN SER     ON AUTD.IDSERVICIO   = SER.IDSERVICIO
					     INNER JOIN RIPS_CP ON SER.CODIGORIPS    = RIPS_CP.IDCONCEPTORIPS
					      --LEFT JOIN TGEN    ON TGEN.TABLA        = 'GENERAL' 
           --                           AND CAMPO             = 'FINALIDADCONSULTA' 
           --                           AND CODIGO            = AUT.FINALIDAD  --- EEMC78 30-08-2025 SE CAMBIA PARA HOMOLOGACION
					      LEFT JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)		
								
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

			WHERE FTRD.N_FACTURA         = @N_FACTURA
			AND   COALESCE(AUTD.VALOR,0) > 0
			--AND   AUTD.CANTIDAD          > 0
         AND   COALESCE(AUTD.CANTIDAD,1 ) = 1
			AND   RIPS_CP.ARCHIVO        ='AC'

         -- EEMC 06-06-2025  AHORA  LOS QUE TIENEN CANTIDAD > 1
      
		
		INSERT INTO @CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud
                           ,causaMotivoAtencion
                           ,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3
                           ,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad) 
			   SELECT @IDPRESTADOR,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
						numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'),codConsulta=LEFT(SER.CODCUPS,6),modalidadGrupoServicioTecSal='01',
						grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
						codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
						finalidadTecnologiaSalud=LEFT(CASE	WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') 
															WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' 
															ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12') 
													END,2),
				       causaMotivoAtencion='38'
                  ,COALESCE(AUT.DXPPAL,'') codDiagnosticoPrincipal,COALESCE(AUT.DXRELACIONADO,'') codDiagnosticoRelacionado1,COALESCE(AUT.DXRELACIONADO2,'') codDiagnosticoRelacionado2
                  ,COALESCE(AUT.COMPLICACION,'') codDiagnosticoRelacionado3
				      ,FTRD.VLR_SERVICI 
                 -- ,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                  ,CAST(CONVERT(DECIMAL(14,2),FTRD.VLR_COPAGOS) AS VARCHAR(20))
				      ,COALESCE(AUTD.NFACTURA,@N_FACTURA),COALESCE(MED.TIPO_ID, @TIPODOC,''), COALESCE(MED.IDMEDICO, @DOCIDAFILIADO,'') 
                  ,CONVERT(INT,AUTD.CANTIDAD)
			   FROM  FTRD INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT 
                                         AND FTRD.NOITEM       = AUTD.NO_ITEM
                       INNER JOIN AUT     ON AUTD.IDAUT        = AUT.IDAUT
					        INNER JOIN SER     ON AUTD.IDSERVICIO   = SER.IDSERVICIO
					        INNER JOIN RIPS_CP ON SER.CODIGORIPS    = RIPS_CP.IDCONCEPTORIPS
					         --LEFT JOIN TGEN    ON TGEN.TABLA        = 'GENERAL' 
              --                           AND CAMPO             = 'FINALIDADCONSULTA' 
              --                           AND CODIGO            = AUT.FINALIDAD
					         LEFT JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)				
										
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

			   WHERE FTRD.N_FACTURA         = @N_FACTURA
			   AND   COALESCE(AUTD.VALOR,0) > 0
            AND   COALESCE(AUTD.CANTIDAD,1 ) > 1
			   AND   RIPS_CP.ARCHIVO        ='AC'

         
			   UPDATE @CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
			   UPDATE @CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
			   SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM @CONSULTAS1
			
			   DECLARE JSCONSUL_AUT_CURSOR CURSOR FOR 
			   SELECT consecutivo,CANTIDAD FROM @CONSULTAS1
			   ORDER BY consecutivo
			   OPEN JSCONSUL_AUT_CURSOR    
			   FETCH NEXT FROM JSCONSUL_AUT_CURSOR    
			   INTO @CNSCONSULTA,@CANTORI
			   WHILE @@FETCH_STATUS = 0    
			   BEGIN 
				   SELECT @BANDERA=1
               PRINT 'ENTRE A SEPARAR LAS CONSULTAS CUANDO SE CARGARON POR AUT Y LA CANTIDAD > 1'
				   --SELECT valorPagoModerador, @CANTORI FROM @CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				   SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM @CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				   --SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM @PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA

				   WHILE @BANDERA<=@CANTORI
				   BEGIN
					   IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
					   BEGIN
						   SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
					   END
					   INSERT INTO @CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion) 
					   SELECT codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								   finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								   codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,iif(coalesce(cantidad,1)>1 ,vrServicio/cantidad , vrServicio),@valorPagoModerador,numFEVPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion 
					   FROM @CONSULTAS1
					   WHERE consecutivo=@CNSCONSULTA
					   SELECT @BANDERA = @BANDERA+1
				   END

				   FETCH NEXT FROM JSCONSUL_AUT_CURSOR    
				   INTO  @CNSCONSULTA,@CANTORI
			   END
			   CLOSE JSCONSUL_AUT_CURSOR
			   DEALLOCATE JSCONSUL_AUT_CURSOR

         -----  EEMC 

			IF EXISTS(SELECT 1 FROM @CONSULTAS)
			BEGIN
				UPDATE @CONSULTAS SET codDiagnosticoPrincipal=AUT.DXPPAL
				,codDiagnosticoRelacionado1=AUT.DXRELACIONADO
				,codDiagnosticoRelacionado2=AUT.DXRELACIONADO2
				,tipoDiagnosticoPrincipal='01'
				FROM AUT
				WHERE AUT.NOAUT=@NOADMISION
				AND N_FACTURA=@N_FACTURA  
			END
		END
		BEGIN --AM
			INSERT INTO @MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
										,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
										,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
										,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)

			SELECT @IDPRESTADOR,NULL, -- SERMUS89: medicamentos ya no exigen numAutorizacion (norma SISPRO)
                null,fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				    AUT.DXPPAL,AUT.DXRELACIONADO,'01',dbo.FNK_LIMPIATEXTO(COALESCE(IART.CODCUM,SER.CODCUM),'A-Z0-9-'),LEFT( dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),'0',
				    COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,AUTD.CANTIDAD),10), CAST(IIF(COALESCE(AUTD.DIAS,0)=0,1,AUTD.DIAS) AS VARCHAR(3)),
				    COALESCE(MED.TIPO_ID, @TIPODOC),COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),AUTD.VALOR,AUTD.VALOR * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) ,
				    '04'
				    ,CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
				    ,COALESCE(AUTD.NFACTURA,@N_FACTURA)
			FROM AUT 
				INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT
				INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT JOIN IART ON SER.IDSERVICIO=IART.IDSERVICIO AND PRINCIPAL = 1 
				LEFT JOIN IFFA  ON IART.IDFORFARM=IFFA.IDFORFARM
				LEFT JOIN IUNI ON IUNI.IDUNIDAD=IART.IDUNIDAD
				LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)				
			WHERE AUT.NOAUT=@NOADMISION
				AND AUTD.N_FACTURA=@N_FACTURA
				AND COALESCE(AUTD.VALOR,0)>0
				AND AUTD.CANTIDAD>0
				AND RIPS_CP.ARCHIVO='AM'
		END
		BEGIN --AP
			INSERT INTO @PROCEDIMIENTOS1 (codPrestador, fechaInicioAtencion, idMIPRES, numAutorizacion, codProcedimiento, vialngresoServicioSalud,modalidadGrupoServicioTecSal,
				grupoServicios ,codServicio ,finalidadTecnologiaSalud ,tipoDocumentoIdentificacion ,numDocumentoIdentificacion ,codDiagnosticoPrincipal ,codDiagnosticoRelacionado
				,codComplicacion ,vrServicio ,tipoPagoModerador ,valorPagoModerador ,numFEVPagoModerador,CANTIDAD)
			SELECT @IDPRESTADOR,REPLACE(CONVERT(VARCHAR, AUT.FECHA, 102), '.', '-') + ' ' + LEFT(CONVERT(VARCHAR, AUT.FECHA, 108), 5) ,NULL ,
                numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                LEFT(SER.CODCUPS,6) ,'02' ,'01',
				 grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
             codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
            -- ,'16',
					,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN

				COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,@DOCIDAFILIADO), AUT.DXPPAL ,AUT.DXRELACIONADO
				--,AUT.DXPPAL,COALESCE(AUTD.VALOR * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) , 0) ,'04'
            ,AUT.DXPPAL,COALESCE(AUTD.VALOR  , 0) ,'04'
				,CASE 
					WHEN AUT.IDPLAN IN (DBO.FNK_VALORVARIABLE ('IDPLANPART'),DBO.FNK_VALORVARIABLE ('IDPLANPART2')
										,DBO.FNK_VALORVARIABLE ('IDPLANPART3'),DBO.FNK_VALORVARIABLE ('IDPLANPART4')
										,DBO.FNK_VALORVARIABLE ('IDPLANPART5'))
					THEN '0.00' 
					ELSE CASE WHEN COALESCE(FTRD.VLR_COPAGOS,0) >0 THEN COALESCE(FTRD.VLR_COPAGOS,0)
                         ELSE --CAST(CONVERT(DECIMAL(14,2), IIF(COALESCE(AUT.COPAGOPROPIO,0)=1, COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)), COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20))
                          CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
                    END 
					END
				,COALESCE(AUTD.NFACTURA,@N_FACTURA), AUTD.CANTIDAD
			FROM  FTRD LEFT JOIN AUTD     ON FTRD.NOPRESTACION = AUTD.IDAUT
                                      AND FTRD.NOITEM       = AUTD.NO_ITEM
                    INNER JOIN AUT     ON AUTD.IDAUT = AUT.IDAUT
                    INNER JOIN SER     ON AUTD.IDSERVICIO = SER.IDSERVICIO
                    INNER JOIN RIPS_CP ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
				        LEFT  JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)	
						  	
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

         WHERE FTRD.N_FACTURA = @N_FACTURA
         AND   RIPS_CP.ARCHIVO = 'AP'
         AND   COALESCE(FTRD.VR_TOTAL,0)  > 0     
         


			UPDATE @PROCEDIMIENTOS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
			UPDATE @PROCEDIMIENTOS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
			SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM @PROCEDIMIENTOS1
			
			DECLARE JSPROCE_CURSOR_AUTD CURSOR FOR 
			SELECT consecutivo,CANTIDAD FROM @PROCEDIMIENTOS1
			ORDER BY consecutivo
			OPEN JSPROCE_CURSOR_AUTD
			FETCH NEXT FROM JSPROCE_CURSOR_AUTD INTO @CNSCONSULTA,@CANTORI
			WHILE @@FETCH_STATUS = 0    
			BEGIN
				SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM @PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
				SELECT @BANDERA=1
				WHILE @BANDERA<=@CANTORI
				BEGIN
					IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
					BEGIN
						SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
					END
					INSERT INTO @PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
								,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
								,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador
									)
					SELECT codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
									,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
									,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,@valorPagoModerador,numFEVPagoModerador
					FROM @PROCEDIMIENTOS1
					WHERE consecutivo=@CNSCONSULTA
					SELECT @BANDERA = @BANDERA+1
				END
				FETCH NEXT FROM JSPROCE_CURSOR_AUTD INTO  @CNSCONSULTA,@CANTORI
			END
			CLOSE JSPROCE_CURSOR_AUTD
			DEALLOCATE JSPROCE_CURSOR_AUTD
		END
		BEGIN --AT
			INSERT INTO @OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
									,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
									,valorPagoModerador,numFEVPagoModerador)
			SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
            null, fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
				tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END
				, --20250702 -- STORRES -- ESPERA CAMPO PARA CONFIGURAR 
            codTecnologiaSalud=LEFT(SER.CODCUPS,6),nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
				cantidadOS=COALESCE(AUTD.CANTIDAD,1),tipoDocumentoIdentificacion=COALESCE(MED.TIPO_ID,@TIPODOC),
				numDocumentoIdentificacion=COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),
				COALESCE(AUTD.VALOR,0),
				COALESCE(AUTD.VALOR,0) * ( CASE COALESCE(AUTD.CANTIDAD,0) WHEN 0 THEN 1 ELSE AUTD.CANTIDAD END ) ,
				tipoPagoModerador='04',
				CAST(CONVERT(DECIMAL(14,2),IIF(COALESCE(AUT.COPAGOPROPIO,0)=1,COALESCE(AUT.VALORCOPAGO,0)/COALESCE(AUT.NO_ITEMES,ROW_NUMBER() OVER (ORDER BY AUTD.NO_ITEM)) ,COALESCE(AUTD.VALORCOPAGO,0))) AS VARCHAR(20)),
				COALESCE(AUTD.NFACTURA,@N_FACTURA)
			FROM AUT 
				INNER JOIN AUTD ON AUT.IDAUT=AUTD.IDAUT
				INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
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
		IF 1=1
		BEGIN --AC

		
			-- COCQ9856  ,  0100004500
		
			INSERT INTO @CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad) 
			SELECT COALESCE(@IDPRESTADOR,'')
            ,fechaInicioAtencion=CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' THEN @fechaInicioAtencion
                                      ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
                                 END,
				numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(HPRED.AUTORIZACION,HADM.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', COALESCE(HPRED.AUTORIZACION,HADM.NOAUTORIZACION,'null')),'A-Z0-9-') -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
            ,codConsulta=LEFT(SER.CODCUPS,6),
            modalidadGrupoServicioTecSal='01',
            grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
            FINALIDADTECNOLOGIASALUD=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' ELSE COALESCE(FINALIDADTGEN.DATO1,'12') END,2),
				
				causaMotivoAtencion='38',COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HCA.DX3,HADM.DXSALIDA3),
				CASE HCA.TIPODX 
								WHEN 'Presuntivo'   THEN 1
								WHEN 'Impresion dx' THEN 1
								WHEN 'Definitivo'   THEN 2
								WHEN 'Conf Nuevo'   THEN 2
								WHEN 'Conf Repet'   THEN 3
								ELSE 1
								END,
				CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
            COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO,CONVERT(INT,HPRED.CANTIDAD)
			FROM HADM 
				INNER JOIN  HPRE ON HADM.NOADMISION=HPRE.NOADMISION
				INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
				INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
				LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3 
						FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>'' 
						AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
						ORDER BY HCA.FECHA DESC 
						) HCA ON HADM.NOADMISION=HCA.NOADMISION
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
				-- LEFT JOIN TGEN ON TGEN.TABLA='GENERAL' AND CAMPO='FINALIDADCONSULTA' AND CODIGO=HPRE.FINALIDAD
					
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

			WHERE HADM.NOADMISION=@NOADMISION
				AND HPRED.N_FACTURA=@N_FACTURA
				AND COALESCE(HPRED.VALOR,0)>0
				AND COALESCE(HPRED.NOCOBRABLE,0)=0
				AND COALESCE(HPRED.CANTIDAD,0)>0
				AND RIPS_CP.ARCHIVO='AC'

         
			UPDATE @CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad
			UPDATE @CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2))
			SELECT @RESIDUO=SUM(TRY_CAST(restoPagoModerador AS decimal(14,2))) FROM @CONSULTAS1
			
			DECLARE JSCONSUL_CURSOR CURSOR FOR 
			SELECT consecutivo,CANTIDAD FROM @CONSULTAS1
			ORDER BY consecutivo
			OPEN JSCONSUL_CURSOR    
			FETCH NEXT FROM JSCONSUL_CURSOR    
			INTO @CNSCONSULTA,@CANTORI
			WHILE @@FETCH_STATUS = 0    
			BEGIN 
				SELECT @BANDERA=1

				--SELECT valorPagoModerador, @CANTORI FROM @CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM @CONSULTAS1 WHERE consecutivo=@CNSCONSULTA
				--SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST((CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) AS DECIMAL (14,2))) FROM @PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA

				WHILE @BANDERA<=@CANTORI
				BEGIN
					IF @CNSCONSULTA=1 AND @BANDERA=@CANTORI
					BEGIN
						SET @valorPagoModerador = CONVERT(VARCHAR(20), TRY_CAST(@valorPagoModerador AS decimal)+TRY_CAST(@RESIDUO AS decimal(14,2)))
					END
					INSERT INTO @CONSULTAS(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion) 
					SELECT codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
								finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
								codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,@valorPagoModerador,numFEVPagoModerador, tipoDocumentoIdentificacion, numDocumentoIdentificacion 
					FROM @CONSULTAS1
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
			INSERT INTO @MEDICAMENTOS(codPrestador,numAutorizadon,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
									,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
									,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
									,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador, MED, idArticulo)

			SELECT @IDPRESTADOR,
            	 NULL, -- SERMUS89: medicamentos ya no exigen numAutorizacion (norma SISPRO)
                null,fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
				    COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),'01',SER.IDSERVICIO,LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),'0',
				    COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,HPRED.CANTIDAD),10),1,LEFT(MED.TIPO_ID,2),MED.IDMEDICO,
                CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR),20)END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
				    CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN '0' ELSE CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALOR*HPRED.CANTIDAD),20) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                '04',CONVERT(VARCHAR,CONVERT(DECIMAL(14,2),HPRED.VALORCOPAGO),20),COALESCE(@NFACTURA,@N_FACTURA), SER.MEDICAMENTOS, HPRED.IDARTICULO
			FROM HADM 
				INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
				INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
				INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT JOIN IART ON COALESCE(HPRED.IDARTICULO,SER.IDARTICULO)=IART.IDARTICULO
				LEFT JOIN IFFA ON IART.IDFORFARM=IFFA.IDFORFARM
				LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3 
						FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>'' 
						AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
						ORDER BY HCA.FECHA DESC 
						) HCA ON HADM.NOADMISION=HCA.NOADMISION
				LEFT JOIN IUNI ON IUNI.IDUNIDAD = IART.IDUNIDAD
                LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'') END
			WHERE HADM.NOADMISION=@NOADMISION
				AND HPRED.N_FACTURA=@N_FACTURA
				AND COALESCE(HPRED.VALOR,0)>0
				AND COALESCE(HPRED.NOCOBRABLE,0)=0
				AND COALESCE(HPRED.CANTIDAD,0)>0
				AND RIPS_CP.ARCHIVO='AM' 
			BEGIN
				UPDATE @MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE COALESCE(IART.CODCUM,'') WHEN '' THEN SER.CODCUM ELSE IART.CODCUM END
				FROM @MEDICAMENTOS A 
					INNER JOIN SER ON SER.IDSERVICIO=A.codTecnologiaSalud
					INNER JOIN IART ON IART.IDARTICULO=A.IDARTICULO
				WHERE SER.MEDICAMENTOS=1 AND ISNULL(A.codTecnologiaSalud,'')='' OR ISNULL(A.codTecnologiaSalud,'') NOT LIKE '%-%'

				UPDATE @MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE ISNULL(SER.CODCUM,'') WHEN '' THEN A.codTecnologiaSalud ELSE SER.CODCUM END
				FROM @MEDICAMENTOS A 
				INNER JOIN SER ON A.codTecnologiaSalud=SER.IDSERVICIO
				WHERE SER.MEDICAMENTOS=1 AND ISNULL(codTecnologiaSalud,'')='' OR ISNULL(codTecnologiaSalud,'') NOT LIKE '%-%'
				
				UPDATE @MEDICAMENTOS SET codTecnologiaSalud=DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9-') FROM @MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'	
				UPDATE @MEDICAMENTOS SET codTecnologiaSalud=(stuff((select CONCAT('-',IIF(ISNUMERIC(WORD)=1 AND CONVERT(INT, WORD)>0, CONVERT(INT, WORD),WORD)) 
												FROM DBO.FNK_EXPLODE(codTecnologiaSalud,'-') FOR XML PATH('')),1,1,'')
												)
				FROM @MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'
			END

		END
		IF 1=1
		BEGIN --AP
			INSERT INTO @PROCEDIMIENTOS1 (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
						,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
						,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador,cantidad,vrtotal
						)
			SELECT @IDPRESTADOR
            ,CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' THEN @fechaInicioAtencion
                  ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
             END
            ,null,
				numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(HPRED.AUTORIZACION,HADM.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', COALESCE(HPRED.AUTORIZACION,HADM.NOAUTORIZACION,'null')),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
            LEFT(SER.CODCUPS,6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
            grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
				codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
            -- ,'16',
					,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN

				LEFT(MED.TIPO_ID,2),MED.IDMEDICO,COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
				COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
            CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE COALESCE(HPRED.VALOR,0) END, --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
            '04',COALESCE(HPRED.VALORCOPAGO,0),COALESCE(@NFACTURA,@N_FACTURA),HPRED.CANTIDAD,
            CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE FTRD.VLR_SERVICI END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0 
			FROM HADM 
				INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
				INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
				INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				INNER JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'
				INNER JOIN FTRD ON HPRED.NOPRESTACION = FTRD.NOPRESTACION 
							AND HPRED.NOITEM       = FTRD.NOITEM
							AND HPRED.N_FACTURA    = FTRD.N_FACTURA 
							AND HADM.NOADMISION    = FTRD.NOADMISION
				LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'') END
				LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3 
						FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>'' 
						AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
						ORDER BY HCA.FECHA DESC 
						) HCA ON HADM.NOADMISION=HCA.NOADMISION
					
						--- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
						INNER JOIN PRE ON SER.PREFIJO	= PRE.PREFIJO 
						LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD 

			WHERE HADM.NOADMISION=@NOADMISION
				AND HPRED.N_FACTURA=@N_FACTURA
				AND COALESCE(HPRED.VALOR,0)>0
				AND COALESCE(HPRED.NOCOBRABLE,0)=0
				AND HPRED.CANTIDAD > 0
				AND RIPS_CP.ARCHIVO='AP'
             DECLARE @TOTALFTRD INT, @BASE INT, @RESTO INT, @TOTALMOD VARCHAR(10), @BASEMOD DECIMAL(14,2), @RESTOMOD DECIMAL(14,2)
			
			DECLARE JSPROCE_CURSOR CURSOR FOR 
			SELECT consecutivo,CANTIDAD,vrtotal, valorPagoModerador FROM @PROCEDIMIENTOS1
			ORDER BY consecutivo
			OPEN JSPROCE_CURSOR    
			FETCH NEXT FROM JSPROCE_CURSOR INTO @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
			WHILE @@FETCH_STATUS = 0    
			BEGIN 
				--SELECT  @valorPagoModerador=CONVERT(VARCHAR(20), CONVERT(DECIMAL (14,2),CAST(valorPagoModerador AS decimal(14,2))/@CANTORI)) FROM @PROCEDIMIENTOS1 WHERE consecutivo=@CNSCONSULTA
            SELECT @BASE = @TOTALFTRD/@CANTORI
            SELECT @RESTO = @TOTALFTRD % @CANTORI

            SELECT @BASEMOD = CONVERT(DECIMAL (14,2),CAST(@TOTALMOD AS decimal(14,2)) / @CANTORI)
            SELECT @RESTOMOD = CONVERT(DECIMAL (14,2),CAST(@TOTALMOD AS decimal(14,2)) % @CANTORI)

            ;WITH cte AS ( SELECT 1 AS n UNION ALL SELECT n + 1 FROM cte WHERE n + 1 <= @CANTORI )
            INSERT INTO @PROCEDIMIENTOS (codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
							   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
								,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador )
			   SELECT codPrestador,fechaInicioAtencion,idMIPRES,numAutorizacion,codProcedimiento,vialngresoServicioSalud
						   ,modalidadGrupoServicioTecSal,grupoServicios,codServicio,finalidadTecnologiaSalud,tipoDocumentoIdentificacion,numDocumentoIdentificacion
						   ,codDiagnosticoPrincipal,codDiagnosticoRelacionado,codComplicacion,
                     
                     CASE WHEN n <= @RESTO THEN @BASE + 1 ELSE @BASE END                    
                     ,tipoPagoModerador,
                     CASE WHEN n <= @RESTOMOD THEN CONVERT(VARCHAR(20), @BASEMOD + 1) ELSE CONVERT(VARCHAR(20), @BASEMOD) END
                     ,numFEVPagoModerador
			    FROM @PROCEDIMIENTOS1 X, cte
			    WHERE X.consecutivo=@CNSCONSULTA 
             OPTION (MAXRECURSION 0)

				FETCH NEXT FROM JSPROCE_CURSOR INTO  @CNSCONSULTA,@CANTORI, @TOTALFTRD, @TOTALMOD
			END
			CLOSE JSPROCE_CURSOR
			DEALLOCATE JSPROCE_CURSOR
		END
		IF 1=1
		BEGIN --AT
			INSERT INTO @OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
								,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
								,valorPagoModerador,numFEVPagoModerador)
			SELECT @IDPRESTADOR ,DBO.FNK_LIMPIATEXTO(COALESCE(HPRED.AUTORIZACION,HADM.NOAUTORIZACION,'null'),'A-Z0-9-'),null 
            , CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' THEN @fechaInicioAtencion
                   ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
              end
				, tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END --20250702 -- STORRES -- A A ESPERA QUE SE CREE EL CAMPO PARA CONFIGURAR
            , LEFT(IIF(RIPS_CP.IDCONCEPTORIPS=DBO.FNK_VALORVARIABLE('IDMATERIALESRIPS'), SER.IDSERVICIO, SER.CODCUPS),6),LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
				, CONVERT(INT,COALESCE(HPRED.CANTIDAD,1)),MED.TIPO_ID,MED.IDMEDICO
            , CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
            , CASE WHEN COALESCE(@PAQUETE,0) = 1 THEN 0 ELSE CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALOR*HPRED.CANTIDAD,0)) END --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0          
				,'04',CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALORCOPAGO,0)) ,COALESCE(@NFACTURA,@N_FACTURA)                                                                       
			FROM HADM 
				INNER JOIN HPRE ON HADM.NOADMISION=HPRE.NOADMISION
				INNER JOIN HPRED ON HPRE.NOPRESTACION=HPRED.NOPRESTACION
				INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
				INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
				LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'') END
			WHERE HADM.NOADMISION=@NOADMISION
				AND HPRED.N_FACTURA=@N_FACTURA
				AND COALESCE(HPRED.VALOR,0)>0
				AND COALESCE(HPRED.NOCOBRABLE,0)=0		
				AND COALESCE(HPRED.CANTIDAD,0)>0
				AND RIPS_CP.ARCHIVO='AT'  
		END

	END
	ELSE
	BEGIN
		RAISERROR ('No se encontr? la procedencia de la factura', 16, 1); 
		RETURN
	END

   DECLARE @VALORCOPAGOACU DECIMAL(14,4)
   DECLARE @VALORCOPAGOS DECIMAL(14,4)
   DECLARE @CONSE INT
   DECLARE @DIF DECIMAL(14,4)
   SELECT @VALORCOPAGOS =VALORCOPAGO FROM FTR WHERE N_fACTURA=@N_FACTURA
   SELECT @VALORCOPAGOACU=SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))) FROM @CONSULTAS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @PROCEDIMIENTOS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @MEDICAMENTOS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @OTROSSER
   SELECT @DIF=ABS(@VALORCOPAGOS-@VALORCOPAGOACU)
   PRINT '@VALORCOPAGOACU='+CONVERT(VARCHAR(20),@VALORCOPAGOACU)
   PRINT '@VALORCOPAGOS='+CONVERT(VARCHAR(20),@VALORCOPAGOS)
   PRINT '@DIFERENCIA='+CONVERT(VARCHAR(20),@DIF)

   IF @DIF <10
   BEGIN
      SELECT TOP 1 @CONSE=CONSECUTIVO FROM @CONSULTAS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
      if COALESCE(@CONSE,0)>0
      BEGIN
         UPDATE @CONSULTAS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE 
      END
      ELSE
      BEGIN
         SELECT TOP 1 @CONSE=CONSECUTIVO FROM @PROCEDIMIENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
         if COALESCE(@CONSE,0)>0
         BEGIN
            UPDATE @PROCEDIMIENTOS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE 
         END
         ELSE
         BEGIN
            SELECT TOP 1 @CONSE=CONSECUTIVO FROM @MEDICAMENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
            if COALESCE(@CONSE,0)>0
            BEGIN
               UPDATE @MEDICAMENTOS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE 
            END   
            ELSE
            BEGIN
               SELECT TOP 1 @CONSE=CONSECUTIVO FROM @OTROSSER WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
               if COALESCE(@CONSE,0)>0
               BEGIN
                  UPDATE @OTROSSER SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE 
               END  
            END
         END
      END
   END
   SELECT @VALORCOPAGOS=0,@VALORCOPAGOACU=0
   SELECT @VALORCOPAGOS =VALORSERVICIOS FROM FTR WHERE N_fACTURA=@N_FACTURA
   SELECT @VALORCOPAGOACU=SUM(CONVERT(BIGINT,CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,2)))) FROM @CONSULTAS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(BIGINT,CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,2)))),0) FROM @PROCEDIMIENTOS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(BIGINT,CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,2)))),0) FROM @MEDICAMENTOS
   SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(BIGINT,CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,2)))),0) FROM @OTROSSER
   PRINT '@SERVICOS='+CONVERT(VARCHAR(20),@VALORCOPAGOACU)
   PRINT '@VALORSERVICIOS='+CONVERT(VARCHAR(20),@VALORCOPAGOS)
   PRINT '@DIFERENCIA='+CONVERT(VARCHAR(20),ABS(@VALORCOPAGOS-@VALORCOPAGOACU))

   IF ABS(@VALORCOPAGOS-@VALORCOPAGOACU)<100
   BEGIN
      DECLARE @DIFE DECIMAL(14,2)=ABS(@VALORCOPAGOS-@VALORCOPAGOACU)
      PRINT @DIFE
      SET @CONSE=0
      SELECT TOP 1 @CONSE=CONSECUTIVO FROM @CONSULTAS WHERE CONVERT(DECIMAL(14,2),vrServicio)>0
      if COALESCE(@CONSE,0)>0
      BEGIN
		 PRINT 'INGRESO AL REDONDEO'
         UPDATE @CONSULTAS SET vrServicio=vrServicio+@DIFE   WHERE CONSECUTIVO=@CONSE 
      END
      ELSE
      BEGIN
         SELECT TOP 1 @CONSE=CONSECUTIVO FROM @PROCEDIMIENTOS WHERE CONVERT(DECIMAL(14,2),vrServicio)>0
         if COALESCE(@CONSE,0)>0
         BEGIN
            UPDATE @PROCEDIMIENTOS SET vrServicio=vrServicio+@DIFE   WHERE CONSECUTIVO=@CONSE 
         END
         ELSE
         BEGIN
            SELECT TOP 1 @CONSE=CONSECUTIVO FROM @MEDICAMENTOS WHERE CONVERT(DECIMAL(14,2),vrServicio)>0
            if COALESCE(@CONSE,0)>0
            BEGIN
               UPDATE @MEDICAMENTOS SET vrServicio=vrServicio+@DIFE  WHERE CONSECUTIVO=@CONSE 
            END   
            ELSE
            BEGIN
               SELECT TOP 1 @CONSE=CONSECUTIVO FROM @OTROSSER WHERE CONVERT(DECIMAL(14,2),vrServicio)>0
               if COALESCE(@CONSE,0)>0
               BEGIN
                  UPDATE @OTROSSER SET vrServicio=vrServicio+@DIFE   WHERE CONSECUTIVO=@CONSE 
               END  
            END
         END
      END
   END
   PRINT '@ESMODERADORAENFTR='+@ESMODERADORAENFTR
   PRINT '@CONCEPTORECAUDOICI='+@CONCEPTORECAUDOICI
   PRINT '@TIPOUSU='+@TIPOUSU
   PRINT '@conceptoRecaudo='+@conceptoRecaudo
	PRINT 'SALGO DE LOS AJUSTES'
	SELECT @CANT=COUNT(1) FROM @CONSULTAS
	IF @CANT>0 
	BEGIN
		SELECT @primerGrupo = 0		
		SET @PLANO += '"consultas":['
		SET @NRO=1
		WHILE @NRO<=@CANT
		BEGIN
			SELECT 
			 @codPrestador =	codPrestador
			,@fechaInicioAtencion =	fechaInicioAtencion
			,@numAutorizacion =	numAutorizacion
			,@codConsulta =	codConsulta
			,@modalidadGrupoServicioTecSal =	modalidadGrupoServicioTecSal
			,@grupoServicios =	grupoServicios
			,@codServicio =	codServicio
			,@finalidadTecnologiaSalud =	finalidadTecnologiaSalud
			,@causaMotivoAtencion =	causaMotivoAtencion
			,@codDiagnosticoPrincipal	 = IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4 ,	 'null', codDiagnosticoPrincipal )
			,@codDiagnosticoRelacionado1 = IIF(LEN(COALESCE(codDiagnosticoRelacionado1,''))<>4 , 'null', codDiagnosticoRelacionado1 )
			,@codDiagnosticoRelacionado2 = IIF(LEN(COALESCE(codDiagnosticoRelacionado2,''))<>4 , 'null', codDiagnosticoRelacionado2 )
			,@codDiagnosticoRelacionado3 = IIF(LEN(COALESCE(codDiagnosticoRelacionado3,''))<>4 , 'null', codDiagnosticoRelacionado3 )
			,@tipoDiagnosticoPrincipal   = IIF(LEN(tipoDiagnosticoPrincipal)<2,'01',COALESCE(tipoDiagnosticoPrincipal,'01') )
			,@vrServicio =	vrServicio
			,@tipoPagoModerador =	'04'
			,@valorPagoModerador =	valorPagoModerador
         ,@numFEVPagoModerador =  COALESCE(numFEVPagoModerador,'')
			,@consecutivo =	CAST(consecutivo AS VARCHAR(4))
			,@tipoDocumentoIdentificacion = tipoDocumentoIdentificacion 
			,@numDocumentoIdentificacion = numDocumentoIdentificacion 
			FROM @CONSULTAS
			WHERE consecutivo=@NRO

			IF @NRO>1 SET @PLANO += ','

			SET @PLANO+='{'
			SET @PLANO+='"codPrestador": "'+@codPrestador+'",'
			SET @PLANO+='"fechaInicioAtencion": "'+@fechaInicioAtencion+'",'         
			IF COALESCE(@numAutorizacion,'')<>''
				SET @PLANO+='"numAutorizacion": "'+@numAutorizacion+'",'
			SET @PLANO+='"codConsulta": "'+@codConsulta+'",'
			SET @PLANO+='"modalidadGrupoServicioTecSal": "'+@modalidadGrupoServicioTecSal+'",'
			SET @PLANO+='"grupoServicios": "'+@grupoServicios+'",'
			SET @PLANO+='"codServicio": '+@codServicio+','
			SET @PLANO+='"finalidadTecnologiaSalud": "'+@finalidadTecnologiaSalud+'",'
			SET @PLANO+='"causaMotivoAtencion": "'+@causaMotivoAtencion+'",'
			IF COALESCE(@codDiagnosticoPrincipal, '')<>''
				SET @PLANO+='"codDiagnosticoPrincipal": "'+@codDiagnosticoPrincipal+'",'
			IF COALESCE(@codDiagnosticoRelacionado1, '')<>''
				SET @PLANO+='"codDiagnosticoRelacionado1": "'+@codDiagnosticoRelacionado1+'",'
			IF COALESCE(@codDiagnosticoRelacionado2, '')<>''
				SET @PLANO+='"codDiagnosticoRelacionado2": "'+@codDiagnosticoRelacionado2+'",'
			IF COALESCE(@codDiagnosticoRelacionado3, '')<>''
				SET @PLANO+='"codDiagnosticoRelacionado3": "'+@codDiagnosticoRelacionado3+'",'
			SET @PLANO+= '"tipoDiagnosticoPrincipal": "'+@tipoDiagnosticoPrincipal+'",'
			SET @PLANO+= '"tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
			SET @PLANO+= '"numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
			SET @PLANO+='"vrServicio": '+CAST(@vrServicio AS VARCHAR)+','
			SET @PLANO+= '"conceptoRecaudo":"'+ 
             CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05' 
                  WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
                  WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN '03'  
                  ELSE @conceptoRecaudo 
             END +'",' --YCARRILLO
			SET @PLANO+='"valorPagoModerador":'+@valorPagoModerador+','
			--SET @PLANO+='"numFEVPagoModerador": "'+@N_FACTURA+'",'
         SET @PLANO+='"numFEVPagoModerador": "'+ CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' AND COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
			SET @PLANO+='"consecutivo": '+@consecutivo+''
			SET @PLANO+='}'
			SELECT @NRO+=1
		END		
		SET @PLANO  += ']'

      --PRINT 'DESPUES DE AC '+@PLANO
	END	
	SELECT @CANT=COUNT(1) FROM @MEDICAMENTOS
   PRINT '@CANT AP='+STR(@CANT)
	IF @CANT>0
	BEGIN
		IF @primerGrupo=1 SELECT @primerGrupo = 0
		ELSE SET @PLANO += ','
		SET @PLANO += '"medicamentos":['

		SET @NRO=1
		WHILE @NRO<=@CANT
		BEGIN
			SELECT @codPrestador=codPrestador
			--	,@numAutorizadon=numAutorizadon
				,@idMIPRES=idMIPRES
				,@fechaDispensAdmon=fechaDispensAdmon
                                ,@codDiagnosticoPrincipal=  IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4 ,	 'null', codDiagnosticoPrincipal ) 
				,@codDiagnosticoRelacionado= IIF(LEN(COALESCE(codDiagnosticoRelacionado,''))<>4 ,	 'null', codDiagnosticoRelacionado ) 
				,@tipoMedicamento=tipoMedicamento
				,@codTecnologiaSalud=codTecnologiaSalud
				,@nomTecnologiaSalud=nomTecnologiaSalud
				,@concentracionMedicamento=concentracionMedicamento
				,@unidadMedida=unidadMedida
				,@formaFarmaceutica=formaFarmaceutica
				,@unidadMinDispensa=unidadMinDispensa
				,@cantidadMedicamento=cantidadMedicamento
				,@diasTratamiento=diasTratamiento
				,@tipoDocumentoIdentificacion=tipoDocumentoIdentificacion
				,@numDocumentoIdentificacion=numDocumentoIdentificacion
				,@vrUnitMedicamento=vrUnitMedicamento
				,@vrServicio=vrServicio
				,@tipoPagoModerador=tipoPagoModerador
				,@valorPagoModerador=valorPagoModerador
				,@numFEVPagoModerador=COALESCE(numFEVPagoModerador,'')
				,@consecutivo=CONVERT(VARCHAR(5), @NRO)
			FROM @MEDICAMENTOS
			WHERE consecutivo=@NRO

			IF @unidadMedida IS NULL
			BEGIN
				RAISERROR ('La Unidad de Medida de los Medicamentos no puede ser null (IUNI.HOMOLOGO_RIPS)', 16, 1); 
				RETURN
			END

			SET @PLANO+='{'
			SET @PLANO+= '"codPrestador":"'+@codPrestador+'",'
			-- SERMUS89: norma vigente ? medicamentos ya no incluyen numAutorizacion en JSON RIPS
			--IF COALESCE(@numAutorizadon,'')<>''
			--	SET @PLANO+='"numAutorizacion": "'+@numAutorizadon+'",'
			SET @PLANO+=' "idMIPRES":'+IIF(coalesce(@idMIPRES,'')='' , 'null',CONCAT('"',@idMIPRES,'"'))+',' --STORRES 20250507 - Se cambia @idMIPRES is null por coalesce(@idMIPRES,'')='' 
			SET @PLANO+= '"fechaDispensAdmon":"'+@fechaDispensAdmon+'",'
			IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
				SET @PLANO+= '"codDiagnosticoPrincipal":"'+@codDiagnosticoPrincipal+'",'
			IF COALESCE(@codDiagnosticoRelacionado, '') <> ''
				SET @PLANO+= '"codDiagnosticoRelacionado":"'+@codDiagnosticoRelacionado+'",'
			SET @PLANO+= '"tipoMedicamento":"'+COALESCE(@tipoMedicamento,'')+'",'
			SET @PLANO+= '"codTecnologiaSalud":"'+COALESCE(@codTecnologiaSalud,'')+'",'
			SET @PLANO+= '"nomTecnologiaSalud":"'+COALESCE(@nomTecnologiaSalud,'')+'",'
			SET @PLANO+= '"concentracionMedicamento":'+COALESCE(@concentracionMedicamento,'')+','
			SET @PLANO+= '"unidadMedida":'+COALESCE(CAST(@unidadMedida AS VARCHAR),'null')+','
			SET @PLANO+= '"formaFarmaceutica":"'+COALESCE(@formaFarmaceutica,'')+'",'
			SET @PLANO+= '"unidadMinDispensa":'+COALESCE(@unidadMinDispensa,'')+','
			SET @PLANO+= '"cantidadMedicamento":'+COALESCE(@cantidadMedicamento,'')+','
			SET @PLANO+= '"diasTratamiento":'+@diasTratamiento+','
			SET @PLANO+= '"tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
			SET @PLANO+= '"numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
			SET @PLANO+= '"vrUnitMedicamento":'+@vrUnitMedicamento+','
			SET @PLANO+= '"vrServicio":'+CONVERT(VARCHAR,@vrServicio)+','
			SET @PLANO+= '"conceptoRecaudo":"'+ CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05'  ELSE  @conceptoRecaudo END +'",'
			SET @PLANO+= '"valorPagoModerador":'+LEFT(@valorPagoModerador,CHARINDEX('.',@valorPagoModerador,1)-1)+','
			--SET @PLANO+= '"numFEVPagoModerador":"'+@numFEVPagoModerador+'",'
         SET @PLANO+='"numFEVPagoModerador": "'+CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' AND COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
			SET @PLANO+= '"consecutivo":'+@consecutivo+''
			SET @PLANO+='},'
			SELECT @NRO+=1
		END		
		SET @PLANO  += ']'
      --PRINT 'DESPUES DE AM '+@PLANO
	END
	
	SELECT @CANT=COUNT(1) FROM @PROCEDIMIENTOS
	IF @CANT>0
	BEGIN
		IF @primerGrupo = 1 SELECT @primerGrupo = 0
		ELSE SET @PLANO += ','
		
		SET @PLANO += '"procedimientos":['
		
		SET @NRO=1
		WHILE @NRO<=@CANT
		BEGIN
			SELECT @codPrestador =	codPrestador,
				@fechaInicioAtencion =	fechaInicioAtencion,
				@idMIPRES =	idMIPRES,
				@numAutorizacion =	numAutorizacion,
				@codProcedimiento = codProcedimiento,
				@vialngresoServicioSalud =	vialngresoServicioSalud,
				@modalidadGrupoServicioTecSal =	modalidadGrupoServicioTecSal,
				@grupoServicios =	grupoServicios,
				@codServicio =	codServicio,
				@finalidadTecnologiaSalud =	finalidadTecnologiaSalud,
				@tipoDocumentoIdentificacion =	tipoDocumentoIdentificacion,
				@numDocumentoIdentificacion =	numDocumentoIdentificacion,
				@codDiagnosticoPrincipal =	codDiagnosticoPrincipal,
				@codDiagnosticoRelacionado =	codDiagnosticoRelacionado,
				@codComplicacion =	codComplicacion,
				@vrServicio =	vrServicio,
				@tipoPagoModerador	=tipoPagoModerador,
				@valorPagoModerador = 	valorPagoModerador,
				@numFEVPagoModerador =	COALESCE(numFEVPagoModerador,''),
				@consecutivo =	CAST(consecutivo AS VARCHAR(4))
			FROM @PROCEDIMIENTOS
			WHERE consecutivo=@NRO
			
			IF @NRO > 1 SET @PLANO+=','

			SET @PLANO+='{'
			SET @PLANO+=' "codPrestador":"'+@codPrestador+'",'
			SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencion+'",'
			SET @PLANO+=' "idMIPRES":'+IIF(coalesce(@idMIPRES,'')='' , 'null',CONCAT('"',@idMIPRES,'"'))+',' --STORRES 20250507 - Se cambia @idMIPRES is null por coalesce(@idMIPRES,'')='' 
			IF COALESCE(@numAutorizacion,'')<>''
				SET @PLANO+=' "numAutorizacion":"'+@numAutorizacion+'",'
      --   PRINT @PLANO
			SET @PLANO+=' "codProcedimiento":"'+@codProcedimiento+'",'
			SET @PLANO+=' "viaIngresoServicioSalud":"'+@vialngresoServicioSalud+'",'
			SET @PLANO+=' "modalidadGrupoServicioTecSal":"'+@modalidadGrupoServicioTecSal+'",'
			SET @PLANO+=' "grupoServicios":"'+@grupoServicios+'",'
			SET @PLANO+=' "codServicio":'+@codServicio+','
			SET @PLANO+=' "finalidadTecnologiaSalud":"'+@finalidadTecnologiaSalud+'",'
			SET @PLANO+=' "tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
      --   PRINT @PLANO
			SET @PLANO+=' "numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
			SET @PLANO+=' "codDiagnosticoPrincipal":"'+ISNULL( NULLIF(@codDiagnosticoPrincipal,''), 'null')+'",'
			SET @PLANO+=' "codDiagnosticoRelacionado":"'+ISNULL( NULLIF(@codDiagnosticoRelacionado,''), 'null')+'",'
			SET @PLANO+=' "codComplicacion":"'+ISNULL( NULLIF(@codComplicacion,''), 'null')+'",'
			SET @PLANO+=' "vrServicio":'+CAST(CONVERT(INT,@vrServicio) AS VARCHAR)+','
     --    PRINT @PLANO
			SET @PLANO+= '"conceptoRecaudo":"'
               --+ CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05'  ELSE  @conceptoRecaudo END +'",'
               +CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05' 
                     WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
                     ELSE @conceptoRecaudo 
                END +'",' --YCARRILLO


        -- PRINT @PLANO
			SET @PLANO+=' "valorPagoModerador":'+LEFT(@valorPagoModerador,CHARINDEX('.',@valorPagoModerador,1)-1)+','
			--SET @PLANO+=' "numFEVPagoModerador":"'+@numFEVPagoModerador+'",'
         SET @PLANO+='"numFEVPagoModerador": "'+ CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' OR COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
			SET @PLANO+=' "consecutivo":'+@consecutivo+''
			SET @PLANO+=' }'
			SELECT @NRO+=1
		END
		
		SET @PLANO  += ']'
	--	PRINT 'DESPUES DE AP '+@PLANO
	END

	SELECT @CANT=COUNT(1) FROM @OTROSSER
	IF @CANT>0
	BEGIN
		IF @primerGrupo = 1 SELECT @primerGrupo = 0
		ELSE SET @PLANO += ','

		SET @PLANO += '"otrosServicios":['

		SET @NRO=1
		WHILE @NRO<=@CANT
		BEGIN
			SELECT @codPrestador=codPrestador,
				@numAutorizacion=numAutorizacion,
				@idMIPRES=idMIPRES,
				@fechaSuministroTecnologia=fechaSuministroTecnologia,
				@tipoOS=tipoOS,
				@codTecnologiaSalud=codTecnologiaSalud,
				@nomTecnologiaSalud=nomTecnologiaSalud,
				@cantidadOS=cantidadOS,
				@tipoDocumentoIdentificacion=tipoDocumentoIdentificacion,
				@numDocumentoIdentificacion=numDocumentoIdentificacion,
				@vrUnitOS=vrUnitOS,
				@vrServicio=vrServicio,
				@tipoPagoModerador=tipoPagoModerador,
				@valorPagoModerador=valorPagoModerador,
				@numFEVPagoModerador=COALESCE(numFEVPagoModerador,''),
				@consecutivo= CAST(consecutivo AS VARCHAR(5))
			FROM @OTROSSER
			WHERE consecutivo=@NRO

			IF @NRO > 1 SET @PLANO+=','

			SET @PLANO+='{ '
			SET @PLANO+= '"codPrestador":"'+@codPrestador+'",'
			IF COALESCE(@numAutorizacion,'')<>''
				SET @PLANO+= '"numAutorizacion":"'+@numAutorizacion+'",'
			SET @PLANO+=' "idMIPRES":'+IIF(coalesce(@idMIPRES,'')='' , 'null',CONCAT('"',@idMIPRES,'"'))+',' --STORRES 20250507 - Se agrega campo que debe ir oblgatorio segun resolucion 
			SET @PLANO+= '"fechaSuministroTecnologia":"'+@fechaSuministroTecnologia+'",'
			SET @PLANO+= '"tipoOS":"'+@tipoOS+'",'
			SET @PLANO+= '"codTecnologiaSalud":"'+COALESCE(DBO.FNK_LIMPIATEXTO(@codTecnologiaSalud,'0-9- _ A-Z'),'')+'",'
			SET @PLANO+= '"nomTecnologiaSalud":"'+@nomTecnologiaSalud+'",'
			SET @PLANO+= '"cantidadOS":'+CAST(@cantidadOS AS VARCHAR)+','
			SET @PLANO+= '"tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
			SET @PLANO+= '"numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
			SET @PLANO+= '"vrUnitOS":'+CAST(@vrUnitOS AS VARCHAR)+','
			SET @PLANO+= '"vrServicio":'+CAST(@vrServicio AS VARCHAR)+','
			SET @PLANO+= '"conceptoRecaudo":"'+ CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05'  ELSE  @conceptoRecaudo END +'",'
			SET @PLANO+= '"valorPagoModerador":'+LEFT(@valorPagoModerador,CHARINDEX('.',@valorPagoModerador,1)-1)+','
			--SET @PLANO+= '"numFEVPagoModerador":"'+@numFEVPagoModerador+'",'
         SET @PLANO+='"numFEVPagoModerador": "'+ CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' AND COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
			SET @PLANO+= '"consecutivo":'+@consecutivo+''
			SET @PLANO+='}'
			SELECT @NRO+=1
		END	
		SET @PLANO += ']'
	--	PRINT 'DESPUES DE AT '+@PLANO
	END
	IF @PROCEDENCIA='SALUD'
	BEGIN
		BEGIN --AU
         print '@fechaInicioAtencion=' +@fechaInicioAtencion 
         print '@fechaEgreso='+@fechaEgreso
			IF EXISTS(SELECT 1 FROM HADM WHERE NOADMISION=@NOADMISION AND DATEDIFF(HOUR,FECHA,FECHAALTAMED)<=48 
					    AND EXISTS (SELECT 1 FROM TGEN WHERE TGEN.CODIGO = HADM.TIPOESTANCIA AND TGEN.CAMPO =  'CLASEHOSP'   AND  TGEN.DATO1 = 'U' AND TABLA = 'General')
					   ) AND @PROCEDENCIA='SALUD' AND DBO.FNK_VALORVARIABLE ('MODO_ASISTENCIAL') = 'Normal'  --STORRES 20250310
			BEGIN
				SELECT @codPrestador=@IDPRESTADOR, 
					@causaMotivoAtencion=CASE WHEN COALESCE(TGEN.CHECK1,0)=1 AND COALESCE(DATO1,'')<>'' THEN DATO1 ELSE CODIGO END,
					@codDiagnosticoPrincipal=COALESCE(HCA.IDDX,HADM.DXINGRESO,'null'),
					@codDiagnosticoPrincipalE=COALESCE(HADM.DXEGRESO,HCA.DX1,COALESCE(HCA.IDDX,HADM.DXINGRESO,'null')),
					@codDiagnosticoRelacionadoE1=COALESCE(HCA.DX1,HADM.DXSALIDA1,'null'),
					@codDiagnosticoRelacionadoE2=COALESCE(HCA.DX2,HADM.DXSALIDA2,'null'),
					@codDiagnosticoRelacionadoE3=COALESCE(HCA.DX3,HADM.DXSALIDA3,'null'),
					@condicionDestinoUsuarioEgreso=CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END,
					@codDiagnosticoCausaMuerte=CASE WHEN HADM.ESTADOPSALIDA=1 THEN null ELSE CAUSABMUERTE END,
					@consecutivo=1
				FROM HADM 
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3 
							FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
					LEFT JOIN TGEN ON HADM.CAUSAEXTERNA=TGEN.CODIGO AND TGEN.TABLA='General' AND TGEN.CAMPO='CAUSAEXTERNA'
				WHERE HADM.NOADMISION=@NOADMISION
				
				IF @primerGrupo = 1 SELECT @primerGrupo = 0
				ELSE SET @PLANO += ','
				SET @PLANO += '"urgencias":['
				SET @PLANO+='{'
				SET @PLANO+=' "codPrestador":"'+@codPrestador+'",'
				SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencion+'",'
				SET @PLANO+=' "causaMotivoAtencion":"'+@causaMotivoAtencion+'",'
				IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
					SET @PLANO+=' "codDiagnosticoPrincipal":"'+UPPER (@codDiagnosticoPrincipal)+'",'
				IF COALESCE(@codDiagnosticoPrincipalE, '') <> ''
					SET @PLANO+=' "codDiagnosticoPrincipalE":"'+UPPER(@codDiagnosticoPrincipalE)+'",'
				--IF COALESCE(@codDiagnosticoRelacionadoE1, '') <> ''-- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE1":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE1,''))<>4 , 'null', @codDiagnosticoRelacionadoE1 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				--IF COALESCE(@codDiagnosticoRelacionadoE2, '') <> ''-- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE2":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE2,''))<>4 , 'null', @codDiagnosticoRelacionadoE2 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				--IF COALESCE(@codDiagnosticoRelacionadoE3, '') <> ''-- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE3":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE3,''))<>4 , 'null', @codDiagnosticoRelacionadoE3 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				SET @PLANO+=' "condicionDestinoUsuarioEgreso":"'+@condicionDestinoUsuarioEgreso+'",'
				SET @PLANO+=' "codDiagnosticoCausaMuerte":"'+COALESCE(@codDiagnosticoCausaMuerte,'null')+'",'
				SET @PLANO+=' "fechaEgreso":"'+@fechaEgreso+'",'
				SET @PLANO+=' "consecutivo":'+CAST(@consecutivo AS VARCHAR(4))
				SET @PLANO+='}]'
			END
         --PRINT 'DESPUES DE AU '+COALESCE(@PLANO,'NADA DE NADA')
		END
		BEGIN --AH
			IF EXISTS(SELECT 1 FROM HADM WHERE NOADMISION=@NOADMISION AND DATEDIFF(HOUR,FECHA,FECHAALTAMED)>48) 
                 AND @PROCEDENCIA='SALUD' AND DBO.FNK_VALORVARIABLE ('MODO_ASISTENCIAL') = 'Normal'  --STORRES 20250310
			BEGIN
				SELECT @codPrestador=@IDPRESTADOR
					,@viaIngresoServicioSalud=COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'01') 
					,@numAutorizacion=DBO.FNK_LIMPIATEXTO(COALESCE(HADM.NOAUTORIZACION,'null'),'A-Z0-9-')
					,@causaMotivoAtencion=COALESCE(REPLACE(TGEN2.DATO1,' ',''),HADM.CAUSAEXTERNA,'38')
					,@codDiagnosticoPrincipal=COALESCE(HCA.IDDX,HADM.DXINGRESO)
					,@codDiagnosticoPrincipalE=COALESCE(HADM.DXEGRESO,HCA.DX1)
					,@codDiagnosticoRelacionadoE1=COALESCE(HCA.DX1,HADM.DXSALIDA1)
					,@codDiagnosticoRelacionadoE2=COALESCE(HCA.DX2,HADM.DXSALIDA2)
					,@codDiagnosticoRelacionadoE3=COALESCE(HCA.DX3,HADM.DXSALIDA3)
					,@codComplicacion=COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO)
					,@condicionDestinoUsuarioEgreso=CASE WHEN HADM.ESTADOPSALIDA=1 THEN '01' ELSE '02' END
					,@codDiagnosticoCausaMuerte=CASE WHEN HADM.ESTADOPSALIDA=1 THEN 'null' ELSE CAUSABMUERTE END
					,@consecutivo=1
				FROM HADM 
					LEFT JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO' 
					LEFT JOIN TGEN TGEN2 ON HADM.CAUSAEXTERNA = TGEN2.CODIGO AND TGEN2.TABLA = 'General' AND TGEN2.CAMPO = 'CAUSAEXTERNA'
					LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3 
							FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>'' 
							AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
							ORDER BY HCA.FECHA DESC 
							) HCA ON HADM.NOADMISION=HCA.NOADMISION
				WHERE HADM.NOADMISION=@NOADMISION
				
				IF @primerGrupo = 1 SELECT @primerGrupo = 0
				ELSE SET @PLANO += ','
				SET @PLANO += '"hospitalizacion":['
				SET @PLANO+='{ '
				SET @PLANO+=' "codPrestador":"'+@codPrestador+'",'
				SET @PLANO+=' "viaIngresoServicioSalud":"'+LTRIM(RTRIM(@viaIngresoServicioSalud))+'",'
				SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencion+'",'
				IF COALESCE(@numAutorizacion,'')<>''
					SET @PLANO+=' "numAutorizacion":"'+@numAutorizacion+'",'
				SET @PLANO+=' "causaMotivoAtencion":"'+@causaMotivoAtencion+'",'
				IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
					SET @PLANO+=' "codDiagnosticoPrincipal":"'+UPPER (@codDiagnosticoPrincipal)+'",'
				IF COALESCE(@codDiagnosticoPrincipalE, '') <> ''
					SET @PLANO+=' "codDiagnosticoPrincipalE":"'+UPPER(@codDiagnosticoPrincipalE)+'",'
				--IF COALESCE(@codDiagnosticoRelacionadoE1, '') <> '' -- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE1":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE1,''))<>4 , 'null', @codDiagnosticoRelacionadoE1 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				--IF COALESCE(@codDiagnosticoRelacionadoE2, '') <> '' -- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE2":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE2,''))<>4 , 'null', @codDiagnosticoRelacionadoE2 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				--IF COALESCE(@codDiagnosticoRelacionadoE3, '') <> '' -- STORRES 20250507 - Se elimina condision ya que que debe enviar siempre informacion en el campo
					SET @PLANO+=' "codDiagnosticoRelacionadoE3":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE3,''))<>4 , 'null', @codDiagnosticoRelacionadoE3 )+'",' -- STORRES 20250507 - Se agrega condicionespar amandar NULL en caso de no encontrar un codigo cie10 o codigo errado. Para agregar NULL
				SET @PLANO+=' "codComplicacion":"'+COALESCE(@codComplicacion,'')+'",'
				SET @PLANO+=' "condicionDestinoUsuarioEgreso":"'+@condicionDestinoUsuarioEgreso+'",'
				SET @PLANO+=' "codDiagnosticoCausaMuerte":"'+COALESCE(@codDiagnosticoCausaMuerte,'null')+'",'
				SET @PLANO+=' "fechaEgreso":"'+@fechaEgreso+'",'
				SET @PLANO+=' "consecutivo":'+CAST(@consecutivo AS VARCHAR(4))+''
				SET @PLANO+='}]'
			END
         --PRINT 'DESPUES DE AH '+COALESCE(@PLANO,'NADA DE NADA')
		END
		BEGIN --RECIEN NACIDO
			SELECT @RECIEN = DBO.FNK_RIPS_JSON_RECIENNACIDOS(@NOADMISION,@N_FACTURA,@PROCEDENCIA,@TIPODOC,@DOCIDAFILIADO,@IDTERINSTA)			
			IF LEN(@RECIEN)>0
			BEGIN
		PRINT '@RECIEN'
		PRINT @RECIEN
				IF @primerGrupo = 1 SELECT @primerGrupo = 0
				ELSE SET @PLANO += ','

				SET @PLANO += '"recienNacidos":['
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
   
	SELECT @PLANO = '{"rips": '+@PLANO+',"xmlFevFile": "@XMLFEVFILE"}'

 --   IF @N_FACTURA = 'SWJ14419'
	--BEGIN
	--	SELECT 'VIENE AQUI ABAJO'
 --     SELECT @PLANO
	--	SELECT 'VIENE AQUI ARRIBA'
	--END
	IF 1=1
	BEGIN
		select @base64 = cast('' as xml).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
		from (
			select [binaryValue] = cast(dbo.FNK_AttachedDocument(@CNSFCT,'FV') as varbinary(max))
		) as conv;
		SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE',@base64)
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
		SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE',@base64)
	END
	IF COALESCE(@URL_PATH,'')<>''
	BEGIN
		SELECT @N_FACTURA=@N_FACTURA+'.json'
		EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
		SELECT @PLANO= @URL_PATH+IIF(RIGHT(@URL_PATH,1)='\','','\')+@N_FACTURA 
	END

	PRINT 'FINALIZO EN SPK_RIPS_JSON_AJUSTE_IND'
END

