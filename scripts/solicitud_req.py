# -*- coding: utf-8 -*-
"""Solicitudes de requerimiento para comité de desarrollo (BA / funcional)."""
from __future__ import annotations

import html
import json
import os
import re
import shutil
import subprocess
import tempfile
import threading
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
SOLICITUDES = os.path.join(ROOT, "solicitudes")
RUTAS_CFG = os.path.join(ROOT, "config", "rutas.json")
PLANTILLA = os.path.join(ROOT, "plantillas", "solicitud-req.html")
DICTAMENES = os.path.join(ROOT, "dictamenes")
INDICE = os.path.join(ROOT, "conocimiento", "INDICE.json")

import sys

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import conocimiento as kb  # noqa: E402
import diagrama_flujo as diagflujo  # noqa: E402
import correo as mailer  # noqa: E402


_CARPETA_LOCK = threading.Lock()


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def servidor_puede_dialogo_carpeta() -> dict:
    """Indica si el proceso del servidor puede mostrar el selector de carpetas de Windows."""
    if os.name != "nt":
        return {"disponible": True, "motivo": ""}
    user = (os.environ.get("USERNAME") or "").strip().upper()
    if user in ("SYSTEM", "LOCAL SERVICE", "NETWORK SERVICE"):
        return {
            "disponible": False,
            "motivo": (
                "El servidor corre como servicio Windows y no puede abrir ventanas. "
                "Escriba la ruta en el cuadro, use Escritorio / Carpeta del caso, "
                "o ejecute servir-app.bat (ventana visible) en lugar del servicio."
            ),
        }
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        proc_session = ctypes.c_uint()
        if kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(proc_session)):
            active = kernel32.WTSGetActiveConsoleSessionId()
            if active != 0xFFFFFFFF and proc_session.value != active:
                return {
                    "disponible": False,
                    "motivo": (
                        "El servidor no está en su sesión de escritorio. "
                        "Pegue la ruta (por ejemplo su Escritorio) o ejecute servir-app.bat."
                    ),
                }
    except Exception:
        pass
    return {"disponible": True, "motivo": ""}


def _load_rutas_cfg() -> dict:
    try:
        with open(RUTAS_CFG, encoding="utf-8") as fh:
            data = json.load(fh) or {}
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def carpeta_export_default() -> str:
    """Carpeta por defecto al guardar PDF/PNG de una solicitud (subcarpeta = ID)."""
    raw = (_load_rutas_cfg().get("carpetaExportSolicitudes") or "").strip()
    if raw:
        dest = os.path.normpath(raw)
        try:
            os.makedirs(dest, exist_ok=True)
        except OSError:
            pass
        return dest
    home = os.path.expanduser("~")
    descargas = os.path.join(home, "Downloads")
    if not os.path.isdir(descargas):
        alt = os.path.join(home, "Descargas")
        descargas = alt if os.path.isdir(alt) else home
    dest = os.path.normpath(os.path.join(descargas, "sdsd"))
    try:
        os.makedirs(dest, exist_ok=True)
    except OSError:
        pass
    return dest


def rutas_carpeta_sugeridas(id_sr: str = "") -> dict:
    """Rutas absolutas útiles para pegar o elegir con un clic."""
    home = os.path.expanduser("~")
    escritorio = os.path.join(home, "Desktop")
    if not os.path.isdir(escritorio):
        alt = os.path.join(home, "Escritorio")
        escritorio = alt if os.path.isdir(alt) else home
    out = {
        "escritorio": os.path.normpath(escritorio),
        "home": os.path.normpath(home),
        "exportDefault": carpeta_export_default(),
    }
    sid = (id_sr or "").strip()
    if sid:
        plat = os.path.join(caso_dir(sid), "plataforma")
        try:
            os.makedirs(plat, exist_ok=True)
        except OSError:
            pass
        out["plataformaCaso"] = os.path.normpath(plat)
        out["escritorioCaso"] = os.path.normpath(os.path.join(escritorio, sid))
        descargas = os.path.join(home, "Downloads")
        if not os.path.isdir(descargas):
            alt = os.path.join(home, "Descargas")
            descargas = alt if os.path.isdir(alt) else home
        out["descargasCaso"] = os.path.normpath(os.path.join(descargas, sid))
        docs = os.path.join(home, "Documents")
        if not os.path.isdir(docs):
            alt = os.path.join(home, "Documentos")
            docs = alt if os.path.isdir(alt) else home
        out["documentosCaso"] = os.path.normpath(os.path.join(docs, sid))
    return out


def elegir_carpeta(titulo: str = "Carpeta para los PDF y la imagen del flujo", inicial: str = "") -> str:
    """Abre el diálogo de Windows para elegir carpeta. Vacío si cancela."""
    inicial = (inicial or "").strip() or os.path.expanduser("~")
    dialogo = servidor_puede_dialogo_carpeta()
    if not dialogo.get("disponible"):
        return ""
    with _CARPETA_LOCK:
        # Tkinter desde hilos HTTP suele fallar; PowerShell STA es más fiable en ventana interactiva.
        safe_t = titulo.replace("'", " ")
        safe_i = inicial.replace("'", "")
        script = (
            "Add-Type -AssemblyName System.Windows.Forms; "
            "$f = New-Object System.Windows.Forms.FolderBrowserDialog; "
            f"$f.Description = '{safe_t}'; "
            "$f.ShowNewFolderButton = $true; "
            f"if (Test-Path -LiteralPath '{safe_i}') {{ $f.SelectedPath = '{safe_i}' }}; "
            "if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $f.SelectedPath }"
        )
        try:
            r = subprocess.run(
                ["powershell", "-NoProfile", "-STA", "-Command", script],
                capture_output=True,
                text=True,
                timeout=120,
                creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0) or 0,
            )
            lines = [ln.strip() for ln in (r.stdout or "").splitlines() if ln.strip()]
            path = lines[-1] if lines else ""
            if path and os.path.isdir(path):
                return os.path.normpath(path)
        except Exception:
            pass
    return ""


def abrir_en_explorador(path: str) -> None:
    if not path:
        return
    try:
        os.startfile(path)  # type: ignore[attr-defined]
    except Exception:
        pass


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
        "estado": "abierto",
        "cerradoEn": None,
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
        "cambioPropuestoSql": "",
        "normativa": "",
        "analisisLanzado": False,
        "archivos": [],
        "mockups": [],
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


def _esta_cerrada(sol: dict) -> bool:
    return str((sol or {}).get("estado") or "").lower() == "cerrado"


def _persistir(merged: dict) -> dict:
    id_sr = merged["id"]
    dest = caso_dir(id_sr)
    os.makedirs(dest, exist_ok=True)
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
        "estado": merged.get("estado") or "abierto",
        "cerradoEn": merged.get("cerradoEn") or "",
        "cerrado": _esta_cerrada(merged),
        "tieneDocumento": bool((merged.get("documento") or {}).get("ruta"))
            or os.path.isfile(os.path.join(dest, "documento.html")),
        "actualizadoEn": merged.get("actualizadoEn") or _now(),
        "avalReq": (_as_map(merged.get("aval")).get("idReq") or ""),
    })
    idx["items"] = items
    save_index(idx)
    return merged


def guardar(payload: dict) -> dict:
    data = payload if isinstance(payload, dict) else {}
    id_sr = (data.get("id") or "").strip() or nuevo_id()
    dest = caso_dir(id_sr)
    os.makedirs(dest, exist_ok=True)
    prev = load(id_sr) or empty_solicitud(id_sr)
    if _esta_cerrada(prev):
        raise ValueError("Esta solicitud está cerrada. No se edita; ábrala solo si sigue abierta.")
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
    merged["titulo"] = _titulo_corto(merged)
    if not merged.get("estado") or merged.get("estado") in ("borrador",):
        merged["estado"] = "abierto"
    return _persistir(merged)


def _archivo_export_en_disco(id_sr: str, sol: dict, item: dict) -> bool:
    """True si el PDF o la imagen de un Guardar anterior sigue en disco."""
    nombre = (item.get("nombre") or "").strip()
    if not nombre:
        return False
    candidatos = []
    carpeta = (_as_map(sol.get("plataforma")).get("carpeta") or "").strip()
    if carpeta:
        candidatos.append(os.path.join(carpeta, nombre))
    ruta = (item.get("ruta") or "").replace("\\", "/").strip()
    if ruta:
        if os.path.isabs(ruta):
            candidatos.append(ruta)
        else:
            candidatos.append(os.path.join(ROOT, *ruta.split("/")))
    candidatos.append(os.path.join(caso_dir(id_sr), "plataforma", nombre))
    return any(os.path.isfile(p) for p in candidatos)


def entregables_ya_guardados(id_sr: str) -> bool:
    """El coordinador ya pulsó Guardar y quedó al menos un entregable en disco."""
    sol = load(id_sr) or {}
    plat = _as_map(sol.get("plataforma"))
    if not plat.get("exportadoEn"):
        return False
    return any(_archivo_export_en_disco(id_sr, sol, a) for a in (plat.get("archivos") or []) if isinstance(a, dict))


def cerrar(id_sr: str, carpeta: str = "", opciones: dict | None = None) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Solicitud no encontrada")
    if _esta_cerrada(sol):
        sol["_reutilizado"] = True
        return sol
    reutilizado = entregables_ya_guardados(id_sr)
    avisos = [] if reutilizado else _preparar_entregables_cierre(id_sr, carpeta=carpeta, opciones=opciones)
    sol = load(id_sr) or sol
    sol["estado"] = "cerrado"
    sol["cerradoEn"] = _now()
    sol["actualizadoEn"] = _now()
    if avisos:
        plat = _as_map(sol.get("plataforma"))
        plat["avisos"] = list(plat.get("avisos") or []) + avisos
        sol["plataforma"] = plat
    guardada = _persistir(sol)
    guardada["_reutilizado"] = reutilizado
    return guardada


def reabrir(id_sr: str) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Solicitud no encontrada")
    sol["estado"] = "abierto"
    sol["cerradoEn"] = None
    sol["actualizadoEn"] = _now()
    return _persistir(sol)


def listar() -> list:
    items = []
    for i in load_index().get("items") or []:
        row = dict(i)
        sid = row.get("id") or ""
        row["cerrado"] = _esta_cerrada(row) or bool(row.get("cerrado"))
        dest = os.path.join(caso_dir(sid), "documento.html") if sid else ""
        row["tieneDocumento"] = bool(row.get("tieneDocumento")) or (bool(dest) and os.path.isfile(dest))
        items.append(row)
    return items


def _textos(sol: dict) -> str:
    return "\n".join(
        str(sol.get(k) or "")
        for k in ("titulo", "necesidad", "hoy", "propuesta", "justificacion", "analisis", "alcance")
    )


def _titulo_corto(sol: dict) -> str:
    """Título de comité: una línea, no el párrafo de la necesidad."""
    t = re.sub(r"\s+", " ", str(sol.get("titulo") or "").strip())
    nec = re.sub(r"\s+", " ", str(sol.get("necesidad") or "").strip())
    if t and t.lower() != nec.lower() and len(t) <= 90:
        return t
    fuente = nec or t
    if not fuente:
        return "Solicitud de requerimiento"
    m = re.match(r"^(.{12,88}?)(?:[.;:\n]|$)", fuente)
    corto = (m.group(1) if m else fuente[:88]).strip(" .")
    if len(corto) > 88:
        corto = corto[:87].rstrip() + "…"
    return corto or "Solicitud de requerimiento"


def _md_html(s: str) -> str:
    if not (s or "").strip():
        return "—"
    text = _esc(s)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text.replace("\n", "<br>\n")


def _seccion_opcional(n: int, titulo: str, cuerpo: str) -> str:
    if not (cuerpo or "").strip():
        return ""
    return (
        f'<section><h2>{n}. {_esc(titulo)}</h2>'
        f'<div class="content-block">{_md_html(cuerpo)}</div></section>'
    )


def analisis_lanzado(sol: dict) -> bool:
    if sol.get("analisisLanzado"):
        return True
    return bool((sol.get("analisis") or "").strip())


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


def _url_web_asset(rel: str) -> str:
    """Ruta web absoluta desde la raíz del servidor (funciona en /api/solicitar/.../documento)."""
    r = str(rel or "").strip().replace("\\", "/").lstrip("/")
    return f"/{r}" if r else ""


def _rutas_mockups(sol: dict, id_sr: str) -> list:
    rels = list(mailer.rutas_mockups_solicitud(sol))
    doc = _as_map(sol.get("documento"))
    raw = doc.get("mockups")
    if isinstance(raw, str) and raw.strip():
        r = raw.strip().replace("\\", "/").lstrip("/")
        if r not in rels:
            rels.append(r)
    elif isinstance(raw, list):
        for item in raw:
            r = str(item or "").strip().replace("\\", "/").lstrip("/")
            if r and r not in rels:
                rels.append(r)
    mock_dir = os.path.join(caso_dir(id_sr), "mockups")
    if os.path.isdir(mock_dir):
        for name in sorted(os.listdir(mock_dir)):
            if name.lower().endswith(".html"):
                r = f"solicitudes/{id_sr}/mockups/{name}"
                if r not in rels:
                    rels.append(r)

    aval_id = (_as_map(sol.get("aval")).get("idCaso") or "").strip()
    propios = [r for r in rels if f"solicitudes/{id_sr}/mockups/" in r.replace("\\", "/")]
    if aval_id:
        pref_aval = f"activo/{aval_id}/".replace("\\", "/")
        if propios:
            rels = [r for r in rels if pref_aval not in r.replace("\\", "/")]
        else:
            activo_sol = _read_json(os.path.join(ROOT, "activo", aval_id, "solicitud.json"), {})
            for r in mailer.rutas_mockups_solicitud(activo_sol):
                if r not in rels:
                    rels.append(r)

    def _orden_mockup(rel):
        n = os.path.basename(rel).lower()
        if "ventana" in n or "ux" in n or "dialog" in n:
            return (0, rel)
        if "sp" in n or "flujo-sp" in n:
            return (1, rel)
        return (2, rel)

    return sorted(rels, key=_orden_mockup)


def _resolve_diagrama_flujo(sol: dict) -> str:
    diag = sol.get("diagramaFlujo")
    if isinstance(diag, dict):
        rel = (diag.get("sidecar") or diag.get("ruta") or "").strip()
        if not rel and (diag.get("nombre") or "").strip():
            id_caso = (_as_map(sol.get("aval")).get("idCaso") or "").strip()
            if id_caso:
                rel = f"activo/{id_caso}/diagramas/{diag.get('nombre')}"
        return rel.replace("\\", "/").lstrip("/")
    if isinstance(diag, str) and diag.strip():
        return diag.strip().replace("\\", "/").lstrip("/")
    aval_id = (_as_map(sol.get("aval")).get("idCaso") or "").strip()
    if aval_id:
        for candidato in (
            f"dictamenes/{aval_id}-flujo.html",
            f"activo/{aval_id}/diagramas/flujo.html",
        ):
            if os.path.isfile(os.path.join(ROOT, *candidato.split("/"))):
                return candidato
    sid = (sol.get("id") or "").strip()
    if sid:
        local = f"solicitudes/{sid}/diagramas/flujo.html"
        if os.path.isfile(os.path.join(ROOT, *local.split("/"))):
            return local
    return ""


def _extraer_html_incrustable(abs_path: str) -> str:
    if not os.path.isfile(abs_path):
        return ""
    with open(abs_path, encoding="utf-8") as fh:
        texto = fh.read()
    estilos = re.findall(r"<style[^>]*>(.*?)</style>", texto, re.I | re.S)
    style_block = "".join(f"<style>{s}</style>" for s in estilos)
    m = re.search(r"<body[^>]*>(.*?)</body>", texto, re.I | re.S)
    cuerpo = m.group(1).strip() if m else texto.strip()
    return f"{style_block}{cuerpo}"


def _html_mockups(id_sr: str, sol: dict) -> str:
    rels = _rutas_mockups(sol, id_sr)
    if not rels:
        return (
            '<p class="aviso">No hay mockups declarados. Guarde HTML en '
            f'<code>solicitudes/{id_sr}/mockups/</code> y registre la ruta en '
            "<code>solicitud.json</code> (<code>documento.mockups</code>).</p>"
        )
    partes = []
    for rel in rels:
        nombre = os.path.basename(rel)
        titulo = "Mockup SP (METODO / secuencia)" if "sp" in nombre.lower() else "Mockup UX (pantallas)"
        abs_path = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.isfile(abs_path):
            partes.append(f'<p class="aviso">Archivo no encontrado: <code>{_esc(rel)}</code></p>')
            continue
        src = _url_web_asset(rel)
        partes.append(
            f'<div class="embed-block mockup-block">'
            f"<h3>{_esc(titulo)} — {_esc(nombre)}</h3>"
            f'<iframe class="doc-embed-frame mockup-frame" src="{_esc(src)}" '
            f'title="{_esc(nombre)}" loading="lazy"></iframe>'
            f'<p class="embed-print-hint">En PDF: abra el mockup desde '
            f'<a href="{_esc(src)}">{_esc(nombre)}</a> (<code>{_esc(rel)}</code>).</p>'
            f'<p class="embed-link"><a href="{_esc(src)}" target="_blank" rel="noopener">'
            f"Abrir mockup en pestaña nueva</a> · <code>{_esc(rel)}</code></p>"
            f"</div>"
        )
    return "\n".join(partes)


def _html_diagrama_flujo(id_sr: str, sol: dict) -> str:
    rel = _resolve_diagrama_flujo(sol)
    if not rel:
        return (
            '<p class="aviso">No hay diagrama. Pulse <strong>Generar diagrama</strong> '
            "en el Chat (sale de conocimiento/ del proceso) o cierre la solicitud para generarlo.</p>"
        )
    abs_path = os.path.join(ROOT, rel.replace("/", os.sep))
    if not os.path.isfile(abs_path):
        return f'<p class="aviso">Diagrama declarado pero no encontrado: <code>{_esc(rel)}</code></p>'

    fragmento = ""
    aval_id = (_as_map(sol.get("aval")).get("idCaso") or "").strip()
    if aval_id:
        activo_sol = os.path.join(ROOT, "activo", aval_id, "solicitud.json")
        if os.path.isfile(activo_sol):
            try:
                with open(activo_sol, encoding="utf-8") as fh:
                    caso_sol = json.load(fh)
                _, ctx = diagflujo.html_caso(caso_sol)
                fragmento = diagflujo.render_fragmento(ctx)
            except (ValueError, OSError, json.JSONDecodeError):
                fragmento = ""

    if not fragmento.strip():
        fragmento = _extraer_html_incrustable(abs_path)

    src = _url_web_asset(rel)
    return (
        f'<div class="diagrama-flujo-block diagrama-incrustado">\n{fragmento}\n</div>'
        f'<iframe class="doc-embed-frame diagrama-frame" src="{_esc(src)}" '
        f'title="Diagrama de flujo" loading="lazy"></iframe>'
        f'<p class="embed-print-hint">En PDF: abra el diagrama '
        f'<a href="{_esc(src)}">{_esc(os.path.basename(rel))}</a>.</p>'
        f'<p class="embed-link"><a href="{_esc(src)}" target="_blank" rel="noopener">'
        f"Abrir diagrama completo en pestaña nueva</a> · <code>{_esc(rel)}</code></p>"
    )


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


def _iso_to_ts(iso: str) -> float:
    if not iso:
        return 0.0
    raw = str(iso).strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(raw).timestamp()
    except ValueError:
        return 0.0


def _mtime_iso(rel: str) -> str:
    abs_path = os.path.join(ROOT, str(rel or "").replace("/", os.sep))
    if not os.path.isfile(abs_path):
        return ""
    try:
        return datetime.fromtimestamp(os.path.getmtime(abs_path)).isoformat(timespec="seconds")
    except OSError:
        return ""


def estado_documento(id_sr: str) -> dict:
    """Compara mockups/diagrama en disco vs lo último generado en documento.html."""
    sol = load(id_sr)
    if not sol:
        raise ValueError("Solicitud no encontrada")
    doc_meta = _as_map(sol.get("documento"))
    doc_path = os.path.join(caso_dir(id_sr), "documento.html")
    generado_en = doc_meta.get("generadoEn") or ""
    base_ts = _iso_to_ts(generado_en)
    if os.path.isfile(doc_path):
        base_ts = max(base_ts, os.path.getmtime(doc_path))

    mockups_actuales = _rutas_mockups(sol, id_sr)
    mockups_doc = list(doc_meta.get("mockups") or [])
    diag_actual = _resolve_diagrama_flujo(sol)
    diag_doc = (doc_meta.get("diagramaFlujo") or "").strip()

    mockups_nuevos = []
    mockups_modificados = []
    for rel in mockups_actuales:
        abs_path = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.isfile(abs_path):
            mockups_nuevos.append({"ruta": rel, "motivo": "no_encontrado"})
            continue
        if rel not in mockups_doc:
            mockups_nuevos.append({"ruta": rel, "motivo": "nuevo"})
        elif base_ts and os.path.getmtime(abs_path) > base_ts + 1:
            mockups_modificados.append({"ruta": rel, "motivo": "modificado"})

    mockups_removidos = [r for r in mockups_doc if r not in mockups_actuales]

    diagrama_desactualizado = False
    if diag_actual != diag_doc:
        diagrama_desactualizado = True
    elif diag_actual:
        abs_diag = os.path.join(ROOT, diag_actual.replace("/", os.sep))
        if os.path.isfile(abs_diag) and base_ts and os.path.getmtime(abs_diag) > base_ts + 1:
            diagrama_desactualizado = True

    motivos = []
    if not os.path.isfile(doc_path):
        motivos.append("Aún no hay documento.html generado.")
    for m in mockups_nuevos:
        if m.get("motivo") == "no_encontrado":
            motivos.append(f"Mockup declarado pero no encontrado: {m.get('ruta')}")
        else:
            motivos.append(f"Mockup nuevo sin incrustar: {os.path.basename(m.get('ruta') or '')}")
    for m in mockups_modificados:
        motivos.append(f"Mockup modificado tras el último documento: {os.path.basename(m.get('ruta') or '')}")
    for rel in mockups_removidos:
        motivos.append(f"Mockup quitado del listado: {os.path.basename(rel)}")
    if diagrama_desactualizado:
        motivos.append("El diagrama de flujo cambió o no coincide con el documento.")

    necesita = bool(
        not os.path.isfile(doc_path)
        or mockups_nuevos
        or mockups_modificados
        or mockups_removidos
        or diagrama_desactualizado
    )

    mockups_info = []
    for rel in mockups_actuales:
        abs_path = os.path.join(ROOT, rel.replace("/", os.sep))
        nombre = os.path.basename(rel)
        mockups_info.append({
            "ruta": rel,
            "url": f"/{rel}",
            "titulo": nombre,
            "tipo": "sp" if "sp" in nombre.lower() else "ux",
            "existe": os.path.isfile(abs_path),
            "modificadoEn": _mtime_iso(rel),
            "origen": "carpeta mockups" if f"/{id_sr}/mockups/" in rel.replace("\\", "/") else "declarado",
        })

    aval_id = (_as_map(sol.get("aval")).get("idCaso") or "").strip()
    diag_origen = ""
    if diag_actual:
        if diag_actual.startswith(f"dictamenes/{aval_id}") or diag_actual.startswith(f"activo/{aval_id}"):
            diag_origen = f"aval técnico {aval_id}"
        elif diag_actual.startswith(f"solicitudes/{id_sr}"):
            diag_origen = "solicitud"
        else:
            diag_origen = "ruta declarada"

    linea_tiempo = []
    if diag_actual:
        linea_tiempo.append({
            "tipo": "diagrama",
            "etiqueta": "Diagrama de flujo",
            "ruta": diag_actual,
            "cuando": _mtime_iso(diag_actual),
            "origen": diag_origen or "—",
        })
    for m in mockups_info:
        if m.get("existe"):
            linea_tiempo.append({
                "tipo": "mockup",
                "etiqueta": m.get("titulo") or "Mockup",
                "ruta": m.get("ruta"),
                "cuando": m.get("modificadoEn") or "",
                "origen": m.get("origen") or "—",
            })
    if os.path.isfile(doc_path):
        linea_tiempo.append({
            "tipo": "documento",
            "etiqueta": "Documento comité (incrustado)",
            "ruta": f"solicitudes/{id_sr}/documento.html",
            "cuando": generado_en or _mtime_iso(f"solicitudes/{id_sr}/documento.html"),
            "origen": "Generar documento",
        })
    linea_tiempo.sort(key=lambda x: _iso_to_ts(x.get("cuando") or ""))

    return {
        "ok": True,
        "id": id_sr,
        "tieneDocumento": os.path.isfile(doc_path),
        "generadoEn": generado_en,
        "necesitaRegenerar": necesita,
        "motivos": motivos,
        "mockupsActuales": mockups_actuales,
        "mockups": mockups_info,
        "mockupsEnDocumento": mockups_doc,
        "mockupsNuevos": mockups_nuevos,
        "mockupsModificados": mockups_modificados,
        "mockupsRemovidos": mockups_removidos,
        "diagramaFlujo": diag_actual,
        "diagramaUrl": f"/{diag_actual}" if diag_actual else "",
        "diagramaModificadoEn": _mtime_iso(diag_actual) if diag_actual else "",
        "diagramaOrigen": diag_origen,
        "diagramaDesactualizado": diagrama_desactualizado,
        "lineaTiempo": linea_tiempo,
    }


def generar_documento(id_sr: str) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("No hay solicitud. Guárdela primero.")
    if _esta_cerrada(sol):
        raise ValueError("La solicitud está cerrada. No se regenera el documento.")
    kb_info = contrastar_kb(sol)
    if kb_info.get("procesoId") and not sol.get("procesoId"):
        sol["procesoId"] = kb_info["procesoId"]
        guardar(sol)
        sol = load(id_sr)
    plantilla = open(PLANTILLA, encoding="utf-8").read()
    mockups_html = _html_mockups(id_sr, sol)
    diag_html = _html_diagrama_flujo(id_sr, sol)
    hay_mockups = "embed-block" in mockups_html
    hay_diag = "diagrama-flujo-block" in diag_html or "doc-embed-frame" in diag_html
    proyecto = (sol.get("proyecto") or "").strip()
    meta_proyecto = (
        f'<div class="meta-item"><label>Proyecto</label><span>{_esc(proyecto)}</span></div>'
        if proyecto else ""
    )
    n = 3
    sec_alcance = _seccion_opcional(n, "Alcance", sol.get("alcance") or "—")
    if sec_alcance:
        n += 1
    sec_rest = _seccion_opcional(n, "Restricciones", sol.get("restricciones") or "—")
    if sec_rest:
        n += 1
    sec_crit = _seccion_opcional(n, "Criterios", sol.get("criterios") or "—")
    if sec_crit:
        n += 1
    n_reco = n
    n += 1
    sec_sql = _html_sugerencia_sql(sol, n)
    if sec_sql:
        n += 1
    sec_norm = _html_normativa(id_sr, sol, n)
    if sec_norm:
        n += 1
    seccion_mockups = (
        f'<section id="mockups"><h2>{n}. Mockups</h2>{mockups_html}</section>'
        if hay_mockups else ""
    )
    if hay_mockups:
        n += 1
    seccion_diag = (
        f'<section id="diagrama-flujo"><h2>{n}. Diagrama de flujo</h2>{diag_html}</section>'
        if hay_diag else ""
    )
    valores = {
        "TITULO": _esc(_titulo_corto(sol)),
        "ID": _esc(id_sr),
        "PROYECTO": _esc(proyecto or "—"),
        "META_PROYECTO": meta_proyecto,
        "FECHA": _esc((sol.get("actualizadoEn") or _now())[:10]),
        "ESTADO": _esc("Para comité" if (sol.get("estado") or "") in ("abierto", "analizado", "para_comite", "documento") else (sol.get("estado") or "Abierto")),
        "NECESIDAD": _md_html(sol.get("necesidad")),
        "ANALISIS": _md_html(sol.get("analisis") or "Pendiente de análisis del agente contra conocimiento/."),
        "RECOMENDACION": _md_html(
            sol.get("recomendacion")
            or "Incluir en el plan de trabajo si el comité valida la necesidad."
        ),
        "N_RECOMENDACION": str(n_reco),
        "SECCION_ALCANCE": sec_alcance,
        "SECCION_RESTRICCIONES": sec_rest,
        "SECCION_CRITERIOS": sec_crit,
        "SECCION_SQL": sec_sql,
        "SECCION_NORMATIVA": sec_norm,
        "SECCION_MOCKUPS": seccion_mockups,
        "SECCION_DIAGRAMA": seccion_diag,
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
    if (sol.get("estado") or "") in ("borrador", "", "abierto", "analizado"):
        sol["estado"] = "abierto"
    mockups = _rutas_mockups(sol, id_sr)
    diag_rel = _resolve_diagrama_flujo(sol)
    sol["documento"] = {
        "nombre": "documento.html",
        "ruta": f"solicitudes/{id_sr}/documento.html",
        "url": f"/api/solicitar/{id_sr}/documento",
        "dictamenCopia": f"dictamenes/{id_sr}.html",
        "mockups": mockups,
        "diagramaFlujo": diag_rel or None,
        "generadoEn": _now(),
    }
    guardar(sol)
    out = {"ok": True, "id": id_sr, "documento": sol["documento"], "kb": kb_info}
    try:
        out["estadoDocumento"] = estado_documento(id_sr)
    except ValueError:
        pass
    return out


def instruccion_agente(sol: dict) -> str:
    id_sr = sol.get("id") or ""
    archs = sol.get("archivos") or []
    lines_arch = ""
    if archs:
        lines_arch = "\n5. **Adjuntos (PDF/imagen)** — léalos:\n" + "\n".join(
            f"   - `solicitudes/{id_sr}/archivos/{a.get('nombre')}`"
            + (f" — extracto `{a.get('extractoRuta') or a.get('extracto')}`" if a.get("extracto") or a.get("extractoRuta") else "")
            for a in archs
            if a.get("nombre")
        )
    return f"""# Solicitud de requerimiento — INSTRUCCIÓN PARA EL AGENTE

Lea del disco:
1. `solicitudes/{id_sr}/solicitud.json`
2. `solicitudes/{id_sr}/chat.json`
3. `conocimiento/INDICE.json` y, si hay procesoId, `conocimiento/{{proceso}}/proceso.json` + `sps.json`
4. Qrystalos2 y documentación viva solo si la ficha no cubre la necesidad
{lines_arch}

Usted es el analista BA/funcional. El Chat **sigue activo** en cada turno. El documento de comité lo genera el coordinador (botón en el Chat).

Reglas:
- Contraste la necesidad con conocimiento/. No invente SP ni columnas.
- Si hace falta el cuerpo de un SP: **bájalo de DESAIX/SQLIX** (`python scripts/sqlix_bajar_objeto.py --solicitud {id_sr} NOMBRE`) a `solicitudes/{id_sr}/sql/`, compare PREVERSION vs última Cerrada, y **después** léalo. Tiene permiso de lectura al catálogo. No lo guarde en la carpeta compartida `sql/`.
- Liste SOLO los SP/METODO de este cambio.
- Escriba en solicitud.json: **titulo corto** (máx. 90 caracteres, no el párrafo), analisis, alcance, restricciones, criterios, recomendacion, procesoId.
- Si el cambio es SQL: escriba **cambioPropuestoSql** con el texto y, enseguida, `---ANTES---` más el SQL de hoy y `---SUGERIDO---` más el SQL propuesto (especificación; no ejecutar). El documento de comité lo pinta en «Sugerencia de código SQL», en «Cómo está hoy» y «Lo que se sugiere».
- El documento de comité usa esos campos: no deje analisis vacío ni de una línea.
- Responda en chat.json (autor: agente). Este Chat es solo de esta solicitud.
- NO genere el HTML del comité ni el dictamen de Analista.
- Si falta un dato que bloquee, PIDA y deténgase.

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
"""


def preparar_analisis(id_sr: str) -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Guarde la solicitud antes de analizar.")
    if _esta_cerrada(sol):
        raise ValueError("La solicitud está cerrada.")
    if analisis_lanzado(sol):
        raise ValueError("El análisis inicial ya se lanzó. Siga en el Chat de esta solicitud.")
    dest = caso_dir(id_sr)
    os.makedirs(dest, exist_ok=True)
    sol["analisisLanzado"] = True
    sol["titulo"] = _titulo_corto(sol)
    guardar(sol)
    with open(os.path.join(dest, "INSTRUCCION-AGENTE.md"), "w", encoding="utf-8") as fh:
        fh.write(instruccion_agente(sol))
    kb_info = contrastar_kb(sol)
    if kb_info.get("procesoId") and not sol.get("procesoId"):
        sol = load(id_sr) or sol
        sol["procesoId"] = kb_info["procesoId"]
        guardar(sol)
    append_chat(
        id_sr,
        "sistema",
        "El agente está contrastando la necesidad con conocimiento/ para armar el documento de comité.",
    )
    return {"ok": True, "id": id_sr, "solicitud": load(id_sr), "kb": kb_info}


def _resolve_carpeta_plataforma(id_sr: str, carpeta: str = "") -> str:
    """Carpeta destino absoluta para PDF/PNG de subida a plataforma IX."""
    raw = (carpeta or "").strip()
    if not raw:
        sol = load(id_sr) or {}
        raw = (_as_map(sol.get("plataforma")).get("carpeta") or "").strip()
    if not raw:
        raw = carpeta_export_default() or f"solicitudes/{id_sr}/plataforma"
    if not os.path.isabs(raw):
        dest = os.path.join(ROOT, *raw.replace("\\", "/").split("/"))
    else:
        dest = raw
    os.makedirs(dest, exist_ok=True)
    dest = os.path.normpath(dest)
    return _subcarpeta_export(id_sr, dest)


def _subcarpeta_export(id_sr: str, dest_dir: str) -> str:
    """Dentro de Escritorio/Descargas/etc. crea {id_sr}/ para no mezclar archivos."""
    sid = (id_sr or "").strip()
    if not sid or not dest_dir:
        return dest_dir
    base = os.path.basename(dest_dir)
    if base.upper() == sid.upper():
        return dest_dir
    rel = ""
    try:
        rel = os.path.relpath(dest_dir, ROOT).replace("\\", "/")
    except ValueError:
        rel = ""
    if rel.replace("\\", "/").startswith(f"solicitudes/{sid}/"):
        return dest_dir
    sub = os.path.join(dest_dir, sid)
    os.makedirs(sub, exist_ok=True)
    return os.path.normpath(sub)


def _ba_http_base() -> str:
    port = (os.environ.get("QRYSTALOS_BA_PORT") or os.environ.get("PORT") or "8765").strip()
    return f"http://127.0.0.1:{port}"


def _html_mockups_para_pdf(id_sr: str, rels: list, http_base: str = "") -> str:
    """Junta los mockups en un HTML imprimible. Sin iframe ni localhost: el servidor no puede atenderse a sí mismo mientras Chrome espera."""
    bloques = []
    for rel in rels:
        abs_p = os.path.join(ROOT, str(rel).replace("/", os.sep))
        if not os.path.isfile(abs_p):
            continue
        texto = open(abs_p, encoding="utf-8", errors="replace").read()
        estilos = "".join(re.findall(r"<style\b[^>]*>.*?</style>", texto, flags=re.I | re.S))
        cuerpo_m = re.search(r"<body\b[^>]*>(.*)</body>", texto, flags=re.I | re.S)
        cuerpo = cuerpo_m.group(1) if cuerpo_m else texto
        titulo = os.path.basename(rel)
        bloques.append(
            f'<section class="page"><h2>{_esc(titulo)}</h2>{estilos}{cuerpo}</section>'
        )
    if not bloques:
        return ""
    return (
        "<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"
        "<title>Mockups — "
        + _esc(id_sr)
        + "</title><style>"
        "@page{size:A4 landscape;margin:8mm;}body{font-family:Segoe UI,sans-serif;margin:0;}"
        "h1{font-size:16px;color:#E67817;padding:10px 14px;margin:0;}"
        ".page{page-break-after:always;padding:0 8px 12px;}h2{font-size:13px;color:#CB500F;}"
        "</style></head><body>"
        f"<h1>Mockups — {_esc(id_sr)}</h1>"
        + "".join(bloques)
        + "</body></html>"
    )


def _copiar_pdf_generado(src_pdf: str, dest_pdf: str) -> bool:
    if not mailer._pdf_utilizable(src_pdf):
        return False
    try:
        if os.path.abspath(src_pdf) == os.path.abspath(dest_pdf):
            return mailer._pdf_utilizable(dest_pdf)
        shutil.copy2(src_pdf, dest_pdf)
        return mailer._pdf_utilizable(dest_pdf)
    except OSError:
        return False


def _detalle_navegador() -> str:
    texto = (getattr(mailer, "_ULTIMO_ERROR_NAVEGADOR", "") or "").replace("\n", " ").strip()
    return texto[:180]


def generar_export_plataforma(id_sr: str, carpeta: str = "", opciones: dict | None = None) -> dict:
    """
    Genera archivos para IX OnLine (solo PDF e imagen):
    - {id}-documento-comite.pdf
    - {id}-mockups.pdf (todos los mockups del caso)
    - {id}-diagrama-flujo.png
    """
    opts = opciones if isinstance(opciones, dict) else {}
    inc_doc = opts.get("incluirDocumento", True)
    inc_mock = opts.get("incluirMockups", True)
    inc_diag = opts.get("incluirDiagrama", True)
    if not (inc_doc or inc_mock or inc_diag):
        raise ValueError("Marque al menos un archivo para guardar (PDF solicitud, PDF mockup o imagen del flujo).")
    sol = load(id_sr)
    if not sol:
        raise ValueError("No hay solicitud. Guárdela primero.")
    if (sol.get("id") or "").strip() not in ("", id_sr):
        raise ValueError(f"solicitud.json no corresponde a {id_sr}.")
    if not _esta_cerrada(sol):
        _asegurar_html_entregables(id_sr)
        sol = load(id_sr) or sol
    doc_path = os.path.join(caso_dir(id_sr), "documento.html")
    if not os.path.isfile(doc_path):
        generar_documento(id_sr)
        sol = load(id_sr) or sol
        doc_path = os.path.join(caso_dir(id_sr), "documento.html")
    if not os.path.isfile(doc_path):
        raise ValueError("Genere documento.html antes de exportar PDF.")

    dest_dir = _resolve_carpeta_plataforma(id_sr, carpeta)
    generados = []
    errores = []

    if inc_doc:
        nombre_doc = f"{id_sr}-documento-comite.pdf"
        dest_doc = os.path.join(dest_dir, nombre_doc)
        pdf_tmp = mailer._html_a_pdf(doc_path, dest_pdf=dest_doc)
        if _copiar_pdf_generado(pdf_tmp, dest_doc):
            generados.append({
                "tipo": "pdf",
                "nombre": nombre_doc,
                "ruta": _rel_desde_root(dest_doc),
                "url": f"/api/solicitar/{id_sr}/plataforma/{nombre_doc}",
            })
        else:
            errores.append(
                "No se pudo generar PDF del documento (Chrome/Edge headless). "
                + _detalle_navegador()
            )

    mockups = _rutas_mockups(sol, id_sr)
    if inc_mock and mockups:
        html_mock = _html_mockups_para_pdf(id_sr, mockups, http_base="")
        if html_mock:
            plat_srv = os.path.join(caso_dir(id_sr), "plataforma")
            os.makedirs(plat_srv, exist_ok=True)
            tmp_html = os.path.join(plat_srv, "_mockups-print.html")
            with open(tmp_html, "w", encoding="utf-8") as fh:
                fh.write(html_mock)
            nombre_mock = f"{id_sr}-mockups.pdf"
            dest_mock = os.path.join(dest_dir, nombre_mock)
            pdf_m = mailer._html_a_pdf(tmp_html, dest_pdf=dest_mock)
            if _copiar_pdf_generado(pdf_m, dest_mock):
                generados.append({
                    "tipo": "pdf",
                    "nombre": nombre_mock,
                    "ruta": _rel_desde_root(dest_mock),
                    "url": f"/api/solicitar/{id_sr}/plataforma/{nombre_mock}",
                })
            else:
                errores.append("No se pudo generar PDF de mockups. " + _detalle_navegador())
    elif inc_mock:
        errores.append("No hay mockups declarados en solicitud.json.")

    diag_rel = _resolve_diagrama_flujo(sol)
    if inc_diag and diag_rel:
        diag_abs = os.path.join(ROOT, diag_rel.replace("/", os.sep))
        if os.path.isfile(diag_abs):
            nombre_png = f"{id_sr}-diagrama-flujo.png"
            dest_png = os.path.join(dest_dir, nombre_png)
            png = mailer.html_a_png(diag_abs, dest_png, window_width=1600, window_height=1000)
            if png and os.path.isfile(png) and os.path.getsize(png) > 500:
                generados.append({
                    "tipo": "png",
                    "nombre": nombre_png,
                    "ruta": _rel_desde_root(dest_png),
                    "url": f"/api/solicitar/{id_sr}/plataforma/{nombre_png}",
                })
            else:
                errores.append("No se pudo capturar PNG del diagrama de flujo. " + _detalle_navegador())
        else:
            errores.append(f"Diagrama no encontrado: {diag_rel}")
    elif inc_diag:
        errores.append("No hay diagramaFlujo en la solicitud.")

    if not generados:
        raise ValueError(" ".join(errores) or "No se generó ningún archivo.")

    plat = _as_map(sol.get("plataforma"))
    plat["carpeta"] = dest_dir
    try:
        plat["carpetaRel"] = os.path.relpath(dest_dir, ROOT).replace("\\", "/")
    except ValueError:
        plat["carpetaRel"] = dest_dir
    plat["exportadoEn"] = _now()
    plat["archivos"] = generados
    if errores:
        plat["avisos"] = errores
    else:
        plat.pop("avisos", None)
    sol["plataforma"] = plat
    _write_json(os.path.join(caso_dir(id_sr), "solicitud.json"), sol)

    append_chat(
        id_sr,
        "sistema",
        "Export plataforma: "
        + ", ".join(g["nombre"] for g in generados)
        + f" en `{plat.get('carpetaRel') or dest_dir}`.",
    )
    abrir_en_explorador(dest_dir)
    return {
        "ok": True,
        "id": id_sr,
        "carpeta": dest_dir,
        "carpetaRel": plat.get("carpetaRel"),
        "archivos": generados,
        "avisos": errores,
        "solicitud": sol,
    }


def _rel_desde_root(abs_path: str) -> str:
    try:
        return os.path.relpath(abs_path, ROOT).replace("\\", "/")
    except ValueError:
        return abs_path.replace("\\", "/")


def _bloque_sql(titulo: str, codigo: str) -> str:
    return f'<h3>{_esc(titulo)}</h3><pre class="sql-spec">{_esc(codigo.strip())}</pre>'


def _html_sugerencia_sql(sol: dict, n: int) -> str:
    texto = (sol.get("cambioPropuestoSql") or sol.get("sugerenciaSql") or "").strip()
    if not texto:
        return ""
    aviso = (
        '<p class="aviso">Especificación para el comité y el desarrollador. '
        "No ejecutar desde BA. Contrastar PREVERSION vs última Cerrada antes de implementar.</p>"
    )
    if "---ANTES---" in texto and "---SUGERIDO---" in texto:
        intro, resto = texto.split("---ANTES---", 1)
        antes, sugerido = resto.split("---SUGERIDO---", 1)
        cuerpo = ""
        if intro.strip():
            cuerpo += f'<div class="content-block">{_md_html(intro.strip())}</div>'
        cuerpo += _bloque_sql("Cómo está hoy", antes)
        cuerpo += _bloque_sql("Lo que se sugiere", sugerido)
    elif "\n---SQL---\n" in texto:
        regla, codigo = texto.split("\n---SQL---\n", 1)
        cuerpo = (
            f'<div class="content-block">{_md_html(regla.strip())}</div>'
            f'<pre class="sql-spec">{_esc(codigo.strip())}</pre>'
        )
    else:
        cuerpo = f'<pre class="sql-spec">{_esc(texto)}</pre>'
    return f'<section id="sugerencia-sql"><h2>{n}. Sugerencia de código SQL</h2>{aviso}{cuerpo}</section>'


def _html_normativa(id_sr: str, sol: dict, n: int) -> str:
    items = list(sol.get("archivos") or [])
    texto = (sol.get("normativa") or "").strip()
    if not items and not texto:
        return ""
    lis = []
    for a in items:
        nombre = a.get("nombre") or ""
        tipo = a.get("tipo") or "adjunto"
        url = a.get("url") or f"/api/solicitar/{id_sr}/archivo/{nombre}"
        lis.append(
            f'<li><a href="{_esc(url)}" target="_blank" rel="noopener">{_esc(nombre)}</a>'
            f' <span class="aviso">({_esc(tipo)})</span></li>'
        )
    cuerpo = ""
    if texto:
        cuerpo += f'<div class="content-block">{_md_html(texto)}</div>'
    if lis:
        cuerpo += f"<ul>{''.join(lis)}</ul>"
        cuerpo += '<p class="aviso">Cite el extracto en el análisis, no solo el nombre del archivo.</p>'
    return f'<section id="normativa"><h2>{n}. Normativa y adjuntos</h2>{cuerpo}</section>'


def listar_archivos(id_sr: str) -> list:
    sol = load(id_sr) or {}
    return list(sol.get("archivos") or [])


NECESIDAD_MD_MAX_CHARS = 40000


def _cargar_necesidad_desde_texto(sol: dict, nombre: str, texto: str) -> dict:
    """Un .md/.txt trae la necesidad detallada: la vuelca en `necesidad` (y título si falta).

    Devuelve {"necesidad": "nueva"|"anexada"|"igual", "titulo": bool}.
    """
    cuerpo = (texto or "").replace("\r\n", "\n").strip()
    res = {"necesidad": "igual", "titulo": False}
    if not cuerpo:
        return res
    if len(cuerpo) > NECESIDAD_MD_MAX_CHARS:
        cuerpo = cuerpo[:NECESIDAD_MD_MAX_CHARS].rstrip() + "\n\n(… texto recortado; vea el archivo original)"
    # Título: primer encabezado Markdown, solo si el formulario no lo tiene.
    m = re.search(r"^#{1,3}\s+(.+?)\s*#*\s*$", cuerpo, re.MULTILINE)
    titulo_actual = (sol.get("titulo") or "").strip()
    if m and (not titulo_actual or titulo_actual == "Solicitud de requerimiento"):
        t = re.sub(r"[*_`]", "", m.group(1)).strip()
        if t:
            sol["titulo"] = t[:90]
            res["titulo"] = True
    actual = (sol.get("necesidad") or "").replace("\r\n", "\n").strip()
    if not actual:
        sol["necesidad"] = cuerpo
        res["necesidad"] = "nueva"
    elif cuerpo not in actual:
        sol["necesidad"] = f"{actual}\n\n--- Desde {nombre} ---\n{cuerpo}"
        res["necesidad"] = "anexada"
    return res


def guardar_archivo(id_sr: str, nombre: str, data_url: str, tipo: str = "normativa") -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Guarde la solicitud primero.")
    if _esta_cerrada(sol):
        raise ValueError("La solicitud está cerrada.")
    raw_nombre = os.path.basename((nombre or "adjunto").strip()) or "adjunto"
    raw_nombre = re.sub(r"[^\w.\-]", "_", raw_nombre)
    dest_dir = os.path.join(caso_dir(id_sr), "archivos")
    os.makedirs(dest_dir, exist_ok=True)
    payload = data_url or ""
    if "," in payload and payload.strip().lower().startswith("data:"):
        payload = payload.split(",", 1)[1]
    import base64

    raw = base64.b64decode(payload, validate=False)
    path = os.path.join(dest_dir, raw_nombre)
    if os.path.exists(path):
        stem, ext = os.path.splitext(raw_nombre)
        raw_nombre = f"{stem}-{int(datetime.now().timestamp())}{ext}"
        path = os.path.join(dest_dir, raw_nombre)
    with open(path, "wb") as fh:
        fh.write(raw)
    extracto = f"{os.path.splitext(raw_nombre)[0]}.extracto.txt"
    extracto_path = os.path.join(dest_dir, extracto)
    texto, aviso = "", ""
    try:
        import servir_qrystalos_ba as srv

        texto, aviso = srv._extraer_texto_archivo(path)
    except Exception:
        if raw_nombre.lower().endswith((".txt", ".md")):
            texto = raw.decode("utf-8", errors="replace")[:80000]
    with open(extracto_path, "w", encoding="utf-8") as fh:
        fh.write(f"Extracto de {raw_nombre}\nSolicitud: {id_sr}\n")
        if aviso:
            fh.write(f"Aviso: {aviso}\n")
        fh.write("=" * 40 + "\n\n")
        fh.write(texto or "(sin texto extraíble — abra el original)\n")
    es_texto_necesidad = raw_nombre.lower().endswith((".md", ".txt"))
    carga = {"necesidad": "igual", "titulo": False}
    if es_texto_necesidad:
        carga = _cargar_necesidad_desde_texto(sol, raw_nombre, texto)
        tipo = "necesidad"  # guardar() recalcula título y actualizadoEn
    meta = {
        "nombre": raw_nombre,
        "ruta": f"solicitudes/{id_sr}/archivos/{raw_nombre}",
        "extracto": extracto,
        "extractoRuta": f"solicitudes/{id_sr}/archivos/{extracto}",
        "tipo": (tipo or "normativa").strip() or "normativa",
        "bytes": len(raw),
        "url": f"/api/solicitar/{id_sr}/archivo/{raw_nombre}",
        "urlExtracto": f"/api/solicitar/{id_sr}/archivo/{extracto}",
        "subidaEn": _now(),
        "avisoExtracto": aviso or "",
    }
    items = [a for a in (sol.get("archivos") or []) if a.get("nombre") != raw_nombre]
    items.append(meta)
    sol["archivos"] = items
    guardar(sol)
    if carga["necesidad"] == "nueva":
        extra = " Título tomado del primer encabezado." if carga["titulo"] else ""
        append_chat(
            id_sr, "sistema",
            f"Necesidad cargada desde `{meta['ruta']}` ({len((texto or '').strip())} caracteres) al campo "
            f"«Necesidad».{extra} El agente la lee como fuente principal del requerimiento.",
        )
    elif carga["necesidad"] == "anexada":
        append_chat(
            id_sr, "sistema",
            f"Texto de `{meta['ruta']}` anexado al final del campo «Necesidad» (ya había texto). "
            "El agente lee ambos; revise si sobra algo.",
        )
    else:
        append_chat(id_sr, "sistema", f"Adjunto: `{meta['ruta']}`. El agente debe leer el extracto.")
    return meta


def _como_caso_mockup(sol: dict) -> dict:
    imgs = []
    for a in sol.get("archivos") or []:
        n = (a.get("nombre") or "").lower()
        if n.endswith((".png", ".jpg", ".jpeg", ".webp", ".gif")):
            imgs.append({"nombre": a.get("nombre"), "url": a.get("url")})
    return {
        "identificacion": {"idCaso": sol.get("id") or "", "idReq": sol.get("id") or ""},
        "proyecto": {
            "nombre": sol.get("proyecto") or "",
            "modulo": sol.get("modulo") or "",
            "rutaPantalla": "",
        },
        "sql": {"procesoId": (sol.get("procesoId") or "").strip()},
        "contenido": {
            "titulo": _titulo_corto(sol),
            "requerimiento": sol.get("necesidad") or "",
            "cambioPropuestoSimple": sol.get("propuesta") or sol.get("recomendacion") or "",
            "criteriosAceptacion": sol.get("criterios") or "",
            "recomendacion": sol.get("recomendacion") or "",
            "alcance": sol.get("alcance") or "",
            "analisis": sol.get("analisis") or "",
            "imagenesAnalisis": imgs,
        },
        "gestion": {},
    }


def generar_mockups(id_sr: str, notas: str = "") -> list:
    import mockup_generar as mockgen

    sol = load(id_sr)
    if not sol:
        raise ValueError("Guarde la solicitud primero.")
    if _esta_cerrada(sol):
        raise ValueError("La solicitud está cerrada.")
    adapt = _como_caso_mockup(sol)
    dest = os.path.join(caso_dir(id_sr), "mockups")
    os.makedirs(dest, exist_ok=True)
    try:
        pares = mockgen.generar_archivos(adapt, notas=notas)
    except ValueError:
        ctx = {
            "titulo": _titulo_corto(sol),
            "propuesto": sol.get("recomendacion") or "",
            "hoy": sol.get("hoy") or "",
            "notas": notas,
            "generadoEn": _now(),
        }
        pares = [("mockup-ux-pantalla.html", mockgen.render_mockup_ux_generic(ctx, adapt, {}))]
    nombres = []
    for nombre, html in pares:
        with open(os.path.join(dest, nombre), "w", encoding="utf-8") as fh:
            fh.write(html)
        nombres.append(nombre)
    rels = [f"solicitudes/{id_sr}/mockups/{n}" for n in nombres]
    sol["mockups"] = rels
    doc = dict(sol.get("documento") or {})
    doc["mockups"] = rels
    sol["documento"] = doc
    guardar(sol)
    append_chat(
        id_sr,
        "sistema",
        "Mockup de la **propuesta** generado: " + ", ".join(f"`{r}`" for r in rels) + ".",
    )
    return rels


def generar_diagrama(id_sr: str, notas: str = "") -> dict:
    sol = load(id_sr)
    if not sol:
        raise ValueError("Guarde la solicitud primero.")
    if _esta_cerrada(sol):
        raise ValueError("La solicitud está cerrada.")
    if not (sol.get("procesoId") or "").strip():
        kb_info = contrastar_kb(sol)
        if kb_info.get("procesoId"):
            sol["procesoId"] = kb_info["procesoId"]
            guardar(sol)
            sol = load(id_sr) or sol
    adapt = _como_caso_mockup(sol)
    dest = os.path.join(caso_dir(id_sr), "diagramas")
    os.makedirs(dest, exist_ok=True)
    try:
        html, _ctx = diagflujo.html_caso(adapt, notas=notas)
    except ValueError:
        pid = (sol.get("procesoId") or "").strip()
        if not pid:
            raise
        html, _ctx = diagflujo.html_proceso(
            pid,
            pregunta=(sol.get("analisis") or sol.get("necesidad") or ""),
            notas=notas,
        )
    with open(os.path.join(dest, "flujo.html"), "w", encoding="utf-8") as fh:
        fh.write(html)
    rel = f"solicitudes/{id_sr}/diagramas/flujo.html"
    sol["diagramaFlujo"] = rel
    doc = dict(sol.get("documento") or {})
    doc["diagramaFlujo"] = rel
    sol["documento"] = doc
    guardar(sol)
    append_chat(id_sr, "sistema", f"Diagrama de flujo generado: `{rel}`.")
    return {
        "ruta": rel,
        "titulo": "Diagrama de flujo",
        "url": f"/api/solicitar/{id_sr}/diagrama/flujo.html",
    }


def _asegurar_html_entregables(id_sr: str) -> list:
    avisos = []
    try:
        generar_documento(id_sr)
    except Exception as exc:
        avisos.append(f"Documento: {exc}")
    sol = load(id_sr) or {}
    if not _resolve_diagrama_flujo(sol):
        try:
            generar_diagrama(id_sr)
        except Exception as exc:
            avisos.append(f"Diagrama: {exc}")
    sol = load(id_sr) or {}
    if not _rutas_mockups(sol, id_sr):
        try:
            generar_mockups(id_sr)
        except Exception as exc:
            avisos.append(f"Mockup: {exc}")
    try:
        generar_documento(id_sr)
    except Exception:
        pass
    return avisos


def _preparar_entregables_cierre(id_sr: str, carpeta: str = "", opciones: dict | None = None) -> list:
    """Documento + mockup + diagrama, luego PDF e imagen en la carpeta indicada."""
    avisos = _asegurar_html_entregables(id_sr)
    try:
        generar_export_plataforma(id_sr, carpeta=carpeta, opciones=opciones)
    except Exception as exc:
        avisos.append(f"PDF/PNG: {exc}")
    return avisos


def panel_chat(id_sr: str) -> dict:
    sol = load(id_sr) or {}
    doc = sol.get("documento") or {}
    mockups = []
    for rel in _rutas_mockups(sol, id_sr):
        nombre = os.path.basename(rel)
        mockups.append({
            "ruta": rel,
            "titulo": nombre,
            "url": f"/api/solicitar/{id_sr}/mockup/{nombre}",
            "existe": os.path.isfile(os.path.join(ROOT, *rel.split("/"))),
        })
    documentos = []
    if doc.get("url") or os.path.isfile(os.path.join(caso_dir(id_sr), "documento.html")):
        documentos.append({
            "tipo": "documento",
            "titulo": "Documento de comité",
            "url": doc.get("url") or f"/api/solicitar/{id_sr}/documento",
            "ruta": doc.get("ruta") or f"solicitudes/{id_sr}/documento.html",
        })
    diag_rel = _resolve_diagrama_flujo(sol)
    diagrama = None
    if diag_rel:
        dnom = os.path.basename(diag_rel)
        diagrama = {
            "ruta": diag_rel,
            "titulo": "Diagrama de flujo",
            "url": f"/api/solicitar/{id_sr}/diagrama/{dnom}",
            "existe": os.path.isfile(os.path.join(ROOT, *diag_rel.split("/"))),
        }
    entregables = []
    for a in _as_map(sol.get("plataforma")).get("archivos") or []:
        nom = a.get("nombre") or ""
        entregables.append({
            **a,
            "url": f"/api/solicitar/{id_sr}/plataforma/{nom}" if nom else "",
        })
    return {
        "ok": True,
        "id": id_sr,
        "solicitud": sol,
        "chat": load_chat(id_sr),
        "analisisLanzado": analisis_lanzado(sol),
        "documentos": documentos,
        "mockups": mockups,
        "diagrama": diagrama,
        "entregables": entregables,
        "archivos": listar_archivos(id_sr),
    }
