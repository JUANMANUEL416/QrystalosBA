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

from quatec_db import get_db  # noqa: E402

ACTIVO = os.path.join(ROOT, "activo")
CONOCIMIENTO = os.path.join(ROOT, "conocimiento")
ENV_PATH = os.path.join(ROOT, ".env")
MODELO = os.environ.get("CURSOR_BOT_MODEL", "composer-2.5")
CONOCIMIENTO_ID = "__conocimiento__"


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


def es_conocimiento(id_caso: str, motivo: str = "") -> bool:
    return motivo == "conocimiento" or id_caso == CONOCIMIENTO_ID


def caso_dir(id_caso: str) -> str:
    if id_caso == CONOCIMIENTO_ID:
        return CONOCIMIENTO
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

        kb.append_chat(autor, texto, (kb.load_chat() or {}).get("procesoId") or "")
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


def prompt_turno(id_caso: str, motivo: str) -> str:
    if es_conocimiento(id_caso, motivo):
        return """Eres el agente de coordinación de Qrys.Quatec. Este turno es el Chat de PROCESO (Consultas / Documentar), no un REQ.

Lea del disco:
1. conocimiento/chat.json — último mensaje del coordinador (releer entero)
2. conocimiento/tarea.json
3. conocimiento/INDICE.json y conocimiento/{proceso}/proceso.json + sps.json
4. sql/ si hay .sql de hoy
5. Qrystalos2 y documentación si hace falta para la pregunta

Reglas:
- Responda en español en conocimiento/chat.json (autor: agente). Campo de fecha: use "en" (no "fecha").
- NO implemente Qrystalos2 ni ejecute SQL.
- NO invente columnas ni SPs. Si falta un .sql, pídalo.
- El coordinador escribe solo en la app. No pida que pegue el texto en Cursor.

Al terminar, el último mensaje relevante de conocimiento/chat.json debe ser suyo (autor: agente).
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
            "- Motivo de este turno: ANALIZAR REQUERIMIENTO (no dictamen).\n"
            "- Lea solicitud.contenido: requerimiento, criteriosAceptacion, alcance, restricciones "
            "y analisis (texto del coordinador; puede estar vacío).\n"
            "- Contraste el REQ con el análisis del coordinador.\n"
            "- Responda CORTO en chat.json (autor: agente), en este orden:\n"
            "  1) Qué ya se puede dar por sentado.\n"
            "  2) Qué LE FALTA analizar a usted (agente) en Qrystalos2 / SQL / documentación "
            "para VALIDAR el análisis del coordinador.\n"
            "  3) Qué dato falta del coordinador si su análisis está incompleto o vacío.\n"
            "- NO genere dictamen HTML. NO invente SPs ni columnas. Si falta un .sql, pídalo en la lista.\n"
            "- Escriba el mismo texto en solicitud.json → contenido.brechaAnalisis "
            "{ texto, fecha (ISO), estado: \"listo\" }."
        )
    elif motivo == "criterios":
        extra = (
            "- Motivo de este turno: PROPONER CRITERIOS (no dictamen, no OpenAI).\n"
            "- Escríbalos en solicitud.contenido.criteriosAceptacion y criteriosMeta (fuente: agente).\n"
            "- Organice analisis y recomendacion si están vacíos.\n"
            "- Resuma en chat.json. No genere dictamen HTML."
        )
    return f"""Eres el agente de coordinación de Qrys.Quatec. Trabaja SOLO este caso.

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
- NO invente columnas ni SPs. Si falta SQL o una aclaración, PIDA y deténgase.
- El coordinador escribe solo en el Chat de la app. No pida que pegue el texto en Cursor.
- Metodología Fase 1: ventana → proceso → backend → SPKs → análisis rápido. No salte al dictamen completo si aún no hay ventana confirmada.
- OpenAI no interviene. Usted escribe criterios, análisis organizado y recomendación en solicitud.json cuando falten o vengan de GPT.
- Contabilidad: lea solicitud.contenido.contabilidad. Si afecta=true, valide cómoAfecta y desarrollo contra Qrystalos2 (MCUE, CON, MCPE, asientos, comprobantes) y documentación. No invente tablas. Escriba el veredicto en chat.json y en solicitud.json → contenido.contabilidad.validacion {{ estado: ok|observado|no_aplica, texto, validadoEn }}.
{extra}

Al terminar, el último mensaje relevante de chat.json debe ser suyo (autor: agente).
"""


def _local_opts():
    from cursor_sdk import LocalAgentOptions

    try:
        return LocalAgentOptions(cwd=ROOT, setting_sources=["project"])
    except TypeError:
        return LocalAgentOptions(cwd=ROOT)


def _agent_options(api_key: str):
    from cursor_sdk import AgentOptions

    return AgentOptions(api_key=api_key, model=MODELO, local=_local_opts())


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
        write_bot(id_caso, estado="error", error="Falta paquete cursor-sdk", terminadoEn=_now())
        append_chat(id_caso, "sistema", "Falta instalar cursor-sdk en Python 3.12 x64.")
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
    from cursor_sdk.asyncio import AsyncAgent, AsyncClient

    options = _agent_options(key)
    meta = read_json(agente_path(id_caso), {})
    agent_id = (meta.get("agentId") or "").strip()

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
            write_json(agente_path(id_caso), {"agentId": agent.agent_id, "modelo": MODELO})
            write_bot(id_caso, agentId=agent.agent_id)

            run = await agent.send(prompt_turno(id_caso, motivo))
            write_bot(id_caso, runId=getattr(run, "id", None) or getattr(run, "run_id", None))
            result = await run.wait()
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
            try:
                await agent.close()
            except Exception:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Bot Cursor para Qrys.Quatec")
    parser.add_argument("--check", action="store_true", help="Validar CURSOR_API_KEY")
    parser.add_argument("--caso", help="ID caso activo")
    parser.add_argument(
        "--motivo",
        default="chat",
        choices=["chat", "activar", "contabilidad", "conocimiento", "analizar-req", "criterios"],
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
    return run_caso(args.caso, args.motivo)


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
    colgado = data.get("estado") == "trabajando" and (not vivo or (hace_hb is not None and hace_hb > 45))
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


def python_bot() -> str:
    """El SDK oficial solo tiene rueda Windows x64; evitar el Python 32 bits."""
    candidatos = [
        os.environ.get("PYTHON_BOT"),
        "py -3.12",
    ]
    for raw in candidatos:
        if not raw:
            continue
        cmd = raw.split()
        try:
            import subprocess

            probe = subprocess.run(
                cmd + ["-c", "import cursor_sdk, sys; sys.exit(0)"],
                capture_output=True,
                text=True,
                timeout=20,
            )
            if probe.returncode == 0:
                return raw
        except Exception:
            continue
    return sys.executable


def lanzar_bot(id_caso: str, motivo: str = "chat") -> dict:
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

    creation = 0
    if os.name == "nt":
        creation = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(f"\n--- {_now()} motivo={motivo} ---\n")
        log.flush()
        env = os.environ.copy()
        env["CURSOR_API_KEY"] = load_api_key()
        exe = python_bot().split()
        proc = subprocess.Popen(
            exe + [os.path.join(SCRIPT_DIR, "cursor_bot.py"), "--caso", id_caso, "--motivo", motivo],
            cwd=ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            creationflags=creation,
            env=env,
        )
    write_bot(
        id_caso,
        estado="trabajando",
        pid=proc.pid,
        motivo=motivo,
        iniciadoEn=_now(),
        heartbeatEn=_now(),
        error="",
    )
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
