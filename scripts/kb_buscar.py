#!/usr/bin/env python3
"""Busca en conocimiento/_indice_busqueda.json y devuelve SOLO la ficha pedida.

    python scripts/kb_buscar.py SPQ_CONF_CAJA/INFO_CAJA
    python scripts/kb_buscar.py BSRES          # tabla
    python scripts/kb_buscar.py /admin/caja     # pantalla
    python scripts/kb_buscar.py caja/entrar-pantalla   # control
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import kb_indice

_RE_RUTA = re.compile(r"(\w+)\[(\d+)\]")


def _extraer(archivo: str, ruta: str):
    data = kb_indice._leer(kb_indice.ROOT / archivo, None)
    if isinstance(data, list) and ruta.startswith("sps["):
        data = {"sps": data}
    for clave, idx in _RE_RUTA.findall(ruta):
        if isinstance(data, dict) and clave == "controles" and "controles" not in data:
            clave = "gates"
        if isinstance(data, dict) and clave == "sps" and "sps" not in data:
            clave = "procedimientos"
        try:
            data = data[clave][int(idx)]
        except (KeyError, IndexError, TypeError):
            return None
    return data


def _resumen_sp(sp: dict) -> dict:
    out = {k: v for k, v in sp.items() if k != "metodos"}
    out["metodos"] = [m.get("id") for m in sp.get("metodos") or [] if isinstance(m, dict)]
    return out


def _cargar_indice() -> dict:
    if not kb_indice.INDICE_BUSQUEDA.is_file():
        kb_indice.regenerar()
    return kb_indice._leer(kb_indice.INDICE_BUSQUEDA, {}) or {}


def buscar(q: str, limite: int = 5) -> dict:
    q = (q or "").strip()
    if not q:
        return {"ok": False, "error": "consulta vacía"}
    idx = _cargar_indice()
    up = q.upper().replace(".", "/") if "/" not in q and q.count(".") == 1 and q.split(".")[0].upper().startswith(("SP", "FN")) else q.upper()
    candidatos = [
        ("metodo", up), ("sp", up), ("tabla", up), ("control", q), ("pantalla", q.lower()), ("termino", q), ("termino", q.lower()), ("termino", up),
    ]
    for tipo, clave in candidatos:
        refs = (idx.get(tipo) or {}).get(clave)
        if not refs:
            continue
        if tipo == "termino":
            procs = [{"proceso": p, **(idx.get("procesos") or {}).get(p, {})} for p in refs]
            return {"ok": True, "tipo": tipo, "clave": clave, "procesos": procs[:limite]}
        refs = sorted(refs, key=lambda r: not r.get("canonico", True))[:limite]
        fichas = []
        for r in refs:
            ficha = _extraer(r["archivo"], r["ruta"])
            if tipo == "sp" and isinstance(ficha, dict):
                ficha = _resumen_sp(ficha)
            fichas.append({**r, "ficha": ficha})
        return {"ok": True, "tipo": tipo, "clave": clave, "resultados": fichas}
    # Búsqueda parcial: claves que contienen el texto (solo referencias, sin fichas).
    sugerencias = []
    for tipo in ("metodo", "sp", "tabla", "pantalla", "control"):
        for clave in idx.get(tipo) or {}:
            if up in clave.upper():
                sugerencias.append({"tipo": tipo, "clave": clave})
                if len(sugerencias) >= 20:
                    break
    return {"ok": bool(sugerencias), "tipo": "sugerencias", "clave": q, "sugerencias": sugerencias}


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    print(json.dumps(buscar(" ".join(argv)), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    sys.exit(main(sys.argv[1:]))
