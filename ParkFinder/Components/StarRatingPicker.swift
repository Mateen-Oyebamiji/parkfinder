//
//  StarRatingPicker.swift
//  ParkFinder
//

import SwiftUI

// Tappable 1–5 star input. Works as a VoiceOver adjustable control.
struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { position in
                Button {
                    rating = position
                } label: {
                    Image(systemName: position <= rating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(Color.gold)
                        .symbolEffect(.bounce, value: rating == position)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(Text("\(rating) out of 5 stars"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, 5)
            case .decrement: rating = max(rating - 1, 1)
            @unknown default: break
            }
        }
    }
}

#Preview {
    @Previewable @State var rating = 3
    StarRatingPicker(rating: $rating)
        .padding()
        .background(Color.ink)
}
