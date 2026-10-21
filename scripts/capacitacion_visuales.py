#!/usr/bin/env python3
"""
Generador de elementos visuales para capacitaciones:
- Mapas mentales y diagramas (Cursor AI → SVG/Mermaid)
- Ilustraciones tipo dibujo (OpenAI Images API)
- Fallback SVG local

Orden de prioridad (configurable en .env):
1. Cursor AI SDK (CURSOR_API_KEY) - Genera SVG/infografías de calidad
2. OpenAI Images (OPENAI_API_KEY) - Solo para ilustraciones tipo dibujo
3. Generador SVG local - Respaldo final
"""
import os
import json
import base64
import re
from pathlib import Path
from typing import Optional


def generar_visual_con_cursor(
    tipo: str,
    tema: str,
    conceptos: list[dict],
    cache_path: Optional[Path] = None
) -> Optional[str]:
    """Genera visualización de calidad usando Cursor AI SDK.
    
    Args:
        tipo: "mapa-mental", "infografia", "diagrama-flujo"
        tema: Tema central
        conceptos: Lista de conceptos con 'titulo' e 'items'
        cache_path: Ruta para cachear el resultado
    
    Returns:
        Código SVG/HTML o None si falla
    """
    # Verificar cache
    if cache_path and cache_path.exists():
        try:
            return cache_path.read_text(encoding="utf-8")
        except Exception:
            pass
    
    # Verificar API key
    cursor_api_key = os.getenv("CURSOR_API_KEY")
    if not cursor_api_key:
        print("  ⚠️  CURSOR_API_KEY no configurada, usando fallback")
        return None
    
    # Modelos disponibles (configurables en .env)
    # Orden de prioridad según CAPACITACION_VISUAL_MODEL
    modelo_preferido = os.getenv("CAPACITACION_VISUAL_MODEL", "gpt-5.6-sol-medium")
    modelos_fallback = [
        "gpt-5.6-sol-medium",
        "claude-sonnet-5-5-medium",
        "gemini-4-argon-medium",
        "claude-opus-5-5-medium",
        "composer-2.5"
    ]
    
    # Crear lista con modelo preferido primero
    modelos = [modelo_preferido] + [m for m in modelos_fallback if m != modelo_preferido]
    
    # Preparar prompt según tipo
    if tipo == "mapa-mental":
        prompt = _crear_prompt_mapa_mental(tema, conceptos)
    elif tipo == "infografia":
        prompt = _crear_prompt_infografia(tema, conceptos)
    elif tipo == "diagrama-flujo":
        prompt = _crear_prompt_diagrama(tema, conceptos)
    else:
        return None
    
    # Intentar con cada modelo
    for modelo in modelos:
        try:
            svg_code = _llamar_cursor_sdk(prompt, modelo, cursor_api_key)
            
            if svg_code:
                # Cachear
                if cache_path:
                    cache_path.parent.mkdir(parents=True, exist_ok=True)
                    cache_path.write_text(svg_code, encoding="utf-8")
                
                return svg_code
        
        except Exception as e:
            print(f"  ⚠️  Error con modelo {modelo}: {e}")
            continue
    
    print("  ⚠️  Ningún modelo de Cursor funcionó, usando fallback local")
    return None


def _llamar_cursor_sdk(prompt: str, modelo: str, api_key: str) -> Optional[str]:
    """Llama al SDK de Cursor usando cursor_sdk.
    
    Args:
        prompt: Prompt para el modelo
        modelo: ID del modelo (ej: "gpt-5.6-sol-medium")
        api_key: API key de Cursor
    
    Returns:
        Código SVG generado o None
    """
    try:
        from cursor_sdk import CursorSDK, ModelSelection
        
        # Configurar SDK
        sdk = CursorSDK(api_key=api_key)
        
        # Crear selección de modelo
        model_selection = ModelSelection(id=modelo)
        
        # Llamar al modelo
        response = sdk.chat.completions.create(
            model=model_selection,
            messages=[
                {
                    "role": "system",
                    "content": "Eres un experto diseñador de infografías y visualizaciones SVG. Generas código SVG profesional, standalone y completo."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            max_tokens=4000,
            temperature=0.7
        )
        
        # Extraer contenido
        contenido = response.choices[0].message.content
        
        # Extraer SVG del código si viene envuelto
        svg_match = re.search(r'<svg.*?</svg>', contenido, re.DOTALL)
        if svg_match:
            return svg_match.group(0)
        
        return contenido if contenido and '<svg' in contenido else None
    
    except Exception as e:
        print(f"    Error en SDK: {e}")
        return None


def _crear_prompt_mapa_mental(tema: str, conceptos: list[dict]) -> str:
    """Crea prompt para generar mapa mental con Cursor AI."""
    conceptos_texto = "\n".join([
        f"- {c.get('titulo', '')}: {', '.join(c.get('items', [])[:3])}"
        for c in conceptos
    ])
    
    return f"""Genera un mapa mental SVG profesional con este contenido:

Tema central: {tema}

Conceptos (ramas):
{conceptos_texto}

Requisitos:
1. SVG standalone (800x600px)
2. Nodo central destacado con el tema
3. Ramas con colores diferentes (#3498DB, #E74C3C, #F39C12, #27AE60, #9B59B6)
4. Texto legible (fuente sans-serif, 14-18px)
5. Iconos SVG simples para cada rama
6. Diseño radial equilibrado
7. Líneas curvas conectando el centro con las ramas

Genera SOLO el código SVG completo, sin explicaciones."""


def _crear_prompt_infografia(tema: str, conceptos: list[dict]) -> str:
    """Crea prompt para generar infografía con Cursor AI."""
    items = []
    for c in conceptos:
        items.append(f"**{c.get('titulo', '')}**")
        items.extend(f"  - {item}" for item in c.get('items', [])[:2])
    
    items_texto = "\n".join(items)
    
    return f"""Genera una infografía SVG moderna sobre:

Título: {tema}

Contenido:
{items_texto}

Requisitos:
1. SVG standalone (800x1200px, vertical)
2. Título grande arriba
3. Secciones con iconos SVG (check, estrella, info, etc.)
4. Paleta de colores profesional (#2C3E50, #3498DB, #E74C3C, #F39C12)
5. Jerarquía visual clara (tamaños de fuente)
6. Márgenes y espaciado generoso
7. Fondo degradado sutil

Genera SOLO el código SVG completo."""


def _crear_prompt_diagrama(tema: str, conceptos: list[dict]) -> str:
    """Crea prompt para generar diagrama de flujo con Cursor AI."""
    pasos = [f"{i+1}. {c.get('titulo', '')}" for i, c in enumerate(conceptos)]
    pasos_texto = "\n".join(pasos)
    
    return f"""Genera un diagrama de flujo SVG para:

Proceso: {tema}

Pasos:
{pasos_texto}

Requisitos:
1. SVG standalone (1000x600px)
2. Cajas rectangulares con bordes redondeados
3. Flechas conectando los pasos
4. Numeración visible en cada paso
5. Colores: inicio (#27AE60), pasos (#3498DB), fin (#E74C3C)
6. Texto centrado en cada caja
7. Layout horizontal o vertical según número de pasos

Genera SOLO el código SVG completo."""


def generar_mapa_mental_svg(tema: str, conceptos: list[dict]) -> str:
    """Genera un mapa mental simple en SVG.
    
    Args:
        tema: Tema central
        conceptos: Lista de diccionarios con 'titulo' y opcionalmente 'items'
    
    Returns:
        String SVG embebible
    """
    # Dimensiones
    width = 800
    height = 600
    center_x = width // 2
    center_y = height // 2
    
    # Colores
    color_centro = "#3498DB"
    colores_ramas = ["#E74C3C", "#F39C12", "#27AE60", "#9B59B6", "#1ABC9C", "#E67E22"]
    
    svg_lines = [
        f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">',
        '  <defs>',
        '    <style>',
        '      .nodo-centro { fill: ' + color_centro + '; stroke: #2980B9; stroke-width: 3; }',
        '      .texto-centro { fill: white; font-family: Arial, sans-serif; font-size: 18px; font-weight: bold; text-anchor: middle; }',
        '      .nodo-rama { stroke-width: 2; }',
        '      .texto-rama { font-family: Arial, sans-serif; font-size: 14px; text-anchor: middle; }',
        '      .linea { stroke-width: 2; stroke-opacity: 0.7; }',
        '    </style>',
        '  </defs>',
    ]
    
    # Nodo central
    svg_lines.append(f'  <circle cx="{center_x}" cy="{center_y}" r="60" class="nodo-centro"/>')
    
    # Texto central (dividir en líneas si es muy largo)
    palabras = tema.split()
    if len(palabras) > 3:
        linea1 = " ".join(palabras[:len(palabras)//2])
        linea2 = " ".join(palabras[len(palabras)//2:])
        svg_lines.append(f'  <text x="{center_x}" y="{center_y - 5}" class="texto-centro">{linea1}</text>')
        svg_lines.append(f'  <text x="{center_x}" y="{center_y + 15}" class="texto-centro">{linea2}</text>')
    else:
        svg_lines.append(f'  <text x="{center_x}" y="{center_y + 5}" class="texto-centro">{tema}</text>')
    
    # Conceptos en círculo
    import math
    num_conceptos = len(conceptos)
    radio_orbita = 200
    
    for i, concepto in enumerate(conceptos):
        angulo = (2 * math.pi * i / num_conceptos) - (math.pi / 2)  # Empezar arriba
        x = center_x + radio_orbita * math.cos(angulo)
        y = center_y + radio_orbita * math.sin(angulo)
        
        color = colores_ramas[i % len(colores_ramas)]
        
        # Línea al centro
        svg_lines.append(f'  <line x1="{center_x}" y1="{center_y}" x2="{x}" y2="{y}" class="linea" stroke="{color}"/>')
        
        # Nodo rama
        svg_lines.append(f'  <circle cx="{x}" cy="{y}" r="50" class="nodo-rama" fill="{color}"/>')
        
        # Texto rama
        titulo = concepto.get('titulo', '')
        palabras = titulo.split()
        if len(palabras) > 2:
            linea1 = " ".join(palabras[:len(palabras)//2])
            linea2 = " ".join(palabras[len(palabras)//2:])
            svg_lines.append(f'  <text x="{x}" y="{y - 5}" class="texto-rama">{linea1}</text>')
            svg_lines.append(f'  <text x="{x}" y="{y + 15}" class="texto-rama">{linea2}</text>')
        else:
            svg_lines.append(f'  <text x="{x}" y="{y + 5}" class="texto-rama">{titulo}</text>')
    
    svg_lines.append('</svg>')
    
    return "\n".join(svg_lines)


def generar_ilustracion_completa(
    tema: str,
    descripcion: str,
    cache_path: Optional[Path] = None
) -> Optional[str]:
    """Genera ilustración usando el mejor método disponible.
    
    Orden de prioridad:
    1. Cursor AI (infografía SVG)
    2. Proveedor de imágenes configurado (OpenAI DALL-E o Gemini Imagen)
    3. SVG local (fallback)
    
    Args:
        tema: Tema de la ilustración
        descripcion: Descripción detallada
        cache_path: Ruta para cachear
    
    Returns:
        Código SVG, URL de imagen o None
    """
    # 1. Intentar con Cursor AI (infografía SVG)
    if os.getenv("CURSOR_API_KEY"):
        conceptos = [{"titulo": tema, "items": [descripcion]}]
        svg_cursor = generar_visual_con_cursor(
            "infografia",
            tema,
            conceptos,
            cache_path
        )
        if svg_cursor:
            return svg_cursor
    
    # 2. Intentar con proveedor de imágenes configurado
    proveedor = os.getenv("CAPACITACION_IMAGE_PROVIDER", "openai").lower()
    
    if proveedor == "gemini":
        url = generar_ilustracion_gemini(descripcion)
        if url:
            return f'<img src="{url}" alt="{tema}" style="max-width: 100%; height: auto;" />'
    else:
        # Default: OpenAI
        openai_model = os.getenv("OPENAI_IMAGE_MODEL")
        if openai_model and os.getenv("OPENAI_API_KEY"):
            url = generar_ilustracion_openai(descripcion, openai_model)
            if url:
                return f'<img src="{url}" alt="{tema}" style="max-width: 100%; height: auto;" />'
    
    # 3. Fallback: SVG local
    return generar_infografia_svg_fallback(tema, [descripcion])


def generar_ilustracion_openai(
    prompt: str,
    modelo: str = "dall-e-3",
    tamano: str = "1024x1024"
) -> Optional[str]:
    """Genera ilustración con OpenAI DALL-E.
    
    Args:
        prompt: Descripción de la imagen
        modelo: Modelo a usar (dall-e-2, dall-e-3)
        tamano: Tamaño de la imagen
    
    Returns:
        URL de la imagen o None si falla
    """
    try:
        import openai
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            return None
        
        openai.api_key = api_key
        
        response = openai.Image.create(
            model=modelo,
            prompt=prompt,
            n=1,
            size=tamano
        )
        
        return response['data'][0]['url']
    except Exception as e:
        print(f"  ⚠️  Error con OpenAI Images: {e}")
        return None


def generar_ilustracion_gemini(
    prompt: str,
    modelo: str = None
) -> Optional[str]:
    """Genera ilustración con Google Gemini Imagen.
    
    Args:
        prompt: Descripción de la imagen
        modelo: Modelo a usar (si None, usa GEMINI_IMAGE_MODEL de .env)
    
    Returns:
        URL de la imagen o None si falla
    """
    try:
        import google.generativeai as genai
        
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return None
        
        if modelo is None:
            modelo = os.getenv("GEMINI_IMAGE_MODEL", "imagen-3.0-generate-001")
        
        genai.configure(api_key=api_key)
        
        # Usar Gemini para generar imagen
        model = genai.GenerativeModel(modelo)
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.7,
                "max_output_tokens": 1024
            }
        )
        
        # Gemini devuelve la URL de la imagen generada
        if response.parts:
            for part in response.parts:
                if hasattr(part, 'inline_data') and part.inline_data:
                    # Convertir a data URL
                    import base64
                    image_data = part.inline_data.data
                    mime_type = part.inline_data.mime_type
                    b64_data = base64.b64encode(image_data).decode('utf-8')
                    return f"data:{mime_type};base64,{b64_data}"
        
        return None
    
    except ImportError:
        print("  ⚠️  google-generativeai no instalado (pip install google-generativeai)")
        return None
    except Exception as e:
        print(f"  ⚠️  Error con Gemini Images: {e}")
        return None


def generar_infografia_svg_fallback(titulo: str, items: list[str]) -> str:
    """Genera una infografía SVG simple como fallback.
    
    Args:
        titulo: Título de la infografía
        items: Lista de puntos clave
    
    Returns:
        String SVG
    """
    width = 600
    height = 400
    
    svg_lines = [
        f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">',
        '  <defs>',
        '    <style>',
        '      .titulo-info { fill: #2C3E50; font-family: Arial, sans-serif; font-size: 24px; font-weight: bold; }',
        '      .item-info { fill: #34495E; font-family: Arial, sans-serif; font-size: 16px; }',
        '      .icono { fill: #3498DB; }',
        '    </style>',
        '  </defs>',
        '  <rect width="100%" height="100%" fill="#ECF0F1"/>',
        f'  <text x="{width // 2}" y="50" class="titulo-info" text-anchor="middle">{titulo}</text>',
    ]
    
    # Items con iconos
    y_pos = 100
    for i, item in enumerate(items[:5]):  # Máximo 5 items
        # Icono de check
        svg_lines.append(f'  <circle cx="50" cy="{y_pos}" r="15" class="icono"/>')
        svg_lines.append(f'  <text x="50" y="{y_pos + 6}" fill="white" font-size="18" text-anchor="middle">✓</text>')
        
        # Texto del item (truncar si es muy largo)
        texto = item[:50] + "..." if len(item) > 50 else item
        svg_lines.append(f'  <text x="80" y="{y_pos + 5}" class="item-info">{texto}</text>')
        
        y_pos += 60
    
    svg_lines.append('</svg>')
    
    return "\n".join(svg_lines)


def generar_mapa_mermaid(tema: str, conceptos: list[dict]) -> str:
    """Genera código Mermaid para un mapa mental.
    
    Args:
        tema: Tema central
        conceptos: Lista de conceptos con titulo e items
    
    Returns:
        Código Mermaid
    """
    lines = [
        "```mermaid",
        "mindmap",
        f"  root(({tema}))"
    ]
    
    for concepto in conceptos:
        titulo = concepto.get('titulo', '')
        items = concepto.get('items', [])
        
        lines.append(f"    {titulo}")
        for item in items[:3]:  # Máximo 3 items por rama
            lines.append(f"      {item}")
    
    lines.append("```")
    
    return "\n".join(lines)


def extraer_conceptos_para_mapa(bloque_meta: dict, contenido_md: str) -> list[dict]:
    """Extrae conceptos clave del contenido para el mapa mental.
    
    Args:
        bloque_meta: Metadatos del bloque
        contenido_md: Contenido markdown
    
    Returns:
        Lista de conceptos con titulo e items
    """
    import re
    
    conceptos = []
    
    # Buscar secciones principales
    secciones = re.findall(r'^## (.+)$', contenido_md, re.MULTILINE)
    
    for seccion in secciones[:6]:  # Máximo 6 secciones para el mapa
        # Limpiar emojis y símbolos
        titulo = re.sub(r'[🎯📍📋🔢⚠️💡📝📌✅🔧]', '', seccion).strip()
        
        # Buscar items bajo esta sección
        patron_seccion = rf'^## {re.escape(seccion)}.*?\n(.*?)(?=^## |\Z)'
        match_contenido = re.search(patron_seccion, contenido_md, re.MULTILINE | re.DOTALL)
        
        items = []
        if match_contenido:
            contenido_seccion = match_contenido.group(1)
            # Extraer primeros bullets
            items = re.findall(r'^\s*[-*]\s+(.+)$', contenido_seccion, re.MULTILINE)[:3]
        
        conceptos.append({
            'titulo': titulo[:30],  # Truncar títulos largos
            'items': [item[:40] for item in items]  # Truncar items
        })
    
    return conceptos
