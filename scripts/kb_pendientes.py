#!/usr/bin/env python3
"""Pendientes de la base: archivo de cerrados y prioridad de los abiertos.

- conocimiento/pendientes.json          -> solo abiertos (lo que la app y los agentes leen)
- conocimiento/pendientes-archivo.json  -> completados / cerrados / hechos (histórico)

    python scripts/kb_pendientes.py            # archiva y prioriza (idempotente)
    python scripts/kb_pendientes.py --solo-ver # muestra el reparto sin escribir

Prioridad (alta/media/baja) solo se calcula si el ítem no trae una puesta a mano
(campo prioridadManual=true la protege):
  alta  = el proceso tiene un REQ/caso abierto, tipo defecto/control, texto de posible defecto, o se pidió 3+ veces
  media = se pidió 2 veces, o el proceso está entre las prioridades 1-10 del INDICE
  baja  = el resto
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KB = ROOT / "conocimiento"
PENDIENTES = KB / "pendientes.json"
ARCHIVO = KB / "pendientes-archivo.json"
_RE_DEFECTO = re.compile(r"equivocad|errad|descuadr|no se puede|sin rama|no valida|duplica|bloquea|falla|incorrect")
CERRADOS = {"completado", "cerrado", "hecho"}


def _leer(path: Path, defecto):
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return defecto


def _escribir(path: Path, data) -> None:
    tmp = path.with_name(path.name + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    tmp.replace(path)


def _ahora() -> str:
    return datetime.now().isoformat(timespec="seconds")


def cargar_archivo() -> dict:
    data = _leer(ARCHIVO, None) or {}
    data.setdefault("items", [])
    return data


def procesos_con_req_abierto() -> set[str]:
    """procesoId de casos activos (activo/*/solicitud.json) y módulos de REQ no enviados."""
    salida: set[str] = set()
    activo = ROOT / "activo"
    if activo.is_dir():
        for sol in activo.glob("*/solicitud.json"):
            d = _leer(sol, {}) or {}
            pid = ((d.get("sql") or {}).get("procesoId") or d.get("procesoId") or "").strip()
            if pid:
                salida.add(pid)
    indice = _leer(KB / "INDICE.json", {}) or {}
    modulos = {}
    for p in indice.get("procesos") or []:
        cod = re.split(r"[\s·_]", str(p.get("modulo") or "").upper())[0]
        if cod:
            modulos.setdefault(cod, p.get("carpeta") or p.get("id"))
    for r in _leer(ROOT / "historico" / "registro.json", []) or []:
        if r.get("estado") in ("enviado", "aprobado"):
            continue
        cod = re.split(r"[\s·_]", str(r.get("modulo") or "").upper())[0]
        if cod in modulos:
            salida.add(modulos[cod])
    return salida


def _clave_rep(it: dict) -> str:
    sp = (it.get("spNombre") or "").strip().upper()
    if sp:
        return "sp:" + sp
    return "t:" + (it.get("procesoId") or "") + ":" + re.sub(r"\W+", " ", (it.get("titulo") or "").lower()).strip()


def priorizar(items: list[dict], historico: list[dict]) -> None:
    con_req = procesos_con_req_abierto()
    indice = _leer(KB / "INDICE.json", {}) or {}
    top = {p.get("carpeta") or p.get("id") for p in indice.get("procesos") or [] if isinstance(p.get("prioridad"), int) and p["prioridad"] <= 10}
    veces = Counter(_clave_rep(i) for i in list(items) + list(historico))
    for it in items:
        if it.get("prioridadManual") and it.get("prioridad") in ("alta", "media", "baja"):
            continue
        n = veces[_clave_rep(it)]
        motivo = []
        if it.get("procesoId") in con_req:
            motivo.append("REQ abierto")
        if it.get("tipo") in ("defecto", "gate", "control"):
            motivo.append(f"tipo {it.get('tipo')}")
        texto = f"{it.get('titulo') or ''} {it.get('detalle') or ''}".lower()
        if _RE_DEFECTO.search(texto):
            motivo.append("posible defecto")
        if n >= 3:
            motivo.append(f"pedido {n} veces")
        if motivo:
            prio = "alta"
        elif n >= 2 or it.get("procesoId") in top:
            prio = "media"
            motivo.append(f"pedido {n} veces" if n >= 2 else "proceso prioritario")
        else:
            prio = "baja"
        it["prioridad"] = prio
        it["prioridadMotivo"] = ", ".join(motivo)


def normalizar(data: dict) -> tuple[dict, int]:
    """Mueve cerrados al archivo y prioriza abiertos. Devuelve (data, movidos)."""
    items = data.get("items") or []
    abiertos = [i for i in items if str(i.get("estado") or "").lower() not in CERRADOS]
    cerrados = [i for i in items if str(i.get("estado") or "").lower() in CERRADOS]
    arch = cargar_archivo()
    if cerrados:
        ids = {i.get("id") for i in arch["items"]}
        arch["items"].extend(i for i in cerrados if i.get("id") not in ids)
        arch["actualizado"] = _ahora()
        arch.setdefault("nota", "Pendientes completados o cerrados. No los lee el agente en cada turno.")
        _escribir(ARCHIVO, arch)
    priorizar(abiertos, arch["items"])
    orden = {"alta": 0, "media": 1, "baja": 2}
    abiertos.sort(key=lambda i: (orden.get(i.get("prioridad"), 3), i.get("creadoEn") or ""))
    data["items"] = abiertos
    data["archivo"] = "pendientes-archivo.json"
    return data, len(cerrados)


def reabrir_desde_archivo(pendiente_id: str) -> dict | None:
    arch = cargar_archivo()
    for n, it in enumerate(arch["items"]):
        if it.get("id") == pendiente_id:
            arch["items"].pop(n)
            arch["actualizado"] = _ahora()
            _escribir(ARCHIVO, arch)
            return it
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--solo-ver", action="store_true")
    a = ap.parse_args()
    data = _leer(PENDIENTES, {"items": []}) or {"items": []}
    antes = len(data.get("items") or [])
    if a.solo_ver:
        estados = Counter(str(i.get("estado")) for i in data.get("items") or [])
        print(antes, dict(estados))
        return 0
    data, movidos = normalizar(data)
    data["actualizado"] = _ahora()
    _escribir(PENDIENTES, data)
    prios = Counter(i.get("prioridad") for i in data["items"])
    print(f"Pendientes: {antes} -> {len(data['items'])} abiertos; archivados {movidos}; prioridad {dict(prios)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
