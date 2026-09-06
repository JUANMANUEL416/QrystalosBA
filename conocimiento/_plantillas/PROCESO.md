# Proceso: {{NOMBRE}}

**Estado:** esqueleto | parcial | listo  
**Módulo:** {{MODULO}}

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

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

**SP de este gate (nombres, no cuerpos):** …

### 2. Proceso propio

Acciones del usuario (abrir, confirmar, etc.).

**Invariante / gates:** …

### 3. Lo que llega y completa

Orígenes externos que alimentan este proceso.

### 4. Subproceso unido (p. ej. bancos)

Solo el encuentro con este proceso, no el módulo entero.

### 5. Envío a contabilidad

Qué se entrega al asiento y qué se asume ya validado.

## Pendiente

- [ ] …
