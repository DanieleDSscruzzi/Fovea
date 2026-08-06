//
//  fovea.js — Fovea per Safari
//  By D.S.
//
//  Stesse due protezioni dell'app, su qualsiasi sito.
//
//  Il trucco che tiene in piedi tutto: non tocchiamo il DOM della pagina.
//  Un solo <div> fisso sopra tutto, con backdrop-filter, sfoca e scurisce
//  quello che sta sotto. Zero conflitti con il CSS del sito, zero reflow,
//  funziona su pagine che non abbiamo mai visto.
//

(() => {
  "use strict";
  if (window.__foveaAttivo) return;
  window.__foveaAttivo = true;

  const CFG = {
    clearAngle: 15,      // gradi: sotto, in chiaro
    opaqueAngle: 36,     // sopra, illeggibile
    maxBlur: 14,         // px di backdrop-filter
    maxDim: 0.90,
    lensRadius: 92,      // px del foro sotto il dito
    reanchorAfter: 4000, // ms di posa stabile prima di riagganciare
    smoothing: 0.3
  };

  const stato = {
    angolo: false,
    lente: false,
    soglia: 0,           // 0 = spenta, altrimenti livello di contrasto
    armato: false,       // permesso sensori concesso su questa origine
    esposizione: 0,
    riferimento: null,
    fermoDa: null,
    dito: null
  };

  // ------------------------------------------------------------ elementi

  const velo = document.createElement("div");
  velo.className = "fovea-strato";

  const pulsante = document.createElement("button");
  pulsante.className = "fovea-innesco";
  pulsante.type = "button";
  pulsante.setAttribute("aria-label", "Attiva Fovea su questa pagina");

  function monta() {
    if (!document.documentElement) return;
    document.documentElement.appendChild(velo);
    document.documentElement.appendChild(pulsante);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", monta, { once: true });
  } else {
    monta();
  }

  // ------------------------------------------------------------ resa

  function disegna() {
    const e = stato.esposizione;
    const foro = stato.lente && stato.dito;

    if (e < 0.004 && !foro) {
      velo.style.opacity = "0";
      velo.style.backdropFilter = "none";
      velo.style.webkitBackdropFilter = "none";
      return;
    }

    velo.style.opacity = "1";

    // L'angolo e la lente si sommano: la lente garantisce sempre un minimo
    // di copertura fuori dal dito, l'angolo la alza inclinando il telefono.
    const sfocatura = Math.max(e * CFG.maxBlur, foro ? 9 : 0);
    const buio = Math.max(e * CFG.maxDim, foro ? 0.55 : 0);

    const f = `blur(${sfocatura.toFixed(1)}px)`;
    velo.style.backdropFilter = f;
    velo.style.webkitBackdropFilter = f;
    velo.style.background = `rgba(8, 9, 12, ${buio.toFixed(3)})`;

    if (foro) {
      // Il foro non è un ritaglio del contenuto: è un buco nel velo.
      // Il sito sotto resta intatto e perfettamente nitido lì dentro.
      const m = `radial-gradient(circle ${CFG.lensRadius}px at ` +
                `${stato.dito.x}px ${stato.dito.y}px, ` +
                `transparent 0%, transparent 58%, black 100%)`;
      velo.style.webkitMaskImage = m;
      velo.style.maskImage = m;
    } else {
      velo.style.webkitMaskImage = "none";
      velo.style.maskImage = "none";
    }
  }

  // ------------------------------------------------------------ angolo

  function normale(alpha, beta, gamma) {
    // Normale allo schermo nel sistema terrestre, dalla matrice ZXY del W3C.
    const r = Math.PI / 180;
    const a = alpha * r, b = beta * r, g = gamma * r;
    const cA = Math.cos(a), sA = Math.sin(a);
    const cB = Math.cos(b), sB = Math.sin(b);
    const cG = Math.cos(g), sG = Math.sin(g);
    return [
      cA * sG + sA * sB * cG,
      sA * sG - cA * sB * cG,
      cB * cG
    ];
  }

  function rampa(gradi) {
    const t = Math.min(Math.max(
      (gradi - CFG.clearAngle) / (CFG.opaqueAngle - CFG.clearAngle), 0), 1);
    return t * t * (3 - 2 * t);   // smoothstep, come nell'app
  }

  function suOrientamento(ev) {
    if (!stato.angolo || ev.alpha === null) return;

    const n = normale(ev.alpha, ev.beta, ev.gamma);
    if (!stato.riferimento) { stato.riferimento = n; return; }

    const r = stato.riferimento;
    const d = Math.min(Math.max(n[0] * r[0] + n[1] * r[1] + n[2] * r[2], -1), 1);
    const gradi = Math.acos(d) * 180 / Math.PI;

    stato.esposizione += (rampa(gradi) - stato.esposizione) * CFG.smoothing;

    // Riaggancio: senza, la deriva della mano ti oscura la pagina dopo
    // qualche minuto e sembra un difetto del sito.
    if (gradi < CFG.clearAngle * 0.5) {
      if (!stato.fermoDa) stato.fermoDa = Date.now();
      else if (Date.now() - stato.fermoDa > CFG.reanchorAfter) {
        stato.riferimento = n;
        stato.fermoDa = Date.now();
      }
    } else {
      stato.fermoDa = null;
    }

    disegna();
  }

  // Su iOS il permesso ai sensori richiede un gesto dell'utente e vale per
  // questa origine. Per questo esiste il pallino: è l'unico modo.
  async function arma() {
    const DOE = window.DeviceOrientationEvent;
    if (DOE && typeof DOE.requestPermission === "function") {
      try {
        const esito = await DOE.requestPermission();
        if (esito !== "granted") return false;
      } catch (_) {
        return false;
      }
    }
    window.addEventListener("deviceorientation", suOrientamento, true);
    stato.armato = true;
    stato.riferimento = null;
    return true;
  }

  // ------------------------------------------------------------ lente

  function segui(ev) {
    if (!stato.lente) return;
    const p = ev.touches ? ev.touches[0] : ev;
    if (!p) return;
    stato.dito = { x: p.clientX, y: p.clientY };
    disegna();
  }

  function lascia() {
    if (!stato.lente) return;
    stato.dito = null;
    disegna();
  }

  // passive: non rubiamo mai lo scorrimento alla pagina.
  const opz = { passive: true, capture: true };
  document.addEventListener("touchstart", segui, opz);
  document.addEventListener("touchmove", segui, opz);
  document.addEventListener("touchend", lascia, opz);
  document.addEventListener("mousemove", segui, opz);

  // ------------------------------------------------------------ soglia

  // Abbassa il contrasto dell'intera pagina fino a poco sopra la soglia di
  // leggibilità di chi guarda in asse. Chi sta di lato è più lontano e riceve
  // meno luce dal pannello: lo stesso testo, per lui, cade sotto soglia.
  function applicaSoglia() {
    const root = document.documentElement;
    if (!root) return;
    if (!stato.soglia) {
      root.style.removeProperty("filter");
      return;
    }
    const k = Math.min(Math.max(stato.soglia, 0.12), 1);
    root.style.setProperty(
      "filter", `contrast(${k.toFixed(2)}) brightness(${(0.45 + k * 0.55).toFixed(2)})`,
      "important");
  }

  // ------------------------------------------------------------ comandi

  pulsante.addEventListener("click", async (ev) => {
    ev.preventDefault();
    ev.stopPropagation();
    if (stato.armato) {
      // Secondo tocco: ritara qui.
      stato.riferimento = null;
      pulsante.classList.add("fovea-tarato");
      setTimeout(() => pulsante.classList.remove("fovea-tarato"), 700);
      return;
    }
    const ok = await arma();
    pulsante.classList.toggle("fovea-acceso", ok);
    if (!ok) pulsante.classList.add("fovea-negato");
  });

  function applica(prefs) {
    stato.angolo = prefs.angolo !== false;
    stato.lente = prefs.lente === true;
    stato.soglia = typeof prefs.soglia === "number" ? prefs.soglia : 0;
    applicaSoglia();
    pulsante.style.display = stato.angolo ? "block" : "none";
    if (!stato.angolo) { stato.esposizione = 0; }
    disegna();
  }

  const api = window.browser || window.chrome;

  // Un solo messaggio al nativo: serve a far sapere all'app che
  // l'estensione è accesa. Non contiene nulla della pagina.
  if (api && api.runtime && api.runtime.sendMessage) {
    try { api.runtime.sendMessage({ ciao: 1 }); } catch (_) {}
  }

  if (api && api.storage) {
    api.storage.local.get(["angolo", "lente"]).then(applica).catch(() => applica({}));
    if (api.storage.onChanged) {
      api.storage.onChanged.addListener((mod) => {
        const p = {};
        for (const k in mod) p[k] = mod[k].newValue;
        applica(Object.assign({ angolo: stato.angolo, lente: stato.lente }, p));
      });
    }
  } else {
    applica({});
  }
})();
