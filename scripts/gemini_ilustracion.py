# -*- coding: utf-8 -*-
"""Las ilustraciones de una entrega las arma el modelo de imagen de Cursor.

No se llama a la API de Google (GEMINI_API_KEY). El agente de Cursor dibuja
la pantalla y deja el archivo con origen «cursor».
"""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

from cursor_bot import ENV_PATH, _escribir_env_lineas, _leer_env_lineas, _parse_env

NOMBRE = "GEMINI_API_KEY"
MODELO = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
MODELO_TEXTO = os.environ.get("GEMINI_TEXT_MODEL", "gemini-3.5-flash-lite")
URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
URL_TEXTO = "https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent"


def _validar(valor: str) -> str:
    clave = (valor or "").strip().strip('"').strip("'")
    if any(c.isspace() for c in clave):
        raise ValueError("La clave de Gemini no puede llevar espacios.")
    if clave.startswith("crsr_"):
        raise ValueError("Esa es una clave de Cursor. Aquí va la de Gemini.")
    if len(clave) < 20:
        raise ValueError("La clave de Gemini está incompleta.")
    return clave


def clave() -> str:
    env = _parse_env(ENV_PATH)
    return (os.environ.get(NOMBRE) or env.get(NOMBRE) or "").strip()


def estado() -> dict:
    return {
        "configurado": False,
        "sufijo": "",
        "modelo": "cursor",
        "modeloTexto": "cursor",
        "aviso": "Las ilustraciones las arma el modelo de imagen de Cursor. No se usa la API de Gemini.",
    }


def guardar_clave(valor: str) -> dict:
    raise ValueError("No se guarda la clave de Gemini. Las ilustraciones las arma el modelo de Cursor.")


def _imagen_de_respuesta(datos: dict) -> tuple[str, str]:
    candidatos = []
    for llave in ("output_image", "outputImage"):
        if isinstance(datos.get(llave), dict):
            candidatos.append(datos[llave])
    for bloque in datos.get("output") or datos.get("outputs") or []:
        if isinstance(bloque, dict):
            candidatos.append(bloque)
    for item in candidatos:
        data = item.get("data") or item.get("inline_data") or item.get("inlineData") or ""
        if isinstance(data, dict):
            mime = data.get("mime_type") or data.get("mimeType") or "image/png"
            data = data.get("data") or ""
        else:
            mime = item.get("mime_type") or item.get("mimeType") or "image/png"
        if isinstance(data, str) and len(data) > 80:
            return mime, data
    raise ValueError("Gemini no devolvió una imagen.")


def _detalle_http(detalle: str, token: str) -> str:
    limpio = (detalle or "").replace(token, "***")
    mensaje = ""
    try:
        datos = json.loads(limpio)
        mensaje = str((datos.get("error") or {}).get("message") or "")
    except json.JSONDecodeError:
        mensaje = limpio
    mensaje = " ".join(mensaje.split())
    if len(mensaje) > 180:
        mensaje = mensaje[:177] + "..."
    return mensaje


def _post(cuerpo: dict, fallo: str, url: str = URL) -> dict:
    raise ValueError("No se usa la API de Gemini. La ilustración la arma el modelo de Cursor.")
    token = clave()
    if not token:
        raise ValueError("Falta la clave de Gemini en Consultas de soporte.")
    req = urllib.request.Request(
        url,
        data=json.dumps(cuerpo).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            datos = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detalle = _detalle_http(exc.read().decode("utf-8", errors="replace")[:500], token)
        extra = (" " + detalle) if detalle else ""
        raise ValueError(fallo + " (" + str(exc.code) + ")." + extra) from exc
    except urllib.error.URLError as exc:
        raise ValueError("No hubo conexión con Gemini.") from exc
    if not isinstance(datos, dict):
        raise ValueError(fallo + ".")
    return datos


def _recolectar_texto(node, partes: list[str]) -> None:
    if isinstance(node, dict):
        for llave in ("text", "output_text", "outputText"):
            valor = node.get(llave)
            if isinstance(valor, str) and valor.strip():
                partes.append(valor)
        for valor in node.values():
            _recolectar_texto(valor, partes)
    elif isinstance(node, list):
        for valor in node:
            _recolectar_texto(valor, partes)


def _textos(datos: dict) -> str:
    partes: list[str] = []
    preferido = []
    for llave in ("output", "outputs", "output_text", "outputText", "steps"):
        if llave in datos:
            preferido.append(datos[llave])
    if preferido:
        _recolectar_texto(preferido, partes)
    if not any(p.strip() for p in partes):
        _recolectar_texto(datos, partes)
    return "\n".join(partes)


def _json_objeto(texto: str) -> dict:
    pos = 0
    while True:
        inicio = texto.find("{", pos)
        if inicio < 0:
            break
        try:
            datos, fin = json.JSONDecoder().raw_decode(texto[inicio:])
        except json.JSONDecodeError:
            pos = inicio + 1
            continue
        if isinstance(datos, dict) and str(datos.get("texto") or "").strip():
            return datos
        pos = inicio + max(int(fin or 1), 1)
    raise ValueError("Gemini no devolvió el documento organizado.")

def organizar(fuente: str, pantallas: list | None = None) -> dict:
    """El texto lo redacta el agente de Cursor. Esta función ya no llama a la API."""
    raise ValueError("El documento lo redacta el agente de Cursor. No se usa la API de Gemini.")


def generar(prompt: str) -> tuple[str, str]:
    """La imagen la genera el modelo de Cursor. Esta función ya no llama a la API."""
    raise ValueError("La ilustración la arma el modelo de imagen de Cursor. No se usa la API de Gemini.")
