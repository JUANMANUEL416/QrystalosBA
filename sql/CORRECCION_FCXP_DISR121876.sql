/*
  CEM — DISR121876, lote de la bolsa sin cuenta.
  La cuenta por pagar 34CM000179 ya está contabilizada
  (comprobante 0659000000213440). No se modifica.

  Las dos líneas de la cuenta tienen 14200502 y así pasaron al comprobante.
  El lote 34L00000272 de la bolsa DM0523-1 no tiene cuenta en las bodegas
  044, 052, 077 y 079.
  La pasta del mismo tipo, sin IVA, usa débito 14200502 y crédito 14200591.
  Se copia ese par solo donde la cuenta está vacía.
  No se cambia existencia, cantidad ni costo.
  La diferencia de 96 pesos contra la factura queda en el comprobante.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si algo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;

SELECT
  E.IDARTICULO,
  E.IDBODEGA,
  E.NOLOTE,
  CONVERT(decimal(18, 2), E.EXISLOTE) AS EXISTENCIA,
  COALESCE(E.CUEDEBITO, N'') AS DEBITO_HOY,
  N'14200502' AS DEBITO_OK,
  COALESCE(E.CUECREDITO, N'') AS CREDITO_HOY,
  N'14200591' AS CREDITO_OK
FROM dbo.IEXI E
WHERE E.IDARTICULO = N'DM0523-1'
  AND E.NOLOTE = N'34L00000272'
ORDER BY E.IDBODEGA;

IF @APLICAR = 0
  RETURN;

BEGIN TRAN;

DECLARE @lot TABLE (IDBODEGA varchar(20));

IF NOT EXISTS (
  SELECT 1
  FROM dbo.FCXP
  WHERE CNSFCXP = N'34CM000179'
    AND NOREFERENCIA = N'DISR121876'
    AND COALESCE(CONTABILIZADA, 0) = 1
    AND RTRIM(NROCOMPROBANTE) = N'0659000000213440'
)
BEGIN
  ROLLBACK TRAN;
  THROW 56120, 'DISR121876 ya no está contabilizada con el comprobante 0659000000213440.', 1;
END;

UPDATE dbo.IEXI
SET CUEDEBITO = N'14200502',
    CUECREDITO = N'14200591'
OUTPUT inserted.IDBODEGA INTO @lot
WHERE IDARTICULO = N'DM0523-1'
  AND NOLOTE = N'34L00000272'
  AND COALESCE(CUEDEBITO, N'') = N''
  AND COALESCE(CUECREDITO, N'') = N''
  AND COALESCE(CUENTAIVA, N'') = N'';

IF (SELECT COUNT(*) FROM @lot) <> 4
BEGIN
  ROLLBACK TRAN;
  THROW 56121, 'El lote de la bolsa ya no tiene las cuatro bodegas sin cuenta.', 1;
END;

IF EXISTS (
  SELECT 1
  FROM dbo.IEXI
  WHERE IDARTICULO = N'DM0523-1'
    AND NOLOTE = N'34L00000272'
    AND (COALESCE(CUEDEBITO, N'') <> N'14200502' OR COALESCE(CUECREDITO, N'') <> N'14200591')
)
BEGIN
  ROLLBACK TRAN;
  THROW 56122, 'La cuenta del lote no quedó en 14200502 y 14200591.', 1;
END;

COMMIT TRAN;

SELECT
  E.IDBODEGA,
  COALESCE(E.CUEDEBITO, N'') AS DEBITO,
  COALESCE(E.CUECREDITO, N'') AS CREDITO,
  CONVERT(decimal(18, 2), E.EXISLOTE) AS EXISTENCIA
FROM dbo.IEXI E
WHERE E.IDARTICULO = N'DM0523-1'
  AND E.NOLOTE = N'34L00000272'
ORDER BY E.IDBODEGA;
