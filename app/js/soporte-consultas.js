/**
 * Consultas de soporte — pestañas Historial | Nueva | Consulta (estilo solicitudes).
 */
window.QrysSoporteConsultas = (function () {
  const $ = (id) => document.getElementById(id);
  let consultaId = null;
  let servidores = [];
  let bound = false;
  let pollTimer = null;
  let esperandoDocTrasAgente = false;
  let botEstabaTrabajando = false;
  let ultimoAvisoMsgAgente = "";
  let pendingNueva = [];
  let pendingChat = [];

  const PANELS = {
    historial: "scPanelHistorial",
    nueva: "scPanelNueva",
    consulta: "scPanelConsulta",
  };

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function urlImagen(nombre, dataUrl) {
    if (dataUrl) return dataUrl;
    if (!consultaId || !nombre) return "";
    return `/api/soporte-consultas/${encodeURIComponent(consultaId)}/imagen/${encodeURIComponent(nombre)}`;
  }

  function htmlMiniaturas(imagenes, conQuitar) {
    return (imagenes || [])
      .map((img) => {
        const nombre = img.nombre || "captura";
        const src = urlImagen(nombre, img.dataUrl);
        if (!src) return "";
        const quitar = conQuitar
          ? `<button type="button" class="sc-captura-x" data-nombre="${esc(nombre)}" data-local="${esc(img.localId || "")}" title="Quitar">×</button>`
          : "";
        return `<li class="sc-captura-item">${quitar}<a href="${esc(src)}" target="_blank" rel="noopener"><img src="${esc(src)}" alt="${esc(nombre)}"></a><span>${esc(nombre)}</span></li>`;
      })
      .join("");
  }

  function pintarPendientesNueva() {
    const ul = $("scImagenLista");
    const empty = $("scImagenEmpty");
    if (ul) ul.innerHTML = htmlMiniaturas(pendingNueva, true);
    if (empty) empty.hidden = pendingNueva.length > 0;
  }

  function pintarPendientesChat() {
    const ul = $("scChatPendientes");
    if (!ul) return;
    ul.innerHTML = htmlMiniaturas(pendingChat, true);
  }

  function pintarImagenesConsulta(meta) {
    const box = $("scHeadImagenes");
    if (!box) return;
    box.innerHTML = htmlMiniaturas(meta?.imagenes || [], true);
  }

  function leerDataUrl(file) {
    return new Promise((resolve, reject) => {
      if (!file || !String(file.type || "").startsWith("image/")) {
        reject(new Error("Solo se admiten imágenes (PNG, JPG, WebP, GIF)."));
        return;
      }
      if (!/png|jpeg|jpg|webp|gif/i.test(file.type)) {
        reject(new Error("Formato no admitido. Use PNG, JPG, WebP o GIF."));
        return;
      }
      if (file.size > 8 * 1024 * 1024) {
        reject(new Error("La imagen supera 8 MB."));
        return;
      }
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result || ""));
      reader.onerror = () => reject(new Error("No se pudo leer la imagen."));
      reader.readAsDataURL(file);
    });
  }

  function archivosImagen(data) {
    const files = [];
    const items = data?.items ? [...data.items] : [];
    items.forEach((it) => {
      if (it.kind === "file" && String(it.type || "").startsWith("image/")) {
        const f = it.getAsFile();
        if (f) files.push(f);
      }
    });
    if (!files.length && data?.files) {
      [...data.files].forEach((f) => {
        if (String(f.type || "").startsWith("image/")) files.push(f);
      });
    }
    return files;
  }

  async function agregarPendientesNueva(files) {
    for (const file of files) {
      const dataUrl = await leerDataUrl(file);
      pendingNueva.push({
        localId: `${Date.now()}-${pendingNueva.length}`,
        nombre: file.name || `captura-${pendingNueva.length + 1}.png`,
        dataUrl,
      });
    }
    pintarPendientesNueva();
  }

  async function subirImagenConsulta(file) {
    if (!consultaId) throw new Error("Abra la consulta antes de adjuntar la captura.");
    const dataUrl = await leerDataUrl(file);
    const data = await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/imagen`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nombre: file.name || "", dataUrl }),
    });
    pendingChat.push(data.imagen);
    pintarPendientesChat();
    return data.imagen;
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok || data.ok === false) throw new Error(data.error || r.statusText || String(r.status));
    return data;
  }

  function aviso(texto, esError) {
    const el = $("scAviso");
    if (!el) return;
    el.hidden = !texto;
    el.textContent = texto || "";
    el.className = esError ? "alert alert-warning" : "alert";
    ajustarAltura();
  }

  function ajustarAltura() {
    const el = $("scPanelConsulta");
    if (!el || el.classList.contains("hidden")) return;
    requestAnimationFrame(() => {
      const top = el.getBoundingClientRect().top;
      el.style.height = `${Math.max(360, window.innerHeight - top - 16)}px`;
    });
  }

  function showPanel(name) {
    Object.keys(PANELS).forEach((key) => {
      const panel = $(PANELS[key]);
      if (panel) panel.classList.toggle("hidden", key !== name);
    });
    document.querySelectorAll("[data-sc-panel]").forEach((btn) => {
      btn.classList.toggle("is-on", btn.dataset.scPanel === name);
    });
    if (name !== "consulta") {
      stopPoll();
    } else {
      ajustarAltura();
      if (consultaId) startPoll();
    }
  }

  function setConsultaTabEnabled(on) {
    const tab = $("scTabConsulta");
    if (tab) tab.disabled = !on;
  }

  function pintarEstadoBot(bot) {
    const box = $("scEstadoAgente");
    const label = $("scEstadoAgenteLabel");
    const detail = $("scEstadoAgenteDetail");
    if (!box || !label) return;
    if (!bot || !bot.estado) {
      box.classList.add("hidden");
      habilitarControlesChat(true);
      return;
    }
    const st = bot.estado;
    box.classList.remove("hidden", "is-working", "is-error");
    
    // Verificar si el heartbeat está obsoleto (más de 30s sin actualizar)
    const heartbeatStale = bot.heartbeatEn 
      ? (Date.now() - new Date(bot.heartbeatEn).getTime()) > 30000
      : false;
    
    const trabajando = (st === "trabajando" && bot.pidVivo && !heartbeatStale);
    
    if (trabajando) {
      box.classList.add("is-working");
      label.textContent = "Agente trabajando";
      if (detail) detail.textContent = "El chat se actualiza solo.";
      habilitarControlesChat(false);
      return;
    }
    
    // Si el heartbeat está obsoleto, considerar el proceso colgado
    if (st === "trabajando" && heartbeatStale) {
      box.classList.add("is-error");
      label.textContent = "Proceso sin respuesta";
      if (detail) detail.textContent = "El agente no responde. Recargue la página.";
      habilitarControlesChat(true);
      return;
    }
    
    if (st === "listo") {
      label.textContent = "Agente listo";
      if (detail) detail.textContent = "Puede escribir o pedir un ajuste.";
      habilitarControlesChat(true);
      return;
    }
    if (st === "error" || st === "sin_clave") {
      box.classList.add("is-error");
      label.textContent = st === "sin_clave" ? "Falta API key" : "Agente con error";
      if (detail) detail.textContent = bot.error || "Revise bot.log y .env";
      habilitarControlesChat(true);
      return;
    }
    box.classList.add("hidden");
    habilitarControlesChat(true);
  }

  function habilitarControlesChat(habilitar) {
    const btn = $("scBtnChatEnviar");
    const ajuste = $("scBtnPedirAgente");
    const input = $("scChatInput");
    const img = $("scBtnAdjuntar");
    const analisis = $("scBtnAnalisis");
    const ilu = $("scBtnIlustracion");
    const req = $("scBtnRequerimiento");
    if (btn) btn.disabled = !habilitar;
    if (ajuste) ajuste.disabled = !habilitar;
    if (input) {
      input.disabled = !habilitar;
      // Bloquear paste/drop mientras esté deshabilitado
      if (!habilitar) {
        input.dataset.bloqueado = "1";
      } else {
        delete input.dataset.bloqueado;
      }
    }
    if (img) img.disabled = !habilitar;
    if (analisis) analisis.disabled = !habilitar;
    if (ilu) ilu.disabled = !habilitar;
    if (req) req.disabled = !habilitar;
  }

  function formatChatBody(texto) {
    if (!texto) return "";
    if (window.QrysChat && typeof window.QrysChat.formatMessage === "function") {
      return window.QrysChat.formatMessage(texto, consultaId || "");
    }
    return esc(texto).replace(/\n/g, "<br>");
  }

  const MSG_LARGO = 650;
  let firmaChat = "";
  const msgAbiertos = new Set();

  function fmtHora(v) {
    const s = String(v || "");
    const m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(s);
    return m ? `${m[3]}/${m[2]} ${m[4]}:${m[5]}` : s;
  }

  function cercaDelFinal(box) {
    return box.scrollHeight - box.scrollTop - box.clientHeight < 80;
  }

  function pintarChat(mensajes, forzarAbajo) {
    const box = $("scChatMensajes");
    if (!box) return;
    const list = mensajes || [];
    const ult = list[list.length - 1];
    const firma = `${consultaId}|${list.length}|${ult ? ult.id || ult.en || "" : ""}|${ult ? (ult.texto || "").length : 0}|${ult && ult.imagenes ? ult.imagenes.length : 0}`;
    if (firma === firmaChat && !forzarAbajo) return;
    const primeraVez = !firmaChat.startsWith(`${consultaId}|`);
    const estabaAbajo = cercaDelFinal(box);
    firmaChat = firma;

    if (!list.length) {
      box.innerHTML = '<p class="scw-empty">Sin mensajes. Pulse el botón de análisis para que el agente responda.</p>';
      return;
    }
    box.innerHTML = list
      .map((m, i) => {
        const autor = (m.autor || "soporte").toLowerCase();
        const hora = esc(fmtHora(m.en || m.fecha));
        const texto = m.texto || "";
        if (autor === "sistema") {
          return `<div class="scw-msg-sys" title="${esc(texto)}"><span>${esc(texto)}</span><time>${hora}</time></div>`;
        }
        const key = String(m.id || i);
        const largo = texto.length > MSG_LARGO;
        const abierto = msgAbiertos.has(key);
        const lado = autor === "agente" ? "in" : "out";
        return `<article class="scw-msg scw-msg-${lado}${largo ? " is-long" : ""}${abierto ? " is-open" : ""}" data-key="${esc(key)}">
          <header><strong>${esc(autor)}</strong><time>${hora}</time></header>
          <div class="scw-msg-body chat-body">${formatChatBody(texto)}</div>
          ${m.imagenes && m.imagenes.length ? `<ul class="sc-captura-lista">${htmlMiniaturas(m.imagenes, false)}</ul>` : ""}
          ${largo ? `<button type="button" class="scw-more">${abierto ? "Ver menos" : "Ver completo"}</button>` : ""}
        </article>`;
      })
      .join("");

    const jump = $("scBtnIrAbajo");
    if (primeraVez || forzarAbajo || estabaAbajo) {
      box.scrollTop = box.scrollHeight;
      jump?.classList.add("hidden");
    } else {
      jump?.classList.remove("hidden");
    }
  }

  function autoAltoInput() {
    const t = $("scChatInput");
    if (!t) return;
    t.style.height = "auto";
    t.style.height = `${Math.min(160, t.scrollHeight)}px`;
  }

  function textoProposito(data) {
    const meta = data.meta || {};
    const manual = (meta.proposito || "").trim();
    if (manual) return manual;
    return (data.propositoDocumento || "").trim();
  }

  function pintarCabecera(data) {
    const meta = data.meta || {};
    const wt = $("scWorkspaceTitulo");
    if (wt) wt.textContent = meta.titulo || "Consulta";
    const wm = $("scWorkspaceMeta");
    if (wm) {
      const base = meta.validarEnBase && meta.baseDatos
        ? `Validación solo lectura · ${meta.servidorNombre || meta.servidorId || "Servidor"} · ${meta.baseDatos}`
        : "";
      wm.textContent = [meta.id, meta.cliente, base, meta.estado].filter(Boolean).join(" · ") || "—";
    }
    const corta = $("scHeadPreguntaCorta");
    if (corta) corta.textContent = (meta.preguntaInicial || "").replace(/\s+/g, " ").trim();
    const tab = $("scTabConsulta");
    if (tab && consultaId) tab.textContent = meta.titulo ? `Consulta: ${meta.titulo.slice(0, 28)}${meta.titulo.length > 28 ? "…" : ""}` : "Consulta";

    const sol = $("scHeadSolicitante");
    if (sol) sol.textContent = meta.solicitante || "—";
    const preg = $("scHeadPregunta");
    if (preg) preg.textContent = meta.preguntaInicial || "";
    pintarImagenesConsulta(meta);
    const prop = $("scHeadProposito");
    if (prop) {
      const t = textoProposito(data);
      prop.textContent = t || "— (al generar documento)";
    }
    const side = $("scMetaResumen");
    if (side) {
      side.textContent = meta.documentoGenerado ? `Documento ${fmtHora(meta.documentoGenerado)}` : "Sin documento";
      side.title = meta.pdfGenerado ? `PDF: ${meta.pdfGenerado}` : "";
    }
    const ver = $("scBtnVer");
    const pdf = $("scBtnPdf");
    const gen = $("scBtnGenerarDoc");
    const tieneResp = !!(meta.respuestaOficial || "").trim();
    if (ver) ver.disabled = !meta.documentoGenerado;
    if (pdf) pdf.disabled = !tieneResp;
    if (gen) gen.disabled = !tieneResp;
    const req = $("scBtnRequerimiento");
    if (req) {
      const sidSr = (meta.solicitudId || "").trim();
      req.dataset.solicitud = sidSr;
      req.title = sidSr
        ? `Abrir la solicitud ${sidSr}`
        : "Crear solicitud de requerimiento para el comité";
      const label = req.querySelector(".sc-req-label");
      if (label) label.textContent = sidSr ? "Ver requerimiento" : "Requerimiento";
    }
  }

  async function generarRequerimiento() {
    if (!consultaId) return;
    const btn = $("scBtnRequerimiento");
    const ya = (btn?.dataset.solicitud || "").trim();
    if (!ya && !confirm("Se creará una solicitud de requerimiento para el comité con el contenido de esta consulta. ¿Continuar?")) {
      return;
    }
    if (btn) btn.disabled = true;
    try {
      const data = await fetchJson(
        `/api/soporte-consultas/${encodeURIComponent(consultaId)}/requerimiento`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" },
      );
      const sol = data.solicitud || {};
      const id = sol.id || "";
      if (btn && id) {
        btn.dataset.solicitud = id;
        const label = btn.querySelector(".sc-req-label");
        if (label) label.textContent = "Ver requerimiento";
        btn.title = `Abrir la solicitud ${id}`;
      }
      aviso(data.yaExistia ? `La solicitud ${id} ya existía. Se abre.` : `Solicitud ${id} creada.`);
      if (id && window.QrysConocimiento && window.QrysSolicitar?.abrir) {
        window.QrysConocimiento.enterMode("solicitar");
        await window.QrysSolicitar.abrir(id);
      }
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function stopPoll() {
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
  }

  function startPoll() {
    stopPoll();
    if (!consultaId) return;
    pollTimer = setInterval(() => {
      refrescarPanel().catch(() => {});
    }, 3500);
  }

  async function generarDocumento(silencioso) {
    if (!consultaId) return;
    if (!silencioso) aviso("Generando el documento con el texto del agente. Puede tardar un minuto.");
    await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/documento`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    await cargarLista();
    const panel = await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/panel`);
    pintarCabecera(panel);
    if (!silencioso) aviso("Documento listo.");
  }

  async function refrescarPanel() {
    if (!consultaId) return;
    const data = await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/panel`);
    pintarCabecera(data);
    pintarChat(data.mensajes);
    pintarEstadoBot(data.bot);
    const trabajando = !!(data.bot && data.bot.estado === "trabajando" && data.bot.pidVivo);
    if (trabajando) {
      botEstabaTrabajando = true;
      return;
    }
    if (botEstabaTrabajando && esperandoDocTrasAgente && data.bot && data.bot.estado === "error") {
      botEstabaTrabajando = false;
      esperandoDocTrasAgente = false;
      aviso(data.bot.error || "El agente falló.", true);
      return;
    }
    if (botEstabaTrabajando && esperandoDocTrasAgente) {
      botEstabaTrabajando = false;
      esperandoDocTrasAgente = false;
      if ((data.meta.respuestaOficial || "").trim()) {
        try {
          await generarDocumento(true);
          aviso("Documento regenerado tras el ajuste del agente.");
        } catch (e) {
          aviso(e.message, true);
        }
      }
      return;
    }
    botEstabaTrabajando = false;
    const ult = (data.mensajes || []).slice(-1)[0];
    const mid = ult && ult.id ? String(ult.id) : "";
    if (ult && ult.autor === "agente" && !esperandoDocTrasAgente && mid && mid !== ultimoAvisoMsgAgente) {
      ultimoAvisoMsgAgente = mid;
      aviso("El agente respondió. Pulse «Generar documento» para validarlo.");
    }
  }

  async function generarIlustracion() {
    if (!consultaId) return;
    
    const btn = $("scGenerarIlustracion");
    if (!btn) return;
    
    const textoOriginal = btn.textContent;
    btn.disabled = true;
    btn.textContent = "Generando...";
    
    try {
      const resp = await fetch(`/api/soporte-consultas/${consultaId}/ilustracion`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt: "" })
      });
      
      const data = await resp.json();
      
      if (data.ok) {
        aviso(`Ilustración generada: ${data.total || 1} imagen(es) con OpenAI.`);
        await cargarPanel();
      } else if (data.usarCursor) {
        aviso("Para casos de capacitación, genere las ilustraciones con el agente de Cursor.", true);
      } else {
        aviso(data.mensaje || "Error generando ilustración", true);
      }
    } catch (e) {
      aviso("La ilustración la arma el modelo de imagen de Cursor, en el agente.", true);
    } finally {
      btn.disabled = false;
      btn.textContent = textoOriginal;
    }
  }

  async function cargarLista() {
    const body = $("scConsultasBody");
    if (!body) return;
    try {
      const data = await fetchJson("/api/soporte-consultas/consultas");
      const rows = data.consultas || [];
      if (!rows.length) {
        body.innerHTML = '<tr><td colspan="6">Sin consultas. Use «Nueva consulta».</td></tr>';
        return;
      }
      body.innerHTML = rows
        .map(
          (c) => `<tr>
          <td><code>${esc(c.id)}</code></td>
          <td>${esc(c.titulo)}</td>
          <td>${esc(c.solicitante || "—")}</td>
          <td>${esc(c.cliente || "—")}</td>
          <td>${esc(c.estado)}</td>
          <td style="text-align:right"><button type="button" class="btn btn-secondary btn-sm sc-abrir" data-id="${esc(c.id)}">Abrir</button></td>
        </tr>`
        )
        .join("");
      body.querySelectorAll(".sc-abrir").forEach((btn) => {
        btn.addEventListener("click", () => abrirConsulta(btn.getAttribute("data-id")));
      });
    } catch (e) {
      body.innerHTML = `<tr><td colspan="6">${esc(e.message)}</td></tr>`;
    }
  }

  async function abrirConsulta(sid) {
    if (!sid) return;
    consultaId = sid;
    esperandoDocTrasAgente = false;
    botEstabaTrabajando = false;
    ultimoAvisoMsgAgente = "";
    firmaChat = "";
    msgAbiertos.clear();
    if ($("scContexto")) $("scContexto").open = false;
    aviso("");
    setConsultaTabEnabled(true);
    showPanel("consulta");
    await refrescarPanel();
  }

  async function cargarServidores() {
    const sel = $("scServidor");
    if (!sel || sel.dataset.listo === "1") return;
    const data = await fetchJson("/api/informe-contab/servidores");
    servidores = data.servidores || [];
    servidores.forEach((s) => {
      const opt = document.createElement("option");
      opt.value = s.id || "";
      opt.textContent = s.nombre || s.id;
      sel.appendChild(opt);
    });
    sel.dataset.listo = "1";
    sel.onchange = () => pintarBases(sel.value);
    pintarBases(sel.value);
  }

  function baseElegida() {
    const otra = ($("scBaseOtra")?.value || "").trim();
    if (otra) return otra;
    return ($("scBase")?.value || "").trim();
  }

  function toggleValidarBd() {
    const on = !!$("scValidarBd")?.checked;
    const box = $("scValidarBdBox");
    if (box) box.hidden = !on;
    if (box) box.style.display = on ? "" : "none";
    if (on) cargarServidores().catch((e) => aviso(e.message, true));
  }

  function pintarBases(servidorId) {
    const sel = $("scBase");
    if (!sel) return;
    const srv = servidores.find((s) => s.id === servidorId) || {};
    const bases = srv.bases && srv.bases.length ? srv.bases : srv.baseDatosDefault ? [srv.baseDatosDefault] : [];
    sel.innerHTML = "";
    if (!servidorId) {
      sel.disabled = true;
      return;
    }
    sel.disabled = false;
    bases.forEach((b) => {
      const opt = document.createElement("option");
      opt.value = b;
      opt.textContent = b;
      sel.appendChild(opt);
    });
    if (srv.baseDatosDefault) sel.value = srv.baseDatosDefault;
  }

  async function nuevaConsulta() {
    const titulo = ($("scTitulo")?.value || "").trim();
    const solicitante = ($("scSolicitante")?.value || "").trim();
    const cliente = ($("scCliente")?.value || "").trim();
    const validarEnBase = !!$("scValidarBd")?.checked;
    const servidorId = validarEnBase ? ($("scServidor")?.value || "").trim() : "";
    const baseDatos = validarEnBase ? baseElegida() : "";
    if (validarEnBase && (!servidorId || !baseDatos)) {
      aviso("Indique el servidor y la base. La validación es solo lectura.", true);
      showPanel("nueva");
      return;
    }
    let pregunta = ($("scPregunta")?.value || "").trim();
    if (!titulo || (!pregunta && !pendingNueva.length)) {
      aviso("Indique el título y la pregunta, o pegue una captura.", true);
      showPanel("nueva");
      return;
    }
    if (!pregunta) pregunta = "Ver captura adjunta.";
    aviso("Creando consulta…");
    const data = await fetchJson("/api/soporte-consultas/consulta", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ titulo, solicitante, cliente, pregunta, validarEnBase, servidorId, baseDatos }),
    });
    const sid = data.meta.id;
    const porSubir = pendingNueva.slice();
    pendingNueva = [];
    pintarPendientesNueva();
    if ($("scPregunta")) $("scPregunta").value = "";
    if ($("scTitulo")) $("scTitulo").value = "";
    if ($("scValidarBd")) $("scValidarBd").checked = false;
    if ($("scBaseOtra")) $("scBaseOtra").value = "";
    toggleValidarBd();
    for (const img of porSubir) {
      await fetchJson(`/api/soporte-consultas/${encodeURIComponent(sid)}/imagen`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: img.nombre, dataUrl: img.dataUrl }),
      });
    }
    await cargarLista();
    await abrirConsulta(sid);
    const mensaje = porSubir.length 
      ? `Consulta creada con ${porSubir.length} captura(s). Pulse el análisis.`
      : "Consulta creada. Pulse el análisis.";
    aviso(mensaje);
  }

  async function enviarChat() {
    if (!consultaId) return;
    const input = $("scChatInput");
    const autor = ($("scChatAutor")?.value || "soporte").trim();
    const texto = (input?.value || "").trim();
    const imagenes = pendingChat.map((img) => ({ nombre: img.nombre }));
    if (!texto && !imagenes.length) return;
    const data = await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ texto, autor, imagenes }),
    });
    if (input) input.value = "";
    pendingChat = [];
    pintarPendientesChat();
    autoAltoInput();
    pintarChat(data.mensajes, true);
    await refrescarPanel();
  }

  async function lanzarAnalisis() {
    if (!consultaId) {
      aviso("Abra una consulta desde Historial.", true);
      return;
    }
    aviso("Lanzando agente…");
    $("scBtnAnalisis") && ($("scBtnAnalisis").disabled = true);
    try {
      await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/analisis`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      botEstabaTrabajando = false;
      esperandoDocTrasAgente = false;
      await refrescarPanel();
      startPoll();
      aviso("Agente en marcha.");
    } catch (e) {
      aviso(e.message, true);
    } finally {
      $("scBtnAnalisis") && ($("scBtnAnalisis").disabled = false);
    }
  }

  async function pedirAjusteAgente() {
    if (!consultaId) return;
    const input = $("scChatInput");
    const texto = (input?.value || "").trim();
    const imagenes = pendingChat.map((img) => ({ nombre: img.nombre }));
    if (!texto && !imagenes.length) {
      aviso("Escriba qué debe ajustar el agente o adjunte una captura.", true);
      return;
    }
    esperandoDocTrasAgente = true;
    botEstabaTrabajando = false;
    aviso("Pidiendo ajuste…");
    try {
      await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/agente`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ texto, imagenes }),
      });
      if (input) input.value = "";
      pendingChat = [];
      pintarPendientesChat();
      autoAltoInput();
      firmaChat = "";
      await refrescarPanel();
      startPoll();
      aviso("Agente ajustando; al terminar se regenera el documento.");
    } catch (e) {
      esperandoDocTrasAgente = false;
      aviso(e.message, true);
    }
  }

  async function descargarPdf() {
    if (!consultaId) return;
    aviso("Generando PDF…");
    try {
      const r = await fetch(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/pdf`, { method: "POST" });
      if (!r.ok) {
        let msg = `Error ${r.status}`;
        try {
          const j = await r.json();
          if (j.error) msg = j.error;
        } catch {
          msg = (await r.text()).slice(0, 200) || msg;
        }
        throw new Error(msg);
      }
      const blob = await r.blob();
      const disp = r.headers.get("Content-Disposition") || "";
      const m = /filename="([^"]+)"/i.exec(disp);
      const nombre = m ? m[1] : `soporte-${consultaId}.pdf`;
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = nombre;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      await refrescarPanel();
      await cargarLista();
      aviso("PDF descargado.");
    } catch (e) {
      aviso(e.message, true);
    }
  }

  async function cerrarConsulta() {
    if (!consultaId) return;
    if (!confirm("¿Cerrar esta consulta?")) return;
    try {
      await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/cerrar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      await cargarLista();
      await refrescarPanel();
      aviso("Consulta cerrada.");
    } catch (e) {
      aviso(e.message, true);
    }
  }

  function bindOnce() {
    if (bound) return;
    bound = true;

    document.querySelectorAll("[data-sc-panel]").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (btn.disabled) return;
        const p = btn.dataset.scPanel;
        if (p === "consulta" && !consultaId) return;
        showPanel(p);
        if (p === "nueva") toggleValidarBd();
      });
    });

    $("scBtnIlustracion")?.addEventListener("click", () => generarIlustracion());
    $("scBtnIrNueva")?.addEventListener("click", () => {
      showPanel("nueva");
      toggleValidarBd();
    });
    $("scValidarBd")?.addEventListener("change", toggleValidarBd);
    $("scBtnNuevaCancelar")?.addEventListener("click", () => showPanel("historial"));
    $("scBtnVolverHistorial")?.addEventListener("click", () => {
      stopPoll();
      showPanel("historial");
      cargarLista().catch(() => {});
    });

    $("scBtnNueva")?.addEventListener("click", () => nuevaConsulta().catch((e) => aviso(e.message, true)));
    $("scBtnAnalisis")?.addEventListener("click", () => lanzarAnalisis());
    $("scBtnChatEnviar")?.addEventListener("click", () => enviarChat().catch((e) => aviso(e.message, true)));
    $("scBtnPedirAgente")?.addEventListener("click", () => pedirAjusteAgente());
    $("scBtnRefrescarChat")?.addEventListener("click", () =>
      refrescarPanel().catch((e) => aviso(e.message, true))
    );
    $("scChatInput")?.addEventListener("input", autoAltoInput);
    const box = $("scChatMensajes");
    box?.addEventListener("click", (ev) => {
      const btn = ev.target.closest(".scw-more");
      if (!btn) return;
      const art = btn.closest(".scw-msg");
      const key = art?.dataset.key;
      if (!art || !key) return;
      const abrir = !art.classList.contains("is-open");
      art.classList.toggle("is-open", abrir);
      btn.textContent = abrir ? "Ver menos" : "Ver completo";
      if (abrir) msgAbiertos.add(key);
      else msgAbiertos.delete(key);
    });
    box?.addEventListener("scroll", () => {
      if (cercaDelFinal(box)) $("scBtnIrAbajo")?.classList.add("hidden");
    });
    $("scBtnIrAbajo")?.addEventListener("click", () => {
      if (box) box.scrollTop = box.scrollHeight;
      $("scBtnIrAbajo")?.classList.add("hidden");
    });
    window.addEventListener("resize", ajustarAltura);
    $("scChatInput")?.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" && !ev.shiftKey) {
        ev.preventDefault();
        enviarChat().catch((e) => aviso(e.message, true));
      }
    });
    $("scBtnRequerimiento")?.addEventListener("click", () =>
      generarRequerimiento().catch((e) => aviso(e.message, true)),
    );
    $("scBtnGenerarDoc")?.addEventListener("click", () =>
      generarDocumento(false).catch((e) => aviso(e.message, true))
    );
    $("scBtnPdf")?.addEventListener("click", () => descargarPdf());
    $("scBtnVer")?.addEventListener("click", () => {
      if (consultaId) window.open(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/html`, "_blank", "noopener");
    });
    $("scBtnCerrar")?.addEventListener("click", () => cerrarConsulta().catch((e) => aviso(e.message, true)));

    async function tomarArchivos(files, destino) {
      try {
        if (destino === "nueva") await agregarPendientesNueva(files);
        else {
          for (const file of files) await subirImagenConsulta(file);
          await refrescarPanel();
        }
      } catch (e) {
        aviso(e.message, true);
      }
    }

    function onPegar(ev, destino) {
      const input = ev.target;
      if (input && input.dataset.bloqueado === "1") {
        ev.preventDefault();
        return;
      }
      const files = archivosImagen(ev.clipboardData);
      if (!files.length) return;
      ev.preventDefault();
      tomarArchivos(files, destino);
    }

    $("scPregunta")?.addEventListener("paste", (ev) => onPegar(ev, "nueva"));
    $("scImagenDrop")?.addEventListener("paste", (ev) => onPegar(ev, "nueva"));
    $("scChatInput")?.addEventListener("paste", (ev) => onPegar(ev, "chat"));
    ["scImagenDrop", "scPregunta"].forEach((id) => {
      const el = $(id);
      if (!el) return;
      el.addEventListener("dragover", (ev) => {
        ev.preventDefault();
        el.classList.add("is-dragover");
      });
      el.addEventListener("dragleave", () => el.classList.remove("is-dragover"));
      el.addEventListener("drop", (ev) => {
        el.classList.remove("is-dragover");
        const files = archivosImagen(ev.dataTransfer);
        if (!files.length) return;
        ev.preventDefault();
        tomarArchivos(files, "nueva");
      });
    });
    $("scBtnElegirImagen")?.addEventListener("click", () => $("scInputImagen")?.click());
    $("scInputImagen")?.addEventListener("change", () => {
      const input = $("scInputImagen");
      const files = [...(input?.files || [])];
      if (input) input.value = "";
      if (files.length) tomarArchivos(files, "nueva");
    });
    $("scBtnAdjuntar")?.addEventListener("click", () => $("scChatInputImagen")?.click());
    $("scChatInputImagen")?.addEventListener("change", () => {
      const input = $("scChatInputImagen");
      const files = [...(input?.files || [])];
      if (input) input.value = "";
      if (files.length) tomarArchivos(files, "chat");
    });
    document.addEventListener("click", (ev) => {
      const btn = ev.target.closest?.(".sc-captura-x");
      if (!btn || !btn.closest("#view-soporte-consultas")) return;
      ev.preventDefault();
      const local = btn.dataset.local || "";
      const nombre = btn.dataset.nombre || "";
      if (local) {
        pendingNueva = pendingNueva.filter((img) => img.localId !== local);
        pintarPendientesNueva();
        return;
      }
      if (!nombre || !consultaId) return;
      if (!confirm(`¿Quitar la captura «${nombre}»?`)) return;
      fetchJson(
        `/api/soporte-consultas/${encodeURIComponent(consultaId)}/imagen/${encodeURIComponent(nombre)}`,
        { method: "DELETE" },
      )
        .then((data) => {
          pendingChat = pendingChat.filter((img) => img.nombre !== nombre);
          pintarPendientesChat();
          pintarImagenesConsulta(data.meta || {});
          if (data.mensajes) pintarChat(data.mensajes, false);
        })
        .catch((e) => aviso(e.message, true));
    });
    pintarPendientesNueva();
  }

  function enter() {
    bindOnce();
    setConsultaTabEnabled(!!consultaId);
    showPanel(consultaId ? "consulta" : "historial");
    cargarLista().catch((e) => aviso(e.message, true));
    if (consultaId) refrescarPanel().catch(() => {});
  }

  return { enter, stopPoll };
})();
