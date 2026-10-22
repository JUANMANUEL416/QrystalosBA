#!/usr/bin/env python3
"""
Genera bloques de capacitación para todos los módulos de la KB.
Lee proceso.json de cada módulo y genera bloques estándar.
"""
import json
import sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parent.parent
CONOCIMIENTO = ROOT / "conocimiento"

# Definición de módulos principales con iconos y colores
MODULOS = {
    "facturacion": {
        "nombre": "Facturación",
        "descripcion": "Facturación hospitalaria: eventos, cápita, procedimientos, RIPS JSON y XML DIAN",
        "icono": "receipt_long",
        "color": "#D32F2F",
        "emoji_bloque": "🧾",
        "orden_tema": 4,
    },
    "caja": {
        "nombre": "Caja",
        "descripcion": "Apertura de caja, recibos de ingreso/egreso, medios de pago, cierre y cuadre",
        "icono": "point_of_sale",
        "color": "#7B1FA2",
        "emoji_bloque": "💰",
        "orden_tema": 5,
    },
    "cxp-fcxp": {
        "nombre": "Cuentas por Pagar",
        "descripcion": "Registro de facturas, contabilización, orden de pago, autorización y egreso de caja",
        "icono": "payments",
        "color": "#0097A7",
        "emoji_bloque": "💳",
        "orden_tema": 6,
    },
    "contabilidad": {
        "nombre": "Contabilidad",
        "descripcion": "Movimientos contables, comprobantes, cierre de periodo y reportes financieros",
        "icono": "account_balance",
        "color": "#5D4037",
        "emoji_bloque": "📊",
        "orden_tema": 7,
    },
    "recaudos": {
        "nombre": "Recaudos y Cartera",
        "descripcion": "Recaudos, aplicación de pagos, conciliaciones bancarias y gestión de cartera",
        "icono": "account_balance_wallet",
        "color": "#F57C00",
        "emoji_bloque": "💵",
        "orden_tema": 3,
    },
    "glosas": {
        "nombre": "Glosas",
        "descripcion": "Gestión de glosas: registro, respuesta, conciliación y recuperación de cartera glosada",
        "icono": "flag",
        "color": "#C62828",
        "emoji_bloque": "🚩",
        "orden_tema": 8,
    },
    "radicaciones": {
        "nombre": "Radicaciones",
        "descripcion": "Radicación de facturas ante pagadores: RIPS, documentos soporte y seguimiento",
        "icono": "send",
        "color": "#6A1B9A",
        "emoji_bloque": "📤",
        "orden_tema": 9,
    },
    "nomina": {
        "nombre": "Nómina",
        "descripcion": "Liquidación de nómina, conceptos, deducciones, aportes parafiscales y contabilización",
        "icono": "groups",
        "color": "#558B2F",
        "emoji_bloque": "👥",
        "orden_tema": 10,
    },
}

# Escenas genéricas por tipo de bloque
ESCENAS_GENERICAS = {
    "configuracion": "Configuración de parámetros en sistema hospitalario: usuario administrador definiendo catálogos y reglas operativas",
    "proceso": "Proceso operativo en sistema hospitalario: usuario ejecutando flujo paso a paso con validaciones",
    "contabilizacion": "Contador revisando comprobantes contables en pantalla: verificando cuentas, valores y centros de costo",
    "reporte": "Usuario consultando reporte en sistema hospitalario: aplicando filtros y exportando datos",
}


def leer_proceso(modulo_id):
    """Lee el proceso.json de un módulo."""
    proceso_path = CONOCIMIENTO / modulo_id / "proceso.json"
    if not proceso_path.exists():
        return None
    
    try:
        return json.loads(proceso_path.read_text(encoding='utf-8'))
    except Exception as e:
        print(f"  ⚠️  Error leyendo {modulo_id}/proceso.json: {e}")
        return None


def generar_bloques_desde_proceso(modulo_id, proceso_data, modulo_config):
    """Genera lista de bloques desde el proceso.json."""
    bloques = []
    
    # Bloque 1: Configuración general del módulo (siempre presente)
    bloques.append({
        "id": f"{modulo_id}-configuracion",
        "titulo": f"Configuración de {modulo_config['nombre']}",
        "descripcion": f"Configuración inicial del módulo {modulo_config['nombre']}: parámetros, variables y catálogos maestros",
        "orden": 1,
        "prerrequisitos": [],
        "tipo": "configuracion",
    })
    
    # Generar bloques desde controles del proceso si existen
    if "controles" in proceso_data or "gates" in proceso_data:
        controles = proceso_data.get("controles", proceso_data.get("gates", []))
        
        for idx, control in enumerate(controles[:10], 2):  # Máximo 10 controles
            control_id = control.get("id", f"control-{idx}")
            control_nombre = control.get("nombre", f"Control {idx}")
            
            bloques.append({
                "id": f"{modulo_id}-{control_id}",
                "titulo": control_nombre,
                "descripcion": control.get("explicacion", f"Proceso {control_nombre} en {modulo_config['nombre']}"),
                "orden": idx,
                "prerrequisitos": [f"{modulo_id}-configuracion"],
                "tipo": "proceso",
            })
    
    # Si no hay controles, crear bloques genéricos basados en el resumen
    elif len(bloques) == 1:
        # Bloques genéricos para módulos sin controles detallados
        bloques_genericos = [
            {"id": "registro", "titulo": "Registro", "tipo": "proceso"},
            {"id": "validacion", "titulo": "Validación", "tipo": "proceso"},
            {"id": "contabilizacion", "titulo": "Contabilización", "tipo": "contabilizacion"},
            {"id": "reportes", "titulo": "Reportes", "tipo": "reporte"},
        ]
        
        for idx, bg in enumerate(bloques_genericos, 2):
            bloques.append({
                "id": f"{modulo_id}-{bg['id']}",
                "titulo": f"{bg['titulo']} de {modulo_config['nombre']}",
                "descripcion": f"Proceso de {bg['titulo'].lower()} en módulo {modulo_config['nombre']}",
                "orden": idx,
                "prerrequisitos": [f"{modulo_id}-configuracion"],
                "tipo": bg["tipo"],
            })
    
    return bloques


def crear_bloque_json(modulo_id, bloque_def, modulo_config):
    """Crea el bloque.json."""
    return {
        "id": bloque_def["id"],
        "titulo": bloque_def["titulo"],
        "version": "1.0.0",
        "temas": [modulo_id],
        "procesos": [modulo_id],
        "orden": {
            modulo_id: bloque_def["orden"]
        },
        "prerrequisitos": bloque_def["prerrequisitos"],
        "variantes": [],
        "duracionEstimada": "20min",
        "icono": modulo_config["emoji_bloque"],
        "fuente": {
            "proceso": modulo_id,
            "actualizado": "2026-10-22"
        },
        "palabrasClave": [modulo_id.upper()],
        "estable": False,
        "generado": datetime.now().isoformat()
    }


def crear_contenido_md(bloque_def, modulo_config):
    """Crea el contenido.md."""
    return f"""# {bloque_def['titulo']}

{modulo_config['emoji_bloque']}

## Contexto

**Proceso:** {modulo_config['nombre']}
**Capa:** {bloque_def['tipo']}

## Explicación

{bloque_def['descripcion']}

## Ideas principales

- **Proceso principal**: El usuario accede al módulo y ejecuta el flujo paso a paso
- **Validaciones**: El sistema valida permisos, periodo abierto y datos obligatorios
- **Efecto**: Los cambios se reflejan en las tablas maestras y transaccionales
- **Contabilización**: Si aplica, genera comprobante contable en módulo de contabilidad
- **Errores comunes**: Periodo cerrado, permisos insuficientes, datos incompletos

## Campos decisivos y visibles

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| **ESTADO** | Registro principal | 0=pendiente, 1=procesado/confirmado |
| **PERIODO** | Periodo | Debe estar abierto para operar |
| **USUARIO** | Sesión | Permisos según USGRUH |
| **FECHA** | Registro | Fecha de operación |

## Variables de configuración (USVGS)

⚠️ Pendiente validar: Variables específicas del módulo en conocimiento/{modulo_config['nombre'].lower()}/

## Usuario final

- **Usuario operativo**: Registra y procesa transacciones en el módulo
- **Contador**: Revisa contabilización si aplica
- **Supervisor**: Valida y autoriza operaciones críticas
- **Soporte**: Configura parámetros y resuelve incidencias

## Soporte y desarrollo

### Procedimientos almacenados

⚠️ Pendiente validar: SPs específicos en conocimiento/{modulo_config['nombre'].lower()}/sps.json

**SP Principal**  
**Propósito:** Ejecuta la lógica principal del proceso  
**Valida:** Permisos, periodo abierto, datos obligatorios  
**Qué hace:** Actualiza tablas maestras y transaccionales  
**Errores:** «Periodo cerrado», «Permiso denegado», «Datos incompletos»

### Ejemplos reales

- **Ejemplo 1**: ⚠️ Pendiente validar con datos reales del cliente
- **Ejemplo 2**: ⚠️ Pendiente validar con datos reales del cliente
- **Ejemplo 3**: ⚠️ Pendiente validar con datos reales del cliente

## Pendiente validar

- ⚠️ SPs específicos en conocimiento/{modulo_config['nombre'].lower()}/sps.json
- ⚠️ Variables USVGS del módulo
- ⚠️ Tablas maestras y transaccionales
- ⚠️ Flujo detallado paso a paso
- ⚠️ Ejemplos reales con datos de cliente
"""


def generar_escena(bloque_def, modulo_config):
    """Genera la escena sin códigos de tabla."""
    tipo = bloque_def["tipo"]
    escena_base = ESCENAS_GENERICAS.get(tipo, ESCENAS_GENERICAS["proceso"])
    
    return f"{modulo_config['nombre']}: {escena_base}"


def main():
    print("=" * 70)
    print("GENERANDO BLOQUES PARA TODOS LOS MÓDULOS")
    print("=" * 70)
    print()
    
    bloques_dir = ROOT / "capacitacion" / "bloques"
    total_bloques = 0
    modulos_procesados = []
    modulos_omitidos = []
    
    for modulo_id, modulo_config in MODULOS.items():
        print(f"\n[{modulo_config['nombre']}]")
        print("-" * 70)
        
        # Leer proceso.json
        proceso_data = leer_proceso(modulo_id)
        
        if not proceso_data:
            print(f"  ⚠️  Sin proceso.json, omitiendo...")
            modulos_omitidos.append((modulo_id, "Sin proceso.json"))
            continue
        
        # Generar bloques
        bloques = generar_bloques_desde_proceso(modulo_id, proceso_data, modulo_config)
        
        if not bloques:
            print(f"  ⚠️  No se pudieron generar bloques")
            modulos_omitidos.append((modulo_id, "No se pudieron generar bloques"))
            continue
        
        print(f"  Generando {len(bloques)} bloques...")
        
        for bloque_def in bloques:
            # Crear directorio
            bloque_dir = bloques_dir / bloque_def["id"]
            bloque_dir.mkdir(parents=True, exist_ok=True)
            
            # Crear bloque.json
            bloque_json = crear_bloque_json(modulo_id, bloque_def, modulo_config)
            (bloque_dir / "bloque.json").write_text(
                json.dumps(bloque_json, indent=2, ensure_ascii=False),
                encoding="utf-8"
            )
            
            # Crear contenido.md
            contenido_md = crear_contenido_md(bloque_def, modulo_config)
            (bloque_dir / "contenido.md").write_text(contenido_md, encoding="utf-8")
            
            print(f"    ✓ {bloque_def['titulo']} (orden {bloque_def['orden']})")
            total_bloques += 1
        
        modulos_procesados.append((modulo_id, modulo_config['nombre'], len(bloques)))
    
    print()
    print("=" * 70)
    print(f"✅ {total_bloques} bloques creados en {len(modulos_procesados)} módulos")
    print("=" * 70)
    print()
    
    if modulos_procesados:
        print("Módulos procesados:")
        for mid, mnombre, mbloques in modulos_procesados:
            print(f"  - {mnombre}: {mbloques} bloques")
    
    if modulos_omitidos:
        print("\nMódulos omitidos:")
        for mid, razon in modulos_omitidos:
            print(f"  - {mid}: {razon}")
    
    return modulos_procesados, modulos_omitidos


if __name__ == "__main__":
    main()
