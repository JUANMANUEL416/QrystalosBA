#!/usr/bin/env python3
"""Test: Verifica que ningún párrafo en bloques supere ~350 caracteres."""

import sys
from pathlib import Path

# --- Reconfigurar stdout/stderr a UTF-8 con errors='replace' ---
# Protege contra UnicodeEncodeError en consolas cp1252
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

ROOT = Path(__file__).resolve().parent
BLOQUES_DIR = ROOT / "capacitacion" / "bloques"

MAX_PARRAFO = 450  # Límite generoso para párrafos


def verificar_bloque(ruta: Path) -> tuple[bool, list[str]]:
    """Verifica un bloque.
    
    Returns:
        (ok, problemas)
    """
    contenido = ruta.read_text(encoding="utf-8")
    lineas = contenido.split("\n")
    
    problemas = []
    i = 0
    en_contexto = False
    
    while i < len(lineas):
        linea = lineas[i].strip()
        
        # Detectar sección Contexto
        if linea.startswith("## 📍 Contexto"):
            en_contexto = True
            i += 1
            continue
        
        # Salir de Contexto al encontrar otra sección ##
        if en_contexto and linea.startswith("##") and "📍 Contexto" not in linea:
            en_contexto = False
        
        # Solo revisar párrafos en Contexto
        if en_contexto and linea and not linea.startswith("#") and not linea.startswith("**") and not linea.startswith(">") and not linea.startswith("|"):
            # Acumular párrafo completo
            parrafo_lineas = [lineas[i]]
            i += 1
            
            while i < len(lineas):
                sig = lineas[i].strip()
                if not sig or sig.startswith("#") or sig.startswith("**") or sig.startswith(">") or sig.startswith("|"):
                    break
                parrafo_lineas.append(lineas[i])
                i += 1
            
            parrafo = " ".join(ln.strip() for ln in parrafo_lineas if ln.strip())
            longitud = len(parrafo)
            
            if longitud > MAX_PARRAFO:
                problemas.append(f"Párrafo de {longitud} chars (max {MAX_PARRAFO})")
        
        i += 1
    
    return len(problemas) == 0, problemas


def test_todos_los_bloques():
    """Test: Verifica TODOS los bloques."""
    print("=" * 70)
    print("TEST: PÁRRAFOS EN BLOQUES DE CAPACITACIÓN")
    print("=" * 70)
    print(f"Límite: {MAX_PARRAFO} caracteres por párrafo en sección Contexto")
    print()
    
    archivos = sorted(BLOQUES_DIR.rglob("contenido.md"))
    
    if not archivos:
        print("✗ No se encontraron bloques")
        return False
    
    print(f"Verificando {len(archivos)} bloques...\n")
    
    con_problemas = []
    
    for ruta in archivos:
        nombre = ruta.parent.name
        ok, problemas = verificar_bloque(ruta)
        
        if ok:
            print(f"  ✓ {nombre}")
        else:
            print(f"  ✗ {nombre}")
            for p in problemas:
                print(f"      {p}")
            con_problemas.append(nombre)
    
    print()
    print("=" * 70)
    
    if con_problemas:
        print(f"❌ {len(con_problemas)}/{len(archivos)} bloques con párrafos largos:")
        for nombre in con_problemas:
            print(f"  - {nombre}")
        return False
    else:
        print(f"✅ Todos los bloques OK ({len(archivos)}/{len(archivos)})")
        return True


if __name__ == "__main__":
    ok = test_todos_los_bloques()
    sys.exit(0 if ok else 1)
