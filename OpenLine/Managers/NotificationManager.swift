//
//  NotificationManager.swift
//  OpenLine
//
//  Created by Andrew Shea on 1/27/26.
//
import Foundation
import UIKit
import UserNotifications
import CloudKit
import Combine

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?

    private let container = CKContainer(identifier: "iCloud.com.shea.OpenLine")
    private let userDefaults = UserDefaults.standard
    private let deviceTokenKey = "pushNotificationDeviceToken"

    private init() {
        loadSavedToken()
        checkAuthorizationStatus()
        setupForegroundObserver()
    }

    private func setupForegroundObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    Logger.shared.error("Notification authorization error: \(error.localizedDescription)")
                }

                self?.isAuthorized = granted
                self?.authorizationStatus = granted ? .authorized : .denied

                if granted {
                    self?.registerForRemoteNotifications()
                }

                completion(granted)
            }
        }
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Device Token Management

    private func loadSavedToken() {
        deviceToken = userDefaults.string(forKey: deviceTokenKey)
    }

    func saveDeviceToken(_ token: String) {
        deviceToken = token
        userDefaults.set(token, forKey: deviceTokenKey)

        // Update token in CloudKit via SyncManager
        SyncManager.shared.updateDeviceToken(token)

        Logger.shared.info("Device token saved and synced to CloudKit")
    }

    // MARK: - CloudKit Subscriptions

    func setupCloudKitSubscriptions(for phoneNumber: String) {
        let publicDB = container.publicCloudDatabase

        // Create subscription for incoming friend requests (by phone number)
        createFriendRequestSubscription(database: publicDB, phoneNumber: phoneNumber)

        // Create subscription for friend request responses (when someone responds to our requests)
        createFriendResponseSubscription(database: publicDB, phoneNumber: phoneNumber)

        // Create subscription for availability notifications (when a friend goes green)
        createAvailabilityNotificationSubscription(database: publicDB, phoneNumber: phoneNumber)
    }

    private func createFriendRequestSubscription(database: CKDatabase, phoneNumber: String) {
        let subscriptionID = "incoming-friend-requests-\(phoneNumber)"

        // Check if subscription already exists
        database.fetch(withSubscriptionID: subscriptionID) { existingSubscription, error in
            if existingSubscription != nil {
                Logger.shared.info("Friend request subscription already exists")
                return
            }

            // Create new subscription - use toUserPhone to match our query pattern
            let predicate = NSPredicate(format: "toUserPhone == %@", phoneNumber)
            let subscription = CKQuerySubscription(
                recordType: "FriendRequest",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.titleLocalizationKey = "New Friend Request"
            notificationInfo.alertLocalizationKey = "%1$@ wants to connect with you"
            notificationInfo.alertLocalizationArgs = ["fromUserName"]
            notificationInfo.soundName = "default"
            notificationInfo.shouldBadge = true
            notificationInfo.shouldSendContentAvailable = true

            subscription.notificationInfo = notificationInfo

            database.save(subscription) { savedSubscription, error in
                if let error = error {
                    Logger.shared.error("Failed to create friend request subscription: \(error.localizedDescription)")
                } else {
                    Logger.shared.info("Friend request subscription created successfully")
                }
            }
        }
    }

    private func createFriendResponseSubscription(database: CKDatabase, phoneNumber: String) {
        let subscriptionID = "friend-request-responses-\(phoneNumber)"

        // Check if subscription already exists
        database.fetch(withSubscriptionID: subscriptionID) { existingSubscription, error in
            if existingSubscription != nil {
                Logger.shared.info("Friend response subscription already exists")
                return
            }

            // Create subscription for FriendRequestResponse records where we are the sender
            // This notifies us when someone responds to our friend request
            let predicate = NSPredicate(format: "senderPhone == %@", phoneNumber)
            let subscription = CKQuerySubscription(
                recordType: "FriendRequestResponse",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.title = "Friend Request Response"
            notificationInfo.alertBody = "Someone responded to your friend request"
            notificationInfo.soundName = "default"
            notificationInfo.shouldSendContentAvailable = true

            subscription.notificationInfo = notificationInfo

            database.save(subscription) { savedSubscription, error in
                if let error = error {
                    Logger.shared.error("Failed to create friend response subscription: \(error.localizedDescription)")
                } else {
                    Logger.shared.info("Friend response subscription created successfully")
                }
            }
        }
    }

    private func createAvailabilityNotificationSubscription(database: CKDatabase, phoneNumber: String) {
        let subscriptionID = "availability-notifications-\(phoneNumber)"

        database.fetch(withSubscriptionID: subscriptionID) { existingSubscription, error in
            if existingSubscription != nil {
                Logger.shared.info("Availability notification subscription already exists")
                return
            }

            let predicate = NSPredicate(format: "targetPhone == %@", phoneNumber)
            let subscription = CKQuerySubscription(
                recordType: "AvailabilityNotification",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.alertLocalizationKey = "%1$@ is now available"
            notificationInfo.alertLocalizationArgs = ["fromUserName"]
            notificationInfo.soundName = "default"
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.desiredKeys = ["fromUserName", "fromUserPhone", "statusMessage", "durationText"]

            subscription.notificationInfo = notificationInfo

            database.save(subscription) { savedSubscription, error in
                if let error = error {
                    Logger.shared.error("Failed to create availability notification subscription: \(error.localizedDescription)")
                } else {
                    Logger.shared.info("Availability notification subscription created successfully")
                }
            }
        }
    }

    func removeAllSubscriptions(completion: @escaping (Bool) -> Void) {
        let publicDB = container.publicCloudDatabase

        publicDB.fetchAllSubscriptions { subscriptions, error in
            guard let subscriptions = subscriptions, error == nil else {
                Logger.shared.error("Failed to fetch subscriptions: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }

            let subscriptionIDs = subscriptions.map { $0.subscriptionID }

            guard !subscriptionIDs.isEmpty else {
                completion(true)
                return
            }

            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: nil, subscriptionIDsToDelete: subscriptionIDs)
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    Logger.shared.info("All subscriptions removed successfully")
                    completion(true)
                case .failure(let error):
                    Logger.shared.error("Failed to remove subscriptions: \(error.localizedDescription)")
                    completion(false)
                }
            }

            publicDB.add(operation)
        }
    }

    // MARK: - Local Notifications

    func scheduleLocalNotification(title: String, body: String, identifier: String, delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Failed to schedule local notification: \(error.localizedDescription)")
            }
        }
    }

    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func removePendingNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
