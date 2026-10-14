/*
  Corrección de detalle. CEM. Septiembre 2026.
  La cabecera ya tiene el IVA de la entrada. El detalle repite el IVA del artículo
  en cada lote. Este script pone en cada línea el IVA de su lote y recalcula el neto.
  No toca FCXP, no contabiliza y no vuelve a procesar la entrada.

  Solo estas CxP, estado N, sin contabilizar y sin comprobante:
    01CM000871  01CM000873  03CM001766  03CM002016

  Fuera de este bloque a propósito:
    01CM000875 y 01CM000880 ya igualan encabezado y detalle, pero varias
    líneas traen el IVA del artículo y no el del lote. Alinearlas a la
    entrada dejaría el detalle por debajo del encabezado y el cierre
    devolvería todo.
    03CM002019 ya está contabilizada y ya cuadra. El cierre la rechaza.

  Si una línea no tiene un solo grupo en la entrada, o si al final
  la suma del detalle no coincide con la cabecera, no deja nada grabado.
  Ejecutar el bloque completo. No correr SPK_CALCULOVALORESCXP: la cabecera ya cuadra.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRAN;

IF EXISTS (
  SELECT D.CNSFCXP, D.ITEM
  FROM FCXPD D
  INNER JOIN FCXP P ON P.CNSFCXP = D.CNSFCXP
  LEFT JOIN (
    SELECT CNSMOV, IDARTICULO, ISNULL(NOLOTEPEDIDO, '') AS NOLOTE, PCOSTO,
           SUM(CANTIDAD) AS CANTIDAD
    FROM IMOVH
    GROUP BY CNSMOV, IDARTICULO, ISNULL(NOLOTEPEDIDO, ''), PCOSTO
  ) G ON G.CNSMOV = D.N_PRESUP
     AND G.IDARTICULO = D.IDSERVICIO
     AND G.NOLOTE = ISNULL(D.NOLOTE, '')
     AND ABS(G.CANTIDAD - D.CANTIDAD) < 0.02
     AND ABS(G.PCOSTO - D.VALOR) < 0.02
  WHERE P.CNSFCXP IN (
      '01CM000871','01CM000873','03CM001766','03CM002016'
    )
    AND P.ESTADO = 'N'
    AND COALESCE(P.CONTABILIZADA, 0) = 0
    AND COALESCE(P.NROCOMPROBANTE, '') = ''
  GROUP BY D.CNSFCXP, D.ITEM
  HAVING COUNT(G.CNSMOV) <> 1
)
BEGIN
  ROLLBACK TRAN;
  THROW 50001, 'Hay una linea sin un solo grupo de entrada. No se cambio nada.', 1;
END;

UPDATE D
SET VLR_IVA = G.IVA_OK,
    VLR_NETO = (D.CANTIDAD * D.VALOR) + G.IVA_OK - ISNULL(D.VLR_DESCUENTO, 0)
FROM FCXPD D
INNER JOIN FCXP P ON P.CNSFCXP = D.CNSFCXP
INNER JOIN (
  SELECT CNSMOV, IDARTICULO, ISNULL(NOLOTEPEDIDO, '') AS NOLOTE, PCOSTO,
         SUM(CANTIDAD) AS CANTIDAD,
         SUM(ISNULL(VLRIVA, 0)) AS IVA_OK
  FROM IMOVH
  GROUP BY CNSMOV, IDARTICULO, ISNULL(NOLOTEPEDIDO, ''), PCOSTO
) G ON G.CNSMOV = D.N_PRESUP
   AND G.IDARTICULO = D.IDSERVICIO
   AND G.NOLOTE = ISNULL(D.NOLOTE, '')
   AND ABS(G.CANTIDAD - D.CANTIDAD) < 0.02
   AND ABS(G.PCOSTO - D.VALOR) < 0.02
WHERE P.CNSFCXP IN (
    '01CM000871','01CM000873','03CM001766','03CM002016'
  )
  AND P.ESTADO = 'N'
  AND COALESCE(P.CONTABILIZADA, 0) = 0
  AND COALESCE(P.NROCOMPROBANTE, '') = ''
  AND ABS(D.VLR_IVA - G.IVA_OK) > 0.01;

IF EXISTS (
  SELECT P.CNSFCXP
  FROM FCXP P
  INNER JOIN FCXPD D ON D.CNSFCXP = P.CNSFCXP
  WHERE P.CNSFCXP IN (
      '01CM000871','01CM000873','03CM001766','03CM002016'
    )
  GROUP BY P.CNSFCXP, P.VLR_IVA, P.VLR_NETO, P.ESTADO, P.CONTABILIZADA, P.NROCOMPROBANTE
  HAVING ABS(SUM(D.VLR_IVA) - P.VLR_IVA) > 0.01
      OR ABS(SUM(D.VLR_NETO) - P.VLR_NETO) > 0.01
      OR P.ESTADO <> 'N'
      OR COALESCE(P.CONTABILIZADA, 0) <> 0
      OR COALESCE(P.NROCOMPROBANTE, '') <> ''
)
BEGIN
  ROLLBACK TRAN;
  THROW 50002, 'El detalle no quedo igual a la cabecera. No se cambio nada.', 1;
END;

COMMIT TRAN;

SELECT P.CNSFCXP,
       CONVERT(decimal(18,2), P.VLR_IVA) AS IVA_CAB,
       CONVERT(decimal(18,2), SUM(D.VLR_IVA)) AS IVA_DET,
       CONVERT(decimal(18,2), P.VLR_NETO) AS NETO_CAB,
       CONVERT(decimal(18,2), SUM(D.VLR_NETO)) AS NETO_DET
FROM FCXP P
INNER JOIN FCXPD D ON D.CNSFCXP = P.CNSFCXP
WHERE P.CNSFCXP IN (
    '01CM000871','01CM000873','03CM001766','03CM002016'
  )
GROUP BY P.CNSFCXP, P.VLR_IVA, P.VLR_NETO
ORDER BY P.CNSFCXP;
