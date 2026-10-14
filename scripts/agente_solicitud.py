# -*- coding: utf-8 -*-
"""Análisis de una solicitud de requerimiento con el modelo local y conocimiento/.

No llama a Cursor ni a una API de pago. Escribe el resultado en solicitud.json y en el chat.
"""
from __future__ import annotations

import json
import os
import re
import threading
import unicodedata
import urllib.error
import urllib.request

import conocimiento as kb
import solicitud_req as solreq
from cursor_bot import leer_estado_bot, pid_vivo, write_bot

OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
def _modelo() -> str:
    try:
        import agentes_panel

        return agentes_panel.modelo_local()
    except Exception:
        return os.environ.get("CONSULTA_MODELO", "qwen2.5-coder:7b")

STOP = {
    "para", "como", "cuando", "donde", "desde", "hasta", "entre", "sobre",
    "porque", "cual", "cuales", "este", "esta", "esto", "esos", "esas",
    "tiene", "pueden", "puede", "solo", "tambien", "con", "sin", "del",
    "las", "los", "una", "uno", "que", "por", "sus",
}


def _tokens(texto: str) -> set[str]:
    plano = unicodedata.normalize("NFD", texto or "")
    plano = "".join(c for c in plano if unicodedata.category(c) != "Mn")
    return {p for p in re.findall(r"[a-z0-9_]{4,}", plano.lower()) if p not in STOP}


def _recorte(texto: str, n: int) -> str:
    texto = (texto or "").strip()
    if len(texto) <= n:
        return texto
    return texto[:n].rstrip() + "…"


def _ficha(sol: dict) -> tuple[dict, str]:
    info = solreq.contrastar_kb(sol)
    pid = (info.get("procesoId") or "").strip()
    pregunta = " ".join(
        str(sol.get(k) or "")
        for k in ("titulo", "necesidad", "hoy", "propuesta", "justificacion")
    )
    q = _tokens(pregunta)
    partes = [
        f"Proceso ubicado: {info.get('procesoNombre') or 'ninguno'} ({pid or 'sin id'})",
        f"Estado de la ficha: {info.get('procesoEstado') or 'sin ficha'}",
        "Resumen: " + _recorte(info.get("resumen") or "", 700),
    ]
    if not info.get("existe"):
        return info, "\n".join(partes)

    proceso = kb.load_proceso(pid) or {}
    alcance = _recorte(proceso.get("alcanceHasta") or "", 400)
    if alcance:
        partes.append("Alcance documentado: " + alcance)

    metodos = []
    for sp in (kb.load_sps(pid) or {}).get("sps") or []:
        for metodo in sp.get("metodos") or []:
            blob = " ".join(
                [
                    str(metodo.get("id") or ""),
                    str(metodo.get("hace") or ""),
                    " ".join(metodo.get("valida") or []),
                    " ".join(metodo.get("noValida") or []),
                ]
            )
            metodos.append((_tokens(blob) & q, sp.get("nombre") or "", metodo))
    metodos.sort(key=lambda fila: len(fila[0]), reverse=True)
    elegidos = [fila for fila in metodos if fila[0]][:2]
    if elegidos:
        partes.append("Métodos de la ficha que coinciden:")
        for _, sp_nombre, metodo in elegidos:
            partes.append(f"- {sp_nombre} · {metodo.get('id')}: {_recorte(metodo.get('hace') or '', 400)}")
            if metodo.get("noValida"):
                partes.append("  No valida: " + _recorte("; ".join(metodo["noValida"]), 280))
    else:
        partes.append("Ningún método de la ficha coincidió con la necesidad.")

    controles = []
    for capa in proceso.get("capas") or []:
        for control in kb.controles_de(capa):
            blob = f"{control.get('nombre') or ''} {control.get('explicacion') or ''}"
            controles.append((len(_tokens(blob) & q), control))
    controles.sort(key=lambda fila: fila[0], reverse=True)
    visibles = [fila for fila in controles if fila[0] > 0][:2]
    if visibles:
        partes.append("Controles que coinciden:")
        for _, control in visibles:
            partes.append(f"- {control.get('nombre')}: {_recorte(control.get('explicacion') or '', 280)}")
    return info, "\n".join(partes)[:4500]


def _pedir(system: str, user: str, tope: int) -> str:
    cuerpo = json.dumps(
        {
            "model": _modelo(),
            "stream": False,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "options": {"temperature": 0.2, "num_predict": tope, "num_ctx": 4096},
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA + "/api/chat",
        data=cuerpo,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        datos = json.loads(resp.read().decode("utf-8"))
    return ((datos.get("message") or {}).get("content") or "").strip()


def _ollama_vivo() -> bool:
    try:
        with urllib.request.urlopen(OLLAMA + "/api/tags", timeout=3) as resp:
            json.load(resp)
        return True
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return False


def _json_de(texto: str) -> dict:
    limpio = texto.strip()
    limpio = re.sub(r"^```(?:json)?\s*", "", limpio)
    limpio = re.sub(r"\s*```$", "", limpio)
    inicio = limpio.find("{")
    fin = limpio.rfind("}")
    if inicio < 0 or fin <= inicio:
        raise ValueError("El modelo no devolvió un objeto.")
    datos = json.loads(limpio[inicio : fin + 1])
    if not isinstance(datos, dict):
        raise ValueError("El modelo no devolvió un objeto.")
    return datos


def _campo(datos: dict, clave: str, n: int) -> str:
    valor = datos.get(clave)
    if isinstance(valor, list):
        valor = "\n".join(str(x).strip() for x in valor if str(x).strip())
    return _recorte(str(valor or "").strip(), n)


def _poner(sol: dict, clave: str, valor: str) -> None:
    if valor:
        sol[clave] = valor


def _aplicar(sol: dict, datos: dict, info: dict) -> dict:
    _poner(sol, "analisis", _campo(datos, "analisis", 1800))
    _poner(sol, "alcance", _campo(datos, "alcance", 800))
    _poner(sol, "restricciones", _campo(datos, "restricciones", 800))
    _poner(sol, "criterios", _campo(datos, "criterios", 1200))
    _poner(sol, "recomendacion", _campo(datos, "recomendacion", 800))
    if not (sol.get("procesoId") or "").strip() and info.get("procesoId"):
        sol["procesoId"] = info["procesoId"]
    if not (sol.get("titulo") or "").strip():
        _poner(sol, "titulo", _campo(datos, "titulo", 90))
    return sol


def _texto_chat(datos: dict, info: dict) -> str:
    clas = _campo(datos, "clasificacion", 40) or "sin clasificar"
    lineas = [
        f"## Análisis local ({_modelo()})",
        "",
        f"Clasificación: **{clas}**.",
        f"Proceso: {info.get('procesoNombre') or 'sin ubicar'}.",
        "",
        _campo(datos, "analisis", 1800),
        "",
        "**Alcance.** " + _campo(datos, "alcance", 800),
        "",
        "**Fuera de alcance.** " + _campo(datos, "restricciones", 800),
        "",
        "**Criterios.**",
        _campo(datos, "criterios", 1200),
        "",
        "**Recomendación.** " + _campo(datos, "recomendacion", 800),
        "",
        "Quedó escrito en la solicitud. Siguen el documento de comité, el mockup de la propuesta y el diagrama de flujo.",
    ]
    return "\n".join(lineas)


def _instruccion_analisis() -> str:
    return (
        "Eres el analista de solicitudes de Qrystalos. Respondes solo con un objeto JSON, "
        "sin markdown. Español, lenguaje de negocio, frases cortas. "
        "Usas únicamente la necesidad y la ficha. Si la ficha no cubre el pedido, dilo en analisis. "
        "No inventes procedimientos, columnas ni pantallas. "
        "clasificacion es una de: capacitacion, defecto, hueco. "
        "capacitacion = el sistema ya lo hace. defecto = el camino existe y falla. "
        "hueco = no hay control para esa necesidad. "
        "criterios es un texto con una comprobación por línea."
    )


def _entregables(id_sr: str, notas: str = "", cuales: list | None = None) -> list[str]:
    """Genera mockup, diagrama y documento. El documento va al final para incrustar los otros dos."""
    pedido = [c for c in (cuales or ["mockup", "diagrama", "documento"]) if c in ("mockup", "diagrama", "documento")]
    if not pedido:
        pedido = ["mockup", "diagrama", "documento"]
    hechos = []
    if "mockup" in pedido:
        try:
            solreq.generar_mockups(id_sr, notas=notas)
            hechos.append("mockup")
        except Exception as exc:
            solreq.append_chat(id_sr, "sistema", "No se pudo generar el mockup: " + str(exc))
    if "diagrama" in pedido:
        try:
            solreq.generar_diagrama(id_sr, notas=notas)
            hechos.append("diagrama")
        except Exception as exc:
            solreq.append_chat(id_sr, "sistema", "No se pudo generar el diagrama: " + str(exc))
    if "documento" in pedido:
        try:
            solreq.generar_documento(id_sr)
            hechos.append("documento")
        except Exception as exc:
            solreq.append_chat(id_sr, "sistema", "No se pudo generar el documento: " + str(exc))
    return hechos


def _pasos() -> list[dict]:
    import agentes_panel

    return agentes_panel.subagentes_de("solicitar")


def _paso(pasos: list[dict], sid: str) -> str:
    for fila in pasos:
        if fila["id"] == sid:
            return fila["motor"]
    return "local"


def _delegar_cursor(id_sr: str, pasos: list[dict]) -> None:
    import agentes_panel
    from cursor_bot import lanzar_bot

    nombres = ", ".join(fila["nombre"] for fila in pasos)
    agentes_panel.publicar_plan("solicitar", id_sr)
    bot = lanzar_bot(id_sr, "solicitar-req", encadenado=True)
    if bot.get("ok"):
        solreq.append_chat(id_sr, "sistema", "Pasos en Cursor: " + nombres + ".")
        return
    solreq.append_chat(
        id_sr,
        "sistema",
        "No arrancó Cursor para " + nombres + ". " + str(bot.get("error") or bot.get("detalle") or ""),
    )


def _correr_analisis(id_sr: str) -> None:
    pasos = _pasos()
    sol = solreq.load(id_sr) or {}
    info, ficha = _ficha(sol)
    if _paso(pasos, "solicitar-redaccion") == "local":
        user = (
            f"NECESIDAD:\n{_recorte(sol.get('necesidad') or '', 900)}\n\n"
            f"CÓMO OPERA HOY:\n{_recorte(sol.get('hoy') or '', 700)}\n\n"
            f"PROPUESTA:\n{_recorte(sol.get('propuesta') or '', 700)}\n\n"
            f"FICHA:\n{ficha}\n\n"
            "Devuelve JSON con las claves clasificacion, titulo, analisis, alcance, "
            "restricciones, criterios, recomendacion."
        )
        datos = _json_de(_pedir(_instruccion_analisis(), user, 480))
        sol = solreq.load(id_sr) or sol
        _aplicar(sol, datos, info)
        solreq.guardar(sol)
        texto = _texto_chat(datos, info)
        if _paso(pasos, "solicitar-pantalla") == "cursor" or _paso(pasos, "solicitar-desaix") == "cursor":
            texto += "\n\nPantalla y DESAIX, si están en Cursor, confirman esta clasificación en el turno de pago."
        solreq.append_chat(id_sr, "agente", texto)
        if _paso(pasos, "solicitar-entregables") == "local":
            _entregables(id_sr)
    else:
        solreq.append_chat(
            id_sr,
            "agente",
            "La redacción de este turno está en Cursor. El mockup, el flujo y el documento se generan cuando ese texto quede escrito.",
        )
    en_cursor = [fila for fila in pasos if fila["motor"] == "cursor" and fila["id"] != "solicitar-chat"]
    if en_cursor:
        _delegar_cursor(id_sr, en_cursor)


def _correr_chat(id_sr: str) -> None:
    if _paso(_pasos(), "solicitar-chat") == "cursor":
        _delegar_cursor(id_sr, [fila for fila in _pasos() if fila["id"] == "solicitar-chat"])
        return
    sol = solreq.load(id_sr) or {}
    chat = solreq.load_chat(id_sr)
    pregunta = ""
    for msg in reversed(chat.get("mensajes") or []):
        if msg.get("autor") == "coordinador" and (msg.get("texto") or "").strip():
            pregunta = msg["texto"].strip()
            break
    if not pregunta:
        solreq.append_chat(id_sr, "sistema", "No hay pregunta del coordinador para responder.")
        return
    info, ficha = _ficha(sol)
    system = (
        "Eres el analista de una solicitud de Qrystalos. Respondes solo con JSON, sin markdown. "
        "accion es responder si es una duda, o ajustar si pide cambiar el análisis, el documento, "
        "el mockup o el diagrama. respuesta es el texto para el coordinador, en español y corto. "
        "Si accion es ajustar, llena solo los campos que deben cambiar: analisis, alcance, "
        "restricciones, criterios, recomendacion. notas resume el cambio para redibujar mockup y flujo. "
        "regenerar es una lista con documento, mockup y diagrama, solo los que hay que volver a generar. "
        "No inventes procedimientos ni columnas."
    )
    user = (
        f"SOLICITUD:\nTítulo: {sol.get('titulo') or ''}\n"
        f"Necesidad: {_recorte(sol.get('necesidad') or '', 500)}\n"
        f"Análisis: {_recorte(sol.get('analisis') or '', 700)}\n"
        f"Recomendación: {_recorte(sol.get('recomendacion') or '', 400)}\n\n"
        f"FICHA:\n{ficha}\n\nMENSAJE:\n{_recorte(pregunta, 800)}"
    )
    crudo = _pedir(system, user, 360)
    try:
        datos = _json_de(crudo)
    except (ValueError, json.JSONDecodeError):
        solreq.append_chat(id_sr, "agente", crudo or "No pude leer la respuesta.")
        return
    respuesta = _campo(datos, "respuesta", 1600) or "Listo."
    if str(datos.get("accion") or "").strip().lower() != "ajustar":
        solreq.append_chat(id_sr, "agente", respuesta)
        return
    sol = solreq.load(id_sr) or sol
    _aplicar(sol, datos, info)
    solreq.guardar(sol)
    regenerar = datos.get("regenerar")
    if not isinstance(regenerar, list) or not regenerar:
        regenerar = ["mockup", "diagrama", "documento"]
    notas = _campo(datos, "notas", 500) or _recorte(pregunta, 500)
    hechos = _entregables(id_sr, notas=notas, cuales=[str(x) for x in regenerar])
    cierre = "Se actualizó: " + ", ".join(hechos) + "." if hechos else "No se regeneró ningún archivo."
    solreq.append_chat(id_sr, "agente", respuesta + "\n\n" + cierre)


def _latido(id_sr: str, stop: threading.Event) -> None:
    from cursor_bot import _now

    while not stop.wait(5):
        write_bot(id_sr, heartbeatEn=_now())


def _trabajar(id_sr: str, turno: str) -> None:
    from cursor_bot import _now

    stop = threading.Event()
    threading.Thread(target=_latido, args=(id_sr, stop), daemon=True).start()
    try:
        pasos = _pasos()
        necesita_ollama = _paso(pasos, "solicitar-chat" if turno == "chat" else "solicitar-redaccion") == "local"
        if necesita_ollama and not _ollama_vivo():
            write_bot(id_sr, estado="error", error="Ollama no está en ejecución.", terminadoEn=_now())
            solreq.append_chat(
                id_sr,
                "sistema",
                "Ollama no está en ejecución. Ábralo y vuelva a enviar el mensaje.",
            )
            return
        if turno == "chat":
            _correr_chat(id_sr)
        else:
            _correr_analisis(id_sr)
        write_bot(id_sr, estado="listo", error="", terminadoEn=_now(), modelo=_modelo())
    except Exception as exc:
        write_bot(id_sr, estado="error", error=str(exc), terminadoEn=_now())
        solreq.append_chat(
            id_sr,
            "sistema",
            "El análisis local no pudo terminar: " + str(exc),
        )
    finally:
        stop.set()


def lanzar(id_sr: str, turno: str = "analizar") -> dict:
    from cursor_bot import _now, _segundos_desde

    actual = leer_estado_bot(id_sr)
    hace = _segundos_desde(actual.get("heartbeatEn"))
    if (
        actual.get("estado") == "trabajando"
        and pid_vivo(actual.get("pid"))
        and hace is not None
        and hace < 15
    ):
        return {"ok": True, "yaCorria": True, "pid": actual.get("pid"), "estado": "trabajando"}
    write_bot(
        id_sr,
        estado="trabajando",
        pid=os.getpid(),
        motivo="agente-local",
        modelo=_modelo(),
        iniciadoEn=_now(),
        heartbeatEn=_now(),
        error="",
        terminadoEn=None,
    )
    threading.Thread(target=_trabajar, args=(id_sr, turno), daemon=True).start()
    return {"ok": True, "pid": os.getpid(), "estado": "trabajando", "local": True, "modelo": _modelo()}
