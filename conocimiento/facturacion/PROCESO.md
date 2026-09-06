# Proceso: Facturación

**Estado:** parcial  
**Módulo:** FTR

> Solo flujo y explicación. Los SP se bajan a `sql/` el día que se analicen.

## Resumen

Quien factura arma la factura en Administrativo → Facturación, notifica a la DIAN, empaqueta anexos, junta facturas en una **cuenta de cobro** y la **radica** en Cuentas por cobrar (fecha, quién recibió, número de radicado).

Eso no es el menú **Radicaciones** (`/rad`): ahí se reciben lotes, incapacidades y PQR.

## Capas

1. Configuración — resolución DIAN, firma, pagador/plan.
2. Proceso propio — facturar → notificar → empaquetar → armar cuenta → radicar.
3. Lo que llega — admisión, citas, autorizaciones.
4. Subproceso unido — empaque y RIPS/FEV (no bancos).
5. Envío a contabilidad — factura y cuenta (cuerpo de SP no leído).

## Pendiente

- [ ] Bajar a `sql/` y Documentar: SPQ_FTR_COL, SPQ_FTR_MASIVA_COL, SPQ_DOCXEMPQ, SPQ_ENT_COL, SPQ_FCXC_COL.
