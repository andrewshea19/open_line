//
//  CloudKitManager.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/9/25.
//
import Foundation
import CloudKit

protocol CloudKitServiceProtocol {
    func fetchOrCreateCurrentUserProfile(localProfile: UserProfile?, completion: @escaping (Result<UserProfile, AppError>) -> Void)
    func upsertUserProfile(_ profile: UserProfile, completion: @escaping (Result<UserProfile, AppError>) -> Void)
    func searchUsersByPhone(_ phone: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void)
    func searchUsersByEmail(_ email: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void)
    func createFriendRequest(from currentUser: UserProfile, to remoteUser: UserProfile, message: String?, completion: @escaping (Result<Bool, AppError>) -> Void)
    func fetchIncomingFriendRequests(forPhone phoneNumber: String, completion: @escaping (Result<[FriendRequest], AppError>) -> Void)
    func fetchOutgoingFriendRequests(forPhone phoneNumber: String, completion: @escaping (Result<[FriendRequest], AppError>) -> Void)
    func respondToFriendRequest(recordID: String, accept: Bool, responderPhone: String, senderPhone: String, completion: @escaping (Result<Bool, AppError>) -> Void)
    func deleteFriendRequest(recordID: String, completion: @escaping (Result<Bool, AppError>) -> Void)
    func fetchFriendProfiles(friendUniqueIDs: [String], completion: @escaping (Result<[UserProfile], AppError>) -> Void)
}

final class CloudKitManager: CloudKitServiceProtocol {
    // MARK: - Constants
    private enum RecordType {
        static let userProfile = "UserProfile"
        static let friendRequest = "FriendRequest"
        static let friendRequestResponse = "FriendRequestResponse"
    }

    private enum UserKeys {
        static let cloudKitUserID = "cloudKitUserID"
        static let name = "name"
        static let phoneNumber = "phoneNumber"
        static let email = "email"
        static let currentStatus = "currentStatus"
        static let statusMessage = "statusMessage"
        static let statusUntil = "statusUntil"
        static let lastStatusUpdate = "lastStatusUpdate"
        static let isDiscoverable = "isDiscoverable"
        static let deviceTokens = "deviceTokens"
    }

    private enum RequestKeys {
        static let fromUserID = "fromUserID"
        static let fromUserName = "fromUserName"
        static let fromUserPhone = "fromUserPhone"
        static let fromUserEmail = "fromUserEmail"
        static let toUserID = "toUserID"
        static let toUserName = "toUserName"
        static let toUserPhone = "toUserPhone"
        static let toUserEmail = "toUserEmail"
        static let message = "message"
        static let status = "status"
        static let createdAt = "createdAt"
        static let respondedAt = "respondedAt"
    }

    // Keys for FriendRequestResponse - a separate record the recipient creates
    private enum ResponseKeys {
        static let originalRequestID = "originalRequestID"  // The FriendRequest this responds to
        static let responderPhone = "responderPhone"        // Phone of who is responding
        static let senderPhone = "senderPhone"              // Original sender's phone (for their queries)
        static let accepted = "accepted"                    // true = accepted, false = declined
        static let respondedAt = "respondedAt"
    }

    // MARK: - Properties
    private let container: CKContainer
    private let publicDB: CKDatabase
    private let containerIdentifier: String

    init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDB = container.publicCloudDatabase
    }

    // MARK: - Helpers
    private func mapCKError(_ error: Error) -> AppError {
        let ckError = error as NSError
        let code = CKError.Code(rawValue: ckError.code) ?? .unknownItem
        let errorDescription = error.localizedDescription
        
        switch code {
        case .networkUnavailable, .networkFailure:
            return .networkError("Network unavailable")
        case .notAuthenticated:
            return .authenticationError("iCloud not authenticated. Please sign in to iCloud in Settings.")
        case .permissionFailure:
            if errorDescription.contains("WRITE") {
                return .dataError("Cannot modify this record. This is a CloudKit security constraint.")
            }
            return .dataError("Permission denied for this operation.")
        case .unknownItem:
            // Schema not created yet - this is expected on first run in Development
            return .dataError("CloudKit schema not initialized. Please ensure container is set up in CloudKit Dashboard.")
        case .invalidArguments:
            // This includes "Type is not marked indexable" errors
            if errorDescription.contains("indexable") || errorDescription.contains("Queryable") {
                return .dataError("CloudKit schema configuration issue: The queried fields need to be marked as 'Queryable' in CloudKit Dashboard. For UserProfile, mark 'cloudKitUserID', 'phoneNumber', and 'email' as Queryable. See CloudKitSetup.md for details.")
            }
            return .dataError("CloudKit configuration error: \(errorDescription)")
        case .serverRecordChanged:
            // Oplock error - record was modified on server. This is usually non-fatal and can be retried.
            return .dataError("Data was updated on another device. This should resolve automatically.")
        case .partialFailure:
            // Some operations succeeded, some failed - check individual results
            return .dataError("Some operations failed. Please try again.")
        case .quotaExceeded:
            return .dataError("iCloud storage quota exceeded")
        case .serviceUnavailable:
            return .networkError("CloudKit service temporarily unavailable")
        default: 
            // Check for specific errors in description
            if errorDescription.contains("oplock") {
                return .dataError("Record conflict detected. Please try again - this usually resolves automatically.")
            }
            if errorDescription.contains("indexable") || errorDescription.contains("Queryable") {
                return .dataError("CloudKit schema error: Fields used in queries must be marked as 'Queryable' in CloudKit Dashboard. Please check CloudKitSetup.md for setup instructions.")
            }
            return .dataError("CloudKit error: \(errorDescription)")
        }
    }

    private func userProfile(from record: CKRecord) -> UserProfile {
        var profile = UserProfile(
            name: record[UserKeys.name] as? String ?? "",
            phoneNumber: record[UserKeys.phoneNumber] as? String ?? "",
            email: record[UserKeys.email] as? String
        )
        profile.cloudKitUserID = record[UserKeys.cloudKitUserID] as? String
        profile.currentStatus = record[UserKeys.currentStatus] as? String ?? "No Status"
        profile.statusMessage = record[UserKeys.statusMessage] as? String ?? ""
        profile.statusUntil = record[UserKeys.statusUntil] as? Date
        profile.lastStatusUpdate = record[UserKeys.lastStatusUpdate] as? Date
        if let discoverable = record[UserKeys.isDiscoverable] as? NSNumber {
            profile.isDiscoverable = discoverable.boolValue
        }
        if let tokens = record[UserKeys.deviceTokens] as? [String] {
            profile.deviceTokens = tokens
        }
        return profile
    }

    private func applyUserProfile(_ profile: UserProfile, to record: CKRecord) {
        record[UserKeys.cloudKitUserID] = profile.cloudKitUserID as CKRecordValue?
        record[UserKeys.name] = profile.name as CKRecordValue
        record[UserKeys.phoneNumber] = profile.phoneNumber as CKRecordValue
        if let email = profile.email { record[UserKeys.email] = email as CKRecordValue }
        record[UserKeys.currentStatus] = profile.currentStatus as CKRecordValue
        record[UserKeys.statusMessage] = profile.statusMessage as CKRecordValue
        if let until = profile.statusUntil { record[UserKeys.statusUntil] = until as CKRecordValue }
        if let updated = profile.lastStatusUpdate { record[UserKeys.lastStatusUpdate] = updated as CKRecordValue }
        record[UserKeys.isDiscoverable] = NSNumber(booleanLiteral: profile.isDiscoverable)
        if !profile.deviceTokens.isEmpty { record[UserKeys.deviceTokens] = profile.deviceTokens as CKRecordValue }
    }

    private func requestCurrentUserRecordID(completion: @escaping (Result<String, AppError>) -> Void) {
        container.accountStatus { status, error in
            // Check iCloud account status - be lenient for simulator compatibility
            switch status {
            case .available, .couldNotDetermine:
                // Continue to fetch user record ID
                // Note: couldNotDetermine is common on simulators even when signed in
                break
            case .noAccount:
                completion(.failure(.authenticationError("No iCloud account. Please sign in to iCloud in Settings.")))
                return
            case .restricted:
                completion(.failure(.authenticationError("iCloud account is restricted")))
                return
            case .temporarilyUnavailable:
                completion(.failure(.networkError("iCloud temporarily unavailable")))
                return
            @unknown default:
                break
            }

            // Fetch the actual user record ID
            self.container.fetchUserRecordID { recordID, error in
                if let error = error {
                    completion(.failure(self.mapCKError(error)))
                    return
                }
                guard let recordID = recordID else {
                    completion(.failure(.dataError("No iCloud user record ID")))
                    return
                }
                completion(.success(recordID.recordName))
            }
        }
    }

    // MARK: - CloudKitServiceProtocol
    func fetchOrCreateCurrentUserProfile(localProfile: UserProfile?, completion: @escaping (Result<UserProfile, AppError>) -> Void) {
        requestCurrentUserRecordID { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let userRecordName):
                // Try to query first
                let predicate = NSPredicate(format: "%K == %@", UserKeys.cloudKitUserID, userRecordName)
                let query = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
                self.publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { queryResult in
                    switch queryResult {
                    case .failure(let error):
                        let errorDesc = error.localizedDescription
                        // If schema isn't ready (indexable error), try creating the record first
                        // This will auto-create the schema in Development mode
                        if errorDesc.contains("indexable") || errorDesc.contains("Queryable") {
                            // Schema not ready - create record first to initialize schema
                            if let localProfile = localProfile {
                                var profile = localProfile
                                profile.cloudKitUserID = userRecordName
                                self.upsertUserProfile(profile) { upsertResult in
                                    // On successful create, try querying again
                                    switch upsertResult {
                                    case .success(let created):
                                        completion(.success(created))
                                    case .failure:
                                        // If upsert also fails, provide helpful error
                                        completion(.failure(.dataError("CloudKit schema needs configuration. Please go to CloudKit Dashboard and mark 'cloudKitUserID', 'phoneNumber', and 'email' as Queryable for UserProfile record type. See Docs/CloudKitSetup.md")))
                                    }
                                }
                            } else {
                                completion(.failure(.dataError("CloudKit schema needs configuration. Please mark queried fields as 'Queryable' in CloudKit Dashboard. See Docs/CloudKitSetup.md")))
                            }
                            return
                        }
                        completion(.failure(self.mapCKError(error)))
                        return
                    case .success(let (matchResults, _)):
                        let records = matchResults.compactMap { try? $0.1.get() }
                        if let record = records.first {
                            completion(.success(self.userProfile(from: record)))
                        } else {
                            // Create using local profile seed if available
                            let record = CKRecord(recordType: RecordType.userProfile)
                            var seed = localProfile ?? UserProfile(name: "", phoneNumber: "")
                            seed.cloudKitUserID = userRecordName
                            self.applyUserProfile(seed, to: record)
                            self.publicDB.save(record) { saved, saveError in
                                if let saveError = saveError {
                                    let nsError = saveError as NSError
                                    let ckCode = CKError.Code(rawValue: nsError.code) ?? .unknownItem
                                    // For oplock errors during initial create, use local profile and continue
                                    if ckCode == .serverRecordChanged || saveError.localizedDescription.contains("oplock") {
                                        // Record conflict - use local profile, sync will retry later
                                        if let localProfile = localProfile {
                                            completion(.success(localProfile))
                                            return
                                        }
                                    }
                                    completion(.failure(self.mapCKError(saveError)))
                                    return
                                }
                                guard let saved = saved else { completion(.failure(.dataError("Failed to save profile"))); return }
                                completion(.success(self.userProfile(from: saved)))
                            }
                        }
                    }
                }
            }
        }
    }

    func upsertUserProfile(_ profile: UserProfile, completion: @escaping (Result<UserProfile, AppError>) -> Void) {
        // Upsert by cloudKitUserID if present, else by phone
        let predicate: NSPredicate
        if let cloudID = profile.cloudKitUserID {
            predicate = NSPredicate(format: "%K == %@", UserKeys.cloudKitUserID, cloudID)
        } else {
            predicate = NSPredicate(format: "%K == %@", UserKeys.phoneNumber, profile.phoneNumber)
        }
        let query = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { queryResult in
            switch queryResult {
            case .failure(let error):
                completion(.failure(self.mapCKError(error)))
                return
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                let record = records.first ?? CKRecord(recordType: RecordType.userProfile)
                self.applyUserProfile(profile, to: record)
                self.publicDB.save(record) { saved, saveError in
                    if let saveError = saveError {
                        let nsError = saveError as NSError
                        let ckCode = CKError.Code(rawValue: nsError.code) ?? .unknownItem
                        // For oplock errors, try to fetch latest and retry once, or use provided profile
                        if ckCode == .serverRecordChanged || saveError.localizedDescription.contains("oplock") {
                            // Fetch latest record and merge our changes
                            if let recordID = saved?.recordID ?? (records.first?.recordID) {
                                self.publicDB.fetch(withRecordID: recordID) { fetched, fetchError in
                                    if let fetched = fetched {
                                        // Apply our changes to the latest record
                                        self.applyUserProfile(profile, to: fetched)
                                        self.publicDB.save(fetched) { retried, retryError in
                                            if retryError != nil {
                                                // If retry fails, just return the provided profile - oplock errors are often transient
                                                completion(.success(profile))
                                            } else if let retried = retried {
                                                completion(.success(self.userProfile(from: retried)))
                                            } else {
                                                completion(.success(profile))
                                            }
                                        }
                                    } else {
                                        // Can't fetch, use provided profile
                                        completion(.success(profile))
                                    }
                                }
                                return
                            } else {
                                // No record ID, just use provided profile
                                completion(.success(profile))
                                return
                            }
                        }
                        completion(.failure(self.mapCKError(saveError)))
                        return
                    }
                    guard let saved = saved else { completion(.failure(.dataError("Failed to save profile"))); return }
                    completion(.success(self.userProfile(from: saved)))
                }
            }
        }
    }

    func searchUsersByPhone(_ phone: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void) {
        // Normalize phone number for search (remove all non-digits)
        let normalizedPhone = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !normalizedPhone.isEmpty else {
            completion(.success(nil))
            return
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == 1", UserKeys.phoneNumber, normalizedPhone, UserKeys.isDiscoverable)
        let query = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { queryResult in
            switch queryResult {
            case .failure(let error):
                // If schema doesn't exist or field not queryable, return nil instead of error
                let errorDesc = error.localizedDescription
                if errorDesc.contains("Unknown field") || errorDesc.contains("indexable") || errorDesc.contains("Queryable") {
                    completion(.success(nil))
                    return
                }
                completion(.failure(self.mapCKError(error)))
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                if let rec = records.first {
                    completion(.success(self.userProfile(from: rec)))
                } else {
                    completion(.success(nil))
                }
            }
        }
    }

    func searchUsersByEmail(_ email: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void) {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            completion(.success(nil))
            return
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == 1", UserKeys.email, normalizedEmail, UserKeys.isDiscoverable)
        let query = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { queryResult in
            switch queryResult {
            case .failure(let error):
                // If schema doesn't exist or field not queryable, return nil instead of error
                let errorDesc = error.localizedDescription
                if errorDesc.contains("Unknown field") || errorDesc.contains("indexable") || errorDesc.contains("Queryable") {
                    completion(.success(nil))
                    return
                }
                completion(.failure(self.mapCKError(error)))
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                if let rec = records.first {
                    completion(.success(self.userProfile(from: rec)))
                } else {
                    completion(.success(nil))
                }
            }
        }
    }

    func createFriendRequest(from currentUser: UserProfile, to remoteUser: UserProfile, message: String?, completion: @escaping (Result<Bool, AppError>) -> Void) {
        let record = CKRecord(recordType: RecordType.friendRequest)
        let fromID = currentUser.cloudKitUserID ?? currentUser.phoneNumber
        let toID = remoteUser.cloudKitUserID ?? remoteUser.phoneNumber

        record[RequestKeys.fromUserID] = fromID as CKRecordValue
        record[RequestKeys.fromUserName] = currentUser.name as CKRecordValue
        record[RequestKeys.fromUserPhone] = currentUser.phoneNumber as CKRecordValue
        if let email = currentUser.email { record[RequestKeys.fromUserEmail] = email as CKRecordValue }
        record[RequestKeys.toUserID] = toID as CKRecordValue
        record[RequestKeys.toUserName] = remoteUser.name as CKRecordValue
        record[RequestKeys.toUserPhone] = remoteUser.phoneNumber as CKRecordValue
        if let email = remoteUser.email { record[RequestKeys.toUserEmail] = email as CKRecordValue }
        if let message = message { record[RequestKeys.message] = message as CKRecordValue }
        record[RequestKeys.status] = FriendRequestStatus.pending.rawValue as CKRecordValue
        record[RequestKeys.createdAt] = Date() as CKRecordValue

        publicDB.save(record) { _, error in
            if let error = error {
                completion(.failure(self.mapCKError(error)))
                return
            }
            completion(.success(true))
        }
    }

    func fetchIncomingFriendRequests(forPhone phoneNumber: String, completion: @escaping (Result<[FriendRequest], AppError>) -> Void) {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", RequestKeys.toUserPhone, phoneNumber, RequestKeys.status, FriendRequestStatus.pending.rawValue)
        let query = CKQuery(recordType: RecordType.friendRequest, predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { queryResult in
            switch queryResult {
            case .failure(let error):
                let errorDesc = error.localizedDescription
                if errorDesc.contains("Unknown field") || errorDesc.contains("Unknown record type") {
                    completion(.success([]))
                    return
                }
                if errorDesc.contains("Queryable") || errorDesc.contains("indexable") {
                    completion(.success([]))
                    return
                }
                completion(.failure(self.mapCKError(error)))
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                let requests = self.parseIncomingRequests(from: records, phoneNumber: phoneNumber)

                // Filter out requests that we've already responded to
                self.fetchResponsesForResponder(responderPhone: phoneNumber) { respondedRequestIDs in
                    let filteredRequests = requests.filter { request in
                        guard let recordID = request.cloudKitRecordID else { return true }
                        return !respondedRequestIDs.contains(recordID)
                    }
                    completion(.success(filteredRequests))
                }
            }
        }
    }

    /// Fetches FriendRequestResponse records where the current user is the responder
    /// Returns a set of originalRequestIDs that have been responded to
    private func fetchResponsesForResponder(responderPhone: String, completion: @escaping (Set<String>) -> Void) {
        let predicate = NSPredicate(format: "%K == %@", ResponseKeys.responderPhone, responderPhone)
        let query = CKQuery(recordType: RecordType.friendRequestResponse, predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { queryResult in
            switch queryResult {
            case .failure:
                completion([])
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                var respondedIDs = Set<String>()
                for rec in records {
                    if let originalID = rec[ResponseKeys.originalRequestID] as? String {
                        respondedIDs.insert(originalID)
                    }
                }
                completion(respondedIDs)
            }
        }
    }

    private func parseIncomingRequests(from records: [CKRecord], phoneNumber: String) -> [FriendRequest] {
        return records.compactMap { rec -> FriendRequest? in
            let fromPhone = rec[RequestKeys.fromUserPhone] as? String ?? ""

            // Skip requests where sender is the current user (shouldn't happen)
            if fromPhone == phoneNumber {
                return nil
            }

            var req = FriendRequest.incoming(
                fromUserID: rec[RequestKeys.fromUserID] as? String ?? "",
                fromUserName: rec[RequestKeys.fromUserName] as? String ?? "",
                fromUserPhone: fromPhone,
                fromUserEmail: rec[RequestKeys.fromUserEmail] as? String,
                message: rec[RequestKeys.message] as? String
            )
            req.toUserID = phoneNumber
            req.cloudKitRecordID = rec.recordID.recordName
            if let statusStr = rec[RequestKeys.status] as? String, let status = FriendRequestStatus(rawValue: statusStr) {
                req.status = status
            }
            req.createdAt = rec[RequestKeys.createdAt] as? Date ?? Date()
            req.respondedAt = rec[RequestKeys.respondedAt] as? Date
            return req
        }
    }

    func fetchOutgoingFriendRequests(forPhone phoneNumber: String, completion: @escaping (Result<[FriendRequest], AppError>) -> Void) {
        let predicate = NSPredicate(format: "%K == %@", RequestKeys.fromUserPhone, phoneNumber)
        let query = CKQuery(recordType: RecordType.friendRequest, predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { queryResult in
            switch queryResult {
            case .failure(let error):
                // If schema doesn't exist yet (unknown field/record type), return empty array
                let errorDesc = error.localizedDescription
                if errorDesc.contains("Unknown field") || errorDesc.contains("Unknown record type") {
                    completion(.success([]))
                    return
                }
                completion(.failure(self.mapCKError(error)))
                return
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                var requests = records.compactMap { rec -> FriendRequest? in
                    var req = FriendRequest.outgoing(
                        toUserID: rec[RequestKeys.toUserID] as? String ?? "",
                        toUserName: rec[RequestKeys.toUserName] as? String ?? "",
                        toUserPhone: rec[RequestKeys.toUserPhone] as? String ?? "",
                        toUserEmail: rec[RequestKeys.toUserEmail] as? String,
                        fromUserID: rec[RequestKeys.fromUserID] as? String ?? "",
                        fromUserName: rec[RequestKeys.fromUserName] as? String ?? "",
                        fromUserPhone: phoneNumber,
                        fromUserEmail: rec[RequestKeys.fromUserEmail] as? String,
                        message: rec[RequestKeys.message] as? String
                    )
                    req.cloudKitRecordID = rec.recordID.recordName
                    if let statusStr = rec[RequestKeys.status] as? String, let status = FriendRequestStatus(rawValue: statusStr) {
                        req.status = status
                    }
                    req.createdAt = rec[RequestKeys.createdAt] as? Date ?? Date()
                    req.respondedAt = rec[RequestKeys.respondedAt] as? Date
                    return req
                }

                // Now fetch any responses to our requests (where we are the sender)
                self.fetchResponsesForSender(senderPhone: phoneNumber) { responses in
                    // Merge response status into requests
                    for i in requests.indices {
                        if let recordID = requests[i].cloudKitRecordID,
                           let response = responses[recordID] {
                            requests[i].status = response.accepted ? .accepted : .declined
                            requests[i].respondedAt = response.respondedAt
                        }
                    }
                    completion(.success(requests))
                }
            }
        }
    }

    /// Fetches FriendRequestResponse records where the current user is the sender
    /// Returns a dictionary mapping originalRequestID to the response info
    private func fetchResponsesForSender(senderPhone: String, completion: @escaping ([String: (accepted: Bool, respondedAt: Date?)]) -> Void) {
        let predicate = NSPredicate(format: "%K == %@", ResponseKeys.senderPhone, senderPhone)
        let query = CKQuery(recordType: RecordType.friendRequestResponse, predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { queryResult in
            // Ensure we're on main thread for safety
            DispatchQueue.main.async {
                switch queryResult {
                case .failure:
                    completion([:])
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { try? $0.1.get() }
                    var responses: [String: (accepted: Bool, respondedAt: Date?)] = [:]
                    for rec in records {
                        if let originalID = rec[ResponseKeys.originalRequestID] as? String {
                            let accepted = (rec[ResponseKeys.accepted] as? Int ?? 0) == 1
                            let respondedAt = rec[ResponseKeys.respondedAt] as? Date
                            responses[originalID] = (accepted, respondedAt)
                        }
                    }
                    completion(responses)
                }
            }
        }
    }

    func respondToFriendRequest(recordID: String, accept: Bool, responderPhone: String, senderPhone: String, completion: @escaping (Result<Bool, AppError>) -> Void) {
        // Create a NEW FriendRequestResponse record instead of modifying the original
        // This works because the responder owns this new record and can write to it
        let responseRecord = CKRecord(recordType: RecordType.friendRequestResponse)
        responseRecord[ResponseKeys.originalRequestID] = recordID as CKRecordValue
        responseRecord[ResponseKeys.responderPhone] = responderPhone as CKRecordValue
        responseRecord[ResponseKeys.senderPhone] = senderPhone as CKRecordValue
        responseRecord[ResponseKeys.accepted] = (accept ? 1 : 0) as CKRecordValue
        responseRecord[ResponseKeys.respondedAt] = Date() as CKRecordValue

        publicDB.save(responseRecord) { _, saveError in
            if let saveError = saveError {
                completion(.failure(self.mapCKError(saveError)))
                return
            }
            completion(.success(true))
        }
    }

    func deleteFriendRequest(recordID: String, completion: @escaping (Result<Bool, AppError>) -> Void) {
        let ckRecordID = CKRecord.ID(recordName: recordID)
        publicDB.delete(withRecordID: ckRecordID) { _, error in
            if let error = error {
                completion(.failure(self.mapCKError(error)))
                return
            }
            completion(.success(true))
        }
    }

    func fetchFriendProfiles(friendUniqueIDs: [String], completion: @escaping (Result<[UserProfile], AppError>) -> Void) {
        guard !friendUniqueIDs.isEmpty else {
            completion(.success([]))
            return
        }

        // Extract phone numbers from the IDs (filter out non-phone identifiers)
        let phoneNumbers = friendUniqueIDs.filter { id in
            let digitsOnly = id.filter { $0.isNumber }
            return digitsOnly.count >= 10 && digitsOnly.count <= 15
        }

        guard !phoneNumbers.isEmpty else {
            completion(.success([]))
            return
        }

        // Query only by phone number (simpler and more reliable)
        let predicate = NSPredicate(format: "%K IN %@", UserKeys.phoneNumber, phoneNumbers)

        let query = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { queryResult in
            switch queryResult {
            case .failure(let error):
                // If schema doesn't exist yet, return empty array instead of failing
                let ckError = error as NSError
                if CKError.Code(rawValue: ckError.code) == .unknownItem {
                    completion(.success([]))
                    return
                }
                completion(.failure(self.mapCKError(error)))
                return
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                let profiles = records.map(self.userProfile(from:))
                completion(.success(profiles))
            }
        }
    }

    // MARK: - CloudKit Subscriptions

    func createFriendRequestSubscription(for phoneNumber: String, completion: @escaping (Result<Bool, AppError>) -> Void) {
        let subscriptionID = "incoming-friend-requests-\(phoneNumber)"

        // Check if subscription already exists
        publicDB.fetch(withSubscriptionID: subscriptionID) { [weak self] existingSubscription, error in
            guard let self = self else { return }

            if existingSubscription != nil {
                completion(.success(true))
                return
            }

            // Create new subscription for incoming friend requests (by phone number)
            let predicate = NSPredicate(format: "%K == %@", RequestKeys.toUserPhone, phoneNumber)
            let subscription = CKQuerySubscription(
                recordType: RecordType.friendRequest,
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.titleLocalizationKey = "New Friend Request"
            notificationInfo.alertLocalizationKey = "%1$@ wants to connect with you"
            notificationInfo.alertLocalizationArgs = [RequestKeys.fromUserName]
            notificationInfo.soundName = "default"
            notificationInfo.shouldBadge = true
            notificationInfo.shouldSendContentAvailable = true

            subscription.notificationInfo = notificationInfo

            self.publicDB.save(subscription) { savedSubscription, error in
                if let error = error {
                    completion(.failure(self.mapCKError(error)))
                } else {
                    completion(.success(true))
                }
            }
        }
    }

    func createFriendResponseSubscription(for phoneNumber: String, completion: @escaping (Result<Bool, AppError>) -> Void) {
        let subscriptionID = "friend-request-responses-\(phoneNumber)"

        // Check if subscription already exists
        publicDB.fetch(withSubscriptionID: subscriptionID) { [weak self] existingSubscription, error in
            guard let self = self else { return }

            if existingSubscription != nil {
                completion(.success(true))
                return
            }

            // Create subscription for FriendRequestResponse records where we are the sender
            // This notifies us when someone responds to our friend request
            let predicate = NSPredicate(format: "%K == %@", ResponseKeys.senderPhone, phoneNumber)
            let subscription = CKQuerySubscription(
                recordType: RecordType.friendRequestResponse,
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

            self.publicDB.save(subscription) { savedSubscription, error in
                if let error = error {
                    completion(.failure(self.mapCKError(error)))
                } else {
                    completion(.success(true))
                }
            }
        }
    }

    func removeAllSubscriptions(completion: @escaping (Result<Bool, AppError>) -> Void) {
        publicDB.fetchAllSubscriptions { [weak self] subscriptions, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(self.mapCKError(error)))
                return
            }

            guard let subscriptions = subscriptions, !subscriptions.isEmpty else {
                completion(.success(true))
                return
            }

            let subscriptionIDs = subscriptions.map { $0.subscriptionID }

            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: nil, subscriptionIDsToDelete: subscriptionIDs)
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    completion(.success(true))
                case .failure(let error):
                    completion(.failure(self.mapCKError(error)))
                }
            }

            self.publicDB.add(operation)
        }
    }
}


