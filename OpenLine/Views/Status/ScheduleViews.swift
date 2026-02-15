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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    let activeColor: Color = schedule.isActive ? .blue : .gray
                    Circle()
                        .fill(activeColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: activeColor.opacity(0.4), radius: 3, x: 0, y: 1)
                    
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 10, height: 10)
                }
                
                Text(schedule.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                Spacer()
                
                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            
            Text(schedule.schedule)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                ZStack {
                    let statusColor: Color = StatusType(rawValue: schedule.status)?.color ?? .gray
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: statusColor.opacity(0.4), radius: 3, x: 0, y: 1)
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 10, height: 10)
                }
                Text("Status: \(schedule.status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14, padding: 0)
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
    @State private var endTime = Date()
    @State private var selectedDate = Date()
    @State private var selectedStatus: StatusType = .available
    @State private var isActive = true
    @Environment(\.dismiss) private var dismiss
    
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
                            DatePicker("Event Date", selection: $selectedDate, displayedComponents: .date)
                        }
                    case .recurring, .commute:
                        Section("Days") {
                            DaySelectionView(selectedDays: $selectedDays)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
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
        case .oneTime: return "One-time Event"
        case .commute: return "Commute"
        case .recurring: return "Schedule"
        @unknown default: return "Schedule"
        }
    }
    
    private var canSave: Bool {
        guard !title.isEmpty else { return false }
        
        switch scheduleType {
        case .oneTime:
            return true
        case .recurring, .commute:
            return !selectedDays.isEmpty
        @unknown default:
            return false
        }
    }
    
    private func setupDefaults() {
        switch scheduleType {
        case .oneTime:
            setupDefaultOneTime()
        case .commute:
            setupDefaultCommute()
        case .recurring:
            break
        @unknown default:
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
    
    private func setupDefaultCommute() {
        let existingCommutes = viewModel.schedules.filter {
            $0.title.lowercased().contains("commute")
        }
        
        let commuteNumber = existingCommutes.count + 1
        title = commuteNumber == 1 ? "Morning Commute" : "Commute \(commuteNumber)"
        selectedDays = Set([1, 2, 3, 4, 5])
        
        let calendar = Calendar.current
        var morningStart = calendar.dateInterval(of: .day, for: Date())!.start
        morningStart = calendar.date(byAdding: .hour, value: 8, to: morningStart)!
        morningStart = calendar.date(byAdding: .minute, value: 30, to: morningStart)!
        
        startTime = morningStart
        endTime = calendar.date(byAdding: .minute, value: 45, to: morningStart)!
        selectedStatus = .commuting
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
        case .recurring, .commute:
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let selectedDayNames = selectedDays.sorted().map { dayNames[$0] }
            
            if selectedDayNames.count == 5 && selectedDays.contains(1) && selectedDays.contains(5) {
                return "Mon-Fri, \(startTimeString)-\(endTimeString)"
            } else {
                let daysString = selectedDayNames.joined(separator: ", ")
                return "\(daysString), \(startTimeString)-\(endTimeString)"
            }
        @unknown default:
            return "\(startTimeString)-\(endTimeString)"
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
                            DatePicker("Event Date", selection: $selectedDate, displayedComponents: .date)
                        }
                    case .recurring, .commute:
                        Section("Days") {
                            DaySelectionView(selectedDays: $selectedDays)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(scheduleType)
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    Button("Delete Schedule", role: .destructive) {
                        viewModel.deleteSchedule(schedule)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit \(scheduleType == .oneTime ? "One-time Event" : "Schedule")")
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
        case .recurring, .commute:
            return !selectedDays.isEmpty
        @unknown default:
            return false
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
            
            scheduleType = schedule.title.lowercased().contains("commute") ? .commute : .recurring
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
        case .recurring, .commute:
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let selectedDayNames = selectedDays.sorted().map { dayNames[$0] }
            
            if selectedDayNames.count == 5 && selectedDays.contains(1) && selectedDays.contains(5) {
                return "Mon-Fri, \(startTimeString)-\(endTimeString)"
            } else {
                let daysString = selectedDayNames.joined(separator: ", ")
                return "\(daysString), \(startTimeString)-\(endTimeString)"
            }
        @unknown default:
            return "\(startTimeString)-\(endTimeString)"
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedDays.contains(dayIndex) ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(dayIndex) ? Color.blue : Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

