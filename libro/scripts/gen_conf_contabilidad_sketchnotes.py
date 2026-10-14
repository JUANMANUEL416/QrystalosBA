# -*- coding: utf-8 -*-
"""Sketchnotes del proceso Configuración → Contable (menú central Configuración).

Uso:  python libro/scripts/gen_conf_contabilidad_sketchnotes.py
Salida: libro/img/confconta_mapa_sketchnote.jpg, confconta_estructura_sketchnote.jpg,
        confconta_cuentas_sketchnote.jpg, confconta_kmcom_sketchnote.jpg,
        confconta_periodos_sketchnote.jpg, confconta_generales_sketchnote.jpg,
        confconta_orden_sketchnote.jpg

Contrastado 2026-10-04 con Qrystalos2 (ConfLayout.arbolMenu → Contable; pages/conf/Conta/* y
components/conf/Conta/*) y con IXONLINE/SQL (SPQ_CONF_CONTABLE, SPQ_SED, SPQ_CUE_COL, SPQ_CUENIIF,
SPQ_KMCOM_COL, SPQ_KCDE_COL, SPQ_TTEC_COL, SPQ_COM_COL, SPQ_PRI, SPQ_MND_COL, SPQ_MNDV_COL, SPQ_FIMP_COL,
SPQ_FIMPD_COL, SPQ_FIMPDV_COL, SPQ_FCTSER_COL, SPQ_FCTSERD_COL, SPQ_RETEFTE_SALARIO, SPQ_CENH_COL).
PREVERSION idéntica a la última liberada en todos.
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · CONFIGURACIÓN · CONTABLE"


def main():
    sketch(
        "confconta_mapa_sketchnote.jpg", B,
        "El submenú Contable de Configuración: quince opciones en cuatro bloques",
        "Configuración → Contable → Estructura · Plan de cuentas · Reglas de contabilización · Comprobantes y periodos · Generales",
        [
            {"num": "1", "tit": "Estructura", "sub": "Dónde ocurre el gasto", "pal": "sky", "items": [
                ("Sedes:", "Datos legales, facturación, interoperabilidad, consultorios y unidades de negocio por sede."),
                ("Grupos de Áreas y A. Func./C.Costos:", "El árbol grupo → área funcional → centro de costo; homologación entre sedes."),
                ("Unidades Negocio:", "Código, nombre y logo; se cruzan con sede y centro de costo."),
            ]},
            {"num": "2", "tit": "Plan de cuentas", "sub": "Con qué se registra", "pal": "orange", "items": [
                ("Cuentas Contables:", "Plan local (CUE): tipo Suma/Detalle, nivel, cuenta suma, qué detalle exige, impuestos, bancos, homóloga, NIIF."),
                ("Cuentas NIIF:", "Plan NIIF (CUENIIF) con carga masiva desde Excel, genealógico automático y bloqueo si hay movimientos."),
                ("Validar / Exportar:", "Revisión de jerarquía, longitud par y nivel; exportación completa a Excel."),
            ]},
            {"num": "3", "tit": "Reglas de contabilización", "sub": "Cómo se arma el comprobante", "pal": "violet", "items": [
                ("Contabilización por Ubicación (KMCOM):", "Tipo de contabilización + prefijo + centro de costo → cuenta débito y crédito; excepciones por servicio."),
                ("Tipos de Terceros (TTEC):", "Cuentas de cartera, radicación, glosas, difícil cobro, cobro jurídico por tipo de tercero."),
                ("Deducibles (KCDE) y Distribución de Gastos (FDIS):", "Cuentas de deducible y repartos porcentuales por centro de costo."),
            ]},
            {"num": "4", "tit": "Comprobantes, periodos y generales", "sub": "El calendario y las tablas base", "pal": "green", "items": [
                ("Tipos de Comprobantes (COM) y Comprobantes por Documentos:", "El catálogo y qué comprobante usa cada documento (variables IDCON_TCOM_*)."),
                ("Períodos Contables (PRI) y Parámetros Contables (PAR):", "El calendario con sus cierres por módulo; mes de cierre y cuenta puente."),
                ("Generales:", "Monedas y vigencias, Impuestos con divisiones y vigencias, Tipos de servicio, Retención de salarios (UVT)."),
            ]},
        ],
        pills=[
            ("Regla", "Las etiquetas y rutas del árbol están fijas en la aplicación; lo que se habilita por grupo viene del menú de Configuración."),
            ("Regla", "Nada de esto mueve saldos: define cómo los módulos armarán sus comprobantes."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_estructura_sketchnote.jpg", B,
        "La estructura: sede → grupo de área → área funcional → centro de costo",
        "Configuración → Contable → Sedes · Grupos de Áreas · A. Func./C.Costos · Unidades Negocio",
        [
            {"num": "1", "tit": "Sede (SED)", "sub": "La unidad legal y física", "pal": "sky", "items": [
                ("General:", "Código, nombre, dirección, teléfonos, ciudad, responsable, nivel, homólogo, código de habilitación, IDSGSSS."),
                ("Datos legales / Facturación:", "NIT y DV, representante legal, líneas de factura, gran contribuyente, textos legales, logo."),
                ("Interoperabilidad:", "Credenciales del conector externo (client id, secret, scope, subscription key, tenant)."),
                ("Pestañas inferiores:", "Consultorios (SEDCONS) y Unidad de Negocio por sede y centro de costo (SEDUNG). Activar / Inactivar."),
            ]},
            {"num": "2", "tit": "Grupo de área (HARE)", "sub": "La agrupación de arriba", "pal": "orange", "items": [
                ("Id. Area + Descripción:", "Solo código y nombre; es el padre de las áreas funcionales."),
            ]},
            {"num": "3", "tit": "Área funcional (AFU)", "sub": "La unidad de servicio", "pal": "violet", "items": [
                ("Campos:", "Código, descripción, grupo de área, ámbito, tipo de área, estado, marcas En Contabilidad / En Prestaciones."),
                ("Dentro:", "Botón de centros de costo del área; cada centro exige su área."),
            ]},
            {"num": "4", "tit": "Centro de costo (CEN)", "sub": "La unidad contable", "pal": "green", "items": [
                ("Campos:", "Código, descripción, compañía, sede, tipo, nivel, ciudad, triage, en habitaciones, alto costo, homólogo, estado."),
                ("Regla:", "Para inactivar hay que indicar un homólogo activo: ahí seguirán cayendo los movimientos."),
                ("Homologación entre sedes (CENH):", "Botón visible con la variable HOMOLOGA_CCOSTOYSEDE: centro origen → centro destino, sucesor si se inactiva."),
            ]},
        ],
        pills=[
            ("Orden", "Primero la sede y el grupo; después el área; al final los centros de costo y su cruce con unidad de negocio."),
            ("Regla", "No hay borrado de sede, área ni centro: se inactivan."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_cuentas_sketchnote.jpg", B,
        "El plan de cuentas: crear, importar, validar y exportar",
        "Configuración → Contable → Cuentas Contables · Cuentas NIIF",
        [
            {"num": "1", "tit": "Crear o editar (CUE)", "sub": "Nueva Cuenta → Guardar", "pal": "sky", "items": [
                ("Identidad:", "Compañía, cuenta, nombre, tipo Suma/Detalle, nivel, cuenta suma, clase (CXC, CXP, OTROS), corriente, estado."),
                ("Qué detalle exige:", "Detalle x Tercero, x Ccosto, x Referencia; tipo tesorero, caja, cuenta de banco."),
                ("Reglas contables:", "De impuesto, aplica ajuste, cuenta homóloga, cuenta NIIF, concepto acreencia, espejo, reversión, gravada."),
            ]},
            {"num": "2", "tit": "Validar Cuentas", "sub": "Antes de contabilizar", "pal": "orange", "items": [
                ("Jerarquía:", "La cuenta suma debe ser el prefijo de la cuenta y existir como tipo Suma."),
                ("Formato:", "Longitud par a partir del segundo nivel; nivel coherente con los dígitos."),
                ("Salida:", "Lista de cuentas con error exportable a Excel; sin errores = «Cuentas validadas correctamente»."),
            ]},
            {"num": "3", "tit": "Importar / Exportar", "sub": "Excel", "pal": "violet", "items": [
                ("Importar Cuentas:", "Descargar plantilla → llenar → Procesar; cada fila pasa por el mismo guardado que el formulario."),
                ("Exportar a Excel:", "Plan completo con nombres de cuenta suma, homóloga, espejo, cierre de costos, banco y caja."),
            ]},
            {"num": "4", "tit": "Cuentas NIIF (CUENIIF)", "sub": "El segundo plan", "pal": "green", "items": [
                ("Genealógico:", "Al escribir la cuenta el sistema propone nivel y cuenta suma."),
                ("Carga masiva:", "Todo o nada: si una fila falla no se inserta ninguna; errores con solución descargables."),
                ("Bloqueos:", "Con movimientos NIIF no se cambia el código ni se borra: se inactiva."),
            ]},
        ],
        pills=[
            ("Regla", "Una cuenta de un dígito no lleva cuenta suma; las demás sí."),
            ("Regla", "Solo las cuentas tipo Detalle reciben movimiento."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_kmcom_sketchnote.jpg", B,
        "Contabilización por ubicación: la regla que arma cada comprobante",
        "Configuración → Contable → Contabilización por Ubicación (KMCOM / KMCOMS)",
        [
            {"num": "1", "tit": "Elegir el tipo", "sub": "Tarjetas de tipo de contabilización (KTCO)", "pal": "sky", "items": [
                ("Tipos:", "Ventas, Nómina, CxP compras, CxP salud, CxP servicios, Depreciación, Descuentos, Mov. activos, Mov. inventario, Caja menor."),
                ("Niif:", "Los tipos NIIF y Prestaciones solo aparecen si el proceso contable es MIXTO."),
            ]},
            {"num": "2", "tit": "La llave", "sub": "Prefijo + centro de costo", "pal": "orange", "items": [
                ("Prefijo según el tipo:", "Ventas/Salud/Descuentos → prefijo de servicio; Nómina → concepto; Compras → tipo de artículo; Servicios → tipo de servicio; Depreciación → tipo de activo; Mov. activos → evento; Inventario → tipo de movimiento; Caja menor → concepto de caja."),
                ("Centro de costo:", "Debe existir con su área funcional."),
            ]},
            {"num": "3", "tit": "Las cuentas", "sub": "Débito y crédito", "pal": "violet", "items": [
                ("Siempre:", "Cuenta débito y cuenta crédito (tipo Detalle). Ventas además: cuenta IPS, PGP y Cápita con sus cuentas crédito."),
                ("IVA:", "Marca de IVA y cuenta de IVA en la regla."),
                ("Excepciones por servicio (KMCOMS):", "Un servicio puntual con cuentas distintas a las de su prefijo."),
            ]},
            {"num": "4", "tit": "Masivo", "sub": "Plantillas Excel", "pal": "green", "items": [
                ("Plantilla KMCOM / KMCOMS:", "Descargar, llenar con ESTADO ADICIONAR / CAMBIAR / BORRAR, Subir; se valida antes de guardar."),
                ("Exportar Excel:", "La configuración vigente del tipo elegido."),
            ]},
        ],
        pills=[
            ("Regla", "Sin regla para la llave (tipo, prefijo, centro) el documento llega a Comprobantes Errados."),
            ("Regla", "Nómina: el concepto se valida contra el concepto de salario para saber si es egreso."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_periodos_sketchnote.jpg", B,
        "Comprobantes, periodos y parámetros: el calendario contable",
        "Configuración → Contable → Tipos de Comprobantes · Comprobantes por Documentos · Períodos Contables · Parámetros Contables",
        [
            {"num": "1", "tit": "Tipos de Comprobantes (COM)", "sub": "El catálogo", "pal": "sky", "items": [
                ("Campos:", "Compañía, código, nombre, homólogo, comprobante externo."),
            ]},
            {"num": "2", "tit": "Comprobantes por Documentos", "sub": "Qué comprobante usa cada documento", "pal": "orange", "items": [
                ("Lista:", "Variables del sistema de tipo comprobante (IDCON_TCOM_*): factura, caja, CxP, notas, reclasificación, castigo, reversión…"),
                ("Asignar:", "Elegir el comprobante del catálogo; se valida que la variable y el comprobante existan."),
            ]},
            {"num": "3", "tit": "Períodos Contables (PRI)", "sub": "Uno por año-mes", "pal": "violet", "items": [
                ("Campos:", "Año, mes, fechas, nombre, saldo inicial (SI / SI NIIF), tipo de ajuste, cambio final, ajuste inflación."),
                ("Cierres visibles:", "Contabilidad, Facturación, Cartera, Inventario, CxP, Presupuesto, Fiscal, Costos, Impuestos; solo Inventario y Facturación se marcan aquí."),
                ("Reglas:", "Año-mes único; un solo periodo de saldos iniciales; cerrado no se edita."),
            ]},
            {"num": "4", "tit": "Parámetros Contables (PAR)", "sub": "Una fila por compañía", "pal": "green", "items": [
                ("Se guardan:", "Cuenta puente (detalle), mes de cierre, cierre de costos, cierre de impuestos, orden de glosas."),
                ("Pantalla:", "También muestra orden de CxC, CxP, Ingresos y Egresos, pero el guardado no los persiste."),
            ]},
        ],
        pills=[
            ("Regla", "Sin periodo abierto no entra ningún comprobante; sin comprobante asignado el módulo no sabe con qué contabilizar."),
            ("Regla", "El mes de cierre fiscal en Parámetros es el que exige el Cierre Fiscal de Contabilidad."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_generales_sketchnote.jpg", B,
        "Generales: monedas, impuestos, tipos de servicio, terceros y retención",
        "Configuración → Contable → Generales · Tipos de Terceros · Retención Salarios · Deducibles · Distribución de Gastos",
        [
            {"num": "1", "tit": "Monedas (MND / MNDV)", "sub": "Pestaña Monedas", "pal": "sky", "items": [
                ("Moneda:", "Código, descripción, símbolo, codificación."),
                ("Vigencias:", "Fecha y valor de cambio por moneda."),
            ]},
            {"num": "2", "tit": "Impuestos (FIMP / FIMPD / FIMPDV)", "sub": "Pestaña Impuestos", "pal": "orange", "items": [
                ("Impuesto:", "Código, descripción, homólogo DIAN."),
                ("División:", "Clase y base por impuesto; vigencias con fecha inicial/final, valor, rango, UVT, cuenta y cuenta asumida."),
            ]},
            {"num": "3", "tit": "Tipos de servicio y de tercero", "sub": "FCTSER / FCTSERD · TTEC", "pal": "violet", "items": [
                ("Tipo de servicio:", "Cuenta, rubro, UNSPSC, grupo de impuesto, de consumo; servicios detalle con valor, clase de cobro, en brigada."),
                ("Tipo de tercero contable:", "Cuentas de cartera, radicación, glosa DB/CR, glosa recuperada, difícil cobro, cobro jurídico, CREE, estimados."),
            ]},
            {"num": "4", "tit": "Retención, deducibles y repartos", "sub": "RETEI · KCDE · FDIS", "pal": "green", "items": [
                ("Retención Salarios:", "Tipos de retención con clase suma/resta y orden; botón Actualizar UVT (variable del sistema)."),
                ("Deducibles:", "Código, descripción, cuenta, tipo, modelo contable."),
                ("Distribución de Gastos:", "Código y detalle por centro de costo y cuenta con porcentaje; la suma no supera 100 %."),
            ]},
        ],
        pills=[
            ("Aviso", "Retención Honorarios y Dependencias del menú abren la pantalla de Generales sin pestaña activa."),
            ("Regla", "Las vigencias de impuesto son las que usan las notas, la CxP y la liquidación de impuestos."),
        ],
        accent="#36485F",
    )

    sketch(
        "confconta_orden_sketchnote.jpg", B,
        "Orden de implantación: qué configurar primero y quién lo consume",
        "Lista de chequeo para una instalación o una sede nueva",
        [
            {"num": "1", "tit": "Base", "sub": "Sin esto nada abre", "pal": "sky", "items": [
                ("Periodos Contables:", "El año completo con fechas; un solo saldo inicial."),
                ("Tipos de Comprobantes + Comprobantes por Documentos:", "Cada variable IDCON_TCOM_* con su comprobante."),
                ("Parámetros Contables:", "Cuenta puente y mes de cierre."),
            ]},
            {"num": "2", "tit": "Estructura", "sub": "Dónde cae el movimiento", "pal": "orange", "items": [
                ("Sede → Grupo de área → Área funcional → Centro de costo:", "Con unidad de negocio y consultorios."),
                ("Consumidores:", "Facturación, inventario, caja, nómina, activos: todos piden centro de costo y sede."),
            ]},
            {"num": "3", "tit": "Plan de cuentas", "sub": "Con qué se registra", "pal": "violet", "items": [
                ("Cuentas Contables validadas:", "Jerarquía completa, detalle x tercero / ccosto donde aplique, impuestos marcados."),
                ("Cuentas NIIF:", "Si el proceso contable es MIXTO."),
            ]},
            {"num": "4", "tit": "Reglas", "sub": "Cómo se arma el comprobante", "pal": "green", "items": [
                ("Generales:", "Monedas, impuestos con vigencias, tipos de servicio, tipos de tercero, retención."),
                ("Contabilización por Ubicación:", "Un tipo a la vez: Ventas, CxP, Inventario, Nómina, Depreciación…; probar con un documento y revisar Comprobantes Errados."),
            ]},
        ],
        pills=[
            ("Prueba", "Enviar un documento de cada módulo a contabilidad y leer el error en Comprobantes Errados: ahí se ve qué regla falta."),
            ("Regla", "Cambiar una regla no corrige los comprobantes ya generados: hay que reconstruirlos."),
        ],
        accent="#36485F",
    )
    print("OK sketchnotes configuración contable en", IMG_DIR)


if __name__ == "__main__":
    main()
