#!/usr/bin/env python3
"""
Generador de PDF para documentos de capacitación usando Edge/Chrome headless.

Usa msedge.exe o chrome.exe en modo headless para generar PDFs sin encabezados/pies
del navegador, con CSS optimizado para impresión.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]


def encontrar_edge_chrome() -> Optional[Path]:
    """Busca Edge o Chrome en las rutas comunes de Windows.
    
    Returns:
        Path al ejecutable o None si no se encuentra
    """
    # Posibles rutas de Edge
    rutas_edge = [
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
        Path(os.environ.get("PROGRAMFILES", "")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
    ]
    
    # Posibles rutas de Chrome
    rutas_chrome = [
        Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
        Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
        Path(os.environ.get("PROGRAMFILES", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
    ]
    
    # Probar Edge primero (viene con Windows)
    for ruta in rutas_edge:
        if ruta.exists():
            print(f"  ✓ Edge encontrado: {ruta}")
            return ruta
    
    # Probar Chrome
    for ruta in rutas_chrome:
        if ruta.exists():
            print(f"  ✓ Chrome encontrado: {ruta}")
            return ruta
    
    print(f"  ✗ No se encontró Edge ni Chrome")
    return None


def generar_pdf_headless(
    html_path: Path,
    pdf_path: Path,
    navegador: Optional[Path] = None
) -> bool:
    """Genera PDF usando Edge/Chrome en modo headless.
    
    Args:
        html_path: Ruta al archivo HTML
        pdf_path: Ruta de salida del PDF
        navegador: Path al ejecutable (si None, lo busca automáticamente)
    
    Returns:
        True si se generó correctamente
    """
    if navegador is None:
        navegador = encontrar_edge_chrome()
        if navegador is None:
            print("  ✗ No se encontró navegador para generar PDF")
            return False
    
    if not html_path.exists():
        print(f"  ✗ HTML no existe: {html_path}")
        return False
    
    # Crear directorio de salida si no existe
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Comando para generar PDF
    # --headless: sin ventana
    # --disable-gpu: sin aceleración GPU (más compatible con servicios)
    # --print-to-pdf: generar PDF
    # --no-pdf-header-footer: sin encabezados/pies del navegador
    # --print-to-pdf-no-header: sin encabezado
    # --run-all-compositor-stages-before-draw: esperar renderizado completo
    comando = [
        str(navegador),
        "--headless",
        "--disable-gpu",
        "--disable-software-rasterizer",
        "--disable-dev-shm-usage",
        "--no-sandbox",
        f"--print-to-pdf={pdf_path}",
        "--no-pdf-header-footer",
        "--print-to-pdf-no-header",
        "--run-all-compositor-stages-before-draw",
        f"file:///{html_path.as_posix()}",
    ]
    
    try:
        print(f"  Generando PDF con {navegador.name}...")
        print(f"    HTML: {html_path}")
        print(f"    PDF:  {pdf_path}")
        
        # CREATE_NO_WINDOW en Windows para no mostrar consola
        startupinfo = None
        if sys.platform == "win32":
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
        
        resultado = subprocess.run(
            comando,
            capture_output=True,
            text=True,
            timeout=60,
            startupinfo=startupinfo,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        
        if pdf_path.exists() and pdf_path.stat().st_size > 0:
            print(f"  ✓ PDF generado: {pdf_path.name} ({pdf_path.stat().st_size} bytes)")
            return True
        else:
            print(f"  ✗ PDF no se generó o está vacío")
            if resultado.stderr:
                print(f"    Error: {resultado.stderr[:200]}")
            return False
    
    except subprocess.TimeoutExpired:
        print(f"  ✗ Timeout al generar PDF (>60s)")
        return False
    except Exception as e:
        print(f"  ✗ Error al generar PDF: {e}")
        return False


def preparar_html_para_pdf(html_content: str) -> str:
    """Prepara el HTML para impresión óptima en PDF.
    
    Añade CSS @page y ajustes para evitar hojas en blanco.
    
    Args:
        html_content: Contenido HTML original
    
    Returns:
        HTML con CSS de impresión optimizado
    """
    # CSS para impresión
    css_impresion = """
    <style media="print">
        @page {
            size: A4;
            margin: 2cm 1.5cm 2.5cm 1.5cm;
            
            @bottom-center {
                content: counter(page) " / " counter(pages);
                font-size: 9pt;
                color: #666;
            }
        }
        
        /* Evitar saltos que dejen hojas en blanco */
        .bloque-contenido {
            page-break-inside: avoid;
            break-inside: avoid;
        }
        
        figure, .importante, .tip, .ejemplo {
            page-break-inside: avoid;
            break-inside: avoid;
        }
        
        /* Solo salto ANTES de un bloque si hay contenido */
        h2 {
            page-break-before: auto;
            break-before: auto;
        }
        
        h2:first-child {
            page-break-before: avoid;
            break-before: avoid;
        }
        
        /* Imágenes adaptables */
        img {
            max-width: 100% !important;
            max-height: 45vh !important;
            height: auto !important;
            object-fit: contain !important;
        }
        
        figure img {
            max-height: 9cm !important;
        }
        
        /* Ocultar botones de acción en impresión */
        .acciones-documento,
        .boton-flotante,
        button:not(.importante button):not(.tip button) {
            display: none !important;
        }
        
        /* Asegurar que el contenido sea visible */
        body {
            background: white !important;
            color: black !important;
        }
        
        /* Tablas: evitar cortes */
        table {
            page-break-inside: avoid;
            break-inside: avoid;
        }
        
        tr {
            page-break-inside: avoid;
            break-inside: avoid;
        }
    </style>
    """
    
    # Insertar CSS antes de </head>
    if "</head>" in html_content:
        html_content = html_content.replace("</head>", f"{css_impresion}\n</head>")
    else:
        # Si no hay </head>, insertar al inicio del body
        html_content = html_content.replace("<body>", f"<body>\n{css_impresion}")
    
    return html_content


def generar_pdf_documento(
    html_content: str,
    nombre_archivo: str = "documento.pdf"
) -> Optional[Path]:
    """Genera PDF de un documento de capacitación.
    
    Args:
        html_content: Contenido HTML del documento
        nombre_archivo: Nombre del archivo PDF de salida
    
    Returns:
        Path al PDF generado o None si falló
    """
    print("Generando PDF...")
    
    # Preparar HTML con CSS de impresión
    html_preparado = preparar_html_para_pdf(html_content)
    
    # Crear archivo temporal HTML
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".html",
        delete=False,
        encoding="utf-8"
    ) as tmp_html:
        tmp_html.write(html_preparado)
        tmp_html_path = Path(tmp_html.name)
    
    try:
        # Ruta de salida del PDF
        pdf_path = ROOT / "capacitacion" / "documentos" / nombre_archivo
        
        # Generar PDF
        exito = generar_pdf_headless(tmp_html_path, pdf_path)
        
        if exito:
            return pdf_path
        else:
            return None
    
    finally:
        # Limpiar archivo temporal
        try:
            tmp_html_path.unlink()
        except Exception:
            pass


if __name__ == "__main__":
    # Test: buscar navegador
    print("=" * 70)
    print("TEST: Buscar Edge/Chrome")
    print("=" * 70)
    
    navegador = encontrar_edge_chrome()
    
    if navegador:
        print(f"\n✓ Navegador disponible para generar PDFs")
        sys.exit(0)
    else:
        print(f"\n✗ No hay navegador disponible (fallback a window.print)")
        sys.exit(1)
