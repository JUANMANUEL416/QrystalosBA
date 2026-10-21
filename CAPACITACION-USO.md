# Cómo usar el Sistema de Capacitaciones Modulares

Guía rápida para usar el sistema de capacitaciones tipo rompecabezas en Qrystalos BA.

## Inicio rápido

### 1. Generar bloques piloto

La primera vez, genera los bloques de ejemplo desde la base de conocimiento:

```bash
cd /workspace
python3 scripts/capacitacion_piloto.py
```

Esto crea bloques para:
- **Inventario**: Configuración de tipos de bodega, bodegas, tipos de artículo, catálogo de artículos
- **Orden de compra**: Cotización, orden, confirmación, tránsito, loteo, entrada confirmada

### 2. Abrir la aplicación

```bash
abrir-app.bat
```

O visita: http://localhost:8765/app/

### 3. Ir al módulo de Capacitación

En el menú principal, haz clic en:
- **Capacitación** (ícono: school)

## Flujo de trabajo

### Paso 1: Seleccionar tema

Se muestra un grid con los temas disponibles:
- **Inventario, Compras y Farmacia**
- **Orden de Compra**
- **Cartera**
- **Facturación**
- **Caja**
- **Cuentas por Pagar**
- **Contabilidad**
- **Configuración General**

Haz clic en el tema deseado.

### Paso 2: Marcar bloques

Se muestra la lista de bloques del tema, en orden sugerido:
- Cada bloque tiene un checkbox
- Número de módulo
- Título descriptivo
- Prerrequisitos (si aplica)
- Duración estimada
- Cantidad de imágenes y variantes

**Marca los bloques que deseas incluir** en el documento.

El sistema muestra:
- "X bloques seleccionados"
- Botón "Generar documento" (habilitado solo si hay selección)

### Paso 3: Generar documento

Haz clic en **Generar documento**.

El sistema automáticamente:
1. ✅ Resuelve dependencias (agrega prerrequisitos faltantes)
2. ✅ Ordena los bloques topológicamente
3. ✅ Une el contenido con transiciones
4. ✅ Incrusta ilustraciones (mapas mentales, infografías)
5. ✅ Genera portada, índice y pie de página

### Paso 4: Descargar

Se muestra un mensaje de éxito con:
- Cantidad de bloques en el documento
- Prerrequisitos agregados automáticamente (si los hubo)
- Botón **Descargar documento** (abre en nueva pestaña)

El documento HTML está listo para:
- Ver en navegador
- Imprimir a PDF (Ctrl+P)
- Convertir a DOCX con Word/LibreOffice

## Generar más bloques

### Desde un control de la KB

```python
import sys
sys.path.insert(0, 'scripts')
import capacitacion_bloques as bloques

# Generar bloque desde un control documentado
resultado = bloques.generar_bloque_desde_control(
    proceso_id="inventario",
    control_id="config-bodega",
    forzar=False  # No regenerar si ya existe y está estable
)

if resultado["ok"]:
    print(f"Bloque generado: {resultado['bloque_id']}")
    print(f"Directorio: {resultado['bloque_dir']}")
```

### Generar ilustraciones

Si tienes configurado `OPENAI_API_KEY` en `.env`:

```python
resultado = bloques.generar_ilustracion_bloque(
    bloque_id="configuracion-de-bodegas",
    regenerar=False
)

if resultado["ok"]:
    print(f"Imágenes generadas: {resultado['total']}")
```

## Estructura de un bloque

Cada bloque vive en `capacitacion/bloques/{id}/`:

```
configuracion-de-bodegas/
├── bloque.json          # Metadatos
├── contenido.md         # Contenido en Markdown
└── imagenes/            # Ilustraciones
    ├── mapa-mental.png
    └── infografia.png
```

### bloque.json

```json
{
  "id": "configuracion-de-bodegas",
  "titulo": "Configuración de bodegas",
  "version": "1.0.0",
  "temas": ["inventario"],
  "procesos": ["inventario"],
  "orden": {
    "inventario": 2
  },
  "prerrequisitos": ["configuracion-de-tipos-de-bodega"],
  "variantes": [],
  "duracionEstimada": "30min",
  "fuente": {
    "proceso": "inventario",
    "control": "config-bodega",
    "actualizado": "2026-10-18T16:20:00"
  },
  "palabrasClave": ["IBOD", "ITBOD", "bodega"],
  "estable": true
}
```

### contenido.md

Markdown estándar con:
- Título (# H1)
- Contexto (proceso, capa)
- Explicación
- Invariante (> blockquote)
- Procedimientos almacenados
- Errores comunes

## API REST

Si prefieres usar la API directamente:

### Listar temas

```bash
curl http://localhost:8765/api/capacitacion/temas
```

### Listar bloques de un tema

```bash
curl "http://localhost:8765/api/capacitacion/bloques?tema=inventario"
```

### Ensamblar documento

```bash
curl -X POST http://localhost:8765/api/capacitacion/ensamblar \
  -H "Content-Type: application/json" \
  -d '{
    "temaId": "inventario",
    "bloquesIds": ["config-bodega", "catalogo-articulo"],
    "titulo": "Capacitación: Inventario básico",
    "formato": "html",
    "incluirIndice": true,
    "incluirImagenes": true
  }'
```

## Tips

### 1. Un bloque solo

Puedes generar un documento con un solo bloque:
- Selecciona solo el bloque deseado
- El sistema agregará automáticamente sus prerrequisitos

### 2. Prerrequisitos automáticos

Si seleccionas "Orden de compra" sin "Cotización", el sistema:
- Detecta la dependencia
- Agrega "Cotización" automáticamente
- Ordena correctamente (Cotización → Orden)
- Te informa: "Se agregaron 1 prerrequisito"

### 3. Bloques estables

Un bloque marcado como `"estable": true` no se regenera automáticamente.
Para forzar regeneración:

```python
bloques.generar_bloque_desde_control(
    proceso_id="inventario",
    control_id="config-bodega",
    forzar=True  # Regenerar aunque exista
)
```

### 4. Imágenes grandes

Las imágenes se incrustan como data URIs en el HTML.
Si el documento es muy grande (>10 MB), considera:
- Regenerar ilustraciones en menor resolución
- Usar formato sin imágenes y agregarlas manualmente después

### 5. Personalizar el documento

El HTML generado es editable:
- Abrir en editor de texto
- Modificar CSS inline (colores, fuentes, espaciado)
- Agregar o quitar secciones
- Guardar como nuevo archivo

## Solución de problemas

### "No hay bloques disponibles para este tema"

- Genera bloques desde la KB: `python3 scripts/capacitacion_piloto.py`
- O genera bloques manualmente con `capacitacion_bloques.py`

### "Error al generar ilustración"

- Verifica que `OPENAI_API_KEY` esté configurado en `.env`
- O genera el documento sin imágenes (el sistema continúa sin fallar)

### "Dependencias circulares"

No debería ocurrir con bloques de la KB. Si pasa:
- Verifica que los prerrequisitos en `bloque.json` sean correctos
- No debe haber ciclos (A → B → A)

### El documento no se ve bien en PDF

- Usa Chrome/Edge para imprimir (mejor soporte CSS)
- En la ventana de impresión: "Más opciones" → "Gráficos de fondo"
- Orientación: Vertical
- Márgenes: Predeterminados

## Próximos pasos

1. Explora los bloques generados en `capacitacion/bloques/`
2. Genera bloques para otros temas (CxP, Facturación, Contabilidad)
3. Personaliza `capacitacion/temas.json` con nuevos temas
4. Crea variantes de bloques (ej. OC manual vs desde cotización)
5. Comparte tus documentos generados con el equipo

## Soporte

Para dudas o reportes:
- **Business Analyst** — IX Colombia SAS
- Pull Request: https://github.com/JUANMANUEL416/QrystalosBA/pull/35
- Documentación técnica: `capacitacion/README.md`
