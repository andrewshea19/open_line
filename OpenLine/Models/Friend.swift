//
//  Friend.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

struct Friend: Identifiable, Codable {
    var id = UUID()
    var name: String
    var phoneNumber: String
    var email: String?
    var relationshipStatus: RelationshipStatus = .friends
    var canSeeMyStatus: Bool = true
    var lastSyncDate: Date?
    
    // CloudKit-ready: These will be fetched from friend's record
    var friendRecordID: String? // CloudKit user record ID
    var currentStatus: String?
    var statusMessage: String?
    var availableUntil: Date?
    var lastStatusUpdate: Date?
    
    init(name: String, phoneNumber: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.lastSyncDate = Date()
    }
    
    // Computed property for display
    var displayStatus: String {
        return currentStatus ?? "No Status"
    }
}

enum RelationshipStatus: String, CaseIterable, Codable {
    case friends = "Friends"
    case blocked = "Blocked"
    case pending = "Pending"
}

