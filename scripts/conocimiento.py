#!/usr/bin/env python3
"""Base de conocimiento de procesos (flujos + explicación; no cuerpos de SP)."""
from __future__ import annotations

import json
import os
import re
import time
import threading
import uuid
from contextlib import contextmanager
import copy
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
SQL_ROOT = os.path.join(ROOT, "sql")
# Copias locales de SP (fuera de git, ver .gitignore). Se leen si existen; nunca se exigen.
SQL_REFE_ROOT = os.path.join(ROOT, "sql_refe")

CAPAS_ESQUELETO = [
    {
        "id": "01-configuracion",
        "numero": 1,
        "nombre": "Configuración",
        "estado": "pendiente",
        "explicacion": "Qué debe estar parametrizado antes de operar.",
        "tablasClave": [],
        "controles": [],
    },
    {
        "id": "02-operacion",
        "numero": 2,
        "nombre": "Proceso propio",
        "estado": "pendiente",
        "explicacion": "Acciones del usuario y controles (abrir, confirmar, etc.).",
        "tablasClave": [],
        "controles": [],
    },
    {
        "id": "03-alimentadores",
        "numero": 3,
        "nombre": "Lo que llega y completa",
        "estado": "pendiente",
        "explicacion": "Orígenes externos que alimentan este proceso.",
        "tablasClave": [],
        "controles": [],
    },
    {
        "id": "04-bancos",
        "numero": 4,
        "nombre": "Subproceso unido (p. ej. bancos)",
        "estado": "pendiente",
        "explicacion": "Solo el encuentro con este proceso, no el módulo entero.",
        "tablasClave": [],
        "controles": [],
    },
    {
        "id": "05-contabilidad",
        "numero": 5,
        "nombre": "Envío a contabilidad",
        "estado": "pendiente",
        "explicacion": "Qué se entrega al asiento y qué se asume ya validado.",
        "tablasClave": [],
        "controles": [],
    },
]


def controles_de(capa: dict | None) -> list:
    """Controles de una capa. Oficial: `controles`. Fichas antiguas: `gates`."""
    if not capa:
        return []
    return capa.get("controles") or capa.get("gates") or []


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _read_json(path: str, default):
    if not os.path.isfile(path):
        return default
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return default


def _write_json(path: str, data) -> None:
    """Escritura atómica: evita chat.json truncado si el proceso muere a mitad."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    # pid + hilo + azar: el servidor es multihilo y varios bots escriben a la vez.
    tmp = f"{path}.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex[:6]}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        last_err = None
        for attempt in range(6):
            try:
                os.replace(tmp, path)
                last_err = None
                break
            except OSError as e:
                last_err = e
                if attempt < 5:
                    time.sleep(0.04 * (attempt + 1))
        if last_err:
            raise last_err
    except Exception:
        try:
            if os.path.isfile(tmp):
                os.remove(tmp)
        except OSError:
            pass
        raise


def indice_path() -> str:
    return os.path.join(CONOCIMIENTO, "INDICE.json")


def pendientes_path() -> str:
    return os.path.join(CONOCIMIENTO, "pendientes.json")


def ruta_path() -> str:
    return os.path.join(CONOCIMIENTO, "RUTA.json")


def vigilante_path() -> str:
    return os.path.join(CONOCIMIENTO, "canales", "documentar", "vigilante.json")


def chat_path() -> str:
    return os.path.join(CONOCIMIENTO, "chat.json")


CANALES_CHAT = ("consultas", "documentar")
BOT_IDS = {
    "consultas": "__consultas__",
    "documentar": "__documentar__",
}


KB_SEP = "~"
_SID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


def bot_id(canal: str, sid: str = "") -> str:
    """Id del bot. Con sid: un bot (y una sesión Cursor) por chat, para chats en paralelo."""
    base = BOT_IDS.get(_norm_canal(canal), BOT_IDS["documentar"])
    sid = (sid or "").strip()
    if sid and _SID_RE.match(sid):
        return f"{base}{KB_SEP}{sid}"
    return base


def sesion_run_dir(canal: str, sid: str) -> str:
    """Carpeta de trabajo de un chat: bot.json, agente.json, bot.log y chat.json propio."""
    if not _SID_RE.match(sid or ""):
        raise ValueError("id de chat inválido")
    d = os.path.join(canal_live_dir(canal), "sesiones", sid)
    os.makedirs(d, exist_ok=True)
    return d


_LOCK_LOCAL = threading.RLock()
_LOCK_TLS = threading.local()


@contextmanager
def _lock_chats(canal: str, espera_sec: float = 15.0):
    """Exclusión entre hilos del servidor y procesos bot al tocar index.json / sesiones."""
    with _LOCK_LOCAL:
        depth = getattr(_LOCK_TLS, "depth", 0)
        if depth:
            _LOCK_TLS.depth = depth + 1
            try:
                yield
            finally:
                _LOCK_TLS.depth -= 1
            return
        os.makedirs(chats_dir(canal), exist_ok=True)
        path = os.path.join(chats_dir(canal), ".lock")
        fin = time.time() + espera_sec
        fd = None
        while fd is None:
            try:
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError:
                try:
                    if time.time() - os.path.getmtime(path) > 30:
                        os.remove(path)  # lock huérfano de un proceso caído
                        continue
                except OSError:
                    pass
                if time.time() > fin:
                    break  # mejor escribir sin lock que colgar el chat
                time.sleep(0.05)
        _LOCK_TLS.depth = 1
        try:
            yield
        finally:
            _LOCK_TLS.depth = 0
            if fd is not None:
                os.close(fd)
                try:
                    os.remove(path)
                except OSError:
                    pass


def _norm_canal(canal: str) -> str:
    c = (canal or "").strip().lower()
    return c if c in CANALES_CHAT else "documentar"


def chats_dir(canal: str) -> str:
    return os.path.join(CONOCIMIENTO, "chats", _norm_canal(canal))


def canal_live_dir(canal: str) -> str:
    return os.path.join(CONOCIMIENTO, "canales", _norm_canal(canal))


def _index_path(canal: str) -> str:
    return os.path.join(chats_dir(canal), "index.json")


def _sesion_path(canal: str, sid: str) -> str:
    return os.path.join(chats_dir(canal), f"{sid}.json")


def _nombre_proceso(proceso_id: str) -> str:
    pid = (proceso_id or "").strip()
    if not pid:
        return ""
    for p in load_indice().get("procesos") or []:
        if p.get("id") == pid:
            return (p.get("nombre") or pid).strip()
    return pid


def _titulo_default(canal: str, proceso_id: str = "") -> str:
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    nombre = _nombre_proceso(proceso_id) if proceso_id else ""
    if nombre:
        return f"{nombre} · {stamp}"
    puerta = "Consulta" if canal == "consultas" else "Documentar"
    return f"{puerta} · {stamp}"


def _nuevo_sid(canal: str) -> str:
    canal = _norm_canal(canal)
    sid = "c" + datetime.now().strftime("%Y%m%d%H%M%S") + uuid.uuid4().hex[:4]
    if os.path.isfile(_sesion_path(canal, sid)):
        sid = "c" + datetime.now().strftime("%Y%m%d%H%M%S") + uuid.uuid4().hex[:6]
    return sid


def _sync_live(canal: str, chat: dict) -> None:
    live = canal_live_dir(canal)
    os.makedirs(live, exist_ok=True)
    _write_json(os.path.join(live, "chat.json"), chat)
    if canal == "documentar":
        _write_json(chat_path(), chat)


def _empty_chat(canal: str, sid: str, titulo: str, proceso_id: str = "") -> dict:
    return {
        "id": sid,
        "canal": canal,
        "titulo": titulo,
        "estado": "activo",
        "procesoId": proceso_id or "",
        "creadoEn": _now(),
        "archivadoEn": None,
        "mensajes": [],
    }


def _ensure_canal(canal: str) -> dict:
    canal = _norm_canal(canal)
    os.makedirs(chats_dir(canal), exist_ok=True)
    os.makedirs(canal_live_dir(canal), exist_ok=True)
    idx = _read_json(_index_path(canal), {}) or {}
    idx.setdefault("items", [])
    if idx.get("items") or (
        idx.get("activoId") and os.path.isfile(_sesion_path(canal, idx["activoId"]))
    ):
        _migrar_chats_por_modulo(canal)
        idx2 = _read_json(_index_path(canal), {}) or {}
        if not idx2.get("items"):
            idx2 = idx
        idx2.setdefault("items", [])
        idx2.setdefault("activoPorProceso", {})
        _limpiar_activo_archivado(idx2)
        if idx2.get("activoId") != (idx.get("activoId") or "") or idx2.get("viendoId") != (idx.get("viendoId") or ""):
            _save_index(canal, idx2)
        return idx2

    legacy = load_chat_legacy() if canal == "documentar" else {"mensajes": []}
    msgs = legacy.get("mensajes") or []
    sid = _nuevo_sid(canal)
    titulo = "Chat histórico" if msgs else _titulo_default(canal)
    chat = _empty_chat(canal, sid, titulo, legacy.get("procesoId") or "")
    chat["mensajes"] = msgs
    _write_json(_sesion_path(canal, sid), chat)
    idx = {
        "activoId": sid,
        "viendoId": sid,
        "activoPorProceso": {},
        "chatsPorModulo": False,
        "items": [
            {
                "id": sid,
                "titulo": titulo,
                "estado": "activo",
                "procesoId": chat.get("procesoId") or "",
                "creadoEn": chat["creadoEn"],
                "archivadoEn": None,
                "mensajes": len(msgs),
            }
        ],
    }
    _write_json(_index_path(canal), idx)
    _sync_live(canal, chat)
    _migrar_chats_por_modulo(canal)
    return _read_json(_index_path(canal), idx) or idx


def load_chat_legacy() -> dict:
    data = _read_json(chat_path(), {"procesoId": "", "mensajes": []})
    if "mensajes" not in data:
        data["mensajes"] = []
    return data


def _save_index(canal: str, idx: dict) -> None:
    _write_json(_index_path(canal), idx)


def _titulo_es_generico(titulo: str) -> bool:
    t = (titulo or "").strip()
    cabeza = t.split(" · ", 1)[0].strip() if t else ""
    return (
        t == "Chat histórico"
        or t.startswith("Histórico mixto")
        or t.startswith("Histórico (sin módulo)")
        or t.startswith("Histórico cruzado")
        or cabeza in ("Consulta", "Documentar", "Prueba archivo API")
    )


def _id_desde_titulo(titulo: str) -> str:
    """Si la cabeza del título es un proceso del índice, devuelve su id."""
    cabeza = (titulo or "").split(" · ", 1)[0].strip()
    if not cabeza:
        return ""
    clave = cabeza.upper()
    for p in load_indice().get("procesos") or []:
        pid = (p.get("id") or "").strip()
        nombre = (p.get("nombre") or "").strip()
        if pid and (pid.upper() == clave or nombre.upper() == clave):
            return pid
    return ""


def _reparar_chats_cruzados(canal: str, idx: dict) -> bool:
    """Reengancha huérfanos y suelta punteros cuyo procesoId no coincide."""
    canal = _norm_canal(canal)
    carpeta = chats_dir(canal)
    changed = False
    if not os.path.isdir(carpeta):
        return False
    conocidos = {item.get("id") for item in (idx.get("items") or []) if item.get("id")}
    for nombre in os.listdir(carpeta):
        if not nombre.startswith("c") or not nombre.endswith(".json"):
            continue
        sid = nombre[:-5]
        if sid in conocidos:
            continue
        chat = _read_json(os.path.join(carpeta, nombre), None)
        if not chat or not chat.get("id"):
            continue
        _touch_item(idx, chat)
        conocidos.add(chat.get("id"))
        changed = True
    por_proceso = idx.setdefault("activoPorProceso", {})
    for pid, sid in list(por_proceso.items()):
        chat = _read_json(_sesion_path(canal, sid), None) if sid else None
        chat_pid = ((chat or {}).get("procesoId") or "").strip()
        if (
            not chat
            or (chat or {}).get("estado") == "archivado"
            or _titulo_es_generico((chat or {}).get("titulo") or "")
            or (chat_pid and chat_pid != pid)
        ):
            del por_proceso[pid]
            changed = True
    for item in idx.get("items") or []:
        if item.get("estado") == "archivado":
            continue
        pid = (item.get("procesoId") or "").strip()
        sid = item.get("id") or ""
        if not pid or not sid or not os.path.isfile(_sesion_path(canal, sid)):
            continue
        chat = _read_json(_sesion_path(canal, sid), None)
        if not chat or (chat.get("procesoId") or "").strip() != pid:
            continue
        if _titulo_es_generico(chat.get("titulo") or ""):
            continue
        actual = por_proceso.get(pid) or ""
        if actual == sid:
            continue
        rival = _read_json(_sesion_path(canal, actual), None) if actual else None
        usar = False
        if not rival or (rival.get("procesoId") or "").strip() != pid or rival.get("estado") == "archivado":
            usar = True
        elif len(chat.get("mensajes") or []) > len(rival.get("mensajes") or []):
            usar = True
        if usar:
            por_proceso[pid] = sid
            changed = True
    return changed


def _migrar_chats_por_modulo(canal: str) -> None:
    """Marca el chat mixto como archivo y deja chats por proceso."""
    canal = _norm_canal(canal)
    idx = _read_json(_index_path(canal), {}) or {}
    idx.setdefault("items", [])
    idx.setdefault("activoPorProceso", {})
    changed = False
    for item in idx.get("items") or []:
        item.setdefault("procesoId", "")
        sid = item.get("id") or ""
        if not sid:
            continue
        chat = _read_json(_sesion_path(canal, sid), None)
        if not chat:
            continue
        pid = (chat.get("procesoId") or item.get("procesoId") or "").strip()
        n = len(chat.get("mensajes") or [])
        titulo = (chat.get("titulo") or item.get("titulo") or "").strip()
        cabeza = titulo.split(" · ", 1)[0].strip() if titulo else ""
        es_generico = (
            titulo == "Chat histórico"
            or titulo.startswith("Histórico mixto")
            or titulo.startswith("Histórico (sin módulo)")
            or titulo.startswith("Histórico cruzado")
            or cabeza in ("Consulta", "Documentar", "Prueba archivo API")
        )
        pid_titulo = _id_desde_titulo(titulo)
        cruzado = bool(
            pid
            and pid_titulo
            and pid_titulo != pid
            and item.get("estado") != "archivado"
        )
        mixto = item.get("estado") != "archivado" and (
            not pid or es_generico or n > 100 or cruzado
        )
        if mixto:
            if cruzado:
                chat["titulo"] = f"Histórico cruzado ({cabeza} / {pid})"
            else:
                chat["titulo"] = (
                    "Histórico mixto (varios módulos)" if n > 20 else "Histórico (sin módulo)"
                )
            chat["estado"] = "archivado"
            chat["procesoId"] = ""
            if not chat.get("archivadoEn"):
                chat["archivadoEn"] = _now()
            _write_json(_sesion_path(canal, sid), chat)
            item["titulo"] = chat["titulo"]
            item["estado"] = "archivado"
            item["archivadoEn"] = chat["archivadoEn"]
            item["procesoId"] = ""
            for k, v in list((idx.get("activoPorProceso") or {}).items()):
                if v == sid:
                    del idx["activoPorProceso"][k]
            changed = True
        elif pid and item.get("estado") != "archivado":
            idx["activoPorProceso"][pid] = sid
            item["procesoId"] = pid
            if chat.get("procesoId") != pid:
                chat["procesoId"] = pid
                _write_json(_sesion_path(canal, sid), chat)
        item["mensajes"] = n
    if idx.get("chatsPorModulo") is not True:
        idx["chatsPorModulo"] = True
        changed = True
    _limpiar_activo_archivado(idx)
    if _reparar_chats_cruzados(canal, idx):
        changed = True
    if changed:
        _save_index(canal, idx)


def _limpiar_activo_archivado(idx: dict) -> None:
    aid = idx.get("activoId") or ""
    for item in idx.get("items") or []:
        if item.get("id") == aid and item.get("estado") == "archivado":
            idx["activoId"] = ""
            if (idx.get("viendoId") or "") == aid:
                idx["viendoId"] = ""
            break


def asegurar_chat_proceso(canal: str, proceso_id: str) -> dict:
    with _lock_chats(canal):
        return _asegurar_chat_proceso_sin_lock(canal, proceso_id)


def _asegurar_chat_proceso_sin_lock(canal: str, proceso_id: str) -> dict:
    """Chat activo (escribible) de un módulo. Crea uno vacío si no hay."""
    canal = _norm_canal(canal)
    pid = (proceso_id or "").strip()
    idx = _ensure_canal(canal)
    idx.setdefault("activoPorProceso", {})
    if not pid:
        return load_sesion(canal, idx.get("viendoId") or idx.get("activoId"))

    sid = (idx.get("activoPorProceso") or {}).get(pid) or ""
    if sid and os.path.isfile(_sesion_path(canal, sid)):
        chat = load_sesion(canal, sid)
        chat_pid = (chat.get("procesoId") or "").strip()
        if (
            chat.get("estado") != "archivado"
            and not _titulo_es_generico(chat.get("titulo") or "")
            and len(chat.get("mensajes") or []) <= 100
            and (not chat_pid or chat_pid == pid)
        ):
            if chat_pid != pid:
                chat["procesoId"] = pid
                _write_json(_sesion_path(canal, sid), chat)
            idx["activoId"] = sid
            idx["viendoId"] = sid
            idx["activoPorProceso"][pid] = sid
            _save_index(canal, idx)
            _sync_live(canal, chat)
            return chat

    for item in idx.get("items") or []:
        if (item.get("procesoId") or "") == pid and item.get("estado") != "archivado":
            sid = item.get("id") or ""
            if sid and os.path.isfile(_sesion_path(canal, sid)):
                chat = load_sesion(canal, sid)
                chat_pid = (chat.get("procesoId") or "").strip()
                if _titulo_es_generico(chat.get("titulo") or "") or len(chat.get("mensajes") or []) > 100:
                    continue
                if chat_pid and chat_pid != pid:
                    continue
                idx["activoId"] = sid
                idx["viendoId"] = sid
                idx["activoPorProceso"][pid] = sid
                _save_index(canal, idx)
                _sync_live(canal, chat)
                return chat

    sid = _nuevo_sid(canal)
    chat = _empty_chat(canal, sid, _titulo_default(canal, pid), pid)
    nombre = _nombre_proceso(pid) or pid
    chat["mensajes"].append(
        {
            "id": str(uuid.uuid4())[:8],
            "autor": "agente",
            "texto": (
                f"Este Chat es independiente y solo de «{nombre}». "
                "Facturación no mezcla caja (ni al revés). "
                "Nuevo abre otra conversación de este mismo módulo; Historial archiva la actual. "
                "Cada requerimiento tiene su propio Chat en Analista de negocio."
            ),
            "en": _now(),
        }
    )
    _write_json(_sesion_path(canal, sid), chat)
    idx["activoPorProceso"][pid] = sid
    idx["activoId"] = sid
    idx["viendoId"] = sid
    _touch_item(idx, chat)
    _save_index(canal, idx)
    _sync_live(canal, chat)
    return chat


def load_sesion(canal: str, sid: str | None = None) -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    sid = sid or idx.get("viendoId") or idx.get("activoId") or ""
    if not sid:
        return _empty_chat(canal, "vacio", _titulo_default(canal))
    data = _read_json(_sesion_path(canal, sid), None)
    if not data:
        data = _empty_chat(canal, sid or "vacio", _titulo_default(canal))
    data.setdefault("mensajes", [])
    if sid and sid == idx.get("activoId"):
        live = _read_json(os.path.join(canal_live_dir(canal), "chat.json"), None)
        live_id = (live or {}).get("id") or ""
        if live and live_id == sid and isinstance(live.get("mensajes"), list):
            live_msgs = live.get("mensajes") or []
            if live_msgs != (data.get("mensajes") or []):
                data["mensajes"] = live_msgs
                live_pid = (live.get("procesoId") or "").strip()
                ses_pid = (data.get("procesoId") or "").strip()
                if live_pid and (not ses_pid or live_pid == ses_pid):
                    data["procesoId"] = live_pid
                _write_json(_sesion_path(canal, sid), data)
                _touch_item(idx, data)
                _save_index(canal, idx)
    return data


def load_chat(canal: str = "documentar") -> dict:
    return load_sesion(canal)


def list_chats(canal: str) -> list[dict]:
    idx = _ensure_canal(canal)
    return idx.get("items") or []


def _touch_item(idx: dict, chat: dict) -> None:
    found = False
    for item in idx.get("items") or []:
        if item.get("id") == chat.get("id"):
            item["titulo"] = chat.get("titulo")
            item["estado"] = chat.get("estado")
            item["archivadoEn"] = chat.get("archivadoEn")
            item["procesoId"] = chat.get("procesoId") or ""
            item["mensajes"] = len(chat.get("mensajes") or [])
            found = True
            break
    if not found:
        idx.setdefault("items", []).insert(
            0,
            {
                "id": chat.get("id"),
                "titulo": chat.get("titulo"),
                "estado": chat.get("estado"),
                "procesoId": chat.get("procesoId") or "",
                "creadoEn": chat.get("creadoEn"),
                "archivadoEn": chat.get("archivadoEn"),
                "mensajes": len(chat.get("mensajes") or []),
            },
        )


def append_chat(autor: str, texto: str, proceso_id: str = "", canal: str = "documentar") -> dict:
    with _lock_chats(canal):
        return _append_chat_sin_lock(autor, texto, proceso_id, canal)


def _append_chat_sin_lock(autor: str, texto: str, proceso_id: str = "", canal: str = "documentar") -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    pid = (proceso_id or "").strip()
    if pid:
        chat = asegurar_chat_proceso(canal, pid)
    else:
        chat = load_sesion(canal, idx.get("activoId"))
        pid = (chat.get("procesoId") or "").strip()
        if pid:
            chat = asegurar_chat_proceso(canal, pid)
    if pid:
        chat["procesoId"] = pid
    chat.setdefault("mensajes", []).append(
        {
            "id": str(uuid.uuid4())[:8],
            "autor": autor,
            "texto": (texto or "").strip(),
            "en": _now(),
        }
    )
    _write_json(_sesion_path(canal, chat["id"]), chat)
    idx = _ensure_canal(canal)
    _touch_item(idx, chat)
    idx["viendoId"] = chat["id"]
    idx["activoId"] = chat["id"]
    if pid:
        idx.setdefault("activoPorProceso", {})[pid] = chat["id"]
    _save_index(canal, idx)
    _sync_live(canal, chat)
    return chat


def archivar_chat(canal: str, titulo: str = "", proceso_id: str = "") -> dict:
    with _lock_chats(canal):
        return _archivar_chat_sin_lock(canal, titulo, proceso_id)


def _archivar_chat_sin_lock(canal: str, titulo: str = "", proceso_id: str = "") -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    pid = (proceso_id or "").strip()
    if pid:
        actual = asegurar_chat_proceso(canal, pid)
    else:
        actual = load_sesion(canal, idx.get("activoId"))
        pid = (actual.get("procesoId") or "").strip()
    if titulo.strip():
        actual["titulo"] = titulo.strip()
    actual["estado"] = "archivado"
    actual["archivadoEn"] = _now()
    if pid:
        actual["procesoId"] = pid
    _write_json(_sesion_path(canal, actual["id"]), actual)
    _touch_item(idx, actual)
    sid = _nuevo_sid(canal)
    nuevo = _empty_chat(canal, sid, _titulo_default(canal, pid), pid)
    _write_json(_sesion_path(canal, sid), nuevo)
    _touch_item(idx, nuevo)
    idx["activoId"] = sid
    idx["viendoId"] = sid
    if pid:
        idx.setdefault("activoPorProceso", {})[pid] = sid
    _save_index(canal, idx)
    _sync_live(canal, nuevo)
    return {"ok": True, "archivado": actual, "activo": nuevo, "chats": idx["items"]}


def append_chat_sesion(canal: str, sid: str, autor: str, texto: str) -> dict:
    """Agrega un mensaje a UN chat concreto sin cambiar cuál está activo o a la vista."""
    canal = _norm_canal(canal)
    with _lock_chats(canal):
        path = _sesion_path(canal, sid)
        chat = _read_json(path, None)
        if not chat:
            return {}
        chat.setdefault("mensajes", []).append(
            {"id": str(uuid.uuid4())[:8], "autor": autor, "texto": (texto or "").strip(), "en": _now()}
        )
        _write_json(path, chat)
        idx = _ensure_canal(canal)
        _touch_item(idx, chat)
        _save_index(canal, idx)
        if idx.get("activoId") == sid:
            _sync_live(canal, chat)
        return chat


def preparar_sesion_run(canal: str, sid: str) -> str:
    """Copia el chat a su carpeta de trabajo; el agente responde ahí, no en el chat.json global."""
    canal = _norm_canal(canal)
    d = sesion_run_dir(canal, sid)
    with _lock_chats(canal):
        chat = _read_json(_sesion_path(canal, sid), None) or _empty_chat(canal, sid, _titulo_default(canal))
        _write_json(os.path.join(d, "chat.json"), chat)
        _write_json(os.path.join(d, "base.json"), {"n": len(chat.get("mensajes") or [])})
    return os.path.join(d, "chat.json")


def absorber_sesion_run(canal: str, sid: str) -> int:
    """Pasa al chat real los mensajes que el agente escribió en su copia. Idempotente."""
    canal = _norm_canal(canal)
    d = sesion_run_dir(canal, sid)
    run = _read_json(os.path.join(d, "chat.json"), None) or {}
    base = int((_read_json(os.path.join(d, "base.json"), {}) or {}).get("n") or 0)
    nuevos = [m for m in (run.get("mensajes") or [])[base:] if isinstance(m, dict) and m.get("autor") != "coordinador"]
    if not nuevos:
        return 0
    with _lock_chats(canal):
        path = _sesion_path(canal, sid)
        chat = _read_json(path, None)
        if not chat:
            return 0
        for m in nuevos:
            m.setdefault("id", str(uuid.uuid4())[:8])
            m.setdefault("en", _now())
            chat.setdefault("mensajes", []).append(m)
        _write_json(path, chat)
        _write_json(os.path.join(d, "base.json"), {"n": len(run.get("mensajes") or [])})
        idx = _ensure_canal(canal)
        _touch_item(idx, chat)
        _save_index(canal, idx)
        if idx.get("activoId") == sid:
            _sync_live(canal, chat)
    return len(nuevos)


def nuevo_chat(canal: str, titulo: str = "", proceso_id: str = "") -> dict:
    return archivar_chat(canal, titulo, proceso_id)


def abrir_chat(canal: str, sid: str) -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    chat = load_sesion(canal, sid)
    if not os.path.isfile(_sesion_path(canal, sid)):
        return {"ok": False, "error": "Chat no encontrado"}
    idx["viendoId"] = sid
    _save_index(canal, idx)
    return {
        "ok": True,
        "chat": chat,
        "soloLectura": chat.get("id") != idx.get("activoId") or chat.get("estado") == "archivado",
    }


def tarea_path() -> str:
    return os.path.join(CONOCIMIENTO, "tarea.json")


def proceso_dir(proceso_id: str) -> str:
    return os.path.join(CONOCIMIENTO, proceso_id)


def proceso_json_path(proceso_id: str) -> str:
    return os.path.join(proceso_dir(proceso_id), "proceso.json")


def sps_json_path(proceso_id: str) -> str:
    return os.path.join(proceso_dir(proceso_id), "sps.json")


def faq_json_path(proceso_id: str) -> str:
    return os.path.join(proceso_dir(proceso_id), "faq.json")


_FAQ_STOP = frozenset(
    {
        "el", "la", "los", "las", "de", "del", "un", "una", "y", "o", "en", "que", "qué",
        "como", "cómo", "para", "por", "con", "se", "es", "al", "lo", "su", "sus",
        "este", "esta", "eso", "esa", "hay", "muy", "más", "mas", "sin", "sobre",
        "entre", "cuando", "donde", "dónde", "cual", "cuál", "ya", "no", "si", "sí",
        "me", "te", "le", "nos", "les", "the", "and", "for", "este", "esa",
    }
)


def load_faq(proceso_id: str) -> dict:
    pid = (proceso_id or "").strip()
    data = _read_json(faq_json_path(pid), None) if pid else None
    if not data:
        data = {
            "procesoId": pid,
            "actualizado": "",
            "nota": "Respuestas aceptadas por el coordinador. El bot solo usa coincidencias con la pregunta actual.",
            "items": [],
        }
    data.setdefault("items", [])
    data.setdefault("procesoId", pid)
    return data


def save_faq(proceso_id: str, data: dict) -> None:
    pid = (proceso_id or "").strip()
    if not pid:
        return
    data["procesoId"] = pid
    data["actualizado"] = _now()
    os.makedirs(proceso_dir(pid), exist_ok=True)
    _write_json(faq_json_path(pid), data)


def _faq_tokens(texto: str) -> set[str]:
    raw = re.findall(r"[a-záéíóúñü0-9]{3,}", (texto or "").lower())
    return {t for t in raw if t not in _FAQ_STOP}


def _faq_norm(texto: str) -> str:
    t = re.sub(r"\s+", " ", (texto or "").strip().lower())
    return t[:240]


def faq_coincidentes(proceso_id: str, pregunta: str, limite: int = 3) -> list[dict]:
    """Hasta `limite` FAQ de este módulo que coinciden con la pregunta. No devuelve el archivo entero."""
    q = (pregunta or "").strip()
    if not q:
        return []
    items = load_faq(proceso_id).get("items") or []
    if not items:
        return []
    qtok = _faq_tokens(q)
    qn = _faq_norm(q)
    scored: list[tuple[int, dict]] = []
    min_hit = 1 if len(qtok) <= 4 else 2
    for it in items:
        preg = str(it.get("pregunta") or "")
        itok = _faq_tokens(preg) | _faq_tokens(str(it.get("respuesta") or "")[:400])
        score = len(qtok & itok)
        pn = _faq_norm(preg)
        if qn and pn and (qn in pn or pn in qn):
            score += 3
        if score >= min_hit:
            scored.append((score, it))
    scored.sort(key=lambda x: -x[0])
    return [it for _, it in scored[:limite]]


def recorte_faq(proceso_id: str, pregunta: str) -> str:
    hits = faq_coincidentes(proceso_id, pregunta, 3)
    if not hits:
        return ""
    bloques = []
    for it in hits:
        p = (it.get("pregunta") or "").strip()
        r = (it.get("respuesta") or "").strip()
        if len(p) > 400:
            p = p[:380].rstrip() + "…"
        if len(r) > 1200:
            r = r[:1180].rstrip() + "…"
        bloques.append(f"P: {p}\nR: {r}")
    return (
        "Respuestas ACEPTADAS de este módulo (si cubren el pedido, úselas y no las contradiga):\n"
        + "\n---\n".join(bloques)
    )


def _es_intro_chat(texto: str) -> bool:
    t = (texto or "").strip()
    return t.startswith("Este Chat es independiente")


def aceptar_faq(canal: str, proceso_id: str, mensaje_id: str, chat_id: str = "") -> dict:
    """Guarda en conocimiento/{proceso}/faq.json la pareja pregunta (coordinador) + respuesta (agente)."""
    canal = _norm_canal(canal)
    pid = (proceso_id or "").strip()
    mid = (mensaje_id or "").strip()
    if not pid:
        return {"ok": False, "error": "Falta el módulo (procesoId)."}
    if not mid:
        return {"ok": False, "error": "Falta el id del mensaje."}
    if not load_proceso(pid) and not os.path.isdir(proceso_dir(pid)):
        return {"ok": False, "error": f"No existe el proceso '{pid}'."}

    chat = load_sesion(canal, chat_id or None)
    msgs = chat.get("mensajes") or []
    pos = next((i for i, m in enumerate(msgs) if str(m.get("id") or "") == mid), -1)
    if pos < 0:
        return {"ok": False, "error": "No está ese mensaje en este chat."}
    msg = msgs[pos]
    if (msg.get("autor") or "") != "agente":
        return {"ok": False, "error": "Solo se aceptan respuestas del agente."}
    respuesta = (msg.get("texto") or "").strip()
    if not respuesta or _es_intro_chat(respuesta):
        return {"ok": False, "error": "Esa respuesta no se guarda (es el aviso de inicio)."}

    pregunta = ""
    for m in reversed(msgs[:pos]):
        if (m.get("autor") or "") == "coordinador":
            pregunta = (m.get("texto") or "").strip()
            break
    if not pregunta:
        return {"ok": False, "error": "No hay una pregunta suya antes de esa respuesta."}

    if len(respuesta) > 8000:
        respuesta = respuesta[:7980].rstrip() + "…"

    faq = load_faq(pid)
    clave = _faq_norm(pregunta)
    found = None
    for it in faq.get("items") or []:
        if _faq_norm(it.get("pregunta") or "") == clave:
            found = it
            break
    if found:
        found["respuesta"] = respuesta
        found["aceptadoEn"] = _now()
        found["canal"] = canal
        found["mensajeId"] = mid
        found["chatId"] = chat.get("id") or ""
    else:
        faq.setdefault("items", []).append(
            {
                "id": str(uuid.uuid4())[:8],
                "pregunta": pregunta[:2000],
                "respuesta": respuesta,
                "canal": canal,
                "aceptadoEn": _now(),
                "mensajeId": mid,
                "chatId": chat.get("id") or "",
            }
        )
    save_faq(pid, faq)
    msg["aceptada"] = True
    _write_json(_sesion_path(canal, chat["id"]), chat)
    idx = _ensure_canal(canal)
    if chat.get("id") == idx.get("activoId"):
        _sync_live(canal, chat)
    return {
        "ok": True,
        "faqCount": len(faq.get("items") or []),
        "procesoId": pid,
        "chat": chat,
    }


def slug(texto: str) -> str:
    raw = (texto or "").strip().lower()
    raw = re.sub(r"[^a-z0-9áéíóúñü]+", "-", raw, flags=re.I)
    raw = raw.strip("-") or "proceso"
    return raw[:40]


def load_indice() -> dict:
    data = _read_json(indice_path(), {"actualizado": "", "procesos": []})
    if "procesos" not in data:
        data["procesos"] = []
    return data


def save_indice(data: dict) -> None:
    data["actualizado"] = _now()
    _write_json(indice_path(), data)
    _reindexar()


def load_pendientes(incluir_archivo: bool = False) -> dict:
    """Abiertos (pendientes.json). Con incluir_archivo=True suma los cerrados de pendientes-archivo.json."""
    data = _read_json(pendientes_path(), {"actualizado": "", "items": []})
    if "items" not in data:
        data["items"] = []
    if incluir_archivo:
        import kb_pendientes

        data = dict(data)
        data["items"] = list(data["items"]) + list(kb_pendientes.cargar_archivo().get("items") or [])
    return data


def _reindexar() -> None:
    """Regenera conocimiento/_indice_busqueda.json tras escribir la base (en segundo plano)."""
    try:
        import kb_indice

        kb_indice.regenerar_en_segundo_plano()
    except Exception:  # noqa: BLE001
        pass


def load_ruta() -> dict:
    data = _read_json(
        ruta_path(),
        {"activo": True, "pasos": [], "nota": ""},
    )
    data.setdefault("pasos", [])
    data.setdefault("activo", True)
    return data


def load_vigilante() -> dict:
    data = _read_json(vigilante_path(), {}) or {}
    data["activo"] = False
    data.setdefault("intervaloMin", 12)
    data.setdefault("ultimoTurnoEn", None)
    data.setdefault("ultimoProcesoId", None)
    data.setdefault("ultimoError", "")
    data.setdefault(
        "motivoPausa",
        "Barrido eliminado. Composer 2.5 estándar: Chat o Documentar SP, un turno y se detiene.",
    )
    return data


def save_vigilante(data: dict) -> None:
    data["actualizadoEn"] = _now()
    _write_json(vigilante_path(), data)


def _capas_incompletas(proc: dict) -> bool:
    capas = proc.get("capas") or []
    if not capas:
        return True
    for c in capas:
        est = (c.get("estado") or "pendiente").lower()
        if est in ("pendiente", "esqueleto", "no_leido"):
            return True
        if not (c.get("explicacion") or "").strip():
            return True
    return False


def marcar_flujo_pasado(pid: str) -> dict:
    """Marca que Documentar ya pasó por este proceso (flujo + pendientes). No espera el .sql."""
    proc = load_proceso(pid)
    if not proc:
        return {"ok": False, "error": "Proceso no encontrado"}
    proc["flujoPasado"] = True
    proc["pasadaEn"] = _now()
    if (proc.get("estado") or "").lower() == "esqueleto":
        proc["estado"] = "parcial"
    save_proceso(pid, proc)
    return {"ok": True, "proceso": load_proceso(pid)}


def proceso_pendiente_ruta(pid: str, abiertos: list | None = None) -> bool:
    """True si aún no se armó el flujo de este paso. Los pendientes de .sql no detienen la ruta."""
    proc = load_proceso(pid) or {}
    estado = (proc.get("estado") or "esqueleto").lower()
    if estado in ("completo", "listo"):
        return False
    if proc.get("flujoPasado"):
        return False
    if estado in ("esqueleto", "pendiente"):
        return True
    return _capas_incompletas(proc)


def siguiente_valle() -> dict | None:
    """Primer paso de RUTA cuyo flujo o pendientes siguen abiertos."""
    ruta = load_ruta()
    if not ruta.get("activo"):
        return None
    pendientes = load_pendientes()
    abiertos = [
        i
        for i in pendientes.get("items") or []
        if i.get("estado") != "completado"
    ]
    for paso in sorted(ruta.get("pasos") or [], key=lambda p: p.get("orden") or 99):
        pid = paso.get("procesoId") or ""
        if not pid or not proceso_pendiente_ruta(pid, abiertos):
            continue
        proc = load_proceso(pid) or {}
        pend_proc = [i for i in abiertos if i.get("procesoId") == pid]
        return {
            "paso": paso,
            "proceso": {
                "id": pid,
                "nombre": proc.get("nombre") or paso.get("nombre") or pid,
                "estado": (proc.get("estado") or "esqueleto").lower(),
            },
            "pendientesAbiertos": len(pend_proc),
            "sqlArchivos": sql_files(),
        }
    return None


def ruta_resumen() -> dict:
    ruta = load_ruta()
    abiertos = [
        i
        for i in (load_pendientes().get("items") or [])
        if i.get("estado") != "completado"
    ]
    hechos = []
    faltan = []
    for paso in sorted(ruta.get("pasos") or [], key=lambda p: p.get("orden") or 99):
        pid = paso.get("procesoId") or ""
        item = {
            "orden": paso.get("orden"),
            "procesoId": pid,
            "nombre": paso.get("nombre") or pid,
        }
        if proceso_pendiente_ruta(pid, abiertos):
            faltan.append(item)
        else:
            hechos.append(item)
    return {
        "cerrada": bool(ruta.get("pasos")) and not faltan,
        "hechos": hechos,
        "faltan": faltan,
    }


def save_pendientes(data: dict) -> None:
    """Guarda solo abiertos: los completados/cerrados pasan a pendientes-archivo.json."""
    try:
        import kb_pendientes

        data, _ = kb_pendientes.normalizar(data)
    except Exception:  # noqa: BLE001
        pass
    data["actualizado"] = _now()
    _write_json(pendientes_path(), data)


def load_sps(proceso_id: str) -> dict:
    path = sps_json_path(proceso_id)
    if not os.path.isfile(path):
        return {"procesoId": proceso_id, "sps": []}
    data = _read_json(path, {}) or {}
    if isinstance(data, list):
        return {"procesoId": proceso_id, "sps": data}
    data.setdefault("procesoId", proceso_id)
    # Alias legacy: algunos catálogos usaron "procedimientos" en vez de "sps".
    if not data.get("sps") and isinstance(data.get("procedimientos"), list):
        data["sps"] = data.get("procedimientos") or []
    data.setdefault("sps", [])
    return data


def save_sps(proceso_id: str, data: dict) -> None:
    data["procesoId"] = proceso_id
    data["actualizado"] = _now()
    _write_json(sps_json_path(proceso_id), data)
    _reindexar()


def load_proceso(proceso_id: str) -> dict | None:
    path = proceso_json_path(proceso_id)
    if not os.path.isfile(path):
        return None
    data = _read_json(path, None)
    if not data:
        return None
    cat = load_sps(proceso_id)
    data["sps"] = cat.get("sps") or []
    data["spsNota"] = cat.get("nota") or ""
    data["spsActualizado"] = cat.get("actualizado") or ""
    return data


def save_proceso(proceso_id: str, data: dict) -> None:
    data["id"] = proceso_id
    data["actualizado"] = _now()[:10]
    to_save = {k: v for k, v in data.items() if k not in ("sps", "spsNota", "spsActualizado")}
    _write_json(proceso_json_path(proceso_id), to_save)
    _reindexar()


def load_tarea() -> dict:
    return _read_json(
        tarea_path(),
        {
            "abierta": False,
            "tipo": None,
            "pendienteId": None,
            "procesoId": None,
            "archivoSql": None,
            "notas": "",
            "creadaEn": None,
        },
    )


def save_tarea(data: dict) -> None:
    _write_json(tarea_path(), data)


def sql_files() -> list[str]:
    if not os.path.isdir(SQL_ROOT):
        return []
    return sorted(
        f
        for f in os.listdir(SQL_ROOT)
        if f.lower().endswith(".sql") and os.path.isfile(os.path.join(SQL_ROOT, f))
    )


def _stem_sql(nombre: str) -> str:
    return os.path.splitext(os.path.basename(nombre or ""))[0].strip().upper()


def completar_pendientes_por_archivo(archivo: str, motivo: str = "sql_en_carpeta") -> list[str]:
    """Cierra pendientes cuyo spNombre coincide con el .sql (sin exigir el radio)."""
    stem = _stem_sql(archivo)
    if not stem:
        return []
    data = load_pendientes()
    cerrados = []
    for item in data.get("items") or []:
        if item.get("estado") == "completado":
            continue
        sp = (item.get("spNombre") or "").strip().upper()
        if sp and sp == stem:
            item["estado"] = "completado"
            item["actualizadoEn"] = _now()
            item["cerradoPor"] = motivo
            cerrados.append(item.get("id") or sp)
    if cerrados:
        save_pendientes(data)
    return cerrados


def sync_pendientes_con_sql() -> list[str]:
    cerrados = []
    for f in sql_files():
        cerrados.extend(completar_pendientes_por_archivo(f, "sql_en_carpeta"))
    return cerrados


_COLA_FICHAR = {
    "documentacion",
    "ficha",
    "doc",
    "sp",
    "gate",
    "flujo",
    "proceso_nuevo",
    "config",
}


def _pendiente_por_fichar(item: dict) -> bool:
    estado = item.get("estado") or ""
    if estado in ("completado", "cerrado", "hecho"):
        return False
    return (item.get("tipo") or "") in _COLA_FICHAR


def resumen(canal: str = "documentar", proceso_id: str = "") -> dict:
    sync_pendientes_con_sql()
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    pid = (proceso_id or "").strip()
    if pid:
        viendo_id = idx.get("viendoId") or ""
        chat_viendo = None
        if viendo_id and os.path.isfile(_sesion_path(canal, viendo_id)):
            chat_viendo = load_sesion(canal, viendo_id)
        if chat_viendo and (chat_viendo.get("procesoId") or "") == pid:
            chat = chat_viendo
        else:
            chat = asegurar_chat_proceso(canal, pid)
            idx = _ensure_canal(canal)
    else:
        chat = load_sesion(canal, idx.get("viendoId") or idx.get("activoId"))
    pid_chat = (chat.get("procesoId") or pid or "").strip()
    activo_mod = (idx.get("activoPorProceso") or {}).get(pid_chat) if pid_chat else idx.get("activoId")
    solo = chat.get("estado") == "archivado" or chat.get("id") != (activo_mod or idx.get("activoId"))
    items = idx.get("items") or []
    if pid:
        items = [i for i in items if (i.get("procesoId") or "") == pid]
    indice = load_indice()
    pendientes = load_pendientes(incluir_archivo=True)  # la app sigue mostrando los cerrados
    abiertos = [i for i in pendientes.get("items", []) if _pendiente_por_fichar(i)]
    return {
        "ok": True,
        "indice": indice,
        "pendientes": pendientes,
        "pendientesAbiertos": len(abiertos),
        "tarea": load_tarea(),
        "canal": canal,
        "chat": chat,
        "chats": items,
        "chatActivoId": activo_mod or idx.get("activoId"),
        "chatViendoId": chat.get("id") or idx.get("viendoId") or idx.get("activoId"),
        "chatProcesoId": chat.get("procesoId") or pid,
        "chatSoloLectura": solo,
        "sqlArchivos": sql_files(),
        "ruta": CONOCIMIENTO,
        "rutaDocumentar": load_ruta(),
        "valle": siguiente_valle(),
        "vigilante": load_vigilante(),
        "rutaEstado": ruta_resumen(),
        "faqCount": len(load_faq(pid or chat.get("procesoId") or "").get("items") or []),
    }


def create_proceso(nombre: str, modulo: str = "", proceso_id: str = "") -> dict:
    pid = slug(proceso_id or nombre)
    if load_proceso(pid):
        return {"ok": False, "error": f"El proceso '{pid}' ya existe."}

    data = {
        "id": pid,
        "nombre": (nombre or pid).strip(),
        "modulo": (modulo or "").strip(),
        "estado": "esqueleto",
        "resumen": "",
        "notaSql": "No se archivan cuerpos de SP. Pasar el .sql vigente en Documentar.",
        "capas": copy.deepcopy(CAPAS_ESQUELETO),
    }
    os.makedirs(proceso_dir(pid), exist_ok=True)
    save_proceso(pid, data)
    _write_json(
        sps_json_path(pid),
        {
            "procesoId": pid,
            "actualizado": "",
            "nota": "Catálogo SP → METODO. Se llena al leer el .sql de hoy. No copiar el cuerpo.",
            "sps": [],
        },
    )

    md = os.path.join(proceso_dir(pid), "PROCESO.md")
    if not os.path.isfile(md):
        with open(md, "w", encoding="utf-8") as fh:
            fh.write(
                f"# Proceso: {data['nombre']}\n\n"
                f"**Estado:** esqueleto  \n**Módulo:** {data['modulo'] or '—'}\n\n"
                "> Solo flujo y explicación. El cuerpo de los SP se lee de DESAIX o de la copia local sql/ (fuera de git); aquí solo nombre, métodos y validaciones (SP:línea).\n\n"
                "## Capas\n\n1. Configuración\n2. Proceso propio\n"
                "3. Lo que llega y completa\n4. Subproceso unido\n5. Envío a contabilidad\n"
            )

    indice = load_indice()
    if not any(p.get("id") == pid for p in indice.get("procesos", [])):
        indice.setdefault("procesos", []).append(
            {
                "id": pid,
                "nombre": data["nombre"],
                "modulo": data["modulo"],
                "estado": "esqueleto",
                "resumen": "Proceso nuevo — completar en Documentar / valles.",
                "carpeta": pid,
            }
        )
        save_indice(indice)

    add_pendiente(
        {
            "tipo": "proceso_nuevo",
            "procesoId": pid,
            "capaId": "",
            "controlId": "",
            "titulo": f"{data['nombre']} · proceso nuevo (5 capas vacías)",
            "detalle": "Completar explicación de cada capa y señalar los SP vigentes (nombre y métodos).",
            "spNombre": "",
            "origen": "app",
        }
    )
    append_chat(
        "agente",
        f"Se creó el esqueleto del proceso **{data['nombre']}** (`{pid}`). "
        "Quedó en pendientes para completar en un valle. No se inventó flujo ni SP.",
        pid,
    )
    return {"ok": True, "proceso": load_proceso(pid), "id": pid}


def add_pendiente(item: dict) -> dict:
    data = load_pendientes()
    pid_fijo = (item.get("id") or "").strip()
    if pid_fijo:
        for existente in data.get("items") or []:
            if existente.get("id") == pid_fijo:
                return existente
    nuevo = {
        "id": item.get("id") or f"{item.get('procesoId') or 'proc'}-{str(uuid.uuid4())[:8]}",
        "tipo": item.get("tipo") or "sp",
        "procesoId": item.get("procesoId") or "",
        "capaId": item.get("capaId") or "",
        "controlId": item.get("controlId") or item.get("gateId") or "",
        "gateId": item.get("controlId") or item.get("gateId") or "",
        "titulo": (item.get("titulo") or "").strip() or "Pendiente",
        "detalle": (item.get("detalle") or "").strip(),
        "spNombre": (item.get("spNombre") or "").strip(),
        "estado": "pendiente",
        "creadoEn": _now(),
        "origen": item.get("origen") or "agente",
    }
    data.setdefault("items", []).append(nuevo)
    save_pendientes(data)
    return nuevo


def set_pendiente_estado(pendiente_id: str, estado: str) -> dict:
    data = load_pendientes()
    found = None
    for item in data.get("items", []):
        if item.get("id") == pendiente_id:
            item["estado"] = estado
            item["actualizadoEn"] = _now()
            found = item
            break
    if not found:
        import kb_pendientes

        found = kb_pendientes.reabrir_desde_archivo(pendiente_id)
        if not found:
            return {"ok": False, "error": "Pendiente no encontrado"}
        if estado in kb_pendientes.CERRADOS:
            # Ya estaba cerrado: se devuelve tal cual al archivo.
            found["estado"] = estado
            found["actualizadoEn"] = _now()
            data["items"].append(found)
            save_pendientes(data)
            return {"ok": True, "item": found}
        found["estado"] = estado
        found["actualizadoEn"] = _now()
        data["items"].append(found)
    save_pendientes(data)
    return {"ok": True, "item": found}


def infer_proceso_id(archivo: str) -> str:
    stem = os.path.splitext(os.path.basename(archivo or ""))[0].upper()
    if not stem:
        return ""
    indice = load_indice()
    for p in indice.get("procesos") or []:
        pid = p.get("id") or ""
        if not pid:
            continue
        cat = load_sps(pid)
        for sp in cat.get("sps") or []:
            if (sp.get("nombre") or "").upper() == stem:
                return pid
        modulo = (p.get("modulo") or "").upper()
        if modulo and modulo in stem:
            return pid
    if "CAJA" in stem or stem.startswith("SPK_APERTURA") or "CAJ" in stem:
        return "caja"
    return ""


def cerrar_tarea() -> dict:
    tarea = load_tarea()
    tarea["abierta"] = False
    tarea["cerradaEn"] = _now()
    save_tarea(tarea)
    return tarea


def buscar_sql_local(archivo: str) -> str:
    """Ruta de la copia local del SP (sql/ y luego sql_refe/**), o "" si no hay.

    Las copias son locales y no se suben al repositorio; su ausencia no es error.
    """
    nombre = os.path.basename(archivo or "").lower()
    if not nombre:
        return ""
    directo = os.path.join(SQL_ROOT, os.path.basename(archivo))
    if os.path.isfile(directo):
        return directo
    for raiz in (SQL_ROOT, SQL_REFE_ROOT):
        if not os.path.isdir(raiz):
            continue
        for base, _dirs, files in os.walk(raiz):
            for f in files:
                if f.lower() == nombre:
                    return os.path.join(base, f)
    return ""


def documentar_sp(pendiente_id: str, archivo_sql: str, notas: str = "", proceso_id: str = "") -> dict:
    archivo = os.path.basename((archivo_sql or "").strip())
    if archivo and not archivo.lower().endswith(".sql"):
        archivo += ".sql"
    if not archivo:
        return {"ok": False, "error": "Indique el SP a documentar (nombre o archivo .sql)."}

    path = buscar_sql_local(archivo)
    if path:
        origen_sql = f"copia local {os.path.relpath(path, ROOT).replace(os.sep, '/')} (fuera de git)"
    else:
        origen_sql = "sin copia local: leer el cuerpo de hoy en DESAIX (SQLIX, PREVERSION primero)"

    pendientes = load_pendientes()
    item = next((i for i in pendientes.get("items", []) if i.get("id") == pendiente_id), None)
    pid = (
        (proceso_id or "").strip()
        or (item or {}).get("procesoId")
        or infer_proceso_id(archivo)
        or ""
    )

    prev = load_tarea()
    reemplazo = bool(prev.get("abierta") and prev.get("archivoSql") and prev.get("archivoSql") != archivo)

    tarea = {
        "abierta": True,
        "tipo": "documentar_sp",
        "pendienteId": pendiente_id or None,
        "procesoId": pid or None,
        "archivoSql": archivo,
        "notas": (notas or "").strip(),
        "creadaEn": _now(),
        "reemplazo": reemplazo,
        "archivoAnterior": prev.get("archivoSql") if reemplazo else None,
    }
    save_tarea(tarea)

    completar_pendientes_por_archivo(archivo, "documentar_sp")
    if item:
        set_pendiente_estado(pendiente_id, "completado")

    extra = ""
    if reemplazo:
        extra = f"Sustituye la tarea anterior ({prev.get('archivoSql')}).\n"
    texto = (
        f"{extra}"
        f"Documentar SP **{archivo[:-4]}** ({origen_sql}).\n"
        f"Pendiente: {item.get('titulo') if item else pendiente_id or '— (sin pendiente; SP suelto)'}.\n"
        f"Proceso: {pid or '—'}.\n"
        f"{('Nota: ' + notas) if notas else ''}\n\n"
        "Leer el script de hoy. En conocimiento/{proceso}/sps.json documentar por METODO:\n"
        "  SP → METODO: hace (una frase), valida (lista), noValida (huecos), "
        "errores (textos KO), llama (SPK/SPQ anidados), efecto en el proceso, estado=leido.\n"
        "Evidencia como SP:línea (p. ej. SPK_X:120), nunca una ruta sql/…; no subir .sql al repositorio. "
        "No copiar el cuerpo. Si el METODO no está en este SPQ, anotarlo en la cola (ELSE). "
        "Anidados faltantes → filas en pendientes. Actualizar el control en proceso.json solo si cambia el flujo."
        .replace("{proceso}", pid or "ID")
    )
    append_chat("coordinador", texto, pid)
    return {"ok": True, "tarea": tarea, "chat": load_chat(), "reemplazo": reemplazo}
