# Base de conocimiento — procesos administrativos

Mapa de **flujos de proceso** para coordinar requerimientos y atender consultas (p. ej. una llamada de caja). No es un diccionario de tablas ni un archivo de stored procedures.

## Qué se guarda aquí

- Flujo por proceso (capas y gates) con una **explicación**.
- Invariantes: qué debe ser cierto para cerrar un paso.
- Nombre y **rol** del SP en ese gate (no el cuerpo del procedimiento).
- Catálogo `{proceso}/sps.json`: **SP → METODO** (hace, valida, noValida, errores KO, llama, efecto). Se completa cada vez que se lee un `.sql`.
- Lista de **pendientes** (Documentar).

## Qué no se guarda

- Cuerpos de `SPQ_` / `SPK_` (se actualizan a diario: hay que bajarlos a `sql/` y pasarlos).
- Copias de `qrystalos.documentacion` ni de Qrystalos2. Esas fuentes se consultan **vivas** en cada análisis.

## Cómo se usa

| Entrada en el menú central | Uso |
|----------------------------|-----|
| Analista de negocio | Cola, casos, dictámenes |
| Consultas | Flujo (capa → gate) y Procedimientos (SP → método) |
| Documentar | Pendientes, indicar SP del día, Chat de proceso |

## Regla para el agente

1. En cada REQ: abrir `INDICE.json`, ubicar el proceso. Si no existe, crear esqueleto y dejar pendientes.
2. No inventar flujo ni validaciones de SP sin el `.sql` de hoy en `sql/`.
3. Tras leer un SP: en `{proceso}/sps.json` documentar cada `METODO` (hace, valida, noValida, errores, llama, efecto). Actualizar el gate en `proceso.json` solo si cambia el flujo. No copiar el script.
4. Si faltan SP o capas: filas en `pendientes.json`.
5. Releer `tarea.json` y `chat.json` cuando el coordinador documente desde la app.
