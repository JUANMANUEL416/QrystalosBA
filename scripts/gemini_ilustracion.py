# -*- coding: utf-8 -*-
"""Clave de Gemini solo para ilustraciones de Consultas de soporte.

La clave vive en .env (GEMINI_API_KEY). No se mezcla con las claves de Cursor.
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
    valor = clave()
    return {
        "configurado": bool(valor),
        "sufijo": valor[-4:] if len(valor) >= 4 else "",
        "modelo": MODELO,
        "modeloTexto": MODELO_TEXTO,
    }


def guardar_clave(valor: str) -> dict:
    nueva = _validar(valor)
    lineas, sep = _leer_env_lineas(ENV_PATH)
    idx = -1
    for i, raw in enumerate(lineas):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        nombre, _, _val = line.partition("=")
        if nombre.strip() == NOMBRE:
            idx = i
            break
    fila = f"{NOMBRE}={nueva}"
    if idx < 0:
        lineas.append(fila)
    else:
        lineas[idx] = fila
    _escribir_env_lineas(ENV_PATH, lineas, sep)
    os.environ[NOMBRE] = nueva
    return estado()


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
    """Pasa la respuesta oficial a lenguaje de pantalla, con flujo e ilustraciones."""
    base = (fuente or "").strip()
    if len(base) < 40:
        raise ValueError("Primero hace falta la respuesta oficial, tomada de la ficha, el grafo y el flujo.")
    if len(base) > 14000:
        base = base[:14000]
    pedido = (
        "Organice esta respuesta de soporte de Qrystalos para quien usa el aplicativo o atiende soporte. "
        "Devuelva solo un JSON con las claves texto, flujo e ilustraciones.\n"
        "texto: la guía en español, con párrafos y pasos numerados. Quite nombres de procedimiento "
        "(SPK_, SPQ_, FNK_) y jerga de base de datos. Use el nombre de la pantalla, la ruta o la ventana "
        "solo si ya aparecen en el texto fuente. No invente menús, botones ni pasos.\n"
        "Si el fuente dice que algo no está documentado, consérvelo tal cual: no lo complete.\n"
        "Separe al final, solo si el fuente trae consultas SQL, un apartado «Para soporte interno» con esas consultas. "
        "El resto es «Para quien usa la pantalla».\n"
        "flujo: lista corta, en el mismo orden del fuente, de los pasos que la persona ve. Máximo 8. "
        "Cada paso es una frase. No agregue pasos que el fuente no tenga.\n"
        "ilustraciones: máximo 2 objetos con titulo y escena. La escena describe solo esos pasos, "
        "como un esquema claro de flujo, sin datos de pacientes ni de clientes. "
        "No dibuje botones que no estén en el fuente ni en los nombres de pantalla.\n"
        + (
            "Nombres de pantalla ya documentados; úselos tal cual y no agregue otros: "
            + "; ".join(str(n) for n in (pantallas or [])[:12])
            + ".\n"
            if pantallas
            else ""
        )
        + "\nTEXTO FUENTE:\n"
        + base
    )
    cuerpo = {
        "contents": [{"role": "user", "parts": [{"text": pedido}]}],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 8192,
            "responseMimeType": "application/json",
        },
    }
    modelos = [MODELO_TEXTO or "gemini-3.5-flash-lite"]
    if "gemini-3.5-flash-lite" not in modelos:
        modelos.append("gemini-3.5-flash-lite")
    datos = None
    ultimo = None
    for modelo in modelos:
        try:
            datos = _post(
                cuerpo,
                "Gemini no pudo organizar el documento",
                URL_TEXTO.format(modelo=modelo),
            )
            break
        except ValueError as exc:
            ultimo = exc
            if "(404)" not in str(exc):
                raise
    if datos is None:
        raise ultimo or ValueError("Gemini no pudo organizar el documento.")
    crudo = _json_objeto(_textos(datos))
    texto = str(crudo.get("texto") or "").strip()
    if len(texto) < 40:
        raise ValueError("Gemini no devolvió la guía organizada.")
    flujo = []
    for paso in crudo.get("flujo") or []:
        frase = str(paso or "").strip()
        if frase:
            flujo.append(frase[:220])
        if len(flujo) >= 8:
            break
    ilustraciones = []
    for item in crudo.get("ilustraciones") or []:
        if not isinstance(item, dict):
            continue
        titulo = str(item.get("titulo") or "Flujo").strip()[:80]
        escena = str(item.get("escena") or "").strip()
        if len(escena) < 8:
            continue
        ilustraciones.append({"titulo": titulo or "Flujo", "escena": escena[:900]})
        if len(ilustraciones) >= 2:
            break
    return {"texto": texto, "flujo": flujo, "ilustraciones": ilustraciones}


def generar(prompt: str) -> tuple[str, str]:
    """Devuelve (mime, base64) sin guardar nada."""
    texto = (prompt or "").strip()
    if len(texto) < 8:
        raise ValueError("Describa la ilustración con un poco más de detalle.")
    if len(texto) > 2000:
        texto = texto[:2000]
    datos = _post(
        {
            "model": MODELO,
            "input": [{"type": "text", "text": texto}],
            "response_format": {
                "type": "image",
                "mime_type": "image/png",
                "aspect_ratio": "16:9",
            },
        },
        "Gemini rechazó la ilustración",
    )
    return _imagen_de_respuesta(datos)
