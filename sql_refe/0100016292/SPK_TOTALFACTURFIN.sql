CREATE OR ALTER PROCEDURE DBO.SPK_TOTALFACTURFIN
    @N_FACTURA VARCHAR(16),
    @COPAPROPIO_ANT BIT = NULL
WITH ENCRYPTION
AS
/*
  Recálculo de totales FTR / FTRD (evento, financiero, capitada y PGP).

  @COPAPROPIO_ANT: estado anterior al guardar FTR (solo edición). NULL = recálculo
  rutinario (ADD, FTRD, etc.) sin limpiar COPAGOS_CP ya digitados.

  Capitada / PGP — transición copago propio:
    - Activar (ANT=0, actual=1): borra COPAGOS_CP FTRD; copago/moderadora FTR en cero;
      espera digitación en FTRD.COPAGOS_CP.
    - Desactivar (actual=0): borra COPAGOS_CP FTRD; restaura VLR_COPAGO FTRDC desde cargos;
      recalcula copago y moderadora normales.
    - FTRD.VLR_COPAGOS = suma VLR_COPAGO de FTRDC por cuota.
    - FTR.VALORSERVICIOS = suma bruta FTRD (VALOR * CANTIDAD).
    - Copago propio: VALORCOPAGO y VALORMODERADORA en cero; CP_VLR_COPAGOS = COPAGOS_CP FTRD.
    - Sin copago propio: COPAGOS_CP en cero (FTRD); copagos desde FTRDC (restaurados desde cargos si aplica).
    - Sin CUOTMODE_ENFACTFINAN: VALORCOPAGO = total FTRDC; moderadora = 0.
    - Con CUOTMODE_ENFACTFINAN: moderadora TCOPAGO 02 / MOCCD; copago = resto.
    - VR_TOTAL = neto según regla anterior menos descuento y abonos.

  Evento / otros: agregados desde FTRD (VLR_SERVICI, VLR_COPAGOS, etc.).
*/
DECLARE @CNSFTR VARCHAR(20),
        @CAPITADA BIT,
        @COPAPROPIO BIT,
        @MODERADORA DECIMAL(14, 2) = 0,
        @COPAGOS_CP DECIMAL(14, 2),
        @VALORFTRD DECIMAL(14, 2),
        @VALORTOTAL_FTRDC DECIMAL(14, 2),
        @TOTAL_COPAGO_FTRDC DECIMAL(14, 2),
        @VALORPCOMP_FTRDC DECIMAL(14, 2),
        @CP_VLR_SERVICIOS DECIMAL(14, 2),
        @CP_VLR_COPAGOS DECIMAL(14, 2),
        @CP_VLR_PAGCOMP DECIMAL(14, 2),
        @VALORSERVICIOS DECIMAL(14, 2),
        @VALORCOPAGO DECIMAL(14, 2),
        @VALORMODERADORA DECIMAL(14, 2),
        @VR_TOTAL DECIMAL(14, 2),
        @VIVA DECIMAL(14, 2),
        @PIVA DECIMAL(7, 2),
        @DESCUENTO DECIMAL(14, 2),
        @VR_ABONOS DECIMAL(14, 2),
        @REDONDEA BIT;

BEGIN
    SELECT
        @CNSFTR = CNSFCT,
        @CAPITADA = COALESCE(CAPITADA, 0),
        @COPAPROPIO = COALESCE(COPAPROPIO, 0),
        @DESCUENTO = COALESCE(DESCUENTO, 0),
        @VR_ABONOS = COALESCE(VR_ABONOS, 0)
    FROM FTR
    WHERE N_FACTURA = @N_FACTURA;

    SET @REDONDEA = CASE WHEN DBO.FNK_VALORVARIABLE('REDONDEOFTRFINANC') = 'SI' THEN 1 ELSE 0 END;

    /* --- Capitada / PGP --- */
    IF @CAPITADA = 1 AND COALESCE(@CNSFTR, '') <> ''
    BEGIN
        /* Desactivar copago propio: copagos normales desde relación */
        IF @COPAPROPIO = 0
        BEGIN
            UPDATE F
            SET VLR_COPAGO =
                CASE
                    WHEN DBO.FNK_VALORVARIABLE('SOLO_COPA_RECAUDADO') = 'SI'
                         AND COALESCE(A.VALORCOPAGO, 0) > 0
                         AND COALESCE(A.ENCAJA, 0) = 0
                        THEN 0
                    ELSE COALESCE(A.VALORCOPAGO, 0)
                END
            FROM FTRDC F
            INNER JOIN VWK_CARGOS_HADMAUTCIT A
                ON A.PROCEDENCIA = F.PROCEDENCIA
               AND A.NOADMISION = F.NOADMISION
               AND A.NOPRESTACION = F.NOPRESTACION
               AND A.NOITEM = F.NOITEM
            WHERE F.CNSFTR = @CNSFTR;

            UPDATE FTRD
            SET COPAGOS_CP = 0
            WHERE CNSFTR = @CNSFTR;
        END
        ELSE
        BEGIN
            /* Activar copago propio: quitar copagos normales; borrar COPAGOS_CP solo al marcar check */
            IF COALESCE(@COPAPROPIO_ANT, 1) = 0
            BEGIN
                UPDATE FTRD
                SET COPAGOS_CP = 0
                WHERE CNSFTR = @CNSFTR;

                UPDATE FTRDC
                SET VLR_COPAGO = 0
                WHERE CNSFTR = @CNSFTR;
            END
            ELSE
            BEGIN
                UPDATE FTRDC
                SET VLR_COPAGO = 0
                WHERE CNSFTR = @CNSFTR
                  AND PROCEDENCIA <> 'HADM'
                  AND (
                        COALESCE(TCOPAGO, '') = '02'
                        OR EXISTS (
                            SELECT 1
                            FROM MOCCD
                            WHERE TIPODEPAGO = 'Moderadora'
                              AND MOCCD.VALOR = FTRDC.VLR_COPAGO
                        )
                      );
            END
        END

        UPDATE FTRD
        SET VLR_COPAGOS =
            CASE
                WHEN @REDONDEA = 1
                    THEN ROUND(COALESCE(V.VALORCOPAGO, 0), 0)
                ELSE COALESCE(V.VALORCOPAGO, 0)
            END
        FROM FTRD
        LEFT JOIN (
            SELECT
                N_CUOTA,
                SUM(VLR_COPAGO) AS VALORCOPAGO
            FROM FTRDC
            WHERE CNSFTR = @CNSFTR
            GROUP BY N_CUOTA
        ) V ON FTRD.N_CUOTA = V.N_CUOTA
        WHERE FTRD.CNSFTR = @CNSFTR;

        SELECT @COPAGOS_CP = SUM(COALESCE(COPAGOS_CP, 0))
        FROM FTRD
        WHERE CNSFTR = @CNSFTR;

        SELECT @VALORFTRD = SUM(VALOR * CANTIDAD)
        FROM FTRD
        WHERE CNSFTR = @CNSFTR;

        SELECT
            @VALORTOTAL_FTRDC = SUM(VALORTOTAL),
            @TOTAL_COPAGO_FTRDC = SUM(VLR_COPAGO),
            @VALORPCOMP_FTRDC = SUM(VLR_PAGCOMP)
        FROM FTRDC
        WHERE CNSFTR = @CNSFTR;

        SELECT
            @VIVA = COALESCE(SUM(VIVA * CANTIDAD), 0),
            @PIVA = MAX(COALESCE(PIVA, 0))
        FROM FTRD
        WHERE N_FACTURA = @N_FACTURA;

        SET @VALORTOTAL_FTRDC = COALESCE(@VALORTOTAL_FTRDC, 0);
        SET @TOTAL_COPAGO_FTRDC = COALESCE(@TOTAL_COPAGO_FTRDC, 0);
        SET @VALORPCOMP_FTRDC = COALESCE(@VALORPCOMP_FTRDC, 0);
        SET @COPAGOS_CP = COALESCE(@COPAGOS_CP, 0);
        SET @VALORFTRD = COALESCE(@VALORFTRD, 0);
        SET @MODERADORA = 0;

        IF @COPAPROPIO = 0
           AND DBO.FNK_VALORVARIABLE('CUOTMODE_ENFACTFINAN') = 'SI'
        BEGIN
            SELECT @MODERADORA = SUM(VLR_COPAGO)
            FROM FTRDC
            WHERE CNSFTR = @CNSFTR
              AND PROCEDENCIA <> 'HADM'
              AND (
                    COALESCE(TCOPAGO, '') = '02'
                    OR EXISTS (
                        SELECT 1
                        FROM MOCCD
                        WHERE TIPODEPAGO = 'Moderadora'
                          AND MOCCD.VALOR = FTRDC.VLR_COPAGO
                    )
                  );
        END

        SET @MODERADORA = COALESCE(@MODERADORA, 0);
        SET @CP_VLR_SERVICIOS = @VALORTOTAL_FTRDC;
        SET @CP_VLR_PAGCOMP = @VALORPCOMP_FTRDC;

        IF @COPAPROPIO = 1
        BEGIN
            SET @CP_VLR_COPAGOS = @COPAGOS_CP;
            SET @VALORCOPAGO = 0;
            SET @VALORMODERADORA = 0;
            SET @VR_TOTAL = @VALORFTRD - @CP_VLR_COPAGOS;
        END
        ELSE
        BEGIN
            SET @CP_VLR_COPAGOS = @TOTAL_COPAGO_FTRDC;
            IF @MODERADORA > 0
            BEGIN
                SET @VALORMODERADORA = @MODERADORA;
                SET @VALORCOPAGO = @TOTAL_COPAGO_FTRDC - @MODERADORA;
            END
            ELSE
            BEGIN
                SET @VALORMODERADORA = 0;
                SET @VALORCOPAGO = @TOTAL_COPAGO_FTRDC;
            END
            SET @VR_TOTAL = @VALORFTRD - @VALORCOPAGO - @VALORMODERADORA;
        END

        SET @VALORSERVICIOS = @VALORFTRD;
        SET @VR_TOTAL = @VR_TOTAL - @DESCUENTO - @VR_ABONOS;

        IF @REDONDEA = 1
        BEGIN
            SET @CP_VLR_SERVICIOS = ROUND(@CP_VLR_SERVICIOS, 0);
            SET @CP_VLR_COPAGOS = ROUND(@CP_VLR_COPAGOS, 0);
            SET @CP_VLR_PAGCOMP = ROUND(@CP_VLR_PAGCOMP, 0);
            SET @VALORSERVICIOS = ROUND(@VALORSERVICIOS, 0);
            SET @VALORCOPAGO = ROUND(@VALORCOPAGO, 0);
            SET @VALORMODERADORA = ROUND(@VALORMODERADORA, 0);
            SET @VR_TOTAL = ROUND(@VR_TOTAL, 0);
            SET @VIVA = ROUND(@VIVA, 0);
        END

        UPDATE FTR
        SET
            CP_VLR_SERVICIOS = @CP_VLR_SERVICIOS,
            CP_VLR_COPAGOS = @CP_VLR_COPAGOS,
            CP_VLR_PAGCOMP = @CP_VLR_PAGCOMP,
            VALORSERVICIOS = @VALORSERVICIOS,
            VALORCOPAGO = @VALORCOPAGO,
            VALORMODERADORA = @VALORMODERADORA,
            VR_TOTAL = @VR_TOTAL,
            VIVA = @VIVA,
            PIVA = @PIVA
        WHERE N_FACTURA = @N_FACTURA;

        RETURN;
    END

    /* --- Evento / financiero (lógica original) --- */
    CREATE TABLE #TEMP (
        VALORSERVICIOS DECIMAL(14, 2),
        VALORCOPAGO DECIMAL(14, 2),
        VALORPCOMP DECIMAL(14, 2),
        COPAGOCP DECIMAL(14, 2),
        VR_TOTAL DECIMAL(14, 2),
        VIVA DECIMAL(14, 2),
        PIVA DECIMAL(7, 2)
    );

    INSERT INTO #TEMP
    SELECT
        COALESCE(SUM(VLR_SERVICI), 0),
        COALESCE(SUM(VLR_COPAGOS), 0),
        COALESCE(SUM(VLR_PAGCOMP), 0),
        COALESCE(SUM(COPAGOS_CP), 0),
        COALESCE(SUM(VR_TOTAL), 0),
        COALESCE(SUM(VIVA * CANTIDAD), 0),
        MAX(COALESCE(PIVA, 0))
    FROM FTRD
    WHERE N_FACTURA = @N_FACTURA;

    IF DBO.FNK_VALORVARIABLE('CUOTMODE_ENFACTFINAN') = 'SI'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM FTRDC
            INNER JOIN FTR ON FTRDC.CNSFTR = FTR.CNSFCT
            WHERE FTR.N_FACTURA = @N_FACTURA
              AND COALESCE(FTR.COPAPROPIO, 0) = 0
        )
        BEGIN
            SELECT @MODERADORA = SUM(FTRDC.VLR_COPAGO)
            FROM FTRDC
            INNER JOIN FTR ON FTRDC.CNSFTR = FTR.CNSFCT
            WHERE FTR.N_FACTURA = @N_FACTURA
              AND FTRDC.PROCEDENCIA <> 'HADM'
              AND COALESCE(FTR.COPAPROPIO, 0) = 0
              AND CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM MOCCD
                        WHERE TIPODEPAGO = 'Moderadora'
                          AND FTRDC.VLR_COPAGO = MOCCD.VALOR
                    ) THEN 1
                    ELSE 0
                  END = 1;
        END
    END

    UPDATE FTR
    SET
        VALORSERVICIOS = #TEMP.VALORSERVICIOS,
        VALORCOPAGO = #TEMP.VALORCOPAGO,
        VALORPCOMP = #TEMP.VALORPCOMP,
        CP_VLR_COPAGOS = #TEMP.COPAGOCP,
        VR_TOTAL =
            CASE
                WHEN COALESCE(FTR.COPAPROPIO, 0) = 1
                    THEN #TEMP.VALORSERVICIOS - (#TEMP.COPAGOCP)
                         - ISNULL(FTR.DESCUENTO, 0) - ISNULL(FTR.VR_ABONOS, 0)
                WHEN COALESCE(FTR.VALORMODERADORA, 0) > 0
                    THEN #TEMP.VALORSERVICIOS - FTR.VALORCOPAGO
                         - ISNULL(FTR.DESCUENTO, 0) - ISNULL(FTR.VR_ABONOS, 0)
                         - COALESCE(FTR.VALORMODERADORA, 0)
                ELSE #TEMP.VR_TOTAL - ISNULL(FTR.DESCUENTO, 0) - ISNULL(FTR.VR_ABONOS, 0)
            END,
        VIVA = #TEMP.VIVA,
        PIVA = #TEMP.PIVA
    FROM #TEMP
    WHERE FTR.N_FACTURA = @N_FACTURA;

    IF COALESCE(@MODERADORA, 0) > 0
    BEGIN
        UPDATE FTR
        SET
            VALORMODERADORA = @MODERADORA,
            VALORCOPAGO = VALORCOPAGO - @MODERADORA
        WHERE N_FACTURA = @N_FACTURA;
    END

    DROP TABLE #TEMP;
END

