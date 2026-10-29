//
//  NearestSpotCard.swift
//  ParkFinder
//

import SwiftUI
import CoreLocation

// The glass card at the bottom of the map showing the closest spot that matches the filter.
struct NearestSpotCard: View {
    let spot: ParkingSpot
    let summary: SpotSummary?
    let userLocation: CLLocation?
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    SpotPin(kind: spot.kind, isFavorite: false, isSelected: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEAREST \(spot.kind.shortName.uppercased())")
                            .font(.caption2.bold())
                            .tracking(1.2)
                            .foregroundStyle(Color.gold)
                        Text(spot.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(detailLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows details for this spot")

            Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                spot.openDirections()
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(Color.ink)
            .frame(width: 50, height: 50)
            .background(.goldGradient, in: .circle)
        }
        .padding(14)
        .glassPanel(in: .rect(cornerRadius: 24))
    }

    private var detailLine: String {
        var parts: [String] = []
        if let distance = spot.distanceText(from: userLocation) { parts.append(distance) }
        if let summary, summary.reviewCount > 0 {
            parts.append("★ " + summary.averageRating.formatted(.number.precision(.fractionLength(1))))
        }
        if let price = summary?.latestPricePerHour {
            parts.append(price == 0 ? String(localized: "Free") : price.hourlyPriceText)
        } else if let rate = spot.officialRate {
            parts.append(rate)
        }
        return parts.joined(separator: " · ")
    }
}
