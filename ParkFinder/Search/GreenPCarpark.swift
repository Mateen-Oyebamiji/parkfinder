//
//  GreenPCarpark.swift
//  ParkFinder
//

import Foundation
import CoreLocation

// The shape of one car park in the City of Toronto's Green P open-data feed.
// Every number arrives as a string, so it's converted when building a ParkingSpot.
struct GreenPCarpark: Decodable {
    struct Feed: Decodable {
        let carparks: [GreenPCarpark]
    }

    struct RateDetails: Decodable {
        let periods: [Period]
    }

    struct Period: Decodable {
        let title: String
        let rates: [Rate]
    }

    struct Rate: Decodable {
        let when: String
        let rate: String
    }

    let id: String
    let address: String
    let lat: String
    let lng: String
    let rate: String?
    let carparkType: String?
    let capacity: String?
    let isUnderConstruction: Bool?
    let rateDetails: RateDetails?

    var parkingSpot: ParkingSpot? {
        guard let latitude = Double(lat), let longitude = Double(lng),
              isUnderConstruction != true else { return nil }

        // Green P tags each car park as a "garage" (structure, mostly underground) or "surface" lot.
        let kind: ParkingKind = carparkType == "garage" ? .underground : .openLot
        let details = rateDetails?.periods.flatMap { period in
            period.rates.map { "\(period.title) · \($0.when): \($0.rate)" }
        } ?? []

        return ParkingSpot(id: "greenp-\(id)",
                           name: String(localized: "Green P – \(address)"),
                           coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                           address: address,
                           kind: kind,
                           source: .greenP,
                           officialRate: rate,
                           rateDetails: details,
                           capacity: capacity.flatMap { Int($0) })
    }
}
