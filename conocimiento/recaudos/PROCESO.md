# Proceso: Cartera · Recaudos

**Módulo:** Recaudos de Cartera  
**Ventana:** Administrativo → Cartera → Recaudos (`/admin/Recaudos`)  
**Ventana hermana (preversión):** Contable → Aval recaudos (`/cont/avalRecaudos`)

> El libro de este proceso (`capitulosLibro` en `proceso.json`) está organizado en 14 capítulos cortos con mapa de proceso (sketchnote) cada uno. Este archivo es la narrativa de referencia para Documentar; no se vuelca al libro (`incluirProcesoMdEnLibro = false`).

## Qué es un recaudo

Quien cobra crea una cabecera (tercero, ingreso, valor, fecha), asigna facturas de la cuenta de cobro y pulsa Aplicar. El ingreso cambia el origen del dinero, la plantilla y lo que pasa al aplicar. Los seis ingresos son CAJA, BANCOS, GLOSAS, CXP, DEVOLUCION y LEVANTAMIENTO. El **Paso a seguir** (columna *Proceso* en pantalla) solo aparece en GLOSAS y DEVOLUCION.

Siempre el mismo hilo: crear → asignar (una a una o Excel) → aplicar. No se aplica sin líneas. Un mismo usuario no puede tener dos recaudos abiertos del mismo tercero e ingreso.

## Caja

En el recaudo de ingreso CAJA la búsqueda es de **recibos**, no de la caja maestra.

Salen recibos del mismo tercero con la casilla **Recaudo** marcada en Caja (ingreso externo marcado para recaudo), ya cerrados, en estado activo y que todavía no estén vinculados a otro recaudo. Al guardar, el recaudo asocia la caja y el número de recibo, y el recibo queda registrado en pagos.

La opción «Acepta Recaudo» es una configuración de caja menor en la administración de cajas. La pantalla de Recaudos no filtra por ese campo.

## Bancos

Misma idea con el movimiento de tesorería. La operación financiera trae la marca de Recaudo. La búsqueda lista líneas del tercero marcadas con recaudo, sin estar previamente en pagos, con el movimiento bancario confirmado por tesorería y con saldo por legalizar mayor que cero. Al guardar, esa línea queda vinculada al pago. En BANCOS, con permiso de retiro de facturas, se puede retirar una factura aunque el recaudo esté aplicado.

## Plantilla de CAJA, BANCOS y CXP

La descarga **Estructura Excel** trae `N_FACTURA`, `VLRPAGO`, `TIPO` y `VALIDACION`. Si al descargar se marcan impuestos o descuento administrativo, se agregan hasta cuatro grupos de impuesto y `VLR_DTO`. `TIPO` es F, G, R o C. `VLRPAGO` mayor que cero. `VALIDACION` es una fórmula de la hoja: las filas con factura deben decir OK. Esa columna no viaja al servidor. Al subir, obligatorias son solo factura, valor y tipo; los impuestos se leen si el archivo los trae. Reenviar borra el lote anterior; Exportar errados y Exportar log muestran las filas rechazadas.

CXP, además de esa plantilla de facturas, tiene la pestaña de cruce con cuentas por pagar. La suma del cruce tiene que igualar el valor de los ítems antes de Aplicar.

Sin la variable de ajuste al peso configurada no se pueden crear recaudos de caja, banco ni CxP.

## Glosas — Pasos a seguir

| Paso a seguir | Nombre en pantalla | Qué hace al aplicar | Plantilla Excel (columnas) |
|---|---|---|---|
| 3 | Recepcionar | Registra la glosa en el sistema. No se responde de forma automática. Cartera pulsa **Enviar a auditoría** para que los auditores médicos revisen los soportes. Si las variables de motivo están en SI, la hoja suma motivo 1, motivo 2 y observación. | `N_FACTURA`, `TIPO`, `VLRPAGO` |
| 4 | Recepcionar y Responder | Registra la glosa y la responde de inmediato al 100%, aplicando la nota crédito según el valor aceptado e imprimiendo el soporte. No se puede deshacer. El encabezado del archivo debe ser idéntico al descargado. | `N_FACTURA`, `TIPO`, `VLRPAGO`, `MOTIVO1`, `OBS`, `CODRPTA`, `VLR_ACEPTADO`, `VALIDACION` |
| 5 | Detalles Glosa | Registra en auditoría médica el detalle ítem por ítem del servicio de salud. El auditor responde manualmente cada servicio. La suma de ítems debe cuadrar con el valor global. | `N_FACTURA`, `TIPO`, `VLR_GLOSA`, `CODGLOSA`, `VLR_ITEM`, `OBSERVACION`, `VALIDACION` |
| 6 | Detalles y Responder | Registra el desglose ítem por ítem del servicio y responde automáticamente en el mismo acto con el código y valor aceptado. No se puede deshacer. Las observaciones exigen un mínimo de 10 caracteres. | `N_FACTURA`, `TIPO`, `CODGLOSA`, `VALOR`, `CODRPTA`, `VLR_ACEPTADO`, `OBSERVACIONES`, `VALIDACION` |

La fila sin número de factura se ignora. En los pasos 4, 5 y 6, la columna `VALIDACION` de Excel debe mostrar OK.

Retirar una factura de un recaudo de glosas **ya cerrado** solo está permitido en Recepcionar (3) y Detalles Glosa (5), siempre que el usuario cuente con el permiso de retiro de facturas. Desaplicar glosas se bloquea si auditoría ya contestó alguna glosa del recaudo y, en preversión, si el periodo contable de la fecha está cerrado.

## Devoluciones — Pasos a seguir

| Paso a seguir | Nombre | Qué hace al aplicar | Plantilla Excel |
|---|---|---|---|
| 0 | Solo devolver | Retira la factura de la cuenta de cobro para corrección. Motivo y observación solo si las variables del sistema lo exigen. | `N_FACTURA`, `VLRPAGO` |
| 1 | Devolver y anular | Retira la factura de la cuenta de cobro, la devuelve a facturación y la anula en el sistema. No se puede desaplicar. | `N_FACTURA`, `VLRPAGO`, `MOTIVO1`, `OBS` |
| 2 | Devolver y radicar | Retira de la cuenta de cobro actual y crea automáticamente una nueva cuenta lista para radicación. No se puede desaplicar. | `N_FACTURA`, `VLRPAGO`, `MOTIVO1`, `OBS` (Idéntica a la opción 1) |

La búsqueda de facturas en devolución solo ofrece tipo F. La hoja generada para 1 y 2 no incluye segundo motivo. Con opciones de anular o radicar (1 y 2), una vez cerrado el recaudo no se puede retirar la factura ni desaplicar; en abierto tampoco se ofrece Anular. La respuesta posterior (Soportar / Anular) se define en Administrativo → Respuesta Devoluciones.

## Corregir: desaplicar, anular, retirar

- **Abierto:** papelera en la línea, Borrar todo, Inactivar, Anular.
- **Cerrado con mes contable abierto:** Desaplicar (reabre; permiso BDesaplicarPago) o Anular (cancela). Retirar una sola factura en BANCOS o GLOSAS 3/5 con BRetiraFactura; la línea queda Retirada con su comprobante de retiro.
- **Cerrado con mes contable cerrado:** solo CAJA y BANCOS, por el circuito de aval (abajo). GLOSAS y los demás ingresos no se desaplican.

## Desaplicar en periodo cerrado con aval contable (preversión, REQ 0100016348)

Si el mes contable de la fecha de legalización ya está cerrado (cierre general o cierre de cartera), la pantalla oculta el Desaplicar clásico y muestra el estado del aval:

1. **Cartera · Solicitar aval** (solo si `REC_SOLICITA_AVAL = SI`): el recaudo queda con Aval = Pendiente.
2. **Contabilidad · Aval recaudos** (Contable → Aval recaudos, permiso `BAvalRecaudoConta`): lista los pendientes y Avalar seleccionados → Avalado con usuario y fecha. El periodo histórico no se abre.
3. **Cartera · Desaplicar con aval**: crea el comprobante de reversión con fecha actual (ligado al original), deja todas las facturas del recaudo **Retiradas** con ese comprobante, reliquida cada factura y libera la cartera. El recaudo **sigue Cerrado**; el jefe de cartera arma un recaudo nuevo.

Si `REC_SOLICITA_AVAL` no es SI, no hay solicitud: el botón Desaplicar ejecuta el mismo reverso y registra el aval a nombre de quien desaplica. Una sola vez: si ya hay facturas retiradas, no se repite. Esta función está en PREVERSION de IXONLINE/SQL; la liberada 2.0.7 no la trae.

## Reglas que no cambian

Aplicar un recaudo exige periodo contable abierto en el sistema, detalle de facturas asignadas, sin facturas repetidas y cuentas de impuestos vigentes. La contabilización ocurre al aplicar, no en un botón aparte. Glosas, notas y conciliaciones son procesos complementarios: este módulo concluye al aplicar el recaudo (y, en glosas 4 y 6, al dejar la respuesta asentada en cartera).
