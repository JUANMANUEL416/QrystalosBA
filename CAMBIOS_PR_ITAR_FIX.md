# PR: Fix ITAR/Armas en Ilustraciones

## Problema

**Bug grave**: La ilustración de "Tipos de artículo (ITAR)" generaba imágenes de **armas** (fusiles, munición, cascos, cohetes).

**Causa raíz**: El acrónimo "ITAR" significa *International Traffic in Arms Regulations* en inglés. Los modelos de IA (Gemini/OpenAI) interpretan "ITAR" en los prompts como regulación de armamento militar, no como una tabla de base de datos de hospital.

## Solución Implementada

### 1. Escenas por Bloque (`scripts/capacitacion_escenas.py`)

**Nuevo archivo** con mapa `bloque_id → escena_salud`:

- **Eliminan códigos técnicos** (`ITAR`, `IART`, `SER`, `IDXB`, `IBOD`, `ITBOD`, `ITMO`, `USVGS`, etc.)
- **Describen escenas explícitas de salud** en contexto hospitalario/farmacéutico
- Ejemplo para `tipos-de-articulo-itar`:
  > "Estantería de farmacia hospitalaria con secciones claramente separadas para medicamentos, dispositivos médicos, material médico-quirúrgico, reactivos de laboratorio y productos de nutrición. Regente de farmacia clasificando productos según su categoría."

**15 bloques** con escenas específicas definidas.

### 2. Validación de Prompts (`capacitacion_escenas.py`)

Función `validar_prompt_sin_codigos(prompt)`:

- **Detecta códigos prohibidos**: `ITAR`, `IART`, `SER`, `SPQ_`, etc.
- **Detecta palabras de armas**: `weapon`, `rifle`, `ammunition`, `military`, `arma`, `fusil`, `munición`, etc.
- **Excluye falsos positivos**: `pharmacy`/`farmacia` contienen "arma" pero son válidas
- **Busca palabras completas** con regex `\b...\b`

### 3. Versionado de Caché con Hash (`capacitacion_visuales.py`)

Nueva lógica de caché:

1. **Genera hash MD5** del prompt (primeros 16 chars)
2. **Guarda metadata** en `ilustracion.meta.json`:
   ```json
   {
     "prompt_hash": "a1b2c3d4e5f6g7h8",
     "prompt": "Professional clean illustration...",
     "timestamp": "2026-10-21T20:35:00"
   }
   ```
3. **Verifica validez**: compara hash actual vs hash guardado
4. **Invalida cache** si el prompt cambió → regenera imagen

**Sin metadata o hash diferente** → cache inválido, regenerar.

### 4. Prompts Limpios sin Códigos

Modificaciones en `generar_ilustracion_completa()`:

- **Acepta `bloque_id`** como parámetro
- **Obtiene escena** de `capacitacion_escenas.py` si está disponible
- **Construye prompt base**:
  ```
  Professional clean illustration for hospital pharmacy warehouse inventory.
  Scene: {escena_visual}.
  Style: clean, professional, soft hospital colors.
  STRICTLY NO text, flags, languages, weapons, ammunition, military items.
  ONLY medical/healthcare inventory items and healthcare staff.
  ```
- **Valida prompt** antes de enviar a Gemini/OpenAI
- **Guarda metadata** al cachear

### 5. Integración en Ensamblador

`capacitacion_ensamblar.py` ahora pasa `bloque_id` al generar ilustraciones:

```python
data_uri = visuales.generar_ilustracion_completa(
    titulo=titulo,
    descripcion=descripcion,
    cache_path=ilustracion_path,
    bloque_id=bloque_id  # ← NUEVO
)
```

### 6. Tests Automatizados (`test_capacitacion_prompts.py`)

**Nuevo archivo de tests** con 3 validaciones:

1. **Test 1**: Verifica que todas las escenas NO contengan códigos prohibidos
2. **Test 2**: Verifica que el validador detecte códigos y palabras de armas
3. **Test 3**: Simula prompts generados y valida que sean limpios

**Resultado**: ✅ Todos los tests pasan (15 bloques validados)

## Archivos Modificados

| Archivo | Cambio |
|---------|--------|
| `scripts/capacitacion_escenas.py` | **NUEVO** - Mapa de escenas + validador |
| `scripts/capacitacion_visuales.py` | Prompts limpios + cache con hash + validación |
| `scripts/capacitacion_ensamblar.py` | Pasa `bloque_id` al generar ilustraciones |
| `test_capacitacion_prompts.py` | **NUEVO** - Tests de validación de prompts |

## Verificación

```bash
# Sintaxis
python3 -m py_compile scripts/capacitacion_*.py
python3 -m py_compile test_capacitacion_*.py

# Tests
python3 test_capacitacion_prompts.py
# ✅ Todos los tests de prompts pasaron
```

## Impacto

- **Ilustraciones existentes**: Cache invalidado automáticamente por cambio de prompt → se regenerarán
- **Nuevas ilustraciones**: Usan escenas limpias sin códigos → NO generan armas
- **Performance**: Cache con metadata evita regeneraciones innecesarias
- **Mantenibilidad**: Validación automática detecta prompts problemáticos antes de generar

## Notas

- El usuario ya borró la caché de ITAR en su PC
- Las ilustraciones se regenerarán automáticamente con los nuevos prompts limpios
- La metadata de caché asegura que no se reutilicen imágenes viejas con prompts problemáticos
