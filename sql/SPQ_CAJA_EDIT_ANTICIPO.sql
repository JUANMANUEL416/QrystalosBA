CREATE OR ALTER PROCEDURE DBO.SPQ_CAJA_EDIT_ANTICIPO
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
SET NOCOUNT ON;
SET DATEFORMAT dmy;

DECLARE @TBLERRORES TABLE (ERROR VARCHAR(MAX));
DECLARE
    @PARAMETROS NVARCHAR(MAX),
    @MODELO VARCHAR(100),
    @METODO VARCHAR(100),
    @USUARIO VARCHAR(12),
    @CODCAJA VARCHAR(20),
    @CNSFACJ VARCHAR(20),
    @FECHA VARCHAR(10),
    @HORA VARCHAR(12),
    @FECHAI VARCHAR(8),
    @FECHA_AUT DATETIME,
    @FECHA_DIA DATE,
    @FECHA_ACT DATE,
    @TIPOANTICIPO VARCHAR(20),
    @TIPOANTICIPO_ACT VARCHAR(20),
    @OBSERVACION VARCHAR(200),
    @ESTADO VARCHAR(20),
    @CERRADA SMALLINT,
    @TIPOEGRESO VARCHAR(20),
    @CNSFCXP VARCHAR(20),
    @CNSFCOM VARCHAR(20),
    @CNSFCXPP VARCHAR(20),
    @CNSFCXPPM VARCHAR(20),
    @PROCEDENCIA VARCHAR(20),
    @CONTABILIZADA SMALLINT,
    @ESTADO_FCXP VARCHAR(20),
    @DESCANT VARCHAR(512),
    @CUECREDITO VARCHAR(20),
    @CUEDEBITO VARCHAR(20),
    @COMPROBANTE VARCHAR(20),
    @ES_ANTICIPO BIT,
    @PUEDE_EDITAR_TIPO BIT,
    @MOTIVO_NO_TIPO VARCHAR(200),
    @SQL NVARCHAR(MAX);

DECLARE @DOC TABLE (
    CNSFCXP VARCHAR(20),
    CNSFCOM VARCHAR(20),
    CNSFCXPP VARCHAR(20),
    CNSFCXPPM VARCHAR(20),
    PROCEDENCIA VARCHAR(20),
    CONTABILIZADA SMALLINT,
    ESTADO_FCXP VARCHAR(20),
    TIPOANTICIPO VARCHAR(20),
    DESCANT VARCHAR(512),
    CUECREDITO VARCHAR(20)
);

BEGIN
    SELECT *
    INTO #JSON
    FROM OPENJSON(@JSON)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        USUARIO VARCHAR(12) '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    SELECT
        @MODELO = MODELO,
        @METODO = METODO,
        @PARAMETROS = PARAMETROS,
        @USUARIO = USUARIO
    FROM #JSON;

    IF COALESCE(@PARAMETROS, '') = ''
    BEGIN
        SET @PARAMETROS = N'{}';
    END

    SELECT
        @CODCAJA = CODCAJA,
        @CNSFACJ = CNSFACJ,
        @FECHA = FECHA,
        @HORA = HORA,
        @TIPOANTICIPO = TIPOANTICIPO,
        @OBSERVACION = OBSERVACION
    FROM OPENJSON(@PARAMETROS)
    WITH (
        CODCAJA VARCHAR(20) '$.CODCAJA',
        CNSFACJ VARCHAR(20) '$.CNSFACJ',
        FECHA VARCHAR(10) '$.FECHA',
        HORA VARCHAR(12) '$.HORA',
        TIPOANTICIPO VARCHAR(20) '$.TIPOANTICIPO',
        OBSERVACION VARCHAR(200) '$.OBSERVACION'
    );

    SET @CODCAJA = LTRIM(RTRIM(COALESCE(@CODCAJA, '')));
    SET @CNSFACJ = LTRIM(RTRIM(COALESCE(@CNSFACJ, '')));
    SET @TIPOANTICIPO = LTRIM(RTRIM(COALESCE(@TIPOANTICIPO, '')));

    IF @CODCAJA = '' OR @CNSFACJ = ''
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'Debe indicar caja y consecutivo del recibo.';
        SELECT 'KO' OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END

    INSERT INTO @DOC (
        CNSFCXP, CNSFCOM, CNSFCXPP, CNSFCXPPM, PROCEDENCIA,
        CONTABILIZADA, ESTADO_FCXP, TIPOANTICIPO, DESCANT, CUECREDITO
    )
    SELECT TOP 1
        FCXP.CNSFCXP,
        FCXP.CNSFCOM,
        FCXPP.CNSFCXPP,
        FCXPP.CNSFCXPPM,
        FCXP.PROCEDENCIA,
        COALESCE(FCXP.CONTABILIZADA, 0),
        FCXP.ESTADO,
        FCOM.TIPOANTICIPO,
        TANT.DESCRIPCION,
        FCXP.CUECREDITO
    FROM FCXPP
    INNER JOIN FCXP ON FCXP.CNSFCXP = FCXPP.CNSFCXP
    LEFT JOIN FCOM ON FCOM.CNSFCOM = FCXP.CNSFCOM
    LEFT JOIN TANT ON TANT.TIPOANTICIPO = FCOM.TIPOANTICIPO
    WHERE FCXPP.CODCAJA = @CODCAJA
      AND FCXPP.CNSFACJ = @CNSFACJ
      AND COALESCE(FCXPP.ESTADO, '') <> 'A'
    ORDER BY FCXPP.CNSFCXPP DESC;

    IF NOT EXISTS (SELECT 1 FROM @DOC)
    BEGIN
        INSERT INTO @DOC (
            CNSFCXP, CNSFCOM, CNSFCXPP, CNSFCXPPM, PROCEDENCIA,
            CONTABILIZADA, ESTADO_FCXP, TIPOANTICIPO, DESCANT, CUECREDITO
        )
        SELECT TOP 1
            FCXP.CNSFCXP,
            FCXP.CNSFCOM,
            FCXPP.CNSFCXPP,
            FCXPP.CNSFCXPPM,
            FCXP.PROCEDENCIA,
            COALESCE(FCXP.CONTABILIZADA, 0),
            FCXP.ESTADO,
            FCOM.TIPOANTICIPO,
            TANT.DESCRIPCION,
            FCXP.CUECREDITO
        FROM FCJD
        INNER JOIN FCXPP ON FCXPP.CNSFCXPP = FCJD.IDSERVICIO
        INNER JOIN FCXP ON FCXP.CNSFCXP = FCXPP.CNSFCXP
        LEFT JOIN FCOM ON FCOM.CNSFCOM = FCXP.CNSFCOM
        LEFT JOIN TANT ON TANT.TIPOANTICIPO = FCOM.TIPOANTICIPO
        WHERE FCJD.CODCAJA = @CODCAJA
          AND FCJD.CNSFACJ = @CNSFACJ
          AND COALESCE(FCXPP.ESTADO, '') <> 'A'
        ORDER BY FCJD.ITEM ASC, FCXPP.CNSFCXPP DESC;
    END

    SELECT TOP 1
        @CNSFCXP = CNSFCXP,
        @CNSFCOM = CNSFCOM,
        @CNSFCXPP = CNSFCXPP,
        @CNSFCXPPM = CNSFCXPPM,
        @PROCEDENCIA = PROCEDENCIA,
        @CONTABILIZADA = CONTABILIZADA,
        @ESTADO_FCXP = ESTADO_FCXP,
        @TIPOANTICIPO_ACT = TIPOANTICIPO,
        @DESCANT = DESCANT,
        @CUECREDITO = CUECREDITO
    FROM @DOC
    ORDER BY CNSFCXPP DESC;

    SET @ES_ANTICIPO = CASE
        WHEN UPPER(LTRIM(RTRIM(COALESCE(@PROCEDENCIA, '')))) IN ('ANTICIPOS', 'ANTICIPO')
        THEN 1
        ELSE 0
    END;

    SET @PUEDE_EDITAR_TIPO = 0;
    SET @MOTIVO_NO_TIPO = NULL;

    IF @ES_ANTICIPO = 1
    BEGIN
        IF COALESCE(@ESTADO_FCXP, '') = 'A'
        BEGIN
            SET @MOTIVO_NO_TIPO = N'La CXP del anticipo est� anulada.';
        END
        ELSE IF COALESCE(@CONTABILIZADA, 0) = 1
        BEGIN
            SET @MOTIVO_NO_TIPO = N'La CXP ya est� contabilizada. No se puede cambiar el tipo de anticipo.';
        END
        ELSE IF EXISTS (
            SELECT 1
            FROM ANT
            WHERE ANT.CNSFCXP = @CNSFCXP
              AND ANT.ESTADO = 'L'
        )
        BEGIN
            SET @MOTIVO_NO_TIPO = N'El anticipo ya est� legalizado. No se puede cambiar el tipo.';
        END
        ELSE IF COALESCE(@CNSFCOM, '') = ''
        BEGIN
            SET @MOTIVO_NO_TIPO = N'No se encontr� la orden FCOM asociada al anticipo.';
        END
        ELSE
        BEGIN
            SET @PUEDE_EDITAR_TIPO = 1;
        END
    END

    IF @METODO = 'TRAER_ANTICIPO_CAJA'
    BEGIN
        SELECT
            'OK' OK,
            @ES_ANTICIPO AS ES_ANTICIPO,
            @PUEDE_EDITAR_TIPO AS PUEDE_EDITAR_TIPO,
            @MOTIVO_NO_TIPO AS MOTIVO_NO_TIPO,
            @CNSFCXP AS CNSFCXP,
            @CNSFCOM AS CNSFCOM,
            @CNSFCXPP AS CNSFCXPP,
            @CNSFCXPPM AS CNSFCXPPM,
            @PROCEDENCIA AS PROCEDENCIA,
            @CONTABILIZADA AS CONTABILIZADA,
            @ESTADO_FCXP AS ESTADO_FCXP,
            @TIPOANTICIPO_ACT AS TIPOANTICIPO,
            @DESCANT AS DESCANT,
            @CUECREDITO AS CUECREDITO;

        SELECT
            TANT.TIPOANTICIPO AS [value],
            TANT.DESCRIPCION AS [label]
        FROM TANT
        ORDER BY TANT.DESCRIPCION, TANT.TIPOANTICIPO;

        RETURN;
    END

    IF @METODO <> 'EDIT_ANTICIPO_DESDE_CAJA'
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'M�todo no soportado.';
        SELECT 'KO' OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END

    IF @ES_ANTICIPO = 0
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'El recibo no corresponde a un anticipo. No se actualizan CXP ni FCOM.';
        SELECT 'KO' OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END

    IF UPPER(LTRIM(RTRIM(COALESCE(DBO.FNK_VALORVARIABLE('IDCJTECXP_EDITAR'), '')))) <> 'SI'
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'Egreso CXP: no se permite modificar fecha ni tipo de anticipo. Active la variable IDCJTECXP_EDITAR (DATO = SI).';
    END

    SELECT
        @ESTADO = FCJ.ESTADO,
        @CERRADA = COALESCE(FCJ.CERRADA, 0),
        @TIPOEGRESO = FCJ.TIPOEGRESO,
        @OBSERVACION = COALESCE(@OBSERVACION, FCJ.OBSERVACION),
        @FECHA_ACT = CONVERT(DATE, FCJ.FECHA)
    FROM FCJ
    WHERE FCJ.CODCAJA = @CODCAJA
      AND FCJ.CNSFACJ = @CNSFACJ;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'No se encontr� el recibo de caja.';
    END

    IF COALESCE(@ESTADO, '') = 'A'
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'El egreso est� anulado; no se puede modificar.';
    END

    IF COALESCE(@CERRADA, 0) = 1
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'El egreso est� confirmado; no se puede modificar fecha ni tipo de anticipo.';
    END

    IF COALESCE(@ESTADO_FCXP, '') = 'A'
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'La CXP del anticipo est� anulada; no se puede modificar.';
    END

    SET @FECHAI = REPLACE(LTRIM(RTRIM(COALESCE(@FECHA, ''))), '-', '');
    IF @FECHAI = '' OR LEN(@FECHAI) <> 8
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'Debe indicar una fecha v�lida.';
    END
    ELSE
    BEGIN
        SET @FECHA_AUT = CONVERT(
            DATETIME,
            CONCAT(@FECHAI, ' ', COALESCE(NULLIF(LTRIM(RTRIM(@HORA)), ''), '00:00'))
        );
        SET @FECHA_DIA = CONVERT(DATE, @FECHA_AUT);
    END

    IF @FECHA_DIA IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM PRI
            WHERE PRI.FECHA_INI <= @FECHA_DIA
              AND PRI.FECHA_FIN >= @FECHA_DIA
              AND COALESCE(PRI.CERRADO, 0) = 0
              AND COALESCE(PRI.CERRADO_CXP, 0) = 0
       )
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'El periodo contable de la fecha del documento no existe, est� cerrado en contabilidad o el periodo de Cuentas por Pagar est� cerrado; no se puede continuar.';
    END

    IF @FECHA_ACT IS NOT NULL
       AND (@FECHA_DIA IS NULL OR @FECHA_ACT <> @FECHA_DIA)
       AND NOT EXISTS (
            SELECT 1
            FROM PRI
            WHERE PRI.FECHA_INI <= @FECHA_ACT
              AND PRI.FECHA_FIN >= @FECHA_ACT
              AND COALESCE(PRI.CERRADO, 0) = 0
              AND COALESCE(PRI.CERRADO_CXP, 0) = 0
       )
    BEGIN
        INSERT INTO @TBLERRORES(ERROR)
        SELECT N'El periodo contable de la fecha actual del documento no existe, est� cerrado en contabilidad o el periodo de Cuentas por Pagar est� cerrado; no se puede continuar.';
    END

    IF @TIPOANTICIPO <> '' AND @TIPOANTICIPO <> COALESCE(@TIPOANTICIPO_ACT, '')
    BEGIN
        IF @PUEDE_EDITAR_TIPO = 0
        BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT COALESCE(@MOTIVO_NO_TIPO, N'No se puede cambiar el tipo de anticipo.');
        END
        ELSE IF NOT EXISTS (
            SELECT 1
            FROM TANT
            WHERE TANT.TIPOANTICIPO = @TIPOANTICIPO
        )
        BEGIN
            INSERT INTO @TBLERRORES(ERROR)
            SELECT N'El tipo de anticipo no existe en TANT.';
        END
    END

    IF EXISTS (SELECT 1 FROM @TBLERRORES)
    BEGIN
        SELECT 'KO' OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END

    BEGIN TRY
        UPDATE FCJ
        SET FECHA = @FECHA_AUT,
            OBSERVACION = @OBSERVACION
        WHERE CODCAJA = @CODCAJA
          AND CNSFACJ = @CNSFACJ;

        UPDATE FCXP
        SET FECHA = @FECHA_AUT,
            F_FACTURAREF = @FECHA_DIA
        WHERE CNSFCXP = @CNSFCXP;

        IF COL_LENGTH('dbo.FCXPP', 'FECHA') IS NOT NULL
        BEGIN
            UPDATE FCXPP
            SET FECHA = @FECHA_AUT
            WHERE CODCAJA = @CODCAJA
              AND CNSFACJ = @CNSFACJ
              AND COALESCE(ESTADO, '') <> 'A';
        END

        IF COL_LENGTH('dbo.FCXPP', 'FECHAPPAGO') IS NOT NULL
           AND COALESCE(@CNSFCXPP, '') <> ''
        BEGIN
            SET @SQL = N'
                UPDATE FCXPP
                SET FECHAPPAGO = @FECHA_AUT
                WHERE CNSFCXPP = @CNSFCXPP
                  AND COALESCE(ESTADO, '''') <> ''A''';
            EXEC SP_EXECUTESQL
                @SQL,
                N'@FECHA_AUT DATETIME, @CNSFCXPP VARCHAR(20)',
                @FECHA_AUT = @FECHA_AUT,
                @CNSFCXPP = @CNSFCXPP;
        END

        IF COALESCE(@CNSFCOM, '') <> ''
        BEGIN
            UPDATE FCOM
            SET FECHA = @FECHA_DIA
            WHERE CNSFCOM = @CNSFCOM
              AND COALESCE(ESTADO, '') <> 'A';

            IF COL_LENGTH('dbo.FCOM', 'F_FACTURA') IS NOT NULL
            BEGIN
                SET @SQL = N'
                    UPDATE FCOM
                    SET F_FACTURA = @FECHA_DIA
                    WHERE CNSFCOM = @CNSFCOM
                      AND COALESCE(ESTADO, '''') <> ''A''';
                EXEC SP_EXECUTESQL
                    @SQL,
                    N'@FECHA_DIA DATE, @CNSFCOM VARCHAR(20)',
                    @FECHA_DIA = @FECHA_DIA,
                    @CNSFCOM = @CNSFCOM;
            END
        END

        IF @TIPOANTICIPO <> ''
           AND @TIPOANTICIPO <> COALESCE(@TIPOANTICIPO_ACT, '')
           AND @PUEDE_EDITAR_TIPO = 1
        BEGIN
            SELECT
                @CUECREDITO = TANT.CUECREDITO,
                @CUEDEBITO = TANT.CUEDEBITO,
                @COMPROBANTE = TANT.COMPROBANTE
            FROM TANT
            WHERE TANT.TIPOANTICIPO = @TIPOANTICIPO;

            UPDATE FCOM
            SET TIPOANTICIPO = @TIPOANTICIPO
            WHERE CNSFCOM = @CNSFCOM;

            UPDATE FCXP
            SET CUECREDITO = @CUECREDITO
            WHERE CNSFCXP = @CNSFCXP
              AND COALESCE(CONTABILIZADA, 0) = 0;

            IF COL_LENGTH('dbo.FCXP', 'CUEDEBITO') IS NOT NULL
               AND COALESCE(@CUEDEBITO, '') <> ''
            BEGIN
                SET @SQL = N'
                    UPDATE FCXP
                    SET CUEDEBITO = @CUEDEBITO
                    WHERE CNSFCXP = @CNSFCXP
                      AND COALESCE(CONTABILIZADA, 0) = 0';
                EXEC SP_EXECUTESQL
                    @SQL,
                    N'@CUEDEBITO VARCHAR(20), @CNSFCXP VARCHAR(20)',
                    @CUEDEBITO = @CUEDEBITO,
                    @CNSFCXP = @CNSFCXP;
            END

            IF COL_LENGTH('dbo.FCXP', 'COMPROBANTE') IS NOT NULL
               AND COALESCE(@COMPROBANTE, '') <> ''
            BEGIN
                SET @SQL = N'
                    UPDATE FCXP
                    SET COMPROBANTE = @COMPROBANTE
                    WHERE CNSFCXP = @CNSFCXP
                      AND COALESCE(CONTABILIZADA, 0) = 0';
                EXEC SP_EXECUTESQL
                    @SQL,
                    N'@COMPROBANTE VARCHAR(20), @CNSFCXP VARCHAR(20)',
                    @COMPROBANTE = @COMPROBANTE,
                    @CNSFCXP = @CNSFCXP;
            END
        END

        SELECT
            'OK' OK,
            @CNSFCXP AS CNSFCXP,
            @CNSFCOM AS CNSFCOM,
            @CNSFCXPP AS CNSFCXPP,
            COALESCE(@TIPOANTICIPO, @TIPOANTICIPO_ACT) AS TIPOANTICIPO;
    END TRY
    BEGIN CATCH
        INSERT INTO @TBLERRORES(ERROR)
        SELECT ERROR_MESSAGE();
        SELECT 'KO' OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END CATCH
END
