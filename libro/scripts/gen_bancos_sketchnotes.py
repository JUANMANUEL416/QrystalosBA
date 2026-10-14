# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del capítulo Tesorería · Bancos.

Uso:  python libro/scripts/gen_bancos_sketchnotes.py
Salida: libro/img/bancos_*_sketchnote.jpg (reutiliza el motor de gen_recaudos_sketchnotes).

Contenido contrastado 2026-10-03 con Qrystalos2 (CuentasPage, tesoreria/BCTComponent, BMOVComponent,
BCTCComponent, BCTDComponent, BCTTARComponent, conf/financiero/OFINComponent, financiero/BCOComponent,
Contable/CONCBMOVComponent, OMBancosComponent, AuxiliarBancosComponent) e IXONLINE/SQL SPQ_BMOV (19 METODO),
SPQ_BCTC (18), SPQ_BCTD, SPQ_BANCOS_AUXILIAR, SPK_OK_BMOV, SPK_DESOK_BMOV, SPK_UPSERT_BCTSM,
SPK_CAMBIA_BCT_PCJ_CAJA (PREVERSION idéntica a la liberada 2.0.7).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND = "QRYSTALOS IPS · TESORERÍA · BANCOS"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. Qué es Bancos y qué no es
    sketch(
        "bancos_que_es_sketchnote.jpg", BRAND,
        "Qué es Tesorería · Bancos y qué no es",
        "El libro de cada cuenta bancaria: lo que entra, lo que sale y cuánto queda; y cómo eso llega a cartera y contabilidad",
        [
            {"num": "1", "tit": "La cuenta", "sub": "Tarjeta BCT", "pal": "sky", "items": [
                ("Qué es:", "Una cuenta real de la IPS en un banco: banco + sucursal + número. Tiene tipo (ahorros, corriente, tarjeta de crédito), cuenta contable y saldo."),
                ("Dónde vive:", "Administrativo → Tesorería → Cuentas. Cada cuenta es una tarjeta; al tocarla se abre su libro de movimientos."),
                ("Saldo:", "Lo calcula el sistema: suma de débitos confirmados menos créditos confirmados. Reliquidar lo vuelve a sumar."),
                ("Tarjeta de crédito:", "Si el tipo es TC muestra cupo y disponible, y habilita Cuotas TC."),
            ]},
            {"num": "2", "tit": "El movimiento", "sub": "BMOV + renglones", "pal": "orange", "items": [
                ("Cabecera:", "Fecha, operación (qué tipo de entrada o salida), descripción, valor total."),
                ("Renglones:", "Uno por tercero: forma de pago, documento, valor, tercero. El total de la cabecera es la suma."),
                ("Operación:", "Define si es débito o crédito, qué cuenta contable toca y si es recaudo, nómina, traslado o genera CxP."),
                ("Vida:", "Pendiente → Confirmado (Ok) → puede desconfirmarse; o Anulado si nunca se confirmó."),
            ]},
            {"num": "3", "tit": "Lo que sale", "sub": "Al confirmar", "pal": "green", "items": [
                ("Saldo:", "La cuenta actualiza su saldo en el momento de confirmar."),
                ("Contabilidad:", "Si el movimiento nació en Bancos o Contabilidad genera su comprobante contable automáticamente."),
                ("Cartera:", "Si la operación es Recaudo, los renglones quedan disponibles para legalizar en Cartera · Recaudos."),
                ("Traslado:", "Si la operación es de traslado, el sistema crea el movimiento espejo en la cuenta destino."),
            ]},
            {"num": "NO ES", "tit": "Lo que no es", "sub": "Evite el camino equivocado", "pal": "rose", "items": [
                ("Caja:", "Los recibos de caja llegan a la cuenta con procedencia Caja; se confirman desde Caja, no aquí."),
                ("Pagar proveedores:", "El cheque o transferencia a un proveedor sale de Cuentas por Pagar; aquí solo se ve el movimiento."),
                ("Conciliar glosas:", "Conciliación de cartera con la EPS es Administrativo → Concilia, otro módulo."),
                ("Auxiliar contable:", "El libro contable de la cuenta está en Contabilidad → Auxiliar de bancos."),
            ]},
        ],
        pills=[
            ("Una operación por movimiento", "La operación financiera (catálogo OFIN) manda: tipo DB/CR, cuenta contable, recaudo, nómina, CxP y traslado."),
            ("Confirmar = saldo + asiento", "Solo los movimientos confirmados (Ok) suman al saldo y generan comprobante. Pendiente no cuenta."),
            ("Procedencia dice de dónde vino", "BANCOS: digitado aquí. CAJA: nació en un recibo. CONTAB: lo creó contabilidad. Cada una se corrige en su origen."),
            ("Periodo contable abierto", "Guardar y confirmar exigen que el mes de la fecha esté abierto en PRI. Cerrado → no deja."),
        ],
        accent="#0284c7",
    )

    # 2. Configuración previa
    sketch(
        "bancos_config_sketchnote.jpg", BRAND,
        "Antes de registrar: banco, sucursal, cuenta y operación",
        "Cuatro catálogos en orden. Sin el anterior no existe el siguiente",
        [
            {"num": "1", "tit": "Banco y sucursal", "sub": "Configuración → Financiero → Bancos", "pal": "sky", "items": [
                ("Banco:", "Código, descripción, código ACH y tercero. El tercero no puede repetirse entre bancos."),
                ("Sucursal:", "Cada banco tiene sucursales (código, nombre, dirección, teléfonos, contacto). Expanda el banco para verlas."),
                ("Borrar banco:", "Solo si no tiene sucursales. No revisa si hay cuentas que lo usan."),
                ("Variable:", "TERCATBANCO filtra qué categoría de tercero aparece al escoger el tercero del banco."),
            ]},
            {"num": "2", "tit": "Cuenta bancaria", "sub": "Tesorería → Cuentas → Nueva Cuenta", "pal": "orange", "items": [
                ("Obligatorios:", "Banco, sucursal, tipo de cuenta (catálogo TIPOCUENTABCT), número (6-40 dígitos), fecha apertura, cuenta contable."),
                ("Cuenta contable:", "Solo cuentas activas de detalle de clase 1 (activo). Es la que recibe los asientos."),
                ("Formatos:", "Formato de pago (01-04), tamaño de cheque (01-05), tipo de archivo plano (Bogotá, Colpatria, Bancolombia), ID formato."),
                ("Tarjeta crédito:", "Tipo TC → se pide el cupo disponible y la tarjeta trabaja con cupo en vez de saldo."),
            ]},
            {"num": "3", "tit": "Operación financiera", "sub": "Configuración → Financiero → Oper. financieras", "pal": "violet", "items": [
                ("Identidad:", "ID, descripción, tipo DB o CR, comprobante contable y cuenta contable de contrapartida."),
                ("Banderas:", "Recaudo (alimenta Cartera), Genera CxP, Pide centro de costo, Recaudo a nómina, Es de traslado."),
                ("Traslado:", "Si es de traslado se indica la cuenta bancaria destino: al confirmar se crea el espejo."),
                ("Cuidado:", "Eliminar no revisa movimientos que la usen; el botón está oculto en pantalla."),
            ]},
            {"num": "4", "tit": "Periodo y formas de pago", "sub": "Contabilidad / Caja", "pal": "green", "items": [
                ("Periodo PRI:", "El mes de la fecha del movimiento debe existir y estar abierto. Si no: «Periodo contable cerrado»."),
                ("Forma de pago FPA:", "Cada renglón lleva forma de pago (efectivo, cheque, transferencia…). Viene del catálogo de Caja."),
                ("Operaciones BCTC:", "Catálogo propio para las partidas de la conciliación bancaria (botón Operaciones)."),
                ("Sede:", "Las cuentas pueden asociarse a una sede (Perú también pide CCI y tipo operativa/recaudadora/detracción)."),
            ]},
        ],
        pills=[
            ("Orden", "Banco → Sucursal → Cuenta → Operación. Después, periodo abierto."),
            ("No se borra lo usado", "Cuenta con movimientos no se elimina. Banco con sucursales tampoco. Operación: el botón de borrar no está visible."),
            ("La cuenta contable manda", "El asiento automático debita o acredita la cuenta contable de la tarjeta BCT contra la cuenta de la operación."),
        ],
        accent="#ea580c",
    )

    # 3. La pantalla Cuentas
    sketch(
        "bancos_cuentas_sketchnote.jpg", BRAND,
        "La pantalla Cuentas: tarjetas y acciones por cuenta",
        "Toque una tarjeta y aparece la barra de acciones y el libro de movimientos de esa cuenta",
        [
            {"num": "A", "tit": "Arriba", "sub": "Filtros y reportes", "pal": "sky", "items": [
                ("Nueva Cuenta:", "Abre el formulario de alta de la cuenta bancaria."),
                ("Estado / Banco:", "Filtra las tarjetas: Activa o Inactiva, y por banco."),
                ("Reportes bancarios:", "Listado de movimientos de varias cuentas a la vez por rango de fechas; PDF y Excel."),
            ]},
            {"num": "B", "tit": "Acciones de la cuenta", "sub": "Barra sobre el libro", "pal": "orange", "items": [
                ("Editar:", "Cambia datos de la cuenta (no el saldo)."),
                ("Consignaciones:", "Informe de consignaciones por tercero: todas, legalizadas o no legalizadas; PDF o Excel."),
                ("Imprimir:", "Listado de movimientos de esta cuenta con los filtros actuales."),
                ("Reliquidar:", "Recalcula el saldo sumando de nuevo los movimientos confirmados."),
            ]},
            {"num": "C", "tit": "Ventanas", "sub": "Diálogos a pantalla completa", "pal": "violet", "items": [
                ("Conciliación:", "Conciliación bancaria de la cuenta: actas por fecha de corte y auxiliar de saldos por mes."),
                ("Documentos:", "Control de chequeras y documentos: generar, entregar, anular, liberar."),
                ("Cuotas TC:", "Solo tarjeta de crédito: cuotas por mes, cuentas contables y generar la CxP del mes."),
            ]},
            {"num": "D", "tit": "El libro", "sub": "Movimientos de la cuenta", "pal": "green", "items": [
                ("Filtros:", "Fecha inicial y final (hoy por defecto), estado, tipo DB/CR, procedencia, tercero."),
                ("Nuevo:", "Crea un movimiento con procedencia Bancos."),
                ("Fila:", "Lápiz = editar, ✓ = confirmar, ⊘ = anular, ↺ = desconfirmar. Expandir muestra los renglones."),
                ("Generar Cxp:", "Aparece si la operación marca Genera CxP y el movimiento está confirmado."),
            ]},
        ],
        pills=[
            ("Hoy por defecto", "El libro abre filtrado a la fecha de hoy. Si no ve un movimiento, amplíe el rango de fechas."),
            ("Una cuenta a la vez", "Al seleccionar una tarjeta las demás se ocultan. «Ver todas las cuentas» regresa a la grilla."),
            ("Permiso de pantalla", "Entrar exige la ruta Administrativo → Tesorería → Cuentas. Los botones no tienen permiso propio, salvo Cambiar cuenta."),
        ],
        accent="#7c3aed",
    )

    # 4. Registrar un movimiento
    sketch(
        "bancos_movimiento_sketchnote.jpg", BRAND,
        "Registrar un movimiento: cabecera, renglones, confirmar",
        "Tres pasos. Hasta confirmar no suma al saldo ni toca contabilidad",
        [
            {"num": "1", "tit": "Cabecera", "sub": "Botón Nuevo", "pal": "sky", "items": [
                ("Fecha:", "Fecha del movimiento y fecha contable. El mes debe estar abierto."),
                ("Operación:", "Seleccionar operación: trae tipo DB/CR, cuenta contable y banderas (Recaudo, Nómina, Centro de costo)."),
                ("Descripción:", "Texto libre que viaja al comprobante."),
                ("Genera Cxp:", "Casilla que hereda de la operación; puede cambiarse por movimiento."),
            ]},
            {"num": "2", "tit": "Renglones", "sub": "Botón Nuevo en el detalle", "pal": "orange", "items": [
                ("Forma de pago:", "Efectivo, cheque, transferencia… Si es cheque pide el banco del documento."),
                ("Valor y documento:", "Valor del renglón y número de documento (cheque, consignación)."),
                ("Tercero:", "Quién consignó o a quién se pagó. Trae su cuenta contable (tercero contable)."),
                ("Recaudo / Nómina:", "Marcas que heredan de la operación; si Recaudo, el renglón será legalizable en Cartera."),
            ]},
            {"num": "3", "tit": "Confirmar", "sub": "✓ en la fila", "pal": "green", "items": [
                ("Exige:", "Al menos un renglón. Mes abierto. No estar ya confirmado."),
                ("Hace:", "Estado Ok, recalcula saldo de la cuenta y genera el comprobante contable si la procedencia es Bancos o Contabilidad."),
                ("Traslado:", "Si la operación es de traslado, clona el movimiento en la cuenta destino y recalcula su saldo."),
                ("Comprobante:", "El botón Comprobante abre el asiento generado."),
            ]},
            {"num": "4", "tit": "Después", "sub": "Lo que se puede hacer", "pal": "violet", "items": [
                ("Generar Cxp:", "Convierte el movimiento confirmado en una cuenta por pagar (una sola vez)."),
                ("Cambiar tercero:", "En un renglón, si el movimiento está confirmado y contabilizado; ajusta el comprobante."),
                ("Desconfirmar:", "Vuelve a Pendiente si ningún renglón está en Recaudos."),
                ("Imprimir:", "Listado de movimientos con los filtros vigentes."),
            ]},
        ],
        pills=[
            ("Solo Pendiente se edita", "Cabecera y renglones se cambian o borran mientras el estado sea P. Confirmado no."),
            ("El total es la suma", "El valor de la cabecera se recalcula con cada renglón que se agrega, edita o elimina."),
            ("Un renglón, un tercero", "Una consignación de varios pagadores se separa en renglones; así cada uno se legaliza aparte."),
            ("Anular solo Pendiente", "Anular pide razón y queda registrado. Si ya está confirmado, primero desconfirmar."),
        ],
        accent="#16a34a",
    )

    # 5. Corregir
    sketch(
        "bancos_corregir_sketchnote.jpg", BRAND,
        "Corregir: desconfirmar, anular, cambiar tercero, cambiar cuenta",
        "Cada corrección tiene su condición. Si el renglón ya está en Recaudos, primero deshacer allá",
        [
            {"num": "1", "tit": "Desconfirmar", "sub": "↺ solo procedencia Bancos", "pal": "orange", "items": [
                ("Bloquea si:", "Algún renglón ya está en un recaudo de cartera (ENPAGOS). Mensaje: «ya se encuentra en pagos en cartera»."),
                ("Avisa si:", "El mes del movimiento está cerrado: pregunta, porque no podrá volver a confirmar en esa fecha."),
                ("Hace:", "Reversa el comprobante (o lo anula si el periodo está cerrado), vuelve a Pendiente y recalcula saldo."),
                ("CxP:", "Si generó cuenta por pagar y esa CxP ya se contabilizó, no desconfirma."),
            ]},
            {"num": "2", "tit": "Anular", "sub": "⊘ solo Pendiente", "pal": "rose", "items": [
                ("Condición:", "Procedencia Bancos y estado Pendiente. Un confirmado no se anula: se desconfirma primero."),
                ("Pide:", "Razón de anulación; guarda usuario, equipo y fecha."),
                ("Resultado:", "Estado A. Se ve con el filtro Estado = Anulados."),
            ]},
            {"num": "3", "tit": "Cambiar tercero", "sub": "En el renglón", "pal": "violet", "items": [
                ("Cuándo:", "Movimiento Bancos, confirmado y contabilizado: el tercero se equivocó pero el dinero es correcto."),
                ("Hace:", "Actualiza tercero, documento y cuenta en el renglón y corrige el tercero en el comprobante contable."),
                ("No hace:", "No cambia valores ni fecha. Para eso: desconfirmar, editar, confirmar."),
            ]},
            {"num": "4", "tit": "Cambiar cuenta", "sub": "Solo procedencia Caja", "pal": "sky", "items": [
                ("Cuándo:", "Un recibo de caja se consignó en la cuenta equivocada. Requiere el permiso CAMBIAR_CTA_BMOV_CAJA."),
                ("Hace:", "Anula el movimiento en la cuenta actual, lo crea y confirma en la destino, actualiza el recibo (PCJ/FCJ) y regenera el comprobante."),
                ("Rastro:", "Queda en el log de usuario (USLOG) con valores anterior y nuevo."),
            ]},
        ],
        pills=[
            ("Primero cartera", "Si el renglón ya está legalizado en Recaudos, desaplique el recaudo antes de desconfirmar aquí."),
            ("Caja se corrige en Caja", "Los movimientos de procedencia Caja no se editan ni desconfirman aquí; solo Cambiar cuenta con permiso."),
            ("Reliquidar no corrige movimientos", "Solo vuelve a sumar los confirmados. Úselo si el saldo de la tarjeta no cuadra con el libro."),
        ],
        accent="#dc2626",
    )

    # 6. Recaudos y consignaciones
    sketch(
        "bancos_recaudos_sketchnote.jpg", BRAND,
        "Consignaciones y Recaudos de cartera: legalizar",
        "Un renglón marcado Recaudo espera a que Cartera lo aplique a facturas. Hasta entonces está «por legalizar»",
        [
            {"num": "1", "tit": "Consignación", "sub": "Movimiento con operación Recaudo", "pal": "sky", "items": [
                ("Operación:", "La operación financiera tiene marcada «Recaudo?». Al escogerla, los renglones heredan la marca."),
                ("Renglón:", "Tercero que consignó (la EPS), valor, documento. Un renglón por pagador."),
                ("Confirmar:", "Solo los movimientos confirmados (Ok) aparecen en Cartera · Recaudos."),
            ]},
            {"num": "2", "tit": "En Recaudos", "sub": "Ingreso = Bancos", "pal": "green", "items": [
                ("Buscar:", "Cartera lista los renglones del tercero con Recaudo, confirmados, sin recaudo enlazado y con saldo por legalizar."),
                ("Enlazar:", "Al crear el recaudo el renglón queda ENPAGOS = 1 y ya no vuelve a salir en la búsqueda."),
                ("Aplicar:", "Al aplicar el recaudo a facturas se suma el valor legalizado del renglón."),
            ]},
            {"num": "3", "tit": "Seguimiento", "sub": "Botón Consignaciones", "pal": "orange", "items": [
                ("Informe:", "Por tercero o todos; Todas / Legalizadas / No legalizadas; rango de fechas opcional."),
                ("Columnas:", "Valor consignado, valor legalizado, por legalizar, caja-recibo, recaudo, procedencia."),
                ("Salida:", "PDF «Listado de consignaciones en banco» o Excel con el detalle."),
                ("También:", "Cartera → Consultas y Reportes → Recaudos en bancos → Estado = Pendientes."),
            ]},
            {"num": "4", "tit": "Casos", "sub": "Lo que suele pasar", "pal": "violet", "items": [
                ("Consignó otro:", "El tercero del renglón no es quien debe: Cambiar tercero (si está contabilizado) o desconfirmar y editar."),
                ("Un pago, varias EPS:", "Distribuir el renglón en varios terceros (Distribuye ADRES, Perú) o separar en renglones antes de confirmar."),
                ("No aparece en Recaudos:", "Revise: ¿operación con Recaudo? ¿confirmado? ¿ya tiene ENPAGOS? ¿saldo por legalizar > 0?"),
            ]},
        ],
        pills=[
            ("Legalizar = aplicar en Cartera", "Bancos registra el dinero; Cartera dice a qué facturas corresponde. El renglón guarda cuánto se legalizó."),
            ("Enlazado no se desconfirma", "Mientras un renglón tenga ENPAGOS el movimiento no se puede desconfirmar ni distribuir."),
            ("Caja no pasa por aquí", "Los recibos de caja consignados actualizan el saldo de la cuenta desde Caja; su legalización es del recibo."),
        ],
        accent="#0891b2",
    )

    # 7. Conciliación bancaria BCTC
    sketch(
        "bancos_conciliacion_sketchnote.jpg", BRAND,
        "Conciliación bancaria: acta de corte y auxiliar del mes",
        "Compare el extracto del banco con los libros, registre las partidas que explican la diferencia y cierre",
        [
            {"num": "1", "tit": "Abrir", "sub": "Nueva conciliación", "pal": "sky", "items": [
                ("Fecha de corte:", "La fecha del extracto. Define el mes del auxiliar."),
                ("Saldo exacto:", "Lo que dice el extracto del banco."),
                ("Saldo en libros:", "Lo que dice el sistema a esa fecha. La diferencia se calcula sola (rojo si negativa)."),
                ("Consecutivo:", "Lo asigna el sistema. Estado Abierta."),
            ]},
            {"num": "2", "tit": "Partidas", "sub": "Nuevo en el detalle", "pal": "orange", "items": [
                ("Qué son:", "Cheques no cobrados, consignaciones no registradas, notas del banco… lo que explica la diferencia."),
                ("Campos:", "Fecha, concepto (catálogo Operaciones), beneficiario, valor, clase DB/CR, detalle."),
                ("Operaciones:", "Botón para crear o borrar los conceptos de partida (catálogo propio de la conciliación)."),
                ("Editar:", "Solo mientras la conciliación está Abierta."),
            ]},
            {"num": "3", "tit": "Cerrar", "sub": "Candado en la fila", "pal": "green", "items": [
                ("Hace:", "Estado Cerrada y graba la foto del mes: saldo inicial, débitos, créditos, saldo final (BCTSM)."),
                ("Aviso:", "Si el saldo final calculado difiere del saldo en libros del acta (> 0,01) lo informa."),
                ("Después:", "Imprimir conciliación (cabecera, totales por operación, partidas). No se reabre."),
            ]},
            {"num": "4", "tit": "Auxiliar por mes", "sub": "Panel inferior", "pal": "violet", "items": [
                ("Qué muestra:", "Por año/mes: SI + DB − CR = SF, con el saldo en libros del acta y un semáforo de cruce."),
                ("Generar / Regenerar:", "Disponible si hay conciliación cerrada ese mes. Recalcula la foto con los movimientos confirmados."),
                ("Saldo inicial:", "Es el saldo final del mes anterior en el auxiliar. Si falta un mes, se arrastra 0."),
                ("Ver movimientos del mes:", "Filtra el libro de la cuenta a ese mes para revisar."),
            ]},
        ],
        pills=[
            ("Cerrar graba la foto", "Desde 2.0.7 cerrar la conciliación guarda la foto mensual (BCTSM). Regenerar la actualiza."),
            ("Meses en orden", "El saldo inicial se toma del mes anterior en el auxiliar: genere los meses en secuencia."),
            ("Las partidas no mueven saldo", "Son explicación de la diferencia, no asientos. Lo que falte en el sistema se registra como movimiento."),
            ("Fecha de corte = mes", "Año y mes del auxiliar salen de la fecha de corte del acta cerrada."),
        ],
        accent="#4f46e5",
    )

    # 8. Tres conciliaciones
    sketch(
        "bancos_tres_conci_sketchnote.jpg", BRAND,
        "Tres «conciliaciones», tres preguntas distintas",
        "No son la misma pantalla. Elija por la pregunta que quiere responder",
        [
            {"num": "1", "tit": "Conciliación bancaria", "sub": "Tesorería → Cuentas → Conciliación", "pal": "sky", "items": [
                ("Pregunta:", "¿Por qué el extracto del banco no da igual que mis libros a una fecha?"),
                ("Compara:", "Saldo del banco vs saldo en libros; partidas que explican la diferencia."),
                ("Produce:", "Acta cerrada + auxiliar de saldos por mes (BCTSM). PDF de la conciliación."),
                ("Quién:", "Tesorería."),
            ]},
            {"num": "2", "tit": "Conciliación contable de bancos", "sub": "Contabilidad → Conciliaciones contables", "pal": "orange", "items": [
                ("Pregunta:", "¿Todo movimiento bancario confirmado tiene su comprobante contable, y por el mismo valor?"),
                ("Compara:", "Movimientos BMOV (procedencia Bancos) del periodo vs MCP/MCPE con procedencia BMOV."),
                ("Produce:", "Semáforo contabilizada 0/1/2, envío de pendientes, reconstruir comprobantes con error. Excel."),
                ("Quién:", "Contabilidad."),
            ]},
            {"num": "3", "tit": "Auxiliar de bancos", "sub": "Contabilidad → Auxiliar de bancos", "pal": "green", "items": [
                ("Pregunta:", "¿Qué asientos de la cuenta contable del banco ya aparecieron en el extracto?"),
                ("Compara:", "Movimientos contables (MCH) de la cuenta por periodo o fechas; marca conciliado y fecha."),
                ("Produce:", "Marcas guardadas en contabilidad (CONCILIADO / FECHACONCILIACION), resumen de conciliados y no conciliados, PDF y Excel."),
                ("Quién:", "Contabilidad."),
            ]},
            {"num": "NO", "tit": "Conciliación de cartera", "sub": "Administrativo → Concilia", "pal": "rose", "items": [
                ("Pregunta:", "¿Qué acordamos con la EPS sobre facturas con saldo?"),
                ("Nada que ver:", "No compara bancos ni contabilidad. Genera notas crédito y saldos tipo C."),
                ("Libro:", "Ver Cartera · Conciliaciones."),
            ]},
        ],
        pills=[
            ("Orden sugerido", "1) Conciliación contable: que todo BMOV tenga asiento. 2) Auxiliar: marcar lo que ya pasó por el banco. 3) Acta bancaria: cerrar el mes."),
            ("Dos procedencias", "En BMOV la fila dice BANCOS/CAJA/CONTAB (de dónde nació). En el comprobante contable la procedencia es siempre BMOV."),
        ],
        accent="#be185d",
    )

    # 9. Contabilidad
    sketch(
        "bancos_contabilidad_sketchnote.jpg", BRAND,
        "Cómo llega un movimiento a contabilidad",
        "Al confirmar nace el comprobante. Si falla, Otros módulos o la conciliación contable lo reenvían",
        [
            {"num": "1", "tit": "Al confirmar", "sub": "Automático", "pal": "sky", "items": [
                ("Cuándo:", "Procedencia Bancos o Contabilidad y al menos un renglón."),
                ("Asiento:", "Débito/crédito a la cuenta contable de la cuenta bancaria contra la cuenta de la operación (o la del tercero contable)."),
                ("Marca:", "El movimiento guarda número de comprobante y Contabilizada = 1."),
                ("Si el mes está cerrado:", "No confirma: «Periodo contable cerrado»."),
            ]},
            {"num": "2", "tit": "Semáforo", "sub": "Campo Contabilizada", "pal": "amber", "items": [
                ("0 Pendiente:", "Confirmado sin comprobante. Enviar desde Otros módulos → Bancos."),
                ("1 Enviado:", "Comprobante generado. Ver con el botón Comprobante."),
                ("2 Con errores:", "Quedó en MCPE (errores). Reconstruir desde Conciliaciones contables."),
            ]},
            {"num": "3", "tit": "Otros módulos → Bancos", "sub": "Contabilidad", "pal": "orange", "items": [
                ("Filtro:", "Año, mes, estado contabilizada, cuenta bancaria. Solo movimientos confirmados."),
                ("Enviar:", "Marcar movimientos → Enviar a contabilidad. Usa el envío estándar de otros módulos con procedencia BMOV."),
                ("Detalle:", "Cada fila expande sus renglones."),
            ]},
            {"num": "4", "tit": "Desconfirmar y contabilidad", "sub": "Reverso", "pal": "rose", "items": [
                ("Mes abierto:", "El comprobante vuelve a estado editable / se anula y el movimiento queda sin número."),
                ("Mes cerrado:", "Genera comprobante de reverso en lugar de borrar."),
                ("Con errores:", "Si el comprobante estaba en MCPE, se elimina de errores."),
            ]},
        ],
        pills=[
            ("Procedencia BMOV en MCP", "Para buscar el asiento en contabilidad filtre procedencia BMOV y referencia = ítem del movimiento."),
            ("Contabilidad masiva también", "El cierre contable masivo recorre los movimientos marcados y los contabiliza si faltan."),
            ("Cuentas de detalle", "El comprobante exige cuentas contables de detalle; una cuenta mayor en la operación lo deja en errores."),
        ],
        accent="#b45309",
    )

    # 10. Chequeras y tarjeta de crédito
    sketch(
        "bancos_documentos_sketchnote.jpg", BRAND,
        "Chequeras, documentos y cuotas de tarjeta de crédito",
        "Dos ventanas auxiliares de la cuenta: control de documentos (BCTD) y cuotas TC (BCTTAR)",
        [
            {"num": "1", "tit": "Chequera", "sub": "Documentos → Nuevo", "pal": "sky", "items": [
                ("Datos:", "Número de chequera, forma de pago, cantidad de documentos, número inicial y final."),
                ("Generar Documentos:", "Crea los documentos (cheques) uno a uno. Opción de generación automática y cheques aleatorios."),
                ("Editar:", "Solo si aún no generó documentos."),
            ]},
            {"num": "2", "tit": "Documento", "sub": "Cada cheque", "pal": "orange", "items": [
                ("Campos:", "Consecutivo, número, fecha, valor, beneficiario, posfechado, código Alfabanco."),
                ("Entregar:", "Marca el documento como entregado (enlaza recibo / comprobante de egreso)."),
                ("Anular:", "Documento dañado o perdido. No se puede cambiar Alfabanco a un anulado."),
                ("Liberar:", "Vuelve a disponible un documento reservado."),
            ]},
            {"num": "3", "tit": "Cuotas TC", "sub": "Solo tarjeta de crédito", "pal": "violet", "items": [
                ("Vista:", "Por año/mes: pendientes y canceladas (cantidad y valor), interés, seguros, impuestos, cuota de manejo."),
                ("Cuentas contables:", "Dónde se contabiliza cada concepto de la tarjeta (catálogo FCTSER)."),
                ("Generar CxP del mes:", "Crea la cuenta por pagar de la tarjeta para pagarla desde CxP."),
            ]},
            {"num": "4", "tit": "Reportes", "sub": "PDF y Excel", "pal": "green", "items": [
                ("Imprimir:", "Movimientos de una cuenta con los filtros del libro."),
                ("Reportes bancarios:", "Varias cuentas, rango de fechas: débitos, créditos, FP, tercero, caja-recibo, recaudo, nómina."),
                ("Consignaciones:", "Por tercero, legalizadas o no."),
                ("Conciliación:", "PDF del acta cerrada."),
            ]},
        ],
        pills=[
            ("Pagar al proveedor es CxP", "El cheque se gira desde Cuentas por Pagar; aquí se controla el talonario y su estado."),
            ("Cupo, no saldo", "La tarjeta de crédito muestra cupo y disponible: disponible = cupo + pagos − consumos."),
        ],
        accent="#0f766e",
    )

    print("OK sketchnotes bancos generadas en", IMG_DIR)


if __name__ == "__main__":
    main()
