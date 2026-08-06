//
//  TiltPrivacy.swift
//  Fovea — By D.S.
//
//  Il comportamento del vetro privacy, riprodotto con l'inclinazione.
//
//  Come funziona: alla prima posa comoda il modello memorizza l'assetto del
//  telefono. Da lì misura di quanti gradi la normale allo schermo si è
//  allontanata da quell'assetto. Sotto una soglia tutto nitido, sopra
//  un'altra tutto nero, in mezzo una rampa continua — la stessa curva di
//  una pellicola a microlamelle.
//
//  Cosa NON fa: distinguere te da chi ti sta di fianco. Lo schermo si scurisce
//  per chiunque, te compreso. Protegge quando muovi il telefono, non quando
//  lo tieni fermo davanti a te con qualcuno accanto: per quello servono
//  PrivacyGuard (secondo volto) e SpotReveal (lente).
//
//  CoreMotion a 30 Hz: nessun permesso, nessun pallino verde, consumo
//  trascurabile rispetto alla fotocamera.
//

import Combine
import CoreMotion
import SwiftUI

// MARK: - Configurazione

public struct TiltPrivacyConfig {

    /// Sotto questi gradi di scarto dalla posa di riferimento: nitido.
    /// Una pellicola vera lascia leggere fino a ~30° totali; qui il valore è
    /// più stretto perché conta lo scarto, non l'angolo assoluto.
    public var clearAngle: Double = 15

    /// Sopra questi gradi: illeggibile.
    public var opaqueAngle: Double = 36

    public var maxBlur: CGFloat = 20
    public var maxDim: Double = 0.90

    /// Se resti a lungo dentro la zona nitida, il riferimento si riaggancia
    /// alla posa attuale: così la deriva naturale della mano non ti oscura
    /// la pagina dopo dieci minuti di lettura.
    public var reanchorAfter: TimeInterval = 4

    /// Filtro sul segnale. Alto = reattivo e nervoso, basso = morbido e lento.
    public var responsiveness: Double = 0.30

    public init() {}
}

// MARK: - Modello

@MainActor
public final class TiltPrivacyModel: ObservableObject {

    /// 0 = pagina in chiaro, 1 = pagina coperta.
    @Published public private(set) var exposure: Double = 0

    /// Scarto in gradi dalla posa di riferimento. Utile a schermo in fase
    /// di taratura, e per capire se le soglie sono giuste sul tuo iPhone.
    @Published public private(set) var angle: Double = 0

    @Published public private(set) var available: Bool = true

    public var config = TiltPrivacyConfig()

    private let motion = CMMotionManager()
    private var reference: CMAttitude?
    private var clearSince: Date?
    private var running = false

    public init() {}

    // MARK: Ciclo di vita

    public func start() {
        guard !running else { return }
        guard motion.isDeviceMotionAvailable else {
            available = false
            return
        }
        running = true
        available = true

        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) {
            [weak self] data, _ in
            guard let self, let data else { return }
            MainActor.assumeIsolated { self.consume(data.attitude) }
        }
    }

    public func stop() {
        running = false
        motion.stopDeviceMotionUpdates()
        reference = nil
        clearSince = nil
        exposure = 0
        angle = 0
    }

    /// Fissa qui la posa "davanti agli occhi". Chiamala quando l'utente
    /// tiene il telefono come gli è comodo.
    public func calibrate() {
        reference = motion.deviceMotion?.attitude.copy() as? CMAttitude
        clearSince = Date()
    }

    // MARK: Misura

    private func consume(_ attitude: CMAttitude) {
        guard let reference else {
            // Prima lettura utile: diventa lei il riferimento.
            self.reference = attitude.copy() as? CMAttitude
            return
        }

        guard let relative = attitude.copy() as? CMAttitude else { return }
        relative.multiply(byInverseOf: reference)

        // m33 della matrice relativa è il coseno dell'angolo fra la normale
        // allo schermo di adesso e quella di riferimento. Una riga di
        // trigonometria al posto di pitch/roll/yaw, che qui si accavallerebbero.
        let cosine = min(max(relative.rotationMatrix.m33, -1), 1)
        let degrees = acos(cosine) * 180 / .pi
        angle = degrees

        let target = ramp(degrees)
        let k = config.responsiveness
        exposure += (target - exposure) * k

        reanchorIfSettled(degrees)
    }

    /// Rampa morbida fra le due soglie. Smoothstep e non lineare, perché una
    /// transizione lineare si vede "partire" e sembra un difetto.
    private func ramp(_ degrees: Double) -> Double {
        let lo = config.clearAngle
        let hi = max(config.opaqueAngle, lo + 1)
        let t = min(max((degrees - lo) / (hi - lo), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func reanchorIfSettled(_ degrees: Double) {
        if degrees < config.clearAngle * 0.5 {
            if let since = clearSince {
                if Date().timeIntervalSince(since) > config.reanchorAfter {
                    // Salto invisibile: siamo già dentro la zona nitida.
                    reference = motion.deviceMotion?.attitude.copy() as? CMAttitude
                    clearSince = Date()
                }
            } else {
                clearSince = Date()
            }
        } else {
            clearSince = nil
        }
    }
}

// MARK: - Vista

public struct TiltPrivacyModifier: ViewModifier {

    @ObservedObject var model: TiltPrivacyModel
    let enabled: Bool

    public func body(content: Content) -> some View {
        content
            .blur(radius: CGFloat(model.exposure) * model.config.maxBlur)
            .overlay {
                Rectangle()
                    .fill(Color.black)
                    .opacity(model.exposure * model.config.maxDim)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .onAppear { if enabled { model.start() } }
            .onDisappear { model.stop() }
            .onChange(of: enabled) { _, on in
                on ? model.start() : model.stop()
            }
    }
}

public extension View {
    /// Scurisce questa vista man mano che il telefono si allontana dalla
    /// posa di riferimento, come una pellicola privacy.
    func tiltPrivacy(_ model: TiltPrivacyModel, enabled: Bool = true) -> some View {
        modifier(TiltPrivacyModifier(model: model, enabled: enabled))
    }
}
