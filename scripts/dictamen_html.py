# -*- coding: utf-8 -*-
"""Arma dictamenes/{id}.html con la plantilla oficial cuando el análisis ya está escrito.

El agente deja el planteamiento en solicitud.json. Este módulo pinta el dictamen.
No escribe el material de manual/guion (material/armado.html).
"""
from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLANTILLA = os.path.join(ROOT, "plantillas", "dictamen.html")
MARCA = "dictamen-oficina"

_CLASIF = {
    "capacitacion": "capacitación",
    "defecto": "defecto",
    "hueco": "hueco",
}


def _esc(texto) -> str:
    return (
        str(texto or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _publicar(texto: str) -> str:
    """El dictamen cita IXONLINE/SQL. No lleva rutas ni comandos de la oficina."""
    t = str(texto or "")
    t = re.sub(r"python\s+scripts/\S+", "", t)
    t = re.sub(r"\b(?:DESAIX|SQLIX)\b", "IXONLINE/SQL", t)
    t = re.sub(
        r"(?:activo|sql_refe)/[^\s<>\"']*?(SP[QK]_[A-Z0-9_]+)",
        r"IXONLINE/SQL · \1",
        t,
        flags=re.I,
    )
    t = re.sub(r"(?:activo|sql_refe|cola|mockups)/[^\s<>\"']+", "", t)
    t = re.sub(r"conocimiento/[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*", "el proceso documentado", t)
    return t


def _contenido(sol: dict) -> dict:
    contenido = sol.get("contenido") if isinstance(sol.get("contenido"), dict) else {}
    return contenido


def _planteamiento(sol: dict) -> dict:
    contenido = _contenido(sol)
    plan = contenido.get("planteamiento")
    if isinstance(plan, dict):
        return plan
    raiz = sol.get("planteamiento")
    return raiz if isinstance(raiz, dict) else {}


def _pick(sol: dict, *claves: str) -> str:
    contenido = _contenido(sol)
    for clave in claves:
        if contenido.get(clave):
            return str(contenido.get(clave))
        if sol.get(clave):
            return str(sol.get(clave))
    return ""


def _impacto(valor: str) -> tuple[str, str]:
    texto = (valor or "No").strip() or "No"
    bajo = texto.lower()
    if bajo in ("si", "sí"):
        return "Sí", "si"
    if bajo == "parcial":
        return "Parcial", "parcial"
    return "No", "no"


def _lineas(texto: str) -> list[str]:
    return [linea.strip(" -\t") for linea in str(texto or "").splitlines() if linea.strip()]


def _ul(items: list[str], checklist: bool = False) -> str:
    limpios = [item for item in items if item]
    if not limpios:
        limpios = ["Sin ítems adicionales."]
    clase = ' class="checklist"' if checklist else ""
    cuerpo = "".join(f"<li>{_esc(item)}</li>" for item in limpios)
    return f"<ul{clase}>{cuerpo}</ul>"


def _tabla(columnas: list[str], filas: list[list[str]]) -> str:
    head = "".join(f"<th>{_esc(col)}</th>" for col in columnas)
    body = []
    for fila in filas:
        celdas = "".join(f"<td>{_esc(celda)}</td>" for celda in fila)
        body.append(f"<tr>{celdas}</tr>")
    if not body:
        body.append(f'<tr><td colspan="{len(columnas)}">Sin objetos nombrados en el análisis.</td></tr>')
    return (
        "<table><thead><tr>"
        + head
        + "</tr></thead><tbody>"
        + "".join(body)
        + "</tbody></table>"
    )


def _analisis(sol: dict) -> str:
    plan = _planteamiento(sol)
    clas = _CLASIF.get(str(plan.get("clasificacion") or "").strip().lower(), "")
    partes = []
    if clas:
        partes.append("Clasificación: " + clas + ".")
    ya = _publicar(" ".join(_lineas_ya_existe(sol))).strip()
    if ya:
        partes.append("Lo que el proceso ya hace: " + ya)
    flujo = plan.get("flujoHoy") if isinstance(plan.get("flujoHoy"), list) else []
    pasos = [str(paso).strip() for paso in flujo if str(paso).strip()]
    if pasos:
        partes.append("Flujo de hoy:\n" + "\n".join(f"{i}. {paso}" for i, paso in enumerate(pasos, 1)))
    causa = str(plan.get("causa") or "").strip()
    analisis = _pick(sol, "analisis").strip()
    if causa and causa not in analisis:
        partes.append("Causa: " + causa)
    if analisis:
        partes.append(analisis)
    return _publicar("\n\n".join(partes) or "Pendiente de análisis.")


def _lineas_ya_existe(sol: dict) -> list[str]:
    plan = _planteamiento(sol)
    items = plan.get("yaExiste")
    lineas = []
    crudo = items if isinstance(items, list) else ([items] if isinstance(items, str) and items.strip() else [])
    for item in crudo:
        if isinstance(item, dict):
            hace = str(item.get("queHace") or "").strip()
            donde = str(item.get("donde") or "").strip()
            condicion = str(item.get("condicion") or "").strip()
            frase = hace
            if donde:
                frase = (frase + " Se hace en " + donde + ".").strip()
            if condicion:
                frase = (frase + " Condición: " + condicion).strip()
        else:
            frase = str(item or "").strip()
        if frase:
            lineas.append(frase)
    return lineas


def _palabras_simples(sol: dict) -> str:
    """Sección 5.0: primero el camino que el proceso ya tiene, después solo el tramo que falta."""
    hecho = _publicar(" ".join(_lineas_ya_existe(sol))).strip()
    gap = _negocio(sol)
    clas = str(_planteamiento(sol).get("clasificacion") or "").strip().lower()
    if hecho and clas == "capacitacion":
        return "Hoy el sistema ya lo hace. " + hecho
    if hecho and gap and gap not in hecho:
        return "Hoy el sistema ya lo hace. " + hecho + "\n\nAparte de ese camino: " + gap
    if hecho:
        return "Hoy el sistema ya lo hace. " + hecho
    return gap


def _negocio(sol: dict) -> str:
    plan = _planteamiento(sol)
    cambio = plan.get("cambio") if isinstance(plan.get("cambio"), dict) else {}
    return _publicar(
        str(cambio.get("negocio") or "").strip()
        or _pick(sol, "cambioPropuestoSimple").strip()
        or _pick(sol, "recomendacion").strip()
    )


def _objetos(sol: dict) -> str:
    plan = _planteamiento(sol)
    cambio = plan.get("cambio") if isinstance(plan.get("cambio"), dict) else {}
    contenido = _contenido(sol)
    filas = [
        ["Frontend", str(cambio.get("frontend") or "Sin cambio FE"), _impacto(contenido.get("impactoFe"))[0]],
        ["SQL Server", str(cambio.get("sql") or "Sin cambio SQL"), _impacto(contenido.get("impactoSql"))[0]],
        ["API / Backend", str(cambio.get("backend") or "Sin cambio API"), _impacto(contenido.get("impactoApi"))[0]],
    ]
    ubicacion = contenido.get("ubicacion") if isinstance(contenido.get("ubicacion"), dict) else {}
    for item in ubicacion.get("participan") or []:
        if not isinstance(item, dict):
            continue
        sp = str(item.get("sp") or "").strip()
        metodo = str(item.get("metodo") or "").strip()
        if sp:
            filas.append(["IXONLINE/SQL", f"{sp} · {metodo}".strip(" ·"), "Participa en el flujo"])
    tabla = _tabla(["Capa", "Objeto", "En este requerimiento"], filas)
    pasos = [str(paso).strip() for paso in (plan.get("flujoHoy") or []) if str(paso).strip()]
    if not pasos:
        return tabla
    traza = _tabla(
        ["Paso", "Qué ocurre hoy"],
        [[str(i), paso] for i, paso in enumerate(pasos, 1)],
    )
    return tabla + "<h3>Trazabilidad del flujo de hoy</h3>" + traza


def _bloque_capa(titulo_vacio: str, texto: str, impacto: str) -> str:
    cuerpo = _publicar(texto).strip()
    if impacto == "No" or not cuerpo or cuerpo.lower().startswith("sin cambio"):
        return f'<div class="content-block">{_esc(titulo_vacio)}</div>'
    return f'<div class="content-block">{_esc(cuerpo)}</div>'


def _sql_spec(sol: dict) -> str:
    sql = _publicar(_pick(sol, "cambioPropuestoSql")).strip()
    if len(sql) < 40:
        return ""
    return (
        "<h3>5.2.1 Fragmentos SQL (especificación)</h3>"
        "<p>Especificación para el desarrollador. No se ejecuta desde este documento. "
        "Fuente: IXONLINE/SQL.</p>"
        f'<pre class="sql-spec">{_esc(sql)}</pre>'
    )


def _contabilidad(sol: dict) -> tuple[str, str]:
    cont = _contenido(sol).get("contabilidad")
    if not isinstance(cont, dict) or not cont.get("afecta"):
        return "No", ""
    partes = []
    como = str(cont.get("comoAfecta") or "").strip()
    desarrollo = str(cont.get("desarrollo") or "").strip()
    validacion = cont.get("validacion") if isinstance(cont.get("validacion"), dict) else {}
    texto_val = str(validacion.get("texto") or "").strip()
    if como:
        partes.append("<h3>Cómo lo afecta</h3>" + f'<div class="content-block">{_esc(_publicar(como))}</div>')
    if desarrollo:
        partes.append("<h3>Desarrollo contable</h3>" + f'<div class="content-block">{_esc(_publicar(desarrollo))}</div>')
    if texto_val:
        partes.append(
            "<h3>Validación del agente</h3>" + f'<div class="content-block">{_esc(_publicar(texto_val))}</div>'
        )
    return "Sí", "".join(partes)


def _normativa(sol: dict, id_caso: str) -> str:
    archivos = _contenido(sol).get("archivosAnalisis") or []
    if not isinstance(archivos, list) or not archivos:
        return "No se adjuntó resolución, circular ni anexo técnico."
    bloques = []
    carpeta = os.path.join(ROOT, "activo", id_caso, "archivos") if id_caso else ""
    for arch in archivos:
        if not isinstance(arch, dict):
            continue
        nombre = str(arch.get("nombre") or "Archivo").strip()
        tipo = str(arch.get("tipo") or "Normativa").strip()
        extracto_nombre = os.path.basename(str(arch.get("extracto") or arch.get("extractoRuta") or ""))
        texto = ""
        if carpeta and extracto_nombre and ".." not in extracto_nombre:
            path = os.path.join(carpeta, extracto_nombre)
            if os.path.isfile(path):
                try:
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        texto = fh.read(1800).strip()
                except OSError:
                    texto = ""
        if texto:
            bloques.append(f"{tipo}: {nombre}\n{texto}")
        else:
            bloques.append(f"{tipo}: {nombre}\nSe adjuntó el archivo. No hay extracto para citar un artículo.")
    return _publicar("\n\n".join(bloques))


def _diagrama(sol: dict) -> str:
    try:
        import copy
        import diagrama_flujo

        copia = copy.deepcopy(sol)
        sql = copia.get("sql") if isinstance(copia.get("sql"), dict) else {}
        copia["sql"] = sql
        if not str(sql.get("procesoId") or "").strip():
            ubicacion = _contenido(sol).get("ubicacion")
            if isinstance(ubicacion, dict) and ubicacion.get("procesoId"):
                sql["procesoId"] = ubicacion.get("procesoId")
        ctx = diagrama_flujo.contexto_caso(copia)
        return _publicar(diagrama_flujo.render_fragmento(ctx))
    except Exception:
        return _diagrama_simple(sol)


def _diagrama_simple(sol: dict) -> str:
    plan = _planteamiento(sol)
    pasos = [str(paso).strip() for paso in (plan.get("flujoHoy") or []) if str(paso).strip()]
    if not pasos:
        return "<p>No se generó diagrama para este requerimiento.</p>"
    nodos = []
    for i, paso in enumerate(pasos):
        if i:
            nodos.append('<div class="df-arrow">→</div>')
        nodos.append(
            f'<div class="df-node"><div class="k">Paso {i + 1}</div><div class="d">{_esc(_publicar(paso))}</div></div>'
        )
    return (
        '<div class="diagrama-incrustado">'
        '<p class="df-meta">Recorrido tomado del análisis. No se generó un diagrama aparte.</p>'
        '<div class="df-flow">' + "".join(nodos) + "</div></div>"
    )


def _criterios(sol: dict) -> list[str]:
    plan = _planteamiento(sol)
    lista = plan.get("criterios") if isinstance(plan.get("criterios"), list) else []
    items = [str(item).strip() for item in lista if str(item).strip()]
    if len(items) >= 2:
        return items
    return _lineas(_pick(sol, "criteriosAceptacion", "criterios")) or items


def _pruebas(sol: dict) -> tuple[str, str, str]:
    contenido = _contenido(sol)
    plan = _planteamiento(sol)
    cambio = plan.get("cambio") if isinstance(plan.get("cambio"), dict) else {}
    criterios = [_publicar(item) for item in _criterios(sol)]
    fe, sql, api = (
        _impacto(contenido.get("impactoFe"))[0],
        _impacto(contenido.get("impactoSql"))[0],
        _impacto(contenido.get("impactoApi"))[0],
    )
    no_cambia = _publicar(str(plan.get("noCambia") or "")).strip()
    dev = ["Lint del cambio en la rama del ticket, con datos límite del escenario."]
    if fe != "No":
        dev.append("Recorrer la pantalla y la condición del flujo de hoy, con y sin permiso.")
    if sql != "No":
        dev.append(
            "Contrastar el bloque sugerido con IXONLINE/SQL en preversión. "
            "El fragmento es especificación: no se ejecuta desde este documento."
        )
    if api != "No":
        dev.append("Verificar MODELO y METODO del llamado, sin cambiar el contrato de los vecinos.")
    dev.extend("Comprobar: " + item for item in criterios)
    if no_cambia:
        dev.append("Regresión: no cambia " + no_cambia + ".")

    coord = [
        "Contrastar el resultado con el requerimiento del cliente.",
        "Happy path del flujo de hoy y un borde del criterio.",
    ]
    coord.extend(criterios)
    coord.append("Criterio de salida: el caso queda listo para soporte cuando esos puntos se cumplen en la copia de prueba.")

    proyecto = sol.get("proyecto") if isinstance(sol.get("proyecto"), dict) else {}
    ruta = str(proyecto.get("rutaPantalla") or proyecto.get("modulo") or "la pantalla del requerimiento").strip()
    soporte = [
        f"Ruta de pantalla: {ruta}.",
        "Solo lectura sobre datos del cliente, salvo el escenario que el requerimiento pide reproducir.",
        "Rollback: volver a la versión anterior del objeto de este cambio y escalar a L3 si el escenario no se reproduce.",
    ]
    return _ul(dev, True), _ul(coord, True), _ul([_publicar(item) for item in soporte], True)


def _consideraciones(sol: dict) -> str:
    plan = _planteamiento(sol)
    items = []
    alcance = _publicar(_pick(sol, "alcance")).strip()
    restricciones = _publicar(_pick(sol, "restricciones")).strip()
    no_cambia = _publicar(str(plan.get("noCambia") or "")).strip()
    if alcance:
        items.append("Alcance: " + alcance)
    if restricciones:
        items.append("Restricciones: " + restricciones)
    if no_cambia:
        items.append("No cambia: " + no_cambia)
    if not items:
        items.append("Respetar el flujo ubicado. No extender el cambio a otro control del módulo.")
    return _ul(items)


def render(sol: dict, id_caso: str = "") -> str:
    """HTML del dictamen. sol es la solicitud del caso."""
    if not isinstance(sol, dict):
        sol = {}
    ident = sol.get("identificacion") if isinstance(sol.get("identificacion"), dict) else {}
    proyecto = sol.get("proyecto") if isinstance(sol.get("proyecto"), dict) else {}
    gestion = sol.get("gestion") if isinstance(sol.get("gestion"), dict) else {}
    contenido = _contenido(sol)
    id_caso = id_caso or str(ident.get("idCaso") or "").strip()
    titulo = str(contenido.get("titulo") or ident.get("idReq") or id_caso or "Dictamen").strip()
    fe_txt, fe_cls = _impacto(contenido.get("impactoFe"))
    api_txt, api_cls = _impacto(contenido.get("impactoApi"))
    sql_txt, sql_cls = _impacto(contenido.get("impactoSql"))
    cont_txt, cont_html = _contabilidad(sol)
    plan = _planteamiento(sol)
    cambio = plan.get("cambio") if isinstance(plan.get("cambio"), dict) else {}
    negocio = _negocio(sol)
    recomendacion = _publicar(_pick(sol, "recomendacion")).strip()
    resumen = recomendacion if len(recomendacion) > len(negocio) else negocio
    dev, coord, soporte = _pruebas(sol)
    validar = contenido.get("validarAntes") if isinstance(contenido.get("validarAntes"), dict) else {}
    ticket = str(gestion.get("ticket") or "").strip()
    rama = str(gestion.get("rama") or "").strip()
    ticket_rama = " · ".join(parte for parte in (ticket, rama) if parte) or "—"
    fecha = str(ident.get("fecha") or "")[:10] or "—"

    with open(PLANTILLA, encoding="utf-8") as fh:
        html = fh.read()
    html = re.sub(
        r"<!-- Si afecta=Sí, CONTABILIDAD_DETALLE.*?\-->\s*",
        "",
        html,
        count=1,
        flags=re.S,
    )
    if not validar.get("aplica"):
        html = re.sub(r"\s*<section id=\"validar-antes\">.*?</section>", "", html, count=1, flags=re.S)

    valores = {
        "TITULO": _esc(_publicar(titulo)),
        "ID": _esc(id_caso or "—"),
        "CLIENTE": _esc(str(proyecto.get("nombre") or "—")),
        "MODULO": _esc(str(proyecto.get("modulo") or "—")),
        "FECHA": _esc(fecha),
        "ESTADO": _esc(str(gestion.get("estado") or "Propuesto")),
        "TICKET_RAMA": _esc(ticket_rama),
        "REQUERIMIENTO_CLIENTE": _esc(_publicar(_pick(sol, "requerimiento", "necesidad") or "—")),
        "ANALISIS_COORDINADOR": _esc(_analisis(sol)),
        "VALIDAR_ANTES_TEXTO": _esc(_publicar(str(validar.get("texto") or ""))),
        "CONTABILIDAD_AFECTA": _esc(cont_txt),
        "CONTABILIDAD_DETALLE": cont_html,
        "IMPACTO_FE": _esc(fe_txt),
        "IMPACTO_FE_CLASS": fe_cls,
        "IMPACTO_API": _esc(api_txt),
        "IMPACTO_API_CLASS": api_cls,
        "IMPACTO_SQL": _esc(sql_txt),
        "IMPACTO_SQL_CLASS": sql_cls,
        "RESUMEN_EJECUTIVO": _esc(resumen or negocio or "—"),
        "TABLA_IMPACTADOS": _objetos(sol),
        "DIAGRAMA_FLUJO": _diagrama(sol),
        "NORMATIVA_ADJUNTOS": _esc(_normativa(sol, id_caso)),
        "CAMBIOS_EN_PALABRAS_SIMPLES": _esc(_palabras_simples(sol) or "—"),
        "CAMBIOS_FRONTEND": _bloque_capa("No hay cambio en el frontend.", str(cambio.get("frontend") or ""), fe_txt),
        "CAMBIOS_SQL": _bloque_capa("No hay cambio en IXONLINE/SQL.", str(cambio.get("sql") or ""), sql_txt),
        "CAMBIOS_SQL_CODIGO": _sql_spec(sol),
        "CAMBIOS_BACKEND": _bloque_capa("No hay cambio de API.", str(cambio.get("backend") or ""), api_txt),
        "CONSIDERACIONES": _consideraciones(sol),
        "PRUEBAS_DESARROLLADOR": dev,
        "PRUEBAS_COORDINADOR": coord,
        "PRUEBAS_SOPORTE": soporte,
    }
    for clave, valor in valores.items():
        html = html.replace("{{" + clave + "}}", valor)
    if "{{" in html:
        html = re.sub(r"\{\{[A-Z0-9_]+\}\}", "", html)
    if MARCA not in html:
        html = html.replace("<head>", f"<head>\n  <!-- {MARCA} -->", 1)
    return html


def _id_seguro(id_caso: str) -> str:
    limpio = str(id_caso or "").strip()
    if not limpio or "/" in limpio or "\\" in limpio or ".." in limpio:
        return ""
    return limpio


def generar(id_caso: str, sol: dict | None = None, dest_dir: str | None = None, reemplazar: bool = False) -> dict:
    """Escribe el dictamen si el planteamiento ya cierra. No pisa un HTML escrito a mano."""
    id_caso = _id_seguro(id_caso)
    if not id_caso:
        return {"ok": False, "motivo": "id"}
    if sol is None:
        import cursor_bot

        sol = cursor_bot.read_json(os.path.join(cursor_bot.caso_dir(id_caso), "solicitud.json"), {})
    if not isinstance(sol, dict):
        return {"ok": False, "motivo": "solicitud"}
    try:
        import planteamiento_req

        if not planteamiento_req.evaluar(sol, modo="analisis").get("ok"):
            return {"ok": False, "motivo": "planteamiento"}
    except Exception:
        return {"ok": False, "motivo": "planteamiento"}

    carpeta = dest_dir or os.path.join(ROOT, "dictamenes")
    os.makedirs(carpeta, exist_ok=True)
    destino = os.path.join(carpeta, f"{id_caso}.html")
    if os.path.isfile(destino) and not reemplazar:
        try:
            with open(destino, encoding="utf-8") as fh:
                previo = fh.read(800)
        except OSError:
            previo = ""
        if MARCA not in previo:
            return {"ok": False, "motivo": "ya_existe", "ruta": f"dictamenes/{id_caso}.html"}

    html = render(sol, id_caso)
    anterior = ""
    if os.path.isfile(destino):
        try:
            with open(destino, encoding="utf-8") as fh:
                anterior = fh.read()
        except OSError:
            anterior = ""
    if anterior == html:
        return {"ok": True, "sinCambio": True, "ruta": f"dictamenes/{id_caso}.html"}
    with open(destino, "w", encoding="utf-8") as fh:
        fh.write(html)
    return {
        "ok": True,
        "sinCambio": False,
        "actualizado": bool(anterior),
        "ruta": f"dictamenes/{id_caso}.html",
    }
