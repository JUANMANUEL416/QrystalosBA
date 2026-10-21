#!/usr/bin/env python3
"""
Generador de elementos visuales para capacitaciones:
- Mapas mentales y diagramas (Cursor AI → SVG/Mermaid)
- Ilustraciones tipo dibujo (Gemini/OpenAI Images API)
- Fallback SVG local

Orden de prioridad (configurable en .env):
1. Gemini (default recomendado) - Genera imágenes
2. OpenAI Images - Respaldo
3. Generador SVG local - Respaldo final

Carga .env del proyecto igual que cursor_bot.py (os.environ gana).
"""
import os
import json
import base64
import re
import sys
from pathlib import Path
from typing import Optional

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
# Bajo servicio Windows LocalSystem con consola cp1252, los emojis/✓/✗
# causan UnicodeEncodeError. Reconfigurar al importar este módulo.
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass  # Ignorar si ya está reconfigurado


# --- Carga de .env (prioridad: os.environ > archivo .env) ---
def _parse_env(path: str) -> dict:
    """Lee .env y devuelve dict de variables (sin sobrescribir os.environ)."""
    values = {}
    if not os.path.isfile(path):
        return values
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            values[key.strip()] = val.strip().strip('"').strip("'")
    return values


# Cargar .env al importar (os.environ ya tiene prioridad)
ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
_ENV_FILE = _parse_env(str(ENV_PATH))


def _get_env(key: str, default: str = "") -> str:
    """Obtiene variable: os.environ gana sobre .env."""
    return os.environ.get(key) or _ENV_FILE.get(key) or default


# --- Cache de estado de cuota Gemini (evita reintentar si 429) ---
_GEMINI_SIN_CUOTA_CACHE = {
    "timestamp": 0,
    "duracion_minutos": 5  # Cachear 5 minutos
}


def _gemini_tiene_cuota() -> bool:
    """Verifica si Gemini tiene cuota disponible (usa cache de 5 min tras 429)."""
    import time
    ahora = time.time()
    ultimo_429 = _GEMINI_SIN_CUOTA_CACHE["timestamp"]
    duracion_seg = _GEMINI_SIN_CUOTA_CACHE["duracion_minutos"] * 60
    
    if ultimo_429 > 0 and (ahora - ultimo_429) < duracion_seg:
        # Todavía en periodo de cache
        return False
    
    return True


def _marcar_gemini_sin_cuota():
    """Marca que Gemini dio 429 (sin cuota) para cachear el estado."""
    import time
    _GEMINI_SIN_CUOTA_CACHE["timestamp"] = time.time()


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
    cursor_api_key = _get_env("CURSOR_API_KEY")
    if not cursor_api_key:
        print("  ⚠️  CURSOR_API_KEY no configurada, usando fallback")
        return None
    
    # Modelos disponibles (configurables en .env)
    # Orden de prioridad según CAPACITACION_VISUAL_MODEL
    modelo_preferido = _get_env("CAPACITACION_VISUAL_MODEL", "gpt-5.6-sol-medium")
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
    titulo: str,
    descripcion: str,
    cache_path: Optional[Path] = None
) -> Optional[str]:
    """Genera ilustración usando el mejor método disponible y devuelve data URI.
    
    Orden de prioridad:
    1. Gemini (default recomendado) - Genera imagen y devuelve data URI
    2. OpenAI - Genera imagen y devuelve data URI
    3. SVG local (fallback)
    
    Args:
        titulo: Título del bloque
        descripcion: Descripción detallada
        cache_path: Ruta para cachear (PNG)
    
    Returns:
        Data URI de la imagen (PNG o SVG) o None
    """
    # Verificar cache primero
    if cache_path and cache_path.exists():
        try:
            img_data = cache_path.read_bytes()
            img_b64 = base64.b64encode(img_data).decode("utf-8")
            print(f"    ✓ Ilustración (cache): {cache_path.name}")
            return f"data:image/png;base64,{img_b64}"
        except Exception as e:
            print(f"    ⚠️  Error leyendo cache: {e}")
    
    # 1. Proveedor configurado (Gemini default)
    proveedor = _get_env("CAPACITACION_IMAGE_PROVIDER", "gemini").lower()
    gemini_key = _get_env("GEMINI_API_KEY")
    openai_key = _get_env("OPENAI_API_KEY")
    
    print(f"    Intentando generar ilustración...")
    print(f"      Proveedor configurado: {proveedor}")
    print(f"      GEMINI_API_KEY: {'✓ disponible' if gemini_key else '✗ no configurada'}")
    print(f"      OPENAI_API_KEY: {'✓ disponible' if openai_key else '✗ no configurada'}")
    
    # Verificar cache de cuota Gemini
    gemini_tiene_cuota = _gemini_tiene_cuota()
    if not gemini_tiene_cuota:
        print(f"      ⚠️  Gemini sin cuota (cacheado), pasando directo a OpenAI")
    
    if proveedor == "gemini" and gemini_key and gemini_tiene_cuota:
        print(f"      → Intentando con Gemini...")
        prompt = f"Ilustración educativa para capacitación: {titulo}. {descripcion}"
        data_uri = generar_ilustracion_gemini(prompt)
        if data_uri:
            # Guardar en cache si es posible
            if cache_path:
                try:
                    _guardar_data_uri_como_png(data_uri, cache_path)
                    print(f"    ✓ Ilustración generada con Gemini y guardada en {cache_path.name}")
                except Exception as e:
                    print(f"    ✓ Ilustración generada con Gemini (no se pudo cachear: {e})")
            else:
                print(f"    ✓ Ilustración generada con Gemini")
            return data_uri
        else:
            print(f"      ✗ Gemini no generó imagen (ver logs arriba)")
    
    # 2. OpenAI fallback
    if openai_key:
        print(f"      → Intentando con OpenAI...")
        openai_model = _get_env("OPENAI_IMAGE_MODEL", "gpt-image-1")
        print(f"        Modelo: {openai_model}")
        prompt = f"Educational illustration for: {titulo}. {descripcion}"
        url = generar_ilustracion_openai(prompt, openai_model)
        if url:
            # Descargar y convertir a data URI
            try:
                print(f"        Descargando imagen desde URL...")
                data_uri = _descargar_imagen_como_data_uri(url)
                if data_uri:
                    if cache_path:
                        _guardar_data_uri_como_png(data_uri, cache_path)
                        print(f"    ✓ Ilustración generada con OpenAI y guardada en {cache_path.name}")
                    else:
                        print(f"    ✓ Ilustración generada con OpenAI")
                    return data_uri
            except Exception as e:
                print(f"      ✗ Error descargando imagen OpenAI: {e}")
        else:
            print(f"      ✗ OpenAI no generó URL (ver logs arriba)")
    
    # 3. Fallback SVG local
    print(f"      → Usando generador SVG local (fallback)")
    svg = generar_infografia_svg_fallback(titulo, [descripcion])
    if svg:
        svg_b64 = base64.b64encode(svg.encode("utf-8")).decode("utf-8")
        print(f"    ✓ Ilustración generada con SVG local")
        return f"data:image/svg+xml;base64,{svg_b64}"
    
    print(f"    ✗ No se pudo generar ilustración (ningún método funcionó)")
    return None


def _descargar_imagen_como_data_uri(url: str) -> Optional[str]:
    """Descarga una imagen desde URL y la convierte a data URI (usando urllib)."""
    try:
        import urllib.request
        
        with urllib.request.urlopen(url, timeout=30) as response:
            img_data = response.read()
            img_b64 = base64.b64encode(img_data).decode("utf-8")
            
            # Detectar tipo MIME del header
            content_type = response.headers.get('Content-Type', 'image/png')
            return f"data:{content_type};base64,{img_b64}"
    except Exception as e:
        print(f"    ⚠️  Error descargando imagen: {e}")
        return None


def _guardar_data_uri_como_png(data_uri: str, output_path: Path) -> None:
    """Guarda un data URI como archivo PNG."""
    try:
        # Extraer el base64 del data URI
        if "base64," in data_uri:
            b64_data = data_uri.split("base64,", 1)[1]
            img_data = base64.b64decode(b64_data)
            
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(img_data)
    except Exception as e:
        print(f"    ⚠️  Error guardando imagen: {e}")


def generar_ilustracion_openai(
    prompt: str,
    modelo: str = "gpt-image-1",
    tamano: str = "1024x1024"
) -> Optional[str]:
    """Genera ilustración con OpenAI usando urllib (sin paquete openai).
    
    Usa https://api.openai.com/v1/images/generations con response_format=b64_json.
    
    Args:
        prompt: Descripción de la imagen
        modelo: Modelo a usar (gpt-image-1, gpt-image-2)
        tamano: Tamaño de la imagen (1024x1024, 1536x1024, etc)
    
    Returns:
        Data URI de la imagen o None si falla
    """
    import urllib.request
    import urllib.error
    
    api_key = _get_env("OPENAI_API_KEY")
    if not api_key:
        print(f"        ✗ OPENAI_API_KEY no disponible")
        return None
    
    base_url = _get_env("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    
    body = {
        "model": modelo,
        "prompt": prompt[:3900],
        "size": tamano,
        "n": 1
        # Nota: gpt-image-1 devuelve b64_json por defecto, no necesita response_format
    }
    
    req = urllib.request.Request(
        f"{base_url}/images/generations",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        
        # gpt-image-1 devuelve b64_json
        fila = (data.get("data") or [{}])[0]
        b64 = (fila.get("b64_json") or "").strip()
        
        if not b64:
            # Intentar con url si no hay b64_json
            url = (fila.get("url") or "").strip()
            if url:
                print(f"        ✓ OpenAI generó URL (descargando): {url[:60]}...")
                with urllib.request.urlopen(url, timeout=60) as img_resp:
                    img_data = img_resp.read()
                    b64 = base64.b64encode(img_data).decode("utf-8")
            else:
                print(f"        ✗ OpenAI no devolvió imagen (ni b64_json ni url)")
                return None
        
        print(f"        ✓ OpenAI generó imagen ({len(b64)} chars base64, ~{len(b64)*3//4//1024} KB)")
        return f"data:image/png;base64,{b64}"
    
    except urllib.error.HTTPError as exc:
        status = exc.code
        try:
            detalle = exc.read().decode("utf-8", errors="replace")[:300]
        except:
            detalle = str(exc)
        print(f"        ✗ Error OpenAI (HTTP {status}): {detalle}")
        
        # Reintentar con tamaño 1024x1024 si falla con otro tamaño
        if tamano != "1024x1024":
            print(f"        → Reintentando con tamaño 1024x1024...")
            return generar_ilustracion_openai(prompt, modelo, "1024x1024")
        
        return None
    
    except Exception as e:
        error_msg = str(e)[:300]
        print(f"        ✗ Error OpenAI: {error_msg}")
        return None


def generar_ilustracion_gemini(
    prompt: str,
    modelo: str = None
) -> Optional[str]:
    """Genera ilustración con Google Gemini usando urllib (sin paquete google-generativeai).
    
    Usa API REST v1beta/models/{model}:generateContent con responseModalities IMAGE.
    
    Args:
        prompt: Descripción de la imagen
        modelo: Modelo a usar (si None, usa GEMINI_IMAGE_MODEL de .env)
    
    Returns:
        Data URI de la imagen o None si falla
    """
    import urllib.request
    import urllib.error
    
    api_key = _get_env("GEMINI_API_KEY")
    if not api_key:
        print(f"        ✗ GEMINI_API_KEY no disponible")
        return None
    
    if modelo is None:
        modelo = _get_env("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    
    # Modelos disponibles con fallback
    modelos = [
        modelo,
        "gemini-3.1-flash-image",
        "gemini-3-pro-image",
        "gemini-2.5-flash-image"
    ]
    # Eliminar duplicados manteniendo orden
    modelos = list(dict.fromkeys(modelos))
    
    # Intentar con cada modelo
    for modelo_actual in modelos:
        try:
            print(f"        Probando modelo: {modelo_actual}")
            
            # Endpoint: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{modelo_actual}:generateContent?key={api_key}"
            
            body = {
                "contents": [{
                    "parts": [{
                        "text": prompt[:2000]
                    }]
                }],
                "generationConfig": {
                    "temperature": 0.7,
                    "maxOutputTokens": 1024,
                    "responseModalities": ["IMAGE"]  # Nota: puede necesitar ["TEXT", "IMAGE"] según el modelo
                }
            }
            
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            
            # Parsear respuesta: candidates[0].content.parts[].inlineData{mimeType,data}
            candidates = data.get("candidates", [])
            if not candidates:
                print(f"        ✗ {modelo_actual}: No hay candidates en respuesta")
                continue
            
            content = candidates[0].get("content", {})
            parts = content.get("parts", [])
            
            if not parts:
                print(f"        ✗ {modelo_actual}: No hay parts en respuesta")
                continue
            
            # Buscar inlineData (camelCase)
            for part in parts:
                inline_data = part.get("inlineData")
                if inline_data:
                    mime_type = inline_data.get("mimeType", "image/png")
                    b64_data = inline_data.get("data", "").strip()
                    
                    if b64_data:
                        # Decodificar para obtener tamaño
                        try:
                            img_bytes = base64.b64decode(b64_data)
                            print(f"        ✓ Gemini generó imagen ({len(img_bytes)} bytes, {mime_type})")
                            return f"data:{mime_type};base64,{b64_data}"
                        except:
                            pass
            
            print(f"        ✗ {modelo_actual}: Respuesta sin inlineData")
            continue
        
        except urllib.error.HTTPError as exc:
            status = exc.code
            try:
                error_body = exc.read().decode("utf-8", errors="replace")
                # Parsear JSON de error si existe
                try:
                    error_json = json.loads(error_body)
                    error_msg = error_json.get("error", {}).get("message", error_body[:300])
                except:
                    error_msg = error_body[:300]
            except:
                error_msg = str(exc)
            
            print(f"        ✗ {modelo_actual} (HTTP {status}): {error_msg}")
            
            # Clasificar error
            if status == 401 or status == 403:
                print(f"          → Error de autenticación (revisar GEMINI_API_KEY)")
            elif status == 404:
                print(f"          → Modelo no disponible en esta cuenta")
            elif status == 429:
                print(f"          → Cuota excedida (cacheando estado, pasando a OpenAI)")
                # Marcar cache de sin cuota y NO reintentar con otros modelos
                _marcar_gemini_sin_cuota()
                return None
            
            continue
        
        except Exception as e:
            error_msg = str(e)[:300]
            print(f"        ✗ {modelo_actual}: {error_msg}")
            continue
    
    print(f"        ✗ Ningún modelo de Gemini funcionó")
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
