# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del capítulo Cartera · Conciliaciones.

Uso:  python libro/scripts/gen_conci_sketchnotes.py
Salida: libro/img/conci_*_sketchnote.jpg (reutiliza el motor de gen_recaudos_sketchnotes).

Contenido contrastado 2026-10-03 con Qrystalos2 (ConciliaPage, Concilia/FconciComponent,
HelpManualConciliaComponent, OMConciliacionesComponent) e IXONLINE/SQL SPQ_FCONCI_COL +
SPK_APLICA_CONCILIACION (PREVERSION idéntica a la liberada 2.0.7).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND = "QRYSTALOS IPS · CARTERA · CONCILIACIONES"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. Qué es una conciliación y qué no es
    sketch(
        "conci_que_es_sketchnote.jpg", BRAND,
        "Qué es una conciliación de cartera y qué no es",
        "Un acuerdo con la EPS sobre facturas con saldo: cuánto se acepta descontar y cuánto queda por recuperar",
        [
            {"num": "1", "tit": "La conciliación", "sub": "Documento FCONCI", "pal": "sky", "items": [
                ("Qué es:", "El acta del acuerdo con una EPS: una cabecera (tercero, fechas, funcionario externo) y una lista de facturas."),
                ("Por factura:", "Saldo neto que debe la EPS, valor aceptado (se descuenta) y valor a recuperar (la EPS debe pagar)."),
                ("Dos tipos:", "Individual (el valor aceptado se digita factura por factura) o Porcentaje (un % igual para todas)."),
                ("Vive en:", "Administrativo → Concilia. Tres estados: Ingresada, Cerrada, Anulada."),
            ]},
            {"num": "2", "tit": "Lo que entra", "sub": "Saldos de cartera", "pal": "orange", "items": [
                ("Facturas:", "Solo las del tercero de la conciliación y con saldo neto mayor que cero."),
                ("Vencimientos:", "Cada factura puede tener varios saldos por tipo: F factura, G glosa, R ratificación, C conciliación anterior."),
                ("Glosas:", "Un saldo tipo glosa exige su consecutivo de glosa, respondida, aplicada y radicada."),
                ("Filtro:", "La variable CONCIGLOSA_TIPOSPERM limita qué tipos se pueden conciliar."),
            ]},
            {"num": "3", "tit": "Lo que sale", "sub": "Al confirmar", "pal": "green", "items": [
                ("Nota crédito:", "Por cada factura con valor aceptado nace una NC automática (prefijo sede + C) que baja la cartera."),
                ("Saldo tipo C:", "El valor a recuperar queda como un nuevo vencimiento tipo C en la factura: la EPS lo debe pagar."),
                ("Contabilidad:", "Si hay valor a recuperar se genera el asiento de conciliación; luego se envía desde Otros módulos."),
                ("Cierre:", "La conciliación queda Cerrada y ya no se edita; solo se imprime o se anula."),
            ]},
            {"num": "NO ES", "tit": "Lo que no es", "sub": "Evite el camino equivocado", "pal": "rose", "items": [
                ("Conciliación bancaria:", "El cruce de extractos contra contabilidad está en Contabilidad → Conciliaciones contables."),
                ("Responder una glosa:", "Aceptar o defender la objeción es Cartera · Glosas; aquí se negocia lo que quedó pendiente."),
                ("Recaudo:", "El pago real de la EPS se registra en Recaudos, no aquí. La conciliación no mueve caja."),
                ("Nota crédito manual:", "La NC del acuerdo la genera el sistema al confirmar; no se digita en Notas DB/CR."),
            ]},
        ],
        pills=[
            ("Aceptado + recuperar = saldo", "En cada línea el valor a recuperar se calcula solo: saldo neto menos valor aceptado. Nunca puede aceptarse más que el saldo."),
            ("Solo Ingresada se edita", "Mientras está Ingresada se agregan, cambian y borran facturas. Al confirmar pasa a Cerrada y queda congelada."),
            ("Anular = nota débito", "Anular una conciliación o una factura cerrada crea una ND que reversa la NC y devuelve el saldo original."),
            ("Concepto de nota obligatorio", "La variable IDCOPNOTACONCI (concepto CPNT) es indispensable: sin ella no se genera la nota crédito y no cierra."),
        ],
        accent="#0284c7",
    )

    # 2. El ciclo completo
    sketch(
        "conci_ciclo_sketchnote.jpg", BRAND,
        "El ciclo completo: del acuerdo con la EPS a la contabilidad",
        "Seis momentos en una sola ventana (Administrativo → Concilia) más el envío contable desde Otros módulos",
        [
            {"num": "PASO 01", "tit": "Crear", "sub": "Nueva Conciliación", "pal": "sky", "items": [
                ("Quién:", "Analista de cartera."),
                ("Qué hace:", "Elige el tercero (EPS), fecha de conciliación, fecha de pago acordada, funcionario externo, tipo y observación."),
                ("Resultado:", "Cabecera en estado Ingresada con consecutivo propio (Cns.Concilia)."),
            ]},
            {"num": "PASO 02", "tit": "Agregar facturas", "sub": "Detalle", "pal": "orange", "items": [
                ("Tres caminos:", "Nuevo Detalle (una por una), Agregar Archivo Plano (Excel) o Aplicar concepto a varias marcadas."),
                ("Por línea:", "Factura y vencimiento, concepto de nota, código de glosa, valor aceptado y observación."),
                ("Resultado:", "Líneas Ingresada con saldo neto, aceptado y a recuperar."),
            ]},
            {"num": "PASO 03", "tit": "Revisar", "sub": "Editar · Borrar · Limpiar", "pal": "violet", "items": [
                ("Editar / Borrar:", "Cada línea Ingresada se corrige o se quita; Limpiar Todos vacía el detalle."),
                ("Imprimir:", "Imp.Conci. saca el acta en PDF en cualquier estado, también antes de confirmar."),
                ("Soportes:", "Escaneo adjunta el acta firmada u otros documentos a la conciliación."),
            ]},
            {"num": "PASO 04", "tit": "Confirmar", "sub": "Cerrar Conciliación", "pal": "green", "items": [
                ("Valida:", "Periodo contable abierto (si aplica), glosas aplicadas y radicadas, tipos permitidos."),
                ("Genera:", "NC por cada valor aceptado; vencimiento tipo C por cada valor a recuperar; asiento de conciliación."),
                ("Resultado:", "Conciliación y líneas en Cerrada."),
            ]},
            {"num": "PASO 05", "tit": "Anular", "sub": "Solo si fue un error", "pal": "rose", "items": [
                ("Toda:", "Anular (cabecera) reversa cada línea cerrada y deja la conciliación Anulada."),
                ("Una factura:", "Anular Item reversa una sola línea; las demás siguen cerradas."),
                ("Resultado:", "ND que reversa la NC, se borra el vencimiento tipo C y se reversa el asiento."),
            ]},
            {"num": "PASO 06", "tit": "Contabilizar", "sub": "Contabilidad → Otros módulos", "pal": "teal", "items": [
                ("Quién:", "Contabilidad."),
                ("Qué hace:", "Otros módulos → Conciliaciones: filtra año/mes, marca las cerradas sin comprobante y envía."),
                ("Resultado:", "Contabilizada = 1 y Nro. Comprobante en la grilla; habilita Imp.Comp."),
            ]},
        ],
        pills=[
            ("Una sola ventana operativa", "Crear, detallar, confirmar, imprimir y anular ocurren en Administrativo → Concilia. Solo el envío contable está en Contabilidad."),
            ("Ingresada → Cerrada → Anulada", "No hay vuelta atrás a Ingresada: lo que se confirmó se anula (con nota débito), no se reabre."),
            ("Las notas no se tocan a mano", "La NC al confirmar y la ND al anular las crea el sistema con procedencia CONCILIA; se consultan en Notas DB/CR."),
        ],
        accent="#ea580c",
    )

    # 3. Crear la cabecera
    sketch(
        "conci_cabecera_sketchnote.jpg", BRAND,
        "Crear la conciliación: la cabecera",
        "Nueva Conciliación abre el formulario; los campos marcados son los que el sistema valida antes de guardar",
        [
            {"num": "1", "tit": "Quién y cuándo", "sub": "Tercero y fechas", "pal": "sky", "items": [
                ("Id. Tercero:", "La EPS con la que se concilia. Botón de búsqueda; solo sus facturas aparecerán en el detalle."),
                ("F. Concilia:", "Fecha del acuerdo. Si la variable FNOT_FECHACONCILIA = CONCILIACION, esta fecha será la de las notas crédito."),
                ("Fecha Pago Acuerdo:", "Cuándo se comprometió a pagar la EPS. Debe ser posterior a la fecha de conciliación."),
                ("Sede:", "Se toma de la sesión; el consecutivo de la NC llevará el prefijo de la sede + C."),
            ]},
            {"num": "2", "tit": "Referencias", "sub": "Lo que firma la EPS", "pal": "orange", "items": [
                ("Nro. Externo:", "Número del acta o referencia de la EPS. Solo números, salvo que CONCIGLOSA_NREXTERNO = alfanumerico."),
                ("Funcionario Externo:", "Nombre de quien firmó por la EPS."),
                ("Observaciones:", "Mínimo 10 caracteres. Explique el acuerdo: fecha de la reunión, alcance, condiciones."),
                ("Funcionario interno:", "Lo registra el sistema con el usuario que crea la conciliación."),
            ]},
            {"num": "3", "tit": "Tipo Individual", "sub": "Caso general", "pal": "green", "items": [
                ("Cuándo:", "El acuerdo es distinto en cada factura o se negoció factura por factura."),
                ("Valor aceptado:", "Se digita en cada línea del detalle; no puede superar el saldo neto ni ser negativo."),
                ("Valor a recuperar:", "Se calcula solo: saldo neto − valor aceptado."),
                ("Excel:", "La carga masiva trae el valor aceptado por fila; sirve para acuerdos largos."),
            ]},
            {"num": "4", "tit": "Tipo Porcentaje", "sub": "Un mismo % para todas", "pal": "violet", "items": [
                ("Cuándo:", "La EPS acordó descontar el mismo porcentaje a todas las facturas (p. ej. 10 %)."),
                ("Vlr. Porcentaje:", "Obligatorio y mayor que cero. Se guarda en la cabecera."),
                ("En el detalle:", "Vlr. Aceptado queda bloqueado y se calcula: saldo neto × % ÷ 100 al elegir la factura."),
                ("Ojo:", "Cambiar el % después de agregar facturas no recalcula las líneas ya guardadas."),
            ]},
        ],
        pills=[
            ("Mientras está Ingresada", "Editar cambia cualquier dato de la cabecera. Borrar solo funciona si aún no tiene facturas en el detalle."),
            ("El tercero manda", "Al elegir facturas, el sistema filtra por el tercero de la cabecera y saldo neto > 0: si una factura no aparece, revise a quién está facturada."),
            ("Procedencia CXC", "Las conciliaciones creadas aquí nacen con procedencia CXC. El valor total de la cabecera no se recalcula desde el detalle."),
        ],
        accent="#2563eb",
    )

    # 4. Agregar facturas al detalle
    sketch(
        "conci_detalle_sketchnote.jpg", BRAND,
        "Agregar facturas: saldo neto, valor aceptado y valor a recuperar",
        "Nuevo Detalle de Conciliación (ícono carpeta) en la fila expandida de una conciliación Ingresada",
        [
            {"num": "1", "tit": "Elegir la factura", "sub": "Seleccionar Factura", "pal": "sky", "items": [
                ("Lista:", "Vencimientos de cartera del tercero con saldo neto > 0 (y del tipo permitido si la variable está configurada)."),
                ("Columnas:", "Nro. factura, tipo de vencimiento, consecutivo CxC, consecutivo de glosa, saldo inicial, saldo neto y fecha."),
                ("Al elegir:", "Se llenan Nro, Tipo, Cns. CxC, Cns. Glosa y Saldo Neto; el valor a recuperar arranca igual al saldo."),
                ("Tipos:", "F = factura, G = glosa, R = ratificación, C = conciliación anterior. Los tipos con glosa exigen Cns. Glosa."),
            ]},
            {"num": "2", "tit": "Clasificar", "sub": "Concepto y código de glosa", "pal": "orange", "items": [
                ("Seleccionar Concepto:", "Concepto de nota (catálogo CPNT). Viene por defecto el de la variable IDCOPNOTACONCI; se puede cambiar."),
                ("Para qué:", "Es el concepto con el que se generará la nota crédito al confirmar."),
                ("Seleccionar Cod. Glosa:", "Motivo del catálogo de glosas (FCGLO). Opcional, pero documenta por qué se aceptó."),
                ("Observación:", "Mínimo 10 caracteres; queda en la línea y en la NC."),
            ]},
            {"num": "3", "tit": "Partir el saldo", "sub": "Aceptado vs recuperar", "pal": "green", "items": [
                ("Saldo Neto:", "Lo que la EPS debe hoy por ese vencimiento. No se edita."),
                ("Vlr. Aceptado:", "Lo que la IPS acepta descontar (la EPS tenía razón). Individual: se digita; Porcentaje: calculado."),
                ("Vlr. Recuperar:", "Saldo neto − aceptado. Lo que la EPS se compromete a pagar."),
                ("Regla:", "Aceptado > saldo → el sistema lo baja al saldo y recuperar = 0. Aceptado < 0 → se rechaza."),
            ]},
            {"num": "4", "tit": "Mantener el detalle", "sub": "Fila expandida", "pal": "violet", "items": [
                ("Editar / Borrar:", "Por línea, solo mientras la conciliación está Ingresada."),
                ("Limpiar Todos:", "Borra de una vez todas las líneas Ingresada de esa conciliación."),
                ("Duplicados:", "No se puede agregar dos veces el mismo vencimiento a la misma conciliación."),
                ("Exportar:", "La grilla del detalle se exporta a Excel para revisarla con la EPS."),
            ]},
        ],
        pills=[
            ("Glosa lista para conciliar", "Si la línea trae consecutivo de glosa, la glosa debe existir, tener respuesta aplicada (cerrada), fecha de respuesta y estar radicada. Si no, el sistema rechaza la línea."),
            ("Un vencimiento, una conciliación abierta", "Un mismo vencimiento no puede estar en dos conciliaciones Ingresada a la vez (la carga Excel lo valida)."),
            ("La cabecera no suma", "El total de la conciliación se lee en el detalle o en el PDF; la cabecera no recalcula un valor global."),
        ],
        accent="#16a34a",
    )

    # 5. Carga masiva y concepto masivo
    sketch(
        "conci_masiva_sketchnote.jpg", BRAND,
        "Cargar muchas facturas: Archivo Plano (Excel) y Aplicar concepto",
        "Dos atajos para acuerdos largos; ambos exigen la conciliación en estado Ingresada",
        [
            {"num": "1", "tit": "La plantilla", "sub": "Descargar plantilla", "pal": "sky", "items": [
                ("Columnas:", "N_FACTURA · TIPO · CNSGLO · VLRACEPTADO · CODCONCEPTO, en ese orden y con esos nombres."),
                ("N_FACTURA:", "Número de factura; debe existir en cartera (vencimientos) y pertenecer al tercero."),
                ("TIPO:", "Tipo de vencimiento (F, G, R, C…). Si hay tipos permitidos configurados, solo esos."),
                ("CNSGLO:", "Obligatorio si TIPO es G, C, R o L. La glosa debe estar respondida, aplicada y radicada."),
            ]},
            {"num": "2", "tit": "Valores", "sub": "Lo que decide el acuerdo", "pal": "orange", "items": [
                ("VLRACEPTADO:", "Valor aceptado por factura, numérico. No puede superar el saldo del vencimiento."),
                ("CODCONCEPTO:", "Código del concepto de nota (CPNT). La plantilla lo prellena con el de IDCOPNOTACONCI."),
                ("Recuperar:", "No va en el archivo: el sistema lo calcula como saldo − aceptado."),
                ("Formato:", ".xlsx o .xls; la primera fila son los encabezados."),
            ]},
            {"num": "3", "tit": "Procesar", "sub": "Agregar Archivo Plano", "pal": "green", "items": [
                ("Vista previa:", "El sistema muestra las filas leídas antes de enviarlas; revise y pulse Procesar."),
                ("Validación por fila:", "Cada fila se acepta o se marca con su error: factura inexistente, otro tercero, sin saldo, glosa sin radicar, concepto inválido, duplicada."),
                ("Resultado:", "Las filas buenas entran como líneas Ingresada; las malas se listan con el motivo para corregir y recargar."),
                ("Nada parcial oculto:", "Lo que entró ya está en el detalle; lo rechazado no. Compare contra el Excel."),
            ]},
            {"num": "4", "tit": "Aplicar concepto", "sub": "Varias facturas a la vez", "pal": "violet", "items": [
                ("Para qué:", "Cambiar el concepto de nota de muchas líneas ya cargadas sin editarlas una por una."),
                ("Cómo:", "Marque las líneas (casilla Sel o Marcar todas de la página) → Aplicar concepto → elija el concepto → Aplicar."),
                ("Qué hace:", "Edita cada línea marcada con el nuevo concepto; informa cuántas quedaron bien y cuáles fallaron."),
                ("Desmarcar:", "Quita la selección. El contador rojo muestra cuántas hay marcadas."),
            ]},
        ],
        pills=[
            ("Primero el concepto por defecto", "Si todas las líneas llevan el mismo concepto, basta con la variable IDCOPNOTACONCI; Aplicar concepto es para excepciones o correcciones masivas."),
            ("Errores con nombre", "El sistema devuelve el mensaje exacto por fila (“La factura no pertenece al tercero…”, “La glosa no esta radicada”…). Corrija en el Excel y vuelva a cargar solo esas filas."),
            ("No hay deshacer de la carga", "Si cargó el archivo equivocado, use Limpiar Todos (borra todas las líneas Ingresada) o Borrar por línea."),
        ],
        accent="#7c3aed",
    )

    # 6. Confirmar
    sketch(
        "conci_confirmar_sketchnote.jpg", BRAND,
        "Confirmar: qué revisa y qué genera el cierre",
        "Botón Confirmar (candado) en la fila de una conciliación Ingresada. Después no se edita",
        [
            {"num": "1", "tit": "Antes de cerrar", "sub": "Validaciones", "pal": "sky", "items": [
                ("Periodo:", "Si FNOT_FECHACONCILIA = CONCILIACION, el periodo contable de la fecha de conciliación debe estar abierto."),
                ("Glosas:", "Toda línea con consecutivo de glosa debe tener la glosa aplicada (cerrada), con fecha de respuesta y radicada."),
                ("Tipos:", "Ninguna línea puede tener un tipo de vencimiento fuera de CONCIGLOSA_TIPOSPERM (si está configurada)."),
                ("Concepto:", "Debe existir el concepto de nota (IDCOPNOTACONCI o el de la línea); si no, no se genera la NC."),
            ]},
            {"num": "2", "tit": "Valor aceptado", "sub": "Nace una nota crédito", "pal": "green", "items": [
                ("Consecutivo:", "Por cada línea con aceptado > 0 se reserva un número de NC: prefijo sede + C + 8 dígitos."),
                ("La NC:", "Clase C, procedencia CONCILIA, concepto de la línea, valor = aceptado, fecha = conciliación u hoy según la variable."),
                ("Aplica:", "La NC se aplica a la cartera de la factura (baja el saldo) y se reliquida la factura."),
                ("Rastro:", "La línea guarda el número de NC (Cns. Nota) y pasa a Cerrada."),
            ]},
            {"num": "3", "tit": "Valor a recuperar", "sub": "Nuevo vencimiento tipo C", "pal": "orange", "items": [
                ("Saldo origen:", "El vencimiento conciliado queda en cero."),
                ("Tipo C:", "El valor a recuperar se registra como vencimiento tipo C (conciliación) de la misma factura, marcado con el Cns. Concilia."),
                ("Si ya había tipo C:", "Se suma al existente (o lo reemplaza si lo que se concilió ya era tipo C)."),
                ("Para qué:", "Ese saldo es el que la EPS pagará en el recaudo; aparece en informes y vencimientos."),
            ]},
            {"num": "4", "tit": "Después", "sub": "Contabilidad y estado", "pal": "violet", "items": [
                ("Asiento:", "Si alguna línea tiene valor a recuperar y la factura no está castigada, se genera el asiento de conciliación (MCPE procedencia CONCI)."),
                ("Cierre:", "Cuando todas las líneas quedan Cerrada, la cabecera pasa a Cerrada."),
                ("Si algo falla:", "Mensaje “La Conciliación No se ha aplicado correctamente…”: revise las líneas que no cerraron y confirme de nuevo."),
                ("Luego:", "Imp.Conci., Imp.NC por línea, Anular si hubo error, y envío a contabilidad desde Otros módulos."),
            ]},
        ],
        pills=[
            ("Línea sin aceptado", "Una línea con aceptado = 0 no genera NC; solo mueve todo el saldo a tipo C. Sirve para formalizar plazos de pago sin descuento."),
            ("Línea sin recuperar", "Una línea con aceptado = saldo genera la NC por el total y no deja vencimiento tipo C: la factura queda saldada por el acuerdo."),
            ("Nada se reabre", "Cerrada no vuelve a Ingresada. Si se confirmó con error, se anula (nota débito) y se crea otra conciliación."),
        ],
        accent="#16a34a",
    )

    # 7. Anular
    sketch(
        "conci_anular_sketchnote.jpg", BRAND,
        "Anular: la conciliación completa o una sola factura",
        "Solo sobre lo Cerrado. Cada reverso crea una nota débito que deshace la nota crédito",
        [
            {"num": "1", "tit": "Anular (cabecera)", "sub": "Fila de la conciliación", "pal": "rose", "items": [
                ("Cuándo:", "Conciliación Cerrada que fue un error completo (tercero equivocado, acuerdo no firmado)."),
                ("Qué hace:", "Recorre cada línea Cerrada, reserva un número de ND (prefijo sede + D) si tenía aceptado y la reversa."),
                ("Resultado:", "Todas las líneas y la cabecera quedan Anulada."),
            ]},
            {"num": "2", "tit": "Anular Item", "sub": "Fila de la factura", "pal": "orange", "items": [
                ("Cuándo:", "Solo una factura del acuerdo quedó mal; el resto sigue vigente."),
                ("Requisitos:", "Línea en Cerrada y sin nota débito previa (si ya tiene Cns. Nota DB no se anula de nuevo)."),
                ("Resultado:", "Esa línea pasa a Anulada; la conciliación sigue Cerrada con las demás."),
            ]},
            {"num": "3", "tit": "Lo que se reversa", "sub": "Cartera", "pal": "sky", "items": [
                ("Nota débito:", "Clase D, procedencia CONCILIA, por el valor aceptado: vuelve a cargar la factura y deshace la NC."),
                ("Tipo C:", "Se borra el vencimiento tipo C creado por la conciliación y se reliquida la factura: el saldo vuelve a su vencimiento original."),
                ("Imp.ND:", "La línea muestra el botón Imp.ND para imprimir la nota débito generada."),
            ]},
            {"num": "4", "tit": "Lo que se reversa", "sub": "Contabilidad", "pal": "violet", "items": [
                ("Asiento inverso:", "Si la línea tenía valor a recuperar, se genera el asiento contrario (MCPE CONCI inverso) por esa línea."),
                ("Periodo:", "El periodo contable debe estar abierto; si está cerrado el reverso falla."),
                ("Comprobante OM:", "Si la conciliación ya fue enviada desde Otros módulos, coordine con contabilidad antes de anular."),
            ]},
        ],
        pills=[
            ("Anular no es borrar", "La conciliación queda con historia: cabecera Anulada, líneas con su NC y su ND. Se sigue viendo en la grilla con filtro Anulada."),
            ("Después de anular", "Las facturas vuelven a tener su saldo y pueden incluirse en una nueva conciliación."),
            ("Ingresada no se anula", "Una conciliación que aún no se confirmó se corrige o se borra (Borrar cabecera tras Limpiar Todos); Anular es solo para Cerrada."),
        ],
        accent="#e11d48",
    )

    # 8. Imprimir y soportes
    sketch(
        "conci_imprimir_sketchnote.jpg", BRAND,
        "Imprimir y adjuntar soportes",
        "Cinco impresiones distintas según el estado, más el escaneo de documentos",
        [
            {"num": "1", "tit": "Imp.Conci.", "sub": "El acta", "pal": "sky", "items": [
                ("Cuándo:", "En cualquier estado, incluso Ingresada: sirve para llevar el borrador a la reunión con la EPS."),
                ("Qué trae:", "Cabecera (tercero, fechas, funcionario externo, Nro. externo) y cada factura con saldo, aceptado y a recuperar."),
                ("Formato:", "PDF en el visor; se descarga o imprime."),
            ]},
            {"num": "2", "tit": "Imp.Comp.", "sub": "Comprobante contable", "pal": "teal", "items": [
                ("Cuándo:", "Conciliación Cerrada y ya contabilizada (Contabilizada = 1 y Nro. Comprobante)."),
                ("Qué trae:", "El comprobante contable generado por el envío desde Otros módulos."),
                ("Si no aparece:", "Aún no se ha enviado a contabilidad; pida a contabilidad el envío."),
            ]},
            {"num": "3", "tit": "Imp.NC / Imp.ND", "sub": "Por factura", "pal": "green", "items": [
                ("Imp.NC:", "En líneas Cerrada o Anulada con nota crédito: imprime la NC que generó el acuerdo."),
                ("Imp.ND:", "En líneas con Cns. Nota DB (anuladas): imprime la nota débito del reverso."),
                ("Mismo formato:", "Es la impresión de Notas DB/CR; también se consulta desde esa ventana."),
            ]},
            {"num": "4", "tit": "Escaneo", "sub": "Documentos adjuntos", "pal": "violet", "items": [
                ("Cuándo:", "Cualquier conciliación no anulada."),
                ("Qué adjuntar:", "Acta firmada por la EPS, correos del acuerdo, soportes de la negociación."),
                ("Dónde queda:", "Archivo asociado al Cns. Concilia (tipo de documento FCONCI); se consulta desde el mismo botón."),
            ]},
        ],
        pills=[
            ("Exportar a Excel", "La grilla de conciliaciones y la del detalle tienen exportación a Excel con los filtros aplicados."),
            ("Historial por factura", "En Informes de cartera → detalle de la factura se listan las conciliaciones en las que estuvo."),
        ],
        accent="#4f46e5",
    )

    # 9. Contabilizar desde Otros módulos
    sketch(
        "conci_contabilidad_sketchnote.jpg", BRAND,
        "Contabilizar: Contabilidad → Otros módulos → Conciliaciones",
        "La operación cierra en cartera; el comprobante contable lo envía contabilidad por periodo",
        [
            {"num": "1", "tit": "Qué se contabiliza", "sub": "Dos movimientos", "pal": "sky", "items": [
                ("Nota crédito:", "El valor aceptado baja la cartera por la vía de Notas DB/CR (su propia contabilización)."),
                ("Valor a recuperar:", "Al confirmar se arma el asiento de conciliación (procedencia CONCI) si la factura no está castigada."),
                ("Pendiente de envío:", "La conciliación queda Cerrada con Contabilizada = 0 hasta que contabilidad la envía."),
            ]},
            {"num": "2", "tit": "La bandeja", "sub": "Lista por periodo", "pal": "orange", "items": [
                ("Filtro:", "Año y mes contable (fecha de conciliación) y estado: no enviadas / enviadas."),
                ("Columnas:", "Cns. Concilia, tercero, fecha, estado, Contabilizada, Nro. Comprobante."),
                ("Semáforo:", "0 = pendiente, 1 = contabilizada, 2 = en proceso: solo las 0 se pueden marcar."),
            ]},
            {"num": "3", "tit": "Enviar", "sub": "Envío masivo", "pal": "green", "items": [
                ("Cómo:", "Marque las conciliaciones del periodo → Enviar a contabilidad."),
                ("Qué hace:", "Genera el comprobante y marca Contabilizada = 1 con el Nro. Comprobante."),
                ("Resultado:", "En Administrativo → Concilia aparece el número y se habilita Imp.Comp."),
            ]},
            {"num": "4", "tit": "Cuidados", "sub": "Antes y después", "pal": "rose", "items": [
                ("Periodo cerrado:", "Si el periodo contable está cerrado, el asiento al confirmar y el reverso al anular fallan."),
                ("Anular tras enviar:", "Si ya hay comprobante y se anula, el reverso genera su propio asiento; avise a contabilidad."),
                ("No confundir:", "Conciliaciones contables (bancos) es otra ventana y otro proceso."),
            ]},
        ],
        pills=[
            ("Dos ventanas, dos roles", "Cartera opera en Administrativo → Concilia; contabilidad envía desde Contabilidad → Otros módulos. Ninguna reemplaza a la otra."),
            ("Castigadas no contabilizan", "Las facturas marcadas como castigadas no generan asiento de conciliación por el valor a recuperar."),
        ],
        accent="#0d9488",
    )

    # 10. Configuración
    sketch(
        "conci_config_sketchnote.jpg", BRAND,
        "Configuración: variables y catálogos que deben existir",
        "Cuatro variables del sistema y dos catálogos. Sin el concepto de nota, la conciliación no cierra",
        [
            {"num": "1", "tit": "IDCOPNOTACONCI", "sub": "Concepto de nota por defecto", "pal": "rose", "items": [
                ("Qué es:", "Código del concepto (CPNT) con el que se generan las notas crédito y débito de conciliación."),
                ("Dónde se usa:", "Se precarga en cada línea nueva y en la plantilla Excel; el cierre lo exige."),
                ("Si falta:", "Al confirmar: “NO EXISTE CONFIGURACION PARA GENERAR LA NOTA CREDITO” y la conciliación no cierra."),
            ]},
            {"num": "2", "tit": "FNOT_FECHACONCILIA", "sub": "Fecha de las notas", "pal": "orange", "items": [
                ("CONCILIACION:", "Las NC llevan la fecha de conciliación; el periodo contable de esa fecha debe estar abierto."),
                ("Otro valor / vacío:", "Las NC llevan la fecha del día en que se confirma."),
                ("Efecto:", "Decide en qué mes contable cae el descuento."),
            ]},
            {"num": "3", "tit": "CONCIGLOSA_TIPOSPERM", "sub": "Tipos de vencimiento permitidos", "pal": "sky", "items": [
                ("Qué es:", "Lista separada por comas (ej. G,R,C,L) de tipos que se pueden conciliar."),
                ("Vacío:", "Sin filtro: cualquier vencimiento con saldo puede conciliarse."),
                ("Dónde actúa:", "Filtra Seleccionar Factura, valida cada línea y la carga Excel, y vuelve a revisar al confirmar."),
            ]},
            {"num": "4", "tit": "CONCIGLOSA_NREXTERNO", "sub": "Formato del Nro. Externo", "pal": "violet", "items": [
                ("alfanumerico:", "El Nro. Externo acepta letras y números."),
                ("Otro valor / vacío:", "Solo números; al teclear letras avisa “No se pueden ingresar letras”."),
                ("Catálogos:", "CPNT (conceptos de nota) y FCGLO (motivos de glosa) deben tener los códigos que usará cartera."),
            ]},
        ],
        pills=[
            ("Consecutivos", "Las NC usan el consecutivo @FNOTC y las ND el @FNOTD por sede; la cabecera usa @CONCI. Deben existir en la configuración de consecutivos."),
            ("Contabilidad", "El asiento de conciliación necesita el tipo de comprobante de conciliaciones y la cuenta de glosas (TTEC); eso lo parametriza contabilidad."),
            ("Acceso", "La ventana se controla por el permiso de menú Administrativo → Concilia; no hay botones con permiso individual."),
        ],
        accent="#64748b",
    )

    print("OK sketchnotes conciliaciones generadas en", IMG_DIR)


if __name__ == "__main__":
    main()
