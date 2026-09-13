# -*- coding: utf-8 -*-
"""Solicitudes de requerimiento para comité de desarrollo (BA / funcional)."""
from __future__ import annotations

import html
import json
import os
import re
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
SOLICITUDES = os.path.join(ROOT, "solicitudes")
PLANTILLA = os.path.join(ROOT, "plantillas", "solicitud-req.html")
DICTAMENES = os.path.join(ROOT, "dictamenes")
INDICE = os.path.join(ROOT, "conocimiento", "INDICE.json")

import sys

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import conocimiento as kb  # noqa: E402


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _read_json(path, default):
    if not os.path.isfile(path):
        return default
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _write_json(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def _esc(s) -> str:
    return html.escape(str(s or ""), quote=False)


def _nl(s) -> str:
    return _esc(s).replace("\n", "<br>\n") if s else "—"


def _as_map(val):
    return val if isinstance(val, dict) else {}


def index_path() -> str:
    return os.path.join(SOLICITUDES, "index.json")


def caso_dir(id_sr: str) -> str:
    return os.path.join(SOLICITUDES, id_sr)


def load_index() -> dict:
    os.makedirs(SOLICITUDES, exist_ok=True)
    return _read_json(index_path(), {"actualizado": "", "items": []})


def save_index(data: dict) -> None:
    data["actualizado"] = _now()
    _write_json(index_path(), data)


def nuevo_id() -> str:
    pref = datetime.now().strftime("SR%Y%m%d")
    idx = load_index()
    n = 1
    existentes = {i.get("id") for i in idx.get("items") or []}
    while f"{pref}-{n:03d}" in existentes:
        n += 1
    return f"{pref}-{n:03d}"


def load(id_sr: str) -> dict:
    path = os.path.join(caso_dir(id_sr), "solicitud.json")
    return _read_json(path, {})


def load_chat(id_sr: str) -> dict:
    return _read_json(os.path.join(caso_dir(id_sr), "chat.json"), {"mensajes": []})


def save_chat(id_sr: str, chat: dict) -> None:
    _write_json(os.path.join(caso_dir(id_sr), "chat.json"), chat)


def append_chat(id_sr: str, autor: str, texto: str) -> dict:
    chat = load_chat(id_sr)
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto,
        "fecha": _now(),
    }
    chat.setdefault("mensajes", []).append(msg)
    save_chat(id_sr, chat)
    return msg


def empty_solicitud(id_sr: str) -> dict:
    return {
        "tipo": "solicitud-req",
        "id": id_sr,
        "creadoEn": _now(),
        "actualizadoEn": _now(),
        "estado": "borrador",
        "analista": "",
        "proyecto": "",
        "modulo": "",
        "procesoId": "",
        "prioridad": "Media",
        "titulo": "",
        "necesidad": "",
        "hoy": "",
        "propuesta": "",
        "justificacion": "",
        "analisis": "",
        "alcance": "",
        "restricciones": "",
        "criterios": "",
        "recomendacion": "",
        "siguiente": "",
        "aval": {
            "aplica": False,
            "idReq": "",
            "idCaso": "",
            "titulo": "",
            "notas": "",
        },
        "documento": None,
    }


def guardar(payload: dict) -> dict:
    data = payload if isinstance(payload, dict) else {}
    id_sr = (data.get("id") or "").strip() or nuevo_id()
    dest = caso_dir(id_sr)
    os.makedirs(dest, exist_ok=True)
    prev = load(id_sr) or empty_solicitud(id_sr)
    merged = {**empty_solicitud(id_sr), **prev, **data}
    merged["id"] = id_sr
    merged["tipo"] = "solicitud-req"
    merged["actualizadoEn"] = _now()
    if not merged.get("creadoEn"):
        merged["creadoEn"] = _now()
    aval = _as_map(merged.get("aval"))
    merged["aval"] = {
        "aplica": bool(aval.get("aplica")),
        "idReq": (aval.get("idReq") or "").strip(),
        "idCaso": (aval.get("idCaso") or "").strip(),
        "titulo": (aval.get("titulo") or "").strip(),
        "notas": (aval.get("notas") or "").strip(),
    }
    _write_json(os.path.join(dest, "solicitud.json"), merged)
    if not os.path.isfile(os.path.join(dest, "chat.json")):
        save_chat(id_sr, {"mensajes": []})
    idx = load_index()
    items = [i for i in (idx.get("items") or []) if i.get("id") != id_sr]
    items.insert(0, {
        "id": id_sr,
        "titulo": merged.get("titulo") or "(sin título)",
        "proyecto": merged.get("proyecto") or "",
        "procesoId": merged.get("procesoId") or "",
        "estado": merged.get("estado") or "borrador",
        "actualizadoEn": merged["actualizadoEn"],
        "avalReq": merged["aval"].get("idReq") or "",
    })
    idx["items"] = items
    save_index(idx)
    return merged


def listar() -> list:
    return load_index().get("items") or []


def _textos(sol: dict) -> str:
    return "\n".join(
        str(sol.get(k) or "")
        for k in ("titulo", "necesidad", "hoy", "propuesta", "justificacion", "analisis", "alcance")
    )


def contrastar_kb(sol: dict) -> dict:
    """Cruza la necesidad con INDICE + proceso/sps. No inventa fichas."""
    proceso_id = (sol.get("procesoId") or "").strip()
    indice = _read_json(INDICE, {})
    procesos = indice.get("procesos") or []
    if not proceso_id:
        blob = _textos(sol).lower()
        scored = []
        for p in procesos:
            hay = " ".join(str(p.get(k) or "") for k in ("id", "nombre", "modulo", "resumen")).lower()
            score = sum(1 for w in re.findall(r"[a-záéíóúñ]{4,}", blob) if w in hay)
            scored.append((score, p))
        scored.sort(key=lambda x: -x[0])
        if scored and scored[0][0] > 0:
            proceso_id = scored[0][1].get("id") or ""
    proceso = kb.load_proceso(proceso_id) if proceso_id else None
    sps_cat = kb.load_sps(proceso_id) if proceso_id else {"sps": []}
    texto = _textos(sol).lower()
    gates = []
    if proceso:
        for capa in proceso.get("capas") or []:
            for gate in kb.controles_de(capa):
                blob = f"{gate.get('id')} {gate.get('nombre')} {gate.get('explicacion')}".lower()
                if any(w in blob for w in re.findall(r"[a-záéíóúñ]{5,}", texto)[:20]) or not texto.strip():
                    gates.append({
                        "capa": capa.get("nombre") or capa.get("id"),
                        "id": gate.get("id"),
                        "nombre": gate.get("nombre"),
                        "explicacion": gate.get("explicacion") or "",
                        "sps": gate.get("sps") or [],
                    })
        if not gates:
            for capa in proceso.get("capas") or []:
                for gate in kb.controles_de(capa)[:3]:
                    gates.append({
                        "capa": capa.get("nombre") or capa.get("id"),
                        "id": gate.get("id"),
                        "nombre": gate.get("nombre"),
                        "explicacion": gate.get("explicacion") or "",
                        "sps": gate.get("sps") or [],
                    })
    metodos = []
    for sp in (sps_cat.get("sps") or [])[:12]:
        nombre = sp.get("nombre") or sp.get("sp") or ""
        for m in (sp.get("metodos") or [])[:8]:
            mid = m.get("id") or m.get("metodo") or ""
            hace = str(m.get("hace") or "").lower()
            if mid and (mid.lower() in texto or any(w in hace for w in ("colilla", "pedir", "inventario", "imprim") if w in texto)):
                metodos.append({"sp": nombre, "metodo": mid, "estado": m.get("estado") or "", "hace": m.get("hace") or ""})
    return {
        "procesoId": proceso_id,
        "procesoNombre": (proceso or {}).get("nombre") or proceso_id or "(proceso no ubicado)",
        "procesoEstado": (proceso or {}).get("estado") or "",
        "resumen": (proceso or {}).get("resumen") or "No hay proceso en conocimiento/ para este módulo. Hay que crear esqueleto en Documentar.",
        "gates": gates[:6],
        "metodos": metodos[:8],
        "existe": bool(proceso),
    }


def _html_contraste(kb_info: dict) -> str:
    if not kb_info.get("existe"):
        return (
            f'<p>No hay ficha de proceso <code>{_esc(kb_info.get("procesoId") or "—")}</code> '
            "en la base. El comité debe saber que el análisis es de necesidad, no de SP leídos hoy. "
            "En Documentar se crea el esqueleto cuando se apruebe el trabajo.</p>"
        )
    parts = [
        f"<p><strong>Proceso:</strong> {_esc(kb_info.get('procesoNombre'))} "
        f"(<code>{_esc(kb_info.get('procesoId'))}</code>, estado {_esc(kb_info.get('procesoEstado') or '—')}).</p>",
        f'<div class="content-block">{_nl(kb_info.get("resumen"))}</div>',
    ]
    if kb_info.get("gates"):
        rows = "".join(
            f"<tr><td>{_esc(g.get('capa'))}</td><td>{_esc(g.get('nombre') or g.get('id'))}</td>"
            f"<td>{_esc(g.get('explicacion'))}</td></tr>"
            for g in kb_info["gates"]
        )
        parts.append(
            "<h3>Controles relacionados</h3>"
            "<table><thead><tr><th>Capa</th><th>Control</th><th>Explicación</th></tr></thead>"
            f"<tbody>{rows}</tbody></table>"
        )
    if kb_info.get("metodos"):
        rows = "".join(
            f"<tr><td><code>{_esc(m.get('sp'))}</code></td><td>{_esc(m.get('metodo'))}</td>"
            f"<td>{_esc(m.get('estado'))}</td><td>{_esc((m.get('hace') or '')[:220])}</td></tr>"
            for m in kb_info["metodos"]
        )
        parts.append(
            "<h3>SP / METODO del alcance (solo fichas existentes)</h3>"
            "<table><thead><tr><th>SP</th><th>METODO</th><th>Estado</th><th>Hace</th></tr></thead>"
            f"<tbody>{rows}</tbody></table>"
        )
    else:
        parts.append(
            "<p>Ningún METODO del catálogo encaja todavía con el texto. "
            "No se listó el módulo entero. El Chat pedirá el .sql si el comité aprueba y hay que dictaminar.</p>"
        )
    return "\n".join(parts)


def _aval_detalle(sol: dict) -> str:
    aval = _as_map(sol.get("aval"))
    if not aval.get("aplica"):
        return "No se asoció aval técnico. Esta solicitud nace de necesidad de negocio / funcional. Si el cliente pide aval, se puede vincular el REQ y su dictamen."
    partes = []
    if aval.get("idReq"):
        partes.append(f"REQ {aval.get('idReq')}")
    if aval.get("idCaso"):
        partes.append(f"caso {aval.get('idCaso')}")
        partes.append(f"dictamen: dictamenes/{aval.get('idCaso')}.html")
    if aval.get("titulo"):
        partes.append(aval.get("titulo"))
    if aval.get("notas"):
        partes.append(aval.get("notas"))
    return " · ".join(p for p in partes if p) or "Aval marcado, sin ID todavía."


def generar_documento(id_sr: str) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("No hay solicitud. Guárdela primero.")
    kb_info = contrastar_kb(sol)
    if kb_info.get("procesoId") and not sol.get("procesoId"):
        sol["procesoId"] = kb_info["procesoId"]
        guardar(sol)
        sol = load(id_sr)
    plantilla = open(PLANTILLA, encoding="utf-8").read()
    aval = _as_map(sol.get("aval"))
    valores = {
        "TITULO": _esc(sol.get("titulo") or "Solicitud de requerimiento"),
        "ID": _esc(id_sr),
        "PROYECTO": _esc(sol.get("proyecto") or "—"),
        "MODULO": _esc(sol.get("modulo") or kb_info.get("procesoNombre") or "—"),
        "PRIORIDAD": _esc(sol.get("prioridad") or "Media"),
        "FECHA": _esc((sol.get("actualizadoEn") or _now())[:10]),
        "ESTADO": _esc(sol.get("estado") or "Para comité"),
        "ANALISTA": _esc(sol.get("analista") or "Business Analyst"),
        "AVAL_RESUMEN": _esc(
            f"REQ {aval.get('idReq')}" if aval.get("aplica") and aval.get("idReq") else ("Sí" if aval.get("aplica") else "No")
        ),
        "NECESIDAD": _nl(sol.get("necesidad")),
        "HOY": _nl(sol.get("hoy") or sol.get("necesidad")),
        "PROPUESTA": _nl(sol.get("propuesta")),
        "JUSTIFICACION": _nl(sol.get("justificacion")),
        "PROCESO_ID": _esc(kb_info.get("procesoId") or sol.get("procesoId") or "—"),
        "CONTRASTE_KB": _html_contraste(kb_info),
        "AVAL_DETALLE": _nl(_aval_detalle(sol)),
        "ANALISIS": _nl(sol.get("analisis") or "Pendiente de análisis del agente contra conocimiento/."),
        "ALCANCE": _nl(sol.get("alcance")),
        "RESTRICCIONES": _nl(sol.get("restricciones")),
        "CRITERIOS": _nl(sol.get("criterios")),
        "RECOMENDACION": _nl(
            sol.get("recomendacion")
            or "Incluir en el plan de trabajo si el comité valida la necesidad. El dictamen técnico de desarrollo se emite después, por Analista de negocio, cuando exista REQ/aval."
        ),
        "SIGUIENTE": _nl(
            sol.get("siguiente")
            or "1) Comité aprueba o pide ajuste. 2) Si hay aval, asociarlo aquí. 3) Al entrar a desarrollo, abrir Analista de negocio con el REQ y dictaminar con sps.json."
        ),
    }
    html_doc = plantilla
    for k, v in valores.items():
        html_doc = html_doc.replace("{{" + k + "}}", v)
    dest_dir = caso_dir(id_sr)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, "documento.html")
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write(html_doc)
    os.makedirs(DICTAMENES, exist_ok=True)
    copia = os.path.join(DICTAMENES, f"{id_sr}.html")
    with open(copia, "w", encoding="utf-8") as fh:
        fh.write(html_doc)
    sol["estado"] = sol.get("estado") if sol.get("estado") not in ("borrador", "") else "para_comite"
    sol["documento"] = {
        "nombre": "documento.html",
        "ruta": f"solicitudes/{id_sr}/documento.html",
        "url": f"/api/solicitar/{id_sr}/documento",
        "dictamenCopia": f"dictamenes/{id_sr}.html",
        "generadoEn": _now(),
    }
    guardar(sol)
    return {"ok": True, "id": id_sr, "documento": sol["documento"], "kb": kb_info}


def instruccion_agente(sol: dict) -> str:
    id_sr = sol.get("id") or ""
    return f"""# Solicitud de requerimiento — INSTRUCCIÓN PARA EL AGENTE

Lea del disco:
1. `solicitudes/{id_sr}/solicitud.json`
2. `solicitudes/{id_sr}/chat.json`
3. `conocimiento/INDICE.json` y, si hay procesoId, `conocimiento/{{proceso}}/proceso.json` + `sps.json`
4. Qrystalos2 y documentación viva solo si la ficha no cubre la necesidad

Usted es el analista BA/funcional. El entregable es un **documento para el comité de desarrollo** (incluir en el plan), no un dictamen de implementación para el desarrollador.

Reglas:
- Contraste la necesidad con la base de conocimiento. No invente SP ni columnas.
- Liste SOLO los SP/METODO de este cambio (no el catálogo del módulo).
- Escriba en solicitud.json: analisis, alcance, restricciones, criterios, recomendacion, siguiente; procesoId si lo ubica.
- Responda en chat.json (autor: agente).
- NO genere el dictamen técnico de Analista de negocio.
- Si hay aval.aplica, cite el REQ/caso y no lo ignore.
- Si falta un dato que bloquee la recomendación al comité, PIDA y deténgase.

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
"""


def preparar_analisis(id_sr: str) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Guarde la solicitud antes de analizar.")
    dest = caso_dir(id_sr)
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, "INSTRUCCION-AGENTE.md"), "w", encoding="utf-8") as fh:
        fh.write(instruccion_agente(sol))
    kb_info = contrastar_kb(sol)
    if kb_info.get("procesoId") and not sol.get("procesoId"):
        sol["procesoId"] = kb_info["procesoId"]
        guardar(sol)
    append_chat(
        id_sr,
        "sistema",
        "El agente está contrastando la necesidad con conocimiento/ para armar el documento de comité.",
    )
    return {"ok": True, "id": id_sr, "solicitud": load(id_sr), "kb": kb_info}
