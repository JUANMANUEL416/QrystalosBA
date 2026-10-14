"""Evita ventanas negras de consola en Windows al lanzar procesos hijos.

instalar() hace que todo subprocess.Popen (y por tanto subprocess.run/call,
asyncio.create_subprocess_exec y el puente node del cursor-sdk) arranque con
CREATE_NO_WINDOW y SW_HIDE salvo que el llamador pida otra cosa.
run_hidden() es el atajo explícito para código nuevo.
"""
from __future__ import annotations

import os
import subprocess

CREATE_NO_WINDOW = 0x08000000
_NUEVAS_CONSOLAS = 0x00000010 | 0x00000008  # CREATE_NEW_CONSOLE | DETACHED_PROCESS
_instalado = False


def _startupinfo_oculto():
    si = subprocess.STARTUPINFO()  # type: ignore[attr-defined]
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW  # type: ignore[attr-defined]
    si.wShowWindow = 0  # SW_HIDE
    return si


def opciones_ocultas() -> dict:
    if os.name != "nt":
        return {}
    return {"creationflags": CREATE_NO_WINDOW, "startupinfo": _startupinfo_oculto()}


def run_hidden(cmd, **kwargs):
    if os.name == "nt":
        kwargs.setdefault("creationflags", CREATE_NO_WINDOW)
        kwargs.setdefault("startupinfo", _startupinfo_oculto())
    return subprocess.run(cmd, **kwargs)


def instalar() -> None:
    global _instalado
    if _instalado or os.name != "nt":
        return
    original = subprocess.Popen.__init__

    def __init__(self, *args, **kwargs):
        flags = kwargs.get("creationflags", 0) or 0
        if not flags & _NUEVAS_CONSOLAS:
            kwargs["creationflags"] = flags | CREATE_NO_WINDOW
        if kwargs.get("startupinfo") is None:
            kwargs["startupinfo"] = _startupinfo_oculto()
        original(self, *args, **kwargs)

    subprocess.Popen.__init__ = __init__  # type: ignore[method-assign]
    _instalado = True
