#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Topes por tamaño de prompt e intentos del segundo plano."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import topes_modelo as tm
import analisis_posterior as ap


class TestTopesPeso(unittest.TestCase):
    def test_analizar_tiene_maximo_mayor_que_estimado(self):
        t = tm.tope_de("analizar-req")
        self.assertGreater(t["maximo"], t["estimado"])
        self.assertGreaterEqual(t["estimado"], 30000)

    def test_consultas_mas_liviano_que_analizar(self):
        self.assertLess(tm.tope_de("consultas")["maximo"], tm.tope_de("analizar-req")["maximo"])

    def test_bajo_estimado_ok(self):
        ver = tm.decision_peso(1000, "analizar-req")
        self.assertTrue(ver["ok"])
        self.assertEqual(ver["estado"], "ok")

    def test_entre_estimado_y_maximo_aviso(self):
        t = tm.tope_de("analizar-req")
        ver = tm.decision_peso(t["estimado"] + 100, "analizar-req")
        self.assertTrue(ver["ok"])
        self.assertEqual(ver["estado"], "aviso")

    def test_sobre_maximo_bloquea_sin_aval(self):
        t = tm.tope_de("analizar-req")
        ver = tm.decision_peso(t["maximo"] + 1, "analizar-req")
        self.assertFalse(ver["ok"])
        self.assertEqual(ver["estado"], "bloquear")

    def test_sobre_maximo_con_aval_sigue(self):
        t = tm.tope_de("analizar-req")
        ver = tm.decision_peso(t["maximo"] + 1, "analizar-req", aval_continuar=True)
        self.assertTrue(ver["ok"])
        self.assertEqual(ver["estado"], "avalado")


class TestTopesIntentos(unittest.TestCase):
    def test_dos_intentos_sin_error(self):
        self.assertTrue(tm.decision_intento(0)["ok"])
        self.assertTrue(tm.decision_intento(1)["ok"])
        self.assertFalse(tm.decision_intento(2)["ok"])

    def test_error_comunicacion_tambien_max_2(self):
        self.assertTrue(tm.es_error_comunicacion("proceso_muerto"))
        self.assertFalse(tm.decision_intento(2, "proceso_muerto")["ok"])

    def test_posterior_omite_al_tope(self):
        item = {"analisisPosterior": "en_cola", "analisisPosteriorIntentos": 2}
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": False}), "omitir")

    def test_sin_tope_diario(self):
        lim = ap.limites()
        self.assertEqual(lim.get("maxCasosPorDia"), 0)
        est = ap.estado_limite()
        self.assertFalse(est.get("pausado"))


if __name__ == "__main__":
    unittest.main()
