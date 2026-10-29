//
//  SpotDetailView.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-21.
//

import SwiftUI
import MapKit

// The panel that slides up when you tap a parking pin.
struct SpotDetailView: View {
    let spot: ParkingSpot          // which spot to show
    let userLocation: CLLocation?  // where the user is (may be unknown)

    @Environment(ParkingRepository.self) private var repository
    @Environment(FavoritesStore.self) private var favorites

    @State private var reviews: [SpotReview] = []
    @State private var isLoadingReviews = true
    @State private var loadError: String?
    @State private var isWritingReview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    stats
                    actions
                    if !spot.rateDetails.isEmpty { officialRates }
                    reviewsSection
                    contactLinks
                    Text("Source: \(spot.source.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    let isFavorite = favorites.isFavorite(spot)
                    Button(isFavorite ? "Remove from Favourites" : "Save to Favourites",
                           systemImage: isFavorite ? "star.fill" : "star") {
                        favorites.toggle(spot)
                    }
                    .foregroundStyle(Color.gold)
                    .symbolEffect(.bounce, value: isFavorite)
                    .sensoryFeedback(.success, trigger: isFavorite)
                }
            }
            .sheet(isPresented: $isWritingReview) {
                ReviewFormView(spot: spot) { review in
                    reviews.insert(review, at: 0)
                    repository.updateSummary(for: spot.id, reviews: reviews)
                }
                .presentationBackground(Color.ink)
            }
            .task(id: spot.id) {
                await loadReviews()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            KindBadge(kind: spot.kind)
            Text(spot.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
            if let address = spot.address, address != spot.name {
                Text(address)
                    .foregroundStyle(.secondary)
            }
            if let distance = spot.distanceText(from: userLocation) {
                Label("\(distance) away", systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.gold)
            }
        }
    }

    private var summary: SpotSummary {
        SpotSummary(reviews: reviews)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(title: "Rating",
                     value: summary.reviewCount == 0
                        ? String(localized: "New")
                        : "★ " + summary.averageRating.formatted(.number.precision(.fractionLength(1))),
                     footnote: String(localized: "\(summary.reviewCount) reviews"))

            if let price = summary.latestPricePerHour {
                StatTile(title: "Drivers paid",
                         value: price == 0 ? String(localized: "Free") : price.hourlyPriceText,
                         footnote: summary.latestPriceDate?.formatted(.relative(presentation: .named)))
            } else if let rate = spot.officialRate {
                StatTile(title: "Posted rate", value: rate)
            } else {
                StatTile(title: "Price", value: String(localized: "Unknown"), footnote: String(localized: "Be the first to report"))
            }

            if let capacity = spot.capacity, capacity > 0 {
                StatTile(title: "Spaces", value: capacity.formatted())
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                spot.openDirections()
            }
            .buttonStyle(.gold)

            Button("Rate & Report Price", systemImage: "square.and.pencil") {
                isWritingReview = true
            }
            .font(.headline)
            .foregroundStyle(Color.gold)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gold, lineWidth: 1.5))
        }
    }

    private var officialRates: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Official Rates")
            ForEach(spot.rateDetails, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Driver Reviews")
            if isLoadingReviews {
                ProgressView()
                    .tint(.gold)
                    .frame(maxWidth: .infinity)
            } else if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if reviews.isEmpty {
                Text("No reviews yet. Parked here? Let other drivers know what it cost.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reviews) { review in
                    ReviewRow(review: review)
                }
            }
        }
    }

    @ViewBuilder
    private var contactLinks: some View {
        // Only shown if Apple Maps knows a phone number or website for this spot
        if let mapItem = spot.mapItem {
            HStack(spacing: 16) {
                if let phone = mapItem.phoneNumber,
                   let callURL = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                    Link(destination: callURL) {
                        Label(phone, systemImage: "phone.fill")
                    }
                }
                if let website = mapItem.url {
                    Link(destination: website) {
                        Label("Website", systemImage: "safari.fill")
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.gold)
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.gold)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Loading

    private func loadReviews() async {
        isLoadingReviews = true
        loadError = nil
        do {
            reviews = try await repository.community.reviews(forSpotID: spot.id)
            repository.updateSummary(for: spot.id, reviews: reviews)
        } catch {
            loadError = String(localized: "Couldn't load reviews right now.")
        }
        isLoadingReviews = false
    }
}
