/*
  Pasa al 01/10/2026 las 23 dispensaciones confirmadas que seguían
  con fecha de confirmación en septiembre.

  Siete nunca se enviaron. No tienen comprobante ni centro de costo:
    3400017963 a 3400017969, bodega 077.

  Dieciséis ya están en comprobantes con error, periodo septiembre,
  procedencia INV. Las líneas tienen cuenta, centro, tercero y área,
  el débito cuadra con el crédito y el texto de error está vacío.
  La cabecera está en estado 1 y el movimiento sigue sin causar.
  Septiembre contable está cerrado, así que el comprobante no pasó a libros.
  Aquí también se mueve el año, el mes y la fecha contable de ese errado.

  No se reconstruye, no se confirma y no se llenan centros de costo.
  No se tocan cantidades, costos ni lotes.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si algo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @FECHA datetime = '20261001';

DECLARE @Mov TABLE (
    CNSMOV varchar(20) NOT NULL PRIMARY KEY,
    NRO varchar(20) NULL
);

INSERT INTO @Mov (CNSMOV, NRO) VALUES
    ('3400017963', NULL),
    ('3400017964', NULL),
    ('3400017965', NULL),
    ('3400017966', NULL),
    ('3400017967', NULL),
    ('3400017968', NULL),
    ('3400017969', NULL),
    ('2900009342', '2968000000007070'),
    ('3400017807', '3468000000011589'),
    ('3400017809', '3468000000011591'),
    ('3400017820', '3468000000011599'),
    ('3400017828', '3468000000011604'),
    ('3400017911', '3468000000011684'),
    ('3400017938', '3468000000011709'),
    ('3400017940', '3468000000011711'),
    ('3400017942', '3468000000011713'),
    ('3400017943', '3468000000011714'),
    ('3400017950', '3468000000011720'),
    ('3400017954', '3468000000011724'),
    ('3400017960', '3468000000011729'),
    ('3300011267', '3368000000007442'),
    ('3300011272', '3368000000007445'),
    ('3300011278', '3368000000007451');

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10
      AND (COALESCE(CERRADO, 0) = 1 OR COALESCE(CERRADO_INV, 0) = 1)
)
    THROW 56160, 'Octubre de 2026 está cerrado en contabilidad o en inventario.', 1;

SELECT
    M.CNSMOV,
    I.IDBODEGA,
    I.NODOCUMENTO,
    CONVERT(varchar(10), I.FECHAMOV, 103) AS FECHAMOV_HOY,
    CONVERT(varchar(10), I.FECHACONF, 103) AS FECHACONF_HOY,
    COALESCE(M.NRO, '(sin comprobante)') AS COMPROBANTE,
    CASE WHEN COALESCE(I.CCOSTO, '') = '' THEN 'NO' ELSE 'SI' END AS TIENE_CENTRO,
    CONVERT(varchar(10), E.FECHACONTABLE, 103) AS FECHA_CONTABLE_HOY,
    CONVERT(varchar(10), @FECHA, 103) AS FECHA_NUEVA
FROM @Mov M
LEFT JOIN dbo.IMOV I ON I.CNSMOV = M.CNSMOV
LEFT JOIN dbo.MCPE E ON E.NROCOMPROBANTE = M.NRO
ORDER BY M.CNSMOV;

IF @APLICAR = 0
    RETURN;

BEGIN TRAN;

DECLARE @Libres TABLE (CNSMOV varchar(20));
DECLARE @Enviados TABLE (CNSMOV varchar(20));
DECLARE @Errados TABLE (NRO varchar(20));

UPDATE dbo.IMOV
SET FECHAMOV = @FECHA,
    FECHACONF = @FECHA
OUTPUT inserted.CNSMOV INTO @Libres (CNSMOV)
WHERE CNSMOV IN (SELECT CNSMOV FROM @Mov WHERE NRO IS NULL)
  AND COALESCE(ESTADO, 0) = 1
  AND COALESCE(SECONTABILIZA, 0) = 1
  AND COALESCE(CONTABILIZADA, 0) = 0
  AND COALESCE(NROCOMPROBANTE, '') = ''
  AND FECHACONF >= '20260901'
  AND FECHACONF < '20261001';

IF (SELECT COUNT(*) FROM @Libres) <> 7
    THROW 56161, 'No se actualizaron las siete dispensaciones sin comprobante. No quedó ningún cambio.', 1;

UPDATE I
SET FECHAMOV = @FECHA,
    FECHACONF = @FECHA
OUTPUT inserted.CNSMOV INTO @Enviados (CNSMOV)
FROM dbo.IMOV I
INNER JOIN @Mov M ON M.CNSMOV = I.CNSMOV AND M.NRO IS NOT NULL
WHERE COALESCE(I.ESTADO, 0) = 1
  AND COALESCE(I.SECONTABILIZA, 0) = 1
  AND COALESCE(I.CONTABILIZADA, 0) = 0
  AND I.NROCOMPROBANTE = M.NRO
  AND I.FECHACONF >= '20260901'
  AND I.FECHACONF < '20261001'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MCP P WHERE P.NROCOMPROBANTE = M.NRO
  );

IF (SELECT COUNT(*) FROM @Enviados) <> 16
    THROW 56162, 'No se actualizaron las dieciséis dispensaciones que ya tienen errado. No quedó ningún cambio.', 1;

UPDATE dbo.IMOVH
SET FECHACONF = @FECHA
WHERE CNSMOV IN (SELECT CNSMOV FROM @Libres)
   OR CNSMOV IN (SELECT CNSMOV FROM @Enviados);

UPDATE E
SET ANO = '2026',
    MES = 10,
    FECHACONTABLE = @FECHA
OUTPUT inserted.NROCOMPROBANTE INTO @Errados (NRO)
FROM dbo.MCPE E
INNER JOIN @Mov M ON M.NRO = E.NROCOMPROBANTE
WHERE RTRIM(E.ANO) = '2026'
  AND E.MES = 9
  AND RTRIM(E.PROCEDENCIA) = 'INV'
  AND E.FECHACONTABLE >= '20260901'
  AND E.FECHACONTABLE < '20261001'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MCP P WHERE P.NROCOMPROBANTE = E.NROCOMPROBANTE
  );

IF (SELECT COUNT(*) FROM @Errados) <> 16
    THROW 56163, 'No se pasaron los dieciséis comprobantes con error a octubre. No quedó ningún cambio.', 1;

SELECT CNSMOV, 'MOVIMIENTO' AS QUE FROM @Libres
UNION ALL
SELECT CNSMOV, 'MOVIMIENTO' FROM @Enviados
UNION ALL
SELECT NRO, 'ERRADO' FROM @Errados
ORDER BY QUE, CNSMOV;

COMMIT TRAN;
