//
//  ContentView.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-20.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(ParkingRepository.self) private var repository
    @Environment(FavoritesStore.self) private var favorites
    @Environment(ParkingDetector.self) private var parking

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleCenter: CLLocationCoordinate2D?
    @State private var selectedSpot: ParkingSpot?    // the pin the user tapped (if any)
    @State private var filter: MapFilter = .all
    @State private var activeSheet: ActiveSheet?
    @AppStorage("hasDismissedDetectionOffer") private var hasDismissedDetectionOffer = false

    var body: some View {
        Map(position: $camera, selection: $selectedSpot) {
            UserAnnotation()

            // One gold pin per parking spot
            ForEach(visibleSpots) { spot in
                Annotation(spot.name, coordinate: spot.coordinate) {
                    SpotPin(kind: spot.kind,
                            isFavorite: favorites.isFavorite(spot),
                            isSelected: selectedSpot == spot)
                }
                .annotationTitles(.hidden)
                .tag(spot)
            }

            if let session = parking.currentSession {
                Annotation("My Car", coordinate: session.coordinate) {
                    Image(systemName: "car.fill")
                        .font(.headline)
                        .foregroundStyle(Color.gold)
                        .frame(width: 38, height: 38)
                        .background(Color.ink, in: .circle)
                        .overlay(Circle().stroke(.goldGradient, lineWidth: 3))
                }
            }
        }
        // A dark, muted map with Apple's own icons hidden so the gold pins stand out.
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        // Remember where the middle of the map is whenever the user stops dragging
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleCenter = context.region.center
        }
        // Search when we first get a location, and again after moving more than 1 km.
        .onChange(of: locationManager.location) { _, newLocation in
            guard let newLocation else { return }
            Task { await repository.searchIfNeeded(around: newLocation) }
        }
        .onChange(of: locationManager.authorizationStatus) {
            parking.permissionsChanged()
        }
        .safeAreaInset(edge: .top) {
            topBar
        }
        .safeAreaInset(edge: .bottom) {
            bottomPanel
        }
        .onAppear {
            locationManager.requestPermission()
        }
        // Tapping a pin opens its details.
        .onChange(of: selectedSpot) { _, spot in
            if let spot { activeSheet = .spot(spot) }
        }
        // Parking detection asks its questions as soon as a park is noticed.
        .onChange(of: parking.pendingPrompt) { _, session in
            if let session { activeSheet = .report(session, .parked) }
        }
        .task {
            if let session = parking.pendingPrompt { activeSheet = .report(session, .parked) }
        }
        .sheet(item: $activeSheet, onDismiss: { selectedSpot = nil }) { sheet in
            sheetContent(for: sheet)
                .presentationBackground(Color.ink)
        }
    }

    // MARK: - Data

    private var visibleSpots: [ParkingSpot] {
        guard let kinds = filter.kinds else { return repository.spots }
        return repository.spots.filter { kinds.contains($0.kind) }
    }

    private var nearestSpot: ParkingSpot? {
        guard let here = locationManager.location else { return visibleSpots.first }
        return repository.nearest(to: here, kinds: filter.kinds)
    }

    /// Show "Search this area" once the map has been dragged well away from the last search.
    private var shouldOfferAreaSearch: Bool {
        guard let visibleCenter, !repository.isSearching else { return false }
        guard let last = repository.lastSearchCenter else { return true }
        let center = CLLocation(latitude: visibleCenter.latitude, longitude: visibleCenter.longitude)
        return center.distance(from: last) > 600
    }

    // MARK: - Overlays

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PARKFINDER")
                    .font(.title3.weight(.black))
                    .tracking(3)
                    .foregroundStyle(.goldGradient)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Settings", systemImage: "gearshape.fill") {
                    activeSheet = .settings
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.gold)
                .frame(width: 44, height: 44)
                .glassPanel(in: .circle)
            }
            .padding(.horizontal)

            FilterBar(selection: $filter)

            if shouldOfferAreaSearch, let visibleCenter {
                Button("Search this area", systemImage: "magnifyingglass") {
                    Task { await repository.search(around: visibleCenter) }
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.goldGradient, in: .capsule)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 4)
        .animation(.snappy, value: shouldOfferAreaSearch)
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if !parking.isEnabled && !hasDismissedDetectionOffer {
                detectionOffer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let nearestSpot {
                NearestSpotCard(spot: nearestSpot,
                                summary: repository.summaries[nearestSpot.id],
                                userLocation: locationManager.location) {
                    activeSheet = .spot(nearestSpot)
                }
            } else {
                statusText
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassPanel()
            }

            actionBar
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// One-time invitation to turn on automatic parking detection.
    private var detectionOffer: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.badge.gearshape.fill")
                .font(.title2)
                .foregroundStyle(Color.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Remember where I park")
                    .font(.subheadline.bold())
                Text("Saves your car and asks about the spot when your drive ends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Turn On") {
                Task { await parking.enable() }
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.goldGradient, in: .capsule)
            Button("Dismiss", systemImage: "xmark") {
                withAnimation { hasDismissedDetectionOffer = true }
            }
            .labelStyle(.iconOnly)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassPanel(in: .rect(cornerRadius: 20), tinted: true)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("Favourites", systemImage: "star.fill") {
                activeSheet = .favorites
            }

            actionButton("I Parked", systemImage: "car.side.fill", prominent: true) {
                parking.parkHereNow()
            }

            actionButton("Add Spot", systemImage: "plus.circle.fill") {
                let coordinate = visibleCenter ?? locationManager.location?.coordinate
                if let coordinate {
                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    activeSheet = .report(ParkedSession(location: location), .addSpot)
                }
            }

            if let session = parking.currentSession {
                actionButton("My Car", systemImage: "location.north.circle.fill") {
                    withAnimation {
                        camera = .region(MKCoordinateRegion(center: session.coordinate,
                                                            latitudinalMeters: 400,
                                                            longitudinalMeters: 400))
                    }
                }
            }
        }
    }

    private func actionButton(_ title: LocalizedStringKey, systemImage: String,
                              prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(prominent ? Color.ink : Color.gold)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: 18).fill(.goldGradient)
                }
            }
            .glassPanel(in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusText: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            Text("Waiting for location permission…")
        case .denied, .restricted:
            Text("Location is off. Turn it on in Settings → Privacy → Location Services.")
        default:
            if let errorMessage = repository.errorMessage {
                Text(errorMessage)
            } else if repository.isSearching {
                Label("Searching for parking…", systemImage: "magnifyingglass")
            } else if locationManager.location == nil && locationManager.hasNoSignal {
                #if targetEnvironment(simulator)
                Text("The Simulator has no location. Choose Features → Location → Custom Location, or drag the map and tap Search this area.")
                #else
                Text("No GPS signal yet. Drag the map and tap Search this area to look somewhere specific.")
                #endif
            } else if locationManager.location == nil {
                Text("Waiting for GPS…")
            } else if filter != .all && !repository.spots.isEmpty {
                Text("No \(filter.title.lowercased()) parking found here. Try another filter or add a spot.")
            } else {
                Text("No parking found nearby. Add a spot to help other drivers.")
            }
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .spot(let spot):
            SpotDetailView(spot: repository.spot(withID: spot.id) ?? spot,
                           userLocation: locationManager.location)
                .presentationDetents([.fraction(0.45), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
        case .favorites:
            FavoritesView { spot in
                activeSheet = .spot(spot)
                withAnimation {
                    camera = .region(MKCoordinateRegion(center: spot.coordinate,
                                                        latitudinalMeters: 800,
                                                        longitudinalMeters: 800))
                }
            }
            .presentationDetents([.medium, .large])
        case .report(let session, let mode):
            SpotReportView(session: session, mode: mode)
                .presentationDetents([.large])
                .interactiveDismissDisabled(mode == .parked)
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    let app = AppModel.shared
    ContentView()
        .environment(app.location)
        .environment(app.repository)
        .environment(app.favorites)
        .environment(app.parking)
        .preferredColorScheme(.dark)
}
