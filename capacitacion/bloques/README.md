# Bloques de Capacitación

Esta carpeta contiene bloques modulares de capacitación reutilizables. Cada bloque es un proceso pequeño y estándar documentado en la base de conocimiento.

## Estructura de un bloque

```
capacitacion/bloques/{id-bloque}/
├── bloque.json          # Metadatos del bloque
├── contenido.md         # Contenido en Markdown
└── imagenes/            # Ilustraciones del bloque
    ├── mapa-mental.png
    └── paso-*.png
```

## bloque.json

```json
{
  "id": "configuracion-bodega",
  "titulo": "Configuración de bodegas",
  "version": "1.0.0",
  "temas": ["inventario", "configuracion"],
  "procesos": ["inventario"],
  "orden": {
    "inventario": 1,
    "configuracion": 5
  },
  "prerrequisitos": [],
  "variantes": [],
  "duracionEstimada": "30min",
  "fuente": {
    "proceso": "inventario",
    "seccion": "capas[0].controles[0]",
    "actualizado": "2026-10-18T16:20:00"
  },
  "palabrasClave": ["bodega", "IBOD", "tipo de bodega", "ITBOD"],
  "estable": true
}
```

## Campos obligatorios

- **id**: Identificador único del bloque (slug kebab-case)
- **titulo**: Título descriptivo
- **temas**: Lista de temas/módulos a los que pertenece
- **procesos**: Lista de procesos de la KB que cubre
- **orden**: Orden sugerido dentro de cada tema (número)
- **prerrequisitos**: IDs de bloques que deben ir antes
- **fuente**: Referencia a la KB (proceso, sección, fecha)

## Variantes

Algunos bloques pueden tener variantes de entrada/salida:

```json
"variantes": [
  {
    "id": "desde-cotizacion",
    "nombre": "Orden de compra desde cotización",
    "entrada": "Cotización aprobada"
  },
  {
    "id": "manual",
    "nombre": "Orden de compra manual",
    "entrada": "Proveedor seleccionado"
  }
]
```

## Temas disponibles

- `inventario`: Inventario, compras y farmacia
- `configuracion`: Configuración general del sistema
- `cartera`: Recaudos, glosas, conciliaciones
- `facturacion`: Facturación y RIPS
- `contabilidad`: Contabilización y cierre
- `caja`: Apertura, movimientos y cierre de caja
- `cxp`: Cuentas por pagar
- `nomina`: Nómina y conceptos

## Estado del bloque

- **estable**: `true` = bloque listo y estable, no se regenera automáticamente
- **estable**: `false` = bloque en desarrollo, puede regenerarse desde la KB
