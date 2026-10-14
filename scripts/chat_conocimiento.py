# -*- coding: utf-8 -*-
"""Chat local sobre conocimiento/. Ubica un proceso y le pasa solo esa ficha a Ollama."""
from __future__ import annotations

import json
import re
import sys
import urllib.request

ROOT = __file__
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
INDICE_PATH = os.path.join(CONOCIMIENTO, "INDICE.json")
OLLAMA = "http://127.0.0.1:11434/api/generate"


def modelo() -> str:
    ruta = os.path.join(ROOT, "config", "agentes.json")
    try:
        with open(ruta, encoding="utf-8") as fh:
            nombre = str(json.load(fh).get("modeloLocal") or "").strip()
        if nombre:
            return nombre
    except (OSError, json.JSONDecodeError, AttributeError, TypeError):
        pass
    return "qwen2.5-coder:7b"


MAX_FICHA = 7000

STOP = {
    "que", "qué", "como", "cómo", "cual", "cuál", "cuales", "cuáles",
    "el", "la", "los", "las", "de", "del", "en", "y", "o", "a", "un", "una",
    "para", "por", "con", "este", "esta", "esto", "ese", "esa", "su", "sus",
    "al", "lo", "se", "es", "son", "hay", "si", "sí", "no", "me", "te",
    "cumple", "funcion", "función", "hace", "sobre", "desde", "cuando",
}


def cargar_indice():
    with open(INDICE_PATH, encoding="utf-8") as f:
        return json.load(f)["procesos"]


def tokens(texto: str) -> set[str]:
    palabras = re.findall(r"[a-z0-9áéíóúñ]{3,}", texto.lower())
    return {p for p in palabras if p not in STOP}


def nombres_objeto(pregunta: str) -> list[str]:
    return re.findall(r"\b(?:SPK|SPQ|FNK|SP)_[A-Z0-9_]+\b", pregunta.upper())


def ficha_objeto(proceso_id: str, nombre: str):
    path = os.path.join(CONOCIMIENTO, proceso_id, "sps.json")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for sp in data.get("sps") or []:
        if (sp.get("nombre") or "").upper() == nombre.upper():
            return sp
    return None


def ubicar(pregunta: str, procesos: list[dict]):
    objs = nombres_objeto(pregunta)
    palabras = tokens(pregunta)
    mejor = None
    mejor_pts = 0
    fichas = []
    for p in procesos:
        pid = p["id"]
        pts = 0
        blob = " ".join(
            [
                pid.replace("-", " "),
                p.get("nombre") or "",
                p.get("familia") or "",
                p.get("modulo") or "",
                p.get("resumen") or "",
            ]
        ).lower()
        for w in palabras:
            if w in blob:
                pts += 2 if w in (p.get("nombre") or "").lower() or w in pid else 1
        halladas = []
        for nombre in objs:
            ficha = ficha_objeto(pid, nombre)
            if ficha:
                halladas.append(ficha)
                pts += 20
        if pts > mejor_pts:
            mejor = p
            mejor_pts = pts
            fichas = halladas
    return mejor, fichas


def texto_base(proceso: dict, fichas: list[dict]) -> str:
    partes = [
        f"Proceso: {proceso.get('nombre')} ({proceso.get('id')})",
        f"Módulo: {proceso.get('modulo') or ''}",
        f"Resumen: {proceso.get('resumen') or ''}",
    ]
    if fichas:
        partes.append("Fichas de la base (solo esto):")
        crudo = json.dumps(fichas, ensure_ascii=False, indent=2)
        partes.append(crudo[:MAX_FICHA])
    else:
        partes.append(
            "No hay ficha de un procedimiento en la pregunta. "
            "Responde solo con el resumen del proceso."
        )
    return "\n".join(partes)


def preguntar(pregunta: str, base: str) -> str:
    cuerpo = {
        "model": modelo(),
        "stream": False,
        "system": (
            "Respondes en español, corto, solo con el texto de la base que te pasan. "
            "Si el dato no está en ese texto, di: No está en la ficha. "
            "No inventes columnas, pantallas ni validaciones."
        ),
        "prompt": f"BASE:\n{base}\n\nPREGUNTA:\n{pregunta}",
        "options": {"temperature": 0.1, "num_predict": 220, "num_ctx": 4096},
    }
    req = urllib.request.Request(
        OLLAMA,
        data=json.dumps(cuerpo).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return (data.get("response") or "").strip()


def una(pregunta: str) -> int:
    procesos = cargar_indice()
    proceso, fichas = ubicar(pregunta, procesos)
    if not proceso:
        print("No ubiqué un proceso en el índice.")
        return 1
    print(f"Proceso: {proceso['id']}")
    if fichas:
        print("Fichas: " + ", ".join(f.get("nombre", "") for f in fichas))
    else:
        print("Fichas: ninguna (solo resumen)")
    print("---")
    print(preguntar(pregunta, texto_base(proceso, fichas)))
    return 0


def chat() -> int:
    print("Chat sobre la base de conocimiento. Escribe /bye para salir.")
    while True:
        try:
            pregunta = input("\n> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not pregunta:
            continue
        if pregunta.lower() in {"/bye", "bye", "salir"}:
            return 0
        una(pregunta)
    return 0


def main() -> int:
    if len(sys.argv) > 1:
        return una(" ".join(sys.argv[1:]))
    return chat()


if __name__ == "__main__":
    raise SystemExit(main())
