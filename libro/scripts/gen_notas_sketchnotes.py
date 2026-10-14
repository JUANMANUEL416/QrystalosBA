# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del capítulo Cartera · Notas débito/crédito.

Uso:  python libro/scripts/gen_notas_sketchnotes.py
Salida: libro/img/notas_*_sketchnote.jpg (reutiliza el motor de gen_recaudos_sketchnotes).

Contenido contrastado 2026-10-03 con Qrystalos2 (NotasDBCRComponent, HelpManualNotasDBCR)
e IXONLINE/SQL SPQ_FNOT_COL (PREVERSION idéntica a la liberada 2.0.7).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND = "QRYSTALOS IPS · CARTERA · NOTAS DÉBITO/CRÉDITO"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. NC vs ND
    sketch(
        "notas_nc_vs_nd_sketchnote.jpg", BRAND,
        "Nota crédito o nota débito: ¿cuál necesito?",
        "Una nota corrige una factura ya emitida sin tocarla: la crédito baja lo que se cobra, la débito lo sube",
        [
            {"num": "NC", "tit": "Nota crédito", "sub": "Baja el valor de la factura", "pal": "green", "items": [
                ("Cuándo:", "Descuento, servicio cobrado de más, glosa aceptada, acuerdo de conciliación."),
                ("Factura:", "Se elige del catálogo de facturas emitidas con saldo (solo las que aún tienen saldo)."),
                ("Límite:", "Nunca por el 100 % del valor: esa es una anulación y se hace desde Facturación."),
                ("Al aplicar:", "Baja el saldo en cartera, reliquida la factura y contabiliza."),
            ]},
            {"num": "ND", "tit": "Nota débito", "sub": "Sube el valor de la factura", "pal": "orange", "items": [
                ("Cuándo:", "Un valor que faltó cobrar, intereses o un ajuste a favor de la institución."),
                ("Factura:", "Se elige del catálogo de facturas / cuentas por cobrar."),
                ("Detalle:", "Siempre ítem por ítem; no existe la casilla «Afecta todos los servicios»."),
                ("Al aplicar:", "Sube el saldo en cartera y contabiliza."),
            ]},
            {"num": "NO ES", "tit": "Lo que no se hace aquí", "sub": "Evite el camino equivocado", "pal": "rose", "items": [
                ("Anular la factura:", "Facturación → anular. O carga masiva con ANULARFACT = SI."),
                ("Notas a proveedores:", "Cuentas por pagar tiene su propia ventana (FCXPDBCR)."),
                ("Responder una glosa:", "Cartera · Glosas crea la nota con procedencia AUDITORIA."),
                ("Conciliar con la EPS:", "Cartera · Conciliaciones crea la nota con procedencia CONCILIA."),
            ]},
            {"num": "ORIGEN", "tit": "Procedencia", "sub": "Columna de la grilla", "pal": "slate", "items": [
                ("NOTAS:", "Creada a mano en esta ventana o por carga masiva. Única que se anula desde aquí."),
                ("AUDITORIA:", "Nace al responder glosas en auditoría médica."),
                ("CONCILIA:", "Nace de un acuerdo de conciliación."),
                ("FACTURA:", "NC con el concepto de anulación: tipo ANULAFACT."),
            ]},
        ],
        pills=[
            ("Elija la clase primero", "El botón Nueva Nota exige tener elegida la Clase (NC o ND) en el filtro."),
            ("Una nota abierta por factura", "Si ya hay una nota sin aplicar sobre esa factura, el sistema no deja crear otra."),
            ("Concepto obligatorio", "Cada nota lleva un concepto del catálogo (Configuración → Conceptos de notas) que define la cuenta contable."),
            ("Periodos abiertos", "La fecha de la nota debe caer en un mes abierto en cartera y en contabilidad."),
        ],
        accent="#0284c7",
    )

    # 2. Hilo común
    sketch(
        "notas_hilo_comun_sketchnote.jpg", BRAND,
        "El hilo común de toda nota: crear → detallar → aplicar",
        "Sea crédito o débito, manual o por concepto, la nota recorre los mismos pasos en Administrativo → Notas DB/CR",
        [
            {"num": "PASO 01", "tit": "Crear la cabecera", "sub": "Filtro Clase + Nueva Nota", "pal": "sky", "items": [
                ("Quién:", "Analista de cartera o facturación."),
                ("Qué se elige:", "La factura (lupa N_Factura), el concepto (lupa Id.Concepto) y una observación."),
                ("Qué muestra:", "Tercero, cuenta de cobro y saldo de la factura."),
                ("Resultado:", "Nota con consecutivo, estado Abierta, procedencia NOTAS."),
                ("Técnico:", "FNOT · FNOT_COL/FNOT_CRUD"),
            ]},
            {"num": "PASO 02", "tit": "Detallar", "sub": "Manual o por concepto", "pal": "orange", "items": [
                ("Manual:", "Botón Detalle → ítem de la factura, cantidad, valor unitario, IVA."),
                ("Por concepto (solo NC):", "Casilla «Afecta todos los servicios» + Porcentaje o Valor → Generar Detalles."),
                ("Regla NC:", "El total no puede superar el saldo de la factura."),
                ("Sin detalle:", "Aplicar responde «Nota sin detalles»."),
                ("Técnico:", "FNOTD · FNOT_CRUDFNOTD / FNOT_ADDDETA"),
            ]},
            {"num": "PASO 03", "tit": "Aplicar", "sub": "Botón Aplicar en la fila", "pal": "green", "items": [
                ("Qué revisa:", "Detalle, periodos abiertos, valor > 0, factura vigente y (NC) saldo suficiente."),
                ("Qué hace:", "Mueve la cartera, deja la nota Aplicada y genera el comprobante contable."),
                ("Si falla:", "Mensaje KO con el motivo; la nota sigue Abierta."),
                ("Técnico:", "FNOT_APLICAR → SPK_NOTASCXC"),
            ]},
            {"num": "PASO 04", "tit": "Después de aplicar", "sub": "DIAN, impresión, anulación", "pal": "violet", "items": [
                ("DIAN:", "Encolar para enviarla; Envíos y Respuestas para ver qué contestó."),
                ("Imprimir:", "Imprimir Nota, Comprobante, N_Factura o ZIP masivo."),
                ("Deshacer:", "Anular Nota solo si la DIAN aún no la procesó (procedencia NOTAS)."),
                ("Técnico:", "FNOT_ENCOLAR · FNOT_ANULANOTA"),
            ]},
        ],
        pills=[
            ("Estado Abierta / Aplicada / Anulada", "Abierta = editable. Aplicada = ya movió cartera y contabilidad. Anulada = sin efecto."),
            ("Editar solo abierta", "Editar Nota, Detalle y Anular (sin aplicar) aparecen únicamente mientras la nota está Abierta."),
            ("La fecha cuenta", "La fecha se asigna al crear (hoy). Para encolar días después puede hacer falta Actualizar Fecha."),
            ("Filtros", "Clase, Estado, Procedencia, Estado DIAN, # Factura, Cns. Nota, rango de fechas y tercero."),
        ],
    )

    # 3. NC por concepto
    sketch(
        "notas_nc_concepto_sketchnote.jpg", BRAND,
        "Nota crédito por concepto: «Afecta todos los servicios»",
        "Un porcentaje o un valor que el sistema reparte entre todas las líneas de la factura (solo NC)",
        [
            {"num": "PASO 01", "tit": "Marcar la casilla", "sub": "En Nueva Nota (solo clase C)", "pal": "sky", "items": [
                ("Dónde:", "Formulario de la nota, debajo de la observación: «Afecta Todos los Servicios»."),
                ("Qué aparece:", "Tipo (Porcentaje o Valor) y la casilla Valor."),
                ("Para qué:", "Descuentos globales, acuerdos de pago o glosas que afectan toda la factura."),
            ]},
            {"num": "PASO 02", "tit": "Porcentaje o Valor", "sub": "Validación en pantalla", "pal": "orange", "items": [
                ("Porcentaje:", "Ej. 10 → el 10 % del saldo de la factura."),
                ("Valor:", "Una cifra fija que no puede superar el saldo."),
                ("Si se pasa:", "Aviso rojo «la afectación no puede superar el saldo de la factura» y no deja guardar."),
                ("Técnico:", "FNOT.CONCEPTO = 1 · TIPOCONCEPTO P/V · VALORCONCEPTO"),
            ]},
            {"num": "PASO 03", "tit": "Generar / Eliminar Detalles", "sub": "El sistema arma las líneas", "pal": "violet", "items": [
                ("Al guardar:", "El sistema reparte el valor entre las líneas de la factura y crea el detalle."),
                ("Si no se generó:", "Botón Generar Detalles (aparece mientras no haya detalle generado)."),
                ("Para rehacer:", "Eliminar Detalles borra las líneas generadas y vuelve el total a cero."),
                ("Técnico:", "SPK_GENITEMS_NOTACR · SPK_DESITEMS_NOTACR · DETGENERADOS"),
            ]},
            {"num": "PASO 04", "tit": "Aplicar", "sub": "Igual que cualquier nota", "pal": "green", "items": [
                ("Condición:", "Debe existir detalle generado (DETGENERADOS = 1)."),
                ("No se mezcla:", "Con la casilla marcada no hay botón Detalle manual ni Editar/Borrar línea."),
                ("Después:", "Aplicada, comprobante contable y lista para encolar a la DIAN."),
            ]},
        ],
        pills=[
            ("Solo NC", "La nota débito no tiene esta casilla: siempre se detalla ítem por ítem."),
            ("Copago propio", "El reparto respeta las líneas de copago y el saldo real de cada servicio."),
            ("Cambiar el valor", "Elimine detalles, edite la nota (Editar Nota) y vuelva a generar."),
            ("Catálogo", "El concepto define la cuenta contable del asiento (Configuración → Conceptos de notas)."),
        ],
        accent="#7c3aed",
    )

    # 4. Detalle manual
    sketch(
        "notas_detalle_manual_sketchnote.jpg", BRAND,
        "Detalle ítem por ítem: cuando la nota es sobre un servicio puntual",
        "Camino obligatorio en la nota débito y opcional en la crédito (sin la casilla «Afecta todos los servicios»)",
        [
            {"num": "PASO 01", "tit": "Botón Detalle", "sub": "Fila expandida, nota Abierta", "pal": "sky", "items": [
                ("Dónde:", "Expanda la nota (carpeta) → botón Detalle debajo de la tabla de líneas."),
                ("Encabezado:", "Muestra la clase y el saldo disponible de la factura."),
                ("Técnico:", "FNOT_CRUDFNOTD · PROCESO Nuevo"),
            ]},
            {"num": "PASO 02", "tit": "Buscar el ítem", "sub": "Lupa sobre la factura", "pal": "orange", "items": [
                ("Qué lista:", "Los servicios o cuotas de la factura elegida."),
                ("Qué trae:", "Código del servicio, descripción, cantidad y valor facturado."),
                ("Técnico:", "FTRD → FNOTD.IDSERVICIO / N_CUOTA"),
            ]},
            {"num": "PASO 03", "tit": "Cantidad, valor e IVA", "sub": "Cálculo en pantalla", "pal": "violet", "items": [
                ("Campos:", "Cantidad, Vlr. Unitario, % IVA (muestra Vlr. IVA), Vlr. Total y Observación."),
                ("Regla NC:", "El total de la línea no puede superar el saldo de la factura; el botón Guardar se oculta."),
                ("Regla ND:", "Sin tope de saldo (sube el valor)."),
            ]},
            {"num": "PASO 04", "tit": "Guardar, editar o borrar", "sub": "Mientras esté Abierta", "pal": "green", "items": [
                ("Guardar:", "Agrega la línea y recalcula el total de la nota."),
                ("Editar | Borrar:", "Iconos al inicio de cada línea (solo si la nota no está aplicada)."),
                ("Después:", "Con al menos una línea ya puede Aplicar."),
                ("Técnico:", "FNOTD · recalcula FNOT.VR_TOTAL"),
            ]},
        ],
        pills=[
            ("Una factura, varias líneas", "Puede agregar tantas líneas como servicios quiera corregir, siempre dentro del saldo (NC)."),
            ("Descripción corta", "La grilla recorta descripción y observación a 30 caracteres; el texto completo queda guardado."),
            ("No en masivo", "La carga por Excel crea una sola línea por nota; el detalle por servicio es de esta ventana."),
            ("Cuotas", "Si la factura tiene cuotas, la línea queda ligada a la cuota (N_CUOTA)."),
        ],
        accent="#ea580c",
    )

    # 5. Carga masiva
    sketch(
        "notas_carga_masiva_sketchnote.jpg", BRAND,
        "Carga masiva: Subir Notas con la plantilla Excel",
        "Clase → plantilla → diligenciar → Procesar → revisar → Generar Notas. Las notas nacen ya aplicadas y contabilizadas",
        [
            {"num": "PASO 01", "tit": "Clase y plantilla", "sub": "Botón Subir Notas", "pal": "sky", "items": [
                ("Elegir:", "Crédito o Débito. La plantilla cambia según la clase."),
                ("Descargar:", "Plantilla Excel (con VALIDACION): trae la fórmula en las primeras filas."),
                ("Si hay más filas:", "Copie la celda VALIDACION hacia abajo."),
            ]},
            {"num": "PASO 02", "tit": "Diligenciar", "sub": "Encabezados exactos", "pal": "orange", "items": [
                ("Crédito:", "N_FACTURA · IDCONCEPTO · DESCRIPCION · VALOR NOTA · OBSERVACIONES · ANULARFACT (SI/NO)."),
                ("Débito:", "N_FACTURA · IDSERVICIO · VALOR · DESCRIPCION · OBSERVACION · CCOSTO · IDAREA · PREFIJO."),
                ("Textos:", "Descripción y observación con mínimo 15 caracteres."),
                ("VALIDACION:", "Debe decir OK en todas las filas con datos."),
            ]},
            {"num": "PASO 03", "tit": "Procesar y revisar", "sub": "Vista previa del lote", "pal": "violet", "items": [
                ("Sube:", "En lotes de 1500 filas a una tabla temporal."),
                ("Revisa el servidor:", "Factura vigente y con saldo, concepto existe, valor > 0; NC: factura notificada en DIAN (FACTE 2 o 6)."),
                ("Vista previa:", "Filtre por factura, «Con errores» y, en NC, «Anular factura»."),
                ("Técnico:", "CARGAR_NOTAS_LOTE → RPDX"),
            ]},
            {"num": "PASO 04", "tit": "Generar Notas", "sub": "Crea, aplica y contabiliza", "pal": "green", "items": [
                ("Qué hace:", "Por cada fila válida crea la nota, la aplica y la contabiliza de una vez."),
                ("ANULARFACT = SI:", "En vez de nota parcial, anula la factura (valor y saldo deben ser iguales al total)."),
                ("Con errores:", "Avisa que solo procesa las válidas y borra las demás."),
                ("Al final:", "Descarga Log_notas_masivo.xlsx con OK / ERROR por fila."),
                ("Técnico:", "FNOT_CREARMASIVO → SPK_APLICA_FNOT_MASIVA / ANULARFAC"),
            ]},
        ],
        pills=[
            ("No queda Abierta", "Las notas masivas se aplican al generarse; no se pueden detallar ni editar después."),
            ("Cancelar = limpiar", "Cancelar en la vista previa borra el lote temporal sin crear notas."),
            ("Débito en masivo", "El servidor usa solo las 5 primeras columnas; CCOSTO, IDAREA y PREFIJO no viajan al detalle."),
            ("No en Perú", "El botón Subir Notas se oculta cuando el país es Perú."),
        ],
        accent="#16a34a",
    )

    # 6. Aplicar
    sketch(
        "notas_aplicar_sketchnote.jpg", BRAND,
        "Qué revisa el sistema cuando pulso Aplicar",
        "Las validaciones corren en este orden; el primer tropiezo detiene todo y la nota sigue Abierta",
        [
            {"num": "1", "tit": "La nota", "sub": "Detalle y valor", "pal": "sky", "items": [
                ("Detalle:", "«Nota sin detalles, no se puede aplicar»."),
                ("Valor:", "«El valor de la nota no puede ser menor o igual a cero»."),
                ("Por concepto:", "Debe tener los detalles generados."),
            ]},
            {"num": "2", "tit": "Los periodos", "sub": "Fecha de la nota", "pal": "amber", "items": [
                ("Cartera:", "«Periodo de cartera cerrado o no existe»."),
                ("Contable:", "«Periodo contable cerrado o no existe»."),
                ("Solución:", "Pedir apertura del mes o Editar Nota con una fecha vigente."),
                ("Técnico:", "PRI.CERRADO_CARTERA / CERRADO"),
            ]},
            {"num": "3", "tit": "La factura", "sub": "Estado y tope", "pal": "orange", "items": [
                ("Vigente:", "Debe estar en estado P y sin anulación: «Inconsistencia en la factura»."),
                ("100 % (NC):", "«No se permite aplicar una nota por el 100 % del valor de la factura, se debe anular desde Facturación»."),
                ("Técnico:", "FTR.ESTADO = P · TIPOANULACION vacío"),
            ]},
            {"num": "4", "tit": "El saldo (solo NC)", "sub": "Reliquida y compara", "pal": "violet", "items": [
                ("Reliquida:", "Recalcula el saldo real de la factura antes de comparar."),
                ("Compara:", "«Verifique los saldos, el saldo de la factura no cubre el valor de la nota»."),
                ("Técnico:", "SPK_RELIQUIDA_FTR · VWK_CXCDIASVTO (SINGLO, tipo F)"),
            ]},
            {"num": "5", "tit": "El efecto", "sub": "Todo o nada", "pal": "green", "items": [
                ("Cartera:", "Baja (NC) o sube (ND) el saldo de la factura en la cuenta por cobrar."),
                ("Nota:", "Queda Aplicada (Cerrada) con usuario y fecha."),
                ("Contabilidad:", "Genera el comprobante con la cuenta del concepto; columna Nro. Comprobante."),
                ("Técnico:", "SPK_NOTASCXC → SPK_NC_CONTAB_FNOT"),
            ]},
        ],
        pills=[
            ("Mensajes KO", "El texto que ve el usuario sale del servidor; búsquelo en esta lista para saber qué corregir."),
            ("Error contable", "Si falla la contabilización, la nota no queda aplicada: la transacción se devuelve completa."),
            ("Hospitalización", "Una NC puede liberar admisiones ligadas a la factura (LIBERAHADM) cuando el concepto lo indica."),
            ("Perú", "Al aplicar también se prepara el JSON para SUNAT."),
        ],
        accent="#16a34a",
    )

    # 7. Anular
    sketch(
        "notas_anular_sketchnote.jpg", BRAND,
        "Anular una nota: no es lo mismo abierta que aplicada",
        "Dos botones con el mismo nombre y reglas distintas. La DIAN marca el punto de no retorno",
        [
            {"num": "ABIERTA", "tit": "Anular sin aplicar", "sub": "Nota Abierta, no anulada", "pal": "amber", "items": [
                ("Qué pide:", "Usuario que solicita y motivo de anulación (mínimo 10 caracteres)."),
                ("Qué hace:", "Marca la nota Anulada. No tocó cartera ni contabilidad, así que no hay reverso."),
                ("DIAN:", "No se notifica nada: la nota nunca salió."),
                ("Técnico:", "FNOT_CRUD · PROCESO = ANULAR"),
            ]},
            {"num": "APLICADA", "tit": "Anular aplicada", "sub": "Procedencia NOTAS o AJUSTE", "pal": "rose", "items": [
                ("Qué pide:", "Usuario que solicita y razón de anulación."),
                ("Qué hace:", "Reversa cartera y contabilidad (anula o reversa el comprobante según la variable y el periodo) y marca Anulada."),
                ("Solo si:", "La DIAN aún no la procesó (estado DIAN Sin Enviar)."),
                ("Técnico:", "FNOT_ANULANOTA → SPK_ANULANOTA_CR"),
            ]},
            {"num": "BLOQUEO", "tit": "Cuándo no se puede", "sub": "Mensajes del sistema", "pal": "slate", "items": [
                ("Ya en DIAN:", "«La nota no puede ser anulada porque corresponde a una factura electrónica y ya se ha procesado»."),
                ("Otra procedencia:", "AUDITORIA o CONCILIA no muestran el botón: se corrigen en Glosas o Conciliaciones."),
                ("Ya anulada:", "«Nota anulada, no se puede generar reversión»."),
            ]},
            {"num": "RASTRO", "tit": "Qué queda registrado", "sub": "Para auditoría", "pal": "teal", "items": [
                ("En la nota:", "Usuario que anuló, usuario que solicitó, fecha y razón."),
                ("En contabilidad:", "Comprobante anulado o comprobante de reversión ligado al original."),
                ("Filtro:", "Estado = Anuladas para listarlas."),
                ("Técnico:", "FNOT.USUARIOANU · USUARIOSOL · FECHAANU · RAZONANU"),
            ]},
        ],
        pills=[
            ("Nota ya notificada", "Si la DIAN ya la aceptó no se anula: cree la nota contraria (una ND para deshacer una NC) con Nueva Nota."),
            ("Variable FNOT_ANULA_REVERSA", "Define si el comprobante se anula o se reversa; en periodo cerrado siempre reversa."),
            ("Masivas", "Las notas de carga masiva nacen aplicadas: se anulan por el camino de «aplicada»."),
            ("Factura anulada", "Si la NC anuló la factura (ANULAFACT), la reversa es de Facturación, no de aquí."),
        ],
        accent="#e11d48",
    )

    # 8. DIAN
    sketch(
        "notas_dian_sketchnote.jpg", BRAND,
        "Enviar la nota a la DIAN: Encolar, Desencolar y Actualizar fecha",
        "Botones de esta ventana; el envío y la respuesta los hace el proceso DIAN (ver XML DIAN)",
        [
            {"num": "ANTES", "tit": "Condiciones para encolar", "sub": "Nota Aplicada, estado Sin Enviar", "pal": "slate", "items": [
                ("Factura:", "Debe estar notificada (FACTE 2) o prevalidada (FACTE 6). Si no: «Factura … no se ha notificado a la DIAN»."),
                ("Fecha:", "La fecha de la nota no puede ser anterior a hoy. Si lo es, use Actualizar Fecha."),
                ("Estado:", "No se encola una nota Abierta ni Anulada."),
            ]},
            {"num": "PASO 01", "tit": "Encolar", "sub": "Botón azul (avión)", "pal": "sky", "items": [
                ("Qué hace:", "Pone la fecha de hoy y marca la nota En Cola (1) o en cola de prevalidación (5)."),
                ("Mes anterior (≤ 3):", "Mueve la fecha contable del comprobante al día de hoy; exige comprobante sin errores y periodo abierto."),
                ("Más de 3 meses:", "No se encola: hay que anular y rehacer."),
                ("Técnico:", "FNOT_ENCOLAR · FACTE 0 → 1/5"),
            ]},
            {"num": "PASO 02", "tit": "Esperar la respuesta", "sub": "Columna Estado DIAN", "pal": "violet", "items": [
                ("En Cola → Enviada → Notificada:", "El proceso DIAN la toma, la firma y la envía."),
                ("Con Errores:", "La DIAN la rechazó; botón Envíos y Respuestas muestra el detalle."),
                ("Notificada:", "Aceptada. Desde aquí ya no se anula; se emite la nota contraria."),
                ("Técnico:", "FACTE 1 → 4 → 2 | 3"),
            ]},
            {"num": "SI FALLA", "tit": "Desencolar y Actualizar fecha", "sub": "Botones naranja e índigo", "pal": "amber", "items": [
                ("Desencolar:", "Saca la nota de la cola (En Cola o Con Errores) y la deja Sin Enviar para corregir."),
                ("Actualizar Fecha:", "Pone la fecha de hoy en la nota (y en el comprobante). Aparece cuando la fecha es anterior a hoy."),
                ("Después:", "Vuelva a Encolar."),
                ("Técnico:", "FNOT_DESENCOLAR · FNOT_ACTUALIZAR_FECHA"),
            ]},
        ],
        pills=[
            ("Filtro Estado DIAN", "Sin Enviar · En Cola · Notificada · Con Errores · Enviada. Útil para la revisión diaria."),
            ("Nota sin factura", "Solo se encola a prevalidación si la variable FTR_PREVALIDA_ACTIVA = SI."),
            ("Envíos y Respuestas", "Visible con FACTE 2, 3 o 4: XML enviado, respuesta y CUDE."),
            ("Perú", "En lugar de la DIAN aparece Enviar Sunat y la columna Estado Sunat."),
        ],
        accent="#0284c7",
    )

    # 9. Imprimir y exportar
    sketch(
        "notas_imprimir_sketchnote.jpg", BRAND,
        "Imprimir y exportar: nota, comprobante, factura, Excel y ZIP",
        "Todo lo que sale en papel o en archivo desde esta ventana",
        [
            {"num": "FILA", "tit": "Imprimir Nota", "sub": "Nota Aplicada", "pal": "teal", "items": [
                ("Qué imprime:", "El formato de la nota crédito o débito con sus líneas, tercero y factura."),
                ("Cuándo:", "Solo notas aplicadas (Cerradas)."),
                ("También:", "N_Factura imprime la factura origen."),
            ]},
            {"num": "FILA", "tit": "Comprobante", "sub": "Nota contabilizada", "pal": "sky", "items": [
                ("Qué imprime:", "El comprobante contable que generó la nota al aplicarse."),
                ("Cuándo:", "Aplicada, no anulada y con Nro. Comprobante."),
                ("Técnico:", "MCP · FNOT.NROCOMPROBANTE"),
            ]},
            {"num": "BARRA", "tit": "Exportar Excel", "sub": "Botón verde", "pal": "green", "items": [
                ("Qué baja:", "Las notas que devuelve el filtro actual, con todas las columnas de la grilla."),
                ("Para qué:", "Informes rápidos, conciliar con contabilidad, revisar estados DIAN."),
            ]},
            {"num": "BARRA", "tit": "Impresión masiva (ZIP)", "sub": "Botón naranja (cremallera)", "pal": "orange", "items": [
                ("Qué hace:", "Genera el PDF de cada nota del filtro actual y los empaqueta en un ZIP."),
                ("Nombre del PDF:", "Solo consecutivo · consecutivo + factura · personalizado con {CNSFNOT} {N_FACTURA} {SUFIJO} {CLASE}."),
                ("Vista previa:", "Muestra cómo se llamará cada archivo antes de confirmar."),
                ("Volumen:", "Hasta 2000 notas por ZIP; si hay más, descarga varios ZIP seguidos. Más de 80 puede tardar minutos."),
            ]},
        ],
        pills=[
            ("Filtre primero", "Excel y ZIP toman exactamente lo que está filtrado: acote clase, fechas o tercero antes."),
            ("Mismo formato", "El PDF del ZIP es el mismo de Imprimir Nota, uno por nota."),
            ("No es un informe", "Los informes de cartera (resumen de notas, saldos) están en Cartera · Reportes."),
            ("Permisos", "Esta ventana se controla por acceso al menú; no hay permisos por botón."),
        ],
        accent="#0d9488",
    )

    # 10. Procedencia
    sketch(
        "notas_procedencia_sketchnote.jpg", BRAND,
        "Lo que llega de otros módulos: la columna Procedencia",
        "Esta ventana muestra todas las notas de cartera, pero solo crea y anula las de procedencia NOTAS",
        [
            {"num": "NOTAS", "tit": "Hechas aquí", "sub": "Manual o carga masiva", "pal": "sky", "items": [
                ("Quién:", "Cartera o facturación, desde Nueva Nota o Subir Notas."),
                ("Se puede:", "Editar, detallar, aplicar, anular, encolar, imprimir."),
            ]},
            {"num": "AUDITORIA", "tit": "Desde Glosas", "sub": "Cartera · Glosas", "pal": "rose", "items": [
                ("Cómo nace:", "Al responder una glosa aceptada, auditoría genera la nota crédito."),
                ("Aquí:", "Se consulta, se encola a la DIAN y se imprime. No se anula desde esta ventana."),
            ]},
            {"num": "CONCILIA", "tit": "Desde Conciliaciones", "sub": "Cartera · Conciliaciones", "pal": "violet", "items": [
                ("Cómo nace:", "Al cerrar un acuerdo con la EPS, el sistema crea las notas del acuerdo."),
                ("Aquí:", "Seguimiento DIAN e impresión. La corrección se hace en Conciliaciones."),
            ]},
            {"num": "FACTURA", "tit": "Anulación de factura", "sub": "Tipo ANULAFACT", "pal": "amber", "items": [
                ("Cómo nace:", "NC con el concepto configurado para anular factura (variable IDCONCEP_ANULAFTRCE) o carga masiva con ANULARFACT = SI."),
                ("Aquí:", "Se ve como ANULAFACT; su reverso es de Facturación."),
            ]},
            {"num": "RECAUDOS", "tit": "Plano desde Recaudos", "sub": "Camino alterno", "pal": "slate", "items": [
                ("Cómo nace:", "Recaudos puede subir un archivo plano de notas (5 columnas) al mismo motor."),
                ("Diferencia:", "No exige factura notificada ni soporta ANULARFACT; las notas quedan con procedencia NOTAS."),
            ]},
        ],
        pills=[
            ("Filtro Procedencia", "NOTAS · AUDITORIA · CONCILIA · TODAS. Por defecto la grilla muestra TODAS, del mes en curso."),
            ("Anular Nota (aplicada)", "Solo aparece con procedencia NOTAS o AJUSTE."),
            ("Un solo motor", "Todas se aplican y contabilizan con el mismo proceso; cambia el origen y la cuenta contable."),
            ("CxP no", "Las notas a proveedores viven en Cuentas por pagar con su propio catálogo de tipos (FNT)."),
        ],
        accent="#475569",
    )


if __name__ == "__main__":
    main()
