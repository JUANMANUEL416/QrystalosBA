#!/usr/bin/env python3
"""Base de conocimiento de procesos (flujos + explicación; no cuerpos de SP)."""
from __future__ import annotations

import json
import os
import re
import uuid
import copy
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
SQL_ROOT = os.path.join(ROOT, "sql")

CAPAS_ESQUELETO = [
    {
        "id": "01-configuracion",
        "numero": 1,
        "nombre": "Configuración",
        "estado": "pendiente",
        "explicacion": "Qué debe estar parametrizado antes de operar.",
        "tablasClave": [],
        "gates": [],
    },
    {
        "id": "02-operacion",
        "numero": 2,
        "nombre": "Proceso propio",
        "estado": "pendiente",
        "explicacion": "Acciones del usuario y gates (abrir, confirmar, etc.).",
        "tablasClave": [],
        "gates": [],
    },
    {
        "id": "03-alimentadores",
        "numero": 3,
        "nombre": "Lo que llega y completa",
        "estado": "pendiente",
        "explicacion": "Orígenes externos que alimentan este proceso.",
        "tablasClave": [],
        "gates": [],
    },
    {
        "id": "04-bancos",
        "numero": 4,
        "nombre": "Subproceso unido (p. ej. bancos)",
        "estado": "pendiente",
        "explicacion": "Solo el encuentro con este proceso, no el módulo entero.",
        "tablasClave": [],
        "gates": [],
    },
    {
        "id": "05-contabilidad",
        "numero": 5,
        "nombre": "Envío a contabilidad",
        "estado": "pendiente",
        "explicacion": "Qué se entrega al asiento y qué se asume ya validado.",
        "tablasClave": [],
        "gates": [],
    },
]


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
    tmp = f"{path}.{os.getpid()}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        os.replace(tmp, path)
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


def bot_id(canal: str) -> str:
    return BOT_IDS.get(_norm_canal(canal), BOT_IDS["documentar"])


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


def _titulo_default(canal: str) -> str:
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    nombre = "Consulta" if canal == "consultas" else "Documentar"
    return f"{nombre} · {stamp}"


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
    if idx.get("activoId") and os.path.isfile(_sesion_path(canal, idx["activoId"])):
        return idx

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
        "items": [
            {
                "id": sid,
                "titulo": titulo,
                "estado": "activo",
                "creadoEn": chat["creadoEn"],
                "archivadoEn": None,
                "mensajes": len(msgs),
            }
        ],
    }
    _write_json(_index_path(canal), idx)
    _sync_live(canal, chat)
    return idx


def load_chat_legacy() -> dict:
    data = _read_json(chat_path(), {"procesoId": "", "mensajes": []})
    if "mensajes" not in data:
        data["mensajes"] = []
    return data


def _save_index(canal: str, idx: dict) -> None:
    _write_json(_index_path(canal), idx)


def load_sesion(canal: str, sid: str | None = None) -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    sid = sid or idx.get("viendoId") or idx.get("activoId")
    data = _read_json(_sesion_path(canal, sid), None)
    if not data:
        data = _empty_chat(canal, sid or "vacio", _titulo_default(canal))
    data.setdefault("mensajes", [])
    if sid and sid == idx.get("activoId"):
        live = _read_json(os.path.join(canal_live_dir(canal), "chat.json"), None)
        if live and isinstance(live.get("mensajes"), list):
            live_msgs = live.get("mensajes") or []
            if live_msgs != (data.get("mensajes") or []):
                data["mensajes"] = live_msgs
                if live.get("procesoId"):
                    data["procesoId"] = live.get("procesoId")
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
                "creadoEn": chat.get("creadoEn"),
                "archivadoEn": chat.get("archivadoEn"),
                "mensajes": len(chat.get("mensajes") or []),
            },
        )


def append_chat(autor: str, texto: str, proceso_id: str = "", canal: str = "documentar") -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    activo = idx.get("activoId")
    chat = load_sesion(canal, activo)
    if proceso_id:
        chat["procesoId"] = proceso_id
    chat.setdefault("mensajes", []).append(
        {
            "id": str(uuid.uuid4())[:8],
            "autor": autor,
            "texto": (texto or "").strip(),
            "en": _now(),
        }
    )
    _write_json(_sesion_path(canal, chat["id"]), chat)
    _touch_item(idx, chat)
    idx["viendoId"] = chat["id"]
    _save_index(canal, idx)
    _sync_live(canal, chat)
    return chat


def archivar_chat(canal: str, titulo: str = "") -> dict:
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    actual = load_sesion(canal, idx.get("activoId"))
    if titulo.strip():
        actual["titulo"] = titulo.strip()
    actual["estado"] = "archivado"
    actual["archivadoEn"] = _now()
    _write_json(_sesion_path(canal, actual["id"]), actual)
    _touch_item(idx, actual)
    sid = _nuevo_sid(canal)
    nuevo = _empty_chat(canal, sid, _titulo_default(canal), actual.get("procesoId") or "")
    _write_json(_sesion_path(canal, sid), nuevo)
    _touch_item(idx, nuevo)
    idx["activoId"] = sid
    idx["viendoId"] = sid
    _save_index(canal, idx)
    _sync_live(canal, nuevo)
    return {"ok": True, "archivado": actual, "activo": nuevo, "chats": idx["items"]}


def nuevo_chat(canal: str, titulo: str = "") -> dict:
    return archivar_chat(canal, titulo)


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


def load_pendientes() -> dict:
    data = _read_json(pendientes_path(), {"actualizado": "", "items": []})
    if "items" not in data:
        data["items"] = []
    return data


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
    data.setdefault("activo", True)
    data.setdefault("intervaloMin", 12)
    data.setdefault("ultimoTurnoEn", None)
    data.setdefault("ultimoProcesoId", None)
    data.setdefault("ultimoError", "")
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


def resumen(canal: str = "documentar") -> dict:
    sync_pendientes_con_sql()
    canal = _norm_canal(canal)
    idx = _ensure_canal(canal)
    chat = load_sesion(canal, idx.get("viendoId") or idx.get("activoId"))
    solo = chat.get("id") != idx.get("activoId") or chat.get("estado") == "archivado"
    indice = load_indice()
    pendientes = load_pendientes()
    abiertos = [i for i in pendientes.get("items", []) if i.get("estado") != "completado"]
    return {
        "ok": True,
        "indice": indice,
        "pendientes": pendientes,
        "pendientesAbiertos": len(abiertos),
        "tarea": load_tarea(),
        "canal": canal,
        "chat": chat,
        "chats": idx.get("items") or [],
        "chatActivoId": idx.get("activoId"),
        "chatViendoId": idx.get("viendoId") or idx.get("activoId"),
        "chatSoloLectura": solo,
        "sqlArchivos": sql_files(),
        "ruta": CONOCIMIENTO,
        "rutaDocumentar": load_ruta(),
        "valle": siguiente_valle(),
        "vigilante": load_vigilante(),
        "rutaEstado": ruta_resumen(),
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
                "> Solo flujo y explicación. Los SP se bajan a sql/ el día que se analicen.\n\n"
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
            "gateId": "",
            "titulo": f"{data['nombre']} · proceso nuevo (5 capas vacías)",
            "detalle": "Completar explicación de cada capa y señalar los SP vigentes en sql/.",
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
        "gateId": item.get("gateId") or "",
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
        return {"ok": False, "error": "Pendiente no encontrado"}
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


def documentar_sp(pendiente_id: str, archivo_sql: str, notas: str = "", proceso_id: str = "") -> dict:
    archivo = os.path.basename((archivo_sql or "").strip())
    if not archivo.lower().endswith(".sql"):
        return {"ok": False, "error": "Indique un archivo .sql (el vigente en sql/)."}

    path = os.path.join(SQL_ROOT, archivo)
    if not os.path.isfile(path):
        return {
            "ok": False,
            "error": f"No está {archivo} en sql/. Baje el SP de hoy a esa carpeta y reintente.",
        }

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
        f"Documentar SP **{archivo}** (vigente en sql/).\n"
        f"Pendiente: {item.get('titulo') if item else pendiente_id or '— (sin pendiente; SP suelto)'}.\n"
        f"Proceso: {pid or '—'}.\n"
        f"{('Nota: ' + notas) if notas else ''}\n\n"
        "Leer el script de hoy. En conocimiento/{proceso}/sps.json documentar por METODO:\n"
        "  SP → METODO: hace (una frase), valida (lista), noValida (huecos), "
        "errores (textos KO), llama (SPK/SPQ anidados), efecto en el proceso, estado=leido.\n"
        "No copiar el cuerpo. Si el METODO no está en este SPQ, anotarlo en la cola (ELSE). "
        "Anidados faltantes → filas en pendientes. Actualizar el gate en proceso.json solo si cambia el flujo."
        .replace("{proceso}", pid or "ID")
    )
    append_chat("coordinador", texto, pid)
    return {"ok": True, "tarea": tarea, "chat": load_chat(), "reemplazo": reemplazo}
