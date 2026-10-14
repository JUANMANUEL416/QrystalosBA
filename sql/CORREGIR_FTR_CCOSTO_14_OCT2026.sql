/*
  Corrige 14 facturas de consulta externa que están en comprobantes
  con error de octubre. La venta quedó en NO DEF.KMCOM porque el detalle
  no trae centro ni área.

  El centro sale de la dispensación confirmada de esa autorización,
  y ese prefijo + centro + área sí está en el modelo de ventas.
  Se copia al detalle y a la autorización, y se reconstruye el mismo
  comprobante con SPK_NC_CONTAB_FTR.

  No entran las otras facturas de este error:
    13 tienen dispensación, pero esa combinación no está en el modelo.
    533 no tienen dispensación de donde tomar el centro.
    FV80459 es financiera y no es este caso.

  No cambia cantidades ni valores.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el listado.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si alguna no cumple, no cambia el detalle ni la autorización.
       La reconstrucción va después, factura por factura.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;
DECLARE @COMPANIA varchar(2) = '01';
DECLARE @SEDE varchar(5) = '06';
DECLARE @PC varchar(254) = 'CONTABILIDAD';
DECLARE @MOD varchar(20) = DBO.FNK_VALORVARIABLE('IDMODELOCONTABLE');

DECLARE @Fac TABLE (
    N_FACTURA varchar(16) NOT NULL PRIMARY KEY,
    NROCOMPROBANTE varchar(20) NOT NULL,
    USUARIO varchar(12) NOT NULL,
    CCOSTO varchar(20) NOT NULL,
    IDAREA varchar(20) NOT NULL,
    CNSMOV varchar(20) NOT NULL
);

INSERT INTO @Fac (N_FACTURA, NROCOMPROBANTE, USUARIO, CCOSTO, IDAREA, CNSMOV) VALUES
    ('FV80450', '0669000000212501', '1035868272', '10330202', '4110', '330000000302'),
    ('FV80489', '0674000000212528', '1048020866', '10220202', '4110', '340000006389'),
    ('FV80746', '0677000000212794', '1022092291', '10220202', '4110', '340000005519'),
    ('FV80998', '0657000000213638', '1000399790', '10220202', '4110', '340000005693'),
    ('FV81018', '0657000000213640', '1000399790', '10220202', '4110', '340000005489'),
    ('FV81057', '0657000000213652', '1000399790', '10290202', '4110', '340000005488'),
    ('FV81273', '0657000000213706', '1018240203', '10340202', '4110', '350000000205'),
    ('FV81471', '0659000000214151', '1015069262', '10220202', '4110', '330000003599'),
    ('FV81567', '0659000000214371', '1048020866', '10220202', '4110', '330000003591'),
    ('FV81570', '0659000000214374', '1048020866', '10220202', '4110', '330000003603'),
    ('FV81652', '0657000000214454', '1048020866', '10340202', '4110', '350000005591'),
    ('FV81706', '0657000000214507', '1192898941', '10330202', '4110', '330000000373'),
    ('FV81716', '0659000000214517', '1192898941', '10340202', '4110', '350000000191'),
    ('FV81849', '0657000000214650', '1015069262', '10320202', '4110', '340000005480');

IF EXISTS (
    SELECT 1 FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 10 AND COALESCE(CERRADO, 0) = 1
)
    THROW 56170, 'Octubre de 2026 está cerrado en contabilidad.', 1;

SELECT
    M.N_FACTURA,
    M.NROCOMPROBANTE,
    M.CNSMOV,
    M.CCOSTO,
    M.IDAREA,
    K.CUENTA AS CUENTA_VENTA
FROM @Fac M
INNER JOIN dbo.FTR F ON F.N_FACTURA = M.N_FACTURA
INNER JOIN dbo.FTRD D ON D.CNSFTR = F.CNSFCT
INNER JOIN dbo.KMCOM K
    ON K.IDMODELOCONT = @MOD
   AND K.IDTIPOCONT = 'VENTAS'
   AND K.TIPO = 'CR'
   AND K.PREFIJO = D.PREFIJO
   AND K.CCOSTO = M.CCOSTO
   AND K.IDAREA = M.IDAREA
   AND COALESCE(K.CUENTA, '') <> ''
   AND K.CUENTA NOT LIKE 'NO DEF%'
ORDER BY M.N_FACTURA;

IF @APLICAR = 0
    RETURN;

IF (
    SELECT COUNT(*)
    FROM @Fac M
    INNER JOIN dbo.FTR F ON F.N_FACTURA = M.N_FACTURA
    INNER JOIN dbo.FTRD D ON D.CNSFTR = F.CNSFCT
    INNER JOIN dbo.AUT A ON A.NOAUT = D.NOADMISION AND A.CNSMOV = M.CNSMOV
    INNER JOIN dbo.MCPE E
        ON E.NROCOMPROBANTE = M.NROCOMPROBANTE
       AND E.NOREFERENCIA = F.N_FACTURA
       AND RTRIM(E.PROCEDENCIA) = 'FACTURA'
       AND E.COMPANIA = @COMPANIA
       AND E.IDSEDE = @SEDE
    WHERE F.PROCEDENCIA = 'CE'
      AND COALESCE(F.ESTADO, '') <> 'A'
      AND COALESCE(F.CONTABILIZADA, 0) = 2
      AND F.NROCOMPROBANTE = M.NROCOMPROBANTE
      AND F.F_FACTURA >= '20261001'
      AND F.F_FACTURA < '20261101'
      AND COALESCE(D.CCOSTO, '') = ''
      AND COALESCE(D.AREAPRESTACION, '') = ''
      AND COALESCE(A.CCOSTO, '') = ''
      AND COALESCE(A.IDAREA, '') = ''
      AND (
          SELECT COUNT(*) FROM dbo.FTRD X WHERE X.CNSFTR = F.CNSFCT
      ) = 1
      AND (
          SELECT COUNT(DISTINCT I.CCOSTO + '|' + I.IDAREA)
          FROM dbo.IMOV I
          WHERE I.NODOCUMENTO = A.CNSMOV
            AND COALESCE(I.ESTADO, 0) = 1
            AND COALESCE(I.CCOSTO, '') <> ''
            AND COALESCE(I.IDAREA, '') <> ''
      ) = 1
      AND EXISTS (
          SELECT 1 FROM dbo.IMOV I
          WHERE I.NODOCUMENTO = A.CNSMOV
            AND COALESCE(I.ESTADO, 0) = 1
            AND I.CCOSTO = M.CCOSTO
            AND I.IDAREA = M.IDAREA
      )
      AND (
          SELECT COUNT(*)
          FROM dbo.KMCOM K
          WHERE K.IDMODELOCONT = @MOD
            AND K.IDTIPOCONT = 'VENTAS'
            AND K.TIPO = 'CR'
            AND K.PREFIJO = D.PREFIJO
            AND K.CCOSTO = M.CCOSTO
            AND K.IDAREA = M.IDAREA
            AND COALESCE(K.CUENTA, '') <> ''
            AND K.CUENTA NOT LIKE 'NO DEF%'
      ) = 1
      AND NOT EXISTS (
          SELECT 1 FROM dbo.MCP P
          WHERE P.NROCOMPROBANTE = M.NROCOMPROBANTE
            AND COALESCE(P.ANULADO, 0) <> 1
      )
      AND (
          DBO.FNK_VALORVARIABLE('CONTAB_FTR_POSTDIAN') <> 'SI'
          OR COALESCE(F.FACTE, 0) = 2
      )
) <> 14
    THROW 56171, 'No están las catorce facturas libres para corregir. No quedó ningún cambio.', 1;

BEGIN TRAN;

DECLARE @Det TABLE (N_FACTURA varchar(16));
DECLARE @Aut TABLE (NOAUT varchar(20));

UPDATE D
SET CCOSTO = M.CCOSTO,
    AREAPRESTACION = M.IDAREA
OUTPUT inserted.N_FACTURA INTO @Det (N_FACTURA)
FROM dbo.FTRD D
INNER JOIN dbo.FTR F ON F.CNSFCT = D.CNSFTR
INNER JOIN @Fac M ON M.N_FACTURA = F.N_FACTURA
WHERE COALESCE(D.CCOSTO, '') = ''
  AND COALESCE(D.AREAPRESTACION, '') = ''
  AND (
      SELECT COUNT(*) FROM dbo.FTRD X WHERE X.CNSFTR = F.CNSFCT
  ) = 1;

IF (SELECT COUNT(*) FROM @Det) <> 14
    THROW 56172, 'No se actualizó el detalle de las catorce facturas. No quedó ningún cambio.', 1;

UPDATE A
SET CCOSTO = M.CCOSTO,
    IDAREA = M.IDAREA
OUTPUT inserted.NOAUT INTO @Aut (NOAUT)
FROM dbo.AUT A
INNER JOIN dbo.FTRD D ON D.NOADMISION = A.NOAUT
INNER JOIN dbo.FTR F ON F.CNSFCT = D.CNSFTR
INNER JOIN @Fac M ON M.N_FACTURA = F.N_FACTURA AND M.CNSMOV = A.CNSMOV
WHERE COALESCE(A.CCOSTO, '') = ''
  AND COALESCE(A.IDAREA, '') = '';

IF (SELECT COUNT(*) FROM @Aut) <> 14
    THROW 56173, 'No se actualizó la autorización de las catorce facturas. No quedó ningún cambio.', 1;

COMMIT TRAN;

DECLARE @NF varchar(16), @NRO varchar(20), @USU varchar(12), @Msg nvarchar(240);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT N_FACTURA, NROCOMPROBANTE, USUARIO
    FROM @Fac
    ORDER BY N_FACTURA;

OPEN c;
FETCH NEXT FROM c INTO @NF, @NRO, @USU;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.SPK_NC_CONTAB_FTR
        @NF, @COMPANIA, @USU, @PC, @SEDE, @NRO;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.FTR
        WHERE N_FACTURA = @NF
          AND COALESCE(CONTABILIZADA, 0) = 1
    )
    OR EXISTS (
        SELECT 1
        FROM dbo.MCHE H
        WHERE H.NROCOMPROBANTE = @NRO
          AND H.CUENTA LIKE 'NO DEF%'
    )
    BEGIN
        CLOSE c;
        DEALLOCATE c;
        SET @Msg = N'La factura ' + @NF + N' no quedó contabilizada. Las anteriores de la lista sí se reconstruyeron.';
        THROW 56174, @Msg, 1;
    END

    FETCH NEXT FROM c INTO @NF, @NRO, @USU;
END

CLOSE c;
DEALLOCATE c;

SELECT F.N_FACTURA, F.CONTABILIZADA, F.NROCOMPROBANTE, D.CCOSTO, D.AREAPRESTACION
FROM @Fac M
INNER JOIN dbo.FTR F ON F.N_FACTURA = M.N_FACTURA
INNER JOIN dbo.FTRD D ON D.CNSFTR = F.CNSFCT
ORDER BY F.N_FACTURA;
