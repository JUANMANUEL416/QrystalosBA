# Base de conocimiento — procesos administrativos

Mapa de **flujos de proceso** para coordinar requerimientos y atender consultas (p. ej. una llamada de caja). No es un diccionario de tablas ni un archivo de stored procedures.

## Vocabulario

**Control** (plural **controles**): paso del proceso —pantalla, botón o confirmación— donde algo debe cumplirse para seguir. En Chat, dictámenes y pantalla se dice control, no «gate». El JSON usa `controles` (fichas antiguas: `gates`).

## Qué se guarda aquí

- Flujo por proceso (capas y controles) con una **explicación**.
- Invariantes: qué debe ser cierto para cerrar un paso.
- Nombre y **rol** del SP en ese control (no el cuerpo del procedimiento).
- Catálogo `{proceso}/sps.json`: **SP → METODO** (hace, valida, noValida, errores KO, llama, efecto). Se completa cada vez que se lee un `.sql`.
- Lista de **pendientes** (Documentar).

## Qué no se guarda

- Cuerpos de `SPQ_` / `SPK_` (cambian por versión). Se leen de DESAIX o de la copia local `sql/` / `sql_refe/`, que está en `.gitignore` y nunca se sube. La ficha guarda nombre del SP, métodos y validaciones, con evidencia `SP:línea`.
- Copias de `qrystalos.documentacion` ni de Qrystalos2. Esas fuentes se consultan **vivas** en cada análisis.

## Cómo se usa

| Entrada en el menú central | Uso |
|----------------------------|-----|
| Analista de negocio | Cola, casos, dictámenes |
| Consultas | Flujo (capa → control) y Procedimientos (SP → método) |
| Documentar | Pendientes, indicar SP del día, Chat de proceso |

## Búsqueda, validación y cola

- **Índice:** `_indice_busqueda.json` (generado por `scripts/kb_indice.py`, se regenera solo tras cada escritura y al arrancar el servidor). Una clave por línea: grep `"SP/METODO"` y abrir el `archivo` desde `linea`. Buscador: `python scripts/kb_buscar.py CLAVE` o `GET /api/kb/buscar?q=CLAVE`.
- **SP repetidos:** `_sp_canonico.json` dice qué proceso manda.
- **Esquemas:** `_schema/*.json`; validar con `python scripts/kb_validar.py` (`--degradar` pasa a `parcial` las fichas `leido` vacías; lista en `_schema/degradados.json`).
- **Pendientes:** `pendientes.json` solo abiertos, con `prioridad`; cerrados en `pendientes-archivo.json` (`scripts/kb_pendientes.py`).
- **Handoffs:** `handoffs/cola.json`, contrato `HANDOFF.md`.

## Regla para el agente

1. En cada REQ: abrir `INDICE.json`, ubicar el proceso. Si no existe, crear esqueleto y dejar pendientes.
2. No inventar flujo ni validaciones de SP sin leer el cuerpo de hoy (DESAIX o copia local `sql/`, fuera de git). Citar la evidencia como `SP:línea`, nunca una ruta `sql/…`.
3. Tras leer un SP: en `{proceso}/sps.json` documentar cada `METODO` (hace, valida, noValida, errores, llama, efecto). Actualizar el control en `proceso.json` solo si cambia el flujo. No copiar el script.
4. Si faltan SP o capas: filas en `pendientes.json`.
5. Releer `tarea.json` y `chat.json` cuando el coordinador documente desde la app.
