#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Preselección de contexto KB para análisis de requerimientos.

Entrega el recorte del proceso (fichas, controles, necesidades ya cubiertas)
para no barrer conocimiento/. El recorte orienta; no reemplaza la ficha
completa del METODO ni el cuerpo SQL del bloque que el cambio toca.
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
    return None


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
