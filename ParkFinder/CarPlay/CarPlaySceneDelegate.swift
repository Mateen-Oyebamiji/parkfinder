//
//  CarPlaySceneDelegate.swift
//  ParkFinder
//

import UIKit
import CarPlay
import MapKit
import Observation

// The CarPlay interface: a map of nearby parking, a nearest-first list, and favourites.
// Requires the CarPlay Parking entitlement (com.apple.developer.carplay-parking).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPPointOfInterestTemplateDelegate {
    private let app = AppModel.shared
    private var interfaceController: CPInterfaceController?
    private weak var scene: CPTemplateApplicationScene?

    private let mapTemplate = CPPointOfInterestTemplate(title: String(localized: "Parking"), pointsOfInterest: [], selectedIndex: NSNotFound)
    private let nearbyTemplate = CPListTemplate(title: String(localized: "Nearby"), sections: [])
    private let favoritesTemplate = CPListTemplate(title: String(localized: "Favourites"), sections: [])
    private var lastReload = Date.distantPast
    private var isConnected = false

    // MARK: - Connection

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        scene = templateApplicationScene
        isConnected = true

        mapTemplate.pointOfInterestDelegate = self
        mapTemplate.tabImage = UIImage(systemName: "map.fill")
        nearbyTemplate.tabImage = UIImage(systemName: "parkingsign.circle.fill")
        favoritesTemplate.tabImage = UIImage(systemName: "star.fill")
        nearbyTemplate.emptyViewTitleVariants = [String(localized: "Finding parking…")]
        favoritesTemplate.emptyViewTitleVariants = [String(localized: "No favourites yet")]
        favoritesTemplate.emptyViewSubtitleVariants = [String(localized: "Save spots on your iPhone to see them here.")]

        let tabs = CPTabBarTemplate(templates: [mapTemplate, nearbyTemplate, favoritesTemplate])
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)

        app.parking.carPlayDidConnect()
        app.location.requestPermission()
        reloadTemplates()
        observeChanges()
        searchIfNeeded()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        isConnected = false
        self.interfaceController = nil
        // Unplugging CarPlay is the clearest sign the drive is over.
        app.parking.carPlayDidDisconnect()
    }

    // MARK: - Keeping the screens fresh

    private func observeChanges() {
        withObservationTracking {
            _ = app.repository.spots
            _ = app.repository.summaries
            _ = app.favorites.favorites
            _ = app.location.location
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isConnected else { return }
                self.searchIfNeeded()
                // Location ticks constantly while driving, so redraw at most every 10 seconds.
                if Date.now.timeIntervalSince(self.lastReload) > 10 { self.reloadTemplates() }
                self.observeChanges()
            }
        }
    }

    private func searchIfNeeded() {
        guard let here = app.location.location else { return }
        Task { await app.repository.searchIfNeeded(around: here) }
    }

    private func reloadTemplates() {
        lastReload = .now
        let here = app.location.location
        let sorted = here.map { app.repository.spots(sortedFrom: $0) } ?? app.repository.spots

        let pointLimit = 12
        let points = sorted.prefix(pointLimit).map { pointOfInterest(for: $0, from: here) }
        mapTemplate.setPointsOfInterest(Array(points), selectedIndex: NSNotFound)

        let listLimit = min(CPListTemplate.maximumItemCount, 40)
        let nearbyItems = sorted.prefix(listLimit).map { listItem(for: $0, from: here) }
        nearbyTemplate.updateSections([CPListSection(items: Array(nearbyItems))])

        let favoriteItems = app.favorites.favorites.prefix(listLimit).map { listItem(for: $0.spot, from: here) }
        favoritesTemplate.updateSections([CPListSection(items: Array(favoriteItems))])
    }

    // MARK: - Building items

    private func subtitle(for spot: ParkingSpot, from here: CLLocation?) -> String {
        var parts = [spot.kind.shortName]
        if let distance = spot.distanceText(from: here) { parts.append(distance) }
        if let price = app.repository.summaries[spot.id]?.latestPricePerHour {
            parts.append(price.hourlyPriceText)
        } else if let rate = spot.officialRate {
            parts.append(rate)
        }
        return parts.joined(separator: " · ")
    }

    private func listItem(for spot: ParkingSpot, from here: CLLocation?) -> CPListItem {
        let item = CPListItem(text: spot.name,
                              detailText: subtitle(for: spot, from: here),
                              image: Self.goldSymbol(spot.kind.systemImage))
        item.handler = { [weak self] _, completion in
            self?.showDetails(for: spot)
            completion()
        }
        return item
    }

    private func pointOfInterest(for spot: ParkingSpot, from here: CLLocation?) -> CPPointOfInterest {
        let summary = app.repository.summaries[spot.id]
        let rating = summary.map { String(localized: "\($0.averageRating, format: .number.precision(.fractionLength(1)))★ (\($0.reviewCount))") }
        let point = CPPointOfInterest(location: spot.directionsItem,
                                      title: spot.name,
                                      subtitle: subtitle(for: spot, from: here),
                                      summary: rating,
                                      detailTitle: spot.name,
                                      detailSubtitle: spot.kind.displayName,
                                      detailSummary: spot.address,
                                      pinImage: Self.goldSymbol(spot.kind.systemImage))
        point.primaryButton = CPTextButton(title: String(localized: "Directions"), textStyle: .confirm) { [weak self] _ in
            self?.openDirections(to: spot)
        }
        point.secondaryButton = CPTextButton(title: String(localized: "Details"), textStyle: .normal) { [weak self] _ in
            self?.showDetails(for: spot)
        }
        point.userInfo = spot.id
        return point
    }

    private func showDetails(for spot: ParkingSpot) {
        let here = app.location.location
        let summary = app.repository.summaries[spot.id]
        var items = [CPInformationItem(title: String(localized: "Type"), detail: spot.kind.displayName)]
        if let distance = spot.distanceText(from: here) {
            items.append(CPInformationItem(title: String(localized: "Distance"), detail: distance))
        }
        if let rate = spot.officialRate {
            items.append(CPInformationItem(title: String(localized: "Posted rate"), detail: rate))
        }
        if let price = summary?.latestPricePerHour {
            items.append(CPInformationItem(title: String(localized: "Drivers paid"), detail: price.hourlyPriceText))
        }
        if let summary, summary.reviewCount > 0 {
            let average = summary.averageRating.formatted(.number.precision(.fractionLength(1)))
            items.append(CPInformationItem(title: String(localized: "Rating"),
                                           detail: String(localized: "\(average) ★ from \(summary.reviewCount) drivers")))
        }

        let isFavorite = app.favorites.isFavorite(spot)
        let actions = [
            CPTextButton(title: String(localized: "Directions"), textStyle: .confirm) { [weak self] _ in
                self?.openDirections(to: spot)
            },
            CPTextButton(title: isFavorite ? String(localized: "Unsave") : String(localized: "Save"), textStyle: .normal) { [weak self] _ in
                self?.app.favorites.toggle(spot)
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
            }
        ]
        let template = CPInformationTemplate(title: spot.name, layout: .twoColumn, items: items, actions: actions)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func openDirections(to spot: ParkingSpot) {
        var components = URLComponents(string: "maps://")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(spot.coordinate.latitude),\(spot.coordinate.longitude)"),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        guard let url = components?.url else { return }
        scene?.open(url, options: nil, completionHandler: nil)
    }

    private static func goldSymbol(_ name: String) -> UIImage? {
        UIImage(systemName: name)?.withTintColor(UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1),
                                                 renderingMode: .alwaysOriginal)
    }

    // MARK: - CPPointOfInterestTemplateDelegate

    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate,
                                 didChangeMapRegion region: MKCoordinateRegion) {
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        if let last = app.repository.lastSearchCenter, center.distance(from: last) < 1500 { return }
        Task { await app.repository.search(around: region.center) }
    }
}
