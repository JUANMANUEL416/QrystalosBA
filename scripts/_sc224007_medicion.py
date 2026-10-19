"""Medicion solo lectura CEM — consulta sc20261015-224007. Ejecutar y borrar."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from auditoria_procesos import _parse_tsv, _resolve_server_db, _sqlcmd_query  # noqa: E402

OUT = ROOT / "data" / "soporte-consultas" / "sc20261015-224007" / "_medicion.json"


def q(server, user, pwd, db, sql):
    return _parse_tsv(_sqlcmd_query(server, user, pwd, db, sql))


def main():
    server, user, pwd, db = _resolve_server_db("servidor5", "CEM")
    result = {}
    result["imov"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT CNSMOV, ESTADO, IDBODEGA, IDTIPOMOV, CNSFCOM, N_FACTURA, CNSITRA, CNSTRAN, NODOCUMENTO, FECHAMOV, FECHACONF, PROCEDENCIA
FROM IMOV WITH (NOLOCK) WHERE CNSMOV = 3400015753""",
    )
    result["imovh_count"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS, SUM(CANTIDAD) AS SUM_CANT
FROM IMOVH WITH (NOLOCK) WHERE CNSMOV = 3400015753""",
    )
    result["imovh_mx631"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 15 CNSMOV, IDARTICULO, NOLOTE, CANTIDAD, PCOSTO, ENCXP, N_PRESUP
FROM IMOVH WITH (NOLOCK)
WHERE CNSMOV = 3400015753 AND IDARTICULO LIKE 'MX631%'""",
    )
    result["itrh_count"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS_ITRAH, SUM(CANTIDAD) AS SUM_CANT
FROM ITRAH h WITH (NOLOCK)
INNER JOIN ITRA t WITH (NOLOCK) ON t.CNSITRA = h.CNSITRA
INNER JOIN IMOV m WITH (NOLOCK) ON m.CNSFCOM = t.CNSFCOM
WHERE m.CNSMOV = 3400015753""",
    )
    result["itrh_mx631"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 15 h.CNSITRA, h.IDARTICULO, h.NOLOTE, h.CANTIDAD, h.INICIAL
FROM ITRAH h WITH (NOLOCK)
INNER JOIN ITRA t WITH (NOLOCK) ON t.CNSITRA = h.CNSITRA
INNER JOIN IMOV m WITH (NOLOCK) ON m.CNSFCOM = t.CNSFCOM
WHERE m.CNSMOV = 3400015753 AND h.IDARTICULO LIKE 'MX631%'""",
    )
    result["fcom"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 1 f.CNSFCOM, f.ORDENCOMPRA, f.N_FACTURA, f.ESTADO
FROM FCOM f WITH (NOLOCK)
INNER JOIN IMOV m WITH (NOLOCK) ON m.CNSFCOM = f.CNSFCOM
WHERE m.CNSMOV = 3400015753""",
    )
    result["fcomd_mx631"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS_FCOMD, SUM(CANTIDAD) AS SUM_CANT
FROM FCOMD d WITH (NOLOCK)
INNER JOIN FCOM f WITH (NOLOCK) ON f.CNSFCOM = d.CNSFCOM
INNER JOIN IMOV m WITH (NOLOCK) ON m.CNSFCOM = f.CNSFCOM
WHERE m.CNSMOV = 3400015753 AND d.IDARTICULO LIKE 'MX631%'""",
    )
    result["izsol"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 3 CNSIZSOL, NOADMISION, ESTADO, IDAFILIADO
FROM IZSOL WITH (NOLOCK) WHERE NOADMISION = '0300001045' OR CNSIZSOL IN (
  SELECT CNSIZSOL FROM IMOV WITH (NOLOCK) WHERE CNSMOV = 3400015753 AND CNSIZSOL IS NOT NULL
)""",
    )
    result["factura_dpe"] = q(
        server,
        user,
        pwd,
        db,
        """SET NOCOUNT ON;
SELECT TOP 5 m.CNSMOV, m.N_FACTURA, m.ESTADO, f.CNSFCOM
FROM IMOV m WITH (NOLOCK)
LEFT JOIN FCOM f WITH (NOLOCK) ON f.CNSFCOM = m.CNSFCOM
WHERE m.N_FACTURA LIKE '%DPE12125%' OR f.N_FACTURA LIKE '%DPE12125%'""",
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
