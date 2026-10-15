# Fase 1 — Grafo operativo de inventario (16 tramos)

**Estado:** cerrada en catálogo (2026-10-14)  
**Alcance:** todo el libro de inventario: compras, movimientos, dispensación, conteo, devolución, vencidos, Pick & Pack, ajustes, custodia y satélites.

## Capacitación (cadena)

```text
Lista de precios (no stock)
  → Cotización → Generar OC (FCOM C)
  → Confirmar OC (FCOM P + tránsito, no stock)
  → Lotear o Excel (IMOV 0, no stock)
  → Confirmar entrada (IEXI + CxP si compra)
Salida: armar IMOV 0 + ISAL → Confirmar (descuenta IEXI)
Mostrador: carrito → Guardar (confirma + descuenta + FTR + caja)
Factura INV: salida VC ya confirmada → solo factura

Solicitud IZSOL → Tomar → Entregar lote → Procesar → Confirmar (descuenta; no es CONFIRMARSALIDAS)
Conteo IFIS → 3 conteos → Aplicar → salida confirmada + entrada pendiente
OC ingresada → Devolver 05 → Confirmar (descuenta; nota CxP en el otro módulo)
Semáforo → Salida 07 confirmada en el acto (no mira reserva P&P)
Packing: reservar → picking → packing → Confirmar salida (ahí descuenta)
Custodia: tránsito propio → confirmar entrada (sin factura ni CxP)
```

## Fallas a priorizar en desarrollo / test

| Prioridad | Hallazgo | Tramo |
|-----------|----------|-------|
| Crítica | ANULAR OC no mira si ya se recibió | órdenes |
| Crítica | Confirmar/anular IMOV no mira PRI.CERRADO_INV | confirmación |
| Alta | Reconfirmar OC puede duplicar tránsito | órdenes |
| Alta | CANTISOL recortado a 32767 | cotizaciones |
| Alta | Código artículo VARCHAR(10) en el carrito | ventas |
| Alta | FECHACONF = hoy; el asiento usa esa fecha, no FECHAMOV | confirmación / ventas |
| Alta | Caja cerrada: recibo con CNSACJ nulo | ventas |
| Alta | KMCOM modelo '01' fijo al confirmar salida | confirmación (INV-TCK-01) |
| Media | GENERAR_OC marca Compra aunque no nazca orden | cotizaciones |
| Media | ABRIR actualiza IEXIF aunque falle | órdenes |
| Media | ESFARMACIA debe ser exactamente SI | entradas / confirmación |
| Crítica | Dispensación: CONF_MOVIMIENTO no mira PRI; no usa CONFIRMARSALIDAS | dispensación |
| Alta | Presupuesto de materiales apagado (INV-TCK-04) | dispensación |
| Crítica | Conteo: aplicar sin PRI; entrada de ajuste queda en 0 | conteo |
| Crítica | Vencidos confirman sin PRI y no respetan reserva P&P | vencidos |
| Alta | Devolución a proveedor hereda confirmar sin PRI | devolución |

Índice: `grafo-inventario-indice.json`. Cada tramo: `grafo-inventario/{id}.json` + `puntos-criticos-{id}.json`.
