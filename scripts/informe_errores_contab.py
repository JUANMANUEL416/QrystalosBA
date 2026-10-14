"""Informe read-only: comprobantes errados, DIAN vs contabilidad, pre-cierre."""
from __future__ import annotations

import html
from datetime import date
from pathlib import Path

from auditoria_procesos import _parse_tsv, _resolve_server_db, _sqlcmd_query


def q(server, user, pwd, db, sql: str) -> list[dict]:
    return _parse_tsv(_sqlcmd_query(server, user, pwd, db, sql))


def esc(s) -> str:
    return html.escape(str(s or ""))


def leer_institucion_clinica(env_key: str, database: str) -> dict:
    """Nombre de la IPS/clínica: USVGS/FNK IDTERCEROINSTALADO → TER."""
    server, user, pwd, db = _resolve_server_db(env_key, database)
    rows = _parse_tsv(
        _sqlcmd_query(
            server,
            user,
            pwd,
            db,
            """
SET NOCOUNT ON;
SELECT TOP 1
       LTRIM(RTRIM(CONVERT(NVARCHAR(20), DBO.FNK_VALORVARIABLE(N'IDTERCEROINSTALADO')))) AS IDTERCERO,
       LTRIM(RTRIM(T.RAZONSOCIAL)) AS RAZONSOCIAL,
       LTRIM(RTRIM(T.NIT)) AS NIT
FROM dbo.TER T WITH (NOLOCK)
WHERE T.IDTERCERO = LTRIM(RTRIM(CONVERT(NVARCHAR(20), DBO.FNK_VALORVARIABLE(N'IDTERCEROINSTALADO'))));
""",
        )
    )
    if rows and (rows[0].get("RAZONSOCIAL") or "").strip():
        return {
            "idTercero": rows[0].get("IDTERCERO") or "",
            "razonSocial": (rows[0].get("RAZONSOCIAL") or "").strip(),
            "nit": (rows[0].get("NIT") or "").strip(),
        }
    rows2 = _parse_tsv(
        _sqlcmd_query(
            server,
            user,
            pwd,
            db,
            """
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(U.DATO)) AS IDTERCERO
FROM dbo.USVGS U WITH (NOLOCK)
WHERE U.IDVARIABLE = N'IDTERCEROINSTALADO' AND LTRIM(RTRIM(COALESCE(U.DATO, N''))) <> N'';
""",
        )
    )
    id_ter = (rows2[0].get("IDTERCERO") if rows2 else "") or ""
    if not id_ter:
        return {"idTercero": "", "razonSocial": "", "nit": ""}
    rows3 = _parse_tsv(
        _sqlcmd_query(
            server,
            user,
            pwd,
            db,
            f"""
SET NOCOUNT ON;
SELECT TOP 1 LTRIM(RTRIM(T.RAZONSOCIAL)) AS RAZONSOCIAL, LTRIM(RTRIM(T.NIT)) AS NIT
FROM dbo.TER T WITH (NOLOCK)
WHERE T.IDTERCERO = N'{id_ter.replace("'", "''")}';
""",
        )
    )
    if not rows3:
        return {"idTercero": id_ter, "razonSocial": "", "nit": ""}
    return {
        "idTercero": id_ter,
        "razonSocial": (rows3[0].get("RAZONSOCIAL") or "").strip(),
        "nit": (rows3[0].get("NIT") or "").strip(),
    }


def tbl(headers: list[str], rows_html: str, empty_colspan: int) -> str:
    th = "".join(f"<th>{h}</th>" for h in headers)
    body = rows_html or f'<tr><td colspan="{empty_colspan}">Sin datos</td></tr>'
    return f"<table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table>"


def generar_informe(
    env_key: str,
    database: str,
    *,
    institucion: str | None = None,
    logo_href: str = "/app/assets/logo-ixcolombia.svg",
) -> tuple[str, dict]:
    """Consulta la BD (solo SELECT) y devuelve HTML + metadatos."""
    server, user, pwd, db = _resolve_server_db(env_key, database)
    inst_label = (institucion or "").strip()
    if not inst_label:
        clinica = leer_institucion_clinica(env_key, database)
        inst_label = clinica.get("razonSocial") or database
    if not inst_label:
        inst_label = database

    agrupado = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT X.PROCEDENCIA, X.TIPO_PROBLEMA, COUNT(DISTINCT X.NROCOMPROBANTE) AS COMPROBANTES
FROM (
  SELECT P.NROCOMPROBANTE, P.PROCEDENCIA,
         CASE
           WHEN P.PROCEDENCIA = N'INV' THEN N'INV_KMCOM'
           WHEN P.PROCEDENCIA = N'CONCI' THEN N'CONCI_TTEC'
           WHEN P.PROCEDENCIA = N'FACTURA' AND COALESCE(D.LINEAS, 0) = 0 THEN N'FACTURA_SIN_LINEAS'
           WHEN P.PROCEDENCIA = N'FACTURA' THEN N'FACTURA_KMCOM'
           WHEN P.PROCEDENCIA = N'CXC' AND COALESCE(D.LINEAS, 0) = 0 THEN N'CXC_SIN_DETALLE'
           ELSE N'OTRO'
         END AS TIPO_PROBLEMA
  FROM dbo.MCPE P WITH (NOLOCK)
  OUTER APPLY (
    SELECT COUNT(*) AS LINEAS FROM dbo.MCHE E WITH (NOLOCK) WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE
  ) D
  WHERE COALESCE(P.ESTADO, 0) = 0
) X
GROUP BY X.PROCEDENCIA, X.TIPO_PROBLEMA
ORDER BY X.PROCEDENCIA, X.TIPO_PROBLEMA;
""",
    )

    inv_resumen = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT T.DESCRIPCION AS TIPO_MOVIMIENTO, I.IDTIPOMOV, I.IDAREA, I.CCOSTO,
       COUNT(DISTINCT P.NROCOMPROBANTE) AS COMPROBANTES,
       COUNT(DISTINCT I.CNSMOV) AS MOVIMIENTOS
FROM dbo.MCPE P WITH (NOLOCK)
INNER JOIN dbo.MCHE E WITH (NOLOCK) ON P.NROCOMPROBANTE = E.NROCOMPROBANTE
INNER JOIN dbo.IMOV I WITH (NOLOCK) ON I.CNSMOV = P.REFERENCIA1
INNER JOIN dbo.ITMO T WITH (NOLOCK) ON T.IDTIPOMOV = I.IDTIPOMOV
WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'INV'
  AND COALESCE(E.ERROR, N'') <> N''
GROUP BY T.DESCRIPCION, I.IDTIPOMOV, I.IDAREA, I.CCOSTO
ORDER BY MOVIMIENTOS DESC;
""",
    )

    inv_lista = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT I.CNSMOV, T.DESCRIPCION AS TIPO_MOV, I.IDTIPOMOV, I.IDAREA, I.CCOSTO,
       CONVERT(VARCHAR(10), I.FECHACONF, 103) AS FECHA_CONF,
       P.NROCOMPROBANTE, P.ANO, P.MES
FROM dbo.MCPE P WITH (NOLOCK)
INNER JOIN dbo.IMOV I WITH (NOLOCK) ON I.CNSMOV = P.REFERENCIA1
INNER JOIN dbo.ITMO T WITH (NOLOCK) ON T.IDTIPOMOV = I.IDTIPOMOV
WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'INV'
ORDER BY I.FECHACONF DESC;
""",
    )

    conci_ttec = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT C.TIPOTTEC, MAX(T.DETALLE) AS NOMBRE_TIPO_TECNICO,
       MAX(T.CUENTACG) AS CUENTACG_DEBITO, MAX(T.CUENTALG) AS CUENTALG_CREDITO,
       COUNT(DISTINCT B.N_FACTURA) AS FACTURAS_EN_GLOSA,
       COUNT(DISTINCT A.IDFCONCI) AS CONCILIACIONES
FROM dbo.FCONCI A WITH (NOLOCK)
INNER JOIN dbo.FCONCID B WITH (NOLOCK) ON A.IDFCONCI = B.IDFCONCI AND B.VLRRECUPERAR > 0
INNER JOIN dbo.FTR C WITH (NOLOCK) ON B.N_FACTURA = C.N_FACTURA
LEFT JOIN dbo.TTEC T WITH (NOLOCK) ON T.TIPO = C.TIPOTTEC
WHERE A.IDFCONCI IN (
  SELECT P.REFERENCIA1 FROM dbo.MCPE P WITH (NOLOCK)
  WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'CONCI'
)
GROUP BY C.TIPOTTEC
ORDER BY C.TIPOTTEC;
""",
    )

    conci_cbtes = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT P.NROCOMPROBANTE, P.REFERENCIA1 AS IDFCONCI, P.NOREFERENCIA, P.ANO, P.MES,
       (SELECT COUNT(*) FROM dbo.MCHE E WITH (NOLOCK)
        WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE AND COALESCE(E.ERROR, N'') <> N'') AS LINEAS_ERROR
FROM dbo.MCPE P WITH (NOLOCK)
WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'CONCI';
""",
    )

    factura = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT P.NROCOMPROBANTE, P.NOREFERENCIA AS FACTURA, P.ANO, P.MES,
       COALESCE(P.ANULADO, 0) AS ANULADO,
       (SELECT COUNT(*) FROM dbo.MCHE E WITH (NOLOCK) WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE) AS LINEAS,
       (SELECT TOP 1 E.PREFIJO FROM dbo.MCHE E WITH (NOLOCK)
        WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE
          AND (E.CUENTA = N'NO DEF.KMCOM' OR COALESCE(E.ERROR, N'') <> N'')) AS PREFIJO_KMCOM,
       (SELECT TOP 1 E.IDAREA FROM dbo.MCHE E WITH (NOLOCK)
        WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE
          AND (E.CUENTA = N'NO DEF.KMCOM' OR COALESCE(E.ERROR, N'') <> N'')) AS IDAREA_KMCOM,
       (SELECT TOP 1 E.CCOSTO FROM dbo.MCHE E WITH (NOLOCK)
        WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE
          AND (E.CUENTA = N'NO DEF.KMCOM' OR COALESCE(E.ERROR, N'') <> N'')) AS CCOSTO_KMCOM,
       (SELECT TOP 1 E.PROCESO FROM dbo.MCHE E WITH (NOLOCK)
        WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE
          AND (E.CUENTA = N'NO DEF.KMCOM' OR COALESCE(E.ERROR, N'') <> N'')) AS PROCESO_CONTAB
FROM dbo.MCPE P WITH (NOLOCK)
WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'FACTURA';
""",
    )

    cxc = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT P.NROCOMPROBANTE, P.NOREFERENCIA, P.REFERENCIA1 AS CNSFPAG, P.ANO, P.MES,
       (SELECT COUNT(*) FROM dbo.MCHE E WITH (NOLOCK) WHERE E.NROCOMPROBANTE = P.NROCOMPROBANTE) AS LINEAS
FROM dbo.MCPE P WITH (NOLOCK)
WHERE COALESCE(P.ESTADO, 0) = 0 AND P.PROCEDENCIA = N'CXC';
""",
    )

    pri_abiertos = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT ANO, MES FROM dbo.PRI WITH (NOLOCK)
WHERE COALESCE(CERRADO, 0) = 0 AND COALESCE(SI, 0) = 0
ORDER BY ANO, MES;
""",
    )

    periodo_trab = q(
        server,
        user,
        pwd,
        db,
        """
SET NOCOUNT ON;
SELECT TOP 1 ANO, MES FROM dbo.PRI WITH (NOLOCK)
WHERE COALESCE(CERRADO, 0) = 0 AND COALESCE(SI, 0) = 0
ORDER BY ANO DESC, MES DESC;
""",
    )
    if periodo_trab:
        p_ano = int(periodo_trab[0].get("ANO") or 0)
        p_mes = int(periodo_trab[0].get("MES") or 0)
    else:
        p_ano, p_mes = date.today().year, date.today().month
    periodo_label = f"{p_ano}-{p_mes:02d}"

    fnk = q(
        server,
        user,
        pwd,
        db,
        f"""
SET NOCOUNT ON;
SELECT MODULO, REFERENCIA, LEFT(ERROR, 220) AS ERROR
FROM dbo.FNK_REVISION_ANTES_CIERRE_PERIODO(N'{p_ano}', {p_mes});
""",
    )

    dian_cuadro = q(
        server,
        user,
        pwd,
        db,
        f"""
SET NOCOUNT ON;
SELECT AMBITO, COD, CANTIDAD FROM (
  SELECT N'FTR' AS AMBITO, N'DIAN2_SIN_CONTAB' AS COD, COUNT(*) AS CANTIDAD
  FROM dbo.FTR F WITH (NOLOCK)
  WHERE F.ESTADO = N'P' AND YEAR(F.F_FACTURA) = {p_ano} AND MONTH(F.F_FACTURA) = {p_mes}
    AND COALESCE(F.FACTE, 0) IN (2, 6) AND COALESCE(F.CONTABILIZADA, 0) NOT IN (1, 2)
  UNION ALL
  SELECT N'FTR', N'CONTAB_SIN_DIAN', COUNT(*)
  FROM dbo.FTR F WITH (NOLOCK)
  WHERE F.ESTADO = N'P' AND YEAR(F.F_FACTURA) = {p_ano} AND MONTH(F.F_FACTURA) = {p_mes}
    AND COALESCE(F.CONTABILIZADA, 0) IN (1, 2) AND COALESCE(F.FACTE, 0) NOT IN (2, 6)
  UNION ALL
  SELECT N'FTR', N'DIAN_ERROR', COUNT(*)
  FROM dbo.FTR F WITH (NOLOCK)
  WHERE F.ESTADO = N'P' AND YEAR(F.F_FACTURA) = {p_ano} AND MONTH(F.F_FACTURA) = {p_mes}
    AND COALESCE(F.FACTE, 0) = 3
  UNION ALL
  SELECT N'FTR', N'DIAN_NO_ENVIADO', COUNT(*)
  FROM dbo.FTR F WITH (NOLOCK)
  WHERE F.ESTADO = N'P' AND YEAR(F.F_FACTURA) = {p_ano} AND MONTH(F.F_FACTURA) = {p_mes}
    AND COALESCE(F.FACTE, 0) IN (0, 1)
  UNION ALL
  SELECT N'FNOT', N'DIAN2_SIN_CONTAB', COUNT(*)
  FROM dbo.FNOT N WITH (NOLOCK)
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.F_NOTA) = {p_ano} AND MONTH(N.F_NOTA) = {p_mes}
    AND COALESCE(N.FACTE, 0) IN (2, 6) AND COALESCE(N.CONTABILIZADA, 0) NOT IN (1, 2)
  UNION ALL
  SELECT N'FNOT', N'CONTAB_SIN_DIAN', COUNT(*)
  FROM dbo.FNOT N WITH (NOLOCK)
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.F_NOTA) = {p_ano} AND MONTH(N.F_NOTA) = {p_mes}
    AND COALESCE(N.CONTABILIZADA, 0) IN (1, 2) AND COALESCE(N.FACTE, 0) NOT IN (2, 6)
  UNION ALL
  SELECT N'FNOT', N'DIAN_ERROR', COUNT(*)
  FROM dbo.FNOT N WITH (NOLOCK)
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.F_NOTA) = {p_ano} AND MONTH(N.F_NOTA) = {p_mes}
    AND COALESCE(N.FACTE, 0) = 3
  UNION ALL
  SELECT N'FNOT', N'DIAN_NO_ENVIADO', COUNT(*)
  FROM dbo.FNOT N WITH (NOLOCK)
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.F_NOTA) = {p_ano} AND MONTH(N.F_NOTA) = {p_mes}
    AND COALESCE(N.FACTE, 0) IN (0, 1)
  UNION ALL
  SELECT N'FCXP', N'DIAN2_SIN_CONTAB', COUNT(*)
  FROM dbo.FCXP X WITH (NOLOCK)
  WHERE COALESCE(X.ESTADO, N'') <> N'AN' AND YEAR(X.FECHA) = {p_ano} AND MONTH(X.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(X.ESTADODIAN, 0) = 2
    AND COALESCE(X.CONTABILIZADA, 0) NOT IN (1, 2)
  UNION ALL
  SELECT N'FCXP', N'CONTAB_SIN_DIAN', COUNT(*)
  FROM dbo.FCXP X WITH (NOLOCK)
  WHERE COALESCE(X.ESTADO, N'') <> N'AN' AND YEAR(X.FECHA) = {p_ano} AND MONTH(X.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(X.CONTABILIZADA, 0) IN (1, 2)
    AND COALESCE(X.ESTADODIAN, 0) <> 2
  UNION ALL
  SELECT N'FCXP', N'DIAN_ERROR', COUNT(*)
  FROM dbo.FCXP X WITH (NOLOCK)
  WHERE COALESCE(X.ESTADO, N'') <> N'AN' AND YEAR(X.FECHA) = {p_ano} AND MONTH(X.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(X.ESTADODIAN, 0) = 3
  UNION ALL
  SELECT N'FCXP', N'DIAN_NO_ENVIADO', COUNT(*)
  FROM dbo.FCXP X WITH (NOLOCK)
  WHERE COALESCE(X.ESTADO, N'') <> N'AN' AND YEAR(X.FECHA) = {p_ano} AND MONTH(X.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(X.ESTADODIAN, 0) IN (0, 1)
  UNION ALL
  SELECT N'FCXPDBCR', N'DIAN2_SIN_CONTAB', COUNT(*)
  FROM dbo.FCXPDBCR N WITH (NOLOCK)
  INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = N.CNSFCXP
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.FECHA) = {p_ano} AND MONTH(N.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(N.ESTADODIAN, 0) = 2
    AND COALESCE(N.CONTABILIZADA, 0) NOT IN (1, 2)
  UNION ALL
  SELECT N'FCXPDBCR', N'CONTAB_SIN_DIAN', COUNT(*)
  FROM dbo.FCXPDBCR N WITH (NOLOCK)
  INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = N.CNSFCXP
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.FECHA) = {p_ano} AND MONTH(N.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(N.CONTABILIZADA, 0) IN (1, 2)
    AND COALESCE(N.ESTADODIAN, 0) <> 2
  UNION ALL
  SELECT N'FCXPDBCR', N'DIAN_ERROR', COUNT(*)
  FROM dbo.FCXPDBCR N WITH (NOLOCK)
  INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = N.CNSFCXP
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.FECHA) = {p_ano} AND MONTH(N.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(N.ESTADODIAN, 0) = 3
  UNION ALL
  SELECT N'FCXPDBCR', N'DIAN_NO_ENVIADO', COUNT(*)
  FROM dbo.FCXPDBCR N WITH (NOLOCK)
  INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = N.CNSFCXP
  WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.FECHA) = {p_ano} AND MONTH(N.FECHA) = {p_mes}
    AND COALESCE(X.DOCEQUIVALENTE, 0) = 1 AND COALESCE(N.ESTADODIAN, 0) IN (0, 1)
) Z WHERE CANTIDAD > 0
ORDER BY AMBITO, COD;
""",
    )

    dian_emitidos = q(
        server,
        user,
        pwd,
        db,
        f"""
SET NOCOUNT ON;
SELECT N'FTR' AS AMBITO, COUNT(*) AS EMITIDOS
FROM dbo.FTR F WITH (NOLOCK)
WHERE F.ESTADO = N'P' AND YEAR(F.F_FACTURA) = {p_ano} AND MONTH(F.F_FACTURA) = {p_mes}
UNION ALL
SELECT N'FNOT', COUNT(*)
FROM dbo.FNOT N WITH (NOLOCK)
WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.F_NOTA) = {p_ano} AND MONTH(N.F_NOTA) = {p_mes}
UNION ALL
SELECT N'FCXP', COUNT(*)
FROM dbo.FCXP X WITH (NOLOCK)
WHERE COALESCE(X.ESTADO, N'') <> N'AN' AND YEAR(X.FECHA) = {p_ano} AND MONTH(X.FECHA) = {p_mes}
  AND COALESCE(X.DOCEQUIVALENTE, 0) = 1
UNION ALL
SELECT N'FCXPDBCR', COUNT(*)
FROM dbo.FCXPDBCR N WITH (NOLOCK)
INNER JOIN dbo.FCXP X WITH (NOLOCK) ON X.CNSFCXP = N.CNSFCXP
WHERE COALESCE(N.ESTADO, N'') <> N'A' AND YEAR(N.FECHA) = {p_ano} AND MONTH(N.FECHA) = {p_mes}
  AND COALESCE(X.DOCEQUIVALENTE, 0) = 1;
""",
    )

    n_pri = len(pri_abiertos)
    pri_list = ", ".join(f"{r.get('ANO')}-{int(r.get('MES') or 0):02d}" for r in pri_abiertos[:12])
    if n_pri > 12:
        pri_list += f" … (+{n_pri - 12} más)"

    _tipo_problema_label = {
        "INV_KMCOM": "Falta regla KMCOM inventario (tipo movimiento + área + centro de costo)",
        "CONCI_TTEC": "Falta cuenta débito glosa en tipo técnico de factura (TTEC.CUENTACG)",
        "FACTURA_SIN_LINEAS": "Comprobante factura sin líneas (anulado o intento fallido)",
        "FACTURA_KMCOM": "Falta regla KMCOM facturación (prefijo servicio + área + centro de costo)",
        "CXC_SIN_DETALLE": "Recaudo enviado a contabilidad sin generar detalle",
        "OTRO": "Otro error contable — revisar comprobante",
    }

    # --- Resumen agrupado ---
    ag_rows = ""
    for r in agrupado:
        cod = (r.get("TIPO_PROBLEMA") or "").strip()
        ag_rows += f"""<tr>
          <td>{esc(r.get('PROCEDENCIA'))}</td>
          <td>{esc(_tipo_problema_label.get(cod, cod))}</td>
          <td class="num">{esc(r.get('COMPROBANTES'))}</td>
        </tr>"""

    _dian_ambito = {
        "FTR": "Facturas emitidas (FTR)",
        "FNOT": "Notas cartera (FNOT)",
        "FCXP": "Cuentas por pagar · documento equivalente (FCXP)",
        "FCXPDBCR": "Notas CxP (FCXPDBCR)",
    }
    _dian_problema = {
        "DIAN2_SIN_CONTAB": "Enviada a DIAN (FACTE/ESTADODIAN = 2) y sin contabilizar",
        "CONTAB_SIN_DIAN": "Contabilizada y sin notificar DIAN",
        "DIAN_ERROR": "DIAN reportó error (FACTE/ESTADODIAN = 3)",
        "DIAN_NO_ENVIADO": "Sin enviar o en cola DIAN (0 / 1)",
    }
    emit_map = {r.get("AMBITO"): r.get("EMITIDOS") for r in dian_emitidos}
    dian_rows = ""
    for r in dian_cuadro:
        cod = (r.get("COD") or "").strip()
        cant = int(r.get("CANTIDAD") or 0)
        if cant <= 0:
            continue
        cls = ' class="row-ko"' if cod in ("DIAN2_SIN_CONTAB", "CONTAB_SIN_DIAN", "DIAN_ERROR") else ""
        dian_rows += f"""<tr{cls}>
          <td>{esc(_dian_ambito.get(r.get('AMBITO'), r.get('AMBITO')))}</td>
          <td>{esc(_dian_problema.get(cod, cod))}</td>
          <td class="num">{cant}</td>
        </tr>"""
    emit_summary = " · ".join(
        f"{_dian_ambito.get(k, k)}: {v}" for k, v in emit_map.items() if v
    )
    dian_tbl = (
        tbl(["Documento", "Tipo de problema", "Cantidad"], dian_rows, 3)
        if dian_rows
        else '<p class="meta">Sin hallazgos DIAN en el periodo consultado.</p>'
    )

    # --- Inventario ---
    inv_rows = ""
    for r in inv_resumen:
        inv_rows += f"""<tr>
          <td>{esc(r.get('TIPO_MOVIMIENTO'))}</td>
          <td>{esc(r.get('IDTIPOMOV'))}</td>
          <td>{esc(r.get('IDAREA'))}</td>
          <td>{esc(r.get('CCOSTO'))}</td>
          <td class="num">{esc(r.get('MOVIMIENTOS'))}</td>
          <td class="num">{esc(r.get('COMPROBANTES'))}</td>
        </tr>"""
    inv_det = ""
    for r in inv_lista:
        inv_det += f"""<tr>
          <td>{esc(r.get('CNSMOV'))}</td>
          <td>{esc(r.get('TIPO_MOV'))}</td>
          <td>{esc(r.get('IDAREA'))}/{esc(r.get('CCOSTO'))}</td>
          <td>{esc(r.get('FECHA_CONF'))}</td>
          <td>{esc(r.get('NROCOMPROBANTE'))}</td>
        </tr>"""

    inv_section = f"""
<section class="proc" id="inv">
  <h2>Inventario</h2>
  <p class="lead"><strong>Problema:</strong> falta regla en KMCOM (<code>MOV_INVENTARIO</code>) para la combinación
  <strong>tipo de movimiento + área + centro de costo</strong> (modelo contable 01).</p>
  <p><strong>Configurar:</strong> Parametrización contable → KMCOM — agregar filas débito y crédito para cada fila del resumen.</p>
  <h3>Cuántos movimientos por descripción</h3>
  {tbl(['Descripción movimiento', 'Cód. tipo', 'Área', 'Centro costo', 'Movimientos', 'Comprobantes'], inv_rows, 6)}
  <h3>Detalle movimientos</h3>
  {tbl(['Consecutivo', 'Tipo', 'Área/CC', 'Fecha conf.', 'Comprobante errado'], inv_det, 5)}
  <p class="accion">Tras parametrizar: Comprobantes errados → <em>Reconstruir</em> cada comprobante INV.</p>
</section>"""

    # --- CONCI ---
    ttec_rows = ""
    for r in conci_ttec:
        cg = (r.get("CUENTACG_DEBITO") or "").strip()
        falta = "Completar <strong>Cuenta CG</strong> (débito glosa) en tipo técnico" if not cg else "Revisar si aplica otro campo"
        ttec_rows += f"""<tr class="{'row-ko' if not cg else ''}">
          <td>{esc(r.get('TIPOTTEC'))}</td>
          <td>{esc(r.get('NOMBRE_TIPO_TECNICO'))}</td>
          <td>{esc(cg or '(vacío)')}</td>
          <td>{esc(r.get('CUENTALG_CREDITO'))}</td>
          <td class="num">{esc(r.get('FACTURAS_EN_GLOSA'))}</td>
          <td>{falta}</td>
        </tr>"""
    conc_cb = ""
    for r in conci_cbtes:
        conc_cb += f"""<tr>
          <td>{esc(r.get('IDFCONCI'))}</td>
          <td>{esc(r.get('NOREFERENCIA'))}</td>
          <td>{esc(r.get('ANO'))}-{int(r.get('MES') or 0):02d}</td>
          <td class="num">{esc(r.get('LINEAS_ERROR'))}</td>
          <td>{esc(r.get('NROCOMPROBANTE'))}</td>
        </tr>"""

    conci_section = f"""
<section class="proc" id="conci">
  <h2>Conciliaciones — glosas</h2>
  <p class="lead"><strong>Problema:</strong> el débito de la glosa toma la cuenta desde el <strong>tipo técnico de la factura (TTEC)</strong>.
  Donde <strong>Cuenta CG</strong> está vacía, el comprobante queda en error.</p>
  <p><strong>Configurar:</strong> Parametrización → <strong>Tipos técnico factura (TTEC)</strong> — no es KMCOM.</p>
  <h3>Tipos técnico y cuenta débito glosa</h3>
  {tbl(['Código TTEC', 'Nombre', 'Cuenta CG (débito)', 'Cuenta LG', 'Facturas en glosa', 'Qué falta'], ttec_rows, 6)}
  <h3>Comprobantes CONCI en error (3)</h3>
  {tbl(['Id conciliación', 'No. ref.', 'Periodo', 'Líneas error', 'Comprobante'], conc_cb, 5)}
  <p class="accion">Tras completar TTEC: <em>Reconstruir</em> comprobantes CONCI.</p>
</section>"""

    # --- FACTURA ---
    fac_rows = ""
    for r in factura:
        lineas = int(r.get("LINEAS") or 0)
        if lineas == 0:
            accion = "Sin líneas — comprobante anulado o fallido; depurar en errados"
            pref = area = cc = proc = "—"
        else:
            accion = "Completar KMCOM facturación (proceso VENTAS) con prefijo + área + CC de la tabla"
            pref = r.get("PREFIJO_KMCOM") or "?"
            area = r.get("IDAREA_KMCOM") or "?"
            cc = r.get("CCOSTO_KMCOM") or "?"
            proc = r.get("PROCESO_CONTAB") or "VENTAS"
        fac_rows += f"""<tr>
          <td>{esc(r.get('FACTURA'))}</td>
          <td>{esc(r.get('ANO'))}-{int(r.get('MES') or 0):02d}</td>
          <td>{esc(proc)}</td>
          <td>{esc(pref)}</td>
          <td>{esc(area)}</td>
          <td>{esc(cc)}</td>
          <td>{esc(accion)}</td>
        </tr>"""

    fact_section = f"""
<section class="proc" id="factura">
  <h2>Facturación</h2>
  <p class="lead"><strong>Problema:</strong> falta regla KMCOM para el <strong>prefijo del servicio</strong>, <strong>área</strong> y <strong>centro de costo</strong>
  usados al contabilizar la venta (proceso VENTAS).</p>
  {tbl(['Factura', 'Periodo', 'Proceso KMCOM', 'Prefijo', 'Área', 'Centro costo', 'Qué hacer'], fac_rows, 7)}
</section>"""

    # --- CXC ---
    cxc_rows = ""
    for r in cxc:
        cxc_rows += f"""<tr>
          <td>{esc(r.get('NOREFERENCIA'))}</td>
          <td>{esc(r.get('CNSFPAG'))}</td>
          <td>{esc(r.get('ANO'))}-{int(r.get('MES') or 0):02d}</td>
          <td class="num">{esc(r.get('LINEAS'))}</td>
          <td>Reenviar recaudo desde cartera o eliminar cabecera huérfana en comprobantes errados.</td>
        </tr>"""

    cxc_section = f"""
<section class="proc" id="cxc">
  <h2>Recaudos (CXC)</h2>
  {tbl(['Referencia', 'Consecutivo recaudo', 'Periodo', 'Líneas', 'Qué hacer'], cxc_rows, 5)}
</section>"""

    dian_section = f"""
<section class="proc" id="dian">
  <h2>Envío DIAN vs contabilidad — periodo {esc(periodo_label)}</h2>
  <p class="lead">Facturas y notas cartera: estado DIAN en <strong>FACTE</strong> (2 = notificada por la DIAN).
  CxP con documento equivalente: <strong>ESTADODIAN</strong> en FCXP / FCXPDBCR. Por auditoría, lo notificado debe estar contabilizado y lo contabilizado debe estar notificado.</p>
  <p class="accion"><strong>Facturas/notas cartera:</strong> contabilizar o encolar/reprocesar DIAN según el caso (Facturación / Notas DB-CR).
  <strong>CxP:</strong> enviar documento equivalente y notas débito desde CxP cuando aplique; corrija rechazos antes de cerrar.</p>
</section>"""

    fnk_rows = ""
    for r in fnk:
        fnk_rows += f"""<tr><td>{esc(r.get('MODULO'))}</td><td>{esc(r.get('REFERENCIA'))}</td><td>{esc(r.get('ERROR'))}</td></tr>"""

    if pri_abiertos:
        pri_desde = f"{pri_abiertos[0].get('ANO')}-{int(pri_abiertos[0].get('MES') or 0):02d}"
        pri_hasta = f"{pri_abiertos[-1].get('ANO')}-{int(pri_abiertos[-1].get('MES') or 0):02d}"
    else:
        pri_desde = pri_hasta = "?"

    precierre_section = f"""
<section class="proc" id="precierre">
  <h2>Pendientes antes de cerrar {esc(periodo_label)}</h2>
  <p class="lead">Estos hallazgos <strong>no</strong> aparecen como comprobantes errados, pero <strong>bloquean el cierre</strong> del periodo.</p>
  <p class="alert alert-ko"><strong>Periodos contables abiertos:</strong> {n_pri} mes(es) operativos sin cerrar
  (PRI.CERRADO = 0), desde {esc(pri_desde)} hasta {esc(pri_hasta)}.
  Deben cerrarse en orden cronológico después de limpiar errores y pendientes.</p>
  <p class="meta">Listado: {esc(pri_list)}</p>
  <h3>Checklist integridad (FNK) — periodo {esc(periodo_label)}</h3>
  {tbl(['Módulo', 'Referencia', 'Qué falta'], fnk_rows, 3)}
</section>"""

    hoy = date.today().isoformat()
    n_cbtes = sum(int(r.get("COMPROBANTES") or 0) for r in agrupado)

    resumen_ejecutivo = f"""
<div class="doc-part" id="resumen-ejecutivo">
  <h2 class="part-title">Resumen ejecutivo</h2>
  <p class="meta part-lead">Cifras agregadas del periodo de trabajo <strong>{esc(periodo_label)}</strong>.
  El detalle por módulo, acciones y pre-cierre está en la sección «Desarrollo del informe».</p>
  <section class="proc">
    <h3>Comprobantes errados por procedencia y tipo</h3>
    {tbl(['Procedencia', 'Tipo de problema', 'Cantidad comprobantes'], ag_rows, 3)}
  </section>
  <section class="proc">
    <h3>DIAN vs contabilidad — hallazgos</h3>
    <p class="meta">Documentos emitidos en el periodo: {esc(emit_summary or '—')}</p>
    {dian_tbl}
  </section>
</div>"""

    desarrollo = f"""
<div class="doc-part" id="desarrollo">
  <h2 class="part-title">Desarrollo del informe</h2>
  <p class="meta part-lead">Explicación por área, tablas de detalle y checklist antes del cierre contable.</p>
  {dian_section}
  {inv_section}
  {conci_section}
  {fact_section}
  {cxc_section}
  {precierre_section}
</div>"""

    body = resumen_ejecutivo + "\n" + desarrollo

    doc = f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{esc(inst_label)} — Errores contables a corregir</title>
  <style>
    :root {{
      --color-primary: #E67817;
      --color-secondary: #CB500F;
      --color-bg: #fff8ee;
      --color-text: #1a1a1a;
      --color-muted: #5d4e37;
    }}
    @page {{ margin: 18mm; }}
    body {{
      font-family: "Segoe UI", Calibri, sans-serif; font-size: 11pt; line-height: 1.45;
      color: var(--color-text); background: var(--color-bg); margin: 0; padding: 1.5rem;
    }}
    .container {{
      max-width: 920px; margin: 0 auto; background: #fff;
      border: 1px solid #000; border-radius: 4px; padding: 1.75rem 2rem;
    }}
    .brand-bar {{ height: 6px; background: var(--color-primary); margin: -1.75rem -2rem 1rem; border-radius: 4px 4px 0 0; }}
    .brand-head {{ display: flex; align-items: center; gap: 12px; margin-bottom: 1rem; }}
    .brand-mark {{ height: 52px; width: auto; background: #000; border-radius: 8px; padding: 4px 8px; }}
    .brand-name {{ font-size: 1.05rem; font-weight: 700; color: #2c2c2c; letter-spacing: .06em; }}
    .brand-sub {{ font-size: .72rem; color: #64748b; text-transform: uppercase; letter-spacing: .1em; }}
    header {{ border-bottom: 3px solid var(--color-primary); padding-bottom: 1rem; margin-bottom: 1rem; }}
    .doc-purpose {{
      background: #f8fafc; border: 1px solid #cbd5e1; border-left: 4px solid var(--color-primary);
      padding: 1rem 1.15rem; margin-bottom: 1.5rem; border-radius: 0 4px 4px 0;
    }}
    .doc-purpose h2 {{ font-size: 0.95rem; margin: 0 0 0.5rem; color: #334155; border: none; padding: 0; }}
    .doc-purpose p {{ margin: 0.35rem 0; font-size: 0.92rem; color: #475569; }}
    .doc-part {{ margin-bottom: 2.5rem; }}
    .part-title {{ font-size: 1.15rem; color: var(--color-secondary); border-left: 5px solid var(--color-primary); padding-left: 0.65rem; margin: 0 0 0.75rem; }}
    .part-lead {{ margin-bottom: 1rem !important; }}
    h1 {{ color: var(--color-primary); font-size: 1.35rem; margin: 0 0 0.5rem; }}
    h2 {{ color: #333; font-size: 1.1rem; margin-top: 0; border-left: 4px solid var(--color-primary); padding-left: 0.6rem; }}
    .doc-part > .part-title {{ border-left-width: 5px; }}
    h3 {{ font-size: 0.95rem; margin: 1rem 0 0.4rem; }}
    .meta {{ color: var(--color-muted); font-size: 0.9rem; }}
    .proc {{ page-break-inside: avoid; margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid #ddd; }}
    .lead {{ background: #fff8ee; padding: 0.75rem 1rem; border-radius: 4px; border: 1px solid #f0d9b5; }}
    .accion {{ font-size: 0.9rem; color: #1e5631; }}
    table {{ width: 100%; border-collapse: collapse; margin: 0.5rem 0 1rem; font-size: 0.85rem; }}
    th, td {{ border: 1px solid #ccc; padding: 0.35rem 0.5rem; text-align: left; vertical-align: top; }}
    th {{ background: var(--color-primary); color: #fff; }}
    .num {{ text-align: center; }}
    code {{ background: #f0f0f0; padding: 0 0.2rem; font-size: 0.85em; }}
    .alert {{ padding: 0.6rem 0.8rem; border-radius: 4px; margin: 0.75rem 0; }}
    .alert-ko {{ background: #fdecea; border: 1px solid #c0392b; }}
    tr.row-ko td {{ background: #fdecea; }}
    nav.doc-nav {{ margin-bottom: 1.5rem; font-size: 0.9rem; }}
    nav.doc-nav a {{ color: var(--color-secondary); text-decoration: none; }}
    nav.doc-nav a:hover {{ text-decoration: underline; }}
    footer.doc-foot {{ margin-top: 2rem; font-size: 0.8rem; color: #777; border-top: 1px solid #ddd; padding-top: 0.75rem; }}
    @media print {{
      nav.doc-nav {{ display: none !important; }}
      body {{ background: #fff; padding: 0; }}
      th {{ background: #E67817 !important; color: #fff !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
    }}
  </style>
</head>
<body>
  <div class="container">
  <div class="brand-bar"></div>
  <div class="brand-head">
    <img class="brand-mark" src="{esc(logo_href)}" alt="IX Colombia SAS">
    <div>
      <div class="brand-name">IX COLOMBIA SAS</div>
      <div class="brand-sub">Business Analyst · Qrystalos</div>
    </div>
  </div>
  <header>
    <h1>Informe de auditoría contable y cumplimiento DIAN</h1>
    <p class="meta">{esc(inst_label)} · Base {esc(database)} · Generado {esc(hoy)} · Consulta solo lectura</p>
    <p class="meta"><strong>{n_cbtes}</strong> comprobantes en «Comprobantes errados» · Periodo de trabajo <strong>{esc(periodo_label)}</strong></p>
  </header>
  <div class="doc-purpose">
    <h2>Propósito del documento</h2>
    <p>Este informe consolida, para la institución indicada, los <strong>comprobantes contables en error</strong>,
    los <strong>cruces entre envío DIAN y contabilización</strong> del periodo de trabajo, y los <strong>pendientes que impiden el cierre</strong> del mes.</p>
    <p>Está dirigido a soporte, coordinación contable y áreas operativas (inventario, facturación, cartera, CxP) para priorizar correcciones:
    parametrización (KMCOM, TTEC), reconstrucción de comprobantes, reproceso DIAN y cierre ordenado de periodos (PRI).</p>
    <p>No modifica la base de datos; las cifras reflejan el estado al momento de la generación.</p>
  </div>
  <nav class="doc-nav">
    <a href="#resumen-ejecutivo">Resumen ejecutivo</a> ·
    <a href="#desarrollo">Desarrollo del informe</a> ·
    <a href="#dian">DIAN</a> ·
    <a href="#inv">Inventario</a> ·
    <a href="#conci">Glosas</a> ·
    <a href="#factura">Facturación</a> ·
    <a href="#cxc">Recaudos</a> ·
    <a href="#precierre">Pre-cierre</a>
  </nav>
  {body}
  <footer class="doc-foot">
    Documento generado por Qrystalos BA — Oficina de coordinación técnica. Uso interno soporte / cliente.
  </footer>
  </div>
</body>
</html>"""

    meta = {
        "generado": hoy,
        "institucion": inst_label,
        "database": database,
        "envKey": env_key,
        "comprobantes_errados": n_cbtes,
        "periodos_abiertos": n_pri,
        "ttec_tipos": len(conci_ttec),
        "periodo_trabajo": periodo_label,
        "dian_hallazgos": len(dian_cuadro),
    }
    return doc, meta


def main() -> None:
    import sys

    env_key = sys.argv[1] if len(sys.argv) > 1 else "servidorHcodazzi"
    database = sys.argv[2] if len(sys.argv) > 2 else "KHCODAZZI"
    institucion = sys.argv[3] if len(sys.argv) > 3 else "Codazzi"
    out = Path(sys.argv[4]) if len(sys.argv) > 4 else Path("informe-errores-contables.html")
    html_doc, meta = generar_informe(env_key, database, institucion=institucion)
    out.write_text(html_doc, encoding="utf-8")
    meta_path = out.with_name("informe-meta.json")
    import json

    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(str(out.resolve()))


if __name__ == "__main__":
    main()
