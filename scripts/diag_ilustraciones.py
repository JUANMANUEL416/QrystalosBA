#!/usr/bin/env python3
"""
Script de diagnóstico para ilustraciones de capacitación.

Prueba Gemini y OpenAI con una imagen pequeña e informa:
- Si las API keys se cargan correctamente desde .env
- Si las APIs responden
- Errores HTTP exactos (sin imprimir las keys)
- Qué proveedor funcionó

Uso:
    python scripts/diag_ilustraciones.py
"""
import sys
from pathlib import Path

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
# Protege contra UnicodeEncodeError en consolas cp1252 (Windows service)
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Añadir scripts/ al path
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))

import capacitacion_visuales as visuales


def diagnosticar():
    """Ejecuta diagnóstico completo de ilustraciones."""
    print("=" * 70)
    print("DIAGNÓSTICO DE ILUSTRACIONES PARA CAPACITACIONES")
    print("=" * 70)
    print()
    
    # 1. Verificar carga de .env
    print("1. Verificando carga de .env...")
    print("-" * 70)
    
    env_path = visuales.ENV_PATH
    print(f"   Ruta .env: {env_path}")
    print(f"   Existe: {'Sí' if env_path.exists() else 'No'}")
    print()
    
    # Verificar variables
    gemini_key = visuales._get_env("GEMINI_API_KEY")
    openai_key = visuales._get_env("OPENAI_API_KEY")
    proveedor = visuales._get_env("CAPACITACION_IMAGE_PROVIDER", "gemini")
    gemini_model = visuales._get_env("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    openai_model = visuales._get_env("OPENAI_IMAGE_MODEL", "gpt-image-1")
    
    print(f"   Variables encontradas:")
    print(f"     CAPACITACION_IMAGE_PROVIDER = {proveedor}")
    print(f"     GEMINI_API_KEY = {'✓ configurada' if gemini_key else '✗ no encontrada'}")
    print(f"     GEMINI_IMAGE_MODEL = {gemini_model}")
    print(f"     OPENAI_API_KEY = {'✓ configurada' if openai_key else '✗ no encontrada'}")
    print(f"     OPENAI_IMAGE_MODEL = {openai_model}")
    print()
    
    # 2. Probar Gemini
    print("2. Probando Gemini Image Generation...")
    print("-" * 70)
    
    if not gemini_key:
        print("   ⊗ GEMINI_API_KEY no configurada, omitiendo prueba")
        gemini_ok = False
    else:
        try:
            print(f"   Modelo: {gemini_model}")
            print(f"   Generando imagen de prueba...")
            
            prompt = "Simple icon: a blue book"
            data_uri = visuales.generar_ilustracion_gemini(prompt, modelo=gemini_model)
            
            if data_uri:
                size_kb = len(data_uri) / 1024
                print(f"   ✓ ÉXITO: Gemini generó imagen ({size_kb:.1f} KB)")
                gemini_ok = True
            else:
                print(f"   ✗ FALLO: Gemini no generó imagen (ver logs arriba)")
                gemini_ok = False
        except Exception as e:
            print(f"   ✗ ERROR: {e}")
            gemini_ok = False
    
    print()
    
    # 3. Probar OpenAI
    print("3. Probando OpenAI Image Generation...")
    print("-" * 70)
    
    if not openai_key:
        print("   ⊗ OPENAI_API_KEY no configurada, omitiendo prueba")
        openai_ok = False
    else:
        try:
            print(f"   Modelo: {openai_model}")
            print(f"   Generando imagen de prueba...")
            
            prompt = "Simple icon: a red apple"
            url = visuales.generar_ilustracion_openai(prompt, modelo=openai_model, tamano="256x256")
            
            if url:
                print(f"   ✓ ÉXITO: OpenAI generó imagen")
                print(f"     URL: {url[:60]}...")
                
                # Intentar descargar
                print(f"   Descargando imagen...")
                data_uri = visuales._descargar_imagen_como_data_uri(url)
                if data_uri:
                    size_kb = len(data_uri) / 1024
                    print(f"   ✓ ÉXITO: Imagen descargada ({size_kb:.1f} KB)")
                    openai_ok = True
                else:
                    print(f"   ✗ FALLO: No se pudo descargar imagen")
                    openai_ok = False
            else:
                print(f"   ✗ FALLO: OpenAI no generó URL (ver logs arriba)")
                openai_ok = False
        except Exception as e:
            print(f"   ✗ ERROR: {e}")
            openai_ok = False
    
    print()
    
    # 4. Probar SVG local (fallback)
    print("4. Probando generador SVG local (fallback)...")
    print("-" * 70)
    
    try:
        svg = visuales.generar_infografia_svg_fallback("Prueba", ["Contenido de prueba"])
        if svg:
            size_kb = len(svg) / 1024
            print(f"   ✓ ÉXITO: SVG local generado ({size_kb:.1f} KB)")
            svg_ok = True
        else:
            print(f"   ✗ FALLO: SVG local no generó contenido")
            svg_ok = False
    except Exception as e:
        print(f"   ✗ ERROR: {e}")
        svg_ok = False
    
    print()
    
    # 5. Resumen
    print("=" * 70)
    print("RESUMEN DEL DIAGNÓSTICO")
    print("=" * 70)
    print()
    
    print("Estado de los proveedores:")
    print(f"  Gemini:     {'✓ FUNCIONA' if gemini_ok else ('⊗ No configurada' if not gemini_key else '✗ FALLO')}")
    print(f"  OpenAI:     {'✓ FUNCIONA' if openai_ok else ('⊗ No configurada' if not openai_key else '✗ FALLO')}")
    print(f"  SVG local:  {'✓ FUNCIONA' if svg_ok else '✗ FALLO'}")
    print()
    
    if gemini_ok or openai_ok or svg_ok:
        print("✓ Al menos un proveedor funciona correctamente")
        if gemini_ok:
            print("  → Recomendación: usar Gemini (default)")
        elif openai_ok:
            print("  → Recomendación: cambiar CAPACITACION_IMAGE_PROVIDER=openai en .env")
        else:
            print("  → Solo SVG local disponible (sin APIs externas)")
        return 0
    else:
        print("✗ NINGÚN proveedor funciona")
        print()
        print("Acciones recomendadas:")
        if not gemini_key and not openai_key:
            print("  1. Agregar GEMINI_API_KEY o OPENAI_API_KEY en .env")
            print("  2. Verificar que las keys sean válidas")
        else:
            print("  1. Revisar logs de error arriba")
            print("  2. Verificar conectividad a internet")
            print("  3. Verificar que las API keys sean válidas")
        return 1


if __name__ == "__main__":
    sys.exit(diagnosticar())
