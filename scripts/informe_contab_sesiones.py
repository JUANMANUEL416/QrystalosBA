"""Sesiones de informe contable (soporte) en data/informe-contab/."""
from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "informe-contab"
INDEX_FILE = DATA_DIR / "index.json"

_ID_SAFE = re.compile(r"[^a-zA-Z0-9_-]+")


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
    return _read_json(INDEX_FILE, {"sesiones": []})


def _save_index(idx: dict) -> None:
    _write_json(INDEX_FILE, idx)


def nueva_id() -> str:
    return f"ic{datetime.now().strftime('%Y%m%d-%H%M%S')}"


def crear_sesion(servidor_id: str, database: str, institucion: str = "") -> dict:
    _ensure_dir()
    sid = nueva_id()
    carpeta = DATA_DIR / sid
    carpeta.mkdir(parents=True, exist_ok=True)
    meta = {
        "id": sid,
        "servidorId": servidor_id.strip(),
        "database": database.strip(),
        "institucion": (institucion or "").strip(),
        "creado": datetime.now().isoformat(timespec="seconds"),
        "generado": None,
        "estado": "nuevo",
    }
    _write_json(carpeta / "meta.json", meta)
    _write_json(carpeta / "chat.json", {"mensajes": []})
    idx = _load_index()
    sesiones = [s for s in idx.get("sesiones", []) if s.get("id") != sid]
    sesiones.insert(0, {k: meta[k] for k in ("id", "servidorId", "database", "institucion", "creado", "generado", "estado")})
    idx["sesiones"] = sesiones[:80]
    _save_index(idx)
    return meta


def listar_sesiones(limit: int = 30) -> list[dict]:
    idx = _load_index()
    return (idx.get("sesiones") or [])[:limit]


def carpeta_sesion(sid: str) -> Path:
    safe = _ID_SAFE.sub("", sid or "")
    if not safe.startswith("ic"):
        raise ValueError("Sesión no válida.")
    p = DATA_DIR / safe
    if not p.is_dir():
        raise FileNotFoundError("Sesión no encontrada.")
    return p


def leer_meta(sid: str) -> dict:
    return _read_json(carpeta_sesion(sid) / "meta.json", {})


def leer_chat(sid: str) -> dict:
    return _read_json(carpeta_sesion(sid) / "chat.json", {"mensajes": []})


def append_chat(sid: str, autor: str, texto: str) -> dict:
    chat = leer_chat(sid)
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto.strip(),
        "en": datetime.now().isoformat(timespec="seconds"),
    }
    chat.setdefault("mensajes", []).append(msg)
    _write_json(carpeta_sesion(sid) / "chat.json", chat)
    return msg


def guardar_informe(sid: str, html: str, meta: dict) -> dict:
    carp = carpeta_sesion(sid)
    (carp / "informe-errores-contables.html").write_text(html, encoding="utf-8")
    _write_json(carp / "informe-meta.json", meta)
    stored = leer_meta(sid)
    stored.update(
        {
            "generado": meta.get("generado") or datetime.now().isoformat(timespec="seconds"),
            "estado": "generado",
            "comprobantes_errados": meta.get("comprobantes_errados"),
            "periodo_trabajo": meta.get("periodo_trabajo"),
        }
    )
    _write_json(carp / "meta.json", stored)
    idx = _load_index()
    for s in idx.get("sesiones", []):
        if s.get("id") == sid:
            s.update(
                {
                    "generado": stored.get("generado"),
                    "estado": stored.get("estado"),
                    "comprobantes_errados": stored.get("comprobantes_errados"),
                    "periodo_trabajo": stored.get("periodo_trabajo"),
                }
            )
            break
    _save_index(idx)
    return stored


def generar_para_sesion(sid: str) -> dict:
    from informe_errores_contab import generar_informe

    meta0 = leer_meta(sid)
    env_key = meta0.get("servidorId") or ""
    database = meta0.get("database") or ""
    if not env_key or not database:
        raise ValueError("Faltan servidor o base de datos en la sesión.")
    html_doc, meta = generar_informe(
        env_key,
        database,
        institucion=meta0.get("institucion") or database,
        logo_href="/app/assets/logo-ixcolombia.svg",
    )
    meta["sesionId"] = sid
    stored = guardar_informe(sid, html_doc, meta)
    return {"html": html_doc, "meta": stored}


def ruta_informe_html(sid: str) -> Path:
    return carpeta_sesion(sid) / "informe-errores-contables.html"


def ruta_informe_pdf(sid: str) -> Path:
    return carpeta_sesion(sid) / "informe-errores-contables.pdf"


def generar_pdf(sid: str) -> Path:
    """PDF sin encabezados/pies del navegador (Chrome headless --no-pdf-header-footer)."""
    html_path = ruta_informe_html(sid)
    if not html_path.is_file():
        raise FileNotFoundError("Informe HTML aún no generado.")
    import correo as mailer

    dest = ruta_informe_pdf(sid)
    out = mailer._html_a_pdf(html_path=str(html_path), dest_pdf=str(dest))
    if not mailer._pdf_utilizable(out):
        detalle = (getattr(mailer, "_ULTIMO_ERROR_NAVEGADOR", None) or "").strip()
        raise RuntimeError(detalle or "No se pudo generar el PDF (Chrome/Edge headless).")
    meta = leer_meta(sid)
    meta["pdfGenerado"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_sesion(sid) / "meta.json", meta)
    return Path(out)
