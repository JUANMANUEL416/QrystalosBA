"""Lista de desarrolladores: se crea si no existe y se actualiza al subir REQ."""
import json
import os
import re
import time
from datetime import date

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
DEV_PATH = os.path.join(ROOT, "config", "desarrolladores.json")
ACTIVO_ROOT = os.path.join(ROOT, "activo")

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

CUERPO_FORMAL = {
    "asunto": "Dictamen técnico REQ {{idReq}} — {{cliente}} / {{modulo}}",
    "texto": (
        "Estimado(a) {{nombre}},\n\n"
        "Por medio de la presente, remito el dictamen técnico del requerimiento {{idReq}} "
        "correspondiente al cliente {{cliente}}, módulo {{modulo}}.\n\n"
        "El documento, elaborado por Business Analyst de IX Colombia, describe "
        "el alcance acordado, el flujo de ejecución, la propuesta de cambio y el plan de pruebas. "
        "Queda adjunto para su implementación en la rama {{rama}}.\n\n"
        "Quedo atento a cualquier aclaración que requiera antes o durante el desarrollo.\n\n"
        "Atentamente,\nJosé Manuel Jiménez\nBusiness Analyst\nIX Colombia SAS\nQrystalos"
    ),
}


def _decode_text(raw):
    for enc in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def _read_json(path, default):
    if not os.path.isfile(path):
        return default
    try:
        raw = open(path, "rb").read()
    except OSError as exc:
        print(f"WARN no se pudo leer {path}: {exc}", flush=True)
        return default
    text = _decode_text(raw)
    stripped = text.lstrip()
    try:
        data, end = json.JSONDecoder().raw_decode(stripped)
    except json.JSONDecodeError:
        return default
    # Solo reescribe si hay basura real tras el JSON (no solo \\n).
    resto = stripped[end:].strip()
    if resto:
        try:
            _write_json(path, data)
        except OSError as exc:
            print(f"WARN no se pudo normalizar {path}: {exc}", flush=True)
    return data


def _write_json(path, data):
    """Escritura atómica con reintento (evita Errno 22 / archivo bloqueado en Windows)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    tmp = f"{path}.{os.getpid()}.tmp"
    last_err = None
    for intento in range(5):
        try:
            with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(payload)
            os.replace(tmp, path)
            return
        except OSError as exc:
            last_err = exc
            try:
                if os.path.isfile(tmp):
                    os.remove(tmp)
            except OSError:
                pass
            time.sleep(0.05 * (intento + 1))
    raise OSError(f"No se pudo guardar {path}: {last_err}") from last_err


def norm_nombre(nombre):
    return " ".join(str(nombre or "").upper().split())


def validar_correo(correo):
    correo = str(correo or "").strip()
    if not correo:
        return ""
    if not EMAIL_RE.match(correo):
        raise ValueError(f"Correo inválido: {correo}")
    return correo


def load_lista():
    try:
        data = _read_json(DEV_PATH, None)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"WARN desarrolladores.json inválido: {exc}", flush=True)
        data = None
    if not isinstance(data, dict):
        data = {}
    data.setdefault("desarrolladores", [])
    data.setdefault("cuerpoFormal", CUERPO_FORMAL)
    data.setdefault("nota", "Si falta correo, al decir finalizar el sistema lo pide y actualiza esta lista.")
    return data


def save_lista(data):
    data["actualizado"] = date.today().isoformat()
    data["cuerpoFormal"] = data.get("cuerpoFormal") or CUERPO_FORMAL
    save = {
        "actualizado": data["actualizado"],
        "nota": data.get("nota") or "",
        "desarrolladores": sorted(
            data.get("desarrolladores") or [],
            key=lambda d: d.get("nombre") or "",
        ),
        "cuerpoFormal": data["cuerpoFormal"],
    }
    _write_json(DEV_PATH, save)
    return save


def _find(data, nombre):
    key = norm_nombre(nombre)
    for d in data["desarrolladores"]:
        if norm_nombre(d.get("nombre")) == key:
            return d
    return None


def _caso_key(caso):
    return str(caso.get("idReq") or caso.get("idCaso") or "")


def _merge_caso(dev, caso):
    """Fusiona un caso. Devuelve True si hubo cambio."""
    if not caso:
        return False
    casos = dev.setdefault("casos", [])
    key = _caso_key(caso)
    if not key:
        return False
    nuevo = {k: v for k, v in caso.items() if v not in (None, "")}
    for i, c in enumerate(casos):
        if _caso_key(c) == key:
            merged = {**c, **nuevo}
            if merged == c:
                return False
            casos[i] = merged
            return True
    casos.append(nuevo)
    return True


def upsert(nombre, caso=None, correo=None, guardar=True):
    nombre = norm_nombre(nombre)
    if not nombre:
        return load_lista(), None, False
    data = load_lista()
    creado = False
    dev = _find(data, nombre)
    if not dev:
        dev = {"nombre": nombre, "correo": "", "casos": []}
        data["desarrolladores"].append(dev)
        creado = True
    if correo is not None and str(correo).strip():
        dev["correo"] = validar_correo(correo)
    _merge_caso(dev, caso)
    if guardar:
        save_lista(data)
    return data, dev, creado


def set_correo(nombre, correo):
    return upsert(nombre, correo=correo)


def pendientes_correo(data=None):
    data = data or load_lista()
    return [d for d in data["desarrolladores"] if not str(d.get("correo") or "").strip()]


def buscar_caso(id_caso=None, id_req=None):
    data = load_lista()
    id_caso = str(id_caso or "").strip()
    id_req = str(id_req or "").strip()
    for d in data.get("desarrolladores") or []:
        for c in d.get("casos") or []:
            if id_caso and str(c.get("idCaso") or "") == id_caso:
                return d, c
            if id_req and str(c.get("idReq") or "") == id_req:
                return d, c
    return None, None


def marcar_envio_caso(id_caso, correo_enviado=None, fecha_envio=None, ultimo_envio=None,
                      reenvios=None, destinatario=None, via=None):
    id_caso = str(id_caso or "").strip()
    if not id_caso:
        return load_lista(), None
    data = load_lista()
    hallado = None
    for d in data.get("desarrolladores") or []:
        for c in d.get("casos") or []:
            if str(c.get("idCaso") or "") == id_caso:
                if correo_enviado is not None:
                    c["correoEnviado"] = bool(correo_enviado)
                if fecha_envio:
                    c["fechaEnvio"] = fecha_envio
                if ultimo_envio:
                    c["ultimoEnvio"] = ultimo_envio
                if reenvios is not None:
                    c["reenvios"] = int(reenvios)
                if destinatario:
                    c["destinatario"] = destinatario
                if via:
                    c["via"] = via
                hallado = c
                break
        if hallado:
            break
    if hallado:
        save_lista(data)
    return data, hallado


def caso_desde_cola_item(item):
    p = (item or {}).get("parsed") or {}
    return {
        "idReq": p.get("idReq") or item.get("idReqSeleccionado") or "",
        "idCaso": p.get("idCaso") or "",
        "cliente": p.get("proyecto") or "",
        "modulo": p.get("moduloNombre") or p.get("modulo") or "",
        "rama": p.get("rama") or "",
        "dictamen": f"dictamenes/{p.get('idCaso')}.html" if p.get("idCaso") else "",
        "fase1": item.get("estado") or "",
    }, p.get("desarrollador") or ""


def _aplicar_caso(data, nombre, caso):
    """Aplica un caso en memoria. Devuelve (creado, cambiado)."""
    nombre = norm_nombre(nombre)
    if not nombre:
        return False, False
    creado = False
    dev = _find(data, nombre)
    if not dev:
        dev = {"nombre": nombre, "correo": "", "casos": []}
        data["desarrolladores"].append(dev)
        creado = True
    cambiado = _merge_caso(dev, caso)
    return creado, creado or cambiado


def sync_from_cola(items):
    creados = []
    actualizados = []
    data = load_lista()
    dirty = False
    for item in items or []:
        caso, nombre = caso_desde_cola_item(item)
        if not nombre:
            continue
        creado, cambiado = _aplicar_caso(data, nombre, caso)
        dirty = dirty or cambiado
        if creado:
            creados.append(norm_nombre(nombre))
        elif cambiado:
            actualizados.append(norm_nombre(nombre))
    if dirty:
        data = save_lista(data)
    return data, creados, actualizados


def sync_from_activo(data=None):
    creados = []
    dirty = False
    if data is None:
        data = load_lista()
    if not os.path.isdir(ACTIVO_ROOT):
        return data, creados, dirty
    for name in os.listdir(ACTIVO_ROOT):
        carpeta = os.path.join(ACTIVO_ROOT, name)
        if not os.path.isdir(carpeta) or name.startswith("."):
            continue
        sol = _read_json(os.path.join(carpeta, "solicitud.json"), {})
        est = _read_json(os.path.join(carpeta, "estado.json"), {})
        ident = sol.get("identificacion") or {}
        personas = sol.get("personas") or {}
        proyecto = sol.get("proyecto") or {}
        gestion = sol.get("gestion") or {}
        nombre = personas.get("desarrollador") or ""
        if not nombre:
            continue
        caso = {
            "idReq": ident.get("idReq") or "",
            "idCaso": ident.get("idCaso") or name,
            "cliente": proyecto.get("nombre") or "",
            "modulo": proyecto.get("modulo") or "",
            "rama": gestion.get("rama") or "",
            "dictamen": f"dictamenes/{ident.get('idCaso') or name}.html",
            "fase1": "cerrada" if est.get("fase1Cerrada") else "abierta",
        }
        creado, cambiado = _aplicar_caso(data, nombre, caso)
        dirty = dirty or cambiado
        if creado:
            creados.append(norm_nombre(nombre))
    return data, creados, dirty


def sync_all(cola_items=None):
    """Un solo load + un solo save (evita carreras Errno 22 en Windows)."""
    data = load_lista()
    data, creados_a, dirty_a = sync_from_activo(data)
    creados_c, actualizados = [], []
    dirty_c = False
    if cola_items is not None:
        for item in cola_items or []:
            caso, nombre = caso_desde_cola_item(item)
            if not nombre:
                continue
            creado, cambiado = _aplicar_caso(data, nombre, caso)
            dirty_c = dirty_c or cambiado
            if creado:
                creados_c.append(norm_nombre(nombre))
            elif cambiado:
                actualizados.append(norm_nombre(nombre))
    if dirty_a or dirty_c:
        data = save_lista(data)
    creados = sorted(set(creados_a + creados_c))
    return {
        "ok": True,
        **data,
        "creados": creados,
        "actualizados": sorted(set(actualizados)),
        "pendientesCorreo": pendientes_correo(data),
    }
