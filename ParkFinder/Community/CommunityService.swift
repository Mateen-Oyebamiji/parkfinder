//
//  CommunityService.swift
//  ParkFinder
//

import Foundation
import CloudKit
import CoreLocation

// Reads and writes the shared data every driver sees: reviews, prices and crowd-sourced spots.
// Everything lives in the CloudKit *public* database, so anyone can read it and anyone
// signed into iCloud can contribute.
final class CommunityService {
    enum RecordType {
        static let review = "Review"
        static let spot = "CommunitySpot"
    }

    enum Field {
        static let spotID = "spotID"
        static let spotName = "spotName"
        static let rating = "rating"
        static let comment = "comment"
        static let pricePerHour = "pricePerHour"
        static let timeLimitMinutes = "timeLimitMinutes"
        static let kind = "kind"
        static let name = "name"
        static let address = "address"
        static let location = "location"
    }

    enum CommunityError: LocalizedError {
        case notSignedIn

        var errorDescription: String? {
            String(localized: "Sign in to iCloud in Settings to share reviews and prices.")
        }
    }

    private let container = CKContainer(identifier: "iCloud.OldMoneyCorp.ParkFinder")
    private var database: CKDatabase { container.publicCloudDatabase }

    // MARK: - Reading

    /// Every review for one spot, newest first.
    func reviews(forSpotID spotID: String) async throws -> [SpotReview] {
        let predicate = NSPredicate(format: "%K == %@", Field.spotID, spotID)
        let records = try await fetchAll(CKQuery(recordType: RecordType.review, predicate: predicate), limit: 100)
        return records.compactMap(Self.review(from:)).sorted { $0.createdAt > $1.createdAt }
    }

    /// Rating + price summaries for many spots at once, keyed by spot id.
    func summaries(forSpotIDs spotIDs: [String]) async -> [String: SpotSummary] {
        var grouped: [String: [SpotReview]] = [:]
        // CloudKit limits IN-lists, so ask in batches.
        for start in stride(from: 0, to: spotIDs.count, by: 50) {
            let batch = Array(spotIDs[start..<min(start + 50, spotIDs.count)])
            let predicate = NSPredicate(format: "%K IN %@", Field.spotID, batch)
            let query = CKQuery(recordType: RecordType.review, predicate: predicate)
            guard let records = try? await fetchAll(query, limit: 400) else { continue }
            for review in records.compactMap(Self.review(from:)) {
                grouped[review.spotID, default: []].append(review)
            }
        }
        return grouped.mapValues(SpotSummary.init(reviews:))
    }

    /// Street spots (and anything else) that drivers have added near a location.
    func communitySpots(near center: CLLocation, radius: CLLocationDistance) async -> [ParkingSpot] {
        // CloudKit measures this radius in kilometres.
        let predicate = NSPredicate(format: "distanceToLocation:fromLocation:(%K, %@) < %f",
                                    Field.location, center, radius / 1000)
        let query = CKQuery(recordType: RecordType.spot, predicate: predicate)
        guard let records = try? await fetchAll(query, limit: 200) else { return [] }
        return records.compactMap(Self.spot(from:))
            .filter { $0.location.distance(from: center) <= radius }
    }

    // MARK: - Writing

    @discardableResult
    func submitReview(for spot: ParkingSpot,
                      rating: Int,
                      comment: String,
                      pricePerHour: Double?,
                      timeLimitMinutes: Int?,
                      kind: ParkingKind?) async throws -> SpotReview {
        try await requireAccount()
        let record = CKRecord(recordType: RecordType.review)
        record[Field.spotID] = spot.id
        record[Field.spotName] = spot.name
        record[Field.rating] = rating
        record[Field.comment] = comment
        record[Field.pricePerHour] = pricePerHour
        record[Field.timeLimitMinutes] = timeLimitMinutes
        record[Field.kind] = kind?.rawValue
        record[Field.location] = spot.location
        let saved = try await database.save(record)
        return Self.review(from: saved) ?? SpotReview(id: saved.recordID.recordName, spotID: spot.id,
                                                       rating: rating, comment: comment,
                                                       pricePerHour: pricePerHour,
                                                       timeLimitMinutes: timeLimitMinutes,
                                                       kind: kind, createdAt: .now)
    }

    /// Adds a new spot for everyone, e.g. a stretch of street parking.
    func addSpot(name: String, coordinate: CLLocationCoordinate2D,
                 kind: ParkingKind, address: String?) async throws -> ParkingSpot {
        try await requireAccount()
        let record = CKRecord(recordType: RecordType.spot)
        record[Field.name] = name
        record[Field.kind] = kind.rawValue
        record[Field.address] = address
        record[Field.location] = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let saved = try await database.save(record)
        guard let spot = Self.spot(from: saved) else { throw CKError(.internalError) }
        return spot
    }

    // MARK: - Helpers

    private func requireAccount() async throws {
        guard try await container.accountStatus() == .available else { throw CommunityError.notSignedIn }
    }

    private func fetchAll(_ query: CKQuery, limit: Int) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var (results, cursor) = try await database.records(matching: query, resultsLimit: min(limit, 200))
        records += results.compactMap { try? $0.1.get() }
        while let next = cursor, records.count < limit {
            (results, cursor) = try await database.records(continuingMatchFrom: next)
            records += results.compactMap { try? $0.1.get() }
        }
        return records
    }

    private static func review(from record: CKRecord) -> SpotReview? {
        guard let spotID = record[Field.spotID] as? String,
              let rating = record[Field.rating] as? Int else { return nil }
        return SpotReview(id: record.recordID.recordName,
                          spotID: spotID,
                          rating: rating,
                          comment: record[Field.comment] as? String ?? "",
                          pricePerHour: record[Field.pricePerHour] as? Double,
                          timeLimitMinutes: record[Field.timeLimitMinutes] as? Int,
                          kind: (record[Field.kind] as? String).flatMap(ParkingKind.init(rawValue:)),
                          createdAt: record.creationDate ?? .now)
    }

    private static func spot(from record: CKRecord) -> ParkingSpot? {
        guard let name = record[Field.name] as? String,
              let location = record[Field.location] as? CLLocation else { return nil }
        let kind = (record[Field.kind] as? String).flatMap(ParkingKind.init(rawValue:)) ?? .street
        return ParkingSpot(id: "community-\(record.recordID.recordName)",
                           name: name,
                           coordinate: location.coordinate,
                           address: record[Field.address] as? String,
                           kind: kind,
                           source: .community)
    }
}
