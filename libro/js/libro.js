(function () {
  const $ = (s) => document.querySelector(s);
  const estado = {
    indice: null,
    id: "",
    modo: "capacitacion", // "capacitacion" (Manual de uso) | "ayuda" (Pasos y validaciones)
    presentar: false,
    escena: 0,
    paquete: null,
    filtro: "",
    familiasAbiertas: new Set(),
  };

  // Diccionario de datos de muestra para enriquecer las plantillas de Excel generadas dinámicamente
  const EJEMPLO = {
    // Facturación y Cartera
    N_FACTURA: "F001",
    TIPO: "F",
    VLRPAGO: "1.250.000",
    VLR_GLOSA: "250.000",
    CODGLOSA: "G01",
    VLR_ITEM: "250.000",
    OBSERVACION: "Detalle del ajuste",
    OBSERVACIONES: "Respuesta formal de la glosa",
    MOTIVO1: "G01",
    MOTIVO2: "",
    OBS: "Nota aclaratoria",
    CODRPTA: "R01",
    VLR_ACEPTADO: "180.000",
    VALOR: "250.000",
    VALIDACION: "OK",
    IDIMPUESTO: "RET01",
    VLR_DTO: "0",
    NUMERO_CUENTA: "CC-2026-089",
    // Contabilidad y Tesorería
    IDCUENTA: "13050501",
    NOMBRECUENTA: "Clientes Nacionales",
    DEBITO: "1.250.000",
    CREDITO: "0",
    NIT: "900.123.456-7",
    TERCERO: "EPS Sanitas",
    RECIBO: "RC-4501",
    VALOR_RECIBO: "1.250.000",
    BANCO: "Bancolombia",
    // Inventario y Compras
    CODARTICULO: "MED-0042",
    DESCRIPCION: "Acetaminofén 500mg Tab",
    CANTIDAD: "100",
    COSTO: "250",
    LOTE: "LT-2026A",
    FECHAVENCE: "2027-12-31",
    BODEGA: "Farmacia Central",
    ORDEN: "OC-1024",
  };

  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  async function traer(url) {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(url + " " + r.status);
    return r;
  }

  function familiaNombre(id) {
    const mapa = {
      facturacion: "Facturación y RIPS",
      cartera: "Cartera y Cobranzas",
      caja: "Caja y Recibos",
      contabilidad: "Contabilidad y Cierres",
      tesoreria: "Tesorería y Bancos",
      nomina: "Nómina y Personal",
      inventario: "Inventario, Compras y Farmacia",
      activos: "Activos Fijos",
      asistencial: "Atención y Consulta Externa",
      presupuesto: "Presupuesto",
      financiero: "Cuentas por Pagar (CxP)",
      auditoria: "Auditoría Médica",
      radicaciones: "Radicación de Cuentas",
      configuracion: "Configuración del sistema",
      otros: "Otros Procesos",
    };
    return mapa[id] || (id ? id.charAt(0).toUpperCase() + id.slice(1) : "General");
  }

  function familiaDeProceso(id) {
    if (!id || !estado.indice?.procesos) return null;
    const p = estado.indice.procesos.find((x) => x.id === id);
    return p ? (p.familia || "otros") : null;
  }

  const ICONOS_FAMILIA = {
    facturacion: "receipt_long",
    cartera: "account_balance_wallet",
    caja: "point_of_sale",
    contabilidad: "pie_chart",
    tesoreria: "account_balance",
    nomina: "badge",
    inventario: "inventory_2",
    activos: "domain",
    asistencial: "medical_services",
    presupuesto: "query_stats",
    financiero: "payments",
    auditoria: "fact_check",
    radicaciones: "mark_email_read",
    configuracion: "settings",
    otros: "folder_open",
  };

  function formatearFecha(iso) {
    if (!iso) return "Actualizada";
    try {
      const d = new Date(iso);
      if (isNaN(d.getTime())) return String(iso).slice(0, 10);
      return d.toLocaleDateString("es-CO", { day: "numeric", month: "short", year: "numeric" });
    } catch {
      return String(iso).slice(0, 10);
    }
  }

  function codigos(texto) {
    const vistos = [];
    for (const m of String(texto).matchAll(/`([A-Z][A-Z0-9_]*)`/g)) {
      if (!vistos.includes(m[1])) vistos.push(m[1]);
    }
    return vistos;
  }

  function hoja(columnas, pie) {
    const th = columnas
      .map((c) => `<th class="${c === "VALIDACION" ? "col-val" : ""}">${esc(c)}</th>`)
      .join("");
    const td = columnas
      .map((c) => {
        const v = EJEMPLO[c] ?? "Dato";
        const cls = c === "VALIDACION" ? "col-val ok" : "";
        return `<td class="${cls}">${esc(v)}</td>`;
      })
      .join("");
    return `<div class="sheet-wrap">
      <div class="sheet-header-label">
        <span class="sheet-ico">📊</span> Plantilla requerida en Excel
      </div>
      <table class="sheet">
        <thead><tr>${th}</tr></thead>
        <tbody><tr>${td}</tr></tbody>
        ${pie ? `<caption>${esc(pie)}</caption>` : ""}
      </table>
    </div>`;
  }

  function limpiarTextoNegocio(texto) {
    if (!texto) return "";
    let s = String(texto);
    s = s.replace(/\(BMOV\.ESTADO\s*=\s*['"]?O['"]?\)/gi, "(con el movimiento bancario confirmado por tesorería)");
    s = s.replace(/`?BMOV\.ESTADO\s*=\s*['"]?O['"]?`?/gi, "movimiento bancario confirmado");
    s = s.replace(/\(FCJ\.RECAUDO\s*=\s*1\)/gi, "(marcado como recaudo en caja)");
    s = s.replace(/`?FCJ\.RECAUDO\s*=\s*1`?/gi, "marcado como recaudo");
    s = s.replace(/\(CERRADA\s*=\s*1\)/gi, "(ya cerrado)");
    s = s.replace(/`?CERRADA\s*=\s*1`?/gi, "cerrado");
    s = s.replace(/`?BMOVD\.RECAUDO`?/gi, "marca de recaudo");
    s = s.replace(/`?CAJ\.ACEPTARECAUDO`?/gi, "configuración de acepta recaudo");
    s = s.replace(/\(FINDEVOL\)/gi, "(Paso a seguir)");
    s = s.replace(/`?FINDEVOL`?/g, "Paso a seguir");
    return s;
  }

  function inline(s, opciones) {
    let t = String(s ?? "");
    if (estado.modo === "capacitacion") {
      t = limpiarTextoNegocio(t);
    }

    const cols = codigos(t);
    let out = esc(t);
    // Imágenes Markdown ![alt](url)
    out = out.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<div class="img-ilustracion-wrap"><img src="$2" alt="$1" class="img-ilustracion" /><span class="img-caption">$1</span></div>');
    // Enlaces Markdown [texto](url)
    out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
    // Código en línea
    out = out.replace(/`([^`]+)`/g, "<code>$1</code>");
    // Negrita
    out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    const esPlantilla = /plantilla|excel|archivo\s+plano|formato\s+de\s+carga/i.test(t);
    if (!opciones?.sinHoja && cols.length >= 3 && esPlantilla) return out + hoja(cols);
    return out;
  }

  function esSeparador(linea) {
    const t = linea.trim();
    return t.includes("-") && /^\|?[\s|:-]+\|?$/.test(t);
  }

  function celdas(linea) {
    return linea
      .trim()
      .replace(/^\|/, "")
      .replace(/\|$/, "")
      .split("|")
      .map((c) => c.trim());
  }

  function renderTablaDobleLinea(head, body, idxExcel, idxPaso, idxNombre) {
    let cardsHtml = "";

    body.forEach((r) => {
      // 1. Paso / Código
      const pasoRaw = idxPaso !== -1 ? r[idxPaso] : "";
      const pasoLimpio = pasoRaw
        ? inline(pasoRaw, { sinHoja: true })
            .replace(/<[^>]+>/g, "")
            .trim()
        : "";

      // 2. Nombre
      const nombreRaw = idxNombre !== -1 ? r[idxNombre] : "";
      const nombreHtml = nombreRaw ? inline(nombreRaw, { sinHoja: true }) : "";

      // 3. Explicación y otras columnas
      const explicaciones = [];
      head.forEach((h, colIdx) => {
        if (colIdx !== idxExcel && colIdx !== idxPaso && colIdx !== idxNombre) {
          const val = r[colIdx];
          if (val) {
            explicaciones.push({
              header: h,
              html: inline(val, { sinHoja: true }),
            });
          }
        }
      });

      // 4. Excel / Plantilla
      const excelRaw = r[idxExcel] || "";
      const cols = codigos(excelRaw);

      // Reversibilidad / Candados
      const todoElTexto = r.join(" ").toLowerCase();
      let badgeReversibilidad = "";
      if (
        todoElTexto.includes("no se puede deshacer") ||
        todoElTexto.includes("no se puede reversar") ||
        todoElTexto.includes("no se puede desaplicar") ||
        todoElTexto.includes("no reversible") ||
        todoElTexto.includes("acción definitiva")
      ) {
        badgeReversibilidad = `<span class="paso-dl-reversibilidad paso-dl-reversibilidad--alerta"><span class="material-icons">lock</span> Acción Definitiva · No se puede desaplicar</span>`;
      } else if (todoElTexto.includes("permite retirar") || todoElTexto.includes("permite desaplicar")) {
        badgeReversibilidad = `<span class="paso-dl-reversibilidad paso-dl-reversibilidad--ok"><span class="material-icons">check_circle</span> Permite retiro o corrección</span>`;
      }

      // Cabecera superior
      let cabeceraPasoHtml = "";
      if (pasoLimpio || nombreHtml) {
        cabeceraPasoHtml = `
          <div class="paso-dl-cabecera">
            <div class="paso-dl-paso-badge">
              <span class="paso-dl-badge-num">${esc(pasoLimpio || "•")}</span>
              <span class="paso-dl-badge-txt">${esc(idxPaso !== -1 ? head[idxPaso] : "Paso a seguir")}</span>
            </div>
            <h4 class="paso-dl-titulo">${nombreHtml}</h4>
            ${badgeReversibilidad}
          </div>
        `;
      }

      // Explicaciones superiores
      let explicacionHtml = "";
      if (explicaciones.length) {
        explicacionHtml = `
          <div class="paso-dl-explicacion">
            ${explicaciones
              .map(
                (e) => `
              <div class="paso-dl-item-exp">
                <span class="paso-dl-exp-label">${esc(e.header)}:</span>
                <div class="paso-dl-exp-texto">${e.html}</div>
              </div>
            `
              )
              .join("")}
          </div>
        `;
      }

      // Inferior: Formato en Excel (Debajo)
      let inferiorHtml = "";
      if (cols.length > 0) {
        const tags = cols.map((c) => `<span class="paso-dl-col-tag"><code>${esc(c)}</code></span>`).join("");

        let notaResto = excelRaw.replace(/`[^`]+`/g, "").replace(/,\s*,/g, "").trim();
        notaResto = notaResto.replace(/^[\s,;.-]+|[\s,;.-]+$/g, "");

        inferiorHtml = `
          <div class="paso-dl-inferior">
            <div class="paso-dl-excel-barra">
              <div class="paso-dl-excel-tit">
                <span class="sheet-ico">📊</span>
                <strong>Formato en Excel Requerido (Estructura de Columnas)</strong>
              </div>
              <div class="paso-dl-cols-tags">
                ${tags}
              </div>
            </div>
            ${hoja(cols)}
            ${notaResto ? `<div class="paso-dl-excel-nota">${inline(notaResto, { sinHoja: true })}</div>` : ""}
          </div>
        `;
      } else if (excelRaw.trim()) {
        inferiorHtml = `
          <div class="paso-dl-inferior paso-dl-inferior--simple">
            <div class="paso-dl-excel-barra">
              <div class="paso-dl-excel-tit">
                <span class="sheet-ico">📋</span>
                <strong>Formato de Carga:</strong>
              </div>
            </div>
            <div class="paso-dl-sin-excel-txt">${inline(excelRaw, { sinHoja: true })}</div>
          </div>
        `;
      }

      cardsHtml += `
        <div class="paso-dl-card">
          <div class="paso-dl-superior">
            ${cabeceraPasoHtml}
            ${explicacionHtml}
          </div>
          ${inferiorHtml}
        </div>
      `;
    });

    return `<div class="pasos-doble-linea-contenedor">${cardsHtml}</div>`;
  }

  function mdToHtml(md) {
    const lines = String(md || "").replace(/\r\n/g, "\n").split("\n");
    let html = "";
    let i = 0;
    const flushP = (buf) => {
      if (!buf.length) return;
      html += `<p>${inline(buf.join(" "))}</p>`;
      buf.length = 0;
    };
    const buf = [];
    while (i < lines.length) {
      const line = lines[i];
      if (!line.trim()) {
        flushP(buf);
        i += 1;
        continue;
      }
      if (line.startsWith("```")) {
        flushP(buf);
        const codeLines = [];
        i += 1;
        while (i < lines.length && !lines[i].startsWith("```")) {
          codeLines.push(lines[i]);
          i += 1;
        }
        if (i < lines.length) i += 1;
        html += `<pre class="codigo-bloque"><code>${esc(codeLines.join("\n"))}</code></pre>`;
        continue;
      }
      if (line.startsWith("### ")) {
        flushP(buf);
        html += `<h3>${inline(line.slice(4))}</h3>`;
        i += 1;
        continue;
      }
      if (line.startsWith("## ")) {
        flushP(buf);
        html += `<h3>${inline(line.slice(3))}</h3>`;
        i += 1;
        continue;
      }
      if (/^\d+\. /.test(line.trim())) {
        flushP(buf);
        const inicio = parseInt(line.trim(), 10);
        html += inicio > 1 ? `<ol start="${inicio}">` : "<ol>";
        while (i < lines.length && /^\d+\. /.test(lines[i].trim())) {
          html += `<li>${inline(lines[i].trim().replace(/^\d+\. /, ""))}</li>`;
          i += 1;
        }
        html += "</ol>";
        continue;
      }
      if (line.startsWith("> ")) {
        const cita = line.slice(2).trim();
        // Ocultar notas de catálogo SQL / cuerpos de desarrollo en manual de uso
        if (
          estado.modo === "capacitacion" &&
          (cita.includes("Cuerpos SQL en sql/") ||
            cita.includes("SPQ_") ||
            cita.includes("SPK_") ||
            cita.includes("PREVERSION") ||
            cita.includes("Flujo y plantillas"))
        ) {
          i += 1;
          continue;
        }
        flushP(buf);
        html += `<div class="cita-box"><span class="cita-ico">💡</span><div class="cita-body">${inline(cita)}</div></div>`;
        i += 1;
        continue;
      }
      if (line.trim().startsWith("|")) {
        flushP(buf);
        const rows = [];
        while (i < lines.length && lines[i].trim().startsWith("|")) {
          if (!esSeparador(lines[i])) rows.push(celdas(lines[i]));
          i += 1;
        }
        if (rows.length) {
          const head = rows[0];
          const body = rows.slice(1);

          // Detectar si la tabla contiene columnas de plantilla Excel o estructura de archivo
          const idxExcel = head.findIndex((h) => /plantilla|excel|formato.*col/i.test(h));
          const idxPaso = head.findIndex((h) => /paso|opci[oó]n|c[oó]digo|n[uú]m/i.test(h));
          const idxNombre = head.findIndex((h) => /nombre|pantalla|acci[oó]n|t[ií]tulo/i.test(h));

          if (idxExcel !== -1) {
            html += renderTablaDobleLinea(head, body, idxExcel, idxPaso, idxNombre);
          } else {
            html += `<div class="tabla-wrap"><table class="tabla"><thead><tr>${head.map((c) => `<th>${inline(c, { sinHoja: true })}</th>`).join("")}</tr></thead><tbody>`;
            body.forEach((r) => {
              html += `<tr>${r.map((c) => `<td>${inline(c, { sinHoja: true })}</td>`).join("")}</tr>`;
            });
            html += "</tbody></table></div>";
          }
        }
        continue;
      }
      if (/^[-*] /.test(line.trim())) {
        flushP(buf);
        html += "<ul>";
        while (i < lines.length && /^[-*] /.test(lines[i].trim())) {
          html += `<li>${inline(lines[i].trim().slice(2))}</li>`;
          i += 1;
        }
        html += "</ul>";
        continue;
      }
      buf.push(line.trim());
      i += 1;
    }
    flushP(buf);
    return html;
  }

  function mdRico(md) {
    const t = String(md || "");
    return (t.match(/^## /gm) || []).length >= 2 && t.length > 500;
  }

  function escenasDeMd(md, titulo) {
    const parts = String(md).replace(/\r\n/g, "\n").trim().split(/\n(?=## )/);
    return parts.map((part, i) => {
      const lines = part.split("\n");
      let title = titulo;
      let body = part;
      const head = lines[0] || "";
      if (head.startsWith("# ")) {
        title = head.replace(/^#\s+/, "");
        body = lines.slice(1).join("\n");
      } else if (head.startsWith("## ")) {
        title = head.replace(/^##\s+/, "");
        body = lines.slice(1).join("\n");
      }
      return {
        id: "cap-" + i,
        kicker: i === 0 ? "Introducción" : `Capítulo ${i}`,
        title,
        html: `<div class="prosa">${mdToHtml(body)}</div>`,
      };
    });
  }

  function obtenerDescripcionProceso(proceso, item) {
    if (proceso.descripcion && proceso.descripcion.queEs) {
      return proceso.descripcion;
    }
    const nombre = proceso.nombre || item.nombre || "Módulo";
    const resumen = proceso.resumen || item.resumen || "";
    return {
      queEs: `Módulo central del sistema Qrystalos especializado en la gestión, control y registro de operaciones de ${nombre}.`,
      paraQueSirve:
        resumen ||
        `Permite a los usuarios autorizados ejecutar las actividades operativas del ciclo de ${nombre}, manteniendo la consistencia de datos y el cumplimiento de las políticas institucionales.`,
      proposito: `Garantizar la agilidad operativa, la conciliación exacta de la información y la trazabilidad institucional en tiempo real para auditoría y toma de decisiones.`,
    };
  }

  function renderDescripcionProceso(desc) {
    return `
      <div class="proceso-descripcion-card">
        <div class="desc-bloque desc-bloque--que">
          <div class="desc-tag">
            <span class="desc-tag-icon">ℹ️</span>
            <strong>¿Qué es?</strong>
          </div>
          <p class="desc-texto">${esc(desc.queEs)}</p>
        </div>
        <div class="desc-bloque desc-bloque--para">
          <div class="desc-tag">
            <span class="desc-tag-icon">🎯</span>
            <strong>¿Para qué se usa?</strong>
          </div>
          <p class="desc-texto">${esc(desc.paraQueSirve)}</p>
        </div>
        <div class="desc-bloque desc-bloque--proposito">
          <div class="desc-tag">
            <span class="desc-tag-icon">🏆</span>
            <strong>¿Cuál es su propósito?</strong>
          </div>
          <p class="desc-texto">${esc(desc.proposito)}</p>
        </div>
      </div>
    `;
  }

  function svgIcon(nombre, size = 20) {
    const mapa = {
      computer: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>`,
      folder_special: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path><polygon points="12 11 13.5 14.5 17 14.5 14 16.5 15.5 20 12 17.5 8.5 20 10 16.5 7 14.5 10.5 14.5 12 11" fill="currentColor" stroke="none"></polygon></svg>`,
      folder: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>`,
      folder_open: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path><path d="M2 10h20"></path></svg>`,
      desktop_windows: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="12" y1="17" x2="12" y2="21"></line><line x1="8" y1="21" x2="16" y2="21"></line></svg>`,
      add_circle: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>`,
      download: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>`,
      cloud_upload: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4M12 12v9"></path><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"></path></svg>`,
      call_split: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 3 21 3 21 8"></polyline><line x1="4" y1="20" x2="21" y2="3"></line><polyline points="21 16 21 21 16 21"></polyline><line x1="15" y1="15" x2="21" y2="21"></line><line x1="4" y1="4" x2="9" y2="9"></line></svg>`,
      check_circle: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>`,
      touch_app: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3"></path></svg>`,
      task_alt: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"></path><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path></svg>`,
      done_all: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline><polyline points="20 12 14.5 17.5"></polyline></svg>`,
      lock_open: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 9.9-1"></path></svg>`,
      lock: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>`,
      payments: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>`,
      trending_down: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 18 13.5 8.5 8.5 13.5 1 6"></polyline><polyline points="17 18 23 18 23 12"></polyline></svg>`,
      account_balance: `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="21" x2="21" y2="21"></line><line x1="3" y1="10" x2="21" y2="10"></line><polyline points="12 3 2 10 22 10 12 3"></polyline><line x1="5" y1="10" x2="5" y2="21"></line><line x1="9" y1="10" x2="9" y2="21"></line><line x1="15" y1="10" x2="15" y2="21"></line><line x1="19" y1="10" x2="19" y2="21"></line></svg>`,
    };
    return mapa[nombre] || mapa.touch_app;
  }

  function renderMapaMentalAcceso(proceso) {
    const v0 = (proceso.ventanas && proceso.ventanas[0]) || {};
    let rutaLimpia = v0.entrada || v0.uso || "Administrativo → Módulo";
    rutaLimpia = rutaLimpia.replace(/VALIDA_[^)]*\)/g, "").replace(/\(.*?\)/g, "").trim();

    let partes = rutaLimpia.includes("→")
      ? rutaLimpia.split("→").map((s) => s.trim())
      : ["Administrativo", proceso.familia ? familiaNombre(proceso.familia) : "Módulo", proceso.nombre];

    const limpiarNombreNodo = (s) => {
      if (!s) return "";
      let limpio = s.split(/[.\n;]/)[0].trim();
      limpio = limpio.replace(/^(Grilla\s+maestro|Maestro|Di[aá]logo|Componente)\s+/i, "");
      limpio = limpio.replace(/\b[A-Z]{3,8}(Component|Page)\b/g, "");
      return limpio.trim();
    };

    const menuPpal = limpiarNombreNodo(partes[0]) || "Administrativo";
    let submenu = limpiarNombreNodo(partes[1]) || (proceso.familia ? familiaNombre(proceso.familia) : "Operación");
    let pantalla = limpiarNombreNodo(partes[2]);

    if (!pantalla) {
      if (proceso.nombre && proceso.nombre.includes("·")) {
        pantalla = proceso.nombre.split("·")[1].trim();
      } else {
        pantalla = proceso.nombre || "Pantalla de Trabajo";
      }
    }
    if (!submenu || submenu.toLowerCase() === pantalla.toLowerCase()) {
      submenu = proceso.familia ? familiaNombre(proceso.familia) : "Gestión";
    }

    const urlPantalla = v0.path || "/admin";

    let ramasAcciones = [];
    if (proceso.id === "recaudos") {
      ramasAcciones = [
        { icon: "add_circle", label: "Nuevo Recaudo", desc: "Crear cabecera con tercero, ingreso y fecha" },
        { icon: "download", label: "Asignar Facturas", desc: "Vincular facturas pendientes de la CxC" },
        { icon: "cloud_upload", label: "Carga Masiva", desc: "Subir plantilla Excel de pagos o glosas" },
        { icon: "call_split", label: "Consignaciones ADRES", desc: "Distribuir giros institucionales" },
        { icon: "check_circle", label: "Aplicar Pago", desc: "Cierre, descuento en cartera y asiento contable" },
      ];
    } else if (proceso.id === "caja") {
      ramasAcciones = [
        { icon: "lock_open", label: "Apertura de Turno", desc: "Validar cajero, equipo UBEQ, CXT y abrir sesión ACJ" },
        { icon: "download", label: "Traer Recibo", desc: "Importar cobros asistenciales pendientes desde TFCJ" },
        { icon: "payments", label: "Medios de Pago", desc: "Liquidar efectivo, datáfono, tarjetas a cuotas y cheques" },
        { icon: "trending_down", label: "Egresos y Caja Menor", desc: "Gastos menores, devolución de copagos y traslados" },
        { icon: "account_balance", label: "Consignación y Bancos", desc: "Afectación de saldo BCT y depósitos de efectivo" },
        { icon: "lock", label: "Cierre y Reembolso", desc: "Arqueo de turno, cierre de sesión y reembolso CMREE/FCXP" },
      ];
    } else {
      ramasAcciones = (proceso.ventanas || []).slice(0, 4).map((v) => ({
        icon: "touch_app",
        label: v.uso ? v.uso.replace(/\(.*?\)/g, "").trim() : "Operación",
        desc: v.path || "Acceso de trabajo",
      }));
      if (!ramasAcciones.length) {
        ramasAcciones = [
          { icon: "add_circle", label: "Registro Inicial", desc: "Crear o consultar documento" },
          { icon: "task_alt", label: "Validación", desc: "Revisión de requisitos y candados" },
          { icon: "done_all", label: "Confirmación", desc: "Cierre y contabilización formal" },
        ];
      }
    }

    const hojasHtml = ramasAcciones
      .map(
        (a) => `
      <div class="mm-hoja-card">
        <div class="mm-hoja-ico-wrap">${svgIcon(a.icon, 18)}</div>
        <div class="mm-hoja-content">
          <strong class="mm-hoja-label">${esc(a.label)}</strong>
          <p class="mm-hoja-desc">${esc(a.desc)}</p>
        </div>
      </div>
    `
      )
      .join("");

    return `
      <div class="mapa-mental-wrap">
        <div class="mm-cabecera">
          <div class="mm-cabecera-tit">
            <span class="mm-cabecera-ico">🧠</span>
            <strong>Ruta de Acceso al Sistema (Mapa de Navegación)</strong>
          </div>
          <span class="mm-cabecera-sub">Siga esta ruta en los menús de Qrystalos para ingresar a la pantalla de trabajo:</span>
        </div>

        <!-- Nivel 1: Ruta en 4 pasos conectados horizontalmente (100% ancho, sin scroll) -->
        <div class="mm-ruta-stepper">
          <div class="mm-paso-card mm-paso-card--sistema">
            <div class="mm-paso-ico">${svgIcon("computer", 22)}</div>
            <div class="mm-paso-info">
              <span class="mm-paso-nivel">Nivel 0 · Sistema</span>
              <strong class="mm-paso-nombre">Qrystalos ERP</strong>
            </div>
          </div>

          <div class="mm-conector">➜</div>

          <div class="mm-paso-card mm-paso-card--menu">
            <div class="mm-paso-ico">${svgIcon("folder_special", 22)}</div>
            <div class="mm-paso-info">
              <span class="mm-paso-nivel">Nivel 1 · Menú</span>
              <strong class="mm-paso-nombre">${esc(menuPpal)}</strong>
            </div>
          </div>

          <div class="mm-conector">➜</div>

          <div class="mm-paso-card mm-paso-card--sub">
            <div class="mm-paso-ico">${svgIcon("folder_open", 22)}</div>
            <div class="mm-paso-info">
              <span class="mm-paso-nivel">Nivel 2 · Submódulo</span>
              <strong class="mm-paso-nombre">${esc(submenu)}</strong>
            </div>
          </div>

          <div class="mm-conector">➜</div>

          <div class="mm-paso-card mm-paso-card--pantalla">
            <div class="mm-paso-ico">${svgIcon("desktop_windows", 22)}</div>
            <div class="mm-paso-info">
              <span class="mm-paso-nivel">Nivel 3 · Pantalla</span>
              <strong class="mm-paso-nombre">${esc(pantalla)}</strong>
              <span class="mm-paso-url">${esc(urlPantalla)}</span>
            </div>
          </div>
        </div>

        <!-- Nivel 2: Acciones Principales dentro de la pantalla (debajo, sin scroll horizontal) -->
        <div class="mm-acciones-seccion">
          <div class="mm-acciones-cabecera">
            <div class="mm-acciones-tit-box">
              <span class="mm-acciones-punto">⚡</span>
              <strong class="mm-acciones-titulo">Acciones Principales en Pantalla (${esc(pantalla)}):</strong>
            </div>
            <span class="mm-acciones-sub">Operaciones y botones más frecuentes del usuario</span>
          </div>
          <div class="mm-acciones-grid">
            ${hojasHtml}
          </div>
        </div>
      </div>
    `;
  }

  function obtenerBotonesProceso(proceso) {
    if (proceso.botones && Array.isArray(proceso.botones) && proceso.botones.length > 0) {
      return proceso.botones;
    }

    const CATALOGO_BOTONES = {
      facturacion: [
        {
          label: "Nueva Factura",
          icono: "receipt_long",
          color: "primary",
          estilo: "outline",
          descripcion: "Inicia el asistente para liquidar y generar una nueva factura manual, por evento o por cita médica.",
        },
        {
          label: "Encolar DIAN",
          icono: "send",
          color: "positive",
          estilo: "outline",
          descripcion: "Encola la factura para su transmisión electrónica formal y validación previa ante la DIAN.",
        },
        {
          label: "Liberar",
          icono: "lock_open",
          color: "warning",
          estilo: "outline",
          descripcion: "Libera los cargos y atenciones asistenciales de la factura para permitir su refacturación sin perder servicios.",
        },
        {
          label: "Anular / NC",
          icono: "block",
          color: "negative",
          estilo: "outline",
          descripcion: "Anula la factura en el sistema o emite una Nota Crédito electrónica si ya fue validada ante la DIAN.",
        },
        {
          label: "Imprimir",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera la representación gráfica oficial de la factura electrónica en formato PDF institucional.",
        },
        {
          label: "Anexo Detallado",
          icono: "description",
          color: "indigo",
          estilo: "outline",
          descripcion: "Descarga e imprime el anexo clínico-administrativo con el desglose de procedimientos y medicamentos.",
        },
        {
          label: "Generar RIPS",
          icono: "code",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Genera y valida la estructura JSON de RIPS según la Resolución 2275 para reporte a MinSalud.",
        },
        {
          label: "Exportar Excel",
          icono: "file_download",
          color: "green-7",
          estilo: "outline",
          descripcion: "Descarga la sábana completa de facturación con desglose de ítems, impuestos y valores a Excel.",
        },
        {
          label: "Log Factura",
          icono: "history",
          color: "blue-grey",
          estilo: "outline",
          descripcion: "Muestra la bitácora completa de auditoría: quién facturó, fechas de envío DIAN y cambios de estado.",
        },
      ],
      caja: [
        {
          label: "Abrir / Cerrar Caja",
          icono: "lock_open",
          color: "positive",
          estilo: "outline",
          descripcion: "Valida la terminal UBEQ, cajero CJR y turno CXT para abrir sesión ACJ o ejecutar el arqueo y cierre formal.",
        },
        {
          label: "Nuevo Recibo",
          icono: "payments",
          color: "teal-7",
          estilo: "unelevated",
          descripcion: "Registra un cobro directo asignando paciente/tercero y conceptos de ingreso en FCJ.",
        },
        {
          label: "Traer Recibo",
          icono: "download",
          color: "teal-10",
          estilo: "outline",
          descripcion: "Importa atenciones médicas pendientes desde TFCJ (citas o autorizaciones) para convertirlas en FCJ.",
        },
        {
          label: "Devolver Recibo",
          icono: "undo",
          color: "blue-grey",
          estilo: "outline",
          descripcion: "Revierte la importación de un recibo asistencial no pagado, devolviéndolo a la cola temporal TFCJ.",
        },
        {
          label: "Confirmar Recibo",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Sella el recibo FCJ, valida medios de pago PCJ, actualiza bancos BCT y genera asiento contable MCP.",
        },
        {
          label: "Desechar Ingreso",
          icono: "delete_outline",
          color: "negative",
          estilo: "outline",
          descripcion: "Elimina de la base de datos el recibo FCJ abierto antes de confirmarse, limpiando sus conceptos y formas de pago.",
        },
        {
          label: "Agregar Medio de Pago",
          icono: "credit_card",
          color: "primary",
          estilo: "outline",
          descripcion: "Agrega formas de pago PCJ: efectivo, vouchers de datáfono, tarjetas institucionales con cuotas o cheques.",
        },
        {
          label: "Mov. Egreso",
          icono: "arrow_upward",
          color: "warning",
          estilo: "outline",
          descripcion: "Registra una salida de dinero en efectivo por gastos de caja menor, devolución de copagos o traslados.",
        },
        {
          label: "Confirmar Egreso",
          icono: "done_all",
          color: "warning",
          estilo: "unelevated",
          descripcion: "Sella el egreso de caja y causa el comprobante contable de salida (MCP/MCH de egreso).",
        },
        {
          label: "Imprimir Recibo",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el comprobante impreso en tirilla POS o formato carta para entrega física al usuario.",
        },
        {
          label: "Anular Recibo",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Anula un recibo confirmado desde /admin/procaja, reversa bancos BCT y genera contrasiento contable.",
        },
        {
          label: "Enviar a Contabilidad",
          icono: "account_balance",
          color: "indigo",
          estilo: "outline",
          descripcion: "Contabiliza por lote los recibos de caja que no fueron procesados en línea durante el turno.",
        },
        {
          label: "Procesos de Caja",
          icono: "dashboard",
          color: "deep-purple",
          estilo: "unelevated",
          descripcion: "Consola central de supervisión y auditoría (/admin/procaja): 12 pestañas para cierres, reimpresión, anulación masiva y seguimiento contable.",
        },
      ],
      recaudos: [
        {
          label: "Nuevo Recaudo",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Abre el formulario para registrar una nueva cabecera indicando tercero, fecha e ingreso.",
        },
        {
          label: "Guardar",
          icono: "save",
          color: "teal-7",
          estilo: "unelevated",
          descripcion: "Guarda los cambios de cabecera o de los datos editados en el recaudo activo.",
        },
        {
          label: "Traer Varias",
          icono: "download",
          color: "primary",
          estilo: "outline",
          descripcion: "Abre la ventana de selección de facturas pendientes de la cuenta por cobrar del cliente.",
        },
        {
          label: "Aplicar Pago",
          icono: "check_circle",
          color: "positive",
          estilo: "outline",
          descripcion: "Aplica el recaudo a las facturas, descuenta cartera y genera el comprobante contable.",
        },
        {
          label: "Desaplicar",
          icono: "undo",
          color: "warning",
          estilo: "outline",
          descripcion: "Reabre el recaudo cerrado para permitir adiciones o correcciones de facturas.",
        },
        {
          label: "Anular",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Anula completamente el recaudo, cancelando sus efectos contables y en cartera.",
        },
        {
          label: "Consig. Adres",
          icono: "call_split",
          color: "deep-orange",
          estilo: "outline",
          descripcion: "Abre la ventana para conciliar y distribuir giros directos de ADRES a las facturas.",
        },
        {
          label: "Cruce CXP",
          icono: "folder_open",
          color: "indigo-10",
          estilo: "outline",
          descripcion: "Permite cruzar valores del recaudo contra cuentas por pagar vigentes con el mismo tercero.",
        },
        {
          label: "Exportar Excel",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Descarga los datos filtrados en la tabla hacia un archivo Excel de auditoría.",
        },
      ],
      glosas: [
        {
          label: "Recepcionar Glosa",
          icono: "assignment_returned",
          color: "purple",
          estilo: "outline",
          descripcion: "Registra formalmente la notificación de objeción radicada por la EPS o aseguradora.",
        },
        {
          label: "Enviar a Auditoría",
          icono: "send",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Traslada el expediente a los médicos auditores para la revisión de soportes y pertinencia clínica.",
        },
        {
          label: "Responder Glosa",
          icono: "check_circle",
          color: "positive",
          estilo: "outline",
          descripcion: "Asienta la respuesta institucional detallada, registrando los valores aceptados y no aceptados.",
        },
        {
          label: "Conciliar Glosa",
          icono: "handshake",
          color: "indigo",
          estilo: "outline",
          descripcion: "Formaliza acuerdos de mesas de trabajo conjuntas entre la institución prestadora y el pagador.",
        },
        {
          label: "Generar Nota Crédito",
          icono: "receipt",
          color: "deep-orange",
          estilo: "outline",
          descripcion: "Aplica el descuento contable y en cartera correspondiente a los valores de glosa aceptados.",
        },
        {
          label: "Historial de Glosa",
          icono: "history",
          color: "blue",
          estilo: "outline",
          descripcion: "Consulta la trazabilidad completa de objeciones, respuestas y ratificaciones de la factura.",
        },
        {
          label: "Exportar Informe",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Descarga la sábana analítica de glosas por estado, motivo, servicio y pagador a Excel.",
        },
      ],
      "notas-dbcr": [
        {
          label: "Nueva Nota",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Inicia el registro de una nueva Nota Débito o Nota Crédito para ajuste de valores.",
        },
        {
          label: "Traer Factura",
          icono: "search",
          color: "primary",
          estilo: "outline",
          descripcion: "Busca y selecciona la factura radicada sobre la cual se aplicará el ajuste comercial o contable.",
        },
        {
          label: "Aplicar Nota",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Cierra la nota, actualiza el saldo de la cartera y genera el asiento contable respectivo.",
        },
        {
          label: "Desaplicar Nota",
          icono: "undo",
          color: "warning",
          estilo: "outline",
          descripcion: "Reabre la nota para corrección de valores o motivos si el periodo contable se mantiene abierto.",
        },
        {
          label: "Anular Nota",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Invalida la nota y devuelve el saldo de la factura a su valor previo a la transacción.",
        },
        {
          label: "Notificar DIAN",
          icono: "send",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Transmite la nota electrónica a la DIAN para validación previa y asignación de CUDE.",
        },
        {
          label: "Imprimir Soporte",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el formato PDF institucional de la Nota Débito/Crédito con desglose de conceptos.",
        },
        {
          label: "Exportar Excel",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Descarga el reporte detallado de notas aplicadas en el rango de fechas seleccionado.",
        },
      ],
      conciliaciones: [
        {
          label: "Nueva Conciliación",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Crea una nueva acta de conciliación de saldos con un pagador a una fecha de corte específica.",
        },
        {
          label: "Cargar Cartera",
          icono: "download",
          color: "primary",
          estilo: "outline",
          descripcion: "Extrae todas las facturas y saldos de la cuenta por cobrar del tercero para cotejo.",
        },
        {
          label: "Subir Archivo EPS",
          icono: "cloud_upload",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Importa la plantilla o extracto enviado por la EPS para cruce automatizado de saldos.",
        },
        {
          label: "Cruzar Facturas",
          icono: "compare_arrows",
          color: "indigo",
          estilo: "outline",
          descripcion: "Ejecuta el motor de coincidencias, identificando pagos cruzados, diferencias y saldos pendientes.",
        },
        {
          label: "Cerrar Acta",
          icono: "verified",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Formaliza el acta de conciliación de cartera y fija los saldos pactados entre ambas partes.",
        },
        {
          label: "Exportar Informe",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Descarga la matriz de conciliación con diferencias y acuerdos hacia una hoja de cálculo.",
        },
      ],
      bancos: [
        {
          label: "Nuevo Movimiento",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra una consignación, transferencia, nota bancaria o débito en la cuenta corriente.",
        },
        {
          label: "Confirmar Movimiento",
          icono: "task_alt",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Valida la entrada efectiva del dinero, dejándolo disponible para su legalización en Recaudos.",
        },
        {
          label: "Conciliar Extracto",
          icono: "sync_alt",
          color: "indigo",
          estilo: "outline",
          descripcion: "Coteja los movimientos registrados en libros contra el extracto bancario oficial del mes.",
        },
        {
          label: "Distribuir ADRES",
          icono: "call_split",
          color: "deep-orange",
          estilo: "outline",
          descripcion: "Distribuye los giros institucionales de ADRES a las cuentas y facturas de la entidad.",
        },
        {
          label: "Anular Movimiento",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Anula el registro bancario que no haya sido utilizado o confirmado en operaciones posteriores.",
        },
        {
          label: "Imprimir Comprobante",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Emite el recibo o volante oficial de movimiento de tesorería y comprobante bancario.",
        },
      ],
      "cxp-fcxp": [
        {
          label: "Radicar Factura Proveedor",
          icono: "receipt",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra la factura de compras, honorarios o servicios con retenciones e impuestos aplicables.",
        },
        {
          label: "Validar Radian",
          icono: "verified",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Verifica acuse de recibo, recepción de bienes/servicios y aceptación como título valor en Radian.",
        },
        {
          label: "Causar / Aprobar",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Genera la obligación contable en el pasivo y habilita la factura para programación de pagos.",
        },
        {
          label: "Programar Pago",
          icono: "event",
          color: "warning",
          estilo: "outline",
          descripcion: "Incluye la cuenta por pagar en la orden semanal o quincenal de desembolsos a proveedores.",
        },
        {
          label: "Anular Radicación",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Reversa la causación por devolución del soporte comercial o inconsistencias de facturación.",
        },
        {
          label: "Imprimir Comprobante",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Descarga el soporte de causación contable con afectación de cuentas por pagar y retenciones.",
        },
      ],
      "activos-fijos": [
        {
          label: "Alta de Activo",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra un nuevo bien tangible con placa, serial, responsable, centro de costo y vida útil.",
        },
        {
          label: "Traslado de Activo",
          icono: "swap_horiz",
          color: "primary",
          estilo: "outline",
          descripcion: "Asigna el activo fijo a un nuevo custodio, departamento, consultorio o sede institucional.",
        },
        {
          label: "Ejecutar Depreciación",
          icono: "calculate",
          color: "indigo",
          estilo: "outline",
          descripcion: "Calcula y contabiliza la alícuota mensual de depreciación bajo normas fiscales y NIIF.",
        },
        {
          label: "Evento Mantenimiento",
          icono: "build",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Registra mantenimientos preventivos, correctivos, calibraciones biomédicas y garantías.",
        },
        {
          label: "Baja de Activo",
          icono: "delete_forever",
          color: "negative",
          estilo: "outline",
          descripcion: "Registra la baja definitiva del bien por obsolescencia, daño irreparable o venta con asiento contable.",
        },
        {
          label: "Hoja de Vida",
          icono: "badge",
          color: "blue",
          estilo: "outline",
          descripcion: "Imprime el historial completo del equipo con valores de compra, depreciación acumulada y eventos.",
        },
      ],
      contabilidad: [
        {
          label: "Nuevo Asiento",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Crea un comprobante manual de diario, ajuste, provisión, nómina o reclasificación contable.",
        },
        {
          label: "Asignar Cuentas",
          icono: "account_balance",
          color: "primary",
          estilo: "outline",
          descripcion: "Digita las cuentas del PUC/NIIF, débitos, créditos, centros de costo y NIT de contrapartida.",
        },
        {
          label: "Confirmar Comprobante",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Asienta definitivamente el comprobante, actualizando libros auxiliares y balances mayores.",
        },
        {
          label: "Reabrir Comprobante",
          icono: "lock_open",
          color: "warning",
          estilo: "outline",
          descripcion: "Permite corregir líneas de un asiento desbalanceado si el periodo contable sigue abierto.",
        },
        {
          label: "Anular Comprobante",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Genera el contrasiento de anulación automática garantizando la trazabilidad histórica.",
        },
        {
          label: "Balance de Prueba",
          icono: "table_chart",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Genera el balance de comprobación de sumas y saldos por cuentas a nivel analítico.",
        },
        {
          label: "Cierre de Periodo",
          icono: "calendar_month",
          color: "deep-orange",
          estilo: "outline",
          descripcion: "Bloquea el mes o año contable para impedir registros o modificaciones extemporáneas.",
        },
      ],
      radicaciones: [
        {
          label: "Nuevo Lote",
          icono: "create_new_folder",
          color: "positive",
          estilo: "outline",
          descripcion: "Crea una agrupación de facturas por cliente o contrato para radicación formal unificada.",
        },
        {
          label: "Asignar Facturas",
          icono: "playlist_add",
          color: "primary",
          estilo: "outline",
          descripcion: "Vincula las facturas auditadas con sus archivos RIPS validados y soportes clínicos.",
        },
        {
          label: "Radicar Lote",
          icono: "send",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Asienta el número oficial de radicado asignado por la aseguradora y fija fecha de vencimiento.",
        },
        {
          label: "Imprimir Planilla",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el acta de entrega y relación física de facturas para firma y sello de recepción.",
        },
        {
          label: "Desarmar Lote",
          icono: "undo",
          color: "warning",
          estilo: "outline",
          descripcion: "Retira facturas con glosas o inconsistencias antes del cierre final de la radicación.",
        },
        {
          label: "Exportar Relación",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Descarga la relación de facturas radicadas con valores, pacientes y diagnósticos a Excel.",
        },
      ],
      "incapacidades-pila": [
        {
          label: "Cargar Planilla PILA",
          icono: "cloud_upload",
          color: "primary",
          estilo: "outline",
          descripcion: "Importa el archivo plano de autoliquidación de aportes PILA para validación de cotizantes.",
        },
        {
          label: "Validar Registros",
          icono: "fact_check",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Coteja número de documento, días cotizados e IBC con la base de datos de incapacidades.",
        },
        {
          label: "Cruzar Incapacidades",
          icono: "compare_arrows",
          color: "indigo",
          estilo: "outline",
          descripcion: "Cruza las novedades médicas reportadas contra los aportes efectivos realizados al sistema.",
        },
        {
          label: "Asignar Estado",
          icono: "rule",
          color: "warning",
          estilo: "outline",
          descripcion: "Actualiza el semáforo de cobro: En trámite, Aprobada por EPS o Pendiente por empleador.",
        },
        {
          label: "Confirmar Pago",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Registra el abono del subsidio por incapacidad temporal emitido por la entidad de seguridad social.",
        },
        {
          label: "Exportar Relación",
          icono: "file_download",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Genera el reporte consolidado de novedades PILA e incapacidades cobradas a Excel.",
        },
      ],
      inventario: [
        {
          label: "Entrada por Compra",
          icono: "add_shopping_cart",
          color: "positive",
          estilo: "outline",
          descripcion: "Ingresa insumos o medicamentos desde una orden de compra, calculando costo promedio ponderado.",
        },
        {
          label: "Salida / Consumo",
          icono: "output",
          color: "warning",
          estilo: "outline",
          descripcion: "Registra la entrega de materiales a servicios asistenciales, quirófanos o centros de costo.",
        },
        {
          label: "Traslado Bodegas",
          icono: "swap_horiz",
          color: "primary",
          estilo: "outline",
          descripcion: "Transfiere existencias entre la bodega central y las farmacias o depósitos satélite.",
        },
        {
          label: "Confirmar Movimiento",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Aplica formalmente el movimiento, actualizando saldos de kardex físico y contable.",
        },
        {
          label: "Ajuste Inventario",
          icono: "tune",
          color: "indigo",
          estilo: "outline",
          descripcion: "Ajusta sobrantes o faltantes resultantes de tomas físicas periódicas de inventario.",
        },
        {
          label: "Kardex de Artículo",
          icono: "history",
          color: "blue",
          estilo: "outline",
          descripcion: "Muestra la trazabilidad detallada de entradas, salidas, saldo actual, lote y fecha de vencimiento.",
        },
      ],
      dispensacion: [
        {
          label: "Atender Solicitud",
          icono: "receipt_long",
          color: "primary",
          estilo: "outline",
          descripcion: "Carga la prescripción médica de medicamentos o insumos generada en la historia clínica.",
        },
        {
          label: "Despachar Insumos",
          icono: "medication",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Confirma los lotes, valida semáforos de vencimiento y descuenta existencias de farmacia.",
        },
        {
          label: "Devolución a Farmacia",
          icono: "assignment_return",
          color: "warning",
          estilo: "outline",
          descripcion: "Reingresa al stock institucional medicamentos no administrados por suspensión médica.",
        },
        {
          label: "Pendientes Entrega",
          icono: "pending_actions",
          color: "deep-orange",
          estilo: "outline",
          descripcion: "Monitorea medicamentos formulados no despachados por desabastecimiento temporal de stock.",
        },
        {
          label: "Imprimir Rótulo",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera la etiqueta de dosificación con nombre del paciente, horario y vía de administración.",
        },
        {
          label: "Historial Solicitud",
          icono: "history",
          color: "blue-grey",
          estilo: "outline",
          descripcion: "Revisa quién despachó, fecha y hora de entrega y devoluciones registradas al paciente.",
        },
      ],
      presupuesto: [
        {
          label: "Nuevo Rubro",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Crea una cuenta presupuestal de ingresos o gastos en el catálogo institucional.",
        },
        {
          label: "Expedir CDP",
          icono: "verified",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Expide el Certificado de Disponibilidad Presupuestal reservando saldo para contratación.",
        },
        {
          label: "Expedir RP",
          icono: "assignment",
          color: "indigo",
          estilo: "outline",
          descripcion: "Genera el Registro Presupuestal comprometiendo formalmente la apropiación ante el contrato.",
        },
        {
          label: "Reconocimiento",
          icono: "trending_up",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Registra el derecho exigible de cobro de ingresos reconocidos por facturación o convenios.",
        },
        {
          label: "Traslado / Adición",
          icono: "sync_alt",
          color: "warning",
          estilo: "outline",
          descripcion: "Aplica modificaciones presupuestales entre rubros mediante decreto o resolución oficial.",
        },
        {
          label: "Ejecución Presupuestal",
          icono: "assessment",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el estado comparativo de apropiación inicial, compromisos, obligaciones y pagos.",
        },
      ],
      "reportes-cartera": [
        {
          label: "Generar Informe",
          icono: "analytics",
          color: "primary",
          estilo: "outline",
          descripcion: "Ejecuta la consulta de saldos de cartera con filtros por fecha de corte y entidad pagadora.",
        },
        {
          label: "Filtro por Edades",
          icono: "filter_alt",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Clasifica la cartera por rangos de vencimiento: Corriente, 30, 60, 90, 180 y más de 360 días.",
        },
        {
          label: "Consolidado Tercero",
          icono: "pie_chart",
          color: "indigo",
          estilo: "outline",
          descripcion: "Agrupa los saldos totales por cada EPS, aseguradora, convenio o particular.",
        },
        {
          label: "Exportar Excel",
          icono: "file_download",
          color: "green-7",
          estilo: "outline",
          descripcion: "Descarga la sábana completa de cartera para análisis financiero y conciliación externa.",
        },
        {
          label: "Imprimir PDF",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el informe ejecutivo imprimible para comités de cartera y gerencia financiera.",
        },
      ],
      "honorarios-fxp": [
        {
          label: "Radicar Cuenta Médica",
          icono: "receipt",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra la cuenta de cobro del profesional de la salud por atenciones médicas o quirúrgicas.",
        },
        {
          label: "Validar Soportes",
          icono: "fact_check",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Coteja los procedimientos facturados contra las órdenes y notas operatorias en historia clínica.",
        },
        {
          label: "Causar Honorarios",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Genera la obligación contable y la liquidación de tarifas pactadas por contrato médico.",
        },
        {
          label: "Liquidar Retenciones",
          icono: "calculate",
          color: "indigo",
          estilo: "outline",
          descripcion: "Calcula automáticamente retención en la fuente, ICA y demás descuentos tributarios aplicables.",
        },
        {
          label: "Pago a Médico",
          icono: "payments",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Vincular el pago de honorarios a la orden de tesorería y comprobante de egreso bancario.",
        },
      ],
      "auditoria-factura": [
        {
          label: "Recibir Factura",
          icono: "inbox",
          color: "primary",
          estilo: "outline",
          descripcion: "Recibe el expediente de facturación para auditoría médica y administrativa previa a radicación.",
        },
        {
          label: "Revisar Pertinencia",
          icono: "medical_services",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Valida la justificación médica de procedimientos, medicamentos y estancias facturadas.",
        },
        {
          label: "Glosar Servicio",
          icono: "rule",
          color: "warning",
          estilo: "outline",
          descripcion: "Marca servicios objetados por falta de soportes, autorización o tarifas incorrectas.",
        },
        {
          label: "Avalar Factura",
          icono: "verified",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Otorga el visto bueno de auditoría habilitando la factura para empaque y radicación formal.",
        },
        {
          label: "Devolver a Facturación",
          icono: "assignment_return",
          color: "negative",
          estilo: "outline",
          descripcion: "Regresa la cuenta al facturador para corrección de diagnósticos, códigos o anexos faltantes.",
        },
      ],
      "custodia-medicamentos": [
        {
          label: "Entrada Custodia",
          icono: "add_box",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra el ingreso de medicamentos de alto costo entregados por el paciente o la EPS.",
        },
        {
          label: "Asignar Paciente",
          icono: "person",
          color: "primary",
          estilo: "outline",
          descripcion: "Vincula las ampollas o dosis al número de historia clínica y tratamiento del usuario.",
        },
        {
          label: "Egreso Tratamiento",
          icono: "medication",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Descarga la dosis para su aplicación en sala de quimioterapia o infusión ambulatoria.",
        },
        {
          label: "Inventario Custodia",
          icono: "inventory",
          color: "indigo",
          estilo: "outline",
          descripcion: "Consulta los medicamentos custodiados discriminados por paciente, bodega y fecha de vencimiento.",
        },
        {
          label: "Devolución Familiar",
          icono: "assignment_return",
          color: "warning",
          estilo: "outline",
          descripcion: "Entrega sobrantes no requeridos al paciente o acudiente con firma de acta de entrega.",
        },
      ],
      "aplicacion-medicamentos": [
        {
          label: "Registrar Ciclo",
          icono: "event_repeat",
          color: "primary",
          estilo: "outline",
          descripcion: "Inicia el protocolo de oncología o tratamiento programado en consulta externa.",
        },
        {
          label: "Confirmar Cita",
          icono: "event_available",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra el ingreso del paciente al sillón o camilla de infusión de medicamentos.",
        },
        {
          label: "Registrar Insumos",
          icono: "vaccines",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Asocia los catéteres, sueros, filtros y mezclas preparadas para la administración.",
        },
        {
          label: "Validar Dosis",
          icono: "health_and_safety",
          color: "indigo",
          estilo: "outline",
          descripcion: "Doble chequeo de enfermería: paciente correcto, medicamento, dosis, vía y velocidad.",
        },
        {
          label: "Registro Enfermería",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Firma la aplicación en la historia clínica digital con registro de signos vitales.",
        },
      ],
      acctran: [
        {
          label: "Registro Siniestro",
          icono: "car_crash",
          color: "positive",
          estilo: "outline",
          descripcion: "Captura los datos del accidente de tránsito, vehículo, placa, conductor y autoridad competente.",
        },
        {
          label: "Validar Póliza SOAT",
          icono: "verified",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Consulta la vigencia de la póliza SOAT en RUNT o aseguradora para cobertura de gastos.",
        },
        {
          label: "Asignar Amparo",
          icono: "healing",
          color: "primary",
          estilo: "outline",
          descripcion: "Distribuye la cobertura entre gastos médicos (hasta tope de ley) e indemnizaciones.",
        },
        {
          label: "Liquidar Gastos Médicos",
          icono: "calculate",
          color: "indigo",
          estilo: "outline",
          descripcion: "Relaciona las atenciones, cirugías y estancia médica imputadas a la póliza del siniestro.",
        },
        {
          label: "Formulario FURIPS",
          icono: "description",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el formulario oficial único de reclamación médica de accidentes de tránsito.",
        },
      ],
      "autorizaciones-ce": [
        {
          label: "Nueva Autorización",
          icono: "add",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra la autorización emitida por la aseguradora para procedimientos o consultas.",
        },
        {
          label: "Validar Derechos",
          icono: "fact_check",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Consulta el estado de afiliación, copagos y cuotas moderadoras en la base del pagador.",
        },
        {
          label: "Asignar Servicio",
          icono: "medical_services",
          color: "primary",
          estilo: "outline",
          descripcion: "Vincula los códigos CUPS autorizados con número de sesiones y vigencia de atención.",
        },
        {
          label: "Adjuntar Orden",
          icono: "attach_file",
          color: "indigo",
          estilo: "outline",
          descripcion: "Carga el soporte digital de la autorización emitida por el portal de la EPS.",
        },
        {
          label: "Autorizar Prestación",
          icono: "check_circle",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Habilita la prestación médica para que el profesional atienda y facture el servicio.",
        },
      ],
      hpre: [
        {
          label: "Cargar Prestación",
          icono: "add_box",
          color: "positive",
          estilo: "outline",
          descripcion: "Registra el consumo de servicios, insumos o medicamentos realizados en hospitalización o urgencias.",
        },
        {
          label: "Reliquidar Cargos",
          icono: "sync",
          color: "warning",
          estilo: "outline",
          descripcion: "Ajusta las tarifas pactadas por manual tarifario (SOAT / ISS / Propio) según el contrato activo.",
        },
        {
          label: "Distribuir SOAT/EPS",
          icono: "call_split",
          color: "indigo",
          estilo: "outline",
          descripcion: "Separa los cargos que cubren el tope SOAT de los excedentes que asume la EPS del paciente.",
        },
        {
          label: "Facturar Prestación",
          icono: "receipt_long",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Traslada las prestaciones cerradas y validadas hacia la cuenta de facturación del paciente.",
        },
        {
          label: "Anular Cargo",
          icono: "cancel",
          color: "negative",
          estilo: "outline",
          descripcion: "Descarga cargos duplicados o no suministrados antes del cierre definitivo de la cuenta.",
        },
      ],
      nomina: [
        {
          label: "Novedades de Personal",
          icono: "person_add",
          color: "primary",
          estilo: "outline",
          descripcion: "Registra horas extras, recargos nocturnos, incapacidades, permisos y licencias del periodo.",
        },
        {
          label: "Liquidar Nómina",
          icono: "calculate",
          color: "positive",
          estilo: "unelevated",
          descripcion: "Ejecuta el cálculo automático de devengados, deducciones de seguridad social y retenciones.",
        },
        {
          label: "Generar Prenómina",
          icono: "receipt_long",
          color: "teal-7",
          estilo: "outline",
          descripcion: "Genera el informe previo para revisión y auditoría de valores antes del cierre definitivo.",
        },
        {
          label: "Aprobar y Pagar",
          icono: "payments",
          color: "teal-10",
          estilo: "glossy",
          descripcion: "Cierra la nómina del periodo y genera el archivo plano para dispersión bancaria.",
        },
        {
          label: "Contabilizar Nómina",
          icono: "account_balance",
          color: "indigo",
          estilo: "outline",
          descripcion: "Causa los salarios, prestaciones sociales parafiscales y aportes patronales en contabilidad.",
        },
        {
          label: "Volante de Pago",
          icono: "print",
          color: "blue",
          estilo: "outline",
          descripcion: "Genera el desprendible de pago oficial para entrega digital o física a cada empleado.",
        },
      ],
    };

    // Búsqueda directa por id
    if (CATALOGO_BOTONES[proceso.id]) {
      return CATALOGO_BOTONES[proceso.id];
    }

    // Búsqueda por coincidencia en familia
    const fam = proceso.familia || "";
    if (fam === "facturacion") return CATALOGO_BOTONES.facturacion;
    if (fam === "caja") return CATALOGO_BOTONES.caja;
    if (fam === "cartera") return CATALOGO_BOTONES.recaudos;
    if (fam === "tesoreria") return CATALOGO_BOTONES.bancos;
    if (fam === "contabilidad") return CATALOGO_BOTONES.contabilidad;
    if (fam === "activos") return CATALOGO_BOTONES["activos-fijos"];
    if (fam === "inventario") return CATALOGO_BOTONES.inventario;
    if (fam === "financiero") return CATALOGO_BOTONES["cxp-fcxp"];
    if (fam === "radicaciones") return CATALOGO_BOTONES.radicaciones;
    if (fam === "auditoria") return CATALOGO_BOTONES["auditoria-factura"];
    if (fam === "presupuesto") return CATALOGO_BOTONES.presupuesto;

    // Fallback general institucional
    return [
      {
        label: "Nuevo Registro",
        icono: "add",
        color: "positive",
        estilo: "outline",
        descripcion: `Abre el formulario para registrar una nueva operación en el módulo de ${esc(proceso.nombre)}.`,
      },
      {
        label: "Guardar",
        icono: "save",
        color: "teal-7",
        estilo: "unelevated",
        descripcion: "Guarda las modificaciones y actualiza los registros en la base de datos.",
      },
      {
        label: "Consultar / Filtrar",
        icono: "search",
        color: "primary",
        estilo: "outline",
        descripcion: "Filtra los datos por fechas, estados o criterios de búsqueda específicos.",
      },
      {
        label: "Confirmar / Procesar",
        icono: "check_circle",
        color: "positive",
        estilo: "outline",
        descripcion: "Valida requisitos y ejecuta el cierre formal de la transacción en el sistema.",
      },
      {
        label: "Anular",
        icono: "cancel",
        color: "negative",
        estilo: "outline",
        descripcion: "Anula la transacción activa siempre que el usuario cuente con autorización.",
      },
      {
        label: "Exportar Excel",
        icono: "file_download",
        color: "teal-10",
        estilo: "glossy",
        descripcion: "Descarga los registros visibles en la pantalla hacia un archivo de hoja de cálculo.",
      },
    ];
  }

  // Paleta Quasar (nombre → hex) para pintar los botones con el color real aunque no exista clase CSS.
  const QRYS_PALETA = {
    primary: "#1976d2", secondary: "#26a69a", accent: "#9c27b0", positive: "#21ba45", negative: "#c10015",
    warning: "#f2c037", info: "#31ccec", dark: "#1d1d1d",
    red: "#f44336", "red-8": "#d32f2f", "red-9": "#c62828", "red-10": "#b71c1c",
    pink: "#e91e63", purple: "#9c27b0", "purple-8": "#6a1b9a", "purple-9": "#4a148c", "deep-purple": "#673ab7",
    indigo: "#3f51b5", "indigo-8": "#303f9f", "indigo-9": "#283593", "indigo-10": "#1a237e",
    blue: "#2196f3", "blue-8": "#1976d2", "blue-9": "#1565c0", "blue-10": "#0d47a1", "light-blue": "#03a9f4", cyan: "#00bcd4",
    teal: "#009688", "teal-7": "#00796b", "teal-8": "#00796b", "teal-9": "#00695c", "teal-10": "#004d40",
    green: "#4caf50", "green-7": "#388e3c", "green-8": "#2e7d32", "green-9": "#1b5e20", "green-10": "#1b5e20", "light-green": "#8bc34a",
    lime: "#cddc39", yellow: "#ffeb3b", amber: "#ffc107",
    orange: "#ff9800", "orange-8": "#ef6c00", "orange-9": "#e65100", "orange-10": "#e65100", "deep-orange": "#ff5722",
    brown: "#795548", grey: "#9e9e9e", "grey-7": "#616161", "grey-8": "#424242", "grey-9": "#212121", "blue-grey": "#607d8b",
  };

  // Font Awesome → Material Icons (los libros antiguos guardaron clases FA; el visor solo carga Material Icons).
  const QRYS_FA_A_MATERIAL = {
    plus: "add", minus: "remove", xmark: "close", x: "close", times: "close", check: "check", "check-circle": "check_circle",
    "circle-check": "check_circle", "times-circle": "cancel", "circle-xmark": "cancel", ban: "block", trash: "delete",
    "trash-can": "delete", edit: "edit", pen: "edit", pencil: "edit", "pen-to-square": "edit", save: "save", "floppy-disk": "save",
    search: "search", "magnifying-glass": "search", eye: "visibility", print: "print", download: "download", upload: "upload",
    "file-arrow-up": "upload_file", "file-arrow-down": "file_download", "file-export": "file_download", "file-import": "file_upload",
    "file-excel": "table_view", "file-pdf": "picture_as_pdf", "file-alt": "description", "file-lines": "description", file: "description",
    "file-invoice": "receipt_long", "file-invoice-dollar": "request_quote", "file-shield": "verified_user", "file-circle-xmark": "cancel",
    "file-circle-plus": "note_add", "file-circle-check": "task", folder: "folder", cogs: "settings", cog: "settings", gear: "settings",
    gears: "settings", wrench: "build", "chart-bar": "bar_chart", "chart-line": "show_chart", "chart-pie": "pie_chart",
    "sack-dollar": "payments", "money-bill": "payments", "money-bill-transfer": "currency_exchange", "money-bill-wave": "payments",
    "hand-holding-dollar": "price_check", "dollar-sign": "attach_money", coins: "paid", wallet: "account_balance_wallet",
    "building-columns": "account_balance", "credit-card": "credit_card", receipt: "receipt", "cash-register": "point_of_sale",
    rotate: "sync", sync: "sync", "arrows-rotate": "sync", undo: "undo", redo: "redo", clone: "content_copy", copy: "content_copy",
    "paper-plane": "send", lock: "lock", unlock: "lock_open", "lock-open": "lock_open", key: "key", "id-badge": "badge", "id-card": "badge",
    percent: "percent", percentage: "percent", reply: "reply", share: "share", "hourglass-half": "hourglass_top", hourglass: "hourglass_top",
    clock: "schedule", calendar: "event", "calendar-days": "event", "list-check": "checklist", list: "list", "list-ul": "list",
    bars: "menu", table: "table_chart", filter: "filter_alt", link: "link", envelope: "mail", user: "person", users: "group",
    "user-plus": "person_add", "exclamation-triangle": "warning", "triangle-exclamation": "warning", "info-circle": "info",
    "circle-info": "info", "arrow-left": "arrow_back", "arrow-right": "arrow_forward", "arrow-up": "arrow_upward",
    "arrow-down": "arrow_downward", "right-left": "swap_horiz", "arrow-right-arrow-left": "swap_horiz", home: "home",
    "sign-out": "logout", "sign-out-alt": "logout", "right-from-bracket": "logout", barcode: "qr_code", qrcode: "qr_code",
    camera: "photo_camera", image: "image", stethoscope: "medical_services", bed: "bed", "notes-medical": "medical_information",
    "book-medical": "menu_book", book: "menu_book", "clipboard-list": "assignment", clipboard: "assignment", "clipboard-check": "assignment_turned_in",
    tag: "label", tags: "label", bell: "notifications", star: "star", heart: "favorite", flag: "flag", bolt: "bolt", play: "play_arrow",
    stop: "stop", pause: "pause", "circle-plus": "add_circle", "plus-circle": "add_circle", "minus-circle": "remove_circle",
    "ellipsis-v": "more_vert", "ellipsis-vertical": "more_vert", "ellipsis-h": "more_horiz", "chevron-down": "expand_more",
    "chevron-up": "expand_less", "caret-down": "arrow_drop_down", "truck": "local_shipping", "box": "inventory_2", boxes: "inventory_2",
    pills: "medication", capsules: "medication", syringe: "vaccines", "hospital": "local_hospital", "user-md": "medical_services",
    "user-doctor": "medical_services", database: "storage", server: "dns", code: "code", "file-code": "data_object", globe: "public",
    "external-link": "open_in_new", "external-link-alt": "open_in_new", "up-right-from-square": "open_in_new", "window-restore": "web_asset",
    "th": "grid_view", "th-list": "view_list", "layer-group": "layers", "sitemap": "account_tree", "diagram-project": "account_tree",
    "scale-balanced": "balance", "balance-scale": "balance", "calculator": "calculate", "handshake": "handshake", "comments": "forum",
    "comment": "comment", "question-circle": "help", "circle-question": "help", "lightbulb": "lightbulb", "history": "history",
    "clock-rotate-left": "history", "random": "shuffle", "shuffle": "shuffle", "retweet": "repeat", "exchange-alt": "swap_horiz",
    "rotate-left": "undo", "rotate-right": "redo", "user-pen": "manage_accounts", "user-edit": "manage_accounts",
    "money-check": "payments", "money-check-dollar": "request_quote", "chalkboard-user": "school", "chalkboard-teacher": "school",
    "clipboard-medical": "medical_information", "draw-circle": "adjust", "circle-dot": "adjust", "location-dot": "place",
  };

  function qrysIconoMaterial(icono) {
    const raw = String(icono || "").trim();
    if (!raw) return "smart_button";
    if (!/(^|\s)fa[srlbd]?(\s|-|$)/.test(raw)) return raw; // ya es Material
    const tokens = raw.split(/\s+/).filter((t) => t.startsWith("fa-") && !/^fa-(solid|regular|light|brands|duotone|fw|lg|xs|sm|\dx)$/.test(t));
    const nombre = (tokens[0] || "").replace(/^fa-/, "");
    return QRYS_FA_A_MATERIAL[nombre] || "smart_button";
  }

  function qrysEstiloNormalizado(estilo) {
    const e = String(estilo || "unelevated").toLowerCase().trim();
    let base = "unelevated";
    if (e.includes("outline")) base = "outline";
    else if (e.includes("flat") || e.includes("menu") || e.includes("menú") || e.includes("dropdown-item")) base = "flat";
    else if (e.includes("glossy")) base = "glossy";
    else if (e.includes("push")) base = "push";
    const tags = [];
    if (e.includes("dropdown")) tags.push("menú desplegable");
    if (e.includes("menú de fila") || e.includes("menu de fila")) tags.push("menú de la fila");
    if (e.includes("tab")) tags.push("pestaña");
    if (e.includes("round")) tags.push("icono");
    if (e.includes("deshabilitado") || e.includes("disabled")) tags.push("deshabilitado");
    if (e.includes("checkbox")) tags.push("casilla");
    if (e.includes("toggle")) tags.push("interruptor");
    if (e === "solid") base = "unelevated";
    if (e === "menu") tags.push("opción de menú");
    return { base, tags, disabled: e.includes("deshabilitado") || e.includes("disabled") };
  }

  function qrysEstiloInline(colorNombre, base) {
    const hex = QRYS_PALETA[String(colorNombre || "").toLowerCase()] || "#546e7a";
    if (base === "outline") return `border-color:${hex};color:${hex};background:#fff;`;
    if (base === "flat") return `border-color:transparent;color:${hex};background:transparent;`;
    if (base === "glossy") return `border-color:${hex};color:#fff;background:linear-gradient(180deg, ${hex} 0%, ${hex}cc 100%);`;
    if (base === "push") return `border-color:${hex};color:#fff;background:${hex};box-shadow:0 3px 0 rgba(0,0,0,.25);`;
    return `border-color:${hex};color:#fff;background:${hex};`;
  }

  function renderBotonesQuasar(proceso) {
    const lista = obtenerBotonesProceso(proceso);

    const filas = lista
      .map((b) => {
        const est = qrysEstiloNormalizado(b.estilo);
        const icono = qrysIconoMaterial(b.icono);
        const tags = est.tags.map((t) => `<span class="qrys-btn-tag">${esc(t)}</span>`).join("");
        const flecha = est.tags.includes("menú desplegable") ? `<span class="material-icons qrys-btn-icon qrys-btn-caret">arrow_drop_down</span>` : "";
        return `
      <div class="qrys-btn-item">
        <div class="qrys-btn-preview">
          <button type="button" ${est.disabled ? 'disabled aria-disabled="true"' : ""}
            class="qrys-btn qrys-btn--${esc(String(b.color || "").replace(/[^a-z0-9-]/gi, ""))} qrys-btn--${esc(est.base)}${est.disabled ? " qrys-btn--disabled" : ""}"
            style="${qrysEstiloInline(b.color, est.base)}">
            <span class="material-icons qrys-btn-icon">${esc(icono)}</span>
            <span class="qrys-btn-label">${esc(b.label)}</span>${flecha}
          </button>
          ${tags}
        </div>
        <div class="qrys-btn-desc">
          ${esc(b.descripcion || b.label)}
        </div>
      </div>
    `;
      })
      .join("");

    return `
      <div class="botones-quasar-seccion">
        <p class="botones-quasar-intro">A continuación se muestran los botones principales disponibles en <strong>${esc(proceso.nombre)}</strong>, con la estética real de Qrystalos y su propósito de uso:</p>
        <div class="botones-quasar-grid">
          ${filas}
        </div>
      </div>
    `;
  }

  function renderTablaPermisos(proceso) {
    const permisos = proceso.permisos || [];
    if (!permisos.length) {
      return `
        <div class="permisos-box">
          <p class="permisos-intro">El acceso y control de este módulo se gestiona centralizadamente mediante los perfiles de usuario del catálogo de seguridad institucional (<strong>USGRUH</strong>):</p>
          <div class="tabla-wrap">
            <table class="tabla tabla-permisos">
              <thead>
                <tr>
                  <th style="width: 25%;">Permiso / Código</th>
                  <th style="width: 25%;">Acción en Pantalla</th>
                  <th style="width: 25%;">Perfil Autorizado</th>
                  <th style="width: 25%;">Propósito Funcional</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><code>MENUQ_${esc((proceso.modulo || proceso.id || "MOD").toUpperCase())}</code></td>
                  <td>Acceso al módulo</td>
                  <td><span class="badge-rol">Operador / Supervisor</span></td>
                  <td>Permite visualizar y abrir la opción desde el menú de navegación.</td>
                </tr>
                <tr>
                  <td><code>BGuardar</code></td>
                  <td>Crear / Modificar</td>
                  <td><span class="badge-rol">Operador</span></td>
                  <td>Habilita el registro de transacciones y guardado de datos.</td>
                </tr>
                <tr>
                  <td><code>BAnular</code></td>
                  <td>Anulación formal</td>
                  <td><span class="badge-rol">Jefe de Área / Supervisor</span></td>
                  <td>Autoriza la reversión y anulación de registros cerrados.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    const filas = permisos
      .map(
        (p) => `
      <tr>
        <td><code>${esc(p.codigo)}</code></td>
        <td><strong>${esc(p.accion)}</strong></td>
        <td><span class="badge-rol">${esc(p.rol)}</span></td>
        <td>${esc(p.descripcion)}</td>
      </tr>
    `
      )
      .join("");

    return `
      <div class="permisos-box">
        <p class="permisos-intro">Para operar las diferentes acciones de este módulo, el administrador del sistema debe asignar los siguientes permisos en el perfil del usuario (catálogo <strong>USGRUH</strong>):</p>
        <div class="tabla-wrap">
          <table class="tabla tabla-permisos">
            <thead>
              <tr>
                <th style="width: 20%;">Código de Permiso</th>
                <th style="width: 22%;">Acción en Pantalla</th>
                <th style="width: 24%;">Perfil Autorizado</th>
                <th style="width: 34%;">Propósito y Alcance</th>
              </tr>
            </thead>
            <tbody>
              ${filas}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderTablaVariables(proceso) {
    const variables = proceso.variables || [];
    if (!variables.length) {
      return `
        <div class="variables-box">
          <p class="variables-intro">Este proceso toma los parámetros institucionales configurados en el catálogo de variables generales del programa (<strong>USVGS</strong>):</p>
          <div class="tabla-wrap">
            <table class="tabla tabla-variables">
              <thead>
                <tr>
                  <th style="width: 26%;">Variable (USVGS)</th>
                  <th style="width: 18%;">Tipo / Formato</th>
                  <th style="width: 18%;">Valor Sugerido</th>
                  <th style="width: 38%;">Efecto en la Operación</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><code>IXCOUNTRY</code></td>
                  <td><span class="badge-tipo">Texto</span></td>
                  <td><strong class="val-sug">COL / PER</strong></td>
                  <td>Define el país de la sede para habilitar formatos de retención y reglas fiscales locales.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    const filas = variables
      .map(
        (v) => `
      <tr>
        <td><code>${esc(v.nombre)}</code></td>
        <td><span class="badge-tipo">${esc(v.tipo)}</span></td>
        <td><strong class="val-sug">${esc(v.valorSugerido)}</strong></td>
        <td>${esc(v.descripcion)}</td>
      </tr>
    `
      )
      .join("");

    return `
      <div class="variables-box">
        <p class="variables-intro">Las siguientes variables del sistema (administradas en <strong>USVGS</strong>) condicionan el comportamiento, límites numéricos y validaciones en este módulo:</p>
        <div class="tabla-wrap">
          <table class="tabla tabla-variables">
            <thead>
              <tr>
                <th style="width: 25%;">Variable (USVGS)</th>
                <th style="width: 18%;">Tipo / Formato</th>
                <th style="width: 17%;">Valor Sugerido</th>
                <th style="width: 40%;">Efecto en el Módulo</th>
              </tr>
            </thead>
            <tbody>
              ${filas}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderGuiaPasoASeguir(proceso, grupo) {
    const gd = proceso.glosasDevoluciones;
    if (!gd) return "";
    const soloDev = grupo === "devoluciones";
    const soloGlo = grupo === "glosas";

    const renderListaPasosDL = (items, tipo) => {
      return (items || [])
        .map((item) => {
          const cols = item.columnasExcel || [];
          const tags = cols.map((c) => `<span class="paso-dl-col-tag"><code>${esc(c)}</code></span>`).join("");
          const esDefinitivo =
            (item.advertencia || "").toLowerCase().includes("definitiv") ||
            (item.advertencia || "").toLowerCase().includes("no se puede");

          const badgeRev = esDefinitivo
            ? `<span class="paso-dl-reversibilidad paso-dl-reversibilidad--alerta"><span class="material-icons">lock</span> ${esc(item.advertencia)}</span>`
            : `<span class="paso-dl-reversibilidad paso-dl-reversibilidad--ok"><span class="material-icons">check_circle</span> ${esc(item.advertencia)}</span>`;

          const inferiorHtml =
            cols.length > 0
              ? `
            <div class="paso-dl-inferior">
              <div class="paso-dl-excel-barra">
                <div class="paso-dl-excel-tit">
                  <span class="sheet-ico">📊</span>
                  <strong>Formato en Excel Requerido (Estructura de Columnas)</strong>
                </div>
                <div class="paso-dl-cols-tags">
                  ${tags}
                </div>
              </div>
              ${hoja(cols)}
            </div>
          `
              : "";

          return `
            <div class="paso-dl-card">
              <div class="paso-dl-superior">
                <div class="paso-dl-cabecera">
                  <div class="paso-dl-paso-badge ${tipo === "glosa" ? "paso-dl-paso-badge--glosa" : ""}">
                    <span class="paso-dl-badge-num">${esc(item.codigo)}</span>
                    <span class="paso-dl-badge-txt">Paso a seguir</span>
                  </div>
                  <h4 class="paso-dl-titulo">${esc(item.nombre)}</h4>
                  ${badgeRev}
                </div>
                <div class="paso-dl-explicacion">
                  <div class="paso-dl-item-exp">
                    <span class="paso-dl-exp-label">Qué hace al aplicar:</span>
                    <div class="paso-dl-exp-texto"><p>${esc(item.descripcion)}</p></div>
                  </div>
                </div>
              </div>
              ${inferiorHtml}
            </div>
          `;
        })
        .join("");
    };

    const devHtml = renderListaPasosDL(gd.devoluciones, "devolucion");
    const gloHtml = renderListaPasosDL(gd.glosas, "glosa");

    const bloqueDev = soloGlo
      ? ""
      : `
        <div class="pasos-grupo">
          <h3 class="pasos-grupo-titulo">
            <span class="material-icons">assignment_return</span>
            Devoluciones de Facturas (Opciones del Paso a Seguir)
          </h3>
          <p class="pasos-grupo-desc">Cuando el tipo de ingreso es <strong>DEVOLUCIÓN</strong>, el selector de <em>Paso a seguir</em> condiciona el efecto final de la factura y su plantilla en Excel:</p>
          <div class="pasos-doble-linea-contenedor">
            ${devHtml}
          </div>
        </div>`;

    const bloqueGlo = soloDev
      ? ""
      : `
        <div class="pasos-grupo" ${soloGlo ? "" : 'style="margin-top: 2rem;"'}>
          <h3 class="pasos-grupo-titulo">
            <span class="material-icons">medical_services</span>
            Glosas Médicas (Opciones del Paso a Seguir)
          </h3>
          <p class="pasos-grupo-desc">Cuando el tipo de ingreso es <strong>GLOSAS</strong>, el sistema ofrece cuatro modalidades con su respectiva estructura de archivo en Excel:</p>
          <div class="pasos-doble-linea-contenedor">
            ${gloHtml}
          </div>
        </div>`;

    return `
      <div class="pasos-seguir-guia">
        ${bloqueDev}
        ${bloqueGlo}
      </div>
    `;
  }

  function renderFlujoPaso(p, idx, total) {
    const num = p.num || idx + 1;
    const tipo = p.tipo || "accion";

    let tipoClase = "tipo-accion";
    let tipoBadgeTxt = "Acción de Usuario";
    let tipoIcono = "touch_app";

    if (tipo === "decision") {
      tipoClase = "tipo-decision";
      tipoBadgeTxt = "Validación / Decisión";
      tipoIcono = "alt_route";
    } else if (tipo === "resultado") {
      tipoClase = "tipo-resultado";
      tipoBadgeTxt = "Resultado Exitoso";
      tipoIcono = "verified";
    } else if (tipo === "sistema") {
      tipoClase = "tipo-sistema";
      tipoBadgeTxt = "Lo hace el sistema";
      tipoIcono = "memory";
    }

    const rolTag =
      p.rol || p.pantalla
        ? `
      <div class="flujo-paso-rol-tag">
        <span class="material-icons">${tipoIcono}</span>
        <span>${esc(p.rol || "Operación")}${p.pantalla ? ` · ${esc(p.pantalla)}` : ""}</span>
      </div>
    `
        : "";

    const tablasHtml = (p.tablas || []).length
      ? (p.tablas || [])
          .map((t) => `<span class="flujo-chip flujo-chip-tabla"><span class="chip-ico">💾</span> ${esc(t)}</span>`)
          .join("")
      : "";

    const spHtml = p.sp
      ? `<span class="flujo-chip flujo-chip-sp"><span class="chip-ico">⚡</span> ${esc(p.sp)}</span>`
      : "";

    const chipsFila =
      tablasHtml || spHtml
        ? `
      <details class="flujo-tecnico">
        <summary><span class="material-icons">build</span>Detalle técnico (soporte)</summary>
        <div class="flujo-chips-fila">
          ${tablasHtml}
          ${spHtml}
        </div>
      </details>
    `
        : "";

    const ramasHtml =
      tipo === "decision" && (p.si || p.no)
        ? `
      <div class="flujo-decision-ramas">
        <div class="flujo-rama-card rama-si">
          <span class="rama-tag">🟢 SÍ (Cumple)</span>
          <p>${esc(p.si || "Continúa al paso siguiente")}</p>
        </div>
        <div class="flujo-rama-card rama-no">
          <span class="rama-tag">🔴 NO (Bloqueo / Desvío)</span>
          <p>${esc(p.no || "Alerta de inconsistencia")}</p>
        </div>
      </div>
    `
        : "";

    return `
      <div class="flujo-paso-item ${tipoClase}">
        <div class="flujo-paso-lateral">
          <div class="flujo-paso-num-burbuja">${num}</div>
          <div class="flujo-paso-linea-conector"></div>
        </div>
        <div class="flujo-paso-contenido">
          <div class="flujo-paso-top-meta">
            ${rolTag}
            <span class="flujo-paso-tipo-badge">${tipoBadgeTxt}</span>
          </div>
          <h4 class="flujo-paso-titulo">${esc(p.titulo || p.nombre || `Paso ${num}`)}</h4>
          <p class="flujo-paso-explicacion">${esc(p.descripcion || p.explicacion || "")}</p>
          ${ramasHtml}
          ${chipsFila}
        </div>
      </div>
    `;
  }

  function renderFlujoBloque(flujo) {
    const pasos = flujo.pasos || [];
    const pasosHtml = pasos.map((p, idx) => renderFlujoPaso(p, idx, pasos.length)).join("");
    const icono = flujo.icono || "account_tree";

    return `
      <div class="flujo-bloque-completo" id="${esc(flujo.id || "")}">
        <div class="flujo-bloque-header">
          <div class="flujo-bloque-tit-wrap">
            <span class="material-icons flujo-bloque-icono">${icono}</span>
            <div class="flujo-bloque-meta-text">
              <h3>${esc(flujo.nombre)}</h3>
              ${flujo.descripcion ? `<p>${esc(flujo.descripcion)}</p>` : ""}
            </div>
          </div>
          <span class="flujo-bloque-badge">${pasos.length} Pasos</span>
        </div>
        <div class="flujo-bloque-cuerpo">
          <div class="flujo-carril-pasos">
            ${pasosHtml}
          </div>
        </div>
      </div>
    `;
  }

  function renderCapasComoFlujo(capas) {
    const iconosPorCapa = {
      1: { icon: "settings", grad: "grad-azul", sub: "Preparación" },
      2: { icon: "edit_note", grad: "grad-verde", sub: "Operación Principal" },
      3: { icon: "fact_check", grad: "grad-morado", sub: "Revisión y Retenciones" },
      4: { icon: "lock", grad: "grad-ambar", sub: "Cierre y Seguridad" },
      5: { icon: "account_balance", grad: "grad-esmeralda", sub: "Contabilización" },
    };

    return capas
      .map((c, i) => {
        const num = c.numero || i + 1;
        const conf = iconosPorCapa[num] || { icon: "analytics", grad: "grad-azul", sub: "Etapa " + num };

        let pasos = [];

        if (c.flujo && Array.isArray(c.flujo)) {
          pasos = c.flujo;
        } else if (c.flujoConfiguracion && Array.isArray(c.flujoConfiguracion)) {
          pasos = c.flujoConfiguracion.map((fc, idx) => {
            const partes = fc.split(" — ");
            return {
              num: idx + 1,
              tipo: "accion",
              titulo: partes[0] || `Paso ${idx + 1}`,
              descripcion: partes[1] || fc,
              rol: "Configuración previa",
              tablas: c.tablasClave ? [c.tablasClave[idx] || ""].filter(Boolean) : [],
            };
          });
        } else if (c.controles && Array.isArray(c.controles)) {
          pasos = c.controles.map((ctrl, idx) => {
            const sps = (ctrl.sps || []).map((s) => s.nombre + (s.metodo ? ` · ${s.metodo}` : "")).join(" / ");
            return {
              num: idx + 1,
              tipo: ctrl.invariante ? "decision" : "accion",
              titulo: ctrl.nombre,
              descripcion: ctrl.explicacion,
              rol: "Control del proceso",
              pantalla: c.nombre,
              si: ctrl.invariante ? `Regla: ${ctrl.invariante}` : null,
              no: ctrl.invariante ? "Inconsistencia / Bloqueo en pantalla" : null,
              tablas: c.tablasClave || [],
              sp: sps || null,
            };
          });
        }

        const pasosHtml = pasos.length
          ? pasos.map((p, idx) => renderFlujoPaso(p, idx, pasos.length)).join("")
          : `<p class="infog-desc">${esc(c.explicacion || "Etapa en actualización.")}</p>`;

        const flechaHtml =
          i < capas.length - 1
            ? `
          <div class="infog-conector">
            <div class="infog-linea"></div>
            <span class="material-icons infog-flecha">arrow_downward</span>
          </div>
        `
            : "";

        return `
          <div class="infog-etapa ${conf.grad}">
            <div class="infog-etapa-header">
              <div class="infog-num-badge">${num}</div>
              <div class="infog-header-meta">
                <span class="infog-sub">${conf.sub} · Etapa ${num}</span>
                <h3 class="infog-titulo">${esc(c.nombre)}</h3>
              </div>
              <span class="material-icons infog-icono-flotante">${conf.icon}</span>
            </div>
            
            <div class="infog-etapa-body">
              ${c.explicacion ? `<p class="infog-desc">${esc(c.explicacion)}</p>` : ""}
              <div class="flujo-carril-pasos" style="margin-top: 1rem;">
                ${pasosHtml}
              </div>
            </div>
          </div>
          ${flechaHtml}
        `;
      })
      .join("");
  }

  function mapaIlustrativoHtml(proceso) {
    const capas = proceso.capas || [];
    const flujos = proceso.flujos || [];

    if (!capas.length && !flujos.length) {
      return `<div class="aviso-vacio">
        <p>Este proceso no requiere fases complejas o se encuentra en actualización.</p>
      </div>`;
    }

    let selectorHtml = "";
    let flujosHtml = "";

    if (flujos.length > 0) {
      const tabsHtml = flujos
        .map(
          (f) => `
        <button type="button" class="btn-flujo-tab" data-flujo-target="${esc(f.id)}">
          <span class="material-icons">${f.icono || "account_tree"}</span>
          ${esc(f.nombre)}
        </button>
      `
        )
        .join("");

      selectorHtml = `
        <div class="flujos-selector-wrap">
          <div class="flujos-selector-header">
            <span class="material-icons">account_tree</span>
            <strong>Explorar Flujos de Trabajo de este Módulo:</strong>
          </div>
          <div class="flujos-tabs-bar">
            <button type="button" class="btn-flujo-tab activo" data-flujo-target="todos">
              <span class="material-icons">view_stream</span>
              Todos los Flujos (Vista Integral)
            </button>
            ${tabsHtml}
          </div>
        </div>
      `;

      flujosHtml = `
        <div class="flujos-listado-wrap">
          ${flujos.map(renderFlujoBloque).join("")}
        </div>
      `;
    }

    const capasHtml = renderCapasComoFlujo(capas);

    return `
      <div class="mapa-infografia-wrap">
        <div class="infog-intro">
          <span class="material-icons infog-intro-ico">timeline</span>
          <div>
            <strong>Diagramas de Flujo del Proceso</strong>
            <p>Siga cada flujo y decisión paso a paso para garantizar la trazabilidad clínica, bancaria y contable:</p>
          </div>
        </div>

        ${selectorHtml}
        ${flujosHtml}

        ${
          flujos.length > 0
            ? `
          <div style="margin: 2.5rem 0 1rem; padding-top: 1.5rem; border-top: 2px dashed #cbd5e1;">
            <div class="infog-intro" style="background: #f8fafc; border-left-color: #64748b;">
              <span class="material-icons infog-intro-ico" style="color: #64748b;">layers</span>
              <div>
                <strong style="color: #334155;">Arquitectura de 5 Capas de Control</strong>
                <p>Estructura de seguridad, invariantes y controles técnicos del módulo:</p>
              </div>
            </div>
            <div class="infog-timeline">
              ${capasHtml}
            </div>
          </div>
        `
            : `
          <div class="infog-timeline">
            ${capasHtml}
          </div>
        `
        }
      </div>
    `;
  }

  function portada(proceso, item, desc) {
    desc = desc || obtenerDescripcionProceso(proceso, item);
    return {
      id: "portada",
      kicker: item.familia ? familiaNombre(item.familia) : "Proceso",
      title: proceso.nombre || item.nombre,
      html: `
        <div class="portada-contenedor">
          <!-- 1. Descripción Estructurada: Qué es, Para qué se usa, Cuál es su propósito -->
          ${renderDescripcionProceso(desc)}

          <!-- 2. Acceso al sistema tipo Mapa Mental -->
          <div class="seccion-acceso-mental">
            ${renderMapaMentalAcceso(proceso)}
          </div>
        </div>
      `,
    };
  }

  // Mapa de procedencias. Por defecto describe FTR (facturación); otros libros
  // (p. ej. dispensación) lo reutilizan con cap.mapa = { pregunta, subtitulo,
  // centroIcono, centroTitulo, centroSub, conector, destinoPrefijo, reglaTitulo, regla }.
  function renderMapaProcedencias(proceso, cap) {
    const m = (cap && cap.mapa) || {};
    const pregunta = m.pregunta || "¿De dónde viene cada factura?";
    const subtitulo = m.subtitulo || "Las ramas muestran el origen operativo y el código definitivo guardado en la cabecera FTR.";
    const centroIcono = m.centroIcono || "receipt_long";
    const centroTitulo = m.centroTitulo || "Factura · FTR";
    const centroSub = m.centroSub || "Cabecera común del proceso";
    const conector = m.conector || "Orígenes que alimentan FTR";
    const destinoPrefijo = m.destinoPrefijo === undefined ? "FTR · " : m.destinoPrefijo;
    const reglaTitulo = m.reglaTitulo || "Regla de lectura";
    const regla = m.regla || "CIT, AUT, HADM, APLIM, ONCO e INV pueden identificar cargos o filtros. Para conocer cómo nació el documento, consulte siempre <code>FTR.PROCEDENCIA</code>.";
    const procedencias = (cap && cap.datos && proceso[cap.datos]) || proceso.procedenciasLibro || [];
    const tarjetas = procedencias
      .map(
        (p, i) => `
          <article class="proc-mind-card proc-mind-card--${(i % 6) + 1}">
            <div class="proc-mind-card-head">
              <span class="material-icons">${esc(p.icono || "source")}</span>
              <div>
                <span class="proc-mind-origen">${esc(p.origen || "")}</span>
                <strong>${esc(p.nombre || "")}</strong>
              </div>
            </div>
            <p>${esc(p.descripcion || "")}</p>
            <div class="proc-mind-transform">
              <span>${esc(p.codigoOrigen || "Origen")}</span>
              <span class="material-icons">arrow_forward</span>
              <b>${esc(destinoPrefijo)}${esc(p.procedenciaFtr || p.codigo || "")}</b>
            </div>
            ${p.ventana ? `<small><span class="material-icons">desktop_windows</span>${esc(p.ventana)}</small>` : ""}
          </article>
        `,
      )
      .join("");

    return `
      <div class="proc-mind-wrap">
        <div class="proc-mind-intro">
          <span class="material-icons">hub</span>
          <div>
            <strong>${esc(pregunta)}</strong>
            <p>${esc(subtitulo)}</p>
          </div>
        </div>
        <div class="proc-mind-centro">
          <span class="material-icons">${esc(centroIcono)}</span>
          <div>
            <strong>${esc(centroTitulo)}</strong>
            <small>${esc(centroSub)}</small>
          </div>
        </div>
        <div class="proc-mind-conector"><span></span><b>${esc(conector)}</b><span></span></div>
        <div class="proc-mind-grid">${tarjetas}</div>
        <div class="invariante-card">
          <div class="invariante-head"><span class="invariante-icon">⚠️</span><strong>${esc(reglaTitulo)}</strong></div>
          <p class="invariante-body">${regla}</p>
        </div>
      </div>
    `;
  }

  function renderFacturaFinanciera(proceso) {
    const tema = proceso.facturaFinancieraLibro || {};
    const modalidades = tema.modalidades || [];
    const tiposCapita = tema.tiposCapita || [];
    const modalidadHtml = modalidades
      .map(
        (m) => `
          <article class="fin-modalidad fin-modalidad--${esc(m.clase || "evento")}">
            <div class="fin-modalidad-head">
              <span class="material-icons">${esc(m.icono || "description")}</span>
              <div><small>${esc(m.codigo || "")}</small><strong>${esc(m.nombre || "")}</strong></div>
            </div>
            <p>${esc(m.descripcion || "")}</p>
            <div class="fin-modalidad-regla">${esc(m.regla || "")}</div>
          </article>
        `,
      )
      .join("");
    const tiposCapitaHtml = tiposCapita
      .map(
        (e) => `
          <div class="fin-facte-estado fin-facte-estado--${esc(e.clase || "neutro")}">
            <b>${esc(e.valor)}</b><span>${esc(e.nombre)}</span><small>${esc(e.uso || "")}</small>
          </div>
        `,
      )
      .join("");

    return `
      <div class="fin-capitulo">
        <div class="fin-intro">
          <span class="material-icons">account_balance_wallet</span>
          <div>
            <strong>Una sola ventana, tres modalidades financieras</strong>
            <p>${esc(tema.introduccion || "")}</p>
          </div>
        </div>

        <div class="fin-modalidades">${modalidadHtml}</div>

        <div class="fin-window">
          <div class="fin-window-bar">
            <span class="material-icons">receipt_long</span>
            <strong>Administrativo · Facturación · Facturas</strong>
            <span class="fin-window-permiso">FACT_FACTURAR</span>
          </div>
          <div class="fin-tabs">
            <span class="activo">Facturas</span><span>Facturación Masiva</span><span>Proceso DIAN</span><span>Informes Facturación</span>
          </div>
          <div class="fin-filtros">
            <label>Fecha inicial<em>01/10/2026</em></label>
            <label>Estado FACTE<em>Todas</em></label>
            <label>Procedencia<em>FINANCIERO</em></label>
            <label>Contrato<em>CAP-2026</em></label>
            <button><span class="material-icons">add</span>Nueva Factura</button>
          </div>
          <div class="fin-grid">
            <div class="fin-grid-head"><span>Factura</span><span>Cliente</span><span>Contrato</span><span>Modalidad</span><span>DIAN</span><span>Valor</span></div>
            <div class="fin-grid-row"><b>FE-10452</b><span>EPS Ejemplo</span><span>CAP-2026</span><span class="fin-chip fin-chip--capita">Capitada · Masiva</span><span class="fin-chip fin-chip--proceso">Sin notificar</span><b>$ 125.000.000</b></div>
          </div>
          <div class="fin-detail">
            <div class="fin-detail-head"><strong>Factura FE-10452</strong><span>FINANCIERO</span><span>Capitada</span><span>TIPOCAP 4 · Masiva</span></div>
            <div class="fin-summary">
              <div><small>Valor servicios</small><b>$ 125.000.000</b></div>
              <div><small>Tipo cápita</small><b>4 · Masiva</b></div>
              <div><small>Relación de servicios</small><b>FTRDC requerida</b></div>
              <div><small>Generador RIPS</small><b>Capitación masiva</b></div>
            </div>
            <div class="fin-actions">
              <button><span class="material-icons">playlist_add</span>Agregar prestaciones</button>
              <button><span class="material-icons">table_view</span>Relación capitado</button>
              <button><span class="material-icons">data_object</span>Relación JSON</button>
              <button><span class="material-icons">print</span>Imprimir</button>
            </div>
            <div class="fin-relacion">
              <div class="fin-relacion-title"><span class="material-icons">link</span><strong>Relación del capitado · FTRDC</strong><small>Une cada línea financiera con pacientes y servicios realmente cubiertos.</small></div>
              <div class="fin-relacion-row fin-relacion-row--head"><span>Origen</span><span>Paciente</span><span>Servicio</span><span>Fecha</span><span>Valor</span></div>
              <div class="fin-relacion-row"><span>HADM</span><span>Paciente ejemplo</span><span>Consulta especializada</span><span>18/09/2026</span><span>$ 95.000</span></div>
            </div>
          </div>
        </div>

        <div class="fin-doble">
          <section class="fin-panel">
            <div class="fin-panel-head"><span class="material-icons">upload_file</span><strong>RIPS externos</strong></div>
            <p>${esc(tema.ripsExternos || "")}</p>
            <ol>
              <li>Abrir <b>Relación JSON</b> en la factura.</li>
              <li>Cargar uno o varios JSON dentro del período de cobertura.</li>
              <li>Validar paciente, tipo de usuario, fechas y servicios.</li>
              <li>Guardar en FTRDJSON; luego el generador RIPS los integra según la modalidad.</li>
            </ol>
            <div class="fin-rips-mini"><span>archivo_eps_09.json</span><b>42 pacientes</b><b>116 servicios</b><strong>Guardado</strong></div>
          </section>
          <section class="fin-panel fin-panel--facte">
            <div class="fin-panel-head"><span class="material-icons">group_work</span><strong>¿Qué significa TIPOCAP=4?</strong></div>
            <p>${esc(tema.tipocap4 || "")}</p>
            <div class="fin-facte-secuencia fin-tipocap-secuencia">${tiposCapitaHtml}</div>
            <ul>
              <li>No participa en la secuencia Inicial → Periodo → Final.</li>
              <li>Genera RIPS con la rama de capitación masiva y usa el endpoint FEV estándar.</li>
              <li>Exige relación de servicios FTRDC; no convierte la factura en PGP por sí solo.</li>
            </ul>
            <div class="fin-alerta"><span class="material-icons">warning</span><span>TIPOCAP=4 clasifica la modalidad cápita masiva. No es el estado electrónico FACTE=4.</span></div>
          </section>
        </div>
      </div>
    `;
  }

  function renderEnvioDian(proceso, cap) {
    const flujo = (proceso.flujos || []).find((f) => f.id === cap.flujoId) || {};
    const pasos = flujo.pasos || [];
    const paso = (num) => pasos.find((p) => Number(p.num) === num) || {};
    const logoDian = "https://devolucion.dian.gov.co/WebIdentidad/imagenes/es/logos/DIAN.png";

    return `
      <div class="dian-ilustracion">
        <header class="dian-hero">
          <div class="dian-hero-copy">
            <span class="dian-eyebrow"><span class="material-icons">receipt_long</span> Facturación electrónica de venta</span>
            <h3>De Qrystalos a la validación electrónica</h3>
            <p>${esc(flujo.descripcion || "")}</p>
          </div>
          <div class="dian-logo-oficial">
            <img src="${logoDian}" alt="Logotipo de la DIAN" loading="lazy">
            <small>Validador tributario</small>
          </div>
        </header>

        <div class="dian-secuencia-claves">
          <div><span class="dian-clave-num">1</span><p><strong>Factura en Qrystalos</strong><small>Documento y detalle completos</small></p></div>
          <span class="material-icons">east</span>
          <div><span class="dian-clave-num">2</span><p><strong>XML firmado</strong><small>Documento electrónico UBL</small></p></div>
          <span class="material-icons">east</span>
          <div><span class="dian-clave-num dian-clave-num--ok">3</span><p><strong>CUFE</strong><small>Identificación electrónica validada</small></p></div>
        </div>

        <section class="dian-precondiciones">
          <div class="dian-section-title">
            <span>01</span>
            <div><strong>Antes de encolar</strong><small>${esc(paso(1).titulo || "Validar factura y resolución")}</small></div>
          </div>
          <div class="dian-check-grid">
            <article><span class="material-icons">format_list_bulleted</span><strong>Factura completa</strong><small>Cabecera, detalle y valores consistentes</small></article>
            <article><span class="material-icons">approval</span><strong>Resolución vigente</strong><small>Prefijo y rango autorizado disponibles</small></article>
            <article><span class="material-icons">workspace_premium</span><strong>Certificado activo</strong><small>Firma digital vigente para el XML</small></article>
            <article><span class="material-icons">account_tree</span><strong>Relación asistencial</strong><small>FTRDC completa cuando es cápita o PGP</small></article>
          </div>
        </section>

        <section class="dian-mapa">
          <article class="dian-actor-card dian-actor-card--qrystalos">
            <div class="dian-actor-head"><span class="material-icons">desktop_windows</span><div><strong>Qrystalos</strong><small>Preparación y cola</small></div></div>
            <div class="dian-step">
              <span class="dian-step-num">02</span>
              <span class="material-icons">outbox</span>
              <strong>${esc(paso(2).titulo || "Encolar la factura")}</strong>
              <small>FACTE=1 · En cola</small>
            </div>
          </article>

          <div class="dian-conector"><span></span><span class="material-icons">arrow_forward</span><span></span></div>

          <article class="dian-actor-card dian-actor-card--servicio">
            <div class="dian-actor-head"><span class="material-icons">hub</span><div><strong>Facturador electrónico</strong><small>Servicio de integración</small></div></div>
            <div class="dian-step">
              <span class="dian-step-num">03</span>
              <span class="material-icons">draw</span>
              <strong>${esc(paso(3).titulo || "Generar y firmar XML")}</strong>
              <small>XML UBL · Firma digital · Transmisión</small>
            </div>
          </article>

          <div class="dian-conector"><span></span><span class="material-icons">arrow_forward</span><span></span></div>

          <article class="dian-actor-card dian-actor-card--dian">
            <div class="dian-actor-head dian-actor-head--logo">
              <img src="${logoDian}" alt="DIAN">
              <small>Validador oficial</small>
            </div>
            <div class="dian-step">
              <span class="dian-step-num">04</span>
              <span class="material-icons">fact_check</span>
              <strong>${esc(paso(4).titulo || "Validar documento")}</strong>
              <div class="dian-validaciones"><span>Firma</span><span>Numeración</span><span>Impuestos</span><span>Estructura</span></div>
            </div>
          </article>
        </section>

        <section class="dian-respuesta">
          <div class="dian-respuesta-title"><span class="material-icons">call_split</span><strong>Respuesta de la DIAN</strong></div>
          <div class="dian-resultado-grid">
            <article class="dian-resultado dian-resultado--ok">
              <div class="dian-resultado-icon"><span class="material-icons">verified</span></div>
              <div><span class="dian-estado">ACEPTADA</span><strong>FACTE=2 · CUFE y XML disponibles</strong><p>${esc(paso(5).descripcion || "")}</p></div>
              <span class="dian-step-num">05</span>
            </article>
            <article class="dian-resultado dian-resultado--error">
              <div class="dian-resultado-icon"><span class="material-icons">report</span></div>
              <div><span class="dian-estado">RECHAZADA</span><strong>FACTE=3 · Con errores</strong><p>${esc(paso(4).no || "Corregir y volver a encolar.")}</p></div>
              <span class="material-icons dian-retorno">replay</span>
            </article>
          </div>
        </section>

        <footer class="dian-nota-final">
          <div><span class="material-icons">fingerprint</span><p><strong>CUFE</strong><small>Factura electrónica DIAN</small></p></div>
          <span class="material-icons dian-noigual">compare_arrows</span>
          <div><span class="material-icons">health_and_safety</span><p><strong>CUV</strong><small>Paquete RIPS Ministerio</small></p></div>
          <span class="material-icons dian-noigual">compare_arrows</span>
          <div><span class="material-icons">payments</span><p><strong>Radicado</strong><small>Cuenta recibida por el pagador</small></p></div>
        </footer>
      </div>
    `;
  }

  function renderEnvioRecepcion(proceso, cap) {
    const flujo = (proceso.flujos || []).find((f) => f.id === cap.flujoId) || {};
    const pasos = flujo.pasos || [];
    const paso = (num) => pasos.find((p) => Number(p.num) === num) || {};

    return `
      <div class="traslado-ilustracion">
        <header class="traslado-hero">
          <div class="traslado-hero-icon"><span class="material-icons">move_to_inbox</span></div>
          <div>
            <span class="traslado-eyebrow">Circuito interno · ENT / ENTD</span>
            <h3>Traslado interno de facturas entre áreas</h3>
            <p>${esc(flujo.descripcion || "")}</p>
          </div>
          <div class="traslado-sello"><span class="material-icons">route</span><strong>Trazabilidad</strong><small>Origen → destino</small></div>
        </header>

        <div class="traslado-estados">
          <div class="traslado-estado traslado-estado--activo"><span>1</span><p><strong>Entrega abierta</strong><small>Se prepara el envío</small></p></div>
          <span class="material-icons">east</span>
          <div class="traslado-estado"><span>2</span><p><strong>Facturas asignadas</strong><small>Detalle ENTD</small></p></div>
          <span class="material-icons">east</span>
          <div class="traslado-estado"><span>3</span><p><strong>Entrega cerrada</strong><small>Lista para recibir</small></p></div>
          <span class="material-icons">east</span>
          <div class="traslado-estado traslado-estado--ok"><span>4</span><p><strong>Recepción confirmada</strong><small>Nueva ubicación</small></p></div>
        </div>

        <section class="traslado-preparacion">
          <div class="traslado-lane-title">
            <span class="material-icons">receipt_long</span>
            <div><strong>Facturación · área que envía</strong><small>Prepara y entrega el lote documental</small></div>
          </div>
          <div class="traslado-pasos-envio">
            <article>
              <span class="traslado-num">01</span>
              <div class="traslado-card-icon"><span class="material-icons">create_new_folder</span></div>
              <div><strong>${esc(paso(1).titulo || "Crear una entrega")}</strong><p>Seleccionar el proceso y la dependencia que recibirá las facturas.</p><span class="traslado-chip">ENT · cabecera</span></div>
            </article>
            <span class="material-icons traslado-arrow">arrow_forward</span>
            <article>
              <span class="traslado-num">02</span>
              <div class="traslado-card-icon"><span class="material-icons">playlist_add_check</span></div>
              <div><strong>${esc(paso(2).titulo || "Asignar facturas")}</strong><p>Marcar una, varias o todas; cada factura queda relacionada con la entrega.</p><span class="traslado-chip">ENTD · detalle</span></div>
            </article>
            <span class="material-icons traslado-arrow">arrow_forward</span>
            <article>
              <span class="traslado-num">03</span>
              <div class="traslado-card-icon traslado-card-icon--cerrar"><span class="material-icons">lock</span></div>
              <div><strong>${esc(paso(3).titulo || "Cerrar la entrega")}</strong><p>La entrega debe tener facturas. Al cerrar queda disponible para el área destino.</p><span class="traslado-chip traslado-chip--cerrado">CERRAR_ENT</span></div>
            </article>
          </div>
        </section>

        <div class="traslado-puente">
          <span class="material-icons">south</span>
          <strong>El área destino abre y procesa la entrega cerrada</strong>
          <small>Cerrar la entrega no significa que ya fue recibida</small>
        </div>

        <section class="traslado-destinos">
          <div class="traslado-destinos-head">
            <div><span class="traslado-num">04</span><strong>${esc(paso(4).titulo || "Recibir según destino")}</strong></div>
            <small>El proceso seleccionado define qué acción se ejecuta</small>
          </div>
          <div class="traslado-rutas">
            <article class="traslado-ruta traslado-ruta--cartera">
              <div class="traslado-ruta-top"><span class="material-icons">account_balance_wallet</span><span>FACTURAS</span></div>
              <strong>Recibir en Cartera</strong>
              <p>Actualiza la ubicación y deja la factura disponible para continuar el cobro.</p>
              <div class="traslado-ruta-efecto"><span class="material-icons">check_circle</span><b>INDCARTERA=1</b></div>
            </article>
            <article class="traslado-ruta traslado-ruta--auditoria">
              <div class="traslado-ruta-top"><span class="material-icons">fact_check</span><span>AUDITORIA</span></div>
              <strong>Recibir para revisión</strong>
              <p>Entrega las facturas a Auditoría para su control antes del siguiente paso.</p>
              <div class="traslado-ruta-efecto"><span class="material-icons">visibility</span><b>Dependencia Auditoría</b></div>
            </article>
            <article class="traslado-ruta traslado-ruta--devolver">
              <div class="traslado-ruta-top"><span class="material-icons">assignment_return</span><span>DEVFACT</span></div>
              <strong>Devolver a Facturación</strong>
              <p>Regresa la factura al área de origen cuando requiere corrección o reproceso.</p>
              <div class="traslado-ruta-efecto"><span class="material-icons">replay</span><b>Retorno controlado</b></div>
            </article>
          </div>
        </section>

        <section class="traslado-resultado">
          <div class="traslado-resultado-icon"><span class="material-icons">where_to_vote</span></div>
          <div><span>05 · RESULTADO</span><strong>${esc(paso(5).titulo || "Factura ubicada en el área destino")}</strong><p>${esc(paso(5).descripcion || "")}</p></div>
          <div class="traslado-opcion-cxc"><span class="material-icons">add_business</span><p><strong>Ruta alternativa</strong><small>CREARCXC_ENT recibe la entrega y crea la cuenta de cobro en el mismo paso.</small></p></div>
        </section>

        <footer class="traslado-no-confundir">
          <span class="material-icons">info</span>
          <p><strong>No confundir:</strong> este capítulo documenta el traslado interno de facturas. No es envío a DIAN, validación del Ministerio ni radicación ante el pagador.</p>
        </footer>
      </div>
    `;
  }

  function renderRadicacionCartera(proceso, cap) {
    const tema = proceso.radicacionCarteraLibro || {};
    const estados = tema.estados || [];
    const iconos = {
      "Agregar Facturas": "playlist_add",
      "Borrar Marcadas": "delete_sweep",
      "Cerrar CxC": "lock",
      Imprimir: "print",
      Adjuntar: "document_scanner",
      "Abrir CxC": "lock_open",
      "F_ENVIO si está configurado": "event_available",
      "Radicar CXC": "approval",
      "Importar Radicados": "upload_file",
      "Asignar o editar radicado por factura": "edit_note",
      Contabilizar: "account_balance",
      "Imprimir comprobante": "receipt_long",
      "Descargar FE / PDF FE / FEV-RIPS": "folder_zip",
    };
    const accionesEstado = (estado) =>
      (estado.acciones || [])
        .map(
          (accion) => `
            <span class="radicacion-accion">
              <span class="material-icons">${iconos[accion] || "touch_app"}</span>
              ${esc(accion)}
            </span>
          `,
        )
        .join("");

    return `
      <div class="radicacion-ilustracion">
        <header class="radicacion-hero">
          <div class="radicacion-hero-copy">
            <span class="radicacion-eyebrow"><span class="material-icons">account_balance_wallet</span> Cuentas por cobrar · FCXC</span>
            <h3>Los botones cambian según el estado de la cuenta</h3>
            <p>La cuenta se arma, se cierra, se radica y después se complementa con documentos, radicados por factura, descargas y contabilidad.</p>
          </div>
          <div class="radicacion-sello"><span class="material-icons">task_alt</span><strong>Radicación</strong><small>Entrega formal al pagador</small></div>
        </header>

        <div class="radicacion-no-confundir">
          <div><span class="material-icons">receipt_long</span><p><strong>Factura</strong><small>Documento individual</small></p></div>
          <span class="material-icons">east</span>
          <div><span class="material-icons">inventory_2</span><p><strong>Cuenta de cobro</strong><small>Agrupa facturas FCXC</small></p></div>
          <span class="material-icons">east</span>
          <div><span class="material-icons">how_to_reg</span><p><strong>Radicación</strong><small>El pagador recibe la cuenta</small></p></div>
        </div>

        <section class="radicacion-ventana">
          <div class="radicacion-window-bar">
            <div><span class="material-icons">account_balance_wallet</span><strong>Administrativo · Cuentas por Cobrar</strong></div>
            <span>Detalle de cuenta</span>
          </div>
          <div class="radicacion-window-summary">
            <div><small>Cuenta</small><strong>CXC-2026-0148</strong></div>
            <div><small>Pagador</small><strong>EPS Ejemplo</strong></div>
            <div><small>Facturas</small><strong>128</strong></div>
            <div><small>Valor</small><strong>$ 286.450.000</strong></div>
          </div>
          <div class="radicacion-estados-grid">
            ${estados
              .map(
                (estado, idx) => `
                  <article class="radicacion-estado-card radicacion-estado-card--${esc(estado.id)}">
                    <div class="radicacion-estado-head">
                      <span class="radicacion-estado-num">0${idx + 1}</span>
                      <div><strong>${esc(estado.nombre)}</strong><small>${esc(estado.condicion)}</small></div>
                    </div>
                    <div class="radicacion-acciones">${accionesEstado(estado)}</div>
                  </article>
                `,
              )
              .join('<span class="material-icons radicacion-flecha">arrow_forward</span>')}
          </div>
        </section>

        <section class="radicacion-doble">
          <article class="radicacion-panel radicacion-panel--excel">
            <div class="radicacion-panel-head">
              <div class="radicacion-panel-icon"><span class="material-icons">upload_file</span></div>
              <div><span>DESPUÉS DE RADICAR</span><strong>Importar Radicados</strong></div>
            </div>
            <p>El botón aparece cuando <b>INDRECIBIDO=1</b>. Permite cargar por Excel el número externo correspondiente a cada factura de una cuenta ya recibida.</p>
            <div class="radicacion-mini-flujo">
              <span><i>1</i>Exportar formato</span><span class="material-icons">east</span>
              <span><i>2</i>Llenar factura + radicado</span><span class="material-icons">east</span>
              <span><i>3</i>Importar</span>
            </div>
            <div class="radicacion-mini-note"><span class="material-icons">edit_note</span><span>También existe <b>Asignar/Edita Radicado</b> por cada factura.</span></div>
          </article>

          <article class="radicacion-panel radicacion-panel--docs">
            <div class="radicacion-panel-head">
              <div class="radicacion-panel-icon"><span class="material-icons">document_scanner</span></div>
              <div><span>GESTIÓN DOCUMENTAL</span><strong>Adjuntar documentos escaneados</strong></div>
            </div>
            <p>${esc(tema.aclaracionDocumental || "")}</p>
            <div class="radicacion-doc-actions">
              <span><span class="material-icons">note_add</span>Nuevo</span>
              <span><span class="material-icons">cloud_upload</span>Subir varios</span>
              <span><span class="material-icons">visibility</span>Ver</span>
              <span><span class="material-icons">download</span>Descargar</span>
              <span><span class="material-icons">delete</span>Eliminar</span>
            </div>
          </article>
        </section>

        <section class="radicacion-posteriores">
          <div class="radicacion-posteriores-title"><span class="material-icons">apps</span><strong>Otros controles disponibles en el detalle</strong></div>
          <div class="radicacion-extras">
            <span><span class="material-icons">print</span>Imprimir cuenta</span>
            <span><span class="material-icons">receipt</span>Comprobante contable</span>
            <span><span class="material-icons">folder_zip</span>Descargar FE</span>
            <span><span class="material-icons">picture_as_pdf</span>Descargar PDF FE</span>
            <span><span class="material-icons">health_and_safety</span>Descargar FEV-RIPS</span>
            <span><span class="material-icons">folder_tree</span>Soportes por factura</span>
            <span><span class="material-icons">send</span>Enviar a Presupuesto</span>
            <span><span class="material-icons">logout</span>Salir</span>
          </div>
        </section>

        <footer class="radicacion-nota-final">
          <span class="material-icons">warning_amber</span>
          <p><strong>Importar Radicados no realiza la radicación inicial.</strong> Complementa una cuenta que ya fue recibida. El botón <b>Radicar CXC</b> es el que registra la recepción y genera los vencimientos de cartera.</p>
        </footer>
      </div>
    `;
  }

  function renderValidacionMinisterio(proceso, cap) {
    const flujo = (proceso.flujos || []).find((f) => f.id === cap.flujoId) || {};
    const pasos = flujo.pasos || [];
    const paso = (num) => pasos.find((p) => Number(p.num) === num) || {};

    return `
      <div class="minsalud-ilustracion">
        <header class="minsalud-hero">
          <div class="minsalud-hero-copy">
            <span class="minsalud-eyebrow"><span class="material-icons">health_and_safety</span> FEV · RIPS · SISPRO</span>
            <h3>De la factura DIAN al Código Único de Validación</h3>
            <p>${esc(flujo.descripcion || "")}</p>
          </div>
          <div class="minsalud-cuv-sello">
            <span class="material-icons">verified_user</span>
            <small>Resultado esperado</small>
            <strong>CUV</strong>
          </div>
        </header>

        <div class="minsalud-diferencia">
          <div><span class="material-icons">receipt_long</span><p><strong>CUFE</strong><small>Valida la factura electrónica ante la DIAN</small></p></div>
          <span class="material-icons minsalud-noigual">compare_arrows</span>
          <div><span class="material-icons">health_and_safety</span><p><strong>CUV</strong><small>Valida el paquete FEV-RIPS ante el Ministerio</small></p></div>
          <div class="minsalud-alerta-corta"><span class="material-icons">info</span>Uno no reemplaza al otro</div>
        </div>

        <section class="minsalud-precondiciones">
          <div class="minsalud-section-title">
            <span>01</span>
            <div><strong>Punto de partida</strong><small>${esc(paso(1).titulo || "Comprobar precondiciones FEV-RIPS")}</small></div>
          </div>
          <div class="minsalud-check-grid">
            <article><span class="material-icons">task_alt</span><strong>Factura DIAN OK</strong><small>FACTE=2 y CUFE disponible</small></article>
            <article><span class="material-icons">clinical_notes</span><strong>Datos clínicos</strong><small>Atención, paciente y códigos completos</small></article>
            <article><span class="material-icons">account_tree</span><strong>Modalidad definida</strong><small>Evento, cápita, PGP, masiva o AUTPG</small></article>
            <article><span class="material-icons">fingerprint</span><strong>Sin CUV previo</strong><small>Evita duplicar una validación aceptada</small></article>
          </div>
        </section>

        <section class="minsalud-mapa">
          <div class="minsalud-carril minsalud-carril--qrystalos">
            <div class="minsalud-actor">
              <span class="material-icons">desktop_windows</span>
              <div><strong>Qrystalos</strong><small>Preparación del paquete</small></div>
            </div>
            <div class="minsalud-nodos">
              <article class="minsalud-nodo">
                <span class="minsalud-nodo-num">02</span>
                <span class="material-icons">data_object</span>
                <div><strong>${esc(paso(2).titulo || "Generar JSON RIPS")}</strong><small>El motor elige la rama según la modalidad de la factura.</small></div>
              </article>
              <span class="material-icons minsalud-flecha">arrow_forward</span>
              <article class="minsalud-nodo">
                <span class="minsalud-nodo-num">03</span>
                <span class="material-icons">inventory_2</span>
                <div><strong>Construir paquete FEV-RIPS</strong><small>Factura electrónica + CUFE + usuarios + servicios RIPS.</small></div>
              </article>
            </div>
          </div>

          <div class="minsalud-puente">
            <div class="minsalud-token"><span class="material-icons">vpn_key</span><strong>JWT</strong><small>Canal autenticado</small></div>
            <div class="minsalud-envio-linea"><span></span><span class="material-icons">cloud_upload</span><span></span></div>
            <small>Transmisión segura</small>
          </div>

          <div class="minsalud-carril minsalud-carril--sispro">
            <div class="minsalud-actor">
              <span class="material-icons">account_balance</span>
              <div><strong>Ministerio · SISPRO</strong><small>Validador oficial</small></div>
            </div>
            <article class="minsalud-validador">
              <span class="minsalud-nodo-num">04</span>
              <div class="minsalud-validador-icon"><span class="material-icons">fact_check</span></div>
              <strong>${esc(paso(4).titulo || "Validar el paquete")}</strong>
              <div class="minsalud-validaciones">
                <span>Estructura</span><span>Identidad</span><span>Códigos</span><span>Coherencia FEV-RIPS</span>
              </div>
            </article>
          </div>
        </section>

        <section class="minsalud-respuesta">
          <div class="minsalud-respuesta-title"><span class="material-icons">call_split</span><strong>Respuesta del validador</strong></div>
          <div class="minsalud-resultado-grid">
            <article class="minsalud-resultado minsalud-resultado--ok">
              <div class="minsalud-resultado-icon"><span class="material-icons">verified</span></div>
              <div><span class="minsalud-estado">APROBADO</span><strong>CUV recibido y registrado</strong><p>${esc(paso(5).descripcion || "")}</p></div>
              <span class="minsalud-nodo-num">05</span>
            </article>
            <article class="minsalud-resultado minsalud-resultado--error">
              <div class="minsalud-resultado-icon"><span class="material-icons">rule</span></div>
              <div><span class="minsalud-estado">RECHAZADO</span><strong>Corregir y volver a enviar</strong><p>${esc(paso(4).no || "Revisar inconsistencias y reintentar.")}</p></div>
              <span class="material-icons minsalud-retorno">replay</span>
            </article>
          </div>
        </section>

        <footer class="minsalud-nota-final">
          <span class="material-icons">payments</span>
          <p><strong>El CUV cierra la validación del Ministerio.</strong> No radica la cuenta de cobro ante el pagador; ese proceso ocurre después en Cartera.</p>
        </footer>
      </div>
    `;
  }

  function renderFevripsMasivo(proceso, cap) {
    const flujo = (proceso.flujos || []).find((f) => f.id === cap.flujoId) || {};
    const pasos = flujo.pasos || [];
    const paso = (num) => pasos.find((p) => Number(p.num) === num) || {};
    const m = proceso.masivoLibro || {};
    const ventana = (proceso.ventanas || [])[0] || {};

    const ruta = String(ventana.entrada || "Administrativo → FEV/NC/NA-RIPS Masivo")
      .split(".")[0]
      .split("→")
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => `<span>${esc(s)}</span>`)
      .join(`<span class="material-icons">chevron_right</span>`);

    const filtro = (m.filtroBase || [])
      .map((f) => `<article><span class="material-icons">${esc(f.icono || "check")}</span><strong>${esc(f.titulo)}</strong><small>${esc(f.detalle || "")}</small></article>`)
      .join("");

    const pestanas = (m.pestanas || [])
      .map(
        (t) => `
          <article class="fevmas-tab fevmas-tab--${esc(t.id)}">
            <div class="fevmas-tab-head"><span class="material-icons">${esc(t.icono || "tab")}</span><div><strong>${esc(t.titulo)}</strong><small>${esc(t.sub || "")}</small></div></div>
            <p>${esc(t.detalle || "")}</p>
          </article>`
      )
      .join("");

    const carril = (lista, clase) =>
      (lista || [])
        .map(
          (s, i) => `
            ${i ? `<span class="material-icons fevmas-flecha">arrow_forward</span>` : ""}
            <article class="fevmas-paso ${clase}">
              <span class="fevmas-num">${String(i + 1).padStart(2, "0")}</span>
              <strong>${esc(s.titulo)}</strong>
              <small>${esc(s.detalle || "")}</small>
            </article>`
        )
        .join("");

    const estados = (m.estados || [])
      .map((e) => `<span class="fevmas-estado fevmas-estado--${esc(e.tono || "gris")}">${esc(e.estado)}</span>`)
      .join(`<span class="material-icons fevmas-estado-sep">east</span>`);

    return `
      <div class="fevmas-ilustracion">
        <header class="fevmas-hero">
          <div>
            <span class="fevmas-eyebrow"><span class="material-icons">${esc(flujo.icono || "dynamic_feed")}</span> Validación por lote</span>
            <h3>${esc(flujo.nombre || "FEV/NC/NA-RIPS Masivo")}</h3>
            <p>${esc(flujo.descripcion || "")}</p>
          </div>
          <div class="fevmas-ruta">${ruta}</div>
        </header>

        <section class="fevmas-bloque">
          <div class="fevmas-titulo"><span class="material-icons">filter_alt</span><div><strong>¿Qué facturas aparecen?</strong><small>Si una factura no sale en la lista, revise estas condiciones antes de reportar un error.</small></div></div>
          <div class="fevmas-filtro">${filtro}</div>
        </section>

        <section class="fevmas-bloque">
          <div class="fevmas-titulo"><span class="material-icons">tab</span><div><strong>Tres pestañas, un mismo procedimiento</strong><small>Facturas, notas débito y crédito, y notas de ajuste.</small></div></div>
          <div class="fevmas-tabs">${pestanas}</div>
        </section>

        ${m.credenciales ? `<div class="fevmas-credenciales"><span class="material-icons">vpn_key</span><p><strong>Credenciales SISPRO.</strong> ${esc(m.credenciales)}</p></div>` : ""}

        <section class="fevmas-carril fevmas-carril--validar">
          <div class="fevmas-carril-head"><span class="material-icons">fact_check</span><div><strong>${esc(paso(2).titulo || "Validar")}</strong><small>${esc(paso(2).descripcion || "")}</small></div></div>
          <div class="fevmas-pasos">${carril(m.validar, "fevmas-paso--validar")}</div>
        </section>

        ${estados ? `<div class="fevmas-estados"><span class="fevmas-estados-label">Estado de cada fila</span>${estados}</div>` : ""}

        <section class="fevmas-carril fevmas-carril--descargar">
          <div class="fevmas-carril-head"><span class="material-icons">folder_zip</span><div><strong>${esc(paso(4).titulo || "Descargar paquetes")}</strong><small>${esc(paso(4).descripcion || "")}</small></div></div>
          <div class="fevmas-pasos">${carril(m.descargar, "fevmas-paso--descargar")}</div>
        </section>

        ${m.nota ? `<footer class="fevmas-nota"><span class="material-icons">payments</span><p><strong>${esc(m.nota)}</strong></p></footer>` : ""}
      </div>
    `;
  }

  function renderGuiaRapida(proceso) {
    const items = proceso.necesidadesYaCubiertas || [];
    if (!items.length) {
      return `<div class="aviso-vacio"><p>La guía rápida está pendiente de documentación.</p></div>`;
    }
    const ruta = (txt) =>
      String(txt || "")
        .split("→")
        .map((s) => s.trim())
        .filter(Boolean)
        .map((s) => `<span class="guia-ruta-paso">${esc(s)}</span>`)
        .join(`<span class="material-icons guia-ruta-sep">chevron_right</span>`);

    const tarjetas = items
      .map(
        (n, i) => `
          <article class="guia-card">
            <header class="guia-card-head">
              <span class="guia-num">${i + 1}</span>
              <h4>${esc(n.necesidad)}</h4>
            </header>
            <div class="guia-ruta">${ruta(n.donde)}</div>
            ${n.condicion ? `<p class="guia-ojo"><span class="material-icons">lightbulb</span><span>${esc(n.condicion)}</span></p>` : ""}
            ${n.noEs ? `<p class="guia-noes"><span class="material-icons">block</span><span><strong>No lo confunda:</strong> ${esc(n.noEs)}</span></p>` : ""}
          </article>`
      )
      .join("");

    return `
      <div class="guia-rapida">
        <p class="guia-intro"><span class="material-icons">travel_explore</span>Busque lo que necesita hacer y siga la ruta. Si su caso no aparece, continúe con los capítulos siguientes.</p>
        <div class="guia-grid">${tarjetas}</div>
      </div>
    `;
  }

  function renderSemaforo(proceso, cap) {
    const d = proceso[cap.datos] || {};
    const filas = d.filas || [];
    if (!filas.length) {
      return `<div class="aviso-vacio"><p>Este capítulo está pendiente de documentación.</p></div>`;
    }
    const columnas = d.columnas || [];
    const filasHtml = filas
      .map((f) => {
        const etiquetas = (f.etiquetas || [])
          .map((t, i) => `<span class="semaforo-etiqueta"${columnas[i] && columnas.length > 1 ? ` title="${esc(columnas[i])}"` : ""}>${esc(t)}</span>`)
          .join("");
        return `
          <article class="semaforo-fila semaforo-fila--${esc(f.tono || "gris")}">
            <div class="semaforo-luz">${esc(f.codigo || "")}</div>
            <div class="semaforo-etiquetas">${etiquetas}</div>
            <div class="semaforo-significa"><small>Qué significa</small><p>${esc(f.significa || "")}</p></div>
            <div class="semaforo-hacer"><small>Qué hacer</small><p>${esc(f.queHacer || "")}</p></div>
          </article>`;
      })
      .join("");

    const leyenda =
      columnas.length > 1
        ? `<div class="semaforo-leyenda"><span>Se ve así en:</span>${columnas.map((c) => `<span class="semaforo-etiqueta">${esc(c)}</span>`).join("")}</div>`
        : "";

    return `
      <div class="semaforo">
        <header class="semaforo-head">
          <span class="material-icons">traffic</span>
          <div><h3>${esc(d.titulo || cap.titulo || "")}</h3>${d.descripcion ? `<p>${esc(d.descripcion)}</p>` : ""}</div>
        </header>
        ${leyenda}
        <div class="semaforo-lista">${filasHtml}</div>
        ${d.nota ? `<footer class="semaforo-nota"><span class="material-icons">info</span><p>${esc(d.nota)}</p></footer>` : ""}
      </div>
    `;
  }

  // Envoltorio común de un capítulo temático: ilustración (sketchnote),
  // introducción en lenguaje de negocio y puntos clave para recordar.
  function envolturaCapitulo(cap, html) {
    const partes = [];
    if (cap.intro) {
      partes.push(`<div class="prosa cap-intro"><p>${inline(cap.intro)}</p></div>`);
    }
    if (cap.imagen) {
      partes.push(
        `<div class="img-ilustracion-wrap"><img src="${esc(cap.imagen)}" alt="${esc(cap.imagenAlt || cap.titulo || "")}" class="img-ilustracion" loading="lazy" />${
          cap.imagenAlt ? `<span class="img-caption">${esc(cap.imagenAlt)}</span>` : ""
        }</div>`
      );
    }
    partes.push(html);
    if (Array.isArray(cap.puntosClave) && cap.puntosClave.length) {
      partes.push(`
        <div class="puntos-clave">
          <div class="puntos-clave-head"><span class="material-icons">push_pin</span><strong>Para recordar</strong></div>
          <ul>${cap.puntosClave.map((p) => `<li>${inline(p)}</li>`).join("")}</ul>
        </div>`);
    }
    return partes.join("");
  }

  function capitulosTematicos(proceso) {
    return (proceso.capitulosLibro || []).map((cap, i) => {
      let html = "";
      if (cap.tipo === "paso-a-seguir") {
        html = renderGuiaPasoASeguir(proceso, cap.grupo) || `<div class="aviso-vacio"><p>Este capítulo está pendiente de documentación.</p></div>`;
      } else if (cap.tipo === "texto") {
        html = cap.md ? `<div class="prosa">${mdToHtml(String(cap.md))}</div>` : "";
      } else if (cap.tipo === "capas") {
        html = `<div class="mapa-infografia-wrap"><div class="infog-timeline">${renderCapasComoFlujo(proceso.capas || [])}</div></div>`;
      } else if (cap.tipo === "mapa-procedencias") {
        html = renderMapaProcedencias(proceso, cap);
      } else if (cap.tipo === "factura-financiera") {
        html = renderFacturaFinanciera(proceso);
      } else if (cap.tipo === "envio-dian") {
        html = renderEnvioDian(proceso, cap);
      } else if (cap.tipo === "envio-recepcion") {
        html = renderEnvioRecepcion(proceso, cap);
      } else if (cap.tipo === "radicacion-cartera") {
        html = renderRadicacionCartera(proceso, cap);
      } else if (cap.tipo === "validacion-ministerio") {
        html = renderValidacionMinisterio(proceso, cap);
      } else if (cap.tipo === "fevrips-masivo") {
        html = renderFevripsMasivo(proceso, cap);
      } else if (cap.tipo === "guia-rapida") {
        html = renderGuiaRapida(proceso);
      } else if (cap.tipo === "semaforo") {
        html = renderSemaforo(proceso, cap);
      } else if (cap.tipo === "flujo") {
        const flujo = (proceso.flujos || []).find((f) => f.id === cap.flujoId);
        html = flujo
          ? `<div class="mapa-infografia-wrap">${renderFlujoBloque(flujo)}</div>`
          : `<div class="aviso-vacio"><p>El flujo está pendiente de documentación.</p></div>`;
      }
      return {
        id: cap.id || `tema-${i}`,
        kicker: cap.kicker || "Guía temática",
        title: cap.titulo || cap.nombre || `Tema ${i + 1}`,
        html: envolturaCapitulo(cap, html),
      };
    });
  }

  function escenasAyuda(proceso) {
    const out = [];
    (proceso.capas || []).forEach((capa, cIdx) => {
      (capa.controles || []).forEach((ctrl, pIdx) => {
        const sps = (ctrl.sps || [])
          .map((s) => `<li><code>${esc(s.nombre || "")}</code> · Método: <strong>${esc(s.metodo || "")}</strong> ${s.rol ? `<em>(${esc(s.rol)})</em>` : ""}</li>`)
          .join("");

        const invarianteHtml = ctrl.invariante
          ? `
          <div class="invariante-card">
            <div class="invariante-head">
              <span class="invariante-icon">⚠️</span>
              <strong>¿Qué debe cumplirse para avanzar?</strong>
            </div>
            <p class="invariante-body">${esc(ctrl.invariante)}</p>
            <div class="invariante-soporte">
              <span class="soporte-tag">💡 Tip de Soporte</span>
              <span>Si el sistema bloquea o no permite guardar, verifique primero que este requisito se encuentre activo y correcto.</span>
            </div>
          </div>
        `
          : "";

        const spsHtml = sps
          ? `
          <details class="tecnico-soporte">
            <summary><span class="tecnico-icon">🔧</span> Referencia técnica para soporte L3 / sistemas</summary>
            <div class="tecnico-contenido">
              <p class="tecnico-nota">Procedimientos y llamadas que ejecutan esta validación en el servidor:</p>
              <ul class="metodos">${sps}</ul>
            </div>
          </details>
        `
          : "";

        out.push({
          id: "ctrl-" + (ctrl.id || out.length),
          kicker: `Etapa ${capa.numero || cIdx + 1}: ${capa.nombre || "Operación"}`,
          title: ctrl.nombre || `Paso ${pIdx + 1}`,
          html: `
            <div class="prosa">
              <p>${esc(ctrl.explicacion || "")}</p>
            </div>
            ${invarianteHtml}
            ${spsHtml}
          `,
        });
      });
    });
    return out;
  }

  function armar(proceso, md, item) {
    const desc = obtenerDescripcionProceso(proceso, item);

    // Capítulo 1: Portada y Visión General (con Descripción 3 partes y Mapa Mental)
    const cap1 = portada(proceso, item, desc);

    // Capítulo 2 por defecto: mapa integral. Los procesos extensos pueden
    // declarar capitulosLibro para separar sus temas en capítulos propios.
    const cap2 = {
      id: "mapa-ilustrado",
      kicker: "Infografía de Ruta",
      title: "Flujo Ilustrativo del Proceso",
      html: mapaIlustrativoHtml(proceso),
    };

    // Capítulo 3: Botones y Ventanas Qrystalos2
    const cap3 = {
      id: "botones-ui",
      kicker: "Interfaz de Usuario",
      title: "Botones y Controles en Pantalla",
      html: `
        <div class="prosa">
          ${renderBotonesQuasar(proceso)}
        </div>
      `,
    };

    // Capítulo 4: Permisos de Usuario Requeridos
    const cap4 = {
      id: "permisos-modulo",
      kicker: "Seguridad y Roles",
      title: "Permisos Requeridos en el Módulo",
      html: `
        <div class="prosa">
          ${renderTablaPermisos(proceso)}
        </div>
      `,
    };

    // Capítulo 5: Variables del Sistema (USVGS)
    const cap5 = {
      id: "variables-modulo",
      kicker: "Configuración General",
      title: "Variables del Sistema (USVGS)",
      html: `
        <div class="prosa">
          ${renderTablaVariables(proceso)}
        </div>
      `,
    };

    const tematicos = capitulosTematicos(proceso);
    const cap = [cap1, ...(tematicos.length ? tematicos : [cap2]), cap3, cap4, cap5];

    // Si tiene Glosas y Devoluciones, agregar capítulo ilustrativo específico
    const tieneGlosasEnMd = /##\s+Glosas/i.test(md || "");
    const tieneCapituloPasoASeguir = (proceso.capitulosLibro || []).some((c) => c.tipo === "paso-a-seguir");
    if (proceso.glosasDevoluciones && !tieneGlosasEnMd && !tieneCapituloPasoASeguir) {
      cap.push({
        id: "glosas-devoluciones",
        kicker: "Reglas Operativas",
        title: "Glosas y Devoluciones — Pasos a Seguir",
        html: `
          <div class="prosa">
            ${renderGuiaPasoASeguir(proceso)}
          </div>
        `,
      });
    }

    // Agregar capítulos de PROCESO.md si existen y tienen contenido sustancial
    if (mdRico(md) && proceso.incluirProcesoMdEnLibro !== false) {
      cap.push(...escenasDeMd(md, proceso.nombre));
    }

    // Modo Pasos y Validaciones (ayuda):
    const ayuda = [cap1, ...(tematicos.length ? tematicos : [cap2]), ...escenasAyuda(proceso), cap4, cap5];

    return { cap, ayuda, fecha: proceso.actualizado };
  }

  function listaActiva() {
    if (!estado.paquete) return [];
    return estado.modo === "ayuda" ? estado.paquete.ayuda : estado.paquete.cap;
  }

  function renderHoja(e, i, total, nav, lista) {
    const fechaActualizado =
      estado.paquete && estado.paquete.fecha
        ? formatearFecha(estado.paquete.fecha)
        : "2 de oct de 2026";

    const ant = lista && i > 0 ? lista[i - 1] : null;
    const sig = lista && i < total - 1 ? lista[i + 1] : null;

    const navFinCapitulo = (ant || sig) ? `
      <div class="fin-capitulo-caja">
        <div class="fin-capitulo-header-label">
          <span class="material-icons">navigation</span>
          <span>Navegación entre Capítulos</span>
        </div>
        <div class="fin-capitulo-grid">
          ${
            ant
              ? `
            <button type="button" class="btn-fin-cap btn-fin-cap--prev" id="btnFinPrev" title="Regresar al capítulo anterior: ${esc(ant.title)}">
              <span class="material-icons fin-cap-ico">arrow_back</span>
              <div class="fin-cap-textos">
                <span class="fin-cap-sub">Capítulo Anterior (${i} de ${total})</span>
                <strong class="fin-cap-tit">${esc(ant.title)}</strong>
              </div>
            </button>
          `
              : `
            <div class="fin-cap-vacio">
              <span class="fin-cap-sub">Inicio del Documento</span>
              <span class="fin-cap-tit-vacio">Primer capítulo de la guía</span>
            </div>
          `
          }

          ${
            sig
              ? `
            <button type="button" class="btn-fin-cap btn-fin-cap--next" id="btnFinNext" title="Continuar al siguiente capítulo: ${esc(sig.title)}">
              <div class="fin-cap-textos fin-cap-textos--right">
                <span class="fin-cap-sub">Siguiente Capítulo (${i + 2} de ${total})</span>
                <strong class="fin-cap-tit">${esc(sig.title)}</strong>
              </div>
              <span class="material-icons fin-cap-ico">arrow_forward</span>
            </button>
          `
              : `
            <div class="fin-cap-completado">
              <span class="material-icons fin-cap-ico-ok">check_circle</span>
              <div class="fin-cap-textos">
                <span class="fin-cap-sub">¡Guía Completada!</span>
                <strong class="fin-cap-tit">Ha recorrido todos los capítulos</strong>
              </div>
            </div>
          `
          }
        </div>
      </div>
    ` : "";

    return `<div class="hoja-contenedor">
      <article class="hoja-documento">
        <header class="hoja-cabecera">
          <div class="hoja-kicker-fila">
            <span class="kicker">${esc(e.kicker)}</span>
            <span class="badge-paso">Capítulo ${i + 1} de ${total}</span>
          </div>
          <h1>${esc(e.title)}</h1>
        </header>

        <div class="hoja-cuerpo" id="paginaCuerpo">
          ${e.html}
        </div>

        ${navFinCapitulo}

        <footer class="hoja-pie">
          <div class="hoja-pie-izq">
            <span class="hoja-folio">Capítulo ${i + 1} de ${total}</span>
            <span class="hoja-fecha-pie">📅 Guía actualizada: ${esc(fechaActualizado)} · Apta para capacitación y soporte</span>
          </div>
          ${nav || ""}
        </footer>
      </article>
    </div>`;
  }

  function actualizarControlesModo() {
    const btnManual = $("#btnModoManual");
    const btnVal = $("#btnModoValidaciones");
    if (!btnManual || !btnVal) return;

    const esManual = estado.modo === "capacitacion";
    btnManual.classList.toggle("activo", esManual);
    btnVal.classList.toggle("activo", !esManual);
  }

  function activarEventosFlujos() {
    const tabs = document.querySelectorAll(".btn-flujo-tab");
    if (!tabs.length) return;
    tabs.forEach((tab) => {
      tab.onclick = () => {
        tabs.forEach((t) => t.classList.remove("activo"));
        tab.classList.add("activo");
        const target = tab.dataset.flujoTarget;
        const bloques = document.querySelectorAll(".flujo-bloque-completo");
        if (target === "todos") {
          bloques.forEach((b) => (b.style.display = "block"));
        } else {
          bloques.forEach((b) => {
            b.style.display = b.id === target ? "block" : "none";
          });
        }
      };
    });
  }

  function ubicarEnCabecera() {
    const escenario = $("#escenario");
    if (escenario) {
      escenario.scrollTop = 0;
    }
    window.scrollTo({ top: 0, left: 0, behavior: "instant" });
    document.documentElement.scrollTop = 0;
    document.body.scrollTop = 0;

    const cabecera = document.querySelector(".hoja-cabecera");
    if (cabecera) {
      cabecera.scrollIntoView({ behavior: "instant", block: "start" });
    }
  }

  function pintarEscena() {
    const lista = listaActiva();
    const i = Math.max(0, Math.min(estado.escena, lista.length - 1));
    estado.escena = i;
    const e = lista[i];
    const escenario = $("#escenario");
    if (!e) {
      escenario.innerHTML = `<div class="aviso-vacio"><p>No hay contenido disponible para este capítulo.</p></div>`;
      return;
    }

    const nav = `<div class="nav-lectura">
      <button type="button" class="btn btn-nav" id="leerPrev" ${i === 0 ? "disabled" : ""}>← Anterior</button>
      <span class="folio-centro">${i + 1} / ${lista.length}</span>
      <button type="button" class="btn btn-nav btn-primario" id="leerNext" ${i === lista.length - 1 ? "disabled" : ""}>Siguiente →</button>
    </div>`;

    escenario.innerHTML = renderHoja(e, i, lista.length, nav, lista);
    activarEventosFlujos();

    $("#leerPrev").onclick = () => ir(i - 1);
    $("#leerNext").onclick = () => ir(i + 1);

    const btnFinPrev = $("#btnFinPrev");
    if (btnFinPrev) btnFinPrev.onclick = () => ir(i - 1);
    const btnFinNext = $("#btnFinNext");
    if (btnFinNext) btnFinNext.onclick = () => ir(i + 1);

    // Actualizar indicador de presentación
    $("#pieProgreso").textContent = `${i + 1} de ${lista.length}`;
    const barra = $("#barraRelleno");
    if (barra && lista.length) {
      const pct = Math.round(((i + 1) / lista.length) * 100);
      barra.style.width = pct + "%";
    }

    document.querySelectorAll(".escena-link").forEach((b) => {
      b.classList.toggle("activo", Number(b.dataset.i) === i);
    });

    // Ubicar en el encabezado
    ubicarEnCabecera();
    setTimeout(ubicarEnCabecera, 0);
  }

  function pintarIndiceEscenas() {
    const wrap = $("#escenasAnidadas");
    if (!wrap) return;
    const lista = listaActiva();
    if (!lista || lista.length === 0) {
      wrap.innerHTML = "";
      return;
    }

    wrap.innerHTML = `
      <div class="escenas-cabecera">Capítulos (${lista.length})</div>
      ${lista
        .map(
          (e, i) => `
        <button type="button" class="escena-link ${i === estado.escena ? "activo" : ""}" data-i="${i}" title="${esc(e.title)}">
          <span class="escena-num">${i + 1}</span>
          <span class="escena-txt">${esc(e.title)}</span>
        </button>
      `
        )
        .join("")}
    `;

    wrap.querySelectorAll(".escena-link").forEach((b) => {
      b.onclick = (ev) => {
        ev.stopPropagation();
        ir(Number(b.dataset.i));
      };
    });
  }

  function ir(n, desdeHash) {
    const lista = listaActiva();
    const tope = Math.max(0, lista.length - 1);
    estado.escena = Math.max(0, Math.min(n, tope));
    if (!desdeHash && estado.id) {
      const next = "#" + estado.id + "/" + estado.escena;
      if (location.hash !== next) location.hash = estado.id + "/" + estado.escena;
    }
    pintarEscena();
  }

  window.addEventListener("hashchange", () => {
    const [id, n] = (location.hash || "").replace(/^#/, "").split("/");
    if (!id) {
      mostrarPortada();
      return;
    }
    const escena = Number(n) || 0;
    if (id !== estado.id) abrir(id, escena);
    else ir(escena, true);
  });

  function pintarEstante() {
    const grupos = new Map();
    const filtro = (estado.filtro || "").trim().toLowerCase();
    const todos = estado.indice.procesos || [];
    let visCount = 0;

    todos.forEach((p) => {
      if (filtro) {
        const txt = [p.nombre, p.modulo, p.familia, p.resumen].join(" ").toLowerCase();
        if (!txt.includes(filtro)) return;
      }
      visCount++;
      const f = p.familia || "otros";
      if (!grupos.has(f)) grupos.set(f, []);
      grupos.get(f).push(p);
    });

    const badgeContador = $("#indiceContador");
    if (badgeContador) {
      badgeContador.textContent = filtro ? `${visCount} de ${todos.length}` : `${todos.length} Módulos`;
    }

    if (grupos.size === 0) {
      $("#listaProcesos").innerHTML = `
        <div class="sin-resultados">
          <p>No se encontraron procesos que coincidan con <strong>"${esc(estado.filtro)}"</strong></p>
        </div>
      `;
      actualizarBotonToggleTodos();
      return;
    }

    // Si hay un proceso activo, asegurar que su familia esté expandida
    const famActiva = familiaDeProceso(estado.id);
    if (famActiva) {
      estado.familiasAbiertas.add(famActiva);
    }

    const hayFiltro = Boolean(filtro);

    const html = [...grupos.entries()]
      .map(([f, items]) => {
        const iconoFamilia = ICONOS_FAMILIA[f] || "folder_open";
        // Si hay búsqueda activa, expandir automáticamente para ver los resultados
        const abierta = hayFiltro || estado.familiasAbiertas.has(f);

        const itemsHtml = items
          .map((p) => {
            const activo = p.id === estado.id;
            const moduloTag = p.modulo ? `<span class="proc-modulo-tag">${esc(p.modulo)}</span>` : "";
            const subtexto = p.resumen || p.modulo || "Módulo del sistema";
            return `
              <div class="proc-item-wrap">
                <button type="button" class="proc ${activo ? "activo" : ""}" data-id="${esc(p.id)}" title="${esc(p.nombre)} (${esc(p.modulo || '')})">
                  <span class="proc-indicador"></span>
                  <div class="proc-cuerpo">
                    <div class="proc-head">
                      <span class="proc-nombre">${esc(p.nombre)}</span>
                      ${moduloTag}
                    </div>
                    <span class="proc-sub">${esc(subtexto)}</span>
                  </div>
                </button>
                ${activo ? `<div class="escenas-anidadas" id="escenasAnidadas"></div>` : ""}
              </div>
            `;
          })
          .join("");

        return `
          <div class="familia-bloque ${abierta ? "abierta" : "cerrada"}" data-familia="${esc(f)}">
            <button type="button" class="familia-header" data-familia="${esc(f)}" aria-expanded="${abierta ? "true" : "false"}" title="${abierta ? "Recoger categoría (clic para contraer)" : "Expandir categoría (clic para ver módulos)"}">
              <div class="familia-tit-wrap">
                <span class="material-icons familia-ico">${iconoFamilia}</span>
                <span class="familia-txt">${esc(familiaNombre(f))}</span>
              </div>
              <div class="familia-meta">
                <span class="familia-badge">${items.length}</span>
                <span class="material-icons familia-chevron">chevron_right</span>
              </div>
            </button>
            <div class="familia-items" style="${abierta ? "" : "display: none;"}">
              ${itemsHtml}
            </div>
          </div>
        `;
      })
      .join("");

    $("#listaProcesos").innerHTML = html;

    // Asignar eventos de clic en los encabezados de familia (acordeón expandir/recoger)
    $("#listaProcesos").querySelectorAll(".familia-header[data-familia]").forEach((btn) => {
      btn.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        const f = btn.dataset.familia;
        const bloque = btn.closest(".familia-bloque");
        toggleFamilia(f, bloque);
      };
    });

    // Asignar eventos de clic en los procesos
    $("#listaProcesos").querySelectorAll(".proc[data-id]").forEach((b) => {
      b.onclick = (e) => {
        e.stopPropagation();
        const idProc = b.dataset.id;
        if (idProc === estado.id) {
          ir(0);
        } else {
          abrir(idProc, 0);
          location.hash = `#${idProc}/0`;
        }
      };
    });

    actualizarBotonToggleTodos();
  }

  function toggleFamilia(f, bloqueEl) {
    if (!bloqueEl) {
      bloqueEl = Array.from($("#listaProcesos")?.querySelectorAll(".familia-bloque") || []).find(
        (b) => b.dataset.familia === f
      );
    }
    const estabaAbierta = bloqueEl ? bloqueEl.classList.contains("abierta") : estado.familiasAbiertas.has(f);
    const ahoraAbierta = !estabaAbierta;

    if (ahoraAbierta) {
      estado.familiasAbiertas.add(f);
    } else {
      estado.familiasAbiertas.delete(f);
    }

    if (bloqueEl) {
      bloqueEl.classList.toggle("abierta", ahoraAbierta);
      bloqueEl.classList.toggle("cerrada", !ahoraAbierta);

      const btn = bloqueEl.querySelector(".familia-header");
      if (btn) {
        btn.setAttribute("aria-expanded", String(ahoraAbierta));
        btn.title = ahoraAbierta
          ? "Recoger categoría (clic para contraer)"
          : "Expandir categoría (clic para ver módulos)";
      }

      const itemsCont = bloqueEl.querySelector(".familia-items");
      if (itemsCont) {
        itemsCont.style.display = ahoraAbierta ? "" : "none";
      }
    }
    actualizarBotonToggleTodos();
  }

  function toggleTodasFamilias() {
    const bloques = $("#listaProcesos")?.querySelectorAll(".familia-bloque") || [];
    if (bloques.length === 0) return;

    // Si al menos una está cerrada, abrimos todas; si todas están abiertas, recogemos todas
    const hayCerradas = Array.from(bloques).some((b) => b.classList.contains("cerrada"));
    const nuevoEstado = hayCerradas;

    bloques.forEach((b) => {
      const f = b.dataset.familia;
      if (nuevoEstado) {
        estado.familiasAbiertas.add(f);
      } else {
        estado.familiasAbiertas.delete(f);
      }
      b.classList.toggle("abierta", nuevoEstado);
      b.classList.toggle("cerrada", !nuevoEstado);

      const btn = b.querySelector(".familia-header");
      if (btn) {
        btn.setAttribute("aria-expanded", String(nuevoEstado));
        btn.title = nuevoEstado
          ? "Recoger categoría (clic para contraer)"
          : "Expandir categoría (clic para ver módulos)";
      }

      const itemsCont = b.querySelector(".familia-items");
      if (itemsCont) {
        itemsCont.style.display = nuevoEstado ? "" : "none";
      }
    });

    actualizarBotonToggleTodos();
  }

  function actualizarBotonToggleTodos() {
    const btn = $("#btnToggleTodos");
    const ico = $("#icoToggleTodos");
    if (!btn || !ico) return;
    const bloques = $("#listaProcesos")?.querySelectorAll(".familia-bloque") || [];
    if (bloques.length === 0) {
      btn.style.display = "none";
      return;
    }
    btn.style.display = "";
    const todasAbiertas = Array.from(bloques).every((b) => b.classList.contains("abierta"));
    ico.textContent = todasAbiertas ? "unfold_less" : "unfold_more";
    btn.title = todasAbiertas ? "Recoger todas las categorías" : "Expandir todas las categorías";
  }

  async function abrir(id, escena) {
    estado.id = id;
    estado.escena = escena || 0;
    const fam = familiaDeProceso(id);
    if (fam) {
      estado.familiasAbiertas.add(fam);
    }
    const escenario = $("#escenario");
    if (escenario) {
      escenario.innerHTML = `
        <div class="cargando-box">
          <div class="spinner"></div>
          <p>Abriendo guía del proceso…</p>
        </div>
      `;
    }

    const item = (estado.indice.procesos || []).find((p) => p.id === id) || { id, nombre: id };
    const carpeta = item.carpeta || id;

    try {
      const [pr, mdRes] = await Promise.all([
        traer("/conocimiento/" + encodeURIComponent(carpeta) + "/proceso.json").then((r) => r.json()),
        traer("/conocimiento/" + encodeURIComponent(carpeta) + "/PROCESO.md").then((r) => r.text()).catch(() => ""),
      ]);

      estado.paquete = armar(pr, mdRes, item);

      $("#btnActualizar").hidden = false;
      $("#btnPresentar").hidden = false;
      $("#conmutadorModo").hidden = false;
      actualizarControlesModo();

      $("#topNota").textContent = `${pr.nombre || item.nombre} · Guía interactiva`;

      pintarEstante();
      pintarIndiceEscenas();
      pintarEscena();
    } catch (err) {
      escenario.innerHTML = renderHoja(
        {
          kicker: "Aviso",
          title: "No se pudo cargar la información",
          html: `
            <div class="prosa">
              <p>Ocurrió un inconveniente al consultar la información de este módulo:</p>
              <div class="cita-box"><span class="cita-ico">⚠️</span><div class="cita-body">${esc(err.message)}</div></div>
              <p>Verifique que el servidor de Qrystalos BA se encuentre en ejecución y vuelva a intentar.</p>
              <p><button type="button" class="btn btn-primario" onclick="location.reload()">Reintentar</button></p>
            </div>
          `,
        },
        0,
        1,
        ""
      );
    }
  }

  function setPresentar(on) {
    estado.presentar = on;
    document.body.classList.toggle("presentando", on);
    $("#piePresentar").hidden = !on;
    const btnPres = $("#btnPresentar");
    if (btnPres) {
      btnPres.innerHTML = on ? '<span class="ico">✕</span> Salir' : '<span class="ico">🖥️</span> Presentar';
      btnPres.classList.toggle("btn-activo", on);
    }
  }

  function logoQrystalosSvg(size = 46) {
    return `
      <svg class="qrys-logo-iso" viewBox="0 0 100 100" width="${size}" height="${size}" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="12" y="12" width="60" height="60" rx="14" stroke="#1565C0" stroke-width="12" stroke-linejoin="round"/>
        <path d="M72 48 H84 V62 H98 V74 H84 V88 H72 V74 H58 V62 H72 V48 Z" fill="#F97316"/>
      </svg>
    `;
  }

  function renderPortadaInicio() {
    return `
      <div class="hoja-contenedor">
        <article class="hoja-documento hoja-inicio">
          
          <!-- Hero de Marca Dual: Qrystalos + IX Colombia SAS -->
          <div class="tapa-hero">
            <div class="tapa-marcas-fila">
              <div class="tapa-marca-principal">
                <div class="tapa-logo-wrap">
                  ${logoQrystalosSvg(44)}
                </div>
                <div class="tapa-marca-meta">
                  <div class="tapa-marca-nombre">
                    <span>Qrysta</span><em>los</em> <strong>ERP</strong>
                  </div>
                  <span class="tapa-marca-sub">Software Asistencial, Administrativo y Contable</span>
                </div>
              </div>

              <div class="tapa-badges-corp">
                <span class="badge-corp-ix">
                  <span class="material-icons" style="font-size:0.95rem;">business</span>
                  IX COLOMBIA SAS · Information Experts
                </span>
                <span class="badge-corp-qrys">
                  <span class="material-icons" style="font-size:0.95rem;">verified</span>
                  Plataforma Hospitalaria v2.0
                </span>
              </div>
            </div>

            <h1 class="tapa-titulo">Guía Integral de Procesos, Operación y Capacitación</h1>
            <p class="tapa-desc">
              Centro de conocimiento oficial para clínicas, hospitales e instituciones prestadoras de salud (IPS).
              Consulte el flujo operativo paso a paso de cada módulo, los requisitos necesarios para avanzar en pantalla,
              permisos de seguridad <strong>USGRUH</strong>, variables del sistema <strong>USVGS</strong> y plantillas estándar para cargas masivas.
            </p>

            <!-- Lema Institucional Oficial de Qrystalos -->
            <div class="tapa-lema-box">
              <span class="tapa-lema-ico">❝</span>
              <span>No cuentes los días, haz que los días cuenten. <strong>— IX Colombia SAS</strong></span>
            </div>
          </div>

          <!-- Métricas e Indicadores Clave del Ecosistema -->
          <div class="tapa-kpis-grid">
            <div class="kpi-card kpi-card--azul">
              <div class="kpi-ico-wrap"><span class="material-icons">local_hospital</span></div>
              <div class="kpi-info">
                <span class="kpi-valor">+25 Módulos</span>
                <span class="kpi-label">Asistencial & Administrativo</span>
              </div>
            </div>

            <div class="kpi-card kpi-card--naranja">
              <div class="kpi-ico-wrap"><span class="material-icons">lock</span></div>
              <div class="kpi-info">
                <span class="kpi-valor">100% Candados</span>
                <span class="kpi-label">Reglas, USGRUH y USVGS</span>
              </div>
            </div>

            <div class="kpi-card kpi-card--verde">
              <div class="kpi-ico-wrap"><span class="material-icons">description</span></div>
              <div class="kpi-info">
                <span class="kpi-valor">DIAN & Res. 2275</span>
                <span class="kpi-label">Factura Electrónica y RIPS</span>
              </div>
            </div>

            <div class="kpi-card kpi-card--indigo">
              <div class="kpi-ico-wrap"><span class="material-icons">school</span></div>
              <div class="kpi-info">
                <span class="kpi-valor">2 Perspectivas</span>
                <span class="kpi-label">Manual y Soporte L1/L2/L3</span>
              </div>
            </div>
          </div>

          <!-- Módulos de Mayor Consulta (Acceso Directo Clicable) -->
          <div class="tapa-seccion-header">
            <div class="tapa-seccion-tit-box">
              <span class="material-icons tapa-seccion-ico">bolt</span>
              <h2 class="tapa-seccion-titulo">Módulos de Mayor Consulta (Acceso Rápido)</h2>
            </div>
            <span class="tapa-seccion-sub">Haga clic en cualquier tarjeta para abrir su guía completa:</span>
          </div>

          <div class="tapa-modulos-grid">
            <div class="modulo-card-inicio" data-ir-proceso="facturacion">
              <div class="modulo-card-ico" style="background:#eff6ff; color:#1565c0;"><span class="material-icons">receipt_long</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Facturación & RIPS</strong>
                <span class="modulo-card-desc">Citas, evento, emisión DIAN y JSON Res. 2275</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="recaudos">
              <div class="modulo-card-ico" style="background:#fff7ed; color:#ea580c;"><span class="material-icons">payments</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Cartera · Recaudos</strong>
                <span class="modulo-card-desc">Asignación, plantilla Excel y giros ADRES</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="caja">
              <div class="modulo-card-ico" style="background:#f0fdf4; color:#16a34a;"><span class="material-icons">point_of_sale</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Caja y Recibos</strong>
                <span class="modulo-card-desc">Apertura de turno, copagos, egresos y arqueo</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="glosas">
              <div class="modulo-card-ico" style="background:#faf5ff; color:#7e22ce;"><span class="material-icons">gavel</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Cartera · Glosas</strong>
                <span class="modulo-card-desc">Recepción, respuesta auditoría y notas crédito</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="notas-dbcr">
              <div class="modulo-card-ico" style="background:#fff1f2; color:#be123c;"><span class="material-icons">receipt</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Notas Débito / Crédito</strong>
                <span class="modulo-card-desc">Ajustes a facturas, CUDE DIAN y contabilidad</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="bancos">
              <div class="modulo-card-ico" style="background:#f0fdfa; color:#0f766e;"><span class="material-icons">account_balance</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Tesorería · Bancos</strong>
                <span class="modulo-card-desc">Extractos, legalización y conciliación bancaria</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="contabilidad">
              <div class="modulo-card-ico" style="background:#eef2ff; color:#3730a3;"><span class="material-icons">pie_chart</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Contabilidad & Cierres</strong>
                <span class="modulo-card-desc">Asientos PUC, causación CxP y balances mayores</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>

            <div class="modulo-card-inicio" data-ir-proceso="inventario">
              <div class="modulo-card-ico" style="background:#f0fdf4; color:#15803d;"><span class="material-icons">inventory_2</span></div>
              <div class="modulo-card-info">
                <strong class="modulo-card-titulo">Inventario & Farmacia</strong>
                <span class="modulo-card-desc">Entradas de compra, dispensación y kardex</span>
              </div>
              <span class="modulo-card-flecha">➜</span>
            </div>
          </div>

          <!-- Metodología de Uso -->
          <div class="tapa-seccion-header">
            <div class="tapa-seccion-tit-box">
              <span class="material-icons tapa-seccion-ico">tips_and_updates</span>
              <h2 class="tapa-seccion-titulo">Cómo Aprovechar esta Guía Interactiva</h2>
            </div>
            <span class="tapa-seccion-sub">Tres recomendaciones para usuarios y líderes de área</span>
          </div>

          <div class="tapa-pasos-inicio">
            <div class="paso-inicio-card">
              <div class="paso-inicio-num">1</div>
              <strong>Navegación Intuitiva</strong>
              <span>Seleccione cualquier módulo en el estante lateral organizado por familias asistenciales o utilice el buscador superior con filtrado reactivo.</span>
            </div>
            <div class="paso-inicio-card">
              <div class="paso-inicio-num">2</div>
              <strong>Doble Perspectiva</strong>
              <span>Alterne entre <strong>📖 Manual de uso</strong> para entender el flujo paso a paso o <strong>📋 Pasos y validaciones</strong> para resolver dudas de soporte e invariantes.</span>
            </div>
            <div class="paso-inicio-card">
              <div class="paso-inicio-num">3</div>
              <strong>Capacitación en Pantalla</strong>
              <span>Active el modo <strong>🖥️ Presentar</strong> para proyectar la guía como diapositivas ejecutivas en inducciones a nuevos colaboradores o reuniones de comité.</span>
            </div>
          </div>

          <!-- Footer Oficial Corporativo -->
          <div class="tapa-footer-corp">
            <div class="tapa-footer-meta">
              <strong>IX COLOMBIA SAS — Expertos en Soluciones Hospitalarias</strong>
              <span>Soluciones de software especializado para IPS, EPS, Clínicas y Centros Médicos desde 2001.</span>
            </div>
            <div class="tapa-footer-enlaces">
              <a class="btn-link-corp btn-link-corp--ix" href="https://www.ixcolombia.com/" target="_blank" rel="noopener">
                <span class="material-icons" style="font-size:0.95rem;">open_in_new</span>
                Portal Corporativo IX
              </a>
              <a class="btn-link-corp btn-link-corp--qrys" href="https://qrystalos.com/#/autenticarse" target="_blank" rel="noopener">
                <span class="material-icons" style="font-size:0.95rem;">lock</span>
                Acceso Qrystalos Web
              </a>
            </div>
          </div>

        </article>
      </div>
    `;
  }

  function activarEventosPortada() {
    const contenedor = $("#escenario");
    if (!contenedor) return;
    contenedor.querySelectorAll("[data-ir-proceso]").forEach((btn) => {
      btn.onclick = () => {
        const idProc = btn.getAttribute("data-ir-proceso");
        if (idProc) {
          abrir(idProc, 0);
          location.hash = `#${idProc}/0`;
        }
      };
    });
  }

  function mostrarPortada() {
    estado.id = null;
    estado.escena = 0;
    estado.paquete = null;

    $("#btnActualizar").hidden = true;
    $("#btnPresentar").hidden = true;
    $("#conmutadorModo").hidden = true;
    $("#topNota").textContent = "Manual de uso, capacitación interactiva y reglas de validación para usuarios y soporte.";

    const escenario = $("#escenario");
    if (escenario) {
      escenario.innerHTML = renderPortadaInicio();
      activarEventosPortada();
    }
    pintarEstante();
    pintarIndiceEscenas();
  }

  async function inicio() {
    try {
      estado.indice = await (await traer("/conocimiento/INDICE.json")).json();
      pintarEstante();

      // Buscador reactivo
      const filtroInput = $("#filtroProcesos");
      if (filtroInput) {
        filtroInput.addEventListener("input", (e) => {
          estado.filtro = e.target.value;
          pintarEstante();
        });
      }

      const hash = (location.hash || "").replace(/^#/, "");
      const [id, n] = hash.split("/");
      if (id) {
        await abrir(id, Number(n) || 0);
      } else {
        mostrarPortada();
      }
    } catch (err) {
      $("#escenario").innerHTML = renderHoja(
        {
          kicker: "Inicio",
          title: "Bienvenido a la Guía de Procesos",
          html: `
            <div class="prosa">
              <p>No se pudo conectar con el catálogo de procesos:</p>
              <p><code>${esc(err.message)}</code></p>
              <p>Asegúrese de abrir esta página a través del servidor activo (<a href="/app/">Inicio</a>).</p>
            </div>
          `,
        },
        0,
        1,
        ""
      );
    }
  }

  // Eventos de botones
  $("#btnActualizar").onclick = () => estado.id && abrir(estado.id, estado.escena);
  $("#btnPresentar").onclick = () => setPresentar(!estado.presentar);
  $("#btnSalir").onclick = () => setPresentar(false);
  $("#btnPrev").onclick = () => ir(estado.escena - 1);
  $("#btnNext").onclick = () => ir(estado.escena + 1);
  const btnToggleTodos = $("#btnToggleTodos");
  if (btnToggleTodos) {
    btnToggleTodos.onclick = () => toggleTodasFamilias();
  }

  // Conmutador de modo
  $("#btnModoManual").onclick = () => {
    if (estado.modo === "capacitacion") return;
    estado.modo = "capacitacion";
    actualizarControlesModo();
    estado.escena = 0;
    pintarIndiceEscenas();
    pintarEscena();
  };

  $("#btnModoValidaciones").onclick = () => {
    if (estado.modo === "ayuda") return;
    estado.modo = "ayuda";
    actualizarControlesModo();
    estado.escena = 0;
    pintarIndiceEscenas();
    pintarEscena();
  };

  // Ampliar ilustraciones (sketchnotes) a pantalla completa con un clic
  let lightbox = null;
  function cerrarLightbox() {
    if (lightbox) {
      lightbox.remove();
      lightbox = null;
      document.body.classList.remove("lightbox-abierto");
    }
  }
  function abrirLightbox(src, alt) {
    cerrarLightbox();
    lightbox = document.createElement("div");
    lightbox.className = "img-lightbox";
    lightbox.innerHTML = `
      <div class="img-lightbox-barra">
        <span>${esc(alt || "")}</span>
        <small>Rueda del ratón o desplazamiento para recorrer · Esc o clic fuera para cerrar</small>
        <button type="button" class="img-lightbox-cerrar" aria-label="Cerrar"><span class="material-icons">close</span></button>
      </div>
      <div class="img-lightbox-scroll"><img src="${esc(src)}" alt="${esc(alt || "")}" /></div>`;
    lightbox.addEventListener("click", (ev) => {
      if (ev.target.closest(".img-lightbox-cerrar") || !ev.target.closest("img")) cerrarLightbox();
    });
    document.body.appendChild(lightbox);
    document.body.classList.add("lightbox-abierto");
  }
  document.addEventListener("click", (ev) => {
    const img = ev.target.closest(".img-ilustracion-wrap img, img.img-ilustracion");
    if (!img || ev.target.closest(".img-lightbox")) return;
    abrirLightbox(img.getAttribute("src"), img.getAttribute("alt"));
  });

  // Teclado
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && lightbox) {
      cerrarLightbox();
      return;
    }
    if (lightbox) return;
    if (ev.target.tagName === "INPUT" || ev.target.tagName === "TEXTAREA") return;
    if (ev.key === "ArrowRight") ir(estado.escena + 1);
    if (ev.key === "ArrowLeft") ir(estado.escena - 1);
    if (ev.key === "Escape" && estado.presentar) setPresentar(false);
    if ((ev.key === "f" || ev.key === "F") && !ev.ctrlKey && !ev.altKey) {
      setPresentar(!estado.presentar);
    }
  });

  inicio();
})();