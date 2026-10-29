//
//  LocationManager.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-20.
//

import Foundation
import CoreLocation
import Observation

// This class asks for permission and keeps track of where the user is.
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    // These values are what the rest of the app reads.
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// True when iOS has tried and failed to get a fix (no GPS signal, or no simulated location).
    var hasNoSignal = false

    /// Called when iOS reports the user has arrived somewhere (works even if the app was closed).
    @ObservationIgnored var onVisit: ((CLVisit) -> Void)?
    /// Called for every new location fix, used by parking detection.
    @ObservationIgnored var onLocation: ((CLLocation) -> Void)?

    // Apple's object that actually talks to the GPS. Created on the main thread,
    // so its delegate callbacks also arrive on the main thread.
    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self                          // "tell ME when something happens"
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20                      // only update after moving 20 m
        manager.activityType = .automotiveNavigation
        // With the automotive activity type, iOS pauses updates when the device sits still —
        // exactly when someone is looking for parking. Keep updates flowing.
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    var hasAlwaysPermission: Bool { authorizationStatus == .authorizedAlways }

    // Shows the "Allow location?" popup (only the first time).
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Asks to upgrade to "Always" so we can notice parking while the app is closed.
    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    /// Starts the low-power monitors that wake the app when a drive starts or ends.
    func startBackgroundMonitoring() {
        guard hasAlwaysPermission else { return }
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopBackgroundMonitoring() {
        manager.stopMonitoringVisits()
        manager.stopMonitoringSignificantLocationChanges()
        setPreciseBackgroundTracking(false)
    }

    /// While driving, keep precise GPS running in the background so we know exactly where the car stopped.
    func setPreciseBackgroundTracking(_ enabled: Bool) {
        guard hasAlwaysPermission else { return }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = false
        if enabled { manager.startUpdatingLocation() }
    }

    // MARK: - Messages from Apple's location manager

    // Called when the user answers the popup (or changes it later in Settings).
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    // Called every time we get a new position.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        MainActor.assumeIsolated {
            location = newest
            hasNoSignal = false
            onLocation?(newest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        MainActor.assumeIsolated {
            onVisit?(visit)
        }
    }

    // Called if getting the location fails (e.g. no GPS signal yet). iOS keeps trying,
    // so we just flag it for the UI and keep waiting.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let isNoSignal = (error as? CLError)?.code == .locationUnknown
        MainActor.assumeIsolated {
            if isNoSignal && location == nil { hasNoSignal = true }
        }
        print("Location error: \(error.localizedDescription)")
    }
}
