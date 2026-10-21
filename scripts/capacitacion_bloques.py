"""Generador y gestor de bloques de capacitación modulares.

Genera bloques desde la base de conocimiento (conocimiento/), reutilizando
scripts/capacitacion_ilustracion.py para ilustraciones.
"""
from __future__ import annotations

import json
import re
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONOCIMIENTO = ROOT / "conocimiento"
CAPACITACION = ROOT / "capacitacion"
BLOQUES_DIR = CAPACITACION / "bloques"
TEMAS_FILE = CAPACITACION / "temas.json"


def cargar_temas() -> dict:
    """Carga el catálogo de temas de capacitación."""
    if not TEMAS_FILE.is_file():
        return {"temas": []}
    with open(TEMAS_FILE, encoding="utf-8") as f:
        return json.load(f)


def cargar_indice_kb() -> dict:
    """Carga el índice de procesos de la KB."""
    indice_path = CONOCIMIENTO / "INDICE.json"
    if not indice_path.is_file():
        return {"procesos": []}
    with open(indice_path, encoding="utf-8") as f:
        return json.load(f)


def cargar_proceso(proceso_id: str) -> dict | None:
    """Carga el proceso.json de un proceso específico."""
    proceso_path = CONOCIMIENTO / proceso_id / "proceso.json"
    if not proceso_path.is_file():
        return None
    with open(proceso_path, encoding="utf-8") as f:
        return json.load(f)


def listar_bloques() -> list[dict]:
    """Lista todos los bloques existentes con sus metadatos."""
    bloques = []
    if not BLOQUES_DIR.exists():
        return bloques
    
    for bloque_dir in sorted(BLOQUES_DIR.iterdir()):
        if not bloque_dir.is_dir():
            continue
        bloque_json = bloque_dir / "bloque.json"
        if bloque_json.is_file():
            with open(bloque_json, encoding="utf-8") as f:
                meta = json.load(f)
                bloques.append(meta)
    
    return bloques


def obtener_bloque(bloque_id: str) -> dict | None:
    """Obtiene los metadatos de un bloque específico."""
    bloque_path = BLOQUES_DIR / bloque_id / "bloque.json"
    if not bloque_path.is_file():
        return None
    with open(bloque_path, encoding="utf-8") as f:
        return json.load(f)


def leer_contenido_bloque(bloque_id: str) -> str:
    """Lee el contenido Markdown de un bloque."""
    contenido_path = BLOQUES_DIR / bloque_id / "contenido.md"
    if not contenido_path.is_file():
        return ""
    return contenido_path.read_text(encoding="utf-8")


def _slug(texto: str) -> str:
    """Convierte texto a slug kebab-case."""
    texto = texto.lower()
    texto = re.sub(r"[áàäâ]", "a", texto)
    texto = re.sub(r"[éèëê]", "e", texto)
    texto = re.sub(r"[íìïî]", "i", texto)
    texto = re.sub(r"[óòöô]", "o", texto)
    texto = re.sub(r"[úùüû]", "u", texto)
    texto = re.sub(r"[ñ]", "n", texto)
    texto = re.sub(r"[^a-z0-9]+", "-", texto)
    return texto.strip("-")


def _inferir_tema_proceso(proceso: dict) -> str | None:
    """Infiere el tema principal de un proceso según su familia/módulo."""
    familia = proceso.get("familia", "").lower()
    modulo = proceso.get("modulo", "").lower()
    
    mapeo = {
        "inventario": "inventario",
        "cartera": "cartera",
        "facturacion": "facturacion",
        "caja": "caja",
        "financiero": "cxp",
        "contabilidad": "contabilidad",
    }
    
    if familia in mapeo:
        return mapeo[familia]
    
    # Por módulo
    if "inventario" in modulo:
        return "inventario"
    if "fpag" in modulo or "fglo" in modulo or "fnot" in modulo or "fconci" in modulo:
        return "cartera"
    if "ftr" in modulo or "rips" in modulo or "dian" in modulo:
        return "facturacion"
    if "caja" in modulo:
        return "caja"
    if "fcxp" in modulo:
        return "cxp"
    if "contab" in modulo:
        return "contabilidad"
    
    return None


def generar_bloque_desde_control(
    proceso_id: str,
    control_id: str,
    capa_numero: int | None = None,
    forzar: bool = False
) -> dict:
    """Genera un bloque de capacitación desde un control de la KB.
    
    Args:
        proceso_id: ID del proceso en conocimiento/
        control_id: ID del control dentro del proceso
        capa_numero: Número de la capa (opcional, se infiere si falta)
        forzar: Si True, regenera aunque ya exista y esté estable
    
    Returns:
        Resultado con ok, bloque_id y mensaje
    """
    proceso = cargar_proceso(proceso_id)
    if not proceso:
        return {
            "ok": False,
            "error": "proceso_no_existe",
            "mensaje": f"No se encontró el proceso '{proceso_id}' en la KB."
        }
    
    # Buscar el control
    control = None
    capa_encontrada = None
    for capa in proceso.get("capas", []):
        for ctrl in capa.get("controles", []):
            if ctrl.get("id") == control_id:
                control = ctrl
                capa_encontrada = capa
                break
        if control:
            break
    
    if not control:
        return {
            "ok": False,
            "error": "control_no_existe",
            "mensaje": f"No se encontró el control '{control_id}' en el proceso '{proceso_id}'."
        }
    
    # Generar ID del bloque
    bloque_id = _slug(control.get("nombre", control_id))
    bloque_dir = BLOQUES_DIR / bloque_id
    
    # Verificar si ya existe y es estable
    if bloque_dir.exists() and not forzar:
        bloque_existente = obtener_bloque(bloque_id)
        if bloque_existente and bloque_existente.get("estable"):
            return {
                "ok": False,
                "error": "bloque_estable",
                "bloque_id": bloque_id,
                "mensaje": f"El bloque '{bloque_id}' ya existe y está marcado como estable. Use forzar=True para regenerar."
            }
    
    # Inferir tema
    tema = _inferir_tema_proceso(proceso)
    temas = [tema] if tema else []
    
    # Crear metadatos del bloque
    bloque_meta = {
        "id": bloque_id,
        "titulo": control.get("nombre", ""),
        "version": "1.0.0",
        "temas": temas,
        "procesos": [proceso_id],
        "orden": {
            tema: capa_encontrada.get("numero", 1) if tema else 1
        },
        "prerrequisitos": [],
        "variantes": [],
        "duracionEstimada": "30min",
        "fuente": {
            "proceso": proceso_id,
            "capa": capa_encontrada.get("id") if capa_encontrada else None,
            "control": control_id,
            "actualizado": proceso.get("actualizado", datetime.now().isoformat())
        },
        "palabrasClave": _extraer_palabras_clave(control),
        "estable": False,
        "generado": datetime.now().isoformat(timespec="seconds")
    }
    
    # Generar contenido Markdown
    contenido_md = _generar_contenido_control(proceso, capa_encontrada, control)
    
    # Crear directorio del bloque
    bloque_dir.mkdir(parents=True, exist_ok=True)
    imagenes_dir = bloque_dir / "imagenes"
    imagenes_dir.mkdir(exist_ok=True)
    
    # Guardar metadatos
    with open(bloque_dir / "bloque.json", "w", encoding="utf-8") as f:
        json.dump(bloque_meta, f, indent=2, ensure_ascii=False)
    
    # Guardar contenido
    (bloque_dir / "contenido.md").write_text(contenido_md, encoding="utf-8")
    
    return {
        "ok": True,
        "bloque_id": bloque_id,
        "bloque_dir": str(bloque_dir),
        "mensaje": f"Bloque '{bloque_id}' generado exitosamente."
    }


def _extraer_palabras_clave(control: dict) -> list[str]:
    """Extrae palabras clave del control."""
    palabras = set()
    
    # Del nombre
    nombre = control.get("nombre", "")
    palabras.update(re.findall(r"\b[A-Z]{3,}\b", nombre))
    
    # De la explicación
    explicacion = control.get("explicacion", "")
    palabras.update(re.findall(r"\b[A-Z]{3,}\b", explicacion))
    
    # De los SPs mencionados
    for sp in control.get("sps", []):
        nombre_sp = sp.get("nombre", "")
        if nombre_sp:
            palabras.add(nombre_sp)
    
    return sorted(list(palabras))


def _generar_contenido_control(proceso: dict, capa: dict | None, control: dict) -> str:
    """Genera el contenido Markdown de un control."""
    lineas = []
    
    # Título
    lineas.append(f"# {control.get('nombre', 'Control')}")
    lineas.append("")
    
    # Contexto del proceso
    lineas.append("## Contexto")
    lineas.append("")
    lineas.append(f"**Proceso:** {proceso.get('nombre', '')}")
    if capa:
        lineas.append(f"**Capa:** {capa.get('nombre', '')}")
    lineas.append("")
    
    # Explicación
    if control.get("explicacion"):
        lineas.append("## Explicación")
        lineas.append("")
        lineas.append(control["explicacion"])
        lineas.append("")
    
    # Invariante
    if control.get("invariante"):
        lineas.append("## Invariante")
        lineas.append("")
        lineas.append(f"> {control['invariante']}")
        lineas.append("")
    
    # SPs relacionados
    sps = control.get("sps", [])
    if sps:
        lineas.append("## Procedimientos almacenados")
        lineas.append("")
        for sp in sps:
            lineas.append(f"### {sp.get('nombre', '')}")
            if sp.get("metodo"):
                lineas.append(f"**Método:** `{sp['metodo']}`")
            if sp.get("rol"):
                lineas.append(f"**Rol:** {sp['rol']}")
            lineas.append("")
    
    # Errores comunes
    errores = control.get("errores", [])
    if errores:
        lineas.append("## Errores comunes")
        lineas.append("")
        for err in errores:
            mensaje = err.get("mensaje", "")
            solucion = err.get("solucion", "")
            lineas.append(f"- **{mensaje}**")
            if solucion:
                lineas.append(f"  - {solucion}")
        lineas.append("")
    
    return "\n".join(lineas)


def listar_bloques_por_tema(tema_id: str) -> list[dict]:
    """Lista bloques que pertenecen a un tema, ordenados."""
    bloques = listar_bloques()
    bloques_tema = [
        b for b in bloques
        if tema_id in b.get("temas", [])
    ]
    
    # Ordenar por el orden del tema
    bloques_tema.sort(key=lambda b: b.get("orden", {}).get(tema_id, 999))
    
    return bloques_tema


def resolver_dependencias(bloques_seleccionados: list[str]) -> dict:
    """Resuelve las dependencias de los bloques seleccionados.
    
    Returns:
        {
            "ok": bool,
            "orden": list[str],  # IDs en orden de ejecución
            "faltantes": list[str]  # IDs de prerrequisitos que faltan
        }
    """
    todos_bloques = {b["id"]: b for b in listar_bloques()}
    
    # Verificar que existen
    faltantes = [bid for bid in bloques_seleccionados if bid not in todos_bloques]
    if faltantes:
        return {
            "ok": False,
            "error": "bloques_no_existen",
            "faltantes": faltantes
        }
    
    # Agregar prerrequisitos
    necesarios = set(bloques_seleccionados)
    por_procesar = list(bloques_seleccionados)
    
    while por_procesar:
        bloque_id = por_procesar.pop(0)
        bloque = todos_bloques.get(bloque_id)
        if not bloque:
            continue
        
        for prereq in bloque.get("prerrequisitos", []):
            if prereq not in necesarios:
                necesarios.add(prereq)
                por_procesar.append(prereq)
    
    # Ordenar topológicamente
    orden = []
    pendientes = list(necesarios)
    iteraciones = 0
    max_iter = len(necesarios) * 2
    
    while pendientes and iteraciones < max_iter:
        iteraciones += 1
        agregados = []
        
        for bid in pendientes:
            bloque = todos_bloques.get(bid)
            if not bloque:
                continue
            
            prereqs = bloque.get("prerrequisitos", [])
            if all(p in orden for p in prereqs):
                orden.append(bid)
                agregados.append(bid)
        
        for bid in agregados:
            pendientes.remove(bid)
    
    if pendientes:
        return {
            "ok": False,
            "error": "dependencias_circulares",
            "pendientes": pendientes
        }
    
    # Reportar prerrequisitos que no estaban en la selección original
    prereqs_agregados = [bid for bid in orden if bid not in bloques_seleccionados]
    
    return {
        "ok": True,
        "orden": orden,
        "agregados": prereqs_agregados,
        "total": len(orden)
    }


def generar_ilustracion_bloque(bloque_id: str, regenerar: bool = False) -> dict:
    """Genera ilustraciones para un bloque usando OpenAI Images.
    
    Args:
        bloque_id: ID del bloque
        regenerar: Si True, regenera aunque ya existan imágenes
    
    Returns:
        {
            "ok": bool,
            "imagenes": list[dict],  # Metadatos de las imágenes generadas
            "error": str  # Solo si ok=False
        }
    """
    import openai_sugerir as oai
    
    bloque = obtener_bloque(bloque_id)
    if not bloque:
        return {
            "ok": False,
            "error": "bloque_no_existe",
            "mensaje": f"No se encontró el bloque '{bloque_id}'."
        }
    
    bloque_dir = BLOQUES_DIR / bloque_id
    imagenes_dir = bloque_dir / "imagenes"
    
    # Verificar si ya tiene imágenes
    if not regenerar and imagenes_dir.exists():
        imagenes_existentes = list(imagenes_dir.glob("*.png"))
        if imagenes_existentes:
            return {
                "ok": False,
                "error": "imagenes_existentes",
                "mensaje": f"El bloque '{bloque_id}' ya tiene {len(imagenes_existentes)} imagen(es). Use regenerar=True para recrearlas."
            }
    
    # Verificar configuración de OpenAI
    cfg = oai.load_config()
    if not cfg["apiKey"]:
        return {
            "ok": False,
            "error": "sin_api_key",
            "mensaje": "Falta OPENAI_API_KEY en .env para generar ilustraciones."
        }
    
    contenido = leer_contenido_bloque(bloque_id)
    if not contenido:
        return {
            "ok": False,
            "error": "sin_contenido",
            "mensaje": f"El bloque '{bloque_id}' no tiene contenido.md."
        }
    
    imagenes_dir.mkdir(parents=True, exist_ok=True)
    imagenes = []
    
    # 1. Mapa mental del control
    try:
        prompt_mapa = f"""Mapa mental de capacitación para Qrystalos (sistema hospitalario HIS).
IDIOMA: español de Colombia exclusivamente. Cero palabras en inglés.
Estilo: diagrama vectorial limpio, nodos conectados con líneas, iconos minimalistas.
Colores: naranja #E67817 para nodos principales, grises y azules suaves para secundarios.
Sin logotipos, sin fotos, sin código SQL.

Título: {bloque['titulo']}

Mostrar los conceptos clave y sus relaciones de forma visual."""
        
        dest_mapa = imagenes_dir / "mapa-mental.png"
        result = oai.generar_imagen(prompt_mapa, str(dest_mapa), size="1536x1024")
        
        if result.get("ok"):
            imagenes.append({
                "nombre": "mapa-mental.png",
                "tipo": "mapa_mental",
                "titulo": f"Mapa mental: {bloque['titulo']}",
                "generado": datetime.now().isoformat(timespec="seconds")
            })
    except Exception:
        pass
    
    # 2. Infografía del proceso
    try:
        # Tomar los primeros 600 caracteres del contenido
        resumen = contenido[:600]
        codigo_idx = resumen.find("```")
        if codigo_idx > 0:
            resumen = resumen[:codigo_idx]
        
        prompt_infografia = f"""Infografía de proceso para capacitación en Qrystalos (sistema hospitalario HIS).
IDIOMA: español de Colombia exclusivamente. Cero palabras en inglés.
Estilo: diagrama de flujo o infografía vectorial limpia, iconos minimalistas.
Colores: naranja #E67817 para énfasis, grises y azules para pasos.
Sin logotipos, sin fotos, sin código SQL, sin tecnicismos de base de datos.

Tema: {bloque['titulo']}

Contexto:
{resumen}

Mostrar los pasos principales del proceso de forma visual y clara."""
        
        dest_infografia = imagenes_dir / "infografia.png"
        result = oai.generar_imagen(prompt_infografia, str(dest_infografia), size="1536x1024")
        
        if result.get("ok"):
            imagenes.append({
                "nombre": "infografia.png",
                "tipo": "infografia",
                "titulo": f"Infografía: {bloque['titulo']}",
                "generado": datetime.now().isoformat(timespec="seconds")
            })
    except Exception:
        pass
    
    if not imagenes:
        return {
            "ok": False,
            "error": "generacion_fallida",
            "mensaje": "No se pudo generar ninguna ilustración."
        }
    
    # Actualizar metadatos del bloque
    bloque["imagenes"] = imagenes
    with open(bloque_dir / "bloque.json", "w", encoding="utf-8") as f:
        json.dump(bloque, f, indent=2, ensure_ascii=False)
    
    return {
        "ok": True,
        "imagenes": imagenes,
        "total": len(imagenes)
    }
