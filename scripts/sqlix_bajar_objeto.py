"""Baja objetos desde DESAIX.dbo.SQLIX. Solo SELECT vía sqlcmd.

Análisis de requerimiento: --caso ID  → activo/{ID}/sql/
Solicitud de comité:       --solicitud ID → solicitudes/{ID}/sql/
Documentar (sin caso):     sin flag → sql/  (no mezclar análisis ahí)
"""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env.local"
SQL_DIR = ROOT / "sql"


def _load_desaix():
    host, port, user, pwd, db = None, None, None, None, None
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("servidor9="):
            parts = line.split("=", 1)[1].split("|")
            host, port, user, pwd = parts[0], parts[1], parts[2], parts[3]
        elif line.startswith("dbservidor9="):
            db = line.split("=", 1)[1].strip()
    if not all([host, port, user, pwd, db]):
        raise SystemExit("Falta servidor9 o dbservidor9 en .env.local")
    return f"{host},{port}", user, pwd, db


def _sqlcmd(query: str) -> str:
    server, user, pwd, db = _load_desaix()
    cmd = [
        "sqlcmd",
        "-S",
        server,
        "-U",
        user,
        "-P",
        pwd,
        "-d",
        db,
        "-C",
        "-y",
        "0",
        "-s",
        "\t",
        "-Q",
        query,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(r.stderr or r.stdout or f"sqlcmd exit {r.returncode}")
    return r.stdout


def _version_liberada() -> tuple[str, str]:
    out = _sqlcmd(
        "SET NOCOUNT ON; "
        "SELECT TOP 1 ID, IDANT FROM dbo.VERSIONES "
        "WHERE PRODUCTO = N'Krystalos IPS' AND ESTADO = N'Cerrada' "
        "ORDER BY FECHA DESC;"
    )
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("-") or line.upper().startswith("ID"):
            continue
        parts = re.split(r"\s+", line)
        if len(parts) >= 2:
            return parts[0], parts[1]
    raise SystemExit("No se pudo leer VERSIONES liberada")


def _buscar_sqlix(objeto: str, id_liberada: str) -> dict[str, str]:
    """Devuelve {PREVERSION|id: instruccion} si existe."""
    base = objeto.replace(".sql", "").strip()
    if base.upper().startswith("SPQ_") or base.upper().startswith("SPK_"):
        nombre = base
    else:
        nombre = base
    esc = nombre.replace("'", "''")
    q = (
        "SET NOCOUNT ON; "
        f"DECLARE @O NVARCHAR(256)=N'{esc}'; "
        f"DECLARE @L NVARCHAR(32)=N'{id_liberada.replace(chr(39), chr(39)+chr(39))}'; "
        "SELECT ID, INSTRUCCION FROM dbo.SQLIX "
        "WHERE ID IN (N'PREVERSION', @L) "
        "AND (NOMBRE = @O OR NOMBRE = N'dbo.' + @O OR NOMBRE LIKE N'%.[[]' + @O + N']' ESCAPE '[' "
        "OR NOMBRE LIKE N'%.' + @O) "
        "ORDER BY CASE ID WHEN N'PREVERSION' THEN 0 ELSE 1 END;"
    )
    raw = _sqlcmd(q)
    rows: dict[str, str] = {}
    current_id = None
    buf: list[str] = []
    for line in raw.splitlines():
        if line.strip().startswith("ID\t") or line.strip().startswith("---"):
            continue
        if "\t" in line and line.split("\t", 1)[0] in ("PREVERSION", id_liberada):
            if current_id and buf:
                rows[current_id] = "\n".join(buf).strip()
            current_id, rest = line.split("\t", 1)
            buf = [rest] if rest else []
        elif current_id is not None:
            buf.append(line)
    if current_id and buf:
        rows[current_id] = "\n".join(buf).strip()
    return rows


def _hash(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:12]


def _destino(argv: list[str]) -> tuple[Path, list[str]]:
    args = list(argv)
    dest = SQL_DIR
    if args and args[0] in ("--caso", "--solicitud"):
        if len(args) < 3:
            raise SystemExit(
                "Uso: python sqlix_bajar_objeto.py --caso ID_CASO OBJETO [OBJETO...]\n"
                "  o: python sqlix_bajar_objeto.py --solicitud ID_SR OBJETO [OBJETO...]"
            )
        flag, ident = args[0], args[1].strip()
        if not ident or any(c in ident for c in "\\/:") or ".." in ident:
            raise SystemExit("Identificador inválido")
        base = "activo" if flag == "--caso" else "solicitudes"
        dest = ROOT / base / ident / "sql"
        args = args[2:]
    return dest, args


def bajar(objeto: str, dest_dir: Path | None = None) -> dict:
    id_lib, id_ant = _version_liberada()
    rows = _buscar_sqlix(objeto, id_lib)
    if not rows:
        rows = _buscar_sqlix(objeto, id_ant)
        fuente = f"IDANT {id_ant}"
    elif "PREVERSION" in rows:
        fuente = "PREVERSION"
        body = rows["PREVERSION"]
        if id_lib in rows:
            cmp_pre, cmp_lib = _hash(body), _hash(rows[id_lib])
            integridad = "idénticas" if cmp_pre == cmp_lib else "distintas (PREVERSION ≠ liberada)"
        else:
            integridad = "solo PREVERSION"
    elif id_lib in rows:
        fuente = f"liberada {id_lib}"
        body = rows[id_lib]
        integridad = "solo liberada (no en PREVERSION)"
    else:
        raise SystemExit(f"{objeto}: no está en PREVERSION ni {id_lib} ni {id_ant}")

    if "PREVERSION" in rows and fuente == "PREVERSION":
        body = rows["PREVERSION"]
    elif id_lib in rows:
        body = rows[id_lib]
    else:
        body = next(iter(rows.values()))

    fname = objeto if objeto.lower().endswith(".sql") else f"{objeto}.sql"
    out_dir = dest_dir or SQL_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / fname
    out.write_text(body + "\n", encoding="utf-8")
    return {
        "archivo": str(out.relative_to(ROOT)),
        "fuente": fuente,
        "id_liberada": id_lib,
        "id_ant": id_ant,
        "integridad": integridad if "integridad" in dir() else "—",
        "bytes": len(body.encode("utf-8")),
    }


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "Uso: python sqlix_bajar_objeto.py --caso ID_CASO SPQ_NOM_PRS [SPQ_NOM_PRSD ...]\n"
            "     python sqlix_bajar_objeto.py --solicitud ID_SR OBJETO\n"
            "     python sqlix_bajar_objeto.py OBJETO   (solo Documentar → sql/)"
        )
        return 1
    dest, objetos = _destino(argv[1:])
    if not objetos:
        print("Falta el nombre del objeto")
        return 1
    id_lib, id_ant = _version_liberada()
    print(f"Última Cerrada: {id_lib} (IDANT {id_ant})")
    print(f"Destino: {dest.relative_to(ROOT)}")
    for obj in objetos:
        info = bajar(obj, dest)
        print(
            f"  OK {info['archivo']} <- {info['fuente']} | {info['bytes']} bytes | {info.get('integridad', '')}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
