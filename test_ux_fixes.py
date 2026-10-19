#!/usr/bin/env python3
"""Tests para verificar las correcciones de UX (waiting notice delay)."""
import asyncio
import json
import os
import sys
import tempfile
import time
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

# Añadir scripts al path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import cursor_bot as cb


class FakeRun:
    """Mock de un run de cursor-sdk."""
    def __init__(self, run_id, status="running"):
        self.id = run_id
        self.status = status


async def test_esperar_turno_sin_runs():
    """Si no hay runs vivos, debe retornar True sin esperar."""
    print("Test 1: Sin runs vivos...")
    
    client = AsyncMock()
    client.list_runs = AsyncMock(return_value=MagicMock(items=[]))
    
    with tempfile.TemporaryDirectory() as tmpdir:
        id_caso = "test-caso-1"
        cb.ACTIVO_DIR = tmpdir
        
        t0 = time.time()
        libre = await cb._esperar_turno_previo(client, "agent-123", id_caso)
        elapsed = time.time() - t0
        
        assert libre is True, "Debe retornar True"
        assert elapsed < 1, f"No debe esperar si no hay runs (tardó {elapsed:.1f}s)"
        
        # No debe haber creado aviso en el chat
        chat_path = os.path.join(tmpdir, id_caso, "chat.json")
        if os.path.exists(chat_path):
            with open(chat_path) as f:
                chat = json.load(f)
            mensajes_sistema = [m for m in chat.get("mensajes", []) if m.get("autor") == "sistema"]
            assert len(mensajes_sistema) == 0, "No debe postear aviso si no hay espera"
        
        print("✓ Test sin runs vivos: OK")


async def test_esperar_turno_rapido():
    """Si el run se cancela rápido (<15s), no debe postear el aviso."""
    print("\nTest 2: Espera rápida (run huérfano)...")
    
    # Simular un run que termina enseguida
    client = AsyncMock()
    fake_run = FakeRun("run-456")
    client.list_runs = AsyncMock(return_value=MagicMock(items=[fake_run]))
    
    # wait_live_run retorna enseguida (run huérfano)
    async def wait_rapido(run_id):
        await asyncio.sleep(0.1)
        return None
    
    client.wait_live_run = AsyncMock(side_effect=wait_rapido)
    client.cancel_run = AsyncMock()
    
    with tempfile.TemporaryDirectory() as tmpdir:
        id_caso = "test-caso-2"
        cb.ACTIVO_DIR = tmpdir
        
        # Primera llamada retorna el run, segunda retorna vacío (ya cancelado)
        call_count = [0]
        async def list_runs_mock(agent_id, limit=8):
            call_count[0] += 1
            if call_count[0] == 1:
                return MagicMock(items=[fake_run])
            else:
                return MagicMock(items=[])
        
        client.list_runs = AsyncMock(side_effect=list_runs_mock)
        
        t0 = time.time()
        libre = await cb._esperar_turno_previo(client, "agent-123", id_caso)
        elapsed = time.time() - t0
        
        assert libre is True, "Debe quedar libre después de cancelar"
        assert elapsed < 15, f"La espera debe ser <15s (tardó {elapsed:.1f}s)"
        
        # No debe haber posteado aviso
        chat_path = os.path.join(tmpdir, id_caso, "chat.json")
        if os.path.exists(chat_path):
            with open(chat_path) as f:
                chat = json.load(f)
            mensajes_sistema = [m for m in chat.get("mensajes", []) if m.get("autor") == "sistema"]
            assert len(mensajes_sistema) == 0, "No debe postear aviso si la espera fue <15s"
        
        print("✓ Test espera rápida: OK")


async def test_esperar_turno_lento():
    """Si el run tarda >15s, debe postear el aviso."""
    print("\nTest 3: Espera lenta (run real)...")
    
    client = AsyncMock()
    fake_run = FakeRun("run-789")
    client.list_runs = AsyncMock(return_value=MagicMock(items=[fake_run]))
    
    # wait_live_run espera 20 segundos (run real trabajando)
    async def wait_lento(run_id):
        await asyncio.sleep(20)
        return None
    
    client.wait_live_run = AsyncMock(side_effect=wait_lento)
    
    # Mock append_chat to capture calls
    chat_calls = []
    original_append_chat = cb.append_chat
    def mock_append_chat(id_caso, autor, texto):
        chat_calls.append({"id_caso": id_caso, "autor": autor, "texto": texto})
    
    cb.append_chat = mock_append_chat
    
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-caso-3"
            cb.ACTIVO_DIR = tmpdir
            
            # Crear directorio del caso
            caso_dir = os.path.join(tmpdir, id_caso)
            os.makedirs(caso_dir, exist_ok=True)
            
            # Segunda llamada retorna vacío (ya terminó)
            call_count = [0]
            async def list_runs_mock(agent_id, limit=8):
                call_count[0] += 1
                if call_count[0] == 1:
                    return MagicMock(items=[fake_run])
                else:
                    return MagicMock(items=[])
            
            client.list_runs = AsyncMock(side_effect=list_runs_mock)
            
            t0 = time.time()
            libre = await cb._esperar_turno_previo(client, "agent-123", id_caso)
            elapsed = time.time() - t0
            
            assert libre is True, "Debe quedar libre después de esperar"
            assert elapsed >= 15, f"La espera debe ser >=15s para que se postee aviso (tardó {elapsed:.1f}s)"
            
            # Debe haber posteado el aviso en chat
            mensajes_sistema = [c for c in chat_calls if c["autor"] == "sistema"]
            assert len(mensajes_sistema) == 1, f"Debe haber 1 mensaje de sistema, tiene {len(mensajes_sistema)}: {chat_calls}"
            assert "turno anterior" in mensajes_sistema[0]["texto"].lower(), "El mensaje debe mencionar 'turno anterior'"
            
            print("✓ Test espera lenta: OK")
    finally:
        cb.append_chat = original_append_chat


async def main():
    """Ejecutar todos los tests."""
    try:
        await test_esperar_turno_sin_runs()
        await test_esperar_turno_rapido()
        await test_esperar_turno_lento()
        print("\n✅ Todos los tests de UX pasaron correctamente")
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
    sys.exit(asyncio.run(main()))
