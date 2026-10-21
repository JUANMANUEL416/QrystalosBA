#!/usr/bin/env python3
"""Test del fix de download de documentos de capacitación."""
import sys
import json
import tempfile
from pathlib import Path

# Configurar encoding UTF-8
if sys.stdout.encoding != 'utf-8':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_ensamblar as ensamblar
import capacitacion_bloques as bloques


def test_ensamblar_devuelve_url_relativa():
    """Test 1: ensamblar_documento devuelve URL relativa, no ruta del sistema."""
    print("Test 1: Verificar URL relativa en ensamblar_documento...")
    
    # Crear directorio temporal para salida
    temp_dir = Path(tempfile.mkdtemp())
    ensamblar.SALIDA_DIR = temp_dir
    
    try:
        # Simular ensamblado con bloques granulares actuales
        resultado = ensamblar.ensamblar_documento(
            tema_id="inventario",
            bloques_ids=["tipos-de-bodega-itbod"],
            titulo="Test Manual",
            formato="html"
        )
        
        assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
        assert "archivo_html" in resultado, "Falta archivo_html en resultado"
        
        archivo_html = resultado["archivo_html"]
        
        # Verificar que es URL relativa, no ruta del sistema
        print(f"  archivo_html = {archivo_html}")
        
        # No debe contener backslashes (Windows) ni slashes absolutos (Unix)
        assert '\\' not in archivo_html, f"Tiene backslashes de Windows: {archivo_html}"
        assert not archivo_html.startswith('/'), f"Tiene slash absoluto inicial: {archivo_html}"
        
        # Debe empezar con capacitacion/documentos/
        assert archivo_html.startswith('capacitacion/documentos/'), \
            f"No empieza con capacitacion/documentos/: {archivo_html}"
        
        # Debe terminar en .html
        assert archivo_html.endswith('.html'), f"No termina en .html: {archivo_html}"
        
        # Debe poderse extraer el nombre con split('/')
        nombre = archivo_html.split('/')[-1]
        assert '.html' in nombre, f"Nombre extraído no tiene .html: {nombre}"
        assert len(nombre) > 5, f"Nombre demasiado corto: {nombre}"
        
        print(f"  ✓ URL relativa correcta: {archivo_html}")
        print(f"  ✓ Nombre extraíble: {nombre}")
        print("✅ Test URL relativa: OK\n")
        
    finally:
        # Limpiar
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)


def test_capacitacion_js_tiene_download():
    """Test 2: capacitacion.js usa setAttribute('download', ...)."""
    print("Test 2: Verificar atributo download en capacitacion.js...")
    
    capacitacion_js = ROOT / "app" / "js" / "capacitacion.js"
    contenido = capacitacion_js.read_text(encoding="utf-8")
    
    # Verificar que usa setAttribute('download', nombreArchivo)
    assert "setAttribute('download'" in contenido, \
        "Falta setAttribute('download' en capacitacion.js"
    
    # Verificar que usa la URL correctamente
    assert "const url = `/${data.archivo_html}`" in contenido, \
        "No construye URL con `/${data.archivo_html}`"
    
    # Verificar que asigna href y download
    assert "linkElem.href = url" in contenido, "No asigna linkElem.href = url"
    assert "linkElem.setAttribute('download', nombreArchivo)" in contenido, \
        "No asigna download con nombreArchivo"
    
    print("  ✓ Construye URL con `/${data.archivo_html}`")
    print("  ✓ Asigna linkElem.href = url")
    print("  ✓ Usa setAttribute('download', nombreArchivo)")
    print("✅ Test capacitacion.js: OK\n")


def test_capacitacion_js_tiene_utf8_correcto():
    """Test 3: capacitacion.js tiene acentos correctos."""
    print("Test 3: Verificar UTF-8 en capacitacion.js...")
    
    capacitacion_js = ROOT / "app" / "js" / "capacitacion.js"
    contenido = capacitacion_js.read_text(encoding="utf-8")
    
    # Buscar palabras con acentos que deben estar correctas
    palabras_acentos = [
        "generó",
        "automáticamente",
        "resolverá",
        "generará",
        "agregaron"
    ]
    
    encontradas = []
    for palabra in palabras_acentos:
        if palabra in contenido:
            encontradas.append(palabra)
    
    assert len(encontradas) > 0, "No se encontraron palabras con acentos"
    
    # Verificar que no hay caracteres dañados (� U+FFFD)
    assert '�' not in contenido, "Hay caracteres dañados (�) en capacitacion.js"
    
    for palabra in encontradas:
        print(f"  ✓ Encontrada correctamente: '{palabra}'")
    
    print("✅ Test UTF-8 capacitacion.js: OK\n")


def test_cache_busting_incrementado():
    """Test 4: ?v= incrementado en index.html."""
    print("Test 4: Verificar cache busting incrementado...")
    
    index_html = ROOT / "app" / "index.html"
    contenido = index_html.read_text(encoding="utf-8")
    
    # Verificar capacitacion.js?v=
    assert 'capacitacion.js?v=' in contenido, "Falta ?v= en capacitacion.js"
    
    # Extraer versión
    import re
    match_js = re.search(r'capacitacion\.js\?v=(\d+)', contenido)
    assert match_js, "No se pudo extraer versión de capacitacion.js"
    version_js = int(match_js.group(1))
    
    assert version_js >= 2, f"Versión de capacitacion.js debe ser >= 2, es {version_js}"
    
    # Verificar capacitacion.css?v=
    assert 'capacitacion.css?v=' in contenido, "Falta ?v= en capacitacion.css"
    
    match_css = re.search(r'capacitacion\.css\?v=(\d+)', contenido)
    assert match_css, "No se pudo extraer versión de capacitacion.css"
    version_css = int(match_css.group(1))
    
    assert version_css >= 2, f"Versión de capacitacion.css debe ser >= 2, es {version_css}"
    
    print(f"  ✓ capacitacion.js?v={version_js}")
    print(f"  ✓ capacitacion.css?v={version_css}")
    print("✅ Test cache busting: OK\n")


if __name__ == "__main__":
    try:
        test_ensamblar_devuelve_url_relativa()
        test_capacitacion_js_tiene_download()
        test_capacitacion_js_tiene_utf8_correcto()
        test_cache_busting_incrementado()
        
        print("\n" + "=" * 60)
        print("✅ Todos los tests de download pasaron correctamente")
        print("=" * 60)
        sys.exit(0)
    except AssertionError as e:
        print(f"\n❌ Test falló: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
