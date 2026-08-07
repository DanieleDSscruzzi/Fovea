//
//  AttivaView.swift
//  Fovea — By D.S.
//
//  La pagina ATTIVA. Un'app iOS non può accendere da sola la propria
//  estensione Safari: non esiste API. Quello che può fare — e qui fa — è
//  portarti al posto giusto in tre passi e poi accorgersi da sola quando è
//  fatta, leggendo il timestamp che l'estensione scrive nell'App Group.
//

import SwiftUI

enum Ponte {
    static let gruppo = "group.com.byds.fovea"
    static let chiave = "estensione.ultimoAvvio"

    static var estensioneVista: Date? {
        UserDefaults(suiteName: gruppo)?.object(forKey: chiave) as? Date
    }
}

enum Legale {
    // Sostituisci con gli URL veri quando il sito è online.
    static let termini = URL(string: "https://byds.it/fovea/termini")!
    static let privacy = URL(string: "https://byds.it/fovea/privacy")!
}

struct AttivaView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var vista: Date? = Ponte.estensioneVista
    @State private var battito = false

    private var attiva: Bool { vista != nil }

    var body: some View {
        ZStack {
            Ink.base.ignoresSafeArea()

            VStack(spacing: 0) {
                marchio
                Spacer(minLength: 24)
                stemma
                Spacer(minLength: 30)

                if attiva { conferma } else { passi }

                Spacer()
                piede
            }
            .padding(.horizontal, 28)
        }
        .onAppear { ricontrolla() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification)) { _ in
            ricontrolla()
        }
    }

    // MARK: Marchio

    /// In cima, centrato: è la prima schermata che un utente nuovo vede,
    /// e deve sapere di chi è l'app prima di sapere cosa fa.
    private var marchio: some View {
        VStack(spacing: 3) {
            Text("Fovea")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .foregroundStyle(Ink.paper)
            Text("BY D.S.")
                .font(.signal)
                .tracking(3.4)
                .foregroundStyle(Ink.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }

    // MARK: Stemma

    private var stemma: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(attiva ? Ink.brass : Ink.muted.opacity(0.35), lineWidth: 2)
                    .frame(width: 128, height: 128)
                    .scaleEffect(battito ? 1.06 : 1)
                Image(systemName: attiva ? "checkmark" : "power")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(attiva ? Ink.brass : Ink.muted)
            }
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                       value: battito)

            Text(attiva ? "ATTIVA" : "DA ATTIVARE")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .tracking(4)
                .foregroundStyle(attiva ? Ink.brass : Ink.muted)
        }
        .onAppear { if !attiva { battito = true } }
    }

    // MARK: Stati

    private var conferma: some View {
        VStack(spacing: 12) {
            Text("Fovea copre tutti i siti in Safari")
                .font(.pageTitle(19))
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.paper)
            Text("Su ogni sito nuovo tocca una volta il pallino d'ottone in basso a destra: iOS chiede lì il permesso ai sensori. Un secondo tocco ritara la posizione in chiaro.")
                .font(.page(14))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(Ink.muted)
        }
    }

    private var passi: some View {
        VStack(alignment: .leading, spacing: 22) {
            passo(1, "Impostazioni", "App › Safari › Estensioni › Fovea")
            passo(2, "Accendi Fovea", "e concedi l'accesso a Tutti i siti web")
            passo(3, "Torna qui", "questa pagina se ne accorge da sola")

            Button {
                apriImpostazioni()
            } label: {
                Text("Apri Impostazioni")
                    .font(.signal)
                    .tracking(1.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Ink.brass))
                    .foregroundStyle(Ink.deep)
            }
            .padding(.top, 6)
        }
    }

    private func passo(_ n: Int, _ titolo: String, _ nota: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(n)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Ink.brass)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Ink.brass.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(titolo)
                    .font(.pageTitle(16))
                    .foregroundStyle(Ink.paper)
                Text(nota)
                    .font(.page(13))
                    .foregroundStyle(Ink.muted)
            }
            Spacer()
        }
    }

    // MARK: Piede

    /// Termini e privacy in fondo, dove la gente li cerca. Sono link veri:
    /// App Review controlla che portino a pagine raggiungibili.
    private var piede: some View {
        VStack(spacing: 16) {
            Button("Chiudi") { dismiss() }
                .font(.signal)
                .tracking(1.4)
                .foregroundStyle(Ink.muted)

            HStack(spacing: 18) {
                Link("Termini e condizioni", destination: Legale.termini)
                Text("·").foregroundStyle(Ink.muted.opacity(0.5))
                Link("Privacy", destination: Legale.privacy)
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tint(Ink.muted)
        }
        .padding(.bottom, 20)
    }

    // MARK: Azioni

    private func ricontrolla() {
        withAnimation(.easeOut(duration: 0.3)) { vista = Ponte.estensioneVista }
        if vista != nil { battito = false }
    }

    private func apriImpostazioni() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
