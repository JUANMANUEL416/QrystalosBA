/**
 * Cola de trabajo — parseo de HTML guardado desde ixonline avalasesor
 */
window.QrysCola = (function () {
  const STORAGE_COLA = "qrystalos_ba_cola";
  const STORAGE_COLA_LEGACY = "qrys_quatec_cola";
  const PATH_COLA = "C:\\DevQuasar\\Qrystalos\\QrystalosBA\\cola\\";

  function loadCola() {
    try {
      const raw = localStorage.getItem(STORAGE_COLA) || localStorage.getItem(STORAGE_COLA_LEGACY) || "[]";
      const items = JSON.parse(raw);
      if (!localStorage.getItem(STORAGE_COLA) && localStorage.getItem(STORAGE_COLA_LEGACY)) {
        localStorage.setItem(STORAGE_COLA, raw);
      }
      return Array.isArray(items) ? items : [];
    } catch {
      return [];
    }
  }

  function saveColaLocal(items) {
    localStorage.setItem(STORAGE_COLA, JSON.stringify(items));
  }

  async function persistColaToServer(items) {
    if (location.protocol === "file:") return;
    try {
      await fetch("/api/cola", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ items }),
      });
    } catch {
      /* caché local sigue válida */
    }
  }

  function saveCola(items) {
    saveColaLocal(items);
    persistColaToServer(items);
  }

  async function syncFromServer() {
    if (location.protocol === "file:") return loadCola();
    try {
      const resp = await fetch("/api/cola", { cache: "no-store" });
      if (!resp.ok) return loadCola();
      const data = await resp.json();
      if (Array.isArray(data.items) && data.items.length) {
        saveColaLocal(data.items);
        return data.items;
      }
    } catch {
      /* usar local */
    }
    return loadCola();
  }

  /** Texto de celda (Aval técnico o lista general de reqs). */
  function textoCelda(td) {
    return String(td?.textContent || "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function idReqEnTexto(text) {
    const m = String(text || "").match(/\b(010\d{7})\b/);
    return m ? m[1] : "";
  }

  function esIconoMaterial(t) {
    return /^(more_vert|subject|history|subjecthistory|arrow_upward|arrow_downward)$/i.test(
      String(t || "").replace(/\s+/g, ""),
    );
  }

  function esHoraReloj(t) {
    return /\d{1,2}:\d{2}\s*(AM|PM)/i.test(String(t || "").trim());
  }

  function esFechaDmy(t) {
    return /^\d{1,2}\/\d{1,2}\/\d{4}$/.test(String(t || "").trim());
  }

  function filaImportable(row) {
    if (!row?.idReq) return false;
    const proy = String(row.proyecto || "").trim();
    const mod = String(row.moduloNombre || "").replace(/\s+/g, "").toLowerCase();
    if (esHoraReloj(proy) || esIconoMaterial(proy) || proy === "0" || /^\d+$/.test(proy)) return false;
    if (!proy) return false;
    if (!mod || mod === "sin" || esIconoMaterial(row.moduloNombre) || mod === "subjecthistory") return false;
    return true;
  }

  function esPrioridad(t) {
    return /^\d\s*-\s*(Alta|Media|Baja)/i.test(String(t || "").trim());
  }

  /** Lista general de reqs (ixonline): menú, ID, fechas, días, rama, iconos, proyecto, módulo/asesoría… */
  function parseFilaListaGeneral(tr) {
    const idEl = tr.querySelector(".copyable[title], .copyable");
    const idReq = idReqEnTexto(idEl?.getAttribute("title") || idEl?.textContent || "");
    if (!idReq) return null;

    const ramaEl = tr.querySelector(".rama-copy");
    const rama = String(ramaEl?.getAttribute("title") || textoCelda(ramaEl) || "")
      .replace(/\s+/g, " ")
      .trim();

    const moduloNombre = textoCelda(tr.querySelector(".gr-mod-cell__mod"));
    const area = textoCelda(tr.querySelector(".gr-mod-cell__ase"));
    const asesor = textoCelda(tr.querySelector(".gr-mod-cell__asesor"));
    const avalBadge = textoCelda(tr.querySelector(".gr-mod-cell__aval"));
    const aval = avalBadge || "Sin aval";

    const detalle = tr.querySelector(".detalle-cell");
    let proyecto = "";
    if (detalle && detalle.nextElementSibling) {
      proyecto = textoCelda(detalle.nextElementSibling);
    }
    if (!proyecto || esIconoMaterial(proyecto) || /^\d+$/.test(proyecto)) {
      const tds = [...tr.querySelectorAll("td")];
      const detIdx = tds.indexOf(detalle);
      if (detIdx >= 0 && tds[detIdx + 1]) proyecto = textoCelda(tds[detIdx + 1]);
    }

    const subido = textoCelda(tr.querySelector(".chip-subido-por .q-chip__content"));
    const chips = [...tr.querySelectorAll(".q-chip__content")]
      .map((el) => textoCelda(el))
      .filter(Boolean);
    const chipsDatos = chips.filter((c) => c !== subido);
    const soporteProyecto = chipsDatos[0] || "";
    const desarrollador = chipsDatos[1] || chipsDatos[0] || "";

    const texts = [...tr.querySelectorAll("td")].map(textoCelda);
    const fecha = texts.find(esFechaDmy) || "";
    const prioridad = texts.find(esPrioridad) || "";
    const estado =
      [...tr.querySelectorAll(".q-badge")]
        .map((el) => textoCelda(el))
        .find((t) => /INGRESADO|ASIGNADO|DEVUELTO|CERRADO|PENDIENTE/i.test(t) && !/aval/i.test(t)) || "";

    return {
      idReq,
      fecha,
      rama,
      proyecto,
      moduloNombre,
      area,
      asesor,
      desarrollador,
      soporteProyecto,
      estado,
      aval,
      prioridad,
    };
  }

  /** Aval técnico clásico: ID en columna 0. */
  function parseFilaAvalTecnico(cells) {
    const texts = [...cells].map(textoCelda);
    let idIdx = -1;
    let idReq = "";
    texts.forEach((t, i) => {
      const id = idReqEnTexto(t);
      if (id && idIdx < 0) {
        idReq = id;
        idIdx = i;
      }
    });
    if (!idReq) return null;

    const fecha = texts.find(esFechaDmy) || "";
    const rama = texts.find((t) => /(feature|hotfix|bugfix|release)\s*\//i.test(t)) || "";
    const prioridad = texts.find(esPrioridad) || "";

    let proyecto = "";
    let moduloNombre = "";
    let area = "";
    let desarrollador = "";
    let estado = "";
    let aval = "Sin aval";
    let asesor = "";

    if (idIdx === 0) {
      const textsJoin = texts.join(" ");
      if (esHoraReloj(textsJoin)) return null;
      proyecto = texts[3] || "";
      moduloNombre = texts[4] || "";
      area = texts[5] || "";
      desarrollador = texts[6] || "";
      estado = texts[7] || "";
      aval = texts[8] || "Sin aval";
    } else {
      const ruido = /^(more_vert|subject|history|subjecthistory|—|-|–|•)$/i;
      const utiles = texts.filter((t, i) => {
        if (i <= idIdx) return false;
        if (!t || ruido.test(t) || esIconoMaterial(t)) return false;
        if (esFechaDmy(t)) return false;
        if (idReqEnTexto(t) === idReq) return false;
        if (rama && t.replace(/\s+/g, "").includes(rama.replace(/\s+/g, ""))) return false;
        if (esHoraReloj(t)) return false;
        if (esPrioridad(t)) return false;
        return true;
      });
      proyecto = utiles[0] || "";
      moduloNombre = utiles[1] || "";
      area = utiles[2] || "";
      desarrollador = utiles[3] || "";
      estado = utiles.find((t) => /INGRESADO|ASIGNADO|DEVUELTO|CERRADO|PENDIENTE/i.test(t)) || utiles[4] || "";
      if (utiles.some((t) => /sin aval/i.test(t))) aval = "Sin aval";
    }

    return {
      idReq,
      fecha: fecha || (idIdx === 0 ? texts[1] || "" : ""),
      rama: rama || (idIdx === 0 ? texts[2] || "" : ""),
      proyecto,
      moduloNombre,
      area,
      asesor,
      desarrollador,
      soporteProyecto: "",
      estado,
      aval,
      prioridad,
    };
  }

  /** Parsea filas de q-table: lista general (gr-mod-cell) o Aval técnico. */
  function parseTablaAvalasesor(doc) {
    const rows = [];
    const seen = new Set();

    function tipoTablaReq(table) {
      if (table.querySelector(".gr-mod-cell, .gr-mod-cell__mod")) return "lista";
      const head = String(table.querySelector("thead")?.textContent || "")
        .replace(/\s+/g, " ")
        .toLowerCase();
      if (/hora/.test(head) && !/m[oó]dulo/.test(head)) return "ignorar";
      const muestra = [...table.querySelectorAll("tbody tr")]
        .slice(0, 4)
        .map((tr) => textoCelda(tr))
        .join(" ");
      if (esHoraReloj(muestra) && !/m[oó]dulo/.test(head)) return "ignorar";
      if (table.querySelector(".copyable") && (/proyecto/.test(head) || /m[oó]dulo/.test(head))) return "lista";
      if (/m[oó]dulo/.test(head) && /proyecto/.test(head)) return "aval";
      if (!head) return "ignorar";
      return "aval";
    }

    function pushFromTr(tr, tipo) {
      const row =
        tipo === "lista" || tr.querySelector(".gr-mod-cell, .gr-mod-cell__mod")
          ? parseFilaListaGeneral(tr)
          : parseFilaAvalTecnico(tr.querySelectorAll("td.q-td, td"));
      if (!filaImportable(row) || seen.has(row.idReq)) return;
      seen.add(row.idReq);
      rows.push({ ...row, ordenPagina: rows.length });
    }

    doc.querySelectorAll("table.q-table, table").forEach((table) => {
      const tipo = tipoTablaReq(table);
      if (tipo === "ignorar") return;
      table.querySelectorAll("tbody tr").forEach((tr) => pushFromTr(tr, tipo));
    });

    return rows;
  }

  function parseFechaDMY(dmy) {
    if (!dmy) return "";
    const [d, m, y] = dmy.split("/");
    if (!d || !m || !y) return "";
    return `${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`;
  }

  function slugFromIdReq(idReq) {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${y}${m}${day}-${idReq}`;
  }

  function rowToParsed(row, fileName) {
    return {
      idReq: row.idReq,
      idCaso: slugFromIdReq(row.idReq),
      fecha: parseFechaDMY(row.fecha),
      proyecto: row.proyecto,
      moduloNombre: row.moduloNombre,
      area: row.area,
      asesor: row.asesor || "JOSE MANUEL JIMENEZ",
      rama: row.rama,
      prioridad: row.prioridad || "",
      desarrollador: row.desarrollador,
      soporteProyecto: row.soporteProyecto || "",
      estado: row.estado,
      aval: row.aval,
      archivoCola: fileName,
      rutaCola: PATH_COLA + fileName,
      filasEncontradas: 1,
      esLista: false,
    };
  }

  /** IDs en el HTML crudo (lista general de reqs: title= / td; no depende del DOM). */
  function extraerFilasHtmlCrudo(html) {
    const seen = new Set();
    const filas = [];
    function push(id) {
      if (!id || seen.has(id)) return;
      seen.add(id);
      filas.push({
        idReq: id,
        ordenPagina: filas.length,
        fecha: "",
        rama: "",
        proyecto: "",
        moduloNombre: "",
        area: "",
        desarrollador: "",
        estado: "",
        aval: "Sin aval",
      });
    }
    const re = /(?:title="(010\d{7})"|<td[^>]*>\s*(?:<div[^>]*>)?\s*(010\d{7}))/gi;
    let m;
    const raw = String(html || "");
    while ((m = re.exec(raw))) {
      push(m[1] || m[2]);
    }
    if (!filas.length) {
      (raw.match(/\b010\d{7}\b/g) || []).forEach(push);
    }
    return filas;
  }

  /** Extrae datos del HTML guardado */
  function parseHtmlAvalasesor(html, fileName) {
    const raw = String(html || "");
    let tablaRows = [];
    try {
      const doc = new DOMParser().parseFromString(raw, "text/html");
      tablaRows = parseTablaAvalasesor(doc);
    } catch {
      tablaRows = [];
    }

    if (!tablaRows.length) {
      tablaRows = extraerFilasHtmlCrudo(raw);
    }

    if (tablaRows.length > 0) {
      return {
        filas: tablaRows,
        esLista: tablaRows.length > 1,
        archivoCola: fileName,
        rutaCola: PATH_COLA + fileName,
        mensaje:
          tablaRows.length > 1
            ? `Lista detectada: ${tablaRows.length} requerimientos. Seleccione ID REQ.`
            : `Requerimiento ${tablaRows[0].idReq} detectado.`,
      };
    }

    // Fallback: página de detalle o HTML parcial
    const idReqMatch = raw.match(/\b(010\d{7})\b/) || String(fileName || "").match(/(010\d{7})/);
    return {
      filas: idReqMatch
        ? [
            {
              idReq: idReqMatch[1],
              fecha: "",
              rama: "",
              proyecto: "",
              moduloNombre: "",
              area: "",
              desarrollador: "",
              estado: "",
              aval: "Sin aval",
            },
          ]
        : [],
      esLista: false,
      archivoCola: fileName,
      rutaCola: PATH_COLA + fileName,
      mensaje: idReqMatch
        ? "ID REQ encontrado en texto."
        : `No se detectó tabla ni ID REQ en «${fileName || "el archivo"}». Use Examinar… y elija el .htm de Descargas (IX OnLine.htm), con la tabla visible.`,
    };
  }

  function getParsedForRow(parseResult, idReq) {
    const row = parseResult.filas?.find((r) => r.idReq === idReq) || parseResult.filas?.[0];
    if (!row) return null;
    return rowToParsed(row, parseResult.archivoCola);
  }

  function findExistingEntry(fileName, idReq) {
    if (!idReq) return null;
    return loadCola().find(
      (c) =>
        c.idReqSeleccionado === idReq ||
        c.parsed?.idReq === idReq ||
        (c.archivoCola === fileName && c.idReqSeleccionado === idReq),
    );
  }

  function filterNuevosEnParseResult(parseResult, fileName) {
    const filas = parseResult.filas || [];
    const nuevas = filas.filter((r) => !findExistingEntry(fileName, r.idReq));
    const duplicadas = filas.filter((r) => findExistingEntry(fileName, r.idReq));
    return { nuevas, duplicadas };
  }

  function sortColaItems(cola) {
    return [...cola].sort((a, b) => {
      const oa = a.ordenPagina ?? Number.MAX_SAFE_INTEGER;
      const ob = b.ordenPagina ?? Number.MAX_SAFE_INTEGER;
      if (oa !== ob) return oa - ob;
      return new Date(a.fechaCola) - new Date(b.fechaCola);
    });
  }

  function buildColaItem({ fileName, parseResult, idReqSeleccionado, ordenPagina }) {
    const parsed = idReqSeleccionado
      ? getParsedForRow(parseResult, idReqSeleccionado)
      : parseResult.filas?.length === 1
        ? getParsedForRow(parseResult, parseResult.filas[0].idReq)
        : null;
    const reqId = idReqSeleccionado || parsed?.idReq;
    const row = parseResult.filas?.find((r) => r.idReq === reqId);
    const orden = ordenPagina ?? row?.ordenPagina ?? null;

    return {
      id: parsed?.idReq || fileName,
      archivoCola: fileName,
      rutaCola: PATH_COLA + fileName,
      fechaCola: new Date().toISOString(),
      estado: "pendiente",
      ordenPagina: orden,
      parseResult: {
        esLista: parseResult.esLista,
        totalFilas: parseResult.filas?.length || 0,
        filas: parseResult.filas,
      },
      parsed,
      idReqSeleccionado: reqId,
      dictamenPath: null,
      aprobadoPath: null,
    };
  }

  function addAllToCola({ fileName, html, parseResult }) {
    const cola = loadCola();
    const registrados = [];
    const omitidos = [];
    const terminados = [];
    const idsEnLista = new Set();

    (parseResult.filas || []).forEach((row) => {
      if (!filaImportable(row)) return;
      idsEnLista.add(String(row.idReq || "").trim());
      const existingIdx = cola.findIndex(
        (c) => c.idReqSeleccionado === row.idReq || c.parsed?.idReq === row.idReq,
      );

      if (existingIdx >= 0) {
        const parsed = rowToParsed(row, fileName);
        const prev = cola[existingIdx];
        // Si volvió a aparecer en la lista dinámica, reabre como pendiente
        // solo cuando estaba marcado terminado (no toca en_analisis/dictamen/…).
        const reabrir = prev.estado === "terminado" ? { estado: "pendiente" } : {};
        cola[existingIdx] = {
          ...prev,
          ...reabrir,
          ordenPagina: row.ordenPagina,
          archivoCola: fileName,
          parsed: {
            ...parsed,
            idCaso: prev.parsed?.idCaso || parsed.idCaso,
          },
          parseResult: {
            esLista: parseResult.esLista,
            totalFilas: parseResult.filas?.length || 0,
            filas: parseResult.filas,
          },
        };
        omitidos.push(row);
        return;
      }

      const item = buildColaItem({
        fileName,
        parseResult,
        idReqSeleccionado: row.idReq,
        ordenPagina: row.ordenPagina,
      });
      cola.push(item);
      registrados.push(item);
    });

    // Avalasesor es dinámico: lo que ya no aparece en la lista subida → terminado.
    if (idsEnLista.size) {
      cola.forEach((item, i) => {
        const id = String(item.idReqSeleccionado || item.parsed?.idReq || "").trim();
        if (!id || idsEnLista.has(id)) return;
        if (item.estado === "terminado") return;
        cola[i] = {
          ...item,
          estado: "terminado",
          terminadoEn: new Date().toISOString(),
          terminadoPor: "ausente_en_lista",
        };
        terminados.push(cola[i]);
      });
    }

    saveCola(sortColaItems(cola));

    return {
      registrados,
      omitidos,
      terminados,
      totalEnArchivo: parseResult.filas?.length || 0,
    };
  }

  /** Solo actualiza REQ ya en cola; no agrega filas de otras tablas del HTML. */
  function actualizarParsedExistentes({ fileName, parseResult }) {
    const cola = loadCola();
    let n = 0;
    (parseResult.filas || []).forEach((row) => {
      if (!filaImportable(row)) return;
      const existingIdx = cola.findIndex(
        (c) => c.idReqSeleccionado === row.idReq || c.parsed?.idReq === row.idReq,
      );
      if (existingIdx < 0) return;
      const parsed = rowToParsed(row, fileName);
      const prev = cola[existingIdx];
      cola[existingIdx] = {
        ...prev,
        ordenPagina: row.ordenPagina,
        archivoCola: fileName,
        parsed: { ...parsed, idCaso: prev.parsed?.idCaso || parsed.idCaso },
      };
      n += 1;
    });
    if (n) saveCola(sortColaItems(cola));
    return n;
  }

  function addToCola({ fileName, html, parseResult, idReqSeleccionado, ordenPagina }) {
    const cola = loadCola();
    const reqId =
      idReqSeleccionado ||
      (parseResult.filas?.length === 1 ? parseResult.filas[0].idReq : null);
    const existing = findExistingEntry(fileName, reqId);
    if (existing) {
      return {
        added: false,
        duplicate: true,
        item: existing,
        idReq: reqId,
      };
    }

    const item = buildColaItem({ fileName, parseResult, idReqSeleccionado: reqId, ordenPagina });
    cola.push(item);
    saveCola(sortColaItems(cola));
    return { added: true, duplicate: false, item, idReq: reqId };
  }

  function updateEstado(archivoCola, estado, extra = {}, idReq) {
    const cola = loadCola();
    const i = cola.findIndex(
      (c) =>
        c.archivoCola === archivoCola &&
        (!idReq || c.idReqSeleccionado === idReq || c.parsed?.idReq === idReq),
    );
    if (i >= 0) {
      const rank = {
        pendiente: 0,
        en_analisis: 1,
        dictamen: 2,
        aprobado: 3,
        enviado: 4,
        terminado: 5,
      };
      const actual = cola[i].estado;
      // "terminado" (ausente en lista) siempre gana; el resto no baja de rango.
      const siguiente =
        estado === "terminado" || (rank[estado] || 0) >= (rank[actual] || 0) ? estado : actual;
      cola[i] = { ...cola[i], ...extra, estado: siguiente };
      saveCola(cola);
    }
  }

  function migrateOrdenPagina() {
    const cola = loadCola();
    let changed = false;
    cola.forEach((item) => {
      if (item.ordenPagina != null) return;
      const idReq = item.idReqSeleccionado || item.parsed?.idReq;
      const filas = item.parseResult?.filas;
      if (!idReq || !filas?.length) return;
      const row = filas.find((r) => r.idReq === idReq);
      if (row) {
        item.ordenPagina = row.ordenPagina ?? filas.indexOf(row);
        changed = true;
      }
    });
    if (changed) saveCola(sortColaItems(cola));
  }

  function idReqDeItem(item) {
    return String(item?.idReqSeleccionado || item?.parsed?.idReq || "").trim();
  }

  function coincideFiltroReq(item, filtro) {
    const q = String(filtro || "").trim();
    if (!q) return true;
    const req = idReqDeItem(item);
    const qDig = q.replace(/\D/g, "");
    const reqDig = req.replace(/\D/g, "");
    if (qDig && reqDig.includes(qDig)) return true;
    return req.toLowerCase().includes(q.toLowerCase());
  }

  function renderColaTable(tbody, onAbrir, onSeleccionarReq, onChat, opts) {
    migrateOrdenPagina();
    const cola = sortColaItems(loadCola());
    const filtro = opts?.filtroReq ?? "";
    const verTerminados = !!opts?.verTerminados;
    const activos = cola.filter((item) => item.estado !== "terminado");
    const base = verTerminados ? cola : activos;
    const visibles = base.filter((item) => coincideFiltroReq(item, filtro));
    const nTerm = cola.length - activos.length;
    const hint = document.getElementById("colaFiltroHint");
    if (hint) {
      const partes = [];
      if (filtro.trim()) partes.push(`${visibles.length} de ${base.length}`);
      else partes.push(`${activos.length} activos`);
      if (nTerm) partes.push(`${nTerm} terminados`);
      hint.textContent = partes.join(" · ");
    }
    if (!cola.length) {
      tbody.innerHTML = `<tr><td colspan="7" class="empty">Sin items. Copie el .htm a cola/ y regístrelo aquí.</td></tr>`;
      return;
    }
    if (!visibles.length) {
      const vacio = filtro.trim()
        ? `Ningún REQ coincide con «${esc(filtro.trim())}».`
        : nTerm && !verTerminados
          ? `No hay REQ activos. ${nTerm} terminados (ausentes en la lista de avalasesor). Marque «Ver terminados» para listarlos.`
          : "Sin items visibles.";
      tbody.innerHTML = `<tr><td colspan="7" class="empty">${vacio}</td></tr>`;
      return;
    }

    tbody.innerHTML = visibles
      .map((item, idx) => {
        const p = item.parsed;
        const necesitaSel = item.parseResult?.esLista && !item.parsed;
        const num = item.ordenPagina != null ? item.ordenPagina + 1 : idx + 1;
        return `
      <tr>
        <td class="col-orden">${num}</td>
        <td><span class="pill pill-${estadoClass(item.estado)}">${labelEstado(item.estado)}</span></td>
        <td><strong>${esc(p?.idReq || item.idReqSeleccionado || "—")}</strong><br><small>${esc(item.archivoCola)}</small></td>
        <td>${esc(p?.proyecto || (necesitaSel ? "— seleccione REQ —" : "—"))}</td>
        <td>${esc(p?.moduloNombre || "—")}</td>
        <td>${new Date(item.fechaCola).toLocaleDateString("es-CO")}</td>
        <td class="actions-cell">
          ${necesitaSel ? `<button type="button" class="btn btn-secondary btn-sm btn-sel-req" data-file="${escAttr(item.archivoCola)}">Elegir REQ</button>` : ""}
          <button type="button" class="btn btn-primary btn-sm btn-abrir-cola" data-file="${escAttr(item.archivoCola)}" data-req="${escAttr(item.idReqSeleccionado || p?.idReq || "")}" ${necesitaSel ? "disabled" : ""}>Abrir</button>
          ${!necesitaSel && p?.idCaso ? `<button type="button" class="btn btn-secondary btn-sm btn-chat-cola" data-file="${escAttr(item.archivoCola)}" data-req="${escAttr(item.idReqSeleccionado || p?.idReq || "")}" title="Chat del caso">💬 Chat</button>` : ""}
          <button type="button" class="btn btn-ghost btn-sm btn-del-cola" data-file="${escAttr(item.archivoCola)}" data-req="${escAttr(item.idReqSeleccionado || "")}">×</button>
        </td>
      </tr>`;
      })
      .join("");

    tbody.querySelectorAll(".btn-abrir-cola").forEach((btn) => {
      btn.addEventListener("click", () => onAbrir(btn.dataset.file, btn.dataset.req));
    });
    if (onChat) {
      tbody.querySelectorAll(".btn-chat-cola").forEach((btn) => {
        btn.addEventListener("click", () => onChat(btn.dataset.file, btn.dataset.req));
      });
    }
    tbody.querySelectorAll(".btn-sel-req").forEach((btn) => {
      btn.addEventListener("click", () => onSeleccionarReq(btn.dataset.file));
    });
    tbody.querySelectorAll(".btn-del-cola").forEach((btn) => {
      btn.addEventListener("click", () => {
        const cola = loadCola().filter(
          (c) => !(c.archivoCola === btn.dataset.file && (c.idReqSeleccionado || "") === btn.dataset.req),
        );
        saveCola(cola);
        renderColaTable(tbody, onAbrir, onSeleccionarReq, onChat, opts);
      });
    });
  }

  function labelEstado(e) {
    return (
      {
        pendiente: "Pendiente",
        en_analisis: "En análisis",
        dictamen: "Dictamen listo",
        aprobado: "Cerrado",
        enviado: "Cerrado · correo enviado",
        terminado: "Terminado",
      }[e] || e
    );
  }

  function estadoClass(e) {
    return {
      pendiente: "pending",
      en_analisis: "progress",
      dictamen: "done",
      aprobado: "approved",
      enviado: "mail-ok",
      terminado: "mail-no",
    }[e] || "pending";
  }

  function esc(s) {
    return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
  }

  function escAttr(s) {
    return esc(s).replace(/"/g, "&quot;");
  }

  function getItem(archivoCola, idReq) {
    return loadCola().find(
      (c) => c.archivoCola === archivoCola && (!idReq || c.idReqSeleccionado === idReq || c.parsed?.idReq === idReq),
    );
  }

  /** Entradas legacy o sin REQ válido */
  function findCorruptEntries() {
    return loadCola().filter((item) => {
      if (item.parseResult?.filas?.length) {
        return item.parseResult.esLista && !item.parsed;
      }
      if (!item.parsed?.idReq) return true;
      const compact = (item.parsed.moduloNombre || "").replace(/\s+/g, "").toLowerCase();
      if (!compact || compact === "subjecthistory" || esIconoMaterial(item.parsed.moduloNombre) || compact === "sin") return true;
      const proy = String(item.parsed.proyecto || "").trim();
      if (proy === "0" || /^\d+$/.test(proy) || /\d{1,2}:\d{2}\s*(AM|PM)/i.test(proy)) return true;
      return compact.length > 120 || /ASIGNADOSin aval/i.test(item.parsed.moduloNombre || "");
    });
  }

  function removeCorruptEntries() {
    const corrupt = new Set(findCorruptEntries().map((c) => `${c.archivoCola}::${c.idReqSeleccionado || ""}`));
    const cola = loadCola().filter(
      (c) => !corrupt.has(`${c.archivoCola}::${c.idReqSeleccionado || ""}`),
    );
    saveCola(cola);
    return corrupt.size;
  }

  function clearCola() {
    saveCola([]);
  }

  function normalizeFileName(name) {
    const base = String(name || "")
      .split(/[/\\]/)
      .pop()
      .trim();
    if (!base) return "aval-asesor-lista.htm";
    if (/aval[-_ ]?asesor|aval.*lista/i.test(base)) return "aval-asesor-lista.htm";
    return base;
  }

  function suggestColaFileName(fileName, parseResult) {
    if (parseResult.filas?.length === 1) {
      return `${parseResult.filas[0].idReq}.html`;
    }
    return normalizeFileName(fileName);
  }

  return {
    PATH_COLA,
    loadCola,
    saveCola,
    syncFromServer,
    parseHtmlAvalasesor,
    getParsedForRow,
    addToCola,
    addAllToCola,
    actualizarParsedExistentes,
    updateEstado,
    renderColaTable,
    getItem,
    findCorruptEntries,
    removeCorruptEntries,
    clearCola,
    normalizeFileName,
    suggestColaFileName,
    findExistingEntry,
    filterNuevosEnParseResult,
    labelEstado,
    sortColaItems,
  };
})();
