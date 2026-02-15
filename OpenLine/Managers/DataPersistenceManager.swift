//
//  DataPersistenceManager.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

final class DataPersistenceManager {
    static let shared = DataPersistenceManager()
    
    private let userDefaults = UserDefaults.standard
    private let documentsDirectory: URL
    
    // UserDefaults keys for preferences only
    private let defaultStatusDurationKey = "defaultStatusDuration"
    private let respectsDoNotDisturbKey = "respectsDoNotDisturb"
    private let globalStatusVisibilityKey = "globalStatusVisibility"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private let lastUsedDurationsKey = "lastUsedDurations"
    
    // File names for data storage
    private let friendsFileName = "friends.json"
    private let schedulesFileName = "schedules.json"
    private let pendingRequestsFileName = "pendingRequests.json"
    private let sentRequestsFileName = "sentRequests.json"
    
    init() {
        documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
    }
    
    // MARK: - Preferences (UserDefaults)
    
    var defaultStatusDuration: Int {
        get { userDefaults.integer(forKey: defaultStatusDurationKey) == 0 ? 120 : userDefaults.integer(forKey: defaultStatusDurationKey) }
        set { userDefaults.set(newValue, forKey: defaultStatusDurationKey) }
    }
    
    var respectsDoNotDisturb: Bool {
        get { userDefaults.object(forKey: respectsDoNotDisturbKey) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: respectsDoNotDisturbKey) }
    }
    
    var globalStatusVisibility: Bool {
        get { userDefaults.object(forKey: globalStatusVisibilityKey) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: globalStatusVisibilityKey) }
    }
    
    var isFirstLaunch: Bool {
        get { userDefaults.object(forKey: hasLaunchedBeforeKey) == nil }
        set { userDefaults.set(!newValue, forKey: hasLaunchedBeforeKey) }
    }
    
    var lastUsedDurations: [String: Int] {
        get {
            if let data = userDefaults.data(forKey: lastUsedDurationsKey),
               let durations = try? JSONDecoder().decode([String: Int].self, from: data) {
                return durations
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: lastUsedDurationsKey)
            }
        }
    }
    
    // MARK: - Data Storage (Documents Directory)
    
    func saveFriends(_ friends: [Friend]) throws {
        let url = documentsDirectory.appendingPathComponent(friendsFileName)
        let data = try JSONEncoder().encode(friends)
        try data.write(to: url)
    }
    
    func loadFriends() throws -> [Friend] {
        let url = documentsDirectory.appendingPathComponent(friendsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Friend].self, from: data)
    }
    
    func saveSchedules(_ schedules: [Schedule]) throws {
        let url = documentsDirectory.appendingPathComponent(schedulesFileName)
        let data = try JSONEncoder().encode(schedules)
        try data.write(to: url)
    }
    
    func loadSchedules() throws -> [Schedule] {
        let url = documentsDirectory.appendingPathComponent(schedulesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Schedule].self, from: data)
    }
    
    func savePendingRequests(_ requests: [FriendRequest]) throws {
        let url = documentsDirectory.appendingPathComponent(pendingRequestsFileName)
        let data = try JSONEncoder().encode(requests)
        try data.write(to: url)
    }
    
    func loadPendingRequests() throws -> [FriendRequest] {
        let url = documentsDirectory.appendingPathComponent(pendingRequestsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([FriendRequest].self, from: data)
    }
    
    func saveSentRequests(_ requests: [FriendRequest]) throws {
        let url = documentsDirectory.appendingPathComponent(sentRequestsFileName)
        let data = try JSONEncoder().encode(requests)
        try data.write(to: url)
    }
    
    func loadSentRequests() throws -> [FriendRequest] {
        let url = documentsDirectory.appendingPathComponent(sentRequestsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([FriendRequest].self, from: data)
    }
    
    // MARK: - Cache Management
    
    func clearAllData() throws {
        let fileNames = [friendsFileName, schedulesFileName, pendingRequestsFileName, sentRequestsFileName]
        for fileName in fileNames {
            let url = documentsDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func getCacheSize() -> Int64 {
        let fileNames = [friendsFileName, schedulesFileName, pendingRequestsFileName, sentRequestsFileName]
        var totalSize: Int64 = 0
        
        for fileName in fileNames {
            let url = documentsDirectory.appendingPathComponent(fileName)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
}
