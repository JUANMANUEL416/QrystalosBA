/**
 * Consultas de soporte — pestañas Historial | Nueva | Consulta (estilo solicitudes).
 */
window.QrysSoporteConsultas = (function () {
  const $ = (id) => document.getElementById(id);
  let consultaId = null;
  let bound = false;
  let pollTimer = null;
  let esperandoDocTrasAgente = false;
  let botEstabaTrabajando = false;
  let ultimoAvisoMsgAgente = "";

  const PANELS = {
    historial: "scPanelHistorial",
    nueva: "scPanelNueva",
    consulta: "scPanelConsulta",
  };

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
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
      return;
    }
    const st = bot.estado;
    box.classList.remove("hidden", "is-working", "is-error");
    if (st === "trabajando" && bot.pidVivo) {
      box.classList.add("is-working");
      label.textContent = "Agente trabajando";
      if (detail) detail.textContent = "El chat se actualiza solo.";
      return;
    }
    if (st === "listo") {
      label.textContent = "Agente listo";
      if (detail) detail.textContent = "Puede escribir o pedir un ajuste.";
      return;
    }
    if (st === "error" || st === "sin_clave") {
      box.classList.add("is-error");
      label.textContent = st === "sin_clave" ? "Falta API key" : "Agente con error";
      if (detail) detail.textContent = bot.error || "Revise bot.log y .env";
      return;
    }
    box.classList.add("hidden");
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
    const firma = `${consultaId}|${list.length}|${ult ? ult.id || ult.en || "" : ""}|${ult ? (ult.texto || "").length : 0}`;
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
    if (wm) wm.textContent = [meta.id, meta.cliente, meta.estado].filter(Boolean).join(" · ") || "—";
    const corta = $("scHeadPreguntaCorta");
    if (corta) corta.textContent = (meta.preguntaInicial || "").replace(/\s+/g, " ").trim();
    const tab = $("scTabConsulta");
    if (tab && consultaId) tab.textContent = meta.titulo ? `Consulta: ${meta.titulo.slice(0, 28)}${meta.titulo.length > 28 ? "…" : ""}` : "Consulta";

    const sol = $("scHeadSolicitante");
    if (sol) sol.textContent = meta.solicitante || "—";
    const preg = $("scHeadPregunta");
    if (preg) preg.textContent = meta.preguntaInicial || "";
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
    if (!silencioso) aviso("Generando documento…");
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

  async function nuevaConsulta() {
    const titulo = ($("scTitulo")?.value || "").trim();
    const solicitante = ($("scSolicitante")?.value || "").trim();
    const cliente = ($("scCliente")?.value || "").trim();
    const pregunta = ($("scPregunta")?.value || "").trim();
    if (!titulo || !pregunta) {
      aviso("Título y pregunta inicial son obligatorios.", true);
      showPanel("nueva");
      return;
    }
    aviso("Creando consulta…");
    const data = await fetchJson("/api/soporte-consultas/consulta", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ titulo, solicitante, cliente, pregunta }),
    });
    if ($("scPregunta")) $("scPregunta").value = "";
    await cargarLista();
    await abrirConsulta(data.meta.id);
    aviso("Consulta creada. Pulse «Analizar».");
  }

  async function enviarChat() {
    if (!consultaId) return;
    const input = $("scChatInput");
    const autor = ($("scChatAutor")?.value || "soporte").trim();
    const texto = (input?.value || "").trim();
    if (!texto) return;
    const data = await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ texto, autor }),
    });
    if (input) input.value = "";
    autoAltoInput();
    pintarChat(data.mensajes, true);
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
    if (!texto) {
      aviso("Escriba qué debe ajustar el agente.", true);
      return;
    }
    esperandoDocTrasAgente = true;
    botEstabaTrabajando = false;
    aviso("Pidiendo ajuste…");
    try {
      await fetchJson(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/agente`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ texto }),
      });
      if (input) input.value = "";
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
      });
    });

    $("scBtnIrNueva")?.addEventListener("click", () => showPanel("nueva"));
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
    $("scBtnGenerarDoc")?.addEventListener("click", () =>
      generarDocumento(false).catch((e) => aviso(e.message, true))
    );
    $("scBtnPdf")?.addEventListener("click", () => descargarPdf());
    $("scBtnVer")?.addEventListener("click", () => {
      if (consultaId) window.open(`/api/soporte-consultas/${encodeURIComponent(consultaId)}/html`, "_blank", "noopener");
    });
    $("scBtnCerrar")?.addEventListener("click", () => cerrarConsulta().catch((e) => aviso(e.message, true)));
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
