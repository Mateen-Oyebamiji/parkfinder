//
//  StreetNamer.swift
//  ParkFinder
//

import Foundation
import MapKit

// Turns a coordinate into a short address, used to name new street-parking spots.
enum StreetNamer {
    static func address(for location: CLLocation) async -> String? {
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first else { return nil }
            return item.address?.shortAddress ?? item.name
        } else {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            return placemark?.thoroughfare ?? placemark?.name
        }
    }
}
