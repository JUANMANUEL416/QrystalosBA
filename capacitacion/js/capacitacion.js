(function () {
  const DATA_URL = "datos/caja-cajero.json?v=8";
  const STORAGE_KEY = "qrystalos-capacitacion-caja";

  const state = {
    course: null,
    lessonIndex: 0,
    mode: "aprender",
    completed: new Set(),
    checks: {},
    narrator: {
      speaking: false,
      paused: false,
      index: 0,
      segments: [],
      walkIndex: -1,
    },
  };

  let spanishVoice = null;

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function loadProgress() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      state.completed = new Set(Array.isArray(saved.completed) ? saved.completed : []);
      state.checks = saved.checks && typeof saved.checks === "object" ? saved.checks : {};
      if (Number.isInteger(saved.lessonIndex)) state.lessonIndex = saved.lessonIndex;
    } catch (_) {
      state.completed = new Set();
      state.checks = {};
    }
  }

  function saveProgress() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      completed: Array.from(state.completed),
      checks: state.checks,
      lessonIndex: state.lessonIndex,
    }));
  }

  function list(items, ordered, className) {
    if (!Array.isArray(items) || !items.length) return "";
    const tag = ordered ? "ol" : "ul";
    return `<${tag}${className ? ` class="${className}"` : ""}>${items
      .map((item) => `<li>${escapeHtml(item)}</li>`)
      .join("")}</${tag}>`;
  }

  function card(title, icon, content, wide) {
    return `<article class="card${wide ? " card-wide" : ""}">
      <h3><span class="material-symbols-outlined">${icon}</span>${escapeHtml(title)}</h3>
      ${content}
    </article>`;
  }

  function callout(type, icon, text) {
    if (!text) return "";
    return `<div class="callout callout-${type}">
      <span class="material-symbols-outlined">${icon}</span>
      <p>${escapeHtml(text)}</p>
    </div>`;
  }

  function frame(image, alt, emptyTitle, emptyText) {
    if (image) {
      return `<img src="${escapeHtml(image)}" alt="${escapeHtml(alt)}"
          onerror="this.closest('.window-media').innerHTML='<div class=&quot;capture-placeholder&quot;><span class=&quot;material-symbols-outlined&quot;>broken_image</span><strong>Captura no disponible</strong><p>Verifique el archivo configurado para esta lección.</p></div>'">`;
    }
    return `<div class="capture-placeholder">
      <span class="material-symbols-outlined">add_a_photo</span>
      <strong>${escapeHtml(emptyTitle)}</strong>
      <p>${escapeHtml(emptyText)}</p>
    </div>`;
  }

  function windowPair(win, lessonTitle) {
    const path = win.path || "Administrativo → Caja";
    const button = win.button || "El control de esta lección";
    const howCaption = win.imageHowCaption || `Pulse «${button}».`;
    const resultCaption = win.caption || "Ventana que se abre después de pulsar el control.";

    return `<div class="path-bar">
        <span class="path-label">Cómo llegar</span>
        <span>${escapeHtml(path)}</span>
        <span class="path-arrow">→</span>
        <strong>${escapeHtml(button)}</strong>
      </div>
      <div class="window-pair">
        <figure class="window-step">
          <figcaption><span class="step-badge">1</span> Pulse este control</figcaption>
          <div class="window-media">${frame(win.imageHow, win.altHow || button, "Falta la foto del botón", "Se capturará el control en la pantalla, no solo el diálogo.")}</div>
          <p class="window-caption">${escapeHtml(howCaption)}</p>
        </figure>
        <div class="window-pair-arrow" aria-hidden="true">
          <span class="material-symbols-outlined">arrow_forward</span>
        </div>
        <figure class="window-step">
          <figcaption><span class="step-badge step-badge-result">2</span> Se abre esta ventana</figcaption>
          <div class="window-media">${frame(win.image, win.alt || lessonTitle, "Ventana real pendiente de capturar", "Se incorporará desde el ambiente de pruebas, sin datos personales ni credenciales.")}</div>
          <p class="window-caption">${escapeHtml(resultCaption)}</p>
        </figure>
      </div>`;
  }

  function capture(lesson) {
    const win = lesson.window || {};
    const extras = Array.isArray(win.extra) ? win.extra : [];

    return `<article class="card card-wide window-card">
      <div class="window-toolbar">
        <span>${escapeHtml(win.name || "Ventana de Qrystalos")}</span>
        <code>${escapeHtml(win.route || "")}</code>
      </div>
      ${windowPair(win, lesson.title)}
      ${extras.map((extra) => windowPair(extra, extra.name || lesson.title)).join("")}
    </article>`;
  }

  function narrationSegments(lesson) {
    const errors = (lesson.commonErrors || []).filter(Boolean).join(". ");
    const business = String(lesson.businessNote || "").trim();
    const extras = [];
    if (errors) extras.push({ title: "Errores frecuentes", text: errors });
    if (business) extras.push({ title: "Lectura de negocio", text: business });

    const catalogSpeech = [];
    if (lesson.catalog && Array.isArray(lesson.catalog.groups)) {
      lesson.catalog.groups.forEach((group) => {
        (group.items || []).forEach((item) => {
          const variable = item.variable ? ` Variable ${item.variable}.` : "";
          const text = `${item.hace || ""}${variable}`.trim();
          if (text) catalogSpeech.push({ title: item.name, text });
        });
      });
    }

    if (Array.isArray(lesson.narration) && lesson.narration.length) {
      const custom = lesson.narration
        .map((item) => ({
          title: item.title || "",
          text: String(item.text || "").trim(),
        }))
        .filter((item) => item.text);
      const titles = new Set(custom.map((item) => item.title.toLowerCase()));
      catalogSpeech.forEach((item) => {
        if (!titles.has(item.title.toLowerCase())) custom.push(item);
      });
      extras.forEach((extra) => {
        if (!titles.has(extra.title.toLowerCase())) custom.push(extra);
      });
      return custom;
    }

    return [
      { title: lesson.title, text: lesson.theory },
      { title: "Cómo se hace", text: (lesson.steps || []).join(". ") },
      { title: "Qué debe ocurrir", text: lesson.expected },
      ...catalogSpeech,
      ...extras,
    ].filter((item) => item.text);
  }

  function walkthroughCard(lesson) {
    const walk = lesson.walkthrough;
    if (!walk || !Array.isArray(walk.clips) || !walk.clips.length) return "";
    const first = walk.clips[0];
    const dots = walk.clips.map((_, index) =>
      `<button type="button" class="walk-dot${index === 0 ? " active" : ""}" data-walk-index="${index}" aria-label="Paso ${index + 1}"></button>`
    ).join("");

    return `<article class="card card-wide walkthrough-card">
      <div class="walkthrough-toolbar">
        <div>
          <span class="path-label">Video guiado</span>
          <strong>${escapeHtml(walk.title || "Paso a paso")}</strong>
        </div>
        <div class="walkthrough-actions">
          <button type="button" class="btn btn-primary" id="btnWalkPlay">
            <span class="material-symbols-outlined">play_circle</span>
            Reproducir con narrador
          </button>
        </div>
      </div>
      <figure class="walkthrough-stage">
        <div class="window-media">
          <img id="walkImage" src="${escapeHtml(first.image || "")}" alt="${escapeHtml(first.caption || walk.title || "")}">
        </div>
        <figcaption>
          <span class="step-badge" id="walkStep">1 / ${walk.clips.length}</span>
          <span id="walkCaption">${escapeHtml(first.caption || "")}</span>
        </figcaption>
      </figure>
      <p class="walkthrough-line" id="walkLine">${escapeHtml(first.text || walk.source || "")}</p>
      <div class="walkthrough-dots" id="walkDots">${dots}</div>
      <p class="walkthrough-source">${escapeHtml(walk.source || "")}</p>
    </article>`;
  }

  function catalogCard(lesson) {
    const catalog = lesson.catalog;
    if (!catalog || !Array.isArray(catalog.groups) || !catalog.groups.length) return "";
    const groups = catalog.groups.map((group) => {
      const items = (group.items || []).map((item) => `<li>
        <strong>${escapeHtml(item.name)}</strong>
        ${item.variable ? `<code>${escapeHtml(item.variable)}</code>` : ""}
        <p>${escapeHtml(item.hace || "")}</p>
      </li>`).join("");
      return `<div class="catalog-group">
        <h4>${escapeHtml(group.title)}</h4>
        <ul class="catalog-list">${items}</ul>
      </div>`;
    }).join("");
    return `<article class="card card-wide catalog-card">
      <h3><span class="material-symbols-outlined">account_tree</span>${escapeHtml(catalog.title || "Tipos y variables")}</h3>
      ${catalog.intro ? `<p>${escapeHtml(catalog.intro)}</p>` : ""}
      <div class="catalog-grid">${groups}</div>
    </article>`;
  }

  function renderLearn(lesson) {
    return `<div class="content-grid">
      ${card("Idea clave", "lightbulb", `<p>${escapeHtml(lesson.theory)}</p>`, false)}
      ${card("Antes de comenzar", "rule", list(lesson.prerequisites, false), false)}
      ${catalogCard(lesson)}
      ${walkthroughCard(lesson)}
      ${capture(lesson)}
      ${card("Recorrido en la ventana", "touch_app", list(lesson.steps, true, "steps"), true)}
      ${card("Resultado esperado", "verified", `<p>${escapeHtml(lesson.expected)}</p>`, false)}
      ${card("Errores frecuentes", "warning", list(lesson.commonErrors, false), false)}
      <div class="card-wide">${callout("info", "info", lesson.businessNote)}</div>
    </div>`;
  }

  function renderInstructor(lesson) {
    const instructor = lesson.instructor || {};
    return `<div class="content-grid">
      ${card("Mensaje para explicar", "record_voice_over", `<p>${escapeHtml(instructor.message)}</p>`, true)}
      ${capture(lesson)}
      ${card("Demostración", "co_present", list(instructor.demo, true, "steps"), false)}
      ${card("Preguntas al aprendiz", "quiz", list(instructor.questions, false), false)}
      ${card("Punto de control", "fact_check", `<p>${escapeHtml(instructor.control)}</p>`, true)}
      <div class="card-wide">${callout("warning", "privacy_tip", instructor.warning)}</div>
    </div>`;
  }

  function renderPractice(lesson) {
    const practice = lesson.practice || {};
    const lessonChecks = state.checks[lesson.id] || {};
    const checklist = (practice.checklist || []).map((item, index) => {
      const checked = Boolean(lessonChecks[index]);
      return `<li><label>
        <input type="checkbox" data-check-index="${index}" ${checked ? "checked" : ""}>
        <span>${escapeHtml(item)}</span>
      </label></li>`;
    }).join("");

    return `<div class="content-grid">
      ${card("Caso de práctica", "assignment", `<p>${escapeHtml(practice.scenario)}</p>`, true)}
      ${card("Tarea", "play_circle", list(practice.tasks, true, "steps"), false)}
      ${card("Criterio de aprobación", "workspace_premium", list(practice.success, false), false)}
      ${card("Lista de verificación", "checklist", `<ul class="checklist">${checklist}</ul>`, true)}
      <div class="card-wide">${callout("danger", "gpp_maybe", practice.doNot)}</div>
    </div>`;
  }

  function renderNavigation() {
    const lessons = state.course.lessons;
    $("#lessonNav").innerHTML = lessons.map((lesson, index) => {
      const complete = state.completed.has(lesson.id);
      return `<button type="button" class="lesson-link${index === state.lessonIndex ? " active" : ""}${complete ? " complete" : ""}" data-lesson="${index}">
        <span class="lesson-number">${complete ? "✓" : index + 1}</span>
        <span class="nav-title">${escapeHtml(lesson.shortTitle || lesson.title)}</span>
        ${complete ? '<span class="material-symbols-outlined nav-check">verified</span>' : ""}
      </button>`;
    }).join("");

    $$(".lesson-link").forEach((button) => {
      button.addEventListener("click", () => {
        state.lessonIndex = Number(button.dataset.lesson);
        saveProgress();
        render();
      });
    });
  }

  function renderProgress() {
    const total = state.course.lessons.length;
    const completed = state.course.lessons.filter((lesson) => state.completed.has(lesson.id)).length;
    const percent = total ? Math.round((completed / total) * 100) : 0;
    $("#progressLabel").textContent = `${percent}%`;
    $("#progressFill").style.width = `${percent}%`;
  }

  function render() {
    stopNarrator();
    const lessons = state.course.lessons;
    state.lessonIndex = Math.min(Math.max(state.lessonIndex, 0), lessons.length - 1);
    const lesson = lessons[state.lessonIndex];

    $("#lessonStep").textContent = `Lección ${state.lessonIndex + 1} de ${lessons.length}`;
    $("#lessonTitle").textContent = lesson.title;
    $("#lessonObjective").textContent = lesson.objective;
    $("#lessonDuration").textContent = lesson.duration;

    const renderers = {
      aprender: renderLearn,
      instructor: renderInstructor,
      practica: renderPractice,
    };
    $("#lessonContent").innerHTML = renderers[state.mode](lesson);

    const completed = state.completed.has(lesson.id);
    const completeButton = $("#btnComplete");
    completeButton.classList.toggle("done", completed);
    completeButton.innerHTML = completed
      ? '<span class="material-symbols-outlined">check_circle</span>Lección completada'
      : '<span class="material-symbols-outlined">check_circle</span>Marcar como completada';

    $("#btnPrev").disabled = state.lessonIndex === 0;
    $("#btnNext").disabled = state.lessonIndex === lessons.length - 1;
    renderNavigation();
    renderProgress();
    bindChecklist(lesson);
    bindWalkthrough(lesson);
    updateNarrateButton();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function pickSpanishVoice() {
    const voices = window.speechSynthesis ? window.speechSynthesis.getVoices() : [];
    spanishVoice = voices.find((voice) => /^es-CO/i.test(voice.lang))
      || voices.find((voice) => /^es-MX/i.test(voice.lang))
      || voices.find((voice) => /^es-ES/i.test(voice.lang))
      || voices.find((voice) => /^es/i.test(voice.lang))
      || null;
    return spanishVoice;
  }

  function stopNarrator() {
    if (window.speechSynthesis) window.speechSynthesis.cancel();
    state.narrator.speaking = false;
    state.narrator.paused = false;
    state.narrator.index = 0;
    state.narrator.segments = [];
    state.narrator.walkIndex = -1;
    updateNarrateButton();
    const play = $("#btnWalkPlay");
    if (play) {
      play.innerHTML = '<span class="material-symbols-outlined">play_circle</span>Reproducir con narrador';
    }
  }

  function updateNarrateButton() {
    const button = $("#btnNarrate");
    const icon = $("#narrateIcon");
    const label = $("#narrateLabel");
    if (!button || !icon || !label) return;
    button.disabled = !("speechSynthesis" in window);
    button.setAttribute("aria-pressed", state.narrator.speaking ? "true" : "false");
    if (state.narrator.speaking && state.narrator.paused) {
      icon.textContent = "play_arrow";
      label.textContent = "Continuar narración";
    } else if (state.narrator.speaking) {
      icon.textContent = "stop_circle";
      label.textContent = "Detener narrador";
    } else {
      icon.textContent = "volume_up";
      label.textContent = "Escuchar lección";
    }
  }

  function showWalkClip(lesson, index) {
    const clips = lesson.walkthrough && lesson.walkthrough.clips ? lesson.walkthrough.clips : [];
    if (!clips[index]) return;
    const clip = clips[index];
    const image = $("#walkImage");
    const caption = $("#walkCaption");
    const line = $("#walkLine");
    const step = $("#walkStep");
    if (image) {
      image.src = clip.image || "";
      image.alt = clip.caption || "";
    }
    if (caption) caption.textContent = clip.caption || "";
    if (line) line.textContent = clip.text || "";
    if (step) step.textContent = `${index + 1} / ${clips.length}`;
    $$(".walk-dot").forEach((dot, dotIndex) => {
      dot.classList.toggle("active", dotIndex === index);
    });
    state.narrator.walkIndex = index;
  }

  function speakQueue(segments, onEvery, onDone) {
    if (!("speechSynthesis" in window)) {
      if (onDone) onDone();
      return;
    }
    window.speechSynthesis.cancel();
    pickSpanishVoice();
    state.narrator.segments = segments;
    state.narrator.speaking = true;
    state.narrator.paused = false;
    updateNarrateButton();

    segments.forEach((segment, index) => {
      const spoken = [segment.title, segment.text].filter(Boolean).join(". ");
      const utterance = new SpeechSynthesisUtterance(spoken);
      utterance.lang = (spanishVoice && spanishVoice.lang) || "es-CO";
      utterance.rate = 0.95;
      utterance.pitch = 1;
      if (spanishVoice) utterance.voice = spanishVoice;
      utterance.onstart = () => {
        state.narrator.index = index;
        if (onEvery) onEvery(segment, index);
      };
      utterance.onend = () => {
        if (index === segments.length - 1) {
          state.narrator.speaking = false;
          state.narrator.paused = false;
          updateNarrateButton();
          if (onDone) onDone();
        }
      };
      utterance.onerror = () => {
        state.narrator.speaking = false;
        state.narrator.paused = false;
        updateNarrateButton();
      };
      window.speechSynthesis.speak(utterance);
    });
  }

  function narrateLesson() {
    const lesson = state.course.lessons[state.lessonIndex];
    if (state.narrator.speaking && !state.narrator.paused) {
      stopNarrator();
      return;
    }
    if (state.narrator.speaking && state.narrator.paused) {
      window.speechSynthesis.resume();
      state.narrator.paused = false;
      updateNarrateButton();
      return;
    }
    speakQueue(narrationSegments(lesson));
  }

  function playWalkthrough(lesson) {
    const clips = lesson.walkthrough && lesson.walkthrough.clips ? lesson.walkthrough.clips : [];
    if (!clips.length) return;
    if (state.narrator.speaking) {
      stopNarrator();
      return;
    }
    const play = $("#btnWalkPlay");
    if (play) {
      play.innerHTML = '<span class="material-symbols-outlined">stop_circle</span>Detener';
    }
    const segments = clips.map((clip, index) => ({
      title: clip.caption || `Paso ${index + 1}`,
      text: clip.text || "",
      walkIndex: index,
    }));
    showWalkClip(lesson, 0);
    speakQueue(segments, (segment) => {
      showWalkClip(lesson, segment.walkIndex);
    }, () => {
      const button = $("#btnWalkPlay");
      if (button) {
        button.innerHTML = '<span class="material-symbols-outlined">play_circle</span>Reproducir con narrador';
      }
    });
  }

  function bindWalkthrough(lesson) {
    const play = $("#btnWalkPlay");
    if (play) {
      play.addEventListener("click", () => playWalkthrough(lesson));
    }
    $$("[data-walk-index]").forEach((dot) => {
      dot.addEventListener("click", () => {
        if (state.narrator.speaking) stopNarrator();
        showWalkClip(lesson, Number(dot.dataset.walkIndex));
      });
    });
  }

  function bindChecklist(lesson) {
    $$("[data-check-index]").forEach((checkbox) => {
      checkbox.addEventListener("change", () => {
        const checks = state.checks[lesson.id] || {};
        checks[Number(checkbox.dataset.checkIndex)] = checkbox.checked;
        state.checks[lesson.id] = checks;
        saveProgress();
      });
    });
  }

  function bind() {
    $$(".mode-tab").forEach((button) => {
      button.addEventListener("click", () => {
        state.mode = button.dataset.mode;
        $$(".mode-tab").forEach((item) => item.classList.toggle("active", item === button));
        render();
      });
    });

    $("#btnPrev").addEventListener("click", () => {
      if (state.lessonIndex > 0) {
        state.lessonIndex -= 1;
        saveProgress();
        render();
      }
    });

    $("#btnNext").addEventListener("click", () => {
      if (state.lessonIndex < state.course.lessons.length - 1) {
        state.lessonIndex += 1;
        saveProgress();
        render();
      }
    });

    $("#btnComplete").addEventListener("click", () => {
      const lesson = state.course.lessons[state.lessonIndex];
      if (state.completed.has(lesson.id)) state.completed.delete(lesson.id);
      else state.completed.add(lesson.id);
      saveProgress();
      render();
    });

    $("#btnPrint").addEventListener("click", () => window.print());
    $("#btnNarrate").addEventListener("click", narrateLesson);
    if (window.speechSynthesis) {
      pickSpanishVoice();
      window.speechSynthesis.addEventListener("voiceschanged", pickSpanishVoice);
    }
  }

  async function init() {
    loadProgress();
    try {
      const response = await fetch(DATA_URL, { cache: "no-store" });
      if (!response.ok) throw new Error(`No se encontró ${DATA_URL} (${response.status}).`);
      state.course = await response.json();
      if (!Array.isArray(state.course.lessons) || !state.course.lessons.length) {
        throw new Error("El curso no contiene lecciones.");
      }

      $("#courseTitle").textContent = state.course.title;
      $("#courseAudience").textContent = state.course.audience;
      $("#loading").hidden = true;
      $("#loading").setAttribute("aria-hidden", "true");
      $("#courseView").hidden = false;
      bind();
      render();
    } catch (error) {
      $("#loading").hidden = true;
      $("#loading").setAttribute("aria-hidden", "true");
      $("#error").hidden = false;
      $("#error").removeAttribute("aria-hidden");
      $("#errorMessage").textContent = error.message;
    }
  }

  init();
})();
