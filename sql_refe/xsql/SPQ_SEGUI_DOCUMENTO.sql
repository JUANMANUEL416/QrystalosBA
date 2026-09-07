CREATE OR ALTER PROCEDURE DBO.SPQ_SEGUI_DOCUMENTO
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @MODELO      VARCHAR(100),
        @METODO      VARCHAR(100),
        @PARAMETROS  NVARCHAR(MAX),

        @CNSRPDX     VARCHAR(20),
        @TIPO        VARCHAR(10),
        @N_FACTURA   VARCHAR(16),
        @IDTERCERO   VARCHAR(20),
        @CNS         VARCHAR(20);

    DECLARE @TBLERRORES TABLE (ERROR NVARCHAR(500));

    BEGIN TRY
        SELECT
            @MODELO     = MODELO,
            @METODO     = METODO,
            @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON)
        WITH (
            MODELO      VARCHAR(100) '$.MODELO',
            METODO      VARCHAR(100) '$.METODO',
            PARAMETROS  NVARCHAR(MAX) AS JSON
        );
    END TRY
    BEGIN CATCH
        INSERT INTO @TBLERRORES(ERROR)
        VALUES ('Error al parsear JSON: ' + ERROR_MESSAGE());

        SELECT 'KO' AS OK;
        SELECT ERROR FROM @TBLERRORES;
        RETURN;
    END CATCH;

    IF @METODO = 'GET_DETALLE_CUENTAS'
    BEGIN
        BEGIN TRY
            SELECT
                @CNS       = CNS,
                @N_FACTURA = N_FACTURA,
                @TIPO      = TIPO
            FROM OPENJSON(@PARAMETROS)
            WITH (
                CNS         VARCHAR(20) '$.CNS',
                N_FACTURA   VARCHAR(16) '$.N_FACTURA',
                TIPO        VARCHAR(10) '$.TIPO'
            );

            IF ISNULL(@CNS,'') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('CNS es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
            END

            IF ISNULL(@N_FACTURA,'') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('N_FACTURA es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
            END

            IF NOT EXISTS (
                SELECT 1
                FROM MCP A
                INNER JOIN MCH B ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                INNER JOIN RPDX C ON C.ID1 = A.NROCOMPROBANTE
                WHERE C.CNS = @CNS
                  AND B.N_FACTURA = @N_FACTURA
            )
            BEGIN
                SELECT
                    CAST(NULL AS VARCHAR(20))  AS CUENTA,
                    CAST(NULL AS VARCHAR(100)) AS NOMCUENTA,
                    CAST(NULL AS DECIMAL(18,2)) AS DEBITO,
                    CAST(NULL AS DECIMAL(18,2)) AS CREDITO,
                    CAST(NULL AS DECIMAL(18,2)) AS SALDO
                WHERE 1=0;
                RETURN;
            END

            SELECT 
                B.CUENTA,
                D.NOMCUENTA,
                SUM(CASE WHEN B.TIPO='DB' THEN B.VALOR ELSE 0 END) AS DEBITO,
                SUM(CASE WHEN B.TIPO='CR' THEN B.VALOR ELSE 0 END) AS CREDITO,
                SUM(CASE WHEN B.TIPO='DB' THEN B.VALOR ELSE 0 END)
                - SUM(CASE WHEN B.TIPO='CR' THEN B.VALOR ELSE 0 END) AS SALDO
            FROM MCP A
            INNER JOIN MCH B ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
            INNER JOIN CUE D ON D.CUENTA = B.CUENTA
            INNER JOIN RPDX C ON C.ID1 = A.NROCOMPROBANTE
            WHERE C.CNS = @CNS
              AND B.N_FACTURA = @N_FACTURA
              --AND D.CLASE IN ('CXC','CXP') --STORRES Y NVOOS 20260819 SE QUITA WHERE PARA QUE MUETSRE LA TRAZA COMPLETA DE LAS CUENTAS AFECTADAS POR LA FACTURA DEL SEGIMIENTO
            GROUP BY B.CUENTA, D.NOMCUENTA;

            RETURN;
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES VALUES ('Error detalle cuentas: ' + ERROR_MESSAGE());
            SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
        END CATCH
    END

    IF @METODO = 'CONSULTAR_TRAZA_DOC_RPT'
    BEGIN
        BEGIN TRY
            SELECT
                @CNSRPDX   = CNSRPDX,
                @TIPO      = TIPO,
                @N_FACTURA = N_FACTURA,
                @IDTERCERO = ISNULL(IDTERCERO,'')
            FROM OPENJSON(@PARAMETROS)
            WITH (
                CNSRPDX    VARCHAR(20) '$.CNSRPDX',
                TIPO       VARCHAR(10) '$.TIPO',
                N_FACTURA  VARCHAR(16) '$.N_FACTURA',
                IDTERCERO  VARCHAR(20) '$.IDTERCERO'
            );

            IF ISNULL(@CNSRPDX,'') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('CNSRPDX es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
            END

            IF ISNULL(@TIPO,'') = ''
            BEGIN
                INSERT INTO @TBLERRORES VALUES ('TIPO es requerido');
                SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
            END

            DELETE FROM RPDX WHERE CNS = @CNSRPDX;

            EXEC NC_SPK_SEGUI_DOCUMENTO
                @CNSRPDX   = @CNSRPDX,
                @TIPO      = @TIPO,
                @N_FACTURA = @N_FACTURA,
                @IDTERCERO = @IDTERCERO;

            IF NOT EXISTS (SELECT 1 FROM RPDX WHERE CNS = @CNSRPDX)
            /*
            BEGIN
                SELECT
                    CAST(NULL AS VARCHAR(20)) AS NROCOMPROBANTE,
                    CAST(NULL AS INT) AS ANO,
                    CAST(NULL AS INT) AS MES,
                    CAST(NULL AS DATETIME) AS FECHACONTABLE,
                    CAST(NULL AS DECIMAL(18,2)) AS VALOR,
                    CAST(NULL AS VARCHAR(50)) AS PROCEDENCIA,
                    CAST(NULL AS VARCHAR(20)) AS ESTADO
                WHERE 1=0;
                RETURN;
            END
            */

            SELECT
                R.ID1    AS NROCOMPROBANTE,
                R.ID2    AS ANO,
                R.ID3    AS MES,
                R.FECHA1 AS FECHACONTABLE,
                R.VALOR1 AS VALOR,
                R.ID6    AS PROCEDENCIA,
                R.ID4    AS ESTADO,
                @N_FACTURA AS N_FACTURA_PARAM
            FROM RPDX R
            WHERE R.CNS = @CNSRPDX
            ORDER BY R.FECHA1, R.ID1;
            

            IF ISNULL(@N_FACTURA,'') <> ''
            BEGIN
                IF EXISTS (SELECT 1 FROM FTR WHERE N_FACTURA = @N_FACTURA)
                    SELECT TOP 1 * FROM FTR WHERE N_FACTURA = @N_FACTURA;
                ELSE
                    SELECT TOP 0 * FROM FTR;
            END
            ELSE
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM RPDX R
                    INNER JOIN MCH MH ON MH.NROCOMPROBANTE = R.ID1
                    INNER JOIN FTR F ON F.N_FACTURA = MH.N_FACTURA
                    WHERE R.CNS = @CNSRPDX
                )
                    SELECT TOP 1 F.*
                    FROM RPDX R
                    INNER JOIN MCH MH ON MH.NROCOMPROBANTE = R.ID1
                    INNER JOIN FTR F ON F.N_FACTURA = MH.N_FACTURA
                    WHERE R.CNS = @CNSRPDX
                    ORDER BY R.FECHA1 DESC;
                ELSE
                    SELECT TOP 0 * FROM FTR;
            END

            RETURN;
        END TRY
        BEGIN CATCH
            INSERT INTO @TBLERRORES VALUES (ERROR_MESSAGE());
            SELECT 'KO' AS OK; SELECT ERROR FROM @TBLERRORES; RETURN;
        END CATCH
    END


    INSERT INTO @TBLERRORES(ERROR)
    VALUES ('M?todo no reconocido: ' + ISNULL(@METODO,'NULL'));

    SELECT 'KO' AS OK;
    SELECT ERROR FROM @TBLERRORES;
END;

