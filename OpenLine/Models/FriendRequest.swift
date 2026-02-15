//
//  FriendRequest.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

struct FriendRequest: Identifiable, Codable {
    var id = UUID()
    var requestType: RequestType
    var fromUserID: String // CloudKit record ID or phone number
    var fromUserName: String
    var fromUserPhone: String
    var fromUserEmail: String?
    var toUserID: String // CloudKit record ID or phone number
    var toUserName: String?
    var toUserPhone: String?
    var toUserEmail: String?
    var message: String?
    var status: FriendRequestStatus
    var createdAt: Date
    var respondedAt: Date?
    var cloudKitRecordID: String?
    
    enum RequestType: String, Codable {
        case incoming
        case outgoing
    }
    
    // Incoming request initializer
    static func incoming(fromUserID: String, fromUserName: String, fromUserPhone: String,
                        fromUserEmail: String? = nil, message: String? = nil) -> FriendRequest {
        return FriendRequest(
            id: UUID(),
            requestType: .incoming,
            fromUserID: fromUserID,
            fromUserName: fromUserName,
            fromUserPhone: fromUserPhone,
            fromUserEmail: fromUserEmail,
            toUserID: "", // Will be filled with current user ID
            toUserName: nil,
            toUserPhone: nil,
            toUserEmail: nil,
            message: message,
            status: .pending,
            createdAt: Date(),
            respondedAt: nil,
            cloudKitRecordID: nil
        )
    }
    
    // Outgoing request initializer
    static func outgoing(toUserID: String, toUserName: String, toUserPhone: String,
                        toUserEmail: String? = nil, fromUserID: String, fromUserName: String,
                        fromUserPhone: String, fromUserEmail: String? = nil,
                        message: String? = nil) -> FriendRequest {
        return FriendRequest(
            id: UUID(),
            requestType: .outgoing,
            fromUserID: fromUserID,
            fromUserName: fromUserName,
            fromUserPhone: fromUserPhone,
            fromUserEmail: fromUserEmail,
            toUserID: toUserID,
            toUserName: toUserName,
            toUserPhone: toUserPhone,
            toUserEmail: toUserEmail,
            message: message,
            status: .pending,
            createdAt: Date(),
            respondedAt: nil,
            cloudKitRecordID: nil
        )
    }
}

enum FriendRequestStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
    case expired = "Expired"
}
