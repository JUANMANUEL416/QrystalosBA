# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del capítulo Cartera · Glosas.

Uso:  python libro/scripts/gen_glosas_sketchnotes.py
Salida: libro/img/glosas_*_sketchnote.jpg (reutiliza el motor de gen_recaudos_sketchnotes).

Contenido contrastado 2026-10-03 con Qrystalos2 (AdiGlosasPage, RespGlosas, ImpRespGlo, DevolResGlo,
RecepGlosas, ConfGlo, AdminGlosasPage, EnvioRecepGlo, RecepRtasG, RadRptaGlo, AsignarResponsableGlosa,
manuales Help*) e IXONLINE/SQL SPQ_FGLO_COL + SPK_RESPUESTAGLOSA + SPK_FINALIDAD_GLOSAS
(PREVERSION idéntica a la liberada 2.0.7).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND = "QRYSTALOS IPS · CARTERA · GLOSAS"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. Qué es una glosa y quién hace qué
    sketch(
        "glosas_que_es_sketchnote.jpg", BRAND,
        "Qué es una glosa y quién hace qué",
        "La EPS objeta parte de una factura; cartera la registra, auditoría la responde y cartera la radica",
        [
            {"num": "1", "tit": "La glosa", "sub": "Documento FGLO", "pal": "sky", "items": [
                ("Qué es:", "La objeción de la EPS a una factura: un valor que no paga mientras no se aclare."),
                ("Nace:", "Al aplicar un recaudo con ingreso GLOSAS. Una glosa por factura glosada."),
                ("Lleva:", "Factura, valor glosado, motivos (códigos del catálogo), observaciones y estado."),
                ("Vive en:", "Dos ventanas: Adm. glosas (cartera) y Auditoría → Glosas (auditor)."),
            ]},
            {"num": "2", "tit": "Cartera", "sub": "Administrativo → Adm. glosas", "pal": "orange", "items": [
                ("Registra:", "Carga el recaudo GLOSAS con factura, valor y motivos."),
                ("Envía:", "Arma la entrega a auditoría (Enviar a auditoría o Envíos Auditoría)."),
                ("Recibe:", "Recepciona las respuestas que vuelven de auditoría."),
                ("Radica:", "Radica el lote de respuestas ante la EPS y descarga FEV-RIPS."),
            ]},
            {"num": "3", "tit": "Auditoría", "sub": "Auditoría → Glosas", "pal": "violet", "items": [
                ("Recibe:", "Recepciona la entrega para que las glosas queden en su bandeja."),
                ("Responde:", "Acepta o defiende cada motivo: total o ítem por ítem."),
                ("Aplica:", "Cierra la glosa; si acepta valor nace una nota crédito."),
                ("Imprime y devuelve:", "Arma el lote de respuestas y lo envía a cartera."),
            ]},
            {"num": "NO ES", "tit": "Lo que no es", "sub": "Evite el camino equivocado", "pal": "rose", "items": [
                ("Conciliación:", "El acuerdo global con la EPS es Cartera · Conciliaciones (FCONCI)."),
                ("Devolución de factura:", "La EPS devuelve la factura entera: ingreso DEVOLUCION en Recaudos."),
                ("Nota crédito a mano:", "La NC por glosa la genera el sistema al aplicar; no se crea en Notas DB/CR."),
                ("Glosas a proveedores:", "Las de cuentas por pagar están en CxP → Auditoría CxP."),
            ]},
        ],
        pills=[
            ("Dos departamentos", "Las variables IDFDEPCARTERA e IDFDEPAUDITORIA dicen en qué dependencia está cada glosa; sin ellas la entrega falla."),
            ("Aceptar = nota crédito", "Lo que auditoría acepta baja la factura con una NC automática; lo que defiende queda por recuperar."),
            ("15 días hábiles", "El plazo legal para responder corre desde el día siguiente al pago del recaudo; la grilla lo muestra en colores."),
            ("Punto de no retorno", "Una glosa radicada no se desradica; una respuesta ya impresa no se desaplica sin reabrir el lote."),
        ],
        accent="#0284c7",
    )

    # 2. El ciclo completo
    sketch(
        "glosas_ciclo_sketchnote.jpg", BRAND,
        "El ciclo completo: de la objeción de la EPS a la radicación",
        "Siete momentos que alternan entre cartera y auditoría. Los capítulos siguientes detallan cada uno",
        [
            {"num": "PASO 01", "tit": "Registrar", "sub": "Cartera · Recaudos", "pal": "sky", "items": [
                ("Recaudo:", "Nuevo recaudo con ingreso GLOSAS; facturas con valor glosado y motivos."),
                ("Aplicar:", "Al aplicar nace la glosa (FGLO) por cada factura del recaudo."),
            ]},
            {"num": "PASO 02", "tit": "Enviar", "sub": "Cartera → Auditoría", "pal": "orange", "items": [
                ("Botón:", "Enviar a auditoría (en el recaudo) o Envíos Auditoría (Adm. glosas)."),
                ("Entrega:", "Se crea un consecutivo de entrega con las glosas; se cierra e imprime."),
            ]},
            {"num": "PASO 03", "tit": "Recibir", "sub": "Auditoría · Recepción", "pal": "violet", "items": [
                ("Recepcionar:", "El auditor recepciona la entrega completa (no glosa por glosa)."),
                ("Efecto:", "Las glosas pasan a la dependencia auditoría y aparecen en Responder."),
            ]},
            {"num": "PASO 04", "tit": "Responder y aplicar", "sub": "Auditoría · Responder Glosas", "pal": "green", "items": [
                ("Responder:", "Edita Glosa: tipo total o por ítems, concepto, valor aceptado."),
                ("Aplicar:", "Cierra la glosa; genera NC por lo aceptado y cuenta por recuperar."),
            ]},
            {"num": "PASO 05", "tit": "Imprimir y devolver", "sub": "Auditoría · Respuestas / Devolver", "pal": "teal", "items": [
                ("Lote:", "Nueva Impresión por tercero; asignar glosas cerradas; Imprimir; Cerrar."),
                ("Devolver:", "Enviar a Cartera o Nueva Entrega → Traer Respuestas → Cerrar Envío."),
            ]},
            {"num": "PASO 06", "tit": "Recepcionar", "sub": "Cartera · Recepción de Respuestas", "pal": "amber", "items": [
                ("Recepcionar:", "Cartera recibe la entrega de respuestas; las glosas vuelven a cartera."),
                ("Efecto:", "Quedan disponibles en CXC Glosas para radicar."),
            ]},
            {"num": "PASO 07", "tit": "Radicar", "sub": "Cartera · CXC Glosas", "pal": "slate", "items": [
                ("Radicar:", "Fecha de radicado (no futura, máximo 30 días atrás)."),
                ("FEV-RIPS:", "Si hubo valor aceptado, la NC se puede ver y descargar para la DIAN."),
            ]},
        ],
        pills=[
            ("Atajo automático", "Si el recaudo se aplica con paso a seguir 4 o 6, el sistema hace los pasos 2 a 6 solo (respuesta automática)."),
            ("Paso a seguir 5", "Deja el detalle cargado en auditoría; el auditor solo responde y aplica."),
            ("Paso a seguir 3", "Recepcionar: cartera envía a mano con el botón Enviar a auditoría."),
        ],
        accent="#7c3aed",
    )

    # 3. Dónde nace: el recaudo GLOSAS
    sketch(
        "glosas_origen_sketchnote.jpg", BRAND,
        "Dónde nace la glosa: el recaudo con ingreso GLOSAS",
        "Sin recaudo no hay glosa. Lo que cartera digita aquí es lo que el auditor verá como motivos",
        [
            {"num": "PASO 01", "tit": "Nuevo recaudo", "sub": "Ingreso = GLOSAS", "pal": "sky", "items": [
                ("Cabecera:", "Tercero (EPS), fecha de pago, ingreso GLOSAS, paso a seguir (3, 4, 5 o 6)."),
                ("Fecha de pago:", "Desde el día siguiente corre el plazo de 15 días hábiles para responder."),
            ]},
            {"num": "PASO 02", "tit": "Facturas y motivos", "sub": "Traer Varias o plantilla Excel", "pal": "orange", "items": [
                ("Plantilla:", "N_FACTURA, VLRGLOSA, MOTIVO1, MOTIVO2 (códigos del catálogo de glosa)."),
                ("Catálogo:", "El código debe existir en Configurar Glosas como clase GLOSA y activo."),
                ("Si no existe:", "La glosa nace igual pero sin motivos; el auditor tendrá que agregarlos."),
            ]},
            {"num": "PASO 03", "tit": "Aplicar el recaudo", "sub": "Nace la glosa", "pal": "green", "items": [
                ("Efecto:", "Una glosa (FGLO) por factura con el valor glosado y hasta dos motivos."),
                ("Cartera:", "La factura queda con el valor glosado pendiente, no como pago."),
                ("Técnico:", "SPQ_FPAG_COL · APLICARPAGO → SPK_PAGOSCXC (FGLO + FGLOCG)."),
            ]},
            {"num": "PASO 04", "tit": "Paso a seguir", "sub": "Qué pasa después de aplicar", "pal": "violet", "items": [
                ("3 Recepcionar:", "Nada automático: cartera pulsa Enviar a auditoría."),
                ("4 Responder:", "El sistema envía, recibe, responde el total, imprime y devuelve a cartera."),
                ("5 Detalle:", "Envía, recibe y carga motivos e ítems; el auditor responde a mano."),
                ("6 Detalle y responde:", "Como 5 y además responde con el detalle de la plantilla."),
            ]},
        ],
        pills=[
            ("Concepto automático", "Los pasos 4 y 6 exigen la variable IDCONCEPRPTAGLO_AUTO (concepto de respuesta); sin ella, el apply falla."),
            ("Plantilla de detalle", "Los pasos 5 y 6 leen la segunda plantilla (DETALLE_RESPONDER) con ítems, código de respuesta y valor aceptado."),
            ("Técnico", "SPK_FINALIDAD_GLOSAS orquesta ENVIAR_AUDIT → RECIBIR_GLOSA → SPK_RESPUESTAGLOSA → FGLOI → ENVIAR_RESPUESTA → RECIBIR_RPTASGLOSA."),
        ],
        accent="#ea580c",
    )

    # 4. Entrega: enviar y recibir
    sketch(
        "glosas_entrega_sketchnote.jpg", BRAND,
        "La entrega: cómo viaja la glosa de cartera a auditoría",
        "Nada se responde si antes no se envió y se recepcionó. La entrega es el sobre; las glosas, su contenido",
        [
            {"num": "A", "tit": "Enviar desde el recaudo", "sub": "Cartera · Recaudos", "pal": "sky", "items": [
                ("Botón:", "Enviar a auditoría en el recaudo aplicado (permiso BEnviarAuditoriaFPAG)."),
                ("Crea:", "Una entrega proceso GLOSAS con todas las glosas del recaudo que estén en cartera."),
                ("Regla:", "Solo glosas sin entrega previa y en la dependencia de cartera."),
            ]},
            {"num": "B", "tit": "Enviar desde Adm. glosas", "sub": "Pestaña Envíos Auditoría", "pal": "orange", "items": [
                ("Nueva Entrega:", "Abre una entrega vacía con consecutivo."),
                ("Traer Recaudo / Respuesta:", "Busca recaudos o facturas y los agrega (una factura no puede ir en dos entregas abiertas)."),
                ("Cerrar Envío:", "La entrega queda lista; Imprimir Entrega genera el comprobante PDF."),
                ("Retirar:", "Quita una glosa mientras la entrega no esté cerrada ni recibida."),
            ]},
            {"num": "C", "tit": "Recibir en auditoría", "sub": "Auditoría → Glosas → Recepción", "pal": "violet", "items": [
                ("Grilla:", "Entregas GLOSAS hacia auditoría: Sin Recibir / Recibido, usuario y fechas."),
                ("Recepcionar Glosas:", "Botón visible solo con la entrega Sin Recibir; recibe todas de una vez."),
                ("Efecto:", "Las glosas pasan a la dependencia auditoría y aparecen en Responder Glosas."),
                ("Exportar:", "Icono Excel exporta la grilla filtrada."),
            ]},
        ],
        pills=[
            ("No hay recepción parcial", "Si solo debe entrar una parte, cartera debe separar la entrega antes de cerrarla."),
            ("Una glosa, una entrega", "Mientras la glosa tenga entrega activa no entra en otra; Retirar la libera."),
            ("Técnico", "SPQ_FPAG_COL · ENVIAR_AUDIT · SPQ_FGLO_COL · ENT_ENVGLOSA / ENT_ADDRECAUDO / ENTD_DELITEMENVIO / RECIBIR_GLOSA."),
        ],
        accent="#0891b2",
    )

    # 5. Responder: total o por ítems
    sketch(
        "glosas_responder_sketchnote.jpg", BRAND,
        "Responder la glosa: total o ítem por ítem",
        "El auditor decide cuánto acepta y cuánto defiende. La suma de motivos debe cuadrar con el valor glosado",
        [
            {"num": "PASO 01", "tit": "Edita Glosa", "sub": "Cabecera de la respuesta", "pal": "sky", "items": [
                ("Tipo glosa:", "Total o Parcial (si glosaron toda la factura o parte)."),
                ("Tipo respuesta:", "Total (una sola respuesta) o Item (línea por línea)."),
                ("Obligatorios:", "Concepto de respuesta y usuario que responde; fecha de respuesta (hoy si vacía)."),
                ("Valores:", "Vlr. Aceptado editable; Vlr. Recuperar = glosa − aceptado."),
            ]},
            {"num": "PASO 02", "tit": "Motivos", "sub": "Respuesta Total", "pal": "orange", "items": [
                ("Agregar Motivo:", "Código del catálogo (clase GLOSA activo), valor y observación."),
                ("Regla:", "La suma de los motivos debe ser igual al valor glosado para poder aplicar."),
                ("Respuesta Total:", "Texto obligatorio cuando el tipo de respuesta es Total."),
            ]},
            {"num": "PASO 03", "tit": "Ítems", "sub": "Respuesta Item", "pal": "violet", "items": [
                ("Agregar Item:", "Servicio o concepto, cantidad, valor unitario, código de glosa y de respuesta."),
                ("Por ítem:", "Vlr. aceptado y vlr. a recuperar; respuesta y observación del responsable."),
                ("Eliminar Todo:", "Borra ítems y motivos de la glosa abierta para empezar de nuevo."),
                ("Regla:", "La suma de los ítems también debe igualar el valor glosado."),
            ]},
            {"num": "PASO 04", "tit": "Aplicar", "sub": "Cuando todo cuadra", "pal": "green", "items": [
                ("Botón:", "Aplicar Glosa aparece solo si glosa abierta y sumas iguales."),
                ("Aplicar y Anula Factura:", "Mismas condiciones; además el valor glosado debe ser igual al valor de la factura."),
                ("Después:", "La glosa queda Cerrada; aparece Desaplicar Rpta."),
            ]},
        ],
        pills=[
            ("Solo el autor", "Con la variable RESTGLO_AUTOR_UNICO = SI, solo quien registró la glosa edita o borra ítems y motivos."),
            ("Inf. motivos", "Botón que descarga un Excel de las glosas filtradas con la descripción completa de cada motivo."),
            ("Liberar pacientes", "Solo con glosa abierta, factura masiva CE/CI y permiso Brw:Glosas · PermitirLiberarPac."),
            ("Técnico", "SPQ_FGLO_COL · TRAE_MOTIGLO · CRUD_FGLO · CRUD_FGLOCG · CRUD_FGLOD · BORRAR_TODO_ITEMS."),
        ],
        accent="#16a34a",
    )

    # 6. Respuesta masiva por Excel
    sketch(
        "glosas_masiva_sketchnote.jpg", BRAND,
        "Responder por Excel: dos plantillas distintas",
        "Carga masiva reemplaza motivos e ítems completos; Rpta Det. responde ítem por ítem con validación estricta",
        [
            {"num": "A", "tit": "Carga masiva", "sub": "Botón Carga masiva", "pal": "violet", "items": [
                ("Advertencia:", "Reemplaza (borra e inserta) todos los motivos e ítems de cada glosa del archivo. No se deshace."),
                ("Comunes:", "CNSGLO · N_FACTURA · VLRGLOSA_TOTAL_GLOSA."),
                ("Tipo Total:", "CODGLOSA_MOTIVO · VLR_MOTIVO · OBSERVACION_MOTIVO."),
                ("Tipo Item:", "TIPO_ITEM (C/S) · IDSERVICIO_O_CONCEPTO · CODGLOSA_ITEM · CODRPTA_ITEM · RESPUESTA_ITEM · CANTIDAD · VR_UNITARIO · VLRGLOSA_ITEM · VLRACEPTADO_ITEM."),
                ("Errores:", "Descarga Reporte_Errores_Carga_Glosas.xlsx con la fila y la causa."),
            ]},
            {"num": "B", "tit": "Rpta Det.", "sub": "Respuesta por detalles", "pal": "teal", "items": [
                ("Paso 1:", "Generar y descargar plantilla (.xlsx) con las glosas filtradas y sus ítems."),
                ("Obligatorios:", "CODGLOSA · CODRPTA · CNSGLO · ITEM · VLRACEPTADO · RESPUESTA (mínimo 10 caracteres)."),
                ("VALIDACION:", "Columna que resume el resultado; después vienen columnas informativas (FRADICADO, FNOTIGLOSA, FFACTURA…)."),
                ("Todo o nada:", "Si el archivo no es válido no se procesa ninguna fila; devuelve un Excel solo con las filas con error."),
                ("Paso 3:", "Enviar al servidor. Después hay que Aplicar cada glosa igual que a mano."),
            ]},
            {"num": "C", "tit": "Cuál usar", "sub": "Regla práctica", "pal": "amber", "items": [
                ("Muchas glosas, respuesta total:", "Carga masiva con las columnas de motivo."),
                ("Glosas con ítems ya cargados:", "Rpta Det.: respeta los ítems y solo pone respuesta y valor aceptado."),
                ("Pocas glosas:", "A mano con Edita Glosa / Agregar Item."),
                ("Ninguna aplica sola:", "Las dos cargas dejan la glosa abierta; Aplicar sigue siendo manual."),
            ]},
        ],
        pills=[
            ("Técnico", "SPQ_FGLO_COL · CARGA_MASIVA_RESPUESTA_GLOSA · TRAER_GLOSAS_VALIDADOS · PLANTILLA_RPTA_DETALLES · SUBIR_RPTA_DETALLES."),
            ("Permiso del lote", "La pestaña Respuestas (lotes de impresión) usa MENUQ_GLOSAS · ABRIR_CERRAR_RESPUESTA; las cargas no tienen permiso por botón."),
        ],
        accent="#7c3aed",
    )

    # 7. Qué pasa al aplicar
    sketch(
        "glosas_aplicar_sketchnote.jpg", BRAND,
        "Qué hace el sistema cuando el auditor pulsa Aplicar",
        "Cierra la glosa, genera la nota crédito por lo aceptado y deja por recuperar lo defendido",
        [
            {"num": "1", "tit": "Revisa", "sub": "Antes de tocar nada", "pal": "sky", "items": [
                ("Glosa abierta:", "«No se encontró el Cnsglosa o ya fue aplicado»."),
                ("Sumas:", "Motivos (y los ítems si es tipo Item) iguales al valor glosado."),
                ("Periodos:", "Cartera y contabilidad abiertos en la fecha de respuesta: «Periodo contable cerrado o no existe»."),
            ]},
            {"num": "2", "tit": "Lo aceptado", "sub": "Vlr. Aceptado > 0", "pal": "green", "items": [
                ("Nota crédito:", "Genera una NC con procedencia AUDITORIA por el valor aceptado."),
                ("Cartera:", "Baja el saldo de la factura y la reliquida."),
                ("Si falla el detalle:", "«No se pudo generar el detalle de la nota crédito. La glosa no se aplicó»."),
            ]},
            {"num": "3", "tit": "Lo defendido", "sub": "Vlr. Recuperar > 0", "pal": "orange", "items": [
                ("Cuenta por recuperar:", "Registra el valor a recuperar (FCXCDV) para cobrarlo a la EPS."),
                ("Siguiente:", "Entra al lote de impresión y a la radicación."),
            ]},
            {"num": "4", "tit": "Cierra y contabiliza", "sub": "Cerrada = 1", "pal": "violet", "items": [
                ("Estado:", "La glosa queda Cerrada; aparece Desaplicar Rpta."),
                ("Contabilidad:", "Genera el asiento de la respuesta (cuenta del concepto)."),
                ("Técnico:", "SPQ_FGLO_COL · APLICAR_GLOSA → SPK_RESPUESTAGLOSA → SPK_NOTASCXC · SPK_RELIQUIDA_FTR · SPK_CONTAB_FGLO."),
            ]},
            {"num": "5", "tit": "Desaplicar", "sub": "Volver atrás", "pal": "rose", "items": [
                ("Cuándo:", "Glosa cerrada y aún no asignada a un lote de impresión."),
                ("Hace:", "Reversa la NC si hubo aceptado, limpia el comprobante y reabre la glosa."),
                ("Bloqueos:", "«La factura de esta glosa ya se encuentra anulada» · «Comprobante contable no confirmado»."),
            ]},
        ],
        pills=[
            ("Aplicar y Anula Factura", "Si el valor glosado es igual al valor de la factura, acepta todo y anula la factura (SPK_GLOSAANULAFTR)."),
            ("Contabilizada", "La columna Contabilizada sigue el mismo semáforo que recaudos: 0 pendiente, 1 enviada, 2 con error. Contabilidad → Otros módulos → Glosas la cierra."),
        ],
        accent="#16a34a",
    )

    # 8. Plazo y responsables
    sketch(
        "glosas_plazo_sketchnote.jpg", BRAND,
        "El plazo de respuesta y el responsable de cada glosa",
        "15 días hábiles desde el día siguiente al pago. La grilla de Responder lo pinta en colores",
        [
            {"num": "15", "tit": "Cómo se cuenta", "sub": "Columna Días", "pal": "sky", "items": [
                ("Inicio:", "El día siguiente a la fecha de pago del recaudo (ese día no cuenta)."),
                ("Hábiles:", "Domingos y festivos (tabla FES) no cuentan; el sábado solo si GLO_DIAS_HASTASABADO = SI."),
                ("Vencida:", "El primer hábil después del plazo marca 0; luego −1, −2…"),
                ("Cerrada:", "La glosa aplicada deja de contar días."),
            ]},
            {"num": "●", "tit": "Colores", "sub": "Filtro Días y Ord. días", "pal": "green", "items": [
                ("Verde 6–15:", "Hay margen."),
                ("Ámbar 1–5:", "Próxima a vencer."),
                ("Rojo Venc.:", "0 o negativo: plazo vencido."),
                ("Ord. días:", "Ordena la grilla por días restantes para atender primero lo urgente."),
            ]},
            {"num": "👤", "tit": "Asignar responsable", "sub": "Botón con permiso", "pal": "violet", "items": [
                ("Permiso:", "MENUQ_GLOSAS · BASIGNARRESPONSABLE; sin él el botón no aparece."),
                ("Individual o masivo:", "Filtra por tercero, recaudo, factura, entrega, fechas y sede; asigna una o varias."),
                ("Datos:", "Usuario activo, fecha de asignación y fecha límite."),
                ("Quitar:", "Individual o masivo; todo queda en el log de cambios."),
            ]},
            {"num": "⚑", "tit": "Reglas", "sub": "Lo que exige el sistema", "pal": "amber", "items": [
                ("Solo en auditoría:", "La glosa debe estar recibida en auditoría y abierta."),
                ("Filtro Asignado A:", "En Responder Glosas cada auditor filtra las suyas."),
                ("Autor único:", "Con RESTGLO_AUTOR_UNICO = SI, solo quien registró la glosa modifica ítems y motivos."),
            ]},
        ],
        pills=[
            ("Técnico", "SPQ_FGLO_COL · ASIGNAR_RESPONSABLE_GLOSA (ACCION ASIGNAR / QUITAR) → FGLO.ASIGNADOA, FASIGNA, FLIMITE + USLOG."),
            ("Días en pantalla", "El cálculo de días lo hace la consulta de la grilla (no el SP): si cambia la variable de sábado, cambia el conteo al refrescar."),
        ],
        accent="#ca8a04",
    )

    # 9. Lotes de impresión y devolución
    sketch(
        "glosas_lotes_sketchnote.jpg", BRAND,
        "Imprimir las respuestas y devolverlas a cartera",
        "Las glosas cerradas se agrupan por tercero en un lote, se imprimen y viajan de vuelta en una entrega",
        [
            {"num": "PASO 01", "tit": "Nueva Impresión", "sub": "Pestaña Respuestas", "pal": "sky", "items": [
                ("Lote:", "Un lote por tercero y usuario; no puede haber dos abiertos del mismo tercero."),
                ("Panel derecho:", "Glosas cerradas disponibles; Asignar una a una o Asignar Todas."),
                ("Panel izquierdo:", "Glosas del lote; Retirar o Retirar Todas mientras Impresiones = 0."),
            ]},
            {"num": "PASO 02", "tit": "Imprimir y cerrar", "sub": "Contador de impresiones", "pal": "orange", "items": [
                ("Imprimir:", "Pregunta si incrementa el contador; genera el documento de respuestas."),
                ("Cerrar:", "Con Impresiones = 0 y al menos una glosa asignada (permiso MENUQ_GLOSAS · ABRIR_CERRAR_RESPUESTA)."),
                ("Abrir:", "Reabre un lote impreso si no está radicado ni en cartera."),
            ]},
            {"num": "PASO 03", "tit": "Enviar a Cartera", "sub": "Desde el lote", "pal": "green", "items": [
                ("Condición:", "Lote impreso (Impresiones > 0), sin radicar y aún no en cartera."),
                ("Efecto:", "Crea la entrega de respuestas hacia cartera con las glosas del lote."),
            ]},
            {"num": "PASO 04", "tit": "Devolver (manual)", "sub": "Pestaña Devolver", "pal": "violet", "items": [
                ("Nueva Entrega:", "Entrega de respuestas vacía."),
                ("Traer Respuestas / Respuesta:", "Agrega todas las respuestas disponibles del tercero o una a una."),
                ("Cerrar Envío:", "La entrega queda lista; Imprimir Entrega solo cerrada o recibida."),
            ]},
        ],
        pills=[
            ("Una glosa, un lote", "La glosa asignada a un lote no entra en otro; Desaplicar exige retirarla primero."),
            ("Exportar", "Las grillas de lotes y entregas exportan a Excel (EXPORTA_RPTAGLOSAS)."),
            ("Técnico", "SPQ_FGLO_COL · CRUD_FGLOI · CRUD_FGLOID · IMP_RESPUESTA · ABRIR/CERRAR_IMPRESION · ENVIAR_RESPUESTA · ENT_RPTAGLOSA · ENT_ADDRESPGLO · ENT_CIERRARPTAGLOSA."),
        ],
        accent="#0891b2",
    )

    # 10. Cartera recibe y radica
    sketch(
        "glosas_radicar_sketchnote.jpg", BRAND,
        "Cartera recibe las respuestas y las radica ante la EPS",
        "Adm. glosas cierra el ciclo: recepcionar la entrega, radicar el lote y entregar la nota crédito electrónica",
        [
            {"num": "PASO 01", "tit": "Recepción de Respuestas", "sub": "Adm. glosas · pestaña Recibir", "pal": "sky", "items": [
                ("Grilla:", "Entregas de auditoría hacia cartera: Sin Recibir / Recibido."),
                ("Recepcionar Respuestas:", "Solo con la entrega Sin Recibir; pide confirmación; no se revierte."),
                ("Efecto:", "Las glosas vuelven a la dependencia cartera y quedan listas para radicar."),
            ]},
            {"num": "PASO 02", "tit": "CXC Glosas", "sub": "Adm. glosas · pestaña Radicar", "pal": "orange", "items": [
                ("Grilla:", "Lotes de respuesta por tercero: Radicado 0/1, fecha y usuario."),
                ("Radicar:", "Diálogo con Fecha Radicado: no futura y máximo 30 días hacia atrás."),
                ("Efecto:", "Marca el lote y sus glosas como radicadas; registra fecha y usuario."),
            ]},
            {"num": "PASO 03", "tit": "FEV-RIPS", "sub": "Nota de ajuste electrónica", "pal": "green", "items": [
                ("Botón FEVRIPS:", "Por factura, solo si hubo valor aceptado: muestra la NC y su XML con la DIAN."),
                ("Descargar FEV-RIPS:", "Baja el archivo del lote para enviarlo a la EPS."),
                ("CUV:", "Filtro Validados / Sin validar según el código único de validación."),
            ]},
            {"num": "PASO 04", "tit": "Después", "sub": "Lo que sigue", "pal": "violet", "items": [
                ("Cobrar lo defendido:", "El valor a recuperar queda en cartera para el siguiente recaudo de la EPS."),
                ("Contabilidad:", "Contabilidad → Otros módulos → Glosas envía las respuestas con Contabilizada = 0."),
                ("Imprimir:", "Comprobante de radicación en PDF desde la misma pestaña."),
            ]},
        ],
        pills=[
            ("No se desradica", "Una vez radicado el lote, el estado no vuelve atrás; verifique la fecha antes de confirmar."),
            ("Técnico", "SPQ_FGLO_COL · RECIBIR_RPTASGLOSA · FGLOI_RADICA → SPK_RADICAGLOSAS."),
        ],
        accent="#ea580c",
    )

    # 11. Configurar: catálogo y variables
    sketch(
        "glosas_config_sketchnote.jpg", BRAND,
        "Configurar glosas: el catálogo de códigos y las variables",
        "Lo que debe existir antes de la primera glosa",
        [
            {"num": "FCGLO", "tit": "Códigos de glosa", "sub": "Auditoría → Glosas → Configurar", "pal": "sky", "items": [
                ("Campos:", "Código, descripción, clase y estado."),
                ("Clases:", "GLOSA (motivos de la EPS) · DEVOLUCION (devolución de factura) · RESPUESTA (códigos con que responde la IPS)."),
                ("Estado:", "Inactivo no se usa en glosas nuevas; las existentes conservan la referencia."),
                ("Regla:", "No borre códigos en uso: desactívelos."),
            ]},
            {"num": "DEP", "tit": "Dependencias", "sub": "Variables del sistema", "pal": "orange", "items": [
                ("IDFDEPCARTERA:", "Dependencia de cartera; donde nace y se radica la glosa."),
                ("IDFDEPAUDITORIA:", "Dependencia de auditoría; donde se responde."),
                ("Sin ellas:", "«IDFDEPAUDITORIA no existe en FDEP»: ninguna entrega funciona."),
            ]},
            {"num": "VAR", "tit": "Comportamiento", "sub": "Variables del sistema", "pal": "violet", "items": [
                ("IDCONCEPRPTAGLO_AUTO:", "Concepto de respuesta para el circuito automático (paso a seguir 4 y 6)."),
                ("GLO_DIAS_HASTASABADO:", "SI cuenta el sábado como hábil en el plazo de 15 días."),
                ("RESTGLO_AUTOR_UNICO:", "SI restringe ítems y motivos a quien registró la glosa."),
            ]},
            {"num": "PERM", "tit": "Permisos", "sub": "USGRUH por control", "pal": "green", "items": [
                ("Brw:Glosas · PermitirLiberarPac:", "Botón Liberar pacientes."),
                ("MENUQ_GLOSAS · ABRIR_CERRAR_RESPUESTA:", "Cerrar / Abrir lotes de impresión."),
                ("MENUQ_GLOSAS · BASIGNARRESPONSABLE:", "Botón Asignar responsable."),
                ("Recaudos:", "BEnviarAuditoriaFPAG (enviar) · BImpEntregaGloFPAG (imprimir entrega)."),
            ]},
        ],
        pills=[
            ("Periodos", "Aplicar una respuesta exige mes abierto en cartera y contabilidad en la fecha de respuesta."),
            ("Catálogo en Recaudos", "La plantilla GLOSAS de Recaudos lista los mismos códigos (CODIGO_GLOSA); si el código no está activo, la glosa nace sin motivo."),
            ("Técnico", "SPQ_FGLO_COL · CRUD_FCGLO."),
        ],
        accent="#475569",
    )

    print("ok sketchnotes glosas")


if __name__ == "__main__":
    main()
