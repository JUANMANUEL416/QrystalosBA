CREATE OR ALTER PROCEDURE DBO.SPQ_RIPS
@JSON  NVARCHAR(MAX)
WITH   ENCRYPTION
AS
DECLARE @PARAMETROS NVARCHAR(MAX)
   , @METODO      VARCHAR(100)
   , @USUARIO     VARCHAR(20)
   , @TIPODOC     VARCHAR(10)
   , @CNSDOC      VARCHAR(20)
   , @JsonSolicitud NVARCHAR(MAX)
   , @JsonRespuesta NVARCHAR(MAX)
   , @ResultadosValidacion NVARCHAR(MAX)
   , @SUCCESS     BIT = 0
   , @CUV         VARCHAR(256)
   , @FRADICACION DATETIME
   , @DATOS       VARCHAR(MAX)
   , @USUMARCA    VARCHAR(20)
   , @CNSCXC      VARCHAR(20)
   , @MARCAFAC    BIT
   , @ISVALIDACUV BIT
   , @FECHAVAL    DATETIME
   , @FECHAINI    DATETIME, @FECHAFIN DATETIME
   , @IDTERCERO   VARCHAR(20) ,@IDPLAN VARCHAR(6) ,@PROCEDENCIA VARCHAR(20)
   , @NOMBREXML   VARCHAR(256) ,@XML VARCHAR(MAX)
DECLARE @TBLERRORES TABLE(ERROR VARCHAR(200));
DECLARE @CMD VARCHAR(4000)

BEGIN
   SELECT @USUARIO = USUARIO
      ,@PARAMETROS = PARAMETROS
      ,@METODO = METODO
   FROM OPENJSON (@json)
   WITH (
      MODELO         VARCHAR(100)     '$.MODELO',
      METODO         VARCHAR(100)     '$.METODO',
      USUARIO        VARCHAR(100)     '$.USUARIO',
      PARAMETROS     NVARCHAR(MAX)  AS JSON
   )

   SELECT @TIPODOC = JSON_VALUE(@PARAMETROS, '$.TIPODOC')
      ,@CNSDOC = JSON_VALUE(@PARAMETROS, '$.CNSDOC')

   IF @METODO = 'GET_DATOS'
   BEGIN
      SELECT OK = 'OK'

      IF @TIPODOC = 'FV'
      BEGIN
         SELECT CUV, FRADICA_RIPS, JSON_RESPUESTA, JSON_ENVIO
         FROM FTRJSON WHERE CNSFCT = @CNSDOC
      END
      IF @TIPODOC IN('NC','ND')
      BEGIN
         SELECT CUV, FRADICA_RIPS, JSON_RESPUESTA, JSON_ENVIO
         FROM FNOTJSON
         WHERE CNSFNOT = @CNSDOC
         AND CLASE=CASE WHEN @TIPODOC='NC' THEN 'C' ELSE 'D' END
      END
      IF @TIPODOC = 'NA'
      BEGIN
         SELECT CUV, FRADICA_RIPS, JSON_RESPUESTA, JSON_ENVIO
         FROM FNOTJSON
         WHERE CNSFNOT = @CNSDOC
         AND CLASE='A'
      END
      SELECT URLBASE=CASE WHEN DBO.FNK_VALORVARIABLE('BDATA_PRODUCCION')<>DB_NAME()
         THEN  DBO.FNK_VALORVARIABLE('URL_SERV_RIPS_PRUEBA')
         ELSE 'OK' END
   END

   IF @METODO = 'GET_MARCADOS'
   BEGIN
      SELECT OK = 'OK'
      SELECT CNSFCT, N_FACTURA, CONVERT(VARCHAR,FTR.F_FACTURA,103)F_FACTURA, PROCEDENCIA, 'Pendiente' ESTADO FROM FTR WHERE MARCAFEVRIPS = 1 AND USUARIO_MARCAFEVRIPS = @USUARIO AND COALESCE(CUV,'')=''
   END

   IF @METODO = 'SET_DATOS'
   BEGIN
      SELECT @JsonRespuesta = JSON_RESPUESTA, @JsonSolicitud = JSON_ENVIO, @ISVALIDACUV = ISVALIDACUV
      FROM OPENJSON (@PARAMETROS)
      WITH (
         JSON_RESPUESTA     NVARCHAR(MAX)  AS JSON, JSON_ENVIO     NVARCHAR(MAX)  AS JSON, ISVALIDACUV BIT
      )
      SELECT @SUCCESS = JSON_VALUE(@JsonRespuesta,'$.ResultState')

      PRINT '@JsonRespuesta >'  + COALESCE(@JsonRespuesta,' SIN @JsonRespuesta')

      SELECT @CUV = JSON_VALUE(@JsonRespuesta,'$.CodigoUnicoValidacion')
      SELECT @FRADICACION = TRY_CAST(JSON_VALUE(@JsonRespuesta, '$.FechaRadicacion') AS DATETIME2)
      IF @TIPODOC = 'FV'
      BEGIN
         BEGIN TRY
            IF COALESCE(@ISVALIDACUV,0) = 1 -- VIENE DE VALIDAR CUV PORQUE YA ESTABA VALIDADO
            BEGIN
               UPDATE FTR
               SET FRADICA_RIPS = CAST(@FRADICACION AS DATETIME2)
                  ,CUV = @CUV
               WHERE CNSFCT = @CNSDOC

               IF NOT EXISTS (SELECT 1 FROM FTRJSON WHERE CNSFCT = @CNSDOC)
               BEGIN
                  INSERT INTO FTRJSON (CNSFCT, JSON_ENVIO,JSON_RESPUESTA, CUV, FRADICA_RIPS)
                  SELECT @CNSDOC, @JsonSolicitud , @JSONRESPUESTA, @CUV, CAST(@FRADICACION AS DATETIME2)
               END
               ELSE
               BEGIN
                  UPDATE FTRJSON
                  SET FRADICA_RIPS = CAST(@FRADICACION AS DATETIME2)
                     ,JSON_ENVIO = @JsonSolicitud
                     ,JSON_RESPUESTA = @JSONRESPUESTA
                     ,CUV = @CUV
                  WHERE CNSFCT = @CNSDOC
               END
               DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'
            END
            ELSE
            BEGIN
               SELECT @SUCCESS = ISNULL(JSON_VALUE(@JsonRespuesta, '$.ResultState'), JSON_VALUE(@JsonRespuesta, '$.errores.resultState'))
               IF COALESCE(@SUCCESS, 0) = 0
               BEGIN
                  PRINT '@JsonRespuesta >'  + COALESCE(@JsonRespuesta,' SIN @JsonRespuesta')

                  SET @ResultadosValidacion = ISNULL(JSON_QUERY(@JsonRespuesta, '$.ResultadosValidacion'), ISNULL(JSON_QUERY(@JsonRespuesta, '$.errores.resultadosValidacion'), @JsonRespuesta))
                  PRINT '@ResultadosValidacion >'  + COALESCE(@ResultadosValidacion,' SIN @ResultadosValidacion')

                  IF NOT EXISTS (SELECT 1 FROM FTRJSON WHERE CNSFCT = @CNSDOC)
                  BEGIN
                     INSERT INTO FTRJSON (CNSFCT, JSON_RESPUESTA, FRADICA_RIPS)
                     SELECT @CNSDOC, @JSONRESPUESTA, GETDATE()
                  END
                  ELSE
                  BEGIN
                     UPDATE FTRJSON  SET FRADICA_RIPS = GETDATE(), JSON_RESPUESTA = @JSONRESPUESTA
                     WHERE CNSFCT = @CNSDOC
                  END
                  DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'

                  INSERT INTO FTR_MAS_LOG (CONSECUTIVO ,FECHA ,PROCEDENCIA ,TIPOERROR ,MENSAJE ,DETALLES ,USUARIO )
                  SELECT @CNSDOC,GETDATE(),'FEVRIPS', 'Error Validacion', @ResultadosValidacion, NULL, @USUARIO
               END
               ELSE
               BEGIN
                  SELECT @CUV = JSON_VALUE(@JsonRespuesta,'$.CodigoUnicoValidacion')
                     --,@FRADICACION = JSON_VALUE(@JsonRespuesta,'$.FechaRadicacion')

                  UPDATE FTR
                  SET FRADICA_RIPS = GETDATE(),CUV = @CUV
                  WHERE CNSFCT = @CNSDOC

                  IF NOT EXISTS (SELECT 1 FROM FTRJSON WHERE CNSFCT = @CNSDOC)
                  BEGIN
                     INSERT INTO FTRJSON (CNSFCT, JSON_ENVIO,JSON_RESPUESTA, CUV, FRADICA_RIPS)
                     SELECT @CNSDOC, @JsonSolicitud , @JSONRESPUESTA, @CUV, GETDATE()
                  END
                  ELSE
                  BEGIN
                     UPDATE FTRJSON
                     SET FRADICA_RIPS = GETDATE()
                        ,JSON_ENVIO = @JsonSolicitud
                        ,JSON_RESPUESTA = @JSONRESPUESTA
                        ,CUV = @CUV
                     WHERE CNSFCT = @CNSDOC
                  END
                  DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'
               END
            END
         END TRY
         BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
         END CATCH
      END
      ELSE
      BEGIN
         BEGIN TRY
            IF COALESCE(@ISVALIDACUV,0) = 1 -- VIENE DE VALIDAR CUV PORQUE YA ESTABA VALIDADO
            BEGIN
               IF @TIPODOC='NA'
               BEGIN
                  UPDATE FGLO SET CUV=@CUV, FRADICA_RIPS=CAST(@FRADICACION AS DATETIME2) WHERE CNSGLO=@CNSDOC
               END
               ELSE
               BEGIN
                  UPDATE FNOT
                  SET FRADICA_RIPS = CAST(@FRADICACION AS DATETIME2) ,CUV = @CUV
                  WHERE CNSFNOT = @CNSDOC
               END
               IF NOT EXISTS (SELECT 1 FROM FNOTJSON WHERE CNSFNOT = @CNSDOC AND CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END)
               BEGIN
                  INSERT INTO FNOTJSON (CNSFNOT,CLASE, JSON_ENVIO,JSON_RESPUESTA, CUV, FRADICA_RIPS)
                  SELECT @CNSDOC,CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END, @JsonSolicitud , @JSONRESPUESTA, @CUV, CAST(@FRADICACION AS DATETIME2)
               END
               ELSE
               BEGIN
                  UPDATE FNOTJSON
                  SET FRADICA_RIPS = CAST(@FRADICACION AS DATETIME2)
                     ,JSON_ENVIO = @JsonSolicitud
                     ,JSON_RESPUESTA = @JSONRESPUESTA
                     ,CUV = @CUV
                  WHERE CNSFNOT = @CNSDOC
                  AND CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END
               END
               DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'
            END
            ELSE
            BEGIN
               SELECT @SUCCESS = ISNULL(JSON_VALUE(@JsonRespuesta, '$.ResultState'), JSON_VALUE(@JsonRespuesta, '$.errores.resultState'))
               IF COALESCE(@SUCCESS, 0) = 0
               BEGIN
                  PRINT '@JsonRespuesta >'  + COALESCE(@JsonRespuesta,' SIN @JsonRespuesta')

                  SET @ResultadosValidacion = ISNULL(JSON_QUERY(@JsonRespuesta, '$.ResultadosValidacion'), ISNULL(JSON_QUERY(@JsonRespuesta, '$.errores.resultadosValidacion'), @JsonRespuesta))
                  PRINT '@ResultadosValidacion >'  + COALESCE(@ResultadosValidacion,' SIN @ResultadosValidacion')

                  IF NOT EXISTS (SELECT 1 FROM FNOTJSON WHERE CNSFNOT = @CNSDOC AND CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END)
                  BEGIN
                     INSERT INTO FNOTJSON (CNSFNOT,CLASE, JSON_RESPUESTA, FRADICA_RIPS)
                     SELECT @CNSDOC,CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END, @JSONRESPUESTA, GETDATE()
                  END
                  ELSE
                  BEGIN
                     UPDATE FNOTJSON
                     SET FRADICA_RIPS = GETDATE()
                        ,JSON_RESPUESTA = @JSONRESPUESTA
                     WHERE CNSFNOT = @CNSDOC AND CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END
                  END
                  DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'

                  INSERT INTO FTR_MAS_LOG (CONSECUTIVO ,FECHA ,PROCEDENCIA ,TIPOERROR ,MENSAJE ,DETALLES ,USUARIO )
                  SELECT @CNSDOC,GETDATE(),'FEVRIPS', 'Error Validacion', @ResultadosValidacion, NULL, @USUARIO
               END
               ELSE
               BEGIN
                  SELECT @CUV = JSON_VALUE(@JsonRespuesta,'$.CodigoUnicoValidacion')

                  IF @TIPODOC='NA'
                  BEGIN
                     UPDATE FGLO SET CUV=@CUV, FRADICA_RIPS=CAST(@FRADICACION AS DATETIME2) WHERE CNSGLO=@CNSDOC
                  END
                  ELSE
                  BEGIN
                     UPDATE FNOT
                     SET FRADICA_RIPS = CAST(@FRADICACION AS DATETIME2)
                        ,CUV = @CUV
                     WHERE CNSFNOT = @CNSDOC
                  END

                  IF NOT EXISTS (SELECT 1 FROM FNOTJSON WHERE CNSFNOT = @CNSDOC AND CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END)
                  BEGIN
                     INSERT INTO FNOTJSON (CNSFNOT,CLASE,JSON_ENVIO,JSON_RESPUESTA, CUV, FRADICA_RIPS)
                     SELECT @CNSDOC,CLASE=CASE @TIPODOC  WHEN 'NC' THEN 'C' WHEN 'NA' THEN 'A' ELSE 'D' END, @JsonSolicitud , @JSONRESPUESTA, @CUV, GETDATE()
                  END
                  ELSE
                  BEGIN
                     UPDATE FNOTJSON
                     SET FRADICA_RIPS = GETDATE()
                        ,JSON_ENVIO = @JsonSolicitud
                        ,JSON_RESPUESTA = @JSONRESPUESTA
                        ,CUV = @CUV
                     WHERE CNSFNOT = @CNSDOC
                     AND CLASE=CASE WHEN @TIPODOC='NC' THEN 'C' ELSE 'D' END
                  END
                  DELETE FROM FTR_MAS_LOG WHERE CONSECUTIVO = @CNSDOC AND PROCEDENCIA = 'FEVRIPS'
               END
            END
         END TRY
         BEGIN CATCH
            INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
         END CATCH
      END
      IF(SELECT COUNT(1) FROM @TBLERRORES)>0
      BEGIN
         SELECT 'KO' OK
         SELECT ERROR FROM @TBLERRORES
         RETURN
      END
      SELECT 'OK' OK
      RETURN
   END

   IF @METODO = 'GET_DATOS_XML'
   BEGIN
      SELECT OK = 'OK'
      SELECT XML_Base64
      FROM FDIANR
      WHERE CNSDOCUMENTO = @CNSDOC
      AND TIPO=@TIPODOC
      AND METODO='SendBillSync'
      AND COALESCE(XML_BASE64, '') <> ''
      ORDER BY ITEM DESC
   END

   IF @METODO = 'GET_DATOS_XML_ATTACHEDDOCUMENT'
   BEGIN
      SELECT OK = 'OK'
      IF @TIPODOC = 'FV'
      BEGIN
         SELECT @NOMBREXML = ATTACHED_DOCNAME
         FROM FTRE INNER JOIN FTR ON FTR.N_FACTURA=FTRN_FACTURA AND FTRE.N_FACTURA=FTR.CNSDIANFE AND FTRE.PREFIJO=FTR.PREFIJODIANFE
         WHERE FTR.CNSFCT=@CNSDOC

         SELECT @XML = DBO.FNK_ATTACHEDDOCUMENT(@CNSDOC,'fv')
         --PRINT COALESCE(@XML ,' SIN XML ' )
         DECLARE @myDoc nvarchar(max) , @part1 nvarchar(max) , @part2 nvarchar(max) , @part3 nvarchar(max)
         BEGIN --- SI TIENE CONTRATO PERO NO LO ESTA TRAYENDO EN EL XML
            DECLARE @CONTRATO VARCHAR(120)
            SELECT TOP 1  @CONTRATO = PPT.NROCONTRATO
            FROM FTR    INNER JOIN   PPT ON   FTR.IDTERCERO =PPT.IDTERCERO
               AND  FTR.IDPLAN =PPT.IDPLAN
            WHERE FTR.CNSFCT= @CNSDOC   AND COALESCE(PPT.NROCONTRATO,'')<>''

            PRINT COALESCE(@CONTRATO,' NO ENCONTRE NUMERO DE CONTRATO PARA  @CNSDOC ') + ' : '+ @CNSDOC
            IF COALESCE(@CONTRATO,'')<>''
            BEGIN
               PRINT ' ENTRE DONDE SI HAY CONTRATO DESDE PPT'
               SELECT  @myDoc = @XML
               select  @part1 =left( @myDoc , charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc )-1 )
               select  @part2 =left( right( @myDoc , len(@myDoc ) - charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc )+1) ,100 )
               select  @part2 = replace( @part2 ,'<Value></Value>','<Value>'+ @CONTRATO + '</Value>')
               select  @part3 =right( @myDoc , len(@myDoc ) - charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc ) - 99 )
               select  @XML = @part1 + @part2 +@part3
            END
            ELSE
            BEGIN
               SELECT  TOP 1  @CONTRATO =  CNT.IDALTERNA
               FROM FTR INNER JOIN   PPT ON   FTR.IDTERCERO =PPT.IDTERCERO
                  AND  FTR.IDPLAN =PPT.IDPLAN
                  INNER JOIN   CNT ON    PPT.IDCONTRATO = CNT.IDCONTRATO
               WHERE FTR.CNSFCT= @CNSDOC   AND COALESCE(PPT.NROCONTRATO,'')<>''

               IF COALESCE(@CONTRATO,'')<>''
               BEGIN
                  PRINT ' ENTRE DONDE SI HAY CONTRATO DESDE CNT'
                  SELECT  @myDoc = @XML
                  select  @part1 =left( @myDoc , charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc )-1 )
                  select  @part2 =left( right( @myDoc , len(@myDoc ) - charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc )+1) ,100 )
                  select  @part2 = replace( @part2 ,'<Value></Value>','<Value>'+ @CONTRATO + '</Value>')
                  select  @part3 =right( @myDoc , len(@myDoc ) - charindex('<Name>NUMERO_CONTRATO</Name>' , @myDoc ) - 99 )
                  select  @XML = @part1 + @part2 +@part3
               END
               ELSE
                  PRINT  ' NO HICE CAMBIOS EN EL CONTRATO'
            END
         END
         PRINT  CHARINDEX ('<Value schemeName="salud_tipo_usuario.gc" schemeID="05">' , @XML  )

         IF CHARINDEX ('<Value schemeName="salud_tipo_usuario.gc" schemeID="05">' , @XML  ) >1
         BEGIN
            PRINT ' ENTRE A BUSCAR TIPO_USUARIO PORQUE ENCONTRE 05'
            SELECT  @myDoc = @XML
            select   @XML = replace( @myDoc ,'<Value schemeName="salud_tipo_usuario.gc" schemeID="04">Subsidiado</Value>','<Value schemeName="salud_tipo_usuario.gc" schemeID="'+ TIPOUSUARIO + '">'+ replace(PLN.TIPOSISTEMA,'.','') + '</Value>')
            FROM FTR INNER JOIN AFI ON FTR.IDAFILIADO = AFI.IDAFILIADO  INNER JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
               INNER JOIN FTRJSON ON FTRJSON.CNSFCT =FTR.CNSFCT
            WHERE FTR.CNSFCT= @CNSDOC
         END

         IF (SELECT DBO.FNK_VALORVARIABLE('SINTAGXMLVERSION'))  = 'NO'
         BEGIN
            SET @XML = REPLACE (@XML ,'<?xml version="1.0" encoding="utf-8" standalone="no"?>
                        <Invoice' ,'<Invoice')  --NO QUITAR EL SALTO DE LINEA POR QUE ESTA INCLUIDO EN LA CADENA PARA BUSCAR
            SET @XML = REPLACE (@XML ,'<?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <Invoice' ,'<Invoice')  --NO QUITAR EL SALTO DE LINEA POR QUE ESTA INCLUIDO EN LA CADENA PARA BUSCAR
         END

         SELECT @NOMBREXML Nombre, @XML XMLAttachedDocument
      END
      ELSE
      BEGIN
         DECLARE @CNS VARCHAR(20)
         SELECT @CNS=FTR.CNSFCT
         FROM FTR INNER JOIN FNOT ON FTR.N_FACTURA=FNOT.N_FACTURA
         WHERE FNOT.CNSFNOT=@CNSDOC

         SELECT @NOMBREXML = ATTACHED_DOCNAME
         FROM FTRE INNER JOIN FTR ON FTR.N_FACTURA=FTRN_FACTURA AND FTRE.N_FACTURA=FTR.CNSDIANFE AND FTRE.PREFIJO=FTR.PREFIJODIANFE
         WHERE FTR.CNSFCT=@CNS
         SELECT @XML = DBO.FNK_ATTACHEDDOCUMENT(@CNSDOC,@TIPODOC)
         SELECT @NOMBREXML Nombre, @XML XMLAttachedDocument
      END
   END

   IF @METODO='MARCAFAC'
   BEGIN
      SELECT @DATOS=DATOS
      FROM   OPENJSON (@PARAMETROS)
      WITH (
         DATOS NVARCHAR(MAX) AS JSON
      )

      SELECT @CNSDOC=CNSDOC,@MARCAFAC=MARCAFAC
      FROM   OPENJSON (@DATOS)
      WITH   (
         CNSDOC VARCHAR(20)   '$.CNSFCT',
         MARCAFAC SMALLINT    '$.MARCAFEVRIPS'
      )

      BEGIN TRY
         UPDATE FTR SET MARCAFEVRIPS=CASE WHEN @MARCAFAC=0 THEN 1 ELSE 0 END, USUARIO_MARCAFEVRIPS=CASE WHEN @MARCAFAC=0 THEN @USUARIO ELSE NULL END
         WHERE FTR.CNSFCT=@CNSDOC
      END TRY
      BEGIN CATCH
         INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
      END CATCH

      IF(SELECT COUNT(*) FROM @TBLERRORES)>0
      BEGIN
         SELECT 'KO' OK
         SELECT ERROR FROM @TBLERRORES
         RETURN
      END
      SELECT 'OK' OK
      SELECT CNSFCT, N_FACTURA, CONVERT(VARCHAR,FTR.F_FACTURA,103)F_FACTURA, PROCEDENCIA, 'Pendiente' ESTADO FROM FTR WHERE MARCAFEVRIPS = 1 AND USUARIO_MARCAFEVRIPS = @USUARIO AND COALESCE(CUV,'')=''
   END

   IF @METODO='MARCATODO'
   BEGIN
      DECLARE @ACCION SMALLINT, @FILTROS VARCHAR(4000)

      SELECT @FILTROS=FILTROS, @ACCION=ACCION
      FROM OPENJSON (@PARAMETROS)
      WITH (
         FILTROS  VARCHAR(4000)  '$.FILTROS',
         ACCION SMALLINT        '$.ACCION'
      )

      BEGIN TRY
         SELECT @CMD='UPDATE FTR SET MARCAFEVRIPS='+IIF(@ACCION=1,'1 ', '0')+',
            USUARIO_MARCAFEVRIPS='+IIF(@ACCION=1,''''+@USUARIO+'''','NULL')+' 
            FROM FTR 
            INNER JOIN FDIAN ON FTR.CNSRESOL=FDIAN.CNSRESOL
            INNER JOIN TER ON FTR.IDTERCERO=TER.IDTERCERO
            INNER JOIN PLN ON FTR.IDPLAN=PLN.IDPLAN
            WHERE '+@FILTROS
         --PRINT @CMD
         EXEC (@CMD)
      END TRY
      BEGIN CATCH
         INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
      END CATCH
      IF(SELECT COUNT(1) FROM @TBLERRORES)>0
      BEGIN
         SELECT 'KO' OK
         SELECT ERROR FROM @TBLERRORES
         RETURN
      END

      SELECT 'OK' OK
      SELECT CNSFCT, N_FACTURA, CONVERT(VARCHAR,FTR.F_FACTURA,103)F_FACTURA, PROCEDENCIA, 'Pendiente' ESTADO FROM FTR WHERE MARCAFEVRIPS = 1 AND USUARIO_MARCAFEVRIPS = @USUARIO AND COALESCE(CUV,'')=''
      RETURN
   END

   IF @METODO='MARCATODO_VALIDADO'
   BEGIN
      SELECT @DATOS=DATOS
      FROM   OPENJSON (@PARAMETROS)
      WITH (
         DATOS NVARCHAR(2048) '$.FILTROS'
      )
      SELECT @CMD='SELECT CNSFCT, N_FACTURA FROM FTR INNER JOIN FDIAN ON FDIAN.CNSRESOL=FTR.CNSRESOL WHERE '+COALESCE(@DATOS,'')
      BEGIN TRY
         SELECT 'OK' OK
         EXEC (@CMD)
      END TRY
      BEGIN CATCH
         INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
      END CATCH
      IF(SELECT COUNT(1) FROM @TBLERRORES)>0
      BEGIN
         SELECT 'KO' OK
         SELECT ERROR FROM @TBLERRORES
         RETURN
      END

      RETURN
   END

   IF @METODO='MARCAFCXC'
   BEGIN
      SELECT @DATOS=DATOS
      FROM   OPENJSON (@PARAMETROS)
      WITH (
         DATOS NVARCHAR(MAX) AS JSON
      )

      SELECT @FECHAINI=F_INIMAS,@FECHAFIN=DATEADD(DAY,1,F_FINMAS),@IDTERCERO=IDTERMAS
         ,@CNSCXC=CNSCXC
      FROM   OPENJSON (@DATOS)
      WITH   (
         F_INIMAS DATE          '$.F_INIMAS',
         F_FINMAS DATE          '$.F_FINMAS',
         IDTERMAS VARCHAR(20)   '$.IDTERMAS',
         CNSCXC VARCHAR(20)     '$.CNSCXC'
      )

      PRINT '@FECHAINI >'  + COALESCE(CONVERT(VARCHAR,@FECHAINI, 112),' SIN @FECHAINI')
      PRINT '@FECHAFIN >'  + COALESCE(CONVERT(VARCHAR, @FECHAFIN, 112),' SIN @FECHAFIN')
      PRINT '@IDTERCERO >'  + COALESCE(@IDTERCERO,' SIN @IDTERCERO')
      PRINT '@CNSCXC >'  + COALESCE(@CNSCXC,' SIN @CNSCXC')

      BEGIN TRY
         PRINT 'DESMARCANDO FACTURAS'
         UPDATE FTR SET MARCAFEVRIPS=0,
            USUARIO_MARCAFEVRIPS=NULL
         WHERE COALESCE(FTR.FACTE,0) = 2
         AND USUARIO_MARCAFEVRIPS = @USUARIO
         AND COALESCE(FTR.SI,0)=0
         AND COALESCE(FTR.ESTADO,'')='P'
         AND COALESCE(FTR.CONTABILIZADA,0)<>0
         AND COALESCE(FTR.VR_TOTAL,0)>0
         AND COALESCE(FTR.CUV,'')=''
         AND PROCEDENCIA <> 'CAJA'

         PRINT 'MARCANDO FACTURAS'
         UPDATE FTR SET MARCAFEVRIPS=1,
            USUARIO_MARCAFEVRIPS= @USUARIO
         FROM FTR
         INNER JOIN FCXCD ON FCXCD.N_FACTURA = FTR.N_FACTURA
         WHERE FCXCD.CNSCXC = @CNSCXC
         AND COALESCE(FTR.FACTE,0) = 2
         AND COALESCE(FTR.SI,0)=0
         AND COALESCE(FTR.ESTADO,'')='P'
         AND COALESCE(FTR.CONTABILIZADA,0)<>0
         AND COALESCE(FTR.VR_TOTAL,0)>0
         AND COALESCE(FTR.CUV,'')=''
         AND PROCEDENCIA <> 'CAJA'
      END TRY
      BEGIN CATCH
         INSERT INTO @TBLERRORES(ERROR) SELECT ERROR_MESSAGE()
      END CATCH
      IF(SELECT COUNT(1) FROM @TBLERRORES)>0
      BEGIN
         SELECT 'KO' OK
         SELECT ERROR FROM @TBLERRORES
         RETURN
      END
      SELECT 'OK' OK
      SELECT CNSFCT, N_FACTURA, CONVERT(VARCHAR,FTR.F_FACTURA,103)F_FACTURA, PROCEDENCIA, 'Pendiente' ESTADO FROM FTR WHERE MARCAFEVRIPS = 1 AND USUARIO_MARCAFEVRIPS = @USUARIO AND COALESCE(CUV,'')=''
      RETURN
   END

   IF @METODO = 'GET_CONFIG_EXPORT_RIPS'
   BEGIN
      DECLARE @CNSDOC_EXPORT VARCHAR(20), @TIPODOC_EXPORT VARCHAR(10)

      SELECT @CNSDOC_EXPORT = JSON_VALUE(@PARAMETROS, '$.CNSDOC')
         ,@TIPODOC_EXPORT = JSON_VALUE(@PARAMETROS, '$.TIPODOC')

      SELECT OK = 'OK'

      IF @TIPODOC_EXPORT IN ('NC', 'ND')
      BEGIN
         SELECT
            RIPS_NOMBRE_CARPETA = COALESCE(PPT.RIPS_NOMBRE_CARPETA, ''),
            RIPS_NOMBRE_JSON = COALESCE(PPT.RIPS_NOMBRE_JSON, ''),
            RIPS_NOMBRE_CUV = COALESCE(PPT.RIPS_NOMBRE_CUV, ''),
            CUVTXT = COALESCE(PPT.CUVTXT, 0),
            NIT = COALESCE(TER.NIT, ''),
            IDTERCERO = FTR.IDTERCERO,
            FACTURA = FTR.N_FACTURA,
            PREFIJO = COALESCE(NULLIF(LTRIM(RTRIM(FTR.PREFIJODIANFE)), ''), ''),
            NUMFACTURA = CASE
               WHEN COALESCE(FTR.PREFIJODIANFE, '') <> ''
                  AND FTR.N_FACTURA LIKE CONCAT(FTR.PREFIJODIANFE, '%')
               THEN SUBSTRING(FTR.N_FACTURA, LEN(FTR.PREFIJODIANFE) + 1, 100)
               ELSE FTR.N_FACTURA
            END,
            CUV = COALESCE(FTR.CUV, ''),
            CNSFNOT = FNOT.CNSFNOT,
            FECHA = CONVERT(VARCHAR(8), GETDATE(), 112),
            ANO = CONVERT(VARCHAR(4), DATEPART(YEAR, GETDATE())),
            MES = RIGHT(CONCAT('0', CONVERT(VARCHAR(2), DATEPART(MONTH, GETDATE()))), 2),
            DIA = RIGHT(CONCAT('0', CONVERT(VARCHAR(2), DATEPART(DAY, GETDATE()))), 2)
         FROM FNOT
         INNER JOIN FTR ON FNOT.N_FACTURA = FTR.N_FACTURA
         INNER JOIN PPT ON FTR.IDTERCERO = PPT.IDTERCERO AND FTR.IDPLAN = PPT.IDPLAN
         INNER JOIN TER ON FTR.IDTERCERO = TER.IDTERCERO
         WHERE FNOT.CNSFNOT = @CNSDOC_EXPORT
         RETURN
      END

      SELECT
         RIPS_NOMBRE_CARPETA = COALESCE(PPT.RIPS_NOMBRE_CARPETA, ''),
         RIPS_NOMBRE_JSON = COALESCE(PPT.RIPS_NOMBRE_JSON, ''),
         RIPS_NOMBRE_CUV = COALESCE(PPT.RIPS_NOMBRE_CUV, ''),
         CUVTXT = COALESCE(PPT.CUVTXT, 0),
         NIT = COALESCE(TER.NIT, ''),
         IDTERCERO = FTR.IDTERCERO,
         FACTURA = FTR.N_FACTURA,
         PREFIJO = COALESCE(NULLIF(LTRIM(RTRIM(FTR.PREFIJODIANFE)), ''), ''),
         NUMFACTURA = CASE
            WHEN COALESCE(FTR.PREFIJODIANFE, '') <> ''
               AND FTR.N_FACTURA LIKE CONCAT(FTR.PREFIJODIANFE, '%')
            THEN SUBSTRING(FTR.N_FACTURA, LEN(FTR.PREFIJODIANFE) + 1, 100)
            ELSE FTR.N_FACTURA
         END,
         CUV = COALESCE(FTR.CUV, ''),
         CNSFNOT = CAST('' AS VARCHAR(20)),
         FECHA = CONVERT(VARCHAR(8), GETDATE(), 112),
         ANO = CONVERT(VARCHAR(4), DATEPART(YEAR, GETDATE())),
         MES = RIGHT(CONCAT('0', CONVERT(VARCHAR(2), DATEPART(MONTH, GETDATE()))), 2),
         DIA = RIGHT(CONCAT('0', CONVERT(VARCHAR(2), DATEPART(DAY, GETDATE()))), 2)
      FROM FTR
      INNER JOIN PPT ON FTR.IDTERCERO = PPT.IDTERCERO AND FTR.IDPLAN = PPT.IDPLAN
      INNER JOIN TER ON FTR.IDTERCERO = TER.IDTERCERO
      WHERE FTR.CNSFCT = @CNSDOC_EXPORT
      RETURN
   END
END

