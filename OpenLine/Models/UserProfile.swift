//
//  UserProfile.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

struct UserProfile: Identifiable, Codable {
    var id = UUID()
    var cloudKitUserID: String? // CloudKit user record ID - stable identifier
    var name: String
    var phoneNumber: String // Primary identifier for friend lookups
    var email: String?
    var currentStatus: String
    var statusMessage: String
    var statusUntil: Date?
    var lastStatusUpdate: Date?
    var isDiscoverable: Bool = true
    var deviceTokens: [String] = [] // For push notifications
    
    init(name: String, phoneNumber: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.currentStatus = "No Status"
        self.statusMessage = ""
        self.lastStatusUpdate = Date()
    }
    
    // CloudKit-ready unique identifier
    var uniqueIdentifier: String {
        return cloudKitUserID ?? phoneNumber
    }
}
