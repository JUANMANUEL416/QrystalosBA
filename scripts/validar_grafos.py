#!/usr/bin/env python3
"""Integridad de los grafos contables (conocimiento/contabilidad/grafo-contabilizacion/*.json).

Revisa: ids únicos, llamaAnterior apunta a nodos que existen, sin huérfanos, sin ciclos
y, en grafos con ordenEstado (p. ej. cierre de periodo), que el id N<k> coincida con orden.
    python scripts/validar_grafos.py [archivo.json ...]
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

GDIR = Path(__file__).resolve().parent.parent / "conocimiento" / "contabilidad" / "grafo-contabilizacion"


def validar(path: Path) -> list[str]:
    d = json.loads(path.read_text(encoding="utf-8"))
    nodos = [n for n in d.get("nodos") or [] if isinstance(n, dict)]
    ids = [n.get("id") for n in nodos]
    err = [f"id duplicado {i}" for i in set(ids) if ids.count(i) > 1]
    S = set(ids)
    aristas = [(a, n["id"]) for n in nodos for a in (n.get("llamaAnterior") or []) if isinstance(a, str)]
    err += [f"{b}.llamaAnterior → {a} no existe" for a, b in aristas if a not in S]
    if len(nodos) > 1:
        unidos = {x for e in aristas for x in e}
        err += [f"huérfano {i}" for i in ids if i not in unidos]
    if any("ordenEstado" in n for n in nodos):
        for n in nodos:
            m = re.match(r"N(\d+)-", n.get("id") or "")
            if not m or int(m.group(1)) != n.get("orden"):
                err.append(f"id/orden no coinciden: {n.get('id')} orden={n.get('orden')}")
            if n.get("ordenEstado") not in ("evidenciado", "por_confirmar", "confirmado_usuario"):
                err.append(f"ordenEstado inválido en {n.get('id')}")
    g = defaultdict(list)
    for a, b in aristas:
        g[a].append(b)
    estado: dict[str, int] = {}

    def dfs(u: str) -> None:
        estado[u] = 1
        for v in g[u]:
            if estado.get(v) == 1:
                err.append(f"ciclo {u} → {v}")
            elif not estado.get(v):
                dfs(v)
        estado[u] = 2

    for i in ids:
        if i and not estado.get(i):
            dfs(i)
    return err


def main(argv: list[str]) -> int:
    archivos = [Path(a) for a in argv] or sorted(p for p in GDIR.glob("*.json") if not p.name.startswith(("puntos-criticos", "VALIDACION")))
    fallos = 0
    for p in archivos:
        e = validar(p)
        print(("OK   " if not e else "FALLA") + f" {p.name}" + ("" if not e else ": " + "; ".join(e[:6])))
        fallos += bool(e)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
