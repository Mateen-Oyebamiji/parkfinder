//
//  ActiveSheet.swift
//  ParkFinder
//

import Foundation
import CoreLocation

// Every sheet the map screen can show. Only one at a time.
enum ActiveSheet: Identifiable, Hashable {
    case spot(ParkingSpot)
    case favorites
    case report(ParkedSession, SpotReportView.Mode)
    case settings

    var id: String {
        switch self {
        case .spot(let spot): "spot-\(spot.id)"
        case .favorites: "favorites"
        case .report(let session, let mode): "report-\(mode)-\(session.parkedAt.timeIntervalSince1970)"
        case .settings: "settings"
        }
    }
}
