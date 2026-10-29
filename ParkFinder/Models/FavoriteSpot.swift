//
//  FavoriteSpot.swift
//  ParkFinder
//

import Foundation
import CoreLocation

// A saved copy of a spot, so favourites still show up without a fresh search.
struct FavoriteSpot: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let kind: ParkingKind
    let source: SpotSource
    let officialRate: String?
    let savedAt: Date

    init(spot: ParkingSpot) {
        id = spot.id
        name = spot.name
        latitude = spot.coordinate.latitude
        longitude = spot.coordinate.longitude
        address = spot.address
        kind = spot.kind
        source = spot.source
        officialRate = spot.officialRate
        savedAt = .now
    }

    var spot: ParkingSpot {
        ParkingSpot(id: id,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    address: address,
                    kind: kind,
                    source: source,
                    officialRate: officialRate)
    }
}
