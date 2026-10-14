CREATE OR ALTER PROCEDURE DBO.SPK_NC_REVISAMCPE 
@NROCOMPROBANTE   VARCHAR(20),
@COMPANIA         VARCHAR(2),
@USUARIO          VARCHAR(12),
@SEDE             VARCHAR(5),
@SYS_COMPUTERNAME VARCHAR(254)
WITH ENCRYPTION
AS
DECLARE @ESTADOMCPE   VARCHAR(1), 
        @PROCEDENCIA  VARCHAR(20),
        @NOREFERENCIA VARCHAR(20),
        @ANO          VARCHAR(4), 
        @MES          VARCHAR(2),
        @REFERENCIA1  VARCHAR(40),
        @REFERENCIA2  VARCHAR(20),
        @REFERENCIA3  VARCHAR(20),
        @COMPROBANTE  VARCHAR(2),
        @PROCNOTA     VARCHAR(10),
        @N_FACTURA    VARCHAR(16),
        @VEZ          INT,
        @CNT_MCHE     INT,
        @CNT_MCH      INT,
        @CNT_MCP      INT,
        @ERRMSG       NVARCHAR(4000)
DECLARE @COMPROBANTE_MCP VARCHAR(2), @PROCEDENCIA_MCP VARCHAR(20), @REFERENCIA1_MCP VARCHAR(40), @REFERENCIA2_MCP VARCHAR(20), @REFERENCIA3_MCP VARCHAR(20),
        @ANO_MCP VARCHAR(4), @MES_MCP VARCHAR(2), @ESTADO_MCP VARCHAR(1)
DECLARE @COMPROBANTE_MCPE VARCHAR(2), @PROCEDENCIA_MCPE VARCHAR(20), @REFERENCIA1_MCPE VARCHAR(40), @REFERENCIA2_MCPE VARCHAR(20), @REFERENCIA3_MCPE VARCHAR(20),
        @ANO_MCPE VARCHAR(4), @MES_MCPE VARCHAR(2),@CLASECONT VARCHAR(10),@NOLOTE VARCHAR(8),@TERCEROSINTER VARCHAR(20),@DOCUMENTONIT VARCHAR(20), @IDTERCERADO VARCHAR(20)
DECLARE @TABLA TABLE (N_FACTURA  VARCHAR(16) COLLATE DATABASE_DEFAULT,
					CCOSTO     VARCHAR(20) COLLATE DATABASE_DEFAULT,
					VALOR      FLOAT)
BEGIN
   SELECT @CLASECONT=COALESCE(CLASECONTB,'LOCAL') FROM MCPE WHERE NROCOMPROBANTE=@NROCOMPROBANTE
   PRINT 'EMPIEZO LA REVISION MCPEEE....'




   IF @CLASECONT<>'NIIF'
   BEGIN								   
      SELECT @VEZ = COUNT(*) FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE
      IF COALESCE(@VEZ,0) > 0
      BEGIN
         SELECT @COMPROBANTE_MCPE = COMPROBANTE, @PROCEDENCIA_MCPE = PROCEDENCIA, @REFERENCIA1_MCPE = REFERENCIA1, 
                @REFERENCIA2_MCPE = REFERENCIA2, @REFERENCIA3_MCPE = REFERENCIA3, @ANO_MCPE = ANO, @MES_MCPE = MES,@NOLOTE=LOTE
         FROM   MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE

         SELECT  @COMPROBANTE_MCP = COMPROBANTE, @PROCEDENCIA_MCP = PROCEDENCIA, @REFERENCIA1_MCP = REFERENCIA1, 
                 @REFERENCIA2_MCP = REFERENCIA2, @REFERENCIA3_MCP = REFERENCIA3, @ANO_MCP = ANO, @MES_MCP = MES, @ESTADO_MCP = ESTADO
         FROM   MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE

         IF (SELECT COALESCE(CERRADO,0) FROM PRI WHERE ANO = @ANO_MCP AND MES = @MES_MCP) = 1
         BEGIN
             RAISERROR('Periodo Contable Cerrado.',16,1)     
             RETURN
         END
         IF @COMPROBANTE_MCP = @COMPROBANTE_MCPE AND @PROCEDENCIA_MCP = @PROCEDENCIA_MCPE AND @REFERENCIA1_MCP = @REFERENCIA1_MCPE
            AND COALESCE(@REFERENCIA2_MCP,'') = COALESCE(@REFERENCIA2_MCPE,'') AND COALESCE(@REFERENCIA3_MCP,'') = COALESCE(@REFERENCIA3_MCPE,'')
            AND @ANO_MCP = @ANO_MCPE AND @MES_MCP = @MES_MCPE
         BEGIN
            IF @ESTADO_MCP = 2
            BEGIN
               UPDATE MCP SET ESTADO = 1 WHERE NROCOMPROBANTE = @NROCOMPROBANTE 
            END
            DELETE MCH WHERE NROCOMPROBANTE = @NROCOMPROBANTE 
            DELETE MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE 
         END
         ELSE
         BEGIN
            RAISERROR('Ya existe un Comprobante en Contabilidad con este Mismo N?ero.',16,1)
            DELETE MCHE WHERE NROCOMPROBANTE=@NROCOMPROBANTE
            DELETE MCPE WHERE NROCOMPROBANTE=@NROCOMPROBANTE
            RETURN
         END
      END
      SELECT @PROCEDENCIA = PROCEDENCIA, @NOREFERENCIA = NOREFERENCIA, @ANO = ANO, @MES = MES, @COMPROBANTE = COMPROBANTE,
             @REFERENCIA1 = REFERENCIA1, @REFERENCIA2 =REFERENCIA2, @REFERENCIA3 =REFERENCIA3,@NOLOTE=LOTE
      FROM   MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE

      PRINT '@PROCEDENCIA='+@PROCEDENCIA
      EXEC SPK_NC_SUMA_DBCR @NROCOMPROBANTE
      DECLARE @DIFERENCIAJ DECIMAL(14,2)
      SELECT @DIFERENCIAJ = ABS(TOTALCREDITO-TOTALDEBITO) FROM MCPE WHERE NROCOMPROBANTE=@NROCOMPROBANTE
      PRINT'DIFERENCIA ANTES DE AJUSTE CENTAVOS '+LTRIM(RTRIM(STR(@DIFERENCIAJ)))

      IF @DIFERENCIAJ>0 AND @DIFERENCIAJ <2.00
      BEGIN
	      PRINT 'SI ENTRO  A BALANCEO DE CENTAVOS...'
         EXEC SPK_NC_BALANCEO_CENTAVOS @NROCOMPROBANTE
      END

	   DECLARE MCHETER_CURSOR CURSOR FOR   
       SELECT COALESCE(IDTERCERO,'') FROM MCHE 
	   WHERE NROCOMPROBANTE=@NROCOMPROBANTE 
	   AND NOT EXISTS(SELECT * FROM TER WHERE TER.IDTERCERO=MCHE.IDTERCERO)
	   AND COALESCE(IDTERCERO,'')<>''
	   OPEN MCHETER_CURSOR    
	   FETCH NEXT FROM MCHETER_CURSOR    
	   INTO @TERCEROSINTER
	   WHILE @@FETCH_STATUS = 0    
	   BEGIN 
         EXEC SPK_INSERT_TERDEAFI @TERCEROSINTER, ''
		 PRINT 'VERIFICO DE NUEVO '
		 IF NOT EXISTS(SELECT * FROM TER WHERE IDTERCERO=@TERCEROSINTER)
		 BEGIN
			SELECT @DOCUMENTONIT=DOCIDAFILIADO  FROM AFI WHERE IDAFILIADO=@TERCEROSINTER
			IF EXISTS(SELECT * FROM TER WHERE NIT=@DOCUMENTONIT AND COALESCE(ESTADO,'')<>'Inactivo')
			BEGIN
				PRINT 'SI ENCONTRE UN TERCERO CON ESE NIT'
				SELECT @IDTERCERADO= IDTERCERO FROM TER WHERE NIT=@DOCUMENTONIT AND COALESCE(ESTADO,'')<>'Inactivo'
				PRINT 'ACTUALIZO AL NUEVO TERCERO'
				UPDATE MCHE SET IDTERCERO=@IDTERCERADO WHERE NROCOMPROBANTE=@NROCOMPROBANTE AND IDTERCERO=@TERCEROSINTER
			END
		 END
	   FETCH NEXT FROM MCHETER_CURSOR    
	   INTO @TERCEROSINTER
	   END
	   CLOSE MCHETER_CURSOR
	   DEALLOCATE MCHETER_CURSOR   

      EXEC SPK_NC_REVISAR_COMPROBANTE @COMPANIA, @NROCOMPROBANTE
      EXEC SPK_NC_SUMA_DBCR @NROCOMPROBANTE
   
      SELECT @ESTADOMCPE = ESTADO FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
      IF @ESTADOMCPE = 0
      BEGIN
         IF @PROCEDENCIA = 'FACTURA'
         BEGIN
            UPDATE FTR SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE = @NROCOMPROBANTE WHERE N_FACTURA = @NOREFERENCIA
         END
         ELSE
         BEGIN
            IF @PROCEDENCIA = 'NOTDBCR'
            BEGIN
               UPDATE FNOT SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
               WHERE  CNSFNOT = @REFERENCIA1 AND CLASE = @REFERENCIA2
            END
            ELSE
            BEGIN
               IF @PROCEDENCIA = 'CXC' AND COALESCE(@NOLOTE,'')<>'REV'
               BEGIN
                  UPDATE FPAG SET CONTABILIZADO=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                  WHERE  CNSFPAG = @REFERENCIA1 
               END
               ELSE
               BEGIN
                  IF @PROCEDENCIA='INV'
                  BEGIN
                     UPDATE IMOV SET CONTABILIZADA=2,MARCACONT=0,NROCOMPROBANTE=@NROCOMPROBANTE
                     WHERE CNSMOV=@REFERENCIA1
                  END
                  ELSE
                  BEGIN
                     IF @PROCEDENCIA = 'CAJA'
                     BEGIN
                        UPDATE FCJ SET CONTABILIZADA=2,MARCACONT=0,NROCOMPROBANTE=@NROCOMPROBANTE
                        WHERE  CNSFACJ = @REFERENCIA1 AND CODCAJA = @REFERENCIA2
                        
                        UPDATE BMOV SET NROCOMPROBANTE=FCJ.NROCOMPROBANTE,CONTABILIZADA=FCJ.CONTABILIZADA 
                        FROM BMOV 
                        INNER JOIN FCJ ON BMOV.CODCAJA=FCJ.CODCAJA AND BMOV.CNSFACJ=FCJ.CNSFACJ 
                        WHERE BMOV.PROCEDENCIA='CAJA' AND COALESCE(BMOV.NROCOMPROBANTE,'')='' AND FCJ.NROCOMPROBANTE=@NROCOMPROBANTE
                     END
                     ELSE
                     BEGIN 
                        IF @PROCEDENCIA = 'NOMINA'
                        BEGIN
                           --@NUMDOC, @CNSPAGO, @CNSNIEPE
                           UPDATE NIEPE SET CONTABILIZADA = 2, NROCOMPROBANTE = @NROCOMPROBANTE, COMPROBANTE = @COMPROBANTE, NOREFERENCIA = @NOREFERENCIA 
                           WHERE  CNSPAGO = @REFERENCIA2 AND NUMDOC = @REFERENCIA1
                           UPDATE NIEPED SET CONTABILIZADA = 2, NROCOMPROBANTE = @NROCOMPROBANTE, COMPROBANTE = @COMPROBANTE, NOREFERENCIA = @NOREFERENCIA 
                           FROM   NIEPE INNER JOIN NIEPED ON NIEPE.CNSNIEPE = NIEPED.CNSNIEPE 
                                                         AND NIEPE.NUMDOC   = NIEPED.NUMDOC
                           WHERE  NIEPE.CNSPAGO = @REFERENCIA2 
                           AND    NIEPE.NUMDOC  = @REFERENCIA1
                        END
                        ELSE
                        BEGIN
                           IF @PROCEDENCIA = 'CXP'
                           BEGIN
                              UPDATE FCXP SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE FCXP.CNSFCXP=@REFERENCIA1
                           END
                           ELSE
                           BEGIN
                              IF @PROCEDENCIA = 'NOTDBCRCXP'
                              BEGIN
                                 UPDATE FCXPDBCR SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSFCXP=@REFERENCIA1 AND ITEM = @REFERENCIA2
                              END
                              ELSE
                              BEGIN
                                 IF @PROCEDENCIA = 'CXC' AND COALESCE(@NOLOTE,'')<>'REV'
                                 BEGIN
                                    UPDATE FPAG SET CONTABILIZADO=2, NROCOMPROBANTE=@NROCOMPROBANTE, MARCACONT=0 WHERE CNSFPAG=@REFERENCIA1
                                 END
                                 ELSE
                                 BEGIN
                                    IF @PROCEDENCIA = 'BMOV'
                                    BEGIN
                                       if COALESCE(DBO.FNK_VALORVARIABLE('LONGITUDCODBANCO'),'') = 3
                                          UPDATE BMOV SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                                          WHERE BANCO    = SUBSTRING(@REFERENCIA1,1,3)
                                          AND   SUCURSAL = SUBSTRING(@REFERENCIA1,4,2)
                                          AND   CTA_BCO  = SUBSTRING(@REFERENCIA1,6,40)
                                          AND   ITEM     = CONVERT(INT,@REFERENCIA2)
                                       ELSE
                                          UPDATE BMOV SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                                          WHERE BANCO    = SUBSTRING(@REFERENCIA1,1,2)
                                          AND   SUCURSAL = SUBSTRING(@REFERENCIA1,3,2)
                                          AND   CTA_BCO  = SUBSTRING(@REFERENCIA1,5,40)
                                          AND   ITEM     = CONVERT(INT,@REFERENCIA2)
                                    END
                                    ELSE
                                    BEGIN
                                       IF @PROCEDENCIA = 'CONCI'
                                       BEGIN
                                          UPDATE FCONCI SET CONTABILIZADA=2, NROCOMPROBANTE=@NROCOMPROBANTE WHERE IDFCONCI=@REFERENCIA1
                                       END
                                       ELSE
                                       BEGIN
                                          IF @PROCEDENCIA = 'RGLO'
                                          BEGIN
                                             UPDATE FGLO SET CONTABILIZADA=2, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSGLO=@REFERENCIA1
                                          END
                                          ELSE
                                          BEGIN
                                             IF @PROCEDENCIA = 'RAD CXC'
                                             BEGIN
                                                UPDATE FCXC SET CONTABILIZADA=2,NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSCXC = @REFERENCIA1
                                             END
                                             ELSE
                                             BEGIN
                                                IF @PROCEDENCIA='ANTICIPOS'
                                                BEGIN
                                                   UPDATE ANT SET CONTABILIZADO=2,NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSANT = @REFERENCIA1 AND CNSFCOM=@REFERENCIA2
                                                END
                                             END
                                          END
                                       END
                                    END
                                 END
                              END
                           END
                        END
                     END
                  END
               END
            END
         END
      END
      ELSE
      BEGIN
         BEGIN TRY
            BEGIN TRAN

            SELECT @CNT_MCHE = COUNT(*) FROM MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
            IF COALESCE(@CNT_MCHE, 0) = 0
            BEGIN
               RAISERROR(N'El comprobante en MCPE no tiene movimientos en MCHE.', 16, 1)
            END

            IF NOT EXISTS (SELECT 1 FROM MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE)
            BEGIN
               RAISERROR(N'No existe el comprobante en MCPE.', 16, 1)
            END

            IF EXISTS (SELECT 1 FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE)
            BEGIN
               RAISERROR(N'Ya existe el comprobante en MCP; verifique contabilidad antes de reconstruir.', 16, 1)
            END

            PRINT N'--se copian en MCP y MCH el Comprobante MCPE MCHE ya que esta correcto'
            INSERT INTO MCP (COMPANIA, NROCOMPROBANTE, PROCEDENCIA, NOREFERENCIA, ANO, MES, FECHACONTABLE, TOTALDEBITO ,TOTALCREDITO, REFERENCIA1, REFERENCIA2,
                             REFERENCIA3, USUARIO, FECHA, LOTE ,OBSERVACION ,IDSEDE ,ESTADO ,ANULADO ,COMPROBANTE ,IDTERCERO, BANCO ,NOCHEQUE, VALOR_CHEQUE,
                             RPT_COMPROBANTE, FECHARADICACION, MARCA, SYS_COMPUTERNAME_MARCA, ESTADOIMP, CBTEINTERNO)
            SELECT COMPANIA, NROCOMPROBANTE, PROCEDENCIA, NOREFERENCIA, ANO, MES, FECHACONTABLE, TOTALDEBITO ,TOTALCREDITO, REFERENCIA1, REFERENCIA2,
                             REFERENCIA3, USUARIO, FECHA, LOTE ,OBSERVACION ,IDSEDE ,ESTADO ,ANULADO ,COMPROBANTE ,IDTERCERO, BANCO ,NOCHEQUE, VALOR_CHEQUE,
                             RPT_COMPROBANTE, FECHARADICACION, MARCA, SYS_COMPUTERNAME_MARCA, ESTADOIMP, CBTEINTERNO
            FROM   MCPE
            WHERE  NROCOMPROBANTE = @NROCOMPROBANTE

            INSERT INTO MCH (NROCOMPROBANTE, COMPANIA, TIPO ,CUENTA, IDTERCERO, CCOSTO, DETALLE, VALOR ,REFERENCIA1, REFERENCIA2, REFERENCIA3, N_FACTURA,
                             F_FACTURAREF, F_VENCE ,GENERA ,CLASE_GENERA ,CNSPAGO, ITEMREF, USUARIO, FECHA ,PREFIJO ,IDAREA, CLASECONT ,ESTADO, PROCESO,
                             VALOR_PORCIMP, BASE_IMP, PROCEDENCIA ,REFERENCIA_PRO, CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR ,IDOPERACION, FECHACONCILIACION,
                             IDPROVEEDOR, ENPRESUPUESTO, ESTADOIMP,IDSEDE,CTAREVERSION)
            SELECT NROCOMPROBANTE, COMPANIA, TIPO ,CUENTA, IDTERCERO, CCOSTO, DETALLE, VALOR ,REFERENCIA1, REFERENCIA2, REFERENCIA3, N_FACTURA,
                             F_FACTURAREF, F_VENCE ,GENERA ,CLASE_GENERA ,CNSPAGO, ITEMREF, USUARIO, FECHA ,PREFIJO ,IDAREA, CLASECONT ,ESTADO, PROCESO,
                             VALOR_PORCIMP, BASE_IMP, PROCEDENCIA ,REFERENCIA_PRO, CONCILIADO, CNSFCXCXP, CODUNG, CODPRG, ERROR ,IDOPERACION, FECHACONCILIACION,
                             IDPROVEEDOR, ENPRESUPUESTO, ESTADOIMP,IDSEDE,CTAREVERSION
            FROM   MCHE
            WHERE  NROCOMPROBANTE = @NROCOMPROBANTE

            SELECT @CNT_MCP = COUNT(*) FROM MCP WHERE NROCOMPROBANTE = @NROCOMPROBANTE
            SELECT @CNT_MCH  = COUNT(*) FROM MCH WHERE NROCOMPROBANTE = @NROCOMPROBANTE

            IF @CNT_MCP = 0 OR @CNT_MCH = 0 OR @CNT_MCH <> @CNT_MCHE
            BEGIN
               RAISERROR(N'No se confirm� el traslado a contabilidad (MCP/MCH). El comprobante permanece en MCPE.', 16, 1)
            END

            IF NOT EXISTS (
                  SELECT 1
                  FROM   MCP M
                  INNER JOIN MCPE E ON E.NROCOMPROBANTE = M.NROCOMPROBANTE
                  WHERE  M.NROCOMPROBANTE = @NROCOMPROBANTE
                  AND    M.PROCEDENCIA    = E.PROCEDENCIA
                  AND    M.COMPROBANTE    = E.COMPROBANTE
                  AND    M.ANO            = E.ANO
                  AND    M.MES            = E.MES
                  AND    M.TOTALDEBITO    = E.TOTALDEBITO
                  AND    M.TOTALCREDITO   = E.TOTALCREDITO
               )
            BEGIN
               RAISERROR(N'El encabezado en MCP no coincide con MCPE.', 16, 1)
            END

            --se coloca como contabilizado ok en el documento origen (solo tras confirmar MCP/MCH)
            IF @PROCEDENCIA = 'FACTURA'
         BEGIN
            UPDATE FTR SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE = @NROCOMPROBANTE WHERE N_FACTURA = @NOREFERENCIA
         END
         ELSE
         BEGIN
            IF @PROCEDENCIA = 'NOTDBCR'
            BEGIN
               UPDATE FNOT SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
               WHERE  CNSFNOT = @REFERENCIA1 AND CLASE = @REFERENCIA2
               IF @@ROWCOUNT = 0
               BEGIN
                  RAISERROR(N'No se actualiz� la nota FNOT; verifique CNSFNOT y CLASE.', 16, 1)
               END
            END
            ELSE
            BEGIN
               IF @PROCEDENCIA = 'CXC' AND COALESCE(@NOLOTE,'')<>'REV'
               BEGIN
                  UPDATE FPAG SET CONTABILIZADO = 1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                  WHERE  CNSFPAG = @REFERENCIA1 
               END
               ELSE
               BEGIN
                  IF @PROCEDENCIA='INV'
                  BEGIN
                     UPDATE IMOV SET CONTABILIZADA=1,MARCACONT=0,NROCOMPROBANTE=@NROCOMPROBANTE
                     WHERE CNSMOV=@REFERENCIA1
                  END
                  ELSE
                  BEGIN
                     IF @PROCEDENCIA = 'CAJA'
                     BEGIN
                        UPDATE FCJ SET CONTABILIZADA=1,MARCACONT=0,NROCOMPROBANTE=@NROCOMPROBANTE
                        WHERE  CNSFACJ = @REFERENCIA1 AND CODCAJA = @REFERENCIA2
                     
                        IF DBO.FNK_VALORVARIABLE('GENANTIDESDEORDENSER')='SI'
                        BEGIN 
                           PRINT 'ACTUALIZO EL COMPROBANTE EN CXP'
                           UPDATE FCXP SET NROCOMPROBANTE=@NROCOMPROBANTE
                           FROM FCXP INNER JOIN FCXPP ON FCXP.CNSFCXP=FCXPP.CNSFCXP
                           WHERE FCXPP.CODCAJA=@REFERENCIA2 
                           AND FCXPP.CNSFACJ = @REFERENCIA1 
                           AND FCXP.PROCEDENCIA='Anticipos'
                           AND COALESCE(FCXP.NROCOMPROBANTE,'')=''  
                        END
                        UPDATE BMOV SET NROCOMPROBANTE=FCJ.NROCOMPROBANTE,CONTABILIZADA=FCJ.CONTABILIZADA 
                        FROM BMOV 
                        INNER JOIN FCJ ON BMOV.CODCAJA=FCJ.CODCAJA AND BMOV.CNSFACJ=FCJ.CNSFACJ 
                        WHERE BMOV.PROCEDENCIA='CAJA' AND COALESCE(BMOV.NROCOMPROBANTE,'')='' AND FCJ.NROCOMPROBANTE=@NROCOMPROBANTE
                     END
                     ELSE
                     BEGIN
                        IF @PROCEDENCIA = 'NOMINA'
                        BEGIN
                           UPDATE NIEPE SET CONTABILIZADA = 1, NROCOMPROBANTE = @NROCOMPROBANTE, COMPROBANTE = @COMPROBANTE, NOREFERENCIA = @NOREFERENCIA 
                           WHERE  CNSPAGO = @REFERENCIA2 AND NUMDOC = @REFERENCIA1
                           UPDATE NIEPED SET CONTABILIZADA = 1, NROCOMPROBANTE = @NROCOMPROBANTE, COMPROBANTE = @COMPROBANTE, NOREFERENCIA = @NOREFERENCIA 
                           FROM   NIEPE INNER JOIN NIEPED ON NIEPE.CNSNIEPE = NIEPED.CNSNIEPE 
                                                         AND NIEPE.NUMDOC   = NIEPED.NUMDOC
                           WHERE  NIEPE.CNSPAGO = @REFERENCIA2 
                           AND    NIEPE.NUMDOC  = @REFERENCIA1
                        END
                        ELSE
                        BEGIN
                           IF @PROCEDENCIA = 'CXP'
                           BEGIN
                              UPDATE FCXP SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE FCXP.CNSFCXP=@REFERENCIA1
                           END
                           ELSE
                           BEGIN
                              IF @PROCEDENCIA = 'NOTDBCRCXP'
                              BEGIN
                                 UPDATE FCXPDBCR SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSFCXP=@REFERENCIA1 AND ITEM = @REFERENCIA2
                              END
                              ELSE
                              BEGIN
                                 IF @PROCEDENCIA = 'CXC'   AND COALESCE(@NOLOTE,'')<>'REV'
                                 BEGIN
                                    UPDATE FPAG SET CONTABILIZADO=1, NROCOMPROBANTE=@NROCOMPROBANTE, MARCACONT=0 WHERE CNSFPAG=@REFERENCIA1
                                 END
                                 ELSE
                                 BEGIN
                                    IF @PROCEDENCIA = 'BMOV'
                                    BEGIN
                                       IF COALESCE(DBO.FNK_VALORVARIABLE('LONGITUDCODBANCO'),'') = 3
                                          UPDATE BMOV SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                                          WHERE BANCO    = SUBSTRING(@REFERENCIA1,1,3)
                                          AND   SUCURSAL = SUBSTRING(@REFERENCIA1,4,2)
                                          AND   CTA_BCO  = SUBSTRING(@REFERENCIA1,6,20)
                                          AND   ITEM     = CONVERT(INT,@REFERENCIA2)
                                       ELSE
                                          UPDATE BMOV SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE 
                                          WHERE BANCO    = SUBSTRING(@REFERENCIA1,1,2)
                                          AND   SUCURSAL = SUBSTRING(@REFERENCIA1,3,2)
                                          AND   CTA_BCO  = SUBSTRING(@REFERENCIA1,5,20)
                                          AND   ITEM     = CONVERT(INT,@REFERENCIA2)
                                    END
                                    ELSE
                                    BEGIN
                                       IF @PROCEDENCIA = 'CONCI'
                                       BEGIN
                                          UPDATE FCONCI SET CONTABILIZADA=1, NROCOMPROBANTE=@NROCOMPROBANTE WHERE IDFCONCI=@REFERENCIA1
                                       END
                                       ELSE
                                       BEGIN
                                          IF @PROCEDENCIA = 'RGLO'
                                          BEGIN
                                             UPDATE FGLO SET CONTABILIZADA=1, MARCACONT=0, NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSGLO=@REFERENCIA1
                                          END
                                          ELSE
                                          BEGIN
                                             IF @PROCEDENCIA = 'RAD CXC'
                                             BEGIN
                                                UPDATE FCXC SET CONTABILIZADA=1,NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSCXC = @REFERENCIA1
                                             END
                                             ELSE
                                             BEGIN
                                                IF @PROCEDENCIA='ANTICIPOS'
                                                BEGIN
                                                   UPDATE ANT SET CONTABILIZADO=1,NROCOMPROBANTE=@NROCOMPROBANTE WHERE CNSANT = @REFERENCIA1 AND CNSFCOM=@REFERENCIA2
                                                END
                                             END         
                                          END
                                       END
                                    END
                                 END
                              END
                           END
                        END
                     END
                  END
               END            
            END
         END

         --se borran de mcpe, mche (solo tras confirmar MCP/MCH y marcar documento origen)
         DELETE MCHE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
         DELETE MCPE WHERE NROCOMPROBANTE = @NROCOMPROBANTE
         /* CONFIRMACION AUTOMATICA DEL COMPROBANTE DE FACTURACION */
         EXEC SPK_NC_CONFIRMAR_CONTAB @NROCOMPROBANTE, @USUARIO, @COMPANIA, @SEDE, @SYS_COMPUTERNAME, @ANO, @MES, @PROCEDENCIA, @NOREFERENCIA, 'CONTABILIZAR'
         -- se hace el proceso de saldos de cuenta x cobrar
         PRINT '@PROCEDENCIA='+@PROCEDENCIA
         
         IF @PROCEDENCIA = 'FACTURA'
         BEGIN
            EXEC SPK_INGRESA_SALDOS_FTR @NROCOMPROBANTE, @NOREFERENCIA, 'FTR'
         END
         ELSE
         BEGIN
            IF @PROCEDENCIA = 'NOTAS'
            BEGIN
               SELECT @PROCNOTA = PROCEDENCIA, @N_FACTURA = N_FACTURA FROM FNOT WHERE CNSFNOT = @REFERENCIA1 AND CLASE = @REFERENCIA2
               IF @REFERENCIA2='C' AND @PROCNOTA = 'NOTAS'
               BEGIN 
                  PRINT 'INGRESO A FTRCXC'
  
                  INSERT INTO @TABLA (N_FACTURA, CCOSTO, VALOR) 
                  SELECT N_FACTURA,CCOSTO, SUM(VR_TOTAL) VALOR 
                  FROM   FNOTD WHERE CNSFNOT=@REFERENCIA1
                  GROUP BY N_FACTURA,CCOSTO
                  PRINT 'INICIO UPDATE'

                  UPDATE FTRCXC SET SALDO=FTRCXC.SALDO - X.VALOR
                  FROM   FTRCXC  INNER JOIN @TABLA X ON FTRCXC.N_FACTURA = X.N_FACTURA 
                                               AND FTRCXC.CCOSTO    = X.CCOSTO
                  WHERE  FTRCXC.N_FACTURA = @N_FACTURA
             
               END
            END
         END

            COMMIT TRAN
         END TRY
         BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN
            SET @ERRMSG = ERROR_MESSAGE()
            RAISERROR(@ERRMSG, 16, 1)
            RETURN
         END CATCH
      END 
   END
   ELSE
   BEGIN
      PRINT 'REVISION DE NIIF'
      DECLARE @NROCOMPROBANTEMCP VARCHAR(20)
      DECLARE @COM VARCHAR(20)
      SELECT @NROCOMPROBANTEMCP=NROCOMPROBANTEMCP,@COM=COMPROBANTE  FROM MCPE WHERE NROCOMPROBANTE=@NROCOMPROBANTE

      EXEC SPK_PASA_MCP_MCPNIIF @NROCOMPROBANTEMCP, @COMPANIA,@USUARIO,@SYS_COMPUTERNAME,@SEDE,@COM,@NROCOMPROBANTE      
   END
END
