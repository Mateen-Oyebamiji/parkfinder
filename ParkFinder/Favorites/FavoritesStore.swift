//
//  FavoritesStore.swift
//  ParkFinder
//

import Foundation
import Observation

// The user's saved spots, kept on-device as a small JSON file.
@Observable
final class FavoritesStore {
    private(set) var favorites: [FavoriteSpot] = []

    @ObservationIgnored private let fileURL = URL.applicationSupportDirectory.appending(path: "favorites.json")

    init() {
        load()
    }

    func isFavorite(_ spot: ParkingSpot) -> Bool {
        favorites.contains { $0.id == spot.id }
    }

    func toggle(_ spot: ParkingSpot) {
        if let index = favorites.firstIndex(where: { $0.id == spot.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(FavoriteSpot(spot: spot), at: 0)
        }
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            favorites.remove(at: index)
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        favorites = (try? JSONDecoder().decode([FavoriteSpot].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(favorites).write(to: fileURL, options: .atomic)
        } catch {
            print("Couldn't save favourites: \(error.localizedDescription)")
        }
    }
}
