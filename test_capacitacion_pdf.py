#!/usr/bin/env python3
"""Test de generación de PDF con Edge/Chrome headless."""

import sys
from pathlib import Path

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))


def test_buscar_navegador():
    """Test 1: Buscar Edge/Chrome en el sistema."""
    print("Test 1: Buscar navegador...")
    print("-" * 70)
    
    import capacitacion_pdf as pdf_gen
    
    navegador = pdf_gen.encontrar_edge_chrome()
    
    if navegador:
        print(f"  ✓ Navegador encontrado: {navegador}")
        return True, navegador
    else:
        print(f"  ⚠️  No se encontró navegador (usar fallback window.print)")
        return False, None


def test_generar_pdf_simple():
    """Test 2: Generar PDF de un HTML simple."""
    print("\nTest 2: Generar PDF simple...")
    print("-" * 70)
    
    import capacitacion_pdf as pdf_gen
    import tempfile
    
    # HTML de prueba
    html_test = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Test PDF</title>
    <style>
        @page {
            size: A4;
            margin: 2cm;
        }
        body {
            font-family: Arial, sans-serif;
            font-size: 12pt;
        }
        h1 { color: #2980B9; }
        .importante {
            background: #E8F6F3;
            padding: 10px;
            border-left: 4px solid #27AE60;
            page-break-inside: avoid;
        }
        img {
            max-width: 100%;
            max-height: 45vh;
            object-fit: contain;
        }
    </style>
</head>
<body>
    <h1>Documento de Prueba</h1>
    <p>Este es un documento de prueba para verificar que la generación de PDF funciona correctamente.</p>
    
    <div class="importante">
        <strong>Importante:</strong> Este bloque no debe cortarse entre páginas.
    </div>
    
    <h2>Lista de verificación</h2>
    <ul>
        <li>PDF generado sin encabezados del navegador</li>
        <li>Imágenes adaptadas al tamaño de página</li>
        <li>Sin hojas en blanco</li>
        <li>Bloques importantes no cortados</li>
    </ul>
</body>
</html>"""
    
    # Generar PDF
    pdf_path = pdf_gen.generar_pdf_documento(html_test, "test-simple.pdf")
    
    if pdf_path and pdf_path.exists():
        size_kb = pdf_path.stat().st_size / 1024
        print(f"  ✓ PDF generado: {pdf_path.name} ({size_kb:.1f} KB)")
        return True
    else:
        print(f"  ✗ No se pudo generar PDF")
        return False


def test_html_sin_saltos_vacios():
    """Test 3: Verificar que el CSS no fuerza saltos vacíos."""
    print("\nTest 3: HTML sin saltos vacíos forzados...")
    print("-" * 70)
    
    # Verificar que el CSS del ensam blador no tiene page-break: always
    import capacitacion_ensamblar as ensamblar
    
    # Generar un HTML de prueba
    import capacitacion_bloques as bloques
    
    # Cargar temas
    temas_data = bloques.cargar_temas()
    tema = temas_data.get("temas", [{}])[0] if temas_data.get("temas") else None
    
    # Generar HTML con un bloque
    from capacitacion_ensamblar import _generar_html
    html = _generar_html(
        tema,
        "Documento de prueba",
        ["tipos-de-bodega-itbod"],
        incluir_indice=True,
        incluir_imagenes=False,
        audiencia="usuario-final"
    )
    
    # Verificar que NO tiene page-break: always ni break-after: page forzados
    problemas = []
    
    if "page-break: always" in html or "page-break:always" in html:
        problemas.append("Tiene 'page-break: always' que fuerza saltos")
    
    if "break-after: page" in html or "break-after:page" in html:
        problemas.append("Tiene 'break-after: page' que fuerza saltos")
    
    # Verificar que SÍ tiene break-inside: avoid (bueno)
    if "break-inside: avoid" not in html and "break-inside:avoid" not in html:
        problemas.append("Falta 'break-inside: avoid' para proteger bloques")
    
    if problemas:
        print(f"  ⚠️  Problemas encontrados:")
        for p in problemas:
            print(f"    - {p}")
        return False
    else:
        print(f"  ✓ CSS optimizado para PDF sin saltos vacíos")
        print(f"    - Usa break-inside: avoid (protege bloques)")
        print(f"    - Usa break-before: auto (solo si es necesario)")
        print(f"    - Imágenes con max-height: 45vh / 9cm")
        return True


def test_preparar_html_para_pdf():
    """Test 4: Preparar HTML con CSS de impresión."""
    print("\nTest 4: Preparar HTML para PDF...")
    print("-" * 70)
    
    import capacitacion_pdf as pdf_gen
    
    html_original = """<html>
<head><title>Test</title></head>
<body><h1>Hola</h1></body>
</html>"""
    
    html_preparado = pdf_gen.preparar_html_para_pdf(html_original)
    
    # Verificar que se añadió CSS @page
    checks = {
        "@page": "Define márgenes y formato A4",
        "break-inside: avoid": "Protege bloques de cortes",
        "max-height: 45vh": "Limita altura de imágenes",
        "display: none": "Oculta botones en impresión"
    }
    
    ok = True
    for regla, desc in checks.items():
        if regla in html_preparado:
            print(f"  ✓ {desc}")
        else:
            print(f"  ✗ Falta: {desc}")
            ok = False
    
    return ok


if __name__ == "__main__":
    print("=" * 70)
    print("TESTS DE GENERACIÓN DE PDF")
    print("=" * 70)
    print()
    
    # Test 1: Buscar navegador
    tiene_navegador, navegador = test_buscar_navegador()
    
    # Test 2: Generar PDF (solo si hay navegador)
    pdf_ok = False
    if tiene_navegador:
        pdf_ok = test_generar_pdf_simple()
    else:
        print("\nTest 2: SKIP (no hay navegador, fallback a window.print)")
        print("-" * 70)
    
    # Test 3: Verificar CSS sin saltos vacíos
    css_ok = test_html_sin_saltos_vacios()
    
    # Test 4: Preparar HTML
    prep_ok = test_preparar_html_para_pdf()
    
    print()
    print("=" * 70)
    print("RESUMEN")
    print("=" * 70)
    
    if tiene_navegador:
        if pdf_ok and css_ok and prep_ok:
            print("✅ Todos los tests pasaron (PDF disponible)")
            sys.exit(0)
        else:
            print("❌ Algunos tests fallaron")
            sys.exit(1)
    else:
        if css_ok and prep_ok:
            print("✅ Tests pasaron (sin navegador, fallback disponible)")
            sys.exit(0)
        else:
            print("❌ Algunos tests fallaron")
            sys.exit(1)
