# -*- coding: utf-8 -*-
"""Topes de gasto al modelo: tamaño del prompt y intentos del segundo plano."""
from __future__ import annotations

import json
import os
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(ROOT, "config", "topes_modelo.json")

_DEFECTO = {"estimado": 25000, "maximo": 50000, "proceso": "general"}
_INTENTOS = {"maxSinError": 2, "maxConError": 2, "erroresComunicacion": []}


def cargar() -> dict:
    try:
        with open(RUTA, encoding="utf-8") as fh:
            datos = json.load(fh)
        if isinstance(datos, dict):
            return datos
    except (OSError, json.JSONDecodeError):
        pass
    return {"porMotivo": {}, "defecto": dict(_DEFECTO), "intentosSegundoPlano": dict(_INTENTOS)}


def tope_de(motivo: str) -> dict:
    cfg = cargar()
    fila = (cfg.get("porMotivo") or {}).get((motivo or "").strip())
    if isinstance(fila, dict) and fila.get("maximo"):
        return {
            "estimado": int(fila.get("estimado") or _DEFECTO["estimado"]),
            "maximo": int(fila.get("maximo") or _DEFECTO["maximo"]),
            "proceso": str(fila.get("proceso") or _DEFECTO["proceso"]),
        }
    d = cfg.get("defecto") if isinstance(cfg.get("defecto"), dict) else _DEFECTO
    return {
        "estimado": int(d.get("estimado") or _DEFECTO["estimado"]),
        "maximo": int(d.get("maximo") or _DEFECTO["maximo"]),
        "proceso": str(d.get("proceso") or _DEFECTO["proceso"]),
    }


def medir_prompt(texto: str) -> int:
    return len(texto or "")


def decision_peso(chars: int, motivo: str, aval_continuar: bool = False) -> dict[str, Any]:
    """ok | aviso (sobre estimado) | bloquear (sobre máximo sin aval)."""
    tope = tope_de(motivo)
    chars = int(chars or 0)
    out = {
        "ok": True,
        "chars": chars,
        "estimado": tope["estimado"],
        "maximo": tope["maximo"],
        "proceso": tope["proceso"],
        "motivo": motivo,
        "estado": "ok",
        "mensaje": "",
    }
    if chars <= tope["estimado"]:
        return out
    if chars <= tope["maximo"]:
        out["estado"] = "aviso"
        out["mensaje"] = (
            f"El prompt de «{motivo}» pesa {chars} caracteres "
            f"(estimado {tope['estimado']}, máximo {tope['maximo']}). Sigue, pero limpie historial si puede."
        )
        return out
    if aval_continuar:
        out["estado"] = "avalado"
        out["mensaje"] = (
            f"Peso {chars} por encima del máximo {tope['maximo']}. "
            "El usuario avaló continuar."
        )
        return out
    out["ok"] = False
    out["estado"] = "bloquear"
    out["mensaje"] = (
        f"El prompt de «{motivo}» pesa {chars} caracteres y supera el máximo "
        f"({tope['maximo']}; estimado {tope['estimado']}). "
        "No se lanza. Limpie el análisis o avale continuar (contexto grande a propósito)."
    )
    return out


def es_error_comunicacion(texto: str) -> bool:
    cfg = cargar().get("intentosSegundoPlano") or {}
    marcas = cfg.get("erroresComunicacion") or _INTENTOS["erroresComunicacion"]
    t = (texto or "").lower()
    return any(str(m).lower() in t for m in marcas if m)


def max_intentos(hubo_error_com: bool = False) -> int:
    cfg = cargar().get("intentosSegundoPlano") or {}
    if hubo_error_com:
        return int(cfg.get("maxConError") or 2)
    return int(cfg.get("maxSinError") or 2)


def decision_intento(intentos: int, ultimo_error: str = "") -> dict[str, Any]:
    """¿Se puede arrancar otra vez el análisis posterior de este REQ?"""
    com = es_error_comunicacion(ultimo_error)
    tope = max_intentos(com)
    n = int(intentos or 0)
    if n >= tope:
        return {
            "ok": False,
            "intentos": n,
            "maximo": tope,
            "errorComunicacion": com,
            "mensaje": (
                f"Este REQ ya tuvo {n} intento(s) de análisis en segundo plano "
                f"(máximo {tope}"
                + (" tras error de comunicación" if com else " sin error de comunicación")
                + "). No se relanza solo. Use Volver a analizar si hace falta."
            ),
        }
    return {
        "ok": True,
        "intentos": n,
        "maximo": tope,
        "errorComunicacion": com,
        "mensaje": "",
    }
