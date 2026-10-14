# -*- coding: utf-8 -*-
"""Revisión de un script SQL: estructura, sintaxis estática y diferencia de versiones.

No ejecuta el script. El catálogo se lee con SELECT (PREVERSION, última Cerrada, SQLIXD).
"""
from __future__ import annotations

import difflib
import hashlib
import json
import os
import re
import subprocess
import threading
from datetime import datetime
from pathlib import Path

try:
    import os as _os, sys as _sys
    _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
    import sin_consola as _sc

    _sc.instalar()
except ImportError:
    pass

ROOT = Path(__file__).resolve().parents[1]
REV_DIR = ROOT / "revisiones"
ENV = ROOT / ".env.local"

_NOMBRE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_BLOQUEO_PCEM = re.compile(
    r"(?i)\bxp_cmdshell\b|\bdrop\s+database\b|\bshutdown\b|\breconfigure\b"
)
_ID_REV = re.compile(r"^SQLR-\d{8}-\d{6}(?:-\d+)?$")
_HEADER = re.compile(
    r"(?im)^\s*(create|alter)\s+(?:or\s+alter\s+)?(proc|procedure|function|view|trigger)\s+"
    r"(?:\[?dbo\]?\s*\.\s*)?\[?([A-Za-z_][A-Za-z0-9_]*)\]?"
)
_PALABRA = re.compile(r"(?i)\b(begin|case|end)\b")
_PELIGRO = (
    (re.compile(r"(?i)\bxp_cmdshell\b"), "Llama a xp_cmdshell."),
    (re.compile(r"(?i)\bdrop\s+(database|table|procedure|proc|function|view|trigger)\b"), "Incluye DROP."),
    (re.compile(r"(?i)\btruncate\s+table\b"), "Incluye TRUNCATE TABLE."),
    (re.compile(r"(?i)\b(grant|deny|revoke)\b"), "Cambia permisos."),
    (re.compile(r"(?i)\bwhile\s+1\s*=\s*1\b"), "Tiene un ciclo WHILE 1 = 1."),
    (re.compile(r"(?i)\bopenrowset\b"), "Usa OPENROWSET."),
    (re.compile(r"(?i)\bsp_executesql\b|\bexec\s*\(\s*@"), "Ejecuta SQL dinámico."),
)


def _ahora() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def _id_nuevo() -> str:
    base = "SQLR-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    if not (REV_DIR / base).exists():
        return base
    n = 2
    while (REV_DIR / f"{base}-{n}").exists():
        n += 1
    return f"{base}-{n}"


def id_valido(valor: str) -> bool:
    return bool(_ID_REV.fullmatch(valor or ""))


def carpeta(id_rev: str) -> Path:
    if not id_valido(id_rev):
        raise ValueError("Identificador de revisión inválido.")
    return REV_DIR / id_rev


def _load_desaix():
    host = port = user = pwd = db = None
    if not ENV.is_file():
        raise RuntimeError("Falta .env.local para leer el catálogo.")
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("servidor9="):
            parts = line.split("=", 1)[1].split("|")
            if len(parts) < 4:
                raise RuntimeError("servidor9 incompleto en .env.local")
            host, port, user, pwd = parts[0], parts[1], parts[2], parts[3]
        elif line.startswith("dbservidor9="):
            db = line.split("=", 1)[1].strip()
    if not all([host, port, user, pwd, db]):
        raise RuntimeError("Falta servidor9 o dbservidor9 en .env.local")
    return f"{host},{port}", user, pwd, db


def _sqlcmd(query: str) -> str:
    server, user, pwd, db = _load_desaix()
    cmd = [
        "sqlcmd", "-S", server, "-U", user, "-P", pwd, "-d", db,
        "-C", "-f", "65001", "-y", "0", "-Q", query,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    salida = proc.stdout or ""
    if proc.returncode != 0 or salida.lstrip().startswith("Mensaje "):
        detalle = (proc.stderr or salida or "sqlcmd falló").strip()
        raise RuntimeError(detalle[:500])
    return salida


def _nombre_sql(valor: str) -> str:
    nombre = (valor or "").strip()
    if nombre.lower().endswith(".sql"):
        nombre = nombre[:-4]
    if "." in nombre:
        nombre = nombre.split(".")[-1].strip("[]")
    if not _NOMBRE.fullmatch(nombre):
        raise ValueError("El nombre del objeto solo puede tener letras, números y guion bajo.")
    return nombre


def versiones() -> dict:
    raw = _sqlcmd(
        "SET NOCOUNT ON; "
        "SELECT TOP 1 ID, IDANT, CONVERT(varchar(19), FECHA, 120) "
        "FROM dbo.VERSIONES "
        "WHERE PRODUCTO = N'Krystalos IPS' AND ESTADO = N'Cerrada' "
        "ORDER BY FECHA DESC;"
    )
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) >= 3 and re.fullmatch(r"\d+\.\d+(?:\.\d+)?", parts[0]):
            return {"liberada": parts[0], "anterior": parts[1], "fecha": parts[2] + (" " + parts[3] if len(parts) > 3 else "")}
    raise RuntimeError("No se pudo leer la última versión cerrada.")


def _hex_a_texto(raw: str) -> str | None:
    lineas = (raw or "").splitlines()
    inicio = 0
    for i, linea in enumerate(lineas):
        if re.fullmatch(r"-+", linea.strip()):
            inicio = i + 1
            break
    compacto = re.sub(r"[^0-9A-Fa-f]", "", "".join(lineas[inicio:]))
    if len(compacto) < 4 or len(compacto) % 2:
        return None
    data = bytes.fromhex(compacto)
    if len(data) >= 2 and data[1] == 0:
        return data.decode("utf-16le", errors="replace")
    return data.decode("cp1252", errors="replace")


def _texto_catalogo(id_version: str, nombre: str, columna: str) -> str | None:
    if columna not in ("INSTRUCCION", "QUERY"):
        raise ValueError("Columna no permitida.")
    if not re.fullmatch(r"[\w.\-]+", id_version):
        raise ValueError("Versión inválida.")
    nom = nombre.replace("'", "''")
    ver = id_version.replace("'", "''")
    consulta = f"""
SET NOCOUNT ON;
DECLARE @txt nvarchar(max);
SELECT @txt = STRING_AGG(CONVERT(nvarchar(max), {columna}), NCHAR(10)) WITHIN GROUP (ORDER BY ORDEN, IDUNICO)
FROM dbo.SQLIX
WHERE ID = N'{ver}'
  AND (NOMBRE = N'{nom}' OR NOMBRE = N'dbo.' + N'{nom}' OR NOMBRE LIKE N'%.' + N'{nom}');
IF @txt IS NOT NULL
    SELECT CONVERT(varchar(max), CONVERT(varbinary(max), @txt), 2);
"""
    return _hex_a_texto(_sqlcmd(consulta))


def _meta(nombre: str, ids: list[str]) -> list[dict]:
    nom = nombre.replace("'", "''")
    lista = ", ".join("N'" + i.replace("'", "''") + "'" for i in ids if re.fullmatch(r"[\w.\-]+", i))
    raw = _sqlcmd(
        "SET NOCOUNT ON; "
        "SELECT ID, NOMBRE, TIPO, IDUNICO, ORDEN, "
        "ISNULL(LEN(INSTRUCCION),0), ISNULL(LEN(QUERY),0) "
        "FROM dbo.SQLIX "
        f"WHERE ID IN ({lista}) "
        f"AND (NOMBRE = N'{nom}' OR NOMBRE = N'dbo.' + N'{nom}' OR NOMBRE LIKE N'%.' + N'{nom}') "
        "ORDER BY ID, ORDEN, IDUNICO;"
    )
    filas = []
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) < 7 or not parts[3].isdigit():
            continue
        filas.append({
            "id": parts[0],
            "nombre": parts[1],
            "tipo": parts[2],
            "idunico": int(parts[3]),
            "orden": int(parts[4]) if parts[4].lstrip("-").isdigit() else None,
            "lenInstruccion": int(parts[5]),
            "lenQuery": int(parts[6]),
        })
    return filas


def _detalle(idunico: int) -> dict:
    raw = _sqlcmd(
        "SET NOCOUNT ON; "
        "SELECT CLASE, COUNT(*), "
        "CONVERT(varchar(19), MIN(FECHA), 120), CONVERT(varchar(19), MAX(FECHA), 120) "
        "FROM dbo.SQLIXD "
        f"WHERE IDUNICO_SQLIX = {int(idunico)} "
        "GROUP BY CLASE;"
    )
    clases = {}
    patron = re.compile(
        r"^(\S+)\s+(\d+)\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})"
    )
    for line in raw.splitlines():
        m = patron.match(line.strip())
        if not m:
            continue
        clases[m.group(1)] = {"n": int(m.group(2)), "desde": m.group(3), "hasta": m.group(4)}
    return clases


def _texto_detalle(idunico: int, clase: str) -> str | None:
    if clase not in ("ORIGINAL", "ACTUALIZACION", "CORRECCION_POST_CIERRE"):
        raise ValueError("Clase no permitida.")
    orden = "ASC" if clase == "ORIGINAL" else "DESC"
    consulta = f"""
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @txt nvarchar(max);
SELECT TOP 1 @txt = QUERY
FROM dbo.SQLIXD
WHERE IDUNICO_SQLIX = {int(idunico)} AND CLASE = N'{clase}'
ORDER BY FECHA {orden}, ID {orden};
IF @txt IS NOT NULL
    SELECT CONVERT(varchar(max), CONVERT(varbinary(max), @txt), 2);
"""
    return _hex_a_texto(_sqlcmd(consulta))


def _hash(texto: str | None) -> str:
    if not texto:
        return ""
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()[:12]


def _sin_comentarios(sql: str) -> str:
    salida = []
    i = 0
    n = len(sql)
    while i < n:
        par = sql[i:i + 2]
        if par == "--":
            fin = sql.find("\n", i)
            salida.append("\n" if fin >= 0 else "")
            i = n if fin < 0 else fin
            continue
        if par == "/*":
            fin = sql.find("*/", i + 2)
            trozo = sql[i: n if fin < 0 else fin + 2]
            salida.append("\n" * trozo.count("\n"))
            i = n if fin < 0 else fin + 2
            continue
        if sql[i] == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'" and j + 1 < n and sql[j + 1] == "'":
                    j += 2
                    continue
                if sql[j] == "'":
                    j += 1
                    break
                j += 1
            salida.append("''")
            salida.append("\n" * sql[i:j].count("\n"))
            i = j
            continue
        salida.append(sql[i])
        i += 1
    return "".join(salida)


def _nombre_objeto(sql: str) -> dict:
    m = _HEADER.search(sql or "")
    if not m:
        return {"accion": "", "tipo": "", "nombre": ""}
    tipo = m.group(2).upper()
    if tipo == "PROC":
        tipo = "PROCEDURE"
    return {"accion": m.group(1).upper(), "tipo": tipo, "nombre": m.group(3)}


def _balance(sql: str) -> dict:
    limpio = _sin_comentarios(sql or "")
    begin = case = end = 0
    for pal in _PALABRA.findall(limpio):
        p = pal.lower()
        if p == "begin":
            begin += 1
        elif p == "case":
            case += 1
        elif case:
            case -= 1
        else:
            end += 1
    paren = 0
    minimo = 0
    for ch in limpio:
        if ch == "(":
            paren += 1
        elif ch == ")":
            paren -= 1
            minimo = min(minimo, paren)
    comilla_abierta = False
    i = 0
    bruto = sql or ""
    while i < len(bruto):
        if bruto.startswith("--", i):
            i = bruto.find("\n", i)
            i = len(bruto) if i < 0 else i
            continue
        if bruto.startswith("/*", i):
            fin = bruto.find("*/", i + 2)
            if fin < 0:
                return {
                    "begin": begin, "end": end, "parentesis": paren,
                    "comentarioAbierto": True, "comillaAbierta": False,
                }
            i = fin + 2
            continue
        if bruto[i] == "'":
            comilla_abierta = not comilla_abierta
        i += 1
    return {
        "begin": begin,
        "end": end,
        "parentesis": paren,
        "parentesisNegativo": minimo < 0,
        "comentarioAbierto": False,
        "comillaAbierta": comilla_abierta,
    }


def _sentencias(sql: str) -> list[tuple[int, str]]:
    limpio = _sin_comentarios(sql or "")
    bloques = re.split(r"(?im)^\s*go\s*$", limpio)
    salida = []
    linea = 1
    for bloque in bloques:
        for sent in bloque.split(";"):
            texto = sent.strip()
            if texto:
                salida.append((linea, texto))
            linea += sent.count("\n")
        linea += 1
    return salida


def revisar_estatica(sql: str) -> dict:
    cab = _nombre_objeto(sql)
    bal = _balance(sql)
    estructura = []
    if not cab["nombre"]:
        estructura.append("No aparece CREATE ni ALTER de procedimiento, función, vista o trigger.")
    if bal["begin"] != bal["end"]:
        estructura.append(f"BEGIN ({bal['begin']}) y END ({bal['end']}) no cuadran.")
    if bal["parentesis"] != 0 or bal.get("parentesisNegativo"):
        estructura.append("Los paréntesis no cuadran.")
    if bal["comentarioAbierto"]:
        estructura.append("Quedó un comentario /* sin cerrar.")
    if bal["comillaAbierta"]:
        estructura.append("Quedó una comilla sin cerrar.")
    avisos = []
    for linea, sent in _sentencias(sql):
        for patron, mensaje in _PELIGRO:
            if patron.search(sent):
                avisos.append({"linea": linea, "mensaje": mensaje})
                break
        es_delete = re.search(r"(?i)\bdelete\b", sent) and not re.search(r"(?i)\bwhere\b", sent)
        es_update = re.search(r"(?i)\bupdate\b.+\bset\b", sent) and not re.search(r"(?i)\bwhere\b", sent)
        if es_delete:
            avisos.append({"linea": linea, "mensaje": "DELETE sin WHERE en la misma sentencia."})
        if es_update:
            avisos.append({"linea": linea, "mensaje": "UPDATE sin WHERE en la misma sentencia."})
    return {
        "objeto": cab,
        "balance": bal,
        "estructura": estructura,
        "estructuraOk": not estructura,
        "avisos": avisos[:40],
    }


def _diff(base: str, nuevo: str, desde: str, hacia: str) -> dict:
    lineas = list(difflib.unified_diff(
        (base or "").splitlines(),
        (nuevo or "").splitlines(),
        fromfile=desde,
        tofile=hacia,
        lineterm="",
        n=2,
    ))
    agregadas = sum(1 for ln in lineas if ln.startswith("+") and not ln.startswith("+++"))
    quitadas = sum(1 for ln in lineas if ln.startswith("-") and not ln.startswith("---"))
    return {
        "desde": desde,
        "hacia": hacia,
        "agregadas": agregadas,
        "quitadas": quitadas,
        "iguales": (base or "") == (nuevo or ""),
        "patch": "\n".join(lineas),
    }


def _raices_locales() -> list[Path]:
    encontradas = []
    if (ROOT / "sql").is_dir():
        encontradas.extend((ROOT / "sql").glob("*.sql"))
    for base in (ROOT / "activo", ROOT / "solicitudes"):
        if base.is_dir():
            encontradas.extend(base.glob("*/sql/*.sql"))
    refe = ROOT / "sql_refe"
    if refe.is_dir():
        encontradas.extend(refe.glob("*.sql"))
        encontradas.extend(refe.glob("*/*.sql"))
    return encontradas


def _home_interactivo() -> Path:
    """Perfil de quien tiene la sesión. El servicio corre como LocalSystem y su home no es el del usuario."""
    cache = getattr(_home_interactivo, "_cache", None)
    if isinstance(cache, Path):
        return cache
    candidatos: list[Path] = []
    perfil = os.environ.get("USERPROFILE") or ""
    if perfil and "systemprofile" not in perfil.lower():
        candidatos.append(Path(perfil))
    try:
        proc = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "(Get-CimInstance Win32_ComputerSystem).UserName",
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
        lineas = [ln.strip() for ln in (proc.stdout or "").splitlines() if ln.strip()]
        nombre = lineas[-1].split("\\")[-1] if lineas else ""
        if nombre:
            import winreg

            raiz = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList",
            )
            for i in range(winreg.QueryInfoKey(raiz)[0]):
                with winreg.OpenKey(raiz, winreg.EnumKey(raiz, i)) as sub:
                    try:
                        imagen, _ = winreg.QueryValueEx(sub, "ProfileImagePath")
                    except OSError:
                        continue
                    imagen = os.path.expandvars(str(imagen))
                    if Path(imagen).name.lower() == nombre.lower():
                        candidatos.insert(0, Path(imagen))
                        break
    except Exception:
        pass
    for path in candidatos:
        if path.is_dir():
            _home_interactivo._cache = path  # type: ignore[attr-defined]
            return path
    fallback = Path.home()
    _home_interactivo._cache = fallback  # type: ignore[attr-defined]
    return fallback


def _resolver_ruta_usuario(texto: str) -> Path | None:
    """Acepta una ruta completa o Descargas\\archivo.sql, Escritorio\\archivo.sql."""
    q = (texto or "").strip().strip('"')
    directo = Path(q).expanduser()
    if directo.suffix.lower() == ".sql" and directo.is_file():
        return directo.resolve()
    partes = [p for p in q.replace("/", "\\").split("\\") if p]
    if not partes or not partes[-1].lower().endswith(".sql"):
        return None
    alias = {
        "descargas": ("Downloads", "Descargas"),
        "downloads": ("Downloads", "Descargas"),
        "escritorio": ("Desktop", "Escritorio"),
        "desktop": ("Desktop", "Escritorio"),
        "documentos": ("Documents", "Documentos"),
        "documents": ("Documents", "Documentos"),
    }
    home = _home_interactivo()
    if partes[0].lower() in alias:
        for carpeta in alias[partes[0].lower()]:
            path = home.joinpath(carpeta, *partes[1:])
            if path.is_file():
                return path.resolve()
    for carpeta in ("Downloads", "Descargas", "Desktop", "Escritorio", "Documents", "Documentos"):
        path = home / carpeta / partes[-1]
        if path.is_file():
            return path.resolve()
    return None


_DIALOGO_LOCK = threading.Lock()


def elegir_archivo_sql() -> str:
    """Abre el explorador de Windows para elegir un .sql. Vacío si cancela."""
    import solicitud_req as solreq

    dialogo = solreq.servidor_puede_dialogo_carpeta()
    if not dialogo.get("disponible"):
        raise RuntimeError(dialogo.get("motivo") or "No se puede abrir el explorador.")
    inicial = str(_home_interactivo())
    for carpeta in ("Downloads", "Descargas"):
        path = _home_interactivo() / carpeta
        if path.is_dir():
            inicial = str(path)
            break
    safe_i = inicial.replace("'", "")
    script = (
        "Add-Type -AssemblyName System.Windows.Forms; "
        "$f = New-Object System.Windows.Forms.OpenFileDialog; "
        "$f.Filter = 'Scripts SQL (*.sql)|*.sql'; "
        "$f.Title = 'Elija el script SQL'; "
        f"if (Test-Path -LiteralPath '{safe_i}') {{ $f.InitialDirectory = '{safe_i}' }}; "
        "if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $f.FileName }"
    )
    with _DIALOGO_LOCK:
        try:
            proc = subprocess.run(
                ["powershell", "-NoProfile", "-STA", "-Command", script],
                capture_output=True,
                text=True,
                timeout=180,
                creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0) or 0,
            )
        except subprocess.TimeoutExpired:
            return ""
    lineas = [ln.strip() for ln in (proc.stdout or "").splitlines() if ln.strip()]
    elegido = lineas[-1] if lineas else ""
    path = Path(elegido) if elegido else None
    if path and path.is_file() and path.suffix.lower() == ".sql":
        return str(path.resolve())
    return ""


def buscar_local(texto: str, limite: int = 30) -> list[dict]:
    q = (texto or "").strip().strip('"')
    if len(q) < 2:
        raise ValueError("Escriba al menos dos caracteres del nombre o una ruta .sql.")
    resuelto = _resolver_ruta_usuario(q)
    if resuelto:
        return [_ficha_archivo(resuelto)]
    clave = q.lower().replace(".sql", "")
    salida = []
    for path in _raices_locales():
        if clave in path.name.lower():
            salida.append(_ficha_archivo(path.resolve()))
        if len(salida) >= limite:
            break
    salida.sort(key=lambda f: f["nombre"].lower())
    return salida


def _ficha_archivo(path: Path) -> dict:
    rel = str(path)
    try:
        rel = str(path.relative_to(ROOT))
    except ValueError:
        pass
    return {
        "nombre": path.name,
        "ruta": str(path),
        "relativo": rel,
        "bytes": path.stat().st_size,
    }


def guardar_subido(nombre: str, texto: str) -> dict:
    """Guarda el .sql elegido en el navegador. El servicio no puede abrir el explorador."""
    base = Path(nombre or "").name
    if not base.lower().endswith(".sql"):
        raise ValueError("Elija un archivo .sql.")
    limpio = re.sub(r"[^\w.\- ]", "_", base).strip(" .") or "script.sql"
    if not limpio.lower().endswith(".sql"):
        limpio += ".sql"
    cuerpo = texto if isinstance(texto, str) else ""
    if not cuerpo.strip():
        raise ValueError("El archivo está vacío.")
    if len(cuerpo.encode("utf-8")) > 8_000_000:
        raise ValueError("El archivo supera 8 MB.")
    destino_dir = REV_DIR / "_subidos"
    destino_dir.mkdir(parents=True, exist_ok=True)
    destino = destino_dir / limpio
    destino.write_text(cuerpo, encoding="utf-8")
    return _ficha_archivo(destino.resolve())


def _leer_archivo(ruta: str) -> tuple[Path, str]:
    resuelto = _resolver_ruta_usuario(ruta)
    path = resuelto if resuelto else Path(ruta).expanduser()
    try:
        path = path.resolve()
    except OSError:
        path = path
    if path.suffix.lower() != ".sql" or not path.is_file():
        raise ValueError("Indique un archivo .sql que exista en este equipo.")
    if path.stat().st_size > 8_000_000:
        raise ValueError("El archivo supera 8 MB.")
    return path, path.read_text(encoding="utf-8", errors="replace")


def _cargar_catalogo(nombre: str) -> dict:
    vers = versiones()
    ids = ["PREVERSION", vers["liberada"], vers["anterior"]]
    filas = _meta(nombre, ids)
    if not filas:
        raise ValueError(
            f"{nombre} no está en PREVERSION, ni en {vers['liberada']}, ni en {vers['anterior']}."
        )
    por_id: dict[str, dict] = {}
    for fila in filas:
        por_id.setdefault(fila["id"], fila)
    pre = por_id.get("PREVERSION")
    lib = por_id.get(vers["liberada"])
    ant = por_id.get(vers["anterior"])
    cuerpo_pre = _texto_catalogo("PREVERSION", nombre, "INSTRUCCION") if pre else None
    cuerpo_lib = _texto_catalogo(vers["liberada"], nombre, "INSTRUCCION") if lib else None
    if not cuerpo_pre and not cuerpo_lib and ant:
        cuerpo_lib = _texto_catalogo(vers["anterior"], nombre, "INSTRUCCION")
        lib = ant
        vers = dict(vers)
        vers["usada"] = vers["anterior"]
    else:
        vers = dict(vers)
        vers["usada"] = vers["liberada"] if cuerpo_lib else ""
    detalle = {}
    original = actualizacion = None
    if pre:
        detalle = _detalle(pre["idunico"])
        if detalle.get("ORIGINAL"):
            original = _texto_detalle(pre["idunico"], "ORIGINAL")
        if detalle.get("ACTUALIZACION"):
            actualizacion = _texto_detalle(pre["idunico"], "ACTUALIZACION")
    query_pre = None
    if pre and detalle.get("ACTUALIZACION"):
        query_pre = _texto_catalogo("PREVERSION", nombre, "QUERY")
    return {
        "versiones": vers,
        "filas": filas,
        "pre": pre,
        "liberada": lib,
        "instruccionPre": cuerpo_pre,
        "instruccionLib": cuerpo_lib,
        "queryPre": query_pre,
        "detalle": detalle,
        "original": original,
        "actualizacion": actualizacion,
    }


def _resumen_detalle(cat: dict) -> dict:
    original = cat.get("original")
    actualizacion = cat.get("actualizacion")
    lib = cat.get("instruccionLib")
    query = cat.get("queryPre")
    return {
        "hay": bool(cat.get("detalle")),
        "clases": cat.get("detalle") or {},
        "originalIgualLiberada": bool(original and lib and _hash(original) == _hash(lib)),
        "actualizacionIgualQuery": bool(actualizacion and query and _hash(actualizacion) == _hash(query)),
        "originalBytes": len((original or "").encode("utf-8")),
        "actualizacionBytes": len((actualizacion or "").encode("utf-8")),
    }


def _credencial_pcem() -> tuple[str, str, str, str]:
    """Solo el servidor de pruebas y la base PCEM. Nunca DESAIX, CEM ni otra."""
    host = port = user = pwd = db = None
    if not ENV.is_file():
        raise RuntimeError("Falta .env.local para la base de pruebas.")
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("servidor1="):
            parts = line.split("=", 1)[1].split("|")
            if len(parts) < 4:
                raise RuntimeError("servidor1 incompleto en .env.local")
            host, port, user, pwd = parts[0], parts[1], parts[2], parts[3]
        elif line.startswith("dbservidor1="):
            db = line.split("=", 1)[1].strip()
    if not all([host, port, user, pwd, db]):
        raise RuntimeError("Falta servidor1 o dbservidor1 en .env.local")
    if db.upper() != "PCEM":
        raise RuntimeError("La base de pruebas configurada no es PCEM. No se aplicó el script.")
    return f"{host},{port}", user, pwd, db


def aplicar_en_pcem(sql: str, objeto: str) -> dict:
    """Aplica el script en PCEM para que SQL Server lo compile. No llama el procedimiento."""
    texto = sql or ""
    if not texto.strip():
        return {"corrido": False, "ok": False, "base": "PCEM", "mensaje": "No hay script para aplicar."}
    if _BLOQUEO_PCEM.search(_sin_comentarios(texto)):
        return {
            "corrido": False,
            "ok": False,
            "base": "PCEM",
            "mensaje": "No se envió a PCEM: el script trae un comando que no se aplica desde aquí (xp_cmdshell, DROP DATABASE, SHUTDOWN o RECONFIGURE).",
        }
    cab = _nombre_objeto(texto)
    if not cab["nombre"]:
        return {
            "corrido": False,
            "ok": False,
            "base": "PCEM",
            "mensaje": "No se envió a PCEM: no es un CREATE o ALTER de procedimiento, función, vista o trigger.",
        }
    server, user, pwd, db = _credencial_pcem()
    destino = REV_DIR / "_pcem_actual.sql"
    REV_DIR.mkdir(parents=True, exist_ok=True)
    destino.write_text(texto, encoding="utf-8")
    cmd = [
        "sqlcmd", "-S", server, "-U", user, "-P", pwd, "-d", db,
        "-C", "-b", "-I", "-f", "65001", "-i", str(destino),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    except subprocess.TimeoutExpired:
        return {"corrido": True, "ok": False, "base": db, "objeto": cab["nombre"], "mensaje": "PCEM no respondió en 3 minutos."}
    finally:
        destino.unlink(missing_ok=True)
    salida = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
    lineas = [ln for ln in salida.splitlines() if ln.strip() and "rows affected" not in ln.lower()]
    resumen = "\n".join(lineas[-12:])[:1500]
    if proc.returncode != 0:
        bajo = salida.lower()
        if "password of the account has expired" in bajo or "contraseña" in bajo and "expir" in bajo:
            resumen = "No se pudo entrar a PCEM: la clave de esa cuenta está vencida. Actualícela en la configuración local y vuelva a revisar."
        elif "login failed" in bajo or "error de inicio de sesión" in bajo:
            resumen = "No se pudo entrar a PCEM. Revise la cuenta del servidor de pruebas en la configuración local."
        return {
            "corrido": True,
            "ok": False,
            "base": db,
            "objeto": cab["nombre"],
            "mensaje": resumen or "SQL Server rechazó el script.",
        }
    cmd_ok = [
        "sqlcmd", "-S", server, "-U", user, "-P", pwd, "-d", db,
        "-C", "-h-1", "-W", "-Q",
        "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'dbo." + cab["nombre"] + "') IS NULL THEN 0 ELSE 1 END;",
    ]
    ver = subprocess.run(cmd_ok, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    existe = any(tok == "1" for tok in (ver.stdout or "").split())
    if not existe:
        return {
            "corrido": True,
            "ok": False,
            "base": db,
            "objeto": cab["nombre"],
            "mensaje": "El lote terminó, pero el objeto no quedó en PCEM.\n" + resumen,
        }
    return {
        "corrido": True,
        "ok": True,
        "base": db,
        "objeto": cab["nombre"] or objeto,
        "mensaje": "PCEM compiló el objeto. El procedimiento no se ejecutó, solo se creó o actualizó.",
    }


def preparar(modo: str, nombre: str = "", ruta: str = "") -> dict:
    modo = (modo or "").strip().lower()
    if modo not in ("local", "catalogo"):
        raise ValueError("El modo es local o catalogo.")
    if modo == "local":
        path, texto = _leer_archivo(ruta)
        cab = _nombre_objeto(texto)
        objeto = cab["nombre"] or path.stem
        cat = None
        try:
            if cab["nombre"]:
                cat = _cargar_catalogo(cab["nombre"])
        except ValueError:
            cat = None
        propuesto = texto
        base = (cat or {}).get("instruccionPre") or (cat or {}).get("instruccionLib") or ""
        desde = "PREVERSION" if (cat or {}).get("instruccionPre") else (
            "ultima-cerrada" if base else "sin-catalogo"
        )
        origen = {"modo": "local", "archivo": path.name, "ruta": str(path), "objeto": objeto}
    else:
        objeto = _nombre_sql(nombre)
        cat = _cargar_catalogo(objeto)
        propuesto = cat.get("instruccionPre") or ""
        base = cat.get("instruccionLib") or ""
        if not propuesto and not base:
            raise ValueError(f"{objeto} no tiene instrucción en PREVERSION ni en la última cerrada.")
        desde = "ultima-cerrada" if base else "sin-cerrada"
        origen = {"modo": "catalogo", "objeto": objeto}

    estatica = revisar_estatica(propuesto or base)
    diff = _diff(base, propuesto, desde, "PREVERSION" if modo == "catalogo" else "archivo-local")
    detalle_diff = None
    if cat and cat.get("original") and cat.get("actualizacion"):
        detalle_diff = _diff(cat["original"], cat["actualizacion"], "SQLIXD-ORIGINAL", "SQLIXD-ACTUALIZACION")
    vers = (cat or {}).get("versiones") or {}
    integridad = "sin catalogo"
    if cat:
        if cat.get("instruccionPre") and cat.get("instruccionLib"):
            integridad = "identicas" if _hash(cat["instruccionPre"]) == _hash(cat["instruccionLib"]) else "preversion distinta de la cerrada"
        elif cat.get("instruccionPre"):
            integridad = "solo PREVERSION"
        else:
            integridad = "solo en la cerrada o anterior; no esta en PREVERSION"

    id_rev = _id_nuevo()
    dest = REV_DIR / id_rev
    dest.mkdir(parents=True, exist_ok=False)
    (dest / "propuesto.sql").write_text(propuesto or "", encoding="utf-8")
    (dest / "base.sql").write_text(base or "", encoding="utf-8")
    (dest / "diff.patch").write_text(diff["patch"], encoding="utf-8")
    if detalle_diff:
        (dest / "detalle.patch").write_text(detalle_diff["patch"], encoding="utf-8")
    ficha = {
        "id": id_rev,
        "creadoEn": _ahora(),
        "origen": origen,
        "objeto": estatica["objeto"]["nombre"] or objeto,
        "versiones": vers,
        "integridad": integridad,
        "detalle": _resumen_detalle(cat) if cat else {"hay": False, "clases": {}},
        "estatica": estatica,
        "diff": {k: v for k, v in diff.items() if k != "patch"},
        "detalleDiff": None if not detalle_diff else {k: v for k, v in detalle_diff.items() if k != "patch"},
    }
    try:
        ficha["prueba"] = aplicar_en_pcem(propuesto or "", ficha["objeto"])
    except RuntimeError as exc:
        ficha["prueba"] = {"corrido": False, "ok": False, "base": "PCEM", "mensaje": str(exc)}
    (dest / "revision.json").write_text(json.dumps(ficha, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (dest / "INSTRUCCION-AGENTE.md").write_text(_instruccion(ficha), encoding="utf-8")
    (dest / "chat.json").write_text(
        json.dumps({"id": id_rev, "mensajes": []}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    append_chat(id_rev, "sistema", _texto_sistema(ficha))
    return vista(id_rev)


def _instruccion(ficha: dict) -> str:
    det = ficha.get("detalle") or {}
    vers = ficha.get("versiones") or {}
    return f"""# Revisión SQL {ficha['id']}

Objeto: {ficha.get('objeto') or '—'}
Modo: {ficha.get('origen', {}).get('modo')}
Última cerrada: {vers.get('liberada') or '—'} (anterior {vers.get('anterior') or '—'})
Integridad PREVERSION vs cerrada: {ficha.get('integridad')}

SQLIX guarda la instrucción completa de cada versión (ID = PREVERSION o el número cerrado).
SQLIXD es el detalle del cambio dentro de esa fila: CLASE ORIGINAL y CLASE ACTUALIZACION.
ORIGINAL suele ser la instrucción de la versión cerrada. ACTUALIZACION suele ser el QUERY editado por el desarrollador, no siempre el mismo texto que INSTRUCCION.

Hay detalle SQLIXD: {"sí" if det.get("hay") else "no"}.
ORIGINAL igual a la cerrada: {det.get("originalIgualLiberada")}
ACTUALIZACION igual al QUERY de PREVERSION: {det.get("actualizacionIgualQuery")}

Archivos de esta revisión:
- propuesto.sql: lo que se quiere validar (archivo local, o INSTRUCCION de PREVERSION)
- base.sql: contra qué se compara (INSTRUCCION de PREVERSION si el modo es local y existe; si no, la cerrada. En catálogo, la cerrada)
- diff.patch: diferencia unificada
- detalle.patch: solo si hay SQLIXD, ORIGINAL contra ACTUALIZACION

La estructura y la sintaxis estática ya están en revision.json. La prueba en PCEM, si se hizo, está en revision.json → prueba. No vuelva a ejecutar el script. No escriba en DESAIX ni en Qrystalos2.
Responda en chat.json si el cambio se ve correcto y qué efectos nocivos puede tener.
"""


def _texto_sistema(ficha: dict) -> str:
    est = ficha["estatica"]
    diff = ficha["diff"]
    lineas = [
        f"Revisión {ficha['id']} lista para el agente.",
        f"Objeto: {ficha.get('objeto') or 'sin nombre en el encabezado'}.",
        f"Comparación: {ficha.get('integridad')}.",
    ]
    if est["estructuraOk"]:
        lineas.append("Estructura: el encabezado y los balances revisados cuadran.")
    else:
        lineas.append("Estructura: " + " ".join(est["estructura"]))
    if est["avisos"]:
        lineas.append(f"Avisos estáticos: {len(est['avisos'])}.")
    else:
        lineas.append("Avisos estáticos: ninguno de los patrones revisados.")
    if diff["iguales"]:
        lineas.append("No hay diferencia de texto entre las dos versiones comparadas.")
    else:
        lineas.append(f"Diferencia: {diff['agregadas']} líneas agregadas y {diff['quitadas']} quitadas.")
    det = ficha.get("detalle") or {}
    if det.get("hay"):
        lineas.append("SQLIXD tiene el original y la actualización de esta fila.")
    else:
        lineas.append("Esta fila no tiene detalle en SQLIXD: no consta una edición guardada ahí.")
    prueba = ficha.get("prueba") or {}
    if prueba.get("ok"):
        lineas.append("PCEM compiló el objeto. No se ejecutó el procedimiento.")
    elif prueba.get("corrido"):
        lineas.append("PCEM rechazó el script: " + (prueba.get("mensaje") or ""))
    else:
        lineas.append("No se aplicó en PCEM: " + (prueba.get("mensaje") or ""))
    lineas.append("El agente revisa si el cambio es correcto y si puede tener efectos nocivos.")
    return "\n".join(lineas)


def append_chat(id_rev: str, autor: str, texto: str) -> dict:
    path = carpeta(id_rev) / "chat.json"
    datos = {"id": id_rev, "mensajes": []}
    if path.is_file():
        try:
            datos = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            datos = {"id": id_rev, "mensajes": []}
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto,
        "en": _ahora(),
    }
    datos.setdefault("mensajes", []).append(msg)
    path.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return msg


def _preview_patch(id_rev: str, nombre: str, tope: int = 160) -> str:
    path = carpeta(id_rev) / nombre
    if not path.is_file():
        return ""
    lineas = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if len(lineas) <= tope:
        return "\n".join(lineas)
    return "\n".join(lineas[:tope]) + f"\n… {len(lineas) - tope} líneas más en el archivo de la revisión."


def vista(id_rev: str) -> dict:
    dest = carpeta(id_rev)
    ficha = json.loads((dest / "revision.json").read_text(encoding="utf-8"))
    chat = {"mensajes": []}
    chat_path = dest / "chat.json"
    if chat_path.is_file():
        try:
            chat = json.loads(chat_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            chat = {"mensajes": []}
    bot = {}
    bot_path = dest / "bot.json"
    if bot_path.is_file():
        try:
            bot = json.loads(bot_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            bot = {}
    ficha["chat"] = chat
    ficha["bot"] = {
        "estado": bot.get("estado") or "",
        "error": bot.get("error") or "",
        "motivo": bot.get("motivo") or "",
    }
    ficha["diffPreview"] = _preview_patch(id_rev, "diff.patch")
    if (dest / "detalle.patch").is_file():
        ficha["detallePreview"] = _preview_patch(id_rev, "detalle.patch", 80)
    return ficha


def listar(limite: int = 20) -> list[dict]:
    if not REV_DIR.is_dir():
        return []
    items = []
    for path in REV_DIR.iterdir():
        if not path.is_dir() or not id_valido(path.name):
            continue
        ficha_path = path / "revision.json"
        if not ficha_path.is_file():
            continue
        try:
            ficha = json.loads(ficha_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        items.append({
            "id": path.name,
            "creadoEn": ficha.get("creadoEn") or "",
            "objeto": ficha.get("objeto") or "",
            "modo": (ficha.get("origen") or {}).get("modo") or "",
            "integridad": ficha.get("integridad") or "",
        })
    items.sort(key=lambda x: x["creadoEn"], reverse=True)
    return items[:limite]
