//
//  MapFilter.swift
//  ParkFinder
//

import Foundation

// The chips across the top of the map.
enum MapFilter: String, CaseIterable, Identifiable {
    case all, street, underground, openLot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .street: ParkingKind.street.shortName
        case .underground: ParkingKind.underground.shortName
        case .openLot: ParkingKind.openLot.shortName
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .street: ParkingKind.street.systemImage
        case .underground: ParkingKind.underground.systemImage
        case .openLot: ParkingKind.openLot.systemImage
        }
    }

    /// nil means "don't filter".
    var kinds: Set<ParkingKind>? {
        switch self {
        case .all: nil
        case .street: [.street]
        case .underground: [.underground]
        case .openLot: [.openLot]
        }
    }
}
