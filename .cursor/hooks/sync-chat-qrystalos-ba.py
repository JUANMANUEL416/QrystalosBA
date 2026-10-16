#!/usr/bin/env python3
"""Inyecta en Cursor los mensajes que el coordinador escribió en el Chat de la app."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVO = ROOT / "activo"
STAMP = Path(__file__).resolve().parent / ".last-followup.json"


def _read(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _write(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _out(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))


def pruebas_abiertas() -> list:
    base = ROOT / "data" / "pruebas-req"
    if not base.is_dir():
        return []
    out = []
    for carpeta in base.iterdir():
        if not carpeta.is_dir() or not carpeta.name.startswith("pr"):
            continue
        meta = _read(carpeta / "meta.json")
        if meta.get("estado") == "cerrada":
            continue
        chat = _read(carpeta / "chat.json")
        out.append((carpeta.name, meta, chat.get("mensajes") or []))
    out.sort(key=lambda item: item[0], reverse=True)
    return out


def contexto_pruebas() -> str:
    abiertas = pruebas_abiertas()
    if not abiertas:
        return ""
    lineas = [
        "Pruebas de requerimiento abiertas (Soporte → Prueba req).",
        "Orden: base de conocimiento, Qrystalos2, IXONLINE/SQL, base de pruebas en solo lectura.",
        "Responda en data/pruebas-req/{id}/chat.json (autor agente) y deje veredicto y veredictoTexto en meta.json.",
        "",
    ]
    for pid, meta, mensajes in abiertas[:4]:
        lineas.append(
            f"- {pid} · {meta.get('servidorNombre') or meta.get('servidorId') or ''} · {meta.get('baseDatos') or ''}"
        )
        ultimo = ultimo_relevante(mensajes)
        if ultimo and ultimo.get("autor") == "coordinador":
            lineas.append(f"  Coordinador: {ultimo.get('texto')}")
    return "\n".join(lineas)


def casos_abiertos() -> list:
    if not ACTIVO.is_dir():
        return []
    out = []
    for carpeta in ACTIVO.iterdir():
        if not carpeta.is_dir() or carpeta.name.startswith("."):
            continue
        estado = _read(carpeta / "estado.json")
        if estado.get("fase1Cerrada"):
            continue
        chat = _read(carpeta / "chat.json")
        out.append((carpeta.name, estado, chat.get("mensajes") or []))
    out.sort(key=lambda item: item[0], reverse=True)
    return out


def ultimo_relevante(mensajes: list) -> dict | None:
    for msg in reversed(mensajes):
        if msg.get("autor") != "sistema":
            return msg
    return None


def pendientes(casos: list) -> list:
    items = []
    for id_caso, estado, mensajes in casos:
        ultimo = ultimo_relevante(mensajes)
        if ultimo and ultimo.get("autor") == "coordinador":
            items.append((id_caso, estado, mensajes, ultimo))
    return items


def contexto(pend: list) -> str:
    lineas = [
        "El coordinador escribe SOLO en el Chat de la app (activo/{id-caso}/chat.json).",
        "No pida que pegue el mismo texto en Cursor.",
        "Responda en chat.json con autor agente. Si cambia el dictamen, deje el enlace dictamenes/{id}.html.",
        "",
    ]
    for id_caso, estado, mensajes, ultimo in pend:
        lineas.append(f"## Caso {id_caso} — mensaje pendiente del coordinador")
        lineas.append(f"ID REQ: {estado.get('idReq') or ''}")
        lineas.append(f"Fecha: {ultimo.get('fecha') or ''}")
        lineas.append(str(ultimo.get("texto") or ""))
        lineas.append("")
        recientes = [m for m in mensajes if m.get("autor") != "sistema"][-6:]
        if len(recientes) > 1:
            lineas.append("Últimos mensajes:")
            for msg in recientes:
                lineas.append(f"- [{msg.get('autor')}] {msg.get('texto')}")
            lineas.append("")
    return "\n".join(lineas)


def main() -> None:
    evento = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        raw = sys.stdin.read()
        if raw.strip():
            json.loads(raw)
    except json.JSONDecodeError:
        pass

    casos = casos_abiertos()
    pend = pendientes(casos)

    if evento == "stop":
        if not pend:
            _out({})
            return
        key = "|".join(f"{id_caso}:{ultimo.get('id')}" for id_caso, _, _, ultimo in pend)
        if _read(STAMP).get("key") == key:
            _out({})
            return
        _write(STAMP, {"key": key})
        _out(
            {
                "followup_message": (
                    "Hay mensajes nuevos del coordinador en el Chat de la app. "
                    "Lea activo/*/chat.json, responda ahí (autor: agente) y no pida que los pegue en Cursor."
                )
            }
        )
        return

    extra = contexto_pruebas()

    if pend:
        texto = contexto(pend)
        if extra:
            texto += "\n\n" + extra
        _out(
            {
                "additional_context": texto,
                "agent_message": (
                    f"{len(pend)} mensaje(s) pendiente(s) en el Chat de la app. "
                    "Responda en chat.json; no pida que los peguen."
                ),
            }
        )
        return

    if casos:
        ids = ", ".join(item[0] for item in casos[:3])
        texto = (
            f"Caso(s) activo(s): {ids}. El coordinador escribe solo en el Chat de la app. "
            "Si responde en Cursor, deje el mismo resumen en activo/{id-caso}/chat.json (autor: agente)."
        )
        if extra:
            texto += "\n\n" + extra
        _out({"additional_context": texto})
        return

    if extra:
        _out({"additional_context": extra})
        return

    _out({})


if __name__ == "__main__":
    main()
