CREATE OR ALTER PROCEDURE DBO.SPK_RELIQUIDACXCQX
    @CNSCXC VARCHAR(20)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    --SET ANSI_WARNINGS OFF;
    
    DECLARE 
        @ES_ARS VARCHAR(3) = '',
        @PERMITE_SALDO_NEG VARCHAR(2) = '',
        @RESTA_ANTICIPOS VARCHAR(2) = '';

    BEGIN TRY
        -- ========================================
        -- CONFIGURACIÓN DE VARIABLES DE SISTEMA
        -- ========================================
        SELECT 
            @ES_ARS = dbo.FNK_VALORVARIABLE('IDTIPOCXP_DEFAULT'),
            @PERMITE_SALDO_NEG = dbo.FNK_VALORVARIABLE('PERMITESALDONEGATIVO'),
            @RESTA_ANTICIPOS = dbo.FNK_VALORVARIABLE('ANTIPO_IMP_RESTA_FTR');

        -- ========================================
        -- ? PASO 1: RESET INICIAL (SOLO DETALLES)
        -- ========================================
        UPDATE FCXCD 
        SET DEDUCCIONES = 0, VALORFACTURANETO = 0, VLRPAGOS = 0, VLRNOTADB = 0,
            VLRNOTACR = 0, VLRGLOSAS = 0, SALDO = 0, SALDONETO = 0, VLRGLOSAS_R = 0,
            VLREXTRA = 0, VLRLEVANTADO = 0, VLRFCES = 0
        WHERE CNSCXC = @CNSCXC;

        UPDATE FCXCDV 
        SET SALDONETO = 0, VLRLEVANTADO = 0
        WHERE CNSCXC = @CNSCXC;

        -- ========================================
        -- ? PASO 2: TABLA TEMPORAL DE FACTURAS
        -- ========================================
        IF OBJECT_ID('tempdb..#FacturasCXC') IS NOT NULL DROP TABLE #FacturasCXC;
        
        CREATE TABLE #FacturasCXC (
            N_FACTURA VARCHAR(16) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            VALORFACTURA DECIMAL(14,2)
        );

        INSERT INTO #FacturasCXC (N_FACTURA, VALORFACTURA)
        SELECT N_FACTURA, VALORFACTURA 
        FROM FCXCD 
        WHERE CNSCXC = @CNSCXC;

        -- ========================================
        -- ? PASO 3: INICIALIZAR CÁLCULOS CON CEROS (¡CRÍTICO!)
        -- ========================================
        IF OBJECT_ID('tempdb..#CalculosFactura') IS NOT NULL DROP TABLE #CalculosFactura;
        
        CREATE TABLE #CalculosFactura (
            N_FACTURA VARCHAR(16) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            TOTALND DECIMAL(14,2) DEFAULT 0,
            TOTALNC DECIMAL(14,2) DEFAULT 0,
            TOTALPAGOS DECIMAL(14,2) DEFAULT 0,
            DEDUCCIONES DECIMAL(14,2) DEFAULT 0,
            VLRGLOSAS_A DECIMAL(14,2) DEFAULT 0,
            VLRGLOSAS_R DECIMAL(14,2) DEFAULT 0,
            VLREXTRA DECIMAL(14,2) DEFAULT 0,
            VLRCESIONES DECIMAL(14,2) DEFAULT 0,
            VLRLEVANTADO DECIMAL(14,2) DEFAULT 0
        );

        -- ? Inicializar TODAS las facturas con 0 (evita NULLs desde el origen)
        INSERT INTO #CalculosFactura (N_FACTURA, TOTALND, TOTALNC, TOTALPAGOS, DEDUCCIONES, VLRGLOSAS_A, VLRGLOSAS_R, VLREXTRA, VLRCESIONES, VLRLEVANTADO)
        SELECT 
            N_FACTURA, 0, 0, 0, 0, 0, 0, 0, 0, 0
        FROM #FacturasCXC;

        -- ========================================
        -- ? PASO 4: ACTUALIZAR CÁLCULOS CON COALESCE EN TODAS LAS OPERACIONES
        -- ========================================
        
        -- Notas Débito/Crédito
        UPDATE CF
        SET 
            TOTALND = COALESCE(N.TOTALND, 0),
            TOTALNC = COALESCE(N.TOTALNC, 0)
        FROM #CalculosFactura CF
        LEFT JOIN (
            SELECT 
                N_FACTURA,
                SUM(CASE WHEN CLASE = 'D' AND CERRADA = 1 AND COALESCE(ESTADO,'') <> 'A' THEN VR_TOTAL ELSE 0 END) AS TOTALND,
                SUM(CASE WHEN CLASE = 'C' AND CERRADA = 1 AND COALESCE(ESTADO,'') = 'O' THEN VR_TOTAL ELSE 0 END) AS TOTALNC
            FROM FNOT 
            WHERE CNSCXC = @CNSCXC
            GROUP BY N_FACTURA
        ) N ON N.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;

        -- Pagos y deducciones (ARS vs normal)
        IF @ES_ARS = 'ARS'
        BEGIN
            UPDATE CF
            SET 
                TOTALPAGOS = COALESCE(P.TOTALPAGOS, 0),
                VLRCESIONES = COALESCE(C.TOTALCESION, 0)
            FROM #CalculosFactura CF
            LEFT JOIN (
                SELECT N_FACTURA, SUM(VALORPAGO) AS TOTALPAGOS
                FROM FLEGD 
                WHERE ESTADO = 1
                GROUP BY N_FACTURA
            ) P ON P.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT
            LEFT JOIN (
                SELECT N_FACTURA, SUM(VALORCESION) AS TOTALCESION
                FROM FCESCXC 
                WHERE ESTADO = 1
                GROUP BY N_FACTURA
            ) C ON C.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;
        END
        ELSE
        BEGIN
            UPDATE CF
            SET 
                TOTALPAGOS = COALESCE(P.TOTALPAGOS, 0),
                VLREXTRA = COALESCE(P.VLREXTRA, 0),
                DEDUCCIONES = COALESCE(P.DEDUCCIONES, 0) + COALESCE(A.ANTICIPOS, 0)
            FROM #CalculosFactura CF
            LEFT JOIN (
                SELECT 
                    FPAGD.N_FACTURA,
                    SUM(FPAGD.VALORPAGO) AS TOTALPAGOS,
                    SUM(FPAGD.VLREXTRA) AS VLREXTRA,
                    SUM(FPAGD.VLRIMPUESTO + COALESCE(FPAGD.VLRDTOFIN,0) + COALESCE(FPAGD.VLROTROSDCTOS,0)) AS DEDUCCIONES
                FROM FPAGD 
                INNER JOIN FPAG ON FPAGD.CNSFPAG = FPAG.CNSFPAG
                WHERE FPAGD.CNSCXC = @CNSCXC
                  AND FPAGD.CERRADO = 1
                  AND COALESCE(FPAG.ESTADO,'') <> 'Inactivo'  
                  AND COALESCE(FPAGD.ESTADO,'') <> 'Retirada'
                GROUP BY FPAGD.N_FACTURA
            ) P ON P.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT
            LEFT JOIN (
                SELECT N_FACTURA, SUM(VALOR) AS ANTICIPOS
                FROM FTRI 
                WHERE @RESTA_ANTICIPOS = 'SI'
                GROUP BY N_FACTURA
            ) A ON A.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;
        END

        -- Glosas en auditoría
        UPDATE CF
        SET VLRGLOSAS_A = COALESCE(G.VLRGLOSAS_A, 0)
        FROM #CalculosFactura CF
        LEFT JOIN (
            SELECT N_FACTURA, SUM(VLRGLOSA) AS VLRGLOSAS_A
            FROM FGLO 
            WHERE CNSCXC = @CNSCXC AND CERRADA = 0 AND ESTADO <> 'A'
            GROUP BY N_FACTURA
        ) G ON G.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;

        -- ========================================
        -- ? PASO 5: ACTUALIZACIÓN DE GLOSAS CERRADAS (sin cambios)
        -- ========================================
        ;WITH PagosPorGlosa AS (
            SELECT 
                FPAGD.CNSGLO COLLATE DATABASE_DEFAULT AS CNSGLO,
                FPAGD.N_FACTURA COLLATE DATABASE_DEFAULT AS N_FACTURA,
                SUM(COALESCE(FPAGD.VALORPAGO,0) + COALESCE(FPAGD.VLRGLOSA,0) + COALESCE(FPAGD.VLRIMPUESTO,0) 
                    + COALESCE(FPAGD.VLRDTOFIN,0) + COALESCE(FPAGD.VLROTROSDCTOS,0)) AS TotalPagos
            FROM FPAGD 
            INNER JOIN FPAG ON FPAGD.CNSFPAG = FPAG.CNSFPAG
            WHERE FPAGD.CNSCXC = @CNSCXC
              AND FPAGD.CERRADO = 1
              AND COALESCE(FPAG.ESTADO,'') <> 'Inactivo' 
              AND COALESCE(FPAGD.ESTADO,'') <> 'Retirada'
              AND COALESCE(FPAGD.CNSGLO,'') <> ''
            GROUP BY FPAGD.CNSGLO COLLATE DATABASE_DEFAULT, FPAGD.N_FACTURA COLLATE DATABASE_DEFAULT
        ),
        ConciliacionesPorGlosa AS (
            SELECT 
                CNSGLO COLLATE DATABASE_DEFAULT AS CNSGLO,
                N_FACTURA COLLATE DATABASE_DEFAULT AS N_FACTURA,
                SUM(VLRACEPTADO) AS GLOCONCIACEP
            FROM FCONCID 
            WHERE ESTADO = 'Cerrada'
            GROUP BY CNSGLO COLLATE DATABASE_DEFAULT, N_FACTURA COLLATE DATABASE_DEFAULT
        )
        UPDATE G
        SET 
            ABONADO = G.VLRACEPTADO + COALESCE(P.TotalPagos, 0) + COALESCE(C.GLOCONCIACEP, 0),
            SALDO = CASE 
                WHEN G.VLRGLOSA - (G.VLRACEPTADO + COALESCE(P.TotalPagos, 0) + COALESCE(C.GLOCONCIACEP, 0)) < 0 
                THEN 0 
                ELSE G.VLRGLOSA - (G.VLRACEPTADO + COALESCE(P.TotalPagos, 0) + COALESCE(C.GLOCONCIACEP, 0)) 
            END
        FROM FGLO G
        LEFT JOIN PagosPorGlosa P ON G.CNSGLO COLLATE DATABASE_DEFAULT = P.CNSGLO AND G.N_FACTURA COLLATE DATABASE_DEFAULT = P.N_FACTURA
        LEFT JOIN ConciliacionesPorGlosa C ON G.CNSGLO COLLATE DATABASE_DEFAULT = C.CNSGLO AND G.N_FACTURA COLLATE DATABASE_DEFAULT = C.N_FACTURA
        WHERE G.CERRADA = 1 AND G.CNSCXC = @CNSCXC;

        -- Glosas a recuperar
        UPDATE CF
        SET VLRGLOSAS_R = COALESCE(G.VLRGLOSAS_R, 0) + COALESCE(C.VLRRECUPERAR_CONC, 0)
        FROM #CalculosFactura CF
        LEFT JOIN (
            SELECT 
                N_FACTURA,
                SUM(CASE WHEN SALDO <= 0 THEN 0 ELSE SALDO END) AS VLRGLOSAS_R
            FROM FGLO 
            WHERE CNSCXC = @CNSCXC
              AND CERRADA = 1
              AND ESTADO <> 'A'
              AND NOT EXISTS (SELECT 1 FROM FCONCID C2 WHERE C2.CNSGLO COLLATE DATABASE_DEFAULT = FGLO.CNSGLO COLLATE DATABASE_DEFAULT AND C2.N_FACTURA COLLATE DATABASE_DEFAULT = FGLO.N_FACTURA COLLATE DATABASE_DEFAULT)
              AND EXISTS (SELECT 1 FROM FGLOI INNER JOIN FGLOID ON FGLOI.CNSGLOI = FGLOID.CNSGLOI 
                          WHERE FGLOID.CNSGLO COLLATE DATABASE_DEFAULT = FGLO.CNSGLO COLLATE DATABASE_DEFAULT AND FGLOI.RADICADO = 1)
            GROUP BY N_FACTURA
        ) G ON G.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT
        LEFT JOIN (
            SELECT 
                N_FACTURA,
                SUM(VLRRECUPERAR) AS VLRRECUPERAR_CONC
            FROM FCONCID
            WHERE CNSCXC = @CNSCXC
              AND ESTADO = 'Cerrada'
              AND EXISTS (SELECT 1 FROM FGLO WHERE CNSGLO COLLATE DATABASE_DEFAULT = FCONCID.CNSGLO COLLATE DATABASE_DEFAULT AND N_FACTURA COLLATE DATABASE_DEFAULT = FCONCID.N_FACTURA COLLATE DATABASE_DEFAULT)
            GROUP BY N_FACTURA
        ) C ON C.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;

        -- Valor levantado
        UPDATE CF
        SET VLRLEVANTADO = COALESCE(L.VLRLEVANTADO, 0)
        FROM #CalculosFactura CF
        LEFT JOIN (
            SELECT N_FACTURA, SUM(VLRLEVANTADO) AS VLRLEVANTADO
            FROM FCXCDV 
            WHERE CNSCXC = @CNSCXC AND TIPO <> 'F'
            GROUP BY N_FACTURA
        ) L ON L.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT;

        -- ========================================
        -- ? PASO 6: ACTUALIZACIÓN MASIVA DE FCXCD CON COALESCE EN FÓRMULAS (¡CORREGIDO!)
        -- ========================================
        UPDATE D
        SET 
            DEDUCCIONES = COALESCE(CF.DEDUCCIONES, 0),
            VLRPAGOS = COALESCE(CF.TOTALPAGOS, 0),
            VLRNOTADB = COALESCE(CF.TOTALND, 0),
            VLRNOTACR = COALESCE(CF.TOTALNC, 0),
            VLRGLOSAS = COALESCE(CF.VLRGLOSAS_A, 0),
            VLRGLOSAS_R = COALESCE(CF.VLRGLOSAS_R, 0),
            VLREXTRA = COALESCE(CF.VLREXTRA, 0),
            VLRFCES = COALESCE(CF.VLRCESIONES, 0),
            VLRLEVANTADO = COALESCE(CF.VLRLEVANTADO, 0),
            VALORFACTURANETO = D.VALORFACTURA - COALESCE(CF.DEDUCCIONES, 0),
            SALDO = D.VALORFACTURA 
                   - COALESCE(CF.TOTALNC, 0) 
                   - COALESCE(CF.VLRGLOSAS_A, 0) 
                   + COALESCE(CF.TOTALND, 0) 
                   - COALESCE(CF.TOTALPAGOS, 0) 
                   - COALESCE(CF.VLRCESIONES, 0),
            SALDONETO = D.VALORFACTURA 
                      - COALESCE(CF.TOTALNC, 0) 
                      - COALESCE(CF.VLRGLOSAS_A, 0) 
                      + COALESCE(CF.TOTALND, 0) 
                      - COALESCE(CF.DEDUCCIONES, 0) 
                      - COALESCE(CF.TOTALPAGOS, 0) 
                      - COALESCE(CF.VLRCESIONES, 0)
        FROM FCXCD D
        INNER JOIN #CalculosFactura CF ON D.N_FACTURA COLLATE DATABASE_DEFAULT = CF.N_FACTURA COLLATE DATABASE_DEFAULT
        WHERE D.CNSCXC = @CNSCXC;

        -- ========================================
        -- ? PASO 7: VALIDACIÓN FINAL (¡GARANTÍA ANTI-NULL!)
        -- ========================================
        UPDATE FCXCD
        SET 
            SALDO = COALESCE(SALDO, 0),
            SALDONETO = COALESCE(SALDONETO, 0),
            VALORFACTURANETO = COALESCE(VALORFACTURANETO, 0),
            DEDUCCIONES = COALESCE(DEDUCCIONES, 0),
            VLRPAGOS = COALESCE(VLRPAGOS, 0),
            VLRNOTADB = COALESCE(VLRNOTADB, 0),
            VLRNOTACR = COALESCE(VLRNOTACR, 0),
            VLRGLOSAS = COALESCE(VLRGLOSAS, 0),
            VLRGLOSAS_R = COALESCE(VLRGLOSAS_R, 0),
            VLREXTRA = COALESCE(VLREXTRA, 0),
            VLRFCES = COALESCE(VLRFCES, 0),
            VLRLEVANTADO = COALESCE(VLRLEVANTADO, 0)
        WHERE CNSCXC = @CNSCXC;

        -- ========================================
        -- ? PASO 8: AJUSTES DE SALDO NEGATIVO Y ANULACIONES
        -- ========================================
        UPDATE D
        SET SALDONETO = 0, SALDO = 0
        FROM FCXCD D
        WHERE D.CNSCXC = @CNSCXC
          AND D.SALDONETO < 0 
          AND @PERMITE_SALDO_NEG <> 'SI';

        UPDATE D
        SET SALDONETO = 0, SALDO = 0
        FROM FCXCD D
        INNER JOIN FTR T ON D.N_FACTURA COLLATE DATABASE_DEFAULT = T.N_FACTURA COLLATE DATABASE_DEFAULT
        WHERE D.CNSCXC = @CNSCXC AND T.ESTADO = 'A';

        -- ========================================
        -- ? PASO 9: RECALCULO DE FCXCDV (partidas) - Versión Compacta y Segura
        -- ========================================
        IF OBJECT_ID('tempdb..#ValoresFCXCDV') IS NOT NULL DROP TABLE #ValoresFCXCDV;
        
        CREATE TABLE #ValoresFCXCDV (
            ITEM INT,
            N_FACTURA VARCHAR(16) COLLATE DATABASE_DEFAULT,
            TIPO VARCHAR(1) COLLATE DATABASE_DEFAULT,
            CNSGLO VARCHAR(20) COLLATE DATABASE_DEFAULT,
            SALDOINICIAL DECIMAL(14,2),
            VLRLEVANTADO DECIMAL(14,2),
            LEVANTADO INT,
            VRNOTAS DECIMAL(14,2) DEFAULT 0,
            VRNOTASD DECIMAL(14,2) DEFAULT 0,
            VRPAGOS DECIMAL(14,2) DEFAULT 0,
            VRDEDUC DECIMAL(14,2) DEFAULT 0,
            VRGLOSAS DECIMAL(14,2) DEFAULT 0,
            VRGLOSAS_R DECIMAL(14,2) DEFAULT 0,
            VLRCESION DECIMAL(14,2) DEFAULT 0,
            PRIMARY KEY (N_FACTURA, ITEM)
        );

        INSERT INTO #ValoresFCXCDV (ITEM, N_FACTURA, TIPO, CNSGLO, SALDOINICIAL, VLRLEVANTADO, LEVANTADO)
        SELECT ITEM, N_FACTURA, TIPO COLLATE DATABASE_DEFAULT, CNSGLO COLLATE DATABASE_DEFAULT, SALDOINICIAL, VLRLEVANTADO, LEVANTADO
        FROM FCXCDV 
        WHERE CNSCXC = @CNSCXC;

        -- Notas crédito para tipo 'F'
        UPDATE V
        SET VRNOTAS = COALESCE((
            SELECT SUM(N.VR_TOTAL) 
            FROM FNOT N
            WHERE N.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
              AND N.CNSCXC = @CNSCXC
              AND N.CERRADA = 1 
              AND N.CLASE = 'C'    
              AND N.PROCEDENCIA IN ('NOTAS','CONCILIA','CARTERA')
              AND N.ESTADO <> 'A'
              AND (V.TIPO = 'F' OR COALESCE(N.CNSGLO COLLATE DATABASE_DEFAULT, '') = COALESCE(V.CNSGLO COLLATE DATABASE_DEFAULT, ''))
        ), 0) +
        COALESCE((
            SELECT SUM(N.VR_TOTAL)
            FROM FNOT N
            INNER JOIN FGLO G ON G.CNSGLO COLLATE DATABASE_DEFAULT = N.CNSGLO COLLATE DATABASE_DEFAULT
            WHERE N.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
              AND N.CNSCXC = @CNSCXC
              AND N.CERRADA = 1 
              AND N.CLASE = 'C'    
              AND N.PROCEDENCIA = 'AUDITORIA'
              AND N.ESTADO <> 'A'
              AND (G.CNSGLO_O COLLATE DATABASE_DEFAULT IS NULL OR G.CNSGLO_O COLLATE DATABASE_DEFAULT = '')
              AND G.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
              AND G.CNSCXC = @CNSCXC
        ), 0)
        FROM #ValoresFCXCDV V
        WHERE V.TIPO COLLATE DATABASE_DEFAULT = 'F';

        -- Notas débito para tipo 'F'
        UPDATE V
        SET VRNOTASD = COALESCE((
            SELECT SUM(N.VR_TOTAL) 
            FROM FNOT N
            WHERE N.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
              AND N.CNSCXC = @CNSCXC
              AND N.CERRADA = 1 
              AND N.CLASE = 'D'
              AND N.ESTADO <> 'A'
              AND N.PROCEDENCIA IN ('NOTAS','CARTERA','CONCILIA')
              AND COALESCE(N.CNSGLO COLLATE DATABASE_DEFAULT, '') = ''
        ), 0)
        FROM #ValoresFCXCDV V
        WHERE V.TIPO COLLATE DATABASE_DEFAULT = 'F';

        -- Pagos (ARS vs normal)
        IF @ES_ARS = 'ARS'
        BEGIN
            UPDATE V
            SET 
                VRPAGOS = COALESCE((SELECT SUM(L.VALORPAGO) FROM FLEGD L WHERE L.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT AND L.ESTADO = 1), 0),
                VLRCESION = COALESCE((SELECT SUM(C.VALORCESION) FROM FCESCXC C WHERE C.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT AND C.ESTADO = 1), 0)
            FROM #ValoresFCXCDV V;
        END
        ELSE
        BEGIN
            UPDATE V
            SET VRPAGOS = COALESCE((
                SELECT SUM(FPAGD.VALORPAGO + COALESCE(FPAGD.VLROTROSDCTOS,0)) 
                FROM FPAGD 
                INNER JOIN FPAG ON FPAGD.CNSFPAG = FPAG.CNSFPAG
                WHERE FPAGD.CERRADO = 1
                  AND COALESCE(FPAG.ESTADO COLLATE DATABASE_DEFAULT,'') <> 'Inactivo' 
                  AND (FPAGD.CLASE COLLATE DATABASE_DEFAULT = 'F' OR FPAGD.CLASE IS NULL OR FPAGD.CLASE COLLATE DATABASE_DEFAULT = V.TIPO COLLATE DATABASE_DEFAULT)
                  AND FPAGD.CNSCXC = @CNSCXC  
                  AND FPAGD.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
                  AND (V.TIPO COLLATE DATABASE_DEFAULT = 'F' OR COALESCE(FPAGD.CNSGLO COLLATE DATABASE_DEFAULT,'') = COALESCE(V.CNSGLO COLLATE DATABASE_DEFAULT,''))
                  AND COALESCE(FPAGD.ESTADO COLLATE DATABASE_DEFAULT,'') <> 'Retirada'
            ), 0)
            FROM #ValoresFCXCDV V;
        END

        -- Deducciones
        UPDATE V
        SET VRDEDUC = COALESCE((
            SELECT SUM(COALESCE(FPAGD.VLRIMPUESTO,0) + COALESCE(FPAGD.VLRDTOFIN,0)) 
            FROM FPAGD 
            INNER JOIN FPAG ON FPAGD.CNSFPAG = FPAG.CNSFPAG
            WHERE FPAGD.CERRADO = 1
              AND FPAGD.CNSCXC = @CNSCXC  
              AND FPAGD.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
              AND (V.TIPO COLLATE DATABASE_DEFAULT = 'F' OR FPAGD.CLASE COLLATE DATABASE_DEFAULT = V.TIPO COLLATE DATABASE_DEFAULT)
              AND (V.TIPO COLLATE DATABASE_DEFAULT = 'F' OR COALESCE(FPAGD.CNSGLO COLLATE DATABASE_DEFAULT,'') = COALESCE(V.CNSGLO COLLATE DATABASE_DEFAULT,''))
              AND COALESCE(FPAGD.ESTADO COLLATE DATABASE_DEFAULT,'') <> 'Retirada'
        ), 0)
        FROM #ValoresFCXCDV V;

        -- Glosas para tipo 'F'
        UPDATE V
        SET 
            VRGLOSAS = COALESCE((
                SELECT SUM(COALESCE(G.VLRGLOSA,0)) 
                FROM FGLO G
                WHERE G.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
                  AND G.CNSCXC = @CNSCXC   
                  AND G.CERRADA = 0
                  AND COALESCE(G.CNSGLO_O COLLATE DATABASE_DEFAULT,'') = ''
                  AND G.ESTADO COLLATE DATABASE_DEFAULT <> 'A'
                  AND G.PROCEDENCIA COLLATE DATABASE_DEFAULT <> 'Recaudo'
            ), 0) +
            COALESCE((
                SELECT SUM(G2.VLRGLOSA) 
                FROM FGLO G2
                WHERE G2.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
                  AND G2.CERRADA = 0
                  AND COALESCE(G2.CNSGLO_O COLLATE DATABASE_DEFAULT,'') = ''
                  AND G2.ESTADO COLLATE DATABASE_DEFAULT <> 'A'
                  AND G2.PROCEDENCIA COLLATE DATABASE_DEFAULT = 'Recaudo'
            ), 0),
            VRGLOSAS_R = COALESCE((
                SELECT SUM(G3.VLRRECUPERAR) 
                FROM FGLO G3
                WHERE G3.N_FACTURA = V.N_FACTURA COLLATE DATABASE_DEFAULT
                  AND G3.CNSCXC = @CNSCXC   
                  AND G3.CERRADA = 1
                  AND COALESCE(G3.CNSGLO_O COLLATE DATABASE_DEFAULT,'') = ''
                  AND G3.ESTADO COLLATE DATABASE_DEFAULT <> 'A'
            ), 0)
        FROM #ValoresFCXCDV V
        WHERE V.TIPO COLLATE DATABASE_DEFAULT = 'F';

        -- Actualización final de SALDONETO con COALESCE total
        UPDATE F
        SET SALDONETO = CASE 
            WHEN V.TIPO COLLATE DATABASE_DEFAULT = 'F' THEN 
                COALESCE(V.SALDOINICIAL,0) 
                - COALESCE(V.VRNOTAS,0) 
                - COALESCE(V.VRPAGOS,0) 
                - COALESCE(V.VRGLOSAS,0) 
                - COALESCE(V.VRGLOSAS_R,0) 
                - COALESCE(V.VRDEDUC,0) 
                + COALESCE(V.VRNOTASD,0) 
                - COALESCE(V.VLRCESION,0) 
                + COALESCE(V.VLRLEVANTADO,0)
            WHEN V.TIPO COLLATE DATABASE_DEFAULT <> 'C' THEN 
                COALESCE(V.SALDOINICIAL,0) 
                - COALESCE(V.VRNOTAS,0) 
                - COALESCE(V.VRPAGOS,0) 
                - COALESCE(V.VRGLOSAS,0) 
                - COALESCE(V.VRGLOSAS_R,0) 
                - COALESCE(V.VRDEDUC,0) 
                + COALESCE(V.VRNOTASD,0) 
                - COALESCE(V.VLRCESION,0) 
                + COALESCE(V.VLRLEVANTADO,0) 
                - (CASE ISNULL(V.LEVANTADO,0) WHEN 1 THEN ISNULL(V.VLRLEVANTADO,0) ELSE 0 END)
            ELSE 
                COALESCE(V.SALDOINICIAL,0) - COALESCE(V.VRPAGOS,0) - COALESCE(V.VRDEDUC,0)
        END
        FROM FCXCDV F
        INNER JOIN #ValoresFCXCDV V 
            ON F.N_FACTURA COLLATE DATABASE_DEFAULT = V.N_FACTURA COLLATE DATABASE_DEFAULT 
            AND F.ITEM = V.ITEM
        WHERE F.CNSCXC = @CNSCXC;

        -- Garantía anti-NULL en FCXCDV
        UPDATE FCXCDV 
        SET SALDONETO = COALESCE(SALDONETO, 0)
        WHERE CNSCXC = @CNSCXC AND SALDONETO IS NULL;

        -- ========================================
        -- ? PASO 10: ACTUALIZACIÓN FINAL DE ENCABEZADO FCXC
        -- ========================================
        DECLARE 
            @TOTALCXC DECIMAL(14,2) = 0,
            @TOTALDEDUCCIONES DECIMAL(14,2) = 0,
            @TOTALPAGOS_CXC DECIMAL(14,2) = 0,
            @TOTALND_CXC DECIMAL(14,2) = 0,
            @TOTALNC_CXC DECIMAL(14,2) = 0,
            @TOTALGLOSAS_A DECIMAL(14,2) = 0,
            @TOTALGLOSAS_R DECIMAL(14,2) = 0,
            @TOTALEXTRA DECIMAL(14,2) = 0;

        SELECT 
            @TOTALCXC = COALESCE(SUM(VALORFACTURA), 0),
            @TOTALDEDUCCIONES = COALESCE(SUM(DEDUCCIONES), 0),
            @TOTALPAGOS_CXC = COALESCE(SUM(VLRPAGOS), 0),
            @TOTALND_CXC = COALESCE(SUM(VLRNOTADB), 0),
            @TOTALNC_CXC = COALESCE(SUM(VLRNOTACR), 0),
            @TOTALGLOSAS_A = COALESCE(SUM(VLRGLOSAS), 0),
            @TOTALGLOSAS_R = COALESCE(SUM(VLRGLOSAS_R), 0),
            @TOTALEXTRA = COALESCE(SUM(VLREXTRA) + SUM(VLRFCES), 0)
        FROM FCXCD
        WHERE CNSCXC = @CNSCXC;

        UPDATE FCXC 
        SET  
            VALORCXC = @TOTALCXC,
            VALORCXCNETO = @TOTALCXC - @TOTALDEDUCCIONES,
            VLRPAGOS = @TOTALPAGOS_CXC,
            VLRNOTADB = @TOTALND_CXC,
            VLRNOTACR = @TOTALNC_CXC,
            DEDUCCIONES = @TOTALDEDUCCIONES,
            VLRGLOSAS = @TOTALGLOSAS_A,
            VLRGLOSAS_R = @TOTALGLOSAS_R,
            VLREXTRA = @TOTALEXTRA,
            SALDO = @TOTALCXC + @TOTALND_CXC - @TOTALNC_CXC - @TOTALPAGOS_CXC - @TOTALGLOSAS_A,
            SALDONETO = (@TOTALCXC - @TOTALDEDUCCIONES) + @TOTALND_CXC - @TOTALNC_CXC - @TOTALPAGOS_CXC - @TOTALGLOSAS_A
        WHERE CNSCXC = @CNSCXC;

        -- Limpiar recursos
        IF OBJECT_ID('tempdb..#FacturasCXC') IS NOT NULL DROP TABLE #FacturasCXC;
        IF OBJECT_ID('tempdb..#CalculosFactura') IS NOT NULL DROP TABLE #CalculosFactura;
        IF OBJECT_ID('tempdb..#ValoresFCXCDV') IS NOT NULL DROP TABLE #ValoresFCXCDV;

    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#FacturasCXC') IS NOT NULL DROP TABLE #FacturasCXC;
        IF OBJECT_ID('tempdb..#CalculosFactura') IS NOT NULL DROP TABLE #CalculosFactura;
        IF OBJECT_ID('tempdb..#ValoresFCXCDV') IS NOT NULL DROP TABLE #ValoresFCXCDV;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END

