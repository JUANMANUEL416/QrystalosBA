/**
 * Prompts Archify — diagrama de flujo (caso REQ y Consultas).
 * Cargar antes de app.js y conocimiento.js.
 */
(function (global) {
  function listarObjetosSql(d) {
    if (!d) return "(ninguno)";
    const sql = d.sql || {};
    if (sql.usarDocumentacion && sql.metodosDocumentados?.length) {
      return sql.metodosDocumentados
        .map((m) => `- ${m.sp} · METODO ${m.metodo}${m.hace ? ` — ${m.hace}` : ""}`)
        .join("\n");
    }
    const archivos = sql.archivosEsperados || [];
    const id = d.identificacion?.idCaso || "{id-caso}";
    if (archivos.length) return archivos.map((a) => `- activo/${id}/sql/${a}`).join("\n");
    return "(indique SP/METODO en el formulario o en Consultas)";
  }

  function buildPromptDiagramaArchify(opts) {
    const o = opts || {};
    const modo = o.modo === "consultas" ? "consultas" : "caso";
    const idCaso = o.idCaso || "{id-caso}";
    const idReq = o.idReq || "—";
    const procesoId = o.procesoId || "—";
    const procesoNombre = o.procesoNombre || procesoId;

    if (modo === "consultas") {
      return `# Diagrama de flujo — Archify (Consultas Qrystalos)

## Rol
Genera un diagrama **verificable** del proceso Qrystalos usando el skill **Archify** (tt-a1i/archify).
Modo recomendado: **workflow** o **architecture** según la pregunta.

## Módulo / proceso
- Proceso: **${procesoNombre}** (\`conocimiento/${procesoId}/\`)
- Leer: \`proceso.json\`, \`sps.json\`, \`PROCESO.md\` si existe

## Pregunta o alcance del diagrama
${o.pregunta?.trim() || "(describa qué flujo quiere ver: ej. confirmar recibo de caja, liquidar concepto nómina, radicar CXC…)"}

## Fuentes (leer en disco — no inventar)
- \`conocimiento/${procesoId}/proceso.json\` — controles y capas
- \`conocimiento/${procesoId}/sps.json\` — SP → METODO (hace, llama)
- Qrystalos2 solo si la ficha no alcanza para pantallas/rutas

## Qué debe mostrar el diagrama
- Pantallas Vue / rutas de menú (si aplica)
- \`AppStore.json\` → MODELO → **SPQ_**MODELO → METODO → **SPK_** / tablas
- Decisiones y errores KO relevantes
- Tablas principales afectadas (solo las documentadas)

## Entregable
1. Ejecutar Archify y generar **un HTML autocontenido**.
2. Guardar en: \`conocimiento/${procesoId}/diagramas/flujo.html\`
   (si ya existe, usar nombre descriptivo: \`flujo-confirmar-recibo.html\`)
3. Responder en el Chat de Consultas con:
   - Resumen en texto (2–4 párrafos)
   - Enlace al archivo: \`conocimiento/${procesoId}/diagramas/...\`

## Restricciones
- No inventar SP, columnas ni METODOs.
- Marcar incertidumbre si falta documentación.
- Español en etiquetas del diagrama.
`;
    }

    const dictamen = o.dictamenPath || `dictamenes/${idCaso}.html`;
    const diagramaDest = o.diagramaRuta || `activo/${idCaso}/diagramas/flujo.html`;

    return `# Diagrama de flujo — Archify (REQ ${idReq})

## Rol
Genera un diagrama **verificable** del cambio técnico usando el skill **Archify** (tt-a1i/archify).
Incluir el flujo **antes/después** si el REQ modifica un camino existente.

## Caso
- ID caso: ${idCaso} | REQ: ${idReq}
- Proyecto: ${o.proyecto || "—"} | Módulo: ${o.modulo || "—"}
- Pantalla: ${o.rutaPantalla || "—"}
- Proceso KB: ${procesoId !== "—" ? `\`conocimiento/${procesoId}/\`` : "(inferir de INDICE.json)"}

## Cambio (negocio)
${o.cambioPropuestoSimple?.trim() || "(ver solicitud.contenido.cambioPropuestoSimple o dictamen §5.0)"}

## Objetos SQL / METODO del REQ
${listarObjetosSql(o.data || { sql: o.sql })}

## Fuentes obligatorias
- Cola REQ: ${o.colaPath || "cola/"}
- Solicitud: \`activo/${idCaso}/solicitud.json\`
- Dictamen (borrador): \`${dictamen}\`
- Qrystalos2: componentes indicados en análisis
- \`conocimiento/${procesoId !== "—" ? procesoId : "{proceso}"}/sps.json\` si hay METODOs documentados

${o.notasDiagrama?.trim() ? `## Notas del coordinador\n${o.notasDiagrama.trim()}\n` : ""}
## Qué debe mostrar el diagrama
1. Punto de entrada usuario (pantalla / menú)
2. Llamadas FE → API → SPQ → METODO → SPK → tablas
3. Dónde aplica el cambio propuesto (resaltar)
4. Errores KO o validaciones críticas del REQ

## Entregable
1. HTML Archify autocontenido → subir en la app (paso Revisión → Diagrama de flujo) **o** guardar en:
   \`${diagramaDest}\`
2. Actualizar dictamen \`${dictamen}\` — **sección 4.5 Diagrama de flujo** con enlace relativo:
   \`<a href="diagramas/flujo.html">diagramas/flujo.html</a>\`
   (al cerrar fase 1 se copia a \`aprobados/${idCaso}/diagramas/\`)
3. Mencionar en \`activo/${idCaso}/chat.json\` que el diagrama quedó listo.

## Restricciones
- No inventar objetos SQL ni columnas.
- Español en etiquetas.
- Si no hay datos suficientes, detenerse y pedir SP o pantalla en el Chat del caso.
`;
  }

  function htmlSeccionDiagramaDictamen(idCaso, nombreArchivo) {
    const nom = (nombreArchivo || "flujo.html").trim() || "flujo.html";
    return `<p>Mapa del flujo técnico incrustado en este dictamen. Copia suelta: <a href="/dictamenes/${idCaso || ""}-flujo.html">${idCaso || "caso"}-flujo.html</a></p>
<p><strong><a href="diagramas/${nom}">diagramas/${nom}</a></strong></p>
<p style="color: var(--color-muted); font-size: 0.9rem;">Copia en entrega al desarrollador: <code>aprobados/${idCaso || "{id-caso}"}/diagramas/${nom}</code></p>`;
  }

  function htmlSeccionDiagramaVacio() {
    return `<p style="color: var(--color-muted);">No se generó diagrama de flujo para este REQ. El coordinador puede pulsar «Generar diagrama» en el paso Revisión (sale de conocimiento/ y del análisis) antes de cerrar fase 1.</p>`;
  }

  global.QrysPromptsFlujo = {
    buildPromptDiagramaArchify,
    htmlSeccionDiagramaDictamen,
    htmlSeccionDiagramaVacio,
    listarObjetosSql,
  };
})(typeof window !== "undefined" ? window : globalThis);
