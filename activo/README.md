# Casos activos — el agente lee aquí (no pegar prompt)

Cuando pulse **Activar análisis (Fase 1)** en la app, se crea:

```
activo/{id-caso}/
  solicitud.json      ← formulario completo
  chat.json           ← conversación con el coordinador
  estado.json         ← fase 1 / fase 2 / cerrado
  INSTRUCCION-AGENTE.md
```

## Flujo

1. Coordinador completa formulario → **Activar análisis (Fase 1)**.
2. Agente Cursor lee `INSTRUCCION-AGENTE.md` + `solicitud.json` + `cola/` + `sql/`.
3. Agente genera propuesta → `dictamenes/{id-caso}.html`.
4. Coordinador escribe en **Chat** de la app lo que piensa.
5. Agente relee `chat.json` y ajusta.
6. **Cerrar fase 1** → caso listo para desarrollo / archivar SQL.
