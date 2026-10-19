# Documentos de Soporte y Capacitación

Carpeta local para guardar documentos generados por el agente de soporte, con sus respuestas y consultas SQL, para referencia futura.

## Estructura

```
data/documentos-soporte/
├── capacitacion/          # Guías de capacitación y orientación funcional
├── consultas-tecnicas/    # Consultas técnicas con análisis SQL
├── configuracion/         # Documentos de configuración de módulos
└── README.md             # Este archivo
```

## Documentos archivados

### Capacitación

#### `sc20261019-162719-cotizaciones-lista-precio.pdf`
- **Fecha:** 2026-10-19
- **Consulta:** sc20261019-162719
- **Quién pregunta:** Sander Torres (ixcolombia)
- **Tema:** Configuración de bodegas para cotizaciones con listas de precios y órdenes de compra
- **Módulo:** Inventario
- **Proceso:** Compras (cotizaciones → orden de compra)
- **Pasos cubiertos:**
  1. Configurar bodega (IBOD/IBODS)
  2. Variables del sistema (IDINVMOV_COMPRAS, USU_GENERA_ORDEN)
  3. Lista de precios (ILPRE/ILPRED)
  4. Cotización de compras (ICTZ/ICTZD)
  5. Orden de compra (FCOM)
- **Incluye:** Consultas SQL para validar configuración
- **SPs mencionados:** SPQ_ILPRE, SPQ_FCOM, SPQ_IBOD, SPK_INSERT_ITRA_REQ

## Convenciones de nombres

Formato: `{id-consulta}-{tema-corto}.pdf`

Ejemplo: `sc20261019-162719-cotizaciones-lista-precio.pdf`

## Notas

- Esta carpeta está en `.gitignore` (no se sube al repositorio)
- Los documentos se guardan localmente para consulta rápida
- Si necesita el documento original, búsquelo por su ID de consulta
