# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas) del libro Honorarios médicos (FXP).

Uso:  python libro/scripts/gen_honorarios_sketchnotes.py
Salida: libro/img/fxp_*_sketchnote.jpg

Contenido contrastado 2026-10-04 con Qrystalos2 (TercerosComponent / PXSNComponent, ServiciosComponent,
PREComponent, HPREComponent, AutorizadorComponent, HonorariosMedPage / FXPComponent / FXPDComponent,
useFxPReport, CXPComponent) y los objetos de IXONLINE/SQL (SPQ_PXSN, SPQ_PXS, SPQ_PXSE, VW_CXPPROTOT,
SPK_CREACXP_ASIS / CE / CI, SPQ_FXP_COL, FNK_ESTADO_FXP, SPK_CAMBIAR_TERFXP, SPK_INSERT_CXP_SALUD).
Regla del libro: sin volúmenes ni valores de configuración de un cliente.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_recaudos_sketchnotes import sketch, IMG_DIR  # noqa: E402

B = "QRYSTALOS IPS · ADMINISTRATIVO · HONORARIOS MÉDICOS"


def main():
    sketch(
        "fxp_config_sketchnote.jpg", B,
        "Configurar al proveedor y sus precios",
        "Configuración → Terceros → Contratación Como Sub-Contratista. Base por administradora, prefijos por sede, excepciones por servicio",
        [
            {"num": "1", "tit": "Tercero", "sub": "TER · TEXCA (PRO)", "pal": "sky", "items": [
                ("Debe ser:", "Contratante con categoría PRO (proveedor)."),
                ("Permiso:", "TERCEROS_WEB · CONTR_SUBCONTR muestra el botón."),
                ("Ojo:", "Sin PRO no aparece en Id.Proveedor del cargo."),
            ]},
            {"num": "2", "tit": "Contratación", "sub": "PXSN · GUARDAR", "pal": "orange", "items": [
                ("Pide:", "Administradora (CON), plan, tarifa, factor > 0."),
                ("Rechaza:", "Administradora + plan repetidos."),
                ("Extras:", "Copiar contratación de otro proveedor."),
            ]},
            {"num": "3", "tit": "Prefijos", "sub": "PXS · GUARDAR", "pal": "violet", "items": [
                ("Pide:", "Sede, prefijo, tipo Normal o Tarifa (tarifa + factor propios)."),
                ("Rechaza:", "Prefijo repetido para la configuración."),
                ("Nota:", "Marcas de pago compartido no afectan el honorario."),
            ]},
            {"num": "4", "tit": "Excepciones", "sub": "PXSE · GUARDAR", "pal": "green", "items": [
                ("Tipos:", "Restringir (sin honorario), Tarifa (+ factor), Valor fijo."),
                ("Rechaza:", "Servicio repetido."),
                ("Lista:", "Solo servicios vigentes del prefijo, no cirugía."),
            ]},
            {"num": "5", "tit": "Precio final", "sub": "VW_CXPPROTOT · Contratación total", "pal": "rose", "items": [
                ("Fórmula:", "Valor tarifa × factor proveedor × factor dinero, redondeo de la tarifa."),
                ("Cirugía:", "Valor de la tarifa tal cual."),
                ("Vigencias:", "Del servicio en la tarifa y del convenio."),
            ]},
        ],
        pills=[
            ("Regla", "El servicio debe tener «Maneja Proveedor»."),
            ("Regla", "Lo que no sale en Contratación total no genera honorario."),
            ("Ojo", "Restringir saca el servicio de la contratación."),
        ],
        accent="#0369a1",
    )

    sketch(
        "fxp_generacion_sketchnote.jpg", B,
        "El honorario nace al facturar",
        "Cargo con Id.Proveedor → facturar → selección → precio → FXP/FXPD en Preparado → cargo marcado",
        [
            {"num": "1", "tit": "Cargo", "sub": "HPRED.IDPROVEEDOR · AUT.IDPROVEEDOR · CIT.IDMEDICO", "pal": "sky", "items": [
                ("Hospital:", "Id.Proveedor obligatorio si el servicio maneja proveedor; lista VW_PXS por administradora y prefijo."),
                ("Consulta ext.:", "Proveedor en la autorización; obligatorio si AUT_OBLI_IDPROVEEDOR = SI."),
                ("Citas:", "El médico de la cita es el proveedor."),
            ]},
            {"num": "2", "tit": "Facturar", "sub": "SPK_FACTURA_* → SPK_CREACXP_ASIS · SPK_FACTURACE_* → CE / CI", "pal": "orange", "items": [
                ("Cuándo:", "Al cerrar la factura de la admisión, la autorización o la cita."),
                ("Toma:", "Cargos de esa factura, no anulados, con proveedor ≠ institución, sin honorario previo."),
            ]},
            {"num": "3", "tit": "Precio", "sub": "VW_CXPPROTOT", "pal": "violet", "items": [
                ("Busca:", "Proveedor + administradora + plan + prefijo + servicio."),
                ("Exige:", "Fecha del cargo dentro de las dos vigencias; valor > 0."),
                ("Si no:", "El cargo no entra y no avisa."),
            ]},
            {"num": "4", "tit": "Honorario", "sub": "FXP · FXPD · @FCXP", "pal": "green", "items": [
                ("Cabecera:", "Un número por proveedor y prestación; estado P; procedencia SALUD / CE / CI; referencia = documento origen."),
                ("Detalle:", "Servicio, prefijo, valor, cantidad, prestación, factura, centro de costo, área."),
                ("HOMED:", "Reparto por porcentaje si existe (sin pantalla hoy)."),
            ]},
            {"num": "5", "tit": "Marca", "sub": "HPRED.CXP = 1 · HADM.CXP = 1 · AUT.CXPGEN = 1", "pal": "rose", "items": [
                ("Evita:", "Generar dos veces el mismo cargo."),
                ("Se libera:", "Al anular o liberar la factura (borra el honorario)."),
            ]},
        ],
        pills=[
            ("Regla", "No hay botón «generar honorario»."),
            ("Regla", "Falta el honorario = proveedor, contratación o vigencia."),
            ("Ojo", "Anular la factura borra el honorario, también si ya está en CxP."),
        ],
        accent="#b45309",
    )

    sketch(
        "fxp_gestion_sketchnote.jpg", B,
        "Honorarios médicos: consultar, corregir e imprimir",
        "Administrativo → Honorarios médicos. Filtros, detalle, Cambiar tercero, Imprimir CxP / Excel / Cuenta de cobro",
        [
            {"num": "1", "tit": "Filtrar", "sub": "FXP + TER", "pal": "sky", "items": [
                ("Pide:", "Proveedor (PRO), fecha inicial y final (generación), estado."),
                ("Estados:", "Preparados = P y S · En CXP = E · Anulados = A."),
                ("Pestañas:", "Por N. CXP · Por No. Referencia."),
            ]},
            {"num": "2", "tit": "Detalle", "sub": "FXPD + SER", "pal": "orange", "items": [
                ("Muestra:", "Estado, ítem, prefijo, servicio, valor, cantidad, total, prestación, factura."),
                ("Selección:", "Un ítem habilita Cambiar tercero."),
            ]},
            {"num": "3", "tit": "Cambiar tercero", "sub": "FXP_COL · ESTADO_FXP → CAMBIAR_TERFXP", "pal": "violet", "items": [
                ("Bloquea si:", "La factura de venta está confirmada en contabilidad (muestra el comprobante)."),
                ("Hace:", "Mueve el ítem al honorario del nuevo tercero (o crea uno); actualiza cargo y factura."),
                ("Contable:", "Si la factura estaba contabilizada, reconstruye el comprobante."),
            ]},
            {"num": "4", "tit": "Imprimir", "sub": "IMPRIMIR_CXP · IMPRIMIR_CUENTA_COBRO", "pal": "green", "items": [
                ("Imprimir CxP:", "PDF «Cuentas por pagar presupuestada» con subtotal por proveedor."),
                ("Cuenta de cobro:", "PDF «Debe a: proveedor / Por concepto de»."),
                ("Excel:", "Misma información en hoja."),
                ("Exige:", "Proveedor y las dos fechas."),
            ]},
            {"num": "5", "tit": "Después", "sub": "FXPD S → SPK_INSERT_CXP_SALUD → FCXPD Salud → E", "pal": "rose", "items": [
                ("Diseño:", "Marcar ítems y pasarlos a una cuenta por pagar del proveedor."),
                ("Hoy:", "Sin camino en la web; solo Cuentas esperadas en salud (consulta)."),
                ("Anular:", "Botón sin procedimiento (pendiente)."),
            ]},
        ],
        pills=[
            ("Regla", "Honorarios médicos no paga: la CxP paga."),
            ("Regla", "Cambiar tercero solo si el comprobante no está confirmado."),
            ("Ojo", "Preparados incluye los ítems ya seleccionados (S)."),
        ],
        accent="#4338ca",
    )

    print("Sketchnotes generadas en", IMG_DIR)


if __name__ == "__main__":
    main()
