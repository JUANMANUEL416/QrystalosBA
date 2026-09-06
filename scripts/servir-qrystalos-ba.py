#!/usr/bin/env python3
"""Shim: Qrystalos BA server entrypoint (renamed from servir-quatec.py)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

_LEGACY = Path(__file__).with_name("servir-quatec.py")

def _load():
    spec = importlib.util.spec_from_file_location("servir_quatec", _LEGACY)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

if __name__ == "__main__":
    _load()  # module runs server on import/main
    # If legacy exposes main:
    mod = _load()
    main = getattr(mod, "main", None)
    if callable(main):
        main()
