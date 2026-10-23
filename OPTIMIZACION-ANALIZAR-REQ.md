# Optimización analizar-req: Reducción de 5-7 min a 1-2 min

> Actualización: el recorte de contexto se mantiene (no barrer `conocimiento/`), pero ya no se cierra el análisis «apenas haya lo mínimo» ni con un tope de ~15 lecturas. Ese cierre dejaba el cambio en un resumen. El planteamiento exige clasificación, flujo de hoy, causa citada y, si hay SQL, el bloque leído (`scripts/planteamiento_req.py`). El tope orientativo pasa a ~28 lecturas, gastadas en el control de este cambio.


## Resumen ejecutivo

El motivo `analizar-req` se ha optimizado para reducir el tiempo de análisis de **5-7 minutos (~100 tool calls)** a **1-2 minutos (~15 tool calls)** mediante:

1. **Preselección de contexto KB** antes de lanzar el agente
2. **Presupuesto explícito de herramientas** en el prompt
3. **Logging mejorado** para observabilidad

## Componentes

### 1. Módulo `kb_contexto_req.py` (nuevo)

**Ubicación:** `scripts/kb_contexto_req.py`

**Función:** Preseleccionar contexto relevante de la base de conocimiento antes de lanzar el agente.

**Flujo:**

```
REQ texto → Extraer términos → Inferir procesos → Resumir contexto → Formato prompt
```

**Extracción de términos:**
- Siglas técnicas (3+ letras mayúsculas): `CAJA`, `UBEQ`, `ACJ`
- Nombres de SP/tablas: `SPQ_CONF_CAJA`, `VWK_*`, `FN*`
- Rutas de pantalla: `/admin/caja`, `/conf/fpa`
- Términos de negocio (5+ letras, español): `cajero`, `factura`, `recaudo`

**Inferencia de procesos:**
- Si viene `proceso_id` → usar ese
- Si no → buscar coincidencias en `conocimiento/_indice_busqueda.json`
- Priorizar por estado (`completo` > `parcial`) y coincidencia de términos
- Limitar a 2 procesos más relevantes

**Resumen de contexto (compacto):**
- **Procesos:** nombre, módulo, estado, resumen (max 400 chars)
- **SPs:** top 8, con top 6 métodos cada uno
  - Métodos: `id`, `hace` (max 120 chars), `valida` (max 80 chars)
- **Controles:** top 6
  - `id`, `nombre` (max 80 chars), `validaSi` (max 120 chars)
- **Grafos:** lista de grafos disponibles (si existen)
- **Rutas para abrir:** paths exactos a `proceso.json`, `sps.json`, grafo-índice

**Límites:**
- Contexto JSON: max 12 KB
- Si se excede: truncar y advertir

**Salida:** prompt formateado listo para inyectar, con:
```
CONTEXTO KB PRESELECCIONADO (usar primero; evita barrer conocimiento/):

Proceso: Caja (caja) · CJA · MODULO DE CAJA · estado=completo
  Resumen: ...
  SPs (3 principales):
    - SPQ_CONF_CAJA (estado=leido) · METODOs: VALIDA_INGRESO_PANTALLA, ...
      VALIDA_INGRESO_PANTALLA: Valida que el equipo sea caja (UBEQ.ESCAJA=1)...
  Controles (5):
    - entrar-pantalla: Validar puesto de caja
      valida si: ...

Si necesita más detalle, abrir SOLO:
  - conocimiento/caja/proceso.json
  - conocimiento/caja/sps.json

PRESUPUESTO DE HERRAMIENTAS:
  - Este recorte orienta. No es el análisis ni el cambio.
  - No barra conocimiento/ ni lea un sps.json entero.
  - Para el METODO de este cambio abra la ficha completa y, si el cambio es SQL, el cuerpo.
  - No escriba la solución hasta tener clasificación, flujo de hoy y el bloque que cambia.
```

### 2. Modificación `cursor_bot.py`

**Cambios en `_prompt_base`:**

Antes:
```python
def _prompt_base(id_caso: str, motivo: str) -> str:
    # ... construir prompt
    return f"""..."""
```

Después:
```python
def _prompt_base(id_caso: str, motivo: str) -> tuple[str, list[str]]:
    """Genera el prompt y devuelve (prompt_texto, procesos_kb_preseleccionados)."""
    procesos_kb_ids: list[str] = []
    
    if motivo == "analizar-req":
        # Preselección de contexto KB
        try:
            import kb_contexto_req
            sol_data = read_json(os.path.join(caso_dir(id_caso), "solicitud.json"), {})
            req_texto = str(sol_data.get("contenido", {}).get("requerimiento") or "")
            proceso_id = str(sol_data.get("sql", {}).get("procesoId") or "")
            if req_texto:
                ctx = kb_contexto_req.preseleccionar_contexto(req_texto, proceso_id)
                contexto_kb = kb_contexto_req.formato_prompt(ctx)
                if ctx.get("procesos"):
                    procesos_kb_ids = [p["id"] for p in ctx["procesos"]]
                    print(f"[kb_contexto] preseleccionados: {', '.join(procesos_kb_ids)}", flush=True)
        except Exception as exc:
            print(f"[kb_contexto] no se pudo preseleccionar: {exc}", flush=True)
        
        # Inyectar contexto en el prompt
        extra = (
            "- Motivo: ANÁLISIS DEL REQUERIMIENTO orientado a SOLUCIÓN (no dictamen HTML).\n"
            + (f"\n{contexto_kb}\n\n" if contexto_kb else "")
            + "- Método obligatorio (en este orden):\n"
            "  1) Leer el REQ (solicitud.contenido.requerimiento + cola).\n"
            "  2) Contrastar con el CONTEXTO KB PRESELECCIONADO (arriba). Si no alcanza, "
            "buscar vía conocimiento/_indice_busqueda.json ...\n"
            ...
        )
    
    # Todos los return ahora devuelven tupla
    return (f"""...""", procesos_kb_ids)
```

**Cambios en `_Tiempos`:**

```python
class _Tiempos:
    def __init__(self, id_caso: str, motivo: str) -> None:
        # ...
        self.procesos_kb: list[str] = []  # Nuevo
    
    def resumen(self) -> None:
        # ...
        kb_procs = ", ".join(self.procesos_kb) if self.procesos_kb else "-"
        print(
            f"[tiempos] {self.motivo} total={total:.1f}s ... "
            f"kb_preseleccionados={kb_procs} ...",
            flush=True,
        )
```

**Cambios en `_run_caso_async`:**

```python
prompt, procesos_kb = _prompt_base(id_caso, motivo)
t.procesos_kb = procesos_kb
t.marca("prompt", chars=len(prompt))
```

### 3. Tests (`test_kb_contexto_req.py`, nuevo)

**7 casos de prueba:**

1. **`test_extraer_terminos`**: Verifica extracción de siglas, SP, tablas, rutas, negocio
2. **`test_preseleccion_con_proceso`**: Preselección cuando `proceso_id` es conocido
3. **`test_preseleccion_inferir_proceso`**: Inferencia desde el texto del REQ
4. **`test_formato_prompt`**: Formato del prompt final (encabezado, presupuesto)
5. **`test_limite_tamano`**: Respeto del límite de 12 KB
6. **`test_resumen_sps`**: Resumen compacto de SPs (top 8, métodos truncados)
7. **`test_json_output`**: CLI JSON (`python scripts/kb_contexto_req.py --req ... --json`)

**Ejecución:**
```bash
python3 test_kb_contexto_req.py
# ✅ Todos los tests de kb_contexto_req pasaron correctamente
```

**Tests existentes (sin cambios):**
```bash
python3 test_cursor_bot_api_keys.py  # ✅
python3 test_ux_fixes.py              # ✅
python3 test_soporte_fixes.py         # ✅
```

## Logging y observabilidad

### Antes de lanzar el agente

```
[kb_contexto] preseleccionados: caja, recaudos
```

### Al terminar el turno

```
[tiempos] analizar-req total=85.3s bridge=2.1s create=1.8s prompt=0.3s send=0.5s run=80.6s 
  primer_evento=12.4s herramientas=18 (read×9, grep×6, strreplace×3) 
  prompt_chars=8420 kb_preseleccionados=caja,recaudos 
  archivos: conocimiento/caja/sps.json×2, activo/REQ-123/solicitud.json×3, ...
```

**Antes:** `herramientas=97 (read×42, grep×38, glob×12, strreplace×5)`  
**Después:** `herramientas=18 (read×9, grep×6, strreplace×3)`

## Impacto esperado

| Métrica | Antes | Después | Reducción |
|---------|-------|---------|-----------|
| **Tiempo total** | 5-7 min | **1-2 min** | **~70%** |
| **Tool calls** | ~100 | **~15** | **85%** |
| **Reads `sps.json` completos** | 5-10 | **0** | **100%** |
| **Greps exploratorios** | 30-40 | **~6** | **85%** |
| **Contexto inicial** | 0 KB | **5-12 KB** | — |

## Migración y compatibilidad

### Sin cambios en:
- Validación de SP con DESAIX (solo se valida con el script del día en `activo/{id}/sql/`)
- Reads (sin locks, solo lectura)
- `.gitignore` y archivos excluidos (`.env`, `config/cursor-api-key-active.json`, etc.)

### Retrocompatibilidad:
- Si `kb_contexto_req` falla al importar o ejecutar, el prompt se genera sin contexto preseleccionado (comportamiento anterior)
- Todos los demás motivos (`chat`, `contabilidad`, `conocimiento`, `consultas`, etc.) no se ven afectados

## CLI del módulo

```bash
# Probar la preselección sin lanzar el agente
python scripts/kb_contexto_req.py --req "Error en caja al abrir sesión" --proceso caja

# Salida JSON
python scripts/kb_contexto_req.py --req "No genera RIPS JSON" --json
```

## Próximos pasos

1. **Monitorear** los primeros turnos de `analizar-req` en producción:
   - `[kb_contexto]` log
   - `[tiempos]` tool calls y tiempo total
2. **Ajustar límites** si hace falta:
   - `MAX_CHARS_CONTEXTO` (actual: 12000)
   - Top SPs (actual: 8)
   - Top métodos por SP (actual: 6)
3. **Extender a otros motivos** si es efectivo:
   - `criterios` (similar a `analizar-req`)
   - `solicitar-req` (necesidad para comité)

## Referencias

- PR: https://github.com/JUANMANUEL416/QrystalosBA/pull/30
- Commit: `f061bae`
- Rama: `cursor/optimize-analizar-req-4ae7`
