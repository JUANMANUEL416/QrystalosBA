CREATE OR ALTER PROCEDURE DBO.SPK_COMPARAR_RECAUDO_CAJA
    @CNSFTR   VARCHAR(40),
    @N_CUOTA  INT = NULL
AS
SET NOCOUNT ON;
SET DATEFORMAT dmy;

DECLARE @N_FACTURA VARCHAR(20);

SELECT @N_FACTURA = N_FACTURA
FROM FTR
WHERE CNSFCT = @CNSFTR;

IF @N_FACTURA IS NULL
BEGIN
    RAISERROR(N'No se encontró la factura para CNSFTR %s.', 16, 1, @CNSFTR);
    RETURN;
END;

/* ------------------------------------------------------------------
   Base FTRDC con clave de enlace a caja
IF OBJECT_ID('tempdb..#FTRDC_VAL') IS NOT NULL
    DROP TABLE #FTRDC_VAL;

SELECT
    D.CNSFTR,
    D.PROCEDENCIA,
    D.NOADMISION,
    D.NOPRESTACION,
    D.NOITEM,
    D.IDAFILIADO,
    D.TCOPAGO,
    COALESCE(D.VLR_COPAGO, 0)                                           AS VLR_COPAGO,
    CASE
        WHEN D.PROCEDENCIA IN ('CIT', 'ONCO', 'APLIM') THEN 'CITAS'
        ELSE D.PROCEDENCIA
    END                                                                 AS GRUPO_CAJA,
    CASE D.PROCEDENCIA
        WHEN 'HADM' THEN D.NOADMISION
        WHEN 'INV'  THEN D.NOADMISION
        ELSE D.NOPRESTACION
    END                                                                 AS FCJ_CLAVE,
    CASE
        WHEN D.PROCEDENCIA IN ('HADM', 'INV') THEN 'ADMISION'
        ELSE 'LINEA'
    END                                                                 AS NIVEL_ENLACE,
    CASE
        WHEN D.PROCEDENCIA = 'HADM' THEN NULL
        WHEN D.TCOPAGO = '01' THEN '02-1'
        WHEN D.TCOPAGO = '02' THEN '02'
        ELSE NULL
    END                                                                 AS FCJD_CONCEPTO
INTO #FTRDC_VAL
FROM FTRDC D
WHERE D.CNSFTR = @CNSFTR
  AND (@N_CUOTA IS NULL OR D.N_CUOTA = @N_CUOTA);

CREATE INDEX IX_FTRDC_VAL ON #FTRDC_VAL (GRUPO_CAJA, PROCEDENCIA, FCJ_CLAVE, FCJD_CONCEPTO);

/* ------------------------------------------------------------------
   0. Cuadro comparativo — relación capitada vs recaudo caja (grupos)
;WITH RELACION_GRUPO AS (
    SELECT
        V.GRUPO_CAJA,
        COUNT(*)                                                            AS REGISTROS,
        SUM(V.VLR_COPAGO)                                                   AS FTRDC_TOTAL,
        SUM(CASE
            WHEN V.GRUPO_CAJA = 'HADM' THEN V.VLR_COPAGO
            WHEN V.TCOPAGO = '01' THEN V.VLR_COPAGO
            ELSE 0
        END)                                                                AS FTRDC_COPAGO,
        SUM(CASE
            WHEN V.GRUPO_CAJA = 'HADM' THEN 0
            WHEN V.TCOPAGO = '02' THEN V.VLR_COPAGO
            ELSE 0
        END)                                                                AS FTRDC_MODERADORA,
        SUM(CASE
            WHEN V.GRUPO_CAJA = 'HADM' THEN 0
            WHEN V.TCOPAGO NOT IN ('01', '02') THEN V.VLR_COPAGO
            ELSE 0
        END)                                                                AS FTRDC_OTROS
    FROM #FTRDC_VAL V
    GROUP BY V.GRUPO_CAJA
),
RECAUDO_CITAS AS (
    SELECT
        'CITAS'                                                             AS GRUPO_CAJA,
        SUM(R.TOTAL_RECAUDO)                                                AS RECAUDO_TOTAL,
        SUM(R.RECAUDO_COPAGO)                                               AS RECAUDO_COPAGO,
        SUM(R.RECAUDO_MODERADORA)                                           AS RECAUDO_MODERADORA,
        SUM(R.RECIBOS)                                                      AS RECIBOS
    FROM (
        SELECT DISTINCT FCJ_CLAVE
        FROM #FTRDC_VAL
        WHERE GRUPO_CAJA = 'CITAS'
    ) D
    CROSS APPLY (
        SELECT
            SUM(FCJD.VALORTOTAL)                                            AS TOTAL_RECAUDO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA,
            COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                       AS RECIBOS
        FROM FCJ
        INNER JOIN FCJD
            ON FCJ.CODCAJA = FCJD.CODCAJA
           AND FCJ.CNSFACJ = FCJD.CNSFACJ
        WHERE FCJ.NOADMISION = D.FCJ_CLAVE
          AND FCJ.ESTADO = 'P'
    ) R
),
RECAUDO_HADM AS (
    SELECT
        'HADM'                                                              AS GRUPO_CAJA,
        SUM(R.TOTAL_RECAUDO)                                                AS RECAUDO_TOTAL,
        SUM(R.TOTAL_RECAUDO)                                                AS RECAUDO_COPAGO,
        CAST(0 AS DECIMAL(14, 2))                                           AS RECAUDO_MODERADORA,
        SUM(R.RECIBOS)                                                      AS RECIBOS
    FROM (
        SELECT DISTINCT FCJ_CLAVE
        FROM #FTRDC_VAL
        WHERE GRUPO_CAJA = 'HADM'
    ) D
    CROSS APPLY (
        SELECT
            SUM(FCJD.VALORTOTAL)                                            AS TOTAL_RECAUDO,
            COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                       AS RECIBOS
        FROM FCJ
        INNER JOIN FCJD
            ON FCJ.CODCAJA = FCJD.CODCAJA
           AND FCJ.CNSFACJ = FCJD.CNSFACJ
        WHERE FCJ.NOADMISION = D.FCJ_CLAVE
          AND FCJ.ESTADO = 'P'
    ) R
),
RECAUDO_OTROS AS (
    SELECT
        D.GRUPO_CAJA,
        SUM(R.TOTAL_RECAUDO)                                                AS RECAUDO_TOTAL,
        SUM(R.RECAUDO_COPAGO)                                               AS RECAUDO_COPAGO,
        SUM(R.RECAUDO_MODERADORA)                                           AS RECAUDO_MODERADORA,
        SUM(R.RECIBOS)                                                      AS RECIBOS
    FROM (
        SELECT DISTINCT GRUPO_CAJA, FCJ_CLAVE
        FROM #FTRDC_VAL
        WHERE GRUPO_CAJA NOT IN ('CITAS', 'HADM')
          AND NIVEL_ENLACE = 'LINEA'
    ) D
    CROSS APPLY (
        SELECT
            SUM(FCJD.VALORTOTAL)                                            AS TOTAL_RECAUDO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA,
            COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                       AS RECIBOS
        FROM FCJ
        INNER JOIN FCJD
            ON FCJ.CODCAJA = FCJD.CODCAJA
           AND FCJ.CNSFACJ = FCJD.CNSFACJ
        WHERE FCJ.NOADMISION = D.FCJ_CLAVE
          AND FCJ.ESTADO = 'P'
    ) R
    GROUP BY D.GRUPO_CAJA

    UNION ALL

    SELECT
        D.GRUPO_CAJA,
        SUM(R.TOTAL_RECAUDO)                                                AS RECAUDO_TOTAL,
        SUM(R.RECAUDO_COPAGO)                                               AS RECAUDO_COPAGO,
        SUM(R.RECAUDO_MODERADORA)                                           AS RECAUDO_MODERADORA,
        SUM(R.RECIBOS)                                                      AS RECIBOS
    FROM (
        SELECT DISTINCT GRUPO_CAJA, FCJ_CLAVE
        FROM #FTRDC_VAL
        WHERE GRUPO_CAJA NOT IN ('CITAS', 'HADM')
          AND NIVEL_ENLACE = 'ADMISION'
    ) D
    CROSS APPLY (
        SELECT
            SUM(FCJD.VALORTOTAL)                                            AS TOTAL_RECAUDO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
            SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA,
            COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                       AS RECIBOS
        FROM FCJ
        INNER JOIN FCJD
            ON FCJ.CODCAJA = FCJD.CODCAJA
           AND FCJ.CNSFACJ = FCJD.CNSFACJ
        WHERE FCJ.NOADMISION = D.FCJ_CLAVE
          AND FCJ.ESTADO = 'P'
    ) R
    GROUP BY D.GRUPO_CAJA
),
RECAUDO_GRUPO AS (
    SELECT * FROM RECAUDO_CITAS
    UNION ALL
    SELECT * FROM RECAUDO_HADM
    UNION ALL
    SELECT * FROM RECAUDO_OTROS
),
SIN_RECAUDO_GRUPO AS (
    SELECT
        V.GRUPO_CAJA,
        COUNT(*)                                                            AS SIN_RECAUDO_REGS,
        SUM(V.VLR_COPAGO)                                                   AS COPAGO_SIN_RECAUDO
    FROM #FTRDC_VAL V
    WHERE NOT EXISTS (
        SELECT 1
        FROM FCJ F
        WHERE F.NOADMISION = V.FCJ_CLAVE
          AND F.ESTADO = 'P'
    )
    GROUP BY V.GRUPO_CAJA
)
SELECT
    CUADRO.*
FROM (
SELECT
    @N_FACTURA                                                          AS N_FACTURA,
    @CNSFTR                                                             AS CNSFTR,
    R.GRUPO_CAJA,
    R.REGISTROS,
    R.FTRDC_TOTAL,
    R.FTRDC_COPAGO,
    R.FTRDC_MODERADORA,
    R.FTRDC_OTROS,
    COALESCE(C.RECIBOS, 0)                                              AS FCJ_RECIBOS,
    COALESCE(C.RECAUDO_TOTAL, 0)                                        AS RECAUDO_TOTAL,
    COALESCE(C.RECAUDO_COPAGO, 0)                                       AS RECAUDO_COPAGO,
    COALESCE(C.RECAUDO_MODERADORA, 0)                                   AS RECAUDO_MODERADORA,
    COALESCE(S.SIN_RECAUDO_REGS, 0)                                      AS SIN_RECAUDO_REGS,
    COALESCE(S.COPAGO_SIN_RECAUDO, 0)                                   AS COPAGO_SIN_RECAUDO,
    R.FTRDC_TOTAL - COALESCE(C.RECAUDO_TOTAL, 0)                        AS DIF_TOTAL,
    CASE
        WHEN R.GRUPO_CAJA = 'HADM' THEN R.FTRDC_TOTAL - COALESCE(C.RECAUDO_TOTAL, 0)
        ELSE R.FTRDC_COPAGO - COALESCE(C.RECAUDO_COPAGO, 0)
    END                                                                 AS DIF_COPAGO,
    CASE
        WHEN R.GRUPO_CAJA = 'HADM' THEN CAST(NULL AS DECIMAL(14, 2))
        ELSE R.FTRDC_MODERADORA + R.FTRDC_OTROS - COALESCE(C.RECAUDO_MODERADORA, 0)
    END                                                                 AS DIF_MODERADORA
FROM RELACION_GRUPO R
LEFT JOIN RECAUDO_GRUPO C
    ON C.GRUPO_CAJA = R.GRUPO_CAJA
LEFT JOIN SIN_RECAUDO_GRUPO S
    ON S.GRUPO_CAJA = R.GRUPO_CAJA

UNION ALL

SELECT
    @N_FACTURA,
    @CNSFTR,
    N'TOTAL'                                                            AS GRUPO_CAJA,
    SUM(R.REGISTROS),
    SUM(R.FTRDC_TOTAL),
    SUM(R.FTRDC_COPAGO),
    SUM(R.FTRDC_MODERADORA),
    SUM(R.FTRDC_OTROS),
    SUM(COALESCE(C.RECIBOS, 0)),
    SUM(COALESCE(C.RECAUDO_TOTAL, 0)),
    SUM(COALESCE(C.RECAUDO_COPAGO, 0)),
    SUM(COALESCE(C.RECAUDO_MODERADORA, 0)),
    SUM(COALESCE(S.SIN_RECAUDO_REGS, 0)),
    SUM(COALESCE(S.COPAGO_SIN_RECAUDO, 0)),
    SUM(R.FTRDC_TOTAL) - SUM(COALESCE(C.RECAUDO_TOTAL, 0)),
    SUM(R.FTRDC_COPAGO) - SUM(COALESCE(C.RECAUDO_COPAGO, 0)),
    SUM(R.FTRDC_MODERADORA + R.FTRDC_OTROS) - SUM(COALESCE(C.RECAUDO_MODERADORA, 0))
FROM RELACION_GRUPO R
LEFT JOIN RECAUDO_GRUPO C
    ON C.GRUPO_CAJA = R.GRUPO_CAJA
LEFT JOIN SIN_RECAUDO_GRUPO S
    ON S.GRUPO_CAJA = R.GRUPO_CAJA
) CUADRO
ORDER BY
    CASE CUADRO.GRUPO_CAJA WHEN N'TOTAL' THEN 2 ELSE 1 END,
    CUADRO.GRUPO_CAJA;

PRINT N'--- Detalle FTRDC por procedencia origen ---';

/* ------------------------------------------------------------------
   1. Resumen por procedencia FTRDC (detalle origen)
;WITH RELACION AS (
    SELECT
        PROCEDENCIA,
        COUNT(*)                                                            AS REGISTROS,
        SUM(VLR_COPAGO)                                                     AS TOTAL_COPAGO,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN VLR_COPAGO
            WHEN TCOPAGO = '01' THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS COPAGO_T01,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN 0
            WHEN TCOPAGO = '02' THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS MODERADORA_T02,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN 0
            WHEN TCOPAGO NOT IN ('01', '02') THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS OTROS_TCOPAGO
    FROM #FTRDC_VAL
    GROUP BY PROCEDENCIA
),
RECAUDO_LINEA AS (
    SELECT
        D.PROCEDENCIA,
        SUM(FCJD.VALORTOTAL)                                                AS TOTAL_RECAUDO,
        SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
        SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA,
        COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                           AS RECIBOS
    FROM #FTRDC_VAL D
    INNER JOIN FCJ
        ON FCJ.NOADMISION = D.FCJ_CLAVE
       AND FCJ.ESTADO = 'P'
    INNER JOIN FCJD
        ON FCJ.CODCAJA = FCJD.CODCAJA
       AND FCJ.CNSFACJ = FCJD.CNSFACJ
    WHERE D.NIVEL_ENLACE = 'LINEA'
    GROUP BY D.PROCEDENCIA
),
RECAUDO_ADMISION AS (
    SELECT
        X.PROCEDENCIA,
        SUM(X.TOTAL_RECAUDO)                                                AS TOTAL_RECAUDO,
        SUM(X.RECAUDO_COPAGO)                                               AS RECAUDO_COPAGO,
        SUM(X.RECAUDO_MODERADORA)                                           AS RECAUDO_MODERADORA,
        SUM(X.RECIBOS)                                                      AS RECIBOS
    FROM (
        SELECT
            D.PROCEDENCIA,
            R.TOTAL_RECAUDO,
            R.TOTAL_RECAUDO                                                   AS RECAUDO_COPAGO,
            CAST(0 AS DECIMAL(14, 2))                                         AS RECAUDO_MODERADORA,
            R.RECIBOS
        FROM (
            SELECT DISTINCT PROCEDENCIA, FCJ_CLAVE
            FROM #FTRDC_VAL
            WHERE NIVEL_ENLACE = 'ADMISION'
              AND PROCEDENCIA = 'HADM'
        ) D
        CROSS APPLY (
            SELECT
                SUM(FCJD.VALORTOTAL)                                          AS TOTAL_RECAUDO,
                COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                     AS RECIBOS
            FROM FCJ
            INNER JOIN FCJD
                ON FCJ.CODCAJA = FCJD.CODCAJA
               AND FCJ.CNSFACJ = FCJD.CNSFACJ
            WHERE FCJ.NOADMISION = D.FCJ_CLAVE
              AND FCJ.ESTADO = 'P'
        ) R

        UNION ALL

        SELECT
            D.PROCEDENCIA,
            R.TOTAL_RECAUDO,
            R.RECAUDO_COPAGO,
            R.RECAUDO_MODERADORA,
            R.RECIBOS
        FROM (
            SELECT DISTINCT PROCEDENCIA, FCJ_CLAVE
            FROM #FTRDC_VAL
            WHERE NIVEL_ENLACE = 'ADMISION'
              AND PROCEDENCIA <> 'HADM'
        ) D
        CROSS APPLY (
            SELECT
                SUM(FCJD.VALORTOTAL)                                          AS TOTAL_RECAUDO,
                SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
                SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA,
                COUNT(DISTINCT FCJ.CODCAJA + FCJ.CNSFACJ)                     AS RECIBOS
            FROM FCJ
            INNER JOIN FCJD
                ON FCJ.CODCAJA = FCJD.CODCAJA
               AND FCJ.CNSFACJ = FCJD.CNSFACJ
            WHERE FCJ.NOADMISION = D.FCJ_CLAVE
              AND FCJ.ESTADO = 'P'
        ) R
    ) X
    GROUP BY X.PROCEDENCIA
),
RECAUDO AS (
    SELECT PROCEDENCIA, TOTAL_RECAUDO, RECAUDO_COPAGO, RECAUDO_MODERADORA, RECIBOS
    FROM RECAUDO_LINEA
    UNION ALL
    SELECT PROCEDENCIA, TOTAL_RECAUDO, RECAUDO_COPAGO, RECAUDO_MODERADORA, RECIBOS
    FROM RECAUDO_ADMISION
),
SIN_RECAUDO AS (
    SELECT
        D.PROCEDENCIA,
        COUNT(*)                                                            AS REGISTROS_SIN_FCJ,
        SUM(D.VLR_COPAGO)                                                   AS COPAGO_SIN_FCJ
    FROM #FTRDC_VAL D
    WHERE NOT EXISTS (
        SELECT 1
        FROM FCJ F
        WHERE F.NOADMISION = D.FCJ_CLAVE
          AND F.ESTADO = 'P'
    )
    GROUP BY D.PROCEDENCIA
)
SELECT
    @N_FACTURA                                                          AS N_FACTURA,
    @CNSFTR                                                             AS CNSFTR,
    R.PROCEDENCIA,
    R.REGISTROS,
    R.TOTAL_COPAGO                                                      AS FTRDC_TOTAL,
    R.COPAGO_T01                                                        AS FTRDC_COPAGO,
    R.MODERADORA_T02                                                    AS FTRDC_MODERADORA,
    R.OTROS_TCOPAGO                                                     AS FTRDC_OTROS,
    COALESCE(C.RECIBOS, 0)                                              AS FCJ_RECIBOS,
    COALESCE(C.TOTAL_RECAUDO, 0)                                        AS RECAUDO_TOTAL,
    COALESCE(C.RECAUDO_COPAGO, 0)                                       AS RECAUDO_COPAGO,
    COALESCE(C.RECAUDO_MODERADORA, 0)                                   AS RECAUDO_MODERADORA,
    COALESCE(S.REGISTROS_SIN_FCJ, 0)                                    AS SIN_RECAUDO_REGS,
    COALESCE(S.COPAGO_SIN_FCJ, 0)                                       AS COPAGO_SIN_RECAUDO,
    R.TOTAL_COPAGO - COALESCE(C.TOTAL_RECAUDO, 0)                       AS DIF_TOTAL,
    CASE
        WHEN R.PROCEDENCIA = 'HADM' THEN R.TOTAL_COPAGO - COALESCE(C.TOTAL_RECAUDO, 0)
        ELSE R.COPAGO_T01 - COALESCE(C.RECAUDO_COPAGO, 0)
    END                                                                 AS DIF_COPAGO,
    CASE
        WHEN R.PROCEDENCIA = 'HADM' THEN CAST(NULL AS DECIMAL(14, 2))
        ELSE R.MODERADORA_T02 + R.OTROS_TCOPAGO - COALESCE(C.RECAUDO_MODERADORA, 0)
    END                                                                 AS DIF_MODERADORA
FROM RELACION R
LEFT JOIN RECAUDO C
    ON C.PROCEDENCIA = R.PROCEDENCIA
LEFT JOIN SIN_RECAUDO S
    ON S.PROCEDENCIA = R.PROCEDENCIA
ORDER BY R.PROCEDENCIA;

/* ------------------------------------------------------------------
   2. Totales consolidados factura
;WITH RELACION AS (
    SELECT
        SUM(VLR_COPAGO)                                                     AS TOTAL_COPAGO,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN VLR_COPAGO
            WHEN TCOPAGO = '01' THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS COPAGO_T01,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN 0
            WHEN TCOPAGO = '02' THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS MODERADORA_T02,
        SUM(CASE
            WHEN PROCEDENCIA = 'HADM' THEN 0
            WHEN TCOPAGO NOT IN ('01', '02') THEN VLR_COPAGO
            ELSE 0
        END)                                                                AS OTROS_TCOPAGO
    FROM #FTRDC_VAL
),
RECAUDO_CIT_ONCO_APLIM_AUT AS (
    SELECT
        SUM(FCJD.VALORTOTAL)                                                AS TOTAL_RECAUDO,
        SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
        SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA
    FROM #FTRDC_VAL D
    INNER JOIN FCJ
        ON FCJ.NOADMISION = D.FCJ_CLAVE
       AND FCJ.ESTADO = 'P'
    INNER JOIN FCJD
        ON FCJ.CODCAJA = FCJD.CODCAJA
       AND FCJ.CNSFACJ = FCJD.CNSFACJ
    WHERE D.NIVEL_ENLACE = 'LINEA'
),
RECAUDO_HADM_INV AS (
    SELECT
        SUM(X.TOTAL_RECAUDO)                                                AS TOTAL_RECAUDO,
        SUM(X.RECAUDO_COPAGO)                                               AS RECAUDO_COPAGO,
        SUM(X.RECAUDO_MODERADORA)                                           AS RECAUDO_MODERADORA
    FROM (
        SELECT
            R.TOTAL_RECAUDO,
            R.TOTAL_RECAUDO                                                   AS RECAUDO_COPAGO,
            CAST(0 AS DECIMAL(14, 2))                                         AS RECAUDO_MODERADORA
        FROM (
            SELECT DISTINCT FCJ_CLAVE
            FROM #FTRDC_VAL
            WHERE NIVEL_ENLACE = 'ADMISION'
              AND PROCEDENCIA = 'HADM'
        ) D
        CROSS APPLY (
            SELECT SUM(FCJD.VALORTOTAL) AS TOTAL_RECAUDO
            FROM FCJ
            INNER JOIN FCJD
                ON FCJ.CODCAJA = FCJD.CODCAJA
               AND FCJ.CNSFACJ = FCJD.CNSFACJ
            WHERE FCJ.NOADMISION = D.FCJ_CLAVE
              AND FCJ.ESTADO = 'P'
        ) R

        UNION ALL

        SELECT
            R.TOTAL_RECAUDO,
            R.RECAUDO_COPAGO,
            R.RECAUDO_MODERADORA
        FROM (
            SELECT DISTINCT FCJ_CLAVE
            FROM #FTRDC_VAL
            WHERE NIVEL_ENLACE = 'ADMISION'
              AND PROCEDENCIA <> 'HADM'
        ) D
        CROSS APPLY (
            SELECT
                SUM(FCJD.VALORTOTAL)                                          AS TOTAL_RECAUDO,
                SUM(CASE WHEN FCJD.CONCEPTO = '02-1' THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_COPAGO,
                SUM(CASE WHEN FCJD.CONCEPTO = '02'   THEN FCJD.VALORTOTAL ELSE 0 END) AS RECAUDO_MODERADORA
            FROM FCJ
            INNER JOIN FCJD
                ON FCJ.CODCAJA = FCJD.CODCAJA
               AND FCJ.CNSFACJ = FCJD.CNSFACJ
            WHERE FCJ.NOADMISION = D.FCJ_CLAVE
              AND FCJ.ESTADO = 'P'
        ) R
    ) X
),
RECAUDO AS (
    SELECT
        COALESCE(L.TOTAL_RECAUDO, 0) + COALESCE(A.TOTAL_RECAUDO, 0)         AS TOTAL_RECAUDO,
        COALESCE(L.RECAUDO_COPAGO, 0) + COALESCE(A.RECAUDO_COPAGO, 0)     AS RECAUDO_COPAGO,
        COALESCE(L.RECAUDO_MODERADORA, 0) + COALESCE(A.RECAUDO_MODERADORA, 0) AS RECAUDO_MODERADORA
    FROM RECAUDO_CIT_ONCO_APLIM_AUT L
    CROSS JOIN RECAUDO_HADM_INV A
)
SELECT
    F.N_FACTURA,
    F.VALORCOPAGO,
    F.VALORMODERADORA,
    F.VALORSERVICIOS,
    R.TOTAL_COPAGO                                                      AS FTRDC_TOTAL,
    R.COPAGO_T01                                                        AS FTRDC_COPAGO,
    R.MODERADORA_T02                                                    AS FTRDC_MODERADORA,
    R.OTROS_TCOPAGO                                                     AS FTRDC_OTROS,
    C.TOTAL_RECAUDO                                                     AS RECAUDO_TOTAL,
    C.RECAUDO_COPAGO,
    C.RECAUDO_MODERADORA,
    R.TOTAL_COPAGO - C.TOTAL_RECAUDO                                    AS DIF_TOTAL,
    F.VALORCOPAGO - R.TOTAL_COPAGO                                      AS DIF_FTR_VS_FTRDC
FROM FTR F
CROSS JOIN RELACION R
CROSS JOIN RECAUDO C
WHERE F.CNSFCT = @CNSFTR;

/* ------------------------------------------------------------------
   3a. Detalle diferencias — procedencias a nivel línea (CIT, ONCO, APLIM, AUT)
SELECT TOP 100
    D.PROCEDENCIA,
    D.NIVEL_ENLACE,
    D.NOADMISION,
    D.NOPRESTACION,
    D.NOITEM,
    D.IDAFILIADO,
    D.TCOPAGO,
    D.VLR_COPAGO,
    COALESCE(R.RECAUDO, 0)                                              AS RECAUDO_FCJ,
    D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)                               AS DIFERENCIA,
    CASE WHEN R.RECAUDO IS NULL THEN N'SIN RECIBO' ELSE N'CON RECIBO' END AS ESTADO_RECAUDO
FROM #FTRDC_VAL D
OUTER APPLY (
    SELECT SUM(FCJD.VALORTOTAL) AS RECAUDO
    FROM FCJ
    INNER JOIN FCJD
        ON FCJ.CODCAJA = FCJD.CODCAJA
       AND FCJ.CNSFACJ = FCJD.CNSFACJ
    WHERE FCJ.NOADMISION = D.FCJ_CLAVE
      AND FCJ.ESTADO = 'P'
      AND (
            D.FCJD_CONCEPTO IS NULL
            OR FCJD.CONCEPTO = D.FCJD_CONCEPTO
          )
) R
WHERE D.NIVEL_ENLACE = 'LINEA'
  AND ABS(D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)) > 0.01
ORDER BY ABS(D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)) DESC;

/* ------------------------------------------------------------------
   3b. Detalle diferencias — procedencias a nivel admisión (HADM, INV)
SELECT
    D.PROCEDENCIA,
    N'ADMISION'                                                         AS NIVEL_ENLACE,
    D.NOADMISION,
    NULL                                                                AS NOPRESTACION,
    NULL                                                                AS NOITEM,
    NULL                                                                AS IDAFILIADO,
    NULL                                                                AS TCOPAGO,
    D.VLR_COPAGO,
    COALESCE(R.RECAUDO, 0)                                              AS RECAUDO_FCJ,
    D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)                               AS DIFERENCIA,
    CASE WHEN R.RECAUDO IS NULL THEN N'SIN RECIBO' ELSE N'CON RECIBO' END AS ESTADO_RECAUDO
FROM (
    SELECT
        PROCEDENCIA,
        NOADMISION,
        FCJ_CLAVE,
        SUM(VLR_COPAGO)                                                 AS VLR_COPAGO
    FROM #FTRDC_VAL
    WHERE NIVEL_ENLACE = 'ADMISION'
    GROUP BY PROCEDENCIA, NOADMISION, FCJ_CLAVE
) D
OUTER APPLY (
    SELECT SUM(FCJD.VALORTOTAL) AS RECAUDO
    FROM FCJ
    INNER JOIN FCJD
        ON FCJ.CODCAJA = FCJD.CODCAJA
       AND FCJ.CNSFACJ = FCJD.CNSFACJ
    WHERE FCJ.NOADMISION = D.FCJ_CLAVE
      AND FCJ.ESTADO = 'P'
) R
WHERE ABS(D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)) > 0.01
ORDER BY ABS(D.VLR_COPAGO - COALESCE(R.RECAUDO, 0)) DESC;

DROP TABLE #FTRDC_VAL;
