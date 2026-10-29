//
//  KindBadge.swift
//  ParkFinder
//

import SwiftUI

// A small gold-outlined capsule saying what kind of parking a spot is.
struct KindBadge: View {
    let kind: ParkingKind

    var body: some View {
        Label(kind.displayName, systemImage: kind.systemImage)
            .font(.caption.bold())
            .foregroundStyle(Color.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gold.opacity(0.12), in: .capsule)
            .overlay(Capsule().stroke(Color.gold.opacity(0.5), lineWidth: 1))
    }
}

#Preview {
    VStack {
        ForEach(ParkingKind.allCases) { KindBadge(kind: $0) }
    }
    .padding()
    .background(Color.ink)
}
