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

from qrystalos_ba_db import get_db  # noqa: E402

ACTIVO = os.path.join(ROOT, "activo")
SOLICITUDES = os.path.join(ROOT, "solicitudes")
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
ENV_PATH = os.path.join(ROOT, ".env")
# Más barato del pool Cursor: Composer 2.5 estándar.
# Grok 4.6 ≈ 4×; Fast ≈ 6×. No usarlos en bots de oficina.
MODELO = os.environ.get("CURSOR_BOT_MODEL", "composer-2.5")
HERRAMIENTAS_KB = ("read", "edit", "grep", "glob", "ls")
HERRAMIENTAS_NO = ("shell", "task", "mcp", "webSearch")
CONOCIMIENTO_ID = "__conocimiento__"
CONSULTAS_ID = "__consultas__"
DOCUMENTAR_ID = "__documentar__"
CONOCIMIENTO_IDS = {CONOCIMIENTO_ID, CONSULTAS_ID, DOCUMENTAR_ID}
MOTIVOS_KB = frozenset({"conocimiento", "consultas", "documentar", "documentar-auto"})
TIMEOUT_KB_SEC = 12 * 60
TIMEOUT_CASO_SEC = 45 * 60


def _env_bool(name: str, default: bool = False) -> bool:
    raw = (os.environ.get(name) or "").strip().lower()
    if not raw:
        return default
    return raw in ("1", "true", "yes", "si", "on")


FAST_CASOS = _env_bool("CURSOR_BOT_FAST", False)


def modelo_id(motivo: str = "") -> str:
    env = _parse_env(ENV_PATH)
    if motivo in MOTIVOS_KB:
        kb = (os.environ.get("CURSOR_BOT_MODEL_KB") or env.get("CURSOR_BOT_MODEL_KB") or "").strip()
        if kb:
            return kb
    return (os.environ.get("CURSOR_BOT_MODEL") or env.get("CURSOR_BOT_MODEL") or MODELO).strip() or "composer-2.5"


def usa_fast(motivo: str = "") -> bool:
    if motivo in MOTIVOS_KB:
        return False
    return FAST_CASOS


def modelo_selection(motivo: str = ""):
    from cursor_sdk import ModelParameterValue, ModelSelection

    return ModelSelection(
        id=modelo_id(motivo),
        params=[ModelParameterValue(id="fast", value="true" if usa_fast(motivo) else "false")],
    )


def modelo_report() -> dict:
    return {
        "modelo": modelo_id("chat"),
        "modeloKb": modelo_id("consultas"),
        "fast": usa_fast("chat"),
        "fastKb": False,
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


def load_api_key() -> str:
    env = _parse_env(ENV_PATH)
    return (os.environ.get("CURSOR_API_KEY") or env.get("CURSOR_API_KEY") or "").strip()


def canal_de(id_caso: str, motivo: str = "") -> str:
    if id_caso == CONSULTAS_ID or motivo == "consultas":
        return "consultas"
    if id_caso == DOCUMENTAR_ID or motivo in ("documentar", "documentar-auto"):
        return "documentar"
    return "documentar"


def es_conocimiento(id_caso: str, motivo: str = "") -> bool:
    return motivo in ("conocimiento", "consultas", "documentar", "documentar-auto") or id_caso in CONOCIMIENTO_IDS


def es_solicitar(id_caso: str, motivo: str = "") -> bool:
    return motivo == "solicitar-req" or str(id_caso or "").startswith("SR")


def caso_dir(id_caso: str) -> str:
    if id_caso in CONOCIMIENTO_IDS:
        import conocimiento as kb

        canal = canal_de(id_caso)
        kb._ensure_canal(canal)
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
    if es_conocimiento(id_caso):
        import conocimiento as kb

        canal = canal_de(id_caso)
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


def prompt_turno(id_caso: str, motivo: str) -> str:
    if es_conocimiento(id_caso, motivo):
        canal = canal_de(id_caso, motivo)
        ruta = f"conocimiento/canales/{canal}/chat.json"
        recorte = recorte_chat_kb(id_caso)
        tarea = recorte_tarea_kb()
        prohibido = (
            "Este chat es SOLO del procesoId indicado (un módulo). No mezcle facturación con caja ni otros. "
            "Si el prompt trae Respuestas ACEPTADAS y cubren el pedido, conteste con esa base; no reabra sps.json ni Qrystalos2. "
            "PROHIBIDO leer: el chat.json histórico (canales/, chats/, conocimiento/chat.json), "
            "faq.json entero, pendientes.json completo, RUTA.json para barrer, todos los sps.json, "
            "Qrystalos2 y qrystalos.documentacion. Eso ya está destilado en conocimiento/{proceso}/. "
            "Solo abra FE/docs/.sql si la ficha de ESE proceso no cubre el pedido; dígalo en una línea."
        )
        if canal == "consultas":
            return f"""Eres el agente de Consultas de Qrystalos BA. UN turno corto y termina. Sin shell ni web.
{prohibido}

Este turno (ya pegado; NO abra el chat.json):
{recorte}

{tarea}

Método: INDICE.json solo para ubicar el proceso nombrado. Luego SOLO conocimiento/{{id}}/proceso.json y sps.json de ese id.
Responda en {ruta} autor agente, campo "en". Español. No invente columnas ni SP.
"""
        return f"""Eres el agente de Documentar de Qrystalos BA. UN turno y termina. Sin barrido, sin shell ni web.
{prohibido}

Este turno (ya pegado; NO abra el chat.json):
{recorte}

{tarea}

Si la tarea está abierta: lea sql/{{archivoSql}} de hoy y documente METODOs en conocimiento/{{procesoId}}/sps.json. proceso.json solo si cambia un control.
Si no hay tarea: haga únicamente lo que pide el coordinador, en el proceso que nombre.
Responda en {ruta} autor agente, campo "en". Español. NO implemente Qrystalos2 ni ejecute SQL.
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
            "(y sql_refe si hace falta la línea exacta). También Qrystalos2/docs vivos.\n"
            "  2b) PASO 0 ¿YA EXISTE?: texto del REQ ≠ captura. Inventariar TODOS los "
            "caminos del control (botones v-if, Help*, necesidadesYaCubiertas, no solo "
            "los METODOs del formulario). Clasificar: capacitación | defecto | hueco. "
            "Si ya existe, dígalo de frente; impacto No; no proponga módulo nuevo.\n"
            "  3) Determinar la solución concreta (qué cambia y dónde; o capacitación).\n"
            "  4) Escribir OBLIGATORIAMENTE en solicitud.json → contenido:\n"
            "     criteriosAceptacion, alcance, restricciones, analisis, recomendacion;\n"
            "     criteriosMeta.fuente=agente; brechaAnalisis {texto, fecha ISO, estado:\"listo\"}.\n"
            "  5) Actualizar solicitud.sql.metodosDocumentados (y procesoId) SOLO con los "
            "SP/METODO que participan en ESTE cambio. NUNCA copie el catálogo entero de "
            "conocimiento/{proceso}/sps.json (prenómina, retiros, DIAN… si el REQ es solo "
            "impresión). Si el SP del fix no está en sps.json, deje metodosDocumentados "
            "vacío o solo los que sí aplican, pida el .sql y anote en brechaAnalisis.sps. "
            "Tabla en el Chat: SP · METODO · estado · rol en el fix.\n"
            "- Responda en chat.json (autor: agente) con el mismo resumen: problema → causa "
            "(según KB) → solución → CA/alcance/restricciones → SPs a usar.\n"
            "- Si el coordinador ya escribió analisis en el formulario, úselo y mejórelo; "
            "no lo ignore ni lo sustituya por un cuestionario.\n"
            "- NO pregunte «qué le falta al coordinador» como eje. Solo pida un dato "
            "si bloquea de verdad la solución.\n"
            "- NO genere dictamen HTML en este turno.\n"
            "- No dé por terminado el turno hasta que esos campos del formulario estén escritos."
        )
    elif motivo == "criterios":
        extra = (
            "- Motivo: criterios + proyección de análisis desde REQ y conocimiento (no OpenAI).\n"
            "- Contraste el REQ con conocimiento/{proceso}/sps.json y proceso.json.\n"
            "- Complete OBLIGATORIAMENTE solicitud.contenido: criteriosAceptacion, alcance, "
            "restricciones, analisis, recomendacion; criteriosMeta (fuente: agente).\n"
            "- Liste SOLO los SP/METODO de este cambio (no todos los del módulo) en "
            "solicitud.sql.metodosDocumentados y brechaAnalisis.sps.\n"
            "- Resuma en chat.json. No genere dictamen HTML.\n"
            "- No termine sin haber escrito esos campos en solicitud.json."
        )
    elif motivo == "solicitar-req":
        return f"""Eres el agente BA/funcional de Qrystalos BA. Solicitud para el comité de desarrollo.

ID: {id_caso}

Lea del disco:
1. solicitudes/{id_caso}/INSTRUCCION-AGENTE.md
2. solicitudes/{id_caso}/solicitud.json
3. solicitudes/{id_caso}/chat.json
4. conocimiento/INDICE.json y conocimiento/{{proceso}}/proceso.json + sps.json

Reglas:
- Español. Responda en solicitudes/{id_caso}/chat.json (autor: agente).
- Contraste la necesidad con la base de conocimiento. No invente SP ni columnas.
- Liste SOLO los SP/METODO de este cambio.
- Escriba en solicitud.json: analisis, alcance, restricciones, criterios, recomendacion, siguiente; procesoId si lo ubica.
- Entregable: fundamento para el documento de comité (incluir en el plan), NO el dictamen técnico de implementación.
- Si hay aval.aplica, cíteelo. Si falta un dato que bloquee, PIDA y deténgase.
- OpenAI no interviene.

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
"""
    return f"""Eres el agente de coordinación de Qrystalos BA. Trabaja SOLO este caso.

ID caso: {id_caso}
Motivo: {motivo}

Lea del disco, en este orden:
1. activo/{id_caso}/INSTRUCCION-AGENTE.md
2. activo/{id_caso}/solicitud.json
3. activo/{id_caso}/chat.json
4. cola/ y sql/ si aplican
5. Qrystalos2 y qrystalos.documentacion según config/rutas.json

Reglas:
- Responda en español.
- Escriba la respuesta en activo/{id_caso}/chat.json (autor: agente). No incruste el HTML del dictamen en el Chat.
- Si avanza el dictamen, déjelo en dictamenes/{id_caso}.html y ponga el enlace en el Chat.
- NO implemente cambios en Qrystalos2, qrystalos.server ni ejecute SQL.
- SQL: si solicitud.sql.usarDocumentacion=true y los METODOs del control están `leido` en conocimiento/{{proceso}}/sps.json, USE esas fichas. También revise sql_refe/ si el cuerpo ya se archivó. NO pida sql/ vacío solo porque la carpeta del día esté limpia. Pida .sql en sql/ SOLO si el METODO está listado/no_leido/parcial, el alcance sale de la ficha, o el Chat concluyó que hay que releer la línea exacta.
- Verifique que sql.procesoId coincida con el proceso del REQ (no use notas-dbcr si el control es conciliaciones/FCONCI, etc.).
- NO invente columnas ni SPs. Si falta una aclaración funcional, PIDA y deténgase.
- El coordinador escribe solo en el Chat de la app. No pida que pegue el texto en Cursor.
- Metodología Fase 1 (orden de trabajo): **REQ → conocimiento (proceso/sps) → ¿ya existe? (capacitación|defecto|hueco) → solución**. No trate por defecto un REQ como desarrollo. Inventarie todos los caminos del control, no solo las casillas SQL. No convierta el Chat en un cuestionario de «qué falta del coordinador». En textos al coordinador y al desarrollador diga **control**, no «gate».
- OpenAI no interviene. Usted escribe criterios, análisis organizado y recomendación en solicitud.json cuando falten o vengan de GPT.
- Contabilidad: lea solicitud.contenido.contabilidad. Si afecta=true, valide cómoAfecta y desarrollo contra Qrystalos2 (MCUE, CON, MCPE, asientos, comprobantes) y documentación. No invente tablas. Escriba el veredicto en chat.json y en solicitud.json → contenido.contabilidad.validacion {{ estado: ok|observado|no_aplica, texto, validadoEn }}. Si afecta=false, en el dictamen HTML deje solo «Afecta contabilidad: No»; no agregue Cómo lo afecta, Desarrollo contable ni Validación del agente.
{extra}

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
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


async def _check_key_async(key: str) -> int:
    from cursor_sdk.asyncio import AsyncClient, AsyncCursor

    async with await AsyncClient.launch_bridge(workspace=ROOT) as client:
        me = await AsyncCursor.me(client=client, api_key=key)
        nombre = getattr(me, "api_key_name", None) or getattr(me, "user_email", None) or "ok"
        print("clave_ok=1")
        print("cuenta=" + str(nombre))
        return 0


def check_key() -> int:
    key = load_api_key()
    if not key:
        print("CURSOR_API_KEY vacia. Peguela en .env")
        return 1
    if not key.startswith("crsr_") or len(key) < 20:
        print("CURSOR_API_KEY no parece una clave Cursor (debe empezar por crsr_)")
        return 1
    os.environ["CURSOR_API_KEY"] = key
    try:
        import asyncio

        return asyncio.run(_check_key_async(key))
    except ImportError:
        print("Falta el paquete cursor-sdk en este Python. Use: py -3.12 -m pip install --only-binary=cursor-sdk cursor-sdk")
        return 1
    except Exception as exc:
        print("clave_ok=0")
        print("error=" + type(exc).__name__)
        detalle = str(exc).replace(key, "***")
        print("detalle=" + detalle[:240])
        return 1


def run_caso(id_caso: str, motivo: str) -> int:
    if motivo == "documentar-auto":
        write_bot(
            id_caso,
            estado="listo",
            error="",
            motivo=motivo,
            terminadoEn=_now(),
        )
        return 0
    key = load_api_key()
    if not key:
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

    os.environ["CURSOR_API_KEY"] = key
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

        from cursor_sdk import CursorAgentError
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

    try:
        return asyncio.run(_run_caso_async(id_caso, motivo, key))
    except CursorAgentError:
        write_bot(id_caso, estado="error", error="CursorAgentError", terminadoEn=_now())
        append_chat(
            id_caso,
            "sistema",
            "El bot no pudo arrancar (clave, red o Cursor). Revise CURSOR_API_KEY y reintente.",
        )
        return 1
    except Exception:
        write_bot(id_caso, estado="error", error="excepcion", terminadoEn=_now())
        append_chat(id_caso, "sistema", "El bot se detuvo por un error interno. Reintente desde el Chat.")
        traceback.print_exc()
        return 1
    finally:
        latido.set()


async def _run_caso_async(id_caso: str, motivo: str, key: str) -> int:
    import asyncio

    from cursor_sdk.asyncio import AsyncAgent, AsyncClient

    options = _agent_options(key, motivo)
    es_kb = es_conocimiento(id_caso, motivo)
    meta = read_json(agente_path(id_caso), {})
    agent_id = "" if es_kb else (meta.get("agentId") or "").strip()
    timeout_sec = TIMEOUT_KB_SEC if es_kb else TIMEOUT_CASO_SEC

    async with await AsyncClient.launch_bridge(workspace=ROOT) as client:
        agent = None
        if agent_id:
            try:
                agent = await AsyncAgent.resume(agent_id, options, client=client)
            except Exception:
                agent = None
        if agent is None:
            agent = await AsyncAgent.create(options, client=client)

        try:
            meta_out = {
                "modelo": modelo_id(motivo),
                "fast": usa_fast(motivo),
            }
            if es_kb:
                meta_out["lastAgentId"] = agent.agent_id
                meta_out["agentId"] = ""
            else:
                meta_out["agentId"] = agent.agent_id
            write_json(agente_path(id_caso), meta_out)
            write_bot(id_caso, agentId=agent.agent_id, modelo=modelo_id(motivo), fast=usa_fast(motivo))

            run = await agent.send(prompt_turno(id_caso, motivo))
            write_bot(id_caso, runId=getattr(run, "id", None) or getattr(run, "run_id", None))
            try:
                result = await asyncio.wait_for(run.wait(), timeout=timeout_sec)
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

            write_bot(id_caso, estado="listo", error="", terminadoEn=_now())
            return 0
        finally:
            if es_kb:
                try:
                    await agent.archive()
                except Exception:
                    pass
            try:
                await agent.close()
            except Exception:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Bot Cursor para Qrystalos BA")
    parser.add_argument("--check", action="store_true", help="Validar CURSOR_API_KEY")
    parser.add_argument("--caso", help="ID caso activo")
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
    return run_caso(args.caso, args.motivo)


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


def _escribir_vbs_bot(exe: list[str], script: str, id_caso: str, motivo: str) -> str:
    import subprocess

    linea = subprocess.list2cmdline(
        _pythonw(exe) + [script, "--caso", id_caso, "--motivo", motivo]
    )
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


def lanzar_bot(id_caso: str, motivo: str = "chat") -> dict:
    if motivo == "documentar-auto":
        return {"ok": False, "error": "barrido_deshabilitado"}
    actual = leer_estado_bot(id_caso)
    if actual.get("estado") == "trabajando" and pid_vivo(actual.get("pid")):
        return {"ok": True, "yaCorria": True, "pid": actual.get("pid")}
    if not os.path.isdir(caso_dir(id_caso)):
        return {"ok": False, "error": "sin_caso"}
    if not load_api_key():
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
        vbs_path = _escribir_vbs_bot(exe, script, id_caso, motivo)
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
        proc = subprocess.Popen(
            _pythonw(exe) + [script, "--caso", id_caso, "--motivo", motivo],
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
