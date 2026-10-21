#!/usr/bin/env python3
"""
Regenera contenido.md de todos los bloques aplicando formato pedagógico:
- Separa párrafos densos en ideas principales con subtítulo + icono
- Máximo ~3 frases o ~350 caracteres por párrafo
- Añade cajas Importante/Tip donde aplique
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOQUES_DIR = ROOT / "capacitacion" / "bloques"

# Iconos para ideas principales (rotamos)
ICONOS_IDEAS = ["🔹", "🔸", "💊", "🏥", "📦", "🔬", "⚕️", "🩺"]


def separar_parrafo_denso(parrafo: str) -> list[str]:
    """Separa un párrafo denso en ideas principales.
    
    Detecta:
    - Múltiples puntos seguidos (más de 3 frases)
    - Más de ~350 caracteres
    - Mezcla de muchas ideas (y, también, además, TABLA, SP, método)
    
    Returns:
        Lista de párrafos separados (cada uno con subtítulo si aplica)
    """
    # Si es corto y simple, devolverlo tal cual
    if len(parrafo) < 350 and parrafo.count(". ") <= 2:
        return [parrafo]
    
    # Detectar oraciones (split por punto + espacio/mayúscula)
    oraciones = re.split(r'\.\s+(?=[A-Z])', parrafo)
    
    # Si hay 3 o menos oraciones y no es muy largo, dejarlo
    if len(oraciones) <= 3 and len(parrafo) < 500:
        return [parrafo]
    
    # Dividir en chunks de ~2-3 oraciones o ~300 caracteres
    ideas = []
    chunk_actual = []
    chars_actual = 0
    
    for oracion in oraciones:
        oracion_clean = oracion.strip()
        if not oracion_clean:
            continue
        
        # Asegurar que termine en punto
        if not oracion_clean.endswith('.'):
            oracion_clean += '.'
        
        # Si añadir esta oración supera el límite, cerrar chunk
        if chunk_actual and (len(chunk_actual) >= 2 or chars_actual + len(oracion_clean) > 350):
            ideas.append(' '.join(chunk_actual))
            chunk_actual = []
            chars_actual = 0
        
        chunk_actual.append(oracion_clean)
        chars_actual += len(oracion_clean)
    
    # Añadir último chunk
    if chunk_actual:
        ideas.append(' '.join(chunk_actual))
    
    return ideas if len(ideas) > 1 else [parrafo]


def extraer_ideas_principales(parrafo: str) -> list[tuple[str, str]]:
    """Extrae ideas principales de un párrafo denso y genera subtítulos.
    
    Returns:
        Lista de (subtitulo, contenido)
    """
    ideas = separar_parrafo_denso(parrafo)
    
    if len(ideas) == 1:
        # No hay separación, devolver sin subtítulo
        return [("", ideas[0])]
    
    # Generar subtítulos inteligentes
    resultado = []
    for i, idea in enumerate(ideas):
        # Intentar extraer el tema principal de las primeras palabras
        palabras = idea.split()[:10]
        tema = None
        
        # Buscar palabras clave para el subtítulo
        if any(kw in idea.upper() for kw in ["TABLA", "ITAR", "IART", "SPQ_", "SPK_"]):
            tema = "Tablas y procedimientos"
        elif any(kw in idea.upper() for kw in ["SKU", "PRINCIPAL", "PRESENTACIÓN"]):
            tema = "Artículos principal y SKU"
        elif any(kw in idea.upper() for kw in ["CONSECUTIVO", "CÓDIGO", "PREFIJO"]):
            tema = "Generación de códigos"
        elif any(kw in idea.upper() for kw in ["LOTEO", "LOTE", "VENCIMIENTO"]):
            tema = "Control de lotes y vencimiento"
        elif any(kw in idea.upper() for kw in ["FILTRO", "BÚSQUEDA", "CUM", "INVIMA"]):
            tema = "Búsqueda y filtros"
        elif any(kw in idea.upper() for kw in ["VALIDACIÓN", "ERROR", "CONF_"]):
            tema = "Validaciones"
        elif any(kw in idea.upper() for kw in ["SERVICIO", "SER", "FACTUR"]):
            tema = "Servicios y facturación"
        elif any(kw in idea.upper() for kw in ["BODEGA", "STOCK", "EXISTENCIA"]):
            tema = "Control de inventario"
        elif any(kw in idea.upper() for kw in ["MEDICAMENTO", "FÁRMACO", "DROGA"]):
            tema = "Medicamentos"
        elif any(kw in idea.upper() for kw in ["IVA", "IMPUESTO", "CONTAB"]):
            tema = "Contabilidad e impuestos"
        else:
            # Genérico
            tema = f"Detalle {i+1}"
        
        icono = ICONOS_IDEAS[i % len(ICONOS_IDEAS)]
        subtitulo = f"{icono} **{tema}**"
        
        resultado.append((subtitulo, idea))
    
    return resultado


def procesar_contenido_md(ruta: Path) -> bool:
    """Procesa un contenido.md aplicando formato pedagógico.
    
    Returns:
        True si se modificó el archivo
    """
    print(f"  Procesando: {ruta.relative_to(BLOQUES_DIR)}")
    
    contenido = ruta.read_text(encoding="utf-8")
    lineas = contenido.split("\n")
    
    resultado = []
    modificado = False
    i = 0
    
    while i < len(lineas):
        linea = lineas[i]
        
        # Detectar sección Contexto (donde suelen estar los párrafos densos)
        if linea.strip().startswith("## 📍 Contexto"):
            resultado.append(linea)
            i += 1
            
            # Saltar líneas vacías y metadata
            while i < len(lineas) and (not lineas[i].strip() or lineas[i].strip().startswith("**Proceso:**")):
                resultado.append(lineas[i])
                i += 1
            
            # Acumular el párrafo completo (puede ser multilínea)
            parrafo_completo = []
            while i < len(lineas):
                l = lineas[i].strip()
                if not l:
                    # Fin del párrafo
                    break
                if l.startswith("#") or l.startswith("---") or l.startswith("|") or l.startswith("**"):
                    # Nueva sección, no es parte del párrafo
                    break
                parrafo_completo.append(lineas[i])
                i += 1
            
            if parrafo_completo:
                parrafo_texto = " ".join(ln.strip() for ln in parrafo_completo if ln.strip())
                
                # Verificar si es denso (más de 400 chars o 4+ frases)
                num_frases = parrafo_texto.count(". ")
                es_denso = len(parrafo_texto) > 400 or num_frases >= 4
                
                if es_denso:
                    print(f"    → Separando párrafo denso ({len(parrafo_texto)} chars, {num_frases} frases)")
                    
                    ideas = extraer_ideas_principales(parrafo_texto)
                    
                    for subtitulo, idea in ideas:
                        resultado.append("")
                        if subtitulo:
                            resultado.append(subtitulo)
                            resultado.append("")
                        resultado.append(idea)
                    
                    modificado = True
                else:
                    # Párrafo corto, dejarlo
                    resultado.extend(parrafo_completo)
            
            continue
        
        # Cualquier otra línea
        resultado.append(linea)
        i += 1
    
    if modificado:
        nuevo_contenido = "\n".join(resultado)
        ruta.write_text(nuevo_contenido, encoding="utf-8")
        print(f"    ✓ Modificado")
        return True
    else:
        print(f"    - Sin cambios")
        return False


def regenerar_todos_los_bloques():
    """Regenera contenido.md de todos los bloques."""
    print("=" * 70)
    print("REGENERACIÓN DE CONTENIDO PEDAGÓGICO")
    print("=" * 70)
    print()
    
    archivos_md = sorted(BLOQUES_DIR.rglob("contenido.md"))
    
    if not archivos_md:
        print("✗ No se encontraron archivos contenido.md")
        return False
    
    print(f"Encontrados {len(archivos_md)} archivos contenido.md")
    print()
    
    modificados = 0
    for ruta in archivos_md:
        if procesar_contenido_md(ruta):
            modificados += 1
    
    print()
    print("=" * 70)
    print(f"✅ Regeneración completa: {modificados}/{len(archivos_md)} modificados")
    print("=" * 70)
    
    return modificados > 0


if __name__ == "__main__":
    modificados = regenerar_todos_los_bloques()
    sys.exit(0 if modificados else 1)
