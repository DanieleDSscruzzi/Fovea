# Fovea per Safari

Angolo e lente su **tutti i siti**, dentro Safari, su iPhone e iPad.

## Aggiungere il target (4 passaggi)

Il target lo crea Xcode dal suo template — è l'unico modo per avere
entitlement e firma corretti al primo colpo.

1. Apri `Fovea.xcodeproj` → **File › New › Target… › Safari Extension**.
   Nome: `FoveaSafari`. Type: **Safari Web Extension**. Language: Swift.
   Quando chiede se vuoi attivare lo schema, rispondi No.
2. Xcode crea `FoveaSafari/` con `Resources/` dentro. **Cancella** i file
   che ha generato lì dentro (`manifest.json`, `content.js`, `popup.*`,
   `images/`) e il suo `SafariWebExtensionHandler.swift`.
3. Trascina al loro posto il contenuto di questa cartella: `Resources/`
   intero e `SafariWebExtensionHandler.swift`. Spunta *Copy items if needed*
   e il target **FoveaSafari** (non quello dell'app).
4. Compila e lancia l'app sul telefono, poi: **Impostazioni › App › Safari ›
   Estensioni › Fovea** → attiva, e concedi l'accesso a **Tutti i siti web**.

Su iPhone l'estensione compare poi nel menu **ᴀA** della barra indirizzi.

## Come si usa

- Su ogni sito nuovo, **un tocco sul pallino d'ottone** in basso a destra.
  Serve perché iOS chiede il permesso ai sensori di movimento solo dopo un
  gesto dell'utente, e il permesso vale per quella origine. Non è aggirabile.
- **Secondo tocco**: ritara la posizione in chiaro su come stai tenendo il
  telefono adesso.
- Le due levette stanno nel popup dell'estensione.

## Come funziona sotto

Non tocchiamo il DOM della pagina. Un solo `<div>` fisso in cima allo stack,
con `backdrop-filter`, sfoca e scurisce tutto ciò che sta sotto. La lente non
ritaglia il contenuto: apre un **buco nel velo** con una `mask` radiale, così
il sito lì dentro resta nitido e intatto. Nessun reflow, nessun conflitto con
il CSS altrui, funziona su pagine mai viste prima.

L'angolo usa `deviceorientation`: dalla matrice ZXY del W3C si ricava la
normale allo schermo, e l'angolo è l'arcocoseno del prodotto scalare con la
normale di riferimento. Stessa rampa smoothstep e stesso riaggancio a 4
secondi del `TiltPrivacy.swift` nativo, così app ed estensione si comportano
in modo identico.

Tutti i listener sono `passive: true`: la lente segue il dito senza mai
rubare lo scorrimento alla pagina.

## Da tarare

`CFG` in cima a `fovea.js`: `clearAngle` / `opaqueAngle` (15° / 36°),
`lensRadius` (92 px), `maxBlur` (14 px).

## Cosa copre, detto chiaro

Tutti i siti in Safari. **Non** i browser interni ad altre app (il webview di
Instagram, WhatsApp, Telegram): quelli non caricano le estensioni di Safari.
Per il resto del telefono valgono l'app e la scorciatoia di sistema.
