"""Medicion solo lectura CEM — consulta sc20261015-222743. Ejecutar y borrar."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from auditoria_procesos import _parse_tsv, _resolve_server_db, _sqlcmd_query  # noqa: E402

OUT = ROOT / "data" / "soporte-consultas" / "sc20261015-222743" / "_medicion.json"


def q(server, user, pwd, db, sql):
    return _parse_tsv(_sqlcmd_query(server, user, pwd, db, sql))


def main():
    server, user, pwd, db = _resolve_server_db("servidor5", "CEM")
    result = {}
    result["usvgs"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT IDVARIABLE, DATO FROM USVGS
WHERE IDVARIABLE IN ('INV_APRU_DEVTRA','IDTIMOVDEV_TRASLBOD','IDTS','IDTE')
ORDER BY IDVARIABLE""",
    )
    result["ibod_044"] = q(
        server,
        user,
        pwd,
        db,
        "SET NOCOUNT ON; SELECT IDBODEGA, DESCRIPCION FROM IBOD WHERE IDBODEGA = '044'",
    )
    result["itradev_counts"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT d.ESTADO, COUNT(*) AS CNT
FROM ITRADEV d
LEFT JOIN ITRA t ON t.CNSITRA = d.CNSITRA
WHERE d.IDBODEGAORI = '044' OR d.IDBODEGADES = '044'
   OR t.IDBODEGAORI = '044' OR t.IDBODEGADES = '044'
GROUP BY d.ESTADO ORDER BY d.ESTADO""",
    )
    result["itradev_sin_mov"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS CNT FROM ITRADEV d
WHERE d.ESTADO = 1
  AND (d.CNSMOVDEV IS NULL OR LTRIM(RTRIM(CAST(d.CNSMOVDEV AS VARCHAR(50)))) = '')
  AND (d.IDBODEGAORI = '044' OR d.IDBODEGADES = '044')""",
    )
    result["itra_estado3"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS CNT FROM ITRA
WHERE ESTADO = 3 AND (IDBODEGAORI = '044' OR IDBODEGADES = '044')""",
    )
    result["recent_aceptadas"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 5 d.CNSITRADEV, d.CNSITRA, d.CNSMOVDEV, d.IDBODEGAORI, d.IDBODEGADES,
       t.ESTADO AS ITRA_EST, t.CNSFCOM
FROM ITRADEV d
INNER JOIN ITRA t ON t.CNSITRA = d.CNSITRA
WHERE d.ESTADO = 1 AND d.IDBODEGAORI = '044'
ORDER BY d.FECHASOL DESC""",
    )
    # IEXI coherencia: devoluciones 33 confirmadas recientes vs IEXI en origen y destino
    result["iexi_trazabilidad"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 8
  d.CNSITRA,
  d.CNSMOVDEV,
  t.IDBODEGAORI AS BOD_ORIGEN,
  t.IDBODEGADES AS BOD_DEST,
  m.ESTADO AS MOVDEV_EST,
  m.IDBODEGA AS MOVDEV_BOD,
  ih.IDARTICULO,
  ih.NOLOTE,
  ih.CANTIDAD AS CANT_IMOVH,
  exO.EXISLOTE AS EXIS_ORIGEN,
  exD.EXISLOTE AS EXIS_DEST
FROM ITRADEV d
INNER JOIN ITRA t ON t.CNSITRA = d.CNSITRA
INNER JOIN IMOV m ON m.CNSMOV = d.CNSMOVDEV
INNER JOIN IMOVH ih ON ih.CNSMOV = m.CNSMOV
LEFT JOIN IEXI exO ON exO.IDBODEGA = t.IDBODEGAORI AND exO.IDARTICULO = ih.IDARTICULO
  AND ISNULL(exO.NOLOTE,'') = ISNULL(ih.NOLOTE,'')
LEFT JOIN IEXI exD ON exD.IDBODEGA = t.IDBODEGADES AND exD.IDARTICULO = ih.IDARTICULO
  AND ISNULL(exD.NOLOTE,'') = ISNULL(ih.NOLOTE,'')
WHERE d.ESTADO = 1 AND d.IDBODEGAORI = '044' AND m.ESTADO = 1
ORDER BY d.FECHASOL DESC""",
    )
    result["aceptadas_mov_no_confirmado"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS CNT
FROM ITRADEV d
INNER JOIN IMOV m ON m.CNSMOV = d.CNSMOVDEV
WHERE d.ESTADO = 1 AND d.IDBODEGAORI = '044' AND m.ESTADO <> 1""",
    )
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
