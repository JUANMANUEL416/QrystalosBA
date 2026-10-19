"""Entrega de requerimiento: plantilla propia, texto con ChatGPT e ilustración.

No reutiliza el PDF de consultas de soporte. El Markdown de control de cambios
sigue siendo el detalle técnico; este documento es breve para cliente y soporte.
"""
from __future__ import annotations

import html as html_lib
import json
import re
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLANTILLA = ROOT / "plantillas" / "entrega-requerimiento.html"
Q2_SQL = Path(r"c:\DevQuasar\Qrystalos\Qrystalos2\sql")

SYSTEM_PROMPT = """Eres coordinador de entrega de Qrystalos (HIS hospitalario).
Redactas un documento BREVE para quien prueba o da soporte.
IDIOMA: español de Colombia en TODOS los campos. Ni una frase en inglés.
Puedes dejar nombres técnicos como están (Conf. Mov., PRI, SPK_CONFIRMASAL_CM).
No copies el control de cambios entero. No pongas SQL, hosts, nombres de base ni cuerpos de SP.
No inventes pantallas, variables ni validaciones que no estén en el material.
Máximo 3 cambios. Máximo 5 pruebas por rol. Si no hay configuración nueva, aplica=false.
Devuelve solo JSON con esta forma:
{
  "titulo": "",
  "proposito": "2 a 4 frases en español",
  "cambios": [{"titulo": "", "texto": ""}],
  "configuracion": {"aplica": false, "items": [{"nombre": "", "texto": ""}]},
  "pruebas": {
    "desarrollador": [""],
    "coordinador": [""],
    "soporte": [""]
  },
  "ilustracion": "escena en español de ESTE ticket, para dibujar la infografía (farmacia confirma, calendario abierto o cerrado)",
  "pieIlustracion": "una línea en español para el pie de la imagen"
}
"""


def _esc(s: str) -> str:
    return html_lib.escape(str(s or ""))


def _p(s: str) -> str:
    return _esc(s).replace("\n", "<br>")


def _ul(items: list) -> str:
    lis = []
    for item in items or []:
        texto = str(item or "").strip()
        if texto:
            lis.append(f"<li>{_esc(texto)}</li>")
    if not lis:
        return "<p class=\"config-vacia\">Sin ítems.</p>"
    return "<ul>" + "".join(lis) + "</ul>"


def _logo_src() -> str:
    import base64

    logo = ROOT / "app" / "assets" / "logo-ixcolombia.svg"
    if logo.is_file():
        encoded = base64.b64encode(logo.read_bytes()).decode("ascii")
        return f"data:image/svg+xml;base64,{encoded}"
    return "/app/assets/logo-ixcolombia.svg"


def resolver_md(meta: dict) -> Path | None:
    """Busca el control de cambios por referencia (COESME644) o ruta en meta."""
    directo = Path(str(meta.get("controlCambios") or "").strip())
    if directo.is_file():
        return directo
    ref = re.sub(r"[^A-Za-z0-9_-]+", "", str(meta.get("referencia") or meta.get("titulo") or ""))
    if not ref:
        return None
    candidatos = [
        Q2_SQL / f"{ref}_CONTROL_CAMBIOS.md",
        ROOT / "sql" / f"{ref}_CONTROL_CAMBIOS.md",
    ]
    titulo = str(meta.get("titulo") or "")
    m = re.search(r"(COESME\d+|MEDICAL\d+|CESPER\d+|IXCOLO\d+)", titulo, re.I)
    if m:
        clave = m.group(1).upper()
        candidatos.insert(0, Q2_SQL / f"{clave}_CONTROL_CAMBIOS.md")
    for path in candidatos:
        if path.is_file():
            return path
    return None


def _seccion_md(texto: str, titulo: str) -> str:
    marca = re.search(rf"(?im)^##\s+{re.escape(titulo)}\s*$", texto)
    if not marca:
        return ""
    resto = texto[marca.end() :]
    sig = re.search(r"(?m)^##\s+", resto)
    return (resto[: sig.start()] if sig else resto).strip()


def _viñetas(bloque: str) -> list[str]:
    out = []
    for line in (bloque or "").splitlines():
        t = re.sub(r"^\s*[-*•]\s+", "", line).strip()
        t = re.sub(r"^\*\*(.+?)\*\*\s*$", r"\1", t)
        if t and not t.startswith("#") and not t.startswith("|") and not t.startswith("```"):
            if t.lower() in ("desarrollador", "coordinador (usuario)", "soporte"):
                continue
            out.append(t)
    return out


def _fallback(meta: dict, md: str) -> dict:
    pruebas = _seccion_md(md, "Pruebas sugeridas")
    bloques = re.split(r"(?im)^\*\*(Desarrollador|Coordinador \(usuario\)|Soporte)\*\*\s*$", pruebas)
    mapa = {"desarrollador": [], "coordinador": [], "soporte": []}
    i = 1
    while i + 1 < len(bloques):
        clave = bloques[i].split()[0].lower()
        if clave.startswith("coordin"):
            clave = "coordinador"
        mapa[clave] = _viñetas(bloques[i + 1])[:5]
        i += 2
    solucion = _seccion_md(md, "Solución realizada") or (meta.get("respuestaOficial") or "")
    primer = [p.strip() for p in re.split(r"\n\s*\n", solucion) if p.strip() and not p.startswith("|")]
    cambios = []
    for par in primer[:3]:
        cambios.append({"titulo": "Cambio", "texto": re.sub(r"\s+", " ", par)[:420]})
    if not cambios:
        cambios = [{"titulo": "Cambio", "texto": (meta.get("proposito") or meta.get("titulo") or "").strip()}]
    return {
        "titulo": meta.get("titulo") or "",
        "proposito": (meta.get("proposito") or "").strip(),
        "cambios": cambios,
        "configuracion": {"aplica": False, "items": []},
        "pruebas": mapa,
        "ilustracion": (
            "Infografía de una farmacia hospitalaria confirmando una dispensación, "
            "con un calendario que marca el mes abierto o cerrado."
        ),
        "pieIlustracion": "Así queda el proceso después del cambio.",
        "modelo": "local",
    }


def redactar(meta: dict, md: str) -> dict:
    import openai_sugerir as oai

    user = (
        "Idioma obligatorio: español de Colombia. Todos los textos del JSON van en español.\n"
        "Título: "
        f"{(meta.get('titulo') or '').strip() or '—'}\n"
        f"Referencia: {(meta.get('referencia') or '').strip() or '—'}\n"
        f"Cliente: {(meta.get('cliente') or '').strip() or '—'}\n"
        f"Necesidad:\n{(meta.get('preguntaInicial') or '').strip() or '—'}\n\n"
        "Control de cambios (fuente; resume, no copies):\n"
        f"{(md or '')[:12000]}\n"
    )
    result = oai.chat_json(SYSTEM_PROMPT, user, modelo=oai.modelo_entrega())
    if not result.get("ok"):
        datos = _fallback(meta, md)
        datos["avisoModelo"] = result.get("mensaje") or "ChatGPT no respondió; se usó el Markdown."
        return datos
    obj = result["objeto"]
    obj["modelo"] = result.get("modelo") or "openai"
    obj["titulo"] = (obj.get("titulo") or meta.get("titulo") or "").strip()
    obj["proposito"] = (obj.get("proposito") or meta.get("proposito") or "").strip()
    if not str(obj.get("pieIlustracion") or "").strip():
        obj["pieIlustracion"] = "Así queda el proceso después del cambio."
    return obj


def _prompt_imagen(escena: str) -> str:
    escena = (escena or "").strip()
    if len(escena) < 40:
        escena = (
            "Una farmacia hospitalaria confirma una dispensación. Un calendario muestra un mes "
            "cerrado en naranja y otro abierto en verde."
        )
    return (
        "Infografía vectorial, estilo editorial limpio. "
        "TODO el texto visible en la imagen debe estar en español de Colombia. "
        "Cero palabras en inglés. Sin logotipos. Sin caras fotorrealistas. Sin letra minúscula ilegible. "
        "Acento naranja #E67817. "
        f"Escena: {escena}"
    )


def ilustrar(sid: str, prompt: str, pie: str = "") -> dict | None:
    import openai_sugerir as oai
    import soporte_consultas as sc

    carp = sc.carpeta_consulta(sid) / "imagenes"
    carp.mkdir(parents=True, exist_ok=True)
    dest = carp / "entrega-ilustracion.png"
    
    try:
        result = oai.generar_imagen(_prompt_imagen(prompt), str(dest))
        if not result.get("ok"):
            # Log el error pero no fallar el documento completo
            sc.append_chat(
                sid,
                "sistema",
                f"No se pudo generar ilustración con OpenAI: {result.get('mensaje', 'Error desconocido')}"
            )
            return None
    except Exception as e:
        sc.append_chat(
            sid,
            "sistema",
            f"Error generando ilustración: {str(e)}"
        )
        return None
    
    item = {
        "nombre": dest.name,
        "url": f"/api/soporte-consultas/{sid}/imagen/{dest.name}",
        "origen": "openai",
        "titulo": (pie or "").strip() or "Así queda el proceso después del cambio.",
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
    }
    meta = sc.leer_meta(sid)
    imgs = [i for i in (meta.get("imagenes") or []) if i.get("nombre") != dest.name]
    imgs.append(item)
    meta["imagenes"] = imgs
    sc.actualizar_meta(sid, imagenes=imgs)
    return item


def _html_cambios(cambios: list) -> str:
    partes = []
    for item in cambios or []:
        if not isinstance(item, dict):
            continue
        titulo = str(item.get("titulo") or "").strip() or "Cambio"
        texto = str(item.get("texto") or "").strip()
        if not texto:
            continue
        partes.append(
            f'<article class="cambio"><h3>{_esc(titulo)}</h3><p>{_p(texto)}</p></article>'
        )
    return "".join(partes) or "<p class=\"config-vacia\">Sin cambios descritos.</p>"


def _html_config(cfg: dict) -> str:
    if not isinstance(cfg, dict) or not cfg.get("aplica"):
        return '<p class="config-vacia">No hay configuración nueva. El comportamiento usa lo que ya estaba en el sistema.</p>'
    items = cfg.get("items") or []
    partes = []
    for item in items:
        if not isinstance(item, dict):
            continue
        nombre = str(item.get("nombre") or "").strip()
        texto = str(item.get("texto") or "").strip()
        if not nombre and not texto:
            continue
        partes.append(
            f'<article class="cambio"><h3>{_esc(nombre or "Parámetro")}</h3><p>{_p(texto)}</p></article>'
        )
    return "".join(partes) or '<p class="config-vacia">No hay configuración nueva.</p>'


def _html_ilustracion(sid: str, item: dict | None) -> str:
    import soporte_consultas as sc

    if not item:
        return ""
    path = sc.carpeta_consulta(sid) / "imagenes" / Path(item.get("nombre") or "").name
    if not path.is_file():
        return ""
    import base64

    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    titulo = item.get("titulo") or "Así queda el proceso después del cambio."
    return (
        f'<figure class="hero"><img src="data:image/png;base64,{encoded}" alt="{_esc(titulo)}">'
        f"<figcaption>{_esc(titulo)}</figcaption></figure>"
    )


def pintar_html(meta: dict, doc: dict, sid: str, ilustracion: dict | None) -> str:
    plantilla = PLANTILLA.read_text(encoding="utf-8")
    pruebas = doc.get("pruebas") or {}
    valores = {
        "TITULO": _esc(doc.get("titulo") or meta.get("titulo") or "Entrega"),
        "ID": _esc(meta.get("id") or sid),
        "REFERENCIA": _esc(meta.get("referencia") or "—"),
        "CLIENTE": _esc(meta.get("cliente") or "—"),
        "FECHA": _esc(date.today().strftime("%d/%m/%Y")),
        "LOGO_SRC": _logo_src(),
        "PROPOSITO": _p(doc.get("proposito") or meta.get("proposito") or ""),
        "NECESIDAD": _p(meta.get("preguntaInicial") or ""),
        "CAMBIOS_HTML": _html_cambios(doc.get("cambios") or []),
        "CONFIG_HTML": _html_config(doc.get("configuracion") or {}),
        "PRUEBAS_DEV_HTML": _ul((pruebas.get("desarrollador") or [])[:5]),
        "PRUEBAS_COORD_HTML": _ul((pruebas.get("coordinador") or [])[:5]),
        "PRUEBAS_SOPORTE_HTML": _ul((pruebas.get("soporte") or [])[:5]),
        "ILUSTRACION_HTML": _html_ilustracion(sid, ilustracion),
        "MODELO": _esc("redactado en español"),
    }
    html = plantilla
    for clave, valor in valores.items():
        html = html.replace("{{" + clave + "}}", valor)
    return html


def generar_documento(sid: str, presentar: bool = True) -> tuple[str, dict]:
    import soporte_consultas as sc

    meta = sc.leer_meta(sid)
    if not meta.get("entregaRequerimiento"):
        raise ValueError("Esta consulta no es una entrega de requerimiento.")
    md_path = resolver_md(meta)
    md = md_path.read_text(encoding="utf-8") if md_path else (meta.get("respuestaOficial") or "")
    doc = redactar(meta, md)
    ilustracion = ilustrar(
        sid,
        doc.get("ilustracion") or "",
        doc.get("pieIlustracion") or "",
    )
    if ilustracion is None:
        imgs = [i for i in (meta.get("imagenes") or []) if i.get("nombre") == "entrega-ilustracion.png"]
        ilustracion = imgs[-1] if imgs else None
    html = pintar_html(meta, doc, sid, ilustracion)
    ts = datetime.now().isoformat(timespec="seconds")
    carp = sc.carpeta_consulta(sid)
    (carp / "respuesta.html").write_text(html, encoding="utf-8")
    (carp / "entrega.json").write_text(
        json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    sc.actualizar_meta(
        sid,
        documentoGenerado=ts,
        entregaModelo=doc.get("modelo"),
        controlCambios=str(md_path) if md_path else meta.get("controlCambios") or "",
    )
    meta = sc.leer_meta(sid)
    return html, meta
