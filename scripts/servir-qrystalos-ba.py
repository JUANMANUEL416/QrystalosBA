#!/usr/bin/env python3
"""Servidor Qrystalos BA: estáticos + API sql + SQLite (casos, chat, histórico, cola)"""
import base64
import json
import os
import re
import shutil
import sys
import time
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import parse_qs, unquote, urlparse

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
# Bajo servicio Windows LocalSystem con consola cp1252, los emojis/✓/✗
# causan UnicodeEncodeError. Esto reconfigura los streams para que
# reemplacen caracteres no representables en vez de fallar.
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        # Si reconfigure falla, envolver con TextIOWrapper
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace', line_buffering=True)
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace', line_buffering=True)
elif hasattr(sys.stdout, 'buffer'):
    # Python 3 sin reconfigure (versiones antiguas)
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace', line_buffering=True)
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace', line_buffering=True)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from cursor_bot import (  # noqa: E402
    CONOCIMIENTO_ID,
    CONSULTAS_ID,
    DOCUMENTAR_ID,
    agregar_clave_cursor,
    cambiar_clave_cursor,
    cursor_key_status,
    continuacion_chat,
    leer_estado_bot,
    listar_claves_publicas,
    load_api_key,
    modelo_report,
)
import agentes_panel  # noqa: E402
from qrystalos_ba_db import get_db  # noqa: E402
import desarrolladores as devs  # noqa: E402
import correo as mailer  # noqa: E402
import conocimiento as kb  # noqa: E402
import kb_buscar  # noqa: E402
import kb_handoff  # noqa: E402
import kb_indice  # noqa: E402
import diagrama_flujo as diagflujo  # noqa: E402
import mockup_generar as mockgen  # noqa: E402
import mockup_empaquetar as mockzip  # noqa: E402
import solicitud_req as solreq  # noqa: E402
import auditoria_procesos as audproc  # noqa: E402
import sql_revisar  # noqa: E402
import servidores_admin  # noqa: E402
import informe_contab_sesiones as icinforme  # noqa: E402
import soporte_consultas as scconsulta  # noqa: E402
import gemini_ilustracion  # noqa: E402
import prueba_req as prreq  # noqa: E402
import capacitacion_bloques as capbloques  # noqa: E402
import capacitacion_ensamblar as capensamblar  # noqa: E402

ROOT = os.path.dirname(SCRIPT_DIR)
SQL_ROOT = os.path.join(ROOT, "sql")
SQL_REF_ROOT = os.path.join(ROOT, "sql_refe")
ACTIVO_ROOT = os.path.join(ROOT, "activo")
HISTORICO_ROOT = os.path.join(ROOT, "historico")
DICTAMENES_ROOT = os.path.join(ROOT, "dictamenes")
APROBADOS_ROOT = os.path.join(ROOT, "aprobados")
COLA_ROOT = os.path.join(ROOT, "cola")
PORT = 8765


def _sql_files_in_dir(directory):
    if not os.path.isdir(directory):
        return []
    return sorted(
        f for f in os.listdir(directory)
        if f.lower().endswith(".sql") and os.path.isfile(os.path.join(directory, f))
    )


def _sql_dir_caso(id_caso):
    """SQL de un análisis. No usa la carpeta compartida sql/."""
    if not id_caso or any(c in id_caso for c in "\\/:") or ".." in id_caso:
        raise ValueError("idCaso inválido")
    d = os.path.join(ACTIVO_ROOT, id_caso, "sql")
    os.makedirs(d, exist_ok=True)
    return d


def _caso_dir(id_caso):
    return os.path.join(ACTIVO_ROOT, id_caso)


def _read_json_file(path, default=None):
    if not os.path.isfile(path):
        return default if default is not None else {}
    raw = open(path, "rb").read()
    text = None
    for enc in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        text = raw.decode("utf-8", errors="replace")
    try:
        data, end = json.JSONDecoder().raw_decode(text.lstrip())
    except json.JSONDecodeError:
        return default if default is not None else {}
    if end < len(text) and text[end:].strip():
        try:
            _write_json_file(path, data)
        except OSError:
            pass
    return data


def _write_json_file(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


def _sanitize_imagen_nombre(nombre):
    base = os.path.basename((nombre or "").strip())
    base = re.sub(r"[^\w.\-]", "_", base)
    return base[:180] if base else ""


def _mime_to_ext(mime):
    return {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }.get((mime or "").lower(), ".png")


def _imagenes_analisis_dir(id_caso):
    return os.path.join(_caso_dir(id_caso), "imagenes")


ARCHIVO_EXTS = {".pdf", ".txt", ".md", ".html", ".htm", ".docx", ".doc"}
ARCHIVO_MAX_BYTES = 20 * 1024 * 1024
EXTRACTO_MAX_CHARS = 250_000


def _archivos_analisis_dir(id_caso):
    return os.path.join(_caso_dir(id_caso), "archivos")


def _sanitize_archivo_nombre(nombre):
    base = os.path.basename((nombre or "").strip())
    base = re.sub(r"[^\w.\-]", "_", base)
    return base[:180] if base else ""


def _ext_archivo(nombre, mime=""):
    ext = os.path.splitext(nombre or "")[1].lower()
    if ext in ARCHIVO_EXTS:
        return ext
    mime = (mime or "").lower()
    return {
        "application/pdf": ".pdf",
        "text/plain": ".txt",
        "text/markdown": ".md",
        "text/html": ".html",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
        "application/msword": ".doc",
    }.get(mime, "")


def _extracto_nombre(nombre):
    stem, _ext = os.path.splitext(nombre or "")
    return f"{stem}.extracto.txt"


def _id_caso_ok(id_caso):
    caso = (id_caso or "").strip()
    if not caso or any(c in caso for c in "\\/:") or ".." in caso:
        raise ValueError("ID de caso no válido")
    return caso


def importar_archivos_solicitud(id_caso, id_sr):
    """Copia los adjuntos de una solicitud de requerimiento al caso del analista."""
    caso = _id_caso_ok(id_caso)
    sol = solreq.load((id_sr or "").strip())
    if not sol:
        raise ValueError("Solicitud no encontrada")
    src_dir = os.path.join(solreq.caso_dir(sol["id"]), "archivos")
    dest_dir = _archivos_analisis_dir(caso)
    os.makedirs(dest_dir, exist_ok=True)
    copiados = []
    for item in sol.get("archivos") or []:
        if not isinstance(item, dict):
            continue
        nombre = _sanitize_archivo_nombre(item.get("nombre") or "")
        if not nombre or nombre.endswith(".extracto.txt"):
            continue
        src = os.path.join(src_dir, nombre)
        if not os.path.isfile(src):
            continue
        dest = os.path.join(dest_dir, nombre)
        if not os.path.isfile(dest):
            shutil.copy2(src, dest)
        extracto = os.path.basename(item.get("extracto") or _extracto_nombre(nombre))
        extracto = _sanitize_archivo_nombre(extracto) or _extracto_nombre(nombre)
        src_ex = os.path.join(src_dir, extracto)
        dest_ex = os.path.join(dest_dir, extracto)
        aviso = item.get("avisoExtracto") or ""
        chars = 0
        if os.path.isfile(src_ex):
            if not os.path.isfile(dest_ex):
                shutil.copy2(src_ex, dest_ex)
            try:
                chars = len(open(dest_ex, encoding="utf-8", errors="replace").read())
            except OSError:
                chars = 0
        elif not os.path.isfile(dest_ex):
            texto, aviso = _extraer_texto_archivo(dest)
            chars = len(texto or "")
            with open(dest_ex, "w", encoding="utf-8") as fh:
                fh.write(f"Extracto de {nombre}\nCaso: {caso}\n")
                if aviso:
                    fh.write(f"Aviso: {aviso}\n")
                fh.write("=" * 40 + "\n\n")
                fh.write(texto or "(sin texto extraíble — abra el original)\n")
        try:
            peso = os.path.getsize(dest)
        except OSError:
            peso = int(item.get("bytes") or 0)
        copiados.append({
            "nombre": nombre,
            "ruta": f"activo/{caso}/archivos/{nombre}",
            "extracto": extracto,
            "extractoRuta": f"activo/{caso}/archivos/{extracto}",
            "tipo": (item.get("tipo") or "normativa").strip() or "normativa",
            "mime": item.get("mime") or "",
            "bytes": peso,
            "charsExtracto": chars,
            "avisoExtracto": aviso or "",
            "subidaEn": datetime.now().isoformat(timespec="seconds"),
            "url": f"/api/caso/{caso}/archivo/{nombre}",
            "urlExtracto": f"/api/caso/{caso}/archivo/{extracto}",
            "origenSolicitud": sol["id"],
        })
    db = get_db()
    solicitud = db.get_solicitud(caso) or {}
    if solicitud.get("identificacion") or solicitud.get("contenido"):
        contenido = dict(solicitud.get("contenido") or {})
        nombres = {c["nombre"] for c in copiados}
        previos = [a for a in (contenido.get("archivosAnalisis") or []) if a.get("nombre") not in nombres]
        contenido["archivosAnalisis"] = previos + copiados
        contenido["solicitudOrigen"] = {
            "id": sol["id"],
            "titulo": sol.get("titulo") or "",
        }
        solicitud["contenido"] = contenido
        db.guardar_solicitud(caso, solicitud)
    return {"id": sol["id"], "titulo": sol.get("titulo") or "", "archivos": copiados}


def _extraer_texto_archivo(path):
    """Devuelve (texto, aviso). aviso si no se pudo extraer o es parcial."""
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext in (".txt", ".md"):
            raw = open(path, "rb").read()
            for enc in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
                try:
                    return raw.decode(enc)[:EXTRACTO_MAX_CHARS], None
                except UnicodeDecodeError:
                    continue
            return raw.decode("utf-8", errors="replace")[:EXTRACTO_MAX_CHARS], None
        if ext in (".html", ".htm"):
            raw = open(path, "rb").read()
            text = raw.decode("utf-8", errors="replace")
            text = re.sub(r"<script[\s\S]*?</script>", " ", text, flags=re.I)
            text = re.sub(r"<style[\s\S]*?</style>", " ", text, flags=re.I)
            text = re.sub(r"<[^>]+>", " ", text)
            text = re.sub(r"[ \t]+", " ", text)
            text = re.sub(r"\n{3,}", "\n\n", text)
            return text.strip()[:EXTRACTO_MAX_CHARS], None
        if ext == ".docx":
            import zipfile
            from xml.etree import ElementTree as ET

            with zipfile.ZipFile(path) as zf:
                xml = zf.read("word/document.xml")
            root = ET.fromstring(xml)
            ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
            partes = [t.text or "" for t in root.findall(".//w:t", ns)]
            return " ".join(p for p in partes if p).strip()[:EXTRACTO_MAX_CHARS], None
        if ext == ".pdf":
            return _extraer_texto_pdf(path)
        if ext == ".doc":
            return "", "DOC binario: no se extrae texto. Convierta a PDF o DOCX."
    except Exception as exc:
        return "", f"No se pudo extraer texto: {exc}"
    return "", "Tipo no extraíble"


def _extraer_texto_pdf(path):
    reader = None
    try:
        from pypdf import PdfReader

        reader = PdfReader(path)
    except ImportError:
        try:
            from PyPDF2 import PdfReader

            reader = PdfReader(path)
        except ImportError:
            return "", "Falta pypdf para leer PDF. El agente igual puede abrir el archivo original."
    paginas = []
    for i, page in enumerate(reader.pages or []):
        try:
            t = page.extract_text() or ""
        except Exception:
            t = ""
        if t.strip():
            paginas.append(f"--- página {i + 1} ---\n{t.strip()}")
    if not paginas:
        return "", "PDF sin texto extraíble (puede ser escaneo)."
    return "\n\n".join(paginas)[:EXTRACTO_MAX_CHARS], None


def _guardar_archivo_analisis(id_caso, data_url, nombre_sugerido="", tipo="", solicitud_base=None):
    """Guarda normativa/archivo en activo/{id}/archivos/ + extracto.txt y actualiza solicitud."""
    data_url = (data_url or "").strip()
    m = re.match(r"data:([^;,]+)(?:;[^,]*)?;base64,(.+)", data_url, re.DOTALL | re.IGNORECASE)
    if not m:
        raise ValueError("dataUrl inválido (se espera archivo base64)")
    mime, b64 = m.group(1), m.group(2)
    nombre = _sanitize_archivo_nombre(nombre_sugerido or "")
    ext = _ext_archivo(nombre, mime)
    if not ext:
        raise ValueError("Solo se admiten PDF, TXT, MD, HTML o DOCX.")
    if not nombre:
        nombre = f"normativa-{datetime.now().strftime('%Y%m%d-%H%M%S')}{ext}"
    if not os.path.splitext(nombre)[1]:
        nombre += ext
    dest_dir = _archivos_analisis_dir(id_caso)
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, nombre)
    if os.path.exists(path):
        base, ext2 = os.path.splitext(nombre)
        nombre = f"{base}-{int(time.time())}{ext2}"
        path = os.path.join(dest_dir, nombre)
    try:
        raw = base64.b64decode(b64, validate=True)
    except Exception as exc:
        raise ValueError("Base64 inválido") from exc
    if len(raw) > ARCHIVO_MAX_BYTES:
        raise ValueError("Archivo demasiado grande (máx. 20 MB)")
    with open(path, "wb") as fh:
        fh.write(raw)
    texto, aviso = _extraer_texto_archivo(path)
    extracto = _extracto_nombre(nombre)
    extracto_path = os.path.join(dest_dir, extracto)
    encabezado = (
        f"Extracto de {nombre}\n"
        f"Caso: {id_caso}\n"
        f"Tipo: {(tipo or 'normativa').strip() or 'normativa'}\n"
        f"{'Aviso: ' + aviso if aviso else 'Texto extraído para citar en el dictamen.'}\n"
        f"{'=' * 60}\n\n"
    )
    with open(extracto_path, "w", encoding="utf-8") as fh:
        fh.write(encabezado)
        fh.write(texto or "(sin texto extraíble — abra el archivo original)\n")
    ruta_rel = f"activo/{id_caso}/archivos/{nombre}"
    meta = {
        "nombre": nombre,
        "ruta": ruta_rel,
        "extracto": extracto,
        "extractoRuta": f"activo/{id_caso}/archivos/{extracto}",
        "tipo": (tipo or "normativa").strip() or "normativa",
        "mime": mime,
        "bytes": len(raw),
        "charsExtracto": len(texto or ""),
        "avisoExtracto": aviso or "",
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
        "url": f"/api/caso/{id_caso}/archivo/{nombre}",
        "urlExtracto": f"/api/caso/{id_caso}/archivo/{extracto}",
    }
    db = get_db()
    solicitud = dict(solicitud_base) if isinstance(solicitud_base, dict) else (db.get_solicitud(id_caso) or {})
    contenido = dict(solicitud.get("contenido") or {})
    items = [a for a in (contenido.get("archivosAnalisis") or []) if a.get("nombre") != nombre]
    items.append({k: meta[k] for k in (
        "nombre", "ruta", "extracto", "extractoRuta", "tipo", "mime", "bytes",
        "charsExtracto", "avisoExtracto", "subidaEn", "url", "urlExtracto",
    )})
    contenido["archivosAnalisis"] = items
    solicitud["contenido"] = contenido
    if not solicitud.get("identificacion"):
        solicitud["identificacion"] = {"idCaso": id_caso}
    db.guardar_solicitud(id_caso, solicitud)
    return meta


def _fmt_archivos_analisis(id_caso, solicitud):
    items = ((solicitud or {}).get("contenido") or {}).get("archivosAnalisis") or []
    if not items:
        return ""
    lines = []
    for a in items:
        nombre = (a.get("nombre") or "").strip()
        if not nombre:
            continue
        extracto = (a.get("extracto") or _extracto_nombre(nombre)).strip()
        tipo = (a.get("tipo") or "normativa").strip()
        lines.append(
            f"   - {tipo}: activo/{id_caso}/archivos/{nombre}"
            f" — lea el extracto `activo/{id_caso}/archivos/{extracto}`"
        )
    if not lines:
        return ""
    return (
        f"4. **Normativa / archivos** — resolución, circular o anexo técnico. "
        f"Léalos, contrastelos con lo que genera Qrystalos y **cite apartes** en el dictamen (sección 4.6):\n"
        + "\n".join(lines)
        + "\n   No invente artículos: solo lo que esté en el extracto o en el PDF."
    )


def _sanitize_diagrama_nombre(nombre):
    base = os.path.basename((nombre or "").strip())
    base = re.sub(r"[^\w.\-]", "_", base)
    if base and not base.lower().endswith(".html"):
        base = f"{base}.html"
    if not base:
        base = "flujo.html"
    return base[:180]


def _diagramas_dir(id_caso):
    return os.path.join(_caso_dir(id_caso), "diagramas")


def _mockups_dir(id_caso):
    return os.path.join(_caso_dir(id_caso), "mockups")


def _filtrar_mockups_caso_list(id_caso, rels):
    """Quita mockups de otros casos en activo/; conserva activo/{id_caso}/ y solicitudes/."""
    out = []
    for rel in rels or []:
        r = str(rel or "").strip().replace("\\", "/").lstrip("/")
        if not r or r in out:
            continue
        if r.startswith("activo/"):
            if not r.startswith(f"activo/{id_caso}/"):
                continue
        out.append(r)
    return out


def _sanitize_mockup_nombre(nombre):
    return _sanitize_diagrama_nombre(nombre or "mockup.html")


def _guardar_mockup_html(id_caso, contenido_html, nombre_sugerido="", reemplazar=False):
    """Guarda HTML en activo/{id}/mockups/ y lo agrega a contenido.mockups."""
    raw = (contenido_html or "").strip()
    if not raw:
        raise ValueError("Contenido HTML vacío")
    if len(raw.encode("utf-8")) > 6 * 1024 * 1024:
        raise ValueError("Mockup demasiado grande (máx. 6 MB)")
    if "<" not in raw:
        raise ValueError("El archivo no parece HTML")
    nombre = _sanitize_mockup_nombre(nombre_sugerido)
    mock_dir = _mockups_dir(id_caso)
    os.makedirs(mock_dir, exist_ok=True)
    path = os.path.join(mock_dir, nombre)
    if os.path.exists(path) and not reemplazar:
        base, ext = os.path.splitext(nombre)
        nombre = f"{base}-{int(time.time())}{ext}"
        path = os.path.join(mock_dir, nombre)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(raw)
    try:
        mockzip.empaquetar_mockup_html(path, id_caso=id_caso)
    except OSError:
        pass
    ruta_rel = f"activo/{id_caso}/mockups/{nombre}"
    db = get_db()
    solicitud = db.get_solicitud(id_caso) or {}
    contenido = dict(solicitud.get("contenido") or {})
    rels = _filtrar_mockups_caso_list(id_caso, mailer.rutas_mockups_solicitud(solicitud))
    if ruta_rel not in rels:
        rels.append(ruta_rel)
    contenido["mockups"] = rels
    solicitud["contenido"] = contenido
    db.guardar_solicitud(id_caso, solicitud)
    return {
        "nombre": nombre,
        "ruta": ruta_rel,
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
        "url": f"/{ruta_rel}",
        "tipo": "mockup-ux",
        "existe": True,
    }


def _guardar_diagrama_flujo(
    id_caso, contenido_html, nombre_sugerido="", solicitud_base=None, reemplazar=False
):
    """Guarda HTML del diagrama en activo/{id}/diagramas/ y actualiza solicitud.contenido.diagramaFlujo."""
    raw = (contenido_html or "").strip()
    if not raw:
        raise ValueError("Contenido HTML vacío")
    if len(raw.encode("utf-8")) > 6 * 1024 * 1024:
        raise ValueError("Diagrama demasiado grande (máx. 6 MB)")
    if "<" not in raw:
        raise ValueError("El archivo no parece HTML")
    nombre = _sanitize_diagrama_nombre(nombre_sugerido)
    diag_dir = _diagramas_dir(id_caso)
    os.makedirs(diag_dir, exist_ok=True)
    path = os.path.join(diag_dir, nombre)
    if os.path.exists(path) and not reemplazar:
        base, ext = os.path.splitext(nombre)
        nombre = f"{base}-{int(time.time())}{ext}"
        path = os.path.join(diag_dir, nombre)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(raw)
    ruta_rel = f"activo/{id_caso}/diagramas/{nombre}"
    meta = {
        "nombre": nombre,
        "ruta": ruta_rel,
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
        "url": f"/api/caso/{id_caso}/diagrama/{nombre}",
    }
    db = get_db()
    solicitud = dict(solicitud_base) if isinstance(solicitud_base, dict) else (db.get_solicitud(id_caso) or {})
    contenido = dict(solicitud.get("contenido") or {})
    notas_prev = (contenido.get("diagramaFlujo") or {}).get("notas") or ""
    meta["notas"] = notas_prev
    contenido["diagramaFlujo"] = meta
    solicitud["contenido"] = contenido
    if not solicitud.get("identificacion"):
        solicitud["identificacion"] = {"idCaso": id_caso}
    db.guardar_solicitud(id_caso, solicitud)
    return meta


def _guardar_imagen_analisis(id_caso, data_url, nombre_sugerido="", solicitud_base=None):
    """Guarda imagen en activo/{id}/imagenes/ y actualiza solicitud.contenido.imagenesAnalisis."""
    data_url = (data_url or "").strip()
    m = re.match(r"data:(image/[\w+.\-]+);base64,(.+)", data_url, re.DOTALL | re.IGNORECASE)
    if not m:
        raise ValueError("dataUrl inválido (se espera imagen base64)")
    mime, b64 = m.group(1), m.group(2)
    ext = _mime_to_ext(mime)
    nombre = _sanitize_imagen_nombre(nombre_sugerido or "")
    if not nombre:
        nombre = f"captura-{datetime.now().strftime('%Y%m%d-%H%M%S')}{ext}"
    if not os.path.splitext(nombre)[1]:
        nombre += ext
    img_dir = _imagenes_analisis_dir(id_caso)
    os.makedirs(img_dir, exist_ok=True)
    path = os.path.join(img_dir, nombre)
    if os.path.exists(path):
        base, ext2 = os.path.splitext(nombre)
        nombre = f"{base}-{int(time.time())}{ext2}"
        path = os.path.join(img_dir, nombre)
    try:
        raw = base64.b64decode(b64, validate=True)
    except Exception as exc:
        raise ValueError("Base64 inválido") from exc
    if len(raw) > 8 * 1024 * 1024:
        raise ValueError("Imagen demasiado grande (máx. 8 MB)")
    with open(path, "wb") as fh:
        fh.write(raw)
    ruta_rel = f"activo/{id_caso}/imagenes/{nombre}"
    meta = {
        "nombre": nombre,
        "ruta": ruta_rel,
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
        "url": f"/api/caso/{id_caso}/imagen/{nombre}",
    }
    db = get_db()
    solicitud = dict(solicitud_base) if isinstance(solicitud_base, dict) else (db.get_solicitud(id_caso) or {})
    contenido = dict(solicitud.get("contenido") or {})
    imgs = [i for i in (contenido.get("imagenesAnalisis") or []) if i.get("nombre") != nombre]
    imgs.append({k: meta[k] for k in ("nombre", "ruta", "subidaEn", "url")})
    contenido["imagenesAnalisis"] = imgs
    solicitud["contenido"] = contenido
    if not solicitud.get("identificacion"):
        solicitud["identificacion"] = {"idCaso": id_caso}
    db.guardar_solicitud(id_caso, solicitud)
    return meta


def _fmt_diagrama_flujo(id_caso, solicitud):
    diag = ((solicitud or {}).get("contenido") or {}).get("diagramaFlujo") or {}
    nombre = (diag.get("nombre") or "").strip()
    if not nombre:
        return ""
    return (
        f"5. **Diagrama de flujo** — ya generado en `activo/{id_caso}/diagramas/{nombre}`. "
        f"**Incruste el mapa en la sección 4.5** del dictamen (no solo un enlace). "
        f"Copia suelta: `dictamenes/{id_caso}-flujo.html`."
    )


def _seccion_dictamen_diagrama(id_caso, nombre, fragmento=""):
    extra = (fragmento or "").strip()
    if extra:
        cuerpo = (
            f'<div class="diagrama-flujo-block diagrama-incrustado">\n{extra}\n</div>'
        )
    else:
        cuerpo = (
            f'<div class="diagrama-flujo-block">'
            f"<p>Hay diagrama en <code>dictamenes/{id_caso}-flujo.html</code> "
            f"y <code>activo/{id_caso}/diagramas/{nombre}</code>.</p></div>"
        )
    return (
        f'  <section id="diagrama-flujo">\n'
        f"    <h2>4.5 Diagrama de flujo</h2>\n"
        f"    {cuerpo}\n"
        f"  </section>"
    )


def _copiar_diagrama_junto_al_dictamen(id_caso, nombre):
    src = os.path.join(_diagramas_dir(id_caso), nombre)
    if not os.path.isfile(src):
        return ""
    dest = os.path.join(DICTAMENES_ROOT, f"{id_caso}-flujo.html")
    shutil.copy2(src, dest)
    return f"dictamenes/{id_caso}-flujo.html"


def _actualizar_dictamen_diagrama(id_caso, nombre, proceso_id="", fragmento=""):
    path = os.path.join(DICTAMENES_ROOT, f"{id_caso}.html")
    sidecar = _copiar_diagrama_junto_al_dictamen(id_caso, nombre)
    if not os.path.isfile(path):
        return False
    with open(path, encoding="utf-8") as fh:
        html = fh.read()
    seccion = _seccion_dictamen_diagrama(id_caso, nombre, fragmento)

    def _repl(_m):
        return seccion

    nuevo, n = re.subn(
        r'<section id="diagrama-flujo">[\s\S]*?</section>',
        _repl,
        html,
        count=1,
    )
    if not n:
        # Insertar antes de normativa o de cambios si el dictamen aún no tiene 4.5
        insertado, n2 = re.subn(
            r'(<section id="normativa">)',
            seccion + "\n\n  \\1",
            html,
            count=1,
        )
        if n2:
            nuevo, n = insertado, n2
        else:
            insertado, n3 = re.subn(
                r'(<section id="cambios">)',
                seccion + "\n\n  \\1",
                html,
                count=1,
            )
            if n3:
                nuevo, n = insertado, n3
    if n:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(nuevo)
        return True
    return bool(sidecar)


def _generar_y_guardar_diagrama_caso(id_caso, notas=""):
    db = get_db()
    solicitud = db.get_solicitud(id_caso)
    if not solicitud:
        raise ValueError("No hay solicitud en disco para este caso. Active el análisis (Fase 1) primero.")
    html, ctx = diagflujo.html_caso(solicitud, notas=notas)
    meta = _guardar_diagrama_flujo(
        id_caso,
        html,
        "flujo.html",
        solicitud_base=solicitud,
        reemplazar=True,
    )
    solicitud = db.get_solicitud(id_caso) or solicitud
    contenido = solicitud.get("contenido") or {}
    diag = contenido.get("diagramaFlujo") or meta
    if notas:
        diag["notas"] = notas
        meta["notas"] = notas
    diag["fuente"] = "conocimiento+analisis"
    contenido["diagramaFlujo"] = diag
    solicitud["contenido"] = contenido
    db.guardar_solicitud(id_caso, solicitud)
    meta["fuente"] = "conocimiento+analisis"
    meta["procesoId"] = ctx.get("procesoId")
    meta["aviso"] = ctx.get("aviso")
    fragmento = diagflujo.render_fragmento(ctx)
    incrustado = _actualizar_dictamen_diagrama(
        id_caso, meta["nombre"], ctx.get("procesoId") or "", fragmento=fragmento
    )
    meta["dictamenIncrustado"] = bool(incrustado)
    meta["sidecar"] = f"dictamenes/{id_caso}-flujo.html"
    ahora = datetime.now().isoformat(timespec="seconds")
    db.append_chat(
        id_caso,
        {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "d",
            "autor": "sistema",
            "texto": (
                f"Diagrama de flujo generado desde conocimiento/{ctx.get('procesoId')}/ "
                f"y el análisis del REQ. Quedó **adjunto en el dictamen** (sección 4.5) "
                f"y en dictamenes/{id_caso}-flujo.html."
            ),
            "fecha": ahora,
        },
    )
    return meta, ctx


def _generar_y_guardar_mockups_caso(id_caso, notas=""):
    db = get_db()
    solicitud = db.get_solicitud(id_caso)
    if not solicitud:
        raise ValueError("No hay solicitud en disco para este caso. Active el análisis (Fase 1) primero.")
    archivos = mockgen.generar_archivos(solicitud, notas=notas)
    if not archivos:
        raise ValueError("No se generó ningún mockup para este caso.")
    nombres = []
    for nombre, html in archivos:
        _guardar_mockup_html(id_caso, html, nombre, reemplazar=True)
        nombres.append(nombre)
    try:
        mockzip.empaquetar_mockups_caso(id_caso)
    except OSError:
        pass
    solicitud = db.get_solicitud(id_caso) or solicitud
    contenido = dict(solicitud.get("contenido") or {})
    if notas:
        contenido["mockupsNotas"] = notas
    contenido["mockupsFuente"] = "conocimiento+analisis"
    solicitud["contenido"] = contenido
    db.guardar_solicitud(id_caso, solicitud)
    ahora = datetime.now().isoformat(timespec="seconds")
    lista = ", ".join(f"`activo/{id_caso}/mockups/{n}`" for n in nombres)
    db.append_chat(
        id_caso,
        {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "m",
            "autor": "sistema",
            "texto": (
                f"Mockups generados **alineados a la propuesta de desarrollo** (no a la captura del problema): {lista}. "
                f"Quedan registrados en solicitud.json → contenido.mockups (correo y dictamen)."
            ),
            "fecha": ahora,
        },
    )
    return nombres


def _fmt_imagenes_analisis(id_caso, solicitud):
    imgs = ((solicitud or {}).get("contenido") or {}).get("imagenesAnalisis") or []
    if not imgs:
        return ""
    lines = []
    for img in imgs:
        nombre = (img.get("nombre") or "").strip()
        if nombre:
            lines.append(f"   - activo/{id_caso}/imagenes/{nombre}")
    if not lines:
        return ""
    return (
        f"4. **Capturas para análisis** — lea las imágenes en:\n"
        + "\n".join(lines)
        + "\n   Contraste pantallazos con Qrystalos2 y el REQ."
    )


def _fmt_metodos_documentados(metodos):
    lines = []
    for m in metodos or []:
        if not isinstance(m, dict):
            continue
        sp = (m.get("sp") or "").strip()
        met = (m.get("metodo") or "").strip()
        est = (m.get("estado") or "?").strip()
        if sp or met:
            lines.append(f"- {sp} · {met} (estado: {est})")
    return "\n".join(lines) if lines else "- (ninguno)"


def _build_instruccion(solicitud):
    id_caso = solicitud.get("identificacion", {}).get("idCaso", "")
    id_req = solicitud.get("identificacion", {}).get("idReq", "")
    cola = solicitud.get("cola", {}).get("rutaCola") or "cola/"
    sql = solicitud.get("sql") or {}
    sql_list = sql.get("archivosEsperados") or []
    usar_doc = bool(sql.get("usarDocumentacion"))
    metodos = sql.get("metodosDocumentados") or []
    proceso_id = (sql.get("procesoId") or "").strip()
    proceso_path = f"conocimiento/{proceso_id}/sps.json" if proceso_id else "conocimiento/<proceso>/sps.json"

    img_bloque = _fmt_imagenes_analisis(id_caso, solicitud)
    arch_bloque = _fmt_archivos_analisis(id_caso, solicitud)
    diag_bloque = _fmt_diagrama_flujo(id_caso, solicitud)
    extras = sum(1 for b in (img_bloque, arch_bloque) if b)
    paso_sql = 4 + extras
    paso_q2 = paso_sql + 1

    carpeta_sql = f"activo/{id_caso}/sql"
    if usar_doc and metodos:
        sql_bloque = f"""{paso_sql}. **SQL — métodos documentados** (no exigir `{carpeta_sql}/` de entrada)
   - Catálogo: `{proceso_path}`
   - Carpeta de ESTE análisis: `{carpeta_sql}/` (no usar la carpeta compartida `sql/`).
   - Métodos del formulario:
{_fmt_metodos_documentados(metodos)}
   - Lea esas fichas (`hace`, `valida`, `noValida`, `errores`, `llama`, `efecto`).
   - **No se detenga** porque `{carpeta_sql}/` esté vacío si esos METODO cubren el REQ.
   - En el **Chat del caso** (`activo/{id_caso}/chat.json`), en el primer resumen, indique si hace falta el .sql de hoy:
     - La ficha `leido` sirve para clasificar. Si la solución **cambia** ese procedimiento, baje igual el cuerpo de ESE METODO a `{carpeta_sql}/` y cite el bloque de hoy y el sugerido. El resumen de la ficha no reemplaza el bloque.
     - Alguno `listado` / `no_leido` / `parcial`, o el REQ toca validaciones no documentadas → **bajar** el .sql a `{carpeta_sql}/` (`python scripts/sqlix_bajar_objeto.py --caso {id_caso} NOMBRE`).
   - No invente METODOs que no estén en `sps.json`.
{paso_q2}. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)"""
        detener = f"Si falta cola, aclaración, o el Chat concluye que hay que releer el SP: **bajar** el .sql a `{carpeta_sql}/`. No lo deje en `sql/`."
    else:
        lista = ", ".join(sql_list) if sql_list else "(ver manifest de esa carpeta)"
        sql_bloque = f"""{paso_sql}. `{carpeta_sql}/` — scripts de ESTE caso: {lista}
   No lea ni escriba la carpeta compartida `sql/` (es de Documentar y mezcla otros análisis).
{paso_q2}. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)"""
        detener = f"Si falta algún SQL, imagen, HTML en cola o aclaración: **DETENER y pedirla**. El .sql de este caso va en `{carpeta_sql}/`."

    img_seccion = f"{img_bloque}\n" if img_bloque else ""
    arch_seccion = f"{arch_bloque}\n" if arch_bloque else ""
    diag_seccion = f"{diag_bloque}\n" if diag_bloque else ""

    return f"""# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/{id_caso}/solicitud.json` — formulario completo
2. `activo/{id_caso}/chat.json` — mensajes del coordinador (releer en cada turno)
3. `{cola}` — HTML avalasesor (cola)
{img_seccion}{arch_seccion}{diag_seccion}{sql_bloque}

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

{detener}

## Caso
- **ID caso:** {id_caso}
- **ID REQ:** {id_req}
- **Dictamen:** dictamenes/{id_caso}.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución concreta** en `contenido.planteamiento` (clasificación capacitación | defecto | hueco, flujo de hoy, causa citada, cambio por capa). Vuelque eso en criteriosAceptacion, alcance, restricciones, analisis y recomendacion, más la lista de SP/METODO **de este cambio** (no el catálogo del módulo). Si el fix es SQL, `contenido.cambioPropuestoSql` trae el bloque de hoy (`---ANTES---`) y el sugerido (`---SUGERIDO---`), leídos del cuerpo del METODO. Un resumen del pedido no cierra el análisis.
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/{id_caso}.html`.
5. Si usó métodos documentados: veredicto breve de releer o no el .sql de hoy.
6. **Mockup UX:** si genera o ajusta `activo/{id_caso}/mockups/`, pinte la **ventana propuesta** (`cambioPropuestoSimple`, criterios, recomendación), no la captura del error ni un control de otro REQ. `imagenes/` es solo referencia «Hoy».

## Chat
El coordinador escribe **solo** en la app (pestaña Chat → `chat.json`).
No pida que pegue el mismo texto en Cursor. Relea `chat.json` en cada turno y responda ahí (autor: `agente`).

## Contabilidad
Si `solicitud.json` → `contenido.contabilidad.afecta` es true, valide cómoAfecta y desarrollo
contra Qrystalos2 (MCUE, CON, MCPE) y documentación. Escriba el veredicto en el Chat y en
`contenido.contabilidad.validacion`. Si **no afecta**, en el dictamen HTML deje solo
«Afecta contabilidad: No». No ponga Cómo lo afecta, Desarrollo contable ni Validación del agente.

## Cierre fase 1
Cuando el coordinador apruebe → botón **Cerrar fase 1** en la app.
"""


def _historico_estado(id_caso, estado_caso, dictamen_exists, aprobado_exists):
    try:
        mail = get_db().caso_tiene_correo(id_caso, (estado_caso or {}).get("idReq") or "")
        if mail.get("enviado"):
            return "enviado"
    except Exception:
        pass
    if aprobado_exists or estado_caso.get("fase1Cerrada"):
        return "aprobado"
    if dictamen_exists:
        return "dictamen"
    if estado_caso.get("fase") or estado_caso.get("activadoEn"):
        return "en_analisis"
    return "pendiente"


def _build_historico_from_disk():
    by_id = {}

    registro_path = os.path.join(HISTORICO_ROOT, "registro.json")
    for item in _read_json_file(registro_path, []):
        id_caso = item.get("idCaso")
        if id_caso:
            by_id[id_caso] = item

    if os.path.isdir(ACTIVO_ROOT):
        for name in sorted(os.listdir(ACTIVO_ROOT)):
            caso_dir = os.path.join(ACTIVO_ROOT, name)
            if not os.path.isdir(caso_dir):
                continue
            sol_path = os.path.join(caso_dir, "solicitud.json")
            if not os.path.isfile(sol_path):
                continue
            sol = _read_json_file(sol_path, {})
            ident = sol.get("identificacion") or {}
            proyecto = sol.get("proyecto") or {}
            cola = sol.get("cola") or {}
            id_caso = ident.get("idCaso") or name
            estado_caso = _read_json_file(os.path.join(caso_dir, "estado.json"), {})
            dictamen_exists = os.path.isfile(os.path.join(DICTAMENES_ROOT, f"{id_caso}.html"))
            aprobado_exists = os.path.isdir(os.path.join(APROBADOS_ROOT, id_caso))

            prev = by_id.get(id_caso, {})
            row = {
                "idCaso": id_caso,
                "idReq": ident.get("idReq", ""),
                "proyecto": proyecto.get("nombre", ""),
                "modulo": proyecto.get("modulo", ""),
                "fecha": ident.get("fecha", ""),
                "estado": _historico_estado(id_caso, estado_caso, dictamen_exists, aprobado_exists),
                "dictamenPath": f"dictamenes/{id_caso}.html",
                "aprobadoPath": f"aprobados/{id_caso}/",
                "archivoCola": cola.get("archivoCola", ""),
                "notas": prev.get("notas", ""),
                "actualizado": estado_caso.get("activadoEn") or prev.get("actualizado") or datetime.now().isoformat(timespec="seconds"),
            }
            by_id[id_caso] = {**prev, **row}

    if os.path.isdir(DICTAMENES_ROOT):
        for fname in sorted(os.listdir(DICTAMENES_ROOT)):
            if not fname.lower().endswith(".html"):
                continue
            id_caso = fname[:-5]
            if id_caso in by_id:
                continue
            by_id[id_caso] = {
                "idCaso": id_caso,
                "idReq": "",
                "proyecto": "",
                "modulo": "",
                "fecha": "",
                "estado": "dictamen",
                "dictamenPath": f"dictamenes/{fname}",
                "aprobadoPath": f"aprobados/{id_caso}/",
                "archivoCola": "",
                "notas": "",
                "actualizado": datetime.now().isoformat(timespec="seconds"),
            }

    items = list(by_id.values())
    items.sort(key=lambda x: (x.get("actualizado") or x.get("fecha") or ""), reverse=True)
    return items


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = False


class QrystalosBAHandler(SimpleHTTPRequestHandler):
    timeout = 30

    def handle_one_request(self):
        try:
            super().handle_one_request()
        except Exception as exc:
            print(f"ERROR petición {self.path}: {exc}", flush=True)
            try:
                if (self.path or "").startswith("/api/"):
                    return self._json({"ok": False, "error": str(exc)}, 500)
                self.send_error(500, explain=str(exc))
            except Exception:
                pass

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}", flush=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]

        if parts == ["api", "kb", "buscar"]:
            q = (parse_qs(parsed.query).get("q") or [""])[0]
            return self._json(kb_buscar.buscar(q))

        if parts == ["api", "kb", "handoffs"]:
            rol = (parse_qs(parsed.query).get("rol") or [""])[0]
            try:
                items = kb_handoff.abiertos_para(rol) if rol else kb_handoff.leer()
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)
            return self._json({"ok": True, "items": items})

        if parts == ["api", "agentes"]:
            return self._json(self._payload_agentes())
        
        # GET /api/capacitacion/temas
        if parts == ["api", "capacitacion", "temas"]:
            temas_data = capbloques.cargar_temas()
            return self._json({"ok": True, "temas": temas_data.get("temas", [])})
        
        # GET /api/capacitacion/bloques?tema=inventario
        if parts == ["api", "capacitacion", "bloques"]:
            tema_id = (parse_qs(parsed.query).get("tema") or [""])[0]
            if tema_id:
                bloques = capbloques.listar_bloques_por_tema(tema_id)
            else:
                bloques = capbloques.listar_bloques()
            return self._json({"ok": True, "bloques": bloques})
        
        # GET /api/capacitacion/bloque/{id}
        if len(parts) == 4 and parts[:3] == ["api", "capacitacion", "bloque"]:
            bloque_id = unquote(parts[3])
            bloque = capbloques.obtener_bloque(bloque_id)
            if bloque:
                contenido = capbloques.leer_contenido_bloque(bloque_id)
                return self._json({"ok": True, "bloque": bloque, "contenido": contenido})
            else:
                return self._json({"ok": False, "error": "Bloque no encontrado"}, 404)

        if parts == ["api", "servidores", "estado"]:
            token = self.headers.get("X-Ba-Sesion") or ""
            return self._json({
                "ok": True,
                "configurado": servidores_admin.configurado(),
                "sesion": servidores_admin.sesion_valida(token),
            })

        if parts == ["api", "servidores"]:
            if not self._exige_sesion_servidores():
                return None
            return self._json({"ok": True, "servidores": servidores_admin.listar()})

        if len(parts) >= 2 and parts[0] == "api" and parts[1] == "health":
            db = get_db()
            return self._json({
                "ok": True,
                "version": 4,
                "db": db.db_path,
                "features": ["sql", "caso", "chat", "documentos", "historico", "cola", "borrador", "chatSinOpenAI", "cursorBot", "desarrolladores", "correo", "conocimiento", "criteriosAgente", "imagenesAnalisis", "archivosAnalisis", "diagramaFlujo", "solicitarReq", "auditoriaProcesos", "revisarSql", "informeContab"],
                "openai": {"configurado": False, "deshabilitado": True, "motivo": "Los textos del formulario los escribe el agente (Cursor)."},
                "cursorBot": {
                    "configurado": bool(load_api_key()),
                    **cursor_key_status(),
                    **modelo_report(),
                },
                "agentes": {
                    "analista": "por caso en activo/",
                    "consultas": leer_estado_bot(CONSULTAS_ID),
                    "documentar": leer_estado_bot(DOCUMENTAR_ID),
                    "vigilante": kb.load_vigilante(),
                    "valle": kb.siguiente_valle(),
                },
                "carpetaDialogo": solreq.servidor_puede_dialogo_carpeta(),
            })

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "openai":
            return self._json({
                "configurado": False,
                "deshabilitado": True,
                "motivo": "OpenAI retirado del formulario. Criterios y textos los escribe el agente.",
            })

        if parts == ["api", "solicitar"]:
            return self._json({"ok": True, "items": solreq.listar()})

        if len(parts) == 3 and parts[0] == "api" and parts[1] == "solicitar" and parts[2] == "carpetas-sugeridas":
            qs = parse_qs(parsed.query or "")
            sid = (qs.get("sr") or qs.get("id") or [""])[0]
            return self._json({"ok": True, "rutas": solreq.rutas_carpeta_sugeridas(unquote(sid))})

        if len(parts) == 3 and parts[0] == "api" and parts[1] == "solicitar":
            sid = unquote(parts[2])
            data = solreq.load(sid)
            if not data:
                return self._json({"error": "Solicitud no encontrada"}, 404)
            try:
                estado_doc = solreq.estado_documento(sid)
            except ValueError:
                estado_doc = None
            panel = solreq.panel_chat(sid)
            return self._json({
                "ok": True,
                "solicitud": data,
                "chat": panel.get("chat") or solreq.load_chat(sid),
                "bot": leer_estado_bot(sid),
                "estadoDocumento": estado_doc,
                "analisisLanzado": panel.get("analisisLanzado"),
                "documentos": panel.get("documentos") or [],
                "mockups": panel.get("mockups") or [],
                "diagrama": panel.get("diagrama"),
                "entregables": panel.get("entregables") or [],
                "archivos": panel.get("archivos") or [],
            })

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "documento" and parts[4] == "estado":
            return self._get_solicitar_documento_estado(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "documento":
            return self._serve_solicitar_documento(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "archivo":
            return self._serve_solicitar_archivo(unquote(parts[2]), unquote(parts[4]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "mockup":
            return self._serve_solicitar_mockup(unquote(parts[2]), unquote(parts[4]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "diagrama":
            return self._serve_solicitar_asset(unquote(parts[2]), "diagramas", unquote(parts[4]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "plataforma":
            return self._serve_solicitar_asset(unquote(parts[2]), "plataforma", unquote(parts[4]))

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "historico":
            return self._get_historico()

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "cola":
            return self._get_cola()

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "casos-activos":
            return self._list_casos_activos()

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "desarrolladores":
            return self._get_desarrolladores()

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "correo":
            return self._get_correo()

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "borrador":
            return self._get_borrador()

        if parts[:2] == ["api", "conocimiento"] and (len(parts) == 2 or (len(parts) == 3 and not parts[2])):
            qs = parse_qs(parsed.query)
            canal = (qs.get("canal") or ["documentar"])[0]
            proceso = (qs.get("procesoId") or [""])[0]
            data = kb.resumen(canal, proceso)
            sid = ((data.get("chat") or {}).get("id") or "").strip()
            # Estado del bot de ESTE chat (no el del canal: eso cruzaba chats).
            data["bot"] = leer_estado_bot(kb.bot_id(canal, sid) if sid else kb.bot_id(canal))
            return self._json(data)

        if len(parts) >= 4 and parts[0] == "api" and parts[1] == "conocimiento" and parts[2] == "proceso":
            proc = kb.load_proceso(unquote(parts[3]))
            if not proc:
                return self._json({"error": "Proceso no encontrado"}, 404)
            return self._json({"ok": True, "proceso": proc})

        if len(parts) >= 2 and parts[0] == "api" and parts[1] == "sql":
            qs = parse_qs(parsed.query)
            id_caso = (qs.get("idCaso") or [""])[0].strip()
            return self._list_sql(id_caso)

        if parts == ["api", "auditoria", "servidores"]:
            return self._json({"ok": True, "servidores": audproc.listar_servidores()})

        if parts == ["api", "informe-contab", "servidores"]:
            return self._json({"ok": True, "servidores": audproc.listar_servidores()})

        if parts == ["api", "informe-contab", "sesiones"]:
            return self._json({"ok": True, "sesiones": icinforme.listar_sesiones()})

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "meta":
            sid = unquote(parts[2])
            try:
                return self._json({"ok": True, "meta": icinforme.leer_meta(sid)})
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Sesión no encontrada."}, 404)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "chat":
            sid = unquote(parts[2])
            try:
                return self._json(icinforme.leer_chat(sid))
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Sesión no encontrada."}, 404)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "html":
            return self._serve_informe_contab_html(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "pdf":
            return self._serve_informe_contab_pdf(unquote(parts[2]), parsed)

        if parts == ["api", "informe-contab", "bases"]:
            qs = parse_qs(parsed.query or "")
            servidor_id = (qs.get("servidorId") or [""])[0].strip()
            if not servidor_id:
                return self._json({"ok": False, "error": "Indique servidorId."}, 400)
            try:
                import servidores_admin

                bases = servidores_admin.listar_bases_sql(servidor_id)
                return self._json({"ok": True, "servidorId": servidor_id, "bases": bases, "origen": "sql"})
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)
            except RuntimeError as exc:
                return self._json({"ok": False, "error": str(exc)}, 502)
            except Exception as exc:
                return self._json({"ok": False, "error": str(exc)}, 500)

        if parts == ["api", "prueba-req", "pruebas"]:
            return self._json({"ok": True, "pruebas": prreq.listar_pruebas()})

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "panel":
            pid = unquote(parts[2])
            try:
                return self._json({"ok": True, **prreq.panel_prueba(pid)})
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "html":
            return self._serve_prueba_req_html(unquote(parts[2]))

        if parts == ["api", "soporte-consultas", "gemini"]:
            return self._json({"ok": True, **gemini_ilustracion.estado()})

        if parts == ["api", "soporte-consultas", "consultas"]:
            return self._json({"ok": True, "consultas": scconsulta.listar_consultas()})

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "meta":
            sid = unquote(parts[2])
            try:
                return self._json({"ok": True, "meta": scconsulta.leer_meta(sid)})
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "chat":
            sid = unquote(parts[2])
            try:
                return self._json(scconsulta.leer_chat(sid))
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "html":
            return self._serve_soporte_consulta_html(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "pdf":
            return self._serve_soporte_consulta_pdf(unquote(parts[2]), parsed)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "panel":
            sid = unquote(parts[2])
            try:
                return self._json({"ok": True, **scconsulta.panel_consulta(sid)})
            except FileNotFoundError:
                return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "imagen":
            return self._serve_soporte_consulta_imagen(unquote(parts[2]), unquote(parts[4]))

        if parts == ["api", "informe-contab", "clinica"]:
            qs = parse_qs(parsed.query or "")
            servidor_id = (qs.get("servidorId") or [""])[0].strip()
            database = (qs.get("database") or [""])[0].strip()
            if not servidor_id or not database:
                return self._json({"ok": False, "error": "Indique servidorId y database."}, 400)
            try:
                from informe_errores_contab import leer_institucion_clinica

                info = leer_institucion_clinica(servidor_id, database)
                return self._json({"ok": True, **info})
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)
            except RuntimeError as exc:
                return self._json({"ok": False, "error": str(exc)}, 502)
            except Exception as exc:
                return self._json({"ok": False, "error": str(exc)}, 500)

        if parts == ["api", "auditoria", "flujos"]:
            return self._json({"ok": True, "flujos": audproc.listar_flujos()})

        if parts == ["api", "auditoria", "procedencias-contab"]:
            return self._json(
                {
                    "ok": True,
                    "procedencias": audproc.listar_procedencias_contab(),
                    "tiposReferencia": audproc.listar_tipos_referencia_contab(),
                }
            )

        if parts == ["api", "auditoria", "tipos-referencia-contab"]:
            return self._json({"ok": True, "tipos": audproc.listar_tipos_referencia_contab()})

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "auditoria" and parts[2] == "flujo":
            flujo_id = unquote(parts[3])
            if flujo_id not in audproc.FLUJO_IDS:
                return self._json({"ok": False, "error": "Flujo no documentado."}, 404)
            doc = audproc.cargar_flujo_documentacion(flujo_id)
            return self._json({"ok": True, **doc})

        if parts == ["api", "sql-revisar"]:
            return self._json({"ok": True, "items": sql_revisar.listar()})

        if len(parts) == 3 and parts[0] == "api" and parts[1] == "sql-revisar" and parts[2] == "buscar":
            qs = parse_qs(parsed.query or "")
            q = (qs.get("q") or [""])[0]
            try:
                return self._json({"ok": True, "archivos": sql_revisar.buscar_local(unquote(q))})
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)

        if len(parts) == 3 and parts[0] == "api" and parts[1] == "sql-revisar":
            id_rev = unquote(parts[2])
            if not sql_revisar.id_valido(id_rev):
                return self._json({"error": "Revisión no encontrada"}, 404)
            try:
                data = sql_revisar.vista(id_rev)
            except (OSError, json.JSONDecodeError, ValueError):
                return self._json({"error": "Revisión no encontrada"}, 404)
            data["ok"] = True
            return self._json(data)

        if parts == ["api", "auditoria", "runbook"]:
            qs = parse_qs(parsed.query or "")
            flujo_rb = (qs.get("flujoId") or ["flujo-compras-inv-cxp-caja"])[0].strip()
            try:
                if flujo_rb == "flujo-recaudos-cartera-contab":
                    md = audproc.leer_runbook_recaudos_markdown()
                    meta = audproc.meta_runbook_recaudos()
                elif flujo_rb == "flujo-rad-cxc-contab":
                    md = audproc.leer_runbook_radicacion_markdown()
                    meta = audproc.meta_runbook_radicacion()
                elif flujo_rb == "flujo-bmov-contab":
                    md = audproc.leer_runbook_bmov_markdown()
                    meta = audproc.meta_runbook_bmov()
                elif flujo_rb == "flujo-nomina-contab":
                    md = audproc._leer_proceso_md(audproc.NOMINA_DIR)
                    meta = audproc.meta_runbook_nomina()
                elif flujo_rb == "flujo-anticipos-contab":
                    md = audproc._leer_proceso_md(audproc.ANTICIPOS_DIR)
                    meta = audproc.meta_runbook_anticipos()
                elif flujo_rb == "flujo-iact-contab":
                    md = audproc._leer_proceso_md(audproc.IACT_DIR)
                    meta = audproc.meta_runbook_iact()
                elif flujo_rb == "flujo-legalizacion-contab":
                    md = audproc._leer_proceso_md(audproc.FLEG_DIR)
                    meta = audproc.meta_runbook_legalizacion()
                elif flujo_rb == "flujo-cesiones-contab":
                    md = audproc._leer_proceso_md(audproc.CESIONES_DIR)
                    meta = audproc.meta_runbook_cesiones()
                elif flujo_rb == "flujo-ajdep-contab":
                    md = audproc._leer_proceso_md(audproc.AJDEP_DIR)
                    meta = audproc.meta_runbook_ajdep()
                elif flujo_rb == "flujo-reversos-contab":
                    md = audproc._leer_proceso_md(audproc.REVERSOS_DIR)
                    meta = audproc.meta_runbook_reversos()
                elif flujo_rb == "flujo-cierre-periodo-contab":
                    md = audproc._leer_proceso_md(audproc.CIERRE_DIR)
                    meta = audproc.meta_runbook_cierre_periodo()
                else:
                    md = audproc.leer_runbook_markdown()
                    meta = audproc.meta_runbook_soporte()
            except FileNotFoundError as exc:
                return self._json({"ok": False, "error": str(exc)}, 404)
            return self._json({"ok": True, "markdown": md, **meta})

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "chat":
            return self._get_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "estado":
            return self._get_estado(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "solicitud":
            return self._get_solicitud(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "documentos":
            return self._get_documentos(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "mockups":
            return self._get_mockups(unquote(parts[2]), parsed)

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "dictamen":
            return self._serve_dictamen(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "imagen":
            return self._serve_imagen(unquote(parts[2]), unquote(parts[4]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "archivo":
            return self._serve_archivo(unquote(parts[2]), unquote(parts[4]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("diagrama", "diagramas"):
            return self._serve_diagrama(unquote(parts[2]), unquote(parts[4]))

        if parsed.path in ("", "/"):
            self.send_response(302)
            self.send_header("Location", "/app/")
            self.end_headers()
            return

        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]

        if parts[:3] == ["api", "kb", "handoffs"] or parts == ["api", "kb", "indice"]:
            return self._post_kb(parts)

        if parts == ["api", "agentes"]:
            return self._post_agentes()
        
        # POST /api/capacitacion/generar-bloque
        if parts == ["api", "capacitacion", "generar-bloque"]:
            try:
                body = self._read_json_body()
            except json.JSONDecodeError:
                return self._json({"error": "JSON inválido"}, 400)
            
            resultado = capbloques.generar_bloque_desde_control(
                body.get("procesoId", ""),
                body.get("controlId", ""),
                body.get("capaNumero"),
                body.get("forzar", False)
            )
            return self._json(resultado, 200 if resultado.get("ok") else 400)
        
        # POST /api/capacitacion/generar-ilustracion
        if parts == ["api", "capacitacion", "generar-ilustracion"]:
            try:
                body = self._read_json_body()
            except json.JSONDecodeError:
                return self._json({"error": "JSON inválido"}, 400)
            
            resultado = capbloques.generar_ilustracion_bloque(
                body.get("bloqueId", ""),
                body.get("regenerar", False)
            )
            return self._json(resultado, 200 if resultado.get("ok") else 400)
        
        # POST /api/capacitacion/ensamblar
        if parts == ["api", "capacitacion", "ensamblar"]:
            try:
                body = self._read_json_body()
            except json.JSONDecodeError:
                return self._json({"error": "JSON inválido"}, 400)
            
            resultado = capensamblar.ensamblar_documento(
                body.get("temaId", ""),
                body.get("bloquesIds", []),
                body.get("titulo"),
                body.get("formato", "html"),
                body.get("incluirIndice", True),
                body.get("incluirImagenes", True),
                body.get("audiencia", "usuario-final")
            )
            return self._json(resultado, 200 if resultado.get("ok") else 400)
        
        # POST /api/capacitacion/generar-pdf
        # Genera PDF en servidor con Edge/Chrome headless
        if parts == ["api", "capacitacion", "generar-pdf"]:
            try:
                body = self._read_json_body()
            except json.JSONDecodeError:
                return self._json({"error": "JSON inválido"}, 400)
            
            # Ensamblar documento en formato PDF
            resultado = capensamblar.ensamblar_documento(
                body.get("temaId", ""),
                body.get("bloquesIds", []),
                body.get("titulo"),
                formato="pdf",  # Forzar formato PDF
                incluir_indice=body.get("incluirIndice", True),
                incluir_imagenes=body.get("incluirImagenes", True),
                audiencia=body.get("audiencia", "usuario-final")
            )
            return self._json(resultado, 200 if resultado.get("ok") else 400)

        if parts == ["api", "servidores", "entrar"]:
            return self._post_servidores_entrar()

        if parts == ["api", "servidores", "salir"]:
            return self._post_servidores_salir()

        if parts == ["api", "servidores", "detalle"]:
            return self._post_servidores_detalle()

        if parts == ["api", "servidores", "guardar"]:
            return self._post_servidores_guardar()

        if parts == ["api", "servidores", "quitar"]:
            return self._post_servidores_quitar()

        if parts == ["api", "servidores", "traer-qrystalos2"]:
            return self._post_servidores_traer()

        if parts == ["api", "servidores", "listar-bases"]:
            return self._post_servidores_listar_bases()

        if parts == ["api", "sql", "archivar"]:
            return self._archivar_sql()

        if parts == ["api", "solicitar"]:
            return self._post_solicitar()

        if parts == ["api", "solicitar", "elegir-carpeta"]:
            return self._post_solicitar_elegir_carpeta()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "analizar":
            return self._post_solicitar_analizar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "documento":
            return self._post_solicitar_documento(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "export-plataforma":
            return self._post_solicitar_export_plataforma(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "chat":
            return self._post_solicitar_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "cerrar":
            return self._post_solicitar_cerrar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "reabrir":
            return self._post_solicitar_reabrir(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "archivo":
            return self._post_solicitar_archivo(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "mockups" and parts[4] == "generar":
            return self._post_solicitar_mockups_generar(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "solicitar" and parts[3] == "diagramas" and parts[4] == "generar":
            return self._post_solicitar_diagrama_generar(unquote(parts[2]))

        if parts == ["api", "caso", "activar"]:
            return self._activar_caso()

        if parts == ["api", "historico"]:
            return self._post_historico()

        if parts == ["api", "cola"]:
            return self._post_cola()

        if parts == ["api", "cola", "html"]:
            return self._post_cola_html()

        if parts == ["api", "desarrolladores"]:
            return self._post_desarrolladores()

        if parts == ["api", "correo"]:
            return self._post_correo()

        if parts == ["api", "borrador"]:
            return self._post_borrador()

        if parts == ["api", "sql-revisar", "elegir-archivo"]:
            return self._post_sql_revisar_elegir()

        if parts == ["api", "sql-revisar", "subir"]:
            return self._post_sql_revisar_subir()

        if parts == ["api", "sql-revisar"]:
            return self._post_sql_revisar()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "sql-revisar" and parts[3] == "chat":
            return self._post_sql_revisar_chat(unquote(parts[2]))

        if parts == ["api", "auditoria", "trazar"]:
            return self._post_auditoria_trazar()

        if parts == ["api", "auditoria", "usvgs"]:
            return self._post_auditoria_usvgs()

        if parts == ["api", "auditoria", "movimientos-inventario"]:
            return self._post_auditoria_movimientos_inventario()

        if parts == ["api", "auditoria", "config-contabilidad"]:
            return self._post_auditoria_config_contabilidad()

        if parts == ["api", "informe-contab", "sesion"]:
            return self._post_informe_contab_sesion()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "generar":
            return self._post_informe_contab_generar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "chat":
            return self._post_informe_contab_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "informe-contab" and parts[3] == "pdf":
            return self._post_informe_contab_pdf(unquote(parts[2]))

        if parts == ["api", "prueba-req", "prueba"]:
            return self._post_prueba_req_nueva()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "chat":
            return self._post_prueba_req_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "probar":
            return self._post_prueba_req_probar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "ajustar":
            return self._post_prueba_req_ajustar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "prueba-req" and parts[3] == "cerrar":
            return self._post_prueba_req_cerrar(unquote(parts[2]))

        if parts == ["api", "soporte-consultas", "gemini"]:
            return self._post_soporte_gemini()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "ilustracion":
            return self._post_soporte_ilustracion(unquote(parts[2]))

        if parts == ["api", "soporte-consultas", "consulta"]:
            return self._post_soporte_consulta_nueva()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "chat":
            return self._post_soporte_consulta_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "imagen":
            return self._post_soporte_consulta_imagen(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "respuesta":
            return self._post_soporte_consulta_respuesta(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "documento":
            return self._post_soporte_consulta_documento(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "cerrar":
            return self._post_soporte_consulta_cerrar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "pdf":
            return self._post_soporte_consulta_pdf(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "analisis":
            return self._post_soporte_consulta_analisis(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "agente":
            return self._post_soporte_consulta_agente(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "requerimiento":
            return self._post_soporte_consulta_requerimiento(unquote(parts[2]))

        if parts == ["api", "sugerir-criterios"]:
            return self._sugerir_criterios()

        if parts == ["api", "organizar-texto"]:
            return self._organizar_texto()

        if parts == ["api", "conocimiento", "proceso"]:
            return self._post_conocimiento_proceso()

        if parts == ["api", "conocimiento", "documentar"]:
            return self._post_conocimiento_documentar()

        if parts == ["api", "conocimiento", "tarea"]:
            return self._post_conocimiento_tarea()

        if parts == ["api", "conocimiento", "pendiente"]:
            return self._post_conocimiento_pendiente()

        if parts == ["api", "conocimiento", "vigilante"]:
            return self._post_conocimiento_vigilante()

        if parts == ["api", "conocimiento", "chat"]:
            return self._post_conocimiento_chat()

        if parts == ["api", "conocimiento", "chat", "archivar"]:
            return self._post_conocimiento_chat_accion("archivar")

        if parts == ["api", "conocimiento", "chat", "nuevo"]:
            return self._post_conocimiento_chat_accion("nuevo")

        if parts == ["api", "conocimiento", "chat", "abrir"]:
            return self._post_conocimiento_chat_accion("abrir")

        if parts == ["api", "conocimiento", "faq"]:
            return self._post_conocimiento_faq()

        if parts == ["api", "conocimiento", "diagrama"]:
            return self._post_conocimiento_diagrama()

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("diagrama", "diagramas") and parts[4] == "generar":
            return self._post_diagrama_generar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "solicitud":
            return self._post_solicitud(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "mockups" and parts[4] == "subir":
            return self._post_mockup_subir(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "mockups" and parts[4] == "generar":
            return self._post_mockup_generar(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "mockups":
            return self._post_mockups(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "chat":
            return self._post_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "cerrar-fase1":
            return self._cerrar_fase1(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "imagen":
            return self._post_imagen(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "archivo":
            return self._post_archivo(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "desde-solicitud":
            return self._post_desde_solicitud(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("diagrama", "diagramas"):
            return self._post_diagrama(unquote(parts[2]))

        return self._json({"error": "Ruta no encontrada"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "imagen":
            return self._delete_imagen(unquote(parts[2]), unquote(parts[4]))
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "soporte-consultas" and parts[3] == "imagen":
            return self._delete_soporte_consulta_imagen(unquote(parts[2]), unquote(parts[4]))
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "archivo":
            return self._delete_archivo(unquote(parts[2]), unquote(parts[4]))
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("diagrama", "diagramas"):
            return self._delete_diagrama(unquote(parts[2]), unquote(parts[4]))
        return self._json({"error": "Ruta no encontrada"}, 404)

    def _read_json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if not length:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def _post_sql_revisar_subir(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            ficha = sql_revisar.guardar_subido(body.get("nombre") or "", body.get("texto") or "")
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, **ficha})

    def _post_sql_revisar_elegir(self):
        try:
            ruta = sql_revisar.elegir_archivo_sql()
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        if not ruta:
            return self._json({"ok": False, "error": "No eligió un archivo."})
        from pathlib import Path

        return self._json({"ok": True, **sql_revisar._ficha_archivo(Path(ruta))})

    def _post_sql_revisar(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            ficha = sql_revisar.preparar(
                body.get("modo") or "",
                nombre=body.get("nombre") or "",
                ruta=body.get("ruta") or "",
            )
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        bot = agentes_panel.lanzar("revisar-sql", ficha["id"], "revisar-sql")
        ficha["bot"] = bot
        ficha["ok"] = True
        return self._json(ficha)

    def _post_sql_revisar_chat(self, id_rev):
        if not sql_revisar.id_valido(id_rev):
            return self._json({"error": "Revisión no encontrada"}, 404)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        texto = (body.get("texto") or "").strip()
        if not texto:
            return self._json({"error": "Escriba la pregunta."}, 400)
        try:
            sql_revisar.append_chat(id_rev, "coordinador", texto)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 404)
        bot = agentes_panel.lanzar("revisar-sql", id_rev, "revisar-sql-chat")
        return self._json({"ok": True, "bot": bot, "revision": sql_revisar.vista(id_rev)})

    def _post_auditoria_trazar(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        flujo = (body.get("flujoId") or "flujo-compras-inv-cxp-caja").strip()
        try:
            if flujo == "flujo-compras-inv-cxp-caja":
                data = audproc.trazar_compras_oc(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                    (body.get("tipoParam") or "ordencompra").strip(),
                )
            elif flujo == "flujo-recaudos-cartera-contab":
                data = audproc.trazar_recaudos(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-rad-cxc-contab":
                data = audproc.trazar_radicacion_cxc(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-bmov-contab":
                data = audproc.trazar_bmov(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-nomina-contab":
                data = audproc.trazar_nomina_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-anticipos-contab":
                data = audproc.trazar_anticipos_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-iact-contab":
                data = audproc.trazar_iact_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-legalizacion-contab":
                data = audproc.trazar_legalizacion_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-cesiones-contab":
                data = audproc.trazar_cesiones_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-ajdep-contab":
                data = audproc.trazar_ajdep_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-reversos-contab":
                data = audproc.trazar_reversos_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            elif flujo == "flujo-cierre-periodo-contab":
                data = audproc.trazar_cierre_periodo_contab(
                    (body.get("servidorId") or "").strip(),
                    (body.get("baseDatos") or "").strip(),
                    (body.get("parametro") or "").strip(),
                )
            else:
                return self._json({"ok": False, "error": "Flujo no implementado aún."}, 400)
            return self._json(data)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_auditoria_usvgs(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            data = audproc.validar_usvgs_inventario(
                (body.get("servidorId") or "").strip(),
                (body.get("baseDatos") or "").strip(),
            )
            return self._json(data)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_auditoria_movimientos_inventario(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            data = audproc.mapa_movimientos_inventario(
                (body.get("servidorId") or "").strip(),
                (body.get("baseDatos") or "").strip(),
            )
            return self._json(data)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_auditoria_config_contabilidad(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            ref_doc = (body.get("referencia") or body.get("cnsfpag") or "").strip() or None
            tipo_raw = body.get("tipoReferencia")
            tipo_doc = (str(tipo_raw).strip() if tipo_raw is not None else "") or None
            data = audproc.validar_config_contabilidad(
                (body.get("servidorId") or "").strip(),
                (body.get("baseDatos") or "").strip(),
                (body.get("procedencia") or "CRITICO").strip(),
                ref_doc,
                tipo_doc,
            )
            return self._json(data)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_informe_contab_sesion(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        servidor_id = (body.get("servidorId") or "").strip()
        database = (body.get("database") or body.get("baseDatos") or "").strip()
        if not servidor_id or not database:
            return self._json({"ok": False, "error": "Indique servidor y base de datos."}, 400)
        institucion = (body.get("institucion") or "").strip()
        try:
            meta = icinforme.crear_sesion(servidor_id, database, institucion)
            return self._json({"ok": True, "meta": meta})
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_informe_contab_generar(self, sid):
        try:
            out = icinforme.generar_para_sesion(sid)
            return self._json(
                {
                    "ok": True,
                    "meta": out["meta"],
                    "urlHtml": f"/api/informe-contab/{sid}/html",
                }
            )
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Sesión no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_informe_contab_chat(self, sid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        texto = (body.get("texto") or "").strip()
        if not texto:
            return self._json({"error": "Mensaje vacío"}, 400)
        autor = (body.get("autor") or "coordinador").strip().lower()
        if autor not in ("coordinador", "agente"):
            autor = "coordinador"
        try:
            msg = icinforme.append_chat(sid, autor, texto)
            chat = icinforme.leer_chat(sid)
            return self._json({"ok": True, "mensaje": msg, "mensajes": chat.get("mensajes", [])})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Sesión no encontrada."}, 404)

    def _serve_informe_contab_html(self, sid):
        try:
            carp = icinforme.carpeta_sesion(sid)
        except (FileNotFoundError, ValueError) as exc:
            return self._json({"ok": False, "error": str(exc)}, 404)
        path = os.path.join(carp, "informe-errores-contables.html")
        if not os.path.isfile(path):
            return self._json({"ok": False, "error": "Informe aún no generado."}, 404)
        try:
            with open(path, "r", encoding="utf-8") as f:
                html_body = f.read()
        except OSError as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        data = html_body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'inline; filename="informe-contab-{sid}.html"')
        self.end_headers()
        self.wfile.write(data)

    def _nombre_pdf_informe_contab(self, sid):
        try:
            meta = icinforme.leer_meta(sid)
            base = (meta.get("institucion") or meta.get("database") or sid).strip()
            safe = re.sub(r"[^\w\-]+", "-", base, flags=re.UNICODE)[:60].strip("-") or sid
            return f"informe-contab-{safe}.pdf"
        except Exception:
            return f"informe-contab-{sid}.pdf"

    def _serve_informe_contab_pdf(self, sid, parsed):
        qs = parse_qs(parsed.query or "")
        forzar = (qs.get("regenerar") or [""])[0].strip() in ("1", "true", "yes")
        try:
            pdf_path = icinforme.ruta_informe_pdf(sid)
            if forzar or not pdf_path.is_file():
                icinforme.generar_pdf(sid)
            if not pdf_path.is_file():
                return self._json({"ok": False, "error": "PDF no disponible."}, 404)
            with open(pdf_path, "rb") as f:
                data = f.read()
        except FileNotFoundError as exc:
            return self._json({"ok": False, "error": str(exc)}, 404)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        nombre = self._nombre_pdf_informe_contab(sid)
        dl = (qs.get("dl") or [""])[0].strip() in ("1", "true", "yes")
        disp = "attachment" if dl else "inline"
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'{disp}; filename="{nombre}"')
        self.end_headers()
        self.wfile.write(data)

    def _post_informe_contab_pdf(self, sid):
        try:
            icinforme.generar_pdf(sid)
            pdf_path = icinforme.ruta_informe_pdf(sid)
            with open(pdf_path, "rb") as f:
                data = f.read()
        except FileNotFoundError as exc:
            return self._json({"ok": False, "error": str(exc)}, 404)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        nombre = self._nombre_pdf_informe_contab(sid)
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'attachment; filename="{nombre}"')
        self.end_headers()
        self.wfile.write(data)

    def _nombre_pdf_soporte_consulta(self, sid):
        try:
            meta = scconsulta.leer_meta(sid)
            base = (meta.get("titulo") or sid).strip()
            safe = re.sub(r"[^\w\-]+", "-", base, flags=re.UNICODE)[:50].strip("-") or sid
            return f"soporte-respuesta-{safe}.pdf"
        except Exception:
            return f"soporte-respuesta-{sid}.pdf"

    def _serve_soporte_consulta_imagen(self, sid, nombre):
        try:
            path = scconsulta._ruta_imagen(sid, nombre)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        if not path.is_file():
            return self._json({"ok": False, "error": "Imagen no encontrada."}, 404)
        ext = path.suffix.lower()
        ctype = {
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".webp": "image/webp",
            ".gif": "image/gif",
        }.get(ext, "application/octet-stream")
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _post_soporte_consulta_imagen(self, sid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            imagen = scconsulta.guardar_imagen(sid, body.get("dataUrl") or "", body.get("nombre") or "")
            return self._json({"ok": True, "imagen": imagen, "meta": scconsulta.leer_meta(sid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _delete_soporte_consulta_imagen(self, sid, nombre):
        try:
            meta = scconsulta.quitar_imagen(sid, nombre)
            return self._json({"ok": True, "meta": meta, "mensajes": scconsulta.leer_chat(sid).get("mensajes", [])})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_prueba_req_nueva(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        servidor_id = (body.get("servidorId") or "").strip()
        nombre = (body.get("servidorNombre") or "").strip()
        if not nombre and servidor_id:
            for srv in audproc.listar_servidores():
                if srv.get("id") == servidor_id:
                    nombre = srv.get("nombre") or servidor_id
                    break
        try:
            meta = prreq.crear_prueba(
                body.get("requerimiento") or "",
                body.get("justificacion") or "",
                body.get("respuestaDesarrollador") or "",
                servidor_id,
                nombre,
                body.get("baseDatos") or "",
                body.get("desarrollador") or "",
            )
            return self._json({"ok": True, "meta": meta})
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_prueba_req_chat(self, pid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            meta = prreq.leer_meta(pid)
            if meta.get("estado") == "cerrada":
                return self._json({"ok": False, "error": "La prueba ya está cerrada."}, 400)
            prreq.append_chat(pid, body.get("autor") or "coordinador", body.get("texto") or "")
            return self._json({"ok": True, **prreq.panel_prueba(pid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_prueba_req_probar(self, pid):
        try:
            meta = prreq.leer_meta(pid)
            if meta.get("estado") == "cerrada":
                return self._json({"ok": False, "error": "La prueba ya está cerrada."}, 400)
            prreq.escribir_instruccion(pid)
            prreq.append_chat(
                pid,
                "sistema",
                "El agente está contrastando: base de conocimiento, fuente, IXONLINE/SQL y la base de pruebas.",
            )
            bot = agentes_panel.lanzar("prueba-req", pid, "prueba-req")
            if not bot.get("ok"):
                prreq.append_chat(
                    pid,
                    "sistema",
                    "El agente no pudo arrancar (" + str(bot.get("error") or "error") + ").",
                )
            return self._json({"ok": True, "bot": bot, **prreq.panel_prueba(pid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_prueba_req_ajustar(self, pid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            meta = prreq.leer_meta(pid)
            if meta.get("estado") == "cerrada":
                return self._json({"ok": False, "error": "La prueba ya está cerrada."}, 400)
            nota = (body.get("texto") or "").strip()
            if nota:
                prreq.append_chat(pid, "coordinador", nota)
            prreq.escribir_instruccion(pid)
            prreq.append_chat(pid, "sistema", "El agente está ajustando el veredicto según el chat.")
            bot = agentes_panel.lanzar("prueba-req", pid, "prueba-req-chat")
            if not bot.get("ok"):
                prreq.append_chat(
                    pid,
                    "sistema",
                    "El agente no pudo arrancar (" + str(bot.get("error") or "error") + ").",
                )
            return self._json({"ok": True, "bot": bot, **prreq.panel_prueba(pid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_prueba_req_cerrar(self, pid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            meta = prreq.cerrar_prueba(pid, (body.get("veredicto") or "").strip())
            return self._json({
                "ok": True,
                "meta": meta,
                "urlHtml": f"/api/prueba-req/{pid}/html",
            })
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _serve_prueba_req_html(self, pid):
        try:
            path = prreq.ruta_html(pid)
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Prueba no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        if not path.is_file():
            return self._json({"ok": False, "error": "Cierre la prueba para generar el documento."}, 404)
        data = path.read_text(encoding="utf-8").encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'inline; filename="prueba-{pid}.html"')
        self.end_headers()
        self.wfile.write(data)

    def _post_soporte_gemini(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            return self._json({"ok": True, **gemini_ilustracion.guardar_clave(body.get("valor") or "")})
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_soporte_ilustracion(self, sid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            meta = scconsulta.leer_meta(sid)
            
            # Detectar casos de capacitación
            import capacitacion_ilustracion as cap_ilustra
            carpeta = scconsulta.carpeta_consulta(sid)
            
            if cap_ilustra._es_capacitacion(meta, carpeta):
                # Caso de capacitación: usar OpenAI
                result = cap_ilustra.generar_ilustraciones(sid, meta)
                if not result.get("ok"):
                    # Si OpenAI falla, avisar y caer al flujo normal de Cursor
                    scconsulta.append_chat(
                        sid,
                        "sistema",
                        f"No se pudo generar ilustración con OpenAI: {result.get('mensaje', 'Error desconocido')}. "
                        "Use el agente de Cursor para generar la ilustración."
                    )
                    return self._json({
                        "ok": False,
                        "error": "openai_fallback",
                        "mensaje": result.get("mensaje", "Error generando con OpenAI"),
                        "usarCursor": True
                    }, 200)
                
                return self._json(result)
            
            # Casos normales: Cursor agent
            oficial = (meta.get("respuestaOficial") or "").strip()
            if len(oficial) < 40:
                raise ValueError(
                    "Primero hace falta la respuesta oficial, tomada de la ficha, el grafo y el flujo. Sin ese guion no se dibuja."
                )
            enfasis = (body.get("prompt") or "").strip()
            pedido = (
                "Ilustración para un documento de soporte de Qrystalos. "
                "Dibuje solo los pasos que el texto cita. "
                "No agregue pantallas, botones ni pasos que el texto no mencione. "
                "Si el texto dice que algo no está documentado, no lo dibuje.\n\n"
                + oficial
            )
            if enfasis:
                pedido += "\n\nÉnfasis, solo si ya está en el texto anterior: " + enfasis[:500]
            raise ValueError(
                "La ilustración la arma el modelo de imagen de Cursor, en el agente. "
                "No se usa la API de Gemini."
            )
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, "imagen": imagen})

    def _post_soporte_consulta_nueva(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            meta = scconsulta.crear_consulta(
                body.get("titulo") or "",
                body.get("pregunta") or body.get("texto") or "",
                body.get("solicitante") or "",
                body.get("cliente") or "",
                body.get("servidorId") or "",
                body.get("baseDatos") or "",
                bool(body.get("validarEnBase")),
            )
            return self._json({"ok": True, "meta": meta})
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_soporte_consulta_chat(self, sid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        texto = (body.get("texto") or "").strip()
        autor = (body.get("autor") or "soporte").strip().lower()
        imagenes = body.get("imagenes") if isinstance(body.get("imagenes"), list) else None
        
        try:
            # Siempre guardar el mensaje del usuario inmediatamente
            msg = scconsulta.append_chat(sid, autor, texto, imagenes)
            chat = scconsulta.leer_chat(sid)
            return self._json({"ok": True, "mensaje": msg, "mensajes": chat.get("mensajes", [])})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)

    def _post_soporte_consulta_respuesta(self, sid):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            texto = body.get("respuesta") or body.get("texto") or ""
            proposito = body.get("proposito")
            meta = scconsulta.guardar_respuesta(
                sid, texto, proposito if "proposito" in body else None
            )
            return self._json(
                {
                    "ok": True,
                    "meta": meta,
                    "respuestaPreviewHtml": scconsulta.texto_respuesta_a_html(texto),
                }
            )
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

    def _post_soporte_consulta_documento(self, sid):
        try:
            _html, meta = scconsulta.generar_html_documento(sid, presentar=True)
            return self._json({"ok": True, "meta": meta, "urlHtml": f"/api/soporte-consultas/{sid}/html"})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_soporte_consulta_requerimiento(self, sid):
        try:
            result = scconsulta.generar_requerimiento(sid)
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, **result})

    def _post_soporte_consulta_cerrar(self, sid):
        try:
            meta = scconsulta.cerrar_consulta(sid)
            return self._json({"ok": True, "meta": meta})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

    def _serve_soporte_consulta_html(self, sid):
        try:
            meta = scconsulta.leer_meta(sid)
            if (meta.get("respuestaOficial") or "").strip():
                scconsulta.generar_html_documento(sid)
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        path = scconsulta.ruta_html(sid)
        if not path.is_file():
            return self._json({"ok": False, "error": "Genere el documento primero."}, 404)
        try:
            html_body = path.read_text(encoding="utf-8")
        except OSError as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        data = html_body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'inline; filename="soporte-{sid}.html"')
        self.end_headers()
        self.wfile.write(data)

    def _serve_soporte_consulta_pdf(self, sid, parsed):
        qs = parse_qs(parsed.query or "")
        try:
            scconsulta.generar_pdf(sid)
            pdf_path = scconsulta.ruta_pdf(sid)
            data = pdf_path.read_bytes()
        except FileNotFoundError as exc:
            return self._json({"ok": False, "error": str(exc)}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        nombre = self._nombre_pdf_soporte_consulta(sid)
        dl = (qs.get("dl") or [""])[0].strip() in ("1", "true", "yes")
        disp = "attachment" if dl else "inline"
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'{disp}; filename="{nombre}"')
        self.end_headers()
        self.wfile.write(data)

    def _post_soporte_consulta_analisis(self, sid):
        try:
            scconsulta.escribir_instruccion(sid)
            meta = scconsulta.leer_meta(sid)
            ahora = datetime.now().isoformat(timespec="seconds")
            if meta.get("validarEnBase"):
                pedido = (
                    "Atienda esta consulta como soporte. La respuesta abre con la causa en palabras "
                    "de la pantalla y sigue con los pasos para corregirla. Mida la base en solo lectura. "
                    "Si el tramo no está documentado, léalo, deje la ficha y, si queda más, un pendiente. "
                    "No responda con el grafo ni con «no está documentado»."
                )
                aviso = (
                    "El agente está revisando el caso en la base del cliente. La respuesta dirá la causa "
                    "y cómo corregirla en la pantalla."
                )
            else:
                pedido = (
                    "Analice esta consulta contrastando conocimiento/ (procesos, DIAN, copagos, facturación, caja, "
                    "recaudos según aplique). Redacte respuestaOficial en meta.json y resuma en el chat."
                )
                aviso = (
                    "El agente está contrastando con la base de conocimiento. En unos minutos verá la respuesta en el chat "
                    "y el borrador en «Respuesta oficial»."
                )
            scconsulta.append_chat(sid, "coordinador", pedido)
            scconsulta.append_chat(sid, "sistema", aviso)
            bot = agentes_panel.lanzar("soporte-consultas", sid, "soporte-consulta-analisis")
            if not bot.get("ok"):
                scconsulta.append_chat(
                    sid,
                    "sistema",
                    "El agente no pudo arrancar (" + str(bot.get("error") or "error") + "). Revise CURSOR_API_KEY y bot.log.",
                )
            scconsulta.actualizar_meta(sid, analisisLanzado=ahora)
            return self._json({"ok": True, "bot": bot, **scconsulta.panel_consulta(sid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)

    def _post_soporte_consulta_agente(self, sid):
        try:
            try:
                body = self._read_json_body()
            except json.JSONDecodeError:
                return self._json({"ok": False, "error": "JSON inválido"}, 400)
            nota = (body.get("texto") or "").strip()
            imagenes = body.get("imagenes") if isinstance(body.get("imagenes"), list) else None
            if nota or imagenes:
                scconsulta.append_chat(sid, "coordinador", nota, imagenes)
            scconsulta.escribir_instruccion(sid)
            scconsulta.append_chat(
                sid,
                "sistema",
                "El agente está ajustando la respuesta según el chat.",
            )
            bot = agentes_panel.lanzar("soporte-consultas", sid, "soporte-consulta-chat")
            if not bot.get("ok"):
                scconsulta.append_chat(
                    sid,
                    "sistema",
                    "El agente no pudo arrancar (" + str(bot.get("error") or "error") + ").",
                )
            return self._json({"ok": True, "bot": bot, **scconsulta.panel_consulta(sid)})
        except FileNotFoundError:
            return self._json({"ok": False, "error": "Consulta no encontrada."}, 404)

    def _post_soporte_consulta_pdf(self, sid):
        try:
            scconsulta.generar_pdf(sid)
            data = scconsulta.ruta_pdf(sid).read_bytes()
        except FileNotFoundError as exc:
            return self._json({"ok": False, "error": str(exc)}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        nombre = self._nombre_pdf_soporte_consulta(sid)
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'attachment; filename="{nombre}"')
        self.end_headers()
        self.wfile.write(data)

    def _sugerir_criterios(self):
        try:
            payload = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        if not (payload.get("requerimiento") or "").strip():
            return self._json({"ok": False, "error": "sin_requerimiento", "mensaje": "Falta el requerimiento."}, 400)
        return self._json({
            "ok": False,
            "error": "openai_retirado",
            "mensaje": "OpenAI ya no sugiere criterios. Use «Pedir criterios al agente» o el Chat.",
        }, 410)

    def _post_conocimiento_proceso(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        result = kb.create_proceso(
            body.get("nombre") or "",
            body.get("modulo") or "",
            body.get("id") or "",
        )
        return self._json(result, 200 if result.get("ok") else 400)

    def _post_conocimiento_documentar(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        result = kb.documentar_sp(
            body.get("pendienteId") or "",
            body.get("archivoSql") or "",
            body.get("notas") or "",
            body.get("procesoId") or "",
        )
        if result.get("ok"):
            result["bot"] = agentes_panel.lanzar("documentar", DOCUMENTAR_ID, "documentar")
        return self._json(result, 200 if result.get("ok") else 400)

    def _post_conocimiento_tarea(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        if body.get("abierta") is False or (body.get("accion") or "").strip().lower() in ("cerrar", "cancelar"):
            return self._json({"ok": True, "tarea": kb.cerrar_tarea()})
        return self._json({"error": "Indique accion=cerrar o abierta=false"}, 400)

    def _post_conocimiento_vigilante(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        # Barrido eliminado: siempre inactivo. Documentar solo por Chat.
        vig = kb.load_vigilante()
        vig["activo"] = False
        vig["motivoPausa"] = (
            "Barrido eliminado. Composer 2.5 estándar, sin Fast. "
            "Pregunte en Chat o pulse Documentar SP; el agente responde un turno y se detiene."
        )
        if body.get("intervaloMin"):
            try:
                vig["intervaloMin"] = max(5, int(body["intervaloMin"]))
            except (TypeError, ValueError):
                pass
        vig["actualizadoEn"] = datetime.now().isoformat(timespec="seconds")
        kb.save_vigilante(vig)
        if body.get("activo") is True:
            return self._json({
                "ok": False,
                "error": "El barrido automático ya no está disponible. Use el Chat de Documentar cuando lo necesite.",
                "vigilante": vig,
            }, 400)
        return self._json({"ok": True, "vigilante": vig, "valle": kb.siguiente_valle()})

    def _post_conocimiento_pendiente(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        estado = (body.get("estado") or "").strip()
        pid = (body.get("id") or "").strip()
        if estado and pid:
            result = kb.set_pendiente_estado(pid, estado)
            return self._json(result, 200 if result.get("ok") else 404)
        if body.get("titulo"):
            item = kb.add_pendiente(body)
            return self._json({"ok": True, "item": item})
        return self._json({"error": "Falta título o id+estado"}, 400)

    def _post_conocimiento_chat(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        texto = (body.get("texto") or "").strip()
        if not texto:
            return self._json({"error": "Falta texto"}, 400)
        autor = (body.get("autor") or "coordinador").strip().lower()
        if autor not in ("coordinador",):
            autor = "coordinador"
        proceso_id = body.get("procesoId") or ""
        canal = body.get("canal") or "documentar"
        chat_info = kb.resumen(canal, proceso_id)
        if chat_info.get("chatSoloLectura"):
            return self._json({"error": "Este chat está archivado. Cree uno nuevo o ábralo solo para leer."}, 409)
        chat_id = (body.get("chatId") or "").strip()
        destino = (
            kb.load_sesion(canal, chat_id)
            if chat_id and kb._SID_RE.match(chat_id) and os.path.isfile(kb._sesion_path(canal, chat_id))
            else {}
        )
        if chat_id and destino.get("id") == chat_id and destino.get("estado") != "archivado" and (
            not proceso_id or (destino.get("procesoId") or "") in ("", proceso_id)
        ):
            # Chat concreto: no depende de cuál está "activo" (otra pestaña pudo cambiarlo).
            kb.append_chat_sesion(canal, chat_id, autor, texto)
            sid = chat_id
        else:
            sid = (kb.append_chat(autor, texto, proceso_id, canal) or {}).get("id") or ""
        if sid:
            kb.append_chat_sesion(canal, sid, "sistema", "El agente está trabajando. En unos segundos responde aquí (autor agente).")
        else:
            kb.append_chat("sistema", "El agente está trabajando. En unos segundos responde aquí (autor agente).", proceso_id, canal)
        # Un bot y una sesión Cursor por chat: dos chats ya no comparten bot.json ni agentId.
        bid = kb.bot_id(canal, sid)
        bot = agentes_panel.lanzar(canal if canal in ("consultas", "documentar") else "documentar", bid, canal)
        if not bot.get("ok"):
            time.sleep(2)
            st = leer_estado_bot(bid)
            if st.get("estado") == "trabajando" and st.get("pidVivo"):
                bot = {"ok": True, "pid": st.get("pid"), "yaCorria": True}
            else:
                kb.append_chat(
                    "sistema",
                    "El agente no pudo arrancar ("
                    + str(bot.get("error") or "error")
                    + "). Reinicie abrir-app.bat o escriba de nuevo en Cursor.",
                    proceso_id,
                    canal,
                )
        chat = kb.load_sesion(canal, sid) if sid else kb.load_chat(canal)
        return self._json({"ok": True, "chat": chat, "bot": bot, "canal": canal, "chatId": sid})

    def _post_conocimiento_chat_accion(self, accion: str):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        canal = body.get("canal") or "documentar"
        proceso = body.get("procesoId") or ""
        if accion in ("archivar", "nuevo"):
            result = kb.nuevo_chat(canal, body.get("titulo") or "", proceso)
            return self._json(result)
        sid = (body.get("id") or "").strip()
        if not sid:
            return self._json({"error": "Falta id del chat"}, 400)
        result = kb.abrir_chat(canal, sid)
        return self._json(result, 200 if result.get("ok") else 404)

    def _post_conocimiento_faq(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        result = kb.aceptar_faq(
            body.get("canal") or "consultas",
            body.get("procesoId") or "",
            body.get("mensajeId") or "",
            body.get("chatId") or "",
        )
        return self._json(result, 200 if result.get("ok") else 400)

    def _organizar_texto(self):
        try:
            payload = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        return self._json({
            "ok": False,
            "error": "openai_retirado",
            "mensaje": "OpenAI ya no organiza textos. El agente (Cursor) asume criterios, análisis y recomendación.",
        }, 410)

    def _post_kb(self, parts):
        """POST /api/kb/indice (regenera) · /api/kb/handoffs (encola) · /api/kb/handoffs/{id} (estado)."""
        if parts == ["api", "kb", "indice"]:
            return self._json({"ok": True, "totales": kb_indice.regenerar()})
        try:
            body = self._read_json_body() or {}
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            if len(parts) == 3:
                h = kb_handoff.encolar(body.get("de") or "", body.get("para") or "conocimiento", body.get("tipo") or "", body.get("contexto") or {}, body.get("prioridad") or "media")
            else:
                hid = unquote(parts[3])
                estado = (body.get("estado") or "").strip()
                if estado == "en_progreso":
                    h = kb_handoff.tomar(hid)
                elif estado in ("respondido", "bloqueado"):
                    h = kb_handoff.responder(hid, body.get("respuesta"), bloqueado=estado == "bloqueado")
                elif estado == "cerrado":
                    h = kb_handoff.cerrar(hid)
                else:
                    return self._json({"ok": False, "error": "estado inválido"}, 400)
                if not h:
                    return self._json({"ok": False, "error": "handoff no encontrado"}, 404)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, "handoff": h})

    @staticmethod
    def _payload_agentes(extra=None):
        nombres = agentes_panel.nombres_claves()
        claves = []
        for fila in listar_claves_publicas():
            item = dict(fila)
            item["nombre"] = nombres.get(item["etiqueta"]) or ""
            claves.append(item)
        try:
            import orquesta

            reparto = orquesta.estado()
        except Exception:
            reparto = {"nota": "", "piezas": []}
        base = {
            "ok": True,
            "agentes": agentes_panel.catalogo(),
            "modeloLocal": agentes_panel.modelo_local(),
            "orquesta": reparto,
            "claves": claves,
        }
        if extra:
            base.update(extra)
        return base

    def _post_agentes(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        accion = (body.get("accion") or "").strip()
        try:
            if accion == "agregar-clave":
                etiqueta = agregar_clave_cursor(body.get("valor") or "")
                agentes_panel.nombrar_clave(etiqueta, body.get("nombre") or "")
                return self._json(self._payload_agentes({"etiqueta": etiqueta}))
            if accion == "cambiar-clave":
                etiqueta = (body.get("etiqueta") or "").strip()
                if (body.get("valor") or "").strip():
                    etiqueta = cambiar_clave_cursor(etiqueta, body.get("valor") or "")
                elif not etiqueta:
                    raise ValueError("Elija qué clave cambiar.")
                if "nombre" in body:
                    agentes_panel.nombrar_clave(etiqueta, body.get("nombre") or "")
                return self._json(self._payload_agentes({"etiqueta": etiqueta}))
            if (body.get("modeloLocal") or "").strip() and not (body.get("id") or "").strip():
                nombre = agentes_panel.asignar_modelo(body.get("modeloLocal") or "")
                return self._json(self._payload_agentes({"modeloLocal": nombre}))
            if "clave" in body and not (body.get("motor") or "").strip():
                fila = agentes_panel.asignar_clave(body.get("id") or "", body.get("clave") or "")
                return self._json(self._payload_agentes({"agente": fila}))
            fila = agentes_panel.asignar(body.get("id") or "", body.get("motor") or "")
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json(self._payload_agentes({"agente": fila}))

    def _post_solicitar(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            sol = solreq.guardar(body)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({"ok": True, "solicitud": sol})

    @staticmethod
    def _json_solicitar_export(result, panel):
        """panel_chat.archivos = adjuntos del chat; no pisar PDF/PNG del export."""
        exportados = result.get("archivos") or []
        entregables = exportados or panel.get("entregables") or []
        base = {**result, **{k: v for k, v in panel.items() if k != "archivos"}}
        base["archivos"] = exportados
        base["entregables"] = entregables
        base["archivosAdjuntos"] = panel.get("archivos") or []
        return base

    @staticmethod
    def _opciones_export_solicitud(body):
        raw = body.get("opciones") if isinstance(body.get("opciones"), dict) else {}
        return {
            "incluirDocumento": raw.get(
                "incluirDocumento",
                body.get("incluirDocumento", True),
            ),
            "incluirMockups": raw.get(
                "incluirMockups",
                body.get("incluirMockups", True),
            ),
            "incluirDiagrama": raw.get(
                "incluirDiagrama",
                body.get("incluirDiagrama", True),
            ),
        }

    def _post_solicitar_elegir_carpeta(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        inicial = (body.get("inicial") or body.get("carpeta") or "").strip()
        dialogo = solreq.servidor_puede_dialogo_carpeta()
        if not dialogo.get("disponible"):
            return self._json({
                "ok": False,
                "carpeta": "",
                "interactive": False,
                "error": dialogo.get("motivo") or "Diálogo no disponible.",
            })
        path = solreq.elegir_carpeta(inicial=inicial)
        if not path:
            return self._json({
                "ok": False,
                "carpeta": "",
                "interactive": True,
                "error": "Canceló o no se abrió la ventana. Escriba la ruta en el cuadro.",
            })
        return self._json({"ok": True, "carpeta": path, "interactive": True})

    def _post_solicitar_cerrar(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        sid_body = (body.get("solicitudId") or body.get("id") or "").strip()
        if sid_body and sid_body != id_sr:
            return self._json(
                {"error": f"Solicitud del formulario ({sid_body}) ≠ URL ({id_sr})."},
                400,
            )
        carpeta = (body.get("carpeta") or body.get("carpetaPlataforma") or "").strip()
        if not carpeta:
            carpeta = ((body.get("plataforma") or {}).get("carpeta") or "").strip()
        opciones = self._opciones_export_solicitud(body)
        try:
            sol = solreq.cerrar(id_sr, carpeta=carpeta, opciones=opciones)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        reutilizado = bool(sol.pop("_reutilizado", False))
        if reutilizado:
            nota = (
                "Solicitud cerrada. Se conservaron los archivos del último Guardar; "
                "no se volvieron a generar documento, mockup ni flujo."
            )
        else:
            nota = (
                "Solicitud cerrada. Quedaron PDF de la solicitud, PDF del mockup e imagen del flujo en solicitudes/"
                f"{id_sr}/plataforma/."
            )
        solreq.append_chat(id_sr, "sistema", nota)
        panel = solreq.panel_chat(id_sr)
        return self._json({"ok": True, "reutilizado": reutilizado, **panel, "solicitud": sol})

    def _post_solicitar_reabrir(self, id_sr):
        try:
            sol = solreq.reabrir(id_sr)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        solreq.append_chat(id_sr, "sistema", "Solicitud reabierta. Puede cerrar de nuevo para generar PDF e imagen.")
        return self._json({"ok": True, "solicitud": sol, "chat": solreq.load_chat(id_sr)})

    def _post_solicitar_analizar(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        if body:
            body["id"] = id_sr
            solreq.guardar(body)
        try:
            prep = solreq.preparar_analisis(id_sr)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        solreq.append_chat(
            id_sr,
            "coordinador",
            "Analiza esta necesidad contra conocimiento/ (proceso/sps). Complete analisis, alcance, "
            "restricciones, criterios y recomendación para el comité. Liste SOLO los SP/METODO de este "
            "cambio. No genere dictamen de implementación. Deje el resultado en este Chat y en solicitud.json.",
        )
        bot = agentes_panel.lanzar("solicitar", id_sr, "solicitar-req", "analizar")
        return self._json({"ok": True, **prep, "bot": bot})

    def _get_solicitar_documento_estado(self, id_sr):
        try:
            return self._json(solreq.estado_documento(id_sr))
        except ValueError as exc:
            return self._json({"error": str(exc)}, 404)

    def _post_solicitar_documento(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        if body:
            body["id"] = id_sr
            solreq.guardar(body)
        try:
            result = solreq.generar_documento(id_sr)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        solreq.append_chat(
            id_sr,
            "sistema",
            f"Documento de comité generado: solicitudes/{id_sr}/documento.html (copia dictamenes/{id_sr}.html).",
        )
        panel = solreq.panel_chat(id_sr)
        return self._json({**result, **panel})

    def _post_solicitar_export_plataforma(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        sid_body = (body.get("solicitudId") or body.get("id") or "").strip()
        if sid_body and sid_body != id_sr:
            return self._json(
                {
                    "error": f"La solicitud del formulario ({sid_body}) no coincide con la URL ({id_sr}). "
                    "Abra la solicitud correcta en la lista.",
                },
                400,
            )
        carpeta = (body.get("plataforma") or {}).get("carpeta") or body.get("carpetaPlataforma") or ""
        actual = solreq.load(id_sr)
        if actual and not solreq._esta_cerrada(actual) and carpeta:
            plat = dict(actual.get("plataforma") or {})
            plat["carpeta"] = carpeta
            actual["plataforma"] = plat
            try:
                solreq.guardar(actual)
            except ValueError:
                pass
        opciones = self._opciones_export_solicitud(body)
        try:
            result = solreq.generar_export_plataforma(id_sr, carpeta=carpeta, opciones=opciones)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        panel = solreq.panel_chat(id_sr)
        return self._json(self._json_solicitar_export(result, panel))

    def _post_solicitar_chat(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        texto = (body.get("texto") or "").strip()
        if not texto:
            return self._json({"error": "Falta el mensaje"}, 400)
        actual = solreq.load(id_sr)
        if not actual:
            return self._json({"error": "Guarde la solicitud primero"}, 400)
        if solreq._esta_cerrada(actual):
            return self._json({"error": "La solicitud está cerrada. El Chat queda de consulta; no se envían mensajes."}, 400)
        solreq.append_chat(id_sr, "coordinador", texto)
        bot = agentes_panel.lanzar("solicitar", id_sr, "solicitar-req", "chat")
        return self._json({"ok": True, "chat": solreq.load_chat(id_sr), "bot": bot})

    def _post_solicitar_archivo(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta = solreq.guardar_archivo(
                id_sr,
                body.get("nombre") or "",
                body.get("dataUrl") or body.get("data") or "",
                body.get("tipo") or "normativa",
            )
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        if meta.get("tipo") == "necesidad":
            bot = agentes_panel.lanzar("solicitar", id_sr, "solicitar-req", "analizar")
        else:
            bot = leer_estado_bot(id_sr)
        return self._json({"ok": True, **solreq.panel_chat(id_sr), "archivo": meta, "bot": bot})

    def _post_solicitar_mockups_generar(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        try:
            rels = solreq.generar_mockups(id_sr, notas=(body.get("notas") or "").strip())
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        panel = solreq.panel_chat(id_sr)
        return self._json({"ok": True, "mockupsGenerados": rels, **panel, "bot": leer_estado_bot(id_sr)})

    def _serve_solicitar_archivo(self, id_sr, nombre):
        safe = os.path.basename(nombre or "")
        path = os.path.join(solreq.caso_dir(id_sr), "archivos", safe)
        if not os.path.isfile(path):
            return self._json({"error": "Archivo no encontrado"}, 404)
        with open(path, "rb") as fh:
            body = fh.read()
        ext = os.path.splitext(safe)[1].lower()
        tipos = {".pdf": "application/pdf", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".txt": "text/plain; charset=utf-8", ".md": "text/plain; charset=utf-8", ".html": "text/html; charset=utf-8"}
        self.send_response(200)
        self.send_header("Content-Type", tipos.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _post_solicitar_diagrama_generar(self, id_sr):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            body = {}
        try:
            meta = solreq.generar_diagrama(id_sr, notas=(body.get("notas") or "").strip())
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        panel = solreq.panel_chat(id_sr)
        return self._json({"ok": True, "diagramaGenerado": meta, **panel})

    def _serve_solicitar_asset(self, id_sr, subdir, nombre):
        safe = os.path.basename(nombre or "")
        path = os.path.join(solreq.caso_dir(id_sr), subdir, safe)
        if not os.path.isfile(path):
            return self._json({"error": "Archivo no encontrado"}, 404)
        with open(path, "rb") as fh:
            body = fh.read()
        ext = os.path.splitext(safe)[1].lower()
        tipos = {
            ".pdf": "application/pdf",
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".html": "text/html; charset=utf-8",
            ".txt": "text/plain; charset=utf-8",
            ".md": "text/plain; charset=utf-8",
        }
        self.send_response(200)
        self.send_header("Content-Type", tipos.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _serve_solicitar_mockup(self, id_sr, nombre):
        safe = os.path.basename(nombre or "")
        path = os.path.join(solreq.caso_dir(id_sr), "mockups", safe)
        if not os.path.isfile(path):
            return self._json({"error": "Mockup no encontrado"}, 404)
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _serve_solicitar_documento(self, id_sr):
        path = os.path.join(solreq.caso_dir(id_sr), "documento.html")
        if not os.path.isfile(path):
            copia = os.path.join(DICTAMENES_ROOT, f"{id_sr}.html")
            if os.path.isfile(copia):
                path = copia
            else:
                return self._json({"error": "Documento no generado todavía"}, 404)
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _activar_caso(self):
        try:
            solicitud = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        id_caso = (solicitud.get("identificacion") or {}).get("idCaso", "").strip()
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)

        db = get_db()
        try:
            instruccion = _build_instruccion(solicitud)
            result = db.activar_caso(solicitud, instruccion)
            db.sync_caso_to_disk(id_caso)
            _sql_dir_caso(id_caso)
        except Exception as exc:
            print(f"ERROR activar caso {id_caso}: {exc}", flush=True)
            return self._json({"ok": False, "error": str(exc)}, 500)

        try:
            self._upsert_dev_desde_solicitud(solicitud)
        except Exception as exc:
            print(f"WARN desarrolladores al activar {id_caso}: {exc}", flush=True)

        bot = {}
        try:
            bot = agentes_panel.lanzar("analista", id_caso, "activar")
        except Exception as exc:
            bot = {"ok": False, "error": str(exc)}

        return self._json({
            "ok": True,
            "idCaso": id_caso,
            "carpeta": os.path.join(ACTIVO_ROOT, id_caso),
            "carpetaRelativa": f"activo/{id_caso}",
            "instruccion": f"activo/{id_caso}/INSTRUCCION-AGENTE.md",
            "mensaje": "Caso activado. El bot de Cursor empezó el análisis.",
            "estado": result.get("estado"),
            "bot": bot,
        })

    def _post_solicitud(self, id_caso):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        solicitud = body.get("solicitud") if isinstance(body, dict) else None
        if not isinstance(solicitud, dict):
            solicitud = body if isinstance(body, dict) else {}
        if not solicitud:
            return self._json({"error": "Falta solicitud"}, 400)
        db = get_db()
        imagen_subida = None
        archivo_subido = None
        subir = body.get("subirImagen") if isinstance(body.get("subirImagen"), dict) else None
        subir_arch = body.get("subirArchivo") if isinstance(body.get("subirArchivo"), dict) else None
        if subir and (subir.get("dataUrl") or "").strip():
            try:
                imagen_subida = _guardar_imagen_analisis(
                    id_caso,
                    subir.get("dataUrl"),
                    subir.get("nombre") or "",
                    solicitud,
                )
                solicitud = db.get_solicitud(id_caso) or solicitud
            except ValueError as exc:
                return self._json({"error": str(exc)}, 400)
        elif subir_arch and (subir_arch.get("dataUrl") or "").strip():
            try:
                archivo_subido = _guardar_archivo_analisis(
                    id_caso,
                    subir_arch.get("dataUrl"),
                    subir_arch.get("nombre") or "",
                    subir_arch.get("tipo") or "",
                    solicitud,
                )
                solicitud = db.get_solicitud(id_caso) or solicitud
            except ValueError as exc:
                return self._json({"error": str(exc)}, 400)
        else:
            db.guardar_solicitud(id_caso, solicitud)
        bot = {}
        if body.get("validarContabilidad"):
            bot = agentes_panel.lanzar("analista", id_caso, "contabilidad")
        if body.get("analizarRequerimiento"):
            ahora = datetime.now().isoformat(timespec="seconds")
            imgs = ((solicitud.get("contenido") or {}).get("imagenesAnalisis") or [])
            archs = ((solicitud.get("contenido") or {}).get("archivosAnalisis") or [])
            img_nota = ""
            if imgs:
                nombres = ", ".join(
                    (i.get("nombre") or "").strip()
                    for i in imgs
                    if (i.get("nombre") or "").strip()
                )
                if nombres:
                    img_nota = (
                        f" Hay capturas en activo/{id_caso}/imagenes/ ({nombres}). "
                        "Léalas y contrástelas con el REQ."
                    )
            if archs:
                anombres = ", ".join(
                    (a.get("nombre") or "").strip()
                    for a in archs
                    if (a.get("nombre") or "").strip()
                )
                if anombres:
                    img_nota += (
                        f" Hay normativa/archivos en activo/{id_caso}/archivos/ ({anombres}). "
                        "Lea el .extracto.txt, compare con lo que genera el sistema y cite apartes en el dictamen (sección 4.6)."
                    )
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
                    "autor": "coordinador",
                    "texto": (
                        "Analizar corre en dos pasos, sin otra acción suya. "
                        "Paso 1: ubique el proceso de la base, el flujo dentro de ese proceso "
                        "y la pieza (ventana, botón, proceso, SP o método), y qué recursos hacen falta. "
                        "Paso 2: con eso, analice el problema y proponga el cambio. "
                        "No nombre SP ni métodos que no participen en ese flujo."
                        f"{img_nota}"
                    ),
                    "fecha": ahora,
                },
            )
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "w",
                    "autor": "sistema",
                    "texto": "Paso 1 de 2: ubicando el proceso, el flujo y la pieza. El análisis del problema arranca solo después.",
                    "fecha": ahora,
                },
            )
            bot = agentes_panel.lanzar("analista", id_caso, "ubicar-req")
            if not bot.get("ok"):
                db.append_chat(
                    id_caso,
                    {
                        "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "e",
                        "autor": "sistema",
                        "texto": (
                            "El agente no pudo arrancar ("
                            + str(bot.get("error") or "error")
                            + "). Reinicie el servidor y pulse de nuevo Analizar requerimiento."
                        ),
                        "fecha": ahora,
                    },
                )
        if body.get("proponerCriterios"):
            ahora = datetime.now().isoformat(timespec="seconds")
            con_analisis = " y mi análisis" if body.get("usarAnalisis") else ""
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
                    "autor": "coordinador",
                    "texto": (
                        "Proponga criterios, alcance, restricciones y análisis contrastando el REQ "
                        "con la base de conocimiento (proceso/sps) y Qrystalos2"
                        + con_analisis
                        + ". Liste los SP/METODO documentados a usar. Escriba en "
                        "solicitud.contenido.criteriosAceptacion, alcance, restricciones, analisis, "
                        "recomendacion, criteriosMeta (fuente: agente) y cambioPropuestoSql si hay "
                        "fix SQL. Resuma en este Chat. No haga el dictamen completo."
                    ),
                    "fecha": ahora,
                },
            )
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "w",
                    "autor": "sistema",
                    "texto": "El agente está armando criterios/alcance/análisis desde el REQ y conocimiento/. Resultado en formulario y Chat.",
                    "fecha": ahora,
                },
            )
            bot = agentes_panel.lanzar("analista", id_caso, "criterios")
            if not bot.get("ok"):
                db.append_chat(
                    id_caso,
                    {
                        "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "e",
                        "autor": "sistema",
                        "texto": (
                            "El agente no pudo arrancar ("
                            + str(bot.get("error") or "error")
                            + "). Reinicie el servidor o escriba de nuevo en el Chat."
                        ),
                        "fecha": ahora,
                    },
                )
        out = {"ok": True, "bot": bot}
        if imagen_subida:
            out["imagen"] = imagen_subida
        if archivo_subido:
            out["archivo"] = archivo_subido
        return self._json(out)

    def _get_solicitud(self, id_caso):
        disk = _read_json_file(os.path.join(ACTIVO_ROOT, id_caso, "solicitud.json"), {})
        db_sol = get_db().get_solicitud(id_caso) or {}
        solicitud = disk if disk else db_sol
        if not solicitud:
            return self._json({"error": "Solicitud no encontrada", "idCaso": id_caso}, 404)
        estado = _read_json_file(os.path.join(ACTIVO_ROOT, id_caso, "estado.json"), {})
        return self._json({
            "ok": True,
            "idCaso": id_caso,
            "solicitud": solicitud,
            "fase1Cerrada": bool(estado.get("fase1Cerrada")),
        })

    def _get_chat(self, id_caso):
        db = get_db()
        chat = db.get_chat(id_caso)
        disk = _read_json_file(os.path.join(ACTIVO_ROOT, id_caso, "chat.json"), {})
        disk_msgs = disk.get("mensajes") or []
        if disk_msgs:
            by_id = {m.get("id"): m for m in (chat.get("mensajes") or []) if m.get("id")}
            for m in disk_msgs:
                if m.get("id"):
                    by_id[m["id"]] = m
            chat = {
                "mensajes": sorted(
                    by_id.values(),
                    key=lambda m: (m.get("fecha") or "", m.get("id") or ""),
                )
            }
        return self._json(chat)

    def _post_chat(self, id_caso):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        texto = (body.get("texto") or "").strip()
        if not texto:
            return self._json({"error": "Mensaje vacío"}, 400)

        autor = (body.get("autor") or "coordinador").strip().lower()
        if autor not in ("coordinador",):
            autor = "coordinador"

        msg = {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
            "autor": autor,
            "texto": texto,
            "fecha": datetime.now().isoformat(timespec="seconds"),
        }
        db = get_db()
        db.append_chat(id_caso, msg)
        accion = continuacion_chat(id_caso, texto)
        if accion == "detenido":
            chat = db.get_chat(id_caso, sync_disk=False)
            return self._json({
                "ok": True,
                "mensaje": msg,
                "mensajes": chat["mensajes"],
                "bot": leer_estado_bot(id_caso),
            })
        if accion == "ubicar":
            aviso_texto = (
                "Dato recibido. Sigue la ubicación del flujo y, si ya queda cerrado, el análisis."
            )
            motivo_chat = "ubicar-req"
        else:
            aviso_texto = "El agente está trabajando. El temporizador de arriba confirma que el proceso sigue vivo."
            motivo_chat = "chat"
        aviso = {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "w",
            "autor": "sistema",
            "texto": aviso_texto,
            "fecha": datetime.now().isoformat(timespec="seconds"),
        }
        db.append_chat(id_caso, aviso)
        bot = agentes_panel.lanzar("analista", id_caso, motivo_chat)
        if not bot.get("ok"):
            fallo = {
                "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "e",
                "autor": "sistema",
                "texto": (
                    "El agente no pudo arrancar ("
                    + str(bot.get("error") or "error")
                    + "). Reinicie abrir-app.bat y vuelva a enviar."
                ),
                "fecha": datetime.now().isoformat(timespec="seconds"),
            }
            db.append_chat(id_caso, fallo)
        chat = db.get_chat(id_caso, sync_disk=False)
        return self._json({
            "ok": True,
            "mensaje": msg,
            "mensajes": chat["mensajes"],
            "bot": bot,
        })

    def _list_casos_activos(self):
        casos = []
        if os.path.isdir(ACTIVO_ROOT):
            for name in sorted(os.listdir(ACTIVO_ROOT), reverse=True):
                carpeta = os.path.join(ACTIVO_ROOT, name)
                if not os.path.isdir(carpeta) or name.startswith("."):
                    continue
                solicitud = _read_json_file(os.path.join(carpeta, "solicitud.json"), {})
                estado = _read_json_file(os.path.join(carpeta, "estado.json"), {})
                chat = _read_json_file(os.path.join(carpeta, "chat.json"), {})
                ident = solicitud.get("identificacion") or {}
                casos.append({
                    "idCaso": name,
                    "idReq": ident.get("idReq") or estado.get("idReq") or "",
                    "titulo": (solicitud.get("contenido") or {}).get("titulo") or name,
                    "fase1Cerrada": bool(estado.get("fase1Cerrada")),
                    "nMensajes": len(chat.get("mensajes") or []),
                })
        return self._json({"casos": casos})

    def _get_estado(self, id_caso):
        estado = get_db().get_estado(id_caso)
        estado["bot"] = leer_estado_bot(id_caso)
        return self._json(estado)

    def _get_historico(self):
        get_db().reconciliar_cerrados()
        items = get_db().build_historico()
        return self._json({"historico": items, "origen": "sqlite"})

    def _post_historico(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        items = body.get("historico") if isinstance(body, dict) else body
        if not isinstance(items, list):
            return self._json({"error": "Se esperaba un arreglo historico"}, 400)

        get_db().save_historico(items)
        return self._json({"ok": True, "count": len(items)})

    def _upsert_dev_desde_solicitud(self, solicitud, fase1=""):
        personas = (solicitud or {}).get("personas") or {}
        nombre = personas.get("desarrollador") or ""
        if not nombre:
            return
        ident = solicitud.get("identificacion") or {}
        proyecto = solicitud.get("proyecto") or {}
        gestion = solicitud.get("gestion") or {}
        id_caso = ident.get("idCaso") or ""
        dest = ((solicitud.get("correo") or {}).get("destinatario") or "").strip()
        caso = {
            "idReq": ident.get("idReq") or "",
            "idCaso": id_caso,
            "cliente": proyecto.get("nombre") or "",
            "modulo": proyecto.get("modulo") or "",
            "rama": gestion.get("rama") or "",
            "dictamen": f"dictamenes/{id_caso}.html" if id_caso else "",
            "fase1": fase1 or "abierta",
        }
        if dest:
            caso["destinatario"] = dest
        devs.upsert(nombre, caso=caso, correo=dest or None)

    def _get_correo(self):
        parsed = urlparse(self.path)
        from urllib.parse import parse_qs
        qs = parse_qs(parsed.query)
        id_caso = (qs.get("idCaso") or [None])[0]
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        return self._json(mailer.estado(id_caso))

    def _post_correo(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        accion = (body.get("accion") or "enviar").strip().lower()
        id_caso = (body.get("idCaso") or "").strip()
        try:
            if accion == "estado":
                return self._json(mailer.estado(id_caso))
            if accion == "marcar":
                return self._json(mailer.marcar(
                    id_caso,
                    enviado=body.get("enviado"),
                    fecha_envio=body.get("fechaEnvio"),
                    destinatario=body.get("correo") or body.get("destinatario"),
                    via=body.get("via") or "manual",
                ))
            if accion in ("enviar", "reenviar"):
                return self._json(mailer.enviar(
                    id_caso,
                    correo=body.get("correo") or body.get("destinatario"),
                    reenviar=accion == "reenviar" or bool(body.get("reenviar")),
                    display=bool(body.get("display")),
                    desarrollador=body.get("desarrollador") or body.get("nombre"),
                ))
        except ValueError as e:
            return self._json({"ok": False, "error": str(e)}, 400)
        except RuntimeError as e:
            return self._json({"ok": False, "error": str(e)}, 502)
        except Exception as e:
            return self._json({"ok": False, "error": str(e)}, 500)
        return self._json({"error": f"Acción desconocida: {accion}"}, 400)

    def _get_desarrolladores(self):
        try:
            return self._json(devs.snapshot())
        except OSError as e:
            return self._json({"ok": False, "error": f"No se pudo leer/guardar desarrolladores: {e}"}, 500)

    def _post_desarrolladores(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        accion = (body.get("accion") or "sync").strip().lower()
        try:
            if accion == "correo":
                try:
                    data, dev, _ = devs.set_correo(body.get("nombre"), body.get("correo"))
                except ValueError as e:
                    return self._json({"ok": False, "error": str(e)}, 400)
                return self._json({
                    "ok": True,
                    "desarrollador": dev,
                    "pendientesCorreo": devs.pendientes_correo(data),
                    **data,
                })
            if accion == "upsert":
                data, dev, creado = devs.upsert(
                    body.get("nombre"),
                    caso=body.get("caso"),
                    correo=body.get("correo"),
                )
                return self._json({"ok": True, "creado": creado, "desarrollador": dev, **data})

            cola = body.get("items") if isinstance(body.get("items"), list) else get_db().get_cola()
            return self._json(devs.sync_all(cola))
        except OSError as e:
            return self._json({"ok": False, "error": f"No se pudo guardar desarrolladores: {e}"}, 500)
    def _get_cola(self):
        db = get_db()
        db.aplicar_estados_cola()
        return self._json({"items": db.get_cola()})

    def _post_cola_html(self):
        try:
            data = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        nombre = os.path.basename(str(data.get("nombre") or "").strip())
        html = data.get("html") or ""
        if not html.strip():
            return self._json({"error": "HTML vacío"}, 400)
        if not re.search(r"\.(html?)$", nombre, re.I):
            nombre = f"{nombre or 'ix-online-lista'}.htm"
        safe = re.sub(r"[^\w.\-áéíóúñÁÉÍÓÚÑ ]", "_", nombre).strip() or "ix-online-lista.htm"
        os.makedirs(COLA_ROOT, exist_ok=True)
        path = os.path.join(COLA_ROOT, safe)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(html)
        return self._json({"ok": True, "archivo": safe})

    def _post_cola(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        items = body.get("items") if isinstance(body, dict) else body
        if not isinstance(items, list):
            return self._json({"error": "Se esperaba items[]"}, 400)

        get_db().save_cola(items)
        sync = devs.sync_from_cola(items)
        return self._json({
            "ok": True,
            "count": len(items),
            "desarrolladores": {
                "creados": sync[1],
                "actualizados": sync[2],
                "pendientesCorreo": [d.get("nombre") for d in devs.pendientes_correo(sync[0])],
            },
        })

    def _get_borrador(self):
        parsed = urlparse(self.path)
        from urllib.parse import parse_qs
        qs = parse_qs(parsed.query)
        id_caso = (qs.get("idCaso") or [None])[0]
        data = get_db().get_borrador(id_caso)
        return self._json({"borrador": data})

    def _post_borrador(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        id_caso = (body.get("idCaso") or "__ultimo__").strip()
        data = body.get("datos") or body.get("borrador") or body
        get_db().save_borrador(id_caso, data)
        return self._json({"ok": True, "idCaso": id_caso})

    def _serve_imagen(self, id_caso, nombre):
        nombre = _sanitize_imagen_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        path = os.path.join(_imagenes_analisis_dir(id_caso), nombre)
        if not os.path.isfile(path):
            return self._json({"error": "Imagen no encontrada"}, 404)
        ext = os.path.splitext(nombre)[1].lower()
        ctype = {
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".webp": "image/webp",
            ".gif": "image/gif",
        }.get(ext, "application/octet-stream")
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _post_imagen(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta = _guardar_imagen_analisis(
                id_caso,
                body.get("dataUrl"),
                body.get("nombre") or "",
            )
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({"ok": True, "imagen": meta})

    def _delete_imagen(self, id_caso, nombre):
        nombre = _sanitize_imagen_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        path = os.path.join(_imagenes_analisis_dir(id_caso), nombre)
        if os.path.isfile(path):
            os.remove(path)
        db = get_db()
        solicitud = db.get_solicitud(id_caso) or {}
        contenido = solicitud.get("contenido") or {}
        imgs = [i for i in (contenido.get("imagenesAnalisis") or []) if i.get("nombre") != nombre]
        contenido["imagenesAnalisis"] = imgs
        solicitud["contenido"] = contenido
        db.guardar_solicitud(id_caso, solicitud)
        return self._json({"ok": True, "nombre": nombre})

    def _serve_archivo(self, id_caso, nombre):
        nombre = _sanitize_archivo_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        path = os.path.join(_archivos_analisis_dir(id_caso), nombre)
        if not os.path.isfile(path):
            aprob = os.path.join(APROBADOS_ROOT, id_caso, "archivos", nombre)
            if os.path.isfile(aprob):
                path = aprob
            else:
                return self._json({"error": "Archivo no encontrado"}, 404)
        ext = os.path.splitext(nombre)[1].lower()
        ctype = {
            ".pdf": "application/pdf",
            ".txt": "text/plain; charset=utf-8",
            ".md": "text/plain; charset=utf-8",
            ".html": "text/html; charset=utf-8",
            ".htm": "text/html; charset=utf-8",
            ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".doc": "application/msword",
        }.get(ext, "application/octet-stream")
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Content-Disposition", f'inline; filename="{nombre}"')
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _post_archivo(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta = _guardar_archivo_analisis(
                id_caso,
                body.get("dataUrl"),
                body.get("nombre") or "",
                body.get("tipo") or "",
            )
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({"ok": True, "archivo": meta})

    def _post_desde_solicitud(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        id_sr = (body.get("idSolicitud") or "").strip()
        if not id_sr:
            return self._json({"error": "Falta la solicitud"}, 400)
        try:
            traido = importar_archivos_solicitud(id_caso, id_sr)
            vinculo = solreq.vincular_caso(
                id_sr,
                id_caso,
                body.get("idReq") or "",
                body.get("titulo") or "",
            )
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({"ok": True, **traido, "vinculo": vinculo})

    def _delete_archivo(self, id_caso, nombre):
        nombre = _sanitize_archivo_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        dest_dir = _archivos_analisis_dir(id_caso)
        path = os.path.join(dest_dir, nombre)
        if os.path.isfile(path):
            os.remove(path)
        extracto = _extracto_nombre(nombre)
        ext_path = os.path.join(dest_dir, extracto)
        if os.path.isfile(ext_path):
            os.remove(ext_path)
        db = get_db()
        solicitud = db.get_solicitud(id_caso) or {}
        contenido = solicitud.get("contenido") or {}
        items = [a for a in (contenido.get("archivosAnalisis") or []) if a.get("nombre") != nombre]
        contenido["archivosAnalisis"] = items
        solicitud["contenido"] = contenido
        db.guardar_solicitud(id_caso, solicitud)
        return self._json({"ok": True, "nombre": nombre})

    def _serve_diagrama(self, id_caso, nombre):
        nombre = _sanitize_diagrama_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        path = os.path.join(_diagramas_dir(id_caso), nombre)
        if not os.path.isfile(path):
            aprob = os.path.join(APROBADOS_ROOT, id_caso, "diagramas", nombre)
            if os.path.isfile(aprob):
                path = aprob
            else:
                return self._json({"error": "Diagrama no encontrado"}, 404)
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _post_diagrama_generar(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta, ctx = _generar_y_guardar_diagrama_caso(id_caso, (body.get("notas") or "").strip())
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        except FileNotFoundError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({"ok": True, "diagrama": meta, "procesoId": ctx.get("procesoId")})

    def _post_conocimiento_diagrama(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        proceso_id = (body.get("procesoId") or "").strip()
        pregunta = (body.get("pregunta") or body.get("notas") or "").strip()
        try:
            html, ctx = diagflujo.html_proceso(proceso_id, pregunta=pregunta, notas=pregunta)
            meta = diagflujo.guardar_html_proceso(proceso_id, html, "flujo.html")
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._json({
            "ok": True,
            "diagrama": meta,
            "procesoId": ctx.get("procesoId"),
            "procesoNombre": ctx.get("procesoNombre"),
        })

    def _post_diagrama(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta = _guardar_diagrama_flujo(
                id_caso,
                body.get("contenido") or body.get("html") or "",
                body.get("nombre") or "",
            )
            notas = (body.get("notas") or "").strip()
            if notas:
                db = get_db()
                solicitud = db.get_solicitud(id_caso) or {}
                contenido = solicitud.get("contenido") or {}
                diag = contenido.get("diagramaFlujo") or meta
                diag["notas"] = notas
                contenido["diagramaFlujo"] = diag
                solicitud["contenido"] = contenido
                db.guardar_solicitud(id_caso, solicitud)
                meta["notas"] = notas
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        try:
            solicitud = get_db().get_solicitud(id_caso) or {}
            _, ctx = diagflujo.html_caso(solicitud, notas=(meta.get("notas") or ""))
            fragmento = diagflujo.render_fragmento(ctx)
        except Exception:
            fragmento = (
                f'<p>Diagrama adjunto. Copia junto al dictamen: '
                f'<a href="/dictamenes/{id_caso}-flujo.html">{id_caso}-flujo.html</a></p>'
            )
        _actualizar_dictamen_diagrama(id_caso, meta.get("nombre") or "flujo.html", fragmento=fragmento)
        return self._json({"ok": True, "diagrama": meta})

    def _delete_diagrama(self, id_caso, nombre):
        nombre = _sanitize_diagrama_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Parámetros inválidos"}, 400)
        path = os.path.join(_diagramas_dir(id_caso), nombre)
        if os.path.isfile(path):
            os.remove(path)
        db = get_db()
        solicitud = db.get_solicitud(id_caso) or {}
        contenido = solicitud.get("contenido") or {}
        diag = contenido.get("diagramaFlujo") or {}
        if diag.get("nombre") == nombre:
            contenido["diagramaFlujo"] = None
        solicitud["contenido"] = contenido
        db.guardar_solicitud(id_caso, solicitud)
        return self._json({"ok": True, "nombre": nombre})

    def _mockup_meta(self, rel):
        rel = str(rel or "").strip().replace("\\", "/").lstrip("/")
        if not rel:
            return None
        abs_path = os.path.join(ROOT, *rel.split("/"))
        existe = os.path.isfile(abs_path)
        nombre = os.path.basename(rel)
        titulo = nombre.replace(".html", "").replace("-", " ")
        tipo = "mockup-sp" if "sp" in nombre.lower() or "flujo-sp" in rel.lower() else "mockup-ux"
        zip_abs = mockzip.nombre_zip_para_html(abs_path) if rel.lower().endswith(".html") else None
        zip_existe = zip_abs.is_file() if zip_abs else False
        zip_rel = ""
        if zip_abs and zip_existe:
            zip_rel = os.path.relpath(str(zip_abs), ROOT).replace("\\", "/")
        id_caso = ""
        if rel.startswith("activo/"):
            parts = rel.split("/")
            if len(parts) > 1:
                id_caso = parts[1]
        zip_url = ""
        if id_caso and rel.lower().endswith(".html"):
            from urllib.parse import quote

            zip_url = f"/api/caso/{id_caso}/mockups?zip={quote(rel, safe='/')}"
        return {
            "tipo": tipo,
            "titulo": f"Mockup: {titulo}",
            "ruta": rel,
            "url": f"/{rel}" if existe else None,
            "existe": existe,
            "estado": "adjunto-correo" if existe else "no-encontrado",
            "zipRuta": zip_rel if zip_existe else None,
            "zipExiste": zip_existe,
            "zipUrl": zip_url if zip_existe or existe else None,
        }

    def _escanear_mockups_html(self, id_caso):
        """Solo mockups del caso activo — no mezclar otros REQ en activo/ ni solicitudes/."""
        found = set()
        caso_mock = os.path.join(ROOT, "activo", id_caso, "mockups")
        if os.path.isdir(caso_mock):
            for name in os.listdir(caso_mock):
                if name.lower().endswith(".html"):
                    found.add(f"activo/{id_caso}/mockups/{name}")
        return sorted(found)

    def _filtrar_mockups_caso(self, id_caso, rels):
        return _filtrar_mockups_caso_list(id_caso, rels)

    def _plantillas_mockup(self):
        out = []
        plantillas = os.path.join(ROOT, "plantillas")
        if not os.path.isdir(plantillas):
            return out
        labels = {
            "mockup-flujo-sp.html": "Plantilla SP (expandibles METODO)",
        }
        for name in sorted(os.listdir(plantillas)):
            if not (name.lower().startswith("mockup") and name.lower().endswith(".html")):
                continue
            rel = f"plantillas/{name}"
            out.append({
                "ruta": rel,
                "titulo": labels.get(name, name),
                "url": f"/{rel}",
            })
        return out

    def _serve_mockup_zip(self, id_caso, ruta_rel):
        from urllib.parse import unquote

        ruta_rel = unquote(str(ruta_rel or "")).strip().replace("\\", "/").lstrip("/")
        if not ruta_rel.lower().endswith(".html"):
            return self._json({"error": "Solo mockups .html"}, 400)
        if ruta_rel.startswith("activo/") and not ruta_rel.startswith(f"activo/{id_caso}/"):
            return self._json({"error": "Mockup de otro caso"}, 403)
        abs_html = os.path.join(ROOT, *ruta_rel.split("/"))
        if not os.path.isfile(abs_html):
            return self._json({"error": "Mockup no encontrado"}, 404)
        try:
            zip_path = mockzip.empaquetar_mockup_html(abs_html, id_caso=id_caso)
        except OSError as exc:
            return self._json({"error": str(exc)}, 500)
        with open(zip_path, "rb") as fh:
            body = fh.read()
        nombre = os.path.basename(zip_path)
        self.send_response(200)
        self.send_header("Content-Type", "application/zip")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Content-Disposition", f'attachment; filename="{nombre}"')
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.end_headers()
        self.wfile.write(body)
        return None

    def _get_mockups(self, id_caso, parsed):
        db = get_db()
        solicitud = db.get_solicitud(id_caso) or _read_json_file(
            os.path.join(ACTIVO_ROOT, id_caso, "solicitud.json"), {}
        )
        if not solicitud:
            return self._json({"error": "Solicitud no encontrada", "idCaso": id_caso}, 404)
        qs = parse_qs(parsed.query or "")
        zip_ruta = (qs.get("zip") or [""])[0].strip()
        if zip_ruta:
            return self._serve_mockup_zip(id_caso, zip_ruta)
        escanear = (qs.get("scan") or [""])[0].lower() in ("1", "true", "si", "sí")
        rels = self._filtrar_mockups_caso(id_caso, mailer.rutas_mockups_solicitud(solicitud))
        configurados = [m for m in (self._mockup_meta(r) for r in rels) if m]
        sugeridos = []
        if escanear:
            cfg_set = set(rels)
            sugeridos = [
                m for m in (self._mockup_meta(r) for r in self._escanear_mockups_html(id_caso))
                if m and m["ruta"] not in cfg_set
            ]
        try:
            correo = mailer.estado(id_caso)
            n_adj = len(configurados)
            correo_hint = (
                f"Dictamen + {n_adj} mockup(s) al enviar"
                if n_adj
                else "Solo dictamen (sin mockups declarados)"
            )
        except Exception:
            correo_hint = ""
        return self._json({
            "ok": True,
            "idCaso": id_caso,
            "mockups": configurados,
            "sugeridos": sugeridos,
            "plantillas": self._plantillas_mockup(),
            "correoHint": correo_hint,
            "fase1Cerrada": bool(_read_json_file(os.path.join(ACTIVO_ROOT, id_caso, "estado.json"), {}).get("fase1Cerrada")),
        })

    def _post_mockups(self, id_caso):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        raw = body.get("mockups")
        if raw is None and isinstance(body.get("accion"), str):
            accion = body.get("accion").strip().lower()
            if accion == "scan":
                return self._get_mockups(id_caso, urlparse("?scan=1"))
            return self._json({"error": "Acción no reconocida"}, 400)
        if not isinstance(raw, list):
            return self._json({"error": "Falta lista mockups"}, 400)
        rels = []
        for item in raw:
            rel = str(item or "").strip().replace("\\", "/").lstrip("/")
            if rel and rel not in rels:
                rels.append(rel)
        rels = self._filtrar_mockups_caso(id_caso, rels)
        db = get_db()
        solicitud = db.get_solicitud(id_caso) or _read_json_file(
            os.path.join(ACTIVO_ROOT, id_caso, "solicitud.json"), {}
        )
        if not solicitud:
            return self._json({"error": "Solicitud no encontrada", "idCaso": id_caso}, 404)
        contenido = dict(solicitud.get("contenido") or {})
        contenido["mockups"] = rels
        if "mockupsNotas" in body:
            contenido["mockupsNotas"] = str(body.get("mockupsNotas") or "").strip()
        solicitud["contenido"] = contenido
        db.guardar_solicitud(id_caso, solicitud)
        configurados = [m for m in (self._mockup_meta(r) for r in rels) if m]
        return self._json({
            "ok": True,
            "idCaso": id_caso,
            "mockups": configurados,
            "correoHint": f"Dictamen + {len(configurados)} mockup(s) al enviar" if configurados else "Solo dictamen",
        })

    def _post_mockup_subir(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        try:
            meta = _guardar_mockup_html(
                id_caso,
                body.get("contenido") or body.get("html") or "",
                body.get("nombre") or "",
            )
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        notas = (body.get("notas") or body.get("mockupsNotas") or "").strip()
        if notas:
            db = get_db()
            solicitud = db.get_solicitud(id_caso) or {}
            contenido = dict(solicitud.get("contenido") or {})
            contenido["mockupsNotas"] = notas
            solicitud["contenido"] = contenido
            db.guardar_solicitud(id_caso, solicitud)
        return self._get_mockups(id_caso, urlparse(""))

    def _post_mockup_generar(self, id_caso):
        if not id_caso:
            return self._json({"error": "Falta idCaso"}, 400)
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        notas = (body.get("notas") or body.get("mockupsNotas") or "").strip()
        try:
            nombres = _generar_y_guardar_mockups_caso(id_caso, notas=notas)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        return self._get_mockups(id_caso, urlparse("?scan=0"))

    def _get_documentos(self, id_caso):
        db = get_db()
        solicitud = db.get_solicitud(id_caso)
        rutas = solicitud.get("rutas") or {}
        docs = []

        dictamen_rel = (rutas.get("dictamen") or f"dictamenes/{id_caso}.html").replace("\\", "/")
        dictamen_abs = os.path.join(ROOT, *dictamen_rel.split("/"))
        if os.path.isfile(dictamen_abs):
            docs.append({
                "tipo": "dictamen",
                "titulo": "Dictamen técnico",
                "ruta": dictamen_rel,
                "url": f"/api/caso/{id_caso}/dictamen",
                "estado": "propuesto",
            })

        aprobado_rel = f"aprobados/{id_caso}/{id_caso}.html"
        aprobado_abs = os.path.join(ROOT, "aprobados", id_caso, f"{id_caso}.html")
        if os.path.isfile(aprobado_abs):
            docs.append({
                "tipo": "aprobado",
                "titulo": "Dictamen aprobado",
                "ruta": aprobado_rel,
                "estado": "aprobado",
            })

        instruccion_rel = f"activo/{id_caso}/INSTRUCCION-AGENTE.md"
        if os.path.isfile(os.path.join(ROOT, "activo", id_caso, "INSTRUCCION-AGENTE.md")):
            docs.append({
                "tipo": "instruccion",
                "titulo": "Instrucción agente",
                "ruta": instruccion_rel,
                "estado": "interno",
            })

        for img in ((solicitud.get("contenido") or {}).get("imagenesAnalisis") or []):
            nombre = (img.get("nombre") or "").strip()
            if not nombre:
                continue
            docs.append({
                "tipo": "imagen",
                "titulo": f"Captura: {nombre}",
                "ruta": f"activo/{id_caso}/imagenes/{nombre}",
                "url": f"/api/caso/{id_caso}/imagen/{nombre}",
                "estado": "analisis",
            })

        for arch in ((solicitud.get("contenido") or {}).get("archivosAnalisis") or []):
            nombre = (arch.get("nombre") or "").strip()
            if not nombre:
                continue
            docs.append({
                "tipo": "archivo",
                "titulo": f"{(arch.get('tipo') or 'Normativa')}: {nombre}",
                "ruta": f"activo/{id_caso}/archivos/{nombre}",
                "url": f"/api/caso/{id_caso}/archivo/{nombre}",
                "estado": "normativa",
            })

        diag = ((solicitud.get("contenido") or {}).get("diagramaFlujo") or {})
        diag_nombre = (diag.get("nombre") or "").strip()
        if diag_nombre:
            docs.append({
                "tipo": "diagrama",
                "titulo": f"Diagrama de flujo: {diag_nombre}",
                "ruta": f"activo/{id_caso}/diagramas/{diag_nombre}",
                "url": f"/api/caso/{id_caso}/diagrama/{diag_nombre}",
                "estado": "flujo",
            })

        for rel in mailer.rutas_mockups_solicitud(solicitud):
            meta = self._mockup_meta(rel)
            if meta:
                docs.append({
                    "tipo": meta["tipo"],
                    "titulo": meta["titulo"],
                    "ruta": meta["ruta"],
                    "url": meta["url"],
                    "estado": meta["estado"],
                })

        return self._json({"idCaso": id_caso, "documentos": docs})

    def _dictamen_path(self, id_caso):
        solicitud = get_db().get_solicitud(id_caso)
        dictamen_rel = ((solicitud.get("rutas") or {}).get("dictamen") or f"dictamenes/{id_caso}.html").replace("\\", "/")
        dictamen_abs = os.path.join(ROOT, *dictamen_rel.split("/"))
        return dictamen_rel, dictamen_abs

    def _base_dictamen_api(self, body):
        """El dictamen se abre en /api/caso/{id}/dictamen. Sin <base>,
        ../activo/ y ../app/ se resuelven bajo /api/caso/ y el mockup da 404."""
        if re.search(br"<base\b", body, re.I):
            return body
        tag = b'<base href="/dictamenes/">'
        match = re.search(br"<head\b[^>]*>", body, re.I)
        if not match:
            return tag + body
        end = match.end()
        return body[:end] + tag + body[end:]

    def _serve_dictamen(self, id_caso):
        dictamen_rel, dictamen_abs = self._dictamen_path(id_caso)
        if not os.path.isfile(dictamen_abs):
            return self._json({"error": "Dictamen no encontrado", "ruta": dictamen_rel}, 404)

        with open(dictamen_abs, "rb") as fh:
            body = self._base_dictamen_api(fh.read())

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _cerrar_fase1(self, id_caso):
        try:
            body = self._read_json_body() or {}
        except json.JSONDecodeError:
            body = {}
        dest = (body.get("correo") or body.get("destinatario") or "").strip()

        db = get_db()
        estado = db.cerrar_fase1(id_caso)
        solicitud = db.get_solicitud(id_caso) or {}
        nombre_dev = ((solicitud.get("personas") or {}).get("desarrollador") or "").strip()
        if dest and nombre_dev:
            try:
                devs.set_correo(nombre_dev, dest)
            except (ValueError, OSError) as exc:
                print(f"WARN set_correo al cerrar fase 1: {exc}", flush=True)
        id_req = (
            (estado.get("idReq") or "")
            or ((solicitud.get("identificacion") or {}).get("idReq") or "")
        ).strip()
        sql_info = self._mover_sql_a_refe(id_req, id_caso)
        aprobado = self._copiar_dictamen_aprobado(id_caso)
        self._upsert_dev_desde_solicitud(solicitud, fase1="cerrada")

        correo = {"ok": False, "enviado": False}
        try:
            prev = mailer.estado(id_caso)
            correo = mailer.enviar(
                id_caso,
                correo=dest or None,
                reenviar=bool(prev.get("enviado")),
                desarrollador=nombre_dev or None,
            )
        except Exception as e:
            correo = {"ok": False, "enviado": False, "error": str(e)}

        if correo.get("ok") and not correo.get("borrador"):
            self._upsert_dev_desde_solicitud(solicitud, fase1="enviado")
            try:
                db.refresh_historico_for_caso(id_caso)
                cola = db.get_cola()
                for item in cola:
                    req = item.get("idReqSeleccionado") or (item.get("parsed") or {}).get("idReq")
                    if req == id_req:
                        item["estado"] = "terminado"
                        item["terminadoPor"] = "correo_enviado"
                        item["terminadoEn"] = item.get("terminadoEn") or datetime.now().isoformat(timespec="seconds")
                        item["correoEnviado"] = True
                db.save_cola(cola)
                db.append_chat(
                    id_caso,
                    {
                        "id": f"correo-cierre-{id_caso}",
                        "autor": "sistema",
                        "texto": (
                            f"Fase 1 cerrada. Correo enviado a "
                            f"{correo.get('destinatario') or dest}."
                        ),
                        "fecha": datetime.now().isoformat(timespec="seconds"),
                    },
                )
            except Exception:
                pass
        elif correo.get("error"):
            try:
                db.append_chat(
                    id_caso,
                    {
                        "id": f"correo-cierre-error-{id_caso}",
                        "autor": "sistema",
                        "texto": (
                            "Fase 1 cerrada, pero el correo no se envió: "
                            f"{correo.get('error')}. Use Enviar correo en el formulario."
                        ),
                        "fecha": datetime.now().isoformat(timespec="seconds"),
                    },
                )
            except Exception:
                pass

        return self._json({
            "ok": True,
            "estado": estado,
            "sql": sql_info,
            "aprobado": aprobado,
            "correo": correo,
        })

    def _copiar_dictamen_aprobado(self, id_caso):
        _, src = self._dictamen_path(id_caso)
        dest_dir = os.path.join(APROBADOS_ROOT, id_caso)
        os.makedirs(dest_dir, exist_ok=True)
        dest_img = os.path.join(dest_dir, "imagenes")
        os.makedirs(dest_img, exist_ok=True)
        src_img_dir = _imagenes_analisis_dir(id_caso)
        if os.path.isdir(src_img_dir):
            for nombre in os.listdir(src_img_dir):
                src_img = os.path.join(src_img_dir, nombre)
                if os.path.isfile(src_img):
                    shutil.copy2(src_img, os.path.join(dest_img, nombre))
        dest_arch = os.path.join(dest_dir, "archivos")
        os.makedirs(dest_arch, exist_ok=True)
        src_arch_dir = _archivos_analisis_dir(id_caso)
        if os.path.isdir(src_arch_dir):
            for nombre in os.listdir(src_arch_dir):
                src_a = os.path.join(src_arch_dir, nombre)
                if os.path.isfile(src_a):
                    shutil.copy2(src_a, os.path.join(dest_arch, nombre))
        dest_diag = os.path.join(dest_dir, "diagramas")
        os.makedirs(dest_diag, exist_ok=True)
        src_diag_dir = _diagramas_dir(id_caso)
        if os.path.isdir(src_diag_dir):
            for nombre in os.listdir(src_diag_dir):
                src_d = os.path.join(src_diag_dir, nombre)
                if os.path.isfile(src_d) and nombre.lower().endswith(".html"):
                    shutil.copy2(src_d, os.path.join(dest_diag, nombre))
        if not os.path.isfile(src):
            return {"ok": False, "error": "Dictamen no encontrado", "ruta": None}
        dest = os.path.join(dest_dir, f"{id_caso}.html")
        shutil.copy2(src, dest)
        return {
            "ok": True,
            "ruta": f"aprobados/{id_caso}/{id_caso}.html",
        }

    def _mover_sql_a_refe(self, id_req, id_caso):
        if not id_req or len(id_req) != 10 or not id_req.isdigit():
            return {"ok": False, "error": "idReq inválido", "movidos": []}
        if not id_caso:
            return {
                "ok": False,
                "error": "Falta idCaso. No se archiva la carpeta compartida sql/.",
                "movidos": [],
            }

        try:
            src_dir = _sql_dir_caso(id_caso)
        except ValueError as exc:
            return {"ok": False, "error": str(exc), "movidos": []}
        dest_dir = os.path.join(SQL_REF_ROOT, id_req)
        os.makedirs(dest_dir, exist_ok=True)
        archivos = _sql_files_in_dir(src_dir)
        movidos = []
        for nombre in archivos:
            src = os.path.join(src_dir, nombre)
            dst = os.path.join(dest_dir, nombre)
            if os.path.exists(dst):
                base, ext = os.path.splitext(nombre)
                dst = os.path.join(dest_dir, f"{base}_{id_caso}{ext}")
            shutil.move(src, dst)
            movidos.append(os.path.basename(dst))

        meta = {
            "idReq": id_req,
            "idCaso": id_caso,
            "origen": f"activo/{id_caso}/sql",
            "archivadoEn": datetime.now().isoformat(timespec="seconds"),
            "archivos": movidos,
        }
        with open(os.path.join(dest_dir, "archivo.json"), "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False, indent=2)

        self._write_case_sql_manifest(src_dir, _sql_files_in_dir(src_dir))
        if not movidos:
            return {
                "ok": True,
                "movidos": [],
                "destinoRelativo": f"sql_refe/{id_req}",
                "origenRelativo": f"activo/{id_caso}/sql",
                "mensaje": f"No había .sql en activo/{id_caso}/sql/ para archivar.",
            }
        return {
            "ok": True,
            "movidos": movidos,
            "destinoRelativo": f"sql_refe/{id_req}",
            "origenRelativo": f"activo/{id_caso}/sql",
            "mensaje": f"Archivados {len(movidos)} .sql de activo/{id_caso}/sql/ en sql_refe/{id_req}/.",
        }

    def _list_sql(self, id_caso=""):
        if id_caso:
            try:
                directory = _sql_dir_caso(id_caso)
            except ValueError as exc:
                return self._json({"ok": False, "error": str(exc)}, 400)
            archivos = _sql_files_in_dir(directory)
            rel = f"activo/{id_caso}/sql"
            self._write_case_sql_manifest(directory, archivos)
            return self._json({
                "ok": True,
                "idCaso": id_caso,
                "ruta": directory,
                "rutaRelativa": rel,
                "archivos": archivos,
                "mensaje": None if archivos else f"No hay .sql en {rel}/",
            })
        archivos = _sql_files_in_dir(SQL_ROOT)
        self._write_sql_manifest(archivos)
        return self._json({
            "ok": True,
            "ruta": SQL_ROOT,
            "rutaRelativa": "sql",
            "archivos": archivos,
            "mensaje": None if archivos else "No hay .sql en sql/ (Documentar).",
        })

    def _write_case_sql_manifest(self, directory, archivos):
        manifest = {
            "generado": datetime.now().isoformat(timespec="seconds"),
            "ruta": directory,
            "archivos": archivos,
        }
        with open(os.path.join(directory, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)

    def _write_sql_manifest(self, archivos):
        manifest = {"generado": datetime.now().isoformat(timespec="seconds"), "ruta": SQL_ROOT, "archivos": archivos}
        with open(os.path.join(SQL_ROOT, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
        app_js = os.path.join(ROOT, "app", "js", "sql-manifest.js")
        lista = ",\n".join(f'    "{a}"' for a in archivos)
        with open(app_js, "w", encoding="utf-8") as fh:
            fh.write(f'window.QRYS_SQL_MANIFEST = {{ generado: "{manifest["generado"]}", archivos: [\n{lista}\n  ] }};\n')

    def _archivar_sql(self):
        try:
            data = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)

        id_req = (data.get("idReq") or "").strip()
        id_caso = (data.get("idCaso") or "").strip()
        result = self._mover_sql_a_refe(id_req, id_caso)
        if not result.get("ok"):
            return self._json({"error": result.get("error") or "Error al archivar"}, 400)
        if not result.get("movidos"):
            return self._json({"error": result.get("mensaje") or "No hay .sql en la carpeta del caso"}, 404)
        return self._json(result)

    def _exige_sesion_servidores(self) -> bool:
        token = self.headers.get("X-Ba-Sesion") or ""
        if servidores_admin.sesion_valida(token):
            return True
        self._json({"ok": False, "error": "Inicie sesión para ver los servidores."}, 401)
        return False

    def _post_servidores_entrar(self):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        try:
            if body.get("crear"):
                servidores_admin.crear_acceso(body.get("usuario") or "", body.get("clave") or "")
            token = servidores_admin.entrar(body.get("usuario") or "", body.get("clave") or "")
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, "token": token})

    def _post_servidores_salir(self):
        servidores_admin.salir(self.headers.get("X-Ba-Sesion") or "")
        return self._json({"ok": True})

    def _post_servidores_detalle(self):
        if not self._exige_sesion_servidores():
            return None
        try:
            body = self._read_json_body()
            ficha = servidores_admin.detalle(body.get("id") or "")
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, "servidor": ficha})

    def _post_servidores_guardar(self):
        if not self._exige_sesion_servidores():
            return None
        try:
            body = self._read_json_body()
            ficha = servidores_admin.guardar(body)
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, "servidor": ficha})

    def _post_servidores_traer(self):
        if not self._exige_sesion_servidores():
            return None
        try:
            resumen = servidores_admin.importar_qrystalos2()
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True, **resumen})

    def _post_servidores_listar_bases(self):
        if not self._exige_sesion_servidores():
            return None
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        sid = (body.get("id") or "").strip()
        try:
            bases = servidores_admin.listar_bases_sql(sid)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        except RuntimeError as exc:
            return self._json({"ok": False, "error": str(exc)}, 502)
        except Exception as exc:
            return self._json({"ok": False, "error": str(exc)}, 500)
        return self._json({"ok": True, "id": sid, "bases": bases})

    def _post_servidores_quitar(self):
        if not self._exige_sesion_servidores():
            return None
        try:
            body = self._read_json_body()
            servidores_admin.quitar(body.get("id") or "")
        except json.JSONDecodeError:
            return self._json({"ok": False, "error": "JSON inválido"}, 400)
        except ValueError as exc:
            return self._json({"ok": False, "error": str(exc)}, 400)
        return self._json({"ok": True})

    def end_headers(self):
        path = (urlparse(self.path).path or "").lower()
        if path.endswith(".html") and ("/dictamenes/" in path or path.endswith("/dictamen")):
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
        super().end_headers()

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Ba-Sesion")

    def _json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)


def _free_port_if_needed(port: int) -> None:
    """Evita ERR_EMPTY_RESPONSE por varios python escuchando el mismo puerto."""
    import subprocess

    script = os.path.join(SCRIPT_DIR, "liberar_puerto.py")
    if not os.path.isfile(script):
        return
    rc = subprocess.call([sys.executable, script, "--port", str(port)])
    if rc != 0:
        print(
            f"ERROR: cierre ventanas 'Qrystalos BA SERVIDOR' y ejecute reiniciar-servidor.bat",
            flush=True,
        )
        sys.exit(1)


def main():
    import sys
    os.chdir(ROOT)
    os.makedirs(ACTIVO_ROOT, exist_ok=True)
    os.makedirs(SQL_REF_ROOT, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "conocimiento"), exist_ok=True)
    kb_indice.regenerar_en_segundo_plano(0.5)  # índice de búsqueda al día al arrancar
    _free_port_if_needed(PORT)
    try:
        get_db().init()
        server = ThreadingHTTPServer(("127.0.0.1", PORT), QrystalosBAHandler)
    except OSError as exc:
        print(f"ERROR: no se pudo usar el puerto {PORT}: {exc}", flush=True)
        print("Ejecute scripts\\liberar-puerto.ps1 o cierre otras ventanas de servir-app.bat", flush=True)
        sys.exit(1)
    print(f"Qrystalos BA — http://localhost:{PORT}/app/", flush=True)
    print(f"SQLite:  data/qrystalos_ba.db", flush=True)
    print(f"Activos: activo/{{id-caso}}/", flush=True)
    print(f"SQL:     activo/{{id-caso}}/sql/  (sql/ solo Documentar)", flush=True)
    print(f"Procesos: conocimiento/", flush=True)
    try:
        import documentar_vigilante as docvig

        docvig.start_background()  # solo marca inactivo; no arranca hilo
    except Exception as exc:
        print(f"Documentar vigilante: {exc}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
