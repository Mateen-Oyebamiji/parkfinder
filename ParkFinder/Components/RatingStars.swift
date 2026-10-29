//
//  RatingStars.swift
//  ParkFinder
//

import SwiftUI

// Read-only gold stars, supporting half stars for averages.
struct RatingStars: View {
    let rating: Double
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { position in
                Image(systemName: symbol(for: position))
            }
        }
        .font(font)
        .foregroundStyle(Color.gold)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(rating, format: .number.precision(.fractionLength(1))) out of 5 stars"))
    }

    private func symbol(for position: Int) -> String {
        let value = Double(position)
        if rating >= value { return "star.fill" }
        if rating >= value - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

#Preview {
    RatingStars(rating: 3.5, font: .title)
        .padding()
        .background(Color.ink)
}
