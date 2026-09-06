/**
 * Criterios de aceptación — sugerencia desde requerimiento/análisis y comparación.
 */
window.QrysCriterios = (function () {
  function normalize(text) {
    return String(text || "")
      .toLowerCase()
      .replace(/[áàä]/g, "a")
      .replace(/[éèë]/g, "e")
      .replace(/[íìï]/g, "i")
      .replace(/[óòö]/g, "o")
      .replace(/[úùü]/g, "u")
      .replace(/ñ/g, "n")
      .replace(/[^a-z0-9\n]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function sonIguales(a, b) {
    return normalize(a) === normalize(b);
  }

  function esMayusculas(text) {
    const letters = String(text || "").replace(/[^A-Za-zÁÉÍÓÚÑáéíóúñ]/g, "");
    if (letters.length < 8) return false;
    const upper = (letters.match(/[A-ZÁÉÍÓÚÑ]/g) || []).length;
    return upper > letters.length * 0.55;
  }

  function sentenceCase(text) {
    let t = String(text || "").replace(/\s+/g, " ").trim();
    if (!t) return "";
    if (esMayusculas(t)) t = t.toLowerCase();
    return t.charAt(0).toUpperCase() + t.slice(1);
  }

  function capitalizar(s) {
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  function criteriosPorDominio(req, analisis) {
    const t = normalize(`${req} ${analisis}`);
    const out = [];

    if (/soat/.test(t) && (/factura|factur/.test(t) || /decimal/.test(t))) {
      out.push(
        "En admisiones tipo SOAT, el sistema no debe permitir generar factura si las prestaciones tienen decimales que no coincidan con el redondeo de la tarifa.",
      );
    } else if (/factura|factur/.test(t) && /decimal/.test(t)) {
      out.push(
        "El sistema no debe permitir generar factura si las prestaciones tienen decimales inconsistentes con la tarifa.",
      );
    }

    if (/redonde|ppt|tarifa/.test(t) || /contrato/.test(t)) {
      out.push(
        "Antes de cerrar la admisión, el sistema debe validar el redondeo contra la tarifa pactada en el contrato (PPT).",
      );
    }

    if (/excep/.test(t) && /prefijo/.test(t)) {
      out.push("La validación debe incluir las tarifas de excepción por prefijo.");
    }

    if (/excep/.test(t) && /servicio/.test(t)) {
      out.push("La validación debe incluir las tarifas de excepción por servicio.");
    }

    if (/copago/.test(t)) {
      out.push("El sistema debe validar los redondeos en la liquidación de copagos.");
    }

    if (/mostrar/.test(t) && (/tarifa|redonde|factor|plan|idplan|cargo/.test(t) || /hpre/.test(t))) {
      out.push(
        "En la pantalla de cargos, al lado del plan, se debe mostrar el código o descripción de la tarifa y el factor de redondeo.",
      );
    }

    if (/alta|cerrad|cerrar la admisi|alta admin/.test(t)) {
      out.push(
        "La validación debe ejecutarse en el alta administrativa; si hay error, no se cierra la admisión ni se factura.",
      );
    }

    if (/cursor|lento|performance|rapida|rápida|costos/.test(t) || /set.based|sin cursor/.test(t)) {
      out.push("La validación debe ser set-based, sin cursores ni recorridos costosos para el servidor.");
    }

    if (/spk_estado|estado_admi|estadohadm/.test(t)) {
      out.push("Si la validación falla, debe registrar el error y detener el flujo (no continuar a facturación).");
    }

    return out;
  }

  function frasesDelTexto(text) {
    return String(text || "")
      .replace(/\r/g, "")
      .split(/\n+|(?<=[.!?])\s+|(?<=;)\s+/)
      .map((s) => s.replace(/^[\s•\-–*\d.)]+/, "").trim())
      .filter((s) => s.length >= 20);
  }

  function aCriterio(frase) {
    let t = sentenceCase(frase).replace(/[.;,]+$/, "");
    if (!t) return "";

    t = t.replace(/^Se requiere que\s+/i, "");
    t = t.replace(/^Se requiere\s+/i, "");
    t = t.replace(/^Se debe\s+/i, "");

    if (/^(El sistema|El usuario|Debe |No debe |Validar |Mostrar |La validación)/i.test(t)) {
      return /[.]$/.test(t) ? t : t + ".";
    }
    if (/no permita|no permitir|no debe/i.test(t)) {
      const resto = t.replace(/^.*?(no permita|no permitir|no debe)\s+/i, "");
      return "El sistema no debe " + resto.charAt(0).toLowerCase() + resto.slice(1) + ".";
    }
    return "El sistema debe " + t.charAt(0).toLowerCase() + t.slice(1) + ".";
  }

  function agregarUnico(lista, seen, criterio) {
    const key = normalize(criterio);
    if (!criterio || key.length < 18 || seen.has(key)) return;
    seen.add(key);
    lista.push(criterio.replace(/\.+$/, ".") );
  }

  function sugerir(requerimiento, analisis, extra) {
    const lista = [];
    const seen = new Set();
    const contexto = [requerimiento, extra].filter(Boolean).join("\n");

    criteriosPorDominio(contexto, analisis).forEach((c) => agregarUnico(lista, seen, c));

    frasesDelTexto(contexto).forEach((u) => {
      if (lista.length >= 8) return;
      agregarUnico(lista, seen, aCriterio(u));
    });

    if (analisis) {
      frasesDelTexto(analisis).forEach((u) => {
        if (lista.length >= 10) return;
        if (/valid|redonde|mostrar|factura|alta|tarifa|excep|copago|ppt|no debe|permit/i.test(u)) {
          agregarUnico(lista, seen, aCriterio(u));
        }
      });
    }

    if (!lista.length && requerimiento.trim()) {
      agregarUnico(lista, seen, aCriterio(requerimiento.trim()));
    }

    return lista.map((c, i) => `${i + 1}. ${c}`).join("\n");
  }

  function emptyMeta() {
    return {
      originales: "",
      originalesEn: "",
      sugeridos: "",
      sugeridosEn: "",
      fuente: "",
      trasAnalisis: "",
      trasAnalisisEn: "",
      definitivos: "",
      validados: false,
      coinciden: null,
      validadosEn: "",
    };
  }

  function estadoLabel(meta, actuales) {
    if (!meta) return "Sin snapshot";
    if (meta.validados) {
      return meta.coinciden
        ? "Validados: coinciden con el snapshot de análisis"
        : "Validados: difieren del snapshot de análisis";
    }
    if (meta.trasAnalisis) {
      return sonIguales(meta.trasAnalisis, actuales)
        ? "Tras análisis — sin cambios"
        : "Editados después del análisis";
    }
    if (meta.sugeridos) {
      if (!String(actuales || "").trim()) return "Hay sugerencia (sin aplicar)";
      return sonIguales(meta.sugeridos, actuales)
        ? "Sugerencia aplicada — puede editar"
        : "Hay sugerencia (texto editado)";
    }
    if (meta.originales) return "Original capturado";
    return "Pendiente de sugerir";
  }

  function baselineCierre(meta) {
    return (meta.trasAnalisis || meta.sugeridos || meta.originales || "").trim();
  }

  return {
    normalize,
    sonIguales,
    sugerir,
    emptyMeta,
    estadoLabel,
    baselineCierre,
  };
})();
