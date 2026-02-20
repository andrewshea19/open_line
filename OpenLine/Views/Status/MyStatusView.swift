//
//  MyStatusView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct MyStatusView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingAddRecurring = false
    @State private var showingAddOneTime = false
    @State private var showingCustomQuickDuration = false
    @State private var customQuickHours = 0
    @State private var customQuickMinutes = 30

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status toggle at top (same as Friends page)
                    TurretStatusPanel(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Quick extend buttons (when status is active)
                    if viewModel.currentStatus != "No Status" {
                        quickExtendSection
                            .padding(.horizontal)
                    }

                    // Schedule section
                    scheduleSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("My Status")
        }
        .sheet(isPresented: $showingAddRecurring) {
            AddScheduleView(viewModel: viewModel, isPresented: $showingAddRecurring, scheduleType: .recurring)
        }
        .sheet(isPresented: $showingAddOneTime) {
            AddScheduleView(viewModel: viewModel, isPresented: $showingAddOneTime, scheduleType: .oneTime)
        }
        .sheet(isPresented: $showingCustomQuickDuration) {
            CustomDurationPickerView(
                hours: $customQuickHours,
                minutes: $customQuickMinutes,
                isPresented: $showingCustomQuickDuration,
                onSave: { hours, minutes in
                    let totalMinutes = hours * 60 + minutes
                    viewModel.extendCurrentStatus(by: totalMinutes)
                }
            )
        }
    }

    // MARK: - Quick Extend Section
    private var quickExtendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extend Duration")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)
                
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ForEach(AppConstants.quickExtendMinutes, id: \.self) { minutes in
                    quickExtendButton(minutes: minutes)
                }

                Button(action: { showingCustomQuickDuration = true }) {
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
    }

    private func quickExtendButton(minutes: Int) -> some View {
        Button(action: { viewModel.extendCurrentStatus(by: minutes) }) {
            Text(formatQuickDuration(minutes))
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

    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule")
                    .font(TurretTheme.headerFont(size: 13))
                    .foregroundColor(.secondary)
                    

                Spacer()

                Menu {
                    Button(action: { showingAddRecurring = true }) {
                        Label("Recurring Schedule", systemImage: "repeat")
                    }

                    Button(action: { showingAddOneTime = true }) {
                        Label("One-time Event", systemImage: "calendar")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 4)

            if viewModel.schedules.isEmpty {
                emptyScheduleView
            } else {
                VStack(spacing: 2) {
                    ForEach(viewModel.sortedSchedules()) { schedule in
                        ScheduleRowView(schedule: schedule, viewModel: viewModel)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
        }
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No Schedules")
                    .font(TurretTheme.statusFont(size: 15))

                Text("Add recurring schedules to\nautomatically update your status")
                    .font(TurretTheme.bodyFont(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func formatQuickDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "+\(minutes)m"
        } else {
            return "+\(minutes/60)hr"
        }
    }
}
