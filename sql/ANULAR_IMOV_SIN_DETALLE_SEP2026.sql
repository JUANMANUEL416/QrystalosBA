/*
  CEM — anular encabezados de inventario de septiembre 2026 que no tienen detalle.

  Universo (el mismo de DETALLE_IMOV_SIN_CONFIRMAR_SEP2026, columna Encabezado vacío):
    FECHAMOV de sep 2026, ESTADO = 0 (pendiente), tipo que se contabiliza,
    sin filas en IMOVH y sin filas en ISAL.

  Qué hace:
    IMOV.ESTADO = 2, FECHACONF = ahora, USUARIOCONF = @USUARIO.
    Es el mismo cierre que deja SPK_ANULAR_MOV_INV cuando el movimiento
    todavía está pendiente (no arma movimiento contrario).

  Qué no hace:
    No llama SPK_ANULAR_MOV_INV (en una entrada confirmada ese SP reabre
    la orden de compra y borra el tránsito).
    No toca IMOVH, ISAL, IEXI, IZSOL, FCOM ni FCXP.
    No anula un movimiento que tenga línea o entrega, aunque sea de septiembre.
    No anula confirmados, ya anulados ni contabilizados.

  Uso:
    1. Deje @APLICAR = 0 y ejecute. Revise el resumen y el listado.
    2. Ponga el usuario de Qrystalos en @USUARIO y @APLICAR = 1.
    3. Vuelva a ejecutar. Si el conteo no cuadra, hace ROLLBACK y no deja nada.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR  bit          = 0;      -- 0 = solo muestra; 1 = anula
DECLARE @USUARIO  varchar(12)  = N'';    -- usuario Qrystalos que anula (obligatorio si @APLICAR = 1)

IF OBJECT_ID('tempdb..#ANULAR') IS NOT NULL DROP TABLE #ANULAR;

SELECT
    M.CNSMOV,
    M.IDBODEGA,
    M.IDTIPOMOV,
    M.NODOCUMENTO,
    M.FECHAMOV,
    M.PROCEDENCIA
INTO #ANULAR
FROM dbo.IMOV M
INNER JOIN dbo.ITMO T
    ON T.IDTIPOMOV = M.IDTIPOMOV
WHERE M.FECHAMOV >= '20260901'
  AND M.FECHAMOV <  '20261001'
  AND COALESCE(M.ESTADO, '0') = '0'
  AND COALESCE(T.SECONTABILIZA, 0) = 1
  AND COALESCE(M.CONTABILIZADA, 0) = 0
  AND COALESCE(RTRIM(M.NROCOMPROBANTE), N'') = N''
  AND NOT EXISTS (SELECT 1 FROM dbo.IMOVH X WHERE X.CNSMOV = M.CNSMOV)
  AND NOT EXISTS (SELECT 1 FROM dbo.ISAL  S WHERE S.CNSMOV = M.CNSMOV);

/* Resumen: lo que se va a anular */
SELECT
    A.IDBODEGA,
    B.DESCRIPCION AS BODEGA,
    A.IDTIPOMOV,
    T.DESCRIPCION AS TIPO,
    COUNT(*) AS MOVIMIENTOS
FROM #ANULAR A
LEFT JOIN dbo.IBOD B ON B.IDBODEGA = A.IDBODEGA
LEFT JOIN dbo.ITMO T ON T.IDTIPOMOV = A.IDTIPOMOV
GROUP BY A.IDBODEGA, B.DESCRIPCION, A.IDTIPOMOV, T.DESCRIPCION
ORDER BY A.IDBODEGA, A.IDTIPOMOV;

SELECT COUNT(*) AS TOTAL_A_ANULAR FROM #ANULAR;

IF @APLICAR = 0
BEGIN
    SELECT
        A.CNSMOV,
        A.IDBODEGA,
        A.IDTIPOMOV,
        A.NODOCUMENTO AS SOLICITUD,
        CONVERT(varchar(10), A.FECHAMOV, 103) AS FECHA,
        A.PROCEDENCIA
    FROM #ANULAR A
    ORDER BY A.IDBODEGA, A.FECHAMOV, A.CNSMOV;

    PRINT 'Vista previa. No se anuló nada. Para aplicar: @USUARIO y @APLICAR = 1.';
    RETURN;
END

IF RTRIM(@USUARIO) = N''
    THROW 56010, N'Falta @USUARIO (usuario de Qrystalos que anula).', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.PRI
    WHERE ANO = '2026' AND MES = 9 AND COALESCE(CERRADO_INV, 0) = 1
)
    THROW 56011, N'Septiembre 2026 tiene el inventario cerrado. No se anula.', 1;

BEGIN TRY
    BEGIN TRAN;

    /* Si entre la foto y el UPDATE apareció una línea o una entrega, no entra. */
    UPDATE M
       SET M.ESTADO       = '2',
           M.FECHACONF    = dbo.FNK_FECHA_SIN_MLS(GETDATE()),
           M.USUARIOCONF  = @USUARIO
    FROM dbo.IMOV M
    INNER JOIN #ANULAR A ON A.CNSMOV = M.CNSMOV
    WHERE COALESCE(M.ESTADO, '0') = '0'
      AND COALESCE(M.CONTABILIZADA, 0) = 0
      AND COALESCE(RTRIM(M.NROCOMPROBANTE), N'') = N''
      AND NOT EXISTS (SELECT 1 FROM dbo.IMOVH X WHERE X.CNSMOV = M.CNSMOV)
      AND NOT EXISTS (SELECT 1 FROM dbo.ISAL  S WHERE S.CNSMOV = M.CNSMOV);

    IF @@ROWCOUNT <> (SELECT COUNT(*) FROM #ANULAR)
    BEGIN
        ROLLBACK TRAN;
        THROW 56012, N'El conteo cambió (apareció detalle, se confirmó o se contabilizó). No se anuló nada. Vuelva a correr con @APLICAR = 0.', 1;
    END

    /* Nada de lo anulado debe haber quedado con líneas. */
    IF EXISTS (
        SELECT 1
        FROM #ANULAR A
        WHERE EXISTS (SELECT 1 FROM dbo.IMOVH X WHERE X.CNSMOV = A.CNSMOV)
           OR EXISTS (SELECT 1 FROM dbo.ISAL  S WHERE S.CNSMOV = A.CNSMOV)
           OR EXISTS (
                SELECT 1 FROM dbo.IMOV M
                WHERE M.CNSMOV = A.CNSMOV
                  AND COALESCE(M.ESTADO, '0') <> '2'
           )
    )
    BEGIN
        ROLLBACK TRAN;
        THROW 56013, N'Quedó un movimiento con detalle o sin anular. No se anuló nada.', 1;
    END

    COMMIT TRAN;

    SELECT COUNT(*) AS ANULADOS
    FROM dbo.IMOV M
    INNER JOIN #ANULAR A ON A.CNSMOV = M.CNSMOV
    WHERE M.ESTADO = '2';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
