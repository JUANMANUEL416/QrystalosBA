#!/usr/bin/env python3
"""Vigilante del agente de Documentar: pasa proceso por proceso sin frenar por .sql."""
from __future__ import annotations

import os
import sys
import threading
import time
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import conocimiento as kb  # noqa: E402
from cursor_bot import DOCUMENTAR_ID, lanzar_bot, leer_estado_bot, load_api_key  # noqa: E402

_started = False


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _segundos_desde(iso) -> float | None:
    if not iso:
        return None
    try:
        return (datetime.now() - datetime.fromisoformat(str(iso))).total_seconds()
    except (TypeError, ValueError):
        return None


def _esperar_bot(timeout_sec: int = 1200) -> dict:
    inicio = time.time()
    ultimo = {}
    while time.time() - inicio < timeout_sec:
        ultimo = leer_estado_bot(DOCUMENTAR_ID)
        if ultimo.get("estado") != "trabajando" or not ultimo.get("pidVivo"):
            return ultimo
        time.sleep(8)
    return ultimo or {"estado": "error", "error": "timeout"}


def tick() -> dict:
    vig = kb.load_vigilante()
    if not vig.get("activo"):
        return {"ok": True, "accion": "pausado"}
    if not load_api_key():
        vig["ultimoError"] = "Falta CURSOR_API_KEY"
        kb.save_vigilante(vig)
        return {"ok": False, "accion": "sin_clave"}

    bot = leer_estado_bot(DOCUMENTAR_ID)
    if bot.get("estado") == "trabajando" and bot.get("pidVivo"):
        return {"ok": True, "accion": "ya_trabajando"}

    valle = kb.siguiente_valle()
    if not valle:
        return _pedir_nuevos_modulos(vig)

    pid = valle["proceso"]["id"]
    nombre = valle["paso"].get("nombre") or pid
    fallos = int(vig.get("fallosSeguidos") or 0)
    if fallos >= 3:
        hace = _segundos_desde(vig.get("ultimoTurnoEn"))
        if hace is not None and hace < 10 * 60:
            return {"ok": False, "accion": "backoff", "procesoId": pid}
    kb.append_chat(
        "sistema",
        "Turno autónomo: "
        + nombre
        + ". Arma el flujo, deja pendientes de .sql y el vigilante sigue al siguiente (no espera el script).",
        pid,
        "documentar",
    )
    bot_res = lanzar_bot(DOCUMENTAR_ID, "documentar-auto")
    vig["ultimoTurnoEn"] = _now()
    vig["ultimoProcesoId"] = pid
    vig["ultimoError"] = "" if bot_res.get("ok") else str(bot_res.get("error") or "error")
    if bot_res.get("ok"):
        vig["fallosSeguidos"] = 0
    else:
        vig["fallosSeguidos"] = fallos + 1
    kb.save_vigilante(vig)
    if not bot_res.get("ok"):
        if vig["fallosSeguidos"] <= 2:
            kb.append_chat(
                "sistema",
                "El agente de Documentar no pudo arrancar ("
                + str(bot_res.get("error") or "error")
                + "). Reintentará el mismo valle.",
                pid,
                "documentar",
            )
        return {"ok": False, "accion": "lanzado_error", "procesoId": pid, "bot": bot_res}

    final = _esperar_bot()
    vig["ultimoTurnoEn"] = _now()
    vig["ultimoError"] = final.get("error") or ""
    if (final.get("estado") or "") == "listo":
        vig["fallosSeguidos"] = 0
        kb.marcar_flujo_pasado(pid)
        kb.append_chat(
            "sistema",
            "Pasada de "
            + nombre
            + " cerrada. Siguiente proceso de la ruta (los .sql quedan en pendientes).",
            pid,
            "documentar",
        )
        kb.save_vigilante(vig)
        return {
            "ok": True,
            "accion": "pasado",
            "procesoId": pid,
            "bot": bot_res,
            "final": "listo",
        }
    vig["fallosSeguidos"] = fallos + 1
    kb.save_vigilante(vig)
    return {
        "ok": False,
        "accion": "turno_error",
        "procesoId": pid,
        "final": final.get("estado"),
    }


def _pedir_nuevos_modulos(vig: dict) -> dict:
    estado = kb.ruta_resumen()
    hace = _segundos_desde(vig.get("solicitoModulosEn"))
    if hace is not None and hace < 6 * 3600:
        vig["ultimoError"] = ""
        vig["ultimoProcesoId"] = None
        kb.save_vigilante(vig)
        return {"ok": True, "accion": "ruta_cerrada_espera"}
    hechos = ", ".join(p.get("nombre") or p.get("procesoId") for p in estado.get("hechos") or []) or "—"
    kb.append_chat(
        "agente",
        "Ya pasé por la ruta administrativa (flujo + lista de pendientes en cada uno):\n"
        + hechos
        + ".\n\nTodavía hay mucho por documentar. Indique los siguientes módulos, en orden "
        "(p. ej. CxP, tesorería/bancos, inventario, nómina u otros que vea en el menú) "
        "y los agrego a la ruta. No invento procesos que no existan en Qrystalos2.",
        "",
        "documentar",
    )
    vig["solicitoModulosEn"] = _now()
    vig["ultimoTurnoEn"] = _now()
    vig["ultimoProcesoId"] = None
    vig["ultimoError"] = ""
    kb.save_vigilante(vig)
    return {"ok": True, "accion": "pedir_modulos"}


def _loop(delay_inicial: int) -> None:
    time.sleep(max(5, delay_inicial))
    while True:
        try:
            res = tick()
            accion = (res or {}).get("accion")
            if accion == "pasado":
                time.sleep(12)
                continue
            if accion == "ya_trabajando":
                time.sleep(15)
                continue
            if accion in ("pausado", "sin_clave", "lanzado_error"):
                time.sleep(60)
                continue
            time.sleep(120)
        except Exception:
            try:
                import traceback

                vig = kb.load_vigilante()
                vig["ultimoError"] = traceback.format_exc()[-800:]
                kb.save_vigilante(vig)
            except Exception:
                pass
            time.sleep(60)


def start_background(delay_inicial: int = 20) -> None:
    global _started
    if _started:
        return
    _started = True
    kb._ensure_canal("documentar")
    vig = kb.load_vigilante()
    vig.setdefault("activo", True)
    vig.setdefault("intervaloMin", 12)
    kb.save_vigilante(vig)
    threading.Thread(target=_loop, args=(delay_inicial,), daemon=True, name="doc-vigilante").start()
    print("Documentar vigilante: pasa proceso a proceso (no espera .sql)", flush=True)
