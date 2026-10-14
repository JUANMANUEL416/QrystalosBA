/**
 * Solicitar requerimiento — documento para comité (BA / funcional).
 */
window.QrysSolicitar = (function () {
  let actual = null;
  let historicoAval = [];
  let chatPoll = null;
  let srTimer = null;
  let ultimoBot = null;
  let ultimoChat = { mensajes: [] };
  let ultimoDocEstado = null;
  let filtroLista = "abiertas";
  let carpetaDialogoSrv = null;
  let rutasCarpetaSrv = null;
  /** @type {FileSystemDirectoryHandle | null} */
  let carpetaDirHandle = null;
  let exportLoadingTimer = null;
  let exportLoadingStarted = 0;
  let ultimoSrExportId = "";

  const CARPETA_EXPORT_DEFAULT = "C:\\Users\\JOSE MANUEL\\Downloads\\sdsd";

  function carpetaExportDefault() {
    return (rutasCarpetaSrv?.exportDefault || CARPETA_EXPORT_DEFAULT).trim();
  }

  function esCarpetaPlataformaCaso(path, id) {
    const sid = (id || "").trim();
    const raw = (path || "").trim();
    if (!sid || !raw) return false;
    const n = raw.replace(/\\/g, "/").replace(/\/+$/, "");
    if (n === `solicitudes/${sid}/plataforma`) return true;
    const caso = (rutasCarpetaSrv?.plataformaCaso || "").replace(/\\/g, "/").replace(/\/+$/, "");
    return !!caso && n === caso;
  }

  const SR_EXPORT_BTNS = [
    "btnSrChatGuardar",
    "btnSrElegirCarpeta",
    "btnSrPcEscritorio",
    "btnSrPcDocumentos",
    "btnSrPcDescargas",
    "btnSrCarpetaPlat",
    "btnSrChatCerrar",
  ];

  const $ = (s) => document.querySelector(s);

  function estaCerrada(sol) {
    if (!sol) return false;
    return String(sol.estado || "").toLowerCase() === "cerrado" || sol.cerrado === true;
  }

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
    if (!r.ok) throw new Error(data.error || data.mensaje || r.statusText || String(r.status));
    return data;
  }

  function setEstado(msg) {
    const el = $("#srEstado");
    if (el) el.textContent = msg || "";
  }

  function renderCriteriosDinamicosDesdeTexto(texto) {
    const list = $("#srCriteriosDinamicosLista");
    if (!list) return;
    const lineas = String(texto || "")
      .split("\n")
      .map((l) => l.replace(/^\d+[\.\)]\s*/, "").replace(/^[-*•]\s*/, "").trim())
      .filter(Boolean);

    if (!lineas.length) {
      list.innerHTML = `<p class="hint compact" style="margin:0.25rem 0;" id="srCriteriosEmpty">Sin criterios agregados. Escriba uno y pulse "+ Añadir criterio".</p>`;
      return;
    }

    list.innerHTML = lineas.map((c, idx) => `
      <div class="dynamic-item-row" data-criterio-idx="${idx}">
        <input type="checkbox" class="dynamic-item-check" checked title="Criterio activo">
        <input type="text" class="dynamic-item-input" value="${esc(c)}" placeholder="Descripción del criterio...">
        <button type="button" class="dynamic-item-btn-remove" title="Eliminar criterio">&times;</button>
      </div>
    `).join("");

    list.querySelectorAll(".dynamic-item-input").forEach((inp) => {
      inp.addEventListener("input", sincronizarCriteriosHaciaTexto);
    });
    list.querySelectorAll(".dynamic-item-check").forEach((chk) => {
      chk.addEventListener("change", sincronizarCriteriosHaciaTexto);
    });
    list.querySelectorAll(".dynamic-item-btn-remove").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.target.closest(".dynamic-item-row")?.remove();
        sincronizarCriteriosHaciaTexto();
      });
    });
  }

  function sincronizarCriteriosHaciaTexto() {
    const rows = document.querySelectorAll("#srCriteriosDinamicosLista .dynamic-item-row");
    const arr = [];
    rows.forEach((r) => {
      const inp = r.querySelector(".dynamic-item-input");
      const chk = r.querySelector(".dynamic-item-check");
      const t = (inp?.value || "").trim();
      if (t) {
        arr.push(chk && !chk.checked ? `[ ] ${t}` : t);
      }
    });
    const txtArea = $("#srCriterios");
    if (txtArea) {
      txtArea.value = arr.map((item, idx) => `${idx + 1}. ${item}`).join("\n");
    }
    const emptyMsg = $("#srCriteriosEmpty");
    if (!arr.length && !emptyMsg) {
      const list = $("#srCriteriosDinamicosLista");
      if (list) list.innerHTML = `<p class="hint compact" style="margin:0.25rem 0;" id="srCriteriosEmpty">Sin criterios agregados. Escriba uno y pulse "+ Añadir criterio".</p>`;
    }
  }

  function agregarNuevoCriterio() {
    const input = $("#srNuevoCriterioInput");
    if (!input) return;
    const val = (input.value || "").trim();
    if (!val) return;
    const emptyMsg = $("#srCriteriosEmpty");
    if (emptyMsg) emptyMsg.remove();

    const list = $("#srCriteriosDinamicosLista");
    if (!list) return;
    const row = document.createElement("div");
    row.className = "dynamic-item-row";
    row.innerHTML = `
      <input type="checkbox" class="dynamic-item-check" checked title="Criterio activo">
      <input type="text" class="dynamic-item-input" value="${esc(val)}" placeholder="Descripción del criterio...">
      <button type="button" class="dynamic-item-btn-remove" title="Eliminar criterio">&times;</button>
    `;
    list.appendChild(row);
    input.value = "";

    row.querySelector(".dynamic-item-input")?.addEventListener("input", sincronizarCriteriosHaciaTexto);
    row.querySelector(".dynamic-item-check")?.addEventListener("change", sincronizarCriteriosHaciaTexto);
    row.querySelector(".dynamic-item-btn-remove")?.addEventListener("click", () => {
      row.remove();
      sincronizarCriteriosHaciaTexto();
    });
    sincronizarCriteriosHaciaTexto();
  }

  function collect() {
    const prev = actual && typeof actual === "object" ? { ...actual } : {};
    const avalPrev = prev.aval && typeof prev.aval === "object" ? prev.aval : {};
    const avalAplica = $("#srAvalAplica") ? $("#srAvalAplica").checked : !!avalPrev.aplica;
    return {
      ...prev,
      id: ($("#srId")?.value || prev.id || "").trim(),
      titulo: $("#srTitulo")?.value || "",
      proyecto: $("#srProyecto")?.value || "",
      modulo: $("#srModulo")?.value || prev.modulo || "",
      procesoId: $("#srProcesoId")?.value || prev.procesoId || "",
      prioridad: $("#srPrioridad")?.value || prev.prioridad || "Media",
      analista: $("#srAnalista")?.value || prev.analista || "",
      necesidad: $("#srNecesidad")?.value || "",
      hoy: $("#srHoy")?.value || prev.hoy || "",
      propuesta: $("#srPropuesta")?.value || prev.propuesta || "",
      justificacion: $("#srJustificacion")?.value || prev.justificacion || "",
      alcance: $("#srAlcance")?.value || prev.alcance || "",
      restricciones: $("#srRestricciones")?.value || prev.restricciones || "",
      criterios: $("#srCriterios")?.value || prev.criterios || "",
      analisis: $("#srAnalisis")?.value || prev.analisis || "",
      recomendacion: $("#srRecomendacion")?.value || prev.recomendacion || "",
      aval: {
        aplica: avalAplica,
        idReq: $("#srAvalIdReq")?.value || avalPrev.idReq || "",
        idCaso: $("#srAvalIdCaso")?.value || avalPrev.idCaso || "",
        titulo: $("#srAvalTitulo")?.value || avalPrev.titulo || "",
        notas: $("#srAvalNotas")?.value || avalPrev.notas || "",
      },
    };
  }

  function solicitudIdActiva() {
    return ($("#srId")?.value || "").trim();
  }

  function pintarSolicitudExportActiva(sol) {
    const el = $("#srExportActiva");
    if (!el || !sol?.id) {
      if (el) el.hidden = true;
      return;
    }
    const tit = (sol.titulo || "").trim();
    el.hidden = false;
    el.textContent = tit
      ? `Solicitud ${sol.id} — ${tit}`
      : `Solicitud ${sol.id}`;
  }

  function resetExportPorSolicitud(sol) {
    if (!sol?.id) return;
    carpetaDirHandle = null;
    rutasCarpetaSrv = null;
    const def = carpetaExportDefault();
    syncCarpetaUI(def, { limpiarNavegador: false });
    setCarpetaFeedback(`Los PDF e imagen de ${sol.id} se guardan en ${def} (subcarpeta ${sol.id}).`);
    pintarSolicitudExportActiva(sol);
  }

  function fill(sol) {
    actual = sol;
    if (!sol) return;
    if (sol.id && sol.id !== ultimoSrExportId) {
      resetExportPorSolicitud(sol);
      ultimoSrExportId = sol.id;
    }
    const set = (id, v) => {
      const el = $(id);
      if (el) el.value = v || "";
    };
    set("#srId", sol.id);
    set("#srAnalista", sol.analista);
    set("#srTitulo", sol.titulo);
    set("#srProyecto", sol.proyecto);
    set("#srModulo", sol.modulo);
    set("#srProcesoId", sol.procesoId);
    set("#srPrioridad", sol.prioridad || "Media");
    set("#srNecesidad", sol.necesidad);
    set("#srHoy", sol.hoy);
    set("#srPropuesta", sol.propuesta);
    set("#srJustificacion", sol.justificacion);
    set("#srAnalisis", sol.analisis);
    set("#srAlcance", sol.alcance);
    set("#srRestricciones", sol.restricciones);
    set("#srCriterios", sol.criterios);
    set("#srRecomendacion", sol.recomendacion);
    const aval = sol.aval || {};
    if ($("#srAvalAplica")) $("#srAvalAplica").checked = !!aval.aplica;
    toggleAval();
    set("#srAvalIdReq", aval.idReq);
    set("#srAvalIdCaso", aval.idCaso);
    set("#srAvalTitulo", aval.titulo);
    set("#srAvalNotas", aval.notas);
    renderCriteriosDinamicosDesdeTexto(sol.criterios || "");
    const res = $("#srAvalResumen");
    if (res) {
      res.textContent = aval.aplica && (aval.idReq || aval.idCaso)
        ? `REQ ${aval.idReq || "—"} · ${aval.idCaso || ""} ${aval.titulo || ""}`.trim()
        : "Ninguno.";
    }
    const link = $("#srDocLink");
    if (link && sol.documento?.url) {
      link.href = sol.documento.url;
      link.hidden = false;
    } else if (link) {
      link.hidden = true;
    }
    const defPlat = carpetaExportDefault();
    let carpetaPlat = (sol.plataforma?.carpeta || "").trim() || defPlat;
    if (sol.id && (esCarpetaPlataformaCaso(carpetaPlat, sol.id)
      || (carpetaPlat.includes("SR") && !carpetaPlat.includes(sol.id)))) {
      carpetaPlat = defPlat;
    }
    syncCarpetaUI(carpetaPlat, { limpiarNavegador: false });
    pintarSolicitudExportActiva(sol);
    if (sol.id) {
      cargarRutasCarpetaSugeridas(sol.id).then(() => {
        if (actual?.id !== sol.id) return;
        const vis = ($("#srCarpetaVisible")?.value || "").trim();
        if (!vis || esCarpetaPlataformaCaso(vis, sol.id)) {
          syncCarpetaUI(carpetaExportDefault(), { limpiarNavegador: false });
        }
      }).catch(() => {});
    }
    ensureCarpetaDialogoInfo().catch(() => {});
    updateAssetButtons(estadoFromSolicitud(sol));
    refreshDocEstado(sol.id).catch(() => {
      hideDocAviso();
      updateAssetButtons(estadoFromSolicitud(actual));
    });
    pintarWorkspace(sol);
    setFormLocked(estaCerrada(sol));
    syncAnalisisBoton(sol);
    renderArchivos(sol.archivos || []);
    const diagRel = typeof sol.diagramaFlujo === "string"
      ? sol.diagramaFlujo
      : (sol.diagramaFlujo?.ruta || sol.documento?.diagramaFlujo || "");
    renderChatAssets._extras = {
      diagrama: diagRel
        ? {
            ruta: diagRel,
            titulo: "Diagrama de flujo",
            url: `/api/solicitar/${sol.id}/diagrama/${diagRel.split("/").pop()}`,
          }
        : null,
      entregables: (sol.plataforma?.archivos || []).filter((a) => {
        const n = a?.nombre || "";
        return !n || n.startsWith(`${sol.id}-`) || n === "documento.html";
      }).map((a) => ({
        ...a,
        url: a.url || `/api/solicitar/${sol.id}/plataforma/${a.nombre}`,
      })),
    };
    renderChatAssets(
      sol.documento,
      (sol.mockups || (sol.documento && sol.documento.mockups) || []).map((r) =>
        typeof r === "string" ? { ruta: r, titulo: r.split("/").pop(), url: `/api/solicitar/${sol.id}/mockup/${r.split("/").pop()}` } : r
      ),
    );
  }

  function pintarWorkspace(sol) {
    const cerrada = estaCerrada(sol);
    const id = sol?.id || "";
    const titulo = sol?.titulo || (id ? id : "Nueva necesidad");
    const ws = $("#srWorkspaceTitulo");
    const meta = $("#srWorkspaceMeta");
    const chatT = $("#srChatTitulo");
    if (ws) ws.textContent = titulo;
    if (meta) {
      meta.textContent = id
        ? `${id}${sol?.proyecto ? ` · ${sol.proyecto}` : ""} · ${cerrada ? "Cerrada" : "Abierta"}`
        : "Se asigna ID al guardar.";
    }
    if (chatT) chatT.textContent = id ? `Chat · ${id}` : "Chat de esta solicitud";
    const btnCerrar = $("#btnSrCerrar");
    if (btnCerrar) btnCerrar.hidden = !id || cerrada;
    const btnChatCerrar = $("#btnSrChatCerrar");
    if (btnChatCerrar) {
      btnChatCerrar.hidden = !id || cerrada;
      btnChatCerrar.disabled = cerrada;
    }
    const tabForm = $("#srTabForm");
    const tabChat = $("#srTabChat");
    if (tabForm) tabForm.disabled = false;
    if (tabChat) tabChat.disabled = !id;
  }

  function setFormLocked(locked) {
    ["#srTitulo", "#srProyecto", "#srNecesidad", "#srAnalisis", "#srRecomendacion", "#srChatInput"].forEach((sel) => {
      const el = $(sel);
      if (el) el.disabled = !!locked;
    });
    ["#btnSrGuardar", "#btnSrDocumento", "#btnSrEnviarChat"].forEach((sel) => {
      const el = $(sel);
      if (el) el.disabled = !!locked;
    });
    syncAnalisisBoton(actual);
  }

  function limpiarFormulario() {
    actual = null;
    ultimoChat = { mensajes: [] };
    ultimoBot = null;
    ultimoDocEstado = null;
    const vacio = {
      id: "",
      titulo: "",
      proyecto: "",
      necesidad: "",
      analisis: "",
      recomendacion: "",
      estado: "abierto",
      documento: null,
    };
    fill(vacio);
    actual = null;
    const box = $("#srChatMensajes");
    if (box) box.innerHTML = `<p class="hint">Sin mensajes. Guarde y analice para abrir este Chat.</p>`;
    hideDocAviso();
    setFormLocked(false);
    const tabChat = $("#srTabChat");
    if (tabChat) tabChat.disabled = true;
    const tabForm = $("#srTabForm");
    if (tabForm) tabForm.disabled = false;
    pintarWorkspace(vacio);
  }

  function estadoFromSolicitud(sol) {
    if (!sol?.id) return null;
    const doc = sol.documento || {};
    const raw = doc.mockups || sol.mockups || [];
    const lista = Array.isArray(raw) ? raw : raw ? [raw] : [];
    const mockups = lista
      .map((item) => String(item || "").trim().replace(/^\//, ""))
      .filter(Boolean)
      .map((rel) => {
        const nombre = rel.split("/").pop() || rel;
        return {
          ruta: rel,
          url: `/${rel}`,
          titulo: nombre,
          tipo: /sp|flujo-sp/i.test(nombre) ? "sp" : "ux",
          existe: true,
        };
      });
    const diag = String(sol.diagramaFlujo || doc.diagramaFlujo || "").trim().replace(/^\//, "");
    const linea = [];
    if (diag) {
      linea.push({
        tipo: "diagrama",
        etiqueta: "Diagrama de flujo",
        ruta: diag,
        cuando: doc.generadoEn || "",
        origen: sol.aval?.idCaso ? `aval ${sol.aval.idCaso}` : "declarado",
      });
    }
    mockups.forEach((m) => {
      linea.push({
        tipo: "mockup",
        etiqueta: m.titulo,
        ruta: m.ruta,
        cuando: "",
        origen: "carpeta mockups",
      });
    });
    if (doc.generadoEn) {
      linea.push({
        tipo: "documento",
        etiqueta: "Documento comité",
        ruta: doc.ruta || "",
        cuando: doc.generadoEn,
        origen: "Generar documento",
      });
    }
    return {
      id: sol.id,
      generadoEn: doc.generadoEn || "",
      diagramaFlujo: diag,
      diagramaUrl: diag ? `/${diag}` : "",
      mockups,
      mockupsActuales: mockups.map((m) => m.ruta),
      necesitaRegenerar: false,
      lineaTiempo: linea,
      fromLocal: true,
    };
  }

  function hideDocAviso() {
    $("#srDocAviso")?.classList.add("hidden");
    const lista = $("#srDocAvisoLista");
    if (lista) lista.innerHTML = "";
  }

  function renderDocAviso(est) {
    const box = $("#srDocAviso");
    const lista = $("#srDocAvisoLista");
    const btn = $("#btnSrDocumento");
    if (!box || !est) return;
    if (!est.necesitaRegenerar) {
      hideDocAviso();
      if (btn) btn.removeAttribute("title");
      return;
    }
    box.classList.remove("hidden");
    const gen = est.generadoEn ? ` (último: ${fmtHora(est.generadoEn)})` : "";
    const txt = $("#srDocAvisoTexto");
    if (txt) {
      txt.textContent =
        `Pulse Generar documento para incrustar mockups y diagrama actualizados${gen}.`;
    }
    if (lista) {
      lista.innerHTML = (est.motivos || [])
        .map((m) => `<li>${esc(m)}</li>`)
        .join("");
    }
    if (btn) {
      btn.title = "Mockups o diagrama cambiaron — regenere para incrustarlos en el documento.";
    }
  }

  function assetUrl(rel) {
    const r = String(rel || "").trim().replace(/^\//, "");
    if (!r) return "";
    if (location.protocol === "file:") {
      return new URL(`../${r}`, location.href).href;
    }
    return new URL(`/${r}`, location.origin).href;
  }

  function mockupEtiqueta(rel) {
    const n = String(rel || "").split("/").pop() || "mockup";
    if (/sp|flujo-sp/i.test(n)) return `Mockup SP — ${n}`;
    return `Mockup UX — ${n}`;
  }

  function renderLineaTiempo(est) {
    const box = $("#srAssetsLinea");
    if (!box) return;
    const items = est?.lineaTiempo || [];
    if (!items.length) {
      box.innerHTML = "";
      box.classList.add("hidden");
      return;
    }
    box.classList.remove("hidden");
    box.innerHTML = `<strong>Cuándo se generó cada vista</strong><ul class="sr-assets-linea">${
      items.map((it) => {
        const cuando = it.cuando ? fmtHora(it.cuando) : "—";
        const orig = it.origen ? ` · ${it.origen}` : "";
        return `<li><span class="sr-asset-tipo">${esc(it.tipo || "")}</span> `
          + `<strong>${esc(it.etiqueta || "")}</strong> — ${esc(cuando)}${esc(orig)}`
          + `<br><code class="sr-asset-ruta">${esc(it.ruta || "")}</code></li>`;
      }).join("")
    }</ul>`;
  }

  function updateAssetButtons(est) {
    ultimoDocEstado = est || null;
    const btnDiag = $("#btnSrVerDiagrama");
    const btnMock = $("#btnSrVerMockup");
    const pick = $("#srMockupPick");
    const hint = $("#srAssetsHint");
    const diag = est?.diagramaFlujo || "";
    const mocks = (est?.mockups || [])
      .filter((m) => m.existe !== false)
      .map((m) => (typeof m === "string" ? { ruta: m, titulo: m.split("/").pop() } : m));

    if (btnDiag) {
      btnDiag.disabled = !diag;
      btnDiag.dataset.ruta = diag;
    }
    if (btnMock) {
      btnMock.disabled = !mocks.length;
    }
    if (pick) {
      if (mocks.length > 1) {
        pick.classList.remove("hidden");
        pick.innerHTML = mocks
          .map((m) => {
            const r = m.ruta || m;
            const t = m.titulo || mockupEtiqueta(r);
            return `<option value="${esc(r)}">${esc(t)}</option>`;
          })
          .join("");
      } else {
        pick.classList.add("hidden");
        pick.innerHTML = mocks.length
          ? `<option value="${esc(mocks[0].ruta || mocks[0])}"></option>`
          : "";
      }
    }
    if (hint) {
      if (!est?.id) {
        hint.textContent = "Guarde la solicitud. Use Ver diagrama / Ver mockup para revisar; el Chat queda con borrador para pedir ajustes.";
      } else if (!diag && !mocks.length) {
        hint.textContent =
          "Sin diagrama ni mockups aún. Asocie aval, indique diagramaFlujo o guarde HTML en solicitudes/{id}/mockups/.";
      } else {
        const partes = [];
        if (diag) partes.push("diagrama");
        if (mocks.length) partes.push(`${mocks.length} mockup(s)`);
        const avisoLocal = est.fromLocal ? " (fechas exactas tras reiniciar servidor o Ctrl+F5)" : "";
        hint.textContent = `Disponible: ${partes.join(" · ")}. Pulse Ver… → pestaña nueva + borrador en Chat.${avisoLocal}`;
      }
    }
    renderLineaTiempo(est);
  }

  function irChatConBorrador(texto) {
    showPanel("chat");
    const input = $("#srChatInput");
    if (input) {
      input.value = texto;
      input.focus();
      const len = input.value.length;
      input.setSelectionRange(len, len);
    }
  }

  async function asegurarEstadoAssets() {
    const id = ($("#srId")?.value || "").trim();
    if (!id) {
      setEstado("Guarde la solicitud primero.");
      return null;
    }
    if (ultimoDocEstado?.id === id) return ultimoDocEstado;
    return refreshDocEstado(id);
  }

  async function verDiagrama() {
    const est = await asegurarEstadoAssets();
    if (!est) return;
    const rel = est.diagramaFlujo || "";
    if (!rel) {
      setEstado("No hay diagrama. Indique diagramaFlujo en la solicitud o asocie un aval con dictamen.");
      return;
    }
    const url = est.diagramaUrl ? new URL(est.diagramaUrl, location.origin).href : assetUrl(rel);
    window.open(url, "_blank", "noopener,noreferrer");
    irChatConBorrador(
      `Revise el diagrama de flujo (${rel}).\n\n`
        + "Solicito estos ajustes al mapa (pantalla → API → SP):\n"
        + "- \n\n"
        + "Tras acordar, regenere el documento de comité si aplica.",
    );
    setEstado("Diagrama abierto. Ajuste el borrador en el Chat y pulse Enviar.");
  }

  async function verMockup() {
    const est = await asegurarEstadoAssets();
    if (!est) return;
    const mocks = (est.mockups || []).filter((m) => m.existe !== false);
    const rels = mocks.length
      ? mocks.map((m) => m.ruta || m)
      : (est.mockupsActuales || []);
    if (!rels.length) {
      setEstado("No hay mockups. Guarde HTML en solicitudes/{id}/mockups/ o vincule el aval del caso activo.");
      return;
    }
    const pick = $("#srMockupPick");
    let rel = rels[0];
    if (rels.length > 1 && pick && !pick.classList.contains("hidden")) {
      rel = pick.value || rel;
    }
    const meta = mocks.find((m) => (m.ruta || m) === rel) || { ruta: rel, titulo: rel.split("/").pop() };
    const url = meta.url ? new URL(meta.url, location.origin).href : assetUrl(rel);
    window.open(url, "_blank", "noopener,noreferrer");
    const esSp = /sp|flujo-sp/i.test(rel);
    irChatConBorrador(
      `Revise el ${esSp ? "mockup SP (secuencia METODO)" : "mockup UX (pantallas)"}: ${meta.titulo || rel}.\n\n`
        + "Solicito estos ajustes al flujo propuesto:\n"
        + "- \n\n"
        + "Tras acordar, regenere el documento de comité.",
    );
    setEstado("Mockup abierto. Ajuste el borrador en el Chat y pulse Enviar.");
  }

  async function refreshDocEstado(idSr) {
    const id = (idSr || $("#srId")?.value || "").trim();
    if (!id || location.protocol === "file:") {
      hideDocAviso();
      updateAssetButtons(null);
      return null;
    }
    const est = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/documento/estado`);
    renderDocAviso(est);
    updateAssetButtons(est);
    return est;
  }

  function toggleAval() {
    const box = $("#srAvalBox");
    if (box) box.hidden = !$("#srAvalAplica")?.checked;
  }

  let listaProcesosCache = [];

  async function cargarProcesos() {
    const sel = $("#srProcesoId");
    if (!sel || sel.tagName !== "SELECT") return;
    const prev = sel.value;
    try {
      const data = await fetchJson("/api/conocimiento");
      listaProcesosCache = data.indice?.procesos || data.procesos || [];
      const hubKpiProcesos = $("#hubKpiProcesosTotal");
      if (hubKpiProcesos && listaProcesosCache.length) {
        hubKpiProcesos.textContent = String(listaProcesosCache.length);
      }
      sel.innerHTML = `<option value="">-- Seleccionar proceso o inferir al analizar --</option>`
        + listaProcesosCache.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}${p.modulo ? ` (${esc(p.modulo)})` : ""}</option>`).join("");
      if (prev) sel.value = prev;
    } catch (_) {
      /* sin servidor */
    }
  }

  async function guardar() {
    const body = collect();
    if (!(body.titulo || body.necesidad).trim()) {
      setEstado("Escriba la necesidad o el problema.");
      return null;
    }
    if (estaCerrada(actual || body)) {
      setEstado("Esta solicitud está cerrada.");
      return null;
    }
    const data = await fetchJson("/api/solicitar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    fill(data.solicitud);
    setEstado(`Guardado ${data.solicitud.id}`);
    await refreshLista();
    return data.solicitud;
  }

  function analisisYaLanzado(sol) {
    if (!sol) return false;
    if (sol.analisisLanzado) return true;
    return !!(sol.analisis || "").trim();
  }

  function syncAnalisisBoton(sol) {
    const btn = $("#btnSrAnalizar");
    const hint = $("#srAssetsHint");
    const hecho = analisisYaLanzado(sol);
    if (btn) {
      btn.disabled = hecho || estaCerrada(sol);
      btn.title = hecho
        ? "El análisis inicial ya se lanzó. Continúe en el Chat."
        : "Contrasta la necesidad con conocimiento/ (una sola vez)";
    }
    if (hint) {
      hint.textContent = hecho
        ? "Análisis lanzado. Siga en el Chat: documento, mockup y adjuntos están ahí."
        : "Guarde, analice una vez y converse en el Chat. Documento y mockup se generan ahí.";
    }
    const btnDocForm = $("#btnSrDocumento");
    if (btnDocForm) btnDocForm.hidden = !!hecho;
  }

  function renderArchivos(lista) {
    const items = lista || [];
    const html = items.length
      ? items.map((a) => {
          const url = a.url || "";
          return `<li><a href="${esc(url)}" target="_blank" rel="noopener">${esc(a.nombre || "archivo")}</a> <span class="hint">${esc(a.tipo || "")}</span></li>`;
        }).join("")
      : `<li class="hint compact">Sin adjuntos.</li>`;
    ["#srArchivosList", "#srChatArchivosList"].forEach((sel) => {
      const el = $(sel);
      if (el) el.innerHTML = html;
    });
  }

  function renderChatAssets(doc, mockups) {
    const id = ($("#srId")?.value || actual?.id || "").trim();
    const docList = $("#srChatDocList");
    const btnAbrir = $("#btnSrChatAbrirDoc");
    const url = doc?.url || (id ? `/api/solicitar/${encodeURIComponent(id)}/documento` : "");
    if (docList) {
      docList.innerHTML = url && (doc?.ruta || doc)
        ? `<li class="chat-doc-item"><a href="${esc(url)}" target="_blank" rel="noopener">Documento de comité</a></li>`
        : `<li class="chat-doc-empty hint">Aún no hay documento. Pulse Generar documento.</li>`;
    }
    if (btnAbrir) {
      btnAbrir.disabled = !url || !doc?.url;
      btnAbrir.dataset.url = url || "";
    }
    const mlist = $("#srChatMockupsList");
    const btnM = $("#btnSrChatAbrirMockup");
    const mocks = mockups || [];
    if (mlist) {
      mlist.innerHTML = mocks.length
        ? mocks.map((m) => `<li class="chat-mockups-item"><a href="${esc(m.url || "")}" target="_blank" rel="noopener">${esc(m.titulo || m.ruta || "mockup")}</a></li>`).join("")
        : `<li class="chat-mockups-empty hint">Sin mockups. Pulse Generar mockup.</li>`;
    }
    if (btnM) {
      const first = mocks.find((m) => m.url);
      btnM.disabled = !first;
      btnM.dataset.url = first?.url || "";
    }
    const extras = renderChatAssets._extras || {};
    const dlist = $("#srChatDiagList");
    const btnD = $("#btnSrChatAbrirDiag");
    const diag = extras.diagrama;
    if (dlist) {
      dlist.innerHTML = diag?.url
        ? `<li class="chat-mockups-item"><a href="${esc(diag.url)}" target="_blank" rel="noopener">${esc(diag.titulo || "Diagrama de flujo")}</a></li>`
        : `<li class="chat-mockups-empty hint">Sin diagrama. Pulse Generar diagrama o Cerrar solicitud.</li>`;
    }
    if (btnD) {
      btnD.disabled = !diag?.url;
      btnD.dataset.url = diag?.url || "";
    }
    const elist = $("#srChatEntregables");
    const ents = extras.entregables || [];
    if (elist) {
      elist.innerHTML = ents.length
        ? ents.map((a) => `<li class="chat-doc-item"><a href="${esc(a.url || "")}" target="_blank" rel="noopener">${esc(a.nombre || a.tipo || "archivo")}</a></li>`).join("")
        : `<li class="chat-doc-empty hint">Al cerrar se generan PDF de la solicitud, PDF del mockup e imagen del flujo.</li>`;
    }
  }

  async function aplicarPanel(data) {
    const sid = data.solicitud?.id || data.id || solicitudIdActiva();
    if (data.solicitud) fill(data.solicitud);
    if (data.chat) ultimoChat = data.chat;
    if (data.bot) ultimoBot = data.bot;
    renderArchivos(data.archivos || data.solicitud?.archivos || []);
    const entRaw = Array.isArray(data.entregables)
      ? data.entregables
      : (data.solicitud?.plataforma?.archivos || []);
    const entregables = entRaw.filter((a) => {
      const n = a?.nombre || "";
      return !sid || !n || n.startsWith(`${sid}-`);
    });
    const diagPrev = renderChatAssets._extras?.diagrama;
    const diagrama = data.diagrama
      || (sid && diagPrev?.url?.includes(`/${encodeURIComponent(sid)}/`) ? diagPrev : null);
    renderChatAssets._extras = { diagrama, entregables };
    renderChatAssets(data.solicitud?.documento || data.documentos?.[0], data.mockups);
    syncAnalisisBoton(data.solicitud || actual);
    if (data.chat) renderChat(data.chat, data.bot || ultimoBot);
  }

  function leerArchivoTexto(file) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(String(r.result || ""));
      r.onerror = () => reject(new Error("No se pudo leer el archivo"));
      r.readAsText(file, "utf-8");
    });
  }

  function leerArchivoDataUrl(file) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = () => reject(new Error("No se pudo leer el archivo"));
      r.readAsDataURL(file);
    });
  }

  async function subirArchivoSr(file) {
    const esTextoNecesidad = /\.(md|txt)$/i.test(file.name || "");
    // Un .md/.txt trae la necesidad: si el formulario está vacío, se prellena antes de guardar
    // (guardar() exige título o necesidad). El servidor hace lo mismo sobre lo persistido.
    if (esTextoNecesidad) {
      const nec = $("#srNecesidad");
      if (nec && !nec.value.trim() && !($("#srTitulo")?.value || "").trim()) {
        const txt = await leerArchivoTexto(file);
        if (txt.trim()) nec.value = txt.trim();
      }
    }
    // Guardar siempre antes: el servidor vuelca el .md/.txt en «Necesidad» sobre lo ya persistido.
    await guardar();
    const sid = ($("#srId")?.value || actual?.id || "").trim();
    if (!sid) throw new Error("Guarde la solicitud antes de adjuntar.");
    const dataUrl = await leerArchivoDataUrl(file);
    setEstado(esTextoNecesidad ? `Leyendo ${file.name}…` : `Subiendo ${file.name}…`);
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(sid)}/archivo`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nombre: file.name, dataUrl, tipo: esTextoNecesidad ? "necesidad" : "normativa" }),
    });
    await aplicarPanel(data);
    const cargado = data.archivo?.tipo === "necesidad";
    setEstado(cargado
      ? `Necesidad cargada desde ${file.name}. Revise el campo y siga en el Chat.`
      : `Adjunto: ${file.name}`);
    if (sid) showPanel("chat");
    if (data.bot && data.bot.estado === "trabajando") startPoll("trabajando");
  }

  async function analizar() {
    const sol = await guardar();
    if (!sol) return;
    if (analisisYaLanzado(sol)) {
      setEstado("El análisis ya se lanzó. Siga en el Chat.");
      showPanel("chat");
      return;
    }
    const btnAn = $("#btnSrAnalizar");
    if (btnAn) btnAn.disabled = true;
    setEstado("Analizando con el modelo local y la base de conocimiento…");
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(sol.id)}/analizar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(collect()),
    });
    if (data.solicitud) fill(data.solicitud);
    ultimoBot = data.bot || { estado: "trabajando", iniciadoEn: new Date().toISOString(), heartbeatEn: new Date().toISOString(), pid: 0 };
    showPanel("chat");
    await refrescarChat().catch(() => renderChat(ultimoChat, ultimoBot));
    startPoll("trabajando");
    setEstado("El modelo local está contrastando la necesidad. Vea el Chat. Puede tardar un par de minutos.");
  }

  async function documento() {
    const sol = await guardar();
    if (!sol) return;
    let est = null;
    try {
      est = await refreshDocEstado(sol.id);
    } catch {
      /* sin aviso */
    }
    if (est?.necesitaRegenerar && est.tieneDocumento) {
      const detalle = (est.motivos || []).slice(0, 4).join("\n• ");
      const ok = confirm(
        "El documento del comité no refleja los mockups/diagrama actuales.\n\n"
          + (detalle ? `• ${detalle}\n\n` : "")
          + "¿Regenerar documento.html ahora con las vistas incrustadas?",
      );
      if (!ok) {
        setEstado("Generación cancelada. Actualice mockups y pulse Generar documento cuando quiera.");
        return;
      }
    } else if (est?.necesitaRegenerar && !est.tieneDocumento) {
      setEstado("Primera generación: se incrustarán mockups y diagrama si existen.");
    }
    setEstado("Generando documento…");
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(sol.id)}/documento`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(collect()),
    });
    await aplicarPanel(data);
    if (data.documento) {
      const link = $("#srDocLink");
      if (link) {
        link.href = data.documento.url;
        link.hidden = false;
      }
      window.open(data.documento.url, "_blank");
    }
    if (data.estadoDocumento) renderDocAviso(data.estadoDocumento);
    else await refreshDocEstado(sol.id).catch(() => hideDocAviso());
    showPanel("chat");
    setEstado(`Documento listo: ${data.documento?.ruta || ""}`);
  }

  function syncCarpetaUI(path, { limpiarNavegador = true } = {}) {
    const p = (path || "").trim();
    if (limpiarNavegador && p && !p.startsWith("browser:")) {
      carpetaDirHandle = null;
    }
    if ($("#srCarpetaPlataforma")) $("#srCarpetaPlataforma").value = p;
    if ($("#srCarpetaVisible")) $("#srCarpetaVisible").value = p;
  }

  function soportaElegirCarpetaNavegador() {
    return typeof window.showDirectoryPicker === "function";
  }

  let exportLock = false;

  function tituloOcupado(texto) {
    const t = String(texto || "");
    if (/cerr/i.test(t)) return "Cerrando solicitud";
    if (/copi/i.test(t)) return "Copiando archivos";
    return "Guardando documentos";
  }

  function setExportLoading(on, texto) {
    const box = $("#srExportLoading");
    const txt = $("#srExportLoadingText");
    if (txt && texto) txt.textContent = texto;
    if (box) box.hidden = !on;
    SR_EXPORT_BTNS.forEach((id) => {
      const b = document.getElementById(id);
      if (b) b.disabled = !!on;
    });
    const aviso = (texto || "Espere a que termine.") + " No abra otra solicitud ni cambie de ventana.";
    if (on) {
      if (!exportLock) {
        exportLock = true;
        window.QrysOcupado?.mostrar(tituloOcupado(texto), aviso, solicitudIdActiva() ? `Solicitud ${solicitudIdActiva()}` : "");
      } else {
        const det = document.getElementById("analisisLoadingDetail");
        const tit = document.getElementById("analisisLoadingTitle");
        if (tit) tit.textContent = tituloOcupado(texto);
        if (det) det.textContent = aviso;
      }
    } else if (exportLock) {
      exportLock = false;
      window.QrysOcupado?.ocultar();
    }
    if (on) {
      exportLoadingStarted = Date.now();
      const tick = $("#srExportLoadingTimer");
      if (exportLoadingTimer) clearInterval(exportLoadingTimer);
      exportLoadingTimer = setInterval(() => {
        if (!tick || box?.hidden) return;
        const s = Math.floor((Date.now() - exportLoadingStarted) / 1000);
        tick.textContent = s > 0 ? `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}` : "";
      }, 500);
    } else if (exportLoadingTimer) {
      clearInterval(exportLoadingTimer);
      exportLoadingTimer = null;
      const tick = $("#srExportLoadingTimer");
      if (tick) tick.textContent = "";
    }
  }

  async function elegirCarpetaEnNavegador(startIn) {
    if (!soportaElegirCarpetaNavegador()) {
      return null;
    }
    try {
      const opts = { mode: "readwrite", id: "qrystalos-ba-export" };
      if (startIn) opts.startIn = startIn;
      const picked = await window.showDirectoryPicker(opts);
      const id = solicitudIdActiva();
      carpetaDirHandle = id ? await asegurarSubcarpetaExportPc(id, picked) : picked;
      const label = carpetaDirHandle?.name || picked?.name || "carpeta";
      syncCarpetaUI(`browser:${label}`, { limpiarNavegador: false });
      const donde = startIn ? ` (${startIn})` : "";
      setCarpetaFeedback(
        id && label.toUpperCase() === id.toUpperCase()
          ? `Subcarpeta «${label}»${donde}. Pulse Guardar selección.`
          : `Carpeta «${label}»${donde}. Pulse Guardar selección.`,
      );
      return carpetaDirHandle;
    } catch (e) {
      if (e && e.name === "AbortError") {
        setCarpetaFeedback("Canceló la selección de carpeta.", true);
        return null;
      }
      throw e;
    }
  }

  async function asegurarSubcarpetaExportPc(id, dirHandle) {
    if (!dirHandle || !id) return dirHandle;
    const baseName = (dirHandle.name || "").trim();
    if (baseName.toUpperCase() === id.toUpperCase()) {
      return dirHandle;
    }
    try {
      const sub = await dirHandle.getDirectoryHandle(id, { create: true });
      syncCarpetaUI(`browser:${id}`, { limpiarNavegador: false });
      carpetaDirHandle = sub;
      setCarpetaFeedback(`Se usa la subcarpeta «${id}» (no se mezcla con otros archivos).`);
      return sub;
    } catch (_) {
      return dirHandle;
    }
  }

  async function copiarEntregablesANavegador(id, archivos) {
    if (!carpetaDirHandle || !archivos?.length) return 0;
    const dest = await asegurarSubcarpetaExportPc(id, carpetaDirHandle);
    let n = 0;
    for (const a of archivos) {
      const nombre = a.nombre;
      if (!nombre) continue;
      const url = a.url || `/api/solicitar/${encodeURIComponent(id)}/plataforma/${encodeURIComponent(nombre)}`;
      const r = await fetch(url, { cache: "no-store" });
      if (!r.ok) throw new Error(`No se pudo descargar ${nombre}`);
      const blob = await r.blob();
      const fh = await dest.getFileHandle(nombre, { create: true });
      const w = await fh.createWritable();
      await w.write(blob);
      await w.close();
      n += 1;
    }
    return n;
  }

  function archivosConUrl(id, lista) {
    return (lista || []).map((a) => ({
      ...a,
      url: a.url || (a.nombre
        ? `/api/solicitar/${encodeURIComponent(id)}/plataforma/${encodeURIComponent(a.nombre)}`
        : ""),
    }));
  }

  function setCarpetaFeedback(msg, isErr) {
    const el = $("#srCarpetaFeedback");
    if (el) {
      el.textContent = msg || "";
      el.classList.toggle("sr-carpeta-feedback--err", !!isErr);
    }
    if (msg) setEstado(msg);
  }

  async function ensureCarpetaDialogoInfo() {
    if (carpetaDialogoSrv) return carpetaDialogoSrv;
    try {
      const h = await fetchJson("/api/health");
      carpetaDialogoSrv = h.carpetaDialogo || { disponible: true, motivo: "" };
    } catch {
      carpetaDialogoSrv = { disponible: true, motivo: "" };
    }
    if (!carpetaDialogoSrv.disponible) {
      setCarpetaFeedback(carpetaDialogoSrv.motivo, true);
    }
    return carpetaDialogoSrv;
  }

  async function cargarRutasCarpetaSugeridas(id) {
    const sid = (id || "").trim();
    if (!sid) {
      rutasCarpetaSrv = null;
      return null;
    }
    try {
      const data = await fetchJson(
        `/api/solicitar/carpetas-sugeridas?sr=${encodeURIComponent(sid)}`,
      );
      rutasCarpetaSrv = data.rutas || null;
    } catch {
      rutasCarpetaSrv = null;
    }
    return rutasCarpetaSrv;
  }

  function promptCarpetaManual(inicial, aviso) {
    if (aviso) setCarpetaFeedback(aviso, true);
    $("#srCarpetaVisible")?.focus();
    const typed = window.prompt(
      `${aviso ? `${aviso}\n\n` : ""}Escriba la carpeta completa en este equipo.\nEjemplo: C:\\\\Users\\\\JOSE MANUEL\\\\Desktop`,
      inicial || "",
    );
    const p = (typed || "").trim();
    if (p) {
      syncCarpetaUI(p);
      setCarpetaFeedback(`Carpeta: ${p}`);
    } else if (aviso) {
      setCarpetaFeedback("Sin carpeta. Use Escritorio, pegue la ruta o Elegir carpeta.", true);
    }
    return p;
  }

  function opcionesExport() {
    return {
      incluirDocumento: !!$("#srExpDocumento")?.checked,
      incluirMockups: !!$("#srExpMockups")?.checked,
      incluirDiagrama: !!$("#srExpDiagrama")?.checked,
    };
  }

  async function elegirCarpetaDialogo() {
    const info = await ensureCarpetaDialogoInfo();
    const inicial = ($("#srCarpetaVisible")?.value || $("#srCarpetaPlataforma")?.value
      || actual?.plataforma?.carpeta || "").trim();

    if (soportaElegirCarpetaNavegador()) {
      const h = await elegirCarpetaEnNavegador(null);
      if (h) return `browser:${h.name || "pc"}`;
    }

    if (!info.disponible) {
      return promptCarpetaManual(
        inicial,
        info.motivo || "Use Chrome/Edge, pulse Elegir carpeta, o Escritorio / Carpeta del caso.",
      );
    }
    const btn = $("#btnSrElegirCarpeta");
    if (btn) btn.disabled = true;
    setCarpetaFeedback(
      "Abriendo ventana de Windows en el servidor… Si no la ve, use Elegir carpeta (navegador) o Escritorio.",
    );
    try {
      const r = await fetch("/api/solicitar/elegir-carpeta", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ inicial }),
        cache: "no-store",
      });
      const data = await r.json().catch(() => ({}));
      if (data.ok && data.carpeta) {
        syncCarpetaUI(data.carpeta);
        setCarpetaFeedback(`Carpeta en el servidor: ${data.carpeta}`);
        return data.carpeta;
      }
      if (data.interactive === false && soportaElegirCarpetaNavegador()) {
        carpetaDialogoSrv = { disponible: false, motivo: data.error || info.motivo };
        const h = await elegirCarpetaEnNavegador(null);
        if (h) return `browser:${h.name || "pc"}`;
      }
      return promptCarpetaManual(inicial, data.error || info.motivo);
    } catch (e) {
      return promptCarpetaManual(inicial, e.message || "No se pudo llamar al servidor.");
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function carpetaParaGuardar({ forzarDialogo = false } = {}) {
    if (carpetaDirHandle) return "";
    const vis = ($("#srCarpetaVisible")?.value || $("#srCarpetaPlataforma")?.value || "").trim();
    if (vis && !vis.startsWith("browser:") && !forzarDialogo) return vis;
    if (vis && vis.startsWith("browser:") && carpetaDirHandle) return "";
    return elegirCarpetaDialogo();
  }

  async function guardarPdfImagen(llamada = {}) {
    const propio = !llamada.yaBloqueado;
    const id = solicitudIdActiva();
    if (!id) {
      const sol = await guardar();
      if (!sol) return null;
      return guardarPdfImagen(llamada);
    }
    if (actual?.id && actual.id !== id) {
      setCarpetaFeedback(`Abra de nuevo ${id} en la lista (otra solicitud en pantalla).`, true);
      return null;
    }
    const opts = opcionesExport();
    if (!opts.incluirDocumento && !opts.incluirMockups && !opts.incluirDiagrama) {
      setEstado("Marque al menos un archivo (PDF solicitud, PDF mockup o imagen del flujo).");
      return null;
    }
    const usarNavegador = !!carpetaDirHandle;
    let carpeta = "";
    try {
      if (usarNavegador) {
        await asegurarSubcarpetaExportPc(id, carpetaDirHandle);
      }
      if (!usarNavegador) {
        carpeta = await carpetaParaGuardar();
        if (!carpeta) {
          setEstado("Pulse Escritorio/Documentos/Descargas o Elegir carpeta.");
          return null;
        }
        syncCarpetaUI(carpeta);
      }
      const avisoGen = usarNavegador
        ? "Generando PDF e imagen en el servidor (1–3 min)… luego se copian a su carpeta."
        : "Generando PDF e imagen en el servidor (1–3 min)…";
      if (propio) setExportLoading(true, avisoGen);
      else setExportLoading(true, avisoGen);
      setCarpetaFeedback(`Generando entregables de ${id}…`);
      const data = await fetchJson(
        `/api/solicitar/${encodeURIComponent(id)}/export-plataforma`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            solicitudId: id,
            regenerarDocumento: true,
            carpetaPlataforma: usarNavegador ? "" : carpeta,
            opciones: opts,
          }),
        },
      );
      const archivos = archivosConUrl(id, data.archivos || data.entregables || []);
      if (usarNavegador && archivos.length) {
        setExportLoading(true, `Copiando ${archivos.length} archivo(s) a «${carpetaDirHandle.name}»…`);
        try {
          const n = await copiarEntregablesANavegador(id, archivos);
          setCarpetaFeedback(`Listo: ${n} archivo(s) en «${carpetaDirHandle.name}».`);
        } catch (e) {
          setCarpetaFeedback(e.message || "No se pudieron copiar a su carpeta.", true);
          throw e;
        }
      }
      await aplicarPanel({ ...data, archivos });
      const lista = archivos.map((a) => a.nombre).filter(Boolean);
      const avisos = lista.length
        ? ""
        : (data.avisos || data.solicitud?.plataforma?.avisos || []).join(" ");
      if (!lista.length && avisos) {
        setCarpetaFeedback(
          `${avisos} Reinicie reiniciar-servidor.bat. Plan B: Abrir documento / mockup / diagrama → Ctrl+P → PDF.`,
          true,
        );
      } else if (lista.length) {
        setCarpetaFeedback(`Listo (${id}): ${lista.join(", ")}`);
      }
      setEstado(
        lista.length
          ? usarNavegador
            ? `Copiados en su PC: ${lista.join(", ")}`
            : `Guardado en ${data.carpeta || carpeta}: ${lista.join(", ")}`
          : `No se generaron PDF. ${avisos || "Revise Chrome/Edge en el servidor."}`,
      );
      return data;
    } catch (e) {
      setCarpetaFeedback(e.message || "Error al generar.", true);
      setEstado(e.message || "Error al generar.");
      return null;
    } finally {
      if (propio) setExportLoading(false);
    }
  }

  async function refreshLista() {
    const body = $("#srListaBody");
    if (!body) return;
    try {
      const data = await fetchJson("/api/solicitar");
      const items = data.items || [];

      const nTotal = items.length;
      const nAbiertas = items.filter((i) => !estaCerrada(i)).length;
      const nCerradas = nTotal - nAbiertas;
      const nConDoc = items.filter((i) => i.tieneDocumento).length;
      const nConAval = items.filter((i) => !!i.avalReq).length;

      const setEl = (id, val) => {
        const el = $(id);
        if (el) el.textContent = String(val);
      };
      setEl("#srKpiTotal", nTotal);
      setEl("#srKpiAbiertas", nAbiertas);
      setEl("#srKpiConDoc", nConDoc);
      setEl("#srKpiConAval", nConAval);
      setEl("#hubKpiSrTotal", nAbiertas);
      setEl("#srCountAbiertas", nAbiertas);
      setEl("#srCountCerradas", nCerradas);
      setEl("#srCountTodas", nTotal);

      const q = String($("#srFiltroTexto")?.value || "").trim().toLowerCase();
      const btnClear = $("#btnLimpiarFiltroSr");
      if (btnClear) btnClear.hidden = !q;

      const filtrados = items.filter((i) => {
        const cerrada = estaCerrada(i);
        if (filtroLista === "abiertas" && cerrada) return false;
        if (filtroLista === "cerradas" && !cerrada) return false;
        if (q) {
          const matchId = String(i.id || "").toLowerCase().includes(q);
          const matchTit = String(i.titulo || "").toLowerCase().includes(q);
          const matchProy = String(i.proyecto || "").toLowerCase().includes(q);
          const matchProc = String(i.procesoId || "").toLowerCase().includes(q);
          const matchAval = String(i.avalReq || "").toLowerCase().includes(q);
          if (!matchId && !matchTit && !matchProy && !matchProc && !matchAval) return false;
        }
        return true;
      });

      if (!filtrados.length) {
        body.innerHTML = `<tr><td colspan="6" class="hint" style="text-align:center;padding:2.2rem 1rem;">${
          q
            ? `Ninguna solicitud coincide con «${esc(q)}». <button type="button" class="btn btn-ghost btn-sm" onclick="document.getElementById('srFiltroTexto').value='';window.QrysSolicitar&&window.QrysSolicitar.refresh();">Limpiar filtro</button>`
            : items.length
              ? "No hay solicitudes en este filtro."
              : "Aún no hay solicitudes de requerimiento. Pulse '+ Nueva solicitud'."
        }</td></tr>`;
        return;
      }

      body.innerHTML = filtrados.map((i) => {
        const cerrada = estaCerrada(i);
        const badge = cerrada
          ? `<span class="sr-badge-closed">Cerrada</span>`
          : `<span class="sr-badge-open">Abierta</span>`;
        const prio = i.prioridad || "Media";
        const prioClass = String(prio).toLowerCase().replace(/[^a-z]/g, "");
        const docBtn = i.tieneDocumento
          ? `<a href="/api/solicitar/${encodeURIComponent(i.id)}/documento" target="_blank" rel="noopener" class="btn btn-secondary btn-sm" title="Abrir dictamen HTML para comité" style="padding:0.25rem 0.55rem;font-size:0.78rem;">Doc HTML</a>`
          : "";
        const acciones = `
          <div style="display:flex;gap:0.4rem;justify-content:flex-end;align-items:center;">
            ${docBtn}
            <button type="button" class="btn btn-primary btn-sm" data-sr-abrir="${esc(i.id)}" style="padding:0.25rem 0.65rem;">${cerrada ? "Reabrir" : "Abrir"}</button>
          </div>`;
        return `<tr>
          <td><code style="font-weight:700;color:var(--q-primary);background:#fff4e8;padding:2px 7px;border-radius:4px;font-size:0.86rem;">${esc(i.id)}</code></td>
          <td>
            <div class="cell-title-col">
              <span class="cell-main-text">${esc(i.titulo || "(Sin título)")}</span>
              ${i.avalReq ? `<small class="hint" style="color:var(--q-primary);font-weight:500;">Aval REQ ${esc(i.avalReq)}</small>` : ""}
            </div>
          </td>
          <td>
            <div style="display:flex;flex-wrap:wrap;gap:4px;">
              ${i.proyecto ? `<span class="chip-tag chip-tag--cliente">${esc(i.proyecto)}</span>` : ""}
              ${i.procesoId ? `<span class="chip-tag chip-tag--proceso">${esc(i.procesoId)}</span>` : ""}
            </div>
          </td>
          <td><span class="prio-badge prio-${prioClass}">${esc(prio)}</span></td>
          <td>${badge}</td>
          <td>${acciones}</td>
        </tr>`;
      }).join("");
    } catch (e) {
      body.innerHTML = `<tr><td colspan="6">${esc(e.message)}</td></tr>`;
    }
  }

  async function abrir(id) {
    if (window.__qrysOcupado) {
      setEstado("Espere a que termine guardar o el cierre. No se abre otra solicitud.");
      return;
    }
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}`);
    if (estaCerrada(data.solicitud)) {
      const re = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/reabrir`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      data.solicitud = re.solicitud || data.solicitud;
      if (re.chat) data.chat = re.chat;
    }
    fill(data.solicitud);
    if (data.estadoDocumento) {
      renderDocAviso(data.estadoDocumento);
      updateAssetButtons(data.estadoDocumento);
    }
    ultimoBot = data.bot || null;
    renderChat(data.chat, data.bot);
    showPanel("chat");
    setEstado(`Abierta ${id}. Pulse Cerrar solicitud o Guardar PDF e imagen.`);
  }

  async function cerrarActual() {
    const id = solicitudIdActiva();
    if (!id) {
      setEstado("Guarde la solicitud antes de cerrarla.");
      return;
    }
    const opts = opcionesExport();
    const yaGuardada = !!(actual?.plataforma?.exportadoEn && (actual?.plataforma?.archivos || []).length);
    if (!yaGuardada && !opts.incluirDocumento && !opts.incluirMockups && !opts.incluirDiagrama) {
      setEstado("Marque al menos un archivo antes de cerrar, o pulse Guardar selección antes.");
      return;
    }
    if (!confirm(
      yaGuardada
        ? "¿Cerrar esta solicitud?\n\nYa hay archivos del último Guardar: no se vuelven a generar.\nQuedará en la lista y no se podrá editar."
        : "¿Cerrar esta solicitud?\n\nAún no hay archivos guardados: se generan PDF e imagen y después se cierra.\nQuedará en la lista y no se podrá editar.",
    )) return;
    const usarNavegador = !!carpetaDirHandle;
    let carpeta = "";
    if (!yaGuardada && !usarNavegador) {
      carpeta = await carpetaParaGuardar();
      if (!carpeta) {
        setEstado("Cierre cancelado: pulse Elegir carpeta o use Escritorio.");
        return;
      }
      syncCarpetaUI(carpeta);
    }
    setExportLoading(
      true,
      yaGuardada
        ? "Cerrando solicitud. No cambie de ventana."
        : "Cerrando solicitud y generando documentos (1–3 min). No cambie de ventana.",
    );
    try {
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/cerrar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        solicitudId: id,
        regenerarDocumento: !yaGuardada,
        carpetaPlataforma: usarNavegador ? "" : carpeta,
        opciones: opts,
      }),
    });
    const archivosCerrar = archivosConUrl(id, data.entregables || data.archivos);
    if (!data.reutilizado && usarNavegador && archivosCerrar.length) {
      try {
        await copiarEntregablesANavegador(id, archivosCerrar);
      } catch (e) {
        setCarpetaFeedback(e.message || "Cerrada, pero falló copia a su carpeta.", true);
      }
    }
    actual = data.solicitud || actual;
    await aplicarPanel(data);
    if (actual) fill(actual);
    showPanel("chat");
    const files = data.entregables || data.archivos || [];
    if (!data.reutilizado) {
      files.forEach((f) => {
        if (f.url) window.open(f.url, "_blank");
      });
    }
    const avisos = (data.solicitud?.plataforma?.avisos || data.avisos || []).join(" ");
    setEstado(
      data.reutilizado
        ? `Cerrada ${id}. Se conservaron los archivos ya guardados.`
        : files.length
          ? `Cerrada ${id}. Entregables: ${files.map((f) => f.nombre).join(", ")}`
          : `Cerrada ${id}.${avisos ? ` ${avisos}` : ""}`,
    );
    await refreshLista();
    } catch (e) {
      setCarpetaFeedback(e.message || "Error al cerrar.", true);
      setEstado(e.message || "Error al cerrar.");
    } finally {
      setExportLoading(false);
    }
  }

  function fmtHora(iso) {
    if (!iso) return "";
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return String(iso);
    return d.toLocaleString("es-CO", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit" });
  }

  function fmtElapsed(iso) {
    if (!iso) return "0:00";
    const t0 = new Date(iso).getTime();
    if (Number.isNaN(t0)) return "0:00";
    const sec = Math.max(0, Math.floor((Date.now() - t0) / 1000));
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
  }

  function stopSrTimer() {
    if (srTimer) {
      clearInterval(srTimer);
      srTimer = null;
    }
    const el = $("#srChatTimer");
    if (el) el.classList.add("hidden");
  }

  function startSrTimer(bot) {
    const el = $("#srChatTimer");
    if (!el) return;
    stopSrTimer();
    el.classList.remove("hidden");
    const tick = () => {
      const hb = bot.heartbeatEn ? new Date(bot.heartbeatEn).getTime() : null;
      const hace = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
      let vivo = "arrancando…";
      if (bot.pidVivo === false && (bot.pid || 0) > 0) vivo = "proceso detenido";
      else if (hace != null && hace <= 15) vivo = "latido OK";
      else if (hace != null) vivo = `sin latido (${hace}s)`;
      el.textContent = `${fmtElapsed(bot.iniciadoEn)} · ${vivo}`;
    };
    tick();
    srTimer = setInterval(tick, 1000);
  }

  function computeSrStatus(bot, chat) {
    const b = bot || {};
    const hb = b.heartbeatEn ? new Date(b.heartbeatEn).getTime() : (b.iniciadoEn ? new Date(b.iniciadoEn).getTime() : null);
    const haceHb = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
    const botMuerto =
      b.estado === "trabajando" &&
      (b.pidVivo === false || (haceHb != null && haceHb > 45));

    if (b.estado === "trabajando" && !botMuerto) {
      return {
        code: "trabajando",
        label: "El agente está procesando",
        detail: "Lea el Chat y conocimiento/. No cierre esta pestaña; la respuesta aparece aquí.",
        bot: b,
      };
    }
    if (b.estado === "sin_clave") {
      return {
        code: "esperando",
        label: "Falta CURSOR_API_KEY",
        detail: "Péguela en .env (empieza por crsr_) y reinicie abrir-app.bat.",
      };
    }
    if (b.estado === "error" || botMuerto) {
      return {
        code: "esperando",
        label: "El bot no respondió",
        detail: b.error || "Se quedó sin latido. Vuelva a Enviar o deje el mensaje: el agente en Cursor lo toma al continuar.",
      };
    }

    const relevantes = ((chat && chat.mensajes) || []).filter((m) => m.autor !== "sistema");
    const ultimo = relevantes[relevantes.length - 1];
    if (ultimo?.autor === "agente") {
      return {
        code: "esperando",
        label: "El agente ya respondió",
        detail: `Último mensaje: ${fmtHora(ultimo.fecha)}. Siga solo en este Chat.`,
      };
    }
    if (ultimo?.autor === "coordinador") {
      return {
        code: "esperando",
        label: "Mensaje guardado — esperando al agente",
        detail: "El texto ya está en disco. Si el punto no pasa a procesando, pulse Enviar de nuevo o continúe en Cursor.",
      };
    }
    return {
      code: "esperando",
      label: "Chat listo",
      detail: "Guarde la solicitud y escriba aquí. El agente responde en este hilo.",
    };
  }

  function renderSrStatus(estado) {
    const box = $("#srChatEstado");
    const label = $("#srChatEstadoLabel");
    const detail = $("#srChatEstadoDetail");
    if (!box || !label || !detail) return estado?.code;
    if (!estado) {
      box.classList.add("hidden");
      stopSrTimer();
      return null;
    }
    box.classList.remove("hidden", "chat-estado-trabajando", "chat-estado-esperando", "chat-estado-cerrado");
    box.classList.add(`chat-estado-${estado.code}`);
    label.textContent = estado.label;
    detail.textContent = estado.detail;
    if (estado.code === "trabajando" && estado.bot) startSrTimer(estado.bot);
    else stopSrTimer();
    const input = $("#srChatInput");
    if (input) {
      input.placeholder = estado.code === "trabajando"
        ? "Procesando… la respuesta aparece abajo. Puede escribir otro ajuste."
        : "Ajuste la necesidad, el aval o pida el documento…";
    }
    return estado.code;
  }

  function renderChat(chat, bot) {
    const box = $("#srChatMensajes");
    if (!box) return;
    ultimoChat = chat || { mensajes: [] };
    if (bot) ultimoBot = bot;
    const msgs = ultimoChat.mensajes || [];
    const html = msgs.map((m) => {
      const cls =
        m.autor === "agente" ? "chat-msg-agente" : m.autor === "sistema" ? "chat-msg-sistema" : "chat-msg-coord";
      const quien = { agente: "Agente", coordinador: "Usted", sistema: "Sistema" }[m.autor] || m.autor;
      return `<div class="chat-msg ${cls}">
        <div class="chat-msg-head"><strong>${esc(quien)}</strong> <small>${esc(fmtHora(m.fecha))}</small></div>
        <div class="chat-msg-body">${esc(m.texto).replace(/\n/g, "<br>")}</div>
      </div>`;
    }).join("");
    const estado = computeSrStatus(ultimoBot, ultimoChat);
    const extra = estado.code === "trabajando"
      ? `<div class="chat-msg chat-msg-sistema chat-msg-procesando">
          <div class="chat-msg-head"><strong>Agente</strong> <small>procesando…</small></div>
          <div class="chat-msg-body">Está leyendo este Chat y conocimiento/. En unos segundos aparece la respuesta aquí.</div>
        </div>`
      : "";
    box.innerHTML = html || extra
      ? html + extra
      : `<p class="hint">Sin mensajes.</p>`;
    box.scrollTop = box.scrollHeight;
    renderSrStatus(estado);
  }

  async function refrescarChat() {
    const id = ($("#srId")?.value || "").trim();
    if (!id) return null;
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}`);
    ultimoBot = data.bot || ultimoBot;
    renderChat(data.chat, data.bot);
    if (data.solicitud) {
      const prev = collect();
      if (!prev.analisis && data.solicitud.analisis) fill(data.solicitud);
      else {
        syncAnalisisBoton(data.solicitud);
        renderArchivos(data.archivos || data.solicitud.archivos || []);
        renderChatAssets(data.solicitud.documento, data.mockups);
      }
    }
    return data;
  }

  async function enviarChat() {
    const id = ($("#srId")?.value || "").trim();
    const texto = ($("#srChatInput")?.value || "").trim();
    if (!id) {
      setEstado("Guarde la solicitud primero.");
      return;
    }
    if (!texto) return;
    if (/^guardar(\s|$)/i.test(texto) || /^guardar\s+(pdf|imagen|archivos)/i.test(texto)) {
      $("#srChatInput").value = "";
      await guardarPdfImagen();
      return;
    }
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ texto }),
    });
    $("#srChatInput").value = "";
    ultimoBot = data.bot || { estado: "trabajando", iniciadoEn: new Date().toISOString(), heartbeatEn: new Date().toISOString(), pid: 0 };
    renderChat(data.chat || ultimoChat, ultimoBot);
    startPoll("trabajando");
    setEstado("Mensaje enviado. El agente está procesando.");
  }

  function startPoll(statusCode) {
    stopPoll();
    const id = ($("#srId")?.value || "").trim();
    if (!id) return;
    const ms = statusCode === "trabajando" ? 1500 : 4000;
    chatPoll = setInterval(async () => {
      try {
        const data = await refrescarChat();
        const code = computeSrStatus(data?.bot, data?.chat).code;
        if (code !== statusCode) {
          startPoll(code);
        }
      } catch (_) { /* */ }
    }, ms);
  }

  function stopPoll() {
    if (chatPoll) {
      clearInterval(chatPoll);
      chatPoll = null;
    }
  }

  function showPanel(name) {
    const tabForm = $("#srTabForm");
    const tabChat = $("#srTabChat");
    const hayId = !!(($("#srId")?.value || actual?.id || "").trim());
    if (tabForm) tabForm.disabled = false;
    if (tabChat) tabChat.disabled = !hayId;
    if (name === "chat" && !hayId) {
      setEstado("Abra o cree una solicitud para usar su Chat.");
      return;
    }
    ["form", "lista", "chat"].forEach((p) => {
      const el = $(`#srPanel${p[0].toUpperCase()}${p.slice(1)}`);
      if (el) el.classList.toggle("hidden", p !== name);
    });
    document.querySelectorAll("[data-sr-panel]").forEach((btn) => {
      btn.classList.toggle("is-on", btn.dataset.srPanel === name);
    });
    if (name !== "chat") stopPoll();
    if (name === "lista") refreshLista();
    if (name === "chat") {
      refrescarChat()
        .then((data) => startPoll(computeSrStatus(data?.bot, data?.chat).code))
        .catch(() => startPoll());
    }
    if (name === "form") {
      refreshDocEstado().catch(() => {
        hideDocAviso();
        updateAssetButtons(estadoFromSolicitud(actual));
      });
    }
  }

  async function cargarAvales() {
    try {
      const data = await fetchJson("/api/historico");
      historicoAval = data.historico || [];
    } catch (_) {
      historicoAval = [];
    }
  }

  function filtrarAvales() {
    const q = ($("#srAvalBuscar")?.value || "").trim().toLowerCase();
    const box = $("#srAvalResultados");
    if (!box) return;
    if (!q) {
      box.innerHTML = "";
      return;
    }
    const hits = historicoAval.filter((h) => {
      const blob = `${h.idReq || ""} ${h.idCaso || ""} ${h.titulo || ""} ${h.proyecto || ""}`.toLowerCase();
      return blob.includes(q);
    }).slice(0, 8);
    box.innerHTML = hits.map((h) => `<button type="button" class="sr-aval-item" data-req="${esc(h.idReq || "")}" data-caso="${esc(h.idCaso || "")}" data-titulo="${esc(h.titulo || h.modulo || "")}">
      <code>${esc(h.idReq || h.idCaso)}</code> ${esc(h.titulo || h.proyecto || "")}
    </button>`).join("") || `<p class="hint">Sin coincidencias.</p>`;
  }

  function asociarAval(btn) {
    $("#srAvalIdReq").value = btn.dataset.req || "";
    $("#srAvalIdCaso").value = btn.dataset.caso || "";
    const res = $("#srAvalResumen");
    if (res) res.textContent = `REQ ${btn.dataset.req || "—"} · ${btn.dataset.caso || ""} ${btn.dataset.titulo || ""}`.trim();
    if ($("#srAvalAplica")) $("#srAvalAplica").checked = true;
    toggleAval();
  }

  function bind() {
    document.querySelectorAll(".btn-sr-dictar").forEach((btn) => {
      if (window.QrysDictado && !QrysDictado.supported()) btn.disabled = true;
      btn.addEventListener("click", () => {
        const el = document.getElementById(btn.getAttribute("data-sr-dictar") || "");
        if (el && window.QrysDictado) QrysDictado.start(el);
      });
    });
    $("#btnSrGuardar")?.addEventListener("click", async () => {
      if (window.__qrysOcupado) return;
      setExportLoading(true, "Guardando la solicitud. No cambie de ventana hasta que termine.");
      try {
        const sol = await guardar();
        if (!sol) return;
        if (analisisYaLanzado(sol)) await guardarPdfImagen({ yaBloqueado: true });
      } catch (e) {
        setEstado(e.message || "Error al guardar.");
      } finally {
        setExportLoading(false);
      }
    });
    $("#btnSrChatGuardar")?.addEventListener("click", () => guardarPdfImagen().catch((e) => setEstado(e.message)));
    $("#btnSrElegirCarpeta")?.addEventListener("click", () =>
      elegirCarpetaDialogo().catch((e) => setCarpetaFeedback(e.message, true)),
    );
    $("#btnSrPcEscritorio")?.addEventListener("click", () =>
      elegirCarpetaEnNavegador("desktop").catch((e) => setCarpetaFeedback(e.message, true)),
    );
    $("#btnSrPcDocumentos")?.addEventListener("click", () =>
      elegirCarpetaEnNavegador("documents").catch((e) => setCarpetaFeedback(e.message, true)),
    );
    $("#btnSrPcDescargas")?.addEventListener("click", () =>
      elegirCarpetaEnNavegador("downloads").catch((e) => setCarpetaFeedback(e.message, true)),
    );
    $("#btnSrCarpetaPlat")?.addEventListener("click", async () => {
      const id = ($("#srId")?.value || actual?.id || "").trim();
      if (!id) return setCarpetaFeedback("Guarde la solicitud primero.", true);
      const rutas = rutasCarpetaSrv || (await cargarRutasCarpetaSugeridas(id));
      const p = rutas?.plataformaCaso;
      if (p) {
        carpetaDirHandle = null;
        syncCarpetaUI(p);
        setCarpetaFeedback(`Carpeta en el servidor: ${p}`);
      } else setCarpetaFeedback("No se pudo resolver la carpeta del caso.", true);
    });
    $("#srCarpetaVisible")?.addEventListener("change", () => syncCarpetaUI($("#srCarpetaVisible")?.value));
    $("#srCarpetaVisible")?.addEventListener("blur", () => syncCarpetaUI($("#srCarpetaVisible")?.value));
    $("#btnSrAnalizar")?.addEventListener("click", () => analizar().catch((e) => setEstado(e.message)));
    $("#btnSrDocumento")?.addEventListener("click", () => documento().catch((e) => setEstado(e.message)));
    $("#btnSrExportPlataforma")?.addEventListener("click", () =>
      guardarPdfImagen().catch((e) => setEstado(e.message)),
    );
    $("#btnSrVerDiagrama")?.addEventListener("click", () => verDiagrama().catch((e) => setEstado(e.message)));
    $("#btnSrVerMockup")?.addEventListener("click", () => verMockup().catch((e) => setEstado(e.message)));
    $("#btnSrEnviarChat")?.addEventListener("click", () => enviarChat().catch((e) => setEstado(e.message)));
    $("#btnSrChatDocumento")?.addEventListener("click", () => documento().catch((e) => setEstado(e.message)));
    $("#btnSrChatAbrirDoc")?.addEventListener("click", () => {
      const u = $("#btnSrChatAbrirDoc")?.dataset.url;
      if (u) window.open(u, "_blank");
    });
    $("#btnSrChatMockup")?.addEventListener("click", async () => {
      const id = ($("#srId")?.value || actual?.id || "").trim();
      if (!id) return setEstado("Guarde la solicitud primero.");
      setEstado("Generando mockup de la propuesta…");
      const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/mockups/generar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      await aplicarPanel(data);
      const first = (data.mockups || []).find((m) => m.url);
      if (first?.url) window.open(first.url, "_blank");
      setEstado("Mockup listo.");
    });
    $("#btnSrChatAbrirMockup")?.addEventListener("click", () => {
      const u = $("#btnSrChatAbrirMockup")?.dataset.url;
      if (u) window.open(u, "_blank");
    });
    $("#btnSrChatCerrar")?.addEventListener("click", () => cerrarActual().catch((e) => setEstado(e.message)));
    $("#btnSrChatDiagrama")?.addEventListener("click", async () => {
      const id = ($("#srId")?.value || actual?.id || "").trim();
      if (!id) return setEstado("Guarde la solicitud primero.");
      setEstado("Generando diagrama de flujo…");
      const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}/diagramas/generar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      await aplicarPanel(data);
      const url = data.diagrama?.url || data.diagramaGenerado?.url;
      if (url) window.open(url, "_blank");
      setEstado("Diagrama listo.");
    });
    $("#btnSrChatAbrirDiag")?.addEventListener("click", () => {
      const u = $("#btnSrChatAbrirDiag")?.dataset.url;
      if (u) window.open(u, "_blank");
    });
    const onFile = (e) => {
      const f = e.target.files && e.target.files[0];
      e.target.value = "";
      if (f) subirArchivoSr(f).catch((err) => setEstado(err.message));
    };
    $("#srInputArchivo")?.addEventListener("change", onFile);
    $("#srChatInputArchivo")?.addEventListener("change", onFile);
    $("#btnSrChatSubirArchivo")?.addEventListener("click", () => $("#srChatInputArchivo")?.click());

    // Gestor dinámico de criterios
    $("#btnSrAddCriterio")?.addEventListener("click", agregarNuevoCriterio);
    $("#srNuevoCriterioInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        agregarNuevoCriterio();
      }
    });

    // Filtro dinámico en tiempo real
    $("#srFiltroTexto")?.addEventListener("input", () => refreshLista());
    $("#btnLimpiarFiltroSr")?.addEventListener("click", () => {
      const inp = $("#srFiltroTexto");
      if (inp) inp.value = "";
      refreshLista();
    });

    // Proceso auto-rellena módulo
    $("#srProcesoId")?.addEventListener("change", () => {
      const selId = $("#srProcesoId")?.value;
      const proc = listaProcesosCache.find((p) => p.id === selId);
      if (proc && proc.modulo) {
        const modInput = $("#srModulo");
        if (modInput && (!modInput.value || modInput.value === "CONF" || !modInput.value.trim())) {
          modInput.value = proc.modulo;
        }
      }
    });

    // Aval toggle reactivo
    $("#srAvalAplica")?.addEventListener("change", toggleAval);

    // Dropzone interactivo
    const dropzone = $("#srDropzoneArchivos");
    if (dropzone) {
      dropzone.addEventListener("click", () => $("#srInputArchivo")?.click());
      dropzone.addEventListener("dragover", (e) => {
        e.preventDefault();
        dropzone.classList.add("dragover");
      });
      dropzone.addEventListener("dragleave", () => {
        dropzone.classList.remove("dragover");
      });
      dropzone.addEventListener("drop", (e) => {
        e.preventDefault();
        dropzone.classList.remove("dragover");
        const file = e.dataTransfer?.files?.[0];
        if (file) subirArchivoSr(file).catch((err) => setEstado(err.message));
      });
    }

    $("#btnSrNueva")?.addEventListener("click", () => {
      limpiarFormulario();
      showPanel("form");
      setEstado("Nueva necesidad. Escríbala y pulse Analizar.");
    });
    $("#btnSrVolverLista")?.addEventListener("click", () => showPanel("lista"));
    $("#btnSrChatALista")?.addEventListener("click", () => showPanel("lista"));
    $("#btnSrCerrar")?.addEventListener("click", () => cerrarActual().catch((e) => setEstado(e.message)));
    document.querySelectorAll("[data-sr-filtro]").forEach((btn) => {
      btn.addEventListener("click", () => {
        filtroLista = btn.getAttribute("data-sr-filtro") || "abiertas";
        document.querySelectorAll("[data-sr-filtro]").forEach((b) => {
          const on = b === btn;
          b.classList.toggle("is-active", on);
          b.classList.toggle("is-on", on);
        });
        refreshLista();
      });
    });
    $("#srListaBody")?.addEventListener("click", (e) => {
      const btn = e.target.closest?.("[data-sr-abrir]");
      if (btn) abrir(btn.getAttribute("data-sr-abrir")).catch((err) => setEstado(err.message));
    });
    document.querySelectorAll("[data-sr-panel]").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (btn.disabled) return;
        showPanel(btn.dataset.srPanel);
      });
    });
  }

  function enter() {
    cargarProcesos();
    refreshLista();
    showPanel("lista");
  }

  function init() {
    bind();
  }

  return { init, enter, stopPoll, refresh: refreshLista };
})();
