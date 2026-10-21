#!/usr/bin/env python3
"""Test de renderizado HTML de capacitaciones.

Verifica:
1. No hay '##' literales (encabezados sin renderizar)
2. No hay párrafos monstruosamente largos (>600 caracteres)
3. Tablas markdown se renderizan como <table>
4. Listas se renderizan como <ul>/<ol>
5. Encabezados se renderizan como <h2>, <h3>
"""

import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_ensamblar as ensamblar
import capacitacion_bloques as bloques


def test_no_encabezados_sin_renderizar():
    """Test 1: HTML no debe contener '##' literal."""
    print("Test 1: Verificar que no hay encabezados markdown sin renderizar...")
    
    resultado = ensamblar.ensamblar_documento(
        tema_id="inventario",
        bloques_ids=["tipos-de-bodega-itbod"],
        titulo="Test Renderizado",
        formato="html",
        audiencia="usuario-final"
    )
    
    assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
    
    # Leer HTML generado
    archivo_url = resultado["archivo_html"]
    archivo_path = ROOT / archivo_url
    html = archivo_path.read_text(encoding="utf-8")
    
    # Buscar '##' literales (fuera de comentarios HTML)
    # Eliminar comentarios HTML primero
    html_sin_comentarios = re.sub(r'<!--.*?-->', '', html, flags=re.DOTALL)
    
    matches = re.findall(r'(?<![<>])##(?![<>])', html_sin_comentarios)
    
    assert len(matches) == 0, f"Se encontraron {len(matches)} encabezados '##' sin renderizar en el HTML"
    
    print(f"  ✓ No hay encabezados sin renderizar")
    print("✅ Test encabezados: OK\n")


def test_no_parrafos_monstruosos():
    """Test 2: Párrafos no deben exceder ~600 caracteres."""
    print("Test 2: Verificar que no hay párrafos excesivamente largos...")
    
    resultado = ensamblar.ensamblar_documento(
        tema_id="inventario",
        bloques_ids=["tipos-de-bodega-itbod"],
        titulo="Test Renderizado",
        formato="html",
        audiencia="usuario-final"
    )
    
    assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
    
    # Leer HTML generado
    archivo_url = resultado["archivo_html"]
    archivo_path = ROOT / archivo_url
    html = archivo_path.read_text(encoding="utf-8")
    
    # Buscar párrafos <p>...</p>
    parrafos = re.findall(r'<p>(.*?)</p>', html, flags=re.DOTALL)
    
    parrafos_largos = []
    for i, p in enumerate(parrafos):
        # Quitar tags HTML internos
        texto = re.sub(r'<[^>]+>', '', p)
        if len(texto) > 600:
            parrafos_largos.append((i, len(texto), texto[:100] + "..."))
    
    if parrafos_largos:
        print(f"  ❌ Se encontraron {len(parrafos_largos)} párrafos muy largos:")
        for idx, longitud, preview in parrafos_largos[:3]:
            print(f"     Párrafo {idx}: {longitud} caracteres")
            print(f"     Preview: {preview}")
        assert False, f"Hay {len(parrafos_largos)} párrafos que exceden 600 caracteres"
    
    print(f"  ✓ Todos los párrafos tienen longitud razonable")
    print(f"  ✓ Total de párrafos: {len(parrafos)}")
    print("✅ Test párrafos: OK\n")


def test_tablas_renderizadas():
    """Test 3: Tablas markdown se convierten a <table>."""
    print("Test 3: Verificar que tablas markdown se renderizan...")
    
    resultado = ensamblar.ensamblar_documento(
        tema_id="inventario",
        bloques_ids=["tipos-de-articulo-itar"],  # Este tiene tabla de campos
        titulo="Test Tablas",
        formato="html",
        audiencia="usuario-final"
    )
    
    assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
    
    # Leer HTML generado
    archivo_url = resultado["archivo_html"]
    archivo_path = ROOT / archivo_url
    html = archivo_path.read_text(encoding="utf-8")
    
    # Verificar que hay <table>
    tablas = re.findall(r'<table', html)
    
    assert len(tablas) > 0, "No se encontraron tablas <table> en el HTML (las tablas markdown no se renderizaron)"
    
    print(f"  ✓ Se encontraron {len(tablas)} tabla(s) renderizada(s)")
    print("✅ Test tablas: OK\n")


def test_listas_renderizadas():
    """Test 4: Listas markdown se convierten a <ul>/<ol>."""
    print("Test 4: Verificar que listas markdown se renderizan...")
    
    resultado = ensamblar.ensamblar_documento(
        tema_id="inventario",
        bloques_ids=["tipos-de-bodega-itbod"],
        titulo="Test Listas",
        formato="html",
        audiencia="usuario-final"
    )
    
    assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
    
    # Leer HTML generado
    archivo_url = resultado["archivo_html"]
    archivo_path = ROOT / archivo_url
    html = archivo_path.read_text(encoding="utf-8")
    
    # Verificar que hay <ul> o <ol>
    listas_ul = re.findall(r'<ul', html)
    listas_ol = re.findall(r'<ol', html)
    
    total_listas = len(listas_ul) + len(listas_ol)
    
    # Debería haber al menos algunas listas
    assert total_listas > 0, "No se encontraron listas <ul>/<ol> en el HTML"
    
    print(f"  ✓ Se encontraron {len(listas_ul)} lista(s) no numerada(s) <ul>")
    print(f"  ✓ Se encontraron {len(listas_ol)} lista(s) numerada(s) <ol>")
    print("✅ Test listas: OK\n")


def test_encabezados_renderizados():
    """Test 5: Encabezados markdown se convierten a <h2>, <h3>."""
    print("Test 5: Verificar que encabezados markdown se renderizan...")
    
    resultado = ensamblar.ensamblar_documento(
        tema_id="inventario",
        bloques_ids=["tipos-de-bodega-itbod"],
        titulo="Test Encabezados",
        formato="html",
        audiencia="usuario-final"
    )
    
    assert resultado.get("ok"), f"Error al ensamblar: {resultado.get('error')}"
    
    # Leer HTML generado
    archivo_url = resultado["archivo_html"]
    archivo_path = ROOT / archivo_url
    html = archivo_path.read_text(encoding="utf-8")
    
    # Verificar que hay <h2>, <h3>
    h2 = re.findall(r'<h2', html)
    h3 = re.findall(r'<h3', html)
    
    assert len(h2) > 0, "No se encontraron encabezados <h2> en el HTML"
    
    print(f"  ✓ Se encontraron {len(h2)} encabezado(s) <h2>")
    print(f"  ✓ Se encontraron {len(h3)} encabezado(s) <h3>")
    print("✅ Test encabezados renderizados: OK\n")


def main():
    """Ejecuta todos los tests."""
    print("=" * 60)
    print("TEST DE RENDERIZADO HTML - CAPACITACIONES")
    print("=" * 60)
    print()
    
    tests = [
        ("Encabezados sin renderizar", test_no_encabezados_sin_renderizar),
        ("Párrafos monstruosos", test_no_parrafos_monstruosos),
        ("Tablas renderizadas", test_tablas_renderizadas),
        ("Listas renderizadas", test_listas_renderizadas),
        ("Encabezados renderizados", test_encabezados_renderizados)
    ]
    
    resultados = []
    for nombre, test_func in tests:
        try:
            test_func()
            resultados.append((nombre, True))
        except Exception as e:
            print(f"\n❌ Error en test '{nombre}': {e}")
            import traceback
            traceback.print_exc()
            resultados.append((nombre, False))
    
    # Resumen
    print("=" * 60)
    print("RESUMEN")
    print("=" * 60)
    
    aprobados = sum(1 for _, exito in resultados if exito)
    total = len(resultados)
    
    for nombre, exito in resultados:
        estado = "✓ APROBADO" if exito else "❌ FALLIDO"
        print(f"{estado}: {nombre}")
    
    print(f"\nTotal: {aprobados}/{total} tests aprobados")
    
    if aprobados == total:
        print("\n🎉 ¡Todos los tests de renderizado pasaron!")
        return 0
    else:
        print(f"\n⚠️  {total - aprobados} test(s) fallaron")
        return 1


if __name__ == "__main__":
    sys.exit(main())
