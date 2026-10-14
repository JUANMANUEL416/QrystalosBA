"""Reescribe tablas/*.md con metadatos BA + columnas/PK/FK desde PCEM. Solo SELECT."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env.local"
RUTAS = json.loads((ROOT / "config" / "rutas.json").read_text(encoding="utf-8"))
DOC_TABLAS = Path(RUTAS["documentacion"]) / "tablas"
DICC = ROOT / "conocimiento" / "diccionario" / "campos.jsonl"
META_DEFAULT = ROOT / "conocimiento" / "diccionario" / "fichas-lote-20261013.json"


def _sqlcmd(query: str) -> str:
    cfg = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    parts = cfg["servidor1"].split("|")
    db = cfg["dbservidor1"]
    cmd = [
        "sqlcmd",
        "-S",
        f"{parts[0]},{parts[1]}",
        "-U",
        parts[2],
        "-P",
        parts[3],
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


def columnas(tabla: str) -> list[tuple[str, str, str, str]]:
    t = re.sub(r"[^A-Za-z0-9_]", "", tabla)
    q = (
        "SET NOCOUNT ON; "
        f"SELECT c.COLUMN_NAME, c.DATA_TYPE, "
        f"COALESCE(CAST(c.CHARACTER_MAXIMUM_LENGTH AS varchar(12)), "
        f"CAST(c.NUMERIC_PRECISION AS varchar(12)), ''), "
        f"c.IS_NULLABLE "
        f"FROM INFORMATION_SCHEMA.COLUMNS c "
        f"WHERE c.TABLE_SCHEMA='dbo' AND c.TABLE_NAME=N'{t}' "
        f"ORDER BY c.ORDINAL_POSITION;"
    )
    out = _sqlcmd(q)
    rows: list[tuple[str, str, str, str]] = []
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("-") or line.upper().startswith("COLUMN"):
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            rows.append(
                (
                    parts[0],
                    parts[1],
                    parts[2] if len(parts) > 2 else "",
                    parts[3] if len(parts) > 3 else "",
                )
            )
    return rows


def pk_cols(tabla: str) -> list[str]:
    t = re.sub(r"[^A-Za-z0-9_]", "", tabla)
    q = (
        "SET NOCOUNT ON; "
        f"SELECT c.COLUMN_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc "
        f"JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE c "
        f"ON tc.CONSTRAINT_NAME=c.CONSTRAINT_NAME AND tc.TABLE_SCHEMA=c.TABLE_SCHEMA "
        f"WHERE tc.TABLE_SCHEMA='dbo' AND tc.TABLE_NAME=N'{t}' AND tc.CONSTRAINT_TYPE='PRIMARY KEY' "
        f"ORDER BY c.ORDINAL_POSITION;"
    )
    out = _sqlcmd(q)
    cols = []
    for line in out.splitlines():
        line = line.strip()
        if line and not line.startswith("-") and line.upper() != "COLUMN_NAME":
            cols.append(line.split("\t")[0])
    return cols


def fk_rows(tabla: str) -> list[tuple[str, str, str]]:
    t = re.sub(r"[^A-Za-z0-9_]", "", tabla)
    q = (
        "SET NOCOUNT ON; "
        f"SELECT pc.name, tr.name, cr.name "
        f"FROM sys.foreign_keys fk "
        f"INNER JOIN sys.foreign_key_columns fkc ON fk.object_id=fkc.constraint_object_id "
        f"INNER JOIN sys.tables tp ON fkc.parent_object_id=tp.object_id "
        f"INNER JOIN sys.columns pc ON fkc.parent_object_id=pc.object_id AND fkc.parent_column_id=pc.column_id "
        f"INNER JOIN sys.tables tr ON fkc.referenced_object_id=tr.object_id "
        f"INNER JOIN sys.columns cr ON fkc.referenced_object_id=cr.object_id AND fkc.referenced_column_id=cr.column_id "
        f"WHERE tp.name=N'{t}' ORDER BY pc.name;"
    )
    out = _sqlcmd(q)
    rows: list[tuple[str, str, str]] = []
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("-") or "name" in line.lower() and line.count("\t") < 2:
            if line.upper().startswith("NAME"):
                continue
        parts = line.split("\t")
        if len(parts) >= 3 and parts[0] != "name":
            rows.append((parts[0], parts[1], parts[2]))
    return rows


def profundizar(tabla: str, meta: dict, meta_all: dict) -> Path:
    t = tabla.upper()
    m = meta_all.get(t, {})
    cols = columnas(t)
    if not cols:
        raise ValueError(f"Sin columnas en PCEM: {t}")
    labels = _labels(t)
    pks = {c.upper() for c in pk_cols(t)}
    fks = fk_rows(t)
    fk_map = {r[0].upper(): r for r in fks}

    titulo = m.get("titulo") or t
    modulo = m.get("modulo") or "Por clasificar"
    proposito = m.get("proposito") or "Documentación ampliada desde PCEM (BA)."
    descripcion = m.get("descripcion") or proposito
    campos_clave: dict[str, str] = m.get("campos_clave") or {}
    relaciones = m.get("relaciones") or ""
    proceso_id = m.get("procesoId") or ""

    lines = [
        f"# {t} — {titulo}",
        "",
        "## Información General",
        "",
        f"- **Nombre de Tabla**: `{t}`",
        "- **Schema**: `dbo`",
        f"- **Módulo**: {modulo}",
        f"- **Propósito**: {proposito}",
    ]
    if proceso_id:
        lines.append(f"- **Proceso BA**: `{proceso_id}`")
    lines.extend(["", "## Descripción", "", descripcion, ""])

    if campos_clave:
        lines.extend(["## Campos principales", "", "| Campo | Descripción |", "|-------|-------------|"])
        for campo, desc in campos_clave.items():
            pk = " (PK)" if campo.upper() in pks else ""
            lines.append(f"| `{campo}`{pk} | {desc} |")
        lines.append("")

    if pks:
        lines.extend(["## Clave primaria", "", ", ".join(f"`{c}`" for c in sorted(pks, key=str.lower)), ""])

    if fks:
        lines.extend(["## Relaciones (FK declaradas)", "", "| Columna | Tabla referenciada | Columna |", "|---------|-------------------|---------|"])
        for pc, tr, cr in fks:
            lines.append(f"| `{pc}` | `{tr}` | `{cr}` |")
        lines.append("")

    if relaciones:
        lines.extend(["## Relaciones y uso en Qrystalos", "", relaciones, ""])

    lines.extend(["## Catálogo de columnas", "", "| Campo | Tipo | Nulo | Rotulo (Clarion) | Notas |", "|-------|------|------|-------------------|-------|"])
    for name, typ, extra, nullable in cols:
        tipo = typ + (f"({extra})" if extra and extra not in ("NULL", "") else "")
        rot = labels.get(name.upper(), "")
        notes = []
        nu = name.upper()
        if nu in pks:
            notes.append("PK")
        if nu in fk_map:
            notes.append(f"FK→{fk_map[nu][1]}")
        if nu in campos_clave:
            notes.append("clave doc")
        lines.append(f"| `{name}` | {tipo} | {nullable or ''} | {rot} | {'; '.join(notes)} |")

    lines.extend(
        [
            "",
            "## Notas",
            "",
            f"- Ficha profundizada por oficina BA (Documentar) el {date.today().isoformat()}.",
            "- Columnas y FK desde catálogo PCEM; completar reglas de negocio en revisiones posteriores.",
            "",
        ]
    )

    dest = DOC_TABLAS / f"{t}.md"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(lines), encoding="utf-8")
    return dest


def main(argv: list[str]) -> None:
    meta_path = META_DEFAULT
    tablas: list[str] = []
    i = 1
    while i < len(argv):
        if argv[i] == "--meta" and i + 1 < len(argv):
            meta_path = Path(argv[i + 1])
            i += 2
        else:
            tablas.append(argv[i])
            i += 1
    if not tablas:
        meta_all = json.loads(meta_path.read_text(encoding="utf-8"))
        tablas = sorted(meta_all.keys())
    else:
        meta_all = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.is_file() else {}

    ok, err = 0, 0
    for t in tablas:
        try:
            profundizar(t, {}, meta_all)
            print("OK", t.upper())
            ok += 1
        except Exception as e:
            print("ERR", t, e)
            err += 1
    print(f"--- hecho={ok} err={err}")


if __name__ == "__main__":
    main(sys.argv)
