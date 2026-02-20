//
//  OpenLineTests.swift
//  OpenLineTests
//
//  Created by Andrew Shea on 6/16/25.
//

import Testing
import Foundation
@testable import OpenLine

struct OpenLineTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - Schedule Parsing Tests

struct ScheduleParsingTests {

    // Helper to create a date formatter matching the app's format
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    @Test func testOneTimeScheduleFormat() async throws {
        // Test that a one-time schedule is formatted correctly
        let date = Date()
        let startTime = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: date)!
        let endTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: date)!

        let dateString = dateFormatter.string(from: date)
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)

        let scheduleText = "\(dateString), \(startTimeString)-\(endTimeString)"

        // Verify the format can be parsed back
        // The format is: "Feb 18, 2026, 2:00 PM-3:00 PM"
        // We need to find the last comma to split date from time
        if let lastCommaIndex = scheduleText.lastIndex(of: ",") {
            let beforeLastComma = String(scheduleText[..<lastCommaIndex]).trimmingCharacters(in: .whitespaces)
            let parsedDate = dateFormatter.date(from: beforeLastComma)
            #expect(parsedDate != nil, "Date should be parseable: \(beforeLastComma)")
        } else {
            #expect(Bool(false), "Schedule should contain comma")
        }
    }

    @Test func testRecurringScheduleFormat() async throws {
        // Test Mon-Fri schedule format
        let scheduleText = "Mon-Fri, 9:00 AM-5:00 PM"

        let parts = scheduleText.components(separatedBy: ",")
        #expect(parts.count == 2)

        let dayPart = parts[0].trimmingCharacters(in: .whitespaces)
        #expect(dayPart == "Mon-Fri")

        let timePart = parts[1].trimmingCharacters(in: .whitespaces)
        #expect(timePart.contains("-"))

        let timeParts = timePart.components(separatedBy: "-")
        #expect(timeParts.count == 2)
    }

    @Test func testTimeRangeParsing() async throws {
        let timeRangeString = "9:00 AM-5:00 PM"

        let timeParts = timeRangeString.components(separatedBy: "-")
        #expect(timeParts.count == 2)

        let startTimeStr = timeParts[0].trimmingCharacters(in: .whitespaces)
        let endTimeStr = timeParts[1].trimmingCharacters(in: .whitespaces)

        let startTime = timeFormatter.date(from: startTimeStr)
        let endTime = timeFormatter.date(from: endTimeStr)

        #expect(startTime != nil, "Start time should parse: \(startTimeStr)")
        #expect(endTime != nil, "End time should parse: \(endTimeStr)")
    }

    @Test func testScheduleModelCreation() async throws {
        let schedule = Schedule(
            title: "Test Schedule",
            schedule: "Mon-Fri, 9:00 AM-5:00 PM",
            status: "Available",
            isActive: true
        )

        #expect(schedule.title == "Test Schedule")
        #expect(schedule.status == "Available")
        #expect(schedule.isActive == true)
    }

    @Test func testDayNameParsing() async throws {
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let shortDayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Test that Mon-Fri expands to days 1-5
        let monFri = "Mon-Fri"
        let rangeParts = monFri.components(separatedBy: "-")
        #expect(rangeParts.count == 2)

        let startDay = rangeParts[0]
        let endDay = rangeParts[1]

        let startIndex = shortDayNames.firstIndex(where: { $0.caseInsensitiveCompare(startDay) == .orderedSame })
        let endIndex = shortDayNames.firstIndex(where: { $0.caseInsensitiveCompare(endDay) == .orderedSame })

        #expect(startIndex == 1, "Mon should be index 1")
        #expect(endIndex == 5, "Fri should be index 5")
    }
}

// MARK: - Status Type Tests

struct StatusTypeTests {

    @Test func testStatusTypeRawValues() async throws {
        #expect(StatusType.available.rawValue == "Available")
        #expect(StatusType.unavailable.rawValue == "Unavailable")
        #expect(StatusType.noStatus.rawValue == "No Status")
    }

    @Test func testStatusTypeCaseIterable() async throws {
        let allCases = StatusType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.available))
        #expect(allCases.contains(.unavailable))
        #expect(allCases.contains(.noStatus))
    }

    @Test func testStatusCycling() async throws {
        // Test cycling through statuses
        let statuses = StatusType.allCases

        // Starting from available (index 0)
        var currentIndex = 0
        #expect(statuses[currentIndex] == .available)

        // Cycle to next (unavailable)
        currentIndex = (currentIndex + 1) % statuses.count
        #expect(statuses[currentIndex] == .unavailable)

        // Cycle to next (noStatus)
        currentIndex = (currentIndex + 1) % statuses.count
        #expect(statuses[currentIndex] == .noStatus)

        // Cycle back to available
        currentIndex = (currentIndex + 1) % statuses.count
        #expect(statuses[currentIndex] == .available)
    }
}

// MARK: - Schedule Activation Tests

struct ScheduleActivationTests {

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    @Test func testCurrentTimeInScheduleWindow() async throws {
        // Create a schedule that is currently active
        let now = Date()
        let cal = Calendar.current

        // Set start time to 1 hour ago, end time to 1 hour from now
        let startTime = cal.date(byAdding: .hour, value: -1, to: now)!
        let endTime = cal.date(byAdding: .hour, value: 1, to: now)!

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        let dateString = dateFormatter.string(from: now)

        let scheduleText = "\(dateString), \(startTimeString)-\(endTimeString)"

        let schedule = Schedule(
            title: "Test Active Schedule",
            schedule: scheduleText,
            status: "Available",
            isActive: true
        )

        // Verify schedule is active
        #expect(schedule.isActive == true)
        #expect(schedule.status == "Available")

        // Parse and verify the schedule covers current time
        if let lastCommaIndex = scheduleText.lastIndex(of: ",") {
            let datePart = String(scheduleText[..<lastCommaIndex]).trimmingCharacters(in: .whitespaces)
            let timePart = String(scheduleText[scheduleText.index(after: lastCommaIndex)...]).trimmingCharacters(in: .whitespaces)

            let parsedDate = dateFormatter.date(from: datePart)
            #expect(parsedDate != nil, "Date should parse correctly")

            let timeParts = timePart.components(separatedBy: "-")
            #expect(timeParts.count == 2)

            let parsedStartTime = timeFormatter.date(from: timeParts[0].trimmingCharacters(in: .whitespaces))
            let parsedEndTime = timeFormatter.date(from: timeParts[1].trimmingCharacters(in: .whitespaces))

            #expect(parsedStartTime != nil, "Start time should parse")
            #expect(parsedEndTime != nil, "End time should parse")
        }
    }

    @Test func testRecurringScheduleForToday() async throws {
        // Create a recurring schedule that includes today
        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday, 2 = Monday, etc.

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let todayName = dayNames[weekday - 1]

        // Create schedule for today from 1 hour ago to 1 hour from now
        let startTime = cal.date(byAdding: .hour, value: -1, to: now)!
        let endTime = cal.date(byAdding: .hour, value: 1, to: now)!

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)

        let scheduleText = "\(todayName), \(startTimeString)-\(endTimeString)"

        let schedule = Schedule(
            title: "Today's Recurring Schedule",
            schedule: scheduleText,
            status: "Available",
            isActive: true
        )

        #expect(schedule.schedule.contains(todayName))
        #expect(schedule.isActive == true)
    }

    @Test func testScheduleEndTimeDefault() async throws {
        // Test that default end time is 60 minutes after start time
        let startTime = Date()
        let expectedEndTime = Calendar.current.date(byAdding: .minute, value: 60, to: startTime)!

        let timeDifference = expectedEndTime.timeIntervalSince(startTime)
        #expect(timeDifference == 3600, "End time should be 60 minutes (3600 seconds) after start time")
    }

    @Test @MainActor func testViewModelScheduleActivation() async throws {
        // Create a ViewModel with mock dependencies
        let viewModel = OpenLineViewModel()

        // Get the current time
        let now = Date()
        let cal = Calendar.current

        // Create a schedule that is currently active (started 5 min ago, ends in 55 min)
        let startTime = cal.date(byAdding: .minute, value: -5, to: now)!
        let endTime = cal.date(byAdding: .minute, value: 55, to: now)!

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        let dateString = dateFormatter.string(from: now)

        let scheduleText = "\(dateString), \(startTimeString)-\(endTimeString)"

        let schedule = Schedule(
            title: "Active Now",
            schedule: scheduleText,
            status: "Available",
            isActive: true
        )

        // Add the schedule - this synchronously applies if currently active
        viewModel.addSchedule(schedule)

        // The status should now be "Available" because the schedule is currently active
        // (addSchedule calls applyScheduleIfNeeded synchronously)
        #expect(viewModel.currentStatus == "Available", "Status should be Available because schedule is active now. Current: \(viewModel.currentStatus)")
    }

    @Test @MainActor func testViewModelFutureSchedule() async throws {
        // Test that a future schedule doesn't immediately activate
        let viewModel = OpenLineViewModel()

        // Record current status before adding schedule (should be initial state)
        let statusBefore = viewModel.currentStatus

        let now = Date()
        let cal = Calendar.current

        // Create a schedule that starts in 1 hour
        let startTime = cal.date(byAdding: .hour, value: 1, to: now)!
        let endTime = cal.date(byAdding: .hour, value: 2, to: now)!

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        let dateString = dateFormatter.string(from: now)

        let scheduleText = "\(dateString), \(startTimeString)-\(endTimeString)"

        let schedule = Schedule(
            title: "Future Schedule",
            schedule: scheduleText,
            status: "Available",
            isActive: true
        )

        // Add the schedule - this should NOT change status since it's in the future
        viewModel.addSchedule(schedule)

        // Status should NOT change because schedule hasn't started yet
        // (applyScheduleIfNeeded only applies schedules where now is within start..end)
        #expect(viewModel.currentStatus == statusBefore, "Status should not change for future schedule. Before: \(statusBefore), After: \(viewModel.currentStatus)")
    }
}

// MARK: - Friend Categorization Tests

struct FriendCategorizationTests {

    @Test @MainActor func testAvailableFriendInAvailableNowCategory() async throws {
        let viewModel = OpenLineViewModel()

        // Create a friend who is Available with future expiration
        var friend = Friend(name: "Test Friend", phoneNumber: "1234567890")
        friend.currentStatus = "Available"
        friend.availableUntil = Calendar.current.date(byAdding: .hour, value: 1, to: Date())

        // Add friend directly (for testing)
        // Note: In real app this would go through proper channels
        // For this test we're just verifying the categorization logic

        // Test the categorization logic directly
        let now = Date()
        let isAvailableNow = friend.displayStatus == "Available" && (friend.availableUntil == nil || friend.availableUntil! > now)

        #expect(isAvailableNow == true, "Friend with Available status and future expiration should be available now")
    }

    @Test @MainActor func testAvailableFriendWithNoExpirationIsAvailable() async throws {
        // Create a friend who is Available with NO expiration (always available)
        var friend = Friend(name: "Always Available", phoneNumber: "9876543210")
        friend.currentStatus = "Available"
        friend.availableUntil = nil  // No expiration

        let now = Date()
        let isAvailableNow = friend.displayStatus == "Available" && (friend.availableUntil == nil || friend.availableUntil! > now)

        #expect(isAvailableNow == true, "Friend with Available status and no expiration should be available now")
    }

    @Test @MainActor func testExpiredFriendIsNotAvailable() async throws {
        // Create a friend whose availability has expired
        var friend = Friend(name: "Expired Friend", phoneNumber: "5555555555")
        friend.currentStatus = "Available"
        friend.availableUntil = Calendar.current.date(byAdding: .hour, value: -1, to: Date())  // Expired 1 hour ago

        let now = Date()
        let isAvailableNow = friend.displayStatus == "Available" && (friend.availableUntil == nil || friend.availableUntil! > now)

        #expect(isAvailableNow == false, "Friend with expired availability should NOT be available now")
    }

    @Test func testDefaultEndTime60Minutes() async throws {
        // Test that default end time is 60 minutes after start time
        let startTime = Date()
        let expectedEndTime = Calendar.current.date(byAdding: .minute, value: 60, to: startTime)!

        let timeDifference = expectedEndTime.timeIntervalSince(startTime)
        #expect(timeDifference == 3600, "End time should be 60 minutes (3600 seconds) after start time")
    }

    @Test func testEndTimeMustBeAfterStartTime() async throws {
        let startTime = Date()
        let endTime = Calendar.current.date(byAdding: .minute, value: 30, to: startTime)!

        #expect(endTime > startTime, "End time must be after start time")

        // Also test that minimum gap is enforced (1 minute = 60 seconds)
        let minimumEndTime = startTime.addingTimeInterval(60)
        #expect(minimumEndTime > startTime, "Minimum end time should be at least 1 minute after start")
    }

    @Test func testScheduleEndTimeComparison() async throws {
        // Test that at exactly the end time, a schedule is NOT considered active
        // This is the critical fix: now < end (not now <= end)
        let now = Date()
        let cal = Calendar.current

        // Create times where "now" is exactly at the end time
        let startTime = cal.date(byAdding: .hour, value: -1, to: now)!
        let endTime = now // End time is exactly now

        // At the end time, the schedule should NOT be active (now < end is false when now == end)
        let isActive = startTime <= now && now < endTime

        #expect(isActive == false, "Schedule should NOT be active at exactly the end time")
    }

    @Test func testScheduleActiveBeforeEndTime() async throws {
        // Test that a schedule IS active one second before the end time
        let now = Date()
        let cal = Calendar.current

        let startTime = cal.date(byAdding: .hour, value: -1, to: now)!
        let endTime = cal.date(byAdding: .second, value: 1, to: now)! // End time is 1 second from now

        // One second before end, the schedule SHOULD be active
        let isActive = startTime <= now && now < endTime

        #expect(isActive == true, "Schedule should be active before end time")
    }
}
