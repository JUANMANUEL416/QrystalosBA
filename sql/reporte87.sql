SELECT
    CC_PACIENTE,
    NOMBRE_PACIENTE,
    ENTIDAD,
    COALESCE(alergico, 'NO') AS "¿Es alérgico a algún medicamento o alimento?",
    CASE
        WHEN UPPER(LEFT(COALESCE(alergico, 'NO'), 2)) = 'SI' THEN COALESCE(cual, 'Sin respuesta')
        ELSE COALESCE(cual, 'No aplica')
    END AS "¿CUAL?",
    COALESCE(sala, 'NO') AS "¿El paciente se encuentra en sala de aplicaciones?",
    CASE
        WHEN UPPER(LEFT(COALESCE(sala, 'NO'), 2)) = 'SI' THEN COALESCE(med_aplica, 'Sin respuesta')
        ELSE COALESCE(med_aplica, 'No aplica')
    END AS "¿Qué medicamento se está aplicando?",
    COALESCE(frec_reclama, 'Sin respuesta') AS "¿Con que frecuencia reclama sus medicamentos?",
    COALESCE(tiene_med, 'NO') AS "¿Actualmente tiene los medicamentos de su tratamiento?",
    CASE
        WHEN UPPER(LEFT(COALESCE(tiene_med, 'NO'), 2)) = 'SI' THEN COALESCE(motivo, 'No aplica')
        ELSE COALESCE(motivo, 'Sin respuesta')
    END AS "¿Cuál es el motivo principal por el cual no tiene los medicamentos completos?",
    CASE
        WHEN UPPER(LEFT(COALESCE(tiene_med, 'NO'), 2)) = 'SI' THEN COALESCE(faltan, 'No aplica')
        ELSE COALESCE(faltan, 'Sin respuesta')
    END AS "¿Qué medicamentos le hacen falta actualmente?",
    CASE
        WHEN UPPER(LEFT(COALESCE(tiene_med, 'NO'), 2)) = 'SI' THEN COALESCE(desde, 'No aplica')
        ELSE COALESCE(desde, 'Sin respuesta')
    END AS "¿Desde cuándo le faltan medicamentos?",
    COALESCE(hospitalizado, 'NO') AS "¿La suspensión u olvido lo ha llevado a estar hospitalizado?",
    CASE
        WHEN UPPER(LEFT(COALESCE(hospitalizado, 'NO'), 2)) = 'SI' THEN COALESCE(med_hosp, 'Sin respuesta')
        ELSE COALESCE(med_hosp, 'No aplica')
    END AS "¿Sabe que medicamento le han administrado durante la hospitalización?",
    COALESCE(naturales, 'No') AS "¿Toma productos naturales, fito terapéuticos o infusiones?",
    COALESCE(clara, 'NO') AS "¿Tiene clara la terapia farmacológica actual?",
    COALESCE(menciona, 'Sin respuesta') AS "¿Puede mencionar cada medicamento, cómo y en qué horario lo toma?",
    COALESCE(suspendio, 'Sin respuesta') AS "¿Ha suspendido la terapia farmacológica? ¿Por qué?",
    COALESCE(olvida, 'NO') AS "¿Olvida usted tomar sus medicamentos?",
    CASE
        WHEN UPPER(LEFT(COALESCE(olvida, 'NO'), 2)) = 'SI' THEN COALESCE(frec_olvida, 'Sin respuesta')
        ELSE COALESCE(frec_olvida, 'No aplica')
    END AS "¿Con que frecuencia olvida?",
    COALESCE(biologicos, 'NO') AS "¿Ha tomado medicamentos biológicos?",
    COALESCE(sabe_ram, 'NO') AS "¿Sabe qué es una reacción adversa?",
    COALESCE(cae_mal, 'NO') AS "¿Siente que alguno de sus medicamentos le cae mal?",
    CASE
        WHEN UPPER(LEFT(COALESCE(cae_mal, 'NO'), 2)) = 'SI' THEN COALESCE(tipo_reaccion, 'Sin respuesta')
        ELSE COALESCE(tipo_reaccion, 'No aplica')
    END AS "¿Qué tipo de reacción experimentó?",
    COALESCE(adherente, 'NO') AS "¿El paciente es adherente al tratamiento?",
    COALESCE(gestion, 'No') AS "¿Se le realiza alguna gestión adicional al paciente?",
    COALESCE(observaciones, 'Sin observaciones') AS "Observaciones"
FROM (
    SELECT
        a.DOCIDAFILIADO AS CC_PACIENTE,
        a.NOMBREAFI AS NOMBRE_PACIENTE,
        ter.RAZONSOCIAL AS ENTIDAD,
        MAX(CASE WHEN m.CAMPO = 'C0010' THEN v.VALOR END) AS alergico,
        MAX(CASE WHEN m.CAMPO = 'C0020' THEN v.VALOR END) AS cual,
        MAX(CASE WHEN m.CAMPO = 'C0030' THEN v.VALOR END) AS sala,
        MAX(CASE WHEN m.CAMPO = 'C0040' THEN v.VALOR END) AS med_aplica,
        MAX(CASE WHEN m.CAMPO = 'C0070' THEN v.VALOR END) AS frec_reclama,
        MAX(CASE WHEN m.CAMPO = 'C0090' THEN v.VALOR END) AS tiene_med,
        MAX(CASE WHEN m.CAMPO = 'C00100' THEN v.VALOR END) AS motivo,
        MAX(CASE WHEN m.CAMPO = 'C00110' THEN v.VALOR END) AS faltan,
        MAX(CASE WHEN m.CAMPO = 'C00120' THEN v.VALOR END) AS desde,
        MAX(CASE WHEN m.CAMPO = 'C00133' THEN v.VALOR END) AS hospitalizado,
        MAX(CASE WHEN m.CAMPO = 'c00135' THEN v.VALOR END) AS med_hosp,
        MAX(CASE WHEN m.CAMPO = 'C00138' THEN v.VALOR END) AS naturales,
        MAX(CASE WHEN m.CAMPO = 'C00140' THEN v.VALOR END) AS clara,
        MAX(CASE WHEN m.CAMPO = 'C00150' THEN v.VALOR END) AS menciona,
        MAX(CASE WHEN m.CAMPO = 'C00160' THEN v.VALOR END) AS suspendio,
        MAX(CASE WHEN m.CAMPO = 'C00170' THEN v.VALOR END) AS olvida,
        MAX(CASE WHEN m.CAMPO = 'C00180' THEN v.VALOR END) AS frec_olvida,
        MAX(CASE WHEN m.CAMPO = 'C00190' THEN v.VALOR END) AS biologicos,
        MAX(CASE WHEN m.CAMPO = 'C00210' THEN v.VALOR END) AS sabe_ram,
        MAX(CASE WHEN m.CAMPO = '220' THEN v.VALOR END) AS cae_mal,
        MAX(CASE WHEN m.CAMPO = 'C00235' THEN v.VALOR END) AS tipo_reaccion,
        MAX(CASE WHEN m.CAMPO IN ('C00230', 'C00260') THEN v.VALOR END) AS adherente,
        MAX(CASE WHEN m.CAMPO = 'C00240' THEN v.VALOR END) AS gestion,
        MAX(CASE WHEN m.CAMPO = 'C00250' THEN v.VALOR END) AS observaciones
    FROM
        MPLD m
    INNER JOIN
        HCAD h
        ON m.CLASEPLANTILLA = h.CLASEPLANTILLA
        AND m.CAMPO = h.CAMPO
        AND m.SECUENCIA = h.SECUENCIA
    INNER JOIN
        HCA hc
        ON h.CONSECUTIVO = hc.CONSECUTIVO
    INNER JOIN
        AFI a
        ON hc.IDAFILIADO = a.IDAFILIADO
    LEFT JOIN
        TER ter
        ON a.IDADMINISTRADORA = ter.IDTERCERO
    CROSS APPLY (
        SELECT COALESCE(
            NULLIF(TRIM(h.MEMO), ''),
            NULLIF(TRIM(h.ALFANUMERICO), ''),
            NULLIF(TRIM(h.LISTA), ''),
            (
                SELECT STRING_AGG(L.VALORLISTA, ', ')
                FROM HCADL L
                WHERE L.CONSECUTIVO = h.CONSECUTIVO
                  AND L.SECUENCIA = h.SECUENCIA
                  AND COALESCE(L.CHECKM, 0) = 1
            )
        ) AS VALOR
    ) v
    WHERE
        m.CLASEPLANTILLA = 'NAFAMA'
        AND h.TIPOCAMPO <> 'Titulo'
        AND m.CAMPO NOT IN ('C0050', 'C00145', 'C0080')
        AND CONVERT(DATE, hc.FECHA) BETWEEN @1FINI AND @2FFIN
    GROUP BY
        a.DOCIDAFILIADO,
        a.NOMBREAFI,
        ter.RAZONSOCIAL
) r
ORDER BY
    CC_PACIENTE;
