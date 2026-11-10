#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Checkpoints estado.pasos del análisis de requerimiento."""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import pasos_analisis as pa


class TestPasosAnalisis(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.caso = "test-pasos-001"
        self.activo = Path(self.tmp.name) / "activo" / self.caso
        self.activo.mkdir(parents=True)
        (self.activo / "estado.json").write_text("{}", encoding="utf-8")
        self._patch = mock.patch.object(pa, "ROOT", self.tmp.name)
        self._patch.start()

    def tearDown(self):
        self._patch.stop()
        self.tmp.cleanup()

    def test_esquema_cinco_pasos(self):
        e = pa.esquema_vacio()
        self.assertEqual(list(e.keys()), list(pa.PASOS_ORDEN))
        self.assertTrue(all(e[p]["estado"] == "pendiente" for p in e))

    def test_marcar_listo_y_siguiente(self):
        pa.marcar(self.caso, "ubicar", "listo", evidencia="rips → fev")
        self.assertTrue(pa.esta_listo(self.caso, "ubicar"))
        self.assertEqual(pa.siguiente_pendiente(self.caso), "analizar")
        self.assertEqual(pa.motivo_siguiente(self.caso), "analizar-req")

    def test_invalidar_desde_analizar(self):
        for p in pa.PASOS_ORDEN:
            pa.marcar(self.caso, p, "listo", evidencia="x")
        pa.invalidar_desde(self.caso, "analizar")
        self.assertTrue(pa.esta_listo(self.caso, "ubicar"))
        self.assertFalse(pa.esta_listo(self.caso, "analizar"))
        self.assertFalse(pa.esta_listo(self.caso, "dictamen"))
        self.assertEqual(pa.siguiente_pendiente(self.caso), "analizar")

    def test_completo_solo_con_cinco(self):
        self.assertFalse(pa.resumen(self.caso)["completo"])
        for p in pa.PASOS_ORDEN:
            pa.marcar(self.caso, p, "listo", evidencia="ok")
        r = pa.resumen(self.caso)
        self.assertTrue(r["completo"])
        self.assertEqual(r["siguiente"], "")

    def test_sincronizar_desde_archivos(self):
        mat = self.activo / "material"
        mat.mkdir()
        (mat / "documento.md").write_text("# plan", encoding="utf-8")
        mocks = self.activo / "mockups"
        mocks.mkdir()
        (mocks / "mockup-ventana-flexible.html").write_text("<html></html>", encoding="utf-8")
        dictamenes = Path(self.tmp.name) / "dictamenes"
        dictamenes.mkdir()
        (dictamenes / f"{self.caso}.html").write_text("<html></html>", encoding="utf-8")
        sol = {
            "contenido": {
                "ubicacion": {"estado": "listo", "procesoId": "rips-json", "flujo": "fev"},
                "analisis": "x" * 80,
                "recomendacion": "y" * 80,
                "cambioPropuestoSimple": "Propuesta\n1. Adicionar campo.\nAntecedentes\n1. Hoy no existe.",
            }
        }
        (self.activo / "solicitud.json").write_text(
            json.dumps(sol, ensure_ascii=False), encoding="utf-8"
        )
        pasos = pa.sincronizar_evidencia(self.caso)
        self.assertEqual(pasos["ubicar"]["estado"], "listo")
        self.assertEqual(pasos["material"]["estado"], "listo")
        self.assertEqual(pasos["mockup"]["estado"], "listo")
        self.assertEqual(pasos["dictamen"]["estado"], "listo")

    def test_motivo_mapeo(self):
        self.assertEqual(pa.paso_de_motivo("ubicar-req"), "ubicar")
        self.assertEqual(pa.paso_de_motivo("mockup-ventana"), "mockup")
        self.assertEqual(pa.motivo_de_paso("material"), "material")


if __name__ == "__main__":
    unittest.main()
