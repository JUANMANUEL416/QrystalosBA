#!/usr/bin/env python3
"""
Agrega tabla de variables de configuración (USVGS) a todos los bloques.
Lee de conocimiento/ y extrae valores documentados.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOQUES_DIR = ROOT / "capacitacion" / "bloques"
CONOCIMIENTO_DIR = ROOT / "conocimiento"

# Variables conocidas de inventario (de la KB)
VARIABLES_INVENTARIO = {
    "IDINVMOV_COMPRAS": {
        "descripcion": "Tipo de movimiento para compras/entrada de almacén",
        "valor": "02 (habitual)",
        "efecto": "Identifica el movimiento de entrada por compra"
    },
    "IDINVMOV_REMISION_EN": {
        "descripcion": "Tipo de movimiento para remisión de entrada",
        "valor": "22 (habitual)",
        "efecto": "Identifica la remisión de entrada de inventario"
    },
    "IDTS": {
        "descripcion": "Tipo de movimiento para traslado de salida",
        "valor": "14 (habitual)",
        "efecto": "Identifica el traslado de salida entre bodegas"
    },
    "IDTE": {
        "descripcion": "Tipo de movimiento para traslado de entrada",
        "valor": "13 (habitual)",
        "efecto": "Identifica el traslado de entrada entre bodegas"
    },
    "IDINVENTA_PARTICULAR": {
        "descripcion": "Tipo de movimiento para venta a particular",
        "valor": "VE (habitual)",
        "efecto": "Identifica la venta a particular (no facturado)"
    },
    "IDINVMOVVENTAFACTURA": {
        "descripcion": "Tipo de movimiento para venta con factura",
        "valor": "VC (habitual)",
        "efecto": "Identifica la venta con factura generada"
    },
    "IDINVDEVPROVEEDOR": {
        "descripcion": "Tipo de movimiento para devolución a proveedor",
        "valor": "05 (habitual)",
        "efecto": "Identifica la devolución de medicamentos/insumos al proveedor"
    },
    "IDINVSALVENCIDOS": {
        "descripcion": "Tipo de movimiento para salida de vencidos",
        "valor": "07 (habitual)",
        "efecto": "Identifica la salida de medicamentos/insumos vencidos"
    },
    "IDINVTRASLOTESAL": {
        "descripcion": "Tipo de movimiento para traslado de lote salida",
        "valor": "24 (habitual)",
        "efecto": "Identifica el traslado de un lote específico (salida)"
    },
    "IDINVTRASLOTEENT": {
        "descripcion": "Tipo de movimiento para traslado de lote entrada",
        "valor": "25 (habitual)",
        "efecto": "Identifica el traslado de un lote específico (entrada)"
    },
    "IDINVSIENT": {
        "descripcion": "Tipo de movimiento para ajuste de entrada por conteo",
        "valor": "SI (habitual)",
        "efecto": "Ajuste positivo de inventario tras conteo físico"
    },
    "IDINVSISAL": {
        "descripcion": "Tipo de movimiento para ajuste de salida por conteo",
        "valor": "SA (habitual)",
        "efecto": "Ajuste negativo de inventario tras conteo físico"
    },
    "IDINVTPROPIA": {
        "descripcion": "Tipo de movimiento para custodia propia",
        "valor": "PR (habitual)",
        "efecto": "Identifica medicamentos/insumos en custodia propia"
    },
    "IDINVTFSA": {
        "descripcion": "Tipo de movimiento para farmacia-sala",
        "valor": "21 (habitual)",
        "efecto": "Identifica el movimiento de farmacia a sala/servicio"
    },
    "IDMOVPICKPACK": {
        "descripcion": "Tipos de movimiento para picking & packing",
        "valor": "14,VC (habitual)",
        "efecto": "Identifica los movimientos que usan picking (alistamiento)"
    },
    "ESFARMACIA": {
        "descripcion": "Indica si la bodega es farmacia (para dispensación)",
        "valor": "SI o SIP (según institución)",
        "efecto": "Habilita reglas de dispensación farmacéutica"
    },
    "IART_SER_UNICO": {
        "descripcion": "Evita duplicar código CUM o descripción de medicamentos",
        "valor": "SI (desde v2.0.7)",
        "efecto": "No permite crear artículos con CUM o descripción repetida"
    },
    "DEINVNODESER": {
        "descripcion": "Define artículos que NO generan servicio al crear",
        "valor": "Pendiente validar",
        "efecto": "Evita crear SER automáticamente para ciertos tipos de artículo"
    }
}


def extraer_variables_bloque(contenido: str) -> list[str]:
    """Extrae códigos de variables mencionadas en el bloque."""
    variables_encontradas = []
    
    for var_codigo in VARIABLES_INVENTARIO.keys():
        if var_codigo in contenido:
            variables_encontradas.append(var_codigo)
    
    return variables_encontradas


def generar_tabla_variables(variables: list[str]) -> str:
    """Genera tabla markdown de variables."""
    if not variables:
        return ""
    
    tabla = ["## 🔹 Variables de configuración",
             "",
             "| Código | Descripción | Valor | Efecto |",
             "|--------|-------------|-------|--------|"]
    
    for var in sorted(variables):
        info = VARIABLES_INVENTARIO[var]
        tabla.append(f"| `{var}` | {info['descripcion']} | {info['valor']} | {info['efecto']} |")
    
    tabla.append("")
    tabla.append("> **💡 Tip:** Los valores mostrados son códigos habituales. Cada institución puede configurar los propios en USVGS.")
    tabla.append("")
    
    return "\n".join(tabla)


def agregar_variables_a_bloque(ruta: Path) -> bool:
    """Agrega tabla de variables a un bloque si menciona alguna variable.
    
    Returns:
        True si se modificó
    """
    contenido = ruta.read_text(encoding="utf-8")
    
    # Verificar si ya tiene la sección de variables
    if "## 🔹 Variables de configuración" in contenido:
        print(f"    - Ya tiene tabla de variables")
        return False
    
    # Extraer variables mencionadas
    variables = extraer_variables_bloque(contenido)
    
    if not variables:
        print(f"    - No menciona variables")
        return False
    
    print(f"    → Encontradas {len(variables)} variables: {', '.join(variables[:3])}{'...' if len(variables) > 3 else ''}")
    
    # Generar tabla
    tabla = generar_tabla_variables(variables)
    
    # Insertar tabla después de la sección "Contexto" (antes de "Campos relevantes" o "Importante")
    lineas = contenido.split("\n")
    resultado = []
    insertado = False
    
    for i, linea in enumerate(lineas):
        resultado.append(linea)
        
        # Insertar después de la sección Contexto y antes de Campos/Importante
        if not insertado and linea.strip().startswith("##") and "Contexto" not in linea:
            # Volver atrás para insertar antes de esta sección
            resultado.pop()
            resultado.append("")
            resultado.append(tabla)
            resultado.append(linea)
            insertado = True
    
    if insertado:
        nuevo_contenido = "\n".join(resultado)
        ruta.write_text(nuevo_contenido, encoding="utf-8")
        print(f"    ✓ Tabla agregada con {len(variables)} variables")
        return True
    
    return False


def procesar_todos_los_bloques():
    """Procesa todos los bloques."""
    print("=" * 70)
    print("AGREGAR VARIABLES DE CONFIGURACIÓN A BLOQUES")
    print("=" * 70)
    print()
    
    archivos = sorted(BLOQUES_DIR.rglob("contenido.md"))
    
    if not archivos:
        print("✗ No se encontraron bloques")
        return False
    
    print(f"Procesando {len(archivos)} bloques...\n")
    
    modificados = 0
    for ruta in archivos:
        nombre = ruta.parent.name
        print(f"  📄 {nombre}")
        
        if agregar_variables_a_bloque(ruta):
            modificados += 1
    
    print()
    print("=" * 70)
    print(f"✅ Variables agregadas: {modificados}/{len(archivos)} bloques modificados")
    print("=" * 70)
    
    return modificados > 0


if __name__ == "__main__":
    modificados = procesar_todos_los_bloques()
    sys.exit(0 if modificados else 1)
