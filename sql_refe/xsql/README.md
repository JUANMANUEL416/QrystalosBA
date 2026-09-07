# Carpeta SQL — Trabajo (siempre la misma)

**Ruta fija:** `C:\DevQuasar\Qrystalos\QrystalosBA\sql\`

Un solo caso a la vez. Coloque aquí los `.sql` del requerimiento en curso.

## Ejemplo

```
sql/
  SPK_AFACTURAR.sql
  SPK_AFACTURAR_CORTE.sql
  SPK_ESTADO_ADMI.sql
```

## Regla

Sin archivos en `sql/` → el agente **se detiene y pide** los que falten.

## Al cerrar el caso

1. Al **cerrar fase 1** (o el botón Archivar SQL) se mueven a **`sql_refe/{ID-REQ}/`**.
2. **`sql/`** queda limpia para el siguiente caso.
3. **`sql/`** queda **limpia** para el siguiente trabajo.

Ver [`sql_refe/README.md`](../sql_refe/README.md).
