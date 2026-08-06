//
//  FoveaApp.swift
//  Fovea — By D.S. · perfezione assicurata
//

import SwiftUI

@main
struct FoveaApp: App {

    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Ink.brass)
        }
    }
}

struct LibraryView: View {

    @EnvironmentObject private var store: NoteStore
    @State private var newNote: Note?

    var body: some View {
        ZStack {
            Ink.base.ignoresSafeArea()

            if store.notes.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Documenti")
            .toolbarBackground(Ink.deep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newNote = store.create()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Ink.brass)
                }
            }
            .navigationDestination(item: $newNote) { note in
                ReaderView(note: note)
            }
    }

    private var list: some View {
        List {
            ForEach(store.notes) { note in
                NavigationLink {
                    ReaderView(note: note)
                } label: {
                    row(note)
                }
                .listRowBackground(Ink.base)
                .listRowSeparatorTint(Ink.muted.opacity(0.2))
            }
            .onDelete { store.delete(at: $0) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(note.displayTitle)
                .font(.pageTitle(17))
                .foregroundStyle(Ink.paper)
                .lineLimit(1)
            Text(note.preview)
                .font(.page(14))
                .foregroundStyle(Ink.muted)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }

    /// Uno schermo vuoto è un invito ad agire, non un'illustrazione.
    private var empty: some View {
        VStack(spacing: 14) {
            Text("Nessun documento")
                .font(.pageTitle())
                .foregroundStyle(Ink.paper)
            Text("Scrivi qui quello che non vuoi\nleggere con qualcuno alle spalle.")
                .font(.page(15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.muted)
            Button("Nuovo documento") { newNote = store.create() }
                .font(.signal)
                .tracking(1.4)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .overlay(Capsule().stroke(Ink.brass.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Ink.brass)
                .padding(.top, 8)
        }
    }
}
