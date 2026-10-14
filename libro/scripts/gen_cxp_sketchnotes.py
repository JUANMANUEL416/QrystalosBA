# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas) del libro Cuentas por pagar (FCXP).

Uso:  python libro/scripts/gen_cxp_sketchnotes.py
Salida: libro/img/cxp_*_sketchnote.jpg

Contenido contrastado 2026-10-04 con Qrystalos2 (pages/administrativo/CuentasxpagarPage.vue,
components/administrativo/CXP/CXPComponent.vue, OPComponent.vue, OPPagoEgresosDialog.vue,
components/administrativo/Caja/CAJMovinComponent.vue) y los SP de IXONLINE/SQL (SPQ_FCXP, SPQ_ORDEN_PAGO,
SPQ_CONF_CAJA, SPK_CONFIRMAR_PAGOSMASIVO, SPK_CIERRERECIBO_CAJA, SPK_NC_CONTAB_CAJA_EGR,
SPK_MARCA_OP_PAGADA_POR_EGRESO, SPK_CALCULOVALORESCXP).
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · ADMINISTRATIVO · CUENTAS POR PAGAR"


def main():
    sketch(
        "cxp_registro_sketchnote.jpg", B,
        "Registrar y contabilizar la factura",
        "Administrativo → Cuentas por Pagar → pestaña Cuentas por Pagar. Cabecera, detalle, impuestos y el icono Contabilizar",
        [
            {"num": "1", "tit": "Nueva CXP", "sub": "FCXP · CRUD_FCXP", "pal": "sky", "items": [
                ("Pide:", "Tercero (trae la fecha de vencimiento), fecha, fecha factura, referencia, procedencia, cuenta crédito."),
                ("Rechaza si:", "Referencia repetida para ese proveedor; periodo contable cerrado; mes de CxP cerrado."),
                ("Presupuesto:", "Con PRESUP_CXP_ACTIVADO=SI exige el registro presupuestal."),
                ("Restricción:", "RESTRIN_CREA_CXP impide otra factura mientras haya una sin detalle."),
            ]},
            {"num": "2", "tit": "Detalle", "sub": "FCXPD · CRUD_FCXPD → RECALCULAR_FCXP", "pal": "orange", "items": [
                ("Qué va:", "Concepto o servicio, cantidad, valor, IVA, descuento, centro de costo, área, cuenta."),
                ("Hace:", "Cada línea recalcula valor neto y saldo de la factura."),
                ("Compras:", "La entrada de inventario ya trae el detalle; solo se revisa."),
            ]},
            {"num": "3", "tit": "Impuestos", "sub": "FCXPI · CRUD_FCXPI", "pal": "violet", "items": [
                ("Qué va:", "Retención en la fuente, ICA, IVA asumido, prestablecidos del proveedor."),
                ("Efecto:", "Bajan el neto a pagar; salen en el comprobante de egreso."),
            ]},
            {"num": "4", "tit": "Contabilizar", "sub": "VALIDAR_FCXP → CONTABILIZAR_FCXP → SPK_NC_CONTAB_CXP", "pal": "green", "items": [
                ("Dónde:", "Icono de la columna Conta (o Generales → Contabilizar masivo)."),
                ("Valida:", "Tiene detalle; cuenta tipo detalle; cuentas en el plan; IVA en el detalle si CUENTA_IVA_CXP=SI."),
                ("No aplica:", "Nómina y caja menor no se contabilizan desde aquí."),
                ("Deshacer:", "Mismo icono; bloqueado con abonos, órdenes, notas o DIAN."),
            ]},
            {"num": "5", "tit": "Lista para pagar", "sub": "ESTADO N · CONTABILIZADA 1", "pal": "rose", "items": [
                ("Aparece en:", "Nuevo Detalle de la orden de pago y botón Pagar en la fila."),
                ("Saldo:", "Valor neto; baja con cada abono autorizado."),
            ]},
        ],
        pills=[
            ("Regla", "Sin contabilizar no hay orden de pago."),
            ("Regla", "Corregir una factura contabilizada = nota débito / crédito."),
            ("Ojo", "La CxP de Compras nace sola al confirmar la entrada."),
        ],
        accent="#0284c7",
    )

    sketch(
        "cxp_orden_sketchnote.jpg", B,
        "Orden de pago: agrupar, abonar y autorizar",
        "Administrativo → Órdenes de pago (o pestaña Orden de pago). Nuevo → Nuevo Detalle → Autorizar → egresos en caja",
        [
            {"num": "1", "tit": "Nuevo", "sub": "FCXPPM · CRUD_FCXPPM", "pal": "sky", "items": [
                ("Pide:", "Fecha, caja que pagará, observación, tercero a favor (opcional), forma de pago."),
                ("Valida:", "Sede del equipo o del usuario; periodo contable abierto."),
                ("Nace en:", "N (No Confirmado)."),
            ]},
            {"num": "2", "tit": "Nuevo Detalle", "sub": "LISTAR_CXP_PENDIENTES → PAGO_TOTAL / PAGO_PARCIAL", "pal": "orange", "items": [
                ("Lista:", "Facturas con saldo, contabilizadas, estado N o C; filtros tercero, vencidas, procedencia, concepto."),
                ("Pago total:", "Todo el saldo. Pago parcial: porcentaje o valor (abono > 0 y ≤ saldo)."),
                ("Valida:", "Presupuesto confirmado; fecha de la orden ≥ fecha del documento; comprobante real si BD_HISTORICAS."),
                ("Crea:", "Abono FCXPP con saldo anterior, abono y saldo nuevo."),
            ]},
            {"num": "3", "tit": "Atajo Pagar", "sub": "CXPComponent → PAGO_CXPTOTAL / PAGO_PARCIAL", "pal": "violet", "items": [
                ("Dónde:", "Botón Pagar en la fila de la factura (contabilizada, con saldo)."),
                ("Total:", "Crea la orden y la autoriza en el acto (modo clásico)."),
                ("Parcial:", "Crea la orden e intenta el modo individual; si no está activo, pide autorizar desde Órdenes de pago."),
            ]},
            {"num": "4", "tit": "Autorizar", "sub": "AUTORIZAR · AUTORIZAR_INDIVIDUAL_TER · AUTORIZAR_INDIVIDUAL", "pal": "green", "items": [
                ("Clásico:", "Un recibo de egreso por proveedor (procedencia CAJA), una línea por abono; el cajero pone la forma de pago."),
                ("Individual:", "AUT_EGRE_INDIVIDUAL=SI. Un recibo por proveedor con la forma de pago de la orden; exige IDCJTECXP, concepto y caja abierta."),
                ("Sin autorizar:", "PERMITE_EGR_SIN_C=SI. Cerrar Orden envía a caja; la orden sigue en N «Pendiente confirmar en caja»."),
                ("Plano dinámico:", "BANC_DINA_ARCH_PLANO=SI. Egresos ya confirmados; orden en P."),
            ]},
            {"num": "5", "tit": "Después", "sub": "DESAUTORIZAR · CERRAR_ORDEN · Archivo Plano", "pal": "rose", "items": [
                ("Desautorizar:", "Solo si ningún egreso está confirmado en caja; anula recibos y devuelve abonos."),
                ("Cerrar Orden:", "Bloquea nuevos detalles y habilita Archivo Plano para el banco."),
                ("Cruce con CxC:", "Compensa saldos a favor del mismo tercero."),
            ]},
        ],
        pills=[
            ("Regla", "Autorizar no paga: crea el recibo pendiente en la caja de la orden."),
            ("Regla", "Sin caja en la orden no hay egreso."),
            ("Ojo", "El modo lo deciden las variables, no el usuario."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "cxp_caja_sketchnote.jpg", B,
        "Pago en caja: forma de pago, confirmar y comprobante",
        "Administrativo → Caja → Mov. Egreso. También Confirmar orden de pago (caja) y Realizar Pago (orden)",
        [
            {"num": "1", "tit": "Caja abierta", "sub": "CONF_CAJA · ABRIR_CAJA · TRAER_COMPROBANTE", "pal": "sky", "items": [
                ("Exige:", "Equipo configurado como caja, cajero con turno para el horario, caja abierta una sola vez."),
                ("Mov. Egreso:", "Lista los recibos de egreso pendientes (clase PAGO, tipo de egreso de pago a proveedores)."),
            ]},
            {"num": "2", "tit": "Forma de pago", "sub": "PCJ · VALIDA_INSERT_FPA_EGRESO · CRUDFPA_EGRESO", "pal": "orange", "items": [
                ("Qué va:", "Efectivo, cheque (chequera y número), transferencia (banco, cuenta), documento y autorización."),
                ("Regla:", "La suma de las formas de pago es igual al valor del recibo."),
                ("Individual:", "Ya viene de la orden; el cajero solo confirma."),
            ]},
            {"num": "3", "tit": "Confirmar", "sub": "CONF_CAJA · CONFIRMAR_RECIBO_EGRESO", "pal": "violet", "items": [
                ("Valida:", "Detalle de pago cuadra; fecha no futura; periodo abierto; no cerrado / anulado / desechado; valor > 0."),
                ("Cierre:", "SPK_CIERRERECIBO_CAJA: abono → P, factura recalculada (saldo y estado), orden → P."),
                ("Asiento:", "SPK_NC_CONTAB_CAJA_EGR: débito cuenta por pagar por factura, crédito forma de pago; recibo CERRADA 1."),
                ("Individual:", "SPK_MARCA_OP_PAGADA_POR_EGRESO marca abono y orden por el número de orden."),
            ]},
            {"num": "4", "tit": "Atajos", "sub": "CONSULTAR_ORDEN_CAJA · CONFIRMAR_EGRESOS_MASIVO_OP · Realizar Pago", "pal": "green", "items": [
                ("Desde caja:", "Confirmar orden de pago: consulta la orden, muestra Pendiente / Confirmado / Anulado y confirma todos; la orden queda autorizada y pagada."),
                ("Desde la orden:", "Realizar Pago recorre cada egreso, pide tipo de pago y lo confirma; exige sesión de caja abierta."),
                ("Solo con:", "PERMITE_EGR_SIN_C y AUT_EGRE_INDIVIDUAL en SI."),
            ]},
            {"num": "5", "tit": "Estados", "sub": "FCXP · FCXPPM · FCXPP · FCJ", "pal": "slate", "items": [
                ("Factura:", "N sin abonos · C con abonos y saldo · P pagada · A anulada."),
                ("Orden:", "N No Confirmado · C Confirmado (egresos en caja) · P Pagado · A Anulado."),
                ("Abono:", "N programado · C autorizado · P pagado · A anulado."),
                ("Recibo:", "Pendiente (CERRADA 0) · Confirmado (CERRADA 1) · Anulado · Desechado."),
            ]},
        ],
        pills=[
            ("Regla", "Confirmar en caja es el único paso que paga."),
            ("Regla", "Para deshacer un pago: anular el recibo en caja (desautoriza la orden)."),
            ("Ojo", "Comp. Egreso imprime el comprobante del pago."),
        ],
        accent="#16a34a",
    )

    sketch(
        "cxp_plano_sketchnote.jpg", B,
        "Archivo plano para el banco (dispersión de pagos)",
        "Administrativo → Órdenes de pago → orden cerrada y No Confirmada → botón Archivo Plano → Banco de Bogotá / Colpatria",
        [
            {"num": "1", "tit": "Antes", "sub": "Requisitos de configuración", "pal": "sky", "items": [
                ("Cuenta propia:", "La cuenta bancaria (Bancos → BCT) debe estar Activa y tener el tipo de plano del banco (BANCO_BOGOTA o COLPATRIA)."),
                ("Proveedor:", "Tercero con banco, tipo de cuenta (Corriente / Ahorros) y número de cuenta bancaria."),
                ("Banco destino:", "El catálogo de bancos lleva el código ACH de cada banco."),
                ("Empresa:", "NIT, dígito de verificación y tipo de identificación del tercero instalado."),
            ]},
            {"num": "2", "tit": "Orden lista", "sub": "FCXPPM · CERRAR_ORDEN", "pal": "orange", "items": [
                ("Cuándo:", "Orden con sus abonos y cerrada (Cerrar Orden), todavía No Confirmada."),
                ("Botón:", "Archivo Plano aparece en la fila de la orden solo en ese estado."),
                ("Opciones:", "Plano Banco Bogotá · Plano Banco Colpatria · Plano Bancolombia."),
            ]},
            {"num": "3", "tit": "Parámetros", "sub": "Diálogo Plano Banco", "pal": "violet", "items": [
                ("Pide:", "Cuenta desde la cual se paga, tipo de transacción (Nómina / Proveedores / …) y código de oficina."),
                ("Colpatria:", "Además la clave asignada por el banco."),
                ("Trae:", "GET_INF_PLANO: cabecera de la empresa y una línea por abono de la orden."),
            ]},
            {"num": "4", "tit": "Archivo", "sub": "Se arma en la pantalla y se descarga .txt", "pal": "green", "items": [
                ("Cabecera:", "Fecha, cuenta de la empresa, NIT, tipo de movimiento, oficina."),
                ("Detalle:", "Por abono: tipo y número de identificación, razón social, tipo y número de cuenta, valor, código ACH."),
                ("Nombre:", "Plano_BB_<orden>_<fecha>.txt o Plano_colpatria_<orden>_<fecha>.txt."),
            ]},
            {"num": "5", "tit": "Después", "sub": "Lo que el archivo NO hace", "pal": "rose", "items": [
                ("No paga:", "Generar el plano no cambia la orden ni los abonos; el pago se confirma en caja."),
                ("Banco:", "El archivo se sube en el portal del banco por fuera de Qrystalos."),
                ("Rastro:", "No queda registro del archivo generado (ver hallazgos)."),
            ]},
        ],
        pills=[
            ("Regla", "Cerrar la orden antes de generar el plano."),
            ("Regla", "Un plano por orden; si cambia la orden, generar de nuevo."),
            ("Ojo", "Sin cuenta bancaria del proveedor la línea sale vacía."),
        ],
        accent="#b45309",
    )
    print("OK", IMG_DIR)


if __name__ == "__main__":
    main()
