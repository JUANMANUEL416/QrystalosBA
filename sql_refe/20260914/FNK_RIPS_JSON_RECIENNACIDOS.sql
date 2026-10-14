CREATE OR ALTER FUNCTION DBO.FNK_RIPS_JSON_RECIENNACIDOS(@NOADMISION VARCHAR(20),@N_FACTURA VARCHAR(20),@PROCEDENCA VARCHAR(10),@TIPODOC VARCHAR(2),@DOCIDAFILIADO VARCHAR(20),@IDTERINSTA VARCHAR(20))
RETURNS VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    DECLARE @PLANO VARCHAR(MAX)
    DECLARE @IDPRESTADOR VARCHAR(20)
    DECLARE @NRO INT
    DECLARE @CANT INT
    DECLARE @codPrestador VARCHAR(20)
    DECLARE @tipoDocumentoldentificacion VARCHAR(2)
    DECLARE @numDocumentoldentificacion VARCHAR(20)
    DECLARE @fechaNacimiento VARCHAR(16)
    DECLARE @edadGestacional VARCHAR(2)
    DECLARE @numConsultasCPrenatal VARCHAR(2)
    DECLARE @codSexoBiologico VARCHAR(2)
    DECLARE @peso VARCHAR(4)
    DECLARE @codDiagnosticoPrincipal VARCHAR(20)
    DECLARE @condicionDestinoUsuarioEgreso VARCHAR(2)
    DECLARE @codDiagnosticoCausaMuerte VARCHAR(20)
    DECLARE @fechaEgreso VARCHAR(16)
    DECLARE @consecutivo VARCHAR(4)
    DECLARE @PLANTILLA VARCHAR(20)
    DECLARE @CAMPO VARCHAR(20)
    DECLARE @NRODOCUMENTO VARCHAR(20)
    DECLARE @TIPODOCRN VARCHAR(4)
    DECLARE @CONSECUTIVOHCA VARCHAR(20)

    SELECT @IDPRESTADOR=COALESCE(IDALTERNA2,'No tengo')
    FROM TER 
    WHERE IDTERCERO=@IDTERINSTA
    IF EXISTS(SELECT 1 FROM QXRCN WHERE NOADMISION=@NOADMISION)
    BEGIN
        IF(SELECT COUNT(1) FROM QXRCN WHERE NOADMISION=@NOADMISION)=1
        BEGIN
            IF EXISTS(SELECT 1 FROM HCAO WHERE PROCESO='RNACIDO' AND CAMPODESTINO='NRODOCUMENTO' )
            BEGIN
                SELECT  @CONSECUTIVOHCA=CONSECUTIVOHC
                FROM HADM INNER JOIN QXRCN ON HADM.NOADMISION=QXRCN.NOADMISION
                WHERE HADM.NOADMISION=@NOADMISION

                IF COALESCE(@CONSECUTIVOHCA,'')<>'' AND EXISTS(SELECT 1 FROM HCA WHERE CONSECUTIVO=@CONSECUTIVOHCA AND NOADMISION=@NOADMISION)
                BEGIN
                    SELECT  @PLANTILLA=CLASEPLANTILLA,@CAMPO=CAMPO FROM HCAO WHERE PROCESO='RNACIDO' AND CAMPODESTINO='NRODOCUMENTO' 
                    SELECT @NRODOCUMENTO=COALESCE(ALFANUMERICO,'') FROM HCAD WHERE CLASEPLANTILLA=@PLANTILLA AND CAMPO=@CAMPO AND CONSECUTIVO=@CONSECUTIVOHCA
                    SET @PLANTILLA= ''

                    SELECT  @PLANTILLA=CLASEPLANTILLA,@CAMPO=CAMPO FROM HCAO WHERE PROCESO='RNACIDO' AND CAMPODESTINO='TIPODOC' 
                    IF COALESCE(@PLANTILLA,'')<>''
                    BEGIN
                        SELECT @TIPODOCRN=COALESCE(ALFANUMERICO,'') FROM HCAD WHERE CLASEPLANTILLA=@PLANTILLA AND CAMPO=@CAMPO AND CONSECUTIVO=@CONSECUTIVOHCA
                    END
                END
            END
            SELECT @codPrestador = @IDPRESTADOR,
                @tipoDocumentoldentificacion = COALESCE (@TIPODOCRN, 'CN'),
                @numDocumentoldentificacion = COALESCE (@NRODOCUMENTO, QXRCN.NRODOCUMENTO),
                @fechaNacimiento = REPLACE(CONVERT (VARCHAR, QXRCN.RNFECHANACE, 102), '.', '-') + ' ' + LEFT(CONVERT (VARCHAR, QXRCN.RNFECHANACE, 108), 5),
                @edadGestacional = QXRCN.CMPERIODOGES,
                @numConsultasCPrenatal = QXRCN.CMCONTROLPRE,
                @codSexoBiologico = CASE WHEN QXRCN.RNSEXO IN ('F', 'Femenino')  THEN '02' WHEN QXRCN.RNSEXO IN ('M', 'Masculino') THEN '01' ELSE '03' END,
                @peso = QXRCN.RNPESO,
                @codDiagnosticoPrincipal = QXRCN.RNDX,
                @condicionDestinoUsuarioEgreso = '0' + CAST (QXRCN.ESTADORN AS VARCHAR (1)),
                @codDiagnosticoCausaMuerte = CASE WHEN QXRCN.CMCAUSAMUERTE = '' THEN 'null' ELSE QXRCN.CMCAUSAMUERTE END,
                @fechaEgreso = REPLACE(CONVERT (VARCHAR, HADM.FECHAALTAMED, 102), '.', '-') + ' ' + LEFT(CONVERT (VARCHAR, HADM.FECHAALTAMED, 108), 5),
                @consecutivo = 1
            FROM HADM 
                INNER JOIN QXRCN ON HADM.NOADMISION = QXRCN.NOADMISION
            WHERE  HADM.NOADMISION = @NOADMISION;

            SET @PLANO = '';
            SET @PLANO += '{ ';
            SET @PLANO += ' "codPrestador":"' + COALESCE (@codPrestador, '') + '",';
            SET @PLANO += ' "tipoDocumentoIdentificacion":"' + COALESCE (@tipoDocumentoldentificacion, 'CN') + '",';
            SET @PLANO += ' "numDocumentoIdentificacion":"' + COALESCE (@numDocumentoldentificacion, '') + '",';
            SET @PLANO += ' "fechaNacimiento":"' + COALESCE (@fechaNacimiento, '') + '",';
            SET @PLANO += ' "edadGestacional":' + COALESCE (@edadGestacional, '0') + ',';
            SET @PLANO += ' "numConsultasCPrenatal":' + CASE WHEN ISNUMERIC(@numConsultasCPrenatal) = 1 THEN @numConsultasCPrenatal ELSE CAST (2 AS VARCHAR (2)) END + ',';
            SET @PLANO += ' "codSexoBiologico":"' + COALESCE (@codSexoBiologico, '') + '",';
            SET @PLANO += ' "peso":' + COALESCE (@peso, '0') + ',';
            SET @PLANO += ' "codDiagnosticoPrincipal":"' + COALESCE (@codDiagnosticoPrincipal, 'null') + '",';
            SET @PLANO += ' "condicionDestinoUsuarioEgreso":"' + COALESCE (@condicionDestinoUsuarioEgreso, '01') + '",';
            SET @PLANO += ' "codDiagnosticoCausaMuerte":'
                + CASE
                    WHEN COALESCE(NULLIF(@codDiagnosticoCausaMuerte, 'null'), '') = '' THEN 'null'
                    ELSE '"' + REPLACE(@codDiagnosticoCausaMuerte, '"', '\"') + '"'
                  END + ',';
            SET @PLANO += ' "fechaEgreso":"' + COALESCE (@fechaEgreso, '') + '",';
            SET @PLANO += ' "codDiagnosticoPrincipalCIE11": null,';
            SET @PLANO += ' "nomCodDiagnosticoPrincipalCIE11": null,';
            SET @PLANO += ' "codDiagnosticoCausaMuerteCIE11": null,';
            SET @PLANO += ' "nomCodDiagnosticoCausaMuerteCIE11": null,';
            SET @PLANO += ' "codigoVIDA": null,';
            SET @PLANO += ' "consecutivo":' + COALESCE (CAST (@consecutivo AS VARCHAR (4)), '1') + '';
            SET @PLANO += '}';
        END
        ELSE
        BEGIN
            SELECT @PLANO = '';
        END
    END
    ELSE
    BEGIN
        SELECT @PLANO = '';
    END
    RETURN @PLANO;
END

