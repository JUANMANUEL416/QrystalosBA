/**
 * Qrystalos BA — App principal
 */
(function () {
  const STORAGE_KEY = "qrystalos_ba_solicitud";
  const STORAGE_KEY_LEGACY = "qrys_quatec_solicitud";
  const PATH_SQL_REFE = "C:\\DevQuasar\\Qrystalos\\QrystalosBA\\sql_refe\\";

  function carpetaSqlCaso(idCaso) {
    const id = String(idCaso || val("#idCaso") || "").trim();
    return id ? `activo/${id}/sql/` : "activo/{id-caso}/sql/";
  }

  function carpetaSqlCasoAbs(idCaso) {
    return `C:\\DevQuasar\\Qrystalos\\QrystalosBA\\${carpetaSqlCaso(idCaso).replaceAll("/", "\\")}`;
  }

  let currentStep = 1;
  const totalSteps = 5;
  let archivoColaVinculado = null;
  let idReqVinculado = null;
  let modalContext = null;
  let sqlChecklistState = null;
  let metodosKbState = emptyMetodosKb();
  let criteriosMeta = window.QrysCriterios ? QrysCriterios.emptyMeta() : {};
  let contValidacion = null;
  let brechaAnalisis = null;
  let imagenesAnalisis = [];
  let archivosAnalisis = [];
  let diagramaFlujo = null;
  let mockupsFormDraft = [];
  let mockupsFormMeta = { mockups: [], sugeridos: [], plantillas: [], correoHint: "" };
  let mockupsFormDirty = false;
  let mockupsFormPreviewRuta = "";
  let mockupsFormCasoId = "";
  let solicitudOrigen = null;
  let solicitudesCache = null;

  function mockupBelongsToCaso(ruta, idCaso) {
    const rel = String(ruta || "")
      .trim()
      .replace(/\\/g, "/")
      .replace(/^\//, "");
    const caso = String(idCaso || "").trim();
    if (!rel) return false;
    if (rel.startsWith("plantillas/")) return false;
    if (rel.startsWith("activo/")) {
      if (!caso) return true;
      return rel.startsWith(`activo/${caso}/`);
    }
    return rel.startsWith("solicitudes/");
  }

  function filterMockupsForCaso(rels, idCaso) {
    const caso = String(idCaso || "").trim();
    return (rels || [])
      .map((r) => String(r || "").trim().replace(/\\/g, "/").replace(/^\//, ""))
      .filter((r) => r && mockupBelongsToCaso(r, caso));
  }

  function clearMockupFormPreview() {
    mockupsFormPreviewRuta = "";
    const preview = $("#mockupFormPreview");
    if (preview) {
      preview.removeAttribute("src");
      preview.classList.add("hidden");
    }
  }

  async function onIdentificacionCasoChanged() {
    const idCaso = val("#idCaso").trim();
    if (!idCaso || idCaso === mockupsFormCasoId) return;
    mockupsFormCasoId = idCaso;
    mockupsFormDraft = filterMockupsForCaso(mockupsFormDraft, idCaso);
    mockupsFormDirty = false;
    mockupsFormMeta = { mockups: [], sugeridos: [], plantillas: [], correoHint: "" };
    clearMockupFormPreview();
    renderMockupsForm();
    await cargarSolicitudCaso(idCaso);
  }
  let syncingCorreo = false;
  let analisisLoadingToken = 0;

  const $ = (s) => document.querySelector(s);
  const $$ = (s) => document.querySelectorAll(s);

  function setText(sel, text) {
    const el = typeof sel === "string" ? $(sel) : sel;
    if (el) el.textContent = text;
  }

  function init() {
    setText("#pathAprobados", "aprobados/{id-caso}/");

    if (location.protocol === "file:") {
      $("#alertFileProtocol").hidden = false;
    }

    setDefaultDates();
    loadFromStorage();
    syncColaFromDb();
    bindMainTabs();
    bindCola();
    bindForm();
    bindChat();
    bindDictado();
    bindHistorico();
    renderOpciones();
    if (!$("#opcionesLista").children.length) addOpcion("", "");
    updateCorruptAlert();
    updateSqlPath();
    updateAll();
    leerCarpetaSql(true);
    cargarOpcionesProcesoSql();
    checkServerHealth();
    setCriteriosHintAgente();
    refreshHistorico();
    const idAlCargar = val("#idCaso");
    if (idAlCargar) {
      cargarSolicitudCaso(idAlCargar);
    } else {
      refreshCorreoEstado();
    }
    showAppReady();
  }

  async function refreshHistorico() {
    await QrysHistorico.syncFromServer();
    QrysHistorico.render($("#historicoBody"), abrirDesdeHistorico);
  }

  function showAppReady() {
    const splash = $("#bootSplash");
    if (splash) splash.remove();
    if (window.QrysConocimiento) {
      QrysConocimiento.init();
    } else {
      const shell = $("#appShell");
      if (shell) shell.hidden = false;
    }
  }

  async function syncColaFromDb() {
    await QrysCola.syncFromServer();
    QrysCola.removeCorruptEntries();
    await repararColaDesdeDisco();
    refreshColaTable();
    updateCorruptAlert();
  }

  async function repararColaDesdeDisco() {
    if (location.protocol === "file:" || !window.QrysCola) return;
    const items = QrysCola.loadCola();
    const files = [...new Set(items.map((i) => i.archivoCola).filter(Boolean))];
    if (!files.length) return;
    for (const name of files) {
      try {
        const resp = await fetch(`../cola/${encodeURIComponent(name)}`, { cache: "no-store" });
        if (!resp.ok) continue;
        const html = await resp.text();
        const parseResult = QrysCola.parseHtmlAvalasesor(html, name);
        if (parseResult.filas?.length) {
          QrysCola.actualizarParsedExistentes({ fileName: name, parseResult });
        }
      } catch {
        /* archivo no está en cola/ */
      }
    }
  }

  function isAnalisisEnCurso() {
    const ov = $("#analisisLoadingOverlay");
    return ov && !ov.hidden;
  }

  function showAnalisisLoading(titulo, detalle, idCaso) {
    const ov = $("#analisisLoadingOverlay");
    if (!ov) return;
    if ($("#analisisLoadingTitle")) $("#analisisLoadingTitle").textContent = titulo || "Analizando requerimiento";
    if ($("#analisisLoadingDetail")) $("#analisisLoadingDetail").textContent = detalle || "";
    if ($("#analisisLoadingCaso")) {
      $("#analisisLoadingCaso").textContent = idCaso ? `Caso: ${idCaso}` : "";
    }
    ov.hidden = false;
    document.body.classList.add("analisis-loading-active");
    window.__qrysOcupado = true;
  }

  function updateAnalisisLoadingDetalle(texto) {
    const el = $("#analisisLoadingDetail");
    if (el && texto) el.textContent = texto;
  }

  function hideAnalisisLoading() {
    const ov = $("#analisisLoadingOverlay");
    if (ov) ov.hidden = true;
    document.body.classList.remove("analisis-loading-active");
    window.__qrysOcupado = false;
  }

  window.QrysOcupado = {
    mostrar: showAnalisisLoading,
    ocultar: hideAnalisisLoading,
    activo() {
      return !!window.__qrysOcupado;
    },
  };

  document.addEventListener("click", (e) => {
    if (!window.__qrysOcupado) return;
    const ov = $("#analisisLoadingOverlay");
    if (ov && !ov.hidden && ov.contains(e.target)) return;
    e.preventDefault();
    e.stopPropagation();
  }, true);

  function bindMainTabs() {
    $$(".main-tab").forEach((tab) => {
      tab.addEventListener("click", () => {
        if (isAnalisisEnCurso()) return;
        const shell = $("#appShell");
        if (shell && !shell.classList.contains("modo-analista")) return;
        $$(".main-tab").forEach((t) => t.classList.toggle("active", t === tab));
        $$(".view").forEach((v) => v.classList.toggle("active", v.id === `view-${tab.dataset.view}`));
        if (tab.dataset.view === "historico") refreshHistorico();
        if (tab.dataset.view === "chat") refreshChatView();
        else stopChatPoll();
        if (window.QrysConocimiento) QrysConocimiento.stopChatPoll();
      });
    });
  }

  function refreshColaTable() {
    QrysCola.renderColaTable(
      $("#colaBody"),
      abrirDesdeCola,
      abrirModalSeleccionReq,
      abrirChatDesdeCola,
      {
        filtroReq: val("#filtroColaReq"),
        verTerminados: !!$("#chkVerTerminadosCola")?.checked,
      },
    );
  }

  function marcarEstadoCola(estado, extra) {
    if (!window.QrysCola) return Promise.resolve(false);
    const idReq = val("#idReq") || idReqVinculado;
    if (!idReq && !archivoColaVinculado) return Promise.resolve(false);
    const pending = QrysCola.updateEstado(archivoColaVinculado || "", estado, extra || {}, idReq);
    refreshColaTable();
    return pending;
  }

  function switchToView(viewName) {
    if (isAnalisisEnCurso()) return;
    $$(".main-tab").forEach((t) => t.classList.toggle("active", t.dataset.view === viewName));
    $$(".view").forEach((v) => v.classList.toggle("active", v.id === `view-${viewName}`));
    if (viewName === "chat") refreshChatView();
    else stopChatPoll();
    if (viewName === "historico") refreshHistorico();
  }

  function abrirChatCaso(idCasoFromCola) {
    if (idCasoFromCola) setVal("#idCaso", idCasoFromCola);
    switchToView("chat");
  }

  let chatPollTimer = null;

  function stopChatPoll() {
    if (chatPollTimer) {
      clearInterval(chatPollTimer);
      chatPollTimer = null;
    }
  }

  function scheduleChatPoll(idCaso, statusCode) {
    stopChatPoll();
    if (location.protocol === "file:") return;
    if (statusCode === "cerrado") return;
    const ms = statusCode === "trabajando" ? 1500 : 5000;
    chatPollTimer = setInterval(() => {
      if ($("#view-chat")?.classList.contains("active")) refreshChatView(idCaso, true);
    }, ms);
  }

  async function refreshChatView(idCasoArg, silent) {
    const offlineBox = $("#chatServerOffline");
    if (location.protocol !== "file:") {
      try {
        const health = await fetch("/api/health", { cache: "no-store" });
        if (offlineBox) offlineBox.classList.toggle("hidden", health.ok);
      } catch {
        if (offlineBox) offlineBox.classList.remove("hidden");
      }
    } else if (offlineBox) {
      offlineBox.classList.remove("hidden");
    }

    if (!window.QrysChat) {
      if ($("#chatMessages")) {
        $("#chatMessages").innerHTML =
          "<p class='hint'>No cargó <code>chat.js</code>. Recargue con <strong>Ctrl+F5</strong> o reinicie con <strong>abrir-app.bat</strong>.</p>";
      }
      return;
    }

    const casos = await QrysChat.listarCasosActivos();
    const idCaso = QrysChat.resolverIdCaso(casos, val("#idReq"), idCasoArg || val("#idCaso"));
    if (idCaso) {
      setVal("#idCaso", idCaso);
      const meta = casos.find((c) => c.idCaso === idCaso);
      if (meta?.idReq) setVal("#idReq", meta.idReq);
    }

    if (!idCaso) {
      stopChatPoll();
      const n = casos.length;
      $("#chatMessages").innerHTML = n
        ? `<p class="hint">Hay <strong>${n}</strong> casos en <code>activo/</code>. Elija el REQ en la lista de arriba — el Chat no usa un solo caso.</p>`
        : "<p class='hint'>Seleccione un caso en la lista de arriba o ábralo desde la cola.</p>";
      QrysChat.renderAgentStatus(null);
      QrysChat.renderMockupsPanel("", { mockups: [], correoHint: "—" }, { readonly: true });
      if (!silent) await fillChatSelect("", casos);
      return;
    }
    $("#chatIdCaso").textContent = idCaso;
    $("#chatIdReq").textContent = val("#idReq") || "—";
    if ($("#chatCasoLabel")) $("#chatCasoLabel").textContent = idCaso;

    const estado = await QrysChat.fetchEstado(idCaso);
    const faseLabel = estado.fase1Cerrada ? "Fase 2 — cerrada F1" : "Fase 1 — análisis";
    $("#chatBadgeFase").textContent = faseLabel;
    $("#badgeFase").textContent = faseLabel;
    $("#btnCerrarFase1").disabled = !!estado.fase1Cerrada;
    $("#btnCerrarFase1Chat").disabled = !!estado.fase1Cerrada;
    $("#chatComposeActivo")?.classList.toggle("hidden", !!estado.fase1Cerrada);
    $("#chatCerradoBar")?.classList.toggle("hidden", !estado.fase1Cerrada);
    $("#btnChatVerHistorico")?.classList.toggle("hidden", !estado.fase1Cerrada);

    const chat = await QrysChat.fetchChat(idCaso);
    QrysChat.renderChat($("#chatMessages"), chat.mensajes, idCaso);
    const documentos = await QrysChat.fetchDocumentos(idCaso);
    QrysChat.renderDocumentList($("#chatDocumentList"), documentos, idCaso);
    const mockData = await QrysChat.fetchMockups(idCaso);
    QrysChat.renderMockupsPanel(idCaso, mockData, { readonly: !!estado.fase1Cerrada });
    const mockupsCaseChanged = idCaso !== mockupsFormCasoId;
    if (mockupsCaseChanged || !mockupsFormDirty) {
      mockupsFormCasoId = idCaso;
      if (mockupsCaseChanged) mockupsFormDirty = false;
      mockupsFormDraft = filterMockupsForCaso(
        (mockData.mockups || []).map((m) => m.ruta),
        idCaso,
      );
      mockupsFormMeta = {
        mockups: (mockData.mockups || []).filter((m) => mockupBelongsToCaso(m.ruta, idCaso)),
        sugeridos: (mockData.sugeridos || []).filter((m) => mockupBelongsToCaso(m.ruta, idCaso)),
        plantillas: mockData.plantillas || [],
        correoHint: mockData.correoHint || "",
      };
      if (mockupsFormPreviewRuta && !mockupsFormDraft.includes(mockupsFormPreviewRuta)) {
        clearMockupFormPreview();
      }
      renderMockupsForm();
    }
    const statusCode = QrysChat.renderAgentStatus(
      QrysChat.computeAgentStatus(estado, chat.mensajes, documentos),
    );
    scheduleChatPoll(idCaso, statusCode);

    const input = $("#chatInput");
    if (input) {
      input.disabled = !!estado.fase1Cerrada;
      input.placeholder = estado.fase1Cerrada
        ? "Fase 1 cerrada."
        : statusCode === "trabajando"
          ? "Mensaje guardado. Espere el verde «Agente» — no lo copie a Cursor."
          : "Escriba solo aquí. Enter envía.";
    }
    $("#btnEnviarChat").disabled = !!estado.fase1Cerrada;
    if (!silent) await fillChatSelect(idCaso, casos);
  }

  async function fillChatSelect(idCasoActual, casosArg) {
    const sel = $("#chatSelectCaso");
    if (!sel) return;
    const lista = casosArg || (await QrysChat.listarCasosActivos());
    const ids = lista.map((c) => `${c.idCaso}:${c.nMensajes}:${c.fase1Cerrada}`).join("|");
    if (sel.dataset.ids !== ids) {
      sel.dataset.ids = ids;
      sel.innerHTML = lista.length
        ? `<option value="">— ${lista.length} requerimientos / casos —</option>` +
          lista
            .map((c) => {
              const fase = c.fase1Cerrada ? "F1 cerrada" : "abierto";
              const n = c.nMensajes || 0;
              const tit = String(c.titulo || "").slice(0, 36);
              return `<option value="${esc(c.idCaso)}">${esc(c.idReq || "?")} · ${n} msgs · ${fase} — ${esc(tit)}</option>`;
            })
            .join("")
        : `<option value="">Sin casos en activo/</option>`;
    }
    if (idCasoActual && [...sel.options].some((o) => o.value === idCasoActual)) {
      sel.value = idCasoActual;
    }
  }

  function bindChat() {
    $("#chatSelectCaso")?.addEventListener("change", () => {
      const id = $("#chatSelectCaso").value;
      if (!id) return;
      setVal("#idCaso", id);
      const req = id.includes("-") ? id.split("-").slice(1).join("-") : "";
      if (req) setVal("#idReq", req);
      refreshChatView(id);
    });
    $("#btnAbrirChat").addEventListener("click", () => abrirChatCaso());
    $("#btnEnviarChat").addEventListener("click", () => enviarMensajeChat());
    $("#btnRefrescarChat").addEventListener("click", () => refreshChatView());
    $("#btnCerrarFase1").addEventListener("click", () => cerrarFase1());
    $("#btnCerrarFase1Chat").addEventListener("click", () => cerrarFase1());
    $("#btnChatVolverForm")?.addEventListener("click", () => switchToView("formulario"));
    $("#btnChatVolverCola")?.addEventListener("click", () => switchToView("cola"));
    $("#btnChatCerrarVolver")?.addEventListener("click", () => switchToView("cola"));
    $("#btnChatVerHistorico")?.addEventListener("click", () => switchToView("historico"));
    $("#btnChatCerrarHistorico")?.addEventListener("click", () => switchToView("historico"));
    if (window.QrysChat?.bindMockupsPanel) {
      QrysChat.bindMockupsPanel(() => val("#idCaso") || $("#chatSelectCaso")?.value || "");
    }
    if (window.QrysChat?.bindChatWorkspace) {
      QrysChat.bindChatWorkspace();
    }
    $("#chatInput").addEventListener("keydown", (e) => {
      if (e.key !== "Enter") return;
      if (e.altKey || e.shiftKey) {
        e.preventDefault();
        const el = e.target;
        const start = el.selectionStart;
        const end = el.selectionEnd;
        el.value = `${el.value.slice(0, start)}\n${el.value.slice(end)}`;
        el.selectionStart = el.selectionEnd = start + 1;
        return;
      }
      e.preventDefault();
      enviarMensajeChat();
    });
  }

  async function enviarMensajeChat() {
    const idCaso = val("#idCaso");
    const texto = val("#chatInput");
    if (!idCaso) return alert("Indique ID caso");
    if (!texto) return;
    const btn = $("#btnEnviarChat");
    const input = $("#chatInput");
    if (btn) btn.disabled = true;
    if (input) {
      input.disabled = true;
      input.placeholder = "Enviando…";
    }
    try {
      const result = await QrysChat.sendMessage(idCaso, texto, "coordinador");
      if (input) input.value = "";
      if (result?.mensajes) {
        QrysChat.renderChat($("#chatMessages"), result.mensajes, idCaso, { forceBottom: true });
      }
      if (window.QrysDesarrolladores) {
        const nombreDev = val("#desarrollador");
        const aplicados = await QrysDesarrolladores.aplicarCorreosDelTexto(texto, nombreDev);
        if (QrysDesarrolladores.esFinalizar(texto)) {
          const fin = await QrysDesarrolladores.alFinalizar();
          if (fin.actualizados?.length) {
            alert("Lista de desarrolladores actualizada:\n" + fin.actualizados.join("\n"));
          }
        } else if (aplicados.length) {
          alert("Correo guardado en la lista:\n" + aplicados.join("\n"));
        }
      }
    } catch (e) {
      alert(e.message || "No se pudo enviar el mensaje.");
    } finally {
      if (btn) btn.disabled = false;
      if (input) {
        input.disabled = false;
        input.placeholder = "Mensaje guardado. Espere el verde «Agente» — no lo copie a Cursor.";
      }
    }
    refreshChatView(idCaso);
  }

  async function cerrarFase1() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID caso");

    const actuales = val("#criteriosAceptacion");
    const baseline = QrysCriterios.baselineCierre(criteriosMeta);
    if (baseline) {
      const coinciden = QrysCriterios.sonIguales(baseline, actuales);
      criteriosMeta.definitivos = actuales;
      criteriosMeta.validados = true;
      criteriosMeta.coinciden = coinciden;
      criteriosMeta.validadosEn = new Date().toISOString();
      saveToStorage();
      renderCriteriosComparacion();

      if (!coinciden) {
        const ok = confirm(
          "Los criterios definitivos NO coinciden con los fijados tras el análisis (o la sugerencia).\n\n" +
            "REFERENCIA:\n" +
            baseline +
            "\n\nDEFINITIVOS:\n" +
            actuales +
            "\n\n¿Cerrar de todos modos? Quedará registrado que difieren.",
        );
        if (!ok) return;
      }
    }

    if (!confirm(
      "¿Cerrar fase 1?\n\n" +
        "El dictamen se aprueba, se copia a aprobados/, los .sql de activo/{id-caso}/sql/ pasan a sql_refe/{ID-REQ}/ " +
        "y se envía el correo al desarrollador.",
    )) return;

    const dest = await resolverCorreoDestino();
    if (!dest) {
      return alert("No se cierra Fase 1 sin correo del desarrollador. Indíquelo en la tarjeta Correo o en la lista de desarrolladores.");
    }
    if (window.__qrysOcupado) return;

    showAnalisisLoading(
      "Cerrando fase 1",
      "Se archiva el dictamen, se mueven los SQL y se envía el correo. No cambie de caso ni de pestaña hasta que termine.",
      idCaso,
    );
    try {
      const cierre = await QrysChat.cerrarFase1(idCaso, { correo: dest });
      if (!cierre || (cierre.ok === false && !cierre.estado)) {
        alert(cierre?.error || "No se pudo cerrar Fase 1.");
        return;
      }
      const mail = cierre?.correo || {};
      if (mail.ok && !mail.borrador) {
        await guardarCorreoEnLista(val("#desarrollador"), dest);
        aplicarResultadoCorreoEnviado(idCaso, mail);
      } else if (archivoColaVinculado) {
        QrysCola.updateEstado(archivoColaVinculado, "aprobado", {}, idReqVinculado);
      }
      refreshColaTable();
      await refreshChatView(idCaso);

      const sqlInfo = cierre?.sql || {};
      const movidos = sqlInfo.movidos || [];
      if (movidos.length) {
        sqlChecklistState = null;
        if ($("#objetosSolicitados")) $("#objetosSolicitados").value = "";
        if ($("#listaArchivosSql")) {
          $("#listaArchivosSql").innerHTML = "<li class='hint'>Carpeta SQL del caso archivada</li>";
        }
        if ($("#sqlLeidoEstado")) $("#sqlLeidoEstado").textContent = "";
        if ($("#chkSqlColocados")) $("#chkSqlColocados").checked = false;
        saveToStorage();
        updateAll();
      }

      const destSql = sqlInfo.destinoRelativo || `sql_refe/${val("#idReq")}/`;
      const destHtml = cierre?.aprobado?.ruta || `aprobados/${idCaso}/`;
      const listaSql = movidos.length
        ? movidos.map((m) => "• " + m).join("\n")
        : "• (no había .sql en la carpeta del caso)";
      const lineaMail = mail.ok && !mail.borrador
        ? `Correo: enviado a ${mail.destinatario || dest}`
        : `Correo: NO enviado. ${mail.error || "Use Enviar correo."}`;
      alert(
        `Fase 1 cerrada.\n\nDictamen: ${destHtml}\nSQL: ${destSql}\n${listaSql}\n${lineaMail}`,
      );
      if (!mail.ok && mail.error && confirm(`${mail.error}\n\n¿Abrir un borrador en Outlook?`)) {
        accionarCorreo({ display: true });
      }
    } finally {
      hideAnalisisLoading();
    }
  }

  async function guardarCorreoEnLista(nombre, mail) {
    nombre = String(nombre || "").trim();
    mail = String(mail || "").trim();
    if (!nombre || !mail || !window.QrysDesarrolladores) return false;
    try {
      const r = await QrysDesarrolladores.setCorreo(nombre, mail);
      if (!r || r.ok === false) {
        console.warn("No se guardó el correo en desarrolladores:", r && r.error);
        return false;
      }
      const guardado = String((r.desarrollador && r.desarrollador.correo) || "").trim().toLowerCase();
      return guardado === mail.toLowerCase();
    } catch (e) {
      console.warn("No se guardó el correo en desarrolladores:", e);
      return false;
    }
  }

  async function resolverCorreoDestino() {
    let dest = val("#correoDestino");
    if (!dest && window.QrysDesarrolladores) {
      try {
        const data = await QrysDesarrolladores.listar();
        dest = QrysDesarrolladores.correoDeLista(data, val("#desarrollador"));
        if (dest) setVal("#correoDestino", dest);
      } catch {
        /* */
      }
    }
    if (!dest) {
      dest = (window.prompt(
        "Para cerrar Fase 1 hay que enviar el correo. Escriba el correo del desarrollador:",
        "",
      ) || "").trim();
      if (dest) setVal("#correoDestino", dest);
    }
    if (dest) {
      await guardarCorreoEnLista(val("#desarrollador"), dest);
    }
    return dest;
  }

  function aplicarResultadoCorreoEnviado(idCaso, r) {
    applyCorreoUI(r);
    saveToStorage();
    QrysHistorico.upsert({
      idCaso,
      idReq: val("#idReq"),
      proyecto: val("#proyecto"),
      modulo: val("#moduloNombre"),
      fecha: val("#fecha"),
      estado: "enviado",
      correoEnviado: true,
      fechaEnvioCorreo: r.fechaEnvio,
    });
    // Al enviar el correo el REQ queda terminado en la cola (como en avalasesor: ya no aparece).
    const idReq = val("#idReq") || idReqVinculado;
    if (archivoColaVinculado) {
      QrysCola.updateEstado(
        archivoColaVinculado,
        "terminado",
        {
          terminadoEn: new Date().toISOString(),
          terminadoPor: "correo_enviado",
          correoEnviado: true,
          fechaEnvioCorreo: r.fechaEnvio || "",
        },
        idReq,
      );
    } else if (idReq && window.QrysCola) {
      const item = QrysCola.loadCola().find(
        (c) => c.idReqSeleccionado === idReq || c.parsed?.idReq === idReq,
      );
      if (item) {
        QrysCola.updateEstado(
          item.archivoCola,
          "terminado",
          {
            terminadoEn: new Date().toISOString(),
            terminadoPor: "correo_enviado",
            correoEnviado: true,
            fechaEnvioCorreo: r.fechaEnvio || "",
          },
          idReq,
        );
      }
    }
    refreshColaTable();
    refreshHistorico();
  }

  async function parseJsonResponse(resp) {
    const text = await resp.text();
    try {
      return JSON.parse(text);
    } catch {
      if (resp.status === 501) {
        throw new Error(
          "Servidor antiguo en puerto 8765 (no tiene API de casos).\n\n" +
            "Cierre la ventana negra del servidor y ejecute abrir-app.bat de nuevo.",
        );
      }
      const preview = text.replace(/\s+/g, " ").trim().slice(0, 120);
      throw new Error(`Respuesta no JSON (${resp.status}): ${preview || "(vacía)"}`);
    }
  }

  function showServerOldAlert(html) {
    $("#alertServerOld")?.remove();
    const el = document.createElement("div");
    el.id = "alertServerOld";
    el.className = "alert alert-warning";
    el.innerHTML = html;
    $(".app-header")?.prepend(el);
  }

  async function checkServerHealth() {
    if (location.protocol === "file:") return;
    try {
      const resp = await fetch("/api/health");
      const data = await parseJsonResponse(resp);
      if (!data.features?.includes("caso") || !data.features?.includes("chatSinOpenAI")) {
        showServerOldAlert(
          "<strong>Servidor viejo.</strong> Cierre la ventana negra y ejecute <code>abrir-app.bat</code>.",
        );
        return;
      }
      if (!data.features?.includes("imagenesAnalisis")) {
        showServerOldAlert(
          "<strong>Servidor sin capturas.</strong> Ejecute <code>reiniciar-servidor.bat</code> "
          + "(como administrador si hay servicio Windows) y recargue con Ctrl+F5. "
          + "Las capturas del paso Requerimiento no funcionarán hasta reiniciar.",
        );
      }
      if (!data.features?.includes("archivosAnalisis")) {
        showServerOldAlert(
          "<strong>Servidor sin archivos de normativa.</strong> Ejecute <code>reiniciar-servidor.bat</code> "
          + "y recargue con Ctrl+F5 para adjuntar resoluciones/circulares.",
        );
      }
    } catch {
      /* servidor no responde health — activarAnalisis mostrará el error concreto */
    }
  }

  async function activarAnalisis() {
    if (!isFormComplete()) return alert("Complete el formulario y el paso SQL (métodos documentados o .sql en la carpeta del caso).");

    const data = collectData();
    const idCaso = data.identificacion.idCaso;

    if (location.protocol === "file:") {
      return alert(
        "Para activar el caso en disco ejecute abrir-app.bat.\n\n" +
          "El agente leerá activo/{id-caso}/ sin pegar prompt.",
      );
    }

    try {
      const resp = await fetch("/api/caso/activar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      const result = await parseJsonResponse(resp);
      if (!resp.ok || !result.ok) throw new Error(result.error || "Error al activar");

      QrysHistorico.upsert({
        idCaso,
        idReq: data.identificacion.idReq,
        proyecto: data.proyecto.nombre,
        modulo: data.proyecto.modulo,
        fecha: data.identificacion.fecha,
        estado: "en_analisis",
        archivoCola: archivoColaVinculado,
      });
      if (archivoColaVinculado) QrysCola.updateEstado(archivoColaVinculado, "en_analisis", {}, idReqVinculado);
      refreshColaTable();
      await guardarCorreoEnLista(val("#desarrollador"), val("#correoDestino"));

      alert(
        "Fase 1 activada.\n\n" +
          "El agente en Cursor lee activo/" +
          idCaso +
          "/ (Qrystalos2, conocimiento/ y activo/" + idCaso + "/sql/ si aplica).\n" +
          "No se abre el Chat solo: use la pestaña Chat cuando quiera escribir.\n" +
          "La propuesta queda en dictamenes/.",
      );
    } catch (e) {
      alert(`No se pudo activar:\n${e.message}\n\n¿Ejecutó abrir-app.bat?`);
    }
  }

  async function abrirChatDesdeCola(archivoCola, idReq) {
    const item = QrysCola.getItem(archivoCola, idReq);
    const req = idReq || item?.parsed?.idReq || item?.idReqSeleccionado || "";
    if (req) setVal("#idReq", req);
    if (item) {
      archivoColaVinculado = archivoCola;
      idReqVinculado = req;
    }
    const casos = await QrysChat.listarCasosActivos();
    const idCaso = QrysChat.resolverIdCaso(casos, req, item?.parsed?.idCaso);
    if (idCaso) setVal("#idCaso", idCaso);
    abrirChatCaso(idCaso || val("#idCaso"));
  }

  function updateCorruptAlert() {
    const corrupt = QrysCola.findCorruptEntries();
    const el = $("#colaCorruptaAlert");
    if (!corrupt.length) {
      el.classList.add("hidden");
      el.innerHTML = "";
      return;
    }
    el.classList.remove("hidden");
    el.innerHTML = `<strong>${corrupt.length} entrada(s) incompleta(s)</strong> — probable registro antiguo. Pulse <em>Quitar entradas corruptas</em> o vuelva a registrar con Examinar…`;
  }

  function bindCola() {
    const inputCola = $("#colaUpload");
    $("#btnColaUpload")?.addEventListener("click", () => inputCola?.click());
    inputCola?.addEventListener("change", () => {
      const file = inputCola.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        inputCola.value = "";
        const nombre = $("#colaUploadNombre");
        if (nombre) nombre.textContent = file.name;
        void (async () => {
          try {
            const canonical = QrysCola.normalizeFileName(file.name);
            const parseResult = QrysCola.parseHtmlAvalasesor(reader.result, canonical);
            guardarHtmlEnCola(canonical, reader.result);
            await procesarRegistroCola(canonical, reader.result, parseResult, file.name);
          } catch (e) {
            alert(`No se pudo registrar la cola:\n${e.message || e}`);
          }
        })();
      };
      reader.onerror = () => {
        inputCola.value = "";
        alert("No se pudo leer el archivo HTML.");
      };
      reader.readAsText(file, "UTF-8");
    });

    $("#btnRegistrarColaManual").addEventListener("click", () => registrarColaManual());
    $("#btnLimpiarCorruptos").addEventListener("click", () => {
      const n = QrysCola.removeCorruptEntries();
      refreshColaTable();
      updateCorruptAlert();
      alert(n ? `Se quitaron ${n} entrada(s) corrupta(s).` : "No había entradas corruptas.");
    });
    $("#btnVaciarCola").addEventListener("click", () => {
      if (!confirm("¿Vaciar toda la cola de trabajo?")) return;
      QrysCola.clearCola();
      refreshColaTable();
      updateCorruptAlert();
    });
    $("#filtroColaReq")?.addEventListener("input", (e) => {
      const btn = $("#btnLimpiarFiltroCola");
      if (btn) btn.style.display = e.target.value ? "inline-flex" : "none";
      refreshColaTable();
    });
    $("#chkVerTerminadosCola")?.addEventListener("change", () => refreshColaTable());
    $("#btnLimpiarFiltroCola")?.addEventListener("click", () => {
      setVal("#filtroColaReq", "");
      const btn = $("#btnLimpiarFiltroCola");
      if (btn) btn.style.display = "none";
      refreshColaTable();
      $("#filtroColaReq")?.focus();
    });

    $("#btnCancelSelReq").addEventListener("click", cerrarModalSelReq);
    $("#btnConfirmSelReq").addEventListener("click", confirmarModalSelReq);
    $("#modalSelReq").addEventListener("click", (e) => {
      if (e.target.id === "modalSelReq") cerrarModalSelReq();
    });
  }

  async function registrarColaManual() {
    const name = QrysCola.normalizeFileName($("#colaArchivoManual").value.trim());
    if (!name) return alert("Indique el nombre del archivo en cola/");

    if (location.protocol === "file:") {
      return alert(
        "En modo file:// use Examinar… para cargar el archivo.\n\n" +
          "Alternativa: ejecute servir-app.bat y abra http://localhost:8765/app/",
      );
    }

    try {
      const resp = await fetch(`../cola/${encodeURIComponent(name)}`);
      if (!resp.ok) throw new Error("No se pudo leer el archivo");
      const html = await resp.text();
      const parseResult = QrysCola.parseHtmlAvalasesor(html, name);
      procesarRegistroCola(name, html, parseResult);
    } catch {
      alert(`No se pudo leer cola/${name}.\n\nUse Examinar… para cargar el archivo manualmente.`);
    }
  }

  async function guardarHtmlEnCola(fileName, html) {
    if (location.protocol === "file:" || !html) return;
    try {
      await fetch("/api/cola/html", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: fileName, html }),
      });
    } catch {
      /* el parseo no depende de guardar en cola/ */
    }
  }

  async function asegurarColaGuardada(guardado) {
    if (!guardado || location.protocol === "file:") return true;
    const saved = await guardado;
    if (saved && saved.ok === false) {
      alert(
        "La página se leyó, pero la cola no se guardó en el servidor.\n\n" +
          (saved.error || "Error desconocido") +
          "\n\nVuelva a seleccionar el archivo.",
      );
      return false;
    }
    return true;
  }

  async function procesarRegistroCola(fileName, html, parseResult, originalName) {
    if (!parseResult.filas?.length) {
      const n = (String(html || "").match(/\b010\d{7}\b/g) || []).length;
      return alert(
        (parseResult.mensaje || "No se detectaron requerimientos en el HTML.") +
          `\n\nArchivo: ${originalName || fileName}\nIDs 010… en el texto: ${n}`,
      );
    }

    const sugerido = QrysCola.suggestColaFileName(originalName || fileName, parseResult);
    const copiarNota =
      sugerido !== (originalName || fileName)
        ? `\n\nCopie el archivo a:\n${QrysCola.PATH_COLA}${sugerido}`
        : `\n\nCopie el archivo a:\n${QrysCola.PATH_COLA}${fileName}`;

    if (parseResult.esLista) {
      const bulk = QrysCola.addAllToCola({ fileName, html, parseResult });
      const guardada = await asegurarColaGuardada(bulk.guardado);
      refreshColaTable();
      updateCorruptAlert();
      if (!guardada) return;

      if (!bulk.registrados.length) {
        let msg =
          `Sin REQ nuevos. Se actualizaron los datos de ${bulk.omitidos.length} REQ ya en cola (proyecto, módulo, rama…).`;
        if (bulk.terminados?.length) {
          msg +=
            `\n\nMarcados como terminados (ya no aparecen en la lista): ${bulk.terminados.length}\n` +
            bulk.terminados.map((i) => i.idReqSeleccionado || i.parsed?.idReq).join(", ");
          msg +=
            `\n\nNota: si la lista tiene varias páginas, registre todas las abiertas; si no, REQ de otras páginas se marcarán terminados.`;
        }
        if (bulk.omitidos.length) {
          msg += `\n\nEn lista: ` + bulk.omitidos.map((r) => r.idReq).join(", ");
        }
        return alert(msg);
      }

      let msg =
        `Registrados ${bulk.registrados.length} REQ nuevos en la cola (orden igual a ixonline).\n\n` +
        bulk.registrados
          .sort((a, b) => (a.ordenPagina ?? 0) - (b.ordenPagina ?? 0))
          .map((i) => `#${(i.ordenPagina ?? 0) + 1} ${i.parsed?.idReq} — ${i.parsed?.proyecto || ""}`)
          .join("\n");

      if (bulk.omitidos.length) {
        msg +=
          `\n\nYa en cola (datos actualizados) ${bulk.omitidos.length}: ` +
          bulk.omitidos.map((r) => r.idReq).join(", ");
      }

      if (bulk.terminados?.length) {
        msg +=
          `\n\nTerminados (ausentes en la lista subida) ${bulk.terminados.length}: ` +
          bulk.terminados.map((i) => i.idReqSeleccionado || i.parsed?.idReq).join(", ");
        msg +=
          `\n\nNota: si avalasesor tiene varias páginas, registre el HTML completo (todas las páginas abiertas); si no, REQ de otras páginas también se marcarán terminados.`;
      }

      msg += `\n\nTrabaje uno a uno con **Abrir** en la tabla.${copiarNota}`;
      if (window.QrysDesarrolladores) {
        const sync = await QrysDesarrolladores.sync();
        if (sync.creados?.length) {
          msg += `\n\nDesarrolladores nuevos en la lista: ${sync.creados.join(", ")}.`;
        }
      }
      return alert(msg);
    }

    const result = QrysCola.addToCola({
      fileName,
      html,
      parseResult,
      idReqSeleccionado: parseResult.filas[0].idReq,
    });
    const guardada = await asegurarColaGuardada(result.guardado);
    refreshColaTable();
    updateCorruptAlert();
    if (!guardada) return;
    if (result.duplicate) {
      return alert(
        `El REQ ${result.idReq} ya está en la cola.\n\nEstado: ${QrysCola.labelEstado(result.item.estado)}`,
      );
    }
    alert(`${parseResult.mensaje}\n\nREQ: ${result.item.parsed?.idReq}${copiarNota}`);
  }

  function abrirModalSeleccionReq(archivoCola, parseResultArg, htmlArg, esRegistro, copiarNota, omitidos) {
    const item = QrysCola.getItem(archivoCola);
    const parseResult = parseResultArg || item?.parseResult;
    if (!parseResult?.filas?.length) {
      return alert("No hay filas parseadas. Vuelva a registrar el archivo con Examinar…");
    }

    modalContext = {
      archivoCola,
      parseResult,
      html: htmlArg || "",
      esRegistro: !!esRegistro,
      copiarNota: copiarNota || "",
    };

    const sel = $("#selectIdReq");
    sel.innerHTML = parseResult.filas
      .map((r) => {
        const ya = QrysCola.findExistingEntry(archivoCola, r.idReq);
        const tag = ya ? " [ya en cola]" : "";
        return `<option value="${escAttr(r.idReq)}" ${ya ? "disabled" : ""}>${esc(r.idReq)} — ${esc(r.proyecto)} — ${esc(r.moduloNombre?.slice(0, 60) || r.area)}${tag}</option>`;
      })
      .join("");

    const hint = $("#modalSelReq .hint");
    if (hint) {
      hint.textContent = omitidos
        ? `Solo se muestran REQ nuevos (${omitidos} ya registrados omitidos). Elija uno:`
        : "Esta página contiene varios requerimientos. Elija uno:";
    }
    $("#modalSelReq").classList.remove("hidden");
  }

  function cerrarModalSelReq() {
    modalContext = null;
    $("#modalSelReq").classList.add("hidden");
  }

  function confirmarModalSelReq() {
    if (!modalContext) return;
    const idReq = $("#selectIdReq").value;
    if (!idReq) return alert("Seleccione un ID REQ");

    const ctx = modalContext;
    const result = QrysCola.addToCola({
      fileName: ctx.archivoCola,
      html: ctx.html,
      parseResult: ctx.parseResult,
      idReqSeleccionado: idReq,
    });
    refreshColaTable();
    updateCorruptAlert();
    cerrarModalSelReq();

    if (result.duplicate) {
      return alert(`El REQ ${idReq} ya está en la cola. No se volvió a registrar.`);
    }

    if (ctx.esRegistro) {
      alert(`Registrado REQ ${idReq}.${ctx.copiarNota || `\n\nArchivo: ${QrysCola.PATH_COLA}${ctx.archivoCola}`}`);
    }
  }

  async function abrirDesdeHistorico(idCaso) {
    const row = QrysHistorico.load().find((h) => h.idCaso === idCaso);
    if (!row) return;
    vaciarFormularioSiCambia(row.idReq, row.idCaso);
    setVal("#idCaso", row.idCaso);
    setVal("#idReq", row.idReq);
    setVal("#proyecto", row.proyecto);
    setVal("#moduloNombre", row.modulo);
    setVal("#fecha", row.fecha);
    if (row.archivoCola) {
      archivoColaVinculado = row.archivoCola;
      $("#archivoColaVinculado").textContent = QrysCola.PATH_COLA + row.archivoCola;
      $("#alertOrigenCola").hidden = false;
    }
    const cargada = await cargarSolicitudCaso(idCaso);
    if (!cargada) {
      updateSqlPath();
      updateAll();
    }
    switchToFormulario();
    goStep(1);
    refreshCorreoEstado();
  }

  async function cargarSolicitudCaso(idCaso, opts) {
    if (location.protocol === "file:" || !idCaso) return false;
    const sondeo = !!opts?.sondeo;
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, { cache: "no-store" });
      if (!resp.ok) return false;
      const data = await resp.json();
      const sol = data.solicitud;
      if (!sol || !sol.identificacion) return false;
      applyStorageData({
        ...sol,
        _archivoColaVinculado: sol.cola?.archivoCola || archivoColaVinculado,
        _idReqVinculado: sol.cola?.idReq || sol.identificacion?.idReq || idReqVinculado,
      }, { sondeo });
      if (sondeo) return true;
      if (data.fase1Cerrada && sol.sql) {
        if ($("#chkSqlColocados")) $("#chkSqlColocados").checked = true;
      }
      if (sol.sql?.archivosEsperados?.length && !sqlChecklistState) {
        renderListaSqlNombres();
      }
      updateSqlPath();
      saveToStorage();
      updateAll();
      await refreshCorreoEstado();
      return true;
    } catch {
      return false;
    }
  }

  function switchToFormulario() {
    $$(".main-tab").forEach((t) => t.classList.toggle("active", t.dataset.view === "formulario"));
    $$(".view").forEach((v) => v.classList.toggle("active", v.id === "view-formulario"));
  }

  function resetFormFields(clearStorage) {
    vaciarFormulario();
    if (clearStorage) localStorage.removeItem(STORAGE_KEY);
  }

  function vaciarFormulario() {
    const form = $("#formSolicitud");
    if (form) form.reset();
    archivoColaVinculado = null;
    idReqVinculado = null;
    sqlChecklistState = null;
    metodosKbState = emptyMetodosKb();
    criteriosMeta = window.QrysCriterios ? QrysCriterios.emptyMeta() : {};
    if ($("#chkCorreoEnviado")) $("#chkCorreoEnviado").checked = false;
    setVal("#fechaEnvioCorreo", "");
    brechaAnalisis = null;
    imagenesAnalisis = [];
    archivosAnalisis = [];
    solicitudOrigen = null;
    pintarSolicitudOrigen();
    diagramaFlujo = null;
    mockupsFormDraft = [];
    mockupsFormMeta = { mockups: [], sugeridos: [], plantillas: [], correoHint: "" };
    mockupsFormDirty = false;
    mockupsFormPreviewRuta = "";
    mockupsFormCasoId = "";
    clearMockupFormPreview();
    renderImagenesAnalisis();
    renderArchivosAnalisis();
    renderDiagramaFlujo();
    renderMockupsForm();
    renderBrechaAnalisis(null);
    const hintBrecha = $("#brechaAnalisisHint");
    if (hintBrecha) hintBrecha.textContent = "El agente (Cursor) contrasta el REQ con su análisis y lista qué le falta revisar. No usa OpenAI.";
    $("#alertOrigenCola").hidden = true;
    $("#archivoColaVinculado").textContent = "—";
    if ($("#chkSqlColocados")) $("#chkSqlColocados").checked = false;
    if ($("#chkUsarDocSp")) $("#chkUsarDocSp").checked = false;
    if ($("#chkSqlKbTodos")) $("#chkSqlKbTodos").checked = false;
    if ($("#sqlMetodosKbLista")) $("#sqlMetodosKbLista").innerHTML = "";
    if ($("#sqlKbEstado")) $("#sqlKbEstado").textContent = "";
    if ($("#opcionesLista")) $("#opcionesLista").innerHTML = "";
    addOpcion("", "");
    ocultarSugerenciaCriterios();
    if ($("#listaArchivosSql")) $("#listaArchivosSql").innerHTML = "";
    if ($("#sqlLeidoEstado")) $("#sqlLeidoEstado").textContent = "";
    $("#sqlLoadError")?.classList.add("hidden");
    setDefaultDates();
  }

  function vaciarFormularioSiCambia(nuevoIdReq, nuevoIdCaso) {
    const actualReq = String(val("#idReq") || idReqVinculado || "").trim();
    const actualCaso = String(val("#idCaso") || "").trim();
    const req = String(nuevoIdReq || "").trim();
    const caso = String(nuevoIdCaso || "").trim();
    const mismo = (req && req === actualReq) || (caso && caso === actualCaso);
    if (!mismo) vaciarFormulario();
  }

  function compactarTextoIa(texto) {
    return String(texto || "")
      .replace(/\r\n/g, "\n")
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{2,}/g, "\n")
      .trim();
  }

  async function abrirDesdeCola(archivoCola, idReq) {
    const item = QrysCola.getItem(archivoCola, idReq);
    if (!item?.parsed) {
      return abrirModalSeleccionReq(archivoCola);
    }

    const p = item.parsed;
    vaciarFormularioSiCambia(p.idReq || idReq, p.idCaso);
    archivoColaVinculado = archivoCola;
    idReqVinculado = item.idReqSeleccionado || p.idReq;
    setVal("#idReq", p.idReq);
    setVal("#idCaso", p.idCaso);
    setVal("#fecha", p.fecha || new Date().toISOString().slice(0, 10));
    setVal("#proyecto", p.proyecto);
    setVal("#moduloNombre", p.moduloNombre);
    setVal("#area", p.area);
    setVal("#asesor", p.asesor);
    setVal("#rama", p.rama);
    setVal("#desarrollador", p.desarrollador);
    setVal("#soporteProyecto", p.soporteProyecto || "");
    setVal("#prioridad", p.prioridad || "2 - Media");
    if (p.estado) setVal("#estadoReq", p.estado);
    if (p.aval) setVal("#aval", p.aval);
    if (p.requerimientoExtraido) setVal("#requerimiento", p.requerimientoExtraido);
    if (p.moduloNombre) setVal("#titulo", p.moduloNombre.slice(0, 120));
    $("#archivoColaVinculado").textContent = item.rutaCola + (idReqVinculado ? ` (${idReqVinculado})` : "");
    $("#alertOrigenCola").hidden = false;
    QrysCola.updateEstado(archivoCola, "en_analisis", {}, idReqVinculado);
    refreshColaTable();
    switchToFormulario();
    goStep(1);
    if (p.idCaso) await cargarSolicitudCaso(p.idCaso);
    else {
      updateSqlPath();
      saveToStorage();
      updateAll();
    }
    refreshCorreoEstado();
  }

  function pintarSolicitudOrigen() {
    const el = $("#solicitudOrigenEstado");
    if (!el) return;
    if (!solicitudOrigen?.id) {
      el.textContent = "Ninguna solicitud asociada.";
      return;
    }
    const tit = solicitudOrigen.titulo ? ` — ${solicitudOrigen.titulo}` : "";
    el.textContent = `Asociada ${solicitudOrigen.id}${tit}`;
  }

  function prioridadDesdeSolicitud(p) {
    const t = String(p || "").toLowerCase();
    if (t.includes("crit") || t.includes("alta")) return "1 - Alta";
    if (t.includes("baja")) return "3 - Baja";
    return "2 - Media";
  }

  function textoRequerimientoDesdeSolicitud(sol) {
    const bloques = [];
    if ((sol.necesidad || "").trim()) bloques.push(sol.necesidad.trim());
    if ((sol.hoy || "").trim()) bloques.push(`Cómo opera hoy\n${sol.hoy.trim()}`);
    if ((sol.propuesta || "").trim()) bloques.push(`Qué se espera\n${sol.propuesta.trim()}`);
    if ((sol.justificacion || "").trim()) bloques.push(`Por qué el camino actual no alcanza\n${sol.justificacion.trim()}`);
    return bloques.join("\n\n");
  }

  function cambioSimpleDesdeSolicitud(sol) {
    const hoy = (sol.hoy || "").trim();
    const prop = (sol.propuesta || "").trim();
    if (hoy && prop) return `Hoy: ${hoy}\n\nPropuesta: ${prop}`;
    return prop || hoy;
  }

  function sugerirIdCaso(sol) {
    const fecha = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const base = String(sol.titulo || "caso")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 36);
    const corte = base.lastIndexOf("-");
    if (corte > 12) base = base.slice(0, corte);
    return `${fecha}-${base || "caso"}`;
  }

  function setSiTexto(sel, valor) {
    const t = String(valor || "").trim();
    if (t) setVal(sel, t);
  }

  async function cargarListaSolicitudes() {
    if (solicitudesCache) return solicitudesCache;
    const resp = await fetch("/api/solicitar", { cache: "no-store" });
    const data = await resp.json();
    solicitudesCache = data.items || [];
    return solicitudesCache;
  }

  function solicitudCerradaSinReq(it) {
    const cerrada = it.cerrado === true || String(it.estado || "").toLowerCase() === "cerrado";
    return cerrada && !String(it.avalReq || "").trim();
  }

  function filtrarSolicitudes(q, items) {
    const base = (items || []).filter(solicitudCerradaSinReq);
    const n = String(q || "").trim().toLowerCase();
    const lista = n
      ? base.filter((it) => {
          const blob = `${it.id || ""} ${it.titulo || ""} ${it.proyecto || ""} ${it.procesoId || ""}`.toLowerCase();
          return blob.includes(n);
        })
      : base;
    return lista.slice(0, n ? 12 : 8);
  }

  function pintarResultadosSolicitud(items) {
    const box = $("#buscarSolicitudResultados");
    if (!box) return;
    box.hidden = false;
    if (!items.length) {
      const vacio = String($("#buscarSolicitudReq")?.value || "").trim()
        ? "Ninguna solicitud cerrada sin requerimiento coincide."
        : "No hay solicitudes cerradas sin requerimiento.";
      box.innerHTML = `<p class="hint compact" style="margin:0.4rem 0.65rem;">${vacio}</p>`;
      return;
    }
    box.innerHTML = items.map((it) => {
      const meta = [it.id, it.proyecto, it.estado].filter(Boolean).join(" · ");
      return `<button type="button" class="sr-asociar-item" data-id="${escAttr(it.id)}"><strong>${esc(it.titulo || it.id)}</strong><span>${esc(meta)}</span></button>`;
    }).join("");
    box.querySelectorAll(".sr-asociar-item").forEach((btn) => {
      btn.addEventListener("click", () => asociarSolicitud(btn.dataset.id));
    });
  }

  async function asociarSolicitud(id) {
    const box = $("#buscarSolicitudResultados");
    if (box) box.hidden = true;
    const estado = $("#solicitudOrigenEstado");
    if (estado) estado.textContent = "Trayendo la solicitud…";
    let data = {};
    let resp;
    try {
      resp = await fetch(`/api/solicitar/${encodeURIComponent(id)}`, { cache: "no-store" });
      data = await resp.json();
    } catch {
      if (estado) estado.textContent = "No se pudo leer la solicitud.";
      return;
    }
    const sol = data.solicitud || data;
    if (!resp.ok || !sol?.id) {
      if (estado) estado.textContent = data.error || "No se pudo leer la solicitud.";
      return;
    }
    if (val("#requerimiento").trim()) {
      const ok = confirm(`¿Traer ${sol.id}?\n\nSe reemplazan título, requerimiento, criterios, análisis y documentos con los de esa solicitud.`);
      if (!ok) {
        pintarSolicitudOrigen();
        return;
      }
    }
    if (!val("#idCaso")) setVal("#idCaso", sugerirIdCaso(sol));
    if (!val("#idReq") && sol.aval?.idReq) setVal("#idReq", sol.aval.idReq);
    setSiTexto("#titulo", sol.titulo);
    setSiTexto("#proyecto", sol.proyecto);
    setSiTexto("#moduloNombre", sol.modulo);
    if ((sol.prioridad || "").trim()) setVal("#prioridad", prioridadDesdeSolicitud(sol.prioridad));
    setSiTexto("#requerimiento", textoRequerimientoDesdeSolicitud(sol));
    setSiTexto("#criteriosAceptacion", sol.criterios);
    setSiTexto("#alcance", sol.alcance);
    setSiTexto("#restricciones", sol.restricciones);
    setSiTexto("#analisis", sol.analisis);
    setSiTexto("#recomendacion", sol.recomendacion);
    setSiTexto("#cambioPropuestoSimple", cambioSimpleDesdeSolicitud(sol));
    setSiTexto("#cambioPropuestoSql", sol.cambioPropuestoSql);
    if (sol.procesoId) {
      metodosKbState.procesoId = sol.procesoId;
      const sel = $("#sqlProcesoId");
      if (sel) sel.value = sol.procesoId;
    }
    renderAnCriteriosDinamicosDesdeTexto(true);
    solicitudOrigen = { id: sol.id, titulo: sol.titulo || "" };
    const idCaso = val("#idCaso");
    let nArch = 0;
    let avisoArch = "";
    try {
      const traidos = await copiarDocumentosSolicitud(idCaso, sol);
      const nombres = new Set(traidos.map((a) => a.nombre));
      archivosAnalisis = archivosAnalisis.filter((a) => !nombres.has(a.nombre)).concat(traidos);
      renderArchivosAnalisis();
      nArch = traidos.length;
      if (traidos.length) {
        const fold = $("#foldCapturasReq");
        if (fold) fold.open = true;
      }
    } catch (err) {
      avisoArch = err?.message || "No se copiaron los documentos.";
    }
    const idReqForm = val("#idReq");
    if (solicitudesCache && idReqForm) {
      const row = solicitudesCache.find((i) => i.id === sol.id);
      if (row) row.avalReq = idReqForm;
    }
    updateSqlPath();
    saveToStorage();
    updateAll();
    const partes = [`Asociada ${sol.id}. Los textos quedaron en el caso.`];
    if (!avisoArch && nArch) partes.push(`${nArch} documento(s) en normativa.`);
    if (!avisoArch && !nArch) partes.push("Esta solicitud no tenía documentos.");
    if (avisoArch) partes.push(avisoArch);
    if (estado) estado.textContent = partes.join(" ");
    const input = $("#buscarSolicitudReq");
    if (input) input.value = "";
  }

  async function blobADataUrl(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("No se pudo leer un documento"));
      reader.readAsDataURL(blob);
    });
  }

  async function copiarDocumentosSolicitud(idCaso, sol) {
    const lista = (sol.archivos || []).filter((a) => a?.nombre && !String(a.nombre).endsWith(".extracto.txt"));
    const body = {
      idSolicitud: sol.id,
      idReq: val("#idReq"),
      titulo: val("#titulo"),
    };
    const r2 = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/desde-solicitud`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    let out = {};
    try { out = await r2.json(); } catch { out = {}; }
    if (r2.ok && out.ok) return out.archivos || [];
    if (r2.status !== 404) {
      throw new Error(out.error || "No se copiaron los documentos.");
    }
    const traidos = [];
    for (const a of lista) {
      const url = a.url || `/api/solicitar/${encodeURIComponent(sol.id)}/archivo/${encodeURIComponent(a.nombre)}`;
      const fr = await fetch(url);
      if (!fr.ok) continue;
      const dataUrl = await blobADataUrl(await fr.blob());
      const up = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/archivo`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: a.nombre, dataUrl, tipo: a.tipo || "normativa" }),
      });
      const meta = await up.json().catch(() => ({}));
      if (up.ok && meta.archivo) traidos.push(meta.archivo);
    }
    return traidos;
  }

  function bindBuscarSolicitud() {
    const input = $("#buscarSolicitudReq");
    const box = $("#buscarSolicitudResultados");
    if (!input || !box) return;
    let timer = null;
    const buscar = async () => {
      try {
        const items = await cargarListaSolicitudes();
        pintarResultadosSolicitud(filtrarSolicitudes(input.value, items));
      } catch {
        box.hidden = false;
        box.innerHTML = `<p class="hint compact" style="margin:0.4rem 0.65rem;">No se pudo leer la lista de solicitudes.</p>`;
      }
    };
    input.addEventListener("input", () => {
      clearTimeout(timer);
      timer = setTimeout(buscar, 180);
    });
    input.addEventListener("focus", () => {
      if (!input.value.trim() && box.hidden) buscar();
    });
    document.addEventListener("click", (e) => {
      if (!e.target.closest("#cardSolicitudOrigen")) box.hidden = true;
    });
  }

  function bindForm() {
    $("#btnNext").addEventListener("click", () => goStep(currentStep + 1));
    $("#btnPrev").addEventListener("click", () => goStep(currentStep - 1));
    $("#btnNuevo").addEventListener("click", resetForm);
    $("#btnAddOpcion").addEventListener("click", () => addOpcion("", ""));
    $("#btnGenerarListaSql").addEventListener("click", () => {
      sqlChecklistState = null;
      $("#sqlLeidoEstado").textContent = "";
      renderListaSqlNombres();
      updateAll();
    });
    $("#btnLeerCarpetaSql").addEventListener("click", () => leerCarpetaSql());
    bindBuscarSolicitud();
    const btnTraerKb = $("#btnTraerMetodosKb");
    if (btnTraerKb) btnTraerKb.addEventListener("click", () => traerMetodosKb(false));
    const selProc = $("#sqlProcesoId");
    if (selProc) {
      selProc.addEventListener("change", () => {
        metodosKbState.procesoId = selProc.value;
        if (selProc.value) traerMetodosKb(true);
      });
    }
    const chkDoc = $("#chkUsarDocSp");
    if (chkDoc) chkDoc.addEventListener("change", updateAll);
    const buscarKb = $("#sqlKbBuscar");
    if (buscarKb) {
      buscarKb.addEventListener("input", () => renderMetodosKbLista());
    }
    const chkTodosKb = $("#chkSqlKbTodos");
    if (chkTodosKb) {
      chkTodosKb.addEventListener("change", () => {
        metodosKbState.verTodos = !!chkTodosKb.checked;
        renderMetodosKbLista();
      });
    }
    $("#btnGuardarJson").addEventListener("click", downloadJson);
    const btnZip = $("#btnDescargarZip");
    if (btnZip) btnZip.addEventListener("click", downloadZip);
    $("#btnActivarAnalisis").addEventListener("click", () => activarAnalisis());
    const btnCopiar = $("#btnCopiarPrompt");
    if (btnCopiar) btnCopiar.addEventListener("click", copyPrompt);
    $("#btnCopiarPromptPruebasSql")?.addEventListener("click", () => copyPromptPruebasSql());
    $("#btnCopiarPromptValidarDev")?.addEventListener("click", () => copyPromptValidarDesarrollo());
    $("#btnArchivarSql").addEventListener("click", () => archivarSql());
    $("#chkSqlColocados").addEventListener("change", updateAll);
    $("#idReq").addEventListener("input", updateSqlPath);
    $("#idCaso")?.addEventListener("change", () => onIdentificacionCasoChanged());
    $("#idCaso")?.addEventListener("blur", () => onIdentificacionCasoChanged());
    bindCorreoDev();
    bindCriterios();
    bindCambioSimplePreview();
    bindImagenesAnalisis();
    bindArchivosAnalisis();
    bindDiagramaFlujo();
    bindMockupsForm();
    $("#btnCopiarPromptDiagrama")?.addEventListener("click", () => copyPromptDiagrama());
    $("#btnAnalizarRequerimiento")?.addEventListener("click", () => analizarRequerimiento());

    $$(".step").forEach((btn) => {
      btn.addEventListener("click", () => goStep(Number(btn.dataset.step)));
    });

    $("#formSolicitud").addEventListener("input", () => {
      saveToStorage();
      updateAll();
    });

    $("#objetosSolicitados").addEventListener("blur", () => {
      if (!sqlChecklistState) renderListaSqlNombres();
    });
  }

  async function refrescarBadgeFaseCerrada() {
    const idCaso = val("#idCaso");
    const badge = $("#estadoFormulario");
    if (!idCaso || !badge || location.protocol === "file:") return;
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/estado`, { cache: "no-store" });
      if (!resp.ok) return;
      const est = await resp.json();
      if (est.fase1Cerrada) {
        badge.textContent = "F1 cerrada";
        badge.className = "badge badge-listo";
      }
    } catch {
      /* badge actual */
    }
  }

  function collectCorreo() {
    return {
      enviado: !!$("#chkCorreoEnviado")?.checked,
      fechaEnvio: val("#fechaEnvioCorreo"),
      destinatario: val("#correoDestino"),
    };
  }

  function applyCorreoUI(c) {
    syncingCorreo = true;
    if ($("#chkCorreoEnviado")) $("#chkCorreoEnviado").checked = !!c.enviado;
    setVal("#fechaEnvioCorreo", c.fechaEnvio || "");
    if (c.destinatario) setVal("#correoDestino", c.destinatario);
    const btn = $("#btnEnviarCorreo");
    if (btn) btn.textContent = c.enviado ? "Reenviar correo" : "Enviar correo";
    const hint = $("#correoEnvioHint");
    const card = $("#cardCorreoDev");
    const ultima = (c.copias && c.copias[0]) || null;
    const dest = (c.destinatario || val("#correoDestino") || "").trim();
    const nombre = (c.desarrollador || val("#desarrollador") || "").trim();
    if (hint) {
      if (c.enviado) {
        const extra = c.reenvios ? ` · ${c.reenvios} reenvío(s)` : "";
        const copia = ultima?.carpeta ? ` · copia ${ultima.carpeta}` : "";
        hint.textContent = `Enviado el ${c.fechaEnvio || "—"} a ${dest || "—"}${extra}${copia}.`;
      } else if (c.tieneDictamen === false) {
        hint.textContent = "Aún no hay dictamen HTML para adjuntar (dictamenes/{idCaso}.html).";
      } else if (!dest) {
        hint.textContent = nombre
          ? `Dictamen listo. Falta el correo de ${nombre} en la lista — escríbalo arriba y se guarda solo.`
          : "Dictamen listo. Indique el correo destino del desarrollador.";
      } else {
        const mock = c.tieneMockups && c.mockups?.length
          ? ` · adjuntos: dictamen + ${c.mockups.length} mockup(s)`
          : "";
        hint.textContent = `Listo para enviar a ${dest}${nombre ? ` (${nombre})` : ""}${mock}. Al enviar se marcan check, fecha y cola Terminado.`;
      }
    }
    if (card) {
      card.classList.toggle("correo-ok", !!c.enviado);
      card.classList.toggle("correo-pendiente", !c.enviado);
    }
    const mockHint = $("#correoMockupsHint");
    if (mockHint) {
      if (c.tieneMockups && c.mockups?.length) {
        const n = c.mockups.length;
        const rutas = c.mockups.map((m) => (typeof m === "string" ? m : m.ruta || "")).filter(Boolean);
        mockHint.innerHTML = `Mockups al correo: <strong>${n}</strong> HTML (${esc(rutas.join(", "))}). Ajuste en pestaña <strong>Chat</strong>.`;
      } else {
        mockHint.textContent =
          "Mockups: configure en la pestaña Chat → bloque «Mockups — adjuntos al correo».";
      }
    }
    syncingCorreo = false;
  }

  async function refreshCorreoEstado() {
    const idCaso = val("#idCaso");
    if (!window.QrysDesarrolladores || !idCaso) {
      applyCorreoUI({
        ...collectCorreo(),
        desarrollador: val("#desarrollador"),
        tieneDictamen: undefined,
      });
      return;
    }
    try {
      const st = await QrysDesarrolladores.estadoCorreo(idCaso);
      if (!st || st.error) {
        if (!val("#correoDestino") && val("#desarrollador")) {
          const lista = await QrysDesarrolladores.listar();
          const mail = QrysDesarrolladores.correoDeLista(lista, val("#desarrollador"));
          if (mail) setVal("#correoDestino", mail);
        }
        applyCorreoUI({
          ...collectCorreo(),
          destinatario: val("#correoDestino"),
          desarrollador: val("#desarrollador"),
        });
        return;
      }
      if (!st.destinatario && val("#desarrollador")) {
        const lista = await QrysDesarrolladores.listar();
        st.destinatario = QrysDesarrolladores.correoDeLista(lista, val("#desarrollador"));
      }
      if (!st.desarrollador) st.desarrollador = val("#desarrollador");
      applyCorreoUI(st);
    } catch {
      applyCorreoUI({
        ...collectCorreo(),
        desarrollador: val("#desarrollador"),
      });
    }
  }

  async function persistMarcarCorreo() {
    if (syncingCorreo || !window.QrysDesarrolladores) return;
    const idCaso = val("#idCaso");
    if (!idCaso) return;
    const enviado = !!$("#chkCorreoEnviado")?.checked;
    let fecha = val("#fechaEnvioCorreo");
    if (enviado && !fecha) {
      fecha = new Date().toISOString().slice(0, 10);
      setVal("#fechaEnvioCorreo", fecha);
    }
    try {
      const r = await QrysDesarrolladores.marcarCorreo({
        idCaso,
        enviado,
        fechaEnvio: fecha,
        destinatario: val("#correoDestino"),
      });
      if (r.ok) applyCorreoUI(r);
    } catch {
      /* local */
    }
    QrysHistorico.upsert({
      idCaso,
      idReq: val("#idReq"),
      proyecto: val("#proyecto"),
      modulo: val("#moduloNombre"),
      fecha: val("#fecha"),
      estado: enviado ? "enviado" : undefined,
      correoEnviado: enviado,
      fechaEnvioCorreo: fecha,
    });
    if (enviado) {
      const idReq = val("#idReq") || idReqVinculado;
      const archivo = archivoColaVinculado;
      if (archivo) {
        QrysCola.updateEstado(
          archivo,
          "terminado",
          {
            terminadoEn: new Date().toISOString(),
            terminadoPor: "correo_enviado",
            correoEnviado: true,
            fechaEnvioCorreo: fecha,
          },
          idReq,
        );
      }
      refreshColaTable();
    }
  }

  async function accionarCorreo(opts) {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique el ID caso.");
    let dest = val("#correoDestino");
    if (!dest) {
      dest = (window.prompt("Correo del desarrollador:", "") || "").trim();
      if (!dest) return;
      setVal("#correoDestino", dest);
    }
    // Siempre: una sola digitación → queda en desarrolladores.json para el próximo REQ.
    await guardarCorreoEnLista(val("#desarrollador"), dest);
    const yaEnviado = !!$("#chkCorreoEnviado")?.checked;
    if (!opts.display && yaEnviado && !confirm(`¿Reenviar el dictamen a ${dest}?`)) return;
    const btn = $("#btnEnviarCorreo");
    if (btn && !opts.display) {
      btn.disabled = true;
      btn.textContent = yaEnviado ? "Reenviando…" : "Enviando…";
    }
    try {
      const r = await QrysDesarrolladores.enviarCorreo({
        idCaso,
        correo: dest,
        reenviar: yaEnviado,
        display: !!opts.display,
        desarrollador: val("#desarrollador"),
      });
      if (!r.ok) {
        const extra = r.error || "No se pudo enviar.";
        if (!opts.display && confirm(`${extra}\n\n¿Abrir un borrador en Outlook?`)) {
          return accionarCorreo({ display: true });
        }
        return alert(extra);
      }
      if (r.borrador) {
        alert(r.mensaje || "Borrador abierto en Outlook.");
        return;
      }
      // Refuerzo: el backend también actualiza la lista; si falló, reintentamos aquí.
      const okLista = await guardarCorreoEnLista(val("#desarrollador"), dest);
      aplicarResultadoCorreoEnviado(idCaso, r);
      if (!okLista) {
        alert((r.mensaje || "Correo enviado.") + "\n\nAviso: no quedó el correo en la lista de desarrolladores. Revíselo y salga del campo Correo destino.");
      } else {
        alert(r.mensaje || "Correo enviado.");
      }
    } catch (e) {
      alert(e.message || "No se pudo enviar el correo.");
    } finally {
      if (btn) {
        btn.disabled = false;
        btn.textContent = $("#chkCorreoEnviado")?.checked ? "Reenviar correo" : "Enviar correo";
      }
    }
  }

  function bindCorreoDev() {
    $("#btnEnviarCorreo")?.addEventListener("click", () => accionarCorreo({}));
    $("#btnBorradorCorreo")?.addEventListener("click", () => accionarCorreo({ display: true }));
    $("#chkCorreoEnviado")?.addEventListener("change", persistMarcarCorreo);
    $("#fechaEnvioCorreo")?.addEventListener("change", persistMarcarCorreo);
    $("#correoDestino")?.addEventListener("change", async () => {
      await guardarCorreoEnLista(val("#desarrollador"), val("#correoDestino"));
      persistMarcarCorreo();
    });
    $("#correoDestino")?.addEventListener("blur", async () => {
      await guardarCorreoEnLista(val("#desarrollador"), val("#correoDestino"));
    });
    $("#desarrollador")?.addEventListener("change", async () => {
      await guardarCorreoEnLista(val("#desarrollador"), val("#correoDestino"));
      refreshCorreoEstado();
    });
  }

  function bindDictado() {
    const ok = QrysDictado.init((msg) => {
      $$(".dictado-estado").forEach((el) => {
        el.textContent = msg;
      });
      const escuchando = msg.includes("Escuchando");
      $$(".btn-detener-dictado").forEach((btn) => {
        btn.disabled = !escuchando;
      });
    });
    if (!ok) {
      $("#btnDictarAnalisis").disabled = true;
      $("#btnDictarRecomendacion").disabled = true;
      if ($("#btnDictarCriterios")) $("#btnDictarCriterios").disabled = true;
      if ($("#btnDictarContComo")) $("#btnDictarContComo").disabled = true;
      if ($("#btnDictarContDesarrollo")) $("#btnDictarContDesarrollo").disabled = true;
    }
    $("#btnDictarAnalisis").addEventListener("click", () => {
      QrysDictado.start($("#analisis"));
    });
    $("#btnDictarRecomendacion").addEventListener("click", () => {
      QrysDictado.start($("#recomendacion"));
    });
    $("#btnDictarCriterios")?.addEventListener("click", () => {
      QrysDictado.start($("#criteriosAceptacion"));
    });
    $("#btnDictarContComo")?.addEventListener("click", () => {
      QrysDictado.start($("#contComoAfecta"));
    });
    $("#btnDictarContDesarrollo")?.addEventListener("click", () => {
      QrysDictado.start($("#contDesarrollo"));
    });
    $("#chkAfectaContabilidad")?.addEventListener("change", () => {
      toggleContabilidad();
      saveToStorage();
    });
    $("#chkValidarAntes")?.addEventListener("change", () => {
      toggleValidarAntes();
      if ($("#chkValidarAntes")?.checked && !val("#validarAntesTexto")) {
        setVal("#validarAntesTexto", TEXTO_VALIDAR_ANTES_DEFECTO);
      }
      saveToStorage();
    });
    $("#btnDictarValidarAntes")?.addEventListener("click", () => {
      QrysDictado.start($("#validarAntesTexto"));
    });
    $("#btnValidarContabilidad")?.addEventListener("click", () => validarContabilidad());
    $$(".btn-detener-dictado").forEach((btn) => {
      btn.addEventListener("click", () => QrysDictado.stop());
    });
    $$(".btn-ia-organizar").forEach((btn) => {
      btn.classList.add("hidden");
      btn.hidden = true;
    });
    toggleContabilidad();
    toggleValidarAntes();
  }

  const TEXTO_VALIDAR_ANTES_DEFECTO =
    "Antes de iniciar cualquier desarrollo, valide en el ambiente del cliente que el error no se haya corregido en un trabajo previo. Revise los datos del escenario (documento, montos, procedencia). Si el proceso ya funciona, no aplique la propuesta e informe que está correcto. Solo si el fallo se reproduce, proceda con el desarrollo sugerido.";

  function toggleValidarAntes() {
    const on = !!$("#chkValidarAntes")?.checked;
    $("#validarAntesCampos")?.classList.toggle("hidden", !on);
  }

  function collectValidarAntes() {
    return {
      aplica: !!$("#chkValidarAntes")?.checked,
      texto: val("#validarAntesTexto") || ($("#chkValidarAntes")?.checked ? TEXTO_VALIDAR_ANTES_DEFECTO : ""),
    };
  }

  function toggleContabilidad() {
    const on = !!$("#chkAfectaContabilidad")?.checked;
    $("#contabilidadCampos")?.classList.toggle("hidden", !on);
  }

  function collectContabilidad() {
    return {
      afecta: !!$("#chkAfectaContabilidad")?.checked,
      comoAfecta: val("#contComoAfecta"),
      desarrollo: val("#contDesarrollo"),
      validacion: contValidacion || null,
    };
  }

  function renderContValidacion(dato) {
    const box = $("#contValidacionBox");
    if (!box) return;
    if (!dato?.texto) {
      box.classList.add("hidden");
      box.innerHTML = "";
      return;
    }
    box.classList.remove("hidden", "cont-validacion-ok", "cont-validacion-obs", "cont-validacion-no");
    const cls =
      dato.estado === "ok"
        ? "cont-validacion-ok"
        : dato.estado === "no_aplica"
          ? "cont-validacion-no"
          : "cont-validacion-obs";
    box.classList.add(cls);
    const cuando = dato.validadoEn ? ` <small>(${esc(dato.validadoEn)})</small>` : "";
    box.innerHTML = `<strong>Validación del agente</strong>${cuando}<pre class="criterios-sugerencia-texto">${esc(dato.texto)}</pre>`;
  }

  function renderBrechaAnalisis(dato) {
    const box = $("#brechaAnalisisBox");
    if (!box) return;
    if (!dato || !dato.texto) {
      box.classList.add("hidden");
      box.innerHTML = "";
      return;
    }
    box.classList.remove("hidden");
    const cuando = dato.fecha ? ` <small>(${esc(dato.fecha)})</small>` : "";
    box.innerHTML = `<strong>Propuesta del agente (solución)</strong>${cuando}<pre class="criterios-sugerencia-texto">${esc(dato.texto)}</pre>`;
  }

  function solicitudTienePropuesta(sol) {
    const c = sol?.contenido || {};
    return !!(
      (c.criteriosAceptacion && String(c.criteriosAceptacion).trim()) ||
      (c.alcance && String(c.alcance).trim()) ||
      (c.restricciones && String(c.restricciones).trim()) ||
      (c.analisis && String(c.analisis).trim()) ||
      (c.brechaAnalisis && c.brechaAnalisis.texto)
    );
  }

  function textoPropuestaEnFormulario() {
    return solicitudTienePropuesta({
      contenido: {
        criteriosAceptacion: val("#criteriosAceptacion"),
        alcance: val("#alcance"),
        restricciones: val("#restricciones"),
        analisis: val("#analisis"),
        brechaAnalisis,
      },
    });
  }

  async function completarBrechaDesdeChat(idCaso) {
    if (brechaAnalisis?.texto) return;
    const chat = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/chat?t=${Date.now()}`, { cache: "no-store" });
    const cj = await chat.json();
    const msgs = (cj.mensajes || []).filter((m) => m.autor === "agente");
    const last = msgs[msgs.length - 1];
    if (last && last.texto) {
      brechaAnalisis = { texto: last.texto, fecha: last.fecha, estado: "listo" };
      renderBrechaAnalisis(brechaAnalisis);
    }
  }

  function minutosDesdeIso(iso) {
    if (!iso) return 0;
    const t = Date.parse(String(iso));
    if (!Number.isFinite(t)) return 0;
    return Math.max(0, Math.floor((Date.now() - t) / 60000));
  }

  async function pollBrechaAnalisis(idCaso, hintEl, loadingToken) {
    const hint = hintEl || $("#brechaAnalisisHint");
    const stale = () => loadingToken != null && loadingToken !== analisisLoadingToken;
    // El agente de un REQ suele pasar de 4 min. 300 sondeos × 4 s ≈ 20 min.
    for (let i = 0; i < 300; i++) {
      await new Promise((r) => setTimeout(r, 4000));
      if (stale()) return;
      try {
        const est = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/estado?t=${Date.now()}`, { cache: "no-store" });
        const estado = await est.json();
        const bot = estado.bot || {};
        if (bot.estado === "error" || bot.estado === "sin_clave") {
          if (hint) hint.textContent = bot.error || "El agente no pudo terminar. Revise el Chat.";
          updateAnalisisLoadingDetalle(bot.error || "El agente no pudo terminar. Revise el Chat.");
          return;
        }
        const termino = bot.estado === "listo" || bot.estado === "terminado";
        if (termino) {
          updateAnalisisLoadingDetalle("Análisis listo. Actualizando formulario…");
          await cargarSolicitudCaso(idCaso, { sondeo: true });
          await completarBrechaDesdeChat(idCaso);
          if (window.QrysCola) {
            await QrysCola.syncFromServer();
            refreshColaTable();
          }
          if (hint) {
            hint.textContent = textoPropuestaEnFormulario()
              ? "Listo: revise criterios, alcance, restricciones y análisis en el formulario."
              : "El bot terminó sin rellenar el formulario. Revise el Chat o pulse Analizar de nuevo.";
          }
          return;
        }
        const modelo = bot.modelo ? ` ${bot.modelo}${bot.fast ? " Fast" : ""}` : "";
        const mins = minutosDesdeIso(bot.iniciadoEn);
        const lleva = mins > 0 ? ` Lleva ${mins} min.` : "";
        updateAnalisisLoadingDetalle(`El agente${modelo} sigue trabajando.${lleva} El aviso se cierra al terminar.`);
        await cargarSolicitudCaso(idCaso, { sondeo: true });
      } catch {
        /* reintento */
      }
    }
    if (hint) hint.textContent = "Sigue en el Chat si aquí no aparece. Recargue el caso si hace falta.";
    updateAnalisisLoadingDetalle("Tiempo de espera agotado. Revise el Chat del caso.");
  }

  function imagenAnalisisUrl(idCaso, nombre) {
    return `/api/caso/${encodeURIComponent(idCaso)}/imagen/${encodeURIComponent(nombre)}`;
  }

  function renderImagenesAnalisis() {
    const ul = $("#imagenesAnalisisLista");
    const empty = $("#imagenesAnalisisEmpty");
    if (!ul) return;
    const idCaso = val("#idCaso");
    ul.innerHTML = imagenesAnalisis
      .map((img) => {
        const nombre = img.nombre || "";
        const url = img.url || (idCaso && nombre ? imagenAnalisisUrl(idCaso, nombre) : "");
        return `<li class="imagen-analisis-item${img._subiendo ? " is-uploading" : ""}" data-nombre="${escAttr(nombre)}">
          <button type="button" class="btn-quitar-imagen" title="Quitar" aria-label="Quitar ${escAttr(nombre)}">×</button>
          ${url ? `<a href="${escAttr(url)}" target="_blank" rel="noopener"><img src="${escAttr(url)}" alt="${escAttr(nombre)}" loading="lazy"></a>` : `<div class="imagen-analisis-placeholder">${escAttr(nombre)}</div>`}
          <span class="imagen-analisis-nombre" title="${escAttr(nombre)}">${escAttr(nombre)}</span>
        </li>`;
      })
      .join("");
    ul.querySelectorAll(".btn-quitar-imagen").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        const li = btn.closest(".imagen-analisis-item");
        quitarImagenAnalisis(li?.dataset.nombre || "");
      });
    });
    if (empty) empty.hidden = imagenesAnalisis.length > 0;
  }

  async function subirImagenAnalisis(file) {
    const idCaso = val("#idCaso");
    if (!idCaso) {
      alert("Indique ID caso (paso 1) antes de adjuntar capturas.");
      return null;
    }
    if (location.protocol === "file:") {
      alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para subir capturas.");
      return null;
    }
    if (!file || !String(file.type || "").startsWith("image/")) {
      alert("Solo se admiten imágenes (PNG, JPG, WebP, GIF).");
      return null;
    }
    const maxMb = 8;
    if (file.size > maxMb * 1024 * 1024) {
      alert(`La imagen supera ${maxMb} MB. Reduzca la captura e intente de nuevo.`);
      return null;
    }
    const dataUrl = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("No se pudo leer la imagen"));
      reader.readAsDataURL(file);
    });
    const tempNombre = file.name || `captura-${Date.now()}.png`;
    imagenesAnalisis.push({ nombre: tempNombre, _subiendo: true });
    renderImagenesAnalisis();
    try {
      let resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/imagen`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: file.name || "", dataUrl }),
      });
      let out = await parseJsonResponse(resp);
      if (resp.status === 404 && (out.error || "").toLowerCase().includes("ruta")) {
        const data = collectData();
        resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            solicitud: data,
            subirImagen: { nombre: file.name || "", dataUrl },
          }),
        });
        out = await parseJsonResponse(resp);
      }
      if (!resp.ok) {
        if (resp.status === 404 && (out.error || "").toLowerCase().includes("ruta")) {
          throw new Error(
            "El servidor no tiene la ruta de capturas (versión antigua). "
            + "Ejecute reiniciar-servidor.bat (como administrador) y recargue con Ctrl+F5.",
          );
        }
        throw new Error(out.error || "No se pudo subir la imagen");
      }
      if (!out.imagen) throw new Error("El servidor no devolvió la imagen guardada.");
      imagenesAnalisis = imagenesAnalisis.filter((i) => !i._subiendo);
      const existIdx = imagenesAnalisis.findIndex((i) => i.nombre === out.imagen.nombre);
      if (existIdx >= 0) imagenesAnalisis[existIdx] = out.imagen;
      else imagenesAnalisis.push(out.imagen);
      renderImagenesAnalisis();
      saveToStorage();
      return out.imagen;
    } catch (e) {
      imagenesAnalisis = imagenesAnalisis.filter((i) => !i._subiendo);
      renderImagenesAnalisis();
      alert(e.message || "Error al subir la imagen.");
      return null;
    }
  }

  async function quitarImagenAnalisis(nombre) {
    if (!nombre) return;
    if (!confirm(`¿Quitar la captura «${nombre}»?`)) return;
    const idCaso = val("#idCaso");
    imagenesAnalisis = imagenesAnalisis.filter((i) => i.nombre !== nombre);
    renderImagenesAnalisis();
    saveToStorage();
    if (location.protocol === "file:" || !idCaso) return;
    try {
      await fetch(`/api/caso/${encodeURIComponent(idCaso)}/imagen/${encodeURIComponent(nombre)}`, {
        method: "DELETE",
      });
    } catch {
      /* local ya actualizado */
    }
  }

  function diagramaFlujoUrl(idCaso, nombre) {
    if (!idCaso || !nombre) return "";
    if (location.protocol === "file:") return "";
    return `/api/caso/${encodeURIComponent(idCaso)}/diagrama/${encodeURIComponent(nombre)}`;
  }

  function renderDiagramaFlujo() {
    const estado = $("#diagramaFlujoEstado");
    const hint = $("#hintDiagramaFlujo");
    const btnQuitar = $("#btnQuitarDiagrama");
    const preview = $("#diagramaFlujoPreview");
    if (!estado) return;
    if (diagramaFlujo?.nombre) {
      const idCaso = val("#idCaso");
      const url = diagramaFlujo.url || diagramaFlujoUrl(idCaso, diagramaFlujo.nombre);
      estado.hidden = false;
      estado.classList.remove("hidden");
      estado.innerHTML = url
        ? `Diagrama: <strong>${diagramaFlujo.nombre}</strong> — <a href="${url}" target="_blank" rel="noopener">Abrir</a>`
        : `Diagrama: <strong>${diagramaFlujo.nombre}</strong> (${diagramaFlujo.ruta || ""})`;
      if (hint) hint.textContent = "Listo para la sección 4.5 del dictamen";
      if (btnQuitar) btnQuitar.classList.remove("hidden");
      if (preview) {
        if (url) {
          if (preview.getAttribute("src") !== url) preview.src = url;
          preview.classList.remove("hidden");
        } else {
          preview.removeAttribute("src");
          preview.classList.add("hidden");
        }
      }
    } else {
      estado.hidden = true;
      estado.classList.add("hidden");
      estado.textContent = "";
      if (hint) {
        hint.textContent = val("#idCaso")
          ? "Sin diagrama — pulse Generar diagrama (conocimiento + análisis)"
          : "Indique ID de caso";
      }
      if (btnQuitar) btnQuitar.classList.add("hidden");
      if (preview) {
        preview.removeAttribute("src");
        preview.classList.add("hidden");
      }
    }
  }

  async function subirDiagramaFlujo(file) {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso (paso 1).");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para subir diagramas.");
    }
    if (!file) return;
    let html;
    try {
      html = await file.text();
    } catch (e) {
      return alert(e.message || "No se pudo leer el archivo.");
    }
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/diagrama`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contenido: html,
          nombre: file.name || "flujo.html",
          notas: val("#notasDiagramaFlujo"),
        }),
      });
      const out = await resp.json();
      if (!resp.ok || !out.ok) throw new Error(out.error || "Error al subir diagrama");
      diagramaFlujo = out.diagrama;
      renderDiagramaFlujo();
      saveToStorage();
      alert(
        "Diagrama subido. El agente debe incluir la sección 4.5 en el dictamen con enlace diagramas/" +
          diagramaFlujo.nombre,
      );
    } catch (e) {
      alert(e.message || "Error al subir el diagrama.");
    }
  }

  async function quitarDiagramaFlujo() {
    if (!diagramaFlujo?.nombre) return;
    if (!confirm(`¿Quitar el diagrama «${diagramaFlujo.nombre}»?`)) return;
    const idCaso = val("#idCaso");
    const nombre = diagramaFlujo.nombre;
    diagramaFlujo = null;
    renderDiagramaFlujo();
    saveToStorage();
    if (location.protocol === "file:" || !idCaso) return;
    try {
      await fetch(`/api/caso/${encodeURIComponent(idCaso)}/diagrama/${encodeURIComponent(nombre)}`, {
        method: "DELETE",
      });
    } catch {
      /* local ya actualizado */
    }
  }

  function buildPromptDiagramaCaso(data) {
    const pf = window.QrysPromptsFlujo;
    if (!pf) return "(Cargue prompts-flujo.js)";
    const d = data || collectData();
    return pf.buildPromptDiagramaArchify({
      modo: "caso",
      idCaso: d.identificacion.idCaso,
      idReq: d.identificacion.idReq,
      procesoId: d.sql.procesoId,
      proyecto: d.proyecto.nombre,
      modulo: d.proyecto.modulo,
      rutaPantalla: d.proyecto.rutaPantalla,
      cambioPropuestoSimple: d.contenido.cambioPropuestoSimple,
      colaPath: d.cola.rutaCola,
      notasDiagrama: val("#notasDiagramaFlujo"),
      data: d,
    });
  }

  async function copyPromptDiagrama() {
    if (!val("#idCaso")) return alert("Indique ID de caso.");
    const prompt = buildPromptDiagramaCaso();
    await copyTextToClipboard(
      prompt,
      "Prompt Archify copiado (opcional).\n\nLo habitual es pulsar «Generar diagrama» en esta misma tarjeta.",
    );
  }

  async function generarDiagramaDesdeKb() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso (paso 1).");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/");
    }
    const btn = $("#btnGenerarDiagrama");
    const hint = $("#hintDiagramaFlujo");
    if (btn) btn.disabled = true;
    if (hint) hint.textContent = "Generando desde conocimiento/ y el análisis…";
    try {
      saveToStorage();
      const data = collectData();
      const saveResp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ solicitud: data }),
      });
      const saveOut = await parseJsonResponse(saveResp);
      if (!saveResp.ok) throw new Error(saveOut.error || "No se pudo guardar el caso");
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/diagrama/generar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ notas: val("#notasDiagramaFlujo") }),
      });
      const out = await parseJsonResponse(resp);
      if (!resp.ok || !out.ok) throw new Error(out.error || "No se pudo generar el diagrama");
      diagramaFlujo = out.diagrama;
      renderDiagramaFlujo();
      saveToStorage();
      if (hint) {
        hint.textContent = out.diagrama?.aviso || "Diagrama listo — sección 4.5 del dictamen";
      }
    } catch (e) {
      if (hint) hint.textContent = e.message || "Error al generar";
      alert(e.message || "Error al generar el diagrama.");
    } finally {
      if (btn) btn.disabled = !val("#idCaso");
    }
  }

  function bindDiagramaFlujo() {
    const input = $("#inputDiagramaFlujo");
    if (input) {
      input.addEventListener("change", async () => {
        const f = input.files?.[0];
        input.value = "";
        if (f) await subirDiagramaFlujo(f);
      });
    }
    $("#btnSubirDiagramaHtml")?.addEventListener("click", () => input?.click());
    $("#btnQuitarDiagrama")?.addEventListener("click", () => quitarDiagramaFlujo());
    $("#btnGenerarDiagrama")?.addEventListener("click", () => generarDiagramaDesdeKb());
  }

  function normalizeMockupPathForm(raw) {
    return String(raw || "")
      .trim()
      .replace(/\\/g, "/")
      .replace(/^\//, "");
  }

  function mockupMetaForRuta(ruta) {
    const found =
      (mockupsFormMeta.mockups || []).find((m) => m.ruta === ruta) ||
      (mockupsFormMeta.sugeridos || []).find((m) => m.ruta === ruta);
    return found || { ruta, existe: ruta.startsWith("activo/"), tipo: "mockup-ux" };
  }

  function mockupUrlForMeta(meta, idCaso) {
    if (!meta) return "";
    if (meta.url) return meta.url;
    if (meta.existe === false) return "";
    const ruta = meta.ruta || "";
    if (!ruta) return "";
    if (ruta.startsWith("activo/") && idCaso) return `/${ruta}`;
    return `/${ruta.replace(/^\//, "")}`;
  }

  function descargarMockupZip(rutaArg) {
    const idCaso = val("#idCaso");
    const sel = $("#selectMockupAbrir");
    const ruta = rutaArg || sel?.value || mockupsFormDraft[0] || "";
    if (!idCaso || !ruta) {
      return alert("Seleccione un mockup (.html) para empaquetar.");
    }
    if (!ruta.toLowerCase().endsWith(".html")) {
      return alert("Solo se empaquetan archivos .html de mockup.");
    }
    const q = encodeURIComponent(ruta.replace(/^\//, ""));
    window.location.href = `/api/caso/${encodeURIComponent(idCaso)}/mockups?zip=${q}`;
  }

  function abrirMockupForm(rutaArg) {
    const idCaso = val("#idCaso");
    const sel = $("#selectMockupAbrir");
    let ruta = rutaArg || sel?.value || mockupsFormDraft[0] || "";
    if (!ruta) {
      return alert("No hay mockup para abrir. Pulse Generar mockups o suba un HTML.");
    }
    const meta = mockupMetaForRuta(ruta);
    const url = mockupUrlForMeta(meta, idCaso);
    if (!url) {
      return alert("El archivo no está en disco. Escanee o regenere el mockup.");
    }
    if (window.QrysChat?.openDocument) {
      QrysChat.openDocument(meta.ruta || ruta, idCaso, url);
    } else {
      window.open(url, "_blank", "noopener,noreferrer");
    }
    mockupsFormPreviewRuta = ruta;
    const preview = $("#mockupFormPreview");
    if (preview) {
      preview.src = `${url}${url.includes("?") ? "&" : "?"}t=${Date.now()}`;
      preview.classList.remove("hidden");
    }
    renderMockupsForm();
  }

  function renderMockupsForm() {
    const list = $("#mockupsFormList");
    const hint = $("#hintMockupsForm");
    const preview = $("#mockupFormPreview");
    const suger = $("#mockupsFormSugeridos");
    const idCaso = val("#idCaso");
    const hasApi = location.protocol !== "file:" && !!window.QrysChat;

    ["#btnGenerarMockups", "#btnMockupsEscanear", "#btnMockupsGuardar", "#selectPlantillaMockup", "#btnMockupsUsarPlantilla", "#btnAbrirMockup", "#btnDescargarMockupZip"].forEach((sel) => {
      const el = $(sel);
      if (el) el.disabled = !idCaso || !hasApi;
    });

    if (!list) return;

    if (!idCaso) {
      list.innerHTML = `<li class="hint compact">Indique ID de caso para cargar o subir mockups.</li>`;
      if (hint) hint.textContent = "";
      if (suger) {
        suger.classList.add("hidden");
        suger.innerHTML = "";
      }
      if (preview) {
        preview.removeAttribute("src");
        preview.classList.add("hidden");
      }
      return;
    }

    if (!hasApi) {
      list.innerHTML = `<li class="hint compact">Abra http://localhost:8765/app/ (abrir-app.bat) para gestionar mockups.</li>`;
      if (hint) hint.textContent = "Borrador local en solicitud al guardar formulario";
      return;
    }

    mockupsFormDraft = filterMockupsForCaso(mockupsFormDraft, idCaso);

    if (!mockupsFormDraft.length) {
      list.innerHTML = `<li class="hint compact">Sin mockups — pulse <strong>Generar mockups</strong> (ventana propuesta, no la captura), suba HTML o use plantilla.</li>`;
      if (mockupsFormPreviewRuta) clearMockupFormPreview();
    } else {
      list.innerHTML = mockupsFormDraft
        .map((ruta) => {
          const meta = mockupMetaForRuta(ruta);
          const missing = meta.existe === false;
          const url = meta.url || (missing ? "" : `/${ruta}`);
          const isPrev = mockupsFormPreviewRuta === ruta;
          return `<li class="${missing ? "missing" : ""}${isPrev ? " is-preview" : ""}" data-ruta="${escAttr(ruta)}">
            <span class="mock-path" title="${escAttr(ruta)}">${esc(ruta)}</span>
            <button type="button" class="btn btn-ghost btn-sm btn-mock-prev" data-url="${escAttr(url)}" data-ruta="${escAttr(ruta)}" ${!url ? "disabled" : ""}>Vista</button>
            ${url ? `<a class="btn btn-ghost btn-sm" href="${escAttr(url)}" target="_blank" rel="noopener">Abrir</a>` : ""}
            ${ruta.toLowerCase().endsWith(".html") ? `<button type="button" class="btn btn-ghost btn-sm btn-mock-zip" data-ruta="${escAttr(ruta)}">ZIP</button>` : ""}
            <button type="button" class="btn btn-ghost btn-sm btn-mock-quitar" data-ruta="${escAttr(ruta)}">Quitar</button>
          </li>`;
        })
        .join("");
      list.querySelectorAll(".btn-mock-prev").forEach((btn) => {
        btn.addEventListener("click", () => {
          mockupsFormPreviewRuta = btn.dataset.ruta || "";
          if (preview && btn.dataset.url) {
            preview.src = btn.dataset.url;
            preview.classList.remove("hidden");
          }
          renderMockupsForm();
        });
      });
      list.querySelectorAll(".btn-mock-zip").forEach((btn) => {
        btn.addEventListener("click", () => descargarMockupZip(btn.dataset.ruta));
      });
      list.querySelectorAll(".btn-mock-quitar").forEach((btn) => {
        btn.addEventListener("click", () => {
          mockupsFormDraft = mockupsFormDraft.filter((r) => r !== btn.dataset.ruta);
          if (mockupsFormPreviewRuta === btn.dataset.ruta) {
            mockupsFormPreviewRuta = "";
            if (preview) {
              preview.removeAttribute("src");
              preview.classList.add("hidden");
            }
          }
          mockupsFormDirty = true;
          saveToStorage();
          renderMockupsForm();
        });
      });
    }

    if (suger) {
      const sugs = mockupsFormMeta.sugeridos || [];
      if (sugs.length) {
        suger.classList.remove("hidden");
        suger.innerHTML = sugs
          .map(
            (m) =>
              `<li><button type="button" class="btn-mock-suger" data-ruta="${escAttr(m.ruta)}" title="${escAttr(m.ruta)}">+ ${esc(m.titulo || m.ruta)}</button></li>`,
          )
          .join("");
        suger.querySelectorAll(".btn-mock-suger").forEach((btn) => {
          btn.addEventListener("click", () => {
            const ruta = normalizeMockupPathForm(btn.dataset.ruta);
            if (ruta && !mockupsFormDraft.includes(ruta)) mockupsFormDraft.push(ruta);
            mockupsFormDirty = true;
            saveToStorage();
            renderMockupsForm();
          });
        });
      } else {
        suger.classList.add("hidden");
        suger.innerHTML = "";
      }
    }

    const abiertos = mockupsFormDraft
      .map((ruta) => ({ ruta, meta: mockupMetaForRuta(ruta), url: mockupUrlForMeta(mockupMetaForRuta(ruta), idCaso) }))
      .filter((x) => x.url);
    const btnAbrir = $("#btnAbrirMockup");
    const selAbrir = $("#selectMockupAbrir");
    const estado = $("#mockupsFormEstado");
    const btnZip = $("#btnDescargarMockupZip");
    if (btnAbrir) btnAbrir.disabled = !idCaso || !hasApi || !abiertos.length;
    if (btnZip) btnZip.disabled = !idCaso || !hasApi || !mockupsFormDraft.some((r) => r.toLowerCase().endsWith(".html"));
    if (selAbrir) {
      if (abiertos.length > 1) {
        selAbrir.classList.remove("hidden");
        selAbrir.disabled = !idCaso || !hasApi;
        const prev = selAbrir.value;
        selAbrir.innerHTML = abiertos
          .map(
            (x) =>
              `<option value="${escAttr(x.ruta)}" data-url="${escAttr(x.url)}">${esc(x.ruta.split("/").pop() || x.ruta)}</option>`,
          )
          .join("");
        if (prev && [...selAbrir.options].some((o) => o.value === prev)) selAbrir.value = prev;
      } else {
        selAbrir.classList.add("hidden");
        selAbrir.innerHTML = "";
        selAbrir.disabled = true;
      }
    }
    if (estado) {
      if (abiertos.length) {
        const first = abiertos[0];
        estado.hidden = false;
        estado.classList.remove("hidden");
        estado.innerHTML = `${abiertos.length} mockup(s) — <a href="${escAttr(first.url)}" target="_blank" rel="noopener">Abrir ${esc(first.ruta.split("/").pop() || "mockup")}</a>`;
      } else {
        estado.hidden = true;
        estado.classList.add("hidden");
        estado.textContent = "";
      }
    }

    if (hint) {
      const n = mockupsFormDraft.length;
      const base = n
        ? `${n} mockup(s)${mockupsFormMeta.correoHint ? " — " + mockupsFormMeta.correoHint : ""}`
        : "Sin mockups — pulse Generar mockups (conocimiento + análisis)";
      hint.textContent = mockupsFormDirty ? `${base} · cambios sin guardar en servidor` : base;
    }

    const selPlant = $("#selectPlantillaMockup");
    if (selPlant && mockupsFormMeta.plantillas?.length) {
      const prev = selPlant.value;
      selPlant.innerHTML =
        `<option value="">Plantilla SP…</option>` +
        mockupsFormMeta.plantillas
          .map((p) => `<option value="${escAttr(p.ruta)}">${esc(p.titulo || p.ruta)}</option>`)
          .join("");
      if (prev && [...selPlant.options].some((o) => o.value === prev)) selPlant.value = prev;
    }
  }

  async function refreshMockupsForm(idCaso) {
    if (!idCaso || !window.QrysChat || location.protocol === "file:") {
      renderMockupsForm();
      return;
    }
    const data = await QrysChat.fetchMockups(idCaso, false);
    if (data.ok !== false) {
      const caseChanged = idCaso !== mockupsFormCasoId;
      mockupsFormCasoId = idCaso;
      mockupsFormMeta = {
        mockups: (data.mockups || []).filter((m) => mockupBelongsToCaso(m.ruta, idCaso)),
        sugeridos: (data.sugeridos || []).filter((m) => mockupBelongsToCaso(m.ruta, idCaso)),
        plantillas: data.plantillas || [],
        correoHint: data.correoHint || "",
      };
      if (!mockupsFormDirty || caseChanged) {
        if (caseChanged) mockupsFormDirty = false;
        mockupsFormDraft = filterMockupsForCaso((data.mockups || []).map((m) => m.ruta), idCaso);
      } else {
        mockupsFormDraft = filterMockupsForCaso(mockupsFormDraft, idCaso);
      }
    }
    renderMockupsForm();
  }

  async function generarMockupsDesdeKb() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso (paso 1).");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/");
    }
    const btn = $("#btnGenerarMockups");
    const hint = $("#hintMockupsForm");
    if (btn) btn.disabled = true;
    if (hint) hint.textContent = "Generando mockup de la propuesta de desarrollo…";
    try {
      saveToStorage();
      const data = collectData();
      const saveResp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ solicitud: data }),
      });
      const saveOut = await parseJsonResponse(saveResp);
      if (!saveResp.ok) throw new Error(saveOut.error || "No se pudo guardar el caso");
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups/generar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ notas: val("#notasMockups"), mockupsNotas: val("#notasMockups") }),
      });
      const out = await parseJsonResponse(resp);
      if (!resp.ok || out.ok === false) throw new Error(out.error || "No se pudieron generar mockups");
      mockupsFormMeta = {
        mockups: out.mockups || [],
        sugeridos: out.sugeridos || [],
        plantillas: out.plantillas || [],
        correoHint: out.correoHint || "",
      };
      mockupsFormDraft = (out.mockups || []).map((m) => m.ruta);
      mockupsFormDirty = false;
      saveToStorage();
      renderMockupsForm();
      if (hint) hint.textContent = out.correoHint || "Mockups listos en activo/…/mockups/";
      alert(
        "Mockup de la propuesta de desarrollo (no de la captura del problema).\n\nRevise la vista previa; si falta el análisis, complete cambio propuesto/criterios y regenere.",
      );
    } catch (e) {
      if (hint) hint.textContent = e.message || "Error al generar";
      alert(e.message || "Error al generar mockups.");
    } finally {
      if (btn) btn.disabled = !val("#idCaso");
    }
  }

  async function escanearMockupsForm() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso (paso 1).");
    if (!window.QrysChat) return;
    const hint = $("#hintMockupsForm");
    if (hint) hint.textContent = "Escaneando disco…";
    const data = await QrysChat.fetchMockups(idCaso, true);
    mockupsFormMeta = {
      mockups: data.mockups || [],
      sugeridos: data.sugeridos || [],
      plantillas: data.plantillas || [],
      correoHint: data.correoHint || "",
    };
    if (!mockupsFormDirty) {
      mockupsFormDraft = (data.mockups || []).map((m) => m.ruta);
    }
    renderMockupsForm();
    if (hint) {
      hint.textContent = data.sugeridos?.length
        ? `Encontrados ${data.sugeridos.length} archivo(s) nuevos — pulse + para agregar`
        : "Escaneo listo — no hay mockups nuevos fuera de la lista";
    }
  }

  async function guardarMockupsForm() {
    const idCaso = val("#idCaso");
    if (!idCaso || !window.QrysChat) return alert("Use abrir-app.bat para guardar mockups.");
    const result = await QrysChat.saveMockups(idCaso, mockupsFormDraft, {
      mockupsNotas: val("#notasMockups"),
    });
    if (!result.ok) {
      alert(result.error || "Error al guardar mockups.");
      return;
    }
    mockupsFormMeta = {
      mockups: result.mockups || [],
      sugeridos: [],
      plantillas: mockupsFormMeta.plantillas || [],
      correoHint: result.correoHint || "",
    };
    mockupsFormDraft = (result.mockups || []).map((m) => m.ruta);
    mockupsFormDirty = false;
    saveToStorage();
    renderMockupsForm();
    alert("Mockups guardados en solicitud.json → contenido.mockups");
  }

  async function subirMockupHtml(file) {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso (paso 1).");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para subir mockups.");
    }
    if (!file) return;
    let html;
    try {
      html = await file.text();
    } catch (e) {
      return alert(e.message || "No se pudo leer el archivo.");
    }
    try {
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups/subir`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contenido: html,
          nombre: file.name || "mockup.html",
          mockupsNotas: val("#notasMockups"),
        }),
      });
      const out = await resp.json();
      if (!resp.ok || !out.ok) throw new Error(out.error || "Error al subir mockup");
      mockupsFormMeta = {
        mockups: out.mockups || [],
        sugeridos: out.sugeridos || [],
        plantillas: out.plantillas || [],
        correoHint: out.correoHint || "",
      };
      mockupsFormDraft = (out.mockups || []).map((m) => m.ruta);
      mockupsFormDirty = false;
      saveToStorage();
      renderMockupsForm();
      alert("Mockup subido y registrado en la solicitud.");
    } catch (e) {
      alert(e.message || "Error al subir el mockup.");
    }
  }

  async function usarPlantillaMockup() {
    const idCaso = val("#idCaso");
    const ruta = normalizeMockupPathForm($("#selectPlantillaMockup")?.value);
    if (!idCaso || !ruta) return alert("Elija una plantilla.");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat para copiar plantillas al caso.");
    }
    try {
      const resp = await fetch(`/${ruta}`, { cache: "no-store" });
      if (!resp.ok) throw new Error("No se pudo leer la plantilla.");
      const html = await resp.text();
      const base = ruta.split("/").pop() || "mockup.html";
      const nombre = base.replace(/^mockup-/i, "").replace(/\.html$/i, "") || "mockup";
      const subResp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/mockups/subir`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contenido: html,
          nombre: `${nombre}-${idCaso.slice(-6)}.html`,
          mockupsNotas: val("#notasMockups"),
        }),
      });
      const out = await subResp.json();
      if (!subResp.ok || !out.ok) throw new Error(out.error || "Error al crear mockup desde plantilla");
      mockupsFormMeta = {
        mockups: out.mockups || [],
        sugeridos: out.sugeridos || [],
        plantillas: out.plantillas || [],
        correoHint: out.correoHint || "",
      };
      mockupsFormDraft = (out.mockups || []).map((m) => m.ruta);
      mockupsFormDirty = false;
      saveToStorage();
      renderMockupsForm();
      alert("Plantilla copiada a activo/…/mockups/ y agregada a la solicitud.");
    } catch (e) {
      alert(e.message || "Error con la plantilla.");
    }
  }

  function bindMockupsForm() {
    const inputMock = $("#inputMockupHtml");
    inputMock?.addEventListener("change", async () => {
      const f = inputMock.files?.[0];
      inputMock.value = "";
      if (f) await subirMockupHtml(f);
    });
    $("#btnSubirMockupHtml")?.addEventListener("click", () => inputMock?.click());
    $("#btnGenerarMockups")?.addEventListener("click", () => generarMockupsDesdeKb());
    $("#btnAbrirMockup")?.addEventListener("click", () => abrirMockupForm());
    $("#btnDescargarMockupZip")?.addEventListener("click", () => descargarMockupZip());
    $("#btnMockupsEscanear")?.addEventListener("click", () => escanearMockupsForm());
    $("#btnMockupsGuardar")?.addEventListener("click", () => guardarMockupsForm());
    $("#btnMockupsUsarPlantilla")?.addEventListener("click", () => usarPlantillaMockup());
    $("#notasMockups")?.addEventListener("input", () => saveToStorage());
  }

  function bindImagenesAnalisis() {
    const input = $("#inputImagenAnalisis");
    const btn = $("#btnElegirImagenAnalisis");
    const drop = $("#imagenesAnalisisDrop");
    if (btn && input) {
      btn.addEventListener("click", () => input.click());
      input.addEventListener("change", async () => {
        const files = [...(input.files || [])];
        input.value = "";
        for (const f of files) await subirImagenAnalisis(f);
      });
    }
    if (!drop) return;
    drop.addEventListener("paste", async (e) => {
      const items = [...(e.clipboardData?.items || [])];
      const imgs = items.filter((it) => it.type.startsWith("image/"));
      if (!imgs.length) return;
      e.preventDefault();
      for (const it of imgs) {
        const blob = it.getAsFile();
        if (blob) await subirImagenAnalisis(blob);
      }
    });
    drop.addEventListener("dragover", (e) => {
      e.preventDefault();
      drop.classList.add("is-dragover");
    });
    drop.addEventListener("dragleave", () => drop.classList.remove("is-dragover"));
    drop.addEventListener("drop", async (e) => {
      e.preventDefault();
      drop.classList.remove("is-dragover");
      const files = [...(e.dataTransfer?.files || [])].filter((f) => f.type.startsWith("image/"));
      for (const f of files) await subirImagenAnalisis(f);
    });
  }

  const ARCHIVO_EXTS_OK = [".pdf", ".txt", ".md", ".html", ".htm", ".docx"];

  function archivoAnalisisUrl(idCaso, nombre) {
    return `/api/caso/${encodeURIComponent(idCaso)}/archivo/${encodeURIComponent(nombre)}`;
  }

  function esArchivoNormativa(file) {
    const name = String(file?.name || "").toLowerCase();
    return ARCHIVO_EXTS_OK.some((ext) => name.endsWith(ext));
  }

  function renderArchivosAnalisis() {
    const ul = $("#archivosAnalisisLista");
    const empty = $("#archivosAnalisisEmpty");
    if (!ul) return;
    const idCaso = val("#idCaso");
    ul.innerHTML = archivosAnalisis
      .map((a) => {
        const nombre = a.nombre || "";
        const url = a.url || (idCaso && nombre ? archivoAnalisisUrl(idCaso, nombre) : "");
        const urlEx = a.urlExtracto || (idCaso && a.extracto ? archivoAnalisisUrl(idCaso, a.extracto) : "");
        const kb = a.bytes ? `${Math.round(a.bytes / 1024)} KB` : "";
        const aviso = a.avisoExtracto ? ` · ${a.avisoExtracto}` : "";
        const extractoOk = a.charsExtracto > 0 ? ` · extracto ${a.charsExtracto} caracteres` : "";
        return `<li class="archivo-analisis-item${a._subiendo ? " is-uploading" : ""}" data-nombre="${escAttr(nombre)}">
          <button type="button" class="btn-quitar-imagen" title="Quitar" aria-label="Quitar ${escAttr(nombre)}">×</button>
          <span class="archivo-analisis-tipo">${escAttr(a.tipo || "normativa")}</span>
          ${url ? `<a class="archivo-analisis-nombre" href="${escAttr(url)}" target="_blank" rel="noopener">${escAttr(nombre)}</a>` : `<span class="archivo-analisis-nombre">${escAttr(nombre)}</span>`}
          <span class="archivo-analisis-meta">${escAttr(kb)}${extractoOk}${escAttr(aviso)}
            ${urlEx ? ` · <a href="${escAttr(urlEx)}" target="_blank" rel="noopener">extracto</a>` : ""}
          </span>
        </li>`;
      })
      .join("");
    ul.querySelectorAll(".btn-quitar-imagen").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        const li = btn.closest(".archivo-analisis-item");
        quitarArchivoAnalisis(li?.dataset.nombre || "");
      });
    });
    if (empty) empty.hidden = archivosAnalisis.length > 0;
  }

  async function subirArchivoAnalisis(file) {
    const idCaso = val("#idCaso");
    if (!idCaso) {
      alert("Indique ID caso (paso 1) antes de adjuntar normativa.");
      return null;
    }
    if (location.protocol === "file:") {
      alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para subir archivos.");
      return null;
    }
    if (!file || !esArchivoNormativa(file)) {
      alert("Solo se admiten PDF, TXT, MD, HTML o DOCX.");
      return null;
    }
    const maxMb = 20;
    if (file.size > maxMb * 1024 * 1024) {
      alert(`El archivo supera ${maxMb} MB.`);
      return null;
    }
    const dataUrl = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("No se pudo leer el archivo"));
      reader.readAsDataURL(file);
    });
    const tipo = val("#tipoArchivoAnalisis") || "circular";
    const tempNombre = file.name || `normativa-${Date.now()}.pdf`;
    archivosAnalisis.push({ nombre: tempNombre, tipo, _subiendo: true });
    renderArchivosAnalisis();
    try {
      let resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/archivo`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: file.name || "", dataUrl, tipo }),
      });
      let out = await parseJsonResponse(resp);
      if (resp.status === 404 && (out.error || "").toLowerCase().includes("ruta")) {
        const data = collectData();
        resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            solicitud: data,
            subirArchivo: { nombre: file.name || "", dataUrl, tipo },
          }),
        });
        out = await parseJsonResponse(resp);
      }
      if (!resp.ok) {
        if (resp.status === 404) {
          throw new Error(
            "El servidor no tiene la ruta de archivos. Ejecute reiniciar-servidor.bat y Ctrl+F5.",
          );
        }
        throw new Error(out.error || "No se pudo subir el archivo");
      }
      if (!out.archivo) throw new Error("El servidor no devolvió el archivo guardado.");
      archivosAnalisis = archivosAnalisis.filter((i) => !i._subiendo);
      const existIdx = archivosAnalisis.findIndex((i) => i.nombre === out.archivo.nombre);
      if (existIdx >= 0) archivosAnalisis[existIdx] = out.archivo;
      else archivosAnalisis.push(out.archivo);
      renderArchivosAnalisis();
      saveToStorage();
      return out.archivo;
    } catch (e) {
      archivosAnalisis = archivosAnalisis.filter((i) => !i._subiendo);
      renderArchivosAnalisis();
      alert(e.message || "Error al subir el archivo.");
      return null;
    }
  }

  async function quitarArchivoAnalisis(nombre) {
    if (!nombre) return;
    if (!confirm(`¿Quitar el archivo «${nombre}»?`)) return;
    const idCaso = val("#idCaso");
    archivosAnalisis = archivosAnalisis.filter((i) => i.nombre !== nombre);
    renderArchivosAnalisis();
    saveToStorage();
    if (location.protocol === "file:" || !idCaso) return;
    try {
      await fetch(`/api/caso/${encodeURIComponent(idCaso)}/archivo/${encodeURIComponent(nombre)}`, {
        method: "DELETE",
      });
    } catch {
      /* local ya actualizado */
    }
  }

  function bindArchivosAnalisis() {
    const input = $("#inputArchivoAnalisis");
    const btn = $("#btnElegirArchivoAnalisis");
    const drop = $("#archivosAnalisisDrop");
    if (btn && input) {
      btn.addEventListener("click", () => input.click());
      input.addEventListener("change", async () => {
        const files = [...(input.files || [])];
        input.value = "";
        for (const f of files) await subirArchivoAnalisis(f);
      });
    }
    if (!drop) return;
    drop.addEventListener("dragover", (e) => {
      e.preventDefault();
      drop.classList.add("is-dragover");
    });
    drop.addEventListener("dragleave", () => drop.classList.remove("is-dragover"));
    drop.addEventListener("drop", async (e) => {
      e.preventDefault();
      drop.classList.remove("is-dragover");
      const files = [...(e.dataTransfer?.files || [])].filter(esArchivoNormativa);
      for (const f of files) await subirArchivoAnalisis(f);
    });
  }

  async function analizarRequerimiento() {
    const req = val("#requerimiento");
    const cola = val("#colaArchivoManual") || archivoColaVinculado;
    if (!req && !cola && !imagenesAnalisis.length && !archivosAnalisis.length) {
      return alert("Escriba el requerimiento, registre la cola o adjunte una captura o un archivo de normativa.");
    }
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID caso (paso 1). Hace falta para que el agente deje el resultado.");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/");
    }
    if (isAnalisisEnCurso()) return;
    saveToStorage();
    switchToFormulario();
    goStep(2);
    await marcarEstadoCola("en_analisis");
    const hint = $("#brechaAnalisisHint");
    const btn = $("#btnAnalizarRequerimiento");
    const loadingToken = ++analisisLoadingToken;
    if (btn) btn.disabled = true;
    showAnalisisLoading(
      "Analizando requerimiento",
      "Guardando y pidiendo análisis al agente…",
      idCaso,
    );
    if (hint) hint.textContent = "Guardando y pidiendo análisis al agente…";
    try {
      const data = collectData();
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ solicitud: data, analizarRequerimiento: true }),
      });
      const out = await parseJsonResponse(resp);
      if (!resp.ok) throw new Error(out.error || "No se pudo guardar");
      if (out.bot && out.bot.ok === false) {
        throw new Error(out.bot.error === "sin_clave" ? "Falta CURSOR_API_KEY en .env" : (out.bot.error || "El bot no arrancó"));
      }
      if (hint) {
        hint.textContent =
          "El agente está armando criterios, alcance, restricciones, análisis y SPs. Espere…";
      }
      updateAnalisisLoadingDetalle(
        "El agente contrasta el REQ con conocimiento/. El formulario se actualizará solo.",
      );
      await pollBrechaAnalisis(idCaso, hint, loadingToken);
    } catch (e) {
      if (hint) hint.textContent = e.message || "Error al analizar";
      alert(e.message || "No se pudo analizar el requerimiento.");
    } finally {
      if (loadingToken === analisisLoadingToken) hideAnalisisLoading();
      if (btn) btn.disabled = false;
    }
    if (loadingToken === analisisLoadingToken) await cargarSolicitudCaso(idCaso);
  }

  async function validarContabilidad() {
    if (!$("#chkAfectaContabilidad")?.checked) {
      return alert("Marque «Afecta contabilidad» para pedir validación, o déjelo sin marcar si no aplica.");
    }
    if (!val("#contComoAfecta")) return alert("Explique cómo afecta la contabilidad. Puede dictar.");
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID caso. Si aún no activó Fase 1, actívela primero.");
    saveToStorage();
    const hint = $("#contValidarHint");
    const btn = $("#btnValidarContabilidad");
    if (btn) btn.disabled = true;
    if (hint) hint.textContent = "Guardando y pidiendo validación…";
    try {
      if (location.protocol === "file:") {
        if (hint) hint.textContent = "Use abrir-app.bat para que el agente valide.";
        return;
      }
      const data = collectData();
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ solicitud: data, validarContabilidad: true }),
      });
      const out = await resp.json();
      if (!resp.ok) throw new Error(out.error || "No se pudo guardar");
      if (hint) hint.textContent = "El bot está validando. Abra el Chat.";
      abrirChatCaso(idCaso);
    } catch (e) {
      if (hint) hint.textContent = e.message || "Error al validar";
      alert(e.message || "No se pudo validar.");
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function setCriteriosHintAgente() {
    const el = $("#openaiEstadoHint");
    if (el) {
      el.textContent =
        "Criterios, análisis y recomendación los escribe el agente (Cursor) con base en Qrystalos2. OpenAI no interviene.";
    }
  }

  function escapeHtmlCambio(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function pintarVistaCambioSimple(texto) {
    const vista = $("#cambioSimpleVista");
    if (!vista) return;
    const t = String(texto || "").trim();
    if (!t) {
      vista.classList.add("is-empty");
      vista.textContent = "El campo está vacío. Escriba o pegue el texto abajo para ver cómo quedará en el dictamen.";
      return;
    }
    vista.classList.remove("is-empty");
    vista.innerHTML = escapeHtmlCambio(t).replace(/\n/g, "<br>");
  }

  function abrirCambioSimplePreview() {
    const modal = $("#modalCambioSimple");
    const editar = $("#cambioSimpleEditar");
    if (!modal || !editar) return;
    const actual = val("#cambioPropuestoSimple");
    editar.value = actual;
    pintarVistaCambioSimple(actual);
    const hint = $("#cambioSimplePreviewHint");
    if (hint) {
      hint.textContent = actual.trim()
        ? "Revise si el tono es el del cliente y si falta algún caso."
        : "Aún no hay texto. Escríbalo abajo o pida al agente que lo complete.";
    }
    modal.classList.remove("hidden");
    editar.focus();
  }

  function cerrarCambioSimplePreview() {
    $("#modalCambioSimple")?.classList.add("hidden");
  }

  function usarTextoCambioSimple() {
    const texto = ($("#cambioSimpleEditar")?.value || "").trim();
    setVal("#cambioPropuestoSimple", texto);
    saveToStorage();
    updateAll();
    cerrarCambioSimplePreview();
    const hint = $("#cambioSimplePreviewHint");
    if (hint) hint.textContent = texto ? "Texto aplicado al campo." : "Campo dejado vacío.";
  }

  function bindCambioSimplePreview() {
    $("#btnVerCambioSimple")?.addEventListener("click", abrirCambioSimplePreview);
    $("#btnCerrarCambioSimple")?.addEventListener("click", cerrarCambioSimplePreview);
    $("#btnUsarCambioSimple")?.addEventListener("click", usarTextoCambioSimple);
    $("#cambioSimpleEditar")?.addEventListener("input", (e) => {
      pintarVistaCambioSimple(e.target.value);
    });
    $("#modalCambioSimple")?.addEventListener("click", (e) => {
      if (e.target.id === "modalCambioSimple") cerrarCambioSimplePreview();
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !$("#modalCambioSimple")?.classList.contains("hidden")) {
        cerrarCambioSimplePreview();
      }
    });
  }

  let _lastCriteriosTexto = null;

  function renderAnCriteriosDinamicosDesdeTexto(forzar = false) {
    const cont = $("#anCriteriosDinamicosLista");
    if (!cont) return;
    const txt = val("#criteriosAceptacion");
    if (!forzar && txt === _lastCriteriosTexto) return;
    _lastCriteriosTexto = txt;

    const lineas = txt
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    cont.innerHTML = "";
    if (!lineas.length) {
      cont.innerHTML = `<p class="hint compact" style="margin:0;color:var(--q-muted);font-style:italic;padding:0.4rem 0;">Sin criterios añadidos. Agregue uno arriba o pídalos al agente.</p>`;
      return;
    }

    lineas.forEach((linea, idx) => {
      const limpia = linea.replace(/^[-*•\d\.\)]\s*/, "").trim();
      const row = document.createElement("div");
      row.className = "dynamic-item-row";
      row.innerHTML = `
        <label class="dynamic-item-label" style="display:flex;align-items:center;gap:8px;flex:1;cursor:pointer;margin:0;">
          <input type="checkbox" class="an-criterio-chk" style="width:16px;height:16px;accent-color:var(--q-primary);cursor:pointer;">
          <span class="dynamic-item-text" style="font-size:0.88rem;color:var(--q-dark);line-height:1.4;">${esc(limpia)}</span>
        </label>
        <button type="button" class="btn-item-delete" title="Eliminar criterio" style="border:none;background:transparent;color:#c62828;cursor:pointer;padding:4px 6px;border-radius:4px;display:flex;align-items:center;">
          <span class="material-symbols-outlined" style="font-size:1.1rem;">delete</span>
        </button>
      `;

      const chk = row.querySelector(".an-criterio-chk");
      const span = row.querySelector(".dynamic-item-text");
      chk?.addEventListener("change", () => {
        if (chk.checked) {
          span.style.textDecoration = "line-through";
          span.style.color = "var(--q-muted)";
          row.style.background = "#f1f8e9";
        } else {
          span.style.textDecoration = "none";
          span.style.color = "var(--q-dark)";
          row.style.background = "#fff";
        }
      });

      row.querySelector(".btn-item-delete")?.addEventListener("click", () => {
        row.remove();
        sincronizarAnCriteriosHaciaTexto();
      });

      cont.appendChild(row);
    });
  }

  function sincronizarAnCriteriosHaciaTexto() {
    const cont = $("#anCriteriosDinamicosLista");
    if (!cont) return;
    const items = cont.querySelectorAll(".dynamic-item-text");
    const arr = [];
    items.forEach((item, idx) => {
      const t = item.textContent.trim();
      if (t) arr.push(`${idx + 1}. ${t}`);
    });
    const nuevoTxt = arr.join("\n");
    _lastCriteriosTexto = nuevoTxt;
    setVal("#criteriosAceptacion", nuevoTxt);
    saveToStorage();
    updateAll();
  }

  function agregarNuevoAnCriterio() {
    const input = $("#anNuevoCriterioInput");
    if (!input) return;
    const v = input.value.trim();
    if (!v) return;
    const cur = val("#criteriosAceptacion");
    const lineas = cur ? cur.split("\n").filter((l) => l.trim()) : [];
    lineas.push(`${lineas.length + 1}. ${v}`);
    const nuevoTxt = lineas.join("\n");
    _lastCriteriosTexto = nuevoTxt;
    setVal("#criteriosAceptacion", nuevoTxt);
    input.value = "";
    renderAnCriteriosDinamicosDesdeTexto(true);
    saveToStorage();
    updateAll();
  }

  function bindCriterios() {
    $("#btnSugerirCriterios")?.addEventListener("click", () => sugerirCriterios(false));
    $("#btnRefinarCriterios")?.addEventListener("click", () => sugerirCriterios(true));
    $("#anBtnAddCriterio")?.addEventListener("click", () => agregarNuevoAnCriterio());
    $("#anNuevoCriterioInput")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        agregarNuevoAnCriterio();
      }
    });
    $("#criteriosAceptacion")?.addEventListener("input", () => {
      renderAnCriteriosDinamicosDesdeTexto();
    });
    document.addEventListener("click", (e) => {
      if (e.target.closest(".btn-usar-criterios")) aplicarCriteriosSugeridos("reemplazar");
      if (e.target.closest(".btn-anadir-criterios")) aplicarCriteriosSugeridos("anadir");
      if (e.target.closest(".btn-descartar-criterios")) ocultarSugerenciaCriterios();
    });
  }

  function ocultarSugerenciaCriterios() {
    $("#criteriosSugerenciaBox")?.classList.add("hidden");
    $("#criteriosSugerenciaBoxAnalisis")?.classList.add("hidden");
  }

  function mostrarSugerenciaCriterios(texto, enAnalisis) {
    $$(".criterios-sugerencia-texto").forEach((el) => {
      el.textContent = texto;
    });
    $("#criteriosSugerenciaBox")?.classList.toggle("hidden", !!enAnalisis);
    $("#criteriosSugerenciaBoxAnalisis")?.classList.toggle("hidden", !enAnalisis);
  }

  function captureCriteriosOriginales() {
    if (!criteriosMeta.originales && val("#criteriosAceptacion")) {
      criteriosMeta.originales = val("#criteriosAceptacion");
      criteriosMeta.originalesEn = new Date().toISOString();
    }
  }

  function captureCriteriosTrasAnalisis() {
    const actuales = val("#criteriosAceptacion");
    if (!actuales || !val("#analisis")) return;
    criteriosMeta.trasAnalisis = actuales;
    criteriosMeta.trasAnalisisEn = new Date().toISOString();
  }

  async function sugerirCriterios(usarAnalisis) {
    const req = val("#requerimiento");
    const cola = val("#colaArchivoManual") || archivoColaVinculado;
    if (!req && !cola) return alert("Escriba el requerimiento o registre la cola primero.");
    if (usarAnalisis && !val("#analisis")) return alert("Escriba el análisis primero.");
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID caso (paso 1).");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/");
    }
    if (isAnalisisEnCurso()) return;
    captureCriteriosOriginales();
    saveToStorage();
    switchToFormulario();
    goStep(2);
    const btn = $("#btnSugerirCriterios");
    const btnRefinar = $("#btnRefinarCriterios");
    const hintOai = $("#openaiEstadoHint");
    const loadingToken = ++analisisLoadingToken;
    if (btn) btn.disabled = true;
    if (btnRefinar) btnRefinar.disabled = true;
    showAnalisisLoading(
      usarAnalisis ? "Actualizando criterios con el agente" : "Pidiendo criterios al agente",
      "El agente arma criterios, alcance, restricciones y análisis…",
      idCaso,
    );
    if (hintOai) hintOai.textContent = "Pidiendo criterios al agente (Cursor)…";
    try {
      const data = collectData();
      const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ solicitud: data, proponerCriterios: true, usarAnalisis }),
      });
      const out = await parseJsonResponse(resp);
      if (!resp.ok) throw new Error(out.error || "No se pudo guardar");
      if (out.bot && out.bot.ok === false) {
        throw new Error(out.bot.error === "sin_clave" ? "Falta CURSOR_API_KEY en .env" : (out.bot.error || "El bot no arrancó"));
      }
      if (hintOai) {
        hintOai.textContent =
          "El agente está armando criterios, alcance, restricciones y análisis. El formulario se actualizará solo.";
      }
      if (usarAnalisis) {
        const hint = $("#criteriosRefineHint");
        if (hint) hint.textContent = "El agente actualiza los criterios en el Chat y en este formulario.";
      }
      await pollBrechaAnalisis(idCaso, hintOai, loadingToken);
    } catch (e) {
      if (hintOai) hintOai.textContent = e.message || "Error al pedir criterios";
      alert(e.message || "No se pudieron pedir los criterios al agente.");
    } finally {
      if (loadingToken === analisisLoadingToken) hideAnalisisLoading();
      if (btn) btn.disabled = false;
      if (btnRefinar) btnRefinar.disabled = false;
    }
    if (loadingToken === analisisLoadingToken) await cargarSolicitudCaso(idCaso);
  }

  function aplicarCriteriosSugeridos(modo) {
    const s = criteriosMeta.sugeridos;
    if (!s) return;
    captureCriteriosOriginales();
    const cur = val("#criteriosAceptacion");
    if (modo === "anadir" && cur) {
      $("#criteriosAceptacion").value = cur + "\n" + s;
    } else {
      $("#criteriosAceptacion").value = s;
      if (!criteriosMeta.originales) {
        criteriosMeta.originales = s;
        criteriosMeta.originalesEn = new Date().toISOString();
      }
    }
    if (val("#analisis")) captureCriteriosTrasAnalisis();
    ocultarSugerenciaCriterios();
    saveToStorage();
    updateAll();
  }

  function updateCriteriosHint() {
    const el = $("#criteriosEstadoHint");
    if (el) el.textContent = QrysCriterios.estadoLabel(criteriosMeta, val("#criteriosAceptacion"));
    renderAnCriteriosDinamicosDesdeTexto();
  }

  function renderCriteriosComparacion() {
    const box = $("#criteriosComparacion");
    if (!box) return;
    const actuales = val("#criteriosAceptacion");
    const baseline = QrysCriterios.baselineCierre(criteriosMeta);
    if (!baseline && !actuales) {
      box.innerHTML = "";
      box.classList.add("hidden");
      return;
    }
    box.classList.remove("hidden");
    const coinciden = baseline ? QrysCriterios.sonIguales(baseline, actuales) : true;
    const badge = baseline
      ? coinciden
        ? `<span class="compare-badge ok">Los criterios definitivos coinciden con la referencia</span>`
        : `<span class="compare-badge fail">Los criterios definitivos difieren de la referencia</span>`
      : `<span class="compare-badge">Sin referencia aún (sugiera o avance el análisis)</span>`;
    const refLabel = criteriosMeta.trasAnalisis
      ? "Tras análisis"
      : criteriosMeta.sugeridos
        ? "Sugeridos"
        : "Originales";
    box.innerHTML = `
      <h3>Validación de criterios</h3>
      ${badge}
      <div class="criterios-compare">
        <div class="compare-col ${coinciden ? "compare-ok" : "compare-diff"}">
          <h4>${refLabel}</h4>
          ${esc(baseline || "—").replace(/\n/g, "<br>")}
        </div>
        <div class="compare-col ${coinciden ? "compare-ok" : "compare-diff"}">
          <h4>Definitivos (actuales)</h4>
          ${esc(actuales || "—").replace(/\n/g, "<br>")}
        </div>
      </div>`;
  }

  function bindHistorico() {
    $("#btnRefrescarHistorico")?.addEventListener("click", () => refreshHistorico());
    $("#btnExportHistorico").addEventListener("click", () => QrysHistorico.exportJson());
    $("#btnImportHistorico").addEventListener("click", () => $("#importHistoricoFile").click());
    $("#importHistoricoFile").addEventListener("change", async (e) => {
      const f = e.target.files?.[0];
      if (!f) return;
      try {
        await QrysHistorico.importJson(f);
        QrysHistorico.render($("#historicoBody"), abrirDesdeHistorico);
        alert("Histórico importado.");
      } catch {
        alert("Error al importar JSON.");
      }
      e.target.value = "";
    });
  }

  function normalizeSqlFileName(name) {
    const n = name.trim();
    if (!n) return "";
    if (n.toLowerCase().endsWith(".sql")) return n;
    if (/^(SPK_|SPQ_|FNK_|VWK_)/i.test(n)) return n + ".sql";
    return n;
  }

  function parseSqlTextareaLines() {
    return val("#objetosSolicitados")
      .split("\n")
      .map((l) => normalizeSqlFileName(l))
      .filter(Boolean);
  }

  function getSqlArchivosSeleccionados() {
    if (sqlChecklistState?.files?.length) {
      return sqlChecklistState.files.filter((f) => f.checked).map((f) => f.name);
    }
    return parseSqlTextareaLines();
  }

  function emptyMetodosKb() {
    return { procesoId: "", sps: [], seleccion: {}, nota: "", actualizado: "", verTodos: false };
  }

  function filasSpsBrechaKb() {
    const raw = brechaAnalisis?.sps;
    const out = [];
    const walk = (val) => {
      if (val == null) return;
      if (Array.isArray(val)) {
        val.forEach(walk);
        return;
      }
      if (typeof val === "string") {
        if (val.trim()) out.push({ rol: val.trim() });
        return;
      }
      if (typeof val === "object") {
        if (val.sp || val.nombre || val.metodo) {
          out.push(val);
          return;
        }
        Object.values(val).forEach(walk);
      }
    };
    walk(raw);
    return out;
  }

  function textoReqParaSqlKb() {
    const brechaSps = filasSpsBrechaKb()
      .map((s) => `${s.sp || ""} ${s.metodo || ""} ${s.rol || ""}`)
      .join("\n");
    return [
      val("#requerimiento"),
      val("#cambioPropuestoSimple"),
      val("#analisis"),
      val("#alcance"),
      val("#restricciones"),
      val("#recomendacion"),
      brechaAnalisis?.texto || "",
      brechaSps,
    ].filter(Boolean).join("\n");
  }

  function extraerCitasSqlKb(texto) {
    const pares = [];
    const vistos = new Set();
    const re = /\b(SPQ_[A-Z0-9_]+|SPK_[A-Z0-9_]+|FNK_[A-Z0-9_]+)\b/g;
    let m;
    const src = texto || "";
    while ((m = re.exec(src))) {
      const sp = m[1];
      const after = src.slice(m.index + m[0].length, m.index + m[0].length + 90);
      const mm = /(?:·\s*|METODO\s+|\/\s*)([A-Z][A-Z0-9_]{2,})(?:\s+y\s+([A-Z][A-Z0-9_]{2,}))?/.exec(after);
      const mets = mm ? [mm[1], mm[2]].filter(Boolean) : [""];
      mets.forEach((met) => {
        const key = `${sp}|${met}`;
        if (vistos.has(key)) return;
        vistos.add(key);
        pares.push({ sp, metodo: met });
      });
    }
    filasSpsBrechaKb().forEach((s) => {
      const sp = String(s.sp || "").toUpperCase();
      const met = String(s.metodo || "").toUpperCase();
      if (!sp) return;
      const key = `${sp}|${met}`;
      if (vistos.has(key)) return;
      vistos.add(key);
      pares.push({ sp, metodo: met, rol: s.rol || "", estado: s.estado || "no_leido" });
    });
    return pares;
  }

  function textoReqNormalizadoKb(texto) {
    return (texto || "").toLowerCase()
      .replace(/colillas_prenomina/g, "colillas")
      .replace(/colillas\s+prenomina/g, "colillas");
  }

  function clavesDistintivasReq(texto) {
    const t = textoReqNormalizadoKb(texto);
    return [
      "colilla", "impres", "desprendible", "furips", "cum", "dian",
      "retiro", "nemphis", "historico", "prenomina", "vacacion", "cesant",
    ].filter((k) => t.includes(k));
  }

  function scoreMetodoKb(sp, metodo, texto, citas, claves) {
    const mid = metodo.id || metodo.nombre || "";
    const blob = `${sp.nombre || ""} ${mid} ${metodo.hace || ""} ${metodo.gateId || ""} ${metodo.capaId || ""}`.toLowerCase();
    const spU = String(sp.nombre || "").toUpperCase();
    const metU = String(mid).toUpperCase();
    const t = textoReqNormalizadoKb(texto);
    let score = 0;
    citas.forEach((c) => {
      if (c.sp !== spU) return;
      score += c.metodo && c.metodo === metU ? 12 : c.metodo ? 0 : 6;
    });
    filasSpsBrechaKb().forEach((s) => {
      if (String(s.sp || "").toUpperCase() === spU && String(s.metodo || "").toUpperCase() === metU) {
        score += 14;
      }
    });
    claves.forEach((k) => {
      if (blob.includes(k)) score += 3;
    });
    if (blob.includes("historico") && !t.includes("historico") && !t.includes("nemphis")) score -= 5;
    if ((blob.includes("retiro") || blob.includes("retiros")) && !t.includes("retiro")) score -= 5;
    if (blob.includes("dian") && !t.includes("dian")) score -= 5;
    if (
      blob.includes("prenomina")
      && !metU.includes("COLILLAS")
      && t.includes("colilla")
      && !t.replace("colillas_prenomina", "").includes("prenomina")
    ) {
      score -= 4;
    }
    return score;
  }

  function metodoRelevanteKb(sp, metodo, texto, citas, claves) {
    return scoreMetodoKb(sp, metodo, texto, citas, claves) > 0;
  }

  function citasFueraDeCatalogo(citas, sps) {
    const enCat = new Set();
    (sps || []).forEach((sp) => {
      (sp.metodos || []).forEach((m) => {
        enCat.add(`${String(sp.nombre || "").toUpperCase()}|${String(m.id || m.nombre || "").toUpperCase()}`);
      });
    });
    return (citas || []).filter((c) => {
      if (!c.sp) return false;
      if (!c.metodo) return !enCat.has(`${c.sp}|`) && ![...enCat].some((k) => k.startsWith(`${c.sp}|`));
      return !enCat.has(`${c.sp}|${c.metodo}`);
    });
  }

  function metodoKbKey(spNombre, metodoId) {
    return `${spNombre || ""}|${metodoId || ""}`;
  }

  function getMetodosDocumentadosSeleccionados() {
    const sps = metodosKbState.sps || [];
    const out = [];
    sps.forEach((sp) => {
      (sp.metodos || []).forEach((m) => {
        const id = m.id || m.nombre || "";
        if (!id) return;
        if (!metodosKbState.seleccion[metodoKbKey(sp.nombre, id)]) return;
        out.push({
          sp: sp.nombre,
          metodo: id,
          estado: m.estado || sp.estado || "no_leido",
          hace: m.hace || "",
          llama: m.llama || [],
        });
      });
    });
    return out;
  }

  function hayMetodosDocumentados() {
    return !!$("#chkUsarDocSp")?.checked && getMetodosDocumentadosSeleccionados().length > 0;
  }

  function sqlPasoListoParaActivar() {
    if (hayMetodosDocumentados()) return true;
    return getSqlArchivosSeleccionados().length > 0 && !!$("#chkSqlColocados")?.checked;
  }

  function sqlPasoPuedeAvanzar() {
    return hayMetodosDocumentados() || getSqlArchivosSeleccionados().length > 0;
  }

  function codigoModuloForm() {
    const raw = val("#moduloNombre") || "";
    const first = raw.split(/[·|,]/)[0].trim();
    return first.split(/\s+/)[0].toUpperCase();
  }

  async function fetchJsonKb(url) {
    const r = await fetch(url, { cache: "no-store" });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || data.mensaje || r.statusText || String(r.status));
    return data;
  }

  async function cargarOpcionesProcesoSql() {
    const sel = $("#sqlProcesoId");
    if (!sel) return;
    const prev = sel.value || metodosKbState.procesoId || "";
    try {
      let procesos = [];
      try {
        const data = await fetchJsonKb("/api/conocimiento");
        procesos = data.indice?.procesos || data.procesos || [];
      } catch (_) {
        const indice = await fetchJsonKb("/conocimiento/INDICE.json");
        procesos = indice.procesos || [];
      }
      const code = codigoModuloForm();
      const matched = procesos.find((p) => (p.modulo || "").toUpperCase() === code)
        || procesos.find((p) => (p.nombre || "").toUpperCase() === code)
        || procesos.find((p) => code && (p.modulo || "").toUpperCase().startsWith(code));
      sel.innerHTML = `<option value="">Proceso…</option>` + procesos
        .map((p) => `<option value="${esc(p.id)}">${esc(p.nombre || p.id)}${p.modulo ? ` (${esc(p.modulo)})` : ""}</option>`)
        .join("");
      const chosen = prev || matched?.id || "";
      if (chosen) sel.value = chosen;
      metodosKbState.procesoId = sel.value;
    } catch (e) {
      if ($("#sqlKbEstado")) $("#sqlKbEstado").textContent = "No se pudo leer conocimiento/";
    }
  }

  async function traerMetodosKb(silent) {
    await cargarOpcionesProcesoSql();
    const procesoId = $("#sqlProcesoId")?.value || "";
    const estadoEl = $("#sqlKbEstado");
    if (!procesoId) {
      if (!silent) alert("Elija el proceso (o complete el módulo del caso para sugerirlo).");
      if (estadoEl) estadoEl.textContent = "Sin proceso";
      return;
    }
    try {
      let sps = [];
      let nota = "";
      let actualizado = "";
      try {
        const data = await fetchJsonKb(`/api/conocimiento/proceso/${encodeURIComponent(procesoId)}`);
        const proc = data.proceso || data;
        sps = proc.sps || proc.procedimientos || [];
        nota = proc.spsNota || "";
        actualizado = proc.spsActualizado || proc.actualizado || "";
      } catch (_) {
        const cat = await fetchJsonKb(`/conocimiento/${encodeURIComponent(procesoId)}/sps.json`);
        sps = cat.sps || cat.procedimientos || [];
        nota = cat.nota || "";
        actualizado = cat.actualizado || "";
      }
      const misma = metodosKbState.procesoId === procesoId;
      metodosKbState.procesoId = procesoId;
      metodosKbState.sps = sps;
      metodosKbState.nota = nota;
      metodosKbState.actualizado = actualizado;
      if (!misma) metodosKbState.seleccion = {};
      renderMetodosKbLista();
      const nMet = sps.reduce((acc, sp) => acc + (sp.metodos || []).length, 0);
      if (estadoEl) {
        estadoEl.textContent = nMet
          ? `${nMet} en el módulo · se filtran por este REQ`
          : "Sin métodos documentados — use la carpeta del caso";
      }
      if (!nMet && !silent) {
        alert("Este proceso aún no tiene métodos en sps.json. Coloque el .sql en la carpeta del caso.");
      }
    } catch (e) {
      if (estadoEl) estadoEl.textContent = "Error al traer métodos";
      if (!silent) alert(`No se pudieron traer los métodos:\n${e.message}`);
    }
  }

  function renderMetodosKbLista() {
    const box = $("#sqlMetodosKbLista");
    if (!box) return;
    const sps = metodosKbState.sps || [];
    if (!sps.length) {
      box.innerHTML = "";
      updateSqlPasoHint();
      renderSqlResumenCaso();
      return;
    }
    const filtro = ($("#sqlKbBuscar")?.value || "").trim().toLowerCase();
    const verTodos = !!metodosKbState.verTodos || !!$("#chkSqlKbTodos")?.checked;
    const textoReq = textoReqParaSqlKb();
    const hayReq = !!(textoReq || "").trim();
    const citas = extraerCitasSqlKb(textoReq);
    const claves = clavesDistintivasReq(textoReq);
    let visibles = 0;
    let total = 0;
    let relevantes = 0;
    const htmlLista = sps.map((sp) => {
      const metodos = sp.metodos || [];
      if (!metodos.length) return "";
      const rows = metodos.map((m) => {
        const id = m.id || m.nombre || "";
        if (!id) return "";
        total += 1;
        const key = metodoKbKey(sp.nombre, id);
        const seleccionado = !!metodosKbState.seleccion[key];
        const relevante = !hayReq || metodoRelevanteKb(sp, m, textoReq, citas, claves);
        if (relevante) relevantes += 1;
        const blob = `${sp.nombre} ${id} ${m.hace || ""}`.toLowerCase();
        const matchBuscar = !filtro || blob.includes(filtro) || seleccionado;
        const matchReq = verTodos || relevante || seleccionado;
        if (!matchBuscar || !matchReq) return "";
        visibles += 1;
        const checked = seleccionado ? "checked" : "";
        const est = (m.estado || sp.estado || "no_leido").replace(/\s+/g, "_");
        const hace = m.hace ? `<span class="hace">${esc(m.hace)}</span>` : "";
        const badgeReq = relevante && hayReq
          ? `<span class="sql-kb-badge sugerido">este REQ</span>`
          : "";
        return `<label class="sql-kb-metodo">
          <input type="checkbox" data-sp="${esc(sp.nombre)}" data-metodo="${esc(id)}" ${checked}>
          <span>
            <span class="kb-id">${esc(id)}</span>
            <span class="sql-kb-badge ${esc(est)}">${esc(est.replace(/_/g, " "))}</span>
            ${badgeReq}
            ${hace}
          </span>
        </label>`;
      }).join("");
      if (!rows.trim()) return "";
      return `<div class="sql-kb-sp">${esc(sp.nombre)}</div>${rows}`;
    }).join("");
    const fuera = citasFueraDeCatalogo(citas, sps);
    const vacioReq = hayReq && !verTodos && relevantes === 0;
    const avisoVacio = (vacioReq || fuera.length)
      ? `<div class="sql-kb-vacio">${
          `<p><strong>Son los de este REQ</strong> (los que participan en el cambio). No es una lista de pendientes por bajar.</p>`
        }${
          fuera.length
            ? `<p>Aún no tienen ficha en <code>sps.json</code>, por eso no salen con casilla. El Chat pedirá el .sql <em>solo</em> si hay que leer el cuerpo hoy:</p>
              <ul>${fuera.map((c) => `<li><code>${esc(c.sp)}</code>${c.metodo ? ` · <strong>${esc(c.metodo)}</strong>` : ""}${c.rol ? ` — ${esc(c.rol)}` : ""} <span class="sql-kb-badge no_leido">sin ficha</span></li>`).join("")}</ul>`
            : vacioReq
              ? `<p>Ninguno de esos está todavía en el catálogo documentado del módulo. El resto del módulo no se lista.</p>`
              : ""
        }${
          vacioReq
            ? `<p class="hint">«Ver todos los del módulo» solo si necesita marcar uno que el filtro ocultó. «Usar estos métodos documentados» aplica cuando hay casillas marcadas, no a esta lista.</p>`
            : ""
        }</div>`
      : "";
    box.innerHTML = avisoVacio + htmlLista;

    box.querySelectorAll("input[type=checkbox]").forEach((cb) => {
      cb.addEventListener("change", () => {
        const key = metodoKbKey(cb.dataset.sp, cb.dataset.metodo);
        if (cb.checked) metodosKbState.seleccion[key] = true;
        else delete metodosKbState.seleccion[key];
        const n = Object.keys(metodosKbState.seleccion).length;
        const chk = $("#chkUsarDocSp");
        if (chk) chk.checked = n > 0;
        actualizarAvisoReleerKb();
        saveToStorage();
        updateAll();
      });
    });
    const estadoEl = $("#sqlKbEstado");
    if (estadoEl && total) {
      if (filtro) {
        estadoEl.textContent = `${visibles} de ${total} método(s)`;
      } else if (hayReq && !verTodos) {
        estadoEl.textContent = relevantes
          ? `${relevantes} de este REQ · ${total} en el módulo`
          : `0 de este REQ · ${total} ocultos del módulo`;
      } else {
        estadoEl.textContent = `${total} método(s) · ${metodosKbState.actualizado || "sin fecha"}`;
      }
    }
    if (!Object.keys(metodosKbState.seleccion).length && $("#chkUsarDocSp")) {
      $("#chkUsarDocSp").checked = false;
    }
    actualizarAvisoReleerKb();
    updateSqlPasoHint();
    renderSqlResumenCaso();
  }

  function renderSqlResumenCaso() {
    const html = buildSqlResumenHtml();
    ["#sqlResumenCaso", "#sqlResumenRevision"].forEach((sel) => {
      const el = $(sel);
      if (el) el.innerHTML = html;
    });
  }

  function buildSqlResumenHtml() {
    const procesoId = $("#sqlProcesoId")?.value || metodosKbState.procesoId || "";
    const catalogo = procesoId ? `conocimiento/${procesoId}/sps.json` : "conocimiento/<proceso>/sps.json";
    const metodos = getMetodosDocumentadosSeleccionados();
    const archivos = getSqlArchivosSeleccionados();
    const idCaso = val("#idCaso") || "{id-caso}";
    const idReq = val("#idReq") || "{ID-REQ}";
    const filasMet = metodos.length
      ? `<ul>${metodos.map((m) => `<li><code>${esc(m.sp)}</code> · <strong>${esc(m.metodo)}</strong> <span class="sql-kb-badge ${esc(m.estado)}">${esc(m.estado)}</span></li>`).join("")}</ul>`
      : "<p class=\"hint\">Ningún método marcado todavía.</p>";
    const filasSql = archivos.length
      ? `<ul>${archivos.map((a) => `<li><code>${esc(carpetaSqlCasoAbs())}${esc(a)}</code></li>`).join("")}</ul>`
      : "<p class=\"hint\">No hay .sql en la carpeta de este caso (el Chat los pedirá si hace falta releer).</p>";
    return `<h4>Dónde queda para el Chat</h4>
      <p><strong>Catálogo (fichas):</strong> <code>${esc(catalogo)}</code></p>
      <p><strong>Métodos de este REQ</strong> (solo los marcados; no el catálogo del módulo — <code>activo/${esc(idCaso)}/solicitud.json</code> → <code>sql.metodosDocumentados</code>):</p>
      ${filasMet}
      <p><strong>SQL de este análisis</strong> (si hay que releer o no está documentado): <code>${esc(carpetaSqlCaso())}</code></p>
      ${filasSql}
      <p><strong>Tras cerrar fase 1:</strong> <code>${esc(PATH_SQL_REFE)}${esc(idReq)}\\</code></p>`;
  }

  function actualizarAvisoReleerKb() {
    const aviso = $("#sqlKbAvisoReleer");
    if (!aviso) return;
    const dudosos = getMetodosDocumentadosSeleccionados().filter((m) => m.estado !== "leido");
    if (dudosos.length) {
      aviso.hidden = false;
      aviso.textContent = "Hay métodos listados, parciales o no leídos: al activar, el Chat pedirá el .sql de hoy para esos.";
    } else {
      aviso.hidden = true;
      aviso.textContent = "";
    }
  }

  function updateSqlPasoHint() {
    const usa = hayMetodosDocumentados();
    const req = $("#sqlArchivosReq");
    const hint = $("#sqlArchivosHint");
    if (req) req.classList.toggle("hidden", usa);
    if (hint) hint.textContent = usa
      ? "(opcional: el Chat pedirá .sql si hay que releer)"
      : "(después del análisis; o cuando soporte/director confirme el SP)";
  }

  async function restaurarMetodosKb(sql) {
    if (!sql) return;
    if (sql.usarDocumentacion && $("#chkUsarDocSp")) $("#chkUsarDocSp").checked = true;
    if (sql.procesoId) metodosKbState.procesoId = sql.procesoId;
    const prevSel = {};
    (sql.metodosDocumentados || []).forEach((m) => {
      if (m?.sp && m?.metodo) prevSel[metodoKbKey(m.sp, m.metodo)] = true;
    });
    await cargarOpcionesProcesoSql();
    if (sql.procesoId && $("#sqlProcesoId")) $("#sqlProcesoId").value = sql.procesoId;
    if (sql.procesoId || (sql.metodosDocumentados || []).length) {
      await traerMetodosKb(true);
      if (Object.keys(prevSel).length) {
        metodosKbState.seleccion = prevSel;
        renderMetodosKbLista();
      }
    }
    updateSqlPasoHint();
    actualizarAvisoReleerKb();
    updateAll();
  }

  async function leerCarpetaSql(silent) {
    const errBox = $("#sqlLoadError");
    const btn = $("#btnLeerCarpetaSql");
    const estado = $("#sqlLeidoEstado");

    function showErr(msg) {
      if (errBox) {
        errBox.textContent = msg;
        errBox.classList.remove("hidden");
      }
      if (estado) estado.textContent = "";
      if (!silent) alert(msg);
    }

    function ok(msg) {
      if (errBox) errBox.classList.add("hidden");
      if (estado && msg) estado.textContent = msg;
    }

    if (!silent && btn) {
      btn.disabled = true;
      btn.textContent = "Leyendo…";
    }

    try {
      const idCaso = val("#idCaso").trim();
      if (!idCaso) {
        showErr("Indique el ID del caso (paso 1). Cada análisis lee solo activo/{id-caso}/sql/.");
        return false;
      }
      if (location.protocol === "file:") {
        showErr("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para leer la carpeta SQL del caso.");
        return false;
      }

      const resp = await fetch(`/api/sql?idCaso=${encodeURIComponent(idCaso)}&t=${Date.now()}`);
      const data = await parseJsonResponse(resp);
      const archivos = Array.isArray(data.archivos) ? data.archivos : [];
      const rel = data.rutaRelativa || carpetaSqlCaso(idCaso);

      if (!archivos.length) {
        sqlChecklistState = null;
        renderListaSqlNombres();
        ok(`${rel}/ no tiene .sql. Coloque los scripts de este caso y pulse Leer de nuevo.`);
        if (errBox) {
          errBox.textContent = `Carpeta ${rel}/ vacía. No se leen los .sql de otros análisis.`;
          errBox.classList.remove("hidden");
        }
        return false;
      }

      applySqlFromDirectory(archivos, "api");
      ok(`Leído de ${rel}/ · ${archivos.length} .sql`);
      return true;
    } catch (e) {
      showErr(e.message || "No se pudo leer la carpeta SQL del caso. ¿Está ejecutando abrir-app.bat?");
      return false;
    } finally {
      if (btn) {
        btn.disabled = false;
        btn.innerHTML = "📂 Leer carpeta SQL";
      }
    }
  }

  function applySqlFromDirectory(fileNames, origen) {
    const prevUnchecked = new Set(
      (sqlChecklistState?.files || []).filter((f) => !f.checked).map((f) => f.name),
    );

    sqlChecklistState = {
      origen,
      files: fileNames.map((name) => ({
        name: normalizeSqlFileName(name),
        checked: !prevUnchecked.has(normalizeSqlFileName(name)),
      })),
    };

    if (!prevUnchecked.size) {
      sqlChecklistState.files.forEach((f) => {
        f.checked = true;
      });
    }

    renderSqlChecklist();
    syncSqlTextareaFromChecklist();
    $("#sqlLeidoEstado").textContent = `${fileNames.length} .sql en carpeta · ${getSqlArchivosSeleccionados().length} seleccionados`;
    saveToStorage();
    updateAll();
  }

  function renderSqlChecklist() {
    const ul = $("#listaArchivosSql");
    if (!sqlChecklistState?.files?.length) {
      renderListaSqlNombres();
      return;
    }

    ul.innerHTML = sqlChecklistState.files
      .map(
        (f, i) => `
      <li class="sql-check-item ${f.checked ? "" : "is-off"}">
        <label>
          <input type="checkbox" class="sql-file-check" data-idx="${i}" ${f.checked ? "checked" : ""}>
          <code>${esc(f.name)}</code>
        </label>
      </li>`,
      )
      .join("");

    ul.querySelectorAll(".sql-file-check").forEach((cb) => {
      cb.addEventListener("change", () => {
        const file = sqlChecklistState.files[Number(cb.dataset.idx)];
        file.checked = cb.checked;
        cb.closest(".sql-check-item")?.classList.toggle("is-off", !file.checked);
        syncSqlTextareaFromChecklist();
        $("#sqlLeidoEstado").textContent = `${sqlChecklistState.files.length} .sql en carpeta · ${getSqlArchivosSeleccionados().length} seleccionados`;
        saveToStorage();
        updateAll();
      });
    });
  }

  function syncSqlTextareaFromChecklist() {
    if (!sqlChecklistState) return;
    $("#objetosSolicitados").value = getSqlArchivosSeleccionados().join("\n");
  }

  function updateSqlPath() {
    const idReq = val("#idReq") || "{ID-REQ}";
    setText("#pathSqlCaso", carpetaSqlCaso());
    setText("#pathSqlRefe", `sql_refe/${idReq}/`);
    if (!sqlChecklistState) renderListaSqlNombres();
  }

  async function archivarSql() {
    const idCaso = val("#idCaso");
    const idReq = val("#idReq");

    if (!idReq || !/^010\d{7}$/.test(idReq)) {
      return alert("Indique un ID REQ válido en paso 1 (ej. 0100016198).");
    }

    if (location.protocol === "file:") {
      return alert(
        "Ejecute servir-app.bat y abra http://localhost:8765/app/\n\n" +
          `O use: scripts\\archivar-sql.ps1 -IdReq ${idReq} -IdCaso ${idCaso}`,
      );
    }

    if (!idCaso) {
      return alert("Indique el ID del caso. El SQL se archiva desde activo/{id-caso}/sql/.");
    }

    const archivos = getSqlArchivosSeleccionados();
    const origen = carpetaSqlCaso(idCaso);
    const msg =
      `¿Archivar ${archivos.length || "los"} SQL de este caso?\n\n` +
      `Destino: sql_refe/${idReq}/\n` +
      `Origen: ${origen}\n\n` +
      "No mueve scripts de otros análisis.";

    if (!confirm(msg)) return;

    try {
      const resp = await fetch("/api/sql/archivar/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idCaso, idReq }),
      });
      const data = await resp.json().catch(() => ({}));

      if (!resp.ok || !data.ok) {
        throw new Error(data.error || "Error al archivar");
      }

      sqlChecklistState = null;
      $("#objetosSolicitados").value = "";
      $("#listaArchivosSql").innerHTML = "<li class='hint'>Carpeta SQL del caso archivada</li>";
      $("#sqlLeidoEstado").textContent = "";
      $("#chkSqlColocados").checked = false;
      $("#alertArchivoSql").hidden = false;

      QrysHistorico.upsert({
        idCaso,
        idReq,
        proyecto: val("#proyecto"),
        modulo: val("#moduloNombre"),
        fecha: val("#fecha"),
        estado: "aprobado",
        archivoCola: archivoColaVinculado,
        notas: `SQL archivados en sql_refe/${idReq}/`,
      });

      if (archivoColaVinculado) {
        QrysCola.updateEstado(archivoColaVinculado, "aprobado", {}, idReqVinculado);
        refreshColaTable();
      }

      saveToStorage();
      updateAll();

      alert(
        `${data.mensaje}\n\n` +
          `Archivos:\n${(data.movidos || []).map((m) => "• " + m).join("\n")}\n\n` +
          `Ruta: ${PATH_SQL_REFE}${idReq}\\`,
      );
    } catch (e) {
      alert(`No se pudo archivar.\n\n${e.message}\n\n¿Está ejecutando servir-app.bat?`);
    }
  }

  function renderListaSqlNombres() {
    const lines = parseSqlTextareaLines();
    const ul = $("#listaArchivosSql");
    if (!lines.length) {
      ul.innerHTML = "<li class='hint'>Escriba nombres arriba o pulse <strong>Leer carpeta SQL</strong></li>";
      return;
    }
    ul.innerHTML = lines.map((n) => `<li><code>${esc(n)}</code></li>`).join("");
  }

  function goStep(step) {
    if (step < 1 || step > totalSteps) return;
    if (isAnalisisEnCurso() && step !== currentStep) return;
    if (step > currentStep && !validateStep(currentStep, true)) return;
    if (currentStep === 2 && step !== 2) captureCriteriosOriginales();
    if (currentStep === 3 && step !== 3) captureCriteriosTrasAnalisis();
    currentStep = step;
    $$(".panel").forEach((p) => p.classList.toggle("active", Number(p.dataset.panel) === step));
    $$(".step").forEach((s) => {
      const n = Number(s.dataset.step);
      s.classList.toggle("active", n === step);
      s.classList.toggle("done", n < step && validateStep(n, false));
    });
    $("#btnPrev").disabled = step === 1;
    $("#btnNext").textContent = step === totalSteps ? "Finalizar" : "Siguiente";
    $("#stepIndicator").textContent = `Paso ${step} de ${totalSteps}`;
    const wizardScroll = $(".wizard-scroll");
    if (wizardScroll) wizardScroll.scrollTop = 0;
    if (step === totalSteps) updateAll();
    if (step === 4) {
      leerCarpetaSql(true);
      cargarOpcionesProcesoSql();
    }
  }

  function validateStep(step, showAlert) {
    const required = getRequiredForStep(step);
    const missing = required.filter(({ el, label }) => {
      if (step === 4 && el?.id === "objetosSolicitados") {
        return !sqlPasoPuedeAvanzar();
      }
      return !el?.value?.trim();
    });
    if (missing.length && showAlert) {
      const msg = missing
        .filter((m) => m.el?.id !== "objetosSolicitados")
        .map((m) => m.label);
      if (msg.length) {
        alert(`Complete:\n• ${msg.join("\n• ")}`);
        return false;
      }
    }
    if (step === 3 && $("#chkAfectaContabilidad")?.checked && !val("#contComoAfecta")) {
      if (showAlert) alert("Si afecta contabilidad, complete «Cómo lo afecta» (puede dictar).");
      return false;
    }
    if (step === 2 && !val("#requerimiento") && !archivoColaVinculado) {
      if (showAlert) alert("Indique requerimiento o vincule un archivo de cola/");
      return false;
    }
    return (
      (step === 4 || missing.length === 0) &&
      (step !== 2 || val("#requerimiento") || archivoColaVinculado)
    );
  }

  function getRequiredForStep(step) {
    const m = {
      1: [
        ["#idCaso", "ID caso"],
        ["#fecha", "Fecha"],
        ["#proyecto", "Proyecto"],
        ["#moduloNombre", "Módulo"],
        ["#asesor", "Asesor"],
        ["#coordinador", "Coordinador"],
        ["#titulo", "Título"],
        ["#prioridad", "Prioridad"],
        ["#estadoReq", "Estado"],
      ],
      2: [["#criteriosAceptacion", "Criterios de aceptación"]],
      3: [["#analisis", "Análisis"]],
      4: [],
    };
    return (m[step] || []).map(([sel, label]) => ({ el: $(sel), label }));
  }

  function isFormComplete() {
    return faltantesActivarAnalisis().length === 0;
  }

  function faltantesActivarAnalisis() {
    const issues = [];
    for (let s = 1; s <= 3; s++) {
      getRequiredForStep(s).forEach(({ el, label }) => {
        if (!el?.value?.trim()) issues.push(label);
      });
    }
    if (!archivoColaVinculado && !val("#requerimiento")) {
      issues.push("Cola HTML o texto del requerimiento (paso 2)");
    }
    if ($("#chkAfectaContabilidad")?.checked && !val("#contComoAfecta")) {
      issues.push("Contabilidad: «Cómo lo afecta»");
    }
    if (!sqlPasoListoParaActivar()) {
      const nMet = getMetodosDocumentadosSeleccionados().length;
      const nSql = getSqlArchivosSeleccionados().length;
      if (nMet > 0 && !$("#chkUsarDocSp")?.checked) {
        issues.push("SQL: marque «Usar las fichas marcadas…» (paso 4)");
      } else if (nSql > 0 && !$("#chkSqlColocados")?.checked) {
        issues.push("SQL: marque «Confirmo que coloqué todos los .sql…» (paso 4)");
      } else {
        issues.push("SQL: traiga y marque métodos documentados, o lea la carpeta del caso y confirme los .sql (paso 4)");
      }
    }
    return [...new Set(issues)];
  }

  function collectData() {
    const opciones = [];
    $$(".opcion-item").forEach((row) => {
      const titulo = row.querySelector(".opcion-titulo")?.value?.trim();
      const desc = row.querySelector(".opcion-desc")?.value?.trim();
      if (titulo || desc) opciones.push({ titulo, descripcion: desc });
    });

    const idCaso = val("#idCaso");
    const sqlArchivos = getSqlArchivosSeleccionados();

    return {
      meta: { version: "2.1", generadoEn: new Date().toISOString(), listoParaAnalisis: isFormComplete() },
      cola: {
        archivoCola: archivoColaVinculado,
        idReq: idReqVinculado || val("#idReq") || null,
        rutaCola: archivoColaVinculado ? QrysCola.PATH_COLA + archivoColaVinculado : null,
        instruccion: "El agente debe leer el HTML desde rutaCola en disco. No transcribir manualmente.",
      },
      identificacion: {
        idCaso,
        idReq: val("#idReq"),
        fecha: val("#fecha"),
        fechaAsignacion: val("#fechaAsignacion"),
        fechaDesarrollo: val("#fechaDesarrollo"),
        diasDesarrollo: val("#diasDesarrollo"),
        fechaEntregaCliente: val("#fechaEntregaCliente"),
        orden: val("#orden"),
      },
      proyecto: {
        nombre: val("#proyecto"),
        area: val("#area"),
        modulo: val("#moduloNombre"),
        rutaPantalla: val("#rutaPantalla"),
      },
      personas: {
        asesor: val("#asesor"),
        coordinador: val("#coordinador"),
        soporteProyecto: val("#soporteProyecto"),
        desarrollador: val("#desarrollador"),
        subidoPor: val("#subidoPor"),
      },
      gestion: {
        ticket: val("#ticket"),
        rama: val("#rama"),
        prioridad: val("#prioridad"),
        estado: val("#estadoReq"),
        aval: val("#aval"),
        tipo: val("#tipo"),
      },
      contenido: {
        titulo: val("#titulo"),
        requerimiento: val("#requerimiento"),
        criteriosAceptacion: val("#criteriosAceptacion"),
        alcance: val("#alcance"),
        restricciones: val("#restricciones"),
        analisis: val("#analisis"),
        opciones,
        recomendacion: val("#recomendacion"),
        cambioPropuestoSimple: val("#cambioPropuestoSimple"),
        cambioPropuestoSql: val("#cambioPropuestoSql"),
        solicitudOrigen: solicitudOrigen && solicitudOrigen.id
          ? { id: solicitudOrigen.id, titulo: solicitudOrigen.titulo || "" }
          : null,
        impactoFe: val("#impactoFe"),
        impactoApi: val("#impactoApi"),
        impactoSql: val("#impactoSql"),
        contabilidad: collectContabilidad(),
        validarAntes: collectValidarAntes(),
        imagenesNecesarias: val("#imagenesNecesarias"),
        imagenesAnalisis: imagenesAnalisis
          .filter((i) => i.nombre && !i._subiendo)
          .map(({ nombre, ruta, subidaEn, url }) => ({ nombre, ruta, subidaEn, url })),
        archivosAnalisis: archivosAnalisis
          .filter((a) => a.nombre && !a._subiendo)
          .map(({ nombre, ruta, extracto, extractoRuta, tipo, mime, bytes, charsExtracto, avisoExtracto, subidaEn, url, urlExtracto }) => ({
            nombre, ruta, extracto, extractoRuta, tipo, mime, bytes, charsExtracto, avisoExtracto, subidaEn, url, urlExtracto,
          })),
        criteriosMeta,
        brechaAnalisis,
        diagramaFlujo: diagramaFlujo
          ? {
              ...diagramaFlujo,
              notas: val("#notasDiagramaFlujo"),
            }
          : val("#notasDiagramaFlujo")
            ? { notas: val("#notasDiagramaFlujo") }
            : null,
        mockups: filterMockupsForCaso(mockupsFormDraft.slice(), val("#idCaso")),
        mockupsNotas: val("#notasMockups"),
      },
      sql: {
        carpetaFija: carpetaSqlCasoAbs(),
        carpetaRelativa: carpetaSqlCaso(),
        carpetaSqlRefe: `${PATH_SQL_REFE}${val("#idReq") || "{ID-REQ}"}\\`,
        archivosEsperados: sqlArchivos,
        confirmadoEnCarpeta: $("#chkSqlColocados").checked,
        usarDocumentacion: hayMetodosDocumentados(),
        procesoId: $("#sqlProcesoId")?.value || metodosKbState.procesoId || "",
        catalogo: (() => {
          const pid = $("#sqlProcesoId")?.value || metodosKbState.procesoId || "";
          return pid ? `conocimiento/${pid}/sps.json` : "";
        })(),
        metodosDocumentados: getMetodosDocumentadosSeleccionados(),
        notas: val("#notasSql"),
        pruebasUnitarias: val("#pruebasSqlUnitarias"),
      },
      rutas: {
        dictamen: `dictamenes/${idCaso}.html`,
        aprobados: `aprobados/${idCaso}/`,
        imagenes: `aprobados/${idCaso}/imagenes/`,
      },
      correo: collectCorreo(),
    };
  }

  function buildPrompt(d) {
    return `# Solicitud dictamen — Qrystalos BA

## REGLA: Leer archivos en disco (no transcribir)
1. **Cola HTML:** ${d.cola.rutaCola || "(registrar en cola/)"}${d.cola.idReq ? ` (REQ ${d.cola.idReq})` : ""}
2. **SQL:** ${d.sql.usarDocumentacion
    ? `métodos documentados en conocimiento/${d.sql.procesoId || "?"}/sps.json — el Chat valida si hay que releer el .sql de hoy`
    : d.sql.carpetaFija}
${d.sql.usarDocumentacion && d.sql.metodosDocumentados?.length
    ? d.sql.metodosDocumentados.map((m) => `   - ${m.sp} · ${m.metodo} (${m.estado})`).join("\n")
    : (d.sql.archivosEsperados || []).map((a) => `   - ${a}`).join("\n") || "   - (ninguno)"}
3. Si falta cola, aclaración, o el Chat concluye que hace falta el .sql de hoy → **DETENER y pedir al coordinador**.

## Caso
- ID: ${d.identificacion.idCaso} | REQ: ${d.identificacion.idReq || "—"}
- Proyecto: ${d.proyecto.nombre} | Módulo: ${d.proyecto.modulo}
- Asesor: ${d.personas.asesor} | Coordinador: ${d.personas.coordinador}
- Prioridad: ${d.gestion.prioridad} | Rama: ${d.gestion.rama || "—"}

## Análisis coordinador (dictado/escrito)
${d.contenido.analisis}

${d.contenido.opciones.length ? "## Opciones\n" + d.contenido.opciones.map((o, i) => `${i + 1}. **${o.titulo}:** ${o.descripcion}`).join("\n") : ""}

${d.contenido.recomendacion ? "## Recomendación\n" + d.contenido.recomendacion : ""}

${d.contenido.cambioPropuestoSimple ? "## Cambio propuesto (palabras simples — sección 5.0 del dictamen)\n" + d.contenido.cambioPropuestoSimple : ""}

${d.contenido.cambioPropuestoSql ? "## Cambio propuesto — SQL (sección 5.2 del dictamen)\n```sql\n" + d.contenido.cambioPropuestoSql.trim() + "\n```" : ""}

## Validar antes de desarrollar
- Aplica: ${d.contenido.validarAntes?.aplica ? "Sí" : "No"}
${d.contenido.validarAntes?.aplica && d.contenido.validarAntes?.texto ? d.contenido.validarAntes.texto : ""}

## Contabilidad
- Afecta: ${d.contenido.contabilidad?.afecta ? "Sí" : "No"}
${d.contenido.contabilidad?.comoAfecta ? "- Cómo lo afecta:\n" + d.contenido.contabilidad.comoAfecta : ""}
${d.contenido.contabilidad?.desarrollo ? "- Desarrollo contable:\n" + d.contenido.contabilidad.desarrollo : ""}
${d.contenido.contabilidad?.validacion?.texto ? "- Validación agente:\n" + d.contenido.contabilidad.validacion.texto : ""}

## Criterios aceptación
${d.contenido.criteriosAceptacion}

${d.contenido.requerimiento ? "## Complemento requerimiento\n" + d.contenido.requerimiento : ""}

## Capturas para análisis
${(d.contenido.imagenesAnalisis || []).length
    ? (d.contenido.imagenesAnalisis || []).map((i) => `- activo/${d.identificacion.idCaso}/imagenes/${i.nombre}`).join("\n")
    : "(ninguna — el coordinador puede adjuntarlas en paso Requerimiento)"}

## Normativa / archivos (sección 4.6 del dictamen)
${(d.contenido.archivosAnalisis || []).length
    ? (d.contenido.archivosAnalisis || []).map((a) =>
        `- ${a.tipo || "normativa"}: activo/${d.identificacion.idCaso}/archivos/${a.nombre}`
        + (a.extracto ? `\n  extracto: activo/${d.identificacion.idCaso}/archivos/${a.extracto}` : "")
      ).join("\n")
    : "(ninguno — adjuntar circular/resolución en paso Requerimiento)"}

## Diagrama de flujo (sección 4.5 del dictamen)
${d.contenido.diagramaFlujo?.nombre
    ? `- HTML: activo/${d.identificacion.idCaso}/diagramas/${d.contenido.diagramaFlujo.nombre}\n- En dictamen usar enlace relativo: diagramas/${d.contenido.diagramaFlujo.nombre}\n${d.contenido.diagramaFlujo.notas ? "- Notas: " + d.contenido.diagramaFlujo.notas : ""}`
    : "(ninguno — botón «Generar diagrama» en paso Revisión: conocimiento + análisis)"}

## Mockups (UX / SP — complemento del REQ)
${(d.contenido.mockups || []).length
    ? (d.contenido.mockups || [])
        .map((r) => `- ${r}`)
        .join("\n") + (d.contenido.mockupsNotas ? `\n- Notas: ${d.contenido.mockupsNotas}` : "")
    : "(ninguno — botón «Generar mockups» en paso Revisión: conocimiento + análisis)"}

## Imágenes dictamen
${d.contenido.imagenesNecesarias || "El agente pedirá capturas si las necesita → aprobados/.../imagenes/"}

Generar: dictamenes/${d.identificacion.idCaso}.html
Al aprobar: copiar a aprobados/${d.identificacion.idCaso}/
`;
  }

  function listarObjetosSqlPrompt(d) {
    if (d.sql.usarDocumentacion && d.sql.metodosDocumentados?.length) {
      return d.sql.metodosDocumentados.map((m) => {
        const extra = m.hace ? ` — ${m.hace}` : "";
        const nested = m.llama?.length ? `\n     llama: ${m.llama.join(", ")}` : "";
        return `- ${m.sp} · METODO ${m.metodo} (${m.estado})${extra}${nested}`;
      }).join("\n");
    }
    const archivos = d.sql.archivosEsperados || [];
    const id = d.identificacion?.idCaso || "{id-caso}";
    if (archivos.length) {
      return archivos.map((a) => `- activo/${id}/sql/${a}`).join("\n");
    }
    return "(ninguno — indique objetos SQL o marque métodos documentados)";
  }

  function buildPromptPruebasSqlUnitarias(d) {
    const idCaso = d.identificacion.idCaso || "{id-caso}";
    const idReq = d.identificacion.idReq || "—";
    const objetos = listarObjetosSqlPrompt(d);
    const notasCoord = d.sql.pruebasUnitarias?.trim();
    const dictamen = d.rutas?.dictamen || `dictamenes/${idCaso}.html`;

    return `# Pruebas unitarias SQL — Qrystalos

## Rol
Eres experto en SQL Server y procesos Qrystalos. Diseña y ejecuta pruebas unitarias sobre los scripts del REQ **antes** de pasar a calidad. **No modifiques** los SP salvo para corregir un fallo demostrado; reporta resultados.

## Caso
- ID caso: ${idCaso} | REQ: ${idReq}
- Proyecto: ${d.proyecto.nombre || "—"} | Módulo: ${d.proyecto.modulo || "—"}
- Pantalla: ${d.proyecto.rutaPantalla || "—"}
- Rama desarrollo: ${d.gestion.rama || "—"}

## Objetos bajo prueba
${objetos}

## Fuentes (leer en disco)
- Scripts de este caso: \`activo/${idCaso}/sql/\` o archivados \`sql_refe/${idReq}/\`
${d.sql.usarDocumentacion && d.sql.catalogo ? `- Catálogo METODO: \`${d.sql.catalogo}\`` : ""}
- Dictamen (secciones 5 y 7): \`${dictamen}\`
- Solicitud: \`activo/${idCaso}/solicitud.json\`
${d.cola.rutaCola ? `- Cola REQ: \`${d.cola.rutaCola}\`` : ""}

## Cambio esperado (negocio)
${d.contenido.cambioPropuestoSimple?.trim() || "(ver dictamen sección 5.0 y criterios)"}

## Criterios de aceptación
${d.contenido.criteriosAceptacion?.trim() || "(completar en formulario)"}

${notasCoord ? `## Notas del coordinador (casos adicionales)\n${notasCoord}\n` : ""}${d.sql.notas?.trim() ? `## Notas SQL del caso\n${d.sql.notas.trim()}\n` : ""}
## Entorno y reglas
- Ejecutar solo en **preversión / copia de BD** (nunca producción).
- Usar transacciones con **ROLLBACK** cuando la prueba inserte o actualice datos.
- Convenciones: tablas MAYÚSCULAS; SPQ_* (API lógica) y SPK_* (núcleo); mensajes KO documentados en fichas METODO.
- Si un METODO está en \`sps.json\` con estado distinto de \`leido\`, releer el \`.sql\` de hoy antes de asumir comportamiento.

## Metodología por objeto (SP / METODO)
Para cada script listado arriba:

1. **Arrange** — Datos mínimos: tablas maestras, parámetros JSON/XML, usuario/sede/empresa si aplica.
2. **Act** — \`EXEC\` del procedimiento con happy path y casos borde.
3. **Assert** — Result sets, códigos/mensajes KO, filas afectadas, SPKs invocados, ausencia de efectos colaterales.

## Casos obligatorios
- [ ] Happy path alineado con cada criterio de aceptación
- [ ] Parámetros NULL, vacíos o fuera de rango
- [ ] Registros inexistentes (FK, estado inválido, documento cerrado)
- [ ] Duplicidad / idempotencia si el negocio lo exige
- [ ] Errores KO **esperados** (texto exacto si está documentado) vs errores inesperados
- [ ] Regresión: flujos vecinos no deben romperse
${d.contenido.contabilidad?.afecta ? "- [ ] Contabilidad: asientos MCUE/CON/MCPE según dictamen\n" : ""}${d.contenido.validarAntes?.aplica ? `- [ ] Validar antes: ${d.contenido.validarAntes.texto || "reproducir fallo original"}\n` : ""}
## Entregables
1. Scripts \`.sql\` de prueba (comentados o en carpeta temporal; sin datos sensibles del cliente).
2. Tabla resumen:

| # | Objeto | Escenario | Entrada | Resultado esperado | OK/KO |
|---|--------|-----------|---------|-------------------|-------|

3. Si hay KO: mensaje de error, filas afectadas y propuesta concreta de corrección.

## Restricciones
- No inventar columnas ni SPs: basarse en scripts leídos y documentación viva.
- No ejecutar DELETE masivo ni cambios destructivos sin acuerdo.
- Marcar incertidumbre explícitamente cuando falte evidencia.
`;
  }

  function buildPromptValidarDesarrollo(d) {
    const idCaso = d.identificacion.idCaso || "{id-caso}";
    const idReq = d.identificacion.idReq || "—";
    const dictamenAprob = `aprobados/${idCaso}/`;
    const dictamenProp = d.rutas?.dictamen || `dictamenes/${idCaso}.html`;

    return `# Validar desarrollo realizado — Qrystalos

## Rol
Valida que el desarrollo entregado cumple el **dictamen aprobado** y los **criterios de aceptación**. **No implementes cambios**: emite un veredicto con evidencia. Si algo no cuadra, indica archivo, línea o objeto SQL concreto.

## Caso
- ID caso: ${idCaso} | REQ: ${idReq}
- Desarrollador: ${d.personas.desarrollador || "—"}
- Rama Git: ${d.gestion.rama || "—"}
- Ticket: ${d.gestion.ticket || "—"}

## Fuentes obligatorias (leer en disco — no asumir)
1. Dictamen aprobado: \`${dictamenAprob}\` (o borrador \`${dictamenProp}\` si fase 1 aún abierta)
2. Solicitud: \`activo/${idCaso}/solicitud.json\`
3. Chat del caso: \`activo/${idCaso}/chat.json\`
${d.cola.rutaCola ? `4. Cola REQ: \`${d.cola.rutaCola}\`` : "4. Cola REQ: `cola/` (HTML del REQ)"}
5. SQL entregado: \`sql_refe/${idReq}/\` y/o diff en rama \`${d.gestion.rama || "feature/*"}\`
6. Qrystalos2: archivos Vue/stores indicados en dictamen (sección 5)
${d.contenido.impactoApi ? `7. Backend/API si aplica: revisar MODELO/METODO en AppStore.json vs SPQ_*` : ""}

## Cambio esperado (palabras simples)
${d.contenido.cambioPropuestoSimple?.trim() || "(dictamen §5.0)"}

## Criterios de aceptación (validar uno a uno)
${d.contenido.criteriosAceptacion?.trim() || "(completar en formulario)"}

${d.contenido.analisis?.trim() ? `## Análisis coordinador (contexto)\n${d.contenido.analisis.trim()}\n` : ""}${d.contenido.recomendacion?.trim() ? `## Recomendación del dictamen\n${d.contenido.recomendacion.trim()}\n` : ""}
## Objetos SQL del REQ
${listarObjetosSqlPrompt(d)}

${d.sql.pruebasUnitarias?.trim() ? `## Pruebas SQL acordadas\n${d.sql.pruebasUnitarias.trim()}\n` : ""}
## Checklist de validación

### SQL Server
- [ ] Objetos modificados coinciden con dictamen (nombres SPQ/SPK, METODO)
- [ ] Lógica alineada con fichas METODO en \`conocimiento/${d.sql.procesoId || "?"}/sps.json\` si aplica
- [ ] Sin cambios colaterales no documentados
- [ ] Pruebas unitarias SQL ejecutadas; tabla resumen OK/KO adjunta o descrita
- [ ] Mensajes de error KO coinciden con lo documentado

### Frontend (Qrystalos2)
- [ ] Pantallas/rutas según dictamen
- [ ] Llamadas \`AppStore.read\` / \`AppStore.json\` con MODELO y METODO correctos
- [ ] Permisos \`useUSGRUH\` si el dictamen los menciona
- [ ] UX coherente con pantallas vecinas

${d.contenido.contabilidad?.afecta ? `### Contabilidad
- [ ] Impacto MCUE / CON / MCPE según dictamen
- Cómo afecta: ${d.contenido.contabilidad.comoAfecta || "—"}
- Desarrollo contable esperado: ${d.contenido.contabilidad.desarrollo || "—"}
` : ""}${d.contenido.validarAntes?.aplica ? `### Validar antes de desarrollar
- [ ] Reproducir el fallo reportado en el REQ
- Si **ya no falla**: veredicto **CORRECTO SIN DESARROLLO** — no exigir merge
- Texto: ${d.contenido.validarAntes.texto || "—"}
` : ""}
## Formato de respuesta (obligatorio)

1. **Veredicto global**: CUMPLE | CUMPLE PARCIAL | NO CUMPLE | CORRECTO SIN DESARROLLO
2. **Por criterio de aceptación**: CA-1, CA-2… → OK / KO / N/A + evidencia breve
3. **Desviaciones** respecto al dictamen (archivo, SP, pantalla)
4. **Riesgos de regresión** identificados
5. **Acciones concretas** para el desarrollador (lista numerada, priorizada)
6. **Próximo paso** recomendado (rework, pruebas adicionales, listo para coordinador/soporte)

## Restricciones
- No inventar tablas, columnas ni SPs.
- Declarar explícitamente lo que no pudiste verificar por falta de acceso a rama/BD.
- Responder en español.
`;
  }

  async function copyTextToClipboard(text, mensajeOk) {
    try {
      await navigator.clipboard.writeText(text);
      alert(mensajeOk);
      return true;
    } catch {
      alert("No se pudo copiar al portapapeles. Use la vista previa y copie manualmente.");
      return false;
    }
  }

  async function copyPromptPruebasSql() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso.");
    if (!sqlPasoPuedeAvanzar()) {
      return alert("Indique objetos SQL (lista o carpeta) o seleccione métodos documentados en el paso SQL.");
    }
    const data = collectData();
    const prompt = buildPromptPruebasSqlUnitarias(data);
    await copyTextToClipboard(
      prompt,
      "Prompt de pruebas unitarias SQL copiado.\n\nPéguelo en Cursor junto con los scripts en activo/" + idCaso + "/sql/ o sql_refe/."
    );
  }

  async function copyPromptValidarDesarrollo() {
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID de caso.");
    if (!val("#criteriosAceptacion").trim()) {
      return alert("Complete los criterios de aceptación (paso Requerimiento) antes de validar el desarrollo.");
    }
    const data = collectData();
    const prompt = buildPromptValidarDesarrollo(data);
    await copyTextToClipboard(
      prompt,
      "Prompt de validación de desarrollo copiado.\n\nPéguelo en Cursor con la rama del desarrollador y el dictamen en aprobados/."
    );
  }

  function updateAll() {
    updateSqlPasoHint();
    actualizarAvisoReleerKb();
    renderSqlResumenCaso();
    const complete = isFormComplete();
    const data = collectData();
    $("#previewPrompt").textContent = buildPrompt(data);
    const prevPruebas = $("#previewPromptPruebasSql");
    if (prevPruebas) prevPruebas.textContent = buildPromptPruebasSqlUnitarias(data);
    const prevValidar = $("#previewPromptValidarDev");
    if (prevValidar) prevValidar.textContent = buildPromptValidarDesarrollo(data);
    const prevDiagrama = $("#previewPromptDiagrama");
    if (prevDiagrama) prevDiagrama.textContent = buildPromptDiagramaCaso(data);
    const btnDiagrama = $("#btnCopiarPromptDiagrama");
    if (btnDiagrama) btnDiagrama.disabled = !val("#idCaso");
    const btnGenDiagrama = $("#btnGenerarDiagrama");
    if (btnGenDiagrama) btnGenDiagrama.disabled = !val("#idCaso");
    renderDiagramaFlujo();
    renderMockupsForm();
    const btnGenMock = $("#btnGenerarMockups");
    if (btnGenMock) btnGenMock.disabled = !val("#idCaso") || location.protocol === "file:";
    const btnAbrirMock = $("#btnAbrirMockup");
    if (btnAbrirMock && !mockupsFormDraft.length) btnAbrirMock.disabled = true;
    const btnPruebasSql = $("#btnCopiarPromptPruebasSql");
    if (btnPruebasSql) btnPruebasSql.disabled = !val("#idCaso") || !sqlPasoPuedeAvanzar();
    const btnValidarDev = $("#btnCopiarPromptValidarDev");
    if (btnValidarDev) btnValidarDev.disabled = !val("#idCaso") || !val("#criteriosAceptacion").trim();
    const hintPruebas = $("#hintPruebasSql");
    if (hintPruebas) {
      hintPruebas.textContent = sqlPasoPuedeAvanzar()
        ? `${getSqlArchivosSeleccionados().length || getMetodosDocumentadosSeleccionados().length} objeto(s) en el prompt`
        : "Faltan objetos SQL o métodos documentados";
    }
    const hintValidar = $("#hintValidarDev");
    if (hintValidar) {
      hintValidar.textContent = val("#criteriosAceptacion").trim()
        ? "Incluye dictamen, criterios y checklist SQL/FE"
        : "Complete criterios de aceptación";
    }
    const btnActivar = $("#btnActivarAnalisis");
    const faltan = faltantesActivarAnalisis();
    if (btnActivar) {
      btnActivar.disabled = !complete;
      btnActivar.title = complete
        ? "Activa Fase 1: el agente lee el caso en disco"
        : `Falta: ${faltan.join("; ")}`;
    }
    const hintActivar = $("#activarAnalisisFalta");
    if (hintActivar) {
      hintActivar.classList.toggle("hidden", complete);
      hintActivar.innerHTML = complete
        ? ""
        : `<strong>El botón no se activa.</strong> Falta:<ul>${faltan.map((i) => `<li>${esc(i)}</li>`).join("")}</ul>`;
    }
    const btnCopiar = $("#btnCopiarPrompt");
    if (btnCopiar) btnCopiar.disabled = !complete;
    const btnChat = $("#btnAbrirChat");
    if (btnChat) btnChat.disabled = !val("#idCaso");

    const badge = $("#estadoFormulario");
    if (badge) {
      if (complete) {
        badge.textContent = "Listo";
        badge.className = "badge badge-listo";
      } else {
        badge.textContent = "Incompleto";
        badge.className = "badge badge-incompleto";
      }
    }
    refrescarBadgeFaseCerrada();

    const issues = faltantesActivarAnalisis();
    $("#validacionResumen").innerHTML = issues.length
      ? `<p class="fail"><strong>El botón «Activar análisis» no se activa. Falta:</strong></p><ul>${issues.map((i) => `<li>${esc(i)}</li>`).join("")}</ul>`
      : `<p class="ok"><strong>✓ Listo.</strong> Pulse <em>Activar análisis (Fase 1)</em> — no hace falta copiar prompt.</p>`;

    updateCriteriosHint();
    renderCriteriosComparacion();
  }

  function renderOpciones() {
    $("#opcionesLista").addEventListener("click", (e) => {
      if (e.target.classList.contains("remove-opcion")) {
        e.target.closest(".opcion-item")?.remove();
        updateAll();
      }
    });
  }

  function addOpcion(titulo, desc) {
    const div = document.createElement("div");
    div.className = "opcion-item";
    div.innerHTML = `
      <input type="text" class="opcion-titulo" placeholder="Opción" value="${esc(titulo)}">
      <textarea class="opcion-desc" placeholder="Descripción">${esc(desc)}</textarea>
      <button type="button" class="remove-opcion btn btn-ghost btn-sm">×</button>`;
    div.querySelectorAll("input, textarea").forEach((el) =>
      el.addEventListener("input", () => { saveToStorage(); updateAll(); }),
    );
    $("#opcionesLista").appendChild(div);
  }

  function escAttr(s) {
    return esc(s);
  }

  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;");
  }

  function val(sel) {
    const el = $(sel);
    return el ? el.value.trim() : "";
  }

  function setVal(sel, v) {
    const el = $(sel);
    if (el && v != null) el.value = v;
  }

  function setDefaultDates() {
    if (!$("#fecha").value) $("#fecha").value = new Date().toISOString().slice(0, 10);
  }

  function saveToStorage() {
    try {
      const data = collectData();
      data._archivoColaVinculado = archivoColaVinculado;
      data._idReqVinculado = idReqVinculado;
      data._sqlChecklistState = sqlChecklistState;
      data._metodosKbState = metodosKbState;
      data._criteriosMeta = criteriosMeta;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      persistBorrador(data);
    } catch (e) {
      console.warn(e);
    }
  }

  async function persistBorrador(data) {
    if (location.protocol === "file:") return;
    const idCaso = data.identificacion?.idCaso || "__ultimo__";
    try {
      await fetch("/api/borrador", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idCaso, datos: data }),
      });
    } catch {
      /* localStorage como respaldo */
    }
  }

  async function loadBorradorFromServer() {
    if (location.protocol === "file:") return null;
    try {
      const idCaso = val("#idCaso");
      const url = idCaso ? `/api/borrador?idCaso=${encodeURIComponent(idCaso)}` : "/api/borrador";
      const resp = await fetch(url);
      if (!resp.ok) return null;
      const data = await resp.json();
      return data.borrador || null;
    } catch {
      return null;
    }
  }

  function loadFromStorage() {
    loadFromStorageLocal();
    loadBorradorFromServer().then((remote) => {
      if (remote && !localStorage.getItem(STORAGE_KEY)) applyStorageData(remote);
    });
  }

  function loadFromStorageLocal() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY) || localStorage.getItem(STORAGE_KEY_LEGACY);
      if (!raw) return;
      if (!localStorage.getItem(STORAGE_KEY) && localStorage.getItem(STORAGE_KEY_LEGACY)) {
        localStorage.setItem(STORAGE_KEY, raw);
      }
      applyStorageData(JSON.parse(raw));
    } catch (e) {
      console.warn(e);
    }
  }

  function applyStorageData(data, opts) {
    const sondeo = !!opts?.sondeo;
    try {
      archivoColaVinculado = data._archivoColaVinculado || null;
      idReqVinculado = data._idReqVinculado || null;
      sqlChecklistState = data._sqlChecklistState || null;
      if (data._metodosKbState) metodosKbState = data._metodosKbState;
      criteriosMeta = data._criteriosMeta || data.contenido?.criteriosMeta || QrysCriterios.emptyMeta();
      if (archivoColaVinculado) {
        const suffix = idReqVinculado ? ` (${idReqVinculado})` : "";
        $("#archivoColaVinculado").textContent = QrysCola.PATH_COLA + archivoColaVinculado + suffix;
        $("#alertOrigenCola").hidden = false;
      }

      const set = (sel, v) => setVal(sel, v);
      set("#idCaso", data.identificacion?.idCaso);
      set("#idReq", data.identificacion?.idReq);
      set("#fecha", data.identificacion?.fecha);
      set("#fechaAsignacion", data.identificacion?.fechaAsignacion);
      set("#fechaDesarrollo", data.identificacion?.fechaDesarrollo);
      set("#diasDesarrollo", data.identificacion?.diasDesarrollo);
      set("#fechaEntregaCliente", data.identificacion?.fechaEntregaCliente);
      set("#orden", data.identificacion?.orden);
      set("#proyecto", data.proyecto?.nombre);
      set("#moduloNombre", data.proyecto?.modulo);
      set("#area", data.proyecto?.area);
      set("#rutaPantalla", data.proyecto?.rutaPantalla);
      set("#asesor", data.personas?.asesor);
      set("#coordinador", data.personas?.coordinador);
      set("#soporteProyecto", data.personas?.soporteProyecto);
      set("#desarrollador", data.personas?.desarrollador);
      set("#subidoPor", data.personas?.subidoPor);
      set("#ticket", data.gestion?.ticket);
      set("#rama", data.gestion?.rama);
      set("#prioridad", data.gestion?.prioridad);
      set("#estadoReq", data.gestion?.estado);
      set("#aval", data.gestion?.aval);
      set("#tipo", data.gestion?.tipo);
      set("#titulo", data.contenido?.titulo);
      set("#requerimiento", data.contenido?.requerimiento);
      set("#criteriosAceptacion", data.contenido?.criteriosAceptacion);
      set("#alcance", data.contenido?.alcance);
      set("#restricciones", data.contenido?.restricciones);
      set("#analisis", data.contenido?.analisis);
      set("#recomendacion", data.contenido?.recomendacion);
      set("#cambioPropuestoSimple", data.contenido?.cambioPropuestoSimple);
      set("#cambioPropuestoSql", data.contenido?.cambioPropuestoSql);
      solicitudOrigen = data.contenido?.solicitudOrigen?.id ? data.contenido.solicitudOrigen : null;
      pintarSolicitudOrigen();
      set("#impactoFe", data.contenido?.impactoFe);
      set("#impactoApi", data.contenido?.impactoApi);
      set("#impactoSql", data.contenido?.impactoSql);
      const cont = data.contenido?.contabilidad || {};
      if ($("#chkAfectaContabilidad")) $("#chkAfectaContabilidad").checked = !!cont.afecta;
      set("#contComoAfecta", cont.comoAfecta);
      set("#contDesarrollo", cont.desarrollo);
      contValidacion = cont.validacion || null;
      toggleContabilidad();
      renderContValidacion(contValidacion);
      brechaAnalisis = data.contenido?.brechaAnalisis || null;
      renderBrechaAnalisis(brechaAnalisis);
      const va = data.contenido?.validarAntes || {};
      if ($("#chkValidarAntes")) $("#chkValidarAntes").checked = !!va.aplica;
      set("#validarAntesTexto", va.texto);
      toggleValidarAntes();
      if (sondeo) return;
      set("#imagenesNecesarias", data.contenido?.imagenesNecesarias);
      imagenesAnalisis = (data.contenido?.imagenesAnalisis || []).map((i) => ({
        ...i,
        url: i.url || (data.identificacion?.idCaso && i.nombre
          ? imagenAnalisisUrl(data.identificacion.idCaso, i.nombre)
          : ""),
      }));
      renderImagenesAnalisis();
      archivosAnalisis = (data.contenido?.archivosAnalisis || []).map((a) => ({
        ...a,
        url: a.url || (data.identificacion?.idCaso && a.nombre
          ? archivoAnalisisUrl(data.identificacion.idCaso, a.nombre)
          : ""),
        urlExtracto: a.urlExtracto || (data.identificacion?.idCaso && a.extracto
          ? archivoAnalisisUrl(data.identificacion.idCaso, a.extracto)
          : ""),
      }));
      renderArchivosAnalisis();
      set("#objetosSolicitados", data.sql?.archivosEsperados?.join("\n"));
      set("#notasSql", data.sql?.notas);
      set("#pruebasSqlUnitarias", data.sql?.pruebasUnitarias);
      diagramaFlujo = data.contenido?.diagramaFlujo?.nombre ? data.contenido.diagramaFlujo : null;
      set("#notasDiagramaFlujo", data.contenido?.diagramaFlujo?.notas || "");
      renderDiagramaFlujo();
      const idCasoLoad = data.identificacion?.idCaso || val("#idCaso");
      mockupsFormCasoId = idCasoLoad || "";
      mockupsFormDraft = filterMockupsForCaso(
        Array.isArray(data.contenido?.mockups) ? data.contenido.mockups : [],
        idCasoLoad,
      );
      mockupsFormDirty = false;
      if (mockupsFormPreviewRuta && !mockupsFormDraft.includes(mockupsFormPreviewRuta)) {
        clearMockupFormPreview();
      }
      set("#notasMockups", data.contenido?.mockupsNotas || "");
      if (!sondeo) {
        if (idCasoLoad) refreshMockupsForm(idCasoLoad);
        else renderMockupsForm();
      } else {
        renderMockupsForm();
      }
      if (data.sql?.confirmadoEnCarpeta) $("#chkSqlColocados").checked = true;
      if (!sondeo) restaurarMetodosKb(data.sql);
      const correo = data.correo || {};
      if (correo.destinatario) setVal("#correoDestino", correo.destinatario);
      if (correo.fechaEnvio) setVal("#fechaEnvioCorreo", correo.fechaEnvio);
      if ($("#chkCorreoEnviado")) $("#chkCorreoEnviado").checked = !!correo.enviado;
      if (sqlChecklistState?.files?.length) {
        renderSqlChecklist();
        $("#sqlLeidoEstado").textContent = `${sqlChecklistState.files.length} .sql · ${getSqlArchivosSeleccionados().length} seleccionados`;
      }

      const opciones = data.contenido?.opciones || [];
      $("#opcionesLista").innerHTML = "";
      if (opciones.length) {
        opciones.forEach((o) => addOpcion(o.titulo || "", o.descripcion || ""));
      }
    } catch (e) {
      console.warn(e);
    }
  }

  function resetForm() {
    if (!confirm("¿Nuevo caso?")) return;
    localStorage.removeItem(STORAGE_KEY);
    location.reload();
  }

  function downloadJson() {
    const data = collectData();
    downloadBlob(new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }), `solicitud-${data.identificacion.idCaso}.json`);
  }

  async function loadJsZip() {
    if (typeof JSZip !== "undefined") return true;
    return new Promise((resolve) => {
      const s = document.createElement("script");
      s.src = "https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js";
      s.onload = () => resolve(true);
      s.onerror = () => resolve(false);
      document.head.appendChild(s);
    });
  }

  async function downloadZip() {
    const ok = await loadJsZip();
    if (!ok || typeof JSZip === "undefined") return downloadJson();
    const data = collectData();
    const zip = new JSZip();
    zip.file("solicitud.json", JSON.stringify(data, null, 2));
    zip.file("PROMPT-CURSOR.md", buildPrompt(data));
    zip.file("LEAME.txt", `Coloque HTML en: cola/\nSQL en: ${data.sql.carpetaFija}\nAprobados en: aprobados/${data.identificacion.idCaso}/`);
    const blob = await zip.generateAsync({ type: "blob" });
    downloadBlob(blob, `paquete-${data.identificacion.idCaso}.zip`);
  }

  function downloadBlob(blob, name) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  async function copyPrompt() {
    if (!isFormComplete()) return alert("Complete el formulario y confirme SQL en la carpeta del caso.");
    const data = collectData();
    const prompt = buildPrompt(data);

    QrysHistorico.upsert({
      idCaso: data.identificacion.idCaso,
      idReq: data.identificacion.idReq,
      proyecto: data.proyecto.nombre,
      modulo: data.proyecto.modulo,
      fecha: data.identificacion.fecha,
      estado: "en_analisis",
      archivoCola: archivoColaVinculado,
    });
    if (archivoColaVinculado) QrysCola.updateEstado(archivoColaVinculado, "en_analisis", {}, idReqVinculado);

    try {
      await navigator.clipboard.writeText(prompt);
      alert("Prompt copiado. Péguelo en Cursor.\n\nRecuerde:\n- HTML en cola/\n- SQL en activo/" + data.identificacion.idCaso + "/sql/");
    } catch {
      alert("Copie manualmente el preview.");
    }
  }

  window.refreshCorreoEstado = refreshCorreoEstado;
  window.QrysApp = { refreshMockupsForm, abrirMockupForm };

  try {
    init();
  } catch (err) {
    console.error(err);
    const msg = $("#bootSplashMsg");
    if (msg) {
      msg.innerHTML = `<strong style="color:#c0392b">Error al iniciar:</strong> ${String(err.message || err)}<br>Ejecute <strong>abrir-app.bat</strong> y recargue con Ctrl+F5.`;
    }
    const shell = $("#appShell");
    if (shell) shell.hidden = false;
    const box = document.createElement("div");
    box.className = "alert alert-warning";
    box.style.margin = "1rem";
    box.textContent = String(err.message || err);
    document.querySelector(".app-shell")?.prepend(box);
  }
})();
