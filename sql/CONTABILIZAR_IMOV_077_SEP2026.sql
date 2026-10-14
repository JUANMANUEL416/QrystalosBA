/*
  Envía a contabilidad cuatro dispensaciones que el precierre
  marca como confirmadas y sin contabilizar:

    3400017677  solicitud 340000014602  21/09/2026
    3400017680  solicitud 340000014604  26/09/2026
    3400017686  solicitud 340000014608  26/09/2026
    3400017697  solicitud 340000014616  26/09/2026

  Bodega 077. No tienen comprobante ni están en comprobantes con error,
  porque nunca se enviaron. La cabecera no tiene centro de costo ni área.
  La fórmula (AUTE / CEFM) de las cuatro trae 10320202 y 4110, el mismo
  centro de la bodega. El script lo copia y llama SPK_NC_CONTAB_INV,
  el mismo procedimiento del envío de inventario.

  No cambia cantidades, costos ni lotes.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si el centro no es único o alguno no queda contabilizado, hace ROLLBACK.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @COMPANIA varchar(2) = '01';
DECLARE @SEDE varchar(5) = '01';
DECLARE @PC varchar(254) = 'CONTABILIDAD';

DECLARE @Movs TABLE (
    CNSMOV varchar(20) PRIMARY KEY,
    SOLICITUD varchar(20),
    USUARIO varchar(20),
    CCOSTO varchar(20),
    IDAREA varchar(20)
);

INSERT INTO @Movs (CNSMOV, SOLICITUD, USUARIO, CCOSTO, IDAREA)
SELECT
    I.CNSMOV,
    I.NODOCUMENTO,
    I.USUARIOCONF,
    MIN(F.CCOSTO),
    MIN(F.IDAREA)
FROM dbo.IMOV I
INNER JOIN dbo.AUTE E ON E.CNSIZSOL = I.NODOCUMENTO
INNER JOIN dbo.CEFM F ON F.CNSCEFM = E.CNSCEFM
WHERE I.CNSMOV IN ('3400017677', '3400017680', '3400017686', '3400017697')
  AND COALESCE(I.ESTADO, 0) = 1
  AND COALESCE(I.CONTABILIZADA, 0) = 0
  AND COALESCE(I.NROCOMPROBANTE, '') = ''
  AND COALESCE(I.CCOSTO, '') = ''
  AND COALESCE(F.CCOSTO, '') <> ''
  AND COALESCE(F.IDAREA, '') <> ''
GROUP BY I.CNSMOV, I.NODOCUMENTO, I.USUARIOCONF
HAVING COUNT(DISTINCT F.CCOSTO) = 1
   AND COUNT(DISTINCT F.IDAREA) = 1;

SELECT
    M.CNSMOV,
    M.SOLICITUD,
    M.USUARIO,
    M.CCOSTO,
    M.IDAREA,
    CONVERT(varchar(10), I.FECHACONF, 103) AS FECHA_CONF
FROM @Movs M
INNER JOIN dbo.IMOV I ON I.CNSMOV = M.CNSMOV
ORDER BY M.CNSMOV;

IF (SELECT COUNT(*) FROM @Movs) <> 4
    THROW 56140, 'No están los cuatro movimientos libres, o la fórmula no tiene un solo centro de costo.', 1;

IF @APLICAR = 0
    RETURN;

BEGIN TRAN;

UPDATE I
SET I.CCOSTO = M.CCOSTO,
    I.IDAREA = M.IDAREA
FROM dbo.IMOV I
INNER JOIN @Movs M ON M.CNSMOV = I.CNSMOV
WHERE COALESCE(I.ESTADO, 0) = 1
  AND COALESCE(I.CONTABILIZADA, 0) = 0
  AND COALESCE(I.NROCOMPROBANTE, '') = ''
  AND COALESCE(I.CCOSTO, '') = '';

IF @@ROWCOUNT <> 4
    THROW 56141, 'No se pudo completar el centro de costo en los cuatro movimientos.', 1;

DECLARE @CNS varchar(20), @USU varchar(20), @NRO varchar(20);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT CNSMOV, USUARIO FROM @Movs ORDER BY CNSMOV;

OPEN cur;
FETCH NEXT FROM cur INTO @CNS, @USU;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @NRO = NULL;
    EXEC dbo.SPK_NC_CONTAB_INV
        @CNSMOV = @CNS,
        @USUARIO = @USU,
        @SYS_COMPUTERNAME = @PC,
        @COMPANIA = @COMPANIA,
        @SEDE = @SEDE,
        @NROCOMPROBANTE = @NRO OUTPUT;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.IMOV
        WHERE CNSMOV = @CNS
          AND COALESCE(CONTABILIZADA, 0) = 1
          AND COALESCE(NROCOMPROBANTE, '') <> ''
    )
        THROW 56142, 'Un movimiento no quedó contabilizado. Se reversa el envío.', 1;

    FETCH NEXT FROM cur INTO @CNS, @USU;
END
CLOSE cur;
DEALLOCATE cur;

SELECT CNSMOV, CCOSTO, IDAREA, CONTABILIZADA, NROCOMPROBANTE
FROM dbo.IMOV
WHERE CNSMOV IN ('3400017677', '3400017680', '3400017686', '3400017697')
ORDER BY CNSMOV;

COMMIT TRAN;
