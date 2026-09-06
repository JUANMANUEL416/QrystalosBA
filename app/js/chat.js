/**
 * Chat del caso — mensajes en disco (activo/{id-caso}/chat.json)
 */
window.QrysChat = (function () {
  const STORAGE_PREFIX = "qrys_chat_";
  const DOC_PATH_RE = /(?:^|[\s(])(dictamenes\/[a-zA-Z0-9_-]+\.html|aprobados\/[a-zA-Z0-9_/-]+\.html|activo\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+\.(?:html|md))/gi;

  let currentIdCaso = null;

  function loadLocal(idCaso) {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_PREFIX + idCaso) || '{"mensajes":[]}');
    } catch {
      return { mensajes: [] };
    }
  }

  function saveLocal(idCaso, data) {
    localStorage.setItem(STORAGE_PREFIX + idCaso, JSON.stringify(data));
  }

  function extractIdCasoFromRuta(rutaRel) {
    const m = String(rutaRel || "").match(/dictamenes\/([a-zA-Z0-9_-]+)\.html/i);
    return m ? m[1] : null;
  }

  function docUrl(rutaRel, idCaso, urlAbsoluta) {
    const clean = String(rutaRel || "").replace(/^\//, "").replace(/\\/g, "/");
    const caso =
      idCaso ||
      currentIdCaso ||
      extractIdCasoFromRuta(clean) ||
      extractIdCasoFromRuta(urlAbsoluta || "");

    if (caso && (clean.includes("dictamenes/") || String(urlAbsoluta || "").includes("dictamenes"))) {
      if (location.protocol === "file:") {
        return new URL(`../dictamenes/${caso}.html`, location.href).href;
      }
      return new URL(`/api/caso/${encodeURIComponent(caso)}/dictamen?t=${Date.now()}`, location.origin).href;
    }

    if (urlAbsoluta) {
      const u = new URL(urlAbsoluta, location.origin);
      u.searchParams.set("t", String(Date.now()));
      return u.href;
    }

    if (location.protocol === "file:") {
      return new URL(`../${clean}`, location.href).href;
    }

    const url = new URL(`/${clean}`, location.origin);
    url.searchParams.set("t", String(Date.now()));
    return url.href;
  }

  function openUrlInNewTab(url) {
    const a = document.createElement("a");
    a.href = url;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  function openDocument(rutaRel, idCaso, urlAbsoluta) {
    if (location.protocol === "file:") {
      const ok = confirm(
        "En modo file:// el navegador suele bloquear abrir otros archivos locales.\n\n" +
          "Use abrir-app.bat o servir-app.bat y abra http://localhost:8765/app/\n\n" +
          "¿Intentar abrir igualmente?",
      );
      if (!ok) return;
    }

    const url = docUrl(rutaRel, idCaso, urlAbsoluta);
    openUrlInNewTab(url);
  }

  function mergeMensajes(...listas) {
    const byId = {};
    for (const lista of listas) {
      for (const m of lista || []) {
        if (m?.id) byId[m.id] = m;
      }
    }
    return Object.values(byId).sort((a, b) => String(a.fecha || "").localeCompare(String(b.fecha || "")));
  }

  async function listarCasosActivos() {
    if (location.protocol === "file:") return [];

    try {
      const r = await fetch(`/api/casos-activos?t=${Date.now()}`, { cache: "no-store" });
      if (r.ok) {
        const d = await r.json();
        if (Array.isArray(d.casos) && d.casos.length) return d.casos;
      }
    } catch {
      /* listado de carpeta */
    }

    try {
      const r = await fetch(`/activo/?t=${Date.now()}`, { cache: "no-store" });
      if (r.ok) {
        const html = await r.text();
        const ids = [...html.matchAll(/href="([^"?#]+)"/gi)]
          .map((m) => decodeURIComponent(m[1]).replace(/\/$/, "").split("/").pop())
          .filter((n) => /^\d{8}-\d+$/.test(n));
        const unique = [...new Set(ids)];
        const casos = [];
        await Promise.all(
          unique.map(async (idCaso) => {
            const caso = {
              idCaso,
              idReq: idCaso.split("-")[1] || "",
              titulo: idCaso,
              nMensajes: 0,
              fase1Cerrada: false,
            };
            try {
              const s = await fetch(`/activo/${idCaso}/solicitud.json?t=${Date.now()}`, { cache: "no-store" });
              if (s.ok) {
                const sol = await s.json();
                caso.idReq = sol.identificacion?.idReq || caso.idReq;
                caso.titulo = sol.contenido?.titulo || caso.titulo;
              }
            } catch {
              /* */
            }
            try {
              const c = await fetch(`/activo/${idCaso}/chat.json?t=${Date.now()}`, { cache: "no-store" });
              if (c.ok) {
                const chat = await c.json();
                caso.nMensajes = (chat.mensajes || []).length;
              }
            } catch {
              /* */
            }
            try {
              const e = await fetch(`/activo/${idCaso}/estado.json?t=${Date.now()}`, { cache: "no-store" });
              if (e.ok) {
                const est = await e.json();
                caso.fase1Cerrada = !!est.fase1Cerrada;
              }
            } catch {
              /* */
            }
            casos.push(caso);
          }),
        );
        if (casos.length) return casos.sort((a, b) => String(b.idCaso).localeCompare(String(a.idCaso)));
      }
    } catch {
      /* historico */
    }

    try {
      const r = await fetch(`/api/historico?t=${Date.now()}`, { cache: "no-store" });
      if (r.ok) {
        const d = await r.json();
        return (d.historico || []).map((h) => ({
          idCaso: h.idCaso,
          idReq: h.idReq,
          titulo: h.titulo || h.proyecto || h.idCaso,
          nMensajes: h.nMensajes || 0,
          fase1Cerrada: !!h.fase1Cerrada,
        }));
      }
    } catch {
      /* */
    }
    return [];
  }

  function resolverIdCaso(casos, idReq, idCasoHint) {
    const lista = casos || [];
    const hint = String(idCasoHint || "").trim();
    const req = String(idReq || "").trim();
    if (hint && lista.some((c) => c.idCaso === hint)) return hint;
    const byReq = lista.filter(
      (c) => (req && c.idReq === req) || (req && String(c.idCaso).endsWith(`-${req}`)),
    );
    if (byReq.length) {
      return byReq.sort(
        (a, b) => (b.nMensajes || 0) - (a.nMensajes || 0) || String(b.idCaso).localeCompare(String(a.idCaso)),
      )[0].idCaso;
    }
    if (hint && /^\d{8}-\d+$/.test(hint)) return hint;
    return "";
  }

  async function fetchChatDisk(idCaso) {
    try {
      const resp = await fetch(`/activo/${encodeURIComponent(idCaso)}/chat.json?t=${Date.now()}`, {
        cache: "no-store",
      });
      if (!resp.ok) return [];
      const data = await resp.json();
      return data.mensajes || [];
    } catch {
      return [];
    }
  }

  async function fetchChat(idCaso) {
    if (location.protocol === "file:") return loadLocal(idCaso);
    const local = loadLocal(idCaso);
    let apiMsgs = [];
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/chat?t=${Date.now()}`, {
        cache: "no-store",
      });
      if (resp.ok) {
        const data = await resp.json();
        apiMsgs = data.mensajes || [];
      }
    } catch {
      /* se mezcla con disco */
    }
    const diskMsgs = await fetchChatDisk(idCaso);
    const mensajes = mergeMensajes(local.mensajes, apiMsgs, diskMsgs);
    const data = { mensajes };
    saveLocal(idCaso, data);
    return data;
  }

  async function fetchDocumentos(idCaso) {
    const fallback = [
      {
        tipo: "dictamen",
        titulo: "Dictamen técnico",
        ruta: `dictamenes/${idCaso}.html`,
        url: location.protocol === "file:" ? null : `/dictamenes/${idCaso}.html`,
        estado: "propuesto",
      },
    ];

    if (location.protocol === "file:") return fallback;

    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/documentos?t=${Date.now()}`, {
        cache: "no-store",
      });
      if (!resp.ok) return fallback;
      const data = await resp.json();
      return data.documentos?.length ? data.documentos : fallback;
    } catch {
      return fallback;
    }
  }

  async function sendMessage(idCaso, texto, autor) {
    const msg = {
      id: Date.now().toString(36),
      autor: autor || "coordinador",
      texto,
      fecha: new Date().toISOString(),
    };

    if (location.protocol === "file:") {
      const data = loadLocal(idCaso);
      data.mensajes = data.mensajes || [];
      data.mensajes.push(msg);
      saveLocal(idCaso, data);
      return { ok: true, mensaje: msg, local: true };
    }

    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ texto, autor: autor || "coordinador" }),
      });
      const data = await resp.json();
      if (data.mensajes) saveLocal(idCaso, data);
      return data;
    } catch (e) {
      const data = loadLocal(idCaso);
      data.mensajes.push(msg);
      saveLocal(idCaso, data);
      return { ok: true, mensaje: msg, local: true, error: String(e) };
    }
  }

  async function fetchEstado(idCaso) {
    if (location.protocol === "file:") {
      try {
        return JSON.parse(localStorage.getItem(STORAGE_PREFIX + idCaso + "_estado") || '{"fase":1,"fase1Cerrada":false}');
      } catch {
        return { fase: 1, fase1Cerrada: false };
      }
    }
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/estado?t=${Date.now()}`, {
        cache: "no-store",
      });
      if (!resp.ok) return { fase: 1, fase1Cerrada: false };
      return await resp.json();
    } catch {
      return { fase: 1, fase1Cerrada: false };
    }
  }

  async function cerrarFase1(idCaso, opts = {}) {
    const estado = { fase: 2, fase1Cerrada: true, cerradaEn: new Date().toISOString() };
    if (location.protocol === "file:") {
      localStorage.setItem(STORAGE_PREFIX + idCaso + "_estado", JSON.stringify(estado));
      return { ok: true, local: true, ...estado, correo: { ok: false, error: "Use abrir-app.bat para enviar el correo." } };
    }
    const dest = (opts.correo || opts.destinatario || "").trim();
    const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/cerrar-fase1`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ correo: dest, destinatario: dest }),
    });
    return resp.json();
  }

  let timerHandle = null;

  function stopLiveTimer() {
    if (timerHandle) {
      clearInterval(timerHandle);
      timerHandle = null;
    }
  }

  function hideLiveTimer() {
    stopLiveTimer();
    const el = document.getElementById("chatTimer");
    if (el) el.classList.add("hidden");
  }

  function fmtElapsed(fromIso) {
    const start = fromIso ? new Date(fromIso).getTime() : Date.now();
    if (Number.isNaN(start)) return "0:00";
    const sec = Math.max(0, Math.floor((Date.now() - start) / 1000));
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
  }

  function startLiveTimer(bot) {
    const el = document.getElementById("chatTimer");
    if (!el) return;
    stopLiveTimer();
    el.classList.remove("hidden");
    function tick() {
      const hb = bot.heartbeatEn ? new Date(bot.heartbeatEn).getTime() : null;
      const hace = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
      let vivo = "arrancando…";
      if (bot.pidVivo === false) vivo = "proceso detenido";
      else if (hace != null && hace <= 15) vivo = "latido OK";
      else if (hace != null) vivo = `sin latido (${hace}s)`;
      el.textContent = `${fmtElapsed(bot.iniciadoEn)} · ${vivo}`;
    }
    tick();
    timerHandle = setInterval(tick, 1000);
  }

  function computeAgentStatus(estado, mensajes, documentos) {
    const bot = estado?.bot || {};
    const hb = bot.heartbeatEn ? new Date(bot.heartbeatEn).getTime() : (bot.iniciadoEn ? new Date(bot.iniciadoEn).getTime() : null);
    const haceHb = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
    const botMuerto =
      bot.estado === "trabajando" &&
      (bot.pidVivo === false || (haceHb != null && haceHb > 45));

    if (bot.estado === "trabajando" && !botMuerto) {
      return {
        code: "trabajando",
        label: "El agente está trabajando",
        detail: "El temporizador confirma que el proceso sigue vivo. Deje esta pestaña abierta.",
        bot,
      };
    }
    if (bot.estado === "sin_clave") {
      return {
        code: "esperando",
        label: "Falta CURSOR_API_KEY",
        detail: "Péguela en .env (empieza por crsr_) y reinicie abrir-app.bat.",
      };
    }
    if (bot.estado === "error" || botMuerto) {
      return {
        code: "esperando",
        label: "El bot no respondió",
        detail: bot.error || "Se quedó sin latido. El análisis lo hace Cursor; recargue el Chat. No deje esta pestaña esperando.",
      };
    }
    if (estado?.fase1Cerrada) {
      return {
        code: "cerrado",
        label: "Fase 1 cerrada",
        detail: "Dictamen aprobado. SQL en sql_refe/{ID-REQ}/.",
      };
    }

    const relevantes = (mensajes || []).filter((m) => m.autor !== "sistema");
    const ultimo = relevantes[relevantes.length - 1];
    const delAgente = relevantes.filter((m) => m.autor === "agente");
    const ultimoAgente = delAgente[delAgente.length - 1];
    const hayDictamen = (documentos || []).some(
      (d) => d.tipo === "dictamen" || String(d.ruta || "").includes("dictamenes/"),
    );
    const cuandoAgente = ultimoAgente ? fmtFecha(ultimoAgente.fecha) : "aún no ha escrito";

    if (ultimo?.autor === "agente") {
      return {
        code: "esperando",
        label: hayDictamen ? "El agente ya dejó propuesta" : "El agente ya respondió",
        detail: `Último mensaje: ${cuandoAgente}. Siga solo en este Chat. Si hay HTML, ábralo en Documentos.`,
      };
    }

    if (ultimo?.autor === "coordinador") {
      return {
        code: "esperando",
        label: "Mensaje guardado — el bot no arrancó",
        detail: `Reinicie abrir-app.bat y pulse Enviar de nuevo. Último del agente: ${cuandoAgente}.`,
      };
    }

    return {
      code: "esperando",
      label: "Esperando el primer mensaje",
      detail: "Escriba solo aquí. El agente responde en verde cuando Cursor toma el caso.",
    };
  }

  function renderAgentStatus(estadoAgente) {
    const box = document.getElementById("chatEstadoAgente");
    const label = document.getElementById("chatEstadoLabel");
    const detail = document.getElementById("chatEstadoDetail");
    if (!box || !label || !detail) return estadoAgente?.code;

    if (!estadoAgente) {
      box.classList.add("hidden");
      hideLiveTimer();
      return null;
    }

    box.classList.remove("hidden", "chat-estado-trabajando", "chat-estado-esperando", "chat-estado-cerrado");
    box.classList.add(`chat-estado-${estadoAgente.code}`);
    label.textContent = estadoAgente.label;
    detail.textContent = estadoAgente.detail;
    if (estadoAgente.code === "trabajando" && estadoAgente.bot) {
      startLiveTimer(estadoAgente.bot);
    } else {
      hideLiveTimer();
    }
    return estadoAgente.code;
  }

  function docIcon(tipo) {
    if (tipo === "aprobado") return "✅";
    if (tipo === "instruccion") return "📋";
    return "📄";
  }

  function badgeClass(estado) {
    if (estado === "aprobado") return "doc-badge-aprobado";
    if (estado === "interno") return "doc-badge-interno";
    return "doc-badge-propuesto";
  }

  function renderDocumentList(container, documentos, idCaso) {
    if (!container) return;
    currentIdCaso = idCaso || currentIdCaso;

    if (!documentos?.length) {
      container.innerHTML = `<li class="chat-doc-empty hint">Sin documentos detectados aún.</li>`;
      return;
    }

    container.innerHTML = documentos
      .map((doc) => {
        const ruta = escAttr(doc.ruta);
        const url = escAttr(doc.url || "");
        const titulo = esc(doc.titulo || doc.ruta);
        const badge = esc(doc.estado || "propuesto");
        return `<li class="chat-doc-item" tabindex="0" data-ruta="${ruta}" data-url="${url}" title="Clic o doble clic para abrir">
          <span class="doc-icon" aria-hidden="true">${docIcon(doc.tipo)}</span>
          <div class="doc-meta">
            <div class="doc-title">${titulo}</div>
            <div class="doc-path">${esc(doc.url || doc.ruta)}</div>
          </div>
          <span class="doc-badge ${badgeClass(doc.estado)}">${badge}</span>
          <button type="button" class="btn btn-primary btn-sm btn-open-doc" data-ruta="${ruta}" data-url="${url}">Abrir</button>
        </li>`;
      })
      .join("");

    function abrirDesdeItem(el) {
      openDocument(el.dataset.ruta, idCaso, el.dataset.url || null);
    }

    container.querySelectorAll(".chat-doc-item").forEach((item) => {
      item.addEventListener("click", (e) => {
        if (e.target.closest(".btn-open-doc")) return;
        abrirDesdeItem(item);
      });
      item.addEventListener("dblclick", () => abrirDesdeItem(item));
      item.addEventListener("keydown", (e) => {
        if (e.key === "Enter") abrirDesdeItem(item);
      });
    });

    container.querySelectorAll(".btn-open-doc").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        abrirDesdeItem(btn);
      });
    });
  }

  function linkifyDocuments(html, idCaso) {
    return html.replace(DOC_PATH_RE, (match, path) => {
      const prefix = match.startsWith(path) ? "" : match.slice(0, match.indexOf(path));
      const href = escAttr(docUrl(path, idCaso));
      return `${prefix}<a href="${href}" class="chat-link-doc" target="_blank" rel="noopener noreferrer">${esc(path)}</a>`;
    });
  }

  const NEAR_BOTTOM_PX = 96;

  function chatSignature(mensajes, idCaso) {
    if (!mensajes?.length) return `empty|${idCaso || ""}`;
    return `${idCaso || ""}#${mensajes
      .map((m) => `${m.id || ""}|${m.autor}|${m.fecha || m.en || ""}|${String(m.texto || "").length}`)
      .join(";")}`;
  }

  function isNearBottom(el) {
    return el.scrollHeight - el.scrollTop - el.clientHeight < NEAR_BOTTOM_PX;
  }

  function paintChatHtml(container, html, signature, forceBottom) {
    const prev = container.dataset.chatSig || "";
    if (prev === signature && !forceBottom) return;
    const keepPlace = !forceBottom && prev && !isNearBottom(container);
    const saved = container.scrollTop;
    container.innerHTML = html;
    container.dataset.chatSig = signature;
    requestAnimationFrame(() => {
      container.scrollTop = keepPlace ? saved : container.scrollHeight;
    });
  }

  function renderChat(container, mensajes, idCaso, opts) {
    currentIdCaso = idCaso || currentIdCaso;
    const forceBottom = !!(opts && opts.forceBottom);

    if (!mensajes?.length) {
      paintChatHtml(
        container,
        `<p class="hint chat-empty">Sin mensajes. Tras activar Fase 1, el agente presentará la propuesta aquí. Usted responde hasta cerrar el caso.</p>`,
        chatSignature([], idCaso),
        forceBottom,
      );
      return;
    }

    const vistos = new Set();
    const visibles = [];
    for (const m of mensajes) {
      if (m.autor === "agente") {
        const clave = String(m.texto || "").trim();
        if (vistos.has(clave)) continue;
        vistos.add(clave);
      }
      visibles.push(m);
    }

    const html = visibles
      .map((m) => {
        const cls =
          m.autor === "agente" ? "chat-msg-agente" : m.autor === "sistema" ? "chat-msg-sistema" : "chat-msg-coord";
        const quien = { agente: "Agente", coordinador: "Usted", sistema: "Sistema" }[m.autor] || m.autor;
        const body = linkifyDocuments(esc(m.texto), idCaso).replace(/\n/g, "<br>");
        return `<div class="chat-msg ${cls}">
          <div class="chat-msg-head"><strong>${esc(quien)}</strong> <small>${fmtFecha(m.fecha)}</small></div>
          <div class="chat-msg-body">${body}</div>
        </div>`;
      })
      .join("");

    paintChatHtml(container, html, chatSignature(visibles, idCaso), forceBottom);
  }

  function fmtFecha(iso) {
    if (!iso) return "";
    try {
      return new Date(iso).toLocaleString("es-CO", { dateStyle: "short", timeStyle: "short" });
    } catch {
      return iso;
    }
  }

  function esc(s) {
    return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function escAttr(s) {
    return esc(s).replace(/"/g, "&quot;");
  }

  return {
    fetchChat,
    fetchDocumentos,
    sendMessage,
    fetchEstado,
    cerrarFase1,
    renderChat,
    renderDocumentList,
    renderAgentStatus,
    computeAgentStatus,
    openDocument,
    loadLocal,
    listarCasosActivos,
    resolverIdCaso,
  };
})();
