/*
  CEM — FEVM716822, Depósito de Drogas Mónaco.
  Solo la cuenta por pagar 25CM000191. No toca la entrada ni existencias.

  La factura trae 10 cajas de trazodona 50 mg (500 tabletas):
    precio bruto 19.845,38
    descuento 18,58 % = 36.872,72
    total 161.581,08
    sin IVA

  La cuenta tiene 500 × 325,16 = 162.580,00.
  La diferencia es 998,92 (el reporte la vio como 999).
  El precio neto por tableta es 323,162160.
  500 × 323,162160 = 161.581,08.

  El neto, el saldo y el valor de la cabecera bajan a 161.581,08.
  La cuenta del artículo sigue en excluidos. No hay retención ni IVA.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si algo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @CNS varchar(20) = N'25CM000191';
DECLARE @NETO decimal(14, 2) = 161581.08;

SELECT
  P.NOREFERENCIA,
  D.IDSERVICIO,
  CONVERT(decimal(18, 2), D.CANTIDAD) AS CANT,
  CONVERT(decimal(18, 6), D.VALOR) AS PRECIO_HOY,
  CONVERT(decimal(18, 6), 323.162160) AS PRECIO_OK,
  CONVERT(decimal(18, 2), D.VLR_NETO) AS NETO_HOY,
  @NETO AS NETO_OK,
  CONVERT(decimal(18, 2), D.VLR_NETO - @NETO) AS DIFERENCIA
FROM dbo.FCXP P
INNER JOIN dbo.FCXPD D ON D.CNSFCXP = P.CNSFCXP
WHERE P.CNSFCXP = @CNS;

IF @APLICAR = 0
  RETURN;

BEGIN TRAN;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.FCXP
  WHERE CNSFCXP = @CNS
    AND NOREFERENCIA = N'FEVM716822'
    AND ESTADO = N'N'
    AND COALESCE(CONTABILIZADA, 0) = 0
    AND COALESCE(RTRIM(NROCOMPROBANTE), N'') = N''
    AND VLR_NETO = 162580.00
    AND SALDO = 162580.00
    AND COALESCE(VLR_IVA, 0) = 0
    AND COALESCE(VLR_IMPUESTOS, 0) = 0
)
BEGIN
  ROLLBACK TRAN;
  THROW 56080, 'FEVM716822 ya no está libre o el neto ya no es 162.580.', 1;
END;

IF (
  SELECT COUNT(*)
  FROM dbo.FCXPD
  WHERE CNSFCXP = @CNS
    AND IDSERVICIO = N'MXC0063-2'
    AND CANTIDAD = 500
    AND VLR_NETO = 162580.00
    AND COALESCE(VLR_IVA, 0) = 0
) <> 1
   OR (SELECT COUNT(*) FROM dbo.FCXPD WHERE CNSFCXP = @CNS) <> 1
BEGIN
  ROLLBACK TRAN;
  THROW 56081, 'La línea de trazodona ya no está como se esperaba.', 1;
END;

UPDATE dbo.FCXPD
SET VALOR = 323.162160,
    VLR_NETO = @NETO,
    VLR_DESCUENTO = 0,
    VLR_IVA = 0
WHERE CNSFCXP = @CNS
  AND IDSERVICIO = N'MXC0063-2'
  AND CANTIDAD = 500;

UPDATE dbo.FCXP
SET VALOR = @NETO,
    VLR_NETO = @NETO,
    SALDO = @NETO
WHERE CNSFCXP = @CNS
  AND SALDO = VLR_NETO;

IF EXISTS (
  SELECT 1
  FROM dbo.FCXP P
  INNER JOIN dbo.FCXPD D ON D.CNSFCXP = P.CNSFCXP
  WHERE P.CNSFCXP = @CNS
    AND (
      ABS(ROUND(D.CANTIDAD * D.VALOR, 2) - @NETO) > 0.02
      OR ABS(D.VLR_NETO - @NETO) > 0.02
      OR ABS(P.VLR_NETO - @NETO) > 0.02
      OR ABS(P.SALDO - @NETO) > 0.02
      OR ABS(P.VALOR - @NETO) > 0.02
    )
)
BEGIN
  ROLLBACK TRAN;
  THROW 56082, 'El neto no quedó en 161.581,08.', 1;
END;

COMMIT TRAN;

SELECT
  P.NOREFERENCIA,
  CONVERT(decimal(18, 2), P.VLR_NETO) AS NETO,
  CONVERT(decimal(18, 2), P.SALDO) AS SALDO,
  D.IDSERVICIO,
  CONVERT(decimal(18, 2), D.CANTIDAD) AS CANT,
  CONVERT(decimal(18, 6), D.VALOR) AS PRECIO,
  CONVERT(decimal(18, 2), D.VLR_NETO) AS NETO_LINEA
FROM dbo.FCXP P
INNER JOIN dbo.FCXPD D ON D.CNSFCXP = P.CNSFCXP
WHERE P.CNSFCXP = @CNS;
