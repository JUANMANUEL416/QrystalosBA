/**
 * Lista de desarrolladores (config/desarrolladores.json).
 * Si no existe el nombre, se crea. Al finalizar, pide correos faltantes.
 */
window.QrysDesarrolladores = (function () {
  const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  async function request(method, body) {
    if (location.protocol === "file:") {
      return { ok: false, error: "file", desarrolladores: [], pendientesCorreo: [] };
    }
    const opts = { method, cache: "no-store", headers: { "Content-Type": "application/json" } };
    if (body) opts.body = JSON.stringify(body);
    const resp = await fetch("/api/desarrolladores", opts);
    return resp.json();
  }

  async function listar() {
    try {
      return await request("GET");
    } catch {
      return { ok: false, desarrolladores: [], pendientesCorreo: [] };
    }
  }

  async function sync(items) {
    try {
      return await request("POST", { accion: "sync", items });
    } catch {
      return { ok: false, desarrolladores: [], pendientesCorreo: [] };
    }
  }

  async function setCorreo(nombre, correo) {
    return request("POST", { accion: "correo", nombre, correo });
  }

  function extraerCorreosDelTexto(texto) {
    const hallados = [];
    const lineas = String(texto || "").split(/\n|;/);
    for (const linea of lineas) {
      const m = linea.match(/^\s*(.+?)\s*[:：]\s*(\S+@\S+)\s*$/);
      if (m) hallados.push({ nombre: m[1].trim(), correo: m[2].trim().replace(/[<>]/g, "") });
    }
    const solo = String(texto || "").trim();
    if (!hallados.length && EMAIL_RE.test(solo)) {
      hallados.push({ nombre: "", correo: solo });
    }
    return hallados;
  }

  async function aplicarCorreosDelTexto(texto, nombreFallback) {
    const pares = extraerCorreosDelTexto(texto);
    const aplicados = [];
    for (const p of pares) {
      const nombre = p.nombre || nombreFallback;
      if (!nombre || !EMAIL_RE.test(p.correo)) continue;
      const r = await setCorreo(nombre, p.correo);
      if (r.ok) aplicados.push(`${nombre} → ${p.correo}`);
    }
    return aplicados;
  }

  async function pedirCorreosSiFaltan() {
    const data = await listar();
    const falta = data.pendientesCorreo || (data.desarrolladores || []).filter((d) => !d.correo);
    if (!falta.length) return { ok: true, pedidos: 0, actualizados: [] };

    const actualizados = [];
    for (const d of falta) {
      const reqs = (d.casos || []).map((c) => c.idReq).filter(Boolean).join(", ") || "sin REQ";
      const correo = window.prompt(
        `Falta el correo de ${d.nombre} (${reqs}).\n\n` +
          "Escríbalo para actualizar la lista. Cancelar omite este desarrollador.",
        d.correo || "",
      );
      if (!correo) continue;
      try {
        const r = await setCorreo(d.nombre, correo.trim());
        if (r.ok) actualizados.push(d.nombre);
        else alert(r.error || "No se pudo guardar el correo.");
      } catch (e) {
        alert(e.message || "No se pudo guardar el correo.");
      }
    }
    return { ok: true, pedidos: falta.length, actualizados };
  }

  async function alFinalizar() {
    await sync();
    return pedirCorreosSiFaltan();
  }

  function esFinalizar(texto) {
    return /^\s*finalizar\b/i.test(String(texto || "").trim());
  }

  async function estadoCorreo(idCaso) {
    if (location.protocol === "file:" || !idCaso) {
      return { ok: false, enviado: false, fechaEnvio: "", destinatario: "" };
    }
    const resp = await fetch(`/api/correo?idCaso=${encodeURIComponent(idCaso)}`, { cache: "no-store" });
    return resp.json();
  }

  async function marcarCorreo(body) {
    return requestCorreo({ accion: "marcar", ...body });
  }

  async function enviarCorreo(body) {
    return requestCorreo({ accion: body.reenviar ? "reenviar" : "enviar", ...body });
  }

  async function requestCorreo(body) {
    if (location.protocol === "file:") {
      return { ok: false, error: "Abra la app con abrir-app.bat para enviar correo." };
    }
    const resp = await fetch("/api/correo", {
      method: "POST",
      cache: "no-store",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok && !data.error) data.error = `HTTP ${resp.status}`;
    return data;
  }

  function correoDeLista(data, nombre) {
    const key = String(nombre || "").toUpperCase().replace(/\s+/g, " ").trim();
    const dev = (data.desarrolladores || []).find(
      (d) => String(d.nombre || "").toUpperCase().replace(/\s+/g, " ").trim() === key,
    );
    return (dev && dev.correo) || "";
  }

  return {
    listar,
    sync,
    setCorreo,
    extraerCorreosDelTexto,
    aplicarCorreosDelTexto,
    pedirCorreosSiFaltan,
    alFinalizar,
    esFinalizar,
    estadoCorreo,
    marcarCorreo,
    enviarCorreo,
    correoDeLista,
  };
})();
