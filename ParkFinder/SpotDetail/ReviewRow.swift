//
//  ReviewRow.swift
//  ParkFinder
//

import SwiftUI

// One driver review in the detail sheet.
struct ReviewRow: View {
    let review: SpotReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RatingStars(rating: Double(review.rating))
                Spacer()
                Text(review.createdAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let price = review.pricePerHour {
                    Label(price == 0 ? String(localized: "Free") : price.hourlyPriceText,
                          systemImage: "dollarsign.circle.fill")
                }
                if let minutes = review.timeLimitMinutes, minutes > 0 {
                    let limit = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
                    Label("\(limit) limit", systemImage: "timer")
                }
                if let kind = review.kind {
                    Label(kind.shortName, systemImage: kind.systemImage)
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Color.gold)

            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.charcoal, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ReviewRow(review: SpotReview(id: "1", spotID: "x", rating: 4,
                                 comment: "Easy to find, a bit tight on level 2.",
                                 pricePerHour: 4, timeLimitMinutes: 120, kind: .underground,
                                 createdAt: .now.addingTimeInterval(-86_400)))
        .padding()
        .background(Color.ink)
}
