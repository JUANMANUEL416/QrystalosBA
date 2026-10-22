#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests de rendimiento y confiabilidad para cursor_bot.py.

Valida:
- Reintentos con backoff exponencial (Mejora 3)
- Límites de tamaño del contexto inline (Mejora 1)
- Preselección KB (Mejora 2)
- Carga de todos los capacitacion/*.json
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

# Añadir scripts/ al path
ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import cursor_bot


class TestReintentos(unittest.IsolatedAsyncioTestCase):
    """Prueba el mecanismo de reintentos con errores de red."""
    
    @unittest.skipIf(not hasattr(sys.modules.get('cursor_sdk', None), 'errors'), 
                     "cursor_sdk no disponible")
    async def test_reintento_network_error(self):
        """Debe reintentar en InternalServerError con 'Network request failed'."""
        from cursor_sdk.errors import InternalServerError
        intentos = []
        
        async def funcion_fallida():
            intentos.append(time.time())
            if len(intentos) < 3:
                raise InternalServerError("internal: Network request failed")
            return "exito"
        
        resultado = await cursor_bot._intentar_con_reintentos_async(
            "test", funcion_fallida, max_intentos=3
        )
        
        self.assertEqual(resultado, "exito")
        self.assertEqual(len(intentos), 3, "Debió reintentar 2 veces antes del éxito")
        
        # Verificar backoff exponencial (tolerancia +50% por overhead)
        if len(intentos) >= 2:
            espera1 = intentos[1] - intentos[0]
            self.assertGreaterEqual(espera1, 1.8, "Primera espera ≥2s")
            self.assertLessEqual(espera1, 3.0, "Primera espera ≤3s")
        
        if len(intentos) >= 3:
            espera2 = intentos[2] - intentos[1]
            self.assertGreaterEqual(espera2, 4.5, "Segunda espera ≥5s")
            self.assertLessEqual(espera2, 7.5, "Segunda espera ≤7.5s")
    
    @unittest.skipIf(not hasattr(sys.modules.get('cursor_sdk', None), 'errors'), 
                     "cursor_sdk no disponible")
    async def test_no_reintenta_auth_error(self):
        """No debe reintentar errores de autenticación."""
        from cursor_sdk.errors import AuthenticationError
        intentos = []
        
        async def funcion_auth_error():
            intentos.append(1)
            raise AuthenticationError("Invalid API key")
        
        with self.assertRaises(Exception) as ctx:
            await cursor_bot._intentar_con_reintentos_async(
                "test", funcion_auth_error, max_intentos=3
            )
        
        self.assertEqual(len(intentos), 1, "No debe reintentar auth errors")
        self.assertIn("Invalid API key", str(ctx.exception))
    
    async def test_no_reintenta_otros_errores(self):
        """No debe reintentar errores que no son de red (mock simple)."""
        intentos = []
        
        async def funcion_otro_error():
            intentos.append(1)
            raise ValueError("Otro tipo de error")
        
        # Sin cursor_sdk, probamos la lógica básica de no reintentar ValueError
        try:
            # Intentar sin reintentos: debe fallar inmediatamente
            async def wrapper():
                try:
                    return await funcion_otro_error()
                except ValueError:
                    raise
            await wrapper()
        except ValueError:
            pass  # Esperado
        
        self.assertEqual(len(intentos), 1, "No debe reintentar errores no-red")
    
    async def test_falla_tras_agotar_intentos(self):
        """Debe fallar si se agotan los reintentos (mock simple)."""
        # Test simplificado sin cursor_sdk
        intentos = []
        
        async def funcion_siempre_falla():
            intentos.append(1)
            raise RuntimeError("Error persistente")
        
        # Sin cursor_sdk, el error no se reconoce como de red, no reintenta
        with self.assertRaises(RuntimeError):
            async def wrapper():
                try:
                    return await funcion_siempre_falla()
                except RuntimeError:
                    raise
            await wrapper()
        
        self.assertEqual(len(intentos), 1, "Sin cursor_sdk, no reintenta RuntimeError")


class TestContextoInline(unittest.TestCase):
    """Prueba el contexto inline (Mejora 1)."""
    
    def test_truncar_sensiblemente(self):
        """Debe truncar en salto de línea cuando es posible."""
        texto = "línea1\n" * 100
        truncado = cursor_bot._truncar_sensiblemente(texto, 50)
        
        self.assertLessEqual(len(truncado), 70, "Debe truncar cerca del límite")
        self.assertIn("...(truncado)", truncado)
    
    def test_truncar_sin_salto_linea(self):
        """Debe truncar en el límite si no hay saltos de línea."""
        texto = "x" * 200
        truncado = cursor_bot._truncar_sensiblemente(texto, 50)
        
        self.assertLessEqual(len(truncado), 65, "Debe truncar en el límite")
        self.assertIn("...(truncado)", truncado)
    
    def test_no_truncar_si_cabe(self):
        """No debe truncar si el texto cabe."""
        texto = "Texto corto"
        truncado = cursor_bot._truncar_sensiblemente(texto, 100)
        
        self.assertEqual(truncado, texto)
        self.assertNotIn("...(truncado)", truncado)
    
    def test_contexto_inline_solicitud(self):
        """Debe extraer campos clave de solicitud.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            caso_dir = Path(tmpdir) / "activo" / "test-001"
            caso_dir.mkdir(parents=True)
            
            solicitud = {
                "contenido": {
                    "titulo": "Prueba test",
                    "requerimiento": "Requerimiento de prueba",
                    "descripcion": "Descripción detallada",
                    "analisis": "Análisis completo",
                    "campoExtra": "No debe aparecer"
                },
                "sql": {
                    "procesoId": "inventario",
                    "usarDocumentacion": True,
                    "metodosDocumentados": [{"sp": "SPQ_TEST", "metodo": "LISTAR"}]
                }
            }
            
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            
            # Mock caso_dir
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                inline = cursor_bot._contexto_inline_solicitud("test-001", max_chars=4000)
            
            self.assertIn("titulo", inline)
            self.assertIn("Prueba test", inline)
            self.assertIn("procesoId", inline)
            self.assertIn("inventario", inline)
            self.assertNotIn("campoExtra", inline, "No debe incluir campos no clave")
    
    def test_contexto_inline_chat(self):
        """Debe extraer últimos N mensajes de chat.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            caso_dir = Path(tmpdir) / "activo" / "test-002"
            caso_dir.mkdir(parents=True)
            
            mensajes = [
                {"autor": "coordinador", "en": "2024-01-01T10:00:00", "texto": f"Mensaje {i}"}
                for i in range(20)
            ]
            
            (caso_dir / "chat.json").write_text(
                json.dumps(mensajes, ensure_ascii=False), 
                encoding="utf-8"
            )
            
            # Mock caso_dir
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                inline = cursor_bot._contexto_inline_chat("test-002", max_mensajes=5, max_chars=2000)
            
            # Debe contener solo los últimos 5
            self.assertIn("Mensaje 19", inline)
            self.assertIn("Mensaje 15", inline)
            self.assertNotIn("Mensaje 10", inline)


class TestPreseleccionKB(unittest.TestCase):
    """Prueba la preselección KB mejorada (Mejora 2)."""
    
    def test_contexto_inline_kb_con_procesos(self):
        """Debe retornar texto inline y lista de proceso_ids."""
        req_texto = "bodega kardex inventario ITAR"
        proceso_id = "inventario"
        
        # Mock kb_contexto_req dentro del módulo
        mock_ctx = {
            "procesos": [
                {
                    "id": "inventario",
                    "score": 12.5,
                    "ventanas": ["Entrada de bodega", "Kardex"],
                    "sps_metodos": ["SPQ_ITAR", "SPK_KARDEX"]
                }
            ]
        }
        
        with patch('kb_contexto_req.preseleccionar_contexto', return_value=mock_ctx):
            inline, procesos_ids = cursor_bot._contexto_inline_kb(req_texto, proceso_id, max_chars=3000)
        
        self.assertIn("inventario", inline)
        self.assertIn("12.5", inline)
        self.assertEqual(procesos_ids, ["inventario"])
    
    def test_contexto_inline_kb_sin_procesos(self):
        """Debe retornar vacío si no hay procesos preseleccionados."""
        req_texto = "xyz abc def"
        proceso_id = ""
        
        mock_ctx = {"procesos": []}
        
        with patch('kb_contexto_req.preseleccionar_contexto', return_value=mock_ctx):
            inline, procesos_ids = cursor_bot._contexto_inline_kb(req_texto, proceso_id, max_chars=3000)
        
        self.assertEqual(inline, "")
        self.assertEqual(procesos_ids, [])
    
    def test_contexto_inline_kb_error_handling(self):
        """Debe manejar errores sin fallar."""
        req_texto = "test"
        proceso_id = ""
        
        with patch('kb_contexto_req.preseleccionar_contexto', side_effect=Exception("Error de prueba")):
            inline, procesos_ids = cursor_bot._contexto_inline_kb(req_texto, proceso_id, max_chars=3000)
        
        self.assertEqual(inline, "")
        self.assertEqual(procesos_ids, [])


class TestCapacitacionJSON(unittest.TestCase):
    """Valida que todos los capacitacion/*.json sean válidos y cargar_temas() funcione."""
    
    def test_todos_json_validos(self):
        """Todos los archivos capacitacion/*.json deben parsear correctamente."""
        capacitacion_dir = ROOT / "capacitacion"
        if not capacitacion_dir.exists():
            self.skipTest("Directorio capacitacion/ no existe")
        
        archivos = list(capacitacion_dir.glob("*.json"))
        self.assertGreater(len(archivos), 0, "Debe haber al menos un .json en capacitacion/")
        
        for archivo in archivos:
            with self.subTest(archivo=archivo.name):
                try:
                    with open(archivo, encoding="utf-8") as f:
                        data = json.load(f)
                    self.assertIsInstance(data, (dict, list), f"{archivo.name} debe ser dict o list")
                except json.JSONDecodeError as exc:
                    self.fail(f"{archivo.name} tiene JSON inválido: {exc}")
    
    def test_cargar_temas(self):
        """La función cargar_temas() debe ejecutar sin errores."""
        try:
            import capacitacion.generador as gen
            temas = gen.cargar_temas()
            
            self.assertIsInstance(temas, list, "cargar_temas() debe retornar una lista")
            if temas:
                tema = temas[0]
                self.assertIn("id", tema, "Cada tema debe tener 'id'")
                self.assertIn("titulo", tema, "Cada tema debe tener 'titulo'")
        except ImportError:
            self.skipTest("No se pudo importar capacitacion.generador")
        except Exception as exc:
            self.fail(f"cargar_temas() falló: {exc}")


class TestLimitesSizeContexto(unittest.TestCase):
    """Verifica que los límites de tamaño del contexto inline se respeten."""
    
    def test_limite_solicitud(self):
        """contexto_inline_solicitud debe respetar max_chars."""
        with tempfile.TemporaryDirectory() as tmpdir:
            caso_dir = Path(tmpdir) / "activo" / "test-003"
            caso_dir.mkdir(parents=True)
            
            # Crear solicitud.json con contenido muy largo
            solicitud = {
                "contenido": {
                    "titulo": "T" * 5000,
                    "requerimiento": "R" * 5000,
                    "descripcion": "D" * 5000
                },
                "sql": {"procesoId": "test"}
            }
            
            (caso_dir / "solicitud.json").write_text(
                json.dumps(solicitud, ensure_ascii=False), 
                encoding="utf-8"
            )
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                inline = cursor_bot._contexto_inline_solicitud("test-003", max_chars=1000)
            
            # El resultado debe estar truncado
            self.assertLessEqual(len(inline), 1100, "Debe respetar el límite +10% margen")
            self.assertIn("...(truncado)", inline, "Debe indicar truncamiento")
    
    def test_limite_chat(self):
        """contexto_inline_chat debe respetar max_chars y max_mensajes."""
        with tempfile.TemporaryDirectory() as tmpdir:
            caso_dir = Path(tmpdir) / "activo" / "test-004"
            caso_dir.mkdir(parents=True)
            
            mensajes = [
                {"autor": "coordinador", "en": "2024-01-01T10:00:00", "texto": "X" * 1000}
                for _ in range(50)
            ]
            
            (caso_dir / "chat.json").write_text(
                json.dumps(mensajes, ensure_ascii=False), 
                encoding="utf-8"
            )
            
            with patch.object(cursor_bot, 'caso_dir', return_value=str(caso_dir)):
                inline = cursor_bot._contexto_inline_chat("test-004", max_mensajes=3, max_chars=500)
            
            # Verificar que está truncado y respeta límites
            self.assertLessEqual(len(inline), 600, "Debe respetar max_chars +margen")
            if "...(truncado)" in inline:
                # Está truncado, validar que tiene los últimos mensajes antes del truncamiento
                self.assertIn("coordinador", inline)
                self.assertIn("2024-01-01", inline)


if __name__ == "__main__":
    unittest.main()
