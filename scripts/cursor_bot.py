#!/usr/bin/env python3
"""Bot de oficina: lanza un agente Cursor local y responde en chat.json."""
from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import time
import traceback
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import sin_consola  # noqa: E402

sin_consola.instalar()

from qrystalos_ba_db import get_db  # noqa: E402

ACTIVO = os.path.join(ROOT, "activo")
SOLICITUDES = os.path.join(ROOT, "solicitudes")
REVISIONES = os.path.join(ROOT, "revisiones")
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
ENV_PATH = os.path.join(ROOT, ".env")
# Si CURSOR_BOT_MODEL está en el entorno, pisa el reparto de config/orquesta.json.
MODELO = os.environ.get("CURSOR_BOT_MODEL", "composer-2.5")
HERRAMIENTAS_KB = ("read", "edit", "grep", "glob", "ls")
HERRAMIENTAS_NO = ("shell", "task", "mcp", "webSearch")
CONOCIMIENTO_ID = "__conocimiento__"
CONSULTAS_ID = "__consultas__"
DOCUMENTAR_ID = "__documentar__"
CONOCIMIENTO_IDS = {CONOCIMIENTO_ID, CONSULTAS_ID, DOCUMENTAR_ID}
MOTIVOS_KB = frozenset({"conocimiento", "consultas", "documentar", "documentar-auto"})
TIMEOUT_KB_SEC = 12 * 60
# Turnos que Conocimiento/Consultas reutilizan su sesión antes de abrir una nueva (0 = sesión nueva cada turno).
KB_TURNOS_SESION = int(os.environ.get("CURSOR_BOT_KB_TURNOS", "6") or 6)
TIMEOUT_CASO_SEC = 45 * 60


def _env_bool(name: str, default: bool = False) -> bool:
    raw = (os.environ.get(name) or "").strip().lower()
    if not raw:
        return default
    return raw in ("1", "true", "yes", "si", "on")


FAST_CASOS = _env_bool("CURSOR_BOT_FAST", True)


def _modelo_forzado() -> str:
    env = _parse_env(ENV_PATH)
    return (os.environ.get("CURSOR_BOT_MODEL") or env.get("CURSOR_BOT_MODEL") or "").strip()


def modelo_id(motivo: str = "") -> str:
    env = _parse_env(ENV_PATH)
    if motivo in MOTIVOS_KB:
        kb = (os.environ.get("CURSOR_BOT_MODEL_KB") or env.get("CURSOR_BOT_MODEL_KB") or "").strip()
        if kb:
            return kb
    forzado = _modelo_forzado()
    if forzado:
        return forzado
    try:
        import orquesta

        return orquesta.modelo_de(motivo)
    except Exception:
        return MODELO.strip() or "composer-2.5"


def usa_fast(motivo: str = "") -> bool:
    env = _parse_env(ENV_PATH)
    raw = (os.environ.get("CURSOR_BOT_FAST") or env.get("CURSOR_BOT_FAST") or "").strip().lower()
    if raw:
        return raw in ("1", "true", "yes", "si", "on")
    if _modelo_forzado():
        return FAST_CASOS
    try:
        import orquesta

        return orquesta.usa_fast(motivo)
    except Exception:
        return FAST_CASOS


def modelo_selection(motivo: str = ""):
    from cursor_sdk import ModelParameterValue, ModelSelection

    especificos = None
    if not _modelo_forzado():
        try:
            import orquesta

            especificos = orquesta.params_de(motivo)
        except Exception:
            especificos = None
    if especificos is None:
        params = [ModelParameterValue(id="fast", value="true" if usa_fast(motivo) else "false")]
    else:
        params = [ModelParameterValue(id=item["id"], value=item["value"]) for item in especificos]
    return ModelSelection(id=modelo_id(motivo), params=params)


def modelo_report() -> dict:
    return {
        "modelo": modelo_id("chat"),
        "modeloAnalisis": modelo_id("analizar-req"),
        "modeloKb": modelo_id("consultas"),
        "fast": usa_fast("chat"),
        "fastKb": usa_fast("consultas"),
    }


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _parse_env(path: str) -> dict:
    values = {}
    if not os.path.isfile(path):
        return values
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def _es_nombre_clave(nombre: str) -> bool:
    if nombre in ("CURSOR_API_KEY", "CURSOR_API_KEY_FALLBACK"):
        return True
    if not nombre.startswith("CURSOR_API_KEY_"):
        return False
    resto = nombre[len("CURSOR_API_KEY_") :]
    return resto.isdigit()


def _nombres_clave(env: dict) -> list[str]:
    """Nombres de variable, en orden estable. CURSOR_API_KEY_3 y siguientes también cuentan."""
    nombres = ["CURSOR_API_KEY", "CURSOR_API_KEY_2", "CURSOR_API_KEY_FALLBACK"]
    extras = []
    for name in env:
        if _es_nombre_clave(name) and name not in nombres:
            resto = name[len("CURSOR_API_KEY_") :]
            if resto.isdigit():
                extras.append((int(resto), name))
    for _, name in sorted(extras):
        nombres.append(name)
    return nombres


ACTIVE_KEY_PATH = os.path.join(ROOT, "config", "cursor-api-key-active.json")


def _load_active_key_meta() -> dict:
    try:
        return read_json(ACTIVE_KEY_PATH, {})
    except (OSError, json.JSONDecodeError):
        return {}


def _save_active_key_meta(meta: dict) -> None:
    os.makedirs(os.path.dirname(ACTIVE_KEY_PATH), exist_ok=True)
    write_json(ACTIVE_KEY_PATH, meta)


def load_cursor_api_keys() -> list[tuple[str, str]]:
    """Lista (etiqueta, clave) en orden de preferencia. Sin duplicados."""
    env = _parse_env(ENV_PATH)
    out: list[tuple[str, str]] = []
    seen: set[str] = set()

    def _add(label: str, val: str) -> None:
        k = (val or "").strip()
        if not k or k in seen:
            return
        if not k.startswith("crsr_"):
            return
        seen.add(k)
        out.append((label, k))

    for name in _nombres_clave({**env, **os.environ}):
        _add(name, os.environ.get(name) or env.get(name) or "")

    if os.path.isfile(ENV_PATH):
        with open(ENV_PATH, encoding="utf-8") as fh:
            n = 0
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                if key.strip() != "CURSOR_API_KEY":
                    continue
                n += 1
                label = "CURSOR_API_KEY" if n == 1 else f"CURSOR_API_KEY#{n}"
                _add(label, val)

    return out


def load_api_key() -> str:
    keys = load_cursor_api_keys()
    if not keys:
        return ""
    meta = _load_active_key_meta()
    idx = meta.get("indice")
    if isinstance(idx, int) and 0 <= idx < len(keys):
        return keys[idx][1]
    return keys[0][1]


def set_active_api_key_index(indice: int, etiqueta: str = "") -> None:
    meta = _load_active_key_meta()
    meta["indice"] = indice
    meta["etiqueta"] = etiqueta or meta.get("etiqueta") or ""
    meta["validadoEn"] = _now()
    _save_active_key_meta(meta)


def cursor_key_status() -> dict:
    pairs = load_cursor_api_keys()
    meta = _load_active_key_meta()
    idx = meta.get("indice")
    etiqueta = meta.get("etiqueta") or ""
    if not etiqueta and isinstance(idx, int) and 0 <= idx < len(pairs):
        etiqueta = pairs[idx][0]
    return {
        "configurado": bool(pairs),
        "cantidadClaves": len(pairs),
        "etiquetaActiva": etiqueta,
        "validadoEn": meta.get("validadoEn"),
    }


def listar_claves_publicas() -> list[dict]:
    """Etiqueta y últimos 4 caracteres. Nunca el secreto."""
    pairs = load_cursor_api_keys()
    meta = _load_active_key_meta()
    idx = meta.get("indice") if isinstance(meta.get("indice"), int) else 0
    salida = []
    for i, (etiqueta, valor) in enumerate(pairs):
        salida.append({
            "etiqueta": etiqueta,
            "sufijo": valor[-4:] if len(valor) >= 4 else "",
            "activa": i == idx,
        })
    return salida


def clave_por_etiqueta(etiqueta: str) -> str:
    buscada = (etiqueta or "").strip()
    if not buscada:
        return ""
    for label, key in load_cursor_api_keys():
        if label == buscada:
            return key
    return ""


def _validar_clave_cursor(valor: str) -> str:
    clave = (valor or "").strip().strip('"').strip("'")
    if any(c.isspace() for c in clave) or "\n" in clave or "\r" in clave:
        raise ValueError("La clave no puede llevar espacios.")
    if not clave.startswith("crsr_") or len(clave) < 20:
        raise ValueError("La clave de Cursor empieza por crsr_.")
    return clave


def _leer_env_lineas(path: str) -> tuple[list[str], str]:
    if not os.path.isfile(path):
        return [], "\n"
    with open(path, encoding="utf-8") as fh:
        texto = fh.read()
    sep = "\r\n" if "\r\n" in texto else "\n"
    return texto.splitlines(), sep


def _escribir_env_lineas(path: str, lineas: list[str], sep: str) -> None:
    texto = sep.join(lineas)
    if texto and not texto.endswith(sep):
        texto += sep
    carpeta = os.path.dirname(path) or "."
    os.makedirs(carpeta, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as fh:
        fh.write(texto)
    os.replace(tmp, path)


def _linea_de_etiqueta(lineas: list[str], etiqueta: str) -> int:
    nombre = etiqueta
    n = 1
    if "#" in etiqueta:
        nombre, _, num = etiqueta.partition("#")
        n = int(num) if num.isdigit() else 1
    vistos = 0
    for i, raw in enumerate(lineas):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, _val = line.partition("=")
        if key.strip() == nombre:
            vistos += 1
            if vistos == n:
                return i
    return -1


def _siguiente_nombre_clave(lineas: list[str]) -> str:
    usados = set()
    for raw in lineas:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, _val = line.partition("=")
        nombre = key.strip()
        if _es_nombre_clave(nombre):
            usados.add(nombre)
    if "CURSOR_API_KEY" not in usados:
        return "CURSOR_API_KEY"
    n = 2
    while f"CURSOR_API_KEY_{n}" in usados:
        n += 1
    return f"CURSOR_API_KEY_{n}"


def agregar_clave_cursor(valor: str, path: str | None = None) -> str:
    """Añade la clave al .env con un nombre nuevo. Devuelve la etiqueta, no el secreto."""
    clave = _validar_clave_cursor(valor)
    for _label, previa in load_cursor_api_keys():
        if previa == clave:
            raise ValueError("Esa clave ya está cargada.")
    ruta = path or ENV_PATH
    lineas, sep = _leer_env_lineas(ruta)
    nombre = _siguiente_nombre_clave(lineas)
    lineas.append(f"{nombre}={clave}")
    _escribir_env_lineas(ruta, lineas, sep)
    return nombre


def cambiar_clave_cursor(etiqueta: str, valor: str, path: str | None = None) -> str:
    """Reemplaza el valor de una clave ya cargada. La etiqueta no cambia."""
    buscada = (etiqueta or "").strip()
    if not buscada:
        raise ValueError("Elija qué clave cambiar.")
    if not clave_por_etiqueta(buscada) and path is None:
        raise ValueError("Esa clave no está cargada.")
    clave = _validar_clave_cursor(valor)
    for label, previa in load_cursor_api_keys():
        if previa == clave and label != buscada:
            raise ValueError("Esa clave ya está cargada con otro nombre.")
    ruta = path or ENV_PATH
    lineas, sep = _leer_env_lineas(ruta)
    idx = _linea_de_etiqueta(lineas, buscada)
    if idx < 0:
        raise ValueError("Esa clave no está en .env. No se puede cambiar desde el panel.")
    nombre = buscada.partition("#")[0]
    lineas[idx] = f"{nombre}={clave}"
    _escribir_env_lineas(ruta, lineas, sep)
    return buscada


KB_SEP = "~"


def kb_base(id_caso: str) -> str:
    """'__consultas__~c2026…' → '__consultas__' (un bot por chat)."""
    return str(id_caso or "").split(KB_SEP, 1)[0]


def kb_sid(id_caso: str) -> str:
    partes = str(id_caso or "").split(KB_SEP, 1)
    return partes[1] if len(partes) == 2 and partes[0] in CONOCIMIENTO_IDS else ""


def canal_de(id_caso: str, motivo: str = "") -> str:
    id_caso = kb_base(id_caso)
    if id_caso == CONSULTAS_ID or motivo == "consultas":
        return "consultas"
    if id_caso == DOCUMENTAR_ID or motivo in ("documentar", "documentar-auto"):
        return "documentar"
    return "documentar"


def es_conocimiento(id_caso: str, motivo: str = "") -> bool:
    return motivo in ("conocimiento", "consultas", "documentar", "documentar-auto") or kb_base(id_caso) in CONOCIMIENTO_IDS


def es_solicitar(id_caso: str, motivo: str = "") -> bool:
    return motivo == "solicitar-req" or str(id_caso or "").startswith("SR")


def es_revisar(id_caso: str, motivo: str = "") -> bool:
    return motivo in ("revisar-sql", "revisar-sql-chat") or str(id_caso or "").startswith("SQLR-")


def es_soporte_consulta(id_caso: str, motivo: str = "") -> bool:
    return motivo in ("soporte-consulta-analisis", "soporte-consulta-chat") or str(id_caso or "").startswith(
        "sc"
    )


def es_prueba_req(id_caso: str, motivo: str = "") -> bool:
    return motivo in ("prueba-req", "prueba-req-chat") or str(id_caso or "").startswith("pr20")


def _carpeta_caso(id_caso: str) -> str:
    return os.path.relpath(caso_dir(id_caso), ROOT).replace("\\", "/")


def caso_dir(id_caso: str) -> str:
    if es_revisar(id_caso):
        return os.path.join(REVISIONES, id_caso)
    if es_prueba_req(id_caso):
        return os.path.join(ROOT, "data", "pruebas-req", id_caso)
    if es_soporte_consulta(id_caso):
        return os.path.join(ROOT, "data", "soporte-consultas", id_caso)
    if kb_base(id_caso) in CONOCIMIENTO_IDS:
        import conocimiento as kb

        canal = canal_de(id_caso)
        kb._ensure_canal(canal)
        sid = kb_sid(id_caso)
        if sid:
            return kb.sesion_run_dir(canal, sid)
        return kb.canal_live_dir(canal)
    if es_solicitar(id_caso):
        return os.path.join(SOLICITUDES, id_caso)
    return os.path.join(ACTIVO, id_caso)


def bot_path(id_caso: str) -> str:
    return os.path.join(caso_dir(id_caso), "bot.json")


def agente_path(id_caso: str) -> str:
    return os.path.join(caso_dir(id_caso), "agente.json")


def write_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


def read_json(path: str, default=None):
    if default is None:
        default = {}
    if not os.path.isfile(path):
        return default
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return default


def write_bot(id_caso: str, **fields) -> dict:
    data = read_json(bot_path(id_caso), {})
    data.update(fields)
    data["actualizadoEn"] = _now()
    write_json(bot_path(id_caso), data)
    return data


def append_chat(id_caso: str, autor: str, texto: str) -> None:
    if es_revisar(id_caso):
        import sql_revisar

        sql_revisar.append_chat(id_caso, autor, texto)
        return
    if es_conocimiento(id_caso):
        import conocimiento as kb

        canal = canal_de(id_caso)
        sid = kb_sid(id_caso)
        if sid:
            kb.append_chat_sesion(canal, sid, autor, texto)
            return
        proceso = ""
        try:
            proceso = (kb.load_chat(canal) or {}).get("procesoId") or ""
        except (OSError, json.JSONDecodeError):
            proceso = ""
        kb.append_chat(autor, texto, proceso, canal)
        return
    if es_solicitar(id_caso):
        import solicitud_req as sr

        sr.append_chat(id_caso, autor, texto)
        return
    if es_prueba_req(id_caso):
        import prueba_req as pr

        pr.append_chat(id_caso, autor if autor != "sistema" else "sistema", texto)
        return
    if es_soporte_consulta(id_caso):
        import soporte_consultas as sc

        if autor == "sistema":
            sc.append_chat(id_caso, "soporte", f"[sistema] {texto}")
        else:
            sc.append_chat(id_caso, autor, texto)
        return
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto,
        "fecha": _now(),
    }
    db = get_db()
    db.append_chat(id_caso, msg)


def ultimo_autor(id_caso: str) -> str:
    chat = read_json(os.path.join(caso_dir(id_caso), "chat.json"), {"mensajes": []})
    for msg in reversed(chat.get("mensajes") or []):
        if msg.get("autor") != "sistema":
            return str(msg.get("autor") or "")
    return ""


def _texto_acotado(texto: str, max_chars: int) -> str:
    t = (texto or "").strip()
    if len(t) <= max_chars:
        return t
    return t[: max_chars - 20].rstrip() + "\n…[recorte]"


def _msg_util(msg: dict) -> bool:
    autor = msg.get("autor") or ""
    if autor == "sistema":
        return False
    return autor in ("coordinador", "agente")


def recorte_faq_kb(proceso_id: str, pregunta: str) -> str:
    import conocimiento as kb

    return kb.recorte_faq(proceso_id, pregunta)


def recorte_chat_kb(id_caso: str) -> str:
    """Último pedido del coordinador + eco corto del agente. No el chat entero."""
    chat = read_json(os.path.join(caso_dir(id_caso), "chat.json"), {"mensajes": []})
    utiles = [m for m in (chat.get("mensajes") or []) if _msg_util(m)]
    coord = next((m for m in reversed(utiles) if m.get("autor") == "coordinador"), None)
    agente = next((m for m in reversed(utiles) if m.get("autor") == "agente"), None)
    partes = []
    pid = (chat.get("procesoId") or "").strip()
    if pid:
        partes.append(f"procesoId del chat: {pid}")
    faq = recorte_faq_kb(pid, str((coord or {}).get("texto") or ""))
    if faq:
        partes.append(faq)
    if coord:
        partes.append(
            "Último mensaje del coordinador:\n"
            + _texto_acotado(str(coord.get("texto") or ""), 6000)
        )
    if agente:
        partes.append(
            "Última respuesta suya (solo contexto; no la repita):\n"
            + _texto_acotado(str(agente.get("texto") or ""), 800)
        )
    return "\n\n".join(partes) if partes else "(sin mensaje del coordinador)"


def recorte_tarea_kb() -> str:
    import conocimiento as kb

    t = kb.load_tarea() or {}
    if not t.get("abierta"):
        return "Tarea: ninguna abierta."
    return (
        "Tarea ABIERTA:\n"
        f"- tipo: {t.get('tipo')}\n"
        f"- procesoId: {t.get('procesoId') or '—'}\n"
        f"- archivoSql: {t.get('archivoSql') or '—'}\n"
        f"- notas: {_texto_acotado(str(t.get('notas') or ''), 400)}"
    )


def _plan_subagentes(id_caso: str) -> str:
    path = os.path.join(caso_dir(id_caso), "notas-subagentes.md")
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, encoding="utf-8") as fh:
            texto = fh.read().strip()
    except OSError:
        return ""
    if not texto:
        return ""
    return (
        "\n\nPLAN DE SUBAGENTES (obligatorio):\n"
        + texto
        + "\nHaga únicamente los pasos marcados en Cursor. "
        "No rehaga un paso marcado en local ni reescriba campos que ese paso ya dejó.\n"
    )


BUSQUEDA_KB = (
    "BÚSQUEDA EN LA BASE (obligatorio, antes que cualquier otra fuente):\n"
    "1. grep en conocimiento/_indice_busqueda.json por la clave exacta entre comillas: \"SP/METODO\", \"SP\", \"TABLA\", \"/ruta/pantalla\", \"proceso/control\" o un término. "
    "Cada línea trae {proceso, archivo, ruta, linea, estado, canonico}.\n"
    "2. Abra SOLO ese archivo desde la línea indicada (read con offset≈linea, limit≈40). NUNCA lea un sps.json entero ni todos los procesos.\n"
    "3. Si hay varias referencias, use la canonico=true (conocimiento/_sp_canonico.json).\n"
    "4. Ficha con estado distinto de leido o inexistente = HUECO → handoff a Conocimiento en conocimiento/handoffs/cola.json (contrato conocimiento/HANDOFF.md)."
)


def rol_de(id_caso: str, motivo: str) -> str:
    if es_conocimiento(id_caso, motivo):
        return "consultas" if canal_de(id_caso, motivo) == "consultas" else "conocimiento"
    if es_prueba_req(id_caso, motivo):
        return "prueba-req"
    if es_soporte_consulta(id_caso, motivo):
        return "consultas"
    if es_revisar(id_caso, motivo):
        return "revisar-sql"
    return "requerimientos"


def _bloque_handoffs(id_caso: str, motivo: str) -> str:
    rol = rol_de(id_caso, motivo)
    if rol == "revisar-sql":
        return ""
    try:
        import kb_handoff

        txt = kb_handoff.resumen_prompt(rol)
    except Exception:  # noqa: BLE001
        return ""
    return ("\n" + txt + "\n") if txt else ""


def prompt_turno(id_caso: str, motivo: str) -> str:
    return _prompt_base(id_caso, motivo)


def _prompt_base(id_caso: str, motivo: str) -> str:
    if es_conocimiento(id_caso, motivo):
        canal = canal_de(id_caso, motivo)
        sid = kb_sid(id_caso)
        ruta = (
            f"conocimiento/canales/{canal}/sesiones/{sid}/chat.json"
            if sid
            else f"conocimiento/canales/{canal}/chat.json"
        )
        recorte = recorte_chat_kb(id_caso)
        tarea = recorte_tarea_kb()
        prohibido = (
            "Este chat es SOLO del procesoId indicado (un módulo). No mezcle facturación con caja ni otros. "
            "Si el prompt trae Respuestas ACEPTADAS y cubren el pedido, conteste con esa base; no reabra sps.json ni Qrystalos2. "
            "PROHIBIDO leer: el chat.json histórico (canales/, chats/, conocimiento/chat.json), "
            "faq.json entero, pendientes.json completo, pendientes-archivo.json, RUTA.json para barrer, cualquier sps.json completo, "
            "Qrystalos2 y qrystalos.documentacion. Eso ya está destilado en conocimiento/{proceso}/. "
            "Solo abra FE/docs/.sql si la ficha de ESE proceso no cubre el pedido; dígalo en una línea."
        )
        if canal == "consultas":
            return f"""Eres el agente de Consultas de Qrystalos BA. UN turno corto y termina. Sin shell ni web.
{prohibido}

Este turno (ya pegado; NO abra el chat.json):
{recorte}

{tarea}

{BUSQUEDA_KB}
{_bloque_handoffs(id_caso, motivo)}
Si la base no alcanza: NO abra Qrystalos2 ni la documentación. Responda lo que la base sí cubre, diga «Escalado a Conocimiento (ho-…)» y agregue el handoff en conocimiento/handoffs/cola.json: de consultas, para conocimiento, tipo documentar_metodo o confirmar_hueco, contexto {{proceso, sp, metodo, pregunta literal, evidencia}}. Si ya hay uno abierto igual, súmele vecesPedido en vez de duplicar.
Responda en {ruta} autor agente, campo "en". Español. No invente columnas ni SP.
{_plan_subagentes(id_caso)}
"""
        return f"""Eres el agente de Conocimiento (Documentar) de Qrystalos BA. UN turno y termina. Sin barrido, sin shell ni web.
{prohibido}

Este turno (ya pegado; NO abra el chat.json):
{recorte}

{tarea}
{_bloque_handoffs(id_caso, motivo)}
Orden de trabajo: (1) handoffs para conocimiento de la lista de arriba, alta primero: póngalo en_progreso, documente y deje respondido + respuesta (o bloqueado + motivo) en conocimiento/handoffs/cola.json; (2) la tarea abierta; (3) si no hay nada más, el primer pendiente de conocimiento/pendientes.json (ya viene ordenado por prioridad: lea solo las primeras líneas).
{BUSQUEDA_KB}
Una ficha leido exige valida, errores y efecto (o "no aplica"); si no los tiene, déjela parcial (validador: scripts/kb_validar.py).
Si la tarea está abierta: lea sql/{{archivoSql}} de hoy y documente METODOs en conocimiento/{{procesoId}}/sps.json. proceso.json solo si cambia un control.
Si no hay tarea: haga únicamente lo que pide el coordinador, en el proceso que nombre.
Responda en {ruta} autor agente, campo "en". Español. NO implemente Qrystalos2 ni ejecute SQL.
{_plan_subagentes(id_caso)}
"""
    extra = ""
    if motivo == "contabilidad":
        extra = (
            "- Motivo de este turno: VALIDAR CONTABILIDAD. Contraste el texto del coordinador "
            "con el código y la documentación. Si no afecta, dígalo y deje estado no_aplica. "
            "Si el texto es incompleto o contradice MCUE/CON, marque observado y pida el dato que falte."
        )
    elif motivo == "analizar-req":
        extra = (
            "- Motivo: ANÁLISIS DEL REQUERIMIENTO orientado a SOLUCIÓN (no dictamen HTML).\n"
            "- Método obligatorio (en este orden):\n"
            "  1) Leer el REQ (solicitud.contenido.requerimiento + cola).\n"
            "  2) Contrastar con conocimiento/: INDICE → proceso → proceso.json + sps.json "
            "vía conocimiento/_indice_busqueda.json (solo las fichas del control; y sql_refe si hace falta la línea exacta). "
            "SOLO DESPUÉS, y únicamente para huecos de la base: SQL → DESAIX; código fuente → Qrystalos2; al final qrystalos.documentacion; "
            "cada hueco va como handoff a Conocimiento (conocimiento/handoffs/cola.json).\n"
            "  2b) PASO 0 ¿YA EXISTE?: texto del REQ ≠ captura. Inventariar TODOS los "
            "caminos del control (botones v-if, Help*, necesidadesYaCubiertas, no solo "
            "los METODOs del formulario). Clasificar: capacitación | defecto | hueco. "
            "Si ya existe, dígalo de frente; impacto No; no proponga módulo nuevo.\n"
            "  3) Determinar la solución concreta (qué cambia y dónde; o capacitación).\n"
            "  4) Escribir OBLIGATORIAMENTE en solicitud.json → contenido:\n"
            "     criteriosAceptacion, alcance, restricciones, analisis, recomendacion;\n"
            "     criteriosMeta.fuente=agente; brechaAnalisis {texto, fecha ISO, estado:\"listo\"}.\n"
            "     Si el fix toca SQL (impactoSql Sí/Parcial o cambio en SP/vista): rellene también\n"
            "     cambioPropuestoSql con fragmentos concretos (objeto, bloque, BEFORE/AFTER del\n"
            "     UPDATE/INSERT/METODO, consultas de validación). Fuente: activo/{id}/sql/, sql_refe/ o DESAIX\n"
            "     (PREVERSION). Si no hay cambio SQL, deje cambioPropuestoSql vacío.\n"
            "  5) Actualizar solicitud.sql.metodosDocumentados (y procesoId) SOLO con los "
            "SP/METODO que participan en ESTE cambio. NUNCA copie el catálogo entero de "
            "conocimiento/{proceso}/sps.json (prenómina, retiros, DIAN… si el REQ es solo "
            "impresión). Si el SP del fix no está en sps.json, deje metodosDocumentados "
            "vacío o solo los que sí aplican, pida el .sql y anote en brechaAnalisis.sps. "
            "Tabla en el Chat: SP · METODO · estado · rol en el fix.\n"
            "- Responda en chat.json (autor: agente) con el mismo resumen: problema → causa "
            "(según KB) → solución → CA/alcance/restricciones → SPs a usar; si escribió "
            "cambioPropuestoSql, indíquelo en una línea.\n"
            "- Si el coordinador ya escribió analisis en el formulario, úselo y mejórelo; "
            "no lo ignore ni lo sustituya por un cuestionario.\n"
            "- NO pregunte «qué le falta al coordinador» como eje. Solo pida un dato "
            "si bloquea de verdad la solución.\n"
            "- NO genere dictamen HTML en este turno.\n"
            "- No dé por terminado el turno hasta que esos campos del formulario estén escritos.\n"
            "- Si genera o ajusta el mockup UX: debe mostrar la **ventana propuesta** "
            "(cambioPropuestoSimple / criterios / recomendación), no la captura del problema "
            "ni pantallas de otro REQ. Regenere con Generar mockups o reescriba el HTML.\n"
            "- No escriba el manual, el guion ni la ventana flexible: cuando analisis y "
            "recomendacion queden en solicitud.json, la oficina los dispara sola."
        )
    elif motivo == "criterios":
        extra = (
            "- Motivo: criterios + proyección de análisis desde REQ y conocimiento (no OpenAI).\n"
            "- Contraste el REQ con conocimiento/{proceso}/sps.json y proceso.json.\n"
            "- Complete OBLIGATORIAMENTE solicitud.contenido: criteriosAceptacion, alcance, "
            "restricciones, analisis, recomendacion; criteriosMeta (fuente: agente). "
            "Si aplica cambio SQL: cambioPropuestoSql con fragmentos (ver motivo analizar-req).\n"
            "- Liste SOLO los SP/METODO de este cambio (no todos los del módulo) en "
            "solicitud.sql.metodosDocumentados y brechaAnalisis.sps.\n"
            "- Resuma en chat.json. No genere dictamen HTML.\n"
            "- No termine sin haber escrito esos campos en solicitud.json."
        )
    elif motivo in ("revisar-sql", "revisar-sql-chat"):
        return f"""Eres el agente de revisión SQL de Qrystalos BA. Un turno y termina.

Revisión: {id_caso}

Lea, en este orden:
1. revisiones/{id_caso}/INSTRUCCION-AGENTE.md
2. revisiones/{id_caso}/revision.json
3. revisiones/{id_caso}/chat.json
4. revisiones/{id_caso}/diff.patch y, si existe, detalle.patch
5. revisiones/{id_caso}/propuesto.sql y base.sql

Reglas:
- Español latino, con tildes, en UTF-8. Agregue su mensaje a revisiones/{id_caso}/chat.json (autor: agente, campo en). No borre los mensajes anteriores.
- El Chat se lee en un cuadro estrecho. Escriba secciones cortas. Cada título va en su línea y empieza por ### . Las frases caben en unas 90 letras. No use tablas. Los riesgos van en viñetas: «Riesgo: qué aplica».
- Los nombres con tilde (nómina, electrónica, días, identificación) se escriben con la tilde. No use el carácter de reemplazo.
- No ejecute el script. No use la terminal. No escriba en el catálogo ni en Qrystalos2.
- La comparación de catálogo es PREVERSION contra la última versión cerrada. SQLIXD, cuando existe, guarda ORIGINAL y ACTUALIZACION de esa fila.
- Diga si la estructura y la sintaxis estática alcanzan, qué cambió, si el cambio se ve correcto y qué efectos nocivos puede tener (borrado amplio, update sin filtro, candado comentado, rama que deja de correr, contabilidad).
- No pegue el script completo. Cite el bloque y el efecto.
- Si el modo es chat, responda solo lo que el coordinador acaba de preguntar, con los archivos de esta revisión.

Al terminar, el último mensaje de chat.json debe ser suyo (autor: agente).
"""
    elif motivo in ("prueba-req", "prueba-req-chat"):
        accion = (
            "PRUEBA: contraste la entrega y deje el veredicto."
            if motivo == "prueba-req"
            else "AJUSTE: responda lo último del coordinador y, si cambia el criterio, actualice el veredicto."
        )
        return f"""Eres el agente que prueba requerimientos entregados en Qrystalos BA. UN turno y termina.

Prueba: {id_caso}
Turno: {accion}

Lea del disco, en este orden:
1. data/pruebas-req/{id_caso}/INSTRUCCION-AGENTE.md
2. data/pruebas-req/{id_caso}/meta.json
3. data/pruebas-req/{id_caso}/chat.json

Luego contraste, en este orden y solo lo que haga falta:
1. Base de conocimiento: conocimiento/_indice_busqueda.json y solo la ficha del control. Nunca un sps.json entero.
2. Qrystalos2: el fuente de la pantalla o el método que el desarrollador dice haber cambiado.
3. IXONLINE/SQL (DESAIX): PREVERSION contra la última versión cerrada del procedimiento, la vista o el campo.
4. La base de pruebas de meta.json (servidorId y baseDatos), solo con SELECT. No escriba ni ejecute procedimientos. Use scripts/auditoria_procesos.py (_resolve_server_db y _sqlcmd_query) si hace falta. No imprima credenciales.

{BUSQUEDA_KB}
Reglas:
- Español. La primera línea del chat es Aprobado o Rechazado.
- Escriba en data/pruebas-req/{id_caso}/chat.json (autor: agente, campo en). No borre mensajes previos.
- Actualice meta.json: veredicto = aprobado o rechazado; veredictoTexto = el texto del documento (qué se cumplió o qué debe corregir el desarrollador).
- En veredictoTexto no ponga rutas internas del BA ni comandos de oficina. La fuente SQL se cita como IXONLINE/SQL y el nombre del objeto.
- No genere HTML. No implemente en Qrystalos2 ni cambie la base.
- No invente columnas ni procedimientos. Si un dato no está, dígalo y rechace solo lo que el requerimiento pedía y no aparece.

Al terminar, el último mensaje útil de chat.json debe ser suyo y meta.json debe tener veredicto y veredictoTexto.
"""
    elif motivo in ("soporte-consulta-analisis", "soporte-consulta-chat"):
        accion = (
            "ANÁLISIS INICIAL: contraste la pregunta con conocimiento/ y proponga respuesta completa."
            if motivo == "soporte-consulta-analisis"
            else "AJUSTE: responda lo último del coordinador/soporte en el chat y refine la respuesta."
        )
        return f"""Eres el agente de consultas de soporte de Qrystalos BA. UN turno y termina.

Consulta: {id_caso}
Turno: {accion}

Lea del disco, en este orden:
1. data/soporte-consultas/{id_caso}/INSTRUCCION-AGENTE.md
2. data/soporte-consultas/{id_caso}/meta.json
3. data/soporte-consultas/{id_caso}/chat.json
4. Si hay capturas, léalas en data/soporte-consultas/{id_caso}/imagenes/ y contrástelas con la pregunta.
5. La base, antes que cualquier otra fuente: conocimiento/_indice_busqueda.json y solo la ficha indicada. Nunca un sps.json entero.
6. El guion ya establecido de ese proceso: conocimiento/{{proceso}}/proceso.json (resumen, ventanas, controles) y el grafo de ese proceso (conocimiento/{{proceso}}/grafo-*/, nodos en su orden). La respuesta sigue ese orden. No reordene ni agregue un paso que el grafo o el flujo no tengan.
7. Solo si la ficha leída no alcanza para un dato concreto: SQL → DESAIX; código → Qrystalos2; al final qrystalos.documentacion (config/rutas.json). Eso no autoriza a inventar el tramo que falta. Cada hueco va como handoff a Conocimiento (conocimiento/handoffs/cola.json, de consultas).

{BUSQUEDA_KB}
{_bloque_handoffs(id_caso, motivo)}
Reglas:
- Español. NO implemente en Qrystalos2. NO escriba en la base del cliente ni ejecute procedimientos.
- Si meta.json trae validarEnBase en true, mida en la base antes de cerrar la respuesta. Use servidorId y baseDatos. La conexión es solo lectura: scripts/auditoria_procesos.py (_resolve_server_db y _sqlcmd_query), solo SELECT o SET NOCOUNT. No imprima credenciales ni las copie al chat ni al PDF. Si validarEnBase es true y falta servidor o base, pídalos y deténgase. Si validarEnBase no está marcado, no conecte salvo que el chat lo pida.
- Incorpore conteos y dos o tres filas clave en respuestaOficial. No pida al coordinador que corra sqlcmd ni que pegue resultados: esa medición es suya. Si no hay servidor para ese cliente, dígalo y deje las consultas; no invente filas.
- Escriba en data/soporte-consultas/{id_caso}/chat.json (autor: agente, campo en). No borre mensajes previos.
- Actualice data/soporte-consultas/{id_caso}/meta.json → **respuestaOficial** con el texto listo para entregar (informe claro: reportes, pantallas, pasos DIAN, criterios de inclusión/exclusión de copagos, etc.).
- En el mismo **meta.json** escriba **proposito** (2–4 frases): enlace entre la necesidad (preguntaInicial) y qué entrega el documento. Separe en ese texto qué hace el cliente en pantalla y qué queda para soporte interno (lo ya medido en base y el escalamiento). No use texto genérico de plantilla. Ese texto se muestra en la cabecera del PDF junto a «quién pregunta».
- La última sección de pasos del documento también separa **Para el cliente** y **Para soporte interno**. Al cliente no le pida SQL, sqlcmd ni rutas de la oficina.
- La respuesta oficial no se edita en pantalla: solo en meta.json. Tras un ajuste pedido por chat, la app regenera el documento sola.
- Toda consulta SQL va en bloques ```sql … ``` (uno por consulta) o secciones «BLOQUE N» con líneas ═══; la app las muestra en formato copiar/pegar en el PDF. Esas consultas son de soporte interno.
- Responda solo con lo que la ficha `leido`, el grafo y el flujo del proceso dicen. Cite proceso, SP, METODO y el paso del grafo.
- Si falta la ficha, está en otro estado, o el grafo no cubre la pregunta: escríbalo en el chat y en respuestaOficial («No está documentado: … No puedo afirmarlo»). No rellene con un flujo parecido, un paso de otro módulo ni una pantalla que el proceso.json no nombre.
- No invente SP, columnas, botones ni el orden del proceso. Si falta un dato del cliente en la base SQL, dígalo; no invente filas.
- El PDF lo genera la app desde respuestaOficial + chat; no genere HTML aparte.
- OpenAI no interviene.

Al terminar, el último mensaje útil de chat.json debe ser suyo (autor: agente) y respuestaOficial debe tener borrador actualizado.
"""
    elif motivo == "solicitar-req":
        return f"""Eres el agente BA/funcional de Qrystalos BA. Solicitud para el comité.

ID: {id_caso}

Lea del disco:
1. solicitudes/{id_caso}/INSTRUCCION-AGENTE.md
2. solicitudes/{id_caso}/solicitud.json
3. solicitudes/{id_caso}/chat.json — solo los últimos mensajes; si esta sesión ya leyó 1-2 y no cambiaron, no los relea.
4. solicitudes/{id_caso}/archivos/ (PDF, imágenes, .md/.txt y *.extracto.txt). Si la necesidad llegó en .md, ese archivo es la fuente principal del requerimiento: léalo completo.
5. La base vía conocimiento/_indice_busqueda.json (proceso, control y solo sus fichas). Después, solo para huecos: SQL → DESAIX; código → Qrystalos2; al final qrystalos.documentacion. Huecos: handoff a Conocimiento.

{BUSQUEDA_KB}
{_bloque_handoffs(id_caso, motivo)}
Reglas:
- Español. Responda SOLO en solicitudes/{id_caso}/chat.json (autor: agente). Este Chat permanece activo en cada turno.
- El coordinador plantea una necesidad. Usted analiza contra conocimiento/ y los adjuntos.
- Si hace falta un SP: bájelo de DESAIX/SQLIX (`python scripts/sqlix_bajar_objeto.py --solicitud {id_caso} NOMBRE`) a solicitudes/{id_caso}/sql/, compare PREVERSION vs última Cerrada, y léalo. Tiene permiso. No lo deje en la carpeta compartida sql/.
- No invente SP ni columnas. Liste SOLO los SP/METODO de este cambio.
- Escriba en solicitud.json: titulo CORTO (máx. 90 caracteres), analisis completo, alcance, restricciones, criterios, recomendacion, procesoId.
- Si el cambio es SQL: cambioPropuestoSql con fragmentos BEFORE/AFTER (especificación). El documento de comité lo incluye.
- El documento de comité usa esos campos: no deje un análisis de una línea.
- NO genere el HTML del comité ni el dictamen de implementación.
- Si falta un dato que bloquee, PIDA y deténgase.
- OpenAI no interviene.

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
{_plan_subagentes(id_caso)}
"""
    elif motivo == "material":
        carpeta = _carpeta_caso(id_caso)
        return f"""Eres quien redacta material para quien usa Qrystalos. UN turno y termina.

Caso: {id_caso}
Carpeta: {carpeta}

Lea, en este orden, lo que exista: {carpeta}/solicitud.json (analisis, alcance, recomendacion, cambioPropuestoSimple), {carpeta}/meta.json (respuestaOficial o veredictoTexto) y el último mensaje del coordinador en {carpeta}/chat.json. Escriba manual, capacitación, documento explicativo y planeación en el mismo archivo, cada uno con su título. Si el texto de origen no trae pantalla (una revisión o una prueba), no invente una: deje el manual en lo que sí quedó escrito.

Reglas:
- Español, en lenguaje de pantalla. Sin nombres de procedimiento salvo un apartado final «Para soporte interno».
- Use solo pasos, botones y pantallas que ya estén en el análisis o en el proceso documentado. Si falta un dato, escriba «no documentado».
- No reabra el SQL ni proponga un módulo nuevo.
- Guarde el texto en {carpeta}/material/documento.md
- Resuma en {carpeta}/chat.json (autor: agente) qué quedó.

Al terminar, el último mensaje del chat es suyo y documento.md existe.
"""
    elif motivo == "mockup-ventana":
        carpeta = _carpeta_caso(id_caso)
        return f"""Eres quien arma la ventana de muestra de Qrystalos. UN turno y termina.

Caso: {id_caso}
Carpeta: {carpeta}

1. En {carpeta}/solicitud.json y en el proceso documentado, ubique la pantalla de este cambio.
2. Abra el Vue de esa pantalla en Qrystalos2. Copie títulos, pestañas, botones y columnas que el archivo ya tiene.
3. Escriba un HTML autónomo que se parezca a esa ventana: misma jerarquía, mismas etiquetas. Marque solo el cambio propuesto.
4. No agregue botones, menús ni columnas que el Vue no tenga.
5. Guárdelo en {carpeta}/mockups/mockup-ventana-flexible.html
6. Avise en {carpeta}/chat.json (autor: agente) con la ruta.

Al terminar, el HTML existe y el último mensaje del chat es suyo.
"""
    elif motivo == "presentacion":
        carpeta = _carpeta_caso(id_caso)
        return f"""Eres quien prepara el guion de capacitación de Qrystalos. UN turno y termina.

Caso: {id_caso}
Carpeta: {carpeta}

Lea el análisis ya cerrado en {carpeta}/solicitud.json y, si existe, {carpeta}/material/documento.md.

Escriba un guion hablado, en el orden de la pantalla: qué muestra, qué hace la persona, qué no debe hacer. Sin procedimientos ni rutas internas.

Guárdelo en {carpeta}/material/guion-capacitacion.md y resuma en {carpeta}/chat.json (autor: agente).

No invente pasos. Si falta un tramo, escriba «no documentado».
"""
    return f"""Eres el agente de coordinación de Qrystalos BA. Trabaja SOLO este caso.

ID caso: {id_caso}
Motivo: {motivo}

Lea del disco, en este orden:
1. activo/{id_caso}/INSTRUCCION-AGENTE.md
2. activo/{id_caso}/solicitud.json
3. activo/{id_caso}/chat.json — solo los últimos mensajes (el pedido nuevo está al final); no relea el historial entero.
   Si esta sesión ya leyó 1-2 en un turno anterior y el Chat no dice que cambiaron, no los relea.
4. BASE DE CONOCIMIENTO, SIEMPRE ANTES DEL CÓDIGO: conocimiento/_indice_busqueda.json → solo las fichas del control (ver BÚSQUEDA EN LA BASE). Nunca un sps.json entero.
5. cola/ y activo/{id_caso}/sql/ si aplican
6. SOLO si la base no cubre el punto: si es SQL → DESAIX; si es código fuente → Qrystalos2; al final qrystalos.documentacion (config/rutas.json). Diga en el Chat qué hueco lo obligó y deje handoff a Conocimiento en conocimiento/handoffs/cola.json (de requerimientos, idCaso {id_caso}).

{BUSQUEDA_KB}
{_bloque_handoffs(id_caso, motivo)}
Reglas:
- Responda en español.
- Escriba la respuesta en activo/{id_caso}/chat.json (autor: agente). No incruste el HTML del dictamen en el Chat.
- Si avanza el dictamen, déjelo en dictamenes/{id_caso}.html y ponga el enlace en el Chat.
- NO implemente cambios en Qrystalos2, qrystalos.server ni ejecute SQL.
- SQL: si solicitud.sql.usarDocumentacion=true y los METODOs del control están `leido` en conocimiento/{{proceso}}/sps.json, USE esas fichas. También revise sql_refe/ si el cuerpo ya se archivó. La carpeta de ESTE caso es activo/{id_caso}/sql/. NO use la carpeta compartida sql/ (mezcla otros análisis; esa es solo de Documentar). Pida o baje el .sql a activo/{id_caso}/sql/ (`python scripts/sqlix_bajar_objeto.py --caso {id_caso} NOMBRE`) SOLO si el METODO está listado/no_leido/parcial, el alcance sale de la ficha, o el Chat concluyó que hay que releer la línea exacta.
- Verifique que sql.procesoId coincida con el proceso del REQ (no use notas-dbcr si el control es conciliaciones/FCONCI, etc.).
- NO invente columnas ni SPs. Si falta una aclaración funcional, PIDA y deténgase.
- El coordinador escribe solo en el Chat de la app. No pida que pegue el texto en Cursor.
- Metodología Fase 1 (orden de trabajo): **REQ → conocimiento (proceso/sps) → ¿ya existe? (capacitación|defecto|hueco) → solución**. No trate por defecto un REQ como desarrollo. Inventarie todos los caminos del control, no solo las casillas SQL. No convierta el Chat en un cuestionario de «qué falta del coordinador». En textos al coordinador y al desarrollador diga **control**, no «gate».
- Mockup UX: la ventana debe ser la **propuesta de desarrollo**, no el problema ni la captura. No reutilice HTML de otro REQ.
- OpenAI no interviene. Usted escribe criterios, análisis organizado y recomendación en solicitud.json cuando falten o vengan de GPT.
- Contabilidad: lea solicitud.contenido.contabilidad. Si afecta=true, valide cómoAfecta y desarrollo contra la base (MCUE, CON, MCPE, asientos, comprobantes); si falta, DESAIX/Qrystalos2 y documentación. No invente tablas. Escriba el veredicto en chat.json y en solicitud.json → contenido.contabilidad.validacion {{ estado: ok|observado|no_aplica, texto, validadoEn }}. Si afecta=false, en el dictamen HTML deje solo «Afecta contabilidad: No»; no agregue Cómo lo afecta, Desarrollo contable ni Validación del agente.
{extra}

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
{_plan_subagentes(id_caso)}
"""


def _local_opts(motivo: str = "chat"):
    from cursor_sdk import LocalAgentOptions

    # Consultas/Documentar: sin reglas de proyecto (son 14 KB+ por turno). Van en el prompt.
    fuentes = [] if motivo in MOTIVOS_KB else ["project"]
    try:
        return LocalAgentOptions(cwd=ROOT, setting_sources=fuentes)
    except TypeError:
        return LocalAgentOptions(cwd=ROOT)


def _agent_options(api_key: str, motivo: str = "chat"):
    from cursor_sdk import AgentOptions

    opts = {
        "api_key": api_key,
        "model": modelo_selection(motivo),
        "local": _local_opts(motivo),
        "disallowed_tools": list(HERRAMIENTAS_NO),
    }
    if motivo in MOTIVOS_KB:
        opts["tools"] = list(HERRAMIENTAS_KB)
    return AgentOptions(**opts)


# --- Arranque del puente node del SDK -------------------------------------------------
# Cada turno lanza un puente propio; con chats en paralelo varios arrancan a la vez y el
# descubrimiento pasaba de 30 s (CursorSDKError "Timed out waiting for bridge discovery").
BRIDGE_TIMEOUT_SEC = float(os.environ.get("CURSOR_BRIDGE_TIMEOUT_SEC") or 120)
BRIDGE_MAX_ARRANQUES = max(1, int(os.environ.get("CURSOR_BRIDGE_MAX_ARRANQUES") or 2))
BRIDGE_SLOT_DIR = os.path.join(ROOT, "data", "bridge-slots")
_BRIDGE_SLOT_STALE_SEC = BRIDGE_TIMEOUT_SEC * 2 + 60


def _tomar_slot_bridge(espera_max: float) -> str | None:
    """Semáforo entre procesos: como mucho BRIDGE_MAX_ARRANQUES puentes arrancando a la vez."""
    os.makedirs(BRIDGE_SLOT_DIR, exist_ok=True)
    fin = time.time() + espera_max
    while True:
        for i in range(BRIDGE_MAX_ARRANQUES):
            path = os.path.join(BRIDGE_SLOT_DIR, f"slot-{i}.lock")
            try:
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError:
                try:
                    with open(path, encoding="utf-8") as fh:
                        dueno = int((fh.read() or "0").strip() or 0)
                except (OSError, ValueError):
                    dueno = 0
                try:
                    viejo = time.time() - os.path.getmtime(path) > _BRIDGE_SLOT_STALE_SEC
                except OSError:
                    viejo = False
                if viejo or (dueno and not pid_vivo(dueno)):
                    try:
                        os.remove(path)  # slot de un proceso caído
                    except OSError:
                        pass
                continue
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(str(os.getpid()))
            return path
        if time.time() > fin:
            return None  # mejor arrancar sin slot que no responder
        time.sleep(0.5)


def _soltar_slot_bridge(path: str | None) -> None:
    if path:
        try:
            os.remove(path)
        except OSError:
            pass


async def abrir_bridge():
    """launch_bridge con timeout amplio, 1 reintento si el descubrimiento expira y semáforo
    de arranque. Solo el arranque se serializa; el turno corre en paralelo."""
    import asyncio

    from cursor_sdk import CursorSDKError
    from cursor_sdk.asyncio import AsyncClient

    _limpiar_bridges_huerfanos()
    ultimo: Exception | None = None
    for intento in (1, 2):
        t0 = time.time()
        slot = await asyncio.to_thread(_tomar_slot_bridge, BRIDGE_TIMEOUT_SEC)
        espera = time.time() - t0
        t1 = time.time()
        try:
            client = await AsyncClient.launch_bridge(workspace=ROOT, timeout=BRIDGE_TIMEOUT_SEC)
            print(
                f"[bridge] arrancó en {time.time() - t1:.1f}s (espera slot {espera:.1f}s, intento {intento})",
                flush=True,
            )
            return client
        except CursorSDKError as exc:
            ultimo = exc
            print(
                f"[bridge] falló en {time.time() - t1:.1f}s (intento {intento}): {exc}",
                flush=True,
            )
            if "discovery" not in str(exc).lower() or intento == 2:
                raise
        finally:
            _soltar_slot_bridge(slot)
    raise ultimo  # type: ignore[misc]


def _limpiar_bridges_huerfanos() -> int:
    """Windows: mata node.exe del puente (cursor_sdk\\_vendor\\bridge) cuyo python padre ya murió."""
    if os.name != "nt":
        return 0
    try:
        out = sin_consola.run_hidden(
            [
                "powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                "Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | "
                "Where-Object { $_.CommandLine -like '*cursor_sdk*_vendor*bridge*' } | "
                "ForEach-Object { \"$($_.ProcessId) $($_.ParentProcessId)\" }",
            ],
            capture_output=True, text=True, timeout=20,
        ).stdout or ""
    except Exception as exc:  # noqa: BLE001
        print(f"[bridge] no se pudo listar huérfanos: {exc}", flush=True)
        return 0
    n = 0
    for linea in out.splitlines():
        partes = linea.split()
        if len(partes) != 2 or not all(p.isdigit() for p in partes):
            continue
        pid, padre = int(partes[0]), int(partes[1])
        if padre == os.getpid() or pid_vivo(padre):
            continue  # su python sigue vivo: no es huérfano
        try:
            sin_consola.run_hidden(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True, timeout=15)
            n += 1
        except Exception:  # noqa: BLE001
            pass
    if n:
        print(f"[bridge] {n} puente(s) huérfano(s) cerrados", flush=True)
    return n


# --- Turno: tiempos y turno anterior en curso ----------------------------------------
ESPERA_TURNO_PREVIO_SEC = float(os.environ.get("CURSOR_BOT_ESPERA_TURNO_SEC") or 15 * 60)
_ESTADOS_VIVOS = ("running", "queued", "creating")


class _Tiempos:
    """Mide cada fase del turno y deja una línea [tiempos] en bot.log."""

    def __init__(self, id_caso: str, motivo: str) -> None:
        self.id_caso, self.motivo = id_caso, motivo
        self.t0 = self.ult = time.time()
        self.fases: list[tuple[str, float]] = []
        self.extra: dict = {}
        self.primer_evento: float | None = None
        self.herramientas: dict[str, int] = {}
        self.archivos: dict[str, int] = {}

    def marca(self, fase: str, **extra) -> None:
        ahora = time.time()
        self.fases.append((fase, ahora - self.ult))
        self.ult = ahora
        self.extra.update(extra)

    def evento(self, msg) -> None:
        if self.primer_evento is None:
            self.primer_evento = time.time() - self.t0
        if getattr(msg, "type", "") != "tool_call" or getattr(msg, "status", "") == "running":
            return
        nombre = getattr(msg, "name", "") or "?"
        self.herramientas[nombre] = self.herramientas.get(nombre, 0) + 1
        args = getattr(msg, "args", None)
        if isinstance(args, dict):
            ruta = args.get("path") or args.get("file_path") or args.get("target_file") or args.get("pattern")
            if ruta:
                ruta = str(ruta).replace("\\", "/")[-80:]
                self.archivos[ruta] = self.archivos.get(ruta, 0) + 1

    def resumen(self) -> None:
        total = time.time() - self.t0
        fases = " ".join(f"{f}={d:.1f}s" for f, d in self.fases)
        pe = f"{self.primer_evento:.1f}s" if self.primer_evento is not None else "-"
        herr = ", ".join(f"{k}×{v}" for k, v in sorted(self.herramientas.items(), key=lambda x: -x[1])[:6])
        top = ", ".join(f"{k}×{v}" for k, v in sorted(self.archivos.items(), key=lambda x: -x[1])[:6])
        print(
            f"[tiempos] {self.motivo} total={total:.1f}s {fases} primer_evento={pe} "
            f"herramientas={sum(self.herramientas.values())} ({herr or '-'}) "
            f"prompt_chars={self.extra.get('chars', '-')} archivos: {top or '-'}",
            flush=True,
        )


async def _consumir_run(run, t: "_Tiempos"):
    """Lee el stream (para medir) y devuelve el resultado final como run.wait()."""
    try:
        async for msg in run.stream():
            t.evento(msg)
    except Exception as exc:  # noqa: BLE001
        print(f"[tiempos] stream no disponible: {type(exc).__name__}: {exc}", flush=True)
    t.marca("run")
    return await run.wait()


async def _runs_vivos(client, agent_id: str) -> list:
    try:
        pagina = await client.list_runs(agent_id, limit=8)
    except Exception:
        return []
    return [
        r for r in (getattr(pagina, "items", None) or [])
        if str(getattr(r, "status", "") or "").lower().split(".")[-1] in _ESTADOS_VIVOS
    ]


async def _esperar_turno_previo(client, agent_id: str, id_caso: str) -> bool:
    """Si la sesión tiene un turno vivo, espera a que termine (sin cancelarlo). True si quedó libre."""
    import asyncio

    vivos = await _runs_vivos(client, agent_id)
    if not vivos:
        return True
    t0 = time.time()
    print(f"[turno] esperando {len(vivos)} turno(s) anterior(es) de {agent_id}", flush=True)
    write_bot(id_caso, fase="esperando turno anterior", heartbeatEn=_now())
    append_chat(id_caso, "sistema", "Esperando que termine el turno anterior de este chat; luego sigo con su mensaje.")
    for r in vivos:
        resto = ESPERA_TURNO_PREVIO_SEC - (time.time() - t0)
        if resto <= 0:
            break
        try:
            await asyncio.wait_for(client.wait_live_run(r.id), timeout=resto)
        except Exception:  # noqa: BLE001
            pass
    restantes = await _runs_vivos(client, agent_id)
    if restantes and time.time() - t0 < 10:
        # wait_live_run volvio enseguida: nadie esta ejecutando ese turno (quedo huerfano
        # por un proceso caido). Solo esos se cancelan; un turno real si se espera.
        for r in restantes:
            try:
                await client.cancel_run(r.id)
                print(f"[turno] turno huerfano {r.id} cancelado", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"[turno] no pude cancelar huerfano {r.id}: {type(exc).__name__}", flush=True)
        await asyncio.sleep(2)
        restantes = await _runs_vivos(client, agent_id)
    libre = not restantes
    print(f"[turno] espera {time.time() - t0:.1f}s libre={libre}", flush=True)
    write_bot(id_caso, fase="")
    return libre


def _es_turno_activo(exc: Exception) -> bool:
    from cursor_sdk import AgentBusyError

    return isinstance(exc, AgentBusyError) or "already has active run" in str(exc).lower()


async def _send_esperando_turno(client, agent, prompt: str, id_caso: str, intentos: int = 4):
    """agent.send que, si la sesión tiene otro turno activo, espera y reintenta. No cancela nada."""
    import asyncio

    aid = getattr(agent, "agent_id", "") or ""
    await _esperar_turno_previo(client, aid, id_caso)
    for i in range(1, intentos + 1):
        try:
            return await agent.send(prompt)
        except Exception as exc:  # noqa: BLE001
            if not _es_turno_activo(exc) or i == intentos:
                raise
            print(f"[turno] send {i}: sesión ocupada ({type(exc).__name__}); espero y reintento", flush=True)
            if not await _esperar_turno_previo(client, aid, id_caso):
                await asyncio.sleep(min(30, 5 * i))


async def _check_key_async(key: str) -> int:
    from cursor_sdk.asyncio import AsyncClient, AsyncCursor

    async with await abrir_bridge() as client:
        me = await AsyncCursor.me(client=client, api_key=key)
        nombre = getattr(me, "api_key_name", None) or getattr(me, "user_email", None) or "ok"
        print("clave_ok=1")
        print("cuenta=" + str(nombre))
        return 0


def check_key() -> int:
    pairs = load_cursor_api_keys()
    if not pairs:
        print("CURSOR_API_KEY vacia. Peguela en .env (opcional CURSOR_API_KEY_2)")
        return 1
    try:
        import asyncio
    except ImportError:
        print("Falta el paquete cursor-sdk en este Python. Use: py -3.12 -m pip install --only-binary=cursor-sdk cursor-sdk")
        return 1

    ok_idx = -1
    for i, (label, key) in enumerate(pairs):
        if len(key) < 20:
            print(f"clave_{label}=formato_invalido")
            continue
        try:
            codigo = asyncio.run(_check_key_async(key))
            if codigo == 0:
                ok_idx = i
                print(f"indice_activo={i}")
                print(f"etiqueta_activa={label}")
                set_active_api_key_index(i, label)
                os.environ["CURSOR_API_KEY"] = key
                return 0
        except Exception as exc:
            print(f"clave_{label}=0")
            print("error=" + type(exc).__name__)
            detalle = str(exc).replace(key, "***")
            print("detalle=" + detalle[:240])
    if ok_idx >= 0:
        return 0
    print("clave_ok=0")
    print("ninguna_clave_valida=1")
    return 1


def _texto_sin_clave(texto: str) -> str:
    import re

    limpio = re.sub(r"crsr_[A-Za-z0-9_\-]+", "crsr_***", str(texto or ""))
    limpio = " ".join(limpio.split())
    return limpio[:280]


def _aviso_fallo_cursor(exc: BaseException) -> str:
    from cursor_sdk import (
        AgentBusyError,
        AuthenticationError,
        ConfigurationError,
        NetworkError,
        RateLimitError,
    )

    detalle = _texto_sin_clave(exc)
    if isinstance(exc, AuthenticationError):
        return "La clave CURSOR_API_KEY fue rechazada. Revísela en .env y reintente."
    if isinstance(exc, RateLimitError):
        return "Cursor limitó el uso (cupo o velocidad). Espere un momento y reintente."
    if isinstance(exc, AgentBusyError):
        return "Había un turno anterior todavía ocupado. Ya se canceló. Pulse Analizar de nuevo."
    if isinstance(exc, NetworkError):
        return "No hubo conexión con Cursor. Revise la red y reintente."
    if isinstance(exc, ConfigurationError):
        return "Cursor rechazó el agente (" + detalle + "). Reintente."
    if detalle:
        return "El agente se detuvo (" + type(exc).__name__ + ": " + detalle + "). Reintente."
    return "El agente se detuvo (" + type(exc).__name__ + "). Reintente. La clave está configurada."


async def _soltar_turnos_vivos(client, agent_id: str) -> int:
    """Cancela turnos que quedaron en marcha y bloquean el siguiente envío."""
    n = 0
    if not agent_id:
        return 0
    try:
        pagina = await client.list_runs(agent_id, limit=8)
        items = getattr(pagina, "items", None) or []
    except Exception:
        return 0
    for item in items:
        estado = str(getattr(item, "status", "") or "").lower()
        if estado not in ("running", "queued", "creating"):
            continue
        try:
            await client.cancel_run(item.id)
            n += 1
        except Exception:
            pass
    return n


def run_caso(id_caso: str, motivo: str, clave: str = "") -> int:
    sid = kb_sid(id_caso)
    if not sid:
        return _run_caso_impl(id_caso, motivo, clave)
    import conocimiento as kb

    canal = canal_de(id_caso, motivo)
    kb.preparar_sesion_run(canal, sid)
    try:
        return _run_caso_impl(id_caso, motivo, clave)
    finally:
        try:
            kb.absorber_sesion_run(canal, sid)
        except Exception as exc:  # noqa: BLE001
            print(f"[absorber_sesion_run] {exc}", flush=True)


def _run_caso_impl(id_caso: str, motivo: str, clave: str = "") -> int:
    if motivo == "documentar-auto":
        write_bot(
            id_caso,
            estado="listo",
            error="",
            motivo=motivo,
            terminadoEn=_now(),
        )
        return 0
    pairs = load_cursor_api_keys()
    if not pairs:
        write_bot(
            id_caso,
            estado="sin_clave",
            error="Falta CURSOR_API_KEY en .env",
            pid=os.getpid(),
            motivo=motivo,
        )
        append_chat(
            id_caso,
            "sistema",
            "El bot no arrancó: falta CURSOR_API_KEY en .env. Péguela y vuelva a escribir.",
        )
        return 1

    write_bot(
        id_caso,
        estado="trabajando",
        error="",
        pid=os.getpid(),
        motivo=motivo,
        iniciadoEn=_now(),
        heartbeatEn=_now(),
        terminadoEn=None,
        claveConfigurada=True,
    )
    latido = _start_heartbeat(id_caso)

    try:
        import asyncio

        from cursor_sdk import AuthenticationError, CursorAgentError
    except ImportError:
        latido.set()
        write_bot(
            id_caso,
            estado="error",
            error="Falta paquete cursor-sdk",
            terminadoEn=_now(),
        )
        append_chat(
            id_caso,
            "sistema",
            "Falta cursor-sdk en " + (sys.executable or "Python") + ".",
        )
        return 1

    pedida = (clave or "").strip()
    if pedida:
        idx_pedida = next((i for i, (label, _key) in enumerate(pairs) if label == pedida), -1)
        if idx_pedida < 0:
            write_bot(
                id_caso,
                estado="sin_clave",
                error="La clave asignada a este agente no está cargada.",
                pid=os.getpid(),
                motivo=motivo,
            )
            append_chat(
                id_caso,
                "sistema",
                "Este agente tiene una clave asignada que ya no está en .env. Cámbiela en el panel de agentes.",
            )
            latido.set()
            return 1
        order = [idx_pedida]
    else:
        meta = _load_active_key_meta()
        start = meta.get("indice") if isinstance(meta.get("indice"), int) else 0
        if not (0 <= start < len(pairs)):
            start = 0
        order = list(range(start, len(pairs))) + list(range(0, start))

    try:
        for pos, idx in enumerate(order):
            label, key = pairs[idx]
            os.environ["CURSOR_API_KEY"] = key
            write_bot(id_caso, claveEtiqueta=label)
            try:
                codigo = asyncio.run(_run_caso_async(id_caso, motivo, key))
                if not pedida:
                    set_active_api_key_index(idx, label)
                if codigo == 0:
                    _disparar_siguiente(id_caso, motivo)
                return codigo
            except CursorAgentError as exc:
                if isinstance(exc, AuthenticationError) and pos + 1 < len(order):
                    print(f"Clave {label} rechazada; probando siguiente…", flush=True)
                    continue
                print(_aviso_fallo_cursor(exc), flush=True)
                traceback.print_exc()
                write_bot(
                    id_caso,
                    estado="error",
                    error=_texto_sin_clave(exc) or type(exc).__name__,
                    terminadoEn=_now(),
                )
                append_chat(id_caso, "sistema", _aviso_fallo_cursor(exc))
                return 1
        return 1
    except Exception:
        write_bot(id_caso, estado="error", error="excepcion", terminadoEn=_now())
        append_chat(id_caso, "sistema", "El bot se detuvo por un error interno. Reintente desde el Chat.")
        traceback.print_exc()
        return 1
    finally:
        latido.set()


def _reindexar_kb() -> None:
    """El agente edita sps.json/proceso.json con su herramienta: regenerar el índice al terminar."""
    try:
        import kb_indice

        kb_indice.regenerar()
    except Exception as exc:  # noqa: BLE001
        print(f"[kb_indice] {exc}", flush=True)


async def _run_caso_async(id_caso: str, motivo: str, key: str) -> int:
    import asyncio

    from cursor_sdk import AgentBusyError, CursorAgentError
    from cursor_sdk.asyncio import AsyncAgent, AsyncClient

    options = _agent_options(key, motivo)
    es_kb = es_conocimiento(id_caso, motivo)
    meta = read_json(agente_path(id_caso), {})
    modelo_pedido = modelo_id(motivo)
    modelo_guardado = (meta.get("modelo") or "").strip()
    fast_pedido = usa_fast(motivo)
    fast_guardado = meta.get("fast")
    # Una sesión por rol: Conocimiento y Consultas reutilizan la suya (canal propio) y la
    # renuevan cada KB_TURNOS_SESION turnos para que el contexto no crezca sin control.
    # Requerimientos: una sesión por caso (agente.json vive en la carpeta del caso).
    rol = rol_de(id_caso, motivo)
    turnos = int(meta.get("turnos") or 0)
    agent_id = (meta.get("agentId") or "").strip()
    if meta.get("rol") and meta.get("rol") != rol:
        agent_id = ""
    if es_kb and (KB_TURNOS_SESION <= 0 or turnos >= KB_TURNOS_SESION):
        agent_id = ""
    if agent_id and modelo_guardado and modelo_guardado != modelo_pedido:
        agent_id = ""
    if agent_id and fast_guardado is not None and bool(fast_guardado) != bool(fast_pedido):
        agent_id = ""
    timeout_sec = TIMEOUT_KB_SEC if es_kb else TIMEOUT_CASO_SEC

    t = _Tiempos(id_caso, motivo)
    async with await abrir_bridge() as client:
        t.marca("bridge")
        agent = None
        if agent_id:
            try:
                agent = await AsyncAgent.resume(agent_id, options, client=client)
                t.marca("resume")
            except AgentBusyError:
                # La sesión tiene un turno en curso: esperarlo (nunca cancelarlo) y reanudar.
                await _esperar_turno_previo(client, agent_id, id_caso)
                try:
                    agent = await AsyncAgent.resume(agent_id, options, client=client)
                    t.marca("resume")
                except Exception:
                    agent = None
            except Exception:
                agent = None
        if agent is None:
            agent = await AsyncAgent.create(options, client=client)
            t.marca("create")

        try:
            meta_out = {
                "modelo": modelo_id(motivo),
                "fast": usa_fast(motivo),
                "rol": rol,
                "agentId": agent.agent_id,
                "lastAgentId": agent.agent_id,
                "turnos": (turnos + 1) if agent.agent_id == agent_id else 1,
            }
            write_json(agente_path(id_caso), meta_out)
            write_bot(id_caso, agentId=agent.agent_id, modelo=modelo_id(motivo), fast=usa_fast(motivo))

            prompt = prompt_turno(id_caso, motivo)
            t.marca("prompt", chars=len(prompt))
            try:
                run = await _send_esperando_turno(client, agent, prompt, id_caso)
            except Exception as exc:  # noqa: BLE001
                if not _es_turno_activo(exc):
                    raise
                write_bot(id_caso, estado="error", error="Turno anterior aún activo", terminadoEn=_now())
                append_chat(
                    id_caso,
                    "sistema",
                    "El turno anterior de este chat sigue trabajando. Su mensaje quedó guardado: "
                    "vuelva a enviarlo cuando ese turno termine.",
                )
                return 2
            t.marca("send")
            write_bot(id_caso, runId=getattr(run, "id", None) or getattr(run, "run_id", None))
            try:
                result = await asyncio.wait_for(_consumir_run(run, t), timeout=timeout_sec)
            except CursorAgentError as exc:
                print(_aviso_fallo_cursor(exc), flush=True)
                try:
                    vivo = await client.get_run(run.id)
                    estado_run = str(getattr(vivo, "status", "") or "").lower()
                except Exception:
                    estado_run = ""
                if estado_run in ("running", "queued", "creating"):
                    try:
                        result = await asyncio.wait_for(client.wait_live_run(run.id), timeout=180)
                    except Exception:
                        await _soltar_turnos_vivos(client, getattr(agent, "agent_id", "") or "")
                        raise
                else:
                    raise
            except TimeoutError:
                try:
                    if hasattr(run, "cancel"):
                        await run.cancel()
                except Exception:
                    pass
                write_bot(
                    id_caso,
                    estado="error",
                    error=f"El turno superó {timeout_sec // 60} min y se canceló.",
                    terminadoEn=_now(),
                )
                append_chat(
                    id_caso,
                    "sistema",
                    "El turno se cortó por tiempo máximo para no seguir gastando tokens. Vuelva a enviar si hace falta.",
                )
                return 2
            status = getattr(result, "status", None) or ""
            if str(status) in ("error", "RunStatus.error"):
                write_bot(id_caso, estado="error", error="El agente falló a mitad del turno", terminadoEn=_now())
                append_chat(id_caso, "sistema", "El bot falló en este turno. Reintente desde el Chat.")
                return 2

            if ultimo_autor(id_caso) != "agente":
                texto = (getattr(result, "result", None) or "").strip()
                if texto:
                    append_chat(id_caso, "agente", texto)
                else:
                    append_chat(
                        id_caso,
                        "sistema",
                        "El bot terminó pero no dejó mensaje en el Chat. Reintente o escriba de nuevo.",
                    )

            _reindexar_kb()
            write_bot(id_caso, estado="listo", error="", terminadoEn=_now())
            return 0
        finally:
            t.resumen()
            if es_kb:
                try:
                    await asyncio.wait_for(agent.archive(), timeout=20)
                except Exception:
                    pass
            try:
                await asyncio.wait_for(agent.close(), timeout=20)
            except Exception:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Bot Cursor para Qrystalos BA")
    parser.add_argument("--check", action="store_true", help="Validar CURSOR_API_KEY")
    parser.add_argument("--caso", help="ID caso activo")
    parser.add_argument("--clave", default="", help="Etiqueta de CURSOR_API_KEY asignada al agente")
    parser.add_argument(
        "--motivo",
        default="chat",
        choices=[
            "chat",
            "activar",
            "contabilidad",
            "conocimiento",
            "consultas",
            "documentar",
            "documentar-auto",
            "analizar-req",
            "criterios",
            "solicitar-req",
            "revisar-sql",
            "revisar-sql-chat",
            "soporte-consulta-analisis",
            "soporte-consulta-chat",
            "material",
            "mockup-ventana",
            "presentacion",
        ],
    )
    args = parser.parse_args()

    if args.check:
        return check_key()
    if not args.caso:
        print("Indique --caso o --check")
        return 1
    if not os.path.isdir(caso_dir(args.caso)):
        print("No existe la carpeta del caso o de proceso: " + args.caso)
        return 1
    _adjuntar_log(args.caso)
    return run_caso(args.caso, args.motivo, args.clave or "")


def _adjuntar_log(id_caso: str) -> None:
    """pythonw no tiene consola: el traceback va a bot.log."""
    log_path = os.path.join(caso_dir(id_caso), "bot.log")
    try:
        fh = open(log_path, "a", encoding="utf-8")
        sys.stdout = fh
        sys.stderr = fh
        print(f"\n--- {_now()} stdout→bot.log pid={os.getpid()} ---", flush=True)
    except OSError:
        pass


def pid_vivo(pid) -> bool:
    if not pid:
        return False
    try:
        pid = int(pid)
    except (TypeError, ValueError):
        return False
    if os.name == "nt":
        try:
            import ctypes

            kernel32 = ctypes.windll.kernel32
            handle = kernel32.OpenProcess(0x1000, False, pid)
            if not handle:
                return False
            try:
                code = ctypes.c_ulong()
                if kernel32.GetExitCodeProcess(handle, ctypes.byref(code)) == 0:
                    return False
                return int(code.value) == 259
            finally:
                kernel32.CloseHandle(handle)
        except Exception:
            return False
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def _segundos_desde(iso) -> int | None:
    if not iso:
        return None
    try:
        t0 = datetime.fromisoformat(str(iso))
        return max(0, int((datetime.now() - t0).total_seconds()))
    except ValueError:
        return None


def leer_estado_bot(id_caso: str) -> dict:
    data = read_json(bot_path(id_caso), {})
    vivo = pid_vivo(data.get("pid"))
    hace_hb = _segundos_desde(data.get("heartbeatEn") or data.get("iniciadoEn"))
    pid_n = 0
    try:
        pid_n = int(data.get("pid") or 0)
    except (TypeError, ValueError):
        pid_n = 0
    arrancando = data.get("estado") == "trabajando" and pid_n <= 0 and (hace_hb is None or hace_hb < 25)
    # Solo marcar muerto si el PID ya existió y el proceso cayó (no al arrancar con pid=0).
    colgado = (
        data.get("estado") == "trabajando"
        and not arrancando
        and not vivo
        and (hace_hb is not None and hace_hb > 12)
    )
    if colgado:
        motivo_err = (
            "El proceso del bot se detuvo."
            if not vivo
            else "El bot no late (se quedó colgado)."
        )
        write_bot(id_caso, estado="error", error=motivo_err, terminadoEn=_now())
        data = read_json(bot_path(id_caso), data)
        vivo = False
    data["pidVivo"] = vivo
    data["claveConfigurada"] = bool(load_api_key())
    data["elapsedSec"] = _segundos_desde(data.get("iniciadoEn")) or 0
    return data


def _start_heartbeat(id_caso: str) -> threading.Event:
    stop = threading.Event()

    def loop():
        while not stop.wait(5):
            write_bot(id_caso, heartbeatEn=_now())

    threading.Thread(target=loop, daemon=True).start()
    return stop


PYTHON_312_FIJO = r"C:\Users\JOSE MANUEL\AppData\Local\Programs\Python\Python312\python.exe"
PERFIL_BOT_FIJO = r"C:\Users\JOSE MANUEL"
TAREA_BOT = "QrystalosBA-CursorBot"


def _perfil_usuario_bot() -> str:
    env_u = (os.environ.get("QRISTALOS_BOT_USERPROFILE") or "").strip()
    if env_u and os.path.isdir(env_u):
        return env_u
    if os.path.isdir(PERFIL_BOT_FIJO):
        return PERFIL_BOT_FIJO
    return (os.environ.get("USERPROFILE") or "").strip()


def _es_cuenta_servicio() -> bool:
    user = (os.environ.get("USERNAME") or "").upper()
    profile = (os.environ.get("USERPROFILE") or "").replace("/", "\\").lower()
    return user in {"SYSTEM", "LOCAL SERVICE", "NETWORK SERVICE"} or profile.endswith(
        "\\systemprofile"
    )


def _env_bot(base: dict | None = None) -> dict:
    env = dict(base or os.environ)
    perfil = _perfil_usuario_bot()
    if perfil:
        env["QRISTALOS_BOT_USERPROFILE"] = perfil
        env["USERPROFILE"] = perfil
        drive, tail = os.path.splitdrive(perfil)
        if drive:
            env["HOMEDRIVE"] = drive
        if tail:
            env["HOMEPATH"] = tail
        env["LOCALAPPDATA"] = os.path.join(perfil, "AppData", "Local")
        env["APPDATA"] = os.path.join(perfil, "AppData", "Roaming")
        user_site = os.path.join(
            perfil, "AppData", "Roaming", "Python", "Python312", "site-packages"
        )
        if os.path.isdir(user_site):
            prev = (env.get("PYTHONPATH") or "").strip()
            env["PYTHONPATH"] = user_site if not prev else user_site + os.pathsep + prev
    env["CURSOR_API_KEY"] = load_api_key()
    return env


def python_bot() -> list[str]:
    """El SDK oficial solo tiene rueda Windows x64; no partir rutas con espacios."""
    perfil = _perfil_usuario_bot()
    local_app = (
        os.path.join(perfil, "AppData", "Local")
        if perfil
        else (os.environ.get("LOCALAPPDATA") or "")
    )
    candidatos = [
        [os.environ["PYTHON_BOT"]] if (os.environ.get("PYTHON_BOT") or "").strip() else None,
        [PYTHON_312_FIJO],
        [os.path.join(local_app, "Programs", "Python", "Python312", "python.exe")],
        [os.path.join(local_app, "Programs", "Python", "Python312-64", "python.exe")],
        ["py", "-3.12"],
    ]
    import subprocess

    env = _env_bot()
    existentes: list[list[str]] = []
    for cmd in candidatos:
        if not cmd or not cmd[0]:
            continue
        if os.path.sep in cmd[0] and not os.path.isfile(cmd[0]):
            continue
        if "313-32" in cmd[0] or cmd[0].lower().endswith("python313-32\\python.exe"):
            continue
        existentes.append(cmd)
        try:
            probe = subprocess.run(
                cmd + ["-c", "import cursor_sdk, sys; sys.exit(0)"],
                capture_output=True,
                text=True,
                timeout=20,
                env=env,
            )
            if probe.returncode == 0:
                return cmd
        except Exception:
            continue
    for cmd in existentes:
        if any("312" in part for part in cmd):
            return cmd
    if os.path.isfile(PYTHON_312_FIJO):
        return [PYTHON_312_FIJO]
    return existentes[0] if existentes else [PYTHON_312_FIJO]


def _pythonw(exe: list[str]) -> list[str]:
    out = list(exe)
    if not out:
        return out
    head = out[0]
    if head.lower().endswith("python.exe"):
        candidato = head[:-10] + "pythonw.exe"
        if os.path.isfile(candidato):
            out[0] = candidato
    return out


def _escribir_vbs_bot(exe: list[str], script: str, id_caso: str, motivo: str, clave: str = "") -> str:
    import subprocess

    # sh.Run ..., 0 oculta la consola de python.exe; los hijos la heredan oculta.
    cmd = list(exe) + [script, "--caso", id_caso, "--motivo", motivo]
    if (clave or "").strip():
        cmd += ["--clave", clave.strip()]
    linea = subprocess.list2cmdline(cmd)
    vbs_cmd = linea.replace('"', '""')
    vbs_path = os.path.join(caso_dir(id_caso), "lanzar-bot.vbs")
    with open(vbs_path, "w", encoding="ascii", errors="replace") as fh:
        fh.write('Set sh = CreateObject("WScript.Shell")\r\n')
        fh.write('sh.CurrentDirectory = "' + ROOT.replace("\\", "\\\\") + '"\r\n')
        fh.write('sh.Run "' + vbs_cmd + '", 0, False\r\n')
    return vbs_path


def _lanzar_via_tarea(vbs_path: str) -> tuple[bool, str]:
    import subprocess

    user = os.path.basename(_perfil_usuario_bot()) or "JOSE MANUEL"
    tr = subprocess.list2cmdline(["wscript.exe", "//nologo", "//B", vbs_path])
    create = subprocess.run(
        [
            "schtasks",
            "/Create",
            "/TN",
            TAREA_BOT,
            "/TR",
            tr,
            "/SC",
            "ONCE",
            "/ST",
            "23:59",
            "/SD",
            "01/01/2099",
            "/RU",
            user,
            "/IT",
            "/F",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if create.returncode != 0:
        detalle = (create.stderr or create.stdout or "schtasks /Create").strip()
        return False, detalle[:400]
    run = subprocess.run(
        ["schtasks", "/Run", "/TN", TAREA_BOT],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if run.returncode != 0:
        detalle = (run.stderr or run.stdout or "schtasks /Run").strip()
        return False, detalle[:400]
    return True, ""


def _esperar_arranque(id_caso: str, timeout_sec: float = 20) -> dict:
    deadline = time.time() + timeout_sec
    ultimo = {}
    while time.time() < deadline:
        ultimo = read_json(bot_path(id_caso), {})
        estado = ultimo.get("estado") or ""
        if estado == "trabajando" and pid_vivo(ultimo.get("pid")):
            return {"ok": True, "pid": ultimo.get("pid"), "yaCorria": False}
        if estado == "sin_clave" and ultimo.get("terminadoEn"):
            return {"ok": False, "error": "sin_clave"}
        time.sleep(0.4)
    if pid_vivo(ultimo.get("pid")):
        return {"ok": True, "pid": ultimo.get("pid"), "yaCorria": False}
    return {"ok": False, "error": "proceso_muerto", "detalle": ultimo.get("error") or ""}


def _clave_del_turno(id_caso: str, motivo: str) -> str:
    """Etiqueta asignada al rol. Vacío = la clave predeterminada."""
    try:
        import agentes_panel

        return agentes_panel.clave_de(rol_de(id_caso, motivo))
    except Exception:
        return ""


def _disparar_siguiente(id_caso: str, motivo: str) -> None:
    """Con los datos escritos, lanza el manual, la ventana, el guion y el armado."""
    try:
        import orquesta
    except Exception:
        return
    nxt = ""
    if motivo in ("material", "mockup-ventana", "presentacion"):
        nxt = orquesta.avanzar(id_caso, motivo)
    elif orquesta.siguiente(motivo):
        if not orquesta.datos_listos(id_caso, motivo):
            append_chat(
                id_caso,
                "sistema",
                "El texto de este proceso todavía no quedó escrito. Cuando esté, entra al mismo cierre que los demás: manual y documento armado.",
            )
            return
        nxt = orquesta.abrir_cierre(id_caso, motivo)
    if not nxt:
        return
    if nxt == "armar":
        try:
            ruta = orquesta.armar(id_caso)
        except Exception as exc:  # noqa: BLE001
            append_chat(id_caso, "sistema", "No pude armar el documento: " + str(exc))
            return
        append_chat(id_caso, "sistema", "Documento armado: " + ruta)
        return
    nombres = {
        "material": "el manual, la capacitación y la planeación",
        "mockup-ventana": "la ventana, parecida a la pantalla",
        "presentacion": "el guion de la capacitación",
    }
    append_chat(id_caso, "sistema", "Datos listos. Sigue " + nombres.get(nxt, nxt) + ".")
    lanzar_bot(id_caso, nxt, encadenado=True)


def lanzar_bot(id_caso: str, motivo: str = "chat", encadenado: bool = False) -> dict:
    if motivo == "documentar-auto":
        return {"ok": False, "error": "barrido_deshabilitado"}
    actual = leer_estado_bot(id_caso)
    if not encadenado and actual.get("estado") == "trabajando" and pid_vivo(actual.get("pid")):
        return {"ok": True, "yaCorria": True, "pid": actual.get("pid")}
    if not os.path.isdir(caso_dir(id_caso)):
        return {"ok": False, "error": "sin_caso"}
    clave = _clave_del_turno(id_caso, motivo)
    if clave:
        if not clave_por_etiqueta(clave):
            write_bot(
                id_caso,
                estado="sin_clave",
                error="La clave asignada a este agente no está cargada.",
                motivo=motivo,
            )
            return {"ok": False, "error": "sin_clave"}
    elif not load_api_key():
        write_bot(id_caso, estado="sin_clave", error="Falta CURSOR_API_KEY en .env", motivo=motivo)
        return {"ok": False, "error": "sin_clave"}

    log_path = os.path.join(caso_dir(id_caso), "bot.log")
    import subprocess

    exe = python_bot()
    script = os.path.join(SCRIPT_DIR, "cursor_bot.py")
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(f"\n--- {_now()} motivo={motivo} exe={exe} servicio={_es_cuenta_servicio()} ---\n")

    write_bot(
        id_caso,
        estado="trabajando",
        pid=0,
        motivo=motivo,
        iniciadoEn=_now(),
        heartbeatEn=_now(),
        error="",
        terminadoEn=None,
    )

    if _es_cuenta_servicio():
        vbs_path = _escribir_vbs_bot(exe, script, id_caso, motivo, clave)
        ok, detalle = _lanzar_via_tarea(vbs_path)
        if not ok:
            write_bot(
                id_caso,
                estado="error",
                error="No se pudo lanzar el bot en la sesión del usuario.",
                terminadoEn=_now(),
            )
            append_chat(
                id_caso,
                "sistema",
                "El servicio no pudo arrancar el bot en su sesión (" + detalle + ").",
            )
            return {"ok": False, "error": "tarea_usuario"}
        return _esperar_arranque(id_caso)

    creation = 0
    if os.name == "nt":
        creation = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    with open(log_path, "a", encoding="utf-8") as log:
        # python.exe + CREATE_NO_WINDOW: consola oculta que heredan node y los shells del SDK.
        # Con pythonw cada hijo de consola abría su propia ventana negra.
        cmd = list(exe) + [script, "--caso", id_caso, "--motivo", motivo]
        if clave:
            cmd += ["--clave", clave]
        proc = subprocess.Popen(
            cmd,
            cwd=ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            creationflags=creation,
            env=_env_bot(),
        )
    write_bot(id_caso, pid=proc.pid)
    time.sleep(0.8)
    if proc.poll() is not None or not pid_vivo(proc.pid):
        write_bot(
            id_caso,
            estado="error",
            error="El proceso del bot se cerró al arrancar. Revise bot.log.",
            terminadoEn=_now(),
        )
        return {"ok": False, "error": "proceso_muerto", "pid": proc.pid}
    return {"ok": True, "pid": proc.pid, "yaCorria": False}


if __name__ == "__main__":
    sys.exit(main())
