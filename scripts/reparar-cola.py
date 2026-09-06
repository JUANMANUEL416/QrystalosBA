# -*- coding: utf-8 -*-
"""Reparar cola: relee HTML de ixonline y corrige proyecto/módulo mal parseados."""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from qrystalos_ba_db import get_db  # noqa: E402

COLA_DIR = ROOT / "cola"
ID_RE = re.compile(r"\b(010\d{7})\b")
FECHA_RE = re.compile(r"\b(\d{1,2}/\d{1,2}/\d{4})\b")
RAMA_RE = re.compile(r"(?:feature|hotfix|bugfix|release)\s*/\s*\S+", re.I)
PRIO_RE = re.compile(r"\d\s*-\s*(?:Alta|Media|Baja)", re.I)
ESTADO_RE = re.compile(r"\b(INGRESADO|ASIGNADO|DEVUELTO|CERRADO|PENDIENTE)\b", re.I)


def slug_from_id(id_req: str) -> str:
    d = datetime.now()
    return f"{d:%Y%m%d}-{id_req}"


def parse_fecha_dmy(dmy: str) -> str:
    if not dmy:
        return ""
    parts = dmy.split("/")
    if len(parts) != 3:
        return ""
    d, m, y = parts
    return f"{y}-{m.zfill(2)}-{d.zfill(2)}"


def clean(t: str) -> str:
    return re.sub(r"\s+", " ", (t or "")).strip()


class _TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_data(self, data):
        if data and data.strip():
            self.parts.append(data)


def text_of(html: str) -> str:
    p = _TextExtractor()
    try:
        p.feed(html)
        p.close()
    except Exception:
        return clean(re.sub(r"<[^>]+>", " ", html))
    return clean(" ".join(p.parts))


def attr(tag_html: str, name: str) -> str:
    m = re.search(rf'{name}="([^"]*)"', tag_html, re.I)
    return m.group(1) if m else ""


def inner_class(block: str, cls: str) -> str:
    m = re.search(
        rf'class="[^"]*{re.escape(cls)}[^"]*"[^>]*>(.*?)</div>',
        block,
        re.I | re.S,
    )
    return text_of(m.group(1)) if m else ""


HORA_RE = re.compile(r"\d{1,2}:\d{2}\s*(?:AM|PM)", re.I)


def tds_text(tr: str) -> list[str]:
    return [text_of(x) for x in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.I | re.S)]


def parse_tr_aval(tr: str) -> dict | None:
    tds = [t.strip() for t in tds_text(tr)]
    if not tds or not ID_RE.fullmatch(tds[0]):
        return None
    if HORA_RE.search(" ".join(tds)):
        return None
    return {
        "idReq": tds[0],
        "fecha": tds[1] if len(tds) > 1 else "",
        "rama": tds[2] if len(tds) > 2 else "",
        "proyecto": tds[3] if len(tds) > 3 else "",
        "moduloNombre": tds[4] if len(tds) > 4 else "",
        "area": tds[5] if len(tds) > 5 else "",
        "asesor": "JOSE MANUEL JIMENEZ",
        "desarrollador": tds[6] if len(tds) > 6 else "",
        "soporteProyecto": "",
        "estado": tds[7] if len(tds) > 7 else "",
        "aval": tds[8] if len(tds) > 8 else "Sin aval",
        "prioridad": "",
    }


def parse_tr_hora(tr: str) -> dict | None:
    """Tabla secundaria de la misma página (idreq, rama, fecha, hora, …, proyecto)."""
    tds = [t.strip() for t in tds_text(tr)]
    id_idx = next((i for i, t in enumerate(tds) if ID_RE.fullmatch(t)), -1)
    if id_idx < 0:
        return None
    hora_idx = next((i for i, t in enumerate(tds) if HORA_RE.search(t)), -1)
    if hora_idx < 0:
        return None
    id_req = tds[id_idx]
    rama = tds[id_idx + 1] if id_idx + 1 < len(tds) else ""
    fecha = tds[id_idx + 2] if id_idx + 2 < len(tds) else ""
    estado = ""
    proyecto = ""
    desarrollador = tds[-1] if tds else ""
    for t in tds[hora_idx + 1 :]:
        if re.search(r"TERMINADO|ASIGNADO|INGRESADO|CERRADO|DEVUELTO|PENDIENTE", t, re.I):
            estado = t
            continue
        if HORA_RE.search(t) or ID_RE.fullmatch(t) or FECHA_RE.fullmatch(t):
            continue
        if t.lower() in {"sin", "sin aval"} or not t:
            continue
        if RAMA_RE.search(t):
            continue
        if len(t) >= 6 and not proyecto:
            proyecto = t
    return {
        "idReq": id_req,
        "fecha": fecha,
        "rama": rama,
        "proyecto": proyecto,
        "moduloNombre": "",
        "area": "",
        "asesor": "JOSE MANUEL JIMENEZ",
        "desarrollador": desarrollador,
        "soporteProyecto": "",
        "estado": estado,
        "aval": "Sin aval",
        "prioridad": "",
    }


def parse_tr(tr: str) -> dict | None:
    id_m = re.search(r'title="(010\d{7})"', tr)
    if not id_m:
        id_m = ID_RE.search(text_of(tr))
        if not id_m:
            return None
        id_req = id_m.group(1) if id_m.lastindex else id_m.group(0)
        if not re.fullmatch(r"010\d{7}", id_req):
            return None
    else:
        id_req = id_m.group(1)

    rama_m = re.search(r'rama-copy"[^>]*title="([^"]+)"', tr)
    if not rama_m:
        rama_m = re.search(r'class="[^"]*rama-copy[^"]*"[^>]*title="([^"]+)"', tr)
    rama = clean(rama_m.group(1)) if rama_m else ""
    if not rama:
        rm = RAMA_RE.search(text_of(tr))
        rama = clean(rm.group(0)) if rm else ""

    proyecto = ""
    det = re.search(r'class="[^"]*detalle-cell[^"]*".*?</td>', tr, re.I | re.S)
    if det:
        rest = tr[det.end() :]
        td = re.search(r"<td[^>]*>(.*?)</td>", rest, re.I | re.S)
        if td:
            proyecto = text_of(td.group(1))

    modulo = inner_class(tr, "gr-mod-cell__mod")
    area = inner_class(tr, "gr-mod-cell__ase")
    asesor = inner_class(tr, "gr-mod-cell__asesor")
    aval = inner_class(tr, "gr-mod-cell__aval") or "Sin aval"

    chips = [text_of(x) for x in re.findall(r'class="q-chip__content[^"]*"[^>]*>(.*?)</div>', tr, re.I | re.S)]
    chips = [c for c in chips if c]
    subido_m = re.search(
        r'chip-subido-por[\s\S]*?class="q-chip__content[^"]*"[^>]*>(.*?)</div>',
        tr,
        re.I,
    )
    subido = text_of(subido_m.group(1)) if subido_m else ""
    datos = [c for c in chips if c != subido]
    soporte = datos[0] if datos else ""
    desarrollador = datos[1] if len(datos) > 1 else (datos[0] if datos else "")

    plain = text_of(tr)
    fechas = FECHA_RE.findall(plain)
    fecha = fechas[0] if fechas else ""
    prio_m = PRIO_RE.search(plain)
    prioridad = prio_m.group(0) if prio_m else ""
    est_m = ESTADO_RE.search(plain)
    estado = est_m.group(1).upper() if est_m else ""

    if not modulo and not proyecto:
        return None
    if HORA_RE.search(proyecto or ""):
        return None

    return {
        "idReq": id_req,
        "fecha": fecha,
        "rama": rama,
        "proyecto": proyecto,
        "moduloNombre": modulo,
        "area": area,
        "asesor": asesor or "JOSE MANUEL JIMENEZ",
        "desarrollador": desarrollador,
        "soporteProyecto": soporte,
        "estado": estado,
        "aval": aval,
        "prioridad": prioridad,
    }


def split_trs(html: str) -> list[str]:
    return re.findall(r"<tr\b[^>]*>.*?</tr>", html, re.I | re.S)


def parse_html_file(path: Path) -> list[dict]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    rows = []
    seen = set()

    def add(row: dict | None) -> None:
        if not row or row["idReq"] in seen:
            return
        if HORA_RE.search(row.get("proyecto") or ""):
            return
        seen.add(row["idReq"])
        row["ordenPagina"] = len(rows)
        rows.append(row)

    for tr in split_trs(raw):
        if "gr-mod-cell" in tr or "copyable" in tr:
            add(parse_tr(tr))
        elif HORA_RE.search(tr):
            continue
        else:
            add(parse_tr_aval(tr))

    for tr in split_trs(raw):
        if HORA_RE.search(tr):
            add(parse_tr_hora(tr))

    return rows


def parsed_malo(p: dict | None) -> bool:
    if not p:
        return True
    mod = re.sub(r"\s+", "", (p.get("moduloNombre") or "")).lower()
    proy = str(p.get("proyecto") or "").strip()
    if mod in {"subjecthistory", "subject", "history", "more_vert", "sin"}:
        return True
    if HORA_RE.search(proy) or proy in {"0"} or re.fullmatch(r"\d+", proy):
        return True
    if not proy:
        return True
    if len(p.get("moduloNombre") or "") > 120:
        return True
    return False


def row_to_parsed(row: dict, file_name: str, id_caso: str | None = None) -> dict:
    return {
        "idReq": row["idReq"],
        "idCaso": id_caso or slug_from_id(row["idReq"]),
        "fecha": parse_fecha_dmy(row.get("fecha") or ""),
        "proyecto": row.get("proyecto") or "",
        "moduloNombre": row.get("moduloNombre") or "",
        "area": row.get("area") or "",
        "asesor": row.get("asesor") or "JOSE MANUEL JIMENEZ",
        "rama": row.get("rama") or "",
        "prioridad": row.get("prioridad") or "",
        "desarrollador": row.get("desarrollador") or "",
        "soporteProyecto": row.get("soporteProyecto") or "",
        "estado": row.get("estado") or "",
        "aval": row.get("aval") or "Sin aval",
        "archivoCola": file_name,
        "rutaCola": str(COLA_DIR / file_name),
        "filasEncontradas": 1,
        "esLista": False,
    }


def main() -> None:
    html_files = sorted(
        {p for p in COLA_DIR.iterdir() if p.suffix.lower() in {".htm", ".html"}}
    )
    by_req: dict[str, tuple[str, dict]] = {}
    for path in html_files:
        rows = parse_html_file(path)
        print(f"{path.name}: {len(rows)} filas")
        for row in rows:
            prev = by_req.get(row["idReq"])
            if prev and prev[1].get("moduloNombre") and not row.get("moduloNombre"):
                continue
            by_req[row["idReq"]] = (path.name, row)

    db = get_db()
    cola = db.get_cola()
    print(f"Cola actual: {len(cola)} items")

    corregidos = []
    ya_ok = []
    sin_html = []

    for i, item in enumerate(cola):
        p = item.get("parsed") or {}
        req = item.get("idReqSeleccionado") or p.get("idReq") or item.get("id")
        if not req or req not in by_req:
            if parsed_malo(p):
                sin_html.append(req or "?")
            continue
        file_name, row = by_req[req]
        nuevo = row_to_parsed(row, file_name, p.get("idCaso"))
        if not parsed_malo(p) and p.get("proyecto") == nuevo["proyecto"] and p.get("moduloNombre") == nuevo["moduloNombre"]:
            ya_ok.append(req)
            continue
        item = dict(item)
        item["parsed"] = nuevo
        item["idReqSeleccionado"] = req
        item["archivoCola"] = file_name
        item["rutaCola"] = str(COLA_DIR / file_name)
        item["ordenPagina"] = row.get("ordenPagina", item.get("ordenPagina"))
        filas_src = [r for fn, r in ((by_req[k][0], by_req[k][1]) for k in by_req) if fn == file_name]
        # keep parseResult filas from this file
        filas_file = [by_req[k][1] for k in by_req if by_req[k][0] == file_name]
        filas_file.sort(key=lambda r: r.get("ordenPagina") or 0)
        item["parseResult"] = {
            "esLista": len(filas_file) > 1,
            "totalFilas": len(filas_file),
            "filas": filas_file,
        }
        cola[i] = item
        corregidos.append(f"{req} → {nuevo['proyecto']} | {nuevo['moduloNombre'][:50]}")

    db.save_cola(cola)
    print(f"Corregidos: {len(corregidos)}")
    for line in corregidos:
        print(" ", line.encode("ascii", "replace").decode("ascii"))
    print(f"Ya estaban bien: {len(ya_ok)}")
    if sin_html:
        print(f"Malos sin HTML coincidente: {sin_html}")


if __name__ == "__main__":
    main()
