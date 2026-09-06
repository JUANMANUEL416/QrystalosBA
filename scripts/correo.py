"""Envío del dictamen al desarrollador (SMTP de DevSoporte / Outlook)."""
import imaplib
import json
import os
import shutil
import smtplib
import subprocess
import tempfile
import time
from datetime import date, datetime
from email.message import EmailMessage
from pathlib import Path

import desarrolladores as devs

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
ENV_PATH = os.path.join(ROOT, ".env")
ACTIVO_ROOT = os.path.join(ROOT, "activo")
DICTAMENES_ROOT = os.path.join(ROOT, "dictamenes")
APROBADOS_ROOT = os.path.join(ROOT, "aprobados")
HISTORICO_PATH = os.path.join(ROOT, "historico", "registro.json")
CORREOS_ROOT = os.path.join(ROOT, "correos")
REGISTRO_CORREOS = os.path.join(CORREOS_ROOT, "registro.json")
PLANTILLA_HTML = os.path.join(ROOT, "config", "correo-plantilla.html")
LOGO_PNG = os.path.join(ROOT, "app", "assets", "logo-ixcolombia.png")
COPIA_DEV_SOPORTE = "jose.jimenez@ixcolombia.com"
LOGO_CID = "logo-ixcolombia"
LOGO_URL = "https://www.ixcolombia.com/dist/IX%20COLOMBIA.png"

EDGE_CANDIDATES = [
    os.path.expandvars(r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"),
    os.path.expandvars(r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"),
]


def _parse_env_file(path):
    values = {}
    if not os.path.isfile(path):
        return values
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if key:
                values[key] = val
    return values


def _read_json(path, default):
    if not os.path.isfile(path):
        return default
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _write_json(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def _llenar(plantilla, valores):
    texto = str(plantilla or "")
    for clave, valor in valores.items():
        texto = texto.replace("{{" + clave + "}}", str(valor or ""))
    return texto


def _solicitud_path(id_caso):
    return os.path.join(ACTIVO_ROOT, id_caso, "solicitud.json")


def _dictamen_abs(id_caso):
    for rel in (
        os.path.join(DICTAMENES_ROOT, f"{id_caso}.html"),
        os.path.join(APROBADOS_ROOT, id_caso, f"{id_caso}.html"),
    ):
        if os.path.isfile(rel):
            return rel
    return ""


def _find_edge():
    for path in EDGE_CANDIDATES:
        if path and os.path.isfile(path):
            return path
    return shutil.which("msedge")


def _html_a_pdf(html_path):
    edge = _find_edge()
    if not edge or not html_path:
        return ""
    pdf_path = os.path.splitext(html_path)[0] + ".pdf"
    url = Path(html_path).resolve().as_uri()
    profile = os.path.join(tempfile.gettempdir(), "quatec-edge-pdf")
    os.makedirs(profile, exist_ok=True)
    cmd = [
        edge,
        "--headless",
        "--disable-gpu",
        f"--user-data-dir={profile}",
        f"--print-to-pdf={pdf_path}",
        "--no-pdf-header-footer",
        url,
    ]
    try:
        subprocess.run(cmd, check=False, timeout=50, capture_output=True)
    except (subprocess.TimeoutExpired, OSError):
        return ""
    return pdf_path if os.path.isfile(pdf_path) and os.path.getsize(pdf_path) > 1000 else ""


def contexto(id_caso):
    id_caso = str(id_caso or "").strip()
    sol = _read_json(_solicitud_path(id_caso), {}) if id_caso else {}
    ident = sol.get("identificacion") or {}
    personas = sol.get("personas") or {}
    proyecto = sol.get("proyecto") or {}
    gestion = sol.get("gestion") or {}
    correo_sol = sol.get("correo") or {}

    data = devs.load_lista()
    dev, caso = devs.buscar_caso(id_caso=id_caso, id_req=ident.get("idReq"))
    if not caso:
        caso = {}
    if not dev:
        dev = {"nombre": personas.get("desarrollador") or "", "correo": ""}

    destinatario = (
        (correo_sol.get("destinatario") or "").strip()
        or (caso.get("destinatario") or "").strip()
        or (dev.get("correo") or "").strip()
    )
    enviado = bool(correo_sol.get("enviado") if "enviado" in correo_sol else caso.get("correoEnviado"))
    fecha = correo_sol.get("fechaEnvio") or caso.get("fechaEnvio") or ""
    dictamen = _dictamen_abs(id_caso)
    return {
        "idCaso": id_caso,
        "idReq": ident.get("idReq") or caso.get("idReq") or "",
        "desarrollador": personas.get("desarrollador") or dev.get("nombre") or "",
        "cliente": proyecto.get("nombre") or caso.get("cliente") or "",
        "modulo": proyecto.get("modulo") or caso.get("modulo") or "",
        "rama": gestion.get("rama") or caso.get("rama") or "",
        "destinatario": destinatario,
        "enviado": enviado,
        "fechaEnvio": fecha,
        "ultimoEnvio": correo_sol.get("ultimoEnvio") or caso.get("ultimoEnvio") or "",
        "reenvios": int(correo_sol.get("reenvios") or caso.get("reenvios") or 0),
        "via": correo_sol.get("via") or caso.get("via") or "",
        "dictamen": dictamen.replace("\\", "/") if dictamen else "",
        "tieneDictamen": bool(dictamen),
        "cuerpoFormal": data.get("cuerpoFormal") or devs.CUERPO_FORMAL,
        "copias": _listar_copias(id_caso),
    }


def estado(id_caso):
    ctx = contexto(id_caso)
    ctx["puedeEnviar"] = bool(ctx["idCaso"] and ctx["tieneDictamen"])
    ctx["ok"] = True
    return ctx


def _persistir(ctx, extra):
    id_caso = ctx["idCaso"]
    payload = {
        "enviado": bool(extra.get("enviado", ctx["enviado"])),
        "fechaEnvio": extra.get("fechaEnvio") or ctx.get("fechaEnvio") or "",
        "ultimoEnvio": extra.get("ultimoEnvio") or ctx.get("ultimoEnvio") or "",
        "reenvios": int(extra.get("reenvios", ctx.get("reenvios") or 0)),
        "destinatario": extra.get("destinatario") or ctx.get("destinatario") or "",
        "via": extra.get("via") or ctx.get("via") or "",
    }
    path = _solicitud_path(id_caso)
    if os.path.isfile(path):
        sol = _read_json(path, {})
        sol["correo"] = payload
        if payload["destinatario"] and (sol.get("personas") or {}).get("desarrollador"):
            pass
        _write_json(path, sol)

    if ctx.get("desarrollador") and payload["destinatario"]:
        try:
            devs.set_correo(ctx["desarrollador"], payload["destinatario"])
        except ValueError:
            pass

    devs.marcar_envio_caso(
        id_caso,
        correo_enviado=payload["enviado"],
        fecha_envio=payload["fechaEnvio"],
        ultimo_envio=payload["ultimoEnvio"],
        reenvios=payload["reenvios"],
        destinatario=payload["destinatario"],
        via=payload["via"],
    )

    hist = _read_json(HISTORICO_PATH, [])
    if isinstance(hist, list):
        for row in hist:
            if row.get("idCaso") == id_caso:
                row["correoEnviado"] = payload["enviado"]
                row["fechaEnvioCorreo"] = payload["fechaEnvio"]
                row["actualizado"] = datetime.now().isoformat(timespec="seconds")
                break
        _write_json(HISTORICO_PATH, hist)

    try:
        from quatec_db import get_db

        db = get_db()
        sol_db = db.get_solicitud(id_caso) or {}
        if sol_db:
            sol_db["correo"] = payload
            db.guardar_solicitud(id_caso, sol_db)
    except Exception:
        pass

    return {**ctx, **payload}


def marcar(id_caso, enviado=None, fecha_envio=None, destinatario=None, via="manual"):
    ctx = contexto(id_caso)
    if not ctx["idCaso"]:
        raise ValueError("Falta idCaso")
    hoy = date.today().isoformat()
    if destinatario:
        destinatario = devs.validar_correo(destinatario)
    extra = {
        "enviado": bool(enviado) if enviado is not None else ctx["enviado"],
        "fechaEnvio": fecha_envio or (hoy if enviado else ctx.get("fechaEnvio") or ""),
        "destinatario": destinatario or ctx.get("destinatario") or "",
        "via": via,
        "ultimoEnvio": ctx.get("ultimoEnvio") or "",
        "reenvios": ctx.get("reenvios") or 0,
    }
    if extra["enviado"] and not extra["fechaEnvio"]:
        extra["fechaEnvio"] = hoy
    return {"ok": True, **_persistir(ctx, extra)}


def _componer(ctx):
    formal = ctx.get("cuerpoFormal") or devs.CUERPO_FORMAL
    valores = {
        "nombre": ctx.get("desarrollador") or "",
        "idReq": ctx.get("idReq") or "",
        "cliente": ctx.get("cliente") or "",
        "modulo": ctx.get("modulo") or "",
        "rama": ctx.get("rama") or "—",
        "logo_src": f"cid:{LOGO_CID}",
    }
    asunto = _llenar(formal.get("asunto"), valores)
    texto = _llenar(formal.get("texto"), valores)
    plantilla = ""
    if os.path.isfile(PLANTILLA_HTML):
        with open(PLANTILLA_HTML, encoding="utf-8") as fh:
            plantilla = fh.read()
    html = _llenar(plantilla, valores) if plantilla else ""
    return asunto, texto, html


def _adjuntos(ctx):
    html = _dictamen_abs(ctx["idCaso"])
    if not html:
        return []
    pdf = _html_a_pdf(html)
    return [pdf] if pdf else [html]


def _enviar_outlook(para, asunto, cuerpo, adjuntos, display=False, cc="", html=""):
    payload = {
        "to": para,
        "cc": cc or "",
        "subject": asunto,
        "body": cuerpo,
        "html": html or "",
        "logo": LOGO_PNG if os.path.isfile(LOGO_PNG) else "",
        "attachments": adjuntos,
        "display": bool(display),
    }
    tmp = tempfile.mkdtemp(prefix="quatec-mail-")
    json_path = os.path.join(tmp, "mail.json")
    ps_path = os.path.join(tmp, "enviar.ps1")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False)
    with open(ps_path, "w", encoding="utf-8") as fh:
        fh.write(
            "$ErrorActionPreference = 'Stop'\n"
            "$payload = Get-Content -Raw -Encoding UTF8 -Path $args[0] | ConvertFrom-Json\n"
            "$ol = New-Object -ComObject Outlook.Application\n"
            "$mail = $ol.CreateItem(0)\n"
            "$mail.To = $payload.to\n"
            "if ($payload.cc) { $mail.CC = $payload.cc }\n"
            "$mail.Subject = $payload.subject\n"
            "$mail.Body = $payload.body\n"
            "if ($payload.html) { $mail.HTMLBody = $payload.html }\n"
            "if ($payload.logo) {\n"
            "  $logo = $mail.Attachments.Add([string]$payload.logo)\n"
            "  try { $logo.PropertyAccessor.SetProperty('http://schemas.microsoft.com/mapi/proptag/0x3712001F', 'logo-ixcolombia') } catch {}\n"
            "}\n"
            "foreach ($a in @($payload.attachments)) {\n"
            "  if ($a) { [void]$mail.Attachments.Add([string]$a) }\n"
            "}\n"
            "if ($payload.display) { $mail.Display() } else { $mail.Send() }\n"
        )
    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            ps_path,
            json_path,
        ],
        capture_output=True,
        text=True,
        timeout=40,
    )
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "Outlook no respondió").strip()
        raise RuntimeError(err[:400])
    return "outlook"


def _env(key, default=""):
    env = _parse_env_file(ENV_PATH)
    return (os.environ.get(key) or env.get(key) or default).strip()


def _smtp_cfg():
    host = _env("SMTP_HOST")
    if not host:
        return None
    return {
        "host": host,
        "port": int(_env("SMTP_PORT") or 587),
        "secure": _env("SMTP_SECURE").lower() == "true",
        "user": _env("SMTP_USER"),
        "password": _env("SMTP_PASS") or _env("SMTP_PASSWORD"),
        "from": _env("SMTP_FROM"),
        "cc": _env("SMTP_CC") or COPIA_DEV_SOPORTE,
    }


def _cc_si_aplica(para, cc):
    cc = (cc or "").strip()
    if not cc:
        return ""
    if para and para.strip().lower() == cc.lower():
        return ""
    return cc


def _armar_mensaje(para, asunto, cuerpo, adjuntos, remitente, cc="", html=""):
    msg = EmailMessage()
    msg["Subject"] = asunto
    msg["From"] = remitente
    msg["To"] = para
    if cc:
        msg["Cc"] = cc
    msg.set_content(cuerpo)
    if html:
        html_envio = html
        if not os.path.isfile(LOGO_PNG):
            html_envio = html.replace(f"cid:{LOGO_CID}", LOGO_URL)
        msg.add_alternative(html_envio, subtype="html")
        if os.path.isfile(LOGO_PNG):
            with open(LOGO_PNG, "rb") as fh:
                logo = fh.read()
            html_part = msg.get_payload()[1]
            html_part.add_related(logo, maintype="image", subtype="png", cid=LOGO_CID)
    for path in adjuntos:
        if not path or not os.path.isfile(path):
            continue
        with open(path, "rb") as fh:
            data = fh.read()
        nombre = os.path.basename(path)
        if nombre.lower().endswith(".pdf"):
            msg.add_attachment(data, maintype="application", subtype="pdf", filename=nombre)
        else:
            msg.add_attachment(data, maintype="text", subtype="html", filename=nombre)
    return msg


def _enviar_smtp(msg):
    cfg = _smtp_cfg()
    if not cfg:
        return None
    remitente = cfg["from"] or cfg["user"]
    if not remitente:
        raise RuntimeError("SMTP configurado pero falta SMTP_FROM o SMTP_USER.")
    if cfg["secure"]:
        smtp = smtplib.SMTP_SSL(cfg["host"], cfg["port"], timeout=30)
    else:
        smtp = smtplib.SMTP(cfg["host"], cfg["port"], timeout=30)
    with smtp:
        if not cfg["secure"]:
            smtp.starttls()
        if cfg["user"]:
            smtp.login(cfg["user"], cfg["password"])
        smtp.send_message(msg)
    return "smtp"


def _listar_copias(id_caso):
    carpeta = os.path.join(CORREOS_ROOT, id_caso)
    if not id_caso or not os.path.isdir(carpeta):
        return []
    copias = []
    for name in sorted(os.listdir(carpeta), reverse=True):
        meta_path = os.path.join(carpeta, name, "meta.json")
        if os.path.isfile(meta_path):
            meta = _read_json(meta_path, {})
            meta["carpeta"] = f"correos/{id_caso}/{name}"
            copias.append(meta)
    return copias


def _guardar_copia_local(ctx, tipo, para, asunto, cuerpo, adjuntos, msg, via):
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = os.path.join(CORREOS_ROOT, ctx["idCaso"], f"{stamp}-{tipo}")
    os.makedirs(dest, exist_ok=True)
    raw = msg.as_bytes()
    with open(os.path.join(dest, "mensaje.eml"), "wb") as fh:
        fh.write(raw)
    with open(os.path.join(dest, "cuerpo.txt"), "w", encoding="utf-8") as fh:
        fh.write(cuerpo)
    html_copia = None
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/html":
                html_copia = part.get_content()
                break
    if html_copia:
        with open(os.path.join(dest, "cuerpo.html"), "w", encoding="utf-8") as fh:
            fh.write(html_copia)
    for path in adjuntos:
        if path and os.path.isfile(path):
            shutil.copy2(path, os.path.join(dest, os.path.basename(path)))
    meta = {
        "idCaso": ctx["idCaso"],
        "idReq": ctx.get("idReq") or "",
        "tipo": tipo,
        "para": para,
        "cc": msg.get("Cc") or "",
        "asunto": asunto,
        "desarrollador": ctx.get("desarrollador") or "",
        "via": via,
        "fecha": datetime.now().isoformat(timespec="seconds"),
        "adjuntos": [os.path.basename(a) for a in adjuntos if a],
        "imap": None,
    }
    imap = _guardar_imap(raw)
    meta["imap"] = imap
    _write_json(os.path.join(dest, "meta.json"), meta)

    registro = _read_json(REGISTRO_CORREOS, [])
    if not isinstance(registro, list):
        registro = []
    registro.insert(0, {**meta, "carpeta": f"correos/{ctx['idCaso']}/{stamp}-{tipo}"})
    _write_json(REGISTRO_CORREOS, registro[:200])
    return dest, meta


def _guardar_imap(raw):
    if _env("SMTP_SAVE_SENT_COPY").lower() == "false":
        return {"saved": False, "reason": "disabled"}
    cfg = _smtp_cfg() or {}
    user = _env("IMAP_USER") or cfg.get("user") or ""
    password = _env("IMAP_PASS") or cfg.get("password") or ""
    host = _env("IMAP_HOST") or cfg.get("host") or ""
    if not user or not password or not host:
        return {"saved": False, "reason": "no-auth"}
    port = int(_env("IMAP_PORT") or 993)
    folders = [
        _env("IMAP_SENT_FOLDER"),
        "Sent",
        "INBOX.Sent",
        "Enviados",
        "Elementos enviados",
        "Sent Items",
    ]
    try:
        client = imaplib.IMAP4_SSL(host, port) if _env("IMAP_SECURE") != "false" else imaplib.IMAP4(host, port)
        try:
            client.login(user, password)
            when = imaplib.Time2Internaldate(time.time())
            last_err = ""
            for folder in folders:
                if not folder:
                    continue
                try:
                    typ, _ = client.append(folder, "\\Seen", when, raw)
                    if typ == "OK":
                        return {"saved": True, "folder": folder}
                except Exception as e:
                    last_err = str(e)
            return {"saved": False, "error": last_err or "sin carpeta Enviados"}
        finally:
            try:
                client.logout()
            except Exception:
                pass
    except Exception as e:
        return {"saved": False, "error": str(e)[:200]}


def enviar(id_caso, correo=None, reenviar=False, display=False):
    ctx = contexto(id_caso)
    if not ctx["idCaso"]:
        raise ValueError("Falta idCaso")
    if not ctx["tieneDictamen"]:
        raise ValueError("No hay dictamen HTML para adjuntar. Genere dictamenes/{idCaso}.html primero.")
    dest = correo or ctx.get("destinatario") or ""
    dest = devs.validar_correo(dest)
    if not dest:
        raise ValueError("Falta el correo del desarrollador.")

    asunto, cuerpo, html = _componer({**ctx, "desarrollador": ctx.get("desarrollador") or dest})
    adjuntos = _adjuntos(ctx)
    cfg = _smtp_cfg()
    remitente = (cfg.get("from") if cfg else "") or (cfg.get("user") if cfg else "") or "IX Colombia SAS"
    cc = _cc_si_aplica(dest, (cfg.get("cc") if cfg else "") or COPIA_DEV_SOPORTE)
    msg = _armar_mensaje(dest, asunto, cuerpo, adjuntos, remitente, cc=cc, html=html)

    via = None
    if not display:
        try:
            via = _enviar_smtp(msg)
        except Exception as e:
            if cfg:
                raise RuntimeError(f"SMTP falló: {e}") from e
    if not via:
        via = _enviar_outlook(dest, asunto, cuerpo, adjuntos, display=display, cc=cc, html=html)

    if display:
        return {
            "ok": True,
            "borrador": True,
            "via": via,
            "mensaje": "Borrador abierto en Outlook. Pulse Enviar allí.",
            **ctx,
            "destinatario": dest,
        }

    tipo = "reenviar" if (reenviar or ctx.get("enviado")) else "enviar"
    copia_dir, copia_meta = _guardar_copia_local(ctx, tipo, dest, asunto, cuerpo, adjuntos, msg, via)

    hoy = date.today().isoformat()
    extra = {
        "enviado": True,
        "fechaEnvio": hoy,
        "ultimoEnvio": datetime.now().isoformat(timespec="seconds"),
        "reenvios": (ctx.get("reenvios") or 0) + (1 if tipo == "reenviar" else 0),
        "destinatario": dest,
        "via": via,
    }
    guardado = _persistir(ctx, extra)
    return {
        "ok": True,
        "borrador": False,
        "adjunto": os.path.basename(adjuntos[0]) if adjuntos else "",
        "copia": copia_meta.get("carpeta") or copia_dir,
        "imap": copia_meta.get("imap"),
        "mensaje": ("Correo reenviado." if tipo == "reenviar" else "Correo enviado.")
        + f" Copia en correos/{ctx['idCaso']}/.",
        **guardado,
        "copias": _listar_copias(ctx["idCaso"]),
    }
