CREATE OR ALTER FUNCTION dbo.FNK_INC_VALIDAR_DIAS_LM (
    @ORIGEN  VARCHAR(50),
    @TIPO_LM VARCHAR(20),
    @DIAS    SMALLINT
)
RETURNS @Result TABLE (
    ES_VALIDO BIT NOT NULL,
    MENSAJE   VARCHAR(300) NULL
)
AS
BEGIN
    DECLARE @O   VARCHAR(50) = UPPER(TRIM(ISNULL(@ORIGEN, '')));
    DECLARE @TLM VARCHAR(20) = UPPER(TRIM(ISNULL(@TIPO_LM, '')));

    IF @O NOT IN ('MATERNIDAD', 'PATERNIDAD')
    BEGIN
        INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
        RETURN;
    END

    IF @O = 'PATERNIDAD'
    BEGIN
        IF @DIAS > 126
            INSERT INTO @Result (ES_VALIDO, MENSAJE)
            VALUES (0, 'Val. D�as LM: Paternidad admite m�ximo 126 d�as.');
        ELSE
            INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
        RETURN;
    END

    -- MATERNIDAD
    IF @TLM = 'NORMAL'
    BEGIN
        IF @DIAS > 126
            INSERT INTO @Result (ES_VALIDO, MENSAJE)
            VALUES (0, 'Val. D�as LM: Maternidad NORMAL admite m�ximo 126 d�as.');
        ELSE
            INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
        RETURN;
    END

    IF @TLM = 'MULTIPLE'
    BEGIN
        IF @DIAS > 140
            INSERT INTO @Result (ES_VALIDO, MENSAJE)
            VALUES (0, 'Val. D�as LM: Maternidad MULTIPLE admite m�ximo 140 d�as.');
        ELSE
            INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
        RETURN;
    END

    IF @TLM = 'PREMATURO'
    BEGIN
        IF @DIAS > 220
            INSERT INTO @Result (ES_VALIDO, MENSAJE)
            VALUES (0, 'Val. D�as LM: Maternidad PREMATURO admite m�ximo 220 d�as.');
        ELSE
            INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
        RETURN;
    END

    INSERT INTO @Result (ES_VALIDO, MENSAJE) VALUES (1, NULL);
    RETURN;
END
