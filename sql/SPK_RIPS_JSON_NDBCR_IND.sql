CREATE OR ALTER PROCEDURE DBO.SPK_RIPS_JSON_NDBCR_IND
@CNSFNOT  VARCHAR(20),
@URL_PATH VARCHAR(MAX)=NULL,
@PLANO NVARCHAR(MAX) OUTPUT
AS
DECLARE @N_FACTURA VARCHAR(20)
DECLARE @TIPONOTA VARCHAR(10)
DECLARE @CLASE VARCHAR(2)
DECLARE @PREFACT VARCHAR(20)
DECLARE @RECIEN  AS NVARCHAR(MAX)
DECLARE @NOADMISION VARCHAR(20)
DECLARE @PROCEDENCIA VARCHAR(20)
DECLARE @NFACTURA VARCHAR(20)=NULL
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
DECLARE @BASE64 VARCHAR(MAX)
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
   numAutorizacion VARCHAR(30),
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
   @numAutorizacion_med VARCHAR(30),
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
DECLARE @fechaInicioAtencionAU VARCHAR(16)
DECLARE @fechaEgresoAU VARCHAR(16)
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
DECLARE @fechaSuministroTecnologia VARCHAR(16)
   ,@tipoOS VARCHAR(2)
   ,@cantidadOS INT
   ,@vrUnitOS INT
   ,@primerGrupo BIT = 1
DECLARE @RESIDUO DECIMAL(14,2)
DECLARE @VALORCOPAGOACU DECIMAL(14,4)
DECLARE @VALORCOPAGOS DECIMAL(14,4)
DECLARE @DIFE DECIMAL(14,2)
DECLARE @DIF DECIMAL(14,4)
DECLARE @CONSE INT
DECLARE @SUM_AC DECIMAL(14,4), @SUM_AP DECIMAL(14,4), @SUM_AM DECIMAL(14,4), @SUM_AT DECIMAL(14,4)
DECLARE @VR_NOTA DECIMAL(14,2)
DECLARE @JSON_FTR NVARCHAR(MAX), @RIPS_FTR NVARCHAR(MAX)
DECLARE @SEC_ITEM_FTR VARCHAR(20), @ITEM_FTR NVARCHAR(MAX), @VR_ITEM_FTR DECIMAL(14,2)
DECLARE @ITEM_NC NVARCHAR(MAX), @ARR_ONE NVARCHAR(MAX)
DECLARE @SEC_NC VARCHAR(20), @JSON_KEY_NC VARCHAR(20)

DECLARE @numDocumentoIdObligado VARCHAR(20)
DECLARE @IDPLAN VARCHAR(10),@CONCEPTORECAUDOICI VARCHAR(20) ,@IDDXCIT VARCHAR(10) ,@TIPODXCIT VARCHAR(20) ,@IDAFILIADOCIT VARCHAR(20)
       ,@CONCEPTORECAUDOICE VARCHAR(20) ,@ESMODERADORAENFTR VARCHAR(2) ,@FMINHPRE DATE,@FMAXHPRE DATE,@FHADM DATE ,@FALTAMED DATE,@FINIATEN DATETIME ,@FFINATEN DATETIME
       ,@FINIATENCION DATETIME, @FFINATENCION DATETIME, @ITEM_FDIANR INT,@FECHAFACTURA DATE ,@FECHANACIMIENTOAFI DATE ,@EDAD INT, @PAQUETE INT -- 20250618 - STORRES - SE AGREGA VARIABLE PARA IDENTIFICAR PAQUETE
BEGIN
   PRINT 'SPK_RIPS_JSON_NDBCR_IND'
   SET LANGUAGE Spanish
   SET DATEFORMAT dmy

   SELECT @PROCEDENCIA=FTR.PROCEDENCIA,@NOADMISION=NOREFERENCIA ,@IDSEDE = IDSEDE,@N_fACTURA=FTR.N_FACTURA,@CLASE=CASE WHEN FNOT.CLASE='C' THEN 'NC' ELSE 'ND' END
      ,@VALORCOPAGO=CASE WHEN COALESCE(CAPITADA,0)=0 THEN COALESCE(VALORCOPAGO,0) ELSE CASE WHEN COALESCE(COPAPROPIO,0)=1 THEN COALESCE(CP_VLR_COPAGOS,0) ELSE COALESCE(VALORCOPAGO,0) END END
      ,@IDSEDE = IDSEDE, @CNSFCT = CNSFCT, @IDPLAN = FTR.IDPLAN,@PREFACT=COALESCE(FTR.PREFIJODIANFE,''),
      @TIPONOTA=CASE WHEN FNOT.CLASE='C' THEN CASE WHEN FNOT.IDCONCEPTO=DBO.FNK_VALORVARIABLE('IDCONCEP_ANULAFTRCE') AND FNOT.PROCEDENCIA='FACTURA' THEN 'TOTAL' ELSE 'PARCIAL' END ELSE 'PARCIAL' END,
      @VR_NOTA = FNOT.VR_TOTAL
   FROM FNOT INNER JOIN  FTR ON FNOT.N_fACTURA=FTR.N_FACTURA
   WHERE FNOT.CNSFNOT=@CNSFNOT

   print '@PAQUETE='+convert(varchar(50),@PAQUETE)
   print '@ESMODERADORAENFTR='+convert(varchar(50),@ESMODERADORAENFTR)
   print '@@N_FACTURA='+convert(varchar(50),@N_FACTURA)
   print '@PROCEDENCIA='+convert(varchar(50),@PROCEDENCIA)
   print '@NOADMISION='+convert(varchar(50),@NOADMISION)

   IF NOT EXISTS(SELECT 1 FROM FTR WHERE N_FACTURA=@N_FACTURA )
   BEGIN
      PRINT 'No encontre la Factura...me devuelvo'
      RETURN
   END
   PRINT '@TIPONOTA='+@TIPONOTA
   IF @TIPONOTA='PARCIAL'
   BEGIN
      SELECT @IDTERINSTA = DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
      SELECT @CONCEPTORECAUDOICI = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICI'
      SELECT @CONCEPTORECAUDOICE = DATO1 FROM TGEN WHERE TABLA = 'RIPS_JSON' AND CAMPO = 'conceptoRecaudo' AND CODIGO = 'ICE'
      SELECT @IDPRESTADOR=COALESCE(IDALTERNA2,'No tengo'), @numDocumentoIdObligado = NIT
      FROM TER WHERE IDTERCERO=@IDTERINSTA
      PRINT '@PROCEDENCIA = ' + @PROCEDENCIA+'@numDocumentoIdObligado='+@numDocumentoIdObligado

      DECLARE @NC_DESDE_FTR BIT = 0
      DECLARE @RIPS_NC_FTR NVARCHAR(MAX) = NULL

      IF @CLASE='NC' AND @PROCEDENCIA<>'FINANCIERO'
      BEGIN
         PRINT 'Intento RIPS NC item unico desde FTRJSON...'

         SELECT @JSON_FTR = JSON_ENVIO FROM FTRJSON WHERE CNSFCT = @CNSFCT;

         IF COALESCE(@JSON_FTR, '') <> '' AND COALESCE(@VR_NOTA, 0) > 0
         BEGIN
            SET @RIPS_FTR = COALESCE(JSON_QUERY(@JSON_FTR, '$.rips'), @JSON_FTR);
            SET @SEC_ITEM_FTR = NULL;
            SET @ITEM_FTR = NULL;
            SET @VR_ITEM_FTR = NULL;

            /* Nota parcial: el vrServicio del item debe ser >= valor nota (nota <= servicio factura) */
            ;WITH FTR_ITEMS AS (
               SELECT 'consultas' AS SECCION, CAST(v.value AS NVARCHAR(MAX)) AS ITEM_JSON,
                  TRY_CAST(JSON_VALUE(v.value, '$.vrServicio') AS DECIMAL(14,2)) AS VR_SERVICIO
               FROM OPENJSON(JSON_QUERY(@RIPS_FTR, '$.usuarios[0].servicios.consultas')) v
               UNION ALL
               SELECT 'medicamentos', CAST(v.value AS NVARCHAR(MAX)),
                  TRY_CAST(JSON_VALUE(v.value, '$.vrServicio') AS DECIMAL(14,2))
               FROM OPENJSON(JSON_QUERY(@RIPS_FTR, '$.usuarios[0].servicios.medicamentos')) v
               UNION ALL
               SELECT 'procedimientos', CAST(v.value AS NVARCHAR(MAX)),
                  TRY_CAST(JSON_VALUE(v.value, '$.vrServicio') AS DECIMAL(14,2))
               FROM OPENJSON(JSON_QUERY(@RIPS_FTR, '$.usuarios[0].servicios.procedimientos')) v
               UNION ALL
               SELECT 'otrosServicios', CAST(v.value AS NVARCHAR(MAX)),
                  TRY_CAST(JSON_VALUE(v.value, '$.vrServicio') AS DECIMAL(14,2))
               FROM OPENJSON(JSON_QUERY(@RIPS_FTR, '$.usuarios[0].servicios.otrosServicios')) v
            )
            SELECT TOP 1
               @SEC_ITEM_FTR = SECCION,
               @ITEM_FTR = ITEM_JSON,
               @VR_ITEM_FTR = VR_SERVICIO
            FROM FTR_ITEMS
            WHERE VR_SERVICIO >= @VR_NOTA
            ORDER BY VR_SERVICIO DESC, SECCION;

            IF @ITEM_FTR IS NOT NULL
            BEGIN
               SET @ITEM_NC = @ITEM_FTR;
               IF @SEC_ITEM_FTR = 'otrosServicios'
                  SET @ITEM_NC = JSON_MODIFY(
                     JSON_MODIFY(
                        JSON_MODIFY(@ITEM_NC, '$.vrServicio', @VR_NOTA),
                        '$.vrUnitOS', @VR_NOTA),
                     '$.cantidadOS', COALESCE(TRY_CAST(JSON_VALUE(@ITEM_NC, '$.cantidadOS') AS DECIMAL(14,2)), 1));
               ELSE IF @SEC_ITEM_FTR = 'medicamentos'
                  SET @ITEM_NC = JSON_MODIFY(
                     JSON_MODIFY(
                        JSON_MODIFY(
                           JSON_MODIFY(@ITEM_NC, '$.vrServicio', @VR_NOTA),
                           '$.vrUnitMedicamento', @VR_NOTA),
                        '$.cantidadMedicamento', COALESCE(TRY_CAST(JSON_VALUE(@ITEM_NC, '$.cantidadMedicamento') AS DECIMAL(14,2)), 1)),
                     '$.numAutorizacion', NULL);
               ELSE
                  SET @ITEM_NC = JSON_MODIFY(@ITEM_NC, '$.vrServicio', @VR_NOTA);

               SET @RIPS_NC_FTR = @RIPS_FTR;
               SET @RIPS_NC_FTR = JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@RIPS_NC_FTR, '$.tipoNota', @CLASE),
                  '$.numNota', LTRIM(RTRIM(@PREFACT)) + @CNSFNOT), '$.numFactura', @N_FACTURA);

               DECLARE @SECCIONES_NC TABLE (SECCION VARCHAR(20), JSON_KEY VARCHAR(20), ORDEN INT);
               INSERT INTO @SECCIONES_NC VALUES ('consultas', 'consultas', 1), ('medicamentos', 'medicamentos', 2),
                  ('procedimientos', 'procedimientos', 3), ('otrosServicios', 'otrosServicios', 4);

               DECLARE NCSEC CURSOR LOCAL FAST_FORWARD FOR
                  SELECT SECCION, JSON_KEY FROM @SECCIONES_NC ORDER BY ORDEN;
               OPEN NCSEC;
               FETCH NEXT FROM NCSEC INTO @SEC_NC, @JSON_KEY_NC;
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @SEC_NC = @SEC_ITEM_FTR
                  BEGIN
                     SET @ARR_ONE = N'[' + @ITEM_NC + N']';
                     SET @RIPS_NC_FTR = JSON_MODIFY(@RIPS_NC_FTR, '$.usuarios[0].servicios.' + @JSON_KEY_NC, JSON_QUERY(@ARR_ONE));
                  END
                  ELSE
                     SET @RIPS_NC_FTR = JSON_MODIFY(@RIPS_NC_FTR, '$.usuarios[0].servicios.' + @JSON_KEY_NC, NULL);

                  FETCH NEXT FROM NCSEC INTO @SEC_NC, @JSON_KEY_NC;
               END
               CLOSE NCSEC;
               DEALLOCATE NCSEC;

               IF COALESCE(@RIPS_NC_FTR, '') <> '' AND ISJSON(@RIPS_NC_FTR) = 1
               BEGIN
                  SET @NC_DESDE_FTR = 1;
                  SELECT @PLANO = '{"rips": '+@RIPS_NC_FTR+',"xmlFevFile": "@XMLFEVFILE"}';
                  PRINT '[SPK_RIPS_JSON_NDBCR_IND] NC item unico OK (seccion=' + @SEC_ITEM_FTR
                     + ', vrFactura=' + CONVERT(VARCHAR(20), @VR_ITEM_FTR, 0)
                     + ', vrNC=' + CONVERT(VARCHAR(20), @VR_NOTA, 2) + ')';
               END
            END
            ELSE
               PRINT '[SPK_RIPS_JSON_NDBCR_IND] Sin item FTR con vrServicio >= nota; usa FNOTD/HPRED';
         END
         ELSE
            PRINT '[SPK_RIPS_JSON_NDBCR_IND] Sin FTRJSON o VR_NOTA; usa FNOTD/HPRED';
      END

      IF @NC_DESDE_FTR = 0
      BEGIN
      IF @PROCEDENCIA='FINANCIERO'
      BEGIN
         PRINT 'INGRESO FINANCIERO...'
         DECLARE @JSON NVARCHAR(MAX);
         DECLARE @RIPS NVARCHAR(MAX);
         DECLARE @Usuario NVARCHAR(MAX);
         DECLARE @Servicio NVARCHAR(MAX);
         DECLARE @VLRNOTA DECIMAL(14,2)
         DECLARE @TipoServicio NVARCHAR(20);
         DECLARE @UsuarioNuevo NVARCHAR(MAX);
         DECLARE @RIPS_NUEVO NVARCHAR(MAX);
         DECLARE @JSON_NUEVO NVARCHAR(MAX);
         IF @CLASE ='ND'
         BEGIN
            SELECT @VLRNOTA=VR_TOTAL FROM FNOT WHERE CNSFNOT=@CNSFNOT
            SELECT @VrServicio = 0,@VLRNOTA=0

            SELECT @JSON = JSON_ENVIO
            FROM FTRJSON
            WHERE CNSFCT = @CNSFCT;

            PRINT'@CNSFCT='+@CNSFCT

            SET @RIPS = COALESCE(JSON_QUERY(@JSON, '$.rips'), @JSON);

            PRINT @RIPS

            SET @UsuarioNuevo = JSON_QUERY(@RIPS, '$.usuarios[0]');
            IF @UsuarioNuevo IS NULL
            BEGIN
               SET @UsuarioNuevo = JSON_QUERY(@RIPS, '$.usuarios[1]');
            END
            PRINT 'USUARIOI'+ @UsuarioNuevo
            DECLARE @CANTI INT
            SELECT @CANTI=COUNT(*)FROM OPENJSON(ISNULL(JSON_QUERY(@UsuarioNuevo, '$.servicios.consultas'), '[]'))
            DECLARE @ITEM VARCHAR(MAX)
            IF COALESCE(@CANTI,0)>0
            BEGIN
               SET @ITEM = JSON_QUERY(@UsuarioNuevo, '$.servicios.consultas[0]');
               SET @UsuarioNuevo = JSON_MODIFY( @UsuarioNuevo,'$.servicios.consultas',JSON_QUERY('[' + @ITEM + ']'));
               SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo,'$.servicios.consultas[0].vrServicio', @VLRNOTA );
               SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.procedimientos', NULL);
               SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.medicamentos', NULL);
               SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.otrosServicios', NULL);
            END
            ELSE
            BEGIN
               SELECT @CANTI=COUNT(*)FROM OPENJSON(ISNULL(JSON_QUERY(@UsuarioNuevo, '$.servicios.procedimientos'), '[]'))
               IF COALESCE(@CANTI,0)>0
               BEGIN
                  SET @ITEM = JSON_QUERY(@UsuarioNuevo, '$.servicios.procedimientos[0]');
                  SET @UsuarioNuevo = JSON_MODIFY( @UsuarioNuevo,'$.servicios.procedimientos',JSON_QUERY('[' + @ITEM + ']'));
                  SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo,'$.servicios.procedimientos[0].vrServicio', @VLRNOTA );
                  SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.medicamentos', NULL);
                  SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.otrosServicios', NULL);
               END
               ELSE
               BEGIN
                  SELECT @CANTI=COUNT(*)FROM OPENJSON(ISNULL(JSON_QUERY(@UsuarioNuevo, '$.servicios.medicamentos'), '[]'))
                  IF COALESCE(@CANTI,0)>0
                  BEGIN
                     SET @ITEM = JSON_QUERY(@UsuarioNuevo, '$.servicios.medicamentos[0]');
                     SET @UsuarioNuevo = JSON_MODIFY( @UsuarioNuevo,'$.servicios.medicamentos',JSON_QUERY('[' + @ITEM + ']'));
                     SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo,'$.servicios.medicamentos[0].vrServicio', @VLRNOTA );
                     SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo, '$.servicios.otrosServicios', NULL);
                  END
                  ELSE
                  BEGIN
                     IF COALESCE(@CANTI,0)>0
                     BEGIN
                        SET @ITEM = JSON_QUERY(@UsuarioNuevo, '$.servicios.otrosServicios[0]');
                        SET @UsuarioNuevo = JSON_MODIFY( @UsuarioNuevo,'$.servicios.otrosServicios',JSON_QUERY('[' + @ITEM + ']'));
                        SET @UsuarioNuevo = JSON_MODIFY(@UsuarioNuevo,'$.servicios.otrosServicios[0].vrServicio', @VLRNOTA );
                     END
                  END
               END
            END

            SELECT @RIPS_NUEVO =
            (
               SELECT
                  @numDocumentoIdObligado AS numDocumentoIdObligado,
                  @N_FACTURA              AS numFactura,
                  @CLASE                                         AS tipoNota,
                  LTRIM(RTRIM(@PREFACT))+@CNSFNOT               AS numNota,
                  JSON_QUERY(CONCAT('[', @UsuarioNuevo, ']'))   AS usuarios
               FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            );
         END
         SELECT @JSON_NUEVO =
         (
            SELECT
               JSON_QUERY(@RIPS_NUEVO) AS rips,
               '@XMLFEVFILE'             AS xmlFevFile
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
         );
         PRINT @JSON_NUEVO
         SET @PLANO= @JSON_NUEVO
      END
      ELSE
      BEGIN
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

            SELECT @EDAD = DATEDIFF(year, @FECHANACIMIENTOAFI, @FECHAFACTURA)
               - CASE
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
                  @TIPOUSU= CASE WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN AFI.TIPOUSUARIO
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
            IF @PROCEDENCIA='AUT'
            BEGIN
               SELECT @DOCIDAFILIADO=AFI.DOCIDAFILIADO,@TIPODOC=AFI.TIPO_DOC,
                  @TIPOUSU= CASE WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN AFI.TIPOUSUARIO
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
                  @TIPOUSU= CASE WHEN COALESCE(AFI.TIPOUSUARIO,'') <> '' THEN AFI.TIPOUSUARIO
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

         -- Si la IPS maneja multiples sedes el codigo de habilitacion es por sede
         IF EXISTS(SELECT 1 FROM USVGS WHERE IDVARIABLE = 'FACTSEDE' AND DATO='SI')
         BEGIN
            SELECT @IDPRESTADOR = COALESCE(CODHABILITA, IDSGSSS) FROM SED WHERE IDSEDE=@IDSEDE
         END

         SELECT @PLANO='{'
         SET @PLANO += '"numDocumentoIdObligado":"'+LTRIM(RTRIM(COALESCE(@numDocumentoIdObligado,'')))+'" ,'
         SET @PLANO += '"numFactura":"'+@N_FACTURA+'" ,'
         SET @PLANO += '"tipoNota": "'+@CLASE+'",'
         SET @PLANO += '"numNota": "'+LTRIM(RTRIM(@PREFACT))+@CNSFNOT+'",'
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
         BEGIN --VERIFICACION de fechas en el xml de la factura para poder arreglar a las malas los datos
            SELECT @FINIATEN = FECHA FROM HADM WHERE NOADMISION=@NOADMISION

            IF @FINIATEN IS NULL
               SELECT @FINIATEN = MIN(FECHA) FROM HPRE WHERE NOADMISION=@NOADMISION

            SELECT @FFINATEN = MAX(Fecha)
            FROM (
                SELECT MAX(FECHA) AS Fecha FROM HPRE WHERE NOADMISION=@NOADMISION
                UNION ALL
                SELECT FECHAALTAMED FROM HADM WHERE NOADMISION=@NOADMISION
            ) F
            WHERE Fecha IS NOT NULL

            IF @FINIATEN IS NULL SET @FINIATEN = GETDATE()
            IF @FFINATEN IS NULL SET @FFINATEN = @FINIATEN
            IF @FFINATEN < @FINIATEN SET @FFINATEN = @FINIATEN

            SELECT @fechaInicioAtencion = CONVERT(VARCHAR(16), @FINIATEN, 120)
            SELECT @fechaEgreso = CONVERT(VARCHAR(16), @FFINATEN, 120)
            SET @fechaInicioAtencionAU = @fechaInicioAtencion
            SET @fechaEgresoAU = @fechaEgreso
            print '@fechaInicioAtencion=' +@fechaInicioAtencion
            print '@fechaEgreso='+@fechaEgreso
         END --VERIFICACION de fechas en el xml de la factura para poder arreglar a las malas los datos

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
                  finalidadTecnologiaSalud=LEFT(CASE WHEN COALESCE(FINALIDADTGEN.DATO1,'') <>''   THEN COALESCE(FINALIDADTGEN.DATO1,'12')
                     WHEN CIT.FINCONSULTA ='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12')
                     WHEN CIT.FINCONSULTA IS NULL OR CIT.FINCONSULTA=''  OR CIT.FINCONSULTA<='10'
                        THEN CASE WHEN COALESCE( MPE.FINALIDAD,'')<>''
                              THEN  MPE.FINALIDAD ELSE  COALESCE(FINALIDADTGEN.DATO1,'12')
                           END
                     ELSE  COALESCE(FINALIDADTGEN.DATO1,'12')
                  END,2),
                  causaMotivoAtencion='38',
                  CASE WHEN CIT.IDPLAN IN (SELECT DATO FROM USVGS WHERE IDVARIABLE IN ('IDPLANPART','IDPLANPART1', 'IDPLANPART2', 'IDPLANPART3', 'IDPLANPART4', 'IDPLANPART5'))
                     THEN CONVERT(BIGINT,FNOTD.VR_TOTAL)
                     ELSE CONVERT(BIGINT,FNOTD.VR_TOTAL)
                  END, --storres_20250403
                  COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA), MED.TIPO_ID, MED.IDMEDICO
               FROM  FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO
                  INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN MED     ON CIT.IDMEDICO = MED.IDMEDICO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  LEFT JOIN MPE ON MPE.IDPESPECIAL=CIT.IDPESPECIAL AND CIT.CLASEORDEN = 'PYP'
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND   FTRD.N_FACTURA=@N_FACTURA
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
                  ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
                  MED.TIPO_ID,MED.IDMEDICO,CIT.IDDX,
                  CIT.IDDX,COALESCE(CIT.IDDX,'null'),CONVERT(BIGINT,FNOTD.VR_TOTAL),'04',COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(CIT.NFACTURA,@N_FACTURA)
               FROM  FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO
                  INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE  FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA  = @N_FACTURA
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
                        ,codDiagnosticoRelacionado='null'
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
                  tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END,  --20250702 -- STORRES -- ESPERA CAMPO PARA REALIZAR CONFIGURACION
                  codTecnologiaSalud=LEFT(SER.CODCUPS,6), nomTecnologiaSalud=LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
                  cantidadOS=1, MED.TIPO_ID, MED.IDMEDICO, CONVERT(BIGINT,FNOTD.VR_TOTAL),CONVERT(BIGINT,FNOTD.VR_TOTAL),
                  tipoPagoModerador='04',
                  COALESCE(FTRD.VLR_COPAGOS,0), COALESCE(CIT.NFACTURA,@N_FACTURA)
               FROM   FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN CIT     ON FTRD.NOADMISION = CIT.CONSECUTIVO
                  INNER JOIN SER     ON CIT.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  INNER JOIN MED     ON CIT.IDMEDICO=MED.IDMEDICO
               WHERE  FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA  = @N_FACTURA
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
                  finalidadTecnologiaSalud=LEFT(CASE WHEN AUT.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12')
                     WHEN AUT.FINALIDAD IS NULL OR AUT.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12'
                     ELSE COALESCE(FINALIDADTGEN.DATO1,AUT.FINALIDAD,'12')
                  END,2),
                  causaMotivoAtencion='38'
                  , AUT.DXPPAL codDiagnosticoPrincipal  -- EEMC 06-06-2025 SE AGREGA DX PORQUE SON CONSULTAS
                  ,CONVERT(BIGINT,FNOTD.VR_TOTAL)
                  ,CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
                  ,COALESCE(AUTD.NFACTURA,@N_FACTURA),COALESCE(MED.TIPO_ID, @TIPODOC,''), COALESCE(MED.IDMEDICO, @DOCIDAFILIADO,'') --STORRES_20250326
               FROM  FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT
                     AND FTRD.NOITEM       = AUTD.NO_ITEM
                  INNER JOIN AUT     ON AUTD.IDAUT        = AUT.IDAUT
                  INNER JOIN SER     ON AUTD.IDSERVICIO   = SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS    = RIPS_CP.IDCONCEPTORIPS
                  LEFT JOIN TGEN    ON TGEN.TABLA        = 'GENERAL'
                     AND CAMPO             = 'FINALIDADCONSULTA'
                     AND CODIGO            = AUT.FINALIDAD
                  LEFT JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA         = @N_FACTURA
               AND   COALESCE(AUTD.VALOR,0) > 0
               AND   RIPS_CP.ARCHIVO        ='AC'

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
               INSERT INTO @MEDICAMENTOS(codPrestador,numAutorizacion,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                  ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                  ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                  ,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador)
               SELECT @IDPRESTADOR,numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(AUT.NUMAUTORIZA,'null') IN ('',' ','  '), 'null', AUT.NUMAUTORIZA),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                  null,fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,AUT.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,AUT.FECHA,108),5),
                  AUT.DXPPAL,AUT.DXRELACIONADO,'01',dbo.FNK_LIMPIATEXTO(COALESCE(IART.CODCUM,SER.CODCUM),'A-Z0-9-'),LEFT( dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),'0',
                  COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',CONVERT(VARCHAR,CONVERT(INT,AUTD.CANTIDAD),10), CAST(IIF(COALESCE(AUTD.DIAS,0)=0,1,AUTD.DIAS) AS VARCHAR(3)),
                  COALESCE(MED.TIPO_ID, @TIPODOC),COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),CONVERT(BIGINT,FNOTD.VR_TOTAL),CONVERT(BIGINT,FNOTD.VR_TOTAL) ,
                  '04'
                  ,CAST(CONVERT(DECIMAL(14,2),IIF(FTRD.VLR_COPAGOS>0,FTRD.VLR_COPAGOS,0)) AS VARCHAR(20))
                  ,COALESCE(AUTD.NFACTURA,@N_FACTURA)
               FROM  FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT
                     AND FTRD.NOITEM       = AUTD.NO_ITEM
                  INNER JOIN AUT     ON AUTD.IDAUT=AUT.IDAUT
                  INNER JOIN SER     ON AUTD.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  LEFT JOIN IART     ON SER.IDSERVICIO=IART.IDSERVICIO AND PRINCIPAL = 1
                  LEFT JOIN IFFA     ON IART.IDFORFARM=IFFA.IDFORFARM
                  LEFT JOIN IUNI     ON IUNI.IDUNIDAD=IART.IDUNIDAD
                  LEFT  JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA = @N_FACTURA
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
                  ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
                  COALESCE(MED.TIPO_ID, 'CC'), COALESCE(MED.IDMEDICO,@DOCIDAFILIADO), AUT.DXPPAL ,AUT.DXRELACIONADO
                  ,AUT.DXPPAL,CONVERT(BIGINT,FNOTD.VR_TOTAL) ,'04'
                  ,CASE
                     WHEN AUT.IDPLAN IN (DBO.FNK_VALORVARIABLE ('IDPLANPART'),DBO.FNK_VALORVARIABLE ('IDPLANPART2')
                        ,DBO.FNK_VALORVARIABLE ('IDPLANPART3'),DBO.FNK_VALORVARIABLE ('IDPLANPART4')
                        ,DBO.FNK_VALORVARIABLE ('IDPLANPART5'))
                     THEN '0.00'
                     ELSE CASE WHEN COALESCE(FTRD.VLR_COPAGOS,0) >0 THEN COALESCE(FTRD.VLR_COPAGOS,0)
                        ELSE CAST(CONVERT(INT,FTRD.VLR_COPAGOS) AS VARCHAR(20))
                     END
                  END
                  ,COALESCE(AUTD.NFACTURA,@N_FACTURA), 1
               FROM FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT
                     AND FTRD.NOITEM       = AUTD.NO_ITEM
                  INNER JOIN AUT     ON AUTD.IDAUT = AUT.IDAUT
                  INNER JOIN SER     ON AUTD.IDSERVICIO = SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS = RIPS_CP.IDCONCEPTORIPS
                  LEFT  JOIN MED     ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA = @N_FACTURA
               AND   RIPS_CP.ARCHIVO = 'AP'
               AND   COALESCE(FNOTD.VR_TOTAL,0)  > 0

               UPDATE @PROCEDIMIENTOS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad WHERE 1=1
               UPDATE @PROCEDIMIENTOS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2)) WHERE 1=1
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
                  tipoOS=CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END, --20250702 -- STORRES -- ESPERA CAMPO PARA CONFIGURAR
                  codTecnologiaSalud=LEFT(SER.CODCUPS,6),nomTecnologiaSalud=LEFT( dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60),
                  cantidadOS=1,tipoDocumentoIdentificacion=COALESCE(MED.TIPO_ID,@TIPODOC),
                  numDocumentoIdentificacion=COALESCE(MED.IDMEDICO,@DOCIDAFILIADO),
                  CONVERT(BIGINT,FNOTD.VR_TOTAL),
                  CONVERT(BIGINT,FNOTD.VR_TOTAL),
                  tipoPagoModerador='04',
                  CAST(CONVERT(DECIMAL(14,2),IIF(FTRD.VLR_COPAGOS>0,FTRD.VLR_COPAGOS,0)) AS VARCHAR(20)),
                  COALESCE(AUTD.NFACTURA,@N_FACTURA)
               FROM FNOTD INNER JOIN FTRD    ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FNOTD.N_CUOTA=FTRD.N_CUOTA
                  INNER JOIN AUTD    ON FTRD.NOPRESTACION = AUTD.IDAUT
                     AND FTRD.NOITEM       = AUTD.NO_ITEM
                  INNER JOIN AUT     ON AUTD.IDAUT = AUT.IDAUT
                  INNER JOIN FNOT    ON FNOTD.CNSFNOT=FNOT.CNSFNOT
                  INNER JOIN SER ON AUTD.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  LEFT  JOIN MED ON MED.IDMEDICO = IIF(COALESCE(AUT.IDMEDICOSOLICITA,'')='',DBO.FNK_VALORVARIABLE('EPI_MEDICODEFAULT'),AUT.IDMEDICOSOLICITA)
               WHERE  FNOTD.CNSFNOT=@CNSFNOT
               AND FTRD.N_FACTURA = @N_FACTURA
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
            BEGIN --AC
               INSERT INTO @CONSULTAS1(codPrestador,fechaInicioAtencion,numAutorizacion,codConsulta,modalidadGrupoServicioTecSal,grupoServicios,codServicio,
                  finalidadTecnologiaSalud,causaMotivoAtencion,codDiagnosticoPrincipal,codDiagnosticoRelacionado1,codDiagnosticoRelacionado2,
                  codDiagnosticoRelacionado3,tipoDiagnosticoPrincipal,vrServicio,valorPagoModerador,numFEVPagoModerador,tipoDocumentoIdentificacion, numDocumentoIdentificacion, Cantidad)
               SELECT COALESCE(@IDPRESTADOR,'')
                  ,fechaInicioAtencion=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
                  numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(HADM.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', HADM.NOAUTORIZACION),'A-Z0-9-') -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                  ,codConsulta=LEFT(SER.CODCUPS,6),
                  modalidadGrupoServicioTecSal='01',
                  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '01'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
      --          FINALIDADTECNOLOGIASALUD=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'12') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '12' ELSE COALESCE(FINALIDADTGEN.DATO1,'12') END,2),
                  FINALIDADTECNOLOGIASALUD=LEFT(CASE WHEN HPRE.FINALIDAD='10' THEN COALESCE(FINALIDADTGEN.DATO1,'15') WHEN HPRE.FINALIDAD IS NULL OR HPRE.FINALIDAD='' OR COALESCE(FINALIDADTGEN.DATO1,'')='' THEN '15' ELSE COALESCE(FINALIDADTGEN.DATO1,'15') END,2), --20260821 SE AGREGA LA MISMA VALIDACION DE SPK_RIPS_JSON_FTR_IND
                  causaMotivoAtencion='38',COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.DX2,HADM.DXSALIDA2),COALESCE(HCA.DX3,HADM.DXSALIDA3),
                  CASE HCA.TIPODX
                     WHEN 'Presuntivo'   THEN 1
                     WHEN 'Impresion dx' THEN 1
                     WHEN 'Definitivo'   THEN 2
                     WHEN 'Conf Nuevo'   THEN 2
                     WHEN 'Conf Repet'   THEN 3
                     ELSE 1
                  END,
                  CONVERT(BIGINT,FNOTD.VR_TOTAL),
                  FTRD.VLR_COPAGOS,@N_FACTURA, MED.TIPO_ID, MED.IDMEDICO,1
               FROM FNOTD INNER JOIN FTRD ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FTRD.N_CUOTA=FNOTD.N_CUOTA
                  INNER JOIN HPRED ON FTRD.NOPRESTACION=HPRED.NOPRESTACION AND FTRD.NOITEM=HPRED.NOITEM
                  INNER JOIN HPRE ON  HPRED.NOPRESTACION=HPRE.NOPRESTACION AND FTRD.NOADMISION=HPRE.NOADMISION
                  INNER JOIN HADM ON FTRD.NOADMISION=HADM.NOADMISION
                  INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                  LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3
                     FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>''
                     AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
                     ORDER BY HCA.FECHA DESC
                  ) HCA ON HADM.NOADMISION=HCA.NOADMISION
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  INNER JOIN FNOT    ON FNOTD.CNSFNOT=FNOT.CNSFNOT
                  LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOALTA,HADM.IDMEDICOTRA,HADM.IDMEDICOING) END
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND HADM.NOADMISION=@NOADMISION
               AND HPRED.N_FACTURA=@N_FACTURA
               AND COALESCE(HPRED.VALOR,0)>0
               AND COALESCE(HPRED.NOCOBRABLE,0)=0
               AND RIPS_CP.ARCHIVO='AC'

               UPDATE @CONSULTAS1 SET restoPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))%cantidad WHERE 1=1
               UPDATE @CONSULTAS1 SET valorPagoModerador=TRY_CAST(valorPagoModerador AS decimal(14,2))-TRY_CAST(restoPagoModerador AS decimal(14,2)) WHERE 1=1
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
                  SELECT @valorPagoModerador=CONVERT(VARCHAR(20), CAST(valorPagoModerador AS decimal(14,2))/@CANTORI) FROM @CONSULTAS1 WHERE consecutivo=@CNSCONSULTA

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
            BEGIN --AM
               INSERT INTO @MEDICAMENTOS(codPrestador,numAutorizacion,idMIPRES,fechaDispensAdmon,codDiagnosticoPrincipal,codDiagnosticoRelacionado
                  ,tipoMedicamento,codTecnologiaSalud,nomTecnologiaSalud,concentracionMedicamento,unidadMedida,formaFarmaceutica
                  ,unidadMinDispensa,cantidadMedicamento,diasTratamiento,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitMedicamento
                  ,vrServicio,tipoPagoModerador,valorPagoModerador,numFEVPagoModerador, MED, idArticulo)
               SELECT @IDPRESTADOR,
                  numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(HADM.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', HADM.NOAUTORIZACION),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                  null,fechaDispensAdmon=REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5),
                  COALESCE(HCA.IDDX,HADM.DXINGRESO),COALESCE(HCA.DX1,HADM.DXSALIDA1),'01',SER.IDSERVICIO,LEFT(dbo.FNK_LIMPIATEXTO(IART.DESCRIPCION,'0-9 A-Z();:.,'),30),'0',
                  COALESCE(IUNI.HOMOLOGO_RIPS,247),COALESCE(IFFA.HOMOJSON,'null'),'11',1,1,LEFT(MED.TIPO_ID,2),MED.IDMEDICO,
                  CONVERT(BIGINT,FNOTD.VR_TOTAL), --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                  CONVERT(BIGINT,FNOTD.VR_TOTAL), --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                  '04',FTRD.VLR_COPAGOS,COALESCE(@NFACTURA,@N_FACTURA), SER.MEDICAMENTOS, HPRED.IDARTICULO
               FROM FNOTD INNER JOIN FTRD ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FTRD.N_CUOTA=FNOTD.N_CUOTA
                  INNER JOIN HPRED ON FTRD.NOPRESTACION=HPRED.NOPRESTACION AND FTRD.NOITEM=HPRED.NOITEM
                  INNER JOIN HPRE ON  HPRED.NOPRESTACION=HPRE.NOPRESTACION AND FTRD.NOADMISION=HPRE.NOADMISION
                  INNER JOIN HADM ON FTRD.NOADMISION=HADM.NOADMISION
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
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND HADM.NOADMISION=@NOADMISION
               AND HPRED.N_FACTURA=@N_FACTURA
               AND COALESCE(HPRED.VALOR,0)>0
               AND COALESCE(HPRED.NOCOBRABLE,0)=0
               AND COALESCE(HPRED.CANTIDAD,0)>0
               AND RIPS_CP.ARCHIVO='AM';

               BEGIN
                  UPDATE @MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE COALESCE(IART.CODCUM,'') WHEN '' THEN SER.CODCUM ELSE IART.CODCUM END
                  FROM @MEDICAMENTOS A
                     INNER JOIN SER ON SER.IDSERVICIO=A.codTecnologiaSalud
                     INNER JOIN IART ON IART.IDARTICULO=A.IDARTICULO
                  WHERE SER.MEDICAMENTOS=1 AND (ISNULL(A.codTecnologiaSalud,'')='' OR ISNULL(A.codTecnologiaSalud,'') NOT LIKE '%-%')

                  UPDATE @MEDICAMENTOS SET MED=1, codTecnologiaSalud=CASE ISNULL(SER.CODCUM,'') WHEN '' THEN A.codTecnologiaSalud ELSE SER.CODCUM END
                  FROM @MEDICAMENTOS A
                  INNER JOIN SER ON A.codTecnologiaSalud=SER.IDSERVICIO
                  WHERE SER.MEDICAMENTOS=1 AND (ISNULL(codTecnologiaSalud,'')='' OR ISNULL(codTecnologiaSalud,'') NOT LIKE '%-%')

                  UPDATE @MEDICAMENTOS SET codTecnologiaSalud=DBO.FNK_LIMPIATEXTO(codTecnologiaSalud,'0-9-') FROM @MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'
                  UPDATE @MEDICAMENTOS SET codTecnologiaSalud=(stuff((select CONCAT('-',IIF(ISNUMERIC(WORD)=1 AND CONVERT(INT, WORD)>0, CONVERT(INT, WORD),WORD))
                     FROM DBO.FNK_EXPLODE(codTecnologiaSalud,'-') FOR XML PATH('')),1,1,'')
                     )
                  FROM @MEDICAMENTOS A WHERE A.MED=1 AND ISNULL(codTecnologiaSalud,'') LIKE '%-%'
               END
            END
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
                  numAutorizacion=DBO.FNK_LIMPIATEXTO(IIF(COALESCE(HADM.NOAUTORIZACION,'null') IN ('',' ','  '), 'null', HADM.NOAUTORIZACION),'A-Z0-9-'), -- 20250702 -- STORRES -- SE AGREGA VALIDACION PARA QUE LOS CAMPOS VACIOS LOS CAMBIE A NULL
                  LEFT(SER.CODCUPS,6),COALESCE(REPLACE(TGEN.DATO2,' ',''),HADM.VIAINGRESO,'02'),'01',
                  grupoServicios= CASE WHEN COALESCE(SER.RIPS_GRUPO,'')  = '' THEN '02'  ELSE SER.RIPS_GRUPO  END, -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                  codServicio   = CASE WHEN COALESCE(SER.RIPS_CODIGO,'') = '' THEN '325' ELSE SER.RIPS_CODIGO END -- 20250702 -- STORRES SE CAMBIA PARA QUE ENVIE LOS CODIGOS CONFIGURADO
                  ,finalidadTecnologiaSalud=LEFT(COALESCE(FINALIDADTGEN.DATO1,'16') ,2) , -- EEMC: 30-08-2025  SE REMPLAZA POR HOMOLOGACION EN TGEN
                  LEFT(MED.TIPO_ID,2),MED.IDMEDICO,COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
                  COALESCE(HCA.DX1,HADM.DXSALIDA1),COALESCE(HCA.IDDX,HADM.DXINGRESO,HADM.DXEGRESO),
                  CONVERT(BIGINT,FNOTD.VR_TOTAL), --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                  '04',COALESCE(FTRD.VLR_COPAGOS,0),COALESCE(@NFACTURA,@N_FACTURA),HPRED.CANTIDAD,
                  CONVERT(BIGINT,FNOTD.VR_TOTAL) --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
               FROM FNOTD INNER JOIN FTRD ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FTRD.N_CUOTA=FNOTD.N_CUOTA
                  INNER JOIN HPRED ON FTRD.NOPRESTACION=HPRED.NOPRESTACION AND FTRD.NOITEM=HPRED.NOITEM
                  INNER JOIN HPRE ON  HPRED.NOPRESTACION=HPRE.NOPRESTACION AND FTRD.NOADMISION=HPRE.NOADMISION
                  INNER JOIN HADM ON FTRD.NOADMISION=HADM.NOADMISION
                  INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  LEFT JOIN TGEN ON HADM.VIAINGRESO = TGEN.CODIGO AND TABLA = 'General' AND CAMPO = 'VIADEINGRESO'
                  LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'') END
                  LEFT JOIN (SELECT TOP 1 HCA.NOADMISION,HCA.TIPODX,HCA.IDDX,COALESCE(HCA.DX1,'')DX1,COALESCE(HCA.DX2,'')DX2,COALESCE(DX3,'')DX3
                     FROM HCA WHERE NOADMISION=@NOADMISION AND COALESCE(IDDX,'')<>''
                     AND HCA.CLASE='HC' AND PROCEDENCIA='QX' AND COALESCE(ANULADA,0)=0 AND CLASEPLANTILLA<>DBO.FNK_VALORVARIABLE('HCPLANTILLAEPI')
                     ORDER BY HCA.FECHA DESC
                  ) HCA ON HADM.NOADMISION=HCA.NOADMISION
                  --- EEMC78 30-08-2025 SE ADICIONA PARA HOMOLOGACION
                  INNER JOIN PRE ON SER.PREFIJO = PRE.PREFIJO
                  LEFT JOIN TGEN FINALIDADTGEN ON FINALIDADTGEN.TABLA='GENERAL' AND FINALIDADTGEN.CAMPO='FINALIDAD' AND FINALIDADTGEN.CODIGO=PRE.FINALIDAD
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND HADM.NOADMISION=@NOADMISION
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
            BEGIN --AT
               INSERT INTO @OTROSSER(codPrestador,numAutorizacion,idMIPRES,fechaSuministroTecnologia,tipoOS,codTecnologiaSalud,nomTecnologiaSalud
                  ,cantidadOS,tipoDocumentoIdentificacion,numDocumentoIdentificacion,vrUnitOS,vrServicio,tipoPagoModerador
                  ,valorPagoModerador,numFEVPagoModerador)
               SELECT @IDPRESTADOR ,DBO.FNK_LIMPIATEXTO(COALESCE(HADM.NOAUTORIZACION,'null'),'A-Z0-9-'),null
                  , CASE WHEN COALESCE(@fechaInicioAtencion,'') != '' THEN @fechaInicioAtencion
                     ELSE REPLACE(CONVERT(VARCHAR,HPRE.FECHA,102),'.','-')+' '+LEFT(CONVERT(VARCHAR,HPRE.FECHA,108),5)
                  END
                  , tipoOS = CASE WHEN COALESCE(SER.TIPOOTRO,'0')='0' THEN  '04'  ELSE IIF(LEN(SER.TIPOOTRO)='1', CONCAT('0',SER.TIPOOTRO),SER.TIPOOTRO) END --20250702 -- STORRES -- A A ESPERA QUE SE CREE EL CAMPO PARA CONFIGURAR
                  , LEFT(IIF(RIPS_CP.IDCONCEPTORIPS=DBO.FNK_VALORVARIABLE('IDMATERIALESRIPS'), SER.IDSERVICIO, SER.CODCUPS),6),LEFT(dbo.FNK_LIMPIATEXTO(SER.DESCSERVICIO,'0-9 A-Z();:.,'),60)
                  , 1,MED.TIPO_ID,MED.IDMEDICO
                  ,CONVERT(BIGINT,FNOTD.VR_TOTAL)--20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                  ,CONVERT(BIGINT,FNOTD.VR_TOTAL) --20250618 - STORRES - SE AGREGA VALIDACION DE PAQUETES. RESOLUCION INDICA QUE CUANDO LA MODALIDAD DEPAGO ES DIFERENTE A EVENTO SE REPORTA 0
                  ,'04',CONVERT(DECIMAL(14,2),COALESCE(HPRED.VALORCOPAGO,0)) ,COALESCE(@NFACTURA,@N_FACTURA)
               FROM FNOTD INNER JOIN FTRD ON FNOTD.N_FACTURA=FTRD.N_FACTURA AND FTRD.N_CUOTA=FNOTD.N_CUOTA
                  INNER JOIN HPRED ON FTRD.NOPRESTACION=HPRED.NOPRESTACION AND FTRD.NOITEM=HPRED.NOITEM
                  INNER JOIN HPRE ON  HPRED.NOPRESTACION=HPRE.NOPRESTACION AND FTRD.NOADMISION=HPRE.NOADMISION
                  INNER JOIN HADM ON FTRD.NOADMISION=HADM.NOADMISION
                  INNER JOIN SER ON HPRED.IDSERVICIO=SER.IDSERVICIO
                  INNER JOIN RIPS_CP ON SER.CODIGORIPS=RIPS_CP.IDCONCEPTORIPS
                  LEFT JOIN MED ON MED.IDMEDICO= CASE WHEN COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'')='' THEN HPRE.IDMEDICO ELSE COALESCE(HADM.IDMEDICOTRA,HADM.IDMEDICOING,HADM.IDMEDICOALTA,'') END
               WHERE FNOTD.CNSFNOT=@CNSFNOT
               AND HADM.NOADMISION=@NOADMISION
               AND HPRED.N_FACTURA=@N_FACTURA
               AND COALESCE(HPRED.VALOR,0)>0
               AND COALESCE(HPRED.NOCOBRABLE,0)=0
               AND COALESCE(HPRED.CANTIDAD,0)>0
               AND RIPS_CP.ARCHIVO='AT'
            END
         END
         ELSE
         BEGIN
            RAISERROR ('No se encontro la procedencia de la factura', 16, 1);
            RETURN
         END

         SELECT @VALORCOPAGOS=0,@VALORCOPAGOACU=0,@SUM_AC=0,@SUM_AP=0,@SUM_AM=0,@SUM_AT=0
         SELECT @VALORCOPAGOS = VR_TOTAL FROM FNOT WHERE CNSFNOT=@CNSFNOT AND N_fACTURA=@N_FACTURA
         SELECT @SUM_AC = COALESCE(SUM(CAST(COALESCE(vrServicio,0) AS DECIMAL(14,4))),0) FROM @CONSULTAS
         SELECT @SUM_AP = COALESCE(SUM(CAST(COALESCE(vrServicio,0) AS DECIMAL(14,4))),0) FROM @PROCEDIMIENTOS
         SELECT @SUM_AM = COALESCE(SUM(CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,4))),0) FROM @MEDICAMENTOS
         SELECT @SUM_AT = COALESCE(SUM(CAST(COALESCE(vrServicio,0) AS DECIMAL(14,4))),0) FROM @OTROSSER
         SET @VALORCOPAGOACU = @SUM_AC + @SUM_AP + @SUM_AM + @SUM_AT
         PRINT '@SERVICOS='+CONVERT(VARCHAR(20),@VALORCOPAGOACU,2)
         PRINT '@VALORSERVICIOS='+CONVERT(VARCHAR(20),@VALORCOPAGOS,2)
         PRINT '@DIFERENCIA='+CONVERT(VARCHAR(20),ABS(@VALORCOPAGOS-@VALORCOPAGOACU),2)

         IF (@VALORCOPAGOS - @VALORCOPAGOACU) <> 0
            AND ABS(@VALORCOPAGOS - @VALORCOPAGOACU) < 100
         BEGIN
            SET @DIFE = @VALORCOPAGOS - @VALORCOPAGOACU
            PRINT '@AJUSTE_VR_SERVICIO='+CONVERT(VARCHAR(20),@DIFE,2)
            SET @CONSE=0

            SELECT TOP 1 @CONSE=CONSECUTIVO FROM @CONSULTAS WHERE CAST(COALESCE(vrServicio,0) AS DECIMAL(14,2)) > 0 ORDER BY CONSECUTIVO
            IF COALESCE(@CONSE,0)>0
            BEGIN
               UPDATE @CONSULTAS
               SET vrServicio = CASE
                     WHEN @DIFE < 0 THEN CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),0) AS INT)
                     ELSE CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,0) AS INT)
                  END
               WHERE CONSECUTIVO = @CONSE
            END
            ELSE
            BEGIN
               SELECT TOP 1 @CONSE=CONSECUTIVO FROM @PROCEDIMIENTOS WHERE CAST(COALESCE(vrServicio,0) AS DECIMAL(14,2)) > 0 ORDER BY CONSECUTIVO DESC
               IF COALESCE(@CONSE,0)>0
               BEGIN
                  UPDATE @PROCEDIMIENTOS
                  SET vrServicio = CASE
                        WHEN @DIFE < 0 THEN CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),0) AS INT)
                        ELSE CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,0) AS INT)
                     END
                  WHERE CONSECUTIVO = @CONSE
               END
               ELSE
               BEGIN
                  SELECT TOP 1 @CONSE=CONSECUTIVO FROM @MEDICAMENTOS WHERE CAST(COALESCE(vrServicio,'0') AS DECIMAL(14,2)) > 0 ORDER BY CONSECUTIVO DESC
                  IF COALESCE(@CONSE,0)>0
                  BEGIN
                     UPDATE @MEDICAMENTOS
                     SET vrServicio = CONVERT(VARCHAR(15), CASE
                           WHEN @DIFE < 0 THEN CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),0) AS INT)
                           ELSE CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,0) AS INT)
                        END)
                     WHERE CONSECUTIVO = @CONSE
                  END
                  ELSE
                  BEGIN
                     SELECT TOP 1 @CONSE=CONSECUTIVO FROM @OTROSSER WHERE CAST(COALESCE(vrServicio,0) AS DECIMAL(14,2)) > 0 ORDER BY CONSECUTIVO DESC
                     IF COALESCE(@CONSE,0)>0
                     BEGIN
                        UPDATE @OTROSSER
                        SET vrServicio = CASE
                              WHEN @DIFE < 0 THEN CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) - ABS(@DIFE),0) AS INT)
                              ELSE CAST(ROUND(CAST(vrServicio AS DECIMAL(14,2)) + @DIFE,0) AS INT)
                           END
                        WHERE CONSECUTIVO = @CONSE
                     END
                  END
               END
            END
         END

         --SELECT @VALORCOPAGOS =VALORCOPAGO FROM FTR WHERE N_fACTURA=@N_FACTURA
         --SELECT @VALORCOPAGOACU=SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))) FROM @CONSULTAS
         --SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @PROCEDIMIENTOS
         --SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @MEDICAMENTOS
         --SELECT @VALORCOPAGOACU=COALESCE(@VALORCOPAGOACU,0)+COALESCE(SUM(CONVERT(INT,CAST(COALESCE(valorPagoModerador,'0') AS DECIMAL(14,2)))),0) FROM @OTROSSER
         --SELECT @DIF=ABS(@VALORCOPAGOS-@VALORCOPAGOACU)
         --PRINT '@VALORCOPAGOACU='+CONVERT(VARCHAR(20),@VALORCOPAGOACU)
         --PRINT '@VALORCOPAGOS='+CONVERT(VARCHAR(20),@VALORCOPAGOS)
         --PRINT '@DIFERENCIA='+CONVERT(VARCHAR(20),@DIF)

         --IF @DIF <10
         --BEGIN
         --   SELECT TOP 1 @CONSE=CONSECUTIVO FROM @CONSULTAS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
         --   if COALESCE(@CONSE,0)>0
         --   BEGIN
         --      UPDATE @CONSULTAS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE
         --   END
         --   ELSE
         --   BEGIN
         --      SELECT TOP 1 @CONSE=CONSECUTIVO FROM @PROCEDIMIENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
         --      if COALESCE(@CONSE,0)>0
         --      BEGIN
         --         UPDATE @PROCEDIMIENTOS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE
         --      END
         --      ELSE
         --      BEGIN
         --         SELECT TOP 1 @CONSE=CONSECUTIVO FROM @MEDICAMENTOS WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
         --         if COALESCE(@CONSE,0)>0
         --         BEGIN
         --            UPDATE @MEDICAMENTOS SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE
         --         END
         --         ELSE
         --         BEGIN
         --            SELECT TOP 1 @CONSE=CONSECUTIVO FROM @OTROSSER WHERE CONVERT(DECIMAL(14,2),valorPagoModerador)>0
         --            if COALESCE(@CONSE,0)>0
         --            BEGIN
         --               UPDATE @OTROSSER SET valorPagoModerador=CAST(CAST(valorPagoModerador AS DECIMAL(14,2))+@DIF AS VARCHAR(20))   WHERE CONSECUTIVO=@CONSE
         --            END
         --         END
         --      END
         --   END
         --END
         PRINT '@ESMODERADORAENFTR='+@ESMODERADORAENFTR
         PRINT '@CONCEPTORECAUDOICI='+@CONCEPTORECAUDOICI
         PRINT '@TIPOUSU='+@TIPOUSU
         PRINT '@conceptoRecaudo='+@conceptoRecaudo
         /* Validacion RIPS/SISPRO: dx relacionados no pueden repetir el principal ni entre si */
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado1 = 'null'
         WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado1) = UPPER(codDiagnosticoPrincipal)
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado2 = 'null'
         WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado2) = UPPER(codDiagnosticoPrincipal)
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
         WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoPrincipal)
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado2 = 'null'
         WHERE COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado2) = UPPER(codDiagnosticoRelacionado1)
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
         WHERE COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado1,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoRelacionado1)
         UPDATE @CONSULTAS SET codDiagnosticoRelacionado3 = 'null'
         WHERE COALESCE(codDiagnosticoRelacionado3,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado2,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado3) = UPPER(codDiagnosticoRelacionado2)
         UPDATE @MEDICAMENTOS SET codDiagnosticoRelacionado = 'null'
         WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado) = UPPER(codDiagnosticoPrincipal)
         UPDATE @PROCEDIMIENTOS SET codDiagnosticoRelacionado = 'null'
         WHERE COALESCE(codDiagnosticoPrincipal,'') NOT IN ('','null')
            AND COALESCE(codDiagnosticoRelacionado,'') NOT IN ('','null')
            AND UPPER(codDiagnosticoRelacionado) = UPPER(codDiagnosticoPrincipal)
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
                  @codPrestador = codPrestador
                  ,@fechaInicioAtencion = fechaInicioAtencion
                  ,@numAutorizacion = numAutorizacion
                  ,@codConsulta = codConsulta
                  ,@modalidadGrupoServicioTecSal = modalidadGrupoServicioTecSal
                  ,@grupoServicios = grupoServicios
                  ,@codServicio = codServicio
                  ,@finalidadTecnologiaSalud = finalidadTecnologiaSalud
                  ,@causaMotivoAtencion = causaMotivoAtencion
                  ,@codDiagnosticoPrincipal = IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4 , 'null', codDiagnosticoPrincipal )
                  ,@codDiagnosticoRelacionado1 = IIF(LEN(COALESCE(codDiagnosticoRelacionado1,''))<>4 OR UPPER(codDiagnosticoRelacionado1)=UPPER(codDiagnosticoPrincipal) OR COALESCE(codDiagnosticoRelacionado1,'') IN ('null',''), 'null', codDiagnosticoRelacionado1 )
                  ,@codDiagnosticoRelacionado2 = IIF(LEN(COALESCE(codDiagnosticoRelacionado2,''))<>4 OR UPPER(codDiagnosticoRelacionado2)=UPPER(codDiagnosticoPrincipal) OR UPPER(codDiagnosticoRelacionado2)=UPPER(codDiagnosticoRelacionado1) OR COALESCE(codDiagnosticoRelacionado2,'') IN ('null',''), 'null', codDiagnosticoRelacionado2 )
                  ,@codDiagnosticoRelacionado3 = IIF(LEN(COALESCE(codDiagnosticoRelacionado3,''))<>4 OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoPrincipal) OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoRelacionado1) OR UPPER(codDiagnosticoRelacionado3)=UPPER(codDiagnosticoRelacionado2) OR COALESCE(codDiagnosticoRelacionado3,'') IN ('null',''), 'null', codDiagnosticoRelacionado3 )
                  ,@tipoDiagnosticoPrincipal   = IIF(LEN(tipoDiagnosticoPrincipal)<2,'01',COALESCE(tipoDiagnosticoPrincipal,'01') )
                  ,@vrServicio = vrServicio
                  ,@tipoPagoModerador = '04'
                  ,@valorPagoModerador = valorPagoModerador
                  ,@numFEVPagoModerador =  COALESCE(numFEVPagoModerador,'')
                  ,@consecutivo = CAST(consecutivo AS VARCHAR(4))
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
               IF COALESCE(@codDiagnosticoPrincipal, '') NOT IN ('','null')
                  SET @PLANO+='"codDiagnosticoPrincipal": "'+@codDiagnosticoPrincipal+'",'
               IF COALESCE(@codDiagnosticoRelacionado1, '') NOT IN ('','null')
                  SET @PLANO+='"codDiagnosticoRelacionado1": "'+@codDiagnosticoRelacionado1+'",'
               IF COALESCE(@codDiagnosticoRelacionado2, '') NOT IN ('','null')
                  SET @PLANO+='"codDiagnosticoRelacionado2": "'+@codDiagnosticoRelacionado2+'",'
               IF COALESCE(@codDiagnosticoRelacionado3, '') NOT IN ('','null')
                  SET @PLANO+='"codDiagnosticoRelacionado3": "'+@codDiagnosticoRelacionado3+'",'
               SET @PLANO+= '"tipoDiagnosticoPrincipal": "'+@tipoDiagnosticoPrincipal+'",'
               SET @PLANO+= '"tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
               SET @PLANO+= '"numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
               SET @PLANO+='"vrServicio": '+CAST(@vrServicio AS VARCHAR)+','
               SET @PLANO+= '"conceptoRecaudo":"'+
                  CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05'
                     WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
                  -- WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN '03'
                     WHEN (@TIPOUSU IN ('01', '02', '04') AND @conceptoRecaudo = '01') THEN IIF(@TIPOUSU IN('03','11'),'03',@conceptoRecaudo) --20260821 SE AGREGA LA MISMA VALIDACION DE SPK_RIPS_JSON_FTR_IND
                     ELSE @conceptoRecaudo
                  END +'",' --YCARRILLO
               SET @PLANO+='"valorPagoModerador":'+@valorPagoModerador+','
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
                  ,@numAutorizacion_med=numAutorizacion
                  ,@idMIPRES=idMIPRES
                  ,@fechaDispensAdmon=fechaDispensAdmon
                  ,@codDiagnosticoPrincipal=  IIF(LEN(COALESCE(codDiagnosticoPrincipal,''))<>4 , 'null', codDiagnosticoPrincipal )
                  ,@codDiagnosticoRelacionado= IIF(LEN(COALESCE(codDiagnosticoRelacionado,''))<>4 , 'null', codDiagnosticoRelacionado )
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
               --IF COALESCE(@numAutorizacion_med,'')<>''
               --   SET @PLANO+='"numAutorizacion": "'+@numAutorizacion_med+'",'
               SET @PLANO+=' "idMIPRES":'+IIF(coalesce(@idMIPRES,'')='' , 'null',CONCAT('"',@idMIPRES,'"'))+',' --STORRES 20250507 - Se cambia @idMIPRES is null por coalesce(@idMIPRES,'')=''
               SET @PLANO+= '"fechaDispensAdmon":"'+@fechaDispensAdmon+'",'
               IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
                  SET @PLANO+= '"codDiagnosticoPrincipal":"'+@codDiagnosticoPrincipal+'",'
               IF COALESCE(@codDiagnosticoRelacionado, '') <> ''
                  SET @PLANO+= '"codDiagnosticoRelacionado":"'+@codDiagnosticoRelacionado+'",'
               SET @PLANO+= '"tipoMedicamento":"'+COALESCE(@tipoMedicamento,'')+'",'
               SET @PLANO+= '"codTecnologiaSalud":"'+COALESCE(DBO.FNK_LIMPIATEXTO(@codTecnologiaSalud,'0-9- _ A-Z'),'')+'",'
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
               SELECT @codPrestador = codPrestador,
                  @fechaInicioAtencion = fechaInicioAtencion,
                  @idMIPRES = idMIPRES,
                  @numAutorizacion = numAutorizacion,
                  @codProcedimiento = codProcedimiento,
                  @vialngresoServicioSalud = vialngresoServicioSalud,
                  @modalidadGrupoServicioTecSal = modalidadGrupoServicioTecSal,
                  @grupoServicios = grupoServicios,
                  @codServicio = codServicio,
                  @finalidadTecnologiaSalud = finalidadTecnologiaSalud,
                  @tipoDocumentoIdentificacion = tipoDocumentoIdentificacion,
                  @numDocumentoIdentificacion = numDocumentoIdentificacion,
                  @codDiagnosticoPrincipal = codDiagnosticoPrincipal,
                  @codDiagnosticoRelacionado = codDiagnosticoRelacionado,
                  @codComplicacion = codComplicacion,
                  @vrServicio = vrServicio,
                  @tipoPagoModerador =tipoPagoModerador,
                  @valorPagoModerador = valorPagoModerador,
                  @numFEVPagoModerador = COALESCE(numFEVPagoModerador,''),
                  @consecutivo = CAST(consecutivo AS VARCHAR(4))
               FROM @PROCEDIMIENTOS
               WHERE consecutivo=@NRO

               IF @NRO > 1 SET @PLANO+=','

               SET @PLANO+='{'
               SET @PLANO+=' "codPrestador":"'+@codPrestador+'",'
               SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencion+'",'
               SET @PLANO+=' "idMIPRES":'+IIF(coalesce(@idMIPRES,'')='' , 'null',CONCAT('"',@idMIPRES,'"'))+',' --STORRES 20250507 - Se cambia @idMIPRES is null por coalesce(@idMIPRES,'')=''
               IF COALESCE(@numAutorizacion,'')<>''
                  SET @PLANO+=' "numAutorizacion":"'+@numAutorizacion+'",'
               SET @PLANO+=' "codProcedimiento":"'+@codProcedimiento+'",'
               SET @PLANO+=' "viaIngresoServicioSalud":"'+@vialngresoServicioSalud+'",'
               SET @PLANO+=' "modalidadGrupoServicioTecSal":"'+@modalidadGrupoServicioTecSal+'",'
               SET @PLANO+=' "grupoServicios":"'+@grupoServicios+'",'
               SET @PLANO+=' "codServicio":'+@codServicio+','
               SET @PLANO+=' "finalidadTecnologiaSalud":"'+@finalidadTecnologiaSalud+'",'
               SET @PLANO+=' "tipoDocumentoIdentificacion":"'+@tipoDocumentoIdentificacion+'",'
               SET @PLANO+=' "numDocumentoIdentificacion":"'+@numDocumentoIdentificacion+'",'
               SET @PLANO+=' "codDiagnosticoPrincipal":"'+ISNULL( NULLIF(@codDiagnosticoPrincipal,''), 'null')+'",'
               SET @PLANO+=' "codDiagnosticoRelacionado":"'+ISNULL( NULLIF(@codDiagnosticoRelacionado,''), 'null')+'",'
               SET @PLANO+=' "codComplicacion":"'+ISNULL( NULLIF(@codComplicacion,''), 'null')+'",'
               SET @PLANO+=' "vrServicio":'+CAST(CONVERT(INT,@vrServicio) AS VARCHAR)+','
               SET @PLANO+= '"conceptoRecaudo":"'
                  +CASE WHEN TRY_CAST(@valorPagoModerador AS decimal(14,2))<=0 THEN '05'
                     WHEN COALESCE(@ESMODERADORAENFTR,'') <> '' THEN @ESMODERADORAENFTR
                     ELSE @conceptoRecaudo
                  END +'",' --YCARRILLO
               SET @PLANO+=' "valorPagoModerador":'+LEFT(@valorPagoModerador,CHARINDEX('.',@valorPagoModerador,1)-1)+','
               SET @PLANO+='"numFEVPagoModerador": "'+ CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' OR COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
               SET @PLANO+=' "consecutivo":'+@consecutivo+''
               SET @PLANO+=' }'
               SELECT @NRO+=1
            END

            SET @PLANO  += ']'
            --PRINT 'DESPUES DE AP '+@PLANO
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
               SET @PLANO+='"numFEVPagoModerador": "'+ CASE WHEN COALESCE(@numFEVPagoModerador,'')<>'' AND COALESCE(@numFEVPagoModerador,'')<>@N_fACTURA THEN @numFEVPagoModerador ELSE 'null' END+'",'
               SET @PLANO+= '"consecutivo":'+@consecutivo+''
               SET @PLANO+='}'
               SELECT @NRO+=1
            END
            SET @PLANO += ']'
            --PRINT 'DESPUES DE AT '+@PLANO 
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
                  SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencionAU+'",'
                  SET @PLANO+=' "causaMotivoAtencion":"'+@causaMotivoAtencion+'",'
                  IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
                     SET @PLANO+=' "codDiagnosticoPrincipal":"'+UPPER (@codDiagnosticoPrincipal)+'",'
                  IF COALESCE(@codDiagnosticoPrincipalE, '') <> ''
                     SET @PLANO+=' "codDiagnosticoPrincipalE":"'+UPPER(@codDiagnosticoPrincipalE)+'",'
                  SET @PLANO+=' "codDiagnosticoRelacionadoE1":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE1,''))<>4 , 'null', @codDiagnosticoRelacionadoE1 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "codDiagnosticoRelacionadoE2":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE2,''))<>4 , 'null', @codDiagnosticoRelacionadoE2 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "codDiagnosticoRelacionadoE3":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE3,''))<>4 , 'null', @codDiagnosticoRelacionadoE3 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "condicionDestinoUsuarioEgreso":"'+@condicionDestinoUsuarioEgreso+'",'
                  SET @PLANO+=' "codDiagnosticoCausaMuerte":'+CASE WHEN COALESCE(@codDiagnosticoCausaMuerte,'') IN ('','null') THEN 'null' ELSE '"'+@codDiagnosticoCausaMuerte+'"' END+','
                  SET @PLANO+=' "fechaEgreso":"'+@fechaEgresoAU+'",'
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
                  SET @PLANO+=' "fechaInicioAtencion":"'+@fechaInicioAtencionAU+'",'
                  IF COALESCE(@numAutorizacion,'')<>''
                     SET @PLANO+=' "numAutorizacion":"'+@numAutorizacion+'",'
                  SET @PLANO+=' "causaMotivoAtencion":"'+@causaMotivoAtencion+'",'
                  IF COALESCE(@codDiagnosticoPrincipal, '') <> ''
                     SET @PLANO+=' "codDiagnosticoPrincipal":"'+UPPER (@codDiagnosticoPrincipal)+'",'
                  IF COALESCE(@codDiagnosticoPrincipalE, '') <> ''
                     SET @PLANO+=' "codDiagnosticoPrincipalE":"'+UPPER(@codDiagnosticoPrincipalE)+'",'
                  SET @PLANO+=' "codDiagnosticoRelacionadoE1":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE1,''))<>4 , 'null', @codDiagnosticoRelacionadoE1 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "codDiagnosticoRelacionadoE2":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE2,''))<>4 , 'null', @codDiagnosticoRelacionadoE2 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "codDiagnosticoRelacionadoE3":"'+IIF(LEN(COALESCE(@codDiagnosticoRelacionadoE3,''))<>4 , 'null', @codDiagnosticoRelacionadoE3 )+'",' -- STORRES 20250507
                  SET @PLANO+=' "codComplicacion":"'+COALESCE(@codComplicacion,'')+'",'
                  SET @PLANO+=' "condicionDestinoUsuarioEgreso":"'+@condicionDestinoUsuarioEgreso+'",'
                  SET @PLANO+=' "codDiagnosticoCausaMuerte":'+CASE WHEN COALESCE(@codDiagnosticoCausaMuerte,'') IN ('','null') THEN 'null' ELSE '"'+@codDiagnosticoCausaMuerte+'"' END+','
                  SET @PLANO+=' "fechaEgreso":"'+@fechaEgresoAU+'",'
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
      END

      IF @PROCEDENCIA<>'FINANCIERO'
      BEGIN
         SET @PLANO += '}' --SERVICIOS
         SET @PLANO += '}' --CADA USUARIO
         SET @PLANO += ']'--USUARIOS
         SET @PLANO += '}'--FIN

         SELECT @PLANO=REPLACE(@PLANO,'},]','}]')
         SELECT @PLANO=REPLACE(@PLANO,'"null"','null')

         SELECT @PLANO = '{"rips": '+@PLANO+',"xmlFevFile": "@XMLFEVFILE"}'
      END
      END /* @NC_DESDE_FTR = 0 */
   END
   ELSE
   BEGIN
      SELECT @PLANO = '{"rips": null,"xmlFevFile": "@XMLFEVFILE"}'
   END
   BEGIN
      select @base64 = cast('' as xml).value('xs:base64Binary(sql:column("binaryValue"))', 'varchar(max)')
      from (
         select [binaryValue] = cast(dbo.FNK_AttachedDocument(@CNSFNOT,@CLASE) as varbinary(max))
      ) as conv;
      SELECT @PLANO=REPLACE(@PLANO,'@XMLFEVFILE',@base64)
   END
   IF COALESCE(@URL_PATH,'')<>''
   BEGIN
      SELECT @N_FACTURA=@N_FACTURA+'.json'
      EXEC SPK_GUARDAR_ARCHIVO @PLANO, @URL_PATH, @N_FACTURA
      SELECT @PLANO= @URL_PATH+IIF(RIGHT(@URL_PATH,1)='\','','\')+@N_FACTURA
   END

   PRINT 'SPK_RIPS_JSON_NDBCR_IND'
END

