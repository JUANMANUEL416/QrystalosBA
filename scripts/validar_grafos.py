#!/usr/bin/env python3
"""Integridad de los grafos de conocimiento.

Cubre contabilidad, accidentes de tránsito, inventario y nómina.
Revisa: ids únicos, llamaAnterior y llamaSiguiente apuntan a nodos que existen,
sin huérfanos, sin ciclos y, en grafos con ordenEstado, que el id N<k> coincida con orden.

Avisa (no falla) los pasos que traen método de pantalla y ningún SP, y los tramos
marcados para releer contra el SQL.

    python scripts/validar_grafos.py [archivo.json ...]
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "conocimiento"
CARPETAS = (
    ROOT / "contabilidad" / "grafo-contabilizacion",
    ROOT / "acctran" / "grafo-acctran",
    ROOT / "inventario" / "grafo-inventario",
    ROOT / "nomina" / "grafo-nomina",
    ROOT / "facturacion" / "grafo-facturacion",
)


def _lista(valor) -> list:
    if isinstance(valor, list):
        return valor
    if isinstance(valor, str) and valor.strip():
        return [valor]
    return []


def _tiene_sp(nodo: dict) -> bool:
    if any(str(x).strip() for x in _lista(nodo.get("sp"))):
        return True
    if any(str(x).strip() for x in _lista(nodo.get("llama"))):
        return True
    for ficha in nodo.get("fichas") or []:
        if isinstance(ficha, dict) and str(ficha.get("sp") or "").strip():
            return True
    return False


def _aristas(nodos: list[dict], campo: str, hacia_adelante: bool) -> list[tuple[str, str]]:
    """Arista en el sentido del flujo: llamaAnterior apunta al paso previo."""
    pares = []
    for n in nodos:
        yo = n.get("id")
        if not isinstance(yo, str):
            continue
        for otro in _lista(n.get(campo)):
            if isinstance(otro, str):
                pares.append((yo, otro) if hacia_adelante else (otro, yo))
    return pares


def validar(path: Path) -> tuple[list[str], list[str]]:
    d = json.loads(path.read_text(encoding="utf-8"))
    nodos = [n for n in d.get("nodos") or [] if isinstance(n, dict)]
    ids = [n.get("id") for n in nodos]
    err = [f"id duplicado {i}" for i in set(ids) if ids.count(i) > 1]
    presentes = {i for i in ids if isinstance(i, str)}
    anteriores = _aristas(nodos, "llamaAnterior", hacia_adelante=False)
    siguientes = _aristas(nodos, "llamaSiguiente", hacia_adelante=True)
    err += [f"{b}.llamaAnterior → {a} no existe" for a, b in anteriores if a not in presentes]
    err += [f"{a}.llamaSiguiente → {b} no existe" for a, b in siguientes if b not in presentes]
    if len(nodos) > 1:
        unidos = {x for a, b in anteriores + siguientes for x in (a, b)}
        err += [f"huérfano {i}" for i in ids if i not in unidos]
    if any("ordenEstado" in n for n in nodos):
        for n in nodos:
            m = re.match(r"N(\d+)-", n.get("id") or "")
            if not m or int(m.group(1)) != n.get("orden"):
                err.append(f"id/orden no coinciden: {n.get('id')} orden={n.get('orden')}")
            if n.get("ordenEstado") not in ("evidenciado", "por_confirmar", "confirmado_usuario"):
                err.append(f"ordenEstado inválido en {n.get('id')}")
    # Una sola dirección: inventario guarda el mismo vínculo en los dos campos.
    flujo = anteriores or [(a, b) for a, b in siguientes]
    g = defaultdict(list)
    for a, b in flujo:
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

    avisos = []
    if path.parent.name in ("grafo-acctran", "grafo-inventario", "grafo-nomina", "grafo-facturacion"):
        for n in nodos:
            if _tiene_sp(n):
                continue
            metodos = [str(x).strip() for x in _lista(n.get("metodoUi")) if str(x).strip()]
            if metodos:
                avisos.append(f"sin SP {n.get('id')} (método de pantalla: {', '.join(metodos[:3])})")
            else:
                avisos.append(f"sin SP {n.get('id')} (paso de interfaz o puente)")
    veredicto = d.get("veredictoFichas") or {}
    if veredicto.get("releerSqlHoy") is True:
        avisos.append("releer contra el SQL")
    return err, avisos


def _archivos() -> list[Path]:
    salida = []
    for carpeta in CARPETAS:
        if not carpeta.is_dir():
            continue
        for p in sorted(carpeta.glob("*.json")):
            if p.name.startswith(("puntos-criticos", "VALIDACION")):
                continue
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                salida.append(p)
                continue
            if isinstance(data, dict) and isinstance(data.get("nodos"), list):
                salida.append(p)
    return salida


def main(argv: list[str]) -> int:
    archivos = [Path(a) for a in argv] or _archivos()
    fallos = 0
    n_sin_sp = 0
    n_releer = 0
    for p in archivos:
        try:
            e, avisos = validar(p)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"FALLA {p.name}: no se pudo leer ({exc})")
            fallos += 1
            continue
        marca = "OK   " if not e else "FALLA"
        detalle = "" if not e else ": " + "; ".join(e[:6])
        print(f"{marca} {p.parent.parent.name}/{p.parent.name}/{p.name}{detalle}")
        for a in avisos:
            print(f"     AVISO {a}")
        n_sin_sp += sum(1 for a in avisos if a.startswith("sin SP"))
        n_releer += sum(1 for a in avisos if a.startswith("releer"))
        fallos += bool(e)
    print(f"{len(archivos)} grafos, {fallos} con fallo, {n_sin_sp} pasos sin SP, {n_releer} por releer")
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
