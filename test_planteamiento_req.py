#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""El análisis no se da por listo si el cambio queda en un resumen."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import planteamiento_req


def _defecto_sql():
    return {
        "contenido": {
            "requerimiento": "La nota crédito de inventario no lleva el IVA en la cabecera",
            "impactoSql": "Sí",
            "impactoFe": "No",
            "impactoApi": "No",
            "analisis": "Causa: GEN_NC graba FNOT.VR_TOTAL con la suma del detalle y deja fuera VALORIVA.",
            "recomendacion": "En SPQ_GESVENTA, METODO GEN_NC, la cabecera queda en base más IVA.",
            "cambioPropuestoSimple": (
                "Hoy la cabecera de la nota queda sin IVA aunque el detalle sí lo trae. "
                "La cabecera pasará a guardar mercancía más IVA."
            ),
            "criteriosAceptacion": (
                "NC parcial: FNOT.VR_TOTAL = suma de base + IVA.\n"
                "NC administrativa sin devolución de inventario no cambia el asiento."
            ),
            "cambioPropuestoSql": (
                "-- SPQ_GESVENTA · GEN_NC\n"
                "---ANTES---\n"
                "UPDATE FNOT SET VR_TOTAL = @VLR_TOTAL WHERE CNSFNOT = @CNSFNOT\n"
                "---SUGERIDO---\n"
                "UPDATE FNOT SET VR_TOTAL = @VLR_TOTAL + @VLR_IVA WHERE CNSFNOT = @CNSFNOT\n"
            ),
            "ubicacion": {
                "procesoId": "inventario",
                "flujo": "Devolución parcial de venta",
                "pieza": {"tipo": "sp", "nombre": "SPQ_GESVENTA · GEN_NC"},
                "recursos": [{"tipo": "sp", "cual": "SPQ_GESVENTA"}],
                "participan": [{"sp": "SPQ_GESVENTA", "metodo": "GEN_NC"}],
                "estado": "listo",
            },
            "planteamiento": {
                "clasificacion": "defecto",
                "flujoHoy": [
                    "Gestión de ventas, devolución parcial",
                    "GESVENTA · GEN_NC",
                    "SPQ_GESVENTA inserta FNOTD y actualiza FNOT",
                    "FNOT.VR_TOTAL queda sin IVA",
                ],
                "causa": (
                    "GEN_NC acumula VR_TOTAL del detalle y graba la cabecera sin sumar VALORIVA, "
                    "así que el PDF y la contabilidad ven un total corto."
                ),
                "cambio": {
                    "negocio": (
                        "Hoy la cabecera de la nota queda sin IVA aunque el detalle sí lo trae. "
                        "La cabecera pasará a guardar mercancía más IVA."
                    ),
                    "frontend": "Sin cambio FE",
                    "sql": "SPQ_GESVENTA GEN_NC, UPDATE de FNOT.VR_TOTAL",
                    "backend": "Sin cambio API",
                },
                "noCambia": "NC administrativa sin devolución de inventario",
                "criterios": [
                    "Cabecera = base + IVA",
                    "NC administrativa permanece igual",
                ],
            },
        }
    }


def test_resumen_no_alcanza():
    sol = {
        "contenido": {
            "requerimiento": "que se vea el iva",
            "analisis": "Se debe ajustar el proceso.",
            "recomendacion": "ajustar el proceso",
            "cambioPropuestoSimple": "ajustar el proceso",
        }
    }
    revision = planteamiento_req.evaluar(sol)
    assert revision["ok"] is False
    assert revision["faltantes"]
    assert planteamiento_req.texto_faltantes(revision["faltantes"])


def test_defecto_con_bloque_sql():
    revision = planteamiento_req.evaluar(_defecto_sql())
    assert revision["ok"] is True, revision["faltantes"]


def test_sql_sin_separar_bloques():
    sol = _defecto_sql()
    sol["contenido"]["cambioPropuestoSql"] = (
        "SPQ_GESVENTA GEN_NC debe hacer UPDATE FNOT SET VR_TOTAL = base + iva WHERE CNSFNOT = @CNS "
        "y luego validar el total de la nota contra el detalle."
    )
    revision = planteamiento_req.evaluar(sol)
    assert revision["ok"] is False
    assert any("ANTES" in item or "bloque" in item.lower() for item in revision["faltantes"])


def test_capacitacion_no_abre_desarrollo():
    sol = _defecto_sql()
    sol["contenido"]["planteamiento"]["clasificacion"] = "capacitacion"
    sol["contenido"]["impactoSql"] = "Sí"
    revision = planteamiento_req.evaluar(sol)
    assert revision["ok"] is False
    assert any("capacitación" in item or "capacitacion" in item.lower() for item in revision["faltantes"])


def _ubicacion_ok():
    return {
        "contenido": {
            "ubicacion": {
                "procesoId": "inventario",
                "flujo": "Saldo inicial de entrada",
                "pieza": {"tipo": "ventana", "nombre": "Movimiento SI"},
                "recursos": [{"tipo": "ventana", "cual": "Movimiento SI"}, {"tipo": "codigo", "cual": "MovimientoPage.vue"}],
                "participan": [],
                "estado": "listo",
            }
        }
    }


def test_ubicacion_incompleta():
    revision = planteamiento_req.evaluar_ubicacion({"contenido": {}})
    assert revision["ok"] is False
    assert revision["espera"] is False
    assert revision["faltantes"]


def test_ubicacion_lista():
    revision = planteamiento_req.evaluar_ubicacion(_ubicacion_ok())
    assert revision["ok"] is True, revision["faltantes"]


def test_ubicacion_pregunta_detiene():
    sol = _ubicacion_ok()
    sol["contenido"]["ubicacion"]["estado"] = "pregunta"
    sol["contenido"]["ubicacion"]["preguntas"] = ["¿El saldo inicial es por bodega o por sede?"]
    revision = planteamiento_req.evaluar_ubicacion(sol)
    assert revision["ok"] is False
    assert revision["espera"] is True


def test_ubicacion_sin_mapa_no_sigue():
    sol = _ubicacion_ok()
    sol["contenido"]["ubicacion"]["estado"] = "sin_mapa"
    sol["contenido"]["ubicacion"]["bloqueo"] = "base"
    sol["contenido"]["ubicacion"]["preguntas"] = ["El proceso caja no tiene mapa de tramos."]
    revision = planteamiento_req.evaluar_ubicacion(sol)
    assert revision["ok"] is False
    assert revision["espera"] is True
    assert revision["bloqueo"] == "base"


def test_sp_de_otro_flujo():
    sol = _defecto_sql()
    sol["contenido"]["cambioPropuestoSql"] += "\n-- también toca SPK_NOMINA_CIERRE\n"
    revision = planteamiento_req.evaluar(sol)
    assert revision["ok"] is False
    assert any("no participan" in item for item in revision["faltantes"])


def test_comite_sin_bloque():
    sol = {
        "necesidad": "La nota no lleva el IVA",
        "analisis": "Clasificación: defecto\nCausa: " + ("GEN_NC omite el IVA de la cabecera. " * 8),
        "recomendacion": "Hay que cambiar SPQ_GESVENTA en el METODO GEN_NC para sumar el IVA.",
        "propuesta": "Hoy la cabecera no incluye el IVA del detalle y debe incluirlo al generar la nota.",
        "criterios": "La cabecera cuadra con el detalle.\nUna nota vieja no se toca.",
        "planteamiento": {
            "clasificacion": "defecto",
            "flujoHoy": ["Notas", "GEN_NC", "SPQ_GESVENTA graba FNOT"],
            "causa": "GEN_NC graba la cabecera con la base y deja el IVA solo en el detalle de la nota.",
        },
    }
    revision = planteamiento_req.evaluar(sol, modo="comite")
    assert revision["ok"] is False
    assert any("cambioPropuestoSql" in item for item in revision["faltantes"])


def main():
    test_resumen_no_alcanza()
    test_defecto_con_bloque_sql()
    test_sql_sin_separar_bloques()
    test_capacitacion_no_abre_desarrollo()
    test_ubicacion_incompleta()
    test_ubicacion_lista()
    test_ubicacion_pregunta_detiene()
    test_ubicacion_sin_mapa_no_sigue()
    test_sp_de_otro_flujo()
    test_comite_sin_bloque()
    print("ok planteamiento_req")
    return 0


if __name__ == "__main__":
    sys.exit(main())
