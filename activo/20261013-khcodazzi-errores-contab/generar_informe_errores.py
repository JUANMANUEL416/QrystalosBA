"""Wrapper local del caso KHCODAZZI → scripts/informe_errores_contab.py"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from informe_errores_contab import generar_informe  # noqa: E402

CASO = Path(__file__).parent
OUT = CASO / "informe-errores-contables.html"


def main() -> None:
    html_doc, meta = generar_informe(
        "servidorHcodazzi",
        "KHCODAZZI",
        institucion="Institución Codazzi",
        logo_href="../../app/assets/logo-ixcolombia.svg",
    )
    OUT.write_text(html_doc, encoding="utf-8")
    (CASO / "informe-meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(OUT)


if __name__ == "__main__":
    main()
