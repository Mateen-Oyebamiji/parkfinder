//
//  ParkFinderApp.swift
//  ParkFinder
//
//  Created by Mateen Oyebamiji on 2026-10-20.
//

import SwiftUI

@main
struct ParkFinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let app = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app.location)
                .environment(app.repository)
                .environment(app.favorites)
                .environment(app.parking)
                .tint(.gold)
                .preferredColorScheme(.dark)
        }
    }
}
