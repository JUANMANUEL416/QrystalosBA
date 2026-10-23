#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contrato del planteamiento de un requerimiento y revisión de que no quede en resumen.

Lo usa el prompt de analizar-req y un control al cerrar el turno: si falta el flujo
de hoy, la causa o el bloque que cambia, el caso no se da por listo.
"""
from __future__ import annotations

import re

CLASIFICACIONES = ("capacitacion", "defecto", "hueco")
TIPOS_PIEZA = ("ventana", "boton", "proceso", "sp", "metodo")
TIPOS_RECURSO = ("ventana", "codigo", "sp", "pregunta", "normativa")

_GENERICAS = (
    "ajustar el proceso",
    "realizar los cambios necesarios",
    "se debe revisar",
    "hacer el ajuste correspondiente",
    "revisar y corregir",
    "realizar el ajuste",
)


def contrato_ubicacion() -> str:
    """Paso interno 1: ubicar el flujo. Sin llaves, para incrustarlo en el prompt."""
    return """PASO 1 DE 2 — UBICAR. No analice el problema y no proponga el cambio.
El coordinador no interviene entre este paso y el siguiente.

Escriba solicitud.json → contenido.ubicacion, en este orden:
1. procesoId: un solo id de la base (por ejemplo inventario). No deje dos módulos.
2. flujo: una fila del MAPA PARA UBICAR (el id del tramo). Si la fila dice RUTA, ese es el flujo. No use el módulo entero ni un tramo cuya pantalla es otra.
3. pieza.tipo: ventana, boton, proceso, sp o metodo. pieza.nombre: cómo se llama esa pieza.
4. recursos: lo que hace falta para analizar ESA pieza, nada más. Cada recurso tiene tipo y cual.
   - ventana: la pantalla.
   - codigo: el Vue o el componente de esa pantalla.
   - sp: el procedimiento de esta pieza (en cual va el nombre).
   - pregunta: un dato que solo el analista puede responder.
   - normativa: la norma adjunta, si el pedido la cita.
5. participan: solo el SP y el METODO de este flujo. Si el recurso no es un SP, déjela vacía. No copie métodos de otro flujo del mismo módulo.
6. estado y bloqueo:
   - listo y bloqueo vacío: el mapa ya trae el tramo o la pantalla.
   - pregunta y bloqueo dato: el proceso está mapeado y solo falta un dato del analista (la ruta, el tramo o una respuesta). Escriba preguntas. Al responder, el análisis continúa.
   - sin_mapa y bloqueo base: el proceso o la pantalla no están en la base, o el proceso no tiene mapa de tramos. No analice. Pida mapearlo en Documentar antes de seguir.

También deje sql.procesoId igual a procesoId.

No escriba analisis, recomendacion, criteriosAceptacion ni cambioPropuestoSql en este paso.
En el Chat, una línea: proceso → flujo → pieza → recursos.
"""


def contrato_prompt(modo: str = "analisis") -> str:
    """Texto para el agente. Sin llaves: se incrusta en un prompt con formato."""
    donde = (
        "planteamiento, en la raíz de solicitud.json"
        if modo == "comite"
        else "solicitud.json, contenido.planteamiento"
    )
    criterios = "criterios" if modo == "comite" else "criteriosAceptacion"
    return f"""PLANTEAMIENTO (obligatorio; un resumen de una frase no cierra el turno):
Escriba {donde} con estos datos, y el mismo contenido en los campos de texto:
- clasificacion: capacitacion, defecto o hueco. Sale de lo que el proceso ya hace, no del texto del pedido.
- yaExiste: lista de lo que el control ya hace y toca este pedido. Cada ítem tiene donde (pantalla y botón), condicion y queHace. Cópielo de las necesidades ya cubiertas y de la ficha, con la condición y el método. Si ninguna coincide, el ítem dice qué caminos revisó y por qué no cubren el pedido.
- flujoHoy: empieza por ese camino que ya existe. Después, pantalla y botón o estado; MODELO y METODO; procedimiento y qué hace ese tramo; tabla o salida. El síntoma del ticket no es el flujo de hoy.
- causa: la condición que falla o falta, citada de la ficha (procedimiento y METODO) o del bloque SQL leído. Si es capacitación, la ruta y la condición del camino que ya existe. No escriba «sale vacío», «no se envía» o «no puede reportar» si la ficha dice que ese envío ya ocurre.
- cambio.negocio: primero lo que la pantalla ya hace (el camino de yaExiste). Después, solo el tramo que la ficha muestra que todavía falta. Sin nombres de procedimiento. CUFE de la DIAN, CUV del Ministerio y radicación son caminos distintos: si la nota ya se envía a la DIAN y el CUFE se genera, eso queda en el flujo de hoy y no se vuelve a proponer.
- cambio.frontend: archivo Vue y condición, o «Sin cambio FE».
- cambio.sql: objeto, METODO y qué bloque cambia, o «Sin cambio SQL».
- cambio.backend: MODELO y METODO, o «Sin cambio API».
- noCambia: el camino vecino que no se toca.
- criterios: al menos dos. Cada uno dice el caso y el resultado que se puede comprobar.

Vuelque eso en el formulario: analisis (flujo de hoy y causa, no una paráfrasis del pedido), recomendacion (cambio por capa), cambioPropuestoSimple (el negocio), {criterios} (un criterio por línea), alcance y restricciones.

Profundidad, sin barrer la base:
1. Clasifique después de ver todos los caminos del control, incluidas las necesidades ya cubiertas (dónde, condición y método). No se quede con las casillas del formulario, la captura ni el texto del pedido. Si ese camino ya envía, genera o valida, la clasificación de esa parte es capacitación y el cambio no la vuelve a construir.
2. Abra la ficha completa del METODO de este cambio (hace, valida, noValida, errores, llama, efecto). El recorte del contexto no alcanza para redactar el cambio.
3. Si el cambio es SQL (defecto o hueco, impacto Sí o Parcial): lea el cuerpo de ESE METODO en la carpeta del caso o bájelo, y escriba cambioPropuestoSql con ---ANTES--- (el bloque de hoy) y ---SUGERIDO--- (el bloque propuesto), más una consulta de comprobación. No invente el SQL desde el resumen de la ficha. Una ficha en estado leido sirve para clasificar; no reemplaza el bloque.
4. Si el cambio es de pantalla: abra el Vue de esa ruta y nombre el archivo, el v-if o el estado, y el llamado AppStore.json.
5. Si es capacitación: impacto de frontend, API y SQL en No; cambioPropuestoSql vacío; validar antes = probar el camino que ya existe. No proponga un módulo nuevo.
6. No marque brechaAnalisis.estado en listo si falta la causa o el bloque. Si un dato bloquea, pida ese dato y deje el estado en observado.
7. El alcance es contenido.ubicacion. Abra solo esos recursos. En el cambio y en metodosDocumentados solo entran los SP y METODO de ubicacion.participan. Un procedimiento de otro flujo del mismo módulo no se nombra ni se baja.
"""


def _norm_tipo(valor: str, validos: tuple[str, ...]) -> str:
    texto = (valor or "").strip().lower().replace("ó", "o").replace("á", "a").replace("é", "e")
    alias = {
        "boton": "boton",
        "metodo": "metodo",
        "procedimiento": "sp",
        "procedure": "sp",
        "pantalla": "ventana",
        "vue": "codigo",
    }
    texto = alias.get(texto, texto)
    return texto if texto in validos else ""


def _ubicacion(sol: dict) -> dict:
    if not isinstance(sol, dict):
        return {}
    contenido = sol.get("contenido") if isinstance(sol.get("contenido"), dict) else {}
    ubicacion = contenido.get("ubicacion")
    if isinstance(ubicacion, dict):
        return ubicacion
    raiz = sol.get("ubicacion")
    return raiz if isinstance(raiz, dict) else {}


def _participan(ubicacion: dict) -> list[tuple[str, str]]:
    salida = []
    for item in ubicacion.get("participan") or []:
        if not isinstance(item, dict):
            continue
        sp = str(item.get("sp") or "").strip().upper()
        metodo = str(item.get("metodo") or "").strip().upper()
        if sp:
            salida.append((sp, metodo))
    return salida


def _recursos(ubicacion: dict) -> list[dict]:
    salida = []
    for rec in ubicacion.get("recursos") or []:
        if not isinstance(rec, dict):
            continue
        tipo = _norm_tipo(str(rec.get("tipo") or ""), TIPOS_RECURSO)
        cual = str(rec.get("cual") or "").strip()
        if tipo and cual:
            salida.append({"tipo": tipo, "cual": cual})
    return salida


def evaluar_ubicacion(sol: dict) -> dict:
    """Paso 1: proceso, flujo, pieza y recursos.

    espera detiene el análisis. bloqueo dato: el analista completa y se sigue.
    bloqueo base: primero se mapea en la base; el análisis no arranca.
    """
    ubicacion = _ubicacion(sol)
    recursos = _recursos(ubicacion)
    preguntas = [
        str(item).strip()
        for item in (ubicacion.get("preguntas") or [])
        if str(item).strip()
    ]
    estado = str(ubicacion.get("estado") or "").strip().lower()
    if estado == "sin_mapa" or str(ubicacion.get("bloqueo") or "").strip().lower() == "base":
        texto = preguntas[0] if preguntas else (
            "Ese proceso no está mapeado en la base. "
            "Complételo en Documentar antes de continuar con el requerimiento."
        )
        return {"ok": False, "espera": True, "bloqueo": "base", "faltantes": [texto]}
    pide = estado == "pregunta" or any(rec["tipo"] == "pregunta" for rec in recursos)
    texto = ""
    if pide:
        texto = preguntas[0] if preguntas else next(
            (rec["cual"] for rec in recursos if rec["tipo"] == "pregunta"),
            "",
        )
        if texto:
            return {
                "ok": False,
                "espera": True,
                "bloqueo": "dato",
                "faltantes": [
                    "Falta un dato del analista. Al responder en el Chat, el análisis continúa: " + texto
                ],
            }
    faltantes: list[str] = []
    if not str(ubicacion.get("procesoId") or "").strip():
        faltantes.append("Falta el proceso de la base (por ejemplo inventario).")
    if len(str(ubicacion.get("flujo") or "").strip()) < 8:
        faltantes.append("Falta el flujo dentro de ese proceso: el recorrido en el que participa el requerimiento.")
    pieza = ubicacion.get("pieza") if isinstance(ubicacion.get("pieza"), dict) else {}
    if not _norm_tipo(str(pieza.get("tipo") or ""), TIPOS_PIEZA):
        faltantes.append("Falta la pieza dentro del flujo: ventana, botón, proceso, SP o método.")
    if not str(pieza.get("nombre") or "").strip():
        faltantes.append("Falta el nombre de esa pieza.")
    if not recursos:
        faltantes.append("Falta qué recursos hacen falta: ventana, código, SP o una pregunta al analista.")
    if any(rec["tipo"] == "sp" for rec in recursos) and not _participan(ubicacion):
        faltantes.append("El recurso es un SP: indique solo el SP y el METODO que participan en este flujo.")
    if pide and not texto:
        faltantes.append("Marcó una pregunta al analista y no escribió cuál.")
    return {
        "ok": not faltantes,
        "espera": False,
        "bloqueo": "" if not faltantes else "dato",
        "faltantes": faltantes,
    }


def sps_fuera_de_flujo(sol: dict) -> list[str]:
    """Procedimientos citados en el cambio que no están en la ubicación."""
    participans = {sp for sp, _metodo in _participan(_ubicacion(sol))}
    if not participans:
        return []
    _contenido, campos = _campos(sol)
    cambio = _cambio(campos)
    blob = " ".join(
        (
            campos["sql"],
            campos["recomendacion"],
            str(cambio.get("sql") or ""),
        )
    ).upper()
    citados = set(re.findall(r"\bSP[QK]_[A-Z0-9_]+\b", blob))
    return sorted(citados - participans)


def texto_faltantes(faltantes: list[str]) -> str:
    if not faltantes:
        return ""
    lineas = "\n".join(f"- {item}" for item in faltantes)
    return (
        "El planteamiento quedó corto para desarrollar. "
        "Complete esto antes de dar el análisis por listo:\n" + lineas
    )


def _norm_clasif(valor: str) -> str:
    texto = (valor or "").strip().lower().replace("ó", "o").replace("á", "a")
    texto = texto.replace("capacitación", "capacitacion")
    if texto in CLASIFICACIONES:
        return texto
    return ""


def _campos(sol: dict) -> tuple[dict, dict]:
    contenido = sol.get("contenido") if isinstance(sol.get("contenido"), dict) else {}

    def pick(*claves: str):
        for clave in claves:
            if contenido.get(clave):
                return contenido.get(clave)
            if sol.get(clave):
                return sol.get(clave)
        return ""

    planteamiento = contenido.get("planteamiento")
    if not isinstance(planteamiento, dict):
        planteamiento = sol.get("planteamiento") if isinstance(sol.get("planteamiento"), dict) else {}
    return contenido, {
        "analisis": str(pick("analisis") or ""),
        "recomendacion": str(pick("recomendacion") or ""),
        "criterios": str(pick("criteriosAceptacion", "criterios") or ""),
        "simple": str(pick("cambioPropuestoSimple", "propuesta") or ""),
        "sql": str(pick("cambioPropuestoSql") or ""),
        "req": str(pick("requerimiento", "necesidad") or ""),
        "planteamiento": planteamiento,
    }


def _impacto(contenido: dict, nombre: str) -> bool:
    valor = str(contenido.get(nombre) or "").strip().lower()
    return valor in ("si", "sí", "parcial")


def _clasificacion(contenido: dict, campos: dict) -> str:
    directa = _norm_clasif(str((campos["planteamiento"] or {}).get("clasificacion") or ""))
    if directa:
        return directa
    blob = "\n".join((campos["analisis"], campos["recomendacion"]))
    hallado = re.search(
        r"clasificaci[oó]n\s*:\s*(capacitaci[oó]n|defecto|hueco)",
        blob,
        re.I,
    )
    if not hallado:
        return ""
    return _norm_clasif(hallado.group(1))


def _cambio(campos: dict) -> dict:
    cambio = campos["planteamiento"].get("cambio")
    return cambio if isinstance(cambio, dict) else {}


def texto_ya_existe(plan: dict) -> str:
    """Camino que el proceso ya cubre, escrito por el análisis antes del cambio."""
    if not isinstance(plan, dict):
        return ""
    items = plan.get("yaExiste")
    partes: list[str] = []
    if isinstance(items, str):
        partes.append(items)
    elif isinstance(items, list):
        for item in items:
            if isinstance(item, dict):
                partes.append(
                    " ".join(
                        str(item.get(clave) or "")
                        for clave in ("donde", "condicion", "queHace", "noEs")
                    )
                )
            else:
                partes.append(str(item))
    return " ".join(parte.strip() for parte in partes if str(parte).strip())


_QUEJA_DE_PEDIDO = re.compile(
    r"sale vac[ií]o|no puede reportar|no se env[ií]a|no genera|no puede enviar|no se puede",
    re.I,
)
_CAMINO_YA_HECHO = re.compile(r"\b(cufe|dian|cuv|notificad)", re.I)


def evaluar(sol: dict, modo: str = "analisis") -> dict:
    """Devuelve ok y la lista de lo que falta para que un desarrollador pueda trabajar."""
    if not isinstance(sol, dict):
        return {"ok": False, "faltantes": ["No hay solicitud para revisar."]}
    contenido, campos = _campos(sol)
    planteamiento = campos["planteamiento"]
    faltantes: list[str] = []
    clasificacion = _clasificacion(contenido, campos)
    ya = texto_ya_existe(planteamiento)
    if len(ya) < 40:
        faltantes.append(
            "Falta lo que el proceso ya hace (planteamiento.yaExiste): pantalla, condición y efecto. "
            "Si la nota ya se envía a la DIAN y el CUFE se genera, eso se escribe ahí. "
            "No copie el pedido como si fuera el comportamiento de hoy."
        )
    if not clasificacion:
        faltantes.append(
            "Clasifique el requerimiento: capacitación, defecto o hueco "
            "(planteamiento.clasificacion)."
        )

    flujo = planteamiento.get("flujoHoy") if isinstance(planteamiento.get("flujoHoy"), list) else []
    pasos = [str(paso).strip() for paso in flujo if str(paso).strip()]
    analisis = campos["analisis"].strip()
    trazo = " ".join(pasos) + " " + analisis
    tiene_tramo = bool(re.search(r"SPQ_|SPK_|\.vue|METODO|bot[oó]n|pantalla", trazo, re.I))
    if len(pasos) < 3 and not (tiene_tramo and len(analisis) >= 280):
        faltantes.append(
            "Falta el flujo de hoy: pantalla o botón, MODELO/METODO, procedimiento y efecto."
        )

    causa = str(planteamiento.get("causa") or "").strip()
    causa_en_analisis = bool(re.search(r"causa\s*:", analisis, re.I)) and len(analisis) >= 200
    if len(causa) < 60 and not causa_en_analisis:
        faltantes.append(
            "Falta la causa: la condición que falla o falta, citada de la ficha o del bloque. "
            "No vale «ajustar el proceso»."
        )

    cambio = _cambio(campos)
    negocio = str(cambio.get("negocio") or campos["simple"] or campos["recomendacion"] or "").strip()
    pedido = campos["req"].strip()
    if len(negocio) < 40:
        faltantes.append("Falta el cambio en palabras de negocio: qué pasa hoy y qué se propone.")
    elif pedido and negocio.lower() == pedido.lower():
        faltantes.append(
            "El cambio propuesto repite el requerimiento. Diga qué hace el sistema hoy y qué bloque cambia."
        )
    elif negocio.lower() in _GENERICAS:
        faltantes.append("El cambio es una frase genérica. Nombre el control y el bloque que se toca.")
    elif (
        _QUEJA_DE_PEDIDO.search(negocio)
        and _CAMINO_YA_HECHO.search(ya)
        and not _CAMINO_YA_HECHO.search(negocio)
    ):
        faltantes.append(
            "El cambio en palabras simples repite el pedido (archivo vacío, no se envía, no se puede reportar) "
            "y no reconoce el camino que ya existe. Si la nota ya se envía a la DIAN y el CUFE se genera, "
            "eso queda en el flujo de hoy. El cambio solo habla de lo que la ficha muestra que todavía falta, "
            "y cita ese método."
        )

    if clasificacion != "capacitacion" and _impacto(contenido, "impactoSql"):
        sql = campos["sql"]
        if not re.search(r"SPQ_|SPK_|UPDATE\s|INSERT\s|DELETE\s|WHERE\s", sql, re.I) or len(sql) < 80:
            faltantes.append(
                "Impacto SQL: cambioPropuestoSql debe citar el objeto y el bloque "
                "(---ANTES--- el de hoy, ---SUGERIDO--- el propuesto)."
            )
        elif not re.search(r"ANTES|SUGERIDO|DESPU[EÉ]S", sql, re.I):
            faltantes.append(
                "El SQL propuesto no separa el bloque de hoy y el sugerido "
                "(---ANTES--- / ---SUGERIDO---)."
            )

    if clasificacion != "capacitacion" and _impacto(contenido, "impactoFe"):
        frontend = " ".join(
            (
                str(cambio.get("frontend") or ""),
                campos["recomendacion"],
                analisis,
            )
        )
        if not re.search(r"\.vue|AppStore|v-if|componente", frontend, re.I):
            faltantes.append(
                "Impacto frontend: nombre el archivo Vue, la condición (v-if o estado) y qué cambia."
            )

    criterios_lista = planteamiento.get("criterios") if isinstance(planteamiento.get("criterios"), list) else []
    criterios_ok = [str(item).strip() for item in criterios_lista if str(item).strip()]
    lineas = [linea.strip() for linea in campos["criterios"].splitlines() if linea.strip()]
    if len(criterios_ok) < 2 and len(lineas) < 2:
        faltantes.append("Hacen falta al menos dos criterios que se puedan comprobar en un caso.")

    if modo == "analisis" and not str(_ubicacion(sol).get("procesoId") or "").strip():
        faltantes.append("Falta ubicar el flujo en la base (proceso, flujo y pieza) antes del cambio.")
    fuera = sps_fuera_de_flujo(sol) if modo == "analisis" else []
    if fuera:
        faltantes.append(
            "El cambio nombra procedimientos que no participan en el flujo ubicado: " + ", ".join(fuera) + "."
        )

    if clasificacion == "capacitacion" and any(
        _impacto(contenido, nombre) for nombre in ("impactoFe", "impactoApi", "impactoSql")
    ):
        faltantes.append(
            "Quedó como capacitación y a la vez con impacto de desarrollo. "
            "Si el camino ya existe, frontend, API y SQL van en No."
        )

    if modo == "comite" and clasificacion in ("defecto", "hueco"):
        if re.search(r"\bSPQ_|\bSPK_", campos["recomendacion"] + " " + analisis) and len(campos["sql"]) < 80:
            faltantes.append(
                "El análisis nombra un procedimiento y no trae el bloque de hoy ni el sugerido "
                "en cambioPropuestoSql."
            )

    return {"ok": not faltantes, "faltantes": faltantes}
