#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Política del análisis en segundo plano: no relanzar cerrados; intentos, no cupo diario."""
from __future__ import annotations

import sys
import unittest
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import analisis_posterior as ap


class TestPoliticaSegundoPlano(unittest.TestCase):
    def test_sin_cupo_diario(self):
        lim = ap.limites()
        self.assertEqual(lim.get("maxCasosPorDia"), 0)
        self.assertEqual(lim.get("maxSinError"), 2)

    def test_cerrado_sin_analisis_no_se_lanza(self):
        item = {"terminadoPor": "sin_analisis", "analisisPosterior": "en_cola"}
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": True}), "omitir")
        self.assertIn("sin análisis", ap.motivo_cierre(item, {"fase1Cerrada": True}))

    def test_correo_enviado_no_se_lanza(self):
        item = {"terminadoPor": "correo_enviado"}
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": True}), "omitir")

    def test_fase1_cerrada_no_se_lanza(self):
        item = {"analisisPosterior": "en_cola"}
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": True}), "omitir")

    def test_enmienda_sin_boton_no_lanza(self):
        item = {"analisisPosterior": "en_cola"}
        estado = {"fase1Cerrada": False, "enmiendaAbierta": True, "analisisCompletado": True}
        self.assertIn("Volver a analizar", ap.motivo_cierre(item, estado))
        self.assertEqual(ap.decision_posterior(item, estado), "omitir")

    def test_enmienda_con_reanalisis_si_lanza(self):
        item = {"analisisPosterior": "en_cola", "reanalisisPedido": True}
        estado = {"fase1Cerrada": False, "enmiendaAbierta": True, "analisisCompletado": True}
        self.assertEqual(ap.motivo_cierre(item, estado), "")
        self.assertEqual(ap.decision_posterior(item, estado), "lanzar")

    def test_analisis_completo_sin_reabrir_no_lanza(self):
        item = {"analisisPosterior": "en_cola"}
        estado = {"fase1Cerrada": False, "analisisCompletado": True}
        self.assertEqual(ap.decision_posterior(item, estado), "omitir")

    def test_abierto_se_lanza(self):
        item = {"analisisPosterior": "en_cola"}
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": False}), "lanzar")

    def test_dos_intentos_bloquean(self):
        item = {
            "analisisPosterior": "en_cola",
            "analisisPosteriorIntentos": 2,
            "analisisPosteriorError": "",
        }
        self.assertEqual(ap.decision_posterior(item, {"fase1Cerrada": False}), "omitir")

    def test_corte_de_peso_no_se_trata_como_cadena_en_curso(self):
        """Un tope a mitad de cadena no espera 90 s ni cierra el análisis."""
        bot = {
            "estado": "listo",
            "pid": 0,
            "motivo": "analizar-req",
            "terminadoEn": datetime.now().isoformat(timespec="seconds"),
            "corte": "peso",
            "corteNota": "supera el máximo",
        }
        self.assertEqual(ap._asentar("caso", bot), "corte")

    def test_cadena_reciente_sin_corte_sigue_esperando(self):
        bot = {
            "estado": "listo",
            "pid": 0,
            "motivo": "analizar-req",
            "terminadoEn": datetime.now().isoformat(timespec="seconds"),
        }
        self.assertEqual(ap._asentar("caso", bot), "esperar")


if __name__ == "__main__":
    unittest.main()
