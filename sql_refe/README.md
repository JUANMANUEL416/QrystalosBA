# SQL de referencia — casos cerrados

Cuando el dictamen está **aprobado** y el trabajo terminó, los scripts se archivan aquí.

## Estructura

```
sql_refe/
  0100016193/          ← número de requerimiento (ID REQ ixonline)
    SPK_xxx.sql
    FNK_xxx.sql
    archivo.json       ← metadatos del archivado (automático)
  0100016198/
    ...
```

## Flujo

1. Durante el análisis: scripts en **`sql/`** (carpeta fija, un caso a la vez).
2. Al **cerrar fase 1** el sistema mueve los `.sql` a **`sql_refe/{ID-REQ}/`** y deja **`sql/`** limpia.
3. También se copia el dictamen a **`aprobados/{id-caso}/`**.

Requiere **`servir-app.bat`** en ejecución.

## Recuperar scripts

Los archivos oficiales del caso aprobado están en esta carpeta y en `aprobados/{id-caso}/` (dictamen HTML).
