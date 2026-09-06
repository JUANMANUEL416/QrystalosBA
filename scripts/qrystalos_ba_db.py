#!/usr/bin/env python3
"""Qrystalos BA DB module (assembled from base64 payload parts)."""
from __future__ import annotations

import base64
from pathlib import Path

_parts_dir = Path(__file__).resolve().parent / "_payloads"
_chunks = sorted(_parts_dir.glob("qrystalos_ba_db.b64.*"))
if not _chunks:
    raise ImportError("Missing scripts/_payloads/qrystalos_ba_db.b64.* payloads")
_src = base64.b64decode("".join(p.read_text(encoding="ascii").split()).encode("ascii"))
exec(compile(_src, str(Path(__file__).resolve()), "exec"), globals())
