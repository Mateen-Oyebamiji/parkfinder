//
//  ParkingSearch.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-20.
//

import Foundation
import MapKit

enum ParkingSearch {
    // Asks Apple Maps for every parking lot/garage within `radius` metres of `center`.
    static func findParking(near center: CLLocationCoordinate2D,
                            radius: CLLocationDistance = 2000) async throws -> [ParkingSpot] {
        let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { ParkingSpot(mapItem: $0) }
        } catch let error as MKError where error.code == .placemarkNotFound {
            // "Nothing found" isn't really an error — it just means no parking here.
            return []
        }
    }
}
