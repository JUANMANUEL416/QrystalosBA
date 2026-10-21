#!/usr/bin/env python3
"""
Aplica formato pedagógico a TODOS los bloques de capacitación:
- Separa párrafos densos en ideas principales (max ~350 chars)
- Añade subtítulos cortos + iconos
- Cajas Importante/Tip donde aplique
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOQUES_DIR = ROOT / "capacitacion" / "bloques"

# Iconos contexto salud
ICONOS_SALUD = ["💊", "🏥", "🩺", "⚕️", "💉", "🔬", "📋", "🔹", "🔸", "📦"]


def separar_parrafo_denso_manual(ruta: Path, parrafo: str) -> list[tuple[str, str]]:
    """Separa un párrafo denso en ideas principales basándose en contenido real.
    
    Returns:
        Lista de (subtitulo, contenido) o [("", parrafo)] si no debe separarse
    """
    # Criterios para separar
    num_puntos = parrafo.count(". ")
    longitud = len(parrafo)
    
    # No separar si es corto o simple
    if longitud < 350 and num_puntos <= 3:
        return [("", parrafo)]
    
    # Detectar oraciones principales
    oraciones = [s.strip() + '.' for s in parrafo.split('. ') if s.strip() and not s.endswith('.')]
    
    if len(oraciones) <= 3:
        return [("", parrafo)]
    
    # Agrupar oraciones en ideas (max 2-3 oraciones por idea o ~300 chars)
    ideas = []
    idea_actual = []
    chars_actual = 0
    
    for oracion in oraciones:
        # Si añadir esta oración supera límites, cerrar idea
        if idea_actual and (len(idea_actual) >= 2 or chars_actual + len(oracion) > 350):
            ideas.append(' '.join(idea_actual))
            idea_actual = []
            chars_actual = 0
        
        idea_actual.append(oracion)
        chars_actual += len(oracion) + 1
    
    # Añadir última idea
    if idea_actual:
        ideas.append(' '.join(idea_actual))
    
    # Si no hubo separación significativa, devolver original
    if len(ideas) <= 1:
        return [("", parrafo)]
    
    # Generar subtítulos inteligentes por contenido
    resultado = []
    for i, idea in enumerate(ideas):
        tema = _detectar_tema(idea, i)
        icono = ICONOS_SALUD[i % len(ICONOS_SALUD)]
        subtitulo = f"{icono} **{tema}**" if tema else ""
        
        resultado.append((subtitulo, idea))
    
    return resultado


def _detectar_tema(texto: str, indice: int) -> str:
    """Detecta el tema de un fragmento de texto."""
    texto_upper = texto.upper()
    
    # Patrones específicos del sector salud
    if any(kw in texto_upper for kw in ["TABLA", "CAMPO", "COLUMNA", "REGISTRO"]):
        return "Estructura de datos"
    elif any(kw in texto_upper for kw in ["SPQ_", "SPK_", "STORED", "PROCEDIMIENTO"]):
        return "Procedimientos almacenados"
    elif any(kw in texto_upper for kw in ["SKU", "PRINCIPAL", "PRESENTACIÓN", "IDARTICULOPRIN"]):
        return "Artículos y presentaciones"
    elif any(kw in texto_upper for kw in ["CONSECUTIVO", "CÓDIGO", "PREFIJO", "GENERA"]):
        return "Generación de códigos"
    elif any(kw in texto_upper for kw in ["LOTE", "LOTEO", "VENCIMIENTO", "FECHA"]):
        return "Control de lotes"
    elif any(kw in texto_upper for kw in ["CUM", "INVIMA", "REGISTRO", "REGULACIÓN"]):
        return "Registro sanitario"
    elif any(kw in texto_upper for kw in ["FILTRO", "BÚSQUEDA", "LISTA", "VENTANA"]):
        return "Búsqueda y filtros"
    elif any(kw in texto_upper for kw in ["VALIDACIÓN", "ERROR", "CONF_", "REVISE"]):
        return "Validaciones"
    elif any(kw in texto_upper for kw in ["SERVICIO", "SER", "FACTUR", "COBR"]):
        return "Servicios médicos"
    elif any(kw in texto_upper for kw in ["BODEGA", "STOCK", "EXISTENCIA", "INVENTARIO"]):
        return "Control de inventario"
    elif any(kw in texto_upper for kw in ["MEDICAMENTO", "FÁRMACO", "DROGA", "PRINCIPIO"]):
        return "Medicamentos"
    elif any(kw in texto_upper for kw in ["PACIENTE", "ADMISIÓN", "ORDEN", "ATENCIÓN"]):
        return "Atención al paciente"
    elif any(kw in texto_upper for kw in ["FARMACIA", "DISPENSACIÓN", "ENTREGA"]):
        return "Dispensación farmacéutica"
    elif any(kw in texto_upper for kw in ["COMPRA", "ORDEN", "PROVEEDOR", "COTIZACIÓN"]):
        return "Gestión de compras"
    elif any(kw in texto_upper for kw in ["TRÁNSITO", "TRASLADO", "MOVIMIENTO"]):
        return "Movimientos de inventario"
    elif any(kw in texto_upper for kw in ["IVA", "IMPUESTO", "CONTAB", "CUENTA"]):
        return "Contabilidad"
    elif any(kw in texto_upper for kw in ["USUARIO", "PERMISO", "ROL", "ACCESO"]):
        return "Permisos y seguridad"
    else:
        return f"Operación {indice + 1}"


def procesar_bloque(ruta: Path) -> bool:
    """Procesa un bloque aplicando formato pedagógico.
    
    Returns:
        True si se modificó
    """
    print(f"\n  📄 {ruta.parent.name}")
    
    contenido = ruta.read_text(encoding="utf-8")
    lineas = contenido.split("\n")
    
    resultado = []
    modificado = False
    i = 0
    
    while i < len(lineas):
        linea = lineas[i]
        
        # Detectar sección Contexto (donde están los párrafos densos)
        if linea.strip().startswith("## 📍 Contexto"):
            resultado.append(linea)
            i += 1
            
            # Saltar líneas vacías y metadata
            while i < len(lineas):
                l = lineas[i].strip()
                if not l or l.startswith("**Proceso:**") or l.startswith("**Tabla:**") or l.startswith("**Frontend:**"):
                    resultado.append(lineas[i])
                    i += 1
                else:
                    break
            
            # Acumular párrafo completo (puede ser multilínea)
            parrafo_lineas = []
            inicio_parrafo = i
            
            while i < len(lineas):
                l = lineas[i].strip()
                
                # Fin del párrafo
                if not l:
                    break
                # Nueva sección
                if l.startswith("#") or l.startswith("---") or l.startswith("|") or l.startswith(">"): 
                    break
                # Ya hay subtítulo con icono (ya procesado)
                if l.startswith("###") and any(ic in l for ic in ICONOS_SALUD):
                    break
                
                parrafo_lineas.append(lineas[i])
                i += 1
            
            if parrafo_lineas:
                parrafo_texto = " ".join(ln.strip() for ln in parrafo_lineas if ln.strip())
                
                # Verificar si es denso
                num_puntos = parrafo_texto.count(". ")
                longitud = len(parrafo_texto)
                es_denso = longitud > 400 or num_puntos >= 4
                
                if es_denso:
                    print(f"    → Separando párrafo denso ({longitud} chars, {num_puntos} puntos)")
                    
                    ideas = separar_parrafo_denso_manual(ruta, parrafo_texto)
                    
                    if len(ideas) > 1:
                        for subtitulo, idea in ideas:
                            resultado.append("")
                            if subtitulo:
                                resultado.append(f"### {subtitulo}")
                                resultado.append("")
                            resultado.append(idea)
                        
                        modificado = True
                        print(f"    ✓ Separado en {len(ideas)} ideas")
                    else:
                        # No se pudo separar significativamente
                        resultado.extend(parrafo_lineas)
                else:
                    # Párrafo corto, dejarlo
                    resultado.extend(parrafo_lineas)
            
            continue
        
        # Cualquier otra línea
        resultado.append(linea)
        i += 1
    
    if modificado:
        nuevo_contenido = "\n".join(resultado)
        ruta.write_text(nuevo_contenido, encoding="utf-8")
        return True
    
    return False


def aplicar_pedagogico_todos():
    """Aplica formato pedagógico a todos los bloques."""
    print("=" * 70)
    print("APLICAR FORMATO PEDAGÓGICO A TODOS LOS BLOQUES")
    print("=" * 70)
    
    archivos = sorted(BLOQUES_DIR.rglob("contenido.md"))
    
    if not archivos:
        print("✗ No se encontraron bloques")
        return False
    
    print(f"\nEncontrados {len(archivos)} bloques")
    
    modificados = 0
    for ruta in archivos:
        if procesar_bloque(ruta):
            modificados += 1
    
    print()
    print("=" * 70)
    print(f"✅ Formato aplicado: {modificados}/{len(archivos)} bloques modificados")
    print("=" * 70)
    
    return modificados > 0


if __name__ == "__main__":
    modificados = aplicar_pedagogico_todos()
    sys.exit(0 if modificados else 1)
