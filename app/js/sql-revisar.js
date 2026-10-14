/**
 * Revisar SQL — archivo local o PREVERSION contra la última cerrada.
 */
window.QrysSqlRevisar = (function () {
  let rutaElegida = "";
  let idActual = "";
  let poll = null;

  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function inline(s) {
    return esc(s)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  }

  function textoChat(texto) {
    const lineas = String(texto || "").replace(/\r\n/g, "\n").split("\n");
    const html = [];
    let i = 0;
    const esTabla = (ln) => /^\s*\|/.test(ln);
    const esSep = (ln) => /^\s*\|?[\s:|-]+\|?\s*$/.test(ln) && /-/.test(ln);
    const esLista = (ln) => /^\s*(?:[-*]|\d+\.)\s+/.test(ln);
    const esTitulo = (ln) => /^(#{2,4})\s+\S/.test(ln);
    while (i < lineas.length) {
      const ln = lineas[i];
      if (!ln.trim()) {
        i += 1;
        continue;
      }
      if (esTabla(ln)) {
        const filas = [];
        while (i < lineas.length && esTabla(lineas[i])) {
          if (!esSep(lineas[i])) {
            const celdas = lineas[i].replace(/^\s*\|/, "").replace(/\|\s*$/, "").split("|").map((c) => c.trim());
            if (celdas.some(Boolean)) filas.push(celdas);
          }
          i += 1;
        }
        const datos = filas.length > 1 ? filas.slice(1) : filas;
        html.push(
          `<div class="sqlrev-tabla">${datos
            .map((c) => `<p><strong>${inline(c[0] || "")}</strong> ${inline(c.slice(1).join(" "))}</p>`)
            .join("")}</div>`
        );
        continue;
      }
      const titulo = ln.match(/^(#{2,4})\s+(.*)$/);
      if (titulo) {
        const tag = titulo[1].length <= 2 ? "h4" : "h5";
        html.push(`<${tag}>${inline(titulo[2])}</${tag}>`);
        i += 1;
        continue;
      }
      if (esLista(ln)) {
        const ordenada = /^\s*\d+\.\s+/.test(ln);
        const items = [];
        while (i < lineas.length && (esLista(lineas[i]) || /^\s{2,}\S/.test(lineas[i]))) {
          let item = lineas[i].replace(/^\s*(?:[-*]|\d+\.)\s+/, "").trim();
          i += 1;
          while (
            i < lineas.length &&
            lineas[i].trim() &&
            !esLista(lineas[i]) &&
            !esTitulo(lineas[i]) &&
            !esTabla(lineas[i]) &&
            /^\s{2,}\S/.test(lineas[i])
          ) {
            item += " " + lineas[i].trim();
            i += 1;
          }
          items.push(`<li>${inline(item)}</li>`);
        }
        const tag = ordenada ? "ol" : "ul";
        html.push(`<${tag}>${items.join("")}</${tag}>`);
        continue;
      }
      const par = [ln.trim()];
      i += 1;
      while (
        i < lineas.length &&
        lineas[i].trim() &&
        !esTitulo(lineas[i]) &&
        !esLista(lineas[i]) &&
        !esTabla(lineas[i])
      ) {
        par.push(lineas[i].trim());
        i += 1;
      }
      html.push(`<p>${inline(par.join(" "))}</p>`);
    }
    return `<div class="sqlrev-texto">${html.join("")}</div>`;
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok && data.error) throw new Error(data.error);
    if (!r.ok) throw new Error(r.statusText || String(r.status));
    return data;
  }

  function aviso(texto) {
    const el = document.getElementById("sqlrevAviso");
    if (el) el.textContent = texto || "";
  }

  function modo() {
    const marcado = document.querySelector('input[name="sqlrevModo"]:checked');
    return marcado ? marcado.value : "local";
  }

  function pintarModo() {
    const local = document.getElementById("sqlrevLocal");
    const cat = document.getElementById("sqlrevCatalogo");
    const esLocal = modo() === "local";
    if (local) local.hidden = !esLocal;
    if (cat) cat.hidden = esLocal;
  }

  function pintarArchivos(archivos) {
    const caja = document.getElementById("sqlrevArchivos");
    if (!caja) return;
    if (!archivos.length) {
      caja.innerHTML = `<p class="hint compact">No está en las carpetas de la oficina. Use Examinar para elegirlo en el equipo, o escriba Descargas\\archivo.sql.</p>`;
      return;
    }
    caja.innerHTML = archivos
      .map(
        (a) => `<button type="button" class="sqlrev-file${a.ruta === rutaElegida ? " is-on" : ""}" data-ruta="${esc(a.ruta)}">
          <strong>${esc(a.nombre)}</strong>
          <span class="hint compact">${esc(a.relativo)} · ${esc(a.bytes)} bytes</span>
        </button>`
      )
      .join("");
    caja.querySelectorAll(".sqlrev-file").forEach((btn) => {
      btn.addEventListener("click", () => {
        rutaElegida = btn.getAttribute("data-ruta") || "";
        pintarArchivos(archivos);
      });
    });
  }

  function examinar() {
    const input = document.getElementById("sqlrevArchivo");
    if (!input) return;
    input.value = "";
    input.click();
  }

  async function subirElegido(file) {
    if (!file) return;
    if (!String(file.name || "").toLowerCase().endsWith(".sql")) {
      aviso("Elija un archivo .sql.");
      return;
    }
    const btn = document.getElementById("btnSqlrevExaminar");
    if (btn) btn.disabled = true;
    aviso("Leyendo " + file.name + "…");
    try {
      const texto = await file.text();
      const data = await fetchJson("/api/sql-revisar/subir", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre: file.name, texto }),
      });
      rutaElegida = data.ruta || "";
      const campo = document.getElementById("sqlrevBuscar");
      if (campo) campo.value = file.name;
      pintarArchivos(data.ruta ? [data] : []);
      aviso("Archivo elegido. Pulse Revisar.");
    } catch (e) {
      aviso(e.message);
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function buscar() {
    const q = (document.getElementById("sqlrevBuscar")?.value || "").trim();
    aviso("Buscando…");
    try {
      const data = await fetchJson("/api/sql-revisar/buscar?q=" + encodeURIComponent(q));
      rutaElegida = data.archivos.length === 1 ? data.archivos[0].ruta : "";
      pintarArchivos(data.archivos || []);
      aviso(data.archivos.length ? "Elija el archivo y pulse Revisar." : "");
    } catch (e) {
      aviso(e.message);
    }
  }

  function diffHtml(texto) {
    if (!texto) return `<p class="hint compact">Sin diferencia de texto.</p>`;
    const lineas = texto.split("\n").map((ln) => {
      const safe = esc(ln);
      if (ln.startsWith("+")) return `<span style="color:#9ccc9c">${safe}</span>`;
      if (ln.startsWith("-")) return `<span style="color:#e08b8b">${safe}</span>`;
      return safe;
    });
    return `<pre class="sqlrev-diff">${lineas.join("\n")}</pre>`;
  }

  function pintarResultado(ficha) {
    const caja = document.getElementById("sqlrevResultado");
    const chat = document.getElementById("sqlrevChat");
    const msgs = document.getElementById("sqlrevMensajes");
    if (!caja) return;
    const est = ficha.estatica || {};
    const diff = ficha.diff || {};
    const vers = ficha.versiones || {};
    const det = ficha.detalle || {};
    const estructura = est.estructuraOk
      ? `<p>La estructura revisada cuadra.</p>`
      : `<ul>${(est.estructura || []).map((t) => `<li>${esc(t)}</li>`).join("")}</ul>`;
    const avisos = (est.avisos || [])
      .map((a) => `<li class="sqlrev-aviso">Línea ${esc(a.linea)}: ${esc(a.mensaje)}</li>`)
      .join("");
    const clases = Object.keys(det.clases || {})
      .map((k) => `${k} (${det.clases[k].n})`)
      .join(", ");
    caja.innerHTML = `
      <h3>${esc(ficha.objeto || ficha.id)}</h3>
      <p class="hint compact">${esc(ficha.id)} · ${esc((ficha.origen || {}).modo || "")}</p>
      <p><strong>PCEM.</strong> ${esc((ficha.prueba || {}).mensaje || "Sin prueba.")}</p>
      <p><strong>Catálogo.</strong> Última cerrada ${esc(vers.liberada || "—")}
        (anterior ${esc(vers.anterior || "—")}). ${esc(ficha.integridad || "")}.</p>
      <p><strong>SQLIXD.</strong> ${det.hay ? "Esta fila tiene detalle: " + esc(clases) + "." : "Esta fila no tiene original ni actualización guardados."}
        ${det.originalIgualLiberada ? " El ORIGINAL coincide con la instrucción de la cerrada." : ""}
        ${det.actualizacionIgualQuery ? " La ACTUALIZACION coincide con el QUERY de PREVERSION." : ""}</p>
      <h3>Estructura</h3>
      ${estructura}
      <h3>Avisos estáticos</h3>
      ${avisos ? `<ul>${avisos}</ul>` : `<p class="hint compact">Ninguno de los patrones revisados.</p>`}
      <h3>Diferencia</h3>
      <p class="hint compact">${diff.iguales ? "El texto comparado es el mismo." : esc(diff.agregadas) + " líneas agregadas, " + esc(diff.quitadas) + " quitadas."}</p>
      ${diffHtml(ficha.diffPreview)}
      ${ficha.detallePreview ? `<h3>Detalle del desarrollador (ORIGINAL → ACTUALIZACION)</h3>${diffHtml(ficha.detallePreview)}` : ""}
    `;
    if (chat) chat.hidden = false;
    if (msgs) {
      const lista = (ficha.chat && ficha.chat.mensajes) || [];
      msgs.innerHTML = lista.length
        ? lista
            .map((m) => {
              const quien = { agente: "Agente", coordinador: "Usted", sistema: "Sistema" }[m.autor] || m.autor;
              return `<article class="chat-msg chat-msg-${esc(m.autor)}"><div class="chat-msg-head"><strong>${esc(quien)}</strong></div><div class="sqlrev-msg-body">${textoChat(m.texto)}</div></article>`;
            })
            .join("")
        : `<p class="hint compact">Sin mensajes.</p>`;
      msgs.scrollTop = msgs.scrollHeight;
    }
  }

  async function cargarLista() {
    const caja = document.getElementById("sqlrevLista");
    if (!caja) return;
    try {
      const data = await fetchJson("/api/sql-revisar");
      const items = data.items || [];
      caja.innerHTML = items.length
        ? items
            .map(
              (it) => `<button type="button" class="sqlrev-item${it.id === idActual ? " is-on" : ""}" data-id="${esc(it.id)}">
                <strong>${esc(it.objeto || it.id)}</strong>
                <span class="hint compact">${esc(it.modo)} · ${esc(it.integridad)}</span>
              </button>`
            )
            .join("")
        : `<p class="hint compact">Aún no hay revisiones.</p>`;
      caja.querySelectorAll(".sqlrev-item").forEach((btn) => {
        btn.addEventListener("click", () => abrir(btn.getAttribute("data-id")));
      });
    } catch (e) {
      caja.innerHTML = `<p class="alert alert-warning">${esc(e.message)}</p>`;
    }
  }

  function estadoBot(bot) {
    const estado = (bot && (bot.estado || bot.error)) || "";
    return estado === "trabajando" || estado === "yaCorria" || bot?.ok === true && bot?.pid && !bot?.error;
  }

  async function abrir(id) {
    if (!id) return;
    idActual = id;
    aviso("");
    try {
      const data = await fetchJson("/api/sql-revisar/" + encodeURIComponent(id));
      pintarResultado(data);
      await cargarLista();
      vigilar(data.bot);
    } catch (e) {
      aviso(e.message);
    }
  }

  function vigilar(bot) {
    if (poll) {
      clearInterval(poll);
      poll = null;
    }
    const trabajando = bot && (bot.estado === "trabajando" || (bot.ok && bot.pid && !bot.terminadoEn && bot.estado !== "listo" && bot.estado !== "error"));
    if (!trabajando) return;
    aviso("El agente está revisando el cambio.");
    poll = setInterval(async () => {
      if (!idActual) return;
      try {
        const data = await fetchJson("/api/sql-revisar/" + encodeURIComponent(idActual));
        pintarResultado(data);
        const estado = (data.bot && data.bot.estado) || "";
        if (estado && estado !== "trabajando") {
          clearInterval(poll);
          poll = null;
          aviso(estado === "error" ? data.bot.error || "El agente no pudo terminar." : "El agente ya respondió.");
        }
      } catch (_) {}
    }, 3000);
  }

  async function revisar() {
    const body = modo() === "catalogo"
      ? { modo: "catalogo", nombre: (document.getElementById("sqlrevNombre")?.value || "").trim() }
      : { modo: "local", ruta: rutaElegida || (document.getElementById("sqlrevBuscar")?.value || "").trim() };
    if (body.modo === "catalogo" && !body.nombre) {
      aviso("Escriba el nombre del objeto.");
      return;
    }
    if (body.modo === "local" && !body.ruta) {
      aviso("Busque el archivo o escriba la ruta del .sql.");
      return;
    }
    aviso(body.modo === "catalogo"
      ? "Leyendo PREVERSION y la última cerrada. Después se compila en PCEM."
      : "Leyendo el archivo y el catálogo. Después se compila en PCEM.");
    const btn = document.getElementById("btnSqlrevRevisar");
    if (btn) btn.disabled = true;
    try {
      const data = await fetchJson("/api/sql-revisar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      idActual = data.id;
      pintarResultado(data);
      await cargarLista();
      if (data.bot && data.bot.ok === false) {
        aviso(data.bot.detalle || data.bot.error || "No se pudo lanzar el agente. La revisión estática sí quedó.");
      } else {
        aviso("El agente está revisando el cambio.");
        vigilar({ estado: "trabajando", ...(data.bot || {}) });
      }
    } catch (e) {
      aviso(e.message);
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  async function enviar() {
    const campo = document.getElementById("sqlrevChatInput");
    const texto = (campo?.value || "").trim();
    if (!idActual || !texto) return;
    aviso("Enviando…");
    try {
      const data = await fetchJson("/api/sql-revisar/" + encodeURIComponent(idActual) + "/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ texto }),
      });
      if (campo) campo.value = "";
      pintarResultado(data.revision || data);
      vigilar({ estado: "trabajando" });
      aviso("El agente está respondiendo.");
    } catch (e) {
      aviso(e.message);
    }
  }

  function enter() {
    pintarModo();
    cargarLista();
    if (idActual) abrir(idActual);
  }

  function bind() {
    if (document.body.dataset.sqlrevBound) return;
    document.body.dataset.sqlrevBound = "1";
    document.querySelectorAll('input[name="sqlrevModo"]').forEach((el) => {
      el.addEventListener("change", pintarModo);
    });
    document.getElementById("btnSqlrevBuscar")?.addEventListener("click", buscar);
    document.getElementById("btnSqlrevExaminar")?.addEventListener("click", examinar);
    document.getElementById("sqlrevArchivo")?.addEventListener("change", (e) => {
      subirElegido(e.target.files && e.target.files[0]);
    });
    document.getElementById("btnSqlrevRevisar")?.addEventListener("click", revisar);
    document.getElementById("btnSqlrevEnviar")?.addEventListener("click", enviar);
    document.getElementById("sqlrevBuscar")?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") buscar();
    });
  }

  bind();
  return { enter };
})();
