"""Envío del dictamen al desarrollador (SMTP de DevSoporte / Outlook)."""
import base64
import imaplib
import json
import os
import re
import shutil
import smtplib
import subprocess
import tempfile
import time
from datetime import date, datetime
from email.message import EmailMessage
from pathlib import Path

try:
    import os as _os, sys as _sys
    _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
    import sin_consola as _sc

    _sc.instalar()
except ImportError:
    pass

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
LOGO_SVG = os.path.join(ROOT, "app", "assets", "logo-ixcolombia.svg")
COPIA_DEV_SOPORTE = "jose.jimenez@ixcolombia.com"
LOGO_CID = "logo-ixcolombia"
LOGO_URL = "https://www.ixcolombia.com/dist/IX%20COLOMBIA.png"

BROWSER_CANDIDATES = [
    os.path.expandvars(r"%ProgramFiles%\Google\Chrome\Application\chrome.exe"),
    os.path.expandvars(r"%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"),
    os.path.expandvars(r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"),
    os.path.expandvars(r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"),
]

CSS_IMPRESION = """
@page { size: A4; margin: 10mm 12mm; }
html, body, .container, .brand-bar, th, .badge, .diagrama-incrustado, .df-node, .df-box, .df-gate, .df-flow {
  -webkit-print-color-adjust: exact !important;
  print-color-adjust: exact !important;
}
@media print {
  body { background: #fff8ee !important; padding: 8px !important; }
  .container { border: 1px solid #000 !important; padding: 1.5rem !important; max-width: none !important; }
  section { page-break-inside: auto; }
  #diagrama-flujo, .brand-head, header { page-break-inside: avoid; }
  th { background: #E67817 !important; color: #fff !important; }
}
"""


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


def _abs_repo(rel):
    rel = str(rel or "").strip().replace("\\", "/")
    if not rel:
        return ""
    if os.path.isabs(rel):
        return rel if os.path.isfile(rel) else ""
    return os.path.join(ROOT, rel.replace("/", os.sep))


def rutas_mockups_solicitud(sol):
    """Rutas relativas (/) declaradas en solicitud.json para adjuntar al correo."""
    if not isinstance(sol, dict):
        return []

    rels = []

    def add_rel(val):
        if not val:
            return
        if isinstance(val, (list, tuple)):
            for item in val:
                add_rel(item)
            return
        if isinstance(val, str):
            rel = val.strip().replace("\\", "/").lstrip("/")
            if rel and rel not in rels:
                rels.append(rel)

    add_rel((sol.get("contenido") or {}).get("mockups"))
    add_rel((sol.get("documento") or {}).get("mockups"))
    add_rel((sol.get("correo") or {}).get("adjuntosExtra"))
    return rels


def _colectar_mockups(sol):
    """Rutas absolutas de mockups declarados en solicitud.json (ZIP offline, no HTML suelto)."""
    paths = []
    seen = set()
    if not isinstance(sol, dict):
        return paths

    id_caso = ((sol.get("identificacion") or {}).get("idCaso") or "").strip()

    def add(val):
        if not val:
            return
        if isinstance(val, (list, tuple)):
            for item in val:
                add(item)
            return
        if isinstance(val, str):
            rel = val.strip().replace("\\", "/")
            abs_path = _abs_repo(rel)
            if not abs_path:
                return
            attach = abs_path
            if rel.lower().endswith(".html"):
                try:
                    import mockup_empaquetar as mockzip

                    attach = mockzip.empaquetar_mockup_html(abs_path, id_caso=id_caso)
                except Exception:
                    attach = abs_path
            elif rel.lower().endswith(".zip"):
                attach = abs_path
            if attach and attach not in seen and os.path.isfile(attach):
                seen.add(attach)
                paths.append(attach)

    for rel in rutas_mockups_solicitud(sol):
        add(rel)
    return paths


def _parrafo_mockups(mockups):
    if not mockups:
        return "", ""
    nombres = ", ".join(os.path.basename(p) for p in mockups)
    html = (
        '<p style="margin:0 0 10px;font-size:15px;line-height:1.65;">'
        "Asimismo se adjunta el <strong>mockup UX</strong> del requerimiento "
        f"(<em>{nombres}</em>): paquete <strong>ZIP offline</strong> con el HTML de la "
        "pantalla propuesta, las capturas del REQ y un archivo <code>LEEME.txt</code>."
        "</p>"
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        'style="margin:0 0 14px;background:#fff8f0;border:1px solid #ffb74d;border-radius:4px;">'
        "<tr><td style=\"padding:14px 16px;font-size:14px;line-height:1.6;color:#494F4C;\">"
        '<p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#CB500F;">'
        "Cómo ver el mockup (desarrollador)"
        "</p>"
        "<ol style=\"margin:0 0 0 18px;padding:0;\">"
        "<li style=\"margin:0 0 6px;\">Guarde el adjunto <strong>*-offline.zip</strong> "
        "(no intente previsualizar el HTML suelto en Outlook: las imágenes no cargan).</li>"
        "<li style=\"margin:0 0 6px;\">Descomprima el ZIP en una carpeta local "
        "(ej. Escritorio).</li>"
        "<li style=\"margin:0 0 6px;\">Dentro verá <code>mockup-*.html</code>, la carpeta "
        "<code>imagenes/</code> y <code>LEEME.txt</code>.</li>"
        "<li style=\"margin:0 0 6px;\">Abra el <strong>.html</strong> con Chrome o Edge "
        "(doble clic o arrastre al navegador).</li>"
        "<li style=\"margin:0;\">Lo resaltado en <strong>naranja</strong> indica controles o "
        "campos nuevos respecto al comportamiento actual; la columna «Hoy» muestra la captura "
        "del REQ cuando aplica.</li>"
        "</ol>"
        "</td></tr></table>"
        '<p style="margin:0 0 14px;font-size:13px;line-height:1.55;color:#6b6560;">'
        "El mockup es referencia visual y de flujo; la especificación formal sigue siendo "
        "el dictamen PDF/HTML adjunto."
        "</p>"
    )
    texto = (
        f"\n\n--- Mockup UX (adjunto: {nombres}) ---\n"
        "Paquete ZIP offline (HTML + carpeta imagenes/ + LEEME.txt).\n\n"
        "Como verlo:\n"
        "1) Guarde el archivo *-offline.zip (no abra solo un .html suelto desde el correo).\n"
        "2) Descomprima el ZIP en su PC.\n"
        "3) Abra el .html incluido con Chrome o Edge.\n"
        "4) Revise lo marcado en naranja (cambio propuesto) y la captura «Hoy» si aparece.\n"
        "5) Lea LEEME.txt dentro del ZIP si tiene dudas.\n\n"
        "La especificacion de implementacion sigue siendo el dictamen adjunto.\n"
    )
    return html, texto


def _find_navegadores():
    seen = []
    for path in BROWSER_CANDIDATES:
        if path and os.path.isfile(path) and path not in seen:
            seen.append(path)
    for name in ("chrome", "msedge"):
        found = shutil.which(name)
        if found and found not in seen:
            seen.append(found)
    return seen


def _find_navegador():
    navs = _find_navegadores()
    return navs[0] if navs else ""


def _logo_data_uri():
    if os.path.isfile(LOGO_PNG):
        raw = Path(LOGO_PNG).read_bytes()
        return "data:image/png;base64," + base64.b64encode(raw).decode("ascii")
    if os.path.isfile(LOGO_SVG):
        raw = Path(LOGO_SVG).read_bytes()
        return "data:image/svg+xml;base64," + base64.b64encode(raw).decode("ascii")
    return ""


def _preparar_html_impresion(html_path):
    """Copia lista para PDF: logo embebido y colores iguales a la pantalla."""
    texto = Path(html_path).read_text(encoding="utf-8")
    logo = _logo_data_uri()
    if logo:
        texto = texto.replace("../app/assets/logo-ixcolombia.png", logo)
        texto = texto.replace("app/assets/logo-ixcolombia.png", logo)
        texto = texto.replace("/app/assets/logo-ixcolombia.svg", logo)
        texto = texto.replace("app/assets/logo-ixcolombia.svg", logo)
    texto = re.sub(
        r'(<iframe\b[^>]*\ssrc=)(["\'])(/[^"\']*)(\2)',
        r"\1\2about:blank\4",
        texto,
        flags=re.I,
    )
    if "print-color-adjust" not in texto:
        if "</style>" in texto:
            texto = texto.replace("</style>", CSS_IMPRESION + "\n</style>", 1)
        else:
            texto = texto.replace("</head>", f"<style>{CSS_IMPRESION}</style></head>", 1)
    base = _dir_trabajo_chrome() if _sesion_no_interactiva() else tempfile.mkdtemp(prefix="qrystalos-ba-pdf-")
    dest = os.path.join(base, "dictamen-print.html")
    Path(dest).write_text(texto, encoding="utf-8")
    return dest


_ULTIMO_ERROR_NAVEGADOR = ""
PERFIL_USUARIO_PDF = r"C:\Users\JOSE MANUEL"


def _pdf_utilizable(path):
    return bool(path) and os.path.isfile(path) and os.path.getsize(path) > 1000


def _sesion_no_interactiva() -> bool:
    """El servicio QrystalosBA corre como SYSTEM, en otra sesión. Chrome no imprime ahí."""
    user = (os.environ.get("USERNAME") or "").strip().upper()
    profile = (os.environ.get("USERPROFILE") or "").replace("/", "\\").lower()
    if user in {"SYSTEM", "LOCAL SERVICE", "NETWORK SERVICE"} or profile.endswith("\\systemprofile"):
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        propia = ctypes.c_uint()
        if kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(propia)):
            activa = kernel32.WTSGetActiveConsoleSessionId()
            if activa != 0xFFFFFFFF and propia.value != activa:
                return True
    except Exception:
        pass
    return False


def _perfil_usuario_pdf() -> str:
    for candidato in (
        (os.environ.get("QRISTALOS_BOT_USERPROFILE") or "").strip(),
        PERFIL_USUARIO_PDF,
        (os.environ.get("USERPROFILE") or "").strip(),
    ):
        if candidato and os.path.isdir(candidato):
            return candidato
    return ""


def _permitir_usuario(path: str) -> None:
    """La carpeta la crea el servicio (SYSTEM). Chrome, en la sesión del usuario, tiene que poder usarla."""
    if not path or not _sesion_no_interactiva():
        return
    usuario = os.path.basename(_perfil_usuario_pdf())
    if not usuario:
        return
    subprocess.run(
        ["icacls", path, "/grant", f"{usuario}:(OI)(CI)M", "/T", "/C"],
        capture_output=True,
        timeout=20,
    )


def _dir_trabajo_chrome() -> str:
    if _sesion_no_interactiva():
        perfil = _perfil_usuario_pdf()
        raiz = os.path.join(perfil, "AppData", "Local", "Temp") if perfil else tempfile.gettempdir()
        os.makedirs(raiz, exist_ok=True)
        path = os.path.join(raiz, f"qrystalos-ba-chrome-{os.getpid()}-{time.time_ns()}")
        os.makedirs(path, exist_ok=True)
        _permitir_usuario(path)
        return path
    return tempfile.mkdtemp(prefix="qrystalos-ba-chrome-")


def _esperar_archivo(path: str, minimo: int, segundos: float = 5) -> bool:
    fin = time.time() + segundos
    while time.time() < fin:
        if path and os.path.isfile(path) and os.path.getsize(path) > minimo:
            return True
        time.sleep(0.25)
    return bool(path) and os.path.isfile(path) and os.path.getsize(path) > minimo


def _ejecutar_comando_navegador(cmd: list, timeout: int = 90) -> tuple[int, str]:
    if not _sesion_no_interactiva():
        try:
            proc = subprocess.run(cmd, check=False, timeout=timeout, capture_output=True)
        except subprocess.TimeoutExpired:
            return 1, f"Tiempo agotado ({timeout}s) esperando a Chrome."
        except OSError as exc:
            return 1, str(exc)
        out = ((proc.stdout or b"") + b"\n" + (proc.stderr or b"")).decode("utf-8", errors="replace")
        return proc.returncode, out.strip()[-800:]
    return _ejecutar_en_sesion_usuario(cmd, timeout)


def _ejecutar_en_sesion_usuario(cmd: list, timeout: int) -> tuple[int, str]:
    """El servicio no puede imprimir. La tarea corre Chrome en el escritorio del usuario."""
    usuario = os.path.basename(_perfil_usuario_pdf())
    if not usuario:
        return 1, "No hay perfil de usuario para lanzar Chrome."
    work = _dir_trabajo_chrome()
    vbs = os.path.join(work, "lanzar.vbs")
    done = os.path.join(work, "listo.txt")
    linea = subprocess.list2cmdline(cmd).replace('"', '""')
    Path(vbs).write_text(
        'Set sh = CreateObject("WScript.Shell")\r\n'
        f'sh.CurrentDirectory = "{work}"\r\n'
        f'codigo = sh.Run("{linea}", 0, True)\r\n'
        'Set fso = CreateObject("Scripting.FileSystemObject")\r\n'
        f'Set tf = fso.CreateTextFile("{done}", True)\r\n'
        "tf.WriteLine CStr(codigo)\r\n"
        "tf.Close\r\n",
        encoding="ascii",
        errors="replace",
    )
    tarea = f"QrystalosBA-PDF-{os.getpid()}-{time.time_ns()}"
    tr = subprocess.list2cmdline(["wscript.exe", "//nologo", "//B", vbs])
    create = subprocess.run(
        [
            "schtasks", "/Create", "/TN", tarea, "/TR", tr,
            "/SC", "ONCE", "/ST", "23:59", "/SD", "01/01/2099",
            "/RU", usuario, "/IT", "/F",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if create.returncode != 0:
        detalle = (create.stderr or create.stdout or "schtasks /Create").strip()
        return 1, detalle[:400]
    try:
        run = subprocess.run(
            ["schtasks", "/Run", "/TN", tarea],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if run.returncode != 0:
            detalle = (run.stderr or run.stdout or "schtasks /Run").strip()
            return 1, detalle[:400]
        fin = time.time() + timeout
        while time.time() < fin and not os.path.isfile(done):
            time.sleep(0.4)
        if not os.path.isfile(done):
            return 1, "Chrome no terminó en la sesión del usuario."
        try:
            codigo = int((Path(done).read_text(encoding="utf-8", errors="replace") or "0").strip() or "0")
        except ValueError:
            codigo = 0
        return codigo, ""
    finally:
        subprocess.run(
            ["schtasks", "/Delete", "/TN", tarea, "/F"],
            capture_output=True,
            text=True,
            timeout=20,
        )


def _html_a_pdf(html_path=None, http_url=None, dest_pdf=None):
    """Imprime HTML a PDF. La ruta de salida va absoluta: con --user-data-dir Chrome no resuelve rutas relativas."""
    global _ULTIMO_ERROR_NAVEGADOR
    http_url = (http_url or "").strip()
    if http_url.startswith("http"):
        url = http_url
        dest = dest_pdf or os.path.join(tempfile.gettempdir(), "qrystalos-ba-export.pdf")
    elif html_path:
        dest = dest_pdf or (os.path.splitext(html_path)[0] + ".pdf")
        try:
            impresion = _preparar_html_impresion(html_path)
        except OSError:
            impresion = html_path
        url = Path(impresion).resolve().as_uri()
    else:
        return ""
    dest = os.path.abspath(dest)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    navs = _find_navegadores()
    if not navs:
        _ULTIMO_ERROR_NAVEGADOR = "No se encontró Chrome ni Edge."
        return dest if _pdf_utilizable(dest) else ""
    flags_comunes = [
        "--disable-gpu",
        "--disable-extensions",
        "--disable-dev-shm-usage",
        "--no-first-run",
        "--no-default-browser-check",
        "--hide-scrollbars",
        "--no-pdf-header-footer",
        "--run-all-compositor-stages-before-draw",
        "--allow-file-access-from-files",
        "--no-sandbox",
    ]
    modos = ("--headless=new", "--headless", "--headless=old")
    last_err = ""
    for nav in navs:
        for modo in modos:
            work = _dir_trabajo_chrome()
            perfil = os.path.join(work, "perfil")
            salida = os.path.join(work, "salida")
            os.makedirs(perfil, exist_ok=True)
            os.makedirs(salida, exist_ok=True)
            tmp_pdf = os.path.join(salida, "dictamen.pdf")
            cmd = [
                nav,
                modo,
                *flags_comunes,
                f"--user-data-dir={perfil}",
                f"--print-to-pdf={tmp_pdf}",
                url,
            ]
            codigo, texto = _ejecutar_comando_navegador(cmd, 90)
            last_err = texto or f"Chrome terminó con código {codigo} y no escribió el PDF."
            if not _pdf_utilizable(tmp_pdf):
                _esperar_archivo(tmp_pdf, 1000, 5)
            fuente = tmp_pdf if _pdf_utilizable(tmp_pdf) else ""
            if fuente:
                if os.path.abspath(fuente) != os.path.abspath(dest):
                    try:
                        shutil.copy2(fuente, dest)
                    except OSError as exc:
                        _ULTIMO_ERROR_NAVEGADOR = str(exc)
                        return fuente
                if _pdf_utilizable(dest):
                    _ULTIMO_ERROR_NAVEGADOR = ""
                    return dest
    if _pdf_utilizable(dest):
        return dest
    _ULTIMO_ERROR_NAVEGADOR = (last_err or "Chrome no escribió el PDF.").strip()
    if last_err:
        try:
            Path(os.path.join(tempfile.gettempdir(), "qrystalos-ba-pdf-error.txt")).write_text(
                last_err, encoding="utf-8"
            )
        except OSError:
            pass
    return ""


def html_a_png(html_path=None, dest_png=None, window_width=1400, window_height=900, http_url=None):
    """Captura PNG de HTML local o URL http con Chrome/Edge headless."""
    global _ULTIMO_ERROR_NAVEGADOR
    http_url = (http_url or "").strip()
    if http_url.startswith("http"):
        url = http_url
        dest = dest_png or os.path.join(tempfile.gettempdir(), "qrystalos-ba-capture.png")
    elif html_path and os.path.isfile(html_path):
        dest = dest_png or (os.path.splitext(html_path)[0] + ".png")
        try:
            impresion = _preparar_html_impresion(html_path)
        except OSError:
            impresion = html_path
        url = Path(impresion).resolve().as_uri()
    else:
        return ""
    dest = os.path.abspath(dest)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    navs = _find_navegadores()
    if not navs:
        _ULTIMO_ERROR_NAVEGADOR = "No se encontró Chrome ni Edge."
        return ""
    flags = [
        "--disable-gpu",
        "--disable-extensions",
        "--no-first-run",
        "--hide-scrollbars",
        "--run-all-compositor-stages-before-draw",
        "--allow-file-access-from-files",
        "--no-sandbox",
        f"--window-size={int(window_width)},{int(window_height)}",
    ]
    last_err = ""
    for nav in navs:
        for modo in ("--headless=new", "--headless", "--headless=old"):
            work = _dir_trabajo_chrome()
            perfil = os.path.join(work, "perfil")
            os.makedirs(perfil, exist_ok=True)
            cmd = [
                nav,
                modo,
                *flags,
                f"--user-data-dir={perfil}",
                f"--screenshot={dest}",
                url,
            ]
            _codigo, texto = _ejecutar_comando_navegador(cmd, 90)
            last_err = texto
            if not (os.path.isfile(dest) and os.path.getsize(dest) > 500):
                _esperar_archivo(dest, 500, 5)
            if os.path.isfile(dest) and os.path.getsize(dest) > 500:
                _ULTIMO_ERROR_NAVEGADOR = ""
                return dest
    _ULTIMO_ERROR_NAVEGADOR = (last_err or "Chrome no escribió el PNG.").strip()
    return dest if os.path.isfile(dest) and os.path.getsize(dest) > 500 else ""


def dictamen_a_pdf(id_caso, html_path=None):
    """Genera dictamenes/{id}.pdf con el mismo aspecto del HTML. Lanza si no puede."""
    src = html_path or _dictamen_abs(id_caso)
    if not src:
        raise ValueError("No hay dictamen HTML para convertir a PDF.")
    dest = os.path.splitext(src)[0] + ".pdf"
    pdf = _html_a_pdf(src)
    if _pdf_utilizable(pdf):
        return pdf
    if _pdf_utilizable(dest):
        return dest
    raise ValueError(
        "No se pudo generar el PDF del dictamen (Chrome/Edge en modo impresión). "
        "No se adjunta HTML. Instale Chrome o Edge, reinicie el servidor QrystalosBA y reintente el envío."
    )


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
    mockups = _colectar_mockups(sol)
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
        "mockups": [p.replace("\\", "/") for p in mockups],
        "tieneMockups": bool(mockups),
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
    nombre_dev = (ctx.get("desarrollador") or "").strip()
    if os.path.isfile(path):
        sol = _read_json(path, {})
        sol["correo"] = payload
        if not nombre_dev:
            nombre_dev = ((sol.get("personas") or {}).get("desarrollador") or "").strip()
        _write_json(path, sol)

    # Un solo write: correo del desarrollador + marca del caso (evita que sync pise el mail).
    try:
        devs.registrar_envio(
            nombre_dev,
            payload["destinatario"],
            id_caso=id_caso,
            correo_enviado=payload["enviado"],
            fecha_envio=payload["fechaEnvio"],
            ultimo_envio=payload["ultimoEnvio"],
            reenvios=payload["reenvios"],
            destinatario=payload["destinatario"],
            via=payload["via"],
        )
    except ValueError as exc:
        print(f"WARN no se pudo guardar correo de {nombre_dev}: {exc}", flush=True)
        devs.marcar_envio_caso(
            id_caso,
            correo_enviado=payload["enviado"],
            fecha_envio=payload["fechaEnvio"],
            ultimo_envio=payload["ultimoEnvio"],
            reenvios=payload["reenvios"],
            destinatario=payload["destinatario"],
            via=payload["via"],
        )
    except OSError as exc:
        print(f"WARN error al escribir desarrolladores.json: {exc}", flush=True)

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
        from qrystalos_ba_db import get_db

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
    parrafo_html, parrafo_texto = _parrafo_mockups(ctx.get("mockups") or [])
    valores = {
        "nombre": ctx.get("desarrollador") or "",
        "idReq": ctx.get("idReq") or "",
        "cliente": ctx.get("cliente") or "",
        "modulo": ctx.get("modulo") or "",
        "rama": ctx.get("rama") or "—",
        "logo_src": f"cid:{LOGO_CID}",
        "parrafoMockups": parrafo_html,
    }
    asunto = _llenar(formal.get("asunto"), valores)
    texto = _llenar(formal.get("texto"), valores) + parrafo_texto
    plantilla = ""
    if os.path.isfile(PLANTILLA_HTML):
        with open(PLANTILLA_HTML, encoding="utf-8") as fh:
            plantilla = fh.read()
    html = _llenar(plantilla, valores) if plantilla else ""
    return asunto, texto, html


def _adjuntos(ctx):
    out = []
    html = _dictamen_abs(ctx["idCaso"])
    if html:
        out.append(html)
    for path in ctx.get("mockups") or []:
        abs_path = _abs_repo(path) if not os.path.isabs(str(path or "")) else path
        if abs_path and os.path.isfile(abs_path) and abs_path not in out:
            out.append(abs_path)
    return out


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
    tmp = tempfile.mkdtemp(prefix="qrystalos-ba-mail-")
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


def enviar(id_caso, correo=None, reenviar=False, display=False, desarrollador=None):
    ctx = contexto(id_caso)
    if desarrollador and str(desarrollador).strip():
        ctx["desarrollador"] = str(desarrollador).strip()
    if not ctx["idCaso"]:
        raise ValueError("Falta idCaso")
    if not ctx["tieneDictamen"]:
        raise ValueError("No hay dictamen para convertir a PDF. Genere dictamenes/{idCaso}.html primero.")
    dest = correo or ctx.get("destinatario") or ""
    dest = devs.validar_correo(dest)
    if not dest:
        raise ValueError("Falta el correo del desarrollador.")

    # Guardar YA en la lista (antes del SMTP), para que quede aunque falle el envío.
    if ctx.get("desarrollador"):
        try:
            devs.set_correo(ctx["desarrollador"], dest)
        except (ValueError, OSError) as exc:
            print(f"WARN set_correo previo a envío: {exc}", flush=True)

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
        "adjuntos": [os.path.basename(a) for a in adjuntos if a],
        "copia": copia_meta.get("carpeta") or copia_dir,
        "imap": copia_meta.get("imap"),
        "mensaje": ("Correo reenviado." if tipo == "reenviar" else "Correo enviado.")
        + f" Copia en correos/{ctx['idCaso']}/.",
        **guardado,
        "copias": _listar_copias(ctx["idCaso"]),
    }
