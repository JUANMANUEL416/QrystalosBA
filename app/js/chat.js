/**
 * Chat del caso — mensajes en disco (activo/{id-caso}/chat.json)
 */
window.QrysChat = (function () {
  const STORAGE_PREFIX = "qrys_chat_";
  const DOC_PATH_RE = /(?:^|[\s(])(dictamenes\/[a-zA-Z0-9_-]+\.html|aprobados\/[a-zA-Z0-9_/-]+\.(?:html|md|zip)|activo\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+\.(?:html|md|json|sql)|sql_refe\/[a-zA-Z0-9_/-]+\.(?:sql|txt)|solicitudes\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+\.(?:html|md|pdf))/gi;

  let currentIdCaso = null;
  let lastDocsCount = 0;
  let lastMocksCount = 0;

  function updateDocsCountBadge() {
    const badge = document.getElementById("chatDocsCountBadge");
    const sideTabDocsBadge = document.getElementById("sideTabDocsBadge");
    const total = (lastDocsCount || 0) + (lastMocksCount || 0);
    if (badge) {
      badge.textContent = String(total);
      badge.classList.toggle("has-items", total > 0);
    }
    if (sideTabDocsBadge) {
      sideTabDocsBadge.textContent = String(lastDocsCount || 0);
    }
    const sideSub = document.getElementById("chatSideSub");
    if (sideSub) {
      sideSub.textContent = `${lastDocsCount} doc(s) · ${lastMocksCount} mockup(s)`;
    }
  }

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

  function docTipoMeta(tipo, estado) {
    const t = String(tipo || "").toLowerCase();
    const e = String(estado || "").toLowerCase();

    if (t === "aprobado" || e === "aprobado") {
      return {
        icon: "✅",
        label: "Dictamen Aprobado",
        badgeText: "Aprobado",
        badgeClass: "badge-aprobado",
        cardClass: "doc-card--aprobado",
        desc: "Dictamen final formal (Fase 1 cerrada)",
      };
    }
    if (t === "dictamen" || e === "propuesto") {
      return {
        icon: "📜",
        label: "Dictamen Técnico",
        badgeText: estado || "Propuesto",
        badgeClass: "badge-dictamen",
        cardClass: "doc-card--dictamen",
        desc: "Especificación técnica para desarrollo",
      };
    }
    if (t === "diagrama" || t.includes("flujo")) {
      return {
        icon: "🗺️",
        label: "Diagrama de Flujo",
        badgeText: "Flujo §4.5",
        badgeClass: "badge-diagrama",
        cardClass: "doc-card--diagrama",
        desc: "Mapa visual del proceso y controles",
      };
    }
    if (t === "imagen" || t.includes("captura")) {
      return {
        icon: "🖼️",
        label: "Captura de Pantalla",
        badgeText: "Evidencia",
        badgeClass: "badge-imagen",
        cardClass: "doc-card--imagen",
        desc: "Captura adjunta al análisis o pantalla del caso",
      };
    }
    if (t === "archivo" || t.includes("normativa")) {
      return {
        icon: "📎",
        label: "Archivo / Normativa",
        badgeText: "Normativa §4.6",
        badgeClass: "badge-archivo",
        cardClass: "doc-card--archivo",
        desc: "Resolución, circular o anexo técnico adjunto",
      };
    }
    if (t.includes("mockup")) {
      return {
        icon: "🎨",
        label: "Mockup UX",
        badgeText: "Mockup",
        badgeClass: "badge-mockup",
        cardClass: "doc-card--mockup",
        desc: "Ventana o pantalla propuesta para el usuario",
      };
    }
    if (t === "instruccion") {
      return {
        icon: "📋",
        label: "Instrucción Agente",
        badgeText: "Interno",
        badgeClass: "badge-interno",
        cardClass: "doc-card--interno",
        desc: "Contexto técnico y reglas para el agente Cursor",
      };
    }
    return {
      icon: "📄",
      label: "Documento",
      badgeText: estado || "Doc",
      badgeClass: "badge-default",
      cardClass: "doc-card--default",
      desc: "Documento o recurso asociado al caso",
    };
  }

  function docIcon(tipo) {
    return docTipoMeta(tipo).icon;
  }

  function badgeClass(estado) {
    if (estado === "aprobado") return "doc-badge-aprobado";
    if (estado === "interno") return "doc-badge-interno";
    if (estado === "adjunto-correo") return "doc-badge-adjunto";
    if (estado === "no-encontrado") return "doc-badge-missing";
    return "doc-badge-propuesto";
  }

  let mockupsDraft = [];
  let mockupsPlantillas = [];
  let mockupsPanelLastData = { mockups: [] };

  async function fetchMockups(idCaso, scan) {
    if (!idCaso || location.protocol === "file:") {
      return { ok: false, mockups: [], sugeridos: [], plantillas: [] };
    }
    const q = scan ? "?scan=1" : "";
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups${q}`, { cache: "no-store" });
      if (!resp.ok) return { ok: false, mockups: [], sugeridos: [], plantillas: [] };
      return await resp.json();
    } catch {
      return { ok: false, mockups: [], sugeridos: [], plantillas: [] };
    }
  }

  async function generarMockups(idCaso, opts) {
    if (!idCaso || location.protocol === "file:") {
      return { ok: false, error: "Use abrir-app.bat para generar mockups." };
    }
    const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups/generar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        notas: (opts && opts.mockupsNotas) || "",
        mockupsNotas: (opts && opts.mockupsNotas) || "",
      }),
    });
    return resp.json();
  }

  async function saveMockups(idCaso, mockups, opts) {
    if (!idCaso || location.protocol === "file:") {
      return { ok: false, error: "Use abrir-app.bat para guardar mockups." };
    }
    const payload = { mockups };
    if (opts && Object.prototype.hasOwnProperty.call(opts, "mockupsNotas")) {
      payload.mockupsNotas = opts.mockupsNotas;
    }
    const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return resp.json();
  }

  function normalizeMockupPath(raw) {
    return String(raw || "")
      .trim()
      .replace(/\\/g, "/")
      .replace(/^\//, "");
  }

  function renderMockupsPanel(idCaso, data, opts) {
    const bar = document.getElementById("chatMockupsBar");
    const btnAbrirChat = document.getElementById("btnChatMockupAbrir");
    const list = document.getElementById("chatMockupsList");
    const pill = document.getElementById("chatMockupsCorreoPill");
    const hint = document.getElementById("chatMockupsHint");
    const status = document.getElementById("chatMockupsStatus");
    const sugerBox = document.getElementById("chatMockupsSugeridos");
    const sugerList = document.getElementById("chatMockupsSugeridosList");
    const selPlant = document.getElementById("chatMockupPlantilla");
    const readonly = !!(opts && opts.readonly);

    if (!bar || !list) return;

    bar.classList.toggle("readonly", readonly);
    if (pill) pill.textContent = data.correoHint || "—";
    if (hint && data.correoHint) {
      hint.textContent =
        "Al enviar el correo: " +
        data.correoHint +
        ". Se adjunta ZIP offline (*-offline.zip: HTML + imagenes/); descomprimir antes de abrir.";
    }
    if (status && opts && opts.statusMsg) status.textContent = opts.statusMsg;

    mockupsPanelLastData = data || { mockups: [] };
    mockupsDraft = (data.mockups || [])
      .map((m) => m.ruta)
      .filter((r) => {
        const rel = String(r || "").replace(/\\/g, "/").replace(/^\//, "");
        if (!rel || !idCaso) return !!rel;
        if (rel.startsWith("activo/")) return rel.startsWith(`activo/${idCaso}/`);
        return rel.startsWith("solicitudes/");
      });
    mockupsPlantillas = data.plantillas || [];
    lastMocksCount = (mockupsDraft || []).length;
    updateDocsCountBadge();

    if (btnAbrirChat) {
      const abiertos = (data.mockups || []).filter((m) => m.existe !== false && (m.url || m.ruta));
      btnAbrirChat.disabled = readonly || !idCaso || !abiertos.length;
    }

    if (selPlant) {
      const prev = selPlant.value;
      selPlant.innerHTML =
        `<option value="">+ Plantilla…</option>` +
        mockupsPlantillas
          .map((p) => `<option value="${escAttr(p.ruta)}">${esc(p.titulo || p.ruta)}</option>`)
          .join("");
      if (prev && [...selPlant.options].some((o) => o.value === prev)) selPlant.value = prev;
    }

    if (!mockupsDraft.length) {
      list.innerHTML = `<li class="chat-mockups-empty hint">Sin mockups. Pulse <strong>Generar mockups</strong> (ventana propuesta, no la captura), escanee disco o agregue una ruta .html.</li>`;
    } else {
      list.innerHTML = mockupsDraft
        .map((ruta) => {
          const meta = (data.mockups || []).find((m) => m.ruta === ruta) || {};
          const missing = meta.existe === false;
          const badge = missing ? "no-encontrado" : "adjunto-correo";
          const removeBtn = readonly
            ? ""
            : `<button type="button" class="btn btn-ghost btn-sm btn-mock-remove" data-ruta="${escAttr(ruta)}">Quitar</button>`;
          return `<li class="chat-mockups-item${missing ? " missing" : ""}" data-ruta="${escAttr(ruta)}">
            <span aria-hidden="true">${missing ? "⚠️" : docIcon(meta.tipo || "mockup-ux")}</span>
            <span class="mock-path" title="${escAttr(ruta)}">${esc(ruta)}</span>
            <span class="doc-badge ${badgeClass(badge)}">${missing ? "no encontrado" : "correo"}</span>
            <button type="button" class="btn btn-primary btn-sm btn-mock-open" data-ruta="${escAttr(ruta)}" ${missing ? "disabled" : ""}>Abrir</button>
            ${removeBtn}
          </li>`;
        })
        .join("");
    }

    list.querySelectorAll(".btn-mock-open").forEach((btn) => {
      btn.addEventListener("click", () => openDocument(btn.dataset.ruta, idCaso, `/${btn.dataset.ruta}`));
    });
    list.querySelectorAll(".btn-mock-remove").forEach((btn) => {
      btn.addEventListener("click", () => {
        mockupsDraft = mockupsDraft.filter((r) => r !== btn.dataset.ruta);
        renderMockupsPanel(idCaso, {
          ...data,
          mockups: mockupsDraft.map((ruta) => {
            const prev = (data.mockups || []).find((m) => m.ruta === ruta);
            return prev || { ruta, existe: false, tipo: "mockup-ux" };
          }),
        }, { readonly, statusMsg: "Cambios sin guardar." });
      });
    });

    const sugeridos = data.sugeridos || [];
    if (sugerBox && sugerList) {
      if (sugeridos.length && !readonly) {
        sugerBox.classList.remove("hidden");
        sugerList.innerHTML = sugeridos
          .map(
            (m) =>
              `<li><button type="button" class="btn-mock-suger" data-ruta="${escAttr(m.ruta)}" title="${escAttr(m.ruta)}">${esc(m.titulo || m.ruta)}</button></li>`,
          )
          .join("");
        sugerList.querySelectorAll(".btn-mock-suger").forEach((btn) => {
          btn.addEventListener("click", () => {
            const ruta = normalizeMockupPath(btn.dataset.ruta);
            if (ruta && !mockupsDraft.includes(ruta)) mockupsDraft.push(ruta);
            renderMockupsPanel(
              idCaso,
              {
                ...data,
                mockups: mockupsDraft.map((r) => {
                  const found = sugeridos.find((s) => s.ruta === r) || (data.mockups || []).find((m) => m.ruta === r);
                  return found || { ruta: r, existe: true, tipo: "mockup-ux" };
                }),
                sugeridos,
              },
              { readonly, statusMsg: "Agregado. Pulse Guardar adjuntos." },
            );
          });
        });
      } else {
        sugerBox.classList.add("hidden");
        sugerList.innerHTML = "";
      }
    }
  }

  function bindMockupsPanel(getIdCaso) {
    const input = document.getElementById("chatMockupInput");
    const btnAdd = document.getElementById("btnChatMockupAdd");
    const btnScan = document.getElementById("btnChatMockupScan");
    const btnGen = document.getElementById("btnChatMockupGenerar");
    const btnSave = document.getElementById("btnChatMockupsGuardar");
    const selPlant = document.getElementById("chatMockupPlantilla");

    btnAdd?.addEventListener("click", () => {
      const idCaso = getIdCaso();
      const ruta = normalizeMockupPath(input?.value);
      if (!ruta || !idCaso) return;
      if (!mockupsDraft.includes(ruta)) mockupsDraft.push(ruta);
      if (input) input.value = "";
      renderMockupsPanel(
        idCaso,
        {
          mockups: mockupsDraft.map((r) => ({ ruta, existe: true, tipo: "mockup-ux" })),
          correoHint: `Dictamen + ${mockupsDraft.length} mockup(s) al enviar`,
        },
        { statusMsg: "Agregado. Pulse Guardar adjuntos." },
      );
    });

    input?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        btnAdd?.click();
      }
    });

    selPlant?.addEventListener("change", () => {
      const ruta = normalizeMockupPath(selPlant.value);
      if (!ruta) return;
      if (input) input.value = ruta;
      selPlant.value = "";
    });

    document.getElementById("btnChatMockupAbrir")?.addEventListener("click", () => {
      const idCaso = getIdCaso();
      if (!idCaso) return;
      const abiertos = (mockupsPanelLastData.mockups || []).filter((m) => m.existe !== false && m.ruta);
      const pick = abiertos[0];
      if (!pick) return;
      const url = pick.url || `/${pick.ruta.replace(/^\//, "")}`;
      openDocument(pick.ruta, idCaso, url);
      if (window.QrysApp?.abrirMockupForm) {
        window.QrysApp.abrirMockupForm(pick.ruta);
      }
    });

    btnGen?.addEventListener("click", async () => {
      const idCaso = getIdCaso();
      if (!idCaso) return;
      const notasEl = document.getElementById("notasMockups");
      const mockupsNotas = notasEl?.value?.trim() || "";
      const statusEl = document.getElementById("chatMockupsStatus");
      if (statusEl) statusEl.textContent = "Generando mockups…";
      const result = await generarMockups(idCaso, { mockupsNotas });
      if (!result.ok) {
        renderMockupsPanel(idCaso, { mockups: [] }, { statusMsg: result.error || "Error al generar." });
        return;
      }
      renderMockupsPanel(idCaso, result, { statusMsg: "Mockup alineado a la propuesta de desarrollo." });
      const docs = await fetchDocumentos(idCaso);
      renderDocumentList(document.getElementById("chatDocumentList"), docs, idCaso);
      if (window.QrysApp && typeof window.QrysApp.refreshMockupsForm === "function") {
        window.QrysApp.refreshMockupsForm(idCaso);
      }
    });

    btnScan?.addEventListener("click", async () => {
      const idCaso = getIdCaso();
      if (!idCaso) return;
      const data = await fetchMockups(idCaso, true);
      renderMockupsPanel(idCaso, data, { statusMsg: data.sugeridos?.length ? "Archivos encontrados en disco." : "No hay mockups nuevos en disco." });
    });

    btnSave?.addEventListener("click", async () => {
      const idCaso = getIdCaso();
      if (!idCaso) return;
      const result = await saveMockups(idCaso, mockupsDraft);
      if (!result.ok) {
        renderMockupsPanel(idCaso, { mockups: mockupsDraft.map((r) => ({ ruta: r })) }, { statusMsg: result.error || "Error al guardar." });
        return;
      }
      renderMockupsPanel(idCaso, result, { statusMsg: "Guardado en solicitud.json → contenido.mockups" });
      const docs = await fetchDocumentos(idCaso);
      renderDocumentList(document.getElementById("chatDocumentList"), docs, idCaso);
      if (window.QrysDesarrolladores && typeof window.refreshCorreoEstado === "function") {
        window.refreshCorreoEstado();
      }
    });
  }

  function renderDocumentList(container, documentos, idCaso) {
    if (!container) return;
    currentIdCaso = idCaso || currentIdCaso;
    lastDocsCount = (documentos || []).length;
    updateDocsCountBadge();

    if (!documentos?.length) {
      container.innerHTML = `<li class="chat-doc-empty hint">Sin documentos detectados aún para este caso.</li>`;
      return;
    }

    container.innerHTML = documentos
      .map((doc) => {
        const ruta = escAttr(doc.ruta);
        const url = escAttr(doc.url || "");
        const titulo = esc(doc.titulo || doc.ruta);
        const meta = docTipoMeta(doc.tipo, doc.estado);
        const displayPath = doc.url || doc.ruta;

        return `<li class="chat-doc-card ${meta.cardClass}" tabindex="0" data-ruta="${ruta}" data-url="${url}" title="Clic para abrir en pestaña nueva">
          <div class="doc-card-header">
            <div class="doc-card-icon-title">
              <span class="doc-card-icon" aria-hidden="true">${meta.icon}</span>
              <div class="doc-card-heading">
                <strong class="doc-card-title">${titulo}</strong>
                <span class="doc-card-type">${meta.label}</span>
              </div>
            </div>
            <span class="doc-card-badge ${meta.badgeClass}">${meta.badgeText}</span>
          </div>
          <p class="doc-card-desc">${meta.desc}</p>
          <div class="doc-card-footer">
            <span class="doc-card-path" title="${escAttr(displayPath)}">📁 ${esc(displayPath)}</span>
            <button type="button" class="btn-open-doc-card" data-ruta="${ruta}" data-url="${url}">
              Abrir ↗
            </button>
          </div>
        </li>`;
      })
      .join("");

    function abrirDesdeItem(el) {
      openDocument(el.dataset.ruta, idCaso, el.dataset.url || null);
    }

    container.querySelectorAll(".chat-doc-card").forEach((item) => {
      item.addEventListener("click", (e) => {
        if (e.target.closest(".btn-open-doc-card")) return;
        abrirDesdeItem(item);
      });
      item.addEventListener("dblclick", () => abrirDesdeItem(item));
      item.addEventListener("keydown", (e) => {
        if (e.key === "Enter") abrirDesdeItem(item);
      });
    });

    container.querySelectorAll(".btn-open-doc-card").forEach((btn) => {
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

  function formatChatMessage(texto, idCaso) {
    if (!texto) return "";
    let s = String(texto);

    // 1. Bloques de código ```lang ... ```
    const codeBlocks = [];
    s = s.replace(/```([a-zA-Z0-9_-]*)\r?\n([\s\S]*?)```/g, (_, lang, code) => {
      const idx = codeBlocks.length;
      codeBlocks.push(
        `<pre class="chat-code-block"><code class="language-${escAttr(lang || "text")}">${esc(code.trimEnd())}</code></pre>`,
      );
      return `__CODE_BLOCK_${idx}__`;
    });

    // 2. Código inline `code`
    const inlineCodes = [];
    s = s.replace(/`([^`\n]+)`/g, (_, code) => {
      const idx = inlineCodes.length;
      inlineCodes.push(`<code class="chat-inline-code">${esc(code)}</code>`);
      return `__INLINE_CODE_${idx}__`;
    });

    // 3. Escapar texto general
    s = esc(s);

    // 4. Negritas **texto**
    s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");

    // 5. Cursiva *texto*
    s = s.replace(/(^|[^\*])\*([^*\n]+)\*([^\*]|$)/g, "$1<em>$2</em>$3");

    // 6. Listas con viñetas
    const lines = s.split(/\r?\n/);
    const formattedLines = [];
    let inList = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const bulletMatch = line.match(/^\s*(?:[\*\-•]|\d+\.)\s+(.+)$/);
      if (bulletMatch) {
        if (!inList) {
          formattedLines.push('<ul class="chat-bullets">');
          inList = true;
        }
        formattedLines.push(`<li class="chat-bullet">${bulletMatch[1]}</li>`);
      } else {
        if (inList) {
          formattedLines.push("</ul>");
          inList = false;
        }
        formattedLines.push(line);
      }
    }
    if (inList) {
      formattedLines.push("</ul>");
    }
    s = formattedLines.join("<br>");
    s = s.replace(/<br>\s*<ul/g, "<ul").replace(/<\/ul>\s*<br>/g, "</ul>");

    // 7. Enlazar documentos
    s = linkifyDocuments(s, idCaso);

    // 8. Restaurar bloques de código e inline
    s = s.replace(/__INLINE_CODE_(\d+)__/g, (_, idx) => inlineCodes[Number(idx)] || "");
    s = s.replace(/<br>\s*__CODE_BLOCK_(\d+)__\s*<br>/g, (_, idx) => codeBlocks[Number(idx)] || "");
    s = s.replace(/__CODE_BLOCK_(\d+)__/g, (_, idx) => codeBlocks[Number(idx)] || "");

    return s;
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

    // Copiar mensaje al portapapeles
    container.querySelectorAll(".btn-copy-msg").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const text = btn.dataset.texto || "";
        try {
          await navigator.clipboard.writeText(text);
          const orig = btn.innerHTML;
          btn.innerHTML = "✓ Copiado";
          btn.classList.add("copied");
          setTimeout(() => {
            btn.innerHTML = orig;
            btn.classList.remove("copied");
          }, 1500);
        } catch {
          const ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          ta.remove();
          btn.innerHTML = "✓ Copiado";
          btn.classList.add("copied");
          setTimeout(() => {
            btn.innerHTML = "📋 Copiar";
            btn.classList.remove("copied");
          }, 1500);
        }
      });
    });
  }

  function renderChat(container, mensajes, idCaso, opts) {
    currentIdCaso = idCaso || currentIdCaso;
    bindChatWorkspace();
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
        const badgeRole = m.autor === "agente" ? "agent" : m.autor === "sistema" ? "system" : "user";
        const iconRole = m.autor === "agente" ? "🤖" : m.autor === "sistema" ? "⚙️" : "👤";
        const quien = { agente: "Agente", coordinador: "Coordinador", sistema: "Sistema" }[m.autor] || m.autor;
        const body = formatChatMessage(m.texto, idCaso);
        return `<div class="chat-msg ${cls}">
          <div class="chat-msg-head">
            <div class="chat-msg-author">
              <span class="chat-msg-badge ${badgeRole}">${iconRole} ${esc(quien)}</span>
              <span class="chat-msg-time">${fmtFecha(m.fecha)}</span>
            </div>
            <button type="button" class="btn-copy-msg" data-texto="${escAttr(m.texto)}" title="Copiar texto del mensaje">📋 Copiar</button>
          </div>
          <div class="chat-msg-body">${body}</div>
        </div>`;
      })
      .join("");

    paintChatHtml(container, html, chatSignature(visibles, idCaso), forceBottom);
  }

  let chatWorkspaceBound = false;

  function switchSidePanelTab(tabKey) {
    const tabs = document.querySelectorAll(".chat-side-tab");
    tabs.forEach((t) => {
      t.classList.toggle("active", t.dataset.sideTab === tabKey);
    });

    const paneMap = {
      docs: "paneSideDocs",
      mockups: "paneSideMockups",
      ayuda: "paneSideAyuda",
    };

    document.querySelectorAll(".chat-side-pane").forEach((pane) => {
      pane.classList.remove("active");
    });

    const targetPaneId = paneMap[tabKey] || "paneSideDocs";
    const targetPane = document.getElementById(targetPaneId);
    if (targetPane) targetPane.classList.add("active");
  }

  function bindChatWorkspace() {
    if (chatWorkspaceBound) return;
    chatWorkspaceBound = true;

    const bench = document.getElementById("chatWorkbench");
    const btnToggle = document.getElementById("btnToggleSidePanel");
    const btnClose = document.getElementById("btnCloseSidePanel");
    const btnMax = document.getElementById("btnChatMaximize");
    const btnScroll = document.getElementById("btnScrollToBottom");
    const msgContainer = document.getElementById("chatMessages");
    const btnAbrirDocCerrado = document.getElementById("btnChatCerrarAbrirDoc");
    const btnRefreshDocs = document.getElementById("btnRefreshDocs");

    // 1. Estado inicial del panel lateral según preferencia guardada o ancho de pantalla
    let savedState = null;
    try {
      savedState = localStorage.getItem("qrys_chat_side_open");
    } catch {}

    const shouldOpen = savedState !== null 
      ? savedState === "1" 
      : (window.innerWidth >= 1150);

    setSidePanelState(shouldOpen);

    // Pestañas del panel lateral
    document.querySelectorAll(".chat-side-tab").forEach((tab) => {
      tab.addEventListener("click", () => {
        switchSidePanelTab(tab.dataset.sideTab);
      });
    });

    btnToggle?.addEventListener("click", () => {
      const isOpen = bench?.classList.contains("side-panel-open");
      setSidePanelState(!isOpen);
      if (!isOpen) {
        switchSidePanelTab("docs");
      }
    });

    btnClose?.addEventListener("click", () => {
      setSidePanelState(false);
    });

    btnRefreshDocs?.addEventListener("click", async () => {
      const idCaso = currentIdCaso || getIdCaso();
      if (!idCaso) return;
      btnRefreshDocs.classList.add("btn-spinning");
      try {
        const docs = await fetchDocumentos(idCaso);
        renderDocumentList(document.getElementById("chatDocumentList"), docs, idCaso);
      } finally {
        setTimeout(() => btnRefreshDocs.classList.remove("btn-spinning"), 400);
      }
    });

    // 2. Maximizar / restaurar chat
    btnMax?.addEventListener("click", () => {
      toggleMaximize();
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        const shell = document.querySelector(".chat-shell");
        if (shell?.classList.contains("chat-maximized")) {
          toggleMaximize(false);
        }
      }
    });

    // 3. Scroll to bottom
    if (msgContainer) {
      msgContainer.addEventListener("scroll", () => {
        if (!btnScroll) return;
        const far = msgContainer.scrollHeight - msgContainer.scrollTop - msgContainer.clientHeight > 140;
        btnScroll.classList.toggle("hidden", !far);
      });
    }

    btnScroll?.addEventListener("click", () => {
      if (msgContainer) {
        msgContainer.scrollTo({ top: msgContainer.scrollHeight, behavior: "smooth" });
      }
    });

    // 4. Abrir dictamen cerrado
    btnAbrirDocCerrado?.addEventListener("click", () => {
      const idCaso = currentIdCaso || document.getElementById("chatSelectCaso")?.value || "";
      if (!idCaso) return;
      openDocument(`dictamenes/${idCaso}.html`, idCaso);
    });
  }

  function setSidePanelState(open) {
    const bench = document.getElementById("chatWorkbench");
    const btnToggle = document.getElementById("btnToggleSidePanel");
    if (!bench) return;
    bench.classList.toggle("side-panel-open", !!open);
    bench.classList.toggle("side-panel-closed", !open);
    if (btnToggle) btnToggle.classList.toggle("active", !!open);
    try {
      localStorage.setItem("qrys_chat_side_open", open ? "1" : "0");
    } catch {}
  }

  function toggleMaximize(forceVal) {
    const shell = document.querySelector(".chat-shell");
    const icon = document.getElementById("chatMaxIcon");
    const btn = document.getElementById("btnChatMaximize");
    if (!shell) return;
    const isNow = typeof forceVal === "boolean" 
      ? forceVal 
      : !shell.classList.contains("chat-maximized");
    
    shell.classList.toggle("chat-maximized", isNow);
    if (icon) icon.textContent = isNow ? "🗗" : "⛶";
    if (btn) btn.title = isNow ? "Restaurar tamaño normal" : "Maximizar chat (pantalla completa)";
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
    fetchMockups,
    generarMockups,
    saveMockups,
    sendMessage,
    fetchEstado,
    cerrarFase1,
    renderChat,
    renderDocumentList,
    renderMockupsPanel,
    bindMockupsPanel,
    bindChatWorkspace,
    setSidePanelState,
    toggleMaximize,
    updateDocsCountBadge,
    renderAgentStatus,
    computeAgentStatus,
    openDocument,
    loadLocal,
    listarCasosActivos,
    resolverIdCaso,
    formatMessage: formatChatMessage,
  };
})();
