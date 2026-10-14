# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas) del capítulo Cartera · Reportes e informes.

Uso:  python libro/scripts/gen_rptcartera_sketchnotes.py
Salida: libro/img/rptcartera_*_sketchnote.jpg (reutiliza el motor de gen_recaudos_sketchnotes).

Contenido contrastado 2026-10-03 con Qrystalos2 (ConsRptCarteraPage y sus 13 informes, Vtos* 6 pestañas,
DetaFacxcComponent, SeguiCarteComponent, CerrarProceAdmComponent) e IXONLINE/SQL SPQ_CARTERA_RPT
(PREVERSION idéntica a la liberada 2.0.7; 16 METODO en catálogo).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND = "QRYSTALOS IPS · CARTERA · REPORTES E INFORMES"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. Qué hay aquí y qué no
    sketch(
        "rptcartera_que_es_sketchnote.jpg", BRAND,
        "Consultas y Reportes de cartera: qué hay aquí y qué no",
        "Una ventana de solo lectura con 13 informes. Lo que muestra es el resultado de radicar, recaudar, hacer notas, glosas y conciliaciones",
        [
            {"num": "1", "tit": "La ventana", "sub": "Administrativo → Consultas y Reportes", "pal": "sky", "items": [
                ("Qué es:", "Una rejilla de 13 botones; cada uno abre un informe con sus filtros, su grilla y su exportación."),
                ("Para quién:", "Analista de cartera, coordinación y contabilidad. Casi todo es lectura."),
                ("Exporta:", "Excel desde la grilla (filtros aplicados) y PDF en los informes que tienen formato."),
                ("No guarda:", "No cambia cartera, salvo tres acciones puntuales (reliquidar, ajuste NC, devoluciones)."),
            ]},
            {"num": "2", "tit": "Cinco familias", "sub": "Cómo agrupar los 13", "pal": "orange", "items": [
                ("Facturas:", "Facturas CXC, Facturas sin CXC, Facturas radicadas."),
                ("Cuentas de cobro:", "CXC entregadas, CXC sin entregar, Cuentas de cobro, Devoluciones."),
                ("Vencimientos:", "Un informe con seis pestañas (aging actual, total, histórico, régimen, tipo tercero, plan)."),
                ("Recaudos:", "Resumen radicación, Resumen recaudos, Recaudos en bancos."),
                ("Varios:", "Varios x mes y Estado de admisiones."),
            ]},
            {"num": "3", "tit": "De dónde salen los datos", "sub": "Vistas de cartera", "pal": "green", "items": [
                ("Vencimientos:", "Cada factura tiene uno o más vencimientos (saldos por tipo F, G, R, C) con fecha de vencimiento."),
                ("Aging:", "Los días vencidos se cuentan desde la fecha de vencimiento del vencimiento, no de la factura."),
                ("Histórico:", "La foto de fin de mes la toma el Cierre de cartera; sin cierre no hay histórico de ese mes."),
                ("Actual-Total:", "Se recalcula al pulsar Procesar; los demás leen en vivo."),
            ]},
            {"num": "NO ES", "tit": "Lo que no se hace aquí", "sub": "Vaya a la ventana correcta", "pal": "rose", "items": [
                ("Registrar un pago:", "Cartera · Recaudos."),
                ("Hacer una nota:", "Cartera · Notas DB/CR (aquí solo el ajuste NC desde el detalle de la factura)."),
                ("Responder una glosa:", "Cartera · Glosas."),
                ("Cerrar el mes:", "Administrativo → Cierre cartera (marca el periodo y crea el histórico)."),
            ]},
        ],
        pills=[
            ("Primero el filtro, luego la grilla", "Todos los informes esperan al menos un rango de fechas o un tercero; sin filtro la consulta puede tardar o no mostrar nada."),
            ("Excel con filtros", "El botón de Excel exporta lo que la grilla está filtrando, no toda la tabla. Si necesita todo, quite filtros."),
            ("Particulares", "Varios informes traen la casilla Incluir particulares: por defecto excluyen a los terceros de la categoría TERCATAFILIADO."),
        ],
        accent="#0284c7",
    )

    # 2. Mapa de los 13 informes
    sketch(
        "rptcartera_mapa_sketchnote.jpg", BRAND,
        "Mapa: qué pregunta responde cada informe",
        "Elija el informe por la pregunta, no por el nombre",
        [
            {"num": "A", "tit": "Facturas", "sub": "¿Qué pasa con esta factura?", "pal": "sky", "items": [
                ("Facturas CXC:", "Facturas que ya están en una cuenta de cobro: saldo, pagos, notas, glosas, radicación. Botón Detalle por factura."),
                ("Facturas sin CXC:", "Facturas liberadas que aún no entraron a ninguna cuenta de cobro (filtro por facturador, procedencia, devueltas)."),
                ("Facturas radicadas:", "Facturas por tercero según la cuenta de cobro esté radicada o no."),
            ]},
            {"num": "B", "tit": "Cuentas de cobro", "sub": "¿Qué entregué y qué me falta?", "pal": "orange", "items": [
                ("CXC entregadas:", "Cuentas recibidas por la EPS (fecha de recibido) con PDF."),
                ("CXC sin entregar:", "Cuentas armadas que aún no tienen recibido."),
                ("Cuentas de cobro:", "Listado completo con No. radicación, guía, quién recibió, sede, régimen; filtro Radicadas / Sin radicar."),
                ("Devoluciones:", "Facturas que la EPS devolvió: respuesta, paso a seguir (soportar / anular), Excel masivo."),
            ]},
            {"num": "C", "tit": "Vencimientos", "sub": "¿Cuánto me deben y hace cuánto?", "pal": "green", "items": [
                ("Actual:", "Aging por tercero en vivo: por vencer, 0-30, 31-60 … 361+."),
                ("Actual-Total:", "Mismo aging recalculado al Procesar, con detalle por factura y PDF."),
                ("Histórico:", "Aging de fin de mes (foto del cierre de cartera)."),
                ("Agrupados:", "El mismo saldo por régimen, por tipo de tercero contable o por plan."),
            ]},
            {"num": "D", "tit": "Recaudos", "sub": "¿Cuánto entró y cuándo?", "pal": "violet", "items": [
                ("Resumen radicación:", "Lo radicado por mes del año, con PDF."),
                ("Resumen recaudos:", "Lo recaudado por mes del año, con PDF."),
                ("Recaudos en bancos:", "Pagos identificados en extractos: banco, estado (pendiente / confirmado / anulado), legalizado, ajustes."),
            ]},
            {"num": "E", "tit": "Varios", "sub": "Cruces y admisiones", "pal": "rose", "items": [
                ("Varios x mes:", "Cinco cruces (radicación × régimen, pagos por fecha, cartera × facturas radicadas…). Hoy depende de un proceso que no está en el catálogo SQL: ver capítulo 11."),
                ("Estado de admisiones:", "Admisiones, citas y autorizaciones del rango con su factura (facturadas / no facturadas, capitado / evento)."),
            ]},
        ],
        pills=[
            ("Detalle de la factura", "Desde Facturas CXC → Detalle se ve todo el historial de una factura: vencimientos, pagos, notas, glosas, conciliaciones y devoluciones."),
            ("Seguimiento", "La gestión de cobro (llamadas, compromisos) no está en el hub: es Administrativo → Seguimiento Cartera."),
        ],
        accent="#ea580c",
    )

    # 3. Facturas
    sketch(
        "rptcartera_facturas_sketchnote.jpg", BRAND,
        "Informes de facturas: CXC, sin CXC y radicadas",
        "Tres miradas a la misma factura según en qué punto del camino esté",
        [
            {"num": "1", "tit": "Facturas CXC", "sub": "Ya están en cuenta de cobro", "pal": "sky", "items": [
                ("Filtros:", "Tipo de fecha (Todas / Radicada / Factura), rango, tercero, Cns. CxC, N. factura, Radicado (Todas / Sí / No), tipo de tercero, valor, valor glosa, glosa por recuperar."),
                ("Columnas:", "Valor total, servicios, copago, pagos, NC, ND, glosas, aceptado, recuperar, levantado, saldo neto; marcas Radicada, Devuelta, Cobro J., Capitada."),
                ("Detalle:", "Botón por fila: abre el historial completo de la factura (capítulo siguiente)."),
                ("Reliquidar:", "Recalcula el saldo de la factura seleccionada a partir de sus movimientos (pagos, notas, glosas)."),
            ]},
            {"num": "2", "tit": "Consulta masiva", "sub": "Dentro de Facturas CXC", "pal": "orange", "items": [
                ("Para qué:", "La EPS manda un listado de facturas y hay que saber cuáles tiene cartera y con qué saldo."),
                ("Cómo:", "Suba un Excel o TXT con números de factura → el sistema busca cada una en los vencimientos."),
                ("Resultado:", "Cuántas se encontraron y cuáles no tienen registro; se exporta."),
                ("Ojo:", "Busca por número de factura exacto; prefijos distintos no cruzan."),
            ]},
            {"num": "3", "tit": "Facturas sin CXC", "sub": "Todavía no entran a cartera", "pal": "green", "items": [
                ("Qué lista:", "Facturas liberadas (no anuladas) que no están en ninguna cuenta de cobro."),
                ("Filtros:", "Tercero, facturador, procedencia (asistencial, farmacia, citas…), rango de fecha de factura, Devuelta / Retirada / Sin devolución."),
                ("Para qué:", "Saber qué falta por armar en cuentas de cobro antes de radicar; detectar facturas devueltas que no se han reprocesado."),
                ("Siguiente paso:", "Facturación → Cuentas de cobro para incluirlas."),
            ]},
            {"num": "4", "tit": "Facturas radicadas", "sub": "Por tercero", "pal": "violet", "items": [
                ("Qué lista:", "Valor facturado por tercero según la cuenta de cobro tenga recibido (radicada) o no."),
                ("Filtros:", "Rango de fecha de recibido, tercero, casilla Radicadas (marcada = radicadas; desmarcada = sin radicar), buscador de factura."),
                ("Exporta:", "Excel y el mismo PDF de CXC entregadas."),
                ("Para qué:", "Soporte rápido de lo radicado en el periodo para informes gerenciales."),
            ]},
        ],
        pills=[
            ("Radicada ≠ cerrada", "Radicada significa que la EPS recibió la cuenta de cobro; la factura sigue en cartera hasta que se pague, se concilie o se castigue."),
            ("Reliquidar no inventa", "Solo vuelve a sumar lo que ya existe; si el saldo sigue mal, el error está en un movimiento (pago, nota, glosa)."),
        ],
        accent="#2563eb",
    )

    # 4. Detalle de la factura
    sketch(
        "rptcartera_detalle_sketchnote.jpg", BRAND,
        "Detalle de una factura en cartera",
        "Botón Detalle en Facturas CXC. La historia completa y la única acción que modifica saldo: el ajuste con nota crédito",
        [
            {"num": "1", "tit": "Vencimientos", "sub": "Los saldos de la factura", "pal": "sky", "items": [
                ("Qué muestra:", "Cada vencimiento con tipo (F factura, G glosa, R ratificación, C conciliación), valor inicial, saldo neto, fechas de recibido y vencimiento."),
                ("Para qué:", "Entender de qué está hecho el saldo: cuánto es factura limpia, cuánto glosa defendida, cuánto quedó de una conciliación."),
                ("Seleccionar:", "Al marcar un vencimiento tipo C o G con saldo se habilita el ajuste con nota crédito."),
            ]},
            {"num": "2", "tit": "Historial", "sub": "Todo lo que le pasó", "pal": "orange", "items": [
                ("Devoluciones:", "Si la EPS devolvió la factura, con motivo y respuesta."),
                ("Notas:", "Notas crédito y débito aplicadas, con módulo de origen (glosa, conciliación, ajuste, manual)."),
                ("Pagos:", "Recaudos aplicados con fecha y valor."),
                ("Glosas y conciliaciones:", "Glosas con su respuesta y conciliaciones en las que estuvo."),
            ]},
            {"num": "3", "tit": "Ajuste con nota crédito", "sub": "Ajuste de Saldos Cartera", "pal": "rose", "items": [
                ("Cuándo:", "Un saldo tipo C o G que no se va a cobrar (diferencia menor, acuerdo verbal, error de registro)."),
                ("Cómo:", "Marcar el vencimiento → Concepto (catálogo CPNT) → Valor (> 0 y ≤ saldo del ítem) → Observación → Registrar."),
                ("Qué hace:", "Crea una nota crédito con procedencia AJUSTE, la aplica a ese vencimiento y reliquida la factura."),
                ("Imprime:", "La NC generada se puede imprimir desde el mismo detalle."),
            ]},
            {"num": "4", "tit": "Límites", "sub": "Lo que no permite", "pal": "violet", "items": [
                ("Solo C o G:", "Vencimientos tipo F (factura) o R no se ajustan aquí: use Notas DB/CR."),
                ("Saldo > 0:", "Si el ítem ya está en cero no hay nada que ajustar."),
                ("Sin deshacer:", "La NC de ajuste se anula como cualquier nota, desde Notas DB/CR."),
                ("Periodo:", "Aplican las reglas de periodo contable de las notas."),
            ]},
        ],
        pills=[
            ("Es la pantalla para soporte", "Cuando el usuario dice «el saldo está mal», aquí se ve en qué movimiento se desvió antes de pedir un arreglo."),
            ("Ajuste no es conciliación", "El ajuste es por factura y sin acta; si es un acuerdo con la EPS sobre varias facturas, use Conciliaciones."),
        ],
        accent="#e11d48",
    )

    # 5. Cuentas de cobro y devoluciones
    sketch(
        "rptcartera_cuentas_sketchnote.jpg", BRAND,
        "Cuentas de cobro: entregadas, sin entregar, listado y devoluciones",
        "Siguen el camino de la cuenta de cobro desde que se arma hasta que la EPS la recibe o la devuelve",
        [
            {"num": "1", "tit": "CXC sin entregar", "sub": "Armadas, sin recibido", "pal": "orange", "items": [
                ("Qué lista:", "Cuentas de cobro sin indicador de recibido."),
                ("Filtros:", "Rango de fecha de la cuenta, tercero."),
                ("Para qué:", "Lo que falta por radicar. Si una lleva días aquí, alguien no la entregó."),
                ("PDF:", "Listado imprimible por tercero."),
            ]},
            {"num": "2", "tit": "CXC entregadas", "sub": "Con recibido de la EPS", "pal": "green", "items": [
                ("Qué lista:", "Cuentas de cobro de cartera con recibido = 1."),
                ("Filtros:", "Rango de fecha de recibido, tercero, Incluir particulares."),
                ("Para qué:", "Soporte de radicación del periodo."),
                ("PDF:", "Mismo formato que Facturas radicadas."),
            ]},
            {"num": "3", "tit": "Cuentas de cobro", "sub": "El listado completo", "pal": "sky", "items": [
                ("Qué lista:", "Todas las cuentas con fecha, cierre, envío, radicado, No. radicación, No. guía, quién recibió, usuario, sede, modalidad, atención, régimen, año y mes."),
                ("Filtros:", "Rango, Estado (Todas / Radicadas / Sin radicar), Incluir particulares."),
                ("Detalle:", "Exportación con las facturas de cada cuenta (Cnc CXC → facturas y valor)."),
                ("Para qué:", "Auditoría de radicación y respuesta a la EPS cuando pide el soporte de entrega."),
            ]},
            {"num": "4", "tit": "Devoluciones", "sub": "Lo que la EPS devolvió", "pal": "rose", "items": [
                ("Qué lista:", "Facturas devueltas con motivo, fecha de radicación, estado, respuesta y paso a seguir."),
                ("Responder:", "Por factura: código de respuesta (catálogo de glosas clase RESPUESTA), paso a seguir Soportar o Anular; o por Excel con plantilla."),
                ("Enviar:", "Soportar → se crea una cuenta de cobro nueva; Anular → vuelve a facturación como devolución."),
                ("Es operación:", "Es el único informe del hub que cambia estado; sus reglas están en Cartera · Recaudos (FCXCR)."),
            ]},
        ],
        pills=[
            ("Tres fechas distintas", "Fecha de la cuenta (cuándo se armó), fecha de envío y fecha de recibido (radicación). Los informes filtran por fechas distintas: lea el encabezado del filtro."),
            ("Incluir particulares", "Por defecto se excluyen los terceros de la categoría TERCATAFILIADO (pacientes particulares); marque la casilla si los necesita."),
        ],
        accent="#16a34a",
    )

    # 6. Vencimientos: las seis pestañas
    sketch(
        "rptcartera_vencimientos_sketchnote.jpg", BRAND,
        "Vencimientos: las seis pestañas del aging",
        "El mismo saldo de cartera visto por tercero, en el tiempo o agrupado",
        [
            {"num": "1", "tit": "Actual", "sub": "En vivo, por tercero", "pal": "sky", "items": [
                ("Filtros:", "Tercero, Clase informe (Sin glosa / Con glosa), Radicadas (Todas / Sí / No), Tipo tercero, Tipo facturas (salud / otras / todo), Grupo de días, Particulares."),
                ("Columnas:", "Vlr. total, por vencer, 0-30, 31-60, 61-90, 91-120, 121-150, 151-180, 181-360, 361+, no radicada."),
                ("Detalle:", "Por tercero: cada vencimiento con factura, tipo, glosa y días."),
                ("Exporta:", "Excel de la grilla, Excel del detalle, PDF por rango de vencimientos."),
            ]},
            {"num": "2", "tit": "Actual-Total", "sub": "Procesar primero", "pal": "orange", "items": [
                ("Cómo:", "Asigne filtros (tercero opcional, Glosa, Radicadas, Particulares) y pulse Procesar: el sistema recalcula la cartera y arma la tabla."),
                ("Columnas:", "Además del aging, por factura: pagos, NC, ND, deducciones, glosa aceptada, por recuperar, levantado, plan, contrato, tipo TTEC."),
                ("Para qué:", "El cuadre fino con la EPS: factura por factura con todos sus componentes."),
                ("Ojo:", "Sin Procesar no hay datos; cada Procesar reemplaza el cálculo anterior."),
            ]},
            {"num": "3", "tit": "Histórico", "sub": "Foto de fin de mes", "pal": "violet", "items": [
                ("Qué muestra:", "El aging tal como quedó al cerrar cada mes (año y mes), por tercero."),
                ("De dónde:", "Lo crea el Cierre de cartera del mes; si se reabre el periodo, la foto se borra."),
                ("Detalle:", "Vencimientos históricos por tercero; exportación de formato."),
                ("Para qué:", "Comparar meses, informes a junta, conciliar contra contabilidad del mes."),
            ]},
            {"num": "4", "tit": "Agrupados", "sub": "Régimen · Tipo tercero · Plan", "pal": "green", "items": [
                ("Por régimen:", "Aging por régimen (contributivo, subsidiado…) y drill-down a facturas."),
                ("Tipo tercero:", "Aging por tipo de tercero contable (TTEC): cómo se ve en contabilidad."),
                ("Por plan:", "Aging por plan del tercero con drill-down."),
                ("Comunes:", "Año/mes, Clase informe, Radicadas, Tipo tercero; Excel con configuración de columnas."),
            ]},
        ],
        pills=[
            ("Mismos buckets en todas", "Por vencer, 0-30, 31-60, 61-90, 91-120, 121-150, 151-180, 181-360 y 361+. Los días se cuentan desde la fecha de vencimiento del vencimiento."),
            ("Actual vs Histórico", "Actual cambia cada vez que entra un pago o una nota; Histórico no cambia nunca (salvo reabrir el mes). Para «cómo estaba a 30 de junio» use Histórico."),
            ("Con glosa / Sin glosa", "Clase informe separa los vencimientos tipo glosa (G, R) del resto; Todas los suma."),
        ],
        accent="#7c3aed",
    )

    # 7. Cómo leer el aging
    sketch(
        "rptcartera_aging_sketchnote.jpg", BRAND,
        "Cómo leer el aging: columnas, marcas y lo que significan",
        "Una fila por tercero (o por factura en el detalle). Lea de izquierda a derecha",
        [
            {"num": "1", "tit": "Vlr. total y por vencer", "sub": "Lo que debe", "pal": "sky", "items": [
                ("Vlr. total:", "Suma de saldos netos de todos los vencimientos del tercero (con los filtros aplicados)."),
                ("Por vencer:", "Saldo cuya fecha de vencimiento aún no llega: no está en mora."),
                ("Regla:", "Total = por vencer + todos los rangos vencidos."),
            ]},
            {"num": "2", "tit": "Rangos vencidos", "sub": "Días desde el vencimiento", "pal": "orange", "items": [
                ("0-30 · 31-60 · 61-90:", "Mora reciente: gestión normal de cobro."),
                ("91-120 · 121-150 · 151-180:", "Mora media: seguimiento formal, conciliación."),
                ("181-360:", "Mora alta: evaluar cobro jurídico o castigo."),
                ("361+:", "Más de un año: revisar castigo de cartera con contabilidad."),
            ]},
            {"num": "3", "tit": "Marcas", "sub": "Columnas de estado", "pal": "green", "items": [
                ("Radicada / No radicada:", "Si la cuenta de cobro tiene recibido. Una no radicada no debería estar en mora: la EPS no la ha recibido."),
                ("Con glosa:", "El saldo viene de una glosa defendida o ratificación."),
                ("Particular:", "Tercero de la categoría de afiliados particulares."),
                ("Capitada / Cobro J. / Devuelta / Castigada:", "Marcas en Facturas CXC que explican por qué un saldo no se mueve."),
            ]},
            {"num": "4", "tit": "Dónde está el detalle", "sub": "Del número a la factura", "pal": "violet", "items": [
                ("Detalle por tercero:", "Botón en la fila: lista cada vencimiento con factura, tipo, días y saldo."),
                ("Detalle de factura:", "Desde Facturas CXC → Detalle: historial completo."),
                ("Exportar detalle:", "En Actual, botón para exportar todos los vencimientos con los filtros actuales."),
                ("PDF por rango:", "Imprime el aging con los rangos elegidos, para enviar a la EPS."),
            ]},
        ],
        pills=[
            ("Un tercero, varias filas", "En Actual-Total e Histórico el mismo tercero aparece por factura; en Actual, una fila por tercero. No sume filas de pantallas distintas."),
            ("Días desde el vencimiento", "Si el vencimiento se fijó a 30 días del recibido, una factura radicada hace 45 días está en 0-30, no en 31-60."),
        ],
        accent="#f59e0b",
    )

    # 8. Recaudos y radicación
    sketch(
        "rptcartera_recaudos_sketchnote.jpg", BRAND,
        "Resúmenes de radicación, recaudos y recaudos en bancos",
        "Tres informes para el seguimiento mensual del flujo de caja de cartera",
        [
            {"num": "1", "tit": "Resumen radicación", "sub": "Por mes del año", "pal": "sky", "items": [
                ("Filtros:", "Año, Mes, Incluir particulares."),
                ("Qué muestra:", "Valor radicado (cuentas de cobro con recibido) por tercero y por mes, enero a diciembre."),
                ("PDF:", "Formato resumen de radicación."),
                ("Para qué:", "Cuánto se radicó cada mes; base de la meta de recaudo."),
            ]},
            {"num": "2", "tit": "Resumen recaudos", "sub": "Por mes del año", "pal": "green", "items": [
                ("Filtros:", "Año, Mes, Incluir particulares."),
                ("Qué muestra:", "Valor recaudado (recaudos aplicados) por tercero y por mes."),
                ("PDF:", "Formato resumen de recaudos."),
                ("Para qué:", "Comparar con radicación: cuánto de lo radicado ya se cobró."),
            ]},
            {"num": "3", "tit": "Recaudos en bancos", "sub": "Lo que llegó al banco", "pal": "orange", "items": [
                ("Filtros:", "Rango de fecha de operación, banco, tercero, Estado (pendientes / confirmados / anulados)."),
                ("Columnas:", "Banco, cuenta, fecha, tercero, valor, saldo, legalizado, ajuste, ajuste al peso, estado."),
                ("Para qué:", "Pagos identificados en el extracto que aún no se legalizan como recaudo (pendientes) o ya se cruzaron (confirmados)."),
                ("Siguiente paso:", "Legalizar desde Cartera · Recaudos (recaudo desde banco)."),
            ]},
            {"num": "4", "tit": "Cómo cruzarlos", "sub": "Lectura conjunta", "pal": "violet", "items": [
                ("Radicado − recaudado:", "Lo que la EPS aún debe del periodo; debe parecerse al aging de ese mes."),
                ("Banco pendiente:", "Dinero que ya está pero no ha bajado cartera: priorizar su legalización."),
                ("Diferencias:", "Si recaudos del mes > banco confirmado, hay recaudos registrados sin soporte bancario (o pagos en caja)."),
                ("Particulares:", "Excluidos por defecto; actívelos para cuadrar con contabilidad."),
            ]},
        ],
        pills=[
            ("Año válido", "Los resúmenes exigen un año válido; el mes es el corte hasta el que se muestra."),
            ("Fecha de operación", "Recaudos en bancos filtra por la fecha en que el banco registró el movimiento, no por la fecha del recaudo en cartera."),
        ],
        accent="#16a34a",
    )

    # 9. Varios x mes y Estado de admisiones
    sketch(
        "rptcartera_varios_sketchnote.jpg", BRAND,
        "Varios x mes y Estado de admisiones",
        "Dos informes de cruce. Uno de ellos depende de un proceso que hoy no está en el catálogo SQL",
        [
            {"num": "1", "tit": "Varios x mes", "sub": "Cinco cruces en pestañas", "pal": "sky", "items": [
                ("Pestañas:", "Radicación × empresa y recaudo legalizado × régimen · Pagos por fecha de pago · Cartera × facturas radicadas · Recaudo × régimen · Radicación × régimen."),
                ("Filtros:", "Fecha inicial, fecha final, Id. tercero → botón Procesar."),
                ("Cómo funciona:", "Procesar manda a calcular los cinco cruces a una tabla de resultados y luego la grilla los lee."),
                ("Exporta:", "Configurar exportación (columnas y cantidad de filas) → Excel."),
            ]},
            {"num": "!", "tit": "Estado hoy", "sub": "Verificado en el catálogo SQL", "pal": "rose", "items": [
                ("Hallazgo:", "El método que ejecuta el cálculo (EXECUTE_SPK_REPORTES_VARIOS_CARTERA) no existe en el procedimiento CARTERA_RPT, ni en PREVERSION ni en la liberada 2.0.7."),
                ("Efecto:", "Procesar no recalcula y no avisa; la grilla muestra lo que haya quedado en la tabla de resultados de una corrida anterior (o nada)."),
                ("Qué decir al usuario:", "El informe no es confiable hasta que se publique el método; use Vencimientos, Resúmenes y Recaudos en bancos para las mismas preguntas."),
                ("Pendiente:", "Registrado para el equipo SQL."),
            ]},
            {"num": "2", "tit": "Estado de admisiones", "sub": "Admisiones · Citas · Autorizaciones", "pal": "green", "items": [
                ("Filtros:", "Rango de fechas, Facturación (facturadas / no facturadas / todas), Estado, Capitado (capitados / evento)."),
                ("Pestañas:", "No. Admisión (altas médica, enfermería y administrativa, factura, valor), Citas (médico, plan, factura), Autorizaciones (prefijo, proveedor, factura)."),
                ("Para qué:", "Detectar atenciones cerradas sin factura (fuga de facturación) y admisiones abiertas."),
                ("Exporta:", "Configurar exportación → Excel."),
            ]},
            {"num": "3", "tit": "Lectura", "sub": "Qué buscar", "pal": "orange", "items": [
                ("No facturada + cerrada:", "Atención terminada que no generó factura: revisar con facturación."),
                ("Facturada sin cuenta de cobro:", "Cruce con Facturas sin CXC."),
                ("Capitado vs evento:", "Separa lo que se cobra por cápita de lo que se cobra por evento."),
                ("Este informe sí lee en vivo:", "Admisiones, citas y autorizaciones se consultan directo; no depende del cálculo anterior."),
            ]},
        ],
        pills=[
            ("No proponer desarrollo por un dato viejo", "Si un usuario reporta que Varios x mes «no cambia», no es un defecto de la grilla: es el método faltante. Validar antes de desarrollar."),
            ("Admisiones es de facturación", "Estado de admisiones vive en el hub de cartera, pero su acción correctiva es de Facturación / Asistencial."),
        ],
        accent="#e11d48",
    )

    # 10. Seguimiento y cierre
    sketch(
        "rptcartera_seguimiento_sketchnote.jpg", BRAND,
        "Alrededor del hub: Seguimiento de cartera y Cierre de cartera",
        "Dos ventanas aparte que alimentan o usan los informes",
        [
            {"num": "1", "tit": "Seguimiento cartera", "sub": "Administrativo → Seguimiento Cartera", "pal": "sky", "items": [
                ("Qué es:", "Bitácora de gestión de cobro por cuenta de cobro / factura: con quién se habló, qué se acordó, próxima llamada."),
                ("Cómo:", "Buscar la cuenta de cobro (filtros tercero, factura) → ver facturas con saldo, glosas, notas, pagos → Nuevo seguimiento."),
                ("Campos:", "Fecha, ¿Con quién se habló?, Observaciones, Valor gestionado, Fecha y valor de advertencia, Próxima llamada, funcionario."),
                ("Estados:", "Abierto → Cerrar (gestión cumplida) o Eliminar (registrado por error). Solo los abiertos se cierran o borran."),
            ]},
            {"num": "2", "tit": "Para qué sirve", "sub": "Gestión, no saldo", "pal": "orange", "items": [
                ("Evidencia:", "Soporta ante la EPS y ante auditoría que la cartera se gestionó."),
                ("Agenda:", "La próxima llamada ordena el trabajo del analista."),
                ("No cambia saldo:", "Registrar un seguimiento no mueve cartera; el pago llega por Recaudos."),
                ("Exporta:", "Las grillas de cuentas y facturas exportan a Excel."),
            ]},
            {"num": "3", "tit": "Cierre de cartera", "sub": "Administrativo → Cierre cartera", "pal": "violet", "items": [
                ("Qué hace:", "Marca el periodo (año/mes) como cerrado para cartera y toma la foto de los vencimientos: ese es el Histórico."),
                ("Ventana:", "Elige el periodo, muestra la grilla del histórico ya generado y permite cerrar o reabrir."),
                ("Reabrir:", "Borra la foto del mes y solo se permite hasta 25 días después del fin de mes."),
                ("Para qué:", "Sin cierre no hay pestaña Histórico de ese mes ni comparación con contabilidad."),
            ]},
            {"num": "4", "tit": "Orden del mes", "sub": "Rutina sugerida", "pal": "green", "items": [
                ("1.", "Legalizar lo pendiente en Recaudos en bancos."),
                ("2.", "Revisar Facturas sin CXC y CXC sin entregar: radicar lo que falte."),
                ("3.", "Aging Actual: gestionar y registrar seguimientos."),
                ("4.", "Cerrar cartera del mes → Histórico → comparar con contabilidad."),
            ]},
        ],
        pills=[
            ("Castigo y seguimiento contable", "Contabilidad → Seguimiento cartera y Castigo cartera son procesos contables sobre la misma cartera; no se documentan aquí."),
            ("Permisos", "Los tres accesos (Consultas y Reportes, Seguimiento Cartera, Cierre cartera) se controlan por menú; no hay botones con permiso individual."),
        ],
        accent="#4f46e5",
    )

    print("OK sketchnotes reportes de cartera generadas en", IMG_DIR)


if __name__ == "__main__":
    main()
