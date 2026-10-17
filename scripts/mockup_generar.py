# -*- coding: utf-8 -*-
"""Mockups UX de la ventana PROPUESTA (desarrollo), no de la captura del problema."""
from __future__ import annotations

import html
import os
import re
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)

import sys

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import diagrama_flujo as diagflujo  # noqa: E402
import conocimiento as kb  # noqa: E402

_STOP = {
    "este", "esta", "para", "como", "debe", "solo", "cada", "todo", "toda",
    "cuando", "donde", "desde", "hasta", "entre", "sobre", "según", "segun",
    "mismo", "misma", "otros", "otras", "tambien", "también", "ningun",
    "ningún", "ninguna", "cambio", "requerimiento",
}


def _esc(s) -> str:
    return html.escape(str(s or ""), quote=True)


def _clip(s, n=400) -> str:
    text = re.sub(r"\s+", " ", str(s or "").strip())
    if len(text) <= n:
        return text
    return text[: n - 1].rstrip() + "…"


def _textos_req(solicitud: dict) -> str:
    return diagflujo._textos_req(solicitud)


def _textos_propuesta(solicitud: dict, notas: str = "") -> str:
    """Solo textos de la solución. El requerimiento (problema) no entra aquí."""
    c = solicitud.get("contenido") or {}
    return "\n".join(
        str(x or "")
        for x in (
            c.get("cambioPropuestoSimple"),
            c.get("criteriosAceptacion"),
            c.get("recomendacion"),
            c.get("alcance"),
            c.get("mockupsNotas"),
            notas,
        )
        if str(x or "").strip()
    )


def _propuesta_resumen(solicitud: dict, ctx=None) -> str:
    c = solicitud.get("contenido") or {}
    return (
        (c.get("cambioPropuestoSimple") or "").strip()
        or (c.get("recomendacion") or "").strip()
        or ((ctx or {}).get("propuesto") or "").strip()
        or ""
    )


def _tiene_propuesta(solicitud: dict, ctx=None) -> bool:
    c = solicitud.get("contenido") or {}
    if _propuesta_resumen(solicitud, ctx):
        return True
    return bool((c.get("criteriosAceptacion") or "").strip())


def _tokens(s: str) -> set[str]:
    found = set(re.findall(r"[a-záéíóúñü0-9]{4,}", (s or "").lower()))
    return {t for t in found if t not in _STOP}


def _captura_url(solicitud: dict) -> str:
    ident = solicitud.get("identificacion") or {}
    id_caso = ident.get("idCaso") or ""
    imgs = ((solicitud.get("contenido") or {}).get("imagenesAnalisis") or [])
    if not imgs:
        return ""
    first = imgs[0] or {}
    nombre = first.get("nombre") or ""
    if nombre:
        return f"../imagenes/{nombre}"
    if first.get("url") and "/imagen/" in str(first["url"]):
        return f"../imagenes/{str(first['url']).split('/imagen/')[-1].split('?')[0]}"
    return ""


def _blob_control(ctrl: dict) -> str:
    return " ".join(
        str(ctrl.get(k) or "")
        for k in ("id", "nombre", "explicacion", "invariante")
    )


def _find_control(proceso: dict, solicitud: dict) -> dict:
    """Elige el control del proceso por solapamiento con la propuesta (no sesgo FCXCR)."""
    proy = solicitud.get("proyecto") or {}
    c = solicitud.get("contenido") or {}
    query = " ".join(
        (
            _textos_propuesta(solicitud),
            c.get("titulo") or "",
            proy.get("modulo") or "",
            proy.get("rutaPantalla") or "",
            (solicitud.get("sql") or {}).get("procesoId") or "",
        )
    )
    qtok = _tokens(query)
    best = None
    best_score = 0
    for capa in proceso.get("capas") or []:
        for ctrl in capa.get("controles") or []:
            blob = _blob_control(ctrl)
            ctok = _tokens(blob)
            score = len(qtok & ctok)
            cid = (ctrl.get("id") or "").lower()
            if cid and cid in query.lower():
                score += 6
            nombre = (ctrl.get("nombre") or "").lower()
            if nombre and nombre in query.lower():
                score += 4
            if score > best_score:
                best_score = score
                best = ctrl
    return best or {}


def _ruta_pantalla(solicitud: dict, control: dict) -> str:
    criterios = ((solicitud.get("contenido") or {}).get("criteriosAceptacion") or "")
    alcance = ((solicitud.get("contenido") or {}).get("alcance") or "")
    blob = criterios + "\n" + alcance
    m = re.search(r"`(/[^`]+)`", blob)
    if m:
        return m.group(1)
    m2 = re.search(r"(/admin/[a-z0-9_-]+)", blob, re.I)
    if m2:
        return m2.group(1)
    expl = control.get("explicacion") or ""
    m3 = re.search(r"`(/[^`]+)`", expl)
    if m3:
        return m3.group(1)
    ruta = (solicitud.get("proyecto") or {}).get("rutaPantalla") or ""
    return ruta or ""


def _es_fcxcr(solicitud: dict, control: dict) -> bool:
    pid = ((solicitud.get("sql") or {}).get("procesoId") or "").lower()
    cid = (control.get("id") or "").lower()
    ruta = _ruta_pantalla(solicitud, control).lower()
    prop = _textos_propuesta(solicitud).lower()
    blob = " ".join((pid, cid, ruta, prop))
    return (
        "fcxcr" in blob
        or cid == "respuesta-devoluciones"
        or "respuesta de devoluc" in blob
        or "respuesta devoluc" in blob
    )


def _es_fevrips_validacion_externa(solicitud: dict) -> bool:
    c = solicitud.get("contenido") or {}
    blob = " ".join(
        (
            c.get("requerimiento") or "",
            _textos_propuesta(solicitud),
            c.get("criteriosAceptacion") or "",
            c.get("alcance") or "",
        )
    ).lower()
    return any(
        k in blob
        for k in (
            "validación externa",
            "validacion externa",
            "validacionesfevrips",
            "registrar validación fev rips externa",
            "registrar validacion fev rips externa",
        )
    )


def _detect_screen_kind(solicitud: dict, control: dict) -> str:
    text = _textos_propuesta(solicitud).lower()
    if _es_fevrips_validacion_externa(solicitud):
        return "fevrips-validacion-externa"
    if _es_fcxcr(solicitud, control):
        if any(k in text for k in ("motivo 1", "motivo 2", "motivos de devoluc", "codigo_gloza", "código glosa")):
            return "fcxcr-form-motivos"
        if any(k in text for k in ("seleccion", "seleccionadas", "lote", "simult", "varias devoluc")):
            return "fcxcr-form-masivo"
        return "fcxcr-form-motivos"
    if "cuentas niif" in text or "cueniif" in text or "en_construccion" in text:
        return "config-niif"
    return "generic"


def _captura_formulario_url(solicitud: dict) -> str:
    """Prefer 2ª captura si hay par grilla+formulario (patrón casos cartera)."""
    ident = solicitud.get("identificacion") or {}
    id_caso = ident.get("idCaso") or ""
    imgs = ((solicitud.get("contenido") or {}).get("imagenesAnalisis") or [])
    if len(imgs) >= 2:
        nombre = (imgs[1] or {}).get("nombre") or ""
        if nombre:
            return f"../imagenes/{nombre}"
    return _captura_url(solicitud)


def _bloquea_accion(text: str) -> bool:
    return any(
        k in text
        for k in (
            "deshabilit",
            "bloque",
            "impedir",
            "no se puede",
            "no podrá",
            "no podra",
            "no se podrá",
            "rechaz",
            "no ejecutable",
        )
    )


def _acciones_propuestas(solicitud: dict, notas: str = "") -> list[dict]:
    """Botones inferidos de la propuesta, no del texto del problema ni de FCXCR por 'masiva'."""
    raw = _textos_propuesta(solicitud, notas)
    text = raw.lower()
    acciones: list[dict] = []
    seen: set[str] = set()

    def _add(aid: str, label: str, tipo: str = "outline", disabled: bool = False):
        if aid in seen:
            return
        seen.add(aid)
        acciones.append({"id": aid, "label": label, "tipo": tipo, "disabled": disabled})

    for m in re.finditer(r"(?:bot[oó]n|acción|accion)\s+[«\"']([^»\"']{3,48})[»\"']", raw, re.I):
        label = m.group(1).strip()
        _add("btn-" + re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")[:24], label, "primary")

    bloquea = _bloquea_accion(text)
    if "factura masiva" in text or ("masiv" in text and "factura" in text):
        _add("fact-masiva", "Factura masiva", "accent", disabled=bloquea and "todas" in text)
    if any(k in text for k in ("factura por fila", "botón factura", "boton factura", "facturar fila")):
        _add("fact-fila", "Facturar fila", "primary", disabled=bloquea)
    if any(k in text for k in ("descarg", "export")) or ("excel" in text and "plantilla" in text):
        _add("descargar", "Descargar plantilla", "outline")
    if ("subir" in text or "cargar" in text) and any(k in text for k in ("archivo", "excel", "plano", "plantilla")):
        _add("subir", "Subir archivo", "outline")
    if _es_fcxcr(solicitud, {}) and any(k in text for k in ("seleccion", "lote", "seleccionadas")):
        _add("definir-sel", "Definir seleccionadas", "primary")
        _add("enviar-sel", "Enviar seleccionadas", "accent")
        if "excel" in text or "descarg" in text:
            _add("descargar", "Descargar devoluciones (Excel)", "outline")
        if "subir" in text or "cargar" in text:
            _add("subir", "Subir respuestas (Excel)", "outline")
    return acciones


def _filtros_propuestos(solicitud: dict, notas: str = "") -> list[dict]:
    text = _textos_propuesta(solicitud, notas).lower()
    filtros = []
    if "sede" in text:
        val = "Todas" if "todas" in text else "Sede concreta"
        filtros.append({"label": "Id. Sede", "value": val, "nuevo": True})
    if "fecha" in text:
        filtros.append({"label": "Fecha inicial", "value": "2026-09-01", "nuevo": False})
        filtros.append({"label": "Fecha final", "value": "2026-09-21", "nuevo": False})
    if "pbs" in text:
        filtros.append({"label": "PBS / No PBS", "value": "No PBS", "nuevo": "todas" in text})
    if "estado" in text:
        filtros.append({"label": "Estado", "value": "Activo", "nuevo": False})
    if "tercero" in text or "nit" in text:
        filtros.append({"label": "Tercero", "value": "Seleccionado", "nuevo": False})
    if "plan" in text:
        filtros.append({"label": "Plan", "value": "Plan del caso", "nuevo": False})
    if not filtros:
        filtros = [
            {"label": "Buscar", "value": "", "nuevo": False},
            {"label": "Estado", "value": "Vigente", "nuevo": False},
        ]
    return filtros[:6]


def _alerta_propuesta(solicitud: dict, notas: str = "") -> str:
    raw = _textos_propuesta(solicitud, notas)
    text = raw.lower()
    if not _bloquea_accion(text):
        return ""
    resumen = _propuesta_resumen(solicitud)
    if resumen:
        return _clip(resumen, 220)
    return "La acción queda bloqueada en este estado hasta cumplir la condición de la propuesta."


def _columnas_grilla(solicitud: dict, notas: str = "") -> list[str]:
    text = _textos_propuesta(solicitud, notas)
    cols = []
    if re.search(r"\b(id\s*sede|sede)\b", text, re.I):
        cols.append("Id Sede")
    for m in re.finditer(r"columna\s+[«\"']?([A-Za-zÁÉÍÓÚÑ][\w\s]{2,28})", text, re.I):
        nombre = m.group(1).strip(" .:;)")
        if nombre and nombre not in cols:
            cols.append(nombre)
    if "factura" in text.lower():
        cols.extend(["Documento", "Nombre", "Estado"])
    elif "autoriz" in text.lower():
        cols.extend(["No Aut", "Documento", "Nombre"])
    else:
        cols.extend(["Identificador", "Descripción", "Estado"])
    seen = []
    for c in cols:
        if c not in seen:
            seen.append(c)
    return seen[:7]


def _puntos_cambio(solicitud: dict) -> list[str]:
    crit = ((solicitud.get("contenido") or {}).get("criteriosAceptacion") or "")
    puntos = []
    for line in str(crit).splitlines():
        line = line.strip()
        m = re.match(r"^(?:\d+\)|\d+\.|[-*•])\s+(.+)", line)
        if not m:
            continue
        limpio = re.sub(r"`[^`]+`", "", m.group(1))
        limpio = re.sub(r"\*\*([^*]+)\*\*", r"\1", limpio)
        puntos.append(_clip(limpio, 180))
        if len(puntos) >= 5:
            break
    if not puntos:
        resumen = _propuesta_resumen(solicitud)
        if resumen:
            puntos.append(_clip(resumen, 220))
    return puntos


def _titulo_ventana(solicitud: dict, control: dict, ctx: dict) -> str:
    return (
        (control.get("nombre") or "").strip()
        or ((solicitud.get("proyecto") or {}).get("modulo") or "").strip()
        or ((solicitud.get("contenido") or {}).get("titulo") or "").strip()
        or (ctx.get("titulo") or "").strip()
        or "Pantalla propuesta"
    )


def _crumb_html(solicitud: dict, control: dict) -> str:
    proy = solicitud.get("proyecto") or {}
    partes = ["Inicio"]
    area = (proy.get("area") or "").split("·")[0].strip()
    modulo = (proy.get("modulo") or "").split("·")[0].strip()
    if area:
        partes.append(area.title() if area.isupper() else area)
    if modulo:
        partes.append(modulo)
    if control.get("nombre"):
        partes.append(str(control["nombre"]))
    html_parts = []
    for i, p in enumerate(partes):
        if i == len(partes) - 1:
            html_parts.append(f"<b>{_esc(p)}</b>")
        else:
            html_parts.append(_esc(p))
    return " &gt; ".join(html_parts)


def _styles_qrystalos_admin() -> str:
    return """
    :root {
      --q-primary: #673ab7; --q-primary-dark: #512da8; --accent: #E67817;
      --bg: #f5f5f5; --border: rgba(0,0,0,.12); --text: #263238; --muted: #607d8b;
      --new-bg: #fff3e0; --new-border: #ffb74d;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Roboto, "Segoe UI", sans-serif; font-size: 13px; color: var(--text); background: var(--bg); }
    .mock-banner { background: #263238; color: #fff; padding: .45rem .75rem; font-size: .72rem; display: flex; gap: .75rem; flex-wrap: wrap; align-items: center; }
    .mock-banner strong { color: #ffcc80; }
    .app-top { background: var(--q-primary); color: #fff; padding: .4rem .75rem; font-size: .78rem; display: flex; justify-content: space-between; }
    .app-top .ver { opacity: .85; font-size: .68rem; }
    .crumb { background: #fff; border-bottom: 1px solid var(--border); padding: .35rem .75rem; font-size: .72rem; color: var(--muted); }
    .crumb b { color: var(--text); }
    .page-title { background: #fff; padding: .5rem .75rem; font-size: 1rem; font-weight: 500; border-bottom: 1px solid var(--border); }
    .filters { background: #fff; padding: .55rem .75rem; display: flex; flex-wrap: wrap; gap: .45rem .65rem; align-items: flex-end; border-bottom: 1px solid var(--border); }
    .field { display: flex; flex-direction: column; gap: .15rem; }
    .field label { font-size: .65rem; color: var(--muted); text-transform: uppercase; letter-spacing: .03em; }
    .field input, .field select { border: 1px solid var(--border); border-radius: 3px; padding: .28rem .4rem; font-size: .75rem; min-width: 7rem; }
    .field.sm input { min-width: 5.5rem; }
    .toolbar-new { background: var(--new-bg); border: 2px solid var(--new-border); margin: .55rem .75rem 0; padding: .45rem .65rem; border-radius: 4px; display: flex; flex-wrap: wrap; gap: .4rem; align-items: center; }
    .toolbar-new .tag { font-size: .62rem; font-weight: 700; color: #e65100; text-transform: uppercase; margin-right: .35rem; }
    .q-btn { border: none; border-radius: 3px; padding: .35rem .7rem; font-size: .72rem; font-weight: 500; text-transform: uppercase; cursor: default; }
    .q-btn--p { background: var(--q-primary); color: #fff; }
    .q-btn--a { background: var(--accent); color: #fff; }
    .q-btn--o { background: #fff; border: 1px solid var(--border); color: var(--text); }
    .table-wrap { background: #fff; margin: .55rem .75rem .75rem; border: 1px solid var(--border); overflow-x: auto; }
    table.data { width: 100%; border-collapse: collapse; font-size: .72rem; min-width: 960px; }
    table.data th { background: #fafafa; border-bottom: 1px solid var(--border); padding: .35rem .4rem; text-align: left; font-weight: 500; white-space: nowrap; }
    table.data td { padding: .32rem .4rem; border-bottom: 1px solid #eee; vertical-align: middle; }
    table.data tr.sel td { background: #f3e5f5; }
    .chk { width: 16px; height: 16px; accent-color: var(--q-primary); }
    .ico { display: inline-flex; gap: .2rem; }
    .ico span { width: 22px; height: 22px; border-radius: 3px; display: inline-flex; align-items: center; justify-content: center; font-size: .65rem; color: #fff; }
    .ico .lock { background: #43a047; } .ico .edit { background: #1e88e5; } .ico .send { background: #fb8c00; }
    .badge-new { font-size: .58rem; background: var(--accent); color: #fff; padding: .08rem .3rem; border-radius: 2px; margin-left: .25rem; vertical-align: middle; }
    .split-cap { display: grid; grid-template-columns: 1fr 1fr; gap: .65rem; padding: .65rem .75rem; }
    @media (max-width: 900px) { .split-cap { grid-template-columns: 1fr; } }
    .cap-box { background: #fff; border: 1px solid var(--border); border-radius: 4px; overflow: hidden; }
    .cap-box h3 { font-size: .72rem; padding: .35rem .5rem; background: #fafafa; border-bottom: 1px solid var(--border); }
    .cap-box img { width: 100%; display: block; }
    .cap-box.prop { border-color: var(--new-border); }
    .foot { text-align: center; font-size: .65rem; color: var(--muted); padding: .75rem; }
    .scene { position: relative; min-height: 520px; background: #e0e0e0; margin: .65rem .75rem; border-radius: 4px; overflow: hidden; }
    .scene-back { filter: blur(1px) brightness(.92); opacity: .55; pointer-events: none; padding: .5rem; }
    .scene-back .table-wrap { margin: 0; }
    .dialog-overlay { position: absolute; inset: 0; display: flex; align-items: flex-start; justify-content: center; padding: 1.25rem .75rem; background: rgba(0,0,0,.35); overflow-y: auto; }
    .q-card { background: #fff; width: min(920px, 96%); border-radius: 4px; box-shadow: 0 8px 24px rgba(0,0,0,.25); }
    .q-bar { background: var(--q-primary); color: #fff; padding: .45rem .65rem; display: flex; align-items: center; gap: .45rem; font-size: .85rem; }
    .q-bar .title { font-weight: 500; flex: 1; }
    .q-section { padding: .65rem .75rem .75rem; }
    .q-row { display: flex; flex-wrap: wrap; gap: .45rem; margin-bottom: .45rem; }
    .q-field { display: flex; flex-direction: column; gap: .12rem; flex: 1; min-width: 140px; }
    .q-field label { font-size: .68rem; color: var(--muted); }
    .q-field input, .q-field textarea, .q-field select { border: 1px solid #ccc; border-radius: 3px; padding: .35rem .45rem; font-size: .78rem; font-family: inherit; }
    .q-field textarea { min-height: 2.2rem; resize: vertical; }
    .q-field.col2 { flex: 0 0 calc(16% - .4rem); min-width: 100px; }
    .q-field.col3 { flex: 0 0 calc(25% - .4rem); }
    .q-field.col8 { flex: 0 0 calc(66% - .4rem); }
    .q-field.col10 { flex: 0 0 calc(83% - .4rem); }
    .q-field.col12 { flex: 0 0 100%; }
    .q-field.new-block { background: var(--new-bg); border: 2px solid var(--new-border); border-radius: 4px; padding: .45rem; }
    .q-field.new-block label { color: #e65100; font-weight: 600; }
    .btn-search { align-self: flex-end; margin-bottom: .15rem; padding: .35rem .5rem; border: 1px solid var(--border); background: #fafafa; border-radius: 3px; color: var(--q-primary); }
    .q-actions { padding: .45rem .75rem .65rem; display: flex; justify-content: flex-end; gap: .45rem; border-top: 1px solid var(--border); }
    .btn-save { background: #21ba45; color: #fff; padding: .4rem .85rem; border: none; border-radius: 3px; font-size: .78rem; }
    .btn-cancel { background: #c10015; color: #fff; padding: .4rem .85rem; border: none; border-radius: 3px; font-size: .78rem; }
    .batch-pill { background: #fff3e0; color: #e65100; font-size: .68rem; padding: .2rem .45rem; border-radius: 3px; margin-left: .35rem; }
    .brief-prop { background: #fff8e1; border-bottom: 2px solid #ffb74d; padding: .5rem .75rem; font-size: .78rem; }
    .brief-prop .lbl { font-size: .62rem; font-weight: 700; color: #e65100; text-transform: uppercase; letter-spacing: .04em; }
    .aviso-falta { background: #ffebee; color: #b71c1c; padding: .55rem .75rem; font-size: .75rem; border-bottom: 1px solid #ef9a9a; }
    .alert-block { background: #ffebee; border: 1px solid #ef9a9a; color: #c62828; font-size: .72rem; padding: .4rem .6rem; border-radius: 4px; margin: .55rem .75rem 0; }
    .field.nuevo input, .field.nuevo select { border: 2px solid var(--new-border); background: var(--new-bg); font-weight: 700; color: #e65100; }
    .q-btn--off { background: #b0bec5; color: #fff; opacity: .9; }
    .hoy-ref { margin: .65rem .75rem; background: #fff; border: 1px dashed var(--border); border-radius: 4px; overflow: hidden; }
    .hoy-ref h3 { font-size: .68rem; padding: .3rem .5rem; background: #fafafa; color: var(--muted); }
    .hoy-ref img { max-height: 140px; width: auto; max-width: 100%; display: block; margin: 0 auto; }
    .callouts { margin: .45rem .75rem .75rem; padding: .45rem .6rem; background: #fff; border: 1px solid var(--border); border-radius: 4px; }
    .callouts h3 { font-size: .68rem; color: #e65100; margin-bottom: .25rem; }
    .callouts li { font-size: .7rem; margin: .15rem 0 .15rem 1rem; }
    .prop-legend { font-size: .65rem; color: var(--muted); padding: .35rem .75rem .85rem; line-height: 1.4; }
    .prop-legend strong { color: #e65100; }
    .td-off { color: #90a4ae; }
    """


def _fevrips_styles_extra() -> str:
    return """
    .ftr-envios-bar { display:flex; flex-wrap:wrap; align-items:center; gap:.35rem .5rem; padding:.45rem .55rem; background:#fafafa; border-bottom:1px solid var(--border); font-size:.72rem; }
    .ftr-envios-chip { display:inline-flex; align-items:center; gap:.25rem; border:1px solid #d1c4e9; background:#fff; border-radius:3px; padding:.2rem .45rem; }
    .ftr-envios-chip__k { color:var(--muted); font-size:.62rem; text-transform:uppercase; }
    .ftr-envios-chip__v { font-weight:600; color:var(--q-primary); }
    .ftr-envios-meta { margin-right:.65rem; }
    .ftr-envios-meta__k { color:var(--muted); font-size:.62rem; margin-right:.2rem; }
    .tab-group { display:flex; gap:.15rem; padding:.45rem .55rem .35rem; flex-wrap:wrap; }
    .tab-btn { border:1px solid var(--border); background:#fff; padding:.28rem .55rem; font-size:.72rem; border-radius:3px; cursor:default; }
    .tab-btn--on { background:var(--q-primary); color:#fff; border-color:var(--q-primary); }
    .fev-body { padding:.45rem .55rem .55rem; background:#fff; }
    .fev-cred { border:1px solid var(--border); border-radius:3px; padding:.35rem .45rem; margin-bottom:.45rem; font-size:.7rem; color:var(--muted); }
    .fev-actions { display:flex; flex-wrap:wrap; gap:.35rem; margin-bottom:.35rem; }
    .fev-btn { border:1px solid var(--border); background:#fff; padding:.28rem .5rem; font-size:.68rem; border-radius:3px; }
    .fev-btn--ext { border-color:#546e7a; color:#37474f; font-weight:600; box-shadow:0 0 0 2px #ffb74d; }
    .q-dialog-sm { width:min(520px,96%); max-width:520px; }
    .q-dialog-sm .text-h6 { font-size:1.05rem; font-weight:500; margin-bottom:.25rem; }
    .caption { font-size:.72rem; color:#546e7a; line-height:1.35; }
    .q-file { border:1px solid #ccc; border-radius:3px; padding:.35rem .45rem; font-size:.78rem; background:#fafafa; }
    .q-file.ok { border-color:#43a047; background:#f1f8e9; }
    .q-file.new-block { background:var(--new-bg); border:2px solid var(--new-border); }
    .success-toast { background:#e8f5e9; border:1px solid #a5d6a7; color:#2e7d32; padding:.45rem .55rem; border-radius:4px; font-size:.75rem; margin:.45rem .55rem 0; display:flex; align-items:center; gap:.35rem; }
    .q-actions-fe { background:#eceff1; }
    .btn-registrar { background:var(--q-primary); color:#fff; padding:.35rem .75rem; border:none; border-radius:3px; font-size:.78rem; }
    .btn-flat { background:transparent; color:#546e7a; padding:.35rem .65rem; border:none; font-size:.78rem; }
    """


def _fevrips_envios_back_html() -> str:
    return """
  <div class="scene-back">
    <div class="q-card" style="margin:0;box-shadow:none">
      <div class="q-bar"><span class="title">Envíos y Respuestas</span><span>×</span></div>
      <div class="ftr-envios-bar">
        <span class="ftr-envios-chip"><span class="ftr-envios-chip__k">Factura</span><span class="ftr-envios-chip__v">FEV327665</span></span>
        <span class="ftr-envios-chip"><span class="ftr-envios-chip__k">CNS</span><span class="ftr-envios-chip__v">0101223197</span></span>
        <span class="ftr-envios-meta"><span class="ftr-envios-meta__k">Fecha</span>19/06/2026</span>
        <span class="ftr-envios-meta"><span class="ftr-envios-meta__k">Proc.</span>FINANCIERO</span>
        <span class="ftr-envios-meta"><span class="ftr-envios-meta__k">Estado</span>P</span>
      </div>
      <div class="tab-group">
        <button type="button" class="tab-btn">Respuestas DIAN</button>
        <button type="button" class="tab-btn tab-btn--on">FEV RIPS</button>
        <button type="button" class="tab-btn">Conf. async</button>
      </div>
      <div class="fev-body">
        <div class="fev-cred">Credenciales SISPRO · NIT 839000356 · Documento 17901144 · API configurada</div>
        <div class="fev-actions">
          <span class="fev-btn">Validar Ahora</span>
          <span class="fev-btn fev-btn--ext">Validación externa</span>
          <span class="fev-btn">Subir JSON y Validar</span>
        </div>
      </div>
    </div>
  </div>"""


def _fevrips_dialog_externa_html() -> str:
    return """
      <div class="q-card q-dialog-sm" role="dialog" aria-label="Validación externa FEV RIPS">
        <div class="q-section">
          <div class="text-h6">Registrar validación FEV RIPS externa</div>
          <p class="caption q-mt-xs">
            Misma ventana que <code>ValidacionesFEVRipsComponent.vue</code>. Tras el desarrollo, archivos
            .txt/.json del ministerio se normalizan antes de <strong>RIPS · SET_DATOS</strong>
            (tokens NULL/NaN, BOM, respuesta solo-CUV).
          </p>
          <div class="q-field col12 new-block q-mt-md">
            <label>Ayuda al usuario <span class="badge-new">propuesto</span></label>
            <p class="caption" style="margin:0">
              Si el export del validador externo no es JSON estándar, el sistema intentará corregirlo o mostrará
              un mensaje claro en pantalla (sin error SQL genérico).
            </p>
          </div>
          <div class="column q-gutter-md" style="margin-top:.65rem;display:flex;flex-direction:column;gap:.55rem">
            <div class="q-file ok">JSON de envío · envio_ministerio.txt <span style="color:#2e7d32;font-size:.68rem">✓ listo</span></div>
            <div class="q-file ok">Respuesta (.json o .txt) · respuesta_sispro.txt <span style="color:#2e7d32;font-size:.68rem">✓ CUV detectado</span></div>
          </div>
          <div class="success-toast"><span>✓</span> Validación externa registrada correctamente — CUV persistido en FTR/FTRJSON</div>
        </div>
        <div class="q-actions q-actions-fe">
          <button type="button" class="btn-flat">Cancelar</button>
          <button type="button" class="btn-registrar">Registrar</button>
        </div>
      </div>"""


def render_mockup_fevrips_validacion_externa(ctx: dict, solicitud: dict, control: dict) -> str:
    ident = solicitud.get("identificacion") or {}
    contenido = solicitud.get("contenido") or {}
    ruta = _ruta_pantalla(solicitud, control) or "/admin/facturacion"
    captura = _captura_url(solicitud)
    req = ident.get("idReq") or "—"
    caso = ident.get("idCaso") or ""
    rama = ((solicitud.get("gestion") or {}).get("rama") or "").strip()
    prop_text = _esc(_clip(contenido.get("cambioPropuestoSimple") or "", 320))
    cap_hoy = (
        f'<img src="{_esc(captura)}" alt="Captura Validación externa (referencia)">'
        if captura
        else "<p style='padding:1rem;color:#888'>Sin captura en imagenesAnalisis</p>"
    )
    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mockup — Envíos y Respuestas · Validación externa</title>
  <style>{_styles_qrystalos_admin()}{_fevrips_styles_extra()}</style>
</head>
<body>
  <div class="mock-banner">
    <span><strong>Mockup UX — propuesto</strong> · REQ {_esc(req)} · <code>{_esc(ruta)}</code></span>
    <span>caso {_esc(caso)}{f' · Rama <code>{_esc(rama)}</code>' if rama else ''} · réplica Qrystalos2 (FTR → Envíos y Respuestas → FEV RIPS)</span>
  </div>

  <div class="split-cap">
    <div class="cap-box">
      <h3>Hoy — referencia del problema (no es el entregable)</h3>
      {cap_hoy}
    </div>
    <div class="cap-box prop">
      <h3>Propuesto — mismo flujo, registro exitoso tras normalizar archivos del ministerio</h3>
      <p style="padding:.45rem .5rem;font-size:.72rem;color:#555">{prop_text}</p>
    </div>
  </div>

  <div class="app-top">
    <span>Qrystalos Administrativo <span class="ver">v2.0.2</span></span>
    <span class="ver">Facturación → Envíos y Respuestas</span>
  </div>
  <div class="crumb">Inicio &gt; Financiero &gt; FTR &gt; <b>Facturación</b></div>

  <div class="scene" style="min-height:620px">
    {_fevrips_envios_back_html()}
    <div class="dialog-overlay">
      {_fevrips_dialog_externa_html()}
    </div>
  </div>
  <p class="foot">Generado {_esc(ctx.get("generadoEn") or "")} · ValidacionesFEVRipsComponent.vue · diálogo Validación externa</p>
</body>
</html>"""


def _fcxcr_grilla_atenuada_html() -> str:
    return """
  <div class="scene-back">
    <div class="page-title" style="font-size:1rem;margin:0 0 .35rem">Devoluciones</div>
    <div class="table-wrap">
      <table class="data">
        <thead><tr>
          <th><input type="checkbox" class="chk" checked disabled></th><th></th>
          <th>CnsCxc</th><th>No. Factura</th><th>Valor</th><th>Estado</th>
        </tr></thead>
        <tbody>
          <tr class="sel"><td><input type="checkbox" class="chk" checked disabled></td><td>✎</td>
            <td>0100000005</td><td>CKEN202</td><td>$ 881.347</td><td></td></tr>
          <tr class="sel"><td><input type="checkbox" class="chk" checked disabled></td><td>✎</td>
            <td>0100000006</td><td>CKEN203</td><td>$ 120.000</td><td></td></tr>
        </tbody>
      </table>
    </div>
  </div>"""


def _fcxcr_dialog_form_html(mode: str) -> str:
    """Réplica del q-dialog dgFCXCR (Definir / Enviar respuesta). Resaltado = cambio REQ."""
    motivos_new = """
        <div class="q-row">
          <div class="q-field col3 new-block">
            <label>Motivo 1 <span class="badge-new">nuevo</span></label>
            <input type="text" value="01" placeholder="Código">
          </div>
          <div class="q-field col8 new-block">
            <label>Descripción motivo 1</label>
            <input type="text" value="Factura no corresponde al paciente" readonly>
          </div>
          <button type="button" class="btn-search" title="Buscador FCGLO DEVOLUCION">🔍</button>
        </div>
        <div class="q-row">
          <div class="q-field col3 new-block">
            <label>Motivo 2 <span class="badge-new">nuevo</span></label>
            <input type="text" value="" placeholder="Opcional">
          </div>
          <div class="q-field col8 new-block">
            <label>Descripción motivo 2</label>
            <input type="text" value="" placeholder="Catálogo DEVOLUCION">
          </div>
          <button type="button" class="btn-search">🔍</button>
        </div>"""
    batch_banner = ""
    batch_pill = ""
    dialog_title = "Definir respuesta — devolución"
    if mode == "masivo":
        batch_banner = """
        <div class="toolbar-new" style="margin:0 0 .55rem;border-radius:4px">
          <span class="tag">Lote</span>
          <span style="font-size:.75rem">Misma respuesta para <strong>3</strong> filas seleccionadas en la grilla (icono ✎ o acción masiva).</span>
        </div>"""
        dialog_title = "Definir respuesta — devoluciones seleccionadas"
        batch_pill = '<span class="batch-pill">3 seleccionadas</span>'

    return f"""
      <div class="q-card" role="dialog" aria-label="dgFCXCR">
        <div class="q-bar">
          <span class="title">{dialog_title}</span>
          {batch_pill}
          <span style="opacity:.85;font-size:1rem;line-height:1">×</span>
        </div>
        <div class="q-section">
          {batch_banner}
          <div class="q-row">
            <div class="q-field col2"><label>Consecutivo CXC</label><input type="text" value="0100000005" readonly></div>
            <div class="q-field col3"><label>N° Factura</label><input type="text" value="CKEN202" readonly></div>
            <div class="q-field col3"><label>Valor</label><input type="text" value="$ 881.347" readonly></div>
          </div>
          {motivos_new}
          <div class="q-row">
            <div class="q-field col3"><label>Código de respuesta</label><input type="text" value="01"></div>
            <div class="q-field col8"><label>Respuesta</label><input type="text" value="Se corrige y reenvía"></div>
            <button type="button" class="btn-search">🔍</button>
          </div>
          <div class="q-row">
            <div class="q-field col12"><label>Detalle respuesta</label><textarea>Observación al pagador…</textarea></div>
          </div>
          <div class="q-row">
            <div class="q-field col6"><label>Paso a seguir</label>
              <select><option selected>Soportar</option><option>Anular</option></select>
            </div>
          </div>
          <p style="font-size:.68rem;color:#888;margin:.35rem 0 0">Formulario real: <code>FCXCRComponent.vue</code> · diálogo <code>dgFCXCR</code> (no la q-table).</p>
        </div>
        <div class="q-actions">
          <button type="button" class="btn-cancel">Cancelar</button>
          <button type="button" class="btn-save">Guardar</button>
        </div>
      </div>"""


def render_mockup_fcxcr_dialog(ctx: dict, solicitud: dict, control: dict, mode: str) -> str:
    ident = solicitud.get("identificacion") or {}
    contenido = solicitud.get("contenido") or {}
    ruta = _ruta_pantalla(solicitud, control)
    captura_form = _captura_formulario_url(solicitud)
    req = ident.get("idReq") or "—"
    caso = ident.get("idCaso") or ""
    ctrl_nombre = control.get("nombre") or "Respuesta Devoluciones"

    cap_hoy = (
        f'<img src="{_esc(captura_form)}" alt="Formulario respuesta (captura REQ)">'
        if captura_form
        else "<p style='padding:1rem;color:#888'>Sin captura del formulario en imagenesAnalisis</p>"
    )
    if mode == "motivos":
        prop_titulo = "Propuesto — formulario dgFCXCR (Motivo 1 / Motivo 2 editables + buscador)"
    else:
        prop_titulo = "Propuesto — mismo formulario dgFCXCR aplicado a lote desde selección en grilla"

    prop_text = _esc(_clip(contenido.get("cambioPropuestoSimple") or "", 320))
    back = _fcxcr_grilla_atenuada_html() if mode == "masivo" else ""
    scene_min = "680px" if mode == "masivo" else "560px"
    excel_bar = ""
    if mode == "masivo":
        excel_bar = """
  <div class="toolbar-new" style="margin:.55rem .75rem .25rem">
    <span class="tag">Complemento</span>
    <button type="button" class="q-btn q-btn--o">Descargar plantilla Excel</button>
    <button type="button" class="q-btn q-btn--a">Subir respuestas</button>
    <span style="font-size:.68rem;color:#555">Misma lógica del formulario dgFCXCR; la grilla masiva abre el diálogo arriba.</span>
  </div>"""

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mockup — {_esc(ctrl_nombre)} (formulario)</title>
  <style>{_styles_qrystalos_admin()}</style>
</head>
<body>
  <div class="mock-banner">
    <span><strong>Mockup UX — propuesto</strong> (alineado al desarrollo, no a la captura del error) · REQ {_esc(req)}</span>
    <span><code>{_esc(ruta)}</code> · caso {_esc(caso)} · control <code>{_esc(control.get("id") or "respuesta-devoluciones")}</code></span>
  </div>

  <div class="split-cap">
    <div class="cap-box">
      <h3>Hoy — referencia del problema (no es el mockup)</h3>
      {cap_hoy}
    </div>
    <div class="cap-box prop">
      <h3>{_esc(prop_titulo)}</h3>
      <p style="padding:.45rem .5rem;font-size:.72rem;color:#555">{prop_text}</p>
    </div>
  </div>

  <div class="app-top">
    <span>Qrystalos Administrativo <span class="ver">v2.0.2</span></span>
    <span class="ver">Administrativo → Respuesta Devoluciones</span>
  </div>
  <div class="crumb">Inicio &gt; <b>Administrativo</b> &gt; <b>Respuesta Devoluciones</b></div>

  <div class="scene" style="min-height:{scene_min}">
    {back}
    <div class="dialog-overlay">
      {_fcxcr_dialog_form_html(mode)}
    </div>
  </div>
  {excel_bar}
  <p class="foot">Generado {_esc(ctx.get("generadoEn") or "")} · mockup centrado en dgFCXCR · grilla solo como contexto{" (atenuada)" if mode == "masivo" else ""}</p>
</body>
</html>"""


def render_mockup_ux_generic(ctx: dict, solicitud: dict, control: dict) -> str:
    ident = solicitud.get("identificacion") or {}
    contenido = solicitud.get("contenido") or {}
    notas = (ctx.get("notas") or contenido.get("mockupsNotas") or "")
    ruta = _ruta_pantalla(solicitud, control)
    captura = _captura_url(solicitud)
    acciones = _acciones_propuestas(solicitud, notas)
    filtros = _filtros_propuestos(solicitud, notas)
    alerta = _alerta_propuesta(solicitud, notas)
    cols = _columnas_grilla(solicitud, notas)
    puntos = _puntos_cambio(solicitud)
    hay_prop = _tiene_propuesta(solicitud, ctx)
    resumen = _propuesta_resumen(solicitud, ctx)
    req = ident.get("idReq") or "—"
    caso = ident.get("idCaso") or ""
    titulo = _titulo_ventana(solicitud, control, ctx)
    crumb = _crumb_html(solicitud, control)
    rama = ((solicitud.get("gestion") or {}).get("rama") or "").strip()

    def _cls_btn(a: dict) -> str:
        if a.get("disabled"):
            return "q-btn q-btn--off"
        if a["tipo"] == "primary":
            return "q-btn q-btn--p"
        if a["tipo"] == "accent":
            return "q-btn q-btn--a"
        return "q-btn q-btn--o"

    btns = "".join(
        f'<button type="button" class="{_cls_btn(a)}"{" disabled" if a.get("disabled") else ""}>'
        f'{_esc(a["label"])}<span class="badge-new">{"bloqueado" if a.get("disabled") else "nuevo"}</span></button>'
        for a in acciones
    )
    filtros_html = "".join(
        f'<div class="field{" nuevo" if f.get("nuevo") else ""}">'
        f'<label>{_esc(f["label"])}{" <span class=badge-new>nuevo</span>" if f.get("nuevo") else ""}</label>'
        f'<input type="text" value="{_esc(f.get("value") or "")}" readonly>'
        f"</div>"
        for f in filtros
    )
    ths = "".join(f"<th>{_esc(c)}</th>" for c in cols)
    sample_a = []
    sample_b = []
    for i, c in enumerate(cols):
        if c.lower() in ("id sede", "sede"):
            sample_a.append("<td><strong>34</strong></td>")
            sample_b.append("<td><strong>12</strong></td>")
        elif "estado" in c.lower():
            sample_a.append("<td>Listo</td>")
            sample_b.append("<td>Listo</td>")
        else:
            sample_a.append(f"<td>Ejemplo {i + 1}A</td>")
            sample_b.append(f"<td>Ejemplo {i + 1}B</td>")
    if alerta:
        last = '<td class="td-off">No disponible</td>'
        ths += "<th>Acción</th>"
        sample_a.append(last)
        sample_b.append(last)
    alerta_html = f'<div class="alert-block" role="status">{_esc(alerta)}</div>' if alerta else ""
    toolbar = (
        f'<div class="toolbar-new"><span class="tag">Propuesto</span>{btns}</div>'
        if btns
        else ""
    )
    aviso = ""
    if not hay_prop:
        aviso = (
            '<div class="aviso-falta">Falta la propuesta de desarrollo '
            "(<code>cambioPropuestoSimple</code>, recomendación o criterios). "
            "Este mockup no copia la captura del problema. Complete el análisis y pulse "
            "<strong>Generar mockups</strong> de nuevo.</div>"
        )
    brief = (
        f'<div class="brief-prop"><div class="lbl">Qué se desarrolla</div>'
        f"{_esc(_clip(resumen, 420)) or 'Complete la propuesta en el formulario.'}</div>"
    )
    hoy_ref = ""
    if captura:
        hoy_ref = (
            f'<div class="hoy-ref"><h3>Hoy — referencia del problema (no es el entregable)</h3>'
            f'<img src="{_esc(captura)}" alt="Captura del estado actual"></div>'
        )
    callouts = ""
    if puntos:
        lis = "".join(f"<li>{_esc(p)}</li>" for p in puntos)
        callouts = (
            f'<div class="callouts"><h3>Criterios visibles en esta ventana</h3>'
            f"<ol>{lis}</ol></div>"
        )
    ruta_txt = f"<code>{_esc(ruta)}</code>" if ruta else "ruta del control"
    rama_txt = f" · Rama <code>{_esc(rama)}</code>" if rama else ""

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mockup propuesto — {_esc(titulo)}</title>
  <style>{_styles_qrystalos_admin()}</style>
</head>
<body>
  <div class="mock-banner">
    <span><strong>Mockup UX — propuesto</strong> · REQ {_esc(req)} · {ruta_txt}{rama_txt}</span>
    <span>caso {_esc(caso)} · alineado a la propuesta de desarrollo, no a la captura del error</span>
  </div>
  {aviso}
  {brief}

  <div class="app-top">
    <span>Qrystalos Administrativo <span class="ver">v2.0.2</span></span>
    <span class="ver">{_esc(titulo)}</span>
  </div>
  <div class="crumb">{crumb}</div>
  <div class="page-title">{_esc(titulo)}</div>
  <div class="filters">{filtros_html}</div>
  {alerta_html}
  {toolbar}
  <div class="table-wrap">
    <table class="data">
      <thead><tr>{ths}</tr></thead>
      <tbody>
        <tr>{''.join(sample_a)}</tr>
        <tr>{''.join(sample_b)}</tr>
      </tbody>
    </table>
  </div>
  {callouts}
  {hoy_ref}
  <p class="prop-legend"><strong>Cambio vs hoy:</strong> {_esc(_clip(resumen or "La ventana de arriba es el resultado del desarrollo, no el error reportado.", 360))}</p>
  <p class="foot">Generado {_esc(ctx.get("generadoEn") or "")} · mockup_generar.py · propuesta, no captura del problema</p>
</body>
</html>"""


def _raiz_qrystalos2() -> str:
    ruta = os.path.join(ROOT, "config", "rutas.json")
    try:
        import json

        with open(ruta, encoding="utf-8") as fh:
            return str(json.load(fh).get("qrystalos2") or "").strip()
    except (OSError, ValueError):
        return ""


def _nombres_vue(texto: str) -> list[str]:
    return re.findall(r"\b([A-Z][A-Za-z0-9]+(?:Page|Component))\b", texto or "")


def _elegir_ventana(proceso: dict, solicitud: dict) -> dict:
    ventanas = [v for v in (proceso.get("ventanas") or []) if isinstance(v, dict)]
    if not ventanas:
        return {}
    ruta = _ruta_pantalla(solicitud, {}).lower()
    consulta = _tokens(
        " ".join(
            (
                _textos_propuesta(solicitud),
                ((solicitud.get("contenido") or {}).get("titulo") or ""),
                ruta,
            )
        )
    )
    mejor = ventanas[0]
    mejor_pts = -1
    for ventana in ventanas:
        blob = " ".join(str(ventana.get(k) or "") for k in ("uso", "ruta", "path", "vue", "entrada"))
        pts = len(consulta & _tokens(blob))
        path = str(ventana.get("path") or "").lower()
        if path and path in ruta:
            pts += 8
        if pts > mejor_pts:
            mejor = ventana
            mejor_pts = pts
    return mejor


def _pistas_ruta(texto: str) -> list[str]:
    return re.findall(
        r"((?:pages|components|layouts)/[\w./-]+\.vue)",
        texto or "",
        flags=re.I,
    )


def _resolver_vue(texto: str) -> str:
    """Usa la ruta del proceso (components/inv/izsol/…) y no el primer IndexComponent del árbol."""
    src = os.path.join(_raiz_qrystalos2(), "src")
    if not os.path.isdir(src):
        return ""
    for pista in reversed(_pistas_ruta(texto)):
        candidato = os.path.normpath(os.path.join(src, *pista.replace("\\", "/").split("/")))
        if os.path.isfile(candidato):
            return candidato
    nombres = _nombres_vue(texto)
    if not nombres:
        return ""
    segmentos = []
    for pista in _pistas_ruta(texto):
        segmentos.extend(
            p.lower() for p in pista.split("/") if p and not p.lower().endswith(".vue")
        )
    hallados = []
    for carpeta, dirs, archivos in os.walk(src):
        dirs[:] = [d for d in dirs if d not in ("node_modules", "dist", ".git")]
        for nombre in nombres:
            if f"{nombre}.vue" in archivos:
                hallados.append(os.path.join(carpeta, f"{nombre}.vue"))
    if not hallados:
        return ""

    def _puntaje(full: str) -> int:
        rel = "/" + full.replace("\\", "/").lower() + "/"
        pts = 0
        for seg in segmentos:
            if f"/{seg}/" in rel:
                pts += 5
        base = os.path.splitext(os.path.basename(full))[0]
        if base == nombres[-1]:
            pts += 2
        return pts

    return max(hallados, key=_puntaje)


def _archivo_vue(nombres: list[str]) -> str:
    return _resolver_vue(" ".join(nombres or []))


def _columnas_script(path: str) -> list[str]:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
    except OSError:
        return []
    marca = re.search(r"const columns = computed\(\(\) => \{", texto)
    if not marca:
        marca = re.search(r"\bcolumns\s*=\s*\[", texto)
    if not marca:
        return []
    trozo = texto[marca.start() : marca.start() + 9000]
    trozo = re.sub(r"/\*.*?\*/", "", trozo, flags=re.S)
    corte = re.search(r"\nconst \w+", trozo[80:])
    if corte:
        trozo = trozo[: 80 + corte.start()]
    salida = []
    for lab in re.findall(r"label:\s*[\"']([^\"']{2,32})[\"']", trozo):
        limpio = re.sub(r"\s+", " ", lab).strip()
        if limpio and limpio not in salida:
            salida.append(limpio)
        if len(salida) >= 8:
            break
    return salida


def _menus_contextuales(plantilla: str) -> list[list[str]]:
    menus = []
    for bloque_m in re.finditer(
        r"<q-menu\b[^>]*\bcontext-menu\b[^>]*>(.*?)</q-menu>",
        plantilla or "",
        re.S | re.I,
    ):
        bloque = bloque_m.group(1)
        items = []
        for lab in re.findall(r"<q-item-label\b[^>]*>(.*?)</q-item-label>", bloque, re.S | re.I):
            citas = re.findall(r'["\']([A-Za-zÁÉÍÓÚáéíóúñÑ][^"\']{2,42})["\']', lab)
            plano = re.sub(r"<[^>]+>", " ", lab)
            plano = re.sub(r"\{\{.*?\}\}", " ", plano, flags=re.S)
            plano = re.sub(r"\s+", " ", plano).strip(" :")
            texto = ""
            if plano and "?" not in plano and len(plano) <= 42:
                texto = plano
            elif citas:
                texto = citas[0].strip()
            if ":" in texto:
                continue
            texto = re.sub(r"\s+", " ", texto.replace("&nbsp;", " ")).strip()
            if texto and texto not in items:
                items.append(texto)
        if len(items) >= 2:
            menus.append(items)
    return menus


def _elegir_menu(menus: list[list[str]], blob: str) -> list[str]:
    tokens = {t for t in _tokens(blob) if len(t) >= 5}
    mejor: list[str] = []
    mejor_pts = 0
    for items in menus:
        pts = sum(len(tokens & _tokens(item)) for item in items)
        if pts > mejor_pts:
            mejor = items
            mejor_pts = pts
    return mejor if mejor_pts else []


def _trozo_plantilla(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            texto = fh.read(350000)
    except OSError:
        return ""
    inicio = texto.find("<template")
    if inicio < 0:
        return ""
    abre = texto.find(">", inicio)
    fin = texto.rfind("</template>")
    if abre < 0 or fin <= abre:
        return ""
    return texto[abre + 1 : fin]


def _etiquetas(fragmento: str, tope: int) -> list[str]:
    salida = []
    for m in re.finditer(r'\blabel="([^"{][^"]{1,42})"', fragmento or ""):
        etiqueta = re.sub(r"\s+", " ", m.group(1)).strip()
        if not etiqueta or etiqueta.lower() in ("filtros", "true", "false"):
            continue
        if re.fullmatch(r"[A-Z0-9_]{5,}", etiqueta):
            continue
        if etiqueta not in salida:
            salida.append(etiqueta)
        if len(salida) >= tope:
            break
    return salida


def _botones_vue(plantilla: str) -> list[str]:
    salida = []
    for m in re.finditer(r"<q-btn\b([^>]*)>", plantilla or "", re.I):
        attrs = m.group(1) or ""
        if re.search(r"""v-if\s*=\s*['"]false['"]""", attrs):
            continue
        hallado = re.search(r'\blabel="([^"{][^"]{1,42})"', attrs)
        if not hallado:
            continue
        lab = re.sub(r"\s+", " ", hallado.group(1)).strip()
        if not lab or lab in salida or re.fullmatch(r"[A-Z0-9_]{5,}", lab):
            continue
        salida.append(lab)
        if len(salida) >= 8:
            break
    return salida


def _pestanas_vue(plantilla: str) -> list[str]:
    halladas = re.findall(r'<q-(?:route-)?tab\b[^>]*\blabel="([^"]{2,40})"', plantilla or "", re.I)
    salida = []
    for etiqueta in halladas:
        limpia = etiqueta.strip()
        if limpia and limpia not in salida:
            salida.append(limpia)
        if len(salida) >= 8:
            break
    return salida


def render_mockup_emulado(ctx: dict, solicitud: dict, control: dict, proceso: dict) -> str:
    """Pinta la ventana real de Qrystalos2 y marca solo el cambio propuesto."""
    ventana = _elegir_ventana(proceso or {}, solicitud)
    pista = ventana.get("vue") or ""
    if not _nombres_vue(pista) and not _pistas_ruta(pista) and control:
        pista = control.get("explicacion") or pista
    archivo = _resolver_vue(pista)
    if not archivo:
        return ""
    plantilla = _trozo_plantilla(archivo)
    corte_tabla = plantilla.find("<q-table")
    zona = plantilla[:corte_tabla] if corte_tabla > 400 else plantilla[:20000]
    filtros = _etiquetas(zona, 10)
    botones = _botones_vue(zona) or _botones_vue(plantilla[:20000])
    pestanas = _pestanas_vue(zona) or _pestanas_vue(plantilla)
    columnas = _columnas_script(archivo)
    blob_cambio = " ".join(
        (
            _textos_propuesta(solicitud),
            (solicitud.get("contenido") or {}).get("alcance") or "",
            (solicitud.get("contenido") or {}).get("criteriosAceptacion") or "",
            solicitud.get("alcance") or "",
            solicitud.get("criterios") or "",
        )
    )
    menu = _elegir_menu(_menus_contextuales(plantilla), blob_cambio)
    if len(filtros) + len(botones) + len(pestanas) + len(columnas) + len(menu) < 3:
        return ""

    ident = solicitud.get("identificacion") or {}
    contenido = solicitud.get("contenido") or {}
    notas = ctx.get("notas") or contenido.get("mockupsNotas") or ""
    resumen = _propuesta_resumen(solicitud, ctx)
    acciones = _acciones_propuestas(solicitud, notas)
    alerta = _alerta_propuesta(solicitud, notas)
    reales = " ".join(botones).lower()
    nuevas = [a for a in acciones if a["label"].lower() not in reales]
    titulo = ventana.get("uso") or _titulo_ventana(solicitud, control, ctx)
    componente = os.path.splitext(os.path.basename(archivo))[0]
    src_raiz = os.path.join(_raiz_qrystalos2(), "src")
    try:
        ruta_vue = os.path.relpath(archivo, src_raiz).replace("\\", "/")
    except ValueError:
        ruta_vue = componente + ".vue"
    tokens_cambio = {t for t in _tokens(blob_cambio) if len(t) >= 5}
    captura = _captura_url(solicitud)

    def _cls_btn(a: dict) -> str:
        if a.get("disabled"):
            return "q-btn q-btn--off"
        if a["tipo"] == "primary":
            return "q-btn q-btn--p"
        if a["tipo"] == "accent":
            return "q-btn q-btn--a"
        return "q-btn q-btn--o"

    filtros_html = "".join(
        f'<div class="field"><label>{_esc(etiqueta)}</label>'
        f'<input type="text" value="" readonly></div>'
        for etiqueta in filtros
    )
    if not filtros_html:
        filtros_html = '<div class="field"><label>La ventana no muestra filtros con etiqueta en la parte superior.</label></div>'
    barra = "".join(
        f'<button type="button" class="q-btn q-btn--o">{_esc(nombre)}</button>'
        for nombre in botones
    )
    nuevos_html = "".join(
        f'<button type="button" class="{_cls_btn(a)}">{_esc(a["label"])}'
        f'<span class="badge-new">{"bloqueado" if a.get("disabled") else "propuesto"}</span></button>'
        for a in nuevas
    )
    tabs = "".join(
        f'<button type="button" class="tab-btn{" tab-btn--on" if i == 0 else ""}">{_esc(nombre)}</button>'
        for i, nombre in enumerate(pestanas)
    )
    alerta_html = f'<div class="alert-block" role="status">{_esc(alerta)}</div>' if alerta else ""
    propuesta_html = ""
    if resumen or nuevos_html:
        propuesta_html = (
            '<div class="toolbar-new"><span class="tag">Cambio propuesto</span>'
            + (f'<span style="font-size:.75rem">{_esc(_clip(resumen, 280))}</span>' if resumen else "")
            + nuevos_html
            + "</div>"
        )
    hoy_ref = ""
    if captura:
        hoy_ref = (
            f'<div class="hoy-ref"><h3>Hoy — referencia (no es la ventana propuesta)</h3>'
            f'<img src="{_esc(captura)}" alt="Captura del estado actual"></div>'
        )
    aviso = ""
    if not _tiene_propuesta(solicitud, ctx):
        aviso = (
            '<div class="aviso-falta">Falta la propuesta de desarrollo. '
            "La ventana de abajo es la del sistema; el cambio se marca cuando haya recomendación o criterios.</div>"
        )
    items_menu = list(menu)
    if "bodega" in tokens_cambio and items_menu and not any("bodega" in _tokens(it) for it in items_menu):
        items_menu.append("Cambiar bodega")
    if columnas:
        ths = "".join(f"<th>{_esc(col)}</th>" for col in columnas)
        tds = "".join("<td>—</td>" for _ in columnas)
        grilla = (
            '<div class="table-wrap" style="margin:0"><table class="data">'
            f"<thead><tr>{ths}</tr></thead><tbody><tr class=\"sel\">{tds}</tr></tbody></table></div>"
        )
    else:
        grilla = (
            '<div class="table-wrap"><table class="data"><thead><tr>'
            f"<th>{_esc(titulo)}</th></tr></thead><tbody><tr><td>—</td></tr></tbody></table></div>"
        )
    if items_menu:
        filas_menu = []
        for item in items_menu:
            marca = bool(_tokens(item) & tokens_cambio)
            estilo = (
                ' style="background:#fff3e0;border-left:3px solid #E67817;font-weight:600;padding:.35rem .6rem"'
                if marca
                else ' style="padding:.28rem .6rem;color:#455a64"'
            )
            filas_menu.append(f"<li{estilo}>{_esc(item)}</li>")
        cuerpo = (
            '<div style="display:flex;gap:.75rem;align-items:flex-start;padding:.65rem .75rem;background:#fff">'
            f'<div style="flex:1;min-width:0">{grilla}</div>'
            '<div class="q-card" style="width:260px;flex:none">'
            '<div class="q-bar"><span class="title">Menú de la línea</span></div>'
            '<ul style="list-style:none;margin:0;padding:.25rem 0 .4rem">'
            + "".join(filas_menu)
            + "</ul></div></div>"
        )
    else:
        cuerpo = grilla
    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mockup — {_esc(titulo)}</title>
  <style>{_styles_qrystalos_admin()}{_fevrips_styles_extra()}</style>
</head>
<body>
  <div class="mock-banner">
    <span><strong>Ventana del sistema</strong> · {_esc(ruta_vue)} · REQ {_esc(ident.get("idReq") or "—")}</span>
    <span>{_esc(ventana.get("entrada") or ventana.get("path") or "")}</span>
  </div>
  {aviso}
  <div class="app-top">
    <span>Qrystalos <span class="ver">Administrativo</span></span>
    <span class="ver">{_esc(titulo)}</span>
  </div>
  <div class="crumb">{_esc(ventana.get("entrada") or titulo)}</div>
  <div class="tab-group">{tabs}</div>
  <div class="filters">{filtros_html}</div>
  <div class="toolbar-new" style="background:#fafafa;border-color:var(--border)">
    <span class="tag" style="color:var(--q-primary)">Barra de la ventana</span>
    {barra or '<span style="font-size:.75rem;color:#777">Sin botones con texto en la plantilla.</span>'}
  </div>
  {alerta_html}
  {propuesta_html}
  {cuerpo}
  {hoy_ref}
  <p class="foot">Tomada de <code>{_esc(ruta_vue)}</code> · generado {_esc(ctx.get("generadoEn") or "")}</p>
</body>
</html>"""


_MOCK_CSS = """
.sc-mock { display: grid; gap: .75rem; margin: .4rem 0 1rem; }
.sc-mock .win { border: 1px solid #e4d5c0; border-radius: 8px; overflow: hidden; background: #fff; break-inside: avoid; }
.sc-mock .win-top { background: #E67817; color: #fff; padding: .45rem .75rem; font-weight: 700; font-size: .84rem; }
.sc-mock .win-path { background: #fff4e8; color: #5d4e37; padding: .28rem .75rem; font-size: .75rem; }
.sc-mock .win-body { padding: .7rem .75rem .8rem; }
.sc-mock .win-note { margin: 0 0 .45rem; font-size: .8rem; color: #344054; }
.sc-mock .chips { display: flex; flex-wrap: wrap; gap: .35rem; margin: .15rem 0 .45rem; }
.sc-mock .chip { border: 1px solid #d0d5dd; border-radius: 4px; padding: .18rem .45rem; font-size: .74rem; background: #f8fafc; color: #172033; }
.sc-mock .chip-tab { background: #175cd3; color: #fff; border-color: #175cd3; }
.sc-mock .cols { margin: 0; font-size: .76rem; color: #344054; }
"""


def _etiqueta_de_pantalla(nombre: str) -> bool:
    texto = (nombre or "").strip()
    if len(texto) < 2:
        return False
    if " " not in texto and re.search(r"[a-záéíóúñ][A-Z]", texto):
        return False
    return True


def _piezas_vue(ventana: dict) -> tuple[list[str], list[str], list[str], list[str]]:
    pista = " ".join(str(ventana.get(k) or "") for k in ("vue", "path", "ruta", "uso"))
    archivo = _resolver_vue(pista)
    if not archivo:
        return [], [], [], []
    plantilla = _trozo_plantilla(archivo)
    corte = plantilla.find("<q-table")
    zona = plantilla[:corte] if corte > 400 else plantilla[:20000]
    filtros = [n for n in _etiquetas(zona, 12) if _etiqueta_de_pantalla(n)][:8]
    botones = [n for n in (_botones_vue(zona) or _botones_vue(plantilla[:20000])) if _etiqueta_de_pantalla(n)][:8]
    pestanas = [n for n in (_pestanas_vue(zona) or _pestanas_vue(plantilla)) if _etiqueta_de_pantalla(n)][:6]
    columnas = [n for n in _columnas_script(archivo) if _etiqueta_de_pantalla(n)][:8]
    return pestanas, filtros, botones, columnas


def fragmento_pantallas(ventanas: list[dict]) -> str:
    """Mockup de las ventanas citadas, con las etiquetas reales del frontend."""
    tarjetas: list[str] = []
    for ventana in ventanas or []:
        if not isinstance(ventana, dict):
            continue
        uso = str(ventana.get("uso") or "Pantalla").strip()
        path = str(ventana.get("path") or ventana.get("ruta") or "").strip()
        entrada = _clip(ventana.get("entrada") or "", 220)
        if re.search(r"\b(?:SPQ_|SPK_|FNK_|MODELO|METODO)\b", entrada):
            entrada = ""
        pestanas, filtros, botones, columnas = _piezas_vue(ventana)
        chips = []
        for nombre in pestanas:
            chips.append(f'<span class="chip chip-tab">{_esc(nombre)}</span>')
        for nombre in botones:
            chips.append(f'<span class="chip">{_esc(nombre)}</span>')
        for nombre in filtros:
            if nombre not in botones:
                chips.append(f'<span class="chip">{_esc(nombre)}</span>')
        nota = f'<p class="win-note">{_esc(entrada)}</p>' if entrada else ""
        cols = (
            f'<p class="cols">Columnas: {_esc(", ".join(columnas))}</p>'
            if columnas
            else ""
        )
        barra = f'<div class="chips">{"".join(chips)}</div>' if chips else ""
        tarjetas.append(
            '<article class="win">'
            f'<div class="win-top">{_esc(uso)}</div>'
            f'<div class="win-path">{_esc(path or "Ruta documentada en el proceso")}</div>'
            f'<div class="win-body">{nota}{barra}{cols}</div>'
            "</article>"
        )
    if not tarjetas:
        return ""
    return (
        f"<style>{_MOCK_CSS}</style>"
        '<h3>Así se ve en el aplicativo</h3>'
        f'<div class="sc-mock">{"".join(tarjetas)}</div>'
    )


def render_mockup_ux(ctx: dict, solicitud: dict) -> str:
    sql = solicitud.get("sql") or {}
    proceso_id = (sql.get("procesoId") or ctx.get("procesoId") or "").strip()
    proceso = (kb.load_proceso(proceso_id) if proceso_id else {}) or {}
    control = _find_control(proceso, solicitud) if proceso else {}
    kind = _detect_screen_kind(solicitud, control)
    if kind == "fevrips-validacion-externa":
        return render_mockup_fevrips_validacion_externa(ctx, solicitud, control)
    if kind in ("fcxcr-form-motivos", "fcxcr-form-masivo", "fcxcr-devoluciones"):
        mode = "masivo" if kind == "fcxcr-form-masivo" else "motivos"
        return render_mockup_fcxcr_dialog(ctx, solicitud, control, mode)
    emulado = render_mockup_emulado(ctx, solicitud, control, proceso)
    if emulado:
        return emulado
    return render_mockup_ux_generic(ctx, solicitud, control)


def generar_archivos(solicitud: dict, notas: str = "") -> list[tuple[str, str]]:
    """Un mockup UX de ventana. El flujo SP queda en dictamen/sps.json, no en plantilla analista."""
    ctx = diagflujo.contexto_caso(solicitud, notas=notas)
    return [("mockup-ux-pantalla.html", render_mockup_ux(ctx, solicitud))]


def contexto_resumen(solicitud: dict, notas: str = "") -> dict:
    ctx = diagflujo.contexto_caso(solicitud, notas=notas)
    return {
        "procesoId": ctx.get("procesoId"),
        "generadoEn": datetime.now().isoformat(timespec="seconds"),
        "archivos": ["mockup-ux-pantalla.html"],
    }
