/*
  CEM. Septiembre 2026. Recontabilizar 22 CxP de servicios
  cuyo impuesto al consumo quedó dentro del gasto.

  No se ejecutó desde BA.

  Antes de @APLICAR = 1 hay que dejar en CEM el provisional
  sql/PROVISIONAL_CEM_SPK_NC_CONTAB_CXP.sql. Sin ese cambio,
  la rama de servicios sin IVA no separa el impuesto y este
  script deshace el comprobante.

  Enviar a cambios (SPK_PASA_A_MCPE) no acepta un comprobante
  en estado 2. El paso que lo deja en 1 es descontabilizar
  (SPK_NC_CONFIRMAR_CONTAB, tarea DESCONTABILIZAR): es el mismo
  cambio de estado 2 a 1. Si ya está en 1, ese paso no corre.

  Por cada comprobante, solo con @APLICAR = 1:
    1. Descontabilizar si el estado es 2.
    2. SPK_PASA_A_MCPE: lo pasa a cambios.
    3. SPK_NC_CONTAB_CXP: reconstruye el asiento con el
       procedimiento que ya está en CEM.
  El comprobante queda en MCPE. No se vuelve a confirmar.

  Si después de reconstruir el débito de 51051526 no coincide
  con el impuesto del detalle, se deshace ese comprobante.
  Eso pasa si el procedimiento de CEM todavía exige IVA.

  No entran:
    06SR019385 y 06SR019014: ya tienen el débito.
    06SR019106: el detalle no trae cuenta de impuesto.
    06SR019483, 06SR019484, 06SR019499: no tienen comprobante.

  1) Deje @APLICAR = 0 y ejecute el script completo: solo lista.
  2) Revise el listado. Deben salir las 22.
  3) Ponga @APLICAR = 1 y ejecute de nuevo.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @APLICAR BIT = 1;
DECLARE @COMPANIA VARCHAR(2) = N'01';
DECLARE @EQUIPO VARCHAR(254) = HOST_NAME();

DECLARE @lista TABLE (
    CNSFCXP varchar(20) NOT NULL,
    NROCOMPROBANTE varchar(20) NOT NULL
);

INSERT INTO @lista (CNSFCXP, NROCOMPROBANTE) VALUES
(N'06SR018998', N'0658000000205261'),
(N'06SR018999', N'0662000000205288'),
(N'06SR019000', N'0658000000205290'),
(N'06SR019101', N'0611100000205886'),
(N'06SR019104', N'0669000000205891'),
(N'06SR019109', N'0676000000205950'),
(N'06SR019110', N'0658000000205911'),
(N'06SR019114', N'0659000000205925'),
(N'06SR019117', N'0673000000205938'),
(N'06SR019120', N'0678000000205945'),
(N'06SR019130', N'0661000000205980'),
(N'06SR019327', N'0680000000206761'),
(N'06SR019328', N'0680000000206762'),
(N'06SR019329', N'0661000000206752'),
(N'06SR019330', N'0610100000206754'),
(N'06SR019331', N'0682000000206756'),
(N'06SR019332', N'0661000000206757'),
(N'06SR019334', N'0659000000206763'),
(N'06SR019335', N'0682000000206764'),
(N'06SR019369', N'0658000000207163'),
(N'06SR019370', N'0663000000207166'),
(N'06SR019386', N'0658000000207368');

SELECT
    L.CNSFCXP,
    C.NOREFERENCIA,
    L.NROCOMPROBANTE,
    M.PROCEDENCIA,
    M.REFERENCIA1,
    M.ESTADO AS ESTADO_MCP,
    M.IDSEDE,
    M.USUARIO,
    SUM(COALESCE(D.VLRIMPCONSUMO, 0)) AS IMPUESTO,
    MAX(NULLIF(LTRIM(RTRIM(D.CTAIMPCONSUMO)), N'')) AS CUENTA_IMP,
    CASE
        WHEN M.NROCOMPROBANTE IS NULL THEN N'No está en MCP'
        WHEN M.PROCEDENCIA <> N'CXP' THEN N'La procedencia del comprobante no es CXP'
        WHEN M.REFERENCIA1 <> L.CNSFCXP THEN N'La referencia no es la CxP'
        WHEN NULLIF(LTRIM(RTRIM(MAX(D.CTAIMPCONSUMO))), N'') IS NULL THEN N'Sin cuenta de impuesto'
        ELSE N'Listo'
    END AS LISTO
FROM @lista L
LEFT JOIN dbo.FCXP C ON C.CNSFCXP = L.CNSFCXP
LEFT JOIN dbo.FCXPD D ON D.CNSFCXP = L.CNSFCXP
LEFT JOIN dbo.MCP M ON M.NROCOMPROBANTE = L.NROCOMPROBANTE AND M.COMPANIA = @COMPANIA
GROUP BY L.CNSFCXP, C.NOREFERENCIA, L.NROCOMPROBANTE, M.NROCOMPROBANTE,
         M.PROCEDENCIA, M.REFERENCIA1, M.ESTADO, M.IDSEDE, M.USUARIO
ORDER BY L.CNSFCXP;

IF @APLICAR = 0
BEGIN
    SELECT N'VISTA PREVIA' AS RESULTADO,
           N'No se grabó. Para recontabilizar, @APLICAR = 1 y ejecute de nuevo.' AS DETALLE;
    RETURN;
END

DECLARE @CNSFCXP VARCHAR(20);
DECLARE @NRO VARCHAR(20);
DECLARE @ESTADO VARCHAR(2);
DECLARE @PROCEDENCIA VARCHAR(20);
DECLARE @REF1 VARCHAR(20);
DECLARE @SEDE VARCHAR(5);
DECLARE @USUARIO VARCHAR(12);
DECLARE @ANO INT;
DECLARE @MES INT;
DECLARE @NOREFERENCIA VARCHAR(20);
DECLARE @CUENTA VARCHAR(20);
DECLARE @IMPUESTO DECIMAL(14, 2);
DECLARE @DEBITO DECIMAL(14, 2);
DECLARE @MSG VARCHAR(400);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT L.CNSFCXP, L.NROCOMPROBANTE
    FROM @lista L
    ORDER BY L.CNSFCXP;

OPEN cur;
FETCH NEXT FROM cur INTO @CNSFCXP, @NRO;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SELECT
            @ESTADO = M.ESTADO,
            @PROCEDENCIA = M.PROCEDENCIA,
            @REF1 = M.REFERENCIA1,
            @SEDE = M.IDSEDE,
            @USUARIO = M.USUARIO,
            @ANO = TRY_CONVERT(int, M.ANO),
            @MES = TRY_CONVERT(int, M.MES),
            @NOREFERENCIA = M.NOREFERENCIA
        FROM dbo.MCP M
        WHERE M.COMPANIA = @COMPANIA
          AND M.NROCOMPROBANTE = @NRO;

        IF @ESTADO IS NULL
            THROW 50001, 'El comprobante no está en MCP.', 1;
        IF @PROCEDENCIA <> N'CXP' OR @REF1 <> @CNSFCXP
            THROW 50001, 'El comprobante no apunta a esta CxP.', 1;

        SELECT
            @CUENTA = MAX(NULLIF(LTRIM(RTRIM(D.CTAIMPCONSUMO)), N'')),
            @IMPUESTO = SUM(COALESCE(D.VLRIMPCONSUMO, 0))
        FROM dbo.FCXPD D
        WHERE D.CNSFCXP = @CNSFCXP;

        IF @CUENTA IS NULL OR COALESCE(@IMPUESTO, 0) <= 0
            THROW 50001, 'La CxP no tiene impuesto al consumo con cuenta.', 1;

        BEGIN TRAN;

        IF @ESTADO = N'2'
        BEGIN
            EXEC dbo.SPK_NC_CONFIRMAR_CONTAB
                @NRO, @USUARIO, @COMPANIA, @SEDE, @EQUIPO,
                @ANO, @MES, @PROCEDENCIA, @NOREFERENCIA, N'DESCONTABILIZAR';
        END

        IF (SELECT ESTADO FROM dbo.MCP WHERE COMPANIA = @COMPANIA AND NROCOMPROBANTE = @NRO) <> N'1'
            THROW 50001, 'El comprobante no quedó en estado 1.', 1;

        EXEC dbo.SPK_PASA_A_MCPE @NRO, @USUARIO;

        EXEC dbo.SPK_NC_CONTAB_CXP
            @CNSFCXP, @USUARIO, @EQUIPO, @COMPANIA, @SEDE, @NRO;

        SELECT @DEBITO = SUM(CASE WHEN H.TIPO = N'DB' THEN H.VALOR ELSE 0 END)
        FROM (
            SELECT TIPO, VALOR, CUENTA, COMPANIA, NROCOMPROBANTE FROM dbo.MCHE
            UNION ALL
            SELECT TIPO, VALOR, CUENTA, COMPANIA, NROCOMPROBANTE FROM dbo.MCH
        ) H
        WHERE H.COMPANIA = @COMPANIA
          AND H.NROCOMPROBANTE = @NRO
          AND H.CUENTA = @CUENTA;

        IF ABS(COALESCE(@DEBITO, 0) - @IMPUESTO) >= 1
            THROW 50001, 'El procedimiento no separó el impuesto al consumo. Se deshizo este comprobante.', 1;

        COMMIT TRAN;

        SELECT @CNSFCXP AS CNSFCXP, @NRO AS NROCOMPROBANTE, N'RECONSTRUIDO' AS RESULTADO,
               @IMPUESTO AS IMPUESTO, @DEBITO AS DEBITO_51051526;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
        SET @MSG = ERROR_MESSAGE();
        SELECT @CNSFCXP AS CNSFCXP, @NRO AS NROCOMPROBANTE, N'NO SE GRABÓ' AS RESULTADO, @MSG AS DETALLE;
    END CATCH

    FETCH NEXT FROM cur INTO @CNSFCXP, @NRO;
END

CLOSE cur;
DEALLOCATE cur;
