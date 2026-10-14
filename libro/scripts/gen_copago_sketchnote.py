import sys
import os
from PIL import Image, ImageDraw, ImageFont

def create_sketchnote():
    w, h = 1280, 720
    im = Image.new("RGB", (w, h), "#f8fafc")
    draw = ImageDraw.Draw(im)

    # Fuentes del sistema
    def get_font(size, bold=False):
        font_names = [
            "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
            "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"
        ]
        for f in font_names:
            if os.path.exists(f):
                try:
                    return ImageFont.truetype(f, size)
                except Exception:
                    pass
        return ImageFont.load_default()

    font_brand = get_font(13, True)
    font_title = get_font(25, True)
    font_sub = get_font(14, False)
    font_card_num = get_font(12, True)
    font_card_tit = get_font(15, True)
    font_card_sub = get_font(11, True)
    font_text = get_font(12, False)
    font_code = get_font(11, True)
    font_bar_tit = get_font(12, True)
    font_bar_val = get_font(11, False)

    # Fondo cabecera
    draw.rectangle([0, 0, w, 100], fill="#0f172a")
    draw.rectangle([0, 97, w, 100], fill="#ea580c") # acento naranja inferior

    # Pill institucional
    draw.rounded_rectangle([30, 16, 320, 36], radius=10, fill="#1e293b", outline="#334155", width=1)
    draw.text((42, 19), "QRYSTALOS IPS · CICLO FISCAL Y VENTANILLA", font=font_brand, fill="#38bdf8")

    # Título principal y subtítulo
    draw.text((30, 42), "Facturación Electrónica del Copago en Caja (DIAN / FEV)", font=font_title, fill="#ffffff")
    draw.text((30, 74), "Trazabilidad de punta a punta: Recaudo asistencial ➔ Motor SPK_CREA_FACTURA_POS_CAJA ➔ Cruce Cartera ➔ DIAN y Paciente", font=font_sub, fill="#cbd5e1")

    # 4 Columnas principales
    card_w = 285
    card_gap = 18
    start_x = 30
    card_top = 118
    card_h = 475

    cards_data = [
        {
            "num": "ETAPA 01",
            "tit": "Recaudo en Ventanilla",
            "sub": "Llegada del Copago / Moderadora",
            "color": "#0284c7",
            "color_bg": "#f0f9ff",
            "color_border": "#bae6fd",
            "items": [
                ("Origen Asistencial:", "Paciente con cita médica (CIT) o autorización (AUT) que liquida copago."),
                ("Traer Recibo:", "Importa comprobante TFCJ ➔ FCJ en la caja del turno activo."),
                ("Clasificación Fiscal:", "El concepto cruza con MOCC.CODIGOCPCJ o CPCJ.NDIAN=1."),
                ("Pago en Ventanilla:", "Liquidación por medios mixtos (efectivo, datáfono, transferencias)."),
                ("Tablas clave:", "FCJ · FCJD · MOCC · CPCJ · PCJ")
            ]
        },
        {
            "num": "ETAPA 02",
            "tit": "Motor de Facturación",
            "sub": "Emisión Automática FTR",
            "color": "#ea580c",
            "color_bg": "#fff7ed",
            "color_border": "#fed7aa",
            "items": [
                ("Disparador:", "Al pulsar 'Confirmar Recibo' (SPK_CIERRERECIBO_CAJA)."),
                ("Validación Previa:", "FACTURAPOS_ACTIVA='SI' y concepto marcado para electrónica."),
                ("Consecutivo DIAN:", "SPK_GENNUMEROFACTURA reserva número de FDIAN por sede."),
                ("Creación FTR:", "Inserta cabecera FTR (PROCEDENCIA='CAJA', contado) y FTRD."),
                ("Vínculo:", "FCJ.N_FACTURAPOS = @N_FACTURA y FCJ.RECAUDO = 1.")
            ]
        },
        {
            "num": "ETAPA 03",
            "tit": "Saneamiento y Cruce",
            "sub": "Cartera $0 y Contabilidad",
            "color": "#7c3aed",
            "color_bg": "#faf5ff",
            "color_border": "#e9d5ff",
            "items": [
                ("Generación CXC:", "SPK_ADMIN_CXC_CONTAB crea cuenta por cobrar particular (FCXC)."),
                ("Recaudo Inmediato:", "SPK_ADMIN_PAGOS genera FPAG y cruce FCJPCXC en el mismo instante."),
                ("Efecto en Cartera:", "Saldo neto queda en $0 (evita cuentas pendientes artificiales)."),
                ("Contabilización:", "SPK_NC_CONTAB_FTR asienta la factura en MCP/MCH comprobante oficial."),
                ("Trazabilidad clínica:", "Actualiza CIT.NFACTURA o HADMF 'COPAGOS'.")
            ]
        },
        {
            "num": "ETAPA 04",
            "tit": "DIAN y Paciente",
            "sub": "Emisión Fiscal y Entrega",
            "color": "#16a34a",
            "color_bg": "#f0fdf4",
            "color_border": "#bbf7d0",
            "items": [
                ("Encolamiento DIAN:", "La factura queda lista para timbrado XML, CUFE y QR en FTRE."),
                ("Diálogo en Pantalla:", "'Este recibo tiene factura asociada. ¿Qué desea imprimir?'"),
                ("Opciones del Cajero:", "• Tirilla de Recibo de Caja (FCJ)\n• Factura Electrónica (FTR)"),
                ("Formato Oficial:", "Imprime tirilla o carta CAJ01 con QR fiscal para entrega al usuario."),
                ("Auditoría:", "Reimpresión y consulta en Procaja / seguimiento contable.")
            ]
        }
    ]

    for idx, card in enumerate(cards_data):
        cx = start_x + idx * (card_w + card_gap)
        cy = card_top

        # Tarjeta contenedor
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=12, fill="#ffffff", outline=card["color_border"], width=2)

        # Header de tarjeta
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + 62], radius=12, fill=card["color_bg"])
        draw.rectangle([cx, cy + 50, cx + card_w, cy + 62], fill=card["color_bg"])
        draw.line([cx, cy + 62, cx + card_w, cy + 62], fill=card["color_border"], width=1)

        # Badge número
        draw.rounded_rectangle([cx + 12, cy + 8, cx + 75, cy + 24], radius=4, fill=card["color"])
        draw.text((cx + 18, cy + 10), card["num"], font=font_card_num, fill="#ffffff")

        # Título y subtítulo
        draw.text((cx + 12, cy + 28), card["tit"], font=font_card_tit, fill="#0f172a")
        draw.text((cx + 12, cy + 45), card["sub"], font=font_card_sub, fill=card["color"])

        # Contenido de la tarjeta
        item_y = cy + 74
        for label, val in card["items"]:
            # Viñeta decorativa
            draw.rectangle([cx + 12, item_y + 3, cx + 16, item_y + 13], fill=card["color"])
            draw.text((cx + 22, item_y), label, font=font_code, fill="#1e293b")
            
            # Texto descriptivo (multilínea si es necesario)
            lines = val.split("\n")
            line_y = item_y + 15
            for l in lines:
                # Partir texto largo
                words = l.split(" ")
                curr_line = ""
                for w_word in words:
                    test_line = (curr_line + " " + w_word).strip()
                    bbox = draw.textbbox((0, 0), test_line, font=font_text)
                    if (bbox[2] - bbox[0]) < (card_w - 32):
                        curr_line = test_line
                    else:
                        draw.text((cx + 22, line_y), curr_line, font=font_text, fill="#475569")
                        line_y += 15
                        curr_line = w_word
                if curr_line:
                    draw.text((cx + 22, line_y), curr_line, font=font_text, fill="#475569")
                    line_y += 15
            
            item_y = line_y + 8

        # Flecha conectora entre tarjetas (salvo la última)
        if idx < 3:
            arrow_x = cx + card_w + 3
            arrow_y = cy + 180
            draw.polygon([
                (arrow_x, arrow_y - 6),
                (arrow_x + 10, arrow_y),
                (arrow_x, arrow_y + 6)
            ], fill="#94a3b8")

    # Barra Inferior: Parámetros del Sistema (USVGS) y Reglas Clave
    bar_y = 608
    bar_h = 98
    draw.rounded_rectangle([start_x, bar_y, w - start_x, bar_y + bar_h], radius=10, fill="#ffffff", outline="#cbd5e1", width=1)

    # Header de la barra inferior
    draw.rounded_rectangle([start_x, bar_y, w - start_x, bar_y + 28], radius=10, fill="#f1f5f9")
    draw.rectangle([start_x, bar_y + 18, w - start_x, bar_y + 28], fill="#f1f5f9")
    draw.text((start_x + 16, bar_y + 7), "PARÁMETROS CRÍTICOS DEL SISTEMA (USVGS) QUE GOBIERNAN LA FACTURA DEL COPAGO", font=font_bar_tit, fill="#334155")

    # 4 Píldoras de parámetros
    pills = [
        ("FACTURAPOS_ACTIVA = 'SI'", "Activa la generación automática de la factura electrónica FEV al confirmar el recibo FCJ."),
        ("FACTU_COPA_MAYOR_SER = 'SI'", "Fuerza facturación a particular si el valor del copago supera o iguala al valor del servicio."),
        ("IDFORMATOFTR_CAJA = 'CAJ01'", "Formato de tirilla o media carta con código QR, resolución DIAN y CUFE para entrega al paciente."),
        ("Saneamiento Automático", "SPK_ADMIN_CXC_CONTAB + SPK_ADMIN_PAGOS cruzan la cartera en tiempo real (Saldo neto $0).")
    ]

    pill_w = 295
    pill_gap = 12
    p_x = start_x + 12
    p_y = bar_y + 36

    for p_tit, p_desc in pills:
        draw.rounded_rectangle([p_x, p_y, p_x + pill_w, p_y + 52], radius=6, fill="#f8fafc", outline="#e2e8f0", width=1)
        draw.text((p_x + 8, p_y + 6), p_tit, font=font_code, fill="#0284c7")
        
        # Word wrap para la descripción de la píldora
        words = p_desc.split(" ")
        c_l = ""
        desc_y = p_y + 21
        for word in words:
            t_l = (c_l + " " + word).strip()
            bbox = draw.textbbox((0, 0), t_l, font=font_bar_val)
            if (bbox[2] - bbox[0]) < (pill_w - 16):
                c_l = t_l
            else:
                draw.text((p_x + 8, desc_y), c_l, font=font_bar_val, fill="#64748b")
                desc_y += 13
                c_l = word
        if c_l:
            draw.text((p_x + 8, desc_y), c_l, font=font_bar_val, fill="#64748b")

        p_x += pill_w + pill_gap

    # Guardar imagen en alta calidad
    out_path = "img/factura_electronica_copago_caja_sketchnote.jpg"
    im.save(out_path, quality=95)
    print(f"Sketchnote guardada exitosamente en {out_path}")

if __name__ == "__main__":
    create_sketchnote()
