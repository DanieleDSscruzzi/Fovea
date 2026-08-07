//
//  HomeView.swift
//  Fovea — By D.S.
//
//  La home non è un elenco di documenti: è un quadro comandi.
//
//  L'elemento centrale è un provino dal vivo. Mostra un finto messaggio con
//  le protezioni attive applicate davvero — se inclini il telefono adesso,
//  qui si scurisce. Nessuna schermata di spiegazione regge il confronto con
//  vedere l'effetto mentre muovi la mano.
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var store: NoteStore
    @StateObject private var sguardo = SguardoModel()
    @StateObject private var soglia = SogliaModel()
    @StateObject private var trama = TramaModel()
    @StateObject private var schermo = SchermoModel()

    @AppStorage("fovea.angle") private var angolo = true
    @AppStorage("fovea.watch") private var sguardi = false
    @AppStorage("fovea.lens")  private var lente = false

    @State private var mostraAttiva = false
    @State private var mostraDocumenti = false
    @State private var estensione: Date? = Ponte.estensioneVista

    private var attive: Int {
        [angolo, sguardi, lente, soglia.attiva, trama.attiva, schermo.attivo]
            .filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Ink.base.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 26) {
                        testata
                        provino
                        comandi
                        fascia
                        documenti
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $mostraAttiva) { AttivaView() }
        .sheet(isPresented: $mostraDocumenti) {
            NavigationStack { LibraryView() }.environmentObject(store)
        }
        .onAppear {
            sguardo.avvia()
            schermo.cellaMisurata = sguardo.periodoConsigliato / 2
            estensione = Ponte.estensioneVista
        }
        .onDisappear { sguardo.ferma() }
    }

    // MARK: Testata

    private var testata: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fovea")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Ink.paper)
                Text("BY D.S.")
                    .font(.signal)
                    .tracking(2.4)
                    .foregroundStyle(Ink.muted)
            }
            Spacer()
            // Il conteggio è l'unica cifra grande della schermata: dice in un
            // colpo d'occhio quanto sei coperto.
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(attive)")
                    .font(.system(size: 30, weight: .light, design: .monospaced))
                    .foregroundStyle(attive > 0 ? Ink.brass : Ink.muted)
                Text("/6")
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundStyle(Ink.muted)
            }
        }
        .padding(.top, 14)
    }

    // MARK: Provino

    private var provino: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Ink.deep)

            VStack(alignment: .leading, spacing: 9) {
                Text("Banca — messaggio")
                    .font(.signal)
                    .tracking(1.4)
                    .foregroundStyle(Ink.muted)
                if trama.attiva {
                    TramaText(model: trama,
                              testo: "Bonifico di 1.480 € ricevuto.\nSaldo 3.912 €.",
                              dimensione: 15)
                } else {
                    Text("Bonifico di 1.480 € ricevuto.\nSaldo disponibile 3.912 €.\nCodice operazione 88-40217.")
                        .font(.page(16))
                        .lineSpacing(5)
                        .foregroundStyle(soglia.attiva ? soglia.inchiostro : Ink.paper)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .blur(radius: angolo ? CGFloat(sguardo.esposizione) * 13 : 0)
            .overlay {
                if angolo {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .opacity(sguardo.esposizione * 0.88)
                }
            }

            // Lettura dei gradi: serve a capire dove cadono le soglie
            // sul proprio iPhone, e rende evidente che il sensore lavora.
            if angolo {
                Text(sguardo.disponibile
                     ? String(format: "%.0f cm · %.0f°", sguardo.distanza, sguardo.angolo)
                     : "TrueDepth assente")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(sguardo.esposizione > 0.5 ? Ink.brass : Ink.muted)
                    .padding(14)
            }
        }
        .schermo(schermo)
        .frame(height: 172)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Ink.muted.opacity(0.16), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            Text(angolo ? "spostati di lato per provare" : "attiva Sguardo per provare")
                .font(.signal)
                .tracking(1.2)
                .foregroundStyle(Ink.muted)
                .padding(.bottom, -20)
        }
        .padding(.bottom, 18)
    }

    // MARK: Comandi

    private var comandi: some View {
        VStack(spacing: 0) {
            riga("Sguardo", "si copre quando lo schermo lascia i tuoi occhi",
                 isOn: $angolo)
            divisore
            riga("Sguardi", "copre se compare un secondo volto", isOn: $sguardi)
            divisore
            riga("Lente", "nitido solo sotto il dito", isOn: $lente)
            divisore
            riga("Soglia", "contrasto al minimo che leggi tu",
                 isOn: Binding(get: { soglia.attiva },
                               set: { soglia.attiva = $0 }))
            divisore
            riga("Trama", trama.attiva
                 ? String(format: "sparisce oltre %.0f cm", trama.distanzaDiSicurezza)
                 : "righe al limite dell'occhio",
                 isOn: Binding(get: { trama.attiva },
                               set: { trama.attiva = $0 }))
            divisore
            riga("Schermo", schermo.attivo
                 ? String(format: "si fonde oltre %.0f cm", schermo.distanzaDiFusione)
                 : "scacchiera su tutta l'interfaccia",
                 isOn: Binding(get: { schermo.attivo },
                               set: { schermo.attivo = $0 }))
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 18).fill(Ink.deep))
    }

    private var divisore: some View {
        Rectangle()
            .fill(Ink.muted.opacity(0.14))
            .frame(height: 1)
            .padding(.leading, 20)
    }

    private func riga(_ titolo: String, _ nota: String,
                      isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            // Barretta d'ottone al posto di un pallino: legge come uno
            // strato di velo che si accende, coerente col nome.
            RoundedRectangle(cornerRadius: 2)
                .fill(isOn.wrappedValue ? Ink.brass : Ink.muted.opacity(0.3))
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.pageTitle(17))
                    .foregroundStyle(Ink.paper)
                Text(nota)
                    .font(.page(12.5))
                    .foregroundStyle(Ink.muted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Ink.brass)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
    }

    // MARK: Fascia estensione

    private var fascia: some View {
        Button {
            mostraAttiva = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: estensione == nil ? "power" : "checkmark.shield")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(estensione == nil ? Ink.muted : Ink.brass)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(estensione == nil ? "Attiva su tutti i siti" : "Attiva su tutti i siti")
                        .font(.pageTitle(16))
                        .foregroundStyle(Ink.paper)
                    Text(estensione == nil
                         ? "l'estensione Safari non è ancora accesa"
                         : "Safari coperto su ogni pagina")
                        .font(.page(12.5))
                        .foregroundStyle(Ink.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.muted)
            }
            .padding(17)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Ink.deep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(estensione == nil ? Ink.brass.opacity(0.45) : .clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Documenti

    private var documenti: some View {
        Button {
            mostraDocumenti = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Documenti")
                        .font(.pageTitle(16))
                        .foregroundStyle(Ink.paper)
                    Text(store.notes.count == 1
                         ? "1 documento" : "\(store.notes.count) documenti")
                        .font(.page(12.5))
                        .foregroundStyle(Ink.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.muted)
            }
            .padding(17)
            .background(RoundedRectangle(cornerRadius: 18).fill(Ink.deep))
        }
        .buttonStyle(.plain)
    }
}
