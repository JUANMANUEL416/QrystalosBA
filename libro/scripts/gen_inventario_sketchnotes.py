# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del libro Inventario, Compras y Farmacia.

Uso:  python libro/scripts/gen_inventario_sketchnotes.py
Salida: libro/img/inv_*_sketchnote.jpg

Contenido contrastado 2026-10-04 con Qrystalos2 (pages/inv/*, pages/inv/conf/*, components/conf/inv/*,
components/inv/*, Procesos/ordenCompra, Procesos/ConteoFisicoPage, Procesos/DevProPage, Procesos/AjustesInvPage,
Venta/*, izsol/*, PackingPage, SemaforoPage), el menú real USPROH (MENUQ_INVENTARIO) y los SP de IXONLINE/SQL
(SPQ_ITBOD, SPQ_IBOD, SPQ_IBODS, SPQ_ITMO, SPQ_ITAR, SPQ_ICLA, SPQ_IGEN, SPQ_IFFA, SPQ_ICCN, SPQ_IPAC, SPQ_IUNI,
SPQ_ITGEN, SPQ_IDXB, SPQ_IEXI, SPQ_ESTANTE, SPQ_IART, SPQ_ILPRE, SPQ_FCOM, SPQ_FCOMD, SPQ_IZSOL, SPQ_IZSOL_TRANSITO,
SPQ_IMOV, SPQ_IMOV_3, SPQ_IMOV_4, SPQ_IMOV_VENTA, SPQ_CONTEOFISICO, SPQ_DEVOLU_PROVEEDOR, SPQ_SEMAFORO,
SPQ_INFOMRES_INV, SPQ_EXISTENCIA, SPQ_VENTAFAR, SPQ_CONF_CXP, SPK_CONFIRMARENTRADAS, SPK_CONFIRMASAL_CM).
Liberada 2.0.7; PREVERSION distinta en SPQ_IZSOL, SPK_CONFIRMARENTRADAS, SPK_CONFIRMASAL_CM.
Regla del libro: sin volúmenes ni valores de configuración de un cliente (el manual sirve a todas las instituciones).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · INVENTARIO, COMPRAS Y FARMACIA"


def main():
    sketch(
        "inv_que_es_sketchnote.jpg", B,
        "Qué es el inventario y cómo se mueve",
        "Bodegas, tipos de movimiento, artículos por lote y un movimiento que nace pendiente y se confirma",
        [
            {"num": "1", "tit": "Configurar", "sub": "Una vez, en orden", "pal": "sky", "items": [
                ("Bodega:", "Dónde está la mercancía: sede, centro de costo, seguridad, bodega que pide."),
                ("Tipo de movimiento:", "Débito (sale) o Crédito (entra); costo, contabiliza, tránsito."),
                ("Variable USVGS:", "IDINVMOV_COMPRAS=02, IDTS/IDTE=14/13, IDINVENTA_PARTICULAR=VE. El proceso elige por variable."),
                ("Artículo:", "Tipo, código automático, servicio para facturar, principal y presentaciones."),
            ]},
            {"num": "2", "tit": "Comprar y recibir", "sub": "Lista → cotización → orden → tránsito", "pal": "orange", "items": [
                ("Orden:", "Nace abierta (C); confirmar (P) crea el tránsito a la bodega."),
                ("Recibir:", "Traer del tránsito: lotear, aceptar, confirmar entrada."),
                ("Resultado:", "Lotes IEXI, totales IDXB/IART, kardex y cuenta por pagar automática."),
            ]},
            {"num": "3", "tit": "Sacar", "sub": "Siempre por lote", "pal": "green", "items": [
                ("Dispensación:", "La solicitud de farmacia arma la salida 06; es el movimiento más frecuente."),
                ("Traslado:", "Salida 14 → tránsito → entrada 13 en destino."),
                ("Venta:", "Mostrador (VE) con caja y factura; Factura INV masiva (VC)."),
                ("Control:", "Conteo físico, devolución a proveedor, vencidos, ajustes."),
            ]},
            {"num": "4", "tit": "Contabilizar", "sub": "Tres puertas", "pal": "violet", "items": [
                ("Movimiento:", "OM Inventario con cuentas KMCOM MOV_INVENTARIO."),
                ("Compra:", "Cuenta por pagar (CXP_COMPRAS) → Cuentas por pagar."),
                ("Venta:", "Factura FTR (+ costo si CONTAB_GASTOVEN_UNI)."),
            ]},
        ],
        pills=[
            ("Estados", "IMOV 0 pendiente → 1 confirmado → 2 anulado. Solo confirmar afecta existencias."),
            ("La existencia vive en el lote", "IEXI por bodega + lote; IDXB e IART son totales que se recalculan."),
            ("Anular", "Pendiente: estado 2. Confirmado: solo farmacia (ESFARMACIA = SI) con movimiento contrario."),
            ("Menú dinámico", "USPROH + USGRUH: si no ve una opción, es permiso del grupo."),
        ],
        accent="#0f766e",
    )

    sketch(
        "inv_configuracion_sketchnote.jpg", B,
        "Configuración: del tipo de bodega al artículo en la bodega",
        "Inventario → Configuración. Guardar / Actualizar / Eliminar; nada se borra con hijos",
        [
            {"num": "1", "tit": "Bodegas", "sub": "ITBOD → IBOD → IBODS", "pal": "sky", "items": [
                ("Tipo de bodega:", "Farmacéutica, carro de paro, botiquín, administrativa."),
                ("Bodega:", "Sede, centro de costo, bodega que pide, mueve existencias, valida stock, no contabiliza, custodia, Pick&Pack, solicita compras."),
                ("Seguridad:", "Qué usuarios entran (BODEGASELECT) y qué tipos de artículo acepta."),
                ("Equipo:", "La estación (UBEQ) tiene bodega por defecto."),
            ]},
            {"num": "2", "tit": "Tipos de movimiento", "sub": "ITMO ↔ USVGS", "pal": "orange", "items": [
                ("Sentido:", "Débito = salida; Crédito = entrada."),
                ("Banderas:", "Afecta costo / promedio, se contabiliza (+ comprobante), genera tránsito (+ tipo opuesto), pide proveedor o valor."),
                ("Variable:", "El proceso usa IDINV*; un tipo sin variable no lo usa nadie."),
                ("Borrar:", "Solo revisa excepciones; no revisa movimientos."),
            ]},
            {"num": "3", "tit": "Tipos y catálogos", "sub": "ITAR + clases, genéricos, formas…", "pal": "green", "items": [
                ("Tipo de artículo:", "Qué pide (lote, vencimiento, genérico, concentración, riesgo, IVA), prefijo del código, cuenta."),
                ("Generar Servicios:", "Crea SER para todo el tipo."),
                ("Catálogos:", "Clase/subclase/grupo, genérico DCI, forma, concentración, principio activo, unidad, tipo de genérico."),
            ]},
            {"num": "4", "tit": "Artículo", "sub": "IART → IDXB → estantes", "pal": "violet", "items": [
                ("Maestro:", "Código automático, principal y presentaciones (SKU), servicio, códigos de barras, UNIRS, unidosis, kits, transformaciones."),
                ("Por bodega:", "Stock mínimo / máximo / punto de reorden, autorización."),
                ("Lote:", "Editar vencimiento, sacar de cuarentena (BTN_INV_EDIT_ART)."),
                ("No se borra:", "Si está en alguna bodega."),
            ]},
        ],
        pills=[
            ("Orden sugerido", "Tipos de bodega → Bodegas → Tipos de movimiento → Variables → Tipos de artículo → Catálogos → Artículos → Artículo por bodega → Estantes."),
            ("Para solicitar compras", "La bodega necesita COMPRASOL y bodega que pide (IDBODEGAPIDE)."),
            ("Custodia", "Bodega ESDECUSTODIA recibe entrada propia (IDINVTPROPIA)."),
            ("Pendiente", "Artículos llama CARGAR_PRECIO_REGULADO y el SP no lo tiene."),
        ],
        accent="#0284c7",
    )

    sketch(
        "inv_tipos_movimiento_sketchnote.jpg", B,
        "Tipos de movimiento: cuáles existen y quién los usa",
        "Catálogo ITMO de cada institución. Variable → tipo → proceso (códigos habituales)",
        [
            {"num": "↓", "tit": "Entradas (Crédito)", "sub": "Suman existencia", "pal": "green", "items": [
                ("02 Compras:", "Recepción de OC; crea CxP (IDINVMOV_COMPRAS)."),
                ("13 Traslado ENT:", "Destino acepta el traslado (IDTE)."),
                ("04 / DV Devoluciones:", "De enfermería (IDINVMOVPREDEV) y de dispensación (IDINVMOV_DEVOLUCION)."),
                ("25 / 33 / SI / PR:", "Traslado lotes ENT, devolución traslado, ajuste de conteo (IDINVSIENT), custodia."),
                ("22 Remisión:", "Entrada sin factura; crea CxP (IDINVMOV_REMISION_EN)."),
            ]},
            {"num": "↑", "tit": "Salidas (Débito)", "sub": "Restan existencia", "pal": "rose", "items": [
                ("06 Dispensación:", "Solicitudes → Confirmar movimiento."),
                ("14 Traslado SAL:", "Genera tránsito; opuesto 13 (IDTS)."),
                ("VC / VE Ventas:", "Facturable masiva (IDINVMOVVENTAFACTURA) / mostrador (IDINVENTA_PARTICULAR)."),
                ("08 / 8A Gasto consumo:", "Solicitud de consumo; 08 genera tránsito 10."),
                ("24 / SA / 07 / 05:", "Traslado lotes SAL, ajuste de conteo (IDINVSISAL), destrucción (vencidos), devolución proveedor."),
            ]},
            {"num": "⚑", "tit": "Banderas", "sub": "Lo que cambia el comportamiento", "pal": "amber", "items": [
                ("SECONTABILIZA:", "Comprobante en OM Inventario si la bodega no tiene NOCONTABILIZA."),
                ("AFECTACOSTO:", "Recalcula costo promedio: compras, ventas, devolución proveedor, destrucción, cambio SKU."),
                ("GENTRANSITO:", "La salida crea tránsito; el destino acepta con IDTIPOMOVOP."),
                ("MPROVEEDOR:", "Pide proveedor: devoluciones, préstamos, remisión."),
            ]},
            {"num": "⚙", "tit": "Variables que eligen el tipo", "sub": "USVGS → ITMO (ejemplo habitual)", "pal": "slate", "items": [
                ("Compras:", "IDINVMOV_COMPRAS 02 · REMISION 22 · SI SI"),
                ("Traslados:", "IDTS 14 · IDTE 13 · DEV_TRASLBOD 33 · lotes 24/25"),
                ("Ventas:", "PARTICULAR VE · VENTAFACTURA VC · PICKPACK 14,VC"),
                ("Control:", "DEVPROVEEDOR 05 · SALVENCIDOS 07 · SIENT/SISAL SI/SA (conteo) · TPROPIA PR · FAR_MOVANULA*"),
            ]},
        ],
        pills=[
            ("Lo más frecuente", "Dispensación (06); compras y traslados son el resto relevante."),
            ("Regla", "El SP rechaza una variable que apunte a un tipo del sentido equivocado («no es de tipo salida»)."),
            ("Ajustes", "Los tipos de IDINVSIENT / IDINVSISAL los genera el conteo físico; no se crean a mano."),
        ],
        accent="#b45309",
    )

    sketch(
        "inv_compras_sketchnote.jpg", B,
        "Compras: de la lista de precios a la orden confirmada",
        "Lista de precios → Cotización → Orden abierta (C) → Confirmar (P) → tránsito",
        [
            {"num": "1", "tit": "Lista de precios", "sub": "ILPRE / ILPRED", "pal": "sky", "items": [
                ("Una por proveedor:", "Vigencia, prioridad, valor mínimo aceptado."),
                ("Artículos:", "A mano o Excel (importar precios); homologación de códigos del proveedor."),
                ("Regla:", "Un artículo una vez por lista; valor ≠ 0."),
                ("Homologación:", "Código del proveedor ↔ artículo propio, también por Excel."),
            ]},
            {"num": "2", "tit": "Cotización", "sub": "ICTZ / ICTZD", "pal": "orange", "items": [
                ("Ingresado:", "Artículos con proveedor de lista y valor; carga masiva por Excel."),
                ("Generar OC:", "Una orden por proveedor, estado C, procedencia ILPRE. Cotización → Compra."),
                ("Bloqueos:", "Cerrada o ya en Compra; total por proveedor < mínimo de su lista."),
                ("No confundir:", "«Cotización comercial» (ICTZG) no genera órdenes."),
            ]},
            {"num": "3", "tit": "Orden de compra", "sub": "FCOM / FCOMD", "pal": "green", "items": [
                ("Abierta (C):", "Proveedor, bodega, centro de costo, fechas de factura, líneas con IVA."),
                ("Desde bodega:", "Solicitud de compra (COMPRASOL + bodega que pide) → Generar OC."),
                ("Desde aplicación:", "GEN_OC_APLIM toma el precio de la lista del proveedor."),
                ("Notas:", "Seguimiento FCOMNOT; Excel de seguimiento."),
            ]},
            {"num": "4", "tit": "Confirmar", "sub": "C → P + ITRA", "pal": "violet", "items": [
                ("Exige:", "Detalle y ningún valor unitario en cero."),
                ("Hace:", "ORDENCOMPRA = 1, estado P, requisición de tránsito a la bodega."),
                ("Abrir:", "Vuelve a C solo sin recepción en bodega."),
                ("Anular / Clonar:", "A libera cotización o pendientes APLIM; clonar copia."),
            ]},
        ],
        pills=[
            ("Estados FCOM", "C abierta · P procesada · R recepción parcial · I confirmada en bodega · A anulada."),
            ("Clonar", "Copia cabecera y líneas a una orden nueva en C, sin factura ni cotización."),
            ("Permisos", "btnRecepcion_masiva_OC, btnEditar/Eliminar_notas_OC, BTN_ELIMINAR_ICTZD."),
        ],
        accent="#ea580c",
    )

    sketch(
        "inv_recepcion_sketchnote.jpg", B,
        "Recepción: tránsito, loteo, entrada confirmada y cuenta por pagar",
        "Movimientos → Traer del tránsito. Lo que hace la bodega y lo que el sistema genera al confirmar",
        [
            {"num": "1", "tit": "Traer del tránsito", "sub": "ITRA / ITRAH", "pal": "sky", "items": [
                ("Lotear:", "Lote, fecha de vencimiento, cantidad recibida, temperatura, registro INVIMA."),
                ("Causa:", "Lo que no llegó lleva causa de no loteo (individual o masiva)."),
                ("Prevalidar:", "Formato de verificación de factura cumplido; tránsito no tomado por otra estación."),
                ("Aceptar:", "Crea el movimiento de entrada en estado 0."),
            ]},
            {"num": "2", "tit": "Recepción masiva", "sub": "Alternativa por Excel", "pal": "amber", "items": [
                ("Permiso:", "btnRecepcion_masiva_OC en Orden de compra."),
                ("Hace:", "Tránsito + movimiento sin pantalla de loteo; PCOSTO base DIAN."),
                ("Parcial:", "La orden queda en R hasta completar."),
            ]},
            {"num": "3", "tit": "Confirmar entrada", "sub": "CONF_ENTRADA → SPK_CONFIRMARENTRADAS", "pal": "green", "items": [
                ("Exige:", "Vencimiento en todas las líneas, factura no duplicada con fechas, costo en todos los lotes, paciente si el tipo lo pide."),
                ("Con VALID_CCOSTO_CXP = SI:", "Centro de costo con cuenta CXP_COMPRAS."),
                ("Hace:", "IEXI, IDXB, IART, kardex, cierra ITRA, orden R o I."),
                ("Si faltan cuentas:", "«Inconsistencia. No existe configuración contable» y no confirma."),
            ]},
            {"num": "4", "tit": "Cuenta por pagar", "sub": "Automática", "pal": "violet", "items": [
                ("Cuándo:", "Tipo 02 / 22 / SI con proveedor en la orden."),
                ("Qué crea:", "FCXP con cuentas CXP_COMPRAS, detalle desde IMOVH, impuestos, anticipos."),
                ("Después:", "Tesorería la contabiliza. Cambiar factura solo si no está contabilizada."),
                ("Contabilidad en línea:", "Solo si CONTABIMOV_JOB ≠ SI; con SI la hace OM Inventario."),
            ]},
        ],
        pills=[
            ("Tránsito", "ITRA 0 abierto · 1 recibido · 2 cancelado. Loteo = SPK_INSERT_ITRAH (digitado + faltante)."),
            ("Anular", "Una entrada solo se anula sin confirmar y sin detalle; confirmada se devuelve al proveedor."),
            ("PREVERSION", "SPK_CONFIRMARENTRADAS corrige el total de bodega/artículo con líneas estado 9."),
            ("Custodia", "AGREGA_CUSTODIA / Excel masivo con tipo PR en bodegas ESDECUSTODIA."),
        ],
        accent="#16a34a",
    )

    sketch(
        "inv_salidas_sketchnote.jpg", B,
        "Salidas y traslados entre bodegas",
        "Salida manual · traslado 14 → 13 · devolución de traslado · traslado entre lotes",
        [
            {"num": "1", "tit": "Crear la salida", "sub": "CRUD_IMOV_SAL", "pal": "sky", "items": [
                ("Datos:", "Tipo Débito, bodega destino si traslada, fecha, paciente o centro de costo."),
                ("Valida:", "Permiso sobre el tipo y la bodega destino; fecha no futura; periodo."),
                ("Traslado:", "No a la misma bodega."),
            ]},
            {"num": "2", "tit": "Entregar por lote", "sub": "ISAL", "pal": "orange", "items": [
                ("Cómo:", "Manual, código de barras (ENTREGA_ISAL) o importar Excel."),
                ("Regla:", "Cantidad ≤ existencia del lote; artículo solicitado y no repetido."),
                ("IVA:", "Confirmar entrega copia el IVA del lote."),
            ]},
            {"num": "3", "tit": "Confirmar salida", "sub": "CONFIRMA_SALIDA → SPK_CONFIRMARSALIDAS", "pal": "green", "items": [
                ("Exige:", "Al menos una entrega; existencia por lote contando reservas Pick&Pack."),
                ("ESFARMACIA = SI:", "Ningún costo cero; debe valer exactamente SI."),
                ("Hace:", "Descuenta IEXI, kardex, estado 1; tipo 14 crea el tránsito al destino."),
                ("Anular:", "Pendiente → estado 2. Confirmada → farmacia crea el contrario (FAR_MOVANULASALIDA) y lo confirma."),
            ]},
            {"num": "4", "tit": "Destino y devoluciones", "sub": "13 · 33 · 24/25", "pal": "violet", "items": [
                ("Aceptar traslado:", "Traer del tránsito → lotear → entrada 13 → confirmar."),
                ("Devolver traslado:", "BTN_DEV_TRANSITO, tipo 33; origen aprueba si INV_APRU_DEVTRA = SI."),
                ("Entre lotes:", "Informes → Trasladar lote (BTN_LOT_TRASLADO): 24 + 25 confirmados en el acto."),
                ("Desde la compra:", "TRAECOMPRA_SALIDA arma la salida con la misma entrada."),
            ]},
        ],
        pills=[
            ("Desde otra entrada", "TRAECOMPRA_SALIDA copia los lotes al borrador ISAL, limitado a la existencia."),
            ("Permisos", "ANULAR_SALIDA, EDITAR_SALIDA, per_traslado_bodegas, BTN_DEV_TRANSITO, BTN_LOT_TRASLADO."),
            ("Pendiente", "Confirmar y anular no consultan el periodo PRI (SR20260911-001)."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "inv_dispensacion_sketchnote.jpg", B,
        "Solicitudes y dispensación: la salida que nace en el piso",
        "Inventario → Solicitudes. Agregar → Entregar → Procesar → Confirmar movimiento (tipo 06)",
        [
            {"num": "1", "tit": "Solicitud", "sub": "IZSOL / IZSOLD", "pal": "sky", "items": [
                ("Clases:", "CE, TRANS_CE, 24HORAS, APLIM, OMEDICA, SENFER, Consumo."),
                ("Estados:", "0 pendiente · 1 en proceso · 2 cerrada."),
                ("Lista de trabajo:", "Autorizaciones (AUT/AUTD) que se dispensan y confirman como una solicitud más."),
            ]},
            {"num": "2", "tit": "Agregar y entregar", "sub": "Picking por lote", "pal": "orange", "items": [
                ("Agregar:", "Farmacia toma la solicitud; movimiento pendiente."),
                ("Entregar:", "Lote y cantidad (IZSOLDT)."),
                ("Bloqueos:", "Medicamento suspendido, PROA pendiente/no autorizado/vencido, cantidad cumplida."),
            ]},
            {"num": "3", "tit": "Procesar y confirmar", "sub": "SPK_PROCESA_IZSOLDT → SPK_CONFIRMASAL_CM", "pal": "green", "items": [
                ("Procesar:", "Picking → detalle del movimiento."),
                ("Bloqueos:", "Admisión cerrada, solicitud vencida, orden anulada, copago sin recaudar, sin privilegios."),
                ("Confirmar:", "Descuenta, cobra si aplica, puede cerrar la solicitud."),
                ("PREVERSION:", "Completa centro de costo en TRANS_CE desde la fórmula."),
            ]},
            {"num": "4", "tit": "Variantes", "sub": "Mismo menú", "pal": "violet", "items": [
                ("Canastas de cirugía:", "Canasta de HCINP, tipo INVE_CIRU_TIPO_MOV, entrega por etiqueta."),
                ("Gasto por consumo:", "Solicitudes de consumo 08 / 8A y carga masiva."),
                ("24 horas:", "Genera las órdenes del día (IZSOLM)."),
                ("Devolver:", "Motivo + movimiento confirmado + IDINVMOV_DEVOLUCION; entregas no recibidas se regresan o reciben."),
            ]},
        ],
        pills=[
            ("Detalle clínico", "PROA, copagos, firmas y devoluciones: libro «Dispensación»."),
            ("Permisos", "abrir_solicitud, cerrar_solicitud_dispensacionINV, deshacer_entrega, devolucion_inv, Firma_*."),
        ],
        accent="#0d9488",
    )

    sketch(
        "inv_conteo_sketchnote.jpg", B,
        "Conteo físico y aplicación de ajustes",
        "Procesos → Conteo físico. Congelar, contar tres veces, cerrar, aplicar",
        [
            {"num": "1", "tit": "Nuevo conteo", "sub": "IFIS / IFISH", "pal": "sky", "items": [
                ("Por bodega:", "Detalle, bodega, por estante si aplica."),
                ("Congela:", "La existencia actual de cada lote como saldo del sistema."),
                ("Anular masivo:", "Limpia movimientos pendientes de la bodega."),
            ]},
            {"num": "2", "tit": "Listados y digitación", "sub": "IFISHU por contador", "pal": "orange", "items": [
                ("Listados:", "Se crean y asignan a contadores."),
                ("Tres conteos:", "Por lote; cantidad ≥ 0 y fecha de vencimiento."),
                ("Lote nuevo:", "Se crea desde el conteo si no estaba en sistema."),
                ("Plantilla Excel:", "Para imprimir o exportar."),
            ]},
            {"num": "3", "tit": "Cerrar / abrir / clonar", "sub": "Por contador y por bodega", "pal": "amber", "items": [
                ("Cerrar:", "Cada conteo del contador; el conteo por bodega manda."),
                ("Abrir:", "Si la bodega está cerrada, abrir primero por bodega."),
                ("Clonar:", "Copia el conteo 1 al 2 o 3 (solo cerrados)."),
                ("Borrar:", "Solo si no está aplicado."),
            ]},
            {"num": "4", "tit": "Aplicar", "sub": "SPK_APLICARCONTEO + SPK_CONFIRMARSALIDAS", "pal": "green", "items": [
                ("Exige:", "Conteos 1-2-3 cerrados; sin negativos; sin entradas ni salidas pendientes; centro de costo activo."),
                ("Variables:", "IDINVSIENT (entrada), IDINVSISAL (salida), IDINV_AJUSXITAR."),
                ("Hace:", "Salida de ajuste confirmada en el acto; entrada de ajuste pendiente en Movimientos."),
                ("Si falla:", "Revierte todo y lo dice."),
            ]},
        ],
        pills=[
            ("Saldo inicial", "Bodega nueva: plantilla → Procesar → Almacenar (crea IART/IDXB/IEXI) → aplicar."),
            ("Después de aplicar", "Confirmar la entrada de ajuste en Movimientos: ahí se exigen las cuentas KMCOM."),
            ("No confundir", "Ajustes de inventario corrige costo o totales, no cantidades."),
        ],
        accent="#d97706",
    )

    sketch(
        "inv_devolucion_vencidos_sketchnote.jpg", B,
        "Devolución a proveedor, vencidos y ajustes de costo",
        "Procesos → Devolución a proveedor · Semáforo · Ajustes de inventario · Informes → Trasladar lote",
        [
            {"num": "1", "tit": "Devolución a proveedor", "sub": "Tipo 05 (IDINVDEVPROVEEDOR)", "pal": "rose", "items": [
                ("Parte de:", "La orden de compra ya ingresada, con CxP."),
                ("Marcar:", "Artículos y lotes uno a uno o Devolución total."),
                ("Confirmar:", "Arma entregas y confirma la salida; exige existencia."),
                ("CxP:", "La nota a proveedor se maneja en Cuentas por pagar."),
            ]},
            {"num": "2", "tit": "Semáforo", "sub": "SEMAFORO_STOCK", "pal": "amber", "items": [
                ("Rangos:", "Rojo / Naranja / Amarillo en días, crecientes (TGEN)."),
                ("Filtro:", "Por bodega o todas (permiso)."),
                ("Salida de vencidos:", "Uno o todos → tipo 07 destrucción (IDINVSALVENCIDOS)."),
                ("Exige:", "Variable configurada y bodega con permiso."),
            ]},
            {"num": "3", "tit": "Ajustes de inventario", "sub": "INFOMRES_INV", "pal": "sky", "items": [
                ("Ajustar / Procesar:", "Cambia el precio de costo del artículo con rastro USLOG."),
                ("Actualizar existencias:", "Recalcula IDXB e IART desde los lotes."),
                ("Cuándo:", "Un artículo «no aparece» aunque el lote tenga saldo. Corre sobre todo el inventario."),
            ]},
            {"num": "4", "tit": "Traslado entre lotes", "sub": "24 → 25", "pal": "green", "items": [
                ("Dónde:", "Informes → Lotes por artículo → Trasladar lote (BTN_LOT_TRASLADO)."),
                ("Exige:", "Cantidad ≤ lote origen, lotes distintos, variables, centro de costo."),
                ("Hace:", "Salida + entrada confirmadas en el acto."),
            ]},
        ],
        pills=[
            ("Vencidos", "Antes de mover valida centro de costo y cuentas MOV_INVENTARIO; confirma en el acto."),
            ("Permisos", "Configurar semaforo vencimientos, Filtro todas las bodegas, Salida un/todos los articulos vencidos."),
        ],
        accent="#e11d48",
    )

    sketch(
        "inv_venta_sketchnote.jpg", B,
        "Venta al público: carrito, caja y factura",
        "Venta a particulares → Venta de insumos. Todo en una transacción al Guardar venta",
        [
            {"num": "1", "tit": "Caja y carrito", "sub": "CONF_CAJA · PRESELL", "pal": "sky", "items": [
                ("Caja abierta:", "La pantalla consulta el estado antes de vender."),
                ("Código de barras:", "Artículo/lote de la bodega; precio de la tarifa de mostrador."),
                ("Regla:", "Valor > 0; cantidad ≤ existencia del lote."),
            ]},
            {"num": "2", "tit": "Cliente y recaudo", "sub": "TER · PRESELLR", "pal": "orange", "items": [
                ("Cliente:", "Nuevo o existente; documento válido (categoría CLI)."),
                ("Recaudo:", "Medios de pago; no supera el pendiente."),
                ("F. electrónica:", "Exige responsable."),
                ("Domicilio:", "Si IDSERVDOMICILIO está configurada."),
            ]},
            {"num": "3", "tit": "Guardar venta", "sub": "GUARDA_VENTA", "pal": "green", "items": [
                ("Exige:", "Preselección no procesada, tipo VE configurado, recaudo completo."),
                ("Hace:", "IMOV VE + ISAL, descuento IEXI por lote, confirmación, factura FTR, recibo de caja FCJ."),
                ("Si falla:", "«Pendiente recaudar» / «No se pudo descontar IEXI por lote»."),
            ]},
            {"num": "4", "tit": "Después", "sub": "Gestión de ventas · Factura INV", "pal": "violet", "items": [
                ("Imprimir:", "IMPRESION_FTR; informe RPT_VENTAS."),
                ("Nota crédito:", "GESVENTA · GEN_NC (permiso NoGenerarReingreso)."),
                ("Factura INV:", "Otro camino: salidas VC confirmadas → Marcar → Facturar masivo."),
                ("Devolución en venta:", "Tipo 31."),
            ]},
        ],
        pills=[
            ("Nota crédito", "GEN_NC parcial o total; concepto FNOT_PAR_CONCEPTO; no reingresa inventario sola."),
            ("No confundir", "Lista de precios del grupo es la del proveedor (compras); el mostrador usa tarifa."),
            ("Contabilidad", "FTR + recibo de caja en el acto; costo INV con CONTAB_GASTOVEN_UNI."),
        ],
        accent="#16a34a",
    )

    sketch(
        "inv_packing_sketchnote.jpg", B,
        "Pick & Pack: preparación de pedidos",
        "Bodegas con MANEJA_PICKPACK; tipos en IDMOVPICKPACK (14, VC)",
        [
            {"num": "1", "tit": "Orden de picking", "sub": "CREAR_ORDEN_PICKING", "pal": "sky", "items": [
                ("Crea:", "IMOV + detalle para la bodega Pick&Pack."),
                ("Agregar:", "Artículos y lotes; cada lote queda reservado."),
                ("Roles:", "Picker y packer por usuario."),
            ]},
            {"num": "2", "tit": "Confirmar picking", "sub": "CONFIRMA_PICKING", "pal": "orange", "items": [
                ("Valida:", "Lotes y cantidades marcadas."),
                ("Ventas:", "Tarifa automática si PVENTA_AUTO_TARIFA; salida si PVENTA_MOV_SAL."),
                ("Devolver:", "Regresa a picking para corregir."),
            ]},
            {"num": "3", "tit": "Packing", "sub": "FINALIZAR_PACKING", "pal": "green", "items": [
                ("Empaque:", "Detalle por pedido, novedades y resumen."),
                ("Finalizar:", "El movimiento queda listo para Confirmar salida."),
            ]},
            {"num": "4", "tit": "Confirmar salida", "sub": "SPQ_IMOV respeta reservas", "pal": "violet", "items": [
                ("Bloquea:", "«Debe completar Picking y Packing antes de confirmar»."),
                ("Reservas:", "Otra salida no invade lotes reservados."),
                ("Descartar:", "No en picking confirmado; devolver el picking."),
            ]},
        ],
        pills=[
            ("Permisos", "ASIG_LOTES_PICK, QUITAR_ART_PICK, VAL_PICKING, CONF_PICKING."),
            ("Configuración", "Bodega con MANEJA_PICKPACK y tipos listados en IDMOVPICKPACK."),
        ],
        accent="#475569",
    )

    sketch(
        "inv_informes_sketchnote.jpg", B,
        "Informes, kardex y existencias",
        "Inventario → Informes (inv.exis_costo). Cinco pestañas, casi todo lectura",
        [
            {"num": "1", "tit": "Dashboard y Por artículo", "sub": "EXISTENCIA", "pal": "sky", "items": [
                ("Dashboard:", "Consumos por periodo y bodega."),
                ("Existencias:", "Por sede, bodega, lote, bodega-lote, institución."),
                ("Lotes por artículo:", "Y desde ahí Trasladar lote."),
                ("Excel:", "Precio-costo, artículo por movimiento y bodega, consumos, custodia."),
            ]},
            {"num": "2", "tit": "Históricos", "sub": "INFOMRES_INV", "pal": "orange", "items": [
                ("Movimientos:", "Buscar, detalle de entrada y de salida."),
                ("Kardex:", "Por periodos: pantalla, Excel, valorizado, PDF."),
                ("Promedios:", "Consumo promedio por bodega o pedido."),
                ("Solicitudes:", "Exportar historial IZSOL."),
            ]},
            {"num": "3", "tit": "Controlados y área", "sub": "Farmacia", "pal": "green", "items": [
                ("Controlados:", "Medicamentos de control."),
                ("Por admisión:", "Dispensados, aplicados, devueltos, facturados."),
                ("Pendientes:", "Medicamentos pendientes de aplicar."),
            ]},
            {"num": "4", "tit": "Reglas", "sub": "Quién ve qué", "pal": "violet", "items": [
                ("Bodegas:", "Solo las del usuario (Seguridad de bodega)."),
                ("Costos:", "Permiso ver_montos_precios."),
                ("Etiquetas:", "Impresión de etiquetas usa la misma lista de bodegas."),
                ("CxP:", "Informes de cuentas por pagar en Procesos → Cuentas por pagar."),
            ]},
        ],
        pills=[
            ("Conciliar", "El kardex por periodos es la fuente para cruzar con contabilidad."),
            ("Única escritura", "Trasladar lote (24/25)."),
        ],
        accent="#0284c7",
    )

    sketch(
        "inv_contabilidad_sketchnote.jpg", B,
        "Contabilidad: qué asiento genera cada paso",
        "Tres puertas: movimiento (OM Inventario), compra (CxP), venta (FTR)",
        [
            {"num": "A", "tit": "Movimiento", "sub": "OM Inventario", "pal": "sky", "items": [
                ("Quién:", "Tipos con SECONTABILIZA en bodegas sin NOCONTABILIZA."),
                ("Cuentas:", "KMCOM MOV_INVENTARIO débito/crédito por tipo de artículo, centro, área."),
                ("Cuándo:", "CONTABIMOV_JOB = SI → OM / Conciliación → Inventario (SPK_NC_CONTAB_INV)."),
                ("Si faltan cuentas:", "La entrada no se confirma."),
            ]},
            {"num": "B", "tit": "Compra", "sub": "Cuenta por pagar", "pal": "orange", "items": [
                ("Nace:", "Sola al confirmar entrada 02/22/SI con proveedor."),
                ("Cuentas:", "KMCOM CXP_COMPRAS (proveedor, débito inventario); impuestos; anticipos."),
                ("Se contabiliza:", "En Cuentas por pagar (SPK_NC_CONTAB_CXP); CUENTAGRAV si IVA."),
                ("Devolución 05:", "Movimiento + nota a proveedor en CxP."),
            ]},
            {"num": "C", "tit": "Venta", "sub": "Factura FTR", "pal": "green", "items": [
                ("Mostrador:", "FTR + recibo de caja en el acto (SPK_NC_CONTAB_CAJA_ING)."),
                ("Factura INV:", "FTR masiva → Facturación → Enviar a contabilidad."),
                ("Costo:", "En el mismo comprobante si CONTAB_GASTOVEN_UNI = SI."),
            ]},
            {"num": "⌛", "tit": "Periodo", "sub": "PRI", "pal": "slate", "items": [
                ("CERRADO_INV:", "Bloquea crear movimientos del mes cerrado."),
                ("MOV_PERIODOS_ANT = SI:", "Permite meses anteriores abiertos."),
                ("No consultan PRI:", "Confirmar y anular (SR20260911-001 pendiente)."),
            ]},
        ],
        pills=[
            ("Dos asientos por compra", "Inventario (OM) y pasivo (CxP), con sentido distinto."),
            ("Variables", "CONTABIMOV_JOB SI · VALID_CCOSTO_CXP NO · CONTAB_GASTOVEN_UNI SI · IDMODELOCONTABLE 01 · IDTIPOCXP_DEFAULT IPS."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "inv_menu_satelites_sketchnote.jpg", B,
        "El menú completo y los satélites de farmacia clínica",
        "USPROH MENUQ_INVENTARIO + USGRUH del grupo",
        [
            {"num": "☰", "tit": "Ítems sueltos", "sub": "19 opciones", "pal": "sky", "items": [
                ("Núcleo:", "Movimientos · Solicitudes · Informes · Semáforo · Packing · Canastas."),
                ("Farmacia clínica:", "Lista de trabajo (LISTA_AUT) · 24 horas (IZSOLM) · Perfil (PERFIL_FARMACOTERAPEUTICO) · Infusión (FAR_IF) · Horarios (FAR_CTRLDOSIS) · Óptica (GES_LENTES_COL)."),
                ("Operación:", "Impresión de etiquetas · Entregas masivas · Recibe solicitud y verifica · Gasto por consumo · Interfaz · Logística MAD · Cotización comercial."),
            ]},
            {"num": "▣", "tit": "Procesos", "sub": "Grupo 40", "pal": "orange", "items": [
                ("Orden de compra", "FCOM / FCOMD"),
                ("Devolución a proveedor", "DEVOLU_PROVEEDOR"),
                ("Conteo físico", "CONTEOFISICO"),
                ("Cuentas por pagar", "CONF_CXP + FCXP"),
                ("Ajustes de inventario", "INFOMRES_INV"),
            ]},
            {"num": "▣", "tit": "Venta a particulares", "sub": "Grupo 60", "pal": "green", "items": [
                ("Venta de insumos", "VENTAFAR + CONF_CAJA"),
                ("Lista de precios", "ILPRE (proveedor)"),
                ("Factura INV", "IMOV_VENTA"),
                ("Cotización de compras", "ILPRE sobre ICTZ"),
                ("Gestión de ventas", "GESVENTA"),
            ]},
            {"num": "▣", "tit": "Configuración", "sub": "Grupo 80 (+ Mobiliario 50)", "pal": "violet", "items": [
                ("Bodegas:", "Tipos de bodega, Bodegas, Estantes."),
                ("Movimiento y artículo:", "Tipos de movimiento, Tipos de artículo, Artículos, Artículo por bodega."),
                ("Catálogos:", "Clases, Genéricos, Tipos de genérico, Formas, Concentraciones, Principios activos, Unidades, Clase de riesgo, Vías, Gastos por consumo, Fórmulas infusión."),
                ("Mobiliario:", "Gestión de mobiliario (MOBI)."),
            ]},
        ],
        pills=[
            ("Si no ve una opción", "Es USGRUH del grupo (SPQ_MENUQ_COL), no un error de pantalla."),
            ("Satélites", "Fichados por METODO: Lista de trabajo, lentes, perfil, infusión, dosis, delivery MAD, hemoderivados."),
            ("No confundir", "Cotización comercial (ICTZG) ≠ Cotización de compras (ILPRE/ICTZ)."),
        ],
        accent="#475569",
    )

    print("OK", IMG_DIR)


if __name__ == "__main__":
    main()
