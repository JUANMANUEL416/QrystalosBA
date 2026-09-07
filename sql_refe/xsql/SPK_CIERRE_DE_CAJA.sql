CREATE OR ALTER PROCEDURE DBO.SPK_CIERRE_DE_CAJA
@CODCAJA          VARCHAR(4),
@SYS_COMPUTERNAME VARCHAR(254), 
@IDSEDE           VARCHAR(5),
@COMPANIA         VARCHAR(2),
@FECHA_CIERRE	  DATETIME = NULL --Se usara desde caja menor cuando quieran modificar la fecha de cierre en el modulo de caja
WITH ENCRYPTION
AS
DECLARE @NVOCONSEC VARCHAR(20)
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN

        SELECT @NVOCONSEC = CNSACJ FROM CAJ WHERE CODCAJA = @CODCAJA

        IF COALESCE(@NVOCONSEC, '') = ''
        BEGIN
            RAISERROR(N'CERRAR CAJA: La caja no tiene consecutivo de apertura (CNSACJ) configurado.', 16, 1)
        END

        IF (SELECT COUNT(1) FROM ACJ WHERE CODCAJA = @CODCAJA AND ABIERTA = 1) > 1
        BEGIN
            RAISERROR(N'La caja tiene mas de una sesion abierta en ACJ. Regularice antes de cerrar.', 16, 1)
        END

        IF NOT EXISTS (
            SELECT 1
            FROM ACJ
            WHERE CODCAJA = @CODCAJA
              AND CNSACJ = @NVOCONSEC
              AND ABIERTA = 1
        )
        BEGIN
            RAISERROR(N'CERRAR CAJA: No existe sesion abierta en ACJ para el consecutivo vigente de la caja.', 16, 1)
        END

        UPDATE CAJ SET ABIERTA = 0 WHERE CODCAJA = @CODCAJA

        UPDATE ACJ
        SET FECHACIERRE = ISNULL(@FECHA_CIERRE, GETDATE()),
            ABIERTA = 0
        WHERE CNSACJ = @NVOCONSEC
          AND CODCAJA = @CODCAJA

        INSERT INTO ACJD( CNSACJ, FORMAPAGO, TIPO, SALDO, CODCAJERO  )
        SELECT @NVOCONSEC, FORMAPAGO, 'Saldo Final', VALOR , NULL
        FROM   CAJR
        WHERE  CODCAJA = @CODCAJA
        AND    VALOR > 0

        IF EXISTS(SELECT * FROM CAJ WHERE CODCAJA=@CODCAJA AND CLASE='Menor')
        BEGIN
            COMMIT TRAN
            PRINT 'ES CAJA MENOR, NO CONTABILIZO'
            RETURN
        END

        PRINT 'CONTABILIZANDO CIERRE DE CAJA'
        IF COALESCE(DBO.FNK_VALORVARIABLE('MAN_CIERRE_CONT_CAJA'),'SI')<>'NO'
        BEGIN
            EXEC SPK_NC_CONTAB_CIERRE_CAJ @NVOCONSEC,@IDSEDE,@SYS_COMPUTERNAME,''
        END

        COMMIT TRAN
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END

