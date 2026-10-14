/*
  CEM — Crédito del encabezado en la nota de devolución 26CM000529.

  La nota es de inventario, del 6 de octubre, por 165.600, sin contabilizar.
  El detalle ya tiene MX1207-1 en 14150591 (devolución de medicamentos excluidos).
  El crédito del encabezado está vacío, y en pantalla se presta a confusión.

  Solo llena CUENTA_CR con la cuenta del detalle. No toca valores, saldo,
  entrada ni existencias. Si el crédito ya está en 14150591, no la vuelve a tocar.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si algo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @CNS varchar(20) = N'26CM000529';
DECLARE @ITEM int = 1;
DECLARE @CTA varchar(20) = N'14150591';

SELECT
  N.CNSFCXP,
  CONVERT(date, N.FECHA) AS FECHA,
  N.PROCEDENCIA,
  N.CONTABILIZADA,
  N.CUENTA_DB,
  COALESCE(NULLIF(RTRIM(N.CUENTA_CR), N''), N'(vacia)') AS CREDITO_HOY,
  D.IDSERVICIO,
  D.CTA_SER AS CREDITO_QUEDA,
  CONVERT(decimal(18, 2), N.VLR_NETO) AS NETO_NOTA,
  CONVERT(decimal(18, 2), D.VLR_NETO) AS NETO_LINEA
FROM dbo.FCXPDBCR N
INNER JOIN dbo.FCXPDNOT D
  ON D.CNSFCXP = N.CNSFCXP
 AND D.ITEM_DBCR = N.ITEM
WHERE N.CNSFCXP = @CNS
  AND N.ITEM = @ITEM;

IF @APLICAR = 0
  RETURN;

BEGIN TRAN;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.FCXPDBCR N
  WHERE N.CNSFCXP = @CNS
    AND N.ITEM = @ITEM
    AND N.PROCEDENCIA = N'INV'
    AND N.ESTADO = N'N'
    AND COALESCE(N.CONTABILIZADA, 0) = 0
    AND COALESCE(RTRIM(N.NROCOMPROBANTE), N'') = N''
    AND N.CUENTA_DB = N'22050101'
    AND COALESCE(RTRIM(N.CUENTA_CR), N'') = N''
    AND N.VLR_NETO = 165600.00
)
BEGIN
  ROLLBACK TRAN;
  THROW 56060, 'La nota 26CM000529 ya no está libre o el crédito ya no está vacío.', 1;
END;

IF (
  SELECT COUNT(*)
  FROM dbo.FCXPDNOT
  WHERE CNSFCXP = @CNS
    AND ITEM_DBCR = @ITEM
    AND IDSERVICIO = N'MX1207-1'
    AND CTA_SER = @CTA
    AND COALESCE(VLR_IVA, 0) = 0
    AND VLR_NETO = 165600.00
) <> 1
   OR (
  SELECT COUNT(*) FROM dbo.FCXPDNOT WHERE CNSFCXP = @CNS AND ITEM_DBCR = @ITEM
) <> 1
BEGIN
  ROLLBACK TRAN;
  THROW 56061, 'El detalle de 26CM000529 no es la línea esperada en 14150591.', 1;
END;

UPDATE dbo.FCXPDBCR
SET CUENTA_CR = @CTA
WHERE CNSFCXP = @CNS
  AND ITEM = @ITEM
  AND COALESCE(CONTABILIZADA, 0) = 0
  AND COALESCE(RTRIM(CUENTA_CR), N'') = N'';

IF @@ROWCOUNT <> 1
BEGIN
  ROLLBACK TRAN;
  THROW 56062, 'No se actualizó el crédito del encabezado.', 1;
END;

COMMIT TRAN;

SELECT
  N.CNSFCXP,
  N.CUENTA_DB,
  N.CUENTA_CR,
  CONVERT(decimal(18, 2), N.VLR_NETO) AS NETO,
  N.CONTABILIZADA,
  D.IDSERVICIO,
  D.CTA_SER
FROM dbo.FCXPDBCR N
INNER JOIN dbo.FCXPDNOT D
  ON D.CNSFCXP = N.CNSFCXP
 AND D.ITEM_DBCR = N.ITEM
WHERE N.CNSFCXP = @CNS
  AND N.ITEM = @ITEM;
