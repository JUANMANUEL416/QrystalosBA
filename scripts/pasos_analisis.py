# -*- coding: utf-8 -*-
"""Checkpoints del análisis: ubicar → analizar → material → mockup → dictamen.

Cada paso queda asentado. El orquestador solo lanza lo pendiente.
"""
from __future__ import annotations

import os
from datetime import datetime
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PASOS_ORDEN = ("ubicar", "analizar", "material", "mockup", "dictamen")

MOTIVO_A_PASO = {
    "ubicar-req": "ubicar",
    "analizar-req": "analizar",
    "criterios": "analizar",
    "activar": "analizar",
    "material": "material",
    "mockup-ventana": "mockup",
}

PASO_A_MOTIVO = {
    "ubicar": "ubicar-req",
    "analizar": "analizar-req",
    "material": "material",
    "mockup": "mockup-ventana",
    "dictamen": "",  # lo genera la oficina, no un turno de modelo
}

NOMBRES = {
    "ubicar": "Ubicar flujo",
    "analizar": "Analizar y plantear",
    "material": "Plan / material",
    "mockup": "Mockup",
    "dictamen": "Dictamen",
}


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _caso_dir(id_caso: str) -> str:
    return os.path.join(ROOT, "activo", id_caso)


def _estado_path(id_caso: str) -> str:
    return os.path.join(_caso_dir(id_caso), "estado.json")


def _read_json(path: str, default: Any = None) -> Any:
    import json

    if default is None:
        default = {}
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return default


def _write_json(path: str, data: dict) -> None:
    import json

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


def fila_vacia(estado: str = "pendiente") -> dict:
    return {"estado": estado, "en": "", "error": "", "evidencia": ""}


def esquema_vacio() -> dict:
    return {pid: fila_vacia("pendiente") for pid in PASOS_ORDEN}


def normalizar(pasos: Any) -> dict:
    base = esquema_vacio()
    if not isinstance(pasos, dict):
        return base
    for pid in PASOS_ORDEN:
        crudo = pasos.get(pid)
        if not isinstance(crudo, dict):
            continue
        est = str(crudo.get("estado") or "pendiente").strip().lower()
        if est not in ("pendiente", "en_curso", "listo", "error"):
            est = "pendiente"
        base[pid] = {
            "estado": est,
            "en": str(crudo.get("en") or ""),
            "error": str(crudo.get("error") or ""),
            "evidencia": str(crudo.get("evidencia") or ""),
        }
    return base


def leer(id_caso: str) -> dict:
    est = _read_json(_estado_path(id_caso), {})
    if not isinstance(est, dict):
        est = {}
    return normalizar(est.get("pasos"))


def guardar(id_caso: str, pasos: dict) -> dict:
    path = _estado_path(id_caso)
    est = _read_json(path, {})
    if not isinstance(est, dict):
        est = {}
    limpios = normalizar(pasos)
    est["pasos"] = limpios
    piezas = {
        "plan": limpios["material"]["estado"] == "listo",
        "mockup": limpios["mockup"]["estado"] == "listo",
        "dictamen": limpios["dictamen"]["estado"] == "listo",
    }
    est["analisisPiezas"] = piezas
    completo = all(limpios[p]["estado"] == "listo" for p in PASOS_ORDEN)
    est["analisisCompletado"] = completo
    if completo and not est.get("analisisCompletadoEn"):
        est["analisisCompletadoEn"] = _now()
    if not completo:
        est.pop("analisisCompletadoEn", None)
    _write_json(path, est)
    return limpios


def paso_de_motivo(motivo: str) -> str:
    return MOTIVO_A_PASO.get((motivo or "").strip(), "")


def motivo_de_paso(paso: str) -> str:
    return PASO_A_MOTIVO.get(paso, "")


def esta_listo(id_caso: str, paso: str) -> bool:
    return leer(id_caso).get(paso, {}).get("estado") == "listo"


def marcar(id_caso: str, paso: str, estado: str, error: str = "", evidencia: str = "") -> dict:
    if paso not in PASOS_ORDEN:
        return leer(id_caso)
    pasos = leer(id_caso)
    fila = dict(pasos.get(paso) or fila_vacia())
    fila["estado"] = estado
    fila["en"] = _now()
    if error:
        fila["error"] = error
    elif estado == "listo":
        fila["error"] = ""
    if evidencia:
        fila["evidencia"] = evidencia
    pasos[paso] = fila
    return guardar(id_caso, pasos)


def invalidar_desde(id_caso: str, paso: str) -> dict:
    """Deja pendiente este paso y todos los posteriores."""
    if paso not in PASOS_ORDEN:
        return leer(id_caso)
    pasos = leer(id_caso)
    i = PASOS_ORDEN.index(paso)
    for pid in PASOS_ORDEN[i:]:
        pasos[pid] = fila_vacia("pendiente")
    return guardar(id_caso, pasos)


def reiniciar(id_caso: str) -> dict:
    return guardar(id_caso, esquema_vacio())


def _evidencia_ubicar(id_caso: str) -> str:
    sol = _read_json(os.path.join(_caso_dir(id_caso), "solicitud.json"), {})
    contenido = sol.get("contenido") if isinstance(sol, dict) else {}
    ubi = (contenido or {}).get("ubicacion") if isinstance(contenido, dict) else {}
    if not isinstance(ubi, dict):
        return ""
    if str(ubi.get("estado") or "") == "listo" and ubi.get("procesoId"):
        return "{proc} → {flujo}".format(
            proc=ubi.get("procesoId") or "",
            flujo=ubi.get("flujo") or "",
        )
    return ""


def _evidencia_analizar(id_caso: str) -> str:
    sol = _read_json(os.path.join(_caso_dir(id_caso), "solicitud.json"), {})
    if not isinstance(sol, dict):
        return ""
    try:
        import planteamiento_req

        if planteamiento_req.evaluar(sol, modo="analisis").get("ok"):
            return "planteamiento listo"
    except Exception:
        contenido = sol.get("contenido") if isinstance(sol.get("contenido"), dict) else {}
        texto = " ".join(
            str(contenido.get(k) or "")
            for k in ("analisis", "recomendacion", "cambioPropuestoSimple")
        ).strip()
        if len(texto) >= 120:
            return "analisis escrito"
    return ""


def _evidencia_material(id_caso: str) -> str:
    path = os.path.join(_caso_dir(id_caso), "material", "documento.md")
    return "material/documento.md" if os.path.isfile(path) else ""


def _evidencia_mockup(id_caso: str) -> str:
    mockups = os.path.join(_caso_dir(id_caso), "mockups")
    for nombre in ("mockup-ventana-flexible.html", "mockup-ux-pantalla.html"):
        if os.path.isfile(os.path.join(mockups, nombre)):
            return f"mockups/{nombre}"
    return ""


def _evidencia_dictamen(id_caso: str) -> str:
    path = os.path.join(ROOT, "dictamenes", f"{id_caso}.html")
    return f"dictamenes/{id_caso}.html" if os.path.isfile(path) else ""


_EVIDENCIA = {
    "ubicar": _evidencia_ubicar,
    "analizar": _evidencia_analizar,
    "material": _evidencia_material,
    "mockup": _evidencia_mockup,
    "dictamen": _evidencia_dictamen,
}


def sincronizar_evidencia(id_caso: str) -> dict:
    """Marca listo lo que ya está en disco; no baja un paso listo a pendiente."""
    pasos = leer(id_caso)
    cambio = False
    for pid in PASOS_ORDEN:
        ev = _EVIDENCIA[pid](id_caso)
        if not ev:
            continue
        if pasos[pid]["estado"] != "listo":
            pasos[pid] = {
                "estado": "listo",
                "en": pasos[pid].get("en") or _now(),
                "error": "",
                "evidencia": ev,
            }
            cambio = True
        elif not pasos[pid].get("evidencia"):
            pasos[pid]["evidencia"] = ev
            cambio = True
    return guardar(id_caso, pasos) if cambio else pasos


def siguiente_pendiente(id_caso: str) -> str:
    """Primer paso no listo, en orden. Vacío si todos listos."""
    sincronizar_evidencia(id_caso)
    pasos = leer(id_caso)
    for pid in PASOS_ORDEN:
        if pasos[pid]["estado"] != "listo":
            return pid
    return ""


def motivo_siguiente(id_caso: str) -> str:
    """Motivo Cursor del siguiente pendiente, o vacío si solo falta dictamen/armar."""
    pid = siguiente_pendiente(id_caso)
    if not pid:
        return ""
    return motivo_de_paso(pid)


def resumen(id_caso: str) -> dict:
    pasos = sincronizar_evidencia(id_caso)
    return {
        "pasos": pasos,
        "orden": list(PASOS_ORDEN),
        "nombres": dict(NOMBRES),
        "siguiente": siguiente_pendiente(id_caso),
        "completo": all(pasos[p]["estado"] == "listo" for p in PASOS_ORDEN),
        "linea": " · ".join(
            f"{NOMBRES[p]} {'✓' if pasos[p]['estado'] == 'listo' else ('…' if pasos[p]['estado'] == 'en_curso' else '·')}"
            for p in PASOS_ORDEN
        ),
    }
