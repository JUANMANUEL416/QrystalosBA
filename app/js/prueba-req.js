/**
 * Prueba req — formulario, chat de ajustes y documento al cerrar.
 */
window.QrysPruebaReq = (function () {
  const $ = (id) => document.getElementById(id);
  let pruebaId = null;
  let bound = false;
  let pollTimer = null;
  let servidores = [];

  const PANELS = {
    historial: "prPanelHistorial",
    nueva: "prPanelNueva",
    prueba: "prPanelPrueba",
  };

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function aviso(texto, esError) {
    const el = $("prAviso");
    if (!el) return;
    if (!texto) {
      el.hidden = true;
      el.textContent = "";
      return;
    }
    el.hidden = false;
    el.textContent = texto;
    el.className = esError ? "alert alert-warning" : "alert alert-info";
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || data.mensaje || r.statusText || String(r.status));
    return data;
  }

  function showPanel(nombre) {
    Object.entries(PANELS).forEach(([key, id]) => {
      const el = $(id);
      if (!el) return;
      el.classList.toggle("hidden", key !== nombre);
    });
    document.querySelectorAll("[data-pr-panel]").forEach((btn) => {
      btn.classList.toggle("is-on", btn.getAttribute("data-pr-panel") === nombre);
    });
  }

  function baseElegida() {
    const otra = ($("prBaseOtra")?.value || "").trim();
    if (otra) return otra;
    return ($("prBase")?.value || "").trim();
  }

  async function cargarServidores() {
    const sel = $("prServidor");
    if (!sel || sel.options.length) return;
    const data = await fetchJson("/api/informe-contab/servidores");
    servidores = data.servidores || [];
    sel.innerHTML = "";
    servidores.forEach((s) => {
      const opt = document.createElement("option");
      opt.value = s.id || "";
      opt.textContent = s.nombre || s.id;
      sel.appendChild(opt);
    });
    const pcem = servidores.find((s) =>
      String(s.baseDatosDefault || "").toUpperCase() === "PCEM" ||
      (s.bases || []).some((b) => String(b).toUpperCase() === "PCEM")
    );
    if (pcem) sel.value = pcem.id;
    sel.onchange = () => cargarBases(sel.value);
    if (sel.value) await cargarBases(sel.value);
  }

  async function cargarBases(servidorId) {
    const sel = $("prBase");
    if (!sel) return;
    const srv = servidores.find((s) => s.id === servidorId) || {};
    const previas = srv.bases && srv.bases.length ? srv.bases : (srv.baseDatosDefault ? [srv.baseDatosDefault] : []);
    const pintar = (bases, preferida) => {
      sel.innerHTML = "";
      bases.forEach((b) => {
        const opt = document.createElement("option");
        opt.value = b;
        opt.textContent = b;
        sel.appendChild(opt);
      });
      if (preferida && [...sel.options].some((o) => o.value === preferida)) sel.value = preferida;
    };
    pintar(previas, srv.baseDatosDefault || "PCEM");
    try {
      const data = await fetchJson(`/api/informe-contab/bases?servidorId=${encodeURIComponent(servidorId)}`);
      const bases = data.bases || [];
      if (bases.length) pintar(bases, srv.baseDatosDefault || "PCEM");
    } catch (_) {
      /* el catálogo del servidor alcanza para elegir */
    }
  }

  function etiquetaEstado(fila) {
    if (fila.estado === "cerrada") {
      return fila.veredicto === "aprobado" ? "Entrega" : fila.veredicto === "rechazado" ? "Devolución" : "Cerrada";
    }
    if (fila.veredicto === "aprobado") return "Sugiere entrega";
    if (fila.veredicto === "rechazado") return "Sugiere devolución";
    return "Abierta";
  }

  async function cargarLista() {
    const body = $("prListaBody");
    if (!body) return;
    const data = await fetchJson("/api/prueba-req/pruebas");
    const filas = data.pruebas || [];
    if (!filas.length) {
      body.innerHTML = `<tr><td colspan="5">No hay pruebas. Registre la primera.</td></tr>`;
      return;
    }
    body.innerHTML = filas
      .map(
        (f) => `<tr>
          <td>${esc(f.id)}</td>
          <td>${esc(f.titulo || "")}</td>
          <td>${esc(f.baseDatos || "")}</td>
          <td>${esc(etiquetaEstado(f))}</td>
          <td style="text-align:right"><button type="button" class="btn btn-secondary btn-sm" data-pr-abrir="${esc(f.id)}">Abrir</button></td>
        </tr>`
      )
      .join("");
  }

  function pintarChat(mensajes) {
    const box = $("prChat");
    if (!box) return;
    const nombres = { coordinador: "Coordinador", agente: "Agente", sistema: "Sistema" };
    box.innerHTML = (mensajes || [])
      .map((m) => {
        const quien = nombres[m.autor] || m.autor || "";
        const lado = m.autor === "coordinador" ? "scw-msg-out" : "scw-msg-in";
        return `<article class="scw-msg ${lado}"><header><strong>${esc(quien)}</strong></header><div class="scw-msg-body">${esc(m.texto).replace(/\n/g, "<br>")}</div></article>`;
      })
      .join("");
    box.scrollTop = box.scrollHeight;
  }

  function pintar(panel) {
    const meta = panel.meta || {};
    const cerrada = meta.estado === "cerrada";
    if ($("prTitulo")) $("prTitulo").textContent = meta.titulo || meta.id || "Prueba";
    if ($("prMeta")) {
      $("prMeta").textContent = `${meta.servidorNombre || meta.servidorId || "—"} · ${meta.baseDatos || "—"}`;
    }
    if ($("prSello")) $("prSello").textContent = etiquetaEstado(meta);
    if ($("prContextLine")) $("prContextLine").textContent = (meta.requerimiento || "").slice(0, 140);
    if ($("prTxtReq")) $("prTxtReq").textContent = meta.requerimiento || "";
    if ($("prTxtJust")) $("prTxtJust").textContent = meta.justificacion || "";
    if ($("prTxtDev")) $("prTxtDev").textContent = meta.respuestaDesarrollador || "";
    ["prBtnProbar", "prBtnEntrega", "prBtnDevolver", "prBtnNota", "prBtnAjuste", "prChatInput"].forEach((id) => {
      const el = $(id);
      if (el) el.disabled = cerrada;
    });
    const ver = $("prBtnVer");
    if (ver) ver.disabled = !meta.documentoGenerado;
    const estado = $("prEstado");
    const bot = panel.bot || {};
    const trabajando = bot.estado === "trabajando";
    if (estado) estado.classList.toggle("hidden", !trabajando);
    if ($("prEstadoLabel")) $("prEstadoLabel").textContent = trabajando ? "Probando" : "Agente";
    if ($("prEstadoDetail")) {
      $("prEstadoDetail").textContent = trabajando
        ? "Contrasta la base, el fuente, IXONLINE/SQL y la base de pruebas."
        : "";
    }
    pintarChat(panel.mensajes);
  }

  async function abrir(id) {
    pruebaId = id;
    const tab = $("prTabPrueba");
    if (tab) tab.disabled = false;
    showPanel("prueba");
    aviso("");
    const data = await fetchJson(`/api/prueba-req/${encodeURIComponent(id)}/panel`);
    pintar(data);
    startPoll();
  }

  function stopPoll() {
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
  }

  function startPoll() {
    stopPoll();
    if (!pruebaId) return;
    pollTimer = setInterval(() => {
      fetchJson(`/api/prueba-req/${encodeURIComponent(pruebaId)}/panel`)
        .then(pintar)
        .catch(() => {});
    }, 3500);
  }

  async function crear() {
    aviso("");
    const servidorId = ($("prServidor")?.value || "").trim();
    const srv = servidores.find((s) => s.id === servidorId) || {};
    const data = await fetchJson("/api/prueba-req/prueba", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        requerimiento: $("prRequerimiento")?.value || "",
        justificacion: $("prJustificacion")?.value || "",
        respuestaDesarrollador: $("prRespuesta")?.value || "",
        desarrollador: $("prDesarrollador")?.value || "",
        servidorId,
        servidorNombre: srv.nombre || "",
        baseDatos: baseElegida(),
      }),
    });
    ["prRequerimiento", "prJustificacion", "prRespuesta", "prDesarrollador", "prBaseOtra"].forEach((id) => {
      const el = $(id);
      if (el) el.value = "";
    });
    await cargarLista();
    await abrir(data.meta.id);
  }

  async function postAccion(accion, body) {
    if (!pruebaId) return;
    aviso("");
    const data = await fetchJson(`/api/prueba-req/${encodeURIComponent(pruebaId)}/${accion}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body || {}),
    });
    if (data.meta || data.mensajes) pintar(data);
    return data;
  }

  async function cerrar(veredicto) {
    const data = await postAccion("cerrar", { veredicto });
    await cargarLista();
    if (data.urlHtml) window.open(data.urlHtml, "_blank", "noopener");
    aviso(veredicto === "aprobado" ? "Documento de entrega listo." : "Documento de devolución listo.");
  }

  function bindOnce() {
    if (bound) return;
    bound = true;
    document.querySelectorAll("[data-pr-panel]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const nombre = btn.getAttribute("data-pr-panel");
        if (nombre === "prueba" && !pruebaId) return;
        if (nombre !== "prueba") stopPoll();
        showPanel(nombre);
        if (nombre === "nueva") cargarServidores().catch((e) => aviso(e.message, true));
        if (nombre === "historial") cargarLista().catch((e) => aviso(e.message, true));
      });
    });
    $("prBtnIrNueva")?.addEventListener("click", () => {
      showPanel("nueva");
      cargarServidores().catch((e) => aviso(e.message, true));
    });
    $("prBtnNuevaCancelar")?.addEventListener("click", () => showPanel("historial"));
    $("prBtnCrear")?.addEventListener("click", () => crear().catch((e) => aviso(e.message, true)));
    $("prListaBody")?.addEventListener("click", (ev) => {
      const btn = ev.target.closest("[data-pr-abrir]");
      if (!btn) return;
      abrir(btn.getAttribute("data-pr-abrir")).catch((e) => aviso(e.message, true));
    });
    $("prBtnVolver")?.addEventListener("click", () => {
      stopPoll();
      showPanel("historial");
      cargarLista().catch(() => {});
    });
    $("prBtnProbar")?.addEventListener("click", () =>
      postAccion("probar", {}).catch((e) => aviso(e.message, true))
    );
    $("prBtnNota")?.addEventListener("click", () => {
      const texto = ($("prChatInput")?.value || "").trim();
      postAccion("chat", { autor: "coordinador", texto })
        .then(() => {
          if ($("prChatInput")) $("prChatInput").value = "";
        })
        .catch((e) => aviso(e.message, true));
    });
    $("prBtnAjuste")?.addEventListener("click", () => {
      const texto = ($("prChatInput")?.value || "").trim();
      postAccion("ajustar", { texto })
        .then(() => {
          if ($("prChatInput")) $("prChatInput").value = "";
        })
        .catch((e) => aviso(e.message, true));
    });
    $("prChatInput")?.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" && !ev.shiftKey) {
        ev.preventDefault();
        $("prBtnAjuste")?.click();
      }
    });
    $("prBtnEntrega")?.addEventListener("click", () => cerrar("aprobado").catch((e) => aviso(e.message, true)));
    $("prBtnDevolver")?.addEventListener("click", () => cerrar("rechazado").catch((e) => aviso(e.message, true)));
    $("prBtnVer")?.addEventListener("click", () => {
      if (pruebaId) window.open(`/api/prueba-req/${encodeURIComponent(pruebaId)}/html`, "_blank", "noopener");
    });
  }

  function enter() {
    bindOnce();
    const tab = $("prTabPrueba");
    if (tab) tab.disabled = !pruebaId;
    showPanel(pruebaId ? "prueba" : "historial");
    cargarLista().catch((e) => aviso(e.message, true));
    if (pruebaId) {
      fetchJson(`/api/prueba-req/${encodeURIComponent(pruebaId)}/panel`).then(pintar).catch(() => {});
      startPoll();
    }
  }

  return { enter, stopPoll };
})();
