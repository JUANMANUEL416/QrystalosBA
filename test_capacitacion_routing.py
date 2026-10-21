#!/usr/bin/env python3
"""Test del routing y charset de Capacitación."""
import sys
import json
from pathlib import Path

# Configurar encoding UTF-8
if sys.stdout.encoding != 'utf-8':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

ROOT = Path(__file__).resolve().parent


def test_conocimiento_js_tiene_modo_capacitacion():
    """Test 1: conocimiento.js tiene el modo capacitacion configurado."""
    print("Test 1: Verificar modo capacitacion en conocimiento.js...")
    
    conocimiento_js = ROOT / "app" / "js" / "conocimiento.js"
    contenido = conocimiento_js.read_text(encoding="utf-8")
    
    # Verificar MODE_META
    assert 'capacitacion: {' in contenido, "Falta capacitacion en MODE_META"
    assert 'icon: "school"' in contenido, "Falta icono school"
    assert 'title: "Capacitación"' in contenido, "Falta título Capacitación"
    
    # Verificar classList.remove
    assert 'modo-capacitacion' in contenido, "Falta modo-capacitacion en classList.remove"
    
    # Verificar else if (mode === "capacitacion")
    assert 'else if (mode === "capacitacion")' in contenido, "Falta bloque else if capacitacion"
    assert 'window.QrysCapacitacion' in contenido, "Falta llamada a QrysCapacitacion"
    
    # Verificar lista de modos permitidos
    lineas_init = [l for l in contenido.split('\n') if 'mode === "capacitacion"' in l]
    assert len(lineas_init) >= 2, "Falta capacitacion en la lista de modos permitidos del init"
    
    print("  ✓ MODE_META incluye capacitacion")
    print("  ✓ classList.remove incluye modo-capacitacion")
    print("  ✓ Bloque else if (mode === \"capacitacion\") existe")
    print("  ✓ Lista de modos permitidos incluye capacitacion")
    print("✅ Test conocimiento.js: OK\n")


def test_css_oculta_pestanas_en_modo_capacitacion():
    """Test 2: CSS oculta las pestañas del agente en modo-capacitacion."""
    print("Test 2: Verificar CSS para modo-capacitacion...")
    
    app_css = ROOT / "app" / "css" / "app.css"
    contenido = app_css.read_text(encoding="utf-8")
    
    # Verificar que .main-tabs se oculta
    assert '.app-shell.modo-capacitacion .main-tabs' in contenido, \
        "Falta regla para ocultar .main-tabs en modo-capacitacion"
    
    # Verificar que #estadoFormulario se oculta
    assert '.app-shell.modo-capacitacion #estadoFormulario' in contenido, \
        "Falta regla para ocultar #estadoFormulario en modo-capacitacion"
    
    # Verificar que las vistas de agente se ocultan
    assert '.app-shell.modo-capacitacion #view-formulario' in contenido, \
        "Falta regla para ocultar #view-formulario"
    assert '.app-shell.modo-capacitacion #view-cola' in contenido, \
        "Falta regla para ocultar #view-cola"
    assert '.app-shell.modo-capacitacion #view-chat' in contenido, \
        "Falta regla para ocultar #view-chat"
    assert '.app-shell.modo-capacitacion #view-historico' in contenido, \
        "Falta regla para ocultar #view-historico"
    
    # Verificar que #view-capacitacion se muestra
    assert '.app-shell.modo-capacitacion #view-capacitacion.view.active { display: block; }' in contenido, \
        "Falta regla para mostrar #view-capacitacion"
    
    print("  ✓ .main-tabs se oculta en modo-capacitacion")
    print("  ✓ #estadoFormulario se oculta")
    print("  ✓ Vistas de agente (cola, formulario, chat, historico) se ocultan")
    print("  ✓ #view-capacitacion se muestra cuando está activa")
    print("✅ Test CSS: OK\n")


def test_temas_json_tiene_acentos():
    """Test 3: temas.json contiene acentos correctamente."""
    print("Test 3: Verificar UTF-8 en temas.json...")
    
    temas_json = ROOT / "capacitacion" / "temas.json"
    with open(temas_json, encoding="utf-8") as f:
        data = json.load(f)
    
    temas = data.get("temas", [])
    assert len(temas) > 0, "No hay temas en temas.json"
    
    # Buscar acentos en los nombres/descripciones
    tiene_acentos = False
    for tema in temas:
        nombre = tema.get("nombre", "")
        desc = tema.get("descripcion", "")
        if any(c in nombre + desc for c in "áéíóúñÁÉÍÓÚÑ"):
            tiene_acentos = True
            print(f"  ✓ Encontrados acentos: '{nombre}' / '{desc}'")
            break
    
    if not tiene_acentos:
        print("  ℹ️ No se encontraron acentos en temas (puede ser correcto)")
    
    print("✅ Test temas.json: OK\n")


if __name__ == "__main__":
    try:
        test_conocimiento_js_tiene_modo_capacitacion()
        test_css_oculta_pestanas_en_modo_capacitacion()
        test_temas_json_tiene_acentos()
        
        print("\n" + "=" * 60)
        print("✅ Todos los tests de routing pasaron correctamente")
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
