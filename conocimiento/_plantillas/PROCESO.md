# Proceso: {{NOMBRE}}

**Estado:** esqueleto | parcial | listo  
**Módulo:** {{MODULO}}

> Solo flujo y explicación. El cuerpo de los SP se lee de DESAIX o de la copia local `sql/`/`sql_refe/` (fuera de git); aquí solo queda el nombre del SP, sus métodos y validaciones (cita `SP:línea`).

## Resumen

{{RESUMEN}}

## Procedimientos (`sps.json`)

Por cada SP, una ficha **por METODO** (se llena al leer el script):

- **hace** — de qué se encarga en el proceso
- **valida** — qué comprueba
- **noValida** — huecos (qué no comprueba)
- **errores** — textos KO que ve el usuario
- **llama** — SPK/SPQ anidados
- **efecto** — qué queda cierto si responde OK

No copiar el cuerpo del procedimiento.

## Capas

### 1. Configuración

Qué debe estar parametrizado **antes** de operar.

**Invariante:** …

**SP de este control (nombres, no cuerpos):** …

### 2. Proceso propio

Acciones del usuario (abrir, confirmar, etc.).

**Invariante / controles:** …

### 3. Lo que llega y completa

Orígenes externos que alimentan este proceso.

### 4. Subproceso unido (p. ej. bancos)

Solo el encuentro con este proceso, no el módulo entero.

### 5. Envío a contabilidad

Qué se entrega al asiento y qué se asume ya validado.

## Pendiente

- [ ] …
