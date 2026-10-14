# -*- coding: utf-8 -*-
"""Genera las sketchnotes (mapas de proceso) del capítulo Cartera · Recaudos.

Uso:  python libro/scripts/gen_recaudos_sketchnotes.py
Salida: libro/img/recaudos_*_sketchnote.jpg (1280x720, estilo de las de Caja).

Contenido contrastado 2026-10-03 con Qrystalos2 (FPAGComponent, CXCComponent,
AvalRecaudosComponent) e IXONLINE/SQL SPQ_FPAG_COL (PREVERSION; liberada 2.0.7).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG_DIR = os.path.join(ROOT, "img")
W, H = 1280, 720
# Factor de render: el lienzo lógico es 1280 de ancho pero se dibuja a 2x
# para que el texto quede nítido al ampliarlo en el libro.
S = 2

PAL = {
    "sky": ("#0284c7", "#f0f9ff", "#bae6fd"),
    "orange": ("#ea580c", "#fff7ed", "#fed7aa"),
    "violet": ("#7c3aed", "#faf5ff", "#e9d5ff"),
    "green": ("#16a34a", "#f0fdf4", "#bbf7d0"),
    "rose": ("#e11d48", "#fff1f2", "#fecdd3"),
    "teal": ("#0d9488", "#f0fdfa", "#99f6e4"),
    "amber": ("#d97706", "#fffbeb", "#fde68a"),
    "slate": ("#475569", "#f8fafc", "#cbd5e1"),
}


def font(size, bold=False):
    names = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for f in names:
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, int(round(size * S)))
            except Exception:
                pass
    return ImageFont.load_default()


class Lienzo:
    """Proxy de ImageDraw que trabaja en coordenadas lógicas (1280 de ancho)
    y las multiplica por S al dibujar. Las medidas de texto se devuelven en
    unidades lógicas para que el layout no cambie con el factor de render."""

    def __init__(self, im):
        self.d = ImageDraw.Draw(im)

    @staticmethod
    def _xy(xy):
        return [v * S for v in xy]

    def rectangle(self, xy, **kw):
        self.d.rectangle(self._xy(xy), **kw)

    def rounded_rectangle(self, xy, radius=0, width=1, **kw):
        self.d.rounded_rectangle(self._xy(xy), radius=radius * S, width=max(1, int(width * S)), **kw)

    def line(self, xy, width=1, **kw):
        self.d.line(self._xy(xy), width=max(1, int(width * S)), **kw)

    def polygon(self, pts, **kw):
        self.d.polygon([(x * S, y * S) for x, y in pts], **kw)

    def text(self, xy, txt, **kw):
        self.d.text((xy[0] * S, xy[1] * S), txt, **kw)

    def textbbox(self, xy, txt, font=None):
        b = self.d.textbbox((xy[0] * S, xy[1] * S), txt, font=font)
        return [v / S for v in b]


def _partir_palabra(draw, word, fnt, max_w):
    """Parte una palabra que no cabe en una línea (nombres técnicos largos),
    preferiblemente después de '_' o '/'; si no, por caracteres."""
    partes, cur = [], ""
    for ch in word:
        test = cur + ch
        if draw.textbbox((0, 0), test, font=fnt)[2] <= max_w:
            cur = test
        else:
            corte = max(cur.rfind("_"), cur.rfind("/"))
            if corte > 2:
                partes.append(cur[: corte + 1])
                cur = cur[corte + 1 :] + ch
            else:
                partes.append(cur)
                cur = ch
    if cur:
        partes.append(cur)
    return partes


def wrap(draw, text, fnt, max_w):
    lines = []
    for raw in str(text).split("\n"):
        cur = ""
        for word in raw.split(" "):
            if draw.textbbox((0, 0), word, font=fnt)[2] > max_w:
                if cur:
                    lines.append(cur)
                trozos = _partir_palabra(draw, word, fnt, max_w)
                lines.extend(trozos[:-1])
                cur = trozos[-1]
                continue
            test = (cur + " " + word).strip()
            if draw.textbbox((0, 0), test, font=fnt)[2] <= max_w:
                cur = test
            else:
                if cur:
                    lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


CARD_TOP = 150       # inicio de las tarjetas (debajo de la cabecera oscura)


def card_height_needed(draw, items, fl, ft, card_w, lh_l, lh_t, head_h):
    y = head_h + 14
    for label, val in items:
        y += lh_l
        y += lh_t * len(wrap(draw, val, ft, card_w - 40))
        y += 10
    return y + 8


def sketch(out_name, brand, title, subtitle, cards, pills=None, pills_title=None, accent="#ea580c"):
    # Lienzo provisional para medir; la altura final se calcula según el contenido.
    im = Image.new("RGB", (W * S, H * S), "#f8fafc")
    d = Lienzo(im)

    n = len(cards)
    gap = 22 if n <= 4 else 14
    start_x = 30
    card_w = int((W - 2 * start_x - gap * (n - 1)) / n)
    card_top = CARD_TOP

    # Cabecera de tarjeta: título y subtítulo pueden ocupar hasta dos líneas.
    f_num = font(13 if n <= 4 else 12, True)
    f_tit_s = 20 if n <= 4 else 17
    f_sub_s = 14 if n <= 4 else 12
    f_tit, f_sub = font(f_tit_s, True), font(f_sub_s, True)
    lh_tit, lh_sub = f_tit_s + 5, f_sub_s + 4
    for c in cards:
        c["_tit_lines"] = wrap(d, c["tit"], f_tit, card_w - 28)[:2]
        c["_sub_lines"] = wrap(d, c.get("sub", ""), f_sub, card_w - 28)[:2] if c.get("sub") else []
    head_h = 36 + max(len(c["_tit_lines"]) * lh_tit + len(c["_sub_lines"]) * lh_sub for c in cards) + 10

    # Tamaño de letra: el mayor que quepa en una tarjeta de alto razonable.
    # Se parte de ~20 px lógicos (el libro muestra la imagen a ~900–1000 px,
    # así que 20 px lógicos equivalen a ~15 px en pantalla).
    sizes = [(20, 20), (19, 19), (19, 18), (18, 18), (18, 17), (17, 17), (17, 16), (16, 16)]
    max_card_h = 980
    for fl_s, ft_s in sizes:
        fl, ft = font(fl_s, True), font(ft_s)
        lh_l, lh_t = fl_s + 8, ft_s + 7
        needed = max(card_height_needed(d, c["items"], fl, ft, card_w, lh_l, lh_t, head_h) for c in cards)
        if needed <= max_card_h:
            break
    card_h = int(min(max_card_h, max(320, needed + 10)))

    # Barra inferior: alto según el texto de las píldoras
    f_pt, f_pv = font(16, True), font(15)
    lh_p = 20
    bar_h = 0
    if pills:
        k = len(pills)
        pg = 14
        pw = int((W - 2 * start_x - 28 - pg * (k - 1)) / k)
        max_lines = max(len(wrap(d, pdesc, f_pv, pw - 20)) for _, pdesc in pills)
        pill_h = 32 + max_lines * lh_p + 10
        bar_h = 44 + pill_h + 14

    H_final = card_top + card_h + ((18 + bar_h + 18) if pills else 26)

    im = Image.new("RGB", (W * S, H_final * S), "#f8fafc")
    d = Lienzo(im)

    # Cabecera
    d.rectangle([0, 0, W, 128], fill="#0f172a")
    d.rectangle([0, 124, W, 128], fill=accent)
    f_brand = font(15, True)
    bw = d.textbbox((0, 0), brand, font=f_brand)[2] + 28
    d.rounded_rectangle([30, 16, 30 + bw, 42], radius=13, fill="#1e293b", outline="#334155", width=1)
    d.text((44, 20), brand, font=f_brand, fill="#38bdf8")
    f_title = font(31, True)
    t = title
    while d.textbbox((0, 0), t, font=f_title)[2] > W - 60 and len(t) > 10:
        t = t[:-2].rstrip() + "…"
    d.text((30, 50), t, font=f_title, fill="#ffffff")
    f_subt = font(17)
    st = subtitle
    while d.textbbox((0, 0), st, font=f_subt)[2] > W - 60 and len(st) > 10:
        st = st[:-2].rstrip() + "…"
    d.text((30, 92), st, font=f_subt, fill="#cbd5e1")

    # Tarjetas
    for i, c in enumerate(cards):
        col, bg, border = PAL[c.get("pal", "sky")]
        cx, cy = start_x + i * (card_w + gap), card_top
        d.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=14, fill="#ffffff", outline=border, width=2)
        d.rounded_rectangle([cx, cy, cx + card_w, cy + head_h], radius=14, fill=bg)
        d.rectangle([cx, cy + head_h - 16, cx + card_w, cy + head_h], fill=bg)
        d.line([cx, cy + head_h, cx + card_w, cy + head_h], fill=border, width=1)
        num = c.get("num", f"PASO {i + 1:02d}")
        nw = d.textbbox((0, 0), num, font=f_num)[2] + 16
        d.rounded_rectangle([cx + 14, cy + 10, cx + 14 + nw, cy + 30], radius=5, fill=col)
        d.text((cx + 22, cy + 12), num, font=f_num, fill="#ffffff")
        ty = cy + 36
        for line in c["_tit_lines"]:
            d.text((cx + 14, ty), line, font=f_tit, fill="#0f172a")
            ty += lh_tit
        for line in c["_sub_lines"]:
            d.text((cx + 14, ty + 1), line, font=f_sub, fill=col)
            ty += lh_sub

        y = cy + head_h + 14
        for label, val in c["items"]:
            d.rectangle([cx + 14, y + 4, cx + 19, y + fl_s + 2], fill=col)
            d.text((cx + 26, y), label, font=fl, fill="#1e293b")
            y += lh_l
            for line in wrap(d, val, ft, card_w - 40):
                d.text((cx + 26, y), line, font=ft, fill="#475569")
                y += lh_t
            y += 10

        if i < n - 1 and c.get("flecha", True):
            ax, ay = cx + card_w + 3, cy + 220
            d.polygon([(ax, ay - 8), (ax + gap - 8, ay), (ax, ay + 8)], fill="#94a3b8")

    # Barra inferior
    if pills:
        by = card_top + card_h + 18
        d.rounded_rectangle([start_x, by, W - start_x, by + bar_h], radius=12, fill="#ffffff", outline="#cbd5e1", width=1)
        d.rounded_rectangle([start_x, by, W - start_x, by + 36], radius=12, fill="#f1f5f9")
        d.rectangle([start_x, by + 22, W - start_x, by + 36], fill="#f1f5f9")
        d.text((start_x + 16, by + 9), pills_title or "REGLAS QUE CONVIENE RECORDAR", font=font(14, True), fill="#334155")
        px, py = start_x + 14, by + 44
        for ptit, pdesc in pills:
            d.rounded_rectangle([px, py, px + pw, py + pill_h], radius=8, fill="#f8fafc", outline="#e2e8f0", width=1)
            pt = ptit
            while d.textbbox((0, 0), pt, font=f_pt)[2] > pw - 20 and len(pt) > 8:
                pt = pt[:-2].rstrip() + "…"
            d.text((px + 10, py + 7), pt, font=f_pt, fill="#0284c7")
            yy = py + 30
            for line in wrap(d, pdesc, f_pv, pw - 20):
                d.text((px + 10, yy), line, font=f_pv, fill="#64748b")
                yy += lh_p
            px += pw + pg

    out = os.path.join(IMG_DIR, out_name)
    im.save(out, quality=92, optimize=True)
    print("OK", os.path.relpath(out, ROOT), f"{im.width}x{im.height}")


BRAND = "QRYSTALOS IPS · CARTERA · RECAUDOS"


def main():
    os.makedirs(IMG_DIR, exist_ok=True)

    # 1. Hilo común
    sketch(
        "recaudos_hilo_comun_sketchnote.jpg", BRAND,
        "El hilo común de todo recaudo: crear → asignar → aplicar",
        "Sea caja, banco, glosa, cruce o devolución, el recaudo recorre siempre los mismos cuatro pasos en Administrativo → Cartera → Recaudos",
        [
            {"num": "PASO 01", "tit": "Crear la cabecera", "sub": "Botón Nuevo (permiso BNuevoFPAG)", "pal": "sky", "items": [
                ("Quién:", "Analista de cartera o tesorero."),
                ("Qué se digita:", "Tercero (pagador), tipo de Ingreso, Fecha de legalización y el valor u origen (recibo, consignación)."),
                ("Si es glosa o devolución:", "aparece además el selector Paso a Seguir y la Fecha Glosa‑Devol."),
                ("Regla:", "Un mismo usuario no puede tener dos recaudos abiertos del mismo tercero y el mismo ingreso."),
                ("Técnico:", "FPAG · FPAG_COL/INSERTAR"),
            ]},
            {"num": "PASO 02", "tit": "Asignar facturas", "sub": "Traer Varias o Carga masiva", "pal": "orange", "items": [
                ("Una a una:", "Traer Varias abre la cuenta por cobrar del tercero y se marcan las facturas."),
                ("Masivo:", "Estructura Excel → diligenciar → subir → Procesar → Asignar."),
                ("Solo entra:", "lo que esté radicado en cartera a nombre de ese tercero y con saldo."),
                ("Regla:", "Sin líneas asignadas el botón Aplicar no hace nada; una factura no puede repetirse en el lote."),
                ("Técnico:", "RPDX (lote) → FPAGD (detalle) · ASIGNAR"),
            ]},
            {"num": "PASO 03", "tit": "Revisar antes de aplicar", "sub": "Totales y candados", "pal": "violet", "items": [
                ("Totales:", "Total Facturas, Total Glosas/Devoluciones y Total Impuestos deben cuadrar con lo recibido."),
                ("Ajuste al peso:", "la diferencia por redondeo debe estar dentro del máximo configurado."),
                ("Impuestos:", "cada retención necesita su desglose y una cuenta contable vigente."),
                ("Periodo:", "el mes contable de la fecha debe estar abierto."),
                ("Técnico:", "FPAGDI · FIMPDV · PRI · REC_VLRMAX_AJUSTE"),
            ]},
            {"num": "PASO 04", "tit": "Aplicar", "sub": "Aplicar Pago / Glosas / Devolución", "pal": "green", "items": [
                ("Qué hace:", "Descuenta el saldo de cada factura, genera el comprobante contable y deja el recaudo Cerrado."),
                ("Según el ingreso:", "crea el expediente de glosa, retira la factura devuelta o cruza con la cuenta por pagar."),
                ("Punto de no retorno:", "Glosas 4 y 6 y devoluciones 1 y 2 no se pueden deshacer."),
                ("Si algo falla:", "el sistema responde KO con el motivo y no deja nada a medias."),
                ("Técnico:", "APLICARPAGO → SPK_PAGOSCXC"),
            ]},
        ],
        pills=[
            ("Estado Abierto / Cerrado", "Abierto = se puede editar, asignar, borrar o inactivar. Cerrado = ya aplicado; solo reversos controlados."),
            ("Un recaudo, un tercero", "Las facturas del lote deben pertenecer al tercero del recaudo; si no, el Asignar rechaza el lote."),
            ("Excel: VALIDACION = OK", "La columna VALIDACION es una fórmula de la hoja; las filas con factura deben decir OK. No viaja al servidor."),
            ("Paso a Seguir", "Solo existe en GLOSAS (3–6) y DEVOLUCION (0–2). Cambia la plantilla y lo que pasa al aplicar."),
        ],
    )

    # 2. Seis ingresos
    sketch(
        "recaudos_seis_ingresos_sketchnote.jpg", BRAND,
        "Los seis tipos de Ingreso: ¿de dónde viene el dinero (o la novedad)?",
        "El selector Ingreso del formulario decide qué se busca al crear, qué plantilla se arma y qué ocurre al aplicar",
        [
            {"num": "CAJA", "tit": "Recibo de caja", "sub": "Dinero que ya entró por ventanilla", "pal": "sky", "items": [
                ("Origen:", "Un recibo de caja de ingreso externo con la casilla Recaudo marcada y ya cerrado."),
                ("Al crear:", "Buscar recibo → Código Caja + Consecutivo Recibo."),
                ("Al aplicar:", "Pago normal: descuenta cartera y contabiliza."),
            ]},
            {"num": "BANCOS", "tit": "Consignación", "sub": "Movimiento de tesorería confirmado", "pal": "teal", "items": [
                ("Origen:", "Línea del movimiento bancario con marca de recaudo y saldo por legalizar."),
                ("Al crear:", "Banco, cuenta y documento del movimiento."),
                ("Al aplicar:", "Legaliza el valor y descuenta cartera."),
            ]},
            {"num": "GLOSAS", "tit": "Objeción del pagador", "sub": "Paso a Seguir 3, 4, 5 o 6", "pal": "rose", "items": [
                ("Origen:", "El pagador informa glosas sobre facturas radicadas."),
                ("Al crear:", "Elegir Paso a Seguir y Fecha Glosa‑Devol."),
                ("Al aplicar:", "Nace el expediente de glosa; según el paso se responde solo o va a auditoría."),
            ]},
            {"num": "CXP", "tit": "Cruce con cuentas por pagar", "sub": "El cliente también es proveedor", "pal": "violet", "items": [
                ("Origen:", "Compensar facturas de cartera con facturas que le debemos al mismo tercero."),
                ("Al crear:", "Pestaña Cruce CXP → Nueva CXP."),
                ("Al aplicar:", "La suma del cruce debe ser igual al valor de las facturas."),
            ]},
            {"num": "DEVOLUCION", "tit": "Factura devuelta", "sub": "Paso a Seguir 0, 1 o 2", "pal": "amber", "items": [
                ("Origen:", "El pagador devuelve la factura sin pagarla."),
                ("Al crear:", "Solo devolver, Devolver y anular o Devolver y radicar."),
                ("Al aplicar:", "Retira la factura de la cuenta de cobro y, si aplica, la anula o la deja lista para radicar de nuevo."),
            ]},
            {"num": "LEVANTAM.", "tit": "Levantamiento de glosa", "sub": "Menos frecuente", "pal": "slate", "items": [
                ("Origen:", "Una glosa registrada que el pagador levanta: el valor vuelve a ser cobrable."),
                ("Al crear:", "Mismo formulario; sin Paso a Seguir."),
                ("Al aplicar:", "El motor de levantamiento ajusta la glosa y el saldo de la factura."),
            ]},
        ],
        pills=[
            ("Variable REC_VLRMAX_AJUSTE", "Si no está configurada o es inválida, CAJA, BANCOS y CXP desaparecen del selector Ingreso."),
            ("Paso a Seguir", "Solo lo piden GLOSAS y DEVOLUCION. La columna Proceso de la grilla muestra el nombre del paso."),
            ("Filtro de la grilla", "Ingreso, Aplicado (Todas / Sin aplicar / Aplicados), Estado (Activo / Inactivo), fechas y sede."),
            ("No es…", "Facturar, radicar la cuenta de cobro ni responder la glosa en auditoría: eso ocurre en otros módulos."),
        ],
        accent="#0284c7",
    )

    # 3. Desde Caja
    sketch(
        "recaudos_desde_caja_sketchnote.jpg", BRAND,
        "Recaudo desde Caja: del recibo de ventanilla al pago aplicado",
        "La búsqueda es de recibos marcados para recaudo, no de la caja maestra ni de la configuración «Acepta Recaudo»",
        [
            {"num": "ANTES", "tit": "En Caja (ventanilla)", "sub": "Lo hace el cajero", "pal": "sky", "items": [
                ("Registra:", "Un ingreso externo a nombre del tercero (EPS, aseguradora, particular) con la casilla Recaudo marcada."),
                ("Cierra el recibo:", "El recibo queda cerrado y activo. Sin esa casilla el recibo no aparece en Recaudos."),
                ("Técnico:", "FCJ.RECAUDO = 1 · CERRADA = 1 · ESTADO = P"),
            ]},
            {"num": "PASO 01", "tit": "Nuevo recaudo CAJA", "sub": "Buscar recibo", "pal": "orange", "items": [
                ("Formulario:", "Ingreso = CAJA, tercero y fecha de legalización."),
                ("Buscar recibo:", "Lista los recibos de ese tercero cerrados, activos y que todavía no estén en otro recaudo."),
                ("Se toma:", "Código Caja y Consecutivo Recibo; el valor del recaudo es el del recibo."),
                ("Técnico:", "FPAG_COL/TRAE_PAGO"),
            ]},
            {"num": "PASO 02", "tit": "Guardar", "sub": "El recibo queda «en pagos»", "pal": "violet", "items": [
                ("Efecto:", "El recaudo amarra caja + recibo y el recibo se marca en pagos: no vuelve a salir en otra búsqueda."),
                ("Si cambia el origen:", "Al editar la cabecera se libera el recibo anterior y se marca el nuevo."),
                ("Técnico:", "FPAG.CODCAJA / CNSFACJ · FCJ.ENPAGOS = 1"),
            ]},
            {"num": "PASO 03", "tit": "Asignar y aplicar", "sub": "Igual al hilo común", "pal": "green", "items": [
                ("Asignar:", "Traer Varias o plantilla Excel (N_FACTURA, VLRPAGO, TIPO, VALIDACION)."),
                ("Cuadre:", "La suma de las facturas debe coincidir con el valor del recibo; el sobrante va al ajuste al peso dentro del límite."),
                ("Aplicar Pago:", "Descuenta cartera, contabiliza y cierra el recaudo."),
            ]},
        ],
        pills=[
            ("¿No aparece el recibo?", "Revise: ¿casilla Recaudo marcada? ¿recibo cerrado? ¿tercero igual al del recaudo? ¿ya lo usó otro recaudo?"),
            ("«Acepta Recaudo» no filtra", "Ese toggle pertenece a la configuración de caja menor. La pantalla de Recaudos no lo consulta."),
            ("Variable obligatoria", "REC_VLRMAX_AJUSTE numérica. Sin ella, CAJA no se ofrece en el selector de ingreso."),
            ("Ruta", "Administrativo → Cartera → Recaudos → Nuevo → Ingreso CAJA → Buscar recibo."),
        ],
        accent="#0284c7",
    )

    # 4. Desde Bancos
    sketch(
        "recaudos_desde_bancos_sketchnote.jpg", BRAND,
        "Recaudo desde Bancos: de la consignación confirmada al pago aplicado",
        "Tesorería registra y confirma el movimiento; cartera lo legaliza contra facturas",
        [
            {"num": "ANTES", "tit": "En Tesorería · Bancos", "sub": "Lo hace tesorería", "pal": "teal", "items": [
                ("Registra:", "El movimiento bancario (consignación o transferencia) a nombre del tercero."),
                ("Marca recaudo:", "La operación financiera deja la línea marcada como recaudo pendiente de legalizar."),
                ("Confirma:", "Sin confirmación del movimiento, la línea no aparece en Recaudos."),
                ("Técnico:", "BMOVD.RECAUDO = 1 · BMOV.ESTADO = O"),
            ]},
            {"num": "PASO 01", "tit": "Nuevo recaudo BANCOS", "sub": "Banco, cuenta y documento", "pal": "sky", "items": [
                ("Formulario:", "Ingreso = BANCOS, tercero y fecha de legalización."),
                ("Búsqueda:", "Líneas de ese tercero marcadas como recaudo, confirmadas, que no estén ya en pagos y con saldo por legalizar mayor que cero."),
                ("Técnico:", "FPAG_COL/TRAE_PAGO · BMOVD.ENPAGOS = 0"),
            ]},
            {"num": "PASO 02", "tit": "Guardar", "sub": "La línea queda vinculada", "pal": "violet", "items": [
                ("Efecto:", "El recaudo guarda banco, cuenta, ítem y documento; la línea pasa a «en pagos» y no vuelve a salir."),
                ("Valor:", "El valor del recaudo es el saldo por legalizar de la línea."),
                ("Técnico:", "FPAG.BANCO / CTA_BCO / ITEM · BMOVD.ENPAGOS = 1"),
            ]},
            {"num": "PASO 03", "tit": "Asignar y aplicar", "sub": "Igual al hilo común", "pal": "green", "items": [
                ("Asignar:", "Traer Varias o plantilla Excel; impuestos (retenciones) y descuento administrativo si el archivo los trae."),
                ("Descuento administrativo:", "En BANCOS se valida antes de aplicar."),
                ("Aplicar Pago:", "Legaliza la consignación, descuenta cartera y contabiliza."),
            ]},
        ],
        pills=[
            ("¿No aparece la consignación?", "¿Está confirmada por tesorería? ¿Tiene la marca de recaudo? ¿Ya la tomó otro recaudo? ¿Es del mismo tercero?"),
            ("Un movimiento, un recaudo", "Una línea bancaria legalizada no se puede volver a usar; si se equivocó, desaplique o anule el recaudo."),
            ("Retirar factura en cerrado", "En BANCOS, con permiso BRetiraFactura, se puede retirar una factura aunque el recaudo esté aplicado."),
            ("Variable obligatoria", "REC_VLRMAX_AJUSTE numérica. Sin ella, BANCOS no se ofrece en el selector."),
        ],
        accent="#0d9488",
    )

    # 5. Plantilla Excel
    sketch(
        "recaudos_plantilla_excel_sketchnote.jpg", BRAND,
        "Carga masiva: la plantilla la arma la pantalla según el ingreso",
        "Descargar → diligenciar → subir y procesar → Asignar. Solo después se puede Aplicar",
        [
            {"num": "PASO 01", "tit": "Descargar Estructura Excel", "sub": "Desde el recaudo abierto", "pal": "sky", "items": [
                ("Dónde:", "Dentro del recaudo → Carga masiva → Estructura Excel."),
                ("Qué trae:", "Las columnas exactas para ese Ingreso y ese Paso a Seguir."),
                ("Opcional:", "Al descargar se puede marcar impuestos (hasta 4) y descuento administrativo; solo entonces se agregan esas columnas."),
            ]},
            {"num": "PASO 02", "tit": "Diligenciar", "sub": "CAJA · BANCOS · CXP", "pal": "orange", "items": [
                ("Columnas base:", "N_FACTURA · VLRPAGO · TIPO · VALIDACION"),
                ("TIPO:", "F factura, G glosa, R ratificación, C conciliación."),
                ("VLRPAGO:", "mayor que cero y no superior al saldo de la factura."),
                ("VALIDACION:", "fórmula de la hoja; debe decir OK. No se envía al servidor."),
                ("Si los marcó:", "IDIMPUESTO/BASE/VLR por impuesto y VLR_DTO."),
            ]},
            {"num": "PASO 03", "tit": "Subir y Procesar", "sub": "El sistema revisa fila por fila", "pal": "violet", "items": [
                ("Valida:", "factura radicada en cartera del tercero, saldo suficiente, sin duplicados en el lote ni ya asignadas, impuestos con cuenta vigente."),
                ("Errores:", "Exportar errados y Exportar log muestran qué fila falló y por qué."),
                ("Reenviar:", "borra el lote anterior y vuelve a cargar."),
                ("Técnico:", "CARGAR_FACTURAS / SUBIR_TXT → RPDX"),
            ]},
            {"num": "PASO 04", "tit": "Asignar", "sub": "Del lote al detalle", "pal": "green", "items": [
                ("Qué hace:", "Pasa el lote al detalle del recaudo y recalcula los totales de la cabecera."),
                ("Bloquea si:", "el recaudo ya está cerrado o hay facturas de otro tercero."),
                ("Después:", "ya se puede pulsar Aplicar."),
                ("Técnico:", "ASIGNAR → SPK_CARGA_MASIVA_FAC_CXC_02 → FPAGD"),
            ]},
        ],
        pills=[
            ("Filas sin N_FACTURA", "Se ignoran. Use la plantilla descargada hoy: el encabezado debe coincidir."),
            ("GLOSAS 4, 5 y 6", "Encabezado y orden exactos de la plantilla descargada; cada paso tiene columnas distintas (ver capítulo de Glosas)."),
            ("Plano CSV", "También se acepta un archivo plano con la misma estructura (SUBIR_TXT)."),
            ("Motivos", "MOTIVO1 / MOTIVO2 / OBS aparecen cuando las variables MOBSERVAFRECGLOSA o MOBSERVADEVOLFACTURA están en SI."),
        ],
        accent="#7c3aed",
    )

    # 6. Cruce CxP
    sketch(
        "recaudos_cruce_cxp_sketchnote.jpg", BRAND,
        "Ingreso CXP: cobrar cruzando con lo que le debemos al mismo tercero",
        "Dos piezas en el mismo recaudo: las facturas de cartera y la pestaña Cruce CXP con las cuentas por pagar",
        [
            {"num": "CUÁNDO", "tit": "Cliente y proveedor a la vez", "sub": "Compensación", "pal": "violet", "items": [
                ("Caso típico:", "Una EPS o entidad a la que facturamos y que, a su vez, nos factura (arriendos, convenios, servicios)."),
                ("Resultado:", "La cartera baja y la cuenta por pagar baja por el mismo valor, sin que circule dinero."),
                ("Requisito:", "Variable REC_VLRMAX_AJUSTE configurada; si no, CXP no se ofrece."),
            ]},
            {"num": "PASO 01", "tit": "Facturas de cartera", "sub": "Igual que CAJA y BANCOS", "pal": "sky", "items": [
                ("Asignar:", "Traer Varias o plantilla Excel (N_FACTURA, VLRPAGO, TIPO, VALIDACION; impuestos y VLR_DTO si el archivo los trae)."),
                ("Total:", "La suma de las líneas es el valor de los ítems del recaudo."),
                ("Técnico:", "FPAGD"),
            ]},
            {"num": "PASO 02", "tit": "Pestaña Cruce CXP", "sub": "Botón Cruce CXP → Nueva CXP", "pal": "orange", "items": [
                ("Elegir:", "Cuentas por pagar del mismo tercero con saldo mayor que cero y no anuladas."),
                ("Vlr. Cruce:", "cuánto de cada cuenta por pagar se compensa; el total del recaudo se recalcula con la suma."),
                ("Bloquea:", "repetir la misma cuenta por pagar o tocar un recaudo ya cerrado."),
                ("Técnico:", "CRUD_FPAGDCXP · REGRESA_FCXPAGDCXP → FPAGDCXP"),
            ]},
            {"num": "PASO 03", "tit": "Aplicar", "sub": "Las dos piezas deben cuadrar", "pal": "green", "items": [
                ("Candado:", "Suma del cruce = valor de los ítems. Si no cuadra: «El valor de los pagos debe ser igual al valor del cruce»."),
                ("Efecto:", "Descuenta cartera, abona las cuentas por pagar cruzadas y contabiliza."),
                ("Técnico:", "APLICARPAGO → SPK_PAGOSCXC · SPK_CALCULOVALORESCXP"),
            ]},
        ],
        pills=[
            ("Solo en recaudo Abierto", "El cruce se arma y edita antes de aplicar. Después, solo desaplicar (si el periodo está abierto) o anular."),
            ("Mismo tercero", "Las cuentas por pagar y las facturas deben ser del tercero del recaudo."),
            ("Notas crédito", "Si hay descuentos administrativos con nota crédito asociada, el recaudo no se puede desaplicar."),
            ("Ruta", "Recaudos → Nuevo → Ingreso CXP → asignar facturas → Cruce CXP → Aplicar."),
        ],
        accent="#7c3aed",
    )

    # 7. Glosas pasos
    sketch(
        "recaudos_glosas_pasos_sketchnote.jpg", BRAND,
        "Glosas: los cuatro Pasos a Seguir y qué pasa al aplicar",
        "Ingreso GLOSAS. El Paso a Seguir decide la plantilla, quién responde y si la acción se puede deshacer",
        [
            {"num": "PASO 3", "tit": "Recepcionar", "sub": "Registrar y enviar a auditoría a mano", "pal": "sky", "items": [
                ("Al aplicar:", "Registra la glosa y crea el expediente. No responde nada."),
                ("Después:", "Cartera pulsa Enviar Auditoría (permiso BEnviarAuditoriaFPAG) e Imprimir Entrega."),
                ("Reversible:", "Sí: se puede retirar una factura aun aplicado (permiso BRetiraFactura) y desaplicar si la auditoría no ha respondido."),
                ("Excel:", "N_FACTURA · TIPO · VLRPAGO (+ MOTIVO1, MOTIVO2, OBS si las variables lo exigen)"),
            ]},
            {"num": "PASO 4", "tit": "Recepcionar y Responder", "sub": "Respuesta total automática", "pal": "rose", "items": [
                ("Al aplicar:", "Registra la glosa, la envía y la recibe en auditoría, la responde al 100 % con el código de respuesta y el valor aceptado, imprime y devuelve el saldo a cartera."),
                ("Nota crédito:", "según el valor aceptado."),
                ("Reversible:", "No. La pantalla avisa antes de aplicar."),
                ("Excel:", "N_FACTURA · TIPO · VLRPAGO · MOTIVO1 · OBS · CODRPTA · VLR_ACEPTADO · VALIDACION (encabezado exacto)"),
            ]},
            {"num": "PASO 5", "tit": "Detalles Glosa", "sub": "Ítem por ítem para el auditor", "pal": "violet", "items": [
                ("Al aplicar:", "Deja en auditoría el detalle de cada servicio glosado (código, valor del ítem, observación). El auditor responde a mano."),
                ("Cuadre:", "la suma de los ítems debe ser igual al valor global de la glosa."),
                ("Reversible:", "Retirar factura sí (permiso); la respuesta la da auditoría."),
                ("Excel:", "N_FACTURA · TIPO · VLR_GLOSA · CODGLOSA · VLR_ITEM · OBSERVACION · VALIDACION"),
            ]},
            {"num": "PASO 6", "tit": "Detalles y Responder", "sub": "Detalle + respuesta por ítem", "pal": "amber", "items": [
                ("Al aplicar:", "Registra el detalle por ítem y responde en el mismo acto con código de respuesta y valor aceptado; luego cierra igual que el paso 4."),
                ("Observaciones:", "mínimo 10 caracteres."),
                ("Reversible:", "No. La pantalla avisa antes de aplicar."),
                ("Excel:", "N_FACTURA · TIPO · CODGLOSA · VALOR · CODRPTA · VLR_ACEPTADO · OBSERVACIONES · VALIDACION"),
            ]},
        ],
        pills=[
            ("Códigos de glosa", "MOTIVO1 / CODGLOSA deben existir y estar activos en el maestro de motivos de glosa (FCGLO)."),
            ("Nace el expediente", "Al aplicar se crea la glosa (FGLO) con sus motivos; desde ahí sigue el proceso hermano Cartera · Glosas."),
            ("Desaplicar glosas", "No se puede si la auditoría ya contestó alguna glosa del recaudo ni si el periodo contable está cerrado."),
            ("Fecha Glosa‑Devol", "Fecha en que el pagador notificó la glosa; es obligatoria y distinta de la fecha de legalización."),
        ],
        accent="#e11d48",
    )

    # 8. Devoluciones pasos
    sketch(
        "recaudos_devoluciones_pasos_sketchnote.jpg", BRAND,
        "Devoluciones: los tres Pasos a Seguir y qué pasa después",
        "Ingreso DEVOLUCION. Solo facturas tipo F. El paso 0 se puede corregir; los pasos 1 y 2 son definitivos",
        [
            {"num": "PASO 0", "tit": "Solo devolver", "sub": "Retirar de la cuenta de cobro", "pal": "sky", "items": [
                ("Al aplicar:", "Retira la factura de la cuenta de cobro donde estaba radicada y la deja disponible para corregir."),
                ("Reversible:", "Sí: se puede desaplicar o retirar la factura."),
                ("Excel:", "N_FACTURA · VLRPAGO (+ MOTIVO1 y/o OBS si las variables lo exigen)"),
                ("Técnico:", "SPK_RETIRAFTR_DE_CXC → FCXCR"),
            ]},
            {"num": "PASO 1", "tit": "Devolver y anular", "sub": "La factura muere", "pal": "rose", "items": [
                ("Al aplicar:", "Retira la factura de la cuenta de cobro, la devuelve a facturación y la anula."),
                ("Reversible:", "No. Ni desaplicar ni retirar factura una vez cerrado."),
                ("Excel:", "N_FACTURA · VLRPAGO · MOTIVO1 · OBS"),
                ("Técnico:", "SPK_FINALIDAD_DEVOL (1) → ENT DEVFACT"),
            ]},
            {"num": "PASO 2", "tit": "Devolver y radicar", "sub": "Nueva cuenta de cobro", "pal": "amber", "items": [
                ("Al aplicar:", "Retira la factura de la cuenta actual y crea otra cuenta de cobro lista para radicar de nuevo."),
                ("Reversible:", "No. Ni desaplicar ni retirar factura una vez cerrado."),
                ("Excel:", "N_FACTURA · VLRPAGO · MOTIVO1 · OBS (igual al paso 1)"),
                ("Técnico:", "SPK_FINALIDAD_DEVOL (2) → nueva FCXC"),
            ]},
            {"num": "DESPUÉS", "tit": "Respuesta a devoluciones", "sub": "Administrativo → Respuesta Devoluciones", "pal": "green", "items": [
                ("Qué es:", "La bandeja donde cartera define para cada factura devuelta el código de respuesta, la respuesta y el paso (Soportar o Anular)."),
                ("Luego:", "Enviar a facturación o a una nueva cuenta de cobro."),
                ("No confundir:", "con la respuesta a glosas, que ocurre en auditoría."),
                ("Técnico:", "FCXCR · DEFINIR_FACTURA / ENVIAR_FACTURA"),
            ]},
        ],
        pills=[
            ("Solo tipo F", "La búsqueda de facturas en DEVOLUCION fuerza TIPO F; no entran glosas ni ratificaciones."),
            ("Motivos y observación", "Obligatorios cuando MOBSERVADEVOLFACTURA = SI (paso 0) y siempre en los pasos 1 y 2. La hoja no trae MOTIVO2."),
            ("Anular en abierto", "Un recaudo DEVOLUCION abierto con paso 1 o 2 no muestra el botón Anular; use Inactivar o Borrar todo."),
            ("Fecha Glosa‑Devol", "Fecha en que el pagador devolvió la factura; obligatoria."),
        ],
        accent="#d97706",
    )

    # 9. Aplicar efectos
    sketch(
        "recaudos_aplicar_efectos_sketchnote.jpg", BRAND,
        "Qué pasa cuando pulso Aplicar",
        "Primero los candados, después cartera, contabilidad y el estado final. Si algo falla, no queda nada a medias",
        [
            {"num": "1 · CANDADOS", "tit": "Antes de mover nada", "sub": "Validaciones previas", "pal": "slate", "items": [
                ("Periodo contable:", "el mes de la fecha debe existir y estar abierto."),
                ("Detalle:", "debe haber facturas asignadas y ninguna repetida."),
                ("Ajuste al peso:", "dentro del máximo configurado."),
                ("Impuestos:", "cada retención con desglose y cuenta contable vigente."),
                ("CXP:", "suma del cruce igual al valor de los ítems."),
                ("Técnico:", "APLICARPAGO · PRI · FPAGDI · FIMPDV"),
            ]},
            {"num": "2 · CARTERA", "tit": "Las facturas cambian", "sub": "Efecto en cuentas por cobrar", "pal": "sky", "items": [
                ("Pago:", "descuenta el saldo de cada factura en la cuenta de cobro."),
                ("Glosa:", "crea el expediente de glosa con motivos y, según el paso, lo envía y responde."),
                ("Devolución:", "retira la factura de la cuenta de cobro y, según el paso, la anula o la radica de nuevo."),
                ("Levantamiento:", "recupera el valor glosado."),
                ("Técnico:", "SPK_PAGOSCXC · FCXCD · FGLO · FCXCR"),
            ]},
            {"num": "3 · CONTABILIDAD", "tit": "Comprobante automático", "sub": "No hay botón aparte", "pal": "green", "items": [
                ("Asiento:", "se genera en el mismo acto (cuentas de cartera, banco/caja, impuestos, glosas, ajuste al peso)."),
                ("Se guarda:", "Contabilizado = Sí y Nro. Comprobante en la cabecera; cada línea queda marcada."),
                ("Excepción:", "casilla «¿No Contabiliza?» (permiso ChkNoContabilizaFPAG) para asientos que entran por otro módulo."),
                ("Imprimir:", "botones Pago y Comprobante."),
                ("Técnico:", "SPK_NC_CONTAB_CXC → MCP/MCH"),
            ]},
            {"num": "4 · ESTADO", "tit": "Recaudo Cerrado", "sub": "Y lo que se dispara después", "pal": "orange", "items": [
                ("Cabecera:", "pasa de Abierto a Cerrado; el filtro Aplicado lo muestra en Aplicados."),
                ("Glosas 4 y 6:", "la respuesta ya quedó asentada en cartera."),
                ("Glosas 3:", "falta pulsar Enviar Auditoría."),
                ("Devoluciones 1 y 2:", "anulación o nueva cuenta de cobro ya creadas."),
                ("Presupuesto:", "si la institución lo maneja, registra el recaudo presupuestal."),
            ]},
        ],
        pills=[
            ("Mensaje KO", "Si aparece «Periodo contable no existe o está cerrado», «Recaudo sin detalles» o «impuesto sin cuenta», corrija y vuelva a aplicar."),
            ("Nada a medias", "La aplicación es una sola transacción: o queda todo (cartera + contabilidad) o no queda nada."),
            ("Para deshacer", "Desaplicar, Anular o retirar una factura: vea el capítulo «Me equivoqué: ¿qué botón uso?»."),
            ("Qué no hace", "No radica cuentas de cobro, no genera la factura ni responde glosas en auditoría (salvo pasos 4 y 6)."),
        ],
        accent="#16a34a",
    )

    # 10. Corregir
    sketch(
        "recaudos_corregir_sketchnote.jpg", BRAND,
        "Me equivoqué: ¿qué botón uso?",
        "Depende de dos cosas: si el recaudo está Abierto o Cerrado y si el mes contable de su fecha sigue abierto",
        [
            {"num": "ABIERTO", "tit": "Todavía no aplicado", "sub": "Se corrige sin reversos", "pal": "sky", "items": [
                ("Quitar una factura:", "icono de papelera en la línea del detalle (permiso BRetiraFactura)."),
                ("Borrar todo:", "vacía el detalle y deja la cabecera lista para asignar de nuevo."),
                ("Inactivar:", "descarta un recaudo que no se va a procesar (permiso BInactivarFPAG)."),
                ("Anular:", "disponible en abierto salvo devoluciones con paso 1 o 2."),
                ("Técnico:", "QUITARFPAGD · BORRARTODO · INACTIVAR · ANULARPAGO"),
            ]},
            {"num": "CERRADO", "tit": "Desaplicar (clásico)", "sub": "Reabre el recaudo", "pal": "orange", "items": [
                ("Cuándo:", "recaudo aplicado y mes contable de su fecha todavía abierto. Permiso BDesaplicarPago."),
                ("Efecto:", "revierte cartera y contabilidad y el recaudo vuelve a Abierto para corregir."),
                ("Bloquea si:", "hay glosas ya contestadas en auditoría, notas crédito por descuentos, facturas retiradas o es devolución con paso 1 o 2."),
                ("Técnico:", "DESAPLICARPAGO → SPK_DESPAGOSCXC"),
            ]},
            {"num": "CERRADO", "tit": "Retirar una sola factura", "sub": "Sin reabrir el recaudo", "pal": "violet", "items": [
                ("Cuándo:", "recaudo aplicado de BANCOS, o de GLOSAS con paso 3 o 5. Permiso BRetiraFactura."),
                ("Efecto:", "revierte solo esa factura (su parte del comprobante) y la línea queda Retirada con su comprobante de retiro."),
                ("No aplica:", "devoluciones con paso 1 o 2 ni glosas 4 y 6."),
                ("Técnico:", "QUITARFPAGD → SPK_RETIRA_FACTURA_FPAGD"),
            ]},
            {"num": "MES CERRADO", "tit": "Desaplicar con aval", "sub": "Solo CAJA y BANCOS", "pal": "rose", "items": [
                ("Cuándo:", "el mes contable de la fecha del recaudo ya está cerrado. El Desaplicar clásico se oculta."),
                ("Qué pasa:", "no se reabre el periodo: se crea un comprobante de reversión, todas las facturas quedan Retiradas y el recaudo sigue Cerrado."),
                ("Aval:", "si la empresa lo exige, Contabilidad debe avalar antes (ver capítulo siguiente)."),
                ("Glosas y devoluciones:", "no se desaplican en mes cerrado."),
            ]},
        ],
        pills=[
            ("Anular en cerrado", "Anular revierte todo el recaudo aplicado (periodos abiertos); bloquea si ya hay facturas retiradas o el comprobante está con error."),
            ("Desaplicar vs Anular", "Desaplicar reabre para corregir; Anular lo cancela definitivamente. Ambos revierten cartera y contabilidad."),
            ("Glosas", "Desaplicar glosas se bloquea si auditoría ya respondió alguna; en mes cerrado no se permite."),
            ("Rastro", "Las líneas Retiradas guardan el número del comprobante de retiro (Nro. Comprobante R) para auditoría."),
        ],
        accent="#e11d48",
    )

    # 11. Aval periodo cerrado
    sketch(
        "recaudos_aval_periodo_cerrado_sketchnote.jpg", BRAND,
        "Desaplicar en periodo cerrado: el aval contable",
        "Cartera pide, Contabilidad avala, Cartera reversa sin reabrir el mes. Disponible en preversión (REQ 0100016348)",
        [
            {"num": "CUÁNDO", "tit": "Se activa el circuito", "sub": "Tres condiciones", "pal": "slate", "items": [
                ("Recaudo:", "CAJA o BANCOS, Cerrado (aplicado) y con comprobante contable."),
                ("Periodo:", "el mes contable de la Fecha de legalización ya está cerrado (cierre general o cierre de cartera)."),
                ("Pantalla:", "el Desaplicar clásico se oculta y aparece un aviso con el estado del aval."),
                ("Técnico:", "CONSULTA_PRI_RECAUDO · PRI.CERRADO / CERRADO_CARTERA"),
            ]},
            {"num": "PASO 01", "tit": "Cartera: Solicitar aval", "sub": "Botón ámbar con sello", "pal": "amber", "items": [
                ("Quién:", "Analista de cartera, desde Recaudos, con el recaudo seleccionado."),
                ("Efecto:", "la columna Aval del recaudo queda en Pendiente. Mientras tanto no se puede desaplicar."),
                ("Solo si:", "la empresa exige aval (variable REC_SOLICITA_AVAL = SI)."),
                ("Técnico:", "SOLICITAR_AVAL_RECAUDO → FPAG.AVALCONTABLE = Pendiente"),
            ]},
            {"num": "PASO 02", "tit": "Contabilidad: Avalar", "sub": "Contable → Aval recaudos", "pal": "teal", "items": [
                ("Pantalla:", "lista los recaudos Pendientes con tercero, valor, comprobante y quién lo solicitó."),
                ("Acción:", "seleccionar y pulsar Avalar seleccionados (permiso BAvalRecaudoConta). Sin permiso solo se consulta."),
                ("Efecto:", "Aval = Avalado, con usuario y fecha. El periodo histórico no se abre."),
                ("Técnico:", "LISTAR_RECAUDOS_AVAL_PENDIENTE · AVALAR_RECAUDO"),
            ]},
            {"num": "PASO 03", "tit": "Cartera: Desaplicar con aval", "sub": "Reverso sin reabrir el mes", "pal": "rose", "items": [
                ("Qué hace:", "crea el comprobante de reversión con fecha actual, deja todas las facturas del recaudo Retiradas y libera sus saldos en cartera."),
                ("El recaudo:", "sigue Cerrado; no se vuelve a aplicar. El jefe de cartera arma un recaudo nuevo con las facturas correctas."),
                ("Una sola vez:", "si ya tiene facturas retiradas, no se repite."),
                ("Técnico:", "RETIRO_MASIVO_CON_AVAL → SPK_REVERSAR_RECUADO · FPAGD.ESTADO = Retirada"),
            ]},
        ],
        pills=[
            ("Si REC_SOLICITA_AVAL ≠ SI", "No hay solicitud: el botón Desaplicar hace el mismo reverso y el aval lo registra el usuario que desaplica."),
            ("Glosas en mes cerrado", "No se desaplican: «Periodo de FPAG.FECHA cerrado: no se puede desaplicar glosas»."),
            ("Rastro", "Comprobante de reversión ligado al original (REFERENCIA3, lote REV) y Nro. Comprobante R en cada factura."),
            ("Versión", "Está en PREVERSION de IXONLINE/SQL; la liberada 2.0.7 todavía no lo trae. Confirmar en su instalación."),
        ],
        accent="#e11d48",
    )


if __name__ == "__main__":
    main()
