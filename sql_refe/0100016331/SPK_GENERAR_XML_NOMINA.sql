CREATE OR ALTER PROCEDURE DBO.SPK_GENERAR_XML_NOMINA @CNSNIEPEG INT, @PATH_URL VARCHAR(MAX) = NULL, @NOMBRE_XML NVARCHAR(1000) OUTPUT, @AMBIENTE INT OUTPUT, @TESTSETID VARCHAR(
		100) OUTPUT
	WITH ENCRYPTION
AS
-- Declaración de variables
DECLARE @BASE_IVA_SERVICIOS VARCHAR(20)
DECLARE @XML AS NVARCHAR(MAX) = ''
DECLARE @FechaGen VARCHAR(10), @FechaNIEPE DATETIME, @HoraGen VARCHAR(20), @FechaLiquidacionInicio VARCHAR(10) --,@Ambiente INT = 2
	, @FechaLiquidacionFin VARCHAR(10), @FechaIngreso VARCHAR(10), @FechaRetiro VARCHAR(10), @TiempoLaborado INT, @Consecutivo INT, @Prefijo VARCHAR(10), @Pais 
	VARCHAR(20), @DepartamentoEstado VARCHAR(3), @Idioma VARCHAR(2) = 'es', @MunicipioCiudad VARCHAR(10), @RazonSocial VARCHAR(120), @NIT VARCHAR(20), @DV VARCHAR(1
	), @SoftwareID VARCHAR(256), @SoftwarePIN VARCHAR(10), @SoftwareSC VARCHAR(256) -- Software Code
	, @CUNE VARCHAR(256), @TipoXML VARCHAR(3) = '102'
	-- 102.- (NominaIndividual) Documento Soporte de Pago de Nómina Electrónica, 103.- (NominaIndividualDeAjuste) Nota de Ajuste de Documento Soporte de Pago de Nómina Electrónica
	, @PeriodoNomina SMALLINT, @MSJERROR VARCHAR(MAX), @CNSPAGO VARCHAR(20), @Direccion VARCHAR(512), @AltoRiesgoPension BIT = 0, @TipoTrabajador VARCHAR(2), 
	@TipoContrato INT, @SubTipoTrabajador VARCHAR(2), @PNombre VARCHAR(50), @SNombre VARCHAR(50), @PApellido VARCHAR(50), @SApellido VARCHAR(50), @TipoDocumento 
	VARCHAR(2), @NumeroDocumento VARCHAR(20), @SalarioIntegral BIT = 0, @IDCONTRATO VARCHAR(20), @Sueldo DECIMAL(14, 2), @MetodoPago INT, @Banco VARCHAR(50), 
	@TipoCuenta VARCHAR(100) = 'Ahorros', @NroCuenta VARCHAR(50), @DiasTrabajados INT, @HORAS_EXTRAS INT, @CODCONCEPTO_HE VARCHAR(20), @FINI_HE DATETIME, @FFIN_HE 
	DATETIME, @VRTOTAL_HE DECIMAL(14, 2), @CODCARGO VARCHAR(20), @HORAS_DIA_LAB INT, @DIAS_MES_LAB INT, @SUM_HORAS_NEDIA INT, @HORAS_NIEPED INT, @HORAS_NEDIA INT, 
	@FECHAINI_NEDIA DATETIME, @FECHAFIN_NEDIA DATETIME, @PAGO_NEDIA DECIMAL(14, 2), @CODCONCEPTO_NEDIA VARCHAR(20), @NOMBRE_CONCEPTO VARCHAR(100), 
	@TOTAL_NOMINA_NIEPED DECIMAL(14, 2), @ID_DIAN VARCHAR(20), @VALOR_NETO DECIMAL(14, 2), @VALOR_INGRESOS DECIMAL(14, 2), @VALOR_EGRESOS DECIMAL(14, 2), @NUMDOC 
	VARCHAR(50), @PERIODO VARCHAR(6), @MONTO DECIMAL(14, 2), @CNSNIEPEG_PREDECESOR INT, @CUNE_PREDECESOR VARCHAR(500), @FECHA_PREDECESOR DATETIME, @TIPONOTA 
	TINYINT = 0, @VERSION VARCHAR(200)
DECLARE @CUR_CNSPAGO VARCHAR(20);-- Variable temporal para el cursor DE RECARGOS

BEGIN
	BEGIN TRY
		--SET @XML='<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
		-- Validar que los conceptos en la nómina estén homologados a los del anexo técnico
		DECLARE @CODCONCEPTO VARCHAR(100), @DESCRIPCIONCONCEPTO VARCHAR(256)

		SELECT @PERIODO = CONSECUTIVO, @NUMDOC = NUMDOC, @CNSNIEPEG_PREDECESOR = CNSNIEPEG_BASE, @TIPONOTA = TIPONOTA
		FROM NIEPEG
		WHERE CNSNIEPEG = @CNSNIEPEG

		SELECT TOP 1 @CODCONCEPTO = CODCONCEPTO, @DESCRIPCIONCONCEPTO = DESCRIPCION
		FROM DBO.VWK_NIEPED
		WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND COALESCE(ID_DIAN, '') NOT IN (
				SELECT CODIGO
				FROM TGEN
				WHERE TABLA = 'FDIAN' AND CAMPO = 'CONCEPTOSNOMINA'
				)

		IF @CODCONCEPTO IS NOT NULL
		BEGIN
			SET @MSJERROR = 'Concepto [CODCONCEPTO: ' + @CODCONCEPTO + '] ' + @DESCRIPCIONCONCEPTO + ' no está clasificado según el anexo técnico'

			RAISERROR (@MSJERROR, 16, 1);
		END

		BEGIN -- Datos del Software
			SELECT @SoftwareID = DESCRIPCION
			FROM TGEN
			WHERE TABLA = 'FDIAN' AND CAMPO = 'SOFTWARE_NOMINA' AND CODIGO = 'ID'

			SELECT @SoftwarePIN = DESCRIPCION
			FROM TGEN
			WHERE TABLA = 'FDIAN' AND CAMPO = 'SOFTWARE_NOMINA' AND CODIGO = 'PIN'

			SELECT @TESTSETID = COALESCE(DESCRIPCION, '')
			FROM TGEN
			WHERE TABLA = 'FDIAN' AND CAMPO = 'SOFTWARE_NOMINA' AND CODIGO = 'TESTSETID'

			--SELECT @Ambiente = CASE WHEN COALESCE(DESCRIPCION,'')<>'' THEN 2 ELSE 1 END FROM TGEN WHERE TABLA='FDIAN' AND CAMPO='SOFTWARE_NOMINA' AND CODIGO='TESTSETID'
			SELECT @PREFIJO = COALESCE(PREFIJO, '') --, @CLAVE_TECNICA=dbo.FNK_LIMPIATEXTO(CLAVETECNICA,'A-Z0-9')
				, @AMBIENTE = AMBIENTE
			FROM FDIAN
			WHERE COALESCE(VENCIDA, 0) = 0 AND COALESCE(FTRELECTRONICA, 0) = 1

			IF @PREFIJO IS NULL
			BEGIN
				RAISERROR ('No hay resolución de facturación electrónica disponible', 16, 1);
			END

			IF @AMBIENTE = 2 AND COALESCE(@TESTSETID, '') = ''
				RAISERROR (
						'El identificador de pruebas (TestSetId) es obligatorio en el ambiente de pruebas. (TGEN => ''FDIAN'', ''SOFTWARE_NOMINA'', ''TESTSETID'')'
						, 16, 1
						);
		END

		SELECT @Prefijo = CASE 
				WHEN COALESCE(PREFIJO, '') = ''
					THEN @PREFIJO
				ELSE PREFIJO
				END
		FROM NIEPEG
		WHERE CNSNIEPEG = @CNSNIEPEG

		IF COALESCE(@PREFIJO, '') = '' OR ISNUMERIC(LEFT(@PREFIJO, 1)) = 1
		BEGIN
			SET @PREFIJO = 'NE'
		END

		IF @CNSNIEPEG_PREDECESOR IS NOT NULL
		BEGIN --NumeroPred
			SELECT @CUNE_PREDECESOR = CUNE, @FECHA_PREDECESOR = FECHA
			FROM NIEPEG
			WHERE CNSNIEPEG = @CNSNIEPEG_PREDECESOR

			IF COALESCE(@TIPONOTA, 0) < 0
				RAISERROR ('El tipo de nota debe tener un valor mayor a Cero (0)', 16, 1);
		END

		SELECT @MunicipioCiudad = CASE 
				WHEN COALESCE(CIU.HOMOLOGODIAN, '') = ''
					THEN CIU.CIUDAD
				ELSE CIU.HOMOLOGODIAN
				END, @DepartamentoEstado = COALESCE(DEP.COD_DIAN, DEP.DPTO), @Pais = PAIS.CODISO, @RazonSocial = DBO.FNK_LIMPIATEXTO(TER.RAZONSOCIAL, 
				'A-Z0-9 .,-_/'), @NIT = DBO.FNK_LIMPIATEXTO(NIT, '0-9A-Z'), @DV = DV, @Direccion = DBO.FNK_LIMPIATEXTO(TER.DIRECCION, 'A-Z0-9 .,-_/')
		FROM TER
		INNER JOIN CIU ON CIU.CIUDAD = TER.CIUDAD
		INNER JOIN DEP ON DEP.DPTO = CIU.DPTO
		INNER JOIN PAIS ON PAIS.IDPAIS = DEP.PAIS
		WHERE IDTERCERO = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')

		BEGIN -- NombreXML
			DECLARE @PREFIJO_USCXS VARCHAR(20), @CANTIARCHENV INT

			SET @PREFIJO_USCXS = '@FDIAN' + CAST(YEAR(GETDATE()) AS VARCHAR)

			SELECT @CANTIARCHENV = CONSECUTIVO
			FROM USCXS
			WHERE COMPANIA = '01' AND IDSEDE = '01' AND PREFIJO = @PREFIJO_USCXS

			IF COALESCE(@CANTIARCHENV, 0) < 1
				SET @CANTIARCHENV = 0
			SET @CANTIARCHENV += 1
			SET @NOMBRE_XML = 'nie'
			SET @NOMBRE_XML += RIGHT('0000000000' + @NIT, 10)
			SET @NOMBRE_XML += CAST(RIGHT(YEAR(GETDATE()), 2) AS VARCHAR)
			SET @NOMBRE_XML += RIGHT('00000000' + CAST(@CANTIARCHENV AS VARCHAR), 8)
			SET @NOMBRE_XML += '.xml'
		END

		SELECT @FechaNIEPE = FECHA, @HoraGen = CONVERT(VARCHAR, FECHA, 108) + '-05:00', @FechaGen = REPLACE(CONVERT(VARCHAR, FECHA, 102), '.', '-'), 
			@FechaLiquidacionInicio = REPLACE(CONVERT(VARCHAR, FECHAINI, 102), '.', '-'), @FechaLiquidacionFin = REPLACE(CONVERT(VARCHAR, FECHAFIN, 102), '.', '-')
			, @Consecutivo = @CNSNIEPEG, @PeriodoNomina = 5 --NPPAG.CODPERIODO
			, @CNSPAGO = PROV.CNSPAGO, @VALOR_NETO = VALOR_NETO + COALESCE(PROV.VALORPROV, 0), @VALOR_INGRESOS = VALOR_INGRESOS + COALESCE(PROV.VALORPROV, 0), 
			@VALOR_EGRESOS = VALOR_EGRESOS
		FROM DBO.VWK_NIEPE
		LEFT JOIN (
			SELECT CONCAT (A.ANO, A.MES) CONSECUTIVO, A.NUMDOC, A.CNSPAGO, A.CNSNIEPE, SUM(COALESCE(B.VALOR_APORTES, 0)) VALORPROV
			FROM NIEPE AS A
			INNER JOIN NIEPED AS B ON B.CNSNIEPE = A.CNSNIEPE AND A.NUMDOC = B.NUMDOC --AND ISNULL(B.VALOR,0)>0 OR COALESCE(B.VALOR_APORTES,0)>0
			INNER JOIN NCON ON NCON.CODCONCEPTO = B.CODCONCEPTO
			INNER JOIN TGEN ON TGEN.TABLA = 'FDIAN' AND TGEN.CAMPO = 'CONCEPTOSNOMINA' AND TGEN.CODIGO = NCON.ID_DIAN
			INNER JOIN NOMI ON NOMI.CODNOMINA = A.CODNOMINA AND ISNULL(NOMI.REPORTA, 0) = 1
			WHERE CONCAT (A.ANO, A.MES) = @PERIODO AND A.NUMDOC = @NUMDOC AND TGEN.CODIGO IN ('Cesantia', 'PrimaS', 'InteresesCesantias', 'VacacionesComunes'
					) AND NCON.CLASE = 'Provision'
			GROUP BY CONCAT (A.ANO, A.MES), A.NUMDOC, A.CNSPAGO, A.CNSNIEPE
			) PROV ON PROV.NUMDOC = DBO.VWK_NIEPE.NUMDOC AND PROV.CONSECUTIVO = VWK_NIEPE.CONSECUTIVO
		--20230912 left join de jhon alexander para que en ingresos y egresos incluya las provisiones mensuales
		WHERE VWK_NIEPE.CONSECUTIVO = @PERIODO AND VWK_NIEPE.NUMDOC = @NUMDOC

		SELECT
			-- @FechaIngreso = CASE WHEN FECHAINGRESO BETWEEN CONVERT(DATE,@FechaLiquidacionInicio) AND CONVERT(DATE,@FechaLiquidacionFin) THEN COALESCE(REPLACE(CONVERT(DATE,FECHAINGRESO,102),'.','-'),'') ELSE '' END
			@FechaIngreso = COALESCE(REPLACE(CONVERT(DATE, FECHAINGRESO, 102), '.', '-'), ''), @FechaRetiro = CASE 
				WHEN FECHARETIRO BETWEEN CONVERT(DATE, @FechaLiquidacionInicio) AND CONVERT(DATE, @FechaLiquidacionFin)
					THEN COALESCE(REPLACE(CONVERT(DATE, FECHARETIRO, 102), '.', '-'), '')
				ELSE ''
				END, @TiempoLaborado = CASE 
				WHEN DATEDIFF(DAY, FECHAINGRESO, COALESCE(FECHARETIRO, GETDATE())) <= 0
					THEN 1
				ELSE DATEDIFF(DAY, FECHAINGRESO, COALESCE(FECHARETIRO, GETDATE()))
				END, @AltoRiesgoPension = COALESCE(n.ALTORIESGO, 0), @TipoTrabajador = n1.HOMOLOGODIAN, @SubTipoTrabajador = CASE 
				WHEN SUBTIPOCOTIZANTE = 0
					THEN '00'
				ELSE '01'
				END, @PApellido = DBO.FNK_LIMPIATEXTO(PRIMERAPELLIDO, ''), @SApellido = DBO.FNK_LIMPIATEXTO(SEGUNDOAPELLIDO, ''), @PNombre = DBO.FNK_LIMPIATEXTO(
				PRIMERNOMBRE, ''), @SNombre = DBO.FNK_LIMPIATEXTO(SEGUNDONOMBRE, ''), @TipoDocumento = (
				SELECT TOP 1 DATO1
				FROM TGEN
				WHERE TABLA = 'GENERAL' AND CAMPO = 'TIPOIDENT' AND CODIGO = NEMP.TIPO_DOC
				), @NumeroDocumento = dbo.FNK_LIMPIATEXTO(DOCIDEMPLEADO, '0-9'), @Sueldo = NEMP.BASICO, @MetodoPago = CASE NEMP.FORMADEPAGO
				WHEN 'Consignacion'
					THEN 42
				WHEN 'Cheque'
					THEN 20
				WHEN 'Efectivo'
					THEN 10
				WHEN 'Bonos'
					THEN 71
				ELSE 10
				END, @Banco = CASE 
				WHEN NEMP.FORMADEPAGO <> 'Efectivo'
					THEN b.DESCRIPCION
				ELSE ''
				END, @TipoCuenta = CASE 
				WHEN NEMP.FORMADEPAGO <> 'Efectivo'
					THEN @TipoCuenta
				ELSE ''
				END, @NroCuenta = CASE 
				WHEN NEMP.FORMADEPAGO <> 'Efectivo'
					THEN DBO.FNK_LIMPIATEXTO(NEMP.CTA_BCO, 'A-Z0-9 .,-_/')
				ELSE ''
				END, @CODCARGO = NEMP.CODCARGO
		FROM NEMP
		LEFT JOIN NCAR n ON n.CODCARGO = NEMP.CODCARGO
		LEFT JOIN NFUTC n1 ON NEMP.TIPOCOTIZANTE = n1.TIPOCOTIZANTE
		LEFT JOIN BCO b ON NEMP.BANCO = b.BANCO
		WHERE NUMDOC = @NUMDOC

		DECLARE @HORASXDIA DECIMAL(14, 2)

		SELECT TOP 1 @HORAS_DIA_LAB = n.HORASDELABOR, @DIAS_MES_LAB = n.DIAS
		FROM NCARNGV n
		WHERE n.CODCARGO = @CODCARGO AND CAST(FECHA AS DATE) <= CAST(@FechaNIEPE AS DATE)
		ORDER BY FECHA DESC

		SELECT @HORASXDIA = ROUND(SUM(HORAS), 2) / @DIAS_MES_LAB
		FROM DBO.VWK_NIEPED
		WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND HORAS >= 1

		SELECT @DiasTrabajados = CAST(ROUND(SUM(HORAS) / COUNT(*), 2) / @HORASXDIA AS INT)
		FROM DBO.VWK_NIEPED
		WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND HORAS >= 1

		SELECT TOP 1 @TipoContrato = CASE NEMP.TIPOCONTRATO
				WHEN 'Indefinido'
					THEN 2 -- 2. Término Indefinido
				WHEN 'Fijo'
					THEN 1 -- 1. Termino Fijo
				WHEN 'Temporal'
					THEN 3 -- 3. Obra o Labor
				WHEN 'Sena'
					THEN 5 -- 5. Prácticas o Pasantías
				WHEN 'Bolsa'
					THEN 3
				WHEN 'Inferiorauna?o'
					THEN 3
				WHEN 'Aprendizaje'
					THEN 4 -- 4. Aprendizaje
				WHEN 'OPS'
					THEN 3
				ELSE 3
				END
		FROM NEMP
		WHERE NUMDOC = @NUMDOC

		SET @XML += 
			'<NominaIndividual xmlns="dian:gov:co:facturaelectronica:NominaIndividual" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:ext="urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2" xmlns:xades="http://uri.etsi.org/01903/v1.3.2#" xmlns:xades141="http://uri.etsi.org/01903/v1.4.1#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" SchemaLocation="" xsi:schemaLocation="dian:gov:co:facturaelectronica:NominaIndividual NominaIndividualElectronicaXSD.xsd">'
		SET @XML += '<ext:UBLExtensions>'

		BEGIN -- Firma electronica 
			SET @XML += '<ext:UBLExtension>'
			SET @XML += '<ext:ExtensionContent></ext:ExtensionContent>' -- Aquí va la firma electronica
			SET @XML += '</ext:UBLExtension>'
		END -- Fin de firma electronica

		SET @XML += '</ext:UBLExtensions>'

		IF @CNSNIEPEG_PREDECESOR IS NULL
			SET @XML += '<Novedad CUNENov="">false</Novedad>'
		ELSE
			SET @XML += '<TipoNota>' + CAST(@TIPONOTA AS VARCHAR) + '</TipoNota>'

		IF @TIPONOTA = 1
			SET @XML += '<Reemplazar>'

		IF @TIPONOTA = 2
			SET @XML += '<Eliminar>'

		IF @CNSNIEPEG_PREDECESOR IS NOT NULL
		BEGIN --NumeroPred
			IF COALESCE(@CUNE_PREDECESOR, '') = ''
				RAISERROR ('CUNE de Predecesor en Nómina Individual de Ajuste está vacío o nulo, nómina predecesora aun sin notificar', 16, 1
						);

			IF @TIPONOTA = 1
				SET @XML += '<ReemplazandoPredecesor NumeroPred="' + @PREFIJO + CAST(@CNSNIEPEG_PREDECESOR AS VARCHAR) + '" CUNEPred="' + @CUNE_PREDECESOR + 
					'" FechaGenPred="' + REPLACE(CONVERT(VARCHAR, @FECHA_PREDECESOR, 102), '.', '-') + '" />'

			IF @TIPONOTA = 2
				SET @XML += '<EliminandoPredecesor NumeroPred="' + @PREFIJO + CAST(@CNSNIEPEG_PREDECESOR AS VARCHAR) + '" CUNEPred="' + @CUNE_PREDECESOR + 
					'" FechaGenPred="' + REPLACE(CONVERT(VARCHAR, @FECHA_PREDECESOR, 102), '.', '-') + '" />'
			SET @TipoXML = '103'
		END

		-- Periodo
		IF COALESCE(@TIPONOTA, 0) <> 2
			SET @XML += 
				'<Periodo @FechaIngreso @FechaRetiro
	FechaLiquidacionInicio="@FechaLiquidacionInicio"
	FechaLiquidacionFin="@FechaLiquidacionFin"
	TiempoLaborado="@TiempoLaborado"
	FechaGen="@FechaGen"/>'
		-- Identificación interna del empleado en la empresa
		SET @XML += '<NumeroSecuenciaXML ' + IIF(@TIPONOTA = 2, '', ' CodigoTrabajador="@CodigoTrabajador"') + 
			'
	Prefijo="@Prefijo"
	Consecutivo="@Consecutivo"
	Numero="@Numero"/>'
		-- Identificación interna del empleado en la empresa
		SET @XML += 
			'<LugarGeneracionXML Pais="@Pais"
	DepartamentoEstado="@DepartamentoEstado"
	MunicipioCiudad="@MunicipioCiudad"
	Idioma="@Idioma"/>'
		-- Datos del Proveedor Tecnológico
		SET @XML += '<ProveedorXML NIT="@NIT"' + IIF(@TIPONOTA = 2, '', ' RazonSocial="@RazonSocial"') + 
			' DV="@DV" SoftwareID="@SoftwareID" SoftwareSC="@SoftwareSC"/>'
		-- QR Code
		SET @XML += '<CodigoQR>NumNIE: ' + @Prefijo + CAST(@Consecutivo AS VARCHAR) + '
FecNIE: ' + @FechaGen + '
HorNIE: ' + @HoraGen + '
NitNIE: ' + @NIT + 
			'
DocEmp: @DOCIDEMPLEADO
ValDev: ' + CAST(@VALOR_INGRESOS AS VARCHAR) + '
ValDed: ' + CAST(@VALOR_EGRESOS AS VARCHAR) + '
ValTol: ' + CAST(
				@VALOR_NETO AS VARCHAR) + '
CUNE: </CodigoQR>'
		-- Información General
		SET @VERSION = 'V1.0: Documento Soporte de Pago de Nómina Electrónica'

		IF @TIPONOTA IN (1, 2)
			SET @VERSION = 'V1.0: Nota de Ajuste de Documento Soporte de Pago de Nómina Electrónica'
		SET @XML += '<InformacionGeneral Version="' + @VERSION + 
			'"
	Ambiente="@AMBIENTE"
	TipoXML="@TipoXML"
	CUNE="@CUNE"
	EncripCUNE="CUNE-SHA384"
	FechaGen="@FechaGen"
	HoraGen="@HoraGen"
	' + 
			IIF(@TIPONOTA = 2, '', 'PeriodoNomina="@PeriodoNomina" TipoMoneda="COP" TRM="0"') + '/>'
		-- Notas Adicionales Libre Texto
		SET @XML += '<Notas>@CUNE</Notas>'
		-- Empleador
		SET @XML += 
			'<Empleador RazonSocial="@RazonSocial"
	NIT="@NIT" DV="@DV"
	Pais="@Pais" DepartamentoEstado="@DepartamentoEstado"
	MunicipioCiudad="@MunicipioCiudad" Direccion="@Direccion"/>'

		-- Trabajador
		IF COALESCE(@TIPONOTA, 0) <> 2
			SET @XML += 
				'<Trabajador TipoTrabajador="@TipoTrabajador"
	SubTipoTrabajador="@SubTipoTrabajador"
	AltoRiesgoPension="@AltoRiesgoPension"
	TipoDocumento="@TipoDocumento"
	NumeroDocumento="@DOCIDEMPLEADO"
	PrimerApellido="@PrimerApellido"
	SegundoApellido="@SegundoApellido"
	PrimerNombre="@PrimerNombre"
	@OtrosNombres
	LugarTrabajoPais="@Pais"
	LugarTrabajoDepartamentoEstado="@DepartamentoEstado"
	LugarTrabajoMunicipioCiudad="@MunicipioCiudad"
	LugarTrabajoDireccion="@Direccion"
	SalarioIntegral="@SalarioIntegral"
	TipoContrato="@TipoContrato"
	Sueldo="@Sueldo"
	' 
				+ IIF(@TIPONOTA = 2, '', ' CodigoTrabajador="@CodigoTrabajador"') + '/>'

		-- Datos de Pago
		IF COALESCE(@TIPONOTA, 0) <> 2
		BEGIN
			IF @MetodoPago = '10'
				SET @XML += '<Pago Forma="1" Metodo="10" />'
			ELSE
				SET @XML += '<Pago Forma="1" Metodo="@MetodoPago" Banco="@Banco" TipoCuenta="@TipoCuenta" NumeroCuenta="@NroCuenta"/>'

			-- Datos de Pago
			SET @XML += '<FechasPagos><FechaPago>@FechaGen</FechaPago></FechasPagos>'
			-- Devengados
			SET @XML += '<Devengados>'
			SET @XML += '<Basico DiasTrabajados="@DiasTrabajados" SueldoTrabajado="@Sueldo"/>'

			-- Transporte
			IF DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'AuxilioTransporte') + DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'ViaticoManuAlojS') + DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG
					, 'ViaticoManuAlojNS') > 0
			BEGIN
				SET @XML += '<Transporte '
				SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'AuxilioTransporte')

				IF @MONTO > 0
					SET @XML += 'AuxilioTransporte="' + CAST(@MONTO AS VARCHAR) + '" '
				SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'ViaticoManuAlojS')

				IF @MONTO > 0
					SET @XML += 'ViaticoManuAlojS="' + CAST(@MONTO AS VARCHAR) + '" '
				SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'ViaticoManuAlojNS')

				IF @MONTO > 0
					SET @XML += 'ViaticoManuAlojNS="' + CAST(@MONTO AS VARCHAR) + '" '
				SET @XML += '/>'
			END

			BEGIN -- Horas EXTRAS DIURNAS
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasD' AND NUMDOC = @NUMDOC
							-- Filtrar por todos los pagos del mes en lugar de uno solo
							AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HEDs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO
					-- Extraer el CNSPAGO real de la novedad, -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasD' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO -- Asignar a la variable temporal

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HED HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="25.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HEDs>'
				END
			END

			BEGIN -- Horas EXTRAS NOCTURNAS
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasN' AND NUMDOC = @NUMDOC
							-- Filtrar por todos los pagos del mes en lugar de uno solo
							AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HENs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO
					-- Extraer el CNSPAGO real de la novedad, -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasN' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO -- Asignar a la variable temporal

					WHILE @@FETCH_STATUS = 0
					BEGIN
						-- Enviar la variable temporal a la función en lugar de la estática @CNSPAGO
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HEN HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="75.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HENs>'
				END
			END

			BEGIN -- Horas RECARGO NOCTURNO
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasNR' AND NUMDOC = @NUMDOC
							-- Filtrar por todos los pagos del mes en lugar de uno solo
							AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HRNs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasNR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HRN HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="35.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HRNs>'
				END
			END

			BEGIN -- Horas EXTRAS DIARIAS DOMINICALES Y FESTIVAS
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasDDF' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HEDDFs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO /*  DATEADD(HOUR, HORAS, FECHAINI) */
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasDDF' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HEDDF HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="100.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HEDDFs>'
				END
			END

			BEGIN -- Horas RECARGO Extras DIARIAS Dominicales y Festivas
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasDDFR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HRDDFs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasDDFR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HRDDF HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="75.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HRDDFs>'
				END
			END

			BEGIN -- Horas EXTRAS NOCTURNAS DOMINICALES Y FESTIVAS
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasNDF' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HENDFs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasNDF' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HENDF HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="150.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HENDFs>'
				END
			END

			BEGIN -- Horas RECARGO Extras NOCTURNAS Dominicales y Festivas
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'HorasExtrasNDFR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<HRNDFs>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO -- DATEADD(HOUR, HORAS, FECHAINI)
					FROM NEDIA
					INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
					INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
					WHERE N1.ID_DIAN = 'HorasExtrasNDFR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
							SELECT CNSPAGO
							FROM NIEPE
							WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
							)

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SELECT @VRTOTAL_HE = VALOR_EMPLEADO
						FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

						IF @VRTOTAL_HE IS NULL
							SET @VRTOTAL_HE = 0
						SET @XML += '<HRNDF HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108) + 
							'"
			     HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
							'"
			     Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
			     Porcentaje="110.00"
			     Pago="' + CAST(@VRTOTAL_HE AS 
								VARCHAR) + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</HRNDFs>'
				END
			END

			BEGIN -- Vacaciones
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'VacacionesCompensada' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						) OR EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'VacacionesComunes' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<Vacaciones>'

					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'VacacionesComunes' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN -- Vacaciones Comunes
						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'VacacionesComunes' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @VRTOTAL_HE = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

							IF @VRTOTAL_HE IS NULL
								SET @VRTOTAL_HE = 0
							SET @XML += '<VacacionesComunes HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE, 108
								) + '"
					 HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
								'"
					 Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
					 Pago="' + CAST(@VRTOTAL_HE AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'VacacionesComunes' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN -- Vacaciones Compensadas
						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, n.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN = 'VacacionesCompensada' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @VRTOTAL_HE = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_HE, @FINI_HE, @FFIN_HE, @CUR_CNSPAGO, 1, 0, 0) AS V

							IF @VRTOTAL_HE IS NULL
								SET @VRTOTAL_HE = 0
							SET @XML += '<VacacionesCompensadas HoraInicio="' + REPLACE(CONVERT(VARCHAR, @FINI_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FINI_HE
									, 108) + '"
					 HoraFin="' + REPLACE(CONVERT(VARCHAR, @FFIN_HE, 102), '.', '-') + 'T' + CONVERT(VARCHAR, @FFIN_HE, 108) + 
								'"
					 Cantidad="' + CAST(@HORAS_EXTRAS AS VARCHAR) + '"
					 Pago="' + CAST(@VRTOTAL_HE AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_EXTRAS, @FINI_HE, @FFIN_HE, @CODCONCEPTO_HE, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					SET @XML += '</Vacaciones>'
				END
			END

			----
			BEGIN -- Primas
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('VacacionesCompensada') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<Primas Cantidad="' + DBO.FNK_DIAS_PRIMA(@CNSNIEPEG) + '" Pago="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'PrimaS') + '" PagoNS="' + DBO
						.FNK_VALOR_NIEPED(@CNSNIEPEG, 'PrimaNS') + '"/>'
			END

			BEGIN -- Cesantias
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('Cesantia') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<Cesantias Pago="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'Cesantia') + '" Porcentaje="12.00" PagoIntereses="' + DBO.
						FNK_VALOR_NIEPED(@CNSNIEPEG, 'InteresesCesantias') + '"/>'
			END

			BEGIN -- Incapacidades
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('IncapacidadC', 'IncapacidadL', 'IncapacidadP') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<Incapacidades>'

					-- Incapacidad Común
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'IncapacidadC' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'IncapacidadC'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadC'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a INCAPACIDAD COMUN [' + CAST(@SUM_HORAS_NEDIA AS VARCHAR
								) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) + ']. NUMDOC: ' + @NUMDOC + 
								', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadC'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<Incapacidad FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '" 
				FechaFin="' + REPLACE(
									CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
				Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
				Tipo="1"
				Pago="' + CAST(@PAGO_NEDIA AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					-- Incapacidad Profesional
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'IncapacidadP' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'IncapacidadP'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadP'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a INCAPACIDAD PROFESIONAL [' + CAST(@SUM_HORAS_NEDIA AS 
									VARCHAR) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) + ']. NUMDOC: ' + 
								@NUMDOC + ', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadP'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<Incapacidad FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '" 
				FechaFin="' + REPLACE(
									CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
				Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
				Tipo="2"
				Pago="' + CAST(@PAGO_NEDIA AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					-- Incapacidad Laboral
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'IncapacidadP' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'IncapacidadL'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadL'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a INCAPACIDAD LABORAL [' + CAST(@SUM_HORAS_NEDIA AS 
									VARCHAR) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) + ']. NUMDOC: ' + 
								@NUMDOC + ', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'IncapacidadL'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<Incapacidad FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '" 
				FechaFin="' + REPLACE(
									CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
				Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
				Tipo="3"
				Pago="' + CAST(@PAGO_NEDIA AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					SET @XML += '</Incapacidades>'
				END
			END

			BEGIN -- Licencias
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('LicenciaMP', 'LicenciaNR', 'LicenciaR') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<Licencias>'

					-- Licencia de Maternidad o Paternidad
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'LicenciaMP' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'LicenciaMP'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaMP'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a LICENCIA DE MATERNIDAD O PATERNIDAD [' + CAST(
									@SUM_HORAS_NEDIA AS VARCHAR) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) 
								+ ']. NUMDOC: ' + @NUMDOC + ', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaMP'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<LicenciaMP FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '"
			            FechaFin="' + 
								REPLACE(CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
			            Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
			            Pago="' + CAST(@PAGO_NEDIA AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					-- Licencia NO Remunerada
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'LicenciaNR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'LicenciaNR'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaNR'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a LICENCIA NO REMUNERADA [' + CAST(@SUM_HORAS_NEDIA AS 
									VARCHAR) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) + ']. NUMDOC: ' + 
								@NUMDOC + ', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaNR'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<LicenciaNR FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '"
			            FechaFin="' + 
								REPLACE(CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
			            Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
						/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					-- Licencia Remunerada
					IF EXISTS (
							SELECT 1
							FROM NEDIA
							INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
							INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
							WHERE N1.ID_DIAN = 'LicenciaR' AND NUMDOC = @NUMDOC AND CNSPAGO IN (
									SELECT CNSPAGO
									FROM NIEPE
									WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
									)
							)
					BEGIN
						SELECT @HORAS_NIEPED = CANTIDAD
						FROM DBO.VWK_NIEPED
						WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN = 'LicenciaR'

						SELECT @SUM_HORAS_NEDIA = SUM(HORAS)
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaR'

						IF @SUM_HORAS_NEDIA <> @HORAS_NIEPED
						BEGIN
							SET @MSJERROR = 'La cantidad de horas en las novedades que corresponden a LICENCIA REMUNERADA [' + CAST(@SUM_HORAS_NEDIA AS 
									VARCHAR) + '] es diferente a la tomada en cuenta en la liquidación [' + CAST(@HORAS_NIEPED AS VARCHAR) + ']. NUMDOC: ' + 
								@NUMDOC + ', CNSPAGO: ' + @CNSPAGO

							RAISERROR (@MSJERROR, 16, 1);
						END

						DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
						FOR
						SELECT HORAS, FECHAINI, FECHAFIN, NEVE.CODCONCEPTO, NEDIA.CNSPAGO
						FROM NEDIA
						INNER JOIN NEVE ON NEVE.IDEVENTO = NEDIA.IDEVENTO
						INNER JOIN NCON ON NCON.CODCONCEPTO = NEVE.CODCONCEPTO
						WHERE NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								) AND ID_DIAN = 'LicenciaR'

						OPEN _CURSOR

						FETCH NEXT
						FROM _CURSOR
						INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SELECT @PAGO_NEDIA = VALOR_EMPLEADO
							FROM DBO.FNK_VALORCONCEPTO_NEMPFD_RUN(@NUMDOC, @CODCONCEPTO_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CUR_CNSPAGO, 1, 0, 0) AS V

							SET @XML += '<LicenciaR FechaInicio="' + REPLACE(CONVERT(VARCHAR, @FECHAINI_NEDIA, 102), '.', '-') + '"
			            FechaFin="' + 
								REPLACE(CONVERT(VARCHAR, @FECHAFIN_NEDIA, 102), '.', '-') + '"
			            Cantidad="' + CAST(@HORAS_NEDIA / (@HORAS_DIA_LAB / @DIAS_MES_LAB
										) AS VARCHAR) + '"
			            Pago="' + CAST(@PAGO_NEDIA AS VARCHAR) + '"/>'

							FETCH NEXT
							FROM _CURSOR
							INTO @HORAS_NEDIA, @FECHAINI_NEDIA, @FECHAFIN_NEDIA, @CODCONCEPTO_NEDIA, @CUR_CNSPAGO
						END

						CLOSE _CURSOR

						DEALLOCATE _CURSOR
					END

					SET @XML += '</Licencias>'
				END
			END

			BEGIN -- Bonificaciones
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('BonificacionNS', 'BonificacionS') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<Bonificaciones><Bonificacion BonificacionS="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'BonificacionS') + '" BonificacionNS="' + DBO
						.FNK_VALOR_NIEPED(@CNSNIEPEG, 'BonificacionNS') + '"/></Bonificaciones>'
			END

			BEGIN -- Auxilios
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('BonificacionNS', 'BonificacionS') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<Auxilios><Auxilio AuxilioS="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'AuxilioS') + '" AuxilioNS="' + DBO.FNK_VALOR_NIEPED(
							@CNSNIEPEG, 'AuxilioNS') + '"/></Auxilios>'
			END

			IF 1 = 2
			BEGIN -- Huelga Legal
				SET @XML += 
					'<HuelgasLegales>
			<HuelgaLegal FechaInicio="9999-12-31"
			             FechaFin="9999-12-31"
			             Cantidad="0"/>
		</HuelgasLegales>'
			END

			BEGIN -- Otros Conceptos
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('OtrosConceptosS', 'OtrosConceptosNS') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
				BEGIN
					SET @XML += '<OtrosConceptos>'

					DECLARE _CURSOR CURSOR FAST_FORWARD READ_ONLY LOCAL
					FOR
					SELECT DBO.FNK_LIMPIATEXTO(DESCRIPCION, 'A-Z0-9 .,-()'), VALOR, ID_DIAN
					FROM DBO.VWK_NIEPED
					WHERE CONSECUTIVO = @PERIODO AND NUMDOC = @NUMDOC AND ID_DIAN IN ('OtrosConceptosS', 'OtrosConceptosNS')

					OPEN _CURSOR

					FETCH NEXT
					FROM _CURSOR
					INTO @NOMBRE_CONCEPTO, @TOTAL_NOMINA_NIEPED

					WHILE @@FETCH_STATUS = 0
					BEGIN
						SET @XML += '<OtroConcepto DescripcionConcepto="' + @NOMBRE_CONCEPTO + '" ConceptoS="' + CASE 
								WHEN @ID_DIAN = 'OtrosConceptosS'
									THEN CAST(@TOTAL_NOMINA_NIEPED AS VARCHAR)
								ELSE '0.00'
								END + '" ConceptoNS="' + CASE 
								WHEN @ID_DIAN = 'OtrosConceptosNS'
									THEN CAST(@TOTAL_NOMINA_NIEPED AS VARCHAR)
								ELSE '0.00'
								END + '"/>'

						FETCH NEXT
						FROM _CURSOR
						INTO @NOMBRE_CONCEPTO, @TOTAL_NOMINA_NIEPED
					END

					CLOSE _CURSOR

					DEALLOCATE _CURSOR

					SET @XML += '</OtrosConceptos>'
				END
			END

			BEGIN -- Compensaciones
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('CompensacionE', 'CompensacionO') AND NUMDOC = @NUMDOC AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<Compensaciones><Compensacion CompensacionO="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'CompensacionO') + '" CompensacionE="' + DBO.
						FNK_VALOR_NIEPED(@CNSNIEPEG, 'CompensacionE') + '"/></Compensaciones>'
			END

			BEGIN -- Bonos Electrónicos, cheques, tarjetas, vales y otros devengados
				IF EXISTS (
						SELECT 1
						FROM NEDIA
						INNER JOIN NEVE n ON NEDIA.IDEVENTO = n.IDEVENTO
						INNER JOIN NCON n1 ON n.CODCONCEPTO = n1.CODCONCEPTO
						WHERE N1.ID_DIAN IN ('PagoS', 'PagoNS', 'PagoAlimentacionNS', 'PagoAlimentacionS') AND NUMDOC = @NUMDOC 
							AND CNSPAGO IN (
								SELECT CNSPAGO
								FROM NIEPE
								WHERE NUMDOC = @NUMDOC AND CONCAT (ANO, MES) = @PERIODO
								)
						)
					SET @XML += '<BonoEPCTVs><BonoEPCTV PagoS="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'PagoS') + '" 
		PagoNS="' + DBO.FNK_VALOR_NIEPED(
							@CNSNIEPEG, 'PagoNS') + '" 
		PagoAlimentacionS="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'PagoAlimentacionS') + 
						'" 
		PagoAlimentacionNS="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'PagoAlimentacionNS') + '"/></BonoEPCTVs>'
			END

			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Comision')

			IF @MONTO > 0
				SET @XML += '<Comisiones><Comision>' + CAST(@MONTO AS VARCHAR) + '</Comision></Comisiones>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'PagoTercero')

			IF @MONTO > 0
				SET @XML += '<PagosTerceros><PagoTercero>' + CAST(@MONTO AS VARCHAR) + '</PagoTercero></PagosTerceros>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Anticipo')

			IF @MONTO > 0
				SET @XML += '<Anticipos><Anticipo>' + CAST(@MONTO AS VARCHAR) + '</Anticipo></Anticipos>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Dotacion')

			IF @MONTO > 0
				SET @XML += '<Dotacion>' + CAST(@MONTO AS VARCHAR) + '</Dotacion>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'ApoyoSost')

			IF @MONTO > 0
				SET @XML += '<ApoyoSost>' + CAST(@MONTO AS VARCHAR) + '</ApoyoSost>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Teletrabajo')

			IF @MONTO > 0
				SET @XML += '<Teletrabajo>' + CAST(@MONTO AS VARCHAR) + '</Teletrabajo>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'BonifRetiro')

			IF @MONTO > 0
				SET @XML += '<BonifRetiro>' + CAST(@MONTO AS VARCHAR) + '</BonifRetiro>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Indemnizacion')

			IF @MONTO > 0
				SET @XML += '<Indemnizacion>' + CAST(@MONTO AS VARCHAR) + '</Indemnizacion>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Reintegro')

			IF @MONTO > 0
				SET @XML += '<Reintegro>' + CAST(@MONTO AS VARCHAR) + '</Reintegro>'
			SET @XML += '</Devengados>'
			SET @XML += '<Deducciones>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionSalud')
			SET @XML += '<Salud Porcentaje="' + IIF(@MONTO <= 0, '0.00', '4.00') + '" Deduccion="' + CAST(@MONTO AS VARCHAR) + '"/>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionFondoPensio')
			SET @XML += '<FondoPension Porcentaje="' + IIF(@MONTO <= 0, '0.00', '4.00') + '" Deduccion="' + CAST(@MONTO AS VARCHAR) + '"/>'

			/* TODO
	PorcentajeSub >> Se debe colocar el Porcentaje que correspondiente al Fondo de Subsistencia correspondiente
	DeduccionSub  >> Valor Pagado correspondiente a Fondo de Subsistencia por parte del trabajador
*/
			-- query2
			IF 1 = 2
				SET @XML += '<FondoSP Porcentaje="1.00" Deduccion="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'DeduccionSalud') + 
					'" PorcentajeSub="0.00" DeduccionSub="0.00"/>'

			IF 1 = 2
				SET @XML += '<Sindicatos><Sindicato Porcentaje="0.00" Deduccion="0.00"/></Sindicatos>'

			IF DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionSancionPub') > 0 OR DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionSancionPri') > 0
				SET @XML += '<Sanciones><Sancion SancionPublic="' + DBO.FNK_VALOR_NIEPED(@CNSNIEPEG, 'DeduccionSancionPub') + '" SancionPriv="' + DBO.
					FNK_VALOR_NIEPED(@CNSNIEPEG, 'DeduccionSancionPri') + '"/></Sanciones>'

			IF 1 = 2
				SET @XML += '<Libranzas><Libranza Descripcion="" Deduccion="0.00"/></Libranzas>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionPagoTercero')

			IF @MONTO > 0
				SET @XML += '<PagosTerceros><PagoTercero>' + CAST(@MONTO AS VARCHAR) + '</PagoTercero></PagosTerceros>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionAnticipo')

			IF @MONTO > 0
				SET @XML += '<Anticipos><Anticipo>' + CAST(@MONTO AS VARCHAR) + '</Anticipo></Anticipos>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionOtras')

			IF @MONTO > 0
				SET @XML += '<OtrasDeducciones><OtraDeduccion>' + CAST(@MONTO AS VARCHAR) + '</OtraDeduccion></OtrasDeducciones>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionPensionVol')

			IF @MONTO > 0
				SET @XML += '<PensionVoluntaria>' + CAST(@MONTO AS VARCHAR) + '</PensionVoluntaria>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionRetencionF')

			IF @MONTO > 0
				SET @XML += '<RetencionFuente>' + CAST(@MONTO AS VARCHAR) + '</RetencionFuente>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionAFC')

			IF @MONTO > 0
				SET @XML += '<AFC>' + CAST(@MONTO AS VARCHAR) + '</AFC>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionCooperativa')

			IF @MONTO > 0
				SET @XML += '<Cooperativa>' + CAST(@MONTO AS VARCHAR) + '</Cooperativa>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionEmbargoF')

			IF @MONTO > 0
				SET @XML += '<EmbargoFiscal>' + CAST(@MONTO AS VARCHAR) + '</EmbargoFiscal>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionPlanCompl')

			IF @MONTO > 0
				SET @XML += '<PlanComplementarios>' + CAST(@MONTO AS VARCHAR) + '</PlanComplementarios>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionEducacion')

			IF @MONTO > 0
				SET @XML += '<Educacion>' + CAST(@MONTO AS VARCHAR) + '</Educacion>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionReintegro')

			IF @MONTO > 0
				SET @XML += '<Reintegro>' + CAST(@MONTO AS VARCHAR) + '</Reintegro>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'DeduccionDeuda')

			IF @MONTO > 0
				SET @XML += '<Deuda>' + CAST(@MONTO AS VARCHAR) + '</Deuda>'
			SET @XML += '</Deducciones>'
			SET @MONTO = DBO.FNK_VALOR_NIEPEG(@CNSNIEPEG, 'Redondeo')

			IF @MONTO > 0
				SET @XML += '<Redondeo>' + CAST(@MONTO AS VARCHAR) + '</Redondeo>'
			SET @XML += '<DevengadosTotal>' + CAST(@VALOR_INGRESOS AS VARCHAR) + '</DevengadosTotal>'
			SET @XML += '<DeduccionesTotal>' + CAST(@VALOR_EGRESOS AS VARCHAR) + '</DeduccionesTotal>'
			SET @XML += '<ComprobanteTotal>' + CAST(@VALOR_NETO AS VARCHAR) + '</ComprobanteTotal>'
		END

		IF @TIPONOTA = 1
			SET @XML += '</Reemplazar>'

		IF @TIPONOTA = 2
			SET @XML += '</Eliminar>'
		SET @XML += '</NominaIndividual>'

		BEGIN -- Generación de Código Único de Nómina Electrónica
			IF @CONSECUTIVO IS NULL
			BEGIN
				RAISERROR ('La columna item de NIEPE está nula, no se puede generar un consecutivo unico de NIE', 16, 1);
			END

			SET @CUNE = @Prefijo + CAST(@Consecutivo AS VARCHAR) -- NumNE
			SET @CUNE += REPLACE(CONVERT(VARCHAR, @FechaNIEPE, 102), '.', '-') -- FecNE
			SET @CUNE += @HoraGen -- HorNE
			SET @CUNE += CAST(IIF(@TIPONOTA = 2, 0, @VALOR_INGRESOS) AS VARCHAR) -- ValDev
			SET @CUNE += CAST(IIF(@TIPONOTA = 2, 0, @VALOR_EGRESOS) AS VARCHAR) -- ValDed
			SET @CUNE += CAST(IIF(@TIPONOTA = 2, 0, @VALOR_NETO) AS VARCHAR) -- ValTolNE
			SET @CUNE += @NIT -- NitNE
			SET @CUNE += IIF(@TIPONOTA = 2, '0', @NumeroDocumento) -- DocEmp
			SET @CUNE += @TipoXML -- TipoXML
			SET @CUNE += @SoftwarePIN -- Software-Pin
			SET @CUNE += CAST(@Ambiente AS VARCHAR) -- TipAmb
		END

		BEGIN -- Datos demográficos del empleado
			SET @XML = REPLACE(@XML, '@FechaIngreso', IIF(COALESCE(@FechaIngreso, '') <> '', CONCAT ('FechaIngreso="', @FechaIngreso, '"'
							), ''))
			SET @XML = REPLACE(@XML, '@FechaRetiro', IIF(COALESCE(@FechaRetiro, '') <> '', CONCAT ('FechaRetiro="', @FechaRetiro, '"')
						, ''))
			SET @XML = REPLACE(@XML, '@FechaLiquidacionInicio', COALESCE(@FechaLiquidacionInicio, ''))
			SET @XML = REPLACE(@XML, '@FechaLiquidacionFin', COALESCE(@FechaLiquidacionFin, ''))
			SET @XML = REPLACE(@XML, '@TiempoLaborado', CAST(@TiempoLaborado AS VARCHAR))
			SET @XML = REPLACE(@XML, '@FechaGen', @FechaGen)
		END

		BEGIN -- Identificación interna del empleado en la empresa
			SET @XML = REPLACE(@XML, '@CodigoTrabajador', @NUMDOC)
			SET @XML = REPLACE(@XML, '@Prefijo', @Prefijo)
			SET @XML = REPLACE(@XML, '@Consecutivo', @Consecutivo)
			SET @XML = REPLACE(@XML, '@Numero', @Prefijo + CAST(@Consecutivo AS VARCHAR))
		END

		BEGIN -- Lugar donde se genera el XML
			IF COALESCE(@DepartamentoEstado, '') = ''
				RAISERROR ('El código ISO del departamento donde se genera la liquidación no está configurado', 16, 1)

			IF COALESCE(@MunicipioCiudad, '') = ''
				RAISERROR ('El código DIAN de la ciudad donde se genera la liquidación no está configurado', 16, 1)

			SET @XML = REPLACE(@XML, '@Pais', COALESCE(@Pais, '57'))
			SET @XML = REPLACE(@XML, '@DepartamentoEstado', @DepartamentoEstado)
			SET @XML = REPLACE(@XML, '@MunicipioCiudad', @MunicipioCiudad)
			SET @XML = REPLACE(@XML, '@Idioma', @Idioma)
		END

		BEGIN -- Datos del Proveedor Tecnológico
			IF COALESCE(@SoftwareID, '') = ''
				RAISERROR ('Identificador del Software no configurado. (TGEN => ''FDIAN'', ''SOFTWARE_NOMINA'', ''ID'')', 16, 1);

			IF COALESCE(@SoftwarePIN, '') = ''
				RAISERROR ('PIN del Software no configurado. (TGEN => ''FDIAN'', ''SOFTWARE_NOMINA'', ''PIN'')', 16, 1);

			SET @SoftwareSC = @SoftwareID + @SoftwarePIN + @Prefijo + CAST(@Consecutivo AS VARCHAR) -- Página 249 de 269
			SET @XML = REPLACE(@XML, '@RazonSocial', @RazonSocial)
			SET @XML = REPLACE(@XML, '@NIT', @NIT)
			SET @XML = REPLACE(@XML, '@DV', @DV)
			SET @XML = REPLACE(@XML, '@SoftwareID', @SoftwareID)
			SET @XML = REPLACE(@XML, '@SoftwareSC', COALESCE(@SoftwareSC, ''))
		END

		BEGIN -- Información General
			IF COALESCE(@PeriodoNomina, - 1) NOT IN (1, 2, 3, 4, 5, 6)
			BEGIN
				SET @MSJERROR = 'Periodo nómina [CNSPAGO: ' + @CNSPAGO + '] (NPPAG.CODPERIODO) no válido >> 5.5.1 Periodo de Nómina: PeriodoNomina'

				RAISERROR (@MSJERROR, 16, 1);
			END

			SET @XML = REPLACE(@XML, '@CUNE', COALESCE(@CUNE, ''))
			SET @XML = REPLACE(@XML, '@AMBIENTE', CAST(COALESCE(@Ambiente, 2) AS VARCHAR))
			SET @XML = REPLACE(@XML, '@TipoXML', @TipoXML)
			SET @XML = REPLACE(@XML, '@HoraGen', @HoraGen)
			SET @XML = REPLACE(@XML, '@PeriodoNomina', CAST(@PeriodoNomina AS VARCHAR))
		END

		SET @XML = REPLACE(@XML, '@Direccion', CAST(@Direccion AS VARCHAR))

		BEGIN -- Trabajador
			IF NOT EXISTS (
					SELECT 1
					FROM TGEN
					WHERE TABLA = 'NFUTC' AND CAMPO = 'HOMOLOGODIAN' AND CODIGO = @TipoTrabajador
					)
			BEGIN
				SET @MSJERROR = 'Tipo de cotizante no configurado en la ficha del empleado [' + @NUMDOC + ' - ' + @PNombre + ' ' + @PApellido + 
					'] (NFUTC.HOMOLOGODIAN) >> 5.5.3 Tipo de Trabajador'

				RAISERROR (@MSJERROR, 16, 1);
			END

			IF COALESCE(@TipoDocumento, '') = ''
			BEGIN
				SET @MSJERROR = 'Tipo de documento de identidad del empleado no homologado [' + @NUMDOC + ' - ' + @PNombre + ' ' + @PApellido + 
					'] (TGEN.TABLA= GENERAL, TGEN.CAMPO=TIPOIDENT)'

				RAISERROR (@MSJERROR, 16, 1);
			END

			IF COALESCE(@TIPOCONTRATO, '') = ''
			BEGIN
				SET @MSJERROR = 'Empleado no tiene tipo de contrato definido [' + @NUMDOC + ' - ' + @PNombre + ' ' + @PApellido + '] (NEMP.TIPOCONTRATO)'

				RAISERROR (@MSJERROR, 16, 1);
			END

			SET @XML = REPLACE(@XML, '@AltoRiesgoPension', CASE 
						WHEN @AltoRiesgoPension = 0
							THEN 'false'
						ELSE 'true'
						END)
			SET @XML = REPLACE(@XML, '@TipoTrabajador', @TipoTrabajador)
			SET @XML = REPLACE(@XML, '@SubTipoTrabajador', @SubTipoTrabajador)
			SET @XML = REPLACE(@XML, '@TipoDocumento', @TipoDocumento)
			SET @XML = REPLACE(@XML, '@DOCIDEMPLEADO', @NumeroDocumento)
			SET @XML = REPLACE(@XML, '@PrimerApellido', COALESCE(@PApellido, ''))
			SET @XML = REPLACE(@XML, '@PrimerNombre', COALESCE(@PNombre, ''))
			SET @XML = REPLACE(@XML, '@SegundoApellido', COALESCE(@SApellido, ''))
			SET @XML = REPLACE(@XML, '@OtrosNombres', iif(COALESCE(@SNombre, '') <> '', CONCAT ('OtrosNombres="', @SNombre, '"'), ''))
			SET @XML = REPLACE(@XML, '@SalarioIntegral', CASE 
						WHEN @SalarioIntegral = 0
							THEN 'false'
						ELSE 'true'
						END)
			SET @XML = REPLACE(@XML, '@TipoContrato', CAST(COALESCE(@TipoContrato, '') AS VARCHAR))
			SET @XML = REPLACE(@XML, '@Sueldo', CAST(@Sueldo AS VARCHAR))
			SET @XML = REPLACE(@XML, '@MetodoPago', CAST(COALESCE(@MetodoPago, '') AS VARCHAR))
			SET @XML = REPLACE(@XML, '@Banco', CAST(COALESCE(@Banco, '') AS VARCHAR))
			SET @XML = REPLACE(@XML, '@TipoCuenta', COALESCE(@TipoCuenta, ''))
			SET @XML = REPLACE(@XML, '@NroCuenta', COALESCE(@NroCuenta, ''))
		END

		SET @XML = REPLACE(@XML, '@DiasTrabajados', CAST(COALESCE(@DiasTrabajados, '') AS VARCHAR))

		IF @CNSNIEPEG_PREDECESOR IS NOT NULL
		BEGIN
			SET @XML = REPLACE(@XML, 'NominaIndividual', 'NominaIndividualDeAjuste')
		END

		IF @PATH_URL IS NULL
			--SELECT @XML as [XML]
			SELECT CAST(@XML AS XML) AS [XML]
		ELSE
			EXEC SPK_GUARDAR_ARCHIVO @XML, @PATH_URL, @NOMBRE_XML;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;

		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();

		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
	END CATCH
END

