//
//  SettingsView.swift
//  ParkFinder
//

import SwiftUI

// Parking detection switch, permission status, the saved car, and data credits.
struct SettingsView: View {
    @Environment(ParkingDetector.self) private var parking
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Detect when I park", isOn: detectionBinding)
                    if parking.isEnabled && !locationManager.hasAlwaysPermission {
                        Button("Allow location “Always” in Settings", systemImage: "exclamationmark.triangle.fill") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .foregroundStyle(Color.gold)
                    }
                } header: {
                    Text("Parking Detection")
                } footer: {
                    Text("ParkFinder notices when a drive ends — CarPlay disconnecting, stepping out of the car, or arriving somewhere — then saves where your car is and asks a few quick questions about the spot.")
                }

                if let session = parking.currentSession {
                    Section("My Car") {
                        LabeledContent("Parked", value: session.parkedAt.formatted(date: .abbreviated, time: .shortened))
                        Button("Rate this spot", systemImage: "star.bubble.fill") {
                            parking.showPrompt(preselecting: nil)
                            dismiss()
                        }
                        Button("I've left — clear my car", systemImage: "xmark.circle", role: .destructive) {
                            parking.clearSession()
                        }
                    }
                }

                Section {
                    Text("Garage and lot data: Green P Parking, City of Toronto. Contains information licensed under the Open Government Licence – Toronto.")
                    Text("Street parking, prices and reviews are shared by ParkFinder drivers.")
                } header: {
                    Text("Data")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var detectionBinding: Binding<Bool> {
        Binding {
            parking.isEnabled
        } set: { isOn in
            if isOn {
                Task { await parking.enable() }
            } else {
                parking.disable()
            }
        }
    }
}
