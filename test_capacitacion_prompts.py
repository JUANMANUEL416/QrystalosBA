#!/usr/bin/env python3
"""
Test: Verifica que los prompts de imagen NO contengan códigos de tabla ni palabras de armas.
"""

import sys
from pathlib import Path

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))


def test_escenas_sin_codigos():
    """Test 1: Verificar que las escenas no contienen códigos de tabla."""
    print("Test 1: Escenas sin códigos de tabla...")
    print("-" * 70)
    
    from capacitacion_escenas import ESCENAS_BLOQUES, validar_prompt_sin_codigos
    
    problemas_encontrados = []
    
    for bloque_id, escena in ESCENAS_BLOQUES.items():
        valido, problemas = validar_prompt_sin_codigos(escena)
        
        if not valido:
            print(f"  ✗ {bloque_id}")
            for p in problemas:
                print(f"      {p}")
            problemas_encontrados.append(bloque_id)
        else:
            print(f"  ✓ {bloque_id}")
    
    if problemas_encontrados:
        print(f"\n  ❌ {len(problemas_encontrados)} bloques con problemas")
        return False
    else:
        print(f"\n  ✅ Todas las escenas OK ({len(ESCENAS_BLOQUES)} bloques)")
        return True


def test_validador_detecta_codigos():
    """Test 2: Verificar que el validador detecta códigos prohibidos."""
    print("\nTest 2: Validador detecta códigos prohibidos...")
    print("-" * 70)
    
    from capacitacion_escenas import validar_prompt_sin_codigos
    
    # Casos de prueba
    casos = [
        # (prompt, debe_ser_valido)
        ("Hospital pharmacy warehouse with medications", True),
        ("Tipos de artículo ITAR para hospital", False),  # Contiene ITAR
        ("Warehouse with weapons and ammunition", False),  # Contiene weapons
        ("IART database for medical devices", False),  # Contiene IART
        ("SPQ_IART stored procedure", False),  # Contiene SPQ_
        ("Clean professional hospital scene", True),
        ("Military equipment storage", False),  # Contiene military
        ("Armamento y munición", False),  # Contiene arma/munición
    ]
    
    todos_ok = True
    
    for prompt, esperado_valido in casos:
        valido, problemas = validar_prompt_sin_codigos(prompt)
        
        if valido == esperado_valido:
            print(f"  ✓ '{prompt[:50]}...' → {'válido' if valido else 'inválido'} (esperado)")
        else:
            print(f"  ✗ '{prompt[:50]}...' → {'válido' if valido else 'inválido'} (esperaba {'válido' if esperado_valido else 'inválido'})")
            if problemas:
                for p in problemas:
                    print(f"      {p}")
            todos_ok = False
    
    if todos_ok:
        print(f"\n  ✅ Validador funciona correctamente")
        return True
    else:
        print(f"\n  ❌ Validador tiene errores")
        return False


def test_prompts_generados():
    """Test 3: Verificar prompts generados por generar_ilustracion_completa."""
    print("\nTest 3: Prompts generados sin códigos...")
    print("-" * 70)
    
    from capacitacion_escenas import obtener_escena_bloque, validar_prompt_sin_codigos
    
    # Bloques de prueba
    bloques_prueba = [
        "tipos-de-articulo-itar",
        "articulos-iart",
        "servicios-ser",
        "tipos-de-movimiento-itmo"
    ]
    
    todos_ok = True
    
    for bloque_id in bloques_prueba:
        escena = obtener_escena_bloque(bloque_id)
        
        # Simular prompt que se generaría (sin la parte FORBIDDEN que contiene palabras prohibidas)
        prompt = (
            f"Professional clean illustration for hospital pharmacy warehouse inventory. "
            f"Scene: {escena}. "
            f"Style: clean, professional, soft hospital colors."
        )
        
        valido, problemas = validar_prompt_sin_codigos(prompt)
        
        if valido:
            print(f"  ✓ {bloque_id}")
        else:
            print(f"  ✗ {bloque_id}")
            for p in problemas:
                print(f"      {p}")
            todos_ok = False
    
    if todos_ok:
        print(f"\n  ✅ Todos los prompts generados son válidos")
        return True
    else:
        print(f"\n  ❌ Algunos prompts generados tienen problemas")
        return False


if __name__ == "__main__":
    print("=" * 70)
    print("TESTS DE PROMPTS DE IMAGEN")
    print("=" * 70)
    print()
    
    test1_ok = test_escenas_sin_codigos()
    test2_ok = test_validador_detecta_codigos()
    test3_ok = test_prompts_generados()
    
    print()
    print("=" * 70)
    print("RESUMEN")
    print("=" * 70)
    
    if test1_ok and test2_ok and test3_ok:
        print("✅ Todos los tests de prompts pasaron")
        sys.exit(0)
    else:
        print("❌ Algunos tests de prompts fallaron")
        sys.exit(1)
