# -*- coding: utf-8 -*-
"""Reparte el turno de Cursor según el trabajo.

Grok 4.7: juicio (requerimiento, SQL, backend, calidad, administración).
Composer 2.5: oficio (base, dudas, chat).
El diseño lo arma la aplicación.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(ROOT, "config", "orquesta.json")

_DEFECTO = {
    "modelo": "composer-2.5",
    "params": [{"id": "fast", "value": "true"}],
}


def cargar() -> dict:
    try:
        with open(RUTA, encoding="utf-8") as fh:
            datos = json.load(fh)
        if isinstance(datos, dict):
            return datos
    except (OSError, json.JSONDecodeError):
        pass
    return {"nota": "", "defecto": dict(_DEFECTO), "piezas": []}


def pieza_de_motivo(motivo: str) -> dict:
    """Pieza de Cursor que atiende este motivo. Vacío si no hay reparto."""
    pedido = (motivo or "").strip()
    for pieza in cargar().get("piezas") or []:
        if not isinstance(pieza, dict):
            continue
        if (pieza.get("proveedor") or "cursor") != "cursor":
            continue
        if pedido in (pieza.get("motivos") or []):
            return pieza
    defecto = cargar().get("defecto")
    return defecto if isinstance(defecto, dict) else dict(_DEFECTO)


def modelo_de(motivo: str) -> str:
    return str(pieza_de_motivo(motivo).get("modelo") or _DEFECTO["modelo"]).strip() or _DEFECTO["modelo"]


def params_de(motivo: str) -> list[dict] | None:
    """None: el turno no declaró parámetros y el bot manda fast. Lista vacía: no manda fast."""
    pieza = pieza_de_motivo(motivo)
    if "params" not in pieza:
        return None
    crudo = pieza.get("params")
    if not isinstance(crudo, list):
        return []
    salida = []
    for item in crudo:
        if not isinstance(item, dict):
            continue
        pid = str(item.get("id") or "").strip()
        valor = str(item.get("value") or "").strip()
        if pid and valor:
            salida.append({"id": pid, "value": valor})
    return salida


def usa_fast(motivo: str) -> bool:
    for param in params_de(motivo) or []:
        if param["id"] == "fast":
            return param["value"].lower() in ("1", "true", "yes", "si", "on")
    return False


def siguiente(motivo: str) -> str:
    """Primer paso del cierre de este turno, si el motivo abre un documento."""
    pasos = (cargar().get("cierre") or {}).get((motivo or "").strip()) or []
    if isinstance(pasos, list) and pasos:
        return str(pasos[0] or "").strip()
    return ""


def _ruta_cierre(id_caso: str) -> str:
    import cursor_bot

    return os.path.join(cursor_bot.caso_dir(id_caso), "material", "cierre.json")


def abrir_cierre(id_caso: str, motivo: str) -> str:
    """Guarda el camino de este proceso y devuelve el primer paso."""
    pasos = (cargar().get("cierre") or {}).get((motivo or "").strip()) or []
    if not isinstance(pasos, list) or not pasos:
        return ""
    limpios = [str(p).strip() for p in pasos if str(p).strip()]
    os.makedirs(os.path.dirname(_ruta_cierre(id_caso)), exist_ok=True)
    with open(_ruta_cierre(id_caso), "w", encoding="utf-8") as fh:
        json.dump({"origen": motivo, "pasos": limpios}, fh, ensure_ascii=False, indent=2)
    return limpios[0]


def avanzar(id_caso: str, motivo: str) -> str:
    """Siguiente paso del cierre que ya abrió este caso."""
    try:
        with open(_ruta_cierre(id_caso), encoding="utf-8") as fh:
            cierre = json.load(fh)
    except (OSError, json.JSONDecodeError):
        cierre = {}
    pasos = cierre.get("pasos") if isinstance(cierre, dict) else []
    if not isinstance(pasos, list) or motivo not in pasos:
        return ""
    i = pasos.index(motivo)
    if i + 1 < len(pasos):
        return str(pasos[i + 1])
    return ""


def _texto_meta(id_caso: str) -> str:
    import cursor_bot

    meta = cursor_bot.read_json(os.path.join(cursor_bot.caso_dir(id_caso), "meta.json"), {})
    if not isinstance(meta, dict):
        return ""
    return " ".join(
        str(meta.get(k) or "")
        for k in ("respuestaOficial", "veredictoTexto")
    ).strip()


def datos_listos(id_caso: str, motivo: str) -> bool:
    """El proceso ya dejó el texto con el que los demás arman el mismo documento."""
    if motivo in ("material", "mockup-ventana", "presentacion"):
        return True
    if motivo == "soporte-consulta-analisis":
        return len(_texto_meta(id_caso)) >= 80
    if motivo == "prueba-req":
        import cursor_bot

        meta = cursor_bot.read_json(os.path.join(cursor_bot.caso_dir(id_caso), "meta.json"), {})
        texto = str((meta or {}).get("veredictoTexto") or "").strip() if isinstance(meta, dict) else ""
        return len(texto) >= 80
    if motivo not in ("analizar-req", "criterios", "solicitar-req"):
        return False
    import cursor_bot

    sol = cursor_bot.read_json(
        os.path.join(cursor_bot.caso_dir(id_caso), "solicitud.json"),
        {},
    )
    if not isinstance(sol, dict):
        return False
    modo = "comite" if motivo == "solicitar-req" else "analisis"
    try:
        import planteamiento_req

        return bool(planteamiento_req.evaluar(sol, modo=modo).get("ok"))
    except Exception:
        contenido = sol.get("contenido") if isinstance(sol.get("contenido"), dict) else {}
        partes = [
            sol.get("analisis") or "",
            contenido.get("analisis") or "",
            contenido.get("recomendacion") or "",
            contenido.get("cambioPropuestoSimple") or "",
            sol.get("recomendacion") or "",
        ]
        return len(" ".join(str(p) for p in partes).strip()) >= 120


def _esc(texto: str) -> str:
    return (
        str(texto or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def _md_html(texto: str) -> str:
    bloques = []
    for linea in str(texto or "").replace("\r\n", "\n").split("\n"):
        fila = linea.strip()
        if not fila:
            continue
        if fila.startswith("#"):
            bloques.append(f"<h3>{_esc(fila.lstrip('#').strip())}</h3>")
        else:
            bloques.append(f"<p>{_esc(fila)}</p>")
    return "\n".join(bloques) or "<p>No documentado.</p>"


def armar(id_caso: str) -> str:
    """Junta manual, guion, ventana y diagrama en un solo HTML."""
    import cursor_bot

    base = cursor_bot.caso_dir(id_caso)
    material = os.path.join(base, "material")
    os.makedirs(material, exist_ok=True)
    documento = ""
    guion = ""
    doc_path = os.path.join(material, "documento.md")
    guion_path = os.path.join(material, "guion-capacitacion.md")
    if os.path.isfile(doc_path):
        with open(doc_path, encoding="utf-8") as fh:
            documento = fh.read()
    if os.path.isfile(guion_path):
        with open(guion_path, encoding="utf-8") as fh:
            guion = fh.read()
    mockup = os.path.join(base, "mockups", "mockup-ventana-flexible.html")
    ventana = ""
    if os.path.isfile(mockup):
        ventana = (
            '<iframe class="ventana" src="../mockups/mockup-ventana-flexible.html" '
            'title="Ventana"></iframe>'
        )
    else:
        ventana = "<p>La ventana flexible no quedó generada.</p>"
    diagrama = "<p>Sin diagrama.</p>"
    try:
        import diagrama_flujo

        sol = cursor_bot.read_json(os.path.join(base, "solicitud.json"), {})
        if isinstance(sol, dict) and sol:
            ctx = diagrama_flujo.contexto_caso(sol)
            diagrama = diagrama_flujo.render_fragmento(ctx)
    except Exception:
        diagrama = "<p>El diagrama de pasos no se pudo armar con el proceso de este caso.</p>"
    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Material {_esc(id_caso)}</title>
<style>
body {{ font-family: Segoe UI, sans-serif; margin: 2rem auto; max-width: 920px; color: #1c1915; line-height: 1.45; }}
h2 {{ font-size: 1.15rem; margin-top: 2rem; }}
.ventana {{ width: 100%; height: 640px; border: 1px solid #e4d5c0; border-radius: 8px; }}
</style>
</head>
<body>
<h1>Material del caso</h1>
<h2>Documento</h2>
{_md_html(documento)}
<h2>Guion de capacitación</h2>
{_md_html(guion)}
<h2>Ventana</h2>
{ventana}
<h2>Diagrama de pasos</h2>
{diagrama}
</body>
</html>
"""
    destino = os.path.join(material, "armado.html")
    with open(destino, "w", encoding="utf-8") as fh:
        fh.write(html)
    return os.path.relpath(destino, cursor_bot.ROOT).replace("\\", "/")


def estado() -> dict:
    datos = cargar()
    piezas = []
    for pieza in datos.get("piezas") or []:
        if not isinstance(pieza, dict):
            continue
        piezas.append({
            "id": pieza.get("id") or "",
            "nombre": pieza.get("nombre") or "",
            "proveedor": pieza.get("proveedor") or "cursor",
            "modelo": pieza.get("modelo") or "",
            "hace": pieza.get("hace") or "",
            "cubre": [str(item) for item in (pieza.get("cubre") or []) if str(item).strip()],
        })
    return {"nota": datos.get("nota") or "", "piezas": piezas}
