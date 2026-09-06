/**
 * Histórico de dictámenes — sincronizado con activo/, dictamenes/ y historico/registro.json
 */
window.QrysHistorico = (function () {
  const STORAGE = "qrys_quatec_historico";
  const PATH_APROBADOS = "C:\\DevQuasar\\Qrystalos\\Qrys.Quatec\\aprobados\\";
  const PATH_DICTAMENES = "C:\\DevQuasar\\Qrystalos\\Qrys.Quatec\\dictamenes\\";

  function load() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE) || "[]");
    } catch {
      return [];
    }
  }

  async function persistToDisk(items) {
    if (location.protocol === "file:") return;
    try {
      await fetch("/api/historico", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ historico: items }),
      });
    } catch {
      /* opcional */
    }
  }

  function save(items) {
    localStorage.setItem(STORAGE, JSON.stringify(items));
    persistToDisk(items);
  }

  function mergeHistorico(local, server) {
    const byId = {};
    for (const item of server) {
      if (item?.idCaso) byId[item.idCaso] = { ...item };
    }
    for (const item of local) {
      if (!item?.idCaso) continue;
      const prev = byId[item.idCaso];
      if (prev) {
        if (item.notas) prev.notas = item.notas;
        const merged = { ...prev, ...item, notas: item.notas || prev.notas };
        merged.estado = mejorEstado(prev.estado, item.estado);
        merged.correoEnviado = !!(prev.correoEnviado || item.correoEnviado);
        merged.fechaEnvioCorreo = item.fechaEnvioCorreo || prev.fechaEnvioCorreo || "";
        byId[item.idCaso] = merged;
      } else {
        byId[item.idCaso] = { ...item };
      }
    }
    return Object.values(byId).sort(
      (a, b) => String(b.actualizado || b.fecha || "").localeCompare(String(a.actualizado || a.fecha || "")),
    );
  }

  async function syncFromServer() {
    if (location.protocol === "file:") {
      try {
        const resp = await fetch("../historico/registro.json");
        if (!resp.ok) return load();
        const data = await resp.json();
        if (!Array.isArray(data) || !data.length) return load();
        const merged = mergeHistorico(load(), data);
        localStorage.setItem(STORAGE, JSON.stringify(merged));
        return merged;
      } catch {
        return load();
      }
    }

    try {
      const resp = await fetch("/api/historico", { cache: "no-store" });
      if (!resp.ok) return load();
      const data = await resp.json();
      const server = data.historico || [];
      const merged = mergeHistorico(load(), server);
      localStorage.setItem(STORAGE, JSON.stringify(merged));
      return merged;
    } catch {
      return load();
    }
  }

  function upsert(entry) {
    const list = load();
    const i = list.findIndex((h) => h.idCaso === entry.idCaso);
    const prev = i >= 0 ? list[i] : {};
    const row = {
      idCaso: entry.idCaso,
      idReq: entry.idReq || prev.idReq || "",
      proyecto: entry.proyecto || prev.proyecto || "",
      modulo: entry.modulo || prev.modulo || "",
      fecha: entry.fecha || prev.fecha || new Date().toISOString().slice(0, 10),
      estado: mejorEstado(prev.estado, entry.estado),
      dictamenPath: entry.dictamenPath || prev.dictamenPath || `${PATH_DICTAMENES}${entry.idCaso}.html`,
      aprobadoPath: entry.aprobadoPath || prev.aprobadoPath || `${PATH_APROBADOS}${entry.idCaso}\\`,
      archivoCola: entry.archivoCola || prev.archivoCola || "",
      notas: entry.notas != null ? entry.notas : (prev.notas || ""),
      correoEnviado: entry.correoEnviado != null ? !!entry.correoEnviado : !!prev.correoEnviado,
      fechaEnvioCorreo: entry.fechaEnvioCorreo || prev.fechaEnvioCorreo || "",
      actualizado: new Date().toISOString(),
    };
    if (i >= 0) list[i] = { ...prev, ...row };
    else list.unshift(row);
    save(list);
    return row;
  }

  function render(tbody, onAbrir) {
    const list = load();
    if (!list.length) {
      tbody.innerHTML =
        `<tr><td colspan="10" class="empty">Sin registros. Active un caso (Fase 1) o pulse <strong>Actualizar desde disco</strong>.</td></tr>`;
      return;
    }
    tbody.innerHTML = list
      .map(
        (h) => `
      <tr>
        <td><code>${esc(h.idCaso)}</code>${h.idReq ? `<br><small>${esc(h.idReq)}</small>` : ""}</td>
        <td>${esc(h.proyecto)}</td>
        <td>${esc(h.modulo)}</td>
        <td>${esc(h.fecha)}</td>
        <td><span class="pill pill-${pillClass(h.estado)}">${esc(labelEstado(h.estado))}</span></td>
        <td>${h.correoEnviado
          ? `<span class="pill pill-mail-ok">Enviado</span><br><small>${esc(h.fechaEnvioCorreo || "")}</small>`
          : `<span class="pill pill-mail-no">No enviado</span>`}</td>
        <td><small>${esc(h.dictamenPath)}</small></td>
        <td><small>${esc(h.aprobadoPath)}</small></td>
        <td><input type="text" class="nota-historico" data-id="${escAttr(h.idCaso)}" value="${escAttr(h.notas)}" placeholder="Notas aval…"></td>
        <td>${onAbrir ? `<button type="button" class="btn btn-ghost btn-sm btn-hist-abrir" data-id="${escAttr(h.idCaso)}">Abrir</button>` : ""}</td>
      </tr>`,
      )
      .join("");

    tbody.querySelectorAll(".nota-historico").forEach((input) => {
      input.addEventListener("change", () => {
        const items = load();
        const i = items.findIndex((h) => h.idCaso === input.dataset.id);
        if (i >= 0) {
          items[i].notas = input.value;
          items[i].actualizado = new Date().toISOString();
          save(items);
        }
      });
    });

    if (onAbrir) {
      tbody.querySelectorAll(".btn-hist-abrir").forEach((btn) => {
        btn.addEventListener("click", () => onAbrir(btn.dataset.id));
      });
    }
  }

  function mejorEstado(a, b) {
    const rank = { pendiente: 0, en_analisis: 1, dictamen: 2, aprobado: 3, enviado: 4 };
    return (rank[b] || 0) >= (rank[a] || 0) ? b || a : a || b;
  }

  function labelEstado(e) {
    return (
      {
        pendiente: "Pendiente",
        en_analisis: "En análisis",
        dictamen: "Dictamen listo",
        aprobado: "Cerrado",
        enviado: "Cerrado · correo enviado",
      }[e] || e
    );
  }

  function pillClass(estado) {
    if (estado === "enviado") return "mail-ok";
    if (estado === "aprobado") return "approved";
    if (estado === "dictamen") return "done";
    if (estado === "en_analisis") return "progress";
    return "pending";
  }

  function exportJson() {
    const blob = new Blob([JSON.stringify(load(), null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "registro.json";
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function importJson(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const data = JSON.parse(reader.result);
          if (!Array.isArray(data)) throw new Error("Formato inválido");
          save(data);
          resolve(data);
        } catch (e) {
          reject(e);
        }
      };
      reader.onerror = reject;
      reader.readAsText(file);
    });
  }

  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;");
  }

  function escAttr(s) {
    return esc(s);
  }

  return {
    load,
    save,
    upsert,
    render,
    exportJson,
    importJson,
    syncFromServer,
    PATH_APROBADOS,
    PATH_DICTAMENES,
  };
})();
