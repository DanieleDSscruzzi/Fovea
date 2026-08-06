//
//  SpotReveal.swift
//  Fovea — By D.S.
//
//  La lente. Due copie dello stesso testo nello stesso ZStack: quella sotto
//  sfocata, quella sopra nitida e mascherata da un gradiente radiale che
//  segue il dito. Stanno dentro la stessa ScrollView, quindi scorrono
//  insieme e restano allineate al pixel.
//

import SwiftUI

private struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct SpotRevealText: View {

    let text: String
    var radius: CGFloat = 74
    var blur: CGFloat = 13

    @State private var size: CGSize = .zero
    @State private var finger: CGPoint?

    private var center: UnitPoint {
        guard let finger, size.width > 0, size.height > 0 else {
            return UnitPoint(x: 0.5, y: 0.16)   // riposo: in cima, dove si inizia a leggere
        }
        return UnitPoint(x: finger.x / size.width, y: finger.y / size.height)
    }

    private var lensMask: some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.62),
                .init(color: .clear, location: 1.0)
            ]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            page.blur(radius: blur)
            page.mask(lensMask)
            // Anello d'ottone: senza un bordo visibile la lente sembra un
            // difetto di rendering invece di un comando.
            if finger != nil {
                Circle()
                    .strokeBorder(Ink.brass.opacity(0.35), lineWidth: 1)
                    .frame(width: radius * 1.25, height: radius * 1.25)
                    .position(x: center.x * size.width, y: center.y * size.height)
                    .allowsHitTesting(false)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizeKey.self) { size = $0 }
        .coordinateSpace(name: "page")
        // simultaneousGesture: la lente segue il dito senza rubare lo scorrimento.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("page"))
                .onChanged { finger = $0.location }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.4)) { finger = nil } }
        )
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.9), value: center)
    }

    private var page: some View {
        Text(text)
            .font(.page())
            .lineSpacing(7)
            .foregroundStyle(Ink.paper)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
