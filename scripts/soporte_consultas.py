"""Consultas de soporte: chat + documento PDF de respuesta (data/soporte-consultas/)."""
from __future__ import annotations

import base64
import html as html_lib
import json
import re
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "soporte-consultas"
INDEX_FILE = DATA_DIR / "index.json"

_ID_SAFE = re.compile(r"[^a-zA-Z0-9_-]+")
_AUTORES = frozenset({"soporte", "coordinador", "agente", "sistema"})


def _instruccion_md(sid: str, meta: dict) -> str:
    return f"""# Consulta soporte — {sid}

## Objetivo
Responder la consulta interna contrastando **conocimiento/** (INDICE, procesos, grafos, runbooks) y documentación viva.

## Leer primero, en este orden
1. `data/soporte-consultas/{sid}/meta.json` y `chat.json`
2. `conocimiento/_indice_busqueda.json` — ubique proceso, control y la ficha. Abra solo esa línea. No lea un `sps.json` entero.
3. El guion de ese proceso: `conocimiento/{{proceso}}/proceso.json` (resumen, ventanas y controles) y el grafo de ese mismo proceso (`grafo-*/`, nodos en el orden del archivo). La respuesta sigue ese orden. No reordene pasos ni traiga un paso de otro proceso.
4. Sin validar en base: ficha distinta de `leido`, o grafo que no cubre la pregunta: no complete el hueco. Diga en el chat y en `respuestaOficial` qué falta. Encole el handoff. Con validar en base, ese hueco se lee y se documenta (ver abajo). No devuelva un atajo ni un paso de otro proceso.

## Entregables
1. Mensaje en **chat.json** (autor: `agente`). No escriba `en` ni `id`, o déjelos como vengan: la app asigna la hora y el id reales al terminar el turno y corrige cualquier valor inventado.
2. Borrador en **meta.json** → `respuestaOficial` (texto para PDF).
3. **meta.json** → `proposito` (2–4 frases): nace de la **necesidad** (`preguntaInicial`) y resume qué entrega el documento según su **análisis** (no texto genérico).
4. En una consulta de soporte, cada **consulta SQL** va en bloque ```sql … ```. Esas consultas son para soporte interno.
5. Si `meta.json` trae `entregaRequerimiento` en true, el PDF usa la plantilla exclusiva `plantillas/entrega-requerimiento.html` (ChatGPT + ilustración). Todo el texto visible, avisos y rótulos de la ilustración van en español de Colombia. No incluya consultas SQL; quedan en el control de cambios.
6. No implementar en Qrystalos2. No escribir en la base ni ejecutar procedimientos.
7. **Límite de mediciones:** máximo **3 intentos** de conexión a la base y **5 minutos** totales. Si la consulta falla o no completa tras 3 intentos, detenga las mediciones, informe el problema en chat y deje la consulta SQL sugerida en `respuestaOficial` para que soporte la ejecute manualmente. No reintente indefinidamente.
8. **proposito** y la sección final de pasos distinguen **Para el cliente** (pantallas) y **Para soporte interno** (lo medido y el escalamiento). En una entrega de requerimiento, soporte interno no lleva SQL.

Título: {meta.get("titulo") or ""}
Cliente: {meta.get("cliente") or ""}
Servidor: {meta.get("servidorId") or "—"} · base {meta.get("baseDatos") or "—"}
{_bloque_validar_base(meta)}{_bloque_capturas(sid, meta)}"""


def escribir_instruccion(sid: str) -> None:
    meta = leer_meta(sid)
    (carpeta_consulta(sid) / "INSTRUCCION-AGENTE.md").write_text(
        _instruccion_md(sid, meta), encoding="utf-8"
    )


def _ensure_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _read_json(path: Path, default):
    if not path.is_file():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_index() -> dict:
    _ensure_dir()
    return _read_json(INDEX_FILE, {"consultas": []})


def _save_index(idx: dict) -> None:
    _write_json(INDEX_FILE, idx)


def nueva_id() -> str:
    return f"sc{datetime.now().strftime('%Y%m%d-%H%M%S')}"


def carpeta_consulta(sid: str) -> Path:
    safe = _ID_SAFE.sub("", sid or "")
    if not safe.startswith("sc"):
        raise ValueError("Consulta no válida.")
    p = DATA_DIR / safe
    if not p.is_dir():
        raise FileNotFoundError("Consulta no encontrada.")
    return p


def crear_consulta(
    titulo: str,
    pregunta: str,
    solicitante: str = "",
    cliente: str = "",
    servidor_id: str = "",
    base_datos: str = "",
    validar_en_base: bool = False,
) -> dict:
    _ensure_dir()
    titulo = (titulo or "").strip()
    pregunta = (pregunta or "").strip()
    if not titulo:
        raise ValueError("Indique un título breve para la consulta.")
    if not pregunta:
        raise ValueError("Indique la pregunta o contexto inicial.")
    if validar_en_base and (not (servidor_id or "").strip() or not (base_datos or "").strip()):
        raise ValueError("Indique el servidor y la base. La validación es solo lectura.")
    sid = nueva_id()
    carp = DATA_DIR / sid
    carp.mkdir(parents=True, exist_ok=True)
    meta = {
        "id": sid,
        "titulo": titulo[:200],
        "solicitante": (solicitante or "").strip(),
        "cliente": (cliente or "").strip(),
        "preguntaInicial": pregunta,
        "validarEnBase": bool(validar_en_base),
        "servidorId": (servidor_id or "").strip() if validar_en_base else "",
        "baseDatos": (base_datos or "").strip() if validar_en_base else "",
        "respuestaOficial": "",
        "proposito": "",
        "creado": datetime.now().isoformat(timespec="seconds"),
        "estado": "abierta",
        "documentoGenerado": None,
        "pdfGenerado": None,
        "cerrada": None,
    }
    _write_json(carp / "meta.json", meta)
    chat = {"mensajes": []}
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": "soporte",
        "texto": pregunta,
        "en": meta["creado"],
    }
    chat["mensajes"].append(msg)
    _write_json(carp / "chat.json", chat)
    escribir_instruccion(sid)
    idx = _load_index()
    fila = {
        k: meta[k]
        for k in (
            "id",
            "titulo",
            "solicitante",
            "cliente",
            "creado",
            "estado",
            "documentoGenerado",
            "pdfGenerado",
        )
    }
    consultas = [c for c in idx.get("consultas", []) if c.get("id") != sid]
    consultas.insert(0, fila)
    idx["consultas"] = consultas[:100]
    _save_index(idx)
    return meta


def listar_consultas(limit: int = 40) -> list[dict]:
    return (_load_index().get("consultas") or [])[:limit]


def leer_meta(sid: str) -> dict:
    return _read_json(carpeta_consulta(sid) / "meta.json", {})


def vincular_solicitud(sid: str, id_sr: str) -> dict:
    """Deja en la consulta el id de la solicitud de requerimiento generada."""
    meta = leer_meta(sid)
    meta["solicitudId"] = (id_sr or "").strip()
    meta["solicitudEn"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    return meta


def generar_requerimiento(sid: str, textos: dict | None = None, nota: str = "") -> dict:
    """Crea (o reabre el vínculo de) la solicitud de comité a partir de esta consulta."""
    import solicitud_req as solreq

    meta = leer_meta(sid)
    mensajes = leer_chat(sid).get("mensajes") or []
    sol = solreq.crear_desde_consulta_soporte(meta, mensajes, textos=textos, nota=nota)
    ya = bool(sol.pop("_yaExistia", False))
    id_sr = (sol.get("id") or "").strip()
    if id_sr:
        vincular_solicitud(sid, id_sr)
    if id_sr and not ya:
        append_chat(
            sid,
            "sistema",
            f"Solicitud de requerimiento {id_sr}: {sol.get('titulo') or 'sin título'}. "
            "Quedó abierta en Solicitar requerimiento.",
        )
    return {"yaExistia": ya, "solicitud": sol}


def leer_chat(sid: str) -> dict:
    return _read_json(carpeta_consulta(sid) / "chat.json", {"mensajes": []})


_IMG_MIME = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/webp": ".webp",
    "image/gif": ".gif",
}
_IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
_IMG_MAX = 8 * 1024 * 1024


def _bloque_validar_base(meta: dict) -> str:
    if not meta.get("validarEnBase"):
        return (
            "\nValidar en base: no. No conecte a una base salvo que el chat lo pida. "
            "Responda con la explicación del proceso.\n"
        )
    return """
Validar en base: sí, solo lectura. Atienda esta consulta como soporte.

La respuesta oficial se lee sola, en palabras de la pantalla. Abra con la causa y siga con lo que la persona debe hacer. Ejemplo de tono, no de este caso: «En la configuración de ese contrato no hay paquetes. Por eso la lista sale vacía y el valor queda en cero. El paquete se configura en la contratación: se elige el contrato, Excepción Servicios, Nuevo, se marca Paquete y se guarda el detalle.»

No abra con el grafo, el nodo, el método ni con lo que la documentación nombra o deja de nombrar. No escriba «no clasifico», «no invento» ni «no puedo afirmar» como respuesta. Nombres de procedimiento, vista y medición van solo en una sección corta **Para soporte interno**.

Mida con SELECT en el servidor y la base de arriba (`scripts/auditoria_procesos.py`, `_resolve_server_db` y `_sqlcmd_query`). No imprima credenciales. No escriba en la base. Si la medición no corre, igual responda la causa que ya se ve en la captura; deje una línea en soporte interno.

Si el tramo que explica la causa no está en el índice o su ficha no es `leido`: léalo (SQL en DESAIX, pantalla en Qrystalos2), escriba esa ficha y, si es vista, la descripción en el diccionario. Si queda más de ese objeto sin leer, deje un ítem abierto en `conocimiento/pendientes.json`. La respuesta al usuario no espera ese pendiente y no habla del hueco.
"""


def _bloque_capturas(sid: str, meta: dict) -> str:
    imgs = meta.get("imagenes") or []
    if not imgs:
        return ""
    lines = "\n".join(
        f"- data/soporte-consultas/{sid}/imagenes/{i.get('nombre')}"
        for i in imgs
        if i.get("nombre")
    )
    if not lines:
        return ""
    return (
        "\n## Capturas\n"
        "La consulta incluye imágenes. Léalas y contrástelas con la pregunta:\n"
        f"{lines}\n"
    )


def _nombre_imagen(nombre: str, ext: str) -> str:
    base = re.sub(r"[^\w.\-]", "_", Path(nombre or "").name)[:140]
    stem = Path(base).stem if base else ""
    if not stem or stem.startswith("."):
        stem = f"captura-{datetime.now().strftime('%H%M%S')}"
    got = Path(base).suffix.lower() if base else ""
    if got not in _IMG_EXT:
        got = ext
    return f"{stem}{got}"[:180]


def _ruta_imagen(sid: str, nombre: str) -> Path:
    fname = Path(nombre or "").name
    if not fname or fname != (nombre or "") or ".." in (nombre or ""):
        raise ValueError("Nombre de imagen no válido.")
    if Path(fname).suffix.lower() not in _IMG_EXT:
        raise ValueError("Formato no admitido. Use PNG, JPG, WebP o GIF.")
    return carpeta_consulta(sid) / "imagenes" / fname


def _ficha_imagen(sid: str, nombre: str) -> dict:
    return {
        "nombre": nombre,
        "url": f"/api/soporte-consultas/{sid}/imagen/{nombre}",
    }


def _imagenes_validas(sid: str, imagenes: list | None) -> list[dict]:
    out: list[dict] = []
    vistos: set[str] = set()
    for item in imagenes or []:
        nombre = item.get("nombre") if isinstance(item, dict) else item
        try:
            path = _ruta_imagen(sid, str(nombre or ""))
        except ValueError:
            continue
        if not path.is_file() or path.name in vistos:
            continue
        vistos.add(path.name)
        out.append(_ficha_imagen(sid, path.name))
    return out


def guardar_imagen(sid: str, data_url: str, nombre: str = "") -> dict:
    raw = (data_url or "").strip()
    match = re.match(r"^data:(image/[a-zA-Z0-9.+-]+);base64,(.+)$", raw, re.S)
    if not match:
        raise ValueError("Se espera una imagen (PNG, JPG, WebP o GIF).")
    ext = _IMG_MIME.get(match.group(1).lower())
    if not ext:
        raise ValueError("Formato no admitido. Use PNG, JPG, WebP o GIF.")
    try:
        blob = base64.b64decode(match.group(2), validate=False)
    except Exception as exc:
        raise ValueError("La imagen no se pudo leer.") from exc
    if not blob or len(blob) > _IMG_MAX:
        raise ValueError("La imagen supera 8 MB.")
    carp = carpeta_consulta(sid)
    dest_dir = carp / "imagenes"
    dest_dir.mkdir(exist_ok=True)
    fname = _nombre_imagen(nombre, ext)
    path = dest_dir / fname
    n = 2
    while path.exists():
        path = dest_dir / f"{Path(fname).stem}-{n}{path.suffix}"
        fname = path.name
        n += 1
    path.write_bytes(blob)
    meta = leer_meta(sid)
    item = {
        **_ficha_imagen(sid, fname),
        "subidaEn": datetime.now().isoformat(timespec="seconds"),
    }
    imgs = [i for i in (meta.get("imagenes") or []) if i.get("nombre") != fname]
    imgs.append(item)
    meta["imagenes"] = imgs
    _write_json(carp / "meta.json", meta)
    escribir_instruccion(sid)
    return item


def quitar_imagen(sid: str, nombre: str) -> dict:
    path = _ruta_imagen(sid, nombre)
    if path.is_file():
        path.unlink()
    meta = leer_meta(sid)
    meta["imagenes"] = [i for i in (meta.get("imagenes") or []) if i.get("nombre") != path.name]
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    chat = leer_chat(sid)
    for msg in chat.get("mensajes") or []:
        if isinstance(msg.get("imagenes"), list):
            msg["imagenes"] = [i for i in msg["imagenes"] if i.get("nombre") != path.name]
    _write_json(carpeta_consulta(sid) / "chat.json", chat)
    escribir_instruccion(sid)
    return meta


def html_capturas(sid: str) -> str:
    """Incrusta las capturas en el HTML: el PDF se arma desde archivo local."""
    meta = leer_meta(sid)
    carp = carpeta_consulta(sid) / "imagenes"
    partes: list[str] = []
    mime = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
    }
    for img in meta.get("imagenes") or []:
        if img.get("origen") in ("gemini", "cursor"):
            continue
        nombre = Path(str(img.get("nombre") or "")).name
        path = carp / nombre
        if not path.is_file() or path.suffix.lower() not in _IMG_EXT:
            continue
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
        src = f"data:{mime.get(path.suffix.lower(), 'image/png')};base64,{encoded}"
        partes.append(
            f'<figure class="doc-captura"><img src="{src}" alt="{_esc(nombre)}">'
            f"<figcaption>{_esc(nombre)}</figcaption></figure>"
        )
    if not partes:
        return ""
    return '<div class="doc-capturas">' + "".join(partes) + "</div>"


def normalizar_timestamps_chat(sid: str) -> int:
    """Normaliza timestamps y IDs de mensajes del agente tras un turno.
    
    Corrige mensajes con:
    - Timestamp futuro, faltante o fuera del rango razonable
    - ID faltante o duplicado
    
    Retorna la cantidad de mensajes corregidos.
    """
    chat = leer_chat(sid)
    mensajes = chat.get("mensajes") or []
    if not mensajes:
        return 0
    
    ahora = datetime.now()
    corregidos = 0
    ids_vistos: set[str] = set()
    
    for msg in mensajes:
        if msg.get("autor") != "agente":
            if msg.get("id"):
                ids_vistos.add(msg["id"])
            continue
        
        cambio_msg = False
        
        # Validar timestamp
        en = msg.get("en")
        try:
            if en:
                ts = datetime.fromisoformat(str(en))
                # Si es futuro o más de 7 días atrás, corregir
                delta = (ahora - ts).total_seconds()
                if delta < 0 or delta > 7 * 24 * 3600:
                    raise ValueError("Timestamp fuera de rango")
            else:
                raise ValueError("Timestamp faltante")
        except (ValueError, TypeError):
            # Timestamp inválido: usar ahora
            msg["en"] = ahora.isoformat(timespec="seconds")
            cambio_msg = True
        
        # Validar ID
        msg_id = msg.get("id")
        if not msg_id or msg_id in ids_vistos:
            # Generar nuevo ID único
            base_id = ahora.strftime("%Y%m%d%H%M%S%f")
            contador = 0
            while f"{base_id}a{contador}" in ids_vistos:
                contador += 1
            msg["id"] = f"{base_id}a{contador}"
            ids_vistos.add(msg["id"])
            cambio_msg = True
        else:
            ids_vistos.add(msg_id)
        
        if cambio_msg:
            corregidos += 1
    
    if corregidos > 0:
        _write_json(carpeta_consulta(sid) / "chat.json", chat)
    
    return corregidos


def append_chat(sid: str, autor: str, texto: str, imagenes: list | None = None) -> dict:
    autor = (autor or "soporte").strip().lower()
    if autor not in _AUTORES:
        autor = "soporte"
    texto = (texto or "").strip()
    
    # Si el texto viene con el prefijo [sistema] pero autor no es sistema, corregirlo
    if texto.startswith("[sistema] ") and autor != "sistema":
        texto = texto[len("[sistema] "):]
        autor = "sistema"
    
    imgs = _imagenes_validas(sid, imagenes)
    if not texto and not imgs:
        raise ValueError("Mensaje vacío.")
    if not texto:
        texto = "Captura adjunta."
    chat = leer_chat(sid)
    msg = {
        "id": datetime.now().strftime("%Y%m%d%H%M%S%f"),
        "autor": autor,
        "texto": texto,
        "en": datetime.now().isoformat(timespec="seconds"),
    }
    if imgs:
        msg["imagenes"] = imgs
    chat.setdefault("mensajes", []).append(msg)
    _write_json(carpeta_consulta(sid) / "chat.json", chat)
    return msg


def guardar_respuesta(sid: str, respuesta: str, proposito: str | None = None) -> dict:
    meta = leer_meta(sid)
    meta["respuestaOficial"] = (respuesta or "").strip()
    if proposito is not None:
        meta["proposito"] = (proposito or "").strip()
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    return meta


def actualizar_meta(sid: str, **campos) -> dict:
    meta = leer_meta(sid)
    meta.update(campos)
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    idx = _load_index()
    for c in idx.get("consultas", []):
        if c.get("id") == sid:
            for k in ("estado", "documentoGenerado", "pdfGenerado", "titulo", "cliente"):
                if k in campos:
                    c[k] = campos[k]
            break
    _save_index(idx)
    return meta


def cerrar_consulta(sid: str) -> dict:
    meta = leer_meta(sid)
    meta["estado"] = "cerrada"
    meta["cerrada"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    idx = _load_index()
    for c in idx.get("consultas", []):
        if c.get("id") == sid:
            c["estado"] = meta["estado"]
            break
    _save_index(idx)
    return meta


def _esc(s: str) -> str:
    return html_lib.escape(str(s or ""))


_SEP_DECOR = re.compile(r"^═{10,}\s*$")
_FENCE = re.compile(r"```([a-zA-Z0-9_-]*)\r?\n([\s\S]*?)```")
_SQL_LINE = re.compile(
    r"^\s*(--|SELECT|WITH|DECLARE|INSERT|UPDATE|DELETE|FROM|JOIN|LEFT|RIGHT|INNER|OUTER|WHERE|GROUP|ORDER|EXEC|COALESCE|CASE|WHEN)\b",
    re.I,
)


def _looks_like_sql(para: str) -> bool:
    lines = [ln for ln in (para or "").splitlines() if ln.strip()]
    if not lines:
        return False
    hits = sum(1 for ln in lines if _SQL_LINE.match(ln))
    if hits >= 2:
        return True
    if len(lines) >= 1 and hits >= 1 and any(";" in ln for ln in lines):
        return True
    return bool(len(lines) >= 4 and hits >= 1 and lines[0].lstrip().startswith("--"))


def _sql_bloque_html(titulo: str | None, codigo: str, *, aviso: bool = True) -> str:
    codigo = (codigo or "").strip("\n")
    if not codigo:
        return ""
    h = ""
    if titulo:
        h += f'<p class="sql-block-title">{_esc(titulo.replace(chr(10), " · "))}</p>\n'
    if aviso:
        h += (
            '<p class="sql-aviso"><strong>Consulta SQL</strong> — Copie y pegue en SQL Server '
            "(solo lectura; valide en copia/preversión).</p>\n"
        )
    h += f'<pre class="sql-spec">{_esc(codigo)}</pre>\n'
    return h


def _parrafos(texto: str) -> str:
    t = (texto or "").strip()
    if not t:
        return '<p class="meta">(Sin texto)</p>'
    return _markdown_basico(t)


_MD_HEADING = re.compile(r"^(#{1,4})\s+(.+?)\s*$")
_MD_NUMBERED_HEADING = re.compile(r"^(\d+(?:\.\d+)*)[.)]\s+(.+?)\s*$")
_MD_UL = re.compile(r"^\s*[-*•]\s+(.+?)\s*$")
_MD_OL = re.compile(r"^\s*(\d+)[.)]\s+(.+?)\s*$")
_MD_TABLE_SEPARATOR = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$")


def _inline_md(texto: str) -> str:
    """Markdown inline seguro: énfasis y código, sin permitir HTML de entrada."""
    value = _esc(texto)
    placeholders: list[str] = []

    def code_repl(match: re.Match) -> str:
        placeholders.append(f"<code>{match.group(1)}</code>")
        return f"\x00CODE{len(placeholders) - 1}\x00"

    value = re.sub(r"`([^`\n]+)`", code_repl, value)
    value = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"__(.+?)__", r"<strong>\1</strong>", value)
    value = re.sub(r"(?<!\*)\*([^*\n]+?)\*(?!\*)", r"<em>\1</em>", value)
    for idx, rendered in enumerate(placeholders):
        value = value.replace(f"\x00CODE{idx}\x00", rendered)
    return value


def _table_cells(line: str) -> list[str]:
    value = line.strip()
    if value.startswith("|"):
        value = value[1:]
    if value.endswith("|"):
        value = value[:-1]
    return [cell.strip() for cell in value.split("|")]


def _render_table(lines: list[str], start: int) -> tuple[str, int] | None:
    if start + 1 >= len(lines) or "|" not in lines[start]:
        return None
    if not _MD_TABLE_SEPARATOR.match(lines[start + 1]):
        return None
    headers = _table_cells(lines[start])
    rows: list[list[str]] = []
    i = start + 2
    while i < len(lines) and lines[i].strip() and "|" in lines[i]:
        rows.append(_table_cells(lines[i]))
        i += 1
    head = "".join(f"<th>{_inline_md(cell)}</th>" for cell in headers)
    body = "".join(
        "<tr>"
        + "".join(
            f"<td>{_inline_md(row[col] if col < len(row) else '')}</td>"
            for col in range(len(headers))
        )
        + "</tr>"
        for row in rows
    )
    return (
        '<div class="table-wrap"><table><thead><tr>'
        + head
        + "</tr></thead><tbody>"
        + body
        + "</tbody></table></div>",
        i,
    )


def _paragraph_class(texto: str) -> str:
    plain = re.sub(r"[*_`]", "", texto).strip().lower()
    if plain.startswith(("importante:", "atención:", "advertencia:")):
        return "callout callout-warning"
    if plain.startswith(("recomendación:", "recomendacion:", "idea clave:", "resultado esperado:")):
        return "callout callout-tip"
    if plain.startswith(("nota:", "tenga en cuenta:", "cómo leer", "como leer")):
        return "callout callout-info"
    return ""


def _markdown_basico(texto: str) -> str:
    """Convierte el formato habitual del agente a HTML de manual, sin dependencias."""
    lines = (texto or "").replace("\r\n", "\n").splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()
        if not stripped:
            i += 1
            continue
        if re.fullmatch(r"-{3,}", stripped):
            out.append('<hr class="section-rule">')
            i += 1
            continue

        table = _render_table(lines, i)
        if table:
            rendered, i = table
            out.append(rendered)
            continue

        heading = _MD_HEADING.match(stripped)
        if heading:
            level = min(4, len(heading.group(1)) + 1)
            out.append(f"<h{level}>{_inline_md(heading.group(2))}</h{level}>")
            i += 1
            continue

        numbered = _MD_NUMBERED_HEADING.match(stripped)
        if numbered and (i + 1 == len(lines) or not lines[i + 1].strip()):
            depth = numbered.group(1).count(".")
            tag = "h3" if depth == 0 else "h4"
            out.append(
                f'<{tag} class="numbered-heading"><span>{_esc(numbered.group(1))}</span>'
                f"{_inline_md(numbered.group(2))}</{tag}>"
            )
            i += 1
            continue

        unordered = _MD_UL.match(raw)
        ordered = _MD_OL.match(raw)
        if unordered or ordered:
            list_tag = "ul" if unordered else "ol"
            items: list[str] = []
            while i < len(lines):
                match = (_MD_UL if list_tag == "ul" else _MD_OL).match(lines[i])
                if not match:
                    break
                item_text = match.group(1 if list_tag == "ul" else 2)
                items.append(f"<li>{_inline_md(item_text)}</li>")
                i += 1
            out.append(f'<{list_tag} class="manual-list">' + "".join(items) + f"</{list_tag}>")
            continue

        paragraph: list[str] = [stripped]
        i += 1
        while i < len(lines) and lines[i].strip():
            candidate = lines[i].strip()
            if (
                _MD_HEADING.match(candidate)
                or _MD_UL.match(lines[i])
                or _MD_OL.match(lines[i])
                or re.fullmatch(r"-{3,}", candidate)
                or _render_table(lines, i)
            ):
                break
            paragraph.append(candidate)
            i += 1
        joined = "<br>".join(_inline_md(line) for line in paragraph)
        css_class = _paragraph_class(" ".join(paragraph))
        class_attr = f' class="{css_class}"' if css_class else ""
        out.append(f"<p{class_attr}>{joined}</p>")
    return "".join(out)


def _parrafos_mixed(text: str) -> str:
    chunks = re.split(r"\n\s*\n", (text or "").strip())
    out: list[str] = []
    for chunk in chunks:
        c = chunk.strip()
        if not c:
            continue
        if _looks_like_sql(c):
            out.append(_sql_bloque_html(None, c))
        else:
            out.append(_markdown_basico(c))
    return "".join(out)


def _procesar_texto_plano(text: str) -> str:
    parts: list[str] = []
    pos = 0
    for m in _FENCE.finditer(text):
        if m.start() > pos:
            parts.append(_parrafos_mixed(text[pos : m.start()]))
        lang = (m.group(1) or "").lower()
        code = m.group(2).strip("\n")
        if lang in ("sql", "tsql", "mssql") or _looks_like_sql(code):
            parts.append(_sql_bloque_html(None, code))
        else:
            parts.append(f'<pre class="text-spec">{_esc(code)}</pre>')
        pos = m.end()
    if pos < len(text):
        parts.append(_parrafos_mixed(text[pos:]))
    return "".join(parts)


def _procesar_bloques_decorativos(text: str) -> str:
    lines = text.replace("\r\n", "\n").splitlines()
    out_parts: list[str] = []
    text_buf: list[str] = []
    i = 0
    n = len(lines)

    def flush_text() -> None:
        nonlocal text_buf
        if text_buf:
            blob = "\n".join(text_buf)
            out_parts.append(_procesar_texto_plano(blob))
            text_buf = []

    while i < n:
        if _SEP_DECOR.match(lines[i].strip()):
            flush_text()
            i += 1
            title_lines: list[str] = []
            while i < n and not _SEP_DECOR.match(lines[i].strip()):
                title_lines.append(lines[i])
                i += 1
            if i < n:
                i += 1
            title = "\n".join(title_lines).strip()
            sql_lines: list[str] = []
            while i < n:
                if _SEP_DECOR.match(lines[i].strip()):
                    break
                low = lines[i].strip().lower()
                if low.startswith("notas (no copiar"):
                    notes = "\n".join(lines[i:])
                    out_parts.append(_parrafos_mixed(notes))
                    return "".join(out_parts)
                sql_lines.append(lines[i])
                i += 1
            if title.lower().startswith("notas"):
                out_parts.append(_parrafos_mixed(title + "\n\n" + "\n".join(sql_lines)))
            else:
                out_parts.append(_sql_bloque_html(title, "\n".join(sql_lines)))
            continue
        text_buf.append(lines[i])
        i += 1
    flush_text()
    return "".join(out_parts)


def _quitar_consultas_sql(texto: str) -> str:
    """Entrega de requerimiento: el PDF no lleva consultas SQL."""
    t = _FENCE.sub(
        lambda m: ""
        if (m.group(1) or "").lower() in ("sql", "tsql", "mssql") or _looks_like_sql(m.group(2))
        else m.group(0),
        texto or "",
    )
    partes = []
    for bloque in re.split(r"\n\s*\n", t):
        if _looks_like_sql(bloque) or "═" in bloque:
            continue
        partes.append(bloque.strip())
    return re.sub(r"\n{3,}", "\n\n", "\n\n".join(p for p in partes if p)).strip()


def _partir_solucion(texto: str) -> tuple[str, str]:
    """Separa «Solución realizada» del resto, para pintarla justo después de la necesidad."""
    t = (texto or "").replace("\r\n", "\n").strip()
    marca = re.search(r"(?m)^##\s+Solución realizada\s*$", t)
    if not marca:
        return "", t
    siguiente = re.search(r"(?m)^##\s+", t[marca.end() :])
    if not siguiente:
        return t[marca.end() :].strip(), ""
    corte = marca.end() + siguiente.start()
    return t[marca.end() : corte].strip(), t[corte:].strip()


def texto_respuesta_a_html(texto: str, *, incluir_sql: bool = True) -> str:
    """Respuesta oficial → HTML. La entrega de requerimiento no pinta consultas SQL."""
    t = (texto or "").replace("\r\n", "\n").strip()
    if not incluir_sql:
        t = _quitar_consultas_sql(t)
    if not t:
        return '<p class="meta">(Sin texto)</p>'
    if incluir_sql and "═" in t and _SEP_DECOR.search(t):
        return _procesar_bloques_decorativos(t)
    return _procesar_texto_plano(t)


def _logo_embebido(logo_href: str) -> str:
    """El PDF se genera desde file://; incrusta el logo para que no dependa del servidor."""
    logo = ROOT / "app" / "assets" / "logo-ixcolombia.svg"
    if logo.is_file():
        encoded = base64.b64encode(logo.read_bytes()).decode("ascii")
        return f"data:image/svg+xml;base64,{encoded}"
    return logo_href


def _trunc(text: str, max_len: int) -> str:
    t = (text or "").replace("\r\n", "\n").strip()
    if len(t) <= max_len:
        return t
    return t[: max_len - 1].rstrip() + "…"


def _resumen_analisis_respuesta(respuesta: str) -> str:
    """Primer párrafo útil de la respuesta (sin SQL ni bloques decorativos)."""
    t = (respuesta or "").replace("\r\n", "\n").strip()
    if not t:
        return ""
    for part in re.split(r"\n\s*\n", t):
        p = part.strip()
        if not p or p.startswith("═") or _looks_like_sql(p):
            continue
        if re.match(r"^(Informe|Reporte|Respuesta)\s*[—–-]", p, re.I):
            continue
        if re.match(r"^\d+\.\s", p):
            one = p.split("\n", 1)[0]
            return _trunc(one.replace("\n", " "), 520)
        return _trunc(p.replace("\n", " "), 520)
    m = re.search(r"(?m)^\d+\.\s.+", t)
    if m:
        return _trunc(m.group(0).replace("\n", " "), 520)
    return ""


def resolver_proposito(meta: dict) -> str:
    """Propósito del PDF: explícito en meta o sintetizado desde necesidad + análisis."""
    manual = (meta.get("proposito") or "").strip()
    if manual:
        return manual
    cliente = (meta.get("cliente") or "").strip()
    titulo = (meta.get("titulo") or "").strip()
    pregunta = (meta.get("preguntaInicial") or "").strip()
    need = pregunta.split("\n\n")[0].replace("\n", " ").strip() or titulo
    need = _trunc(need, 420)
    analisis = _resumen_analisis_respuesta(meta.get("respuestaOficial") or "")
    cli = f" para {cliente}" if cliente else ""
    if analisis:
        return (
            f"Atender la necesidad planteada{cli}: {need} "
            f"Este documento entrega la respuesta oficial según el análisis realizado; "
            f"en síntesis: {analisis}"
        )
    return (
        f"Atender la necesidad planteada{cli}: {need} "
        "Este documento consolida la respuesta oficial derivada de ese planteamiento."
    )


def _html_figura(path: Path, titulo: str) -> str:
    mime = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
    }
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    src = f"data:{mime.get(path.suffix.lower(), 'image/png')};base64,{encoded}"
    return (
        f'<figure class="doc-captura"><img src="{src}" alt="{_esc(titulo)}">'
        f"<figcaption>{_esc(titulo)}</figcaption></figure>"
    )


def html_ilustraciones(sid: str) -> str:
    meta = leer_meta(sid)
    carp = carpeta_consulta(sid) / "imagenes"
    partes: list[str] = []
    for img in meta.get("imagenes") or []:
        if img.get("origen") not in ("gemini", "cursor"):
            continue
        nombre = Path(str(img.get("nombre") or "")).name
        path = carp / nombre
        if not path.is_file():
            continue
        titulo = str(img.get("titulo") or nombre)
        partes.append(_html_figura(path, titulo))
    if not partes:
        return ""
    return '<div class="doc-capturas">' + "".join(partes) + "</div>"


def html_flujo(pasos: list) -> str:
    items = []
    for paso in pasos or []:
        frase = str(paso or "").strip()
        if frase:
            items.append(f"<li>{_esc(frase)}</li>")
    if not items:
        return ""
    return (
        '<h3>Flujo en el aplicativo</h3>'
        '<ol class="manual-list">' + "".join(items) + "</ol>"
    )


def _quitar_ilustraciones_gemini(sid: str) -> None:
    meta = leer_meta(sid)
    carp = carpeta_consulta(sid) / "imagenes"
    quedan = []
    for img in meta.get("imagenes") or []:
        if img.get("origen") not in ("gemini", "cursor"):
            quedan.append(img)
            continue
        path = carp / Path(str(img.get("nombre") or "")).name
        if path.is_file():
            path.unlink()
    meta["imagenes"] = quedan
    _write_json(carpeta_consulta(sid) / "meta.json", meta)


def _guia_documentada(texto: str) -> dict:
    """Flujos y ventanas del proceso citado en la respuesta oficial. No inventa pasos."""
    import conocimiento as kb
    import diagrama_flujo as diagflujo
    import mockup_generar as mockgen

    bajo = (texto or "").lower()
    vistos: list[str] = []
    for patron in (
        r"proceso documentado:\**\s*`?([a-z0-9][a-z0-9_-]{1,40})",
        r"conocimiento/([a-z0-9][a-z0-9_-]{1,40})",
    ):
        for hallado in re.findall(patron, bajo):
            if hallado not in vistos and kb.load_proceso(hallado):
                vistos.append(hallado)
    if not vistos:
        return {"flujos": [], "ventanas": [], "pantallas": []}
    proceso = kb.load_proceso(vistos[0]) or {}
    flujos = []
    for flujo in proceso.get("flujos") or []:
        if not isinstance(flujo, dict):
            continue
        puntaje = 0
        blob = f"{flujo.get('id') or ''} {flujo.get('nombre') or ''}".lower().replace("-", " ")
        for token in re.findall(r"[a-záéíóúñ0-9]{5,}", blob):
            if token in bajo:
                puntaje += 2
        for paso in flujo.get("pasos") or []:
            if not isinstance(paso, dict):
                continue
            pantalla = str(paso.get("pantalla") or "").strip().lower()
            titulo = str(paso.get("titulo") or "").strip().lower()
            if pantalla and pantalla in bajo:
                puntaje += 4
            if titulo and titulo in bajo:
                puntaje += 3
        if puntaje >= 4:
            flujos.append(flujo)
        if len(flujos) >= 2:
            break
    pantallas: list[str] = []
    for flujo in flujos:
        for paso in flujo.get("pasos") or []:
            nombre = str((paso or {}).get("pantalla") or "").strip()
            if nombre and nombre not in pantallas:
                pantallas.append(nombre)
    candidatas = []
    for ventana in proceso.get("ventanas") or []:
        if not isinstance(ventana, dict):
            continue
        path = str(ventana.get("path") or "").strip()
        if not path or path.lower() not in bajo:
            continue
        candidatas.append((bajo.find(path.lower()), ventana))
    candidatas.sort(key=lambda par: par[0])
    ventanas = [ventana for _pos, ventana in candidatas[:4]]
    return {
        "flujos": flujos,
        "ventanas": ventanas,
        "pantallas": pantallas,
        "diagrama": diagflujo.fragmento_guia(flujos),
        "mockup": mockgen.fragmento_pantallas(ventanas),
    }


def preparar_presentacion(sid: str) -> dict:
    """No llama a una API externa. El texto y las ilustraciones los deja el agente de Cursor."""
    meta = leer_meta(sid)
    oficial = (meta.get("respuestaOficial") or "").strip()
    if len(oficial) < 40:
        raise ValueError("Complete la respuesta oficial antes de generar el documento.")
    return meta


def generar_html_documento(
    sid: str,
    logo_href: str = "/app/assets/logo-ixcolombia.svg",
    presentar: bool = False,
) -> tuple[str, dict]:
    meta_pre = leer_meta(sid)
    if meta_pre.get("entregaRequerimiento"):
        import entrega_requerimiento as entrega

        return entrega.generar_documento(sid, presentar=presentar)
    if presentar:
        preparar_presentacion(sid)
    meta = leer_meta(sid)
    hoy = date.today().isoformat()
    respuesta = (meta.get("documentoUsuario") or meta.get("respuestaOficial") or "")
    if not respuesta.strip():
        raise ValueError("Complete la «Respuesta oficial» antes de generar el documento.")

    proposito = resolver_proposito(meta)
    proposito_html = _esc(proposito).replace(chr(10), "<br>")
    guia = _guia_documentada(meta.get("respuestaOficial") or respuesta)
    diagrama = guia.get("diagrama") or ""
    mockup = guia.get("mockup") or ""
    flujo_simple = "" if diagrama else html_flujo(meta.get("flujoDocumento") or [])
    guia_html = diagrama + mockup + flujo_simple
    logo_src = _logo_embebido(logo_href)
    entrega = bool(meta.get("entregaRequerimiento"))
    solucion_txt, respuesta_resto = _partir_solucion(respuesta) if entrega else ("", respuesta)
    solucion_html = (
        texto_respuesta_a_html(solucion_txt, incluir_sql=False) if solucion_txt else ""
    )
    bloque_solucion = (
        f'<section class="solution-card"><h2>Solución realizada</h2>{solucion_html}</section>'
        if solucion_html
        else ""
    )
    area = "Entrega de requerimiento" if entrega else "Business Analyst · Soporte Qrystalos"
    kind = "Entrega de requerimiento" if entrega else "Guía de soporte"
    eyebrow = "Qué quedó resuelto" if entrega else "Orientación funcional y operativa"
    titulo_proposito = "Propósito de esta entrega" if entrega else "Propósito de esta guía"
    titulo_manual = "Qué se entrega" if entrega else "Guía de solución"
    pie = "Qrystalos BA · Entrega de requerimiento" if entrega else "Qrystalos BA · Documento de orientación para soporte"
    etiqueta_id = "Entrega" if entrega else "Consulta"

    doc = f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{_esc(meta.get('titulo'))} — Respuesta soporte</title>
  <style>
    :root {{
      --brand: #e67817; --brand-dark: #a94908; --brand-soft: #fff5ea;
      --ink: #172033; --text: #344054; --muted: #667085; --line: #e4e7ec;
      --surface: #f8fafc; --success: #087a55; --info: #175cd3;
    }}
    * {{ box-sizing: border-box; }}
    @page {{ size: A4; margin: 14mm 15mm 16mm; }}
    html {{ background: #eef1f5; }}
    body {{ font-family: "Segoe UI", Aptos, Calibri, sans-serif; font-size: 10.5pt; line-height: 1.58;
      color: var(--text); background: #eef1f5; margin: 0; padding: 28px; }}
    .container {{ max-width: 900px; margin: 0 auto; background: #fff; box-shadow: 0 12px 32px rgba(16,24,40,.10); }}
    .top-accent {{ height: 7px; background: linear-gradient(90deg, var(--brand) 0 72%, #273248 72%); }}
    .page-content {{ padding: 30px 42px 26px; }}
    .brand-head {{ display: flex; align-items: center; justify-content: space-between; gap: 18px;
      padding-bottom: 20px; border-bottom: 1px solid var(--line); }}
    .brand-id {{ display:flex; align-items:center; gap:13px; }}
    .brand-mark {{ height: 42px; width: auto; background: #111827; border-radius: 9px; padding: 5px 9px; }}
    .brand-name {{ font-weight: 750; letter-spacing: .08em; color: var(--ink); }}
    .brand-area {{ color: var(--muted); text-transform: uppercase; font-size: 7.5pt; letter-spacing: .11em; }}
    .doc-kind {{ color: var(--brand-dark); background: var(--brand-soft); border: 1px solid #f7d6b5;
      border-radius: 999px; padding: 5px 11px; font-size: 7.5pt; font-weight: 700; letter-spacing: .06em;
      text-transform: uppercase; white-space: nowrap; }}
    .title-block {{ padding: 26px 0 18px; }}
    .eyebrow {{ margin: 0 0 7px; color: var(--brand-dark); font-size: 8pt; font-weight: 750;
      text-transform: uppercase; letter-spacing: .12em; }}
    h1 {{ color: var(--ink); font-size: 24pt; line-height: 1.16; letter-spacing: -.025em; margin: 0; font-weight: 730; }}
    .doc-meta {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin: 0 0 20px; }}
    .meta-item {{ background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; min-width: 0; }}
    .meta-label {{ display:block; color:var(--muted); font-size: 7pt; font-weight:700; letter-spacing:.06em;
      text-transform:uppercase; margin-bottom:2px; }}
    .meta-value {{ display:block; color:var(--ink); font-size:8.5pt; font-weight:600; overflow-wrap:anywhere; }}
    .doc-purpose {{ position: relative; background: linear-gradient(135deg, #fff8f0, #fff);
      border: 1px solid #f5d4b2; border-radius: 10px; padding: 15px 18px 15px 50px; margin: 0 0 24px; }}
    .doc-purpose::before {{ content:"✓"; position:absolute; left:17px; top:16px; display:grid; place-items:center;
      width:22px; height:22px; border-radius:50%; background:var(--brand); color:#fff; font-weight:800; }}
    .doc-purpose h2 {{ margin:0 0 4px; padding:0; border:0; color:var(--brand-dark); font-size:9pt;
      text-transform:uppercase; letter-spacing:.08em; }}
    .doc-purpose p {{ margin:0; color:#4f3b2b; font-size:9.5pt; }}
    .question-card {{ background:var(--surface); border:1px solid var(--line); border-left:4px solid #98a2b3;
      border-radius:8px; padding:12px 15px; margin:0 0 27px; }}
    .question-card h2 {{ margin:0 0 5px; padding:0; border:0; font-size:8pt; color:var(--muted);
      text-transform:uppercase; letter-spacing:.08em; }}
    .question-card p {{ margin:.15rem 0; font-size:9.5pt; }}
    .solution-card {{ background:#fff; border:1px solid #f5d4b2; border-left:4px solid var(--brand);
      border-radius:8px; padding:14px 16px; margin:0 0 27px; }}
    .solution-card h2 {{ margin:0 0 8px; padding:0; border:0; font-size:8pt; color:var(--brand-dark);
      text-transform:uppercase; letter-spacing:.08em; }}
    .doc-capturas {{ display:flex; flex-direction:column; gap:12px; margin:12px 0 0; }}
    .doc-captura {{ margin:0; break-inside:avoid; page-break-inside:avoid; }}
    .doc-captura img {{ max-width:100%; height:auto; border:1px solid var(--line); border-radius:8px; }}
    .doc-captura figcaption {{ margin-top:4px; color:var(--muted); font-size:8pt; }}
    .manual-title {{ display:flex; align-items:center; gap:10px; margin:0 0 16px; color:var(--ink);
      font-size:15pt; border-bottom:2px solid var(--ink); padding-bottom:8px; }}
    .manual-title span {{ display:grid; place-items:center; width:25px; height:25px; border-radius:6px;
      color:#fff; background:var(--brand); font-size:12pt; }}
    .manual-content h2 {{ color:var(--ink); font-size:15pt; line-height:1.25; margin:28px 0 11px;
      padding:0 0 7px; border-bottom:2px solid var(--brand); break-after:avoid; page-break-after:avoid; }}
    .manual-content h3 {{ color:var(--ink); font-size:12pt; line-height:1.3; margin:22px 0 9px;
      break-after:avoid; page-break-after:avoid; }}
    .manual-content h4 {{ color:#344054; font-size:10.5pt; margin:17px 0 7px;
      break-after:avoid; page-break-after:avoid; }}
    .numbered-heading {{ display:flex; align-items:center; gap:8px; }}
    .numbered-heading > span {{ display:inline-grid; place-items:center; min-width:25px; height:25px; padding:0 6px;
      border-radius:6px; background:var(--brand-soft); color:var(--brand-dark); font-size:8.5pt; font-weight:800; }}
    p {{ margin: 7px 0 10px; }}
    strong {{ color:var(--ink); font-weight:700; }}
    code {{ font-family:Consolas,"Courier New",monospace; font-size:.88em; color:#9a3412;
      background:#fff1e7; border:1px solid #fed7bd; border-radius:4px; padding:1px 4px; }}
    .section-rule {{ border:0; height:1px; background:var(--line); margin:24px 0; }}
    .manual-list {{ margin:8px 0 14px; padding-left:0; list-style:none; }}
    ul.manual-list li {{ position:relative; padding:3px 0 3px 23px; break-inside:avoid; page-break-inside:avoid; }}
    ul.manual-list li::before {{ content:""; position:absolute; left:4px; top:11px; width:7px; height:7px;
      border-radius:2px; background:var(--brand); transform:rotate(45deg); }}
    ol.manual-list {{ counter-reset:step; }}
    ol.manual-list li {{ counter-increment:step; position:relative; padding:5px 0 7px 35px;
      min-height:29px; break-inside:avoid; page-break-inside:avoid; }}
    ol.manual-list li::before {{ content:counter(step); position:absolute; left:0; top:2px; display:grid; place-items:center;
      width:25px; height:25px; border-radius:50%; background:var(--ink); color:#fff; font-size:8pt; font-weight:750; }}
    .callout {{ border-radius:8px; padding:10px 13px 10px 40px; margin:13px 0; position:relative;
      break-inside:avoid; page-break-inside:avoid; }}
    .callout::before {{ position:absolute; left:14px; top:10px; font-weight:800; }}
    .callout-warning {{ background:#fffaeb; border:1px solid #fedf89; color:#7a2e0e; }}
    .callout-warning::before {{ content:"!"; }}
    .callout-tip {{ background:#ecfdf3; border:1px solid #abefc6; color:#085d3a; }}
    .callout-tip::before {{ content:"✓"; }}
    .callout-info {{ background:#eff8ff; border:1px solid #b2ddff; color:#1849a9; }}
    .callout-info::before {{ content:"i"; }}
    .table-wrap {{ overflow-x:auto; margin:12px 0 18px; border:1px solid var(--line); border-radius:8px;
      break-inside:avoid; page-break-inside:avoid; }}
    table {{ width:100%; border-collapse:collapse; font-size:8.5pt; }}
    thead {{ display:table-header-group; }}
    th {{ background:#273248; color:#fff; text-align:left; padding:8px 10px; font-size:7.5pt;
      letter-spacing:.025em; }}
    td {{ padding:8px 10px; border-top:1px solid var(--line); vertical-align:top; }}
    tbody tr:nth-child(even) {{ background:#f8fafc; }}
    .sql-block-title {{ color:var(--ink); font-weight:750; font-size:10pt; margin:19px 0 5px;
      padding-left:10px; border-left:4px solid var(--brand); break-after:avoid; page-break-after:avoid; }}
    .sql-aviso {{ position:relative; font-size:8pt; color:#475467; background:#f2f4f7; border:1px solid #e4e7ec;
      border-bottom:0; border-radius:7px 7px 0 0; margin:8px 0 0; padding:7px 10px 7px 30px; }}
    .sql-aviso::before {{ content:"</>"; position:absolute; left:9px; color:var(--brand-dark); font-weight:800; }}
    pre.sql-spec {{ background:#172033; color:#e5e7eb; padding:13px 15px; overflow-x:auto; font-size:7.5pt;
      line-height:1.42; border-radius:0 0 7px 7px; margin:0 0 14px; white-space:pre-wrap; overflow-wrap:anywhere;
      font-family:Consolas,"Courier New",monospace; -webkit-user-select:all; user-select:all; }}
    pre.text-spec {{ background:#f4f4f4; border:1px solid var(--line); padding:11px 13px; border-radius:7px;
      font-size:8pt; white-space:pre-wrap; font-family:Consolas,monospace; }}
    footer {{ display:flex; justify-content:space-between; gap:20px; margin-top:30px; color:#7b8494;
      border-top:1px solid var(--line); padding-top:11px; font-size:7.5pt; }}
    @media print {{
      html, body {{ background:#fff; }}
      body {{ padding:0; }}
      .container {{ max-width:none; box-shadow:none; }}
      .page-content {{ padding:0; }}
      .top-accent {{ margin:0 0 8mm; }}
      .brand-head, .doc-purpose, .question-card, .meta-item, th, pre.sql-spec, .callout,
      .diagrama-incrustado, .sc-mock .win-top, .sc-mock .chip-tab,
      .numbered-heading > span, ul.manual-list li::before, ol.manual-list li::before {{
        -webkit-print-color-adjust:exact !important; print-color-adjust:exact !important;
      }}
      .brand-head, .title-block, .doc-meta, .doc-purpose, .question-card, footer {{
        break-inside:avoid; page-break-inside:avoid;
      }}
    }}
    @media (max-width:700px) {{
      body {{ padding:0; }}
      .page-content {{ padding:22px; }}
      .doc-meta {{ grid-template-columns:repeat(2,1fr); }}
      .doc-kind {{ display:none; }}
      h1 {{ font-size:20pt; }}
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="top-accent"></div>
    <div class="page-content">
      <div class="brand-head">
        <div class="brand-id">
          <img class="brand-mark" src="{_esc(logo_src)}" alt="IX Colombia SAS">
          <div>
            <div class="brand-name">IX COLOMBIA SAS</div>
            <div class="brand-area">{_esc(area)}</div>
          </div>
        </div>
        <div class="doc-kind">{_esc(kind)}</div>
      </div>
      <header class="title-block">
        <p class="eyebrow">{_esc(eyebrow)}</p>
        <h1>{_esc(meta.get('titulo'))}</h1>
      </header>
      <div class="doc-meta">
        <div class="meta-item"><span class="meta-label">{_esc(etiqueta_id)}</span><span class="meta-value">{_esc(meta.get('id'))}</span></div>
        <div class="meta-item"><span class="meta-label">Quién pregunta</span><span class="meta-value">{_esc(meta.get('solicitante') or '—')}</span></div>
        <div class="meta-item"><span class="meta-label">Cliente</span><span class="meta-value">{_esc(meta.get('cliente') or '—')}</span></div>
        <div class="meta-item"><span class="meta-label">Fecha</span><span class="meta-value">{_esc(hoy)}</span></div>
      </div>
      <section class="doc-purpose">
        <h2>{_esc(titulo_proposito)}</h2>
        <p>{proposito_html}</p>
      </section>
      <section class="question-card">
        <h2>Necesidad planteada</h2>
        {_parrafos(meta.get('preguntaInicial') or '')}
        {html_capturas(sid)}
      </section>
      {bloque_solucion}
      <h2 class="manual-title"><span>✓</span> {_esc(titulo_manual)}</h2>
      <main class="manual-content">
      {guia_html}
      {html_ilustraciones(sid)}
      {texto_respuesta_a_html(respuesta_resto if entrega else respuesta, incluir_sql=not entrega)}
      </main>
      <footer>
        <span>{_esc(pie)}</span>
        <span>Uso interno IX Colombia · {_esc(meta.get('id'))}</span>
      </footer>
    </div>
  </div>
</body>
</html>"""
    ts = datetime.now().isoformat(timespec="seconds")
    meta["documentoGenerado"] = ts
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    (carpeta_consulta(sid) / "respuesta.html").write_text(doc, encoding="utf-8")
    idx = _load_index()
    for c in idx.get("consultas", []):
        if c.get("id") == sid:
            c["documentoGenerado"] = ts
            break
    _save_index(idx)
    return doc, meta


def ruta_html(sid: str) -> Path:
    return carpeta_consulta(sid) / "respuesta.html"


def ruta_pdf(sid: str) -> Path:
    return carpeta_consulta(sid) / "respuesta.pdf"


def generar_pdf(sid: str) -> Path:
    meta = leer_meta(sid)
    generar_html_documento(sid, presentar=False)
    html_path = ruta_html(sid)
    import correo as mailer

    dest = ruta_pdf(sid)
    out = mailer._html_a_pdf(html_path=str(html_path), dest_pdf=str(dest))
    if not mailer._pdf_utilizable(out):
        detalle = (getattr(mailer, "_ULTIMO_ERROR_NAVEGADOR", None) or "").strip()
        raise RuntimeError(detalle or "No se pudo generar el PDF.")
    meta = leer_meta(sid)
    meta["pdfGenerado"] = datetime.now().isoformat(timespec="seconds")
    _write_json(carpeta_consulta(sid) / "meta.json", meta)
    idx = _load_index()
    for c in idx.get("consultas", []):
        if c.get("id") == sid:
            c["pdfGenerado"] = meta["pdfGenerado"]
            break
    _save_index(idx)
    return Path(out)


def panel_consulta(sid: str) -> dict:
    from cursor_bot import leer_estado_bot

    meta = leer_meta(sid)
    respuesta = meta.get("respuestaOficial") or ""
    return {
        "meta": meta,
        "mensajes": leer_chat(sid).get("mensajes", []),
        "bot": leer_estado_bot(sid),
        "respuestaPreviewHtml": texto_respuesta_a_html(respuesta) if respuesta.strip() else "",
        "propositoDocumento": resolver_proposito(meta)
        if respuesta.strip() or (meta.get("preguntaInicial") or "").strip()
        else "",
    }
