"""Auditoría de procesos — trazas read-only en SQL Server (sqlcmd)."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env.local"
CONFIG_SERV = ROOT / "config" / "servidores-auditoria.json"
FLUJO_DIR = ROOT / "conocimiento" / "flujo-compras-inv-cxp-caja"
RECAUDOS_DIR = ROOT / "conocimiento" / "flujo-recaudos-cartera-contab"
RAD_CXC_DIR = ROOT / "conocimiento" / "flujo-rad-cxc-contab"
BMOV_DIR = ROOT / "conocimiento" / "flujo-bmov-contab"
NOMINA_DIR = ROOT / "conocimiento" / "flujo-nomina-contab"
ANTICIPOS_DIR = ROOT / "conocimiento" / "flujo-anticipos-contab"
IACT_DIR = ROOT / "conocimiento" / "flujo-iact-contab"
FLEG_DIR = ROOT / "conocimiento" / "flujo-legalizacion-contab"
CESIONES_DIR = ROOT / "conocimiento" / "flujo-cesiones-contab"
AJDEP_DIR = ROOT / "conocimiento" / "flujo-ajdep-contab"
REVERSOS_DIR = ROOT / "conocimiento" / "flujo-reversos-contab"
CIERRE_DIR = ROOT / "conocimiento" / "flujo-cierre-periodo-contab"
CONTAB_DIR = ROOT / "conocimiento" / "contabilidad"
GRAFO_CONTAB_DIR = CONTAB_DIR / "grafo-contabilizacion"
GRAFO_CONTAB_INDICE = CONTAB_DIR / "grafo-contabilizacion-indice.json"
INVENTARIO_DIR = ROOT / "conocimiento" / "inventario"
RUNBOOK_MD = FLUJO_DIR / "RUNBOOK-SOPORTE-IEXI-CXP.md"
RUNBOOK_RECAUDOS_MD = RECAUDOS_DIR / "RUNBOOK-SOPORTE-RECAUDOS.md"

FLUJO_IDS = {
    "flujo-compras-inv-cxp-caja": FLUJO_DIR,
    "flujo-recaudos-cartera-contab": RECAUDOS_DIR,
    "flujo-rad-cxc-contab": RAD_CXC_DIR,
    "flujo-bmov-contab": BMOV_DIR,
    "flujo-nomina-contab": NOMINA_DIR,
    "flujo-anticipos-contab": ANTICIPOS_DIR,
    "flujo-iact-contab": IACT_DIR,
    "flujo-legalizacion-contab": FLEG_DIR,
    "flujo-cesiones-contab": CESIONES_DIR,
    "flujo-ajdep-contab": AJDEP_DIR,
    "flujo-reversos-contab": REVERSOS_DIR,
    "flujo-cierre-periodo-contab": CIERRE_DIR,
}

_AYUDA_PC_CACHE: dict[str, str] | None = None

# Primera acción soporte cuando el paso cita estos PC (complementa núcleo PC-N*)
_AYUDA_PC_EXTRA: dict[str, str] = {
    "PC-04b": "Completar factura, fechas, PCOSTO y vencimientos → CONF_ENTRADA (inv.ges).",
    "PC-05": "CxP: PROCESAR_IMOVH (relee IMOVH); no solo RECONSTRUIR_CUENTAS_FCXPD.",
    "PC-04": "Cuadre cantidades OC vs IMOVH; revisar recepción parcial.",
    "PC-01": "Completar KMCOM CXP_COMPRAS e inventario por ITAR/CCOSTO.",
}


def _read_json(path: Path, default=None):
    if not path.is_file():
        return default if default is not None else {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def listar_servidores() -> list[dict]:
    cfg = _read_json(CONFIG_SERV, {"servidores": []})
    out = []
    for s in cfg.get("servidores") or []:
        db_default = ""
        env_db = (s.get("baseDatosEnv") or "").strip()
        if env_db and ENV.is_file():
            for line in ENV.read_text(encoding="utf-8").splitlines():
                if line.strip().startswith(env_db + "="):
                    db_default = line.split("=", 1)[1].strip()
                    break
        bases_cfg = [str(b).strip() for b in (s.get("bases") or []) if str(b).strip()]
        if not bases_cfg and db_default:
            bases_cfg = [db_default]
        out.append(
            {
                "id": s.get("id"),
                "nombre": s.get("nombre"),
                "baseDatosDefault": db_default or (bases_cfg[0] if bases_cfg else ""),
                "bases": bases_cfg,
                "soloLectura": bool(s.get("soloLectura", True)),
            }
        )
    return out


def listar_flujos() -> list[dict]:
    out: list[dict] = []
    for fid, fdir in FLUJO_IDS.items():
        proc = _read_json(fdir / "proceso.json", {})
        if not proc.get("id"):
            continue
        pc = _read_json(fdir / "puntos-criticos.json", {}) or {}
        out.append(
            {
                "id": proc["id"],
                "nombre": proc.get("nombre"),
                "descripcion": proc.get("resumen"),
                "estado": proc.get("estado"),
                "pasos": len(proc.get("pasos") or []),
                "puntosCriticos": len(pc.get("puntos") or []),
                "parametroTraza": proc.get("parametroTraza"),
            }
        )
    return out


def _load_credencial(credencial_env: str) -> tuple[str, str, str, str]:
    host, port, user, pwd = None, None, None, None
    if not ENV.is_file():
        raise ValueError("Falta .env.local con credenciales")
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith(credencial_env + "="):
            parts = line.split("=", 1)[1].split("|")
            if len(parts) >= 4:
                host, port, user, pwd = parts[0], parts[1], parts[2], parts[3]
            break
    if not all([host, port, user, pwd]):
        raise ValueError(f"Credencial {credencial_env} incompleta en .env.local")
    return f"{host},{port}", user, pwd, ""


def _resolve_server_db(servidor_id: str, base_datos: str) -> tuple[str, str, str, str]:
    cfg = _read_json(CONFIG_SERV, {"servidores": []})
    match = next((s for s in cfg.get("servidores") or [] if s.get("id") == servidor_id), None)
    if not match:
        raise ValueError(f"Servidor desconocido: {servidor_id}")
    server, user, pwd, _ = _load_credencial(match.get("credencialEnv") or "servidor9")
    db = (base_datos or "").strip()
    if not db:
        env_db = (match.get("baseDatosEnv") or "dbservidor9").strip()
        for line in ENV.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith(env_db + "="):
                db = line.split("=", 1)[1].strip()
                break
    if not db:
        raise ValueError("Indique base de datos")
    return server, user, pwd, db


def _sqlcmd_query(server: str, user: str, pwd: str, db: str, query: str) -> str:
    q = query.strip()
    upper = re.sub(r"\s+", " ", q.upper())
    if not upper.startswith("SELECT") and not upper.startswith("SET NOCOUNT"):
        raise ValueError("Solo consultas SELECT permitidas")
    for bad in ("INSERT ", "UPDATE ", "DELETE ", "MERGE ", "EXEC ", "EXECUTE ", "DROP ", "ALTER ", "TRUNCATE "):
        if bad in upper:
            raise ValueError(f"Operación no permitida en auditoría: {bad.strip()}")
    cmd = [
        "sqlcmd",
        "-S",
        server,
        "-U",
        user,
        "-P",
        pwd,
        "-d",
        db,
        "-C",
        "-s",
        "\t",
        "-W",
        "-Q",
        q,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout or f"sqlcmd {r.returncode}").strip()[:2000])
    return r.stdout


def _parse_tsv(raw: str) -> list[dict]:
    lines = [ln.rstrip() for ln in raw.splitlines() if ln.strip()]
    if len(lines) < 2:
        return []
    header_idx = None
    for i, ln in enumerate(lines):
        if "\t" in ln and not ln.strip().startswith("-"):
            header_idx = i
            break
    if header_idx is None:
        return []
    headers = [h.strip() for h in lines[header_idx].split("\t")]
    rows = []
    for ln in lines[header_idx + 1 :]:
        if ln.strip().startswith("-") or ln.strip().startswith("("):
            continue
        parts = ln.split("\t")
        if len(parts) < len(headers):
            parts += [""] * (len(headers) - len(parts))
        row = {headers[j]: (parts[j].strip() if j < len(parts) else "") for j in range(len(headers))}
        if any(v for v in row.values()):
            rows.append(row)
    return rows


def _esc(val: str) -> str:
    return (val or "").replace("'", "''")


def _resolve_cnsfcom(server, user, pwd, db, parametro: str, tipo: str) -> str | None:
    val = (parametro or "").strip()
    if not val:
        return None
    if tipo == "cnsfcom":
        q = f"SET NOCOUNT ON; SELECT TOP 1 CNSFCOM FROM dbo.FCOM WITH (NOLOCK) WHERE CNSFCOM = N'{_esc(val)}';"
    else:
        q = (
            "SET NOCOUNT ON; SELECT TOP 1 CNSFCOM FROM dbo.FCOM WITH (NOLOCK) WHERE "
            f"CNSFCOM = N'{_esc(val)}' OR CAST(ORDENCOMPRA AS VARCHAR(20)) = N'{_esc(val)}' "
            f"OR CNSFCOM LIKE N'%{_esc(val)}' ORDER BY FECHA DESC;"
        )
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        return None
    return rows[0].get("CNSFCOM") or list(rows[0].values())[0]


def _load_ayuda_pc_map() -> dict[str, str]:
    global _AYUDA_PC_CACHE
    if _AYUDA_PC_CACHE is not None:
        return _AYUDA_PC_CACHE
    out = dict(_AYUDA_PC_EXTRA)
    nucleo = _read_json(FLUJO_DIR / "nucleo-critico-iexi-cxp.json", {})
    for ctrl in nucleo.get("controles") or []:
        pid = (ctrl.get("id") or "").strip()
        acc = (ctrl.get("accionSiFalla") or "").strip()
        if pid and acc:
            out[pid] = acc
    rec_pc = _read_json(RECAUDOS_DIR / "puntos-criticos.json", {}) or {}
    for pt in rec_pc.get("puntos") or []:
        pid = (pt.get("id") or "").strip()
        acc = (pt.get("invariante") or pt.get("nombre") or "").strip()
        if pid and acc and pid not in out:
            out[pid] = acc
    _AYUDA_PC_CACHE = out
    return out


def _ayuda_soporte_para_pcs(pc_ids: list[str] | None) -> list[dict]:
    if not pc_ids:
        return []
    mp = _load_ayuda_pc_map()
    items: list[dict] = []
    seen: set[str] = set()
    for pid in pc_ids:
        pid = (pid or "").strip()
        if not pid or pid in seen:
            continue
        seen.add(pid)
        if pid in mp:
            items.append({"pc": pid, "accion": mp[pid]})
    return items


def _check(estado: str, titulo: str, detalle: str, filas: list | None = None, pc_ids: list | None = None) -> dict:
    pcs = pc_ids or []
    row: dict[str, Any] = {
        "estado": estado,
        "titulo": titulo,
        "detalle": detalle,
        "filas": filas or [],
        "puntosCriticos": pcs,
    }
    ayuda = _ayuda_soporte_para_pcs(pcs)
    if ayuda and estado in ("ko", "warn"):
        row["ayudaSoporte"] = ayuda
    return row


def _parse_par_referencia(referencia: str) -> tuple[str, str | None]:
    ref = (referencia or "").strip()
    if not ref:
        return "", None
    for sep in ("/", "|"):
        if sep in ref:
            a, b = ref.split(sep, 1)
            return a.strip(), b.strip()
    return ref, None


def _pasos_from_grafo_checks(
    rows: list[dict],
    titulo_prefix: str = "Grafo config",
    default_pc: list[str] | None = None,
) -> list[dict]:
    dpc = default_pc or []
    return [
        _check(
            row.get("estado") or "ok",
            f"{titulo_prefix} — {row.get('titulo', '')}",
            row.get("validacion") or "",
            row.get("filas") or [],
            row.get("puntosCriticos") or dpc,
        )
        for row in rows
    ]


def meta_runbook_soporte() -> dict:
    return {
        "titulo": "Runbook soporte IEXI ↔ CxP",
        "archivo": "RUNBOOK-SOPORTE-IEXI-CXP.md",
        "rutaRelativa": "conocimiento/flujo-compras-inv-cxp-caja/RUNBOOK-SOPORTE-IEXI-CXP.md",
        "urlMarkdown": "/api/auditoria/runbook",
        "nucleoDoc": "NUCLEO-CRITICO-IEXI-CXP.md",
    }


def leer_runbook_markdown() -> str:
    if not RUNBOOK_MD.is_file():
        raise FileNotFoundError("RUNBOOK-SOPORTE-IEXI-CXP.md no encontrado")
    return RUNBOOK_MD.read_text(encoding="utf-8")


def trazar_compras_oc(
    servidor_id: str,
    base_datos: str,
    parametro: str,
    tipo_param: str = "ordencompra",
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = _resolve_cnsfcom(server, user, pwd, db, parametro, tipo_param)
    if not cns:
        return {
            "ok": False,
            "error": f"No se encontró FCOM para «{parametro}» en {db}.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }

    esc = _esc(cns)
    pasos: list[dict] = []

    # --- FCOM cabecera ---
    q_fcom = f"""
SET NOCOUNT ON;
SELECT CNSFCOM, ORDENCOMPRA, ESTADO, IDTERCERO, N_FACTURA, F_FACTURA,
       VR_ANTESIVA, IVA, VR_TOTAL, IDBODEGA, ENINVENTARIO, ENCXP, CNSFCOT, FECHA,
       LTRIM(RTRIM(COALESCE(IDTIPOSER, ''))) AS IDTIPOSER
FROM dbo.FCOM WITH (NOLOCK) WHERE CNSFCOM = N'{esc}';
"""
    fcom_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcom))
    fcom = fcom_rows[0] if fcom_rows else {}
    est = (fcom.get("ESTADO") or "").upper()
    if not fcom:
        pasos.append(_check("ko", "Orden de compra", "Sin fila FCOM.", pc_ids=["PC-02"]))
    elif est in ("A", "X"):
        pasos.append(_check("ko", "Orden de compra", f"CNSFCOM={cns} ESTADO={est} (anulada/cancelada).", fcom_rows, ["PC-02"]))
    elif est == "C":
        pasos.append(_check("warn", "Orden de compra", f"CNSFCOM={cns} en borrador (ESTADO=C). Falta CONFIRMAR_ORDEN.", fcom_rows, ["PC-02"]))
    elif est in ("P", "R", "I"):
        oc_num = fcom.get("ORDENCOMPRA") or "0"
        pasos.append(
            _check(
                "ok",
                "Orden de compra",
                f"CNSFCOM={cns} ESTADO={est} (confirmada/recepción). ORDENCOMPRA={oc_num}.",
                fcom_rows,
                ["PC-02"],
            )
        )
    else:
        pasos.append(_check("warn", "Orden de compra", f"CNSFCOM={cns} ESTADO={est} (revisar dominio).", fcom_rows, ["PC-02"]))

    # --- Confirmación / flags cabecera ---
    if fcom:
        eni = fcom.get("ENINVENTARIO", "")
        enc = fcom.get("ENCXP", "")
        pasos.append(
            _check(
                "ok",
                "Flags FCOM (inventario/CxP)",
                f"ENINVENTARIO={eni}, ENCXP={enc} (referencia; CxP vía FCXP, existencias vía IMOV confirmado).",
                fcom_rows,
                ["PC-02"],
            )
        )

    # --- Bodega OC + tipo movimiento USVGS ---
    q_bod = f"""
SET NOCOUNT ON;
DECLARE @IDMOV VARCHAR(20) = (
  SELECT TOP 1 LTRIM(RTRIM(DATO)) FROM dbo.USVGS WITH (NOLOCK) WHERE IDVARIABLE = N'IDINVMOV_COMPRAS'
);
SELECT F.IDBODEGA,
       B.DESCRIPCION AS BOD_DESC,
       B.ESTADO AS BOD_ESTADO,
       LTRIM(RTRIM(COALESCE(B.MUEVEEXISTENCIAS, ''))) AS MUEVEEXISTENCIAS,
       LTRIM(RTRIM(COALESCE(B.CCOSTO, ''))) AS CCOSTO,
       CAST(COALESCE(B.NOCONTABILIZA, 0) AS INT) AS NOCONTABILIZA,
       @IDMOV AS IDINVMOV_COMPRAS,
       T.IDTIPOMOV AS ITMO_ID,
       T.DESCRIPCION AS ITMO_DESC,
       LTRIM(RTRIM(COALESCE(T.TIPO, ''))) AS ITMO_TIPO,
       CAST(COALESCE(T.COMPRAS, 0) AS INT) AS ITMO_COMPRAS,
       CAST(COALESCE(T.SECONTABILIZA, 0) AS INT) AS ITMO_SECONTABILIZA,
       LTRIM(RTRIM(COALESCE(T.ESTADO, ''))) AS ITMO_ESTADO,
       CAST(CASE WHEN COALESCE(B.NOCONTABILIZA, 0) = 1 THEN 0
            ELSE COALESCE(T.SECONTABILIZA, 0) END AS INT) AS SECONTABILIZA_EFECTIVO
FROM dbo.FCOM F WITH (NOLOCK)
LEFT JOIN dbo.IBOD B WITH (NOLOCK) ON B.IDBODEGA = F.IDBODEGA
LEFT JOIN dbo.ITMO T WITH (NOLOCK) ON T.IDTIPOMOV = @IDMOV
WHERE F.CNSFCOM = N'{esc}';
"""
    bod_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_bod))
    if fcom and bod_rows:
        row = bod_rows[0]
        bod_issues: list[str] = []
        idbod = (row.get("IDBODEGA") or "").strip()
        if not idbod:
            bod_issues.append("FCOM sin IDBODEGA")
        elif not (row.get("BOD_DESC") or "").strip():
            bod_issues.append(f"Bodega {idbod} no existe en IBOD")
        elif (row.get("BOD_ESTADO") or "").strip().lower() not in ("activo", "a"):
            bod_issues.append(f"Bodega {idbod} ESTADO={row.get('BOD_ESTADO')}")
        mov_usv = (row.get("IDINVMOV_COMPRAS") or "").strip()
        if not mov_usv:
            bod_issues.append("USVGS IDINVMOV_COMPRAS vacía")
        elif not (row.get("ITMO_ID") or "").strip():
            bod_issues.append(f"ITMO {mov_usv} no encontrado")
        else:
            if (row.get("ITMO_ESTADO") or "").strip().lower() not in ("activo", "a"):
                bod_issues.append(f"ITMO {mov_usv} inactivo")
            if "crédito" not in (row.get("ITMO_TIPO") or "").lower() and "credito" not in (
                row.get("ITMO_TIPO") or ""
            ).lower():
                bod_issues.append(f"ITMO {mov_usv} TIPO={row.get('ITMO_TIPO')} (se espera entrada/Crédito)")
        if bod_issues:
            pasos.append(
                _check(
                    "ko",
                    "Bodega y tipo movimiento (OC)",
                    "; ".join(bod_issues),
                    bod_rows,
                    ["PC-00g", "PC-00h", "PC-00i"],
                )
            )
        else:
            sec = row.get("SECONTABILIZA_EFECTIVO", "")
            msg = f"Bodega {idbod}; tipo mov {mov_usv}; SECONTABILIZA efectivo={sec}."
            nivel = "ok" if str(sec) != "" else "warn"
            pasos.append(
                _check(nivel, "Bodega y tipo movimiento (OC)", msg, bod_rows, ["PC-00g", "PC-00h", "PC-00i"])
            )
    elif fcom:
        pasos.append(
            _check("warn", "Bodega y tipo movimiento (OC)", "No se pudo leer IBOD/ITMO/USVGS.", [], ["PC-00g"])
        )

    # --- FCOMD vs recepción ---
    q_fcomd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS, SUM(COALESCE(CANTIDAD,0)) AS CANT_TOTAL,
       SUM(COALESCE(CANTIDAD_REF_ENT,0)) AS CANT_REF_ENT
FROM dbo.FCOMD WITH (NOLOCK) WHERE CNSFCOM = N'{esc}';
"""
    fcomd = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcomd))
    pasos.append(_check("ok", "Detalle OC (FCOMD)", "Agregado detalle.", fcomd, ["PC-04"]))

    # --- Catálogo artículos en líneas OC ---
    q_cat = f"""
SET NOCOUNT ON;
SELECT D.IDARTICULO,
       I.DESCRIPCION,
       I.ESTADO,
       I.IDITAR,
       LTRIM(RTRIM(COALESCE(I.IDSERVICIO, ''))) AS IDSERVICIO,
       LTRIM(RTRIM(COALESCE(I.IDIMPUESTO, ''))) AS IDIMPUESTO,
       CAST(COALESCE(T.MLOTEO, 0) AS INT) AS MLOTEO,
       CAST(COALESCE(T.MFECHAVENCIMIENTO, 0) AS INT) AS MFECHAVENCIMIENTO,
       CAST(COALESCE(I.MIVA, 0) AS INT) AS IART_MIVA,
       CASE WHEN S.IDSERVICIO IS NULL THEN 0 ELSE 1 END AS TIENE_SER
FROM dbo.FCOMD D WITH (NOLOCK)
LEFT JOIN dbo.IART I WITH (NOLOCK) ON I.IDARTICULO = D.IDARTICULO
LEFT JOIN dbo.ITAR T WITH (NOLOCK) ON T.IDITAR = I.IDITAR
LEFT JOIN dbo.SER S WITH (NOLOCK) ON S.IDSERVICIO = I.IDSERVICIO
WHERE D.CNSFCOM = N'{esc}'
GROUP BY D.IDARTICULO, I.DESCRIPCION, I.ESTADO, I.IDITAR, I.IDSERVICIO, I.IDIMPUESTO,
         T.MLOTEO, T.MFECHAVENCIMIENTO, I.MIVA, S.IDSERVICIO;
"""
    cat_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cat))
    if not cat_rows:
        pasos.append(_check("warn", "Catálogo artículos (OC)", "Sin líneas FCOMD para revisar IART.", [], ["PC-00c"]))
    else:
        issues: list[str] = []
        for row in cat_rows:
            art = (row.get("IDARTICULO") or "").strip()
            if not (row.get("DESCRIPCION") or "").strip():
                issues.append(f"{art}: sin IART o artículo inexistente")
                continue
            if (row.get("ESTADO") or "").strip().lower() not in ("activo", "a"):
                issues.append(f"{art}: ESTADO={row.get('ESTADO')}")
            if not (row.get("IDITAR") or "").strip():
                issues.append(f"{art}: sin IDITAR")
            if int(row.get("TIENE_SER") or 0) == 0 and (row.get("IDSERVICIO") or "").strip():
                issues.append(f"{art}: IDSERVICIO sin fila SER")
        if issues:
            pasos.append(
                _check(
                    "ko",
                    "Catálogo artículos (OC)",
                    "; ".join(issues[:8]) + ("…" if len(issues) > 8 else ""),
                    cat_rows,
                    ["PC-00c", "PC-00e", "PC-01"],
                )
            )
        else:
            pasos.append(
                _check(
                    "ok",
                    "Catálogo artículos (OC)",
                    f"{len(cat_rows)} artículo(s): IART+ITAR; SER cuando hay IDSERVICIO.",
                    cat_rows,
                    ["PC-00a", "PC-00c", "PC-00e"],
                )
            )

    # --- ITRA / ITRAH (tránsito y loteo) ---
    q_itra = f"""
SET NOCOUNT ON;
SELECT I.CNSITRA, I.ESTADO, I.IDTIPOMOV, I.FECHA,
       (SELECT COUNT(*) FROM dbo.ITRAH H WITH (NOLOCK) WHERE H.CNSITRA = I.CNSITRA) AS LINEAS_ITRAH,
       (SELECT COUNT(*) FROM dbo.ITRAH H WITH (NOLOCK) WHERE H.CNSITRA = I.CNSITRA AND COALESCE(H.INICIAL,0)=1) AS LINEAS_LOTEADAS,
       (SELECT COUNT(*) FROM dbo.ITRAH H WITH (NOLOCK) WHERE H.CNSITRA = I.CNSITRA AND COALESCE(H.INICIAL,0)=0 AND COALESCE(H.CANTIDADORI,0)>0 AND COALESCE(H.IDCAUSAL,'')='') AS PEND_SIN_CAUSA
FROM dbo.ITRA I WITH (NOLOCK) WHERE I.CNSFCOM = N'{esc}' ORDER BY I.FECHA;
"""
    itra_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_itra))
    tiposer = ((fcom.get("IDTIPOSER") if fcom else "") or "").strip().lower()
    mov_esperado = (bod_rows[0].get("IDINVMOV_COMPRAS") if bod_rows else "") or ""
    if tiposer == "presta":
        q_prest = """
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(DATO)) AS DATO FROM dbo.USVGS WITH (NOLOCK)
WHERE IDVARIABLE = N'IDINVMOV_PRESTAMOS';
"""
        prest = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_prest))
        if prest and (prest[0].get("DATO") or "").strip():
            mov_esperado = (prest[0].get("DATO") or "").strip()

    if not itra_rows:
        if fcom and est in ("P", "R", "I"):
            pasos.append(
                _check(
                    "ko",
                    "Tránsito (ITRA)",
                    "OC confirmada/recepción pero sin ITRA (¿falló SPK_INSERT_ITRA_REQ?).",
                    [],
                    ["PC-02b", "PC-03"],
                )
            )
        else:
            pasos.append(_check("warn", "Tránsito (ITRA)", "Sin ITRA ligado a la OC.", [], ["PC-03", "PC-02b"]))
    else:
        if fcom and est in ("P", "R", "I"):
            pasos.append(
                _check(
                    "ok",
                    "Confirmación → tránsito",
                    f"{len(itra_rows)} ITRA(s) ligados a la OC.",
                    itra_rows[:3],
                    ["PC-02b"],
                )
            )
        for row in itra_rows:
            tm = (row.get("IDTIPOMOV") or "").strip()
            if mov_esperado and tm and tm != mov_esperado:
                pasos.append(
                    _check(
                        "ko",
                        "ITRA tipo movimiento",
                        f"CNSITRA={row.get('CNSITRA')}: IDTIPOMOV={tm} ≠ esperado {mov_esperado}.",
                        [row],
                        ["PC-02c", "PC-00g"],
                    )
                )
            lot = int(row.get("LINEAS_LOTEADAS") or 0)
            pend = int(row.get("PEND_SIN_CAUSA") or 0)
            est_i = (row.get("ESTADO") or "").strip()
            if pend > 0:
                pasos.append(_check("ko", "Loteo tránsito", f"CNSITRA={row.get('CNSITRA')}: {pend} línea(s) sin causa (no loteo).", [row], ["PC-03b"]))
            elif lot == 0 and est_i not in ("1", "2"):
                pasos.append(_check("warn", "Loteo tránsito", f"CNSITRA={row.get('CNSITRA')}: sin ITRAH INICIAL=1 (falta lotear o aceptar).", [row], ["PC-03b"]))
            else:
                pasos.append(_check("ok", "Tránsito / loteo", f"CNSITRA={row.get('CNSITRA')} ESTADO={est_i}; loteadas={lot}.", [row], ["PC-03", "PC-03b"]))

    # --- IMOV entradas ---
    q_imov = f"""
SET NOCOUNT ON;
SELECT CNSMOV, ESTADO, FECHA, IDBODEGA, N_FACTURA, VR_TOTAL, TIPO
FROM dbo.IMOV WITH (NOLOCK) WHERE CNSFCOM = N'{esc}' ORDER BY FECHA;
"""
    imov_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_imov))
    if not imov_rows:
        pasos.append(_check("warn", "Ingreso inventario (IMOV)", "No hay movimientos ligados a esta OC.", [], ["PC-03"]))
    else:
        estados = {r.get("ESTADO", "") for r in imov_rows}
        if estados <= {"0"}:
            pasos.append(_check("warn", "Ingreso inventario (IMOV)", "Movimiento(s) sin confirmar (ESTADO=0). Falta CONF_ENTRADA.", imov_rows, ["PC-03"]))
        elif "0" in estados:
            pasos.append(_check("warn", "Ingreso inventario (IMOV)", "Hay entradas confirmadas y pendientes.", imov_rows, ["PC-03"]))
        else:
            pasos.append(_check("ok", "Ingreso inventario (IMOV)", "Entrada(s) confirmada(s).", imov_rows, ["PC-03", "PC-04"]))

    cnsmovs = [_esc(r.get("CNSMOV", "")) for r in imov_rows if r.get("CNSMOV")]
    imovh_resumen = []
    if cnsmovs:
        in_list = ",".join(f"N'{m}'" for m in cnsmovs)
        q_imovh = f"""
SET NOCOUNT ON;
SELECT CNSMOV, COUNT(*) AS LINEAS, SUM(COALESCE(CANTIDAD,0)) AS CANT,
       SUM(COALESCE(PCOSTO,0)*COALESCE(CANTIDAD,0)) AS COSTO_EXT,
       SUM(COALESCE(VLRIVA,0)) AS VLRIVA
FROM dbo.IMOVH WITH (NOLOCK) WHERE CNSMOV IN ({in_list}) GROUP BY CNSMOV;
"""
        imovh_resumen = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_imovh))
        pasos.append(_check("ok", "Detalle entrada (IMOVH)", "Costos e IVA en líneas.", imovh_resumen, ["PC-04"]))

    conf_movs = [
        r.get("CNSMOV")
        for r in imov_rows
        if str(r.get("ESTADO", "")).strip() == "1" and r.get("CNSMOV")
    ]
    if conf_movs:
        cm_esc = ",".join(f"N'{_esc(m)}'" for m in conf_movs)
        q_iexi = f"""
SET NOCOUNT ON;
SELECT M.CNSMOV,
       COUNT(*) AS LINEAS_IMOVH,
       SUM(CASE WHEN E.IDARTICULO IS NULL THEN 1 ELSE 0 END) AS LINEAS_SIN_IEXI
FROM dbo.IMOV M WITH (NOLOCK)
INNER JOIN dbo.IMOVH H WITH (NOLOCK) ON H.CNSMOV = M.CNSMOV AND COALESCE(H.CANTIDAD, 0) > 0
LEFT JOIN dbo.IEXI E WITH (NOLOCK)
  ON E.IDBODEGA = M.IDBODEGA AND E.IDARTICULO = H.IDARTICULO AND E.NOLOTE = H.NOLOTE
WHERE M.CNSFCOM = N'{esc}' AND COALESCE(M.ESTADO, 0) = 1
  AND M.CNSMOV IN ({cm_esc})
GROUP BY M.CNSMOV;
"""
        iexi_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_iexi))
        iexi_bad = [r for r in iexi_rows if int(r.get("LINEAS_SIN_IEXI") or 0) > 0]
        if iexi_bad:
            pasos.append(
                _check(
                    "ko",
                    "IEXI vs IMOV confirmado",
                    "Líneas IMOVH sin fila IEXI (bodega+artículo+NOLOTE).",
                    iexi_rows,
                    ["PC-N1", "PC-04"],
                )
            )
        elif iexi_rows:
            pasos.append(
                _check(
                    "ok",
                    "IEXI vs IMOV confirmado",
                    f"{len(iexi_rows)} movimiento(s) confirmado(s) con IEXI ligado.",
                    iexi_rows,
                    ["PC-N1"],
                )
            )

    # --- Preconfirmación CONF_ENTRADA (IMOV pendientes) ---
    pend_movs = [r.get("CNSMOV") for r in imov_rows if str(r.get("ESTADO", "")).strip() in ("0", "")]
    if pend_movs:
        pm_esc = ",".join(f"N'{_esc(m)}'" for m in pend_movs if m)
        if pm_esc:
            q_pre = f"""
SET NOCOUNT ON;
SELECT M.CNSMOV,
       SUM(CASE WHEN COALESCE(H.PCOSTO, 0) <= 0 AND COALESCE(H.CANTIDAD, 0) > 0 THEN 1 ELSE 0 END) AS LINEAS_SIN_PCOSTO,
       SUM(CASE WHEN ITAR.MFECHAVENCIMIENTO = 1 AND COALESCE(H.FECHAVENCE, '') = '' THEN 1 ELSE 0 END) AS LINEAS_SIN_VENCE,
       SUM(CASE WHEN COALESCE(H.ESTADO, 0) = 0 AND COALESCE(H.CANTIDAD, 0) > 0 THEN 1 ELSE 0 END) AS LINEAS_CONFIRMables
FROM dbo.IMOV M WITH (NOLOCK)
INNER JOIN dbo.IMOVH H WITH (NOLOCK) ON H.CNSMOV = M.CNSMOV
LEFT JOIN dbo.IART I WITH (NOLOCK) ON I.IDARTICULO = H.IDARTICULO
LEFT JOIN dbo.ITAR ITAR WITH (NOLOCK) ON ITAR.IDITAR = I.IDITAR
WHERE M.CNSMOV IN ({pm_esc}) AND COALESCE(M.ESTADO, 0) = 0
GROUP BY M.CNSMOV;
"""
            pre_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pre))
            pre_issues: list[str] = []
            for pr in pre_rows:
                cm = pr.get("CNSMOV", "")
                if int(pr.get("LINEAS_SIN_PCOSTO") or 0) > 0:
                    pre_issues.append(f"{cm}: PCOSTO≤0")
                if int(pr.get("LINEAS_SIN_VENCE") or 0) > 0:
                    pre_issues.append(f"{cm}: sin vencimiento")
                if int(pr.get("LINEAS_CONFIRMables") or 0) == 0:
                    pre_issues.append(f"{cm}: sin líneas confirmables")
            if pre_issues:
                pasos.append(
                    _check(
                        "ko",
                        "Preconfirmación CONF_ENTRADA",
                        "; ".join(pre_issues[:6]),
                        pre_rows,
                        ["PC-04b"],
                    )
                )
            else:
                pasos.append(
                    _check(
                        "warn",
                        "Preconfirmación CONF_ENTRADA",
                        f"{len(pre_rows)} IMOV(0): revisar factura/fechas en cabecera antes de confirmar.",
                        pre_rows,
                        ["PC-04b"],
                    )
                )

    # --- FCXP ---
    q_fcxp = f"""
SET NOCOUNT ON;
SELECT CNSFCXP, CNSFCOM, NOREFERENCIA, N_FACTURA, PROCEDENCIA, ESTADO,
       CONTABILIZADA, NROCOMPROBANTE, VALOR, SALDO, VLR_NETO, VLR_IVA
FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCOM = N'{esc}' OR CNSFCXP IN (
  SELECT DISTINCT CNSFCXP FROM dbo.FCXPD WITH (NOLOCK) WHERE N_PRESUP IN ({",".join(f"N'{m}'" for m in cnsmovs) if cnsmovs else "NULL"})
);
"""
    if not cnsmovs:
        q_fcxp = f"""
SET NOCOUNT ON;
SELECT CNSFCXP, CNSFCOM, NOREFERENCIA, N_FACTURA, PROCEDENCIA, ESTADO,
       CONTABILIZADA, NROCOMPROBANTE, VALOR, SALDO, VLR_NETO, VLR_IVA
FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCOM = N'{esc}';
"""
    fcxp_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcxp))
    if not fcxp_rows:
        encxp = (fcom.get("ENCXP") or "").strip()
        if encxp in ("1", "S", "SI"):
            pasos.append(_check("ko", "Cuenta por pagar (FCXP)", "ENCXP activo pero no hay FCXP.", [], ["PC-05"]))
        else:
            pasos.append(_check("warn", "Cuenta por pagar (FCXP)", "Sin FCXP aún (¿falta PROCESAR_IMOVH?).", [], ["PC-05"]))
    else:
        for row in fcxp_rows:
            cont = (row.get("CONTABILIZADA") or "0").strip()
            if cont in ("0", ""):
                pasos.append(_check("warn", "CxP sin contabilizar", f"CNSFCXP={row.get('CNSFCXP')} CONTABILIZADA=0.", [row], ["PC-07"]))
            else:
                pasos.append(_check("ok", "CxP contabilizada", f"CNSFCXP={row.get('CNSFCXP')} NRO={row.get('NROCOMPROBANTE')}.", [row], ["PC-07"]))

    cnsfcxps = [_esc(r.get("CNSFCXP", "")) for r in fcxp_rows if r.get("CNSFCXP")]

    # --- FCXPD puente IMOV ---
    if cnsfcxps and cnsmovs:
        q_fcxpd = f"""
SET NOCOUNT ON;
SELECT CNSFCXP, ITEM, N_PRESUP AS CNSMOV, CUENTA_SER, CUENTAGRAV, VLR_IVA, VALOR, CANTIDAD
FROM dbo.FCXPD WITH (NOLOCK)
WHERE CNSFCXP IN ({",".join(f"N'{x}'" for x in cnsfcxps)})
  AND N_PRESUP IN ({",".join(f"N'{m}'" for m in cnsmovs)});
"""
        fcxpd_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcxpd))
        if not fcxpd_rows:
            pasos.append(_check("ko", "Detalle CxP ↔ IMOV", "No hay FCXPD con N_PRESUP=CNSMOV.", [], ["PC-05"]))
        else:
            grav = [r for r in fcxpd_rows if float(r.get("VLR_IVA") or 0) > 0]
            msg = f"{len(fcxpd_rows)} línea(s) puente IMOV."
            if grav:
                sin_grav = [r for r in grav if (r.get("CUENTA_SER") or "") == (r.get("CUENTAGRAV") or "")]
                if sin_grav:
                    pasos.append(_check("warn", "Detalle CxP ↔ IMOV (IVA gravado)", msg + " Revisar CUENTAGRAV en líneas con IVA.", fcxpd_rows, ["PC-05", "PC-06"]))
                else:
                    pasos.append(_check("ok", "Detalle CxP ↔ IMOV (IVA gravado)", msg, fcxpd_rows, ["PC-05"]))
            else:
                pasos.append(_check("ok", "Detalle CxP ↔ IMOV", msg, fcxpd_rows, ["PC-05"]))
            if cnsmovs:
                q_enc = f"""
SET NOCOUNT ON;
SELECT CNSMOV,
       SUM(CASE WHEN COALESCE(ENCXP, 0) = 1 THEN 1 ELSE 0 END) AS LINEAS_ENCXP,
       COUNT(*) AS LINEAS
FROM dbo.IMOVH WITH (NOLOCK)
WHERE CNSMOV IN ({",".join(f"N'{m}'" for m in cnsmovs)})
GROUP BY CNSMOV;
"""
                enc_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_enc))
                for er in enc_rows:
                    le = int(er.get("LINEAS_ENCXP") or 0)
                    lt = int(er.get("LINEAS") or 0)
                    if lt > 0 and le == 0:
                        pasos.append(
                            _check(
                                "warn",
                                "IMOVH sin ENCXP",
                                f"CNSMOV={er.get('CNSMOV')}: hay FCXPD pero IMOVH.ENCXP=0 (¿falta reprocesar?).",
                                [er],
                                ["PC-N2", "PC-05"],
                            )
                        )

            sin_cuenta = [r for r in fcxpd_rows if not (r.get("CUENTA_SER") or "").strip()]
            if sin_cuenta:
                pasos.append(
                    _check(
                        "ko",
                        "KMCOM en FCXPD (CUENTA_SER)",
                        f"{len(sin_cuenta)} línea(s) sin CUENTA_SER — revisar KMCOM CXP_COMPRAS.",
                        sin_cuenta[:5],
                        ["PC-N3", "PC-01"],
                    )
                )

            mov_in = ",".join(f"N'{m}'" for m in cnsmovs)
            fcxp_in = ",".join(f"N'{x}'" for x in cnsfcxps)
            q_cuadre = f"""
SET NOCOUNT ON;
SELECT M.CNSMOV,
       ROUND(SUM(COALESCE(H.CANTIDAD, 0) * COALESCE(H.PCOSTO, 0)), 2) AS IMOV_BASE,
       ROUND(SUM(COALESCE(H.VLRIVA, H.IVA, 0)), 2) AS IMOV_IVA,
       (SELECT ROUND(SUM(COALESCE(D.VALOR, 0) * COALESCE(D.CANTIDAD, 0)), 2)
        FROM dbo.FCXPD D WITH (NOLOCK)
        WHERE D.N_PRESUP = M.CNSMOV AND D.CNSFCXP IN ({fcxp_in})) AS FCXPD_BASE,
       (SELECT ROUND(SUM(COALESCE(D.VLR_IVA, 0)), 2)
        FROM dbo.FCXPD D WITH (NOLOCK)
        WHERE D.N_PRESUP = M.CNSMOV AND D.CNSFCXP IN ({fcxp_in})) AS FCXPD_IVA
FROM dbo.IMOV M WITH (NOLOCK)
INNER JOIN dbo.IMOVH H WITH (NOLOCK) ON H.CNSMOV = M.CNSMOV
WHERE M.CNSMOV IN ({mov_in}) AND COALESCE(M.ESTADO, 0) = 1
GROUP BY M.CNSMOV;
"""
            cuadre_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cuadre))
            tol = 1.0
            cuadre_issues: list[str] = []
            for cr in cuadre_rows:
                cm = cr.get("CNSMOV", "")
                try:
                    ib = float(cr.get("IMOV_BASE") or 0)
                    fb = float(cr.get("FCXPD_BASE") or 0)
                    ii = float(cr.get("IMOV_IVA") or 0)
                    fi = float(cr.get("FCXPD_IVA") or 0)
                except (TypeError, ValueError):
                    continue
                if abs(ib - fb) > tol:
                    cuadre_issues.append(f"{cm}: base Δ={ib - fb:.2f}")
                if abs(ii - fi) > tol:
                    cuadre_issues.append(f"{cm}: IVA Δ={ii - fi:.2f}")
            if cuadre_issues:
                pasos.append(
                    _check(
                        "ko",
                        "Cuadre IMOVH ↔ FCXPD",
                        "; ".join(cuadre_issues[:6]),
                        cuadre_rows,
                        ["PC-N5", "PC-05"],
                    )
                )
            elif cuadre_rows:
                pasos.append(
                    _check(
                        "ok",
                        "Cuadre IMOVH ↔ FCXPD",
                        f"{len(cuadre_rows)} movimiento(s) dentro de tolerancia {tol} peso(s).",
                        cuadre_rows,
                        ["PC-N5"],
                    )
                )

            for fx in fcxp_rows:
                cns = _esc(fx.get("CNSFCXP", ""))
                if not cns:
                    continue
                q_fcxp_sum = f"""
SET NOCOUNT ON;
SELECT
  (SELECT COALESCE(VLR_NETO, 0) FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCXP = N'{cns}') AS FCXP_NETO,
  (SELECT COALESCE(VLR_IVA, 0) FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCXP = N'{cns}') AS FCXP_IVA,
  (SELECT ROUND(SUM(COALESCE(VLR_NETO, 0)), 2) FROM dbo.FCXPD WITH (NOLOCK) WHERE CNSFCXP = N'{cns}') AS SUM_DET_NETO,
  (SELECT ROUND(SUM(COALESCE(VLR_IVA, 0)), 2) FROM dbo.FCXPD WITH (NOLOCK) WHERE CNSFCXP = N'{cns}') AS SUM_DET_IVA;
"""
                sum_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcxp_sum))
                if sum_rows:
                    sr = sum_rows[0]
                    try:
                        fn = float(sr.get("FCXP_NETO") or 0)
                        sn = float(sr.get("SUM_DET_NETO") or 0)
                        if abs(fn - sn) > tol:
                            pasos.append(
                                _check(
                                    "warn",
                                    "Cuadre FCXP cabecera ↔ detalle",
                                    f"CNSFCXP={fx.get('CNSFCXP')}: VLR_NETO cabecera vs Σ FCXPD (Δ {fn - sn:.2f}). ¿Flete/anticipo?",
                                    sum_rows,
                                    ["PC-N5"],
                                )
                            )
                    except (TypeError, ValueError):
                        pass

    # --- FCXPI ---
    if cnsfcxps:
        q_fcxpi = f"""
SET NOCOUNT ON;
SELECT CNSFCXP, COUNT(*) AS RETENCIONES, SUM(COALESCE(VALOR,0)) AS VLR_RET
FROM dbo.FCXPI WITH (NOLOCK) WHERE CNSFCXP IN ({",".join(f"N'{x}'" for x in cnsfcxps)}) GROUP BY CNSFCXP;
"""
        fcxpi = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcxpi))
        pasos.append(_check("ok" if fcxpi else "warn", "Impuestos CxP (FCXPI)", "Retenciones registradas." if fcxpi else "Sin FCXPI (puede ser normal).", fcxpi, ["PC-06"]))

    # --- MCP CXP ---
    if cnsfcxps:
        q_mcp = f"""
SET NOCOUNT ON;
SELECT REFERENCIA1 AS CNSFCXP, NROCOMPROBANTE, PROCEDENCIA, CONTABILIZADA, FECHA,
       (SELECT SUM(DEBITO)-SUM(CREDITO) FROM dbo.MCHE WITH (NOLOCK) WHERE MCHE.NROCOMPROBANTE = MCP.NROCOMPROBANTE) AS DIFERENCIA
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXP' AND REFERENCIA1 IN ({",".join(f"N'{x}'" for x in cnsfcxps)});
"""
        mcp_cxp = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp))
        if not mcp_cxp:
            pasos.append(_check("warn", "Comprobante contable CxP", "Sin MCP PROCEDENCIA=CXP.", [], ["PC-07"]))
        else:
            for m in mcp_cxp:
                dif = float(m.get("DIFERENCIA") or 0)
                st = "ok" if abs(dif) < 0.02 else "ko"
                pasos.append(_check(st, "Comprobante contable CxP", f"NRO {m.get('NROCOMPROBANTE')} dif={dif:.2f}", [m], ["PC-07"]))

    # --- MCP INV mismo movimiento ---
    if cnsmovs:
        q_mcp_inv = f"""
SET NOCOUNT ON;
SELECT REFERENCIA_PRO AS CNSMOV, NROCOMPROBANTE, PROCEDENCIA
FROM dbo.MCHE WITH (NOLOCK)
WHERE PROCEDENCIA = N'INV' AND REFERENCIA_PRO IN ({",".join(f"N'{m}'" for m in cnsmovs)});
"""
        mcp_inv = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp_inv))
        if mcp_inv and fcxp_rows and any((r.get("CONTABILIZADA") or "0") != "0" for r in fcxp_rows):
            pasos.append(_check("warn", "Contabilidad inventario mismo movimiento", "Hay MCHE INV para CNSMOV de compra y CxP contabilizada — revisar doble costo.", mcp_inv, ["PC-08"]))
        elif mcp_inv:
            pasos.append(_check("ok", "Contabilidad inventario (entrada)", "MCP INV presente.", mcp_inv, ["PC-08"]))
        else:
            pasos.append(_check("ok", "Contabilidad inventario (entrada)", "Sin MCP INV en entradas (habitual si solo CxP).", [], ["PC-08"]))

    # --- Orden de pago / caja ---
    if cnsfcxps:
        q_fcxpp = f"""
SET NOCOUNT ON;
SELECT FCXPP.CNSFCXPP, FCXPP.CNSFCXPPM, FCXPP.CNSFCXP, FCXPP.VALOR, FCXPP.ESTADO,
       FCXPP.CODCAJA, FCXPP.CNSFACJ, FCXPPM.ESTADO AS ESTADO_PM
FROM dbo.FCXPP WITH (NOLOCK)
INNER JOIN dbo.FCXPPM WITH (NOLOCK) ON FCXPPM.CNSFCXPPM = FCXPP.CNSFCXPPM
WHERE FCXPP.CNSFCXP IN ({",".join(f"N'{x}'" for x in cnsfcxps)})
  AND COALESCE(FCXPP.ESTADO,'') <> 'A';
"""
        fcxpp = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcxpp))
        if not fcxpp:
            saldo_pos = any(float(r.get("SALDO") or 0) > 0.01 for r in fcxp_rows)
            pasos.append(_check("warn" if saldo_pos else "ok", "Orden de pago (FCXPP)", "Sin abonos OP." if saldo_pos else "CxP sin saldo pendiente.", [], ["PC-09"]))
        else:
            pasos.append(_check("ok", "Orden de pago (FCXPP)", f"{len(fcxpp)} registro(s).", fcxpp, ["PC-09"]))
            cnsfacjs = list({r.get("CNSFACJ") for r in fcxpp if r.get("CNSFACJ")})
            if cnsfacjs:
                in_f = ",".join(f"N'{_esc(x)}'" for x in cnsfacjs)
                q_fcj = f"""
SET NOCOUNT ON;
SELECT CNSFACJ, CODCAJA, CERRADA, VALORTOTAL, FECHA, PROCEDENCIA
FROM dbo.FCJ WITH (NOLOCK) WHERE CNSFACJ IN ({in_f});
"""
                fcj = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcj))
                for f in fcj:
                    cerr = (f.get("CERRADA") or "0").strip()
                    st = "ok" if cerr in ("1", "S") else "warn"
                    pasos.append(_check(st, "Recibo caja (egreso)", f"CNSFACJ={f.get('CNSFACJ')} CERRADA={cerr}.", [f], ["PC-10"]))
                q_mcp_caj = f"""
SET NOCOUNT ON;
SELECT REFERENCIA1 AS CNSFACJ, NROCOMPROBANTE, PROCEDENCIA, CONTABILIZADA
FROM dbo.MCP WITH (NOLOCK) WHERE PROCEDENCIA = N'CAJA' AND REFERENCIA1 IN ({in_f});
"""
                mcp_caj = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp_caj))
                if fcj and all((f.get("CERRADA") or "0") in ("1", "S") for f in fcj) and not mcp_caj:
                    pasos.append(_check("warn", "Contabilidad caja", "Egreso confirmado sin MCP CAJA visible.", [], ["PC-10"]))
                elif mcp_caj:
                    pasos.append(_check("ok", "Contabilidad caja", "MCP CAJA encontrado.", mcp_caj, ["PC-10"]))

    # --- Salidas posteriores (mismo artículo / bodega OC) — opcional resumen ---
    if cnsmovs and fcom.get("IDBODEGA"):
        bod = _esc(fcom.get("IDBODEGA"))
        q_sal = f"""
SET NOCOUNT ON;
SELECT TOP 5 CNSMOV, ESTADO, FECHA, TIPO, VR_TOTAL
FROM dbo.IMOV WITH (NOLOCK)
WHERE IDBODEGA = N'{bod}' AND TIPO IN (N'S', N'SA') AND FECHA >= (SELECT MIN(FECHA) FROM dbo.IMOV WITH (NOLOCK) WHERE CNSFCOM = N'{esc}')
ORDER BY FECHA DESC;
"""
        sal_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sal))
        pasos.append(_check("ok", "Salidas inventario (muestra)", "Últimas salidas en bodega tras OC (referencia).", sal_rows, ["PC-11", "PC-12"]))

    if fcxp_rows:
        seen_fcxp_doc: set[str] = set()
        for fx in fcxp_rows:
            cns_cxp = (fx.get("CNSFCXP") or "").strip()
            if not cns_cxp or cns_cxp in seen_fcxp_doc:
                continue
            seen_fcxp_doc.add(cns_cxp)
            pasos.extend(
                _pasos_from_grafo_checks(
                    _checks_documento_cnsfcxp(server, user, pwd, db, cns_cxp),
                    titulo_prefix="Grafo CxP",
                    default_pc=["PC-07", "PC-CXP-01"],
                )
            )
        if cnsmovs:
            pasos.extend(
                _pasos_from_grafo_checks(
                    _checks_documento_cnsmov(server, user, pwd, db, cnsmovs[0]),
                    titulo_prefix="Grafo INV",
                    default_pc=["PC-08", "PC-INV-01"],
                )
            )

    resumen = {"ok": 0, "warn": 0, "ko": 0}
    for p in pasos:
        resumen[p["estado"]] = resumen.get(p["estado"], 0) + 1

    return {
        "ok": True,
        "flujoId": "flujo-compras-inv-cxp-caja",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnsfcom": cns,
        "parametroEntrada": parametro,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_soporte(),
    }


def meta_runbook_recaudos() -> dict:
    return {
        "titulo": "Runbook soporte recaudos cartera",
        "archivo": "RUNBOOK-SOPORTE-RECAUDOS.md",
        "rutaRelativa": "conocimiento/flujo-recaudos-cartera-contab/RUNBOOK-SOPORTE-RECAUDOS.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-recaudos-cartera-contab",
    }


def meta_runbook_radicacion() -> dict:
    return {
        "titulo": "Radicación CxC — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-rad-cxc-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-rad-cxc-contab",
    }


def leer_runbook_radicacion_markdown() -> str:
    path = RAD_CXC_DIR / "PROCESO.md"
    if not path.is_file():
        raise FileNotFoundError("PROCESO.md radicación no encontrado")
    return path.read_text(encoding="utf-8")


def meta_runbook_bmov() -> dict:
    return {
        "titulo": "Movimiento banco — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-bmov-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-bmov-contab",
    }


def leer_runbook_bmov_markdown() -> str:
    path = BMOV_DIR / "PROCESO.md"
    if not path.is_file():
        raise FileNotFoundError("PROCESO.md BMOV no encontrado")
    return path.read_text(encoding="utf-8")


def meta_runbook_nomina() -> dict:
    return {
        "titulo": "Nómina — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-nomina-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-nomina-contab",
    }


def meta_runbook_anticipos() -> dict:
    return {
        "titulo": "Anticipos — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-anticipos-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-anticipos-contab",
    }


def meta_runbook_iact() -> dict:
    return {
        "titulo": "Activos (IACT) — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-iact-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-iact-contab",
    }


def meta_runbook_legalizacion() -> dict:
    return {
        "titulo": "Legalización caja menor — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-legalizacion-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-legalizacion-contab",
    }


def meta_runbook_cesiones() -> dict:
    return {
        "titulo": "Cesiones cartera — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-cesiones-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-cesiones-contab",
    }


def meta_runbook_ajdep() -> dict:
    return {
        "titulo": "Depreciación activos — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-ajdep-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-ajdep-contab",
    }


def meta_runbook_reversos() -> dict:
    return {
        "titulo": "Reversión comprobante — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-reversos-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-reversos-contab",
    }


def meta_runbook_cierre_periodo() -> dict:
    return {
        "titulo": "Cierre periodo (Fase 2) — notas de traza",
        "archivo": "PROCESO.md",
        "rutaRelativa": "conocimiento/flujo-cierre-periodo-contab/PROCESO.md",
        "urlMarkdown": "/api/auditoria/runbook?flujoId=flujo-cierre-periodo-contab",
    }


def _leer_proceso_md(flujo_dir: Path) -> str:
    path = flujo_dir / "PROCESO.md"
    if not path.is_file():
        raise FileNotFoundError(f"PROCESO.md no encontrado en {flujo_dir.name}")
    return path.read_text(encoding="utf-8")


def leer_runbook_recaudos_markdown() -> str:
    if not RUNBOOK_RECAUDOS_MD.is_file():
        raise FileNotFoundError("RUNBOOK-SOPORTE-RECAUDOS.md no encontrado")
    return RUNBOOK_RECAUDOS_MD.read_text(encoding="utf-8")


def cargar_flujo_documentacion(flujo_id: str = "flujo-compras-inv-cxp-caja") -> dict:
    fdir = FLUJO_IDS.get(flujo_id) or FLUJO_DIR
    base = {
        "proceso": _read_json(fdir / "proceso.json"),
        "puntosCriticos": _read_json(fdir / "puntos-criticos.json"),
        "ayudaPc": _load_ayuda_pc_map(),
    }
    if flujo_id == "flujo-compras-inv-cxp-caja":
        base["usvgsInventario"] = _read_json(FLUJO_DIR / "usvgs-inventario.json")
        base["runbook"] = meta_runbook_soporte()
    elif flujo_id == "flujo-recaudos-cartera-contab":
        base["runbook"] = meta_runbook_recaudos()
    elif flujo_id == "flujo-rad-cxc-contab":
        base["runbook"] = meta_runbook_radicacion()
    elif flujo_id == "flujo-bmov-contab":
        base["runbook"] = meta_runbook_bmov()
    elif flujo_id == "flujo-nomina-contab":
        base["runbook"] = meta_runbook_nomina()
    elif flujo_id == "flujo-anticipos-contab":
        base["runbook"] = meta_runbook_anticipos()
    elif flujo_id == "flujo-iact-contab":
        base["runbook"] = meta_runbook_iact()
    elif flujo_id == "flujo-legalizacion-contab":
        base["runbook"] = meta_runbook_legalizacion()
    elif flujo_id == "flujo-cesiones-contab":
        base["runbook"] = meta_runbook_cesiones()
    elif flujo_id == "flujo-ajdep-contab":
        base["runbook"] = meta_runbook_ajdep()
    elif flujo_id == "flujo-reversos-contab":
        base["runbook"] = meta_runbook_reversos()
    elif flujo_id == "flujo-cierre-periodo-contab":
        base["runbook"] = meta_runbook_cierre_periodo()
    else:
        base["runbook"] = meta_runbook_soporte()
    return base


_USVGS_SQL_REFS: dict | None = None

# Tipos de validación cruzada (tabla maestra esperada)
_USVGS_ITMO = {
    "IDINVMOV_COMPRAS",
    "IDINVMOV_PRESTAMOS",
    "IDINVMOV_REMISION_EN",
    "IDINVMOV_SI",
    "IDINVTPROPIA",
    "IDTS",
    "IDTE",
    "IDINVMOV_VENTAS",
    "IDINVMOVVENTAFACTURA",
    "INVE_CIRU_TIPO_MOV",
    "FAR_MOVANULASALIDA",
    "IDINVENTXOBSEQUIOS",
    "IDINVTFSA",
    "IDINVTRASLACTIVOS",
}
_USVGS_IBOD = {"IDBOD_HEMODERIVADOS"}
_USVGS_ITAR = {"IDITARHEMODERIVADOS", "IDITARUNIDOSIS"}
_USVGS_IART = {"DEINVNODESER"}
_USVGS_FLAGS = {
    "VALID_CCOSTO_CXP",
    "TRAN_EDIT_OC",
    "CONTAB_INV_IVA_ITAR",
    "CUENTA_IVA_CXP",
    "REDONDEO_COMPRAS_CXP",
    "COLOCAR_TOTAL_IMOV",
    "CODIGOUNICOICBU",
    "MOV_PERIODOS_ANT",
    "ASI_VAL_CCAF_CARGOS",
    "IMPUESTO_OBL",
    "ESFARMACIA",
    "MVIGENCIAIZSOL",
    "IZSOL_MED_SOLI",
    "IENF_RECIBE_INSUMOS",
    "VALIDA_INVI",
    "VALID_INVIMA_HEMO",
    "ANULA_TRANSITO_SINEN",
    "CONTABIMOV_JOB",
}
_USVGS_ENTEROS = {
    "IDINVDIASPARAVENCER",
    "NDIASANTESVENCE",
    "HVIGENCIAIZSOL",
    "NRO_ESPACIOS_ITARCNS",
}

_IMPACTO_SI_CAMBIA: dict[str, str] = {
    "IDINVMOV_COMPRAS": "Cambia qué ITRA/IMOV se tratan como compra: OCs en tránsito, CONF_ENTRADA, recepción masiva y auditoría PC-N1 dejan de cuadrar con ITMO anterior.",
    "VALID_CCOSTO_CXP": "Activa/desactiva bloqueo KMCOM CXP_COMPRAS en CONF_ENTRADA; impacto inmediato en entradas confirmadas, no en histórico FCXPD.",
    "IDMODELOCONTABLE": "Todas las cuentas FNK_CUENTA_KMCOM (inventario, CxP, IVA) usan otro modelo; riesgo masivo en nuevos IMOV/FCXPD/MCP.",
    "CONTAB_INV_IVA_ITAR": "Altera armado de VLR_IVA/CUENTA_IVA en FCXPD vs IMOVH; cuadre CxP y contabilización.",
    "REDONDEO_COMPRAS_CXP": "Centavos de diferencia IMOVH↔FCXPD en PROCESAR_IMOVH; puede pasar/fallar cuadre según redondeo.",
    "DEINVNODESER": "Rompe VALIDA_SERVICIO y artículos sin SER; no afecta movimientos ya grabados.",
    "IDBOD_HEMODERIVADOS": "Reglas de lote/vencimiento/INVIMA en tránsito y dispensación dejan de aplicar al cambiar bodega.",
    "IDINVTPROPIA": "Entradas propias/paciente y custodia IMOV; exige CNSTRAN según tipo.",
}


def _usvgs_sql_refs() -> dict[str, list]:
    global _USVGS_SQL_REFS
    if _USVGS_SQL_REFS is None:
        _USVGS_SQL_REFS = _read_json(FLUJO_DIR / "usvgs-sql-refs.json", {})
    return _USVGS_SQL_REFS


def _usvgs_catalogo_flat() -> list[dict]:
    cat = _read_json(FLUJO_DIR / "usvgs-inventario.json", {})
    out: list[dict] = []
    for g in cat.get("grupos") or []:
        for v in g.get("variables") or []:
            out.append(
                {
                    **v,
                    "grupo": g.get("nombre"),
                    "grupoId": g.get("id"),
                }
            )
    return out


def _usvgs_estado_flag(dato: str, critico: bool) -> tuple[str, str]:
    up = (dato or "").strip().upper()
    if up in ("SI", "NO", "S", "N"):
        return "ok", f"Flag {up}"
    if not up:
        return ("ko", "Vacío") if critico else ("warn", "Vacío (opcional)")
    return "ok", f"Valor literal: {dato.strip()}"


def validar_usvgs_inventario(servidor_id: str, base_datos: str) -> dict:
    """Valida USVGS de inventario/compras contra tablas maestras (solo SELECT)."""
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    catalogo = _usvgs_catalogo_flat()
    refs_map = _usvgs_sql_refs()
    ids = [v["id"] for v in catalogo]
    if not ids:
        raise ValueError("Catálogo USVGS vacío")

    in_list = ",".join(f"N'{_esc(i)}'" for i in ids)
    q_us = (
        "SET NOCOUNT ON; SELECT IDVARIABLE, LTRIM(RTRIM(DATO)) AS DATO "
        f"FROM dbo.USVGS WITH (NOLOCK) WHERE IDVARIABLE IN ({in_list});"
    )
    dato_map = {r["IDVARIABLE"]: (r.get("DATO") or "") for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_us))}

    itmo_need = {
        (dato_map.get(vid) or "").strip()
        for vid in _USVGS_ITMO
        if (dato_map.get(vid) or "").strip()
    }
    ibod_need = {(dato_map.get(v) or "").strip() for v in _USVGS_IBOD if (dato_map.get(v) or "").strip()}
    itar_need = {(dato_map.get(v) or "").strip() for v in _USVGS_ITAR if (dato_map.get(v) or "").strip()}
    iart_need = {(dato_map.get(v) or "").strip() for v in _USVGS_IART if (dato_map.get(v) or "").strip()}

    itmo_map: dict[str, dict] = {}
    if itmo_need:
        inl = ",".join(f"N'{_esc(x)}'" for x in sorted(itmo_need))
        q = (
            "SET NOCOUNT ON; SELECT IDTIPOMOV, LTRIM(RTRIM(TIPO)) AS TIPO, "
            f"COMPRAS, ESACTIVO, DESCRIPCION FROM dbo.ITMO WITH (NOLOCK) WHERE IDTIPOMOV IN ({inl});"
        )
        for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q)):
            itmo_map[r["IDTIPOMOV"]] = r

    ibod_ok: set[str] = set()
    if ibod_need:
        inl = ",".join(f"N'{_esc(x)}'" for x in sorted(ibod_need))
        q = f"SET NOCOUNT ON; SELECT IDBODEGA FROM dbo.IBOD WITH (NOLOCK) WHERE IDBODEGA IN ({inl});"
        ibod_ok = {r["IDBODEGA"] for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))}

    itar_ok: set[str] = set()
    if itar_need:
        inl = ",".join(f"N'{_esc(x)}'" for x in sorted(itar_need))
        q = f"SET NOCOUNT ON; SELECT IDITAR FROM dbo.ITAR WITH (NOLOCK) WHERE IDITAR IN ({inl});"
        itar_ok = {r["IDITAR"] for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))}

    iart_ok: set[str] = set()
    if iart_need:
        inl = ",".join(f"N'{_esc(x)}'" for x in sorted(iart_need))
        q = f"SET NOCOUNT ON; SELECT IDARTICULO FROM dbo.IART WITH (NOLOCK) WHERE IDARTICULO IN ({inl});"
        iart_ok = {r["IDARTICULO"] for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))}

    modelo = (dato_map.get("IDMODELOCONTABLE") or "").strip()
    kmco_ok = False
    kmcom_cxp = 0
    if modelo:
        qm = f"SET NOCOUNT ON; SELECT TOP 1 IDMODELOCONT FROM dbo.KMCO WITH (NOLOCK) WHERE IDMODELOCONT = N'{_esc(modelo)}';"
        kmco_ok = bool(_parse_tsv(_sqlcmd_query(server, user, pwd, db, qm)))
        qc = (
            "SET NOCOUNT ON; SELECT COUNT(*) AS N FROM dbo.KMCOM WITH (NOLOCK) "
            f"WHERE IDMODELOCONT = N'{_esc(modelo)}' AND IDTIPOCONT = N'CXP_COMPRAS';"
        )
        rows_c = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qc))
        if rows_c:
            try:
                kmcom_cxp = int(rows_c[0].get("N") or 0)
            except ValueError:
                kmcom_cxp = 0

    variables: list[dict] = []
    resumen = {"ok": 0, "warn": 0, "ko": 0}

    for meta in catalogo:
        vid = meta["id"]
        critico = bool(meta.get("critico"))
        dato = dato_map.get(vid)
        refs = refs_map.get(vid) or []
        impacto = _IMPACTO_SI_CAMBIA.get(vid) or (
            f"Afecta rutas SQL documentadas en BA ({len(refs)} script(s) en sql/). "
            "Cambiar sin alinear ITMO/IBOD/KMCOM puede romper flujos nuevos, no datos históricos."
        )

        if dato is None:
            estado, validacion = ("ko", "Sin fila en USVGS") if critico else ("warn", "Sin fila en USVGS")
        elif not str(dato).strip():
            estado, validacion = ("ko", "DATO vacío") if critico else ("warn", "DATO vacío")
        elif vid in _USVGS_ITMO:
            t = itmo_map.get(dato.strip())
            if not t:
                estado, validacion = "ko", f"ITMO {dato} no existe"
            else:
                issues = []
                if vid == "IDINVMOV_COMPRAS":
                    if (t.get("TIPO") or "").lower() != "credito":
                        issues.append("TIPO≠Crédito")
                    if str(t.get("COMPRAS") or "") not in ("1", "True", "true"):
                        issues.append("COMPRAS≠1")
                if vid == "INVE_CIRU_TIPO_MOV" and (t.get("TIPO") or "").lower() != "debito":
                    issues.append("TIPO≠Débito")
                if str(t.get("ESACTIVO") or "") in ("0", "False", "false"):
                    issues.append("ITMO inactivo")
                if issues:
                    estado, validacion = "warn", "; ".join(issues) + f" — {t.get('DESCRIPCION', '')}"
                else:
                    estado, validacion = "ok", f"ITMO OK ({t.get('TIPO')}) {t.get('DESCRIPCION', '')}"
        elif vid in _USVGS_IBOD:
            estado, validacion = (
                ("ok", "IBOD existe") if dato.strip() in ibod_ok else ("ko", f"IBOD {dato} no existe")
            )
        elif vid in _USVGS_ITAR:
            estado, validacion = (
                ("ok", "ITAR existe") if dato.strip() in itar_ok else ("ko", f"ITAR {dato} no existe")
            )
        elif vid in _USVGS_IART:
            estado, validacion = (
                ("ok", "IART placeholder existe") if dato.strip() in iart_ok else ("ko", f"IART {dato} no existe")
            )
        elif vid == "IDMODELOCONTABLE":
            if not kmco_ok:
                estado, validacion = "ko", f"KMCO {dato} no existe"
            elif kmcom_cxp <= 0:
                estado, validacion = "warn", f"KMCO OK; sin filas KMCOM CXP_COMPRAS ({kmcom_cxp})"
            else:
                estado, validacion = "ok", f"KMCO OK; KMCOM CXP_COMPRAS={kmcom_cxp} filas (muestra)"
        elif vid in _USVGS_FLAGS:
            estado, validacion = _usvgs_estado_flag(dato, critico)
        elif vid in _USVGS_ENTEROS:
            try:
                int(dato.strip())
                estado, validacion = "ok", "Numérico OK"
            except ValueError:
                estado, validacion = "warn", "No es entero válido"
        else:
            estado, validacion = "ok", "Configurado (sin regla cruzada)"

        resumen[estado] = resumen.get(estado, 0) + 1
        variables.append(
            {
                "id": vid,
                "grupo": meta.get("grupo"),
                "grupoId": meta.get("grupoId"),
                "dato": dato if dato is not None else "",
                "estado": estado,
                "validacion": validacion,
                "paraQue": meta.get("paraQue"),
                "donde": meta.get("donde"),
                "sqlRefs": refs,
                "impactoSiCambia": impacto,
                "critico": critico,
            }
        )

    return {
        "ok": True,
        "flujoId": "flujo-compras-inv-cxp-caja",
        "servidor": servidor_id,
        "baseDatos": db,
        "variables": variables,
        "resumen": resumen,
        "nota": "sqlRefs = scripts en QrystalosBA/sql/ (referencia PREVERSION); un cambio de USVGS exige probar esos SP en preversión.",
    }


def mapa_movimientos_inventario(servidor_id: str, base_datos: str) -> dict:
    """ITMO del cliente mapeado a familias normalizadas + muestra KMCOM MOV_INVENTARIO."""
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    catalog = _read_json(INVENTARIO_DIR / "catalogo-movimientos-inventario.json", {})
    familias = catalog.get("familias") or []

    usvgs_to_fam: dict[str, dict] = {}
    for fam in familias:
        for u in fam.get("usvgs") or []:
            usvgs_to_fam[u] = fam

    usvgs_ids = sorted(usvgs_to_fam.keys())
    dato_map: dict[str, str] = {}
    if usvgs_ids:
        in_list = ",".join(f"N'{_esc(i)}'" for i in usvgs_ids)
        q_us = (
            "SET NOCOUNT ON; SELECT IDVARIABLE, LTRIM(RTRIM(DATO)) AS DATO "
            f"FROM dbo.USVGS WITH (NOLOCK) WHERE IDVARIABLE IN ({in_list});"
        )
        dato_map = {r["IDVARIABLE"]: (r.get("DATO") or "") for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_us))}

    q_itmo = (
        "SET NOCOUNT ON; SELECT IDTIPOMOV, LTRIM(RTRIM(DESCRIPCION)) AS DESCRIPCION, "
        "LTRIM(RTRIM(TIPO)) AS TIPO, COMPRAS, SECONTABILIZA, ESACTIVO, MPROVEEDOR "
        "FROM dbo.ITMO WITH (NOLOCK) ORDER BY TIPO, IDTIPOMOV;"
    )
    itmo_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_itmo))
    itmo_by_id = {r["IDTIPOMOV"]: r for r in itmo_rows}

    modelo = (dato_map.get("IDMODELOCONTABLE") or "").strip()
    if not modelo:
        q_mod = "SET NOCOUNT ON; SELECT TOP 1 LTRIM(RTRIM(DATO)) AS DATO FROM dbo.USVGS WHERE IDVARIABLE = N'IDMODELOCONTABLE';"
        rows_m = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mod))
        if rows_m:
            modelo = (rows_m[0].get("DATO") or "").strip()

    kmcom_prefijos: set[str] = set()
    if modelo:
        q_k = (
            "SET NOCOUNT ON; SELECT DISTINCT LTRIM(RTRIM(PREFIJO)) AS PREFIJO FROM dbo.KMCOM WITH (NOLOCK) "
            f"WHERE IDMODELOCONT = N'{_esc(modelo)}' AND IDTIPOCONT = N'MOV_INVENTARIO';"
        )
        kmcom_prefijos = {r["PREFIJO"] for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_k)) if r.get("PREFIJO")}

    # Mapeo USVGS → ITMO (familias conocidas)
    filas_familia: list[dict] = []
    resumen = {"ok": 0, "warn": 0, "ko": 0}
    tipomov_asignados: set[str] = set()

    for u, fam in usvgs_to_fam.items():
        dato = (dato_map.get(u) or "").strip()
        fam_id = fam.get("id") or ""
        if not dato:
            estado, det = "warn", "USVGS vacía o sin fila"
            itmo = None
        else:
            itmo = itmo_by_id.get(dato)
            tipomov_asignados.add(dato)
            if not itmo:
                estado, det = "ko", f"ITMO {dato} no existe"
            else:
                issues = []
                esp = fam.get("itmoEsperado") or {}
                if esp.get("tipo") and (itmo.get("TIPO") or "").lower() != str(esp["tipo"]).lower():
                    issues.append(f"TIPO esperado {esp['tipo']}, tiene {itmo.get('TIPO')}")
                if esp.get("compras") and str(itmo.get("COMPRAS") or "") not in ("1", "True", "true"):
                    issues.append("COMPRAS≠1")
                if str(itmo.get("ESACTIVO") or "") in ("0", "False", "false"):
                    issues.append("ITMO inactivo")
                sec = str(itmo.get("SECONTABILIZA") or "")
                if sec in ("1", "True", "true") and modelo and dato not in kmcom_prefijos:
                    issues.append("SECONTABILIZA sin KMCOM MOV_INVENTARIO (muestra PREFIJO=IDTIPOMOV)")
                if issues:
                    estado, det = "warn", "; ".join(issues)
                else:
                    estado, det = "ok", "Alineado"
        resumen[estado] = resumen.get(estado, 0) + 1
        cont = fam.get("contabilidad") or {}
        filas_familia.append(
            {
                "familiaNorm": fam_id,
                "familiaNombre": fam.get("nombre"),
                "usvgs": u,
                "idtipomov": dato,
                "estado": estado,
                "validacion": det,
                "itmo": itmo,
                "omInv": cont.get("omInv"),
                "kmcomProceso": cont.get("kmcomProceso"),
                "notasContables": cont.get("notas"),
            }
        )

    # ITMO activos no referenciados por USVGS del catálogo
    otros: list[dict] = []
    for tid, itmo in itmo_by_id.items():
        if tid in tipomov_asignados:
            continue
        if str(itmo.get("ESACTIVO") or "") in ("0", "False", "false"):
            continue
        sec = str(itmo.get("SECONTABILIZA") or "")
        estado = "ok"
        det = "Tipo manual / sin USVGS en catálogo BA"
        if sec in ("1", "True", "true") and modelo and tid not in kmcom_prefijos:
            estado, det = "warn", "SECONTABILIZA=1 sin filas KMCOM MOV_INVENTARIO para este IDTIPOMOV"
        resumen[estado] = resumen.get(estado, 0) + 1
        otros.append(
            {
                "idtipomov": tid,
                "descripcion": itmo.get("DESCRIPCION"),
                "tipo": itmo.get("TIPO"),
                "seContabiliza": itmo.get("SECONTABILIZA"),
                "estado": estado,
                "validacion": det,
            }
        )

    return {
        "ok": True,
        "baseDatos": db,
        "idModeloContable": modelo,
        "familiasUsvgs": filas_familia,
        "itmoSinUsvgsCatalogo": otros,
        "resumen": resumen,
        "documento": "conocimiento/inventario/MOVIMIENTOS-INVENTARIO.md",
        "invariantes": catalog.get("invariantesContables"),
    }


def _resumen_pasos(pasos: list[dict]) -> dict:
    resumen = {"ok": 0, "warn": 0, "ko": 0}
    for p in pasos:
        resumen[p["estado"]] = resumen.get(p["estado"], 0) + 1
    return resumen


def trazar_recaudos(
    servidor_id: str,
    base_datos: str,
    cnsfpag: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = (cnsfpag or "").strip()
    if not cns:
        return {
            "ok": False,
            "error": "Indique CNSFPAG.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }

    esc = _esc(cns)
    pasos: list[dict] = []

    q_fpag = f"""
SET NOCOUNT ON;
SELECT F.CNSFPAG, F.INGRESO, CAST(COALESCE(F.FINDEVOL, 0) AS INT) AS FINDEVOL,
       F.IDTERCERO, T.NIT, T.RAZONSOCIAL,
       CAST(COALESCE(F.CERRADO, 0) AS INT) AS CERRADO,
       LTRIM(RTRIM(COALESCE(F.ESTADO, ''))) AS ESTADO,
       CAST(COALESCE(F.VALORPAGO, 0) AS DECIMAL(18,2)) AS VALORPAGO,
       CAST(COALESCE(F.VLRITEMS, 0) AS DECIMAL(18,2)) AS VLRITEMS,
       CAST(COALESCE(F.VLRAJUSTEPESO, 0) AS DECIMAL(18,2)) AS VLRAJUSTEPESO,
       F.FECHAPAGO, F.FECHA,
       CAST(COALESCE(F.CONTABILIZADO, 0) AS INT) AS CONTABILIZADO,
       LTRIM(RTRIM(COALESCE(F.NROCOMPROBANTE, ''))) AS NROCOMPROBANTE,
       CAST(COALESCE(F.NOCONTABILIZA, 0) AS INT) AS NOCONTABILIZA,
       LTRIM(RTRIM(COALESCE(F.CODCAJA, ''))) AS CODCAJA,
       LTRIM(RTRIM(COALESCE(F.CNSFACJ, ''))) AS CNSFACJ,
       LTRIM(RTRIM(COALESCE(F.BANCO, ''))) AS BANCO,
       LTRIM(RTRIM(COALESCE(F.SUCURSAL, ''))) AS SUCURSAL,
       LTRIM(RTRIM(COALESCE(F.CTA_BCO, ''))) AS CTA_BCO,
       CAST(COALESCE(F.ITEM, 0) AS INT) AS ITEM,
       CAST(COALESCE(F.RENGLON, 0) AS INT) AS RENGLON,
       LTRIM(RTRIM(COALESCE(F.AVALCONTABLE, ''))) AS AVALCONTABLE,
       CAST(COALESCE(F.ENAUDIT, 0) AS INT) AS ENAUDIT
FROM dbo.FPAG F WITH (NOLOCK)
LEFT JOIN dbo.TER T WITH (NOLOCK) ON T.IDTERCERO = F.IDTERCERO
WHERE F.CNSFPAG = N'{esc}';
"""
    fpag_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fpag))
    fpag = fpag_rows[0] if fpag_rows else {}
    if not fpag:
        pasos.append(_check("ko", "Recaudo FPAG", f"No existe CNSFPAG={cns}.", pc_ids=["PC-RC-03"]))
        return {
            "ok": False,
            "error": f"No se encontró FPAG «{cns}» en {db}.",
            "flujoId": "flujo-recaudos-cartera-contab",
            "servidor": servidor_id,
            "baseDatos": db,
            "cnsfpag": cns,
            "pasos": pasos,
            "resumen": _resumen_pasos(pasos),
            "runbook": meta_runbook_recaudos(),
        }

    ingreso = (fpag.get("INGRESO") or "").strip().upper()
    cerrado = str(fpag.get("CERRADO") or "0").strip()
    pasos.append(
        _check(
            "ok",
            "Recaudo FPAG",
            f"CNSFPAG={cns} INGRESO={ingreso} FINDEVOL={fpag.get('FINDEVOL', '')} "
            f"CERRADO={cerrado} ESTADO={fpag.get('ESTADO', '')}.",
            fpag_rows,
            ["PC-RC-03"],
        )
    )

    q_usvgs = """
SET NOCOUNT ON;
SELECT IDVARIABLE, LTRIM(RTRIM(COALESCE(DATO, ''))) AS DATO
FROM dbo.USVGS WITH (NOLOCK)
WHERE IDVARIABLE IN (N'REC_VLRMAX_AJUSTE', N'REC_SOLICITA_AVAL');
"""
    usvgs_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_usvgs))
    usvgs_map = {(r.get("IDVARIABLE") or "").strip(): (r.get("DATO") or "").strip() for r in usvgs_rows}
    max_aj = usvgs_map.get("REC_VLRMAX_AJUSTE", "")
    st_usv = "ok"
    det_usv = f"REC_VLRMAX_AJUSTE={max_aj or '—'}; REC_SOLICITA_AVAL={usvgs_map.get('REC_SOLICITA_AVAL', '—')}."
    if ingreso in ("CAJA", "BANCOS", "CXP") and not max_aj:
        st_usv, det_usv = "ko", det_usv + " Falta REC_VLRMAX_AJUSTE (bloquea CAJA/BANCOS/CXP)."
    elif ingreso in ("CAJA", "BANCOS", "CXP") and not max_aj.replace(".", "", 1).isdigit():
        st_usv, det_usv = "warn", det_usv + " Valor no numérico claro."
    pasos.append(_check(st_usv, "Variables USVGS recaudos", det_usv, usvgs_rows, ["PC-RC-01"]))

    q_pri = f"""
SET NOCOUNT ON;
SELECT YEAR(F.FECHAPAGO) AS ANO, MONTH(F.FECHAPAGO) AS MES,
       CAST(COALESCE(P.CERRADO, 0) AS INT) AS PRI_CERRADO,
       CAST(COALESCE(P.CERRADO_CARTERA, 0) AS INT) AS PRI_CERRADO_CARTERA
FROM dbo.FPAG F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK)
  ON P.ANO = YEAR(F.FECHAPAGO) AND P.MES = MONTH(F.FECHAPAGO)
WHERE F.CNSFPAG = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    pri = pri_rows[0] if pri_rows else {}
    pcerr = str(pri.get("PRI_CERRADO") or "0")
    pccar = str(pri.get("PRI_CERRADO_CARTERA") or "0")
    st_pri = "ok"
    det_pri = f"Periodo {pri.get('ANO', '?')}-{pri.get('MES', '?')}: CERRADO={pcerr}, CERRADO_CARTERA={pccar}."
    if pcerr == "1" or pccar == "1":
        if cerrado == "0":
            st_pri = "ko"
            det_pri += " Periodo cerrado: no podrá APLICARPAGO."
        else:
            st_pri = "warn"
            det_pri += " Recaudo cerrado en periodo cerrado (reversos/aval según INGRESO)."
    pasos.append(_check(st_pri, "Periodo contable (FECHAPAGO)", det_pri, pri_rows, ["PC-RC-02", "PC-RC-17"]))

    if ingreso == "CAJA":
        cod = (fpag.get("CODCAJA") or "").strip()
        cfj = (fpag.get("CNSFACJ") or "").strip()
        if not cod or not cfj:
            pasos.append(_check("ko", "Origen caja FCJ", "INGRESO=CAJA sin CODCAJA/CNSFACJ.", fpag_rows, ["PC-RC-04"]))
        else:
            q_fcj = f"""
SET NOCOUNT ON;
SELECT CODCAJA, CNSFACJ,
       CAST(COALESCE(RECAUDO, 0) AS INT) AS RECAUDO,
       CAST(COALESCE(CERRADA, 0) AS INT) AS CERRADA,
       LTRIM(RTRIM(COALESCE(ESTADO, ''))) AS ESTADO,
       CAST(COALESCE(ENPAGOS, 0) AS INT) AS ENPAGOS,
       CAST(COALESCE(CONTABILIZADA, 0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(NROCOMPROBANTE, ''))) AS NROCOMPROBANTE
FROM dbo.FCJ WITH (NOLOCK)
WHERE CODCAJA = N'{_esc(cod)}' AND CNSFACJ = N'{_esc(cfj)}';
"""
            fcj_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fcj))
            if not fcj_rows:
                pasos.append(_check("ko", "Origen caja FCJ", f"Sin FCJ {cod}/{cfj}.", [], ["PC-RC-04"]))
            else:
                fcj = fcj_rows[0]
                issues = []
                if str(fcj.get("RECAUDO")) != "1":
                    issues.append("RECAUDO≠1")
                if str(fcj.get("CERRADA")) != "1":
                    issues.append("no cerrado")
                if (fcj.get("ESTADO") or "").upper() not in ("P", ""):
                    issues.append(f"ESTADO={fcj.get('ESTADO')}")
                st_f = "ok" if not issues else "warn" if str(fcj.get("CERRADA")) == "1" else "ko"
                pasos.append(
                    _check(
                        st_f,
                        "Origen caja FCJ",
                        f"Recibo {cod}/{cfj}: " + ("; ".join(issues) if issues else "elegible."),
                        fcj_rows,
                        ["PC-RC-04", "PC-RC-06"],
                    )
                )
                if cerrado == "1" and str(fpag.get("NOCONTABILIZA")) != "1" and str(fcj.get("CONTABILIZADA")) != "1":
                    pasos.append(
                        _check(
                            "warn",
                            "Contabilidad recibo caja origen",
                            "Recaudo cerrado pero FCJ.CONTABILIZADA≠1 (tesorería).",
                            fcj_rows,
                            ["PC-RC-14"],
                        )
                    )
            q_dup = f"""
SET NOCOUNT ON;
SELECT CNSFPAG, INGRESO, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO
FROM dbo.FPAG WITH (NOLOCK)
WHERE CODCAJA = N'{_esc(cod)}' AND CNSFACJ = N'{_esc(cfj)}'
  AND CNSFPAG <> N'{esc}' AND COALESCE(ESTADO,'') = N'Activo';
"""
            dup_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
            if dup_rows:
                pasos.append(
                    _check(
                        "ko",
                        "Doble enlace mismo recibo",
                        f"Otro(s) FPAG activo(s) con mismo recibo: {len(dup_rows)}.",
                        dup_rows,
                        ["PC-RC-06"],
                    )
                )

    elif ingreso == "BANCOS":
        bco = (fpag.get("BANCO") or "").strip()
        suc = (fpag.get("SUCURSAL") or "").strip()
        cta = (fpag.get("CTA_BCO") or "").strip()
        item = fpag.get("ITEM") or "0"
        ren = fpag.get("RENGLON") or "0"
        q_bm = f"""
SET NOCOUNT ON;
SELECT D.BANCO, D.SUCURSAL, D.CTA_BCO, D.ITEM, D.RENGLON,
       CAST(COALESCE(D.RECAUDO, 0) AS INT) AS RECAUDO,
       CAST(COALESCE(D.ENPAGOS, 0) AS INT) AS ENPAGOS,
       CAST(COALESCE(D.VLRITEM, 0) AS DECIMAL(18,2)) AS VLRITEM,
       CAST(COALESCE(D.VLRLEGALIZADO, 0) AS DECIMAL(18,2)) AS VLRLEGALIZADO,
       LTRIM(RTRIM(COALESCE(M.ESTADO, ''))) AS BMOV_ESTADO
FROM dbo.BMOVD D WITH (NOLOCK)
INNER JOIN dbo.BMOV M WITH (NOLOCK)
  ON M.BANCO = D.BANCO AND M.SUCURSAL = D.SUCURSAL AND M.CTA_BCO = D.CTA_BCO AND M.ITEM = D.ITEM
WHERE D.BANCO = N'{_esc(bco)}' AND D.SUCURSAL = N'{_esc(suc)}' AND D.CTA_BCO = N'{_esc(cta)}'
  AND D.ITEM = {int(item)} AND D.RENGLON = {int(ren)};
"""
        bm_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_bm))
        if not bm_rows:
            pasos.append(_check("ko", "Origen banco BMOVD", "Sin línea BMOVD para llaves del FPAG.", fpag_rows, ["PC-RC-05"]))
        else:
            bm = bm_rows[0]
            saldo = float(bm.get("VLRITEM") or 0) - float(bm.get("VLRLEGALIZADO") or 0)
            issues = []
            if str(bm.get("RECAUDO")) != "1":
                issues.append("RECAUDO≠1")
            if (bm.get("BMOV_ESTADO") or "").upper() not in ("O", ""):
                issues.append(f"BMOV.ESTADO={bm.get('BMOV_ESTADO')}")
            st_b = "ok" if not issues else "warn"
            pasos.append(
                _check(
                    st_b,
                    "Origen banco BMOVD",
                    f"Saldo legalizar≈{saldo:.2f}; ENPAGOS={bm.get('ENPAGOS')}. "
                    + ("; ".join(issues) if issues else "OK."),
                    bm_rows,
                    ["PC-RC-05", "PC-RC-06"],
                )
            )
            if bco and suc and cta:
                ref_bmov = f"{bco}/{suc}/{cta}/{item}"
                pasos.extend(
                    _pasos_from_grafo_checks(
                        _checks_documento_bmov(server, user, pwd, db, ref_bmov),
                        titulo_prefix="Grafo BMOV",
                        default_pc=["PC-BMOV-01", "PC-BMOV-02"],
                    )
                )

    elif ingreso == "CXP":
        q_cxp = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS,
       CAST(COALESCE(SUM(VALORPAGO), 0) AS DECIMAL(18,2)) AS SUMA_CRUCE
FROM dbo.FPAGDCXP WITH (NOLOCK)
WHERE CNSFPAG = N'{esc}';
"""
        cxp_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxp))
        cxp = cxp_rows[0] if cxp_rows else {}
        vitems = float(fpag.get("VLRITEMS") or 0)
        suma = float(cxp.get("SUMA_CRUCE") or 0)
        lineas = int(cxp.get("LINEAS") or 0)
        if lineas == 0:
            pasos.append(_check("warn", "Cruce CxP FPAGDCXP", "Sin líneas de cruce.", cxp_rows, ["PC-RC-10"]))
        elif abs(suma - vitems) > 0.02 and cerrado == "1":
            pasos.append(
                _check(
                    "ko",
                    "Cruce CxP FPAGDCXP",
                    f"SUM cruce={suma} vs VLRITEMS={vitems}.",
                    cxp_rows,
                    ["PC-RC-10"],
                )
            )
        else:
            pasos.append(
                _check(
                    "ok" if abs(suma - vitems) <= 0.02 else "warn",
                    "Cruce CxP FPAGDCXP",
                    f"{lineas} línea(s); SUM={suma}; VLRITEMS={vitems}.",
                    cxp_rows,
                    ["PC-RC-10"],
                )
            )

    q_det = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS,
       CAST(COALESCE(SUM(VALORPAGO), 0) AS DECIMAL(18,2)) AS SUMA_PAGO,
       SUM(CASE WHEN COALESCE(ESTADO,'') = N'Retirada' THEN 1 ELSE 0 END) AS RETIRADAS,
       SUM(CASE WHEN COALESCE(LEVANTADO, 0) = 1 THEN 1 ELSE 0 END) AS LEVANTADAS
FROM dbo.FPAGD WITH (NOLOCK)
WHERE CNSFPAG = N'{esc}';
"""
    det_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_det))
    det = det_rows[0] if det_rows else {}
    lineas_d = int(det.get("LINEAS") or 0)
    suma_d = float(det.get("SUMA_PAGO") or 0)
    vitems = float(fpag.get("VLRITEMS") or 0)
    if lineas_d == 0:
        pasos.append(_check("ko" if cerrado == "1" else "warn", "Detalle FPAGD", "Sin líneas FPAGD.", det_rows, ["PC-RC-07"]))
    else:
        st_d = "ok"
        msg = f"{lineas_d} línea(s); SUM VALORPAGO={suma_d}; VLRITEMS cabecera={vitems}."
        if cerrado == "1" and vitems > 0 and abs(suma_d - vitems) > 0.05:
            st_d, msg = "warn", msg + " Descuadre cabecera vs detalle."
        if int(det.get("RETIRADAS") or 0) > 0:
            st_d = "warn"
            msg += f" Retiradas={det.get('RETIRADAS')}."
        pasos.append(_check(st_d, "Detalle FPAGD", msg, det_rows, ["PC-RC-07", "PC-RC-20"]))

    q_dupf = f"""
SET NOCOUNT ON;
SELECT N_FACTURA, CLASE, COUNT(*) AS CNT
FROM dbo.FPAGD WITH (NOLOCK)
WHERE CNSFPAG = N'{esc}'
GROUP BY N_FACTURA, CLASE
HAVING COUNT(*) > 1;
"""
    dupf_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dupf))
    if dupf_rows:
        pasos.append(
            _check("ko", "Duplicados FPAGD", f"{len(dupf_rows)} par(es) N_FACTURA+CLASE repetido(s).", dupf_rows, ["PC-RC-08"])
        )
    else:
        pasos.append(_check("ok", "Duplicados FPAGD", "Sin duplicados N_FACTURA+CLASE.", [], ["PC-RC-08"]))

    q_imp = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS LINEAS_IMP
FROM dbo.FPAGDI WITH (NOLOCK)
WHERE CNSFPAG = N'{esc}';
"""
    imp_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_imp))
    nimp = int((imp_rows[0] if imp_rows else {}).get("LINEAS_IMP") or 0)
    pasos.append(
        _check(
            "ok" if nimp >= 0 else "warn",
            "Impuestos FPAGDI",
            f"{nimp} línea(s) FPAGDI (validar FIMPDV al aplicar).",
            imp_rows,
            ["PC-RC-09"],
        )
    )

    if ingreso == "GLOSAS":
        fd = fpag.get("FINDEVOL") or "0"
        q_fg = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS FGLO_CNT FROM dbo.FGLO WITH (NOLOCK) WHERE CNSFPAG = N'{esc}';
"""
        fg_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fg))
        cnt_fg = int((fg_rows[0] if fg_rows else {}).get("FGLO_CNT") or 0)
        st_g = "ok"
        msg_g = f"FINDEVOL={fd}; FGLO ligadas={cnt_fg}; ENAUDIT={fpag.get('ENAUDIT', 0)}."
        if cerrado == "1" and cnt_fg == 0 and fd in ("3", "4", "5", "6"):
            st_g = "warn"
            msg_g += " Cerrado sin FGLO (revisar apply)."
        pasos.append(_check(st_g, "Glosas (FINDEVOL / FGLO)", msg_g, fg_rows, ["PC-RC-15"]))

    if ingreso in ("DEVOLUCION", "DEVPAR"):
        fd = fpag.get("FINDEVOL") or "0"
        pasos.append(
            _check(
                "ok",
                "Devolución FINDEVOL",
                f"INGRESO={ingreso}; Paso a seguir={fd} (0=retira, 1=anula, 2=radica).",
                fpag_rows,
                ["PC-RC-16"],
            )
        )

    if ingreso == "LEVANTAMIENTO":
        lev = int(det.get("LEVANTADAS") or 0)
        pasos.append(
            _check(
                "ok" if lev > 0 or cerrado == "0" else "warn",
                "Levantamiento",
                f"Líneas con LEVANTADO=1: {lev}.",
                det_rows,
                ["PC-RC-19"],
            )
        )

    if cerrado == "1":
        pasos.append(_check("ok", "Aplicar (cerrado)", "FPAG.CERRADO=1.", fpag_rows, ["PC-RC-11"]))
    else:
        pasos.append(_check("warn", "Aplicar (cerrado)", "Recaudo aún abierto (CERRADO=0).", fpag_rows, ["PC-RC-11"]))

    nocont = str(fpag.get("NOCONTABILIZA") or "0")
    contab = str(fpag.get("CONTABILIZADO") or "0")
    nro = (fpag.get("NROCOMPROBANTE") or "").strip()
    if nocont == "1":
        pasos.append(_check("ok", "Contabilidad FPAG", "NOCONTABILIZA=1 (sin asiento esperado).", fpag_rows, ["PC-RC-12"]))
    elif cerrado == "1" and contab != "1":
        pasos.append(_check("ko", "Contabilidad FPAG", "Cerrado pero CONTABILIZADO≠1.", fpag_rows, ["PC-RC-12"]))
    elif contab == "1" and not nro:
        pasos.append(_check("warn", "Contabilidad FPAG", "CONTABILIZADO=1 sin NROCOMPROBANTE.", fpag_rows, ["PC-RC-12"]))
    else:
        pasos.append(
            _check(
                "ok" if contab == "1" else "warn",
                "Contabilidad FPAG",
                f"CONTABILIZADO={contab}; NROCOMPROBANTE={nro or '—'}.",
                fpag_rows,
                ["PC-RC-12"],
            )
        )

    if nro and nocont != "1":
        q_mcp = f"""
SET NOCOUNT ON;
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO, 0) AS INT) AS ESTADO,
       ANO, MES, REFERENCIA1, REFERENCIA2, N'OK' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK)
WHERE NROCOMPROBANTE = N'{_esc(nro)}'
UNION ALL
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO, 0) AS INT) AS ESTADO,
       ANO, MES, REFERENCIA1, REFERENCIA2, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK)
WHERE NROCOMPROBANTE = N'{_esc(nro)}';
"""
        mcp_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp))
        if not mcp_rows:
            pasos.append(
                _check("ko", "Comprobante MCP/MCPE", f"NROCOMPROBANTE {nro} no está en MCP ni MCPE.", [], ["PC-RC-13"])
            )
        else:
            row0 = mcp_rows[0]
            origen = row0.get("ORIGEN") or "OK"
            est = str(row0.get("ESTADO") or "")
            proc = row0.get("PROCEDENCIA") or ""
            st_m = "ok"
            if origen == "MCPE" or est == "0":
                st_m = "ko"
            elif est != "2":
                st_m = "warn"
            pasos.append(
                _check(
                    st_m,
                    "Comprobante MCP/MCPE",
                    f"{nro}: {origen}; PROCEDENCIA={proc}; ESTADO={est}.",
                    mcp_rows,
                    ["PC-RC-13"],
                )
            )
    elif cerrado == "1" and nocont != "1":
        q_cxc_ref = f"""
SET NOCOUNT ON;
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXC' AND REFERENCIA1 = N'{esc}'
UNION ALL
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXC' AND REFERENCIA1 = N'{esc}';
"""
        ref_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxc_ref))
        if ref_rows:
            pasos.append(
                _check(
                    "warn",
                    "Comprobante por REFERENCIA1",
                    f"Encontrado comprobante CXC con REFERENCIA1={cns} (FPAG sin NROCOMPROBANTE en cabecera).",
                    ref_rows,
                    ["PC-RC-13"],
                )
            )

    aval = (fpag.get("AVALCONTABLE") or "").strip()
    if ingreso in ("CAJA", "BANCOS") and aval:
        pasos.append(
            _check(
                "warn" if aval == "Pendiente" else "ok",
                "Aval contable",
                f"AVALCONTABLE={aval} (circuito desaplicar periodo cerrado).",
                fpag_rows,
                ["PC-RC-18"],
            )
        )

    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_fpag_grafo(server, user, pwd, db, cns),
            default_pc=["PC-CXC-01"],
        )
    )

    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-recaudos-cartera-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnsfpag": cns,
        "ingreso": ingreso,
        "parametroEntrada": cns,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_recaudos(),
    }


def trazar_radicacion_cxc(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    """Traza radicación CxC por CNSCXC (solo SELECT)."""
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = (parametro or "").strip()
    if not cns:
        return {
            "ok": False,
            "error": "Indique CNSCXC (cuenta de cobro).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }

    esc = _esc(cns)
    pasos: list[dict] = []

    q_gen = f"""
SET NOCOUNT ON;
SELECT
  (SELECT COUNT(*) FROM dbo.FCXCD WITH (NOLOCK) WHERE CNSCXC = N'{esc}') AS N_FCXCD,
  (SELECT COUNT(*) FROM dbo.FCXCD D WITH (NOLOCK)
   INNER JOIN dbo.FPAGD P WITH (NOLOCK) ON P.N_FACTURA = D.N_FACTURA
   WHERE D.CNSCXC = N'{esc}') AS N_CON_FPAGD,
  (SELECT COUNT(*) FROM dbo.FCXCD D WITH (NOLOCK)
   INNER JOIN dbo.FNOT N WITH (NOLOCK) ON N.N_FACTURA = D.N_FACTURA
   WHERE D.CNSCXC = N'{esc}') AS N_CON_FNOT;
"""
    gen_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_gen))
    n_mov = 0
    n_fc = 0
    if gen_rows:
        gr = gen_rows[0]
        n_fc = int(gr.get("N_FCXCD") or 0)
        n_mov = int(gr.get("N_CON_FPAGD") or 0) + int(gr.get("N_CON_FNOT") or 0)
    generador = "SPK_CONTAB_RADICACXC_1" if n_mov > 0 else "SPK_CONTAB_RADICACXC"
    st_gen = "ok" if n_fc > 0 else "ko"
    pasos.append(
        _check(
            st_gen,
            "Generador contable sugerido",
            f"{generador} — facturas en rad={n_fc}; con FPAGD/FNOT={n_mov}.",
            gen_rows,
            ["PC-RAD-01"],
        )
    )

    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_cnscxc(server, user, pwd, db, cns),
            titulo_prefix="Grafo RAD",
            default_pc=["PC-RAD-01", "PC-RAD-02"],
        )
    )

    q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSCXC, LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA
FROM dbo.FCXC WITH (NOLOCK) WHERE CNSCXC = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
    nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
    cont = int(cab[0].get("CONTABILIZADA") or 0) if cab else 0
    if nro:
        q_mcp = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{_esc(nro)}'
UNION ALL
SELECT NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{_esc(nro)}';
"""
        mcp_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp))
        if not mcp_rows:
            pasos.append(
                _check(
                    "ko",
                    "Comprobante radicación",
                    f"NROCOMPROBANTE {nro} no está en MCP/MCPE.",
                    cab,
                    ["PC-RAD-02"],
                )
            )
        else:
            row0 = mcp_rows[0]
            proc = row0.get("PROCEDENCIA") or ""
            est = str(row0.get("ESTADO") or "")
            origen = row0.get("ORIGEN") or ""
            st_m = "ok"
            if proc != "RAD CXC":
                st_m = "warn"
            if origen == "MCPE" or est == "0":
                st_m = "ko"
            elif est not in ("2", "1"):
                st_m = "warn"
            pasos.append(
                _check(
                    st_m,
                    "Comprobante radicación",
                    f"{nro}: {origen}; PROCEDENCIA={proc}; ESTADO={est}.",
                    mcp_rows,
                    ["PC-RAD-02"],
                )
            )
    elif cont != 0:
        pasos.append(
            _check(
                "warn",
                "Comprobante radicación",
                "FCXC marcada contabilizada pero sin NROCOMPROBANTE en cabecera.",
                cab,
                ["PC-RAD-02"],
            )
        )

    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-rad-cxc-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnscxc": cns,
        "parametroEntrada": cns,
        "generadorSugerido": generador,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_radicacion(),
    }


def trazar_bmov(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    """Traza movimiento bancario BMOV/BMOVD (solo SELECT)."""
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    banco, suc, cta, item = _parse_bmov_referencia(parametro, server, user, pwd, db)
    if not banco:
        return {
            "ok": False,
            "error": "Indique BANCO/SUCURSAL/CTA_BCO/ITEM (4 segmentos) o REFERENCIA1/ITEM MCP.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }

    ref = f"{banco}/{suc}/{cta}/{item}"
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_bmov(server, user, pwd, db, ref),
            titulo_prefix="Grafo BMOV",
            default_pc=["PC-BMOV-01", "PC-BMOV-02"],
        )
    )

    esc_b, esc_s, esc_c = _esc(banco), _esc(suc), _esc(cta)
    item_i = int(item) if str(item).isdigit() else 0
    q_det = f"""
SET NOCOUNT ON;
SELECT TOP 15 RENGLON, CAST(COALESCE(RECAUDO,0) AS INT) AS RECAUDO,
       CAST(COALESCE(ENPAGOS,0) AS INT) AS ENPAGOS,
       COALESCE(VLRITEM,0) AS VLRITEM, COALESCE(VLRLEGALIZADO,0) AS VLRLEGALIZADO,
       LTRIM(RTRIM(COALESCE(NODOCUMENTO,''))) AS NODOCUMENTO
FROM dbo.BMOVD WITH (NOLOCK)
WHERE BANCO = N'{esc_b}' AND SUCURSAL = N'{esc_s}' AND CTA_BCO = N'{esc_c}' AND ITEM = {item_i}
ORDER BY RENGLON;
"""
    det = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_det))
    pasos.append(
        _check(
            "ok" if det else "ko",
            "Detalle BMOVD",
            f"{len(det)} línea(s) en movimiento banco.",
            det,
            ["PC-BMOV-02"],
        )
    )

    q_fpag = f"""
SET NOCOUNT ON;
SELECT TOP 5 CNSFPAG, INGRESO, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO, RENGLON
FROM dbo.FPAG WITH (NOLOCK)
WHERE BANCO = N'{esc_b}' AND SUCURSAL = N'{esc_s}' AND CTA_BCO = N'{esc_c}'
  AND ITEM = {item_i} AND COALESCE(ESTADO,'') = N'Activo';
"""
    fpag = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fpag))
    if det and any(int(r.get("RECAUDO") or 0) == 1 for r in det):
        pasos.append(
            _check(
                "ok" if fpag else "warn",
                "Recaudos FPAG (RECAUDO=1)",
                f"{len(fpag)} FPAG activo(s) amarrado(s) al movimiento.",
                fpag,
                ["PC-RC-05", "PC-RC-06"],
            )
        )

    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-bmov-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "bmovRef": ref,
        "parametroEntrada": parametro.strip(),
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_bmov(),
    }


def _pasos_comprobante_desde_nro(
    server: str,
    user: str,
    pwd: str,
    db: str,
    nro: str,
    proc_esperada: str,
    titulo: str,
    pc_ids: list[str],
) -> list[dict]:
    """MCP/MCPE por NROCOMPROBANTE del documento origen."""
    nro = (nro or "").strip()
    if not nro:
        return []
    esc = _esc(nro)
    q = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}'
UNION ALL
SELECT NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        return [
            _check(
                "warn",
                titulo,
                f"Sin MCP/MCPE para {nro}",
                [],
                pc_ids,
            )
        ]
    row = rows[0]
    proc = (row.get("PROCEDENCIA") or "").strip().upper()
    est = str(row.get("ESTADO") or "")
    origen = row.get("ORIGEN") or ""
    st = "ok"
    if proc != proc_esperada.upper():
        st = "warn"
    if origen == "MCPE" or est == "0":
        st = "ko"
    elif est not in ("1", "2"):
        st = "warn"
    return [
        _check(
            st,
            titulo,
            f"{nro}: {origen}; PROCEDENCIA={proc}; ESTADO={est}.",
            rows,
            pc_ids,
        )
    ]


def trazar_nomina_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (parametro or "").strip()
    if not ref:
        return {
            "ok": False,
            "error": "Indique NUMDOC/CNSPAGO/CNSNIEPE (MCP REF1/2/3).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_nomina_pago(server, user, pwd, db, ref),
            titulo_prefix="Grafo NOMINA",
            default_pc=["PC-NOM-01", "PC-NOM-02"],
        )
    )
    numdoc, cnspago, cnsniepe = _parse_nomina_referencia(ref, server, user, pwd, db)
    if numdoc and cnspago and cnsniepe:
        esc_n, esc_p, esc_e = _esc(numdoc), _esc(cnspago), _esc(cnsniepe)
        q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA
FROM dbo.NIEPE WITH (NOLOCK)
WHERE NUMDOC = N'{esc_n}' AND CNSPAGO = N'{esc_p}' AND CNSNIEPE = N'{esc_e}';
"""
        cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
        nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
        if nro:
            pasos.extend(
                _pasos_comprobante_desde_nro(
                    server,
                    user,
                    pwd,
                    db,
                    nro,
                    "NOMINA",
                    "Comprobante nómina",
                    ["PC-NOM-01"],
                )
            )
    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_NC_CONTAB_NOMINA (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-NOM-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-nomina-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "parametroEntrada": ref,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_nomina(),
    }


def trazar_anticipos_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (parametro or "").strip()
    if not ref:
        return {
            "ok": False,
            "error": "Indique CNSANT/CNSFCOM (MCP REF1/2 ANTICIPOS).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_cnsant(server, user, pwd, db, ref),
            titulo_prefix="Grafo ANTICIPOS",
            default_pc=["PC-ANT-01"],
        )
    )
    cnsant, cnsfcom = _parse_cnsant_referencia(ref, server, user, pwd, db)
    if cnsant and cnsfcom:
        q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE
FROM dbo.ANT WITH (NOLOCK)
WHERE CNSANT = N'{_esc(cnsant)}' AND CNSFCOM = N'{_esc(cnsfcom)}';
"""
        cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
        nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
        if nro:
            pasos.extend(
                _pasos_comprobante_desde_nro(
                    server,
                    user,
                    pwd,
                    db,
                    nro,
                    "ANTICIPOS",
                    "Comprobante anticipo",
                    ["PC-ANT-01"],
                )
            )
    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_NC_CONTAB_ANTICIPOS / rama TANT+FCXP (IXONLINE/SQL).",
            [],
            ["PC-ANT-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-anticipos-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "parametroEntrada": ref,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_anticipos(),
    }


def trazar_iact_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = (parametro or "").strip()
    if not cns:
        return {
            "ok": False,
            "error": "Indique CNSIACTH (REFERENCIA1 MCP IACT).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_cnsiacth(server, user, pwd, db, cns),
            titulo_prefix="Grafo IACT",
            default_pc=["PC-IACT-01"],
        )
    )
    esc = _esc(cns)
    q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE
FROM dbo.IACTH WITH (NOLOCK) WHERE CNSIACTH = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
    nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
    if nro:
        pasos.extend(
            _pasos_comprobante_desde_nro(
                server,
                user,
                pwd,
                db,
                nro,
                "IACT",
                "Comprobante evento activo",
                ["PC-IACT-01"],
            )
        )
    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_CONTAB_IACT (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-IACT-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-iact-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnsiacth": cns,
        "parametroEntrada": cns,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_iact(),
    }


def trazar_legalizacion_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = (parametro or "").strip()
    if not cns:
        return {
            "ok": False,
            "error": "Indique CNSFLEG (REFERENCIA1 MCP LEGALIZACION).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_cnsfleg(server, user, pwd, db, cns),
            titulo_prefix="Grafo LEGALIZACION",
            default_pc=["PC-FLEG-01"],
        )
    )
    esc = _esc(cns)
    q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       LTRIM(RTRIM(COALESCE(INGRESO,''))) AS INGRESO,
       LTRIM(RTRIM(COALESCE(BANCO,''))) AS BANCO,
       LTRIM(RTRIM(COALESCE(SUCURSAL,''))) AS SUCURSAL,
       LTRIM(RTRIM(COALESCE(CTA_BCO,''))) AS CTA_BCO,
       CAST(COALESCE(ITEM,0) AS INT) AS ITEM,
       CAST(COALESCE(RENGLON,0) AS INT) AS RENGLON
FROM dbo.FLEG WITH (NOLOCK) WHERE CNSFLEG = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
    nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
    if nro:
        pasos.extend(
            _pasos_comprobante_desde_nro(
                server,
                user,
                pwd,
                db,
                nro,
                "LEGALIZACION",
                "Comprobante legalización",
                ["PC-FLEG-01"],
            )
        )
    if cab:
        ing = (cab[0].get("INGRESO") or "").strip().upper()
        if ing == "BANCOS" and (cab[0].get("BANCO") or "").strip():
            b = cab[0].get("BANCO") or ""
            s = cab[0].get("SUCURSAL") or ""
            c = cab[0].get("CTA_BCO") or ""
            it = cab[0].get("ITEM") or 0
            bmov_ref = f"{b}/{s}/{c}/{it}"
            pasos.append(
                _check(
                    "ok",
                    "Enlace BMOV (INGRESO=BANCOS)",
                    f"Traza banco opcional: {bmov_ref}",
                    cab,
                    ["PC-FLEG-01"],
                )
            )
        elif ing == "CAJA":
            pasos.append(
                _check(
                    "ok",
                    "Rama caja (INGRESO=CAJA)",
                    "Validar recibo/menor en caja antes de FLEG — no enlaza BMOV.",
                    cab,
                    ["PC-FLEG-01"],
                )
            )

    q_muestra = f"""
SET NOCOUNT ON;
SELECT TOP 8 ITEM, LTRIM(RTRIM(COALESCE(N_FACTURA,''))) AS N_FACTURA,
       COALESCE(VLRTOTAL,0) AS VLRTOTAL
FROM dbo.FLEGD WITH (NOLOCK) WHERE CNSFLEG = N'{esc}' ORDER BY ITEM;
"""
    muestra = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_muestra))
    pasos.append(
        _check(
            "ok" if muestra else "ko",
            "Muestra FLEGD",
            f"{len(muestra)} línea(s) mostradas (máx. 8).",
            muestra,
            ["PC-FLEG-01"],
        )
    )

    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_CONTAB_FLEG (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-FLEG-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-legalizacion-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnsfleg": cns,
        "parametroEntrada": cns,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_legalizacion(),
    }


def trazar_cesiones_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    cns = (parametro or "").strip()
    if not cns:
        return {
            "ok": False,
            "error": "Indique CNSCES (REFERENCIA1 MCP CESIONES).",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_cnsces(server, user, pwd, db, cns),
            titulo_prefix="Grafo CESIONES",
            default_pc=["PC-FCES-01"],
        )
    )
    esc = _esc(cns)
    q_nro = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE
FROM dbo.FCES WITH (NOLOCK) WHERE CNSCES = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nro))
    nro = (cab[0].get("NROCOMPROBANTE") or "").strip() if cab else ""
    if nro:
        pasos.extend(
            _pasos_comprobante_desde_nro(
                server,
                user,
                pwd,
                db,
                nro,
                "CESIONES",
                "Comprobante cesión",
                ["PC-FCES-01"],
            )
        )

    q_cxp = f"""
SET NOCOUNT ON;
SELECT TOP 5 CNSFCXP, COALESCE(VALORCESION,0) AS VALORCESION
FROM dbo.FCESCXP WITH (NOLOCK) WHERE CNSCES = N'{esc}';
"""
    q_cxc = f"""
SET NOCOUNT ON;
SELECT TOP 5 N_FACTURA, COALESCE(VALORCESION,0) AS VALORCESION
FROM dbo.FCESCXC WITH (NOLOCK) WHERE CNSCES = N'{esc}';
"""
    cxp = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxp))
    cxc = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxc))
    pasos.append(
        _check(
            "ok" if cxp or cxc else "ko",
            "Detalle cesión (muestra)",
            f"FCESCXP={len(cxp)} FCESCXC={len(cxc)} filas muestra.",
            (cxp[:3] + cxc[:3])[:6],
            ["PC-FCES-01"],
        )
    )

    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_CONTAB_FCES (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-FCES-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-cesiones-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "cnsces": cns,
        "parametroEntrada": cns,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_cesiones(),
    }


def trazar_ajdep_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (parametro or "").strip()
    if not ref:
        return {
            "ok": False,
            "error": "Indique NROCOMPROBANTE AJDEP o ANO/MES[/IDSEDE] o ANO-MES.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos: list[dict] = []
    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_ajdep(server, user, pwd, db, ref),
            titulo_prefix="Grafo AJDEP",
            default_pc=["PC-AJDEP-01"],
        )
    )
    nro, nota = _resolve_ajdep_nro_comprobante(server, user, pwd, db, ref)
    if nro:
        pasos.extend(
            _pasos_comprobante_desde_nro(
                server,
                user,
                pwd,
                db,
                nro,
                "AJDEP",
                "Comprobante depreciación",
                ["PC-AJDEP-01"],
            )
        )
    pasos.append(
        _check(
            "ok" if nro else "warn",
            "Resolución parámetro",
            nota or ref,
            [],
            ["PC-AJDEP-01"],
        )
    )
    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_APL_AJDEPRECIACION (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-AJDEP-01"],
        )
    )
    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-ajdep-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "parametroEntrada": ref,
        "nroComprobanteResuelto": nro or "",
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_ajdep(),
    }


def _parse_nro_rev_param(parametro: str) -> tuple[str, str]:
    """Devuelve (nro_reverso, nro_origen_buscar). ORIG: prefix busca por REFERENCIA3."""
    p = (parametro or "").strip()
    if not p:
        return "", ""
    upper = p.upper()
    if upper.startswith("ORIG:"):
        return "", p.split(":", 1)[1].strip()
    if upper.startswith("ORIGEN:"):
        return "", p.split(":", 1)[1].strip()
    return p, ""


def _resolver_nro_reverso_por_origen(
    server: str, user: str, pwd: str, db: str, nro_origen: str
) -> tuple[str, str]:
    orig = (nro_origen or "").strip()
    if not orig:
        return "", ""
    esc = _esc(orig)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3, N'MCPE' AS ORIGEN, FECHA
FROM dbo.MCPE WITH (NOLOCK)
WHERE REFERENCIA3 = N'{esc}' AND PROCEDENCIA LIKE N'REV%'
ORDER BY FECHA DESC;
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        q2 = f"""
SET NOCOUNT ON;
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3, N'MCP' AS ORIGEN, FECHA
FROM dbo.MCP WITH (NOLOCK)
WHERE REFERENCIA3 = N'{esc}' AND PROCEDENCIA LIKE N'REV%'
ORDER BY FECHA DESC;
"""
        rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q2))
    if not rows:
        return "", f"Sin reverso MCPE/MCP con REFERENCIA3={orig}"
    nro = (rows[0].get("NROCOMPROBANTE") or "").strip()
    return nro, f"Resuelto desde origen {orig} → {nro} ({len(rows)} candidato(s))"


def trazar_reversos_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (parametro or "").strip()
    if not ref:
        return {
            "ok": False,
            "error": "Indique NROCOMPROBANTE reversión o ORIG:NROCOMPROBANTE_origen.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }

    nro_rev, orig_buscar = _parse_nro_rev_param(ref)
    nota_res = ""
    if not nro_rev and orig_buscar:
        nro_rev, nota_res = _resolver_nro_reverso_por_origen(
            server, user, pwd, db, orig_buscar
        )
        if not nro_rev:
            return {
                "ok": False,
                "error": nota_res or "No se encontró reverso para el origen.",
                "servidor": servidor_id,
                "baseDatos": db,
                "pasos": [],
                "resumen": {"ok": 0, "warn": 0, "ko": 1},
            }
        ref = nro_rev

    pasos: list[dict] = []
    if nota_res:
        pasos.append(
            _check(
                "ok",
                "Resolución por origen",
                nota_res,
                [],
                ["PC-REV-01"],
            )
        )

    pasos.extend(
        _pasos_from_grafo_checks(
            _checks_documento_nro_reverso(server, user, pwd, db, ref),
            titulo_prefix="Grafo REVERSOS",
            default_pc=["PC-REV-01", "PC-REV-02"],
        )
    )

    esc = _esc(ref)
    q_rev = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3, ANO, MES
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}'
UNION ALL
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3, ANO, MES
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    rev_row = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_rev))
    orig = (rev_row[0].get("REFERENCIA3") or "").strip() if rev_row else ""
    proc = (rev_row[0].get("PROCEDENCIA") or "").strip().upper() if rev_row else ""

    if orig:
        q_o = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, ANO, MES,
       CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       CAST(COALESCE(ANULADO,0) AS INT) AS ANULADO
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{_esc(orig)}';
"""
        orig_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_o))
        if orig_rows:
            ano_o = (orig_rows[0].get("ANO") or "").strip()
            mes_o = orig_rows[0].get("MES")
            if ano_o and mes_o is not None:
                q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO
FROM dbo.PRI WITH (NOLOCK) WHERE ANO = N'{_esc(ano_o)}' AND MES = {int(mes_o)};
"""
                pri = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
                if pri and proc in ("REVCAJAING", "REVCAJAEGR"):
                    cerr = int(pri[0].get("CERRADO") or 0)
                    pasos.append(
                        _check(
                            "ok" if cerr == 0 else "ko",
                            "PRI periodo origen (REVCAJA)",
                            f"Origen {orig} periodo {ano_o}-{mes_o} CERRADO={cerr}",
                            pri,
                            ["PC-REV-02"],
                        )
                    )

    q_mch = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCH,
       SUM(CASE WHEN PROCESO = N'REVERSION' THEN 1 ELSE 0 END) AS N_REVERSION
FROM dbo.MCHE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    mch = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mch))
    n_m = int(mch[0].get("N_MCH") or 0) if mch else 0
    n_r = int(mch[0].get("N_REVERSION") or 0) if mch else 0
    tabla_lineas = "MCHE"
    if n_m == 0:
        q_mch2 = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCH,
       SUM(CASE WHEN PROCESO = N'REVERSION' THEN 1 ELSE 0 END) AS N_REVERSION
FROM dbo.MCH WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
        mch = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mch2))
        n_m = int(mch[0].get("N_MCH") or 0) if mch else 0
        n_r = int(mch[0].get("N_REVERSION") or 0) if mch else 0
        tabla_lineas = "MCH"
    pasos.append(
        _check(
            "ok" if n_m > 0 else "ko",
            f"Líneas {tabla_lineas} reversión",
            f"{n_m} línea(s); PROCESO=REVERSION: {n_r}",
            mch,
            ["PC-REV-01"],
        )
    )

    pasos.append(
        _check(
            "ok",
            "Generador contable",
            "SPK_REVERSAR_MCP (IXONLINE/SQL · PREVERSION).",
            [],
            ["PC-REV-01"],
        )
    )

    resumen = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-reversos-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "parametroEntrada": parametro.strip(),
        "nroReverso": ref,
        "nroOrigen": orig,
        "pasos": pasos,
        "resumen": resumen,
        "runbook": meta_runbook_reversos(),
    }


def trazar_cierre_periodo_contab(
    servidor_id: str,
    base_datos: str,
    parametro: str,
) -> dict[str, Any]:
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (parametro or "").strip() or None
    checks, resumen, ano, mes = _checks_cierre_periodo_fase2(
        server, user, pwd, db, ref
    )
    if ano is None or mes is None:
        return {
            "ok": False,
            "error": "Indique ANO-MES o ANO/MES, o exista periodo abierto en PRI.",
            "servidor": servidor_id,
            "baseDatos": db,
            "pasos": [],
            "resumen": {"ok": 0, "warn": 0, "ko": 1},
        }
    pasos = _checks_cierre_a_pasos(checks)
    pasos.append(
        _check(
            "ok",
            "Grafo Fase 2",
            "grafo-cierre-periodo.json — PRI, MCPE, SALDOMES, sub-cierres.",
            [],
            ["PC-CIERRE-01", "PC-CIERRE-02", "PC-CIERRE-03"],
        )
    )
    resumen_p = _resumen_pasos(pasos)
    return {
        "ok": True,
        "flujoId": "flujo-cierre-periodo-contab",
        "servidor": servidor_id,
        "baseDatos": db,
        "parametroEntrada": ref or f"{ano}-{mes:02d}",
        "periodoFoco": f"{ano}-{mes:02d}",
        "pasos": pasos,
        "resumen": resumen_p,
        "checksFase2": checks,
        "runbook": meta_runbook_cierre_periodo(),
    }


# --- Configuración contable (grafos requires[] → SELECT) ---

_PAQUETE_CRITICO = ("CAJA", "CXC", "CONCI", "NOTDBCR")

_CUENTA_USVGS_EXACT = frozenset(
    {
        "CUENTA_CR_ANTIMPUEST",
        "IDCUENTANOTAS",
        "CUENTAGLOSAACEPTADA",
        "IDCON_REVDOC_AANTING",
    }
)


def _load_grafo_indice() -> dict:
    return _read_json(GRAFO_CONTAB_INDICE, {"procedencias": []})


def listar_procedencias_contab() -> list[dict]:
    idx = _load_grafo_indice()
    out = []
    for p in idx.get("procedencias") or []:
        out.append(
            {
                "orden": p.get("orden"),
                "procedencia": p.get("procedencia"),
                "generadores": p.get("generadores") or [],
                "grafoArchivo": p.get("grafoArchivo"),
                "estadoGrafo": p.get("estadoGrafo"),
            }
        )
    return out


def _resolve_procedencias_contab(seleccion: str) -> list[str]:
    sel = (seleccion or "CRITICO").strip().upper()
    idx = _load_grafo_indice()
    todas = [p.get("procedencia") for p in idx.get("procedencias") or [] if p.get("procedencia")]
    if sel in ("TODAS", "ALL", "*"):
        return todas
    if sel in ("CRITICO", "CRÍTICO", "PAQUETE"):
        return [x for x in _PAQUETE_CRITICO if x in todas]
    # una procedencia (RAD CXC tiene espacio)
    for p in idx.get("procedencias") or []:
        if (p.get("procedencia") or "").upper() == sel or (p.get("procedencia") or "") == seleccion.strip():
            return [p.get("procedencia")]
    raise ValueError(f"Procedencia contable desconocida: {seleccion}")


def _grafo_json_path(procedencia: str) -> Path | None:
    for p in _load_grafo_indice().get("procedencias") or []:
        if p.get("procedencia") == procedencia:
            rel = (p.get("grafoArchivo") or "").replace("grafo-contabilizacion/", "")
            if rel:
                path = GRAFO_CONTAB_DIR / rel
                return path if path.is_file() else None
    return None


def _usvgs_tokens_from_req(req: dict) -> list[str]:
    raw = req.get("usvgs")
    if not raw:
        return []
    items = [raw] if isinstance(raw, str) else list(raw) if isinstance(raw, list) else []
    out: list[str] = []
    for item in items:
        s = str(item).strip()
        if not s or "→" in s or "*" in s:
            continue
        tok = s.split()[0].strip()
        if tok and tok not in out:
            out.append(tok)
    return out


def _collect_grafo_requires(procedencias: list[str]) -> dict[str, Any]:
    usvgs: set[str] = set()
    tablas: set[str] = set()
    by_proc: dict[str, list[str]] = {}
    for proc in procedencias:
        path = _grafo_json_path(proc)
        if not path:
            continue
        doc = _read_json(path, {})
        ids: list[str] = []
        for nodo in doc.get("nodos") or []:
            for bucket in ("requiresConfig", "requiresDocumento"):
                for req in nodo.get(bucket) or []:
                    if not isinstance(req, dict):
                        continue
                    for u in _usvgs_tokens_from_req(req):
                        usvgs.add(u)
                        ids.append(u)
                    t = req.get("tabla")
                    if t:
                        tablas.add(str(t).upper())
                    for tb in req.get("tablas") or []:
                        tablas.add(str(tb).upper())
        by_proc[proc] = sorted(set(ids))
    usvgs.add("IDMODELOCONTABLE")
    usvgs.add("COMPROBMULTISEDE")
    return {"usvgs": sorted(usvgs), "tablas": sorted(tablas), "porProcedencia": by_proc}


def _is_cuenta_usvgs(var_id: str) -> bool:
    v = (var_id or "").upper()
    if v in _CUENTA_USVGS_EXACT:
        return True
    return v.startswith("CUENTA_") or v.startswith("CTA_") or v.startswith("IDCUENTA")


def _append_check(checks: list[dict], resumen: dict, **row: Any) -> None:
    st = row.get("estado") or "ok"
    resumen[st] = resumen.get(st, 0) + 1
    checks.append(row)


# KMCOM: IDTIPOCONT habituales por procedencia (mínimo de filas, severidad si falta)
_KMCOM_ESPERADO: dict[str, list[tuple[str, str, int]]] = {
    "CAJA": [("COSTOS", "warn", 1)],
    "CXP": [("CXP_COMPRAS", "ko", 1)],
    "INV": [("MOV_INVENTARIO", "warn", 1)],
    "FACTURA": [("DESCUENTOS", "warn", 1)],
}


def _checks_maestros_fpa_bct_ofin_kmcom(
    server: str,
    user: str,
    pwd: str,
    db: str,
    procs: list[str],
    modelo: str,
    checks: list[dict],
    resumen: dict[str, int],
) -> None:
    need_fpa = any(p in procs for p in ("CAJA", "CXC", "LEGALIZACION"))
    if need_fpa:
        q_fpa = """
SET NOCOUNT ON;
SELECT TOP 20 LTRIM(RTRIM(F.FPA)) AS FPA, LTRIM(RTRIM(F.CUENTA)) AS CUENTA
FROM dbo.FPA F WITH (NOLOCK)
LEFT JOIN dbo.CUE U WITH (NOLOCK) ON U.CUENTA = F.CUENTA AND U.TIPO = N'Detalle'
WHERE COALESCE(F.CUENTA,'') = '' OR U.CUENTA IS NULL;
"""
        fpa_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fpa))
        _append_check(
            checks,
            resumen,
            id="fpa-cuenta",
            grupo="Tesorería",
            titulo="FPA → CUE Detalle",
            estado="ko" if fpa_rows else "ok",
            validacion=f"{len(fpa_rows)} forma(s) de pago sin cuenta válida" if fpa_rows else "Formas de pago con cuenta OK (muestra TOP 20)",
            filas=fpa_rows,
            puntosCriticos=["PC-CAJ-05", "PC-CXC-01"],
        )

    need_bco = any(p in procs for p in ("BMOV", "CXC"))
    if need_bco:
        q_bct = """
SET NOCOUNT ON;
SELECT TOP 15 LTRIM(RTRIM(BANCO)) AS BANCO, LTRIM(RTRIM(SUCURSAL)) AS SUCURSAL,
       LTRIM(RTRIM(CTA_BCO)) AS CTA_BCO, LTRIM(RTRIM(COD_CONTABLE)) AS COD_CONTABLE
FROM dbo.BCT WITH (NOLOCK)
WHERE COALESCE(COD_CONTABLE,'') = '';
"""
        bct_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_bct))
        _append_check(
            checks,
            resumen,
            id="bct-contable",
            grupo="Bancos",
            titulo="BCT sin COD_CONTABLE",
            estado="ko" if bct_rows else "ok",
            validacion=f"{len(bct_rows)} cuenta(s) bancaria(s) sin código contable" if bct_rows else "Cuentas banco con COD_CONTABLE",
            filas=bct_rows,
            puntosCriticos=["PC-BMOV-01"],
        )

    if "BMOV" in procs:
        q_ofin = """
SET NOCOUNT ON;
SELECT TOP 20 LTRIM(RTRIM(IDOPERACION)) AS IDOPERACION,
       LTRIM(RTRIM(COMPROBANTE)) AS COMPROBANTE, LTRIM(RTRIM(CUENTA)) AS CUENTA
FROM dbo.OFIN WITH (NOLOCK)
WHERE COALESCE(COMPROBANTE,'') = '' OR COALESCE(CUENTA,'') = '';
"""
        ofin_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ofin))
        _append_check(
            checks,
            resumen,
            id="ofin-config",
            grupo="Bancos",
            titulo="OFIN operaciones bancarias",
            estado="ko" if ofin_rows else "ok",
            validacion=f"{len(ofin_rows)} operación(es) sin comprobante o cuenta" if ofin_rows else "OFIN con comprobante y cuenta (muestra)",
            filas=ofin_rows,
            puntosCriticos=["PC-BMOV-01"],
        )

    if modelo:
        q_km = (
            "SET NOCOUNT ON; SELECT IDTIPOCONT, COUNT(*) AS N FROM dbo.KMCOM WITH (NOLOCK) "
            f"WHERE IDMODELOCONT = N'{_esc(modelo)}' GROUP BY IDTIPOCONT ORDER BY IDTIPOCONT;"
        )
        km_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_km))
        n_total = sum(int(r.get("N") or 0) for r in km_rows)
        if n_total == 0:
            _append_check(
                checks,
                resumen,
                id="kmcom-vacio",
                grupo="KMCOM",
                titulo="KMCOM del modelo",
                estado="ko",
                validacion=f"Sin filas KMCOM para modelo {modelo}",
                filas=[],
                puntosCriticos=["PC-INV-01"],
            )
        else:
            _append_check(
                checks,
                resumen,
                id="kmcom-resumen",
                grupo="KMCOM",
                titulo="KMCOM del modelo",
                estado="ok",
                validacion=f"{n_total} fila(s) en {len(km_rows)} IDTIPOCONT distintos",
                filas=km_rows[:25],
            )
        km_map = {(r.get("IDTIPOCONT") or "").strip(): int(r.get("N") or 0) for r in km_rows}
        for proc in procs:
            for idtipo, sev, minimo in _KMCOM_ESPERADO.get(proc, []):
                n = km_map.get(idtipo, 0)
                if n < minimo:
                    _append_check(
                        checks,
                        resumen,
                        id=f"kmcom-{proc}-{idtipo}",
                        grupo="KMCOM",
                        titulo=f"{proc}: IDTIPOCONT={idtipo}",
                        estado=sev,
                        validacion=f"{n} fila(s); se esperaba al menos {minimo}",
                        filas=[],
                        puntosCriticos=["PC-CAJ-03", "PC-INV-01"],
                    )


def _checks_documento_fpag_grafo(
    server: str,
    user: str,
    pwd: str,
    db: str,
    cnsfpag: str,
) -> list[dict]:
    """Configuración grafo CXC/CAJA atada a un recaudo (CNSFPAG)."""
    cns = (cnsfpag or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q_fpag = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSFPAG, INGRESO, CODCAJA, CNSFACJ, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO
FROM dbo.FPAG WITH (NOLOCK) WHERE CNSFPAG = N'{esc}';
"""
    fpag_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fpag))
    if not fpag_rows:
        out.append(
            {
                "id": "doc-fpag-missing",
                "grupo": "Documento CXC",
                "titulo": f"FPAG {cns}",
                "estado": "ko",
                "validacion": "Recaudo no existe — no se cruza TTEC/FIMPDV",
                "filas": [],
                "puntosCriticos": ["PC-CXC-01"],
            }
        )
        return out

    ingreso = (fpag_rows[0].get("INGRESO") or "").strip().upper()

    q_ttec = f"""
SET NOCOUNT ON;
SELECT DISTINCT LTRIM(RTRIM(F.TIPOTTEC)) AS TIPOTTEC,
       LTRIM(RTRIM(T.CUENTACG)) AS CUENTACG,
       LTRIM(RTRIM(T.CUENTARAD)) AS CUENTARAD,
       COUNT(*) AS LINEAS_FTR
FROM dbo.FPAGD D WITH (NOLOCK)
INNER JOIN dbo.FTR F WITH (NOLOCK) ON F.N_FACTURA = D.N_FACTURA
LEFT JOIN dbo.TTEC T WITH (NOLOCK) ON T.TIPO = F.TIPOTTEC
WHERE D.CNSFPAG = N'{esc}'
GROUP BY F.TIPOTTEC, T.CUENTACG, T.CUENTARAD
ORDER BY F.TIPOTTEC;
"""
    ttec_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ttec))
    bad_ttec = [
        r
        for r in ttec_rows
        if not (r.get("TIPOTTEC") or "").strip()
        or (not (r.get("CUENTACG") or "").strip() and not (r.get("CUENTARAD") or "").strip())
    ]
    out.append(
        {
            "id": "doc-ttec-fpagd",
            "grupo": "Documento CXC",
            "titulo": "TTEC × facturas del recaudo",
            "estado": "ko" if bad_ttec else ("ok" if ttec_rows else "warn"),
            "validacion": (
                f"{len(bad_ttec)} tipo(s) sin CUENTACG/CUENTARAD en {len(ttec_rows)} distintos"
                if bad_ttec
                else (f"{len(ttec_rows)} TIPOTTEC en FPAGD" if ttec_rows else "Sin líneas FPAGD / FTR")
            ),
            "filas": bad_ttec or ttec_rows[:15],
            "puntosCriticos": ["PC-CXC-01", "PC-CONCI-01"],
        }
    )

    q_imp = f"""
SET NOCOUNT ON;
SELECT TOP 15 P.IDIMPUESTO, LTRIM(RTRIM(P.CUENTA)) AS CUENTA_FPAGDI,
       LTRIM(RTRIM(F.CUENTA)) AS CUENTA_FIMPDV
FROM dbo.FPAGDI P WITH (NOLOCK)
LEFT JOIN dbo.FIMPDV F WITH (NOLOCK)
  ON F.IDIMPUESTO = P.IDIMPUESTO
 AND CAST(GETDATE() AS DATE) BETWEEN CAST(F.FINICIAL AS DATE) AND CAST(F.FFINAL AS DATE)
WHERE P.CNSFPAG = N'{esc}'
  AND (COALESCE(P.CUENTA,'') = '' OR F.IDIMPUESTO IS NULL OR COALESCE(F.CUENTA,'') = '');
"""
    imp_bad = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_imp))
    if imp_bad:
        out.append(
            {
                "id": "doc-fimpdv-fpagdi",
                "grupo": "Documento CXC",
                "titulo": "FPAGDI × FIMPDV vigente",
                "estado": "ko",
                "validacion": f"{len(imp_bad)} línea(s) impuesto sin cuenta o sin vigencia FIMPDV",
                "filas": imp_bad,
                "puntosCriticos": ["PC-CXC-03"],
            }
        )

    q_vlr = """
SET NOCOUNT ON;
SELECT IDVARIABLE, LTRIM(RTRIM(DATO)) AS DATO FROM dbo.USVGS WITH (NOLOCK)
WHERE IDVARIABLE IN (N'VLRMAXAJUSTERECAUDOS', N'REC_VLRMAX_AJUSTE');
"""
    vlr_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_vlr))
    vlr_map = {(r.get("IDVARIABLE") or "").strip(): (r.get("DATO") or "").strip() for r in vlr_rows}
    if not vlr_map.get("VLRMAXAJUSTERECAUDOS") and not vlr_map.get("REC_VLRMAX_AJUSTE"):
        out.append(
            {
                "id": "doc-usvgs-recaudo",
                "grupo": "Documento CXC",
                "titulo": "USVGS topes recaudo",
                "estado": "warn",
                "validacion": "VLRMAXAJUSTERECAUDOS y REC_VLRMAX_AJUSTE vacíos o ausentes",
                "filas": vlr_rows,
                "puntosCriticos": ["PC-CXC-02"],
            }
        )

    if ingreso == "CAJA":
        cod = (fpag_rows[0].get("CODCAJA") or "").strip()
        cfj = (fpag_rows[0].get("CNSFACJ") or "").strip()
        if cod and cfj:
            q_pcj = f"""
SET NOCOUNT ON;
SELECT TOP 10 P.FPA, C.CODIGO AS CONCEPTO, LTRIM(RTRIM(C.CUENTA)) AS CUENTA_CPCJ
FROM dbo.PCJ P WITH (NOLOCK)
INNER JOIN dbo.CPCJ C WITH (NOLOCK) ON C.CODIGO = P.CONCEPTO
LEFT JOIN dbo.CUE U WITH (NOLOCK) ON U.CUENTA = C.CUENTA AND U.TIPO = N'Detalle'
WHERE P.CODCAJA = N'{_esc(cod)}' AND P.CNSFACJ = N'{_esc(cfj)}'
  AND (COALESCE(C.CUENTA,'') = '' OR U.CUENTA IS NULL);
"""
            pcj_bad = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pcj))
            out.append(
                {
                    "id": "doc-pcj-cpcj",
                    "grupo": "Documento CAJA",
                    "titulo": "PCJ del recibo × CPCJ",
                    "estado": "ko" if pcj_bad else "ok",
                    "validacion": (
                        f"{len(pcj_bad)} forma/concepto sin cuenta Detalle"
                        if pcj_bad
                        else "Conceptos del recibo con cuenta OK"
                    ),
                    "filas": pcj_bad,
                    "puntosCriticos": ["PC-CAJ-04"],
                }
            )

    return out


# Tipos de referencia documento ↔ grafo N3 (validacionSql cableado en motor)
_TIPOS_REFERENCIA_CONTAB: list[dict[str, Any]] = [
    {
        "id": "CNSFPAG",
        "etiqueta": "Recaudo (CNSFPAG)",
        "procedencias": ["CXC"],
        "grafoRequireIds": ["fpag-cerrado"],
        "formato": "Consecutivo FPAG",
    },
    {
        "id": "CNSFCXP",
        "etiqueta": "CxP (CNSFCXP)",
        "procedencias": ["CXP", "NOTDBCRCXP"],
        "grafoRequireIds": ["fcxp-detalle", "sin-duplicado"],
        "formato": "Consecutivo FCXP",
    },
    {
        "id": "N_FACTURA",
        "etiqueta": "Factura (N_FACTURA)",
        "procedencias": ["FACTURA"],
        "grafoRequireIds": ["ftr-vigente", "ftr-no-duplicada"],
        "formato": "N_FACTURA",
    },
    {
        "id": "CNSFNOT",
        "etiqueta": "Nota cartera (CNSFNOT + CLASE)",
        "procedencias": ["NOTDBCR"],
        "grafoRequireIds": ["fnot-aplicada", "fnot-unica-mcp"],
        "formato": "CNSFNOT/CLASE (REFERENCIA1/2 MCP NOTDBCR)",
    },
    {
        "id": "FCXPDBCR",
        "etiqueta": "Nota CxP (CNSFCXP + ITEM)",
        "procedencias": ["NOTDBCRCXP"],
        "grafoRequireIds": ["fcxpdbcr", "fcxp-mcp-previo"],
        "formato": "CNSFCXP/ITEM (REFERENCIA1/2 MCP NOTDBCRCXP)",
    },
    {
        "id": "IDFCONCI",
        "etiqueta": "Conciliación glosa (IDFCONCI)",
        "procedencias": ["CONCI"],
        "grafoRequireIds": ["fconci-ref"],
        "formato": "IDFCONCI = REFERENCIA1 MCP CONCI",
    },
    {
        "id": "CNSCXC",
        "etiqueta": "Radicación CxC (CNSCXC)",
        "procedencias": ["RAD CXC"],
        "grafoRequireIds": ["fcxc-radicada", "ftr-factura-mcp"],
        "formato": "CNSCXC = REFERENCIA1 MCP RAD CXC",
    },
    {
        "id": "CNSGLO",
        "etiqueta": "Glosa cartera (CNSGLO)",
        "procedencias": ["RGLO"],
        "grafoRequireIds": ["fglo-ref", "tipo-glo"],
        "formato": "CNSGLO = REFERENCIA1 MCP RGLO",
    },
    {
        "id": "BMOV_REF",
        "etiqueta": "Mov. banco (BANCO/SUC/CTA/ITEM)",
        "procedencias": ["BMOV"],
        "grafoRequireIds": ["bmov-confirmado", "bct-cue"],
        "formato": "BANCO/SUCURSAL/CTA_BCO/ITEM o REFERENCIA1/ITEM MCP",
    },
    {
        "id": "NROCOMPROBANTE",
        "etiqueta": "Comprobante (NROCOMPROBANTE)",
        "procedencias": ["MANUAL"],
        "grafoRequireIds": ["mch-detalle", "cuadre"],
        "formato": "NROCOMPROBANTE MCP/MCPE",
    },
    {
        "id": "NOMINA_PAGO",
        "etiqueta": "Pago nómina (NUMDOC/CNSPAGO/CNSNIEPE)",
        "procedencias": ["NOMINA"],
        "grafoRequireIds": ["lote-nom", "conceptos-cuenta"],
        "formato": "MCP REF1/2/3 = NUMDOC, CNSPAGO, CNSNIEPE",
    },
    {
        "id": "CNSANT",
        "etiqueta": "Anticipo (CNSANT)",
        "procedencias": ["ANTICIPOS"],
        "grafoRequireIds": ["anticipo-ref", "tercero-debito"],
        "formato": "CNSANT o CNSANT/CNSFCOM (REF1/2 MCP ANTICIPOS)",
    },
    {
        "id": "CNSIACTH",
        "etiqueta": "Evento activo (CNSIACTH)",
        "procedencias": ["IACT"],
        "grafoRequireIds": ["iact-ref", "acfi-estado"],
        "formato": "CNSIACTH = REFERENCIA1 MCP IACT",
    },
    {
        "id": "CNSFLEG",
        "etiqueta": "Legalización (CNSFLEG)",
        "procedencias": ["LEGALIZACION"],
        "grafoRequireIds": ["fleg", "caja-menor"],
        "formato": "CNSFLEG = REFERENCIA1 MCP LEGALIZACION",
    },
    {
        "id": "CNSCES",
        "etiqueta": "Cesión cartera (CNSCES)",
        "procedencias": ["CESIONES"],
        "grafoRequireIds": ["fces", "fces-doc"],
        "formato": "CNSCES = REFERENCIA1 MCP CESIONES",
    },
    {
        "id": "AJDEP_REF",
        "etiqueta": "Depreciación (AJDEP)",
        "procedencias": ["AJDEP"],
        "grafoRequireIds": ["cabecera-periodo", "activos-dep"],
        "formato": "NROCOMPROBANTE o ANO/MES[/IDSEDE]",
    },
    {
        "id": "NRO_REV",
        "etiqueta": "Reversión (comprobante)",
        "procedencias": ["REVERSOS"],
        "grafoRequireIds": ["mcp-origen", "mch-lineas"],
        "formato": "NROCOMPROBANTE MCPE/MCP reversión (REFERENCIA3 = origen)",
    },
    {
        "id": "CNSMOV",
        "etiqueta": "Movimiento inventario (CNSMOV)",
        "procedencias": ["INV"],
        "grafoRequireIds": ["imov-confirmado"],
        "formato": "CNSMOV = REFERENCIA1 MCP INV",
    },
    {
        "id": "FCJ",
        "etiqueta": "Recibo caja (CODCAJA + CNSFACJ)",
        "procedencias": ["CAJA", "LEGALIZACION"],
        "grafoRequireIds": ["fcj-existe"],
        "formato": "CODCAJA/CNSFACJ o CNSFACJ (busca CODCAJA en FPAG)",
    },
]


def listar_tipos_referencia_contab() -> list[dict]:
    return list(_TIPOS_REFERENCIA_CONTAB)


def _collect_grafo_n3_validaciones(procedencias: list[str]) -> list[dict]:
    """Requires N3 con validacionSql (catálogo para UI / trazabilidad)."""
    out: list[dict] = []
    for proc in procedencias:
        path = _grafo_json_path(proc)
        if not path:
            continue
        doc = _read_json(path, {})
        for nodo in doc.get("nodos") or []:
            if not str(nodo.get("id", "")).startswith("N3-"):
                continue
            for bucket in ("requiresDocumento", "requiresConfig"):
                for req in nodo.get(bucket) or []:
                    if not isinstance(req, dict):
                        continue
                    vs = (req.get("validacionSql") or "").strip()
                    if not vs:
                        continue
                    out.append(
                        {
                            "procedencia": proc,
                            "nodoId": nodo.get("id"),
                            "requireId": req.get("id"),
                            "validacionSql": vs,
                            "checkMotor": req.get("checkMotor") or _check_motor_for_require(req.get("id") or ""),
                        }
                    )
    return out


def _check_motor_for_require(require_id: str) -> str | None:
    m = {
        "fpag-cerrado": "doc-fpag-*",
        "fcxp-detalle": "doc-fcxp-*",
        "sin-duplicado": "doc-fcxp-duplicado",
        "ftr-vigente": "doc-ftr-*",
        "ftr-no-duplicada": "doc-ftr-duplicado",
        "imov-confirmado": "doc-imov-*",
        "pri-f-factura": "doc-ftr-pri",
        "fnot-aplicada": "doc-fnot-*",
        "fnot-unica-mcp": "doc-fnot-mcp-dup",
        "fcxpdbcr": "doc-fcxpdbcr-*",
        "fcxp-mcp-previo": "doc-fcxpdbcr-mcp-cxp",
        "fconci-ref": "doc-fconci-*",
        "fcxc-radicada": "doc-fcxc-*",
        "ftr-factura-mcp": "doc-fcxc-ftr-mcp",
        "fglo-ref": "doc-fglo-*",
        "tipo-glo": "doc-fglo-tipo",
        "bmov-confirmado": "doc-bmov-*",
        "bct-cue": "doc-bmov-bct",
        "mch-detalle": "doc-mch-cue",
        "cuadre": "doc-mch-cuadre",
        "lote-nom": "doc-nomina-*",
        "conceptos-cuenta": "doc-nomina-conceptos",
        "anticipo-ref": "doc-ant-*",
        "tercero-debito": "doc-ant-tercero",
        "iact-ref": "doc-iact-*",
        "acfi-estado": "doc-iact-acfi",
        "fleg": "doc-fleg-*",
        "caja-menor": "doc-fleg-caj",
        "fces": "doc-fces-*",
        "fces-doc": "doc-fces-det",
        "cabecera-periodo": "doc-ajdep-*",
        "activos-dep": "doc-ajdep-mche",
        "mcp-origen": "doc-rev-*",
        "mch-lineas": "doc-mch-cuadre",
    }
    return m.get(require_id)


def _infer_tipo_referencia(procedencia: str, tipo_explicit: str | None) -> str:
    t = (tipo_explicit or "").strip().upper()
    aliases = {
        "FPAG": "CNSFPAG",
        "RECAUDO": "CNSFPAG",
        "FCXP": "CNSFCXP",
        "FTR": "N_FACTURA",
        "IMOV": "CNSMOV",
        "CNSFACJ": "FCJ",
        "FNOT": "CNSFNOT",
        "CONCI": "IDFCONCI",
        "FCONCI": "IDFCONCI",
        "RAD": "CNSCXC",
        "FCXPDBCR": "FCXPDBCR",
        "FGLO": "CNSGLO",
        "GLOSA": "CNSGLO",
        "BMOV": "BMOV_REF",
        "MCP": "NROCOMPROBANTE",
        "NOMINA": "NOMINA_PAGO",
        "ANT": "CNSANT",
        "IACTH": "CNSIACTH",
        "FLEG": "CNSFLEG",
        "FCES": "CNSCES",
        "CES": "CNSCES",
        "AJDEP": "AJDEP_REF",
        "REV": "NRO_REV",
    }
    if t in aliases:
        t = aliases[t]
    if t in {x["id"] for x in _TIPOS_REFERENCIA_CONTAB}:
        return t
    proc = (procedencia or "").strip().upper()
    proc_map = {
        "CXC": "CNSFPAG",
        "CXP": "CNSFCXP",
        "NOTDBCRCXP": "FCXPDBCR",
        "ANTICIPOS": "CNSANT",
        "NOMINA": "NOMINA_PAGO",
        "IACT": "CNSIACTH",
        "FACTURA": "N_FACTURA",
        "NOTDBCR": "CNSFNOT",
        "INV": "CNSMOV",
        "CAJA": "FCJ",
        "LEGALIZACION": "CNSFLEG",
        "CESIONES": "CNSCES",
        "AJDEP": "AJDEP_REF",
        "CONCI": "IDFCONCI",
        "RAD CXC": "CNSCXC",
        "RGLO": "CNSGLO",
        "BMOV": "BMOV_REF",
        "MANUAL": "NROCOMPROBANTE",
        "REVERSOS": "NRO_REV",
    }
    try:
        procs_one = _resolve_procedencias_contab(procedencia) if procedencia else []
    except ValueError:
        procs_one = []
    if len(procs_one) == 1:
        return proc_map.get(procs_one[0].upper(), t) or t
    return t


def _parse_fcj_referencia(referencia: str, server: str, user: str, pwd: str, db: str) -> tuple[str, str]:
    ref = (referencia or "").strip()
    if not ref:
        return "", ""
    if "/" in ref:
        a, b = ref.split("/", 1)
        return a.strip(), b.strip()
    if "|" in ref:
        a, b = ref.split("|", 1)
        return a.strip(), b.strip()
    esc = _esc(ref)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(CODCAJA)) AS CODCAJA, LTRIM(RTRIM(CNSFACJ)) AS CNSFACJ
FROM dbo.FCJ WITH (NOLOCK) WHERE CNSFACJ = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if rows:
        return (rows[0].get("CODCAJA") or "").strip(), (rows[0].get("CNSFACJ") or ref).strip()
    q2 = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(CODCAJA)) AS CODCAJA, LTRIM(RTRIM(CNSFACJ)) AS CNSFACJ
FROM dbo.FPAG WITH (NOLOCK) WHERE CNSFACJ = N'{esc}' AND COALESCE(CODCAJA,'') <> '';
"""
    rows2 = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q2))
    if rows2:
        return (rows2[0].get("CODCAJA") or "").strip(), (rows2[0].get("CNSFACJ") or ref).strip()
    return "", ref


def _parse_cnsfnot_referencia(
    referencia: str, server: str, user: str, pwd: str, db: str
) -> tuple[str, str]:
    cns, clase = _parse_par_referencia(referencia)
    if not cns:
        return "", ""
    if clase:
        return cns, clase
    esc = _esc(cns)
    q = f"""
SET NOCOUNT ON;
SELECT DISTINCT LTRIM(RTRIM(CLASE)) AS CLASE FROM dbo.FNOT WITH (NOLOCK) WHERE CNSFNOT = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if len(rows) == 1:
        return cns, (rows[0].get("CLASE") or "").strip()
    return cns, ""


def _parse_fcxpdbcr_referencia(referencia: str) -> tuple[str, str]:
    cns, item = _parse_par_referencia(referencia)
    return (cns or "").strip(), (item or "").strip()


def _parse_bmov_referencia(
    referencia: str,
    server: str | None = None,
    user: str | None = None,
    pwd: str | None = None,
    db: str | None = None,
) -> tuple[str, str, str, str]:
    ref = (referencia or "").strip()
    if not ref:
        return "", "", "", ""
    parts = re.split(r"[/|]", ref)
    if len(parts) >= 4:
        return parts[0].strip(), parts[1].strip(), parts[2].strip(), parts[3].strip()
    if len(parts) == 2 and server and user and pwd and db:
        ref1, item = parts[0].strip(), parts[1].strip()
        q = f"""
SET NOCOUNT ON;
SELECT TOP 1 BANCO, SUCURSAL, CTA_BCO, CAST(ITEM AS VARCHAR(20)) AS ITEM
FROM dbo.BMOV WITH (NOLOCK)
WHERE (BANCO + SUCURSAL + CTA_BCO) = N'{_esc(ref1)}'
  AND CAST(ITEM AS VARCHAR(20)) = N'{_esc(item)}';
"""
        rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
        if rows:
            r0 = rows[0]
            return (
                (r0.get("BANCO") or "").strip(),
                (r0.get("SUCURSAL") or "").strip(),
                (r0.get("CTA_BCO") or "").strip(),
                (r0.get("ITEM") or item).strip(),
            )
    return "", "", "", ""


def _parse_nomina_referencia(
    referencia: str,
    server: str | None = None,
    user: str | None = None,
    pwd: str | None = None,
    db: str | None = None,
) -> tuple[str, str, str]:
    ref = (referencia or "").strip()
    if not ref:
        return "", "", ""
    parts = re.split(r"[/|]", ref)
    if len(parts) >= 3:
        return parts[0].strip(), parts[1].strip(), parts[2].strip()
    if len(parts) == 2 and server and user and pwd and db:
        numdoc, cnspago = parts[0].strip(), parts[1].strip()
        q = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(CNSNIEPE)) AS CNSNIEPE FROM dbo.NIEPE WITH (NOLOCK)
WHERE NUMDOC = N'{_esc(numdoc)}' AND CNSPAGO = N'{_esc(cnspago)}'
ORDER BY CNSNIEPE DESC;
"""
        rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
        if rows:
            return numdoc, cnspago, (rows[0].get("CNSNIEPE") or "").strip()
        return numdoc, cnspago, ""
    if len(parts) == 1:
        return parts[0].strip(), "", ""
    return "", "", ""


def _parse_cnsant_referencia(
    referencia: str, server: str, user: str, pwd: str, db: str
) -> tuple[str, str]:
    cns, cnsfcom = _parse_par_referencia(referencia)
    if not cns:
        return "", ""
    if cnsfcom:
        return cns, cnsfcom
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(CNSFCOM)) AS CNSFCOM FROM dbo.ANT WITH (NOLOCK) WHERE CNSANT = N'{_esc(cns)}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if rows:
        return cns, (rows[0].get("CNSFCOM") or "").strip()
    return cns, ""


def _checks_documento_cnsfcxp(
    server: str, user: str, pwd: str, db: str, cnsfcxp: str
) -> list[dict]:
    cns = (cnsfcxp or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSFCXP, LTRIM(RTRIM(PROCEDENCIA)) AS PROCEDENCIA,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE,
       FECHA, F_FACTURAREF, CAST(COALESCE(ESTADO,'') AS VARCHAR(20)) AS ESTADO
FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCXP = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fcxp-missing",
                "grupo": "Documento CXP",
                "titulo": f"FCXP {cns}",
                "estado": "ko",
                "validacion": "CxP no existe — grafo N3 fcxp-detalle",
                "filas": [],
                "puntosCriticos": ["PC-CXP-01"],
                "validacionSqlRef": "CNSFCXP",
            }
        )
        return out

    fc = rows[0]
    out.append(
        {
            "id": "doc-fcxp-cab",
            "grupo": "Documento CXP",
            "titulo": "Cabecera FCXP",
            "estado": "ok",
            "validacion": (
                f"PROCEDENCIA={fc.get('PROCEDENCIA') or '?'}"
                f" CONTABILIZADA={fc.get('CONTABILIZADA')} NRO={fc.get('NROCOMPROBANTE') or '—'}"
            ),
            "filas": rows,
            "puntosCriticos": ["PC-CXP-02"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, ESTADO, REFERENCIA1
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXP' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3
UNION ALL
SELECT NROCOMPROBANTE, PROCEDENCIA, ESTADO, REFERENCIA1
FROM dbo.MCPE WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXP' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    st_dup = "ko" if len(dup) > 1 else ("warn" if len(dup) == 1 and not (fc.get("NROCOMPROBANTE") or "").strip() else "ok")
    out.append(
        {
            "id": "doc-fcxp-duplicado",
            "grupo": "Documento CXP",
            "titulo": "Duplicidad MCP CXP",
            "estado": st_dup,
            "validacion": f"{len(dup)} comprobante(s) vigente(s) REFERENCIA1=CNSFCXP",
            "filas": dup[:10],
            "puntosCriticos": ["PC-CXP-03"],
            "validacionSqlRef": "sin-duplicado",
        }
    )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FCXPD FROM dbo.FCXPD WITH (NOLOCK) WHERE CNSFCXP = N'{esc}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_det = int(drows[0].get("N_FCXPD") or 0) if drows else 0
    out.append(
        {
            "id": "doc-fcxpd-lineas",
            "grupo": "Documento CXP",
            "titulo": "Detalle FCXPD",
            "estado": "ok" if n_det > 0 else "ko",
            "validacion": f"{n_det} línea(s) FCXPD",
            "filas": drows,
            "puntosCriticos": ["PC-CXP-01"],
        }
    )

    q_us = """
SET NOCOUNT ON;
SELECT LTRIM(RTRIM(DATO)) AS DATO FROM dbo.USVGS WITH (NOLOCK)
WHERE IDVARIABLE = N'IDCON_FCONTABLE_CXP';
"""
    us_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_us))
    modo = ((us_rows[0].get("DATO") if us_rows else "") or "").strip().upper()
    fecha_expr = "FECHA" if modo == "RADICACION" else "F_FACTURAREF"
    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.{fecha_expr} AS FECHA_CONTABLE
FROM dbo.FCXP F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK)
  ON P.ANO = YEAR(F.{fecha_expr}) AND P.MES = MONTH(F.{fecha_expr})
WHERE F.CNSFCXP = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-fcxp-pri",
                "grupo": "Documento CXP",
                "titulo": f"PRI ({modo or 'F_FACTURAREF'})",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"Periodo {pri_rows[0].get('ANO')}-{pri_rows[0].get('MES')} CERRADO={cerr}",
                "filas": pri_rows,
                "puntosCriticos": ["PC-CXP-01"],
            }
        )

    return out


def _checks_documento_n_factura(
    server: str, user: str, pwd: str, db: str, n_factura: str
) -> list[dict]:
    nf = (n_factura or "").strip()
    if not nf:
        return []
    esc = _esc(nf)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 N_FACTURA, LTRIM(RTRIM(NOREFERENCIA)) AS NOREFERENCIA,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(ESTADO)) AS ESTADO, F_FACTURA,
       LTRIM(RTRIM(TIPOTTEC)) AS TIPOTTEC, LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE
FROM dbo.FTR WITH (NOLOCK) WHERE N_FACTURA = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-ftr-missing",
                "grupo": "Documento FACTURA",
                "titulo": f"FTR {nf}",
                "estado": "ko",
                "validacion": "Factura no existe",
                "filas": [],
                "puntosCriticos": ["PC-FTR-01"],
                "validacionSqlRef": "ftr-vigente",
            }
        )
        return out

    ftr = rows[0]
    est = (ftr.get("ESTADO") or "").strip().upper()
    st_cab = "ko" if est == "A" else "ok"
    out.append(
        {
            "id": "doc-ftr-cab",
            "grupo": "Documento FACTURA",
            "titulo": "Cabecera FTR",
            "estado": st_cab,
            "validacion": f"ESTADO={est} CONTABILIZADA={ftr.get('CONTABILIZADA')} TIPOTTEC={ftr.get('TIPOTTEC') or '?'}",
            "filas": rows,
            "validacionSqlRef": "ftr-vigente",
        }
    )

    noref = (ftr.get("NOREFERENCIA") or "").strip()
    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, NOREFERENCIA, ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'FACTURA'
  AND (NOREFERENCIA = N'{_esc(noref)}' OR REFERENCIA1 = N'{esc}')
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-ftr-duplicado",
            "grupo": "Documento FACTURA",
            "titulo": "Duplicidad MCP FACTURA",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) mismo NOREFERENCIA/N_FACTURA",
            "filas": dup[:8],
            "puntosCriticos": ["PC-FTR-04"],
            "validacionSqlRef": "ftr-no-duplicada",
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.F_FACTURA
FROM dbo.FTR F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(F.F_FACTURA) AND P.MES = MONTH(F.F_FACTURA)
WHERE F.N_FACTURA = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-ftr-pri",
                "grupo": "Documento FACTURA",
                "titulo": "PRI F_FACTURA",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"Periodo factura CERRADO={cerr}",
                "filas": pri_rows,
                "puntosCriticos": ["PC-FTR-02"],
                "validacionSqlRef": "pri-f-factura",
            }
        )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FTRD FROM dbo.FTRD WITH (NOLOCK) WHERE N_FACTURA = N'{esc}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_d = int(drows[0].get("N_FTRD") or 0) if drows else 0
    out.append(
        {
            "id": "doc-ftrd-lineas",
            "grupo": "Documento FACTURA",
            "titulo": "Detalle FTRD",
            "estado": "ok" if n_d > 0 else "ko",
            "validacion": f"{n_d} línea(s) FTRD",
            "filas": drows,
        }
    )

    tt = (ftr.get("TIPOTTEC") or "").strip()
    if tt:
        qt = f"""
SET NOCOUNT ON;
SELECT TOP 1 TIPO, LTRIM(RTRIM(CUENTACG)) AS CUENTACG, LTRIM(RTRIM(CUENTARAD)) AS CUENTARAD
FROM dbo.TTEC WITH (NOLOCK) WHERE TIPO = N'{_esc(tt)}';
"""
        trows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qt))
        bad = not trows or (
            not (trows[0].get("CUENTACG") or "").strip() and not (trows[0].get("CUENTARAD") or "").strip()
        )
        out.append(
            {
                "id": "doc-ftr-ttec",
                "grupo": "Documento FACTURA",
                "titulo": "TTEC factura",
                "estado": "ko" if bad else "ok",
                "validacion": "TIPOTTEC sin CUENTACG/CUENTARAD" if bad else "TTEC con cuentas cartera",
                "filas": trows,
                "puntosCriticos": ["PC-FTR-01"],
            }
        )

    return out


def _checks_documento_cnsmov(
    server: str, user: str, pwd: str, db: str, cnsmov: str
) -> list[dict]:
    cns = (cnsmov or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 I.CNSMOV, CAST(COALESCE(I.ESTADO,0) AS INT) AS ESTADO,
       CAST(COALESCE(I.SECONTABILIZA,0) AS INT) AS SECONTABILIZA,
       CAST(COALESCE(I.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       I.FECHACONF, I.FECHAMOV, LTRIM(RTRIM(I.IDTIPOMOV)) AS IDTIPOMOV,
       LTRIM(RTRIM(I.IDBODEGA)) AS IDBODEGA, LTRIM(RTRIM(I.NROCOMPROBANTE)) AS NROCOMPROBANTE
FROM dbo.IMOV I WITH (NOLOCK) WHERE I.CNSMOV = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-imov-missing",
                "grupo": "Documento INV",
                "titulo": f"IMOV {cns}",
                "estado": "ko",
                "validacion": "Movimiento no existe",
                "filas": [],
                "puntosCriticos": ["PC-INV-01"],
                "validacionSqlRef": "imov-confirmado",
            }
        )
        return out

    im = rows[0]
    est = int(im.get("ESTADO") or 0)
    sec = int(im.get("SECONTABILIZA") or 0)
    st = "ok" if est == 1 and sec == 1 else "ko"
    out.append(
        {
            "id": "doc-imov-estado",
            "grupo": "Documento INV",
            "titulo": "IMOV confirmado / SECONTABILIZA",
            "estado": st,
            "validacion": f"ESTADO={est} SECONTABILIZA={sec} CONTABILIZADA={im.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "imov-confirmado",
        }
    )

    bod = (im.get("IDBODEGA") or "").strip()
    if bod:
        qb = f"""
SET NOCOUNT ON;
SELECT TOP 1 IDBODEGA, COALESCE(NOCONTABILIZA,0) AS NOCONTABILIZA
FROM dbo.IBOD WITH (NOLOCK) WHERE IDBODEGA = N'{_esc(bod)}';
"""
        brows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qb))
        if brows and int(brows[0].get("NOCONTABILIZA") or 0) == 1:
            out.append(
                {
                    "id": "doc-ibod-nocontab",
                    "grupo": "Documento INV",
                    "titulo": "IBOD.NOCONTABILIZA",
                    "estado": "warn",
                    "validacion": "Bodega excluida de contabilización",
                    "filas": brows,
                }
            )

    fc = im.get("FECHACONF")
    if fc:
        q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO
FROM dbo.PRI P WITH (NOLOCK)
WHERE P.ANO = YEAR(CAST(N'{_esc(str(fc))}' AS DATETIME))
  AND P.MES = MONTH(CAST(N'{_esc(str(fc))}' AS DATETIME));
"""
        pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
        if pri_rows:
            cerr = int(pri_rows[0].get("CERRADO") or 0)
            out.append(
                {
                    "id": "doc-imov-pri",
                    "grupo": "Documento INV",
                    "titulo": "PRI FECHACONF",
                    "estado": "ok" if cerr == 0 else "ko",
                    "validacion": f"Periodo confirmación CERRADO={cerr} (grilla OM usa FECHAMOV)",
                    "filas": pri_rows,
                    "puntosCriticos": ["PC-INV-02"],
                }
            )

    return out


def _checks_documento_fcj(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    cod, cfj = _parse_fcj_referencia(referencia, server, user, pwd, db)
    if not cfj:
        return []
    out: list[dict] = []
    if not cod:
        out.append(
            {
                "id": "doc-fcj-parse",
                "grupo": "Documento CAJA",
                "titulo": "Referencia FCJ",
                "estado": "warn",
                "validacion": "Indique CODCAJA/CNSFACJ — no se resolvió CODCAJA",
                "filas": [],
                "puntosCriticos": ["PC-CAJ-01"],
            }
        )
        return out

    esc_c = _esc(cod)
    esc_f = _esc(cfj)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CODCAJA, CNSFACJ, LTRIM(RTRIM(ESTADO)) AS ESTADO,
       CAST(COALESCE(CERRADA,0) AS INT) AS CERRADA,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE, FECHA
FROM dbo.FCJ WITH (NOLOCK)
WHERE CODCAJA = N'{esc_c}' AND CNSFACJ = N'{esc_f}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fcj-missing",
                "grupo": "Documento CAJA",
                "titulo": f"FCJ {cod}/{cfj}",
                "estado": "ko",
                "validacion": "Recibo no existe",
                "filas": [],
                "puntosCriticos": ["PC-CAJ-03"],
            }
        )
        return out

    fcj_row = rows[0]
    est = (fcj_row.get("ESTADO") or "").strip().upper()
    out.append(
        {
            "id": "doc-fcj-cab",
            "grupo": "Documento CAJA",
            "titulo": "Cabecera FCJ",
            "estado": "ok" if est == "P" else "warn",
            "validacion": f"ESTADO={est} CERRADA={fcj_row.get('CERRADA')} CONTABILIZADA={fcj_row.get('CONTABILIZADA')}",
            "filas": rows,
            "puntosCriticos": ["PC-CAJ-01", "PC-CAJ-03"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CAJA' AND REFERENCIA1 = N'{esc_f}' AND REFERENCIA2 = N'{esc_c}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fcj-mcp-dup",
            "grupo": "Documento CAJA",
            "titulo": "Duplicidad MCP CAJA",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP CAJA vigente(s) REF1/REF2 recibo",
            "filas": dup[:5],
            "puntosCriticos": ["PC-CAJ-03"],
        }
    )

    q_pcj = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_PCJ, SUM(COALESCE(VALOR,0)) AS SUMA_PCJ FROM dbo.PCJ WITH (NOLOCK)
WHERE CODCAJA = N'{esc_c}' AND CNSFACJ = N'{esc_f}';
"""
    pcj = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pcj))
    n_pcj = int(pcj[0].get("N_PCJ") or 0) if pcj else 0
    out.append(
        {
            "id": "doc-fcj-pcj",
            "grupo": "Documento CAJA",
            "titulo": "Formas de pago PCJ",
            "estado": "ok" if n_pcj > 0 else "ko",
            "validacion": f"{n_pcj} línea(s) PCJ",
            "filas": pcj,
            "puntosCriticos": ["PC-CAJ-05"],
        }
    )

    return out


def _checks_documento_cnsfnot(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    cns, clase = _parse_cnsfnot_referencia(referencia, server, user, pwd, db)
    if not cns:
        return []
    out: list[dict] = []
    if not clase:
        out.append(
            {
                "id": "doc-fnot-parse",
                "grupo": "Documento NOTDBCR",
                "titulo": "Referencia FNOT",
                "estado": "warn",
                "validacion": "Indique CNSFNOT/CLASE (REFERENCIA2 en MCP) o un solo CLASE en BD",
                "filas": [],
                "puntosCriticos": ["PC-NOT-01"],
            }
        )
        return out

    esc_c = _esc(cns)
    esc_cl = _esc(clase)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSFNOT, LTRIM(RTRIM(CLASE)) AS CLASE, LTRIM(RTRIM(N_FACTURA)) AS N_FACTURA,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       CAST(COALESCE(CERRADA,0) AS INT) AS CERRADA,
       LTRIM(RTRIM(ESTADO)) AS ESTADO, F_NOTA, VR_TOTAL,
       LTRIM(RTRIM(IDCONCEPTO)) AS IDCONCEPTO,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE
FROM dbo.FNOT WITH (NOLOCK) WHERE CNSFNOT = N'{esc_c}' AND CLASE = N'{esc_cl}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fnot-missing",
                "grupo": "Documento NOTDBCR",
                "titulo": f"FNOT {cns}/{clase}",
                "estado": "ko",
                "validacion": "Nota no existe — grafo N3 fnot-aplicada",
                "filas": [],
                "puntosCriticos": ["PC-NOT-01"],
                "validacionSqlRef": "fnot-aplicada",
            }
        )
        return out

    fn = rows[0]
    est = (fn.get("ESTADO") or "").strip().upper()
    cerr = int(fn.get("CERRADA") or 0)
    cont = int(fn.get("CONTABILIZADA") or 0)
    st_cab = "ko" if est == "A" else "ok"
    out.append(
        {
            "id": "doc-fnot-cab",
            "grupo": "Documento NOTDBCR",
            "titulo": "Cabecera FNOT",
            "estado": st_cab,
            "validacion": f"ESTADO={est} CERRADA={cerr} CONTABILIZADA={cont} VR_TOTAL={fn.get('VR_TOTAL')}",
            "filas": rows,
            "validacionSqlRef": "fnot-aplicada",
        }
    )
    out.append(
        {
            "id": "doc-fnot-aplicada",
            "grupo": "Documento NOTDBCR",
            "titulo": "Nota aplicada (CERRADA)",
            "estado": "ok" if cerr == 1 else "ko",
            "validacion": f"CERRADA={cerr} (grafa exige aplicada antes de contabilizar)",
            "filas": [],
            "puntosCriticos": ["PC-NOT-01"],
            "validacionSqlRef": "fnot-aplicada",
        }
    )
    if cont == 1:
        out.append(
            {
                "id": "doc-fnot-ya-contab",
                "grupo": "Documento NOTDBCR",
                "titulo": "Ya contabilizada",
                "estado": "warn",
                "validacion": f"CONTABILIZADA=1 NRO={fn.get('NROCOMPROBANTE') or '?'}",
                "filas": rows,
            }
        )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'NOTDBCR' AND REFERENCIA1 = N'{esc_c}' AND REFERENCIA2 = N'{esc_cl}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fnot-mcp-dup",
            "grupo": "Documento NOTDBCR",
            "titulo": "Duplicidad MCP NOTDBCR",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REF1/REF2 nota",
            "filas": dup[:5],
            "validacionSqlRef": "fnot-unica-mcp",
        }
    )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FNOTD, SUM(COALESCE(VR_TOTAL,0)) AS SUMA FROM dbo.FNOTD WITH (NOLOCK)
WHERE CNSFNOT = N'{esc_c}' AND CLASE = N'{esc_cl}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_d = int(drows[0].get("N_FNOTD") or 0) if drows else 0
    out.append(
        {
            "id": "doc-fnotd-lineas",
            "grupo": "Documento NOTDBCR",
            "titulo": "Detalle FNOTD",
            "estado": "ok" if n_d > 0 else "ko",
            "validacion": f"{n_d} línea(s) FNOTD",
            "filas": drows,
        }
    )

    conc = (fn.get("IDCONCEPTO") or "").strip()
    if conc:
        qc = f"""
SET NOCOUNT ON;
SELECT TOP 1 CODIGO, LTRIM(RTRIM(CUENTA)) AS CUENTA FROM dbo.CPNT WITH (NOLOCK) WHERE CODIGO = N'{_esc(conc)}';
"""
        crows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qc))
        bad = not crows or not (crows[0].get("CUENTA") or "").strip()
        out.append(
            {
                "id": "doc-fnot-cpnt",
                "grupo": "Documento NOTDBCR",
                "titulo": "Concepto CPNT",
                "estado": "ko" if bad else "ok",
                "validacion": f"IDCONCEPTO={conc}" + (" sin cuenta" if bad else ""),
                "filas": crows,
                "puntosCriticos": ["PC-NOT-02"],
                "validacionSqlRef": "cpnt-cuenta",
            }
        )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.F_NOTA
FROM dbo.FNOT F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(F.F_NOTA) AND P.MES = MONTH(F.F_NOTA)
WHERE F.CNSFNOT = N'{esc_c}' AND F.CLASE = N'{esc_cl}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr_p = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-fnot-pri",
                "grupo": "Documento NOTDBCR",
                "titulo": "PRI F_NOTA",
                "estado": "ok" if cerr_p == 0 else "ko",
                "validacion": f"Periodo nota CERRADO={cerr_p}",
                "filas": pri_rows,
                "validacionSqlRef": "pri-f-nota",
            }
        )

    return out


def _checks_documento_fcxpdbcr(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    cnsfcxp, item = _parse_fcxpdbcr_referencia(referencia)
    if not cnsfcxp:
        return []
    out: list[dict] = []
    if not item:
        out.append(
            {
                "id": "doc-fcxpdbcr-parse",
                "grupo": "Documento NOTDBCRCXP",
                "titulo": "Referencia FCXPDBCR",
                "estado": "warn",
                "validacion": "Indique CNSFCXP/ITEM (REFERENCIA2 en MCP NOTDBCRCXP)",
                "filas": [],
                "puntosCriticos": ["PC-NOTCXP-01"],
            }
        )
        return out

    esc_x = _esc(cnsfcxp)
    esc_i = _esc(item)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 D.CNSFCXP, D.ITEM, LTRIM(RTRIM(D.PROCEDENCIA)) AS PROCEDENCIA,
       CAST(COALESCE(D.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(D.NROCOMPROBANTE)) AS NROCOMPROBANTE, D.VALOR, D.VLR_NETO,
       CAST(COALESCE(X.CONTABILIZADA,0) AS INT) AS FCXP_CONTABILIZADA,
       LTRIM(RTRIM(X.NROCOMPROBANTE)) AS FCXP_NRO
FROM dbo.FCXPDBCR D WITH (NOLOCK)
INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = D.CNSFCXP
WHERE D.CNSFCXP = N'{esc_x}' AND CAST(D.ITEM AS VARCHAR(20)) = N'{esc_i}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fcxpdbcr-missing",
                "grupo": "Documento NOTDBCRCXP",
                "titulo": f"FCXPDBCR {cnsfcxp}/{item}",
                "estado": "ko",
                "validacion": "Línea nota CxP no existe",
                "filas": [],
                "validacionSqlRef": "fcxpdbcr",
            }
        )
        return out

    row = rows[0]
    fcxp_cont = int(row.get("FCXP_CONTABILIZADA") or 0)
    out.append(
        {
            "id": "doc-fcxpdbcr-cab",
            "grupo": "Documento NOTDBCRCXP",
            "titulo": "Línea FCXPDBCR",
            "estado": "ok",
            "validacion": f"PROCEDENCIA={row.get('PROCEDENCIA')} CONTABILIZADA={row.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "fcxpdbcr",
        }
    )
    out.append(
        {
            "id": "doc-fcxpdbcr-mcp-cxp",
            "grupo": "Documento NOTDBCRCXP",
            "titulo": "CxP origen contabilizada",
            "estado": "ok" if fcxp_cont != 0 else "ko",
            "validacion": f"FCXP CONTABILIZADA={fcxp_cont} NRO={row.get('FCXP_NRO') or '?'}",
            "filas": [],
            "validacionSqlRef": "fcxp-mcp-previo",
            "puntosCriticos": ["PC-NOTCXP-02"],
        }
    )

    q_cxp_mcp = f"""
SET NOCOUNT ON;
SELECT TOP 3 NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CXP' AND REFERENCIA1 = N'{esc_x}' AND COALESCE(ESTADO,0) <> 3;
"""
    mcp_cxp = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxp_mcp))
    out.append(
        {
            "id": "doc-fcxpdbcr-mcp-cxp-vig",
            "grupo": "Documento NOTDBCRCXP",
            "titulo": "MCP CXP previo",
            "estado": "ok" if mcp_cxp else "warn",
            "validacion": f"{len(mcp_cxp)} MCP CXP vigente(s) REFERENCIA1",
            "filas": mcp_cxp,
            "validacionSqlRef": "fcxp-mcp-previo",
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'NOTDBCRCXP' AND REFERENCIA1 = N'{esc_x}' AND REFERENCIA2 = N'{esc_i}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fcxpdbcr-mcp-dup",
            "grupo": "Documento NOTDBCRCXP",
            "titulo": "Duplicidad MCP NOTDBCRCXP",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) nota CxP",
            "filas": dup[:5],
        }
    )

    proc = (row.get("PROCEDENCIA") or "").strip().upper()
    if proc == "INV":
        q_imov = f"""
SET NOCOUNT ON;
SELECT COUNT(DISTINCT LTRIM(RTRIM(N_PRESUP))) AS N_IMOV
FROM dbo.FCXPD WITH (NOLOCK) WHERE CNSFCXP = N'{esc_x}';
"""
        im = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_imov))
        n_im = int(im[0].get("N_IMOV") or 0) if im else 0
        out.append(
            {
                "id": "doc-fcxpdbcr-imov-unico",
                "grupo": "Documento NOTDBCRCXP",
                "titulo": "IMOV único (nota inventario)",
                "estado": "ok" if n_im <= 1 else "warn",
                "validacion": f"{n_im} CNSMOV distinto(s) en FCXPD de la CxP",
                "filas": im,
                "validacionSqlRef": "imov-unico",
            }
        )

    return out


def _checks_documento_idfconci(
    server: str, user: str, pwd: str, db: str, idfconci: str
) -> list[dict]:
    cid = (idfconci or "").strip()
    if not cid:
        return []
    esc = _esc(cid)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 IDFCONCI, CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE, FECHA, LTRIM(RTRIM(ESTADO)) AS ESTADO
FROM dbo.FCONCI WITH (NOLOCK) WHERE IDFCONCI = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fconci-missing",
                "grupo": "Documento CONCI",
                "titulo": f"FCONCI {cid}",
                "estado": "ko",
                "validacion": "Conciliación no existe",
                "filas": [],
                "validacionSqlRef": "fconci-ref",
            }
        )
        return out

    cab = rows[0]
    out.append(
        {
            "id": "doc-fconci-cab",
            "grupo": "Documento CONCI",
            "titulo": "Cabecera FCONCI",
            "estado": "ok",
            "validacion": f"ESTADO={cab.get('ESTADO')} CONTABILIZADA={cab.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "fconci-ref",
        }
    )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_DET,
       SUM(CASE WHEN COALESCE(VLRRECUPERAR,0) > 0 THEN 1 ELSE 0 END) AS N_RECUP,
       SUM(COALESCE(VLRRECUPERAR,0)) AS SUMA_RECUP
FROM dbo.FCONCID WITH (NOLOCK) WHERE IDFCONCI = N'{esc}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_rec = int(drows[0].get("N_RECUP") or 0) if drows else 0
    out.append(
        {
            "id": "doc-fconci-det",
            "grupo": "Documento CONCI",
            "titulo": "Detalle FCONCID (VLRRECUPERAR)",
            "estado": "ok" if n_rec > 0 else "ko",
            "validacion": f"{n_rec} línea(s) con VLRRECUPERAR>0",
            "filas": drows,
            "validacionSqlRef": "fconci-ref",
            "puntosCriticos": ["PC-CONCI-01"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CONCI' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fconci-mcp-dup",
            "grupo": "Documento CONCI",
            "titulo": "Duplicidad MCP CONCI",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REFERENCIA1",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.FECHA
FROM dbo.FCONCI F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(F.FECHA) AND P.MES = MONTH(F.FECHA)
WHERE F.IDFCONCI = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr_p = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-fconci-pri",
                "grupo": "Documento CONCI",
                "titulo": "PRI fecha conciliación",
                "estado": "ok" if cerr_p == 0 else "ko",
                "validacion": f"Periodo CERRADO={cerr_p}",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_cnscxc(
    server: str, user: str, pwd: str, db: str, cnscxc: str
) -> list[dict]:
    cns = (cnscxc or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSCXC, CAST(COALESCE(INDRECIBIDO,0) AS INT) AS INDRECIBIDO,
       F_RECIBIDO, LTRIM(RTRIM(IDTERCERO)) AS IDTERCERO,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE
FROM dbo.FCXC WITH (NOLOCK) WHERE CNSCXC = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fcxc-missing",
                "grupo": "Documento RAD CXC",
                "titulo": f"FCXC {cns}",
                "estado": "ko",
                "validacion": "Radicación no existe — grafo fcxc-radicada",
                "filas": [],
                "puntosCriticos": ["PC-RAD-01"],
                "validacionSqlRef": "fcxc-radicada",
            }
        )
        return out

    fc = rows[0]
    ind = int(fc.get("INDRECIBIDO") or 0)
    out.append(
        {
            "id": "doc-fcxc-cab",
            "grupo": "Documento RAD CXC",
            "titulo": "Cabecera FCXC",
            "estado": "ok" if ind == 1 else "warn",
            "validacion": f"INDRECIBIDO={ind} CONTABILIZADA={fc.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "fcxc-radicada",
        }
    )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FCXCD, SUM(CASE WHEN COALESCE(SALDO,0) > 0 THEN 1 ELSE 0 END) AS N_SALDO_POS
FROM dbo.FCXCD WITH (NOLOCK) WHERE CNSCXC = N'{esc}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_d = int(drows[0].get("N_FCXCD") or 0) if drows else 0
    out.append(
        {
            "id": "doc-fcxc-det",
            "grupo": "Documento RAD CXC",
            "titulo": "Detalle FCXCD",
            "estado": "ok" if n_d > 0 else "ko",
            "validacion": f"{n_d} factura(s) en radicación",
            "filas": drows,
        }
    )

    q_ftr_mcp = f"""
SET NOCOUNT ON;
SELECT TOP 5 D.N_FACTURA, F.CONTABILIZADA AS FTR_CONTAB, F.NROCOMPROBANTE AS FTR_NRO,
       (SELECT COUNT(*) FROM dbo.MCP M WITH (NOLOCK)
        WHERE M.PROCEDENCIA = N'FACTURA' AND (M.REFERENCIA1 = D.N_FACTURA OR M.NOREFERENCIA = F.NOREFERENCIA)
          AND COALESCE(M.ESTADO,0) <> 3) AS N_MCP_FACTURA
FROM dbo.FCXCD D WITH (NOLOCK)
INNER JOIN dbo.FTR F WITH (NOLOCK) ON F.N_FACTURA = D.N_FACTURA
WHERE D.CNSCXC = N'{esc}';
"""
    ftr_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ftr_mcp))
    sin_mcp = [r for r in ftr_rows if int(r.get("N_MCP_FACTURA") or 0) == 0]
    out.append(
        {
            "id": "doc-fcxc-ftr-mcp",
            "grupo": "Documento RAD CXC",
            "titulo": "MCP FACTURA previo (muestra)",
            "estado": "ko" if sin_mcp and ftr_rows else "ok" if ftr_rows else "warn",
            "validacion": f"{len(sin_mcp)} de {len(ftr_rows)} factura(s) sin MCP FACTURA vigente",
            "filas": ftr_rows,
            "validacionSqlRef": "ftr-factura-mcp",
            "puntosCriticos": ["PC-RAD-02"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'RAD CXC' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fcxc-mcp-dup",
            "grupo": "Documento RAD CXC",
            "titulo": "Duplicidad MCP RAD CXC",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) radicación",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, X.F_RECIBIDO
FROM dbo.FCXC X WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(X.F_RECIBIDO) AND P.MES = MONTH(X.F_RECIBIDO)
WHERE X.CNSCXC = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr_p = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-fcxc-pri",
                "grupo": "Documento RAD CXC",
                "titulo": "PRI F_RECIBIDO",
                "estado": "ok" if cerr_p == 0 else "ko",
                "validacion": f"Periodo radicación CERRADO={cerr_p}",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_bmov(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    banco, suc, cta, item = _parse_bmov_referencia(referencia, server, user, pwd, db)
    if not banco:
        return [
            {
                "id": "doc-bmov-parse",
                "grupo": "Documento BMOV",
                "titulo": "Referencia banco",
                "estado": "warn",
                "validacion": "Formato BANCO/SUCURSAL/CTA_BCO/ITEM o REFERENCIA1/ITEM (MCP)",
                "filas": [],
                "puntosCriticos": ["PC-BMOV-01"],
            }
        ]
    out: list[dict] = []
    esc_b, esc_s, esc_c = _esc(banco), _esc(suc), _esc(cta)
    item_i = int(item) if str(item).isdigit() else 0
    ref1 = f"{banco}{suc}{cta}"
    esc_ref1 = _esc(ref1)
    esc_item = _esc(str(item))

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 M.BANCO, M.SUCURSAL, M.CTA_BCO, M.ITEM,
       LTRIM(RTRIM(COALESCE(M.ESTADO,''))) AS ESTADO,
       LTRIM(RTRIM(COALESCE(M.IDOPERACION,''))) AS IDOPERACION,
       M.FECHAOK, M.FECHAOPERACION,
       CAST(COALESCE(M.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(M.NROCOMPROBANTE,''))) AS NROCOMPROBANTE
FROM dbo.BMOV M WITH (NOLOCK)
WHERE M.BANCO = N'{esc_b}' AND M.SUCURSAL = N'{esc_s}' AND M.CTA_BCO = N'{esc_c}' AND M.ITEM = {item_i};
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-bmov-missing",
                "grupo": "Documento BMOV",
                "titulo": f"BMOV {banco}/{suc}/{cta}/{item}",
                "estado": "ko",
                "validacion": "Movimiento banco no existe",
                "filas": [],
                "validacionSqlRef": "bmov-confirmado",
            }
        )
        return out

    bm = rows[0]
    est = (bm.get("ESTADO") or "").strip().upper()
    out.append(
        {
            "id": "doc-bmov-cab",
            "grupo": "Documento BMOV",
            "titulo": "Cabecera BMOV",
            "estado": "ok" if est == "O" else "warn",
            "validacion": f"ESTADO={est} IDOPERACION={bm.get('IDOPERACION')} CONTABILIZADA={bm.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "bmov-confirmado",
            "puntosCriticos": ["PC-BMOV-01"],
        }
    )

    q_sum = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_LINEAS, SUM(COALESCE(VLRITEM,0)) AS SUMA_VLR
FROM dbo.BMOVD WITH (NOLOCK)
WHERE BANCO = N'{esc_b}' AND SUCURSAL = N'{esc_s}' AND CTA_BCO = N'{esc_c}' AND ITEM = {item_i};
"""
    srows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sum))
    n_lin = int(srows[0].get("N_LINEAS") or 0) if srows else 0
    out.append(
        {
            "id": "doc-bmovd-sum",
            "grupo": "Documento BMOV",
            "titulo": "Detalle BMOVD",
            "estado": "ok" if n_lin > 0 else "ko",
            "validacion": f"{n_lin} línea(s); Σ VLRITEM={srows[0].get('SUMA_VLR') if srows else 0}",
            "filas": srows,
            "validacionSqlRef": "bmov-confirmado",
        }
    )

    q_bct = f"""
SET NOCOUNT ON;
SELECT TOP 1 B.COD_CONTABLE, U.TIPO AS CUE_TIPO
FROM dbo.BCT B WITH (NOLOCK)
LEFT JOIN dbo.CUE U WITH (NOLOCK) ON U.CUENTA = B.COD_CONTABLE
WHERE B.BANCO = N'{esc_b}' AND B.SUCURSAL = N'{esc_s}' AND B.CTA_BCO = N'{esc_c}';
"""
    bct = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_bct))
    bad_bct = not bct or not (bct[0].get("COD_CONTABLE") or "").strip()
    if not bad_bct:
        bad_bct = (bct[0].get("CUE_TIPO") or "").strip() != "Detalle"
    out.append(
        {
            "id": "doc-bmov-bct",
            "grupo": "Documento BMOV",
            "titulo": "BCT → CUE Detalle",
            "estado": "ko" if bad_bct else "ok",
            "validacion": "COD_CONTABLE vacío o no Detalle" if bad_bct else "Cuenta banco contable OK",
            "filas": bct,
            "validacionSqlRef": "bct-cue",
            "puntosCriticos": ["PC-BMOV-01"],
        }
    )

    idop = (bm.get("IDOPERACION") or "").strip()
    if idop:
        q_of = f"""
SET NOCOUNT ON;
SELECT TOP 1 IDOPERACION, LTRIM(RTRIM(COMPROBANTE)) AS COMPROBANTE, LTRIM(RTRIM(CUENTA)) AS CUENTA
FROM dbo.OFIN WITH (NOLOCK) WHERE IDOPERACION = N'{_esc(idop)}';
"""
        ofin = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_of))
        bad_o = not ofin or not (ofin[0].get("COMPROBANTE") or "").strip() or not (ofin[0].get("CUENTA") or "").strip()
        out.append(
            {
                "id": "doc-bmov-ofin",
                "grupo": "Documento BMOV",
                "titulo": "OFIN operación",
                "estado": "ko" if bad_o else "ok",
                "validacion": f"IDOPERACION={idop}",
                "filas": ofin,
                "validacionSqlRef": "ofin",
                "puntosCriticos": ["PC-BMOV-02"],
            }
        )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'BMOV' AND REFERENCIA1 = N'{esc_ref1}' AND REFERENCIA2 = N'{esc_item}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-bmov-mcp-dup",
            "grupo": "Documento BMOV",
            "titulo": "Duplicidad MCP BMOV",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REF1+ITEM",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, COALESCE(M.FECHAOK, M.FECHAOPERACION) AS FECHA_PRI
FROM dbo.BMOV M WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK)
  ON P.ANO = YEAR(COALESCE(M.FECHAOK, M.FECHAOPERACION))
 AND P.MES = MONTH(COALESCE(M.FECHAOK, M.FECHAOPERACION))
WHERE M.BANCO = N'{esc_b}' AND M.SUCURSAL = N'{esc_s}' AND M.CTA_BCO = N'{esc_c}' AND M.ITEM = {item_i};
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-bmov-pri",
                "grupo": "Documento BMOV",
                "titulo": "PRI FECHAOK/operación",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"Periodo CERRADO={cerr}",
                "filas": pri_rows,
                "validacionSqlRef": "pri-fechaok",
            }
        )

    return out


def _checks_documento_nro_comprobante(
    server: str,
    user: str,
    pwd: str,
    db: str,
    nro_comprobante: str,
    procedencia_esperada: str | None = None,
) -> list[dict]:
    nro = (nro_comprobante or "").strip()
    if not nro:
        return []
    esc = _esc(nro)
    proc_exp = (procedencia_esperada or "").strip().upper()
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       TOTALDEBITO, TOTALCREDITO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}'
UNION ALL
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       TOTALDEBITO, TOTALCREDITO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not cab:
        out.append(
            {
                "id": "doc-mcp-missing",
                "grupo": "Comprobante",
                "titulo": nro,
                "estado": "ko",
                "validacion": "No está en MCP ni MCPE",
                "filas": [],
            }
        )
        return out

    row = cab[0]
    proc = (row.get("PROCEDENCIA") or "").strip().upper()
    st = "ok"
    if proc_exp and proc != proc_exp:
        st = "warn"
    elif proc_exp == "MANUAL" and proc not in ("MANUAL", "MCP"):
        st = "warn" if proc else "ko"
    out.append(
        {
            "id": "doc-mcp-cab",
            "grupo": "Comprobante",
            "titulo": "Cabecera MCP/MCPE",
            "estado": st,
            "validacion": f"{row.get('ORIGEN')} PROCEDENCIA={proc} ESTADO={row.get('ESTADO')}",
            "filas": cab,
        }
    )

    q_cuadre = f"""
SET NOCOUNT ON;
SELECT SUM(CASE WHEN TIPO IN (N'DB', N'D') THEN COALESCE(VALOR,0) ELSE 0 END) AS DEB,
       SUM(CASE WHEN TIPO IN (N'CR', N'C') THEN COALESCE(VALOR,0) ELSE 0 END) AS CRE
FROM dbo.MCHE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    cuadre = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cuadre))
    deb = float(cuadre[0].get("DEB") or 0) if cuadre else 0.0
    cre = float(cuadre[0].get("CRE") or 0) if cuadre else 0.0
    dif = deb - cre
    out.append(
        {
            "id": "doc-mch-cuadre",
            "grupo": "Comprobante",
            "titulo": "Cuadre MCH",
            "estado": "ok" if abs(dif) < 0.02 else "ko",
            "validacion": f"DB={deb:.2f} CR={cre:.2f} Δ={dif:.2f}",
            "filas": cuadre,
            "validacionSqlRef": "cuadre",
        }
    )

    q_bad = f"""
SET NOCOUNT ON;
SELECT TOP 10 M.CUENTA, M.TIPO, M.VALOR, U.TIPO AS CUE_TIPO
FROM dbo.MCHE M WITH (NOLOCK)
LEFT JOIN dbo.CUE U WITH (NOLOCK) ON U.CUENTA = M.CUENTA
WHERE M.NROCOMPROBANTE = N'{esc}' AND (U.CUENTA IS NULL OR U.TIPO <> N'Detalle');
"""
    bad = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_bad))
    out.append(
        {
            "id": "doc-mch-cue",
            "grupo": "Comprobante",
            "titulo": "MCH cuentas Detalle",
            "estado": "ko" if bad else "ok",
            "validacion": f"{len(bad)} línea(s) sin CUE Detalle" if bad else "Cuentas Detalle OK",
            "filas": bad,
            "validacionSqlRef": "mch-detalle",
        }
    )

    return out


def _checks_documento_nomina_pago(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    numdoc, cnspago, cnsniepe = _parse_nomina_referencia(referencia, server, user, pwd, db)
    if not numdoc or not cnspago:
        return [
            {
                "id": "doc-nom-parse",
                "grupo": "Documento NOMINA",
                "titulo": "Referencia nómina",
                "estado": "warn",
                "validacion": "Indique NUMDOC/CNSPAGO/CNSNIEPE (MCP REF1/2/3)",
                "filas": [],
                "puntosCriticos": ["PC-NOM-01"],
            }
        ]
    out: list[dict] = []
    if not cnsniepe:
        out.append(
            {
                "id": "doc-nom-parse-niepe",
                "grupo": "Documento NOMINA",
                "titulo": "CNSNIEPE",
                "estado": "warn",
                "validacion": "Falta CNSNIEPE — use 3 segmentos o NUMDOC/CNSPAGO único en BD",
                "filas": [],
            }
        )
        return out

    esc_n = _esc(numdoc)
    esc_p = _esc(cnspago)
    esc_e = _esc(cnsniepe)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 NIEPE.CNSNIEPE, NIEPE.CNSPAGO, NIEPE.NUMDOC, NIEPE.CODNOMINA,
       CAST(COALESCE(NIEPE.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(NIEPE.NROCOMPROBANTE,''))) AS NROCOMPROBANTE
FROM dbo.NIEPE WITH (NOLOCK)
WHERE NUMDOC = N'{esc_n}' AND CNSPAGO = N'{esc_p}' AND CNSNIEPE = N'{esc_e}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-nom-missing",
                "grupo": "Documento NOMINA",
                "titulo": f"NIEPE {numdoc}/{cnspago}/{cnsniepe}",
                "estado": "ko",
                "validacion": "Pago nómina no existe — grafo lote-nom",
                "filas": [],
                "validacionSqlRef": "lote-nom",
            }
        )
        return out

    out.append(
        {
            "id": "doc-nom-cab",
            "grupo": "Documento NOMINA",
            "titulo": "Cabecera NIEPE",
            "estado": "ok",
            "validacion": f"CODNOMINA={rows[0].get('CODNOMINA')} CONTABILIZADA={rows[0].get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "lote-nom",
        }
    )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_NIEPED FROM dbo.NIEPED WITH (NOLOCK)
WHERE NUMDOC = N'{esc_n}' AND CNSNIEPE = N'{esc_e}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_d = int(drows[0].get("N_NIEPED") or 0) if drows else 0
    out.append(
        {
            "id": "doc-nom-nieped",
            "grupo": "Documento NOMINA",
            "titulo": "Detalle NIEPED",
            "estado": "ok" if n_d > 0 else "ko",
            "validacion": f"{n_d} línea(s) concepto",
            "filas": drows,
        }
    )

    q_con = f"""
SET NOCOUNT ON;
SELECT TOP 8 D.CODCONCEPTO, LTRIM(RTRIM(COALESCE(N.CODCONCEPTO,''))) AS NCON_OK
FROM dbo.NIEPED D WITH (NOLOCK)
LEFT JOIN dbo.NCON N WITH (NOLOCK) ON N.CODCONCEPTO = D.CODCONCEPTO
WHERE D.NUMDOC = N'{esc_n}' AND D.CNSNIEPE = N'{esc_e}';
"""
    crows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_con))
    sin = [r for r in crows if not (r.get("NCON_OK") or "").strip()]
    out.append(
        {
            "id": "doc-nom-conceptos",
            "grupo": "Documento NOMINA",
            "titulo": "Conceptos NCON (muestra)",
            "estado": "ko" if sin else "ok",
            "validacion": f"{len(sin)} concepto(s) sin fila NCON" if sin else "Conceptos en catálogo NCON",
            "filas": crows,
            "validacionSqlRef": "conceptos-cuenta",
            "puntosCriticos": ["PC-NOM-02"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, REFERENCIA3,
       CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'NOMINA' AND REFERENCIA1 = N'{esc_n}' AND REFERENCIA2 = N'{esc_p}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-nom-mcp-dup",
            "grupo": "Documento NOMINA",
            "titulo": "Duplicidad MCP NOMINA",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REF1/2",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO
FROM dbo.NIEPE E WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(GETDATE()) AND P.MES = MONTH(GETDATE())
WHERE E.NUMDOC = N'{esc_n}' AND E.CNSPAGO = N'{esc_p}' AND E.CNSNIEPE = N'{esc_e}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-nom-pri",
                "grupo": "Documento NOMINA",
                "titulo": "PRI (mes actual ref.)",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"CERRADO={cerr} — validar FECHACONTABLE del pago",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_cnsant(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    cnsant, cnsfcom = _parse_cnsant_referencia(referencia, server, user, pwd, db)
    if not cnsant:
        return []
    out: list[dict] = []
    if not cnsfcom:
        out.append(
            {
                "id": "doc-ant-parse",
                "grupo": "Documento ANTICIPOS",
                "titulo": "CNSFCOM",
                "estado": "warn",
                "validacion": "Indique CNSANT/CNSFCOM (REFERENCIA2 MCP)",
                "filas": [],
            }
        )
        return out

    esc_a = _esc(cnsant)
    esc_f = _esc(cnsfcom)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 A.CNSANT, A.CNSFCOM, LTRIM(RTRIM(COALESCE(A.CNSFCXP,''))) AS CNSFCXP,
       CAST(COALESCE(A.CRUCETER,0) AS INT) AS CRUCETER,
       CAST(COALESCE(A.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(A.ESTADO,''))) AS ESTADO,
       COALESCE(A.VALOR_LEG,0) AS VALOR_LEG, A.FECHA,
       LTRIM(RTRIM(COALESCE(A.NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       F.TIPOANTICIPO, F.IDTERCERO
FROM dbo.ANT A WITH (NOLOCK)
INNER JOIN dbo.FCOM F WITH (NOLOCK) ON F.CNSFCOM = A.CNSFCOM
WHERE A.CNSANT = N'{esc_a}' AND A.CNSFCOM = N'{esc_f}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-ant-missing",
                "grupo": "Documento ANTICIPOS",
                "titulo": f"ANT {cnsant}/{cnsfcom}",
                "estado": "ko",
                "validacion": "Anticipo no existe",
                "filas": [],
                "validacionSqlRef": "anticipo-ref",
            }
        )
        return out

    ant = rows[0]
    out.append(
        {
            "id": "doc-ant-cab",
            "grupo": "Documento ANTICIPOS",
            "titulo": "Cabecera ANT",
            "estado": "ok",
            "validacion": f"ESTADO={ant.get('ESTADO')} VALOR_LEG={ant.get('VALOR_LEG')} CONTAB={ant.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "anticipo-ref",
        }
    )

    tipo = (ant.get("TIPOANTICIPO") or "").strip()
    if tipo:
        qt = f"""
SET NOCOUNT ON;
SELECT TOP 1 TIPOANTICIPO, LTRIM(RTRIM(CUEDEBITO)) AS CUEDEBITO,
       LTRIM(RTRIM(CUECREDITO)) AS CUECREDITO, LTRIM(RTRIM(COMPROBANTE)) AS COMPROBANTE
FROM dbo.TANT WITH (NOLOCK) WHERE TIPOANTICIPO = N'{_esc(tipo)}';
"""
        trows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qt))
        bad = not trows or not (trows[0].get("CUEDEBITO") or "").strip()
        out.append(
            {
                "id": "doc-ant-tant",
                "grupo": "Documento ANTICIPOS",
                "titulo": "TANT tipo anticipo",
                "estado": "ko" if bad else "ok",
                "validacion": f"TIPOANTICIPO={tipo}",
                "filas": trows,
                "validacionSqlRef": "tant",
            }
        )

    cruc = int(ant.get("CRUCETER") or 0)
    cnsfcxp = (ant.get("CNSFCXP") or "").strip()
    if cruc == 1 and cnsfcxp:
        q_x = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSFCXP, CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(IDTERCERO)) AS IDTERCERO
FROM dbo.FCXP WITH (NOLOCK) WHERE CNSFCXP = N'{_esc(cnsfcxp)}';
"""
        xrows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_x))
        ok_t = bool(xrows) and int(xrows[0].get("CONTABILIZADA") or 0) != 0
        out.append(
            {
                "id": "doc-ant-tercero",
                "grupo": "Documento ANTICIPOS",
                "titulo": "CxP tercero (CRUCETER)",
                "estado": "ok" if ok_t else "ko",
                "validacion": f"CNSFCXP={cnsfcxp} CONTABILIZADA={xrows[0].get('CONTABILIZADA') if xrows else '?'}",
                "filas": xrows,
                "validacionSqlRef": "tercero-debito",
                "puntosCriticos": ["PC-ANT-01"],
            }
        )
    else:
        out.append(
            {
                "id": "doc-ant-tercero",
                "grupo": "Documento ANTICIPOS",
                "titulo": "Rama tercero",
                "estado": "ok",
                "validacion": f"CRUCETER={cruc} — débito vía TANT/FCXP según SP",
                "filas": [],
                "validacionSqlRef": "tercero-debito",
            }
        )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'ANTICIPOS' AND REFERENCIA1 = N'{esc_a}' AND REFERENCIA2 = N'{esc_f}'
  AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-ant-mcp-dup",
            "grupo": "Documento ANTICIPOS",
            "titulo": "Duplicidad MCP ANTICIPOS",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s)",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, A.FECHA
FROM dbo.ANT A WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(A.FECHA) AND P.MES = MONTH(A.FECHA)
WHERE A.CNSANT = N'{esc_a}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-ant-pri",
                "grupo": "Documento ANTICIPOS",
                "titulo": "PRI fecha anticipo",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"CERRADO={cerr}",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_cnsiacth(
    server: str, user: str, pwd: str, db: str, cnsiacth: str
) -> list[dict]:
    cns = (cnsiacth or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 H.CNSIACTH, H.IDEVENTO, H.IDACTIVO, H.FECHAEVENTO,
       LTRIM(RTRIM(COALESCE(H.OBSERVACION,''))) AS OBSERVACION,
       CAST(COALESCE(H.CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(H.NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       LTRIM(RTRIM(COALESCE(I.ESTADO,''))) AS IACT_ESTADO,
       LTRIM(RTRIM(COALESCE(E.DESCRIPCION,''))) AS EVENTO_DESC
FROM dbo.IACTH H WITH (NOLOCK)
INNER JOIN dbo.IACT I WITH (NOLOCK) ON I.IDACTIVO = H.IDACTIVO
LEFT JOIN dbo.IACTE E WITH (NOLOCK) ON E.IDEVENTO = H.IDEVENTO
WHERE H.CNSIACTH = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-iact-missing",
                "grupo": "Documento IACT",
                "titulo": f"IACTH {cns}",
                "estado": "ko",
                "validacion": "Historial evento no existe",
                "filas": [],
                "validacionSqlRef": "iact-ref",
            }
        )
        return out

    h = rows[0]
    est_act = (h.get("IACT_ESTADO") or "").strip().upper()
    out.append(
        {
            "id": "doc-iact-cab",
            "grupo": "Documento IACT",
            "titulo": "IACTH + activo",
            "estado": "ok" if est_act not in ("A", "ANULADO") else "warn",
            "validacion": f"IDACTIVO={h.get('IDACTIVO')} EVENTO={h.get('IDEVENTO')} IACT.ESTADO={est_act}",
            "filas": rows,
            "validacionSqlRef": "iact-ref",
        }
    )
    out.append(
        {
            "id": "doc-iact-acfi",
            "grupo": "Documento IACT",
            "titulo": "Estado activo",
            "estado": "ok" if h.get("IDACTIVO") else "ko",
            "validacion": (h.get("EVENTO_DESC") or "")[:80] or "Evento IACTE",
            "filas": [],
            "validacionSqlRef": "acfi-estado",
            "puntosCriticos": ["PC-IACT-01"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, REFERENCIA2, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'IACT' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-iact-mcp-dup",
            "grupo": "Documento IACT",
            "titulo": "Duplicidad MCP IACT",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REFERENCIA1",
            "filas": dup[:5],
        }
    )

    fe = h.get("FECHAEVENTO")
    if fe:
        q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, H.FECHAEVENTO
FROM dbo.IACTH H WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(H.FECHAEVENTO) AND P.MES = MONTH(H.FECHAEVENTO)
WHERE H.CNSIACTH = N'{esc}';
"""
        pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
        if pri_rows:
            cerr = int(pri_rows[0].get("CERRADO") or 0)
            out.append(
                {
                    "id": "doc-iact-pri",
                    "grupo": "Documento IACT",
                    "titulo": "PRI FECHAEVENTO",
                    "estado": "ok" if cerr == 0 else "ko",
                    "validacion": f"CERRADO={cerr}",
                    "filas": pri_rows,
                }
            )

    return out


def _checks_documento_cnsfleg(
    server: str, user: str, pwd: str, db: str, cnsfleg: str
) -> list[dict]:
    cns = (cnsfleg or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 F.CNSFLEG, LTRIM(RTRIM(COALESCE(F.ESTADO,''))) AS ESTADO,
       CAST(COALESCE(F.CONTABILIZADO,0) AS INT) AS CONTABILIZADO,
       LTRIM(RTRIM(COALESCE(F.NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       LTRIM(RTRIM(COALESCE(F.INGRESO,''))) AS INGRESO,
       LTRIM(RTRIM(COALESCE(F.CODCAJA,''))) AS CODCAJA, F.FECHA,
       LTRIM(RTRIM(COALESCE(F.IDTERCERO,''))) AS IDTERCERO
FROM dbo.FLEG F WITH (NOLOCK) WHERE F.CNSFLEG = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fleg-missing",
                "grupo": "Documento LEGALIZACION",
                "titulo": f"FLEG {cns}",
                "estado": "ko",
                "validacion": "Legalización no existe",
                "filas": [],
                "validacionSqlRef": "fleg",
            }
        )
        return out

    fleg = rows[0]
    est = (fleg.get("ESTADO") or "").strip().upper()
    out.append(
        {
            "id": "doc-fleg-cab",
            "grupo": "Documento LEGALIZACION",
            "titulo": "Cabecera FLEG",
            "estado": "ok" if est != "A" else "warn",
            "validacion": f"INGRESO={fleg.get('INGRESO')} CONTABILIZADO={fleg.get('CONTABILIZADO')}",
            "filas": rows,
            "validacionSqlRef": "fleg",
        }
    )

    codcaja = (fleg.get("CODCAJA") or "").strip()
    if codcaja:
        qc = f"""
SET NOCOUNT ON;
SELECT TOP 1 CODCAJA, LTRIM(RTRIM(COALESCE(CLASE,''))) AS CLASE,
       CAST(COALESCE(NOCONTAB,0) AS INT) AS NOCONTAB
FROM dbo.CAJ WITH (NOLOCK) WHERE CODCAJA = N'{_esc(codcaja)}';
"""
        caj = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qc))
        clase = (caj[0].get("CLASE") or "").strip().upper() if caj else ""
        out.append(
            {
                "id": "doc-fleg-caj",
                "grupo": "Documento LEGALIZACION",
                "titulo": "Caja menor (CAJ)",
                "estado": "ok" if clase == "MENOR" else "warn",
                "validacion": f"CODCAJA={codcaja} CLASE={clase or '?'}",
                "filas": caj,
                "validacionSqlRef": "caja-menor",
                "puntosCriticos": ["PC-FLEG-01"],
            }
        )

    qd = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FLEGD FROM dbo.FLEGD WITH (NOLOCK) WHERE CNSFLEG = N'{esc}';
"""
    drows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qd))
    n_d = int(drows[0].get("N_FLEGD") or 0) if drows else 0
    out.append(
        {
            "id": "doc-fleg-det",
            "grupo": "Documento LEGALIZACION",
            "titulo": "Detalle FLEGD",
            "estado": "ok" if n_d > 0 else "ko",
            "validacion": f"{n_d} línea(s) gasto",
            "filas": drows,
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'LEGALIZACION' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fleg-mcp-dup",
            "grupo": "Documento LEGALIZACION",
            "titulo": "Duplicidad MCP LEGALIZACION",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REFERENCIA1",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.FECHA
FROM dbo.FLEG F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(F.FECHA) AND P.MES = MONTH(F.FECHA)
WHERE F.CNSFLEG = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        out.append(
            {
                "id": "doc-fleg-pri",
                "grupo": "Documento LEGALIZACION",
                "titulo": "PRI fecha legalización",
                "estado": "ok" if cerr == 0 else "ko",
                "validacion": f"CERRADO={cerr}",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_cnsces(
    server: str, user: str, pwd: str, db: str, cnsces: str
) -> list[dict]:
    cns = (cnsces or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSCES, LTRIM(RTRIM(COALESCE(DETALLE,''))) AS DETALLE,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(COALESCE(NROCOMPROBANTE,''))) AS NROCOMPROBANTE,
       LTRIM(RTRIM(COALESCE(IDTERCERO,''))) AS IDTERCERO, FECHA
FROM dbo.FCES WITH (NOLOCK) WHERE CNSCES = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fces-missing",
                "grupo": "Documento CESIONES",
                "titulo": f"FCES {cns}",
                "estado": "ko",
                "validacion": "Cesión no existe",
                "filas": [],
                "validacionSqlRef": "fces",
            }
        )
        return out

    out.append(
        {
            "id": "doc-fces-cab",
            "grupo": "Documento CESIONES",
            "titulo": "Cabecera FCES",
            "estado": "ok",
            "validacion": f"CONTABILIZADA={rows[0].get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "fces",
        }
    )

    q_mix = f"""
SET NOCOUNT ON;
SELECT
  (SELECT COUNT(*) FROM dbo.FCESCXP WITH (NOLOCK) WHERE CNSCES = N'{esc}') AS N_CXP,
  (SELECT COUNT(*) FROM dbo.FCESCXC WITH (NOLOCK) WHERE CNSCES = N'{esc}') AS N_CXC;
"""
    mix = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mix))
    n_cxp = int(mix[0].get("N_CXP") or 0) if mix else 0
    n_cxc = int(mix[0].get("N_CXC") or 0) if mix else 0
    out.append(
        {
            "id": "doc-fces-det",
            "grupo": "Documento CESIONES",
            "titulo": "Detalle FCESCXP / FCESCXC",
            "estado": "ok" if (n_cxp + n_cxc) > 0 else "ko",
            "validacion": f"CxP={n_cxp} CxC={n_cxc}",
            "filas": mix,
            "validacionSqlRef": "fces-doc",
            "puntosCriticos": ["PC-FCES-01"],
        }
    )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'CESIONES' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fces-mcp-dup",
            "grupo": "Documento CESIONES",
            "titulo": "Duplicidad MCP CESIONES",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s)",
            "filas": dup[:5],
        }
    )

    fe = rows[0].get("FECHA")
    if fe:
        q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, F.FECHA
FROM dbo.FCES F WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK) ON P.ANO = YEAR(F.FECHA) AND P.MES = MONTH(F.FECHA)
WHERE F.CNSCES = N'{esc}';
"""
        pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
        if pri_rows:
            cerr = int(pri_rows[0].get("CERRADO") or 0)
            out.append(
                {
                    "id": "doc-fces-pri",
                    "grupo": "Documento CESIONES",
                    "titulo": "PRI fecha cesión",
                    "estado": "ok" if cerr == 0 else "ko",
                    "validacion": f"CERRADO={cerr}",
                    "filas": pri_rows,
                }
            )

    return out


def _resolve_ajdep_nro_comprobante(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> tuple[str, str]:
    """Devuelve (nrocomprobante, nota). referencia: NRO, ANO-MES o ANO/MES/IDSEDE."""
    ref = (referencia or "").strip()
    if not ref:
        return "", ""
    if "/" in ref:
        parts = [p.strip() for p in ref.split("/")]
        if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
            ano, mes = parts[0], parts[1]
            sede = parts[2] if len(parts) > 2 else ""
            cond_sede = f" AND IDSEDE = N'{_esc(sede)}'" if sede else ""
            q = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE FROM dbo.MCPE WITH (NOLOCK)
WHERE PROCEDENCIA = N'AJDEP' AND ANO = N'{_esc(ano)}' AND MES = {int(mes)} {cond_sede}
ORDER BY FECHA DESC;
"""
            rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
            if rows and (rows[0].get("NROCOMPROBANTE") or "").strip():
                return (rows[0].get("NROCOMPROBANTE") or "").strip(), f"MCPE AJDEP {ano}/{mes}" + (f"/{sede}" if sede else "")
            q2 = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'AJDEP' AND ANO = N'{_esc(ano)}' AND MES = {int(mes)} {cond_sede}
ORDER BY FECHA DESC;
"""
            rows2 = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q2))
            if rows2:
                return (rows2[0].get("NROCOMPROBANTE") or "").strip(), f"MCP AJDEP {ano}/{mes}"
            return "", f"Sin comprobante AJDEP para {ano}/{mes}"
    if "-" in ref and ref.count("-") == 1:
        ano, mes = ref.split("-", 1)
        if ano.strip().isdigit() and mes.strip().isdigit():
            return _resolve_ajdep_nro_comprobante(server, user, pwd, db, f"{ano.strip()}/{mes.strip()}")
    return ref, "NROCOMPROBANTE directo"


def _checks_documento_ajdep(
    server: str, user: str, pwd: str, db: str, referencia: str
) -> list[dict]:
    nro, nota = _resolve_ajdep_nro_comprobante(server, user, pwd, db, referencia)
    out: list[dict] = []
    if not nro:
        out.append(
            {
                "id": "doc-ajdep-missing",
                "grupo": "Documento AJDEP",
                "titulo": "Depreciación periodo",
                "estado": "ko",
                "validacion": nota or "Indique NROCOMPROBANTE o ANO/MES[/IDSEDE]",
                "filas": [],
                "validacionSqlRef": "cabecera-periodo",
            }
        )
        return out

    esc = _esc(nro)
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, ANO, MES, IDSEDE,
       CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}' AND PROCEDENCIA = N'AJDEP'
UNION ALL
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, ANO, MES, IDSEDE,
       CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}' AND PROCEDENCIA = N'AJDEP';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not cab:
        out.append(
            {
                "id": "doc-ajdep-missing",
                "grupo": "Documento AJDEP",
                "titulo": nro,
                "estado": "ko",
                "validacion": "No es comprobante PROCEDENCIA AJDEP",
                "filas": [],
            }
        )
        return out

    row = cab[0]
    out.append(
        {
            "id": "doc-ajdep-cab",
            "grupo": "Documento AJDEP",
            "titulo": "Cabecera depreciación",
            "estado": "ok",
            "validacion": f"{nota} · {row.get('ORIGEN')} ESTADO={row.get('ESTADO')} {row.get('ANO')}-{row.get('MES')} sede={row.get('IDSEDE')}",
            "filas": cab,
            "validacionSqlRef": "cabecera-periodo",
        }
    )

    q_mch = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCH,
       SUM(CASE WHEN PROCESO LIKE N'%DEP%' OR PROCESO LIKE N'%AJDEP%' THEN 1 ELSE 0 END) AS N_DEP
FROM dbo.MCHE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    mch = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mch))
    n_m = int(mch[0].get("N_MCH") or 0) if mch else 0
    out.append(
        {
            "id": "doc-ajdep-mche",
            "grupo": "Documento AJDEP",
            "titulo": "Líneas MCHE",
            "estado": "ok" if n_m > 0 else "ko",
            "validacion": f"{n_m} línea(s) MCHE",
            "filas": mch,
            "validacionSqlRef": "activos-dep",
        }
    )

    ano = (row.get("ANO") or "").strip()
    mes = row.get("MES")
    if ano and mes is not None:
        q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO
FROM dbo.PRI WITH (NOLOCK) WHERE ANO = N'{_esc(ano)}' AND MES = {int(mes)};
"""
        pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
        if pri_rows:
            cerr = int(pri_rows[0].get("CERRADO") or 0)
            out.append(
                {
                    "id": "doc-ajdep-pri",
                    "grupo": "Documento AJDEP",
                    "titulo": "PRI periodo depreciación",
                    "estado": "ok" if cerr == 0 else "ko",
                    "validacion": f"CERRADO={cerr}",
                    "filas": pri_rows,
                }
            )

    return out


def _checks_documento_nro_reverso(
    server: str, user: str, pwd: str, db: str, nro_reverso: str
) -> list[dict]:
    """Comprobante de reversión (MCPE/MCP): PROCEDENCIA REV* y enlace REFERENCIA3 → origen."""
    nro = (nro_reverso or "").strip()
    if not nro:
        return []
    esc = _esc(nro)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA1,''))) AS REFERENCIA1,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3,
       ANO, MES, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}'
UNION ALL
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       LTRIM(RTRIM(COALESCE(REFERENCIA1,''))) AS REFERENCIA1,
       LTRIM(RTRIM(COALESCE(REFERENCIA3,''))) AS REFERENCIA3,
       ANO, MES, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{esc}';
"""
    cab = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not cab:
        out.append(
            {
                "id": "doc-rev-missing",
                "grupo": "Documento REVERSOS",
                "titulo": nro,
                "estado": "ko",
                "validacion": "Comprobante reversión no está en MCP/MCPE",
                "filas": [],
                "validacionSqlRef": "mcp-origen",
            }
        )
        return out

    row = cab[0]
    proc = (row.get("PROCEDENCIA") or "").strip().upper()
    rev_procs = (
        "REVCAJAING",
        "REVCAJAEGR",
        "REVNOTDBCR",
        "REVNOTDBCR",
        "NOTDBCRCXP",
    )
    is_rev = proc.startswith("REV") or proc in rev_procs
    out.append(
        {
            "id": "doc-rev-cab",
            "grupo": "Documento REVERSOS",
            "titulo": "Cabecera reversión",
            "estado": "ok" if is_rev else "warn",
            "validacion": f"{row.get('ORIGEN')} PROCEDENCIA={proc} ESTADO={row.get('ESTADO')}",
            "filas": cab,
            "validacionSqlRef": "mcp-origen",
            "puntosCriticos": ["PC-REV-01"],
        }
    )

    orig = (row.get("REFERENCIA3") or "").strip()
    if not orig:
        out.append(
            {
                "id": "doc-rev-origen",
                "grupo": "Documento REVERSOS",
                "titulo": "MCP origen (REFERENCIA3)",
                "estado": "ko",
                "validacion": "Sin REFERENCIA3 — no enlaza comprobante origen",
                "filas": [],
            }
        )
    else:
        q_o = f"""
SET NOCOUNT ON;
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       CAST(COALESCE(ANULADO,0) AS INT) AS ANULADO, N'MCP' AS ORIGEN
FROM dbo.MCP WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{_esc(orig)}'
UNION ALL
SELECT TOP 1 NROCOMPROBANTE, PROCEDENCIA, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO,
       CAST(COALESCE(ANULADO,0) AS INT) AS ANULADO, N'MCPE' AS ORIGEN
FROM dbo.MCPE WITH (NOLOCK) WHERE NROCOMPROBANTE = N'{_esc(orig)}';
"""
        orig_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_o))
        out.append(
            {
                "id": "doc-rev-origen",
                "grupo": "Documento REVERSOS",
                "titulo": "Comprobante origen",
                "estado": "ok" if orig_rows else "ko",
                "validacion": f"REFERENCIA3={orig}",
                "filas": orig_rows,
            }
        )

    for c in _checks_documento_nro_comprobante(server, user, pwd, db, nro, None):
        if c.get("id") in ("doc-mch-cuadre", "doc-mch-cue"):
            c["grupo"] = "Documento REVERSOS"
            out.append(c)

    return out


def _checks_documento_cnsglo(
    server: str, user: str, pwd: str, db: str, cnsglo: str
) -> list[dict]:
    cns = (cnsglo or "").strip()
    if not cns:
        return []
    esc = _esc(cns)
    out: list[dict] = []

    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 CNSGLO, LTRIM(RTRIM(N_FACTURA)) AS N_FACTURA,
       COALESCE(VLRRECUPERAR,0) AS VLRRECUPERAR, COALESCE(VLRACEPTADO,0) AS VLRACEPTADO,
       CAST(COALESCE(CONTABILIZADA,0) AS INT) AS CONTABILIZADA,
       LTRIM(RTRIM(NROCOMPROBANTE)) AS NROCOMPROBANTE,
       FCIERRE, FECHARESP, LTRIM(RTRIM(IDTERCERO)) AS IDTERCERO
FROM dbo.FGLO WITH (NOLOCK) WHERE CNSGLO = N'{esc}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if not rows:
        out.append(
            {
                "id": "doc-fglo-missing",
                "grupo": "Documento RGLO",
                "titulo": f"FGLO {cns}",
                "estado": "ko",
                "validacion": "Glosa no existe — grafo fglo-ref",
                "filas": [],
                "puntosCriticos": ["PC-RGLO-01"],
                "validacionSqlRef": "fglo-ref",
            }
        )
        return out

    fg = rows[0]
    v_rec = float(fg.get("VLRRECUPERAR") or 0)
    v_ace = float(fg.get("VLRACEPTADO") or 0)
    out.append(
        {
            "id": "doc-fglo-cab",
            "grupo": "Documento RGLO",
            "titulo": "Cabecera FGLO",
            "estado": "ok",
            "validacion": f"N_FACTURA={fg.get('N_FACTURA')} VLRRECUPERAR={v_rec} VLRACEPTADO={v_ace} CONTAB={fg.get('CONTABILIZADA')}",
            "filas": rows,
            "validacionSqlRef": "fglo-ref",
        }
    )
    out.append(
        {
            "id": "doc-fglo-recuperar",
            "grupo": "Documento RGLO",
            "titulo": "Valor a recuperar",
            "estado": "ok" if v_rec > 0 else "warn",
            "validacion": "VLRRECUPERAR>0 (SPK_CONTAB_FGLO sale si no hay valor salvo MCUEORDEN_GLOSAS)",
            "filas": [],
            "validacionSqlRef": "fglo-ref",
        }
    )
    out.append(
        {
            "id": "doc-fglo-tipo",
            "grupo": "Documento RGLO",
            "titulo": "Rama aceptada vs recuperación",
            "estado": "ok" if v_rec > 0 or v_ace > 0 else "warn",
            "validacion": f"Recuperación={v_rec}; aceptada={v_ace} (cuentas TTEC/USVGS distintas)",
            "filas": [],
            "validacionSqlRef": "tipo-glo",
        }
    )

    nf = (fg.get("N_FACTURA") or "").strip()
    if nf:
        q_ftr = f"""
SET NOCOUNT ON;
SELECT TOP 1 F.N_FACTURA, LTRIM(RTRIM(F.TIPOTTEC)) AS TIPOTTEC,
       LTRIM(RTRIM(F.NROCOMPROBANTE)) AS FTR_NRO,
       CAST(COALESCE(F.CONTABILIZADA,0) AS INT) AS FTR_CONTABILIZADA
FROM dbo.FTR F WITH (NOLOCK) WHERE F.N_FACTURA = N'{_esc(nf)}';
"""
        ftr_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ftr))
        if not ftr_rows:
            out.append(
                {
                    "id": "doc-fglo-ftr",
                    "grupo": "Documento RGLO",
                    "titulo": "Factura ligada",
                    "estado": "ko",
                    "validacion": f"FTR {nf} no existe",
                    "filas": [],
                }
            )
        else:
            tt = (ftr_rows[0].get("TIPOTTEC") or "").strip()
            qt = f"""
SET NOCOUNT ON;
SELECT TOP 1 TIPO, LTRIM(RTRIM(CUENTACG)) AS CUENTACG,
       LTRIM(RTRIM(CUENTARAD)) AS CUENTARAD, LTRIM(RTRIM(CUENTALG)) AS CUENTALG
FROM dbo.TTEC WITH (NOLOCK) WHERE TIPO = N'{_esc(tt)}';
"""
            trows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qt))
            bad = not trows or not any((trows[0].get(k) or "").strip() for k in ("CUENTACG", "CUENTARAD", "CUENTALG"))
            out.append(
                {
                    "id": "doc-fglo-ttec",
                    "grupo": "Documento RGLO",
                    "titulo": "TTEC factura glosa",
                    "estado": "ko" if bad else "ok",
                    "validacion": f"TIPOTTEC={tt or '?'} cuentas glosa/rad/cg",
                    "filas": trows,
                    "puntosCriticos": ["PC-RGLO-02"],
                }
            )

    q_dup = f"""
SET NOCOUNT ON;
SELECT NROCOMPROBANTE, PROCEDENCIA, REFERENCIA1, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'RGLO' AND REFERENCIA1 = N'{esc}' AND COALESCE(ESTADO,0) <> 3;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    out.append(
        {
            "id": "doc-fglo-mcp-dup",
            "grupo": "Documento RGLO",
            "titulo": "Duplicidad MCP RGLO",
            "estado": "warn" if dup else "ok",
            "validacion": f"{len(dup)} MCP vigente(s) REFERENCIA1",
            "filas": dup[:5],
        }
    )

    q_pri = f"""
SET NOCOUNT ON;
SELECT TOP 1 P.ANO, P.MES, P.CERRADO, P.CERRADO_CARTERA,
       COALESCE(G.FCIERRE, G.FECHARESP) AS FECHA_GLO
FROM dbo.FGLO G WITH (NOLOCK)
LEFT JOIN dbo.PRI P WITH (NOLOCK)
  ON P.ANO = YEAR(COALESCE(G.FCIERRE, G.FECHARESP))
 AND P.MES = MONTH(COALESCE(G.FCIERRE, G.FECHARESP))
WHERE G.CNSGLO = N'{esc}';
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    if pri_rows:
        cerr = int(pri_rows[0].get("CERRADO") or 0)
        cerr_c = int(pri_rows[0].get("CERRADO_CARTERA") or 0)
        st_p = "ok" if cerr == 0 and cerr_c == 0 else "ko"
        out.append(
            {
                "id": "doc-fglo-pri",
                "grupo": "Documento RGLO",
                "titulo": "PRI glosa",
                "estado": st_p,
                "validacion": f"CERRADO={cerr} CERRADO_CARTERA={cerr_c}",
                "filas": pri_rows,
            }
        )

    return out


def _checks_documento_grafo_router(
    server: str,
    user: str,
    pwd: str,
    db: str,
    tipo_referencia: str,
    referencia: str,
) -> list[dict]:
    t = (tipo_referencia or "").strip().upper()
    ref = (referencia or "").strip()
    if not ref or not t:
        return []
    if t in ("CNSFPAG", "FPAG", "RECAUDO"):
        return _checks_documento_fpag_grafo(server, user, pwd, db, ref)
    if t == "CNSFCXP":
        return _checks_documento_cnsfcxp(server, user, pwd, db, ref)
    if t in ("N_FACTURA", "FTR"):
        return _checks_documento_n_factura(server, user, pwd, db, ref)
    if t in ("CNSMOV", "IMOV"):
        return _checks_documento_cnsmov(server, user, pwd, db, ref)
    if t in ("FCJ", "CNSFACJ"):
        return _checks_documento_fcj(server, user, pwd, db, ref)
    if t in ("CNSFNOT", "FNOT"):
        return _checks_documento_cnsfnot(server, user, pwd, db, ref)
    if t == "FCXPDBCR":
        return _checks_documento_fcxpdbcr(server, user, pwd, db, ref)
    if t in ("IDFCONCI", "FCONCI"):
        return _checks_documento_idfconci(server, user, pwd, db, ref)
    if t in ("CNSCXC", "RAD"):
        return _checks_documento_cnscxc(server, user, pwd, db, ref)
    if t in ("CNSGLO", "FGLO", "GLOSA"):
        return _checks_documento_cnsglo(server, user, pwd, db, ref)
    if t in ("BMOV_REF", "BMOV", "BMOVD"):
        return _checks_documento_bmov(server, user, pwd, db, ref)
    if t in ("NROCOMPROBANTE", "MCP", "MCPE"):
        return _checks_documento_nro_comprobante(server, user, pwd, db, ref, "MANUAL")
    if t in ("NOMINA_PAGO", "NOMINA", "NIEPE"):
        return _checks_documento_nomina_pago(server, user, pwd, db, ref)
    if t in ("CNSANT", "ANT"):
        return _checks_documento_cnsant(server, user, pwd, db, ref)
    if t in ("CNSIACTH", "IACTH", "IACT"):
        return _checks_documento_cnsiacth(server, user, pwd, db, ref)
    if t in ("CNSFLEG", "FLEG"):
        return _checks_documento_cnsfleg(server, user, pwd, db, ref)
    if t in ("CNSCES", "FCES", "CESIONES"):
        return _checks_documento_cnsces(server, user, pwd, db, ref)
    if t in ("AJDEP_REF", "AJDEP"):
        return _checks_documento_ajdep(server, user, pwd, db, ref)
    if t in ("NRO_REV", "REVERSO"):
        return _checks_documento_nro_reverso(server, user, pwd, db, ref)
    return [
        {
            "id": "doc-tipo-desconocido",
            "grupo": "Documento",
            "titulo": tipo_referencia,
            "estado": "warn",
            "validacion": f"Tipo {t} sin checks implementados",
            "filas": [],
        }
    ]


def _parse_periodo_cierre(referencia: str | None) -> tuple[str | None, int | None]:
    ref = (referencia or "").strip()
    if not ref:
        return None, None
    sep = "/" if "/" in ref else "-" if "-" in ref else None
    if not sep:
        return None, None
    a, m = ref.split(sep, 1)
    if a.strip().isdigit() and m.strip().isdigit():
        return a.strip(), int(m.strip())
    return None, None


def _periodo_anterior(ano: str, mes: int) -> tuple[str, int]:
    a = int(ano)
    if mes <= 1:
        return str(a - 1), 12
    return str(a), mes - 1


def _resolver_periodo_foco_cierre(
    server: str, user: str, pwd: str, db: str, referencia: str | None
) -> tuple[str | None, int | None]:
    ano, mes = _parse_periodo_cierre(referencia)
    if ano and mes:
        return ano, mes
    q = """
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES FROM dbo.PRI WITH (NOLOCK)
WHERE CAST(COALESCE(CERRADO,0) AS INT) = 0
ORDER BY ANO DESC, MES DESC;
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    if rows:
        return (rows[0].get("ANO") or "").strip(), int(rows[0].get("MES") or 0)
    q2 = """
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES FROM dbo.PRI WITH (NOLOCK)
ORDER BY ANO DESC, MES DESC;
"""
    rows2 = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q2))
    if rows2:
        return (rows2[0].get("ANO") or "").strip(), int(rows2[0].get("MES") or 0)
    return None, None


def _usvgs_dato(server: str, user: str, pwd: str, db: str, idvariable: str) -> str:
    vid = (idvariable or "").strip()
    if not vid:
        return ""
    q = f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(COALESCE(DATO,''))) AS DATO
FROM dbo.USVGS WITH (NOLOCK) WHERE IDVARIABLE = N'{_esc(vid)}';
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    return (rows[0].get("DATO") or "").strip() if rows else ""


def _append_precierre_modulos_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
) -> None:
    """Conteos read-only inspirados en FNK_REVISION_ANTES_CIERRE_PERIODO (sql/)."""
    esc_a = _esc(ano)
    fcxp_fecha = "FECHA" if _usvgs_dato(server, user, pwd, db, "IDCON_FCONTABLE_CXP").lower() == "radicacion" else "F_FACTURAREF"
    contab_act = _usvgs_dato(server, user, pwd, db, "CONTAB_ACTFIJO").upper()

    q = f"""
SET NOCOUNT ON;
SELECT N'INVENTARIO' AS MODULO, COUNT(*) AS N_PEND
FROM dbo.IMOV WITH (NOLOCK)
WHERE YEAR(FECHACONF) = {int(ano)} AND MONTH(FECHACONF) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(SECONTABILIZA,0) = 1 AND COALESCE(ESTADO,0) = 1
UNION ALL
SELECT N'NOTASDB-CR', COUNT(*)
FROM dbo.FNOT WITH (NOLOCK)
WHERE COALESCE(ESTADO,'') <> N'A' AND YEAR(F_NOTA) = {int(ano)} AND MONTH(F_NOTA) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N''
UNION ALL
SELECT N'CAJA_SIN_CONTAB', COUNT(*)
FROM dbo.FCJ WITH (NOLOCK)
WHERE COALESCE(ESTADO,'') NOT IN (N'A',N'D') AND YEAR(FECHA) = {int(ano)} AND MONTH(FECHA) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N''
  AND COALESCE(CERRADA,0) = 1 AND COALESCE(DEAPERTURA,0) = 0
UNION ALL
SELECT N'CAJA_SIN_CERRAR', COUNT(*)
FROM dbo.FCJ WITH (NOLOCK)
WHERE COALESCE(ESTADO,'') NOT IN (N'A',N'D') AND YEAR(FECHA) = {int(ano)} AND MONTH(FECHA) = {mes}
  AND COALESCE(CERRADA,0) = 0 AND COALESCE(DEAPERTURA,0) = 0
UNION ALL
SELECT N'NOMINA', COUNT(*)
FROM dbo.NPER WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes} AND COALESCE(CERRADO,0) = 0
UNION ALL
SELECT N'RECAUDOS', COUNT(*)
FROM dbo.FPAG WITH (NOLOCK)
WHERE YEAR(FECHA) = {int(ano)} AND MONTH(FECHA) = {mes}
  AND COALESCE(CONTABILIZADO,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N''
  AND COALESCE(ESTADO,'') <> N'Inactivo' AND COALESCE(CERRADO,0) = 1
UNION ALL
SELECT N'BANCOS', COUNT(*)
FROM dbo.BMOV WITH (NOLOCK)
WHERE YEAR(COALESCE(FECHAOPERACION, FECHAOK)) = {int(ano)}
  AND MONTH(COALESCE(FECHAOPERACION, FECHAOK)) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N''
  AND COALESCE(ESTADO,'') <> N'A'
UNION ALL
SELECT N'CONCILIACIONES', COUNT(*)
FROM dbo.FCONCI WITH (NOLOCK)
WHERE YEAR(FECHACONC) = {int(ano)} AND MONTH(FECHACONC) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N''
UNION ALL
SELECT N'RADICACION', COUNT(*)
FROM dbo.FCXC WITH (NOLOCK)
WHERE COALESCE(INDRECIBIDO,0) = 1 AND YEAR(F_RECIBIDO) = {int(ano)} AND MONTH(F_RECIBIDO) = {mes}
  AND COALESCE(NROCOMPROBANTE,'') = N''
  AND COALESCE(OBSERVACION,'') NOT IN (N'CXC GENERADA EN CAJA', N'VENTA DESDE FARMACIA');
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))

    q_cxp = f"""
SET NOCOUNT ON;
SELECT N'CXP' AS MODULO, COUNT(*) AS N_PEND
FROM dbo.FCXP WITH (NOLOCK)
WHERE YEAR({fcxp_fecha}) = {int(ano)} AND MONTH({fcxp_fecha}) = {mes}
  AND COALESCE(CONTABILIZADA,0) = 0 AND COALESCE(NROCOMPROBANTE,'') = N'' AND COALESCE(ESTADO,'') <> N'A';
"""
    rows.extend(_parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cxp)))

    q_nd = f"""
SET NOCOUNT ON;
SELECT N'CXP DBCR' AS MODULO, COUNT(*) AS N_PEND
FROM dbo.FCXPDBCR D WITH (NOLOCK)
WHERE YEAR(D.FECHA) = {int(ano)} AND MONTH(D.FECHA) = {mes} AND COALESCE(D.CONTABILIZADA,0) = 0
  AND EXISTS (SELECT 1 FROM dbo.FCXP X WITH (NOLOCK) WHERE X.CNSFCXP = D.CNSFCXP AND COALESCE(X.ESTADO,'') <> N'A');
"""
    rows.extend(_parse_tsv(_sqlcmd_query(server, user, pwd, db, q_nd)))

    q_pri_sub = f"""
SET NOCOUNT ON;
SELECT N'CIERRE_CARTERA' AS MODULO,
       CASE WHEN COALESCE(CERRADO_CARTERA,0) = 0 THEN 1 ELSE 0 END AS N_PEND
FROM dbo.PRI WITH (NOLOCK) WHERE ANO = N'{esc_a}' AND MES = {mes}
UNION ALL
SELECT N'CIERRE_CXP',
       CASE WHEN COALESCE(CERRADO_CXP,0) = 0 THEN 1 ELSE 0 END
FROM dbo.PRI WITH (NOLOCK) WHERE ANO = N'{esc_a}' AND MES = {mes};
"""
    rows.extend(_parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri_sub)))

    if contab_act == "SI":
        q_act = f"""
SET NOCOUNT ON;
SELECT N'ACTIVOS_DEP' AS MODULO, COUNT(*) AS N_PEND
FROM dbo.IACTD WITH (NOLOCK)
WHERE YEAR(FECHA) = {int(ano)} AND MONTH(FECHA) = {mes} AND COALESCE(CONTABILIZADA,0) <> 1;
"""
        rows.extend(_parse_tsv(_sqlcmd_query(server, user, pwd, db, q_act)))

    pend = [r for r in rows if int(r.get("N_PEND") or 0) > 0]
    total = sum(int(r.get("N_PEND") or 0) for r in pend)
    _append_check(
        checks,
        resumen,
        id="precierre-modulos",
        grupo="Pre-cierre (módulos)",
        titulo="Pendientes por módulo (conteo BA)",
        estado="ko" if total > 0 else "ok",
        validacion=(
            f"{len(pend)} módulo(s) con pendientes · {total} ítem(s) · "
            f"CxP fecha={fcxp_fecha} · NOTAS usa MONTH(F_NOTA) (FNK liberada tiene bug YEAR=MONTH)"
        ),
        filas=rows,
        puntosCriticos=["PC-CIERRE-04"],
    )

    q_fnk = f"""
SET NOCOUNT ON;
SELECT MODULO, COUNT(*) AS N_ERR
FROM dbo.FNK_REVISION_ANTES_CIERRE_PERIODO(N'{esc_a}', {mes})
GROUP BY MODULO
ORDER BY MODULO;
"""
    try:
        fnk_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fnk))
        n_fnk = sum(int(r.get("N_ERR") or 0) for r in fnk_rows)
        _append_check(
            checks,
            resumen,
            id="precierre-fnk",
            grupo="Pre-cierre (módulos)",
            titulo="FNK_REVISION_ANTES_CIERRE_PERIODO",
            estado="ko" if n_fnk > 0 else "ok",
            validacion=f"{n_fnk} fila(s) devueltas por la función en BD",
            filas=fnk_rows[:20],
            puntosCriticos=["PC-CIERRE-04"],
        )
    except RuntimeError:
        _append_check(
            checks,
            resumen,
            id="precierre-fnk",
            grupo="Pre-cierre (módulos)",
            titulo="FNK_REVISION_ANTES_CIERRE_PERIODO",
            estado="warn",
            validacion="No se pudo invocar la función en esta BD — use conteos BA anteriores.",
            filas=[],
            puntosCriticos=["PC-CIERRE-04"],
        )

    q_mcp = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCP_PEND
FROM dbo.MCP WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes}
  AND COALESCE(ESTADO,0) <> 2 AND COALESCE(ANULADO,0) <> 1;
"""
    mcp_p = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp))
    n_mcp = int(mcp_p[0].get("N_MCP_PEND") or 0) if mcp_p else 0
    _append_check(
        checks,
        resumen,
        id="mcp-sin-confirmar",
        grupo="Pre-cierre (módulos)",
        titulo="MCP sin confirmar (ESTADO<>2)",
        estado="warn" if n_mcp else "ok",
        validacion=f"{n_mcp} comprobante(s) en periodo foco",
        filas=mcp_p,
        puntosCriticos=["PC-CIERRE-02"],
    )


def _append_obtener_periodo_a_cerrar_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
    foco: list[dict],
) -> None:
    """Réplica read-only de reglas OBTENER_PERIODO_A_CERRAR (secuencia PRI)."""
    esc_a = _esc(ano)
    anomes_foco = f"{int(ano)}{mes:02d}"
    si_foco = int(foco[0].get("SI") or 0) if foco else 0

    q_si = """
SET NOCOUNT ON;
SELECT COUNT(*) AS N_SI FROM dbo.PRI WITH (NOLOCK) WHERE COALESCE(SI,0) = 1;
"""
    si_r = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_si))
    n_si = int(si_r[0].get("N_SI") or 0) if si_r else 0
    _append_check(
        checks,
        resumen,
        id="opc-si-existe",
        grupo="OBTENER periodo a cerrar",
        titulo="Periodo saldos iniciales (SI=1)",
        estado="ko" if n_si != 1 else "ok",
        validacion=f"{n_si} fila(s) PRI con SI=1",
        filas=si_r,
        puntosCriticos=["PC-CIERRE-06"],
    )

    q_si_abierto_cerrados = """
SET NOCOUNT ON;
SELECT CASE WHEN EXISTS(
  SELECT 1 FROM dbo.PRI WITH (NOLOCK)
  WHERE COALESCE(SI,0)=1 AND COALESCE(CERRADO,0)=0
) AND EXISTS(
  SELECT 1 FROM dbo.PRI WITH (NOLOCK)
  WHERE COALESCE(SI,0)=0 AND COALESCE(CERRADO,0)=1
) THEN 1 ELSE 0 END AS INCONSISTENTE;
"""
    si_inc = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_si_abierto_cerrados))
    bad_si = int(si_inc[0].get("INCONSISTENTE") or 0) if si_inc else 0
    _append_check(
        checks,
        resumen,
        id="opc-si-abierto-con-posteriores-cerrados",
        grupo="OBTENER periodo a cerrar",
        titulo="SI abierto vs periodos posteriores cerrados",
        estado="ko" if bad_si else "ok",
        validacion=(
            "SI no cerrado pero hay meses operativos ya cerrados"
            if bad_si
            else "Coherente"
        ),
        filas=si_inc,
        puntosCriticos=["PC-CIERRE-06"],
    )

    q_candidato = """
SET NOCOUNT ON;
SELECT TOP 1 ANOMES, ANO, MES, CAST(COALESCE(SI,0) AS INT) AS SI
FROM dbo.PRI WITH (NOLOCK)
WHERE COALESCE(SI,0)=1 AND COALESCE(CERRADO,0)=0;
"""
    cand = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_candidato))
    if not cand:
        q_candidato = """
SET NOCOUNT ON;
SELECT TOP 1 ANOMES, ANO, MES, CAST(COALESCE(SI,0) AS INT) AS SI
FROM dbo.PRI WITH (NOLOCK)
WHERE COALESCE(SI,0)=0 AND COALESCE(CERRADO,0)=0
ORDER BY ANO, MES;
"""
        cand = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_candidato))
    anomes_calc = (cand[0].get("ANOMES") or "").strip() if cand else ""
    st_calc = "ok"
    if anomes_calc and anomes_calc != anomes_foco:
        st_calc = "warn"
    _append_check(
        checks,
        resumen,
        id="opc-periodo-calculado-vs-foco",
        grupo="OBTENER periodo a cerrar",
        titulo="Periodo que cerraría la pantalla",
        estado=st_calc if cand else "warn",
        validacion=(
            f"Calculado ANOMES={anomes_calc or '?'} · foco auditoría={anomes_foco}"
        ),
        filas=cand,
        puntosCriticos=["PC-CIERRE-06"],
    )

    q_gap = f"""
SET NOCOUNT ON;
SELECT CASE WHEN EXISTS(
  SELECT 1 FROM dbo.PRI WITH (NOLOCK)
  WHERE COALESCE(SI,0)=0
    AND TRY_CAST(ANOMES AS INT) > TRY_CAST(N'{_esc(anomes_foco)}' AS INT)
    AND COALESCE(CERRADO,0)=1
) AND EXISTS(
  SELECT 1 FROM dbo.PRI WITH (NOLOCK)
  WHERE ANO = N'{esc_a}' AND MES = {mes} AND COALESCE(CERRADO,0)=0
) THEN 1 ELSE 0 END AS HAY_SALTO;
"""
    gap = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_gap))
    hay_salto = int(gap[0].get("HAY_SALTO") or 0) if gap else 0
    _append_check(
        checks,
        resumen,
        id="opc-secuencia-posterior-cerrado",
        grupo="OBTENER periodo a cerrar",
        titulo="Periodo foco abierto con posteriores cerrados",
        estado="ko" if hay_salto else "ok",
        validacion=(
            "Inconsistencia: mes posterior ya cerrado contablemente"
            if hay_salto
            else "Sin salto de secuencia en PRI"
        ),
        filas=gap,
        puntosCriticos=["PC-CIERRE-06"],
    )

    q_ant = f"""
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO,
       CAST(COALESCE(SI,0) AS INT) AS SI
FROM dbo.PRI WITH (NOLOCK)
WHERE (ANO < N'{esc_a}') OR (ANO = N'{esc_a}' AND MES < {mes})
ORDER BY ANO DESC, MES DESC;
"""
    ant = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ant))
    st_ant = "ok"
    val_ant = "Sin periodo anterior en PRI"
    if ant and si_foco == 0:
        ca = int(ant[0].get("CERRADO") or 0)
        if ca == 0:
            st_ant = "ko"
            val_ant = (
                f"Anterior {ant[0].get('ANO')}-{int(ant[0].get('MES') or 0):02d} "
                f"aún CERRADO=0 — VALIDAR_PERIODO_BASICO lo bloquearía"
            )
        else:
            val_ant = (
                f"Anterior {ant[0].get('ANO')}-{int(ant[0].get('MES') or 0):02d} "
                f"CERRADO=1"
            )
    elif si_foco == 1:
        val_ant = "Periodo foco es saldos iniciales (SI) — regla anterior no aplica"
    _append_check(
        checks,
        resumen,
        id="opc-periodo-anterior-cerrado",
        grupo="OBTENER periodo a cerrar",
        titulo="Periodo anterior contablemente cerrado",
        estado=st_ant,
        validacion=val_ant,
        filas=ant,
        puntosCriticos=["PC-CIERRE-06"],
    )

    q_fiscal = f"""
SET NOCOUNT ON;
SELECT TOP 1 CAST(COALESCE(P.MESDECIERRE,0) AS INT) AS MESDECIERRE,
       CAST(COALESCE(R.CIERREFISCAL,0) AS INT) AS CIERREFISCAL
FROM dbo.PRI R WITH (NOLOCK)
CROSS JOIN (SELECT TOP 1 MESDECIERRE FROM dbo.PAR WITH (NOLOCK)) P
WHERE R.ANO = N'{esc_a}' AND R.MES = {mes};
"""
    fis = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fiscal))
    st_fis = "ok"
    val_fis = "No aplica cierre fiscal en este mes"
    if fis:
        mdc = int(fis[0].get("MESDECIERRE") or 0)
        cf = int(fis[0].get("CIERREFISCAL") or 0)
        if mdc == mes:
            if cf == 0:
                st_fis = "ko"
                val_fis = "Mes de cierre fiscal (PAR) sin CIERREFISCAL=1 en PRI"
            else:
                val_fis = "Cierre fiscal marcado en PRI"
    _append_check(
        checks,
        resumen,
        id="opc-cierre-fiscal",
        grupo="OBTENER periodo a cerrar",
        titulo="Cierre fiscal (mes PAR.MESDECIERRE)",
        estado=st_fis,
        validacion=val_fis,
        filas=fis,
        puntosCriticos=["PC-CIERRE-06"],
    )


def _append_integridad_paso2_extra_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
) -> None:
    """Paso 2 integridad — reglas fuera o más estrictas que FNK en sql/."""
    esc_a = _esc(ano)

    q_dup = f"""
SET NOCOUNT ON;
SELECT TOP 15 REFERENCIA1 AS CNSFCXP, REFERENCIA2 AS ITEM, COUNT(*) AS N_MCP_VIG
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'NOTDBCRCXP'
  AND COALESCE(ANULADO,0) = 0
  AND YEAR(FECHACONTABLE) = {int(ano)} AND MONTH(FECHACONTABLE) = {mes}
GROUP BY REFERENCIA1, REFERENCIA2
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
"""
    dup = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_dup))
    n_dup = len(dup)
    _append_check(
        checks,
        resumen,
        id="int-notdbcrcxp-mcp-duplicado",
        grupo="Integridad paso 2 (extra)",
        titulo="MCP NOTDBCRCXP duplicados por nota-ítem",
        estado="ko" if n_dup else "ok",
        validacion=(
            f"{n_dup} par(es) CNSFCXP/ITEM con >1 MCP vigente en el mes "
            "(criterio REQ cierre · FECHACONTABLE)"
        ),
        filas=dup,
        puntosCriticos=["PC-CIERRE-07"],
    )

    q_cue = f"""
SET NOCOUNT ON;
SELECT COUNT(DISTINCT MCP.NROCOMPROBANTE) AS N_COMPROBANTES
FROM dbo.MCP WITH (NOLOCK)
INNER JOIN dbo.MCH WITH (NOLOCK) ON MCP.NROCOMPROBANTE = MCH.NROCOMPROBANTE
WHERE MCP.ESTADO = 2 AND MCP.ANO = N'{esc_a}' AND MCP.MES = {mes}
  AND COALESCE(MCP.ANULADO,0) <> 1
  AND COALESCE(MCH.VALOR,0) <> 0
  AND NOT EXISTS (
    SELECT 1 FROM dbo.CUE WITH (NOLOCK)
    WHERE CUE.CUENTA = MCH.CUENTA AND COALESCE(CUE.TIPO,N'') = N'Detalle'
  );
"""
    cue = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cue))
    n_cue = int(cue[0].get("N_COMPROBANTES") or 0) if cue else 0
    q_cue_m = f"""
SET NOCOUNT ON;
SELECT TOP 8 MCP.NROCOMPROBANTE, MCH.CUENTA, MCH.VALOR
FROM dbo.MCP WITH (NOLOCK)
INNER JOIN dbo.MCH WITH (NOLOCK) ON MCP.NROCOMPROBANTE = MCH.NROCOMPROBANTE
WHERE MCP.ESTADO = 2 AND MCP.ANO = N'{esc_a}' AND MCP.MES = {mes}
  AND COALESCE(MCP.ANULADO,0) <> 1
  AND COALESCE(MCH.VALOR,0) <> 0
  AND NOT EXISTS (
    SELECT 1 FROM dbo.CUE WITH (NOLOCK)
    WHERE CUE.CUENTA = MCH.CUENTA AND COALESCE(CUE.TIPO,N'') = N'Detalle'
  );
"""
    cue_m = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cue_m))
    _append_check(
        checks,
        resumen,
        id="int-mcp-cuenta-no-detalle",
        grupo="Integridad paso 2 (extra)",
        titulo="MCP confirmados con cuenta no detalle",
        estado="ko" if n_cue else "ok",
        validacion=f"{n_cue} comprobante(s) · regla FNK módulo CONTABILIDAD",
        filas=cue_m,
        puntosCriticos=["PC-CIERRE-07"],
    )

    q_ndb = f"""
SET NOCOUNT ON;
SELECT TOP 15 REFERENCIA1 AS CNSFNOT, REFERENCIA2 AS CLASE, COUNT(*) AS N_MCP_VIG
FROM dbo.MCP WITH (NOLOCK)
WHERE PROCEDENCIA = N'NOTDBCR'
  AND COALESCE(ANULADO,0) = 0
  AND YEAR(FECHACONTABLE) = {int(ano)} AND MONTH(FECHACONTABLE) = {mes}
GROUP BY REFERENCIA1, REFERENCIA2
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
"""
    ndb = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ndb))
    n_ndb = len(ndb)
    _append_check(
        checks,
        resumen,
        id="int-notdbcr-mcp-duplicado",
        grupo="Integridad paso 2 (extra)",
        titulo="MCP NOTDBCR duplicados (CxC notas)",
        estado="ko" if n_ndb else "ok",
        validacion=(
            f"{n_ndb} par(es) CNSFNOT/CLASE con >1 MCP vigente · FECHACONTABLE del mes"
        ),
        filas=ndb,
        puntosCriticos=["PC-CIERRE-07"],
    )


def _append_validar_integridad_periodo_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
) -> None:
    """Paso 2 pantalla: VALIDAR_INTEGRIDAD_PERIODO → SELECT FNK (detalle)."""
    esc_a = _esc(ano)
    filtro_sf = """
      AND UPPER(COALESCE(R.MODULO, N'')) NOT LIKE N'%CIERRE%FISCAL%'
      AND UPPER(COALESCE(R.ERROR, N'')) NOT LIKE N'%CIERRE FISCAL%'
      AND UPPER(COALESCE(R.ERROR, N'')) NOT LIKE N'%CIERRE DE CUENTAS 4,5 Y 6%'
      AND UPPER(COALESCE(R.ERROR, N'')) NOT LIKE N'%CUENTAS 4,5 Y 6%'
"""
    q_all = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_ERR
FROM dbo.FNK_REVISION_ANTES_CIERRE_PERIODO(N'{esc_a}', {mes}) R;
"""
    q_det = f"""
SET NOCOUNT ON;
SELECT TOP 25 R.MODULO, R.REFERENCIA, R.ERROR
FROM dbo.FNK_REVISION_ANTES_CIERRE_PERIODO(N'{esc_a}', {mes}) R
ORDER BY R.MODULO, R.REFERENCIA;
"""
    q_sf = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_ERR
FROM dbo.FNK_REVISION_ANTES_CIERRE_PERIODO(N'{esc_a}', {mes}) R
WHERE 1=1 {filtro_sf};
"""
    try:
        rows_all = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_all))
        n_all = int(rows_all[0].get("N_ERR") or 0) if rows_all else 0
        det = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_det))
        rows_sf = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sf))
        n_sf = int(rows_sf[0].get("N_ERR") or 0) if rows_sf else 0
        _append_check(
            checks,
            resumen,
            id="int-fnk-validar-integridad",
            grupo="Integridad paso 2 (FNK)",
            titulo="VALIDAR_INTEGRIDAD_PERIODO (FNK detalle)",
            estado="ko" if n_all > 0 else "ok",
            validacion=(
                f"{n_all} error(es) integridad · equivalente paso 2 CerrarPeriodos "
                "(muestra 25 filas MODULO/REFERENCIA/ERROR)"
            ),
            filas=det,
            puntosCriticos=["PC-CIERRE-09"],
        )
        st_sf = "ok"
        if n_sf < n_all:
            st_sf = "warn"
        _append_check(
            checks,
            resumen,
            id="int-fnk-validar-integridad-sin-fiscal",
            grupo="Integridad paso 2 (FNK)",
            titulo="FNK excl. mensajes cierre fiscal",
            estado=st_sf,
            validacion=(
                f"{n_sf} error(es) si EXCLUIR_CIERRE_FISCAL=1 · total FNK={n_all}"
            ),
            filas=[{"N_ERR": str(n_sf), "N_TOTAL": str(n_all)}],
            puntosCriticos=["PC-CIERRE-09"],
        )
    except RuntimeError:
        _append_check(
            checks,
            resumen,
            id="int-fnk-validar-integridad",
            grupo="Integridad paso 2 (FNK)",
            titulo="VALIDAR_INTEGRIDAD_PERIODO (FNK detalle)",
            estado="warn",
            validacion="FNK no invocable — ver precierre-fnk y conteos BA.",
            filas=[],
            puntosCriticos=["PC-CIERRE-09"],
        )


def _append_tbalanceh_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
    cerr_foco: int,
) -> None:
    """Fotos balance prueba / ER (TBALANCEH) — informes pre/post cierre."""
    esc_a = _esc(ano)
    q = f"""
SET NOCOUNT ON;
SELECT CLASEH, COUNT(DISTINCT CNSPRO) AS N_FOTOS, COUNT(*) AS N_LINEAS
FROM dbo.TBALANCEH WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes}
GROUP BY CLASEH
ORDER BY CLASEH;
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    tiene_bpr = any((r.get("CLASEH") or "").strip().upper() == "BPRUEBA" for r in rows)
    tiene_est = any((r.get("CLASEH") or "").strip().upper() == "ESTRES" for r in rows)
    st = "ok"
    if cerr_foco == 1 and not tiene_bpr:
        st = "warn"
    _append_check(
        checks,
        resumen,
        id="tbalanceh-fotos-mes",
        grupo="Informes / fotos (TBALANCEH)",
        titulo="Fotos del mes en TBALANCEH",
        estado=st,
        validacion=(
            f"CLASEH: {', '.join((r.get('CLASEH') or '?') for r in rows) or ['ninguna']} · "
            f"BPRUEBA={'sí' if tiene_bpr else 'no'} ESTRES={'sí' if tiene_est else 'no'}"
        ),
        filas=rows,
        puntosCriticos=["PC-CIERRE-09"],
    )

    if mes == 12:
        q_an = f"""
SET NOCOUNT ON;
SELECT CLASEH, COUNT(DISTINCT CNSPRO) AS N_FOTOS
FROM dbo.TBALANCEH WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = 13
GROUP BY CLASEH;
"""
        an = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_an))
        _append_check(
            checks,
            resumen,
            id="tbalanceh-foto-anual",
            grupo="Informes / fotos (TBALANCEH)",
            titulo="Foto anual (MES=13)",
            estado="ok" if an else "warn",
            validacion=(
                f"{len(an)} CLASEH con foto anual"
                if an
                else "Sin TBALANCEH MES=13 — opcional Balance Prueba Foto del Año"
            ),
            filas=an,
            puntosCriticos=["PC-CIERRE-09"],
        )


def _append_libros_uscxs_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    checks: list[dict],
    resumen: dict[str, int],
) -> None:
    """Foliado de libros (USCXS) — parametrización pre-cierre / informes."""
    q = """
SET NOCOUNT ON;
SELECT PREFIJO, COUNT(*) AS N_FILAS,
       MIN(COALESCE(CONSECUTIVO,0)) AS MIN_CONS,
       MAX(COALESCE(CONSECUTIVO,0)) AS MAX_CONS
FROM dbo.USCXS WITH (NOLOCK)
GROUP BY PREFIJO
ORDER BY PREFIJO;
"""
    rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    _append_check(
        checks,
        resumen,
        id="libros-uscxs-registros",
        grupo="Libros / informes (USCXS)",
        titulo="Registros USCXS por prefijo",
        estado="ok" if rows else "warn",
        validacion=f"{len(rows)} prefijo(s) configurado(s)",
        filas=rows[:25],
        puntosCriticos=["PC-CIERRE-08"],
    )

    q_cov = """
SET NOCOUNT ON;
WITH libros(suf, nom) AS (
  SELECT N'LBGR', N'Balance general' UNION ALL
  SELECT N'LBPR', N'Balance prueba' UNION ALL
  SELECT N'LDIA', N'Libro diario' UNION ALL
  SELECT N'LEST', N'Estado resultados' UNION ALL
  SELECT N'LINV', N'Inventario y balance' UNION ALL
  SELECT N'LMAY', N'Libro mayor'
)
SELECT L.nom, L.suf, COUNT(U.PREFIJO) AS N_MATCH
FROM libros L
LEFT JOIN dbo.USCXS U WITH (NOLOCK) ON U.PREFIJO LIKE N'%' + L.suf + N'%'
GROUP BY L.nom, L.suf
ORDER BY L.suf;
"""
    cov = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cov))
    falt = [r for r in cov if int(r.get("N_MATCH") or 0) == 0]
    _append_check(
        checks,
        resumen,
        id="libros-uscxs-seis-tipos",
        grupo="Libros / informes (USCXS)",
        titulo="Cobertura seis libros oficiales",
        estado="warn" if falt else "ok",
        validacion=(
            f"Faltan prefijos: {', '.join(r.get('suf') or '?' for r in falt)}"
            if falt
            else "LBGR/LBPR/LDIA/LEST/LINV/LMAY presentes (patrón PREFIJO)"
        ),
        filas=cov,
        puntosCriticos=["PC-CIERRE-08"],
    )


def _append_validar_periodo_basico_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
    foco: list[dict],
) -> None:
    """Réplica read-only de SPQ_CONTABILIDAD_2 · VALIDAR_PERIODO_BASICO (paso 1 cierre)."""
    esc_a = _esc(ano)
    anomes = f"{int(ano)}{mes:02d}"
    diacom = f"DATEFROMPARTS({int(ano)}, {mes}, 1)"
    inv_cierr = _usvgs_dato(server, user, pwd, db, "VALIDAINVCIERRECONT").upper()
    trasl = _usvgs_dato(server, user, pwd, db, "CONTABGENTRASLACOSTO").upper()

    if inv_cierr == "SI":
        q_inv = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_PEND
FROM dbo.IMOV WITH (NOLOCK)
WHERE FECHAMOV >= {diacom} AND FECHAMOV <= EOMONTH({diacom})
  AND COALESCE(ESTADO,0) = 0
  AND IDTIPOMOV IN (SELECT IDTIPOMOV FROM dbo.ITMO WITH (NOLOCK) WHERE COALESCE(SECONTABILIZA,0) = 1);
"""
        inv_r = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_inv))
        n_inv = int(inv_r[0].get("N_PEND") or 0) if inv_r else 0
        _append_check(
            checks,
            resumen,
            id="vpb-inv-sin-confirmar",
            grupo="Validar periodo básico (paso 1)",
            titulo="Inventario sin confirmar (FECHAMOV)",
            estado="ko" if n_inv else "ok",
            validacion=(
                f"{n_inv} movimiento(s) · VALIDAINVCIERRECONT=SI "
                "(distinto a pre-cierre IMOV por FECHACONF)"
            ),
            filas=inv_r,
            puntosCriticos=["PC-CIERRE-05"],
        )

    q_si = """
SET NOCOUNT ON;
SELECT COUNT(*) AS N_SI FROM dbo.PRI WITH (NOLOCK) WHERE COALESCE(SI,0) = 1;
"""
    si_r = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_si))
    n_si = int(si_r[0].get("N_SI") or 0) if si_r else 0
    _append_check(
        checks,
        resumen,
        id="vpb-saldos-iniciales-unico",
        grupo="Validar periodo básico (paso 1)",
        titulo="Periodo de saldos iniciales (SI=1)",
        estado="ko" if n_si != 1 else "ok",
        validacion=f"{n_si} fila(s) PRI con SI=1 (esperado: 1)",
        filas=si_r,
        puntosCriticos=["PC-CIERRE-05"],
    )

    cerr = int(foco[0].get("CERRADO") or 0) if foco else -1
    _append_check(
        checks,
        resumen,
        id="vpb-periodo-no-cerrado",
        grupo="Validar periodo básico (paso 1)",
        titulo="Periodo abierto para cierre",
        estado="ko" if cerr == 1 else ("ok" if cerr == 0 else "warn"),
        validacion="CERRADO=1 bloquea VALIDAR_PERIODO_BASICO" if cerr == 1 else f"CERRADO={cerr}",
        filas=foco,
        puntosCriticos=["PC-CIERRE-05"],
    )

    q_mcp = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCP
FROM dbo.MCP WITH (NOLOCK)
WHERE COALESCE(ESTADO,0) <> 2 AND COALESCE(ANULADO,0) = 0 AND ANOMES = N'{_esc(anomes)}';
"""
    mcp_r = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcp))
    n_mcp = int(mcp_r[0].get("N_MCP") or 0) if mcp_r else 0
    _append_check(
        checks,
        resumen,
        id="vpb-mcp-sin-confirmar",
        grupo="Validar periodo básico (paso 1)",
        titulo="MCP sin confirmar (ANOMES)",
        estado="ko" if n_mcp else "ok",
        validacion=f"{n_mcp} comprobante(s) · ANOMES={anomes}",
        filas=mcp_r,
        puntosCriticos=["PC-CIERRE-05"],
    )

    q_mcpe = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_MCPE
FROM dbo.MCPE WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes} AND COALESCE(CLASECONTB,'') <> N'NIIF';
"""
    mcpe_r = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcpe))
    n_mcpe = int(mcpe_r[0].get("N_MCPE") or 0) if mcpe_r else 0
    _append_check(
        checks,
        resumen,
        id="vpb-mcpe-en-tabla-errores",
        grupo="Validar periodo básico (paso 1)",
        titulo="MCPE en periodo (≠ NIIF)",
        estado="ko" if n_mcpe else "ok",
        validacion=(
            f"{n_mcpe} fila(s) · incluye cualquier MCPE del mes "
            "(no solo ESTADO=0)"
        ),
        filas=mcpe_r,
        puntosCriticos=["PC-CIERRE-05"],
    )

    if trasl == "SI" and foco:
        ct = int(foco[0].get("CIERRE_TRASCOSTOS") or 0)
        _append_check(
            checks,
            resumen,
            id="vpb-traslado-costos",
            grupo="Validar periodo básico (paso 1)",
            titulo="Traslado de costos (CONTABGENTRASLACOSTO)",
            estado="ko" if ct == 0 else "ok",
            validacion=f"PRI.CIERRE_TRASCOSTOS={ct}",
            filas=foco,
            puntosCriticos=["PC-CIERRE-05"],
        )


def _append_saldomester_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
    cerr_foco: int,
) -> None:
    esc_a = _esc(ano)
    q = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FILAS, COUNT(DISTINCT IDTERCERO) AS N_TERCEROS,
       SUM(ABS(COALESCE(SF,0))) AS SUM_ABS_SF
FROM dbo.SALDOMESTER WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes};
"""
    sdt = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    n_f = int(sdt[0].get("N_FILAS") or 0) if sdt else 0
    st = "ok"
    if cerr_foco == 1 and n_f == 0:
        st = "warn"
    _append_check(
        checks,
        resumen,
        id="saldomester-periodo",
        grupo="Cierre periodo",
        titulo="SALDOMESTER (terceros)",
        estado=st,
        validacion=f"{n_f} fila(s) · terceros distintos={sdt[0].get('N_TERCEROS') if sdt else 0}",
        filas=sdt,
        puntosCriticos=["PC-CIERRE-03"],
    )


def _append_saldomesterfac_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    ano: str,
    mes: int,
    checks: list[dict],
    resumen: dict[str, int],
    cerr_foco: int,
) -> None:
    esc_a = _esc(ano)
    q = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_FILAS, COUNT(DISTINCT IDTERCERO) AS N_TERCEROS,
       SUM(ABS(COALESCE(SF,0))) AS SUM_ABS_SF
FROM dbo.SALDOMESTERFAC WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes};
"""
    sdt = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q))
    n_f = int(sdt[0].get("N_FILAS") or 0) if sdt else 0
    st = "ok"
    if cerr_foco == 1 and n_f == 0:
        st = "warn"
    _append_check(
        checks,
        resumen,
        id="saldomesterfac-periodo",
        grupo="Cierre periodo",
        titulo="SALDOMESTERFAC (terceros / factura)",
        estado=st,
        validacion=f"{n_f} fila(s) · usada en balance y cierre saldos iniciales",
        filas=sdt,
        puntosCriticos=["PC-CIERRE-03"],
    )


def _checks_cierre_a_pasos(checks: list[dict]) -> list[dict]:
    pasos: list[dict] = []
    for c in checks:
        pasos.append(
            _check(
                c.get("estado") or "ok",
                c.get("titulo") or c.get("id") or "Check",
                c.get("validacion") or "",
                c.get("filas") or [],
                c.get("puntosCriticos") or [],
            )
        )
    return pasos


def _checks_cierre_periodo_fase2(
    server: str,
    user: str,
    pwd: str,
    db: str,
    referencia: str | None,
) -> tuple[list[dict], dict[str, int], str | None, int | None]:
    """Fase 2 — PRI, MCPE, SALDOMES, cartera (solo SELECT)."""
    checks: list[dict] = []
    resumen: dict[str, int] = {"ok": 0, "warn": 0, "ko": 0}
    ano, mes = _resolver_periodo_foco_cierre(server, user, pwd, db, referencia)
    if not ano or not mes:
        return checks, resumen, None, None

    esc_a = _esc(ano)
    cond_foco = f" AND ANO = N'{esc_a}' AND MES = {mes}"

    q_pri = """
SET NOCOUNT ON;
SELECT TOP 24 ANO, MES,
       CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO,
       CAST(COALESCE(CERRADO_CARTERA,0) AS INT) AS CERRADO_CARTERA,
       CAST(COALESCE(CERRADO_INV,0) AS INT) AS CERRADO_INV,
       CAST(COALESCE(CIERREIMP,0) AS INT) AS CIERREIMP,
       CAST(COALESCE(SI,0) AS INT) AS SI
FROM dbo.PRI WITH (NOLOCK)
ORDER BY ANO DESC, MES DESC;
"""
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    abiertos = [r for r in pri_rows if int(r.get("CERRADO") or 0) == 0]
    _append_check(
        checks,
        resumen,
        id="pri-recientes",
        grupo="Cierre periodo",
        titulo="PRI (muestra / contexto)",
        estado="ok" if pri_rows else "ko",
        validacion=f"{len(abiertos)} abierto(s) contables en muestra · foco {ano}-{mes:02d}",
        filas=pri_rows,
        puntosCriticos=["PC-CIERRE-01"],
    )

    q_foco = f"""
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES,
       CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO,
       CAST(COALESCE(CERRADO_CARTERA,0) AS INT) AS CERRADO_CARTERA,
       CAST(COALESCE(CERRADO_INV,0) AS INT) AS CERRADO_INV,
       CAST(COALESCE(CERRADO_FAC,0) AS INT) AS CERRADO_FAC,
       CAST(COALESCE(CIERREIMP,0) AS INT) AS CIERREIMP,
       CAST(COALESCE(CIERRECOSTOS,0) AS INT) AS CIERRECOSTOS,
       CAST(COALESCE(CIERRE_TRASCOSTOS,0) AS INT) AS CIERRE_TRASCOSTOS,
       CAST(COALESCE(SI,0) AS INT) AS SI,
       CAST(COALESCE(DESALDOSINICIALES,0) AS INT) AS DESALDOSINICIALES
FROM dbo.PRI WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes};
"""
    foco = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_foco))
    if not foco:
        _append_check(
            checks,
            resumen,
            id="pri-foco-missing",
            grupo="Cierre periodo",
            titulo=f"PRI {ano}-{mes:02d}",
            estado="ko",
            validacion="Periodo no existe en PRI",
            filas=[],
            puntosCriticos=["PC-CIERRE-01"],
        )
    else:
        f0 = foco[0]
        cerr = int(f0.get("CERRADO") or 0)
        cc = int(f0.get("CERRADO_CARTERA") or 0)
        _append_check(
            checks,
            resumen,
            id="pri-foco",
            grupo="Cierre periodo",
            titulo=f"PRI periodo foco {ano}-{mes:02d}",
            estado="ok",
            validacion=(
                f"CERRADO={cerr} CERRADO_CARTERA={cc} "
                f"INV={f0.get('CERRADO_INV')} FAC={f0.get('CERRADO_FAC')} "
                f"IMP={f0.get('CIERREIMP')} SI={f0.get('SI')}"
            ),
            filas=foco,
            puntosCriticos=["PC-CIERRE-01"],
        )
        st_car = "ok"
        if cerr == 1 and cc == 0:
            st_car = "warn"
        if cerr == 0 and cc == 1:
            st_car = "warn"
        _append_check(
            checks,
            resumen,
            id="pri-cartera",
            grupo="Cierre periodo",
            titulo="Sub-cierre cartera vs contable",
            estado=st_car,
            validacion="CERRADO y CERRADO_CARTERA pueden cerrar en momentos distintos — contrastar política institución.",
            filas=foco,
            puntosCriticos=["PC-CIERRE-03"],
        )
        _append_obtener_periodo_a_cerrar_fase2(
            server, user, pwd, db, ano, mes, checks, resumen, foco
        )

    q_mcpe = f"""
SET NOCOUNT ON;
SELECT TOP 15 NROCOMPROBANTE, PROCEDENCIA, ANO, MES, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCPE WITH (NOLOCK)
WHERE COALESCE(ESTADO,0) = 0 {cond_foco}
ORDER BY FECHA DESC;
"""
    err = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcpe))
    q_mcpe_all = """
SET NOCOUNT ON;
SELECT TOP 5 NROCOMPROBANTE, PROCEDENCIA, ANO, MES, CAST(COALESCE(ESTADO,0) AS INT) AS ESTADO
FROM dbo.MCPE WITH (NOLOCK)
WHERE COALESCE(ESTADO,0) = 0
ORDER BY FECHA DESC;
"""
    err_all = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_mcpe_all))
    _append_check(
        checks,
        resumen,
        id="mcpe-estado-0",
        grupo="Cierre periodo",
        titulo="MCPE en error (estado 0)",
        estado="warn" if err else "ok",
        validacion=f"{len(err)} en periodo foco · {len(err_all)} global (muestra 5)",
        filas=err if err else err_all,
        puntosCriticos=["PC-CIERRE-02"],
    )

    q_sdm = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_CUENTAS,
       SUM(ABS(COALESCE(SF,0))) AS SUM_ABS_SF,
       SUM(ABS(COALESCE(SI,0))) AS SUM_ABS_SI
FROM dbo.SALDOMES WITH (NOLOCK)
WHERE ANO = N'{esc_a}' AND MES = {mes};
"""
    sdm = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sdm))
    n_sdm = int(sdm[0].get("N_CUENTAS") or 0) if sdm else 0
    ano_ant, mes_ant = _periodo_anterior(ano, mes)
    q_sdm_ant = f"""
SET NOCOUNT ON;
SELECT COUNT(*) AS N_CUENTAS FROM dbo.SALDOMES WITH (NOLOCK)
WHERE ANO = N'{_esc(ano_ant)}' AND MES = {mes_ant};
"""
    sdm_ant = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sdm_ant))
    n_ant = int(sdm_ant[0].get("N_CUENTAS") or 0) if sdm_ant else 0
    cerr_foco = int(foco[0].get("CERRADO") or 0) if foco else 0
    st_sdm = "ok"
    if cerr_foco == 1 and n_sdm == 0:
        st_sdm = "ko"
    elif n_sdm == 0 and n_ant > 0:
        st_sdm = "warn"
    _append_check(
        checks,
        resumen,
        id="saldomes-periodo",
        grupo="Cierre periodo",
        titulo="SALDOMES periodo foco",
        estado=st_sdm,
        validacion=f"{n_sdm} cuenta(s) · mes anterior {ano_ant}-{mes_ant:02d}: {n_ant} fila(s)",
        filas=sdm,
        puntosCriticos=["PC-CIERRE-03"],
    )

    _append_validar_periodo_basico_fase2(
        server, user, pwd, db, ano, mes, checks, resumen, foco
    )

    q_sig = f"""
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES, CAST(COALESCE(CERRADO,0) AS INT) AS CERRADO
FROM dbo.PRI WITH (NOLOCK)
WHERE (ANO = N'{esc_a}' AND MES > {mes}) OR (ANO > N'{esc_a}')
ORDER BY ANO, MES;
"""
    sig = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_sig))
    _append_check(
        checks,
        resumen,
        id="pri-siguiente",
        grupo="Cierre periodo",
        titulo="Periodo siguiente en PRI",
        estado="ok" if sig else "warn",
        validacion="Existe fila PRI posterior" if sig else "No hay periodo posterior — ¿apertura pendiente?",
        filas=sig,
        puntosCriticos=["PC-CIERRE-01"],
    )

    _append_precierre_modulos_fase2(server, user, pwd, db, ano, mes, checks, resumen)
    _append_validar_integridad_periodo_fase2(
        server, user, pwd, db, ano, mes, checks, resumen
    )
    _append_integridad_paso2_extra_fase2(
        server, user, pwd, db, ano, mes, checks, resumen
    )
    _append_saldomester_fase2(
        server, user, pwd, db, ano, mes, checks, resumen, cerr_foco
    )
    _append_saldomesterfac_fase2(
        server, user, pwd, db, ano, mes, checks, resumen, cerr_foco
    )
    _append_libros_uscxs_fase2(server, user, pwd, db, checks, resumen)
    _append_tbalanceh_fase2(
        server, user, pwd, db, ano, mes, checks, resumen, cerr_foco
    )

    return checks, resumen, ano, mes


def validar_cierre_periodo_contable(
    servidor_id: str,
    base_datos: str,
    referencia: str | None = None,
) -> dict:
    """Fase 2 — lectura PRI / MCPE / SALDOMES (solo SELECT). referencia opcional: ANO-MES o ANO/MES."""
    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    ref = (referencia or "").strip() or None
    checks, resumen, ano, mes = _checks_cierre_periodo_fase2(server, user, pwd, db, ref)

    return {
        "ok": True,
        "tipo": "config-contabilidad",
        "modo": "cierre-periodo-fase2",
        "servidor": servidor_id,
        "baseDatos": db,
        "procedencias": ["CIERRE-PERIODO"],
        "checks": checks,
        "variables": [],
        "resumen": resumen,
        "referencia": ref,
        "periodoFoco": f"{ano}-{mes:02d}" if ano and mes else None,
        "grafoFase2": "grafo-cierre-periodo.json",
        "catalogoValidacionFase2": [
            {"id": c.get("id"), "titulo": c.get("titulo"), "checkMotor": c.get("id")}
            for c in checks
        ],
    }


def validar_config_contabilidad(
    servidor_id: str,
    base_datos: str,
    procedencia: str = "CRITICO",
    referencia: str | None = None,
    tipo_referencia: str | None = None,
) -> dict:
    """Valida configuración exigida por grafos contables (solo SELECT)."""
    proc_sel = (procedencia or "CRITICO").strip().upper()
    if proc_sel in ("CIERRE_PERIODO", "CIERRE", "FASE2_CIERRE"):
        return validar_cierre_periodo_contable(servidor_id, base_datos, referencia)

    server, user, pwd, db = _resolve_server_db(servidor_id, base_datos)
    procs = _resolve_procedencias_contab(procedencia)
    catalog = _collect_grafo_requires(procs)
    usvgs_ids = catalog["usvgs"]
    checks: list[dict] = []
    resumen: dict[str, int] = {"ok": 0, "warn": 0, "ko": 0}

    dato_map: dict[str, str] = {}
    if usvgs_ids:
        in_list = ",".join(f"N'{_esc(i)}'" for i in usvgs_ids)
        q_us = (
            "SET NOCOUNT ON; SELECT IDVARIABLE, LTRIM(RTRIM(DATO)) AS DATO "
            f"FROM dbo.USVGS WITH (NOLOCK) WHERE IDVARIABLE IN ({in_list});"
        )
        dato_map = {
            (r.get("IDVARIABLE") or "").strip(): (r.get("DATO") or "").strip()
            for r in _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_us))
        }

    variables: list[dict] = []
    for vid in usvgs_ids:
        dato = dato_map.get(vid)
        critico = vid in ("IDMODELOCONTABLE",) or any(
            vid in (catalog["porProcedencia"].get(p) or []) for p in procs if p in _PAQUETE_CRITICO
        )
        if dato is None:
            estado, validacion = ("ko", "Sin fila en USVGS") if critico else ("warn", "Sin fila en USVGS")
        elif not str(dato).strip():
            estado, validacion = ("ko", "DATO vacío") if critico else ("warn", "DATO vacío")
        elif _is_cuenta_usvgs(vid) and str(dato).strip().upper() not in ("SI", "NO", "S", "N"):
            qc = (
                "SET NOCOUNT ON; SELECT TOP 1 CUENTA, TIPO FROM dbo.CUE WITH (NOLOCK) "
                f"WHERE CUENTA = N'{_esc(dato.strip())}';"
            )
            cue_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, qc))
            if not cue_rows:
                estado, validacion = "ko", f"Cuenta {dato} no existe en CUE"
            elif (cue_rows[0].get("TIPO") or "").strip() != "Detalle":
                estado, validacion = "ko", f"Cuenta {dato} no es tipo Detalle"
            else:
                estado, validacion = "ok", "Cuenta Detalle OK"
        else:
            estado, validacion = "ok", f"Configurado ({dato[:40]}{'…' if len(dato) > 40 else ''})"

        resumen[estado] = resumen.get(estado, 0) + 1
        variables.append({"id": vid, "dato": dato if dato is not None else "", "estado": estado, "validacion": validacion})

    modelo = (dato_map.get("IDMODELOCONTABLE") or "").strip()
    if modelo:
        qm = (
            "SET NOCOUNT ON; SELECT TOP 1 IDMODELOCONT FROM dbo.KMCO WITH (NOLOCK) "
            f"WHERE IDMODELOCONT = N'{_esc(modelo)}';"
        )
        if _parse_tsv(_sqlcmd_query(server, user, pwd, db, qm)):
            _append_check(
                checks,
                resumen,
                id="kmco-modelo",
                grupo="Modelo contable",
                titulo="KMCO / IDMODELOCONTABLE",
                estado="ok",
                validacion=f"Modelo {modelo} existe en KMCO",
                filas=[],
            )
        else:
            _append_check(
                checks,
                resumen,
                id="kmco-modelo",
                grupo="Modelo contable",
                titulo="KMCO / IDMODELOCONTABLE",
                estado="ko",
                validacion=f"KMCO {modelo} no existe",
                filas=[],
                puntosCriticos=["PC-CAJ-03", "PC-CXC-01"],
            )
    else:
        _append_check(
            checks,
            resumen,
            id="kmco-modelo",
            grupo="Modelo contable",
            titulo="KMCO / IDMODELOCONTABLE",
            estado="ko",
            validacion="IDMODELOCONTABLE vacío o ausente",
            filas=[],
        )

    q_pri = (
        "SET NOCOUNT ON; SELECT COUNT(*) AS N_ABIERTOS FROM dbo.PRI WITH (NOLOCK) "
        "WHERE COALESCE(CERRADO,0)=0;"
    )
    pri_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_pri))
    n_abiertos = int(pri_rows[0].get("N_ABIERTOS") or 0) if pri_rows else 0
    _append_check(
        checks,
        resumen,
        id="pri-abiertos",
        grupo="Periodo",
        titulo="PRI periodos abiertos",
        estado="ok" if n_abiertos > 0 else "ko",
        validacion=f"{n_abiertos} mes(es) con CERRADO=0",
        filas=pri_rows,
        puntosCriticos=["PC-FTR-02", "PC-CXC-02", "PC-BMOV-01"],
    )

    need_ttec = any(p in procs for p in ("CXC", "CONCI", "NOTDBCR", "FACTURA", "RGLO", "RAD CXC"))
    if need_ttec:
        q_ttec = """
SET NOCOUNT ON;
SELECT TOP 15 TIPO,
  SUM(CASE WHEN COALESCE(CUENTACG,'')='' THEN 1 ELSE 0 END) AS SIN_CUENTACG,
  SUM(CASE WHEN COALESCE(CUENTARAD,'')='' THEN 1 ELSE 0 END) AS SIN_CUENTARAD,
  COUNT(*) AS TOTAL
FROM dbo.TTEC WITH (NOLOCK)
GROUP BY TIPO
HAVING SUM(CASE WHEN COALESCE(CUENTACG,'')='' THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN COALESCE(CUENTARAD,'')='' THEN 1 ELSE 0 END) > 0
ORDER BY TIPO;
"""
        ttec_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_ttec))
        if ttec_rows:
            _append_check(
                checks,
                resumen,
                id="ttec-cuentas",
                grupo="Cartera (TTEC)",
                titulo="TTEC sin CUENTACG / CUENTARAD",
                estado="ko",
                validacion=f"{len(ttec_rows)} tipo(s) TTEC con cuentas vacías (muestra)",
                filas=ttec_rows,
                puntosCriticos=["PC-CXC-01", "PC-CONCI-01"],
            )
        else:
            _append_check(
                checks,
                resumen,
                id="ttec-cuentas",
                grupo="Cartera (TTEC)",
                titulo="TTEC sin CUENTACG / CUENTARAD",
                estado="ok",
                validacion="Ningún TIPO con CUENTACG/CUENTARAD vacío (agregado)",
                filas=[],
            )

    need_cpcj = any(p in procs for p in ("CAJA", "LEGALIZACION"))
    if need_cpcj:
        q_cpcj = """
SET NOCOUNT ON;
SELECT TOP 20 LTRIM(RTRIM(C.CODIGO)) AS CODIGO, LTRIM(RTRIM(C.CUENTA)) AS CUENTA
FROM dbo.CPCJ C WITH (NOLOCK)
LEFT JOIN dbo.CUE U WITH (NOLOCK) ON U.CUENTA = C.CUENTA AND U.TIPO = N'Detalle'
WHERE COALESCE(C.CUENTA,'') = '' OR U.CUENTA IS NULL;
"""
        cpcj_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_cpcj))
        _append_check(
            checks,
            resumen,
            id="cpcj-cuenta",
            grupo="Caja",
            titulo="CPCJ → CUE Detalle",
            estado="ko" if cpcj_rows else "ok",
            validacion=f"{len(cpcj_rows)} concepto(s) sin cuenta Detalle válida" if cpcj_rows else "Conceptos caja con cuenta OK (muestra TOP 20)",
            filas=cpcj_rows,
            puntosCriticos=["PC-CAJ-04"],
        )

    need_caj = "CAJA" in procs
    if need_caj:
        q_caj = """
SET NOCOUNT ON;
SELECT TOP 15 LTRIM(RTRIM(CODCAJA)) AS CODCAJA, LTRIM(RTRIM(CUENTA)) AS CUENTA, COALESCE(NOCONTAB,0) AS NOCONTAB
FROM dbo.CAJ WITH (NOLOCK)
WHERE COALESCE(NOCONTAB,0)=0 AND COALESCE(CUENTA,'')='';
"""
        caj_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_caj))
        _append_check(
            checks,
            resumen,
            id="caj-cuenta",
            grupo="Caja",
            titulo="CAJ contabilizable sin CUENTA",
            estado="ko" if caj_rows else "ok",
            validacion=f"{len(caj_rows)} caja(s) NOCONTAB=0 sin CUENTA" if caj_rows else "Cajas contabilizables con CUENTA",
            filas=caj_rows,
            puntosCriticos=["PC-CAJ-05"],
        )

    need_fimp = any(p in procs for p in ("CXC", "NOTDBCR", "CXP", "NOTDBCRCXP"))
    if need_fimp:
        q_fi = """
SET NOCOUNT ON;
SELECT COUNT(*) AS N_VIGENTES FROM dbo.FIMPDV WITH (NOLOCK)
WHERE CAST(GETDATE() AS DATE) BETWEEN CAST(FINICIAL AS DATE) AND CAST(FFINAL AS DATE);
"""
        fi_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_fi))
        n_fi = int(fi_rows[0].get("N_VIGENTES") or 0) if fi_rows else 0
        _append_check(
            checks,
            resumen,
            id="fimpdv-vigente",
            grupo="Impuestos",
            titulo="FIMPDV vigente hoy",
            estado="ok" if n_fi > 0 else "warn",
            validacion=f"{n_fi} fila(s) FIMPDV vigentes para hoy",
            filas=fi_rows,
            puntosCriticos=["PC-CXC-03"],
        )

    if "CONCI" in procs:
        val_conci = (dato_map.get("IDCON_TCOM_CONCI") or "").strip()
        st = "ok" if val_conci else "ko"
        _append_check(
            checks,
            resumen,
            id="tcom-conci",
            grupo="Conciliaciones",
            titulo="IDCON_TCOM_CONCI",
            estado=st,
            validacion="Tipo comprobante configurado" if val_conci else "Variable vacía o ausente",
            filas=[],
            puntosCriticos=["PC-CONCI-01"],
        )
        ffc = (dato_map.get("FNOT_FECHACONCILIA") or "").strip()
        _append_check(
            checks,
            resumen,
            id="fnot-fechaconcilia",
            grupo="Conciliaciones",
            titulo="FNOT_FECHACONCILIA",
            estado="ok" if ffc else "warn",
            validacion=ffc or "Sin valor — periodo puede usar GETDATE()",
            filas=[],
        )

    if "NOTDBCR" in procs:
        for vid, pc in (("IDCON_TCOM_NOTDBCR", "PC-FNOT-02"), ("IDCUENTANOTAS", "PC-FNOT-01")):
            val = (dato_map.get(vid) or "").strip()
            _append_check(
                checks,
                resumen,
                id=f"not-{vid.lower()}",
                grupo="Notas DB/CR",
                titulo=vid,
                estado="ok" if val else "ko",
                validacion="OK" if val else "Vacío o ausente",
                filas=[],
                puntosCriticos=[pc],
            )

    comp_multi = (dato_map.get("COMPROBMULTISEDE") or "").strip().upper()
    if comp_multi == "SI":
        q_comms = """
SET NOCOUNT ON;
SELECT CLASE, TIPO, COUNT(*) AS N FROM dbo.COMMS WITH (NOLOCK)
WHERE CLASE IN (N'NOTADBCR',N'CXP',N'FGLO',N'BMOV',N'ICAJ',N'ECAJ')
GROUP BY CLASE, TIPO;
"""
        comms_rows = _parse_tsv(_sqlcmd_query(server, user, pwd, db, q_comms))
        _append_check(
            checks,
            resumen,
            id="comms-multisede",
            grupo="Comprobantes",
            titulo="COMMS (COMPROBMULTISEDE=SI)",
            estado="ok" if comms_rows else "warn",
            validacion=f"{len(comms_rows)} grupo(s) COMMS" if comms_rows else "Sin filas COMMS en clases habituales",
            filas=comms_rows[:10],
        )

    _checks_maestros_fpa_bct_ofin_kmcom(server, user, pwd, db, procs, modelo, checks, resumen)

    documento: list[dict] = []
    ref = (referencia or "").strip()
    tipo_ref = _infer_tipo_referencia(procedencia, tipo_referencia)
    if ref and tipo_ref:
        documento = _checks_documento_grafo_router(server, user, pwd, db, tipo_ref, ref)
        for row in documento:
            _append_check(checks, resumen, **row)

    catalogo_n3 = _collect_grafo_n3_validaciones(procs)

    nota = "Validación read-only según requires[] de grafos contables (N3 validacionSql cableado en motor)."
    if documento:
        nota += f" Cruce documento {tipo_ref}={ref}."
    else:
        nota += (
            " Opcional: referencia + tipoReferencia "
            "(CNSFPAG, CNSFCXP, N_FACTURA, CNSMOV, FCJ) o elija una sola procedencia para inferir tipo."
        )

    return {
        "ok": True,
        "tipo": "config-contabilidad",
        "procedencias": procs,
        "seleccion": procedencia,
        "servidor": servidor_id,
        "baseDatos": db,
        "grafoIndice": "grafo-contabilizacion-indice.json",
        "variables": variables,
        "checks": checks,
        "documento": documento,
        "referencia": ref or None,
        "tipoReferencia": tipo_ref or None,
        "tiposReferenciaDisponibles": listar_tipos_referencia_contab(),
        "catalogoValidacionN3": catalogo_n3,
        "resumen": resumen,
        "catalogoUsvgs": catalog,
        "nota": nota,
    }
