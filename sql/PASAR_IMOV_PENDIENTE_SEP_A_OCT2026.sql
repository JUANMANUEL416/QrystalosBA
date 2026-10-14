/*
  Pasa a octubre los movimientos de inventario de septiembre
  que siguen sin confirmar (ESTADO = 0).

  Solo cambia IMOV.FECHAMOV. No toca confirmados, cantidades,
  costos, lotes ni la solicitud.

  Hoy el periodo de septiembre tiene dos, bodega 080, sin líneas:
    3300011226  solicitud 330000009233  05/09/2026
    3300011231  solicitud 330000009239  05/09/2026

  La fecha nueva es el 01/10/2026. Octubre está abierto.

  Los que el precierre sigue mostrando están confirmados (ESTADO = 1).
  Este script no los mueve.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si no hay pendientes o octubre está cerrado, hace ROLLBACK.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @FECHA datetime = '20261001';

IF EXISTS (
    SELECT 1
    FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO_INV, 0) = 1
)
    THROW 56130, 'Octubre de 2026 está cerrado en inventario.', 1;

SELECT
    I.CNSMOV,
    I.IDBODEGA,
    I.IDTIPOMOV,
    I.PROCEDENCIA,
    I.NODOCUMENTO,
    CONVERT(varchar(10), I.FECHAMOV, 103) AS FECHA_HOY,
    CONVERT(varchar(10), @FECHA, 103) AS FECHA_NUEVA,
    (SELECT COUNT(*) FROM dbo.IMOVH H WHERE H.CNSMOV = I.CNSMOV) AS LINEAS
FROM dbo.IMOV I
WHERE COALESCE(I.ESTADO, 0) = 0
  AND COALESCE(I.CONTABILIZADA, 0) = 0
  AND COALESCE(I.NROCOMPROBANTE, '') = ''
  AND I.FECHAMOV >= '20260901'
  AND I.FECHAMOV < '20261001'
ORDER BY I.IDBODEGA, I.CNSMOV;

IF @APLICAR = 0
    RETURN;

BEGIN TRAN;

DECLARE @Hechos TABLE (CNSMOV varchar(20));

UPDATE dbo.IMOV
SET FECHAMOV = @FECHA
OUTPUT inserted.CNSMOV INTO @Hechos (CNSMOV)
WHERE COALESCE(ESTADO, 0) = 0
  AND COALESCE(CONTABILIZADA, 0) = 0
  AND COALESCE(NROCOMPROBANTE, '') = ''
  AND FECHAMOV >= '20260901'
  AND FECHAMOV < '20261001';

IF NOT EXISTS (SELECT 1 FROM @Hechos)
    THROW 56131, 'No había movimientos sin confirmar en septiembre.', 1;

SELECT CNSMOV FROM @Hechos ORDER BY CNSMOV;

COMMIT TRAN;
