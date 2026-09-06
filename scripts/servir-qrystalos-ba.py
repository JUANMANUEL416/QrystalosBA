#!/usr/bin/env python3
"""Qrystalos BA local server — entry renamed from servir-quatec.py."""
from __future__ import annotations

import runpy
from pathlib import Path

runpy.run_path(str(Path(__file__).with_name("servir-quatec.py")), run_name="__main__")
