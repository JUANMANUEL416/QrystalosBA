/**
 * Menú central — Analista / Consultas / Documentar (base de procesos).
 */
window.QrysConocimiento = (function () {
  const MODE_KEY = "qrystalos_ba_modo";
  const DOC_PROC_KEY = "qrystalos_ba_doc_proceso";
  let cache = null;
  let caches = { consultas: null, documentar: null };
  let procesoActual = null;
  let chatPoll = null;
  const kbTimers = { consultas: null, documentar: null };
  const MODE_META = {
    analista: {
      icon: "assignment",
      title: "Analista de negocio",
      desc: "Cola, casos, Chat del requerimiento y dictámenes.",
    },
    solicitar: {
      icon: "assignment_add",
      title: "Solicitar requerimiento",
      desc: "Necesidades para comité y documento HTML.",
    },
    consultas: {
      icon: "travel_explore",
      title: "Consultas",
      desc: "Ubicar capa, control e invariante en procesos documentados.",
    },
    documentar: {
      icon: "edit_note",
      title: "Documentar",
      desc: "Pendientes, SP de hoy y Chat de la base de procesos.",
    },
    capacitacion: {
      icon: "school",
      title: "Capacitación",
      desc: "Bloques modulares tipo rompecabezas para manuales.",
    },
    auditoria: {
      icon: "fact_check",
      title: "Auditoría de procesos",
      desc: "Trazas read-only en BD cliente según flujos documentados.",
    },
    "revisar-sql": {
      icon: "rule",
      title: "Revisar SQL",
      desc: "Estructura, diferencia de versiones y efectos del cambio.",
    },
    agentes: {
      icon: "smart_toy",
      title: "Panel de agentes",
      desc: "Asigne si cada agente corre en local o en Cursor.",
    },
    servidores: {
      icon: "dns",
      title: "Servidores",
      desc: "Bases de datos, usuario y clave. El acceso pide usuario y clave de la oficina.",
    },
    "informe-contab": {
      icon: "summarize",
      title: "Informe contable + DIAN",
      desc: "Errores MCPE, KMCOM, DIAN vs contabilidad — documento para soporte.",
    },
    "soporte-consultas": {
      icon: "forum",
      title: "Consultas soporte",
      desc: "Chat, respuesta oficial y PDF de evidencia para el equipo.",
    },
    "prueba-req": {
      icon: "science",
      title: "Prueba req",
      desc: "Contrasta la entrega del desarrollador y cierra con entrega o devolución.",
    },
    capacitacion: {
      icon: "school",
      title: "Capacitación",
      desc: "Sistema modular tipo rompecabezas: seleccione bloques y genere el manual completo.",
    },
  };
  const ESTADO_UI = {
    consultas: {
      box: "#consultaChatEstado",
      label: "#consultaChatEstadoLabel",
      detail: "#consultaChatEstadoDetail",
      timer: "#consultaChatTimer",
      input: "#consultaChatInput",
    },
    documentar: {
      box: "#docChatEstado",
      label: "#docChatEstadoLabel",
      detail: "#docChatEstadoDetail",
      timer: "#docChatTimer",
      input: "#docChatInput",
    },
  };
  let pagePanel = { consultas: "trabajo", documentar: "trabajo" };
  let chatProceso = { consultas: "", documentar: "" };

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

  function procesoGuardado() {
    try {
      return sessionStorage.getItem(DOC_PROC_KEY) || "";
    } catch (_) {
      return "";
    }
  }

  function guardarProcesoDoc(pid) {
    try {
      if (pid) sessionStorage.setItem(DOC_PROC_KEY, pid);
    } catch (_) {}
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
    try {
      // Los cerrados viven en pendientes-archivo.json; la vista los sigue mostrando.
      const archivo = await fetchJson("/conocimiento/pendientes-archivo.json");
      pendientes.items = (pendientes.items || []).concat(archivo.items || []);
    } catch (_) {}
    const items = pendientes.items || [];
    return {
      ok: true,
      indice,
      pendientes,
      pendientesAbiertos: items.filter((i) => estaAbierto(i) && colaDe(i) === "fichar").length,
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
    const pid = procesoChatDe(c);
    const q = new URLSearchParams({ canal: c });
    if (pid) q.set("procesoId", pid);
    try {
      const data = await fetchJson(`/api/conocimiento?${q.toString()}`);
      caches[c] = data;
      cache = data;
      if (pid) chatProceso[c] = pid;
      else if (data.chatProcesoId) chatProceso[c] = data.chatProcesoId;
      return data;
    } catch (_) {
      const data = await loadFromDisk(c);
      caches[c] = data;
      cache = data;
      return data;
    }
  }

  function applyModeChrome(mode) {
    const strip = $("#appModeStrip");
    const meta = MODE_META[mode];
    if (!strip || !meta) return;
    strip.hidden = false;
    strip.removeAttribute("hidden");
    const icon = $("#appModeIcon");
    const title = $("#appModeTitle");
    const desc = $("#appModeDesc");
    if (icon) icon.textContent = meta.icon;
    if (title) title.textContent = meta.title;
    if (desc) desc.textContent = meta.desc;
  }

  function hideModeChrome() {
    const strip = $("#appModeStrip");
    if (strip) {
      strip.hidden = true;
      strip.setAttribute("hidden", "");
    }
  }

  function contarPorFichar(data) {
    const items = data?.pendientes?.items || [];
    if (!items.length) return data?.pendientesAbiertos || 0;
    return items.filter((i) => estaAbierto(i) && colaDe(i) === "fichar").length;
  }

  function badgePendientes(n) {
    const el = $("#hubBadgePendientes");
    if (!el) return;
    el.textContent = n ? String(n) : "";
    el.title = n ? n + " por fichar. Defectos y hallazgos del libro van en otras colas de Documentar." : "";
    el.hidden = !n;
    const nav = $("#docBadgePendientes");
    if (nav) {
      nav.textContent = n ? String(n) : "";
      nav.hidden = !n;
    }
  }

  function showHub() {
    stopChatPoll();
    if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
    if (window.QrysPruebaReq) window.QrysPruebaReq.stopPoll();
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
    hideModeChrome();
    loadResumen()
      .then((d) => badgePendientes(contarPorFichar(d)))
      .catch(() => {});
    refreshHubKpis();
  }

  async function refreshHubKpis() {
    try {
      const solData = await fetchJson("/api/solicitar").catch(() => ({ items: [] }));
      const srItems = solData.items || [];
      const srAbiertas = srItems.filter((i) => String(i.estado || "").toLowerCase() !== "cerrado" && i.cerrado !== true).length;
      const srKpi = $("#hubKpiSrTotal");
      if (srKpi) srKpi.textContent = String(srAbiertas);
    } catch (_) {}

    try {
      const colaData = await fetchJson("/api/cola").catch(() => ({ items: [] }));
      const colaItems = colaData.items || [];
      const colaActivas = colaItems.filter((i) => i.estado !== "terminado").length;
      const colaKpi = $("#hubKpiColaTotal");
      if (colaKpi) colaKpi.textContent = String(colaActivas);

      const casosFase1 = colaItems.filter((i) => i.estado === "en_analisis").length;
      const fase1Kpi = $("#hubKpiCasosFase1");
      if (fase1Kpi) fase1Kpi.textContent = String(casosFase1);
    } catch (_) {}

    try {
      const indData = await fetchJson("/api/conocimiento").catch(() => ({}));
      const procs = indData.indice?.procesos || indData.procesos || [];
      const procKpi = $("#hubKpiProcesosTotal");
      if (procKpi && procs.length) procKpi.textContent = String(procs.length);
    } catch (_) {}
  }

  function enterMode(mode) {
    if (window.__qrysOcupado) return;
    if (window.QrysSoporteConsultas && modoGuardado() === "soporte-consultas" && mode !== "soporte-consultas") {
      window.QrysSoporteConsultas.stopPoll();
    }
    if (window.QrysPruebaReq && modoGuardado() === "prueba-req" && mode !== "prueba-req") {
      window.QrysPruebaReq.stopPoll();
    }
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
      shell.classList.remove("modo-analista", "modo-consultas", "modo-documentar", "modo-solicitar", "modo-capacitacion", "modo-auditoria", "modo-agentes", "modo-revisar-sql", "modo-servidores", "modo-informe-contab", "modo-soporte-consultas", "modo-prueba-req");
      shell.classList.add(`modo-${mode}`);
    }
    const inicio = $("#btnInicioHub");
    if (inicio) inicio.hidden = false;
    applyModeChrome(mode);

    $$(".view").forEach((v) => v.classList.remove("active"));
    $$(".main-tab").forEach((t) => t.classList.remove("active"));

    if (mode === "analista") {
      const colaTab = document.querySelector('.main-tab[data-view="cola"]');
      if (colaTab) colaTab.classList.add("active");
      const cola = $("#view-cola");
      if (cola) cola.classList.add("active");
    } else if (mode === "solicitar") {
      const v = $("#view-solicitar");
      if (v) v.classList.add("active");
      if (window.QrysSolicitar) window.QrysSolicitar.enter();
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
    } else if (mode === "capacitacion") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      ["view-cola", "view-formulario", "view-chat", "view-historico"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.classList.remove("active");
      });
      const v = $("#view-capacitacion");
      if (v) v.classList.add("active");
      if (window.QrysCapacitacion) window.QrysCapacitacion.init();
    } else if (mode === "auditoria") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      const v = $("#view-auditoria");
      if (v) v.classList.add("active");
      if (window.QrysAuditoria) {
        window.QrysAuditoria.bind();
        window.QrysAuditoria.init();
      }
    } else if (mode === "informe-contab") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      ["view-cola", "view-formulario", "view-chat", "view-historico"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.classList.remove("active");
      });
      const v = $("#view-informe-contab");
      if (v) v.classList.add("active");
      if (window.QrysInformeContab) window.QrysInformeContab.enter();
    } else if (mode === "soporte-consultas") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      ["view-cola", "view-formulario", "view-chat", "view-historico"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.classList.remove("active");
      });
      const v = $("#view-soporte-consultas");
      if (v) v.classList.add("active");
      if (window.QrysSoporteConsultas) window.QrysSoporteConsultas.enter();
    } else if (mode === "prueba-req") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      ["view-cola", "view-formulario", "view-chat", "view-historico"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.classList.remove("active");
      });
      const v = $("#view-prueba-req");
      if (v) v.classList.add("active");
      if (window.QrysPruebaReq) window.QrysPruebaReq.enter();
    } else if (mode === "agentes") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      const v = $("#view-agentes");
      if (v) v.classList.add("active");
      if (window.QrysAgentes) window.QrysAgentes.enter();
    } else if (mode === "servidores") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      ["view-cola", "view-formulario", "view-chat", "view-historico"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.classList.remove("active");
      });
      const v = $("#view-servidores");
      if (v) v.classList.add("active");
      if (window.QrysServidores) window.QrysServidores.enter();
    } else if (mode === "revisar-sql") {
      stopChatPoll();
      if (window.QrysSolicitar) window.QrysSolicitar.stopPoll();
      const v = $("#view-revisar-sql");
      if (v) v.classList.add("active");
      if (window.QrysSqlRevisar) window.QrysSqlRevisar.enter();
    }
  }

  async function refreshConsultas() {
    const list = $("#consultaProcesos");
    const det = $("#consultaDetalle");
    if (!list) return;
    try {
      await loadResumenConModulo("consultas");
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
      det.innerHTML = `<p class="hint">Elija un proceso a la izquierda. Flujo (capa → control) o Procedimientos (SP → método). El Chat está en su pestaña.</p>`;
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
    setProcesoChat("consultas", id);
    if ($("#consultaPanelChat") && !$("#consultaPanelChat").classList.contains("hidden")) {
      loadResumen("consultas")
        .then(() => renderChatBoxes(true))
        .catch(() => {});
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
        const controles = (c.controles || c.gates || [])
          .map((g) => {
            const sps = (g.sps || [])
              .map((s) => `<li><code>${esc(s.nombre)}</code> ${esc(s.metodo || "")} — ${esc(s.rol || "")}</li>`)
              .join("");
            return `
            <article class="kb-control kb-gate">
              <h4>${esc(g.nombre)}</h4>
              <p>${esc(g.explicacion || "")}</p>
              ${g.invariante ? `<div class="kb-invariante"><strong>Invariante:</strong> ${esc(g.invariante)}</div>` : ""}
              ${sps ? `<p class="hint compact">SP de este control (ficha completa en Procedimientos)</p><ul>${sps}</ul>` : `<p class="hint compact">SP de este control: pendiente.</p>`}
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
          ${controles || `<p class="hint">Controles aún no documentados.</p>`}
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
        ${m.hace ? `<p>${esc(m.hace)}</p>` : `<p class="hint compact">Aún no leído. Leer el SP de hoy (DESAIX o copia local sql/, fuera de git) y pasarlo en Documentar.</p>`}
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

  const COLA_FICHAR = {
    documentacion: 1,
    ficha: 1,
    doc: 1,
    sp: 1,
    gate: 1,
    flujo: 1,
    proceso_nuevo: 1,
    config: 1,
  };
  const SALIDA_COLA = {
    fichar:
      "Por fichar: baje el .sql y pulse Documentar SP, o Marcar pendiente hecho si la ficha ya está leída.",
    aclarar: "Por aclarar: responda en el Chat del módulo y luego Marcar pendiente hecho.",
    defecto:
      "Defectos: no se documentan aquí. Llévelos a Solicitar requerimiento (uno por módulo) y márquelos hechos cuando el REQ exista.",
    libro:
      "Del libro: ya están en el manual. Márquelos hechos si el comité no los va a desarrollar, o al crear la solicitud si sí.",
  };
  let colaFiltro = "fichar";

  function estaAbierto(item) {
    const e = item?.estado || "";
    return e !== "completado" && e !== "cerrado" && e !== "hecho";
  }

  function colaDe(item) {
    const tipo = item?.tipo || "";
    if (tipo === "hallazgo" || tipo === "libro") return "libro";
    if (tipo === "aclaracion") return "aclarar";
    if (COLA_FICHAR[tipo]) return "fichar";
    return "defecto";
  }

  function spsPendientes(soloValle) {
    const items = (cache?.pendientes?.items || []).filter((i) => estaAbierto(i) && i.spNombre && colaDe(i) === "fichar");
    const valleId = cache?.valle?.proceso?.id || "";
    const modulo = $("#docFiltroProceso")?.value || chatProceso.documentar || "";
    const porModulo = modulo ? items.filter((i) => i.procesoId === modulo) : items;
    const filtrados = soloValle && valleId ? porModulo.filter((i) => i.procesoId === valleId) : porModulo;
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

  function nombreProceso(pid) {
    const procesos = cache?.indice?.procesos || [];
    const p = procesos.find((x) => x.id === pid);
    return (p && (p.nombre || p.id)) || pid || "";
  }

  function renderPendientes() {
    const box = $("#docPendientesLista");
    if (!box || !cache) return;
    const todos = (cache.pendientes?.items || []).filter((i) => estaAbierto(i));
    const cuentas = { fichar: 0, aclarar: 0, defecto: 0, libro: 0 };
    todos.forEach((i) => {
      cuentas[colaDe(i)] += 1;
    });
    const selCola = $("#docFiltroCola");
    if (selCola) {
      const etiquetas = {
        fichar: "Por fichar",
        aclarar: "Por aclarar",
        defecto: "Defectos",
        libro: "Del libro",
        "": "Todos",
      };
      Array.from(selCola.options).forEach((op) => {
        const n = op.value ? cuentas[op.value] || 0 : todos.length;
        op.textContent = etiquetas[op.value] + " (" + n + ")";
      });
      if (selCola.value !== colaFiltro) selCola.value = colaFiltro;
    }
    const hintCola = $("#docColaHint");
    if (hintCola) {
      hintCola.textContent =
        (SALIDA_COLA[colaFiltro] || "Todos: elija una cola. Cada una se cierra de una forma distinta.") +
        " Totales: " +
        cuentas.fichar +
        " por fichar, " +
        cuentas.aclarar +
        " por aclarar, " +
        cuentas.defecto +
        " defectos, " +
        cuentas.libro +
        " del libro.";
    }
    const filtro = $("#docFiltroProceso")?.value || chatProceso.documentar || "";
    const deCola = colaFiltro ? todos.filter((i) => colaDe(i) === colaFiltro) : todos;
    const items = filtro ? deCola.filter((i) => (i.procesoId || "") === filtro) : deCola;
    const ocultos = deCola.length - items.length;
    badgePendientes(cuentas.fichar);
    if (!items.length) {
      const extra = filtro
        ? `<p class="hint">No hay pendientes de <strong>${esc(nombreProceso(filtro))}</strong>.${ocultos ? " Hay " + ocultos + " de otros módulos (cambie el filtro a «Todos» para verlos)." : ""}</p>`
        : `<p class="hint">No hay pendientes. Cuando un REQ abra un proceso o falten SP, aparecerán aquí.</p>`;
      box.innerHTML = extra;
      return;
    }
    const aviso = filtro
      ? `<p class="hint compact">Solo <strong>${esc(nombreProceso(filtro))}</strong> (${items.length}).${ocultos ? " Ocultos " + ocultos + " de otros módulos." : ""}</p>`
      : "";
    box.innerHTML =
      aviso +
      items
        .map((i) => {
          const sel = i.estado === "en_progreso" ? " kb-pendiente--on" : "";
          const modulo = nombreProceso(i.procesoId) || i.procesoId || "—";
          return `
        <label class="kb-pendiente${sel}">
          <input type="radio" name="docPendiente" value="${esc(i.id)}">
          <div>
            <strong>${esc(i.titulo)}</strong>
            ${pillEstado(i.estado)}
            <span class="kb-tipo">${esc(i.tipo)}</span>
            <span class="kb-tipo">${esc(modulo)}</span>
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
    const actual = sel.value || chatProceso.documentar || procesoGuardado() || "";
    sel.innerHTML =
      `<option value="">Proceso (se infiere si el SP ya está en el catálogo)…</option>` +
      procesos.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}${p.modulo ? " · " + esc(p.modulo) : ""}</option>`).join("");
    if (actual && procesos.some((p) => p.id === actual)) sel.value = actual;
  }

  function procesoSelId(canal) {
    return canal === "consultas" ? "#consultaChatProceso" : "#docChatProceso";
  }

  function procesoChatDe(canal) {
    const sel = $(procesoSelId(canal));
    return (sel && sel.value) || chatProceso[canal] || "";
  }

  function setProcesoChat(canal, pid) {
    chatProceso[canal] = pid || "";
    if (canal === "documentar") guardarProcesoDoc(pid);
    const sel = $(procesoSelId(canal));
    if (sel && pid) sel.value = pid;
    const filtro = $("#docFiltroProceso");
    if (canal === "documentar" && filtro && pid) filtro.value = pid;
    const docSel = $("#docProcesoId");
    if (canal === "documentar" && docSel && pid) docSel.value = pid;
  }

  function fillProcesoChatSelect(canal) {
    const sel = $(procesoSelId(canal));
    const data = caches[canal];
    if (!sel || !data) return;
    const procesos = data.indice?.procesos || [];
    const actual =
      chatProceso[canal] ||
      procesoGuardado() ||
      data.chatProcesoId ||
      "";
    sel.innerHTML =
      `<option value="">— Elija módulo —</option>` +
      procesos.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}</option>`).join("");
    if (actual && procesos.some((p) => p.id === actual)) sel.value = actual;
    chatProceso[canal] = sel.value || actual;
    if (canal === "documentar" && sel.value) guardarProcesoDoc(sel.value);
  }

  function fillFiltroProceso() {
    const sel = $("#docFiltroProceso");
    const data = caches.documentar || cache;
    if (!sel || !data) return;
    const procesos = data.indice?.procesos || [];
    const actual = chatProceso.documentar || procesoGuardado() || sel.value || "";
    sel.innerHTML =
      `<option value="">— Todos (se mezclan) —</option>` +
      procesos.map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}</option>`).join("");
    if (actual && procesos.some((p) => p.id === actual)) sel.value = actual;
  }

  async function loadResumenConModulo(canal) {
    if (canal === "documentar" && !chatProceso.documentar && procesoGuardado()) {
      chatProceso.documentar = procesoGuardado();
    }
    await loadResumen(canal);
    fillProcesoChatSelect(canal);
    const pid = procesoChatDe(canal);
    if (pid && pid !== (caches[canal]?.chatProcesoId || "")) {
      await loadResumen(canal);
    }
  }

  function renderChatBoxes(forceBottom) {
    fillProcesoChatSelect("consultas");
    fillProcesoChatSelect("documentar");
    renderChatIn("#docChatMensajes", caches.documentar, forceBottom, "documentar");
    renderChatIn("#consultaChatMensajes", caches.consultas, forceBottom, "consultas");
    fillChatSelect("consultas", "#consultaChatSelect");
    fillChatSelect("documentar", "#docChatSelect");
    toggleCompose("consultas", "#consultaChatCompose");
    toggleCompose("documentar", "#docChatCompose");
    renderKbStatus("consultas");
    renderKbStatus("documentar");
    const nC = caches.consultas?.faqCount || 0;
    const nD = caches.documentar?.faqCount || 0;
    const elC = $("#consultaFaqCount");
    const elD = $("#docFaqCount");
    if (elC) elC.textContent = nC ? `Hay ${nC} respuesta${nC === 1 ? "" : "s"} aceptada${nC === 1 ? "" : "s"} en este módulo.` : "";
    if (elD) elD.textContent = nD ? `Hay ${nD} respuesta${nD === 1 ? "" : "s"} aceptada${nD === 1 ? "" : "s"} en este módulo.` : "";
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

  function fmtKbElapsed(iso) {
    if (!iso) return "0:00";
    const t0 = new Date(iso).getTime();
    if (Number.isNaN(t0)) return "0:00";
    const sec = Math.max(0, Math.floor((Date.now() - t0) / 1000));
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
  }

  function stopKbTimer(canal) {
    if (kbTimers[canal]) {
      clearInterval(kbTimers[canal]);
      kbTimers[canal] = null;
    }
    const el = $(ESTADO_UI[canal]?.timer);
    if (el) el.classList.add("hidden");
  }

  function startKbTimer(canal, bot) {
    const el = $(ESTADO_UI[canal]?.timer);
    if (!el) return;
    stopKbTimer(canal);
    el.classList.remove("hidden");
    const tick = () => {
      const hb = bot.heartbeatEn ? new Date(bot.heartbeatEn).getTime() : null;
      const hace = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
      let vivo = "arrancando…";
      if (bot.pidVivo === false && (bot.pid || 0) > 0) vivo = "proceso detenido";
      else if (hace != null && hace <= 15) vivo = "latido OK";
      else if (hace != null) vivo = `sin latido (${hace}s)`;
      el.textContent = `${fmtKbElapsed(bot.iniciadoEn)} · ${vivo}`;
    };
    tick();
    kbTimers[canal] = setInterval(tick, 1000);
  }

  function computeKbStatus(bot, chat, soloLectura) {
    const b = bot || {};
    const hb = b.heartbeatEn
      ? new Date(b.heartbeatEn).getTime()
      : b.iniciadoEn
        ? new Date(b.iniciadoEn).getTime()
        : null;
    const haceHb = hb && !Number.isNaN(hb) ? Math.max(0, Math.floor((Date.now() - hb) / 1000)) : null;
    const botMuerto =
      b.estado === "trabajando" && (b.pidVivo === false || (haceHb != null && haceHb > 45));
    if (soloLectura) {
      return {
        code: "esperando",
        label: "Chat archivado (solo lectura)",
        detail: "Pulse Nuevo para seguir en este módulo.",
      };
    }
    if (b.estado === "trabajando" && !botMuerto) {
      return {
        code: "trabajando",
        label: "El agente está procesando",
        detail: "Lea este Chat y conocimiento/. La respuesta aparece aquí; no cierre la pestaña.",
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
        detail: b.error || "Se quedó sin latido. Vuelva a Enviar o deje el mensaje: en Cursor lo toma al continuar.",
      };
    }
    const msgs = (chat && chat.mensajes) || [];
    const ultimo = [...msgs].reverse().find((m) => m.autor !== "sistema") || msgs[msgs.length - 1];
    const lastAny = msgs[msgs.length - 1];
    if (lastAny?.autor === "sistema" && /está trabajando|procesando/i.test(lastAny.texto || "")) {
      const t0 = new Date(lastAny.en || lastAny.fecha || 0).getTime();
      const age = Number.isNaN(t0) ? 0 : (Date.now() - t0) / 1000;
      if (age < 90 || b.estado === "trabajando") {
        return {
          code: "trabajando",
          label: "El agente está procesando",
          detail: "El mensaje ya está en disco. En unos segundos aparece la respuesta aquí.",
          bot: b.iniciadoEn ? b : { iniciadoEn: lastAny.en || lastAny.fecha || new Date().toISOString() },
        };
      }
    }
    if (ultimo?.autor === "agente") {
      return {
        code: "esperando",
        label: "El agente ya respondió",
        detail: "Siga solo en este Chat. Si la respuesta es correcta, pulse Aceptar.",
      };
    }
    if (ultimo?.autor === "coordinador") {
      return {
        code: "esperando",
        label: "Mensaje guardado — esperando al agente",
        detail: "Si el punto no pasa a procesando, pulse Enviar de nuevo o continúe en Cursor.",
      };
    }
    return {
      code: "esperando",
      label: "Chat listo",
      detail: "Escriba y el agente responde en este hilo.",
    };
  }

  function renderKbStatus(canal, estado) {
    const ui = ESTADO_UI[canal];
    if (!ui) return;
    const data = caches[canal];
    const st = estado || computeKbStatus(data?.bot, data?.chat, data?.chatSoloLectura);
    const box = $(ui.box);
    const label = $(ui.label);
    const detail = $(ui.detail);
    if (!box || !label || !detail) return;
    box.classList.remove("hidden", "chat-estado-trabajando", "chat-estado-esperando", "chat-estado-cerrado");
    box.classList.add(`chat-estado-${st.code}`);
    label.textContent = st.label;
    detail.textContent = st.detail;
    if (st.code === "trabajando" && st.bot) startKbTimer(canal, st.bot);
    else stopKbTimer(canal);
    const input = $(ui.input);
    if (input) {
      input.placeholder =
        st.code === "trabajando"
          ? "Procesando… la respuesta aparece abajo. Puede escribir otro ajuste."
          : canal === "consultas"
            ? "Escriba la pregunta…"
            : "Ej. el SP de confirmar es SPQ_… método CONFIRMAR";
    }
  }

  const NEAR_BOTTOM_PX = 96;

  function chatSig(msgs) {
    if (!msgs?.length) return "empty";
    return msgs.map((m) => `${m.id || ""}|${m.autor}|${m.en || ""}|${String(m.texto || "").length}|${m.aceptada ? 1 : 0}`).join(";");
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

  function burbujaProcesando() {
    return `<div class="chat-msg chat-msg-sistema chat-msg-procesando">
      <div class="chat-msg-head"><strong>Agente</strong> <small>procesando…</small></div>
      <div class="chat-msg-body">Está leyendo este Chat y conocimiento/. En unos segundos aparece la respuesta aquí.</div>
    </div>`;
  }

  function renderChatIn(sel, data, forceBottom, canal) {
    const box = $(sel);
    if (!box || !data) return;
    const estado = computeKbStatus(data.bot, data.chat, data.chatSoloLectura);
    const extra = estado.code === "trabajando" ? burbujaProcesando() : "";
    const msgs = data.chat?.mensajes || [];
    if (!msgs.length) {
      const pid = data.chatProcesoId || "";
      const proc = (data.indice?.procesos || []).find((p) => p.id === pid);
      const nombre = (proc && proc.nombre) || pid || "este módulo";
      paintChat(
        box,
        `<p class="hint">Chat de <strong>${esc(nombre)}</strong>. Solo este proceso (no se mezcla con otros módulos). Escriba y el agente responde aquí.</p>${extra}`,
        "empty-" + pid + "|" + estado.code,
        !!forceBottom,
      );
      if (canal) renderKbStatus(canal, estado);
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
        const intro = String(m.texto || "").startsWith("Este Chat es independiente");
        let actions = "";
        if (m.autor === "agente" && m.id && !intro) {
          actions = m.aceptada
            ? `<div class="chat-msg-actions"><span class="chat-faq-ok">En la base de este módulo</span></div>`
            : `<div class="chat-msg-actions"><button type="button" class="btn btn-ghost btn-sm" data-faq-aceptar="${esc(m.id)}">Aceptar</button></div>`;
        }
        return `<div class="${cls}"><div class="chat-msg-head"><strong>${esc(who)}</strong> · ${esc(m.en || m.fecha || "")}</div><div>${esc(m.texto).replace(/\n/g, "<br>")}</div>${actions}</div>`;
      })
      .join("");
    paintChat(box, html + extra, chatSig(msgs) + "|" + estado.code, !!forceBottom);
    if (canal) renderKbStatus(canal, estado);
  }

  function renderValle() {
    const el = $("#docValleBox");
    if (!el || !cache) return;
    const ruta = cache.rutaDocumentar || {};
    const pasos = ruta.pasos || [];
    const valle = cache.valle;
    if (!pasos.length) {
      el.hidden = true;
      return;
    }
    el.hidden = false;
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
        <span class="hint compact">Pausado (bajo demanda)${actual !== "—" ? " · valle: " + esc(actual) : (cache.rutaEstado?.cerrada ? " · ruta cubierta" : "")}</span>
      </div>
      <p class="hint compact">El agente <strong>no</strong> corre solo. Pregunte en el Chat o pulse Documentar SP: un turno con Composer 2.5 estándar (sin Fast) y se detiene. El barrido automático está eliminado.</p>
      <ol class="kb-valle-list">${filas}</ol>`;
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
      await loadResumenConModulo("documentar");
    } catch (e) {
      const box = $("#docPendientesLista");
      if (box) box.innerHTML = `<p class="alert alert-warning">${esc(e.message)}</p>`;
      return;
    }
    fillFiltroProceso();
    renderPendientes();
    fillSqlSelect();
    fillProcesoSelect();
    renderChatBoxes();
    renderTarea();
    renderValle();
  }

  function kbPollMs() {
    const docOn = $("#view-documentar")?.classList.contains("active");
    const consOn = $("#view-consultas")?.classList.contains("active");
    const canal = docOn ? "documentar" : consOn ? "consultas" : "";
    if (!canal || pagePanel[canal] !== "chat") return 5000;
    const data = caches[canal];
    const code = computeKbStatus(data?.bot, data?.chat, data?.chatSoloLectura).code;
    return code === "trabajando" ? 1500 : 4000;
  }

  function startChatPoll() {
    stopChatPoll();
    const run = async () => {
      try {
        if ($("#view-documentar")?.classList.contains("active")) {
          if (pagePanel.documentar === "chat") {
            await loadResumenConModulo("documentar");
            renderChatBoxes();
          } else {
            await refreshDocumentar();
          }
        } else if ($("#view-consultas")?.classList.contains("active")) {
          await loadResumenConModulo("consultas");
          if (pagePanel.consultas === "chat") renderChatBoxes();
          else refreshConsultas();
        }
      } catch (_) {}
      chatPoll = setTimeout(run, kbPollMs());
    };
    chatPoll = setTimeout(run, 400);
  }

  function stopChatPoll() {
    if (chatPoll) {
      clearTimeout(chatPoll);
      chatPoll = null;
    }
    stopKbTimer("consultas");
    stopKbTimer("documentar");
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
        err.textContent = "Indique el SP vigente (lista de la copia local sql/ o su nombre). No es obligatorio marcar un pendiente.";
      }
      return;
    }
    try {
      const out = await fetchJson("/api/conocimiento/documentar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pendienteId, archivoSql: archivo, notas, procesoId }),
      });
      if ($("#docNotas")) $("#docNotas").value = "";
      if ($("#docSqlManual")) $("#docSqlManual").value = "";
      await refreshDocumentar();
      if (caches.documentar) {
        caches.documentar.bot = out.bot || {
          estado: "trabajando",
          iniciadoEn: new Date().toISOString(),
          heartbeatEn: new Date().toISOString(),
        };
      }
      renderKbStatus("documentar");
      if (pagePanel.documentar === "chat") renderChatBoxes(true);
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
      loadResumenConModulo(page).then(() => renderChatBoxes(true)).catch(() => {});
    }
  }

  async function onChatProceso(canal, pid) {
    setProcesoChat(canal, pid);
    await loadResumen(canal);
    renderChatBoxes(true);
    if (canal === "documentar") {
      fillFiltroProceso();
      renderPendientes();
      fillProcesoSelect();
    }
  }

  async function onChatNuevo(canal) {
    const procesoId = procesoChatDe(canal);
    await fetchJson("/api/conocimiento/chat/nuevo", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ canal, procesoId }),
    });
    await loadResumen(canal);
    renderChatBoxes(true);
  }

  async function onGenerarDiagramaConsultas() {
    const sel = $("#consultaChatProceso");
    const procesoId = sel?.value || chatProceso.consultas || "";
    if (!procesoId) return alert("Seleccione el módulo en el desplegable de Chat.");
    const pregunta = ($("#consultaChatInput")?.value || "").trim();
    const btn = $("#btnConsultaGenerarDiagrama");
    if (btn) btn.disabled = true;
    try {
      const out = await fetchJson("/api/conocimiento/diagrama", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ procesoId, pregunta }),
      });
      if (!out?.ok) throw new Error(out?.error || "No se pudo generar");
      const url = out.diagrama?.url || `/conocimiento/${procesoId}/diagramas/flujo.html`;
      window.open(url, "_blank", "noopener");
    } catch (e) {
      alert(e.message || "Error al generar el diagrama.");
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function onChatArchivar(canal) {
    const titulo = window.prompt("Nombre para archivar este chat (opcional):", "") || "";
    const procesoId = procesoChatDe(canal);
    await fetchJson("/api/conocimiento/chat/archivar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ canal, titulo, procesoId }),
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

  async function onAceptarFaq(canal, mensajeId) {
    const dest = canal || "consultas";
    const procesoId = procesoChatDe(dest) || caches[dest]?.chatProcesoId || "";
    const chatId = caches[dest]?.chat?.id || "";
    try {
      await fetchJson("/api/conocimiento/faq", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ canal: dest, procesoId, mensajeId, chatId }),
      });
      await loadResumen(dest);
      renderChatBoxes(true);
    } catch (e) {
      alert(e.message || "No se pudo guardar en la base.");
    }
  }

  async function onEnviarChat(fromSel, canal) {
    const input = $(fromSel || "#docChatInput") || $("#consultaChatInput");
    const texto = input?.value?.trim();
    if (!texto) return;
    const dest = canal || (fromSel && fromSel.includes("consulta") ? "consultas" : "documentar");
    if (input) input.value = "";
    if (caches[dest]) {
      const prev = caches[dest].chat || { mensajes: [] };
      caches[dest].bot = {
        estado: "trabajando",
        iniciadoEn: new Date().toISOString(),
        heartbeatEn: new Date().toISOString(),
        pid: 0,
      };
      caches[dest].chat = {
        ...prev,
        mensajes: (prev.mensajes || []).concat([
          { autor: "coordinador", texto, en: new Date().toISOString() },
        ]),
      };
      renderChatBoxes(true);
    }
    try {
      const out = await fetchJson("/api/conocimiento/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          autor: "coordinador",
          texto,
          canal: dest,
          procesoId: procesoChatDe(dest) || procesoActual?.id || caches[dest]?.chatProcesoId || "",
          // Chat exacto: cada chat tiene su propio bot y no se cruza con otro abierto en paralelo.
          chatId: (!caches[dest]?.chatSoloLectura && caches[dest]?.chat?.id) || "",
        }),
      });
      await loadResumen(dest);
      if (caches[dest]) {
        if (out.bot && out.bot.ok === false) {
          caches[dest].bot = { estado: "error", error: out.bot.error || "No arrancó" };
        } else if (out.bot) {
          caches[dest].bot = {
            estado: "trabajando",
            ...out.bot,
            iniciadoEn: out.bot.iniciadoEn || new Date().toISOString(),
          };
        }
        if (out.chat) caches[dest].chat = out.chat;
      }
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
    $("#btnConsultaGenerarDiagrama")?.addEventListener("click", () => onGenerarDiagramaConsultas());
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
    $("#consultaChatProceso")?.addEventListener("change", (e) => onChatProceso("consultas", e.target.value));
    $("#docChatProceso")?.addEventListener("change", (e) => onChatProceso("documentar", e.target.value));
    $("#docFiltroProceso")?.addEventListener("change", (e) => {
      setProcesoChat("documentar", e.target.value || "");
      refreshDocumentar();
    });
    $("#docFiltroCola")?.addEventListener("change", (e) => {
      colaFiltro = e.target.value || "";
      renderPendientes();
    });
    $("#docProcesoId")?.addEventListener("change", (e) => {
      if (e.target.value) setProcesoChat("documentar", e.target.value);
    });
    $("#consultaChatMensajes")?.addEventListener("click", (e) => {
      const btn = e.target && e.target.closest ? e.target.closest("[data-faq-aceptar]") : null;
      if (!btn) return;
      onAceptarFaq("consultas", btn.getAttribute("data-faq-aceptar"));
    });
    $("#docChatMensajes")?.addEventListener("click", (e) => {
      const btn = e.target && e.target.closest ? e.target.closest("[data-faq-aceptar]") : null;
      if (!btn) return;
      onAceptarFaq("documentar", btn.getAttribute("data-faq-aceptar"));
    });
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
    if (window.QrysSolicitar) window.QrysSolicitar.init();
    bind();
    let mode = "hub";
    try {
      mode = modoGuardado();
    } catch (_) {
      mode = "hub";
    }
    if (mode === "analista" || mode === "consultas" || mode === "documentar" || mode === "solicitar" || mode === "capacitacion" || mode === "revisar-sql" || mode === "auditoria" || mode === "agentes" || mode === "servidores" || mode === "informe-contab" || mode === "soporte-consultas" || mode === "prueba-req") {
      enterMode(mode);
    } else {
      showHub();
    }
    loadResumen()
      .then((d) => badgePendientes(contarPorFichar(d)))
      .catch(() => {});
  }

  return { init, showHub, enterMode, stopChatPoll };
})();
