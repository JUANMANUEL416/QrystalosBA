/*
  128 dispensaciones tipo 06 con comprobante en error, periodo de octubre
  y fecha de confirmación en septiembre. La línea quedó sin centro y con
  cuenta NO DEF.KMCOM. El centro del movimiento, o el de la bodega cuando
  el movimiento no lo tiene, sí tiene cuenta de inventario del prefijo 06:
  débito 61350502 y crédito 14150502.

  En 19 movimientos el centro está vacío. Se copia el de la bodega.
  Luego se reconstruye el mismo comprobante con fecha 1 de octubre, porque
  septiembre ya está cerrado y la confirmación sigue en septiembre.

  No cambia cantidades ni costos. Si alguna entrega tiene valor antes de
  IVA en cero, no hace nada: reconstruir esa entrega sí cambiaría el costo.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise centros y cuentas.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si ya no son 128, no cambia nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @PC varchar(254) = 'CONTABILIDAD';
DECLARE @MOD varchar(20) = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE');
DECLARE @FECHA date = '20261001';

IF OBJECT_ID('tempdb..#Mov') IS NOT NULL DROP TABLE #Mov;

IF COALESCE(DBO.FNK_VALORVARIABLE('IDCON_IMOVDBENT_COMP'), '') <> 'MOV_INVENTARIO'
    THROW 56230, 'La contabilización de la salida no está en MOV_INVENTARIO.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO, 0) = 1
)
    THROW 56231, 'Octubre de 2026 está cerrado en contabilidad.', 1;

SELECT
    I.CNSMOV,
    P.NROCOMPROBANTE,
    P.COMPANIA,
    P.IDSEDE,
    LEFT(P.USUARIO, 12) AS USUARIO,
    RTRIM(I.IDBODEGA) AS IDBODEGA,
    CASE WHEN COALESCE(RTRIM(I.CCOSTO), '') = '' THEN 1 ELSE 0 END AS LLENAR,
    COALESCE(NULLIF(RTRIM(I.CCOSTO), ''), RTRIM(B.CCOSTO)) AS CCOSTO,
    COALESCE(NULLIF(RTRIM(I.IDAREA), ''), RTRIM(B.IDAREA)) AS IDAREA
INTO #Mov
FROM dbo.MCPE P
INNER JOIN dbo.IMOV I ON I.CNSMOV = P.REFERENCIA1
LEFT JOIN dbo.IBOD B ON B.IDBODEGA = I.IDBODEGA
WHERE P.ANO = 2026 AND P.MES = 10 AND P.ESTADO = 0
  AND RTRIM(P.PROCEDENCIA) = 'INV'
  AND COALESCE(P.ANULADO, 0) <> 1
  AND I.IDTIPOMOV = '06'
  AND YEAR(I.FECHACONF) = 2026 AND MONTH(I.FECHACONF) = 9
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MCP L
      WHERE L.NROCOMPROBANTE = P.NROCOMPROBANTE AND COALESCE(L.ANULADO, 0) <> 1
  );

SELECT IDBODEGA, LLENAR, CCOSTO, IDAREA, COUNT(*) AS MOVIMIENTOS,
       DBO.FNK_NC_CUENTA_KMCOM(@MOD, 'MOV_INVENTARIO', 'DB', '06', CCOSTO, 'P', '01', 0) AS CUENTA_DB,
       DBO.FNK_NC_CUENTA_KMCOM(@MOD, 'MOV_INVENTARIO', 'CR', '06', CCOSTO, 'P', '01', 0) AS CUENTA_CR
FROM #Mov
GROUP BY IDBODEGA, LLENAR, CCOSTO, IDAREA
ORDER BY IDBODEGA, LLENAR;

IF @APLICAR = 0
    RETURN;

IF (SELECT COUNT(*) FROM #Mov) <> 128
    THROW 56232, 'Ya no son 128 dispensaciones. No quedó ningún cambio.', 1;
IF (SELECT COUNT(*) FROM #Mov WHERE LLENAR = 1) <> 19
    THROW 56233, 'Ya no son 19 movimientos sin centro. No quedó ningún cambio.', 1;
IF EXISTS (SELECT 1 FROM #Mov WHERE COALESCE(CCOSTO, '') = '' OR COALESCE(IDAREA, '') = '' OR COALESCE(USUARIO, '') = '')
    THROW 56234, 'Falta centro, área o usuario. No quedó ningún cambio.', 1;
IF EXISTS (
    SELECT 1 FROM #Mov M
    WHERE DBO.FNK_NC_CUENTA_KMCOM(@MOD, 'MOV_INVENTARIO', 'DB', '06', M.CCOSTO, 'P', '01', 0) LIKE 'NO DEF%'
       OR DBO.FNK_NC_CUENTA_KMCOM(@MOD, 'MOV_INVENTARIO', 'CR', '06', M.CCOSTO, 'P', '01', 0) LIKE 'NO DEF%'
)
    THROW 56235, 'El centro no tiene cuenta de inventario del prefijo 06. No quedó ningún cambio.', 1;
IF EXISTS (
    SELECT 1
    FROM #Mov M
    INNER JOIN dbo.ISAL S ON S.CNSMOV = M.CNSMOV
    WHERE COALESCE(S.VR_ANTESIVA, 0) <= 0
)
    THROW 56236, 'Hay una entrega con costo en cero. Reconstruir la cambiaría. No quedó ningún cambio.', 1;

BEGIN TRAN;

UPDATE I
SET CCOSTO = M.CCOSTO, IDAREA = M.IDAREA
FROM dbo.IMOV I
INNER JOIN #Mov M ON M.CNSMOV = I.CNSMOV
WHERE M.LLENAR = 1
  AND COALESCE(RTRIM(I.CCOSTO), '') = ''
  AND COALESCE(RTRIM(I.IDAREA), '') = '';

IF @@ROWCOUNT <> 19
BEGIN
    ROLLBACK TRAN;
    THROW 56237, 'No se completó el centro de los 19 movimientos. No quedó ningún cambio.', 1;
END

COMMIT TRAN;

DECLARE @CNS varchar(20), @NRO varchar(20), @USU varchar(12);
DECLARE @CIA varchar(2), @SEDE varchar(5), @Msg nvarchar(240);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT CNSMOV, NROCOMPROBANTE, USUARIO, COMPANIA, IDSEDE
    FROM #Mov
    ORDER BY CNSMOV;

OPEN c;
FETCH NEXT FROM c INTO @CNS, @NRO, @USU, @CIA, @SEDE;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.SPK_NC_CONTAB_INV @CNS, @USU, @PC, @CIA, @SEDE, @NRO OUTPUT, 0, @FECHA;

    IF EXISTS (
        SELECT 1 FROM dbo.MCHE H
        WHERE H.NROCOMPROBANTE = @NRO
          AND (H.CUENTA LIKE 'NO DEF%' OR H.ERROR LIKE 'El valor del Registro es cero%')
    )
    BEGIN
        CLOSE c;
        DEALLOCATE c;
        SET @Msg = N'El movimiento ' + @CNS + N' siguió con error. Los anteriores de la lista sí se reconstruyeron.';
        THROW 56238, @Msg, 1;
    END

    FETCH NEXT FROM c INTO @CNS, @NRO, @USU, @CIA, @SEDE;
END

CLOSE c;
DEALLOCATE c;

SELECT 'LISTO' AS GRUPO, COUNT(*) AS MOVIMIENTOS FROM #Mov;
