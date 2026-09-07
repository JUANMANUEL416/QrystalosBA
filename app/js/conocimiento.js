/**
 * Menú central — Analista / Consultas / Documentar (base de procesos).
 */
window.QrysConocimiento = (function () {
  const MODE_KEY = "qrystalos_ba_modo";
  let cache = null;
  let caches = { consultas: null, documentar: null };
  let procesoActual = null;
  let chatPoll = null;
  let pagePanel = { consultas: "trabajo", documentar: "trabajo" };

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

  function canalDe(mode) {
    if (mode === "consultas") return "consultas";
    return "documentar";
  }

  async function loadFromDisk(canal) {
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
      canal: canal || "documentar",
      chat,
      chats: [],
      chatSoloLectura: false,
      sqlArchivos: [],
      desdeDisco: true,
    };
  }

  async function loadResumen(canal) {
    const c = canal || "documentar";
    try {
      const data = await fetchJson(`/api/conocimiento?canal=${encodeURIComponent(c)}`);
      caches[c] = data;
      cache = data;
      return data;
    } catch (_) {
      const data = await loadFromDisk(c);
      caches[c] = data;
      cache = data;
      return data;
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
      await loadResumen("consultas");
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
      det.innerHTML = `<p class="hint">Elija un proceso a la izquierda. Flujo (capa → gate) o Procedimientos (SP → método). El Chat está en su pestaña.</p>`;
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

  function normSpNombre(raw, comoSql) {
    let n = String(raw || "").trim();
    if (!n) return "";
    n = n.replace(/\.sql$/i, "");
    return comoSql ? n + ".sql" : n;
  }

  function spsPendientes(soloValle) {
    const items = (cache?.pendientes?.items || []).filter((i) => i.estado !== "completado" && i.spNombre);
    const valleId = cache?.valle?.proceso?.id || "";
    const filtrados = soloValle && valleId ? items.filter((i) => i.procesoId === valleId) : items;
    const seen = new Set();
    const out = [];
    filtrados.forEach((i) => {
      const key = String(i.spNombre).trim().toUpperCase().replace(/\.SQL$/, "");
      if (!key || seen.has(key)) return;
      seen.add(key);
      out.push(String(i.spNombre).trim());
    });
    return out;
  }

  async function copiarTexto(texto) {
    const t = (texto || "").trim();
    if (!t) throw new Error("No hay nombres de SP pendientes.");
    try {
      await navigator.clipboard.writeText(t);
      return;
    } catch (_) {}
    try {
      const ta = document.createElement("textarea");
      ta.value = t;
      ta.setAttribute("readonly", "");
      ta.style.position = "fixed";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand("copy");
      document.body.removeChild(ta);
      if (ok) return;
    } catch (_) {}
    window.prompt("Seleccione y copie (Ctrl+C):", t);
  }

  async function onCopiarSps(comoSql, soloValle) {
    const hint = $("#docCopiarHint");
    try {
      const nombres = spsPendientes(soloValle).map((n) => normSpNombre(n, !!comoSql));
      await copiarTexto(nombres.join("\n"));
      if (hint) {
        hint.hidden = false;
        hint.textContent = `Copiados ${nombres.length}: ${nombres.join(", ")}`;
      }
    } catch (e) {
      if (hint) {
        hint.hidden = false;
        hint.textContent = e.message;
      } else {
        alert(e.message);
      }
    }
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
            ${i.spNombre ? `<p class="hint compact">SP sugerido: <code>${esc(i.spNombre)}</code> <button type="button" class="btn btn-ghost btn-sm btn-copiar-sp" data-sp="${esc(i.spNombre)}">Copiar</button></p>` : ""}
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
    renderChatIn("#docChatMensajes", caches.documentar, forceBottom);
    renderChatIn("#consultaChatMensajes", caches.consultas, forceBottom);
    fillChatSelect("consultas", "#consultaChatSelect");
    fillChatSelect("documentar", "#docChatSelect");
    toggleCompose("consultas", "#consultaChatCompose");
    toggleCompose("documentar", "#docChatCompose");
    renderBotHint();
  }

  function fillChatSelect(canal, selId) {
    const sel = $(selId);
    const data = caches[canal];
    if (!sel || !data) return;
    const items = data.chats || [];
    const actual = data.chatViendoId || data.chatActivoId || "";
    sel.innerHTML = items
      .map((c) => {
        const tag = c.estado === "archivado" ? " (archivado)" : " (activo)";
        return `<option value="${esc(c.id)}">${esc(c.titulo || c.id)}${tag}</option>`;
      })
      .join("");
    if (actual) sel.value = actual;
  }

  function toggleCompose(canal, sel) {
    const box = $(sel);
    const data = caches[canal];
    if (!box || !data) return;
    box.classList.toggle("hidden", !!data.chatSoloLectura);
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

  function hintDe(canal) {
    const bot = (caches[canal] || {}).bot || {};
    if (bot.estado === "trabajando") return "El agente está trabajando. En unos segundos aparece la respuesta aquí.";
    if (bot.estado === "error" || bot.estado === "sin_clave") {
      return bot.error ? "El agente no pudo responder: " + bot.error : "El agente no pudo responder este turno.";
    }
    if ((caches[canal] || {}).chatSoloLectura) return "Chat archivado (solo lectura). Pulse Nuevo chat para seguir.";
    return "";
  }

  function renderBotHint() {
    [
      ["consultas", "#consultaChatBotHint"],
      ["documentar", "#docChatBotHint"],
    ].forEach(([canal, sel]) => {
      const el = $(sel);
      if (!el) return;
      const text = hintDe(canal);
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

  function renderChatIn(sel, data, forceBottom) {
    const box = $(sel);
    if (!box || !data) return;
    const msgs = data.chat?.mensajes || [];
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
        return `<div class="${cls}"><div class="chat-msg-head"><strong>${esc(who)}</strong> · ${esc(m.en || m.fecha || "")}</div><div>${esc(m.texto).replace(/\n/g, "<br>")}</div></div>`;
      })
      .join("");
    paintChat(box, html, chatSig(msgs), !!forceBottom);
  }

  function renderValle() {
    const el = $("#docValleBox");
    if (!el || !cache) return;
    const ruta = cache.rutaDocumentar || {};
    const pasos = ruta.pasos || [];
    const vig = cache.vigilante || {};
    const valle = cache.valle;
    if (!pasos.length) {
      el.hidden = true;
      return;
    }
    el.hidden = false;
    const estadoVig = vig.activo === false ? "Pausado" : "Activo (trabaja solo)";
    const actual = valle?.proceso?.id || "—";
    const filas = pasos
      .map((p) => {
        const on = p.procesoId === actual ? " kb-valle--on" : "";
        return `<li class="kb-valle-item${on}"><strong>${esc(p.orden)}.</strong> ${esc(p.nombre || p.procesoId)} <span class="kb-meta">${esc(p.familia || "")}</span></li>`;
      })
      .join("");
    el.innerHTML = `
      <div class="historico-toolbar" style="margin:0 0 .5rem">
        <h3 class="kb-h3" style="margin:0;flex:1">Ruta administrativa</h3>
        <span class="hint compact">${esc(estadoVig)}${actual !== "—" ? " · valle: " + esc(actual) : (cache.rutaEstado?.cerrada ? " · ruta cubierta" : "")}</span>
        <button type="button" class="btn btn-ghost btn-sm" id="btnDocVigilante">${vig.activo === false ? "Reanudar agente" : "Pausar agente"}</button>
      </div>
      <p class="hint compact">Barrido automático <strong>detenido</strong> por defecto. Use Documentar (Chat) o Analista de negocio cuando encuentre algo nuevo o haya que mejorar un proceso. No hace falta reanudar el agente autónomo.</p>
      <ol class="kb-valle-list">${filas}</ol>`;
    $("#btnDocVigilante")?.addEventListener("click", () => onToggleVigilante(!(vig.activo === false)));
  }

  async function onToggleVigilante(pausar) {
    try {
      await fetchJson("/api/conocimiento/vigilante", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ activo: !pausar }),
      });
      await refreshDocumentar();
    } catch (e) {
      const err = $("#docError");
      if (err) {
        err.hidden = false;
        err.textContent = e.message;
      }
    }
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
      await loadResumen("documentar");
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
    renderValle();
  }

  function startChatPoll() {
    stopChatPoll();
    chatPoll = setInterval(() => {
      if ($("#view-documentar")?.classList.contains("active")) refreshDocumentar();
      else if ($("#view-consultas")?.classList.contains("active")) {
        loadResumen("consultas")
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

  function showPagePanel(page, panel) {
    pagePanel[page] = panel;
    $$(`[data-kb-page="${page}"]`).forEach((btn) => {
      btn.classList.toggle("is-on", btn.dataset.kbPanel === panel);
    });
    const ids =
      page === "consultas"
        ? { trabajo: "#consultaPanelTrabajo", chat: "#consultaPanelChat" }
        : { trabajo: "#docPanelTrabajo", chat: "#docPanelChat" };
    Object.entries(ids).forEach(([key, sel]) => {
      const el = $(sel);
      if (!el) return;
      el.classList.toggle("hidden", key !== panel);
    });
    if (panel === "chat") {
      loadResumen(page).then(() => renderChatBoxes(true)).catch(() => {});
    }
  }

  async function onChatNuevo(canal) {
    await fetchJson("/api/conocimiento/chat/nuevo", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ canal }),
    });
    await loadResumen(canal);
    renderChatBoxes(true);
  }

  async function onChatArchivar(canal) {
    const titulo = window.prompt("Nombre para archivar este chat (opcional):", "") || "";
    await fetchJson("/api/conocimiento/chat/archivar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ canal, titulo }),
    });
    await loadResumen(canal);
    renderChatBoxes(true);
  }

  async function onChatAbrir(canal, sid) {
    if (!sid) return;
    await fetchJson("/api/conocimiento/chat/abrir", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ canal, id: sid }),
    });
    await loadResumen(canal);
    renderChatBoxes(true);
  }

  async function onEnviarChat(fromSel, canal) {
    const input = $(fromSel || "#docChatInput") || $("#consultaChatInput");
    const texto = input?.value?.trim();
    if (!texto) return;
    const dest = canal || (fromSel && fromSel.includes("consulta") ? "consultas" : "documentar");
    try {
      await fetchJson("/api/conocimiento/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          autor: "coordinador",
          texto,
          canal: dest,
          procesoId: procesoActual?.id || caches[dest]?.chat?.procesoId || "",
        }),
      });
      if (input) input.value = "";
      await loadResumen(dest);
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
    $("#btnDocCopiarSps")?.addEventListener("click", () => onCopiarSps(false, false));
    $("#btnDocCopiarSql")?.addEventListener("click", () => onCopiarSps(true, false));
    $("#btnDocCopiarValle")?.addEventListener("click", () => onCopiarSps(false, true));
    $("#docPendientesLista")?.addEventListener("click", (e) => {
      const btn = e.target && e.target.closest ? e.target.closest(".btn-copiar-sp") : null;
      if (!btn) return;
      e.preventDefault();
      e.stopPropagation();
      copiarTexto(normSpNombre(btn.getAttribute("data-sp"), false))
        .then(() => {
          const hint = $("#docCopiarHint");
          if (hint) {
            hint.hidden = false;
            hint.textContent = "Copiado: " + btn.getAttribute("data-sp");
          }
        })
        .catch((err) => alert(err.message));
    });
    $("#btnDocDocumentarSp")?.addEventListener("click", () => onDocumentarSp());
    $("#btnDocCerrarTarea")?.addEventListener("click", () => onCerrarTarea());
    $("#btnDocMarcarHecho")?.addEventListener("click", () => onMarcarHecho());
    $("#btnDocNuevoProceso")?.addEventListener("click", () => onNuevoProceso());
    $("#btnDocEnviarChat")?.addEventListener("click", () => onEnviarChat("#docChatInput", "documentar"));
    $("#btnConsultaEnviarChat")?.addEventListener("click", () => onEnviarChat("#consultaChatInput", "consultas"));
    $("#docChatInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.altKey) {
        e.preventDefault();
        onEnviarChat("#docChatInput", "documentar");
      }
    });
    $("#consultaChatInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.altKey) {
        e.preventDefault();
        onEnviarChat("#consultaChatInput", "consultas");
      }
    });
    $("#btnConsultaChatNuevo")?.addEventListener("click", () => onChatNuevo("consultas"));
    $("#btnDocChatNuevo")?.addEventListener("click", () => onChatNuevo("documentar"));
    $("#btnConsultaChatArchivar")?.addEventListener("click", () => onChatArchivar("consultas"));
    $("#btnDocChatArchivar")?.addEventListener("click", () => onChatArchivar("documentar"));
    $("#consultaChatSelect")?.addEventListener("change", (e) => onChatAbrir("consultas", e.target.value));
    $("#docChatSelect")?.addEventListener("change", (e) => onChatAbrir("documentar", e.target.value));
    $$(".kb-page-tab").forEach((btn) => {
      btn.addEventListener("click", () => showPagePanel(btn.dataset.kbPage, btn.dataset.kbPanel));
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
