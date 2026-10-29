//
//  AppDelegate.swift
//  ParkFinder
//

import UIKit
import CarPlay

// SwiftUI can't declare a CarPlay scene, so this delegate routes CarPlay connections
// to CarPlaySceneDelegate. It also creates the shared services at launch, which matters
// when iOS relaunches the app in the background for a location visit.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = AppModel.shared
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = CarPlaySceneDelegate.self
            return configuration
        }
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}
