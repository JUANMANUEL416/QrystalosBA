#!/usr/bin/env python3
"""Índice de búsqueda de la base de conocimiento (conocimiento/_indice_busqueda.json).

Mapea SP, SP/METODO, tablas, pantallas, controles, procesos y términos a
{proceso, archivo, ruta} para que los agentes abran SOLO la ficha que necesitan.

Uso:
    python scripts/kb_indice.py            # regenera el índice
    python scripts/kb_indice.py --canonico # además completa _sp_canonico.json
Solo biblioteca estándar.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KB = ROOT / "conocimiento"
INDICE_BUSQUEDA = KB / "_indice_busqueda.json"
SP_CANONICO = KB / "_sp_canonico.json"
EXCLUIR = {"canales", "chats", "diccionario", "handoffs", "_plantillas", "_schema"}
_ESTADO_PESO = {"leido": 4, "documentado": 3, "parcial": 2, "listado": 1, "no_leido": 0}
_RE_SIGLA = re.compile(r"\b[A-Z][A-Z0-9_]{2,}\b")
_lock = threading.Lock()


def _leer(path: Path, defecto=None):
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return defecto


def _escribir(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, path)


def lista_sps(data) -> list:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        sps = data.get("sps") or data.get("procedimientos") or []
        return list(sps.values()) if isinstance(sps, dict) else list(sps)
    return []


def carpetas_proceso() -> list[str]:
    salida = []
    for d in sorted(KB.iterdir()):
        if d.is_dir() and d.name not in EXCLUIR and not d.name.startswith((".", "_")):
            if (d / "proceso.json").is_file() or (d / "sps.json").is_file():
                salida.append(d.name)
    return salida


class _Lineas:
    """Ubica la línea (1-based) de cada SP/METODO para que el agente lea con offset."""

    def __init__(self, path: Path):
        try:
            self.lineas = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            self.lineas = []
        self.pos = 0

    def buscar(self, campo: str, valor: str, desde: int | None = None) -> int:
        patron = re.compile(r'"%s"\s*:\s*"%s"' % (campo, re.escape(valor)))
        inicio = self.pos if desde is None else desde
        for i in range(inicio, len(self.lineas)):
            if patron.search(self.lineas[i]):
                if desde is None:
                    self.pos = i + 1
                return i + 1
        return 0


def _add(mapa: dict, clave: str, valor: dict) -> None:
    clave = (clave or "").strip()
    if clave:
        mapa.setdefault(clave, []).append(valor)


def _peso_sp(sp: dict) -> tuple:
    mets = [m for m in sp.get("metodos") or [] if isinstance(m, dict)]
    llenos = sum(1 for m in mets if m.get("valida") and m.get("errores"))
    return (_ESTADO_PESO.get(str(sp.get("estado")), 0), llenos, len(mets))


def generar_canonico(escribir: bool = True) -> dict:
    """SP en más de un proceso -> proceso canónico. Respeta lo ya escrito a mano."""
    actual = _leer(SP_CANONICO, {}) or {}
    mapa = dict(actual.get("sps") or {})
    indice = _leer(KB / "INDICE.json", {}) or {}
    prioridad = {p.get("carpeta") or p.get("id"): p.get("prioridad") or 99 for p in indice.get("procesos") or []}
    vistos: dict[str, list] = {}
    for pid in carpetas_proceso():
        for sp in lista_sps(_leer(KB / pid / "sps.json", [])):
            if isinstance(sp, dict) and sp.get("nombre"):
                vistos.setdefault(sp["nombre"].strip().upper(), []).append((pid, sp))
    for nombre, filas in vistos.items():
        if len(filas) < 2 or nombre in mapa:
            continue
        filas.sort(key=lambda f: (_peso_sp(f[1]), -(prioridad.get(f[0], 99) if isinstance(prioridad.get(f[0], 99), int) else 99), not f[0].startswith("configuracion")), reverse=True)
        mapa[nombre] = {"canonico": filas[0][0], "tambienEn": sorted(f[0] for f in filas[1:])}
    data = {
        "nota": "SP repetido en varios procesos. La ficha que manda es la del proceso canónico; los demás la referencian. Edite a mano si la elección no es correcta: la regeneración respeta lo escrito.",
        "actualizado": datetime.now().isoformat(timespec="seconds"),
        "sps": dict(sorted(mapa.items())),
    }
    if escribir:
        _escribir(SP_CANONICO, data)
    return data


def generar() -> dict:
    canon = (_leer(SP_CANONICO, {}) or {}).get("sps") or {}
    indice = _leer(KB / "INDICE.json", {}) or {}
    meta_indice = {(p.get("carpeta") or p.get("id")): p for p in indice.get("procesos") or []}
    procesos, sp_map, met_map, tabla_map, pant_map, ctrl_map, term_map = {}, {}, {}, {}, {}, {}, {}
    for pid in carpetas_proceso():
        proc = _leer(KB / pid / "proceso.json", {}) or {}
        meta = meta_indice.get(pid) or {}
        procesos[pid] = {
            "nombre": meta.get("nombre") or proc.get("nombre") or pid,
            "estado": meta.get("estado") or proc.get("estado") or "",
            "familia": meta.get("familia") or proc.get("familia") or "",
            "modulo": meta.get("modulo") or proc.get("modulo") or "",
            "proceso": f"conocimiento/{pid}/proceso.json" if (KB / pid / "proceso.json").is_file() else "",
            "sps": f"conocimiento/{pid}/sps.json" if (KB / pid / "sps.json").is_file() else "",
            "enIndice": bool(meta),
        }
        archivo_p = f"conocimiento/{pid}/proceso.json"
        for i, v in enumerate(proc.get("ventanas") or []):
            if not isinstance(v, dict):
                continue
            ref = {"proceso": pid, "archivo": archivo_p, "ruta": f"ventanas[{i}]"}
            for k in ("ruta", "path"):
                _add(pant_map, str(v.get(k) or "").lower(), ref)
            for vue in re.findall(r"[A-Za-z0-9_]+\.vue", str(v.get("vue") or "")):
                _add(pant_map, vue.lower(), ref)
        for ci, cap in enumerate(proc.get("capas") or []):
            if not isinstance(cap, dict):
                continue
            for gi, ctl in enumerate(cap.get("controles") or cap.get("gates") or []):
                if isinstance(ctl, dict) and ctl.get("id"):
                    _add(ctrl_map, f"{pid}/{ctl['id']}", {"proceso": pid, "archivo": archivo_p, "ruta": f"capas[{ci}].controles[{gi}]", "nombre": ctl.get("nombre") or ""})
        for i, paso in enumerate(proc.get("pasos") or []):
            if isinstance(paso, dict) and paso.get("id"):
                _add(ctrl_map, f"{pid}/{paso['id']}", {"proceso": pid, "archivo": archivo_p, "ruta": f"pasos[{i}]", "nombre": paso.get("nombre") or ""})
        texto = " ".join(str(x or "") for x in (procesos[pid]["nombre"], procesos[pid]["modulo"], meta.get("resumen"), proc.get("resumen")))
        for palabra in set(re.findall(r"[a-záéíóúñ]{5,}", procesos[pid]["nombre"].lower())) | set(_RE_SIGLA.findall(texto)):
            term_map.setdefault(palabra, set()).add(pid)

        archivo_s = f"conocimiento/{pid}/sps.json"
        lin = _Lineas(KB / pid / "sps.json")
        for si, sp in enumerate(lista_sps(_leer(KB / pid / "sps.json", []))):
            if not isinstance(sp, dict) or not sp.get("nombre"):
                continue
            nombre = sp["nombre"].strip().upper()
            c = canon.get(nombre)
            es_canon = (not c) or c.get("canonico") == pid
            l_sp = lin.buscar("nombre", sp["nombre"])
            _add(sp_map, nombre, {"proceso": pid, "archivo": archivo_s, "ruta": f"sps[{si}]", "linea": l_sp, "estado": sp.get("estado") or "", "canonico": es_canon})
            for t in sp.get("tablas") or []:
                if isinstance(t, str):
                    _add(tabla_map, t.strip().upper(), {"proceso": pid, "sp": nombre, "archivo": archivo_s, "ruta": f"sps[{si}]"})
            for mi, met in enumerate(sp.get("metodos") or []):
                if not isinstance(met, dict) or not met.get("id"):
                    continue
                ruta = f"sps[{si}].metodos[{mi}]"
                l_m = lin.buscar("id", str(met["id"]), desde=l_sp) if l_sp else 0
                _add(met_map, f"{nombre}/{str(met['id']).strip().upper()}", {"proceso": pid, "archivo": archivo_s, "ruta": ruta, "linea": l_m, "estado": met.get("estado") or "", "canonico": es_canon})
                for t in met.get("tablas") or []:
                    if isinstance(t, str):
                        _add(tabla_map, t.strip().upper(), {"proceso": pid, "sp": nombre, "metodo": met["id"], "archivo": archivo_s, "ruta": ruta})
    data = {
        "nota": "Generado por scripts/kb_indice.py. No editar a mano. Buscar aquí y abrir SOLO la ruta indicada (python scripts/kb_buscar.py CLAVE o GET /api/kb/buscar?q=CLAVE).",
        "generado": datetime.now().isoformat(timespec="seconds"),
        "totales": {},
        "procesos": procesos,
        "sp": sp_map,
        "metodo": met_map,
        "tabla": tabla_map,
        "pantalla": pant_map,
        "control": ctrl_map,
        "termino": {k: sorted(v) for k, v in term_map.items()},
    }
    data["totales"] = {k: len(data[k]) for k in ("procesos", "sp", "metodo", "tabla", "pantalla", "control", "termino")}
    return data


def _escribir_por_linea(path: Path, data: dict) -> None:
    """Una clave por línea: el agente hace grep '"SP/METODO"' y obtiene solo esa línea."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    dump = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":"))  # noqa: E731
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("{\n")
        claves = list(data)
        for n, k in enumerate(claves):
            v = data[k]
            fin = "," if n < len(claves) - 1 else ""
            if isinstance(v, dict) and k not in ("totales",):
                fh.write(f"{dump(k)}:{{\n")
                sub = sorted(v)
                for m, sk in enumerate(sub):
                    fh.write(f"{dump(sk)}:{dump(v[sk])}{',' if m < len(sub) - 1 else ''}\n")
                fh.write("}" + fin + "\n")
            else:
                fh.write(f"{dump(k)}:{dump(v)}{fin}\n")
        fh.write("}\n")
    os.replace(tmp, path)


def regenerar() -> dict:
    with _lock:
        data = generar()
        _escribir_por_linea(INDICE_BUSQUEDA, data)
        return data["totales"]


_pendiente = threading.Event()
_ultimo = [0.0]


def regenerar_en_segundo_plano(espera: float = 2.0) -> None:
    """Agrupa varias escrituras seguidas en una sola regeneración. Nunca lanza excepción."""
    if _pendiente.is_set():
        return
    _pendiente.set()

    def _correr():
        try:
            time.sleep(espera)
            _pendiente.clear()
            regenerar()
            _ultimo[0] = time.time()
        except Exception as exc:  # noqa: BLE001
            _pendiente.clear()
            print(f"[kb_indice] no se pudo regenerar: {exc}", file=sys.stderr)

    threading.Thread(target=_correr, daemon=True).start()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--canonico", action="store_true", help="Completar conocimiento/_sp_canonico.json")
    args = ap.parse_args()
    t0 = time.time()
    if args.canonico:
        print("SP canónicos:", len(generar_canonico()["sps"]))
    tot = regenerar()
    print(json.dumps(tot, ensure_ascii=False), f"{time.time() - t0:.2f}s", INDICE_BUSQUEDA)
    return 0


if __name__ == "__main__":
    sys.exit(main())
