# Qrystalos BA — Oficina de coordinación

Proyecto de **coordinación técnica** para Qrystalos. No contiene código de la aplicación; genera dictámenes HTML para desarrolladores a partir de requerimientos del cliente.

## Rol del agente

Coordinador experto en:
- **Qrystalos2** (Vue 3 / Quasar PWA) — rutas, componentes, stores, `AppStore.read` / `AppStore.json`, permisos USGRUH.
- **SQL Server** — tablas, vistas, stored procedures, convenciones de nomenclatura.
- **Documentación de tablas** — índices, runbooks, relaciones FK (proyecto vivo).
- **Procesos administrativos** — `conocimiento/` (flujo, invariantes y catálogo SP → METODO; no cuerpos de SP).

**No implementa** cambios en Qrystalos2, backend ni base de datos.

**OpenAI no interviene.** El agente en Cursor analiza, propone criterios, organiza análisis/recomendación, responde el Chat y genera dictámenes — una sola opinión con fundamento.

## Flujo por requerimiento

1. Usuario elige **Analista de negocio** en el menú central y completa el formulario (métodos documentados o SQL en `sql/`).
2. Ubicar el proceso en `conocimiento/INDICE.json`. Si no existe, esqueleto + pendientes.
3. Agente verifica solicitud; si hay `sql.usarDocumentacion`, usa `sps.json` y en el Chat valida si hay que releer. Si falta algo no documentado, **se detiene y lo pide**.
4. Investiga Qrystalos2, documentación de tablas **viva** y el flujo en `conocimiento/`.
5. Genera `dictamenes/<ID>.html`.
6. Responde con resumen + ruta del archivo.

Los SP **no se archivan** en la base de procesos. Se bajan a `sql/` el día que hay que documentarlos o releerlos.

## Regla principal

**Detenerse y pedir** cualquier SP, script, aclaración o dato faltante. No inventar ni continuar el análisis incompleto.

## Estructura

```
config/rutas.json          # Rutas configurables
plantillas/dictamen.html   # Plantilla HTML
dictamenes/                # Salida de dictámenes
conocimiento/              # Flujos de proceso + pendientes
.cursor/rules/             # Reglas del coordinador
```

## Configuración

Editar `config/rutas.json` para cambiar rutas de Qrystalos2, documentación o carpeta de salida.

## Reglas

Ver `.cursor/rules/coordinador-qrystalos.mdc` (alwaysApply).
