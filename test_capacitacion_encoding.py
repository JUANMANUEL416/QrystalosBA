#!/usr/bin/env python3
"""Test de encoding: simula consola cp1252 y verifica que ensamblar no falla."""

import io
import sys
import tempfile
from pathlib import Path

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))


def test_ensamblar_con_cp1252():
    """Simula stdout cp1252 y verifica que ensamblar no falla con emojis/✓/✗."""
    print("Test: Ensamblado con stdout simulado cp1252...")
    print("-" * 70)
    
    # Guardar stdout/stderr originales
    stdout_original = sys.stdout
    stderr_original = sys.stderr
    
    try:
        # Simular consola cp1252 (Windows LocalSystem)
        # TextIOWrapper con cp1252 que falla con caracteres no representables
        buffer = io.BytesIO()
        sys.stdout = io.TextIOWrapper(buffer, encoding='cp1252', errors='strict')
        sys.stderr = io.TextIOWrapper(buffer, encoding='cp1252', errors='strict')
        
        # Intentar importar los módulos (esto reconfigura stdout/stderr)
        print("  1. Importando capacitacion_ensamblar...")
        import capacitacion_ensamblar as ensamblar
        
        print("  2. Importando capacitacion_visuales...")
        import capacitacion_visuales as visuales
        
        # Ahora stdout/stderr deben estar reconfigurados a utf-8 con errors='replace'
        print("  3. Verificando reconfiguración...")
        
        # Intentar imprimir caracteres problemáticos
        print("  4. Probando caracteres: ✓ ✗ ⚠️ → 📚")
        
        # Ensamblar un documento de prueba
        print("  5. Ensamblando documento de prueba...")
        resultado = ensamblar.ensamblar_documento(
            tema_id="inventario",
            bloques_ids=["tipos-de-bodega-itbod"],
            titulo="Test Encoding",
            formato="html",
            audiencia="usuario-final"
        )
        
        assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
        print(f"  ✓ Documento ensamblado: {resultado['archivo_html']}")
        
    except UnicodeEncodeError as e:
        # Si llegamos aquí, la reconfiguración NO funcionó
        print(f"\n  ✗ FALLO: UnicodeEncodeError no manejado")
        print(f"     {e}")
        return False
    
    except Exception as e:
        print(f"\n  ✗ ERROR inesperado: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        # Restaurar stdout/stderr originales
        sys.stdout = stdout_original
        sys.stderr = stderr_original
    
    print("\n✅ Test encoding: OK")
    print("   La reconfiguración UTF-8 funciona correctamente")
    return True


def test_print_seguro():
    """Verifica que los módulos pueden imprimir emojis sin fallar."""
    print("\nTest: Print seguro de emojis...")
    print("-" * 70)
    
    try:
        # Importar módulos
        import capacitacion_ensamblar as ensamblar
        import capacitacion_visuales as visuales
        
        # Probar caracteres problemáticos
        chars_problematicos = [
            "✓", "✗", "⚠️", "→", "📚", "🎯", "📋", "🔧",
            "✅", "❌", "⊗", "←", "↑", "↓"
        ]
        
        print("  Caracteres problemáticos:")
        for char in chars_problematicos:
            print(f"    {char}", end=" ")
        print()
        
        print("\n✅ Test print: OK")
        return True
    
    except Exception as e:
        print(f"\n✗ ERROR: {e}")
        return False


if __name__ == "__main__":
    print("=" * 70)
    print("TESTS DE ENCODING PARA CAPACITACIONES")
    print("=" * 70)
    print()
    
    # Ejecutar tests
    test1_ok = test_ensamblar_con_cp1252()
    test2_ok = test_print_seguro()
    
    print()
    print("=" * 70)
    print("RESUMEN")
    print("=" * 70)
    
    if test1_ok and test2_ok:
        print("✅ Todos los tests de encoding pasaron")
        sys.exit(0)
    else:
        print("❌ Algunos tests fallaron")
        sys.exit(1)
