# -*- coding: utf-8 -*-
"""Sketchnotes del módulo Presupuesto.

Uso: python libro/scripts/gen_presupuesto_sketchnotes.py
Contrastado 2026-10-04: Qrystalos2 PresupuestoLayout + IXONLINE/SQL PREVERSION=2.0.7.
Regla: sin volúmenes ni valores de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch  # noqa: E402

B = "QRYSTALOS IPS · PRESUPUESTO"


def main():
    sketch(
        "ppto_mapa_sketchnote.jpg", B,
        "El menú Presupuesto: movimientos, ingresos, gastos, otros módulos e informes",
        "Módulo /ppto · el árbol es fijo; lo que se habilita lo decide el menú PRESUPUESTO del grupo",
        [
            {"num": "1", "tit": "Movimientos", "sub": "El calendario y el maestro", "pal": "sky", "items": [
                ("Presupuestos:", "Cabecera y distribución por rubros (abierto / cerrado)."),
                ("Periodos:", "Cerrar o reabrir el mes presupuestal (PRI.CERRADO_PPTO)."),
                ("Resoluciones:", "Soporte jurídico de adiciones y traslados."),
            ]},
            {"num": "2", "tit": "Ingresos y gastos", "sub": "Las dos cadenas", "pal": "orange", "items": [
                ("Ingresos:", "Reconocimientos, seguimiento reco/recaudo, notas débito/crédito."),
                ("Gastos:", "CDP → seguimiento gastos (CDP/RP/CxP/Pagos) → seguimiento CDP-CxP."),
                ("Movimientos:", "Traslados y adiciones entre rubros."),
            ]},
            {"num": "3", "tit": "Otros módulos", "sub": "Lo que llega de afuera", "pal": "violet", "items": [
                ("Facturación / Recaudos / Anticipos CxP:", "Traer documentos ya confirmados en su módulo."),
                ("Nómina:", "Se envía desde Configuración → Nómina (periodos y conceptos)."),
            ]},
            {"num": "4", "tit": "Informes e históricos", "sub": "Lectura y huecos", "pal": "green", "items": [
                ("Reportes:", "Ejecución por rubro/centro, listados CDP-RP-CxP-Pago, PAC, cartera, nómina."),
                ("Históricos:", "Cierre y seguimientos históricos: en construcción. El seguimiento de gastos vivo está en Gastos."),
            ]},
        ],
        pills=[
            ("Regla", "Presupuesto no envía asientos a Contabilidad: reserva, compromete y paga en sus propias tablas."),
            ("Ojo", "Históricos → Seguimiento Gasto no es la pantalla viva: esa está en Gastos → Seguimiento Gastos."),
        ],
        accent="#120727",
    )

    sketch(
        "ppto_config_sketchnote.jpg", B,
        "Configurar antes de operar: recursos, rubros, presupuesto y periodo",
        "Presupuesto → Configuración · Movimientos → Presupuestos · Periodos",
        [
            {"num": "1", "tit": "Catálogos", "sub": "Configuración", "pal": "sky", "items": [
                ("Recursos y rubros:", "De dónde sale el dinero y a qué cuenta presupuestal."),
                ("Clasificaciones, tipos, divisiones:", "Cómo se agrupa e informa."),
                ("Contratos y nómina:", "Plan/contrato y conceptos que se envían al presupuesto."),
            ]},
            {"num": "2", "tit": "Abrir el presupuesto", "sub": "Presupuestos", "pal": "orange", "items": [
                ("Cabecera:", "Vigencia, estado Abierto/Cerrado, contadores."),
                ("Distribución:", "Asignar valor a cada rubro (detalle). Sin rubro no hay CDP ni reconocimiento."),
            ]},
            {"num": "3", "tit": "Periodo", "sub": "Periodos presupuestales", "pal": "violet", "items": [
                ("Cerrar:", "Exige que no queden NoConfirmado en reco, recaudo, CDP, RP, CxP ni pagos."),
                ("Reabrir:", "Solo si el periodo presupuestal ya se había abierto."),
            ]},
        ],
        pills=[
            ("Orden", "Catálogos → presupuesto abierto con rubros → periodo abierto → primer CDP o reconocimiento."),
        ],
        accent="#120727",
    )

    sketch(
        "ppto_gastos_sketchnote.jpg", B,
        "La cadena de gasto: CDP → RP → obligación → pago",
        "Gastos → CDP · Seguimiento Gastos · Seguimiento CDP, CxP y Pagos",
        [
            {"num": "1", "tit": "CDP", "sub": "Reserva el saldo", "pal": "sky", "items": [
                ("Cabecera:", "Presupuesto, centro de costo, fecha. Consecutivo propio."),
                ("Detalle:", "Rubro + valor. No se baja por debajo de lo ya comprometido o liberado."),
                ("Estados:", "NoConfirmado → Confirmado → Anulado. Sin saldo usado para anular."),
            ]},
            {"num": "2", "tit": "RP", "sub": "Compromete", "pal": "orange", "items": [
                ("Registro presupuestal:", "Un RP por CDP. Fecha RP. Detalle por ítem del CDP."),
                ("Contrato:", "El número de contrato viaja a la impresión del RP."),
            ]},
            {"num": "3", "tit": "CxP y pago", "sub": "Obliga y paga", "pal": "violet", "items": [
                ("Obligación:", "PTCXP ligada al RP. Luego PTPAG."),
                ("Seguimiento:", "Cuatro pestañas (CDP/RP/CxP/Pagos) para confirmar lo que quedó NoConfirmado."),
            ]},
            {"num": "4", "tit": "Desconfirmar", "sub": "Variable", "pal": "rose", "items": [
                ("Cascada:", "Si PPTO_CDP_DESCONFMOV está encendida, desconfirmar el CDP baja RP, CxP y pagos."),
            ]},
        ],
        pills=[
            ("Regla", "No se anula ni se desconfirma un documento con saldo ya usado en el siguiente paso."),
        ],
        accent="#120727",
    )

    sketch(
        "ppto_ingresos_sketchnote.jpg", B,
        "La cadena de ingreso: reconocer, recaudar y ajustar con nota",
        "Ingresos → Reconocimientos · Seguimiento · Notas DB CR",
        [
            {"num": "1", "tit": "Reconocimiento", "sub": "El derecho de cobro", "pal": "sky", "items": [
                ("Cabecera:", "Tercero, fecha, centro, factura/CxC, valor. Presupuesto Abierto para confirmar."),
                ("Detalle:", "Rubros de ingreso. Estados NoConfirmado / Confirmado / Anulado."),
            ]},
            {"num": "2", "tit": "Recaudo", "sub": "Lo que entra", "pal": "orange", "items": [
                ("Seguimiento:", "Cruza reconocimientos con recaudos presupuestales."),
                ("Traer:", "Otros módulos → Recaudos (FPAG de caja/bancos/CxP)."),
            ]},
            {"num": "3", "tit": "Notas", "sub": "Ajuste", "pal": "violet", "items": [
                ("Pantalla:", "Nueva, confirmar, anular, imprimir. Confirmar/anular llama al aplicador de notas."),
                ("Hueco:", "El guardado de la nota lo pide el formulario a un método que el procedimiento aún no tiene."),
            ]},
        ],
        pills=[
            ("Regla", "Confirmar exige presupuesto Abierto. La nota no es la nota de cartera (FNOT)."),
        ],
        accent="#120727",
    )

    sketch(
        "ppto_alimentadores_sketchnote.jpg", B,
        "Cómo se alimenta el presupuesto desde otros módulos",
        "Movimientos → Otros Módulos · Configuración → Nómina",
        [
            {"num": "1", "tit": "Facturación", "sub": "Traer factura", "pal": "sky", "items": [
                ("Qué:", "Facturas confirmadas para armar reconocimiento o CDP según el caso."),
                ("Marca:", "El documento origen queda enlazado al presupuesto."),
            ]},
            {"num": "2", "tit": "Recaudos y anticipos", "sub": "Variables", "pal": "orange", "items": [
                ("Recaudos:", "FPAG de caja, bancos o CxP. Variable PRESUP_CXC_ACTIVADO."),
                ("Anticipos CxP:", "ANT + FCXP. Variable PRESUP_CXP_ACTIVADO. El envío lo pide la pantalla."),
            ]},
            {"num": "3", "tit": "Nómina", "sub": "Enviar", "pal": "violet", "items": [
                ("Antes:", "Revisa que cada concepto tenga rubro (si falta, lista de pendientes)."),
                ("Envío:", "La CxP de nómina pasa a registro presupuestal. Sin saldo de CDP el envío no marca."),
            ]},
        ],
        pills=[
            ("Regla", "Nada se inventa aquí: se trae lo ya confirmado en su módulo."),
        ],
        accent="#120727",
    )

    sketch(
        "ppto_cierre_sketchnote.jpg", B,
        "Cerrar el periodo presupuestal",
        "Movimientos → Periodos Presupuestales",
        [
            {"num": "1", "tit": "Revisar", "sub": "Antes de cerrar", "pal": "sky", "items": [
                ("Pendientes:", "Reconocimientos, recaudos, CDP, RP, CxP y pagos en NoConfirmado del mes."),
                ("Mensaje:", "Hay que confirmarlos primero. Reabrir exige que el periodo ya estuviera abierto alguna vez."),
            ]},
            {"num": "2", "tit": "Cerrar / reabrir", "sub": "Marca del periodo", "pal": "orange", "items": [
                ("Efecto:", "PRI.CERRADO_PPTO. No genera asiento contable."),
                ("Histórico:", "El botón Cierre del menú Históricos está en construcción; el procedimiento de histórico existe sin pantalla."),
            ]},
            {"num": "3", "tit": "Informes", "sub": "Después", "pal": "green", "items": [
                ("Ejecución:", "Por rubro y por centro (ingreso y gasto), PAC, listados de la cadena."),
                ("Cartera y nómina:", "Consultas de apoyo; no mueven presupuesto."),
            ]},
        ],
        pills=[
            ("Regla", "Cerrar presupuesto no es cerrar contabilidad: son dos marcas del mismo periodo."),
        ],
        accent="#120727",
    )

    print("OK sketchnotes presupuesto")


if __name__ == "__main__":
    main()
