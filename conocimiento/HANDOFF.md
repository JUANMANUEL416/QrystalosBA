# Contrato de handoff entre agentes

Los tres agentes (Conocimiento, Consultas, Requerimientos) se coordinan por **archivos en disco**, no compartiendo el mismo hilo de chat ni el mismo contexto largo.

## Quién puede llamar a quién

| De → Para | Permitido | Tipos típicos |
|-----------|-----------|---------------|
| Consultas → Conocimiento | Sí | `documentar_metodo`, `confirmar_hueco` |
| Requerimientos → Conocimiento | Sí | `documentar_metodo`, `pedir_sql`, `confirmar_hueco` |
| Conocimiento → Consultas | Sí (respuesta) | `respuesta_consulta` |
| Conocimiento → Requerimientos | Sí (respuesta) | `respuesta_consulta`, `impacto_req` (veredicto de ficha) |
| Consultas ↔ Requerimientos | No directo | Pasan por el coordinador humano o por Conocimiento |

## Cola

- Carpeta: `conocimiento/handoffs/`
- Índice: `conocimiento/handoffs/cola.json` (array)
- Detalle opcional: `conocimiento/handoffs/{id}.json` (mismo objeto)

## Schema

```json
{
  "id": "ho-20260905-001",
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
    "evidencia": "sps.json tiene estado listado; no hay ficha leido"
  },
  "estado": "pendiente",
  "respuesta": null,
  "creadoEn": "2026-09-05T20:00:00",
  "actualizadoEn": "2026-09-05T20:00:00"
}
```

### Campos

| Campo | Valores |
|-------|---------|
| `de` / `para` | `conocimiento` \| `consultas` \| `requerimientos` |
| `tipo` | `documentar_metodo` \| `confirmar_hueco` \| `respuesta_consulta` \| `impacto_req` \| `pedir_sql` |
| `prioridad` | `alta` \| `media` \| `baja` |
| `estado` | `pendiente` \| `en_progreso` \| `respondido` \| `bloqueado` |
| `respuesta` | texto/objeto con veredicto; `null` hasta cerrar |

## Ciclo de vida

1. Emisor crea el objeto, lo agrega a `cola.json`, estado `pendiente`.
2. Receptor lo toma → `en_progreso`.
3. Al terminar → `respondido` + `respuesta` (o `bloqueado` + motivo en `respuesta`).
4. Emisor, en su siguiente turno, lee la respuesta y cierra su pregunta/chat.

## Anti-cruce

- Cada agente **solo escribe** los chats y carpetas de su rol (ver reglas `.mdc`).
- Un handoff **no** copia el historial completo del chat: solo `contexto` mínimo.
- Conocimiento no abre `activo/`; Requerimientos no escribe `sps.json`; Consultas no dictamina.

## Flujos ejemplo

### 1) Consulta sin ficha
Usuario pregunta en Consultas → Consultas no encuentra `leido` → handoff `documentar_metodo` a Conocimiento → Conocimiento documenta o pide `.sql` → `respondido` → Consultas responde al usuario.

### 2) REQ con METODO parcial
Requerimientos compara cola vs `sps.json` → ve `parcial` → handoff `documentar_metodo` o `pedir_sql` → mientras, lista dudas de negocio al coordinador → con ficha `leido`, propone cambio + impactos → dictamen.

### 3) Documentar continuo
Conocimiento procesa `tarea.json` / pendientes / handoffs en cola; solo pregunta gaps; no atiende Chat de caso ni Consultas salvo vía handoff.
