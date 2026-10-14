/*
  KHCODAZZI. Corregir el modelo que deja la cuenta NO DEF.KMCOM.

  La factura (SPK_NC_CONTAB_FTR) busca KMCOM de VENTAS, crédito, clase S.
  El inventario (SPK_NC_CONTAB_INV) busca MOV_INVENTARIO con el tipo de movimiento
  y clase P. La clave de KMCOM no incluye la clase: solo cabe una fila por
  modelo, proceso, débito o crédito, prefijo, área y centro.

  Vista previa: @APLICAR = 0. Para escribir, cambiar a 1.
  Después hay que reconstruir la factura o el movimiento. Este script no lo hace.
*/
SET NOCOUNT ON;

DECLARE @APLICAR bit = 1;

/* 1. Factura. La fila ya existe, con clase P o vacía. La factura busca S.
      Se conserva la cuenta y se deja la clase en S.
      La nota de factura busca la misma clave con clase P. Estos prefijos
      están fallando en la factura, así que la clase queda en S. */
SELECT RTRIM(k.PREFIJO) AS PREFIJO, RTRIM(k.CCOSTO) AS CCOSTO, RTRIM(k.IDAREA) AS IDAREA,
       k.CLASECONT AS CLASE_HOY, 'S' AS CLASE_NUEVA, k.CUENTA, 'Dejar clase S' AS ACCION
FROM KMCOM k
WHERE k.IDMODELOCONT = '01'
  AND k.IDTIPOCONT = 'VENTAS'
  AND k.TIPO = 'CR'
  AND COALESCE(k.CLASECONT, '') <> 'S'
  AND (
        (RTRIM(k.PREFIJO) = '16' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '31' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '36' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '41' AND RTRIM(k.CCOSTO) = '128' AND RTRIM(k.IDAREA) = '4110')
      );

/* 2. Factura. La fila no existe. La cuenta sale de un prefijo del mismo centro,
      o del mismo prefijo en otro centro cuando ese centro no tiene modelo. */
SELECT v.PREFIJO, v.CCOSTO, v.IDAREA, v.CUENTA, v.ORIGEN
FROM (
  SELECT '41' AS PREFIJO, '011' AS CCOSTO, '4110' AS IDAREA, '43122001' AS CUENTA,
         'Mismo centro 011/4110, prefijo 36' AS ORIGEN
  UNION ALL
  SELECT 'PYM', '000701', '4110', '43121801',
         'Mismo centro 000701/4110, prefijos 16, 90 y 100'
  UNION ALL
  SELECT 'MAT', '1001', '1000', '43122001',
         'Mismo prefijo MAT en centro 012 área 4110'
) v
WHERE NOT EXISTS (
  SELECT 1
  FROM KMCOM k
  WHERE k.IDMODELOCONT = '01'
    AND k.IDTIPOCONT = 'VENTAS'
    AND k.TIPO = 'CR'
    AND RTRIM(k.PREFIJO) = v.PREFIJO
    AND RTRIM(k.CCOSTO) = v.CCOSTO
    AND RTRIM(k.IDAREA) = v.IDAREA
);

/* 3. Inventario. Falta el tipo de movimiento 01 en el centro 012 área 4110.
      Se copia la cuenta del tipo 05 del mismo centro. La clase queda P,
      que es la que busca el inventario. */
SELECT v.PREFIJO, v.TIPO, v.CCOSTO, v.IDAREA, v.CUENTA, v.ORIGEN
FROM (
  SELECT '01' AS PREFIJO, 'CR' AS TIPO, '012' AS CCOSTO, '4110' AS IDAREA,
         '15149010' AS CUENTA, 'Tipo 05 del mismo centro' AS ORIGEN
  UNION ALL
  SELECT '01', 'DB', '012', '4110', '73100290', 'Tipo 05 del mismo centro'
) v
WHERE NOT EXISTS (
  SELECT 1
  FROM KMCOM k
  WHERE k.IDMODELOCONT = '01'
    AND k.IDTIPOCONT = 'MOV_INVENTARIO'
    AND k.TIPO = v.TIPO
    AND RTRIM(k.PREFIJO) = v.PREFIJO
    AND RTRIM(k.CCOSTO) = v.CCOSTO
    AND RTRIM(k.IDAREA) = v.IDAREA
);

/* 4. No se inventa cuenta. Estas claves no tienen prefijo vecino.
      La factura con prefijo vacío no puede casar con KMCOM:
      la línea no trae prefijo y la clave no admite un prefijo en blanco útil.
      El tipo 01 en 117/4135 ya está en clase P: el inventario lo busca así
      y no se duplica. Si sigue en NO DEF.KMCOM, el fallo está en el artículo
      o en el centro que valida la función, no en una fila ausente. */
SELECT 'SIN CUENTA' AS ACCION, 'FACTURA' AS PROCEDENCIA, '(prefijo vacio)' AS PREFIJO,
       '012' AS CCOSTO, '4110' AS IDAREA, 'CR' AS TIPO
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 01', '01', '132', '4140', 'CR'
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 01', '01', '132', '4140', 'DB'
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 05', '05', '000272', '4110', 'CR y DB'
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 05', '05', '119', '5105', 'CR y DB'
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 05', '05', '128', '4110', 'CR y DB'
UNION ALL
SELECT 'SIN CUENTA', 'INV tipo 05', '05', '145', '4145', 'CR y DB';

IF @APLICAR = 0
BEGIN
  PRINT 'Vista previa. No se escribió KMCOM. Para escribir, cambie @APLICAR a 1.';
  RETURN;
END

BEGIN TRAN;

UPDATE k
SET CLASECONT = 'S'
FROM KMCOM k
WHERE k.IDMODELOCONT = '01'
  AND k.IDTIPOCONT = 'VENTAS'
  AND k.TIPO = 'CR'
  AND COALESCE(k.CLASECONT, '') <> 'S'
  AND (
        (RTRIM(k.PREFIJO) = '16' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '31' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '36' AND RTRIM(k.CCOSTO) = '132' AND RTRIM(k.IDAREA) = '4140')
     OR (RTRIM(k.PREFIJO) = '41' AND RTRIM(k.CCOSTO) = '128' AND RTRIM(k.IDAREA) = '4110')
      );

INSERT INTO KMCOM (
  IDMODELOCONT, IDTIPOCONT, TIPO, PREFIJO, IDAREA, CCOSTO, CUENTA, CLASECONT,
  ESTADO, CUENTAIPS, NIIF, CTA_PASIVOEST, MPGP, CUECRPGP, MCAPITA, CUECRCAP, MIVA, CUENTAIVA
)
SELECT s.IDMODELOCONT, s.IDTIPOCONT, s.TIPO, '41', s.IDAREA, s.CCOSTO, s.CUENTA, 'S',
       s.ESTADO, s.CUENTAIPS, s.NIIF, s.CTA_PASIVOEST, s.MPGP, s.CUECRPGP, s.MCAPITA, s.CUECRCAP, s.MIVA, s.CUENTAIVA
FROM KMCOM s
WHERE s.IDMODELOCONT = '01'
  AND s.IDTIPOCONT = 'VENTAS'
  AND s.TIPO = 'CR'
  AND RTRIM(s.PREFIJO) = '36'
  AND RTRIM(s.CCOSTO) = '011'
  AND RTRIM(s.IDAREA) = '4110'
  AND NOT EXISTS (
        SELECT 1 FROM KMCOM k
        WHERE k.IDMODELOCONT = '01' AND k.IDTIPOCONT = 'VENTAS' AND k.TIPO = 'CR'
          AND RTRIM(k.PREFIJO) = '41' AND RTRIM(k.CCOSTO) = '011' AND RTRIM(k.IDAREA) = '4110'
      );

INSERT INTO KMCOM (
  IDMODELOCONT, IDTIPOCONT, TIPO, PREFIJO, IDAREA, CCOSTO, CUENTA, CLASECONT,
  ESTADO, CUENTAIPS, NIIF, CTA_PASIVOEST, MPGP, CUECRPGP, MCAPITA, CUECRCAP, MIVA, CUENTAIVA
)
SELECT s.IDMODELOCONT, s.IDTIPOCONT, s.TIPO, 'PYM', s.IDAREA, s.CCOSTO, s.CUENTA, 'S',
       s.ESTADO, s.CUENTAIPS, s.NIIF, s.CTA_PASIVOEST, s.MPGP, s.CUECRPGP, s.MCAPITA, s.CUECRCAP, s.MIVA, s.CUENTAIVA
FROM KMCOM s
WHERE s.IDMODELOCONT = '01'
  AND s.IDTIPOCONT = 'VENTAS'
  AND s.TIPO = 'CR'
  AND RTRIM(s.PREFIJO) = '16'
  AND RTRIM(s.CCOSTO) = '000701'
  AND RTRIM(s.IDAREA) = '4110'
  AND NOT EXISTS (
        SELECT 1 FROM KMCOM k
        WHERE k.IDMODELOCONT = '01' AND k.IDTIPOCONT = 'VENTAS' AND k.TIPO = 'CR'
          AND RTRIM(k.PREFIJO) = 'PYM' AND RTRIM(k.CCOSTO) = '000701' AND RTRIM(k.IDAREA) = '4110'
      );

INSERT INTO KMCOM (
  IDMODELOCONT, IDTIPOCONT, TIPO, PREFIJO, IDAREA, CCOSTO, CUENTA, CLASECONT,
  ESTADO, CUENTAIPS, NIIF, CTA_PASIVOEST, MPGP, CUECRPGP, MCAPITA, CUECRCAP, MIVA, CUENTAIVA
)
SELECT s.IDMODELOCONT, s.IDTIPOCONT, s.TIPO, s.PREFIJO, '1000', '1001', s.CUENTA, 'S',
       s.ESTADO, s.CUENTAIPS, s.NIIF, s.CTA_PASIVOEST, s.MPGP, s.CUECRPGP, s.MCAPITA, s.CUECRCAP, s.MIVA, s.CUENTAIVA
FROM KMCOM s
WHERE s.IDMODELOCONT = '01'
  AND s.IDTIPOCONT = 'VENTAS'
  AND s.TIPO = 'CR'
  AND RTRIM(s.PREFIJO) = 'MAT'
  AND RTRIM(s.CCOSTO) = '012'
  AND RTRIM(s.IDAREA) = '4110'
  AND NOT EXISTS (
        SELECT 1 FROM KMCOM k
        WHERE k.IDMODELOCONT = '01' AND k.IDTIPOCONT = 'VENTAS' AND k.TIPO = 'CR'
          AND RTRIM(k.PREFIJO) = 'MAT' AND RTRIM(k.CCOSTO) = '1001' AND RTRIM(k.IDAREA) = '1000'
      );

INSERT INTO KMCOM (
  IDMODELOCONT, IDTIPOCONT, TIPO, PREFIJO, IDAREA, CCOSTO, CUENTA, CLASECONT,
  ESTADO, CUENTAIPS, NIIF, CTA_PASIVOEST, MPGP, CUECRPGP, MCAPITA, CUECRCAP, MIVA, CUENTAIVA
)
SELECT s.IDMODELOCONT, s.IDTIPOCONT, s.TIPO, '01', s.IDAREA, s.CCOSTO, s.CUENTA, 'P',
       s.ESTADO, s.CUENTAIPS, s.NIIF, s.CTA_PASIVOEST, s.MPGP, s.CUECRPGP, s.MCAPITA, s.CUECRCAP, s.MIVA, s.CUENTAIVA
FROM KMCOM s
WHERE s.IDMODELOCONT = '01'
  AND s.IDTIPOCONT = 'MOV_INVENTARIO'
  AND RTRIM(s.PREFIJO) = '05'
  AND RTRIM(s.CCOSTO) = '012'
  AND RTRIM(s.IDAREA) = '4110'
  AND s.TIPO IN ('CR', 'DB')
  AND NOT EXISTS (
        SELECT 1 FROM KMCOM k
        WHERE k.IDMODELOCONT = s.IDMODELOCONT
          AND k.IDTIPOCONT = s.IDTIPOCONT
          AND k.TIPO = s.TIPO
          AND RTRIM(k.PREFIJO) = '01'
          AND RTRIM(k.CCOSTO) = '012'
          AND RTRIM(k.IDAREA) = '4110'
      );

COMMIT TRAN;

PRINT 'Listo. Reconstruya las facturas y los movimientos de inventario. No reconstruya los reversos.';
