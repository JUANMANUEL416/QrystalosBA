# -*- coding: utf-8 -*-
"""Diagrama de flujo desde conocimiento/ + análisis del REQ (HTML autocontenido)."""
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

import conocimiento as kb  # noqa: E402


def _esc(s) -> str:
    return html.escape(str(s or ""), quote=True)


def _clip(s, n=480) -> str:
    text = re.sub(r"\s+", " ", str(s or "").strip())
    if len(text) <= n:
        return text
    return text[: n - 1].rstrip() + "…"


def _norm(s) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip()


_SP_RE = re.compile(r"\b(SPQ_[A-Z0-9_]+|SPK_[A-Z0-9_]+|FNK_[A-Z0-9_]+)\b")
_METODO_CERCANO_RE = re.compile(
    r"(?:METODO\s+)?([A-Z][A-Z0-9_]{2,})(?:\s*/\s*([A-Z][A-Z0-9_]{2,}))?",
)


def _textos_req(solicitud: dict) -> str:
    c = solicitud.get("contenido") or {}
    return "\n".join(
        str(c.get(k) or "")
        for k in (
            "requerimiento",
            "cambioPropuestoSimple",
            "analisis",
            "alcance",
            "restricciones",
            "recomendacion",
        )
    )


def _es_caso_req(solicitud: dict) -> bool:
    ident = solicitud.get("identificacion") or {}
    return bool(ident.get("idCaso") or ident.get("idReq") or (solicitud.get("contenido") or {}).get("requerimiento"))


def _extraer_sps_del_texto(texto: str) -> list[tuple[str, str]]:
    """Pares (SP, METODO) citados en el análisis; no el catálogo entero."""
    pares = []
    vistos = set()
    for m in _SP_RE.finditer(texto or ""):
        sp = m.group(1)
        after = (texto or "")[m.end() : m.end() + 80]
        met = ""
        mm = re.search(
            r"(?:·\s*|METODO\s+|/\s*)([A-Z][A-Z0-9_]{2,})(?:\s+y\s+([A-Z][A-Z0-9_]{2,}))?",
            after,
        )
        if mm:
            for mid in (mm.group(1), mm.group(2)):
                if not mid:
                    continue
                key = (sp, mid)
                if key not in vistos:
                    vistos.add(key)
                    pares.append(key)
        else:
            key = (sp, "")
            if key not in vistos:
                vistos.add(key)
                pares.append(key)
    # METODOs de colilla citados sin repetir el SP en la misma frase
    if "COLILLAS_PRENOMINA" in (texto or "") and ("SPQ_RPT_NOMINA", "COLILLAS_PRENOMINA") not in vistos:
        if "SPQ_RPT_NOMINA" in (texto or "") or "RPT_NOMINA" in (texto or ""):
            pares.append(("SPQ_RPT_NOMINA", "COLILLAS_PRENOMINA"))
    if re.search(r"\bCOLILLAS\b", texto or "") and ("SPQ_RPT_NOMINA", "COLILLAS") not in vistos:
        if "SPQ_RPT_NOMINA" in (texto or "") or "RPT_NOMINA" in (texto or ""):
            pares.append(("SPQ_RPT_NOMINA", "COLILLAS"))
    return pares


_STOP_VENTANA = {
    "este", "esta", "para", "desde", "hasta", "como", "debe", "solo", "cada",
    "con", "sin", "por", "del", "las", "los", "una", "que", "req", "caso",
}

_BOOST_VENTANA = (
    "masiva", "rips", "fev", "copago", "moderadora", "factura", "radicar",
    "dian", "colilla", "prenomina", "nomina", "glosa", "caja", "presupuesto",
    "cxc", "ftr", "fevrips",
)


def _tokens_ventana(texto: str) -> set[str]:
    return {
        w
        for w in re.findall(r"[a-záéíóúñ0-9_]{4,}", (texto or "").lower())
        if w not in _STOP_VENTANA
    }


def _ventana_del_req(proceso: dict, solicitud: dict) -> dict:
    """Elige ventana del MISMO proceso. Nunca mezcla nómina en facturación/RIPS."""
    text = _textos_req(solicitud).lower()
    ventanas = proceso.get("ventanas") or []
    pid = (proceso.get("id") or "").lower()
    tokens = _tokens_ventana(text)
    scored = []
    for v in ventanas:
        blob = " ".join(
            str(v.get(k) or "") for k in ("uso", "entrada", "vue", "ruta", "path")
        ).lower()
        score = len(tokens & _tokens_ventana(blob))
        for w in _BOOST_VENTANA:
            if w in text and w in blob:
                score += 4
        if "empaque" in blob and "empaque" not in text and "anexo" not in text:
            score -= 4
        if "historico" in blob and "historico" not in text and "nemphis" not in text:
            score -= 4
        if pid != "nomina" and ("colilla" in blob or "fmtcolillas" in blob or "rpt_nomina" in blob):
            score -= 20
        scored.append((score, v))
    scored.sort(key=lambda x: -x[0])
    if scored and scored[0][0] > 0:
        return scored[0][1]
    if pid == "nomina" and any(k in text for k in ("colilla", "desprendible")):
        return {
            "entrada": "Talento humano → Procesos nómina → colillas de pago (PDF)",
            "vue": "FmtColillasNom.js · useNomi → RPT_NOMINA",
        }
    if ventanas:
        return ventanas[0]
    return {}


def _ficha_metodo(sps_cat: dict, sp_nombre: str, metodo_id: str):
    want_sp = (sp_nombre or "").upper()
    want_m = (metodo_id or "").upper()
    for sp in sps_cat.get("sps") or []:
        if (sp.get("nombre") or "").upper() != want_sp:
            continue
        for met in sp.get("metodos") or []:
            mid = (met.get("id") or "").upper()
            if mid == want_m or (want_m in ("(FUNCIÓN)", "(FUNCION)", "") and not mid):
                return sp, met
        if want_m in ("(FUNCIÓN)", "(FUNCION)"):
            return sp, {}
    return None, None


def _as_map(val):
    return val if isinstance(val, dict) else {}


def _iter_filas_sp(raw):
    """Acepta lista de dicts, lista de textos, o {leidosEnSql, pendientesSql}."""
    if raw is None:
        return
    if isinstance(raw, dict):
        if raw.get("sp") or raw.get("nombre"):
            yield raw
            return
        for v in raw.values():
            yield from _iter_filas_sp(v)
        return
    if isinstance(raw, str):
        texto = raw.strip()
        if not texto:
            return
        pares = _extraer_sps_del_texto(texto)
        if pares:
            for sp, metodo in pares:
                yield {"sp": sp, "metodo": metodo or "(reporte)", "rol": texto}
        return
    if isinstance(raw, (list, tuple)):
        for item in raw:
            yield from _iter_filas_sp(item)


def _metodos_del_caso(solicitud: dict, sps_cat: dict, proceso: dict) -> list[dict]:
    sql = _as_map(solicitud.get("sql"))
    contenido = _as_map(solicitud.get("contenido"))
    brecha = _as_map(contenido.get("brechaAnalisis"))
    filas = []
    vistos = set()

    def add(sp, metodo, extra=None):
        key = (str(sp or "").upper(), str(metodo or "").upper())
        if not key[0] or key in vistos:
            return
        vistos.add(key)
        row = {"sp": sp, "metodo": metodo}
        if extra:
            row.update(extra)
        cat_sp, cat_m = _ficha_metodo(sps_cat, sp, metodo)
        if cat_m:
            row.setdefault("hace", cat_m.get("hace") or "")
            row.setdefault("llama", list(cat_m.get("llama") or []))
            row.setdefault("efecto", cat_m.get("efecto") or "")
            row.setdefault("estado", cat_m.get("estado") or "")
            row.setdefault("gateId", cat_m.get("gateId") or "")
            row.setdefault("capaId", cat_m.get("capaId") or "")
        elif cat_sp:
            row.setdefault("estado", cat_sp.get("estado") or "")
        filas.append(row)

    for m in _iter_filas_sp(sql.get("metodosDocumentados")):
        add(m.get("sp") or m.get("nombre"), m.get("metodo") or m.get("id"), {
            "hace": m.get("hace") or "",
            "rol": m.get("rol") or "",
            "estado": m.get("estado") or "",
        })
    for m in _iter_filas_sp(brecha.get("sps")):
        add(m.get("sp") or m.get("nombre"), m.get("metodo") or m.get("id"), {
            "rol": m.get("rol") or "",
            "estado": m.get("estado") or "",
        })
    if filas:
        return filas

    texto = _textos_req(solicitud)
    if texto.strip():
        for sp, metodo in _extraer_sps_del_texto(texto):
            add(sp, metodo or "(reporte)", {"rol": "Citado en el análisis del REQ", "gateId": ""})
        if filas:
            return filas

    # Consultas (sin REQ): catálogo del proceso. En un REQ no volcar todos los controles.
    if not _es_caso_req(solicitud):
        for capa in proceso.get("capas") or []:
            for control in kb.controles_de(capa):
                for sp in control.get("sps") or []:
                    add(sp.get("nombre"), sp.get("metodo"), {"rol": sp.get("rol") or "", "gateId": control.get("id") or ""})
    return filas


def _gates_relevantes(proceso: dict, metodos: list[dict], solicitud: dict | None = None) -> list[dict]:
    ids = {
        m.get("gateId")
        for m in metodos
        if m.get("gateId") and "fuera" not in (m.get("rol") or "").lower()
    }
    texto = _textos_req(solicitud or {}).lower()
    out = []
    for capa in proceso.get("capas") or []:
        for gate in kb.controles_de(capa):
            gid = gate.get("id") or ""
            nombre = (gate.get("nombre") or "").lower()
            expl = (gate.get("explicacion") or "").lower()
            if ids:
                if gid not in ids:
                    continue
            elif texto:
                # Solo controles que hablen del mismo tema que el REQ
                claves = [
                    w
                    for w in (
                        "colilla", "desprendible", "furips", "cum", "rips",
                        "fev", "masiva", "copago", "moderadora", "radicar",
                    )
                    if w in texto
                ]
                blob = f"{gid} {nombre} {expl}"
                if claves and not any(k in blob for k in claves):
                    continue
            item = dict(gate)
            item["capaNombre"] = capa.get("nombre") or capa.get("id")
            out.append(item)
    if out:
        return out
    if _es_caso_req(solicitud or {}):
        c = (solicitud or {}).get("contenido") or {}
        return [
            {
                "id": "alcance-req",
                "nombre": "Solo el cambio de este REQ",
                "capaNombre": "Alcance (no el proceso completo)",
                "explicacion": _clip(c.get("cambioPropuestoSimple") or c.get("analisis") or "", 420),
                "invariante": _clip(c.get("restricciones") or "No incluir SPs de otros controles.", 320),
                "sps": [{"nombre": m.get("sp"), "metodo": m.get("metodo")} for m in metodos if m.get("sp")],
            }
        ]
    for capa in proceso.get("capas") or []:
        for gate in kb.controles_de(capa):
            item = dict(gate)
            item["capaNombre"] = capa.get("nombre") or capa.get("id")
            out.append(item)
    return out


def _pasos_flujo(solicitud: dict, proceso: dict, metodos: list[dict]) -> list[dict]:
    texto = _textos_req(solicitud).lower()
    if "vwk_imovh_agrupado" in texto:
        return [
            {
                "kind": "user",
                "titulo": "Confirmación de entrada",
                "detalle": "IMOV confirmada. Cada lote queda en IMOVH con su IVA.",
            },
            {
                "kind": "vue",
                "titulo": "Vista",
                "detalle": "VWK_IMOVH_AGRUPADO agrupa por artículo, lote, vencimiento, estado y costo. El IVA sale de ese grupo.",
            },
            {
                "kind": "sql",
                "titulo": "CxP",
                "detalle": "SPK_INSERT_CXP_INV graba ese IVA en cada línea de FCXPD.",
            },
        ]
    proyecto = solicitud.get("proyecto") or {}
    ventana = _ventana_del_req(proceso, solicitud)
    pantalla = (
        proyecto.get("rutaPantalla")
        or ventana.get("entrada")
        or ventana.get("vue")
        or proyecto.get("modulo")
        or "Pantalla"
    )
    vue = ventana.get("vue") or "componente Vue"
    pasos = [
        {"kind": "user", "titulo": "Usuario", "detalle": _clip(ventana.get("entrada") or pantalla, 90)},
        {"kind": "vue", "titulo": "Pantalla", "detalle": _clip(vue, 90)},
    ]
    principales = [m for m in metodos if "fuera" not in (m.get("rol") or "").lower()]
    if not principales:
        principales = metodos[:2]
    if principales:
        llamados = []
        vistos = set()
        for m in principales:
            etiq = f"{(m.get('sp') or '').replace('SPQ_', '')} · {m.get('metodo')}"
            if etiq not in vistos:
                vistos.add(etiq)
                llamados.append(etiq)
        pasos.append({
            "kind": "api",
            "titulo": "AppStore.json",
            "detalle": _clip(" / ".join(llamados[:4]) or "MODELO · METODO", 140),
        })
        sps_unicos = []
        vistos_sp = set()
        llamas = []
        for m in principales:
            n = (m.get("sp") or "").strip()
            if n and n.upper() not in vistos_sp:
                vistos_sp.add(n.upper())
                sps_unicos.append(n)
            for x in m.get("llama") or []:
                if x not in llamas:
                    llamas.append(x)
        pasos.append({
            "kind": "sql",
            "titulo": ", ".join(sps_unicos[:3]) or "SP",
            "detalle": _clip(", ".join(llamas) or (principales[0].get("efecto") or "SQL Server"), 140),
        })
    pasos.append({
        "kind": "out",
        "titulo": "Resultado",
        "detalle": _clip(
            (solicitud.get("contenido") or {}).get("cambioPropuestoSimple")
            or "Salida del proceso",
            100,
        ),
    })
    # Evitar duplicar SP si hay varios métodos del mismo SP: se dejan, el mapa debe verse.
    return pasos


def _hoy_propuesto(solicitud: dict) -> tuple[str, str]:
    c = solicitud.get("contenido") or {}
    analisis = c.get("analisis") or ""
    hoy = ""
    m = re.search(r"\*\*Causa:\*\*\s*(.+?)(?:\n\n|\*\*|$)", analisis, re.S)
    if m:
        hoy = _clip(m.group(1), 360)
    if not hoy:
        hoy = _clip(analisis, 360) or "Comportamiento actual según la base de procesos."
    prop = _clip(c.get("cambioPropuestoSimple") or c.get("recomendacion") or "", 360)
    if not prop:
        prop = "El análisis del REQ aún no describe el cambio. Complete el análisis y vuelva a generar."
    return hoy, prop


CSS_INCRUSTADO = """
.diagrama-incrustado { color: #1a1a1a; }
.diagrama-incrustado .df-flow {
  display: flex; flex-wrap: wrap; align-items: stretch; gap: .45rem .35rem;
  padding: .85rem; background: #faf6f0; border: 1px dashed #e4d5c0; border-radius: 6px;
  margin-bottom: .85rem;
}
.diagrama-incrustado .df-node {
  flex: 1 1 140px; min-width: 120px; max-width: 220px;
  border-radius: 6px; padding: .55rem .65rem; border: 1px solid #e4d5c0; background: #fff;
}
.diagrama-incrustado .df-node .k { font-weight: 700; font-size: .82rem; margin-bottom: .2rem; color: #1a1a1a; }
.diagrama-incrustado .df-node .d { font-size: .78rem; color: #5d4e37; line-height: 1.35; white-space: normal; }
.diagrama-incrustado .df-user { border-color: #E67817; background: #fff4e8; }
.diagrama-incrustado .df-vue { border-color: #3d7ea6; }
.diagrama-incrustado .df-api { border-color: #6b4c9a; background: #f7f2fc; }
.diagrama-incrustado .df-sql { border-color: #1e8449; background: #f2faf5; }
.diagrama-incrustado .df-out { border-color: #CB500F; background: #fff0e4; }
.diagrama-incrustado .df-arrow { align-self: center; color: #E67817; font-weight: 700; }
.diagrama-incrustado .df-split { display: grid; grid-template-columns: 1fr 1fr; gap: .65rem; margin-bottom: .85rem; }
@media (max-width: 720px) { .diagrama-incrustado .df-split { grid-template-columns: 1fr; } .diagrama-incrustado .df-arrow { display: none; } }
.diagrama-incrustado .df-box { border: 1px solid #e4d5c0; border-radius: 6px; padding: .75rem .85rem; }
.diagrama-incrustado .df-hoy { background: #fdf2f2; border-color: #e6b0aa; }
.diagrama-incrustado .df-ok { background: #eafaf1; border-color: #a9dfbf; }
.diagrama-incrustado .df-box h3 { margin: 0 0 .35rem; font-size: .88rem; color: #CB500F; }
.diagrama-incrustado .df-box p { margin: 0; font-size: .85rem; white-space: normal; }
.diagrama-incrustado table { width: 100%; border-collapse: collapse; font-size: .82rem; margin: .4rem 0 .85rem; }
.diagrama-incrustado th, .diagrama-incrustado td { border: 1px solid #e4d5c0; padding: .4rem .5rem; vertical-align: top; text-align: left; white-space: normal; }
.diagrama-incrustado th { background: #fff4e8; color: #1a1a1a; }
.diagrama-incrustado .df-gate { border: 1px solid #E67817; border-radius: 6px; padding: .65rem .85rem; margin-bottom: .5rem; box-shadow: 0 0 0 2px #f5d0b0; }
.diagrama-incrustado .df-gate h3 { margin: 0 0 .2rem; font-size: .9rem; color: #CB500F; }
.diagrama-incrustado .df-meta { color: #5d4e37; font-size: .8rem; }
"""


def _cuerpo_flujo(ctx: dict) -> dict:
    pasos_html = []
    for i, p in enumerate(ctx["pasos"]):
        if i:
            pasos_html.append('<div class="df-arrow" aria-hidden="true">→</div>')
        pasos_html.append(
            f'<div class="df-node df-{_esc(p["kind"])}">'
            f'<div class="k">{_esc(p["titulo"])}</div>'
            f'<div class="d">{_esc(p["detalle"])}</div>'
            f"</div>"
        )
    filas_sp = []
    for m in ctx["metodos"]:
        llama = ", ".join(m.get("llama") or []) or "—"
        filas_sp.append(
            "<tr>"
            f"<td>{_esc(m.get('sp'))}</td>"
            f"<td>{_esc(m.get('metodo'))}</td>"
            f"<td>{_esc(m.get('estado') or '—')}</td>"
            f"<td>{_esc(_clip(m.get('hace') or m.get('rol'), 220))}</td>"
            f"<td>{_esc(_clip(llama, 160))}</td>"
            "</tr>"
        )
    if not filas_sp:
        filas_sp.append('<tr><td colspan="5">Sin SP/METODO en el análisis ni en el proceso.</td></tr>')
    gates_html = []
    for g in ctx["gates"]:
        sps_g = ", ".join(
            f"{x.get('nombre')} · {x.get('metodo')}"
            for x in (g.get("sps") or [])
            if x.get("nombre")
        )
        gates_html.append(
            f'<article class="df-gate">'
            f"<h3>{_esc(g.get('nombre') or g.get('id'))}</h3>"
            f'<p class="df-meta">{_esc(g.get("capaNombre"))} · <code>{_esc(g.get("id"))}</code></p>'
            f"<p>{_esc(g.get('explicacion') or '')}</p>"
            f'<p class="df-meta"><strong>Invariante:</strong> {_esc(g.get("invariante") or "—")}</p>'
            f'<p class="df-meta">SP: {_esc(sps_g or "—")}</p>'
            "</article>"
        )
    return {
        "pasos": "".join(pasos_html),
        "filas": "".join(filas_sp),
        "gates": "".join(gates_html) or "<p class='df-meta'>Este proceso aún no tiene controles en conocimiento/.</p>",
        "notas": _esc(ctx.get("notas") or ""),
        "alcance": _esc(ctx.get("alcance") or ""),
        "hoy": _esc(ctx["hoy"]),
        "propuesto": _esc(ctx["propuesto"]),
        "req": ctx.get("idReq") or "—",
        "caso": ctx.get("idCaso") or "",
        "titulo": ctx.get("titulo") or ctx.get("procesoNombre") or "Flujo",
        "procesoId": ctx.get("procesoId") or "",
        "procesoNombre": ctx.get("procesoNombre") or "",
        "proyecto": ctx.get("proyecto") or "",
        "generadoEn": ctx.get("generadoEn") or "",
    }


def render_fragmento(ctx: dict) -> str:
    """HTML para incrustar en el dictamen (sección 4.5). Autocontenido, sin documento completo."""
    c = _cuerpo_flujo(ctx)
    notas = f'<p class="df-meta"><strong>Notas:</strong> {c["notas"]}</p>' if ctx.get("notas") else ""
    alcance = f'<p class="df-meta"><strong>Alcance:</strong> {c["alcance"]}</p>' if ctx.get("alcance") else ""
    return (
        f"<style>{CSS_INCRUSTADO}</style>\n"
        f'<p class="df-meta">Generado desde <code>conocimiento/{_esc(c["procesoId"])}/</code> '
        f"y el análisis del REQ. Queda adjunto a este documento.</p>\n"
        f'<div class="df-flow">{c["pasos"]}</div>\n'
        f'<div class="df-split">'
        f'<div class="df-box df-hoy"><h3>Hoy</h3><p>{c["hoy"]}</p></div>'
        f'<div class="df-box df-ok"><h3>Propuesto</h3><p>{c["propuesto"]}</p></div>'
        f"</div>\n"
        f"<table><thead><tr><th>SP</th><th>METODO</th><th>Estado</th><th>Hace / rol</th><th>Llama</th></tr></thead>"
        f"<tbody>{c['filas']}</tbody></table>\n"
        f"{c['gates']}\n"
        f"{alcance}{notas}"
    )


def render_html(ctx: dict) -> str:
    pasos_html = []
    for i, p in enumerate(ctx["pasos"]):
        if i:
            pasos_html.append('<div class="arrow" aria-hidden="true">→</div>')
        pasos_html.append(
            f'<div class="node node-{_esc(p["kind"])}">'
            f'<div class="k">{_esc(p["titulo"])}</div>'
            f'<div class="d">{_esc(p["detalle"])}</div>'
            f"</div>"
        )

    filas_sp = []
    for m in ctx["metodos"]:
        llama = ", ".join(m.get("llama") or []) or "—"
        filas_sp.append(
            "<tr>"
            f"<td>{_esc(m.get('sp'))}</td>"
            f"<td>{_esc(m.get('metodo'))}</td>"
            f"<td>{_esc(m.get('estado') or '—')}</td>"
            f"<td>{_esc(_clip(m.get('hace') or m.get('rol'), 220))}</td>"
            f"<td>{_esc(_clip(llama, 160))}</td>"
            "</tr>"
        )
    if not filas_sp:
        filas_sp.append('<tr><td colspan="5">Sin SP/METODO en el análisis ni en el proceso. Documente el control o analice el REQ.</td></tr>')

    gates_html = []
    for g in ctx["gates"]:
        cls = "gate gate-on" if g.get("id") in ctx["gateIds"] else "gate"
        sps_g = ", ".join(
            f"{x.get('nombre')} · {x.get('metodo')}"
            for x in (g.get("sps") or [])
            if x.get("nombre")
        )
        gates_html.append(
            f'<article class="{cls}">'
            f"<h3>{_esc(g.get('nombre') or g.get('id'))}</h3>"
            f'<p class="meta">{_esc(g.get("capaNombre"))} · <code>{_esc(g.get("id"))}</code></p>'
            f"<p>{_esc(g.get('explicacion') or '')}</p>"
            f'<p class="inv"><strong>Invariante:</strong> {_esc(g.get("invariante") or "—")}</p>'
            f'<p class="meta">SP: {_esc(sps_g or "—")}</p>'
            "</article>"
        )
    if not gates_html:
        gates_html.append("<p class='empty'>Este proceso aún no tiene controles en conocimiento/.</p>")

    notas = ctx.get("notas") or ""
    notas_block = (
        f'<section><h2>Notas del coordinador</h2><p>{_esc(notas)}</p></section>'
        if notas
        else ""
    )
    req = ctx.get("idReq") or "—"
    caso = ctx.get("idCaso") or ""
    titulo = ctx.get("titulo") or ctx.get("procesoNombre") or "Flujo"

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Diagrama de flujo — {_esc(titulo)} {('· REQ ' + _esc(req)) if req != '—' else ''}</title>
  <style>
    :root {{
      --naranja: #E67817;
      --naranja-2: #CB500F;
      --fondo: #fff8ee;
      --texto: #1a1a1a;
      --muted: #5d4e37;
      --borde: #e4d5c0;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; font-family: "Segoe UI", Tahoma, sans-serif;
      background: var(--fondo); color: var(--texto); padding: 1.25rem;
    }}
    .wrap {{ max-width: 1100px; margin: 0 auto; background: #fff; border: 1px solid #000; border-radius: 4px; padding: 1.5rem 1.75rem 2rem; }}
    header {{ border-bottom: 3px solid var(--naranja); padding-bottom: 1rem; margin-bottom: 1.25rem; }}
    header h1 {{ margin: 0 0 .35rem; font-size: 1.35rem; color: var(--naranja); }}
    header p {{ margin: 0; color: var(--muted); font-size: .92rem; }}
    h2 {{ font-size: 1.05rem; color: var(--naranja-2); margin: 1.4rem 0 .6rem; }}
    .flow {{
      display: flex; flex-wrap: wrap; align-items: stretch; gap: .45rem .35rem;
      padding: .85rem; background: #faf6f0; border: 1px dashed var(--borde); border-radius: 6px;
    }}
    .node {{
      flex: 1 1 140px; min-width: 130px; max-width: 220px;
      border-radius: 6px; padding: .65rem .7rem; border: 1px solid var(--borde); background: #fff;
    }}
    .node .k {{ font-weight: 700; font-size: .82rem; margin-bottom: .25rem; }}
    .node .d {{ font-size: .78rem; color: var(--muted); line-height: 1.35; }}
    .node-user {{ border-color: var(--naranja); background: #fff4e8; }}
    .node-vue {{ border-color: #3d7ea6; }}
    .node-api {{ border-color: #6b4c9a; background: #f7f2fc; }}
    .node-sql {{ border-color: #1e8449; background: #f2faf5; }}
    .node-out {{ border-color: var(--naranja-2); background: #fff0e4; }}
    .arrow {{ align-self: center; color: var(--naranja); font-weight: 700; padding: 0 .15rem; }}
    .split {{ display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }}
    @media (max-width: 720px) {{ .split {{ grid-template-columns: 1fr; }} .arrow {{ display: none; }} }}
    .box {{ border: 1px solid var(--borde); border-radius: 6px; padding: .85rem 1rem; }}
    .box h3 {{ margin: 0 0 .4rem; font-size: .9rem; }}
    .box-hoy {{ background: #fdf2f2; border-color: #e6b0aa; }}
    .box-ok {{ background: #eafaf1; border-color: #a9dfbf; }}
    table {{ width: 100%; border-collapse: collapse; font-size: .82rem; }}
    th, td {{ border: 1px solid var(--borde); padding: .4rem .5rem; vertical-align: top; text-align: left; }}
    th {{ background: #fff4e8; }}
    .gates {{ display: grid; gap: .65rem; }}
    .gate {{ border: 1px solid var(--borde); border-radius: 6px; padding: .75rem 1rem; }}
    .gate-on {{ border-color: var(--naranja); box-shadow: 0 0 0 2px #f5d0b0; }}
    .gate h3 {{ margin: 0 0 .2rem; font-size: .95rem; }}
    .meta, .inv, .empty, .foot {{ color: var(--muted); font-size: .82rem; }}
    .inv {{ margin-bottom: .35rem; }}
    .foot {{ margin-top: 1.5rem; border-top: 1px solid var(--borde); padding-top: .75rem; }}
    code {{ font-size: .85em; }}
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <h1>{_esc(titulo)}</h1>
      <p>
        {"REQ " + _esc(req) if req != "—" else "Consultas"}
        {" · caso " + _esc(caso) if caso else ""}
        · proceso <code>{_esc(ctx.get("procesoId"))}</code>
        · {_esc(ctx.get("procesoNombre"))}
        {" · " + _esc(ctx.get("proyecto")) if ctx.get("proyecto") else ""}
      </p>
    </header>

    <section>
      <h2>Recorrido técnico</h2>
      <div class="flow">{''.join(pasos_html)}</div>
    </section>

    <section>
      <h2>Hoy frente a lo propuesto</h2>
      <div class="split">
        <div class="box box-hoy">
          <h3>Hoy</h3>
          <p>{_esc(ctx["hoy"])}</p>
        </div>
        <div class="box box-ok">
          <h3>Propuesto (análisis del REQ)</h3>
          <p>{_esc(ctx["propuesto"])}</p>
        </div>
      </div>
    </section>

    <section>
      <h2>SP · METODO (conocimiento + análisis)</h2>
      <table>
        <thead><tr><th>SP</th><th>METODO</th><th>Estado</th><th>Hace / rol</th><th>Llama</th></tr></thead>
        <tbody>{''.join(filas_sp)}</tbody>
      </table>
    </section>

    <section>
      <h2>Controles en la base de procesos</h2>
      <div class="gates">{''.join(gates_html)}</div>
    </section>

    {f'<section><h2>Alcance</h2><p>{_esc(ctx["alcance"])}</p></section>' if ctx.get("alcance") else ""}
    {notas_block}

    <p class="foot">
      Generado {_esc(ctx.get("generadoEn"))} desde el <strong>alcance de este REQ</strong>
      cruzado con <code>conocimiento/{_esc(ctx.get("procesoId"))}/</code>.
      No se listan SPs de otros controles del módulo.
    </p>
  </div>
</body>
</html>
"""


def contexto_caso(solicitud: dict, notas: str = "") -> dict:
    sql = solicitud.get("sql") or {}
    ident = solicitud.get("identificacion") or {}
    contenido = solicitud.get("contenido") or {}
    proyecto = solicitud.get("proyecto") or {}
    proceso_id = (sql.get("procesoId") or "").strip()
    if not proceso_id:
        raise ValueError(
            "Falta el proceso en el caso (paso SQL → proceso / métodos documentados). "
            "Sin eso no se puede leer conocimiento/."
        )
    proceso = kb.load_proceso(proceso_id)
    if not proceso:
        raise ValueError(f"No hay proceso «{proceso_id}» en conocimiento/.")
    sps_cat = kb.load_sps(proceso_id)
    metodos = _metodos_del_caso(solicitud, sps_cat, proceso)
    gates = _gates_relevantes(proceso, metodos, solicitud)
    hoy, propuesto = _hoy_propuesto(solicitud)
    return {
        "idCaso": ident.get("idCaso") or "",
        "idReq": ident.get("idReq") or "",
        "titulo": contenido.get("titulo") or proceso.get("nombre") or proceso_id,
        "procesoId": proceso_id,
        "procesoNombre": proceso.get("nombre") or proceso_id,
        "proyecto": proyecto.get("nombre") or "",
        "pasos": _pasos_flujo(solicitud, proceso, metodos),
        "metodos": metodos,
        "gates": gates,
        "gateIds": {
            m.get("gateId")
            for m in metodos
            if m.get("gateId") and "fuera" not in (m.get("rol") or "").lower()
        },
        "hoy": hoy,
        "propuesto": propuesto,
        "alcance": _clip(contenido.get("alcance") or "", 700),
        "notas": _norm(notas) or _norm(_as_map(contenido.get("diagramaFlujo")).get("notas")),
        "generadoEn": datetime.now().isoformat(timespec="seconds"),
        "aviso": None if metodos else "El diagrama salió del proceso; aún no hay SP del análisis.",
    }


def contexto_proceso(proceso_id: str, pregunta: str = "", notas: str = "") -> dict:
    proceso_id = (proceso_id or "").strip()
    if not proceso_id:
        raise ValueError("Seleccione el módulo / proceso.")
    proceso = kb.load_proceso(proceso_id)
    if not proceso:
        raise ValueError(f"No hay proceso «{proceso_id}» en conocimiento/.")
    sps_cat = kb.load_sps(proceso_id)
    solicitud = {
        "sql": {"procesoId": proceso_id},
        "identificacion": {},
        "proyecto": {"modulo": proceso.get("modulo") or proceso.get("nombre")},
        "contenido": {
            "titulo": proceso.get("nombre") or proceso_id,
            "analisis": pregunta or proceso.get("resumen") or "",
            "cambioPropuestoSimple": pregunta or proceso.get("resumen") or "",
            "alcance": proceso.get("alcanceHasta") or "",
        },
    }
    ctx = contexto_caso(solicitud, notas=notas or pregunta)
    ctx["idCaso"] = ""
    ctx["idReq"] = "—"
    if pregunta:
        ctx["hoy"] = _clip(proceso.get("resumen") or "Flujo documentado en la base de procesos.", 360)
        ctx["propuesto"] = _clip(pregunta, 360)
    return ctx


def html_caso(solicitud: dict, notas: str = "") -> tuple[str, dict]:
    ctx = contexto_caso(solicitud, notas=notas)
    return render_html(ctx), ctx


def html_proceso(proceso_id: str, pregunta: str = "", notas: str = "") -> tuple[str, dict]:
    ctx = contexto_proceso(proceso_id, pregunta=pregunta, notas=notas)
    return render_html(ctx), ctx


def guardar_html_proceso(proceso_id: str, contenido: str, nombre: str = "flujo.html") -> dict:
    dest_dir = os.path.join(kb.proceso_dir(proceso_id), "diagramas")
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, nombre)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(contenido)
    rel = f"conocimiento/{proceso_id}/diagramas/{nombre}"
    return {
        "nombre": nombre,
        "ruta": rel,
        "url": f"/{rel}",
        "generadoEn": datetime.now().isoformat(timespec="seconds"),
        "fuente": "conocimiento",
    }
