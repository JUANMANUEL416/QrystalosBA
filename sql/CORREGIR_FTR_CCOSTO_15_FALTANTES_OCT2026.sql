/*
  Las que faltaron después del reparto de las 533.

  Quince facturas de consulta externa, prefijo 12, siguen en
  comprobantes con error:
    Trece tienen dispensación en el centro 10030102, área 4110.
    Ese par no tiene cuenta de ventas del prefijo 12, así que
    reconstruir con ese centro las deja en NO DEF.KMCOM.
    Dos no tienen solicitud ni centro: FV81411 y FV81414.
    Se salieron del reparto anterior porque la solicitud venía vacía.

  Entran al mismo peso de los movimientos 06 de octubre, solo en
  centros que sí tienen cuenta de ventas del prefijo 12.

  No incluye FV80459. Es capitada, el detalle ya tiene centro y
  el errado que queda es otra línea.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el reparto.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si no siguen siendo 15, no cambia nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 1;
DECLARE @PC varchar(254) = 'CONTABILIDAD';
DECLARE @MOD varchar(20) = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE');

IF OBJECT_ID('tempdb..#Fac') IS NOT NULL DROP TABLE #Fac;
IF OBJECT_ID('tempdb..#Cen') IS NOT NULL DROP TABLE #Cen;
IF OBJECT_ID('tempdb..#Cupo') IS NOT NULL DROP TABLE #Cupo;
IF OBJECT_ID('tempdb..#Asig') IS NOT NULL DROP TABLE #Asig;

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO, 0) = 1
)
    THROW 56190, 'Octubre de 2026 está cerrado en contabilidad.', 1;

SELECT
    F.N_FACTURA,
    D.PREFIJO,
    E.NROCOMPROBANTE,
    E.COMPANIA,
    E.IDSEDE,
    LEFT(E.USUARIO, 12) AS USUARIO,
    A.NOAUT
INTO #Fac
FROM dbo.MCPE E
INNER JOIN dbo.FTR F ON F.N_FACTURA = E.NOREFERENCIA
INNER JOIN dbo.FTRD D ON D.CNSFTR = F.CNSFCT
INNER JOIN dbo.AUT A ON A.NOAUT = D.NOADMISION
WHERE F.N_FACTURA IN (
    'FV80499','FV81275','FV81337','FV81351','FV81395','FV81402',
    'FV81411','FV81414','FV81436','FV81577','FV81631','FV81700',
    'FV81707','FV81713','FV81819'
)
  AND RTRIM(E.PROCEDENCIA) = 'FACTURA'
  AND F.PROCEDENCIA = 'CE'
  AND D.PREFIJO = '12'
  AND COALESCE(F.ESTADO, '') <> 'A'
  AND COALESCE(F.CONTABILIZADA, 0) = 2
  AND F.NROCOMPROBANTE = E.NROCOMPROBANTE
  AND COALESCE(D.CCOSTO, '') = ''
  AND COALESCE(D.AREAPRESTACION, '') = ''
  AND COALESCE(A.CCOSTO, '') = ''
  AND COALESCE(A.IDAREA, '') = ''
  AND E.COMPANIA = '01'
  AND E.IDSEDE = '06'
  AND (SELECT COUNT(*) FROM dbo.FTRD X WHERE X.CNSFTR = F.CNSFCT) = 1
  AND EXISTS (
      SELECT 1 FROM dbo.MCHE H
      WHERE H.NROCOMPROBANTE = E.NROCOMPROBANTE
        AND H.CUENTA LIKE 'NO DEF%'
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MCP P
      WHERE P.NROCOMPROBANTE = E.NROCOMPROBANTE
        AND COALESCE(P.ANULADO, 0) <> 1
  );

SELECT I.CCOSTO, I.IDAREA, COUNT(*) AS MOV06
INTO #Cen
FROM dbo.IMOV I
WHERE I.IDTIPOMOV = '06'
  AND COALESCE(I.ESTADO, 0) = 1
  AND COALESCE(I.CCOSTO, '') <> ''
  AND COALESCE(I.IDAREA, '') <> ''
  AND I.FECHACONF >= '20261001'
  AND I.FECHACONF < '20261101'
GROUP BY I.CCOSTO, I.IDAREA;

;WITH Pesos AS (
    SELECT
        F.PREFIJO,
        C.CCOSTO,
        C.IDAREA,
        C.MOV06,
        SUM(C.MOV06) OVER (PARTITION BY F.PREFIJO) AS TOTAL,
        (SELECT COUNT(*) FROM #Fac X WHERE X.PREFIJO = F.PREFIJO) AS NFAC
    FROM (SELECT DISTINCT PREFIJO FROM #Fac) F
    INNER JOIN #Cen C ON 1 = 1
    WHERE (
        SELECT COUNT(*)
        FROM dbo.KMCOM K
        WHERE K.IDMODELOCONT = @MOD
          AND K.IDTIPOCONT = 'VENTAS'
          AND K.TIPO = 'CR'
          AND K.PREFIJO = F.PREFIJO
          AND K.CCOSTO = C.CCOSTO
          AND K.IDAREA = C.IDAREA
          AND COALESCE(K.CUENTA, '') <> ''
          AND K.CUENTA NOT LIKE 'NO DEF%'
    ) = 1
),
Base AS (
    SELECT
        *,
        CAST((MOV06 * NFAC) / TOTAL AS int) AS BASE,
        (MOV06 * NFAC) % TOTAL AS FRAC
    FROM Pesos
),
Cupo AS (
    SELECT
        PREFIJO, CCOSTO, IDAREA, MOV06,
        BASE + CASE
            WHEN ROW_NUMBER() OVER (PARTITION BY PREFIJO ORDER BY FRAC DESC, CCOSTO, IDAREA)
                 <= NFAC - SUM(BASE) OVER (PARTITION BY PREFIJO)
            THEN 1 ELSE 0 END AS CUPO
    FROM Base
)
SELECT PREFIJO, CCOSTO, IDAREA, MOV06, CUPO,
       SUM(CUPO) OVER (
           PARTITION BY PREFIJO
           ORDER BY MOV06 DESC, CCOSTO, IDAREA
           ROWS UNBOUNDED PRECEDING
       ) AS HASTA
INTO #Cupo
FROM Cupo
WHERE CUPO > 0;

SELECT
    F.N_FACTURA,
    F.PREFIJO,
    F.NROCOMPROBANTE,
    F.COMPANIA,
    F.IDSEDE,
    F.USUARIO,
    F.NOAUT,
    C.CCOSTO,
    C.IDAREA
INTO #Asig
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY PREFIJO ORDER BY N_FACTURA) AS RN
    FROM #Fac
) F
INNER JOIN #Cupo C
    ON C.PREFIJO = F.PREFIJO
   AND F.RN > C.HASTA - C.CUPO
   AND F.RN <= C.HASTA;

SELECT CCOSTO, IDAREA, MOV06, CUPO
FROM #Cupo
ORDER BY MOV06 DESC, CCOSTO;

SELECT N_FACTURA, NROCOMPROBANTE, CCOSTO, IDAREA
FROM #Asig
ORDER BY N_FACTURA;

IF @APLICAR = 0
    RETURN;

IF (SELECT COUNT(*) FROM #Fac) <> 15
    THROW 56191, 'Ya no son las quince facturas pendientes. No quedó ningún cambio.', 1;

IF (SELECT COUNT(*) FROM #Asig) <> 15
    THROW 56192, 'El reparto no cubre las quince facturas. No quedó ningún cambio.', 1;

BEGIN TRAN;

DECLARE @Det TABLE (N_FACTURA varchar(16));
DECLARE @Aut TABLE (NOAUT varchar(20));

UPDATE D
SET CCOSTO = A.CCOSTO,
    AREAPRESTACION = A.IDAREA
OUTPUT inserted.N_FACTURA INTO @Det (N_FACTURA)
FROM dbo.FTRD D
INNER JOIN dbo.FTR F ON F.CNSFCT = D.CNSFTR
INNER JOIN #Asig A ON A.N_FACTURA = F.N_FACTURA
WHERE COALESCE(D.CCOSTO, '') = ''
  AND COALESCE(D.AREAPRESTACION, '') = '';

IF (SELECT COUNT(*) FROM @Det) <> 15
    THROW 56193, 'No se actualizó el detalle de las quince facturas. No quedó ningún cambio.', 1;

UPDATE U
SET CCOSTO = A.CCOSTO,
    IDAREA = A.IDAREA
OUTPUT inserted.NOAUT INTO @Aut (NOAUT)
FROM dbo.AUT U
INNER JOIN #Asig A ON A.NOAUT = U.NOAUT
WHERE COALESCE(U.CCOSTO, '') = ''
  AND COALESCE(U.IDAREA, '') = '';

IF (SELECT COUNT(*) FROM @Aut) <> 15
    THROW 56194, 'No se actualizó la autorización de las quince facturas. No quedó ningún cambio.', 1;

COMMIT TRAN;

DECLARE @NF varchar(16), @NRO varchar(20), @USU varchar(12);
DECLARE @CIA varchar(2), @SEDE varchar(5), @Msg nvarchar(240);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT N_FACTURA, NROCOMPROBANTE, USUARIO, COMPANIA, IDSEDE
    FROM #Asig
    ORDER BY N_FACTURA;

OPEN c;
FETCH NEXT FROM c INTO @NF, @NRO, @USU, @CIA, @SEDE;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.SPK_NC_CONTAB_FTR
        @NF, @CIA, @USU, @PC, @SEDE, @NRO;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.FTR
        WHERE N_FACTURA = @NF
          AND COALESCE(CONTABILIZADA, 0) = 1
    )
    OR EXISTS (
        SELECT 1 FROM dbo.MCHE H
        WHERE H.NROCOMPROBANTE = @NRO
          AND H.CUENTA LIKE 'NO DEF%'
    )
    BEGIN
        CLOSE c;
        DEALLOCATE c;
        SET @Msg = N'La factura ' + @NF + N' no quedó contabilizada. Las anteriores de la lista sí se reconstruyeron.';
        THROW 56195, @Msg, 1;
    END

    FETCH NEXT FROM c INTO @NF, @NRO, @USU, @CIA, @SEDE;
END

CLOSE c;
DEALLOCATE c;

SELECT N_FACTURA, CONTABILIZADA, NROCOMPROBANTE
FROM dbo.FTR
WHERE N_FACTURA IN (SELECT N_FACTURA FROM #Asig)
ORDER BY N_FACTURA;
