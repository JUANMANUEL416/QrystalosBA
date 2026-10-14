/*
  Reparte centro de costo a las 533 facturas de consulta externa que
  están en comprobantes con error, sin dispensación de donde copiarlo.

  El peso de cada centro es la cantidad de movimientos 06 confirmados
  en octubre de 2026 que ya traen ese centro y esa área. Solo entran
  los centros que tienen una cuenta de ventas en el modelo para el
  prefijo de la factura. Si no hay cuenta, reconstruir las dejaría
  otra vez en NO DEF.KMCOM.

  El centro 10310102, área 4111, es el que más dispensaciones tiene
  (998) y no entra en el prefijo 12: no hay cuenta de ventas.
  Las 522 de ese prefijo se reparten entre los centros que sí tienen
  cuenta. Las 11 del prefijo 16 sí pueden usar 10310102.

  Se copia el centro y el área al detalle y a la autorización, y se
  reconstruye el mismo comprobante.

  No entran las 14 que ya tienen dispensación con cuenta, ni las 13
  cuya dispensación no está en el modelo, ni FV80459.
  No cambia cantidades ni valores.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el reparto.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si no siguen siendo 533, no cambia nada.
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
    THROW 56180, 'Octubre de 2026 está cerrado en contabilidad.', 1;

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
WHERE RTRIM(E.PROCEDENCIA) = 'FACTURA'
  AND F.PROCEDENCIA = 'CE'
  AND COALESCE(F.ESTADO, '') <> 'A'
  AND COALESCE(F.CONTABILIZADA, 0) = 2
  AND F.NROCOMPROBANTE = E.NROCOMPROBANTE
  AND F.F_FACTURA >= '20261001'
  AND F.F_FACTURA < '20261101'
  AND COALESCE(D.CCOSTO, '') = ''
  AND COALESCE(D.AREAPRESTACION, '') = ''
  AND COALESCE(A.CCOSTO, '') = ''
  AND COALESCE(A.IDAREA, '') = ''
  AND E.COMPANIA = '01'
  AND E.IDSEDE = '06'
  AND (SELECT COUNT(*) FROM dbo.FTRD X WHERE X.CNSFTR = F.CNSFCT) = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MCP P
      WHERE P.NROCOMPROBANTE = E.NROCOMPROBANTE
        AND COALESCE(P.ANULADO, 0) <> 1
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.IMOV I
      WHERE I.NODOCUMENTO = A.CNSMOV
        AND COALESCE(I.ESTADO, 0) = 1
        AND COALESCE(I.CCOSTO, '') <> ''
  )
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.IZSOL Z
      INNER JOIN dbo.IMOV I
          ON I.NODOCUMENTO = Z.CNSIZSOL
         AND COALESCE(I.ESTADO, 0) = 1
         AND COALESCE(I.CCOSTO, '') <> ''
      WHERE Z.NOADMISION IN (A.NOAUT, A.IDAUT)
  )
  AND (
      DBO.FNK_VALORVARIABLE('CONTAB_FTR_POSTDIAN') <> 'SI'
      OR COALESCE(F.FACTE, 0) = 2
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

SELECT PREFIJO, CCOSTO, IDAREA, MOV06, CUPO
FROM #Cupo
ORDER BY PREFIJO, MOV06 DESC, CCOSTO;

SELECT PREFIJO, COUNT(*) AS FACTURAS
FROM #Asig
GROUP BY PREFIJO
ORDER BY PREFIJO;

IF @APLICAR = 0
    RETURN;

IF (SELECT COUNT(*) FROM #Fac) <> 533
    THROW 56181, 'Ya no son 533 facturas sin dispensación. No quedó ningún cambio.', 1;

IF (SELECT COUNT(*) FROM #Asig) <> 533
    OR EXISTS (SELECT 1 FROM #Fac F WHERE NOT EXISTS (SELECT 1 FROM #Asig A WHERE A.N_FACTURA = F.N_FACTURA))
    THROW 56182, 'El reparto no cubre las 533 facturas. No quedó ningún cambio.', 1;

IF EXISTS (SELECT 1 FROM #Fac WHERE COALESCE(USUARIO, '') = '')
    THROW 56183, 'Hay una factura sin usuario en el comprobante. No quedó ningún cambio.', 1;

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
  AND COALESCE(D.AREAPRESTACION, '') = ''
  AND (SELECT COUNT(*) FROM dbo.FTRD X WHERE X.CNSFTR = F.CNSFCT) = 1;

IF (SELECT COUNT(*) FROM @Det) <> 533
    THROW 56184, 'No se actualizó el detalle de las 533 facturas. No quedó ningún cambio.', 1;

UPDATE U
SET CCOSTO = A.CCOSTO,
    IDAREA = A.IDAREA
OUTPUT inserted.NOAUT INTO @Aut (NOAUT)
FROM dbo.AUT U
INNER JOIN #Asig A ON A.NOAUT = U.NOAUT
WHERE COALESCE(U.CCOSTO, '') = ''
  AND COALESCE(U.IDAREA, '') = '';

IF (SELECT COUNT(*) FROM @Aut) <> 533
    THROW 56185, 'No se actualizó la autorización de las 533 facturas. No quedó ningún cambio.', 1;

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
        THROW 56186, @Msg, 1;
    END

    FETCH NEXT FROM c INTO @NF, @NRO, @USU, @CIA, @SEDE;
END

CLOSE c;
DEALLOCATE c;

SELECT PREFIJO, CCOSTO, IDAREA, COUNT(*) AS FACTURAS
FROM #Asig
GROUP BY PREFIJO, CCOSTO, IDAREA
ORDER BY PREFIJO, FACTURAS DESC;
