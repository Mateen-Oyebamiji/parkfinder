//
//  SpotReportView.swift
//  ParkFinder
//

import SwiftUI
import MapKit

// The questions asked after parking (or when adding a spot by hand):
// what kind of parking it is, what it cost, any time limit, and a rating.
struct SpotReportView: View {
    enum Mode: String, Hashable {
        case parked     // parking detection noticed the user stopped
        case addSpot    // the user is adding a spot from the map
    }

    let session: ParkedSession
    let mode: Mode

    @Environment(ParkingRepository.self) private var repository
    @Environment(ParkingDetector.self) private var parking
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ParkingKind = .street
    @State private var useMatchedSpot = true
    @State private var spotName = ""
    @State private var rating = 4
    @State private var isFree = false
    @State private var pricePerHour: Double?
    @State private var timeLimitMinutes = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    /// A spot we already know about where the user stopped, e.g. a Green P garage.
    private var matchedSpot: ParkingSpot? {
        repository.spot(containing: session.location)
    }

    private var isReviewingMatchedSpot: Bool {
        matchedSpot != nil && useMatchedSpot
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if let matchedSpot {
                    Section {
                        Toggle(isOn: $useMatchedSpot.animation()) {
                            VStack(alignment: .leading) {
                                Text("Parked at \(matchedSpot.name)?")
                                Text(matchedSpot.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("What kind of parking?") {
                    ParkingKindPicker(selection: $kind)
                    if !isReviewingMatchedSpot {
                        TextField("Spot name, e.g. Queen St W meters", text: $spotName)
                    }
                }

                PriceFields(kind: kind, isFree: $isFree,
                            pricePerHour: $pricePerHour,
                            timeLimitMinutes: $timeLimitMinutes)

                Section("How was it?") {
                    StarRatingPicker(rating: $rating)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    TextField("Anything other drivers should know?", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(mode == .parked ? "Share with Drivers" : "Add Spot", systemImage: "paperplane.fill") {
                        Task { await submit() }
                    }
                    .buttonStyle(.gold)
                    .disabled(isSubmitting || (!isReviewingMatchedSpot && spotName.trimmingCharacters(in: .whitespaces).isEmpty))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink)
            .navigationTitle(mode == .parked ? "You Parked" : "Add a Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .parked ? "Not Now" : "Cancel") { close() }
                }
                if isSubmitting {
                    ToolbarItem(placement: .confirmationAction) {
                        ProgressView()
                    }
                }
            }
            .task {
                configureDefaults()
                if spotName.isEmpty, let address = await StreetNamer.address(for: session.location) {
                    spotName = address
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Map(initialPosition: .region(MKCoordinateRegion(center: session.coordinate,
                                                            latitudinalMeters: 250,
                                                            longitudinalMeters: 250))) {
                Annotation("Your car", coordinate: session.coordinate) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(Color.ink)
                        .padding(8)
                        .background(.goldGradient, in: .circle)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(height: 150)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.goldGradient, lineWidth: 1.5))
            .accessibilityHidden(true)

            if mode == .parked {
                Text("Parked \(session.parkedAt, format: .relative(presentation: .named)). Your car's location is saved. Tell other drivers about this spot.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    private func configureDefaults() {
        if let preselected = parking.preselectedKind, mode == .parked {
            kind = preselected
        } else if let matchedSpot, matchedSpot.kind != .unknown {
            kind = matchedSpot.kind
        } else {
            kind = .street
        }
    }

    private func close() {
        if mode == .parked {
            parking.pendingPrompt = nil
            parking.preselectedKind = nil
        }
        dismiss()
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let community = repository.community
            let target: ParkingSpot
            if let matchedSpot, useMatchedSpot {
                target = matchedSpot
            } else {
                // A new spot for everyone — this is how street parking gets onto the map.
                let name = spotName.trimmingCharacters(in: .whitespaces)
                target = try await community.addSpot(name: name,
                                                     coordinate: session.coordinate,
                                                     kind: kind,
                                                     address: name)
                repository.insert(target)
            }

            let review = try await community.submitReview(
                for: target,
                rating: rating,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                pricePerHour: isFree ? 0 : pricePerHour,
                timeLimitMinutes: timeLimitMinutes > 0 ? timeLimitMinutes : nil,
                kind: kind)

            let allReviews = (try? await community.reviews(forSpotID: target.id)) ?? [review]
            repository.updateSummary(for: target.id, reviews: allReviews)

            if mode == .parked { parking.markQuestionsAnswered() }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
