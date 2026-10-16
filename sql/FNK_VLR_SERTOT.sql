IF EXISTS(SELECT NAME FROM SYSOBJECTS WHERE NAME='FNK_VLR_SERTOT' AND XTYPE='FN')
BEGIN
   DROP FUNCTION FNK_VLR_SERTOT
END
GO
CREATE FUNCTION DBO.FNK_VLR_SERTOT (@IDTERCERO  VARCHAR(20),
                                    @IDPLAN     VARCHAR(6),
                                    @IDSERVICIO VARCHAR(20),
                                    @FECHA      DATETIME
                                     )
RETURNS DECIMAL(14,2)
WITH ENCRYPTION
AS
BEGIN
   DECLARE @VALOR      DECIMAL(14,2)
   DECLARE @PIVA DECIMAL(7,2)
   DECLARE @VIVA DECIMAL(14,2)
          
            SELECT @VALOR = VLRSERVICIO
            FROM   SERTOT WITH(NOLOCK)
            WHERE  IDTERCERO  = @IDTERCERO
            AND    IDPLAN     = @IDPLAN
            AND    IDSERVICIO = @IDSERVICIO
            AND    @FECHA     >= FECHAINIFD 
            AND    @FECHA     <= FECHAFINFD
            AND    @FECHA     >= FECHAINI   
            AND    @FECHA     <= FECHAFIN
   RETURN(@VALOR)
END
