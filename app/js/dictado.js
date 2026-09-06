/**
 * Dictado por voz — Web Speech API (Chrome / Edge)
 */
window.QrysDictado = (function () {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  let recognition = null;
  let targetField = null;
  let onStatus = null;

  function supported() {
    return !!SpeechRecognition;
  }

  function init(statusCallback) {
    onStatus = statusCallback;
    if (!supported()) {
      onStatus?.("Dictado no disponible en este navegador. Use Chrome o Edge.");
      return false;
    }
    recognition = new SpeechRecognition();
    recognition.lang = "es-CO";
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onresult = (event) => {
      let transcript = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      if (targetField && event.results[event.results.length - 1].isFinal) {
        const sep = targetField.value && !targetField.value.endsWith(" ") ? " " : "";
        targetField.value += sep + transcript.trim();
        targetField.dispatchEvent(new Event("input", { bubbles: true }));
      }
    };

    recognition.onerror = (e) => onStatus?.(`Error dictado: ${e.error}`);
    recognition.onend = () => onStatus?.("");
    return true;
  }

  function start(textareaEl) {
    if (!recognition) return false;
    targetField = textareaEl;
    try {
      recognition.start();
      onStatus?.("Escuchando… hable ahora");
      return true;
    } catch {
      return false;
    }
  }

  function stop() {
    recognition?.stop();
    onStatus?.("");
  }

  return { supported, init, start, stop };
})();
