/**
 * Qrys.Quatec — App principal
 */
(function () {
  const STORAGE_KEY = "qrys_quatec_solicitud";
  const PATH_SQL = "C:\\DevQuasar\\Qrystalos\\Qrys.Quatec\\sql\\";
  const PATH_SQL_REFE = "C:\\DevQuasar\\Qrystalos\\Qrys.Quatec\\sql_refe\\";

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
  let syncingCorreo = false;

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
    refreshCorreoEstado();
    const idAlCargar = val("#idCaso");
    if (idAlCargar) cargarSolicitudCaso(idAlCargar);
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

  function bindMainTabs() {
    $$(".main-tab").forEach((tab) => {
      tab.addEventListener("click", () => {
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
      { filtroReq: val("#filtroColaReq") },
    );
  }

  function switchToView(viewName) {
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
    $("#chatInput").addEventListener("keydown", (e) => {
      if (e.key !== "Enter") return;
      if (e.altKey) {
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
        "El dictamen se aprueba, se copia a aprobados/, los .sql pasan a sql_refe/{ID-REQ}/ " +
        "y se envía el correo al desarrollador.",
    )) return;

    const dest = await resolverCorreoDestino();
    if (!dest) {
      return alert("No se cierra Fase 1 sin correo del desarrollador. Indíquelo en la tarjeta Correo o en la lista de desarrolladores.");
    }

    const cierre = await QrysChat.cerrarFase1(idCaso, { correo: dest });
    if (!cierre || (cierre.ok === false && !cierre.estado)) {
      return alert(cierre?.error || "No se pudo cerrar Fase 1.");
    }
    const mail = cierre?.correo || {};
    if (mail.ok && !mail.borrador) {
      aplicarResultadoCorreoEnviado(idCaso, mail);
    } else if (archivoColaVinculado) {
      QrysCola.updateEstado(archivoColaVinculado, "aprobado", {}, idReqVinculado);
    }
    refreshColaTable();
    refreshChatView(idCaso);

    const sqlInfo = cierre?.sql || {};
    const movidos = sqlInfo.movidos || [];
    if (movidos.length) {
      sqlChecklistState = null;
      if ($("#objetosSolicitados")) $("#objetosSolicitados").value = "";
      if ($("#listaArchivosSql")) {
        $("#listaArchivosSql").innerHTML = "<li class='hint'>Carpeta sql/ limpia — listo para el siguiente caso</li>";
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
      : "• (no había .sql en sql/)";
    const lineaMail = mail.ok && !mail.borrador
      ? `Correo: enviado a ${mail.destinatario || dest}`
      : `Correo: NO enviado. ${mail.error || "Use Enviar correo."}`;
    alert(
      `Fase 1 cerrada.\n\nDictamen: ${destHtml}\nSQL: ${destSql}\n${listaSql}\n${lineaMail}`,
    );
    if (!mail.ok && mail.error && confirm(`${mail.error}\n\n¿Abrir un borrador en Outlook?`)) {
      accionarCorreo({ display: true });
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
      if (dest) {
        setVal("#correoDestino", dest);
        if (val("#desarrollador") && window.QrysDesarrolladores) {
          try { await QrysDesarrolladores.setCorreo(val("#desarrollador"), dest); } catch { /* */ }
        }
      }
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
    if (archivoColaVinculado) {
      QrysCola.updateEstado(archivoColaVinculado, "enviado", {}, val("#idReq") || idReqVinculado);
    }
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

  async function checkServerHealth() {
    if (location.protocol === "file:") return;
    try {
      const resp = await fetch("/api/health");
      const data = await parseJsonResponse(resp);
      if (!data.features?.includes("caso") || !data.features?.includes("chatSinOpenAI")) {
        $("#alertFileProtocol")?.remove();
        const el = document.createElement("div");
        el.id = "alertServerOld";
        el.className = "alert alert-warning";
        el.innerHTML =
          "<strong>Servidor viejo.</strong> Cierre la ventana negra y ejecute <code>abrir-app.bat</code>.";
        $(".app-header")?.prepend(el);
      }
    } catch {
      /* servidor no responde health — activarAnalisis mostrará el error concreto */
    }
  }

  async function activarAnalisis() {
    if (!isFormComplete()) return alert("Complete el formulario y el paso SQL (métodos documentados o .sql en sql/).");

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

      alert(
        "Fase 1 activada.\n\n" +
          "El agente en Cursor lee activo/" +
          idCaso +
          "/ (Qrystalos2, conocimiento/ y sql/ si aplica).\n" +
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
    $("#colaUpload").addEventListener("change", (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        const canonical = QrysCola.normalizeFileName(file.name);
        const parseResult = QrysCola.parseHtmlAvalasesor(reader.result, canonical);
        guardarHtmlEnCola(canonical, reader.result);
        procesarRegistroCola(canonical, reader.result, parseResult, file.name);
      };
      reader.readAsText(file, "UTF-8");
      e.target.value = "";
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
    $("#filtroColaReq")?.addEventListener("input", () => refreshColaTable());
    $("#btnLimpiarFiltroCola")?.addEventListener("click", () => {
      setVal("#filtroColaReq", "");
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
      refreshColaTable();
      updateCorruptAlert();

      if (!bulk.registrados.length) {
        return alert(
          `Sin REQ nuevos. Se actualizaron los datos de ${bulk.omitidos.length} REQ ya en cola (proyecto, módulo, rama…).\n\n` +
            bulk.omitidos.map((r) => r.idReq).join(", "),
        );
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
    refreshColaTable();
    updateCorruptAlert();
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

  async function cargarSolicitudCaso(idCaso) {
    if (location.protocol === "file:" || !idCaso) return false;
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
      });
      if (data.fase1Cerrada && sol.sql) {
        if ($("#chkSqlColocados")) $("#chkSqlColocados").checked = true;
      }
      if (sol.sql?.archivosEsperados?.length && !sqlChecklistState) {
        renderListaSqlNombres();
      }
      updateSqlPath();
      saveToStorage();
      updateAll();
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
    renderBrechaAnalisis(null);
    const hintBrecha = $("#brechaAnalisisHint");
    if (hintBrecha) hintBrecha.textContent = "El agente (Cursor) contrasta el REQ con su análisis y lista qué le falta revisar. No usa OpenAI.";
    $("#alertOrigenCola").hidden = true;
    $("#archivoColaVinculado").textContent = "—";
    if ($("#chkSqlColocados")) $("#chkSqlColocados").checked = false;
    if ($("#chkUsarDocSp")) $("#chkUsarDocSp").checked = false;
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
    $("#btnGuardarJson").addEventListener("click", downloadJson);
    const btnZip = $("#btnDescargarZip");
    if (btnZip) btnZip.addEventListener("click", downloadZip);
    $("#btnActivarAnalisis").addEventListener("click", () => activarAnalisis());
    const btnCopiar = $("#btnCopiarPrompt");
    if (btnCopiar) btnCopiar.addEventListener("click", copyPrompt);
    $("#btnArchivarSql").addEventListener("click", () => archivarSql());
    $("#chkSqlColocados").addEventListener("change", updateAll);
    $("#idReq").addEventListener("input", updateSqlPath);
    bindCorreoDev();
    bindCriterios();
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
    if (hint) {
      if (c.enviado) {
        const extra = c.reenvios ? ` · ${c.reenvios} reenvío(s)` : "";
        const copia = ultima?.carpeta ? ` · copia ${ultima.carpeta}` : "";
        hint.textContent = `Enviado el ${c.fechaEnvio || "—"}${extra}${copia}.`;
      } else if (c.tieneDictamen === false) {
        hint.textContent = "Aún no hay dictamen HTML para adjuntar.";
      } else {
        hint.textContent = "Aún no se ha enviado el dictamen.";
      }
    }
    if (card) {
      card.classList.toggle("correo-ok", !!c.enviado);
      card.classList.toggle("correo-pendiente", !c.enviado);
    }
    syncingCorreo = false;
  }

  async function refreshCorreoEstado() {
    const idCaso = val("#idCaso");
    if (!window.QrysDesarrolladores || !idCaso) {
      applyCorreoUI(collectCorreo());
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
        applyCorreoUI({ ...collectCorreo(), destinatario: val("#correoDestino") });
        return;
      }
      if (!st.destinatario && val("#desarrollador")) {
        const lista = await QrysDesarrolladores.listar();
        st.destinatario = QrysDesarrolladores.correoDeLista(lista, val("#desarrollador"));
      }
      applyCorreoUI(st);
    } catch {
      applyCorreoUI(collectCorreo());
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
    if (enviado && archivoColaVinculado) {
      QrysCola.updateEstado(archivoColaVinculado, "enviado", {}, val("#idReq") || idReqVinculado);
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
      if (val("#desarrollador") && window.QrysDesarrolladores) {
        try { await QrysDesarrolladores.setCorreo(val("#desarrollador"), dest); } catch { /* */ }
      }
    }
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
      aplicarResultadoCorreoEnviado(idCaso, r);
      alert(r.mensaje || "Correo enviado.");
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
      const nombre = val("#desarrollador");
      const mail = val("#correoDestino");
      if (nombre && mail && window.QrysDesarrolladores) {
        try { await QrysDesarrolladores.setCorreo(nombre, mail); } catch { /* */ }
      }
      persistMarcarCorreo();
    });
    $("#desarrollador")?.addEventListener("change", () => refreshCorreoEstado());
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
    box.innerHTML = `<strong>Qué me falta analizar (para validar el suyo)</strong>${cuando}<pre class="criterios-sugerencia-texto">${esc(dato.texto)}</pre>`;
  }

  async function pollBrechaAnalisis(idCaso) {
    const hint = $("#brechaAnalisisHint");
    for (let i = 0; i < 40; i++) {
      await new Promise((r) => setTimeout(r, 4000));
      try {
        const resp = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/solicitud`, { cache: "no-store" });
        const data = await resp.json();
        const brecha = data.solicitud?.contenido?.brechaAnalisis;
        if (brecha && brecha.texto) {
          brechaAnalisis = brecha;
          renderBrechaAnalisis(brecha);
          if (hint) hint.textContent = "Listo. El mismo texto quedó en el Chat.";
          return;
        }
        const est = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/estado?t=${Date.now()}`, { cache: "no-store" });
        const estado = await est.json();
        const bot = estado.bot || {};
        if (bot.estado === "error" || bot.estado === "sin_clave") {
          if (hint) hint.textContent = bot.error || "El agente no pudo terminar. Revise el Chat.";
          return;
        }
        if (bot.estado === "listo" || bot.estado === "terminado") {
          const chat = await fetch(`/api/caso/${encodeURIComponent(idCaso)}/chat?t=${Date.now()}`, { cache: "no-store" });
          const cj = await chat.json();
          const msgs = (cj.mensajes || []).filter((m) => m.autor === "agente");
          const last = msgs[msgs.length - 1];
          if (last && last.texto) {
            brechaAnalisis = { texto: last.texto, fecha: last.fecha, estado: "listo" };
            renderBrechaAnalisis(brechaAnalisis);
            if (hint) hint.textContent = "Listo. El mismo texto quedó en el Chat.";
            return;
          }
        }
      } catch {
        /* reintento */
      }
    }
    if (hint) hint.textContent = "Sigue en el Chat si aquí no aparece. Recargue si hace falta.";
  }

  async function analizarRequerimiento() {
    const req = val("#requerimiento");
    const cola = val("#colaArchivoManual") || archivoColaVinculado;
    if (!req && !cola) return alert("Escriba el requerimiento o registre la cola primero.");
    const idCaso = val("#idCaso");
    if (!idCaso) return alert("Indique ID caso (paso 1). Hace falta para que el agente deje el resultado.");
    if (location.protocol === "file:") {
      return alert("Ejecute abrir-app.bat y abra http://localhost:8765/app/");
    }
    saveToStorage();
    const hint = $("#brechaAnalisisHint");
    const btn = $("#btnAnalizarRequerimiento");
    if (btn) btn.disabled = true;
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
      if (hint) hint.textContent = "El agente está contrastando el REQ con su análisis. Espere…";
      pollBrechaAnalisis(idCaso);
    } catch (e) {
      if (hint) hint.textContent = e.message || "Error al analizar";
      alert(e.message || "No se pudo analizar el requerimiento.");
    } finally {
      if (btn) btn.disabled = false;
    }
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

  function bindCriterios() {
    $("#btnSugerirCriterios")?.addEventListener("click", () => sugerirCriterios(false));
    $("#btnRefinarCriterios")?.addEventListener("click", () => sugerirCriterios(true));
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
    captureCriteriosOriginales();
    saveToStorage();
    const btn = $("#btnSugerirCriterios");
    const btnRefinar = $("#btnRefinarCriterios");
    const hintOai = $("#openaiEstadoHint");
    if (btn) btn.disabled = true;
    if (btnRefinar) btnRefinar.disabled = true;
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
      if (hintOai) hintOai.textContent = "El agente está proponiendo criterios. Abra el Chat y recargue el formulario al terminar.";
      if (usarAnalisis) {
        const hint = $("#criteriosRefineHint");
        if (hint) hint.textContent = "El agente actualiza los criterios en el Chat y en este formulario.";
      }
      abrirChatCaso(idCaso);
    } catch (e) {
      if (hintOai) hintOai.textContent = e.message || "Error al pedir criterios";
      alert(e.message || "No se pudieron pedir los criterios al agente.");
    } finally {
      if (btn) btn.disabled = false;
      if (btnRefinar) btnRefinar.disabled = false;
    }
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
    return { procesoId: "", sps: [], seleccion: {}, nota: "", actualizado: "" };
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
        sps = proc.sps || [];
        nota = proc.spsNota || "";
        actualizado = proc.spsActualizado || proc.actualizado || "";
      } catch (_) {
        const cat = await fetchJsonKb(`/conocimiento/${encodeURIComponent(procesoId)}/sps.json`);
        sps = cat.sps || [];
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
          ? `${nMet} método(s) · ${actualizado || "sin fecha"}`
          : "Sin métodos documentados — use sql/";
      }
      if (!nMet && !silent) {
        alert("Este proceso aún no tiene métodos en sps.json. Coloque el .sql en sql/.");
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
    let visibles = 0;
    let total = 0;
    box.innerHTML = sps.map((sp) => {
      const metodos = sp.metodos || [];
      if (!metodos.length) return "";
      const rows = metodos.map((m) => {
        const id = m.id || m.nombre || "";
        if (!id) return "";
        total += 1;
        const key = metodoKbKey(sp.nombre, id);
        const seleccionado = !!metodosKbState.seleccion[key];
        const blob = `${sp.nombre} ${id} ${m.hace || ""}`.toLowerCase();
        const match = !filtro || blob.includes(filtro) || seleccionado;
        if (!match) return "";
        visibles += 1;
        const checked = seleccionado ? "checked" : "";
        const est = (m.estado || sp.estado || "no_leido").replace(/\s+/g, "_");
        const hace = m.hace ? `<span class="hace">${esc(m.hace)}</span>` : "";
        return `<label class="sql-kb-metodo">
          <input type="checkbox" data-sp="${esc(sp.nombre)}" data-metodo="${esc(id)}" ${checked}>
          <span>
            <span class="kb-id">${esc(id)}</span>
            <span class="sql-kb-badge ${esc(est)}">${esc(est.replace(/_/g, " "))}</span>
            ${hace}
          </span>
        </label>`;
      }).join("");
      if (!rows.trim()) return "";
      return `<div class="sql-kb-sp">${esc(sp.nombre)}</div>${rows}`;
    }).join("");

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
      estadoEl.textContent = filtro
        ? `${visibles} de ${total} método(s)`
        : `${total} método(s) · ${metodosKbState.actualizado || "sin fecha"}`;
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
      ? `<ul>${archivos.map((a) => `<li><code>${esc(PATH_SQL)}${esc(a)}</code></li>`).join("")}</ul>`
      : "<p class=\"hint\">No hay .sql en la carpeta de hoy (el Chat los pedirá si hace falta releer).</p>";
    return `<h4>Dónde queda para el Chat</h4>
      <p><strong>Catálogo (fichas):</strong> <code>${esc(catalogo)}</code></p>
      <p><strong>Métodos de este REQ</strong> (también en <code>activo/${esc(idCaso)}/solicitud.json</code> → <code>sql.metodosDocumentados</code>):</p>
      ${filasMet}
      <p><strong>SQL de hoy</strong> (si hay que releer o no está documentado): <code>${esc(PATH_SQL)}</code></p>
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
      if (location.protocol === "file:") {
        const local = window.QRYS_SQL_MANIFEST?.archivos || [];
        if (!local.length) {
          showErr("Ejecute abrir-app.bat y abra http://localhost:8765/app/ para leer sql/.");
          return false;
        }
        applySqlFromDirectory(local, "manifest-local");
        ok(`Leído de sql/ · ${local.length} .sql (lista embebida)`);
        return true;
      }

      const resp = await fetch(`/api/sql?t=${Date.now()}`);
      const data = await parseJsonResponse(resp);
      const archivos = Array.isArray(data.archivos) ? data.archivos : [];

      if (!archivos.length) {
        sqlChecklistState = null;
        renderListaSqlNombres();
        ok("sql/ no tiene .sql. Coloque los scripts y pulse Leer de nuevo.");
        if (errBox) {
          errBox.textContent = "Carpeta sql/ vacía. No se usó la lista del requerimiento anterior.";
          errBox.classList.remove("hidden");
        }
        return false;
      }

      applySqlFromDirectory(archivos, "api");
      ok(`Leído de sql/ · ${archivos.length} .sql`);
      return true;
    } catch (e) {
      showErr(e.message || "No se pudo leer sql/. ¿Está ejecutando abrir-app.bat?");
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
    setText("#pathSqlCaso", PATH_SQL);
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
          `O use: scripts\\archivar-sql.ps1 -IdReq ${idReq} -IdCaso ${idCaso || '""'}`,
      );
    }

    const archivos = getSqlArchivosSeleccionados();
    const msg =
      `¿Archivar ${archivos.length || "los"} SQL del caso y limpiar la carpeta de trabajo?\n\n` +
      `Destino: sql_refe/${idReq}/\n` +
      `Origen: sql/\n\n` +
      "Use esto cuando el dictamen esté aprobado.";

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
      $("#listaArchivosSql").innerHTML = "<li class='hint'>Carpeta sql/ limpia — listo para el siguiente caso</li>";
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
    for (let s = 1; s <= 4; s++) if (!validateStep(s, false)) return false;
    return sqlPasoListoParaActivar();
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
        impactoFe: val("#impactoFe"),
        impactoApi: val("#impactoApi"),
        impactoSql: val("#impactoSql"),
        contabilidad: collectContabilidad(),
        validarAntes: collectValidarAntes(),
        imagenesNecesarias: val("#imagenesNecesarias"),
        criteriosMeta,
        brechaAnalisis,
      },
      sql: {
        carpetaFija: PATH_SQL,
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
    return `# Solicitud dictamen — Qrys.Quatec

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

## Imágenes
${d.contenido.imagenesNecesarias || "El agente pedirá capturas si las necesita → aprobados/.../imagenes/"}

Generar: dictamenes/${d.identificacion.idCaso}.html
Al aprobar: copiar a aprobados/${d.identificacion.idCaso}/
`;
  }

  function updateAll() {
    updateSqlPasoHint();
    actualizarAvisoReleerKb();
    renderSqlResumenCaso();
    const complete = isFormComplete();
    const data = collectData();
    $("#previewPrompt").textContent = buildPrompt(data);
    const btnActivar = $("#btnActivarAnalisis");
    if (btnActivar) btnActivar.disabled = !complete;
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

    const issues = [];
    for (let s = 1; s <= 3; s++) {
      getRequiredForStep(s).forEach(({ el, label }) => {
        if (!el?.value?.trim()) issues.push(label);
      });
    }
    if (!archivoColaVinculado && !val("#requerimiento")) issues.push("Cola HTML o requerimiento");
    if (!sqlPasoListoParaActivar()) {
      issues.push("SQL: solo al Activar fase 1 (después del análisis, o si soporte/director confirma el SP)");
    }

    $("#validacionResumen").innerHTML = issues.length
      ? `<p class="fail"><strong>Pendiente:</strong></p><ul>${[...new Set(issues)].map((i) => `<li>${i}</li>`).join("")}</ul>`
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
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      applyStorageData(JSON.parse(raw));
    } catch (e) {
      console.warn(e);
    }
  }

  function applyStorageData(data) {
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
      set("#imagenesNecesarias", data.contenido?.imagenesNecesarias);
      set("#objetosSolicitados", data.sql?.archivosEsperados?.join("\n"));
      set("#notasSql", data.sql?.notas);
      if (data.sql?.confirmadoEnCarpeta) $("#chkSqlColocados").checked = true;
      restaurarMetodosKb(data.sql);
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
    if (!isFormComplete()) return alert("Complete el formulario y confirme SQL en carpeta fija.");
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
      alert("Prompt copiado. Péguelo en Cursor.\n\nRecuerde:\n- HTML en cola/\n- SQL en sql/" + data.identificacion.idCaso + "/");
    } catch {
      alert("Copie manualmente el preview.");
    }
  }

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
