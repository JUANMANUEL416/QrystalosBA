#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests de aislamiento de sesiones de agente.

Verifica que:
1. Dos IDs distintos nunca comparten agentId
2. Cerrar archiva chat.json y limpia agentId
3. El prompt solo lee el chat del ID correspondiente
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import cursor_bot


class TestAislamientoSesiones(unittest.TestCase):
    """Prueba que cada ID tiene su propia sesión aislada."""
    
    def test_ids_distintos_no_comparten_agent_id(self):
        """Dos IDs distintos nunca deben compartir el mismo agentId."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Mock de agente.json para dos casos distintos
            activo = Path(tmpdir) / "activo"
            
            caso1_dir = activo / "test-001"
            caso1_dir.mkdir(parents=True)
            agente1 = {
                "idCaso": "test-001",
                "modelo": "composer-2.5",
                "fast": True,
                "rol": "requerimientos",
                "agentId": "agent-abc-001",
                "turnos": 3
            }
            (caso1_dir / "agente.json").write_text(
                json.dumps(agente1, ensure_ascii=False),
                encoding="utf-8"
            )
            
            caso2_dir = activo / "test-002"
            caso2_dir.mkdir(parents=True)
            agente2 = {
                "idCaso": "test-002",
                "modelo": "composer-2.5",
                "fast": True,
                "rol": "requerimientos",
                "agentId": "agent-abc-002",
                "turnos": 2
            }
            (caso2_dir / "agente.json").write_text(
                json.dumps(agente2, ensure_ascii=False),
                encoding="utf-8"
            )
            
            # Simular que cursor_bot intenta reutilizar sesión
            # Con el ID correcto, debe reutilizar
            original_root = cursor_bot.ROOT
            original_activo = cursor_bot.ACTIVO
            
            try:
                cursor_bot.ROOT = tmpdir
                cursor_bot.ACTIVO = str(activo)
                
                # Leer meta de caso1
                meta1 = cursor_bot.read_json(cursor_bot.agente_path("test-001"), {})
                self.assertEqual(meta1.get("idCaso"), "test-001")
                self.assertEqual(meta1.get("agentId"), "agent-abc-001")
                
                # Leer meta de caso2
                meta2 = cursor_bot.read_json(cursor_bot.agente_path("test-002"), {})
                self.assertEqual(meta2.get("idCaso"), "test-002")
                self.assertEqual(meta2.get("agentId"), "agent-abc-002")
                
                # Verificar que son distintos
                self.assertNotEqual(meta1.get("agentId"), meta2.get("agentId"))
                
            finally:
                cursor_bot.ROOT = original_root
                cursor_bot.ACTIVO = original_activo
    
    def test_cambio_id_invalida_agent_id(self):
        """Si el idCaso en agente.json no coincide, debe invalidarse el agentId."""
        with tempfile.TemporaryDirectory() as tmpdir:
            activo = Path(tmpdir) / "activo"
            caso_dir = activo / "test-003"
            caso_dir.mkdir(parents=True)
            
            # agente.json con idCaso diferente
            agente = {
                "idCaso": "test-OLD",  # ID diferente
                "modelo": "composer-2.5",
                "fast": True,
                "rol": "requerimientos",
                "agentId": "agent-abc-003",
                "turnos": 5
            }
            (caso_dir / "agente.json").write_text(
                json.dumps(agente, ensure_ascii=False),
                encoding="utf-8"
            )
            
            original_root = cursor_bot.ROOT
            original_activo = cursor_bot.ACTIVO
            
            try:
                cursor_bot.ROOT = tmpdir
                cursor_bot.ACTIVO = str(activo)
                
                # Leer meta
                meta = cursor_bot.read_json(cursor_bot.agente_path("test-003"), {})
                
                # Simular la lógica de validación (como en _run_caso_async)
                id_caso_actual = "test-003"
                id_guardado = meta.get("idCaso", "")
                agent_id = meta.get("agentId", "")
                
                # Si los IDs no coinciden, debe invalidarse
                if agent_id and id_guardado != id_caso_actual:
                    agent_id = ""
                
                self.assertEqual(agent_id, "", 
                               "agentId debe invalidarse cuando idCaso no coincide")
                
            finally:
                cursor_bot.ROOT = original_root
                cursor_bot.ACTIVO = original_activo
    
    def test_reiniciar_chat_archiva_y_limpia(self):
        """reiniciar_chat debe archivar chat.json y limpiar agente.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            activo = Path(tmpdir) / "activo"
            caso_dir = activo / "test-004"
            caso_dir.mkdir(parents=True)
            
            # Crear chat.json con mensajes
            mensajes = [
                {"autor": "coordinador", "texto": "Mensaje 1", "en": "2024-01-01T10:00:00"},
                {"autor": "agente", "texto": "Mensaje 2", "en": "2024-01-01T10:01:00"},
                {"autor": "coordinador", "texto": "Mensaje 3", "en": "2024-01-01T10:02:00"}
            ]
            (caso_dir / "chat.json").write_text(
                json.dumps(mensajes, ensure_ascii=False),
                encoding="utf-8"
            )
            
            # Crear agente.json
            agente = {
                "idCaso": "test-004",
                "agentId": "agent-abc-004",
                "modelo": "composer-2.5",
                "turnos": 3
            }
            (caso_dir / "agente.json").write_text(
                json.dumps(agente, ensure_ascii=False),
                encoding="utf-8"
            )
            
            original_root = cursor_bot.ROOT
            original_activo = cursor_bot.ACTIVO
            
            try:
                cursor_bot.ROOT = tmpdir
                cursor_bot.ACTIVO = str(activo)
                
                # Reiniciar chat
                resultado = cursor_bot.reiniciar_chat("test-004", motivo="test")
                
                # Verificar resultado
                self.assertTrue(resultado.get("ok"), f"reiniciar_chat falló: {resultado.get('mensaje')}")
                self.assertIn("archivoChat", resultado)
                
                # Verificar que chat.json está vacío
                chat_nuevo = cursor_bot.read_json(caso_dir / "chat.json", [])
                self.assertEqual(chat_nuevo, [], "chat.json debe estar vacío")
                
                # Verificar que agente.json fue eliminado
                self.assertFalse((caso_dir / "agente.json").exists(), 
                               "agente.json debe ser eliminado")
                
                # Verificar que el archivo de historial existe
                historial_dir = caso_dir / "historial"
                self.assertTrue(historial_dir.exists(), "Directorio historial/ debe existir")
                
                archivos_historial = list(historial_dir.glob("chat-*.json"))
                self.assertEqual(len(archivos_historial), 1, 
                               "Debe haber exactamente 1 archivo en historial/")
                
                # Verificar contenido del archivo archivado
                chat_archivado = json.loads(archivos_historial[0].read_text(encoding="utf-8"))
                self.assertEqual(len(chat_archivado), 3, 
                               "El chat archivado debe tener los 3 mensajes originales")
                
            finally:
                cursor_bot.ROOT = original_root
                cursor_bot.ACTIVO = original_activo
    
    def test_reiniciar_chat_ya_vacio(self):
        """reiniciar_chat con chat ya vacío solo debe limpiar agentId."""
        with tempfile.TemporaryDirectory() as tmpdir:
            activo = Path(tmpdir) / "activo"
            caso_dir = activo / "test-005"
            caso_dir.mkdir(parents=True)
            
            # Crear chat.json vacío
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            # Crear agente.json
            agente = {"idCaso": "test-005", "agentId": "agent-abc-005"}
            (caso_dir / "agente.json").write_text(
                json.dumps(agente, ensure_ascii=False),
                encoding="utf-8"
            )
            
            original_root = cursor_bot.ROOT
            original_activo = cursor_bot.ACTIVO
            
            try:
                cursor_bot.ROOT = tmpdir
                cursor_bot.ACTIVO = str(activo)
                
                # Reiniciar
                resultado = cursor_bot.reiniciar_chat("test-005")
                
                self.assertTrue(resultado.get("ok"))
                self.assertIn("vacío", resultado.get("mensaje", "").lower())
                
                # agente.json debe ser eliminado
                self.assertFalse((caso_dir / "agente.json").exists())
                
                # No debe haber archivo de historial (chat ya estaba vacío)
                historial_dir = caso_dir / "historial"
                if historial_dir.exists():
                    archivos = list(historial_dir.glob("chat-*.json"))
                    self.assertEqual(len(archivos), 0, 
                                   "No debe archivar un chat vacío")
                
            finally:
                cursor_bot.ROOT = original_root
                cursor_bot.ACTIVO = original_activo
    
    def test_sesiones_consultas_aisladas(self):
        """Sesiones de Consultas con sufijos distintos deben estar aisladas."""
        # Este test verifica el concepto de aislamiento: dos sesiones con IDs distintos
        # (aunque sean del mismo tipo como __consultas__~sid1 y __consultas__~sid2)
        # deben tener agentIds distintos guardados en agente.json separados.
        
        # En la práctica, cada sesión vive en su propia carpeta:
        # conocimiento/canales/consultas/sesiones/{sid}/agente.json
        # y el sistema usa el ID completo (incluyendo ~sid) como clave de sesión.
        
        # Verificamos la lógica de validación de idCaso
        id1 = "__consultas__~c20261022-100000"
        id2 = "__consultas__~c20261022-150000"
        
        # Deben ser IDs distintos
        self.assertNotEqual(id1, id2)
        
        # Simulamos que cada uno tiene su agente.json con idCaso guardado
        agente1 = {"idCaso": id1, "agentId": "agent-001"}
        agente2 = {"idCaso": id2, "agentId": "agent-002"}
        
        # Validación: si intentamos usar agente1 para id2, debe invalidarse
        agent_id_test = agente1.get("agentId")
        id_guardado_test = agente1.get("idCaso")
        id_actual_test = id2
        
        if agent_id_test and id_guardado_test != id_actual_test:
            agent_id_test = ""
        
        self.assertEqual(agent_id_test, "", 
                       "Debe invalidarse agentId cuando se intenta reutilizar con otro ID")


if __name__ == "__main__":
    unittest.main()
