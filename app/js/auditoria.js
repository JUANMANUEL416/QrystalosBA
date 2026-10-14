/**
 * Auditoría de procesos — trazas read-only contra SQL Server (vía API BA).
 */
window.QrysAuditoria = (function () {
  const $ = (s) => document.querySelector(s);

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok && data.error) throw new Error(data.error);
    if (!r.ok) throw new Error(r.statusText || String(r.status));
    return data;
  }

  function estadoClass(st) {
    if (st === "ok") return "pill pill-done";
    if (st === "warn") return "pill pill-progress";
    return "pill pill-pending";
  }

  function renderFilas(filas) {
    if (!filas || !filas.length) return "";
    const keys = Object.keys(filas[0]);
    const head = keys.map((k) => `<th>${esc(k)}</th>`).join("");
    const body = filas
      .map(
        (row) =>
          `<tr>${keys.map((k) => `<td>${esc(row[k])}</td>`).join("")}</tr>`
      )
      .join("");
    return `<div class="audit-table-wrap"><table class="data-table audit-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
  }

  let runbookMeta = null;

  function renderAyudaSoporte(p) {
    const items = p.ayudaSoporte || [];
    if (!items.length) return "";
    const lis = items
      .map((a) => `<li><strong>${esc(a.pc)}</strong> — ${esc(a.accion)}</li>`)
      .join("");
    const rb =
      runbookMeta?.urlMarkdown
        ? ` <a class="audit-runbook-link" href="#" data-runbook="1">Runbook completo</a>`
        : "";
    const openAttr = p.estado === "ko" ? " open" : "";
    return `<details class="audit-soporte"${openAttr}>
      <summary>Soporte (acción sugerida)${rb}</summary>
      <ul class="audit-soporte-list">${lis}</ul>
    </details>`;
  }

  function renderPasos(pasos) {
    if (!pasos || !pasos.length) {
      return `<p class="hint">Sin pasos en la traza.</p>`;
    }
    return pasos
      .map((p) => {
        const pcs = (p.puntosCriticos || []).map((id) => `<span class="pill pill-ghost">${esc(id)}</span>`).join(" ");
        return `<article class="audit-paso card-lite">
          <header><span class="${estadoClass(p.estado)}">${esc(p.estado).toUpperCase()}</span>
          <strong>${esc(p.titulo)}</strong></header>
          <p>${esc(p.detalle)}</p>
          ${pcs ? `<p class="hint compact">Puntos críticos: ${pcs}</p>` : ""}
          ${renderAyudaSoporte(p)}
          ${renderFilas(p.filas)}
        </article>`;
      })
      .join("");
  }

  async function abrirRunbookModal() {
    const flujoEl = document.querySelector('input[name="auditFlujo"]:checked');
    const flujoId = flujoEl?.value || DEFAULT_FLUJO;
    const url =
      runbookMeta?.urlMarkdown ||
      `/api/auditoria/runbook?flujoId=${encodeURIComponent(flujoId)}`;
    try {
      const data = await fetchJson(url);
      const md = data.markdown || "";
      const w = window.open("", "_blank", "noopener,noreferrer");
      if (!w) {
        alert("Permita ventanas emergentes para ver el runbook.");
        return;
      }
      const body = md
        .replace(/^### (.*)$/gm, "<h3>$1</h3>")
        .replace(/^## (.*)$/gm, "<h2>$1</h2>")
        .replace(/^# (.*)$/gm, "<h1>$1</h1>")
        .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
        .replace(/\n\n/g, "</p><p>")
        .replace(/\n/g, "<br>");
      w.document.write(
        `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${esc(
          data.titulo || "Runbook"
        )}</title><style>body{font-family:Segoe UI,sans-serif;max-width:52rem;margin:1.5rem auto;padding:0 1rem;line-height:1.45}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:.35rem .5rem}code{background:#f4f4f4;padding:.1rem .25rem}</style></head><body><p>${body}</p></body></html>`
      );
      w.document.close();
    } catch (e) {
      alert(e.message || String(e));
    }
  }

  function bindRunbookLinks(root) {
    root?.querySelectorAll("[data-runbook]").forEach((el) => {
      el.addEventListener("click", (ev) => {
        ev.preventDefault();
        abrirRunbookModal();
      });
    });
  }

  const DEFAULT_FLUJO = "flujo-recaudos-cartera-contab";

  function renderFlujos(flujos) {
    const el = $("#auditFlujosList");
    if (!el) return;
    if (!flujos.length) {
      el.innerHTML = `<p class="hint">No hay flujos documentados.</p>`;
      return;
    }
    el.innerHTML = flujos
      .map(
        (f) => `<label class="audit-flujo-item">
          <input type="radio" name="auditFlujo" value="${esc(f.id)}" ${f.id === DEFAULT_FLUJO ? "checked" : ""}>
          <span><strong>${esc(f.nombre)}</strong>
          <span class="hint compact">${esc(f.descripcion || "")} · ${f.pasos || 0} pasos · ${f.puntosCriticos || 0} puntos críticos</span></span>
        </label>`
      )
      .join("");
    el.querySelectorAll('input[name="auditFlujo"]').forEach((inp) => {
      inp.addEventListener("change", () => {
        if (inp.checked) onFlujoSelected(inp.value);
      });
    });
  }

  function configureParamUI(flujoId) {
    const tipo = $("#auditTipoParam");
    const param = $("#auditParametro");
    const hint = $("#auditParamHint");
    if (flujoId === "flujo-recaudos-cartera-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="cnsfpag">Consecutivo recaudo (CNSFPAG)</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. 0100123456";
      if (hint) hint.textContent = "Identificador del recaudo en FPAG (CNSFPAG).";
    } else if (flujoId === "flujo-rad-cxc-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="cnscxc">Cuenta de cobro (CNSCXC)</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. 0100567890";
      if (hint) hint.textContent = "Consecutivo FCXC (CNSCXC) de la radicación.";
    } else if (flujoId === "flujo-bmov-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="bmov">Llaves BMOV</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. 007/01/1234567890/1";
      if (hint) hint.textContent = "BANCO/SUCURSAL/CTA_BCO/ITEM o REFERENCIA1/ITEM (MCP).";
    } else if (flujoId === "flujo-nomina-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="nomina">Pago nómina</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. NUMDOC/CNSPAGO/CNSNIEPE";
      if (hint) hint.textContent = "MCP NOMINA REF1/2/3 = NUMDOC, CNSPAGO, CNSNIEPE.";
    } else if (flujoId === "flujo-anticipos-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="anticipo">Anticipo</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. CNSANT/CNSFCOM";
      if (hint) hint.textContent = "MCP ANTICIPOS REF1/2 = CNSANT, CNSFCOM.";
    } else if (flujoId === "flujo-iact-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="iact">Evento activo</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. consecutivo CNSIACTH";
      if (hint) hint.textContent = "Historial IACTH (REFERENCIA1 MCP IACT).";
    } else if (flujoId === "flujo-legalizacion-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="fleg">Legalización</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. CNSFLEG";
      if (hint) hint.textContent = "FLEG caja menor (REFERENCIA1 MCP LEGALIZACION).";
    } else if (flujoId === "flujo-cesiones-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="ces">Cesión</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. CNSCES";
      if (hint) hint.textContent = "FCES cesión cartera/CxP (REFERENCIA1 MCP CESIONES).";
    } else if (flujoId === "flujo-ajdep-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="ajdep">Depreciación</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. 2026/10/01 o NRO comprobante";
      if (hint) hint.textContent = "AJDEP: NROCOMPROBANTE o ANO/MES[/IDSEDE] o ANO-MES.";
    } else if (flujoId === "flujo-reversos-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="nro_rev">Reversión</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. NRO reverso o ORIG:NRO_origen";
      if (hint) hint.textContent = "NRO_REV: comprobante MCPE/MCP reversión, o ORIG: + NRO del comprobante origen.";
    } else if (flujoId === "flujo-cierre-periodo-contab") {
      if (tipo) {
        tipo.innerHTML = `<option value="cierre">Cierre periodo</option>`;
        tipo.disabled = true;
      }
      if (param) param.placeholder = "Ej. 2026-10 o 2026/10 (vacío = último abierto)";
      if (hint) hint.textContent = "Fase 2: OBTENER/VPB, FNK paso 2 detalle, NOTDBCR/CXP dup., SALDOMES, USCXS, fotos TBALANCEH.";
    } else {
      if (tipo) {
        tipo.disabled = false;
        tipo.innerHTML = `<option value="ordencompra">Número orden (ORDENCOMPRA)</option>
            <option value="cnsfcom">Consecutivo (CNSFCOM)</option>`;
      }
      if (param) param.placeholder = "Ej. 2424";
      if (hint) hint.textContent = "ORDENCOMPRA o CNSFCOM de la orden de compra.";
    }
  }

  async function onFlujoSelected(flujoId) {
    configureParamUI(flujoId);
    try {
      const doc = await fetchJson(`/api/auditoria/flujo/${encodeURIComponent(flujoId)}`);
      renderDoc(doc);
      runbookMeta = doc.runbook || null;
      const rbBar = $("#auditRunbookBar");
      if (rbBar && runbookMeta) {
        rbBar.hidden = false;
        rbBar.innerHTML = `<p class="hint compact">Runbook: <button type="button" class="btn btn-secondary btn-sm" id="btnAuditRunbook">Abrir runbook soporte</button>
          <span class="hint">(${esc(runbookMeta.archivo || "")})</span></p>`;
        $("#btnAuditRunbook")?.addEventListener("click", abrirRunbookModal);
      }
    } catch (e) {
      const err = $("#auditError");
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
    }
  }

  function renderDoc(doc) {
    const el = $("#auditDocPasos");
    if (!el || !doc.proceso) return;
    const pasos = doc.proceso.pasos || [];
    let variantesHtml = "";
    const varIng = doc.proceso.variantesIngreso;
    if (varIng && typeof varIng === "object") {
      variantesHtml = `<h4 class="audit-usvgs-grupo">Variantes INGRESO</h4><table class="data-table"><thead><tr>
        <th>INGRESO</th><th>Origen</th><th>Contabilidad</th><th>PC</th></tr></thead><tbody>${Object.keys(varIng)
        .map((k) => {
          const v = varIng[k];
          return `<tr><td><strong>${esc(k)}</strong><br><span class="hint compact">${esc(v.nombre || "")}</span></td>
            <td>${esc(v.origen || (v.camposClave || []).join(", "))}</td>
            <td>${esc((v.contabilidad || []).join("; "))}</td>
            <td>${esc((v.puntosCriticos || []).join(", "))}</td></tr>`;
        })
        .join("")}</tbody></table>`;
    }
    el.innerHTML = `<table class="data-table"><thead><tr><th>#</th><th>Etapa</th><th>Qrystalos2</th><th>MODELO</th><th>Tablas</th></tr></thead><tbody>${pasos
      .map((p) => {
        const q = p.qrystalos2 || {};
        return `<tr><td>${p.orden}</td><td>${esc(p.nombre)}</td><td><code>${esc(q.path || q.ruta || "")}</code></td><td>${esc(q.modelo || "")}</td><td>${esc((p.tablas || []).join(", "))}</td></tr>`;
      })
      .join("")}</tbody></table>${variantesHtml}`;
    const pc = doc.puntosCriticos?.puntos || [];
    const pcEl = $("#auditDocPc");
    if (pcEl) {
      pcEl.innerHTML = `<ul class="audit-pc-list">${pc
        .map(
          (x) =>
            `<li><strong>${esc(x.id)}</strong> ${esc(x.nombre)} <span class="hint">[${(x.dimension || []).join(", ")}]</span></li>`
        )
        .join("")}</ul>`;
    }
  }

  async function init() {
    const err = $("#auditError");
    if (err) err.hidden = true;
    try {
      const [srv, flujos, doc] = await Promise.all([
        fetchJson("/api/auditoria/servidores"),
        fetchJson("/api/auditoria/flujos"),
        fetchJson(`/api/auditoria/flujo/${encodeURIComponent(DEFAULT_FLUJO)}`),
      ]);
      const sel = $("#auditServidor");
      if (sel) {
        sel.innerHTML = (srv.servidores || [])
          .map(
            (s) =>
              `<option value="${esc(s.id)}" data-db="${esc(s.baseDatosDefault || "")}">${esc(s.nombre)}</option>`
          )
          .join("");
        sel.addEventListener("change", () => {
          const opt = sel.selectedOptions[0];
          const db = $("#auditBaseDatos");
          if (db && opt && !db.value.trim()) db.value = opt.dataset.db || "";
        });
        const first = sel.selectedOptions[0];
        const dbIn = $("#auditBaseDatos");
        if (dbIn && first && !dbIn.value.trim()) dbIn.value = first.dataset.db || "";
      }
      renderFlujos(flujos.flujos || []);
      loadProcedenciasContab();
      configureParamUI(DEFAULT_FLUJO);
      renderDoc(doc);
      runbookMeta = doc.runbook || null;
      const rbBar = $("#auditRunbookBar");
      if (rbBar && runbookMeta) {
        rbBar.hidden = false;
        rbBar.innerHTML = `<p class="hint compact">Núcleo IEXI↔CxP: <button type="button" class="btn btn-secondary btn-sm" id="btnAuditRunbook">Abrir runbook soporte</button>
          <span class="hint">(${esc(runbookMeta.archivo || "")})</span></p>`;
        $("#btnAuditRunbook")?.addEventListener("click", abrirRunbookModal);
      }
    } catch (e) {
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
    }
  }

  function renderConfigContab(data) {
    const checks = data.checks || [];
    const vars = data.variables || [];
    const res = data.resumen || {};
    const head = `<div class="audit-resumen">
      <p><strong>Config. contable</strong> · ${esc((data.procedencias || []).join(", "))} · BD ${esc(data.baseDatos)}
      · <span class="pill pill-done">${res.ok || 0} OK</span>
      <span class="pill pill-progress">${res.warn || 0} AVISO</span>
      <span class="pill pill-pending">${res.ko || 0} KO</span></p>
      <p class="hint compact">${esc(data.nota || "")}</p>
    </div>`;
    const chkHtml = checks.length
      ? `<h4 class="audit-usvgs-grupo">Comprobaciones cruzadas</h4>${checks
          .map((c) => {
            const pcs = (c.puntosCriticos || [])
              .map((id) => `<span class="pill pill-ghost">${esc(id)}</span>`)
              .join(" ");
            return `<article class="audit-paso card-lite">
              <header><span class="${estadoClass(c.estado)}">${esc(c.estado).toUpperCase()}</span>
              <strong>${esc(c.titulo)}</strong> <span class="hint compact">${esc(c.grupo || "")}</span></header>
              <p>${esc(c.validacion)}</p>
              ${pcs ? `<p class="hint compact">PC: ${pcs}</p>` : ""}
              ${renderFilas(c.filas)}
            </article>`;
          })
          .join("")}`
      : "";
    const varHtml = vars.length
      ? `<h4 class="audit-usvgs-grupo">USVGS (grafo)</h4>${renderUsvgsVariables(vars)}`
      : "";
    const catN3 = data.catalogoValidacionN3 || [];
    const catHtml = catN3.length
      ? `<details class="card-lite mt"><summary class="hint">Catálogo validacionSql N3 (${catN3.length})</summary><ul class="hint compact">${catN3
          .map(
            (x) =>
              `<li><code>${esc(x.procedencia)}</code> · ${esc(x.requireId)} — ${esc(x.validacionSql || "")}${x.checkMotor ? ` → ${esc(x.checkMotor)}` : ""}</li>`
          )
          .join("")}</ul></details>`
      : "";
    const docRef =
      data.referencia && data.tipoReferencia
        ? `<p class="hint compact">Documento: <code>${esc(data.tipoReferencia)}</code> = <strong>${esc(data.referencia)}</strong></p>`
        : "";
    return head + docRef + chkHtml + varHtml + catHtml;
  }

  async function loadProcedenciasContab() {
    const sel = $("#auditProcContab");
    if (!sel) return;
    try {
      const data = await fetchJson("/api/auditoria/procedencias-contab");
      const list = data.procedencias || [];
      const base = sel.innerHTML;
      const extra = list
        .map(
          (p) =>
            `<option value="${esc(p.procedencia)}">${esc(p.procedencia)} — ${esc((p.generadores || [])[0] || "")}</option>`
        )
        .join("");
      sel.innerHTML = base + extra;
      const tipos = data.tiposReferencia || [];
      const selTipo = $("#auditTipoReferencia");
      if (selTipo && tipos.length) {
        const cur = selTipo.value;
        const opts = tipos
          .map(
            (t) =>
              `<option value="${esc(t.id)}">${esc(t.etiqueta || t.id)} — ${esc((t.procedencias || []).join("/"))}</option>`
          )
          .join("");
        selTipo.innerHTML =
          `<option value="">Inferir desde procedencia</option>` + opts;
        if (cur) selTipo.value = cur;
      }
    } catch (_) {
      /* mantener opciones CRITICO / TODAS */
    }
  }

  async function validarConfigContabilidad() {
    const out = $("#auditUsvgsResultado");
    const err = $("#auditError");
    const btn = $("#btnAuditConfigContab");
    if (err) err.hidden = true;
    const servidorId = $("#auditServidor")?.value;
    const baseDatos = $("#auditBaseDatos")?.value?.trim();
    const procedencia = $("#auditProcContab")?.value || "CRITICO";
    const referencia =
      $("#auditDocReferencia")?.value?.trim() ||
      $("#auditConfigCnsfpag")?.value?.trim() ||
      $("#auditParametro")?.value?.trim() ||
      "";
    const tipoSel = ($("#auditTipoReferencia")?.value || "").trim();
    if (!baseDatos) {
      if (err) {
        err.textContent = "Indique base de datos para validar configuración contable.";
        err.hidden = false;
      }
      return;
    }
    if (btn) btn.disabled = true;
    if (out) out.innerHTML = `<p class="hint">Validando grafos contables en ${esc(baseDatos)}…</p>`;
    try {
      const data = await fetchJson("/api/auditoria/config-contabilidad", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          servidorId,
          baseDatos,
          procedencia,
          referencia: referencia || undefined,
          tipoReferencia: referencia && tipoSel ? tipoSel : undefined,
        }),
      });
      if (!data.ok && data.error) throw new Error(data.error);
      if (out) out.innerHTML = renderConfigContab(data);
    } catch (e) {
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
      if (out) out.innerHTML = "";
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function renderUsvgsVariables(variables) {
    if (!variables || !variables.length) {
      return `<p class="hint">Sin variables en catálogo.</p>`;
    }
    let lastGrupo = "";
    const blocks = variables.map((v) => {
      let head = "";
      if (v.grupo !== lastGrupo) {
        lastGrupo = v.grupo;
        head = `<h4 class="audit-usvgs-grupo">${esc(v.grupo)}</h4>`;
      }
      const refs = (v.sqlRefs || []).length
        ? `<p class="hint compact"><strong>SQL (BA/sql):</strong> ${(v.sqlRefs || []).map((s) => `<code>${esc(s)}</code>`).join(", ")}</p>`
        : `<p class="hint compact">SQL: sin referencia en carpeta sql/ local (puede estar en otros SP del producto).</p>`;
      return `${head}<details class="audit-usvgs-item card-lite">
        <summary><span class="${estadoClass(v.estado)}">${esc(v.estado).toUpperCase()}</span>
        <code>${esc(v.id)}</code> = <strong>${esc(v.dato || "—")}</strong>
        ${v.critico ? '<span class="pill pill-ghost">crítica</span>' : ""}</summary>
        <p><strong>Validación:</strong> ${esc(v.validacion)}</p>
        <p><strong>Para qué:</strong> ${esc(v.paraQue)}</p>
        <p><strong>Dónde (METODO/SP):</strong> ${esc(v.donde)}</p>
        <p class="audit-impacto"><strong>Si cambia el valor:</strong> ${esc(v.impactoSiCambia)}</p>
        ${refs}
      </details>`;
    });
    return blocks.join("");
  }

  function renderMapaMovInv(data) {
    const fam = data.familiasUsvgs || [];
    const otros = data.itmoSinUsvgsCatalogo || [];
    const head = `<p class="hint compact">Modelo contable: <code>${esc(data.idModeloContable || "—")}</code> · Ver <code>${esc(data.documento || "")}</code></p>`;
    const famHtml = fam.length
      ? `<table class="data-table audit-table"><thead><tr>
          <th>Estado</th><th>Familia</th><th>USVGS</th><th>IDTIPOMOV</th><th>Validación</th><th>OM INV</th><th>KMCOM</th>
        </tr></thead><tbody>${fam
          .map(
            (r) =>
              `<tr><td><span class="${estadoClass(r.estado)}">${esc(r.estado).toUpperCase()}</span></td>
              <td>${esc(r.familiaNombre)}</td><td><code>${esc(r.usvgs)}</code></td>
              <td><code>${esc(r.idtipomov || "—")}</code></td><td>${esc(r.validacion)}</td>
              <td>${esc(String(r.omInv ?? ""))}</td>
              <td>${esc((r.kmcomProceso || []).join(", "))}</td></tr>`
          )
          .join("")}</tbody></table>`
      : "";
    const otrosHtml = otros.length
      ? `<h4 class="audit-usvgs-grupo">ITMO activos sin USVGS en catálogo BA (${otros.length})</h4>
        <div class="audit-table-wrap"><table class="data-table audit-table"><thead><tr>
          <th>Estado</th><th>IDTIPOMOV</th><th>Descripción</th><th>TIPO</th><th>SECONTABILIZA</th><th>Nota</th>
        </tr></thead><tbody>${otros
          .map(
            (r) =>
              `<tr><td><span class="${estadoClass(r.estado)}">${esc(r.estado).toUpperCase()}</span></td>
              <td><code>${esc(r.idtipomov)}</code></td><td>${esc(r.descripcion)}</td><td>${esc(r.tipo)}</td>
              <td>${esc(r.seContabiliza)}</td><td>${esc(r.validacion)}</td></tr>`
          )
          .join("")}</tbody></table></div>`
      : `<p class="hint">No hay ITMO activos fuera del mapa USVGS.</p>`;
    return head + famHtml + otrosHtml;
  }

  async function mapaMovimientosInventario() {
    const out = $("#auditUsvgsResultado");
    const err = $("#auditError");
    const btn = $("#btnAuditMovInv");
    if (err) err.hidden = true;
    const servidorId = $("#auditServidor")?.value;
    const baseDatos = $("#auditBaseDatos")?.value?.trim();
    if (!baseDatos) {
      if (err) {
        err.textContent = "Indique base de datos para el mapa ITMO.";
        err.hidden = false;
      }
      return;
    }
    if (btn) btn.disabled = true;
    if (out) out.innerHTML = `<p class="hint">Cargando ITMO y familias en ${esc(baseDatos)}…</p>`;
    try {
      const data = await fetchJson("/api/auditoria/movimientos-inventario", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ servidorId, baseDatos }),
      });
      if (!data.ok && data.error) throw new Error(data.error);
      const res = data.resumen || {};
      const banner = `<div class="audit-resumen"><p><strong>Mapa movimientos</strong> · BD ${esc(data.baseDatos)}
        · <span class="pill pill-done">${res.ok || 0} OK</span>
        <span class="pill pill-progress">${res.warn || 0} AVISO</span>
        <span class="pill pill-pending">${res.ko || 0} KO</span></p></div>`;
      if (out) out.innerHTML = banner + renderMapaMovInv(data);
    } catch (e) {
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
      if (out) out.innerHTML = "";
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function validarUsvgs() {
    const out = $("#auditUsvgsResultado");
    const err = $("#auditError");
    const btn = $("#btnAuditUsvgs");
    if (err) err.hidden = true;
    const servidorId = $("#auditServidor")?.value;
    const baseDatos = $("#auditBaseDatos")?.value?.trim();
    if (!baseDatos) {
      if (err) {
        err.textContent = "Indique base de datos para validar USVGS.";
        err.hidden = false;
      }
      return;
    }
    if (btn) btn.disabled = true;
    if (out) out.innerHTML = `<p class="hint">Validando USVGS en ${esc(baseDatos)}…</p>`;
    try {
      const data = await fetchJson("/api/auditoria/usvgs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ servidorId, baseDatos }),
      });
      if (!data.ok && data.error) throw new Error(data.error);
      const res = data.resumen || {};
      const head = `<div class="audit-resumen">
        <p><strong>BD:</strong> ${esc(data.baseDatos)}
        · <span class="pill pill-done">${res.ok || 0} OK</span>
        <span class="pill pill-progress">${res.warn || 0} AVISO</span>
        <span class="pill pill-pending">${res.ko || 0} KO</span></p>
        <p class="hint compact">${esc(data.nota || "")}</p>
      </div>`;
      if (out) out.innerHTML = head + renderUsvgsVariables(data.variables);
    } catch (e) {
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
      if (out) out.innerHTML = "";
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function trazar() {
    const out = $("#auditResultado");
    const err = $("#auditError");
    const btn = $("#btnAuditTrazar");
    if (err) err.hidden = true;
    const servidorId = $("#auditServidor")?.value;
    const baseDatos = $("#auditBaseDatos")?.value?.trim();
    const parametro = $("#auditParametro")?.value?.trim();
    const tipoParam = $("#auditTipoParam")?.value || "ordencompra";
    const flujoEl = document.querySelector('input[name="auditFlujo"]:checked');
    const flujoId = flujoEl?.value || DEFAULT_FLUJO;
    if (!parametro && flujoId !== "flujo-cierre-periodo-contab") {
      if (err) {
        err.textContent =
          flujoId === "flujo-recaudos-cartera-contab"
            ? "Indique CNSFPAG del recaudo."
            : flujoId === "flujo-rad-cxc-contab"
              ? "Indique CNSCXC de la radicación."
              : flujoId === "flujo-bmov-contab"
              ? "Indique llaves BMOV (4 segmentos)."
              : flujoId === "flujo-nomina-contab"
                ? "Indique NUMDOC/CNSPAGO/CNSNIEPE."
                : flujoId === "flujo-anticipos-contab"
                  ? "Indique CNSANT/CNSFCOM."
                  : flujoId === "flujo-iact-contab"
                    ? "Indique CNSIACTH."
                    : flujoId === "flujo-legalizacion-contab"
                      ? "Indique CNSFLEG."
                      : flujoId === "flujo-cesiones-contab"
                        ? "Indique CNSCES."
                        : flujoId === "flujo-ajdep-contab"
                          ? "Indique NRO AJDEP o ANO/MES[/SEDE]."
                          : flujoId === "flujo-reversos-contab"
                            ? "Indique NRO reversión o ORIG:NRO_origen."
                            : flujoId === "flujo-cierre-periodo-contab"
                              ? "Opcional ANO-MES; vacío usa último PRI abierto."
                              : "Indique número de OC (ORDENCOMPRA o CNSFCOM).";
        err.hidden = false;
      }
      return;
    }
    if (btn) btn.disabled = true;
    if (out) out.innerHTML = `<p class="hint">Consultando ${esc(baseDatos)}…</p>`;
    try {
      const data = await fetchJson("/api/auditoria/trazar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ servidorId, baseDatos, parametro, tipoParam, flujoId }),
      });
      if (!data.ok && data.error) throw new Error(data.error);
      const res = data.resumen || {};
      let idLabel = `<strong>CNSFCOM:</strong> ${esc(data.cnsfcom)}`;
      if (data.cnsfpag != null) {
        idLabel = `<strong>CNSFPAG:</strong> ${esc(data.cnsfpag)}${data.ingreso ? ` (${esc(data.ingreso)})` : ""}`;
      } else if (data.cnscxc != null) {
        idLabel = `<strong>CNSCXC:</strong> ${esc(data.cnscxc)}${data.generadorSugerido ? ` · ${esc(data.generadorSugerido)}` : ""}`;
      } else if (data.bmovRef != null) {
        idLabel = `<strong>BMOV:</strong> ${esc(data.bmovRef)}`;
      }
      const head = `<div class="audit-resumen">
        <p>${idLabel} · <strong>BD:</strong> ${esc(data.baseDatos)}
        · <span class="pill pill-done">${res.ok || 0} OK</span>
        <span class="pill pill-progress">${res.warn || 0} AVISO</span>
        <span class="pill pill-pending">${res.ko || 0} KO</span></p>
      </div>`;
      runbookMeta = data.runbook || runbookMeta;
      let koBanner = "";
      if ((res.ko || 0) > 0 && runbookMeta) {
        koBanner =
          `<p class="hint compact audit-ko-runbook">Hay pasos KO: expanda <em>Soporte</em> en cada paso o ` +
          `<a href="#" data-runbook="1">abrir el runbook de soporte</a>.</p>`;
      }
      if (out) {
        out.innerHTML = head + koBanner + renderPasos(data.pasos);
        bindRunbookLinks(out);
      }
    } catch (e) {
      if (err) {
        err.textContent = e.message || String(e);
        err.hidden = false;
      }
      if (out) out.innerHTML = "";
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  let bound = false;
  function bind() {
    if (bound) return;
    bound = true;
    $("#btnAuditTrazar")?.addEventListener("click", trazar);
    $("#btnAuditUsvgs")?.addEventListener("click", validarUsvgs);
    $("#btnAuditMovInv")?.addEventListener("click", mapaMovimientosInventario);
    $("#btnAuditConfigContab")?.addEventListener("click", validarConfigContabilidad);
  }

  return {
    init,
    trazar,
    validarUsvgs,
    mapaMovimientosInventario,
    validarConfigContabilidad,
    bind,
  };
})();
