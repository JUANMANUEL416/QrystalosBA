"""Cola de análisis posterior: guarda el caso y lo analiza después, uno por uno.

No relanza un REQ ya cerrado (sin análisis, fase 1 cerrada o correo enviado).
Topes: tamaño del prompt (config/topes_modelo.json) e intentos (máx. 2). Sin cupo diario.
"""
from __future__ import annotations

import threading
import time
from datetime import datetime

_lock = threading.Lock()
_thread: threading.Thread | None = None
_generando: set[str] = set()
_gen_diagrama = None
_gen_mockup = None
_EN_CADENA = {"ubicar-req", "analizar-req", "material", "mockup-ventana", "presentacion"}
_MOTIVOS_MODELO = _EN_CADENA
_NOTA_CIERRE = {
    "sin_analisis": "Cerrado sin análisis. No se relanza el agente.",
    "correo_enviado": "Fase 1 ya cerrada y el correo ya salió. No se relanza el agente.",
    "ausente_en_lista": "Salió de la lista de avalasesor. No se relanza el agente.",
}


def registrar_generadores(diagrama, mockup) -> None:
    """El servidor registra cómo armar el flujo y el mockup del dictamen."""
    global _gen_diagrama, _gen_mockup
    _gen_diagrama = diagrama
    _gen_mockup = mockup


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _hoy() -> str:
    return datetime.now().date().isoformat()


def limites() -> dict:
    try:
        import orquesta

        return orquesta.limites_segundo_plano()
    except Exception:
        return {"maxSinError": 2, "maxConError": 2, "maxCasosPorDia": 0, "maxTurnosPorCaso": 0}


def motivo_cierre(item: dict, estado: dict | None) -> str:
    """Por qué este REQ no debe gastar otro turno. Vacío si todavía está abierto."""
    estado = estado or {}
    item = item or {}
    reabierto = bool(estado.get("enmiendaAbierta")) and not estado.get("fase1Cerrada")
    reanalisis = bool(item.get("reanalisisPedido"))
    # Reanálisis solo con caso reabierto y el botón «Volver a analizar».
    if reabierto and reanalisis:
        return ""
    if estado.get("analisisCompletado") and not reanalisis:
        if reabierto:
            return (
                "Caso reabierto. Pulse Volver a analizar para limpiar la sesión "
                "y arrancar de nuevo."
            )
        return (
            "El análisis ya está completo: plan, mockup y dictamen. "
            "Para repetirlo, reabra el caso y use Volver a analizar."
        )
    if reabierto:
        # Reabierto sin análisis completo: puede seguir el análisis normal.
        return ""
    por = str(item.get("terminadoPor") or "")
    if por in _NOTA_CIERRE:
        return _NOTA_CIERRE[por]
    if estado.get("fase1Cerrada"):
        return "Fase 1 ya cerrada. No se relanza el agente."
    return ""


def decision_posterior(item: dict, estado: dict | None, lanzados: int = 0, max_casos: int = 0) -> str:
    """omitir o lanzar. Sin cupo diario: el freno es cierre + intentos."""
    if motivo_cierre(item, estado):
        return "omitir"
    try:
        import topes_modelo

        intentos = int((item or {}).get("analisisPosteriorIntentos") or 0)
        err = str((item or {}).get("analisisPosteriorError") or "")
        # Reanálisis pedido reinicia el cupo de intentos.
        if (item or {}).get("reanalisisPedido") and intentos:
            intentos = 0
        ver = topes_modelo.decision_intento(intentos, err)
        if not ver.get("ok"):
            return "omitir"
    except Exception:
        return "omitir"
    return "lanzar"


def freno_modelo(id_caso: str, motivo: str, turnos_hoy: int = 0) -> str:
    """Texto si este turno de modelo no debe arrancar. Vacío si puede seguir."""
    if motivo not in _MOTIVOS_MODELO:
        return ""
    db = _db()
    item = {}
    for it in db.get_cola():
        if _caso(it) == id_caso:
            item = it
            break
    estado = db.get_estado(id_caso) if id_caso else {}
    razon = motivo_cierre(item, estado)
    if razon:
        return razon + " No se abre otro turno."
    try:
        import topes_modelo

        intentos = int(item.get("analisisPosteriorIntentos") or 0)
        if item.get("reanalisisPedido"):
            intentos = 0
        ver = topes_modelo.decision_intento(
            intentos, str(item.get("analisisPosteriorError") or "")
        )
        if not ver.get("ok"):
            return str(ver.get("mensaje") or "Tope de intentos del segundo plano.")
    except Exception:
        return "No se pudo leer el tope de tokens. El turno no se abre."
    return ""


def _req(item: dict) -> str:
    return str(item.get("idReqSeleccionado") or (item.get("parsed") or {}).get("idReq") or "").strip()


def _caso(item: dict) -> str:
    return str((item.get("parsed") or {}).get("idCaso") or item.get("idCaso") or "").strip()


def _db():
    from qrystalos_ba_db import get_db

    return get_db()


def _segundos(iso: str) -> int | None:
    try:
        t0 = datetime.fromisoformat(str(iso))
    except ValueError:
        return None
    return max(0, int((datetime.now() - t0).total_seconds()))


def _asentar(id_caso: str, bot: dict) -> str:
    """terminado, error o esperar. No cierra mientras la cadena sigue."""
    estado = str(bot.get("estado") or "")
    if estado in ("error", "sin_clave"):
        return "error"
    if estado != "listo":
        return "esperar"
    from cursor_bot import pid_vivo

    if pid_vivo(bot.get("pid")):
        return "esperar"
    if bot.get("ubicacionDetenida"):
        return "error"
    # Un tope de prompt o de intentos deja el bot en listo. No es el fin de la cadena:
    # no se espera el siguiente turno ni se arma diagrama ni mockup.
    corte = str(bot.get("corte") or "")
    if corte in ("peso", "limite") or isinstance(bot.get("pesoBloqueo"), dict):
        return "corte"
    motivo = str(bot.get("motivo") or "")
    if _turno_siguiente(id_caso, motivo):
        hace = _segundos(str(bot.get("terminadoEn") or ""))
        # El siguiente turno reescribe el bot. Si este motivo sigue vigente, aún no arrancó.
        if hace is None or hace < 90:
            return "esperar"
    return "terminado"


def _turno_siguiente(id_caso: str, motivo: str) -> bool:
    """Hay otro turno de agente después de este. «armar» corre en el mismo proceso."""
    if motivo == "ubicar-req":
        return True
    try:
        import orquesta
    except Exception:
        return motivo in ("analizar-req", "material", "mockup-ventana")
    if motivo == "analizar-req":
        return bool(orquesta.siguiente(motivo))
    if motivo in ("material", "mockup-ventana", "presentacion"):
        nxt = orquesta.avanzar(id_caso, motivo)
        return bool(nxt and nxt != "armar")
    return False


def _armar_documento(id_caso: str) -> str:
    """Genera el flujo y el mockup y los deja en el dictamen. Devuelve el aviso, si falló algo."""
    fallos = []
    if _gen_diagrama:
        try:
            _gen_diagrama(id_caso, "")
        except Exception as exc:
            fallos.append("flujo: " + str(exc))
    if _gen_mockup:
        try:
            _gen_mockup(id_caso, "")
        except Exception as exc:
            fallos.append("mockup: " + str(exc))
    return " ".join(fallos)


def podar_cerrados() -> int:
    """Saca de la cola de segundo plano los REQ que ya están cerrados. No lanza agente."""
    from cursor_bot import leer_estado_bot, pid_vivo

    avisos: list[tuple[str, str]] = []
    with _lock:
        db = _db()
        items = db.get_cola()
        for item in items:
            if item.get("analisisPosterior") not in ("en_cola", "en_proceso"):
                continue
            id_caso = _caso(item)
            estado = db.get_estado(id_caso) if id_caso else {}
            razon = motivo_cierre(item, estado)
            if not razon:
                continue
            if item.get("analisisPosterior") == "en_proceso" and id_caso:
                bot = leer_estado_bot(id_caso)
                if bot.get("estado") == "trabajando" and pid_vivo(bot.get("pid")):
                    continue
            item["analisisPosterior"] = "omitido"
            item["analisisPosteriorNota"] = razon
            item["analisisPosteriorFin"] = _now()
            item.pop("analisisPosteriorError", None)
            if id_caso:
                avisos.append((id_caso, razon))
        if avisos:
            db.save_cola(items)
    db = _db()
    for id_caso, razon in avisos:
        db.append_chat(
            id_caso,
            {
                "id": datetime.now().strftime("%Y%m%d%H%M%S%f") + "o",
                "autor": "sistema",
                "texto": "Análisis posterior detenido. " + razon,
                "fecha": _now(),
            },
        )
    return len(avisos)


def estado_limite() -> dict:
    lim = limites()
    items = _db().get_cola()
    en_cola = sum(1 for i in items if i.get("analisisPosterior") == "en_cola")
    en_proc = sum(1 for i in items if i.get("analisisPosterior") == "en_proceso")
    tope_intentos = int(lim.get("maxSinError") or 2)
    bloqueados = sum(
        1
        for i in items
        if i.get("analisisPosterior") in ("en_cola", "error")
        and int(i.get("analisisPosteriorIntentos") or 0) >= tope_intentos
        and not i.get("reanalisisPedido")
    )
    return {
        "fecha": _hoy(),
        "enCola": en_cola,
        "enProceso": en_proc,
        "maxIntentos": tope_intentos,
        "bloqueadosPorIntentos": bloqueados,
        "maxCasosPorDia": 0,
        "maxTurnosPorCaso": 0,
        "pausado": False,
        "nota": "Sin tope diario. Freno: tamaño del prompt + máx. 2 intentos por REQ.",
    }


def sincronizar_estados() -> bool:
    """Pasa a terminado o error lo que el agente ya cerró. Arma flujo y mockup al cerrar."""
    podar_cerrados()
    from cursor_bot import leer_estado_bot

    listos: list[str] = []
    with _lock:
        db = _db()
        items = db.get_cola()
        cambio = False
        for item in items:
            if item.get("analisisPosterior") != "en_proceso":
                continue
            id_caso = _caso(item)
            if not id_caso:
                continue
            bot = leer_estado_bot(id_caso)
            inicio = str(item.get("analisisPosteriorEn") or "")
            iniciado = str(bot.get("iniciadoEn") or "")
            if inicio and iniciado and iniciado < inicio:
                continue
            veredicto = _asentar(id_caso, bot)
            if veredicto == "esperar" or id_caso in _generando:
                continue
            if veredicto == "error":
                item["analisisPosterior"] = "error"
                item["analisisPosteriorError"] = str(
                    bot.get("error") or "El agente no terminó el análisis"
                )
                item["analisisPosteriorFin"] = _now()
                cambio = True
                continue
            if veredicto == "corte":
                nota = str(bot.get("corteNota") or "")
                peso = bot.get("pesoBloqueo")
                if not nota and isinstance(peso, dict):
                    nota = str(peso.get("mensaje") or "")
                item["analisisPosterior"] = "omitido"
                item["analisisPosteriorNota"] = (
                    nota or "El turno se detuvo por el tope. No se arma el documento."
                )
                item["analisisPosteriorFin"] = _now()
                item.pop("analisisPosteriorError", None)
                cambio = True
                continue
            if item.get("analisisPosteriorDocs"):
                item["analisisPosterior"] = "terminado"
                item["analisisPosteriorFin"] = item.get("analisisPosteriorFin") or _now()
                cambio = True
                continue
            _generando.add(id_caso)
            listos.append(id_caso)
        if cambio:
            db.save_cola(items)
    for id_caso in listos:
        aviso = ""
        try:
            aviso = _armar_documento(id_caso)
        except Exception as exc:
            aviso = str(exc)
        with _lock:
            _generando.discard(id_caso)
            db = _db()
            items = db.get_cola()
            for item in items:
                if _caso(item) != id_caso or item.get("analisisPosterior") != "en_proceso":
                    continue
                item["analisisPosterior"] = "terminado"
                item["analisisPosteriorDocs"] = True
                item["analisisPosteriorFin"] = _now()
                if aviso:
                    item["analisisPosteriorError"] = aviso
                else:
                    item.pop("analisisPosteriorError", None)
            db.save_cola(items)
    return bool(listos)


def encolar(id_caso: str, id_req: str = "", proyecto: str = "", modulo: str = "") -> dict:
    id_caso = (id_caso or "").strip()
    id_req = (id_req or "").strip()
    if not id_caso:
        return {"ok": False, "error": "Falta el caso"}
    with _lock:
        db = _db()
        items = db.get_cola()
        hit = False
        for item in items:
            if (id_req and _req(item) == id_req) or _caso(item) == id_caso:
                item["analisisPosterior"] = "en_cola"
                item["analisisPosteriorEn"] = _now()
                item.pop("analisisPosteriorError", None)
                item.pop("analisisPosteriorFin", None)
                parsed = dict(item.get("parsed") or {})
                parsed["idCaso"] = parsed.get("idCaso") or id_caso
                if id_req:
                    parsed["idReq"] = parsed.get("idReq") or id_req
                if proyecto and not parsed.get("proyecto"):
                    parsed["proyecto"] = proyecto
                if modulo and not parsed.get("moduloNombre"):
                    parsed["moduloNombre"] = modulo
                item["parsed"] = parsed
                if id_req and not item.get("idReqSeleccionado"):
                    item["idReqSeleccionado"] = id_req
                hit = True
                break
        if not hit:
            items.append(
                {
                    "id": id_req or id_caso,
                    "archivoCola": "analisis-posterior",
                    "rutaCola": "",
                    "fechaCola": _now(),
                    "estado": "pendiente",
                    "ordenPagina": 10**9,
                    "parsed": {
                        "idReq": id_req,
                        "idCaso": id_caso,
                        "proyecto": proyecto,
                        "moduloNombre": modulo,
                        "aval": "",
                    },
                    "idReqSeleccionado": id_req,
                    "analisisPosterior": "en_cola",
                    "analisisPosteriorEn": _now(),
                }
            )
        db.save_cola(items)
        n = sum(1 for i in items if i.get("analisisPosterior") == "en_cola")
    return {"ok": True, "idCaso": id_caso, "enCola": n}


def _nota_archivos(id_caso: str, solicitud: dict) -> str:
    contenido = solicitud.get("contenido") if isinstance(solicitud.get("contenido"), dict) else {}
    nota = ""
    imgs = contenido.get("imagenesAnalisis") or []
    archs = contenido.get("archivosAnalisis") or []
    nombres = ", ".join((i.get("nombre") or "").strip() for i in imgs if (i.get("nombre") or "").strip())
    if nombres:
        nota += f" Hay capturas en activo/{id_caso}/imagenes/ ({nombres}). Léalas y contrástelas con el REQ."
    anombres = ", ".join((a.get("nombre") or "").strip() for a in archs if (a.get("nombre") or "").strip())
    if anombres:
        nota += (
            f" Hay normativa/archivos en activo/{id_caso}/archivos/ ({anombres}). "
            "Lea el .extracto.txt, compare con lo que genera el sistema y cite apartes en el dictamen (sección 4.6)."
        )
    return nota


def _lanzar_uno(id_caso: str) -> dict:
    import agentes_panel

    db = _db()
    solicitud = db.get_solicitud(id_caso) or {}
    ahora = _now()
    nota = _nota_archivos(id_caso, solicitud)
    db.append_chat(
        id_caso,
        {
            "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
            "autor": "coordinador",
            "texto": (
                "Análisis posterior. Analizar corre en dos pasos, sin otra acción suya. "
                "Paso 1: ubique el proceso de la base, el flujo dentro de ese proceso "
                "y la pieza (ventana, botón, proceso, SP o método), y qué recursos hacen falta. "
                "Paso 2: con eso, analice el problema y proponga el cambio. "
                "No nombre SP ni métodos que no participen en ese flujo."
                f"{nota}"
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
    return agentes_panel.lanzar("analista", id_caso, "ubicar-req")


def _marcar(id_caso: str, estado: str, error: str = "", inicio: str = "", nota: str = "", lanzado: bool = False) -> None:
    with _lock:
        db = _db()
        items = db.get_cola()
        for item in items:
            if _caso(item) != id_caso:
                continue
            item["analisisPosterior"] = estado
            if lanzado:
                item["analisisPosteriorLanzado"] = True
                if item.get("reanalisisPedido"):
                    item["analisisPosteriorIntentos"] = 1
                    item.pop("reanalisisPedido", None)
                else:
                    item["analisisPosteriorIntentos"] = int(item.get("analisisPosteriorIntentos") or 0) + 1
            if nota:
                item["analisisPosteriorNota"] = nota
            if error:
                item["analisisPosteriorError"] = error
                item["analisisPosteriorFin"] = _now()
                try:
                    import topes_modelo

                    item["analisisPosteriorErrorCom"] = topes_modelo.es_error_comunicacion(error)
                except Exception:
                    item["analisisPosteriorErrorCom"] = False
            elif estado == "en_proceso":
                item["analisisPosteriorEn"] = inicio or _now()
                item.pop("analisisPosteriorError", None)
                item.pop("analisisPosteriorFin", None)
            elif estado == "omitido":
                item["analisisPosteriorFin"] = _now()
                item.pop("analisisPosteriorError", None)
            else:
                item["analisisPosteriorEn"] = item.get("analisisPosteriorEn") or _now()
        db.save_cola(items)


def _paso() -> bool:
    """True si queda trabajo. Lanza como mucho un caso; freno por cierre o intentos."""
    sincronizar_estados()
    with _lock:
        db = _db()
        items = db.get_cola()
        if any(i.get("analisisPosterior") == "en_proceso" for i in items):
            return True
        pendiente = None
        for i in items:
            if i.get("analisisPosterior") != "en_cola":
                continue
            if decision_posterior(i, db.get_estado(_caso(i) or "")) != "lanzar":
                # Agota intentos: saca de la cola activa.
                if motivo_cierre(i, db.get_estado(_caso(i) or "")):
                    continue
                try:
                    import topes_modelo

                    ver = topes_modelo.decision_intento(
                        int(i.get("analisisPosteriorIntentos") or 0),
                        str(i.get("analisisPosteriorError") or ""),
                    )
                    if not ver.get("ok"):
                        i["analisisPosterior"] = "omitido"
                        i["analisisPosteriorNota"] = ver.get("mensaje") or "Tope de intentos."
                        i["analisisPosteriorFin"] = _now()
                        db.save_cola(items)
                except Exception:
                    pass
                continue
            pendiente = i
            break
        if not pendiente:
            return False
        id_caso = _caso(pendiente)
    if not id_caso:
        return True
    _marcar(id_caso, "en_proceso", lanzado=True)
    try:
        bot = _lanzar_uno(id_caso)
    except Exception as exc:
        _marcar(id_caso, "error", str(exc))
        return True
    if bot.get("detenido"):
        bloqueo = str(bot.get("bloqueo") or "")
        if bloqueo == "peso":
            nota = str((bot.get("peso") or {}).get("mensaje") or "El prompt supera el máximo. No se abre el turno.")
        elif bloqueo == "limite":
            nota = "Tope de intentos o caso cerrado. No se abre otro turno."
        else:
            nota = "El agente no arrancó: el caso ya está cerrado o llegó al tope."
        _marcar(id_caso, "omitido", nota=nota)
    elif not bot.get("ok"):
        _marcar(id_caso, "error", str(bot.get("error") or "El agente no arrancó"))
    elif bot.get("yaCorria"):
        from cursor_bot import leer_estado_bot

        iniciado = str(leer_estado_bot(id_caso).get("iniciadoEn") or "")
        if iniciado:
            _marcar(id_caso, "en_proceso", inicio=iniciado)
    return True


def _loop() -> None:
    while _paso():
        time.sleep(8)


def asegurar_worker() -> bool:
    global _thread
    podar_cerrados()
    with _lock:
        vivo = _thread is not None and _thread.is_alive()
        if vivo:
            return True
        items = _db().get_cola()
        if not any(i.get("analisisPosterior") in ("en_cola", "en_proceso") for i in items):
            return False
        _thread = threading.Thread(target=_loop, name="analisis-posterior", daemon=True)
        _thread.start()
        return True


def arrancar() -> dict:
    with _lock:
        items = _db().get_cola()
    n_cola = sum(1 for i in items if i.get("analisisPosterior") == "en_cola")
    n_proc = sum(1 for i in items if i.get("analisisPosterior") == "en_proceso")
    if not n_cola and not n_proc:
        return {"ok": True, "enCola": 0, "enProceso": 0, "arranco": False}
    asegurar_worker()
    return {"ok": True, "enCola": n_cola, "enProceso": n_proc, "arranco": True}


def resumen() -> dict:
    sincronizar_estados()
    items = _db().get_cola()
    return {
        "enCola": sum(1 for i in items if i.get("analisisPosterior") == "en_cola"),
        "enProceso": sum(1 for i in items if i.get("analisisPosterior") == "en_proceso"),
        "terminados": sum(1 for i in items if i.get("analisisPosterior") == "terminado"),
        "errores": sum(1 for i in items if i.get("analisisPosterior") == "error"),
        "omitidos": sum(1 for i in items if i.get("analisisPosterior") == "omitido"),
        "limite": estado_limite(),
    }
