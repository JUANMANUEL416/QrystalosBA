# Dispensación

Inventario → Solicitudes (`/inv/sol_2`). Hay que elegir bodega. Este archivo no se incluye como capítulos
(`incluirProcesoMdEnLibro: false`); el libro sale de `capitulosLibro` (10 capítulos, 3 mapas, 2 flujos, 1 semáforo).

Es la entrega de lo que ya fue pedido: una admisión, una orden, una cita, una fórmula o una aplicación. No es la venta
de mostrador ni la custodia.

## Qué hace la persona

1. Elige bodega, busca la solicitud y la toma (**Dispensar** → `IZSOL · AGREGAR`). Si otro equipo la tiene abierta, el sistema avisa.
2. Entrega cada medicamento por lote y cantidad (`ENTREGAR` o código de barras). No deja pasar un medicamento suspendido
   en la orden, una solicitud vencida, una admisión cerrada ni una orden de consulta externa anulada.
3. Procesa (`PROCESAR`). Eso arma el detalle del movimiento, que sigue en borrador.
4. Confirma (`CONF_MOVIMIENTO` → `SPK_CONFIRMASAL_CM`). Baja la existencia, completa tercero y centro según la procedencia,
   genera el cargo al paciente (`SPK_GENCOBRO_INSCENTRAL`, salvo producción y consumo) y cierra la solicitud si no queda nada pendiente.
5. Si sobró o se devuelve, usa la devolución de la misma solicitud (`IZSOL_2 · PROCESAR_DEVOLUCION`, tipo `IDINVMOV_DEVOLUCION`).
   Si cerró de más y aún hay líneas pendientes, puede reabrirla.

## Procedencias (IZSOL.CLASE)

El filtro Procedencia y la columna CLASE muestran el mismo código; el SP decide por ese valor.

| Grupo | Códigos | Qué cambia |
|---|---|---|
| Admisión | SENFER, OMEDICA, 24HORAS, HTX, HBALINI, OMSOLI | Valida admisión cerrada (`ALTAS_QUE_VALIDA_INV`), vigencia (`MVIGENCIAIZSOL`/`HVIGENCIAIZSOL`) y suspendidos; tercero de HADM, área/centro de HHAB |
| Consulta externa | CE, TRANS_CE, FORMEDCE, FORMEDASIS, APOYODX | CE: AUT es la referencia, orden anulada bloquea, copago en caja si lo generó; manual CE (TRANS_CE, FORMEDCE, MANUALCE) salta vigencia, cierre y copago |
| Procedimientos y programas | QXPGCX, ONCO, HEMOD, HPRE | Sin validación de cierre ni vigencia; ONCO toma paciente/plan/contratante de CIT |
| Sin paciente que cobrar | PROD, Consumo, APLIM | PROD y Consumo no cobran; APLIM marca APLIMF como DISPENSADA al confirmar |

`ENTREGALOG` no es procedencia: AGREGAR la usa solo para llamar `SPK_CM_GENIMOV_SOL`.

## Dónde sigue

La existencia que se entrega puede ser del hospital o, si se recibió así, de la **custodia** del paciente. Quien pidió la
aplicación sigue el ciclo en **Aplicación de medicamentos**. El movimiento confirmado se ve en **Movimientos** (`/inv/ges`) y
su contabilidad en el libro de Inventario.

## Hallazgos 2026-10-04

- Cobro en FORMEDCE / TRANS_CE: `SPK_GENCOBRO_INSCENTRAL` inserta HPRE con FK a HADM y esas procedencias guardan el afiliado; la validación está comentada.
- Permisos ModificarCopago / Particular / CBodega se leen de `Brw:BrwVerSolicitudes_InvPeru` en cualquier país.
- Presupuesto de materiales apagado en la confirmación (INV-TCK-04); en Perú `CONF_MOVIMIENTO` sí bloquea si hay HPREP sin aprobar.
