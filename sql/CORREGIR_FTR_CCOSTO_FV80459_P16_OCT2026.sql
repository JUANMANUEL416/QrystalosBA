/*
  FV80459, comprobante 0653000000212251.

  Una venta del prefijo 16, valor 622.350, está en NO DEF.KMCOM
  y no tiene centro. El detalle de hoy ya no tiene esa línea.
  Reconstruir cambiaría las ventas de la factura, así que este
  script no reconstruye: escribe el centro en la línea del errado.

  El centro y el área salen del encabezado de la factura:
  10040101 y 4115. El modelo de ventas del prefijo 16 tiene
  una sola cuenta para ese par. La función de cuentas debe
  devolver esa misma cuenta. Si no, no cambia nada.

  No toca el diferencial 41950505. Esa línea sigue sin centro.
  No llama a revisar: con el diferencial vacío, revisar podría
  pasar el comprobante a contabilidad.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el centro y la cuenta.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si la línea ya no está en NO DEF.KMCOM, no cambia nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 1;
DECLARE @FACTURA varchar(16) = 'FV80459';
DECLARE @NRO varchar(20) = '0653000000212251';
DECLARE @CCOSTO varchar(20) = '10040101';
DECLARE @IDAREA varchar(20) = '4115';
DECLARE @PREFIJO varchar(6) = '16';
DECLARE @VALOR decimal(14, 2) = 622350.00;
DECLARE @MOD varchar(20) = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE');
DECLARE @PGP int = 2;
DECLARE @CUENTA varchar(20);
DECLARE @SEDE varchar(5);
DECLARE @ANO varchar(4);
DECLARE @MES int;
DECLARE @NROASIENTO int;
DECLARE @FILAS int;

IF EXISTS (
    SELECT 1
    FROM dbo.PPT
    INNER JOIN dbo.FTR
        ON FTR.IDTERCERO = PPT.IDTERCERO
       AND FTR.IDPLAN = PPT.IDPLAN
    WHERE FTR.N_FACTURA = @FACTURA
      AND COALESCE(PPT.PGP, 0) = 1
)
    SET @PGP = 1;

SELECT
    @SEDE = E.IDSEDE,
    @ANO = E.ANO,
    @MES = E.MES
FROM dbo.MCPE E
WHERE E.NROCOMPROBANTE = @NRO
  AND E.NOREFERENCIA = @FACTURA
  AND RTRIM(E.PROCEDENCIA) = 'FACTURA';

IF @ANO IS NULL
    THROW 56200, 'No está el comprobante 0653000000212251 de FV80459.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = @ANO AND MES = @MES AND COALESCE(CERRADO, 0) = 1
)
    THROW 56201, 'El periodo del comprobante está cerrado en contabilidad.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.MCP
    WHERE NROCOMPROBANTE = @NRO
      AND COALESCE(ANULADO, 0) <> 1
)
    THROW 56202, 'El comprobante ya está en contabilidad.', 1;

SELECT @CUENTA = DBO.FNK_NC_CUENTA_KMCOM(
    @MOD, 'VENTAS', 'CR', @PREFIJO,
    DBO.FNK_VALIDA_CCOSTO(@CCOSTO, @SEDE),
    'S', '', @PGP
);

IF (
    SELECT COUNT(*)
    FROM dbo.KMCOM K
    WHERE K.IDMODELOCONT = @MOD
      AND K.IDTIPOCONT = 'VENTAS'
      AND K.TIPO = 'CR'
      AND K.PREFIJO = @PREFIJO
      AND RTRIM(K.CCOSTO) = @CCOSTO
      AND RTRIM(K.IDAREA) = @IDAREA
      AND K.CUENTA = @CUENTA
      AND COALESCE(K.CUENTA, '') <> ''
      AND K.CUENTA NOT LIKE 'NO DEF%'
) <> 1
    THROW 56203, 'El prefijo 16 no tiene una sola cuenta de ventas para 10040101 y 4115.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.CUE WHERE CUENTA = @CUENTA)
    THROW 56204, 'La cuenta que devuelve el modelo no existe.', 1;

SELECT @NROASIENTO = H.NROASIENTO
FROM dbo.MCHE H
WHERE H.NROCOMPROBANTE = @NRO
  AND H.COMPANIA = '01'
  AND H.PROCESO = 'VENTAS'
  AND H.PREFIJO = @PREFIJO
  AND H.TIPO = 'CR'
  AND H.CUENTA LIKE 'NO DEF%'
  AND RTRIM(COALESCE(H.CCOSTO, '')) = ''
  AND RTRIM(COALESCE(H.IDAREA, '')) = ''
  AND H.VALOR = @VALOR;

SET @FILAS = @@ROWCOUNT;

IF @FILAS <> 1
    THROW 56205, 'La venta del prefijo 16 por 622.350 ya no está en NO DEF.KMCOM.', 1;

SELECT
    H.NROASIENTO,
    H.PREFIJO,
    CONVERT(decimal(14, 2), H.VALOR) AS VALOR,
    H.CUENTA AS CUENTA_HOY,
    @CCOSTO AS CCOSTO_NUEVO,
    @IDAREA AS AREA_NUEVA,
    @CUENTA AS CUENTA_NUEVA,
    H.IDTERCERO,
    H.ERROR
FROM dbo.MCHE H
WHERE H.NROCOMPROBANTE = @NRO
  AND H.NROASIENTO = @NROASIENTO;

IF @APLICAR = 0
    RETURN;

UPDATE dbo.MCHE
SET CCOSTO = @CCOSTO,
    IDAREA = @IDAREA,
    CUENTA = @CUENTA,
    ERROR = NULL
WHERE NROCOMPROBANTE = @NRO
  AND NROASIENTO = @NROASIENTO
  AND COMPANIA = '01'
  AND PROCESO = 'VENTAS'
  AND PREFIJO = @PREFIJO
  AND TIPO = 'CR'
  AND CUENTA LIKE 'NO DEF%'
  AND RTRIM(COALESCE(CCOSTO, '')) = ''
  AND VALOR = @VALOR;

IF @@ROWCOUNT <> 1
    THROW 56206, 'No se actualizó la línea de 622.350.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.MCHE
    WHERE NROCOMPROBANTE = @NRO
      AND NROASIENTO = @NROASIENTO
      AND (
          RTRIM(COALESCE(CCOSTO, '')) <> @CCOSTO
          OR RTRIM(COALESCE(IDAREA, '')) <> @IDAREA
          OR CUENTA <> @CUENTA
          OR CUENTA LIKE 'NO DEF%'
      )
)
    THROW 56207, 'La línea quedó distinta del centro 10040101 y la cuenta del modelo.', 1;
