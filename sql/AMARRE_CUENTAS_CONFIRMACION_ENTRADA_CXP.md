# Amarre de cuentas: confirmación de la entrada y cuenta por pagar de compras

CEM. Soporte. Septiembre 2026.

La cuenta por pagar de una compra nace de la entrada. El encabezado, el detalle y el lote deben salir de lo que se recibió. Si la línea no tiene IVA, no lleva cuenta de IVA y la cuenta del servicio es la de excluidos. Si la línea tiene IVA, la cuenta del servicio pasa a la gravada y lleva la cuenta de IVA descontable.

Estos cambios corrigen datos ya grabados y la configuración que los produjo. El procedimiento que confirma la entrada masiva todavía puede volver a poner el total de la orden en el encabezado. Ese cambio de programa está pedido en la solicitud SR20260926-001 y no está publicado.

## Regla del amarre

| Qué | Sin IVA | Con IVA |
|---|---|---|
| Detalle `FCXPD.CUENTA_SER` | 14150502 medicamentos excluidos | 14150501 medicamentos gravados |
| Detalle `FCXPD.CUENTA_IVA` | Vacía | 24080501 IVA descontable |
| Encabezado `FCXP.CUECREDITO` | 22050101 proveedores | 22050101 proveedores |
| Inventario débito `IEXI.CUEDEBITO` | 14150502 | 14150501 |
| Inventario reversión `IEXI.CUECREDITO` | 14150591 | 14150590 |
| Encabezado `FCXP.VALOR` / `VLR_NETO` / `SALDO` | Suma de lo recibido en esta entrada | Suma de lo recibido en esta entrada |

El crédito del encabezado no cambia por el IVA. El IVA solo mueve la cuenta del detalle y la del lote.

Si la entrada no trae IVA, la cuenta por pagar tampoco. DPE11292 (03CM001991, entrada 0300026859, MX1944-1) quedó en 14150502, sin cuenta de IVA, porque la entrada está en cero. Eso está bien.

## 1. Configuración KMCOM

El débito de compras debe nacer en la cuenta no gravada. Al terminar el insert, si la línea tiene IVA, el procedimiento la pasa a la gravada. Dos filas del modelo 01, proceso `CXP_COMPRAS`, prefijo 01, área 4110, ya estaban en gravados. Por eso una factura sin IVA quedaba en 14150501. El crédito del centro 40010101 también estaba en gravados.

Script: `sql/CORRECCION_KMCOM_CXP_COMPRAS_NO_GRAVADA.sql`

Quedó así, revisado en CEM:

| Centro | Tipo | Cuenta |
|---|---|---|
| 40010101 | DB | 14150502 excluidos |
| 40010101 | CR | 22050101 proveedores |
| 10250202 | DB | 14150502 excluidos |
| 10250202 | CR | 22050101 proveedores |

El script no reescribe facturas ya hechas. Las que nacieron antes se corrigieron en el punto 3.

## 2. Encabezado igual a la entrada

En la recepción masiva, `SPK_CONFIRMARENTRADAS` arma el detalle con lo recibido y después vuelve a escribir el encabezado con `FCOM.VR_ANTESIVA`, el total de la orden. Si la entrada es parcial, la misma cuenta por pagar queda con mercancía que no entró.

Se corrigieron tres cuentas sin contabilizar. El detalle no se tocó: ya era la entrada.

Script: `sql/CORRECCION_FCXP_ENCABEZADO_ENTRADA_SEP2026.sql`

| Cuenta | Factura | Antes | Después |
|---|---|---:|---:|
| 26CM000528 | DPE11790 | 106.891.881,12 | 74.065.751,04 |
| 03CM001951 | DPE11721 | 5.680.472,00 | 132.810,00 |
| 34CM000083 | DPE12636 | 5.680.472,00 | 4.955.910,00 |

DPE11721 y DPE12636 son la orden 2600001259. MX1203-2 llegó en dos entradas (570 y 21.270). MX1206-1, 2.800 unidades y 591.752, no ha entrado y sigue en la orden para otra cuenta por pagar.

Revisado en CEM: el neto de las tres coincide con la suma del detalle. DPE11721 y DPE12636 coinciden también con el monto de RADIAN. DPE11790 coincide con la entrada y queda 1.928,96 por debajo del XML: la factura cobra la caja de 48 a 16.895 y el sistema guardó la unidad a 351,97. Las cantidades sí están completas. Ese precio no se modificó.

## 3. Líneas sin IVA que quedaron en gravados

Dieciséis líneas de septiembre, IVA en cero y sin cuenta de IVA, estaban en 14150501. Cinco encabezados también acreditaban a gravados. Los lotes nacidos en esas entradas tenían débito 14150501 y reversión 14150590.

Script: `sql/CORRECCION_FCXPD_SIN_IVA_EXCLUIDOS_SEP2026.sql`

| Cuenta | Factura | Qué se cambió |
|---|---|---|
| 26CM000489 | DPE11219 | Solo el detalle. El crédito ya era 22050101. |
| 34CM000014 | DPE10812 | Detalle y crédito |
| 03CM002011 | DPE11248 | Detalle y crédito |
| 34CM000015 | DPE11687 | Detalle y crédito |
| 34CM000016 | DPE11686 | Detalle y crédito |
| 34CM000017 | DPE11674 | Detalle y crédito |

El detalle quedó en 14150502. El crédito de las seis quedó en 22050101. Los lotes de esas entradas quedaron en débito 14150502 y reversión 14150591. DPE10812 no creó lote propio: sus artículos están en los lotes de DPE11248 y quedaron en el mismo cambio.

Revisado en CEM: en septiembre ya no hay compras sin IVA en una cuenta gravada. Ninguna de estas seis está contabilizada.

## Qué no cambió el programa

KMCOM ya nace bien para las entradas nuevas de esos dos centros. El procedimiento de confirmación masiva sigue pudiendo pisar el encabezado con el total de la orden. La solicitud SR20260926-001 pide que, con `CUFE_DESDE_RADIAN` en SI, el CUFE venga de RADIAN (en la masiva, dentro del mismo archivo) y que totales y líneas de la entrada se comparen con el XML antes de causar. Si la entrada es mayor que la factura, no confirma. Si es menor, la cuenta por pagar queda en lo recibido.

Siguen sin corregir, y no forman parte de estos tres scripts, las líneas cuyo IVA está en 24080601 (IVA generado) en lugar de 24080501 (IVA descontable): FEP109948, DPE11741, DPE11925, DPE12388 y DPE12422.
