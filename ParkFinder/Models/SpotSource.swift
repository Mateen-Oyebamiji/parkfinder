//
//  SpotSource.swift
//  ParkFinder
//

import Foundation

// Where a parking spot's information came from.
enum SpotSource: String, Codable {
    case appleMaps
    case greenP
    case community

    var label: String {
        switch self {
        case .appleMaps: String(localized: "Apple Maps")
        case .greenP: String(localized: "Green P (City of Toronto)")
        case .community: String(localized: "Added by drivers")
        }
    }
}
