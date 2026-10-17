/**
 * Panel de agentes — local (Ollama) o Cursor.
 */
window.QrysAgentes = (function () {
  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  async function fetchJson(url, opts) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    const data = await r.json().catch(() => ({}));
    if (!r.ok && data.error) throw new Error(data.error);
    if (!r.ok) throw new Error(r.statusText || String(r.status));
    return data;
  }

  let claves = [];

  function aviso(texto) {
    const el = document.getElementById("agentesAviso");
    if (el) el.textContent = texto || "";
  }

  function textoClave(clave) {
    const nombre = clave.nombre ? clave.nombre + " · " : "";
    const marca = clave.activa ? " · predeterminada" : "";
    return nombre + clave.etiqueta + " …" + (clave.sufijo || "") + marca;
  }

  function motoresHtml(id, motorActual, motores) {
    return ["local", "cursor"].map((motor) => {
      const permitido = (motores || ["cursor"]).includes(motor);
      const marcado = motorActual === motor ? "checked" : "";
      const etiqueta = motor === "local" ? "Local" : "Cursor";
      const extra = permitido ? "" : " title=\"Este paso lo arma la oficina\"";
      return `<label class="${permitido ? "" : "is-off"}">
        <input type="radio" name="motor-${esc(id)}" value="${motor}" ${marcado} ${permitido ? "" : "disabled"}${extra}>
        ${etiqueta}${permitido ? "" : " · oficina"}
      </label>`;
    }).join("");
  }

  function subtarjeta(sub) {
    return `<article class="agente-sub" data-agente="${esc(sub.id)}">
      <h4>${esc(sub.orden || "")}. ${esc(sub.nombre)}</h4>
      <p class="hint compact">${esc(sub.hace || "")}</p>
      <div class="agente-motores">${motoresHtml(sub.id, sub.motor, sub.motores)}</div>
    </article>`;
  }

  function selectorClave(agente) {
    const opciones = [`<option value="">Predeterminada</option>`].concat(
      claves.map((clave) => {
        const sel = agente.clave === clave.etiqueta ? " selected" : "";
        return `<option value="${esc(clave.etiqueta)}"${sel}>${esc(textoClave(clave))}</option>`;
      })
    );
    return `<label class="agente-clave">Clave de este agente
      <select data-clave-de="${esc(agente.id)}">${opciones.join("")}</select>
    </label>`;
  }

  function tarjeta(agente) {
    const nota = agente.nota ? `<p class="hint compact">${esc(agente.nota)}</p>` : "";
    const subs = agente.subagentes || [];
    const total = agente.subagentesTotal || subs.length;
    const locales = subs.filter((s) => s.motor === "local").length;
    const cursores = subs.filter((s) => s.motor === "cursor").length;
    const resumen = total
      ? `<p class="agente-cuenta">${total} subagente${total === 1 ? "" : "s"} · ${locales} local · ${cursores} Cursor</p>`
      : `<p class="agente-cuenta">Sin subagentes</p>`;
    const lista = subs.length
      ? `<div class="agente-subs">${subs.map(subtarjeta).join("")}</div>`
      : "";
    return `<article class="agente-card" data-agente="${esc(agente.id)}">
      <h3>${esc(agente.nombre)}</h3>
      <p class="hint compact">${esc(agente.hace || "")}</p>
      ${nota}
      ${selectorClave(agente)}
      ${resumen}
      ${lista || `<div class="agente-motores">${motoresHtml(agente.id, agente.motor, agente.motores)}</div>`}
    </article>`;
  }

  function pintarOrquesta(orquesta) {
    const nota = document.getElementById("agentesOrquestaNota");
    const lista = document.getElementById("agentesOrquestaLista");
    if (!lista) return;
    const piezas = (orquesta && orquesta.piezas) || [];
    if (nota && orquesta && orquesta.nota) nota.textContent = orquesta.nota;
    lista.innerHTML = piezas.length
      ? piezas.map((pieza) => {
          const modelo = pieza.modelo
            ? esc(pieza.proveedor || "cursor") + " · " + esc(pieza.modelo)
            : "La aplicación";
          const cubre = (pieza.cubre || []).map((item) => esc(item)).join(" · ");
          return `<li><strong>${esc(pieza.nombre)}</strong> — ${modelo}<br><span class="hint">${esc(pieza.hace || "")}</span>${cubre ? `<br><span class="hint">${cubre}</span>` : ""}</li>`;
        }).join("")
      : "<li>Sin reparto cargado.</li>";
  }

  function pintarClaves() {
    const lista = document.getElementById("agentesClavesLista");
    const cambiar = document.getElementById("agentesClaveCambiar");
    if (lista) {
      lista.innerHTML = claves.length
        ? claves.map((clave) => `<li>${esc(textoClave(clave))}</li>`).join("")
        : `<li>No hay claves en .env.</li>`;
    }
    if (cambiar && document.activeElement !== cambiar) {
      const actual = cambiar.value;
      cambiar.innerHTML = claves.length
        ? claves.map((clave) => `<option value="${esc(clave.etiqueta)}">${esc(textoClave(clave))}</option>`).join("")
        : `<option value="">Sin claves</option>`;
      if (actual && claves.some((clave) => clave.etiqueta === actual)) cambiar.value = actual;
    }
  }

  async function pintar() {
    const caja = document.getElementById("agentesLista");
    if (!caja) return;
    try {
      const data = await fetchJson("/api/agentes");
      const campo = document.getElementById("agentesModeloNombre");
      if (campo && document.activeElement !== campo) campo.value = data.modeloLocal || "";
      claves = data.claves || [];
      pintarClaves();
      pintarOrquesta(data.orquesta);
      const lista = data.agentes || [];
      caja.innerHTML = lista.length
        ? lista.map(tarjeta).join("")
        : `<p class="hint">No hay agentes en el catálogo.</p>`;
    } catch (e) {
      caja.innerHTML = `<p class="alert alert-warning">No se pudo leer el panel. ${esc(e.message)}</p>`;
    }
  }

  async function onCambio(e) {
    const input = e.target;
    if (!input) return;
    if (input.tagName === "SELECT" && input.hasAttribute("data-clave-de")) {
      const id = input.getAttribute("data-clave-de");
      aviso("Guardando clave…");
      try {
        await fetchJson("/api/agentes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id, clave: input.value }),
        });
        aviso(input.value
          ? "Ese agente usará su clave en el siguiente turno."
          : "Ese agente volvió a la clave predeterminada.");
        await pintar();
      } catch (err) {
        aviso(err.message);
        await pintar();
      }
      return;
    }
    if (input.type !== "radio") return;
    const card = input.closest("[data-agente]");
    if (!card) return;
    const id = card.getAttribute("data-agente");
    aviso("Guardando…");
    try {
      await fetchJson("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id, motor: input.value }),
      });
      aviso(input.value === "local"
        ? "Quedó en local."
        : "Quedó en Cursor.");
      await pintar();
    } catch (err) {
      aviso(err.message);
      await pintar();
    }
  }

  async function guardarModelo() {
    const campo = document.getElementById("agentesModeloNombre");
    const nombre = (campo && campo.value || "").trim();
    aviso("Guardando modelo…");
    try {
      const data = await fetchJson("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ modeloLocal: nombre }),
      });
      if (campo) campo.value = data.modeloLocal || nombre;
      aviso("Modelo local: " + (data.modeloLocal || nombre) + ". El chat de consulta y los agentes locales lo usan en el siguiente turno.");
    } catch (err) {
      aviso(err.message);
    }
  }

  async function agregarClave() {
    const campo = document.getElementById("agentesClaveNueva");
    const nombre = document.getElementById("agentesClaveNombre");
    const valor = (campo && campo.value || "").trim();
    if (!valor) {
      aviso("Pegue la clave nueva.");
      return;
    }
    aviso("Agregando clave…");
    try {
      const data = await fetchJson("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          accion: "agregar-clave",
          valor,
          nombre: (nombre && nombre.value || "").trim(),
        }),
      });
      if (campo) campo.value = "";
      if (nombre) nombre.value = "";
      claves = data.claves || [];
      aviso("Clave agregada. Asígnela al agente que debe usarla.");
      await pintar();
    } catch (err) {
      aviso(err.message);
    }
  }

  async function cambiarClave() {
    const elegir = document.getElementById("agentesClaveCambiar");
    const campo = document.getElementById("agentesClaveValor");
    const nombre = document.getElementById("agentesClaveRenombre");
    const etiqueta = (elegir && elegir.value || "").trim();
    const valor = (campo && campo.value || "").trim();
    const texto = (nombre && nombre.value || "").trim();
    if (!etiqueta) {
      aviso("No hay una clave para cambiar.");
      return;
    }
    if (!valor && !texto) {
      aviso("Escriba el valor nuevo o un nombre.");
      return;
    }
    aviso("Guardando clave…");
    try {
      const cuerpo = { accion: "cambiar-clave", etiqueta };
      if (valor) cuerpo.valor = valor;
      if (texto) cuerpo.nombre = texto;
      await fetchJson("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(cuerpo),
      });
      if (campo) campo.value = "";
      if (nombre) nombre.value = "";
      aviso(valor ? "Clave reemplazada. Los agentes que la tenían siguen usándola." : "Nombre de la clave actualizado.");
      await pintar();
    } catch (err) {
      aviso(err.message);
    }
  }

  function enter() {
    const caja = document.getElementById("agentesLista");
    if (caja && !caja.dataset.bound) {
      caja.dataset.bound = "1";
      caja.addEventListener("change", (e) => onCambio(e));
    }
    const btn = document.getElementById("btnAgentesModelo");
    if (btn && !btn.dataset.bound) {
      btn.dataset.bound = "1";
      btn.addEventListener("click", () => guardarModelo());
    }
    const agregar = document.getElementById("btnAgentesClaveAgregar");
    if (agregar && !agregar.dataset.bound) {
      agregar.dataset.bound = "1";
      agregar.addEventListener("click", () => agregarClave());
    }
    const cambiar = document.getElementById("btnAgentesClaveCambiar");
    if (cambiar && !cambiar.dataset.bound) {
      cambiar.dataset.bound = "1";
      cambiar.addEventListener("click", () => cambiarClave());
    }
    pintar();
  }

  return { enter };
})();
