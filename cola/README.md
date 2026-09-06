# Cola de trabajo — Páginas guardadas de ixonline

Evita transcribir manualmente los datos de avalasesor.

## Dos formas de guardar

### A) Lista de requerimientos (flujo diario)

1. Guarde la tabla aval técnico (**Ctrl+S**) como `aval-asesor-lista.htm` en esta carpeta.
2. En Qrys.Quatec → **Examinar…** (o **Registrar** con servidor local).
3. Se registran **todos los REQ nuevos** en la cola automáticamente.
4. Los REQ que ya estaban en cola se **omiten** (aún en espera de aval).
5. Trabaje **uno a uno** con **Abrir** en la tabla.

Cada día ixonline agrega filas nuevas; al volver a guardar la misma lista, solo entran los que falten.

### B) Detalle de un solo requerimiento

1. Abra el requerimiento en ixonline (vista detalle).
2. **Ctrl+S** → guarde como **`{ID-REQ}.html`** (ej. `0100016193.html`).
3. Copie el archivo aquí y regístrelo en la app.

> **Nota:** Si guardó la lista completa, el ID `0100016198` solo aparecerá si esa fila estaba visible al guardar. Revise la tabla o guarde el detalle del REQ.

## Flujo

```
ixonline avalasesor  →  Guardar HTML en cola/  →  Agente lee el archivo
                              ↓
                    Usted dicta análisis en el formulario (paso 3)
                              ↓
                    SQL en sql/{id-caso}/  (nombres fijos, ver formulario)
                              ↓
                    Agente genera dictamen  →  Aprobados en aprobados/{id-caso}/
```

El agente **lee `cola/*.html`** directamente del disco. No hace falta copiar todo al chat.

## Archivo ya copiado

- `aval-asesor-lista.htm` — lista de aval técnico (15 REQ visibles; use **Elegir REQ**).

## Servidor local (recomendado)

Si abre la app con doble clic (`file://`), use **Examinar…** para registrar HTML.
Para leer archivos ya en `cola/` con el botón **Registrar**, ejecute desde la raíz del proyecto:

`servir-app.bat` → abra http://localhost:8765/app/

## Imágenes de refuerzo

Si el dictamen necesita capturas del sistema, el agente las pedirá. Guárdelas en:

`aprobados/{id-caso}/imagenes/`
