# Sistema de Capacitaciones Modulares — Qrystalos BA

Sistema tipo rompecabezas que genera documentos de capacitación desde bloques modulares reutilizables, basados en la base de conocimiento documentada.

## Concepto

Cada **bloque** es un proceso pequeño y estándar (ej. Configuración de bodega, Creación de artículos, Cotización, Orden de compra manual). Los bloques conocen:

- A qué **temas/procesos** pertenecen
- Sus **prerrequisitos** (qué bloques deben ir antes)
- El **orden** sugerido dentro de cada tema
- **Variantes** de entrada (ej. OC desde cotización vs manual)
- Su **fuente** en la base de conocimiento

## Flujo de uso

1. **Abrir la app** → Menú: **Capacitación** (ícono school)
2. **Elegir tema** (Inventario, Orden de compra, Cartera, etc.)
3. **Marcar bloques** deseados (checkboxes)
4. **Generar documento** → el sistema:
   - Resuelve dependencias automáticamente
   - Ordena los bloques topológicamente
   - Une el contenido en un HTML con índice
   - Incrusta ilustraciones (mapas mentales, infografías)
5. **Descargar** el documento HTML (listo para convertir a PDF o DOCX)

Un bloque solo también puede generarse independiente.

## Estructura de archivos

```
capacitacion/
├── bloques/                   # Bloques modulares
│   ├── {id-bloque}/
│   │   ├── bloque.json       # Metadatos
│   │   ├── contenido.md      # Contenido en Markdown
│   │   └── imagenes/         # Ilustraciones (PNG)
│   │       ├── mapa-mental.png
│   │       └── infografia.png
│   └── README.md
├── documentos/                # Documentos generados
│   └── {timestamp}-{slug}.html
├── temas.json                 # Catálogo de temas
└── README.md
```

## Temas disponibles (piloto)

1. **Inventario** — Configuración de bodegas, artículos, compras, movimientos
2. **Orden de Compra** — Desde cotización o manual, confirmación, tránsito, loteo
3. **Cartera** — Recaudos, aplicación, glosas, conciliaciones
4. **Facturación** — Eventos, cápita, RIPS JSON, XML DIAN
5. **Caja** — Apertura, recibos, medios de pago, cierre
6. **Cuentas por Pagar** — Registro, contabilización, orden de pago, egreso
7. **Contabilidad** — Movimientos, comprobantes, cierre de periodo
8. **Configuración** — Tablas generales, variables, permisos

## Generar bloques desde la KB

Los bloques se generan desde los **controles documentados** en `conocimiento/{proceso}/proceso.json`:

```python
import capacitacion_bloques as bloques

# Generar un bloque desde un control
resultado = bloques.generar_bloque_desde_control(
    proceso_id="inventario",
    control_id="config-bodega",
    forzar=False  # No regenerar si ya existe y está estable
)

if resultado["ok"]:
    print(f"Bloque generado: {resultado['bloque_id']}")
```

### Piloto: Inventario y Orden de compra

```bash
# Genera los bloques piloto desde la KB
python3 scripts/capacitacion_piloto.py
```

Esto crea bloques para:
- Configuración de tipos de bodega
- Configuración de bodegas
- Configuración de tipos de artículo
- Catálogo de artículos
- Cotización de compras
- Orden de compra
- Confirmación de orden
- Tránsito de mercancía
- Loteo de entrada
- Entrada confirmada

## Ilustraciones automáticas

Si está configurado `OPENAI_API_KEY` en `.env`, el sistema genera ilustraciones con OpenAI Images:

```python
import capacitacion_bloques as bloques

resultado = bloques.generar_ilustracion_bloque(
    bloque_id="configuracion-de-bodegas",
    regenerar=False
)
```

Cada bloque obtiene:
1. **Mapa mental** de los conceptos clave
2. **Infografía** del proceso (pasos principales)

Las imágenes se cachean por bloque (no se regeneran si existen).

Variables en `.env`:
```bash
OPENAI_API_KEY=sk-proj-...
OPENAI_IMAGE_MODEL=gpt-image-1
```

## Ensamblar documentos

```python
import capacitacion_ensamblar as ensamblar

resultado = ensamblar.ensamblar_documento(
    tema_id="inventario",
    bloques_ids=["config-bodega", "catalogo-articulo", "orden-compra"],
    titulo="Capacitación: Inventario básico",
    formato="html",
    incluir_indice=True,
    incluir_imagenes=True
)

if resultado["ok"]:
    print(f"Documento: {resultado['archivo_html']}")
    print(f"Bloques: {resultado['bloques']}")
    if resultado.get("agregados"):
        print(f"Prerrequisitos agregados: {resultado['agregados']}")
```

El ensamblador:
- Resuelve dependencias automáticamente
- Ordena topológicamente
- Une contenido con transiciones
- Incrusta imágenes como data URIs (documento auto-contenido)
- Genera portada, índice y pie de página
- Produce HTML imprimible (Ctrl+P → PDF)

## API REST

### GET /api/capacitacion/temas

Lista todos los temas disponibles.

**Respuesta:**
```json
{
  "ok": true,
  "temas": [
    {
      "id": "inventario",
      "nombre": "Inventario, Compras y Farmacia",
      "descripcion": "...",
      "modulo": "INVENTARIO",
      "procesos": ["inventario", "flujo-compras-inv-cxp-caja"],
      "orden": 1,
      "icono": "inventory_2",
      "color": "#1976D2"
    }
  ]
}
```

### GET /api/capacitacion/bloques?tema={id}

Lista bloques de un tema (ordenados).

**Respuesta:**
```json
{
  "ok": true,
  "bloques": [
    {
      "id": "configuracion-de-bodegas",
      "titulo": "Configuración de bodegas",
      "version": "1.0.0",
      "temas": ["inventario"],
      "orden": { "inventario": 1 },
      "prerrequisitos": ["configuracion-de-tipos-de-bodega"],
      "duracionEstimada": "30min",
      "palabrasClave": ["IBOD", "ITBOD"],
      "imagenes": [...]
    }
  ]
}
```

### GET /api/capacitacion/bloque/{id}

Obtiene un bloque con su contenido.

**Respuesta:**
```json
{
  "ok": true,
  "bloque": { /* metadatos */ },
  "contenido": "# Configuración de bodegas\n\n..."
}
```

### POST /api/capacitacion/generar-bloque

Genera un bloque desde un control de la KB.

**Body:**
```json
{
  "procesoId": "inventario",
  "controlId": "config-bodega",
  "forzar": false
}
```

**Respuesta:**
```json
{
  "ok": true,
  "bloque_id": "configuracion-de-bodegas",
  "bloque_dir": "capacitacion/bloques/configuracion-de-bodegas",
  "mensaje": "Bloque generado exitosamente."
}
```

### POST /api/capacitacion/generar-ilustracion

Genera ilustraciones para un bloque con OpenAI Images.

**Body:**
```json
{
  "bloqueId": "configuracion-de-bodegas",
  "regenerar": false
}
```

**Respuesta:**
```json
{
  "ok": true,
  "imagenes": [
    {
      "nombre": "mapa-mental.png",
      "tipo": "mapa_mental",
      "titulo": "Mapa mental: Configuración de bodegas"
    }
  ],
  "total": 2
}
```

### POST /api/capacitacion/ensamblar

Ensambla un documento desde bloques seleccionados.

**Body:**
```json
{
  "temaId": "inventario",
  "bloquesIds": ["config-bodega", "catalogo-articulo"],
  "titulo": "Capacitación: Inventario básico",
  "formato": "html",
  "incluirIndice": true,
  "incluirImagenes": true
}
```

**Respuesta:**
```json
{
  "ok": true,
  "archivo_html": "capacitacion/documentos/20261021-161820-capacitacion-inventario-basico.html",
  "bloques": ["config-tipo-bodega", "config-bodega", "catalogo-articulo"],
  "agregados": ["config-tipo-bodega"],
  "titulo": "Capacitación: Inventario básico"
}
```

## Tests

```bash
# Ejecutar tests del sistema
python3 test_capacitacion_bloques.py
```

Cobertura:
- ✓ Cargar temas
- ✓ Conversión a slug
- ✓ Generar bloque desde control
- ✓ Resolver dependencias
- ✓ Ensamblar documento
- ✓ Conversión Markdown → HTML

## Reglas del repositorio

**NO** commitear:
- `capacitacion/documentos/*.html` (generados por el usuario)
- Bloques inestables o de prueba
- Imágenes de más de 2 MB

**SÍ** commitear:
- `capacitacion/bloques/{id}/*.json` (metadatos estables)
- `capacitacion/bloques/{id}/contenido.md` (bloques listos)
- `capacitacion/bloques/{id}/imagenes/*.png` (ilustraciones cacheadas)
- `capacitacion/temas.json` (catálogo de temas)

## Estilo del documento generado

- **Portada:** Logo IX Colombia, título, descripción del tema, fecha
- **Índice:** Numerado, con enlaces a cada bloque
- **Bloques:** Número, título, imágenes (mapa mental + infografía), contenido Markdown → HTML
- **Transiciones:** Flecha visual entre bloques
- **Pie de página:** Marca del sistema y empresa
- **Impresión:** CSS print-friendly (sin sombras, page-break-inside: avoid)
- **Colores:** Naranja #E67817 (énfasis), grises y azules suaves

## Próximos pasos

1. **Generar bloques restantes** desde la KB (CxP, Facturación, Contabilidad)
2. **Variantes de entrada** (ej. OC desde cotización vs manual)
3. **Exportar a DOCX** (además de HTML)
4. **Ilustraciones por sección** (pasos del proceso con diagramas)
5. **Mapas mentales del tema completo** (antes del índice)
6. **Búsqueda de bloques** (por palabras clave, proceso, control)
7. **Versionado de bloques** (track de cambios cuando se actualiza la KB)

## Soporte

Para dudas o reportes: Business Analyst — IX Colombia SAS
