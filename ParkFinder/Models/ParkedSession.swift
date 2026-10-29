//
//  ParkedSession.swift
//  ParkFinder
//

import Foundation
import CoreLocation

// Where and when the user last parked. Drives "Find my car" and the post-parking questions.
struct ParkedSession: Codable, Identifiable, Hashable {
    var id: Date { parkedAt }
    let latitude: Double
    let longitude: Double
    let parkedAt: Date
    var hasAnsweredQuestions = false

    init(location: CLLocation, parkedAt: Date = .now) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        self.parkedAt = parkedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
