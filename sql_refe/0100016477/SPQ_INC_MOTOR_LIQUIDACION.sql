CREATE OR ALTER PROCEDURE DBO.SPQ_INC_MOTOR_LIQUIDACION
    @IDINCAPACIDAD INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IDAFILIADO INT,
            @ORIGEN VARCHAR(50),
            @IDEPS VARCHAR(20),
            @IDDX VARCHAR(10),
            @FECHA_INICIO DATE,
            @FECHA_FIN DATE,
            @DIAS_INCAPACIDAD SMALLINT,
            @IBC DECIMAL(18,2),
            @PRORROGA_USER BIT,
            @TIPO_LM VARCHAR(20),
            @TIPO_COTIZANTE VARCHAR(20);

    DECLARE @EsProrrogaFinal BIT = 0;

    DECLARE @DiasAcumuladosPrevios INT = 0;
    DECLARE @ValorIbcDia DECIMAL(18,2);
    DECLARE @EsProrrogaLegal BIT = 0;
    DECLARE @StartDayComercial INT;
    DECLARE @SlotAbsoluto INT;
    DECLARE @MesOffset INT;
    DECLARE @FechaComercialPeriodo DATE;

    -- 1. Extraer los datos de la incapacidad actual vinculados al afiliado
    SELECT
        @IDAFILIADO = IDAFILIADO,
        @ORIGEN = UPPER(ISNULL(ORIGEN, '')),
        @IDEPS = NULLIF(LTRIM(RTRIM(IDEPS)), ''),
        @IDDX = IDDX,
        @FECHA_INICIO = FECHA_INICIO,
        @FECHA_FIN = ISNULL(FECHA_FIN, DATEADD(DAY, DIAS_INCAPACIDAD - 1, FECHA_INICIO)),
        @DIAS_INCAPACIDAD = DIAS_INCAPACIDAD,
        @IBC = ISNULL(IBC, 0),
        @PRORROGA_USER = ISNULL(PRORROGA, 0),
        @TIPO_LM = ISNULL(TIPO_LM, ''),
        @TIPO_COTIZANTE = UPPER(ISNULL(TIPO_COTIZANTE, 'DEPENDIENTE'))
    FROM dbo.INCA
    WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 'KO' AS OK, 'Incapacidad no encontrada' AS ERROR;
        RETURN;
    END

    -- Topes de d�as LM / Paternidad (EG, ARL y dem�s or�genes no entran aqu�)
    IF @ORIGEN IN ('MATERNIDAD', 'PATERNIDAD')
    BEGIN
        DECLARE @ErrDiasLM NVARCHAR(300);
        SELECT @ErrDiasLM = V.MENSAJE
        FROM dbo.FNK_INC_VALIDAR_DIAS_LM(@ORIGEN, @TIPO_LM, @DIAS_INCAPACIDAD) V
        WHERE V.ES_VALIDO = 0;

        IF @ErrDiasLM IS NOT NULL
        BEGIN
            SELECT 'KO' AS OK, @ErrDiasLM AS ERROR;
            RETURN;
        END
    END

    -- Valor IBC Diario base
    SET @ValorIbcDia = @IBC / 30.0;

    -- 2. VALIDACI�N DE PR�RROGA (Basado en prorroga.md)
    -- Buscamos el certificado anterior v�lido m�s cercano
    DECLARE @PrevFechaFin DATE, @PrevDx VARCHAR(10), @PrevIdeps VARCHAR(20), @PrevAcumuladoFin INT, @PrevId INT;

    SELECT TOP 1 
        @PrevFechaFin = FECHA_FIN,
        @PrevDx = IDDX,
        @PrevIdeps = NULLIF(LTRIM(RTRIM(IDEPS)), ''),
        @PrevId = IDINCAPACIDAD
    FROM dbo.INCA i
    WHERE i.IDAFILIADO = @IDAFILIADO
        AND i.FECHA_FIN <= @FECHA_INICIO
        AND i.IDESTADO NOT IN (4, 8) -- No devueltas ni rechazadas
        AND i.IDINCAPACIDAD <> @IDINCAPACIDAD
    ORDER BY i.FECHA_FIN DESC;

    -- Evaluar condiciones de pr�rroga legal (misma EPS por ID + mismo diagn�stico)
    IF @PrevFechaFin IS NOT NULL
        AND DATEDIFF(DAY, @PrevFechaFin, @FECHA_INICIO) <= 30
        AND @PrevDx = @IDDX
        AND @PrevIdeps = @IDEPS
        AND @IDEPS IS NOT NULL
    BEGIN
        SET @EsProrrogaLegal = 1;

        -- GUARDAR EL V�NCULO PARA TRAZABILIDAD
        UPDATE dbo.INCA SET ID_ANTECESOR = @PrevId WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        -- Obtener el acumulado m�ximo de ese antecesor de la tabla de liquidaci�n diaria
        SELECT @PrevAcumuladoFin = MAX(DIA_ACUMULADO_PRORROGA) 
        FROM dbo.INC_LIQUIDACION_DIARIA 
        WHERE IDINCAPACIDAD = @PrevId;
        
        SET @DiasAcumuladosPrevios = ISNULL(@PrevAcumuladoFin, 0);
    END
    ELSE
    BEGIN
        SET @EsProrrogaLegal = 0;
        SET @DiasAcumuladosPrevios = 0;
    END

    -- Decisi�n final de pr�rroga (Legal o Manual por Usuario)
    IF @EsProrrogaLegal = 1 OR @PRORROGA_USER = 1
    BEGIN
        SET @EsProrrogaFinal = 1;
        -- Si es pr�rroga, el acumulado debe ser al menos 2 para no cobrar carencia (empresa) de nuevo
        IF @DiasAcumuladosPrevios < 2 SET @DiasAcumuladosPrevios = 2;
    END
    ELSE
    BEGIN
        SET @EsProrrogaFinal = 0;
        UPDATE dbo.INCA SET ID_ANTECESOR = NULL WHERE IDINCAPACIDAD = @IDINCAPACIDAD;
    END

    BEGIN TRAN;
    BEGIN TRY
        -- 3. Limpiar liquidaci�n anterior si existe (Idempotencia)
        DELETE FROM dbo.INC_LIQUIDACION_DIARIA WHERE IDINCAPACIDAD = @IDINCAPACIDAD;

        -- 4. Generar tabla de d�as con CTE
        CREATE TABLE #DiasDesglose (
            DIA_NUMERO_INCAPACIDAD INT,
            FECHA DATE,
            DIA_ACUMULADO_PRORROGA INT
        );

        -- Generador de n�meros hasta 1000 d�as
        ;WITH Numeros(DiaNum) AS (
            SELECT 1
            UNION ALL
            SELECT DiaNum + 1 FROM Numeros WHERE DiaNum < @DIAS_INCAPACIDAD
        )
        INSERT INTO #DiasDesglose (DIA_NUMERO_INCAPACIDAD, FECHA, DIA_ACUMULADO_PRORROGA)
        SELECT 
            DiaNum,
            DATEADD(DAY, DiaNum - 1, @FECHA_INICIO),
            @DiasAcumuladosPrevios + DiaNum
        FROM Numeros
        OPTION (MAXRECURSION 1000);

        -- 5. Procesar cada d�a
        CREATE TABLE #LiquidacionFinal (
            IDINCAPACIDAD INT,
            FECHA DATE,
            DIA_NUMERO_INCAPACIDAD INT,
            DIA_ACUMULADO_PRORROGA INT,
            VALOR_IBC_DIA DECIMAL(18,2),
            VALOR_PAGADO_EMPRESA DECIMAL(18,2),
            VALOR_PAGADO_EPS DECIMAL(18,2),
            VALOR_APORTE_SALUD_8 DECIMAL(18,2),
            VALOR_TOTAL_LIQUIDADO DECIMAL(18,2),
            PORCENTAJE_APLICADO DECIMAL(5,2),
            ENTIDAD_PAGADORA VARCHAR(30),
            MES_CONTABLE INT,
            ANIO_CONTABLE INT,
            ES_PRORROGA BIT
        );

        DECLARE @CurrentDiaNum INT, @CurrentFecha DATE, @CurrentAcumulado INT;
        DECLARE @ValorEmpresa DECIMAL(18,2), @ValorEps DECIMAL(18,2), @ValorSalud8 DECIMAL(18,2), @Porcentaje DECIMAL(5,2);
        DECLARE @Entidad VARCHAR(30), @SmmlvDiario DECIMAL(18,2);
        DECLARE @HayTraslape BIT;

        DECLARE CursorDias CURSOR LOCAL FAST_FORWARD FOR
        SELECT DIA_NUMERO_INCAPACIDAD, FECHA, DIA_ACUMULADO_PRORROGA
        FROM #DiasDesglose
        ORDER BY DIA_NUMERO_INCAPACIDAD;

        OPEN CursorDias;
        FETCH NEXT FROM CursorDias INTO @CurrentDiaNum, @CurrentFecha, @CurrentAcumulado;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 5.1. DETECCI�N DE SIMULTANEIDAD (TRASLAPES)
            SET @HayTraslape = 0;
            IF EXISTS (
                SELECT 1
                FROM dbo.INC_LIQUIDACION_DIARIA LD
                INNER JOIN dbo.INCA I ON LD.IDINCAPACIDAD = I.IDINCAPACIDAD
                WHERE I.IDAFILIADO = @IDAFILIADO
                    AND LD.FECHA = @CurrentFecha
                    AND LD.IDINCAPACIDAD <> @IDINCAPACIDAD
                    AND (LD.VALOR_PAGADO_EPS > 0 OR LD.VALOR_PAGADO_EMPRESA > 0)
            )
            BEGIN
                SET @HayTraslape = 1;
            END

            -- Par�metros legales: SMMLV del a�o calendario de cada d�a (cruce dic?ene)
            SELECT @SmmlvDiario = SMMLV_DIARIO
            FROM dbo.INC_PARAMETROS_LEGALES
            WHERE ANIO = YEAR(@CurrentFecha)
                AND ACTIVO = 1;
            
            IF @SmmlvDiario IS NULL
            BEGIN
                DECLARE @ErrAnio NVARCHAR(10) = CAST(YEAR(@CurrentFecha) AS NVARCHAR(10));
                RAISERROR ('No se encontraron par�metros legales activos (SMMLV) configurados para el a�o %s. Por favor config�relos antes de liquidar.', 16, 1, @ErrAnio);
            END

            -- Reset valores
            SET @ValorEmpresa = 0;
            SET @ValorEps = 0;
            SET @ValorSalud8 = 0;
            SET @Porcentaje = 0;
            SET @Entidad = 'EPS';

            IF @HayTraslape = 1
            BEGIN
                SET @Entidad = 'TRASLAPE';
            END
            ELSE
            BEGIN
                -- A. ORIGEN LABORAL
                IF @ORIGEN IN ('ACCIDENTE DE TRABAJO', 'ENFERMEDAD LABORAL')
                BEGIN
                    SET @Entidad = 'ARL';
                END
                -- B. LICENCIAS
                ELSE IF @ORIGEN IN ('MATERNIDAD', 'PATERNIDAD') OR @TIPO_LM <> ''
                BEGIN
                    SET @Porcentaje = 100.00;
                    SET @ValorEps = @ValorIbcDia;
                    IF @TIPO_COTIZANTE = 'INDEPENDIENTE' AND (@ORIGEN = 'MATERNIDAD' OR @TIPO_LM <> '')
                        SET @ValorSalud8 = @ValorIbcDia * 0.08;
                END
                -- C. ENFERMEDAD GENERAL (y or�genes con la misma regla: ACCIDENTE DE TRANSITO, etc.)
                -- ACCIDENTE DE TRANSITO no va a ARL ni a licencia 100%; conserva su valor en INCA.ORIGEN.
                ELSE
                BEGIN
                    IF @CurrentAcumulado <= 2
                    BEGIN
                        IF @TIPO_COTIZANTE = 'DEPENDIENTE'
                        BEGIN
                            SET @Entidad = 'EMPRESA';
                            SET @ValorEmpresa = @ValorIbcDia;
                        END
                        ELSE SET @Entidad = 'NINGUNA';
                    END
                    ELSE IF @CurrentAcumulado <= 90
                    BEGIN
                        SET @Porcentaje = 66.67;
                        SET @ValorEps = @ValorIbcDia * 0.6667;
                    END
                    ELSE IF @CurrentAcumulado <= 180
                    BEGIN
                        SET @Porcentaje = 50.00;
                        SET @ValorEps = @ValorIbcDia * 0.50;
                    END
                    ELSE IF @CurrentAcumulado <= 540
                    BEGIN
                        SET @Entidad = 'FONDO_PENSION';
                    END
                    ELSE
                    BEGIN
                        SET @Porcentaje = 100.00;
                        SET @ValorEps = @ValorIbcDia;
                    END

                    -- Salud para independientes
                    IF @TIPO_COTIZANTE = 'INDEPENDIENTE' AND @ValorEps > 0 AND @Entidad = 'EPS'
                        SET @ValorSalud8 = @ValorIbcDia * 0.08;
                END

                -- Piso legal
                IF @Entidad = 'EPS' AND @ValorEps > 0 AND @ValorEps < @SmmlvDiario
                    SET @ValorEps = @SmmlvDiario;
            END

            -- 5.2. DISTRIBUCI�N EN SLOTS COMERCIALES (30 D�AS)
            SET @StartDayComercial = CASE WHEN DAY(@FECHA_INICIO) > 30 THEN 30 ELSE DAY(@FECHA_INICIO) END;
            SET @SlotAbsoluto = (@StartDayComercial - 1) + (@CurrentDiaNum - 1);
            SET @MesOffset = @SlotAbsoluto / 30;
            
            -- Calcular periodo contable exacto (Maneja cambio de a�o autom�ticamente)
            SET @FechaComercialPeriodo = DATEADD(MONTH, @MesOffset, @FECHA_INICIO);

            -- Regla: Si inicia un d�a 31, el primer d�a no se paga
            IF DAY(@FECHA_INICIO) = 31 AND @CurrentDiaNum = 1
            BEGIN
                SET @ValorEmpresa = 0;
                SET @ValorEps = 0;
                SET @ValorSalud8 = 0;
                SET @Porcentaje = 0;
            END

            -- Redondeo de valores diarios a 2 decimales (Est�ndar PILA)
            SET @ValorEmpresa = ROUND(@ValorEmpresa, 2);
            SET @ValorEps = ROUND(@ValorEps, 2);
            SET @ValorSalud8 = ROUND(@ValorSalud8, 2);

            INSERT INTO #LiquidacionFinal (
                IDINCAPACIDAD, FECHA, DIA_NUMERO_INCAPACIDAD, DIA_ACUMULADO_PRORROGA,
                VALOR_IBC_DIA, VALOR_PAGADO_EMPRESA, VALOR_PAGADO_EPS, VALOR_APORTE_SALUD_8,
                VALOR_TOTAL_LIQUIDADO, PORCENTAJE_APLICADO, ENTIDAD_PAGADORA,
                MES_CONTABLE, ANIO_CONTABLE, ES_PRORROGA
            ) VALUES (
                @IDINCAPACIDAD, @CurrentFecha, @CurrentDiaNum, @CurrentAcumulado,
                @ValorIbcDia, @ValorEmpresa, @ValorEps, @ValorSalud8,
                (@ValorEps + @ValorSalud8), @Porcentaje, @Entidad,
                MONTH(@FechaComercialPeriodo), YEAR(@FechaComercialPeriodo), @EsProrrogaFinal
            );

            FETCH NEXT FROM CursorDias INTO @CurrentDiaNum, @CurrentFecha, @CurrentAcumulado;
        END

        CLOSE CursorDias;
        DEALLOCATE CursorDias;

        -- 6. Pasar a tabla f�sica
        INSERT INTO dbo.INC_LIQUIDACION_DIARIA (
            IDINCAPACIDAD, FECHA, DIA_NUMERO_INCAPACIDAD, DIA_ACUMULADO_PRORROGA,
            VALOR_IBC_DIA, VALOR_PAGADO_EMPRESA, VALOR_PAGADO_EPS, VALOR_APORTE_SALUD_8,
            VALOR_TOTAL_LIQUIDADO, PORCENTAJE_APLICADO, ENTIDAD_PAGADORA,
            MES_CONTABLE, ANIO_CONTABLE, ES_PRORROGA
        )
        SELECT IDINCAPACIDAD, FECHA, DIA_NUMERO_INCAPACIDAD, DIA_ACUMULADO_PRORROGA,
               VALOR_IBC_DIA, VALOR_PAGADO_EMPRESA, VALOR_PAGADO_EPS, VALOR_APORTE_SALUD_8,
               VALOR_TOTAL_LIQUIDADO, PORCENTAJE_APLICADO, ENTIDAD_PAGADORA,
               MES_CONTABLE, ANIO_CONTABLE, @EsProrrogaFinal
        FROM #LiquidacionFinal;

        DROP TABLE #DiasDesglose;
        DROP TABLE #LiquidacionFinal;

        IF @@TRANCOUNT > 0 COMMIT;
        SELECT 'OK' AS OK, 'Liquidaci�n vinculada y generada con �xito' AS MENSAJE;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        SELECT 'KO' AS OK, 'Error al liquidar: ' + @ErrMsg AS ERROR;
    END CATCH
END
