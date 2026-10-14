# Capacitación Qrystalos

Módulo estático de cursos prácticos por rol. Se sirve en `/capacitacion/` con el servidor local de QrystalosBA.

## Estructura

- `index.html`: visor del curso.
- `datos/`: contenido independiente de cada curso.
- `js/`: navegación, avance y modos instructor/aprendiz.
- `css/`: presentación responsive e impresión.
- `img/<proceso>/`: capturas reales tomadas en ambiente de pruebas.

## Curso inicial

`datos/caja-cajero.json` contiene la ruta operativa del cajero. Cada lección apunta a una captura en `img/caja/`.

Las capturas se tomaron en el ambiente de pruebas (`/admin/caja`) sin confirmar recibos, sin guardar egresos y sin cerrar la caja. Nombres, documentos y filas de pacientes quedan ocultos. La base `conocimiento/` es fuente de consulta y no se modifica desde este módulo.
