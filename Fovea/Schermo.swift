//
//  Schermo.swift
//  Fovea — By D.S.
//
//  Applica l'algoritmo Eye-Shield a QUALSIASI vista SwiftUI, non solo al
//  testo. È la differenza grossa rispetto a Trama: qui passa l'intera
//  interfaccia — immagini, grafici, campi, bottoni.
//
//  Fonte: Tang & Shin, "Eye-Shield: Real-Time Protection of Mobile Device
//  Screen Information from Shoulder Surfing", 32nd USENIX Security
//  Symposium, 2023.
//
//  ATTENZIONE COMMERCIALE: gli autori hanno depositato una domanda di
//  brevetto negli Stati Uniti (63/468,650). Per uso personale e per provare
//  la tecnica non cambia nulla; prima di vendere l'app conviene farla
//  guardare a chi se ne intende. Vedi la nota in fondo al LEGGIMI.
//

import SwiftUI

// MARK: - Modello

@MainActor
public final class SchermoModel: ObservableObject {

    @Published public var attivo: Bool {
        didSet { UserDefaults.standard.set(attivo, forKey: "fovea.schermo.attivo") }
    }

    /// Lato della cella in pixel fisici. Sotto i 2 px l'occhio non separa
    /// più nemmeno da vicino; sopra i 6 la protezione si vede troppo.
    @Published public var cellaPixel: Double {
        didSet { UserDefaults.standard.set(cellaPixel, forKey: "fovea.schermo.cella") }
    }

    /// Quanto è marcata la protezione. Sotto 0,5 si legge comodo ma protegge
    /// poco; a 1 protegge molto e il testo "brilla" un po' da vicino.
    @Published public var forza: Double {
        didSet { UserDefaults.standard.set(forza, forKey: "fovea.schermo.forza") }
    }

    /// Raggio della sfocatura bersaglio, in punti. Indipendente dalla cella:
    /// è la larghezza di questa sfocatura a creare la differenza fra
    /// originale e complemento, cioè tutta la protezione.
    @Published public var raggio: Double {
        didSet { UserDefaults.standard.set(raggio, forKey: "fovea.schermo.raggio") }
    }

    /// Se acceso, la cella la detta la distanza misurata da Sguardo.
    @Published public var automatico: Bool {
        didSet { UserDefaults.standard.set(automatico, forKey: "fovea.schermo.auto") }
    }

    /// Aggiornato da SguardoModel.
    @Published public var cellaMisurata: Double = 3

    public var cellaAttiva: Double { automatico ? cellaMisurata : cellaPixel }

    public init() {
        let d = UserDefaults.standard
        attivo = d.object(forKey: "fovea.schermo.attivo") as? Bool ?? true
        cellaPixel = d.object(forKey: "fovea.schermo.cella") as? Double ?? 2
        forza = d.object(forKey: "fovea.schermo.forza") as? Double ?? 1.0
        raggio = d.object(forKey: "fovea.schermo.raggio") as? Double ?? 7
        automatico = d.object(forKey: "fovea.schermo.auto") as? Bool ?? false
    }

    /// Distanza oltre la quale la scacchiera si fonde, per un occhio con
    /// acuità di 1 primo d'arco su un pannello da 460 ppi.
    public var distanzaDiFusione: Double {
        let mm = cellaAttiva * 2 * 25.4 / 460.0     // periodo = 2 celle
        let radianti = (1.0 / 60.0) * .pi / 180
        return (mm / radianti) / 10.0
    }
}

// MARK: - Vista

public struct SchermoModifier: ViewModifier {

    @ObservedObject var model: SchermoModel
    let enabled: Bool

    @Environment(\.displayScale) private var scala

    public func body(content: Content) -> some View {
        // Lo shader lavora in punti, la cella è in pixel fisici: la
        // conversione passa da displayScale, altrimenti su un iPhone 3x la
        // scacchiera verrebbe tre volte più grossa del previsto e si vedrebbe.
        let cellaPunti = model.cellaAttiva / scala
        let raggio = max(model.raggio, 2)

        return content
            .layerEffect(
                ShaderLibrary.fovea(
                    .float(Float(cellaPunti)),
                    .float(Float(raggio)),
                    .float(enabled && model.attivo ? Float(model.forza) : 0)
                ),
                // Deve coprire il campione più lontano: 2 passi da raggio/2.
                maxSampleOffset: CGSize(width: raggio, height: raggio)
            )
            .animation(.easeOut(duration: 0.25), value: model.attivo)
    }
}

public extension View {
    /// Applica la scacchiera Eye-Shield a questa vista e a tutto ciò che
    /// contiene.
    func schermo(_ model: SchermoModel, enabled: Bool = true) -> some View {
        modifier(SchermoModifier(model: model, enabled: enabled))
    }
}

// MARK: - Taratura

public struct TaraturaSchermo: View {

    @ObservedObject var model: SchermoModel
    let chiudi: () -> Void

    public var body: some View {
        VStack(spacing: 22) {
            Text("Allontana il telefono finché non leggi più")
                .font(.pageTitle(18))
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.paper)

            // Il provino è protetto davvero: quello che vedi qui è quello
            // che vedrai nell'app.
            VStack(alignment: .leading, spacing: 6) {
                Text("Codice di accesso 4471")
                    .font(.page(17))
                Text("Saldo 3.912 €")
                    .font(.page(17))
            }
            .foregroundStyle(Ink.paper)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Ink.base))
            .schermo(model)

            VStack(spacing: 5) {
                Toggle("Cella dalla distanza misurata", isOn: $model.automatico)
                    .font(.page(13))
                    .foregroundStyle(Ink.paper)
                    .tint(Ink.brass)
                Slider(value: $model.cellaPixel, in: 2...6, step: 1)
                    .tint(Ink.brass)
                    .disabled(model.automatico)
                    .opacity(model.automatico ? 0.35 : 1)
                HStack {
                    Text(String(format: "cella %.0f px", model.cellaAttiva))
                        .font(.signal).foregroundStyle(Ink.muted)
                    Spacer()
                    Text(String(format: "si fonde oltre %.0f cm",
                                model.distanzaDiFusione))
                        .font(.signal).foregroundStyle(Ink.brass)
                }
            }

            VStack(spacing: 5) {
                Slider(value: $model.forza, in: 0.3...1.0)
                    .tint(Ink.brass)
                Text("forza — alza se da lontano si legge ancora")
                    .font(.signal)
                    .foregroundStyle(Ink.muted)
            }

            VStack(spacing: 5) {
                Slider(value: $model.raggio, in: 3...14, step: 1)
                    .tint(Ink.brass)
                Text(String(format: "sfocatura %.0f pt — quanto è illeggibile da lontano",
                            model.raggio))
                    .font(.signal)
                    .foregroundStyle(Ink.muted)
            }

            Button("Fissa qui") { chiudi() }
                .font(.signal)
                .tracking(1.4)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .overlay(Capsule().stroke(Ink.brass.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Ink.brass)
        }
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 24).fill(Ink.deep))
        .shadow(color: .black.opacity(0.6), radius: 30)
        .padding(20)
    }
}
