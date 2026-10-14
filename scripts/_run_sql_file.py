"""Ejecuta un .sql en solo lectura si es verificación; si no, igual sqlcmd (uso interno)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from scripts import auditoria_procesos as ap  # noqa: E402


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("Uso: python scripts/_run_sql_file.py <archivo.sql> [servidor_id]")
    path = ROOT / sys.argv[1]
    sid = sys.argv[2] if len(sys.argv) > 2 else "servidor5"
    sql = path.read_text(encoding="utf-8")
    server, user, pwd, db = ap._resolve_server_db(sid, "")
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
        "-W",
        "-i",
        str(path),
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (r.stdout or "") + (r.stderr or "")
    dest = sys.argv[3] if len(sys.argv) > 3 else None
    if dest:
        Path(dest).write_text(out, encoding="utf-8")
        print(f"OK -> {dest} ({len(out)} bytes)")
    else:
        sys.stdout.buffer.write(out.encode("utf-8", errors="replace"))
    if r.returncode != 0:
        raise SystemExit(r.returncode)


if __name__ == "__main__":
    main()
