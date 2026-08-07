# Fovea — By D.S.

App di lettura riservata. Due protezioni indipendenti, entrambe on-device.

## Avvio

Apri `Fovea.xcodeproj` e premi Run. Non serve altro: target iOS 16, bundle `com.byds.velo`, team `S6C4FQLMT5`, `NSCameraUsageDescription` già scritta nelle build settings (`INFOPLIST_KEY_*`, niente Info.plist da gestire a mano).

Compila su **dispositivo fisico**: il simulatore non ha fotocamera frontale e la modalità Sguardi resta inerte. La Lente invece si prova anche in simulatore.

L'icona è già dentro (`AppIcon.png`, 1024×1024, RGB senza canale alpha come richiede App Store Connect). Per ritoccarla: `strumenti/icona.py`, gira con Pillow e numpy.

## Struttura

```
Fovea/
├── Fovea.xcodeproj
├── LEGGIMI.md
└── Fovea/
    ├── FoveaApp.swift       entry point + libreria documenti
    ├── ReaderView.swift    lettura, modifica, barra di stato
    ├── SpotReveal.swift    la lente che segue il dito
    ├── PrivacyGuard.swift  rilevamento secondo volto (Vision + AVFoundation)
    ├── NoteStore.swift     modello e persistenza JSON
    ├── Design.swift        colori, caratteri, etichette di stato
    └── Assets.xcassets     icona e accent color

`strumenti/icona.py` rigenera l'icona: righe di testo che si dissolvono sotto
un velo diagonale. I parametri da toccare sono il gradiente `g` (dove cade il
velo) e `rows` (lunghezza delle righe).
```

## Note per App Review

Copia questo nel campo *App Review Information → Notes*, altrimenti il rischio è un rigetto **5.1.1** per uso della fotocamera non evidente:

> La fotocamera frontale è usata da una sola funzione opzionale ("Sguardi"), disattivata di default e attivabile dal menu in alto a destra nella schermata di lettura. Conta i volti nel frame con il framework Vision, esclusivamente sul dispositivo, per sfocare il testo quando compare una seconda persona. I fotogrammi non vengono salvati, elaborati altrove né trasmessi: l'app non effettua alcuna connessione di rete.
>
> Per provarla: aprire un documento → menu in alto a destra → attivare "Sguardi" → concedere il permesso → far inquadrare una seconda persona. Il testo si copre in circa mezzo secondo.

Nella scheda App Store, dichiara il pallino verde prima che lo faccia una recensione a una stella: *"Quando Sguardi è attivo l'indicatore verde della fotocamera resta acceso. È il sistema iOS che segnala l'uso, ed è corretto che lo veda."*

Privacy Nutrition Labels: **Data Not Collected**. Nessuna eccezione da dichiarare, perché nulla lascia il dispositivo.

## Da tarare sul campo

- `PrivacyGuardConfig.minFaceArea` (0.012) — sul treno, con gente lontana, probabilmente va alzato a 0.02.
- `framesToReveal` (8) — se riapre troppo in fretta, alza.
- `SpotRevealText.radius` (74) — su iPhone mini scendi a ~60.

## Cosa Fovea non fa

Non restringe l'angolo di visione dello schermo: quella è una proprietà fisica del pannello e richiede una pellicola a microlamelle. Non impedisce gli screenshot (iOS notifica dopo lo scatto, non prima); copre invece registrazione schermo, mirroring e AirPlay tramite `UIScreen.isCaptured`. Meglio scriverlo nella descrizione dello Store che leggerlo nelle recensioni.
