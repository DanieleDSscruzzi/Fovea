//
//  NoteStore.swift
//  Fovea — By D.S.
//
//  Persistenza volutamente banale: un JSON in Documents, protetto a livello
//  file da .completeFileProtection. Niente iCloud, niente rete: se il valore
//  dell'app è la riservatezza, i dati non devono uscire dal telefono.
//

import Foundation

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var updated: Date = Date()

    /// Titolo mostrato in libreria: se l'utente non l'ha scritto, si deduce
    /// dalla prima riga del testo.
    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        let first = body.split(separator: "\n").first.map(String.init) ?? ""
        return first.isEmpty ? "Senza titolo" : String(first.prefix(60))
    }

    var preview: String {
        body.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

@MainActor
final class NoteStore: ObservableObject {

    @Published private(set) var notes: [Note] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("fovea-notes.json")
    }()

    init() { load() }

    // MARK: Lettura e scrittura

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            notes = [Note.sample]
            return
        }
        notes = decoded.sorted { $0.updated > $1.updated }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: Modifiche

    @discardableResult
    func create() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        save()
        return note
    }

    func update(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var edited = note
        edited.updated = Date()
        notes[i] = edited
        notes.sort { $0.updated > $1.updated }
        save()
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }
}

extension Note {
    static let sample = Note(
        title: "Come funziona Fovea",
        body: """
        Fovea serve a leggere qualcosa in un posto dove non sei solo.

        Sguardi
        La fotocamera frontale conta i volti davanti al telefono. Se ne \
        compare un secondo, la pagina si copre in meno di mezzo secondo e \
        torna leggibile da sola quando la persona se ne va. Nessuna \
        immagine viene salvata o inviata: il conteggio avviene sul \
        dispositivo e i fotogrammi vengono scartati subito.

        Lente
        Tieni il dito sulla pagina: resta nitido solo quello che stai \
        leggendo, il resto è sfocato. Funziona anche senza fotocamera, e \
        contro chi legge da sopra la tua spalla è la difesa più solida \
        delle due, perché non deve indovinare nulla.

        Limiti, detti chiaramente
        Nessun software può restringere l'angolo di visione di uno schermo: \
        quella è una proprietà fisica del pannello e serve una pellicola a \
        microlamelle. Fovea non fa miracoli, riduce la superficie leggibile \
        e il tempo in cui resta esposta.
        """,
        updated: Date()
    )
}
