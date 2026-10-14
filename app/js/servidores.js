/**
 * Servidores SQL: el listado solo aparece después del usuario de acceso.
 */
window.QrysServidores = (function () {
  const TOKEN_KEY = "qrystalos_ba_servidores_sesion";
  let creando = false;
  let editando = false;

  function $(id) {
    return document.getElementById(id);
  }

  function token() {
    try {
      return sessionStorage.getItem(TOKEN_KEY) || "";
    } catch (_) {
      return "";
    }
  }

  function guardarToken(valor) {
    try {
      if (valor) sessionStorage.setItem(TOKEN_KEY, valor);
      else sessionStorage.removeItem(TOKEN_KEY);
    } catch (_) {}
  }

  function aviso(texto) {
    const el = $("srvAviso");
    if (!el) return;
    el.hidden = !texto;
    el.textContent = texto || "";
  }

  async function api(ruta, opciones) {
    const headers = { ...(opciones && opciones.headers) };
    const sesion = token();
    if (sesion) headers["X-Ba-Sesion"] = sesion;
    const res = await fetch(ruta, { ...opciones, headers });
    const data = await res.json().catch(() => ({}));
    if (res.status === 401) {
      guardarToken("");
      pintarAcceso(true);
      throw new Error(data.error || "Inicie sesión.");
    }
    if (!res.ok || data.ok === false) throw new Error(data.error || "No se pudo completar.");
    return data;
  }

  function pintarAcceso(configurado) {
    const form = $("srvAcceso");
    const panel = $("srvPanel");
    const confirmar = $("srvAccesoConfirmarCampo");
    if (panel) panel.hidden = true;
    if (form) form.hidden = false;
    creando = !configurado;
    if (confirmar) confirmar.hidden = configurado;
    const titulo = $("srvAccesoTitulo");
    const ayuda = $("srvAccesoAyuda");
    const btn = $("srvAccesoBtn");
    if (titulo) titulo.textContent = configurado ? "Ingresar" : "Crear usuario de acceso";
    if (ayuda) {
      ayuda.textContent = configurado
        ? "Este usuario es de la oficina. No es el usuario de SQL."
        : "La primera vez se crea aquí. Después, cada ingreso pide este usuario y esta clave. Mínimo 8 caracteres.";
    }
    if (btn) btn.textContent = configurado ? "Ingresar" : "Crear e ingresar";
    const clave = $("srvAccesoClave");
    if (clave) clave.autocomplete = configurado ? "current-password" : "new-password";
  }

  function fila(s) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
      <td><button type="button" class="btn btn-secondary btn-sm" data-editar>Editar</button>
          <button type="button" class="btn btn-secondary btn-sm" data-quitar>Quitar</button></td>`;
    const celdas = tr.querySelectorAll("td");
    celdas[0].textContent = s.nombre || s.id;
    celdas[1].textContent = s.id;
    celdas[2].textContent = s.host || "";
    celdas[3].textContent = s.puerto || "";
    celdas[4].textContent = (s.bases && s.bases.length) ? s.bases.join(", ") : (s.base || "");
    celdas[5].textContent = s.usuario || "";
    celdas[6].textContent = s.soloLectura ? "Solo lectura" : "Escritura";
    tr.querySelector("[data-editar]").addEventListener("click", () => abrir(s.id));
    tr.querySelector("[data-quitar]").addEventListener("click", () => quitar(s.id, s.nombre || s.id));
    return tr;
  }

  async function listar() {
    aviso("");
    const data = await api("/api/servidores");
    const cont = $("srvLista");
    if (!cont) return;
    cont.innerHTML = "";
    const tabla = document.createElement("table");
    tabla.className = "srv-tabla";
    tabla.innerHTML = "<thead><tr><th>Nombre</th><th>Id</th><th>Host</th><th>Puerto</th><th>Base</th><th>Usuario SQL</th><th>Uso</th><th></th></tr></thead>";
    const cuerpo = document.createElement("tbody");
    (data.servidores || []).forEach((s) => cuerpo.appendChild(fila(s)));
    if (!(data.servidores || []).length) {
      const vacio = document.createElement("tr");
      vacio.innerHTML = '<td colspan="8">No hay servidores guardados.</td>';
      cuerpo.appendChild(vacio);
    }
    tabla.appendChild(cuerpo);
    cont.appendChild(tabla);
  }

  function limpiarFormulario() {
    ["srvId", "srvNombre", "srvHost", "srvPuerto", "srvBase", "srvUsuario", "srvClave"].forEach((id) => {
      const el = $(id);
      if (el) el.value = "";
    });
    const uso = $("srvSoloLectura");
    if (uso) uso.value = "1";
    const id = $("srvId");
    if (id) id.readOnly = false;
    editando = false;
    pintarBasesLista([]);
  }

  function mostrarFormulario(titulo) {
    const form = $("srvForm");
    if (form) form.hidden = false;
    const h = $("srvFormTitulo");
    if (h) h.textContent = titulo;
    const ayuda = $("srvClaveAyuda");
    if (ayuda) ayuda.hidden = !editando;
  }

  async function abrir(id) {
    aviso("");
    const data = await api("/api/servidores/detalle", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });
    const s = data.servidor;
    editando = true;
    $("srvId").value = s.id;
    $("srvId").readOnly = true;
    $("srvNombre").value = s.nombre || "";
    $("srvNombre").readOnly = false;
    $("srvHost").value = s.host || "";
    $("srvPuerto").value = s.puerto || "";
    $("srvBase").value = s.base || "";
    $("srvUsuario").value = s.usuario || "";
    $("srvClave").value = s.clave || "";
    $("srvClave").type = "password";
    $("srvSoloLectura").value = s.soloLectura ? "1" : "0";
    pintarBasesLista(s.bases || _lista_bases(s.base));
    mostrarFormulario(s.nombre || s.id);
  }

  function _lista_bases(texto) {
    return String(texto || "")
      .split(",")
      .map((b) => b.trim())
      .filter(Boolean);
  }

  function pintarBasesLista(bases) {
    const ul = $("srvBasesLista");
    if (!ul) return;
    if (!bases || !bases.length) {
      ul.innerHTML = "";
      return;
    }
    ul.innerHTML = bases.map((b) => `<li>${b}</li>`).join("");
  }

  async function quitar(id, nombre) {
    if (!window.confirm("Quitar " + nombre + " de este equipo?")) return;
    aviso("");
    await api("/api/servidores/quitar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });
    $("srvForm").hidden = true;
    limpiarFormulario();
    await listar();
  }

  async function enter() {
    aviso("");
    let estado;
    try {
      const res = await fetch("/api/servidores/estado", { headers: { "X-Ba-Sesion": token() } });
      if (res.status === 404) {
        aviso("El menú ya está en la página. Falta reiniciar el servicio con reiniciar-servidor.bat (como administrador) y pulsar Ctrl+F5.");
        return;
      }
      estado = await res.json();
    } catch (_) {
      aviso("No hay conexión con el servidor de la oficina. Abra la aplicación con abrir-app.bat.");
      return;
    }
    if (estado.sesion && token()) {
      $("srvAcceso").hidden = true;
      $("srvPanel").hidden = false;
      $("srvForm").hidden = true;
      try {
        await listar();
      } catch (err) {
        aviso(err.message);
      }
      return;
    }
    pintarAcceso(!!estado.configurado);
  }

  function bind() {
    const acceso = $("srvAcceso");
    if (!acceso || acceso.dataset.bound) return;
    acceso.dataset.bound = "1";
    acceso.addEventListener("submit", async (e) => {
      e.preventDefault();
      aviso("");
      const usuario = $("srvAccesoUsuario").value.trim();
      const clave = $("srvAccesoClave").value;
      if (creando && clave !== $("srvAccesoConfirmar").value) {
        aviso("La confirmación no coincide.");
        return;
      }
      try {
        const data = await api("/api/servidores/entrar", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ usuario, clave, crear: creando }),
        });
        guardarToken(data.token);
        $("srvAccesoClave").value = "";
        if ($("srvAccesoConfirmar")) $("srvAccesoConfirmar").value = "";
        await enter();
      } catch (err) {
        aviso(err.message);
      }
    });
    $("srvSalir").addEventListener("click", async () => {
      try {
        await api("/api/servidores/salir", { method: "POST" });
      } catch (_) {}
      guardarToken("");
      $("srvForm").hidden = true;
      await enter();
    });
    $("srvTraer").addEventListener("click", async () => {
      aviso("");
      try {
        const data = await api("/api/servidores/traer-qrystalos2", { method: "POST" });
        const nuevos = (data.agregados || []).map((s) => s.nombre || s.id);
        const sumadas = (data.basesSumadas || []).map((s) => s.id);
        const quitados = data.quitados || [];
        const partes = [];
        if (quitados.length) partes.push("Unificados, se quitó la repetición: " + quitados.join(", "));
        if (nuevos.length) partes.push("Agregados: " + nuevos.join(", "));
        if (sumadas.length) partes.push("Bases sumadas en: " + sumadas.join(", "));
        if (!partes.length) partes.push("Ya estaban todas, sin repetir host y puerto.");
        aviso(partes.join(". ") + ".");
        await listar();
      } catch (err) {
        aviso(err.message);
      }
    });
    $("srvNuevo").addEventListener("click", () => {
      limpiarFormulario();
      mostrarFormulario("Nuevo servidor");
    });
    $("srvVerClave").addEventListener("click", () => {
      const clave = $("srvClave");
      const visible = clave.type === "text";
      clave.type = visible ? "password" : "text";
      $("srvVerClave").textContent = visible ? "Mostrar" : "Ocultar";
    });
    $("srvListarBases")?.addEventListener("click", async () => {
      aviso("");
      const id = ($("srvId")?.value || "").trim();
      if (!id) {
        aviso("Indique el identificador del servidor.");
        return;
      }
      try {
        aviso("Consultando catálogo SQL…");
        const data = await api("/api/servidores/listar-bases", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id }),
        });
        const bases = data.bases || [];
        pintarBasesLista(bases);
        if (bases.length) $("srvBase").value = bases.join(", ");
        aviso(`Se encontraron ${bases.length} base(s). Revise y guarde si aplica.`);
      } catch (err) {
        aviso(err.message);
      }
    });
    $("srvCancelar").addEventListener("click", () => {
      $("srvForm").hidden = true;
      limpiarFormulario();
    });
    $("srvForm").addEventListener("submit", async (e) => {
      e.preventDefault();
      aviso("");
      const cuerpo = {
        id: $("srvId").value.trim(),
        nombre: $("srvNombre").value.trim(),
        host: $("srvHost").value.trim(),
        puerto: $("srvPuerto").value.trim(),
        base: $("srvBase").value.trim(),
        usuario: $("srvUsuario").value.trim(),
        clave: $("srvClave").value,
        soloLectura: $("srvSoloLectura").value === "1",
      };
      try {
        await api("/api/servidores/guardar", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(cuerpo),
        });
        $("srvClave").value = "";
        $("srvForm").hidden = true;
        limpiarFormulario();
        await listar();
      } catch (err) {
        aviso(err.message);
      }
    });
  }

  bind();
  return { enter };
})();
