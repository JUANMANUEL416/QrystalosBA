# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas) del libro Dispensación (Inventario → Solicitudes).

Uso:  python libro/scripts/gen_dispensacion_sketchnotes.py
Salida: libro/img/disp_*_sketchnote.jpg

Contenido contrastado 2026-10-04 con Qrystalos2 (pages/inv/izsol/SolicitudesPage.vue →
components/inv/izsol/IndexComponent.vue, IMOVComponent, NuevaDispensacionCEDialog, ListaAplicacionMedicamentos)
y los SP de IXONLINE/SQL (SPQ_IZSOL, SPQ_IZSOL_2, SPK_CONFIRMASAL_CM, SPK_GENCOBRO_INSCENTRAL, SPK_CM_GENIMOV_SOL).
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · INVENTARIO, COMPRAS Y FARMACIA · DISPENSACIÓN"


def main():
    sketch(
        "disp_flujo_sketchnote.jpg", B,
        "Dispensar: de la solicitud a la salida confirmada",
        "Inventario → Solicitudes. Elegir bodega, tomar la solicitud, entregar por lote, procesar y confirmar",
        [
            {"num": "1", "tit": "Tomar", "sub": "IZSOL · AGREGAR", "pal": "sky", "items": [
                ("Qué hace:", "Abre (o reabre) el movimiento de salida en borrador para esa solicitud."),
                ("Bloquea si:", "La admisión está cerrada (ALTAS_QUE_VALIDA_INV), la solicitud venció (MVIGENCIAIZSOL / HVIGENCIAIZSOL) o la orden de consulta externa está anulada."),
                ("Copago:", "Autorizador CE con caja: exige el copago recaudado antes de dispensar."),
                ("Otro equipo:", "Si la solicitud ya está tomada, el sistema avisa."),
            ]},
            {"num": "2", "tit": "Entregar", "sub": "IZSOL · ENTREGAR / Código de barras", "pal": "orange", "items": [
                ("Por lote:", "Cantidad ≤ existencia del lote; vencimiento vigente; unidosis aparte."),
                ("Suspendido:", "No se dispensa un medicamento suspendido en la orden (24 horas, orden médica, enfermería, prestaciones)."),
                ("Autorización PROA:", "Artículos con MAUTORIZACION exigen la línea Iniciar vigente."),
                ("Retirar entrega:", "Clic derecho en el lote mientras no se confirme."),
            ]},
            {"num": "3", "tit": "Procesar", "sub": "IZSOL · PROCESAR", "pal": "violet", "items": [
                ("Qué hace:", "Pasa lo entregado al detalle del movimiento (IMOVH). Sigue en borrador."),
                ("Faltantes:", "La línea queda abierta (estado 1) si entregó menos de lo pedido."),
            ]},
            {"num": "4", "tit": "Confirmar", "sub": "IZSOL · CONF_MOVIMIENTO → SPK_CONFIRMASAL_CM", "pal": "green", "items": [
                ("Existencias:", "Descuenta IEXI, escribe kardex y contabiliza si el tipo lo pide."),
                ("Tercero y centro:", "Según la procedencia: admisión/habitación o autorización."),
                ("Cobro:", "Genera el cargo al paciente (SPK_GENCOBRO_INSCENTRAL) salvo producción y consumo."),
                ("Cierre:", "Si no queda nada pendiente, la solicitud pasa a Cerrada."),
            ]},
        ],
        pills=[
            ("Estados IZSOL", "1 Abierta (se puede entregar) · 2 Cerrada. Las líneas: 1 con faltante, 0 completa."),
            ("Firmas", "Paciente (Firma_paciente_mov) y enfermera que recibe (Firma_recibido_enf); huella o Wacom si están activas."),
            ("Devolver", "Devoluciones pendientes → Procesar devolución: entrada con IDINVMOV_DEVOLUCION y motivo."),
            ("No confundir", "Venta de insumos (mostrador) y custodia (entrada propia) son otros caminos."),
        ],
        accent="#0f766e",
    )

    sketch(
        "disp_procedencias_sketchnote.jpg", B,
        "Procedencias: quién pide y qué cambia en farmacia",
        "IZSOL.CLASE dice de dónde nació la solicitud. Cambia el paciente, el tercero, las validaciones y el cobro",
        [
            {"num": "A", "tit": "Hospitalización", "sub": "Paciente con admisión (HADM)", "pal": "sky", "items": [
                ("SENFER · Enfermería:", "Pedido del piso. Cobro inmediato al confirmar; verifica suspendidos."),
                ("OMEDICA · Orden médica:", "Tercero de la admisión; área y centro de la habitación."),
                ("24HORAS · Orden 24 h:", "El pedido del día (IZSOLM); se busca el Iniciar vigente del servicio."),
                ("HTX · HBALINI · OMSOLI:", "Cargos de historia, balance inicial (cobro HBALI aparte) y solicitud desde la orden."),
            ]},
            {"num": "B", "tit": "Consulta externa", "sub": "Autorización, transcripción, fórmula", "pal": "orange", "items": [
                ("CE · Autorizaciones:", "NOADMISION es la orden AUT. Orden anulada bloquea; copago en caja si la generó."),
                ("TRANS_CE · Transcripciones:", "Dispensación manual; guarda el afiliado. Sin vigencia ni cierre de admisión; sin copago."),
                ("FORMEDCE / FORMEDASIS:", "Fórmula médica (FME) de consulta externa o asistencial."),
                ("APOYODX · Apoyo Dx:", "Cobro inmediato como enfermería."),
            ]},
            {"num": "C", "tit": "Procedimientos y programas", "sub": "Sin admisión clásica", "pal": "violet", "items": [
                ("QXPGCX · Programa QX:", "La programación de cirugía; no valida vigencia ni cierre."),
                ("ONCO · Oncológico:", "Paciente, plan y contratante salen de la cita (CIT)."),
                ("HEMOD · Hemodinamia:", "Procedimiento de hemodinamia."),
                ("HPRE · Prestaciones:", "La prestación es la referencia; no valida cierre de admisión."),
            ]},
            {"num": "D", "tit": "Sin paciente que cobrar", "sub": "Producción, consumo y aplicación", "pal": "green", "items": [
                ("PROD · Producción:", "Sin admisión: no valida cierre, vigencia ni genera cobro."),
                ("Consumo · Gasto:", "Centro de costo como sector; es el gasto por consumo."),
                ("APLIM · Aplicación:", "Al confirmar marca la línea APLIMF como DISPENSADA con el movimiento."),
            ]},
        ],
        pills=[
            ("Regla", "El filtro Procedencia y la columna CLASE muestran el mismo código; el SP decide por ese valor."),
            ("Manual CE", "TRANS_CE, FORMEDCE y CE con MANUALCE = 1 saltan vigencia, cierre y copago."),
            ("Al confirmar", "Admisión → tercero HADM y centro HHAB. Consulta externa → tercero, área y centro de AUT."),
        ],
        accent="#c2410c",
    )

    sketch(
        "disp_despues_sketchnote.jpg", B,
        "Después de entregar: cerrar, devolver, deshacer, firmar",
        "Lo que la farmacia puede hacer sobre una solicitud ya tomada o ya confirmada",
        [
            {"num": "1", "tit": "Cerrar / abrir", "sub": "IZSOL · CERRAR_IZSOL / ABRIR_IZSOL", "pal": "sky", "items": [
                ("Cerrar:", "Anula movimientos vacíos y deja la solicitud Cerrada; con IZSOL_CIERRE_MOTIVO = SI pide motivo."),
                ("Abrir:", "Permiso abrir_solicitud; solo si quedan líneas por entregar."),
            ]},
            {"num": "2", "tit": "Deshacer entrega", "sub": "IZSOL · DESHACER_ENTREGA", "pal": "orange", "items": [
                ("Cuándo:", "Antes de confirmar: retira el lote del borrador."),
                ("Permiso:", "deshacer_entrega. Nueva dispensación CE: «Deshacer y corregir» anula solicitud, autorización y fórmula."),
            ]},
            {"num": "3", "tit": "Devolver", "sub": "IZSOL_2 · PROCESAR_DEVOLUCION", "pal": "violet", "items": [
                ("Qué pide:", "Movimiento confirmado, motivo y el tipo IDINVMOV_DEVOLUCION."),
                ("Qué hace:", "Entrada que reintegra el lote (SPK_CONFIRMARENTRADAS); la solicitud muestra Dev. parcial / total."),
                ("Pendientes:", "Botón Devoluciones Pendientes con contador."),
            ]},
            {"num": "4", "tit": "Entregar y firmar", "sub": "TERMINAR_ENTREGA · FIRMAR_PACIENTE_MOV", "pal": "green", "items": [
                ("Entregas no recibidas:", "Enfermería recibe o regresa; INV_RECIBE_CON_LOGIN pide usuario."),
                ("Firma:", "Paciente o enfermera, manuscrita, Wacom o huella."),
                ("Comprobante:", "Impresión del movimiento y comprobante al paciente (COMPROBANTES_INV)."),
            ]},
        ],
        pills=[
            ("Autorizar", "Clic derecho → Autorizar este ítem / todos (IZSOL_2 · AUTORIZAR) para líneas que lo requieren."),
            ("Cantidad y copago", "Cambiar cantidad y Modificar copago desde el menú contextual, con permiso."),
            ("Traer de otra bodega", "per_traslado_bodegas: la solicitud se surte con traslado desde otra bodega."),
        ],
        accent="#4338ca",
    )
    print("OK", IMG_DIR)


if __name__ == "__main__":
    main()
