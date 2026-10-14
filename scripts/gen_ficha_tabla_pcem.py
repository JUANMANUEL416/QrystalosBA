"""Genera fichas mínimas tablas/*.md desde PCEM + diccionario Clarion. Solo SELECT."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env.local"
RUTAS = json.loads((ROOT / "config" / "rutas.json").read_text(encoding="utf-8"))
DOC_TABLAS = Path(RUTAS["documentacion"]) / "tablas"
DICC = ROOT / "conocimiento" / "diccionario" / "campos.jsonl"


def _sqlcmd(query: str) -> str:
    cfg = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    parts = cfg["servidor1"].split("|")
    db = cfg["dbservidor1"]
    cmd = [
        "sqlcmd", "-S", f"{parts[0]},{parts[1]}", "-U", parts[2], "-P", parts[3],
        "-d", db, "-C", "-y", "0", "-s", "\t", "-Q", query,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(r.stderr or r.stdout)
    return r.stdout


def _labels(tabla: str) -> dict[str, str]:
    t = tabla.upper()
    out: dict[str, str] = {}
    if not DICC.is_file():
        return out
    with DICC.open(encoding="utf-8") as fh:
        for line in fh:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if (row.get("tabla") or "").upper() == t:
                c = (row.get("campo") or "").upper()
                if c and row.get("rotulo"):
                    out[c] = str(row["rotulo"])
    return out


def columnas(tabla: str) -> list[tuple[str, str, str]]:
    t = re.sub(r"[^A-Za-z0-9_]", "", tabla)
    q = (
        "SET NOCOUNT ON; "
        f"SELECT c.COLUMN_NAME, c.DATA_TYPE, "
        f"COALESCE(CAST(c.CHARACTER_MAXIMUM_LENGTH AS varchar(12)), CAST(c.NUMERIC_PRECISION AS varchar(12)), '') "
        f"FROM INFORMATION_SCHEMA.COLUMNS c "
        f"WHERE c.TABLE_SCHEMA='dbo' AND c.TABLE_NAME=N'{t}' ORDER BY c.ORDINAL_POSITION;"
    )
    out = _sqlcmd(q)
    rows: list[tuple[str, str, str]] = []
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("-") or line.upper().startswith("COLUMN"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            rows.append((parts[0], parts[1], parts[2] if len(parts) > 2 else ""))
    return rows


def generar(tabla: str, modulo: str = "", proposito: str = "") -> Path:
    cols = columnas(tabla)
    if not cols:
        raise ValueError(f"Sin columnas en PCEM: {tabla}")
    labels = _labels(tabla)
    dest = DOC_TABLAS / f"{tabla.upper()}.md"
    if dest.is_file():
        return dest
    lines = [
        f"# {tabla.upper()}",
        "",
        "### Información General",
        "",
        f"- **Nombre de Tabla**: `{tabla.upper()}`",
        "- **Schema**: `dbo`",
        f"- **Módulo**: {modulo or 'Por clasificar'}",
        f"- **Propósito**: {proposito or 'Documentación generada desde PCEM (BA); completar relaciones en revisión.'}",
        "",
        "### Campos",
        "",
        "| Campo | Tipo | Rotulo (Clarion) |",
        "|-------|------|------------------|",
    ]
    for name, typ, extra in cols:
        tipo = typ + (f"({extra})" if extra and extra != "NULL" else "")
        rot = labels.get(name.upper(), "")
        lines.append(f"| `{name}` | {tipo} | {rot} |")
    lines.extend(["", "### Notas", "", "- Ficha creada por oficina BA (Documentar pendientes).", ""])
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(lines), encoding="utf-8")
    return dest


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        print("Uso: py scripts/gen_ficha_tabla_pcem.py TABLA [TABLA...]")
        raise SystemExit(1)
    ok, skip, err = 0, 0, 0
    for t in argv[1:]:
        try:
            p = generar(t.strip())
            if p.stat().st_size:
                print("OK", p.name)
                ok += 1
        except ValueError as e:
            if "Sin columnas" in str(e):
                print("SKIP", t, str(e))
                skip += 1
            else:
                print("ERR", t, e)
                err += 1
        except Exception as e:
            print("ERR", t, e)
            err += 1
    print(f"--- hecho={ok} skip={skip} err={err}")


if __name__ == "__main__":
    main(sys.argv)
