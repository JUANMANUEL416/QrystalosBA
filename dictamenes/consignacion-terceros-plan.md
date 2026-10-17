# Plan técnico — consignación entre empresas Qrystalos

**Estado:** propuesta para validación  
**Fecha:** 16 de octubre de 2026  
**HTML:** `dictamenes/consignacion-terceros-proceso.html`  
**PDF:** `dictamenes/consignacion-terceros-proceso.pdf`

## Objetivo

Diseñar el estándar de consignación de Qrystalos para operación local o integrada, con catálogo gobernado por el proveedor, API en tiempo real, remisión, reposición, facturas versionadas y ajuste de CxP según el contrato del pagador.

## Decisiones de diseño

- Las instalaciones se coordinan como **clínica receptora** y **empresa proveedora**.
- Cada evento tendrá un identificador global para enlazar solicitud, movimientos, remisión, reposición, factura y CxP.
- El traslado consignación → principal genera una salida de consignación y una entrada tipo remisión.
- El precio del movimiento no se sobrescribe; las diferencias contractuales se registran como ajustes.
- Cada consumo o solicitud genera en el proveedor:
  1. Salida-remisión desde la bodega de ventas para facturar.
  2. Pedido y salida desde la bodega abastecedora para reponer la consignación.
- Osteosíntesis y materiales especiales con paciente se facturan individualmente por salida.
- El precio se recalcula al facturar según el pagador y contrato vigentes.
- El proveedor gobierna los códigos de medicamentos, materiales e insumos integrados.
- Cirugía y hemodinamia activan el flujo en tiempo real cuando solicitan artículos consignados.
- Las facturas pueden modificarse, anularse o reemplazarse; cada versión recalcula costo y CxP sin borrar el histórico.
- La consignación funciona como estándar local con o sin API.
- Un panel administra empresas, bodegas, artículos, API, variables, movimientos, facturas y logs.

## Implementación

1. **Preparar fuentes y núcleo estándar.** Crear una rama de trabajo desde `develop`. Recuperar y comparar los SP vigentes de artículos, bodegas, solicitudes, movimientos, remisiones, facturación, CxP e interfaz. Diseñar primero la consignación local y luego el adaptador API.
2. **Crear la configuración y el panel.** Parametrizar empresas, bodegas, artículos consignados, áreas disparadoras, modalidad de factura, recepción, API, seguridad, tipos de movimiento, máximos, mínimos y reprocesos.
3. **Sincronizar maestros.** Publicar desde el proveedor altas, cambios e inactivaciones con versión e idempotencia. Crear u homologar en la clínica sin duplicados y conservar sus parámetros locales.
4. **Implementar el flujo de la clínica.** Al solicitar un artículo consignado desde cirugía, hemodinamia o bodega principal, generar salida de consignación, entrada-remisión y evento al proveedor.
5. **Implementar las dos ramas del proveedor.** Crear la salida-remisión facturable y el pedido/salida de reposición, ambos vinculados al origen.
6. **Resolver modalidad, precio y versiones de factura.** Mantener separados precio del movimiento y precio facturado. Modelar emisión, modificación, anulación y reemplazo.
7. **Integrar factura y CxP.** Crear, recalcular o revertir la CxP según la versión recibida, sin modificar el movimiento histórico.
8. **Construir la integración Qrystalos-a-Qrystalos.** Publicar API versionada para maestros, solicitudes, remisiones, reposición, recepción y facturas. Usar autenticación, outbox/inbox, idempotencia, reintentos y auditoría.
9. **Validar y documentar.** Probar modo local, modo integrado, sincronización, escenarios con/sin paciente, versiones de factura, caídas, duplicados y eventos fuera de orden.

## Variables propuestas

Todos los identificadores respetan el máximo de 20 caracteres de `USVGS.IDVARIABLE`.

- `INV_CONSIGNA`: activa el estándar de consignación.
- `INV_CONSIG_API`: activa la integración en tiempo real.
- `INV_CONSIG_AUTOREC`: controla la confirmación automática de recepción.
- `IDINV_CONS_ENT`: entrada a bodega consignada.
- `IDINV_CONS_SAL`: salida desde consignación.
- `IDINV_CONS_REM`: entrada tipo remisión en principal.
- `IDINV_CONS_VTA`: salida-remisión del proveedor.
- `IDINV_CONS_REP`: salida de reposición.
- `IDINV_CONS_DEV`: devolución de consignación.
- `INV_CONSIG_REINT`: política de reintentos.

Las URL, credenciales, certificados y secretos deben almacenarse en configuración segura del panel, no como texto visible en variables generales.

## Criterios de aceptación

- Un evento de la clínica produce exactamente una remisión facturable y una reposición en el proveedor.
- La entrada en principal es una remisión y conserva el precio histórico.
- El proveedor crea los códigos y la clínica los homologa una sola vez.
- Cirugía y hemodinamia activan automáticamente el flujo para artículos consignados.
- Las facturas individuales conservan paciente, pagador, responsable y solicitud original.
- Modificaciones, anulaciones y reemplazos recalculan la clínica sin duplicar CxP.
- El despacho del proveedor crea una recepción pendiente sin duplicados.
- El panel permite parametrizar y diagnosticar toda la operación.
- La bodega consignada funciona aunque la API esté desactivada o la contraparte no esté disponible.
- Los flujos existentes de compra, remisión, custodia, dispensación y devolución no cambian.

## Condición previa para implementar

`Qrystalos2` se encontraba en `develop`, rama protegida. Antes de realizar cambios se debe crear y utilizar una rama propia desde `develop`.
