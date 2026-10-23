#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""El dictamen sale de la plantilla oficial, no del material armado."""
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))

import dictamen_html


def _sol(**extra):
    contenido = {
        "titulo": "IVA en la cabecera de la nota",
        "requerimiento": "La nota crédito de inventario no lleva el IVA en la cabecera",
        "impactoSql": "Sí",
        "impactoFe": "No",
        "impactoApi": "No",
        "analisis": (
            "Causa: GEN_NC graba FNOT.VR_TOTAL con la suma del detalle y deja fuera VALORIVA. "
            "El cuerpo está en activo/caso/sql/SPQ_GESVENTA.sql. "
            "Bajar con python scripts/sqlix_bajar_objeto.py --caso x SPQ_GESVENTA."
        ),
        "recomendacion": "En IXONLINE/SQL, SPQ_GESVENTA · GEN_NC, la cabecera queda en base más IVA.",
        "cambioPropuestoSimple": (
            "Hoy la cabecera de la nota queda sin IVA aunque el detalle sí lo trae. "
            "La cabecera pasará a guardar mercancía más IVA."
        ),
        "criteriosAceptacion": (
            "NC parcial: FNOT.VR_TOTAL = suma de base + IVA.\n"
            "NC administrativa sin devolución de inventario no cambia el asiento."
        ),
        "alcance": "Solo la cabecera de la nota de devolución parcial.",
        "restricciones": "No tocar la nota administrativa.",
        "cambioPropuestoSql": (
            "-- SPQ_GESVENTA · GEN_NC\n"
            "---ANTES---\n"
            "UPDATE FNOT SET VR_TOTAL = @VLR_TOTAL WHERE CNSFNOT = @CNSFNOT\n"
            "---SUGERIDO---\n"
            "UPDATE FNOT SET VR_TOTAL = @VLR_TOTAL + @VLR_IVA WHERE CNSFNOT = @CNSFNOT\n"
        ),
        "ubicacion": {
            "procesoId": "proceso-que-no-esta",
            "flujo": "Devolución parcial de venta",
            "pieza": {"tipo": "sp", "nombre": "SPQ_GESVENTA · GEN_NC"},
            "recursos": [{"tipo": "sp", "cual": "SPQ_GESVENTA"}],
            "participan": [{"sp": "SPQ_GESVENTA", "metodo": "GEN_NC"}],
            "estado": "listo",
        },
            "planteamiento": {
                "yaExiste": [
                    {
                        "donde": "Notas DB/CR, al aplicar la nota de devolución parcial",
                        "condicion": "La nota ya se crea y el detalle guarda el IVA",
                        "queHace": "La cabecera de la nota ya se graba al aplicar. El detalle ya trae el IVA.",
                    }
                ],
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
        "contabilidad": {"afecta": False, "comoAfecta": "No debe salir", "desarrollo": "Tampoco"},
        "validarAntes": {"aplica": False, "texto": "No debe pintarse"},
    }
    contenido.update(extra)
    return {
        "identificacion": {"idCaso": "20261023-prueba", "idReq": "0100099999", "fecha": "2026-10-23"},
        "proyecto": {"nombre": "Clínica prueba", "modulo": "Inventario", "rutaPantalla": "/inv/gesventa"},
        "gestion": {"estado": "Propuesto", "ticket": "FOR-1", "rama": "bugfix/iva-nc"},
        "contenido": contenido,
    }


def test_plantilla_oficial_sin_contabilidad_ni_rutas():
    html = dictamen_html.render(_sol(), "20261023-prueba")
    assert "dictamen-oficina" in html
    assert "<h2>1. Requerimiento del cliente</h2>" in html
    assert "<h2>5. Cambios propuestos</h2>" in html
    assert "5.0 En palabras simples" in html
    assert "5.2.1 Fragmentos SQL" in html
    assert 'class="sql-spec"' in html
    assert "---ANTES---" in html and "---SUGERIDO---" in html
    assert "Afecta contabilidad" in html
    assert ">No<" in html
    assert "Cómo lo afecta" not in html
    assert "Desarrollo contable" not in html
    assert "Validación del agente" not in html
    assert 'id="validar-antes"' not in html
    assert "No debe pintarse" not in html
    assert "activo/" not in html
    assert "sql_refe/" not in html
    assert "conocimiento/" not in html
    assert "python scripts/" not in html
    assert "material/armado.html" not in html
    assert "IXONLINE/SQL" in html
    assert "{{" not in html
    assert "<h2>7. Pruebas del desarrollador</h2>" in html
    assert "<h2>9. Pruebas de soporte</h2>" in html


def test_validar_antes_y_contabilidad_solo_si_aplican():
    html = dictamen_html.render(
        _sol(
            validarAntes={"aplica": True, "texto": "Reproducir la nota sin IVA antes de desarrollar."},
            contabilidad={
                "afecta": True,
                "comoAfecta": "El asiento de la nota toma el total de la cabecera.",
                "desarrollo": "MCUE de la nota debe usar el total con IVA.",
                "validacion": {"estado": "ok", "texto": "El comprobante usa VR_TOTAL de FNOT."},
            },
        ),
        "20261023-prueba",
    )
    assert 'id="validar-antes"' in html
    assert "Reproducir la nota sin IVA" in html
    assert "Cómo lo afecta" in html
    assert "Desarrollo contable" in html
    assert "Validación del agente" in html


def test_seccion_50_empieza_por_lo_que_ya_hace():
    sol = _sol()
    sol["contenido"]["planteamiento"]["yaExiste"] = [
        {
            "donde": "FEV/NC/NA-RIPS, pestaña NC / ND, Validar Notas",
            "condicion": "La nota ya está notificada a la DIAN",
            "queHace": "La nota crédito ya se envía a la DIAN y el CUFE queda generado.",
        }
    ]
    html = dictamen_html.render(sol, "20261023-prueba")
    bloque = html.split("5.0 En palabras simples", 1)[1][:900]
    assert "Hoy el sistema ya lo hace" in bloque
    assert "CUFE" in bloque
    assert "DIAN" in bloque
    assert bloque.find("CUFE") < bloque.find("Aparte de ese camino")


def test_no_escribe_si_el_planteamiento_esta_corto():
    sol = _sol()
    sol["contenido"]["planteamiento"] = {}
    with tempfile.TemporaryDirectory() as tmp:
        out = dictamen_html.generar("20261023-prueba", sol, dest_dir=tmp, reemplazar=True)
        assert out["ok"] is False
        assert not os.path.exists(os.path.join(tmp, "20261023-prueba.html"))


def test_genera_y_no_pisa_un_html_escrito_a_mano():
    sol = _sol()
    with tempfile.TemporaryDirectory() as tmp:
        manual = os.path.join(tmp, "20261023-prueba.html")
        with open(manual, "w", encoding="utf-8") as fh:
            fh.write("<html>dictamen a mano</html>")
        respetado = dictamen_html.generar("20261023-prueba", sol, dest_dir=tmp, reemplazar=False)
        assert respetado["ok"] is False
        assert respetado["motivo"] == "ya_existe"
        with open(manual, encoding="utf-8") as fh:
            assert fh.read() == "<html>dictamen a mano</html>"
        creado = dictamen_html.generar("20261023-prueba", sol, dest_dir=tmp, reemplazar=True)
        assert creado["ok"] is True
        assert creado["sinCambio"] is False
        otra = dictamen_html.generar("20261023-prueba", sol, dest_dir=tmp, reemplazar=True)
        assert otra["sinCambio"] is True


if __name__ == "__main__":
    test_plantilla_oficial_sin_contabilidad_ni_rutas()
    test_seccion_50_empieza_por_lo_que_ya_hace()
    test_validar_antes_y_contabilidad_solo_si_aplican()
    test_no_escribe_si_el_planteamiento_esta_corto()
    test_genera_y_no_pisa_un_html_escrito_a_mano()
    print("ok")
