/*
  Cuatro compras de octubre con líneas en NO DEF.KMCOM.

  El artículo de la línea está en tipo 06. El principal no.
    MX1817-2 y MX1817-3 tienen principal MX1817, tipo 01, medicamentos.
    MX2433-1 tiene principal MX2433, tipo 14, fitoterapéuticos.
  En compras, centro 10220202 y área 4110, los dos tipos ya tienen
  cuenta: débito 14150502 y crédito 22050101.

  El script copia el tipo del principal a la línea y al artículo,
  y pone la cuenta que devuelve el modelo. No cambia cantidades,
  precios, IVA ni la entrada. No causa.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el tipo y la cuenta.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si la línea ya no está en NO DEF.KMCOM, no cambia nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 1;
DECLARE @MOD varchar(20) = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE');
DECLARE @CCOSTO varchar(20) = '10220202';
DECLARE @IDAREA varchar(20) = '4110';

IF OBJECT_ID('tempdb..#Lin') IS NOT NULL DROP TABLE #Lin;

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO, 0) = 1
)
    THROW 56210, 'Octubre de 2026 está cerrado en contabilidad.', 1;

SELECT
    D.CNSFCXP,
    D.ITEM,
    D.IDSERVICIO,
    P.IDARTICULO AS PRINCIPAL,
    P.IDITAR AS TIPO,
    DBO.FNK_CUENTA_KMCOM(@MOD, 'CXP_COMPRAS', 'DB', P.IDITAR, @IDAREA, @CCOSTO, 'S', H.IDGRUPO) AS CUENTA,
    DBO.FNK_CUENTA_KMCOM(@MOD, 'CXP_COMPRAS', 'CR', P.IDITAR, @IDAREA, @CCOSTO, 'P', '') AS CREDITO
INTO #Lin
FROM dbo.FCXPD D
INNER JOIN dbo.FCXP F ON F.CNSFCXP = D.CNSFCXP
INNER JOIN dbo.IART H ON H.IDARTICULO = D.IDSERVICIO
INNER JOIN dbo.IART P
    ON P.IDARTICULO = CASE D.IDSERVICIO
        WHEN 'MX1817-2' THEN 'MX1817'
        WHEN 'MX1817-3' THEN 'MX1817'
        WHEN 'MX2433-1' THEN 'MX2433'
    END
   AND P.PRINCIPAL = 1
WHERE F.ESTADO = 'N'
  AND COALESCE(F.CONTABILIZADA, 0) = 0
  AND COALESCE(F.NROCOMPROBANTE, '') = ''
  AND D.CUENTA_SER LIKE 'NO DEF%'
  AND RTRIM(D.CCOSTO) = @CCOSTO
  AND RTRIM(D.IDAREA) = @IDAREA
  AND D.PREFIJO = '06'
  AND (
      (D.CNSFCXP = '03CM002555' AND D.ITEM = 3 AND D.IDSERVICIO = 'MX1817-2')
      OR (D.CNSFCXP = '03CM002567' AND D.ITEM = 2 AND D.IDSERVICIO = 'MX1817-2')
      OR (D.CNSFCXP = '03CM002599' AND D.ITEM = 1 AND D.IDSERVICIO = 'MX2433-1')
      OR (D.CNSFCXP = '34CM000173' AND D.ITEM IN (1, 2, 3) AND D.IDSERVICIO = 'MX1817-3')
  );

IF (SELECT COUNT(*) FROM #Lin) <> 6
    THROW 56211, 'Ya no son las seis líneas en NO DEF.KMCOM.', 1;

IF EXISTS (
    SELECT 1 FROM #Lin
    WHERE PRINCIPAL = 'MX1817' AND TIPO <> '01'
       OR PRINCIPAL = 'MX2433' AND TIPO <> '14'
)
    THROW 56212, 'El principal ya no está en el tipo 01 o 14.', 1;

IF EXISTS (
    SELECT 1 FROM #Lin
    WHERE CUENTA <> '14150502'
       OR CREDITO <> '22050101'
       OR CUENTA LIKE 'NO DEF%'
)
    THROW 56213, 'El modelo de compras no devolvió 14150502 y 22050101.', 1;

SELECT
    L.CNSFCXP,
    L.ITEM,
    L.IDSERVICIO,
    L.PRINCIPAL,
    L.TIPO,
    L.CUENTA,
    F.CUECREDITO AS CREDITO_HOY,
    L.CREDITO AS CREDITO_NUEVO
FROM #Lin L
INNER JOIN dbo.FCXP F ON F.CNSFCXP = L.CNSFCXP
ORDER BY L.CNSFCXP, L.ITEM;

IF @APLICAR = 0
    RETURN;

UPDATE D
SET PREFIJO = L.TIPO,
    CUENTA_SER = L.CUENTA
FROM dbo.FCXPD D
INNER JOIN #Lin L ON L.CNSFCXP = D.CNSFCXP AND L.ITEM = D.ITEM
WHERE D.CUENTA_SER LIKE 'NO DEF%'
  AND D.PREFIJO = '06';

IF @@ROWCOUNT <> 6
    THROW 56214, 'No se actualizaron las seis líneas.', 1;

UPDATE F
SET CUECREDITO = L.CREDITO
FROM dbo.FCXP F
INNER JOIN (
    SELECT CNSFCXP, MIN(CREDITO) AS CREDITO
    FROM #Lin
    GROUP BY CNSFCXP
) L ON L.CNSFCXP = F.CNSFCXP
WHERE F.CUECREDITO LIKE 'NO DEF%'
  AND F.CNSFCXP IN ('03CM002599', '34CM000173');

IF @@ROWCOUNT <> 2
    THROW 56215, 'No se actualizó el crédito de las dos cuentas.', 1;

UPDATE H
SET IDITAR = P.IDITAR
FROM dbo.IART H
INNER JOIN dbo.IART P
    ON P.IDARTICULO = CASE H.IDARTICULO
        WHEN 'MX1817-2' THEN 'MX1817'
        WHEN 'MX1817-3' THEN 'MX1817'
        WHEN 'MX2433-1' THEN 'MX2433'
    END
   AND P.PRINCIPAL = 1
WHERE H.IDARTICULO IN ('MX1817-2', 'MX1817-3', 'MX2433-1')
  AND H.IDITAR = '06'
  AND H.PRINCIPAL = 0;

IF @@ROWCOUNT <> 3
    THROW 56216, 'No se actualizó el tipo de los tres artículos.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.FCXPD D
    WHERE (
        (D.CNSFCXP = '03CM002555' AND D.ITEM = 3)
        OR (D.CNSFCXP = '03CM002567' AND D.ITEM = 2)
        OR (D.CNSFCXP = '03CM002599' AND D.ITEM = 1)
        OR (D.CNSFCXP = '34CM000173' AND D.ITEM IN (1, 2, 3))
    )
      AND (D.CUENTA_SER <> '14150502' OR D.PREFIJO NOT IN ('01', '14'))
)
    THROW 56217, 'Alguna línea quedó sin la cuenta del principal.', 1;
