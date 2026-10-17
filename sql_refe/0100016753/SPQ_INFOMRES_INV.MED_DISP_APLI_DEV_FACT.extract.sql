-- Extracto · SPQ_INFOMRES_INV · MED_DISP_APLI_DEV_FACT (caso 0100016753)
-- Cuerpo completo: pendiente SPQ_INFOMRES_INV.sql vía sqlix PREVERSION en esta carpeta.

   IF @METODO='MED_DISP_APLI_DEV_FACT'
   BEGIN
      DECLARE @TIPO_FECHA VARCHAR(10)
            , @F_INI DATETIME
            , @F_FIN_EXC DATETIME

      SELECT @F_INI = CONVERT(DATETIME, REPLACE(REPLACE(F_INICIAL, '-', ''), '/', ''), 112)
           , @F_FIN_EXC = DATEADD(DAY, 1, CONVERT(DATETIME, REPLACE(REPLACE(F_FINAL, '-', ''), '/', ''), 112))
           , @TIPO_FECHA = COALESCE(NULLIF(LTRIM(RTRIM(TIPO_FECHA)), ''), 'SOL')
      FROM OPENJSON(@PARAMETROS)
      WITH (
         F_INICIAL  VARCHAR(20) '$.F_INICIAL',
         F_FINAL    VARCHAR(20) '$.F_FINAL',
         TIPO_FECHA VARCHAR(10) '$.TIPO_FECHA'
      )
      -- #MED_KEYS según @TIPO_FECHA (HBALI | HPRED | default SOL/FECHASOL)
      -- #MED_DISP: SUM(IZSOLDT.CANTIDADSOL) filtrando S.FECHASOL siempre (líneas 1821-1822)
      -- #MED_APLI: HBALIDD vía IZSOLD.CNSHBALI + INSERT alterno por HBALI.NOADMISION
      -- #MED_DEV: HPRED; EXISTS permite HD.CNSHBALI vacío (líneas 1890-1891) → infla dev/fact
      -- RPDX: VALOR1..4 = dispensado, administrado, devuelto, facturado; IDTERCERO='MEDDAF'
      SELECT 'OK' OK, @CNSRPDX AS CNSRPDX
      RETURN
   END
