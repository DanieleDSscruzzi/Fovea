// popup.js — le due levette. Lo stato vive in storage.local e il content
// script lo ascolta, così cambia su tutte le schede aperte insieme.
const api = window.browser || window.chrome;
const campi = ["angolo", "lente", "soglia"];

async function carica() {
  const p = await api.storage.local.get(campi);
  document.getElementById("angolo").checked = p.angolo !== false; // acceso di default
  document.getElementById("lente").checked = p.lente === true;
  // 0 sullo slider = soglia spenta, contrasto pieno.
  document.getElementById("soglia").value =
    p.soglia ? Math.round((1 - p.soglia) * 100) : 0;
}

["angolo", "lente"].forEach((k) => {
  document.getElementById(k).addEventListener("change", (e) => {
    api.storage.local.set({ [k]: e.target.checked });
  });
});

document.getElementById("soglia").addEventListener("input", (e) => {
  const v = Number(e.target.value);
  api.storage.local.set({ soglia: v === 0 ? 0 : 1 - v / 100 });
});

carica();
