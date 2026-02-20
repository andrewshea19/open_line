//
//  SyncManager.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation
import Combine
import CloudKit

protocol SyncManagerProtocol {
    var currentUserProfile: UserProfile? { get }
    var isConnected: Bool { get }
    var syncError: AppError? { get }
    var syncErrorPublisher: AnyPublisher<AppError?, Never> { get }
    var currentUserProfilePublisher: AnyPublisher<UserProfile?, Never> { get }

    func loadUserProfile()
    func saveUserProfile(_ profile: UserProfile)
    func updateUserStatus(status: String, message: String, until: Date?)
    func updateDeviceToken(_ token: String)
    func searchForUsersByPhone(_ phoneNumber: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void)
    func searchForUsersByEmail(_ email: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void)
    func sendFriendRequest(to userProfile: UserProfile, message: String?, completion: @escaping (Result<Bool, AppError>) -> Void)
    func fetchFriendStatuses(for friends: [Friend], completion: @escaping (Result<[Friend], AppError>) -> Void)
    func acceptFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void)
    func declineFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void)
    func cancelFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void)
    func fetchIncomingFriendRequests(completion: @escaping (Result<[FriendRequest], AppError>) -> Void)
    func fetchOutgoingFriendRequests(completion: @escaping (Result<[FriendRequest], AppError>) -> Void)
    func removeFriend(myPhone: String, friendPhone: String, completion: @escaping (Result<Bool, AppError>) -> Void)
    func checkForFriendRemovals(completion: @escaping (Result<[String], AppError>) -> Void)
}

final class SyncManager: ObservableObject, SyncManagerProtocol {
    static let shared = SyncManager()

    @Published var currentUserProfile: UserProfile?
    @Published var isConnected = true
    @Published var syncError: AppError?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let cloudService: CloudKitServiceProtocol

    private let profileKey = "userProfile"
    private let lastSyncKey = "lastSyncDate"

    init(cloudService: CloudKitServiceProtocol = CloudKitManager(containerIdentifier: "iCloud.com.shea.OpenLine")) {
        self.cloudService = cloudService
        loadUserProfile()
        setupNetworkMonitoring()
    }

    // MARK: - Publishers

    var syncErrorPublisher: AnyPublisher<AppError?, Never> {
        $syncError.eraseToAnyPublisher()
    }

    var currentUserProfilePublisher: AnyPublisher<UserProfile?, Never> {
        $currentUserProfile.eraseToAnyPublisher()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        let container = CKContainer(identifier: "iCloud.com.shea.OpenLine")
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    let nsError = error as NSError
                    if let ckError = CKError.Code(rawValue: nsError.code) {
                        if ckError == .networkUnavailable || ckError == .networkFailure {
                            self.isConnected = false
                        }
                    }
                    return
                }

                switch status {
                case .available:
                    self.isConnected = true
                case .noAccount, .restricted:
                    self.isConnected = true // Allow attempts, will get auth errors if needed
                case .temporarilyUnavailable:
                    self.isConnected = false
                case .couldNotDetermine:
                    self.isConnected = true
                @unknown default:
                    self.isConnected = true
                }
            }
        }
    }

    // MARK: - User Profile Management

    func loadUserProfile() {
        // Load local cache first for instant UI
        if let profileData = userDefaults.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            currentUserProfile = profile
            Logger.shared.sync("Loaded profile from cache: \(profile.name)")
        }

        if let lastSync = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = lastSync
        }

        // Fetch or create in CloudKit to ensure we have a server copy
        if currentUserProfile != nil || DataPersistenceManager.shared.isFirstLaunch {
            cloudService.fetchOrCreateCurrentUserProfile(localProfile: currentUserProfile) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let remoteProfile):
                        if !remoteProfile.phoneNumber.isEmpty {
                            self?.saveUserProfile(remoteProfile)
                        }
                    case .failure(let error):
                        self?.handleProfileFetchError(error)
                    }
                }
            }
        }
    }

    private func handleProfileFetchError(_ error: AppError) {
        let errorDesc = error.errorDescription ?? ""
        let isTransientError = errorDesc.contains("oplock") ||
                               errorDesc.contains("Record conflict") ||
                               errorDesc.contains("Data was updated")

        let isAuthErrorWithCache: Bool = {
            if case .authenticationError = error {
                return currentUserProfile != nil
            }
            return false
        }()

        if !isTransientError && !isAuthErrorWithCache {
            syncError = error
        }

        if case .authenticationError = error, currentUserProfile == nil {
            isConnected = false
        }
    }

    func saveUserProfile(_ profile: UserProfile) {
        currentUserProfile = profile
        if let profileData = try? JSONEncoder().encode(profile) {
            userDefaults.set(profileData, forKey: profileKey)
        }

        cloudService.upsertUserProfile(profile) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    if case .authenticationError = error {
                        // Suppress auth errors when we have a local profile
                    } else {
                        self?.syncError = error
                    }
                }
                self?.updateLastSyncDate()
            }
        }
    }

    func updateUserStatus(status: String, message: String, until: Date?) {
        guard var profile = currentUserProfile else {
            syncError = .dataError("No user profile found")
            return
        }

        profile.currentStatus = status
        profile.statusMessage = message
        profile.statusUntil = until
        profile.lastStatusUpdate = Date()

        saveUserProfile(profile)
    }

    func updateDeviceToken(_ token: String) {
        guard var profile = currentUserProfile else {
            userDefaults.set(token, forKey: "pendingDeviceToken")
            return
        }

        if !profile.deviceTokens.contains(token) {
            profile.deviceTokens.append(token)
            if profile.deviceTokens.count > 5 {
                profile.deviceTokens = Array(profile.deviceTokens.suffix(5))
            }
            saveUserProfile(profile)
        }
    }

    private func updateLastSyncDate() {
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)
    }

    // MARK: - Friend Discovery

    func searchForUsersByPhone(_ phoneNumber: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void) {
        cloudService.searchUsersByPhone(phoneNumber) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func searchForUsersByEmail(_ email: String, completion: @escaping (Result<UserProfile?, AppError>) -> Void) {
        cloudService.searchUsersByEmail(email) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(to userProfile: UserProfile, message: String? = nil, completion: @escaping (Result<Bool, AppError>) -> Void) {
        guard let current = currentUserProfile else {
            completion(.failure(.dataError("Missing current user")))
            return
        }

        cloudService.createFriendRequest(from: current, to: userProfile, message: message) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func acceptFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void) {
        respondToRequest(request, accept: true, completion: completion)
    }

    func declineFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void) {
        respondToRequest(request, accept: false, completion: completion)
    }

    private func respondToRequest(_ request: FriendRequest, accept: Bool, completion: @escaping (Result<Bool, AppError>) -> Void) {
        guard let recordID = request.cloudKitRecordID else {
            completion(.failure(.dataError("Missing request record ID")))
            return
        }
        guard let responderPhone = currentUserProfile?.phoneNumber else {
            completion(.failure(.dataError("Missing current user profile")))
            return
        }

        let senderPhone = request.fromUserPhone
        cloudService.respondToFriendRequest(recordID: recordID, accept: accept, responderPhone: responderPhone, senderPhone: senderPhone) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func cancelFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Bool, AppError>) -> Void) {
        guard let recordID = request.cloudKitRecordID else {
            completion(.failure(.dataError("Missing request record ID")))
            return
        }

        cloudService.deleteFriendRequest(recordID: recordID) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func fetchIncomingFriendRequests(completion: @escaping (Result<[FriendRequest], AppError>) -> Void) {
        guard let profile = currentUserProfile else {
            completion(.success([]))
            return
        }

        cloudService.fetchIncomingFriendRequests(forPhone: profile.phoneNumber) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func fetchOutgoingFriendRequests(completion: @escaping (Result<[FriendRequest], AppError>) -> Void) {
        guard let phoneNumber = currentUserProfile?.phoneNumber else {
            completion(.success([]))
            return
        }

        cloudService.fetchOutgoingFriendRequests(forPhone: phoneNumber) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Friend Status Sync

    func fetchFriendStatuses(for friends: [Friend], completion: @escaping (Result<[Friend], AppError>) -> Void) {
        isSyncing = true
        let friendPhones = friends.map { $0.phoneNumber }

        cloudService.fetchFriendProfiles(friendUniqueIDs: friendPhones) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncing = false
                self.updateLastSyncDate()

                switch result {
                case .failure(let error):
                    completion(.failure(error))

                case .success(let profiles):
                    // Build lookup dictionary, preferring most recently updated profile for duplicates
                    let byPhone = Dictionary(
                        profiles.map { ($0.phoneNumber, $0) },
                        uniquingKeysWith: { existing, new in
                            let existingDate = existing.lastStatusUpdate ?? Date.distantPast
                            let newDate = new.lastStatusUpdate ?? Date.distantPast
                            return newDate > existingDate ? new : existing
                        }
                    )

                    let updated = friends.map { friend -> Friend in
                        var f = friend
                        if let profile = byPhone[friend.phoneNumber] {
                            f.currentStatus = profile.currentStatus
                            f.statusMessage = profile.statusMessage
                            f.availableUntil = profile.statusUntil
                            f.lastStatusUpdate = profile.lastStatusUpdate
                            if let cloudID = profile.cloudKitUserID {
                                f.friendRecordID = cloudID
                            }
                            f.lastSyncDate = Date()
                        }
                        return f
                    }

                    completion(.success(updated))
                }
            }
        }
    }

    // MARK: - Friend Removal (Bidirectional)

    func removeFriend(myPhone: String, friendPhone: String, completion: @escaping (Result<Bool, AppError>) -> Void) {
        cloudService.createFriendRemoval(removerPhone: myPhone, removedPhone: friendPhone) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    func checkForFriendRemovals(completion: @escaping (Result<[String], AppError>) -> Void) {
        guard let profile = currentUserProfile else {
            completion(.success([]))
            return
        }

        cloudService.fetchFriendRemovals(forPhone: profile.phoneNumber) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }
}
