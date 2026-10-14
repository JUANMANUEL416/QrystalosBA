# Contrato de handoff entre agentes

Tres agentes — **Conocimiento**, **Consultas** y **Requerimientos** — se coordinan por **archivos en disco**. Cada uno tiene su propia sesión (no comparten hilo ni contexto largo).

## Orden de fuentes (todos los agentes)

1. **Base de conocimiento** vía índice: `conocimiento/_indice_busqueda.json` → abrir SOLO la `linea`/`ruta` indicada en el `archivo`. Nunca leer un `sps.json` entero.
2. **Qrystalos2** (código vivo, ruta en `config/rutas.json`) — solo Requerimientos, solo para huecos.
3. **qrystalos.documentacion** — solo Requerimientos, solo para huecos.
4. **DESAIX/SQLIX** — bajar el `.sql` a la carpeta del caso si la ficha no alcanza.
5. Si algo falta en la base: **handoff a Conocimiento** (no se rellena con suposiciones).

## Quién puede llamar a quién

| De → Para | Permitido | Tipos típicos |
|-----------|-----------|---------------|
| Consultas → Conocimiento | Sí | `documentar_metodo`, `confirmar_hueco` |
| Requerimientos → Conocimiento | Sí | `documentar_metodo`, `pedir_sql`, `confirmar_hueco` |
| Conocimiento → Consultas | Sí (respuesta) | `respuesta_consulta` |
| Conocimiento → Requerimientos | Sí (respuesta) | `respuesta_consulta`, `impacto_req` |
| Consultas ↔ Requerimientos | No directo | Pasan por el coordinador o por Conocimiento |

## Cola

- `conocimiento/handoffs/cola.json` (lista). Plantilla: `conocimiento/handoffs/_plantilla.json`.
- Código: `scripts/kb_handoff.py`. El servidor pega en cada prompt los handoffs que le tocan a ese agente.
- Esquema: `conocimiento/_schema/handoff.schema.json`.

```json
{
  "id": "ho-20261014-001",
  "de": "consultas",
  "para": "conocimiento",
  "tipo": "documentar_metodo",
  "prioridad": "alta",
  "contexto": {
    "proceso": "caja",
    "sp": "SPQ_CONF_CAJA",
    "metodo": "CONFIRMAR",
    "idCaso": null,
    "pregunta": "¿Qué valida CONFIRMAR sobre FCJD.CONCEPTO?",
    "evidencia": "Índice: SPQ_CONF_CAJA/CONFIRMAR estado listado"
  },
  "estado": "pendiente",
  "respuesta": null,
  "creadoEn": "2026-10-14T08:00:00",
  "actualizadoEn": "2026-10-14T08:00:00"
}
```

| Campo | Valores |
|-------|---------|
| `de` / `para` | `conocimiento` \| `consultas` \| `requerimientos` |
| `tipo` | `documentar_metodo` \| `confirmar_hueco` \| `respuesta_consulta` \| `impacto_req` \| `pedir_sql` |
| `prioridad` | `alta` \| `media` \| `baja` (3 pedidos iguales suben a `alta`) |
| `estado` | `pendiente` → `en_progreso` → `respondido` \| `bloqueado` → `cerrado` |

## Ciclo de vida

1. El emisor agrega el objeto (`pendiente`). Si ya hay uno abierto sobre el mismo SP/METODO, suma `vecesPedido` en vez de duplicar.
2. Conocimiento lo toma (`en_progreso`) **antes** que tarea/pendientes.
3. Al terminar: `respondido` + `respuesta` (o `bloqueado` + motivo). Actualiza la ficha y el índice se regenera solo.
4. El emisor, en su siguiente turno, usa la respuesta y pone `cerrado`.

## Anti-cruce

- Cada agente escribe solo lo de su rol (ver `.cursor/rules/agente-*.mdc`).
- Un handoff lleva solo `contexto` mínimo, nunca el historial del chat.
- Conocimiento no abre `activo/`; Requerimientos y Consultas no escriben `sps.json`; Consultas no dictamina.
