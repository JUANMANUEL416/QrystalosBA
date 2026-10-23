#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests para validar que el análisis de requerimientos incluye el paso de reproducción del error.

Valida:
- El prompt de analizar-req incluye paso 0) REPRODUCIR EL REPORTE
- El prompt menciona DESAIX (PREVERSION siempre) para buscar el error
- El prompt incluye instrucciones de leer capturas en activo/{id}/imagenes/
- El prompt incluye ejemplo del caso real que falló (RIPS JSON nota crédito)
- El prompt requiere campo reproduccion en solicitud.json
- El prompt requiere contrastar diagnóstico del usuario
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import cursor_bot


class TestAnalisisReproducirError(unittest.TestCase):
    """Valida que el prompt de análisis incluye el paso de reproducción del error."""
    
    def test_prompt_incluye_reproducir_reporte(self):
        """El prompt de analizar-req debe incluir paso 0) REPRODUCIR EL REPORTE."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Setup caso
            id_caso = "test-reproducir-001"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            # Crear solicitud básica
            solicitud = {
                "contenido": {
                    "titulo": "Error RIPS",
                    "requerimiento": "Error en RIPS JSON",
                    "ubicacion": {
                        "procesoId": "facturacion",
                        "flujo": "rips",
                        "participan": []
                    }
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            # Mock caso_dir
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            # Verificar que el prompt incluye el paso de reproducción
            self.assertIn("0) REPRODUCIR EL REPORTE", prompt, 
                         "Debe incluir paso 0) REPRODUCIR EL REPORTE")
            self.assertIn("obligatorio antes de analizar", prompt.lower(),
                         "Debe marcar la reproducción como obligatoria")
    
    def test_prompt_menciona_desaix_preversion(self):
        """El prompt debe mencionar DESAIX (PREVERSION siempre) para buscar errores."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-002"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("DESAIX", prompt,
                         "Debe mencionar DESAIX para buscar el error")
            self.assertIn("PREVERSION siempre", prompt,
                         "Debe indicar usar PREVERSION siempre")
            self.assertIn("nunca un .sql guardado", prompt.lower(),
                         "Debe indicar no usar SQL guardado")
    
    def test_prompt_incluye_leer_capturas(self):
        """El prompt debe incluir instrucciones de leer capturas adjuntas."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-003"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("imagenes/", prompt,
                         "Debe mencionar la carpeta de imágenes")
            self.assertIn("Leer capturas adjuntas", prompt,
                         "Debe incluir instrucción de leer capturas")
            self.assertIn("interpretar", prompt.lower(),
                         "Debe pedir interpretar las capturas")
    
    def test_prompt_incluye_ejemplo_caso_real(self):
        """El prompt debe incluir el ejemplo del caso real que falló (RIPS JSON nota crédito)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-004"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("Caso real que FALLÓ", prompt,
                         "Debe incluir el caso real que falló")
            self.assertIn("RIPS JSON", prompt,
                         "Debe mencionar RIPS JSON")
            self.assertIn("FENC591", prompt,
                         "Debe incluir número de factura del ejemplo")
            self.assertIn("CNSFCT", prompt,
                         "Debe mencionar el parámetro CNSFCT del ejemplo")
            self.assertIn("CNSFNOT", prompt,
                         "Debe mencionar CNSFNOT del ejemplo")
    
    def test_prompt_requiere_campo_reproduccion(self):
        """El prompt debe requerir el campo reproduccion en solicitud.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-005"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("contenido.reproduccion", prompt,
                         "Debe requerir campo contenido.reproduccion")
            self.assertIn("errorLiteral", prompt,
                         "Debe incluir campo errorLiteral")
            self.assertIn("parametrosReales", prompt,
                         "Debe incluir campo parametrosReales")
            self.assertIn("ramaQueFalla", prompt,
                         "Debe incluir campo ramaQueFalla")
            self.assertIn("diagnosticoUsuario", prompt,
                         "Debe incluir campo diagnosticoUsuario")
            self.assertIn("diagnosticoReal", prompt,
                         "Debe incluir campo diagnosticoReal")
            self.assertIn("confirmaDiagnostico", prompt,
                         "Debe incluir campo confirmaDiagnostico")
    
    def test_prompt_requiere_contrastar_diagnostico(self):
        """El prompt debe requerir contrastar el diagnóstico del usuario."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-006"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("Contrastar con diagnóstico del usuario", prompt,
                         "Debe incluir instrucción de contrastar diagnóstico")
            self.assertIn("no aceptar", prompt.lower(),
                         "Debe indicar no aceptar sin evidencia")
            self.assertIn("evidencia", prompt.lower(),
                         "Debe requerir evidencia para el diagnóstico")
    
    def test_prompt_incluye_trazar_parametros(self):
        """El prompt debe incluir instrucciones de trazar parámetros reales."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-007"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("Trazar parámetros", prompt,
                         "Debe incluir instrucción de trazar parámetros")
            self.assertIn("valor real", prompt.lower(),
                         "Debe mencionar valor real de parámetros")
            self.assertIn("ventana de origen", prompt,
                         "Debe considerar ventana de origen para parámetros")
    
    def test_prompt_incluye_resumen_chat(self):
        """El prompt debe requerir resumen de reproducción en chat.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            id_caso = "test-reproducir-008"
            caso_dir = Path(tmpdir) / "activo" / id_caso
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "ubicacion": {"procesoId": "test"}
                }
            }
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            (caso_dir / "chat.json").write_text("[]", encoding="utf-8")
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                prompt, _ = cursor_bot._prompt_base(id_caso, "analizar-req")
            
            self.assertIn("chat.json", prompt,
                         "Debe mencionar chat.json")
            self.assertIn("Reproducción", prompt,
                         "Debe incluir sección Reproducción en chat")
            self.assertIn("PRIMERO reproducción", prompt,
                         "Debe indicar poner reproducción primero en chat")


class TestReglasAgenteRequerimientos(unittest.TestCase):
    """Valida que la regla del agente incluye el paso de reproducción."""
    
    def test_regla_incluye_reproducir_reporte(self):
        """La regla agente-requerimientos.mdc debe incluir REPRODUCIR EL REPORTE."""
        regla_path = ROOT / ".cursor" / "rules" / "agente-requerimientos.mdc"
        
        if not regla_path.exists():
            self.skipTest("Archivo agente-requerimientos.mdc no encontrado")
        
        contenido = regla_path.read_text(encoding="utf-8")
        
        self.assertIn("REPRODUCIR EL REPORTE", contenido,
                     "Debe incluir sección REPRODUCIR EL REPORTE")
        self.assertIn("obligatorio cuando hay error", contenido.lower(),
                     "Debe marcar como obligatorio cuando hay error")
    
    def test_regla_menciona_caso_real(self):
        """La regla debe incluir el caso real que falló."""
        regla_path = ROOT / ".cursor" / "rules" / "agente-requerimientos.mdc"
        
        if not regla_path.exists():
            self.skipTest("Archivo agente-requerimientos.mdc no encontrado")
        
        contenido = regla_path.read_text(encoding="utf-8")
        
        self.assertIn("Caso real que FALLÓ", contenido,
                     "Debe incluir caso real")
        self.assertIn("RIPS JSON", contenido,
                     "Debe mencionar RIPS JSON")
        self.assertIn("FENC591", contenido,
                     "Debe incluir ejemplo concreto")
    
    def test_regla_incluye_reproduccion_en_planteamiento(self):
        """La regla debe incluir reproduccion en la sección Planteamiento."""
        regla_path = ROOT / ".cursor" / "rules" / "agente-requerimientos.mdc"
        
        if not regla_path.exists():
            self.skipTest("Archivo agente-requerimientos.mdc no encontrado")
        
        contenido = regla_path.read_text(encoding="utf-8")
        
        self.assertIn("## Planteamiento", contenido,
                     "Debe tener sección Planteamiento")
        self.assertIn("reproduccion", contenido.lower(),
                     "Debe incluir reproduccion en planteamiento")
        self.assertIn("errorLiteral", contenido,
                     "Debe listar campo errorLiteral")
        self.assertIn("parametrosReales", contenido,
                     "Debe listar campo parametrosReales")


if __name__ == "__main__":
    unittest.main()
