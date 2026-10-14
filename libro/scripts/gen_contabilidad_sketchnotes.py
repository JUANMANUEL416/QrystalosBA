# -*- coding: utf-8 -*-
"""Sketchnotes del proceso Contabilidad (módulo CONTABLE).

Uso:  python libro/scripts/gen_contabilidad_sketchnotes.py
Salida: libro/img/conta_menu_sketchnote.jpg, conta_comprobante_sketchnote.jpg,
        conta_errados_sketchnote.jpg, conta_alimentadores_sketchnote.jpg,
        conta_liqimp_sketchnote.jpg, conta_correcciones_sketchnote.jpg,
        conta_libros_sketchnote.jpg, conta_cierre_sketchnote.jpg

Contrastado 2026-10-04 con Qrystalos2 (ContableLayout, MCPComponent, MCHComponent, MCPEComponent,
MCHEComponent, OtrosModulos + OM*, ConciContables + CONC*, LiqImpuComponent, FoliarLibros, Reclasificar*,
CastigoCartera, ProcesosContables + Abrir/Cerrar/CierreFiscal, BalanceAuxiliar, LibrosAuxiliares,
EstadoResultado, HistoricoBalances, BalanceGeneral, CircularUnica, GenerarExogena, ConfExogena) y con
IXONLINE/SQL (SPQ_MCP_COL, SPQ_MCPE_COL, SPQ_MCH_COL, SPQ_MCHE_COL, SPQ_CONTABILIDAD, SPQ_CONTABILIDAD_2,
SPQ_CONTABILIDAD_3, SPK_CONTAB_MASIVA, SPK_NC_REVISAMCPE, SPK_REVISAR_COMPROBANTE, SPK_SUMA_DBCR,
SPK_NC_CONFIRMAR_CONTAB, SPK_PASA_A_MCPE, SPK_NC_BALANCEO_CENTAVOS, SPQ_CONTA_LIQIMP, SPK_GEN_CXP_LIQIMP,
VWK_LIQ_IMP, SPQ_FOLIAR_LB, SPK_HOMOLOGA_TERCERO, SPK_HOMOLOGA_CUENTA, SPK_NC_CONTAB_CASTIGO_CARTERA,
SPK_CIERRA_PERIODOCONTABLE, SPK_ABRE_PERIODOCONTABLE, FNK_REVISION_ANTES_CIERRE_PERIODO, SPK_CIERRE_FISCAL,
SPK_DIAG_MCPE_ERRORES). PREVERSION idéntica a la última liberada en todos.
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · CONTABILIDAD"


def main():
    sketch(
        "conta_menu_sketchnote.jpg", B,
        "El mapa del menú Contable: cuatro familias y un atajo",
        "Contable → Procesos · Consultas · Otros Módulos · Parametrización · Normas Niif",
        [
            {"num": "1", "tit": "Procesos", "sub": "Lo que mueve saldos", "pal": "sky", "items": [
                ("Movimiento Diario:", "Los comprobantes (MCP) y su detalle (MCH): crear, confirmar, desconfirmar, duplicar, imprimir."),
                ("Comprobantes Errados:", "Lo que llegó de otros módulos y no cuadró (MCPE/MCHE): revisar, corregir, reconstruir."),
                ("Cierres:", "Abrir/Cerrar Periodos, Cierre Fiscal, Depreciación, Liquidación de Impuestos."),
                ("Correcciones:", "Reclasificar Terceros y Cuentas, Castigo de Cartera, Aval recaudos, Conciliaciones, Exógena, Circular Única."),
            ]},
            {"num": "2", "tit": "Consultas", "sub": "Lo que muestra saldos", "pal": "orange", "items": [
                ("Libros:", "Balance de Prueba y Libro Auxiliar, Libros auxiliares (asíncrono), Balance general, Estado de resultados."),
                ("Histórico:", "Fotos de mes/año del balance y del estado de resultados; se imprimen y se eliminan desde Histórico."),
                ("Cartera y bancos:", "Análisis de vencimientos, Seguimiento de cartera, Auxiliar de bancos, Trazabilidad de documentos."),
            ]},
            {"num": "3", "tit": "Otros Módulos", "sub": "La entrada a contabilidad", "pal": "violet", "items": [
                ("Pestañas:", "Facturas, Caja, Bancos, Recaudos (CXC), Glosas, CxP, Inventario, Notas D/C, Mov. Activo."),
                ("Gesto único:", "Buscar periodo → marcar → Enviar a Contabilidad. El motor arma el comprobante y lo revisa."),
            ]},
            {"num": "4", "tit": "Parametrización y Niif", "sub": "Lo que se configura una vez", "pal": "green", "items": [
                ("Catálogos:", "Periodos Contables (PRI), Naturaleza (NTZ), Parámetros Contables (PAR), Agrupación de Cuentas (KPRES)."),
                ("Exógena y libros:", "Formatos y conceptos (EXOFMT), Foliar Libros (consecutivos USCXS)."),
                ("Niif:", "Parámetros NIIF (PARN) y terceros equivalentes de efectivo; el resto del submenú aún no tiene pantalla."),
            ]},
        ],
        pills=[
            ("Regla", "Cada opción se habilita por grupo de usuario (USGRUH · MENUQ_CONTABLE); sin permiso queda gris."),
            ("Regla", "El periodo contable (PRI) manda: cerrado = ninguna acción que mueva saldos."),
            ("Ojo", "Hay opciones del menú sin pantalla todavía: Provisiones de Cartera, Libros oficiales y los procesos Niif."),
        ],
        accent="#0369a1",
    )

    sketch(
        "conta_comprobante_sketchnote.jpg", B,
        "El comprobante contable: de borrador a confirmado",
        "Procesos → Movimiento Diario (MCP + MCH)",
        [
            {"num": "1", "tit": "Cabecera", "sub": "MCP_COL · CRUDMCP", "pal": "sky", "items": [
                ("Qué lleva:", "Periodo, tipo de comprobante (COM), fecha contable, tercero, referencias, detalle, cheque."),
                ("Nace:", "En estado 0 (borrador). La fecha contable debe caer dentro del periodo elegido y el periodo debe estar abierto."),
                ("Procedencia:", "MANUAL si lo digita contabilidad; FACTURA, CAJA, CXP, CXC, INV, NOTDBCR, BMOV… si lo armó otro módulo."),
            ]},
            {"num": "2", "tit": "Detalle", "sub": "MCH_COL · CRUDMCH", "pal": "orange", "items": [
                ("Cada línea:", "Cuenta de detalle, DB o CR, valor, tercero, centro de costo, referencias, base de impuesto."),
                ("Subir detalle:", "Excel con formato descargable; valida cuentas, terceros y centros antes de grabar (SUBIR_DETALLE_COMPROBANTE)."),
                ("Recalcular:", "Suma DB y CR y decide el estado: 0 con errores, 1 preparado, 2 contabilizado (SPK_SUMA_DBCR)."),
            ]},
            {"num": "3", "tit": "Confirmar", "sub": "CONFIRMAR_MASIVO → SPK_NC_CONFIRMAR_CONTAB", "pal": "green", "items": [
                ("Revisa:", "Cuenta existe y es de detalle, valor distinto de cero y positivo, tercero existe (SPK_REVISAR_COMPROBANTE)."),
                ("Cuadra:", "DB = CR y todas las líneas en estado 1; si no, 'no está preparado para su contabilización'."),
                ("Resultado:", "MCP y MCH pasan a estado 2 y afectan saldos. Desconfirmar regresa a 1 mientras el periodo esté abierto."),
            ]},
            {"num": "4", "tit": "Después", "sub": "Duplicar · Imprimir · Enviar a cambios", "pal": "violet", "items": [
                ("Duplicar:", "Copia cabecera y detalle a un comprobante MANUAL nuevo en estado 0."),
                ("Imprimir:", "Reporte individual o masivo (GENERAR_COMPROBANTE_CONTABLE / MASIVO_V2) y exportación a Excel."),
                ("Enviar a cambios:", "Solo no MANUAL: devuelve el comprobante a Errados (SPK_PASA_A_MCPE) para corregirlo y reconstruirlo."),
            ]},
        ],
        pills=[
            ("Regla", "Un comprobante confirmado (2) no se edita: se desconfirma o se envía a cambios."),
            ("Regla", "Anulado = estado 0 y sin efecto en saldos; confirmar un anulado falla."),
            ("Ojo", "El filtro inicial trae el tipo de comprobante por defecto (IDCON_TCOM_DEFAULT) para no cargar todo el periodo."),
        ],
        accent="#b45309",
    )

    sketch(
        "conta_errados_sketchnote.jpg", B,
        "Comprobantes errados: la sala de espera de la contabilidad",
        "Procesos → Comprobantes Errados (MCPE + MCHE)",
        [
            {"num": "1", "tit": "Por qué llegan", "sub": "SPK_NC_REVISAMCPE", "pal": "rose", "items": [
                ("Flujo invertido:", "Todo comprobante de otro módulo nace en MCPE/MCHE; solo si pasa la revisión se copia a MCP/MCH."),
                ("Si falla:", "Se queda en MCPE con estado 0 y el documento origen queda CONTABILIZADA = 2 (con errores)."),
                ("Causas típicas:", "Cuenta inexistente o no de detalle, valor cero o negativo, tercero inexistente, descuadre, KMCOM sin cuenta."),
            ]},
            {"num": "2", "tit": "Leer el error", "sub": "OBTENER_ERRORES_DETALLE · DIAGNOSTICAR_ERRORES", "pal": "orange", "items": [
                ("Línea:", "El campo ERROR/DETALLE de MCHE dice qué falló y de qué procedencia, proceso, centro y referencias viene."),
                ("Diagnóstico:", "Códigos con severidad (SIN_LINEAS_MCHE, DESCUADRE_DB_CR, CUENTA_NO_EXISTE, KMCOM_NO_DEFINIDO, TERCERO_NO_EXISTE…) y sugerencia."),
                ("KMCOM:", "Botón directo a la configuración contable del módulo cuando el error es de parametrización."),
            ]},
            {"num": "3", "tit": "Corregir", "sub": "MCHE_COL · CRUDMCHE · PROCESAR_MARCADOS", "pal": "sky", "items": [
                ("Editar línea:", "Cuenta, valor, tercero, centro de costo, referencias (permiso EditarItemMCHE)."),
                ("Masivo:", "Marcar líneas → Procesar: cambia centro de costo y área a todas las marcadas y reconstruye."),
                ("Mejor:", "Corregir la causa (cuenta en KMCOM, tercero, documento) y reconstruir, no parchar la línea."),
            ]},
            {"num": "4", "tit": "Reconstruir / Revisar", "sub": "MCPE_COL · RECONSTRUIR · REVISAR_MCPE", "pal": "green", "items": [
                ("Reconstruir:", "Borra el intento y vuelve a correr el generador de la procedencia (SPK_NC_CONTAB_*); respeta líneas corregidas a mano."),
                ("Revisar:", "Vuelve a pasar la revisión sin regenerar; si cuadra, pasa a MCP/MCH y confirma automáticamente."),
                ("Centavos:", "Diferencias menores a 2,00 se ajustan solas en la primera línea DB o CR (SPK_NC_BALANCEO_CENTAVOS)."),
            ]},
        ],
        pills=[
            ("Regla", "Cerrar periodo con comprobantes en MCPE está bloqueado: errados = 0 antes del cierre."),
            ("Regla", "MANUAL no se reconstruye: se corrige en Movimiento Diario."),
            ("Ojo", "Al pasar a MCP el documento origen queda CONTABILIZADA = 1 con su NROCOMPROBANTE."),
        ],
        accent="#be123c",
    )

    sketch(
        "conta_alimentadores_sketchnote.jpg", B,
        "Cómo se alimenta la contabilidad desde los otros módulos",
        "Contable → Otros Módulos · Conciliaciones contables",
        [
            {"num": "1", "tit": "Marcar y enviar", "sub": "CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS", "pal": "sky", "items": [
                ("Pestaña:", "Facturas (FTR), Caja (FCJ), Bancos (BMOV), Recaudos (FPAG), Glosas (FGLO), CxP (FCXP), Inventario (IMOV), Notas (FNOT), Mov. Activo."),
                ("Filtro:", "Año y mes contable; caja o bodega según pestaña; estado Pendiente / Enviado / Errores."),
                ("Envío:", "Marca MARCACONT = 1 en los documentos elegidos y llama SPK_CONTAB_MASIVA con la procedencia."),
            ]},
            {"num": "2", "tit": "El motor", "sub": "SPK_CONTAB_MASIVA → SPK_NC_CONTAB_*", "pal": "orange", "items": [
                ("Un SP por módulo:", "FTR, CAJA_ING/EGR, CXP, CXC, FGLO, INV, FNOT, BMOV. Cada uno lee KMCOM y arma MCPE/MCHE."),
                ("Cuentas:", "Salen de la configuración contable del módulo (KMCOM), del tipo de tercero (TTEC), impuestos (FIMPDV) y variables."),
                ("Luego:", "SPK_NC_REVISAMCPE revisa; si pasa, el comprobante queda en MCP confirmado y el documento CONTABILIZADA = 1."),
            ]},
            {"num": "3", "tit": "Estados del documento", "sub": "MARCACONT · CONTABILIZADA", "pal": "violet", "items": [
                ("0 Pendiente:", "Sin enviar. Aparece en la pestaña para marcar."),
                ("1 Enviado:", "Ya tiene comprobante (NROCOMPROBANTE). No se vuelve a enviar."),
                ("2 Errores:", "Está en Comprobantes Errados; se corrige allá y se reconstruye."),
            ]},
            {"num": "4", "tit": "Conciliaciones contables", "sub": "Documento ↔ comprobante", "pal": "green", "items": [
                ("Qué muestra:", "Por módulo, cada documento con su MCP o su MCPE, y la diferencia si la hay."),
                ("Acciones:", "Enviar a contabilidad, Reconstruir, y en CxP / CXC desmarcar contabilizado para reenviar (RESET_CONTABILIZADO)."),
                ("Caja:", "UPDATE_FCJ y CORREGIR_Y_CONTABILIZAR_FCJ para recibos con datos corregidos."),
            ]},
        ],
        pills=[
            ("Regla", "Nunca se contabiliza dos veces: 'ya se enviaron a contabilidad' detiene el envío."),
            ("Regla", "Los módulos de nómina, anticipos, legalización, glosas-FGLO, depreciación y radicación CXC se contabilizan desde su propio módulo."),
            ("Ojo", "Enviar sin KMCOM completo produce errados, no comprobantes."),
        ],
        accent="#6d28d9",
    )

    sketch(
        "conta_liqimp_sketchnote.jpg", B,
        "Liquidación de impuestos: del movimiento retenido a la cuenta por pagar",
        "Procesos → Liquidación Impuestos",
        [
            {"num": "1", "tit": "Consultar", "sub": "VWK_LIQ_IMP", "pal": "sky", "items": [
                ("Qué suma:", "Movimientos MCH de comprobantes confirmados, en cuentas marcadas como impuesto (CUE.IMPUESTO = 1), con base de impuesto."),
                ("Agrupa:", "Año, mes, tercero, cuenta: base, débitos, créditos y valor según la naturaleza de la cuenta (NTZ)."),
                ("Filtros:", "Fecha inicial/final, cuenta inicial/final, tercero opcional, fecha de certificado."),
            ]},
            {"num": "2", "tit": "Generar CxP", "sub": "CONTA_LIQIMP · GEN_CXP_LIQIMP", "pal": "orange", "items": [
                ("Condición:", "Un solo mes, sin filtro de tercero, sin CxP previa del periodo y permiso ACT_CXP_LIQUIIMP."),
                ("Hace:", "Crea una cuenta por pagar al tercero DIAN (IDTERCERO_DIAN) con un ítem por cuenta de impuesto y marca MCH.LIQUI_IMP = 1."),
                ("Cierra:", "PRI.CERRADO_IMP = 1: el periodo ya no admite otra liquidación."),
            ]},
            {"num": "3", "tit": "Documentos", "sub": "Certificado · Imprimir CxP · Detalles", "pal": "green", "items": [
                ("Certificado:", "Por tercero (uno) o todos los del periodo en ZIP: retenciones practicadas."),
                ("Imprimir CxP:", "La cuenta por pagar generada, con su consecutivo SR."),
                ("Por tercero / Por cuenta:", "Listados agrupados para revisar antes de pagar."),
            ]},
            {"num": "4", "tit": "Después", "sub": "CxP → Orden de pago → Egreso", "pal": "violet", "items": [
                ("La CxP:", "Nace contabilizada con el comprobante de referencia: no genera asiento nuevo; el pasivo ya está en las cuentas de impuesto."),
                ("Pago:", "Se paga como cualquier CxP; el egreso debita la cuenta de impuesto vía la CxP."),
                ("Asumidos:", "LIQIMPASUMIDO decide si los impuestos asumidos entran o no en la liquidación."),
            ]},
        ],
        pills=[
            ("Regla", "Sin tercero DIAN configurado no hay liquidación: 'Variable de sistema IDTERCERO_DIAN no configurada'."),
            ("Regla", "La CxP es consolidada del periodo completo; el filtro de tercero solo sirve para consultar."),
            ("Ojo", "Cualquier filtro de cuentas al generar marca CERRADO_IMP del periodo entero."),
        ],
        accent="#047857",
    )

    sketch(
        "conta_correcciones_sketchnote.jpg", B,
        "Correcciones: cambiar tercero, cuenta o castigar sin romper los libros",
        "Procesos → Reclasificar Terceros · Reclasificar Cuentas · Castigo de Cartera · Aval recaudos",
        [
            {"num": "1", "tit": "Reclasificar tercero", "sub": "CONTABILIDAD · RECLASIFICAR_TERCEROS_*", "pal": "sky", "items": [
                ("Cuándo:", "El saldo quedó en un tercero equivocado en un periodo ya cerrado."),
                ("Hace:", "Comprobante HOTERCUE en el mes siguiente: reversa el saldo del tercero actual y lo abona al nuevo (SPK_HOMOLOGA_TERCERO)."),
                ("Y además:", "Actualiza el tercero en facturas, CxP, recaudos, caja, radicaciones y presupuesto ligados."),
            ]},
            {"num": "2", "tit": "Reclasificar cuenta", "sub": "RECLASIFICAR_CUENTAS_*", "pal": "orange", "items": [
                ("Cuándo:", "Una cuenta se usó mal o se reorganiza el PUC."),
                ("Hace:", "Comprobante de homologación que traslada el saldo de la cuenta actual a la nueva, opcionalmente por tercero (SPK_HOMOLOGA_CUENTA)."),
                ("Requiere:", "Periodo cerrado de partida y que ambas cuentas sean de detalle."),
            ]},
            {"num": "3", "tit": "Castigo de cartera", "sub": "CASTIGO_CARTERA_* → SPK_NC_CONTAB_CASTIGO_CARTERA", "pal": "rose", "items": [
                ("Marcar:", "Facturas con saldo (FCXCDV) por tercero y fecha; marca por equipo, no por usuario."),
                ("Castigar:", "Comprobante IDCON_TCOM_CASTICART contra la cuenta KCDE · CXC_CASTIGO_CARTERA."),
                ("Difícil cobro:", "Traslada a la cuenta CUEDIFCOB del tipo de tercero (TTEC); sin cuenta, no deja seguir."),
            ]},
            {"num": "4", "tit": "Aval y marcas", "sub": "FPAG_COL · AVALAR_RECAUDO · RESET_CONTABILIZADO", "pal": "green", "items": [
                ("Aval recaudos:", "Contabilidad avala recaudos de cartera pendientes antes de que se contabilicen (permiso BAvalRecaudoConta)."),
                ("Reset:", "Desmarcar CONTABILIZADA de una CxP para reenviarla cuando el comprobante se perdió."),
                ("Enviar a cambios:", "Desde Movimiento Diario, devuelve un comprobante de módulo a Errados."),
            ]},
        ],
        pills=[
            ("Regla", "Nunca se edita un periodo cerrado: toda corrección es un comprobante nuevo en el periodo abierto."),
            ("Regla", "Castigar exige variables y cuentas configuradas; el error dice cuál falta."),
            ("Ojo", "Reclasificar tercero toca documentos de otros módulos: revisar cartera y CxP después."),
        ],
        accent="#9f1239",
    )

    sketch(
        "conta_libros_sketchnote.jpg", B,
        "Libros e informes: el mismo saldo visto de cinco maneras",
        "Consultas → Balance de Prueba · Libros auxiliares · Estado de resultados · Balance general · Histórico",
        [
            {"num": "1", "tit": "Balance de prueba y auxiliar", "sub": "BALANCE_COL · GENERAR_BALANCE · OBTENER_AUXILIAR", "pal": "sky", "items": [
                ("Balance:", "Saldo inicial, débitos, créditos y saldo final por cuenta, con rango de cuentas, centros y terceros."),
                ("Auxiliar:", "Movimiento por movimiento de una cuenta: comprobante, fecha, tercero, detalle."),
                ("Fotos:", "Tomar foto del mes o del año guarda el balance en TBALANCEH para compararlo después."),
            ]},
            {"num": "2", "tit": "Libros auxiliares (asíncrono)", "sub": "CONTABILIDAD_2 · INICIAR_BUSQUEDA_LIBROS_AUXILIARES", "pal": "orange", "items": [
                ("Cómo:", "Se lanza un trabajo (RPDX2) y la pantalla consulta el estado hasta que termina."),
                ("Salidas:", "Saldo acumulado por cuenta, documento, cuenta/centro/documento, cuenta/tercero/documento; agrupado por centro o tercero."),
                ("Excel:", "Exporta lo generado por el trabajo."),
            ]},
            {"num": "3", "tit": "Estado de resultados y balance general", "sub": "TRAER_DATOS_ER · BALANCE_GENERAL", "pal": "green", "items": [
                ("ER:", "Ingresos, costos y gastos del periodo; comparativo entre periodos; fotos de mes y año."),
                ("Balance general:", "Activo, pasivo y patrimonio al último periodo cerrado o al elegido; PDF."),
                ("Agrupación:", "KPRES define cómo se agrupan cuentas para presentar informes."),
            ]},
            {"num": "4", "tit": "Cartera, bancos y trazabilidad", "sub": "ANALISIS_VENCIMIENTO · SEGUIMIENTO_CARTERA · BANCOS_AUXILIAR", "pal": "violet", "items": [
                ("Vencimientos:", "Cartera por edades, por tercero o cuenta, a un periodo cerrado."),
                ("Seguimiento:", "Saldo contable vs saldo de cartera por tercero; avisa 'existe diferencia entre saldos'."),
                ("Bancos y traza:", "Auxiliar de bancos con conciliación en MCH; trazabilidad de un documento por todos sus comprobantes."),
            ]},
        ],
        pills=[
            ("Regla", "Los informes leen MCP confirmados (estado 2) y no anulados; lo pendiente no suma."),
            ("Regla", "Foliar Libros fija el consecutivo de cada libro oficial (Diario, Mayor, Inventario y Balance…)."),
            ("Ojo", "Una foto borrada no se recupera: Histórico → Eliminar pide confirmación."),
        ],
        accent="#1d4ed8",
    )

    sketch(
        "conta_cierre_sketchnote.jpg", B,
        "Cerrar el periodo: tres pasos y una lista de pendientes",
        "Procesos → Abrir/Cerrar Periodos · Cierre Fiscal",
        [
            {"num": "1", "tit": "Antes de cerrar", "sub": "VALIDAR_PERIODO_BASICO · VALIDAR_INTEGRIDAD_PERIODO", "pal": "sky", "items": [
                ("Básico:", "Existe el periodo, está abierto, el anterior está cerrado (salvo saldos iniciales)."),
                ("Integridad:", "FNK_REVISION_ANTES_CIERRE_PERIODO lista por módulo lo pendiente: inventario sin contabilizar, caja sin cerrar, nómina abierta, CxP, recaudos, bancos."),
                ("Comprobantes:", "Ninguno en estado 0 ó 1 y ninguno en Errados."),
            ]},
            {"num": "2", "tit": "Cerrar", "sub": "EJECUTAR_CIERRE_PERIODO → SPK_CIERRA_PERIODOCONTABLE", "pal": "rose", "items": [
                ("Hace:", "Calcula saldos del mes (SALDOMES, SALDOMESTER) y marca PRI.CERRADO = 1."),
                ("Asíncrono:", "El cierre largo corre como trabajo; la pantalla muestra 'Paso 3/3 cerrando (segundos)'."),
                ("Efecto:", "Nada que mueva saldos se permite en ese mes: ni confirmar, ni reconstruir, ni enviar."),
            ]},
            {"num": "3", "tit": "Abrir", "sub": "EJECUTAR_ABRIR_PERIODO → SPK_ABRE_PERIODOCONTABLE", "pal": "orange", "items": [
                ("Condición:", "No puede haber periodos posteriores cerrados ni ser el periodo de saldos iniciales."),
                ("Hace:", "Borra los saldos del mes y pone CERRADO = 0; opcionalmente anula el traslado de costos."),
                ("Sub-cierres:", "Cartera y CxP tienen su propio abrir/cerrar en la misma pantalla."),
            ]},
            {"num": "4", "tit": "Cierre fiscal", "sub": "CONTABILIDAD · CIERRE_FISCAL", "pal": "green", "items": [
                ("Cuándo:", "Solo el mes definido en Parámetros Contables (PAR.MESDECIERRE), con el anterior cerrado."),
                ("Consultar / Procesar:", "Saldos de cuentas de resultado por clase y nivel (SDCUEFIS)."),
                ("Generar comprobante:", "Cancela ingresos y gastos contra el resultado del ejercicio con el comprobante de cierre elegido."),
            ]},
        ],
        pills=[
            ("Regla", "Cerrar es reversible (Abrir), pero borra y recalcula saldos: hacerlo con criterio."),
            ("Regla", "El cierre fiscal es una vez por año: 'Proceso de generación de comprobante ya realizado'."),
            ("Ojo", "La lista de integridad se exporta a Excel para repartirla a los módulos."),
        ],
        accent="#0f766e",
    )
    print("OK sketchnotes contabilidad en", IMG_DIR)


if __name__ == "__main__":
    main()
