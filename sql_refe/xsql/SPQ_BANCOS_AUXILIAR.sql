CREATE OR ALTER PROCEDURE DBO.SPQ_BANCOS_AUXILIAR
    @JSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET DEADLOCK_PRIORITY HIGH;
    SET LANGUAGE SPANISH;
    SET DATEFORMAT DMY
   
    DECLARE
        @PARAMETROS         NVARCHAR(MAX),
        @MODELO             VARCHAR(100),
        @METODO             VARCHAR(100),
        @USUARIO            VARCHAR(12),
        @COMPANIA           VARCHAR(2),
        @IDSEDE             VARCHAR(2),
        @SYS_COMPUTE        VARCHAR(255),

        @CNS                VARCHAR(20),
        @FECHA_INICIAL      DATE,
        @FECHA_FINAL        DATE,
        @FECHA_FINAL_PLUS   DATE,
        @IDTERCERO          VARCHAR(20),
        @MOVIMIENTO         VARCHAR(20),
        @COMPROBANTE        VARCHAR(20),
        @REFERENCIA         VARCHAR(50),
        @CUENTA_CONTABLE    VARCHAR(20),
        @VER_CONCILIACION   VARCHAR(20),
        @VER_ESTADO         VARCHAR(20),
        @N_FACTURA          VARCHAR(50),

        @ANO                VARCHAR(4),
        @MES                VARCHAR(2),
        @MES_INT            INT,
        @TOTAL              INT,
        @RC                 INT,
        @ITEM_LIST          NVARCHAR(MAX),
        @ITEM_RPDX          INT,
        @FECHA_CONCILIACION DATE,
        @ACCION             VARCHAR(20),
        @AGRUPADO           BIT,
        @INCLUIR_NC_ANTERIORES BIT,

        /* Acumuladores del resumen (pasos 1-9 del sistema antiguo) */
        @SI_NC_DB DECIMAL(18,2), @SI_NC_CR DECIMAL(18,2),
        @SI_C_DB  DECIMAL(18,2), @SI_C_CR  DECIMAL(18,2),
        @P_NC_DB  DECIMAL(18,2), @P_NC_CR  DECIMAL(18,2),
        @P_C_DB   DECIMAL(18,2), @P_C_CR   DECIMAL(18,2),
        @LIB_SI   DECIMAL(18,2), @LIB_DB   DECIMAL(18,2),
        @LIB_CR   DECIMAL(18,2), @LIB_SF   DECIMAL(18,2),
        @SICON_SI DECIMAL(18,2);

    BEGIN TRY
        -- Validar JSON
        IF ISJSON(@JSON) <> 1
        BEGIN
            SELECT 'RESULTADO' AS TIPO_RESULTADO, 'KO' AS OK, 'JSON inválido' AS MENSAJE;
            RETURN;
        END;

        -- Extraer parámetros del JSON
        SELECT @PARAMETROS = PARAMETROS
        FROM OPENJSON(@JSON)
        WITH (PARAMETROS NVARCHAR(MAX) AS JSON);

        SELECT
            @MODELO  = JSON_VALUE(@JSON, '$.MODELO'),
            @METODO  = JSON_VALUE(@JSON, '$.METODO'),
            @USUARIO = JSON_VALUE(@JSON, '$.USUARIO');

        -- Obtener COMPANIA del usuario (con fallback)
        SELECT
            @COMPANIA    = COALESCE(COMPANIA, HOST_NAME()),
            @IDSEDE      = COALESCE(IDSEDE, '01'),
            @SYS_COMPUTE = COALESCE(SYS_COMPUTERNAME, HOST_NAME())
        FROM USUSU WITH (NOLOCK)
        WHERE USUARIO = @USUARIO;

        SET @COMPANIA = ISNULL(@COMPANIA, '01');
        SET @IDSEDE   = ISNULL(@IDSEDE,   '01');

        -- Normalizar método a mayúsculas
        SET @METODO = UPPER(TRIM(ISNULL(@METODO, '')));

        -- Extraer todos los parámetros comunes una sola vez
        SELECT
            @CNS              = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CNS')), ''),
            @FECHA_INICIAL    = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_INICIAL') AS DATE),
            @FECHA_FINAL      = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_FINAL')   AS DATE),
            @IDTERCERO        = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.IDTERCERO')), ''),
            @MOVIMIENTO       = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.MOVIMIENTO')), ''),
            @COMPROBANTE      = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.COMPROBANTE')), ''),
            @REFERENCIA       = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.REFERENCIA')), ''),
            @CUENTA_CONTABLE  = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CUENTA_CONTABLE')), ''),
            @VER_CONCILIACION = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.VER_CONCILIACION')), ''),
            @VER_ESTADO       = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.VER_ESTADO')), ''),
            @N_FACTURA        = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.N_FACTURA')), '');

        SET @AGRUPADO = CASE
            WHEN JSON_VALUE(@PARAMETROS, '$.AGRUPADO') IN ('1', 'true', 'TRUE', 'True', 'SI', 'Si') THEN 1
            WHEN TRY_CAST(JSON_VALUE(@PARAMETROS, '$.AGRUPADO') AS BIT) = 1 THEN 1
            ELSE 0
        END;

        /* Clarion=1: no conciliados con FECHACONTABLE < FECHA_FINAL (sin límite inferior).
           Web=0: no conciliados solo dentro del rango [FECHA_INICIAL, FECHA_FINAL]. */
        SET @INCLUIR_NC_ANTERIORES = CASE
            WHEN JSON_VALUE(@PARAMETROS, '$.INCLUIR_NC_ANTERIORES') IN ('0', 'false', 'FALSE', 'False', 'NO', 'No') THEN 0
            WHEN TRY_CAST(JSON_VALUE(@PARAMETROS, '$.INCLUIR_NC_ANTERIORES') AS BIT) = 0 THEN 0
            ELSE 1
        END;

        SET @FECHA_FINAL_PLUS = DATEADD(DAY, 1, @FECHA_FINAL);
        /* Libros / SAC: mes y año según FECHA_INICIAL (igual que Clarion). */
        SET @MES_INT          = MONTH(ISNULL(@FECHA_INICIAL, GETDATE()));
        SET @ANO              = CAST(YEAR(ISNULL(@FECHA_INICIAL, GETDATE())) AS VARCHAR(4));
        SET @MES              = RIGHT('0' + CAST(@MES_INT AS VARCHAR(2)), 2);

        
        IF @METODO = 'LIMPIAR'
        BEGIN
            IF @CNS IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar CNS' AS ERROR;
                RETURN;
            END

            DELETE FROM RPDX WHERE CNS = @CNS;

            SELECT 'OK' AS OK, 'RPDX limpiado' AS MENSAJE, @CNS AS CNS, @@ROWCOUNT AS REGISTROS_ELIMINADOS;
            RETURN;
        END

        IF @METODO = 'OBTENER_MOVIMIENTOS'
        BEGIN
            
            IF @CNS IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar CNS' AS ERROR;
                RETURN;
            END
            IF @CUENTA_CONTABLE IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar la CUENTA_CONTABLE' AS ERROR;
                RETURN;
            END
            IF @FECHA_INICIAL IS NULL OR @FECHA_FINAL IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar FECHA_INICIAL y FECHA_FINAL' AS ERROR;
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;

                DELETE FROM RPDX WHERE CNS = @CNS;

                IF ISNULL(@AGRUPADO, 0) = 1
                BEGIN
                    /* Modo agrupado (Clarion AGRUPADO=1): suma DB/CR, sin NROASIENTO */
                    INSERT INTO RPDX
                    (
                        CNS, ID1, ID2, ID3, STRINGMEDIO1, ID4, STRINGMEDIO2, VALOR5, VALOR6, ID7, ID8, ID9, ID10, STRINGGRANDE1,
                        ID11, ID12, ID13, ID14, ID16, ID17
                    )
                    SELECT
                        @CNS                                              AS CNS,
                        CONVERT(VARCHAR(10), B.FECHACONTABLE, 103)        AS FECHACONTABLE,
                        TRIM(B.COMPROBANTE) + ' ' + ISNULL(TRIM(B.NOREFERENCIA), '') AS COMPROBANTE,
                        A.CUENTA                                          AS CUENTA,
                        LEFT(CUE.NOMCUENTA, 100)                          AS NOMCUENTA,
                        A.IDTERCERO                                       AS IDTERCERO,
                        LEFT(TER.RAZONSOCIAL, 100)                        AS RAZONSOCIAL,
                        SUM(CASE WHEN A.TIPO = 'DB' THEN A.VALOR ELSE 0 END) AS DEBITOS,
                        SUM(CASE WHEN A.TIPO = 'CR' THEN A.VALOR ELSE 0 END) AS CREDITOS,
                        A.N_FACTURA                                       AS N_FACTURA,
                        CONVERT(VARCHAR(10), A.F_FACTURAREF, 103)         AS F_FACTURA,
                        CONVERT(VARCHAR(10), A.F_VENCE, 103)              AS F_VENCE,
                        B.NOCHEQUE                                        AS NOCHEQUE,
                        A.DETALLE                                         AS DETALLE,
                        A.CONCILIADO                                      AS CONCILIADO,
                        A.NROCOMPROBANTE                                  AS NROCOMPROBANTE,
                        NULL                                              AS NROASIENTO,
                        A.ESTADO                                          AS ESTADO,
                        CONVERT(VARCHAR(10), A.FECHACONCILIACION, 103)    AS FECHACONCILIACION,
                        0                                                 AS ID17
                    FROM   MCH AS A
                    INNER JOIN MCP AS B ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                    INNER JOIN CUE      ON A.CUENTA         = CUE.CUENTA  AND CUE.COMPANIA = @COMPANIA
                    LEFT  JOIN TER      ON A.IDTERCERO      = TER.IDTERCERO
                    WHERE  ISNULL(B.ANULADO, 0) = 0
                      AND  A.CUENTA = @CUENTA_CONTABLE
                      AND  (
                               (A.FECHACONCILIACION >= @FECHA_INICIAL AND A.FECHACONCILIACION < @FECHA_FINAL_PLUS AND COALESCE(A.CONCILIADO, 0) = 1)
                            OR (
                                   COALESCE(A.CONCILIADO, 0) = 0
                               AND B.FECHACONTABLE < @FECHA_FINAL_PLUS
                               AND (@INCLUIR_NC_ANTERIORES = 1 OR B.FECHACONTABLE >= @FECHA_INICIAL)
                               )
                           )
                      AND  (@COMPROBANTE IS NULL OR B.COMPROBANTE = @COMPROBANTE)
                      AND  (@REFERENCIA  IS NULL OR B.NOREFERENCIA = @REFERENCIA)
                      AND  (
                               A.IDTERCERO IN (CASE WHEN @IDTERCERO IS NULL THEN A.IDTERCERO ELSE @IDTERCERO END)
                            OR (@IDTERCERO IS NULL AND A.IDTERCERO IS NULL)
                           )
                      AND  (
                               A.N_FACTURA IN (CASE WHEN @N_FACTURA IS NULL THEN A.N_FACTURA ELSE @N_FACTURA END)
                            OR (@N_FACTURA IS NULL AND A.N_FACTURA IS NULL)
                           )
                      AND  (
                               @MOVIMIENTO IS NULL
                            OR @MOVIMIENTO IN ('Todos', 'TO')
                            OR (@MOVIMIENTO IN ('DB', 'Debitos',  'Débitos')  AND A.TIPO = 'DB')
                            OR (@MOVIMIENTO IN ('CR', 'Creditos', 'Créditos') AND A.TIPO = 'CR')
                           )
                      AND  (
                               A.ESTADO IN (
                                   CASE
                                       WHEN @VER_ESTADO IS NULL OR @VER_ESTADO IN ('Todos', '9') THEN A.ESTADO
                                       WHEN @VER_ESTADO IN ('Contabilizados', '2') THEN '2'
                                       WHEN @VER_ESTADO IN ('Preparados', '1') THEN '1'
                                       WHEN @VER_ESTADO IN ('Incompletos', '0') THEN '0'
                                       ELSE A.ESTADO
                                   END
                               )
                            OR (
                                   (@VER_ESTADO IS NULL OR @VER_ESTADO IN ('Todos', '9') OR @VER_ESTADO IN ('Incompletos', '0'))
                               AND A.ESTADO IS NULL
                               )
                           )
                      AND  (
                               A.CONCILIADO IN (
                                   CASE
                                       WHEN @VER_CONCILIACION IS NULL OR @VER_CONCILIACION = 'Ambos' THEN A.CONCILIADO
                                       WHEN @VER_CONCILIACION = 'Conciliados' THEN 1
                                       WHEN @VER_CONCILIACION = 'NoConciliados' THEN 0
                                       ELSE A.CONCILIADO
                                   END
                               )
                            OR (
                                   (@VER_CONCILIACION IS NULL OR @VER_CONCILIACION = 'Ambos' OR @VER_CONCILIACION = 'NoConciliados')
                               AND A.CONCILIADO IS NULL
                               )
                           )
                    GROUP BY
                        B.FECHACONTABLE,
                        B.COMPROBANTE,
                        B.NOREFERENCIA,
                        A.CUENTA,
                        LEFT(CUE.NOMCUENTA, 100),
                        A.IDTERCERO,
                        LEFT(TER.RAZONSOCIAL, 100),
                        A.N_FACTURA,
                        A.F_FACTURAREF,
                        A.F_VENCE,
                        B.NOCHEQUE,
                        A.DETALLE,
                        A.CONCILIADO,
                        A.NROCOMPROBANTE,
                        A.ESTADO,
                        A.FECHACONCILIACION
                    ORDER BY A.CUENTA, B.FECHACONTABLE, B.NOCHEQUE;
                END
                ELSE
                BEGIN
                    /* Modo detalle (Clarion AGRUPADO=0): una fila por línea MCH */
                    INSERT INTO RPDX
                    (
                        CNS, ID1, ID2, ID3, STRINGMEDIO1, ID4, STRINGMEDIO2,VALOR5, VALOR6, ID7, ID8, ID9, ID10, STRINGGRANDE1,
                        ID11, ID12, ID13, ID14, ID16, ID17
                    )
                    SELECT
                        @CNS                                              AS CNS,
                        CONVERT(VARCHAR(10), B.FECHACONTABLE, 103)        AS FECHACONTABLE,    -- ID1
                        TRIM(B.COMPROBANTE) + ' '+ ISNULL(TRIM(B.NOREFERENCIA), '')   AS COMPROBANTE,      -- ID2
                        A.CUENTA                                          AS CUENTA,           -- ID3
                        LEFT(CUE.NOMCUENTA, 100)                          AS NOMCUENTA,        -- STRINGMEDIO1
                        A.IDTERCERO                                       AS IDTERCERO,        -- ID4
                        LEFT(TER.RAZONSOCIAL, 100)                        AS RAZONSOCIAL,      -- STRINGMEDIO2
                        CASE WHEN A.TIPO = 'DB' THEN A.VALOR ELSE 0 END   AS DEBITOS,          -- VALOR5
                        CASE WHEN A.TIPO = 'CR' THEN A.VALOR ELSE 0 END   AS CREDITOS,         -- VALOR6
                        A.N_FACTURA                                       AS N_FACTURA,        -- ID7
                        CONVERT(VARCHAR(10), A.F_FACTURAREF, 103)         AS F_FACTURA,        -- ID8
                        CONVERT(VARCHAR(10), A.F_VENCE, 103)              AS F_VENCE,          -- ID9
                        B.NOCHEQUE                                        AS NOCHEQUE,         -- ID10
                        A.DETALLE                                         AS DETALLE,          -- STRINGGRANDE1
                        A.CONCILIADO                                      AS CONCILIADO,       -- ID11
                        A.NROCOMPROBANTE                                  AS NROCOMPROBANTE,   -- ID12
                        A.NROASIENTO                                      AS NROASIENTO,       -- ID13
                        A.ESTADO                                          AS ESTADO,           -- ID14
                        CONVERT(VARCHAR(10), A.FECHACONCILIACION, 103)    AS FECHACONCILIACION,-- ID16
                        0                                                 AS ID17              -- ID17: 1 = filas marcadas para SALVAR_CONCILIACION
                    FROM   MCH AS A --WITH (NOLOCK)
                    INNER JOIN MCP AS B ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                    INNER JOIN CUE      ON A.CUENTA         = CUE.CUENTA  AND CUE.COMPANIA = @COMPANIA
                    LEFT  JOIN TER      ON A.IDTERCERO      = TER.IDTERCERO
                    WHERE  ISNULL(B.ANULADO, 0) = 0
                      AND  A.CUENTA = @CUENTA_CONTABLE
                      /* Núcleo del auxiliar de bancos */
                      AND  (
                               (A.FECHACONCILIACION >= @FECHA_INICIAL AND A.FECHACONCILIACION < @FECHA_FINAL_PLUS AND COALESCE(A.CONCILIADO, 0) = 1)
                            OR (
                                   COALESCE(A.CONCILIADO, 0) = 0
                               AND B.FECHACONTABLE < @FECHA_FINAL_PLUS
                               AND (@INCLUIR_NC_ANTERIORES = 1 OR B.FECHACONTABLE >= @FECHA_INICIAL)
                               )
                           )
                      AND  (@COMPROBANTE IS NULL OR B.COMPROBANTE  = @COMPROBANTE)
                      AND  (@REFERENCIA  IS NULL OR B.NOREFERENCIA = @REFERENCIA)
                      /* Filtros con manejo explícito de NULL (patrón Clarion) */
                      AND  (
                               A.IDTERCERO IN (CASE WHEN @IDTERCERO IS NULL THEN A.IDTERCERO ELSE @IDTERCERO END)
                            OR (@IDTERCERO IS NULL AND A.IDTERCERO IS NULL)
                           )
                      AND  (
                               A.N_FACTURA IN (CASE WHEN @N_FACTURA IS NULL THEN A.N_FACTURA ELSE @N_FACTURA END)
                            OR (@N_FACTURA IS NULL AND A.N_FACTURA IS NULL)
                           )
                      /* Tipo de movimiento */
                      AND  (
                               @MOVIMIENTO IS NULL
                            OR @MOVIMIENTO IN ('Todos', 'TO')
                            OR (@MOVIMIENTO IN ('DB', 'Debitos',  'Débitos')  AND A.TIPO = 'DB')
                            OR (@MOVIMIENTO IN ('CR', 'Creditos', 'Créditos') AND A.TIPO = 'CR')
                           )
                      AND  (
                               A.ESTADO IN (
                                   CASE
                                       WHEN @VER_ESTADO IS NULL OR @VER_ESTADO IN ('Todos', '9') THEN A.ESTADO
                                       WHEN @VER_ESTADO IN ('Contabilizados', '2') THEN '2'
                                       WHEN @VER_ESTADO IN ('Preparados', '1') THEN '1'
                                       WHEN @VER_ESTADO IN ('Incompletos', '0') THEN '0'
                                       ELSE A.ESTADO
                                   END
                               )
                            OR (
                                   (@VER_ESTADO IS NULL OR @VER_ESTADO IN ('Todos', '9') OR @VER_ESTADO IN ('Incompletos', '0'))
                               AND A.ESTADO IS NULL
                               )
                           )
                      AND  (
                               A.CONCILIADO IN (
                                   CASE
                                       WHEN @VER_CONCILIACION IS NULL OR @VER_CONCILIACION = 'Ambos' THEN A.CONCILIADO
                                       WHEN @VER_CONCILIACION = 'Conciliados' THEN 1
                                       WHEN @VER_CONCILIACION = 'NoConciliados' THEN 0
                                       ELSE A.CONCILIADO
                                   END
                               )
                            OR (
                                   (@VER_CONCILIACION IS NULL OR @VER_CONCILIACION = 'Ambos' OR @VER_CONCILIACION = 'NoConciliados')
                               AND A.CONCILIADO IS NULL
                               )
                           )
                    ORDER BY A.CUENTA, B.FECHACONTABLE, B.NOCHEQUE;
                END




                SET @TOTAL = (SELECT COUNT(1) FROM RPDX WITH (NOLOCK) WHERE CNS = @CNS);

                COMMIT;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0 ROLLBACK;
                SELECT 'KO' AS OK,
                       CONCAT('Error al cargar movimientos: ', ERROR_MESSAGE()) AS ERROR,
                       ERROR_LINE() AS LINEA;
                RETURN;
            END CATCH

            ----------------------------------------------------------------
            -- Recordset 1 — Estado de la operación
            ----------------------------------------------------------------
            SELECT
                'OK'                  AS OK,
                'Movimientos cargados' AS MENSAJE,
                @CNS                  AS CNS,
                @TOTAL                AS TOTAL_INSERTADOS,
                @AGRUPADO             AS AGRUPADO;

            ----------------------------------------------------------------
            -- Recordset 2 — Resumen (pasos 1..9 del sistema antiguo)
            ----------------------------------------------------------------
            SET @SI_NC_DB = 0; SET @SI_NC_CR = 0;
            SET @SI_C_DB  = 0; SET @SI_C_CR  = 0;
            SET @P_NC_DB  = 0; SET @P_NC_CR  = 0;
            SET @P_C_DB   = 0; SET @P_C_CR   = 0;
            SET @LIB_SI   = 0; SET @LIB_DB   = 0;
            SET @LIB_CR   = 0; SET @LIB_SF   = 0;
            SET @SICON_SI = 0;

            /* Saldo inicial conciliado manual en TGEN (Clarion: CONCIL_SI por cuenta). */
            SELECT @SICON_SI = ISNULL(TRY_CAST(VALOR1 AS DECIMAL(18,2)), 0)
            FROM   TGEN WITH (NOLOCK)
            WHERE  CAMPO = 'CONCIL_SI'
              AND  CODIGO = @CUENTA_CONTABLE;

            BEGIN TRY
                /* Paso 1 — Saldo inicial NO CONCILIADO (movs antes del rango) */
                SELECT
                    @SI_NC_DB = ISNULL(SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'DB' THEN A.VALOR ELSE 0 END), 0),
                    @SI_NC_CR = ISNULL(SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'CR' THEN A.VALOR ELSE 0 END), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  B.FECHACONTABLE < @FECHA_INICIAL
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  (A.CONCILIADO IS NULL OR A.CONCILIADO = 0)
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 2 — Saldo inicial CONCILIADO */
                SELECT
                    @SI_C_DB = ISNULL(SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'DB' THEN A.VALOR ELSE 0 END), 0),
                    @SI_C_CR = ISNULL(SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'CR' THEN A.VALOR ELSE 0 END), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  A.FECHACONCILIACION < @FECHA_INICIAL
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  A.CONCILIADO = 1
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 3 — Débitos del periodo NO CONCILIADO */
                SELECT @P_NC_DB = ISNULL(SUM(A.VALOR), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  B.FECHACONTABLE >= @FECHA_INICIAL
                  AND  B.FECHACONTABLE <  @FECHA_FINAL_PLUS
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  (A.CONCILIADO IS NULL OR A.CONCILIADO = 0)
                  AND  UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'DB'
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 4 — Débitos del periodo CONCILIADO */
                SELECT @P_C_DB = ISNULL(SUM(A.VALOR), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  A.FECHACONCILIACION >= @FECHA_INICIAL
                  AND  A.FECHACONCILIACION <  @FECHA_FINAL_PLUS
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  A.CONCILIADO = 1
                  AND  UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'DB'
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 5 — Créditos del periodo NO CONCILIADO */
                SELECT @P_NC_CR = ISNULL(SUM(A.VALOR), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  B.FECHACONTABLE >= @FECHA_INICIAL
                  AND  B.FECHACONTABLE <  @FECHA_FINAL_PLUS
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  (A.CONCILIADO IS NULL OR A.CONCILIADO = 0)
                  AND  UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'CR'
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 6 — Créditos del periodo CONCILIADO */
                SELECT @P_C_CR = ISNULL(SUM(A.VALOR), 0)
                FROM   MCH A WITH (NOLOCK)
                       INNER JOIN MCP B WITH (NOLOCK) ON A.NROCOMPROBANTE = B.NROCOMPROBANTE
                WHERE  B.ESTADO = 2
                  AND  A.FECHACONCILIACION >= @FECHA_INICIAL
                  AND  A.FECHACONCILIACION <  @FECHA_FINAL_PLUS
                  AND  A.CUENTA = @CUENTA_CONTABLE
                  AND  A.CONCILIADO = 1
                  AND  UPPER(LTRIM(RTRIM(ISNULL(A.TIPO, '')))) = 'CR'
                  AND  ISNULL(B.ANULADO, 0) = 0;

                /* Paso 7 — Recalcular detalles del SAC para el período (no crítico) */
                BEGIN TRY
                    EXEC DBO.SPK_SUMA_DETALLES_SAC @COMPANIA, @ANO, @MES_INT;
                END TRY
                BEGIN CATCH
                    PRINT 'AVISO: SPK_SUMA_DETALLES_SAC falló: ' + ERROR_MESSAGE();
                END CATCH

                /* Pasos 8-9 — Saldo en libros contables (FNK_INFO_CON_MENSUAL) */
                BEGIN TRY
                    SELECT
                        @LIB_SI = ISNULL(SUM(SALDOINICIAL), 0),
                        @LIB_DB = ISNULL(SUM(DEBITOS),      0),
                        @LIB_CR = ISNULL(SUM(CREDITOS),     0),
                        @LIB_SF = ISNULL(SUM(SALDOFINAL),   0)
                    FROM   DBO.FNK_INFO_CON_MENSUAL(@COMPANIA, @ANO, @MES_INT)
                    WHERE  CUENTA = @CUENTA_CONTABLE;
                END TRY
                BEGIN CATCH
                    PRINT 'AVISO: FNK_INFO_CON_MENSUAL falló: ' + ERROR_MESSAGE();
                END CATCH
            END TRY
            BEGIN CATCH
                /* Si falla algún paso del resumen, no detenemos el flujo: simplemente
                   se devolverán ceros en los campos que no se pudieron calcular. */
                PRINT 'AVISO: Error parcial en cálculo de resumen: ' + ERROR_MESSAGE();
            END CATCH

            SELECT
                'OK'                                              AS OK,

                /* Saldos iniciales */
                @SI_NC_DB                                         AS SI_NC_DEBITOS,
                @SI_NC_CR                                         AS SI_NC_CREDITOS,
                (@SI_NC_DB - @SI_NC_CR)                           AS SI_NC_NETO,
                @SI_C_DB                                          AS SI_C_DEBITOS,
                @SI_C_CR                                          AS SI_C_CREDITOS,
                @SICON_SI                                         AS SICON_SI,
                (@SICON_SI + @SI_C_DB - @SI_C_CR)                 AS SI_C_NETO,
                ((@SI_NC_DB - @SI_NC_CR) + (@SICON_SI + @SI_C_DB - @SI_C_CR)) AS SI_TOTAL,

                /* Movimientos del periodo */
                @P_NC_DB                                          AS P_NC_DEBITOS,
                @P_NC_CR                                          AS P_NC_CREDITOS,
                @P_C_DB                                           AS P_C_DEBITOS,
                @P_C_CR                                           AS P_C_CREDITOS,
                (@P_NC_DB + @P_C_DB)                              AS T_DEBITOS,
                (@P_NC_CR + @P_C_CR)                              AS T_CREDITOS,

                /* Saldos finales = saldo inicial + débitos - créditos */
                ((@SI_NC_DB - @SI_NC_CR) + @P_NC_DB - @P_NC_CR)   AS SF_NC,
                ((@SICON_SI + @SI_C_DB - @SI_C_CR) + @P_C_DB - @P_C_CR) AS SF_C,
                (((@SI_NC_DB - @SI_NC_CR) + (@SICON_SI + @SI_C_DB - @SI_C_CR))
                 + (@P_NC_DB + @P_C_DB) - (@P_NC_CR + @P_C_CR))   AS SF_TOTAL,

                /* Saldos en libros contables */
                @LIB_SI                                           AS LIBROS_SALDO_INICIAL,
                @LIB_DB                                           AS LIBROS_DEBITOS,
                @LIB_CR                                           AS LIBROS_CREDITOS,
                @LIB_SF                                           AS LIBROS_SALDO_FINAL;

            RETURN;
        END
        IF @METODO = 'SALVAR_CONCILIACION'
        BEGIN
            SELECT  @CNS = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CNS')), '')
            IF @CNS IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar CNS' AS ERROR;
                RETURN;
            END
            
            BEGIN TRY
                BEGIN TRANSACTION;
                    --se apaga trigger mientras se actualiza movimiento
                    ALTER TABLE MCH DISABLE TRIGGER TK_MCH_MOVIMIENTOS;
                    -- Actualizcion del movimiento 
                    UPDATE MCH 
                    SET
                        CONCILIADO = CASE WHEN RPDX.ID11 = 1 THEN 1 ELSE 0 END,
                        FECHACONCILIACION = CASE WHEN RPDX.ID11 = 1 THEN TRY_CAST(RPDX.ID16 AS DATE) ELSE NULL END
                    FROM MCH
                    INNER JOIN RPDX ON RPDX.ID12 = MCH.NROCOMPROBANTE AND RPDX.CNS = @CNS AND RPDX.ID17 = 1
                    INNER JOIN MCP B ON B.NROCOMPROBANTE = MCH.NROCOMPROBANTE
                    WHERE (
                            (NULLIF(TRIM(RPDX.ID13), '') IS NOT NULL AND MCH.NROASIENTO = RPDX.ID13)
                         OR (
                                NULLIF(TRIM(RPDX.ID13), '') IS NULL
                            AND MCH.DETALLE = RPDX.STRINGGRANDE1
                            AND ISNULL(B.NOCHEQUE, '') = ISNULL(RPDX.ID10, '')
                            AND ISNULL(MCH.IDTERCERO, '') = ISNULL(RPDX.ID4, '')
                            AND ISNULL(MCH.N_FACTURA, '') = ISNULL(RPDX.ID7, '')
                            )
                          )
                    --se activa trigger una vez actualizados los movimientos
                    ALTER TABLE MCH ENABLE TRIGGER TK_MCH_MOVIMIENTOS;
                 COMMIT TRANSACTION;
                    SELECT 'OK' AS OK, 'Conciliación salvada con éxito' AS MENSAJE
                       
                RETURN;
            END TRY
            BEGIN CATCH
                SELECT 'KO' AS OK,CONCAT('Error al salvar conciliación: ', ERROR_MESSAGE()) AS ERROR,ERROR_LINE() AS LINEA;
                RETURN;
            END CATCH
        END

        IF @METODO = 'MARCAR_DESMARCAR_IND'
        BEGIN
            SELECT
                @ITEM_RPDX          = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.ITEM') AS INT),
                @FECHA_CONCILIACION = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_CONCILIACION') AS DATE),
                @CNS                = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CNS')), ''),
                @ACCION             = UPPER(NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.ACCION')), ''));

            IF @CNS IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar CNS' AS ERROR;
                RETURN;
            END
            IF @ITEM_RPDX IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar ITEM (fila RPDX)' AS ERROR;
                RETURN;
            END
            IF @ACCION NOT IN ('MARCAR', 'DESMARCAR')
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar ACCION (MARCAR o DESMARCAR)' AS ERROR;
                RETURN;
            END

            IF @ACCION = 'MARCAR'
            BEGIN
                IF @FECHA_CONCILIACION IS NULL
                BEGIN
                    SELECT 'KO' AS OK, 'Debe indicar FECHA_CONCILIACION para marcar' AS ERROR;
                    RETURN;
                END

                UPDATE RPDX
                SET
                    ID11 = 1,
                    ID16 = CONVERT(VARCHAR(10), @FECHA_CONCILIACION, 103),
                    ID17 = 1
                WHERE ITEM = @ITEM_RPDX
                  AND CNS  = @CNS
                  AND (ID11 = 0 OR ID11 IS NULL OR ID11 = '0');

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 'KO' AS OK, 'El movimiento ya está marcado o no existe' AS ERROR;
                    RETURN;
                END

                SELECT
                    'OK' AS OK,
                    'Movimiento marcado' AS MENSAJE,
                    @ITEM_RPDX AS ITEM,
                    @FECHA_CONCILIACION AS FECHA_CONCILIACION;

                RETURN;
            END

            /* DESMARCAR — equivalente Clarion masivo, una fila */
            UPDATE RPDX
            SET
                ID11 = 0,
                ID16 = NULL,
                ID17 = 1
            WHERE ITEM = @ITEM_RPDX
              AND CNS  = @CNS
              AND (ID11 = 1 OR ID11 = '1');

            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 'KO' AS OK, 'El movimiento ya está desmarcado o no existe' AS ERROR;
                RETURN;
            END

            SELECT
                'OK' AS OK,
                'Movimiento desmarcado' AS MENSAJE,
                @ITEM_RPDX AS ITEM;

            RETURN;
        END
        IF @METODO = 'MARCAR_DESMARCAR_TODO'
        BEGIN
            SELECT
                @FECHA_CONCILIACION = TRY_CAST(JSON_VALUE(@PARAMETROS, '$.FECHA_CONCILIACION') AS DATE),
                @CNS                = NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.CNS')), ''),
                @ACCION             = UPPER(NULLIF(TRIM(JSON_VALUE(@PARAMETROS, '$.ACCION')), ''));

            IF @CNS IS NULL
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar CNS' AS ERROR;
                RETURN;
            END

            IF @ACCION NOT IN ('MARCAR', 'DESMARCAR')
            BEGIN
                SELECT 'KO' AS OK, 'Debe indicar ACCION (MARCAR o DESMARCAR)' AS ERROR;
                RETURN;
            END

            IF @ACCION = 'MARCAR'
            BEGIN
                IF @FECHA_CONCILIACION IS NULL
                BEGIN
                    SELECT 'KO' AS OK, 'Debe indicar FECHA_CONCILIACION para marcar' AS ERROR;
                    RETURN;
                END

                UPDATE RPDX
                SET
                    ID11 = 1,
                    ID16 = CONVERT(VARCHAR(10), @FECHA_CONCILIACION, 103),
                    ID17 = 1
                WHERE CNS = @CNS
                  AND (ID11 = 0 OR ID11 IS NULL OR ID11 = '0');

                SELECT
                    'OK' AS OK,
                    'Todos los movimientos marcados' AS MENSAJE,
                    @FECHA_CONCILIACION AS FECHA_CONCILIACION;

                RETURN;
            END

            /* DESMARCAR — equivalente Clarion: solo filas marcadas, ID16=NULL, ID17=1 */
            UPDATE RPDX
            SET
                ID11 = 0,
                ID16 = NULL,
                ID17 = 1
            WHERE CNS = @CNS
              AND (ID11 = 1 OR ID11 = '1');

            SELECT 'OK' AS OK, 'Todos los movimientos desmarcados' AS MENSAJE;

            RETURN;
        END

        
        SELECT 'KO' AS OK,
               'Método no soportado: ' + ISNULL(@METODO, '(vacío)') AS ERROR;
    END TRY
    BEGIN CATCH
        SELECT
            'RESULTADO'                AS TIPO_RESULTADO,
            'KO'                       AS OK,
            'Error: ' + ERROR_MESSAGE() AS MENSAJE,
            ERROR_LINE()               AS LINEA,
            ERROR_PROCEDURE()          AS PROCEDIMIENTO;
    END CATCH;
END

