//
//  OpenLineViewModel.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation
import SwiftUI
import Combine
import WidgetKit
import UserNotifications

// Centralized strings and shared values that define app semantics (no UI change)
struct AppConstants {
    static let quickExtendMinutes: [Int] = [30, 60, 120, 240]
    struct Category {
        static let availableNow = "Available Now"
        static let availableSoon = "Available Soon"
        static let notAvailable = "Not Available"
    }
}

protocol LogSink {
    func log(_ message: String)
}

struct NopLogger: LogSink {
    func log(_ message: String) {}
}

@MainActor
final class OpenLineViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var schedules: [Schedule] = []
    @Published private(set) var currentStatus = "No Status"
    @Published private(set) var statusMessage = ""
    @Published private(set) var statusUntil: Date?
    @Published private(set) var pendingFriendRequests: [FriendRequest] = []
    @Published private(set) var sentFriendRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Computed Properties
    var defaultStatusDuration: Int {
        get { persistenceManager.defaultStatusDuration }
        set { persistenceManager.defaultStatusDuration = newValue }
    }
    
    var respectsDoNotDisturb: Bool {
        get { persistenceManager.respectsDoNotDisturb }
        set { persistenceManager.respectsDoNotDisturb = newValue }
    }
    
    var globalStatusVisibility: Bool {
        get { persistenceManager.globalStatusVisibility }
        set { persistenceManager.globalStatusVisibility = newValue }
    }
    
    var isFirstLaunch: Bool {
        get { persistenceManager.isFirstLaunch }
        set { persistenceManager.isFirstLaunch = newValue }
    }
    
    // MARK: - Private Properties
    private let syncManager: SyncManagerProtocol
    private let persistenceManager: DataPersistenceManager
    private var statusHistory: [(StatusType, Date)] = []
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTimer: Timer?
    private var statusExpirationTimer: Timer?
    private var scheduleActivationTimer: Timer?
    private let logger: LogSink
    
    // MARK: - Friend Categories Cache
    private var friendCategoriesCache: [(category: String, friends: [Friend])]?
    private var cacheUpdateTime: Date?
    
    // MARK: - Initialization
    
    init(
        syncManager: SyncManagerProtocol = SyncManager.shared,
        persistenceManager: DataPersistenceManager = DataPersistenceManager.shared,
        logger: LogSink = NopLogger()
    ) {
        self.syncManager = syncManager
        self.persistenceManager = persistenceManager
        self.logger = logger
        loadData()
        setupBindings()
        setupStatusMonitoring()
        checkInitialLaunch()
        
        #if DEBUG
        generateSampleDataIfNeeded()
        #endif
    }
    
    deinit {
        statusCheckTimer?.invalidate()
        statusExpirationTimer?.invalidate()
        scheduleActivationTimer?.invalidate()
    }
    
    private func setupBindings() {
        // Subscribe to sync manager changes
        syncManager.syncErrorPublisher
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        syncManager.currentUserProfilePublisher
            .sink { [weak self] profile in
                if let profile = profile {
                    self?.currentStatus = profile.currentStatus
                    self?.statusMessage = profile.statusMessage
                    self?.statusUntil = profile.statusUntil
                    self?.scheduleStatusExpiration(until: profile.statusUntil)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusMonitoring() {
        // Listen for CloudKit subscription notifications
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudKitNotification(notification)
            }
            .store(in: &cancellables)

        // Listen for notification taps to navigate appropriately
        NotificationCenter.default.publisher(for: .notificationTapped)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchFriendRequests()
            }
            .store(in: &cancellables)

        // Listen for app becoming active to sync widget changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncFromWidget()
            }
            .store(in: &cancellables)

        // Use longer fallback polling interval in production (5 minutes)
        // CloudKit subscriptions handle real-time updates
        #if DEBUG
        let pollingInterval: TimeInterval = 60 // 1 minute in debug
        #else
        let pollingInterval: TimeInterval = 300 // 5 minutes in production
        #endif

        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            Task { @MainActor in
                self.checkAndRefreshStatuses()
            }
        }
    }

    private func handleCloudKitNotification(_ notification: Notification) {
        guard let subscriptionID = notification.userInfo?["subscriptionID"] as? String else { return }

        logger.log("Received CloudKit update for subscription: \(subscriptionID)")

        if subscriptionID.contains("friend-request") {
            // Refresh friend requests
            fetchFriendRequests()
        } else if subscriptionID.contains("friend-status") {
            // Refresh friend statuses
            syncFriendStatuses()
        }
    }
    
    private func checkInitialLaunch() {
        if isFirstLaunch {
            isFirstLaunch = false
        }
    }
    
    // MARK: - Data Management
    
    private func loadData() {
        do {
            friends = try persistenceManager.loadFriends()
            schedules = try persistenceManager.loadSchedules()
            pendingFriendRequests = try persistenceManager.loadPendingRequests()
            sentFriendRequests = try persistenceManager.loadSentRequests()
        } catch {
            handleError(AppError.dataError("Failed to load data: \(error.localizedDescription)"))
        }
        
        syncManager.loadUserProfile()
        if let profile = syncManager.currentUserProfile {
            currentStatus = profile.currentStatus
            statusMessage = profile.statusMessage
            statusUntil = profile.statusUntil
            // Schedule expiration timer for existing status
            scheduleStatusExpiration(until: statusUntil)
        }

        // Apply any active schedule immediately on startup
        applyScheduleIfNeeded(at: Date())

        // Schedule timer for next schedule activation
        scheduleNextActivation()
    }
    
    private func saveData() {
        do {
            try persistenceManager.saveFriends(friends)
            try persistenceManager.saveSchedules(schedules)
            try persistenceManager.savePendingRequests(pendingFriendRequests)
            try persistenceManager.saveSentRequests(sentFriendRequests)
        } catch {
            handleError(AppError.dataError("Failed to save data: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - Error Handling

    private func handleError(_ error: AppError) {
        errorMessage = error.errorDescription
        showError = true
        if let description = error.errorDescription {
            logger.log("AppError: \(description)")
        }
    }

    // MARK: - Badge Management

    func updateAppBadge() {
        let badgeCount = pendingFriendRequests.count
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error = error {
                Logger.shared.error("Failed to update badge: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Friend Availability Notifications

    private func checkForNewlyAvailableFriends(oldFriends: [Friend], newFriends: [Friend]) {
        guard NotificationManager.shared.isAuthorized else { return }

        for newFriend in newFriends {
            // Find old version of this friend
            guard let oldFriend = oldFriends.first(where: { $0.id == newFriend.id }) else { continue }

            // Check if friend just became available
            let wasAvailable = oldFriend.currentStatus == "Available" && (oldFriend.availableUntil ?? Date.distantPast) > Date()
            let isNowAvailable = newFriend.currentStatus == "Available" && (newFriend.availableUntil ?? Date.distantPast) > Date()

            if !wasAvailable && isNowAvailable {
                // Friend just became available - send local notification
                NotificationManager.shared.scheduleLocalNotification(
                    title: "\(newFriend.name) is now available",
                    body: newFriend.statusMessage ?? "Free for calls!",
                    identifier: "friend-available-\(newFriend.id.uuidString)"
                )
            }
        }
    }

    // MARK: - Status Management
    
    func checkAndRefreshStatuses() {
        let now = Date()

        // Check if current status has expired
        if let until = statusUntil, until <= now {
            autoExpireStatus()
        }

        // Apply schedule-based status if applicable
        applyScheduleIfNeeded(at: now)

        // Update friend statuses locally
        updateFriendStatuses()

        // Check for bidirectional friend removals
        checkForFriendRemovals()

        // Sync with CloudKit
        syncFriendStatuses()
    }
    
    private func autoExpireStatus() {
        currentStatus = "No Status"
        statusMessage = ""
        statusUntil = nil
        statusHistory.append((.noStatus, Date()))
        saveData()

        syncManager.updateUserStatus(status: currentStatus, message: statusMessage, until: statusUntil)

        // Update widget immediately when status expires
        syncToWidget()
    }
    
    private func updateFriendStatuses() {
        var hasChanges = false
        for i in friends.indices {
            if let until = friends[i].availableUntil, until <= Date() {
                friends[i].currentStatus = "No Status"
                friends[i].statusMessage = ""
                friends[i].availableUntil = nil
                hasChanges = true
            }
        }

        if hasChanges {
            friendCategoriesCache = nil // Invalidate cache
            saveData()
            syncToWidget()
        }
    }
    
    func syncFriendStatuses() {
        isLoading = true

        let oldFriends = friends

        syncManager.fetchFriendStatuses(for: friends) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let updatedFriends):
                    // Check for friends who just became available (for notifications)
                    self?.checkForNewlyAvailableFriends(oldFriends: oldFriends, newFriends: updatedFriends)

                    self?.friends = updatedFriends
                    self?.friendCategoriesCache = nil
                    self?.saveData()
                    self?.syncToWidget()
                case .failure(let error):
                    self?.handleError(error)
                }
            }
        }
    }
    
    func updateCurrentStatus(status: String, message: String, until: Date?) {
        currentStatus = status
        statusMessage = message
        statusUntil = until

        if let statusType = StatusType(rawValue: status) {
            statusHistory.append((statusType, Date()))
            if statusHistory.count > 10 {
                statusHistory.removeFirst()
            }
        }

        // Schedule expiration timer
        scheduleStatusExpiration(until: until)

        saveData()
        syncManager.updateUserStatus(status: status, message: message, until: until)

        // Sync to widget via App Groups
        syncToWidget()
    }

    /// Schedule a timer to automatically expire status at the specified time
    private func scheduleStatusExpiration(until: Date?) {
        // Cancel any existing expiration timer
        statusExpirationTimer?.invalidate()
        statusExpirationTimer = nil

        guard let expirationDate = until else { return }

        let timeInterval = expirationDate.timeIntervalSinceNow
        guard timeInterval > 0 else {
            // Already expired, handle immediately
            checkAndRefreshStatuses()
            return
        }

        // Schedule timer to fire at expiration time
        statusExpirationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndRefreshStatuses()
            }
        }
    }

    /// Sync current status and friends to widget via shared App Groups storage
    func syncToWidget() {
        let phone = syncManager.currentUserProfile?.phoneNumber ?? ""
        let name = syncManager.currentUserProfile?.name ?? ""

        // Get available friends for widget
        let now = Date()
        let widgetFriends: [WidgetFriend] = friends.compactMap { friend -> WidgetFriend? in
            guard let until = friend.availableUntil, until > now else { return nil }
            guard friend.currentStatus == "Available" else { return nil }
            return WidgetFriend(
                id: friend.id.uuidString,
                name: friend.name,
                phoneNumber: friend.phoneNumber,
                status: friend.currentStatus ?? "No Status",
                statusMessage: friend.statusMessage ?? "",
                availableUntil: friend.availableUntil
            )
        }

        SharedDefaults.shared.syncFromApp(
            status: currentStatus,
            message: statusMessage,
            until: statusUntil,
            phone: phone,
            name: name,
            duration: defaultStatusDuration,
            friends: widgetFriends
        )

        // Reload widget timelines to show updated data
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Sync status changes made via widget back to the app
    private func syncFromWidget() {
        let shared = SharedDefaults.shared
        let widgetStatus = shared.currentStatus
        let widgetMessage = shared.statusMessage
        let widgetUntil = shared.statusUntil

        // Check if widget has a different status than the app
        let statusChanged = widgetStatus != currentStatus
        let untilChanged = widgetUntil != statusUntil

        if statusChanged || untilChanged {
            // Widget was used to change status - sync to app and CloudKit
            currentStatus = widgetStatus
            statusMessage = widgetMessage
            statusUntil = widgetUntil

            // Update CloudKit with widget changes
            syncManager.updateUserStatus(status: widgetStatus, message: widgetMessage, until: widgetUntil)

            // Schedule expiration timer for the new status
            scheduleStatusExpiration(until: widgetUntil)

            // Save locally
            saveData()

            logger.log("Synced status from widget: \(widgetStatus)")
        }

        // Also check for any schedule-based status changes
        applyScheduleIfNeeded(at: Date())
    }

    func extendCurrentStatus(by minutes: Int) {
        guard currentStatus != "No Status" else { return }
        
        let newUntil = Calendar.current.date(
            byAdding: .minute,
            value: minutes,
            to: statusUntil ?? Date()
        ) ?? Date()
        
        statusUntil = newUntil
        saveData()
        syncManager.updateUserStatus(status: currentStatus, message: statusMessage, until: statusUntil)
    }

    // MARK: - Schedule application and sorting

    func sortedSchedules() -> [Schedule] {
        // Sorting schedules by next occurrence (recurring) and event date (one-time)
        func parseDate(_ str: String) -> Date? {
            // Be liberal in what we accept: medium, long, and full month formats
            let locales = [Locale(identifier: "en_US_POSIX"), Locale(identifier: "en_US")]
            let styles: [DateFormatter.Style] = [.medium, .long]
            var cleaned = str
                .replacingOccurrences(of: "\u{00A0}", with: " ") // NBSP -> space
                .trimmingCharacters(in: .whitespacesAndNewlines)
            for loc in locales {
                for style in styles {
                    let df = DateFormatter()
                    df.locale = loc
                    df.dateStyle = style
                    df.timeStyle = .none
                    if let d = df.date(from: cleaned) { return d }
                }
            }
            // Fallback exact format
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "MMM d, yyyy"
            if let d = df.date(from: cleaned) { return d }
            return nil
        }

        func isOneTime(_ s: Schedule) -> Bool {
            let parts = s.schedule.components(separatedBy: ",")
            guard !parts.isEmpty else { return false }
            let first = parts[0].trimmingCharacters(in: .whitespaces)
            if let d = parseDate(first) { return d != nil }
            if parts.count >= 2 {
                let combined = first + ", " + parts[1].trimmingCharacters(in: .whitespaces)
                return parseDate(combined) != nil
            }
            return false
        }
        
        func oneTimeStart(_ s: Schedule) -> Date? {
            let parts = s.schedule.components(separatedBy: ",")
            guard parts.count >= 2 else { return nil }
            var first = parts[0].trimmingCharacters(in: .whitespaces)
            if parts.count >= 2, parseDate(first) == nil {
                let candidate = first + ", " + parts[1].trimmingCharacters(in: .whitespaces)
                if parseDate(candidate) != nil { first = candidate }
            }
            let timeRange = parts.suffix(1).joined(separator: ",").trimmingCharacters(in: .whitespaces)
            let day = parseDate(first)
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.locale = Locale(identifier: "en_US_POSIX")
            guard let day = day else { return nil }
            if let dash = timeRange.firstIndex(of: "-") {
                let startStr = String(timeRange[..<dash]).trimmingCharacters(in: .whitespaces)
                if let t = tf.date(from: startStr) {
                    let cal = Calendar.current
                    return cal.date(bySettingHour: cal.component(.hour, from: t), minute: cal.component(.minute, from: t), second: 0, of: day)
                }
            }
            return day
        }
        
        let sorted = schedules.sorted { a, b in
            let aOne = isOneTime(a)
            let bOne = isOneTime(b)
            if aOne != bOne {
                // Recurring first, then one-time
                return !aOne && bOne
            }
            if aOne {
                let aStart = oneTimeStart(a) ?? Date.distantFuture
                let bStart = oneTimeStart(b) ?? Date.distantFuture
                return aStart < bStart
            } else {
                let aStart = nextOccurrence(for: a)?.start ?? Date.distantFuture
                let bStart = nextOccurrence(for: b)?.start ?? Date.distantFuture
                return aStart < bStart
            }
        }
        return sorted
    }

    private func applyScheduleIfNeeded(at now: Date) {
        // Find any active schedule whose current occurrence contains now
        let activeSchedules = schedules.filter { $0.isActive }
        var matching: (schedule: Schedule, window: (start: Date, end: Date))?
        for sched in activeSchedules {
            if let window = currentOccurrence(for: sched, at: now) {
                matching = (sched, window)
                break
            }
        }
        guard let match = matching else { return }

        let desiredStatus = match.schedule.status
        let desiredUntil = match.window.end

        if currentStatus != desiredStatus || statusUntil != desiredUntil {
            updateCurrentStatus(status: desiredStatus, message: statusMessage, until: desiredUntil)
        }
    }

    /// Schedule a timer to fire at the next schedule transition (start or end time) for precise activation/deactivation
    private func scheduleNextActivation() {
        scheduleActivationTimer?.invalidate()
        scheduleActivationTimer = nil

        let now = Date()
        var nextTransition: Date?

        // Find the earliest upcoming schedule start OR end time
        for schedule in schedules where schedule.isActive {
            // Check for upcoming start times
            if let occurrence = nextOccurrence(for: schedule, from: now) {
                // Consider future start times
                if occurrence.start > now {
                    if nextTransition == nil || occurrence.start < nextTransition! {
                        nextTransition = occurrence.start
                    }
                }
                // Also consider end times for currently active or upcoming schedules
                if occurrence.end > now {
                    if nextTransition == nil || occurrence.end < nextTransition! {
                        nextTransition = occurrence.end
                    }
                }
            }

            // Also check current occurrence for end time
            if let current = currentOccurrence(for: schedule, at: now) {
                if current.end > now {
                    if nextTransition == nil || current.end < nextTransition! {
                        nextTransition = current.end
                    }
                }
            }
        }

        guard let fireDate = nextTransition else { return }

        let timeInterval = fireDate.timeIntervalSince(now)
        guard timeInterval > 0 else { return }

        // Schedule timer to fire at exact transition time
        scheduleActivationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndRefreshStatuses()
                // Schedule the next transition after this one fires
                self?.scheduleNextActivation()
            }
        }

        logger.log("Scheduled activation timer for \(fireDate)")
    }

    private func currentOccurrence(for schedule: Schedule, at now: Date) -> (start: Date, end: Date)? {
        guard let next = nextOccurrence(for: schedule, from: now.addingTimeInterval(-60*60*24)) else { return nil }
        // If now is between start and end (exclusive of end time - schedule ends AT end time, not after)
        if next.start <= now && now < next.end { return next }
        return nil
    }

    private func nextOccurrence(for schedule: Schedule, from base: Date = Date()) -> (start: Date, end: Date)? {
        // schedule.schedule examples:
        // "Oct 30, 2025, 8:00 PM-11:00 PM"
        // "Mon-Fri, 8:30 AM-9:15 AM" or "Monday, Wednesday, 5:00 PM-6:00 PM"

        // Find the last comma to separate date/day part from time range
        // This handles dates like "Feb 18, 2026" which contain commas
        guard let lastCommaIndex = schedule.schedule.lastIndex(of: ",") else { return nil }
        let first = String(schedule.schedule[..<lastCommaIndex]).trimmingCharacters(in: .whitespaces)
        let timeRangeString = String(schedule.schedule[schedule.schedule.index(after: lastCommaIndex)...]).trimmingCharacters(in: .whitespaces)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "en_US")
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.locale = Locale(identifier: "en_US")
        
        func parseTimeRange(_ str: String) -> (DateComponents, DateComponents)? {
            guard str.contains("-") else { return nil }
            let comps = str.components(separatedBy: "-")
            guard comps.count == 2,
                  let startTime = timeFormatter.date(from: comps[0].trimmingCharacters(in: .whitespaces)),
                  let endTime = timeFormatter.date(from: comps[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            let cal = Calendar.current
            let sdc = cal.dateComponents([.hour, .minute], from: startTime)
            let edc = cal.dateComponents([.hour, .minute], from: endTime)
            return (sdc, edc)
        }
        guard let (startTimeDC, endTimeDC) = parseTimeRange(timeRangeString) else { return nil }
        let cal = Calendar.current
        
        // One-time if first parses as a date
        if let eventDate = dateFormatter.date(from: first) {
            var start = cal.date(bySettingHour: startTimeDC.hour ?? 0, minute: startTimeDC.minute ?? 0, second: 0, of: eventDate) ?? eventDate
            var end = cal.date(bySettingHour: endTimeDC.hour ?? 0, minute: endTimeDC.minute ?? 0, second: 0, of: eventDate) ?? eventDate
            if end < start { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
            return (start, end)
        }
        
        // Recurring: compute next occurrence within next 7 days
        let dayNamesFull = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        let dayNamesShort = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        var allowedDays = Set<Int>() // 0=Sun ... 6=Sat
        let dayPart = first // e.g. "Mon-Fri" or "Monday, Wednesday"
        let tokens = dayPart.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for token in tokens {
            if token.contains("-") {
                let rangeParts = token.components(separatedBy: "-")
                if rangeParts.count == 2 {
                    let a = rangeParts[0].trimmingCharacters(in: .whitespaces)
                    let b = rangeParts[1].trimmingCharacters(in: .whitespaces)
                    let ai = dayNamesShort.firstIndex { $0.caseInsensitiveCompare(a) == .orderedSame } ?? dayNamesFull.firstIndex { $0.caseInsensitiveCompare(a) == .orderedSame }
                    let bi = dayNamesShort.firstIndex { $0.caseInsensitiveCompare(b) == .orderedSame } ?? dayNamesFull.firstIndex { $0.caseInsensitiveCompare(b) == .orderedSame }
                    if let ai, let bi {
                        if ai <= bi {
                            for d in ai...bi { allowedDays.insert(d) }
                        } else {
                            for d in ai...6 { allowedDays.insert(d) }
                            for d in 0...bi { allowedDays.insert(d) }
                        }
                    }
                }
            } else if !token.isEmpty {
                if let idx = dayNamesShort.firstIndex(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) ?? dayNamesFull.firstIndex(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
                    allowedDays.insert(idx)
                }
            }
        }
        
        let startOfDay = cal.startOfDay(for: base)
        for offset in 0..<14 { // search two weeks ahead
            guard let day = cal.date(byAdding: .day, value: offset, to: startOfDay) else { continue }
            let weekday = cal.component(.weekday, from: day) - 1 // Calendar weekday: 1=Sun
            if allowedDays.contains(weekday) {
                var start = cal.date(bySettingHour: startTimeDC.hour ?? 0, minute: startTimeDC.minute ?? 0, second: 0, of: day) ?? day
                var end = cal.date(bySettingHour: endTimeDC.hour ?? 0, minute: endTimeDC.minute ?? 0, second: 0, of: day) ?? day
                if end < start { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
                return (start, end)
            }
        }
        return nil
    }
    
    func cycleToPreviousStatus() {
        let statuses = StatusType.allCases
        if let currentIndex = statuses.firstIndex(where: { $0.rawValue == currentStatus }) {
            let previousIndex = currentIndex > 0 ? currentIndex - 1 : statuses.count - 1
            let newStatus = statuses[previousIndex]
            
            let duration = getLastUsedDuration(for: newStatus) ?? defaultStatusDuration
            let until = newStatus == .noStatus ? nil : Calendar.current.date(byAdding: .minute, value: duration, to: Date())
            
            updateCurrentStatus(status: newStatus.rawValue, message: newStatus.defaultMessage, until: until)
        }
    }
    
    func cycleToNextStatus() {
        let statuses = StatusType.allCases
        if let currentIndex = statuses.firstIndex(where: { $0.rawValue == currentStatus }) {
            let nextIndex = (currentIndex + 1) % statuses.count
            let newStatus = statuses[nextIndex]
            
            let duration = getLastUsedDuration(for: newStatus) ?? defaultStatusDuration
            let until = newStatus == .noStatus ? nil : Calendar.current.date(byAdding: .minute, value: duration, to: Date())
            
            updateCurrentStatus(status: newStatus.rawValue, message: newStatus.defaultMessage, until: until)
        }
    }
    
    // MARK: - Duration Management
    
    func setLastUsedDuration(_ duration: Int, for status: StatusType) {
        var durations = persistenceManager.lastUsedDurations
        durations[status.rawValue] = duration
        persistenceManager.lastUsedDurations = durations
    }
    
    func getLastUsedDuration(for status: StatusType) -> Int? {
        return persistenceManager.lastUsedDurations[status.rawValue]
    }
    
    // MARK: - Friend Management

    func removeFriend(_ friend: Friend) {
        // Remove locally first for responsive UI
        friends.removeAll { $0.id == friend.id }
        friendCategoriesCache = nil // Invalidate cache
        saveData()

        // Create removal record in CloudKit for bidirectional removal
        guard let myPhone = syncManager.currentUserProfile?.phoneNumber else { return }
        syncManager.removeFriend(myPhone: myPhone, friendPhone: friend.phoneNumber) { [weak self] result in
            if case .failure(let error) = result {
                self?.handleError(error)
            }
        }
    }

    /// Check for and process any pending friend removals from other users
    func checkForFriendRemovals() {
        syncManager.checkForFriendRemovals { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let removerPhones):
                    guard let self = self, !removerPhones.isEmpty else { return }

                    // Remove friends whose phone numbers are in the removal list
                    var hasChanges = false
                    for phone in removerPhones {
                        if self.friends.contains(where: { $0.phoneNumber == phone }) {
                            self.friends.removeAll { $0.phoneNumber == phone }
                            hasChanges = true
                        }
                    }

                    if hasChanges {
                        self.friendCategoriesCache = nil
                        self.saveData()
                    }
                case .failure:
                    // Silently ignore errors - this is a background sync operation
                    break
                }
            }
        }
    }
    
    func updateFriendVisibility(friend: Friend, canSee: Bool) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].canSeeMyStatus = canSee
            saveData()
        }
    }
    
    func setAllFriendsVisibility(_ canSee: Bool) {
        for i in friends.indices {
            friends[i].canSeeMyStatus = canSee
        }
        saveData()
    }
    
    func canFriendSeeStatus(_ friend: Friend) -> Bool {
        return globalStatusVisibility && friend.canSeeMyStatus
    }
    
    // MARK: - Friend Categories (Optimized)
    
    func getFriendCategories() -> [(category: String, friends: [Friend])] {
        // Check if cache is valid
        if let cache = friendCategoriesCache,
           let cacheTime = cacheUpdateTime,
           Date().timeIntervalSince(cacheTime) < 5 { // Cache for 5 seconds
            return cache
        }
        
        // Calculate categories
        let now = Date()
        let oneHourFromNow = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now

        // A friend is "available now" if their status is "Available" AND their availability hasn't expired
        let availableNow = friends.filter { friend in
            // Must have "Available" status
            guard friend.displayStatus == "Available" else { return false }
            // If they have an expiration time, it must be in the future
            if let until = friend.availableUntil {
                return until > now
            }
            // No expiration = always available
            return true
        }

        // "Available soon" = status will change to available within the hour
        let availableSoon = friends.filter { friend in
            guard let until = friend.availableUntil else { return false }
            // They're currently NOT available but will be free soon
            return friend.displayStatus != "Available" && until > now && until <= oneHourFromNow
        }

        // Everyone else is "not available"
        let notAvailable = friends.filter { friend in
            // Not in availableNow
            let isAvailableNow = friend.displayStatus == "Available" && (friend.availableUntil == nil || friend.availableUntil! > now)
            if isAvailableNow { return false }

            // Not in availableSoon
            if let until = friend.availableUntil {
                let isAvailableSoon = friend.displayStatus != "Available" && until > now && until <= oneHourFromNow
                if isAvailableSoon { return false }
            }

            return true
        }
        
        let categories = [
            (AppConstants.Category.availableNow, availableNow),
            (AppConstants.Category.availableSoon, availableSoon),
            (AppConstants.Category.notAvailable, notAvailable)
        ]
        
        // Update cache
        friendCategoriesCache = categories
        cacheUpdateTime = Date()
        
        return categories
    }

    // MARK: - Visibility rules (hook for CloudKit; does not alter current UI)
    func canSee(friend: Friend) -> Bool {
        // Centralized place to enforce visibility. Keep current behavior: global flag and per-friend toggle.
        return globalStatusVisibility && friend.canSeeMyStatus
    }
    
    // MARK: - Friend Requests

    func fetchFriendRequests() {
        isLoading = true

        let group = DispatchGroup()
        
        group.enter()
        syncManager.fetchIncomingFriendRequests { [weak self] result in
            defer { group.leave() }
            
            switch result {
            case .success(let requests):
                DispatchQueue.main.async {
                    self?.pendingFriendRequests = requests
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
            }
        }
        
        group.enter()
        syncManager.fetchOutgoingFriendRequests { [weak self] result in
            defer { group.leave() }

            switch result {
            case .success(let requests):
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Process accepted requests - add them as friends
                    for request in requests where request.status == .accepted {
                        // Need valid name and phone to add as friend
                        guard let toUserName = request.toUserName,
                              let toUserPhone = request.toUserPhone else {
                            continue
                        }

                        // Check if already a friend
                        let alreadyFriend = self.friends.contains { $0.phoneNumber == toUserPhone }
                        if !alreadyFriend {
                            let newFriend = Friend(
                                name: toUserName,
                                phoneNumber: toUserPhone,
                                email: request.toUserEmail
                            )
                            self.friends.append(newFriend)
                            self.friendCategoriesCache = nil
                        }
                    }

                    // Only keep pending requests in the sent list
                    self.sentFriendRequests = requests.filter { $0.status == .pending }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.saveData()
            self?.updateAppBadge()
        }
    }
    
    func addSentFriendRequest(_ request: FriendRequest) {
        sentFriendRequests.append(request)
        saveData()
    }
    
    func cancelSentFriendRequest(_ request: FriendRequest) {
        // Remove locally immediately for responsive UI
        sentFriendRequests.removeAll { $0.id == request.id }
        saveData()

        // Delete from CloudKit
        guard request.cloudKitRecordID != nil else { return }

        syncManager.cancelFriendRequest(request) { [weak self] result in
            if case .failure(let error) = result {
                self?.handleError(error)
            }
        }
    }
    
    func respondToFriendRequest(_ request: FriendRequest, accept: Bool, completion: @escaping () -> Void) {
        // Handle requests without cloudKitRecordID (legacy/sample data)
        guard request.cloudKitRecordID != nil else {
            pendingFriendRequests.removeAll { $0.id == request.id }
            saveData()
            errorMessage = "This request is invalid and has been removed. Please ask your friend to send a new request."
            showError = true
            completion()
            return
        }

        isLoading = true

        let handler = accept ? syncManager.acceptFriendRequest : syncManager.declineFriendRequest

        handler(request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    if accept {
                        // Check for duplicate before adding
                        let alreadyFriend = self?.friends.contains { $0.phoneNumber == request.fromUserPhone } ?? false
                        if !alreadyFriend {
                            let newFriend = Friend(
                                name: request.fromUserName,
                                phoneNumber: request.fromUserPhone,
                                email: request.fromUserEmail
                            )
                            self?.friends.append(newFriend)
                            self?.friendCategoriesCache = nil
                        }
                    }

                    self?.pendingFriendRequests.removeAll { $0.id == request.id }
                    self?.saveData()

                    // Clear badge if no more pending requests
                    self?.updateAppBadge()

                    completion()

                case .failure(let error):
                    self?.handleError(error)
                    completion()
                }
            }
        }
    }
    
    // MARK: - Schedule Management
    
    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
        saveData()
        applyScheduleIfNeeded(at: Date())
        scheduleNextActivation()
    }

    func updateSchedule(original: Schedule, updated: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == original.id }) {
            schedules[index] = updated
            saveData()
            applyScheduleIfNeeded(at: Date())
            scheduleNextActivation()
        }
    }

    func deleteSchedule(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }
        scheduleNextActivation()
        saveData()
        applyScheduleIfNeeded(at: Date())
    }
    
    // MARK: - Sample Data (Debug Only)
    
    #if DEBUG
    private func generateSampleDataIfNeeded() {
        // Only generate once per install
        let hasGeneratedKey = "hasGeneratedSampleData_v3"
        guard UserDefaults.standard.object(forKey: hasGeneratedKey) == nil else { return }

        if friends.isEmpty {
            // Add sample friends with properly formatted phone numbers
            let sampleFriends = [
                Friend(name: "Alice Johnson", phoneNumber: "1234567890", email: "alice@example.com"),
                Friend(name: "Bob Smith", phoneNumber: "1987654321"),
                Friend(name: "Carol Williams", phoneNumber: "1122334455")
            ]

            // Set some sample statuses
            friends = sampleFriends
            friends[0].currentStatus = "Available"
            friends[0].statusMessage = "Free for calls!"
            friends[0].availableUntil = Calendar.current.date(byAdding: .hour, value: 2, to: Date())

            friends[1].currentStatus = "Unavailable"
            friends[1].statusMessage = "Can't talk right now"
            friends[1].availableUntil = Calendar.current.date(byAdding: .minute, value: 45, to: Date())

            // Note: Sample friend requests are NOT created because they lack cloudKitRecordID
            // and cannot be accepted/declined through CloudKit. Real friend requests from
            // CloudKit will work properly.

            saveData()
            UserDefaults.standard.set(true, forKey: hasGeneratedKey)
        }
    }
    #endif
}
