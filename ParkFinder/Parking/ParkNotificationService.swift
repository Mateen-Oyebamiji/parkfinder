//
//  ParkNotificationService.swift
//  ParkFinder
//

import Foundation
import UserNotifications

// Sends the "Looks like you parked" notification, with quick buttons for the parking type.
final class ParkNotificationService: NSObject, UNUserNotificationCenterDelegate {
    nonisolated static let categoryID = "PARKED"

    /// Called when the user taps the notification. The kind is set if they tapped a type button.
    var onParkedResponse: ((ParkingKind?) -> Void)?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        let actions = ParkingKind.choosable.map {
            UNNotificationAction(identifier: $0.rawValue, title: $0.displayName, options: [.foreground])
        }
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: actions,
                                              intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func sendParkedPrompt(nearSpotName spotName: String?) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Parked?")
        if let spotName {
            content.body = String(localized: "Looks like you're at \(spotName). Tap to rate it and share what you paid.")
        } else {
            content.body = String(localized: "Street, underground or open lot? Tap to share the price and rate the spot for other drivers.")
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        let request = UNNotificationRequest(identifier: "parked-\(Date.now.timeIntervalSince1970)",
                                            content: content,
                                            trigger: nil)
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.categoryIdentifier == Self.categoryID else { return }
        let kind = ParkingKind(rawValue: response.actionIdentifier)
        await MainActor.run {
            onParkedResponse?(kind)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
