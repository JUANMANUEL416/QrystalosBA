# Activos fijos (IACT)

Estado: documentado · 2026-10-04

## Fuentes
- Qrystalos2: GestionIACTComponent, EventosIACTComponent, ResponsablesIACTComponent, AccesoriosIACTComponent, DepreciacionIACTComponent,
  FabricantesIACTComponent, TipoActivoComponent, EventosComponent, GruposComponent, ArticulosComponent, TipoArticuloComponent,
  EquiposXSectorComponent, NotifiParXSectorComponent, Contable/DepreciacionActivosComponent, composables useActivoFijo/* (hoja de vida,
  paz y salvo, entrada/salida, acta de entrega, acta responsable), ActivosFijosLayout (MENUQ_COL · IACT), pages/iact/IndexPage.
- IXONLINE/SQL (DESAIX): ver `sps.json`. PREVERSION idéntica a 2.0.7 en todos los objetos bajados a `sql/`.
- qrystalos.documentacion: sin fichas IACT*.md; IART.md referencia FK_IACT_IACTIDARTICULO.

## Trazabilidad FE → SPQ → METODO
| Pantalla | MODELO | METODO |
|---|---|---|
| Gestión | IACT | GUARDAR, TRE_TIPOACT, OBTENER_FOTO, INFO_HV_IACT |
| Eventos (fila) | IACTH / APLICAR_IACTH / CONTAB_IACT | GUARDAR, ELIMINAR / GENERAR / GENERAR |
| Accesorios | IACTEQU | GUARDAR, ELIMINAR |
| Responsables | IACTR / VERIF_IACT_PARTIC | GUARDAR, ELIMINAR, RETIRAR / GUARDAR, ELIMINAR, INFO_VERIF |
| Depreciación (pestaña) | GEN_DEPRECIACION | GENERAR_DEPRECIACION, OBTENER_IACT |
| Tipos de activo | TIPOAF | GUARDAR, GUARDAR_TIPOACTIVO_USUARIO, ELIMINAR, GENERAR_DEP |
| Eventos (catálogo) | EVENTOAF | GUARDAR, ELIMINAR |
| Grupos | GRUPAC | GUARDAR, GUARDAR_SUBGRUP, ELIMINAR, ELIMINAR_SUBGRUP |
| Artículos | IART / DOCXTPO | GUARDAR, ELIMINAR / CONSULTAR, INSERTAR, GET_ARCHIVO, ELIMINAR |
| Equipos x sector / Notificaciones | EQXSEAF / NOTIFPARADAAF | GUARDAR, ELIMINAR |
| Fabricantes | TER_COL | GUARDAR |
| Contabilidad → Depreciación activos | CONTABILIDAD_3 | DEPRECIACION_ACTIVOS_LISTA, DEPR_ACFIJP_ENV_CONTA |

## Notas internas (no van al manual)
- Aplicar Novedad en FE: `modelo = MUEVECONTABILIDAD == 'SI' ? 'CONTAB_IACT' : 'APLICAR_IACTH'`, siempre METODO GENERAR con NROCOMPROBANTE ''.
- CONTAB_IACT filtra la línea CR del activo por IACTH.VALOR <> 0; APLICAR_IACTH actualiza IACT por IACTE.TIPO (Traslado/Salida/Entrada).
- SPK_APL_AJDEPRECIACION: estado de baja fijo '02'; DEPACUM* = SUM por comprobante; marca todas las IACTD del mes de activos depreciables.
- DEPR_IACTD_UNICO y RESET_CONTABILIZADO existen en CONTABILIDAD_3 sin botón en la pantalla de depreciación.
- Pestaña Distribución Contable comentada en GestionIACTComponent (IACTDIS sin mantenimiento en Qrystalos2).
- Variables vistas: IDPROCESOCONTABLE, TERCATFABRICANTE, IACTEVENTOCOMPRA, IACT_ESTADOBAJA, TIPO_ACTIVO_USUARIO, IDMODELOCONTABLE,
  IDCON_TCOM_DEFAULT, IDCON_TCOM_DEPR, COMPROBMULTISEDE, IDTERCEROINSTALADO, CON_ACTFIJO_CONTAXCC (leída, sin uso).

## Hallazgos
16 registrados en `proceso.json → hallazgos` y en `pendientes.json` (prefijo `activos-`). Sin dictamen aún.
