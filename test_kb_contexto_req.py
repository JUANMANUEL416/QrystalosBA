#!/usr/bin/env python3
"""Tests para la preselección de contexto KB en analizar-req."""
import json
import sys
from pathlib import Path

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import kb_contexto_req


def test_extraer_terminos():
    """Verifica extracción de términos clave del REQ."""
    print("Test 1: Extracción de términos...")
    
    req = """
    En el módulo de CAJA, cuando el cajero intenta abrir sesión, 
    aparece un error. El procedimiento SPQ_CONF_CAJA debe validar 
    que el equipo tenga UBEQ.ESCAJA=1 antes de permitir el ingreso 
    a /admin/caja.
    """
    
    terminos = kb_contexto_req._extraer_terminos_req(req)
    
    assert "CAJA" in terminos, "Debe extraer siglas (CAJA)"
    assert "SPQ_CONF_CAJA" in terminos, "Debe extraer nombres de SP"
    assert "UBEQ" in terminos, "Debe extraer nombres de tabla"
    assert "/admin/caja" in terminos, "Debe extraer rutas de pantalla"
    assert "cajero" in terminos, "Debe extraer términos de negocio"
    
    print(f"  Términos extraídos: {len(terminos)}")
    print(f"  {', '.join(sorted(terminos)[:10])}")
    print("✓ Test extracción de términos: OK")


def test_preseleccion_con_proceso():
    """Verifica preselección cuando ya se conoce el proceso."""
    print("\nTest 2: Preselección con proceso conocido (caja)...")
    
    req = """
    El cajero no puede abrir sesión. Aparece error de configuración
    cuando intenta ingresar a la pantalla de Caja.
    """
    
    contexto = kb_contexto_req.preseleccionar_contexto(req, "caja")
    
    assert contexto.get("procesos"), "Debe devolver procesos"
    assert len(contexto["procesos"]) >= 1, "Debe incluir al menos el proceso solicitado"
    
    proc = contexto["procesos"][0]
    assert proc["id"] == "caja", "El primer proceso debe ser caja"
    assert "nombre" in proc, "Debe incluir nombre del proceso"
    assert "sps" in proc, "Debe incluir SPs del proceso"
    
    if proc.get("sps"):
        print(f"  SPs principales: {', '.join(sp['nombre'] for sp in proc['sps'][:3])}")
    
    assert contexto.get("rutas_abrir"), "Debe incluir rutas para abrir"
    print(f"  Rutas para abrir: {len(contexto['rutas_abrir'])}")
    
    print("✓ Test preselección con proceso: OK")


def test_preseleccion_inferir_proceso():
    """Verifica inferencia de proceso desde el texto del REQ."""
    print("\nTest 3: Inferencia de proceso desde términos...")
    
    req = """
    Al facturar un servicio de salud, el sistema no genera el RIPS JSON
    correctamente. El archivo no incluye el diagnóstico principal.
    """
    
    contexto = kb_contexto_req.preseleccionar_contexto(req, "")
    
    assert contexto.get("procesos"), "Debe inferir al menos un proceso"
    
    # Debe priorizar facturacion o rips-json
    proc_ids = [p["id"] for p in contexto["procesos"]]
    print(f"  Procesos inferidos: {', '.join(proc_ids)}")
    
    assert any("facturacion" in pid or "rips" in pid for pid in proc_ids), \
        "Debe inferir proceso relacionado con facturación/RIPS"
    
    print("✓ Test inferencia de proceso: OK")


def test_formato_prompt():
    """Verifica que el formato del prompt sea válido."""
    print("\nTest 4: Formato del prompt...")
    
    req = "Error en caja al abrir sesión"
    contexto = kb_contexto_req.preseleccionar_contexto(req, "caja")
    
    prompt_txt = kb_contexto_req.formato_prompt(contexto)
    
    assert "CONTEXTO KB PRESELECCIONADO" in prompt_txt, "Debe incluir encabezado"
    assert "Proceso:" in prompt_txt, "Debe listar procesos"
    assert "PRESUPUESTO DE HERRAMIENTAS" in prompt_txt, "Debe incluir presupuesto"
    assert "~15 tool calls" in prompt_txt, "Debe especificar límite de tool calls"
    
    # Verificar que no sea excesivamente largo
    assert len(prompt_txt) < 15000, f"Prompt muy largo: {len(prompt_txt)} chars"
    
    print(f"  Longitud del prompt: {len(prompt_txt)} caracteres")
    print("✓ Test formato prompt: OK")


def test_limite_tamano():
    """Verifica que el contexto respete el límite de tamaño."""
    print("\nTest 5: Límite de tamaño del contexto...")
    
    # Crear un REQ que podría coincidir con muchos procesos
    req = "Error en el sistema contable financiero"
    
    contexto = kb_contexto_req.preseleccionar_contexto(req, "")
    
    # El contexto JSON no debe ser excesivamente grande
    contexto_json = json.dumps(contexto, ensure_ascii=False)
    assert len(contexto_json) < kb_contexto_req.MAX_CHARS_CONTEXTO * 1.5, \
        f"Contexto muy grande: {len(contexto_json)} chars"
    
    # Si se truncó, debe indicarlo
    if contexto.get("advertencia"):
        print(f"  ⚠ {contexto['advertencia']}")
    
    print(f"  Tamaño del contexto: {len(contexto_json)} caracteres")
    print("✓ Test límite de tamaño: OK")


def test_resumen_sps():
    """Verifica que el resumen de SPs sea compacto."""
    print("\nTest 6: Resumen de SPs...")
    
    sps = kb_contexto_req._resumir_sps("caja", limite=5)
    
    assert isinstance(sps, list), "Debe devolver una lista"
    
    if sps:
        assert len(sps) <= 5, "Debe respetar el límite"
        
        for sp in sps:
            assert "nombre" in sp, "Debe incluir nombre del SP"
            assert "estado" in sp, "Debe incluir estado"
            assert "metodos" in sp, "Debe incluir métodos"
            
            # Los métodos deben estar resumidos (no completos)
            for metodo in sp.get("metodos") or []:
                if metodo.get("hace"):
                    assert len(metodo["hace"]) <= 120, "Debe truncar 'hace'"
        
        print(f"  SPs resumidos: {len(sps)}")
        print(f"  Primer SP: {sps[0]['nombre']} con {len(sps[0]['metodos'])} métodos")
    else:
        print("  (No hay SPs en el proceso de prueba)")
    
    print("✓ Test resumen de SPs: OK")


def test_json_output():
    """Verifica salida JSON del CLI."""
    print("\nTest 7: Salida JSON del CLI...")
    
    import subprocess
    
    result = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "kb_contexto_req.py"),
            "--req", "Error en caja",
            "--proceso", "caja",
            "--json",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    
    assert result.returncode == 0, f"CLI falló: {result.stderr}"
    
    # Debe ser JSON válido
    contexto = json.loads(result.stdout)
    assert "procesos" in contexto, "JSON debe incluir 'procesos'"
    
    print("✓ Test salida JSON: OK")


def main():
    """Ejecutar todos los tests."""
    try:
        test_extraer_terminos()
        test_preseleccion_con_proceso()
        test_preseleccion_inferir_proceso()
        test_formato_prompt()
        test_limite_tamano()
        test_resumen_sps()
        test_json_output()
        
        print("\n✅ Todos los tests de kb_contexto_req pasaron correctamente")
        return 0
    except AssertionError as e:
        print(f"\n❌ Test falló: {e}")
        import traceback
        traceback.print_exc()
        return 1
    except Exception as e:
        print(f"\n❌ Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
