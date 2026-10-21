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
