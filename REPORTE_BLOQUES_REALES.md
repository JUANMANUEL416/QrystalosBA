# Reporte de bloques de capacitación con datos reales

**Fecha:** 2026-10-22  
**Rama:** `cursor/bloques-modulos-reales-73a4`

## Resumen ejecutivo

**Bloques eliminados:** 40 bloques genéricos (con plantillas ESTADO/PERIODO/USUARIO/FECHA y variables "Pendiente validar")

**Bloques creados:** 9 bloques con datos reales de la KB de conocimiento

**Módulos trabajados:** Facturación (3), Cuentas por Pagar (2), Caja (2), Contabilidad (2)

**Enfoque:** Calidad sobre cantidad. Cada bloque tiene tablas reales, SPs documentados, métodos, validaciones, variables USVGS concretas y ejemplos del sector salud.

## Bloques creados por módulo

### Facturación (3 bloques)

1. **facturacion-contratos-tarifas**
   - Tablas: `TARC`, `CPRE`, `COPS`, `PPT`, `TTEC`
   - SPs: `SPQ_TARC_COL`, `SPQ_PPT_COL`, `SPQ_CPRE_COL`, `SPQ_COPS_COL`, `SPK_BUSCAR_TARIFA`
   - Variables: `FTR_VALIDAR_TARIFA`, `FTR_MANUAL_TARIFARIO`, `FTR_CONTRATO_OBLIGATORIO`, `CAPITA_EXIGE_FTRDC`
   - Contenido: Contratos con EPS, planes de salud (evento, cápita, PGP), tarifas específicas y paquetes, manuales tarifarios SOAT/ISS
   - Ejemplos: Contrato con Compensar EPS, cápita con Salud Total ARS, manual tarifario SOAT

2. **facturacion-financiera**
   - Tablas: `FTR`, `FTRD`, `FTRDC`
   - SPs: `SPQ_FTR_COL` (métodos `CREARFTR`, `CRUDFTRD`, `DELETEFTRD`, `ADDFTRDC`), `SPK_TOTALFACTURFIN`, `SPK_GENNUMEROFACTURA`, `SPK_ADDSERCAP`, `SPK_DELSERCAP`
   - Variables: `IDFORMATOFTRFINANCIE`, `CAPITA_EXIGE_FTRDC`, `FTR_VALIDA_CONTRATO_VIGENTE`, `FTR_CALCULA_IVA_AUTO`, `GENNUMEROFACTURA_PREFIJO`
   - Contenido: Nueva Factura (PROCEDENCIA=FINANCIERO), modalidades evento/cápita/PGP, líneas FTRD, relación FTRDC, numeración DIAN, validaciones
   - Ejemplos: Factura por evento (consulta general), factura cápita Periodo, factura PGP hospital universitario

3. **facturacion-admision**
   - Tablas: `HADM`, `HPRE`, `HPRED`, `FTR`, `FTRD`, `FTRDC`
   - SPs: `SPQ_FTR_HADM_COL` (método `FACTURA_ADMI`), `SPK_FACTURA_ASIS`, `SPK_FACTURA_ASIS_CORTE`, `SPK_RIPS_JSON_FTR`
   - Variables: `FACTURA_ALTA_COMPLETA`, `FACTURA_PERMITE_CORTE`, `FACTURA_VALIDA_AUTORIZACION`, `RIPS_OBLIGATORIO_FACTURA`, `CARGOS_DUPLICADOS_ALERTA`
   - Contenido: Factura desde admisión (urgencias, hospitalización, domiciliaria), cargos HPRE/HPRED, alta completa vs corte, RIPS JSON, PROCEDENCIA=SALUD
   - Ejemplos: Factura de urgencias (trauma accidente), factura de hospitalización con corte, rechazo por cargo no autorizado

### Cuentas por Pagar (2 bloques)

4. **cxp-registro-factura**
   - Tablas: `FCXP`, `FCXPD`, `FCXPI`, `TER`, `MCP`, `MCPE`
   - SPs: `SPQ_FCXP` (métodos `CRUD_FCXP`, `CRUD_FCXPD`, `CRUD_FCXPI`, `CONTABILIZAR_FCXP`), `SPK_NC_CONTAB_CXP`, `SPK_CALCULOVALORESCXP`
   - Variables: `CXP_CALCULA_IVA_AUTO`, `CXP_CALCULA_RETENCIONES`, `CXP_EXIGE_ENTRADA_INV`, `CXP_VALIDA_CUADRE`, `CERRADO_CXP`
   - Contenido: Registro de factura de proveedor, detalle FCXPD, impuestos FCXPI, validación de cuadre, contabilización, control de saldo, periodo CxP
   - Ejemplos: Compra de medicamentos (Laboratorios ABC), servicios públicos (energía eléctrica)

5. **cxp-orden-pago**
   - Tablas: `FCXPP`, `FCXPPM`, `FCJ`, `PCJ`, `BCT`
   - SPs: `SPQ_ORDEN_PAGO` (métodos `CRUD_FCXPPM`, `AUTORIZAR`), `SPQ_CONF_CAJA` (método `CONFIRMAR_RECIBO_EGRESO`), `SPK_CONFIRMAR_PAGOSMASIVO`, `SPK_NC_CONTAB_CAJA_EGR`, `SPK_MARCA_OP_PAGADA_POR_EGRESO`
   - Variables: `AUT_EGRE_INDIVIDUAL`, `PERMITE_EGR_SIN_C`, `IDCJTECXP`, `BANC_DINA_ARCH_PLANO`
   - Contenido: Orden de pago, autorización (masiva, individual por tercero, individual por abono), egreso pendiente FCJ, confirmación en caja con forma de pago, actualización saldo CxP
   - Ejemplos: Orden de pago a un proveedor (transferencia), abono parcial

### Caja (2 bloques)

6. **caja-apertura-cierre**
   - Tablas: `ACJ`, `ACJD`, `CAJ`, `CJR`, `TUR`
   - SPs: `SPQ_CONF_CAJA` (método `APERTURA_CAJA`), `SPQ_CONF_CAJA_2` (métodos `CIERRE_CAJA`, `CUADRE_CAJA`)
   - Variables: `CAJA_EXIGE_BASE`, `CAJA_CUADRE_AUTO`, `CAJA_FALTANTE_MAX`, `CAJA_REEMBOLSO_AUTO`
   - Contenido: Apertura de sesión con base inicial, registro de ingresos/egresos, cierre con cuadre (efectivo esperado vs real), diferencia (sobrante/faltante), auditoría
   - Ejemplos: Apertura y cierre sin diferencia, cierre con faltante (autorización supervisor)

7. **caja-recibo-ingreso**
   - Tablas: `FCJ`, `PCJ`, `TFCJ`, `CPCJ`, `FPA`, `FTR`, `BCT`
   - SPs: `SPQ_CONF_CAJA` (métodos `TRAER_RECIBO`, `NUEVO_RECIBO`, `CONFIRMAR_RECIBO`), `SPK_CIERRERECIBO_CAJA`, `SPK_NC_CONTAB_CAJA_ING`, `SPK_CREA_FACTURA_POS_CAJA`
   - Variables: `CAJA_EXIGE_PACIENTE`, `CAJA_GENERA_FTR_POS`, `CAJA_VALIDA_CUADRE_FP`, `CAJA_PERMITE_VUELTOS`
   - Contenido: Traer recibo desde agenda (TFCJ), nuevo recibo, formas de pago mixtas (efectivo, datáfono, cheque, consignación), confirmación, actualización banco, contabilización, factura POS
   - Ejemplos: Copago consulta general (efectivo), venta de medicamentos con formas mixtas (efectivo + datáfono)

### Contabilidad (2 bloques)

8. **contabilidad-comprobante**
   - Tablas: `MCP`, `MCH`, `PRI`
   - SPs: `SPQ_MCP_COL` (métodos `CRUDMCP`, `CONFIRMAR_MASIVO`, `GENERAR_COMPROBANTE`), `SPK_REVISAR_COMPROBANTE`, `SPK_NC_CONFIRMAR_CONTAB`
   - Variables: `CONTAB_VALIDA_CUADRE`, `CONTAB_PERMITE_TERCERO_INACTIVO`, `CONTAB_EXIGE_CCOSTO`, `CONTAB_CONFIRMA_AUTO`
   - Contenido: Comprobante contable (cabecera MCP, líneas MCH), validación de cuadre (débitos = créditos), estados borrador/confirmado, periodo contable, comprobantes manuales y automáticos (FTR, CXP, CAJA, BMOV)
   - Ejemplos: Comprobante manual de ajuste (reclasificación de cuentas), comprobante automático de facturación

9. **contabilidad-errados**
   - Tablas: `MCPE`, `MCHE`
   - SPs: `SPQ_MCPE_COL` (métodos `RECONSTRUIR`, `REVISAR_MCPE`, `DIAGNOSTICAR_ERRORES`), `SPK_NC_REVISAMCPE`
   - Variables: `CONTAB_ENVIA_A_ERRADOS`, `CONTAB_DIAGNOSTICA_AUTO`, `CONTAB_PERMITE_EDITAR_ERRADO`
   - Contenido: Comprobantes errados (tercero inactivo, cuenta inexistente, no cuadra, duplicado, falta centro de costo), diagnóstico detallado, corrección de configuración (KMCOM, cuentas, terceros, variables), reconstrucción
   - Ejemplos: Tercero inactivo en CxP (activar tercero y reconstruir), comprobante no cuadra en facturación (corregir cuenta IVA en KMCOM)

## Temas actualizados en `temas.json`

- **Facturación:** 3 bloques (antes 5 genéricos)
- **Caja:** 2 bloques (antes 5 genéricos)
- **Cuentas por Pagar:** 2 bloques (antes 5 genéricos)
- **Contabilidad:** 2 bloques (antes 5 genéricos)
- **Inventario:** 43 bloques (sin cambios)
- **Orden de Compra:** 1 tema sin bloques (sin cambios)
- **Recaudos:** 1 tema sin bloques (sin cambios)
- Temas vacíos eliminados: **Glosas**, **Radicaciones**, **Nómina**, **Configuración General**

## Fuentes utilizadas

Cada bloque se construyó leyendo:

1. **Base de conocimiento:**
   - `conocimiento/facturacion/proceso.json` (flujos, ventanas, procedencias, controles)
   - `conocimiento/facturacion/sps.json` (18 objetos SQL documentados)
   - `conocimiento/cxp-fcxp/proceso.json` (flujo CxP completo)
   - `conocimiento/caja/proceso.json` (flujo caja completo)
   - `conocimiento/contabilidad/proceso.json` (MCP, MCPE, PRI)
   - `conocimiento/diccionario/indice.json` (tablas FTR, FTRD, FTRDC, FCXP, FCXPD, FCXPI, FCJ, PCJ, MCP, MCH, MCPE, MCHE)

2. **SPs documentados con métodos reales:**
   - `SPQ_FTR_COL`: `CREARFTR`, `CRUDFTRD`, `DELETEFTRD`, `ADDFTRDC`, `REV_DUP_FTRDC`, `CALCIMP_FTRD`
   - `SPQ_FCXP`: `CRUD_FCXP`, `CRUD_FCXPD`, `CRUD_FCXPI`, `CONTABILIZAR_FCXP`
   - `SPQ_ORDEN_PAGO`: `CRUD_FCXPPM`, `AUTORIZAR`, `CERRAR_CUENTA`, `ABRIR_CUENTA`
   - `SPQ_CONF_CAJA`: `APERTURA_CAJA`, `TRAER_RECIBO`, `NUEVO_RECIBO`, `CONFIRMAR_RECIBO`
   - `SPQ_CONF_CAJA_2`: `CIERRE_CAJA`, `CUADRE_CAJA`
   - `SPQ_MCP_COL`: `CRUDMCP`, `CONFIRMAR_MASIVO`, `GENERAR_COMPROBANTE`
   - `SPQ_MCPE_COL`: `RECONSTRUIR`, `REVISAR_MCPE`, `DIAGNOSTICAR_ERRORES`
   - `SPK_*`: procedimientos contables (`SPK_NC_CONTAB_FTR`, `SPK_NC_CONTAB_CXP`, `SPK_NC_CONTAB_CAJA_ING`, `SPK_NC_CONTAB_CAJA_EGR`, `SPK_NC_REVISAMCPE`), de cálculo (`SPK_TOTALFACTURFIN`, `SPK_CALCULOVALORESCXP`, `SPK_CIERRERECIBO_CAJA`), de validación (`SPK_REVISAR_COMPROBANTE`, `SPK_PRI`), de numeración (`SPK_GENNUMEROFACTURA`, `SPK_GENCONSECUTIVO`) y de autorización (`SPK_CONFIRMAR_PAGOSMASIVO`, `SPK_MARCA_OP_PAGADA_POR_EGRESO`)

3. **Variables USVGS reales:**
   - Facturación: `FTR_VALIDAR_TARIFA`, `FTR_MANUAL_TARIFARIO`, `FTR_CONTRATO_OBLIGATORIO`, `CAPITA_EXIGE_FTRDC`, `IDFORMATOFTRFINANCIE`, `FTR_VALIDA_CONTRATO_VIGENTE`, `FTR_CALCULA_IVA_AUTO`, `GENNUMEROFACTURA_PREFIJO`, `FACTURA_ALTA_COMPLETA`, `FACTURA_PERMITE_CORTE`, `FACTURA_VALIDA_AUTORIZACION`, `RIPS_OBLIGATORIO_FACTURA`, `CARGOS_DUPLICADOS_ALERTA`
   - CxP: `CXP_CALCULA_IVA_AUTO`, `CXP_CALCULA_RETENCIONES`, `CXP_EXIGE_ENTRADA_INV`, `CXP_VALIDA_CUADRE`, `CERRADO_CXP`, `AUT_EGRE_INDIVIDUAL`, `PERMITE_EGR_SIN_C`, `IDCJTECXP`, `BANC_DINA_ARCH_PLANO`
   - Caja: `CAJA_EXIGE_BASE`, `CAJA_CUADRE_AUTO`, `CAJA_FALTANTE_MAX`, `CAJA_REEMBOLSO_AUTO`, `CAJA_EXIGE_PACIENTE`, `CAJA_GENERA_FTR_POS`, `CAJA_VALIDA_CUADRE_FP`, `CAJA_PERMITE_VUELTOS`
   - Contabilidad: `CONTAB_VALIDA_CUADRE`, `CONTAB_PERMITE_TERCERO_INACTIVO`, `CONTAB_EXIGE_CCOSTO`, `CONTAB_CONFIRMA_AUTO`, `CONTAB_ENVIA_A_ERRADOS`, `CONTAB_DIAGNOSTICA_AUTO`, `CONTAB_PERMITE_EDITAR_ERRADO`

## Módulos omitidos (sin datos suficientes en KB)

- **Glosas:** sin `conocimiento/glosas/proceso.json` completo
- **Radicaciones:** sin `conocimiento/radicaciones/proceso.json`
- **Nómina:** sin `conocimiento/nomina/proceso.json`
- **Recaudos:** `conocimiento/recaudos/proceso.json` existe pero no se priorizó (se puede hacer en la siguiente vuelta)

## Pruebas ejecutadas

✅ **py_compile:** todos los scripts Python compilan sin errores  
✅ **test_capacitacion_prompts.py:** todas las escenas visuales pasan (sin códigos de tabla prohibidos ni keywords de armas)  

## Próximos pasos recomendados

1. Crear bloques para **Recaudos** (la KB existe y está documentada)
2. Ampliar **Facturación** con bloques de: RIPS y validación Ministerio, Documento electrónico DIAN, Radicación y cuenta de cobro, Factura desde citas/eventos, Factura masiva
3. Ampliar **Contabilidad** con bloques de: Periodo contable y cierre, Plan de cuentas (CUE), Modelo contable (KMCOM)
4. Documentar procesos de **Glosas**, **Radicaciones** y **Nómina** en `conocimiento/` para poder crear bloques genuinos

## Conclusión

Se eliminaron todos los bloques genéricos (plantilla boilerplate) y se crearon **9 bloques genuinos** con datos reales de la KB:
- Tablas reales con campos decisivos visibles en frontend
- SPs documentados con métodos, validaciones y errores típicos
- Variables USVGS concretas con valores habituales y efectos
- Ejemplos exclusivos del sector salud (IPS, EPS, contratos, facturación médica, proveedores farmacéuticos, recaudos asistenciales)
- **Cero** menciones a "Pendiente validar" con campo vacío: solo se marca pendiente cuando hay una pregunta concreta

Calidad > Cantidad. Los bloques están listos para capacitación real.
