//
//  ReviewFormView.swift
//  ParkFinder
//

import SwiftUI

// Rate a spot and report what it costs, so the price shown to everyone stays current.
struct ReviewFormView: View {
    let spot: ParkingSpot
    let onSubmitted: (SpotReview) -> Void

    @Environment(ParkingRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 4
    @State private var kind: ParkingKind
    @State private var isFree = false
    @State private var pricePerHour: Double?
    @State private var timeLimitMinutes = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(spot: ParkingSpot, onSubmitted: @escaping (SpotReview) -> Void) {
        self.spot = spot
        self.onSubmitted = onSubmitted
        _kind = State(initialValue: spot.kind == .unknown ? .openLot : spot.kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your rating") {
                    StarRatingPicker(rating: $rating)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }

                Section("What kind of parking is it?") {
                    ParkingKindPicker(selection: $kind)
                }

                PriceFields(kind: kind, isFree: $isFree,
                            pricePerHour: $pricePerHour,
                            timeLimitMinutes: $timeLimitMinutes)

                Section("Comments") {
                    TextField("Easy to find? Tight spaces? Well lit?", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink)
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task { await submit() }
                        }
                        .bold()
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let review = try await repository.community.submitReview(
                for: spot,
                rating: rating,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                pricePerHour: isFree ? 0 : pricePerHour,
                timeLimitMinutes: timeLimitMinutes > 0 ? timeLimitMinutes : nil,
                kind: kind)
            onSubmitted(review)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
