//
//  FavoritesView.swift
//  ParkFinder
//

import SwiftUI

// The user's saved spots, nearest first.
struct FavoritesView: View {
    let onSelect: (ParkingSpot) -> Void

    @Environment(FavoritesStore.self) private var favorites
    @Environment(ParkingRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        NavigationStack {
            Group {
                if favorites.favorites.isEmpty {
                    ContentUnavailableView {
                        Label("No Favourites Yet", systemImage: "star")
                            .foregroundStyle(Color.gold)
                    } description: {
                        Text("Tap the star on any spot to save it here and in CarPlay.")
                    }
                } else {
                    List {
                        ForEach(favorites.favorites) { favorite in
                            Button {
                                onSelect(repository.spot(withID: favorite.id) ?? favorite.spot)
                            } label: {
                                row(for: favorite)
                            }
                            .listRowBackground(Color.charcoal)
                        }
                        .onDelete(perform: favorites.remove(atOffsets:))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.ink)
            .navigationTitle("Favourites")
        }
    }

    private func row(for favorite: FavoriteSpot) -> some View {
        let spot = favorite.spot
        let summary = repository.summaries[favorite.id]
        return HStack(spacing: 12) {
            SpotPin(kind: favorite.kind, isFavorite: false, isSelected: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(favorite.kind.shortName)
                    if let distance = spot.distanceText(from: locationManager.location) {
                        Text("· \(distance)")
                    }
                    if let price = summary?.latestPricePerHour {
                        Text("· \(price == 0 ? String(localized: "Free") : price.hourlyPriceText)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let summary, summary.reviewCount > 0 {
                RatingStars(rating: summary.averageRating)
            }
        }
        .padding(.vertical, 4)
    }
}
