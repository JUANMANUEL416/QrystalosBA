# Plan de Refactorización - Sistema de Capacitación Modular

## Feedback del usuario (main 92bb43f)

### 1. GRANULARIDAD
❌ **Problema:** Los bloques mezclan varias tablas maestras
- Ejemplo: 'Tipo de artículo y artículo (ITAR/IART/SER)' debe ser 3 bloques independientes

✅ **Solución:** Un bloque = una tabla maestra o un proceso pequeño
- **ITAR** (tipos de artículo): MLOTEO, MFECHAVENCIMIENTO, MIVA, PRECNS/MCNS, MPRINCIPAL, MSTOCK
- **IART** (artículos): IDITAR+Activo, IDSERVICIO, IDIMPUESTO, PRINCIPAL, REGINVIMA, CODCUM, UNID_VENTA  
- **SER** (servicios): para facturación, KMCOM, centro de costo

Prerrequisitos: IART requiere ITAR, IDXB requiere IART

### 2. GUION DETALLADO
❌ **Problema:** Contenido superficial, no explica cada campo

✅ **Solución:** Guion de capacitación detallado desde KB real
- Explicar cada campo/parámetro relevante con:
  * Qué es
  * Para qué sirve
  * Qué pasa si se marca o no
  * Ejemplo práctico
  * Errores comunes
- Fuente: `conocimiento/` (procesos, grafos, sps con métodos y validaciones)
- Si la KB no tiene el dato: marcar 'Pendiente validar' y registrar como gap
- Usar LLM (Cursor SDK) para redactar desde la KB si es necesario

### 3. PEDAGÓGICO Y ATRACTIVO
❌ **Problema:** HTML plano, poco atractivo

✅ **Solución:** Formato pedagógico visual
- **Iconos** por sección (Material Symbols ya en la app)
- **Cajas especiales:**
  * 🎯 Objetivo
  * ⚠️ Importante
  * 💡 Tip
  * ❌ Error común
  * 📝 Ejemplo
- **Tablas de campos** con descripción y efecto
- **Pasos numerados** con iconos
- **Resumen** al final
- **Mini quiz/autoevaluación**
- **Mapa mental o infografía** por bloque
- **Imágenes** (OpenAI via `scripts/capacitacion_ilustracion.py` con OPENAI_IMAGE_MODEL)
  * Tamaño proporcional al texto
  * Cacheadas por bloque
  * Respaldo: diagramas mermaid/SVG generados localmente si no hay key

## Implementación

### Archivo 1: `scripts/capacitacion_bloques.py`

#### Nuevas funciones:

```python
def generar_bloque_desde_tabla(
    proceso_id: str,
    tabla: str,  # ej: "ITAR", "IART", "SER"
    titulo: str,
    control_padre_id: str = None,
    forzar: bool = False
) -> dict:
    """Genera un bloque granular desde una tabla específica."""
    # Similar a generar_bloque_desde_control pero más granular
    # Lee la KB, extrae info de la tabla, genera contenido pedagógico
```

```python
def _generar_contenido_pedagogico(
    tabla: str,
    proceso: dict,
    control: dict,
    kb_docs: list[dict]
) -> str:
    """Genera contenido markdown pedagógico detallado.
    
    Estructura:
    1. Objetivo del bloque (🎯)
    2. Contexto y ubicación en el proceso
    3. Campos/parámetros (tabla con icono, nombre, descripción, efecto, ejemplo)
    4. Flujo paso a paso (numerado con iconos)
    5. Importante (⚠️ cajas)
    6. Tips (💡)
    7. Errores comunes (❌)
    8. Ejemplos prácticos (📝)
    9. Resumen
    10. Autoevaluación (mini quiz)
    11. [Pendiente validar] para gaps
    """
```

#### Mapeo de bloques a separar:

```python
# De esto:
bloques_viejos = [
    "tipos-de-bodega-bodegas-y-catalogos",  # → ITBOD + IBOD separados
    "tipos-de-movimiento-y-variables-usvgs",  # → ITMO + USVGS separados
    "tipo-de-articulo-y-articulo-itar-iart-ser",  # → ITAR + IART + SER separados
]

# A esto:
bloques_nuevos_granulares = [
    # Configuración de bodegas
    {"tabla": "ITBOD", "titulo": "Tipos de bodega (ITBOD)", "prereq": []},
    {"tabla": "IBOD", "titulo": "Bodegas (IBOD)", "prereq": ["tipos-de-bodega-itbod"]},
    
    # Configuración de movimientos
    {"tabla": "ITMO", "titulo": "Tipos de movimiento (ITMO)", "prereq": []},
    {"tabla": "USVGS", "titulo": "Variables de sistema (USVGS)", "prereq": []},
    
    # Configuración de artículos
    {"tabla": "ITAR", "titulo": "Tipos de artículo (ITAR)", "prereq": []},
    {"tabla": "IART", "titulo": "Artículos (IART)", "prereq": ["tipos-de-articulo-itar"]},
    {"tabla": "SER", "titulo": "Servicios (SER)", "prereq": ["articulos-iart"]},
    {"tabla": "IDXB", "titulo": "Artículo por bodega (IDXB)", "prereq": ["articulos-iart", "bodegas-ibod"]},
]
```

### Archivo 2: `scripts/capacitacion_ensamblar.py`

#### Actualizar `_generar_html`:

```python
def _generar_html(tema, titulo, bloques, incluir_indice, incluir_imagenes):
    """
    Agregar CSS para:
    - .objetivo-box (🎯)
    - .importante-box (⚠️)
    - .tip-box (💡)
    - .error-box (❌)
    - .ejemplo-box (📝)
    - .campo-tabla (tabla de campos con icono, nombre, descripción, efecto)
    - .paso-numerado (pasos con iconos)
    - .quiz-box (autoevaluación)
    - .resumen-box (resumen al final)
    - .gap-pendiente (pendiente validar)
    """
```

### Archivo 3: `scripts/capacitacion_piloto.py`

#### Regenerar piloto con bloques granulares:

```python
bloques_piloto_granulares = [
    # Configuración de bodegas (2 bloques)
    ("inventario", "ITBOD", "Tipos de bodega (ITBOD)"),
    ("inventario", "IBOD", "Bodegas (IBOD)"),
    
    # Configuración de movimientos (2 bloques)
    ("inventario", "ITMO", "Tipos de movimiento (ITMO)"),
    ("inventario", "USVGS", "Variables de sistema (USVGS)"),
    
    # Configuración de artículos (4 bloques)
    ("inventario", "ITAR", "Tipos de artículo (ITAR)"),
    ("inventario", "IART", "Artículos (IART)"),
    ("inventario", "SER", "Servicios (SER)"),
    ("inventario", "IDXB", "Artículo por bodega (IDXB)"),
    
    # Flujo de compras (6 bloques - sin cambios)
    # ... (cotización, orden, tránsito, loteo, aceptar, confirmar entrada)
]
```

### Archivo 4: `test_capacitacion_granularidad.py`

```python
def test_bloque_no_mezcla_tablas():
    """Test: Un bloque no debe mezclar ITAR/IART/SER."""
    bloques = listar_bloques()
    
    for bloque in bloques:
        titulo = bloque.get("titulo", "")
        # Buscar patrones que mezclan tablas
        patron_mixto = r"(ITAR.*IART|IART.*SER|ITAR.*SER|ITBOD.*IBOD|ITMO.*USVGS)"
        assert not re.search(patron_mixto, titulo, re.IGNORECASE), \
            f"Bloque '{titulo}' mezcla varias tablas maestras"
```

## Fuentes de información (KB)

### Para ITAR:
- `conocimiento/flujo-compras-inv-cxp-caja/CATALOGO-ARTICULO.md` (líneas 14-22)
- `conocimiento/inventario/proceso.json` → control `iart-maestro` → sps SPQ_ITAR

### Para IART:
- `conocimiento/flujo-compras-inv-cxp-caja/CATALOGO-ARTICULO.md` (líneas 24-35)
- `conocimiento/inventario/proceso.json` → control `iart-maestro` → sps SPQ_IART

### Para IBOD/ITMO/USVGS:
- `conocimiento/flujo-compras-inv-cxp-caja/CONFIG-BODEGA-TIPO-MOV.md`
- `conocimiento/inventario/proceso.json` → controles `catalogo-configuracion` y `catalogo-itmo`

## Reglas

❌ **No commitear:**
- `.env`
- `config/cursor-api-key-active.json`
- `config/desarrolladores.json`
- `historico/`
- `cola/`
- `sql/`
- `sql_refe/`

❌ **No imprimir credenciales**

## Entregables

1. ✅ Bloques regenerados en `capacitacion/bloques/` (14+ bloques granulares)
2. ✅ Tests que validan granularidad
3. ✅ Commit con lista de bloques resultantes en el mensaje
4. ✅ PR con reporte de bloques

## Estado actual

- Branch: `cursor/capacitacion-granular-pedagogico-73a4`
- Este documento creado para guiar la implementación
- Siguiente paso: Implementar funciones de generación pedagógica
