//
//  SharedDefaults.swift
//  OpenLine
//
//  Created by Andrew Shea on 2/17/26.
//
import Foundation

/// Lightweight friend data for widget display
struct WidgetFriend: Codable, Identifiable {
    let id: String
    let name: String
    let phoneNumber: String
    let status: String
    let statusMessage: String
    let availableUntil: Date?

    var isAvailable: Bool {
        guard let until = availableUntil, until > Date() else { return false }
        return status == "Available"
    }

    var initials: String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
}

/// Shared data storage using App Groups for widget communication
final class SharedDefaults {
    static let shared = SharedDefaults()

    private let suiteName = "group.com.shea.OpenLine"
    private let userDefaults: UserDefaults?

    private enum Keys {
        static let currentStatus = "widget_currentStatus"
        static let statusMessage = "widget_statusMessage"
        static let statusUntil = "widget_statusUntil"
        static let userPhone = "widget_userPhone"
        static let userName = "widget_userName"
        static let defaultDuration = "widget_defaultDuration"
        static let availableFriends = "widget_availableFriends"
    }

    init() {
        self.userDefaults = UserDefaults(suiteName: suiteName)
    }

    // MARK: - Status Data

    var currentStatus: String {
        get { userDefaults?.string(forKey: Keys.currentStatus) ?? "No Status" }
        set { userDefaults?.set(newValue, forKey: Keys.currentStatus) }
    }

    var statusMessage: String {
        get { userDefaults?.string(forKey: Keys.statusMessage) ?? "" }
        set { userDefaults?.set(newValue, forKey: Keys.statusMessage) }
    }

    var statusUntil: Date? {
        get { userDefaults?.object(forKey: Keys.statusUntil) as? Date }
        set { userDefaults?.set(newValue, forKey: Keys.statusUntil) }
    }

    var userPhone: String {
        get { userDefaults?.string(forKey: Keys.userPhone) ?? "" }
        set { userDefaults?.set(newValue, forKey: Keys.userPhone) }
    }

    var userName: String {
        get { userDefaults?.string(forKey: Keys.userName) ?? "" }
        set { userDefaults?.set(newValue, forKey: Keys.userName) }
    }

    var defaultDuration: Int {
        get { userDefaults?.integer(forKey: Keys.defaultDuration) ?? 60 }
        set { userDefaults?.set(newValue, forKey: Keys.defaultDuration) }
    }

    // MARK: - Friends Data

    var availableFriends: [WidgetFriend] {
        get {
            guard let data = userDefaults?.data(forKey: Keys.availableFriends),
                  let friends = try? JSONDecoder().decode([WidgetFriend].self, from: data) else {
                return []
            }
            return friends
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults?.set(data, forKey: Keys.availableFriends)
            }
        }
    }

    // MARK: - Convenience

    var isAvailable: Bool {
        currentStatus == "Available"
    }

    func syncFromApp(status: String, message: String, until: Date?, phone: String, name: String, duration: Int, friends: [WidgetFriend]) {
        currentStatus = status
        statusMessage = message
        statusUntil = until
        userPhone = phone
        userName = name
        defaultDuration = duration
        availableFriends = friends
    }
}
