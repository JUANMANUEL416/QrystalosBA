"""Ensamblador de documentos de capacitación desde bloques modulares.

Une bloques seleccionados en un documento unificado (HTML y/o DOCX).
"""
from __future__ import annotations

import base64
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
# Bajo servicio Windows LocalSystem con consola cp1252, los emojis/✓/✗
# causan UnicodeEncodeError. Reconfigurar al importar este módulo.
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass  # Ignorar si ya está reconfigurado

ROOT = Path(__file__).resolve().parents[1]
CAPACITACION = ROOT / "capacitacion"
BLOQUES_DIR = CAPACITACION / "bloques"
SALIDA_DIR = CAPACITACION / "documentos"

import capacitacion_bloques as bloques

# Intentar importar generador de visuales (opcional)
try:
    import capacitacion_visuales as visuales
    VISUALES_DISPONIBLE = True
except ImportError:
    VISUALES_DISPONIBLE = False

# Intentar importar generador de PDF (opcional)
try:
    import capacitacion_pdf as pdf_gen
    PDF_DISPONIBLE = True
except ImportError:
    PDF_DISPONIBLE = False


def ensamblar_documento(
    tema_id: str,
    bloques_ids: list[str],
    titulo: str | None = None,
    formato: str = "html",
    incluir_indice: bool = True,
    incluir_imagenes: bool = True,
    audiencia: str = "usuario-final"
) -> dict:
    """Ensambla un documento de capacitación desde bloques.
    
    Args:
        tema_id: ID del tema (para contexto)
        bloques_ids: Lista de IDs de bloques a incluir
        titulo: Título del documento (opcional, se genera si falta)
        formato: "html", "docx" o "ambos"
        incluir_indice: Si True, genera índice al inicio
        incluir_imagenes: Si True, incrusta imágenes en el documento
        audiencia: "usuario-final" | "soporte-desarrollo"
    
    Returns:
        {
            "ok": bool,
            "archivo_html": str,  # Ruta si formato incluye html
            "archivo_docx": str,  # Ruta si formato incluye docx
            "bloques": list[str],  # IDs en orden
            "audiencia": str,  # Audiencia del documento
            "error": str  # Solo si ok=False
        }
    """
    # Resolver dependencias
    deps = bloques.resolver_dependencias(bloques_ids)
    if not deps["ok"]:
        return {
            "ok": False,
            "error": deps.get("error"),
            "detalles": deps
        }
    
    orden = deps["orden"]
    
    # Cargar tema
    temas_data = bloques.cargar_temas()
    tema = next((t for t in temas_data.get("temas", []) if t["id"] == tema_id), None)
    
    # Generar título si falta
    if not titulo:
        if tema:
            titulo = f"Capacitación: {tema['nombre']}"
        else:
            titulo = "Manual de capacitación Qrystalos"
    
    # Generar slug para el archivo
    slug = _slug(titulo)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    nombre_base = f"{timestamp}-{slug}"
    
    # Crear directorio de salida
    SALIDA_DIR.mkdir(parents=True, exist_ok=True)
    
    resultado = {
        "ok": True,
        "bloques": orden,
        "titulo": titulo,
        "agregados": deps.get("agregados", []),
        "audiencia": audiencia
    }
    
    # Generar HTML
    html_content = None
    if formato in ("html", "ambos", "pdf"):
        archivo_html = SALIDA_DIR / f"{nombre_base}.html"
        html_content = _generar_html(tema, titulo, orden, incluir_indice, incluir_imagenes, audiencia)
        archivo_html.write_text(html_content, encoding="utf-8")
        # Devolver URL relativa para el navegador (no ruta del sistema)
        resultado["archivo_html"] = f"capacitacion/documentos/{nombre_base}.html"
    
    # Generar PDF (si está disponible)
    if formato == "pdf" and PDF_DISPONIBLE and html_content:
        pdf_path = pdf_gen.generar_pdf_documento(html_content, f"{nombre_base}.pdf")
        if pdf_path:
            resultado["archivo_pdf"] = f"capacitacion/documentos/{nombre_base}.pdf"
        else:
            # Fallback: devolver HTML para window.print
            resultado["archivo_pdf"] = None
            resultado["pdf_fallback"] = "window.print"
    
    # Generar DOCX (futuro)
    if formato in ("docx", "ambos"):
        # Por ahora solo marcador
        resultado["archivo_docx"] = None
        resultado["nota_docx"] = "Generación DOCX no implementada aún. Use HTML como entrada a Word."
    
    return resultado


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
    return texto.strip("-")[:50]


def _filtrar_por_audiencia(contenido_md: str, audiencia: str) -> str:
    """Filtra el contenido markdown según la audiencia.
    
    Usuario final: elimina secciones entre <!-- AUDIENCIA: soporte-desarrollo --> y <!-- /AUDIENCIA -->
                   y limpia referencias explícitas a SPs
    Soporte y desarrollo: mantiene todo
    """
    import re
    
    if audiencia == "soporte-desarrollo":
        # Mantener todo, solo quitar marcadores
        contenido_md = contenido_md.replace("<!-- AUDIENCIA: soporte-desarrollo -->", "")
        contenido_md = contenido_md.replace("<!-- /AUDIENCIA -->", "")
        return contenido_md
    
    # Usuario final: eliminar secciones técnicas marcadas
    patron_seccion = r'<!-- AUDIENCIA: soporte-desarrollo -->.*?<!-- /AUDIENCIA -->'
    contenido_md = re.sub(patron_seccion, '', contenido_md, flags=re.DOTALL)
    
    # Usuario final: limpiar referencias explícitas a SPs del resto del texto
    contenido_md = _limpiar_referencias_sps(contenido_md)
    
    return contenido_md


def _obtener_logo_data_uri() -> str:
    """Obtiene el logo de IX Colombia como data URI.
    
    Returns:
        Data URI del logo PNG o cadena vacía si no existe
    """
    logo_path = ROOT / "app" / "assets" / "logo-ixcolombia.png"
    
    if not logo_path.exists():
        # Intentar SVG
        logo_path = ROOT / "app" / "assets" / "logo-ixcolombia.svg"
        if not logo_path.exists():
            return ""
    
    try:
        if logo_path.suffix == ".svg":
            svg_content = logo_path.read_text(encoding="utf-8")
            svg_b64 = base64.b64encode(svg_content.encode("utf-8")).decode("utf-8")
            return f"data:image/svg+xml;base64,{svg_b64}"
        else:
            img_data = logo_path.read_bytes()
            img_b64 = base64.b64encode(img_data).decode("utf-8")
            return f"data:image/png;base64,{img_b64}"
    except Exception as e:
        print(f"  ⚠️  Error cargando logo: {e}")
        return ""


def _obtener_visuales_bloque(bloque_id: str, bloque_meta: dict, log: bool = True) -> dict:
    """Obtiene o genera las visuales de un bloque (mapa mental + ilustración).
    
    Returns:
        dict con 'mapa_mental' (data URI SVG) e 'ilustracion' (data URI imagen)
    """
    resultado = {
        "mapa_mental": None,
        "ilustracion": None
    }
    
    bloque_dir = BLOQUES_DIR / bloque_id
    
    # 1. Mapa mental SVG (siempre debe existir en visuales/)
    mapa_path = bloque_dir / "visuales" / "mapa-mental.svg"
    if mapa_path.exists():
        try:
            svg_content = mapa_path.read_text(encoding="utf-8")
            # Convertir a data URI
            svg_b64 = base64.b64encode(svg_content.encode("utf-8")).decode("utf-8")
            resultado["mapa_mental"] = f"data:image/svg+xml;base64,{svg_b64}"
            if log:
                print(f"    ✓ Mapa mental: {mapa_path.name}")
        except Exception as e:
            if log:
                print(f"    ⚠️  Error leyendo mapa mental: {e}")
    else:
        if log:
            try:
                ruta_relativa = mapa_path.relative_to(ROOT)
            except ValueError:
                ruta_relativa = mapa_path
            print(f"    ⚠️  No existe mapa mental en {ruta_relativa}")
    
    # 2. Ilustración (intentar generar si no existe en cache)
    ilustracion_path = bloque_dir / "visuales" / "ilustracion.png"
    
    if ilustracion_path.exists():
        # Usar cache
        try:
            img_data = ilustracion_path.read_bytes()
            img_b64 = base64.b64encode(img_data).decode("utf-8")
            resultado["ilustracion"] = f"data:image/png;base64,{img_b64}"
            if log:
                print(f"    ✓ Ilustración (cache): {ilustracion_path.name}")
        except Exception as e:
            if log:
                print(f"    ⚠️  Error leyendo ilustración: {e}")
    else:
        # Intentar generar
        if VISUALES_DISPONIBLE:
            if log:
                print(f"    Generando ilustración para {bloque_meta['titulo']}...")
            
            try:
                # Preparar contexto del bloque
                titulo = bloque_meta.get("titulo", "")
                descripcion = bloque_meta.get("descripcion", titulo)
                
                # Intentar generar (logs en capacitacion_visuales.py)
                data_uri = visuales.generar_ilustracion_completa(
                    titulo=titulo,
                    descripcion=descripcion,
                    cache_path=ilustracion_path
                )
                
                if data_uri:
                    resultado["ilustracion"] = data_uri
                    # El log detallado ya se imprimió en generar_ilustracion_completa()
                else:
                    if log:
                        print(f"    ✗ No se generó ilustración (ver logs arriba)")
            except Exception as e:
                if log:
                    print(f"    ⚠️  Error generando ilustración: {e}")
        else:
            if log:
                print(f"    ⚠️  Visuales no disponible, no se puede generar ilustración")
    
    return resultado


def _limpiar_referencias_sps(texto: str) -> str:
    """Elimina o reemplaza referencias técnicas a stored procedures.
    
    Estrategia: Eliminar frases completas que mencionen SPs técnicos,
    preservando la estructura de párrafos y encabezados markdown.
    """
    import re
    
    # Patrón para detectar menciones a SPs
    # Ejemplos: "SPQ_IART", "SPK_CONFIRMAR", "SP_PROCESAR"
    patron_sp = r'\b(SPQ_|SPK_|SP_)[A-Z_0-9]+\b'
    
    # Dividir en párrafos (separados por línea en blanco)
    # Esto preserva encabezados markdown que deben ir separados
    parrafos = re.split(r'\n\n+', texto)
    
    parrafos_limpios = []
    for parrafo in parrafos:
        # Si es encabezado markdown, mantenerlo siempre
        if parrafo.strip().startswith('#'):
            parrafos_limpios.append(parrafo)
            continue
        
        # Dividir párrafo en oraciones
        oraciones = re.split(r'(?<=[.!?])\s+', parrafo)
        
        # Filtrar oraciones que NO contengan referencias a SPs
        oraciones_limpias = []
        for oracion in oraciones:
            if not re.search(patron_sp, oracion, re.IGNORECASE):
                oraciones_limpias.append(oracion)
        
        # Si quedan oraciones, unirlas con espacio
        if oraciones_limpias:
            parrafos_limpios.append(' '.join(oraciones_limpias))
    
    # Unir párrafos con doble salto de línea
    return '\n\n'.join(parrafos_limpios)


def _generar_html(
    tema: dict | None,
    titulo: str,
    bloques_ids: list[str],
    incluir_indice: bool,
    incluir_imagenes: bool,
    audiencia: str = "usuario-final"
) -> str:
    """Genera el HTML del documento ensamblado."""
    lineas = []
    
    # Cabecera HTML
    lineas.append("<!DOCTYPE html>")
    lineas.append('<html lang="es">')
    lineas.append("<head>")
    lineas.append('  <meta charset="UTF-8">')
    lineas.append('  <meta name="viewport" content="width=device-width, initial-scale=1.0">')
    lineas.append(f"  <title>{titulo}</title>")
    lineas.append(_css_documento())
    lineas.append("</head>")
    lineas.append("<body>")
    
    # Botón flotante para descargar PDF
    lineas.append('''  <button class="btn-pdf" onclick="window.print()" title="Descargar como PDF">
      📄 Descargar PDF
    </button>''')
    
    # Portada (banda compacta)
    logo_data_uri = _obtener_logo_data_uri()
    
    lineas.append('  <div class="portada">')
    lineas.append('    <div class="portada-contenido">')
    if logo_data_uri:
        lineas.append(f'      <img class="portada-logo" src="{logo_data_uri}" alt="IX Colombia" />')
    lineas.append('      <div class="portada-texto">')
    lineas.append(f'        <h1 class="portada-titulo">{titulo}</h1>')
    if tema:
        lineas.append(f'        <p class="portada-subtitulo">{tema.get("descripcion", "")}</p>')
    lineas.append(f'        <p class="portada-fecha">📅 {datetime.now().strftime("%d/%m/%Y %H:%M")}</p>')
    lineas.append('      </div>')
    lineas.append('    </div>')
    lineas.append('  </div>')
    
    # Índice
    if incluir_indice:
        lineas.append('  <div class="indice">')
        lineas.append('    <h2>Índice</h2>')
        lineas.append('    <ol class="indice-lista">')
        for i, bloque_id in enumerate(bloques_ids, 1):
            bloque_meta = bloques.obtener_bloque(bloque_id)
            if bloque_meta:
                lineas.append(f'      <li><a href="#bloque-{bloque_id}">{bloque_meta["titulo"]}</a></li>')
        lineas.append('    </ol>')
        lineas.append('  </div>')
    
    # Contenido de cada bloque
    for i, bloque_id in enumerate(bloques_ids, 1):
        bloque_meta = bloques.obtener_bloque(bloque_id)
        if not bloque_meta:
            continue
        
        print(f"\n  Bloque {i}/{len(bloques_ids)}: {bloque_meta['titulo']}")
        
        contenido_md = bloques.leer_contenido_bloque(bloque_id)
        
        # Filtrar contenido por audiencia
        contenido_md = _filtrar_por_audiencia(contenido_md, audiencia)
        
        # Obtener visuales del bloque
        visuales_bloque = _obtener_visuales_bloque(bloque_id, bloque_meta) if incluir_imagenes else {}
        
        # Obtener prerrequisitos
        prerreqs = bloque_meta.get("prerrequisitos", [])
        
        lineas.append(f'  <section class="bloque" id="bloque-{bloque_id}">')
        
        # Encabezado del bloque (tarjeta con color)
        lineas.append('    <div class="bloque-encabezado">')
        lineas.append(f'      <div class="bloque-numero">📚 Módulo {i}</div>')
        lineas.append(f'      <h2 class="bloque-titulo">{bloque_meta["titulo"]}</h2>')
        
        # Chips de info
        lineas.append('      <div class="bloque-chips">')
        
        # Audiencia
        if audiencia == "usuario-final":
            lineas.append('        <span class="chip chip-audiencia">👤 Usuario Final</span>')
        else:
            lineas.append('        <span class="chip chip-audiencia">🔧 Soporte</span>')
        
        # Prerrequisitos
        if prerreqs:
            for prereq_id in prerreqs[:2]:  # Máximo 2
                prereq_meta = bloques.obtener_bloque(prereq_id)
                if prereq_meta:
                    titulo_corto = prereq_meta["titulo"][:30]
                    lineas.append(f'        <span class="chip chip-prereq">📌 {titulo_corto}</span>')
        
        # Duración
        duracion = bloque_meta.get("duracionEstimada", "")
        if duracion:
            lineas.append(f'        <span class="chip chip-duracion">⏱️ {duracion}</span>')
        
        lineas.append('      </div>')
        lineas.append('    </div>')
        
        # Imágenes del bloque (mapa mental + ilustración)
        if incluir_imagenes and (visuales_bloque.get("mapa_mental") or visuales_bloque.get("ilustracion")):
            lineas.append('    <div class="bloque-visuales">')
            
            if visuales_bloque.get("mapa_mental"):
                lineas.append('      <figure class="visual-mapa-mental">')
                lineas.append(f'        <img src="{visuales_bloque["mapa_mental"]}" alt="Mapa mental: {bloque_meta["titulo"]}" />')
                lineas.append('        <figcaption>🗺️ Mapa conceptual</figcaption>')
                lineas.append('      </figure>')
            
            if visuales_bloque.get("ilustracion"):
                lineas.append('      <figure class="visual-ilustracion">')
                lineas.append(f'        <img src="{visuales_bloque["ilustracion"]}" alt="Ilustración: {bloque_meta["titulo"]}" />')
                lineas.append('        <figcaption>🎨 Ilustración</figcaption>')
                lineas.append('      </figure>')
            
            lineas.append('    </div>')
        
        # Contenido Markdown → HTML simple
        contenido_html = _markdown_simple_a_html(contenido_md)
        lineas.append('    <div class="bloque-contenido">')
        lineas.append(contenido_html)
        lineas.append('    </div>')
        
        # Transición al siguiente bloque
        if i < len(bloques_ids):
            lineas.append('    <div class="bloque-transicion">▼</div>')
        
        lineas.append('  </section>')
    
    # Pie de página
    lineas.append('  <footer class="pie">')
    lineas.append('    <p>Documento generado por <strong>Qrystalos BA</strong> — Sistema de capacitaciones modulares</p>')
    lineas.append('    <p>IX Colombia SAS · Business Analyst</p>')
    lineas.append('  </footer>')
    
    lineas.append("</body>")
    lineas.append("</html>")
    
    return "\n".join(lineas)


def _css_documento() -> str:
    """Estilos CSS embebidos para el documento (diseño moderno con tarjetas)."""
    return """  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      line-height: 1.6;
      color: #2C3E50;
      background: #F5F7FA;
    }
    
    /* Botón flotante para PDF */
    .btn-pdf {
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      background: linear-gradient(135deg, #E67817 0%, #F39C12 100%);
      color: white;
      border: none;
      padding: 1rem 1.5rem;
      border-radius: 50px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(230, 120, 23, 0.4);
      transition: all 0.3s;
      z-index: 1000;
    }
    
    .btn-pdf:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(230, 120, 23, 0.5);
    }
    
    /* Portada compacta (banda delgada) */
    .portada {
      background: linear-gradient(135deg, #E67817 0%, #F39C12 100%);
      color: white;
      padding: 1.5rem 2rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    
    .portada-contenido {
      max-width: 1200px;
      margin: 0 auto;
      display: flex;
      align-items: center;
      gap: 1.5rem;
    }
    
    .portada-logo {
      width: 80px;
      height: auto;
      filter: brightness(0) invert(1);
    }
    
    .portada-texto {
      flex: 1;
    }
    
    .portada-titulo {
      font-size: 1.8rem;
      font-weight: 700;
      margin-bottom: 0.25rem;
    }
    
    .portada-subtitulo {
      font-size: 1rem;
      margin-bottom: 0.25rem;
      opacity: 0.95;
    }
    
    .portada-fecha {
      font-size: 0.9rem;
      opacity: 0.85;
    }
    
    .indice {
      background: white;
      padding: 2rem;
      margin: 2rem auto;
      max-width: 800px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      page-break-after: always;
    }
    
    .indice h2 {
      color: #E67817;
      margin-bottom: 1.5rem;
      font-size: 2rem;
    }
    
    .indice-lista {
      list-style: none;
      counter-reset: indice-counter;
    }
    
    .indice-lista li {
      counter-increment: indice-counter;
      margin-bottom: 0.8rem;
      padding-left: 2rem;
      position: relative;
    }
    
    .indice-lista li::before {
      content: counter(indice-counter);
      position: absolute;
      left: 0;
      top: 0;
      background: #E67817;
      color: white;
      width: 1.5rem;
      height: 1.5rem;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.9rem;
      font-weight: 600;
    }
    
    .indice-lista a {
      color: #2C3E50;
      text-decoration: none;
      font-size: 1.1rem;
      transition: color 0.2s;
    }
    
    .indice-lista a:hover {
      color: #E67817;
    }
    
    /* Bloque como tarjeta con encabezado de color */
    .bloque {
      background: white;
      margin: 2rem auto;
      max-width: 1000px;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      overflow: hidden;
      page-break-inside: avoid;
    }
    
    .bloque-encabezado {
      background: linear-gradient(135deg, #E67817 0%, #F39C12 100%);
      color: white;
      padding: 1.5rem 2rem;
    }
    
    .bloque-numero {
      font-size: 0.85rem;
      font-weight: 600;
      opacity: 0.95;
      margin-bottom: 0.5rem;
    }
    
    .bloque-titulo {
      font-size: 1.8rem;
      font-weight: 700;
      margin-bottom: 1rem;
    }
    
    .bloque-chips {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
    }
    
    .chip {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.8rem;
      font-weight: 500;
      background: rgba(255,255,255,0.2);
      backdrop-filter: blur(10px);
    }
    
    .chip-audiencia {
      background: rgba(52,152,219,0.3);
    }
    
    .chip-prereq {
      background: rgba(155,89,182,0.3);
    }
    
    .chip-duracion {
      background: rgba(46,204,113,0.3);
    }
    
    /* Visuales (mapa mental + ilustración) */
    .bloque-visuales {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
      gap: 1.5rem;
      padding: 2rem;
      background: #F8F9FA;
    }
    
    .visual-mapa-mental,
    .visual-ilustracion {
      text-align: center;
    }
    
    .visual-mapa-mental img,
    .visual-ilustracion img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      background: white;
      padding: 1rem;
    }
    
    .visual-mapa-mental figcaption,
    .visual-ilustracion figcaption {
      margin-top: 0.75rem;
      font-size: 0.9rem;
      font-weight: 600;
      color: #E67817;
    }
    
    .bloque-contenido {
      font-size: 1.05rem;
      line-height: 1.8;
    }
    
    .bloque-contenido {
      padding: 2rem;
    }
    
    .bloque-contenido h1 {
      color: #2C3E50;
      font-size: 1.8rem;
      margin-bottom: 1.5rem;
      border-bottom: 2px solid #E0E0E0;
      padding-bottom: 0.5rem;
    }
    
    .bloque-contenido h2 {
      color: #E67817;
      margin-top: 2rem;
      margin-bottom: 1rem;
      font-size: 1.5rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    .bloque-contenido h3 {
      color: #5D6D7E;
      margin-top: 1.5rem;
      margin-bottom: 0.8rem;
      font-size: 1.2rem;
    }
    
    .bloque-contenido p {
      margin-bottom: 1rem;
    }
    
    .bloque-contenido ul,
    .bloque-contenido ol {
      margin-left: 2rem;
      margin-bottom: 1rem;
    }
    
    .bloque-contenido li {
      margin-bottom: 0.5rem;
    }
    
    .bloque-contenido blockquote {
      border-left: 4px solid #E67817;
      padding-left: 1rem;
      margin: 1.5rem 0;
      color: #5D6D7E;
      font-style: italic;
      background: #FFF5E6;
      padding: 1rem;
      border-radius: 4px;
    }
    
    .bloque-contenido code {
      background: #F0F0F0;
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
      font-family: 'Courier New', monospace;
      font-size: 0.95em;
    }
    
    .bloque-contenido pre {
      background: #2C3E50;
      color: #ECF0F1;
      padding: 1rem;
      border-radius: 6px;
      overflow-x: auto;
      margin: 1rem 0;
    }
    
    .bloque-contenido pre code {
      background: none;
      padding: 0;
      color: inherit;
    }
    
    /* Tablas mejoradas */
    .bloque-contenido table {
      width: 100%;
      border-collapse: collapse;
      margin: 1.5rem 0;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      border-radius: 8px;
      overflow: hidden;
    }
    
    .bloque-contenido thead {
      background: linear-gradient(135deg, #E67817 0%, #F39C12 100%);
      color: white;
    }
    
    .bloque-contenido th {
      padding: 1rem;
      text-align: left;
      font-weight: 600;
      font-size: 0.95rem;
    }
    
    .bloque-contenido td {
      padding: 0.875rem 1rem;
      border-bottom: 1px solid #E0E0E0;
    }
    
    .bloque-contenido tbody tr:hover {
      background: #FFF5E6;
    }
    
    .bloque-contenido tbody tr:last-child td {
      border-bottom: none;
    }
    
    /* Cajas especiales (Importante, Tip, Error) */
    .bloque-contenido blockquote {
      border-left: 4px solid #E67817;
      padding: 1rem 1rem 1rem 3rem;
      margin: 1.5rem 0;
      border-radius: 8px;
      position: relative;
      background: #FFF5E6;
    }
    
    .bloque-contenido blockquote::before {
      content: "💡";
      position: absolute;
      left: 1rem;
      top: 1rem;
      font-size: 1.5rem;
    }
    
    /* Listas numeradas con círculos */
    .bloque-contenido ol {
      counter-reset: paso-counter;
      list-style: none;
      padding-left: 0;
    }
    
    .bloque-contenido ol > li {
      counter-increment: paso-counter;
      position: relative;
      padding-left: 3rem;
      margin-bottom: 1rem;
    }
    
    .bloque-contenido ol > li::before {
      content: counter(paso-counter);
      position: absolute;
      left: 0;
      top: 0;
      width: 2rem;
      height: 2rem;
      background: #E67817;
      color: white;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 600;
      font-size: 1rem;
    }
    
    /* Listas anidadas: estilo normal */
    .bloque-contenido ol ol,
    .bloque-contenido ol ul {
      margin-left: 2rem;
      margin-top: 0.5rem;
      list-style: disc;
    }
    
    .bloque-contenido ol ol {
      list-style: decimal;
    }
    
    /* Autoevaluación (details) */
    .bloque-contenido details {
      background: #F0F4F8;
      border: 2px solid #E67817;
      border-radius: 8px;
      padding: 1rem;
      margin: 1.5rem 0;
    }
    
    .bloque-contenido summary {
      cursor: pointer;
      font-weight: 600;
      color: #E67817;
      padding: 0.5rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    .bloque-contenido summary::before {
      content: "▶";
      transition: transform 0.3s;
    }
    
    .bloque-contenido details[open] summary::before {
      transform: rotate(90deg);
    }
    
    .bloque-transicion {
      text-align: center;
      font-size: 2rem;
      color: #E67817;
      margin-top: 2rem;
    }
    
    .pie {
      text-align: center;
      padding: 2rem;
      color: #7F8C8D;
      font-size: 0.9rem;
      border-top: 2px solid #E67817;
      margin-top: 3rem;
    }
    
    .pie p {
      margin-bottom: 0.5rem;
    }
    
    /* Estilos para impresión / PDF */
    @media print {
      body {
        background: white;
      }
      
      .btn-pdf {
        display: none;
      }
      
      .portada {
        page-break-after: always;
      }
      
      .indice {
        page-break-after: always;
      }
      
      .bloque {
        page-break-inside: avoid;
        page-break-after: always;
        box-shadow: none;
        border: 1px solid #E0E0E0;
      }
      
      .bloque-transicion {
        display: none;
      }
      
      /* Evitar saltos que dejen hojas en blanco */
      .bloque-contenido,
      .bloque-visuales {
        page-break-inside: avoid;
        break-inside: avoid;
      }
      
      figure, .importante, .tip, .ejemplo {
        page-break-inside: avoid;
        break-inside: avoid;
      }
      
      /* Solo salto ANTES de bloques si es necesario */
      h2 {
        page-break-before: auto;
        break-before: auto;
      }
      
      h2:first-child {
        page-break-before: avoid;
        break-before: avoid;
      }
      
      /* Imágenes adaptables para PDF */
      .visual-mapa-mental img,
      .visual-ilustracion img {
        max-width: 100% !important;
        max-height: 45vh !important;
        height: auto !important;
        object-fit: contain !important;
      }
      
      figure img {
        max-height: 9cm !important;
      }
      
      a {
        color: #2C3E50;
        text-decoration: underline;
      }
      
      /* Asegurar tablas visibles */
      table {
        page-break-inside: avoid;
        break-inside: avoid;
      }
      
      tr {
        page-break-inside: avoid;
        break-inside: avoid;
      }
    }
  </style>"""


def _markdown_simple_a_html(md: str) -> str:
    """Convierte Markdown a HTML usando librería markdown con extensiones.
    
    Soporta: títulos, párrafos, listas, tablas, blockquotes, código, etc.
    Fallback a conversor simple si markdown no está instalado.
    """
    try:
        import markdown
        
        # Usar extensiones para tablas, listas numeradas, atributos, etc.
        md_processor = markdown.Markdown(extensions=[
            'tables',          # Soporte para tablas
            'fenced_code',     # Bloques de código con ```
            'nl2br',           # Saltos de línea → <br>
            'sane_lists',      # Listas numeradas y no numeradas mejoradas
            'attr_list'        # Atributos en elementos
        ])
        
        return md_processor.convert(md)
    
    except ImportError:
        # Fallback a conversor simple si markdown no está instalado
        return _markdown_fallback_simple(md)


def _markdown_fallback_simple(md: str) -> str:
    """Conversor markdown simple como fallback si la librería no está disponible."""
    html = []
    lineas = md.split("\n")
    en_lista = False
    
    for linea in lineas:
        stripped = linea.strip()
        
        # Encabezados
        if stripped.startswith("### "):
            html.append(f"<h3>{_escape_html(stripped[4:])}</h3>")
        elif stripped.startswith("## "):
            html.append(f"<h2>{_escape_html(stripped[3:])}</h2>")
        elif stripped.startswith("# "):
            html.append(f"<h1>{_escape_html(stripped[2:])}</h1>")
        # Listas
        elif stripped.startswith("- ") or stripped.startswith("* "):
            if not en_lista:
                html.append("<ul>")
                en_lista = True
            html.append(f"<li>{_escape_html(stripped[2:])}</li>")
        # Párrafo
        elif stripped:
            if en_lista:
                html.append("</ul>")
                en_lista = False
            html.append(f"<p>{_escape_html(stripped)}</p>")
        else:
            if en_lista:
                html.append("</ul>")
                en_lista = False
    
    if en_lista:
        html.append("</ul>")
    
    return "\n".join(html)


def _escape_html(texto: str) -> str:
    """Escapa caracteres HTML."""
    return (texto
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;"))
