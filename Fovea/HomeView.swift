//
//  HomeView.swift
//  Fovea — By D.S.
//
//  Tre elementi, niente altro: il marchio in alto, il pulsante di
//  configurazione al centro, i legali in fondo. Niente levette, niente
//  provini, niente documenti. Chi apre l'app deve avere una cosa sola da
//  fare, e quella cosa deve essere grande.
//

import SwiftUI

struct HomeView: View {

    @State private var mostraAttiva = false
    @State private var estensione: Date? = Ponte.estensioneVista

    var body: some View {
        ZStack {
            Ink.base.ignoresSafeArea()

            VStack(spacing: 0) {
                marchio
                Spacer()
                configura
                Spacer()
                legali
            }
            .padding(.horizontal, 30)
        }
        .sheet(isPresented: $mostraAttiva) { AttivaView() }
        .onAppear { estensione = Ponte.estensioneVista }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification)) { _ in
            estensione = Ponte.estensioneVista
        }
    }

    // MARK: Marchio

    private var marchio: some View {
        VStack(spacing: 4) {
            Text("Fovea")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(Ink.paper)
            Text("BY D.S.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(4.5)
                .foregroundStyle(Ink.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 54)
    }

    // MARK: Configurazione

    /// Il colore del bordo è l'unico stato mostrato: ottone quando c'è
    /// qualcosa da fare, spento quando è tutto a posto.
    private var configura: some View {
        Button {
            mostraAttiva = true
        } label: {
            VStack(spacing: 20) {
                Image(systemName: estensione == nil ? "power" : "checkmark")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(estensione == nil ? Ink.brass : Ink.paper)

                Text("ATTIVA\nCONFIGURAZIONE")
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .tracking(2.2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(Ink.paper)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 54)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Ink.deep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(estensione == nil
                                    ? Ink.brass.opacity(0.55)
                                    : Ink.muted.opacity(0.22),
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Legali

    private var legali: some View {
        HStack(spacing: 20) {
            Link("Privacy", destination: Legale.privacy)
            Text("·").foregroundStyle(Ink.muted.opacity(0.45))
            Link("Termini e condizioni", destination: Legale.termini)
        }
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .tint(Ink.muted)
        .padding(.bottom, 26)
    }
}
