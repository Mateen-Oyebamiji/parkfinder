//
//  GreenPService.swift
//  ParkFinder
//

import Foundation
import CoreLocation

// Loads City of Toronto Green P car parks (garages + surface lots with official rates).
// The feed is small (~270 KB), so it's downloaded once, cached on disk, and filtered locally.
final class GreenPService {
    private static let feedURL = URL(string: "https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/b66466c3-69c8-4825-9c8b-04b270069193/resource/8549d588-30b0-482e-b872-b21beefdda22/download/green-p-parking-2019.json")!
    private static let torontoCenter = CLLocation(latitude: 43.6532, longitude: -79.3832)
    private static let coverageRadius: CLLocationDistance = 60_000
    private static let cacheLifetime: TimeInterval = 7 * 24 * 60 * 60

    private var allSpots: [ParkingSpot]?

    private var cacheURL: URL {
        URL.cachesDirectory.appending(path: "green-p-parking.json")
    }

    /// Green P spots within `radius` of `center`, or nothing if the user isn't near Toronto.
    func spots(near center: CLLocation, radius: CLLocationDistance) async -> [ParkingSpot] {
        guard center.distance(from: Self.torontoCenter) < Self.coverageRadius else { return [] }
        do {
            let spots = try await loadAll()
            return spots.filter { $0.location.distance(from: center) <= radius }
        } catch {
            print("Green P feed failed: \(error.localizedDescription)")
            return []
        }
    }

    private func loadAll() async throws -> [ParkingSpot] {
        if let allSpots { return allSpots }

        let data: Data
        if let cached = try? Data(contentsOf: cacheURL), isCacheFresh {
            data = cached
        } else {
            do {
                let (downloaded, _) = try await URLSession.shared.data(from: Self.feedURL)
                try? downloaded.write(to: cacheURL, options: .atomic)
                data = downloaded
            } catch {
                // Offline: fall back to a stale cache if we have one.
                guard let stale = try? Data(contentsOf: cacheURL) else { throw error }
                data = stale
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let spots = try decoder.decode(GreenPCarpark.Feed.self, from: data).carparks.compactMap(\.parkingSpot)
        allSpots = spots
        return spots
    }

    private var isCacheFresh: Bool {
        guard let values = try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else { return false }
        return Date.now.timeIntervalSince(modified) < Self.cacheLifetime
    }
}
