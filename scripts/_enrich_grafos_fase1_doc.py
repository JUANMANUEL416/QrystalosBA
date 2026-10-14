# Enriquece metadatos Fase 1 en grafos + puntos críticos mínimos. Ejecutar una vez.
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTAB = ROOT / "conocimiento" / "contabilidad"
INDICE = CONTAB / "grafo-contabilizacion-indice.json"
GRAFO_DIR = CONTAB / "grafo-contabilizacion"

PC_EXTRA = {
    "FACTURA": [
        {"id": "PC-FTR-04", "nombre": "Duplicidad MCP", "nodo": "N3-contab-ftr", "invariante": "MCP FACTURA mismo NOREFERENCIA bloquea reenvío."},
    ],
    "NOTDBCR": [
        {"id": "PC-FNOT-03", "nombre": "Periodo F_NOTA", "nodo": "N3-contab-fnot", "invariante": "PRI del mes de la nota debe existir."},
    ],
    "CXP": [
        {"id": "PC-CXP-03", "nombre": "Duplicidad CNSFCXP", "nodo": "N3-contab-cxp", "invariante": "Segundo MCP CXP mismo REFERENCIA1 rechazado."},
    ],
    "NOTDBCRCXP": [
        {"id": "PC-CXPFNT-02", "nombre": "CxP contabilizada", "nodo": "N2-contabilizar-nota-cxp", "invariante": "FCXP origen con MCP antes de la nota."},
    ],
    "INV": [
        {"id": "PC-INV-02", "nombre": "FECHACONF vs FECHAMOV", "nodo": "N3-contab-inv", "invariante": "Periodo del asiento = FECHACONF; grilla OM usa FECHAMOV."},
    ],
    "BMOV": [
        {"id": "PC-BMOV-02", "nombre": "OFIN comprobante", "nodo": "N3-contab-bmov", "invariante": "IDOPERACION debe tener COMPROBANTE y CUENTA en OFIN."},
    ],
    "RGLO": [
        {"id": "PC-RGLO-02", "nombre": "CONTABCXC recuperación", "nodo": "N3-contab-fglo", "invariante": "Recuperación: CUENTARAD vs CUENTALG según variable."},
    ],
    "CONCI": [
        {"id": "PC-CONCI-02", "nombre": "VLRRECUPERAR", "nodo": "N3-contab-conci", "invariante": "Sin valor a recuperar no hay comprobante."},
    ],
    "RAD CXC": [
        {"id": "PC-RAD-02", "nombre": "Periodo cerrado", "nodo": "N3-contab-rad", "invariante": "PRI.CERRADO=1 detiene radicación contable."},
    ],
    "AJDEP": [
        {"id": "PC-AJDEP-02", "nombre": "CON_ACTFIJO_CONTAXCC", "nodo": "N3-contab-ajdep", "invariante": "Define si deprecia por centro de costo."},
    ],
    "IACT": [
        {"id": "PC-IACT-02", "nombre": "Evento vs depreciación", "nodo": "N3-contab-iact", "invariante": "No usar grafo AJDEP para altas/traslados IACT."},
    ],
    "ANTICIPOS": [
        {"id": "PC-ANT-02", "nombre": "CRUCETER", "nodo": "N3-contab-ant", "invariante": "CRUCETER=1 usa tercero de la CxP en débito."},
    ],
    "NOMINA": [
        {"id": "PC-NOM-02", "nombre": "NOMINATIPOCONTAB", "nodo": "N3-contab-nom", "invariante": "Variable define agrupación del asiento."},
    ],
    "CESIONES": [
        {"id": "PC-FCES-02", "nombre": "Saldo cesionable", "nodo": "N3-contab-fces", "invariante": "FTR/FCXCD deben tener saldo antes de cesión."},
    ],
    "LEGALIZACION": [
        {"id": "PC-FLEG-02", "nombre": "Caja menor", "nodo": "N3-contab-fleg", "invariante": "FLEG distinto de SPK_NC_CONTAB_ANTICIPO compras."},
    ],
    "REVERSOS": [
        {"id": "PC-REV-02", "nombre": "Periodo caja abierto", "nodo": "N3-reversar", "invariante": "REVCAJA* puede anular MCP origen si periodo abierto."},
    ],
    "MANUAL": [
        {"id": "PC-MAN-02", "nombre": "CUE Detalle", "nodo": "N3-crud-mcp", "invariante": "SPK_REVISAR_COMPROBANTE exige cuenta Detalle."},
    ],
}

OM_PUERTA = {
    "procedencia": "",
    "sp": "SPQ_CONTABILIDAD_3 · ENV_CONTA_OTROS_MODULS",
    "nota": "Pestaña Otros módulos; mismo generador que Reconstruir en MCPE.",
}


def main():
    idx = json.loads(INDICE.read_text(encoding="utf-8-sig"))
    rev = idx.get("revisionComun", {})
    for p in idx.get("procedencias") or []:
        proc = p["procedencia"]
        rel = (p.get("grafoArchivo") or "").replace("grafo-contabilizacion/", "")
        path = GRAFO_DIR / rel
        if not path.is_file():
            print("MISSING", path)
            continue
        doc = json.loads(path.read_text(encoding="utf-8-sig"))
        doc["metadatosFase1"] = {
            "estadoDocumentacion": "completo",
            "fichaErrados": f"conocimiento/contabilidad/{p.get('fichaErrados')}",
            "procesoHermano": p.get("procesoHermano"),
            "puntosCriticosArchivo": f"conocimiento/contabilidad/{p.get('puntosCriticos')}",
            "indiceMaestro": "conocimiento/contabilidad/grafo-contabilizacion-indice.json",
            "revisionComunRef": "revisionComun en índice maestro",
        }
        doc["revisionComun"] = rev
        if not doc.get("puertaOtrosModulos") and proc not in ("MANUAL", "REVERSOS"):
            puerta = {**OM_PUERTA, "procedencia": proc, "tablaOrigen": p.get("documentoOrigen", "")[:40]}
            doc["puertaOtrosModulos"] = puerta
        ab = doc.get("auditoriaBd") or {}
        if proc in ("CAJA", "CXC"):
            ab.setdefault("estado", "implementado_parcial")
            ab["checksImplementados"] = ["USVGS", "PRI", "KMCO", "TTEC", "CPCJ", "CAJ", "FPA", "FIMPDV", "documento-CNSFPAG"]
        else:
            ab["estado"] = "catalogo"
            ab["checksImplementados"] = ["USVGS", "PRI", "KMCO", "requires-grafo"]
            ab["nota"] = "Validación global en Auditoría BA; cruce documento pendiente salvo CNSFPAG."
        doc["auditoriaBd"] = ab
        path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        pc_name = (p.get("puntosCriticos") or "").split("/")[-1]
        pc_path = GRAFO_DIR / pc_name
        if pc_path.is_file() and proc in PC_EXTRA:
            pc = json.loads(pc_path.read_text(encoding="utf-8-sig"))
            existing = {x["id"] for x in pc.get("puntos") or []}
            for item in PC_EXTRA[proc]:
                if item["id"] not in existing:
                    pc.setdefault("puntos", []).append(item)
            pc_path.write_text(json.dumps(pc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    idx["documentacionFase1"] = {
        "completa": True,
        "fecha": "2026-10-13",
        "documentoMaestro": "conocimiento/contabilidad/FASE-1-GRAFO-CONTABILIZACION.md",
        "validacionSql": "conocimiento/contabilidad/grafo-contabilizacion/VALIDACION-SQL-INDICE.json",
        "auditoriaApp": "Menú Auditoría → Validar configuración contable (grafos)",
    }
    INDICE.write_text(json.dumps(idx, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("OK enrich", len(idx.get("procedencias") or []))


if __name__ == "__main__":
    main()
