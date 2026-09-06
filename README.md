# Qrystalos BA — Oficina de coordinación Qrystalos

Proyecto de **coordinación técnica**. Recibe requerimientos del cliente, los analiza contra Qrystalos2 y la documentación del sistema, y genera **dictámenes HTML** para el equipo de desarrollo. **No implementa cambios** en la aplicación.

## Flujo de uso (con formulario GUI)

1. **Cola:** Guarde avalasesor en `cola/0100016198.html` → regístrelo en la app → **Abrir**.
2. **Formulario:** Complete análisis (puede **dictar** en paso 3).
3. **SQL:** Coloque scripts en **`sql/`** (carpeta fija) → confirme en paso 4.
4. **Revisión:** Copie prompt en Cursor. El agente lee cola + SQL del disco.
5. **Histórico / aprobados:** Tabla de seguimiento; dictamen aprobado en `aprobados/{id-caso}/`.
6. **Al cerrar caso:** **Archivar SQL** → scripts a `sql_refe/{ID-REQ}/`, carpeta `sql/` limpia.
7. Si el agente necesita **capturas**, las pide → guárdelas en `aprobados/{id-caso}/imagenes/`.

Abrir: **`abrir-app.bat`** → menú central (Analista / Consultas / Documentar) en http://localhost:8765/app/

- **Analista de negocio:** cola, casos, dictámenes.
- **Consultas:** proceso → capa → gate (p. ej. llamada de caja).
- **Documentar:** lista de pendientes, indicar el `.sql` de hoy, Chat de proceso. No se guarda el cuerpo del SP.

### Cola con lista ixonline (varios REQ)

1. Guarde la tabla aval técnico como `cola/aval-asesor-lista.htm`
2. En la app: **Examinar…** (si abre por file://) o **Registrar** (con servidor local)
3. Elija su **ID REQ** en el modal
4. Pulse **Abrir** → complete formulario y SQL

## Estructura del proyecto

```
QrystalosBA/
├── app/                    # GUI (menú central + analista)
├── conocimiento/           # Flujos de proceso (no cuerpos de SP)
├── cola/                   # HTML guardados de ixonline (Ctrl+S)
├── sql/                    # Scripts SQL — carpeta fija de trabajo (SP del día)
├── sql_refe/{ID-REQ}/      # SQL archivados al cerrar caso
├── historico/registro.json # Histórico exportable
├── aprobados/{id-caso}/    # Dictámenes aprobados + imagenes/
├── dictamenes/             # Salida HTML del agente
```

## Configuración de rutas

Editar [`config/rutas.json`](config/rutas.json):

| Campo | Descripción |
|-------|-------------|
| `qrystalos2` | Frontend Quasar/Vue 3 |
| `documentacion` | Diccionario de tablas (proyecto vivo) |
| `carpetaConocimiento` | Flujos de proceso (esta oficina) |
| `carpetaSql` | Scripts SQL por caso |
| `carpetaSolicitudes` | JSON del formulario |
| `appFormulario` | Ruta al formulario GUI |
| `salidaDictamenes` | HTML generados |

## SQL obligatorio antes del análisis

Ver [`sql/README.md`](sql/README.md). Sin scripts en `sql/<ID-CASO>/`, el agente debe **pedirlos y detenerse**.

Mínimo recomendado:
- SP principal del flujo
- Funciones `FNK_*` relacionadas
- Estructura de tablas involucradas
- Script de medición (si es performance)

## Regla del agente

> **Si falta algo, parar y pedirlo.** No asumir SPs, columnas ni comportamiento.

## Formato del dictamen HTML

Ver secciones en `plantillas/dictamen.html`: requerimiento, análisis, dictamen, cambios, pruebas (dev/coordinador/soporte), fuentes.

## Lo que este proyecto NO hace

- No implementa en Qrystalos2, backend ni BD.
- No ejecuta scripts SQL en servidores.
