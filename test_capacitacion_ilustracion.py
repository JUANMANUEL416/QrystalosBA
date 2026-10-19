#!/usr/bin/env python3
"""Tests para ilustraciones de capacitación con OpenAI."""
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_ilustracion as cap_ilustra
import soporte_consultas as sc


def test_es_capacitacion():
    """Test: Detectar casos de capacitación."""
    print("Test 1: Detectar casos de capacitación...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        carpeta = Path(tmpdir)
        
        # Caso 1: tipo explícito
        meta1 = {"tipo": "capacitacion"}
        assert cap_ilustra._es_capacitacion(meta1, carpeta), "Debe detectar tipo explícito"
        
        # Caso 2: entregaRequerimiento con palabras clave
        meta2 = {
            "entregaRequerimiento": True,
            "preguntaInicial": "Necesito la capacitación de cómo configurar bodegas"
        }
        assert cap_ilustra._es_capacitacion(meta2, carpeta), "Debe detectar por palabras clave"
        
        # Caso 3: existe guion-capacitacion.md
        meta3 = {}
        material = carpeta / "material"
        material.mkdir(parents=True, exist_ok=True)
        (material / "guion-capacitacion.md").write_text("## Sección 1\nContenido", encoding="utf-8")
        assert cap_ilustra._es_capacitacion(meta3, carpeta), "Debe detectar por guion existente"
        
        # Caso 4: no es capacitación
        meta4 = {"preguntaInicial": "Error en la impresión de facturas"}
        carpeta4 = Path(tmpdir) / "otro"
        carpeta4.mkdir(exist_ok=True)
        assert not cap_ilustra._es_capacitacion(meta4, carpeta4), "No debe detectar como capacitación"
        
        print("✓ Test detectar capacitación: OK")


def test_extraer_secciones():
    """Test: Extraer secciones del guion."""
    print("\nTest 2: Extraer secciones del guion...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        guion = Path(tmpdir) / "guion.md"
        guion.write_text("""# Capacitación

## Introducción al sistema
Este es el contenido de la introducción.

## Configuración de bodegas
Pasos para configurar las bodegas.

## Flujo de movimientos
Cómo registrar movimientos.

## Cierre de periodo
Proceso de cierre mensual.
""", encoding="utf-8")
        
        secciones = cap_ilustra._extraer_secciones(guion)
        
        assert len(secciones) == 4, f"Esperaba 4 secciones, obtuvo {len(secciones)}"
        assert secciones[0]["titulo"] == "Introducción al sistema"
        assert "introducción" in secciones[0]["resumen"].lower()
        
        print("✓ Test extraer secciones: OK")


def test_limpiar_texto_prompt():
    """Test: Limpiar texto para prompt de imagen."""
    print("\nTest 3: Limpiar texto para prompt...")
    
    texto = """Este es el proceso.
    
```sql
SELECT * FROM TABLA
WHERE ID = 1
```

El archivo está en activo/caso-123/sql/script.sql

Ejecutar: python scripts/sqlix_bajar_objeto.py

El procedimiento SPQ_CONFIRMAR valida en DESAIX.
"""
    
    limpio = cap_ilustra._limpiar_texto_para_prompt(texto)
    
    assert "SELECT" not in limpio, "No debe contener SQL"
    assert "activo/" not in limpio, "No debe contener rutas internas"
    assert "python scripts/" not in limpio, "No debe contener comandos Python"
    assert "SPQ_CONFIRMAR" not in limpio, "No debe contener nombres de SP"
    assert "DESAIX" not in limpio, "No debe contener DESAIX"
    assert "proceso" in limpio, "Debe mantener el contenido funcional"
    
    print("✓ Test limpiar texto: OK")


def test_generar_ilustraciones_sin_api_key():
    """Test: Fallar gracefully cuando no hay API key."""
    print("\nTest 4: Sin API key de OpenAI...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        
        meta = sc.crear_consulta(
            "Test capacitación",
            "Necesito capacitación sobre bodegas",
            "Test User"
        )
        sid = meta["id"]
        
        # Crear material
        carpeta = sc.carpeta_consulta(sid)
        material = carpeta / "material"
        material.mkdir(parents=True, exist_ok=True)
        (material / "guion-capacitacion.md").write_text("## Sección 1\nContenido", encoding="utf-8")
        
        # Mock sin API key
        with patch('openai_sugerir.load_config') as mock_config:
            mock_config.return_value = {"apiKey": "", "modelo": "gpt-4o-mini"}
            
            meta_updated = sc.leer_meta(sid)
            result = cap_ilustra.generar_ilustraciones(sid, meta_updated)
            
            assert not result.get("ok"), "Debe fallar sin API key"
            assert result.get("error") == "sin_api_key"
            assert "OPENAI_API_KEY" in result.get("mensaje", "")
        
        print("✓ Test sin API key: OK")


def test_generar_ilustraciones_mock():
    """Test: Generar ilustraciones con API mock."""
    print("\nTest 5: Generar ilustraciones (mock)...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        
        meta = sc.crear_consulta(
            "Capacitación bodegas",
            "Manual de configuración de bodegas",
            "Test User"
        )
        sid = meta["id"]
        
        # Crear material
        carpeta = sc.carpeta_consulta(sid)
        material = carpeta / "material"
        material.mkdir(parents=True, exist_ok=True)
        (material / "guion-capacitacion.md").write_text("""## Introducción
Bienvenido al sistema de bodegas.

## Configuración inicial
Pasos para configurar las bodegas.

## Flujo de movimientos
Cómo registrar entradas y salidas.
""", encoding="utf-8")
        
        # Mock de OpenAI
        fake_image_data = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        
        with patch('openai_sugerir.load_config') as mock_config, \
             patch('openai_sugerir.generar_imagen') as mock_generar:
            
            mock_config.return_value = {
                "apiKey": "sk-test-key",
                "modelo": "gpt-4o-mini",
                "baseUrl": "https://api.openai.com/v1"
            }
            
            def fake_generar(prompt, dest_path, size="1536x1024"):
                # Crear imagen fake
                Path(dest_path).write_bytes(fake_image_data)
                return {
                    "ok": True,
                    "archivo": dest_path,
                    "modelo": "gpt-image-1",
                    "bytes": len(fake_image_data)
                }
            
            mock_generar.side_effect = fake_generar
            
            meta_updated = sc.leer_meta(sid)
            result = cap_ilustra.generar_ilustraciones(sid, meta_updated)
            
            assert result.get("ok"), f"Debe generar ilustraciones: {result.get('mensaje')}"
            assert result.get("total") >= 1, "Debe generar al menos 1 ilustración"
            
            # Verificar que se crearon archivos
            ilustraciones = result.get("ilustraciones", [])
            assert len(ilustraciones) > 0, "Debe haber ilustraciones"
            
            # Verificar tipos
            tipos = {i["tipo"] for i in ilustraciones}
            assert "mapa_mental" in tipos or "seccion" in tipos
            
            # Verificar que se actualizó meta.json
            meta_final = sc.leer_meta(sid)
            assert len(meta_final.get("imagenes", [])) >= 1
            
            # Verificar mensaje en chat
            chat = sc.leer_chat(sid)
            mensajes_sistema = [m for m in chat["mensajes"] if m["autor"] == "sistema"]
            assert any("ilustración" in m["texto"].lower() for m in mensajes_sistema)
        
        print("✓ Test generar ilustraciones (mock): OK")


def test_no_capacitacion():
    """Test: No generar para casos que no son capacitación."""
    print("\nTest 6: Casos no-capacitación...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        
        meta = sc.crear_consulta(
            "Error en facturación",
            "La factura no se genera correctamente",
            "Test User"
        )
        sid = meta["id"]
        
        result = cap_ilustra.generar_ilustraciones(sid, meta)
        
        assert not result.get("ok"), "No debe generar para casos no-capacitación"
        assert result.get("error") == "no_capacitacion"
        
        print("✓ Test no-capacitación: OK")


if __name__ == "__main__":
    try:
        test_es_capacitacion()
        test_extraer_secciones()
        test_limpiar_texto_prompt()
        test_generar_ilustraciones_sin_api_key()
        test_generar_ilustraciones_mock()
        test_no_capacitacion()
        
        print("\n✅ Todos los tests de capacitación pasaron correctamente")
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
