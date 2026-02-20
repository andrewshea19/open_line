//
//  OpenLineWidget.swift
//  OpenLineWidget
//
//  Created by Andrew Shea on 2/17/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Theme (Slack-Inspired Modern Design)

struct WidgetTheme {
    // Backgrounds
    static let background = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let cardBackground = Color(red: 0.16, green: 0.17, blue: 0.19)
    static let panelDark = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let bezel = Color(red: 0.28, green: 0.29, blue: 0.31)

    // LED colors - signature element
    static let ledGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let ledRed = Color(red: 0.90, green: 0.32, blue: 0.32)
    static let ledAmber = Color(red: 0.96, green: 0.70, blue: 0.20)
    static let ledOff = Color(red: 0.55, green: 0.57, blue: 0.60)

    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color(white: 0.65)
    static let dimText = Color(white: 0.45)

    // Corner radius
    static let cornerRadius: CGFloat = 10

    // Fonts - Rounded for friendly, professional look
    static func statusFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func captionFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Widget Entry

struct AvailabilityEntry: TimelineEntry {
    let date: Date
    let currentStatus: String
    let statusMessage: String
    let statusUntil: Date?
    let availableFriends: [WidgetFriend]

    var isAvailable: Bool {
        currentStatus == "Available"
    }

    var isNoStatus: Bool {
        currentStatus == "No Status"
    }
}

// MARK: - Timeline Provider

struct AvailabilityProvider: TimelineProvider {
    func placeholder(in context: Context) -> AvailabilityEntry {
        AvailabilityEntry(
            date: Date(),
            currentStatus: "Available",
            statusMessage: "Free for calls!",
            statusUntil: nil,
            availableFriends: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AvailabilityEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AvailabilityEntry>) -> Void) {
        let now = Date()
        var entries: [AvailabilityEntry] = []
        var refreshDates: [Date] = []

        // Create current entry
        let currentEntry = createEntry()
        entries.append(currentEntry)

        // Add status expiration time as a refresh point
        if let until = currentEntry.statusUntil, until > now {
            refreshDates.append(until)
        }

        // Add friend availability expiration times
        for friend in currentEntry.availableFriends {
            if let friendUntil = friend.availableUntil, friendUntil > now {
                refreshDates.append(friendUntil)
            }
        }

        // Default refresh every 5 minutes (reduced from 15 for more responsive updates)
        let defaultRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now

        // Find the next refresh time (earliest of all options)
        var nextRefresh = defaultRefresh
        for date in refreshDates {
            if date > now && date < nextRefresh {
                nextRefresh = date
            }
        }

        // Create entries at key transition times for smooth updates
        for date in refreshDates.sorted() where date > now && date <= defaultRefresh {
            let futureEntry = AvailabilityEntry(
                date: date,
                currentStatus: currentEntry.currentStatus,
                statusMessage: currentEntry.statusMessage,
                statusUntil: currentEntry.statusUntil,
                availableFriends: currentEntry.availableFriends
            )
            entries.append(futureEntry)
        }

        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }

    private func createEntry() -> AvailabilityEntry {
        let shared = SharedDefaults.shared
        return AvailabilityEntry(
            date: Date(),
            currentStatus: shared.currentStatus,
            statusMessage: shared.statusMessage,
            statusUntil: shared.statusUntil,
            availableFriends: shared.availableFriends.filter { $0.isAvailable }
        )
    }
}

// MARK: - Toggle Intent

struct ToggleAvailabilityIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Availability"
    static var description = IntentDescription("Toggle between Available and Unavailable status")

    func perform() async throws -> some IntentResult {
        let shared = SharedDefaults.shared
        let currentlyAvailable = shared.isAvailable

        if currentlyAvailable {
            shared.currentStatus = "Unavailable"
            shared.statusMessage = "Can't talk right now"
        } else {
            shared.currentStatus = "Available"
            shared.statusMessage = "Free for calls!"
        }

        let duration = shared.defaultDuration > 0 ? shared.defaultDuration : 120
        shared.statusUntil = Calendar.current.date(byAdding: .minute, value: duration, to: Date())

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// MARK: - Widget Views

struct OpenLineWidgetEntryView: View {
    var entry: AvailabilityProvider.Entry
    @Environment(\.widgetFamily) var family

    private var ledColor: Color {
        switch entry.currentStatus {
        case "Available":
            return WidgetTheme.ledGreen
        case "Unavailable":
            return WidgetTheme.ledRed
        default:
            return WidgetTheme.ledAmber
        }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryCircular:
            circularWidget
        case .accessoryRectangular:
            rectangularWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget
    private var smallWidget: some View {
        Button(intent: ToggleAvailabilityIntent()) {
            VStack(spacing: 10) {
                // LED indicator
                ledIndicator(size: 44)

                // Status text
                VStack(spacing: 3) {
                    Text(entry.currentStatus)
                        .font(WidgetTheme.statusFont(size: 13))
                        .foregroundStyle(WidgetTheme.primaryText)

                    if let until = entry.statusUntil {
                        Text("Until \(until, style: .time)")
                            .font(WidgetTheme.captionFont(size: 11))
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                }

                Text("Tap to toggle")
                    .font(WidgetTheme.captionFont(size: 9))
                    .foregroundStyle(WidgetTheme.dimText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }

    // MARK: - Medium Widget
    private var mediumWidget: some View {
        HStack(spacing: 0) {
            // Status toggle section
            Button(intent: ToggleAvailabilityIntent()) {
                VStack(spacing: 8) {
                    ledIndicator(size: 36)

                    VStack(spacing: 2) {
                        Text(entry.currentStatus)
                            .font(WidgetTheme.statusFont(size: 11))
                            .foregroundStyle(WidgetTheme.primaryText)

                        if let until = entry.statusUntil {
                            Text("\(until, style: .time)")
                                .font(WidgetTheme.captionFont(size: 10))
                                .foregroundStyle(WidgetTheme.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(WidgetTheme.bezel.opacity(0.5))
                .frame(width: 1)
                .padding(.vertical, 12)

            // Friends section
            VStack(alignment: .leading, spacing: 6) {
                Text("Friends")
                    .font(WidgetTheme.statusFont(size: 10))
                    .foregroundStyle(WidgetTheme.secondaryText)

                if entry.availableFriends.isEmpty {
                    VStack {
                        Spacer()
                        Text("No one online")
                            .font(WidgetTheme.captionFont(size: 11))
                            .foregroundStyle(WidgetTheme.dimText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 4) {
                        ForEach(entry.availableFriends.prefix(3)) { friend in
                            friendRow(friend, compact: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 10)
        }
        .padding(10)
        .widgetURL(URL(string: "openline://home"))
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }

    // MARK: - Large Widget
    private var largeWidget: some View {
        VStack(spacing: 12) {
            // Status toggle header
            Button(intent: ToggleAvailabilityIntent()) {
                HStack(spacing: 12) {
                    ledIndicator(size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.currentStatus)
                            .font(WidgetTheme.statusFont(size: 15))
                            .foregroundStyle(WidgetTheme.primaryText)

                        if let until = entry.statusUntil {
                            Text("Until \(until, style: .time)")
                                .font(WidgetTheme.captionFont(size: 12))
                                .foregroundStyle(WidgetTheme.secondaryText)
                        } else {
                            Text("Tap to toggle")
                                .font(WidgetTheme.captionFont(size: 12))
                                .foregroundStyle(WidgetTheme.dimText)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WidgetTheme.dimText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(WidgetTheme.cardBackground)
                )
            }
            .buttonStyle(.plain)

            // Friends header
            HStack {
                Text("Friends Online")
                    .font(WidgetTheme.statusFont(size: 11))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Spacer()
                Text("\(entry.availableFriends.count)")
                    .font(WidgetTheme.captionFont(size: 11))
                    .foregroundStyle(WidgetTheme.dimText)
            }

            // Friends list
            if entry.availableFriends.isEmpty {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(WidgetTheme.cardBackground)
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.2")
                            .font(.system(size: 18))
                            .foregroundStyle(WidgetTheme.dimText)
                    }
                    Text("No friends online")
                        .font(WidgetTheme.captionFont(size: 12))
                        .foregroundStyle(WidgetTheme.dimText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.availableFriends.prefix(5)) { friend in
                        friendRow(friend, compact: false)
                    }

                    if entry.availableFriends.count > 5 {
                        Text("+\(entry.availableFriends.count - 5) more")
                            .font(WidgetTheme.captionFont(size: 11))
                            .foregroundStyle(WidgetTheme.dimText)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .widgetURL(URL(string: "openline://home"))
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }

    // MARK: - Lock Screen Widgets
    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()

            Circle()
                .fill(ledColor)
                .padding(8)
                .shadow(color: ledColor.opacity(0.6), radius: 4)
        }
    }

    private var rectangularWidget: some View {
        HStack(spacing: 8) {
            // Mini LED
            ZStack {
                Circle()
                    .fill(ledColor.opacity(0.4))
                    .frame(width: 18, height: 18)
                    .blur(radius: 2)

                Circle()
                    .fill(ledColor)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.currentStatus)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                if !entry.availableFriends.isEmpty {
                    Text("\(entry.availableFriends.count) online")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                } else if let until = entry.statusUntil {
                    Text("Until \(until, style: .time)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    // MARK: - Helper Views

    private func ledIndicator(size: CGFloat) -> some View {
        Circle()
            .fill(ledColor)
            .frame(width: size * 0.7, height: size * 0.7)
            .shadow(color: ledColor.opacity(0.5), radius: 4)
    }

    private func friendRow(_ friend: WidgetFriend, compact: Bool) -> some View {
        Link(destination: URL(string: "tel:\(friend.phoneNumber)")!) {
            HStack(spacing: compact ? 6 : 8) {
                // Status indicator
                Circle()
                    .fill(WidgetTheme.ledGreen)
                    .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                    .shadow(color: WidgetTheme.ledGreen.opacity(0.3), radius: 2)

                Text(friend.name)
                    .font(WidgetTheme.statusFont(size: compact ? 10 : 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                // Call button
                ZStack {
                    Circle()
                        .fill(WidgetTheme.ledGreen.opacity(0.15))
                        .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)

                    Image(systemName: "phone.fill")
                        .font(.system(size: compact ? 9 : 11))
                        .foregroundStyle(WidgetTheme.ledGreen)
                }
            }
            .padding(.vertical, compact ? 5 : 7)
            .padding(.horizontal, compact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(WidgetTheme.cardBackground)
            )
        }
    }
}

// MARK: - Widget Definition

struct OpenLineWidget: Widget {
    let kind: String = "OpenLineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AvailabilityProvider()) { entry in
            OpenLineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Open.Line")
        .description("Toggle availability and see who's free to call")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    OpenLineWidget()
} timeline: {
    AvailabilityEntry(
        date: .now,
        currentStatus: "Available",
        statusMessage: "Free for calls!",
        statusUntil: Date().addingTimeInterval(3600),
        availableFriends: [
            WidgetFriend(id: "1", name: "Alice Johnson", phoneNumber: "1234567890", status: "Available", statusMessage: "Free!", availableUntil: Date().addingTimeInterval(3600)),
            WidgetFriend(id: "2", name: "Bob Smith", phoneNumber: "0987654321", status: "Available", statusMessage: "Call me!", availableUntil: Date().addingTimeInterval(1800))
        ]
    )
}
