#!/usr/bin/env python3
"""Cola de handoffs entre agentes (conocimiento/handoffs/cola.json). Contrato: conocimiento/HANDOFF.md.

    python scripts/kb_handoff.py listar [rol]
    python scripts/kb_handoff.py encolar consultas conocimiento documentar_metodo '{"proceso":"caja","sp":"SPQ_CONF_CAJA","metodo":"CONFIRMAR","pregunta":"..."}'
    python scripts/kb_handoff.py responder ho-20261014-001 "texto"
"""
from __future__ import annotations

import json
import os
import sys
import threading
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "conocimiento" / "handoffs"
COLA = DIR / "cola.json"
ROLES = ("conocimiento", "consultas", "requerimientos")
TIPOS = ("documentar_metodo", "confirmar_hueco", "respuesta_consulta", "impacto_req", "pedir_sql")
ESTADOS_ABIERTOS = ("pendiente", "en_progreso")
_lock = threading.Lock()
# Nombres viejos de perfiles -> rol nuevo.
ALIAS_ROL = {"documentar": "conocimiento", "analista": "requerimientos", "solicitar": "requerimientos", "contabilidad": "requerimientos", "soporte-consultas": "consultas"}


def _ahora() -> str:
    return datetime.now().isoformat(timespec="seconds")


def rol(nombre: str) -> str:
    nombre = (nombre or "").strip().lower()
    nombre = ALIAS_ROL.get(nombre, nombre)
    if nombre not in ROLES and nombre != "coordinador":
        raise ValueError(f"Rol desconocido: {nombre}")
    return nombre


def leer() -> list[dict]:
    try:
        with COLA.open(encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, list) else []
    except (OSError, ValueError):
        return []


def _guardar(cola: list[dict]) -> None:
    DIR.mkdir(parents=True, exist_ok=True)
    tmp = COLA.with_name(f"cola.json.{os.getpid()}.tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(cola, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    os.replace(tmp, COLA)


def _nuevo_id(cola: list[dict]) -> str:
    base = "ho-" + datetime.now().strftime("%Y%m%d") + "-"
    n = sum(1 for h in cola if str(h.get("id", "")).startswith(base)) + 1
    return f"{base}{n:03d}"


def encolar(de: str, para: str, tipo: str, contexto: dict, prioridad: str = "media") -> dict:
    de, para = rol(de), rol(para)
    if tipo not in TIPOS:
        raise ValueError(f"Tipo inválido: {tipo}")
    if prioridad not in ("alta", "media", "baja"):
        prioridad = "media"
    ctx = {k: contexto.get(k) for k in ("proceso", "sp", "metodo", "idCaso", "pregunta", "evidencia")}
    with _lock:
        cola = leer()
        # Evita duplicados: misma pregunta abierta sobre el mismo SP/METODO.
        for h in cola:
            c = h.get("contexto") or {}
            if h.get("para") == para and h.get("estado") in ESTADOS_ABIERTOS and c.get("sp") == ctx.get("sp") and c.get("metodo") == ctx.get("metodo") and ctx.get("sp"):
                h.setdefault("vecesPedido", 1)
                h["vecesPedido"] += 1
                if prioridad == "alta" or h["vecesPedido"] >= 3:
                    h["prioridad"] = "alta"
                h["actualizadoEn"] = _ahora()
                _guardar(cola)
                return h
        h = {
            "id": _nuevo_id(cola), "de": de, "para": para, "tipo": tipo, "prioridad": prioridad,
            "contexto": ctx, "estado": "pendiente", "respuesta": None,
            "creadoEn": _ahora(), "actualizadoEn": _ahora(),
        }
        cola.append(h)
        _guardar(cola)
        return h


def _cambiar(hid: str, **campos) -> dict | None:
    with _lock:
        cola = leer()
        for h in cola:
            if h.get("id") == hid:
                h.update(campos)
                h["actualizadoEn"] = _ahora()
                _guardar(cola)
                return h
    return None


def tomar(hid: str) -> dict | None:
    return _cambiar(hid, estado="en_progreso")


def responder(hid: str, respuesta, bloqueado: bool = False) -> dict | None:
    return _cambiar(hid, estado="bloqueado" if bloqueado else "respondido", respuesta=respuesta)


def cerrar(hid: str) -> dict | None:
    """El emisor ya usó la respuesta."""
    return _cambiar(hid, estado="cerrado")


def abiertos_para(rol_destino: str) -> list[dict]:
    r = rol(rol_destino)
    orden = {"alta": 0, "media": 1, "baja": 2}
    items = [h for h in leer() if h.get("para") == r and h.get("estado") in ESTADOS_ABIERTOS]
    return sorted(items, key=lambda h: (orden.get(h.get("prioridad"), 3), h.get("creadoEn") or ""))


def respuestas_para(rol_emisor: str) -> list[dict]:
    r = rol(rol_emisor)
    return [h for h in leer() if h.get("de") == r and h.get("estado") in ("respondido", "bloqueado")]


def resumen_prompt(rol_agente: str, maximo: int = 5) -> str:
    """Bloque corto para pegar en el prompt: lo que este rol debe atender o leer."""
    r = rol(rol_agente)
    partes = []
    pend = abiertos_para(r)[:maximo]
    if pend:
        partes.append(f"HANDOFFS PARA {r.upper()} (atiéndalos ANTES que cualquier otra cosa, en este orden):")
        for h in pend:
            c = h.get("contexto") or {}
            partes.append(f"- {h['id']} [{h.get('prioridad')}] {h.get('tipo')} de {h.get('de')}: proceso={c.get('proceso') or '—'} sp={c.get('sp') or '—'} metodo={c.get('metodo') or '—'} · {str(c.get('pregunta') or '')[:240]}")
    resp = respuestas_para(r)[:maximo]
    if resp:
        partes.append("RESPUESTAS DE CONOCIMIENTO A SUS HANDOFFS (úselas y luego ponga estado cerrado):")
        for h in resp:
            partes.append(f"- {h['id']} {h.get('estado')}: {str(h.get('respuesta') or '')[:300]}")
    if not partes:
        return ""
    partes.append("Cola: conocimiento/handoffs/cola.json · contrato: conocimiento/HANDOFF.md")
    return "\n".join(partes)


def main(argv: list[str]) -> int:
    if not argv or argv[0] == "listar":
        r = argv[1] if len(argv) > 1 else None
        items = abiertos_para(r) if r else leer()
        print(json.dumps(items, ensure_ascii=False, indent=2))
        return 0
    if argv[0] == "encolar" and len(argv) >= 5:
        print(json.dumps(encolar(argv[1], argv[2], argv[3], json.loads(argv[4]), argv[5] if len(argv) > 5 else "media"), ensure_ascii=False, indent=2))
        return 0
    if argv[0] == "responder" and len(argv) >= 3:
        print(json.dumps(responder(argv[1], argv[2]), ensure_ascii=False, indent=2))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
