/*
  Corrección masiva de IART.IDSERVICIO en artículos comerciales (PRINCIPAL = 0).

  El comercial queda con el código de otro artículo (otro fabricante de la misma
  familia, o un artículo ajeno) en lugar del servicio del principal.
  Ejemplo CEM: MX1266-1 (Legrand) tiene IDSERVICIO = MX1266-2.
  El principal MX1266 tiene IDSERVICIO = MX1266. Ahí debe quedar el hijo.

  Conteo de solo lectura del 2026-09-23:
    CEM  112
    PCEM   1
  Los 113 apuntan a otro IDARTICULO. Ninguno apunta a su propio código.

  No toca SER, movimientos, existencias ni el artículo principal.
  No se ejecuta desde BA.

  1) Deje @APLICAR = 0 y ejecute el script completo: solo lista.
  2) Revise el listado.
  3) Ponga @APLICAR = 1 y ejecute de nuevo. Graba y, si aún queda un cruzado
     de la misma regla, deshace todo.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR BIT = 0;
DECLARE @NA VARCHAR(20) = LTRIM(RTRIM(DBO.FNK_VALORVARIABLE('DEINVNODESER')));

IF OBJECT_ID('tempdb..#corr') IS NOT NULL DROP TABLE #corr;

SELECT
    h.IDARTICULO,
    LTRIM(RTRIM(h.IDSERVICIO)) AS IDSERVICIO_HOY,
    LTRIM(RTRIM(p.IDSERVICIO)) AS IDSERVICIO_NUEVO,
    p.IDARTICULO AS IDARTICULO_PRINCIPAL
INTO #corr
FROM dbo.IART h
INNER JOIN dbo.IART p
    ON p.IDARTICULO = LEFT(h.IDARTICULO, LEN(h.IDARTICULO) - CHARINDEX('-', REVERSE(h.IDARTICULO)))
   AND COALESCE(p.PRINCIPAL, 0) = 1
INNER JOIN dbo.IART otro
    ON otro.IDARTICULO = LTRIM(RTRIM(h.IDSERVICIO))
   AND otro.IDARTICULO <> h.IDARTICULO
WHERE COALESCE(h.PRINCIPAL, 0) = 0
  AND CHARINDEX('-', h.IDARTICULO) > 0
  AND TRY_CAST(RIGHT(h.IDARTICULO, CHARINDEX('-', REVERSE(h.IDARTICULO)) - 1) AS INT) IS NOT NULL
  AND LTRIM(RTRIM(h.IDSERVICIO)) <> LTRIM(RTRIM(p.IDSERVICIO))
  AND NULLIF(LTRIM(RTRIM(p.IDSERVICIO)), '') IS NOT NULL
  AND LTRIM(RTRIM(p.IDSERVICIO)) <> @NA
  AND EXISTS (
        SELECT 1 FROM dbo.SER s
        WHERE s.IDSERVICIO = LTRIM(RTRIM(p.IDSERVICIO))
      );

SELECT COUNT(*) AS A_CORREGIR FROM #corr;

SELECT IDARTICULO, IDSERVICIO_HOY, IDSERVICIO_NUEVO, IDARTICULO_PRINCIPAL
FROM #corr
ORDER BY IDARTICULO_PRINCIPAL, IDARTICULO;

IF @APLICAR = 0
BEGIN
    SELECT 'VISTA PREVIA' AS RESULTADO, 'No se grabó. Para corregir, @APLICAR = 1 y ejecute de nuevo.' AS DETALLE;
    RETURN;
END

BEGIN TRAN;

UPDATE h
SET h.IDSERVICIO = c.IDSERVICIO_NUEVO
FROM dbo.IART h
INNER JOIN #corr c ON c.IDARTICULO = h.IDARTICULO
WHERE LTRIM(RTRIM(h.IDSERVICIO)) = c.IDSERVICIO_HOY;

IF EXISTS (
    SELECT 1
    FROM dbo.IART h
    INNER JOIN #corr c ON c.IDARTICULO = h.IDARTICULO
    WHERE LTRIM(RTRIM(h.IDSERVICIO)) <> c.IDSERVICIO_NUEVO
)
BEGIN
    ROLLBACK TRAN;
    SELECT 'ROLLBACK' AS RESULTADO, 'Quedó algún artículo sin el servicio del principal. No se grabó nada.' AS DETALLE;
    RETURN;
END

COMMIT TRAN;

SELECT 'GRABADO' AS RESULTADO, COUNT(*) AS CORREGIDOS FROM #corr;

SELECT h.IDARTICULO, h.IDSERVICIO, c.IDARTICULO_PRINCIPAL
FROM dbo.IART h
INNER JOIN #corr c ON c.IDARTICULO = h.IDARTICULO
ORDER BY c.IDARTICULO_PRINCIPAL, h.IDARTICULO;
