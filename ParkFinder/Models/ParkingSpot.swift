//
//  ParkingSpot.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-20.
//

import Foundation
import MapKit

// One parking place shown on the map.
struct ParkingSpot: Identifiable {
    let id: String                          // a stable tag that reviews are attached to
    let name: String                        // e.g. "Green P Parking"
    let coordinate: CLLocationCoordinate2D  // where it is (latitude + longitude)
    let address: String?                    // may be missing, hence the ?
    var kind: ParkingKind                   // street, underground or open lot
    let source: SpotSource                  // Apple Maps, Green P or the community
    var officialRate: String?               // e.g. "$2.50 / Half Hour" from Green P
    var rateDetails: [String] = []          // e.g. "Day Maximum (7am - 6pm): $14.00"
    var capacity: Int?
    var mapItem: MKMapItem?                 // Apple's full info, when we have it
}

extension ParkingSpot {
    // Builds a ParkingSpot from an Apple Maps search result.
    init(mapItem: MKMapItem) {
        let coordinate: CLLocationCoordinate2D
        let address: String?
        if #available(iOS 26, *) {
            coordinate = mapItem.location.coordinate
            address = mapItem.address?.shortAddress ?? mapItem.address?.fullAddress
        } else {
            coordinate = mapItem.placemark.coordinate
            address = mapItem.placemark.title
        }
        let name = mapItem.name ?? String(localized: "Parking")

        self.init(id: ParkingSpot.makeID(name: name, coordinate: coordinate),
                  name: name,
                  coordinate: coordinate,
                  address: address,
                  kind: ParkingKind.guess(fromName: name),
                  source: .appleMaps,
                  mapItem: mapItem)
    }

    // The id is the name + location rounded to about 10 m, so the same lot always gets
    // the same id and its reviews follow it between searches and devices.
    static func makeID(name: String, coordinate: CLLocationCoordinate2D) -> String {
        name + String(format: "@%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
}

// Lets SwiftUI tell two spots apart (needed so a pin can be "selected").
// Two spots count as the same if their ids match.
extension ParkingSpot: Hashable {
    static func == (lhs: ParkingSpot, rhs: ParkingSpot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ParkingSpot {
    // The spot's position as a CLLocation, so we can measure distances.
    var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    // A map item suitable for handing to Apple Maps for directions.
    var directionsItem: MKMapItem {
        if let mapItem { return mapItem }
        let item: MKMapItem
        if #available(iOS 26, *) {
            item = MKMapItem(location: location, address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
        item.name = name
        return item
    }

    // Opens Apple Maps with driving directions to this spot.
    func openDirections() {
        directionsItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // "450 m" or "1.2 km" from the given location.
    func distanceText(from userLocation: CLLocation?) -> String? {
        guard let userLocation else { return nil }
        let meters = location.distance(from: userLocation)
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
