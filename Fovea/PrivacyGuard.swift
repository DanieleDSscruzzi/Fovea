//
//  PrivacyGuard.swift
//  By D.S. — perfezione assicurata
//
//  Nasconde il contenuto della tua app quando una seconda persona
//  entra nel campo visivo della fotocamera frontale.
//
//  Requisiti: iOS 15+ · Info.plist → NSCameraUsageDescription
//  Nessun frame viene salvato, trasmesso o scritto su disco.
//

import AVFoundation
import Combine
import SwiftUI
import Vision

// MARK: - Configurazione

public struct PrivacyGuardConfig {

    /// Area minima del frame che un volto deve occupare per contare.
    /// 0.012 ≈ una persona a ~1,5 m. Alza il valore per ignorare chi è più lontano.
    public var minFaceArea: CGFloat = 0.012

    /// Rilevamenti consecutivi prima di oscurare. Basso = reazione rapida.
    public var framesToShield: Int = 2

    /// Frame puliti consecutivi prima di riaprire. Alto = niente sfarfallio.
    public var framesToReveal: Int = 8

    /// Frequenza di analisi. 5 fps bastano e tengono la CPU sotto il 3%.
    public var samplesPerSecond: Double = 5

    /// Raggio della sfocatura applicata al contenuto protetto.
    public var blurRadius: CGFloat = 30

    /// Oscura anche durante registrazione schermo, mirroring o AirPlay.
    public var hideOnScreenCapture: Bool = true

    public init() {}
}

// MARK: - Campionatore volti

/// Gira su una coda dedicata: apre la fotocamera frontale a bassa risoluzione,
/// conta i volti con Vision e riporta il totale sul main thread.
final class FaceSampler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "byds.privacyguard.camera", qos: .userInitiated)
    private let handler = VNSequenceRequestHandler()

    private var config: PrivacyGuardConfig
    private var lastSample = CFAbsoluteTimeGetCurrent()
    private var configured = false

    /// Chiamato sul main thread a ogni campione analizzato.
    var onFaceCount: ((Int) -> Void)?

    init(config: PrivacyGuardConfig) {
        self.config = config
        super.init()
    }

    func update(config: PrivacyGuardConfig) {
        self.config = config
    }

    // MARK: Ciclo di vita

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard self.configure() else { return }
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Risoluzione minima utile: i volti restano rilevabili, la batteria ringrazia.
        session.sessionPreset = .vga640x480

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return false }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        return true
    }

    // MARK: Analisi

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Throttling: analizziamo solo N campioni al secondo.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSample >= 1.0 / config.samplesPerSecond else { return }
        lastSample = now

        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest()
        // Fotocamera frontale in verticale: l'immagine arriva ruotata e specchiata.
        try? handler.perform([request], on: pixels, orientation: .leftMirrored)

        let faces = (request.results ?? []).filter { face in
            let box = face.boundingBox
            return box.width * box.height >= config.minFaceArea
        }

        let count = faces.count
        DispatchQueue.main.async { [weak self] in
            self?.onFaceCount?(count)
        }
    }
}

// MARK: - Modello

@MainActor
public final class PrivacyGuardModel: ObservableObject {

    public enum CameraAccess {
        case notRequested, granted, denied
    }

    /// True quando il contenuto va nascosto.
    @Published public private(set) var isShielded = false

    /// Motivo per cui il contenuto è nascosto — utile per la copy a schermo.
    @Published public private(set) var reason: Reason = .none

    @Published public private(set) var access: CameraAccess = .notRequested

    public enum Reason { case none, secondPerson, screenCapture }

    public var config: PrivacyGuardConfig {
        didSet { sampler.update(config: config) }
    }

    private lazy var sampler = FaceSampler(config: config)
    private var shieldStreak = 0
    private var revealStreak = 0
    private var isActive = false
    private var observers: [NSObjectProtocol] = []

    public init(config: PrivacyGuardConfig = PrivacyGuardConfig()) {
        self.config = config
        sampler.onFaceCount = { [weak self] count in
            self?.ingest(faceCount: count)
        }
        observeScreenCapture()
        observeAppState()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: Attivazione

    public func activate() {
        guard !isActive else { return }
        isActive = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted
            sampler.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                Task { @MainActor in
                    guard let self else { return }
                    self.access = ok ? .granted : .denied
                    if ok, self.isActive { self.sampler.start() }
                }
            }
        default:
            access = .denied
        }
    }

    public func deactivate() {
        isActive = false
        sampler.stop()
        shieldStreak = 0
        revealStreak = 0
        setShield(false, reason: .none)
    }

    // MARK: Isteresi

    private func ingest(faceCount: Int) {
        // Un solo volto (o nessuno) = sei solo. Due o più = qualcuno guarda.
        if faceCount >= 2 {
            revealStreak = 0
            shieldStreak += 1
            if shieldStreak >= config.framesToShield {
                setShield(true, reason: .secondPerson)
            }
        } else {
            shieldStreak = 0
            revealStreak += 1
            if revealStreak >= config.framesToReveal, reason != .screenCapture {
                setShield(false, reason: .none)
            }
        }
    }

    private func setShield(_ on: Bool, reason: Reason) {
        guard isShielded != on || self.reason != reason else { return }
        isShielded = on
        self.reason = reason
    }

    // MARK: Cattura schermo e background

    private func observeScreenCapture() {
        let check: () -> Void = { [weak self] in
            Task { @MainActor in
                guard let self, self.config.hideOnScreenCapture else { return }
                if UIScreen.main.isCaptured {
                    self.setShield(true, reason: .screenCapture)
                } else if self.reason == .screenCapture {
                    self.setShield(false, reason: .none)
                }
            }
        }
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil, queue: .main) { _ in check() }
        )
        check()
    }

    private func observeAppState() {
        // Fuori dallo schermo la fotocamera si spegne: batteria e pallino verde.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.sampler.stop() }
                }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.isActive, self.access == .granted else { return }
                        self.sampler.start()
                    }
                }
        )
    }
}

// MARK: - Vista

public struct PrivacyShade: View {

    let reason: PrivacyGuardModel.Reason

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                Image(systemName: reason == .screenCapture
                      ? "record.circle"
                      : "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 34, weight: .light))
                Text(reason == .screenCapture
                     ? "Schermo in registrazione"
                     : "Qualcuno sta guardando")
                    .font(.callout.weight(.medium))
                Text("Il contenuto torna visibile da solo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .transition(.opacity)
    }
}

public struct PrivacyGuardModifier: ViewModifier {

    @ObservedObject var model: PrivacyGuardModel
    let enabled: Bool

    public func body(content: Content) -> some View {
        content
            .blur(radius: model.isShielded ? model.config.blurRadius : 0)
            .overlay {
                if model.isShielded {
                    PrivacyShade(reason: model.reason)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.16), value: model.isShielded)
            .onAppear { if enabled { model.activate() } }
            .onDisappear { model.deactivate() }
            .onChange(of: enabled) { _, on in
                on ? model.activate() : model.deactivate()
            }
    }
}

public extension View {
    /// Nasconde questa vista quando compare un secondo volto davanti al telefono.
    func privacyGuard(_ model: PrivacyGuardModel, enabled: Bool = true) -> some View {
        modifier(PrivacyGuardModifier(model: model, enabled: enabled))
    }
}

// MARK: - Esempio d'uso

/*
 struct DocumentView: View {
     @StateObject private var guardModel = PrivacyGuardModel()
     @AppStorage("privacyMode") private var privacyMode = false

     var body: some View {
         ScrollView {
             Text(documentBody)
         }
         .privacyGuard(guardModel, enabled: privacyMode)
         .toolbar {
             Toggle("Lettura privata", isOn: $privacyMode)
         }
     }
 }
 */
