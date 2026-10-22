#!/usr/bin/env python3
"""
Mapa de escenas visuales por bloque para ilustraciones.
Elimina códigos técnicos (ITAR, IART, etc.) que confunden a las IA de imagen.
"""

# Mapa: bloque_id -> escena visual descriptiva en español (contexto salud)
ESCENAS_BLOQUES = {
    "tipos-de-articulo-itar": (
        "Estantería de farmacia hospitalaria con secciones claramente separadas para "
        "medicamentos, dispositivos médicos, material médico-quirúrgico, reactivos de "
        "laboratorio y productos de nutrición. Regente de farmacia clasificando productos "
        "según su categoría."
    ),
    
    "articulos-iart": (
        "Base de datos de artículos médicos en pantalla de computador: medicamentos con "
        "código CUM, dispositivos médicos con registro INVIMA, material médico-quirúrgico. "
        "Farmaceuta revisando el catálogo en sistema hospitalario."
    ),
    
    "servicios-ser": (
        "Catálogo de procedimientos médicos hospitalarios en pantalla: cirugías, exámenes "
        "de laboratorio, imagenología diagnóstica, dispensación de medicamentos. Personal "
        "de salud revisando lista de procedimientos disponibles."
    ),
    
    "articulo-por-bodega-idxb": (
        "Diferentes bodegas de farmacia hospitalaria: farmacia central, carro de paro, "
        "botiquín de enfermería, almacén de dispositivos médicos. Control de inventario "
        "por ubicación."
    ),
    
    "bodegas-ibod": (
        "Bodega de farmacia hospitalaria con zonas organizadas: área refrigerada para "
        "medicamentos termolábiles, estantes de medicamentos controlados bajo llave, "
        "zona de dispositivos médicos estériles. Farmaceuta en control de inventario."
    ),
    
    "tipos-de-bodega-itbod": (
        "Plano hospitalario mostrando diferentes tipos de almacenes: farmacia central, "
        "farmacia satélite en piso, carro de paro en urgencias, bodega de dispositivos "
        "médicos, almacén de reactivos de laboratorio."
    ),
    
    "tipos-de-movimiento-itmo": (
        "Flujo de movimientos de inventario en hospital: entrada de medicamentos desde "
        "proveedor, traslado entre farmacias, dispensación a pacientes, devolución de "
        "medicamentos vencidos. Trazabilidad en sistema."
    ),
    
    "variables-de-sistema-usvgs": (
        "Panel de configuración de sistema hospitalario mostrando variables operativas: "
        "tipos de movimiento de inventario, reglas de dispensación farmacéutica, controles "
        "de trazabilidad de medicamentos."
    ),
    
    "loteo-en-transito": (
        "Proceso de registro de lotes de medicamentos: farmaceuta ingresando número de "
        "lote, fecha de vencimiento y concentración de medicamentos recién llegados a "
        "farmacia hospitalaria."
    ),
    
    "confirmar-entrada-inventario": (
        "Farmaceuta verificando entrada de medicamentos contra orden de compra: revisando "
        "cantidades, lotes y fechas de vencimiento de antibióticos, analgésicos y material "
        "médico-quirúrgico."
    ),
    
    "entrada-de-almacen-y-confirmacion": (
        "Proceso de recepción en bodega hospitalaria: revisión de documentos, verificación "
        "física de medicamentos y dispositivos médicos, ingreso al sistema de farmacia."
    ),
    
    "orden-de-compra": (
        "Farmaceuta generando orden de compra para proveedor farmacéutico: selección de "
        "medicamentos, dispositivos médicos y reactivos necesarios para reposición de "
        "inventario hospitalario."
    ),
    
    "cotizacion-de-compras": (
        "Proceso de cotización para adquisición hospitalaria: comparando precios de "
        "proveedores para medicamentos, dispositivos médicos y material médico-quirúrgico."
    ),
    
    "transito-de-compra": (
        "Traslado de medicamentos entre bodegas hospitalarias: carro de traslado con "
        "medicamentos en contenedores seguros, personal de farmacia verificando documentos "
        "de traslado."
    ),
    
    "aceptar-transito": (
        "Farmaceuta recibiendo traslado de medicamentos: verificando cantidades, lotes y "
        "documentación de medicamentos transferidos desde farmacia central a farmacia "
        "satélite."
    ),
    
    "contabilizacion-entrada-compra": (
        "Contador hospitalario en pantalla de orden de movimiento contable revisando "
        "comprobantes de entrada de inventario: verificando cuentas contables DB/CR, "
        "centros de costo y valores de medicamentos y dispositivos médicos recibidos."
    ),
    
    "salida-dispensacion-servicios": (
        "Proceso de dispensación farmacéutica en hospital: farmaceuta entregando medicamentos "
        "a urgencias, enfermería recibiendo, verificación de cantidades y lotes en sistema "
        "de gestión hospitalaria."
    ),
    
    "traslado-entre-bodegas": (
        "Traslado interno de medicamentos entre farmacias hospitalarias: auxiliar de farmacia "
        "trasladando contenedor seguro de medicamentos controlados desde farmacia central a "
        "farmacia satélite de piso, documentación de tránsito."
    ),
    
    # Bloques de compras
    "generacion-cxp-automatica": (
        "Sistema hospitalario generando automáticamente cuenta por pagar desde entrada de "
        "compra: pantalla mostrando detalle de factura proveedor con base gravable, IVA y "
        "total por cada línea de medicamentos recibidos."
    ),
    
    "contabilizacion-cxp": (
        "Contador en pantalla de orden de movimiento comprobantes: revisando y contabilizando "
        "cuentas por pagar de proveedores farmacéuticos con cuentas contables y valores."
    ),
    
    "cufe-radian-compras": (
        "Proceso de sincronización CUFE y documentos electrónicos: farmaceuta revisando "
        "facturas electrónicas de proveedores con código CUFE, verificando con plataforma "
        "RADIAN para trazabilidad de documentos."
    ),
    
    # Bloques de salidas
    "salida-manual-consumo": (
        "Registro manual de salida de inventario hospitalario: auxiliar de farmacia ingresando "
        "consumo de medicamentos para área de urgencias en pantalla de movimientos."
    ),
    
    "contabilizacion-salidas": (
        "Contador revisando movimientos de salida de inventario para contabilizar: verificando "
        "valores de consumo de medicamentos y dispositivos médicos con cuentas contables."
    ),
    
    "devolucion-interna": (
        "Enfermería devolviendo medicamentos no utilizados a farmacia hospitalaria: auxiliar "
        "recibiendo y registrando devolución en sistema, verificando lotes y cantidades."
    ),
    
    "devolucion-proveedor": (
        "Farmaceuta preparando devolución de medicamentos vencidos a proveedor: empacando "
        "productos con documentación de salida y generación de nota crédito."
    ),
    
    "ajustes-inventario": (
        "Proceso de ajuste tras conteo físico: farmaceuta corrigiendo diferencias entre "
        "existencias del sistema y cantidades físicas contadas en estantes de farmacia."
    ),
    
    # Tipos de movimiento
    "tipo-mov-traslado-salida": (
        "Salida para traslado entre bodegas: auxiliar preparando medicamentos para envío "
        "desde farmacia central a farmacia satélite, registrando tránsito en sistema."
    ),
    
    "tipo-mov-traslado-entrada": (
        "Recepción de traslado en bodega destino: farmaceuta aceptando y confirmando "
        "entrada de medicamentos trasladados desde otra farmacia del hospital."
    ),
    
    "tipo-mov-compra": (
        "Entrada de compra desde orden: farmaceuta confirmando recepción de medicamentos "
        "pedidos a proveedor, verificando contra orden de compra y factura."
    ),
    
    "tipo-mov-remision": (
        "Entrada por remisión de proveedor: recepción de medicamentos con remisión "
        "sin factura inmediata, registro en sistema hospitalario."
    ),
    
    "tipo-mov-prestamo": (
        "Entrada de medicamentos en préstamo de proveedor: farmaceuta registrando "
        "productos recibidos temporalmente para atención de emergencias."
    ),
    
    "tipo-mov-si": (
        "Entrada alterna al sistema: registro de medicamentos ingresados por ruta "
        "especial o directa desde cliente, farmaceuta verificando documentación."
    ),
    
    "tipo-mov-dispensacion": (
        "Dispensación desde solicitud médica: farmaceuta entregando medicamentos "
        "autorizados por prescripción, enfermería recibiendo para administración."
    ),
    
    "tipo-mov-cirugia": (
        "Salida de medicamentos e insumos para quirófano: auxiliar preparando kit "
        "quirúrgico con anestésicos, material estéril y dispositivos médicos."
    ),
    
    "tipo-mov-venta-retail": (
        "Venta al público en farmacia hospitalaria: vendedor atendiendo a particular, "
        "registrando medicamentos vendidos con recibo de caja y factura."
    ),
    
    "tipo-mov-venta-factura": (
        "Venta con facturación electrónica: proceso de venta a particular con "
        "generación de factura DIAN y registro contable unificado."
    ),
    
    "tipo-mov-venta-particular": (
        "Venta directa a particular: atención rápida en ventanilla de farmacia "
        "con registro de medicamentos vendidos sin fórmula médica."
    ),
    
    "tipo-mov-devolucion-cliente": (
        "Cliente devolviendo medicamento: vendedor de farmacia recibiendo producto "
        "no utilizado con factura original, reversando venta en sistema."
    ),
    
    "tipo-mov-traslado-af": (
        "Traslado de inventario a activos fijos: registro de equipos médicos que "
        "pasan de inventario consumible a activo fijo institucional."
    ),
    
    "tipo-mov-pickpack": (
        "Proceso pick and pack en bodega: preparación y empaque de pedido completo "
        "de medicamentos para despacho a entidad externa o sucursal."
    ),
    
    "tipo-mov-traslado-lote": (
        "Traslado específico de lote entre bodegas: movimiento de lote concreto de "
        "medicamento con número de lote y vencimiento entre ubicaciones."
    ),
    
    "tipo-mov-devolucion-ce-cx": (
        "Devolución desde áreas clínicas: enfermería de consulta externa o "
        "hospitalización devolviendo medicamentos no administrados a farmacia."
    ),
    
    "tipo-mov-obsequios": (
        "Entrada de medicamentos por obsequio: farmaceuta registrando productos "
        "donados o de cortesía recibidos sin costo de proveedor."
    ),
    
    "tipo-mov-anulacion-salida": (
        "Anulación de salida previa: farmaceuta reversando salida registrada "
        "incorrectamente, devolviendo medicamentos a existencias disponibles."
    ),
    
    # Facturación
    "facturacion-configuracion": (
        "Configuración de módulo de facturación: administrador definiendo tarifas, "
        "convenios con pagadores, códigos CUPS y parámetros de facturación hospitalaria."
    ),
    "facturacion-registro": (
        "Registro de factura hospitalaria: facturador ingresando eventos de atención, "
        "procedimientos, medicamentos y exámenes con valores según contrato."
    ),
    "facturacion-validacion": (
        "Validación de factura antes de radicar: revisor verificando RIPS, soportes "
        "clínicos y cumplimiento de contrato con pagador."
    ),
    "facturacion-contabilizacion": (
        "Contabilización de factura hospitalaria: contador generando comprobante "
        "contable con cuentas de ingreso y cartera por cobrar."
    ),
    "facturacion-reportes": (
        "Reportes de facturación: usuario consultando facturas por periodo, pagador, "
        "estado y valores facturados en sistema hospitalario."
    ),
    
    # Caja
    "caja-configuracion": (
        "Configuración de cajas: administrador definiendo cajas, medios de pago, "
        "conceptos de ingreso y egreso en sistema hospitalario."
    ),
    "caja-registro": (
        "Registro de movimiento de caja: cajero recibiendo pago de particular o "
        "pagador, generando recibo de caja con medio de pago."
    ),
    "caja-validacion": (
        "Validación y cuadre de caja: cajero verificando recibos del día contra "
        "efectivo y medios de pago antes de cierre de caja."
    ),
    "caja-contabilizacion": (
        "Contabilización de movimientos de caja: contador generando comprobante "
        "contable de recaudos e ingresos a bancos."
    ),
    "caja-reportes": (
        "Reportes de caja: cajero o supervisor consultando movimientos, cuadre "
        "diario y medios de pago recibidos."
    ),
    
    # CxP
    "cxp-fcxp-configuracion": (
        "Configuración de cuentas por pagar: administrador definiendo proveedores, "
        "formas de pago y parámetros de autorización de pagos."
    ),
    "cxp-fcxp-registro": (
        "Registro de cuenta por pagar: auxiliar ingresando factura de proveedor "
        "con valores, retenciones e impuestos en sistema."
    ),
    "cxp-fcxp-validacion": (
        "Validación y autorización de cuenta por pagar: supervisor revisando "
        "factura proveedor y autorizando orden de pago."
    ),
    "cxp-fcxp-contabilizacion": (
        "Contabilización de cuenta por pagar: contador generando comprobante "
        "contable con pasivo y cuentas de gasto o activo."
    ),
    "cxp-fcxp-reportes": (
        "Reportes de cuentas por pagar: tesorero consultando saldos por proveedor, "
        "vencimientos y pagos programados."
    ),
    
    # Contabilidad
    "contabilidad-configuracion": (
        "Configuración de contabilidad: contador definiendo plan de cuentas, centros "
        "de costo, periodos contables y parámetros de cierre."
    ),
    "contabilidad-registro": (
        "Registro de comprobante contable: contador ingresando asiento manual "
        "con débitos, créditos y centro de costo."
    ),
    "contabilidad-validacion": (
        "Validación de comprobante: contador verificando cuadre de débitos y "
        "créditos, cuentas correctas y documentos soporte."
    ),
    "contabilidad-contabilizacion": (
        "Contabilización y cierre: contador cerrando periodo contable, generando "
        "estados financieros y balance de comprobación."
    ),
    "contabilidad-reportes": (
        "Reportes contables: contador consultando balance general, estado de "
        "resultados y libros auxiliares por periodo."
    ),
    
    # Recaudos
    "recaudos-configuracion": (
        "Configuración de recaudos: administrador definiendo pagadores, bancos, "
        "conceptos de pago y parámetros de conciliación."
    ),
    "recaudos-registro": (
        "Registro de recaudo: auxiliar de cartera ingresando pago recibido de "
        "pagador con número de transacción y cuenta bancaria."
    ),
    "recaudos-validacion": (
        "Validación y aplicación de recaudo: auxiliar aplicando pago a facturas "
        "pendientes, verificando valores y glosas."
    ),
    "recaudos-contabilizacion": (
        "Contabilización de recaudo: contador generando comprobante contable "
        "de ingreso a banco y disminución de cartera."
    ),
    "recaudos-reportes": (
        "Reportes de recaudos: cartera consultando pagos por periodo, pagador, "
        "saldos pendientes y antigüedad de cartera."
    ),
    
    # Glosas
    "glosas-configuracion": (
        "Configuración de glosas: administrador definiendo tipos de glosa, causales, "
        "responsables y flujo de respuesta."
    ),
    "glosas-registro": (
        "Registro de glosa: auxiliar de cartera ingresando glosa recibida de pagador "
        "con causal, valor glosado y facturas afectadas."
    ),
    "glosas-validacion": (
        "Validación y respuesta de glosa: coordinador médico revisando glosa, "
        "preparando respuesta con soportes clínicos."
    ),
    "glosas-contabilizacion": (
        "Contabilización de glosa: contador ajustando cartera y generando "
        "provisión contable de glosas pendientes de respuesta."
    ),
    "glosas-reportes": (
        "Reportes de glosas: cartera consultando glosas por estado, pagador, "
        "causal, valores glosados y recuperados."
    ),
    
    # Radicaciones
    "radicaciones-configuracion": (
        "Configuración de radicaciones: administrador definiendo pagadores, "
        "formatos de radicación y documentos soporte requeridos."
    ),
    "radicaciones-registro": (
        "Registro de radicación: facturador preparando paquete de radicación "
        "con facturas, RIPS y soportes para envío a pagador."
    ),
    "radicaciones-validacion": (
        "Validación de radicación: revisor verificando completitud de RIPS, "
        "facturas y documentos antes de radicar ante pagador."
    ),
    "radicaciones-contabilizacion": (
        "Contabilización de radicación: contador registrando cartera radicada "
        "y generando reporte de cuentas por cobrar."
    ),
    "radicaciones-reportes": (
        "Reportes de radicaciones: cartera consultando facturas radicadas por "
        "pagador, fecha, estado y valores pendientes de pago."
    ),
    
    # Nómina
    "nomina-configuracion": (
        "Configuración de nómina: administrador de recursos humanos definiendo "
        "conceptos, deducciones, aportes y parámetros de liquidación."
    ),
    "nomina-registro": (
        "Registro de novedades de nómina: auxiliar ingresando incapacidades, "
        "horas extras, bonificaciones y deducciones del periodo."
    ),
    "nomina-validacion": (
        "Validación y liquidación de nómina: contador liquidando nómina mensual "
        "con conceptos, deducciones y aportes parafiscales."
    ),
    "nomina-contabilizacion": (
        "Contabilización de nómina: contador generando comprobante contable "
        "de gastos de personal y provisiones laborales."
    ),
    "nomina-reportes": (
        "Reportes de nómina: recursos humanos consultando liquidación por empleado, "
        "centro de costo, conceptos pagados y deducciones aplicadas."
    ),
}


def obtener_escena_bloque(bloque_id: str, titulo: str = "", descripcion: str = "") -> str:
    """Obtiene la escena visual descriptiva para un bloque.
    
    Args:
        bloque_id: ID del bloque (ej: tipos-de-articulo-itar)
        titulo: Título del bloque (no se usa, solo para compatibilidad)
        descripcion: Descripción (no se usa, solo para compatibilidad)
    
    Returns:
        Descripción de escena sin códigos técnicos
    """
    escena = ESCENAS_BLOQUES.get(bloque_id)
    
    if escena:
        return escena
    
    # Fallback genérico si no hay escena definida
    return (
        "Escena de farmacia hospitalaria con personal de salud trabajando en gestión "
        "de inventario de medicamentos, dispositivos médicos y material médico-quirúrgico."
    )


def validar_prompt_sin_codigos(prompt: str) -> tuple[bool, list[str]]:
    """Valida que un prompt NO contenga códigos de tabla ni palabras de armas.
    
    Returns:
        (es_valido, lista_de_problemas)
    """
    problemas = []
    
    # Códigos de tabla que NO deben aparecer en prompts de imagen
    codigos_prohibidos = [
        "ITAR", "IART", "SER", "IDXB", "IBOD", "ITBOD", "ITMO", "USVGS",
        "SPQ_", "SPK_", "IDARTICULO", "IDSERVICIO", "IDTIPOBODEGA"
    ]
    
    # Palabras de armas que indican problema (palabras completas, no substring)
    palabras_armas = [
        "weapon", "weapons", "gun", "guns", "rifle", "rifles", "ammunition", "ammo",
        "missile", "rocket", "rockets", "grenade", "grenades", "bomb", "bombs",
        "tank", "tanks", "soldier", "soldiers", "army", "warfare",
        "fusil", "munición", "municion", "cohete", "granada", "bomba", "bombas"
    ]
    
    # Palabras que contienen 'arma' pero NO son armas (excluir de la validación)
    palabras_ok = ["pharmacy", "pharmacist", "farmacia", "farmaceuta", "pharmaceutical"]
    
    prompt_upper = prompt.upper()
    
    # Verificar códigos prohibidos
    for codigo in codigos_prohibidos:
        if codigo in prompt_upper:
            problemas.append(f"Código de tabla prohibido: {codigo}")
    
    # Verificar palabras de armas (solo palabras completas, excluir pharmacy/farmacia)
    prompt_lower = prompt.lower()
    
    # Buscar palabras completas de armas
    import re
    for palabra in palabras_armas:
        # Buscar palabra completa (con límites de palabra)
        if re.search(r'\b' + re.escape(palabra) + r'\b', prompt_lower):
            problemas.append(f"Palabra de armas prohibida: {palabra}")
    
    # Buscar "arma" como palabra completa (no en pharmacy/farmacia)
    if re.search(r'\barma\b', prompt_lower):
        # Verificar que no sea parte de pharmacy/farmacia
        es_parte_ok = False
        for ok_word in palabras_ok:
            if ok_word in prompt_lower:
                es_parte_ok = True
                break
        
        if not es_parte_ok:
            problemas.append(f"Palabra de armas prohibida: arma")
    
    # Buscar "militar" como palabra completa (no military en FORBIDDEN)
    if re.search(r'\bmilitar\b', prompt_lower):
        problemas.append(f"Palabra de armas prohibida: militar")
    
    return len(problemas) == 0, problemas
