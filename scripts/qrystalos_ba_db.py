#!/usr/bin/env python3
"""Shim: Qrystalos BA DB module. Full implementation follows rename; imports from legacy during transition."""
from __future__ import annotations

# Temporary bridge: prefer full module body if this file is replaced by push of complete content.
# Until then, expose API expected by callers.

import importlib.util
from pathlib import Path

_LEGACY = Path(__file__).with_name("quatec_db.py")

def _load_legacy():
    spec = importlib.util.spec_from_file_location("quatec_db", _LEGACY)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

_mod = _load_legacy()
# Re-export with new names
QrystalosBADB = getattr(_mod, "QrystalosBADB", None) or _mod.QuatecDB
get_db = _mod.get_db
QuatecDB = QrystalosBADB  # alias
