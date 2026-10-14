"""One-off: scan sql refs for USVGS vars (dev helper)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads(
    (ROOT / "conocimiento/flujo-compras-inv-cxp-caja/usvgs-inventario.json").read_text(encoding="utf-8-sig")
)
ids = {v["id"] for g in catalog["grupos"] for v in g["variables"]}
pat = re.compile(r"FNK_VALORVARIABLE\s*\(\s*['\"]([A-Z0-9_]+)['\"]")
refs = {i: [] for i in ids}
for sql in (ROOT / "sql").glob("*.sql"):
    found = set(pat.findall(sql.read_text(encoding="utf-8", errors="replace")))
    for vid in found:
        if vid in refs:
            refs[vid].append(sql.name)
out = ROOT / "conocimiento/flujo-compras-inv-cxp-caja/usvgs-sql-refs.json"
out.write_text(json.dumps(refs, indent=2, ensure_ascii=False), encoding="utf-8")
print("written", out)
