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
    if (!r.ok) throw new Error(data.error || data.mensaje || r.statusText || String(r.status));
    return data;
  }

  function setEstado(msg) {
    const el = $("#srEstado");
    if (el) el.textContent = msg || "";
  }

  function collect() {
    return {
      id: ($("#srId")?.value || "").trim(),
      analista: $("#srAnalista")?.value || "",
      titulo: $("#srTitulo")?.value || "",
      proyecto: $("#srProyecto")?.value || "",
      modulo: $("#srModulo")?.value || "",
      procesoId: $("#srProcesoId")?.value || "",
      prioridad: $("#srPrioridad")?.value || "Media",
      necesidad: $("#srNecesidad")?.value || "",
      hoy: $("#srHoy")?.value || "",
      propuesta: $("#srPropuesta")?.value || "",
      justificacion: $("#srJustificacion")?.value || "",
      analisis: $("#srAnalisis")?.value || "",
      alcance: $("#srAlcance")?.value || "",
      restricciones: $("#srRestricciones")?.value || "",
      criterios: $("#srCriterios")?.value || "",
      recomendacion: $("#srRecomendacion")?.value || "",
      aval: {
        aplica: !!$("#srAvalAplica")?.checked,
        idReq: $("#srAvalIdReq")?.value || "",
        idCaso: $("#srAvalIdCaso")?.value || "",
        titulo: ($("#srAvalResumen")?.textContent || "").replace(/^Ninguno\.?$/, ""),
        notas: $("#srAvalNotas")?.value || "",
      },
    };
  }

  function fill(sol) {
    actual = sol;
    if (!sol) return;
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
    set("#srAvalNotas", aval.notas);
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
  }

  function toggleAval() {
    const box = $("#srAvalBox");
    if (box) box.hidden = !$("#srAvalAplica")?.checked;
  }

  async function cargarProcesos() {
    const sel = $("#srProcesoId");
    if (!sel) return;
    const prev = sel.value;
    try {
      const data = await fetchJson("/api/conocimiento");
      const procesos = data.indice?.procesos || data.procesos || [];
      sel.innerHTML = `<option value="">Inferir al analizar…</option>`
        + procesos.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}${p.modulo ? ` (${esc(p.modulo)})` : ""}</option>`).join("");
      if (prev) sel.value = prev;
    } catch (_) {
      /* sin servidor */
    }
  }

  async function guardar() {
    const body = collect();
    if (!(body.titulo || body.necesidad).trim()) {
      setEstado("Indique al menos el título o la necesidad.");
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

  async function analizar() {
    const sol = await guardar();
    if (!sol) return;
    setEstado("Analizando con conocimiento/…");
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
    setEstado("El agente está contrastando la necesidad. Vea el Chat.");
  }

  async function documento() {
    const sol = await guardar();
    if (!sol) return;
    setEstado("Generando documento…");
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(sol.id)}/documento`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(collect()),
    });
    if (data.documento) {
      const link = $("#srDocLink");
      if (link) {
        link.href = data.documento.url;
        link.hidden = false;
      }
      window.open(data.documento.url, "_blank");
    }
    setEstado(`Documento listo: ${data.documento?.ruta || ""}`);
  }

  async function refreshLista() {
    const body = $("#srListaBody");
    if (!body) return;
    try {
      const data = await fetchJson("/api/solicitar");
      const items = data.items || [];
      if (!items.length) {
        body.innerHTML = `<tr><td colspan="6" class="hint">Aún no hay solicitudes.</td></tr>`;
        return;
      }
      body.innerHTML = items.map((i) => `<tr>
        <td><code>${esc(i.id)}</code></td>
        <td>${esc(i.titulo)}</td>
        <td>${esc(i.proyecto)}</td>
        <td>${esc(i.estado)}</td>
        <td>${esc(i.avalReq || "—")}</td>
        <td><button type="button" class="btn btn-ghost btn-sm" data-sr-abrir="${esc(i.id)}">Abrir</button></td>
      </tr>`).join("");
    } catch (e) {
      body.innerHTML = `<tr><td colspan="6">${esc(e.message)}</td></tr>`;
    }
  }

  async function abrir(id) {
    const data = await fetchJson(`/api/solicitar/${encodeURIComponent(id)}`);
    fill(data.solicitud);
    ultimoBot = data.bot || null;
    renderChat(data.chat, data.bot);
    showPanel("form");
    setEstado(`Abierta ${id}`);
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
    $("#btnSrGuardar")?.addEventListener("click", () => guardar().catch((e) => setEstado(e.message)));
    $("#btnSrAnalizar")?.addEventListener("click", () => analizar().catch((e) => setEstado(e.message)));
    $("#btnSrDocumento")?.addEventListener("click", () => documento().catch((e) => setEstado(e.message)));
    $("#btnSrEnviarChat")?.addEventListener("click", () => enviarChat().catch((e) => setEstado(e.message)));
    $("#srAvalAplica")?.addEventListener("change", toggleAval);
    $("#srAvalBuscar")?.addEventListener("input", filtrarAvales);
    $("#srAvalResultados")?.addEventListener("click", (e) => {
      const btn = e.target.closest?.("[data-caso], [data-req]");
      if (btn) asociarAval(btn);
    });
    $("#srListaBody")?.addEventListener("click", (e) => {
      const btn = e.target.closest?.("[data-sr-abrir]");
      if (btn) abrir(btn.getAttribute("data-sr-abrir")).catch((err) => setEstado(err.message));
    });
    document.querySelectorAll("[data-sr-panel]").forEach((btn) => {
      btn.addEventListener("click", () => showPanel(btn.dataset.srPanel));
    });
  }

  function enter() {
    cargarProcesos();
    cargarAvales();
    refreshLista();
    toggleAval();
  }

  function init() {
    bind();
  }

  return { init, enter, stopPoll };
})();
