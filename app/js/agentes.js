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

  function aviso(texto) {
    const el = document.getElementById("agentesAviso");
    if (el) el.textContent = texto || "";
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
      ${resumen}
      ${lista || `<div class="agente-motores">${motoresHtml(agente.id, agente.motor, agente.motores)}</div>`}
    </article>`;
  }

  async function pintar() {
    const caja = document.getElementById("agentesLista");
    if (!caja) return;
    aviso("");
    try {
      const data = await fetchJson("/api/agentes");
      const campo = document.getElementById("agentesModeloNombre");
      if (campo && document.activeElement !== campo) campo.value = data.modeloLocal || "";
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
    if (!input || input.type !== "radio") return;
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
    pintar();
  }

  return { enter };
})();
