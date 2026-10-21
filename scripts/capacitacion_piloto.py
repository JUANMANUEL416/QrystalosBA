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
    
    # Proceso: inventario y orden de compra
    # Los bloques se generan desde los controles reales documentados en la KB
    
    print("Generando bloques piloto...")
    print("=" * 60)
    
    # Lista de bloques a generar desde controles de inventario
    # (proceso_id, control_id, descripción)
    controles_inventario = [
        ("inventario", "catalogo-configuracion", "Tipos de bodega, bodegas y catálogos"),
        ("inventario", "catalogo-itmo", "Tipos de movimiento y variables USVGS"),
        ("inventario", "iart-maestro", "Tipo de artículo y artículo (ITAR / IART / SER)"),
        ("inventario", "imov-entrada", "Entrada de almacén y confirmación"),
    ]
    
    # Bloques desde el flujo de compras (proceso transversal)
    # (proceso_id, paso_id, título, variantes)
    pasos_compras = [
        ("flujo-compras-inv-cxp-caja", "cotizacion", "Cotización de compras", None),
        ("flujo-compras-inv-cxp-caja", "fcom", "Orden de compra", [
            {
                "id": "desde-cotizacion",
                "nombre": "Desde cotización",
                "descripcion": "Orden de compra generada desde una cotización previa",
                "prerrequisitos": ["cotizacion-de-compras"]
            },
            {
                "id": "manual",
                "nombre": "Manual",
                "descripcion": "Orden de compra creada directamente sin cotización previa",
                "prerrequisitos": []
            }
        ]),
        ("flujo-compras-inv-cxp-caja", "itra_transito", "Tránsito de compra", None),
        ("flujo-compras-inv-cxp-caja", "loteo_transito", "Loteo en tránsito", None),
        ("flujo-compras-inv-cxp-caja", "acepta_transito", "Aceptar tránsito", None),
        ("flujo-compras-inv-cxp-caja", "imov_entrada", "Confirmar entrada inventario", None),
    ]
    
    # Generar bloques desde controles
    for proceso_id, control_id, desc in controles_inventario:
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
                "fuente": control_id,
                "bloque_id": resultado["bloque_id"],
                "ok": True
            })
        else:
            error = resultado.get("error", "desconocido")
            if error == "bloque_estable":
                print(f"  • Bloque ya existe: {resultado.get('bloque_id')}")
                resultados.append({
                    "proceso": proceso_id,
                    "fuente": control_id,
                    "bloque_id": resultado.get("bloque_id"),
                    "ok": True
                })
            else:
                print(f"  ✗ Error: {error}")
                print(f"    {resultado.get('mensaje', '')}")
                resultados.append({
                    "proceso": proceso_id,
                    "fuente": control_id,
                    "ok": False,
                    "error": error
                })
    
    # Generar bloques desde pasos del proceso transversal
    for proceso_id, paso_id, titulo, variantes in pasos_compras:
        print(f"\n{titulo}...")
        print(f"  Proceso: {proceso_id}")
        print(f"  Paso: {paso_id}")
        
        resultado = bloques.generar_bloque_desde_paso(
            proceso_id=proceso_id,
            paso_id=paso_id,
            titulo=titulo,
            forzar=False
        )
        
        if resultado.get("ok"):
            print(f"  ✓ Bloque generado: {resultado['bloque_id']}")
            
            # Si hay variantes, agregarlas al bloque
            if variantes:
                bloque_path = ROOT / "capacitacion" / "bloques" / resultado["bloque_id"] / "bloque.json"
                with open(bloque_path, "r", encoding="utf-8") as f:
                    bloque_meta = json.load(f)
                bloque_meta["variantes"] = variantes
                with open(bloque_path, "w", encoding="utf-8") as f:
                    json.dump(bloque_meta, f, indent=2, ensure_ascii=False)
                print(f"  ✓ Variantes agregadas: {', '.join(v['id'] for v in variantes)}")
            
            resultados.append({
                "proceso": proceso_id,
                "fuente": paso_id,
                "bloque_id": resultado["bloque_id"],
                "ok": True
            })
        else:
            error = resultado.get("error", "desconocido")
            if error == "bloque_estable":
                print(f"  • Bloque ya existe: {resultado.get('bloque_id')}")
                
                # Si hay variantes, agregarlas al bloque existente
                if variantes:
                    bloque_path = ROOT / "capacitacion" / "bloques" / resultado.get("bloque_id") / "bloque.json"
                    if bloque_path.exists():
                        with open(bloque_path, "r", encoding="utf-8") as f:
                            bloque_meta = json.load(f)
                        bloque_meta["variantes"] = variantes
                        with open(bloque_path, "w", encoding="utf-8") as f:
                            json.dump(bloque_meta, f, indent=2, ensure_ascii=False)
                        print(f"  ✓ Variantes actualizadas: {', '.join(v['id'] for v in variantes)}")
                
                resultados.append({
                    "proceso": proceso_id,
                    "fuente": paso_id,
                    "bloque_id": resultado.get("bloque_id"),
                    "ok": True
                })
            else:
                print(f"  ✗ Error: {error}")
                print(f"    {resultado.get('mensaje', '')}")
                resultados.append({
                    "proceso": proceso_id,
                    "fuente": paso_id,
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
