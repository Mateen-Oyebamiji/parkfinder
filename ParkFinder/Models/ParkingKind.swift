//
//  ParkingKind.swift
//  ParkFinder
//

import Foundation

// What sort of parking a spot is. Stored as a string in CloudKit, so never rename raw values.
enum ParkingKind: String, Codable, CaseIterable, Identifiable {
    case street
    case underground
    case openLot
    case unknown

    var id: String { rawValue }

    /// The kinds a person can choose when describing a spot.
    static let choosable: [ParkingKind] = [.street, .underground, .openLot]

    var displayName: String {
        switch self {
        case .street: String(localized: "Street")
        case .underground: String(localized: "Underground / Garage")
        case .openLot: String(localized: "Open Lot")
        case .unknown: String(localized: "Parking")
        }
    }

    var shortName: String {
        switch self {
        case .street: String(localized: "Street")
        case .underground: String(localized: "Underground")
        case .openLot: String(localized: "Lot")
        case .unknown: String(localized: "Parking")
        }
    }

    var systemImage: String {
        switch self {
        case .street: "road.lanes"
        case .underground: "arrow.down.square.fill"
        case .openLot: "parkingsign"
        case .unknown: "parkingsign.circle"
        }
    }

    /// Best guess from a place name, since Apple Maps doesn't say what kind of parking it is.
    static func guess(fromName name: String) -> ParkingKind {
        let lowered = name.lowercased()
        let undergroundWords = ["underground", "garage", "parkade", "parking structure", "deck", "indoor"]
        let lotWords = ["surface", " lot", "lot ", "open air", "outdoor"]
        if undergroundWords.contains(where: lowered.contains) { return .underground }
        if lotWords.contains(where: lowered.contains) || lowered.hasSuffix("lot") { return .openLot }
        if lowered.contains("street") && lowered.contains("parking") { return .street }
        return .unknown
    }
}
