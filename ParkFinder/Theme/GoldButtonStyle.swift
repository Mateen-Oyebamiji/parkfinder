//
//  GoldButtonStyle.swift
//  ParkFinder
//

import SwiftUI

// A solid gold button with black text — the app's primary call to action.
struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.goldGradient, in: .rect(cornerRadius: 16))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GoldButtonStyle {
    static var gold: GoldButtonStyle { GoldButtonStyle() }
}
