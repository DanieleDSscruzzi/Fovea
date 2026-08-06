//
//  Soglia.swift
//  Fovea — By D.S.
//
//  Il meccanismo "io al centro leggo, chi è di lato no".
//
//  Non è un filtro angolare: quello richiede microlamelle, e nessun software
//  lo replica. Questo lavora su una cosa diversa e reale — la soglia di
//  contrasto dell'occhio.
//
//  Chi ti guarda di lato paga tre penalità contemporaneamente:
//
//    1. distanza — tu leggi a ~33 cm, lui sta a 70-120 cm. Le lettere gli
//       arrivano a un terzo della dimensione angolare;
//    2. luminanza fuori asse — un OLED a 45° emette circa metà della luce
//       che manda in avanti. È fisica del pannello, vale sempre;
//    3. degrado di contrasto fuori asse — la curva di gamma si sposta e i
//       toni vicini collassano l'uno sull'altro.
//
//  Prese singolarmente sono debolezze. Moltiplicate fra loro valgono un
//  fattore 6-10. Se il testo sta appena sopra la TUA soglia di leggibilità,
//  finisce sotto la sua.
//
//  Per questo la taratura è manuale e personale: abbassi finché fatichi
//  appena a leggere. Quel punto è diverso per ogni paio d'occhi, e nessun
//  valore predefinito può indovinarlo.
//
//  Insieme al contrasto abbassiamo anche la luminosità dello schermo, che
//  un'app può fare davvero: meno luce assoluta significa che la penalità
//  fuori asse morde su un margine già stretto.
//

import SwiftUI

// MARK: - Modello

@MainActor
public final class SogliaModel: ObservableObject {

    // @AppStorage dentro una ObservableObject non pubblica i cambiamenti:
    // le viste non si aggiornerebbero. Qui @Published + UserDefaults a mano.

    /// 1 = contrasto pieno, 0.12 = quasi invisibile. Personale.
    @Published public var livello: Double {
        didSet { salva(livello, "fovea.soglia.livello") }
    }

    /// Luminanza dello schermo mentre la soglia è attiva.
    @Published public var luminosita: Double {
        didSet { salva(luminosita, "fovea.soglia.luminosita") }
    }

    @Published public var attiva: Bool {
        didSet {
            salva(attiva, "fovea.soglia.attiva")
            attiva ? applicaLuminosita() : ripristinaLuminosita()
        }
    }

    private func salva(_ v: Any, _ k: String) {
        UserDefaults.standard.set(v, forKey: k)
    }

    private var luminositaPrecedente: CGFloat?

    public init() {
        let d = UserDefaults.standard
        livello = d.object(forKey: "fovea.soglia.livello") as? Double ?? 1.0
        luminosita = d.object(forKey: "fovea.soglia.luminosita") as? Double ?? 0.42
        attiva = d.bool(forKey: "fovea.soglia.attiva")
    }

    /// Colore del testo alla soglia scelta: si avvicina al fondo man mano
    /// che il livello scende.
    public var inchiostro: Color {
        Color(red: mix(0.086, 0.910), green: mix(0.094, 0.902), blue: mix(0.114, 0.882))
    }

    private func mix(_ fondo: Double, _ carta: Double) -> Double {
        fondo + (carta - fondo) * livello
    }

    public func applicaLuminosita() {
        guard attiva else { return }
        if luminositaPrecedente == nil {
            luminositaPrecedente = UIScreen.main.brightness
        }
        UIScreen.main.brightness = CGFloat(luminosita)
    }

    public func ripristinaLuminosita() {
        if let precedente = luminositaPrecedente {
            UIScreen.main.brightness = precedente
            luminositaPrecedente = nil
        }
    }
}

// MARK: - Taratura

/// Il testo di prova non è finto: è una riga del documento che stai
/// leggendo, così tari sul carattere e sulla spaziatura veri.
public struct TaraturaSoglia: View {

    @ObservedObject var model: SogliaModel
    let campione: String
    let chiudi: () -> Void

    public var body: some View {
        VStack(spacing: 26) {
            Text("Abbassa finché fatichi appena a leggere")
                .font(.pageTitle(18))
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.paper)

            Text(campione)
                .font(.page(17))
                .lineSpacing(6)
                .foregroundStyle(model.inchiostro)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120, alignment: .top)
                .clipped()

            VStack(spacing: 6) {
                Slider(value: $model.livello, in: 0.12...1.0)
                    .tint(Ink.brass)
                HStack {
                    Text("coperto").font(.signal).foregroundStyle(Ink.muted)
                    Spacer()
                    Text("in chiaro").font(.signal).foregroundStyle(Ink.muted)
                }
            }

            VStack(spacing: 6) {
                Slider(value: $model.luminosita, in: 0.10...0.85) { fine in
                    if !fine { model.applicaLuminosita() }
                }
                .tint(Ink.brass)
                Text("luminosità dello schermo")
                    .font(.signal)
                    .foregroundStyle(Ink.muted)
            }

            Text("Quello che tu leggi a fatica, chi ti sta di lato non lo legge: è più lontano, e il pannello verso di lui emette meno luce.")
                .font(.page(13))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(Ink.muted)

            Button("Fissa qui") { chiudi() }
                .font(.signal)
                .tracking(1.4)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .overlay(Capsule().stroke(Ink.brass.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Ink.brass)
        }
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 24).fill(Ink.deep))
        .shadow(color: .black.opacity(0.6), radius: 30)
        .padding(22)
    }
}
