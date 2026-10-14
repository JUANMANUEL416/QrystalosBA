"""Empaqueta mockup HTML + capturas para uso offline (correo / desarrollador)."""
from __future__ import annotations

import os
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# /api/caso/{id}/imagen/{file} o URL absoluta al mismo path
_RE_API_IMG = re.compile(
    r"""(?P<prefix>src\s*=\s*["'])(?:https?://[^"']+)?/api/caso/(?P<caso>[^/"']+)/imagen/(?P<file>[^"']+)(?P<suffix>["'])""",
    re.IGNORECASE,
)
_RE_ACTIVO_IMG = re.compile(
    r"""src\s*=\s*["'](?:\.\./)?activo/[^/"']+/imagenes/(?P<file>[^"']+)["']""",
    re.IGNORECASE,
)
_RE_REL_IMG = re.compile(
    r"""src\s*=\s*["']\.\./imagenes/(?P<file>[^"']+)["']""",
    re.IGNORECASE,
)


def _id_caso_desde_ruta(html_path: Path) -> str:
    parts = html_path.as_posix().split("/")
    if "activo" in parts:
        i = parts.index("activo")
        if i + 1 < len(parts):
            return parts[i + 1]
    return ""


def _resolver_imagen(id_caso: str, nombre: str) -> Path | None:
    nombre = os.path.basename(nombre.replace("\\", "/"))
    if not nombre or not id_caso:
        return None
    p = ROOT / "activo" / id_caso / "imagenes" / nombre
    if p.is_file():
        return p
    return None


def _extraer_imagenes_referenciadas(html: str, id_caso: str) -> set[str]:
    files: set[str] = set()
    for m in _RE_API_IMG.finditer(html):
        cid = m.group("caso")
        if not id_caso or cid == id_caso:
            files.add(m.group("file"))
    for m in _RE_ACTIVO_IMG.finditer(html):
        files.add(m.group("file"))
    for m in _RE_REL_IMG.finditer(html):
        files.add(m.group("file"))
    return files


def reescribir_html_offline(html: str, id_caso: str, carpeta_imagenes: str = "imagenes") -> str:
    """Sustituye rutas /api/caso/.../imagen/ por carpeta relativa dentro del ZIP."""

    def repl_api(m: re.Match) -> str:
        f = m.group("file")
        return f'{m.group("prefix")}{carpeta_imagenes}/{f}{m.group("suffix")}'

    out = _RE_API_IMG.sub(repl_api, html)
    out = _RE_ACTIVO_IMG.sub(
        lambda m: f'src="{carpeta_imagenes}/{m.group("file")}"',
        out,
    )
    out = _RE_REL_IMG.sub(
        lambda m: f'src="{carpeta_imagenes}/{m.group("file")}"',
        out,
    )
    return out


def nombre_zip_para_html(html_abs: str | Path) -> Path:
    p = Path(html_abs)
    return p.with_name(f"{p.stem}-offline.zip")


def empaquetar_mockup_html(
    html_abs: str | Path,
    id_caso: str = "",
    zip_abs: str | Path | None = None,
) -> str:
    """
    Crea ZIP con HTML reescrito + carpeta imagenes/.
    Devuelve ruta absoluta del .zip.
    """
    html_path = Path(html_abs).resolve()
    if not html_path.is_file():
        raise FileNotFoundError(f"No existe mockup: {html_path}")

    id_caso = (id_caso or _id_caso_desde_ruta(html_path)).strip()
    html = html_path.read_text(encoding="utf-8")
    refs = _extraer_imagenes_referenciadas(html, id_caso)
    html_off = reescribir_html_offline(html, id_caso)

    zip_path = Path(zip_abs).resolve() if zip_abs else nombre_zip_para_html(html_path)
    zip_path.parent.mkdir(parents=True, exist_ok=True)

    leeme = (
        "Mockup UX — paquete offline (Qrystalos BA)\n\n"
        f"Caso: {id_caso or '(ver carpeta activo)'}\n"
        f"1. Descomprima esta carpeta en cualquier ruta.\n"
        f"2. Abra en el navegador: {html_path.name}\n"
        "3. Las capturas están en imagenes/ (rutas relativas).\n\n"
        "No abra solo el HTML suelto desde el correo: use este ZIP completo.\n"
    )

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(html_path.name, html_off.encode("utf-8"))
        zf.writestr("LEEME.txt", leeme.encode("utf-8"))
        for nombre in sorted(refs):
            src = _resolver_imagen(id_caso, nombre)
            if src and src.is_file():
                zf.write(src, f"imagenes/{nombre}")

    return str(zip_path)


def empaquetar_mockups_caso(id_caso: str) -> list[str]:
    """Genera ZIP offline para cada .html en activo/{id}/mockups/."""
    mock_dir = ROOT / "activo" / id_caso / "mockups"
    if not mock_dir.is_dir():
        return []
    zips: list[str] = []
    for html in sorted(mock_dir.glob("*.html")):
        try:
            zips.append(empaquetar_mockup_html(html, id_caso=id_caso))
        except OSError:
            continue
    return zips


def ruta_zip_offline(html_abs: str) -> str:
    """Ruta esperada del ZIP junto al HTML."""
    return str(nombre_zip_para_html(html_abs))
