# Fusiona nodos N0/N1/N2 desde grafo-contabilizacion/deep/*.json
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRAFO = ROOT / "conocimiento" / "contabilidad" / "grafo-contabilizacion"
DEEP = GRAFO / "deep"
MAP = {
    "factura.json": "factura-n012.json",
    "notdbcr.json": "notdbcr-n012.json",
    "cxp.json": "cxp-n012.json",
    "notdbcrcxp.json": "notdbcrcxp-n012.json",
    "inv.json": "inv-n012.json",
    "bmov.json": "bmov-n012.json",
    "rglo.json": "rglo-n012.json",
    "conci.json": "conci-n012.json",
    "rad-cxc.json": "rad-cxc-n012.json",
    "ajdep.json": "ajdep-n012.json",
    "iact.json": "iact-n012.json",
    "anticipos.json": "anticipos-n012.json",
    "nomina.json": "nomina-n012.json",
    "cesiones.json": "cesiones-n012.json",
    "legalizacion.json": "legalizacion-n012.json",
    "reversos.json": "reversos-n012.json",
    "manual.json": "manual-n012.json",
}


def merge_node(old: dict, patch: dict) -> dict:
    out = {**old, **patch}
    for key in ("requiresDocumento", "requiresConfig", "metodoUi", "metodos", "sp", "pantallas"):
        if key in patch and patch[key]:
            out[key] = patch[key]
    return out


def apply(grafo_path: Path, deep_path: Path) -> None:
    doc = json.loads(grafo_path.read_text(encoding="utf-8-sig"))
    patches = json.loads(deep_path.read_text(encoding="utf-8-sig"))
    extra = patches.get("nodosExtra") or []
    by_id = {n["id"]: n for n in doc.get("nodos") or []}
    for p in patches.get("nodos") or []:
        nid = p["id"]
        if nid in by_id:
            by_id[nid] = merge_node(by_id[nid], p)
        else:
            by_id[nid] = p
    for p in extra:
        if p["id"] not in by_id:
            by_id[p["id"]] = p
    # orden habitual: N4..N0 por campo orden descendente, estable por id
    ordered = sorted(by_id.values(), key=lambda n: (-int(n.get("orden", 0)), n.get("id", "")))
    doc["nodos"] = ordered
    doc["actualizado"] = patches.get("actualizado") or "2026-10-13"
    meta = doc.setdefault("metadatosFase1", {})
    meta["estadoDocumentacion"] = "profundizado-n012"
    if patches.get("enlaces"):
        doc.update(patches["enlaces"])
    grafo_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def mark_caja_cxc() -> None:
    for name in ("caja.json", "cxc.json"):
        p = GRAFO / name
        doc = json.loads(p.read_text(encoding="utf-8-sig"))
        doc.setdefault("metadatosFase1", {})["estadoDocumentacion"] = "profundizado-n012"
        doc["actualizado"] = "2026-10-13"
        p.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    DEEP.mkdir(parents=True, exist_ok=True)
    for grafo_name, deep_name in MAP.items():
        gp = GRAFO / grafo_name
        dp = DEEP / deep_name
        if not dp.is_file():
            print("SKIP missing", dp.name)
            continue
        if not gp.is_file():
            print("SKIP grafo", grafo_name)
            continue
        apply(gp, dp)
        print("OK", grafo_name)
    mark_caja_cxc()
    print("OK caja/cxc metadatos")


if __name__ == "__main__":
    main()
