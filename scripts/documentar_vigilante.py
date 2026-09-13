#!/usr/bin/env python3
"""Vigilante de Documentar — DESACTIVADO.

La base de conocimiento ya está adelantada. No hay barrido automático.
Documentar y Consultas solo corren cuando el coordinador escribe en el Chat;
al terminar el turno el bot queda en estado listo (no sigue solo).
"""
from __future__ import annotations

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import conocimiento as kb  # noqa: E402
from datetime import datetime

_started = False


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def tick() -> dict:
    """No-op: el barrido ya no existe."""
    return {"ok": True, "accion": "deshabilitado"}


def start_background(delay_inicial: int = 20, forzar: bool = False) -> None:
    """Nunca arranca hilo. Fuerza vigilante inactivo."""
    global _started
    _started = False
    kb._ensure_canal("documentar")
    vig = kb.load_vigilante()
    vig["activo"] = False
    vig["motivoPausa"] = (
        "Barrido eliminado. Composer 2.5 estándar, sin Fast. "
        "Chat o Documentar SP: un turno y se detiene."
    )
    vig["actualizadoEn"] = _now()
    kb.save_vigilante(vig)
    if forzar:
        print("Documentar vigilante: barrido deshabilitado (ignore reanudar)", flush=True)
    else:
        print("Documentar: sin barrido — solo Chat bajo demanda", flush=True)


def ensure_running_if_activo() -> None:
    """No reanuda: el barrido quedó fuera de servicio."""
    start_background(0, forzar=False)
