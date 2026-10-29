//
//  SpotSummary.swift
//  ParkFinder
//

import Foundation

// Everything the community has said about a spot, boiled down for display.
struct SpotSummary: Hashable {
    let averageRating: Double
    let reviewCount: Int
    let latestPricePerHour: Double?
    let latestPriceDate: Date?
    let consensusKind: ParkingKind?

    init(reviews: [SpotReview]) {
        reviewCount = reviews.count
        averageRating = reviews.isEmpty ? 0 : Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)

        // Prices change, so the newest report wins.
        let priced = reviews.filter { $0.pricePerHour != nil }.max { $0.createdAt < $1.createdAt }
        latestPricePerHour = priced?.pricePerHour
        latestPriceDate = priced?.createdAt

        // The kind most drivers picked overrides the name-based guess.
        let votes = Dictionary(grouping: reviews.compactMap(\.kind), by: { $0 }).mapValues(\.count)
        consensusKind = votes.max { $0.value < $1.value }?.key
    }
}

extension Double {
    /// Formats an hourly price in the user's currency, e.g. "$3.50/hr".
    var hourlyPriceText: String {
        let code = Locale.current.currency?.identifier ?? "CAD"
        let amount = self.formatted(.currency(code: code))
        return String(localized: "\(amount)/hr")
    }
}
