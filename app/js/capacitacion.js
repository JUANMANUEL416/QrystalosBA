/**
 * Módulo de capacitaciones modulares tipo rompecabezas.
 * Permite seleccionar bloques por tema y ensamblar un documento de capacitación.
 */

window.QrysCapacitacion = (function() {
  'use strict';

  let temas = [];
  let bloques = [];
  let bloquesSeleccionados = new Set();
  let variantesSeleccionadas = {}; // {bloque_id: variante_id}
  let temaActual = null;
  let ensamblando = false;

  // Inicialización
  async function init() {
    console.log('[Capacitacion] Inicializando módulo...');
    
    try {
      await cargarTemas();
      renderizarVista();
    } catch (err) {
      console.error('[Capacitacion] Error al inicializar:', err);
      mostrarError('Error al cargar el módulo de capacitación');
    }
  }

  // Carga el catálogo de temas
  async function cargarTemas() {
    const resp = await fetch('/api/capacitacion/temas');
    const data = await resp.json();
    
    if (!data.ok) {
      throw new Error(data.error || 'Error al cargar temas');
    }
    
    temas = data.temas || [];
    console.log(`[Capacitacion] ${temas.length} temas cargados`);
  }

  // Carga los bloques de un tema
  async function cargarBloquesTema(temaId) {
    const resp = await fetch(`/api/capacitacion/bloques?tema=${encodeURIComponent(temaId)}`);
    const data = await resp.json();
    
    if (!data.ok) {
      throw new Error(data.error || 'Error al cargar bloques');
    }
    
    bloques = data.bloques || [];
    console.log(`[Capacitacion] ${bloques.length} bloques cargados para tema ${temaId}`);
    
    return bloques;
  }

  // Renderiza la vista principal
  function renderizarVista() {
    const container = document.querySelector('.capacitacion-container');
    if (!container) {
      console.warn('[Capacitacion] No se encontró el contenedor');
      return;
    }

    container.innerHTML = `
      <div class="capacitacion-header">
        <h2>Capacitaciones Modulares</h2>
        <p class="capacitacion-descripcion">
          Seleccione un tema y marque los bloques que desea incluir en el documento de capacitación.
          El sistema resolverá automáticamente las dependencias y generará el manual completo.
        </p>
      </div>

      <div class="capacitacion-content">
        <div class="capacitacion-temas">
          <h3>Temas disponibles</h3>
          <div class="temas-grid" id="temasGrid">
            ${renderizarTemas()}
          </div>
        </div>

        <div class="capacitacion-bloques" id="bloquesPanel" hidden>
          <div class="bloques-header">
            <h3 id="temaSeleccionadoTitulo">Bloques del tema</h3>
            <button class="btn btn-secundario" onclick="window.QrysCapacitacion.volverTemas()">
              ← Volver a temas
            </button>
          </div>

          <div class="bloques-lista" id="bloquesLista">
            <!-- Se llena dinámicamente -->
          </div>

          <div class="bloques-acciones">
            <div class="seleccionados-info">
              <span id="contadorSeleccionados">0 bloques seleccionados</span>
            </div>
            <button 
              class="btn btn-principal"
              id="btnEnsamblar"
              onclick="window.QrysCapacitacion.ensamblar()"
              disabled
            >
              <span class="material-symbols-outlined">description</span>
              Generar documento
            </button>
          </div>
        </div>

        <div class="capacitacion-resultado" id="resultadoPanel" hidden>
          <div class="resultado-exito">
            <span class="material-symbols-outlined">check_circle</span>
            <h3>Documento generado exitosamente</h3>
            <p id="resultadoMensaje"></p>
            <div class="resultado-acciones">
              <a id="resultadoLink" class="btn btn-principal" target="_blank">
                <span class="material-symbols-outlined">download</span>
                Descargar documento
              </a>
              <button class="btn btn-secundario" onclick="window.QrysCapacitacion.volverTemas()">
                Nueva capacitación
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  // Renderiza las tarjetas de temas
  function renderizarTemas() {
    return temas.map(tema => `
      <div 
        class="tema-card" 
        onclick="window.QrysCapacitacion.seleccionarTema('${tema.id}')"
        style="border-left: 4px solid ${tema.color}"
      >
        <div class="tema-icono">
          <span class="material-symbols-outlined">${tema.icono}</span>
        </div>
        <div class="tema-info">
          <h4>${tema.nombre}</h4>
          <p>${tema.descripcion}</p>
          <span class="tema-modulo">${tema.modulo}</span>
        </div>
      </div>
    `).join('');
  }

  // Selecciona un tema y carga sus bloques
  async function seleccionarTema(temaId) {
    temaActual = temas.find(t => t.id === temaId);
    if (!temaActual) {
      console.error('[Capacitacion] Tema no encontrado:', temaId);
      return;
    }

    console.log('[Capacitacion] Tema seleccionado:', temaActual.nombre);
    
    // Mostrar indicador de carga
    const bloquesPanel = document.getElementById('bloquesPanel');
    bloquesPanel.hidden = false;
    document.querySelector('.capacitacion-temas').hidden = true;
    
    const tituloElem = document.getElementById('temaSeleccionadoTitulo');
    tituloElem.textContent = `Bloques: ${temaActual.nombre}`;
    
    const lista = document.getElementById('bloquesLista');
    lista.innerHTML = '<div class="loading">Cargando bloques...</div>';

    try {
      await cargarBloquesTema(temaId);
      bloquesSeleccionados.clear();
      renderizarBloques();
    } catch (err) {
      console.error('[Capacitacion] Error al cargar bloques:', err);
      lista.innerHTML = `<div class="error">Error al cargar bloques: ${err.message}</div>`;
    }
  }

  // Renderiza la lista de bloques
  function renderizarBloques() {
    const lista = document.getElementById('bloquesLista');
    
    if (bloques.length === 0) {
      lista.innerHTML = `
        <div class="bloques-vacio">
          <span class="material-symbols-outlined">info</span>
          <p>No hay bloques disponibles para este tema aún.</p>
          <p class="text-secundario">Los bloques se generan desde la base de conocimiento.</p>
        </div>
      `;
      return;
    }

    lista.innerHTML = bloques.map((bloque, index) => {
      const tieneVariantes = bloque.variantes && bloque.variantes.length > 0;
      const seleccionado = bloquesSeleccionados.has(bloque.id);
      const varianteSeleccionada = variantesSeleccionadas[bloque.id];
      
      return `
      <div class="bloque-item ${seleccionado ? 'seleccionado' : ''}">
        <label class="bloque-checkbox">
          <input 
            type="checkbox" 
            value="${bloque.id}"
            ${seleccionado ? 'checked' : ''}
            onchange="window.QrysCapacitacion.toggleBloque('${bloque.id}')"
          />
          <span class="bloque-numero">${index + 1}</span>
        </label>
        
        <div class="bloque-info">
          <h4>${bloque.titulo}</h4>
          
          ${tieneVariantes && seleccionado ? `
            <div class="bloque-variantes-selector">
              <label class="variantes-label">
                <span class="material-symbols-outlined">alt_route</span>
                Variante:
              </label>
              <select 
                class="variantes-select" 
                onchange="window.QrysCapacitacion.seleccionarVariante('${bloque.id}', this.value)"
              >
                ${bloque.variantes.map(v => `
                  <option value="${v.id}" ${varianteSeleccionada === v.id ? 'selected' : ''}>
                    ${v.nombre}
                  </option>
                `).join('')}
              </select>
            </div>
          ` : ''}
          
          ${bloque.prerrequisitos && bloque.prerrequisitos.length > 0 ? `
            <div class="bloque-prereq">
              <span class="material-symbols-outlined">link</span>
              Requiere: ${bloque.prerrequisitos.map(p => {
                const prereq = bloques.find(b => b.id === p);
                return prereq ? prereq.titulo : p;
              }).join(', ')}
            </div>
          ` : ''}
          
          <div class="bloque-meta">
            <span class="bloque-duracion">
              <span class="material-symbols-outlined">schedule</span>
              ${bloque.duracionEstimada || '30min'}
            </span>
            
            ${tieneVariantes ? `
              <span class="bloque-variantes">
                <span class="material-symbols-outlined">alt_route</span>
                ${bloque.variantes.length} variante(s)
              </span>
            ` : ''}
            
            ${bloque.imagenes && bloque.imagenes.length > 0 ? `
              <span class="bloque-imagenes">
                <span class="material-symbols-outlined">image</span>
                ${bloque.imagenes.length} imagen(es)
              </span>
            ` : ''}
          </div>
        </div>
      </div>
      `;
    }).join('');

    actualizarContadorSeleccionados();
  }

  // Alterna la selección de un bloque
  function toggleBloque(bloqueId) {
    if (bloquesSeleccionados.has(bloqueId)) {
      bloquesSeleccionados.delete(bloqueId);
      delete variantesSeleccionadas[bloqueId];
    } else {
      bloquesSeleccionados.add(bloqueId);
      
      // Seleccionar variante por defecto si tiene
      const bloque = bloques.find(b => b.id === bloqueId);
      if (bloque && bloque.variantes && bloque.variantes.length > 0) {
        variantesSeleccionadas[bloqueId] = bloque.variantes[0].id;
      }
    }
    
    // Re-renderizar para mostrar/ocultar selector de variantes
    renderizarBloques();
  }
  
  // Selecciona una variante para un bloque
  function seleccionarVariante(bloqueId, varianteId) {
    if (bloquesSeleccionados.has(bloqueId)) {
      variantesSeleccionadas[bloqueId] = varianteId;
      console.log(`[Capacitacion] Variante seleccionada: ${bloqueId} -> ${varianteId}`);
    }
  }

  // Actualiza el contador y habilita/deshabilita el botón
  function actualizarContadorSeleccionados() {
    const contador = document.getElementById('contadorSeleccionados');
    const btnEnsamblar = document.getElementById('btnEnsamblar');
    
    const total = bloquesSeleccionados.size;
    contador.textContent = total === 1 
      ? '1 bloque seleccionado'
      : `${total} bloques seleccionados`;
    
    btnEnsamblar.disabled = total === 0 || ensamblando;
  }

  // Vuelve a la vista de temas
  function volverTemas() {
    document.getElementById('bloquesPanel').hidden = true;
    document.getElementById('resultadoPanel').hidden = true;
    document.querySelector('.capacitacion-temas').hidden = false;
    
    bloquesSeleccionados.clear();
    temaActual = null;
    bloques = [];
  }

  // Ensambla el documento de capacitación
  async function ensamblar() {
    if (bloquesSeleccionados.size === 0 || ensamblando) {
      return;
    }

    ensamblando = true;
    const btnEnsamblar = document.getElementById('btnEnsamblar');
    btnEnsamblar.disabled = true;
    btnEnsamblar.innerHTML = `
      <span class="spinner"></span>
      Generando documento...
    `;

    try {
      const resp = await fetch('/api/capacitacion/ensamblar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temaId: temaActual.id,
          bloquesIds: Array.from(bloquesSeleccionados),
          titulo: `Capacitación: ${temaActual.nombre}`,
          formato: 'html',
          incluirIndice: true,
          incluirImagenes: true,
          variantesSeleccionadas: variantesSeleccionadas
        })
      });

      const data = await resp.json();

      if (!data.ok) {
        throw new Error(data.error || 'Error al ensamblar el documento');
      }

      mostrarResultado(data);
    } catch (err) {
      console.error('[Capacitacion] Error al ensamblar:', err);
      mostrarError('Error al generar el documento: ' + err.message);
    } finally {
      ensamblando = false;
      btnEnsamblar.disabled = false;
      btnEnsamblar.innerHTML = `
        <span class="material-symbols-outlined">description</span>
        Generar documento
      `;
    }
  }

  // Muestra el resultado del ensamblado
  function mostrarResultado(data) {
    document.getElementById('bloquesPanel').hidden = true;
    
    const resultadoPanel = document.getElementById('resultadoPanel');
    resultadoPanel.hidden = false;

    const mensajeElem = document.getElementById('resultadoMensaje');
    const linkElem = document.getElementById('resultadoLink');

    let mensaje = `Se generó un documento con ${data.bloques.length} bloque(s).`;
    
    if (data.agregados && data.agregados.length > 0) {
      mensaje += ` Se agregaron automáticamente ${data.agregados.length} prerrequisito(s).`;
    }

    mensajeElem.textContent = mensaje;
    
    // El archivo está en capacitacion/documentos/
    const nombreArchivo = data.archivo_html.split('/').pop();
    linkElem.href = `/capacitacion/documentos/${nombreArchivo}`;
    
    console.log('[Capacitacion] Documento generado:', data.archivo_html);
  }

  // Muestra un error
  function mostrarError(mensaje) {
    alert(mensaje);
  }

  // API pública
  return {
    init,
    seleccionarTema,
    toggleBloque,
    seleccionarVariante,
    volverTemas,
    ensamblar
  };
})();

// Auto-inicializar cuando se entra al modo capacitacion
document.addEventListener('DOMContentLoaded', () => {
  const observer = new MutationObserver(() => {
    const container = document.querySelector('.capacitacion-container');
    if (container && !container.dataset.initialized) {
      container.dataset.initialized = 'true';
      window.QrysCapacitacion.init();
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
});
