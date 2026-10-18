# Qrystalos BA — Oficina de coordinación

Proyecto de **coordinación técnica** para Qrystalos. No contiene código de la aplicación; genera dictámenes HTML para desarrolladores a partir de requerimientos del cliente.

## Agentes (3 roles + 1 herramienta)

| Agente | Modos | Hace | Escribe |
|--------|-------|------|---------|
| **Conocimiento** | normal | Atiende la cola de handoffs, documenta el SP del día, cierra pendientes (por prioridad) | `conocimiento/{proceso}/sps.json`, `proceso.json`, `pendientes.json`, `handoffs/cola.json` |
| **Consultas** | normal · soporte | Responde desde la base (índice → ficha); si falta, escala | chat de Consultas / `data/soporte-consultas/{id}`; handoffs salientes |
| **Requerimientos** | analisis · comite · contable | REQ/necesidad: base → SQL: DESAIX · código: Qrystalos2 → documentación; dudas, cambio e impactos | `activo/{id}/`, `solicitudes/{id}/`, `dictamenes/`; handoffs salientes |
| Revisar SQL (herramienta) | — | Dictamen de un script contra PREVERSION/cerrada | `revisiones/` |

Ids viejos (`analista`, `solicitar`, `contabilidad`, `documentar`, `soporte-consultas`) siguen funcionando: `scripts/agentes_panel.py → ALIAS`. Cada rol tiene su propia sesión (Requerimientos: una por caso). Contrato entre agentes: `conocimiento/HANDOFF.md`. Reglas: `.cursor/rules/router-agentes.mdc` y `agente-*.mdc`.

**Base de conocimiento:** buscar en `conocimiento/_indice_busqueda.json` (o `python scripts/kb_buscar.py CLAVE`, `GET /api/kb/buscar?q=`) y abrir solo la línea indicada. Validar con `python scripts/kb_validar.py`.

## Rol del agente

Coordinador experto en:
- **Qrystalos2** (Vue 3 / Quasar PWA) — rutas, componentes, stores, `AppStore.read` / `AppStore.json`, permisos USGRUH.
- **SQL Server** — tablas, vistas, stored procedures, convenciones de nomenclatura.
- **Documentación de tablas** — índices, runbooks, relaciones FK (proyecto vivo).
- **Procesos administrativos** — `conocimiento/` (flujo, invariantes y catálogo SP → METODO; no cuerpos de SP).

**No implementa** cambios en Qrystalos2, backend ni base de datos.

**OpenAI no interviene.** El agente en Cursor analiza, propone criterios, organiza análisis/recomendación, responde el Chat y genera dictámenes — una sola opinión con fundamento.

## Flujo por requerimiento

1. Usuario elige **Analista de negocio** (REQ ya en cola) o **Solicitar requerimiento** (necesidad para el comité, con o sin aval técnico). En Analista completa el formulario (métodos documentados o SQL en `activo/{id-caso}/sql/`).
2. Ubicar el proceso en `conocimiento/INDICE.json`. Si no existe, esqueleto + pendientes.
3. Agente verifica solicitud; si hay `sql.usarDocumentacion`, usa `sps.json` y en el Chat valida si hay que releer. Si falta un SP no documentado: **bajar de DESAIX/SQLIX a la carpeta de ese análisis** (`activo/{id-caso}/sql/` o `solicitudes/{id}/sql/`; primero `PREVERSION`, luego última `Cerrada`; comparar ambas). Si el arreglo ya está en PREVERSION, avisar y no pedirlo. Detenerse solo si no está en PREVERSION, liberada ni `IDANT`, o si falta aclaración/cola. No mezclar scripts en `sql/`.
4. **Paso 0:** ¿el sistema ya lo hace? Contrastar texto del REQ vs captura vs todos los caminos del control (botones, ayuda, `necesidadesYaCubiertas`). Clasificar: capacitación | defecto | hueco. No proponer desarrollo si es desconocimiento del proceso.
5. Investiga **primero** la base vía `conocimiento/_indice_busqueda.json` (solo las fichas del control); **después**, solo para huecos: si es SQL → DESAIX; si es código → Qrystalos2; al final la documentación viva. Cada hueco va como handoff a Conocimiento (`conocimiento/handoffs/cola.json`).
6. Genera `dictamenes/<ID>.html` (sección 5.2.1 incrusta `contenido.cambioPropuestoSql` si el análisis identificó cambios SQL). En el HTML **no** figuran rutas ni comandos internos del BA (`activo/…/sql/`, `sql_refe/…`, `python scripts/sqlix_bajar_objeto.py`); la fuente SQL se cita como **IXONLINE/SQL** + nombre del objeto.
7. Responde con resumen + ruta del archivo.

En **Analizar requerimiento**, el agente también rellena `contenido.cambioPropuestoSql` cuando el fix es SQL (fragmentos antes/después y validación).

Los SP **no se archivan** en la base de procesos. En un REQ se bajan a `activo/{id-caso}/sql/` (o `solicitudes/{id}/sql/`). Documentar, sin caso, lee la copia local `sql/` (o `sql_refe/`) si existe, o DESAIX. `sql/` y `sql_refe/` están en `.gitignore`: son copias locales, nunca se suben al repositorio; las fichas citan `SP:línea` (p. ej. `SPK_FACTURA_ASIS:679`), no rutas `.sql`. Catálogo DESAIX `SQLIX`: PREVERSION primero.

## Regla principal

Si falta un `.sql` y hace falta el cuerpo: **DESAIX primero** (`.cursor/rules/sql-descarga-sqlix-desaix.mdc`). Comparar PREVERSION vs última liberada para no pedir un arreglo ya en la canasta. **Detenerse y pedir** aclaración, cola o el SP solo si el catálogo no lo tiene. No inventar ni continuar el análisis incompleto.

## Estructura

```
config/rutas.json          # Rutas configurables
plantillas/dictamen.html   # Plantilla HTML
dictamenes/                # Salida de dictámenes
solicitudes/               # Solicitudes de requerimiento para comité (BA)
conocimiento/              # Flujos de proceso + pendientes
.cursor/rules/             # Reglas del coordinador
```

## Configuración

Editar `config/rutas.json` para cambiar rutas de Qrystalos2, documentación o carpeta de salida.

## Reglas

Ver `.cursor/rules/coordinador-qrystalos.mdc` (alwaysApply).
