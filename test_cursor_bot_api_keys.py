#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test para verificar el orden de carga de claves API de Cursor."""
import os
import sys
import tempfile
from pathlib import Path

# Force UTF-8 output to avoid Windows cp1252 crashes
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import cursor_bot


def test_carga_claves_env_file_priority():
    """
    Test para verificar que las claves del archivo .env tienen prioridad sobre os.environ.
    
    Escenario del bug de producción:
    1. Un turno corre con CURSOR_API_KEY_2, setea os.environ["CURSOR_API_KEY"] = <valor de KEY_2>
    2. Un turno encadenado en el mismo proceso (_disparar_siguiente) intenta cargar las claves
    3. Bug anterior: load_cursor_api_keys() leía os.environ primero, encontraba CURSOR_API_KEY
       con el valor de KEY_2, hacía que KEY_2 fuera un duplicado y clave_por_etiqueta('CURSOR_API_KEY_2')
       retornaba ''.
    4. Fix: leer env.get(name) primero, luego os.environ.get(name) como fallback.
    """
    print("Test: Prioridad del archivo .env sobre os.environ...")
    
    # Crear un .env temporal con dos claves distintas
    with tempfile.TemporaryDirectory() as tmpdir:
        env_path = Path(tmpdir) / ".env"
        
        # Dos claves distintas (sufijos diferentes para identificarlas)
        key1_value = "crsr_key1_aaaa1111222233334444"
        key2_value = "crsr_key2_bbbb5555666677778888"
        
        env_path.write_text(
            f"CURSOR_API_KEY={key1_value}\n"
            f"CURSOR_API_KEY_2={key2_value}\n",
            encoding="utf-8"
        )
        
        # Simular el escenario del bug: un turno anterior seteó os.environ["CURSOR_API_KEY"]
        # con el valor de CURSOR_API_KEY_2
        original_env_key = os.environ.get("CURSOR_API_KEY")
        original_env_key2 = os.environ.get("CURSOR_API_KEY_2")
        
        try:
            # Simular el estado después del primer turno: CURSOR_API_KEY en os.environ
            # tiene el valor de CURSOR_API_KEY_2
            os.environ["CURSOR_API_KEY"] = key2_value
            
            # Cargar las claves (simular lo que hace el turno encadenado)
            # Parchear temporalmente la ruta del .env
            original_env_path = cursor_bot.ENV_PATH
            cursor_bot.ENV_PATH = str(env_path)
            
            try:
                pairs = cursor_bot.load_cursor_api_keys()
                
                # Verificar que se cargaron ambas claves sin duplicados
                assert len(pairs) == 2, f"Esperaba 2 claves, obtuvo {len(pairs)}: {pairs}"
                
                # Verificar que las etiquetas son correctas
                labels = [label for label, _ in pairs]
                assert "CURSOR_API_KEY" in labels, f"Falta CURSOR_API_KEY en {labels}"
                assert "CURSOR_API_KEY_2" in labels, f"Falta CURSOR_API_KEY_2 en {labels}"
                
                # Verificar que CURSOR_API_KEY tiene su propio valor del .env (no el de KEY_2)
                key1_loaded = cursor_bot.clave_por_etiqueta("CURSOR_API_KEY")
                assert key1_loaded == key1_value, \
                    f"CURSOR_API_KEY debería ser {key1_value[-8:]}, obtuvo {key1_loaded[-8:]}"
                
                # Verificar que CURSOR_API_KEY_2 también se cargó correctamente
                key2_loaded = cursor_bot.clave_por_etiqueta("CURSOR_API_KEY_2")
                assert key2_loaded == key2_value, \
                    f"CURSOR_API_KEY_2 debería ser {key2_value[-8:]}, obtuvo {key2_loaded[-8:]}"
                
                # Verificar que los valores son distintos
                assert key1_loaded != key2_loaded, \
                    "CURSOR_API_KEY y CURSOR_API_KEY_2 no deben tener el mismo valor"
                
                print("  ✓ Ambas claves cargadas correctamente")
                print(f"    CURSOR_API_KEY:   ...{key1_loaded[-8:]}")
                print(f"    CURSOR_API_KEY_2: ...{key2_loaded[-8:]}")
                
            finally:
                cursor_bot.ENV_PATH = original_env_path
        
        finally:
            # Restaurar el estado original de os.environ
            if original_env_key is not None:
                os.environ["CURSOR_API_KEY"] = original_env_key
            elif "CURSOR_API_KEY" in os.environ:
                del os.environ["CURSOR_API_KEY"]
            
            if original_env_key2 is not None:
                os.environ["CURSOR_API_KEY_2"] = original_env_key2
            elif "CURSOR_API_KEY_2" in os.environ:
                del os.environ["CURSOR_API_KEY_2"]
    
    print("✓ Test carga de claves con prioridad .env: OK")


def test_orden_claves_sin_conflicto():
    """Test básico: verificar que el orden de claves funciona cuando no hay conflicto."""
    print("\nTest: Orden de claves sin conflicto en os.environ...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        env_path = Path(tmpdir) / ".env"
        
        key1_value = "crsr_test1_aaaa1111222233334444"
        key2_value = "crsr_test2_bbbb5555666677778888"
        
        env_path.write_text(
            f"CURSOR_API_KEY={key1_value}\n"
            f"CURSOR_API_KEY_2={key2_value}\n",
            encoding="utf-8"
        )
        
        original_env_path = cursor_bot.ENV_PATH
        cursor_bot.ENV_PATH = str(env_path)
        
        try:
            pairs = cursor_bot.load_cursor_api_keys()
            
            assert len(pairs) == 2, f"Esperaba 2 claves, obtuvo {len(pairs)}"
            
            # Verificar el orden: CURSOR_API_KEY primero, luego CURSOR_API_KEY_2
            assert pairs[0][0] == "CURSOR_API_KEY", \
                f"Primera clave debería ser CURSOR_API_KEY, obtuvo {pairs[0][0]}"
            assert pairs[1][0] == "CURSOR_API_KEY_2", \
                f"Segunda clave debería ser CURSOR_API_KEY_2, obtuvo {pairs[1][0]}"
            
            print("  ✓ Orden de claves correcto")
            
        finally:
            cursor_bot.ENV_PATH = original_env_path
    
    print("✓ Test orden de claves: OK")


if __name__ == "__main__":
    try:
        test_carga_claves_env_file_priority()
        test_orden_claves_sin_conflicto()
        print("\n✅ Todos los tests de API keys pasaron correctamente")
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
