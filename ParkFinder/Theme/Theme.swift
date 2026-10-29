//
//  Theme.swift
//  ParkFinder
//

import SwiftUI

// The black-and-gold palette used across the app (and mirrored in CarPlay).
extension Color {
    /// Main brand gold (#D4AF37). Reads at roughly 9:1 contrast on black.
    static let gold = Color(red: 0.831, green: 0.686, blue: 0.216)
    /// Lighter highlight gold used at the top of gradients.
    static let goldLight = Color(red: 0.961, green: 0.851, blue: 0.494)
    /// Darker gold for pressed states and gradient bottoms.
    static let goldDeep = Color(red: 0.604, green: 0.471, blue: 0.098)
    /// Near-black app background.
    static let ink = Color(red: 0.039, green: 0.039, blue: 0.047)
    /// Slightly lifted black for cards and rows.
    static let charcoal = Color(red: 0.094, green: 0.094, blue: 0.106)
}

extension ShapeStyle where Self == LinearGradient {
    /// A metallic gold sheen for prominent surfaces.
    static var goldGradient: LinearGradient {
        LinearGradient(colors: [.goldLight, .gold, .goldDeep],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}
