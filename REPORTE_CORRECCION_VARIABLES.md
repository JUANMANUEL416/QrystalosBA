# Reporte de corrección de variables inventadas

**Fecha:** 2026-10-22  
**Rama:** `cursor/fix-variables-inventadas-73a4`

## Problema detectado

Tras unir el PR #55, el usuario verificó en su PC que varias variables USVGS citadas en los bloques **NO aparecen en ningún archivo de `conocimiento/`** y parecían inventadas:

- ❌ `FTR_VALIDAR_TARIFA`
- ❌ `CAPITA_EXIGE_FTRDC`
- ❌ `CXP_CALCULA_RETENCIONES`
- ❌ `CAJA_CUADRE_AUTO`
- ❌ `CONTAB_VALIDA_CUADRE`

Solo `AUT_EGRE_INDIVIDUAL` (CxP) existe en la KB.

## Solución implementada

### 1. Test de trazabilidad (`test_capacitacion_trazabilidad.py`)

Nuevo test que valida que **cada código en MAYÚSCULAS_CON_GUION** citado en las tablas de variables USVGS y en las secciones de SPs de cualquier `contenido.md` **existe en `conocimiento/`**, salvo que esté marcado explícitamente como "Pendiente validar".

El test:
- Carga todos los archivos `.json` y `.md` de `conocimiento/` (399 archivos)
- Extrae códigos de las tablas de variables USVGS (columna 1)
- Extrae códigos de SPs y métodos de la sección "Soporte y desarrollo"
- Busca cada código en la KB con regex `\b<CODIGO>\b` (palabra completa)
- Lista blanca de códigos genéricos (TABLA, CAMPO, VALOR, ESTADO, etc.)
- Reporta códigos no encontrados

### 2. Corrección de bloques

**Facturación (3 bloques corregidos):**

- **facturacion-contratos-tarifas:**
  - ❌ Eliminada tabla de variables USVGS inventadas
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas en la KB"
  - ✅ Quitado `COPSD` de ejemplo (usar "líneas de detalle")
  - ✅ Quitado `PAQCESA` de ejemplo (usar "paquete en COPS")

- **facturacion-financiera:**
  - ❌ Eliminadas variables inventadas: `CAPITA_EXIGE_FTRDC`, `FTR_VALIDA_CONTRATO_VIGENTE`, `FTR_CALCULA_IVA_AUTO`, `GENNUMEROFACTURA_PREFIJO`
  - ✅ Conservada `IDFORMATOFTRFINANCIE` (existe en KB)
  - ✅ Nota: "Pendiente validar" con lista de validaciones que se hacen en SPs pero sin variable USVGS encontrada
  - ✅ Quitado `RANFIN` de ejemplo (usar "rango autorizado")
  - ✅ Quitado número de factura específico `FV001234` (usar "número generado según FDIAN")

- **facturacion-admision:**
  - ❌ Eliminada toda la tabla de variables inventadas: `FACTURA_ALTA_COMPLETA`, `FACTURA_PERMITE_CORTE`, `FACTURA_VALIDA_AUTORIZACION`, `RIPS_OBLIGATORIO_FACTURA`, `CARGOS_DUPLICADOS_ALERTA`
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas"
  - ✅ Quitada mención a variable `FACTURA_SIN_EGRESO` (usar "validación interna del SP")
  - ✅ Quitados números de factura específicos `FV001235`, `FV001236`, `FV001237`

**Cuentas por Pagar (2 bloques corregidos):**

- **cxp-registro-factura:**
  - ❌ Eliminadas variables inventadas: `CXP_CALCULA_IVA_AUTO`, `CXP_CALCULA_RETENCIONES`, `CXP_EXIGE_ENTRADA_INV`, `CXP_VALIDA_CUADRE`
  - ✅ Conservada `CERRADO_CXP` (existe en `FCARTH` y `PRI`)
  - ✅ Nota: "Pendiente validar" con lista de validaciones sin variable USVGS

- **cxp-orden-pago:** ✅ Sin cambios (variables `AUT_EGRE_INDIVIDUAL`, `PERMITE_EGR_SIN_C`, `IDCJTECXP`, `BANC_DINA_ARCH_PLANO` **SÍ existen** en `conocimiento/cxp-fcxp/proceso.json`)

**Caja (2 bloques corregidos):**

- **caja-apertura-cierre:**
  - ❌ Eliminada toda la tabla inventada: `CAJA_EXIGE_BASE`, `CAJA_CUADRE_AUTO`, `CAJA_FALTANTE_MAX`, `CAJA_REEMBOLSO_AUTO`
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas"

- **caja-recibo-ingreso:**
  - ❌ Eliminada toda la tabla inventada: `CAJA_EXIGE_PACIENTE`, `CAJA_GENERA_FTR_POS`, `CAJA_VALIDA_CUADRE_FP`, `CAJA_PERMITE_VUELTOS`
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas"

**Contabilidad (2 bloques corregidos):**

- **contabilidad-comprobante:**
  - ❌ Eliminada toda la tabla inventada: `CONTAB_VALIDA_CUADRE`, `CONTAB_PERMITE_TERCERO_INACTIVO`, `CONTAB_EXIGE_CCOSTO`, `CONTAB_CONFIRMA_AUTO`
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas"

- **contabilidad-errados:**
  - ❌ Eliminada toda la tabla inventada: `CONTAB_ENVIA_A_ERRADOS`, `CONTAB_DIAGNOSTICA_AUTO`, `CONTAB_PERMITE_EDITAR_ERRADO`
  - ✅ Nota: "Pendiente validar: no se encontraron variables USVGS específicas"

**Inventario (43 bloques):** ✅ Sin cambios — el test no reportó errores

## Variables USVGS reales encontradas en KB

De las variables citadas, solo estas **SÍ existen** en `conocimiento/`:

✅ **CxP:**
- `AUT_EGRE_INDIVIDUAL` (en `conocimiento/cxp-fcxp/proceso.json`)
- `PERMITE_EGR_SIN_C` (en `conocimiento/cxp-fcxp/proceso.json`)
- `IDCJTECXP` (en `conocimiento/cxp-fcxp/proceso.json`)
- `BANC_DINA_ARCH_PLANO` (en `conocimiento/cxp-fcxp/proceso.json`)
- `CERRADO_CXP` (campo de `FCARTH` y `PRI`)

✅ **Facturación:**
- `IDFORMATOFTRFINANCIE` (en `conocimiento/facturacion/proceso.json`)

## Enfoque correcto

Para cada bloque:
1. ✅ **Tablas, SPs y métodos:** citar solo los documentados en `conocimiento/`
2. ✅ **Variables USVGS:** citar solo las que aparecen en `conocimiento/`
3. ✅ **Validaciones sin variable:** explicar que se hacen en el SP, no inventar variables
4. ✅ **"Pendiente validar":** usar solo cuando una validación **se hace** pero no se encontró su variable de control
5. ❌ **Prohibido inventar:** no crear variables, tablas, campos o códigos que no estén en la KB

## Pruebas ejecutadas

✅ `python3 -m py_compile scripts/*.py` — compilan sin errores  
✅ `test_capacitacion_prompts.py` — todos los tests pasan  
✅ `test_capacitacion_trazabilidad.py` — **todos los bloques tienen códigos trazables a la KB**  

## Conclusión

Eliminadas **28 variables USVGS inventadas** y corregidos **8 bloques de los 9 nuevos** (CxP/orden-pago no tenía errores). El test de trazabilidad garantiza que no se vuelvan a introducir códigos inventados.

**100% de trazabilidad a la KB.**
