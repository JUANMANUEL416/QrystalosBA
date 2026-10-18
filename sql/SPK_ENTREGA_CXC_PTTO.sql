IF EXISTS (SELECT NAME FROM SYSOBJECTS WHERE NAME = 'SPK_ENTREGA_CXC_PTTO' AND TYPE = 'P')
BEGIN
   DROP PROCEDURE SPK_ENTREGA_CXC_PTTO      
END
GO
CREATE PROCEDURE DBO.SPK_ENTREGA_CXC_PTTO 
@CNSCXC VARCHAR(20) , 
@IDSEDE VARCHAR(5)
WITH ENCRYPTION
AS
DECLARE @CNSFCT       VARCHAR(40)
DECLARE @CONSECUTIVO  VARCHAR(20)  --PRESUPUESTO
DECLARE @CCOSTOPRESUP VARCHAR(20)  --PRESUPUESTO
DECLARE @RECO         VARCHAR(20)  --PRESUPUESTO
DECLARE @FECHARECEP   DATETIME
DECLARE @N_FACTURA    VARCHAR(16)
DECLARE @ENPPTO       INT
DECLARE @CLASEPRECO   VARCHAR(20)
BEGIN 
   SELECT @FECHARECEP=COALESCE(CASE WHEN DBO.FNK_VALORVARIABLE('PPTO_FECHAPTRECO')='FECHACXC' THEN   FECHACXC ELSE F_RECIBIDO END,FECHACXC),@ENPPTO=COALESCE(ENPRESUPUESTO,0) FROM FCXC WHERE CNSCXC=@CNSCXC
   IF @ENPPTO=1
   BEGIN
      RAISERROR ('Esta Cuenta Por Cobrar Ya Se encuentra En Prepupuesto',16,1)
      RETURN
   END
   SELECT @CONSECUTIVO  = CONSECUTIVO FROM PTPTO WHERE FECHAINI <= @FECHARECEP AND FECHAFIN >= @FECHARECEP
   SELECT @CCOSTOPRESUP = DBO.FNK_VALORVARIABLE('PRESUP_CCOSTO')
   PRINT 'ESTE EL CCOSTO PRESUPUESTO:::: '+@CCOSTOPRESUP
   IF COALESCE(@CCOSTOPRESUP,'')=''
   BEGIN
      RAISERROR ('No Esta Configurada la Variable de Presupuesto',16,1)
      RETURN
   END  
   SELECT @CLASEPRECO = DBO.FNK_VALORVARIABLE('PRESUP_TIPORECO')
   IF COALESCE(@CLASEPRECO,'')=''
   BEGIN
      RAISERROR ('No Esta Configurada la Variable de Tipo de Reconocimiento',16,1)
      RETURN
   END  
   IF DBO.FNK_VALORVARIABLE('PRESUP_TIPORECO')='FACTURA'
   BEGIN 
      DECLARE FTR_CURSOR CURSOR FOR  
      SELECT FTR.N_FACTURA,FTR.CNSFCT
      FROM   FTR, FCXCD
      WHERE  FTR.N_FACTURA   = FCXCD.N_FACTURA
      AND    FCXCD.CNSCXC    = @CNSCXC
      AND    COALESCE(FTR.ENPRESUPUESTO,0)=0

      OPEN FTR_CURSOR  
      FETCH NEXT FROM FTR_CURSOR  
      INTO  @N_FACTURA,@CNSFCT
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         PRINT '@N_FACTURA='+@N_FACTURA
         IF NOT  EXISTS(SELECT * FROM PTRECO WHERE CONSECUTIVO=@CONSECUTIVO AND N_FACTURA=@N_FACTURA AND CNSFTR=@CNSFCT AND ESTADO<>'Anulado')
         BEGIN
            PRINT 'INGRESO A CREAR EL RECONOCIMIENTO'
            SELECT @RECO = ISNULL(CONTADOR_RR,0) + 1 
            FROM   PTPTO 
            WHERE  COMPANIA = '01' AND CONSECUTIVO = @CONSECUTIVO
         

            SELECT @RECO = @IDSEDE + REPLACE(SPACE(8 - LEN(@RECO))+LTRIM(RTRIM(@RECO)),SPACE(1),0) 
          
            PRINT 'CONSECUTIVO DE PTRCO :: '+@RECO            
            INSERT INTO PTRECO(COMPANIA, CONSECUTIVO, RECO, OBJETIVO, VALOR, CNSFCXC, IDTERCERO, FECHA, ESTADO, CCOSTO, N_FACTURA, CNSFTR,TIPO)
            SELECT '01', @CONSECUTIVO, @RECO, 'REGIMEN: ' + PLN.TIPOSISTEMA+ ' ' + 
                   CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                   ' FACTURADO EN EL MES DE ' + CASE MONTH(FTR.F_FACTURA) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                          WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                          WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                          WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                                END,
                   FTR.VR_TOTAL, @CNSCXC, FTR.IDTERCERO, @FECHARECEP, 'NoConfirmado', @CCOSTOPRESUP, @N_FACTURA, @CNSFCT,'Suma'
            FROM   FTR  LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
            WHERE  N_FACTURA = @N_FACTURA
         
            UPDATE PTPTO SET CONTADOR_RR = ISNULL(CONTADOR_RR,0) + 1 
            WHERE  COMPANIA    = '01' 
            AND    CONSECUTIVO = @CONSECUTIVO
         
            INSERT INTO PTRECOD (COMPANIA, CONSECUTIVO, RECO, CLASE, RUBRO, OBJETIVO, VALOR,VALOR_RECA,SALDO, RUBRO_ID,VIGENCIA ) --, SALDO)
            SELECT '01', @CONSECUTIVO, @RECO, 'Ingreso', PLN.RUBRO, CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                   ' FACTURADO EN EL MES DE ' + CASE MONTH(FTR.F_FACTURA) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                          WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                          WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                          WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                                END,
                   FTR.VR_TOTAL,0,FTR.VR_TOTAL , PLN.RUBRO_ID,'Actual'
            FROM   FTR  LEFT JOIN PLN          ON FTR.IDPLAN = PLN.IDPLAN
            WHERE  N_FACTURA = @N_FACTURA 
         END
         ELSE
         BEGIN
            PRINT 'YA EXISTE BUSCO EL RECONOCIMIENTO PARA ACTUALIZAR '
            SELECT @RECO=RECO FROM PTRECO WHERE CONSECUTIVO=@CONSECUTIVO AND N_FACTURA=@N_FACTURA AND CNSFTR=@CNSFCT AND ESTADO<>'Anulado'
         END
         UPDATE FTR SET ENPRESUPUESTO = 1, CONSECUTIVOPTO = @CONSECUTIVO, RECO = @RECO
         WHERE  N_FACTURA = @N_FACTURA
      FETCH NEXT FROM FTR_CURSOR  
      INTO  @N_FACTURA,@CNSFCT
      END
      CLOSE FTR_CURSOR  
      DEALLOCATE FTR_CURSOR 
   END
   ELSE 
   BEGIN
      DECLARE @CUANTOS INT
      SELECT @CUANTOS=COUNT(*) FROM(
                                    SELECT DISTINCT FTR.IDPLAN 
                                    FROM FTR INNER JOIN FCXCD ON FTR.N_FACTURA=FCXCD.N_FACTURA
                                    WHERE FCXCD.CNSCXC=@CNSCXC ) A                                
      PRINT 'NUMERO DE PLANES:::'+STR(@CUANTOS)
      IF @CUANTOS=1
      BEGIN 
         SELECT @RECO = ISNULL(CONTADOR_RR,0) + 1 
         FROM   PTPTO 
         WHERE  COMPANIA = '01' AND CONSECUTIVO = @CONSECUTIVO
         
         SELECT @RECO = @IDSEDE + REPLACE(SPACE(8 - LEN(@RECO))+LTRIM(RTRIM(@RECO)),SPACE(1),0) 
          
         PRINT 'CONSECUTIVO DE PTRCO :: '+@RECO            
         INSERT INTO PTRECO(COMPANIA, CONSECUTIVO, RECO, OBJETIVO, VALOR, CNSFCXC, IDTERCERO, FECHA, ESTADO, CCOSTO, N_FACTURA, CNSFTR,TIPO)
         SELECT '01', @CONSECUTIVO, @RECO, 'REGIMEN: ' + PLN.TIPOSISTEMA+ ' ' + 
                CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                ' FACTURADO EN EL MES DE ' + CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                FCXC.VALORCXC, @CNSCXC, FCXC.IDTERCERO, @FECHARECEP, 'NoConfirmado', @CCOSTOPRESUP, @CNSCXC, @CNSCXC,'Suma'
         FROM   FTR INNER JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA
                    INNER JOIN FCXC  ON FCXCD.CNSCXC  = FCXC.CNSCXC
                    LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
         WHERE  FCXC.CNSCXC = @CNSCXC AND COALESCE(FTR.ENPRESUPUESTO,0)=0
         GROUP BY PLN.TIPOSISTEMA, CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                  FCXC.VALORCXC, FCXC.IDTERCERO,PLN.CAPITADO                                           
         
         UPDATE PTPTO SET CONTADOR_RR = ISNULL(CONTADOR_RR,0) + 1 
         WHERE  COMPANIA    = '01' 
         AND    CONSECUTIVO = @CONSECUTIVO 
           
         INSERT INTO PTRECOD (COMPANIA, CONSECUTIVO, RECO, CLASE, RUBRO, OBJETIVO, VALOR,VALOR_RECA,SALDO, RUBRO_ID,VIGENCIA )
         SELECT '01', @CONSECUTIVO, @RECO, 'Ingreso', PLN.RUBRO, CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                ' FACTURADO EN EL MES DE ' + CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                FCXC.VALORCXC,0,FCXC.VALORCXC , PLN.RUBRO_ID,'Actual'
         FROM   FTR INNER JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA
                    INNER JOIN FCXC  ON FCXCD.CNSCXC  = FCXC.CNSCXC
                    LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
         WHERE  FCXCD.CNSCXC = @CNSCXC AND COALESCE(FTR.ENPRESUPUESTO,0)=0
         GROUP BY PLN.TIPOSISTEMA, CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                  FCXC.VALORCXC, FCXC.IDTERCERO,PLN.CAPITADO,PLN.RUBRO  , PLN.RUBRO_ID     
         
         UPDATE FTR SET ENPRESUPUESTO = 1, CONSECUTIVOPTO = @CONSECUTIVO, RECO = @RECO
         FROM FTR INNER JOIN FCXCD ON FTR.N_FACTURA=FCXCD.N_FACTURA
         WHERE  FCXCD.CNSCXC = @CNSCXC             
      END
      ELSE 
      BEGIN
         DECLARE @IDPLAN VARCHAR(10) 
         DECLARE PG_CURSOR CURSOR FOR 
         SELECT DISTINCT FTR.IDPLAN FROM FTR INNER JOIN FCXCD ON FTR.N_FACTURA=FCXCD.N_FACTURA
         WHERE FCXCD.CNSCXC=@CNSCXC   
         OPEN PG_CURSOR    
         FETCH NEXT FROM PG_CURSOR    
         INTO @IDPLAN
         WHILE @@FETCH_STATUS = 0    
         BEGIN 
         SELECT @RECO = ISNULL(CONTADOR_RR,0) + 1 
         FROM   PTPTO 
         WHERE  COMPANIA = '01' AND CONSECUTIVO = @CONSECUTIVO
         
         SELECT @RECO = @IDSEDE + REPLACE(SPACE(8 - LEN(@RECO))+LTRIM(RTRIM(@RECO)),SPACE(1),0) 
          
         PRINT 'CONSECUTIVO DE PTRCO :: '+@RECO            
         INSERT INTO PTRECO(COMPANIA, CONSECUTIVO, RECO, OBJETIVO, VALOR, CNSFCXC, IDTERCERO, FECHA, ESTADO, CCOSTO, N_FACTURA, CNSFTR,TIPO)
         SELECT '01', @CONSECUTIVO, @RECO, 'REGIMEN: ' + PLN.TIPOSISTEMA+ ' ' + 
                CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                ' FACTURADO EN EL MES DE ' + CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                SUM(FTR.VR_TOTAL), @CNSCXC, FCXC.IDTERCERO, @FECHARECEP, 'NoConfirmado', @CCOSTOPRESUP, @CNSCXC, @CNSCXC,'Suma'
         FROM   FTR INNER JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA
                    INNER JOIN FCXC  ON FCXCD.CNSCXC  = FCXC.CNSCXC
                    LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
         WHERE  FCXC.CNSCXC = @CNSCXC AND FTR.IDPLAN=@IDPLAN AND COALESCE(FTR.ENPRESUPUESTO,0)=0
         GROUP BY PLN.TIPOSISTEMA, CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                  FCXC.VALORCXC, FCXC.IDTERCERO,PLN.CAPITADO                                           
         
         UPDATE PTPTO SET CONTADOR_RR = ISNULL(CONTADOR_RR,0) + 1 
         WHERE  COMPANIA    = '01' 
         AND    CONSECUTIVO = @CONSECUTIVO 
           
         INSERT INTO PTRECOD (COMPANIA, CONSECUTIVO, RECO, CLASE, RUBRO, OBJETIVO, VALOR,VALOR_RECA,SALDO,RUBRO_ID,VIGENCIA )
         SELECT '01', @CONSECUTIVO, @RECO, 'Ingreso', PLN.RUBRO, CASE COALESCE(PLN.CAPITADO,0) WHEN 0 THEN 'EVENTO' ELSE 'CAPITADO' END +
                ' FACTURADO EN EL MES DE ' + CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                SUM(FTR.VR_TOTAL),0,SUM(FTR.VR_TOTAL), PLN.RUBRO_ID,'Actual'
         FROM   FTR INNER JOIN FCXCD ON FTR.N_FACTURA = FCXCD.N_FACTURA
                    INNER JOIN FCXC  ON FCXCD.CNSCXC  = FCXC.CNSCXC
                    LEFT JOIN PLN ON FTR.IDPLAN = PLN.IDPLAN
         WHERE  FCXCD.CNSCXC = @CNSCXC AND FTR.IDPLAN=@IDPLAN AND COALESCE(FTR.ENPRESUPUESTO,0)=0
         GROUP BY PLN.TIPOSISTEMA, CASE MONTH(FCXC.FECHACXC) WHEN 1  THEN 'ENERO'   WHEN 2  THEN 'FEBRERO'   WHEN 3  THEN 'MARZO'
                                                                       WHEN 4  THEN 'ABRIL'   WHEN 5  THEN 'MAYO'      WHEN 6  THEN 'JUNIO'
                                                                       WHEN 7  THEN 'JULIO'   WHEN 8  THEN 'AGOSTO'    WHEN 9  THEN 'SEPTIEMBRE'
                                                                       WHEN 10 THEN 'OCTUBRE' WHEN 11 THEN 'NOVIEMBRE' WHEN 12 THEN 'DICIEMBRE'
                                             END,
                  FCXC.VALORCXC, FCXC.IDTERCERO,PLN.CAPITADO,PLN.RUBRO  , PLN.RUBRO_ID         
         
         UPDATE FTR SET ENPRESUPUESTO = 1, CONSECUTIVOPTO = @CONSECUTIVO, RECO = @RECO
         FROM FTR INNER JOIN FCXCD ON FTR.N_FACTURA=FCXCD.N_FACTURA
         WHERE  FCXCD.CNSCXC = @CNSCXC   AND FTR.IDPLAN=@IDPLAN
            FETCH NEXT FROM PG_CURSOR    
            INTO @IDPLAN
         END
         CLOSE PG_CURSOR
         DEALLOCATE PG_CURSOR    
      END    
   END
   UPDATE FCXC SET ENPRESUPUESTO=1 WHERE CNSCXC=@CNSCXC 
END
