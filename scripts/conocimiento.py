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
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _write_json(path: str, data) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def indice_path() -> str:
    return os.path.join(CONOCIMIENTO, "INDICE.json")


def pendientes_path() -> str:
    return os.path.join(CONOCIMIENTO, "pendientes.json")


def chat_path() -> str:
    return os.path.join(CONOCIMIENTO, "chat.json")


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


def load_chat() -> dict:
    data = _read_json(chat_path(), {"procesoId": "", "mensajes": []})
    if "mensajes" not in data:
        data["mensajes"] = []
    return data


def append_chat(autor: str, texto: str, proceso_id: str = "") -> dict:
    chat = load_chat()
    if proceso_id:
        chat["procesoId"] = proceso_id
    msg = {
        "id": str(uuid.uuid4())[:8],
        "autor": autor,
        "texto": (texto or "").strip(),
        "en": _now(),
    }
    chat.setdefault("mensajes", []).append(msg)
    _write_json(chat_path(), chat)
    return chat


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


def resumen() -> dict:
    sync_pendientes_con_sql()
    indice = load_indice()
    pendientes = load_pendientes()
    abiertos = [i for i in pendientes.get("items", []) if i.get("estado") != "completado"]
    return {
        "ok": True,
        "indice": indice,
        "pendientes": pendientes,
        "pendientesAbiertos": len(abiertos),
        "tarea": load_tarea(),
        "chat": load_chat(),
        "sqlArchivos": sql_files(),
        "ruta": CONOCIMIENTO,
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
