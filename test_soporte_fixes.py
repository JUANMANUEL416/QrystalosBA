#!/usr/bin/env python3
"""Tests para verificar las correcciones de soporte-consultas."""
import json
import os
import sys
import tempfile
import time
from datetime import datetime, timedelta
from pathlib import Path

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import soporte_consultas as sc


def test_normalizar_timestamps():
    """Test 4a: Normalizar timestamps y IDs del agente."""
    print("Test 1: Normalizar timestamps...")
    
    # Crear consulta temporal
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        meta = sc.crear_consulta(
            "Test timestamps",
            "Pregunta de prueba",
            "Test User"
        )
        sid = meta["id"]
        
        # Manipular directamente chat.json sin usar append_chat
        chat_path = sc.carpeta_consulta(sid) / "chat.json"
        chat = sc._read_json(chat_path, {"mensajes": []})
        
        ahora = datetime.now()
        futuro = ahora + timedelta(days=1)
        pasado_lejano = ahora - timedelta(days=10)
        
        # Mensaje con timestamp futuro
        chat["mensajes"].append({
            "id": "fut001",
            "autor": "agente",
            "texto": "Mensaje con timestamp futuro",
            "en": futuro.isoformat()
        })
        
        # Mensaje con timestamp muy antiguo
        chat["mensajes"].append({
            "id": "ant001",
            "autor": "agente",
            "texto": "Mensaje antiguo",
            "en": pasado_lejano.isoformat()
        })
        
        # Mensaje sin timestamp
        chat["mensajes"].append({
            "id": "sin001",
            "autor": "agente",
            "texto": "Sin timestamp"
        })
        
        # Mensaje sin ID
        chat["mensajes"].append({
            "autor": "agente",
            "texto": "Sin ID",
            "en": ahora.isoformat()
        })
        
        # Mensaje de usuario (no debe modificarse)
        chat["mensajes"].append({
            "id": "sop001",
            "autor": "soporte",
            "texto": "Mensaje de soporte",
            "en": futuro.isoformat()
        })
        
        sc._write_json(chat_path, chat)
        
        # Ejecutar normalización
        corregidos = sc.normalizar_timestamps_chat(sid)
        
        # Verificar
        chat_norm = sc.leer_chat(sid)
        mensajes = chat_norm["mensajes"]
        
        assert corregidos == 4, f"Esperaba 4 corregidos, obtuvo {corregidos}"
        
        # Verificar que los timestamps del agente están en rango válido
        for msg in mensajes:
            if msg["autor"] == "agente":
                ts = datetime.fromisoformat(msg["en"])
                delta = (ahora - ts).total_seconds()
                assert -60 < delta < 7*24*3600, f"Timestamp fuera de rango: {msg['en']} (delta={delta})"
                assert msg.get("id"), "Mensaje sin ID"
        
        # El mensaje de soporte mantiene su ID
        msgs_soporte = [m for m in mensajes if m["autor"] == "soporte"]
        msg_soporte = [m for m in msgs_soporte if m.get("texto") == "Mensaje de soporte"][0]
        assert msg_soporte["id"] == "sop001", f"ID de soporte no debe cambiar, obtuvo {msg_soporte['id']}"
        
        print("✓ Test normalizar timestamps: OK")


def test_limite_mediciones():
    """Test 5: Verificar límite de mediciones."""
    print("\nTest 2: Límite de mediciones...")
    
    import auditoria_procesos as aud
    
    # Resetear contadores
    aud._contadores_medicion.clear()
    
    consulta_id = "sc20261019-test"
    
    # Primer intento: OK
    try:
        aud._verificar_limite_medicion(consulta_id)
        print("  Intento 1: OK")
    except RuntimeError as e:
        assert False, f"Primer intento falló: {e}"
    
    # Segundo intento: OK
    try:
        aud._verificar_limite_medicion(consulta_id)
        print("  Intento 2: OK")
    except RuntimeError as e:
        assert False, f"Segundo intento falló: {e}"
    
    # Tercer intento: OK
    try:
        aud._verificar_limite_medicion(consulta_id)
        print("  Intento 3: OK")
    except RuntimeError as e:
        assert False, f"Tercer intento falló: {e}"
    
    # Cuarto intento: debe fallar
    try:
        aud._verificar_limite_medicion(consulta_id)
        assert False, "Cuarto intento debió fallar"
    except RuntimeError as e:
        assert "Límite de mediciones alcanzado: 3 intentos" in str(e)
        print(f"  Intento 4: Bloqueado correctamente - {e}")
    
    # Verificar límite de tiempo (simulado)
    aud._contadores_medicion.clear()
    aud._iniciar_medicion_consulta(consulta_id)
    # Simular que comenzó hace 6 minutos
    aud._contadores_medicion[consulta_id]["inicio"] = time.time() - 360
    
    try:
        aud._verificar_limite_medicion(consulta_id)
        assert False, "Límite de tiempo debió fallar"
    except RuntimeError as e:
        assert "Límite de tiempo de medición alcanzado" in str(e)
        print(f"  Tiempo límite: Bloqueado correctamente - {e}")
    
    # Operaciones no-consulta no deben tener límite
    aud._contadores_medicion.clear()
    for _ in range(10):
        aud._verificar_limite_medicion("operacion-normal")
    print("  Operaciones normales: Sin límite (correcto)")
    
    print("✓ Test límite mediciones: OK")


def test_autor_sistema():
    """Test 1: Verificar que autor 'sistema' se guarda correctamente."""
    print("\nTest 3: Autor sistema...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        meta = sc.crear_consulta(
            "Test sistema",
            "Pregunta de prueba",
            "Test User"
        )
        sid = meta["id"]
        
        # Añadir mensaje con prefijo [sistema]
        msg1 = sc.append_chat(sid, "soporte", "[sistema] Mensaje del sistema con prefijo")
        assert msg1["autor"] == "sistema", f"Esperaba 'sistema', obtuvo '{msg1['autor']}'"
        assert not msg1["texto"].startswith("[sistema]"), "El prefijo no debe quedar en el texto"
        
        # Añadir mensaje directo con autor sistema
        msg2 = sc.append_chat(sid, "sistema", "Mensaje directo del sistema")
        assert msg2["autor"] == "sistema", f"Esperaba 'sistema', obtuvo '{msg2['autor']}'"
        
        # Verificar que se guardaron correctamente
        chat = sc.leer_chat(sid)
        mensajes_sistema = [m for m in chat["mensajes"] if m["autor"] == "sistema"]
        assert len(mensajes_sistema) == 2, f"Esperaba 2 mensajes de sistema, obtuvo {len(mensajes_sistema)}"
        
        print("✓ Test autor sistema: OK")


def test_imagenes_primera_consulta():
    """Test 3: Verificar que las imágenes se pueden guardar al crear consulta."""
    print("\nTest 4: Imágenes en primera consulta...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        sc.DATA_DIR = Path(tmpdir)
        meta = sc.crear_consulta(
            "Test imágenes",
            "Pregunta con imágenes",
            "Test User"
        )
        sid = meta["id"]
        
        # Simular carga de imagen
        data_url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        
        img = sc.guardar_imagen(sid, data_url, "test.png")
        assert img["nombre"], "Imagen debe tener nombre"
        
        # Verificar que se guardó en meta
        meta_actualizado = sc.leer_meta(sid)
        assert len(meta_actualizado.get("imagenes", [])) == 1, "Debe haber 1 imagen"
        
        # Verificar que la instrucción la menciona
        sc.escribir_instruccion(sid)
        instr_path = sc.carpeta_consulta(sid) / "INSTRUCCION-AGENTE.md"
        instr = instr_path.read_text(encoding="utf-8")
        assert "test.png" in instr, "La instrucción debe mencionar la imagen"
        
        print("✓ Test imágenes primera consulta: OK")


if __name__ == "__main__":
    try:
        test_normalizar_timestamps()
        test_limite_mediciones()
        test_autor_sistema()
        test_imagenes_primera_consulta()
        print("\n✅ Todos los tests pasaron correctamente")
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
