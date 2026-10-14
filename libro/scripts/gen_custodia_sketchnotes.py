# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas) del libro Custodia de medicamentos.

Uso:  python libro/scripts/gen_custodia_sketchnotes.py
Salida: libro/img/cus_*_sketchnote.jpg

Contenido contrastado 2026-10-04 con Qrystalos2 (components/inv/izsol/IMOVComponetNew.vue,
boot/Inventario/rptActaRecepcion.js, components/inv/Informes/InformeCustodiaComponent.vue,
APLIMAgendaCitaComponent, IBODComponent) y los SP de IXONLINE/SQL (SPQ_IZSOL: AGREGA_CUSTODIA,
AGREGA_ARTICULO_ITRAH, ON_ACEPTA_TRANSITO, SUBIR_CUSTODIA_MASIVA, CONF_ENTRADA; SPK_INSERTENTTRANSITO;
SPK_CONFIRMARENTRADAS; SPQ_IMOV_3 actas; SPQ_EXISTENCIA EXPORTA_INFORME_CUSTODIA).
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · INVENTARIO · CUSTODIA DE MEDICAMENTOS"


def main():
    sketch(
        "cus_flujo_sketchnote.jpg", B,
        "Recibir custodia a mano",
        "Inventario → Movimientos (bodega de custodia, filtro Crédito). Abrir tránsito, agregar, lotear, aceptar, paciente, confirmar",
        [
            {"num": "1", "tit": "Abrir", "sub": "IZSOL · AGREGA_CUSTODIA", "pal": "sky", "items": [
                ("Botón:", "Ingresar Custodia en el panel de tránsito (permiso BrwTransito · Bcustodia)."),
                ("Pide:", "Proveedor (tercero PRO) y observación. Sin proveedor: «Seleccione un Tercero»."),
                ("Crea:", "Tránsito ITRA con origen CUSTODIA, tipo IDINVTPROPIA, estado 0."),
                ("Bloquea si:", "La variable IDINVTPROPIA no está configurada."),
            ]},
            {"num": "2", "tit": "Agregar", "sub": "IZSOL · AGREGA_ARTICULO_ITRAH", "pal": "orange", "items": [
                ("Qué va:", "Código de presentación (no el principal) y cantidad. Una línea por clic."),
                ("No pide:", "Lote del proveedor ni vencimiento: se completan al lotear."),
                ("Ojo:", "Hoy el procedimiento no valida cantidad ni bodega (hallazgo)."),
            ]},
            {"num": "3", "tit": "Lotear y aceptar", "sub": "ON_ACEPTA_TRANSITO → SPK_INSERTENTTRANSITO", "pal": "violet", "items": [
                ("Lotear:", "En Traer del Tránsito: lote del proveedor, vencimiento y cantidad por artículo."),
                ("Aceptar exige:", "Todo loteado o con causa; si nada está loteado no genera entrada."),
                ("Genera:", "Entrada IMOV en estado 0 con el tipo del tránsito y el proveedor como tercero. Tránsito → estado 1."),
            ]},
            {"num": "4", "tit": "Paciente y confirmar", "sub": "IZSOL · CONF_ENTRADA → SPK_CONFIRMARENTRADAS", "pal": "green", "items": [
                ("Cabecera:", "Información del Paciente: Buscar paciente llena ID y nombre (CNSTRAN)."),
                ("Exige:", "Paciente y estado 0. No pide costo ni factura."),
                ("Hace:", "Suma la existencia por unidad y reserva la aplicación pendiente del paciente."),
            ]},
            {"num": "5", "tit": "Acta", "sub": "IMOV_3 · RPT_ACTA_RECEPCION_CUSTODIA", "pal": "rose", "items": [
                ("Dónde:", "Clic derecho en el movimiento → Acta de Recepción de Custodia (solo tipo IDINVTPROPIA)."),
                ("Trae:", "Paciente, lotes, temperatura, cumple, aprobado y firma de quien confirmó."),
            ]},
        ],
        pills=[
            ("Regla", "Custodia = entrada propia: sin factura, sin costo obligatorio, sin cuenta por pagar."),
            ("Regla", "El paciente va en la entrada, no en el tránsito."),
            ("Regla", "Solo Confirmar da existencia."),
        ],
        accent="#0284c7",
    )

    sketch(
        "cus_masiva_sketchnote.jpg", B,
        "Recibir custodia por Excel",
        "Botón morado Ingresar Custodia → Subir Custodia Masivo (permiso Masivo_cus, bodega Es de Custodia)",
        [
            {"num": "1", "tit": "Plantilla", "sub": "11 columnas", "pal": "sky", "items": [
                ("Paciente:", "CEDULA (afiliado activo)."),
                ("Artículo:", "IDARTICULO = presentación (PRINCIPAL 0), activo, permitido en la bodega, con servicio."),
                ("Cantidades:", "CANTIDAD ≥ 1; CANTIDADREV entre 0 y CANTIDAD."),
                ("Proveedor y lote:", "TERCERO (NIT en TER), NOLOTEPEDIDO, FECHAVENCE YYYY-MM-DD, PCOSTO opcional."),
                ("Recepción:", "TEMPERATURA, CUMPLE, APROBADO → salen en el acta."),
            ]},
            {"num": "2", "tit": "Validar", "sub": "IZSOL · SUBIR_CUSTODIA_MASIVA", "pal": "orange", "items": [
                ("Todo o nada:", "Si falla una validación no se graba nada y la respuesta lista lo que falta."),
                ("Bodega:", "«La bodega seleccionada (…) no está configurada para custodia masiva.»"),
                ("Tránsito:", "«El consecutivo de custodia no existe.» / «La custodia ya está procesada o anulada.»"),
                ("Catálogos:", "NIT en TER, artículos activos no principales con servicio, pacientes activos, fechas válidas."),
            ]},
            {"num": "3", "tit": "Armar", "sub": "Un tránsito por proveedor · un movimiento por paciente", "pal": "violet", "items": [
                ("Tránsito:", "El primero reutiliza el abierto; los demás se clonan. Quedan loteados, estado 2."),
                ("Movimiento:", "Tipo IDINVTPROPIA, estado 0, paciente en CNSTRAN, TIPO_DOC_COMPRA N."),
                ("Unidad:", "Una línea de movimiento, una de tránsito y un lote interno con existencia cero."),
            ]},
            {"num": "4", "tit": "Confirmar", "sub": "IZSOL · CONF_ENTRADA", "pal": "green", "items": [
                ("Uno a uno:", "Cada movimiento queda en la lista de entradas en estado 0."),
                ("Hasta entonces:", "El informe lo muestra con existencia cero (no es error)."),
                ("Al confirmar:", "Suma la unidad y reserva la aplicación pendiente del paciente."),
            ]},
            {"num": "5", "tit": "Acta por proveedor", "sub": "IMOV_3 · RPT_ACTA_CUSTODIA_TERCERO_CONSOLIDADA", "pal": "rose", "items": [
                ("Filtros:", "Proveedor obligatorio; bodega, fechas y estado opcionales."),
                ("Si no hay:", "«No hay movimientos de custodia para el proveedor con los filtros actuales.»"),
            ]},
        ],
        pills=[
            ("Regla", "Una unidad = una línea = un lote interno."),
            ("Regla", "Nunca el artículo principal: siempre la presentación."),
            ("Ojo", "Subir el Excel no suma existencia."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "cus_despues_sketchnote.jpg", B,
        "Después de confirmar: aplicación, informe y actas",
        "Lo que el sistema hace solo y lo que la institución consulta",
        [
            {"num": "1", "tit": "Enlace automático", "sub": "IZSOL · CONF_ENTRADA", "pal": "sky", "items": [
                ("Busca:", "Líneas de aplicación PENDIENTE GESTION del mismo paciente, sin lote, con aplicación vigente."),
                ("Ruta 1:", "Requerimiento IEXIF pendiente de gestión o compra."),
                ("Ruta 2:", "Cita agendada sin requerimiento."),
                ("Ruta 3:", "Paciente + servicio directo."),
                ("Ruta 4:", "Cualquier lote de custodia del paciente, incluidas entradas anteriores."),
            ]},
            {"num": "2", "tit": "Resultado", "sub": "APLIMF RESERVADO · IEXIF RECEPCIONADO", "pal": "green", "items": [
                ("Línea:", "Queda con el lote (IDIEXI) que vence antes y el artículo físico."),
                ("Requerimiento:", "Pasa a RECEPCIONADO."),
                ("Regla:", "Un lote de custodia nunca se asigna a otro paciente."),
            ]},
            {"num": "3", "tit": "Aplicar", "sub": "Consulta externa → Aplicación de medicamentos", "pal": "orange", "items": [
                ("Variable:", "APLIM_USA_MEDCUSTOD muestra «Medicamento en Custodia» y el chip DE CUSTODIA."),
                ("Cita:", "Solo ofrece lotes de movimientos IDINVTPROPIA del paciente."),
                ("Sigue en:", "Libro de aplicación de medicamentos."),
            ]},
            {"num": "4", "tit": "Informe", "sub": "EXISTENCIA · EXPORTA_INFORME_CUSTODIA", "pal": "teal", "items": [
                ("Dónde:", "Existencias → pestaña Informe de Custodia; solo bodegas activas Es de Custodia."),
                ("Columnas:", "Paciente, medicamento, lote proveedor, lote interno, existencia, INVIMA, CUM, laboratorio, ingreso, vence."),
                ("Solo con existencia:", "Oculta lo consumido; sigue mostrando lo cargado y no confirmado."),
            ]},
            {"num": "5", "tit": "Estados", "sub": "ITRA · IMOV · IEXI", "pal": "slate", "items": [
                ("Tránsito:", "0 abierto · 1 aceptado (manual) · 2 loteado (masiva) · 3 anulado."),
                ("Movimiento:", "0 borrador · 1 confirmado · 2 anulado."),
                ("Lote:", "EXISLOTE 0 sin confirmar o consumido · 1 unidad disponible."),
            ]},
        ],
        pills=[
            ("Regla", "El lote es del paciente."),
            ("Regla", "Custodia no es compra: no hay CxP."),
            ("Ojo", "Sin servicio en el artículo no hay enlace: la masiva lo rechaza antes."),
        ],
        accent="#16a34a",
    )
    print("OK", IMG_DIR)


if __name__ == "__main__":
    main()
