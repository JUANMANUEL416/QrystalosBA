/**
 * Menú central — Analista / Consultas / Documentar (base de procesos).
 */
window.QrysConocimiento = (function () {
  const MODE_KEY = "qrystalos_ba_modo";
  let cache = null;
  let procesoActual = null;
  let chatPoll = null;

  const $ = (s) => document.querySelector(s);
  const $$ = (s) => document.querySelectorAll(s);

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function modoGuardado() {
    return sessionStorage.getItem(MODE_KEY) || "hub";
  }

  function guardarModo(m) {
    sessionStorage.setItem(MODE_KEY, m);
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || data.mensaje || r.statusText || String(r.status));
    return data;
  }

  async function loadFromDisk() {
    const indice = await fetchJson("/conocimiento/INDICE.json");
    const pendientes = await fetchJson("/conocimiento/pendientes.json");
    let chat = { mensajes: [] };
    let tarea = { abierta: false };
    try {
      chat = await fetchJson("/conocimiento/chat.json");
    } catch (_) {}
    try {
      tarea = await fetchJson("/conocimiento/tarea.json");
    } catch (_) {}
    const items = pendientes.items || [];
    return {
      ok: true,
      indice,
      pendientes,
      pendientesAbiertos: items.filter((i) => i.estado !== "completado").length,
      tarea,
      chat,
      sqlArchivos: [],
      desdeDisco: true,
    };
  }

  async function loadResumen() {
    try {
      cache = await fetchJson("/api/conocimiento");
      return cache;
    } catch (_) {
      cache = await loadFromDisk();
      return cache;
    }
  }

  function badgePendientes(n) {
    const el = $("#hubBadgePendientes");
    if (!el) return;
    el.textContent = n ? String(n) : "";
    el.hidden = !n;
    const nav = $("#docBadgePendientes");
    if (nav) {
      nav.textContent = n ? String(n) : "";
      nav.hidden = !n;
    }
  }

  function showHub() {
    stopChatPoll();
    try {
      guardarModo("hub");
    } catch (_) {}
    const hub = $("#hubScreen");
    const shell = $("#appShell");
    if (hub) {
      hub.hidden = false;
      hub.removeAttribute("hidden");
    }
    if (shell) {
      shell.hidden = true;
      shell.setAttribute("hidden", "");
    }
    const inicio = $("#btnInicioHub");
    if (inicio) inicio.hidden = true;
    loadResumen()
      .then((d) => badgePendientes(d.pendientesAbiertos || 0))
      .catch(() => {});
  }

  function enterMode(mode) {
    try {
      guardarModo(mode);
    } catch (_) {
      /* sessionStorage bloqueado: igual se entra */
    }
    const hub = $("#hubScreen");
    const shell = $("#appShell");
    if (hub) {
      hub.hidden = true;
      hub.setAttribute("hidden", "");
    }
    if (shell) {
      shell.hidden = false;
      shell.removeAttribute("hidden");
      shell.classList.remove("modo-analista", "modo-consultas", "modo-documentar");
      shell.classList.add(`modo-${mode}`);
    }
    const inicio = $("#btnInicioHub");
    if (inicio) inicio.hidden = false;

    $$(".view").forEach((v) => v.classList.remove("active"));
    $$(".main-tab").forEach((t) => t.classList.remove("active"));

    if (mode === "analista") {
      const colaTab = document.querySelector('.main-tab[data-view="cola"]');
      if (colaTab) colaTab.classList.add("active");
      const cola = $("#view-cola");
      if (cola) cola.classList.add("active");
    } else if (mode === "consultas") {
      const v = $("#view-consultas");
      if (v) v.classList.add("active");
      refreshConsultas();
      startChatPoll();
    } else if (mode === "documentar") {
      const v = $("#view-documentar");
      if (v) v.classList.add("active");
      refreshDocumentar();
      startChatPoll();
    }
  }

  async function refreshConsultas() {
    const list = $("#consultaProcesos");
    const det = $("#consultaDetalle");
    if (!list) return;
    try {
      await loadResumen();
    } catch (e) {
      list.innerHTML = `<p class="alert alert-warning">No se pudo leer la base. Use abrir-app.bat. ${esc(e.message)}</p>`;
      return;
    }
    const q = ($("#consultaBuscar")?.value || "").trim().toLowerCase();
    const procesos = cache.indice?.procesos || [];
    const filtrados = procesos.filter((p) => {
      if (!q) return true;
      return `${p.nombre} ${p.modulo} ${p.resumen}`.toLowerCase().includes(q);
    });
    if (!filtrados.length) {
      list.innerHTML = `<p class="hint">No hay procesos que coincidan. En Documentar puede crear uno nuevo.</p>`;
      return;
    }
    list.innerHTML = filtrados
      .map(
        (p) => `
      <button type="button" class="kb-proc-card" data-id="${esc(p.id)}">
        <strong>${esc(p.nombre)}</strong>
        <span class="kb-meta">${esc(p.modulo || "—")} · ${esc(p.estado || "")}</span>
        <span>${esc(p.resumen || "")}</span>
      </button>`,
      )
      .join("");
    list.querySelectorAll(".kb-proc-card").forEach((btn) => {
      btn.addEventListener("click", () => abrirProcesoConsulta(btn.dataset.id));
    });
    renderChatBoxes();
    if (det && !procesoActual) {
      det.innerHTML = `<p class="hint">Elija un proceso a la izquierda. Flujo (capa → gate) o Procedimientos (SP → método). Abajo puede preguntar al agente.</p>`;
    }
  }

  function pillEstado(estado) {
    const map = {
      pendiente: "pill-pending",
      no_leido: "pill-pending",
      listado: "pill-progress",
      parcial: "pill-progress",
      esqueleto: "pill-progress",
      en_progreso: "pill-progress",
      leido: "pill-done",
      listo: "pill-done",
      completado: "pill-done",
    };
    return `<span class="pill ${map[estado] || "pill-pending"}">${esc(estado || "—")}</span>`;
  }

  async function abrirProcesoConsulta(id, tab) {
    const det = $("#consultaDetalle");
    if (!det) return;
    try {
      try {
        const data = await fetchJson(`/api/conocimiento/proceso/${encodeURIComponent(id)}`);
        procesoActual = data.proceso;
      } catch (_) {
        procesoActual = await fetchJson(`/conocimiento/${encodeURIComponent(id)}/proceso.json`);
        if (!procesoActual.sps) {
          try {
            const cat = await fetchJson(`/conocimiento/${encodeURIComponent(id)}/sps.json`);
            procesoActual.sps = cat.sps || [];
            procesoActual.spsNota = cat.nota || "";
          } catch (_) {
            procesoActual.sps = [];
          }
        }
      }
    } catch (e) {
      det.innerHTML = `<p class="alert alert-warning">${esc(e.message)}</p>`;
      return;
    }
    if (!procesoActual) {
      det.innerHTML = `<p class="alert alert-warning">Proceso no encontrado.</p>`;
      return;
    }
    const p = procesoActual;
    const vista = tab || "flujo";
    det.innerHTML = `
      <h2>${esc(p.nombre)}</h2>
      <p class="hint">${esc(p.modulo || "")} · ${pillEstado(p.estado)}</p>
      <p>${esc(p.resumen || "")}</p>
      ${p.notaSql ? `<div class="alert alert-info">${esc(p.notaSql)}</div>` : ""}
      <div class="kb-tabs" role="tablist">
        <button type="button" class="kb-tab${vista === "flujo" ? " is-on" : ""}" data-kb-tab="flujo">Flujo</button>
        <button type="button" class="kb-tab${vista === "sps" ? " is-on" : ""}" data-kb-tab="sps">Procedimientos</button>
      </div>
      <div id="consultaCuerpo">${vista === "sps" ? renderSps(p) : renderFlujo(p)}</div>`;
    det.querySelectorAll("[data-kb-tab]").forEach((btn) => {
      btn.addEventListener("click", () => abrirProcesoConsulta(id, btn.dataset.kbTab));
    });
  }

  function renderFlujo(p) {
    const capas = (p.capas || [])
      .map((c) => {
        const gates = (c.gates || [])
          .map((g) => {
            const sps = (g.sps || [])
              .map((s) => `<li><code>${esc(s.nombre)}</code> ${esc(s.metodo || "")} — ${esc(s.rol || "")}</li>`)
              .join("");
            return `
            <article class="kb-gate">
              <h4>${esc(g.nombre)}</h4>
              <p>${esc(g.explicacion || "")}</p>
              ${g.invariante ? `<div class="kb-invariante"><strong>Invariante:</strong> ${esc(g.invariante)}</div>` : ""}
              ${sps ? `<p class="hint compact">SP de este gate (ficha completa en Procedimientos)</p><ul>${sps}</ul>` : `<p class="hint compact">SP de este gate: pendiente.</p>`}
            </article>`;
          })
          .join("");
        const tablas = (c.tablasClave || []).map((t) => `<code>${esc(t)}</code>`).join(" ");
        return `
        <section class="kb-capa">
          <header>
            <h3>${c.numero}. ${esc(c.nombre)} ${pillEstado(c.estado)}</h3>
          </header>
          <p>${esc(c.explicacion || "")}</p>
          ${tablas ? `<p class="hint compact">Tablas de apoyo (docs vivas): ${tablas}</p>` : ""}
          ${gates || `<p class="hint">Gates aún no documentados.</p>`}
        </section>`;
      })
      .join("");
    return capas || `<p class="hint">Capas aún no documentadas.</p>`;
  }

  function listaHtml(arr) {
    if (!arr || !arr.length) return "";
    return `<ul>${arr.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>`;
  }

  function renderMetodo(m) {
    const st = m.estado || "no_leido";
    const errores = listaHtml(m.errores);
    const valida = listaHtml(m.valida);
    const noValida = listaHtml(m.noValida);
    const llama = (m.llama || []).map((x) => `<code>${esc(x)}</code>`).join(" ");
    return `
      <article class="kb-metodo kb-metodo--${esc(st)}">
        <h5><code>${esc(m.id)}</code> ${pillEstado(st)}</h5>
        ${m.hace ? `<p>${esc(m.hace)}</p>` : `<p class="hint compact">Aún no leído. Bajar el .sql a sql/ y pasarlo en Documentar.</p>`}
        ${valida ? `<p class="hint compact"><strong>Valida</strong></p>${valida}` : ""}
        ${noValida ? `<div class="kb-hueco"><strong>No valida (hueco)</strong>${noValida}</div>` : ""}
        ${errores ? `<p class="hint compact"><strong>Errores posibles (KO)</strong></p>${errores}` : ""}
        ${llama ? `<p class="hint compact"><strong>Llama:</strong> ${llama}</p>` : ""}
        ${m.efecto ? `<p class="kb-efecto"><strong>Efecto:</strong> ${esc(m.efecto)}</p>` : ""}
      </article>`;
  }

  function renderSps(p) {
    const sps = p.sps || [];
    if (!sps.length) {
      return `<p class="hint">Aún no hay catálogo de SP. En Documentar, baje el .sql de hoy: el agente llena SP → método (hace, valida, errores).</p>`;
    }
    const nota = p.spsNota ? `<p class="hint">${esc(p.spsNota)}</p>` : "";
    const bloques = sps
      .map((sp) => {
        const metodos = (sp.metodos || []).map(renderMetodo).join("");
        return `
        <section class="kb-sp">
          <header>
            <h3><code>${esc(sp.nombre)}</code> ${pillEstado(sp.estado)}</h3>
            <p class="hint compact">${esc(sp.tipo || "")}${sp.modelo ? " · MODELO " + esc(sp.modelo) : ""}${sp.fuente ? " · " + esc(sp.fuente) : ""}</p>
            ${sp.cola ? `<p class="hint compact">Cola: ${esc(sp.cola)}</p>` : ""}
          </header>
          ${metodos || `<p class="hint">Métodos pendientes de lectura.</p>`}
        </section>`;
      })
      .join("");
    return `${nota}${bloques}`;
  }

  function renderPendientes() {
    const box = $("#docPendientesLista");
    if (!box || !cache) return;
    const items = (cache.pendientes?.items || []).filter((i) => i.estado !== "completado");
    badgePendientes(items.length);
    if (!items.length) {
      box.innerHTML = `<p class="hint">No hay pendientes. Cuando un REQ abra un proceso o falten SP, aparecerán aquí.</p>`;
      return;
    }
    box.innerHTML = items
      .map((i) => {
        const sel = i.estado === "en_progreso" ? " kb-pendiente--on" : "";
        return `
        <label class="kb-pendiente${sel}">
          <input type="radio" name="docPendiente" value="${esc(i.id)}">
          <div>
            <strong>${esc(i.titulo)}</strong>
            ${pillEstado(i.estado)}
            <span class="kb-tipo">${esc(i.tipo)}</span>
            <p>${esc(i.detalle || "")}</p>
            ${i.spNombre ? `<p class="hint compact">SP sugerido: <code>${esc(i.spNombre)}</code></p>` : ""}
          </div>
        </label>`;
      })
      .join("");
  }

  function fillSqlSelect() {
    const sel = $("#docSqlSelect");
    if (!sel) return;
    const files = cache?.sqlArchivos || [];
    const actual = sel.value;
    sel.innerHTML =
      `<option value="">— .sql en sql/ (el de hoy) —</option>` +
      files.map((f) => `<option value="${esc(f)}">${esc(f)}</option>`).join("");
    if (actual && files.includes(actual)) sel.value = actual;
  }

  function fillProcesoSelect() {
    const sel = $("#docProcesoId");
    if (!sel) return;
    const procesos = cache?.indice?.procesos || [];
    const actual = sel.value || cache?.tarea?.procesoId || "";
    sel.innerHTML =
      `<option value="">Proceso (se infiere si el SP ya está en el catálogo)…</option>` +
      procesos.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}${p.modulo ? " · " + esc(p.modulo) : ""}</option>`).join("");
    if (actual) sel.value = actual;
  }

  function renderChatBoxes(forceBottom) {
    renderChatIn("#docChatMensajes", forceBottom);
    renderChatIn("#consultaChatMensajes", forceBottom);
    renderBotHint();
  }

  function botHintText() {
    const bot = cache?.bot || {};
    if (bot.estado === "trabajando") {
      return "El agente está trabajando. En unos segundos aparece la respuesta aquí.";
    }
    if (bot.estado === "error" || bot.estado === "sin_clave") {
      return bot.error
        ? "El agente no pudo responder: " + bot.error
        : "El agente no pudo responder este turno. Vuelva a enviar o reinicie abrir-app.bat.";
    }
    return "";
  }

  function renderBotHint() {
    const text = botHintText();
    ["#consultaChatBotHint", "#docChatBotHint"].forEach((sel) => {
      const el = $(sel);
      if (!el) return;
      el.hidden = !text;
      el.textContent = text;
    });
  }

  const NEAR_BOTTOM_PX = 96;

  function chatSig(msgs) {
    if (!msgs?.length) return "empty";
    return msgs.map((m) => `${m.id || ""}|${m.autor}|${m.en || ""}|${String(m.texto || "").length}`).join(";");
  }

  function paintChat(box, html, signature, forceBottom) {
    const prev = box.dataset.chatSig || "";
    if (prev === signature && !forceBottom) return;
    const keep = !forceBottom && prev && box.scrollHeight - box.scrollTop - box.clientHeight >= NEAR_BOTTOM_PX;
    const saved = box.scrollTop;
    box.innerHTML = html;
    box.dataset.chatSig = signature;
    requestAnimationFrame(() => {
      box.scrollTop = keep ? saved : box.scrollHeight;
    });
  }

  function renderChatIn(sel, forceBottom) {
    const box = $(sel);
    if (!box || !cache) return;
    const msgs = cache.chat?.mensajes || [];
    if (!msgs.length) {
      paintChat(
        box,
        `<p class="hint">Escriba aquí. El agente responde en este Chat (autor agente), igual que en el caso.</p>`,
        "empty",
        !!forceBottom,
      );
      return;
    }
    const html = msgs
      .map((m) => {
        const who = m.autor === "agente" ? "Agente" : m.autor === "sistema" ? "Sistema" : "Usted";
        const cls =
          m.autor === "agente"
            ? "chat-msg chat-msg-agente"
            : m.autor === "sistema"
              ? "chat-msg chat-msg-sistema"
              : "chat-msg chat-msg-coord";
        return `<div class="${cls}"><div class="chat-msg-head"><strong>${esc(who)}</strong> · ${esc(m.en || "")}</div><div>${esc(m.texto).replace(/\n/g, "<br>")}</div></div>`;
      })
      .join("");
    paintChat(box, html, chatSig(msgs), !!forceBottom);
  }

  function renderTarea() {
    const el = $("#docTareaActiva");
    if (!el || !cache) return;
    const t = cache.tarea;
    if (t?.abierta) {
      el.hidden = false;
      el.innerHTML = `<strong>Tarea abierta:</strong> ${esc(t.tipo)} · <code>${esc(t.archivoSql || "")}</code> · proceso ${esc(t.procesoId || "—")}.
        Puede indicar <em>otro</em> .sql y pulsar Documentar SP para sustituirla, o <em>Cerrar tarea abierta</em>.`;
    } else {
      el.hidden = true;
      el.innerHTML = "";
    }
  }

  async function refreshDocumentar() {
    try {
      await loadResumen();
    } catch (e) {
      const box = $("#docPendientesLista");
      if (box) box.innerHTML = `<p class="alert alert-warning">${esc(e.message)}</p>`;
      return;
    }
    renderPendientes();
    fillSqlSelect();
    fillProcesoSelect();
    renderChatBoxes();
    renderTarea();
  }

  function startChatPoll() {
    stopChatPoll();
    chatPoll = setInterval(() => {
      if ($("#view-documentar")?.classList.contains("active")) refreshDocumentar();
      else if ($("#view-consultas")?.classList.contains("active")) {
        loadResumen()
          .then(() => renderChatBoxes())
          .catch(() => {});
      }
    }, 5000);
  }

  function stopChatPoll() {
    if (chatPoll) {
      clearInterval(chatPoll);
      chatPoll = null;
    }
  }

  function pendienteSeleccionado() {
    return document.querySelector('input[name="docPendiente"]:checked')?.value || "";
  }

  async function onDocumentarSp() {
    const pendienteId = pendienteSeleccionado();
    const manual = $("#docSqlManual")?.value?.trim() || "";
    const archivo = manual || $("#docSqlSelect")?.value || "";
    const notas = $("#docNotas")?.value?.trim() || "";
    const procesoId = $("#docProcesoId")?.value || "";
    const err = $("#docError");
    if (err) err.hidden = true;
    if (!archivo) {
      if (err) {
        err.hidden = false;
        err.textContent = "Indique el .sql vigente (lista sql/ o el nombre del archivo). No es obligatorio marcar un pendiente.";
      }
      return;
    }
    try {
      await fetchJson("/api/conocimiento/documentar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pendienteId, archivoSql: archivo, notas, procesoId }),
      });
      if ($("#docNotas")) $("#docNotas").value = "";
      if ($("#docSqlManual")) $("#docSqlManual").value = "";
      await refreshDocumentar();
    } catch (e) {
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      }
    }
  }

  async function onCerrarTarea() {
    const err = $("#docError");
    if (err) err.hidden = true;
    try {
      await fetchJson("/api/conocimiento/tarea", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ accion: "cerrar" }),
      });
      await refreshDocumentar();
    } catch (e) {
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      }
    }
  }

  async function onMarcarHecho() {
    const id = pendienteSeleccionado();
    const err = $("#docError");
    if (!id) {
      if (err) {
        err.hidden = false;
        err.textContent = "Seleccione un pendiente.";
      }
      return;
    }
    try {
      await fetchJson("/api/conocimiento/pendiente", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id, estado: "completado" }),
      });
      await refreshDocumentar();
    } catch (e) {
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      }
    }
  }

  async function onNuevoProceso() {
    const nombre = $("#docNuevoNombre")?.value?.trim();
    const modulo = $("#docNuevoModulo")?.value?.trim();
    const err = $("#docError");
    if (!nombre) {
      if (err) {
        err.hidden = false;
        err.textContent = "Indique el nombre del proceso (ej. Facturación).";
      }
      return;
    }
    try {
      await fetchJson("/api/conocimiento/proceso", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre, modulo }),
      });
      if ($("#docNuevoNombre")) $("#docNuevoNombre").value = "";
      if ($("#docNuevoModulo")) $("#docNuevoModulo").value = "";
      await refreshDocumentar();
    } catch (e) {
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      }
    }
  }

  async function onEnviarChat(fromSel) {
    const input = $(fromSel || "#docChatInput") || $("#consultaChatInput");
    const texto = input?.value?.trim();
    if (!texto) return;
    try {
      await fetchJson("/api/conocimiento/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          autor: "coordinador",
          texto,
          procesoId: procesoActual?.id || cache?.chat?.procesoId || "",
        }),
      });
      if (input) input.value = "";
      await loadResumen();
      renderChatBoxes(true);
    } catch (e) {
      const err = $("#docError");
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      } else {
        alert(e.message);
      }
    }
  }

  function bind() {
    $("#consultaBuscar")?.addEventListener("input", () => refreshConsultas());
    $("#btnDocRefrescar")?.addEventListener("click", () => refreshDocumentar());
    $("#btnDocDocumentarSp")?.addEventListener("click", () => onDocumentarSp());
    $("#btnDocCerrarTarea")?.addEventListener("click", () => onCerrarTarea());
    $("#btnDocMarcarHecho")?.addEventListener("click", () => onMarcarHecho());
    $("#btnDocNuevoProceso")?.addEventListener("click", () => onNuevoProceso());
    $("#btnDocEnviarChat")?.addEventListener("click", () => onEnviarChat("#docChatInput"));
    $("#btnConsultaEnviarChat")?.addEventListener("click", () => onEnviarChat("#consultaChatInput"));
    $("#docChatInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.altKey) {
        e.preventDefault();
        onEnviarChat("#docChatInput");
      }
    });
    $("#consultaChatInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.altKey) {
        e.preventDefault();
        onEnviarChat("#consultaChatInput");
      }
    });
  }

  document.addEventListener("click", (e) => {
    const el = e.target && e.target.closest ? e.target : (e.target && e.target.parentElement);
    if (!el || !el.closest) return;
    const hubBtn = el.closest("[data-hub-mode]");
    if (hubBtn) {
      e.preventDefault();
      enterMode(hubBtn.getAttribute("data-hub-mode"));
      return;
    }
    if (el.closest("#btnInicioHub")) {
      e.preventDefault();
      showHub();
    }
  });

  function init() {
    bind();
    let mode = "hub";
    try {
      mode = modoGuardado();
    } catch (_) {
      mode = "hub";
    }
    if (mode === "analista" || mode === "consultas" || mode === "documentar") {
      enterMode(mode);
    } else {
      showHub();
    }
    loadResumen()
      .then((d) => badgePendientes(d.pendientesAbiertos || 0))
      .catch(() => {});
  }

  return { init, showHub, enterMode, stopChatPoll };
})();
