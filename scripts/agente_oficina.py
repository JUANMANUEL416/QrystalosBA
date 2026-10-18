# -*- coding: utf-8 -*-
"""Corredor local de Consultas, Documentar y Analista.

Usa el modelo de config/agentes.json. No llama a Cursor.
No pisa una ficha ya leída ni un análisis que ya tenga texto.
"""
from __future__ import annotations

import json
import os
import re
import threading
import urllib.error
import urllib.request

import conocimiento as kb
from cursor_bot import append_chat, leer_estado_bot, pid_vivo, write_bot
from qrystalos_ba_db import get_db

OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")

STOP = {
    "para", "como", "cuando", "donde", "desde", "hasta", "entre", "sobre",
    "porque", "cual", "cuales", "este", "esta", "esto", "esos", "esas",
    "tiene", "pueden", "puede", "solo", "tambien", "con", "sin", "del",
    "las", "los", "una", "uno", "que", "por", "sus", "hace", "esta",
}


def _modelo() -> str:
    try:
        import agentes_panel

        return agentes_panel.modelo_local()
    except Exception:
        return "qwen2.5-coder:7b"


def _recorte(texto: str, n: int) -> str:
    texto = (texto or "").strip()
    if len(texto) <= n:
        return texto
    return texto[:n].rstrip() + "…"


def _tokens(texto: str) -> set[str]:
    return {p for p in re.findall(r"[a-z0-9_]{4,}", (texto or "").lower()) if p not in STOP}


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
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return False


def _json_de(texto: str) -> dict:
    limpio = (texto or "").strip()
    limpio = re.sub(r"^```(?:json)?\s*", "", limpio)
    limpio = re.sub(r"\s*```$", "", limpio)
    inicio = limpio.find("{")
    fin = limpio.rfind("}")
    if inicio < 0 or fin <= inicio:
        raise ValueError("sin objeto")
    datos = json.loads(limpio[inicio : fin + 1])
    if not isinstance(datos, dict):
        raise ValueError("no es objeto")
    return datos


def _lista(valor, n: int = 6, largo: int = 220) -> list[str]:
    if isinstance(valor, str):
        valor = [valor]
    if not isinstance(valor, list):
        return []
    salida = []
    for item in valor:
        texto = str(item or "").strip()
        if texto:
            salida.append(texto[:largo])
        if len(salida) >= n:
            break
    return salida


def _proceso(proceso_id: str) -> dict | None:
    pid = (proceso_id or "").strip()
    if not pid:
        return None
    for fila in (kb.load_indice().get("procesos") or []):
        if fila.get("id") == pid:
            return fila
    return None


def _ubicar(pregunta: str, proceso_id: str = "") -> dict | None:
    fijo = _proceso(proceso_id)
    if fijo:
        return fijo
    palabras = _tokens(pregunta)
    objetos = re.findall(r"\b(?:SPK|SPQ|FNK|SP)_[A-Z0-9_]+\b", (pregunta or "").upper())
    mejor = None
    mejor_pts = 0
    for fila in (kb.load_indice().get("procesos") or []):
        pid = fila.get("id") or ""
        blob = " ".join(
            [
                pid.replace("-", " "),
                fila.get("nombre") or "",
                fila.get("familia") or "",
                fila.get("modulo") or "",
                fila.get("resumen") or "",
            ]
        ).lower()
        pts = sum(2 if w in (fila.get("nombre") or "").lower() or w in pid else 1 for w in palabras if w in blob)
        if objetos:
            catalogo = kb.load_sps(pid)
            nombres = {(sp.get("nombre") or "").upper() for sp in catalogo.get("sps") or []}
            pts += 20 * sum(1 for nombre in objetos if nombre in nombres)
        if pts > mejor_pts:
            mejor = fila
            mejor_pts = pts
    return mejor if mejor_pts else None


def _base(proceso: dict | None, pregunta: str) -> str:
    if not proceso:
        return "No hay un proceso de la base que coincida con la pregunta."
    pid = proceso.get("id") or ""
    partes = [
        f"Proceso: {proceso.get('nombre')} ({pid})",
        "Resumen: " + _recorte(proceso.get("resumen") or "", 700),
    ]
    faq = kb.recorte_faq(pid, pregunta)
    if faq:
        partes.append(_recorte(faq, 1200))
    q = _tokens(pregunta)
    metodos = []
    for sp in (kb.load_sps(pid).get("sps") or []):
        for metodo in sp.get("metodos") or []:
            blob = " ".join(
                [
                    str(sp.get("nombre") or ""),
                    str(metodo.get("id") or ""),
                    str(metodo.get("hace") or ""),
                ]
            )
            metodos.append((len(_tokens(blob) & q), sp.get("nombre") or "", metodo))
    metodos.sort(key=lambda fila: fila[0], reverse=True)
    elegidos = [fila for fila in metodos if fila[0]][:2] or metodos[:1]
    if elegidos and elegidos[0][2].get("hace"):
        partes.append("Métodos de la ficha:")
        for _, nombre, metodo in elegidos:
            if not metodo.get("hace"):
                continue
            partes.append(f"- {nombre} · {metodo.get('id')}: {_recorte(metodo.get('hace') or '', 360)}")
            if metodo.get("noValida"):
                partes.append("  No valida: " + _recorte("; ".join(metodo["noValida"]), 240))
    return "\n".join(partes)[:4200]


def _ultimo_coord_kb(canal: str) -> tuple[str, str]:
    chat = kb.load_chat(canal) or {}
    pid = (chat.get("procesoId") or "").strip()
    for msg in reversed(chat.get("mensajes") or []):
        if msg.get("autor") == "coordinador" and (msg.get("texto") or "").strip():
            return pid, str(msg.get("texto") or "").strip()
    return pid, ""


def _responder_consulta(canal: str) -> None:
    pid, pregunta = _ultimo_coord_kb(canal)
    if not pregunta:
        append_chat(kb.bot_id(canal), "agente", "No hay una pregunta del coordinador en este chat.")
        return
    proceso = _ubicar(pregunta, pid)
    base = _base(proceso, pregunta)
    texto = _pedir(
        "Respondes en español, en un párrafo o una lista corta. "
        "Usa solo la base que te pasan. Si el dato no está, di: No está en la ficha. "
        "No inventes columnas, pantallas ni validaciones.",
        f"BASE:\n{base}\n\nPREGUNTA:\n{_recorte(pregunta, 2500)}",
        360,
    )
    if not texto:
        texto = "El modelo local no devolvió texto."
    append_chat(kb.bot_id(canal), "agente", texto, )


def _sql_recorte(archivo: str) -> str:
    nombre = os.path.basename((archivo or "").strip())
    if not nombre:
        return ""
    path = kb.buscar_sql_local(nombre)  # copia local sql/ o sql_refe/ (fuera de git)
    if not path:
        return ""
    with open(path, encoding="utf-8", errors="replace") as fh:
        texto = fh.read()
    return _recorte(texto, 3200)


def _metodo_vacio(metodo: dict) -> bool:
    return not str(metodo.get("hace") or "").strip()


def _fusionar_fichas(proceso_id: str, archivo: str, propuestos: list) -> list[str]:
    if not proceso_id or not os.path.isdir(kb.proceso_dir(proceso_id)):
        return []
    catalogo = kb.load_sps(proceso_id)
    sps = catalogo.setdefault("sps", [])
    por_nombre = {(sp.get("nombre") or "").upper(): sp for sp in sps}
    stem = os.path.splitext(os.path.basename(archivo or ""))[0].upper()
    escritos = []
    for item in propuestos:
        if not isinstance(item, dict):
            continue
        nombre = str(item.get("nombre") or stem or "").strip().upper()
        if not re.fullmatch(r"[A-Z][A-Z0-9_]{2,}", nombre):
            continue
        metodos = item.get("metodos") if isinstance(item.get("metodos"), list) else [item]
        sp = por_nombre.get(nombre)
        if sp is None:
            sp = {
                "nombre": nombre,
                "tipo": nombre.split("_", 1)[0] if "_" in nombre else "SP",
                "estado": "parcial",
                "fuente": "modelo local de prueba",
                "metodos": [],
            }
            sps.append(sp)
            por_nombre[nombre] = sp
        elif (sp.get("estado") or "") != "leido":
            sp["estado"] = "parcial"
        actuales = {(m.get("id") or "").upper(): m for m in sp.setdefault("metodos", [])}
        for metodo in metodos:
            if not isinstance(metodo, dict):
                continue
            mid = str(metodo.get("id") or "").strip().upper()
            hace = _recorte(str(metodo.get("hace") or ""), 400)
            if not re.fullmatch(r"[A-Z0-9_]{2,}", mid) or not hace:
                continue
            previo = actuales.get(mid)
            if previo is not None and not _metodo_vacio(previo):
                continue
            ficha = {
                "id": mid,
                "hace": hace,
                "valida": _lista(metodo.get("valida")),
                "noValida": _lista(metodo.get("noValida")) + [
                    "Borrador del modelo local: contrastar con el script antes de darlo por leído.",
                ],
                "errores": _lista(metodo.get("errores")),
                "llama": _lista(metodo.get("llama"), 8, 80),
                "efecto": _recorte(str(metodo.get("efecto") or ""), 240),
            }
            if previo is None:
                sp["metodos"].append(ficha)
                actuales[mid] = ficha
            else:
                previo.update(ficha)
            escritos.append(f"{nombre} · {mid}")
    if escritos:
        kb.save_sps(proceso_id, catalogo)
    return escritos


def _documentar() -> None:
    pid_chat, pregunta = _ultimo_coord_kb("documentar")
    tarea = kb.load_tarea() or {}
    pid = (tarea.get("procesoId") or pid_chat or "").strip()
    archivo = (tarea.get("archivoSql") or "").strip()
    if tarea.get("abierta") and archivo:
        sql = _sql_recorte(archivo)
        if not sql:
            append_chat("__documentar__", "agente", f"No hay copia local de {archivo} (sql/ o sql_refe/, fuera de git). Léalo en DESAIX o bájelo a sql/ (no se sube al repositorio) y vuelva a pedir la ficha.")
            return
    else:
        sql = ""
    if not sql:
        _responder_consulta("documentar")
        return
    proceso = _ubicar(pregunta or archivo, pid)
    base = _base(proceso, pregunta or archivo)
    try:
        datos = _json_de(
            _pedir(
                "Documentas un procedimiento de Qrystalos. Respondes solo JSON. "
                "No inventes columnas que no aparezcan en el recorte. "
                '{"respuesta":"texto en español","metodos":[{"nombre":"SPQ_X","id":"METODO","hace":"una frase","valida":[],"noValida":[],"errores":[],"llama":[],"efecto":""}]}',
                f"ARCHIVO: {archivo}\nPROCESO: {pid or 'sin id'}\n\nBASE:\n{base}\n\nSQL (recorte):\n{sql}\n\nPEDIDO:\n{_recorte(pregunta, 1500)}",
                480,
            )
        )
    except (ValueError, json.JSONDecodeError, urllib.error.URLError, TimeoutError, OSError):
        datos = {}
    respuesta = str(datos.get("respuesta") or "").strip()
    propuestos = datos.get("metodos") if isinstance(datos.get("metodos"), list) else []
    escritos = _fusionar_fichas(pid, archivo, propuestos)
    if not respuesta:
        respuesta = "Revisé el recorte del script."
    if escritos:
        respuesta += "\n\nFicha en borrador (no pisa métodos que ya tenían texto): " + ", ".join(escritos) + "."
    elif propuestos:
        respuesta += "\n\nNo escribí fichas nuevas: esos métodos ya tenían texto, o el proceso no está en la base."
    else:
        respuesta += "\n\nNo pude armar una ficha nueva con este recorte. El script sigue en sql/ para un turno con Cursor si hace falta el cuerpo completo."
    append_chat("__documentar__", "agente", respuesta)


def _campos_vacios(contenido: dict) -> dict:
    vacios = {}
    for clave in ("analisis", "alcance", "restricciones", "criteriosAceptacion", "recomendacion"):
        if len(str(contenido.get(clave) or "").strip()) < 40:
            vacios[clave] = True
    return vacios


def _aplicar_vacios(contenido: dict, datos: dict) -> list[str]:
    vacios = _campos_vacios(contenido)
    escritos = []
    for clave in vacios:
        texto = _recorte(str(datos.get(clave) or ""), 1800)
        if len(texto) >= 40:
            contenido[clave] = texto
            escritos.append(clave)
    clasificacion = str(datos.get("clasificacion") or "").strip().lower()
    if clasificacion in ("capacitacion", "defecto", "hueco") and "analisis" in escritos:
        contenido["analisis"] = f"Clasificación: {clasificacion}.\n\n" + contenido["analisis"]
    return escritos


def _ajustar_chat(contenido: dict, datos: dict) -> list[str]:
    escritos = []
    for clave in ("analisis", "alcance", "restricciones", "criteriosAceptacion", "recomendacion", "cambioPropuestoSimple"):
        nuevo = _recorte(str(datos.get(clave) or ""), 1800)
        if len(nuevo) < 40:
            continue
        previo = str(contenido.get(clave) or "").strip()
        if len(previo) > 80 and len(nuevo) < int(len(previo) * 0.6):
            continue
        contenido[clave] = nuevo
        escritos.append(clave)
    return escritos


def _contexto_caso(solicitud: dict, pregunta: str) -> str:
    contenido = solicitud.get("contenido") or {}
    ident = solicitud.get("identificacion") or {}
    sql = solicitud.get("sql") or {}
    pid = (sql.get("procesoId") or contenido.get("procesoId") or "").strip()
    proceso = _ubicar(
        " ".join(
            [
                pregunta,
                str(contenido.get("requerimiento") or ""),
                str(contenido.get("titulo") or ""),
            ]
        ),
        pid,
    )
    partes = [
        f"Caso: {ident.get('idCaso') or ''}",
        f"Título: {_recorte(str(contenido.get('titulo') or ''), 180)}",
        f"Requerimiento: {_recorte(str(contenido.get('requerimiento') or ''), 900)}",
        _base(proceso, pregunta or str(contenido.get("requerimiento") or "")),
    ]
    for clave in ("analisis", "alcance", "recomendacion"):
        texto = str(contenido.get(clave) or "").strip()
        if texto:
            partes.append(f"{clave} ya escrito: {_recorte(texto, 500)}")
    return "\n".join(partes)[:4200]


def _analizar_caso(id_caso: str, motivo: str) -> None:
    db = get_db()
    solicitud = db.get_solicitud(id_caso) or {}
    contenido = solicitud.setdefault("contenido", {})
    chat = db.get_chat(id_caso, sync_disk=False)
    pregunta = ""
    for msg in reversed(chat.get("mensajes") or []):
        if msg.get("autor") == "coordinador" and (msg.get("texto") or "").strip():
            pregunta = str(msg.get("texto") or "").strip()
            break
    if not pregunta:
        pregunta = str(contenido.get("requerimiento") or "")
    contexto = _contexto_caso(solicitud, pregunta)
    if motivo == "contabilidad":
        cont = contenido.get("contabilidad") if isinstance(contenido.get("contabilidad"), dict) else {}
        if not cont.get("afecta"):
            append_chat(id_caso, "agente", "Afecta contabilidad: No.")
            return
        validacion = cont.get("validacion") if isinstance(cont.get("validacion"), dict) else {}
        if (validacion.get("estado") or "") == "ok" and (validacion.get("texto") or "").strip():
            append_chat(id_caso, "agente", "La validación contable ya está escrita. No la sustituyo desde el modelo local.")
            return
        texto = _pedir(
            "Valida en español, corto, si el texto contable es coherente con lo que te pasan. "
            "No inventes cuentas. Si falta un dato, dilo.",
            contexto + "\n\nCómo afecta: " + _recorte(str(cont.get("comoAfecta") or ""), 500),
            280,
        )
        from cursor_bot import _now

        cont["validacion"] = {
            "estado": "observado",
            "texto": texto or "El modelo local no pudo contrastar el asiento. Revisar con Cursor.",
            "validadoEn": _now(),
        }
        contenido["contabilidad"] = cont
        db.guardar_solicitud(id_caso, solicitud)
        append_chat(id_caso, "agente", cont["validacion"]["texto"] + "\n\nQuedó como observado: el modelo local no cierra la validación contable.")
        return

    if motivo == "chat":
        try:
            datos = _json_de(
                _pedir(
                    "Eres el analista local de un caso. Respondes solo JSON. "
                    "accion es responder o ajustar. En ajustar incluye solo los campos que el coordinador pidió cambiar. "
                    "No inventes SQL ni columnas. "
                    '{"accion":"responder","respuesta":"...","analisis":"","alcance":"","restricciones":"","criteriosAceptacion":"","recomendacion":"","cambioPropuestoSimple":""}',
                    f"CONTEXTO:\n{contexto}\n\nMENSAJE:\n{_recorte(pregunta, 2000)}",
                    420,
                )
            )
        except (ValueError, json.JSONDecodeError, urllib.error.URLError, TimeoutError, OSError):
            datos = {"accion": "responder", "respuesta": ""}
        respuesta = str(datos.get("respuesta") or "").strip() or "No pude armar la respuesta con la ficha de este caso."
        if str(datos.get("accion") or "").strip().lower() == "ajustar":
            escritos = _ajustar_chat(contenido, datos)
            if escritos:
                db.guardar_solicitud(id_caso, solicitud)
                respuesta += "\n\nActualicé: " + ", ".join(escritos) + "."
            else:
                respuesta += "\n\nNo reemplacé textos que ya eran más completos."
        append_chat(id_caso, "agente", respuesta)
        return

    vacios = _campos_vacios(contenido)
    if not vacios:
        append_chat(
            id_caso,
            "agente",
            "El análisis, el alcance, las restricciones, los criterios y la recomendación ya están escritos. "
            "El modelo local no los sustituye. Si quiere un cambio, pídalo en el chat.",
        )
        return
    try:
        datos = _json_de(
            _pedir(
                "Completa solo los campos vacíos de un requerimiento. Solo JSON. "
                "Clasifica capacitacion, defecto o hueco. No inventes columnas ni fragmentos SQL. "
                '{"clasificacion":"defecto","respuesta":"...","analisis":"","alcance":"","restricciones":"","criteriosAceptacion":"","recomendacion":""}',
                f"MOTIVO: {motivo}\nCONTEXTO:\n{contexto}",
                480,
            )
        )
    except (ValueError, json.JSONDecodeError, urllib.error.URLError, TimeoutError, OSError):
        datos = {}
    escritos = _aplicar_vacios(contenido, datos)
    if escritos:
        meta = contenido.get("criteriosMeta") if isinstance(contenido.get("criteriosMeta"), dict) else {}
        meta["fuente"] = "agente-local"
        contenido["criteriosMeta"] = meta
        db.guardar_solicitud(id_caso, solicitud)
    respuesta = str(datos.get("respuesta") or "").strip()
    if not respuesta:
        respuesta = "Revisé el requerimiento contra la ficha del proceso."
    if escritos:
        respuesta += "\n\nCompleté campos que estaban vacíos: " + ", ".join(escritos) + ". No generé el dictamen HTML."
    else:
        respuesta += "\n\nNo completé campos: el modelo no devolvió texto suficiente, o ya estaban escritos."
    append_chat(id_caso, "agente", respuesta)


def _trabajar(agente_id: str, id_caso: str, motivo: str) -> None:
    from cursor_bot import _now

    stop = threading.Event()

    def latido() -> None:
        while not stop.wait(5):
            write_bot(id_caso, heartbeatEn=_now())

    threading.Thread(target=latido, daemon=True).start()
    try:
        if not _ollama_vivo():
            write_bot(id_caso, estado="error", error="Ollama no está en ejecución.", terminadoEn=_now())
            append_chat(id_caso, "sistema", "Ollama no está en ejecución. Ábralo y vuelva a enviar el mensaje.")
            return
        if agente_id == "analista":
            _analizar_caso(id_caso, motivo)
        elif agente_id == "documentar":
            _documentar()
        else:
            _responder_consulta("consultas")
        write_bot(id_caso, estado="listo", error="", terminadoEn=_now(), modelo=_modelo())
    except Exception as exc:
        write_bot(id_caso, estado="error", error=str(exc), terminadoEn=_now())
        append_chat(id_caso, "sistema", "El agente local no pudo terminar: " + str(exc))
    finally:
        stop.set()


def lanzar(agente_id: str, id_caso: str, motivo: str) -> dict:
    from cursor_bot import _now, _segundos_desde

    actual = leer_estado_bot(id_caso)
    hace = _segundos_desde(actual.get("heartbeatEn"))
    if (
        actual.get("estado") == "trabajando"
        and pid_vivo(actual.get("pid"))
        and hace is not None
        and hace < 15
    ):
        return {"ok": True, "yaCorria": True, "pid": actual.get("pid"), "estado": "trabajando"}
    write_bot(
        id_caso,
        estado="trabajando",
        pid=os.getpid(),
        motivo="agente-local",
        modelo=_modelo(),
        iniciadoEn=_now(),
        heartbeatEn=_now(),
        error="",
        terminadoEn=None,
    )
    threading.Thread(target=_trabajar, args=(agente_id, id_caso, motivo), daemon=True).start()
    return {"ok": True, "pid": os.getpid(), "estado": "trabajando", "local": True, "modelo": _modelo()}
