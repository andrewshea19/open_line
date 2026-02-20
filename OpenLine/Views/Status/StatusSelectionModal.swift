//
//  StatusSelectionModal.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

enum DurationMode: String, CaseIterable {
    case duration = "Duration"
    case untilTime = "Until Time"
}

struct StatusSelectionModal: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @Binding var isPresented: Bool
    @State private var selectedStatus: StatusType = .available
    @State private var selectedDuration = 60
    @State private var durationMode: DurationMode = .duration
    @State private var selectedEndTime = Date()
    @State private var showingCustomPicker = false
    @State private var customHours = 0
    @State private var customMinutes = 30
    @Environment(\.dismiss) private var dismiss

    private let durationOptionsRow1 = [
        (30, "30m"),
        (60, "1hr"),
        (120, "2hr")
    ]

    private let durationOptionsRow2 = [
        (240, "4hr"),
        (480, "8hr"),
        (1440, "All day")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    statusSelectionSection

                    if selectedStatus != .noStatus {
                        durationModeSection

                        if durationMode == .duration {
                            durationSelectionSection
                        } else {
                            timeSelectionSection
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(TurretTheme.bodyFont(size: 17))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        updateStatus()
                        dismiss()
                    }
                    .font(TurretTheme.statusFont(size: 17))
                }
            }
        }
        .sheet(isPresented: $showingCustomPicker) {
            CustomDurationPickerView(
                hours: $customHours,
                minutes: $customMinutes,
                isPresented: $showingCustomPicker,
                onSave: { hours, minutes in
                    selectedDuration = hours * 60 + minutes
                }
            )
        }
        .onAppear {
            // Preselect current status
            if let current = StatusType(rawValue: viewModel.currentStatus) {
                selectedStatus = current
            }
            // Always seed with app Default Status Duration
            selectedDuration = viewModel.defaultStatusDuration
            // Set default end time to 1 hour from now
            selectedEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        }
        .onChange(of: selectedStatus) { _ in
            // Always use app Default Status Duration regardless of status
            selectedDuration = viewModel.defaultStatusDuration
        }
    }

    private var statusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Status")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)

            ForEach(StatusType.allCases, id: \.self) { status in
                Button(action: { selectedStatus = status }) {
                    HStack {
                        // Status indicator
                        Circle()
                            .fill(statusDisplayColor(for: status))
                            .frame(width: 14, height: 14)
                            .shadow(color: statusDisplayColor(for: status).opacity(0.3), radius: 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.rawValue)
                                .font(TurretTheme.statusFont(size: 15))
                                .foregroundColor(.primary)

                            Text(status.defaultMessage)
                                .font(TurretTheme.captionFont(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedStatus == status {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background(selectedStatus == status ? Color.accentColor.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var durationModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("End Time")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)

            Picker("Mode", selection: $durationMode) {
                ForEach(DurationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var durationSelectionSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(durationOptionsRow1, id: \.0) { duration, label in
                    durationButton(duration: duration, label: label)
                }
            }

            HStack(spacing: 10) {
                ForEach(durationOptionsRow2, id: \.0) { duration, label in
                    durationButton(duration: duration, label: label)
                }
            }

            Button(action: { showingCustomPicker = true }) {
                Text("Custom")
                    .font(TurretTheme.statusFont(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func durationButton(duration: Int, label: String) -> some View {
        Button(action: { selectedDuration = duration }) {
            Text(label)
                .font(TurretTheme.statusFont(size: 13, weight: .medium))
                .foregroundColor(selectedDuration == duration ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedDuration == duration ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var timeSelectionSection: some View {
        DatePicker(
            "Status ends at",
            selection: $selectedEndTime,
            in: Date()...,
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.compact)
        .font(TurretTheme.bodyFont(size: 15))
    }

    private func updateStatus() {
        var until: Date?

        if selectedStatus != .noStatus {
            if durationMode == .duration {
                until = Calendar.current.date(byAdding: .minute, value: selectedDuration, to: Date())
            } else {
                until = selectedEndTime
            }
        }

        viewModel.updateCurrentStatus(
            status: selectedStatus.rawValue,
            message: selectedStatus.defaultMessage,
            until: until
        )

        if durationMode == .duration {
            viewModel.setLastUsedDuration(selectedDuration, for: selectedStatus)
        }
    }

    private func statusDisplayColor(for status: StatusType) -> Color {
        switch status {
        case .available:
            return TurretTheme.ledGreen
        case .noStatus:
            return TurretTheme.ledAmber
        case .unavailable:
            return TurretTheme.ledRed
        }
    }
}
