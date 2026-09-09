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
from email.parser import BytesParser
from email.policy import default as email_policy
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import parse_qs, unquote, urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from cursor_bot import (  # noqa: E402
    CONOCIMIENTO_ID,
    CONSULTAS_ID,
    DOCUMENTAR_ID,
    lanzar_bot,
    leer_estado_bot,
    load_api_key,
)
from qrystalos_ba_db import get_db  # noqa: E402
import desarrolladores as devs  # noqa: E402
import correo as mailer  # noqa: E402
import conocimiento as kb  # noqa: E402

ROOT = os.path.dirname(SCRIPT_DIR)
SQL_ROOT = os.path.join(ROOT, "sql")
SQL_REF_ROOT = os.path.join(ROOT, "sql_refe")
ACTIVO_ROOT = os.path.join(ROOT, "activo")
HISTORICO_ROOT = os.path.join(ROOT, "historico")
DICTAMENES_ROOT = os.path.join(ROOT, "dictamenes")
APROBADOS_ROOT = os.path.join(ROOT, "aprobados")
COLA_ROOT = os.path.join(ROOT, "cola")
PORT = 8765
IMAGEN_EXT = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"}
IMAGEN_MIME = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
}
IMAGEN_MAX = 10 * 1024 * 1024


def _safe_id_caso(id_caso):
    s = unquote(id_caso or "").strip()
    return s if re.fullmatch(r"[A-Za-z0-9._-]{3,80}", s) else ""


def _safe_imagen_nombre(nombre):
    base = os.path.basename(unquote(nombre or "")).strip()
    base = re.sub(r"[^\w.\-]", "_", base)
    ext = os.path.splitext(base)[1].lower()
    if not base or base.startswith(".") or ext not in IMAGEN_EXT:
        return ""
    return base


def _imagenes_dir(id_caso):
    return os.path.join(ACTIVO_ROOT, id_caso, "imagenes")


def _sql_files_in_dir(directory):
    if not os.path.isdir(directory):
        return []
    return sorted(
        f for f in os.listdir(directory)
        if f.lower().endswith(".sql") and os.path.isfile(os.path.join(directory, f))
    )


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

    if usar_doc and metodos:
        sql_bloque = f"""4. **SQL — métodos documentados** (no exigir `sql/` de entrada)
   - Catálogo: `{proceso_path}`
   - Métodos del formulario:
{_fmt_metodos_documentados(metodos)}
   - Lea esas fichas (`hace`, `valida`, `noValida`, `errores`, `llama`, `efecto`).
   - **No se detenga** porque `sql/` esté vacío si esos METODO cubren el REQ.
   - En el **Chat del caso** (`activo/{id_caso}/chat.json`), en el primer resumen, indique si hace falta el .sql de hoy:
     - Todos `leido` y el alcance no sale de lo documentado → seguir sin pedir el script.
     - Alguno `listado` / `no_leido` / `parcial`, o el REQ toca validaciones no documentadas → **pedir** el .sql en `sql/` (los SP se actualizan a diario).
   - No invente METODOs que no estén en `sps.json`.
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)"""
        detener = "Si falta cola, aclaración, o el Chat concluye que hay que releer el SP: **DETENER y pedir** el .sql en `sql/`."
    else:
        lista = ", ".join(sql_list) if sql_list else "(ver manifest)"
        sql_bloque = f"""4. `sql/` — scripts: {lista}
5. Qrystalos2 (`src/pages`, `src/components`, stores) y documentación (`tablas/`, runbooks)"""
        detener = "Si falta algún SQL, imagen, HTML en cola o aclaración: **DETENER y pedirla**."

    return f"""# Caso activo — INSTRUCCIÓN PARA EL AGENTE

## NO esperar prompt pegado en el chat de Cursor
Lea **del disco** en este orden:

1. `activo/{id_caso}/solicitud.json` — formulario completo
2. `activo/{id_caso}/chat.json` — mensajes del coordinador (releer en cada turno)
3. `{cola}` — HTML avalasesor (cola)
{sql_bloque}

Usted (agente en Cursor) hace el análisis técnico y también escribe los textos del formulario (criterios, análisis organizado, recomendación). OpenAI no interviene.

{detener}

## Caso
- **ID caso:** {id_caso}
- **ID REQ:** {id_req}
- **Dictamen:** dictamenes/{id_caso}.html

## Fase 1 — su tarea ahora
1. **REQ → conocimiento** (INDICE, proceso.json, sps.json; sql_refe si hace falta).
2. Proyectar **solución**: criteriosAceptacion, alcance, restricciones, analisis, recomendacion + lista de SP/METODO documentados a usar.
3. Resumir en `chat.json` (autor: agente). No convertir el Chat en cuestionario.
4. Cuando el coordinador lo pida: dictamen en `dictamenes/{id_caso}.html`.
5. Si usó métodos documentados: veredicto breve de releer o no el .sql de hoy.

## Chat
El coordinador escribe **solo** en la app (pestaña Chat → `chat.json`).
No pida que pegue el mismo texto en Cursor. Relea `chat.json` en cada turno y responda ahí (autor: `agente`).

## Contabilidad
Si `solicitud.json` → `contenido.contabilidad.afecta` es true, valide cómoAfecta y desarrollo
contra Qrystalos2 (MCUE, CON, MCPE) y documentación. Escriba el veredicto en el Chat y en
`contenido.contabilidad.validacion`.

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

        if len(parts) >= 2 and parts[0] == "api" and parts[1] == "health":
            db = get_db()
            return self._json({
                "ok": True,
                "version": 4,
                "db": db.db_path,
                "features": ["sql", "caso", "chat", "documentos", "historico", "cola", "borrador", "chatSinOpenAI", "cursorBot", "desarrolladores", "correo", "conocimiento", "criteriosAgente", "imagenes"],
                "openai": {"configurado": False, "deshabilitado": True, "motivo": "Los textos del formulario los escribe el agente (Cursor)."},
                "cursorBot": {
                    "configurado": bool(load_api_key()),
                    "modelo": os.environ.get("CURSOR_BOT_MODEL", "composer-2.5"),
                },
                "agentes": {
                    "analista": "por caso en activo/",
                    "consultas": leer_estado_bot(CONSULTAS_ID),
                    "documentar": leer_estado_bot(DOCUMENTAR_ID),
                    "vigilante": kb.load_vigilante(),
                    "valle": kb.siguiente_valle(),
                },
            })

        if len(parts) == 2 and parts[0] == "api" and parts[1] == "openai":
            return self._json({
                "configurado": False,
                "deshabilitado": True,
                "motivo": "OpenAI retirado del formulario. Criterios y textos los escribe el agente.",
            })

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
            data = kb.resumen(canal)
            data["bot"] = leer_estado_bot(kb.bot_id(canal))
            return self._json(data)

        if len(parts) >= 4 and parts[0] == "api" and parts[1] == "conocimiento" and parts[2] == "proceso":
            proc = kb.load_proceso(unquote(parts[3]))
            if not proc:
                return self._json({"error": "Proceso no encontrado"}, 404)
            return self._json({"ok": True, "proceso": proc})

        if len(parts) >= 2 and parts[0] == "api" and parts[1] == "sql":
            return self._list_sql()

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "chat":
            return self._get_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "estado":
            return self._get_estado(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "solicitud":
            return self._get_solicitud(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "documentos":
            return self._get_documentos(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "dictamen":
            return self._serve_dictamen(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("imagenes", "imagen", "capturas"):
            return self._list_imagenes(unquote(parts[2]))

        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("imagenes", "imagen", "capturas"):
            return self._serve_imagen(unquote(parts[2]), unquote(parts[4]))

        if parsed.path in ("", "/"):
            self.send_response(302)
            self.send_header("Location", "/app/")
            self.end_headers()
            return

        if parts and parts[0] == "api":
            return self._json({"error": f"Ruta no encontrada: GET {parsed.path}"}, 404)

        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]

        if parts == ["api", "sql", "archivar"]:
            return self._archivar_sql()

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

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "solicitud":
            return self._post_solicitud(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "chat":
            return self._post_chat(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] == "cerrar-fase1":
            return self._cerrar_fase1(unquote(parts[2]))

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("imagenes", "imagen", "capturas"):
            return self._post_imagenes(unquote(parts[2]))

        return self._json({"error": f"Ruta no encontrada: POST {parsed.path}"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "caso" and parts[3] in ("imagenes", "imagen", "capturas"):
            return self._delete_imagen(unquote(parts[2]), unquote(parts[4]))
        return self._json({"error": f"Ruta no encontrada: DELETE {parsed.path}"}, 404)

    def _imagenes_payload(self, id_caso):
        carpeta = _imagenes_dir(id_caso)
        os.makedirs(carpeta, exist_ok=True)
        archivos = []
        for name in sorted(os.listdir(carpeta)):
            ruta = os.path.join(carpeta, name)
            if not os.path.isfile(ruta):
                continue
            ext = os.path.splitext(name)[1].lower()
            if ext not in IMAGEN_EXT:
                continue
            archivos.append({
                "nombre": name,
                "ruta": f"activo/{id_caso}/imagenes/{name}",
                "url": f"/api/caso/{id_caso}/imagenes/{name}",
                "bytes": os.path.getsize(ruta),
            })
        return {
            "ok": True,
            "idCaso": id_caso,
            "carpeta": f"activo/{id_caso}/imagenes/",
            "archivos": archivos,
        }

    def _list_imagenes(self, id_caso):
        id_caso = _safe_id_caso(id_caso)
        if not id_caso:
            return self._json({"error": "ID caso inválido"}, 400)
        return self._json(self._imagenes_payload(id_caso))

    def _serve_imagen(self, id_caso, nombre):
        id_caso = _safe_id_caso(id_caso)
        nombre = _safe_imagen_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Ruta de imagen inválida"}, 400)
        path = os.path.join(_imagenes_dir(id_caso), nombre)
        if not os.path.isfile(path):
            return self._json({"error": "Imagen no encontrada", "ruta": f"activo/{id_caso}/imagenes/{nombre}"}, 404)
        ext = os.path.splitext(nombre)[1].lower()
        with open(path, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", IMAGEN_MIME.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _read_upload_imagen(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length <= 0:
            raise ValueError("No vino contenido.")
        if length > IMAGEN_MAX + 8192:
            raise ValueError("La captura supera 10 MB.")
        raw = self.rfile.read(length)
        ctype = (self.headers.get("Content-Type") or "").lower()
        if "multipart/form-data" in ctype:
            header = f"Content-Type: {self.headers.get('Content-Type')}\r\n\r\n".encode("utf-8")
            msg = BytesParser(policy=email_policy).parsebytes(header + raw)
            for part in msg.iter_parts():
                fn = part.get_filename()
                if not fn:
                    continue
                payload = part.get_payload(decode=True)
                if payload:
                    return fn, payload
            raise ValueError("No vino archivo en el formulario.")
        if "json" in ctype or raw[:1] in (b"{", b"["):
            data = json.loads(raw.decode("utf-8"))
            nombre = data.get("nombre") or data.get("filename") or data.get("fileName") or ""
            b64 = data.get("contenido") or data.get("data") or data.get("base64") or ""
            if isinstance(b64, str) and b64.startswith("data:") and "," in b64:
                b64 = b64.split(",", 1)[1]
            if not b64:
                raise ValueError("Falta el contenido de la imagen.")
            return nombre, base64.b64decode(b64)
        raise ValueError("Use JSON o multipart para subir la captura.")

    def _post_imagenes(self, id_caso):
        id_caso = _safe_id_caso(id_caso)
        if not id_caso:
            return self._json({"error": "Indique un ID caso válido (paso 1) para guardar la captura."}, 400)
        try:
            nombre_in, payload = self._read_upload_imagen()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        except ValueError as exc:
            return self._json({"error": str(exc)}, 400)
        except Exception as exc:
            return self._json({"error": f"No se pudo leer la captura: {exc}"}, 400)

        nombre = _safe_imagen_nombre(nombre_in)
        if not nombre:
            return self._json({"error": "Use PNG, JPG, GIF o WebP."}, 400)
        if len(payload) > IMAGEN_MAX:
            return self._json({"error": "La captura supera 10 MB."}, 400)

        carpeta = _imagenes_dir(id_caso)
        os.makedirs(carpeta, exist_ok=True)
        dest = os.path.join(carpeta, nombre)
        if os.path.isfile(dest):
            stem, ext = os.path.splitext(nombre)
            n = 2
            while os.path.isfile(os.path.join(carpeta, f"{stem}_{n}{ext}")):
                n += 1
            nombre = f"{stem}_{n}{ext}"
            dest = os.path.join(carpeta, nombre)
        with open(dest, "wb") as fh:
            fh.write(payload)

        try:
            get_db().append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
                    "autor": "sistema",
                    "texto": f"Captura guardada: activo/{id_caso}/imagenes/{nombre}",
                    "fecha": datetime.now().isoformat(timespec="seconds"),
                },
            )
        except Exception:
            pass

        data = self._imagenes_payload(id_caso)
        data["nombre"] = nombre
        data["mensaje"] = f"Guardada en activo/{id_caso}/imagenes/{nombre}"
        return self._json(data)

    def _delete_imagen(self, id_caso, nombre):
        id_caso = _safe_id_caso(id_caso)
        nombre = _safe_imagen_nombre(nombre)
        if not id_caso or not nombre:
            return self._json({"error": "Ruta de imagen inválida"}, 400)
        path = os.path.join(_imagenes_dir(id_caso), nombre)
        if os.path.isfile(path):
            os.remove(path)
        return self._json(self._imagenes_payload(id_caso))

    def _read_json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if not length:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

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
        vig = kb.load_vigilante()
        if "activo" in body:
            vig["activo"] = bool(body.get("activo"))
        if body.get("intervaloMin"):
            try:
                vig["intervaloMin"] = max(5, int(body["intervaloMin"]))
            except (TypeError, ValueError):
                pass
        kb.save_vigilante(vig)
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
        chat_info = kb.resumen(canal)
        if chat_info.get("chatSoloLectura"):
            return self._json({"error": "Este chat está archivado. Cree uno nuevo o ábralo solo para leer."}, 409)
        kb.append_chat(autor, texto, proceso_id, canal)
        kb.append_chat(
            "sistema",
            "El agente está trabajando. En unos segundos responde aquí (autor agente).",
            proceso_id,
            canal,
        )
        bot = lanzar_bot(kb.bot_id(canal), canal)
        if not bot.get("ok"):
            time.sleep(2)
            st = leer_estado_bot(kb.bot_id(canal))
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
        chat = kb.load_chat(canal)
        return self._json({"ok": True, "chat": chat, "bot": bot, "canal": canal})

    def _post_conocimiento_chat_accion(self, accion: str):
        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            return self._json({"error": "JSON inválido"}, 400)
        canal = body.get("canal") or "documentar"
        if accion in ("archivar", "nuevo"):
            result = kb.nuevo_chat(canal, body.get("titulo") or "")
            return self._json(result)
        sid = (body.get("id") or "").strip()
        if not sid:
            return self._json({"error": "Falta id del chat"}, 400)
        result = kb.abrir_chat(canal, sid)
        return self._json(result, 200 if result.get("ok") else 404)

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
        except Exception as exc:
            print(f"ERROR activar caso {id_caso}: {exc}", flush=True)
            return self._json({"ok": False, "error": str(exc)}, 500)

        try:
            self._upsert_dev_desde_solicitud(solicitud)
        except Exception as exc:
            print(f"WARN desarrolladores al activar {id_caso}: {exc}", flush=True)

        bot = {}
        try:
            bot = lanzar_bot(id_caso, "activar")
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
        db.guardar_solicitud(id_caso, solicitud)
        bot = {}
        if body.get("validarContabilidad"):
            bot = lanzar_bot(id_caso, "contabilidad")
        if body.get("analizarRequerimiento"):
            ahora = datetime.now().isoformat(timespec="seconds")
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
                    "autor": "coordinador",
                    "texto": (
                        "Analiza el requerimiento contrastándolo con la base de conocimiento "
                        "(proceso/sps). Proponga solución, criterios de aceptación, alcance, "
                        "restricciones y análisis; liste los SP/METODO documentados a usar. "
                        "No haga el dictamen completo. Deje el resultado en este Chat y en "
                        "solicitud.contenido (criterios, alcance, restricciones, analisis, "
                        "brechaAnalisis)."
                    ),
                    "fecha": ahora,
                },
            )
            db.append_chat(
                id_caso,
                {
                    "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "w",
                    "autor": "sistema",
                    "texto": "El agente está contrastando el REQ con conocimiento/. Criterios, alcance y SPs quedan en el formulario y en el Chat.",
                    "fecha": ahora,
                },
            )
            bot = lanzar_bot(id_caso, "analizar-req")
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
                        "recomendacion y criteriosMeta (fuente: agente). Resuma en este Chat. "
                        "No haga el dictamen completo."
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
            bot = lanzar_bot(id_caso, "criterios")
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
        return self._json({"ok": True, "bot": bot})

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
        aviso = {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "w",
            "autor": "sistema",
            "texto": "El agente está trabajando. El temporizador de arriba confirma que el proceso sigue vivo.",
            "fecha": datetime.now().isoformat(timespec="seconds"),
        }
        db.append_chat(id_caso, aviso)
        bot = lanzar_bot(id_caso, "chat")
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
        devs.upsert(nombre, caso={
            "idReq": ident.get("idReq") or "",
            "idCaso": id_caso,
            "cliente": proyecto.get("nombre") or "",
            "modulo": proyecto.get("modulo") or "",
            "rama": gestion.get("rama") or "",
            "dictamen": f"dictamenes/{id_caso}.html" if id_caso else "",
            "fase1": fase1 or "abierta",
        })

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
            cola = get_db().get_cola()
            return self._json(devs.sync_all(cola))
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
        get_db().reconciliar_cerrados()
        return self._json({"items": get_db().get_cola()})

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

        img_dir = os.path.join(ROOT, "activo", id_caso, "imagenes")
        if os.path.isdir(img_dir):
            for name in sorted(os.listdir(img_dir)):
                ext = os.path.splitext(name)[1].lower()
                if ext not in IMAGEN_EXT:
                    continue
                if not os.path.isfile(os.path.join(img_dir, name)):
                    continue
                docs.append({
                    "tipo": "imagen",
                    "titulo": name,
                    "ruta": f"activo/{id_caso}/imagenes/{name}",
                    "url": f"/api/caso/{id_caso}/imagenes/{name}",
                    "estado": "interno",
                })

        return self._json({"idCaso": id_caso, "documentos": docs})

    def _dictamen_path(self, id_caso):
        solicitud = get_db().get_solicitud(id_caso)
        dictamen_rel = ((solicitud.get("rutas") or {}).get("dictamen") or f"dictamenes/{id_caso}.html").replace("\\", "/")
        dictamen_abs = os.path.join(ROOT, *dictamen_rel.split("/"))
        return dictamen_rel, dictamen_abs

    def _serve_dictamen(self, id_caso):
        dictamen_rel, dictamen_abs = self._dictamen_path(id_caso)
        if not os.path.isfile(dictamen_abs):
            return self._json({"error": "Dictamen no encontrado", "ruta": dictamen_rel}, 404)

        with open(dictamen_abs, "rb") as fh:
            body = fh.read()

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
                        item["estado"] = "enviado"
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
        os.makedirs(os.path.join(dest_dir, "imagenes"), exist_ok=True)
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

        dest_dir = os.path.join(SQL_REF_ROOT, id_req)
        os.makedirs(dest_dir, exist_ok=True)
        archivos = _sql_files_in_dir(SQL_ROOT)
        movidos = []
        for nombre in archivos:
            src = os.path.join(SQL_ROOT, nombre)
            dst = os.path.join(dest_dir, nombre)
            if os.path.exists(dst):
                base, ext = os.path.splitext(nombre)
                dst = os.path.join(dest_dir, f"{base}_{id_caso or 'dup'}{ext}")
            shutil.move(src, dst)
            movidos.append(os.path.basename(dst))

        meta = {
            "idReq": id_req,
            "idCaso": id_caso,
            "archivadoEn": datetime.now().isoformat(timespec="seconds"),
            "archivos": movidos,
        }
        with open(os.path.join(dest_dir, "archivo.json"), "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False, indent=2)

        self._write_sql_manifest(_sql_files_in_dir(SQL_ROOT))
        if not movidos:
            return {
                "ok": True,
                "movidos": [],
                "destinoRelativo": f"sql_refe/{id_req}",
                "mensaje": "No había .sql en sql/ para archivar.",
            }
        return {
            "ok": True,
            "movidos": movidos,
            "destinoRelativo": f"sql_refe/{id_req}",
            "mensaje": f"Archivados {len(movidos)} .sql en sql_refe/{id_req}/. sql/ limpia.",
        }

    def _list_sql(self):
        archivos = _sql_files_in_dir(SQL_ROOT)
        self._write_sql_manifest(archivos)
        return self._json({
            "ok": True,
            "ruta": SQL_ROOT,
            "rutaRelativa": "sql",
            "archivos": archivos,
            "mensaje": None if archivos else "No hay .sql en sql/",
        })

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
            return self._json({"error": result.get("mensaje") or "No hay .sql en sql/"}, 404)
        return self._json(result)

    def end_headers(self):
        path = (urlparse(self.path).path or "").lower()
        if path.endswith(".html") and ("/dictamenes/" in path or path.endswith("/dictamen")):
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
        super().end_headers()

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

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
    print(f"SQL:     sql/", flush=True)
    print(f"Procesos: conocimiento/", flush=True)
    try:
        import documentar_vigilante as docvig

        docvig.start_background(45)
    except Exception as exc:
        print(f"Documentar vigilante no arrancó: {exc}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
