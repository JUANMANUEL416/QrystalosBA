#!/usr/bin/env python3
"""
Genera los 27 bloques de inventario basándose en la KB y el catálogo.
"""
import json
import sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parent.parent

# Definición de los 27 bloques a crear
BLOQUES = [
    {
        "id": "generacion-cxp-automatica",
        "titulo": "Generación automática de CxP",
        "orden": 13,
        "prerrequisitos": ["contabilizacion-entrada-compra"],
        "icono": "💳",
        "duracion": "20min",
        "capa": "compras",
        "sp_principal": "SPK_INSERT_CXP_INV",
        "variables": ["CONTAB_INV_IVA_ITAR", "REDONDEO_COMPRAS_CXP"],
        "descripcion": "Creación automática de detalle CxP (FCXPD) desde entrada de compra confirmada",
    },
    {
        "id": "contabilizacion-cxp",
        "titulo": "Contabilización de CxP",
        "orden": 14,
        "prerrequisitos": ["generacion-cxp-automatica"],
        "icono": "📑",
        "duracion": "25min",
        "capa": "compras",
        "sp_principal": "CONTABILIZAR_FCXP",
        "variables": ["CUENTA_IVA_CXP"],
        "descripcion": "Contabilización de cuentas por pagar desde OM Comprobantes (proceso hermano cxp-fcxp)",
    },
    {
        "id": "cufe-radian-compras",
        "titulo": "CUFE y Radian en compras",
        "orden": 15,
        "prerrequisitos": ["entrada-de-almacen-y-confirmacion"],
        "icono": "📄",
        "duracion": "30min",
        "capa": "compras",
        "sp_principal": "SPK_SINCRONIZAR_CUFE_RADIAN",
        "variables": ["INV_CUFE_LOTEO"],
        "descripcion": "Sincronización de CUFE desde FRADIAN, loteo con factura y trazabilidad documento electrónico",
    },
    {
        "id": "salida-manual-consumo",
        "titulo": "Salida manual por consumo",
        "orden": 16,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "📤",
        "duracion": "20min",
        "capa": "salidas",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["CONTABIMOV_JOB"],
        "descripcion": "Salida manual de inventario (CRUD_IMOV_SAL) y confirmación con validación KMCOM previa",
    },
    {
        "id": "salida-dispensacion-servicios",
        "titulo": "Salida por dispensación a servicios",
        "orden": 17,
        "prerrequisitos": ["salida-manual-consumo"],
        "icono": "💊",
        "duracion": "25min",
        "capa": "salidas",
        "sp_principal": "SPK_CONFIRMASAL_CM",
        "variables": ["IDINVMOV_DISPEN"],
        "descripcion": "Dispensación desde solicitud (IZSOL) con SPK_CONFIRMASAL_CM sin validación KMCOM previa",
    },
    {
        "id": "contabilizacion-salidas",
        "titulo": "Contabilización de salidas",
        "orden": 18,
        "prerrequisitos": ["salida-dispensacion-servicios"],
        "icono": "📊",
        "duracion": "20min",
        "capa": "salidas",
        "sp_principal": "SPK_NC_CONTAB_INV",
        "variables": ["CONTABIMOV_JOB"],
        "descripcion": "Contabilización de movimientos de salida con OM Inventario (mismo SP que entradas)",
    },
    {
        "id": "devolucion-interna",
        "titulo": "Devolución interna",
        "orden": 19,
        "prerrequisitos": ["salida-manual-consumo"],
        "icono": "↩️",
        "duracion": "15min",
        "capa": "salidas",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOV_DEVOLUCION"],
        "descripcion": "Entrada que revierte salida previa (devolución de servicio a farmacia)",
    },
    {
        "id": "devolucion-proveedor",
        "titulo": "Devolución a proveedor",
        "orden": 20,
        "prerrequisitos": ["entrada-de-almacen-y-confirmacion"],
        "icono": "🔙",
        "duracion": "25min",
        "capa": "salidas",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDINVDEVPROVEEDOR"],
        "descripcion": "Salida hacia proveedor que genera nota CxP (SPK_NC_CONTAB_INV no contabiliza desde INV)",
    },
    {
        "id": "ajustes-inventario",
        "titulo": "Ajustes de inventario",
        "orden": 21,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "⚖️",
        "duracion": "20min",
        "capa": "salidas",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDINVTFSA", "IDINVSAL_MISMAENT"],
        "descripcion": "Corrección de diferencias de conteo físico con tipos TFSA y ajustes",
    },
    {
        "id": "tipo-mov-traslado-salida",
        "titulo": "Tipo de movimiento: Traslado salida (IDTS)",
        "orden": 22,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🚚",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDTS"],
        "descripcion": "Salida de bodega origen con ESTRANSITO=1, par con entrada traslado IDTE",
    },
    {
        "id": "tipo-mov-traslado-entrada",
        "titulo": "Tipo de movimiento: Traslado entrada (IDTE)",
        "orden": 23,
        "prerrequisitos": ["tipo-mov-traslado-salida"],
        "icono": "📥",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_INSERTENTTRANSITO",
        "variables": ["IDTE"],
        "descripcion": "Entrada en bodega destino desde ON_ACEPTA_TRANSITO",
    },
    {
        "id": "tipo-mov-compra",
        "titulo": "Tipo de movimiento: Compra (02)",
        "orden": 24,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🛒",
        "duracion": "25min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOV_COMPRAS"],
        "descripcion": "Entrada por orden de compra con CxP automática (TIPO=Crédito, COMPRAS=true)",
    },
    {
        "id": "tipo-mov-remision",
        "titulo": "Tipo de movimiento: Remisión (22)",
        "orden": 25,
        "prerrequisitos": ["tipo-mov-compra"],
        "icono": "📋",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOV_REMISION_EN"],
        "descripcion": "Entrada por remisión de proveedor (CxP según flujo)",
    },
    {
        "id": "tipo-mov-prestamo",
        "titulo": "Tipo de movimiento: Préstamo",
        "orden": 26,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🤝",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOV_PRESTAMOS"],
        "descripcion": "Entrada por préstamo de proveedor (IDTIPOSER=Presta en FCOM)",
    },
    {
        "id": "tipo-mov-si",
        "titulo": "Tipo de movimiento: Entrada SI",
        "orden": 27,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "➕",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOV_SI"],
        "descripcion": "Entrada alterna cliente/SI desde tránsito",
    },
    {
        "id": "tipo-mov-dispensacion",
        "titulo": "Tipo de movimiento: Dispensación",
        "orden": 28,
        "prerrequisitos": ["salida-dispensacion-servicios"],
        "icono": "💉",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMASAL_CM",
        "variables": ["IDINVMOV_DISPEN"],
        "descripcion": "Salida ligada a solicitud IZSOL con confirmación especial",
    },
    {
        "id": "tipo-mov-cirugia",
        "titulo": "Tipo de movimiento: Cirugía",
        "orden": 29,
        "prerrequisitos": ["salida-manual-consumo"],
        "icono": "🏥",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["INVE_CIRU_TIPO_MOV"],
        "descripcion": "Salida para consumo en quirófano",
    },
    {
        "id": "tipo-mov-venta-retail",
        "titulo": "Tipo de movimiento: Venta retail",
        "orden": 30,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🛍️",
        "duracion": "30min",
        "capa": "tipos-movimiento",
        "sp_principal": "GUARDA_VENTA",
        "variables": ["IDINVMOV_VENTAS", "CONTAB_GASTOVEN_UNI"],
        "descripcion": "Venta al público con triple contabilidad (INV + FTR + caja)",
    },
    {
        "id": "tipo-mov-venta-factura",
        "titulo": "Tipo de movimiento: Venta con factura",
        "orden": 31,
        "prerrequisitos": ["tipo-mov-venta-retail"],
        "icono": "🧾",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_NC_CONTAB_INV",
        "variables": ["IDINVMOVVENTAFACTURA", "CONTAB_GASTOVEN_UNI"],
        "descripcion": "Venta facturable con unificación de costo en comprobante FACTURA",
    },
    {
        "id": "tipo-mov-venta-particular",
        "titulo": "Tipo de movimiento: Venta particular (VE)",
        "orden": 32,
        "prerrequisitos": ["tipo-mov-venta-retail"],
        "icono": "👤",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDINVENTA_PARTICULAR"],
        "descripcion": "Venta a particular con tipo VE",
    },
    {
        "id": "tipo-mov-devolucion-cliente",
        "titulo": "Tipo de movimiento: Devolución cliente",
        "orden": 33,
        "prerrequisitos": ["tipo-mov-venta-retail"],
        "icono": "↪️",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDTIPOMOVDEV_CLIENTE"],
        "descripcion": "Entrada que revierte venta a particular",
    },
    {
        "id": "tipo-mov-traslado-af",
        "titulo": "Tipo de movimiento: Traslado a activos fijos",
        "orden": 34,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🏢",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDINVTRASLACTIVOS"],
        "descripcion": "Traslado de inventario a activos fijos",
    },
    {
        "id": "tipo-mov-pickpack",
        "titulo": "Tipo de movimiento: Pick & Pack",
        "orden": 35,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "📦",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDMOVPICKPACK"],
        "descripcion": "Movimiento Pick & Pack con ESTADO_PICKPACK (1/3)",
    },
    {
        "id": "tipo-mov-traslado-lote",
        "titulo": "Tipo de movimiento: Traslado de lote",
        "orden": 36,
        "prerrequisitos": ["tipo-mov-traslado-entrada"],
        "icono": "🔄",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARSALIDAS",
        "variables": ["IDINVTRASLOTESAL", "IDINVTRASLOTEENT"],
        "descripcion": "Traslado específico de lote (24 salida / 25 entrada)",
    },
    {
        "id": "tipo-mov-devolucion-ce-cx",
        "titulo": "Tipo de movimiento: Devolución CE/Cx/HTX",
        "orden": 37,
        "prerrequisitos": ["salida-manual-consumo"],
        "icono": "🔃",
        "duracion": "20min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVMOVDEVCX", "IDINVMOVDEVCE", "IDINVMOVDEVHTX"],
        "descripcion": "Par salida-entrada para devoluciones específicas de áreas clínicas",
    },
    {
        "id": "tipo-mov-obsequios",
        "titulo": "Tipo de movimiento: Obsequios",
        "orden": 38,
        "prerrequisitos": ["tipos-de-movimiento-itmo"],
        "icono": "🎁",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["IDINVENTXOBSEQUIOS"],
        "descripcion": "Entrada por obsequios (sin costo comercial)",
    },
    {
        "id": "tipo-mov-anulacion-salida",
        "titulo": "Tipo de movimiento: Anulación de salida",
        "orden": 39,
        "prerrequisitos": ["salida-manual-consumo"],
        "icono": "❌",
        "duracion": "15min",
        "capa": "tipos-movimiento",
        "sp_principal": "SPK_CONFIRMARENTRADAS",
        "variables": ["FAR_MOVANULASALIDA"],
        "descripcion": "Entrada que anula/revierte salida farmacéutica",
    },
]


def crear_bloque_json(bloque_def):
    """Crea el bloque.json de un bloque."""
    return {
        "id": bloque_def["id"],
        "titulo": bloque_def["titulo"],
        "version": "1.0.0",
        "temas": ["inventario"],
        "procesos": ["inventario"],
        "orden": {
            "inventario": bloque_def["orden"]
        },
        "prerrequisitos": bloque_def["prerrequisitos"],
        "variantes": [],
        "duracionEstimada": bloque_def["duracion"],
        "icono": bloque_def["icono"],
        "fuente": {
            "proceso": "inventario",
            "capa": bloque_def["capa"],
            "sp": bloque_def["sp_principal"],
            "actualizado": "2026-10-21"
        },
        "palabrasClave": [bloque_def["sp_principal"]] + bloque_def.get("variables", []),
        "estable": True,
        "generado": datetime.now().isoformat()
    }


def crear_contenido_md(bloque_def):
    """Crea el contenido.md de un bloque."""
    variables_section = ""
    if bloque_def.get("variables"):
        variables_section = "\n## Variables de configuración (USVGS)\n\n| Código | Descripción | Valor habitual | Efecto |\n|--------|-------------|----------------|--------|\n"
        for var in bloque_def["variables"]:
            variables_section += f"| **{var}** | {var} | *Pendiente validar* | *Pendiente validar* |\n"
    
    return f"""# {bloque_def['titulo']}

{bloque_def['icono']}

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** {bloque_def['capa']}

## Explicación

{bloque_def['descripcion']}

## Ideas principales

- **Procedimiento principal**: {bloque_def['sp_principal']} ejecuta la lógica central de este tipo de movimiento
- **Validaciones**: El sistema valida SECONTABILIZA efectivo, permisos de bodega, periodo abierto y KMCOM cuando aplica
- **Efecto en existencias**: El movimiento incrementa o decrementa IEXI y actualiza IDXB/IART según el tipo
- **Contabilización**: Usa SPK_NC_CONTAB_INV para generar MCP según modelo MOV_INVENTARIO en KMCOM
- **Errores comunes**: KMCOM faltante, periodo cerrado, bodega bloqueada, tipo de movimiento inactivo

## Campos decisivos y visibles

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| **ITMO.SECONTABILIZA** | Tipos de movimiento | Si 1, puede contabilizarse; si 0, no |
| **ITMO.TIPO** | Tipos de movimiento | Crédito (entrada) o Débito (salida) |
| **IBOD.NOCONTABILIZA** | Bodegas | Si 1, esa bodega no contabiliza aunque ITMO diga que sí |
| **IMOV.ESTADO** | Movimientos | 0=pendiente, 1=confirmado |
| **PRI.CERRADO_INV** | Periodo | Bloquea si 1; debe estar abierto |
{variables_section}
## Usuario final

- **Farmaceuta/Auxiliar**: Registra y confirma el movimiento en inv.ges o inv.imov
- **Contador**: Revisa contabilización desde OM Inventario
- **Soporte**: Valida KMCOM, tipos de movimiento y permisos de bodega

## Soporte y desarrollo

### Procedimientos almacenados

**{bloque_def['sp_principal']}**  
**Propósito:** {bloque_def['descripcion']}  
**Métodos:** *Pendiente validar en conocimiento/inventario/sps.json*  
**Valida:** SECONTABILIZA efectivo, periodo abierto, KMCOM cuando aplica  
**Qué hace:** Actualiza IEXI, IDXB/IART, genera comprobante contable si SECONTABILIZA=1  
**Errores:** «Periodo cerrado», «No existe cuenta KMCOM», «Tipo de movimiento inactivo»

### Ejemplos reales

- **Ejemplo 1**: *Pendiente validar con datos reales del cliente*
- **Ejemplo 2**: *Pendiente validar con datos reales del cliente*
- **Ejemplo 3**: *Pendiente validar con datos reales del cliente*

## Pendiente validar

- ⚠️ Métodos específicos del SP en conocimiento/inventario/sps.json
- ⚠️ Variables USVGS: valores habituales y efecto en el flujo
- ⚠️ Ejemplos reales con datos de cliente (sin información sensible)
- ⚠️ Validaciones específicas del tipo de movimiento
- ⚠️ Cruce con proceso hermano si aplica (CxP, FTR, caja)
"""


def main():
    print("=" * 70)
    print("GENERANDO 27 BLOQUES DE INVENTARIO")
    print("=" * 70)
    print()
    
    bloques_dir = ROOT / "capacitacion" / "bloques"
    creados = []
    
    for i, bloque_def in enumerate(BLOQUES, 1):
        print(f"[{i}/27] Creando {bloque_def['id']}...")
        
        # Crear directorio
        bloque_dir = bloques_dir / bloque_def["id"]
        bloque_dir.mkdir(parents=True, exist_ok=True)
        
        # Crear bloque.json
        bloque_json = crear_bloque_json(bloque_def)
        (bloque_dir / "bloque.json").write_text(
            json.dumps(bloque_json, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )
        
        # Crear contenido.md
        contenido_md = crear_contenido_md(bloque_def)
        (bloque_dir / "contenido.md").write_text(contenido_md, encoding="utf-8")
        
        creados.append(bloque_def["id"])
        print(f"    ✓ {bloque_def['titulo']} (orden {bloque_def['orden']})")
    
    print()
    print("=" * 70)
    print(f"✅ {len(creados)} bloques creados exitosamente")
    print("=" * 70)
    
    return creados


if __name__ == "__main__":
    main()
