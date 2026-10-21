#!/usr/bin/env python3
"""Tests para el sistema de capacitaciones modulares."""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

# Configurar encoding UTF-8
if sys.stdout.encoding != 'utf-8':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_bloques as bloques
import capacitacion_ensamblar as ensamblar


def test_cargar_temas():
    """Test: Cargar catálogo de temas."""
    print("Test 1: Cargar temas...")
    
    temas_data = bloques.cargar_temas()
    assert "temas" in temas_data, "Debe tener campo 'temas'"
    
    temas = temas_data["temas"]
    assert len(temas) > 0, "Debe haber al menos un tema"
    
    tema = temas[0]
    assert "id" in tema, "Tema debe tener id"
    assert "nombre" in tema, "Tema debe tener nombre"
    assert "descripcion" in tema, "Tema debe tener descripcion"
    
    print(f"  ✓ {len(temas)} tema(s) cargado(s)")
    print("✅ Test cargar temas: OK\n")


def test_slug():
    """Test: Conversión a slug."""
    print("Test 2: Conversión a slug...")
    
    assert bloques._slug("Configuración de Bodega") == "configuracion-de-bodega"
    assert bloques._slug("ORDEN DE COMPRA") == "orden-de-compra"
    assert bloques._slug("Artículos · Catálogo") == "articulos-catalogo"
    assert bloques._slug("Notas DB/CR") == "notas-db-cr"
    
    print("  ✓ Slugs generados correctamente")
    print("✅ Test slug: OK\n")


def test_generar_bloque_mock():
    """Test: Generar bloque desde control (mock)."""
    print("Test 3: Generar bloque desde control (mock)...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        # Mockear directorios
        bloques.BLOQUES_DIR = Path(tmpdir) / "bloques"
        bloques.BLOQUES_DIR.mkdir(parents=True)
        
        # Mockear proceso
        proceso_mock = {
            "id": "test-proceso",
            "nombre": "Proceso de prueba",
            "familia": "inventario",
            "actualizado": "2026-10-21",
            "capas": [
                {
                    "id": "capa-1",
                    "numero": 1,
                    "nombre": "Configuración",
                    "controles": [
                        {
                            "id": "control-test",
                            "nombre": "Control de prueba",
                            "explicacion": "Explicación del control de prueba",
                            "invariante": "Invariante de prueba",
                            "sps": [
                                {
                                    "nombre": "SPQ_TEST",
                                    "metodo": "METODO_TEST",
                                    "rol": "Valida el control"
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        
        with patch('capacitacion_bloques.cargar_proceso') as mock_cargar:
            mock_cargar.return_value = proceso_mock
            
            resultado = bloques.generar_bloque_desde_control(
                "test-proceso",
                "control-test"
            )
            
            assert resultado.get("ok"), f"Debe generar bloque: {resultado.get('mensaje')}"
            assert "bloque_id" in resultado
            
            bloque_id = resultado["bloque_id"]
            print(f"  ✓ Bloque generado: {bloque_id}")
            
            # Verificar que se creó el directorio
            bloque_dir = bloques.BLOQUES_DIR / bloque_id
            assert bloque_dir.exists(), "Debe crear directorio del bloque"
            
            # Verificar bloque.json
            bloque_json = bloque_dir / "bloque.json"
            assert bloque_json.exists(), "Debe crear bloque.json"
            
            with open(bloque_json, encoding="utf-8") as f:
                meta = json.load(f)
            
            assert meta["id"] == bloque_id
            assert meta["titulo"] == "Control de prueba"
            assert "inventario" in meta["temas"]
            assert "test-proceso" in meta["procesos"]
            
            # Verificar contenido.md
            contenido_path = bloque_dir / "contenido.md"
            assert contenido_path.exists(), "Debe crear contenido.md"
            
            contenido = contenido_path.read_text(encoding="utf-8")
            assert "Control de prueba" in contenido
            assert "Explicación del control" in contenido
            
            print("  ✓ Archivos del bloque creados correctamente")
    
    print("✅ Test generar bloque: OK\n")


def test_resolver_dependencias():
    """Test: Resolver dependencias entre bloques."""
    print("Test 4: Resolver dependencias...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        bloques.BLOQUES_DIR = Path(tmpdir) / "bloques"
        bloques.BLOQUES_DIR.mkdir(parents=True)
        
        # Crear bloques mock
        bloque_a = {
            "id": "bloque-a",
            "titulo": "Bloque A",
            "prerrequisitos": []
        }
        
        bloque_b = {
            "id": "bloque-b",
            "titulo": "Bloque B",
            "prerrequisitos": ["bloque-a"]
        }
        
        bloque_c = {
            "id": "bloque-c",
            "titulo": "Bloque C",
            "prerrequisitos": ["bloque-b"]
        }
        
        for bloque in [bloque_a, bloque_b, bloque_c]:
            dir_bloque = bloques.BLOQUES_DIR / bloque["id"]
            dir_bloque.mkdir(parents=True)
            with open(dir_bloque / "bloque.json", "w", encoding="utf-8") as f:
                json.dump(bloque, f, ensure_ascii=False, indent=2)
        
        # Resolver solo C (debe incluir B y A)
        resultado = bloques.resolver_dependencias(["bloque-c"])
        
        assert resultado.get("ok"), f"Debe resolver: {resultado.get('error')}"
        assert resultado["orden"] == ["bloque-a", "bloque-b", "bloque-c"]
        assert resultado["agregados"] == ["bloque-a", "bloque-b"]
        
        print("  ✓ Dependencias resueltas correctamente")
        
        # Resolver B y C (debe incluir A)
        resultado = bloques.resolver_dependencias(["bloque-b", "bloque-c"])
        
        assert resultado.get("ok")
        assert resultado["orden"] == ["bloque-a", "bloque-b", "bloque-c"]
        assert resultado["agregados"] == ["bloque-a"]
        
        print("  ✓ Múltiples bloques resueltos correctamente")
    
    print("✅ Test resolver dependencias: OK\n")


def test_ensamblar_documento():
    """Test: Ensamblar documento desde bloques."""
    print("Test 5: Ensamblar documento...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        bloques.BLOQUES_DIR = Path(tmpdir) / "bloques"
        bloques.BLOQUES_DIR.mkdir(parents=True)
        
        ensamblar.BLOQUES_DIR = bloques.BLOQUES_DIR
        ensamblar.SALIDA_DIR = Path(tmpdir) / "salida"
        ensamblar.SALIDA_DIR.mkdir(parents=True)
        
        # Crear bloque mock
        bloque = {
            "id": "test-bloque",
            "titulo": "Bloque de prueba",
            "temas": ["inventario"],
            "prerrequisitos": [],
            "imagenes": []
        }
        
        dir_bloque = bloques.BLOQUES_DIR / "test-bloque"
        dir_bloque.mkdir(parents=True)
        
        with open(dir_bloque / "bloque.json", "w", encoding="utf-8") as f:
            json.dump(bloque, f, ensure_ascii=False, indent=2)
        
        contenido = """# Bloque de prueba

## Introducción

Este es un bloque de prueba.

## Pasos

1. Paso uno
2. Paso dos
3. Paso tres
"""
        
        (dir_bloque / "contenido.md").write_text(contenido, encoding="utf-8")
        
        # Mockear temas
        tema = {
            "id": "inventario",
            "nombre": "Inventario",
            "descripcion": "Prueba"
        }
        
        with patch('capacitacion_bloques.cargar_temas') as mock_temas:
            mock_temas.return_value = {"temas": [tema]}
            
            resultado = ensamblar.ensamblar_documento(
                tema_id="inventario",
                bloques_ids=["test-bloque"],
                titulo="Documento de prueba",
                formato="html"
            )
            
            assert resultado.get("ok"), f"Debe ensamblar: {resultado.get('error')}"
            assert "archivo_html" in resultado
            
            # archivo_html es una URL relativa, pero en el test está en SALIDA_DIR temporal
            archivo_html_url = resultado["archivo_html"]
            nombre_archivo = archivo_html_url.split('/')[-1]
            # El archivo está en el SALIDA_DIR temporal del test
            archivo_html = ensamblar.SALIDA_DIR / nombre_archivo
            assert archivo_html.exists(), f"Debe crear archivo HTML: {archivo_html}"
            
            html = archivo_html.read_text(encoding="utf-8")
            assert "Documento de prueba" in html
            assert "Bloque de prueba" in html
            assert "Paso uno" in html
            
            print(f"  ✓ Documento generado: {archivo_html.name}")
    
    print("✅ Test ensamblar documento: OK\n")


def test_markdown_a_html():
    """Test: Conversión Markdown a HTML."""
    print("Test 6: Conversión Markdown a HTML...")
    
    md = """# Título principal

## Subtítulo

Este es un párrafo con **negrita** y *cursiva* y `código inline`.

> Esto es una cita

- Item 1
- Item 2
- Item 3

```
código en bloque
```
"""
    
    html = ensamblar._markdown_simple_a_html(md)
    
    assert "<h1>" in html
    assert "<h2>" in html
    assert "<strong>" in html
    assert "<em>" in html
    assert "<code>" in html
    assert "<blockquote>" in html
    assert "<ul>" in html
    assert "<li>" in html
    assert "<pre>" in html
    
    print("  ✓ Conversión Markdown → HTML correcta")
    print("✅ Test Markdown: OK\n")


def test_piloto_genera_bloques():
    """Test: El piloto debe generar bloques reales (no 0)."""
    print("Test 7: Piloto genera bloques...")
    
    import capacitacion_piloto
    
    # Ejecutar generación del piloto
    resultados = capacitacion_piloto.generar_piloto()
    
    # Contar bloques generados
    bloques_ok = sum(1 for r in resultados if r.get("ok"))
    
    print(f"  Bloques generados: {bloques_ok}")
    print(f"  Bloques omitidos: {len(resultados) - bloques_ok}")
    
    # El test FALLA si se generaron 0 bloques
    assert bloques_ok > 0, f"El piloto generó 0 bloques (total: {len(resultados)}). Revisar IDs de controles/pasos en la KB."
    
    print("  ✓ Piloto genera bloques correctamente")
    print("✅ Test piloto: OK\n")


if __name__ == "__main__":
    try:
        test_cargar_temas()
        test_slug()
        test_generar_bloque_mock()
        test_resolver_dependencias()
        test_ensamblar_documento()
        test_markdown_a_html()
        test_piloto_genera_bloques()
        
        print("\n" + "=" * 60)
        print("✅ Todos los tests de capacitación pasaron correctamente")
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
