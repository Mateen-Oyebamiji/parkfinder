//
//  ParkingDetector.swift
//  ParkFinder
//

import Foundation
import CoreLocation
import CoreMotion
import Observation

// Works out when a drive has ended so the app can remember the car and ask about the spot.
//
// Signals, strongest first:
//  1. CarPlay disconnects.
//  2. Motion goes from "automotive" to "walking", or stays "stationary" for a few minutes.
//  3. iOS reports a visit (arrival) and motion history shows we were just driving.
//     Visits relaunch the app even if it was closed.
@Observable
final class ParkingDetector {
    private(set) var isEnabled: Bool
    private(set) var isDriving = false
    /// The most recent parking event, used for "Find my car".
    private(set) var currentSession: ParkedSession?
    /// When set, the UI shows the "Tell us about this spot" questions.
    var pendingPrompt: ParkedSession?
    /// Parking type picked straight from the notification buttons.
    var preselectedKind: ParkingKind?

    @ObservationIgnored private let location: LocationManager
    @ObservationIgnored private let notifications: ParkNotificationService
    @ObservationIgnored private let repository: ParkingRepository
    @ObservationIgnored private let motion = CMMotionActivityManager()
    @ObservationIgnored private var stationaryCheck: Task<Void, Never>?

    private static let enabledKey = "parkDetectionEnabled"
    private static let sessionKey = "currentParkedSession"
    /// How long the car must sit still (without CarPlay or walking) before we call it parked.
    private static let stationaryDelay: Duration = .seconds(180)

    init(location: LocationManager, notifications: ParkNotificationService, repository: ParkingRepository) {
        self.location = location
        self.notifications = notifications
        self.repository = repository
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if let data = UserDefaults.standard.data(forKey: Self.sessionKey) {
            currentSession = try? JSONDecoder().decode(ParkedSession.self, from: data)
        }

        location.onVisit = { [weak self] visit in self?.handle(visit) }
        notifications.onParkedResponse = { [weak self] kind in self?.showPrompt(preselecting: kind) }

        if isEnabled { startMonitoring() }
    }

    // MARK: - Turning it on and off

    func enable() async {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        location.requestAlwaysPermission()
        await notifications.requestAuthorization()
        startMonitoring()
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        motion.stopActivityUpdates()
        location.stopBackgroundMonitoring()
        stationaryCheck?.cancel()
    }

    /// Call after the location permission changes, so background monitors start once "Always" is granted.
    func permissionsChanged() {
        if isEnabled { location.startBackgroundMonitoring() }
    }

    private func startMonitoring() {
        location.startBackgroundMonitoring()
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            MainActor.assumeIsolated {
                self?.handle(activity)
            }
        }
    }

    // MARK: - CarPlay

    func carPlayDidConnect() {
        beginDriving()
    }

    func carPlayDidDisconnect() {
        guard isEnabled else { return }
        markParked(at: location.location)
    }

    // MARK: - Manual

    /// "I just parked" button.
    func parkHereNow() {
        markParked(at: location.location, force: true)
    }

    func showPrompt(preselecting kind: ParkingKind?) {
        preselectedKind = kind
        if let currentSession {
            pendingPrompt = currentSession
        } else if let here = location.location {
            pendingPrompt = ParkedSession(location: here)
        }
    }

    func markQuestionsAnswered() {
        currentSession?.hasAnsweredQuestions = true
        pendingPrompt = nil
        preselectedKind = nil
        persist()
    }

    /// "I've left" — forget where the car is.
    func clearSession() {
        currentSession = nil
        pendingPrompt = nil
        persist()
    }

    // MARK: - Detection

    private func handle(_ activity: CMMotionActivity) {
        guard isEnabled, activity.confidence != .low else { return }

        if activity.automotive {
            beginDriving()
        } else if isDriving && (activity.walking || activity.running) {
            // Out of the car and on foot: definitely parked.
            markParked(at: location.location)
        } else if isDriving && activity.stationary {
            scheduleStationaryCheck()
        }
    }

    private func beginDriving() {
        isDriving = true
        stationaryCheck?.cancel()
        stationaryCheck = nil
        location.setPreciseBackgroundTracking(true)
    }

    private func scheduleStationaryCheck() {
        guard stationaryCheck == nil else { return }
        stationaryCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.stationaryDelay)
            guard let self, !Task.isCancelled else { return }
            self.stationaryCheck = nil
            // Still not moving after a few minutes (and not a long red light), so call it parked.
            if self.isDriving, (self.location.location?.speed ?? 0) < 1 {
                self.markParked(at: self.location.location)
            }
        }
    }

    private func handle(_ visit: CLVisit) {
        guard isEnabled,
              visit.arrivalDate != .distantPast,
              visit.departureDate == .distantFuture,       // an arrival, not a departure
              CMMotionActivityManager.isActivityAvailable() else { return }

        let arrival = visit.arrivalDate
        let visitLocation = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)

        // Were we driving in the 15 minutes before arriving?
        motion.queryActivityStarting(from: arrival.addingTimeInterval(-15 * 60), to: arrival, to: .main) { [weak self] activities, _ in
            let wasDriving = activities?.contains { $0.automotive && $0.confidence != .low } ?? false
            MainActor.assumeIsolated {
                if wasDriving {
                    self?.markParked(at: visitLocation, date: arrival)
                }
            }
        }
    }

    private func markParked(at parkedLocation: CLLocation?, date: Date = .now, force: Bool = false) {
        stationaryCheck?.cancel()
        stationaryCheck = nil
        isDriving = false
        location.setPreciseBackgroundTracking(false)

        guard let parkedLocation else { return }

        // Ignore repeats of the same stop (e.g. CarPlay disconnect followed by a visit).
        if !force, let currentSession,
           currentSession.location.distance(from: parkedLocation) < 150,
           date.timeIntervalSince(currentSession.parkedAt) < 30 * 60 {
            return
        }

        let session = ParkedSession(location: parkedLocation, parkedAt: date)
        currentSession = session
        pendingPrompt = session
        persist()

        let knownSpot = repository.spot(containing: parkedLocation)
        notifications.sendParkedPrompt(nearSpotName: knownSpot?.name)
    }

    private func persist() {
        if let currentSession, let data = try? JSONEncoder().encode(currentSession) {
            UserDefaults.standard.set(data, forKey: Self.sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        }
    }
}
