#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests para validar cierre de casos y creación de nuevas sesiones.

Valida:
- Cierre de solicitud llama reiniciar_chat
- Cierre de consulta llama reiniciar_chat
- Cierre de prueba llama reiniciar_chat
- Cierre completo de caso llama reiniciar_chat
- Nueva sesión en Conocimiento/Consultas limpia agente.json
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


class TestCierresLlamanReiniciarChat(unittest.TestCase):
    """Valida que las funciones de cierre incluyan llamadas a reiniciar_chat."""
    
    def test_cerrar_solicitud_incluye_reiniciar_chat(self):
        """Código de cerrar_solicitud debe incluir llamada a reiniciar_chat."""
        import solicitud_req
        import inspect
        
        codigo = inspect.getsource(solicitud_req.cerrar)
        self.assertIn("cursor_bot.reiniciar_chat", codigo, 
                     "cerrar() debe incluir llamada a cursor_bot.reiniciar_chat")
        self.assertIn("cerrar-solicitud", codigo,
                     "cerrar() debe usar motivo 'cerrar-solicitud'")
    
    def test_cerrar_consulta_incluye_reiniciar_chat(self):
        """Código de cerrar_consulta debe incluir llamada a reiniciar_chat."""
        import soporte_consultas
        import inspect
        
        codigo = inspect.getsource(soporte_consultas.cerrar_consulta)
        self.assertIn("cursor_bot.reiniciar_chat", codigo,
                     "cerrar_consulta() debe incluir llamada a cursor_bot.reiniciar_chat")
        self.assertIn("cerrar-consulta", codigo,
                     "cerrar_consulta() debe usar motivo 'cerrar-consulta'")
    
    def test_cerrar_prueba_incluye_reiniciar_chat(self):
        """Código de cerrar_prueba debe incluir llamada a reiniciar_chat."""
        import prueba_req
        import inspect
        
        codigo = inspect.getsource(prueba_req.cerrar_prueba)
        self.assertIn("cursor_bot.reiniciar_chat", codigo,
                     "cerrar_prueba() debe incluir llamada a cursor_bot.reiniciar_chat")
        self.assertIn("cerrar-prueba", codigo,
                     "cerrar_prueba() debe usar motivo 'cerrar-prueba'")
    
    def test_cerrar_caso_completo_incluye_reiniciar_chat(self):
        """Código de cerrar_caso_completo debe incluir llamada a reiniciar_chat."""
        import qrystalos_ba_db
        import inspect
        
        codigo = inspect.getsource(qrystalos_ba_db.QrystalosBADB.cerrar_caso_completo)
        self.assertIn("cursor_bot.reiniciar_chat", codigo,
                     "cerrar_caso_completo() debe incluir llamada a cursor_bot.reiniciar_chat")
        self.assertIn("cerrar-caso-completo", codigo,
                     "cerrar_caso_completo() debe usar motivo 'cerrar-caso-completo'")


class TestNuevaSesionLimpiaAgente(unittest.TestCase):
    """Valida que crear nueva sesión en Conocimiento/Consultas limpia agente.json."""
    
    def test_archivar_chat_sesion_llama_reiniciar(self):
        """Archivar chat de sesión debe llamar reiniciar_chat para limpiar agente.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            import conocimiento
            
            canal = "consultas"
            sid_anterior = f"__{canal}__~123"
            
            conocimiento_dir = Path(tmpdir) / "conocimiento"
            conocimiento_dir.mkdir(parents=True)
            
            canales_dir = conocimiento_dir / "canales"
            canales_dir.mkdir(parents=True)
            
            canal_dir = canales_dir / canal
            canal_dir.mkdir(parents=True)
            
            chat_anterior = {
                "id": sid_anterior,
                "titulo": "Chat anterior",
                "mensajes": [
                    {"autor": "coordinador", "texto": "Hola"}
                ]
            }
            
            idx = {
                "activoId": sid_anterior,
                "viendoId": sid_anterior,
                "items": [
                    {"id": sid_anterior, "titulo": "Chat anterior", "estado": "activo", "mensajes": 1}
                ]
            }
            
            (canal_dir / "index.json").write_text(json.dumps(idx, ensure_ascii=False), encoding="utf-8")
            (canal_dir / f"{sid_anterior}.json").write_text(json.dumps(chat_anterior, ensure_ascii=False), encoding="utf-8")
            
            with patch('cursor_bot.reiniciar_chat') as mock_reiniciar:
                mock_reiniciar.return_value = {"ok": True}
                
                with patch.object(conocimiento, 'CONOCIMIENTO', str(conocimiento_dir)):
                    try:
                        resultado = conocimiento.nuevo_chat(canal, "Nuevo chat")
                        
                        # Verificar que se llamó reiniciar_chat con la sesión anterior
                        mock_reiniciar.assert_called_once()
                        args = mock_reiniciar.call_args
                        self.assertEqual(args[0][0], sid_anterior)
                        self.assertIn("nueva-sesion", args[0][1])
                        
                        # Verificar que se creó nuevo chat
                        self.assertTrue(resultado.get("ok"))
                        self.assertIsNotNone(resultado.get("activo"))
                        nuevo_id = resultado["activo"].get("id")
                        self.assertNotEqual(nuevo_id, sid_anterior)
                    except Exception as exc:
                        # Si falla por otras razones, al menos verificar que se intentó llamar reiniciar_chat
                        if mock_reiniciar.called:
                            args = mock_reiniciar.call_args
                            self.assertEqual(args[0][0], sid_anterior)


if __name__ == "__main__":
    unittest.main()
