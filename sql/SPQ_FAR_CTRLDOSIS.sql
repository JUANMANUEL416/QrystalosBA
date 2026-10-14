CREATE OR ALTER PROCEDURE DBO.SPQ_FAR_CTRLDOSIS
    @JSON NVARCHAR(MAX)
WITH ENCRYPTION
AS
DECLARE @PARAMETROS NVARCHAR(MAX)
DECLARE @MODELO VARCHAR(100)
DECLARE @METODO VARCHAR(100)
DECLARE @USUARIO VARCHAR(20)
DECLARE @IDSEDE VARCHAR(5)
DECLARE @SECTOR VARCHAR(20)
DECLARE @HABITACION VARCHAR(20)
DECLARE @HORAS NVARCHAR(MAX)
DECLARE @CLASES NVARCHAR(MAX)
DECLARE @FECHA DATE
DECLARE @HELPER VARCHAR(20)
DECLARE @FECHAHOJA DATETIME
DECLARE @HORA_ACTUAL INT
BEGIN
    SET NOCOUNT ON;

    SELECT
        @MODELO = MODELO,
        @METODO = METODO,
        @USUARIO = USUARIO,
        @PARAMETROS = PARAMETROS
    FROM OPENJSON(@JSON)
    WITH (
        MODELO VARCHAR(100) '$.MODELO',
        METODO VARCHAR(100) '$.METODO',
        USUARIO VARCHAR(20) '$.USUARIO',
        PARAMETROS NVARCHAR(MAX) AS JSON
    );

    /* =====================================================================
       HELPER: combos Sede / Sector / Habitaci�n
       ===================================================================== */
    IF @METODO = 'HELPER'
    BEGIN
        SELECT
            @HELPER = METODO,
            @IDSEDE = NULLIF(LTRIM(RTRIM(IDSEDE)), ''),
            @SECTOR = NULLIF(LTRIM(RTRIM(SECTOR)), '')
        FROM OPENJSON(@PARAMETROS)
        WITH (
            METODO VARCHAR(20) '$.METODO',
            IDSEDE VARCHAR(5) '$.IDSEDE',
            SECTOR VARCHAR(20) '$.SECTOR'
        );

        IF COALESCE(@HELPER, '') = '' OR @HELPER = 'SEDE'
        BEGIN
            SELECT 'OK' OK;
            SELECT
                SED.IDSEDE value,
                SED.IDSEDE + ' - ' + SED.DESCRIPCION label
            FROM DBO.SED WITH (NOLOCK)
            ORDER BY SED.IDSEDE;
            RETURN;
        END;

        IF @HELPER = 'SECTOR'
        BEGIN
            SELECT 'OK' OK;
            SELECT
                HHAB.HABCAMA value,
                HHAB.HABCAMA + ' - ' + HHAB.DESCRIPCION label,
                HHAB.IDSEDE
            FROM DBO.HHAB WITH (NOLOCK)
            WHERE HHAB.CLASE IN ('Sector', 'SECTOR')
              AND COALESCE(HHAB.ESTADOHAB, '') <> 'Inhabilitada'
              AND (
                    COALESCE(@IDSEDE, '') = ''
                 OR COALESCE(@IDSEDE, '') IN ('TODOS', '*')
                 OR HHAB.IDSEDE = @IDSEDE
              )
            ORDER BY HHAB.HABCAMA;
            RETURN;
        END;

        IF @HELPER = 'HABITACION'
        BEGIN
            SELECT 'OK' OK;
            SELECT
                HHAB.HABCAMA value,
                HHAB.HABCAMA + ' - ' + COALESCE(HHAB.DESCRIPCION, '') label,
                HHAB.SECTOR,
                HHAB.IDSEDE
            FROM DBO.HHAB WITH (NOLOCK)
            WHERE HHAB.CLASE IN ('Habitaci�n', 'Habitacion', 'HABITACION')
              AND COALESCE(HHAB.ESTADOHAB, '') <> 'Inhabilitada'
              AND (
                    COALESCE(@SECTOR, '') = ''
                 OR COALESCE(@SECTOR, '') IN ('TODOS', '*')
                 OR HHAB.SECTOR = @SECTOR
              )
              AND (
                    COALESCE(@IDSEDE, '') = ''
                 OR COALESCE(@IDSEDE, '') IN ('TODOS', '*')
                 OR HHAB.IDSEDE = @IDSEDE
              )
            ORDER BY HHAB.HABCAMA;
            RETURN;
        END;

        SELECT 'KO' OK;
        SELECT 'HELPER no reconocido. Usar SEDE, SECTOR o HABITACION.' ERROR;
        RETURN;
    END;

    /* =====================================================================
       LISTAR: tablero control de dosis
       ===================================================================== */
    IF @METODO = 'LISTAR'
    BEGIN
        SELECT
            @IDSEDE = NULLIF(LTRIM(RTRIM(IDSEDE)), ''),
            @SECTOR = NULLIF(LTRIM(RTRIM(SECTOR)), ''),
            @HABITACION = NULLIF(LTRIM(RTRIM(HABITACION)), ''),
            @FECHA = TRY_CONVERT(DATE, FECHA)
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDSEDE VARCHAR(5) '$.IDSEDE',
            SECTOR VARCHAR(20) '$.SECTOR',
            HABITACION VARCHAR(20) '$.HABITACION',
            FECHA VARCHAR(20) '$.FECHA'
        );

        -- Array JSON requiere JSON_QUERY; sin AS JSON / JSON_QUERY el array llega NULL y el filtro no aplica
        SET @HORAS = JSON_QUERY(@PARAMETROS, '$.HORAS');
        IF @HORAS IS NULL AND JSON_VALUE(@PARAMETROS, '$.HORAS') IS NOT NULL
            SET @HORAS = CONCAT('[', JSON_VALUE(@PARAMETROS, '$.HORAS'), ']');

        SET @CLASES = JSON_QUERY(@PARAMETROS, '$.CLASES');
        IF @CLASES IS NULL AND JSON_VALUE(@PARAMETROS, '$.CLASES') IS NOT NULL
            SET @CLASES = CONCAT('[', JSON_VALUE(@PARAMETROS, '$.CLASES'), ']');

        SET @HORA_ACTUAL = DATEPART(HOUR, DBO.FNK_GETDATE());
        IF @FECHA IS NULL
        BEGIN
            IF @HORA_ACTUAL < 7
                SET @FECHA = CAST(DATEADD(DAY, -1, DBO.FNK_GETDATE()) AS DATE);
            ELSE
                SET @FECHA = CAST(DBO.FNK_GETDATE() AS DATE);
        END;
        SET @FECHAHOJA = CAST(@FECHA AS DATETIME);

        IF COALESCE(@IDSEDE, '') IN ('TODOS', '*') SET @IDSEDE = NULL;
        IF COALESCE(@SECTOR, '') IN ('TODOS', '*') SET @SECTOR = NULL;
        IF COALESCE(@HABITACION, '') IN ('TODOS', '*') SET @HABITACION = NULL;

        SELECT 'OK' OK;

        ;WITH HorasFiltro AS (
            SELECT DISTINCT HORA
            FROM (
                SELECT TRY_CONVERT(INT, LTRIM(RTRIM(value))) AS HORA
                FROM OPENJSON(
                    CASE
                        WHEN ISJSON(COALESCE(@HORAS, '')) = 1 THEN @HORAS
                        WHEN COALESCE(LTRIM(RTRIM(@HORAS)), '') = '' THEN '[]'
                        ELSE CONCAT('[', @HORAS, ']')
                    END
                )
            ) X
            WHERE HORA IS NOT NULL
              AND HORA BETWEEN 0 AND 23
        ),
        ClasesFiltro AS (
            SELECT DISTINCT UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(5), value)))) AS CLASE
            FROM OPENJSON(
                CASE
                    WHEN ISJSON(COALESCE(@CLASES, '')) = 1 THEN @CLASES
                    WHEN COALESCE(LTRIM(RTRIM(@CLASES)), '') = '' THEN '[]'
                    ELSE CONCAT('[', @CLASES, ']')
                END
            )
            WHERE NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(5), value))), '') IS NOT NULL
              AND UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(5), value)))) IN ('I', 'B', 'C', 'S')
        ),
        CamasFiltro AS (
            SELECT
                CAMA.HABCAMA,
                CAMA.DESCRIPCION AS DESC_CAMA,
                CAMA.SECTOR,
                CAMA.IDSEDE,
                CAMA.NOADMISION,
                CAMA.HABITACION,
                CAMA.TIPOESTANCIA
            FROM DBO.HHAB CAMA WITH (NOLOCK)
            WHERE CAMA.CLASE = 'Cama'
              AND CAMA.ESTADOHAB = 'Ocupada'
              AND COALESCE(CAMA.NOADMISION, '') <> ''
              AND (@IDSEDE IS NULL OR CAMA.IDSEDE = @IDSEDE)
              AND (@SECTOR IS NULL OR CAMA.SECTOR = @SECTOR)
              AND (
                    @HABITACION IS NULL
                 OR CAMA.HABITACION = @HABITACION
                 OR EXISTS (
                        SELECT 1
                        FROM DBO.HHAB HAB WITH (NOLOCK)
                        WHERE HAB.HABCAMA = @HABITACION
                          AND HAB.CLASE IN ('Habitaci�n', 'Habitacion', 'HABITACION')
                          AND (
                                CAMA.HABITACION = HAB.HABCAMA
                             OR CAMA.HABCAMA LIKE HAB.HABCAMA + '%'
                          )
                    )
              )
        ),
        Keys AS (
            SELECT DISTINCT
                CAMA.NOADMISION,
                HHOM.IDSERVICIO,
                COALESCE(HHOM.CODOM, '') AS CODOM
            FROM CamasFiltro CAMA
            INNER JOIN DBO.HHOM WITH (NOLOCK)
                ON HHOM.NOADMISION = CAMA.NOADMISION
               AND (
                    COALESCE(HHOM.ESTADO, 'A') IN ('A', 'S', '')
                    OR HHOM.ESTADO IS NULL
               )
            INNER JOIN DBO.SER WITH (NOLOCK)
                ON SER.IDSERVICIO = HHOM.IDSERVICIO
               AND COALESCE(SER.MEDICAMENTOS, 0) = 1

            UNION

            SELECT DISTINCT
                CAMA.NOADMISION,
                E.IDSERVICIO,
                COALESCE(E.CODOM, '') AS CODOM
            FROM CamasFiltro CAMA
            INNER JOIN DBO.FAR_OM_EVENTO E WITH (NOLOCK)
                ON E.NOADMISION = CAMA.NOADMISION
               AND E.VIGENTE = 1
            INNER JOIN DBO.SER WITH (NOLOCK)
                ON SER.IDSERVICIO = E.IDSERVICIO
               AND COALESCE(SER.MEDICAMENTOS, 0) = 1
        ),
        Base AS (
            SELECT
                CAMA.HABCAMA,
                CAMA.DESC_CAMA,
                CAMA.SECTOR,
                CAMA.IDSEDE,
                HADM.NOADMISION,
                HADM.IDAFILIADO,
                AFI.TIPO_DOC,
                AFI.DOCIDAFILIADO,
                AFI.NOMBREAFI,
                HHOM.ITEM AS HHOM_ITEM,
                K.IDSERVICIO,
                K.CODOM,
                HHOM.ESTADO AS HHOM_ESTADO,
                HHOM.CANTIDAD AS HHOM_CANTIDAD,
                HHOM.FRECUENCIA AS HHOM_FRECUENCIA,
                HHOM.DURACION AS HHOM_DURACION,
                HHOM.VIA AS HHOM_VIA,
                HHOM.FECHAINI AS HHOM_FECHAINI,
                HHOM.CONSECUTIVO AS HHOM_CONSECUTIVO,
                HHOM.ITEMRED AS HHOM_ITEMRED,
                SER.DESCSERVICIO,
                SER.PRESUNI,
                SER.IDARTICULO,
                HBALI.CNSHBALI,
                HBALID.H00, HBALID.H00EST,
                HBALID.H01, HBALID.H01EST,
                HBALID.H02, HBALID.H02EST,
                HBALID.H03, HBALID.H03EST,
                HBALID.H04, HBALID.H04EST,
                HBALID.H05, HBALID.H05EST,
                HBALID.H06, HBALID.H06EST,
                HBALID.H07, HBALID.H07EST,
                HBALID.H08, HBALID.H08EST,
                HBALID.H09, HBALID.H09EST,
                HBALID.H10, HBALID.H10EST,
                HBALID.H11, HBALID.H11EST,
                HBALID.H12, HBALID.H12EST,
                HBALID.H13, HBALID.H13EST,
                HBALID.H14, HBALID.H14EST,
                HBALID.H15, HBALID.H15EST,
                HBALID.H16, HBALID.H16EST,
                HBALID.H17, HBALID.H17EST,
                HBALID.H18, HBALID.H18EST,
                HBALID.H19, HBALID.H19EST,
                HBALID.H20, HBALID.H20EST,
                HBALID.H21, HBALID.H21EST,
                HBALID.H22, HBALID.H22EST,
                HBALID.H23, HBALID.H23EST,
                EVT.CONSECUTIVO AS ORD_CONSECUTIVO,
                EVT.CLASE AS EVT_CLASE,
                EVT.OBSERVACION AS EVT_OBSERVACION,
                EVT.PRESCRIPCION AS EVT_PRESCRIPCION,
                EVT.VIA AS EVT_VIA,
                EVT.CANTIDAD AS EVT_CANTIDAD,
                EVT.FRECUENCIA AS EVT_FRECUENCIA,
                EVT.FECHAEVENTO AS EVT_FECHA,
                EVT.HCA_FECHA,
                EVT.HCATD_CANTIDAD,
                EVT.HCATD_FRECUENCIA,
                EST.ESTANCIA,
                IZS.CANTIDADSOL,
                IZS.CANTIDAD_DISPENSADA,
                IZS.FECHA_DISPENSACION
            FROM Keys K
            INNER JOIN CamasFiltro CAMA
                ON CAMA.NOADMISION = K.NOADMISION
            INNER JOIN DBO.HADM WITH (NOLOCK) ON HADM.NOADMISION = K.NOADMISION
            INNER JOIN DBO.AFI WITH (NOLOCK) ON AFI.IDAFILIADO = HADM.IDAFILIADO
            INNER JOIN DBO.SER WITH (NOLOCK)
                ON SER.IDSERVICIO = K.IDSERVICIO
               AND COALESCE(SER.MEDICAMENTOS, 0) = 1
            OUTER APPLY (
                SELECT TOP (1)
                    H.ITEM,
                    H.ESTADO,
                    H.CANTIDAD,
                    H.FRECUENCIA,
                    H.DURACION,
                    H.VIA,
                    H.FECHAINI,
                    H.CONSECUTIVO,
                    H.ITEMRED
                FROM DBO.HHOM H WITH (NOLOCK)
                WHERE H.NOADMISION = K.NOADMISION
                  AND H.IDSERVICIO = K.IDSERVICIO
                  AND COALESCE(H.CODOM, '') = K.CODOM
                  AND (
                        COALESCE(H.ESTADO, 'A') IN ('A', 'S', '')
                        OR H.ESTADO IS NULL
                   )
                ORDER BY
                    CASE WHEN COALESCE(H.ESTADO, '') = 'S' THEN 0 ELSE 1 END,
                    H.ITEM DESC
            ) HHOM
            LEFT JOIN DBO.HBALI WITH (NOLOCK)
                ON HBALI.NOADMISION = HADM.NOADMISION
               AND CAST(HBALI.FECHA AS DATE) = @FECHA
            LEFT JOIN DBO.HBALID WITH (NOLOCK)
                ON HBALID.CNSHBALI = HBALI.CNSHBALI
               AND HBALID.IDSERVICIO = K.IDSERVICIO
               AND HBALID.TIPO = 'HOJA TRAT'
            OUTER APPLY (
                SELECT TOP (1)
                    E.CONSECUTIVO,
                    E.CLASE,
                    E.OBSERVACION,
                    E.PRESCRIPCION,
                    E.VIA,
                    E.CANTIDAD,
                    E.FRECUENCIA,
                    E.FECHAEVENTO,
                    E.ITEMRED,
                    E.CODOM,
                    HCA.FECHA AS HCA_FECHA,
                    HCATD.CANTIDAD AS HCATD_CANTIDAD,
                    HCATD.FRECUENCIA AS HCATD_FRECUENCIA
                FROM DBO.FAR_OM_EVENTO E WITH (NOLOCK)
                LEFT JOIN DBO.HCA WITH (NOLOCK)
                    ON HCA.CONSECUTIVO = E.CONSECUTIVO
                LEFT JOIN DBO.HCATD WITH (NOLOCK)
                    ON HCATD.CONSECUTIVO = E.CONSECUTIVO
                   AND HCATD.IDSERVICIO = E.IDSERVICIO
                   AND COALESCE(HCATD.CODOM, '') = COALESCE(E.CODOM, '')
                   AND (E.ITEMRED IS NULL OR HCATD.ITEMRED = E.ITEMRED)
                WHERE E.NOADMISION = K.NOADMISION
                  AND E.IDSERVICIO = K.IDSERVICIO
                  AND COALESCE(E.CODOM, '') = K.CODOM
                  AND E.VIGENTE = 1
                ORDER BY E.FECHAEVENTO DESC, HCATD.ID DESC
            ) EVT
            OUTER APPLY (
                SELECT TOP (1)
                    COALESCE(TG.DESCRIPCION, CO.TIPOESTANCIA) AS ESTANCIA
                FROM (
                    SELECT COALESCE(
                        (SELECT TOP (1) HN.TIPOESTANCIA
                         FROM DBO.HNAT HN WITH (NOLOCK)
                         WHERE HN.NOADMISION = HADM.NOADMISION
                         ORDER BY HN.FECHA DESC, HN.NOITEM DESC),
                        HADM.TIPOESTANCIA,
                        CAMA.TIPOESTANCIA
                    ) AS TIPOESTANCIA
                ) CO
                LEFT JOIN DBO.TGEN TG WITH (NOLOCK)
                    ON TG.TABLA = 'GENERAL'
                   AND TG.CAMPO = 'CLASEHOSP'
                   AND TG.CODIGO = CO.TIPOESTANCIA
            ) EST
            -- Cantidades como CANTIDADES_INICIO_OM / EXPORTA_POR_ENTREGAR:
            -- Solicitado = SUM(IZSOLD.CANTIDADSOL) PR/IN de la solicitud m�s reciente del servicio.
            -- Dispensado = SUM(IZSOLDT.CANTIDADSOL) con IMOV confirmado (ESTADO=1). Nunca IZSOLD.CANTIDAD.
            OUTER APPLY (
                SELECT TOP (1)
                    S.CNSIZSOL,
                    S.FECHASOL
                FROM DBO.IZSOL S WITH (NOLOCK)
                INNER JOIN DBO.IZSOLD D WITH (NOLOCK) ON D.CNSIZSOL = S.CNSIZSOL
                INNER JOIN DBO.IART A WITH (NOLOCK) ON A.IDARTICULO = D.IDARTICULO
                WHERE S.NOADMISION = HADM.NOADMISION
                  AND COALESCE(D.IDSERVICIO, A.IDSERVICIO) = K.IDSERVICIO
                  AND COALESCE(NULLIF(LTRIM(RTRIM(D.TIPOM)), ''), 'PR') IN ('PR', 'IN')
                ORDER BY
                    S.FECHASOL DESC,
                    S.CNSIZSOL DESC
            ) IZS_SOL
            OUTER APPLY (
                SELECT
                    CAST(SUM(COALESCE(D.CANTIDADSOL, 0)) AS DECIMAL(18, 2)) AS CANTIDADSOL
                FROM DBO.IZSOLD D WITH (NOLOCK)
                INNER JOIN DBO.IART A WITH (NOLOCK) ON A.IDARTICULO = D.IDARTICULO
                WHERE D.CNSIZSOL = IZS_SOL.CNSIZSOL
                  AND COALESCE(D.IDSERVICIO, A.IDSERVICIO) = K.IDSERVICIO
                  AND COALESCE(NULLIF(LTRIM(RTRIM(D.TIPOM)), ''), 'PR') IN ('PR', 'IN')
            ) IZS_CANT
            OUTER APPLY (
                SELECT
                    CAST(SUM(COALESCE(T.CANTIDADSOL, 0)) AS DECIMAL(18, 2)) AS CANTIDAD_DISPENSADA,
                    MAX(M.FECHACONF) AS FECHA_DISPENSACION
                FROM DBO.IZSOLD D WITH (NOLOCK)
                INNER JOIN DBO.IART A WITH (NOLOCK) ON A.IDARTICULO = D.IDARTICULO
                INNER JOIN DBO.IZSOLDT T WITH (NOLOCK) ON T.CNSIZSOLD = D.CNSIZSOLD
                INNER JOIN DBO.IMOV M WITH (NOLOCK)
                    ON M.CNSMOV = T.CNSMOV
                   AND COALESCE(M.ESTADO, 0) = 1
                WHERE D.CNSIZSOL = IZS_SOL.CNSIZSOL
                  AND COALESCE(D.IDSERVICIO, A.IDSERVICIO) = K.IDSERVICIO
                  AND COALESCE(NULLIF(LTRIM(RTRIM(D.TIPOM)), ''), 'PR') IN ('PR', 'IN')
            ) IZS_DISP
            OUTER APPLY (
                SELECT
                    IZS_CANT.CANTIDADSOL,
                    CASE
                        WHEN COALESCE(IZS_DISP.CANTIDAD_DISPENSADA, 0) > COALESCE(IZS_CANT.CANTIDADSOL, 0)
                        THEN IZS_CANT.CANTIDADSOL
                        ELSE COALESCE(IZS_DISP.CANTIDAD_DISPENSADA, 0)
                    END AS CANTIDAD_DISPENSADA,
                    CASE
                        WHEN COALESCE(IZS_DISP.CANTIDAD_DISPENSADA, 0) > 0
                        THEN IZS_DISP.FECHA_DISPENSACION
                        ELSE NULL
                    END AS FECHA_DISPENSACION
            ) IZS
        )
        SELECT
            B.HABCAMA AS CAMA,
            B.DESC_CAMA,
            B.SECTOR,
            B.IDSEDE,
            B.NOADMISION,
            B.IDAFILIADO,
            LTRIM(RTRIM(COALESCE(B.TIPO_DOC, ''))) + ' ' + LTRIM(RTRIM(COALESCE(B.DOCIDAFILIADO, ''))) AS IDENTIFICACION,
            B.DOCIDAFILIADO,
            B.NOMBREAFI,
            B.IDSERVICIO,
            B.DESCSERVICIO,
            MEDICAMENTO = B.IDSERVICIO + ' - ' + B.DESCSERVICIO,
            DOSIS = COALESCE(
                NULLIF(LTRIM(RTRIM(B.EVT_PRESCRIPCION)), ''),
                LTRIM(RTRIM(
                    COALESCE(CONVERT(VARCHAR(30), CONVERT(DECIMAL(18, 2), COALESCE(B.EVT_CANTIDAD, B.HHOM_CANTIDAD))), '')
                    + ' '
                    + COALESCE(B.PRESUNI, '')
                    + CASE
                        WHEN COALESCE(B.EVT_FRECUENCIA, B.HHOM_FRECUENCIA, 0) > 0
                        THEN ' Cada ' + CONVERT(VARCHAR(10), CONVERT(INT, COALESCE(B.EVT_FRECUENCIA, B.HHOM_FRECUENCIA))) + ' Horas'
                        ELSE ''
                      END
                ))
            ),
            FRECUENCIA_TXT = CASE
                WHEN COALESCE(B.EVT_FRECUENCIA, B.HHOM_FRECUENCIA, 0) > 0
                THEN 'Cada ' + CONVERT(VARCHAR(10), CONVERT(INT, COALESCE(B.EVT_FRECUENCIA, B.HHOM_FRECUENCIA))) + ' Horas'
                ELSE ''
            END,
            HORARIO_PROG = (
                SELECT STUFF((
                    SELECT '-' + RIGHT('0' + CONVERT(VARCHAR(2), H.HORA), 2)
                    FROM (VALUES
                        (7, B.H07, B.H07EST),(8, B.H08, B.H08EST),(9, B.H09, B.H09EST),(10, B.H10, B.H10EST),
                        (11, B.H11, B.H11EST),(12, B.H12, B.H12EST),(13, B.H13, B.H13EST),(14, B.H14, B.H14EST),
                        (15, B.H15, B.H15EST),(16, B.H16, B.H16EST),(17, B.H17, B.H17EST),(18, B.H18, B.H18EST),
                        (19, B.H19, B.H19EST),(20, B.H20, B.H20EST),(21, B.H21, B.H21EST),(22, B.H22, B.H22EST),
                        (23, B.H23, B.H23EST),(0, B.H00, B.H00EST),(1, B.H01, B.H01EST),(2, B.H02, B.H02EST),
                        (3, B.H03, B.H03EST),(4, B.H04, B.H04EST),(5, B.H05, B.H05EST),(6, B.H06, B.H06EST)
                    ) H(HORA, VALOR, ESTADO)
                    WHERE COALESCE(H.VALOR, 0) > 0 AND COALESCE(H.ESTADO, 0) BETWEEN 1 AND 4
                    ORDER BY CASE WHEN H.HORA >= 7 THEN H.HORA ELSE H.HORA + 24 END
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(200)'), 1, 1, '')
            ),
            HORAS_JSON = (
                SELECT
                    H.HORA,
                    COALESCE(H.VALOR, 0) AS VALOR,
                    COALESCE(H.ESTADO, 0) AS ESTADO,
                    D.NOMBREMED,
                    D.RAZONNOAPLICA
                FROM (VALUES
                    (7, B.H07, B.H07EST),(8, B.H08, B.H08EST),(9, B.H09, B.H09EST),(10, B.H10, B.H10EST),
                    (11, B.H11, B.H11EST),(12, B.H12, B.H12EST),(13, B.H13, B.H13EST),(14, B.H14, B.H14EST),
                    (15, B.H15, B.H15EST),(16, B.H16, B.H16EST),(17, B.H17, B.H17EST),(18, B.H18, B.H18EST),
                    (19, B.H19, B.H19EST),(20, B.H20, B.H20EST),(21, B.H21, B.H21EST),(22, B.H22, B.H22EST),
                    (23, B.H23, B.H23EST),(0, B.H00, B.H00EST),(1, B.H01, B.H01EST),(2, B.H02, B.H02EST),
                    (3, B.H03, B.H03EST),(4, B.H04, B.H04EST),(5, B.H05, B.H05EST),(6, B.H06, B.H06EST)
                ) H(HORA, VALOR, ESTADO)
                OUTER APPLY (
                    SELECT TOP (1)
                        MED.NOMBRE AS NOMBREMED,
                        COALESCE(TGEN.DESCRIPCION, '') AS RAZONNOAPLICA
                    FROM DBO.HBALIDD WITH (NOLOCK)
                    LEFT JOIN DBO.MED WITH (NOLOCK) ON MED.IDMEDICO = HBALIDD.IDAPLICA
                    LEFT JOIN DBO.TGEN WITH (NOLOCK)
                        ON TGEN.TABLA = 'HTX'
                       AND TGEN.CAMPO = 'CLASENOAPLICA'
                       AND TGEN.CODIGO = HBALIDD.CLASENOAPLICA
                    WHERE HBALIDD.CNSHBALI = B.CNSHBALI
                      AND HBALIDD.IDSERVICIO = B.IDSERVICIO
                      AND HBALIDD.HORA = H.HORA
                    ORDER BY COALESCE(HBALIDD.FECHAAPLICA, HBALIDD.F_ULTIMA, HBALIDD.FECHA) DESC
                ) D
                ORDER BY CASE WHEN H.HORA >= 7 THEN H.HORA ELSE H.HORA + 24 END
                FOR JSON PATH
            ),
            B.ESTANCIA,
            OBSERVACION = B.EVT_OBSERVACION,
            VIA = COALESCE(
                VIA_TGEN.DESCRIPCION,
                NULLIF(LTRIM(RTRIM(B.EVT_VIA)), ''),
                NULLIF(LTRIM(RTRIM(B.HHOM_VIA)), '')
            ),
            CANTIDAD = COALESCE(B.HCATD_CANTIDAD, B.EVT_CANTIDAD, B.HHOM_CANTIDAD),
            FRECUENCIA = COALESCE(B.HCATD_FRECUENCIA, B.EVT_FRECUENCIA, B.HHOM_FRECUENCIA),
            FECHA_HCA = B.HCA_FECHA,
            ESTADO = CASE
                WHEN COALESCE(B.HHOM_ESTADO, '') = 'S' OR B.EVT_CLASE = 'S' THEN 'Suspendido'
                WHEN B.EVT_CLASE = 'B' THEN 'Cambiado'
                ELSE 'Activo'
            END,
            EVT_CLASE = B.EVT_CLASE,
            NORDEN = COALESCE(B.ORD_CONSECUTIVO, B.HHOM_CONSECUTIVO),
            B.CANTIDADSOL,
            B.CANTIDAD_DISPENSADA,
            B.FECHA_DISPENSACION,
            B.HHOM_ITEM,
            B.CODOM,
            FECHA_HOJA = @FECHA,
            IFACT.CNSIF,
            IFACT.IF_ESTADO,
            IFACT.IF_DESCRIPCION,
            IFACT.IF_PRM,
            IFACT.ACEPTADA,
            IFACT.FECHA_ACEPTA,
            IFACT.NOMBRE_ACEPTA,
            IFACT.OBS_ACEPTA,
            IFACT.OBSERVACION_QCO,
            IFACT.FECHA_IF,
            IF_PENDIENTES = COALESCE(IFCNT.IF_PENDIENTES, 0),
            PROA.PROA_ESTADO,
            PROA.PROA_FECHA_VENCE,
            PROA.PROA_DIAS_TRAT,
            PROA.PROA_DIAS_AUT,
            PROA.PROA_OBSERVACION,
            PROA.PROA_CNSPROA,
            PROA.PROA_CONSECUTIVO_INICIAR,
            ENTREVISTA_ESTADO = CASE
                WHEN ENTC.CNSENTC IS NOT NULL THEN 'Diligenciada'
                ELSE 'Pendiente'
            END,
            ENTC.CNSENTC
        FROM Base B
        OUTER APPLY (
            SELECT TOP (1) E.CNSENTC
            FROM DBO.FAR_ENTC E WITH (NOLOCK)
            WHERE E.NOADMISION COLLATE DATABASE_DEFAULT = B.NOADMISION COLLATE DATABASE_DEFAULT
              AND E.ESTADO_REG = 'A'
            ORDER BY E.FECHAREG DESC
        ) ENTC
        OUTER APPLY (
            SELECT TOP (1) V.DESCRIPCION
            FROM DBO.TGEN V WITH (NOLOCK)
            WHERE V.TABLA = 'General'
              AND V.CAMPO = 'VIAAPLICACION'
              AND NULLIF(LTRIM(RTRIM(COALESCE(B.EVT_VIA, B.HHOM_VIA))), '') IS NOT NULL
              AND (
                    LTRIM(RTRIM(V.CODIGO)) = LTRIM(RTRIM(COALESCE(B.EVT_VIA, B.HHOM_VIA)))
                 OR LOWER(LTRIM(RTRIM(V.DESCRIPCION))) = LOWER(LTRIM(RTRIM(COALESCE(B.EVT_VIA, B.HHOM_VIA))))
              )
        ) VIA_TGEN
        OUTER APPLY (
            /* PROA del Iniciar original (NOADMISION+IDSERVICIO). No usa CONSECUTIVO del pedido 24h. */
            SELECT TOP (1)
                P.ESTADO AS PROA_ESTADO,
                P.FECHA_VENCE AS PROA_FECHA_VENCE,
                P.DIAS_TRATAMIENTO AS PROA_DIAS_TRAT,
                COALESCE(P.DIAS_AUTORIZADOS, P.DIAS_TRATAMIENTO) AS PROA_DIAS_AUT,
                P.OBSERVACION AS PROA_OBSERVACION,
                P.CNSPROA AS PROA_CNSPROA,
                COALESCE(INI.CONSECUTIVO, P.CONSECUTIVO) AS PROA_CONSECUTIVO_INICIAR
            FROM DBO.HCATD_PROA P WITH (NOLOCK)
            OUTER APPLY (
                SELECT TOP (1) H.CONSECUTIVO
                FROM DBO.HCATD H WITH (NOLOCK)
                INNER JOIN DBO.HCA C WITH (NOLOCK) ON C.CONSECUTIVO = H.CONSECUTIVO
                WHERE C.NOADMISION = B.NOADMISION
                  AND H.IDSERVICIO = B.IDSERVICIO
                  AND H.CLASE = 'I'
                  AND COALESCE(C.ANULADA, 0) <> 1
                ORDER BY C.FECHA ASC, H.CONSECUTIVO ASC
            ) INI
            WHERE P.ESTADO_REG = 'A'
              AND P.NOADMISION = B.NOADMISION
              AND P.IDSERVICIO = B.IDSERVICIO
            ORDER BY
                CASE WHEN INI.CONSECUTIVO IS NOT NULL AND P.CONSECUTIVO = INI.CONSECUTIVO THEN 0 ELSE 1 END,
                P.FECHA_SOL ASC
        ) PROA
        OUTER APPLY (
            /* PRM / IF activa m�s reciente de la l�nea OM (no cerrada).
               Match por admisi�n+servicio+CODOM (l�nea), sin exigir CONSECUTIVO:
               tras reabrir/nueva OM el consecutivo de la fila puede diferir del FAR_IF. */
            SELECT TOP (1)
                F.CNSIF,
                F.ESTADO AS IF_ESTADO,
                COALESCE(NULLIF(LTRIM(RTRIM(F.IF_TEXTO)), ''), CAT.DESCRIPCION, '') AS IF_DESCRIPCION,
                CAT.CONV_GRANADA AS IF_PRM,
                F.ACEPTADA,
                F.FECHA_ACEPTA,
                F.NOMBRE_ACEPTA,
                F.OBS_ACEPTA,
                F.OBSERVACION_QCO,
                F.FECHA_IF
            FROM DBO.FAR_IF F WITH (NOLOCK)
            LEFT JOIN DBO.FAR_IFCAT CAT WITH (NOLOCK)
                ON CAT.IDIFCAT COLLATE DATABASE_DEFAULT = F.IDIFCAT COLLATE DATABASE_DEFAULT
            WHERE F.NOADMISION COLLATE DATABASE_DEFAULT = B.NOADMISION COLLATE DATABASE_DEFAULT
              AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = B.IDSERVICIO COLLATE DATABASE_DEFAULT
              AND COALESCE(F.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(B.CODOM, '') COLLATE DATABASE_DEFAULT
              AND F.ESTADO_REG = 'A'
              AND F.ESTADO <> 'Cerrado'
            ORDER BY F.FECHA_IF DESC, F.CNSIF DESC
        ) IFACT
        OUTER APPLY (
            SELECT COUNT(*) AS IF_PENDIENTES
            FROM DBO.FAR_IF F WITH (NOLOCK)
            WHERE F.NOADMISION COLLATE DATABASE_DEFAULT = B.NOADMISION COLLATE DATABASE_DEFAULT
              AND F.IDSERVICIO COLLATE DATABASE_DEFAULT = B.IDSERVICIO COLLATE DATABASE_DEFAULT
              AND COALESCE(F.CODOM, '') COLLATE DATABASE_DEFAULT = COALESCE(B.CODOM, '') COLLATE DATABASE_DEFAULT
              AND F.ESTADO_REG = 'A'
              AND F.ESTADO <> 'Cerrado'
        ) IFCNT
        WHERE
            (
                NOT EXISTS (SELECT 1 FROM HorasFiltro)
                OR EXISTS (
                    SELECT 1
                    FROM (VALUES
                        (0, B.H00, B.H00EST),(1, B.H01, B.H01EST),(2, B.H02, B.H02EST),(3, B.H03, B.H03EST),
                        (4, B.H04, B.H04EST),(5, B.H05, B.H05EST),(6, B.H06, B.H06EST),(7, B.H07, B.H07EST),
                        (8, B.H08, B.H08EST),(9, B.H09, B.H09EST),(10, B.H10, B.H10EST),(11, B.H11, B.H11EST),
                        (12, B.H12, B.H12EST),(13, B.H13, B.H13EST),(14, B.H14, B.H14EST),(15, B.H15, B.H15EST),
                        (16, B.H16, B.H16EST),(17, B.H17, B.H17EST),(18, B.H18, B.H18EST),(19, B.H19, B.H19EST),
                        (20, B.H20, B.H20EST),(21, B.H21, B.H21EST),(22, B.H22, B.H22EST),(23, B.H23, B.H23EST)
                    ) H(HORA, VALOR, ESTADO)
                    INNER JOIN HorasFiltro F ON F.HORA = H.HORA
                    WHERE COALESCE(H.VALOR, 0) > 0
                      AND COALESCE(H.ESTADO, 0) BETWEEN 1 AND 4
                )
            )
            AND (
                NOT EXISTS (SELECT 1 FROM ClasesFiltro)
                OR EXISTS (
                    SELECT 1
                    FROM ClasesFiltro CF
                    WHERE CF.CLASE = UPPER(LTRIM(RTRIM(COALESCE(B.EVT_CLASE, ''))))
                )
            )
            /* Suspendidos: solo �ltimas 24 h (ventana m�vil sobre FECHAEVENTO / EVT_FECHA).
               Activos / cambiados / continuar no se filtran por antig�edad. */
            AND (
                NOT (
                    COALESCE(B.HHOM_ESTADO, '') = 'S'
                 OR COALESCE(B.EVT_CLASE, '') = 'S'
                )
                OR (
                    B.EVT_FECHA IS NOT NULL
                    AND B.EVT_FECHA >= DATEADD(HOUR, -24, GETDATE())
                )
            )
        ORDER BY B.SECTOR, B.HABCAMA, B.NOMBREAFI, B.DESCSERVICIO;

        RETURN;
    END;

    /* =====================================================================
       CONTAR_PENDIENTES_INICIO: HBALINI I/P en sectores INICIATRATFAR=1
       ===================================================================== */
    IF @METODO = 'CONTAR_PENDIENTES_INICIO'
    BEGIN
        SELECT
            @IDSEDE = NULLIF(LTRIM(RTRIM(IDSEDE)), ''),
            @SECTOR = NULLIF(LTRIM(RTRIM(SECTOR)), '')
        FROM OPENJSON(@PARAMETROS)
        WITH (
            IDSEDE VARCHAR(5) '$.IDSEDE',
            SECTOR VARCHAR(20) '$.SECTOR'
        );

        IF COL_LENGTH('DBO.HHAB', 'INICIATRATFAR') IS NULL
        BEGIN
            SELECT 'KO' OK;
            SELECT ERROR = 'La columna HHAB.INICIATRATFAR no existe. Ejecute el script de migraci�n.';
            RETURN;
        END;

        SELECT 'OK' OK;
        SELECT COUNT(1) AS PENDIENTES
        FROM DBO.HBALINI H WITH (NOLOCK)
        INNER JOIN DBO.HHAB C WITH (NOLOCK)
            ON C.NOADMISION = H.NOADMISION
           AND C.CLASE IN ('Cama', 'CAMA')
           AND C.ESTADOHAB = 'Ocupada'
        INNER JOIN DBO.HHAB S WITH (NOLOCK)
            ON S.HABCAMA = C.SECTOR
           AND S.CLASE IN ('Sector', 'SECTOR')
           AND COALESCE(S.INICIATRATFAR, 0) = 1
        WHERE H.ESTADO IN ('I', 'P')
          AND (
                COALESCE(@IDSEDE, '') = ''
             OR COALESCE(@IDSEDE, '') IN ('TODOS', '*')
             OR C.IDSEDE = @IDSEDE
             OR S.IDSEDE = @IDSEDE
          )
          AND (
                COALESCE(@SECTOR, '') = ''
             OR COALESCE(@SECTOR, '') IN ('TODOS', '*')
             OR C.SECTOR = @SECTOR
          );

        RETURN;
    END;

    SELECT 'KO' OK;
    SELECT 'M�todo no soportado. Usar HELPER, LISTAR o CONTAR_PENDIENTES_INICIO.' ERROR;
END
