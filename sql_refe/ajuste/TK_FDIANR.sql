CREATE OR ALTER TRIGGER TK_FDIANR
ON FDIANR 
WITH ENCRYPTION
FOR --ANTES
--AFTER --DESPUES
--INSTEAD OF 
INSERT--,UPDATE--,DELETE 
AS
DECLARE @PREFIJO_USCXS VARCHAR(20)
DECLARE @ACTION      AS VARCHAR(1)
DECLARE @AMBIENTE	   INT
BEGIN
   DECLARE @ITEM		INT					,@CNSDOCUMENTO		VARCHAR(20)
	,@TIPO				VARCHAR(2)			,@XML_RESPUESTA		XML
	,@IsValid			BIT = 0				,@XmlDocumentKey	VARCHAR(1000)	
	,@XmlFileName		VARCHAR(1000)		,@ZipKey			VARCHAR(1000)
	,@CNSACTUAL			BIGINT				,@CNSRESOL			VARCHAR(100)	
	,@N_FACTURA			VARCHAR(20)			,@PREFIJO			VARCHAR(10)	
	,@CUFE				NVARCHAR(MAX)		,@METODO			VARCHAR(100)
	,@TRACKID			NVARCHAR(1000)		,@StatusCode		VARCHAR(10)
	,@NUMDOC			VARCHAR(20)			,@base64			NVARCHAR(MAX)
	,@ApplicationResponse NVARCHAR(MAX)		,@StatusMessage NVARCHAR(MAX)


	DECLARE @COMPANIA VARCHAR(20) = '01' -- UNICA COMPANIA
	DECLARE @SEDE VARCHAR(2) = '01' -- UNICA SEDE
   DECLARE @USUARIOFTR VARCHAR(20)
   DECLARE @SYS_COMPUTERNAME VARCHAR(255)
   DECLARE @CONTAB BIT
	DECLARE @NITOFE VARCHAR(20)
	DECLARE @CONSECUTIVO VARCHAR(100)
	DECLARE @ATTACHED_DOCNAME VARCHAR(1000)
	DECLARE @ANIO VARCHAR(2)=RIGHT(CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR),2)
	DECLARE @PREFIJO_USCXS2 VARCHAR(20)='ad'+@ANIO
	DECLARE @PRIMER_ERROR VARCHAR(1000)
   DECLARE @SIN_FACTURA SMALLINT
   SET @ACTION = 'I';
   IF EXISTS(SELECT * FROM DELETED)
   BEGIN
       SET @ACTION = CASE WHEN EXISTS(SELECT * FROM INSERTED) THEN 'U' ELSE 'D' END 
   END   
   
   SELECT @ITEM=ITEM, @CNSDOCUMENTO=CNSDOCUMENTO, @TIPO=TIPO
		, @XML_RESPUESTA=XML_RESPUESTA
		,@METODO=METODO	,@NUMDOC=NUMDOC
   FROM INSERTED
   
   IF @ACTION='I'
   BEGIN

		IF @METODO='SendBillSync' --TODOS EXCEPTO NOMINA Y RADIAN
		BEGIN
			
			;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
						'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
						'http://schemas.datacontract.org/2004/07/DianResponse' AS b,
						'http://www.w3.org/2001/XMLSchema-instance' AS i,
						'http://schemas.microsoft.com/2003/10/Serialization/Arrays' AS c)
			--SELECT	@IsValid		=  xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:IsValid)[1]', 'bit') ,
			--		@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
			--		@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlFileName)[1]', 'varchar(1000)') 
			--FROM   FDIANR
			--WHERE  ITEM = @ITEM
			SELECT	@IsValid		=  xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:IsValid)[1]', 'bit') ,
					@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
					@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlFileName)[1]', 'varchar(1000)'),
					@PRIMER_ERROR	= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:ErrorMessage)[1]', 'varchar(1000)'),
					@StatusCode		= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:StatusCode)[1]', 'varchar(10)')
					,@base64		= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlBase64Bytes)[1]', 'nvarchar(max)')
					--,@StatusDescription = xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:StatusDescription)[1]', 'nvarchar(max)')
					,@StatusMessage = xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:StatusMessage)[1]', 'nvarchar(max)')
			FROM   FDIANR
			WHERE  ITEM = @ITEM


         PRINT '@ISVALID: ' + CAST(@ISVALID AS VARCHAR)
         PRINT '@StatusCode: ' + CAST(@StatusCode AS VARCHAR)
			
			IF @ISVALID = 1
			BEGIN
				
				-- Nombre del archivo a la columna ATTACHED_DOCNAME de FTRE -- EZ 18/05/2020
				SELECT @NITOFE=RIGHT('0000000000'+DBO.FNK_LIMPIATEXTO(NIT,'0-9'),10) FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCERO_OFE')
				EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, @PREFIJO_USCXS2, @CONSECUTIVO OUTPUT  
				SELECT @ATTACHED_DOCNAME = 'ad'+@NITOFE+'000'+@ANIO+RIGHT('00000000'+@CONSECUTIVO,8)+'.xml'
				
			
				IF @TIPO='FV'
				BEGIN

					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
					SELECT 
						   @CUFE = XML_SOLICITUD.value('(Invoice/cbc:UUID)[1]', 'varchar(max)') 

					FROM   FDIANR
					WHERE  ITEM = @ITEM

					SELECT @CNSRESOL = CNSRESOL, @N_FACTURA=N_FACTURA
					FROM FTR WHERE CNSFCT = @CNSDOCUMENTO


					IF (SELECT AMBIENTE FROM FDIAN WHERE CNSRESOL=@CNSRESOL)=1
					BEGIN
						--SELECT @PREFIJO = DBO.FNK_LIMPIATEXTO(@N_FACTURA,'A-Z'), @CNSACTUAL=DBO.FNK_LIMPIATEXTO(@N_FACTURA,'0-9')
						SELECT @PREFIJO = COALESCE(PREFIJO, '') FROM FDIAN WHERE CNSRESOL= @CNSRESOL
						SELECT @CNSACTUAL = REPLACE(@N_FACTURA,@PREFIJO,'')
					END
					ELSE
					BEGIN
						SELECT @CNSACTUAL=CNSACTUAL+1, @PREFIJO=COALESCE(PREFIJO,'') FROM FDIAN WHERE CNSRESOL=@CNSRESOL
					END

				
					-- Consecutivo consumido, se aumenta en uno el consecutivo
					UPDATE FDIAN SET CNSACTUAL=CNSACTUAL+1 WHERE CNSRESOL=@CNSRESOL
				
					-- Se registra el documento electronico en FTRE
					INSERT INTO FTRE(N_FACTURA,FTRN_FACTURA,PREFIJO,NOMBREARCHIVO,CUFE,CNSRESOL,RESPUESTA,ATTACHED_DOCNAME,F_MAXRADICA)
					SELECT @CNSACTUAL, @N_FACTURA, COALESCE(@PREFIJO, ''), @XmlFileName+'.xml', @CUFE, @CNSRESOL,CAST(@XML_RESPUESTA AS nvarchar(MAX)),@ATTACHED_DOCNAME,
               DBO.FNK_DIAS_HABILES_DIAN(DBO.FNK_GETDATE(),22)
					

					UPDATE FTR SET FACTE=2, CUFE=@CUFE WHERE CNSFCT=@CNSDOCUMENTO	
               
               IF DBO.FNK_VALORVARIABLE('CONTAB_FTR_POSTDIAN')='SI'
               BEGIN
                  SELECT @USUARIOFTR=USUARIOFACTURA,@CONTAB=CASE WHEN COALESCE(CONTABILIZADA,0)=0 THEN 0 ELSE 1 END
                  FROM FTR WHERE N_FACTURA=@N_FACTURA
                  SELECT @SEDE=COALESCE(UBEQ.IDSEDE,USUSU.IDSEDE),@COMPANIA=COALESCE(UBEQ.COMPANIA,USUSU.COMPANIA),  @SYS_COMPUTERNAME=COALESCE(USUSU.SYS_ComputerName,HOST_NAME())   FROM USUSU LEFT JOIN UBEQ ON USUSU.SYS_ComputerName=UBEQ.SYS_ComputerName
                  WHERE USUSU.USUARIO=@USUARIOFTR
                  IF COALESCE(@CONTAB,0)=0
                  BEGIN
                     EXEC SPK_NC_CONTAB_FTR @N_FACTURA,@COMPANIA,@USUARIOFTR,@SYS_COMPUTERNAME,@SEDE,''
                  END
               END

				END

				IF @TIPO='NC'
				BEGIN
					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)

					SELECT    @CUFE = XML_SOLICITUD.value('(CreditNote/cbc:UUID)[1]', 'varchar(max)') 
					FROM   FDIANR
					WHERE  ITEM = @ITEM

					SELECT @CNSRESOL = CNSRESOL, @N_FACTURA=FNOT.N_FACTURA, @SIN_FACTURA = COALESCE(NOTA_SIN_FACTURA,0)
					FROM FNOT INNER JOIN FTR ON FTR.N_FACTURA=FNOT.N_FACTURA 
					WHERE CNSFNOT = @CNSDOCUMENTO

               IF COALESCE(@SIN_FACTURA,0)=0 OR COALESCE(@CNSRESOL,'')=''
                  SELECT TOP 1 @CNSRESOL = CNSRESOL FROM FDIAN WHERE PROCEDENCIA='FTR' AND COALESCE(VENCIDA,0)=0 
					
					SELECT @CNSACTUAL=CNSACTUAL+1, @PREFIJO=COALESCE(PREFIJO, '') FROM FDIAN WHERE CNSRESOL=@CNSRESOL
				
					-- Se registra el documento electronico en FTRE
					INSERT INTO FTRE(N_FACTURA,FTRN_FACTURA,PREFIJO,NOMBREARCHIVO,CUFE,CNSRESOL,RESPUESTA,ATTACHED_DOCNAME)
					SELECT @CNSDOCUMENTO, @N_FACTURA, COALESCE(@PREFIJO, ''), @XmlFileName+'.xml', @CUFE, @CNSRESOL, CAST(@XML_RESPUESTA AS nvarchar(MAX)), @ATTACHED_DOCNAME

					UPDATE FNOT SET FACTE=2, CUDE=@CUFE WHERE CNSFNOT=@CNSDOCUMENTO

				END

				IF @TIPO='ND'
				BEGIN
					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)

					SELECT    @CUFE = XML_SOLICITUD.value('(DebitNote/cbc:UUID)[1]', 'varchar(max)') 
					FROM   FDIANR
					WHERE  ITEM = @ITEM

               
					SELECT @CNSRESOL = CNSRESOL, @N_FACTURA=FNOT.N_FACTURA, @SIN_FACTURA = COALESCE(NOTA_SIN_FACTURA,0)
					FROM FNOT INNER JOIN FTR ON FTR.N_FACTURA=FNOT.N_FACTURA 
               WHERE CNSFNOT = @CNSDOCUMENTO

               IF COALESCE(@SIN_FACTURA,0)=0 OR COALESCE(@CNSRESOL,'')=''
                  SELECT TOP 1 @CNSRESOL = CNSRESOL FROM FDIAN WHERE PROCEDENCIA='FTR' AND COALESCE(VENCIDA,0)=0 
					

					SELECT @CNSACTUAL=CNSACTUAL+1, @PREFIJO=COALESCE(PREFIJO, '') FROM FDIAN WHERE CNSRESOL=@CNSRESOL
				
					-- Se registra el documento electronico en FTRE
					INSERT INTO FTRE(N_FACTURA,FTRN_FACTURA,PREFIJO,NOMBREARCHIVO,CUFE,CNSRESOL,RESPUESTA,ATTACHED_DOCNAME)
					SELECT @CNSDOCUMENTO, @N_FACTURA, COALESCE(@PREFIJO, ''), @XmlFileName+'.xml', @CUFE, @CNSRESOL, CAST(@XML_RESPUESTA AS nvarchar(MAX)), @ATTACHED_DOCNAME
					
					UPDATE FNOT SET FACTE=2, CUDE=@CUFE WHERE CNSFNOT=@CNSDOCUMENTO
				END

				IF @TIPO='DS'
				BEGIN

					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
					SELECT @CUFE = XML_SOLICITUD.value('(Invoice/cbc:UUID)[1]', 'varchar(max)') 
					FROM   FDIANR
					WHERE  ITEM = @ITEM

					UPDATE FCXP SET ESTADODIAN=2, CUDS=@CUFE WHERE CNSFCXP=@CNSDOCUMENTO
				END

				IF @TIPO='NA'
				BEGIN
					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)

					SELECT    @CUFE = XML_SOLICITUD.value('(CreditNote/cbc:UUID)[1]', 'varchar(max)') 
					FROM   FDIANR
					WHERE  ITEM = @ITEM

					UPDATE FCXPDBCR SET ESTADODIAN=2, CUDS=@CUFE WHERE CNSFCXP = @CNSDOCUMENTO AND ITEM=@NUMDOC

				END

				IF @base64 IS NOT NULL
				BEGIN
					SELECT @ApplicationResponse =
						CONVERT(VARCHAR(MAX), 
							CAST('' AS XML).value('xs:base64Binary(sql:column("BASE64_COLUMN"))', 'VARBINARY(MAX)')
						)
					FROM(
						SELECT @base64 AS BASE64_COLUMN
					) A

					IF @ApplicationResponse IS NOT NULL
					BEGIN
						UPDATE FDIANR
						SET XML_ApplicationResponse = @ApplicationResponse
						WHERE ITEM = @ITEM
					END
				END

				SELECT @PREFIJO_USCXS = '@FDIAN'+CAST(YEAR(GETDATE()) AS varchar)
				IF NOT EXISTS(SELECT CONSECUTIVO FROM USCXS WHERE COMPANIA='01' AND IDSEDE='01' AND PREFIJO = @PREFIJO_USCXS)
				BEGIN
					INSERT INTO USCXS (COMPANIA,IDSEDE,BODEGA,IDADICIONAL,PREFIJO,CONSECUTIVO,SERIE,LIMITE)  
					VALUES('01','01','','',@PREFIJO_USCXS,1,0,0)  
				END
				ELSE
				BEGIN
					UPDATE USCXS SET CONSECUTIVO = CONSECUTIVO + 1  
					WHERE COMPANIA = '01'  
					AND   IDSEDE   = '01'  
					AND   PREFIJO  = @PREFIJO_USCXS
				END
			END
			ELSE
			BEGIN
				
				IF @StatusCode='500'
				BEGIN
					IF @TIPO='FV' UPDATE FTR SET FACTE=1, ZIPKEY=@XmlDocumentKey WHERE CNSFCT=@CNSDOCUMENTO
					IF @TIPO IN ('NC','ND') UPDATE FNOT SET FACTE=1, ZIPKEY=@XmlDocumentKey WHERE CNSFNOT=@CNSDOCUMENTO
					IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN=1, ZIPKEY=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO
					IF @TIPO='NA' UPDATE FCXPDBCR SET ESTADODIAN=1, ZIPKEY=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO AND ITEM=@NUMDOC
				END
				ELSE
				BEGIN
					IF TRIM(COALESCE(@PRIMER_ERROR, ''))='' AND TRIM(COALESCE(@StatusMessage, ''))<>'' 
					BEGIN
						SELECT @PRIMER_ERROR = @StatusMessage
					END
					IF CHARINDEX('Regla: 90, Rechazo',@PRIMER_ERROR,1)>0 
					BEGIN						
						IF @TIPO='FV' UPDATE FTR SET FACTE=4, ZIPKEY=@XmlDocumentKey, CUFE=@XmlDocumentKey WHERE CNSFCT=@CNSDOCUMENTO
						IF @TIPO IN ('NC','ND') UPDATE FNOT SET FACTE=4, ZIPKEY=@XmlDocumentKey, CUDE=@XmlDocumentKey WHERE CNSFNOT=@CNSDOCUMENTO
						IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN=4,ZIPKEY=@XmlDocumentKey, CUDS=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO
						IF @TIPO='NA' UPDATE FCXPDBCR SET ESTADODIAN=4, ZIPKEY=@XmlDocumentKey, CUDS=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO AND ITEM=@NUMDOC
					END
               ELSE
               BEGIN
                  IF CHARINDEX('Regla: LGC15, Rechazo:',@PRIMER_ERROR,1)>0 
					   BEGIN	
						   IF @TIPO IN ('NC','ND') UPDATE FNOT SET FACTE=1, NOTA_SIN_FACTURA=1 WHERE CNSFNOT=@CNSDOCUMENTO
					   END
					   ELSE
					   BEGIN		
                     IF CHARINDEX('factura sea igual a la fecha de firma',@PRIMER_ERROR,1)>0  AND @TIPO IN('FV','NC')
                     BEGIN
                        IF @TIPO='FV'
                        BEGIN
                           IF(SELECT DATEDIFF(DAY,F_FACTURA,DBO.FNK_GETDATE()) FROM FTR WHERE CNSFCT=@CNSDOCUMENTO)<7
                           BEGIN 
                              UPDATE FTR SET F_FACTURA=DBO.FNK_GETDATE(),F_VENCE=DBO.FNK_GETDATE()+30,FACTE=1 WHERE CNSFCT=@CNSDOCUMENTO
                           END
                           ELSE
                           BEGIN
                              UPDATE FTR SET FACTE=3, ZIPKEY=@XmlDocumentKey WHERE CNSFCT=@CNSDOCUMENTO
                           END
                        END
                        IF @TIPO='NC'
                        BEGIN
                           IF(SELECT DATEDIFF(DAY,F_NOTA,DBO.FNK_GETDATE()) FROM FNOT WHERE CNSFNOT=@CNSDOCUMENTO)<7
                           BEGIN 
                              UPDATE FNOT SET F_NOTA=DBO.FNK_GETDATE(),FACTE=1 WHERE CNSFNOT=@CNSDOCUMENTO
                           END
                           ELSE
                           BEGIN
                              UPDATE FNOT SET FACTE=3, ZIPKEY=@XmlDocumentKey WHERE CNSFNOT=@CNSDOCUMENTO
                           END
                        END
                     END
                     ELSE
                     BEGIN
						      IF @TIPO='FV' UPDATE FTR SET FACTE=3, ZIPKEY=@XmlDocumentKey WHERE CNSFCT=@CNSDOCUMENTO
						      IF @TIPO IN ('NC','ND') UPDATE FNOT SET FACTE=3, ZIPKEY=@XmlDocumentKey WHERE CNSFNOT=@CNSDOCUMENTO
						      IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN=3, ZIPKEY=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO
						      IF @TIPO='NA' UPDATE FCXPDBCR SET ESTADODIAN=3, ZIPKEY=@XmlDocumentKey WHERE CNSFCXP=@CNSDOCUMENTO AND ITEM=@NUMDOC
                     END
					   END
               END
				END
			END
		END

		IF @METODO='SendBillAsync'  --FTR-FNOT
		BEGIN
			;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
                    'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
                    'http://schemas.datacontract.org/2004/07/UploadDocumentResponse' AS b,
                    'http://www.w3.org/2001/XMLSchema-instance' AS i,
                    'http://schemas.datacontract.org/2004/07/XmlParamsResponseTrackId' AS c)
			SELECT	@ZipKey = xml_respuesta.value('(s:Envelope/s:Body/SendBillAsyncResponse/SendBillAsyncResult/b:ZipKey)[1]', 'varchar(1000)') 
			FROM   FDIANR
			WHERE  ITEM = @ITEM

			IF @TIPO = 'FV'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2','urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT @CUFE = XML_SOLICITUD.value('(Invoice/cbc:UUID)[1]', 'varchar(max)') FROM   FDIANR  WHERE  ITEM = @ITEM
			END
			IF @TIPO = 'NC'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT  @CUFE = XML_SOLICITUD.value('(CreditNote/cbc:UUID)[1]', 'varchar(max)') FROM FDIANR  WHERE  ITEM = @ITEM
			END
			IF @TIPO = 'ND'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT  @CUFE = XML_SOLICITUD.value('(DebitNote/cbc:UUID)[1]', 'varchar(max)') FROM FDIANR  WHERE  ITEM = @ITEM
			END

			IF @TIPO='FV' UPDATE FTR SET FACTE=4, ZIPKEY = @ZipKey, CUFE=@CUFE WHERE CNSFCT=@CNSDOCUMENTO
			ELSE IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN = 4, ZIPKEY = @ZipKey, CUDS = @CUFE WHERE CNSFCXP=@CNSDOCUMENTO
			ELSE UPDATE FNOT SET FACTE=4, ZIPKEY = @ZipKey, CUDE=@CUFE WHERE CNSFNOT=@CNSDOCUMENTO
		END

		IF @METODO='SendTestSetAsync' --FTR-FNOT
		BEGIN
			;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
                    'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
                    'http://schemas.datacontract.org/2004/07/UploadDocumentResponse' AS b,
                    'http://www.w3.org/2001/XMLSchema-instance' AS i,
                    'http://schemas.datacontract.org/2004/07/XmlParamsResponseTrackId' AS c)
			SELECT	@ZipKey = xml_respuesta.value('(s:Envelope/s:Body/SendTestSetAsyncResponse/SendTestSetAsyncResult/b:ZipKey)[1]', 'varchar(1000)') 
			FROM   FDIANR
			WHERE  ITEM = @ITEM

			IF @TIPO = 'FV' OR @TIPO = 'DS'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2','urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT @CUFE = XML_SOLICITUD.value('(Invoice/cbc:UUID)[1]', 'varchar(max)') FROM   FDIANR  WHERE  ITEM = @ITEM
			END
			IF @TIPO = 'NC' OR @TIPO='NA'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT  @CUFE = XML_SOLICITUD.value('(CreditNote/cbc:UUID)[1]', 'varchar(max)') FROM FDIANR  WHERE  ITEM = @ITEM
			END
			IF @TIPO = 'ND'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				SELECT  @CUFE = XML_SOLICITUD.value('(DebitNote/cbc:UUID)[1]', 'varchar(max)') FROM FDIANR  WHERE  ITEM = @ITEM

			END
			IF @TIPO = 'NE'
			BEGIN
				--;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2',
				--						'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
				-- SELECT  XML_SOLICITUD.value('(NominaIndividual/InformacionGeneral)[1]', 'varchar(max)') FROM FDIANR  WHERE  ITEM = @ITEM

				UPDATE NIEPEG SET ESTADODIAN=4, ZIPKEY=@ZIPKEY 
				WHERE CNSNIEPEG=@CNSDOCUMENTO
				RETURN
			END

			IF @TIPO='FV' 
                UPDATE FTR SET FACTE=4, ZIPKEY = @ZipKey, CUFE = @ZipKey WHERE CNSFCT=@CNSDOCUMENTO
			ELSE 
                IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN = 4, ZIPKEY = @ZipKey, CUDS = @ZipKey WHERE CNSFCXP=@CNSDOCUMENTO
			ELSE 
				IF @TIPO='NA' UPDATE FCXPDBCR SET ESTADODIAN = 4, ZIPKEY = @ZipKey, CUDS = @ZipKey WHERE CNSFCXP = @CNSDOCUMENTO AND ITEM= @NUMDOC
			ELSE
                UPDATE FNOT SET FACTE = 4, ZIPKEY = @ZipKey, CUDE = @CUFE WHERE CNSFNOT=@CNSDOCUMENTO

		END

		IF LEFT(@METODO,9)='GetStatus' --TODOS
		BEGIN
			IF @METODO='GetStatusZip'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
						'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
						'http://schemas.datacontract.org/2004/07/DianResponse' AS b,
						'http://www.w3.org/2001/XMLSchema-instance' AS i,
						'http://schemas.microsoft.com/2003/10/Serialization/Arrays' AS c)
				SELECT	@IsValid		=	xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:IsValid)[1]', 'bit'),
						@StatusCode		=	xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:StatusCode)[1]', 'VARCHAR(10)'),
						@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
						@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:XmlFileName)[1]', 'varchar(1000)'),  
						@TRACKID		= xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:XmlDocumentKey)[1]', 'varchar(1000)'),  
                        @PRIMER_ERROR	= xml_respuesta.value('(s:Envelope/s:Body/GetStatusZipResponse/GetStatusZipResult/b:DianResponse/b:ErrorMessage)[1]', 'varchar(1000)')
				FROM   FDIANR
				WHERE  ITEM = @ITEM
			END
			ELSE
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
						'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
						'http://schemas.datacontract.org/2004/07/DianResponse' AS b,
						'http://www.w3.org/2001/XMLSchema-instance' AS i,
						'http://schemas.microsoft.com/2003/10/Serialization/Arrays' AS c)
				SELECT	@IsValid		=	xml_respuesta.value('(s:Envelope/s:Body/GetStatusResponse/GetStatusResult/b:IsValid)[1]', 'bit'),
						@StatusCode		=	xml_respuesta.value('(s:Envelope/s:Body/GetStatusResponse/GetStatusResult/b:StatusCode)[1]', 'VARCHAR(10)'),
						@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/GetStatusResponse/GetStatusResult/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
						@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/GetStatusResponse/GetStatusResult/b:XmlFileName)[1]', 'varchar(1000)'),  
						@TRACKID		= xml_respuesta.value('(s:Envelope/s:Body/GetStatusResponse/GetStatusResult/b:XmlDocumentKey)[1]', 'varchar(1000)')
				FROM   FDIANR
				WHERE  ITEM = @ITEM
			END

			IF @IsValid = 1
			BEGIN
				IF @TIPO='FV'
				BEGIN

					-- Nombre del archivo a la columna ATTACHED_DOCNAME de FTRE -- EZ 18/05/2020
					SELECT @NITOFE=RIGHT('0000000000'+DBO.FNK_LIMPIATEXTO(NIT,'0-9'),10) FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCERO_OFE')
					EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, @PREFIJO_USCXS2, @CONSECUTIVO OUTPUT  
					SELECT @ATTACHED_DOCNAME = 'ad'+@NITOFE+'000'+@ANIO+RIGHT('00000000'+@CONSECUTIVO,8)+'.xml'

					sELECT @CNSRESOL = CNSRESOL, @N_FACTURA=N_FACTURA
					FROM FTR WHERE CNSFCT = @CNSDOCUMENTO


					SELECT @PREFIJO=COALESCE(PREFIJO, ''), @AMBIENTE=AMBIENTE FROM FDIAN WHERE CNSRESOL=@CNSRESOL

					IF @AMBIENTE=1
					BEGIN
						SELECT @CNSACTUAL = REPLACE(@N_FACTURA, COALESCE(@PREFIJO, ''), '')
					END
					ELSE
					BEGIN
						SELECT @CNSACTUAL=CNSACTUAL+1, @PREFIJO = COALESCE(PREFIJO, '') FROM FDIAN WHERE CNSRESOL=@CNSRESOL
					END

					-- Consecutivo consumido, se aumenta en uno el consecutivo
					-- UPDATE FDIAN SET CNSACTUAL=CNSACTUAL+1 WHERE CNSRESOL=@CNSRESOL
					-- Se registra el documento electronico en FTRE
					DELETE FROM FTRE WHERE N_FACTURA=CAST(@CNSACTUAL AS VARCHAR) AND PREFIJO = COALESCE(@PREFIJO, '')

					INSERT INTO FTRE(N_FACTURA,FTRN_FACTURA,PREFIJO,NOMBREARCHIVO,CUFE,CNSRESOL,RESPUESTA,ATTACHED_DOCNAME,F_MAXRADICA)
					SELECT CAST(@CNSACTUAL AS varchar(40)), @N_FACTURA, COALESCE(@PREFIJO, ''), @XmlFileName+'.xml', COALESCE(@CUFE,@TRACKID), @CNSRESOL, CAST(@XML_RESPUESTA AS nvarchar(MAX)), @ATTACHED_DOCNAME,
               DBO.FNK_DIAS_HABILES_DIAN(DBO.FNK_GETDATE(),22)
					--WHERE NOT EXISTS(SELECT * FROM FTRE WHERE N_FACTURA=CAST(@CNSACTUAL AS VARCHAR) AND PREFIJO=@PREFIJO)

					UPDATE FTR SET FACTE=2,CUFE=@XmlDocumentKey WHERE CNSFCT=@CNSDOCUMENTO
				
				END
				ELSE IF @TIPO='DS'
				BEGIN

					UPDATE FCXP SET ESTADODIAN=2, CUDS=@XmlDocumentKey  WHERE CNSFCXP=@CNSDOCUMENTO
				
				END
				ELSE IF @TIPO='NE'
				BEGIN
					SELECT @NITOFE=RIGHT('0000000000'+DBO.FNK_LIMPIATEXTO(NIT,'0-9'),10) FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCERO_OFE')
					EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, @PREFIJO_USCXS2, @CONSECUTIVO OUTPUT  
					SELECT @ATTACHED_DOCNAME = 'ad'+@NITOFE+'000'+@ANIO+RIGHT('00000000'+@CONSECUTIVO,8)+'.xml'
					
					UPDATE NIEPEG SET ESTADODIAN=2,CUNE=@XmlDocumentKey WHERE CNSNIEPEG=@CNSDOCUMENTO
				END
				ELSE IF @TIPO='NA'
				BEGIN
										
					UPDATE FCXPDBCR SET ESTADODIAN=2,CUDS=@XmlDocumentKey WHERE CNSFCXP = @CNSDOCUMENTO AND ITEM=@NUMDOC

				END
				ELSE
				BEGIN -- Notas
					
					-- Nombre del archivo a la columna ATTACHED_DOCNAME de FTRE -- EZ 18/05/2020
					SELECT @NITOFE=RIGHT('0000000000'+DBO.FNK_LIMPIATEXTO(NIT,'0-9'),10) FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCERO_OFE')
					EXEC SPK_GENCONSECUTIVO @COMPANIA, @SEDE, @PREFIJO_USCXS2, @CONSECUTIVO OUTPUT  
					SELECT @ATTACHED_DOCNAME = 'ad'+@NITOFE+'000'+@ANIO+RIGHT('00000000'+@CONSECUTIVO,8)+'.xml'

					;with XMLNAMESPACES(DEFAULT 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
										'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc)
					SELECT 
						   @CUFE = XML_SOLICITUD.value('(CreditNote/cbc:UUID)[1]', 'varchar(max)') 

					FROM   FDIANR
					WHERE  ITEM = @ITEM

                              
					SELECT @CNSRESOL = CNSRESOL, @N_FACTURA=FNOT.N_FACTURA, @SIN_FACTURA = COALESCE(NOTA_SIN_FACTURA,0)
					FROM FNOT INNER JOIN FTR ON FTR.N_FACTURA=FNOT.N_FACTURA 
               WHERE CNSFNOT = @CNSDOCUMENTO

               IF COALESCE(@SIN_FACTURA,0)=0 OR COALESCE(@CNSRESOL,'')=''
                  SELECT TOP 1 @CNSRESOL = CNSRESOL FROM FDIAN WHERE PROCEDENCIA='FTR' AND COALESCE(VENCIDA,0)=0 

					SELECT @CNSACTUAL=CNSACTUAL+1, @PREFIJO = COALESCE(PREFIJO, '') FROM FDIAN WHERE CNSRESOL=@CNSRESOL
				
					-- Se registra el documento electronico en FTRE
					INSERT INTO FTRE(N_FACTURA,FTRN_FACTURA,PREFIJO,NOMBREARCHIVO,CUFE,CNSRESOL,RESPUESTA, ATTACHED_DOCNAME)
					SELECT @CNSDOCUMENTO, @N_FACTURA, COALESCE(@PREFIJO, ''), @XmlFileName+'.xml', COALESCE(@CUFE,@TRACKID), @CNSRESOL, CAST(@XML_RESPUESTA AS nvarchar(MAX)), @ATTACHED_DOCNAME
					WHERE NOT EXISTS(SELECT 1 FROM FTRE WHERE N_FACTURA=@CNSDOCUMENTO AND PREFIJO = COALESCE(@PREFIJO, '') AND CNSRESOL=@CNSRESOL)

					IF @@ROWCOUNT = 0
					BEGIN
						UPDATE FNOT SET PREFIJODIANFE=COALESCE(@PREFIJO, ''), CNSDIANFE=@N_FACTURA, CNSRESOLFE=@CNSRESOL,FACTE=2 WHERE CNSFNOT=@CNSDOCUMENTO
					END
				END
			END
			ELSE
			BEGIN
				IF @StatusCode <> '0'
				BEGIN
					IF @TIPO='NE'
					BEGIN
                        IF CHARINDEX('Regla: 90, Rechazo',@PRIMER_ERROR,1)>0 
					    BEGIN
						    UPDATE NIEPEG SET ESTADODIAN = 2, CUNE = @XmlDocumentKey WHERE CNSNIEPEG = @CNSDOCUMENTO
                            RETURN
					    END
                        ELSE
                        BEGIN
						    IF CHARINDEX(', ha sido autorizada.',@StatusMessage,1)>0 AND @StatusCode='299'
						    BEGIN
							    UPDATE NIEPEG SET ESTADODIAN = 4, ZIPKEY=COALESCE(ZIPKEY,@XmlDocumentKey), CUNE=COALESCE(CUNE,@XmlDocumentKey) WHERE CNSNIEPEG = @CNSDOCUMENTO
						    END
						    ELSE
						    BEGIN
							    UPDATE NIEPEG SET ESTADODIAN = 3 WHERE CNSNIEPEG = @CNSDOCUMENTO
						    END
						    RETURN
                        END
					END
					IF @TIPO='FV' UPDATE FTR SET FACTE=3 WHERE CNSFCT = @CNSDOCUMENTO
					ELSE IF @TIPO='DS' UPDATE FCXP SET ESTADODIAN = 3, CUDS=@XmlDocumentKey WHERE CNSFCXP = @CNSDOCUMENTO
					ELSE IF @TIPO='NA' UPDATE FCXPDBCR SET ESTADODIAN = 3, CUDS=@XmlDocumentKey WHERE CNSFCXP = @CNSDOCUMENTO AND ITEM=@NUMDOC
					ELSE UPDATE FNOT SET FACTE = 3 WHERE CNSFNOT = @CNSDOCUMENTO
				END
			END
		END

		IF @METODO='SendNominaSync' --NOMINA
		BEGIN
			;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
                'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
                'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
                'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
                'http://schemas.datacontract.org/2004/07/DianResponse' AS b,
                'http://www.w3.org/2001/XMLSchema-instance' AS i,
                'http://schemas.microsoft.com/2003/10/Serialization/Arrays' AS c)
			SELECT	@IsValid		=  xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:IsValid)[1]', 'bit') ,
					@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
					@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:XmlFileName)[1]', 'varchar(1000)'),
					@PRIMER_ERROR	= xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:ErrorMessage)[1]', 'varchar(1000)'),
					@StatusCode		= xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:StatusCode)[1]', 'varchar(10)'),
					@StatusMessage	= xml_respuesta.value('(s:Envelope/s:Body/SendNominaSyncResponse/SendNominaSyncResult/b:StatusMessage)[1]', 'varchar(1000)')
			FROM   FDIANR
			WHERE  ITEM = @ITEM

			IF @IsValid = 0
			BEGIN
				IF @StatusCode='500'
				BEGIN
					UPDATE NIEPEG SET ESTADODIAN = 1 WHERE CNSNIEPEG = @CNSDOCUMENTO
				END
				ELSE
					IF CHARINDEX('Regla: 90, Rechazo',@PRIMER_ERROR,1)>0 
					BEGIN
						UPDATE NIEPEG SET ESTADODIAN = 4, ZIPKEY=COALESCE(ZIPKEY,@XmlDocumentKey), CUNE=COALESCE(CUNE,@XmlDocumentKey) WHERE CNSNIEPEG = @CNSDOCUMENTO
					END
					ELSE
					BEGIN
						IF CHARINDEX(', ha sido autorizada.',@StatusMessage,1)>0 AND @StatusCode='299'
						BEGIN
							UPDATE NIEPEG SET ESTADODIAN = 4, ZIPKEY=COALESCE(ZIPKEY,@XmlDocumentKey), CUNE=COALESCE(CUNE,@XmlDocumentKey) WHERE CNSNIEPEG = @CNSDOCUMENTO
						END
						ELSE
						BEGIN
							UPDATE NIEPEG SET ESTADODIAN = 3, ZIPKEY=COALESCE(ZIPKEY,@XmlDocumentKey), CUNE=COALESCE(CUNE,@XmlDocumentKey) WHERE CNSNIEPEG = @CNSDOCUMENTO
						END
					END	
			END
			ELSE 
			BEGIN
				UPDATE NIEPEG SET ESTADODIAN=2, CUNE=@XmlDocumentKey, ZIPKEY=@XmlDocumentKey WHERE CNSNIEPEG = @CNSDOCUMENTO
			END
		END

		IF @METODO IN ('SendBillAsync', 'SendTestSetAsync'/*, 'SendBillSync'*/) 
		BEGIN
			IF @TIPO='NE' AND @METODO = 'SendBillAsync'
			BEGIN
				;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
                    'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
                    'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
                    'http://schemas.datacontract.org/2004/07/UploadDocumentResponse' AS b,
                    'http://www.w3.org/2001/XMLSchema-instance' AS i,
                    'http://schemas.datacontract.org/2004/07/XmlParamsResponseTrackId' AS c)
				SELECT	@ZipKey = xml_respuesta.value('(s:Envelope/s:Body/SendBillAsyncResponse/SendBillAsyncResult/b:ZipKey)[1]', 'varchar(1000)') 
				FROM   FDIANR
				WHERE  ITEM = @ITEM

				UPDATE NIEPEG SET ESTADODIAN=4,ZIPKEY=@ZIPKEY WHERE CNSNIEPEG=@CNSDOCUMENTO
				RETURN
			END
			IF @TIPO='FV' -- Consecutivo consumido, se aumenta en uno el consecutivo de FDIAN
			BEGIN
				SELECT @CNSRESOL = CNSRESOL, @N_FACTURA=N_FACTURA FROM FTR WHERE CNSFCT = @CNSDOCUMENTO
				UPDATE FDIAN SET CNSACTUAL = CNSACTUAL+1 WHERE CNSRESOL=@CNSRESOL
			END
		END

		IF @METODO = 'SendEventUpdateStatus' --RADIAN
		BEGIN
			;with XMLNAMESPACES(DEFAULT 'http://wcf.dian.colombia',
						'http://www.w3.org/2003/05/soap-envelope' AS s, 'http://www.w3.org/2005/08/addressing' AS a,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' AS u,
						'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS o,
						'http://schemas.datacontract.org/2004/07/DianResponse' AS b,
						'http://www.w3.org/2001/XMLSchema-instance' AS i,
						'http://schemas.microsoft.com/2003/10/Serialization/Arrays' AS c)
			SELECT	@IsValid		=  xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:IsValid)[1]', 'bit'),
					@XmlDocumentKey = xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:XmlDocumentKey)[1]', 'varchar(1000)') ,
					@XmlFileName	= xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:XmlFileName)[1]', 'varchar(1000)'),
					@PRIMER_ERROR	= xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:StatusDescription)[1]', 'varchar(1000)'),
					@StatusCode		= xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:StatusCode)[1]', 'varchar(10)')
					--,@base64		= xml_respuesta.value('(s:Envelope/s:Body/SendBillSyncResponse/SendBillSyncResult/b:XmlBase64Bytes)[1]', 'nvarchar(max)')
					,@StatusMessage	= xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:StatusMessage)[1]', 'varchar(1000)')
					,@PRIMER_ERROR	= xml_respuesta.value('(s:Envelope/s:Body/SendEventUpdateStatusResponse/SendEventUpdateStatusResult/b:ErrorMessage)[1]', 'varchar(1000)')

			FROM   FDIANR
			WHERE  ITEM = @ITEM

			UPDATE FRADIAND SET PROCESADO=1, FECHAPROCESADO=DBO.FNK_GETDATE()
				,ERROR = CASE WHEN @IsValid = 0 THEN 1 ELSE 0 END 
			WHERE ITEM = @CNSDOCUMENTO
			
			SELECT @CONSECUTIVO = CNSRADIAN FROM FRADIAND WHERE ITEM =  @CNSDOCUMENTO

			IF @IsValid = 0
			BEGIN
				IF CHARINDEX('Documento procesado anteriormente', @PRIMER_ERROR, 1)>0 
				BEGIN
					UPDATE FRADIAND SET ERROR = 0
					WHERE ITEM = @CNSDOCUMENTO
				END
				ELSE
					UPDATE FRADIAN SET ESTADO = 3 WHERE CNSRADIAN = @CONSECUTIVO
			END
			ELSE
			BEGIN
				UPDATE FRADIAN SET ESTADO = 1 WHERE CNSRADIAN = @CONSECUTIVO
			END
			
		END
		
   END
END

