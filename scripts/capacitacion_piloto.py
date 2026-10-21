"""Genera los bloques piloto para capacitación: Inventario y Orden de compra."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_bloques as bloques


def generar_piloto():
    """Genera bloques desde la KB para el piloto."""
    resultados = []
    
    print("Generando bloques piloto...")
    print("=" * 60)
    
    # Lista de controles a convertir en bloques
    # (proceso_id, control_id, descripción, variantes, prerrequisitos)
    controles_piloto = [
        # Inventario: configuración
        ("inventario", "config-tipo-bodega", "Configuración de tipos de bodega", None, []),
        ("inventario", "config-bodega", "Configuración de bodegas", None, ["configuracion-de-tipos-de-bodega"]),
        ("inventario", "config-tipo-articulo", "Configuración de tipos de artículo", None, []),
        ("inventario", "catalogo-articulo", "Catálogo de artículos", None, ["configuracion-de-tipos-de-articulo"]),
        
        # Orden de compra (con variantes)
        ("flujo-compras-inv-cxp-caja", "cotizacion", "Cotización de compras", None, []),
        ("flujo-compras-inv-cxp-caja", "orden-compra", "Orden de compra", 
         [
             {
                 "id": "desde-cotizacion",
                 "nombre": "Desde cotización",
                 "entrada": "Cotización aprobada",
                 "omite_prerrequisitos": False
             },
             {
                 "id": "manual",
                 "nombre": "Manual (sin cotización)",
                 "entrada": "Proveedor seleccionado",
                 "omite_prerrequisitos": True  # No requiere cotización
             }
         ], 
         ["cotizacion-de-compras"]),
        ("flujo-compras-inv-cxp-caja", "confirmar-orden", "Confirmación de orden", None, ["orden-de-compra"]),
        ("flujo-compras-inv-cxp-caja", "transito", "Tránsito de mercancía", None, ["confirmacion-de-orden"]),
        ("flujo-compras-inv-cxp-caja", "loteo", "Loteo de entrada", None, ["transito-de-mercancia"]),
        ("flujo-compras-inv-cxp-caja", "entrada-confirmada", "Entrada confirmada", None, ["loteo-de-entrada"]),
    ]
    
    for proceso_id, control_id, desc, variantes, prereqs in controles_piloto:
        print(f"\n{desc}...")
        print(f"  Proceso: {proceso_id}")
        print(f"  Control: {control_id}")
        
        resultado = bloques.generar_bloque_desde_control(
            proceso_id=proceso_id,
            control_id=control_id,
            forzar=False,
            variantes=variantes
        )
        
        # Actualizar prerrequisitos y marcar como estable
        if resultado.get("ok"):
            bloque_id = resultado["bloque_id"]
            bloque_path = bloques.BLOQUES_DIR / bloque_id / "bloque.json"
            
            if bloque_path.exists():
                with open(bloque_path, encoding="utf-8") as f:
                    bloque_data = json.load(f)
                
                # Actualizar prerrequisitos
                if prereqs:
                    bloque_data["prerrequisitos"] = prereqs
                
                # Marcar como estable
                bloque_data["estable"] = True
                
                with open(bloque_path, "w", encoding="utf-8") as f:
                    json.dump(bloque_data, f, indent=2, ensure_ascii=False)
            
            print(f"  ✓ Bloque generado: {resultado['bloque_id']}")
            resultados.append({
                "proceso": proceso_id,
                "control": control_id,
                "bloque_id": resultado["bloque_id"],
                "ok": True
            })
        else:
            error = resultado.get("error", "desconocido")
            if error == "bloque_estable":
                print(f"  • Bloque ya existe: {resultado.get('bloque_id')}")
            elif error == "control_no_existe":
                print(f"  ✗ Control no existe en la KB")
            else:
                print(f"  ✗ Error: {error}")
                print(f"    {resultado.get('mensaje', '')}")
            
            resultados.append({
                "proceso": proceso_id,
                "control": control_id,
                "ok": False,
                "error": error
            })
    
    print("\n" + "=" * 60)
    print(f"Resumen: {sum(1 for r in resultados if r['ok'])} bloques generados")
    print(f"         {sum(1 for r in resultados if not r['ok'])} bloques omitidos")
    
    return resultados


if __name__ == "__main__":
    if sys.stdout.encoding != 'utf-8':
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
        sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')
    
    try:
        generar_piloto()
        print("\n✅ Piloto generado correctamente")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
