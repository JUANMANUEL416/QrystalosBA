"""Genera los bloques piloto para capacitación: Inventario y Orden de compra."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import capacitacion_bloques as bloques


def generar_piloto():
    """Genera bloques desde la KB para el piloto."""
    resultados = []
    
    # Proceso: inventario
    # Los bloques se generan desde los controles documentados en la KB
    
    print("Generando bloques piloto...")
    print("=" * 60)
    
    # Lista de controles a convertir en bloques
    # (proceso_id, control_id, descripción)
    controles_piloto = [
        # Inventario: configuración
        ("inventario", "config-tipo-bodega", "Configuración de tipos de bodega"),
        ("inventario", "config-bodega", "Configuración de bodegas"),
        ("inventario", "config-tipo-articulo", "Configuración de tipos de artículo"),
        ("inventario", "catalogo-articulo", "Catálogo de artículos"),
        
        # Orden de compra
        ("flujo-compras-inv-cxp-caja", "cotizacion", "Cotización de compras"),
        ("flujo-compras-inv-cxp-caja", "orden-compra", "Orden de compra"),
        ("flujo-compras-inv-cxp-caja", "confirmar-orden", "Confirmación de orden"),
        ("flujo-compras-inv-cxp-caja", "transito", "Tránsito de mercancía"),
        ("flujo-compras-inv-cxp-caja", "loteo", "Loteo de entrada"),
        ("flujo-compras-inv-cxp-caja", "entrada-confirmada", "Entrada confirmada"),
    ]
    
    for proceso_id, control_id, desc in controles_piloto:
        print(f"\n{desc}...")
        print(f"  Proceso: {proceso_id}")
        print(f"  Control: {control_id}")
        
        resultado = bloques.generar_bloque_desde_control(
            proceso_id=proceso_id,
            control_id=control_id,
            forzar=False
        )
        
        if resultado.get("ok"):
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
    import sys
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
