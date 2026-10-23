#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contrato del planteamiento de un requerimiento y revisión de que no quede en resumen.

Lo usa el prompt de analizar-req y un control al cerrar el turno: si falta el flujo
de hoy, la causa o el bloque que cambia, el caso no se da por listo.
"""
from __future__ import annotations

import re

CLASIFICACIONES = ("capacitacion", "defecto", "hueco")

_GENERICAS = (
    "ajustar el proceso",
    "realizar los cambios necesarios",
    "se debe revisar",
    "hacer el ajuste correspondiente",
    "revisar y corregir",
    "realizar el ajuste",
)


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
- clasificacion: capacitacion, defecto o hueco.
- flujoHoy: cuatro pasos — pantalla y botón o estado; MODELO y METODO; procedimiento y qué hace ese tramo; tabla o salida.
- causa: la condición que falla o falta, citada de la ficha (procedimiento y METODO) o del bloque SQL leído. Si es capacitación, la ruta y la condición del camino que ya existe.
- cambio.negocio: qué pasa hoy y qué se propone, en palabras de la pantalla, sin nombres de procedimiento.
- cambio.frontend: archivo Vue y condición, o «Sin cambio FE».
- cambio.sql: objeto, METODO y qué bloque cambia, o «Sin cambio SQL».
- cambio.backend: MODELO y METODO, o «Sin cambio API».
- noCambia: el camino vecino que no se toca.
- criterios: al menos dos. Cada uno dice el caso y el resultado que se puede comprobar.

Vuelque eso en el formulario: analisis (flujo de hoy y causa, no una paráfrasis del pedido), recomendacion (cambio por capa), cambioPropuestoSimple (el negocio), {criterios} (un criterio por línea), alcance y restricciones.

Profundidad, sin barrer la base:
1. Clasifique después de ver todos los caminos del control, incluidas las necesidades ya cubiertas. No se quede con las casillas del formulario ni con la captura.
2. Abra la ficha completa del METODO de este cambio (hace, valida, noValida, errores, llama, efecto). El recorte del contexto no alcanza para redactar el cambio.
3. Si el cambio es SQL (defecto o hueco, impacto Sí o Parcial): lea el cuerpo de ESE METODO en la carpeta del caso o bájelo, y escriba cambioPropuestoSql con ---ANTES--- (el bloque de hoy) y ---SUGERIDO--- (el bloque propuesto), más una consulta de comprobación. No invente el SQL desde el resumen de la ficha. Una ficha en estado leido sirve para clasificar; no reemplaza el bloque.
4. Si el cambio es de pantalla: abra el Vue de esa ruta y nombre el archivo, el v-if o el estado, y el llamado AppStore.json.
5. Si es capacitación: impacto de frontend, API y SQL en No; cambioPropuestoSql vacío; validar antes = probar el camino que ya existe. No proponga un módulo nuevo.
6. No marque brechaAnalisis.estado en listo si falta la causa o el bloque. Si un dato bloquea, pida ese dato y deje el estado en observado.
"""


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


def evaluar(sol: dict, modo: str = "analisis") -> dict:
    """Devuelve ok y la lista de lo que falta para que un desarrollador pueda trabajar."""
    if not isinstance(sol, dict):
        return {"ok": False, "faltantes": ["No hay solicitud para revisar."]}
    contenido, campos = _campos(sol)
    planteamiento = campos["planteamiento"]
    faltantes: list[str] = []
    clasificacion = _clasificacion(contenido, campos)
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
