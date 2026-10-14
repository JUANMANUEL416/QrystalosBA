# -*- coding: utf-8 -*-
"""Sketchnotes del proceso Activos fijos (módulo IACT).

Uso:  python libro/scripts/gen_activos_sketchnotes.py
Salida: libro/img/activos_config_sketchnote.jpg, activos_alta_sketchnote.jpg,
        activos_responsables_sketchnote.jpg, activos_eventos_sketchnote.jpg,
        activos_depreciacion_sketchnote.jpg

Contrastado 2026-10-04 con Qrystalos2 (GestionIACTComponent, EventosIACTComponent, ResponsablesIACTComponent,
AccesoriosIACTComponent, DepreciacionIACTComponent, TipoActivoComponent, EventosComponent, GruposComponent,
ArticulosComponent, Contable/DepreciacionActivosComponent, composables useActivoFijo/*) y con IXONLINE/SQL
(SPQ_IACT, SPQ_IACTH, SPQ_APLICAR_IACTH, SPQ_CONTAB_IACT, SPQ_GEN_DEPRECIACION, SPK_GEN_DEPRECIACION,
SPQ_TIPOAF, SPQ_EVENTOAF, SPQ_GRUPAC, SPQ_IACTR, SPQ_VERIF_IACT_PARTIC, SPQ_IACTEQU, SPQ_CONTABILIDAD_3,
SPK_APL_AJDEPRECIACION). PREVERSION idéntica a la última liberada en todos.
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · ACTIVOS FIJOS"


def main():
    sketch(
        "activos_config_sketchnote.jpg", B,
        "Antes del primer activo: tipos, eventos, grupos y variables",
        "Activos Fijos → Tipos de activo · Eventos · Grupos · Artículos · Equipos por sector · Notificaciones",
        [
            {"num": "1", "tit": "Tipo de activo", "sub": "TIPOAF · GUARDAR / GENERAR_DEP", "pal": "sky", "items": [
                ("Define:", "Clase Local o Niif, qué campos exige el alta (modelo, marca, serial, referencia, escritura, linderos, partes, matrícula)."),
                ("Depreciación:", "Vida útil en meses, tipo de salvamento (valor o porcentaje) y valor de salvamento."),
                ("Generar Depreciación:", "Marca depreciables los activos del tipo y recalcula sus cuotas pendientes."),
                ("Administrador:", "Asignar Administrador liga empleados al tipo (solo si TIPO_ACTIVO_USUARIO = SI)."),
            ]},
            {"num": "2", "tit": "Eventos", "sub": "EVENTOAF · GUARDAR", "pal": "orange", "items": [
                ("Qué es:", "El catálogo de novedades: tipo Entrada, Salida o Traslado, descripción."),
                ("Pide:", "Estado, valor, centro de costo y área: al menos uno marcado."),
                ("Contable:", "Se contabiliza? exige comprobante; el estado asociado igual al de baja marca Baja de activo."),
            ]},
            {"num": "3", "tit": "Grupos y artículos", "sub": "GRUPAC · IART · ITAR", "pal": "violet", "items": [
                ("Grupos:", "Grupo y subgrupo del activo (tabla general ACTIVOSFIJOS / GRUPOS)."),
                ("Artículos:", "El artículo de inventario puede llevar tipo de activo fijo y fabricante; el alta lo referencia."),
                ("Sector:", "Equipos por sector y notificaciones de parada por servicio (tabla general)."),
            ]},
            {"num": "4", "tit": "Variables y contabilidad", "sub": "USVGS · KMCOM", "pal": "green", "items": [
                ("Alta:", "IDPROCESOCONTABLE = MIXTO pide tipo Niif y valor comercial Niif; TERCATFABRICANTE filtra fabricantes."),
                ("Eventos:", "IACTEVENTOCOMPRA (no se aplica desde novedades); IACT_ESTADOBAJA (estado de baja)."),
                ("Contable:", "IDMODELOCONTABLE + KMCOM (MOV_ACTIVOS, DEPRECIACION); comprobantes IDCON_TCOM_DEFAULT e IDCON_TCOM_DEPR; COMPROBMULTISEDE."),
            ]},
        ],
        pills=[
            ("Regla", "Sin tipo de activo no hay alta: el tipo dice qué campos son obligatorios."),
            ("Regla", "Sin comprobante de depreciación (IDCON_TCOM_DEPR) no se contabiliza el mes."),
            ("Ojo", "Las variables se configuran por instalación; no hay valores únicos."),
        ],
        accent="#0369a1",
    )

    sketch(
        "activos_alta_sketchnote.jpg", B,
        "Alta del activo: de la compra a la ficha con código",
        "Activos Fijos → Gestión → Nuevo activo → Información → Guardar → (Se deprecia) Generar Depreciación",
        [
            {"num": "1", "tit": "Gestión", "sub": "AppStore.read IACT", "pal": "sky", "items": [
                ("Filtros:", "Campo + operador + valor (Agregar), fechas de compra (Hoy), sector / servicio, Buscar activo, Actualizar."),
                ("Fila:", "Editar, Hoja de vida (impresora) y expandir para ver Eventos."),
                ("Imprimir:", "Formatos en blanco: Paz y Salvo, Entrada y Salida, Acta de Entrega."),
            ]},
            {"num": "2", "tit": "Información", "sub": "IACT · TRE_TIPOACT", "pal": "orange", "items": [
                ("Tipo:", "Al elegir el tipo el formulario exige los campos marcados en él."),
                ("Datos:", "Descripción, estado, costo histórico, valor comercial, fecha de compra, código interno y alterno, código de barra."),
                ("Ubicación:", "Centro de costo, área funcional, servicio / sector, grupo, fabricante (*), cuenta (*), proveedor."),
                ("Técnico:", "Invima, año, voltajes, calibración, parada, propiedad, mantenimiento; fotografía."),
            ]},
            {"num": "3", "tit": "Guardar", "sub": "IACT · GUARDAR (INSERTAR)", "pal": "violet", "items": [
                ("Código:", "Lo asigna el sistema por consecutivo al guardar."),
                ("Rechaza:", "Serial, código interno o código alterno ya usados por otro activo."),
                ("Foto:", "Se sube aparte y queda ligada a la ficha."),
                ("Editar:", "Mismo formulario; aparecen Accesorios, Responsables y Depreciación."),
            ]},
            {"num": "4", "tit": "Se deprecia", "sub": "GEN_DEPRECIACION · SPK_GEN_DEPRECIACION", "pal": "green", "items": [
                ("Marca:", "Se deprecia? es de solo lectura: lo fija Generar Depreciación (del activo o del tipo)."),
                ("Cálculo:", "Cuota mensual lineal: (costo − salvamento) / meses de vida útil, desde la compra."),
                ("Ficha:", "Meses a depreciar, meses depreciados, acumulados y fecha de última depreciación."),
            ]},
        ],
        pills=[
            ("Regla", "Serial, código interno y código alterno son únicos por activo."),
            ("Regla", "La hoja de vida necesita fabricante: sin él no imprime."),
            ("Ojo", "Mantenimiento, Documentos e Importar aún no están disponibles en esta versión."),
        ],
        accent="#c2410c",
    )

    sketch(
        "activos_responsables_sketchnote.jpg", B,
        "Accesorios, responsables, capacitación y formatos",
        "Editar activo → Accesorios · Responsables (Asignar → Capacitación → Retirar → Imprimir acta)",
        [
            {"num": "1", "tit": "Accesorios", "sub": "IACTEQU · GUARDAR / ELIMINAR", "pal": "sky", "items": [
                ("Qué es:", "Las partes que acompañan al activo: ítem, descripción, serial, marca, modelo, código interno, estado."),
                ("Regla:", "El ítem no se repite dentro del mismo activo."),
            ]},
            {"num": "2", "tit": "Asignar responsable", "sub": "IACTR · GUARDAR", "pal": "orange", "items": [
                ("Pide:", "Empleado activo, cargo, fecha de asignación, estado Asignado, validado No, observación."),
                ("Capacitación:", "Casillas: uso básico, almacenamiento, verificación de accesorios, entrega de manuales."),
                ("Regla:", "El mismo empleado no se asigna dos veces al mismo activo; la fecha de retiro se edita después."),
            ]},
            {"num": "3", "tit": "Entrega y verificación", "sub": "VERIF_IACT_PARTIC · GUARDAR", "pal": "violet", "items": [
                ("Pestaña Capacitación:", "Registros de entrega (tipo ASIGACTI) con fecha, empleado y cargo."),
                ("Para qué:", "Soporta el acta de entrega al responsable y la trazabilidad de la capacitación."),
            ]},
            {"num": "4", "tit": "Retirar e imprimir", "sub": "IACTR · RETIRAR · INFO_VERIF", "pal": "green", "items": [
                ("Retirar:", "Fecha de retiro hoy y estado Retirado; la fila deja de editarse."),
                ("Imprimir:", "Acta del responsable en PDF desde la fila; formatos en blanco desde Gestión → Imprimir."),
                ("Hoja de vida:", "Ficha completa del activo con foto, responsables y accesorios."),
            ]},
        ],
        pills=[
            ("Regla", "Retirado es definitivo en pantalla: para reasignar se crea una asignación nueva."),
            ("Regla", "Eliminar responsable está oculto: la historia se conserva."),
            ("Ojo", "Paz y Salvo, Entrada y Salida y Acta de Entrega son formatos para diligenciar a mano."),
        ],
        accent="#6d28d9",
    )

    sketch(
        "activos_eventos_sketchnote.jpg", B,
        "Novedades del activo: registrar, aplicar y contabilizar",
        "Gestión → expandir fila → Eventos → Nuevo → Aplicar Novedad → (contable) comprobante",
        [
            {"num": "1", "tit": "Nueva novedad", "sub": "IACTH · GUARDAR", "pal": "sky", "items": [
                ("Pide:", "Evento del catálogo (no de mantenimiento), fecha, valor (por defecto el costo), estado nuevo, centro de costo y área, observación."),
                ("Nace:", "Pendiente: sin aplicar y sin contabilizar; se puede editar o eliminar."),
                ("No aplica:", "El evento de compra se registra con el alta, no como novedad."),
            ]},
            {"num": "2", "tit": "Aplicar (no contable)", "sub": "APLICAR_IACTH · GENERAR", "pal": "orange", "items": [
                ("Traslado:", "Cambia centro de costo y área de la ficha."),
                ("Salida:", "Cambia el estado; si el evento es de baja, el activo deja de depreciarse."),
                ("Entrada:", "Actualiza estado y valor; recalcula las cuotas pendientes."),
                ("Marca:", "Aplicada: ya no se edita ni elimina."),
            ]},
            {"num": "3", "tit": "Aplicar (contable)", "sub": "CONTAB_IACT · GENERAR", "pal": "violet", "items": [
                ("Comprobante:", "Un comprobante por novedad con el modelo contable (MOV_ACTIVOS, DEPRECIACION)."),
                ("Entrada:", "Débito al activo. Salida: crédito al activo, débito a depreciación acumulada y saldo a resultado."),
                ("Traslado:", "Reclasifica activo y depreciación entre centros de costo o áreas."),
                ("Revisa:", "Totales del comprobante y copia NIIF si el proceso contable es mixto."),
            ]},
            {"num": "4", "tit": "Después", "sub": "IACTH · CONTABILIZADA / APLICADA", "pal": "green", "items": [
                ("Novedad:", "Contabilizada y aplicada: bloqueada en pantalla."),
                ("Ficha:", "Verifique estado, centro de costo y acumulados del activo tras una novedad contable."),
                ("Depreciación:", "Vuelva a Generar Depreciación si cambió el valor o el estado."),
            ]},
        ],
        pills=[
            ("Regla", "Periodo contable abierto para la fecha de la novedad contable."),
            ("Regla", "El evento decide: Se contabiliza? → comprobante; si no → solo ficha."),
            ("Ojo", "La novedad contable no actualiza la ficha por sí sola: revísela."),
        ],
        accent="#be123c",
    )

    sketch(
        "activos_depreciacion_sketchnote.jpg", B,
        "Depreciación: cuotas por activo y contabilización del mes",
        "Generar Depreciación (activo o tipo) → Contabilidad → Depreciación activos → periodo → Contabilizar período",
        [
            {"num": "1", "tit": "Cuotas", "sub": "SPK_GEN_DEPRECIACION", "pal": "sky", "items": [
                ("Base:", "Vida útil y salvamento del tipo si el activo no trae saldo inicial."),
                ("Cálculo:", "Cuota mensual lineal (costo − salvamento) / meses; una línea por mes desde la compra o desde la última contabilizada."),
                ("Reproceso:", "Borra solo las cuotas no contabilizadas y las recalcula."),
                ("Fin:", "Si ya se depreció todo, avisa «Activo depreciado completamente»."),
            ]},
            {"num": "2", "tit": "Periodo", "sub": "CONTABILIDAD_3 · DEPRECIACION_ACTIVOS_LISTA", "pal": "orange", "items": [
                ("Pantalla:", "Contabilidad → Depreciación activos: elija año-mes; lista de cuotas con Contabilizado, acumulados y meses pendientes."),
                ("Excel:", "Exporta las columnas visibles; Columnas permite ocultar y restaurar."),
            ]},
            {"num": "3", "tit": "Validaciones", "sub": "DEPR_ACFIJP_ENV_CONTA", "pal": "violet", "items": [
                ("Exige:", "Comprobante de depreciación configurado (IDCON_TCOM_DEPR)."),
                ("Rechaza:", "Activos comprados en los últimos 90 días sin cuotas; compras del último año con menos cuotas que meses a depreciar; mes sin cuotas pendientes."),
            ]},
            {"num": "4", "tit": "Comprobante", "sub": "SPK_APL_AJDEPRECIACION", "pal": "green", "items": [
                ("Asiento:", "Débito gasto / crédito depreciación acumulada por activo (KMCOM DEPRECIACION), fecha último día del mes."),
                ("Excluye:", "Activos de baja, cuotas en cero y clase NIIF; distribuye por centro de costo si hay distribución."),
                ("Marca:", "Cuotas contabilizadas con número de comprobante; ficha con acumulados y fecha de última depreciación."),
            ]},
        ],
        pills=[
            ("Regla", "Primero cuotas generadas, después el periodo: sin cuotas el mes no se envía."),
            ("Regla", "Un comprobante por mes y sede (COMPROBMULTISEDE usa el comprobante de la sede)."),
            ("Ojo", "Reversar el mes es tarea de contabilidad: la pantalla solo contabiliza pendientes."),
        ],
        accent="#15803d",
    )
    print("ok", IMG_DIR)


if __name__ == "__main__":
    main()
