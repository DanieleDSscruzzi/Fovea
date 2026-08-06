//
//  Design.swift
//  Fovea — By D.S.
//
//  Il mondo dell'app è la lettura di nascosto: microfilm, carta carbone,
//  documenti con le barre nere. Da lì arrivano colori e caratteri.
//

import SwiftUI

enum Ink {
    /// Fondo. Non nero pieno: il nero puro su OLED spegne i pixel e
    /// rende i bordi della lente troppo netti.
    static let base = Color(red: 0.086, green: 0.094, blue: 0.114)   // #16181D
    static let deep = Color(red: 0.043, green: 0.047, blue: 0.059)   // #0B0C0F
    /// Testo. Bianco sporco, meno affaticante in lettura lunga.
    static let paper = Color(red: 0.910, green: 0.902, blue: 0.882)  // #E8E6E1
    static let muted = Color(red: 0.478, green: 0.502, blue: 0.541)  // #7A8089
    /// Ottone. Unico accento, riservato alla lente e agli stati attivi.
    static let brass = Color(red: 0.784, green: 0.635, blue: 0.290)  // #C8A24A
}

extension Font {
    /// Corpo dei documenti: il serif di sistema, pensato per la lettura.
    static func page(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func pageTitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    /// Etichette di stato: monospace spaziato. Dice sempre qualcosa di vero
    /// sullo stato della protezione, non decora.
    static let signal = Font.system(size: 10, weight: .medium, design: .monospaced)
}

/// Etichetta di stato in alto: l'unico elemento che l'utente impara a leggere
/// con la coda dell'occhio per sapere se è coperto o in chiaro.
struct StatusTag: View {
    let text: String
    var active: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(.signal)
            .tracking(1.6)
            .foregroundStyle(active ? Ink.brass : Ink.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay(
                Capsule().stroke(active ? Ink.brass.opacity(0.5) : Ink.muted.opacity(0.3),
                                 lineWidth: 1)
            )
    }
}
