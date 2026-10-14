# -*- coding: utf-8 -*-
"""Sketchnotes Configuración → Activos F. · Financiero · Sistemas · Generales (Planes/Terceros).

Uso: python libro/scripts/gen_conf_resto_sketchnotes.py
Regla: sin volúmenes ni valores de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch  # noqa: E402

BA = "QRYSTALOS IPS · CONFIGURACIÓN · ACTIVOS F."
BF = "QRYSTALOS IPS · CONFIGURACIÓN · FINANCIERO"
BS = "QRYSTALOS IPS · CONFIGURACIÓN · SISTEMAS"
BG = "QRYSTALOS IPS · CONFIGURACIÓN · GENERALES"


def main():
    sketch(
        "confact_mapa_sketchnote.jpg", BA,
        "El submenú Activos F. de Configuración: siete catálogos y un hueco",
        "Configuración → Activos F. · las mismas pantallas viven también en Activos Fijos → Configuración",
        [
            {"num": "1", "tit": "Activos", "sub": "En construcción", "pal": "rose", "items": [
                ("Menú:", "Abre la página en construcción. El alta y la ficha están en Activos Fijos → Gestión."),
            ]},
            {"num": "2", "tit": "Tipos y eventos", "sub": "Qué se pide y qué se mueve", "pal": "sky", "items": [
                ("Tipos de Activos (IACTT):", "Clase Local/NIIF, campos del alta, vida útil, salvamento, generar depreciación, administrador por tipo."),
                ("Eventos (IACTE):", "Entrada / Salida / Traslado: qué pide, si contabiliza, comprobante, estado asociado, marca de baja."),
            ]},
            {"num": "3", "tit": "Artículos y tipos", "sub": "El catálogo que se capitaliza", "pal": "orange", "items": [
                ("Tipos de Artículos:", "Solo los marcados ESACTIVO: el tipo de inventario que puede ser activo fijo."),
                ("Artículos:", "IART con tipo de activo y fabricante; no es el catálogo completo de Inventario."),
            ]},
            {"num": "4", "tit": "Grupos y sectores", "sub": "Clasificar y notificar", "pal": "green", "items": [
                ("Grupos:", "Tabla general ACTIVOSFIJOS / GRUPOS y subgrupos."),
                ("Equipos por sector / Noti. parada:", "Dotación por habitación-sector y correos de parada."),
            ]},
        ],
        pills=[
            ("Regla", "Configurar tipo → artículo → evento antes del primer alta."),
            ("Ojo", "Inventario → Artículos es otro catálogo: aquí solo los de activo fijo."),
        ],
        accent="#0F766E",
    )

    sketch(
        "confact_tipo_sketchnote.jpg", BA,
        "Tipo de activo: lo que el alta va a exigir y cómo se deprecia",
        "Configuración → Activos F. → Tipos de Activos",
        [
            {"num": "1", "tit": "Identidad", "sub": "IACTT", "pal": "sky", "items": [
                ("Código y descripción:", "Únicos. Clase Local o NIIF."),
                ("Estado:", "Activo / Inactivo. Sin tipo no hay alta."),
            ]},
            {"num": "2", "tit": "Qué pide el formulario", "sub": "Casillas", "pal": "orange", "items": [
                ("Pedir:", "Modelo, escritura, marca, linderos, serial, partes, referencia, matrícula."),
                ("Alta:", "Al elegir el tipo, el formulario consulta qué campos son obligatorios."),
            ]},
            {"num": "3", "tit": "Depreciación del tipo", "sub": "Salvamento y vida útil", "pal": "violet", "items": [
                ("Salvamento:", "Valor o porcentaje; el porcentaje no supera 100."),
                ("Vida útil:", "En meses. Generar Depreciación marca depreciables los activos del tipo y recalcula cuotas."),
            ]},
            {"num": "4", "tit": "Administrador", "sub": "Si la variable lo enciende", "pal": "green", "items": [
                ("Asignar Administrador:", "Visible con TIPO_ACTIVO_USUARIO. Liga empleados al tipo."),
                ("Error:", "«El empleado ya se encuentra asignado»."),
            ]},
        ],
        pills=[
            ("Regla", "Generar Depreciación del tipo no contabiliza: solo arma las cuotas."),
        ],
        accent="#0F766E",
    )

    sketch(
        "confact_evento_sketchnote.jpg", BA,
        "Eventos: entrada, salida y traslado",
        "Configuración → Activos F. → Eventos",
        [
            {"num": "1", "tit": "Tipo de evento", "sub": "IACTE", "pal": "sky", "items": [
                ("Clase:", "Entrada, Salida o Traslado. Código único."),
                ("Pide:", "Al menos una de: estado, valor, centro de costo."),
            ]},
            {"num": "2", "tit": "Contabilidad", "sub": "Si se contabiliza", "pal": "orange", "items": [
                ("Marca:", "Se Contabiliza + comprobante del catálogo COM."),
                ("Baja:", "Si el estado asociado coincide con IACT_ESTADOBAJA, el evento da de baja."),
            ]},
            {"num": "3", "tit": "Dónde se usa", "sub": "Gestión", "pal": "violet", "items": [
                ("Novedad:", "Activos Fijos → Gestión → Eventos. Aquí solo el catálogo."),
                ("Compra:", "El evento de compra (variable) nace al dar de alta."),
            ]},
        ],
        pills=[
            ("Ojo", "Cambiar el evento no reescribe novedades ya aplicadas."),
        ],
        accent="#0F766E",
    )

    sketch(
        "conffin_mapa_sketchnote.jpg", BF,
        "El submenú Financiero: caja, bancos, notas, DIAN y un hueco",
        "Configuración → Financiero",
        [
            {"num": "1", "tit": "Caja", "sub": "Ocho pestañas", "pal": "sky", "items": [
                ("Pestañas:", "Caja, Turnos, Cajeros, Conceptos, Asignación de turnos, Tipos de egreso, Tipos de anticipo."),
                ("Caja:", "Bodega, cuentas, comprobante, tercero, conceptos y formas de pago por caja."),
            ]},
            {"num": "2", "tit": "Bancos y formas", "sub": "El dinero que entra y sale", "pal": "orange", "items": [
                ("Bancos:", "Banco (tercero categoría banco) + sucursales."),
                ("Formas de pago:", "Código, cuenta, comprobante. Las usa caja y recaudos."),
                ("Operaciones financieras:", "Tipo de movimiento bancario con cuenta y comprobante."),
            ]},
            {"num": "3", "tit": "Notas y funcionarios", "sub": "Cartera y CxP", "pal": "violet", "items": [
                ("Conceptos de notas / Tipos ND-NC:", "Cuentas y homologación DIAN. Las consume Notas débito/crédito."),
                ("Funcionarios:", "Tercero de oficina ligado al usuario que autoriza."),
            ]},
            {"num": "4", "tit": "DIAN y firma", "sub": "Factura electrónica", "pal": "green", "items": [
                ("Resolución DIAN:", "Rangos por sede, vigencia, facturador electrónico."),
                ("Firma digital:", "Certificado, vencimiento y aviso de días."),
                ("Parámetros Financieros:", "En construcción. Las reglas viven en Variables del Sistema."),
            ]},
        ],
        pills=[
            ("Regla", "Caja de Configuración no abre ni cierra turno: eso es el módulo Caja."),
            ("Ojo", "Hay una ruta legacy de caja (conf.caj) distinta de esta pantalla de ocho pestañas."),
        ],
        accent="#B45309",
    )

    sketch(
        "conffin_caja_sketchnote.jpg", BF,
        "Configurar una caja: de la ficha a los turnos y conceptos",
        "Configuración → Financiero → Caja",
        [
            {"num": "1", "tit": "Ficha de caja", "sub": "CAJ", "pal": "sky", "items": [
                ("Identidad:", "Código, nombre, estado, bodega, cuentas (caja y CxP), comprobante, tercero."),
                ("Por caja:", "Tipos de egreso y formas de pago permitidos (tabla general)."),
            ]},
            {"num": "2", "tit": "Turnos y cajeros", "sub": "TUR · CJR · CXT", "pal": "orange", "items": [
                ("Turnos:", "Horario de la caja."),
                ("Cajeros:", "Usuarios que pueden abrir."),
                ("Asignación:", "Qué cajero en qué turno."),
            ]},
            {"num": "3", "tit": "Conceptos y anticipos", "sub": "CPCJ · CJTE · TANT", "pal": "violet", "items": [
                ("Conceptos:", "Ingreso / egreso / caja menor: la regla KMCOM CAJA_MENOR usa estos."),
                ("Tipos de egreso y anticipo:", "Clases que el cajero elige al registrar."),
            ]},
        ],
        pills=[
            ("Orden", "Caja → conceptos → turnos → cajeros → asignación. Después se abre el turno en el módulo Caja."),
        ],
        accent="#B45309",
    )

    sketch(
        "conffin_dian_sketchnote.jpg", BF,
        "Resolución DIAN y certificado de firma",
        "Configuración → Financiero → Resolución DIAN · Gestión de Firma Digital",
        [
            {"num": "1", "tit": "Resolución", "sub": "FDIAN", "pal": "sky", "items": [
                ("Por sede:", "Prefijo, rango inicial-final, vigencia, tipo (factura, nota, POS)."),
                ("Facturador electrónico:", "Datos de contacto y software (TGEN)."),
            ]},
            {"num": "2", "tit": "Candados", "sub": "Variables", "pal": "orange", "items": [
                ("POS:", "Si FACTURAPOS_ACTIVA no está encendida, no se crea resolución POS."),
                ("País:", "IXCOUNTRY cambia el juego de procedencias (Colombia / Perú)."),
            ]},
            {"num": "3", "tit": "Certificado", "sub": "FDIANCER", "pal": "green", "items": [
                ("Alta:", "Archivo, clave, fechas. El color avisa según DIASNOTIFICACERT."),
                ("Uso:", "La factura electrónica toma el certificado vigente (variable DIANCERTIFICADO)."),
            ]},
        ],
        pills=[
            ("Regla", "La factura final debe ser mayor que la inicial. Sin resolución vigente no hay envío DIAN."),
        ],
        accent="#B45309",
    )

    sketch(
        "confsis_mapa_sketchnote.jpg", BS,
        "El submenú Sistemas: lo que sí está y lo que está en construcción",
        "Configuración → Sistemas",
        [
            {"num": "1", "tit": "Catálogos vivos", "sub": "Lo que se configura aquí", "pal": "sky", "items": [
                ("Variables del Sistema (USVGS):", "El valor (DATO) de cada variable. No se crea la variable: se edita."),
                ("Tabla Genérica (TGEN):", "Listas del sistema (estados, homologaciones, grupos) + opciones libres."),
                ("Defaults (USDEF):", "Valor por defecto e obligatoriedad de un campo al crear un registro."),
            ]},
            {"num": "2", "tit": "Seguridad", "sub": "Quién entra y qué ve", "pal": "orange", "items": [
                ("Grupos:", "Permisos (USGRUH), usuarios del grupo, prefijos y administradoras."),
                ("Usuarios:", "Ficha, clave, foto/firma, equipo, bodegas, plantillas, MFA, lista blanca IP."),
                ("Permisos especiales:", "Excepción temporal por usuario (PERMESP)."),
            ]},
            {"num": "3", "tit": "Estaciones y logs", "sub": "Equipo y rastro", "pal": "violet", "items": [
                ("Ubicaciones físicas (UBEQ):", "El equipo de la estación: sede, área, caja, bodegas."),
                ("Logs:", "Auditoría (USLOG), cambios de variables (KLOG), mensajes, accesos (ULOGIN)."),
            ]},
            {"num": "4", "tit": "En construcción", "sub": "Sin pantalla", "pal": "rose", "items": [
                ("Huecos:", "Contadores, Reportes con formato, Noticias, Procedimientos y Controles, Seguridad por tabla, Impresoras, Correcciones, Objetos del sistema."),
                ("Dónde sí:", "Los procedimientos se asignan desde Grupos → Seguridad."),
            ]},
        ],
        pills=[
            ("Regla", "El menú Configuración se habilita por grupo. Quien entra a la opción puede editar (salvo Planes y Terceros, que sí tienen permisos por botón)."),
        ],
        accent="#4338CA",
    )

    sketch(
        "confsis_seguridad_sketchnote.jpg", BS,
        "Grupos y usuarios: el candado del sistema",
        "Configuración → Sistemas → Seguridad",
        [
            {"num": "1", "tit": "Grupo", "sub": "USGRU", "pal": "sky", "items": [
                ("Alta:", "Código y nombre. Expandir: Seguridad, Usuarios, Prefijos, Administradoras."),
                ("Permisos:", "Uno a uno, masivos, clonar o eliminar todos (USGRUH)."),
            ]},
            {"num": "2", "tit": "Usuario", "sub": "USUSU", "pal": "orange", "items": [
                ("Ficha:", "Login, grupo, sede, médico, cajero, equipo (UBEQ obligatorio), foto y firma."),
                ("Clave:", "DATACLAVE al guardar; Reiniciar clave web; desbloqueo y MFA por API."),
            ]},
            {"num": "3", "tit": "Extras", "sub": "Por variable", "pal": "violet", "items": [
                ("Plantillas:", "Si IMPRIMIRMPLXUSUARIO = SI."),
                ("Lista blanca IP:", "TGEN WEB / IPPERMITIDA; o marcar Cualquier IP."),
                ("Permiso especial:", "Ventana aparte: tipo + usuario + vigencia."),
            ]},
        ],
        pills=[
            ("Ojo", "Procedimientos y Controles no tiene pantalla: el catálogo USPROH se asigna dentro del grupo."),
        ],
        accent="#4338CA",
    )

    sketch(
        "confsis_usvgs_sketchnote.jpg", BS,
        "Variables y tabla genérica: el interruptor de cada módulo",
        "Configuración → Sistemas → Variables del Sistema · Tabla Genérica",
        [
            {"num": "1", "tit": "Variable", "sub": "USVGS", "pal": "sky", "items": [
                ("Se edita:", "DATO y descripción. El código, el tipo y la observación no se cambian aquí."),
                ("Referencia:", "Si apunta a una tabla, el DATO es un código de esa tabla (COM, TER…)."),
            ]},
            {"num": "2", "tit": "Tabla genérica", "sub": "TGEN", "pal": "orange", "items": [
                ("Llave:", "Tabla + Campo + Código. Filtros por tabla y campo."),
                ("Opciones libres:", "TGENOP: listas que un formulario ofrece al usuario."),
            ]},
            {"num": "3", "tit": "Rastro", "sub": "KLOG", "pal": "green", "items": [
                ("Log de variables:", "Quién cambió qué valor y cuándo. Solo lectura + Excel."),
            ]},
        ],
        pills=[
            ("Regla", "No publicar en el manual el DATO de una instalación: cada cliente tiene el suyo."),
        ],
        accent="#4338CA",
    )

    sketch(
        "confgen_mapa_sketchnote.jpg", BG,
        "Planes, contratos y terceros: quién paga y con qué plan",
        "Configuración → Generales → Planes · Contratos IPS · Terceros",
        [
            {"num": "1", "tit": "Categorías", "sub": "CAT", "pal": "sky", "items": [
                ("Maestro:", "Código y descripción (CON contratante, PRO proveedor, OFI oficina…)."),
            ]},
            {"num": "2", "tit": "Terceros", "sub": "TER + TEXCA", "pal": "orange", "items": [
                ("Ficha:", "NIT, razón social o nombres, fiscal, RL, talento humano, bancos."),
                ("Categorías del tercero:", "Un tercero puede tener varias. CON abre contrataciones (PPT); PRO abre impuestos y condiciones de pago."),
            ]},
            {"num": "3", "tit": "Planes", "sub": "PLN + CPPAF", "pal": "violet", "items": [
                ("Plan:", "Código ≤ 6, régimen, tipo de sistema, cobertura, carné, paquete, crónico."),
                ("Servicios del plan:", "Por área: quién cobra (origen o contratante), autorización, patología."),
            ]},
            {"num": "4", "tit": "Contrato IPS", "sub": "CNT + CNTD", "pal": "green", "items": [
                ("Cabecera:", "Tercero CON + plan en PPT + vigencia + tipo + valor + tarifa."),
                ("Detalle:", "Tope por prefijo/grupo. Activar / Suspender / Finalizar."),
            ]},
        ],
        pills=[
            ("Orden", "Categoría → tercero → categoría CON → PPT (plan de la administradora) → contrato → servicios del plan."),
            ("Ojo", "Tipos de Terceros del menú Contable (TTEC) son cuentas de cartera, no este catálogo."),
        ],
        accent="#0369A1",
    )

    sketch(
        "confgen_planes_sketchnote.jpg", BG,
        "El plan: crear, cargar servicios y copiar",
        "Configuración → Generales → Planes  ·  permisos MENUQ_PLANES",
        [
            {"num": "1", "tit": "Crear el plan", "sub": "CONF_PLANES · GUARDAR", "pal": "sky", "items": [
                ("Campos:", "Id (≤6), nombre, estado, tipo de sistema, aseguramiento, régimen, cobertura, carné, paquete + servicio, crónico."),
                ("Candado:", "La cobertura debe coincidir con el tipo de sistema."),
            ]},
            {"num": "2", "tit": "Servicios (CPPAF)", "sub": "Uno a uno o masivo", "pal": "orange", "items": [
                ("Fila:", "Área + servicio + cobra origen/contratante; si contratante: tercero CON y plan CA."),
                ("Masivo:", "Importar servicios, subir plano, agregar prefijo, quitar por área, varios planes."),
            ]},
            {"num": "3", "tit": "Copiar", "sub": "Dos botones", "pal": "violet", "items": [
                ("Copiar contrato:", "Lleva servicios de un plan a otro (parcial)."),
                ("Copiar idéntica:", "Réplica completa. Exige permiso propio."),
            ]},
            {"num": "4", "tit": "Unidades", "sub": "PLNU", "pal": "green", "items": [
                ("Unidad de atención:", "Dónde se presta el plan (roles / sedes del plan)."),
            ]},
        ],
        pills=[
            ("PREVERSION", "SPQ_CONF_PLANES en la canasta abierta ya difiere de la última liberada: validar ahí antes de pedir un arreglo."),
        ],
        accent="#0369A1",
    )

    sketch(
        "confgen_terceros_sketchnote.jpg", BG,
        "El tercero: ficha, categorías y lo que se abre después",
        "Configuración → Generales → Terceros  ·  permisos TERCEROS_WEB",
        [
            {"num": "1", "tit": "Alta / Excel", "sub": "TER_COL · GUARDAR", "pal": "sky", "items": [
                ("Generales:", "Régimen, naturaleza, NIT+DV, nombres o razón social, contacto, fiscal, actividad."),
                ("Excel:", "Fila a fila; NIT duplicado en archivo o en base se rechaza."),
            ]},
            {"num": "2", "tit": "Categorías", "sub": "TEXCA", "pal": "orange", "items": [
                ("Asignar:", "Una o varias del maestro CAT. Estado Activo/Inactivo por categoría."),
                ("CON:", "Abre contrataciones de administradora (PPT) y el combo de Contratos IPS."),
                ("PRO:", "Exige condición de pago (contado / crédito 30-60-90) e impuestos."),
            ]},
            {"num": "3", "tit": "Acciones de la fila", "sub": "Permiso por botón", "pal": "violet", "items": [
                ("Editar / Inactivar:", "EDITAR_TERCERO, INACTIVAR_TERCERO."),
                ("Documentos, rete salario, límite de citas, contingencias:", "Cada una con su control. Contingencias solo si la variable lo enciende."),
            ]},
        ],
        pills=[
            ("Regla", "Sin categoría CON el tercero no aparece como contratante del contrato IPS."),
        ],
        accent="#0369A1",
    )

    print("OK sketchnotes config resto en", os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "img")


if __name__ == "__main__":
    main()
