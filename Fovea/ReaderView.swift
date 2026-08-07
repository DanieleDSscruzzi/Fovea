//
//  ReaderView.swift
//  Fovea — By D.S.
//

import SwiftUI

struct ReaderView: View {

    @EnvironmentObject private var store: NoteStore
    @StateObject private var guardModel = PrivacyGuardModel()
    @StateObject private var sguardo = SguardoModel()
    @StateObject private var schermo = SchermoModel()
    @StateObject private var soglia = SogliaModel()
    @StateObject private var trama = TramaModel()

    @AppStorage("fovea.angle") private var angleEnabled = true
    @AppStorage("fovea.watch") private var watchEnabled = false
    @AppStorage("fovea.lens")  private var lensEnabled  = false

    @State private var note: Note
    @State private var editing = false
    @State private var mostraAttiva = false
    @State private var tarandoSoglia = false
    @State private var tarandoTrama = false
    @State private var tarandoSchermo = false
    @FocusState private var typing: Bool

    init(note: Note) {
        _note = State(initialValue: note)
    }

    var body: some View {
        ZStack {
            Ink.base.ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                Divider().overlay(Ink.muted.opacity(0.18))

                if editing { editor } else { reader }
            }
            .schermo(schermo)
            // L'angolo si applica per ultimo, sopra tutto: è una pellicola
            // appoggiata sullo schermo, non una proprietà del testo.
            .sguardo(sguardo, enabled: angleEnabled && sguardo.disponibile && !editing)
            .onChange(of: sguardo.distanza) { _, _ in
                trama.periodoMisurato = sguardo.periodoConsigliato
                schermo.cellaMisurata = sguardo.periodoConsigliato / 2
            }

            if tarandoSchermo {
                TaraturaSchermo(model: schermo) { tarandoSchermo = false }
            }
            if tarandoTrama {
                TaraturaTrama(model: trama,
                              campione: String(note.body.prefix(160))) {
                    tarandoTrama = false
                }
            }
            if tarandoSoglia {
                TaraturaSoglia(model: soglia,
                               campione: String(note.body.prefix(240))) {
                    tarandoSoglia = false
                }
            }
        }
        .navigationTitle(note.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editing ? "Fine" : "Modifica") {
                    if editing { store.update(note); typing = false }
                    editing.toggle()
                }
                .tint(Ink.brass)
            }
        }
        .toolbarBackground(Ink.deep, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $mostraAttiva) { AttivaView() }
        .onAppear { soglia.applicaLuminosita() }
        .onDisappear {
            store.update(note)
            soglia.ripristinaLuminosita()
        }
    }

    // MARK: Stato

    private var statusBar: some View {
        HStack(spacing: 8) {
            StatusTag(text: sguardoStato, active: angleEnabled)
            if schermo.attivo {
                StatusTag(text: String(format: "schermo %.0fpx", schermo.cellaAttiva),
                          active: true)
            }
            StatusTag(text: watchStatusText,
                      active: watchEnabled && guardModel.access == .granted)
            StatusTag(text: lensEnabled ? "lente attiva" : "lente spenta",
                      active: lensEnabled)
            if soglia.attiva {
                StatusTag(text: String(format: "soglia %.0f%%", soglia.livello * 100),
                          active: true)
            }
            Spacer()
            Menu {
                Toggle("Sguardo", isOn: $angleEnabled)
                Toggle("Sguardi", isOn: $watchEnabled)
                Toggle("Lente", isOn: $lensEnabled)
                Toggle("Soglia", isOn: $soglia.attiva)
                Toggle("Trama", isOn: $trama.attiva)
                Toggle("Schermo", isOn: $schermo.attivo)
                Divider()
                Button("Tara la soglia") { tarandoSoglia = true }
                Button("Tara la trama") { tarandoTrama = true }
                Button("Tara lo schermo") { tarandoSchermo = true }
                Divider()
                Button("Attiva su tutti i siti") { mostraAttiva = true }
                if guardModel.access == .denied {
                    Button("Apri Impostazioni") { openSettings() }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Ink.brass)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Ink.deep)
    }

    private var sguardoStato: String {
        guard angleEnabled else { return "sguardo spento" }
        if !sguardo.disponibile { return "TrueDepth assente" }
        if sguardo.senzaVolto { return "nessun volto" }
        return String(format: "%.0f cm · %.0f°", sguardo.distanza, sguardo.angolo)
    }

    private var watchStatusText: String {
        guard watchEnabled else { return "sguardi spenti" }
        switch guardModel.access {
        case .granted:      return "sguardi attivi"
        case .denied:       return "fotocamera negata"
        case .notRequested: return "sguardi in avvio"
        }
    }

    // MARK: Taratura

    /// Sta sopra la pellicola, così resta leggibile mentre l'utente inclina.
    // MARK: Lettura

    private var reader: some View {
        ScrollView {
            Group {
                if trama.attiva {
                    TramaText(model: trama, testo: note.body)
                } else if lensEnabled {
                    SpotRevealText(text: note.body)
                } else {
                    Text(note.body)
                        .font(.page())
                        .lineSpacing(7)
                        .foregroundStyle(soglia.attiva ? soglia.inchiostro : Ink.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
        }
        .privacyGuard(guardModel, enabled: watchEnabled)
    }

    // MARK: Modifica

    private var editor: some View {
        VStack(spacing: 0) {
            TextField("Titolo", text: $note.title)
                .font(.pageTitle())
                .foregroundStyle(Ink.paper)
                .padding(.horizontal, 22)
                .padding(.top, 20)

            TextEditor(text: $note.body)
                .font(.page())
                .foregroundStyle(Ink.paper)
                .scrollContentBackground(.hidden)
                .background(Ink.base)
                .focused($typing)
                .padding(.horizontal, 18)
        }
        // In scrittura la lente resta spenta: duplicare un TextEditor
        // sdoppierebbe cursore e selezione. E l'angolo pure: scrivere su
        // uno schermo che si scurisce a ogni movimento è inusabile.
        .privacyGuard(guardModel, enabled: watchEnabled)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
