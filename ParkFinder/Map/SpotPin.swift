//
//  SpotPin.swift
//  ParkFinder
//

import SwiftUI

// The custom gold map pin. Street spots get a rounded square so they read differently
// from lots and garages even at a glance.
struct SpotPin: View {
    let kind: ParkingKind
    let isFavorite: Bool
    let isSelected: Bool

    var body: some View {
        let shape = kind == .street ? AnyShape(.rect(cornerRadius: 8)) : AnyShape(.circle)

        Image(systemName: kind.systemImage)
            .font(.system(size: isSelected ? 18 : 14, weight: .bold))
            .foregroundStyle(Color.ink)
            .frame(width: isSelected ? 42 : 32, height: isSelected ? 42 : 32)
            .background(.goldGradient, in: shape)
            .overlay(shape.stroke(Color.ink, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.gold)
                        .padding(3)
                        .background(Color.ink, in: .circle)
                        .offset(x: 6, y: -6)
                }
            }
            .shadow(color: .gold.opacity(isSelected ? 0.6 : 0.25), radius: isSelected ? 10 : 4)
            .animation(.snappy, value: isSelected)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        SpotPin(kind: .street, isFavorite: true, isSelected: false)
        SpotPin(kind: .underground, isFavorite: false, isSelected: true)
        SpotPin(kind: .openLot, isFavorite: false, isSelected: false)
    }
    .padding(40)
    .background(Color.ink)
}
