# Bloques de Inventario Pendientes

## Bloques Creados (1 de ejemplo)

✅ **contabilizacion-entrada-compra** (orden 12)
- Contabilización de entrada de compra con OM INV
- SPK_NC_CONTAB_INV, KMCOM MOV_INVENTARIO
- Variables: CONTABIMOV_JOB, VALID_CCOSTO_CXP
- Escena agregada en capacitacion_escenas.py
- Icono: 📊

## Estructura de Bloques Pendientes

Basándose en `conocimiento/inventario/catalogo-movimientos-inventario.json` y `MOVIMIENTOS-INVENTARIO.md`, crear los siguientes bloques:

### A) Compras (después de entrada hasta CxP)

1. **generacion-cxp-automatica** (orden 13, prerreq: contabilizacion-entrada-compra)
   - SPK_INSERT_CXP_INV crea FCXPD desde IMOVH
   - KMCOM CXP_COMPRAS
   - Variables: CONTAB_INV_IVA_ITAR, REDONDEO_COMPRAS_CXP
   - Icono: 💳

2. **contabilizacion-cxp** (orden 14, prerreq: generacion-cxp-automatica)
   - Proceso hermano cxp-fcxp
   - CONTABILIZAR_FCXP en OM Comprobantes
   - Cruce con FRADIAN si aplica
   - Icono: 📑

3. **cufe-radian-compras** (orden 15, prerreq: entrada-de-almacen-y-confirmacion)
   - IMOV.CUFE, SINCRONIZAR_CUFE_RADIAN
   - Loteo con factura (INV_CUFE_LOTEO=SI)
   - Control imov-transito
   - Variables: INV_CUFE_LOTEO
   - Icono: 📄

### B) Salidas (despacho hasta contabilización)

4. **salida-manual-consumo** (orden 16, prerreq: tipos-de-movimiento-itmo)
   - CRUD_IMOV_SAL, CONFIRMA_SALIDA
   - SPK_CONFIRMARSALIDAS valida KMCOM antes
   - Icono: 📤

5. **salida-dispensacion-servicios** (orden 17, prerreq: salida-manual-consumo)
   - IZSOL PROCESAR → CONF_MOVIMIENTO
   - SPK_CONFIRMASAL_CM (no valida KMCOM previo)
   - Cruce IEXI lote vs IDXB
   - Icono: 💊

6. **contabilizacion-salidas** (orden 18, prerreq: salida-dispensacion-servicios)
   - SPK_NC_CONTAB_INV para salidas
   - CONTABIMOV_JOB o inmediato
   - Icono: 📊

7. **devolucion-interna** (orden 19, prerreq: salida-manual-consumo)
   - IDINVMOV_DEVOLUCION (entrada que revierte salida)
   - Efecto en IEXI
   - Icono: ↩️

8. **devolucion-proveedor** (orden 20, prerreq: entrada-de-almacen-y-confirmacion)
   - IDINVDEVPROVEEDOR (salida hacia proveedor)
   - Genera nota CxP (no MCP desde inventario)
   - SPK_NC_CONTAB_INV sale sin contabilizar
   - Icono: 🔙

9. **ajustes-inventario** (orden 21, prerreq: tipos-de-movimiento-itmo)
   - IDINVTFSA, IDINVSAL_MISMAENT
   - Corrección de diferencias de conteo
   - Variables: IDINVTFSA
   - Icono: ⚖️

### C) Tipos de Movimiento Especiales (1 bloque por tipo USVGS)

10. **tipo-mov-traslado-salida** (orden 22, prerreq: tipos-de-movimiento-itmo)
    - IDTS (salida origen)
    - ESTRANSITO=1
    - Variables: IDTS
    - Icono: 🚚

11. **tipo-mov-traslado-entrada** (orden 23, prerreq: tipo-mov-traslado-salida)
    - IDTE (entrada destino)
    - ON_ACEPTA_TRANSITO → SPK_INSERTENTTRANSITO
    - Variables: IDTE
    - Icono: 📥

12. **tipo-mov-compra** (orden 24, prerreq: tipos-de-movimiento-itmo)
    - IDINVMOV_COMPRAS (02)
    - TIPO=Crédito, COMPRAS=true
    - CxP automática
    - Variables: IDINVMOV_COMPRAS
    - Icono: 🛒

13. **tipo-mov-remision** (orden 25, prerreq: tipo-mov-compra)
    - IDINVMOV_REMISION_EN (22)
    - CxP según flujo
    - Variables: IDINVMOV_REMISION_EN
    - Icono: 📋

14. **tipo-mov-prestamo** (orden 26, prerreq: tipos-de-movimiento-itmo)
    - IDINVMOV_PRESTAMOS
    - IDTIPOSER=Presta en FCOM
    - Variables: IDINVMOV_PRESTAMOS
    - Icono: 🤝

15. **tipo-mov-si** (orden 27, prerreq: tipos-de-movimiento-itmo)
    - IDINVMOV_SI (entrada alterna)
    - Variables: IDINVMOV_SI
    - Icono: ➕

16. **tipo-mov-dispensacion** (orden 28, prerreq: salida-dispensacion-servicios)
    - IDINVMOV_DISPEN
    - Ligado a IZSOL
    - Variables: IDINVMOV_DISPEN
    - Icono: 💉

17. **tipo-mov-cirugia** (orden 29, prerreq: salida-manual-consumo)
    - INVE_CIRU_TIPO_MOV
    - Salida quirófano
    - Variables: INVE_CIRU_TIPO_MOV
    - Icono: 🏥

18. **tipo-mov-venta-retail** (orden 30, prerreq: tipos-de-movimiento-itmo)
    - IDINVMOV_VENTAS
    - GUARDA_VENTA (triple contabilidad: INV, FTR, caja)
    - Variables: IDINVMOV_VENTAS, CONTAB_GASTOVEN_UNI
    - Icono: 🛍️

19. **tipo-mov-venta-factura** (orden 31, prerreq: tipo-mov-venta-retail)
    - IDINVMOVVENTAFACTURA
    - Con CONTAB_GASTOVEN_UNI unifica costo en FACTURA
    - Variables: IDINVMOVVENTAFACTURA, CONTAB_GASTOVEN_UNI
    - Icono: 🧾

20. **tipo-mov-venta-particular** (orden 32, prerreq: tipo-mov-venta-retail)
    - IDINVENTA_PARTICULAR (VE)
    - Variables: IDINVENTA_PARTICULAR
    - Icono: 👤

21. **tipo-mov-devolucion-cliente** (orden 33, prerreq: tipo-mov-venta-retail)
    - IDTIPOMOVDEV_CLIENTE (entrada que revierte venta)
    - Variables: IDTIPOMOVDEV_CLIENTE
    - Icono: ↪️

22. **tipo-mov-traslado-af** (orden 34, prerreq: tipos-de-movimiento-itmo)
    - IDINVTRASLACTIVOS (traslado a activos fijos)
    - Variables: IDINVTRASLACTIVOS
    - Icono: 🏢

23. **tipo-mov-pickpack** (orden 35, prerreq: tipos-de-movimiento-itmo)
    - IDMOVPICKPACK (14,VC)
    - ESTADO_PICKPACK 1/3
    - Variables: IDMOVPICKPACK
    - Icono: 📦

24. **tipo-mov-traslado-lote** (orden 36, prerreq: tipo-mov-traslado-entrada)
    - IDINVTRASLOTESAL / IDINVTRASLOTEENT (24/25)
    - Variables: IDINVTRASLOTESAL, IDINVTRASLOTEENT
    - Icono: 🔄

25. **tipo-mov-devolucion-ce-cx** (orden 37, prerreq: salida-manual-consumo)
    - IDINVMOVDEVCX, IDINVMOVDEVCE, IDINVMOVDEVHTX
    - Par salida-entrada
    - Variables: IDINVMOVDEVCX, IDINVMOVDEVCE, IDINVMOVDEVHTX
    - Icono: 🔃

26. **tipo-mov-obsequios** (orden 38, prerreq: tipos-de-movimiento-itmo)
    - IDINVENTXOBSEQUIOS (entrada)
    - Variables: IDINVENTXOBSEQUIOS
    - Icono: 🎁

27. **tipo-mov-anulacion-salida** (orden 39, prerreq: salida-manual-consumo)
    - FAR_MOVANULASALIDA (entrada que revierte)
    - Variables: FAR_MOVANULASALIDA
    - Icono: ❌

## Formato Estándar por Bloque

### `bloque.json`
```json
{
  "id": "nombre-bloque",
  "titulo": "Título Descriptivo",
  "version": "1.0.0",
  "temas": ["inventario"],
  "procesos": ["inventario"],
  "orden": { "inventario": N },
  "prerrequisitos": ["bloque-previo"],
  "variantes": [],
  "duracionEstimada": "20min",
  "icono": "emoji",
  "fuente": {
    "proceso": "inventario",
    "capa": "compras / salidas / especiales",
    "sp": "SPK_*",
    "actualizado": "2026-10-21"
  },
  "palabrasClave": ["SP", "TABLA", "VARIABLE"],
  "estable": true,
  "generado": "2026-10-21T23:30:00"
}
```

### `contenido.md`

Seguir estructura de `contabilizacion-entrada-compra/contenido.md`:

1. **Título + emoji**
2. **Contexto**: Proceso, Capa
3. **Explicación**: Párrafo resumen del flujo
4. **Ideas principales**: 3-5 puntos clave con contexto de usuario (bullet points con negrita inicial)
5. **Campos decisivos y visibles**: Tabla con Campo | Ubicación | Qué controla
6. **Variables de configuración (USVGS)**: Tabla con Código | Descripción | Valor habitual | Efecto
7. **Usuario final**: Quién usa, cómo, cuándo
8. **Soporte y desarrollo**: SPs con Propósito, Métodos, Valida, Qué hace, Errores; Ejemplos reales (3)
9. **Pendiente validar**: Ítems con ⚠️ si hay huecos en la KB

### `capacitacion_escenas.py`

Agregar entrada en `ESCENAS_BLOQUES`:
```python
"nombre-bloque": (
    "Escena descriptiva de farmacia/hospital con personal de salud, "
    "medicamentos, dispositivos médicos. SIN códigos de tabla (ITAR, IART, etc.)."
),
```

## Fuentes KB

- `conocimiento/inventario/proceso.json`
- `conocimiento/inventario/MOVIMIENTOS-INVENTARIO.md`
- `conocimiento/inventario/catalogo-movimientos-inventario.json`
- `conocimiento/flujo-compras-inv-cxp-caja/*.md`
- `conocimiento/inventario/sps.json` (para SPs documentados)

## Temas.json

Todos los bloques van bajo tema `inventario`. Se puede agregar `subtemas` si se desea:

```json
{
  "id": "inventario",
  "subtemas": [
    { "id": "compras", "nombre": "Compras" },
    { "id": "salidas", "nombre": "Salidas" },
    { "id": "tipos-movimiento", "nombre": "Tipos de Movimiento" }
  ]
}
```

## Pendientes de Validación Generales

- ⚠️ SPK_CONFIRMARSALIDAS hardcodea IDMODELOCONTABLE='01' (ticket INV-TCK-01)
- ⚠️ Job IMOVC para contabilización diferida: SP del job no está en KB
- ⚠️ Validar cada familia de movimiento contra proceso.json → controles
- ⚠️ Traslados AF, Pick&Pack, devoluciones CE/Cx/HTX: validar flujo completo en KB

## Orden de Creación Sugerido

1. Compras (bloques 1-3): completar flujo hasta CxP contabilizada
2. Salidas básicas (bloques 4-6): consumo, dispensación, contabilización
3. Devoluciones y ajustes (bloques 7-9)
4. Tipos de movimiento por orden de uso: traslados → compras → dispensación → cirugía → ventas → resto

## Validación por Bloque

Para cada bloque creado:

1. Verificar que el SP existe en `conocimiento/inventario/sps.json` o `proceso.json`
2. Validar variables USVGS en `conocimiento/flujo-compras-inv-cxp-caja/USVGS-INVENTARIO.md`
3. Agregar escena en `scripts/capacitacion_escenas.py` sin códigos de tabla
4. Ejecutar `python3 test_capacitacion_prompts.py` para validar escena
5. Registrar orden coherente en `bloque.json`
