"""Ensamblador de documentos de capacitación desde bloques modulares.

Une bloques seleccionados en un documento unificado (HTML y/o DOCX).
"""
from __future__ import annotations

import base64
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CAPACITACION = ROOT / "capacitacion"
BLOQUES_DIR = CAPACITACION / "bloques"
SALIDA_DIR = CAPACITACION / "documentos"

import capacitacion_bloques as bloques


def ensamblar_documento(
    tema_id: str,
    bloques_ids: list[str],
    titulo: str | None = None,
    formato: str = "html",
    incluir_indice: bool = True,
    incluir_imagenes: bool = True
) -> dict:
    """Ensambla un documento de capacitación desde bloques.
    
    Args:
        tema_id: ID del tema (para contexto)
        bloques_ids: Lista de IDs de bloques a incluir
        titulo: Título del documento (opcional, se genera si falta)
        formato: "html", "docx" o "ambos"
        incluir_indice: Si True, genera índice al inicio
        incluir_imagenes: Si True, incrusta imágenes en el documento
    
    Returns:
        {
            "ok": bool,
            "archivo_html": str,  # Ruta si formato incluye html
            "archivo_docx": str,  # Ruta si formato incluye docx
            "bloques": list[str],  # IDs en orden
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
        "agregados": deps.get("agregados", [])
    }
    
    # Generar HTML
    if formato in ("html", "ambos"):
        archivo_html = SALIDA_DIR / f"{nombre_base}.html"
        html_content = _generar_html(tema, titulo, orden, incluir_indice, incluir_imagenes)
        archivo_html.write_text(html_content, encoding="utf-8")
        resultado["archivo_html"] = str(archivo_html)
    
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


def _generar_html(
    tema: dict | None,
    titulo: str,
    bloques_ids: list[str],
    incluir_indice: bool,
    incluir_imagenes: bool
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
    
    # Portada
    lineas.append('  <div class="portada">')
    lineas.append('    <div class="portada-logo">')
    lineas.append('      <img src="../app/assets/logo-ixcolombia.png" alt="IX Colombia" />')
    lineas.append('    </div>')
    lineas.append(f'    <h1 class="portada-titulo">{titulo}</h1>')
    if tema:
        lineas.append(f'    <p class="portada-subtitulo">{tema.get("descripcion", "")}</p>')
    lineas.append(f'    <p class="portada-fecha">Generado: {datetime.now().strftime("%d/%m/%Y %H:%M")}</p>')
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
        
        contenido_md = bloques.leer_contenido_bloque(bloque_id)
        
        lineas.append(f'  <section class="bloque" id="bloque-{bloque_id}">')
        lineas.append(f'    <div class="bloque-numero">Módulo {i}</div>')
        lineas.append(f'    <h2 class="bloque-titulo">{bloque_meta["titulo"]}</h2>')
        
        # Imágenes del bloque (antes del contenido)
        if incluir_imagenes:
            imagenes = bloque_meta.get("imagenes", [])
            if imagenes:
                lineas.append('    <div class="bloque-imagenes">')
                for img in imagenes:
                    img_path = BLOQUES_DIR / bloque_id / "imagenes" / img["nombre"]
                    if img_path.exists():
                        # Incrustar como data URI
                        img_data = base64.b64encode(img_path.read_bytes()).decode("utf-8")
                        lineas.append(f'      <figure class="bloque-imagen bloque-imagen-{img["tipo"]}">')
                        lineas.append(f'        <img src="data:image/png;base64,{img_data}" alt="{img["titulo"]}" />')
                        lineas.append(f'        <figcaption>{img["titulo"]}</figcaption>')
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
    """Estilos CSS embebidos para el documento."""
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
      background: #F8F9FA;
    }
    
    .portada {
      background: linear-gradient(135deg, #E67817 0%, #F39C12 100%);
      color: white;
      padding: 4rem 2rem;
      text-align: center;
      page-break-after: always;
    }
    
    .portada-logo img {
      max-width: 200px;
      margin-bottom: 2rem;
      filter: brightness(0) invert(1);
    }
    
    .portada-titulo {
      font-size: 3rem;
      font-weight: 700;
      margin-bottom: 1rem;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    
    .portada-subtitulo {
      font-size: 1.3rem;
      margin-bottom: 2rem;
      opacity: 0.95;
    }
    
    .portada-fecha {
      font-size: 1rem;
      opacity: 0.9;
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
    
    .bloque {
      background: white;
      padding: 3rem 2rem;
      margin: 2rem auto;
      max-width: 900px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      page-break-inside: avoid;
    }
    
    .bloque-numero {
      display: inline-block;
      background: #E67817;
      color: white;
      padding: 0.3rem 1rem;
      border-radius: 20px;
      font-size: 0.9rem;
      font-weight: 600;
      margin-bottom: 1rem;
    }
    
    .bloque-titulo {
      font-size: 2.2rem;
      color: #2C3E50;
      margin-bottom: 2rem;
      border-bottom: 3px solid #E67817;
      padding-bottom: 0.5rem;
    }
    
    .bloque-imagenes {
      display: flex;
      flex-wrap: wrap;
      gap: 1rem;
      margin-bottom: 2rem;
    }
    
    .bloque-imagen {
      flex: 1;
      min-width: 300px;
      text-align: center;
    }
    
    .bloque-imagen img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    
    .bloque-imagen figcaption {
      margin-top: 0.5rem;
      font-size: 0.9rem;
      color: #7F8C8D;
      font-style: italic;
    }
    
    .bloque-imagen-mapa_mental {
      flex-basis: 100%;
    }
    
    .bloque-contenido {
      font-size: 1.05rem;
      line-height: 1.8;
    }
    
    .bloque-contenido h2 {
      color: #34495E;
      margin-top: 2rem;
      margin-bottom: 1rem;
      font-size: 1.6rem;
    }
    
    .bloque-contenido h3 {
      color: #5D6D7E;
      margin-top: 1.5rem;
      margin-bottom: 0.8rem;
      font-size: 1.3rem;
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
    
    @media print {
      .portada, .indice, .bloque {
        box-shadow: none;
        page-break-inside: avoid;
      }
      
      .bloque-transicion {
        display: none;
      }
    }
  </style>"""


def _markdown_simple_a_html(md: str) -> str:
    """Convierte Markdown simple a HTML.
    
    Soporta: títulos, párrafos, listas, blockquotes, código inline y bloques.
    """
    lineas = md.split("\n")
    html = []
    en_lista = False
    en_blockquote = False
    en_codigo = False
    
    for linea in lineas:
        # Bloques de código
        if linea.strip().startswith("```"):
            if not en_codigo:
                html.append("<pre><code>")
                en_codigo = True
            else:
                html.append("</code></pre>")
                en_codigo = False
            continue
        
        if en_codigo:
            html.append(_escape_html(linea))
            continue
        
        # Blockquote
        if linea.strip().startswith(">"):
            if not en_blockquote:
                html.append("<blockquote>")
                en_blockquote = True
            texto = linea.strip()[1:].strip()
            html.append(f"<p>{_procesar_inline(texto)}</p>")
            continue
        elif en_blockquote:
            html.append("</blockquote>")
            en_blockquote = False
        
        # Títulos
        if linea.startswith("### "):
            html.append(f"<h3>{_procesar_inline(linea[4:])}</h3>")
            continue
        elif linea.startswith("## "):
            html.append(f"<h2>{_procesar_inline(linea[3:])}</h2>")
            continue
        elif linea.startswith("# "):
            html.append(f"<h1>{_procesar_inline(linea[2:])}</h1>")
            continue
        
        # Listas
        if linea.strip().startswith("- ") or linea.strip().startswith("* "):
            if not en_lista:
                html.append("<ul>")
                en_lista = True
            texto = linea.strip()[2:]
            html.append(f"<li>{_procesar_inline(texto)}</li>")
            continue
        elif en_lista:
            html.append("</ul>")
            en_lista = False
        
        # Párrafo
        if linea.strip():
            html.append(f"<p>{_procesar_inline(linea)}</p>")
        else:
            html.append("")
    
    # Cerrar tags abiertos
    if en_lista:
        html.append("</ul>")
    if en_blockquote:
        html.append("</blockquote>")
    if en_codigo:
        html.append("</code></pre>")
    
    return "\n".join(html)


def _procesar_inline(texto: str) -> str:
    """Procesa formatos inline: **negrita**, `código`, etc."""
    # Código inline (antes de negrita/cursiva, no escapar contenido)
    partes = []
    ultimo = 0
    for match in re.finditer(r"`([^`]+)`", texto):
        partes.append(_escape_html(texto[ultimo:match.start()]))
        partes.append(f"<code>{_escape_html(match.group(1))}</code>")
        ultimo = match.end()
    partes.append(_escape_html(texto[ultimo:]))
    texto = "".join(partes)
    
    # Negrita
    texto = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", texto)
    
    # Cursiva (solo * solitarios)
    texto = re.sub(r"(?<!\*)\*([^*]+)\*", r"<em>\1</em>", texto)
    
    return texto


def _escape_html(texto: str) -> str:
    """Escapa caracteres HTML."""
    return (texto
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;"))
