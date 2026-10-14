CREATE OR ALTER PROCEDURE DBO.SPK_CIRCULARUNICA @CNSCIRUNI INT, @GEN_FILE BIT=0
WITH ENCRYPTION
AS
/* 
Fecha:		 2021-07-08
Descripci�n: Procedimiento que permite exportar XML de superSalud
modificado por Edgardo para agregar el FT003 11-07-2023
 NO TIENE ENCUENTA EL DETERIODO SE DEJA PENDIENTE PARA FUTURAS MEJORAS

*/
SET NOCOUNT ON
DECLARE @XML XML, @CNSPRO VARCHAR(20), @FFIN DATETIME
BEGIN
    PRINT CONCAT('EXEC SPK_CIRCULARUNICA ',@CNSCIRUNI)

    IF @GEN_FILE=1
    BEGIN
		--DECLARE @XML XML, @CNSPRO VARCHAR(20), @FFIN DATETIME ,  @CNSCIRUNI INT, @GEN_FILE BIT=0

		--select   @CNSCIRUNI = 3 , @GEN_FILE= 1
		DECLARE @SQLCmd VARCHAR(8000), @Path VARCHAR(256), @NIT VARCHAR(20), @DV VARCHAR(1), @ANO VARCHAR(4), @MES VARCHAR(2)
        SELECT @Path=DBO.FNK_VALORVARIABLE('PATH_XML_CONTA')
        IF RIGHT(@Path,1)<>'\' SET @Path=@Path+'\'
        SELECT @NIT=NIT, @DV=DV FROM TER WHERE IDTERCERO=DBO.FNK_VALORVARIABLE('IDTERCEROINSTALADO')
        SELECT @ANO=ANO, @MES=RIGHT('00'+CONVERT(VARCHAR(2),MES),2) FROM CIRUNI WHERE CNSCIRUNI=@CNSCIRUNI
        SET @Path=@Path+@NIT+@DV+@MES+@ANO

        DECLARE @FILES TABLE (ID INT IDENTITY, FORMATO VARCHAR(10))
        DECLARE @I INT, @I_TO INT, @FORMATO VARCHAR(10)

        INSERT INTO @FILES (FORMATO)
        SELECT FORMATO
        FROM (
            SELECT * FROM CIRUNI WHERE CNSCIRUNI=@CNSCIRUNI
        )SOURCE UNPIVOT(
            DETALLE FOR FORMATO IN ([FT001],[FT002],[FT003],[FT004],[FT005],[FT006],[FT007],[FT008],[FT009],[FT010])
        )X
        SELECT @I=1, @I_TO=MAX(ID) FROM @FILES
        WHILE @I<=@I_TO
        BEGIN
            SELECT @FORMATO=FORMATO FROM @FILES WHERE ID=@I

            SELECT @SQLCmd='bcp "SELECT '+@FORMATO+' FROM '+DB_NAME()+'..CIRUNI WHERE CNSCIRUNI='+CONVERT(VARCHAR(20),@CNSCIRUNI)+'" queryout '+@Path+@FORMATO+'.xml -w -T -S '+@@SERVERNAME

			--print @SQLCmd 

            EXEC xp_cmdshell @SQLCmd, NO_OUTPUT
            SET @I+=1
        END
        DELETE @FILES


    END
    ELSE
    BEGIN
        SELECT @CNSPRO=CNSPRO FROM CIRUNI WHERE CNSCIRUNI=@CNSCIRUNI

        BEGIN --FT001
            SET @XML=NULL
            DECLARE @FT001_DETALLE TABLE (ID INT IDENTITY, NIVEL SMALLINT, CUENTA VARCHAR(16), CLASE TINYINT, VALOR DECIMAL(18,0), CUENTA_SUMA VARCHAR(16), PASO SMALLINT)
            DECLARE @FT001 TABLE (codigoConcepto VARCHAR(16), claseConcepto TINYINT, valor DECIMAL(18,0))

            INSERT INTO @FT001_DETALLE (NIVEL, CUENTA, CLASE, VALOR, CUENTA_SUMA, PASO)
            SELECT 
                CUE.NIVEL,
                B.CUENTA, 
                CLASE=IIF(ISNULL(CUE.CORRIENTE,0)=0,1,CUE.CORRIENTE), 
                VALOR=ROUND(SUM(B.SF),0), 
                CUENTA_SUMA=COALESCE(CUE.CUENTA_SUMA,''),
                PASO=0
            FROM TBALANCEH AS B INNER JOIN CUE ON CUE.CUENTA=B.CUENTA
            WHERE B.CNSPRO=@CNSPRO AND B.SF>0 AND CUE.TIPO='Detalle'
            GROUP BY CUE.NIVEL, B.CUENTA, IIF(ISNULL(CUE.CORRIENTE,0)=0,1,CUE.CORRIENTE), COALESCE(CUE.CUENTA_SUMA,'')

            WHILE EXISTS (SELECT 1 FROM @FT001_DETALLE WHERE CUENTA_SUMA<>'' AND ISNULL(PASO,0)=0)
            BEGIN
                UPDATE @FT001_DETALLE SET PASO=1 WHERE PASO=0
    
                INSERT INTO @FT001_DETALLE (NIVEL, CUENTA, CLASE, VALOR, CUENTA_SUMA, PASO)
                SELECT NIVEL, CUENTA, CLASE, SUM(VALOR), CUENTA_SUMA, 0
                FROM (
                    SELECT 
                        CUE.NIVEL,
                        CUENTA=D.CUENTA_SUMA, 
                        D.CLASE, 
                        D.VALOR,
                        CUENTA_SUMA=IIF(COALESCE(CUE.CUENTA_SUMA,'')<>COALESCE(D.CUENTA_SUMA,''),CUE.CUENTA_SUMA,'')
                    FROM @FT001_DETALLE AS D
                        INNER JOIN CUE ON CUE.CUENTA=D.CUENTA_SUMA
                    WHERE D.CUENTA<>D.CUENTA_SUMA AND D.CUENTA_SUMA<>'' AND PASO=1
                ) X GROUP BY NIVEL, CUENTA, CLASE, CUENTA_SUMA

                UPDATE @FT001_DETALLE SET PASO=2 WHERE PASO=1
            END

            INSERT INTO @FT001 (claseConcepto, codigoConcepto, valor)
            SELECT CLASE, CUENTA, SUM(VALOR) 
            FROM @FT001_DETALLE
            GROUP BY CLASE, CUENTA

            SELECT @XML=(
                SELECT codigoConcepto, claseConcepto, valor 
                FROM @FT001
                FOR XML PATH('RegistroFT001'), root('FT001')
            )

            UPDATE CIRUNI SET FT001=@XML WHERE CNSCIRUNI=@CNSCIRUNI
        END --FT001
		BEGIN --FT003
            SELECT @FFIN=DATEADD(MONTH,MES,CONVERT(DATETIME,CONCAT(ANO,'0101'))) FROM CIRUNI WHERE CNSCIRUNI=@CNSCIRUNI
            
            SELECT @XML=(
                SELECT 
                    lineaNegocio=3, 
                    idDeudor= NIT,
                    dvDeudor=CASE  TIPO_ID WHEN 'NIT' THEN IIF(COALESCE(DV,'')='',0,DV) ELSE '' END,
                    nombreDeudor=RAZONSOCIAL,
                    codigoMunicipio= CIUDAD ,
                    conceptoDeudores= CONCEPTO,
					tipoDeuda= TIPODEUDA,
                    medicionPosterior= MEDICION,
					cxcPendientesRadicar =NORADICA ,
                    cxcNoVencidas=		 FORMAT( ISNULL([D0] ,0 ),	 'G', 'en-us') ,
                    cxcMora30dias=		 FORMAT( ISNULL([D30],0 ),   'G', 'en-us') ,
                    cxcMora60dias=		 FORMAT( ISNULL([D60],0 ),   'G', 'en-us') ,
                    cxcMora90dias=		 FORMAT( ISNULL([D90],0 ),   'G', 'en-us') ,
                    cxcMora180dias=		 FORMAT( ISNULL([D180],0),   'G', 'en-us') ,
                    cxcMora360dias=		 FORMAT( ISNULL([D360],0),   'G', 'en-us') ,
                    cxcMoraMayor360dias= FORMAT( ISNULL([DMAS],0),	 'G', 'en-us') ,
					deterioro30Dias		 = 0 ,
					deterioro60Dias		 = 0 ,
					deterioro90Dias		 = 0 ,
					deterioro180Dias	 = 0 ,
					deterioro360Dias	 = 0 ,
					deterioroMayor90Dias = 0 ,
                    ajuste=AJUSTE,
                    saldo=  FORMAT( (ISNULL([D0],0)+ISNULL([D30],0)+ISNULL([D60],0)+ISNULL([D90],0)+ISNULL([D180],0)+ISNULL([D360],0)+ISNULL([DMAS],0)+ISNULL(AJUSTE,0) +ISNULL(NORADICA,0) ),	 'G', 'en-us')
                FROM (
                   
						SELECT  RAZONSOCIAL, DV , NIT, TIPO_ID, CIUDAD,CONCEPTO, TIPODEUDA, MEDICION
							, SUM (NORADICADA) NORADICA
							, SUM( NOVENCIDAS ) D0
							,SUM(D_30) D30 , 
							SUM(D_60) D60 , 
							SUM(D_90) D90 , 
							SUM(D_180) D180 , 
							SUM(D_360) D360 , 
							SUM(D_MAS) DMAS , 
							0 DT30,
							0 DT60,
							0 DT90,
							0 DT120,
							0 DT180,
							0 DT360,
							0 DTMAS360,
							0 AJUSTE,
							SUM(SALDO) SALDO
						FROM (
	
							select COALESCE(b.ano, YEAR(A.F_FACTURA) ) ANO , COALESCE(b.mes, MONTH(A.F_FACTURA) ) MES, c.razonsocial , c.nit , c.dv , c.TIPO_ID, coalesce(c.ciudad, '') ciudad,
								case  when b.regimen in ('Contributivo','Subsidiado') then 1 
										when b.regimen in ('ARL','SOAT') then 5
										when b.regimen in ('Prepagado','Vinculado') then 2
								else 7
								end CONCEPTO,
								2 tipodeuda,
								1 MEDICION,
								COALESCE(NORADICADA,0) NORADICADA ,
								CASE WHEN COALESCE(B.F_RECIBIDO,'')='' THEN A.VR_TOTAL ELSE 0 END NOVENCIDAS,  
								COALESCE( B.D0_30, 0 ) D_30   ,
								COALESCE( B.D31_60, 0 ) D_60 ,
								COALESCE( B.D61_90, 0 ) D_90 ,
								COALESCE( B.D91_120, 0 )  +	COALESCE( B.D121_150, 0 ) + COALESCE( B.D151_180 , 0 ) D_180 ,
								COALESCE( B.D181_360, 0 ) D_360 ,
								COALESCE( B.D361_MAS, 0 ) D_MAS ,
									COALESCE(B.SALDONETO ,CASE WHEN COALESCE(B.F_RECIBIDO,'')='' THEN A.VR_TOTAL ELSE 0 END  ) SALDO
									, A.N_FACTURA
							from  ftr A inner join ter c on a.IDTERCERO = c.IDTERCERO 
									left outer join VWK_CXCDIASVTO B on a.N_FACTURA=b.N_FACTURA 
							WHERE COALESCE(B.TIPO,'F')='F'
	
						) Y
						GROUP BY RAZONSOCIAL , DV, NIT, TIPO_ID, CIUDAD,CONCEPTO, TIPODEUDA, MEDICION
					) Z
                FOR XML PATH('RegistroFT003'), root('FT003')
            )

            UPDATE CIRUNI SET FT003=@XML WHERE CNSCIRUNI=@CNSCIRUNI
        END --FT003
        BEGIN --FT004
            SELECT @FFIN=DATEADD(MONTH,MES,CONVERT(DATETIME,CONCAT(ANO,'0101'))) FROM CIRUNI WHERE CNSCIRUNI=@CNSCIRUNI
            
            SELECT @XML=(
                SELECT 
                    lineaNegocio=3, 
                    tipoIdAcreedor=(CASE TER.TIPO_ID WHEN 'CC' THEN 'CC' WHEN 'CE' THEN 'CE' WHEN 'NIT' THEN 'NI' ELSE 'OT' END),
                    idAcreedor=TER.NIT,
                    dvAcreedor=IIF(COALESCE(TER.DV,'')='',0,TER.DV),
                    nombreAcreedor=TER.RAZONSOCIAL,
                    actividadAcreedor=IIF(COALESCE(TER.IDACTIVIDAD,'')='','NA',TER.IDACTIVIDAD),
                    conceptoAcreencia=X.CONCEPTO,
                    medicionPosterior=X.MEDICION,
                    cxpNoVencidas=ISNULL([D0],0),
                    cxpMora30dias=ISNULL([D30],0),
                    cxpMora60dias=ISNULL([D60],0),
                    cxpMora90dias=ISNULL([D90],0),
                    cxpMora180dias=ISNULL([D180],0),
                    cxpMora360dias=ISNULL([D360],0),
                    cxpMoraMayor360dias=ISNULL([D361],0),
                    ajuste=X.AJUSTE,
                    saldo=(ISNULL([D0],0)+ISNULL([D30],0)+ISNULL([D60],0)+ISNULL([D90],0)+ISNULL([D180],0)+ISNULL([D360],0)+ISNULL([D361],0)+ISNULL(X.AJUSTE,0))
                FROM (
                    SELECT IDTERCERO, CONCEPTO, MEDICION, SALDO, AJUSTE=0,
                        VIGENCIA=(CASE 
                            WHEN DIAS BETWEEN 1   AND 30  THEN 'D30'
                            WHEN DIAS BETWEEN 31  AND 60  THEN 'D60'
                            WHEN DIAS BETWEEN 61  AND 90  THEN 'D90'
                            WHEN DIAS BETWEEN 91  AND 180 THEN 'D180'
                            WHEN DIAS BETWEEN 181 AND 360 THEN 'D360'
                            WHEN DIAS>= 361 THEN 'D361'
                            ELSE 'D0' END) 
                    FROM (
                        SELECT FCXP.IDTERCERO, 
                            CONCEPTO=IIF(COALESCE(CUE.CONCEPTO_ACREENCIA,'')='','6',CUE.CONCEPTO_ACREENCIA),
                            MEDICION=(CASE PROCEDENCIA WHEN 'Nomina' THEN 1 ELSE 6 END),
                            DIAS=DATEDIFF(DAY, FCXP.F_VENCE, DATEADD(MINUTE,-1,@FFIN)),
                            SALDO=CEILING(FCXP.SALDO)
                        FROM FCXP LEFT JOIN CUE ON CUE.CUENTA=FCXP.CUECREDITO
                        WHERE ISNULL(FCXP.CONTABILIZADA,0)=1 AND FCXP.ESTADO<>'A' 
                            AND FCXP.SALDO>0 AND FCXP.F_FACTURAREF<@FFIN
                    ) AS Z
                ) SOURCE PIVOT (
                    SUM(SALDO) FOR VIGENCIA IN ([D0],[D30],[D60],[D90],[D180],[D360],[D361])
                ) AS X
                    INNER JOIN TER ON TER.IDTERCERO=X.IDTERCERO
                FOR XML PATH('RegistroFT004'), root('FT004')
            )

            UPDATE CIRUNI SET FT004=@XML WHERE CNSCIRUNI=@CNSCIRUNI
        END --FT004
        BEGIN --FT006
            SET @XML=NULL
            DECLARE @BANCO TABLE (ID INT IDENTITY, CUENTA VARCHAR(16), VALOR DECIMAL(18,0), BANCO VARCHAR(3), SUCURSAL VARCHAR(2), CTA_BCO VARCHAR(40))

            INSERT INTO @BANCO (CUENTA, VALOR, BANCO, SUCURSAL, CTA_BCO)
            SELECT B.CUENTA, VALOR=SUM(B.SF), BCT.BANCO, BCT.SUCURSAL, BCT.CTA_BCO
            FROM TBALANCEH AS B 
                INNER JOIN BCT ON BCT.COD_CONTABLE=B.CUENTA
            WHERE B.CNSPRO=@CNSPRO AND B.SF>0
            GROUP BY B.CUENTA, BCT.BANCO, BCT.SUCURSAL, BCT.CTA_BCO
            
            SELECT @XML=(
                SELECT 
                    lineaNegocio=3, 
                    establecimiento=LEFT(TER.RAZONSOCIAL,100),
                    idEstablecimiento=TER.NIT,
                    codigoSIMEV=IIF(COALESCE(BCT.SIMEV,'')='','001-001',BCT.SIMEV),
                    clasificacionRiesgo=COALESCE(BCT.RIESGO,''),
                    entidadCalificadora=IIF(COALESCE(BCT.ENTIDAD_CALIFICADORA,'')='','0',BCT.ENTIDAD_CALIFICADORA),
                    otraCalificadora=IIF(COALESCE(BCT.ENTIDAD_CALIFICADORA,'')='4',BCT.OTRA_CALIFICADORA,'NA'),
                    claseCuenta=(CASE 
                        WHEN CC.DESCRIPCION LIKE '%CORRIENTE%' THEN 1
                        WHEN CC.DESCRIPCION LIKE '%AHORRO%' THEN 2
                        WHEN CC.DESCRIPCION LIKE '%MAESTRA%' THEN 3
                        WHEN CC.DESCRIPCION LIKE '%ABIERTA%' THEN 4
                        WHEN CC.DESCRIPCION LIKE '%CERRADA%' THEN 5
                        ELSE 6 END),
                    tipoMoneda=IIF(COALESCE(MND.CODIFICACION,'')='','COP',MND.CODIFICACION),
                    idCuenta=BCT.CTA_BCO,
                    nombreCuenta=CUE.NOMCUENTA,
                    saldoExtracto=CEILING(BCT.SALDO),
                    saldoLibros=CEILING(B.VALOR),
                    sobregiro=0, -->
                    rendimientos=0, -->
                    gravamen=ISNULL(BCT.GRAVAMEN,0),
                    estado=IIF(COALESCE(BCT.ESTADO_BCO,'')='','0',BCT.ESTADO_BCO),
                    fechaMedida=0, -->
                    valorMedida=0, -->
                    inversionReservas=0
                FROM @BANCO B 
                    INNER JOIN BCT ON BCT.BANCO=B.BANCO AND BCT.SUCURSAL=B.SUCURSAL AND BCT.CTA_BCO=B.CTA_BCO
                    INNER JOIN BCO ON BCO.BANCO=B.BANCO
                    INNER JOIN TER ON TER.IDTERCERO=BCO.IDTERCERO
                    INNER JOIN CUE ON CUE.CUENTA=B.CUENTA
                    LEFT  JOIN MND ON MND.IDMONEDA=BCT.IDMONEDA
                    LEFT  JOIN TGEN CC ON CC.TABLA='General' AND CC.CAMPO='TIPOCUENTABCT' AND CC.CODIGO=BCT.TIPO_CUENTA
                FOR XML PATH('RegistroFT006'), root('FT006')
            )

            UPDATE CIRUNI SET FT006=@XML WHERE CNSCIRUNI=@CNSCIRUNI
        END --FT006
        BEGIN --GT010
            SET @XML=NULL
            DECLARE @GT010 TABLE (ID INT IDENTITY, CUENTA VARCHAR(16), IDTERCERO VARCHAR(20), VALOR DECIMAL(18,0))

            INSERT INTO @GT010 (CUENTA, IDTERCERO, VALOR)
            SELECT B.CUENTA, B.IDTERCERO, VALOR=CEILING(SUM(B.SF))
            FROM TBALANCEH AS B 
                INNER JOIN CUE ON CUE.CUENTA=B.CUENTA
            WHERE B.CNSPRO=@CNSPRO AND B.SF>0 AND LEFT(B.CUENTA,1) IN (1,2)
                AND CUE.TIPO='Detalle' AND CUE.NOMCUENTA LIKE '%ACCIONISTA%'
            GROUP BY B.CUENTA, B.IDTERCERO
            
            SELECT @XML=(
                SELECT 
	                tipoReporte=1,
	                tipoIdAportante=(CASE TER.TIPO_ID WHEN 'CC' THEN 'CC' WHEN 'CE' THEN 'CE' WHEN 'NIT' THEN 'NI' ELSE 'OT' END),
	                idAportante=TER.NIT,
	                dvAportante=IIF(COALESCE(TER.DV,'')='',0,TER.DV),
	                nombreAportante=TER.RAZONSOCIAL,
	                codigoMunicipio=TER.CIUDAD,
	                valor=G.VALOR
                FROM @GT010 G
	                INNER JOIN TER ON TER.IDTERCERO=G.IDTERCERO
                FOR XML PATH('RegistroGT010'), root('GT010')
            )

            UPDATE CIRUNI SET GT010=@XML WHERE CNSCIRUNI=@CNSCIRUNI
        END --GT010
    END
END
