/*
  Pasa al 01/10/2026 la fecha del movimiento y la fecha de confirmación
  de tres dispensaciones confirmadas que el cierre de septiembre sigue listando.
  El precierre lee la fecha de confirmación. En la pantalla no se puede
  cambiar: el movimiento ya está confirmado y el editar lo rechaza.

  3300011234  bodega 080  solicitud 330000009242  05/09/2026
  3300011238  bodega 080  solicitud 330000009244  05/09/2026
  3400017715  bodega 077  solicitud 340000014633  21/09/2026

  Siguen sin comprobante. No se contabilizan aquí.
  No se tocan los cuatro que ya tienen comprobante.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @FECHA datetime = '20261001';

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO_INV, 0) = 1
)
    THROW 56150, 'Octubre de 2026 está cerrado en inventario.', 1;

SELECT
    I.CNSMOV,
    I.IDBODEGA,
    I.NODOCUMENTO,
    CONVERT(varchar(10), I.FECHAMOV, 103) AS FECHAMOV_HOY,
    CONVERT(varchar(10), I.FECHACONF, 103) AS FECHACONF_HOY,
    CONVERT(varchar(10), @FECHA, 103) AS FECHA_NUEVA
FROM dbo.IMOV I
WHERE I.CNSMOV IN ('3300011234', '3300011238', '3400017715')
  AND COALESCE(I.ESTADO, 0) = 1
  AND COALESCE(I.CONTABILIZADA, 0) = 0
  AND COALESCE(I.NROCOMPROBANTE, '') = ''
  AND I.FECHACONF >= '20260901'
  AND I.FECHACONF < '20261001'
ORDER BY I.CNSMOV;

IF @APLICAR = 0
    RETURN;

BEGIN TRAN;

DECLARE @Hechos TABLE (CNSMOV varchar(20));

UPDATE dbo.IMOV
SET FECHAMOV = @FECHA,
    FECHACONF = @FECHA
OUTPUT inserted.CNSMOV INTO @Hechos (CNSMOV)
WHERE CNSMOV IN ('3300011234', '3300011238', '3400017715')
  AND COALESCE(ESTADO, 0) = 1
  AND COALESCE(CONTABILIZADA, 0) = 0
  AND COALESCE(NROCOMPROBANTE, '') = ''
  AND FECHACONF >= '20260901'
  AND FECHACONF < '20261001';

IF (SELECT COUNT(*) FROM @Hechos) <> 3
    THROW 56151, 'No se actualizaron los tres movimientos. No quedó ningún cambio.', 1;

UPDATE dbo.IMOVH
SET FECHACONF = @FECHA
WHERE CNSMOV IN (SELECT CNSMOV FROM @Hechos);

SELECT CNSMOV FROM @Hechos ORDER BY CNSMOV;

COMMIT TRAN;
