"""Genera bloques de ejemplo para el piloto."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOQUES_DIR = ROOT / "capacitacion" / "bloques"


def crear_bloque(id_bloque, data):
    """Crea un bloque con sus archivos."""
    bloque_dir = BLOQUES_DIR / id_bloque
    bloque_dir.mkdir(parents=True, exist_ok=True)
    
    # Crear bloque.json
    with open(bloque_dir / "bloque.json", "w", encoding="utf-8") as f:
        json.dump(data["meta"], f, indent=2, ensure_ascii=False)
    
    # Crear contenido.md
    (bloque_dir / "contenido.md").write_text(data["contenido"], encoding="utf-8")
    
    # Crear carpeta de imágenes
    (bloque_dir / "imagenes").mkdir(exist_ok=True)
    
    print(f"✓ Bloque creado: {id_bloque}")


def generar_bloques():
    """Genera los 10 bloques piloto."""
    
    bloques = [
        # 1. Configuración de tipos de bodega
        {
            "id": "configuracion-de-tipos-de-bodega",
            "meta": {
                "id": "configuracion-de-tipos-de-bodega",
                "titulo": "Configuración de tipos de bodega",
                "version": "1.0.0",
                "temas": ["inventario", "configuracion"],
                "procesos": ["inventario"],
                "orden": {"inventario": 1, "configuracion": 5},
                "prerrequisitos": [],
                "variantes": [],
                "duracionEstimada": "20min",
                "fuente": {
                    "proceso": "inventario",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["ITBOD", "bodega", "tipo"],
                "estable": True
            },
            "contenido": """# Configuración de tipos de bodega

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Los tipos de bodega (ITBOD) definen las categorías de almacenamiento disponibles en el sistema. Cada tipo determina las características y comportamientos de las bodegas que lo usan.

Tipos comunes:
- **Farmacia** — Medicamentos y dispositivos médicos
- **Alimentos** — Cocina y alimentación
- **Papelería** — Suministros de oficina
- **Aseo** — Productos de limpieza
- **Insumos médicos** — Material quirúrgico y hospitalario

## Invariante

> Cada tipo de bodega debe tener un código único y un nombre descriptivo. Los tipos activos determinan qué bodegas pueden crearse.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ITBOD`  
**Rol:** Crea, modifica o elimina tipos de bodega

## Pasos

1. Ir a **Inventario → Configuración → Tipos de bodega**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre del tipo
4. Definir si maneja lotes, vencimientos o refrigeración
5. Guardar

## Errores comunes

- **Código duplicado** — El código del tipo ya existe  
  **Solución:** Usar un código único

- **Tipo en uso** — No se puede eliminar porque hay bodegas asociadas  
  **Solución:** Eliminar primero las bodegas o cambiar su tipo
"""
        },
        
        # 2. Configuración de bodegas
        {
            "id": "configuracion-de-bodegas",
            "meta": {
                "id": "configuracion-de-bodegas",
                "titulo": "Configuración de bodegas",
                "version": "1.0.0",
                "temas": ["inventario", "configuracion"],
                "procesos": ["inventario"],
                "orden": {"inventario": 2, "configuracion": 6},
                "prerrequisitos": ["configuracion-de-tipos-de-bodega"],
                "variantes": [],
                "duracionEstimada": "30min",
                "fuente": {
                    "proceso": "inventario",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["IBOD", "bodega", "almacén"],
                "estable": True
            },
            "contenido": """# Configuración de bodegas

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Las bodegas (IBOD) son los almacenes físicos donde se guardan los artículos. Cada bodega pertenece a un tipo y puede tener responsables, sedes y permisos específicos.

## Invariante

> Cada bodega debe tener código único, nombre, tipo de bodega válido y sede. Las bodegas activas pueden recibir movimientos de inventario.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_IBOD`  
**Rol:** Crea, modifica o elimina bodegas

## Pasos

1. Ir a **Inventario → Configuración → Bodegas**
2. Hacer clic en **Nuevo**
3. Seleccionar el **tipo de bodega**
4. Ingresar código, nombre y sede
5. Asignar responsable (opcional)
6. Activar la bodega
7. Guardar

## Errores comunes

- **Código duplicado** — El código de la bodega ya existe  
  **Solución:** Usar un código único

- **Tipo de bodega inactivo** — No se puede crear bodega con tipo inactivo  
  **Solución:** Activar primero el tipo de bodega

- **Bodega con existencias** — No se puede eliminar porque tiene artículos  
  **Solución:** Trasladar o dar salida a todos los artículos antes de eliminar
"""
        },
        
        # 3. Configuración de tipos de artículo
        {
            "id": "configuracion-de-tipos-de-articulo",
            "meta": {
                "id": "configuracion-de-tipos-de-articulo",
                "titulo": "Configuración de tipos de artículo",
                "version": "1.0.0",
                "temas": ["inventario", "configuracion"],
                "procesos": ["inventario"],
                "orden": {"inventario": 3, "configuracion": 7},
                "prerrequisitos": [],
                "variantes": [],
                "duracionEstimada": "20min",
                "fuente": {
                    "proceso": "inventario",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["ITAR", "artículo", "tipo"],
                "estable": True
            },
            "contenido": """# Configuración de tipos de artículo

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

Los tipos de artículo (ITAR) clasifican los productos según su naturaleza y uso. Cada tipo define propiedades como manejo de lotes, vencimientos, refrigeración y regulación.

Tipos comunes:
- **Medicamento** — Requiere lote, vencimiento y registro INVIMA
- **Dispositivo médico** — Requiere lote y registro
- **Insumo** — Sin requerimientos especiales
- **Alimento** — Requiere vencimiento

## Invariante

> Cada tipo debe tener código único y definir si maneja lotes, vencimientos, refrigeración y regulación sanitaria.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ITAR`  
**Rol:** Crea, modifica o elimina tipos de artículo

## Pasos

1. Ir a **Inventario → Configuración → Tipos de artículo**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre
4. Marcar las opciones:
   - Maneja lotes
   - Maneja vencimientos
   - Requiere refrigeración
   - Requiere registro sanitario
5. Guardar

## Errores comunes

- **Código duplicado** — El código ya existe  
  **Solución:** Usar un código único
"""
        },
        
        # 4. Catálogo de artículos
        {
            "id": "catalogo-de-articulos",
            "meta": {
                "id": "catalogo-de-articulos",
                "titulo": "Catálogo de artículos",
                "version": "1.0.0",
                "temas": ["inventario"],
                "procesos": ["inventario"],
                "orden": {"inventario": 4},
                "prerrequisitos": ["configuracion-de-tipos-de-articulo"],
                "variantes": [],
                "duracionEstimada": "40min",
                "fuente": {
                    "proceso": "inventario",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["IART", "artículo", "catálogo"],
                "estable": True
            },
            "contenido": """# Catálogo de artículos

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** Configuración

## Explicación

El catálogo de artículos (IART) contiene todos los productos que la institución puede comprar, almacenar y vender. Cada artículo tiene código, nombre, tipo, unidad de medida, precio y propiedades farmacéuticas si aplica.

## Invariante

> Cada artículo debe tener código único, nombre, tipo válido, unidad de medida y estar asociado a al menos una bodega con mínimos y máximos.

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_IART`  
**Rol:** Crea, modifica o elimina artículos en el catálogo

### SPK_INVENTARIO

**Método:** `CRUD_IDXB`  
**Rol:** Asocia artículo con bodega y define mínimos/máximos

## Pasos

1. Ir a **Inventario → Configuración → Artículos**
2. Hacer clic en **Nuevo**
3. Ingresar código y nombre del artículo
4. Seleccionar tipo de artículo
5. Definir unidad de medida
6. Si es medicamento:
   - Ingresar principio activo
   - Concentración y forma farmacéutica
   - Registro INVIMA
7. Asociar con bodegas:
   - Seleccionar bodega
   - Definir stock mínimo y máximo
   - Ubicación (estante/fila/columna)
8. Guardar

## Errores comunes

- **Código duplicado** — El código del artículo ya existe  
  **Solución:** Usar un código único o buscar el artículo existente

- **Falta tipo de artículo** — No se seleccionó el tipo  
  **Solución:** Seleccionar el tipo apropiado

- **Sin bodega asociada** — El artículo no tiene bodegas  
  **Solución:** Asociar al menos una bodega con mínimos y máximos
"""
        },
        
        # 5. Cotización de compras
        {
            "id": "cotizacion-de-compras",
            "meta": {
                "id": "cotizacion-de-compras",
                "titulo": "Cotización de compras",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 1},
                "prerrequisitos": [],
                "variantes": [],
                "duracionEstimada": "30min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["ICTZ", "cotización", "proveedor"],
                "estable": True
            },
            "contenido": """# Cotización de compras

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Cotización

## Explicación

La cotización (ICTZ) registra las ofertas de proveedores antes de generar la orden de compra. Permite comparar precios, descuentos y plazos de entrega.

## Invariante

> Cada cotización debe tener proveedor, fecha, artículos con cantidades y precios, y estado (Pendiente, Aprobada, Rechazada).

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_ICTZ`  
**Rol:** Crea, modifica o elimina cotizaciones

## Pasos

1. Ir a **Inventario → Procesos → Cotización de compras**
2. Hacer clic en **Nueva cotización**
3. Seleccionar proveedor
4. Ingresar fecha de cotización
5. Agregar artículos:
   - Buscar artículo
   - Ingresar cantidad
   - Precio unitario
   - Descuento (opcional)
6. Revisar subtotal e IVA
7. Guardar como Pendiente
8. Al aprobar: cambiar estado a **Aprobada**

## Siguiente paso

La cotización aprobada se puede convertir en **Orden de compra**.
"""
        },
        
        # 6. Orden de compra
        {
            "id": "orden-de-compra",
            "meta": {
                "id": "orden-de-compra",
                "titulo": "Orden de compra",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 2},
                "prerrequisitos": ["cotizacion-de-compras"],
                "variantes": [
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
                        "omite_prerrequisitos": True
                    }
                ],
                "duracionEstimada": "30min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["FCOM", "orden", "compra"],
                "estable": True
            },
            "contenido": """# Orden de compra

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Orden

## Explicación

La orden de compra (FCOM) es el documento oficial que autoriza al proveedor a entregar los artículos. Puede generarse desde una cotización aprobada o crearse manualmente.

## Invariante

> Cada orden debe tener proveedor, fecha, artículos, cantidades, precios, bodega destino y estado (Creada, Confirmada, Recibida, Anulada).

## Procedimientos almacenados

### SPQ_INVENTARIO

**Método:** `CRUD_FCOM`  
**Rol:** Crea o modifica órdenes de compra

## Pasos

### Desde cotización

1. Ir a **Inventario → Procesos → Cotización de compras**
2. Seleccionar cotización aprobada
3. Hacer clic en **Generar orden de compra**
4. Revisar artículos y precios (se copian de la cotización)
5. Seleccionar bodega destino
6. Guardar

### Manual

1. Ir a **Inventario → Procesos → Orden de compra**
2. Hacer clic en **Nueva orden**
3. Seleccionar proveedor
4. Ingresar fecha esperada de entrega
5. Agregar artículos manualmente:
   - Buscar artículo
   - Cantidad
   - Precio unitario
6. Seleccionar bodega destino
7. Guardar

## Siguiente paso

La orden creada debe **confirmarse** antes de que el proveedor la reciba.
"""
        },
        
        # 7. Confirmación de orden
        {
            "id": "confirmacion-de-orden",
            "meta": {
                "id": "confirmacion-de-orden",
                "titulo": "Confirmación de orden",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 3},
                "prerrequisitos": ["orden-de-compra"],
                "variantes": [],
                "duracionEstimada": "15min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["FCOM", "confirmar", "autorizar"],
                "estable": True
            },
            "contenido": """# Confirmación de orden

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Orden

## Explicación

La confirmación de la orden (FCOM estado Confirmada) autoriza al proveedor a despachar la mercancía. Una vez confirmada, la orden no puede modificarse.

## Invariante

> Solo pueden confirmarse órdenes en estado Creada. La confirmación genera un registro de tránsito para cada artículo.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `CONFIRMAR_ORDEN`  
**Rol:** Confirma la orden y genera registros de tránsito (ITRA)

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden en estado **Creada**
3. Revisar artículos, cantidades y precios
4. Hacer clic en **Confirmar orden**
5. El sistema genera automáticamente:
   - Estado de la orden → **Confirmada**
   - Registros de tránsito (ITRA) para cada artículo
   - PDF de la orden para enviar al proveedor

## Siguiente paso

Cuando el proveedor despache, registrar el **Tránsito de mercancía** (llegada parcial o total).
"""
        },
        
        # 8. Tránsito de mercancía
        {
            "id": "transito-de-mercancia",
            "meta": {
                "id": "transito-de-mercancia",
                "titulo": "Tránsito de mercancía",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 4},
                "prerrequisitos": ["confirmacion-de-orden"],
                "variantes": [],
                "duracionEstimada": "20min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["ITRA", "tránsito", "remisión"],
                "estable": True
            },
            "contenido": """# Tránsito de mercancía

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Tránsito

## Explicación

El tránsito (ITRA) registra la llegada de la mercancía del proveedor. Se ingresa la remisión, las cantidades recibidas y observaciones. El tránsito puede ser parcial (llegadas múltiples) o total.

## Invariante

> Cada tránsito debe tener remisión, fecha, cantidades recibidas ≤ cantidades ordenadas, y estado (Pendiente loteo).

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `ON_ACEPTA_TRANSITO`  
**Rol:** Registra tránsito y crea movimiento temporal (IMOV tipo 02 estado 0)

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden **Confirmada**
3. Hacer clic en **Registrar tránsito**
4. Ingresar número de remisión del proveedor
5. Ingresar fecha de llegada
6. Para cada artículo:
   - Cantidad recibida (puede ser menor que la ordenada)
   - Observaciones si hay faltantes o daños
7. Guardar

## Siguiente paso

El tránsito queda pendiente de **Loteo** para ingresar números de lote, vencimientos y cantidades definitivas.
"""
        },
        
        # 9. Loteo de entrada
        {
            "id": "loteo-de-entrada",
            "meta": {
                "id": "loteo-de-entrada",
                "titulo": "Loteo de entrada",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 5},
                "prerrequisitos": ["transito-de-mercancia"],
                "variantes": [],
                "duracionEstimada": "30min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["lote", "vencimiento", "IEXI"],
                "estable": True
            },
            "contenido": """# Loteo de entrada

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Loteo

## Explicación

El loteo registra números de lote y fechas de vencimiento de los artículos recibidos. Es obligatorio para medicamentos y dispositivos médicos. Cada lote se registra en IEXI con su cantidad específica.

## Invariante

> La suma de cantidades de todos los lotes debe coincidir con la cantidad en tránsito. Artículos con tipo que maneja lote exigen lote y vencimiento.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `LOTEO_TRANSITO`  
**Rol:** Registra lotes (IEXI) y actualiza existencias preliminares

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden con tránsito **Pendiente loteo**
3. Hacer clic en **Lotear**
4. Para cada artículo que maneja lote:
   - Ingresar número de lote del proveedor
   - Fecha de vencimiento
   - Cantidad de este lote
   - Si hay varios lotes, agregar líneas adicionales
5. Verificar que suma de lotes = cantidad en tránsito
6. Guardar

## Siguiente paso

Después del loteo, **Confirmar entrada** para que los artículos ingresen a la bodega y se genere la CxP.
"""
        },
        
        # 10. Entrada confirmada
        {
            "id": "entrada-confirmada",
            "meta": {
                "id": "entrada-confirmada",
                "titulo": "Entrada confirmada",
                "version": "1.0.0",
                "temas": ["orden-compra"],
                "procesos": ["flujo-compras-inv-cxp-caja"],
                "orden": {"orden-compra": 6},
                "prerrequisitos": ["loteo-de-entrada"],
                "variantes": [],
                "duracionEstimada": "20min",
                "fuente": {
                    "proceso": "flujo-compras-inv-cxp-caja",
                    "actualizado": "2026-10-21"
                },
                "palabrasClave": ["IMOV", "entrada", "CxP", "FCXP"],
                "estable": True
            },
            "contenido": """# Entrada confirmada

## Contexto

**Proceso:** Compras, Inventario y CxP  
**Capa:** Entrada

## Explicación

La entrada confirmada ingresa los artículos a la bodega destino, actualiza existencias (IDXB) y genera automáticamente la cuenta por pagar (FCXP) al proveedor.

## Invariante

> La entrada confirma el movimiento de inventario (IMOV tipo 02 estado 0 → estado 1), actualiza IDXB y crea FCXP por el valor de la compra.

## Procedimientos almacenados

### SPK_INVENTARIO

**Método:** `CONF_ENTRADA`  
**Rol:** Confirma entrada, actualiza existencias y genera CxP

## Pasos

1. Ir a **Inventario → Procesos → Orden de compra**
2. Buscar la orden con loteo completo
3. Hacer clic en **Confirmar entrada**
4. Revisar resumen:
   - Artículos con lotes y vencimientos
   - Cantidades que ingresan
   - Valor total de la compra
   - Impuestos (IVA)
5. Confirmar

El sistema automáticamente:
- Actualiza existencias en la bodega (IDXB)
- Genera movimiento de entrada (IMOV estado 1)
- Crea cuenta por pagar (FCXP) al proveedor
- Cambia orden a estado **Recibida**

## Resultado

- Los artículos ya están disponibles en la bodega
- Se generó una CxP pendiente de pago
- La orden queda cerrada
"""
        },
    ]
    
    print("Generando 10 bloques piloto...\n")
    
    for bloque in bloques:
        crear_bloque(bloque["id"], bloque)
    
    print(f"\n✅ {len(bloques)} bloques generados exitosamente")


if __name__ == "__main__":
    generar_bloques()
