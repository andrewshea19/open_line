//
//  AppDelegate.swift
//  OpenLine
//
//  Created by Andrew Shea on 1/27/26.
//
import UIKit
import UserNotifications
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        registerForPushNotifications()

        return true
    }

    // MARK: - Push Notification Registration

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.shared.error("Push notification authorization error: \(error.localizedDescription)")
                return
            }

            Logger.shared.info("Push notification authorization granted: \(granted)")

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - Remote Notification Callbacks

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Logger.shared.info("Device token received: \(tokenString)")

        // Save device token via NotificationManager
        NotificationManager.shared.saveDeviceToken(tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Handle Remote Notifications

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if this is a CloudKit notification
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            handleCloudKitNotification(notification)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }

    private func handleCloudKitNotification(_ notification: CKNotification) {
        guard let subscriptionID = notification.subscriptionID else { return }

        Logger.shared.info("Received CloudKit notification for subscription: \(subscriptionID)")

        // Post notification for the app to refresh data
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil, userInfo: ["subscriptionID": subscriptionID])
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle user interaction with notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Handle the notification action
        Logger.shared.info("User tapped notification: \(response.notification.request.identifier)")

        // Post notification for the app to handle
        NotificationCenter.default.post(name: .notificationTapped, object: nil, userInfo: userInfo)

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
    static let notificationTapped = Notification.Name("notificationTapped")
}
