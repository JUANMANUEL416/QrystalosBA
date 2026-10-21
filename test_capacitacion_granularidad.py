#!/usr/bin/env python3
"""Test de granularidad de bloques de capacitación."""
import re
import sys
from pathlib import Path

# Configurar encoding UTF-8
if sys.stdout.encoding != 'utf-8':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_bloques as bloques


def test_bloque_no_mezcla_tablas():
    """Test 1: Un bloque no debe mezclar ITAR/IART/SER."""
    print("Test 1: Verificar que ningún bloque mezcle múltiples tablas...")
    
    todos_bloques = bloques.listar_bloques()
    
    # Patrones que indican mezcla de tablas
    patrones_mixtos = [
        (r"ITAR.*IART", "ITAR e IART"),
        (r"IART.*SER", "IART y SER"),
        (r"ITAR.*SER", "ITAR y SER"),
        (r"ITBOD.*IBOD", "ITBOD e IBOD"),
        (r"ITMO.*USVGS", "ITMO y USVGS"),
    ]
    
    bloques_mixtos = []
    
    for bloque in todos_bloques:
        titulo = bloque.get("titulo", "")
        
        for patron, tablas in patrones_mixtos:
            if re.search(patron, titulo, re.IGNORECASE):
                bloques_mixtos.append({
                    "id": bloque.get("id"),
                    "titulo": titulo,
                    "tablas_mezcladas": tablas
                })
                print(f"  ❌ Bloque mezcla tablas: {titulo} ({tablas})")
    
    assert len(bloques_mixtos) == 0, \
        f"Se encontraron {len(bloques_mixtos)} bloque(s) que mezclan tablas: {[b['titulo'] for b in bloques_mixtos]}"
    
    print(f"  ✓ {len(todos_bloques)} bloques verificados, ninguno mezcla tablas")
    print("✅ Test granularidad: OK\n")


def test_bloques_granulares_existen():
    """Test 2: Verificar que existen los bloques granulares."""
    print("Test 2: Verificar existencia de bloques granulares...")
    
    bloques_esperados = [
        "tipos-de-bodega-itbod",
        "bodegas-ibod",
        "tipos-de-movimiento-itmo",
        "variables-de-sistema-usvgs",
        "tipos-de-articulo-itar",
        "articulos-iart",
        "servicios-ser",
        "articulo-por-bodega-idxb",
    ]
    
    todos_bloques = {b["id"]: b for b in bloques.listar_bloques()}
    
    faltantes = []
    for bloque_id in bloques_esperados:
        if bloque_id in todos_bloques:
            print(f"  ✓ {bloque_id}")
        else:
            print(f"  ❌ Falta: {bloque_id}")
            faltantes.append(bloque_id)
    
    assert len(faltantes) == 0, \
        f"Faltan {len(faltantes)} bloque(s) granular(es): {faltantes}"
    
    print("✅ Test bloques granulares existen: OK\n")


def test_prerrequisitos_correctos():
    """Test 3: Verificar que los prerrequisitos sean correctos."""
    print("Test 3: Verificar prerrequisitos de bloques granulares...")
    
    esperados = {
        "articulos-iart": ["tipos-de-articulo-itar"],
        "servicios-ser": ["articulos-iart"],
        "articulo-por-bodega-idxb": ["articulos-iart", "bodegas-ibod"],
        "bodegas-ibod": ["tipos-de-bodega-itbod"],
    }
    
    errores = []
    
    for bloque_id, prereqs_esperados in esperados.items():
        bloque = bloques.obtener_bloque(bloque_id)
        if not bloque:
            errores.append(f"Bloque {bloque_id} no existe")
            continue
        
        prereqs_actuales = bloque.get("prerrequisitos", [])
        
        if set(prereqs_actuales) != set(prereqs_esperados):
            print(f"  ❌ {bloque_id}:")
            print(f"     Esperado: {prereqs_esperados}")
            print(f"     Actual: {prereqs_actuales}")
            errores.append(f"{bloque_id}: {prereqs_actuales} != {prereqs_esperados}")
        else:
            print(f"  ✓ {bloque_id}: {prereqs_esperados}")
    
    assert len(errores) == 0, \
        f"Errores en prerrequisitos: {errores}"
    
    print("✅ Test prerrequisitos: OK\n")


def test_contenido_pedagogico():
    """Test 4: Verificar que el contenido sea pedagógico."""
    print("Test 4: Verificar contenido pedagógico...")
    
    # Verificar un bloque de muestra
    bloque_id = "tipos-de-articulo-itar"
    bloque = bloques.obtener_bloque(bloque_id)
    
    assert bloque, f"Bloque {bloque_id} no existe"
    
    contenido = bloques.leer_contenido_bloque(bloque_id)
    
    # Verificar secciones pedagógicas
    secciones_requeridas = [
        "🎯 Objetivo",
        "📍 Contexto",
        "📋 Campos relevantes",
        "🔢 Pasos",
        "⚠️ Importante",
        "💡 Tips",
        "📝 Ejemplo",
        "📌 Resumen",
        "✅ Autoevaluación",
    ]
    
    faltantes = []
    for seccion in secciones_requeridas:
        if seccion in contenido:
            print(f"  ✓ {seccion}")
        else:
            print(f"  ❌ Falta: {seccion}")
            faltantes.append(seccion)
    
    assert len(faltantes) == 0, \
        f"Faltan {len(faltantes)} sección(es) pedagógica(s): {faltantes}"
    
    # Verificar tabla de campos con icono decisivo
    assert "🔑" in contenido, "Falta icono 🔑 (campo decisivo) en tabla de campos"
    assert "| Icono | Campo |" in contenido, "Falta tabla de campos con columna Icono"
    
    print("  ✓ Tabla de campos con iconos")
    print("✅ Test contenido pedagógico: OK\n")


def test_version_2():
    """Test 5: Verificar que los bloques granulares sean versión 2.0.0."""
    print("Test 5: Verificar versión de bloques granulares...")
    
    bloques_granulares = [
        "tipos-de-articulo-itar",
        "articulos-iart",
        "servicios-ser",
    ]
    
    for bloque_id in bloques_granulares:
        bloque = bloques.obtener_bloque(bloque_id)
        if not bloque:
            print(f"  ❌ {bloque_id}: no existe")
            continue
        
        version = bloque.get("version", "")
        assert version.startswith("2."), \
            f"Bloque {bloque_id} tiene versión {version}, esperado 2.x.x"
        
        print(f"  ✓ {bloque_id}: versión {version}")
    
    print("✅ Test versión 2: OK\n")


if __name__ == "__main__":
    try:
        test_bloque_no_mezcla_tablas()
        test_bloques_granulares_existen()
        test_prerrequisitos_correctos()
        test_contenido_pedagogico()
        test_version_2()
        
        print("\n" + "=" * 60)
        print("✅ Todos los tests de granularidad pasaron correctamente")
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
