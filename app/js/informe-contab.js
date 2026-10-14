/**
 * Informe errores contables + DIAN — soporte (read-only SQL).
 */
window.QrysInformeContab = (function () {
  const $ = (id) => document.getElementById(id);
  let sesionId = null;
  let bound = false;

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
    const el = $("icAviso");
    if (!el) return;
    el.hidden = !texto;
    el.textContent = texto || "";
    el.className = esError ? "alert alert-warning" : "alert";
  }

  function pintarChat(mensajes) {
    const box = $("icChatMensajes");
    if (!box) return;
    const list = mensajes || [];
    if (!list.length) {
      box.innerHTML = '<p class="hint">Sin mensajes. Anote ajustes pedidos al agente o observaciones de soporte.</p>';
      return;
    }
    box.innerHTML = list
      .map(
        (m) =>
          `<article class="chat-msg chat-msg-${esc(m.autor || "coordinador")}"><header><strong>${esc(
            m.autor || "?"
          )}</strong> <span class="hint compact">${esc(m.en || m.fecha || "")}</span></header><div class="chat-body">${esc(
            m.texto || ""
          ).replace(/\n/g, "<br>")}</div></article>`
      )
      .join("");
    box.scrollTop = box.scrollHeight;
  }

  let servidoresCache = [];
  let institucionManual = false;

  function basesDelServidor(s) {
    const bases = (s && s.bases) || [];
    if (bases.length) return bases;
    if (s && s.baseDatosDefault) return [s.baseDatosDefault];
    return [];
  }

  function pintarOpcionesBases(bases, preferida) {
    const sel = $("icBaseDatos");
    if (!sel) return;
    const lista = [...new Set((bases || []).map((b) => String(b).trim()).filter(Boolean))].sort(
      (a, b) => a.localeCompare(b, "es")
    );
    sel.innerHTML = "";
    if (!lista.length) {
      const opt = document.createElement("option");
      opt.value = "";
      opt.textContent = "(Sin bases — escriba abajo o Actualizar desde SQL)";
      sel.appendChild(opt);
      return;
    }
    lista.forEach((b) => {
      const opt = document.createElement("option");
      opt.value = b;
      opt.textContent = b;
      sel.appendChild(opt);
    });
    const pref = (preferida || "").trim();
    if (pref && lista.includes(pref)) sel.value = pref;
    else if (lista.length === 1) sel.value = lista[0];
  }

  function pintarBasesCatalogo(servidorId) {
    const s = servidoresCache.find((x) => x.id === servidorId);
    pintarOpcionesBases(basesDelServidor(s), s?.baseDatosDefault || "");
  }

  function basesPreferidaServidor(servidorId) {
    const s = servidoresCache.find((x) => x.id === servidorId);
    return (s && s.baseDatosDefault) || (basesDelServidor(s)[0] || "");
  }

  async function cargarBasesDesdeSql(servidorId, silencioso) {
    const sel = $("icBaseDatos");
    const btn = $("icBtnListarBases");
    if (!servidorId || !sel) return;
    if (btn) btn.disabled = true;
    const prev = sel.value;
    sel.innerHTML = "";
    const loading = document.createElement("option");
    loading.value = "";
    loading.textContent = "Consultando sys.databases…";
    sel.appendChild(loading);
    if (!silencioso) aviso("Listando bases de datos en el servidor…");
    try {
      const url = `/api/informe-contab/bases?servidorId=${encodeURIComponent(servidorId)}`;
      const data = await fetchJson(url);
      const bases = data.bases || [];
      const pref = basesPreferidaServidor(servidorId);
      pintarOpcionesBases(bases, pref);
      if (prev && [...sel.options].some((o) => o.value === prev)) sel.value = prev;
      if (!silencioso) aviso(bases.length ? `${bases.length} base(s) en el servidor.` : "No se encontraron bases (use el campo manual).");
    } catch (e) {
      pintarBasesCatalogo(servidorId);
      if (!silencioso) {
        aviso(
          (e.message || String(e)) + " — Se muestran las bases del catálogo local.",
          true
        );
      }
    } finally {
      if (btn) btn.disabled = false;
      cargarClinica();
    }
  }

  function baseElegida() {
    const otra = ($("icBaseDatosOtra")?.value || "").trim();
    if (otra) return otra;
    return ($("icBaseDatos")?.value || "").trim();
  }

  async function cargarServidores() {
    const sel = $("icServidor");
    if (!sel) return;
    const data = await fetchJson("/api/informe-contab/servidores");
    servidoresCache = data.servidores || [];
    sel.innerHTML = "";
    servidoresCache.forEach((s) => {
      const opt = document.createElement("option");
      opt.value = s.id || s.nombre;
      opt.textContent = s.nombre || s.id;
      sel.appendChild(opt);
    });
    sel.onchange = () => cargarBasesDesdeSql(sel.value, true);
    const baseSel = $("icBaseDatos");
    if (baseSel) baseSel.onchange = () => cargarClinica();
    const baseOtra = $("icBaseDatosOtra");
    if (baseOtra) baseOtra.onchange = () => cargarClinica();
    $("icBtnListarBases")?.addEventListener("click", () => {
      const sid = ($("icServidor")?.value || "").trim();
      if (!sid) {
        aviso("Elija un servidor.", true);
        return;
      }
      cargarBasesDesdeSql(sid, false);
    });
    if (servidoresCache.length) cargarBasesDesdeSql(sel.value, true);
  }

  async function cargarClinica() {
    const servidorId = ($("icServidor")?.value || "").trim();
    const database = baseElegida();
    const campo = $("icInstitucion");
    if (!servidorId || !database || !campo) return;
    if (institucionManual && (campo.value || "").trim()) return;
    try {
      const url =
        `/api/informe-contab/clinica?servidorId=${encodeURIComponent(servidorId)}` +
        `&database=${encodeURIComponent(database)}`;
      const data = await fetchJson(url);
      if (data.razonSocial) {
        campo.value = data.razonSocial;
        institucionManual = false;
      }
    } catch (_) {
      /* opcional: sin bloquear el flujo */
    }
  }

  async function cargarSesiones() {
    const tb = $("icSesionesBody");
    if (!tb) return;
    const data = await fetchJson("/api/informe-contab/sesiones");
    const rows = data.sesiones || [];
    if (!rows.length) {
      tb.innerHTML = '<tr><td colspan="5">Sin análisis previos</td></tr>';
      return;
    }
    tb.innerHTML = rows
      .map(
        (s) => `<tr data-sid="${esc(s.id)}">
          <td>${esc(s.id)}</td>
          <td>${esc(s.institucion || "—")}</td>
          <td>${esc(s.database)}</td>
          <td>${esc(s.generado || "—")}</td>
          <td><button type="button" class="btn btn-secondary btn-sm" data-abrir>Abrir</button></td>
        </tr>`
      )
      .join("");
    tb.querySelectorAll("[data-abrir]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const tr = btn.closest("tr");
        abrirSesion(tr?.getAttribute("data-sid"));
      });
    });
  }

  function pintarMeta(meta) {
    const el = $("icMetaResumen");
    if (!el || !meta) return;
    el.innerHTML = `<p class="hint compact">Sesión <code>${esc(meta.id)}</code> · ${esc(meta.institucion || meta.database)} · 
      ${meta.generado ? `Generado ${esc(meta.generado)}` : "Pendiente de generar"} · 
      ${meta.comprobantes_errados != null ? `<strong>${esc(meta.comprobantes_errados)}</strong> comprobantes errados` : ""}
      ${meta.periodo_trabajo ? ` · Periodo ${esc(meta.periodo_trabajo)}` : ""}</p>`;
    const dl = $("icBtnDescargar");
    const ver = $("icBtnVer");
    const imp = $("icBtnImprimir");
    const ok = meta.estado === "generado";
    if (dl) dl.disabled = !ok;
    if (ver) ver.disabled = !ok;
    if (imp) imp.disabled = !ok;
  }

  async function abrirSesion(sid) {
    if (!sid) return;
    sesionId = sid;
    aviso("");
    const meta = await fetchJson(`/api/informe-contab/${encodeURIComponent(sid)}/meta`);
    pintarMeta(meta.meta);
    const chat = await fetchJson(`/api/informe-contab/${encodeURIComponent(sid)}/chat`);
    pintarChat(chat.mensajes);
    $("icPanelTrabajo")?.removeAttribute("hidden");
  }

  async function nuevaSesion() {
    const servidorId = ($("icServidor")?.value || "").trim();
    const database = baseElegida();
    const institucion = ($("icInstitucion")?.value || "").trim();
    if (!servidorId || !database) {
      aviso("Indique servidor y base de datos.", true);
      return;
    }
    aviso("Creando sesión…");
    const data = await fetchJson("/api/informe-contab/sesion", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ servidorId, database, institucion }),
    });
    await cargarSesiones();
    await abrirSesion(data.meta.id);
    aviso("Sesión lista. Pulse «Generar análisis».");
  }

  async function generar() {
    if (!sesionId) {
      aviso("Cree o abra una sesión primero.", true);
      return;
    }
    aviso("Consultando base de datos (puede tardar 1–2 min)…");
    $("icBtnGenerar") && ($("icBtnGenerar").disabled = true);
    try {
      const data = await fetchJson(`/api/informe-contab/${encodeURIComponent(sesionId)}/generar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      pintarMeta(data.meta);
      await cargarSesiones();
      aviso("Informe generado. Puede verlo o descargarlo.");
    } catch (e) {
      aviso(e.message || String(e), true);
    } finally {
      $("icBtnGenerar") && ($("icBtnGenerar").disabled = false);
    }
  }

  async function enviarChat() {
    if (!sesionId) return;
    const input = $("icChatInput");
    const texto = (input?.value || "").trim();
    if (!texto) return;
    const data = await fetchJson(`/api/informe-contab/${encodeURIComponent(sesionId)}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ texto, autor: "coordinador" }),
    });
    if (input) input.value = "";
    pintarChat(data.mensajes);
  }

  function urlInforme(descargar) {
    if (!sesionId) return "#";
    const u = `/api/informe-contab/${encodeURIComponent(sesionId)}/html`;
    return descargar ? u + "?dl=1" : u;
  }

  async function descargarPdf() {
    if (!sesionId) return;
    const btn = $("icBtnImprimir");
    if (btn) btn.disabled = true;
    aviso("Generando PDF (Chrome headless, sin encabezados del navegador)…");
    try {
      const r = await fetch(`/api/informe-contab/${encodeURIComponent(sesionId)}/pdf`, {
        method: "POST",
      });
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
      const nombre = m ? m[1] : `informe-contab-${sesionId}.pdf`;
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = nombre;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      aviso("PDF descargado.");
    } catch (e) {
      aviso(e.message || String(e), true);
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function bindOnce() {
    if (bound) return;
    bound = true;
    $("icInstitucion")?.addEventListener("input", () => {
      institucionManual = true;
    });
    $("icBtnNuevaSesion")?.addEventListener("click", () => nuevaSesion().catch((e) => aviso(e.message, true)));
    $("icBtnGenerar")?.addEventListener("click", () => generar());
    $("icBtnImprimir")?.addEventListener("click", () => descargarPdf());
    $("icBtnVer")?.addEventListener("click", () => {
      if (sesionId) window.open(urlInforme(false), "_blank", "noopener");
    });
    $("icBtnDescargar")?.addEventListener("click", () => {
      if (!sesionId) return;
      const a = document.createElement("a");
      a.href = urlInforme(true);
      a.download = `informe-contab-${sesionId}.html`;
      a.target = "_blank";
      a.rel = "noopener";
      document.body.appendChild(a);
      a.click();
      a.remove();
    });
    $("icBtnChatEnviar")?.addEventListener("click", () => enviarChat().catch((e) => aviso(e.message, true)));
    $("icChatInput")?.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" && !ev.shiftKey) {
        ev.preventDefault();
        enviarChat().catch((e) => aviso(e.message, true));
      }
    });
  }

  async function enter() {
    bindOnce();
    aviso("");
    sesionId = null;
    institucionManual = false;
    if ($("icInstitucion")) $("icInstitucion").value = "";
    $("icPanelTrabajo")?.setAttribute("hidden", "");
    try {
      await cargarServidores();
      await cargarSesiones();
    } catch (e) {
      aviso(e.message || String(e), true);
    }
  }

  return { enter, bindOnce };
})();
