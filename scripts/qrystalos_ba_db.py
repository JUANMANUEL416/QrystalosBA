#!/usr/bin/env python3
"""Mini base de datos SQLite — Qrystalos BA (casos, chat, histórico, cola)."""
from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
DB_PATH = os.path.join(DATA_DIR, "qrystalos_ba.db")

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS casos (
  id_caso TEXT PRIMARY KEY,
  id_req TEXT,
  fase INTEGER DEFAULT 1,
  fase1_cerrada INTEGER DEFAULT 0,
  activado_en TEXT,
  cerrada_en TEXT,
  solicitud_json TEXT NOT NULL,
  instruccion_md TEXT,
  created_at TEXT DEFAULT (datetime('now','localtime')),
  updated_at TEXT DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS chat_mensajes (
  id TEXT PRIMARY KEY,
  id_caso TEXT NOT NULL,
  autor TEXT NOT NULL,
  texto TEXT NOT NULL,
  fecha TEXT NOT NULL,
  FOREIGN KEY (id_caso) REFERENCES casos(id_caso) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chat_caso_fecha ON chat_mensajes(id_caso, fecha);

CREATE TABLE IF NOT EXISTS historico (
  id_caso TEXT PRIMARY KEY,
  id_req TEXT,
  proyecto TEXT,
  modulo TEXT,
  fecha TEXT,
  estado TEXT,
  dictamen_path TEXT,
  aprobado_path TEXT,
  archivo_cola TEXT,
  notas TEXT,
  actualizado TEXT
);

CREATE TABLE IF NOT EXISTS cola_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_req TEXT NOT NULL UNIQUE,
  id_caso TEXT,
  archivo_cola TEXT NOT NULL,
  ruta_cola TEXT,
  estado TEXT DEFAULT 'pendiente',
  orden_pagina INTEGER,
  fecha_cola TEXT,
  item_json TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now','localtime')),
  updated_at TEXT DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS borradores (
  id_caso TEXT PRIMARY KEY,
  datos_json TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now','localtime'))
);
"""


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


_RANK_ESTADO = {
    "pendiente": 0,
    "en_analisis": 1,
    "dictamen": 2,
    "aprobado": 3,
    "enviado": 4,
}


def _mejor_estado(a: str | None, b: str | None) -> str:
    ra = _RANK_ESTADO.get(a or "", 0)
    rb = _RANK_ESTADO.get(b or "", 0)
    if rb >= ra:
        return b or a or "pendiente"
    return a or b or "pendiente"


def _read_json(path: str, default: Any = None) -> Any:
    if not os.path.isfile(path):
        return default if default is not None else {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _write_json(path: str, data: Any) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


class QrystalosBADB:
    def __init__(self, root: str | None = None):
        self.root = root or ROOT
        self.activo = os.path.join(self.root, "activo")
        self.historico = os.path.join(self.root, "historico")
        self.dictamenes = os.path.join(self.root, "dictamenes")
        self.aprobados = os.path.join(self.root, "aprobados")
        self.db_path = os.path.join(self.root, "data", "qrystalos_ba.db")
        self._migrated = False

    def connect(self) -> sqlite3.Connection:
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = sqlite3.connect(self.db_path, check_same_thread=False, timeout=15)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=15000")
        return conn

    def init(self) -> None:
        with self.connect() as conn:
            conn.executescript(SCHEMA)
            conn.commit()
        if not self._migrated:
            self.migrate_from_disk()
            self.migrate_from_quatec()
            self._migrated = True

    def migrate_from_disk(self) -> None:
        if os.path.isdir(self.activo):
            for name in os.listdir(self.activo):
                caso_dir = os.path.join(self.activo, name)
                if not os.path.isdir(caso_dir):
                    continue
                sol_path = os.path.join(caso_dir, "solicitud.json")
                if os.path.isfile(sol_path):
                    solicitud = _read_json(sol_path, {})
                    id_caso = (solicitud.get("identificacion") or {}).get("idCaso") or name
                    estado = _read_json(os.path.join(caso_dir, "estado.json"), {})
                    instr_path = os.path.join(caso_dir, "INSTRUCCION-AGENTE.md")
                    instruccion = ""
                    if os.path.isfile(instr_path):
                        with open(instr_path, encoding="utf-8") as fh:
                            instruccion = fh.read()
                    self._upsert_caso_row(id_caso, solicitud, estado, instruccion)

                chat = _read_json(os.path.join(caso_dir, "chat.json"), {"mensajes": []})
                id_caso = name
                if chat.get("mensajes"):
                    self.set_chat_messages(id_caso, chat["mensajes"], sync_disk=False)

        registro = _read_json(os.path.join(self.historico, "registro.json"), [])
        if registro:
            self.save_historico(registro)

    def _rewrite_quatec_paths(self, value: Any) -> Any:
        old = "Qrys.Quatec"
        new = "QrystalosBA"
        if isinstance(value, str):
            return value.replace(old, new).replace("qrys.quatec", "qrystalosba")
        if isinstance(value, list):
            return [self._rewrite_quatec_paths(v) for v in value]
        if isinstance(value, dict):
            return {k: self._rewrite_quatec_paths(v) for k, v in value.items()}
        return value

    def migrate_from_quatec(self) -> None:
        """Copia cola y borradores desde data/quatec.db si la base nueva quedó vacía."""
        old_path = os.path.join(self.root, "data", "quatec.db")
        if not os.path.isfile(old_path):
            return
        if os.path.abspath(old_path) == os.path.abspath(self.db_path):
            return
        with self.connect() as conn:
            cola_n = conn.execute("SELECT COUNT(*) FROM cola_items").fetchone()[0]
            borr_n = conn.execute("SELECT COUNT(*) FROM borradores").fetchone()[0]
        if cola_n and borr_n:
            return
        try:
            old = sqlite3.connect(f"file:{old_path}?mode=ro", uri=True, timeout=10)
            old.row_factory = sqlite3.Row
        except sqlite3.Error:
            return
        try:
            if not cola_n:
                items = []
                for row in old.execute("SELECT item_json FROM cola_items"):
                    try:
                        items.append(self._rewrite_quatec_paths(json.loads(row["item_json"])))
                    except (TypeError, json.JSONDecodeError):
                        continue
                if items:
                    self.save_cola(items)
            if not borr_n:
                for row in old.execute("SELECT id_caso, datos_json FROM borradores"):
                    try:
                        data = self._rewrite_quatec_paths(json.loads(row["datos_json"]))
                    except (TypeError, json.JSONDecodeError):
                        continue
                    self.save_borrador(row["id_caso"], data)
        finally:
            old.close()

    def _upsert_caso_row(
        self,
        id_caso: str,
        solicitud: dict,
        estado: dict,
        instruccion: str = "",
    ) -> None:
        ident = solicitud.get("identificacion") or {}
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO casos (id_caso, id_req, fase, fase1_cerrada, activado_en, cerrada_en,
                                   solicitud_json, instruccion_md, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id_caso) DO UPDATE SET
                  id_req=excluded.id_req,
                  fase=excluded.fase,
                  fase1_cerrada=excluded.fase1_cerrada,
                  activado_en=excluded.activado_en,
                  cerrada_en=excluded.cerrada_en,
                  solicitud_json=excluded.solicitud_json,
                  instruccion_md=COALESCE(NULLIF(excluded.instruccion_md,''), casos.instruccion_md),
                  updated_at=excluded.updated_at
                """,
                (
                    id_caso,
                    ident.get("idReq") or estado.get("idReq"),
                    int(estado.get("fase") or 1),
                    1 if estado.get("fase1Cerrada") else 0,
                    estado.get("activadoEn"),
                    estado.get("cerradaEn"),
                    json.dumps(solicitud, ensure_ascii=False),
                    instruccion,
                    _now(),
                ),
            )
            conn.commit()

    def sync_caso_to_disk(self, id_caso: str) -> None:
        caso_dir = os.path.join(self.activo, id_caso)
        os.makedirs(caso_dir, exist_ok=True)

        with self.connect() as conn:
            row = conn.execute("SELECT * FROM casos WHERE id_caso=?", (id_caso,)).fetchone()
            if not row:
                return
            solicitud = json.loads(row["solicitud_json"])
            _write_json(os.path.join(caso_dir, "solicitud.json"), solicitud)

            prev_est = _read_json(os.path.join(caso_dir, "estado.json"), {})
            estado = {
                "fase": row["fase"],
                "fase1Cerrada": bool(row["fase1_cerrada"]),
                "activadoEn": row["activado_en"],
                "cerradaEn": row["cerrada_en"],
                "idCaso": id_caso,
                "idReq": row["id_req"],
            }
            if prev_est.get("enmiendaAbierta") and not row["fase1_cerrada"]:
                estado["enmiendaAbierta"] = True
                if prev_est.get("reabiertoEn"):
                    estado["reabiertoEn"] = prev_est["reabiertoEn"]
                if prev_est.get("motivoReapertura"):
                    estado["motivoReapertura"] = prev_est["motivoReapertura"]
            _write_json(os.path.join(caso_dir, "estado.json"), estado)

            if row["instruccion_md"]:
                with open(os.path.join(caso_dir, "INSTRUCCION-AGENTE.md"), "w", encoding="utf-8") as fh:
                    fh.write(row["instruccion_md"])

        chat = self.get_chat(id_caso, sync_disk=False)
        _write_json(os.path.join(caso_dir, "chat.json"), chat)

    def guardar_solicitud(self, id_caso: str, solicitud: dict) -> None:
        estado = self.get_estado(id_caso)
        if not estado.get("idCaso"):
            estado["idCaso"] = id_caso
        self._upsert_caso_row(id_caso, solicitud, estado, "")
        self.sync_caso_to_disk(id_caso)

    def activar_caso(self, solicitud: dict, instruccion: str) -> dict:
        id_caso = (solicitud.get("identificacion") or {}).get("idCaso", "").strip()
        if not id_caso:
            raise ValueError("Falta idCaso")

        prev = _read_json(os.path.join(self.activo, id_caso, "estado.json"), {})
        ya_cerrado = (
            bool(prev.get("fase1Cerrada")) or os.path.isdir(os.path.join(self.aprobados, id_caso))
        ) and not prev.get("enmiendaAbierta")
        if ya_cerrado:
            estado = {
                "fase": 2,
                "fase1Cerrada": True,
                "activadoEn": prev.get("activadoEn") or _now(),
                "cerradaEn": prev.get("cerradaEn") or _now(),
                "idCaso": id_caso,
                "idReq": (solicitud.get("identificacion") or {}).get("idReq") or prev.get("idReq"),
            }
        else:
            estado = {
                "fase": 1,
                "fase1Cerrada": False,
                "activadoEn": _now(),
                "idCaso": id_caso,
                "idReq": (solicitud.get("identificacion") or {}).get("idReq"),
            }
        self._upsert_caso_row(id_caso, solicitud, estado, instruccion)

        existing = self.get_chat(id_caso, sync_disk=False)
        if not existing.get("mensajes"):
            self.set_chat_messages(
                id_caso,
                [
                    {
                        "id": "sys1",
                        "autor": "sistema",
                        "texto": (
                            "Fase 1 activada. Escriba solo en este Chat; no copie el texto a Cursor. "
                            "El agente lee activo/, Qrystalos2, documentación y sql/, y responde aquí en verde."
                        ),
                        "fecha": _now(),
                    }
                ],
                sync_disk=True,
            )
        else:
            self.sync_caso_to_disk(id_caso)

        self.refresh_historico_for_caso(id_caso)
        return {"idCaso": id_caso, "estado": estado}

    def sync_chat_from_disk(self, id_caso: str) -> None:
        path = os.path.join(self.activo, id_caso, "chat.json")
        if not os.path.isfile(path):
            return
        data = _read_json(path, {"mensajes": []})
        disk_msgs = data.get("mensajes") or []
        if not disk_msgs:
            return

        with self.connect() as conn:
            rows = conn.execute(
                "SELECT id, autor, texto, fecha FROM chat_mensajes WHERE id_caso=?",
                (id_caso,),
            ).fetchall()
        db_msgs = [dict(r) for r in rows]
        by_id = {m["id"]: m for m in db_msgs}
        for m in disk_msgs:
            mid = m.get("id")
            if mid:
                by_id[mid] = m
        merged = sorted(by_id.values(), key=lambda m: (m.get("fecha") or "", m.get("id") or ""))
        disk_ids = {m.get("id") for m in disk_msgs if m.get("id")}
        db_ids = {m.get("id") for m in db_msgs}
        if not disk_ids.issubset(db_ids):
            self.set_chat_messages(id_caso, merged, sync_disk=False)

    def get_chat(self, id_caso: str, sync_disk: bool = True) -> dict:
        if sync_disk:
            self.sync_chat_from_disk(id_caso)
        with self.connect() as conn:
            rows = conn.execute(
                "SELECT id, autor, texto, fecha FROM chat_mensajes WHERE id_caso=? ORDER BY fecha, id",
                (id_caso,),
            ).fetchall()
        return {"mensajes": [dict(r) for r in rows]}

    def append_chat(self, id_caso: str, msg: dict) -> dict:
        with self.connect() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO chat_mensajes (id, id_caso, autor, texto, fecha) VALUES (?, ?, ?, ?, ?)",
                (msg["id"], id_caso, msg["autor"], msg["texto"], msg["fecha"]),
            )
            conn.commit()
        self.sync_caso_to_disk(id_caso)
        return msg

    def set_chat_messages(self, id_caso: str, mensajes: list, sync_disk: bool = True) -> None:
        with self.connect() as conn:
            conn.execute("DELETE FROM chat_mensajes WHERE id_caso=?", (id_caso,))
            for m in mensajes:
                conn.execute(
                    "INSERT OR IGNORE INTO chat_mensajes (id, id_caso, autor, texto, fecha) VALUES (?, ?, ?, ?, ?)",
                    (
                        m.get("id") or "",
                        id_caso,
                        m.get("autor", "sistema"),
                        m.get("texto") or "",
                        m.get("fecha") or m.get("en") or _now(),
                    ),
                )
            conn.commit()
        if sync_disk:
            self.sync_caso_to_disk(id_caso)

    def get_estado(self, id_caso: str) -> dict:
        disk = _read_json(os.path.join(self.activo, id_caso, "estado.json"), {})
        with self.connect() as conn:
            row = conn.execute("SELECT * FROM casos WHERE id_caso=?", (id_caso,)).fetchone()
        if row:
            est = {
                "fase": row["fase"],
                "fase1Cerrada": bool(row["fase1_cerrada"]),
                "activadoEn": row["activado_en"],
                "cerradaEn": row["cerrada_en"],
                "idCaso": id_caso,
                "idReq": row["id_req"],
            }
            if disk.get("enmiendaAbierta") and not est["fase1Cerrada"]:
                est["enmiendaAbierta"] = True
                est["motivoReapertura"] = disk.get("motivoReapertura") or ""
            return est
        return disk or {"fase": 1, "fase1Cerrada": False}

    def reabrir_enmienda(self, id_caso: str, motivo: str = "") -> dict:
        """Reabre Fase 1 para completar algo (p. ej. contabilidad) sin borrar el dictamen aprobado."""
        solicitud = self.get_solicitud(id_caso)
        prev = _read_json(os.path.join(self.activo, id_caso, "estado.json"), {})
        estado = {
            "fase": 1,
            "fase1Cerrada": False,
            "activadoEn": prev.get("activadoEn") or _now(),
            "cerradaEn": None,
            "cerradaEnAnterior": prev.get("cerradaEn") or prev.get("cerradaEnAnterior"),
            "idCaso": id_caso,
            "idReq": (solicitud.get("identificacion") or {}).get("idReq") or prev.get("idReq"),
            "enmiendaAbierta": True,
            "reabiertoEn": _now(),
            "motivoReapertura": motivo or "enmienda",
        }
        self._upsert_caso_row(id_caso, solicitud, estado, "")
        _write_json(os.path.join(self.activo, id_caso, "estado.json"), estado)
        return estado

    def cerrar_fase1(self, id_caso: str) -> dict:
        estado = self.get_estado(id_caso)
        estado.update({"fase": 2, "fase1Cerrada": True, "cerradaEn": _now(), "enmiendaAbierta": False})
        with self.connect() as conn:
            conn.execute(
                """
                UPDATE casos SET fase=2, fase1_cerrada=1, cerrada_en=?, updated_at=? WHERE id_caso=?
                """,
                (estado["cerradaEn"], _now(), id_caso),
            )
            conn.commit()
        self.append_chat(
            id_caso,
            {
                "id": "fase1cerrada",
                "autor": "sistema",
                "texto": "Fase 1 cerrada. Dictamen copiado a aprobados/. SQL movido a sql_refe/{ID-REQ}/.",
                "fecha": _now(),
            },
        )
        self.refresh_historico_for_caso(id_caso)
        return estado

    def get_solicitud(self, id_caso: str) -> dict:
        with self.connect() as conn:
            row = conn.execute("SELECT solicitud_json FROM casos WHERE id_caso=?", (id_caso,)).fetchone()
        if row:
            return json.loads(row["solicitud_json"])
        return _read_json(os.path.join(self.activo, id_caso, "solicitud.json"), {})

    def _historico_estado(self, id_caso: str, caso_row, dictamen_exists: bool, aprobado_exists: bool) -> str:
        id_req = ""
        if caso_row:
            try:
                id_req = caso_row["id_req"] or ""
            except (KeyError, IndexError, TypeError):
                id_req = ""
        if self.caso_tiene_correo(id_caso, id_req).get("enviado"):
            return "enviado"
        if aprobado_exists or (caso_row and caso_row["fase1_cerrada"]):
            return "aprobado"
        if dictamen_exists:
            return "dictamen"
        if caso_row and caso_row["activado_en"]:
            return "en_analisis"
        return "pendiente"

    def caso_tiene_correo(self, id_caso: str, id_req: str = "") -> dict:
        """Solo evidencia real de envío (carpeta correos/ o registro). No el check del formulario."""
        meta = {"enviado": False, "fecha": ""}
        registro = _read_json(os.path.join(ROOT, "correos", "registro.json"), [])
        if isinstance(registro, list):
            for row in registro:
                if row.get("idCaso") == id_caso or (id_req and row.get("idReq") == id_req):
                    meta["enviado"] = True
                    meta["fecha"] = (row.get("fecha") or "")[:10]
                    return meta
        carpeta = os.path.join(ROOT, "correos", id_caso)
        if os.path.isdir(carpeta):
            meta["enviado"] = True
            return meta
        return meta

    def refresh_historico_for_caso(self, id_caso: str) -> None:
        solicitud = self.get_solicitud(id_caso)
        ident = solicitud.get("identificacion") or {}
        proyecto = solicitud.get("proyecto") or {}
        cola = solicitud.get("cola") or {}
        with self.connect() as conn:
            caso_row = conn.execute("SELECT * FROM casos WHERE id_caso=?", (id_caso,)).fetchone()
        dictamen_exists = os.path.isfile(os.path.join(self.dictamenes, f"{id_caso}.html"))
        aprobado_exists = os.path.isdir(os.path.join(self.aprobados, id_caso))
        with self.connect() as conn:
            prev = conn.execute("SELECT notas FROM historico WHERE id_caso=?", (id_caso,)).fetchone()
            notas = prev["notas"] if prev else ""
            conn.execute(
                """
                INSERT INTO historico (id_caso, id_req, proyecto, modulo, fecha, estado,
                                       dictamen_path, aprobado_path, archivo_cola, notas, actualizado)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id_caso) DO UPDATE SET
                  id_req=excluded.id_req, proyecto=excluded.proyecto, modulo=excluded.modulo,
                  fecha=excluded.fecha, estado=excluded.estado, dictamen_path=excluded.dictamen_path,
                  aprobado_path=excluded.aprobado_path, archivo_cola=excluded.archivo_cola,
                  notas=COALESCE(NULLIF(historico.notas,''), excluded.notas),
                  actualizado=excluded.actualizado
                """,
                (
                    id_caso,
                    ident.get("idReq", ""),
                    proyecto.get("nombre", ""),
                    proyecto.get("modulo", ""),
                    ident.get("fecha", ""),
                    self._historico_estado(id_caso, caso_row, dictamen_exists, aprobado_exists),
                    f"dictamenes/{id_caso}.html",
                    f"aprobados/{id_caso}/",
                    cola.get("archivoCola", ""),
                    notas,
                    _now(),
                ),
            )
            conn.commit()

    def build_historico(self) -> list[dict]:
        with self.connect() as conn:
            rows = conn.execute(
                "SELECT * FROM historico ORDER BY actualizado DESC, fecha DESC"
            ).fetchall()

        by_id = {r["id_caso"]: self._row_to_historico(r) for r in rows}

        if os.path.isdir(self.dictamenes):
            for fname in os.listdir(self.dictamenes):
                if not fname.lower().endswith(".html"):
                    continue
                id_caso = fname[:-5]
                if id_caso in by_id:
                    continue
                by_id[id_caso] = {
                    "idCaso": id_caso,
                    "idReq": "",
                    "proyecto": "",
                    "modulo": "",
                    "fecha": "",
                    "estado": "dictamen",
                    "dictamenPath": f"dictamenes/{fname}",
                    "aprobadoPath": f"aprobados/{id_caso}/",
                    "archivoCola": "",
                    "notas": "",
                    "actualizado": _now(),
                }

        items = sorted(
            by_id.values(),
            key=lambda x: x.get("actualizado") or x.get("fecha") or "",
            reverse=True,
        )
        self.save_historico(items)
        return items

    def _row_to_historico(self, row: sqlite3.Row) -> dict:
        id_caso = row["id_caso"]
        mail = self.caso_tiene_correo(id_caso, row["id_req"] or "")
        estado = row["estado"] or "pendiente"
        if mail["enviado"]:
            estado = "enviado"
        elif os.path.isdir(os.path.join(self.aprobados, id_caso)) and estado in ("pendiente", "en_analisis", "dictamen"):
            estado = "aprobado"
        return {
            "idCaso": id_caso,
            "idReq": row["id_req"] or "",
            "proyecto": row["proyecto"] or "",
            "modulo": row["modulo"] or "",
            "fecha": row["fecha"] or "",
            "estado": estado,
            "dictamenPath": row["dictamen_path"] or "",
            "aprobadoPath": row["aprobado_path"] or "",
            "archivoCola": row["archivo_cola"] or "",
            "notas": row["notas"] or "",
            "actualizado": row["actualizado"] or "",
            "correoEnviado": mail["enviado"],
            "fechaEnvioCorreo": mail["fecha"],
        }

    def save_historico(self, items: list[dict]) -> None:
        prev_estado = {}
        with self.connect() as conn:
            for r in conn.execute("SELECT id_caso, estado FROM historico").fetchall():
                prev_estado[r["id_caso"]] = r["estado"]
        for h in items:
            actual = _mejor_estado(prev_estado.get(h.get("idCaso")), h.get("estado"))
            if h.get("correoEnviado"):
                actual = _mejor_estado(actual, "enviado")
            h["estado"] = actual
        with self.connect() as conn:
            for h in items:
                conn.execute(
                    """
                    INSERT INTO historico (id_caso, id_req, proyecto, modulo, fecha, estado,
                                           dictamen_path, aprobado_path, archivo_cola, notas, actualizado)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id_caso) DO UPDATE SET
                      id_req=excluded.id_req, proyecto=excluded.proyecto, modulo=excluded.modulo,
                      fecha=excluded.fecha, estado=excluded.estado, dictamen_path=excluded.dictamen_path,
                      aprobado_path=excluded.aprobado_path, archivo_cola=excluded.archivo_cola,
                      notas=COALESCE(NULLIF(excluded.notas,''), historico.notas),
                      actualizado=excluded.actualizado
                    """,
                    (
                        h.get("idCaso"),
                        h.get("idReq", ""),
                        h.get("proyecto", ""),
                        h.get("modulo", ""),
                        h.get("fecha", ""),
                        h.get("estado", "pendiente"),
                        h.get("dictamenPath", ""),
                        h.get("aprobadoPath", ""),
                        h.get("archivoCola", ""),
                        h.get("notas", ""),
                        h.get("actualizado") or _now(),
                    ),
                )
            conn.commit()
        _write_json(os.path.join(self.historico, "registro.json"), items)

    def reconciliar_cerrados(self, forzar_enviados=None) -> dict:
        """Reabre no: si hay dictamen aprobado o correo, deja el caso cerrado."""
        forzar = set(forzar_enviados or [])
        tocados = []
        if os.path.isdir(self.activo):
            for name in os.listdir(self.activo):
                caso_dir = os.path.join(self.activo, name)
                if not os.path.isdir(caso_dir) or name.startswith("."):
                    continue
                sol = _read_json(os.path.join(caso_dir, "solicitud.json"), {})
                ident = sol.get("identificacion") or {}
                id_caso = ident.get("idCaso") or name
                id_req = ident.get("idReq") or ""
                est_prev = _read_json(os.path.join(caso_dir, "estado.json"), {})
                if est_prev.get("enmiendaAbierta"):
                    continue
                mail = self.caso_tiene_correo(id_caso, id_req)
                if id_req in forzar:
                    mail["enviado"] = True
                aprobado = os.path.isdir(os.path.join(self.aprobados, id_caso))
                if not (mail["enviado"] or aprobado or id_req in forzar):
                    continue
                est_path = os.path.join(caso_dir, "estado.json")
                est = _read_json(est_path, {})
                est.update({
                    "fase": 2,
                    "fase1Cerrada": True,
                    "idCaso": id_caso,
                    "idReq": id_req,
                    "cerradaEn": est.get("cerradaEn") or _now(),
                })
                _write_json(est_path, est)
                if mail["enviado"]:
                    sol.setdefault("correo", {})
                    sol["correo"]["enviado"] = True
                    if mail["fecha"]:
                        sol["correo"]["fechaEnvio"] = mail["fecha"]
                    _write_json(os.path.join(caso_dir, "solicitud.json"), sol)
                self._upsert_caso_row(id_caso, sol, est, "")
                self.refresh_historico_for_caso(id_caso)
                try:
                    import desarrolladores as devs

                    if mail["enviado"]:
                        devs.marcar_envio_caso(
                            id_caso,
                            correo_enviado=True,
                            fecha_envio=mail.get("fecha") or None,
                        )
                    nombre = (sol.get("personas") or {}).get("desarrollador") or ""
                    if nombre:
                        devs.upsert(
                            nombre,
                            caso={"idReq": id_req, "idCaso": id_caso, "fase1": "cerrada"},
                        )
                except Exception:
                    pass
                tocados.append(id_req or id_caso)
        cola = self.get_cola()
        cambiado = False
        for item in cola:
            req = item.get("idReqSeleccionado") or (item.get("parsed") or {}).get("idReq") or ""
            id_caso = (item.get("parsed") or {}).get("idCaso") or ""
            mail = self.caso_tiene_correo(id_caso, req)
            if req in forzar:
                mail["enviado"] = True
            if mail["enviado"]:
                item["estado"] = "enviado"
                cambiado = True
            elif os.path.isdir(os.path.join(self.aprobados, id_caso)) and item.get("estado") in (
                "pendiente", "en_analisis", "dictamen",
            ):
                item["estado"] = "aprobado"
                cambiado = True
        if cambiado:
            self.save_cola(cola)
        return {"ok": True, "tocados": tocados}

    def get_cola(self) -> list[dict]:
        with self.connect() as conn:
            rows = conn.execute(
                "SELECT item_json FROM cola_items ORDER BY orden_pagina, id_req"
            ).fetchall()
        return [json.loads(r["item_json"]) for r in rows]

    def save_cola(self, items: list[dict]) -> None:
        prev_estado = {}
        try:
            for old in self.get_cola():
                req = old.get("idReqSeleccionado") or (old.get("parsed") or {}).get("idReq")
                if req:
                    prev_estado[req] = old.get("estado")
        except Exception:
            pass
        for item in items:
            req = item.get("idReqSeleccionado") or (item.get("parsed") or {}).get("idReq") or item.get("idReq")
            if req:
                merged = _mejor_estado(prev_estado.get(req), item.get("estado"))
                if merged == "enviado":
                    id_caso = (item.get("parsed") or {}).get("idCaso") or item.get("idCaso") or ""
                    if not self.caso_tiene_correo(id_caso, req).get("enviado"):
                        merged = item.get("estado") or "pendiente"
                item["estado"] = merged
        with self.connect() as conn:
            conn.execute("DELETE FROM cola_items")
            for item in items:
                parsed = item.get("parsed") or {}
                id_req = item.get("idReqSeleccionado") or parsed.get("idReq") or item.get("idReq")
                if not id_req:
                    continue
                conn.execute(
                    """
                    INSERT INTO cola_items (id_req, id_caso, archivo_cola, ruta_cola, estado,
                                            orden_pagina, fecha_cola, item_json, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        id_req,
                        parsed.get("idCaso") or item.get("idCaso"),
                        item.get("archivoCola", ""),
                        item.get("rutaCola", ""),
                        item.get("estado", "pendiente"),
                        item.get("ordenPagina"),
                        item.get("fechaCola"),
                        json.dumps(item, ensure_ascii=False),
                        _now(),
                    ),
                )
            conn.commit()

    def upsert_cola_item(self, item: dict) -> None:
        items = self.get_cola()
        id_req = item.get("idReqSeleccionado") or (item.get("parsed") or {}).get("idReq")
        replaced = False
        for i, existing in enumerate(items):
            ex_req = existing.get("idReqSeleccionado") or (existing.get("parsed") or {}).get("idReq")
            if ex_req == id_req or existing.get("archivoCola") == item.get("archivoCola"):
                items[i] = item
                replaced = True
                break
        if not replaced:
            items.append(item)
        self.save_cola(items)

    def get_borrador(self, id_caso: str | None = None) -> dict | None:
        key = id_caso or "__ultimo__"
        with self.connect() as conn:
            row = conn.execute("SELECT datos_json FROM borradores WHERE id_caso=?", (key,)).fetchone()
        if row:
            return json.loads(row["datos_json"])
        return None

    def save_borrador(self, id_caso: str, data: dict) -> None:
        payload = json.dumps(data, ensure_ascii=False)
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO borradores (id_caso, datos_json, updated_at) VALUES (?, ?, ?)
                ON CONFLICT(id_caso) DO UPDATE SET datos_json=excluded.datos_json, updated_at=excluded.updated_at
                """,
                (id_caso or "__ultimo__", payload, _now()),
            )
            conn.commit()


_db: QrystalosBADB | None = None


def get_db() -> QrystalosBADB:
    global _db
    if _db is None:
        _db = QrystalosBADB()
        _db.init()
    return _db
