# Qrys.Quatec — Oficina de coordinación

Proyecto de **coordinación técnica** para Qrystalos. No contiene código de la aplicación; genera dictámenes HTML para desarrolladores a partir de requerimientos del cliente.

## Tres agentes

Para evitar cruce de contexto y chats lentos, el trabajo se reparte en tres roles. Contrato de handoff: [`conocimiento/HANDOFF.md`](conocimiento/HANDOFF.md).

| Agente | Menú | Regla | Escribe |
|--------|------|-------|---------|
| **Conocimiento** | Documentar | `.cursor/rules/agente-conocimiento.mdc` | `conocimiento/` (sps, proceso, pendientes, chat Documentar) |
| **Consultas** | Consultas | `.cursor/rules/agente-consultas.mdc` | Chat de consultas + handoffs a Conocimiento |
| **Requerimientos** | Analista | `.cursor/rules/agente-requerimientos.mdc` | `activo/`, `dictamenes/` |

El archivo `.cursor/rules/coordinador-qrystalos.mdc` actúa como **router** (alwaysApply): elige el modo según menú / `tarea.json` / `activo/{id}/`.

**No implementa** cambios en Qrystalos2, backend ni base de datos.

**OpenAI no interviene.** Cada agente pregunta solo lo que le falta en su modo.

### Dominio compartido

- **Qrystalos2** (Vue 3 / Quasar PWA) — rutas, componentes, stores, `AppStore.read` / `AppStore.json`, permisos USGRUH.
- **SQL Server** — tablas, vistas, stored procedures, convenciones de nomenclatura.
- **Documentación de tablas** — índices, runbooks, relaciones FK (proyecto vivo).
- **Procesos administrativos** — `conocimiento/` (flujo, invariantes y catálogo SP → METODO; no cuerpos de SP).

## Flujo por requerimiento (agente Requerimientos)

1. Usuario elige **Analista de negocio** en el menú central y completa el formulario (métodos documentados o SQL en `sql/`).
2. Ubicar el proceso en `conocimiento/INDICE.json`. Si no existe, esqueleto + pendientes (vía handoff a Conocimiento).
3. Agente verifica solicitud; si hay `sql.usarDocumentacion`, usa `sps.json` y en el Chat valida si hay que releer. Si falta algo no documentado, **se detiene y lo pide** o escala a Conocimiento.
4. Investiga Qrystalos2, documentación de tablas **viva** y el flujo en `conocimiento/`.
5. Genera `dictamenes/<ID>.html`.
6. Responde con resumen + ruta del archivo.

Los SP **no se archivan** en la base de procesos. Se bajan a `sql/` el día que hay que documentarlos o releerlos (agente Conocimiento).

## Regla principal

**Detenerse y pedir** cualquier SP, script, aclaración o dato faltante. No inventar ni continuar el análisis incompleto.

## Estructura

```
config/rutas.json          # Rutas configurables
plantillas/dictamen.html   # Plantilla HTML
dictamenes/                # Salida de dictámenes
conocimiento/              # Flujos de proceso + pendientes + HANDOFF.md
conocimiento/handoffs/     # Cola entre agentes
.cursor/rules/             # Router + 3 reglas de agente
```

## Configuración

Editar `config/rutas.json` para cambiar rutas de Qrystalos2, documentación o carpeta de salida.

## Reglas

Ver `.cursor/rules/coordinador-qrystalos.mdc` (router, alwaysApply) y las tres reglas `agente-*.mdc`.
