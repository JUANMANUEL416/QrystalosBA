# Inventario, Compras y Farmacia

Proceso `inventario` · módulo INVENTARIO · familia Inventario.
Menú en Qrystalos2: **Inventario** (USPROH `MENUQ_INVENTARIO`, visible según USGRUH): ítems sueltos
(Movimientos, Solicitudes, Informes, Semáforo, Packing, Canastas, satélites de farmacia clínica) y grupos
**Procesos** (Orden de compra, Devolución a proveedor, Conteo físico, Cuentas por pagar, Ajustes de inventario),
**Venta a particulares** (Venta de insumos, Lista de precios, Factura INV, Cotización de compras, Gestión de ventas),
**Configuración** (bodegas, tipos de movimiento, tipos de artículo, artículos y catálogos farmacéuticos) y
**Mobiliario**.

El libro (`capitulosLibro`, 18 capítulos y 14 mapas) explica el proceso de punta a punta y en orden:
configuración → tipos de movimiento → compras → recepción y CxP automática → salidas y traslados →
solicitudes/dispensación → conteo físico y ajustes → devolución a proveedor y vencidos → venta al público →
Pick & Pack → informes y kardex → contabilidad → semáforos de estados → menú y satélites → pendientes.
Este archivo no se incluye como capítulos (`incluirProcesoMdEnLibro: false`).

## Fuente SQL

Procedimientos leídos desde IXONLINE/SQL, canasta **PREVERSION**, contrastada con la última liberada **2.0.7**
(anterior 2.0.6). PREVERSION es distinta en `SPQ_IZSOL`, `SPK_CONFIRMARENTRADAS`, `SPK_CONFIRMASAL_CM` y `SPQ_IARTO`
(detalle en `sps.json` → `cola`). Fichas: 77 objetos / 631 METODOs (2ª pasada 2026-10-04: SPK de conteo, vencidos,
ajuste IDXB, loteo de tránsito, clonar OC, traer compra a salida, anular movimiento, GESVENTA, IZSOL_2 y satélites
de farmacia clínica). Regla del libro: no se publican volúmenes ni valores de configuración de un cliente.

## Columna vertebral

| Etapa | Pantalla | MODELO · METODO clave | Efecto |
|---|---|---|---|
| Configurar | Configuración → … | ITBOD, IBOD, IBODS, ITMO, ITAR, ICLA/IGEN/IFFA/ICCN/IPAC/IUNI/ITGEN, IART, IDXB, ESTANTE | Catálogos; variables USVGS `IDINV*` apuntan al tipo de movimiento |
| Comprar | Lista de precios → Cotización → Orden de compra | ILPRE · GUARDAR / GENERAR_OC; FCOM · GUARDA_FCOM / CONFIRMAR_ORDEN | FCOM C → P; `SPK_INSERT_ITRA_REQ` crea el tránsito |
| Recibir | Movimientos → Traer del tránsito | IZSOL_TRANSITO · BUSCAR_RADIAN_LOTEO / GUARDAR_CUFE_LOTEO / ON_PROCESAR; IZSOL · CONF_ENTRADA → `SPK_CONFIRMARENTRADAS` | Con INV_CUFE_LOTEO = SI: Factura o Remisión, Todos y faltante en Loteado (control imov-transito). Luego IEXI/IDXB/IART, kardex, ITRA 1, FCOM R/I, **FCXP automática** (KMCOM `CXP_COMPRAS`) |
| Sacar | Movimientos (salida / traslado) | IMOV · CRUD_IMOV_SAL / ENTREGA_ISAL / CONFIRMA_SALIDA → `SPK_CONFIRMARSALIDAS` | IEXI descuenta; tipo 14 crea tránsito; destino acepta con 13 |
| Dispensar | Solicitudes | IZSOL · AGREGAR / ENTREGAR / PROCESAR → `SPK_PROCESA_IZSOLDT` / `SPK_CONFIRMASAL_CM` | Salida 06 (el movimiento más frecuente); devolución con IDINVMOV_DEVOLUCION |
| Controlar | Conteo físico · Devolución a proveedor · Semáforo · Ajustes | CONTEOFISICO · APLICAR → `SPK_APLICARCONTEO`; DEVOLU_PROVEEDOR · CONFIRMAR; SEMAFORO · SALIDA_VENCIDOS; INFOMRES_INV · ACTUALIZAR_EXISTENCIAS | Ajustes con IDINVSISAL (salida, confirmada en el acto) e IDINVSIENT (entrada, queda pendiente); devolución 05; destrucción 07 (valida CCOSTO y KMCOM antes de mover) |
| Vender | Venta de insumos · Factura INV | VENTAFAR · GUARDA_VENTA; IMOV_VENTA · FACTURAR_MASIVO | IMOV VE/VC + FTR + FCJ |
| Contabilizar | OM Inventario · Cuentas por pagar · Facturación | `SPK_NC_CONTAB_INV`, `SPK_NC_CONTAB_CXP`, FTR | Tres puertas contables |

## Estados

- **FCOM**: C abierta · P procesada · R recepción parcial · I confirmada en bodega · A anulada · S (sin etiqueta en FE).
- **ITRA**: 0 abierto · 1 recibido · 2 cancelado · 3 (sin etiqueta).
- **IMOV**: 0 pendiente · 1 confirmado · 2 anulado. **IZSOL**: 0 pendiente · 1 en proceso · 2 cerrada.

## Hallazgos 2026-10-04

- `IART · CARGAR_PRECIO_REGULADO` se invoca desde Artículos y no existe en `SPQ_IART`.
- `ESFARMACIA` debe valer exactamente «SI»: `SPQ_IMOV` y `SPK_ANULAR_MOV_INV` comparan con «SI»; cualquier otro valor apaga el control de costo cero y la anulación de movimientos confirmados (en una base revisada estaba en otro valor).
- `SPK_APLICARCONTEO` deja la entrada de ajuste en estado 0: hay que confirmarla en Movimientos (allí se exigen cuentas KMCOM).
- `SPK_ANULAR_MOV_INV` necesita `FAR_MOVANULAENTRADA` / `FAR_MOVANULASALIDA`; crea el movimiento contrario y lo confirma.
- `SPK_UPDATE_VLRS_FCOM` describe un estado E de FCOM que el FE no muestra.
- `SPK_AJUSTE_IDXB_IART` corre sobre todo el inventario (sin parámetros).
- `ITMO · ELIMINAR` solo revisa IEXCEP; no revisa movimientos existentes.
- `SPQ_IMOV_2` duplica lógica de IMOV + IMOV_3.
- Confirmar / anular movimientos no consultan `PRI.CERRADO_INV` (SR20260911-001).

Todos los SP listados como pendientes el 2026-10-04 quedaron fichados (`SPQ_ORDEN_PAGO` y `SPQ_CONF_CAJA` se
referencian desde `cxp-fcxp` y `caja`). Queda por profundizar con flujo propio: Lista de trabajo (LISTA_AUT),
hemoderivados (TRANSFUSIONAL) y delivery MAD (ver `conocimiento/pendientes.json`).
