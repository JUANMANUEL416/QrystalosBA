"""Ilustraciones de capacitación con OpenAI (mapas mentales, diagramas de proceso).

Para casos de capacitación (meta.tipo='capacitacion' o guion-capacitacion.md),
genera visuales vía OpenAI Images: mapa mental de los temas principales y
diagramas por sección del guion.
"""
from __future__ import annotations

import base64
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _es_capacitacion(meta: dict, carpeta: Path) -> bool:
    """Determina si el caso es de capacitación."""
    # 1. Campo explícito en meta
    if meta.get("tipo") == "capacitacion":
        return True
    
    # 2. Marca entregaRequerimiento con contenido de capacitación
    if meta.get("entregaRequerimiento"):
        pregunta = (meta.get("preguntaInicial") or "").lower()
        if any(palabra in pregunta for palabra in [
            "capacitación", "capacitacion", "capacitar",
            "entrenar", "entrenamiento", "formación", "formacion",
            "manual", "guía", "guia", "tutorial"
        ]):
            return True
    
    # 3. Existe guion-capacitacion.md
    material = carpeta / "material"
    if (material / "guion-capacitacion.md").is_file():
        return True
    
    return False


def _extraer_secciones(guion_path: Path) -> list[dict]:
    """Extrae las secciones principales del guion de capacitación."""
    texto = guion_path.read_text(encoding="utf-8")
    secciones = []
    
    # Buscar títulos ## (h2)
    for match in re.finditer(r"^##\s+(.+?)$", texto, re.MULTILINE):
        titulo = match.group(1).strip()
        inicio = match.end()
        
        # Buscar el siguiente título o final del documento
        siguiente = re.search(r"^##\s+", texto[inicio:], re.MULTILINE)
        fin = inicio + siguiente.start() if siguiente else len(texto)
        
        contenido = texto[inicio:fin].strip()
        
        # Extraer los primeros 400 caracteres o hasta el primer bloque de código
        resumen = contenido[:400]
        codigo_idx = resumen.find("```")
        if codigo_idx > 0:
            resumen = resumen[:codigo_idx]
        
        secciones.append({
            "titulo": titulo,
            "resumen": resumen.strip(),
        })
    
    return secciones[:6]  # Máximo 6 secciones


def _limpiar_texto_para_prompt(texto: str) -> str:
    """Limpia el texto para el prompt de imagen: sin SQL, sin rutas internas, sin credenciales."""
    # Quitar bloques de código SQL
    texto = re.sub(r"```(?:sql|tsql|mssql).*?```", "", texto, flags=re.DOTALL | re.IGNORECASE)
    
    # Quitar rutas internas
    texto = re.sub(r"(?:activo|conocimiento|sql_refe|data)/[^\s]+", "", texto)
    
    # Quitar comandos de Python
    texto = re.sub(r"python\s+scripts/[^\s]+", "", texto)
    
    # Quitar referencias a DESAIX/SQLIX
    texto = re.sub(r"DESAIX|SQLIX", "", texto)
    
    # Quitar menciones a stored procedures
    texto = re.sub(r"SP[QK]_\w+", "", texto)
    
    return " ".join(texto.split())


def _prompt_mapa_mental(titulo: str, secciones: list[dict]) -> str:
    """Genera el prompt para el mapa mental de capacitación."""
    temas = []
    for sec in secciones[:5]:
        tema = sec["titulo"]
        # Quitar numeración si existe
        tema = re.sub(r"^\d+\.\s*", "", tema)
        temas.append(tema)
    
    lista_temas = "\n".join(f"- {t}" for t in temas)
    
    return f"""Mapa mental de capacitación para Qrystalos (sistema hospitalario HIS).
IDIOMA: español de Colombia exclusivamente. Cero palabras en inglés.
Estilo: diagrama vectorial limpio, nodos conectados con líneas, iconos minimalistas.
Colores: naranja #E67817 para nodos principales, grises y azules suaves para secundarios.
Sin logotipos, sin fotos, sin código SQL.

Título principal: {titulo}

Temas principales:
{lista_temas}

Organizar los temas de forma radial o jerárquica, mostrando las conexiones entre conceptos."""


def _prompt_ilustracion_seccion(titulo: str, contenido: str) -> str:
    """Genera el prompt para ilustrar una sección del guion."""
    contenido_limpio = _limpiar_texto_para_prompt(contenido)[:500]
    
    return f"""Infografía de proceso para capacitación en Qrystalos (sistema hospitalario HIS).
IDIOMA: español de Colombia exclusivamente. Cero palabras en inglés.
Estilo: diagrama de flujo o infografía vectorial limpia, iconos minimalistas.
Colores: naranja #E67817 para énfasis, grises y azules para pasos.
Sin logotipos, sin fotos, sin código SQL, sin tecnicismos de base de datos.

Sección: {titulo}

Contexto del proceso:
{contenido_limpio}

Mostrar los pasos principales del proceso de forma visual y clara, usando pantallas, estados o flujos."""


def generar_ilustraciones(sid: str, meta: dict) -> dict:
    """Genera ilustraciones para un caso de capacitación usando OpenAI Images."""
    import openai_sugerir as oai
    import soporte_consultas as sc
    
    carpeta = sc.carpeta_consulta(sid)
    
    # Verificar si es caso de capacitación
    if not _es_capacitacion(meta, carpeta):
        return {
            "ok": False,
            "error": "no_capacitacion",
            "mensaje": "Este caso no es de capacitación. Use el flujo normal de ilustraciones."
        }
    
    # Verificar configuración de OpenAI
    cfg = oai.load_config()
    if not cfg["apiKey"]:
        return {
            "ok": False,
            "error": "sin_api_key",
            "mensaje": "Falta OPENAI_API_KEY en .env para generar ilustraciones de capacitación."
        }
    
    # Buscar el guion de capacitación
    material = carpeta / "material"
    guion_path = material / "guion-capacitacion.md"
    documento_path = material / "documento.md"
    
    fuente = None
    if guion_path.is_file():
        fuente = guion_path
    elif documento_path.is_file():
        fuente = documento_path
    else:
        return {
            "ok": False,
            "error": "sin_guion",
            "mensaje": "No se encontró guion-capacitacion.md ni documento.md en material/"
        }
    
    titulo = meta.get("titulo", "Capacitación Qrystalos")
    secciones = _extraer_secciones(fuente)
    
    if not secciones:
        return {
            "ok": False,
            "error": "sin_contenido",
            "mensaje": "El guion de capacitación no tiene secciones identificables."
        }
    
    imagenes_dir = carpeta / "imagenes"
    imagenes_dir.mkdir(parents=True, exist_ok=True)
    
    ilustraciones = []
    
    # 1. Generar mapa mental de los temas
    try:
        prompt_mapa = _prompt_mapa_mental(titulo, secciones)
        dest_mapa = imagenes_dir / "capacitacion-mapa-mental.png"
        
        result_mapa = oai.generar_imagen(prompt_mapa, str(dest_mapa), size="1536x1024")
        
        if result_mapa.get("ok"):
            item_mapa = {
                "nombre": dest_mapa.name,
                "url": f"/api/soporte-consultas/{sid}/imagen/{dest_mapa.name}",
                "origen": "openai",
                "titulo": f"Mapa mental: {titulo}",
                "tipo": "mapa_mental",
                "subidaEn": datetime.now().isoformat(timespec="seconds"),
            }
            ilustraciones.append(item_mapa)
    except Exception as e:
        # Continuar con las demás ilustraciones incluso si el mapa falla
        pass
    
    # 2. Generar ilustraciones por sección (máximo 3)
    for idx, seccion in enumerate(secciones[:3], 1):
        try:
            prompt_sec = _prompt_ilustracion_seccion(
                seccion["titulo"],
                seccion["resumen"]
            )
            dest_sec = imagenes_dir / f"capacitacion-seccion-{idx}.png"
            
            result_sec = oai.generar_imagen(prompt_sec, str(dest_sec), size="1536x1024")
            
            if result_sec.get("ok"):
                item_sec = {
                    "nombre": dest_sec.name,
                    "url": f"/api/soporte-consultas/{sid}/imagen/{dest_sec.name}",
                    "origen": "openai",
                    "titulo": seccion["titulo"],
                    "tipo": "seccion",
                    "subidaEn": datetime.now().isoformat(timespec="seconds"),
                }
                ilustraciones.append(item_sec)
        except Exception:
            # Continuar con las demás secciones si una falla
            continue
    
    if not ilustraciones:
        return {
            "ok": False,
            "error": "generacion_fallida",
            "mensaje": "No se pudo generar ninguna ilustración. Verifique la configuración de OpenAI."
        }
    
    # Actualizar meta.json con las ilustraciones generadas
    imgs_actuales = meta.get("imagenes") or []
    # Quitar ilustraciones anteriores de capacitación
    imgs_actuales = [
        i for i in imgs_actuales
        if not (i.get("origen") == "openai" and i.get("tipo") in ("mapa_mental", "seccion"))
    ]
    imgs_actuales.extend(ilustraciones)
    
    sc.actualizar_meta(sid, imagenes=imgs_actuales)
    
    # Escribir mensaje en el chat
    sc.append_chat(
        sid,
        "sistema",
        f"Se generaron {len(ilustraciones)} ilustración(es) de capacitación con OpenAI: "
        f"{'mapa mental y ' if any(i['tipo'] == 'mapa_mental' for i in ilustraciones) else ''}"
        f"{sum(1 for i in ilustraciones if i['tipo'] == 'seccion')} sección(es)."
    )
    
    return {
        "ok": True,
        "ilustraciones": ilustraciones,
        "total": len(ilustraciones),
        "modelo": cfg.get("modelo", "openai")
    }
