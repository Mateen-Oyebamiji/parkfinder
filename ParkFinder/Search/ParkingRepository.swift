//
//  ParkingRepository.swift
//  ParkFinder
//

import Foundation
import CoreLocation
import Observation

// The single source of truth for nearby parking, shared by the phone UI and CarPlay.
// It merges Apple Maps, Green P and community spots, then layers on community ratings and prices.
@Observable
final class ParkingRepository {
    private(set) var spots: [ParkingSpot] = []
    private(set) var summaries: [String: SpotSummary] = [:]
    private(set) var isSearching = false
    private(set) var errorMessage: String?
    private(set) var lastSearchCenter: CLLocation?

    @ObservationIgnored private let greenP = GreenPService()
    @ObservationIgnored let community: CommunityService

    /// Apple Maps lots this close to a Green P lot are treated as the same place.
    private static let duplicateDistance: CLLocationDistance = 45

    init(community: CommunityService) {
        self.community = community
    }

    func search(around coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 2000) async {
        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        // All three sources load at the same time.
        async let appleResult: Result<[ParkingSpot], Error> = {
            do { return .success(try await ParkingSearch.findParking(near: coordinate, radius: radius)) }
            catch { return .failure(error) }
        }()
        async let greenPSpots = greenP.spots(near: center, radius: radius)
        async let communitySpots = community.communitySpots(near: center, radius: radius)

        let official = await greenPSpots
        var apple: [ParkingSpot] = []
        switch await appleResult {
        case .success(let found): apple = found
        case .failure(let error): errorMessage = String(localized: "Search failed: \(error.localizedDescription)")
        }

        // Prefer the Green P record (it knows the type and rate), but keep Apple's phone/website.
        var merged = official
        for spot in apple {
            if let index = merged.firstIndex(where: { $0.location.distance(from: spot.location) < Self.duplicateDistance }) {
                if merged[index].mapItem == nil { merged[index].mapItem = spot.mapItem }
            } else {
                merged.append(spot)
            }
        }
        merged += await communitySpots

        spots = merged.sorted { $0.location.distance(from: center) < $1.location.distance(from: center) }
        lastSearchCenter = center
        await refreshSummaries()
    }

    /// Searches the first time we learn the user's location, and again after they move more than 1 km.
    func searchIfNeeded(around location: CLLocation) async {
        guard !isSearching else { return }
        if let lastSearchCenter, location.distance(from: lastSearchCenter) < 1000 { return }
        await search(around: location.coordinate)
    }

    /// Re-fetches ratings and prices for everything on the map.
    func refreshSummaries() async {
        let fresh = await community.summaries(forSpotIDs: spots.map(\.id))
        summaries.merge(fresh) { _, new in new }
        applyCommunityKinds()
    }

    func updateSummary(for spotID: String, reviews: [SpotReview]) {
        summaries[spotID] = SpotSummary(reviews: reviews)
        applyCommunityKinds()
    }

    /// Adds a spot someone just created so it appears without another search.
    func insert(_ spot: ParkingSpot) {
        guard !spots.contains(spot) else { return }
        spots.append(spot)
        if let center = lastSearchCenter {
            spots.sort { $0.location.distance(from: center) < $1.location.distance(from: center) }
        }
    }

    func spot(withID id: String) -> ParkingSpot? {
        spots.first { $0.id == id }
    }

    /// Nearest spot to a location, optionally limited to some kinds.
    func nearest(to location: CLLocation, kinds: Set<ParkingKind>? = nil) -> ParkingSpot? {
        spots(sortedFrom: location, kinds: kinds).first
    }

    func spots(sortedFrom location: CLLocation, kinds: Set<ParkingKind>? = nil) -> [ParkingSpot] {
        spots
            .filter { kinds == nil || kinds?.contains($0.kind) == true }
            .sorted { $0.location.distance(from: location) < $1.location.distance(from: location) }
    }

    /// A known spot the user is standing in, used after they park.
    func spot(containing location: CLLocation, within meters: CLLocationDistance = 60) -> ParkingSpot? {
        guard let closest = nearest(to: location),
              closest.location.distance(from: location) <= meters else { return nil }
        return closest
    }

    // Drivers know better than a name-based guess, so their majority vote wins
    // (official Green P types are left alone).
    private func applyCommunityKinds() {
        for index in spots.indices where spots[index].source != .greenP {
            if let kind = summaries[spots[index].id]?.consensusKind, kind != .unknown {
                spots[index].kind = kind
            }
        }
    }
}
