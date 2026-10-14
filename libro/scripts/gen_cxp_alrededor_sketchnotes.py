# -*- coding: utf-8 -*-
"""Sketchnotes de lo que rodea al ciclo de Cuentas por pagar: notas, anticipos, Radian y auditoría.

Uso:  python libro/scripts/gen_cxp_alrededor_sketchnotes.py
Salida: libro/img/cxp_notas_sketchnote.jpg, cxp_anticipos_sketchnote.jpg,
        cxp_radian_sketchnote.jpg, cxp_auditoria_sketchnote.jpg

Contrastado 2026-10-04 con Qrystalos2 (CXPComponent.vue, ANTComponent.vue, FacturasRadianComponent.vue,
CxpFradianGenerarDialog.vue, AUDCXPComponent.vue, AUDCXPDComponent.vue, AUDCXPGComponent.vue,
CierreCXPComponent.vue) y con IXONLINE/SQL (SPQ_FCXPDBCR, SPK_CIERRA_FCXPDBCR, SPK_ANULAR_FCXPDBCR,
SPQ_NC_CONTAB_CXPFNT, SPQ_FNT_COL, SPQ_ANTICIPOS_COL, SPK_GEN_PROCESO_ANTICIPO, SPK_ANTICIPO_LEG_CXP,
SPK_NC_CONTAB_ANTICIPO, SPQ_TANT_COL, SPQ_FRADIAN, SPQ_FCXP, SPQ_FCXP_AUDIT, SPQ_ORDEN_PAGO, SPK_CIERRA_CARTERA).
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · ADMINISTRATIVO · CUENTAS POR PAGAR"


def main():
    sketch(
        "cxp_notas_sketchnote.jpg", B,
        "Notas débito y crédito sobre una factura contabilizada",
        "Fila de la factura → Notas DB / Notas CR → Nueva → Elegir Nota → Vlr. Bruto → Guardar → Contabilizar",
        [
            {"num": "1", "tit": "Catálogo de notas", "sub": "Conf. financiero → Tipos de nota (FNT)", "pal": "sky", "items": [
                ("Define:", "Código, descripción, tipo DB o CR, cuenta contable, comprobante, cruce de saldos y si afecta costo."),
                ("Regla:", "La nota hereda tipo y cuenta DB del catálogo; la cuenta CR es la cuenta por pagar de la factura."),
            ]},
            {"num": "2", "tit": "Nueva nota", "sub": "FCXP · CRUD_FCXPDBCR_2 (SPQ_FCXPDBCR)", "pal": "orange", "items": [
                ("Exige:", "Factura no anulada y con saldo mayor a cero."),
                ("Pide:", "Nota del catálogo, fecha, Vlr. Bruto, observación, centro de costo."),
                ("Opciones:", "Impuestos? (devuelve retenciones en proporción), Afecta IVA (% IVA), Saldo completo (solo DB), Masivo por ítem."),
                ("Especiales:", "Genera CxP? traslada el valor a una CxP nueva de otro tercero; Cambio tercero? solo marca."),
            ]},
            {"num": "3", "tit": "Contabilizar", "sub": "CONTABILIZAR_NOTACREDITO → SPQ_NC_CONTAB_CXPFNT", "pal": "violet", "items": [
                ("Exige:", "Factura contabilizada; nota sin comprobante; una DB no deja el saldo bajo cero."),
                ("Hace:", "Comprobante propio de la nota (procedencia NOTDBCRCXP) y recalcula la factura."),
                ("Saldo:", "La nota solo pesa en el saldo cuando está contabilizada y no anulada."),
            ]},
            {"num": "4", "tit": "DIAN y reversa", "sub": "ENVIARDIAN_NOTACREDITO · DESAPLICAR → SPK_ANULAR_FCXPDBCR", "pal": "green", "items": [
                ("Enviar DIAN:", "Solo notas DB contabilizadas de una factura que ya es documento equivalente aceptado."),
                ("Desaplicar:", "Anula o reversa el comprobante (según periodo) y la nota vuelve a pendiente."),
                ("Eliminar:", "Solo si nunca se contabilizó; las devoluciones de inventario no se borran."),
            ]},
        ],
        pills=[
            ("Regla", "DB baja el saldo, CR lo sube; ninguna se edita contabilizada."),
            ("Regla", "La devolución de compras crea su nota sola (procedencia INV)."),
            ("Ojo", "La glosa de auditoría es una nota DB de procedencia AUDT."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "cxp_anticipos_sketchnote.jpg", B,
        "Anticipos a proveedor: orden, caja y legalización",
        "Pestaña Anticipos → Nuevo → detalle → Cerrar → Enviar a Caja → (factura real) → Aplicar Anticipo",
        [
            {"num": "1", "tit": "Tipo de anticipo", "sub": "Conf. → Tipos de anticipo (TANT)", "pal": "sky", "items": [
                ("Define:", "Cuenta débito (anticipo entregado) y cuenta crédito (contrapartida) por tipo."),
                ("Variables:", "Caja donde cae el egreso del anticipo; tipo de CxP por defecto."),
            ]},
            {"num": "2", "tit": "Orden de anticipo", "sub": "ANTICIPOS_COL · CRUD_FCOM / CRUD_FCOMD / CERRAR_FCOM", "pal": "orange", "items": [
                ("Pide:", "Proveedor, bodega, tipo de anticipo, servicios del catálogo con cantidad y valor."),
                ("Cerrar:", "Solo con detalle; la orden pasa de abierta (C) a pendiente de caja (P)."),
            ]},
            {"num": "3", "tit": "Enviar a Caja", "sub": "ENVIAR_CAJA → SPK_GEN_PROCESO_ANTICIPO", "pal": "violet", "items": [
                ("Exige:", "Valor no mayor al total de la orden (sumando anticipos previos); sin egresos de la orden pendientes en caja."),
                ("Crea:", "CxP procedencia Anticipos (AN), orden de pago automática y egreso pendiente en la caja de anticipos."),
                ("Contable:", "Nada aún: el débito a la cuenta de anticipo sale al confirmar el egreso en caja."),
            ]},
            {"num": "4", "tit": "Aplicar Anticipo", "sub": "FCXP · TRAER_VALORES_ANTI → APLICAR_ANTICIPO → SPK_ANTICIPO_LEG_CXP", "pal": "green", "items": [
                ("Dónde:", "Fila de la factura real (procedencia Compras) → Aplicar Anticipo → elegir la orden."),
                ("Exige:", "Saldo de anticipo disponible; sin egresos del anticipo sin confirmar; valor no mayor al saldo de la factura."),
                ("Hace:", "Legalización (ANT en L); la factura baja su saldo; comprobante de legalización si la variable lo pide."),
                ("Anular:", "Anular Anticipo deshace la legalización si el periodo sigue abierto."),
            ]},
        ],
        pills=[
            ("Regla", "El anticipo se paga por caja como cualquier egreso."),
            ("Regla", "La factura real nace aparte; el anticipo se le aplica después."),
            ("Ojo", "El saldo disponible = anticipos pagados − legalizaciones."),
        ],
        accent="#b45309",
    )

    sketch(
        "cxp_radian_sketchnote.jpg", B,
        "Facturas electrónicas recibidas (Radian) → eventos → cuenta por pagar",
        "Pestaña Facturas Radian: bandeja → eventos DIAN → Generar CxP → Marcar las que ya tienen CxP",
        [
            {"num": "1", "tit": "Bandeja", "sub": "AppStore.read FRADIAN · SPQ_FRADIAN · ARCHIVOS", "pal": "sky", "items": [
                ("Llega:", "La factura electrónica del proveedor entra sola (correo/servicio): XML, PDF, NIT, número, monto, CUFE."),
                ("Filtros:", "Fechas, En CxP, Procesado, Evento, número, NIT, consecutivo CxP; refresco automático."),
                ("Ver:", "XML y PDF, línea de tiempo de eventos, solicitud y respuesta enviadas a la DIAN."),
            ]},
            {"num": "2", "tit": "Eventos DIAN", "sub": "FRADIAN · MATRIZ_EVENTOS / ADDEVENTO / REENCOLAR_EVENTO / DELEVENTO", "pal": "orange", "items": [
                ("Qué son:", "Acuse de recibo, recibo del bien o servicio, aceptación o reclamo, según la matriz configurada."),
                ("Exige:", "Permiso de nuevo evento y datos completos del usuario (nombres, apellidos, tipo y número de documento, departamento, cargo)."),
                ("Estados:", "Pendiente → Procesado o Error; el error se reencola; solo se borra lo no procesado."),
            ]},
            {"num": "3", "tit": "Generar CxP", "sub": "FCXP · VALIDA_TERCERO → diálogo → REGISTRAR_CXP_FRADIAN", "pal": "violet", "items": [
                ("Cuándo:", "Solo con el filtro de evento en acuse de recibo y desde la pestaña dentro de Cuentas por Pagar."),
                ("Pide:", "Tercero creado por NIT, cuenta crédito, centro de costo y cuenta de cada línea del XML."),
                ("Hace:", "Cabecera y detalle de la CxP ligados a la factura Radian; queda lista para impuestos y contabilizar."),
            ]},
            {"num": "4", "tit": "Marcar", "sub": "FCXP · CONCILIAR_CXP_FRADIAN", "pal": "green", "items": [
                ("Hace:", "Recorre el rango de fechas y marca las facturas Radian que ya tienen CxP (mismo NIT y número)."),
                ("Informa:", "Marcadas, ya marcadas y sin CxP; no crea nada."),
            ]},
        ],
        pills=[
            ("Regla", "Sin acuse de recibo no se genera la CxP desde Radian."),
            ("Regla", "La CxP generada sigue el ciclo normal: impuestos, contabilizar, orden, caja."),
            ("Ojo", "La homologación contable por proveedor aún no existe en SQL."),
        ],
        accent="#0f766e",
    )

    sketch(
        "cxp_auditoria_sketchnote.jpg", B,
        "Auditoría de facturas de servicios: glosa, conciliación y cierre",
        "Pestaña Auditoría → factura de Servicios contabilizada → Nueva Glosa → ítems → Cerrar Glosa → Levantar → Cerrar Conci",
        [
            {"num": "1", "tit": "Qué se audita", "sub": "AppStore.read FCXP (Servicios, contabilizada)", "pal": "sky", "items": [
                ("Alcance:", "Solo facturas de procedencia Servicios ya contabilizadas; filtro Auditado para ver las cerradas."),
                ("Sin glosa:", "Cerrar Sin Glosa marca la factura como auditada si no tiene ítems de glosa."),
            ]},
            {"num": "2", "tit": "Nueva Glosa", "sub": "FCXP · CRUD_FCXPDBCR (nota DB procedencia AUDT) + FCXP_AUDIT · CRUD_FCXPS", "pal": "orange", "items": [
                ("Crea:", "Una nota débito de auditoría y, debajo, ítems de glosa por paciente o documento con valor."),
                ("Regla:", "El valor de la nota = suma de los ítems glosados."),
            ]},
            {"num": "3", "tit": "Cerrar Glosa", "sub": "FCXP_AUDIT · CERRAR_GLOSA → CONTABILIZAR_NOTACREDITO", "pal": "violet", "items": [
                ("Hace:", "Ítems Nuevo → Glosa y contabiliza la nota débito: la factura baja su saldo."),
                ("Imprimir:", "Imp. Glosa saca el soporte para el proveedor."),
            ]},
            {"num": "4", "tit": "Levantar y conciliar", "sub": "Levantar (nota CR) · CERRAR_CONCI", "pal": "green", "items": [
                ("Levantar:", "El proveedor responde; lo aceptado se levanta con valor levantado y nota crédito."),
                ("Cerrar Conci:", "Ítems Glosa → Conci; Imp. Conci imprime el acta."),
                ("Reversa:", "Desaplicar la nota devuelve los ítems a Nuevo."),
            ]},
        ],
        pills=[
            ("Regla", "La glosa es contable: baja la cuenta por pagar vía nota DB."),
            ("Regla", "Auditada = sin glosas pendientes o cerrada sin glosa."),
            ("Ojo", "Reliquidar cxp no tiene procedimiento detrás hoy."),
        ],
        accent="#be123c",
    )
    print("ok", IMG_DIR)


if __name__ == "__main__":
    main()
