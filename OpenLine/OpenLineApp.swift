//
//  OpenLineApp.swift
//  OpenLine
//
//  Created by Andrew Shea on 6/16/25.
//

import SwiftUI
import Combine

// MARK: - UIFont Extension for Rounded Design
extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

@main
struct OpenLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var syncManager = SyncManager.shared
    @State private var subscriptionsSetUp = false

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(syncManager.$currentUserProfile) { profile in
                    setupCloudKitSubscriptionsIfNeeded(for: profile)
                }
        }
    }

    private func configureAppearance() {
        // Navigation Bar - Rounded font for friendly, professional look
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()

        // Large title - rounded
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold, width: .standard).rounded()
        ]

        // Inline title - rounded
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold, width: .standard).rounded()
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Tab Bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func setupCloudKitSubscriptionsIfNeeded(for profile: UserProfile?) {
        guard !subscriptionsSetUp,
              let phoneNumber = profile?.phoneNumber,
              !phoneNumber.isEmpty else { return }
        subscriptionsSetUp = true
        NotificationManager.shared.setupCloudKitSubscriptions(for: phoneNumber)
        Logger.shared.info("CloudKit subscriptions set up for phone: \(phoneNumber)")
    }
}
