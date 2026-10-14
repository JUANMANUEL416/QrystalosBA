"""Administración local de servidores SQL. Las claves viven en .env.local."""
from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env.local"
ACCESO_PATH = ROOT / "data" / "acceso-servidores.json"
CONFIG_PATH = ROOT / "config" / "servidores-auditoria.json"

_SESIONES: dict[str, float] = {}
_FALLOS = {"n": 0, "hasta": 0.0}
_SESION_SEG = 8 * 3600
_ID_RE = re.compile(r"^servidor[A-Za-z0-9]+$")


def _leer_texto(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def _escribir_texto(path: Path, texto: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporal = path.with_suffix(path.suffix + ".tmp")
    temporal.write_text(texto, encoding="utf-8")
    temporal.replace(path)


def _acceso() -> dict | None:
    if not ACCESO_PATH.is_file():
        return None
    data = json.loads(ACCESO_PATH.read_text(encoding="utf-8"))
    if not data.get("usuario") or not data.get("hash") or not data.get("salt"):
        return None
    return data


def _hash_clave(clave: str, salt: bytes) -> str:
    digest = hashlib.scrypt(clave.encode("utf-8"), salt=salt, n=2**14, r=8, p=1)
    return digest.hex()


def configurado() -> bool:
    return _acceso() is not None


def crear_acceso(usuario: str, clave: str) -> None:
    usuario = (usuario or "").strip()
    if _acceso():
        raise ValueError("El acceso ya está creado.")
    if len(usuario) < 3:
        raise ValueError("El usuario de acceso necesita al menos 3 caracteres.")
    if len(clave or "") < 8:
        raise ValueError("La clave de acceso necesita al menos 8 caracteres.")
    salt = secrets.token_bytes(16)
    ACCESO_PATH.parent.mkdir(parents=True, exist_ok=True)
    _escribir_texto(
        ACCESO_PATH,
        json.dumps(
            {"usuario": usuario, "salt": salt.hex(), "hash": _hash_clave(clave, salt)},
            ensure_ascii=False,
            indent=2,
        ),
    )


def _bloquear_si_hace_falta() -> None:
    if _FALLOS["n"] >= 5 and time.time() < _FALLOS["hasta"]:
        raise ValueError("Demasiados intentos. Espere un minuto e intente de nuevo.")


def entrar(usuario: str, clave: str) -> str:
    _bloquear_si_hace_falta()
    data = _acceso()
    if not data:
        raise ValueError("Primero cree el usuario de acceso.")
    salt = bytes.fromhex(data["salt"])
    esperado = data["hash"]
    recibido = _hash_clave(clave or "", salt)
    usuario_ok = hmac.compare_digest((usuario or "").strip(), data["usuario"])
    clave_ok = hmac.compare_digest(recibido, esperado)
    if not (usuario_ok and clave_ok):
        _FALLOS["n"] += 1
        if _FALLOS["n"] >= 5:
            _FALLOS["hasta"] = time.time() + 60
        raise ValueError("Usuario o clave incorrectos.")
    _FALLOS["n"] = 0
    _FALLOS["hasta"] = 0.0
    token = secrets.token_urlsafe(32)
    _SESIONES[token] = time.time() + _SESION_SEG
    return token


def salir(token: str) -> None:
    _SESIONES.pop(token or "", None)


def sesion_valida(token: str) -> bool:
    if not token:
        return False
    ahora = time.time()
    vencidas = [k for k, exp in _SESIONES.items() if exp < ahora]
    for k in vencidas:
        _SESIONES.pop(k, None)
    return _SESIONES.get(token, 0) >= ahora


def _catalogo() -> dict:
    if not CONFIG_PATH.is_file():
        return {"actualizado": "", "nota": "", "servidores": []}
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def _guardar_catalogo(data: dict) -> None:
    data["actualizado"] = time.strftime("%Y-%m-%d")
    data["nota"] = (
        "Credenciales en .env.local (host|puerto|usuario|clave). "
        "No guardar claves aquí. baseDatosEnv apunta a la variable con el nombre por defecto de BD."
    )
    _escribir_texto(CONFIG_PATH, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def _leer_env() -> tuple[dict[str, dict], dict[str, str]]:
    cred: dict[str, dict] = {}
    dbs: dict[str, str] = {}
    for line in _leer_texto(ENV_PATH).splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, val = raw.split("=", 1)
        key = key.strip()
        if key.startswith("dbservidor"):
            dbs[key] = val.strip()
        elif _ID_RE.match(key) and "|" in val:
            parts = val.split("|")
            if len(parts) >= 4:
                cred[key] = {
                    "host": parts[0].strip(),
                    "puerto": parts[1].strip(),
                    "usuario": parts[2].strip(),
                    "clave": "|".join(parts[3:]),
                }
    return cred, dbs


def _reescribir_env(cambios: dict[str, str | None]) -> None:
    lineas = _leer_texto(ENV_PATH).splitlines()
    vistas: set[str] = set()
    salida: list[str] = []
    for line in lineas:
        raw = line.strip()
        if raw and not raw.startswith("#") and "=" in raw:
            key = raw.split("=", 1)[0].strip()
            if key in cambios:
                vistas.add(key)
                if cambios[key] is None:
                    continue
                salida.append(f"{key}={cambios[key]}")
                continue
        salida.append(line)
    for key, val in cambios.items():
        if key not in vistas and val is not None:
            salida.append(f"{key}={val}")
    texto = "\n".join(salida).rstrip() + "\n"
    _escribir_texto(ENV_PATH, texto)


def _lista_bases(texto: str) -> list[str]:
    return [p.strip() for p in (texto or "").split(",") if p.strip()]


def _bases_de(meta: dict, db_env: str) -> list[str]:
    guardadas = [b for b in (meta.get("bases") or []) if str(b).strip()]
    if guardadas:
        return [str(b).strip() for b in guardadas]
    return _lista_bases(db_env)


def listar() -> list[dict]:
    cred, dbs = _leer_env()
    nombres = {s.get("id"): s for s in (_catalogo().get("servidores") or []) if s.get("id")}
    items = []
    for sid, row in sorted(cred.items()):
        meta = nombres.get(sid) or {}
        db_key = meta.get("baseDatosEnv") or f"db{sid}"
        bases = _bases_de(meta, dbs.get(db_key, ""))
        items.append(
            {
                "id": sid,
                "nombre": meta.get("nombre") or sid,
                "host": row["host"],
                "puerto": row["puerto"],
                "usuario": row["usuario"],
                "base": bases[0] if bases else "",
                "bases": bases,
                "soloLectura": bool(meta.get("soloLectura", True)),
                "tieneClave": bool(row["clave"]),
            }
        )
    return items


def detalle(servidor_id: str) -> dict:
    sid = (servidor_id or "").strip()
    cred, dbs = _leer_env()
    if sid not in cred:
        raise ValueError("Servidor no encontrado.")
    meta = next((s for s in (_catalogo().get("servidores") or []) if s.get("id") == sid), {})
    db_key = meta.get("baseDatosEnv") or f"db{sid}"
    row = cred[sid]
    bases = _bases_de(meta, dbs.get(db_key, ""))
    return {
        "id": sid,
        "nombre": meta.get("nombre") or sid,
        "host": row["host"],
        "puerto": row["puerto"],
        "usuario": row["usuario"],
        "clave": row["clave"],
        "base": ", ".join(bases),
        "bases": bases,
        "soloLectura": bool(meta.get("soloLectura", True)),
    }


def _validar(sid: str, host: str, puerto: str, usuario: str, base: str) -> None:
    if not _ID_RE.match(sid):
        raise ValueError("El identificador debe empezar por servidor y seguir con letras o números. Ejemplo: servidor9.")
    for texto in (sid, host, puerto, usuario, base):
        if "\n" in texto or "\r" in texto:
            raise ValueError("Los datos del servidor no pueden llevar saltos de línea.")
    if not host or not puerto or not usuario or not base:
        raise ValueError("Host, puerto, usuario SQL y base de datos son obligatorios.")
    if not puerto.isdigit():
        raise ValueError("El puerto debe ser numérico.")


def guardar(payload: dict) -> dict:
    sid = (payload.get("id") or "").strip()
    host = (payload.get("host") or "").strip()
    puerto = (payload.get("puerto") or "").strip()
    usuario = (payload.get("usuario") or "").strip()
    base = (payload.get("base") or "").strip()
    nombre = (payload.get("nombre") or sid).strip() or sid
    clave = payload.get("clave")
    solo = bool(payload.get("soloLectura", True))
    _validar(sid, host, puerto, usuario, base)
    cred, _dbs = _leer_env()
    if clave is None or clave == "":
        if sid not in cred:
            raise ValueError("La clave SQL es obligatoria al crear el servidor.")
        clave = cred[sid]["clave"]
    elif "\n" in clave or "\r" in clave:
        raise ValueError("La clave no puede llevar saltos de línea.")
    bases = _lista_bases(base)
    db_key = f"db{sid}"
    _reescribir_env(
        {
            sid: f"{host}|{puerto}|{usuario}|{clave}",
            db_key: bases[0],
        }
    )
    cat = _catalogo()
    servidores = [s for s in (cat.get("servidores") or []) if s.get("id") != sid]
    servidores.append(
        {
            "id": sid,
            "nombre": nombre,
            "credencialEnv": sid,
            "baseDatosEnv": db_key,
            "bases": bases,
            "soloLectura": solo,
        }
    )
    cat["servidores"] = servidores
    _guardar_catalogo(cat)
    return {"id": sid, "nombre": nombre}


def quitar(servidor_id: str) -> None:
    sid = (servidor_id or "").strip()
    if not _ID_RE.match(sid):
        raise ValueError("Identificador no válido.")
    cred, _dbs = _leer_env()
    if sid not in cred:
        raise ValueError("Servidor no encontrado.")
    _reescribir_env({sid: None, f"db{sid}": None})
    cat = _catalogo()
    cat["servidores"] = [s for s in (cat.get("servidores") or []) if s.get("id") != sid]
    _guardar_catalogo(cat)


def _ruta_qrystalos2() -> Path:
    rutas = json.loads((ROOT / "config" / "rutas.json").read_text(encoding="utf-8"))
    base = (rutas.get("qrystalos2") or "").strip()
    if not base:
        raise ValueError("Falta la ruta de Qrystalos2 en la configuración.")
    path = Path(base) / ".env.local"
    if not path.is_file():
        raise ValueError("Qrystalos2 no tiene .env.local.")
    return path


def _leer_origen(path: Path) -> list[dict]:
    nombre = ""
    filas: dict[str, dict] = {}
    dbs: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        raw = line.strip()
        if not raw:
            continue
        if raw.startswith("#"):
            marca = re.search(r"---\s*(.+?)\s*---", raw)
            if marca:
                etiqueta = re.sub(r"^Servidor\s+\d*\s*", "", marca.group(1), flags=re.I).strip(" -")
                nombre = etiqueta or marca.group(1).strip()
            continue
        if "=" not in raw:
            continue
        key, val = raw.split("=", 1)
        key = key.strip()
        if key.startswith("dbservidor"):
            dbs[key] = val.strip()
        elif _ID_RE.match(key) and "|" in val:
            parts = val.split("|")
            if len(parts) >= 4:
                filas[key] = {
                    "id": key,
                    "nombre": nombre or key,
                    "host": parts[0].strip(),
                    "puerto": parts[1].strip(),
                    "usuario": parts[2].strip(),
                    "clave": "|".join(parts[3:]),
                }
                nombre = ""
    for sid, row in filas.items():
        row["bases"] = _lista_bases(dbs.get(f"db{sid}", ""))
    return list(filas.values())


def _mismo_equipo(a: dict, b: dict) -> bool:
    return a["host"].lower() == b["host"].lower() and str(a["puerto"]) == str(b["puerto"])


def _principal(ids: list[str]) -> str:
    orden = [
        "servidor1",
        "servidor2",
        "servidor5",
        "servidor9",
        "servidorHcodazzi",
        "servidor3",
        "servidor4",
        "servidor7",
        "servidor8",
        "servidor10",
        "servidor11",
    ]
    for sid in orden:
        if sid in ids:
            return sid
    return sorted(ids)[0]


def _id_libre(preferido: str, nombre: str, ocupados: set[str]) -> str:
    if preferido not in ocupados and _ID_RE.match(preferido):
        return preferido
    slug = re.sub(r"[^A-Za-z0-9]", "", nombre or "")
    candidato = "servidor" + slug if slug and not slug.lower().startswith("servidor") else slug
    if candidato and candidato not in ocupados and _ID_RE.match(candidato):
        return candidato
    n = 20
    while f"servidor{n}" in ocupados:
        n += 1
    return f"servidor{n}"


def deduplicar() -> dict:
    """Un servidor por host y puerto. Las bases se suman en la entrada que se conserva."""
    cred, dbs = _leer_env()
    cat = _catalogo()
    por_id = {s.get("id"): s for s in (cat.get("servidores") or []) if s.get("id")}
    grupos: dict[tuple[str, str], list[str]] = {}
    for sid, row in cred.items():
        grupos.setdefault((row["host"].lower(), str(row["puerto"])), []).append(sid)
    cambios: dict[str, str | None] = {}
    quitados = []
    for ids in grupos.values():
        if len(ids) < 2:
            continue
        principal = _principal(ids)
        extras = [i for i in ids if i != principal]
        fuente = cred[extras[-1]]
        cambios[principal] = f"{fuente['host']}|{fuente['puerto']}|{fuente['usuario']}|{fuente['clave']}"
        bases: list[str] = []
        for sid in [principal, *extras]:
            meta = por_id.get(sid) or {}
            for base in meta.get("bases") or _lista_bases(dbs.get(f"db{sid}", "")):
                if base not in bases:
                    bases.append(base)
        ficha = por_id.setdefault(
            principal,
            {
                "id": principal,
                "nombre": principal,
                "credencialEnv": principal,
                "baseDatosEnv": f"db{principal}",
                "soloLectura": True,
            },
        )
        ficha["bases"] = bases
        ficha["baseDatosEnv"] = f"db{principal}"
        ficha["credencialEnv"] = principal
        nombre = ficha.get("nombre") or principal
        ficha["nombre"] = nombre.replace(" · clave de Qrystalos2", "")
        if bases:
            cambios[f"db{principal}"] = bases[0]
        for extra in extras:
            cambios[extra] = None
            cambios[f"db{extra}"] = None
            por_id.pop(extra, None)
            quitados.append(extra)
    if cambios:
        _reescribir_env(cambios)
    vivos, _ = _leer_env()
    cat["servidores"] = [por_id[k] for k in sorted(por_id) if k in vivos]
    _guardar_catalogo(cat)
    return {"quitados": quitados}


def importar_qrystalos2() -> dict:
    limpieza = deduplicar()
    origen = _leer_origen(_ruta_qrystalos2())
    cred, dbs = _leer_env()
    ocupados = set(cred)
    cambios: dict[str, str] = {}
    cat = _catalogo()
    servidores = list(cat.get("servidores") or [])
    por_id = {s.get("id"): s for s in servidores if s.get("id")}
    agregados = []
    ya_estaban = []
    bases_sumadas = []

    nombres_locales = {
        "servidor1": "API TEST · PCEM",
        "servidor2": "San Luis · KSANLUIS",
        "servidorHcodazzi": "IxColombia · KHCODAZZI",
    }
    for sid in cred:
        if sid in por_id:
            continue
        base = dbs.get(f"db{sid}", "")
        por_id[sid] = {
            "id": sid,
            "nombre": nombres_locales.get(sid, sid),
            "credencialEnv": sid,
            "baseDatosEnv": f"db{sid}",
            "bases": _lista_bases(base),
            "soloLectura": True,
        }

    for row in origen:
        if not row["bases"]:
            continue
        coinciden = [sid for sid, actual in cred.items() if _mismo_equipo(actual, row)]
        gemelo = _principal(coinciden) if coinciden else None
        if gemelo:
            meta = por_id.setdefault(
                gemelo,
                {
                    "id": gemelo,
                    "nombre": row["nombre"],
                    "credencialEnv": gemelo,
                    "baseDatosEnv": f"db{gemelo}",
                    "bases": _lista_bases(dbs.get(f"db{gemelo}", "")),
                    "soloLectura": True,
                },
            )
            if not meta.get("nombre") or meta.get("nombre") == gemelo:
                meta["nombre"] = row["nombre"]
            actuales = list(meta.get("bases") or _lista_bases(dbs.get(f"db{gemelo}", "")))
            nuevas = [b for b in row["bases"] if b not in actuales]
            if nuevas:
                meta["bases"] = actuales + nuevas
                bases_sumadas.append({"id": gemelo, "bases": nuevas})
            ya_estaban.append({"id": row["id"], "como": gemelo, "nombre": meta.get("nombre") or gemelo})
            continue
        nuevo = _id_libre(row["id"], row["nombre"], ocupados)
        ocupados.add(nuevo)
        cambios[nuevo] = f"{row['host']}|{row['puerto']}|{row['usuario']}|{row['clave']}"
        cambios[f"db{nuevo}"] = row["bases"][0]
        por_id[nuevo] = {
            "id": nuevo,
            "nombre": row["nombre"],
            "credencialEnv": nuevo,
            "baseDatosEnv": f"db{nuevo}",
            "bases": row["bases"],
            "soloLectura": True,
        }
        agregados.append({"id": nuevo, "nombre": row["nombre"]})

    if cambios:
        _reescribir_env(cambios)
    cat["servidores"] = [por_id[k] for k in sorted(por_id)]
    _guardar_catalogo(cat)
    return {
        "agregados": agregados,
        "yaEstaban": ya_estaban,
        "basesSumadas": bases_sumadas,
        "quitados": limpieza["quitados"],
    }


def listar_bases_sql(servidor_id: str) -> list[str]:
    """Catálogo de bases en el servidor (solo lectura, sqlcmd)."""
    from auditoria_procesos import _parse_tsv, _resolve_server_db, _sqlcmd_query

    sid = (servidor_id or "").strip()
    if not _ID_RE.match(sid):
        raise ValueError("Identificador de servidor no válido.")
    server, user, pwd, _db = _resolve_server_db(sid, "master")
    sql = """
SET NOCOUNT ON;
SELECT name FROM sys.databases
WHERE state_desc = N'ONLINE'
  AND database_id > 4
ORDER BY name;
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, "master", sql))
    out = []
    for r in rows:
        n = (r.get("name") or "").strip()
        if n and n not in out:
            out.append(n)
    return out
