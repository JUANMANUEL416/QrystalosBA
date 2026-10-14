# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) de los dos libros de Nómina.

Uso:  python libro/scripts/gen_nomina_sketchnotes.py
Salida:
  libro/img/nomconf_*_sketchnote.jpg  → Nómina · Conceptos y novedades (configuración)
  libro/img/nomliq_*_sketchnote.jpg   → Nómina · Liquidación y procesos

Contenido contrastado 2026-10-03 con Qrystalos2 (pages/nom/conf/indexPage, components/nomina/configuracion/*,
prenomina/*, liquidacion/LiquidaNomComponent, prestaciones/*, cuotas/CuotasComponent, vacaciones/*,
adelantoCesantias/*, prestaSociales/*, dian/DianNominaComponent, Certificados/*) e IXONLINE/SQL
(SPQ_NOM_CONCEPTOS, SPQ_NOM_NCOND*, SPQ_NOM_NOVEDADES, SPQ_NOM_NEVED, SPQ_NOM_NPLT, SPQ_NOM_NOMI, SPQ_NOM_NPER,
SPQ_NOM_NCARNG, SPQ_NOM_AGRUPACIONES, SPQ_NOM_RETTER/RETUVT, SPQ_NOM_NEMPHIS, FNK_INFO_NEMPHIS_NEMP,
SPK_ADDDEL_CONCEPTOS_DE_CARGOS_NUMDOC, FNK_VALORCONCEPTO_NEMPFD_RUN, SPK_CALCULAR_RETIROS, SPK_CALCULA_REFTE_NOMI,
SPQ_NOM_PRESTACIONES, SPQ_NOM_PRS/PRSD, SPK_GENERA_CUOTAS, SPQ_NOM_VACACIONES, SPQ_NOM_ADELANTO_CESANTIAS,
SPQ_LIQUIDACION, SPQ_LIQUIDAR_NOMI, SPQ_CERRAR_NOMI, SPQ_ABRIR_NOMI, SPQ_NC_CONTAB_NOMINA, SPQ_NIEPER,
SPQ_NOM_DIAN, SPQ_RPT_NOMINA). PREVERSION idéntica a la liberada 2.0.7.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

BRAND_CONF = "QRYSTALOS IPS · NÓMINA · CONCEPTOS Y NOVEDADES"
BRAND_LIQ = "QRYSTALOS IPS · NÓMINA · LIQUIDACIÓN Y PROCESOS"


def conf():
    B = BRAND_CONF

    sketch(
        "nomconf_que_es_sketchnote.jpg", B,
        "Qué se configura en Nómina y en qué orden",
        "Todo lo que la prenómina necesita leer antes de calcular un solo peso",
        [
            {"num": "1", "tit": "Estructura", "sub": "Nóminas, períodos, cargos", "pal": "sky", "items": [
                ("Nómina:", "Grupo de empleados que se liquida junto (NOMI): plantilla, centro de costo, área, % máximo a deducir, reporta DIAN."),
                ("Período:", "El mes o rango que se paga (NPER / CNSPAGO): año, mes, periodicidad, fechas, Generado y Cerrado."),
                ("Cargo:", "Cargo + nivel + grado con básico, días, horas y días de vacaciones. Con histórico salarial por fecha."),
                ("Plantilla:", "Lista de cargos y de conceptos que se cargan al abrir la prenómina."),
            ]},
            {"num": "2", "tit": "Conceptos", "sub": "Lo que se paga o descuenta", "pal": "orange", "items": [
                ("Maestro:", "Código, descripción, Ingreso/Egreso, clase (Normal, Aporte, Parafiscal, Familiares, Préstamo, Particular, Provisión, Manual, Tabla)."),
                ("Definición:", "Vigencias con base, valor o %, frecuencia, validaciones y destino. Varias por concepto, manda la última a la fecha."),
                ("Reglas finas:", "Condiciones, fórmulas, conceptos por base, tablas de valores, asociaciones, salario básico."),
                ("Colilla:", "Nombre alterno por fecha para conceptos Manual / Particular."),
            ]},
            {"num": "3", "tit": "Novedades y datos", "sub": "Eventos, parámetros, agrupaciones", "pal": "green", "items": [
                ("Evento (NEVE):", "Qué le pasa al empleado: incapacidad, hora extra, retiro… Apunta al concepto que paga o descuenta."),
                ("Parámetro:", "Valor con vigencia que una condición puede leer (SMMLV, auxilio, tope)."),
                ("Agrupación:", "EPS, fondo, ARL, caja: tercero y % empleado/empresa por vigencia. El concepto apunta aquí."),
                ("Retención:", "Terceros sujetos, tabla UVT y conceptos base de retefuente."),
            ]},
            {"num": "4", "tit": "El empleado", "sub": "Lo individual", "pal": "violet", "items": [
                ("Histórico:", "Cargo, básico, área y centro de costo a una fecha. La prenómina lee el vigente al cierre del período."),
                ("Asignación:", "A qué nómina pertenece (NOMIE). Sin eso no entra a la prenómina."),
                ("Excepciones:", "Conceptos que no se le liquidan, conceptos particulares con valor y vigencia, aportes (EPS/fondo/ARL)."),
                ("Contratos y planta:", "Contrato laboral y distribución por centros de costo para contabilizar."),
            ]},
        ],
        pills=[
            ("Ruta", "Menú central → RRHH → Configuraciones avanzadas (/nom.config). Cada pestaña tiene su permiso MENUQ_NOMINA · nom_*."),
            ("Orden sugerido", "Agrupaciones → Parámetros → Conceptos → Novedades → Cargos → Plantillas → Nóminas → Períodos → Empleados → Retención."),
            ("Nada se calcula aquí", "Esta pantalla solo define reglas. El valor sale en Procesos nómina → Prenómina (otro libro)."),
            ("Fechas mandan", "Definición de concepto, histórico de empleado, salario del cargo, parámetro y agrupación: siempre se toma la vigente a la fecha fin del período."),
        ],
        accent="#4f46e5",
    )

    sketch(
        "nomconf_nominas_periodos_sketchnote.jpg", B,
        "Nóminas, periodicidad y períodos de pago",
        "La nómina agrupa empleados; el período dice qué mes se paga y si ya está cerrado",
        [
            {"num": "1", "tit": "Nómina (NOMI)", "sub": "Pestaña Nominas", "pal": "sky", "items": [
                ("Datos:", "Código, descripción, plantilla, centro de costo, área, % máximo a deducir (tope de egresos), ¿Se reporta en la DIAN?"),
                ("Asignar:", "Botón Asignar: marca qué empleados pertenecen (NOMIE). Un empleado puede estar en varias nóminas."),
                ("Tope:", "El % máximo a deducir frena egresos en prenómina: la línea queda Liquidar = No."),
                ("Regla:", "Código de nómina único; no se elimina desde la pantalla."),
            ]},
            {"num": "2", "tit": "Periodicidad (NPPAG)", "sub": "Botón Nuevo en Períodos", "pal": "orange", "items": [
                ("Tipos:", "Semanal, decenal, catorcenal, quincenal, mensual, otro."),
                ("Horas y días:", "Horas de labor y días del período: base de horas laboradas y de prorrateos."),
                ("Uso:", "Cada período elige su periodicidad (CODPPAG)."),
            ]},
            {"num": "3", "tit": "Período (NPER)", "sub": "Pestaña Períodos", "pal": "green", "items": [
                ("Clave:", "Consecutivo CNSPAGO, nómina, año, mes, periodicidad, fecha inicial y final."),
                ("Tipo liquidación:", "Por Nómina (novedades del mismo período) o Por Rango de Fechas (novedades por solapamiento de fechas)."),
                ("Un mes, un período:", "Si la variable REPITE_NPER_NOMINA = NO, no se repite año/mes en la misma nómina."),
                ("Marcas:", "Generado (ya se liquidó) y Cerrado (ya no se toca). Cerrado bloquea editar."),
            ]},
            {"num": "4", "tit": "Borrar y permisos", "sub": "Cuándo no deja", "pal": "rose", "items": [
                ("No se borra si:", "Tiene novedades en prenómina o ya tiene una generación (NIEPE)."),
                ("Permisos:", "EDITAR_NPER y ELIMINAR_NPER por USGRUH además de nom_periodos."),
                ("Filtro:", "Abierto / Cerrado / Todos."),
                ("Siguiente:", "Con el período abierto se entra a Procesos nómina → Prenómina."),
            ]},
        ],
        accent="#0284c7",
    )

    sketch(
        "nomconf_cargos_sketchnote.jpg", B,
        "Cargos, salario por fecha y conceptos exceptuados",
        "El cargo trae el básico; el histórico salarial dice desde cuándo",
        [
            {"num": "1", "tit": "Área / cargo (NCAR)", "sub": "Nuevo Cargo", "pal": "sky", "items": [
                ("Datos:", "Código, descripción, ¿Alto riesgo (Dec. 2090 de 2003)?"),
                ("Rol:", "Agrupa los cargos con nivel y grado."),
            ]},
            {"num": "2", "tit": "Cargo + nivel + grado (NCARNG)", "sub": "Nuevo Salario", "pal": "orange", "items": [
                ("Datos:", "Nivel, grado, básico, días a trabajar, horas a laborar, Nro. vacaciones, fecha, plantillas."),
                ("Único:", "No se repite cargo + nivel + grado."),
                ("Vacaciones:", "Nro. vacaciones alimenta los días por año del empleado (NEMPV)."),
                ("Plantillas:", "Al guardar se vincula a las plantillas elegidas (NPLTCA)."),
            ]},
            {"num": "3", "tit": "Histórico salarial (NCARNGV)", "sub": "Básico por fecha", "pal": "green", "items": [
                ("Qué guarda:", "Básico, días y horas con fecha de vigencia. Una fila por fecha."),
                ("Regla:", "No dos valores para la misma fecha."),
                ("Ajuste salarial:", "RRHH → Ajustes de salario aplica un % o valor a varios cargos y crea la vigencia; se anula si no hay nóminas posteriores."),
            ]},
            {"num": "4", "tit": "Conceptos exceptuados (NCARNGE)", "sub": "Botón Conceptos Exceptos", "pal": "rose", "items": [
                ("Qué hace:", "Un concepto de la plantilla que NO se liquida a ese cargo."),
                ("Motor:", "La prenómina lo salta aunque esté en la plantilla."),
                ("Borrar cargo:", "No deja si hay planta (NPLA) o histórico de empleados (NEMPHIS) que lo usen."),
            ]},
        ],
        accent="#ea580c",
    )

    sketch(
        "nomconf_plantillas_sketchnote.jpg", B,
        "Plantillas: qué cargos y qué conceptos entran a la prenómina",
        "La plantilla es la lista de compras del período",
        [
            {"num": "1", "tit": "Plantilla (NPLT)", "sub": "Pestaña Plantillas", "pal": "sky", "items": [
                ("Datos:", "Id, descripción, estado Activa/Inactiva."),
                ("Dónde se usa:", "La nómina (NOMI) tiene una plantilla; el cargo (NCARNG) también."),
            ]},
            {"num": "2", "tit": "Cargos (NPLTCA)", "sub": "Botón Cargos", "pal": "orange", "items": [
                ("Qué:", "Marque los cargos que pertenecen. Toggle Ver seleccionados."),
                ("Efecto:", "Solo empleados con cargo en la plantilla se cargan al Gestionar prenómina."),
            ]},
            {"num": "3", "tit": "Conceptos (NPLTCO)", "sub": "Botón Conceptos", "pal": "green", "items": [
                ("Qué:", "Marque los conceptos que se calculan automáticamente a todos."),
                ("Orden:", "Primero ingresos, luego egresos (por prioridad del concepto)."),
                ("Lo que no está:", "Un concepto fuera de la plantilla solo entra como particular del empleado, novedad o manual."),
            ]},
            {"num": "4", "tit": "En prenómina", "sub": "Lectura", "pal": "violet", "items": [
                ("Gestionar prenómina:", "Trae la plantilla a una tabla de trabajo (RPDX) y deja quitar o agregar antes de calcular."),
                ("Recalcular:", "Vuelve a leer la plantilla vigente para ese empleado."),
            ]},
        ],
        accent="#16a34a",
    )

    sketch(
        "nomconf_concepto_sketchnote.jpg", B,
        "El concepto: maestro y sus nueve clases",
        "Primero qué es (maestro NCON); después cómo se calcula (definición NCOND)",
        [
            {"num": "1", "tit": "Identidad", "sub": "Pestaña Conceptos → Nuevo", "pal": "sky", "items": [
                ("Código y descripción:", "El código no se repite y es el que viaja a nómina, colilla y contabilidad."),
                ("Tipo:", "Ingreso (suma al empleado) o Egreso (resta)."),
                ("Prioridad:", "Orden de cálculo dentro de su tipo. Lo que depende de otro va después."),
                ("Tipo prestación:", "Legales, Extralegales, No aplica."),
            ]},
            {"num": "2", "tit": "Clase", "sub": "Cómo se comporta", "pal": "orange", "items": [
                ("Normal:", "Se calcula con base y % o valor."),
                ("Aporte / Parafiscal:", "Va a un tercero (EPS, fondo, ARL, caja). Lleva valor empleado y valor empresa."),
                ("Préstamo:", "Descuenta la cuota de una libranza (base Cuota)."),
                ("Particular / Manual:", "Valor propio del empleado (con vigencia) o digitado en el período."),
                ("Provisión:", "Reserva mensual de prima, cesantías, intereses, vacaciones."),
                ("Tabla / Familiares:", "Valor por rangos (tabla de valores) o por hijos."),
            ]},
            {"num": "3", "tit": "Opciones", "sub": "Casillas", "pal": "green", "items": [
                ("¿Informativo?", "Se calcula pero no suma al neto."),
                ("¿Se imprime?", "Aparece o no en la colilla."),
                ("¿Valor 100 %?", "Guarda también el valor sin prorratear."),
                ("¿Se repite?", "Una línea por cada novedad del concepto (horas extra) en vez de sumar."),
                ("Mostrar cantidad:", "No / Días / Horas / Cuota / Detalle en la colilla."),
            ]},
            {"num": "4", "tit": "Fuera del cálculo", "sub": "Pero obligatorio", "pal": "violet", "items": [
                ("Clasificación DIAN:", "Código del anexo técnico de nómina electrónica. Sin él, el XML se rechaza."),
                ("Estado:", "Activar / Inactivar sin borrar. Eliminar solo si nada lo usa."),
                ("Tabla de valores:", "Botón para crear tablas con vigencias y rangos (NCONT)."),
                ("Nombre en colilla:", "Alias por fecha para Manual / Particular (permiso BtnNombreColilla)."),
            ]},
        ],
        accent="#d97706",
    )

    sketch(
        "nomconf_definicion_sketchnote.jpg", B,
        "Definición del concepto (vigencia): base, valor, validaciones y destino",
        "Nuevo Detalle sobre el concepto. Cada fila es una vigencia desde una fecha",
        [
            {"num": "1", "tit": "Generales", "sub": "Pestaña Generales", "pal": "sky", "items": [
                ("Fecha inicial:", "Desde cuándo rige. La prenómina toma la última vigencia anterior al fin del período."),
                ("Valor:", "Valor empleado y valor empresa; Tipo cálculo Porcentaje o Valor."),
                ("Base:", "Laborado, Básico, Salario neto, Base prestaciones, Conceptos, Cuota, Fórmula, Promedio."),
                ("Destino:", "Agrupación (CODPRF) a la que va el dinero y tercero por defecto. Recobro y destino del recobro."),
            ]},
            {"num": "2", "tit": "Marcas", "sub": "Sí / No", "pal": "orange", "items": [
                ("Base prestación:", "Suma a la base de prima, cesantías y vacaciones."),
                ("Base retención:", "Entra al cálculo de retefuente."),
                ("Genera CxP:", "Al liquidar crea cuenta por pagar al tercero (No para provisiones)."),
                ("Redondeo:", "Decimales, unidad, decena, centena (aportes PILA), unidad de mil."),
                ("Permitir deducciones:", "Si se marca, no se bloquea por el % máximo a deducir."),
            ]},
            {"num": "3", "tit": "Validaciones", "sub": "Cuándo sí se liquida", "pal": "green", "items": [
                ("Fecha ingreso:", "Solo si el ingreso es >, <, = a una fecha."),
                ("Antigüedad:", "Solo si lleva más/menos de N días/meses/años."),
                ("Tiempo laborado:", "Solo si trabajó más/menos de N horas en el período."),
                ("Frecuencia:", "Siempre, Periódica (cada N días/meses/años desde ingreso o fecha base) o Una vez."),
            ]},
            {"num": "4", "tit": "Pestañas extra", "sub": "Según base y clase", "pal": "violet", "items": [
                ("Condiciones:", "Dependencias que ajustan la base (parámetro, concepto); Evaluar: Resultado, Base, Básico."),
                ("Conceptos por base:", "Si Base = Conceptos: qué conceptos se suman."),
                ("Fórmulas:", "Si Base = Fórmula: operandos, operación, factor, prioridad."),
                ("Tabla:", "Si clase Tabla: qué se valida (base, básico, edad, antigüedad, horas) y los conceptos de la tabla."),
                ("Asociaciones / Salario básico:", "Conceptos que una provisión paga; reglas de básico por días."),
            ]},
        ],
        pills=[
            ("Liquidar x día", "Campo Días: prorratea el valor por días del período."),
            ("Formulario único", "Generar novedad FU + código: alimenta el Formulario Único de afiliación."),
            ("Rubro", "Solo si presupuesto está activo (PRESUP_CXP_ACTIVADO)."),
            ("Sin definición", "Un concepto sin vigencia vigente no se calcula: queda en cero con detalle explicativo."),
        ],
        accent="#7c3aed",
    )

    sketch(
        "nomconf_bases_sketchnote.jpg", B,
        "Las ocho bases y las tablas que las acompañan",
        "La base dice sobre qué se aplica el % o el valor",
        [
            {"num": "1", "tit": "Bases de tiempo", "sub": "Laborado · Básico", "pal": "sky", "items": [
                ("Laborado:", "Básico del cargo × horas realmente laboradas (resta novedades que afectan horas, ingreso o retiro a mitad de mes)."),
                ("Básico:", "Salario del cargo completo, sin descontar tiempo."),
                ("Promedio:", "Promedio de períodos anteriores (variable NROPERIODOS_SALAPROM)."),
            ]},
            {"num": "2", "tit": "Bases acumuladas", "sub": "Neto · Prestaciones · Conceptos", "pal": "orange", "items": [
                ("Salario neto:", "Ingresos menos egresos ya calculados del período."),
                ("Base prestaciones:", "Suma de los conceptos marcados Base prestación."),
                ("Conceptos:", "Suma de la lista Conceptos por base (NCONDC). Si Concepto liquidado está marcado, solo cuenta si ya se calculó."),
            ]},
            {"num": "3", "tit": "Bases especiales", "sub": "Cuota · Fórmula · Tabla", "pal": "green", "items": [
                ("Cuota:", "Lee la cuota PorPagar de la libranza del empleado en las fechas del período."),
                ("Fórmula:", "Operandos (otros conceptos) con +, −, ×, ÷ y factor, en orden de prioridad."),
                ("Tabla de valores (NCONT):", "Rangos valor inicial / % / valor a aplicar con vigencia. Se valida contra base, básico, edad, antigüedad u horas."),
            ]},
            {"num": "4", "tit": "Reglas de apoyo", "sub": "Condiciones · Asociaciones · Básico", "pal": "violet", "items": [
                ("Condición (NCONDD):", "Dependencia tipo Parámetro o Concepto con factor, factor máximo y operación. Evaluar sobre Resultado, Base o Básico."),
                ("Asociación (NCONDA):", "Para provisiones: los conceptos que esa prestación paga (los que se restan al pagar la prima)."),
                ("Salario básico (NCONDB):", "Reglas por rango de días con operación y parámetro."),
                ("Parámetro (NPAR/NPARV):", "Valor con fecha inicial y final; la condición lee el vigente."),
            ]},
        ],
        accent="#0891b2",
    )

    sketch(
        "nomconf_novedades_sketchnote.jpg", B,
        "Eventos de novedad: qué le pasa al empleado y qué concepto lo paga",
        "El evento (NEVE) es el catálogo; la novedad del período (NEDIA) se registra en prenómina",
        [
            {"num": "1", "tit": "Evento (NEVE)", "sub": "Pestaña Novedades → Nuevo", "pal": "sky", "items": [
                ("Datos:", "Id evento, descripción, concepto que paga o descuenta."),
                ("Tipo novedad:", "Días, Horas o Minutos: cómo se registra la cantidad."),
                ("Afecta horas:", "No afecta / Resta horas laboradas (incapacidad, licencia)."),
                ("Días calendario:", "Cuenta sábados, domingos y festivos."),
            ]},
            {"num": "2", "tit": "Marcas", "sub": "Casillas", "pal": "orange", "items": [
                ("Evento secundario:", "Tras N días genera otro evento (incapacidad > 2 días pasa a EPS)."),
                ("Se muestra en masivo:", "Aparece en la carga masiva de novedades."),
                ("Solicita diagnóstico:", "Exige código CIE al registrar."),
                ("Fechas informativas:", "Guarda fechas reales además de las de aplicación."),
            ]},
            {"num": "3", "tit": "Ítems (NEVED)", "sub": "Detalle del evento", "pal": "green", "items": [
                ("Qué:", "Varios conceptos por evento, cada uno con factor (1.25 hora extra, 0.6667 incapacidad…) y fecha inicial."),
                ("Factor:", "Multiplica el valor hora o día del concepto."),
                ("Retiro (RET):", "Ítems de liquidación final; casilla ¿Indemniza? y si aplica a antigüedad mayor o menor."),
            ]},
            {"num": "4", "tit": "Cómo lo usa la prenómina", "sub": "Lectura", "pal": "violet", "items": [
                ("Novedad → concepto:", "Suma horas + minutos/60 × factor × valor hora del concepto."),
                ("Tipo liquidación:", "Por Nómina: novedades del mismo período. Por Fechas: las que se cruzan con las fechas del período."),
                ("Se repite:", "Si el concepto tiene ¿Se repite? = Sí, una línea por novedad."),
                ("Sin NEDIA no hay valor:", "Un concepto de novedad sin novedad registrada vale cero."),
            ]},
        ],
        accent="#db2777",
    )

    sketch(
        "nomconf_agrupaciones_sketchnote.jpg", B,
        "Agrupaciones y aportes: EPS, fondo, ARL, caja y parafiscales",
        "La agrupación dice a quién se le gira y con qué porcentaje",
        [
            {"num": "1", "tit": "Agrupación (NPRF)", "sub": "Pestaña Agrupaciones", "pal": "sky", "items": [
                ("Datos:", "Código, descripción, clase (Aporte, Parafiscal, Salario, Particular, Provisión…), tipo, ¿Es base? (solo Aporte), estado."),
                ("Destino:", "La definición del concepto apunta aquí con Destino del concepto (CODPRF)."),
            ]},
            {"num": "2", "tit": "Vigencias (NPRFD)", "sub": "Detalle", "pal": "orange", "items": [
                ("Qué:", "Fecha inicial, tipo cálculo (% o valor), valor empleado y valor empresa, tercero, estado."),
                ("Lectura:", "Al editar el concepto se muestra la vigencia activa más reciente."),
                ("Borrar:", "No deja si está en uso."),
            ]},
            {"num": "3", "tit": "Terceros (NPRFT)", "sub": "Asignar Tercero", "pal": "green", "items": [
                ("Qué:", "Lista de terceros válidos para la agrupación (las EPS, los fondos, las ARL)."),
                ("Uso:", "Al asignar la EPS del empleado se escoge entre estos."),
            ]},
            {"num": "4", "tit": "Por empleado (NPRFE / NPRFED)", "sub": "Empleados → Aportes", "pal": "violet", "items": [
                ("Qué:", "Para cada agrupación, el tercero del empleado con fecha inicial (su EPS, su fondo, su ARL)."),
                ("Copiar:", "Copia las afiliaciones de otro empleado."),
                ("Sin tercero:", "El concepto de aporte queda en cero con detalle Ap.No.Conf."),
            ]},
        ],
        accent="#059669",
    )

    sketch(
        "nomconf_empleado_sketchnote.jpg", B,
        "Lo individual del empleado: histórico, nómina, excepciones y particulares",
        "Pestaña Empleados: lo que hace a un empleado distinto del cargo",
        [
            {"num": "1", "tit": "Histórico (NEMPHIS)", "sub": "Botón Histórico", "pal": "sky", "items": [
                ("Qué:", "Fecha de movimiento, cargo/nivel/grado, básico, horas, área funcional, centro de costo, planta, estado, fechas ingreso/retiro."),
                ("Regla de oro:", "La prenómina toma la fila con mayor fecha de movimiento ≤ fin del período (FNK_INFO_NEMPHIS_NEMP)."),
                ("Área y centro:", "Se eligen de catálogo (AFU, CEN) y se guardan en la fila."),
                ("Permiso:", "HistoricoEmpleadosNom."),
            ]},
            {"num": "2", "tit": "Nómina y cargos", "sub": "Asignación", "pal": "orange", "items": [
                ("NOMIE:", "A qué nómina(s) pertenece y si está activo allí. Sin NOMIE no sale en prenómina."),
                ("Cargos (NPLA / NDIS):", "Planta y distribución % por centro de costo; se usa al contabilizar (tipo 3)."),
                ("Importar:", "Carga masiva de empleados por archivo (permiso ImportarEmpleadosNom)."),
            ]},
            {"num": "3", "tit": "Excepciones y particulares", "sub": "Conceptos", "pal": "green", "items": [
                ("Excluir (NEMPE):", "Conceptos de la plantilla que a este empleado no se le liquidan."),
                ("Particulares (NEMPDA):", "Concepto con valor o %, tercero, financiación y vigencia desde/hasta. También se cargan masivo desde prenómina."),
                ("Regla:", "Si el concepto no se repite, no se inserta otra vigencia cruzada."),
            ]},
            {"num": "4", "tit": "Contratos y documentos", "sub": "Soporte", "pal": "violet", "items": [
                ("Contratos (NEMPC):", "Número único, fechas, tipo. Alimenta nómina electrónica (tipo contrato)."),
                ("Documentos:", "Archivos adjuntos por tipo."),
                ("Período de prueba:", "Notificaciones de vencimiento (permiso EmpleadosPerPruebaTH)."),
            ]},
        ],
        accent="#9333ea",
    )

    sketch(
        "nomconf_retencion_sketchnote.jpg", B,
        "Retención en la fuente: quién, con qué tabla y sobre qué conceptos",
        "Pestaña Reten. Fuentes. El cálculo ocurre en cada prenómina",
        [
            {"num": "1", "tit": "Terceros (RETTER)", "sub": "Agregar", "pal": "sky", "items": [
                ("Qué:", "Tercero del empleado sujeto a retención: ¿Nómina?, código de configuración, clase, valor, estado."),
                ("Sin RETTER:", "No se calcula retefuente a ese empleado."),
            ]},
            {"num": "2", "tit": "Tabla UVT (RETUVT)", "sub": "Botón U V T", "pal": "orange", "items": [
                ("Rangos:", "UVT mínimo, UVT máximo, tarifa marginal, UVT adicional."),
                ("Variable:", "VALOR_UVT_RETEFTE: valor del UVT del año."),
            ]},
            {"num": "3", "tit": "Conceptos base (RETEI)", "sub": "Botón C O D I G O S", "pal": "green", "items": [
                ("Qué:", "Qué conceptos suman como devengo y cuáles restan como deducción."),
                ("Copiar códigos / Última nómina:", "Trae los conceptos marcados Base retención o los de la última nómina."),
            ]},
            {"num": "4", "tit": "En prenómina", "sub": "Resultado", "pal": "violet", "items": [
                ("Cálculo:", "Devengos − deducciones − renta exenta 25 % → UVT → tabla → valor."),
                ("Dónde cae:", "Concepto de la variable IDCONCEPTO_RETEFTE (egreso) en la nómina del empleado; liquidación guardada en RETEL."),
                ("Si da cero:", "La línea se borra del período."),
            ]},
        ],
        accent="#b45309",
    )


def liq():
    B = BRAND_LIQ

    sketch(
        "nomliq_que_es_sketchnote.jpg", B,
        "El ciclo de un período de nómina",
        "Del período abierto a la colilla: cada paso deja una marca",
        [
            {"num": "1", "tit": "Preparar", "sub": "Período abierto", "pal": "sky", "items": [
                ("Período:", "Configuraciones → Períodos: año, mes, fechas. Es el CNSPAGO sobre el que vive todo."),
                ("Prenómina:", "Gestionar prenómina carga la plantilla; Recalcular calcula a cada empleado."),
                ("Novedades:", "Incapacidades, horas extra, licencias, retiros: individuales o masivas. Conceptos particulares y manuales."),
            ]},
            {"num": "2", "tit": "Especiales", "sub": "Lo que no es mensual", "pal": "orange", "items": [
                ("Primas y cesantías:", "Talento humano → Prestaciones: programación por clase y generación por empleado."),
                ("Vacaciones:", "Períodos causados y novedad de disfrute que entra a la prenómina."),
                ("Libranzas:", "Préstamo con plan de cuotas; la cuota baja por concepto clase Préstamo."),
                ("Retefuente:", "Se calcula sola en cada recálculo si el empleado está en RETTER."),
            ]},
            {"num": "3", "tit": "Liquidar y cerrar", "sub": "Pestaña Liquidación", "pal": "green", "items": [
                ("Generar nómina:", "Pasa lo calculado (NEMPFD) a la liquidación (NIEPE/NIEPED). Valida terceros."),
                ("Cerrar:", "Valida cuentas contables, marca Cerrado, cuotas de libranza Pagadas, provisión de vacaciones."),
                ("Abrir:", "Reversa todo si no hay pagos ni notas sobre las CxP."),
            ]},
            {"num": "4", "tit": "Después", "sub": "Lo que sale", "pal": "violet", "items": [
                ("Contabilizar:", "Comprobante contable empleado a empleado."),
                ("CxP:", "Cuentas por pagar a terceros (EPS, fondos, libranzas) y neto al empleado."),
                ("DIAN:", "Nómina electrónica por empleado (NIEPEG)."),
                ("Colillas y reportes:", "PDF, correo, acumulados, pagos a terceros."),
            ]},
        ],
        pills=[
            ("Ruta", "Menú central → Talento humano → Procesos nómina (/nom/Nom_procesos): Prenómina · Liquidación · Envío DIAN."),
            ("Dos tablas, dos momentos", "NEMPF/NEMPFD = lo calculado (se puede recalcular). NIEPE/NIEPED = lo liquidado (lo que se paga y contabiliza)."),
            ("Cerrado manda", "Período cerrado: no se agregan novedades, no se recalcula, contabilidad no cierra el mes si hay nóminas abiertas."),
            ("Lo que no es", "Configurar conceptos/eventos (otro libro). Pagar al empleado: Cuentas por pagar / Tesorería."),
        ],
        accent="#0f766e",
    )

    sketch(
        "nomliq_prenomina_sketchnote.jpg", B,
        "Prenómina: cargar, calcular, ajustar",
        "Procesos nómina → Prenómina. Todo pasa empleado a empleado",
        [
            {"num": "1", "tit": "Elegir período", "sub": "Filtro", "pal": "sky", "items": [
                ("Qué:", "Nómina + estado + año/mes. Se abre el período (CNSPAGO) y la grilla de empleados."),
                ("Totales:", "Ingresos, egresos, aportes, total nómina y empleados, en vivo."),
            ]},
            {"num": "2", "tit": "Gestionar prenómina", "sub": "Botón", "pal": "orange", "items": [
                ("Trae plantilla:", "Cargos y conceptos de la plantilla a una tabla de trabajo (RPDX). Puede quitar o agregar."),
                ("Procesar:", "Por cada empleado ejecuta PRENOMINA: borra lo anterior, calcula ingresos, luego egresos, retiros, retefuente, totales."),
                ("Agregar:", "Mete un empleado nuevo al período."),
            ]},
            {"num": "3", "tit": "Ajustar", "sub": "Botones", "pal": "green", "items": [
                ("Novedades:", "Individual o masivo (archivo). Al guardar se recalcula el empleado."),
                ("Conceptos:", "Carga masiva de conceptos particulares (valor, tercero, vigencia) → recálculo."),
                ("Retiros:", "Retiro masivo por archivo; luego recálculo uno a uno."),
                ("Fila:", "Editar una línea: Liquidar sí/no, incluir/excluir, valor."),
            ]},
            {"num": "4", "tit": "Leer la grilla", "sub": "Columnas", "pal": "violet", "items": [
                ("Liquidar?", "No cuando el egreso supera el % máximo a deducir de la nómina."),
                ("% egresos:", "Egresos / ingresos del empleado."),
                ("Tercero CxP:", "A quién se gira ese concepto."),
                ("Recalcular:", "Siempre que cambie algo en configuración o novedades."),
            ]},
        ],
        pills=[
            ("Permiso", "MENUQ_NOMINA · Prenomina abre la pestaña. No hay permiso por botón dentro."),
            ("Período cerrado", "Nada de esto corre; primero Abrir nómina en Liquidación."),
            ("Recalcular borra", "PRENOMINA elimina y recrea las líneas del empleado; los manuales del período (NPERC) y particulares se vuelven a leer."),
            ("Sin error visible", "El motor no lanza errores: una línea en cero trae el motivo en la columna Detalle."),
        ],
        accent="#2563eb",
    )

    sketch(
        "nomliq_novedades_sketchnote.jpg", B,
        "Novedades del período, particulares y manuales",
        "Tres formas de meter algo que la plantilla no trae",
        [
            {"num": "1", "tit": "Novedad (NEDIA)", "sub": "Botón Novedades → Individual", "pal": "sky", "items": [
                ("Datos:", "Empleado, evento, fechas de aplicación (y hora inicio/fin), días u horas y minutos, factor."),
                ("Forma de liquidación:", "Por pago (este período) o por fecha (el período que cubra la fecha)."),
                ("Extras:", "¿Es prórroga?, diagnóstico (si el evento lo pide), fechas informativas, recobro a tercero, retiro con indemnización."),
                ("Efecto:", "Guardar → recálculo del empleado. Borrar un retiro limpia también su liquidación."),
            ]},
            {"num": "2", "tit": "Masivo", "sub": "Archivo Excel / TXT", "pal": "orange", "items": [
                ("Flujo:", "Plantilla → subir → validar (errores por fila) → corregir → procesar."),
                ("Valida:", "Contrato, documento, evento, diagnóstico, fechas, empleado en plantilla, concepto activo."),
                ("Interactivo:", "Grilla de empleados × evento para digitar cantidades sin archivo."),
            ]},
            {"num": "3", "tit": "Particulares (NEMPDA)", "sub": "Botón Conceptos", "pal": "green", "items": [
                ("Qué:", "Concepto Particular con valor, tercero, financiación y vigencia desde/hasta, por empleado."),
                ("Masivo:", "Mismo flujo de archivo. Si el concepto no se repite, no inserta vigencias cruzadas."),
                ("Dónde más:", "Configuraciones → Empleados → Conceptos (uno a uno)."),
            ]},
            {"num": "4", "tit": "Manuales (NPERC)", "sub": "Talento humano → Manuales", "pal": "violet", "items": [
                ("Qué:", "Ajuste puntual del período: empleado, concepto Manual, valor empleado, valor 100 %, aporte empresa."),
                ("Vida:", "Solo existe en ese CNSPAGO. El recálculo lo respeta."),
                ("Adelanto de cesantías:", "Se registra como manual del concepto NOM_ADEL_CESAN."),
            ]},
        ],
        accent="#db2777",
    )

    sketch(
        "nomliq_motor_sketchnote.jpg", B,
        "Cómo se calcula un concepto (sin fórmulas)",
        "Lo que hace el motor por cada empleado y cada concepto",
        [
            {"num": "1", "tit": "¿Aplica?", "sub": "Filtros previos", "pal": "sky", "items": [
                ("Empleado:", "Activo, en la nómina, con básico > 0 en su histórico a la fecha. Ingresó antes del fin del período."),
                ("Concepto:", "Vigencia válida; no excluido por cargo ni por empleado; frecuencia y antigüedad cumplidas."),
                ("Novedad:", "Si el concepto viene de evento, necesita NEDIA del empleado en el período."),
            ]},
            {"num": "2", "tit": "Base × valor", "sub": "El número", "pal": "orange", "items": [
                ("Base:", "Según la definición: laborado, básico, neto, prestaciones, conceptos, cuota, fórmula, tabla."),
                ("Horas:", "Horas del cargo menos novedades que restan horas; ingreso o retiro parcial prorratea."),
                ("Valor:", "% o valor fijo sobre la base; factor de la novedad; redondeo configurado."),
                ("Empresa:", "Aportes y parafiscales llevan además el valor empresa."),
            ]},
            {"num": "3", "tit": "Orden y tope", "sub": "Secuencia", "pal": "green", "items": [
                ("Ingresos primero:", "Por prioridad. Luego egresos por prioridad."),
                ("Tope:", "Si egresos acumulados superan el % máximo a deducir, la línea queda Liquidar = No (salvo Permitir deducciones)."),
                ("Retiros:", "Después de la plantilla: prima, vacaciones, cesantías, indemnización según el evento RET."),
                ("Retefuente:", "Al final, si el empleado está sujeto."),
            ]},
            {"num": "4", "tit": "Resultado", "sub": "Lo que queda", "pal": "violet", "items": [
                ("Líneas:", "Una por concepto con cantidad, valor empleado, valor empresa, tercero, detalle."),
                ("Totales:", "Ingresos, egresos, aportes, neto, % egresos por empleado y por período."),
                ("Cero con motivo:", "BASICO=0, ANTIGUEDAD, Ap.No.Conf, Valor<=0: el motor explica en Detalle, no falla."),
                ("Auxilio transporte:", "Se retira si los ingresos superan 2 SMMLV (variable AUX_TRANS_VS_INGRESO)."),
            ]},
        ],
        accent="#4f46e5",
    )

    sketch(
        "nomliq_retiros_sketchnote.jpg", B,
        "Retiros: novedad RET y liquidación final",
        "Un retiro es una novedad; la liquidación la hace el recálculo",
        [
            {"num": "1", "tit": "Individual", "sub": "Novedades → evento RET", "pal": "sky", "items": [
                ("Qué:", "Novedad con evento de retiro, fecha de retiro, ¿con indemnización?, motivo."),
                ("Efecto:", "Fecha de retiro en el empleado + histórico; el recálculo liquida."),
                ("Borrar:", "Quita la novedad y limpia las líneas de retiro."),
            ]},
            {"num": "2", "tit": "Masivo", "sub": "Botón Retiros", "pal": "orange", "items": [
                ("Flujo:", "Archivo documento, nombre, fecha → validar (sin retiro previo, en plantilla, fecha ≥ ingreso) → Retirar."),
                ("Una corrida:", "Marca fecha de retiro y crea la novedad RET a todos."),
                ("Después:", "La pantalla recalcula empleado a empleado (con muchos retiros tarda)."),
            ]},
            {"num": "3", "tit": "Qué liquida", "sub": "Según FORMALIQRETIROS", "pal": "green", "items": [
                ("Estándar:", "Conceptos del evento RET: prima proporcional, vacaciones pendientes, cesantías, intereses, indemnización."),
                ("OTRASIPS:", "Genera la provisión y escribe directo en la liquidación; marca pagadas las provisiones."),
                ("Adelantos:", "Cesantías pendientes de adelanto se descuentan en orden de fecha."),
                ("Vacaciones:", "Días causados hasta la fecha de retiro desde los períodos NEMPV."),
            ]},
            {"num": "4", "tit": "Cuidados", "sub": "Lo que no valida", "pal": "rose", "items": [
                ("Sin aviso:", "El motor de retiros no lanza error; revise las líneas y el Detalle."),
                ("Fechas duras:", "Umbrales 180/360 días y códigos fijos de prima/vacaciones en el cálculo."),
                ("Reabrir:", "Si el período se abre, los adelantos aplicados se desaplican."),
            ]},
        ],
        accent="#dc2626",
    )

    sketch(
        "nomliq_primas_sketchnote.jpg", B,
        "Primas, cesantías e intereses: programar, verificar, generar",
        "Talento humano → Prestaciones. Una programación por clase y año",
        [
            {"num": "1", "tit": "Programación (NVAC)", "sub": "Nueva programación", "pal": "sky", "items": [
                ("Clase:", "Prima junio, Prima diciembre, Cesantías, Intereses de cesantías, Vacaciones."),
                ("Liquidación:", "P = Provisiones (suma lo provisionado mes a mes), C = Conceptos (calcula con la definición), S = Base salarial."),
                ("Datos:", "Nómina base, año, fecha inicial y final, días, consecutivo de pago (período donde se paga), evento."),
            ]},
            {"num": "2", "tit": "Detalle (NVACD)", "sub": "Registrar detalle", "pal": "orange", "items": [
                ("Qué:", "Período de pago (CNSPAGO) y evento de pago. El evento lleva al concepto que paga."),
                ("Generar detalles:", "Crea una fila por empleado activo de la nómina."),
                ("Verificar:", "Marcar Pagado / No pagar / Sin liquidar por empleado antes de generar."),
            ]},
            {"num": "3", "tit": "Generar", "sub": "Tres pasos", "pal": "green", "items": [
                ("Preparar:", "Lista empleados; exige período no cerrado."),
                ("Generar por empleado:", "Provisiones: suma aportes del semestre/año no pagados de los conceptos asociados; descuenta adelantos de cesantías. Conceptos: valor de la definición prorrateado por días."),
                ("Finalizar:", "Totales del período y estado Liquidado."),
            ]},
            {"num": "4", "tit": "Reglas", "sub": "Variables", "pal": "violet", "items": [
                ("NOMI_PRIMADIAS_MIN:", "Menos días laborados que esto → no se paga."),
                ("PERIODO_PRESTA_NOM = FECHAS:", "Toma el rango de fechas de la programación en vez del semestre fijo."),
                ("Asociaciones:", "La provisión se paga con los conceptos asociados (NCONDA) y esos se quitan del período."),
                ("Eventos de prestación (PREVENT):", "Descuentos sobre lo provisionado (no mayor al provisionado)."),
            ]},
        ],
        accent="#0891b2",
    )

    sketch(
        "nomliq_retefuente_sketchnote.jpg", B,
        "Retención en la fuente del empleado",
        "Se calcula sola en cada recálculo; se consulta en Liquidación retefuente",
        [
            {"num": "1", "tit": "Requisitos", "sub": "Configuración", "pal": "sky", "items": [
                ("Tercero sujeto:", "El tercero del empleado está en RETTER con ¿Nómina?"),
                ("Concepto:", "Variable IDCONCEPTO_RETEFTE apunta a un concepto Egreso y ese concepto está en la plantilla."),
                ("UVT:", "VALOR_UVT_RETEFTE > 0 y tabla RETUVT con rangos."),
            ]},
            {"num": "2", "tit": "Cálculo", "sub": "En PRENOMINA", "pal": "orange", "items": [
                ("Devengos:", "Suma de conceptos marcados como ingreso base."),
                ("Deducciones:", "Aportes obligatorios y conceptos marcados como deducción."),
                ("Exenta:", "25 % de renta exenta (sin tope implementado)."),
                ("UVT → tabla:", "Base en UVT contra RETUVT: tarifa marginal + UVT adicional."),
            ]},
            {"num": "3", "tit": "Dónde queda", "sub": "Tablas", "pal": "green", "items": [
                ("Liquidación RETEL / RETELD:", "Una por empleado y período con base, UVT, valor."),
                ("Concepto en nómina:", "Línea del concepto de retefuente con el valor; si da cero se borra."),
                ("Pantalla:", "Talento humano → Liquidación retefuente: consulta por año/mes y certificado."),
            ]},
            {"num": "4", "tit": "Certificado", "sub": "Ingresos y retenciones", "pal": "violet", "items": [
                ("Dónde:", "Talento humano → Certificados: genera el certificado anual por empleado (NCINGRET)."),
                ("Ajustes:", "Asignar código de retención, reliquidar detalle, ajustar total, cerrar certificado."),
            ]},
        ],
        accent="#b45309",
    )

    sketch(
        "nomliq_libranzas_sketchnote.jpg", B,
        "Libranzas: préstamo, plan de cuotas y descuento en nómina",
        "Nómina → Gestión de libranzas. La cuota baja por un concepto clase Préstamo",
        [
            {"num": "1", "tit": "Préstamo (PRS)", "sub": "Nuevo préstamo", "pal": "sky", "items": [
                ("Datos:", "Empleado, concepto (clase Préstamo), financiación, total, número de cuotas, fecha inicio pago, intereses, observaciones."),
                ("Al guardar:", "Se genera el plan de cuotas automáticamente."),
                ("Estados:", "PorPagar, Pagada, Anulada, Aplazada."),
            ]},
            {"num": "2", "tit": "Cuotas (PRSD)", "sub": "Plan", "pal": "orange", "items": [
                ("Cada cuota:", "Número, valor, intereses, fecha de pago, estado; cuando la nómina la descuenta guarda período y línea."),
                ("Generar cuotas:", "Rehace el plan desde la última pagada. Borrar cuotas elimina las no pagadas."),
                ("Nueva cuota / editar:", "Ajuste manual de una cuota."),
            ]},
            {"num": "3", "tit": "En nómina", "sub": "Descuento", "pal": "green", "items": [
                ("Base Cuota:", "El concepto lee la cuota PorPagar cuya fecha cae en el período y la descuenta."),
                ("Cerrar nómina:", "Marca esas cuotas Pagada y recalcula saldo y estado del préstamo."),
                ("Abrir nómina:", "Las devuelve a PorPagar."),
            ]},
            {"num": "4", "tit": "Otros", "sub": "Botones", "pal": "violet", "items": [
                ("Enviar a CxP:", "Crea la cuenta por pagar del desembolso al empleado."),
                ("Homologar:", "Pasa libranzas de un contrato retirado al contrato nuevo del mismo empleado."),
                ("Cambiar estado cuota:", "Permiso Frm:PRSD · CambiaEstCuot."),
                ("Cuidado:", "Borrar o regenerar no revisa si la cuota ya fue descontada en una nómina abierta."),
            ]},
        ],
        accent="#7c3aed",
    )

    sketch(
        "nomliq_vacaciones_sketchnote.jpg", B,
        "Vacaciones y adelanto de cesantías",
        "Dos pantallas propias que terminan en la prenómina",
        [
            {"num": "1", "tit": "Períodos (NEMPV)", "sub": "Talento humano → Vacaciones", "pal": "sky", "items": [
                ("Qué:", "Por empleado, un ítem por año: fecha inicio/fin del período, días de vacaciones del cargo, días causados, pagados, pendientes."),
                ("Actualizar:", "Recalcula lo causado a hoy (prorrateo a 360 días)."),
                ("Restablecer:", "Rehace los períodos del empleado (permiso BtnRestablecerPeriodosVac)."),
            ]},
            {"num": "2", "tit": "Evento (NEMPVD)", "sub": "Nuevo Evento", "pal": "orange", "items": [
                ("Qué:", "Fecha salida, días a pagar, días de disfrute, calendario (sábados, domingos, festivos), fecha regreso, período de nómina."),
                ("Generar novedad:", "Crea la novedad NEDIA del concepto de vacaciones y recalcula. Si cruza de mes, parte en dos novedades."),
                ("Deshacer / anular:", "Solo con período abierto; devuelve los días."),
            ]},
            {"num": "3", "tit": "Adelanto cesantías (NACE)", "sub": "Talento humano → Adelanto", "pal": "green", "items": [
                ("Registrar:", "Empleado, año, valor ≤ saldo disponible de cesantías; crea el manual del concepto NOM_ADEL_CESAN en el período abierto."),
                ("Estados:", "Registrado → EnNomina → Aplicado (cuando se paga cesantías o retiro) · Anulado."),
                ("Anular:", "No si ya fue descontado en la liquidación de cesantías."),
            ]},
            {"num": "4", "tit": "Variables", "sub": "Configuración", "pal": "violet", "items": [
                ("NOMICODCON_VACA:", "Concepto de vacaciones."),
                ("IDNOVEDADVACSIGMES / MESANTE · VACA_MESSIGUE_COBRO:", "Cómo se parte la novedad que cruza de mes."),
                ("PERIODO_VACACIONES / VAC_ULTIMOS_4PER:", "Vigencia y número de períodos."),
                ("NOM_ADEL_CESAN:", "Concepto Manual del adelanto."),
            ]},
        ],
        accent="#ea580c",
    )

    sketch(
        "nomliq_cierre_sketchnote.jpg", B,
        "Generar, cerrar y abrir la nómina",
        "Pestaña Liquidación. Tres botones con permiso propio",
        [
            {"num": "1", "tit": "Generar nómina", "sub": "Siempre permitido", "pal": "sky", "items": [
                ("Valida:", "Ingresos cuyo tercero del concepto no es el del empleado → exporta Excel y para."),
                ("Hace:", "Borra y recrea la liquidación del período (NIEPE por empleado, NIEPED por línea) desde lo calculado; totales; recobros a terceros."),
                ("Marca:", "Período Generado."),
            ]},
            {"num": "2", "tit": "Cerrar nómina", "sub": "BtnCerrarNomina", "pal": "orange", "items": [
                ("Valida:", "Hay liquidación; cada línea tiene cuenta contable (modelo KMCOM) → si no, Excel de errores."),
                ("Hace:", "Período y liquidación Cerrado; cuotas de libranza Pagada; provisión mensual de vacaciones."),
                ("Después:", "Ya no se recalcula ni se agregan novedades."),
            ]},
            {"num": "3", "tit": "Abrir nómina", "sub": "BtnAbrirNomina", "pal": "green", "items": [
                ("Bloquea si:", "El mes contable está cerrado; hay órdenes de pago sobre las CxP de nómina; hay notas DB/CR sobre ellas."),
                ("Hace:", "Cuotas a PorPagar; borra comprobantes contables; borra CxP sin pagos; período Abierto y sin contabilizar; revierte vacaciones."),
                ("Aviso:", "La pantalla advierte que se pierde contabilidad y CxP."),
            ]},
            {"num": "4", "tit": "Salidas", "sub": "Imprimir / Exportar", "pal": "violet", "items": [
                ("Imprimir:", "PDF de la liquidación."),
                ("Exportar:", "Excel, SOI (planilla), detalle de nómina, cuentas DB/CR."),
                ("Totales:", "Ingresos, egresos, aportes, total nómina, empleados."),
            ]},
        ],
        pills=[
            ("Orden", "Generar → (revisar) → Cerrar → Contabilizar → CxP → DIAN. Abrir deshace de Cerrar en adelante."),
            ("Contabilidad y nómina", "Contabilidad no cierra el mes si hay períodos sin Cerrado."),
            ("Generar no exige cerrado", "Se puede generar varias veces mientras el período esté abierto."),
            ("Permisos", "MENUQ_NOMINA: Liquidacion (pestaña), BtnCerrarNomina, BtnAbrirNomina, BtnContabilizarNomina, GenerarCxp, CxpEspecial, btnImprimirLiquidacion, btnExportarLiquidacion."),
        ],
        accent="#16a34a",
    )

    sketch(
        "nomliq_contabilidad_sketchnote.jpg", B,
        "Contabilizar, cuentas por pagar y recobros",
        "Lo que sale de la nómina cerrada hacia Contabilidad y Tesorería",
        [
            {"num": "1", "tit": "Contabilizar", "sub": "BtnContabilizarNomina", "pal": "sky", "items": [
                ("Cómo:", "Empleado a empleado, con fecha contable. El primero crea el comprobante; los demás suman líneas al mismo."),
                ("Cuentas:", "Modelo contable KMCOM: por concepto, DB/CR, centro de costo y nómina."),
                ("Tipo:", "NOMINATIPOCONTAB 1 normal; 3 distribuye por centros de costo de la planta si suma 100 %."),
                ("Exige:", "Período contable existente; comprobante IDCON_TCOM_NOMINA (o por sede)."),
            ]},
            {"num": "2", "tit": "Cuentas por pagar", "sub": "Generar CxP", "pal": "orange", "items": [
                ("Automático:", "Si NOMINA_AUTENVIO_CXP está activa, tras contabilizar se generan solas."),
                ("Manual:", "Botón Generar CxP (permiso GenerarCxp). Validar / Reconstruir CxP por tercero."),
                ("Especiales:", "CxP Especiales (permiso CxpEspecial) para conceptos con tratamiento aparte."),
                ("Qué crea:", "Una CxP por tercero (EPS, fondos, libranzas, neto al empleado) con procedencia Nómina."),
            ]},
            {"num": "3", "tit": "Recobros (NIEPER)", "sub": "Prestación social", "pal": "green", "items": [
                ("Qué:", "Valores que la EPS/ARL debe reembolsar (incapacidades con recobro)."),
                ("Pago:", "Talento humano → Prestación social: se cruza con un movimiento de Bancos o un recibo de Caja marcados Recaudo nómina."),
                ("Parcial:", "Si paga menos, queda un nuevo renglón con el saldo."),
            ]},
            {"num": "4", "tit": "Lo que no es", "sub": "Otros módulos", "pal": "rose", "items": [
                ("Pagar al empleado:", "La orden de pago sale de Cuentas por pagar / Tesorería."),
                ("Cierre contable:", "Contabilidad → Cierres: exige nóminas cerradas."),
                ("Presupuesto:", "Si está activo, la CxP afecta rubro (ENVIARNOMI_PPTO_AUTO)."),
            ]},
        ],
        accent="#059669",
    )

    sketch(
        "nomliq_dian_sketchnote.jpg", B,
        "Nómina electrónica DIAN",
        "Pestaña Envío DIAN. Un documento por empleado y período",
        [
            {"num": "1", "tit": "Preparar", "sub": "Preparar nómina", "pal": "sky", "items": [
                ("Qué:", "Crea un documento NIEPEG por empleado liquidado del período (estado 0)."),
                ("Tipo:", "Nómina individual (102) o nota de ajuste (103) con reemplazo/eliminación."),
            ]},
            {"num": "2", "tit": "Enviar", "sub": "Procesar", "pal": "orange", "items": [
                ("Encolar:", "Procesar pone estado 1 (en cola). Un proceso externo arma el XML, firma y envía."),
                ("Respuesta:", "Llega a FDIANR y el trigger actualiza el estado del documento."),
            ]},
            {"num": "3", "tit": "Estados", "sub": "ESTADODIAN", "pal": "green", "items": [
                ("0", "Preparado."),
                ("1", "En cola / error 500 (reintenta)."),
                ("2", "Aceptado (CUNE)."),
                ("3", "Rechazado: corregir y volver a procesar."),
                ("4", "En consulta (ZipKey)."),
            ]},
            {"num": "4", "tit": "Requisitos", "sub": "Lo que revisa el XML", "pal": "violet", "items": [
                ("Conceptos:", "Clasificación DIAN en cada concepto."),
                ("Empleado:", "Tipo de documento y tipo de cotizante homologados; tipo de contrato."),
                ("Empresa:", "Resolución vigente, ID y PIN del software, TestSetId en pruebas."),
                ("Vista previa XML:", "Permiso BtnPrevioXml; no envía."),
            ]},
        ],
        accent="#4338ca",
    )


def liq_extra():
    """Capítulos añadidos 2026-10-04: certificados, turnos, capacitaciones."""
    B = BRAND_LIQ

    sketch(
        "nomliq_certificados_sketchnote.jpg", B,
        "Certificados y contratos del empleado",
        "Cuatro documentos que salen de la nómina ya liquidada",
        [
            {"num": "1", "tit": "Ingresos y retenciones", "sub": "Talento humano → Certificados", "pal": "sky", "items": [
                ("Nuevo certificado:", "Empleado, año, fechas, valor UVT. Crea una fila por código de retención (TGEN NOMINA·CERTINGRETE) y suma lo liquidado del año."),
                ("Configurar:", "Asignar a cada concepto su código de retención (NCON.CODRET). Sin eso el certificado sale en cero."),
                ("Reliquidar / Ajustar:", "Recalcula las sumas o corrige un total a mano mientras esté Abierto."),
                ("Cerrar:", "Pasa a Cerrado; solo entonces imprime."),
            ]},
            {"num": "2", "tit": "Liquidación de retención", "sub": "Talento humano → Liquidación retefuente", "pal": "orange", "items": [
                ("Qué muestra:", "RETEL por período y empleado: devengos, deducciones, renta exenta, base, UVT, retención."),
                ("Detalle:", "RETELD con cada concepto que sumó o restó."),
                ("Certificado:", "PDF de la liquidación (aportes a pensión, fondo y salud separados)."),
                ("Nace:", "En cada recálculo de prenómina; aquí solo se consulta."),
            ]},
            {"num": "3", "tit": "Certificados laborales", "sub": "Talento humano → Certificaciones", "pal": "green", "items": [
                ("Solicitud:", "El empleado la pide desde su menú personal (NSOLICERT en Espera: dirigido a, con sueldo, cargo, tipo de contrato, fecha de ingreso)."),
                ("Generar:", "RRHH elige formato (NCERTC tipo Certificado) y hasta 4 conceptos con valor; crea NCERT Generado y cierra la solicitud."),
                ("Firma:", "Firma del jefe de RRHH (variable USUARIOJEFERH) desde su imagen registrada."),
            ]},
            {"num": "4", "tit": "Contratos laborales", "sub": "Talento humano → Contratos", "pal": "violet", "items": [
                ("Generar:", "Empleado activo + formato tipo Contrato con contenido web. Un solo contrato Activo por empleado."),
                ("Firmas:", "Empleado y Representante legal (permiso BtnFirmarContGerente; imagen o dibujo). Firma masiva del gerente."),
                ("Inactivar:", "Deja el contrato Inactivo para generar otro."),
                ("Formatos:", "Talento humano → Formatos: plantillas NCERTC con variables (empleado, cargo, EPS, ARL, caja)."),
            ]},
        ],
        pills=[
            ("Estados", "NCINGRET Abierto → Cerrado · NSOLICERT Espera → Generado · NCONTLABO Activo / Inactivo + fecha de firma por parte."),
            ("Sin permiso por botón", "Solo BtnFirmarContGerente. Certificados y retención dependen del acceso al menú."),
            ("Lo que no es", "La retención se calcula en Prenómina (capítulo Retefuente); aquí se consulta e imprime."),
        ],
        accent="#0e7490",
    )

    sketch(
        "nomliq_turnos_sketchnote.jpg", B,
        "Auditoría de turnos → novedades de nómina",
        "Del cuadro de turnos (asistencial y administrativo) a la novedad del período",
        [
            {"num": "1", "tit": "Traer datos", "sub": "Año + mes (+ usuario)", "pal": "sky", "items": [
                ("Resumen diario:", "Toma los turnos TSECFU del mes no resumidos y arma TSECRES: horas cumplidas, pendientes y de novedad por día."),
                ("Estado del día:", "Borrador si quedan horas pendientes; Error si hay novedad y horas cumplidas a la vez; Definitivo si cuadra."),
                ("Marca:", "Los días Definitivos quedan RESUM=1 en el turno: no se vuelven a tomar."),
            ]},
            {"num": "2", "tit": "Pestaña Turnos", "sub": "TURESUM", "pal": "orange", "items": [
                ("Qué ve:", "Por período y usuario: horas cumplidas, pendientes, de novedad y total. Estado Abierto."),
                ("Rehacer:", "Traer datos borra lo Abierto del período y lo recrea; lo cerrado no se toca."),
                ("Imprimir:", "PDF del resumen."),
            ]},
            {"num": "3", "tit": "Pestaña Novedades", "sub": "TURNOV", "pal": "green", "items": [
                ("Qué ve:", "Horas por código de novedad del turno (TGEN TSECFU·NOVEDAD) y usuario; columna CNSPAGO cuando ya pasó a nómina."),
                ("Configurar:", "Mapea cada código de novedad de turnos a un evento de nómina (NEVE) en TGEN.DATO1."),
                ("Sin mapa:", "La novedad no tiene evento y no puede pasar a NEDIA."),
            ]},
            {"num": "4", "tit": "Hacia la nómina", "sub": "Lo que hay y lo que falta", "pal": "rose", "items": [
                ("Hoy:", "El SP de auditoría solo arma resumen y novedades; no inserta NEDIA."),
                ("Paso manual:", "La novedad de nómina se registra en Prenómina → Novedades con el evento mapeado."),
                ("Hueco:", "No hay botón «Enviar a nómina» en PREVERSION 2.0.7: candidato a REQ."),
            ]},
        ],
        accent="#be185d",
    )

    sketch(
        "nomliq_capacitaciones_sketchnote.jpg", B,
        "Talento humano: capacitaciones, talleres y período de prueba",
        "Lo que RRHH gestiona del empleado fuera del pago",
        [
            {"num": "1", "tit": "Capacitaciones (CAP)", "sub": "Permiso GESTIONCAP", "pal": "sky", "items": [
                ("Programar:", "Capacitación con sesiones (fecha, hora, instructor, grupo de usuarios) y soportes adjuntos."),
                ("Convocar:", "Empleados por sesión; asistencia confirmada desde la sesión."),
                ("Exportar:", "Cronograma y detalle a Excel."),
            ]},
            {"num": "2", "tit": "Talleres y formularios", "sub": "Permiso GESTIONTALL", "pal": "orange", "items": [
                ("Taller:", "Formulario con preguntas (opción múltiple o respuesta libre) y opciones."),
                ("Asignar:", "Empleados asignados responden desde su menú personal."),
                ("Calificar:", "Las de texto se califican a mano; resultados en TRESULTADOS."),
            ]},
            {"num": "3", "tit": "Período de prueba", "sub": "Permiso EmpleadosPerPruebaTH", "pal": "green", "items": [
                ("Qué:", "Empleados con fecha fin de período de prueba: validación y aviso por correo (QRY_ENVIOS)."),
                ("Dónde:", "Configuración → Empleados → Emp. P. Prueba."),
            ]},
            {"num": "4", "tit": "Distribución de planta", "sub": "NDISP", "pal": "violet", "items": [
                ("Qué:", "Porcentaje de la planta del empleado por área / centro de costo."),
                ("Para qué:", "Contabilizar nómina distribuida (NOMINATIPOCONTAB = 3) si la suma llega a 100 %."),
                ("Regla:", "Una distribución por área; no se duplica."),
            ]},
        ],
        pills=[
            ("Menú personal", "Solicitar certificado, responder talleres y ver capacitaciones salen del cajón Talento humano del empleado (MainLayout), no del menú RRHH."),
            ("Gastos por consumo", "El ítem del menú RRHH abre la solicitud de artículos de Inventario (IZSOL): se documenta en Inventario."),
        ],
        accent="#7c2d12",
    )


def main():
    os.makedirs(IMG_DIR, exist_ok=True)
    conf()
    liq()
    liq_extra()
    print("OK sketchnotes nómina en", IMG_DIR)


if __name__ == "__main__":
    main()
