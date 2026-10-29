//
//  AppModel.swift
//  ParkFinder
//

import Foundation

// Owns the app's long-lived services. One shared instance so the iPhone UI and
// the CarPlay scene always see the same spots, favourites and parking state.
final class AppModel {
    static let shared = AppModel()

    let location = LocationManager()
    let community = CommunityService()
    let favorites = FavoritesStore()
    let notifications = ParkNotificationService()
    let repository: ParkingRepository
    let parking: ParkingDetector

    private init() {
        repository = ParkingRepository(community: community)
        parking = ParkingDetector(location: location, notifications: notifications, repository: repository)
    }
}
