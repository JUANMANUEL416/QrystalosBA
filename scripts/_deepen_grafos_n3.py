# Ampliación N3: parches deep/*-n3.json + USVGS/RAISERROR desde sql/ PREVERSION
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRAFO = ROOT / "conocimiento" / "contabilidad" / "grafo-contabilizacion"
DEEP = GRAFO / "deep"
SQL = ROOT / "sql"

# grafo filename -> [(n3_id, sql files)]
N3_MAP: dict[str, list[tuple[str, list[str]]]] = {
    "caja.json": [
        ("N3-contab-caja-ing", ["SPK_NC_CONTAB_CAJA_ING.sql"]),
        ("N3-contab-caja-egr", ["SPK_NC_CONTAB_CAJA_EGR.sql"]),
    ],
    "cxc.json": [("N3-contab-cxc", ["SPK_NC_CONTAB_CXC.sql"])],
    "factura.json": [("N3-contab-ftr", ["SPK_NC_CONTAB_FTR.sql"])],
    "notdbcr.json": [("N3-contab-fnot", ["SPK_NC_CONTAB_FNOT.sql"])],
    "cxp.json": [("N3-contab-cxp", ["SPK_NC_CONTAB_CXP.sql"])],
    "notdbcrcxp.json": [("N3-contab-cxpfnt", ["SPK_NC_CONTAB_CXPFNT.sql"])],
    "inv.json": [("N3-contab-inv", ["SPK_NC_CONTAB_INV.sql"])],
    "bmov.json": [("N3-contab-bmov", ["SPK_NC_CONTAB_BMOV.sql"])],
    "rglo.json": [("N3-contab-fglo", ["SPK_CONTAB_FGLO.sql"])],
    "conci.json": [
        ("N3-contab-conci", ["SPK_CONTAB_CONCI.sql", "SPK_NC_CONTAB_ANULA_CONCI.sql"]),
    ],
    "rad-cxc.json": [
        ("N3-contab-rad", ["SPK_CONTAB_RADICACXC.sql", "SPK_CONTAB_RADICACXC_1.sql"]),
    ],
    "ajdep.json": [("N3-contab-ajdep", ["SPK_APL_AJDEPRECIACION.sql"])],
    "iact.json": [("N3-contab-iact", ["SPK_CONTAB_IACT.sql"])],
    "anticipos.json": [("N3-contab-ant", ["SPK_NC_CONTAB_ANTICIPO.sql"])],
    "nomina.json": [("N3-contab-nom", ["SPK_NC_CONTAB_NOMINA.sql"])],
    "cesiones.json": [("N3-contab-fces", ["SPK_CONTAB_FCES.sql"])],
    "legalizacion.json": [("N3-contab-fleg", ["SPK_CONTAB_FLEG.sql"])],
    "reversos.json": [("N3-reversar", ["SPK_REVERSAR_MCP.sql"])],
    "manual.json": [("N3-crud-mcp", [])],
}

PAT_USVGS = re.compile(r"FNK_VALORVARIABLE\s*\(\s*'([^']+)'", re.I)
PAT_RAIS = re.compile(r"RAISERROR\s*\(\s*'([^']{8,120})'", re.I)


def read_sql(names: list[str]) -> str:
    parts = []
    for n in names:
        p = SQL / n
        if p.is_file():
            parts.append(p.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(parts)


def extract_catalog(text: str) -> dict:
    usvgs = sorted(set(PAT_USVGS.findall(text)))
    rais = []
    seen = set()
    for m in PAT_RAIS.findall(text):
        s = m.strip().replace("  ", " ")
        if s not in seen:
            seen.add(s)
            rais.append(s)
    return {"usvgsLeidas": usvgs, "validacionesKo": rais[:15]}


def merge_node(old: dict, patch: dict) -> dict:
    out = {**old}
    for k, v in patch.items():
        if k in ("requiresDocumento", "requiresConfig") and isinstance(v, list):
            out[k] = v
        elif v is not None and k != "id":
            out[k] = v
    return out


def merge_requires(existing: list, extra_doc: list, extra_cfg: list) -> tuple[list, list]:
    doc = list(existing or []) if isinstance(existing, list) else []
    # split by presence of usvgs/tabla in items - existing is mixed in nodos
    cfg = []
    doc_only = []
    for r in doc:
        if isinstance(r, dict) and (r.get("usvgs") or r.get("tabla") or r.get("tablas")):
            cfg.append(r)
        else:
            doc_only.append(r)
    # re-read from patch structure - actually patch replaces full lists when provided
    return doc_only, cfg


def apply_file(grafo_path: Path, slug: str) -> None:
    doc = json.loads(grafo_path.read_text(encoding="utf-8-sig"))
    patch_file = DEEP / f"{slug}-n3.json"
    patches_by_id = {}
    if patch_file.is_file():
        pj = json.loads(patch_file.read_text(encoding="utf-8-sig"))
        for n in pj.get("nodos") or []:
            patches_by_id[n["id"]] = n

    by_id = {n["id"]: n for n in doc.get("nodos") or []}
    for n3_id, sql_files in N3_MAP.get(grafo_path.name, []):
        if n3_id not in by_id:
            continue
        node = by_id[n3_id]
        if sql_files:
            cat = extract_catalog(read_sql(sql_files))
            node["catalogoSql"] = {
                "archivos": sql_files,
                "canasta": "PREVERSION (sql/)",
                **cat,
            }
            if cat["usvgsLeidas"]:
                node.setdefault("requiresConfig", [])
                ids = {r.get("id") for r in node["requiresConfig"] if isinstance(r, dict)}
                if "usvgs-spk-leidas" not in ids:
                    node["requiresConfig"].append(
                        {
                            "id": "usvgs-spk-leidas",
                            "usvgs": cat["usvgsLeidas"],
                            "desc": "Variables USVGS referenciadas en el SP (lectura automática)",
                            "obligatorio": "según rama del SP",
                        }
                    )
        post = {
            "id": "post-generacion",
            "sp": ["SPK_NC_REVISAMCPE", "SPK_PASA_MCP_MCPNIIF"],
            "nota": "Salvo MANUAL/REVERSOS: revisión y paso a MCP tras insertar MCPE/MCHE",
        }
        if n3_id not in ("N3-crud-mcp", "N3-reversar"):
            node["postGenerador"] = post
        if n3_id in patches_by_id:
            by_id[n3_id] = merge_node(node, patches_by_id[n3_id])

    doc["nodos"] = sorted(
        by_id.values(), key=lambda n: (-int(n.get("orden", 0)), n.get("id", ""))
    )
    doc.setdefault("metadatosFase1", {})["estadoDocumentacion"] = "profundizado-n012-n3"
    doc["actualizado"] = "2026-10-13"
    grafo_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    for grafo_name, entries in N3_MAP.items():
        gp = GRAFO / grafo_name
        if not gp.is_file():
            print("MISSING", grafo_name)
            continue
        slug = grafo_name.replace(".json", "")
        apply_file(gp, slug)
        print("OK N3", grafo_name, len(entries))


if __name__ == "__main__":
    main()
