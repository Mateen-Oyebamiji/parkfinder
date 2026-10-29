//
//  GlassPanel.swift
//  ParkFinder
//

import SwiftUI

// Liquid Glass on iOS 26+, a dark material with a thin gold rim on older systems.
struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S
    var tinted = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(tinted ? .regular.tint(.gold.opacity(0.35)).interactive() : .regular.interactive(),
                             in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.ink.opacity(0.6), in: shape)
                .overlay(shape.stroke(Color.gold.opacity(tinted ? 0.8 : 0.35), lineWidth: 1))
        }
    }
}

extension View {
    /// Wraps the view in the app's glass treatment.
    func glassPanel(in shape: some Shape = Capsule(), tinted: Bool = false) -> some View {
        modifier(GlassPanel(shape: shape, tinted: tinted))
    }
}
