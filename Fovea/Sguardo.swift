//
//  Sguardo.swift
//  Fovea — By D.S.
//
//  Sostituisce Angolo, e ne ribalta il criterio.
//
//  Angolo misurava il movimento del telefono: se ruotavi il polso, la pagina
//  si copriva — anche se stavi continuando a leggerla. Sbagliato.
//
//  Sguardo misura dove sono i TUOI occhi rispetto allo schermo, con la
//  fotocamera TrueDepth. Puoi girare, alzare, inclinare il telefono quanto
//  vuoi: finché lo schermo resta puntato verso di te, resta in chiaro. Si
//  copre solo quando la superficie si allontana dal tuo asse visivo — cioè
//  quando è puntata verso qualcun altro.
//
//  Cosa NON fa, detto prima che tu lo scopra da solo: non rende lo schermo
//  scuro per chi ti sta di fianco mentre tu leggi. Nessun software lo fa: la
//  direzione della luce è geometria del pannello. Quello che fa è togliere
//  l'errore di Angolo e dare a Trama la misura che le serviva.
//
//  Il pezzo che vale davvero: TrueDepth misura la tua distanza in metri, in
//  tempo reale. Trama la usa per tarare il periodo delle righe appena sopra
//  la tua soglia di acuità — e quindi sotto quella di chi sta più lontano.
//  Prima quel numero lo dovevi indovinare con uno slider.
//

import ARKit
import Combine
import SwiftUI

// MARK: - Configurazione

public struct SguardoConfig {

    /// Sotto questi gradi di scarto fra la normale allo schermo e la
    /// direzione dei tuoi occhi: in chiaro.
    public var clearAngle: Double = 22

    /// Sopra: illeggibile. Più largo di Angolo, perché qui non stiamo
    /// misurando il polso ma la geometria vera fra faccia e schermo.
    public var opaqueAngle: Double = 48

    public var maxBlur: CGFloat = 20
    public var maxDim: Double = 0.92
    public var responsiveness: Double = 0.25

    public init() {}
}

// MARK: - Modello

@MainActor
public final class SguardoModel: NSObject, ObservableObject, ARSessionDelegate {

    /// 0 = in chiaro, 1 = coperto.
    @Published public private(set) var esposizione: Double = 0

    /// Scarto in gradi fra la normale allo schermo e i tuoi occhi.
    @Published public private(set) var angolo: Double = 0

    /// Distanza degli occhi dallo schermo, in centimetri. È il dato che
    /// nessun altro sensore del telefono sa darti.
    @Published public private(set) var distanza: Double = 0

    /// False su iPhone senza TrueDepth: in quel caso l'app ricade su Angolo.
    @Published public private(set) var disponibile: Bool = true

    /// True quando nessun volto è inquadrato. Non copriamo: potresti aver
    /// solo appoggiato il telefono, e oscurare a vuoto è fastidioso.
    @Published public private(set) var senzaVolto: Bool = false

    public var config = SguardoConfig()

    private let session = ARSession()
    private var attivo = false
    private var frameSaltati = 0

    public override init() {
        super.init()
        session.delegate = self
    }

    // MARK: Ciclo di vita

    public func avvia() {
        guard !attivo else { return }
        guard ARFaceTrackingConfiguration.isSupported else {
            disponibile = false
            return
        }
        attivo = true
        disponibile = true

        let configurazione = ARFaceTrackingConfiguration()
        configurazione.maximumNumberOfTrackedFaces = 1
        configurazione.isLightEstimationEnabled = false
        session.run(configurazione, options: [.resetTracking, .removeExistingAnchors])
    }

    public func ferma() {
        guard attivo else { return }
        attivo = false
        session.pause()
        esposizione = 0
        angolo = 0
        distanza = 0
    }

    // MARK: Misura

    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let volto = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first
        let cameraT = frame.camera.transform

        guard let volto, volto.isTracked else {
            Task { @MainActor in self.nessunVolto() }
            return
        }

        // Posizione del volto nel sistema di riferimento della fotocamera.
        let relativa = simd_mul(simd_inverse(cameraT), volto.transform)
        let p = simd_make_float3(relativa.columns.3)

        let d = simd_length(p)
        guard d > 0.05 else { return }

        // La fotocamera frontale guarda lungo -Z: l'angolo fra quell'asse e
        // la direzione dei tuoi occhi è lo scarto dall'asse dello schermo.
        let direzione = simd_normalize(p)
        let coseno = simd_clamp(simd_dot(direzione, simd_float3(0, 0, -1)), -1, 1)
        let gradi = Double(acos(coseno)) * 180 / .pi

        Task { @MainActor in
            self.aggiorna(gradi: gradi, metri: Double(d))
        }
    }

    @MainActor
    private func aggiorna(gradi: Double, metri: Double) {
        frameSaltati = 0
        senzaVolto = false
        angolo = gradi
        distanza = metri * 100

        let obiettivo = rampa(gradi)
        esposizione += (obiettivo - esposizione) * config.responsiveness
    }

    @MainActor
    private func nessunVolto() {
        // Qualche frame perso è normale (battito di ciglia, mano davanti):
        // non reagiamo prima di mezzo secondo di assenza vera.
        frameSaltati += 1
        guard frameSaltati > 30 else { return }
        senzaVolto = true
        esposizione += (0 - esposizione) * config.responsiveness
    }

    private func rampa(_ gradi: Double) -> Double {
        let lo = config.clearAngle
        let hi = max(config.opaqueAngle, lo + 1)
        let t = min(max((gradi - lo) / (hi - lo), 0), 1)
        return t * t * (3 - 2 * t)
    }

    // MARK: Periodo per Trama

    /// Periodo delle righe, in pixel fisici, tarato sulla distanza misurata
    /// adesso. Sopra la tua soglia di acuità, sotto quella di chi è lontano.
    ///
    ///   periodo_mm = distanza_mm · tan(1,6′)     e     460 ppi = 18,11 px/mm
    ///
    /// A 33 cm dà 2,8 px, a 50 cm ne dà 4,2. È lo stesso numero che prima
    /// dovevi cercare a mano con lo slider.
    public var periodoConsigliato: Double {
        guard distanza > 5 else { return 3 }
        let mm = distanza * 10
        let radianti = (1.6 / 60.0) * .pi / 180
        return min(max(mm * radianti * 18.11, 2), 6)
    }
}

// MARK: - Vista

public struct SguardoModifier: ViewModifier {

    @ObservedObject var model: SguardoModel
    let enabled: Bool

    public func body(content: Content) -> some View {
        content
            .blur(radius: CGFloat(model.esposizione) * model.config.maxBlur)
            .overlay {
                Rectangle()
                    .fill(Color.black)
                    .opacity(model.esposizione * model.config.maxDim)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .onAppear { if enabled { model.avvia() } }
            .onDisappear { model.ferma() }
            .onChange(of: enabled) { _, on in
                on ? model.avvia() : model.ferma()
            }
    }
}

public extension View {
    /// Copre questa vista quando lo schermo si allontana dall'asse dei tuoi
    /// occhi — non quando muovi il telefono seguendolo con lo sguardo.
    func sguardo(_ model: SguardoModel, enabled: Bool = true) -> some View {
        modifier(SguardoModifier(model: model, enabled: enabled))
    }
}
