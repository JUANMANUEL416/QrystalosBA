"""Generador de contenido pedagógico para bloques de capacitación.

Genera guiones detallados desde la KB con:
- Campos decisivos (los que cambian comportamiento)
- Campos visibles en formularios
- Omite campos técnicos/internos

Estructura pedagógica:
- Objetivo
- Campos relevantes (tabla con icono Decisivo/Formulario)
- Pasos numerados
- Cajas: Importante, Tip, Error común, Ejemplo
- Resumen
- Autoevaluación
"""
from typing import Any


def generar_contenido_tabla(
    tabla: str,
    titulo: str,
    proceso: dict,
    control: dict,
    documentos_kb: list[str] = None
) -> str:
    """Genera contenido pedagógico para una tabla específica.
    
    Args:
        tabla: Nombre de la tabla (ej: "ITAR", "IART", "SER")
        titulo: Título del bloque
        proceso: Diccionario del proceso desde conocimiento/
        control: Diccionario del control desde proceso.json
        documentos_kb: Lista de rutas a documentos MD relacionados
    
    Returns:
        Contenido markdown pedagógico
    """
    lineas = []
    
    # 1. Encabezado
    lineas.append(f"# {titulo}")
    lineas.append("")
    
    # 2. Objetivo (🎯)
    objetivo = _generar_objetivo(tabla, control)
    lineas.append("## 🎯 Objetivo")
    lineas.append("")
    lineas.append(objetivo)
    lineas.append("")
    
    # 3. Contexto
    lineas.append("## 📍 Contexto")
    lineas.append("")
    lineas.append(f"**Proceso:** {proceso.get('nombre', '')}")
    lineas.append(f"**Tabla:** `{tabla}`")
    
    if control.get("ventanasFe"):
        rutas_fe = control["ventanasFe"]
        lineas.append(f"**Frontend:** {', '.join(f'`{r}`' for r in rutas_fe[:2])}")
    
    lineas.append("")
    lineas.append(control.get("explicacion", ""))
    lineas.append("")
    
    # 4. Campos relevantes (solo decisivos y de formulario)
    campos = _extraer_campos_relevantes(tabla, control, documentos_kb)
    if campos:
        lineas.append("## 📋 Campos relevantes")
        lineas.append("")
        lineas.append("| Icono | Campo | Descripción | Impacto / Uso |")
        lineas.append("|-------|-------|-------------|---------------|")
        
        for campo in campos:
            icono = "🔑" if campo.get("decisivo") else "📝"
            nombre = campo["nombre"]
            desc = campo["descripcion"]
            impacto = campo["impacto"]
            lineas.append(f"| {icono} | **{nombre}** | {desc} | {impacto} |")
        
        lineas.append("")
        lineas.append("**Leyenda:** 🔑 Campo decisivo (cambia comportamiento) · 📝 Campo de formulario")
        lineas.append("")
    
    # 5. Flujo paso a paso
    pasos = _generar_pasos(tabla, control)
    if pasos:
        lineas.append("## 🔢 Pasos")
        lineas.append("")
        for i, paso in enumerate(pasos, 1):
            lineas.append(f"**{i}.** {paso}")
            lineas.append("")
    
    # 6. Importante
    importantes = _extraer_importantes(control)
    if importantes:
        lineas.append("## ⚠️ Importante")
        lineas.append("")
        for imp in importantes:
            lineas.append(f"- {imp}")
        lineas.append("")
    
    # 7. Tips
    tips = _extraer_tips(tabla, control)
    if tips:
        lineas.append("## 💡 Tips")
        lineas.append("")
        for tip in tips:
            lineas.append(f"- {tip}")
        lineas.append("")
    
    # 8. Errores comunes
    errores = control.get("errores", [])
    if errores:
        lineas.append("## ❌ Errores comunes")
        lineas.append("")
        for err in errores:
            mensaje = err.get("mensaje", "")
            solucion = err.get("solucion", "")
            lineas.append(f"**{mensaje}**")
            if solucion:
                lineas.append(f"  - Solución: {solucion}")
            lineas.append("")
    
    # 9. Ejemplo práctico
    ejemplo = _generar_ejemplo(tabla)
    if ejemplo:
        lineas.append("## 📝 Ejemplo práctico")
        lineas.append("")
        lineas.append(ejemplo)
        lineas.append("")
    
    # 10. Resumen
    lineas.append("## 📌 Resumen")
    lineas.append("")
    resumen = _generar_resumen(tabla, campos, pasos)
    lineas.append(resumen)
    lineas.append("")
    
    # 11. Autoevaluación
    quiz = _generar_quiz(tabla, campos)
    if quiz:
        lineas.append("## ✅ Autoevaluación")
        lineas.append("")
        for i, pregunta in enumerate(quiz, 1):
            lineas.append(f"**{i}.** {pregunta['pregunta']}")
            lineas.append("")
            lineas.append(f"   <details><summary>Ver respuesta</summary>")
            lineas.append(f"   {pregunta['respuesta']}")
            lineas.append(f"   </details>")
            lineas.append("")
    
    # 12. Pendientes de validar (si hay gaps)
    gaps = _identificar_gaps(campos)
    if gaps:
        lineas.append("## ⚠️ Pendiente validar")
        lineas.append("")
        for gap in gaps:
            lineas.append(f"- {gap}")
        lineas.append("")
    
    return "\n".join(lineas)


def _generar_objetivo(tabla: str, control: dict) -> str:
    """Genera el objetivo del bloque."""
    objetivos = {
        "ITAR": "Configurar los tipos de artículo que definen el comportamiento de los artículos en inventario: si lotean, si tienen fecha de vencimiento, si manejan IVA, el consecutivo automático y las reglas de control de stock.",
        "IART": "Crear y configurar artículos (medicamentos, insumos, dispositivos) con su información básica, precios, costos, y asociación a servicios facturables.",
        "SER": "Configurar servicios facturables asociados a artículos para que puedan aparecer en facturación y contabilidad con su centro de costo correcto.",
        "IBOD": "Crear y configurar bodegas (farmacia, bodega central, carro de paro, etc.) con sus permisos, centros de costo y reglas de validación de stock.",
        "ITBOD": "Definir los tipos de bodega que agrupan las bodegas por su naturaleza (farmacéutica, administrativa, etc.).",
        "ITMO": "Configurar los tipos de movimiento de inventario (entradas, salidas, traslados) que definen si afectan existencias, si contabilizan y cómo.",
        "USVGS": "Configurar las variables de sistema que controlan el comportamiento global de inventario y compras.",
        "IDXB": "Asociar artículos a bodegas con punto de reorden, máximo y mínimo para control de stock.",
    }
    return objetivos.get(tabla, control.get("explicacion", "")[:200])


def _extraer_campos_relevantes(tabla: str, control: dict, documentos_kb: list[str] = None) -> list[dict]:
    """Extrae solo campos decisivos y de formulario desde la KB."""
    
    # Mapeo de campos relevantes por tabla desde la KB
    campos_por_tabla = {
        "ITAR": [
            {
                "nombre": "MLOTEO",
                "decisivo": True,
                "descripcion": "Define si el artículo usa loteo",
                "impacto": "1 = sin pantalla de loteo (INICIAL=1). 0 = lotear en tránsito"
            },
            {
                "nombre": "MFECHAVENCIMIENTO",
                "decisivo": True,
                "descripcion": "Exige fecha de vencimiento",
                "impacto": "CONF_ENTRADA valida que todas las líneas tengan fecha"
            },
            {
                "nombre": "MIVA",
                "decisivo": True,
                "descripcion": "Maneja IVA",
                "impacto": "Coherencia con IART.IDIMPUESTO, afecta IMOVH y FCXPD"
            },
            {
                "nombre": "PRECNS / MCNS",
                "decisivo": True,
                "descripcion": "Prefijo y consecutivo del código",
                "impacto": "Genera IDARTICULO automáticamente. Error: 'Revise ITAR PRECNS'"
            },
            {
                "nombre": "MPRINCIPAL",
                "decisivo": True,
                "descripcion": "Permite artículos hijo (SKU/presentaciones)",
                "impacto": "Artículos con IDARTICULOPRIN comparten IDSERVICIO"
            },
            {
                "nombre": "MSTOCK",
                "decisivo": True,
                "descripcion": "Controla existencias",
                "impacto": "Si no controla stock, no debe usarse en movimientos que afectan IEXI"
            },
        ],
        "IART": [
            {
                "nombre": "IDITAR",
                "decisivo": True,
                "descripcion": "Tipo de artículo",
                "impacto": "Define el comportamiento del artículo (loteo, vencimiento, IVA)"
            },
            {
                "nombre": "ESTADO",
                "decisivo": True,
                "descripcion": "Activo / Inactivo",
                "impacto": "Solo artículos Activos pueden comprarse y usarse en movimientos"
            },
            {
                "nombre": "IDSERVICIO",
                "decisivo": True,
                "descripcion": "Servicio facturable asociado",
                "impacto": "Necesario si hay contabilidad/CxP. No dejar solo DEINVNODESER"
            },
            {
                "nombre": "IDIMPUESTO / IDCLASE_IMP",
                "decisivo": True,
                "descripcion": "Impuesto del artículo",
                "impacto": "Obligatorio si USVGS IMPUESTO_OBL=SI"
            },
            {
                "nombre": "IDARTICULOPRIN",
                "decisivo": True,
                "descripcion": "Artículo principal (para SKU)",
                "impacto": "SKU/presentaciones apuntan al principal, comparten IDSERVICIO"
            },
            {
                "nombre": "REGINVIMA / CODCUM",
                "decisivo": False,
                "descripcion": "Registro INVIMA y código CUM",
                "impacto": "Regulatorio, necesario para cotizaciones y trazabilidad"
            },
            {
                "nombre": "PCOSTO",
                "decisivo": True,
                "descripcion": "Precio de costo",
                "impacto": "Base para valorización de inventario y CxP"
            },
        ],
        "SER": [
            {
                "nombre": "IDKMCOM",
                "decisivo": True,
                "descripcion": "Centro de costo contable",
                "impacto": "Define dónde se contabiliza (CXP_COMPRAS, MOV_INVENTARIO)"
            },
            {
                "nombre": "DESCRIPCION",
                "decisivo": False,
                "descripcion": "Nombre del servicio",
                "impacto": "Aparece en facturación y contabilidad"
            },
        ],
        "IBOD": [
            {
                "nombre": "IDTIPOBODEGA",
                "decisivo": True,
                "descripcion": "Tipo de bodega",
                "impacto": "Define la naturaleza de la bodega (ITBOD)"
            },
            {
                "nombre": "MUEVEEXISTENCIAS",
                "decisivo": True,
                "descripcion": "Afecta stock físico",
                "impacto": "Si no mueve, no altera IEXI (bodegas virtuales)"
            },
            {
                "nombre": "VALIDASTOCK",
                "decisivo": True,
                "descripcion": "Valida que haya existencia antes de salida",
                "impacto": "Evita saldos negativos"
            },
            {
                "nombre": "NOCONTABILIZA",
                "decisivo": True,
                "descripcion": "No genera asientos contables",
                "impacto": "Bodegas de prueba o administrativas sin impacto contable"
            },
            {
                "nombre": "IDBODEGAPIDE",
                "decisivo": True,
                "descripcion": "Bodega que solicita compras",
                "impacto": "Obligatoria para generar órdenes de compra desde solicitudes"
            },
        ],
        "ITMO": [
            {
                "nombre": "Débito / Crédito",
                "decisivo": True,
                "descripcion": "Tipo de movimiento",
                "impacto": "Débito = salida, Crédito = entrada. Afecta signo en IEXI"
            },
            {
                "nombre": "CONTABILIZA",
                "decisivo": True,
                "descripcion": "Genera comprobante contable",
                "impacto": "Define si el movimiento afecta contabilidad"
            },
            {
                "nombre": "MPIDEPROV",
                "decisivo": True,
                "descripcion": "Pide proveedor",
                "impacto": "Usado en entradas de compras (tipo 02, 22)"
            },
        ],
    }
    
    return campos_por_tabla.get(tabla, [])


def _generar_pasos(tabla: str, control: dict) -> list[str]:
    """Genera los pasos del proceso para la tabla."""
    pasos_por_tabla = {
        "ITAR": [
            "Ir a Inventario → Configuración → Tipos de artículo",
            "Nuevo tipo: ingresar nombre y seleccionar opciones de loteo, vencimiento, IVA",
            "Configurar prefijo (PRECNS) y si el consecutivo es automático (MCNS)",
            "Definir si el tipo permite artículos principal/hijo (MPRINCIPAL)",
            "Guardar y verificar que el tipo aparezca en la lista",
        ],
        "IART": [
            "Ir a Inventario → Configuración → Artículos",
            "Seleccionar el tipo de artículo (IDITAR) — debe existir previamente",
            "Ingresar descripción, código CUM, registro INVIMA (regulatorio)",
            "Configurar impuesto (IDIMPUESTO) si es obligatorio",
            "Si es SKU/presentación: seleccionar artículo principal (IDARTICULOPRIN)",
            "Definir si crea servicio facturable (CREARSER=1) o usar uno existente",
            "Guardar — el sistema genera el código (IDARTICULO) automáticamente",
        ],
        "IBOD": [
            "Ir a Inventario → Configuración → Bodegas",
            "Seleccionar tipo de bodega (IDTIPOBODEGA)",
            "Configurar nombre, sede y centro de costo",
            "Definir si mueve existencias (MUEVEEXISTENCIAS) y valida stock (VALIDASTOCK)",
            "Configurar bodega que pide (IDBODEGAPIDE) si genera órdenes de compra",
            "Guardar y configurar permisos en Seguridad de bodegas (IBODS)",
        ],
    }
    return pasos_por_tabla.get(tabla, [])


def _extraer_importantes(control: dict) -> list[str]:
    """Extrae puntos importantes del invariante o explicación."""
    invariante = control.get("invariante", "")
    if not invariante:
        return []
    
    # Dividir por puntos o comas largas
    partes = [p.strip() for p in invariante.split('.') if len(p.strip()) > 20]
    return partes[:3]  # Máximo 3 puntos importantes


def _extraer_tips(tabla: str, control: dict) -> list[str]:
    """Genera tips prácticos para la tabla."""
    tips_por_tabla = {
        "ITAR": [
            "Crear primero los tipos más comunes: Medicamentos (loteo+vencimiento+IVA), Insumos (solo loteo), Dispositivos (sin loteo ni vencimiento)",
            "El prefijo (PRECNS) no se puede cambiar después de crear artículos de ese tipo",
            "Si MPRINCIPAL=1, permite crear SKUs (ej: Acetaminofén 500mg principal, Acetaminofén Genven 500mg SKU)",
        ],
        "IART": [
            "Buscar primero si el artículo ya existe (CUM, INVIMA) para no duplicar",
            "Con IART_SER_UNICO=SI (liberado 2.0.7) el sistema no permite CUM ni descripción repetidos",
            "El precio de costo (PCOSTO) se actualiza automáticamente al confirmar entradas de compras",
        ],
        "IBOD": [
            "Bodegas de prueba: marcar NOCONTABILIZA y no MUEVEEXISTENCIAS",
            "Farmacia principal: debe tener VALIDASTOCK para evitar saldos negativos",
            "Configurar permisos por usuario en Seguridad de bodegas (IBODS) después de crear la bodega",
        ],
    }
    return tips_por_tabla.get(tabla, [])


def _generar_ejemplo(tabla: str) -> str:
    """Genera un ejemplo práctico concreto."""
    ejemplos = {
        "ITAR": """**Tipo: Medicamentos controlados**
- MLOTEO = 1 (sin pantalla de loteo manual)
- MFECHAVENCIMIENTO = 1 (exige fecha de vencimiento)
- MIVA = 1 (maneja IVA)
- PRECNS = "MED"
- MCNS = SI (consecutivo automático: MED00001, MED00002, ...)
- MPRINCIPAL = 1 (permite presentaciones/SKUs)
- MSTOCK = 1 (controla existencias)""",
        
        "IART": """**Artículo: Acetaminofén 500mg**
- IDITAR = Medicamentos
- DESCRIPCION = "Acetaminofén 500mg tableta"
- CODCUM = "19901234567890"
- REGINVIMA = "INVIMA2023M-001234"
- IDIMPUESTO = IVA 19%
- CREARSER = 1 (crea servicio automáticamente)
- ESTADO = Activo
→ El sistema genera: IDARTICULO = "MED00001" (según ITAR.PRECNS)""",
        
        "IBOD": """**Bodega: Farmacia Central**
- IDTIPOBODEGA = Farmacéutica
- DESCRIPCION = "Farmacia Central - Sede Principal"
- MUEVEEXISTENCIAS = 1 (afecta stock físico)
- VALIDASTOCK = 1 (valida existencia antes de salida)
- NOCONTABILIZA = 0 (sí contabiliza)
- IDBODEGAPIDE = (la misma bodega, si genera OC)
→ Permisos: configurar en IBODS qué usuarios/tipos de artículo pueden acceder""",
    }
    return ejemplos.get(tabla, "")


def _generar_resumen(tabla: str, campos: list[dict], pasos: list[str]) -> str:
    """Genera un resumen ejecutivo del bloque."""
    decisivos = [c for c in campos if c.get("decisivo")]
    return f"""**{tabla}** es {'una tabla decisiva' if decisivos else 'una tabla de configuración'} que define {'el comportamiento' if decisivos else 'la información'} de {'los artículos' if 'ART' in tabla else 'las bodegas' if 'BOD' in tabla else 'los movimientos' if 'ITMO' in tabla else 'el sistema'} en inventario.

**Campos clave:** {', '.join(c['nombre'] for c in decisivos[:3])} (cambian el comportamiento del sistema)

**Proceso:** {len(pasos)} pasos desde configuración hasta operación

**Prerrequisitos:** {'Ninguno (configuración base)' if tabla in ['ITAR', 'ITBOD', 'ITMO', 'USVGS'] else f'Requiere {tabla[1:] if tabla.startswith("I") else "configuración previa"}'}"""


def _generar_quiz(tabla: str, campos: list[dict]) -> list[dict]:
    """Genera mini quiz de autoevaluación."""
    quizzes = {
        "ITAR": [
            {
                "pregunta": "¿Qué sucede si un tipo de artículo tiene MLOTEO=0?",
                "respuesta": "El artículo requiere pantalla de loteo en tránsito (IZSOL_TRANSITO). Si MLOTEO=1, el loteo es automático (INICIAL=1)."
            },
            {
                "pregunta": "¿Se puede cambiar el PRECNS de un tipo después de crear artículos?",
                "respuesta": "No. El prefijo queda fijo porque ya se usó para generar códigos de artículos (IDARTICULO)."
            },
        ],
        "IART": [
            {
                "pregunta": "¿Qué pasa si dejo IDSERVICIO en DEINVNODESER en un artículo que se factura?",
                "respuesta": "La facturación y contabilidad fallarán porque no hay servicio asociado. Debe crear un SER válido con centro de costo."
            },
            {
                "pregunta": "¿Cómo se actualiza el precio de costo (PCOSTO) de un artículo?",
                "respuesta": "Se actualiza automáticamente al confirmar entradas de compras, tomando el costo de la factura."
            },
        ],
        "IBOD": [
            {
                "pregunta": "¿Cuándo usar MUEVEEXISTENCIAS=0 en una bodega?",
                "respuesta": "En bodegas virtuales, de prueba o administrativas que no afectan el stock físico real (no alteran IEXI)."
            },
            {
                "pregunta": "¿Qué hace VALIDASTOCK=1?",
                "respuesta": "Valida que haya existencia disponible antes de permitir una salida, evitando saldos negativos."
            },
        ],
    }
    return quizzes.get(tabla, [])


def _identificar_gaps(campos: list[dict]) -> list[str]:
    """Identifica campos que necesitan validación."""
    gaps = []
    for campo in campos:
        if "pendiente" in campo.get("descripcion", "").lower():
            gaps.append(f"Campo {campo['nombre']}: verificar si aparece en formulario")
    return gaps
