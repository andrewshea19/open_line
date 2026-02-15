//
//  OpenLineApp.swift
//  OpenLine
//
//  Created by Andrew Shea on 6/16/25.
//

import SwiftUI
import Combine

@main
struct OpenLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var syncManager = SyncManager.shared
    @State private var subscriptionsSetUp = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(syncManager.$currentUserProfile) { profile in
                    setupCloudKitSubscriptionsIfNeeded(for: profile)
                }
        }
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
