#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Preselección de contexto KB para análisis de requerimientos.

Entrega el recorte del proceso (fichas, controles, necesidades ya cubiertas)
para no barrer conocimiento/. El recorte orienta; no reemplaza la ficha
completa del METODO ni el cuerpo SQL del bloque que el cambio toca.

mapa_ubicacion arma el mapa de tramos (proceso → flujo → pantalla) con la
ruta del formulario y el texto del pedido, para el paso de ubicar.
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

# Force UTF-8 output
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Añadir scripts al path para kb_buscar/kb_indice
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

import kb_buscar
import kb_indice

ROOT = Path(__file__).resolve().parent.parent
KB = ROOT / "conocimiento"
MAX_CHARS_CONTEXTO = 12000  # Límite de tamaño del contexto preseleccionado
MIN_SCORE_THRESHOLD = 3  # Puntaje mínimo para considerar un proceso relevante

# Stopwords: tokens cortos/genéricos que no aportan al matching
STOPWORDS = {
    "si", "no", "de", "del", "la", "el", "los", "las", "un", "una", "en", 
    "con", "por", "para", "que", "cuando", "donde", "como", "desde", "hasta",
    "saldo", "movimiento", "sistema", "error", "problema"
}

# Keywords de dominio por proceso (peso fuerte)
DOMAIN_KEYWORDS = {
    "inventario": {"sku", "bodega", "kardex", "entrada", "salida", "articulo", "stock", 
                   "existencia", "lote", "vencimiento", "compras", "orden", "cotizacion",
                   "proveedor", "devolucion", "conteo", "ajuste", "transito", "traslado",
                   "dispensacion", "farmacia", "venta", "particular"},
    "caja": {"cajero", "recibo", "efectivo", "datáfono", "datafono", "cheque", "consignacion",
             "turno", "apertura", "cierre", "cuadre", "egreso", "reembolso", "forma", "pago",
             "ventanilla", "sesion", "menor"},
    "bancos": {"banco", "cuenta", "extracto", "conciliacion", "cheque", "consignacion", 
               "transferencia", "tarjeta", "credito", "debito", "extracto"},
    "facturacion": {"factura", "facturar", "rips", "evento", "capita", "pgp", "autorizacion", 
                    "radicacion", "glosa", "cartera", "nota", "debito", "credito", "dian", "fev",
                    "cups", "eps", "ips", "prestacion", "servicio", "diagnostico", "procedimiento",
                    "cufe", "cuv", "sispro", "ministerio", "validacion", "json"},
    "rips-json": {"rips", "json", "fevrips", "cuv", "sispro", "ministerio", "validacion", 
                  "factura", "nota", "credito", "debito", "cups", "diagnostico"},
    "nomina": {"nomina", "empleado", "concepto", "devengado", "deduccion", "seguridad", "social",
               "parafiscal", "liquidacion", "incapacidad", "vacaciones", "prestacion"},
    "contabilidad": {"asiento", "comprobante", "mayor", "balance", "auxiliar", "niif", "puc",
                     "causacion", "centro", "costo", "periodo", "cierre"},
    "presupuesto": {"presupuesto", "ppto", "ejecucion", "apropiacion", "cdp", "rp", "compromiso",
                    "disponibilidad", "registro", "vigencia", "ordenacion", "gasto"},
}


def _normalizar_texto(texto: str) -> str:
    """Normaliza texto: quita acentos, minúsculas."""
    if not texto:
        return ""
    # Normalizar unicode (NFD) y quitar marcas diacríticas
    nfd = unicodedata.normalize('NFD', texto)
    sin_acentos = ''.join(c for c in nfd if unicodedata.category(c) != 'Mn')
    return sin_acentos.lower()


def _extraer_terminos_req(texto: str) -> tuple[set[str], list[str]]:
    """
    Extrae términos clave del requerimiento para buscar en la KB.
    
    Returns:
        (terminos_set, tags_inicio): términos generales y tags al inicio del texto
    """
    texto = (texto or "").strip()
    if not texto:
        return (set(), [])
    
    terminos = set()
    texto_norm = _normalizar_texto(texto)
    
    # Tags de módulo al inicio (antes de '—' o ':' o primeras 80 chars)
    tags_inicio = []
    primera_linea = texto.split('\n')[0][:100]
    if '—' in primera_linea or ':' in primera_linea:
        # Formato "PPTO — PRESUPUESTO Error..." o "CARTERA: problema..."
        separador = '—' if '—' in primera_linea else ':'
        prefijo = primera_linea.split(separador)[0].strip()
        # Extraer palabras/siglas del prefijo
        for palabra in re.findall(r'\b[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]+\b', prefijo):
            if len(palabra) >= 3:
                tags_inicio.append(palabra)
                terminos.add(palabra)
    
    # Siglas técnicas (3+ letras mayúsculas) - mantener original
    for sigla in re.findall(r"\b[A-Z][A-Z0-9_]{2,}\b", texto):
        # Filtrar stopwords en mayúsculas como SI (saldo inicial vs if)
        if sigla.lower() not in STOPWORDS or len(sigla) > 3:
            terminos.add(sigla)
    
    # Nombres de SP/tablas (SP*, FN*, VWK_*)
    for sp in re.findall(r"\b(SP[QK]_[A-Z0-9_]+|FN[QK]_[A-Z0-9_]+|VWK_[A-Z0-9_]+)\b", texto):
        terminos.add(sp)
    
    # Términos de negocio (4+ letras, español) - normalizado
    for palabra in re.findall(r"\b[a-záéíóúñ]{4,}\b", texto_norm):
        if palabra not in STOPWORDS:
            terminos.add(palabra)
    
    # Rutas de pantalla
    for ruta in re.findall(r"/[a-z]+/[a-z\-]+", texto.lower()):
        terminos.add(ruta)
    
    return (terminos, tags_inicio)


def _cargar_proceso_meta(proceso_id: str) -> dict:
    """Carga metadatos ligeros de un proceso (sin el proceso.json completo)."""
    indice_general = kb_indice._leer(KB / "INDICE.json", {}) or {}
    for p in indice_general.get("procesos") or []:
        if p.get("id") == proceso_id or p.get("carpeta") == proceso_id:
            return p
    return {}


def _clip(valor, n: int) -> str:
    """Texto corto de un campo de ficha (string o lista)."""
    if isinstance(valor, list):
        partes = []
        for item in valor:
            if isinstance(item, dict):
                partes.append(str(item.get("nombre") or item.get("sp") or item.get("id") or ""))
            else:
                partes.append(str(item))
        valor = "; ".join(parte for parte in partes if parte)
    texto = " ".join(str(valor or "").split())
    if len(texto) <= n:
        return texto
    return texto[: n - 1].rstrip() + "…"


def _blob_metodo(metodo: dict) -> str:
    partes = [str(metodo.get("id") or "")]
    for clave in ("hace", "valida", "noValida", "efecto", "errores", "llama"):
        partes.append(_clip(metodo.get(clave), 400))
    return _normalizar_texto(" ".join(partes))


def _puntaje_metodo(metodo: dict, terminos: set[str] | None) -> int:
    if not terminos:
        return 0
    blob = _blob_metodo(metodo)
    return sum(1 for termino in terminos if _normalizar_texto(str(termino)) and _normalizar_texto(str(termino)) in blob)


def _ficha_metodo(metodo: dict) -> dict:
    ficha = {"id": metodo.get("id")}
    for clave, tope in (
        ("hace", 140),
        ("valida", 80),
        ("noValida", 80),
        ("efecto", 80),
        ("llama", 80),
        ("errores", 80),
    ):
        texto = _clip(metodo.get(clave), tope)
        if texto:
            ficha[clave] = texto
    return ficha


def _resumir_sps(proceso_id: str, limite: int = 6, terminos: set[str] | None = None) -> list[dict]:
    """SPs del proceso, con los METODO que más se acercan al texto del REQ."""
    sps_path = KB / proceso_id / "sps.json"
    if not sps_path.is_file():
        return []

    data = kb_indice._leer(sps_path, [])
    if isinstance(data, dict):
        data = data.get("sps") or data.get("procedimientos") or []

    if isinstance(data, dict):
        data = list(data.values())

    preparados = []
    for sp in data:
        if not isinstance(sp, dict):
            continue
        metodos = [m for m in (sp.get("metodos") or []) if isinstance(m, dict) and m.get("id")]
        metodos.sort(key=lambda m: _puntaje_metodo(m, terminos), reverse=True)
        mejor = _puntaje_metodo(metodos[0], terminos) if metodos else 0
        estado = sp.get("estado") or ""
        preparados.append((mejor, estado == "leido", len(metodos), sp.get("nombre") or "", sp, metodos))

    preparados.sort(key=lambda fila: (fila[0], fila[1], fila[2], fila[3]), reverse=True)

    salida = []
    for _mejor, _leido, _n, _nombre, sp, metodos in preparados[:limite]:
        salida.append({
            "nombre": sp.get("nombre"),
            "estado": sp.get("estado"),
            "metodos": [_ficha_metodo(m) for m in metodos[:4]],
        })
    return salida


def _resumir_controles(proceso_id: str, limite: int = 6) -> list[dict]:
    """Resumen compacto de controles del proceso."""
    proceso_path = KB / proceso_id / "proceso.json"
    if not proceso_path.is_file():
        return []
    
    data = kb_indice._leer(proceso_path, {}) or {}
    controles = []
    
    for capa in data.get("capas") or []:
        if not isinstance(capa, dict):
            continue
        for ctl in capa.get("controles") or capa.get("gates") or []:
            if isinstance(ctl, dict) and ctl.get("id"):
                controles.append({
                    "id": ctl["id"],
                    "nombre": (ctl.get("nombre") or "")[:80],
                    "validaSi": (ctl.get("validaSi") or "")[:120],
                })
    
    return controles[:limite]


def _resumir_cubiertas(proceso_id: str, terminos: set[str] | None = None, limite: int = 4) -> list[dict]:
    """Necesidades que el control ya cubre, priorizando las que se parecen al REQ."""
    proceso_path = KB / proceso_id / "proceso.json"
    if not proceso_path.is_file():
        return []
    data = kb_indice._leer(proceso_path, {}) or {}
    items = [item for item in (data.get("necesidadesYaCubiertas") or []) if isinstance(item, dict)]
    if not items:
        return []

    def puntaje(item: dict) -> int:
        blob = _normalizar_texto(
            " ".join(str(item.get(clave) or "") for clave in ("necesidad", "donde", "condicion", "noEs"))
        )
        if not terminos:
            return 0
        return sum(1 for termino in terminos if _normalizar_texto(str(termino)) in blob)

    ranked = sorted(items, key=puntaje, reverse=True)
    if terminos and puntaje(ranked[0]) == 0:
        ranked = items[:limite]
    else:
        ranked = ranked[:limite]
    salida = []
    for item in ranked:
        salida.append({
            "necesidad": _clip(item.get("necesidad"), 120),
            "donde": _clip(item.get("donde"), 140),
            "noEs": _clip(item.get("noEs"), 100),
        })
    return salida


def _buscar_grafo_indice(proceso_id: str) -> str | None:
    """Busca el archivo grafo-*-indice.json si existe."""
    indice_general = kb_indice._leer(KB / "INDICE.json", {}) or {}
    for p in indice_general.get("procesos") or []:
        if (p.get("id") == proceso_id or p.get("carpeta") == proceso_id) and p.get("grafoIndice"):
            return p["grafoIndice"]
    carpeta = KB / proceso_id
    if carpeta.is_dir():
        hallados = sorted(carpeta.glob("grafo-*-indice.json"))
        if hallados:
            return f"{proceso_id}/{hallados[0].name}"
    return None


def _clave_pantalla(texto: str) -> str:
    """Último tramo de una ruta (/inv/gesventa) o de un código de menú (inv.gesventa)."""
    t = _normalizar_texto(str(texto or "")).replace("\\", "/").split("·")[0].strip()
    if not t:
        return ""
    if "/" in t:
        return t.rstrip("/").split("/")[-1]
    if "." in t:
        return t.split(".")[-1]
    return t


def _coincide_ruta(pantalla_valor, ruta: str) -> bool:
    """La pantalla del tramo es la misma ruta del formulario. No vale un prefijo más corto."""
    ruta_full = _normalizar_texto(ruta).replace("\\", "/").strip()
    if not ruta_full:
        return False
    clave_ruta = _clave_pantalla(ruta_full)
    if isinstance(pantalla_valor, list):
        partes = []
        for item in pantalla_valor:
            partes.extend(re.split(r"[;,]", str(item or "")))
    else:
        partes = re.split(r"[;,]", str(pantalla_valor or ""))
    for parte in partes:
        full = _normalizar_texto(parte).replace("\\", "/").split("·")[0].strip()
        if not full:
            continue
        if full.rstrip("/") == ruta_full.rstrip("/"):
            return True
        clave = _clave_pantalla(full)
        if clave_ruta and len(clave_ruta) >= 4 and clave == clave_ruta:
            return True
    return False


def _mapas_flujo() -> list[tuple[str, dict]]:
    """Índices de tramos en disco, aunque INDICE.json no traiga grafoIndice."""
    if not KB.is_dir():
        return []
    salida = []
    for carpeta in sorted(p for p in KB.iterdir() if p.is_dir()):
        for path in sorted(carpeta.glob("grafo-*-indice.json")):
            data = kb_indice._leer(path, {}) or {}
            if isinstance(data, dict):
                salida.append((carpeta.name, data))
    return salida


def _filas_flujo(proceso: str, data: dict) -> list[dict]:
    filas = []
    for clave in ("tramos", "procedencias", "grafos"):
        for item in data.get(clave) or []:
            if isinstance(item, str):
                filas.append({
                    "proceso": proceso,
                    "id": item,
                    "nombre": item,
                    "pantalla": "",
                    "controlClave": "",
                    "orden": 0,
                })
                continue
            if not isinstance(item, dict):
                continue
            generadores = item.get("generadores") or []
            if item.get("controlClave"):
                control = str(item.get("controlClave"))
            elif isinstance(generadores, list):
                control = "; ".join(str(g) for g in generadores[:4])
            else:
                control = str(generadores or "")
            ident = str(item.get("id") or item.get("procedencia") or item.get("nombre") or "").strip()
            filas.append({
                "proceso": proceso,
                "id": ident,
                "nombre": str(item.get("nombre") or item.get("procedencia") or ident),
                "pantalla": item.get("pantalla") if item.get("pantalla") not in (None, "") else item.get("pantallas") or "",
                "controlClave": control,
                "orden": item.get("orden") or 0,
            })
    return filas


def _tokens_de_proceso() -> set[str]:
    """Palabras que nombran un proceso o su módulo. No sirven para elegir un tramo."""
    indice = kb_indice._leer(KB / "INDICE.json", {}) or {}
    tokens = set()
    for meta in indice.get("procesos") or []:
        pid = _normalizar_texto(str(meta.get("id") or meta.get("carpeta") or ""))
        modulo = _normalizar_texto(str(meta.get("modulo") or ""))
        if len(pid) >= 4:
            tokens.add(pid)
        if len(modulo) >= 4:
            tokens.add(modulo)
    return tokens


def _puntaje_tramo(
    fila: dict,
    terminos: set[str],
    ruta: str,
    tokens_proceso: set[str] | None = None,
) -> tuple[int, list[str], bool]:
    score = 0
    porque: list[str] = []
    coincide = _coincide_ruta(fila.get("pantalla"), ruta)
    if coincide:
        score += 20
        porque.append("pantalla")
    blob_nombre = _normalizar_texto(f"{fila.get('id') or ''} {fila.get('nombre') or ''}")
    blob_control = _normalizar_texto(str(fila.get("controlClave") or ""))
    tokens_proceso = tokens_proceso or set()
    for termino in terminos:
        crudo = str(termino)
        t = _normalizar_texto(crudo)
        if not t or t in STOPWORDS or t in tokens_proceso:
            continue
        if "_" in crudo and t in blob_control:
            score += 8
            if crudo not in porque:
                porque.append(crudo)
            continue
        if len(t) < 5:
            continue
        if t in blob_nombre:
            score += 4
            if t not in porque and len(porque) < 5:
                porque.append(t)
        elif t in blob_control:
            score += 3
    return score, porque, coincide


def _fichas_pantalla(ruta: str) -> list[dict]:
    ruta = (ruta or "").strip()
    if not ruta:
        return []
    vistos = set()
    salida = []
    resultado = kb_buscar.buscar(ruta, limite=3)
    if resultado.get("tipo") != "pantalla":
        return []
    for ref in resultado.get("resultados") or []:
        ficha = ref.get("ficha") if isinstance(ref.get("ficha"), dict) else {}
        pid = str(ref.get("proceso") or "")
        path = str(ficha.get("path") or ficha.get("ruta") or ruta)
        llave = (pid, path.lower())
        if llave in vistos:
            continue
        vistos.add(llave)
        salida.append({
            "proceso": pid,
            "path": str(ficha.get("path") or ""),
            "ruta": str(ficha.get("ruta") or ""),
            "uso": _clip(ficha.get("uso"), 80),
            "vue": _clip(ficha.get("vue"), 140),
            "entrada": _clip(ficha.get("entrada"), 180),
        })
    return salida[:4]


def _controles_proceso(proceso_id: str, terminos: set[str], tokens_proceso: set[str] | None = None) -> list[dict]:
    tokens_proceso = tokens_proceso or set()
    idx = kb_buscar._cargar_indice()
    prefijo = proceso_id + "/"
    salida = []
    for clave, refs in (idx.get("control") or {}).items():
        if not str(clave).startswith(prefijo):
            continue
        nombre = ""
        for ref in refs or []:
            if isinstance(ref, dict) and ref.get("proceso") == proceso_id:
                nombre = str(ref.get("nombre") or "")
                break
        cid = str(clave).split("/", 1)[1]
        blob = _normalizar_texto(f"{cid} {nombre}")
        score = 0
        for termino in terminos:
            t = _normalizar_texto(str(termino))
            if len(t) >= 5 and t not in STOPWORDS and t not in tokens_proceso and t in blob:
                score += 1
        if score:
            salida.append({"proceso": proceso_id, "id": cid, "nombre": nombre, "score": score})
    salida.sort(key=lambda item: (-item["score"], item["id"]))
    return salida[:6]


def _menu_coincidencias(
    proceso_id: str,
    terminos: set[str],
    clave_ruta: str,
    tokens_proceso: set[str] | None = None,
) -> list[dict]:
    tokens_proceso = tokens_proceso or set()
    proc = kb_indice._leer(KB / proceso_id / "proceso.json", {}) or {}
    menu = proc.get("menu") if isinstance(proc.get("menu"), dict) else {}
    hits = []
    vistos = set()

    def considera(grupo: str, texto: str) -> None:
        blob = _normalizar_texto(texto)
        if not blob or blob in vistos:
            return
        por_ruta = bool(clave_ruta) and len(clave_ruta) >= 4 and clave_ruta in blob
        por_texto = any(
            len(_normalizar_texto(str(t))) >= 5
            and _normalizar_texto(str(t)) not in STOPWORDS
            and _normalizar_texto(str(t)) not in tokens_proceso
            and _normalizar_texto(str(t)) in blob
            for t in terminos
        )
        if not por_ruta and not por_texto:
            return
        vistos.add(blob)
        hits.append({"proceso": proceso_id, "grupo": grupo, "item": texto})

    for item in menu.get("individuales") or []:
        considera("", str(item))
    grupos = menu.get("grupos") or {}
    if isinstance(grupos, dict):
        for grupo, items in grupos.items():
            for item in items or []:
                considera(str(grupo), str(item))
    return hits[:6]


def _procesos_nombrados(terminos: set[str], modulo: str) -> set[str]:
    """Procesos que el texto o el módulo nombran. No es un tramo."""
    indice = kb_indice._leer(KB / "INDICE.json", {}) or {}
    elegidos = set()
    tokens = {_normalizar_texto(str(t)) for t in terminos if _normalizar_texto(str(t))}
    modulo_n = _normalizar_texto(modulo)
    for meta in indice.get("procesos") or []:
        pid = str(meta.get("id") or meta.get("carpeta") or "")
        if not pid:
            continue
        pid_n = _normalizar_texto(pid)
        mod_n = _normalizar_texto(str(meta.get("modulo") or ""))
        nombre_n = _normalizar_texto(str(meta.get("nombre") or ""))
        if pid_n and pid_n in tokens:
            elegidos.add(pid)
        if mod_n and len(mod_n) >= 4 and mod_n in tokens:
            elegidos.add(pid)
        if modulo_n and len(modulo_n) >= 4 and (
            modulo_n == pid_n or modulo_n == mod_n or re.search(rf"\b{re.escape(modulo_n)}\b", nombre_n)
        ):
            elegidos.add(pid)
    return elegidos


def mapa_ubicacion(req_texto: str, ruta: str = "", modulo: str = "", proceso_id: str = "") -> dict:
    """Cruza la ruta y el texto con los tramos de la base. No elige el cambio."""
    terminos, _tags = _extraer_terminos_req(req_texto)
    ruta = (ruta or "").strip()
    if not ruta:
        halladas = re.findall(r"/[a-z0-9]+(?:/[a-z0-9_\-]+)+", (req_texto or "").lower())
        if halladas:
            ruta = halladas[0]
    modulo = (modulo or "").strip()
    proceso_id = (proceso_id or "").strip()
    pantallas = _fichas_pantalla(ruta)
    filas: list[dict] = []
    for pid, data in _mapas_flujo():
        filas.extend(_filas_flujo(pid, data))
    if proceso_id and not ruta and not pantallas:
        propias = [fila for fila in filas if fila["proceso"] == proceso_id]
        if propias:
            filas = propias
    tokens_proceso = _tokens_de_proceso()
    ranked = []
    for fila in filas:
        score, porque, coincide = _puntaje_tramo(fila, terminos, ruta, tokens_proceso)
        if score <= 0:
            continue
        ranked.append({**fila, "score": score, "porque": porque, "rutaCoincide": coincide})
    nombrados = _procesos_nombrados(terminos, modulo)
    if proceso_id:
        nombrados.add(proceso_id)
    if nombrados:
        if ruta:
            ranked = [
                item for item in ranked
                if item.get("rutaCoincide") or item.get("proceso") in nombrados
            ]
        else:
            ranked = [item for item in ranked if item.get("proceso") in nombrados]
    ranked.sort(key=lambda item: (
        -item["score"],
        0 if item["rutaCoincide"] else 1,
        str(item.get("proceso") or ""),
        int(item.get("orden") or 0),
        str(item.get("id") or ""),
    ))
    tramos = ranked[:8]
    procesos: list[str] = []
    for pantalla in pantallas:
        if pantalla.get("proceso") and pantalla["proceso"] not in procesos:
            procesos.append(pantalla["proceso"])
    for tramo in tramos:
        if tramo.get("proceso") and tramo["proceso"] not in procesos:
            procesos.append(tramo["proceso"])
    if proceso_id and proceso_id not in procesos:
        procesos.append(proceso_id)
    if not tramos:
        for pid in sorted(nombrados):
            if pid not in procesos:
                procesos.append(pid)
    procesos = procesos[:2]
    controles: list[dict] = []
    menu: list[dict] = []
    clave = _clave_pantalla(ruta)
    for pid in procesos:
        controles.extend(_controles_proceso(pid, terminos, tokens_proceso))
        menu.extend(_menu_coincidencias(pid, terminos, clave, tokens_proceso))
    hay_ruta = any(item.get("rutaCoincide") for item in tramos)
    ambiguo = not hay_ruta and (
        not tramos
        or tramos[0]["score"] < 8
        or (
            len(tramos) > 1
            and tramos[0]["proceso"] != tramos[1]["proceso"]
            and tramos[0]["score"] - tramos[1]["score"] < 4
        )
    )
    return {
        "ruta": ruta,
        "modulo": modulo,
        "procesoIdFormulario": proceso_id,
        "pantallas": pantallas,
        "tramos": tramos,
        "controles": controles[:6],
        "menu": menu[:6],
        "procesos": procesos,
        "ambiguo": ambiguo,
    }


def formato_mapa(mapa: dict) -> str:
    """Texto del mapa, al inicio del paso ubicar. El agente elige un tramo de esta lista."""
    if not mapa:
        return ""
    lineas = [
        "MAPA PARA UBICAR (elija un tramo de esta lista; no invente otro flujo "
        "ni nombre un procedimiento que no esté en el control de ese tramo):"
    ]
    if mapa.get("ruta"):
        lineas.append(f"Ruta del formulario: {mapa['ruta']}")
    else:
        lineas.append("Ruta del formulario: vacía. Sin ruta el tramo sale solo de las palabras y puede quedar ambiguo.")
    if mapa.get("modulo"):
        lineas.append(f"Módulo del formulario: {mapa['modulo']}")
    if mapa.get("procesoIdFormulario"):
        lineas.append(f"procesoId del formulario: {mapa['procesoIdFormulario']}")
    if mapa.get("pantallas"):
        lineas.append("Pantalla en la base:")
        for pantalla in mapa["pantallas"]:
            donde = pantalla.get("path") or pantalla.get("ruta") or ""
            lineas.append(
                f"  - {pantalla.get('proceso')} · {donde} · {pantalla.get('uso') or ''} · vue {pantalla.get('vue') or ''}"
            )
            if pantalla.get("entrada"):
                lineas.append(f"    entrada: {pantalla['entrada']}")
        form_pid = str(mapa.get("procesoIdFormulario") or "")
        pids = {p.get("proceso") for p in mapa["pantallas"]}
        if form_pid and form_pid not in pids:
            lineas.append(
                f"La ruta está en {mapa['pantallas'][0].get('proceso')}. "
                f"Ese es el proceso, aunque el formulario traiga {form_pid}."
            )
    else:
        lineas.append("Pantalla en la base: la ruta no está en el índice.")
    if mapa.get("tramos"):
        lineas.append("Tramos:")
        for tramo in mapa["tramos"]:
            marca = "RUTA " if tramo.get("rutaCoincide") else ""
            pantalla = tramo.get("pantalla")
            if isinstance(pantalla, list):
                pantalla = ", ".join(str(p) for p in pantalla)
            lineas.append(
                f"  - {marca}{tramo.get('proceso')} · {tramo.get('id')} · {tramo.get('nombre')}"
                f" · pantalla {pantalla} · control {tramo.get('controlClave')}"
            )
        if any(tramo.get("rutaCoincide") for tramo in mapa["tramos"]):
            lineas.append("Si un tramo dice RUTA, ese es el flujo. Un vecino con otra pantalla no participa.")
        elif mapa.get("ambiguo"):
            procesos = sorted({tramo.get("proceso") for tramo in mapa["tramos"] if tramo.get("proceso")})
            if len(procesos) == 1:
                lineas.append(
                    f"El proceso sí es {procesos[0]}. El tramo no. "
                    f"Deje procesoId={procesos[0]} y estado=pregunta, y pida la pantalla. "
                    "No elija la primera fila solo porque está de primera."
                )
            else:
                lineas.append(
                    "Ninguna ruta coincidió y el texto cae en más de un tramo. "
                    "Deje estado=pregunta y pida la pantalla."
                )
    elif mapa.get("pantallas"):
        lineas.append(
            "Tramos: no hay mapa de tramos para esta pantalla. "
            "El flujo es la pantalla de arriba y la pieza es esa ventana. No recorra otros procedimientos del módulo."
        )
    elif mapa.get("procesos"):
        lineas.append(
            "Tramos: ninguno de "
            + ", ".join(mapa["procesos"])
            + " coincide con el texto. No salte a otro módulo. "
            "Deje ese procesoId, estado=pregunta, y pida la pantalla."
        )
    else:
        lineas.append(
            "Tramos: ninguno coincide con la ruta ni con el texto. "
            "No elija un procedimiento del módulo. Deje estado=pregunta y pida la pantalla."
        )
    if mapa.get("menu"):
        lineas.append("Menú que coincide:")
        for item in mapa["menu"]:
            grupo = f"{item.get('grupo')} → " if item.get("grupo") else ""
            lineas.append(f"  - {item.get('proceso')} · {grupo}{item.get('item')}")
    if mapa.get("controles"):
        lineas.append("Controles de ese proceso que mencionan el pedido (no abren otro flujo):")
        for control in mapa["controles"]:
            lineas.append(f"  - {control.get('proceso')}/{control.get('id')}: {control.get('nombre')}")
    return "\n".join(lineas)


def _resumir_grafo(grafo_path: str) -> dict | None:
    """Resumen del índice de grafos (lista de grafos disponibles)."""
    path = KB / grafo_path
    if not path.is_file():
        return None
    
    data = kb_indice._leer(path, {}) or {}
    if not data.get("grafos"):
        return None
    
    return {
        "procedencia": data.get("procedencia") or data.get("modulo") or "",
        "grafos": [g.get("nombre") or g.get("id") for g in (data.get("grafos") or [])[:8]],
    }


def preseleccionar_contexto(req_texto: str, proceso_id: str = "") -> dict:
    """
    Preselecciona contexto relevante de la KB para un requerimiento.
    
    Args:
        req_texto: Texto del requerimiento/necesidad
        proceso_id: ID del proceso (si ya se conoce; si no, se intenta inferir)
    
    Returns:
        dict con proceso, sps, controles, grafos, rutas para abrir si hace falta
    """
    terminos, tags_inicio = _extraer_terminos_req(req_texto)
    
    # Si no hay proceso_id, intentar inferirlo por términos
    procesos_candidatos = set()
    if not proceso_id:
        idx = kb_buscar._cargar_indice()
        # Ordenar terminos para hacer búsquedas deterministas
        terminos_ordenados = sorted(terminos)
        for termino in terminos_ordenados[:10]:  # Limitar búsquedas
            resultado = kb_buscar.buscar(termino, limite=3)
            if not resultado.get("ok"):
                continue
            
            tipo = resultado.get("tipo")
            if tipo == "termino":
                # resultado["procesos"] es una lista de dicts con {"proceso": "id", ...}
                for p in resultado.get("procesos") or []:
                    if isinstance(p, dict) and p.get("proceso"):
                        procesos_candidatos.add(p["proceso"])
            elif tipo in ("sp", "metodo", "tabla", "pantalla", "control", "grafo"):
                # Resultados directos
                for r in resultado.get("resultados") or []:
                    if r.get("proceso"):
                        procesos_candidatos.add(r["proceso"])
            elif tipo == "sugerencias":
                # Búsqueda parcial: re-buscar las sugerencias más relevantes
                for sug in (resultado.get("sugerencias") or [])[:3]:
                    clave = sug.get("clave")
                    if clave:
                        res2 = kb_buscar.buscar(clave, limite=2)
                        if res2.get("ok") and res2.get("resultados"):
                            for r in res2.get("resultados") or []:
                                if r.get("proceso"):
                                    procesos_candidatos.add(r["proceso"])
    else:
        procesos_candidatos = {proceso_id}
    
    # Scoring de procesos candidatos
    if procesos_candidatos:
        idx_gen = kb_indice._leer(KB / "INDICE.json", {}) or {}
        meta_procs = {(p.get("id") or p.get("carpeta")): p for p in idx_gen.get("procesos") or []}
        
        def score_proceso(pid):
            """Score basado en: tags inicio (peso máximo), id/nombre/módulo (peso fuerte), keywords dominio, términos del REQ."""
            meta = meta_procs.get(pid) or {}
            score = 0
            
            # 0. PRIORIDAD: Match con tags de inicio del texto (peso 20)
            # Ejemplo: "PPTO — PRESUPUESTO Error..." debe priorizar presupuesto
            pid_norm = _normalizar_texto(pid)
            nombre = _normalizar_texto(meta.get("nombre") or "")
            modulo = _normalizar_texto(meta.get("modulo") or "")
            
            for tag in tags_inicio:
                tag_norm = _normalizar_texto(tag)
                if tag_norm:
                    # Match exacto con id/carpeta
                    if tag_norm == pid_norm:
                        score += 20
                    # Match en nombre o módulo
                    elif tag_norm in nombre or tag_norm in modulo:
                        score += 15
            
            # 1. Match exacto en id/carpeta (peso 10)
            for t in terminos:
                t_norm = _normalizar_texto(str(t))
                if t_norm and t_norm == pid_norm:
                    score += 10
            
            # 2. Match en nombre del proceso (peso 8)
            for t in terminos:
                t_norm = _normalizar_texto(str(t))
                if t_norm and len(t_norm) >= 4 and t_norm in nombre:
                    score += 8
            
            # 3. Match en módulo (peso 7)
            for t in terminos:
                t_norm = _normalizar_texto(str(t))
                if t_norm and len(t_norm) >= 4 and t_norm in modulo:
                    score += 7
            
            # 4. Match con keywords de dominio del proceso (peso 5)
            domain_kws = DOMAIN_KEYWORDS.get(pid, set())
            for t in terminos:
                t_norm = _normalizar_texto(str(t))
                if t_norm in domain_kws:
                    score += 5
            
            # 5. Match en resumen (peso 2)
            resumen = _normalizar_texto(meta.get("resumen") or "")
            for t in terminos:
                t_norm = _normalizar_texto(str(t))
                if t_norm and len(t_norm) >= 4 and t_norm in resumen:
                    score += 2
            
            # 6. Match en nombres de archivos grafo (peso 6)
            grafo_idx = meta.get("grafoIndice") or ""
            if grafo_idx:
                grafo_idx_norm = _normalizar_texto(grafo_idx)
                for t in terminos:
                    t_norm = _normalizar_texto(str(t))
                    if t_norm and len(t_norm) >= 4 and t_norm in grafo_idx_norm:
                        score += 6
            
            # 7. Estado del proceso (desempate)
            if meta.get("estado") == "completo":
                score += 1
            elif meta.get("estado") in ("documentado", "parcial"):
                score += 0.5
            
            return score
        
        # Ordenar por score y filtrar por umbral mínimo
        # Hacer determinista: ordenar también por pid para desempatar
        scored = [(pid, score_proceso(pid)) for pid in sorted(procesos_candidatos)]
        scored_filtered = [(pid, s) for pid, s in scored if s >= MIN_SCORE_THRESHOLD]
        scored_filtered.sort(key=lambda x: (-x[1], x[0]))  # Score desc, pid asc (determinista)
        
        if not scored_filtered:
            # Ningún proceso alcanza el umbral mínimo
            procesos_candidatos = set()
        else:
            # Tomar los top 2
            procesos_candidatos = set(pid for pid, _ in scored_filtered[:2])
    
    # Construir contexto compacto
    contexto = {
        "procesos": [],
        "rutas_abrir": [],
        "advertencia": "",
    }
    
    total_chars = 0
    for pid in sorted(procesos_candidatos):
        if total_chars >= MAX_CHARS_CONTEXTO:
            contexto["advertencia"] = f"Contexto truncado (límite {MAX_CHARS_CONTEXTO} caracteres)"
            break
        
        meta = _cargar_proceso_meta(pid)
        if not meta:
            continue
        
        proc_ctx = {
            "id": pid,
            "nombre": meta.get("nombre") or pid,
            "modulo": meta.get("modulo") or "",
            "estado": meta.get("estado") or "",
            "resumen": (meta.get("resumen") or "")[:400],
            "sps": _resumir_sps(pid, terminos=terminos),
            "controles": _resumir_controles(pid),
            "yaCubiertas": _resumir_cubiertas(pid, terminos),
        }
        
        # Grafo si existe
        grafo_path = _buscar_grafo_indice(pid)
        if grafo_path:
            grafo_resumen = _resumir_grafo(grafo_path)
            if grafo_resumen:
                proc_ctx["grafo"] = grafo_resumen
                contexto["rutas_abrir"].append(f"conocimiento/{grafo_path}")
        
        # Rutas para abrir si se necesita más detalle
        contexto["rutas_abrir"].extend([
            f"conocimiento/{pid}/proceso.json",
            f"conocimiento/{pid}/sps.json",
        ])
        
        contexto["procesos"].append(proc_ctx)
        total_chars += len(json.dumps(proc_ctx, ensure_ascii=False))
    
    return contexto


def formato_prompt(contexto: dict) -> str:
    """Formatea el contexto para incluir en el prompt del agente."""
    if not contexto.get("procesos"):
        return ""
    
    lineas = ["CONTEXTO KB PRESELECCIONADO (usar primero; evita barrer conocimiento/):"]
    
    for proc in contexto["procesos"]:
        lineas.append(f"\nProceso: {proc['nombre']} ({proc['id']}) · {proc['modulo']} · estado={proc['estado']}")
        if proc.get("resumen"):
            lineas.append(f"  Resumen: {proc['resumen']}")
        
        if proc.get("sps"):
            lineas.append(f"  SPs ({len(proc['sps'])} principales):")
            for sp in proc["sps"]:
                metodos_txt = ", ".join(m["id"] for m in sp.get("metodos") or [])
                lineas.append(f"    - {sp['nombre']} (estado={sp['estado']}) · METODOs: {metodos_txt}")
                for m in sp.get("metodos") or []:
                    detalle = []
                    for clave, etiqueta in (
                        ("hace", "hace"),
                        ("valida", "valida"),
                        ("noValida", "no valida"),
                        ("efecto", "efecto"),
                        ("llama", "llama"),
                        ("errores", "error"),
                    ):
                        if m.get(clave):
                            detalle.append(f"{etiqueta}: {m[clave]}")
                    if detalle:
                        lineas.append(f"      {m['id']}: " + " · ".join(detalle[:4]))

        if proc.get("yaCubiertas"):
            lineas.append("  Necesidades ya cubiertas (si el REQ coincide, es capacitación, no desarrollo):")
            for item in proc["yaCubiertas"]:
                extra = f" — no es: {item['noEs']}" if item.get("noEs") else ""
                lineas.append(f"    - {item.get('necesidad') or ''} → {item.get('donde') or ''}{extra}")
        
        if proc.get("controles"):
            lineas.append(f"  Controles ({len(proc['controles'])}):")
            for ctl in proc["controles"]:
                lineas.append(f"    - {ctl['id']}: {ctl['nombre']}")
                if ctl.get("validaSi"):
                    lineas.append(f"      valida si: {ctl['validaSi']}")
        
        if proc.get("grafo"):
            lineas.append(f"  Grafos disponibles: {', '.join(proc['grafo'].get('grafos') or [])}")
    
    if contexto.get("rutas_abrir"):
        lineas.append("\nSi necesita más detalle, abrir SOLO:")
        for ruta in contexto["rutas_abrir"][:8]:
            lineas.append(f"  - {ruta}")
    
    if contexto.get("advertencia"):
        lineas.append(f"\n⚠ {contexto['advertencia']}")
    
    lineas.append("\nPRESUPUESTO DE HERRAMIENTAS:")
    lineas.append("  - Este recorte orienta. No es el análisis ni el cambio.")
    lineas.append("  - No barra conocimiento/ ni lea un sps.json entero ni el INDICE completo.")
    lineas.append("  - Para el METODO de este cambio abra la ficha completa y, si el cambio es SQL, el cuerpo de ese procedimiento.")
    lineas.append("  - Tope orientativo ~28 lecturas, gastadas en este control (ficha, SQL del método, Vue de la pantalla).")
    lineas.append("  - No escriba la solución hasta tener clasificación, flujo de hoy y el bloque que cambia.")
    
    return "\n".join(lineas)


def main(argv: list[str]) -> int:
    """CLI para testing."""
    import argparse
    
    # Ensure UTF-8 stdout
    if sys.stdout.encoding != 'utf-8':
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--req", required=True, help="Texto del requerimiento")
    ap.add_argument("--proceso", default="", help="ID del proceso (opcional)")
    ap.add_argument("--json", action="store_true", help="Salida en JSON")
    args = ap.parse_args(argv)
    
    contexto = preseleccionar_contexto(args.req, args.proceso)
    
    if args.json:
        print(json.dumps(contexto, ensure_ascii=False, indent=2))
    else:
        print(formato_prompt(contexto))
    
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
