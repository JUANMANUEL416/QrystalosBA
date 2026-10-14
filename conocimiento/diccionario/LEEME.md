# Catálogo de tablas

Sirve para ubicar una tabla, armar una consulta o un reporte, entregar un diccionario de datos y orientar a soporte. No forma parte del índice de procesos.

Los cuatro diccionarios Clarion (`Krystalos2024_04.dct`, `krys2_2024_04.dct`, `Krys3_2024_04.dct`, `KPresup2024_04.dct`) están en binario. El rótulo de pantalla y los campos salen de la declaración generada en los `.clw` de `C:\DEV11.1\KrystalosCol_2024.04`. El tipo SQL sale de `qrystalos.documentacion` (`tablas.rpt` y `columnas_por_tabla.rpt`).

| Archivo | Uso |
|---|---|
| `indice.json` | Una fila por objeto: nombre, descripción, `tipo` (`tabla` o `vista`), prefijo, diccionario, si está en SQL, si Clarion lo declara y si ya hay ficha larga |
| `campos.jsonl` | Una fila por campo: tabla, campo, rótulo de pantalla, tipo Clarion, tipo SQL |
| `diccionarios.json` | Qué aplicaciones usan cada diccionario |
| `resumen.json` | Conteos de la última generación |

`enClarion` y `enSql` juntos: el objeto está en el escritorio y en la base. Solo `enSql`: existe en la base y no salió en los `.clw` generados (el `.dct` puede tenerlo, pero no se puede leer en binario). El rótulo es el texto que ve el usuario en la pantalla Clarion.

Un nombre que empieza por `VWK` es una vista SQL (`tipo`: `vista`). Al leer un procedimiento, si aparece una tabla o vista que no está en `indice.json`, se agrega. Si algún proceso de `conocimiento/` ya la explica, esa frase queda como etiqueta. Si no, se pide la etiqueta y no se inventa. Esas filas llevan `origen`: `lectura-sp` y se conservan al regenerar.

Regenerar: `python scripts/clarion_diccionario.py`
