# Base de datos Qrystalos BA

Archivo: **`qrystalos_ba.db`** (SQLite)

## Tablas

| Tabla | Contenido |
|-------|-----------|
| `casos` | Solicitud + estado de cada caso activo |
| `chat_mensajes` | Mensajes del chat (coordinador / agente / sistema) |
| `historico` | Índice de dictámenes y estados |
| `cola_items` | Cola de trabajo (REQ avalasesor) |
| `borradores` | Borrador del formulario |

## Compatibilidad con el agente

La BD es la **fuente principal**, pero se mantiene sincronizado:

- `activo/{id-caso}/solicitud.json`
- `activo/{id-caso}/estado.json`
- `activo/{id-caso}/chat.json`

El agente en Cursor sigue leyendo esos archivos del disco.

## Migración

Al arrancar `servir-app.bat`, se importan automáticamente los JSON existentes en `activo/` e `historico/registro.json`.
