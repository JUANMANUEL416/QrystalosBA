"""Cliente OpenAI: texto (Chat Completions) e ilustración (Images)."""
import base64
import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
ENV_PATH = os.path.join(ROOT, ".env")
CONFIG_PATH = os.path.join(ROOT, "config", "openai.json")


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

SYSTEM_PROMPT = """Eres coordinador técnico de Qrystalos (HIS hospitalario Vue/Quasar + SQL Server).
Redacta criterios de aceptación claros, verificables y numerados (1. 2. 3.).
Un criterio por línea. Español. Sin preámbulo, sin cierre, sin markdown.
Cubre validaciones, pantallas, excepciones y lo que el requerimiento y el análisis indiquen.
No inventes módulos, SPs ni columnas que no se mencionen."""


def load_config():
    env_file = _parse_env_file(ENV_PATH)
    data = {}
    if os.path.isfile(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            data = json.load(fh) or {}
    key = (
        os.environ.get("OPENAI_API_KEY")
        or env_file.get("OPENAI_API_KEY")
        or data.get("apiKey")
        or ""
    ).strip()
    modelo = (
        os.environ.get("OPENAI_MODEL")
        or env_file.get("OPENAI_MODEL")
        or data.get("modelo")
        or "gpt-4.1"
    ).strip()
    base = (
        os.environ.get("OPENAI_BASE_URL")
        or env_file.get("OPENAI_BASE_URL")
        or data.get("baseUrl")
        or "https://api.openai.com/v1"
    ).rstrip("/")
    return {"apiKey": key, "modelo": modelo, "baseUrl": base, "ruta": ENV_PATH}


def estado_publico():
    cfg = load_config()
    return {
        "configurado": bool(cfg["apiKey"]),
        "modelo": cfg["modelo"],
        "modeloEntrega": modelo_entrega(),
        "idiomaEntrega": idioma_entrega(),
        "rutaConfig": ".env",
        "ejemplo": ".env.example",
    }


def modelo_entrega() -> str:
    """Modelo para la plantilla de entrega de requerimiento. Mejor que el mini."""
    env_file = _parse_env_file(ENV_PATH)
    data = {}
    if os.path.isfile(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            data = json.load(fh) or {}
    return (
        os.environ.get("OPENAI_MODEL_ENTREGA")
        or env_file.get("OPENAI_MODEL_ENTREGA")
        or data.get("modeloEntrega")
        or "gpt-5.4"
    ).strip()


def idioma_entrega() -> str:
    """Idioma de textos e ilustración de la entrega. Por defecto español."""
    env_file = _parse_env_file(ENV_PATH)
    data = {}
    if os.path.isfile(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            data = json.load(fh) or {}
    valor = (
        os.environ.get("OPENAI_IDIOMA_ENTREGA")
        or env_file.get("OPENAI_IDIOMA_ENTREGA")
        or data.get("idiomaEntrega")
        or "es"
    ).strip().lower()
    if valor in ("en", "english", "ingles", "inglés"):
        return "en"
    return "es"


def _user_prompt(payload):
    return (
        "Requerimiento:\n"
        f"{(payload.get('requerimiento') or '').strip() or '—'}\n\n"
        "Alcance:\n"
        f"{(payload.get('alcance') or '').strip() or '—'}\n\n"
        "Restricciones:\n"
        f"{(payload.get('restricciones') or '').strip() or '—'}\n\n"
        "Análisis del coordinador:\n"
        f"{(payload.get('analisis') or '').strip() or '—'}\n"
    )


ORGANIZAR_PROMPTS = {
    "criteriosAceptacion": (
        "Organiza este dictado en criterios de aceptación numerados (1. 2. 3.). "
        "Conserva el significado. Español. Sin preámbulo ni markdown. "
        "Un criterio por línea. SIN renglones vacíos entre ítems. "
        "No inventes SPs, tablas ni pantallas que no estén en el texto."
    ),
    "analisis": (
        "Organiza este dictado en un análisis técnico claro con viñetas (- ). "
        "Conserva nombres de SPs, tablas, pantallas y el sentido original. "
        "Español. Sin preámbulo ni markdown. "
        "Una viñeta por línea. SIN renglones vacíos entre viñetas."
    ),
    "recomendacion": (
        "Organiza este dictado en una recomendación técnica breve y clara. "
        "Conserva el sentido. Español. Sin preámbulo ni markdown. "
        "Sin renglones vacíos entre frases."
    ),
}


def _chat(system_prompt, user_prompt):
    cfg = load_config()
    if not cfg["apiKey"]:
        return {
            "ok": False,
            "error": "sin_api_key",
            "mensaje": "Falta OPENAI_API_KEY en el archivo .env (raíz del proyecto).",
            "rutaConfig": ".env",
        }

    body = {
        "model": cfg["modelo"],
        "temperature": 0.3,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }
    req = urllib.request.Request(
        f"{cfg['baseUrl']}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {cfg['apiKey']}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=50) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detalle = exc.read().decode("utf-8", errors="replace")[:400]
        return {
            "ok": False,
            "error": "openai_http",
            "mensaje": f"OpenAI HTTP {exc.code}: {detalle}",
            "modelo": cfg["modelo"],
        }
    except Exception as exc:
        return {
            "ok": False,
            "error": "openai_red",
            "mensaje": f"No se pudo llamar a OpenAI: {exc}",
            "modelo": cfg["modelo"],
        }

    texto = ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
    texto = texto.strip()
    if not texto:
        return {"ok": False, "error": "vacio", "mensaje": "OpenAI no devolvió texto.", "modelo": cfg["modelo"]}

    return {"ok": True, "texto": texto, "modelo": cfg["modelo"], "origen": "openai"}


def chat_json(system_prompt, user_prompt, modelo: str | None = None):
    """Igual que _chat, pidiendo un objeto JSON."""
    cfg = load_config()
    modelo = (modelo or cfg["modelo"]).strip()
    if not cfg["apiKey"]:
        return {
            "ok": False,
            "error": "sin_api_key",
            "mensaje": "Falta OPENAI_API_KEY en el archivo .env (raíz del proyecto).",
            "rutaConfig": ".env",
        }
    body = {
        "model": modelo,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }
    req = urllib.request.Request(
        f"{cfg['baseUrl']}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {cfg['apiKey']}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detalle = exc.read().decode("utf-8", errors="replace")[:400]
        return {
            "ok": False,
            "error": "openai_http",
            "mensaje": f"OpenAI HTTP {exc.code}: {detalle}",
            "modelo": modelo,
        }
    except Exception as exc:
        return {
            "ok": False,
            "error": "openai_red",
            "mensaje": f"No se pudo llamar a OpenAI: {exc}",
            "modelo": modelo,
        }
    texto = ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
    texto = texto.strip()
    if not texto:
        return {"ok": False, "error": "vacio", "mensaje": "OpenAI no devolvió JSON.", "modelo": modelo}
    try:
        objeto = json.loads(texto)
    except json.JSONDecodeError:
        return {"ok": False, "error": "json", "mensaje": "OpenAI no devolvió un JSON válido.", "modelo": modelo}
    if not isinstance(objeto, dict):
        return {"ok": False, "error": "json", "mensaje": "OpenAI no devolvió un objeto JSON.", "modelo": modelo}
    return {"ok": True, "objeto": objeto, "modelo": modelo, "origen": "openai"}


def generar_imagen(prompt: str, dest_path: str, size: str = "1536x1024"):
    """Ilustración con el modelo de imagen de OpenAI (DALL·E). No imprime la clave."""
    cfg = load_config()
    if not cfg["apiKey"]:
        return {
            "ok": False,
            "error": "sin_api_key",
            "mensaje": "Falta OPENAI_API_KEY en el archivo .env (raíz del proyecto).",
        }
    modelo_img = (
        os.environ.get("OPENAI_IMAGE_MODEL")
        or _parse_env_file(ENV_PATH).get("OPENAI_IMAGE_MODEL")
        or "gpt-image-1"
    ).strip()
    body = {
        "model": modelo_img,
        "prompt": (prompt or "").strip()[:3900],
        "size": size,
        "n": 1,
    }
    req = urllib.request.Request(
        f"{cfg['baseUrl']}/images/generations",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {cfg['apiKey']}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detalle = exc.read().decode("utf-8", errors="replace")[:400]
        if size != "1024x1024":
            return generar_imagen(prompt, dest_path, size="1024x1024")
        return {
            "ok": False,
            "error": "openai_http",
            "mensaje": f"OpenAI imagen HTTP {exc.code}: {detalle}",
            "modelo": modelo_img,
        }
    except Exception as exc:
        return {
            "ok": False,
            "error": "openai_red",
            "mensaje": f"No se pudo generar la ilustración: {exc}",
            "modelo": modelo_img,
        }
    fila = (data.get("data") or [{}])[0]
    b64 = (fila.get("b64_json") or "").strip()
    url = (fila.get("url") or "").strip()
    if b64:
        blob = base64.b64decode(b64)
    elif url:
        try:
            with urllib.request.urlopen(url, timeout=60) as img_resp:
                blob = img_resp.read()
        except Exception as exc:
            return {"ok": False, "error": "openai_red", "mensaje": str(exc), "modelo": modelo_img}
    else:
        return {"ok": False, "error": "vacio", "mensaje": "OpenAI no devolvió imagen.", "modelo": modelo_img}
    dest = Path(dest_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(blob)
    return {"ok": True, "archivo": str(dest), "modelo": modelo_img, "bytes": len(blob)}


def sugerir(payload):
    result = _chat(SYSTEM_PROMPT, _user_prompt(payload))
    if result.get("ok"):
        result["criterios"] = result.get("texto")
    return result


def compactar_texto(texto):
    t = (texto or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    t = re.sub(r"[ \t]+\n", "\n", t)
    t = re.sub(r"\n{2,}", "\n", t)
    return t


def organizar(payload):
    campo = (payload.get("campo") or "").strip()
    texto = (payload.get("texto") or "").strip()
    if not texto:
        return {"ok": False, "error": "sin_texto", "mensaje": "No hay texto para organizar."}
    system = ORGANIZAR_PROMPTS.get(campo) or ORGANIZAR_PROMPTS["analisis"]
    result = _chat(system, texto)
    if result.get("ok") and result.get("texto"):
        result["texto"] = compactar_texto(result["texto"])
    return result
