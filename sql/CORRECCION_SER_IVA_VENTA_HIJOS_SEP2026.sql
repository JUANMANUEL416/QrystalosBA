/*
  CEM — marcar IVA de venta en el servicio del hijo
  que entró con IVA en septiembre 2026 y hoy no factura IVA.

  El servicio es SER.IDSERVICIO = código del artículo (INS0058-1),
  no el padre IART.IDSERVICIO.

  Qué deja en SER:
    IVA = 'SER'
    IDIMPUESTO = 'IVA'
    IDCLASE = '02'   (IVA - VENTAS MEDICAMENTOS E INSUMOS, 19 %)

  Esa es la clase que usan los servicios que ya facturan IVA.
  La factura (SPK_FACTURACE_N) cobra el impuesto solo cuando SER.IVA = 'SER'.

  Qué no hace:
    No activa servicios Inactivo.
    No toca los 100 hijos que ya tienen IVA = 'SER'.
    No mueve entradas, existencias ni cuentas por pagar.
    No rehace facturas ya hechas. El cambio vale para la facturación siguiente.
    No marca los cuatro servicios cuya entrada no es 19 %
    (quedan en el listado de revisión).

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise los dos listados.
    2. Ponga @APLICAR = 1 y vuelva a ejecutar.
       Si el conteo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR bit = 0;   -- 0 = solo muestra; 1 = actualiza SER

DECLARE @SRV TABLE (
  IDSERVICIO varchar(20) NOT NULL PRIMARY KEY,
  MOTIVO     varchar(80) NOT NULL
);

INSERT INTO @SRV (IDSERVICIO, MOTIVO) VALUES
  (N'DM0474-1',  N'Entrada al 19 %'),
  (N'DM0868-3',  N'Entrada con PIVA 19; el valor trae el IVA incluido'),
  (N'DM148-1',   N'Hoy IVA = No y clase 01 compras; se pasa a clase 02 ventas'),
  (N'INS0058-1', N'Entrada al 19 %'),
  (N'INS0059-1', N'Entrada al 19 %'),
  (N'INS0064-1', N'Entrada al 19 %; el porcentaje no quedó en PIVA'),
  (N'INS0065-1', N'Entrada al 19 %; el porcentaje no quedó en PIVA'),
  (N'MX1944-1',  N'Entrada al 19 %');

/* No se actualizan: la entrada no sostiene la tarifa del 19 %. */
DECLARE @REVISAR TABLE (
  IDSERVICIO varchar(20) NOT NULL PRIMARY KEY,
  MOTIVO     varchar(120) NOT NULL
);

INSERT INTO @REVISAR (IDSERVICIO, MOTIVO) VALUES
  (N'DM0056-1', N'IVA de la entrada $0,50. No es tarifa.'),
  (N'DM149-1',  N'Costo de la entrada en $1. El IVA no sale al 19 % de ese costo.'),
  (N'MX1059-1', N'El IVA de la entrada no es 19 % del costo.'),
  (N'MX2434-1', N'El IVA de la entrada sale cerca del 38 %, no del 19 %.');

/* Vista previa: lo que cambiaría */
SELECT
  S.IDSERVICIO,
  A.DESCRIPCION,
  S.ESTADO,
  COALESCE(S.IVA, N'') AS IVA_HOY,
  COALESCE(S.IDIMPUESTO, N'') AS IMPUESTO_HOY,
  COALESCE(S.IDCLASE, N'') AS CLASE_HOY,
  N'SER' AS IVA_NUEVO,
  N'IVA' AS IMPUESTO_NUEVO,
  N'02' AS CLASE_NUEVA,
  X.MOTIVO
FROM @SRV X
LEFT JOIN dbo.SER S ON S.IDSERVICIO = X.IDSERVICIO
LEFT JOIN dbo.IART A ON A.IDARTICULO = X.IDSERVICIO
ORDER BY X.IDSERVICIO;

SELECT
  R.IDSERVICIO,
  A.DESCRIPCION,
  COALESCE(S.ESTADO, N'') AS ESTADO,
  COALESCE(S.IVA, N'') AS IVA_HOY,
  COALESCE(S.IDIMPUESTO, N'') AS IMPUESTO_HOY,
  COALESCE(S.IDCLASE, N'') AS CLASE_HOY,
  R.MOTIVO
FROM @REVISAR R
LEFT JOIN dbo.SER S ON S.IDSERVICIO = R.IDSERVICIO
LEFT JOIN dbo.IART A ON A.IDARTICULO = R.IDSERVICIO
ORDER BY R.IDSERVICIO;

IF @APLICAR = 0
  RETURN;

BEGIN TRAN;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.FIMPDV V
  WHERE V.IDIMPUESTO = N'IVA'
    AND V.IDCLASE = N'02'
    AND V.VALOR = 19
    AND V.FECHAINI <= CONVERT(date, GETDATE())
    AND (V.FECHAFIN IS NULL OR V.FECHAFIN >= CONVERT(date, GETDATE()))
)
BEGIN
  ROLLBACK TRAN;
  THROW 56020, 'La clase IVA 02 no está vigente al 19 %.', 1;
END;

IF (SELECT COUNT(*) FROM @SRV X INNER JOIN dbo.SER S ON S.IDSERVICIO = X.IDSERVICIO) <> 8
BEGIN
  ROLLBACK TRAN;
  THROW 56021, 'No están los 8 servicios en SER.', 1;
END;

IF EXISTS (
  SELECT 1
  FROM @SRV X
  INNER JOIN dbo.SER S ON S.IDSERVICIO = X.IDSERVICIO
  WHERE COALESCE(S.IVA, N'') = N'SER'
)
BEGIN
  ROLLBACK TRAN;
  THROW 56022, 'Alguno de los 8 ya tiene IVA = SER. No se actualizó nada.', 1;
END;

UPDATE S
SET IVA = N'SER',
    IDIMPUESTO = N'IVA',
    IDCLASE = N'02'
FROM dbo.SER S
INNER JOIN @SRV X ON X.IDSERVICIO = S.IDSERVICIO
WHERE COALESCE(S.IVA, N'') <> N'SER';

IF @@ROWCOUNT <> 8
BEGIN
  ROLLBACK TRAN;
  THROW 56023, 'El UPDATE no tocó los 8 servicios.', 1;
END;

IF EXISTS (
  SELECT 1
  FROM @SRV X
  INNER JOIN dbo.SER S ON S.IDSERVICIO = X.IDSERVICIO
  WHERE S.IVA <> N'SER'
     OR S.IDIMPUESTO <> N'IVA'
     OR S.IDCLASE <> N'02'
)
BEGIN
  ROLLBACK TRAN;
  THROW 56024, 'Quedó un servicio sin la clase de venta.', 1;
END;

COMMIT TRAN;

SELECT S.IDSERVICIO, S.ESTADO, S.IVA, S.IDIMPUESTO, S.IDCLASE
FROM dbo.SER S
INNER JOIN @SRV X ON X.IDSERVICIO = S.IDSERVICIO
ORDER BY S.IDSERVICIO;
