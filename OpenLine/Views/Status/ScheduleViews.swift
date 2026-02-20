//
//  ScheduleViews.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct ScheduleRowView: View {
    let schedule: Schedule
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingEditSheet = false

    private var ledColor: Color {
        if !schedule.isActive {
            return TurretTheme.ledOff
        }
        switch StatusType(rawValue: schedule.status) {
        case .available:
            return TurretTheme.ledGreen
        case .unavailable:
            return TurretTheme.ledRed
        default:
            return TurretTheme.ledAmber
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(ledColor)
                .frame(width: 10, height: 10)
                .shadow(color: ledColor.opacity(0.3), radius: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.title)
                    .font(TurretTheme.statusFont(size: 14, weight: .medium))

                Text(schedule.schedule)
                    .font(TurretTheme.captionFont(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingEditSheet = true }) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingEditSheet) {
            EditScheduleView(schedule: schedule, viewModel: viewModel, isPresented: $showingEditSheet)
        }
    }
}

struct AddScheduleView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @Binding var isPresented: Bool
    let scheduleType: ScheduleType

    @State private var title = ""
    @State private var selectedDays: Set<Int> = []
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .minute, value: 60, to: Date()) ?? Date()
    @State private var selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var selectedStatus: StatusType = .available
    @State private var isActive = true
    @Environment(\.dismiss) private var dismiss

    // Minimum date is tomorrow for one-time events
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private static var sharedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Schedule Details") {
                    TextField("Title", text: $title)

                    Picker("Status", selection: $selectedStatus) {
                        ForEach(StatusType.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Toggle("Active", isOn: $isActive)
                }

                Group {
                    switch scheduleType {
                    case .oneTime:
                        Section("Date") {
                            DatePicker("Event Date", selection: $selectedDate, in: minimumDate..., displayedComponents: .date)
                        }
                    case .recurring:
                        Section("Days") {
                            DaySelectionView(selectedDays: $selectedDays)
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { oldStartTime, newStartTime in
                            // Calculate the duration that was set (end - old start)
                            let currentDuration = endTime.timeIntervalSince(oldStartTime)
                            // Apply same duration to new start time (like calendar apps)
                            let newEndTime = newStartTime.addingTimeInterval(currentDuration)
                            // Ensure end time is always after start time (minimum 1 minute)
                            if newEndTime <= newStartTime {
                                endTime = Calendar.current.date(byAdding: .minute, value: 60, to: newStartTime) ?? newStartTime
                            } else {
                                endTime = newEndTime
                            }
                        }
                    DatePicker("End Time", selection: $endTime, in: startTime.addingTimeInterval(60)..., displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Add \(navigationTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSchedule()
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupDefaults()
        }
    }

    private var navigationTitle: String {
        switch scheduleType {
        case .oneTime: return "Event"
        case .recurring: return "Schedule"
        }
    }

    private var canSave: Bool {
        guard !title.isEmpty else { return false }

        switch scheduleType {
        case .oneTime:
            return true
        case .recurring:
            return !selectedDays.isEmpty
        }
    }

    private func setupDefaults() {
        // Set default end time to 30 minutes after start time
        endTime = Calendar.current.date(byAdding: .minute, value: 60, to: startTime) ?? startTime

        switch scheduleType {
        case .oneTime:
            setupDefaultOneTime()
        case .recurring:
            break
        }
    }

    private func setupDefaultOneTime() {
        let existingEvents = viewModel.schedules.filter { schedule in
            let components = schedule.schedule.components(separatedBy: ", ")
            if let firstComponent = components.first {
                return Self.sharedDateFormatter.date(from: firstComponent) != nil
            }
            return false
        }

        let eventNumber = existingEvents.count + 1
        title = eventNumber == 1 ? "One-time Event" : "Event \(eventNumber)"
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        selectedStatus = .available
    }

    private func saveSchedule() {
        let scheduleText = generateScheduleText()
        let newSchedule = Schedule(
            title: title,
            schedule: scheduleText,
            status: selectedStatus.rawValue,
            isActive: isActive
        )
        viewModel.addSchedule(newSchedule)
    }

    private func generateScheduleText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)

        switch scheduleType {
        case .oneTime:
            let dateString = Self.sharedDateFormatter.string(from: selectedDate)
            return "\(dateString), \(startTimeString)-\(endTimeString)"
        case .recurring:
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let selectedDayNames = selectedDays.sorted().map { dayNames[$0] }

            if selectedDayNames.count == 5 && selectedDays.contains(1) && selectedDays.contains(5) {
                return "Mon-Fri, \(startTimeString)-\(endTimeString)"
            } else {
                let daysString = selectedDayNames.joined(separator: ", ")
                return "\(daysString), \(startTimeString)-\(endTimeString)"
            }
        }
    }
}

struct EditScheduleView: View {
    let schedule: Schedule
    @ObservedObject var viewModel: OpenLineViewModel
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var selectedDays: Set<Int> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedDate = Date()
    @State private var selectedStatus: StatusType = .available
    @State private var isActive = true
    @State private var scheduleType: ScheduleType = .recurring
    @Environment(\.dismiss) private var dismiss

    // Minimum date is today for editing (allow current day)
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private static var sharedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Schedule Details") {
                    TextField("Title", text: $title)

                    Picker("Status", selection: $selectedStatus) {
                        ForEach(StatusType.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Toggle("Active", isOn: $isActive)
                }

                Group {
                    switch scheduleType {
                    case .oneTime:
                        Section("Date") {
                            DatePicker("Event Date", selection: $selectedDate, in: minimumDate..., displayedComponents: .date)
                        }
                    case .recurring:
                        Section("Days") {
                            DaySelectionView(selectedDays: $selectedDays)
                        }
                    }
                }
                .id(scheduleType)

                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { oldStartTime, newStartTime in
                            // Keep duration when start time changes
                            let currentDuration = endTime.timeIntervalSince(oldStartTime)
                            let newEndTime = newStartTime.addingTimeInterval(currentDuration)
                            if newEndTime <= newStartTime {
                                endTime = Calendar.current.date(byAdding: .minute, value: 60, to: newStartTime) ?? newStartTime
                            } else {
                                endTime = newEndTime
                            }
                        }
                    DatePicker("End Time", selection: $endTime, in: startTime.addingTimeInterval(60)..., displayedComponents: .hourAndMinute)
                }

                Section {
                    Button("Delete Schedule", role: .destructive) {
                        viewModel.deleteSchedule(schedule)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit \(scheduleType == .oneTime ? "Event" : "Schedule")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            parseExistingSchedule()
        }
    }

    private var canSave: Bool {
        guard !title.isEmpty else { return false }

        switch scheduleType {
        case .oneTime:
            return true
        case .recurring:
            return !selectedDays.isEmpty
        }
    }

    private func parseExistingSchedule() {
        title = schedule.title
        selectedStatus = StatusType(rawValue: schedule.status) ?? .available
        isActive = schedule.isActive

        let scheduleString = schedule.schedule

        if let lastCommaIndex = scheduleString.lastIndex(of: ",") {
            let beforeLastComma = String(scheduleString[..<lastCommaIndex]).trimmingCharacters(in: .whitespaces)
            let afterLastComma = String(scheduleString[scheduleString.index(after: lastCommaIndex)...]).trimmingCharacters(in: .whitespaces)

            if let parsedDate = Self.sharedDateFormatter.date(from: beforeLastComma) {
                scheduleType = .oneTime
                selectedDate = parsedDate
                parseTimeRange(afterLastComma)
                return
            }

            scheduleType = .recurring
            parseRecurringDays(beforeLastComma)
            parseTimeRange(afterLastComma)
        }
    }

    private func parseRecurringDays(_ daysString: String) {
        selectedDays.removeAll()

        let dayComponents = daysString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for component in dayComponents {
            if component.contains("-") {
                let rangeParts = component.components(separatedBy: "-")
                if rangeParts.count == 2 {
                    let startDay = rangeParts[0].trimmingCharacters(in: .whitespaces)
                    let endDay = rangeParts[1].trimmingCharacters(in: .whitespaces)

                    if let startIndex = dayNameToIndex(startDay),
                       let endIndex = dayNameToIndex(endDay) {
                        for dayIndex in startIndex...endIndex {
                            selectedDays.insert(dayIndex)
                        }
                    }
                }
            } else {
                if let dayIndex = dayNameToIndex(component) {
                    selectedDays.insert(dayIndex)
                }
            }
        }
    }

    private func dayNameToIndex(_ dayName: String) -> Int? {
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let shortDayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        if let index = dayNames.firstIndex(where: { $0.lowercased() == dayName.lowercased() }) {
            return index
        }
        if let index = shortDayNames.firstIndex(where: { $0.lowercased() == dayName.lowercased() }) {
            return index
        }
        return nil
    }

    private func parseTimeRange(_ timeString: String) {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if timeString.contains("-") {
            let timeParts = timeString.components(separatedBy: "-")
            if timeParts.count == 2 {
                let startTimeString = timeParts[0].trimmingCharacters(in: .whitespaces)
                let endTimeString = timeParts[1].trimmingCharacters(in: .whitespaces)

                if let parsedStartTime = timeFormatter.date(from: startTimeString) {
                    startTime = parsedStartTime
                }
                if let parsedEndTime = timeFormatter.date(from: endTimeString) {
                    endTime = parsedEndTime
                }
            }
        }
    }

    private func saveChanges() {
        let scheduleText = generateScheduleText()
        let updatedSchedule = Schedule(
            title: title,
            schedule: scheduleText,
            status: selectedStatus.rawValue,
            isActive: isActive
        )
        viewModel.updateSchedule(original: schedule, updated: updatedSchedule)
    }

    private func generateScheduleText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)

        switch scheduleType {
        case .oneTime:
            let dateString = Self.sharedDateFormatter.string(from: selectedDate)
            return "\(dateString), \(startTimeString)-\(endTimeString)"
        case .recurring:
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let selectedDayNames = selectedDays.sorted().map { dayNames[$0] }

            if selectedDayNames.count == 5 && selectedDays.contains(1) && selectedDays.contains(5) {
                return "Mon-Fri, \(startTimeString)-\(endTimeString)"
            } else {
                let daysString = selectedDayNames.joined(separator: ", ")
                return "\(daysString), \(startTimeString)-\(endTimeString)"
            }
        }
    }
}

struct DaySelectionView: View {
    @Binding var selectedDays: Set<Int>

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { dayIndex in
                Button(action: {
                    if selectedDays.contains(dayIndex) {
                        selectedDays.remove(dayIndex)
                    } else {
                        selectedDays.insert(dayIndex)
                    }
                }) {
                    Text(dayNames[dayIndex])
                        .font(TurretTheme.statusFont(size: 13, weight: .medium))
                        .foregroundColor(selectedDays.contains(dayIndex) ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(dayIndex) ? Color.accentColor : Color(UIColor.tertiarySystemFill))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
