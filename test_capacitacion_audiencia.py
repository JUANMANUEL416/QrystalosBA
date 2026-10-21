#!/usr/bin/env python3
"""
Test de audiencia para capacitaciones.

Verifica que:
1. Usuario final: NO contiene nombres de SPs (SPQ_, SPK_, SP_)
2. Soporte y desarrollo: SÍ contiene nombres de SPs y métodos
"""

import sys
import re
from pathlib import Path

# Agregar scripts al path
PROYECTO_DIR = Path(__file__).parent
sys.path.insert(0, str(PROYECTO_DIR / "scripts"))

from capacitacion_ensamblar import ensamblar_documento


def test_audiencia_usuario_final():
    """Test: Usuario final NO debe ver nombres de SPs."""
    print("\n=== Test: Audiencia Usuario Final ===")
    
    # Ensamblar documento para usuario final
    resultado = ensamblar_documento(
        tema_id="inventarios",
        bloques_ids=["tipos-de-articulo-itar"],
        titulo="Test Usuario Final",
        formato="html",
        incluir_indice=True,
        incluir_imagenes=False,
        audiencia="usuario-final"
    )
    
    if not resultado.get("ok"):
        print(f"❌ Error al ensamblar: {resultado.get('error')}")
        return False
    
    # Leer el HTML generado
    archivo_html = resultado.get("archivo_html", "")
    ruta_html = PROYECTO_DIR / "capacitacion" / "documentos" / archivo_html.split('/')[-1]
    
    if not ruta_html.exists():
        print(f"❌ No se encontró el archivo: {ruta_html}")
        return False
    
    contenido = ruta_html.read_text(encoding="utf-8")
    
    # Buscar nombres de SPs (SPQ_, SPK_, SP_)
    patron_sps = r'\b(SPQ_|SPK_|SP_)[A-Z_0-9]+\b'
    matches = re.findall(patron_sps, contenido, re.IGNORECASE)
    
    if matches:
        print(f"❌ Usuario final contiene {len(matches)} referencias a SPs:")
        for match in set(matches):
            print(f"   - {match}")
        return False
    
    print("✓ Usuario final NO contiene nombres de SPs")
    print(f"✓ Archivo generado: {archivo_html}")
    return True


def test_audiencia_soporte_desarrollo():
    """Test: Soporte y desarrollo SÍ debe ver nombres de SPs."""
    print("\n=== Test: Audiencia Soporte y Desarrollo ===")
    
    # Ensamblar documento para soporte
    resultado = ensamblar_documento(
        tema_id="inventarios",
        bloques_ids=["tipos-de-articulo-itar"],
        titulo="Test Soporte y Desarrollo",
        formato="html",
        incluir_indice=True,
        incluir_imagenes=False,
        audiencia="soporte-desarrollo"
    )
    
    if not resultado.get("ok"):
        print(f"❌ Error al ensamblar: {resultado.get('error')}")
        return False
    
    # Leer el HTML generado
    archivo_html = resultado.get("archivo_html", "")
    ruta_html = PROYECTO_DIR / "capacitacion" / "documentos" / archivo_html.split('/')[-1]
    
    if not ruta_html.exists():
        print(f"❌ No se encontró el archivo: {ruta_html}")
        return False
    
    contenido = ruta_html.read_text(encoding="utf-8")
    
    # Buscar sección técnica
    tiene_seccion_tecnica = "Referencia técnica" in contenido or "Stored Procedures" in contenido
    
    # Buscar nombres de SPs (SPQ_, SPK_, SP_)
    patron_sps = r'\b(SPQ_|SPK_|SP_)[A-Z_0-9]+\b'
    matches = re.findall(patron_sps, contenido, re.IGNORECASE)
    
    if not tiene_seccion_tecnica:
        print("⚠️  No se encontró sección técnica (puede que el bloque no tenga SPs)")
    
    # Si el bloque tiene SPs registrados, debe mostrarlos
    if not matches and tiene_seccion_tecnica:
        print("❌ Soporte y desarrollo NO contiene nombres de SPs (esperado si hay SPs)")
        return False
    
    if matches:
        print(f"✓ Soporte y desarrollo contiene {len(set(matches))} SP(s):")
        for sp in set(matches):
            print(f"   - {sp}")
    
    print(f"✓ Archivo generado: {archivo_html}")
    return True


def test_diferencia_entre_audiencias():
    """Test: Verificar que hay diferencia real entre audiencias."""
    print("\n=== Test: Diferencia entre Audiencias ===")
    
    # Generar ambas versiones
    resultado_usuario = ensamblar_documento(
        tema_id="inventarios",
        bloques_ids=["tipos-de-articulo-itar"],
        titulo="Test Comparación Usuario",
        formato="html",
        incluir_indice=False,
        incluir_imagenes=False,
        audiencia="usuario-final"
    )
    
    resultado_soporte = ensamblar_documento(
        tema_id="inventarios",
        bloques_ids=["tipos-de-articulo-itar"],
        titulo="Test Comparación Soporte",
        formato="html",
        incluir_indice=False,
        incluir_imagenes=False,
        audiencia="soporte-desarrollo"
    )
    
    if not resultado_usuario.get("ok") or not resultado_soporte.get("ok"):
        print("❌ Error al generar documentos")
        return False
    
    # Leer ambos archivos
    ruta_usuario = PROYECTO_DIR / "capacitacion" / "documentos" / resultado_usuario["archivo_html"].split('/')[-1]
    ruta_soporte = PROYECTO_DIR / "capacitacion" / "documentos" / resultado_soporte["archivo_html"].split('/')[-1]
    
    contenido_usuario = ruta_usuario.read_text(encoding="utf-8")
    contenido_soporte = ruta_soporte.read_text(encoding="utf-8")
    
    # El contenido de soporte debe ser igual o más largo
    if len(contenido_soporte) < len(contenido_usuario):
        print(f"⚠️  Contenido soporte ({len(contenido_soporte)} chars) más corto que usuario ({len(contenido_usuario)} chars)")
    
    # Usuario NO debe tener sección técnica
    tiene_tecnico_usuario = "Referencia técnica" in contenido_usuario
    tiene_tecnico_soporte = "Referencia técnica" in contenido_soporte or "Stored Procedures" in contenido_soporte
    
    if tiene_tecnico_usuario:
        print("❌ Usuario final tiene sección técnica (no debería)")
        return False
    
    print("✓ Usuario final NO tiene sección técnica")
    
    if tiene_tecnico_soporte:
        print("✓ Soporte tiene sección técnica")
    else:
        print("⚠️  Soporte no tiene sección técnica (puede que el bloque no tenga SPs)")
    
    return True


def main():
    """Ejecuta todos los tests."""
    print("=" * 60)
    print("TEST DE AUDIENCIA - CAPACITACIONES MODULARES")
    print("=" * 60)
    
    tests = [
        ("Usuario Final", test_audiencia_usuario_final),
        ("Soporte y Desarrollo", test_audiencia_soporte_desarrollo),
        ("Diferencia entre Audiencias", test_diferencia_entre_audiencias)
    ]
    
    resultados = []
    for nombre, test_func in tests:
        try:
            exito = test_func()
            resultados.append((nombre, exito))
        except Exception as e:
            print(f"\n❌ Error en test '{nombre}': {e}")
            import traceback
            traceback.print_exc()
            resultados.append((nombre, False))
    
    # Resumen
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    
    aprobados = sum(1 for _, exito in resultados if exito)
    total = len(resultados)
    
    for nombre, exito in resultados:
        estado = "✓ APROBADO" if exito else "❌ FALLIDO"
        print(f"{estado}: {nombre}")
    
    print(f"\nTotal: {aprobados}/{total} tests aprobados")
    
    if aprobados == total:
        print("\n🎉 ¡Todos los tests pasaron!")
        return 0
    else:
        print(f"\n⚠️  {total - aprobados} test(s) fallaron")
        return 1


if __name__ == "__main__":
    sys.exit(main())
