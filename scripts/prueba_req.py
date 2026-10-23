"""Prueba de un requerimiento entregado: formulario, chat y documento de cierre."""
from __future__ import annotations

import html as html_lib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "pruebas-req"
INDEX_FILE = DATA_DIR / "index.json"

_ID_SAFE = re.compile(r"^pr\d{8}-\d{6}$")
_AUTORES = frozenset({"coordinador", "agente", "sistema"})
_VEREDICTOS = frozenset({"aprobado", "rechazado"})


def _ensure_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _read_json(path: Path, default):
    if not path.is_file():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_index() -> dict:
    _ensure_dir()
    return _read_json(INDEX_FILE, {"pruebas": []})


def _save_index(idx: dict) -> None:
    _write_json(INDEX_FILE, idx)


def _titulo(requerimiento: str) -> str:
    linea = " ".join((requerimiento or "").split())
    return (linea[:90] + "…") if len(linea) > 90 else linea


def nueva_id() -> str:
    return datetime.now().strftime("pr%Y%m%d-%H%M%S")


def carpeta_prueba(pid: str) -> Path:
    if not _ID_SAFE.match(pid or ""):
        raise ValueError("Prueba no válida.")
    p = DATA_DIR / pid
    if not p.is_dir():
        raise FileNotFoundError("Prueba no encontrada.")
    return p


def _instruccion_md(pid: str, meta: dict) -> str:
    return f"""# Prueba de requerimiento — {pid}

## Objetivo
Decidir si la entrega del desarrollador cumple el requerimiento. El veredicto es **Aprobado** o **Rechazado**.

## Leer primero
1. `data/pruebas-req/{pid}/meta.json`
2. `data/pruebas-req/{pid}/chat.json`
3. `data/pruebas-req/{pid}/INSTRUCCION-AGENTE.md`

## Orden de contraste
1. Base de conocimiento: `conocimiento/_indice_busqueda.json` y solo la ficha del control.
2. Qrystalos2: el fuente del control (pantalla, botón, llamada).
3. IXONLINE/SQL en DESAIX: PREVERSION contra la última versión cerrada (procedimiento, vista o campo).
4. Base de pruebas indicada abajo, solo con SELECT. No escriba, no ejecute procedimientos.

## Entregables
1. Mensaje en `chat.json` (autor: `agente`, campo `en`). La primera línea es **Aprobado** o **Rechazado**.
2. `meta.json` → `veredicto`: `aprobado` o `rechazado`.
3. `meta.json` → `veredictoTexto`: el texto que irá al documento. Sin rutas internas del BA, sin comandos de oficina. La fuente SQL se cita como IXONLINE/SQL y el nombre del objeto.
4. No genere el HTML. La app lo arma al cerrar.
5. No implemente en Qrystalos2 ni en la base.

## Datos de esta prueba
Desarrollador: {meta.get("desarrollador") or "—"}
Servidor: {meta.get("servidorNombre") or meta.get("servidorId") or "—"}
Base de pruebas: {meta.get("baseDatos") or "—"}

### Requerimiento
{meta.get("requerimiento") or ""}

### Observación o justificación
{meta.get("justificacion") or ""}

### Respuesta del desarrollador
{meta.get("respuestaDesarrollador") or ""}
"""


def escribir_instruccion(pid: str) -> None:
    meta = leer_meta(pid)
    (carpeta_prueba(pid) / "INSTRUCCION-AGENTE.md").write_text(
        _instruccion_md(pid, meta), encoding="utf-8"
    )


def _fila_indice(meta: dict) -> dict:
    return {
        "id": meta.get("id"),
        "titulo": meta.get("titulo") or "",
        "desarrollador": meta.get("desarrollador") or "",
        "servidorNombre": meta.get("servidorNombre") or "",
        "baseDatos": meta.get("baseDatos") or "",
        "creado": meta.get("creado"),
        "estado": meta.get("estado") or "abierta",
        "veredicto": meta.get("veredicto") or "",
        "documentoGenerado": meta.get("documentoGenerado"),
    }


def _upsert_indice(meta: dict) -> None:
    idx = _load_index()
    fila = _fila_indice(meta)
    pruebas = [p for p in idx.get("pruebas", []) if p.get("id") != meta.get("id")]
    pruebas.insert(0, fila)
    idx["pruebas"] = pruebas[:80]
    _save_index(idx)


def crear_prueba(
    requerimiento: str,
    justificacion: str,
    respuesta_desarrollador: str,
    servidor_id: str,
    servidor_nombre: str,
    base_datos: str,
    desarrollador: str = "",
) -> dict:
    _ensure_dir()
    requerimiento = (requerimiento or "").strip()
    justificacion = (justificacion or "").strip()
    respuesta = (respuesta_desarrollador or "").strip()
    servidor_id = (servidor_id or "").strip()
    base_datos = (base_datos or "").strip()
    if not requerimiento:
        raise ValueError("Indique el requerimiento.")
    if not justificacion:
        raise ValueError("Indique la observación o justificación.")
    if not respuesta:
        raise ValueError("Indique la respuesta del desarrollador.")
    if not servidor_id:
        raise ValueError("Elija el servidor de prueba.")
    if not base_datos:
        raise ValueError("Indique la base de prueba.")
    pid = nueva_id()
    carp = DATA_DIR / pid
    carp.mkdir(parents=True, exist_ok=True)
    ahora = datetime.now().isoformat(timespec="seconds")
    meta = {
        "id": pid,
        "titulo": _titulo(requerimiento),
        "requerimiento": requerimiento,
        "justificacion": justificacion,
        "respuestaDesarrollador": respuesta,
        "desarrollador": (desarrollador or "").strip(),
        "servidorId": servidor_id,
        "servidorNombre": (servidor_nombre or servidor_id).strip(),
        "baseDatos": base_datos,
        "veredicto": "",
        "veredictoTexto": "",
        "creado": ahora,
        "estado": "abierta",
        "documentoGenerado": None,
        "cerrada": None,
    }
    _write_json(carp / "meta.json", meta)
    _write_json(carp / "chat.json", {"mensajes": []})
    escribir_instruccion(pid)
    append_chat(
        pid,
        "sistema",
        "Prueba registrada. El contraste sigue este orden: base de conocimiento, fuente en Qrystalos2, "
        "IXONLINE/SQL y la base de pruebas.",
    )
    _upsert_indice(meta)
    return meta


def listar_pruebas(limit: int = 40) -> list[dict]:
    return (_load_index().get("pruebas") or [])[:limit]


def leer_meta(pid: str) -> dict:
    return _read_json(carpeta_prueba(pid) / "meta.json", {})


def leer_chat(pid: str) -> dict:
    return _read_json(carpeta_prueba(pid) / "chat.json", {"mensajes": []})


def append_chat(pid: str, autor: str, texto: str) -> dict:
    autor = (autor or "coordinador").strip().lower()
    if autor not in _AUTORES:
        autor = "coordinador"
    texto = (texto or "").strip()
    if not texto:
        raise ValueError("Mensaje vacío.")
    chat = leer_chat(pid)
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto,
        "en": datetime.now().isoformat(timespec="seconds"),
    }
    chat.setdefault("mensajes", []).append(msg)
    _write_json(carpeta_prueba(pid) / "chat.json", chat)
    return msg


def _texto_agente(pid: str) -> str:
    meta = leer_meta(pid)
    escrito = (meta.get("veredictoTexto") or "").strip()
    if escrito:
        return escrito
    for msg in reversed(leer_chat(pid).get("mensajes") or []):
        if msg.get("autor") == "agente" and (msg.get("texto") or "").strip():
            return str(msg.get("texto")).strip()
    return ""


def panel_prueba(pid: str) -> dict:
    from cursor_bot import leer_estado_bot

    meta = leer_meta(pid)
    return {
        "meta": meta,
        "mensajes": leer_chat(pid).get("mensajes", []),
        "bot": leer_estado_bot(pid),
    }


def ruta_html(pid: str) -> Path:
    return carpeta_prueba(pid) / "documento.html"


def _esc(s: str) -> str:
    return html_lib.escape(str(s or ""))


def _bloques(texto: str) -> str:
    partes = [p.strip() for p in re.split(r"\n\s*\n", texto or "") if p.strip()]
    if not partes:
        return "<p>—</p>"
    return "".join(f"<p>{_esc(p).replace(chr(10), '<br>')}</p>" for p in partes)


def generar_html_documento(pid: str, veredicto: str) -> tuple[str, dict]:
    if veredicto not in _VEREDICTOS:
        raise ValueError("El cierre es entrega (aprobado) o devolución (rechazado).")
    meta = leer_meta(pid)
    cuerpo = _texto_agente(pid)
    if not cuerpo:
        raise ValueError(
            "Falta el resultado de la prueba. Pulse Probar y espere el veredicto en el chat."
        )
    aprobado = veredicto == "aprobado"
    kind = "Entrega de requerimiento" if aprobado else "Devolución al desarrollador"
    resultado_titulo = "Qué quedó verificado" if aprobado else "Qué no cumple y qué debe corregir"
    hoy = datetime.now().strftime("%d/%m/%Y %H:%M")
    sello = "Aprobado" if aprobado else "Rechazado"
    color = "#087a55" if aprobado else "#b42318"
    fondo = "#e8f7f0" if aprobado else "#fdecea"
    doc = f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>{_esc(kind)} — {_esc(meta.get("titulo") or pid)}</title>
  <style>
    :root {{ --ink:#172033; --text:#344054; --muted:#667085; --line:#e4e7ec; --brand:#e67817; }}
    * {{ box-sizing: border-box; }}
    @page {{ size: A4; margin: 14mm 15mm; }}
    body {{ font-family: "Segoe UI", Calibri, sans-serif; color: var(--text); background: #eef1f5; margin: 0; padding: 28px; }}
    .hoja {{ max-width: 880px; margin: 0 auto; background: #fff; padding: 32px 40px 28px; }}
    .franja {{ height: 6px; background: linear-gradient(90deg, var(--brand) 0 70%, #273248 70%); margin: -32px -40px 22px; }}
    .marca {{ font-size: 11px; letter-spacing: .12em; text-transform: uppercase; color: var(--muted); }}
    h1 {{ color: var(--ink); font-size: 22pt; line-height: 1.2; margin: 8px 0 12px; }}
    .sello {{ display: inline-block; background: {fondo}; color: {color}; border: 1px solid {color};
      border-radius: 999px; padding: 4px 12px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; font-size: 11px; }}
    .meta {{ display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin: 16px 0 8px; }}
    .meta div {{ background: #f8fafc; border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; }}
    .meta span {{ display: block; color: var(--muted); font-size: 10px; text-transform: uppercase; letter-spacing: .05em; }}
    h2 {{ color: var(--ink); font-size: 13pt; border-bottom: 2px solid var(--brand); padding-bottom: 4px; margin: 22px 0 8px; }}
    p {{ margin: 0 0 8px; line-height: 1.5; }}
    footer {{ margin-top: 28px; color: var(--muted); font-size: 10px; border-top: 1px solid var(--line); padding-top: 8px; }}
  </style>
</head>
<body>
  <article class="hoja">
    <div class="franja"></div>
    <div class="marca">IX Colombia · Business Analyst</div>
    <h1>{_esc(kind)}</h1>
    <span class="sello">{sello}</span>
    <div class="meta">
      <div><span>Prueba</span>{_esc(pid)}</div>
      <div><span>Fecha</span>{_esc(hoy)}</div>
      <div><span>Desarrollador</span>{_esc(meta.get("desarrollador") or "—")}</div>
      <div><span>Base de pruebas</span>{_esc(meta.get("servidorNombre") or meta.get("servidorId") or "—")} · {_esc(meta.get("baseDatos") or "—")}</div>
    </div>
    <h2>Requerimiento</h2>
    {_bloques(meta.get("requerimiento") or "")}
    <h2>Observación o justificación</h2>
    {_bloques(meta.get("justificacion") or "")}
    <h2>Respuesta del desarrollador</h2>
    {_bloques(meta.get("respuestaDesarrollador") or "")}
    <h2>{resultado_titulo}</h2>
    {_bloques(cuerpo)}
    <footer>Contraste en este orden: base de conocimiento, fuente Qrystalos2, IXONLINE/SQL y la base de pruebas. Consultas de solo lectura.</footer>
  </article>
</body>
</html>
"""
    ruta_html(pid).write_text(doc, encoding="utf-8")
    meta["veredicto"] = veredicto
    meta["veredictoTexto"] = cuerpo
    meta["documentoGenerado"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_prueba(pid) / "meta.json", meta)
    _upsert_indice(meta)
    return doc, meta


def cerrar_prueba(pid: str, veredicto: str) -> dict:
    meta = leer_meta(pid)
    if meta.get("estado") == "cerrada" and ruta_html(pid).is_file():
        return meta
    _html, meta = generar_html_documento(pid, veredicto)
    meta["estado"] = "cerrada"
    meta["cerrada"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_prueba(pid) / "meta.json", meta)
    frase = (
        "Se cerró la prueba. El documento es la entrega del requerimiento."
        if veredicto == "aprobado"
        else "Se cerró la prueba. El documento es la devolución al desarrollador."
    )
    append_chat(pid, "sistema", frase)
    _upsert_indice(meta)
    
    # Reiniciar chat del agente al cerrar prueba
    try:
        import cursor_bot
        cursor_bot.reiniciar_chat(pid, motivo="cerrar-prueba")
    except Exception as exc:
        print(f"[prueba_req.cerrar_prueba] advertencia al reiniciar chat: {exc}", flush=True)
    
    return meta
