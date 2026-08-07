//
//  Trama.swift
//  Fovea — By D.S.
//
//  Lavoro sui pixel, per davvero. Solo non sull'angolo — su quello non si
//  può, la direzione della luce è geometria del pannello. Qui si lavora
//  sulla risoluzione dell'occhio.
//
//  L'idea: il testo non viene disegnato in un colore, viene disegnato come
//  una trama di righe verticali larghe pochi pixel fisici, alternate fra due
//  toni equidistanti dal fondo. La media dei due toni È il fondo.
//
//    · chi sta vicino risolve le righe, vede la trama, legge la parola;
//    · chi sta lontano non le risolve: le righe si mediano fra loro e
//      collassano esattamente sul colore del fondo. Non "sfocato" —
//      assente.
//
//  I numeri, sul display dell'iPhone (460 ppi):
//    periodo 3 px  →  0,166 mm  →  1,7' d'arco a 33 cm   (risolvibile)
//                                  0,57' d'arco a 100 cm (sotto soglia)
//  Il limite di acuità di un occhio sano è circa 1' d'arco. Il periodo si
//  regola proprio per cadere sopra la tua soglia e sotto la sua.
//
//  È la stessa fisica su cui si regge Soglia, portata al limite fisico del
//  pannello invece che al limite del contrasto.
//

import SwiftUI

// MARK: - Modello

@MainActor
public final class TramaModel: ObservableObject {

    @Published public var attiva: Bool {
        didSet { UserDefaults.standard.set(attiva, forKey: "fovea.trama.attiva") }
    }

    /// Larghezza del periodo in pixel fisici. 2 = al limite assoluto del
    /// pannello, 6 = leggibile anche da un metro. Il punto utile sta fra 3 e 4.
    @Published public var periodo: Double {
        didSet { UserDefaults.standard.set(periodo, forKey: "fovea.trama.periodo") }
    }

    /// Quanto i due toni si allontanano dal fondo. Più ampiezza = più
    /// leggibile da vicino, ma anche più residuo percepibile da lontano.
    @Published public var ampiezza: Double {
        didSet { UserDefaults.standard.set(ampiezza, forKey: "fovea.trama.ampiezza") }
    }

    /// Quando Sguardo è attivo, il periodo lo detta la distanza misurata
    /// invece dello slider: si adatta mentre avvicini o allontani il telefono.
    @Published public var periodoAutomatico: Bool {
        didSet { UserDefaults.standard.set(periodoAutomatico, forKey: "fovea.trama.auto") }
    }

    /// Scritto da SguardoModel a ogni misura.
    @Published public var periodoMisurato: Double = 3

    public var periodoAttivo: Double {
        periodoAutomatico ? periodoMisurato : periodo
    }

    public init() {
        let d = UserDefaults.standard
        attiva = d.bool(forKey: "fovea.trama.attiva")
        periodo = d.object(forKey: "fovea.trama.periodo") as? Double ?? 3
        ampiezza = d.object(forKey: "fovea.trama.ampiezza") as? Double ?? 0.26
        periodoAutomatico = d.object(forKey: "fovea.trama.auto") as? Bool ?? true
    }

    /// Campo su cui si posa la trama. Un grigio medio, non il fondo scuro
    /// dell'app: serve spazio sopra e sotto perché i due toni ci stiano
    /// senza saturare, ed è quello a rendere il trucco efficace.
    public var campo: Double { 0.34 }

    public var toni: (UIColor, UIColor) {
        let a = min(campo + ampiezza, 1.0)
        let b = max(campo - ampiezza, 0.0)
        return (UIColor(white: a, alpha: 1), UIColor(white: b, alpha: 1))
    }

    /// Diagnostica onesta: a che distanza il testo diventa illeggibile,
    /// dato il periodo scelto e un'acuità di 1' d'arco.
    public var distanzaDiSicurezza: Double {
        let mm = periodoAttivo * 25.4 / 460.0          // periodo in millimetri
        let radianti = (1.0 / 60.0) * .pi / 180  // 1 primo d'arco
        return (mm / radianti) / 10.0            // in centimetri
    }
}

// MARK: - Resa

public struct TramaText: View {

    @ObservedObject var model: TramaModel
    let testo: String
    var dimensione: CGFloat = 18

    @Environment(\.displayScale) private var scala

    public var body: some View {
        Text(testo)
            .font(.page(dimensione))
            .lineSpacing(6)
            // ImagePaint ripete la piastrella: con scale = 1/displayScale
            // ogni pixel dell'immagine copre esattamente un pixel fisico
            // dello schermo. Senza questo il sistema interpolerebbe e la
            // trama si spegnerebbe da sola.
            .foregroundStyle(
                ImagePaint(image: Image(uiImage: piastrella), scale: 1 / scala)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(white: model.campo))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var piastrella: UIImage {
        Self.righe(periodo: Int(model.periodoAttivo.rounded()), toni: model.toni)
    }

    static func righe(periodo: Int, toni: (UIColor, UIColor)) -> UIImage {
        let larghezza = max(2, periodo)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1          // pixel dell'immagine = pixel fisici
        formato.opaque = true
        let render = UIGraphicsImageRenderer(
            size: CGSize(width: larghezza, height: 1), format: formato)
        return render.image { ctx in
            let meta = larghezza / 2
            toni.0.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: meta, height: 1))
            toni.1.setFill()
            ctx.fill(CGRect(x: meta, y: 0, width: larghezza - meta, height: 1))
        }
    }
}

// MARK: - Taratura

public struct TaraturaTrama: View {

    @ObservedObject var model: TramaModel
    let campione: String
    let chiudi: () -> Void

    public var body: some View {
        VStack(spacing: 22) {
            Text("Allontana il telefono finché sparisce")
                .font(.pageTitle(18))
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.paper)

            TramaText(model: model, testo: campione, dimensione: 17)
                .frame(height: 130)
                .clipped()

            VStack(spacing: 5) {
                Toggle("Periodo dalla distanza misurata", isOn: $model.periodoAutomatico)
                    .font(.page(13))
                    .foregroundStyle(Ink.paper)
                    .tint(Ink.brass)
                Slider(value: $model.periodo, in: 2...6, step: 1)
                    .tint(Ink.brass)
                    .disabled(model.periodoAutomatico)
                    .opacity(model.periodoAutomatico ? 0.35 : 1)
                HStack {
                    Text("periodo \(Int(model.periodoAttivo)) px")
                        .font(.signal).foregroundStyle(Ink.muted)
                    Spacer()
                    Text(String(format: "sparisce oltre %.0f cm",
                                model.distanzaDiSicurezza))
                        .font(.signal).foregroundStyle(Ink.brass)
                }
            }

            VStack(spacing: 5) {
                Slider(value: $model.ampiezza, in: 0.08...0.45)
                    .tint(Ink.brass)
                Text("ampiezza — alza se fatichi a leggere da vicino")
                    .font(.signal)
                    .foregroundStyle(Ink.muted)
            }

            Text("Le righe sono larghe pochi pixel e i loro due toni hanno per media esatta il colore del fondo. Da vicino il tuo occhio le separa e legge; oltre la distanza indicata si mediano e restano un rettangolo grigio uniforme.")
                .font(.page(12.5))
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
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 24).fill(Ink.deep))
        .shadow(color: .black.opacity(0.6), radius: 30)
        .padding(20)
    }
}
