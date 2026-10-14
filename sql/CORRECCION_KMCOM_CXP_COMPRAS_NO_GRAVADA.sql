/*
  Corrección de KMCOM. CEM. Septiembre 2026.
  Modelo 01, proceso CXP_COMPRAS, prefijo 01 (medicamentos), área 4110.

  El débito debe nacer en la cuenta no gravada. Al armar la CxP, si la línea
  tiene IVA, el procedimiento pasa el detalle a la cuenta gravada.
  Estas dos filas ya estaban en la gravada, así que una factura sin IVA
  queda en medicamentos gravados.

  El crédito del centro 40010101 también estaba en medicamentos gravados.
  El encabezado de la CxP debe ser la cuenta de proveedores.

  No toca FCXP, FCXPD ni IEXI. Las facturas ya generadas no cambian.
  Si las filas no están como se espera, no deja nada grabado.
  Ejecutar el bloque completo.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRAN;

IF (
  SELECT COUNT(*)
  FROM dbo.KMCOM
  WHERE IDMODELOCONT = N'01'
    AND IDTIPOCONT = N'CXP_COMPRAS'
    AND TIPO = N'DB'
    AND PREFIJO = N'01'
    AND IDAREA = N'4110'
    AND CCOSTO IN (N'40010101', N'10250202')
    AND CUENTA = N'14150501'
) <> 2
BEGIN
  ROLLBACK TRAN;
  THROW 50001, 'Los debitos no estan en 14150501. No se cambio nada.', 1;
END;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.KMCOM
  WHERE IDMODELOCONT = N'01'
    AND IDTIPOCONT = N'CXP_COMPRAS'
    AND TIPO = N'CR'
    AND PREFIJO = N'01'
    AND IDAREA = N'4110'
    AND CCOSTO = N'40010101'
    AND CUENTA = N'14150501'
)
BEGIN
  ROLLBACK TRAN;
  THROW 50002, 'El credito de 40010101 no esta en 14150501. No se cambio nada.', 1;
END;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.CUE
  WHERE CUENTA = N'14150502'
    AND TIPO = N'Detalle'
    AND ISNULL(MCUEGRAV, 0) = 1
    AND CUENTAGRAV = N'14150501'
)
BEGIN
  ROLLBACK TRAN;
  THROW 50003, '14150502 no es la cuenta no gravada que pasa a 14150501. No se cambio nada.', 1;
END;

IF NOT EXISTS (
  SELECT 1
  FROM dbo.CUE
  WHERE CUENTA = N'22050101'
    AND TIPO = N'Detalle'
    AND ESTADO = N'Activa'
)
BEGIN
  ROLLBACK TRAN;
  THROW 50004, '22050101 no esta activa como cuenta de detalle. No se cambio nada.', 1;
END;

UPDATE dbo.KMCOM
SET CUENTA = N'14150502'
WHERE IDMODELOCONT = N'01'
  AND IDTIPOCONT = N'CXP_COMPRAS'
  AND TIPO = N'DB'
  AND PREFIJO = N'01'
  AND IDAREA = N'4110'
  AND CCOSTO IN (N'40010101', N'10250202')
  AND CUENTA = N'14150501';

UPDATE dbo.KMCOM
SET CUENTA = N'22050101'
WHERE IDMODELOCONT = N'01'
  AND IDTIPOCONT = N'CXP_COMPRAS'
  AND TIPO = N'CR'
  AND PREFIJO = N'01'
  AND IDAREA = N'4110'
  AND CCOSTO = N'40010101'
  AND CUENTA = N'14150501';

IF (
  SELECT COUNT(*)
  FROM dbo.KMCOM
  WHERE IDMODELOCONT = N'01'
    AND IDTIPOCONT = N'CXP_COMPRAS'
    AND PREFIJO = N'01'
    AND IDAREA = N'4110'
    AND (
      (TIPO = N'DB' AND CCOSTO IN (N'40010101', N'10250202') AND CUENTA = N'14150502')
      OR (TIPO = N'CR' AND CCOSTO = N'40010101' AND CUENTA = N'22050101')
    )
) <> 3
BEGIN
  ROLLBACK TRAN;
  THROW 50005, 'Despues del cambio no quedaron las tres filas esperadas. No se cambio nada.', 1;
END;

COMMIT TRAN;

SELECT TIPO, PREFIJO, IDAREA, CCOSTO, CUENTA
FROM dbo.KMCOM
WHERE IDMODELOCONT = N'01'
  AND IDTIPOCONT = N'CXP_COMPRAS'
  AND PREFIJO = N'01'
  AND IDAREA = N'4110'
  AND CCOSTO IN (N'40010101', N'10250202')
ORDER BY CCOSTO, TIPO;
