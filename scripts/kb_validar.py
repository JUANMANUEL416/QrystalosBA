#!/usr/bin/env python3
"""Valida la base de conocimiento contra conocimiento/_schema/*.json.

    python scripts/kb_validar.py              # informe (no cambia nada)
    python scripts/kb_validar.py --json       # informe en JSON
    python scripts/kb_validar.py --degradar   # fichas 'leido' vacías -> 'parcial'

Regla clave: un METODO 'leido' debe tener valida, errores y efecto (o "no aplica").
--degradar solo toca las fichas GRAVES: sin valida, sin errores, sin efecto y
casi sin texto (menos de --min-chars caracteres). El resto queda como aviso.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kb_indice  # noqa: E402

KB = kb_indice.KB
SCHEMA_DIR = KB / "_schema"
_TIPOS = {"object": dict, "array": list, "string": str, "integer": int, "number": (int, float), "boolean": bool, "null": type(None)}
CAMPOS_LEIDO = ("valida", "errores", "efecto")


def cargar_schemas() -> dict:
    out = {}
    for p in sorted(SCHEMA_DIR.glob("*.schema.json")):
        s = kb_indice._leer(p, {}) or {}
        out[s.get("$id") or p.name.split(".")[0]] = s
    return out


def validar(valor, schema: dict, schemas: dict, ruta: str, errores: list) -> None:
    if "$ref" in schema:
        schema = schemas.get(schema["$ref"], {})
    tipos = schema.get("type")
    if tipos:
        tipos = tipos if isinstance(tipos, list) else [tipos]
        if not any(isinstance(valor, _TIPOS[t]) and not (t == "integer" and isinstance(valor, bool)) for t in tipos):
            errores.append(f"{ruta}: tipo {type(valor).__name__}, se esperaba {'/'.join(tipos)}")
            return
    if "enum" in schema and valor not in schema["enum"]:
        errores.append(f"{ruta}: valor {valor!r} fuera de {schema['enum']}")
    if isinstance(valor, str) and len(valor) < schema.get("minLength", 0):
        errores.append(f"{ruta}: texto vacío")
    if isinstance(valor, dict):
        for req in schema.get("required") or []:
            if req not in valor:
                errores.append(f"{ruta}: falta '{req}'")
        for k, sub in (schema.get("properties") or {}).items():
            if k in valor:
                validar(valor[k], sub, schemas, f"{ruta}.{k}", errores)
    if isinstance(valor, list) and "items" in schema:
        for i, item in enumerate(valor):
            validar(item, schema["items"], schemas, f"{ruta}[{i}]", errores)


def _vacio(v) -> bool:
    return v is None or (isinstance(v, (str, list, dict)) and len(v) == 0)


def _no_aplica(v) -> bool:
    if isinstance(v, str):
        return v.strip().lower().startswith("no aplica")
    if isinstance(v, list) and len(v) == 1 and isinstance(v[0], str):
        return v[0].strip().lower().startswith("no aplica")
    return False


def revisar_leido(met: dict, min_chars: int) -> str:
    """'' si está bien, 'aviso' si le falta algo, 'grave' si es una ficha vacía."""
    if met.get("estado") != "leido":
        return ""
    faltan = [c for c in CAMPOS_LEIDO if _vacio(met.get(c)) and not _no_aplica(met.get(c))]
    if not faltan:
        return ""
    if len(faltan) == len(CAMPOS_LEIDO) and len(json.dumps(met, ensure_ascii=False)) < min_chars:
        return "grave"
    return "aviso"


def ejecutar(degradar: bool = False, min_chars: int = 160) -> dict:
    schemas = cargar_schemas()
    errores: list[str] = []
    graves, avisos = [], []
    estados = Counter()
    cambiados = 0
    degradados: list[str] = []
    validar(kb_indice._leer(KB / "INDICE.json", {}), schemas["indice"], schemas, "INDICE.json", errores)
    for pid in kb_indice.carpetas_proceso():
        pp = KB / pid / "proceso.json"
        if pp.is_file():
            validar(kb_indice._leer(pp, {}), schemas["proceso"], schemas, f"{pid}/proceso.json", errores)
        sp_path = KB / pid / "sps.json"
        if not sp_path.is_file():
            continue
        data = kb_indice._leer(sp_path, None)
        validar(data, schemas["sps"], schemas, f"{pid}/sps.json", errores)
        lineas = sp_path.read_text(encoding="utf-8").splitlines(keepends=True) if degradar else []
        loc = kb_indice._Lineas(sp_path) if degradar else None
        tocado = False
        for si, sp in enumerate(kb_indice.lista_sps(data)):
            if not isinstance(sp, dict):
                continue
            l_sp = loc.buscar("nombre", sp.get("nombre") or "") if loc and sp.get("nombre") else 0
            for mi, met in enumerate(sp.get("metodos") or []):
                if not isinstance(met, dict):
                    continue
                estados[str(met.get("estado"))] += 1
                nivel = revisar_leido(met, min_chars)
                if not nivel:
                    continue
                ref = f"{pid}:{sp.get('nombre')}/{met.get('id')}"
                (graves if nivel == "grave" else avisos).append(ref)
                if nivel == "grave" and degradar and l_sp:
                    # Edición de texto mínima: solo cambia la línea "estado" de ese METODO.
                    l_id = loc.buscar("id", str(met.get("id")), desde=l_sp)
                    for j in range(l_id - 1 if l_id else len(lineas), len(lineas)):
                        if re.search(r'"estado"\s*:\s*"leido"', lineas[j]):
                            lineas[j] = re.sub(r'("estado"\s*:\s*)"leido"', r'\1"parcial"', lineas[j], count=1)
                            met["estado"] = "parcial"
                            tocado = True
                            cambiados += 1
                            degradados.append(ref)
                            break
                        if j > l_id - 1 and re.match(r"\s*\{\s*$", lineas[j]):
                            break
        if tocado:
            tmp = sp_path.with_name(sp_path.name + ".tmp")
            tmp.write_text("".join(lineas), encoding="utf-8", newline="")
            tmp.replace(sp_path)
    pend = kb_indice._leer(KB / "pendientes.json", {}) or {}
    for i, it in enumerate(pend.get("items") or []):
        validar(it, schemas["pendiente"], schemas, f"pendientes.json.items[{i}]", errores)
    cola = kb_indice._leer(KB / "handoffs" / "cola.json", []) or []
    for i, it in enumerate(cola if isinstance(cola, list) else []):
        validar(it, schemas["handoff"], schemas, f"handoffs/cola.json[{i}]", errores)
    if cambiados:
        reg = KB / "_schema" / "degradados.json"
        previo = kb_indice._leer(reg, {}) or {}
        lista = sorted(set(previo.get("metodos") or []) | set(degradados))
        kb_indice._escribir(reg, {"nota": "METODO pasados de leido a parcial por kb_validar --degradar: faltaban valida, errores y efecto. Releer el .sql y completar.", "metodos": lista})
        kb_indice.regenerar()
    return {
        "estructura": errores,
        "leidoGrave": graves,
        "leidoIncompleto": avisos,
        "estadosMetodo": dict(estados),
        "degradados": cambiados,
    }


def _escribir_sps(path: Path, data) -> None:
    """Mismo formato que conocimiento.py (_write_json): indent 2, utf-8, LF."""
    tmp = path.with_name(path.name + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    tmp.replace(path)


def main() -> int:
    ap = argparse.ArgumentParser(description="Valida conocimiento/")
    ap.add_argument("--degradar", action="store_true", help="Pasa a 'parcial' las fichas leido graves")
    ap.add_argument("--min-chars", type=int, default=160)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    r = ejecutar(a.degradar, a.min_chars)
    if a.json:
        print(json.dumps(r, ensure_ascii=False, indent=2))
    else:
        print(f"Errores de estructura: {len(r['estructura'])}")
        for e in r["estructura"][:40]:
            print("  -", e)
        print(f"METODO leido graves (vacíos): {len(r['leidoGrave'])}")
        print(f"METODO leido incompletos (aviso): {len(r['leidoIncompleto'])}")
        print(f"Estados METODO: {r['estadosMetodo']}")
        print(f"Degradados a parcial: {r['degradados']}")
    return 1 if r["estructura"] else 0


if __name__ == "__main__":
    sys.exit(main())
