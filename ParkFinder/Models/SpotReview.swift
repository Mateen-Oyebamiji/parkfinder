//
//  SpotReview.swift
//  ParkFinder
//

import Foundation

// One driver's review of a spot, including the price they paid.
struct SpotReview: Identifiable, Hashable {
    let id: String
    let spotID: String
    let rating: Int                 // 1...5 stars
    let comment: String
    let pricePerHour: Double?       // what they paid, if anything
    let timeLimitMinutes: Int?      // mostly for street parking
    let kind: ParkingKind?          // what they say the spot actually is
    let createdAt: Date
}
